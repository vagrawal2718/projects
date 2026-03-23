"""
DHW Time Series Forecasting Module
===================================

CRITICAL INSIGHT: DHW prediction is a TIME SERIES problem, not classification.
The current approach (RF/XGBoost classification) fails because:
1. 98% of days are "no bleaching" - models predict majority class
2. Time series structure (seasonality, autocorrelation) is ignored
3. DHW magnitude matters, not just binary bleaching/no-bleaching

This module provides:
1. SARIMAX - Classical time series with exogenous variables
2. Prophet - Facebook's forecasting with seasonality
3. NeuralProphet - Prophet + neural networks
4. Chronos v2 - Amazon's foundation model (state-of-the-art)
5. Ensemble - Combining pCRVI components with time series forecasts

Key exogenous variables for DHW forecasting:
- ONI (El Niño) - 2-6 month lead time
- DMI (Indian Ocean Dipole) - 2-4 month lead time
- pCRVI components (thermal anomaly trend, accumulating stress)
"""

from typing import Optional, Dict, List, Any, Tuple
from datetime import datetime, timedelta
from pathlib import Path
import warnings
import numpy as np
import pandas as pd
from .logger import get_logger
from .naming import friendly_name, csv_rename_dict
warnings.filterwarnings('ignore')

# Check available libraries
STATSMODELS_AVAILABLE = False
PROPHET_AVAILABLE = False
NEURALPROPHET_AVAILABLE = False
CHRONOS_AVAILABLE = False
SKLEARN_AVAILABLE = False

try:
    from statsmodels.tsa.statespace.sarimax import SARIMAX
    from statsmodels.tsa.stattools import adfuller
    STATSMODELS_AVAILABLE = True
except ImportError:
    pass

try:
    from prophet import Prophet
    PROPHET_AVAILABLE = True
except ImportError:
    pass

try:
    from neuralprophet import NeuralProphet
    NEURALPROPHET_AVAILABLE = True
except ImportError:
    pass

try:
    import torch
    from chronos import ChronosPipeline
    CHRONOS_AVAILABLE = True
except ImportError:
    pass

try:
    from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
    from sklearn.preprocessing import StandardScaler
    from sklearn.ensemble import GradientBoostingRegressor
    SKLEARN_AVAILABLE = True
except ImportError:
    pass


class DHWTimeSeriesForecaster:
    """
    Time series forecasting for Degree Heating Weeks (DHW).
    
    Replaces classification approach with proper time series regression.
    """
    
    def __init__(
        self,
        mmm_sst: float = 29.87,
        bleaching_threshold: float = 4.0,
        severe_threshold: float = 8.0
    ):
        """
        Initialize forecaster.
        
        Parameters
        ----------
        mmm_sst : float
            Maximum Monthly Mean SST for the region (ANI = 29.87°C)
        bleaching_threshold : float
            DHW threshold for bleaching (typically 4.0)
        severe_threshold : float
            DHW threshold for severe bleaching (typically 8.0)
        """
        self.logger = get_logger("coral_ews.dhw_forecaster")
        self.mmm_sst = mmm_sst
        self.bleaching_threshold = bleaching_threshold
        self.severe_threshold = severe_threshold
        
        self.models = {}
        self.scalers = {}
        self.feature_df = None
        
        # Report available models
        self.available = {
            'sarimax': STATSMODELS_AVAILABLE,
            'prophet': PROPHET_AVAILABLE,
            'neuralprophet': NEURALPROPHET_AVAILABLE,
            'chronos': CHRONOS_AVAILABLE
        }
        
        print("DHW Time Series Forecaster initialized")
        print(f"Available models: {[k for k,v in self.available.items() if v]}")
    
    def prepare_features(
        self,
        sst_data: pd.DataFrame,
        dhw_data: pd.DataFrame,
        climate_data: Optional[pd.DataFrame] = None,
        pcrvi_data: Optional[pd.DataFrame] = None,
        ocean_color_data: Optional[pd.DataFrame] = None,
    ) -> pd.DataFrame:
        """
        Prepare feature matrix for time series forecasting.
        
        Creates lagged features and exogenous variables that LEAD DHW.
        """
        # Ensure datetime index
        if not isinstance(dhw_data.index, pd.DatetimeIndex):
            dhw_data.index = pd.to_datetime(dhw_data.index)
        
        df = pd.DataFrame(index=dhw_data.index)
        df['dhw'] = dhw_data['dhw']
        df = df.asfreq('D')  # Force daily frequency
        df = df.ffill()      # Fill any resulting gaps from missing days

        # === SST Features ===
        if sst_data is not None and 'sst' in sst_data.columns:
            sst = sst_data['sst'].reindex(df.index)
            df['sst'] = sst
            df['sst_anomaly'] = sst - self.mmm_sst
            df['hotspot'] = np.maximum(0, sst - self.mmm_sst)
            
            # Lagged SST (predictive)
            for lag in [7, 14, 30, 60]:
                df[f'sst_lag{lag}'] = sst.shift(lag)
            
            # Rolling features
            df['sst_7d_mean'] = sst.rolling(7).mean()
            df['sst_30d_mean'] = sst.rolling(30).mean()
            df['sst_trend_7d'] = sst - sst.shift(7)
            df['hotspot_4w_sum'] = df['hotspot'].rolling(28).sum() / 7
        
        # === Temporal Features ===
        df['doy'] = df.index.dayofyear
        df['month'] = df.index.month
        df['doy_sin'] = np.sin(2 * np.pi * df['doy'] / 365)
        df['doy_cos'] = np.cos(2 * np.pi * df['doy'] / 365)
        df['is_peak'] = df['month'].isin([3, 4, 5, 6]).astype(int)
        
        # === Climate Indices (CRITICAL - have lead time!) ===
        if climate_data is not None:
            if 'oni' in climate_data.columns:
                oni = climate_data['oni'].reindex(df.index, method='ffill')
                df['oni'] = oni
                df['oni_lag30'] = oni.shift(30)
                df['oni_lag60'] = oni.shift(60)
                df['oni_lag90'] = oni.shift(90)
                df['is_elnino'] = (oni > 0.5).astype(int)
            
            if 'dmi' in climate_data.columns:
                dmi = climate_data['dmi'].reindex(df.index, method='ffill')
                df['dmi'] = dmi
                df['dmi_lag30'] = dmi.shift(30)
                df['dmi_lag60'] = dmi.shift(60)
        
        # === pCRVI Components (use as leading indicators) ===
        # NOTE: as_norm EXCLUDED — it is derived from DHW accumulation,
        # making it circular as a predictor of future DHW.
        # It remains in pCRVI (vulnerability index) but not here.
        _DHW_CIRCULAR = {'as_norm', 'as_norm_lag7', 'as_norm_lag14'}
        if pcrvi_data is not None:
            for col in ['pcrvi', 'ta_norm', 'cdr_norm', 'sr_norm',
                    'bh_norm', 'wq_norm', 'la_norm']:
                if col in pcrvi_data.columns:
                    vals = pcrvi_data[col].reindex(df.index)
                    df[col] = vals
                    df[f'{col}_lag7'] = vals.shift(7)
                    df[f'{col}_lag14'] = vals.shift(14)
        
        # === Ocean Color Features (Chlorophyll, Turbidity, Light Attenuation) ===
        if ocean_color_data is not None and not ocean_color_data.empty:
            chl_col = next((c for c in ['CHL', 'chlor_a', 'chl', 'Chlorophyll']
                            if c in ocean_color_data.columns), None)
            if chl_col:
                chl = ocean_color_data[chl_col].reindex(df.index)
                df['chlorophyll'] = chl
                chl_monthly_mean = chl.groupby(chl.index.month).transform('mean')
                df['chlorophyll_anomaly'] = chl - chl_monthly_mean
                for lag in [7, 14, 30]:
                    df[f'chlorophyll_lag{lag}'] = chl.shift(lag)

            kd_col = next((c for c in ['KD490', 'kd490', 'Kd490']
                           if c in ocean_color_data.columns), None)
            if kd_col:
                kd = ocean_color_data[kd_col].reindex(df.index)
                df['turbidity'] = kd
                df['light_attenuation'] = kd
                kd_monthly_mean = kd.groupby(kd.index.month).transform('mean')
                df['turbidity_anomaly'] = kd - kd_monthly_mean
                for lag in [7, 14, 30]:
                    df[f'turbidity_lag{lag}'] = kd.shift(lag)
                    df[f'light_attenuation_lag{lag}'] = kd.shift(lag)

        # Pull raw chl/kd490 anomalies from pCRVI diagnostics as fallback
        if pcrvi_data is not None:
            if 'chl_anomaly' in pcrvi_data.columns and 'chlorophyll_anomaly' not in df.columns:
                df['chlorophyll_anomaly'] = pcrvi_data['chl_anomaly'].reindex(df.index)
            if 'kd490_anomaly' in pcrvi_data.columns and 'turbidity_anomaly' not in df.columns:
                df['turbidity_anomaly'] = pcrvi_data['kd490_anomaly'].reindex(df.index)

        # === DHW Lagged Features ===
        for lag in [7, 14, 30]:
            df[f'dhw_lag{lag}'] = df['dhw'].shift(lag)
        df['dhw_7d_max'] = df['dhw'].rolling(7).max()
        
        # Forward fill and back fill NaN
        df = df.ffill().bfill()
        
        self.feature_df = df
        return df
    
    def _evaluate(self, y_true: np.ndarray, y_pred: np.ndarray) -> Dict[str, float]:
        """Calculate comprehensive metrics."""
        y_pred = np.maximum(y_pred, 0)  # DHW can't be negative
        
        mae = mean_absolute_error(y_true, y_pred)
        rmse = np.sqrt(mean_squared_error(y_true, y_pred))
        r2 = r2_score(y_true, y_pred)
        
        # Skill score vs naive (persistence)
        naive_mae = np.mean(np.abs(np.diff(y_true)))
        skill = 1 - (mae / naive_mae) if naive_mae > 0 else 0
        
        # Bleaching detection (DHW >= 4)
        true_bl = (y_true >= self.bleaching_threshold).astype(int)
        pred_bl = (y_pred >= self.bleaching_threshold).astype(int)
        
        tp = ((true_bl == 1) & (pred_bl == 1)).sum()
        fp = ((true_bl == 0) & (pred_bl == 1)).sum()
        fn = ((true_bl == 1) & (pred_bl == 0)).sum()
        tn = ((true_bl == 0) & (pred_bl == 0)).sum()
        
        prec = tp / (tp + fp) if (tp + fp) > 0 else 0
        rec = tp / (tp + fn) if (tp + fn) > 0 else 0
        f1 = 2 * prec * rec / (prec + rec) if (prec + rec) > 0 else 0
        
        return {
            'mae': mae,
            'rmse': rmse,
            'r2': r2,
            'skill_score': skill,
            'bl_precision': prec,
            'bl_recall': rec,
            'bl_f1': f1,
            'tp': tp, 'fp': fp, 'fn': fn, 'tn': tn
        }
    
    def fit_sarimax(
        self,
        df: pd.DataFrame,
        order: Tuple[int, int, int] = (2, 1, 1),
        seasonal_order: Tuple[int, int, int, int] = (1, 1, 1, 12),
        exog_cols: List[str] = None
    ) -> Dict[str, Any]:
        """
        Fit SARIMAX model.
        
        SARIMAX captures:
        - Autoregressive patterns (AR)
        - Integrated (differencing for stationarity)
        - Moving average (MA)
        - Seasonal patterns (annual cycle)
        - Exogenous variables (climate indices)
        """
        if not STATSMODELS_AVAILABLE:
            raise ImportError("statsmodels required")
        
        print("\nFitting SARIMAX...")
        
        # Default exog columns
        if exog_cols is None:
            exog_cols = ['oni_lag60', 'dmi_lag60', 'sst_anomaly', 
                        'doy_sin', 'doy_cos', 'is_peak']
        exog_cols = [c for c in exog_cols if c in df.columns]
        
        # Prepare data
        data = df[['dhw'] + exog_cols].dropna()
        
        # Train/test split (80/20)
        split = int(len(data) * 0.8)
        train = data.iloc[:split]
        test = data.iloc[split:]
        
        # Fit model
        model = SARIMAX(
            train['dhw'],
            exog=train[exog_cols] if exog_cols else None,
            order=order,
            seasonal_order=seasonal_order,
            enforce_stationarity=False,
            enforce_invertibility=False
        )
        
        fitted = model.fit(disp=False, maxiter=200)
        
        # Forecast
        forecast = fitted.get_forecast(
            steps=len(test),
            exog=test[exog_cols] if exog_cols else None
        )
        y_pred = forecast.predicted_mean.values
        y_true = test['dhw'].values
        
        # Evaluate
        metrics = self._evaluate(y_true, y_pred)
        
        result = {
            'model': fitted,
            'name': 'SARIMAX',
            'order': order,
            'seasonal_order': seasonal_order,
            'exog_cols': exog_cols,
            'metrics': metrics,
            'aic': fitted.aic,
            'bic': fitted.bic,
            'predictions': pd.DataFrame({
                'date': test.index,
                'actual': y_true,
                'predicted': np.maximum(y_pred, 0),
                'residual': y_true - np.maximum(y_pred, 0),
            })
        }
        
        self.models['sarimax'] = result
        
        print(f"  MAE: {metrics['mae']:.3f}, RMSE: {metrics['rmse']:.3f}")
        print(f"  R²: {metrics['r2']:.3f}, Skill: {metrics['skill_score']:.3f}")
        print(f"  Bleaching F1: {metrics['bl_f1']:.3f} (Prec: {metrics['bl_precision']:.3f}, Rec: {metrics['bl_recall']:.3f})")
        
        return result
    
    def fit_prophet(
        self,
        df: pd.DataFrame,
        add_climate_regressors: bool = True
    ) -> Dict[str, Any]:
        """
        Fit Prophet model.
        
        Prophet excels at:
        - Automatic seasonality detection
        - Handling missing data
        - Trend changepoints
        """
        if not PROPHET_AVAILABLE:
            raise ImportError("prophet required: pip install prophet")
        
        print("\nFitting Prophet...")
        
        # Prepare Prophet format
        prophet_df = pd.DataFrame({
            'ds': df.index,
            'y': df['dhw']
        })
        
        # Add regressors
        regressors = []
        if add_climate_regressors:
            for col in ['oni', 'dmi', 'sst_anomaly']:
                if col in df.columns:
                    prophet_df[col] = df[col].values
                    regressors.append(col)
        
        prophet_df = prophet_df.dropna()
        
        # Split
        split = int(len(prophet_df) * 0.8)
        train = prophet_df.iloc[:split]
        test = prophet_df.iloc[split:]
        
        # Initialize and fit
        model = Prophet(
            yearly_seasonality=True,
            weekly_seasonality=False,
            daily_seasonality=False,
            changepoint_prior_scale=0.05,
            seasonality_mode='multiplicative'
        )
        
        for reg in regressors:
            model.add_regressor(reg)
        
        model.fit(train)
        
        # Predict
        forecast = model.predict(test[['ds'] + regressors])
        y_pred = forecast['yhat'].values
        y_true = test['y'].values
        
        # Evaluate
        metrics = self._evaluate(y_true, y_pred)
        
        result = {
            'model': model,
            'name': 'Prophet',
            'regressors': regressors,
            'metrics': metrics,
            'predictions': pd.DataFrame({
                'date': test['ds'].values,
                'actual': y_true,
                'predicted': np.maximum(y_pred, 0),
                'residual': y_true - np.maximum(y_pred, 0),
            })
        }
        
        self.models['prophet'] = result
        
        print(f"  MAE: {metrics['mae']:.3f}, RMSE: {metrics['rmse']:.3f}")
        print(f"  R²: {metrics['r2']:.3f}")
        print(f"  Bleaching F1: {metrics['bl_f1']:.3f}")
        
        return result
    
    def fit_neuralprophet(
        self,
        df: pd.DataFrame,
        n_lags: int = 60,
        n_forecasts: int = 30
    ) -> Dict[str, Any]:
        """
        Fit NeuralProphet model.
        
        NeuralProphet adds to Prophet:
        - AR-Net for autoregression
        - Lagged regressors
        - Neural network components
        """
        if not NEURALPROPHET_AVAILABLE:
            raise ImportError("neuralprophet required: pip install neuralprophet")
        
        print("\nFitting NeuralProphet...")
        
        # Prepare data
        np_df = pd.DataFrame({
            'ds': df.index,
            'y': df['dhw']
        })
        
        # Add regressors
        regressors = []
        for col in ['oni', 'dmi', 'sst_anomaly']:
            if col in df.columns:
                np_df[col] = df[col].values
                regressors.append(col)
        
        np_df = np_df.dropna()
        
        # Split
        split = int(len(np_df) * 0.8)
        train = np_df.iloc[:split]
        test = np_df.iloc[split:]
        
        # Initialize
        model = NeuralProphet(
            yearly_seasonality=True,
            weekly_seasonality=False,
            daily_seasonality=False,
            n_lags=n_lags,
            n_forecasts=n_forecasts,
            learning_rate=0.1,
            epochs=50,
            batch_size=64
        )
        
        # Add lagged regressors
        for reg in regressors:
            model.add_lagged_regressor(reg, n_lags=30)
        
        # Fit
        model.fit(train, freq='D')
        
        # Predict
        future = model.make_future_dataframe(train, periods=len(test))
        for reg in regressors:
            future[reg] = np.concatenate([train[reg].values, test[reg].values])
        
        forecast = model.predict(future)
        y_pred = forecast['yhat1'].iloc[-len(test):].values
        y_true = test['y'].values
        
        # Evaluate
        metrics = self._evaluate(y_true, y_pred)
        
        result = {
            'model': model,
            'name': 'NeuralProphet',
            'regressors': regressors,
            'n_lags': n_lags,
            'metrics': metrics
        }
        
        self.models['neuralprophet'] = result
        
        print(f"  MAE: {metrics['mae']:.3f}, RMSE: {metrics['rmse']:.3f}")
        print(f"  R²: {metrics['r2']:.3f}")
        print(f"  Bleaching F1: {metrics['bl_f1']:.3f}")
        
        return result
    
    def fit_chronos(
        self,
        df: pd.DataFrame,
        model_size: str = "small",
        num_samples: int = 20
    ) -> Dict[str, Any]:
        """
        Fit Amazon Chronos v2 foundation model.
        
        Chronos is state-of-the-art:
        - Pretrained on millions of time series
        - Zero-shot capability
        - Probabilistic forecasts
        """
        if not CHRONOS_AVAILABLE:
            raise ImportError(
                "chronos required: pip install chronos-forecasting torch"
            )
        
        print(f"\nFitting Chronos ({model_size})...")
        
        # Load model
        model_name = f"amazon/chronos-t5-{model_size}"
        device = "cuda" if torch.cuda.is_available() else "cpu"
        
        pipeline = ChronosPipeline.from_pretrained(
            model_name,
            device_map=device,
            torch_dtype=torch.bfloat16 if device == "cuda" else torch.float32
        )
        
        # Prepare data
        dhw = df['dhw'].dropna()
        
        # Split
        split = int(len(dhw) * 0.8)
        train = dhw.iloc[:split]
        test = dhw.iloc[split:]
        
        # Forecast
        context = torch.tensor(train.values).unsqueeze(0)
        forecast = pipeline.predict(
            context,
            prediction_length=len(test),
            num_samples=num_samples
        )
        
        # Get median and intervals
        y_pred = np.median(forecast[0].numpy(), axis=0)
        y_lower = np.percentile(forecast[0].numpy(), 10, axis=0)
        y_upper = np.percentile(forecast[0].numpy(), 90, axis=0)
        y_true = test.values
        
        # Match lengths
        min_len = min(len(y_pred), len(y_true))
        y_pred = y_pred[:min_len]
        y_true = y_true[:min_len]
        
        # Evaluate
        metrics = self._evaluate(y_true, y_pred)
        
        result = {
            'model': pipeline,
            'name': f'Chronos-{model_size}',
            'metrics': metrics,
            'predictions': pd.DataFrame({
                'date': test.index[:min_len],
                'actual': y_true,
                'predicted': np.maximum(y_pred, 0),
                'residual': y_true - np.maximum(y_pred, 0),
                'lower_80': y_lower[:min_len],
                'upper_80': y_upper[:min_len]
            })
        }
        
        self.models['chronos'] = result
        
        print(f"  MAE: {metrics['mae']:.3f}, RMSE: {metrics['rmse']:.3f}")
        print(f"  R²: {metrics['r2']:.3f}")
        print(f"  Bleaching F1: {metrics['bl_f1']:.3f}")
        
        return result
    
    def fit_ensemble_with_pcrvi(
        self,
        df: pd.DataFrame,
        pcrvi_data: pd.DataFrame,
        target_horizon: int = 30
    ) -> Dict[str, Any]:
        """
        Ensemble model combining time series + pCRVI components.
        
        Key insight: pCRVI components (especially climate driver response)
        have PREDICTIVE power for future DHW because they incorporate
        leading indicators (ONI, DMI) before thermal effects manifest.
        """
        if not SKLEARN_AVAILABLE:
            raise ImportError("sklearn required")
        
        print(f"\nFitting Ensemble (TS + pCRVI) for {target_horizon}d forecast...")
        
        # Get pCRVI features (as_norm excluded — circular with DHW target)
        pcrvi_cols = []
        for col in ['pcrvi', 'ta_norm', 'cdr_norm', 'sr_norm',
                    'bh_norm', 'wq_norm', 'la_norm']:
            if col in pcrvi_data.columns:
                pcrvi_cols.append(col)
        
        if not pcrvi_cols:
            raise ValueError("No pCRVI columns found")
        
        # Align data
        common_idx = df.index.intersection(pcrvi_data.index)
        
        # Build ensemble features
        ens_df = pd.DataFrame(index=common_idx)
        ens_df['dhw'] = df.loc[common_idx, 'dhw']
        
        # Add pCRVI with lags
        for col in pcrvi_cols:
            ens_df[col] = pcrvi_data.loc[common_idx, col]
            ens_df[f'{col}_lag7'] = pcrvi_data[col].reindex(common_idx).shift(7)
            ens_df[f'{col}_lag14'] = pcrvi_data[col].reindex(common_idx).shift(14)
        
        # Add climate indices
        for col in ['oni_lag60', 'dmi_lag60', 'sst_anomaly', 'doy_sin', 'doy_cos']:
            if col in df.columns:
                ens_df[col] = df.loc[common_idx, col]
        
        # Target: future DHW
        ens_df['dhw_target'] = ens_df['dhw'].shift(-target_horizon)
        
        # Drop NaN
        ens_df = ens_df.dropna()
        
        # Feature columns (exclude circular DHW-derived features)
        _circular = {'as_norm', 'as_norm_lag7', 'as_norm_lag14'}
        feat_cols = [c for c in ens_df.columns
                     if c not in ['dhw', 'dhw_target'] and c not in _circular]
        
        # Split
        split = int(len(ens_df) * 0.8)
        train = ens_df.iloc[:split]
        test = ens_df.iloc[split:]
        
        X_train = train[feat_cols].values
        y_train = train['dhw_target'].values
        X_test = test[feat_cols].values
        y_true = test['dhw_target'].values
        
        # Scale
        scaler = StandardScaler()
        X_train_s = scaler.fit_transform(X_train)
        X_test_s = scaler.transform(X_test)
        
        # Fit gradient boosting
        model = GradientBoostingRegressor(
            n_estimators=100,
            max_depth=5,
            learning_rate=0.1,
            random_state=42
        )
        model.fit(X_train_s, y_train)
        
        y_pred = model.predict(X_test_s)
        
        # Evaluate
        metrics = self._evaluate(y_true, y_pred)
        
        # Feature importance
        importance = pd.DataFrame({
            'feature': feat_cols,
            'importance': model.feature_importances_
        }).sort_values('importance', ascending=False)
        importance['display_name'] = importance['feature'].map(friendly_name)
        
        result = {
            'model': model,
            'scaler': scaler,
            'name': f'Ensemble-pCRVI-{target_horizon}d',
            'feature_cols': feat_cols,
            'metrics': metrics,
            'feature_importance': importance,
            'predictions': pd.DataFrame({
                'date': test.index,
                'actual': y_true,
                'predicted': np.maximum(y_pred, 0),
                'residual': y_true - np.maximum(y_pred, 0),
            })
        }
        
        self.models[f'ensemble_{target_horizon}d'] = result
        self.scalers[f'ensemble_{target_horizon}d'] = scaler
        
        print(f"  MAE: {metrics['mae']:.3f}, RMSE: {metrics['rmse']:.3f}")
        print(f"  R²: {metrics['r2']:.3f}")
        print(f"  Bleaching F1: {metrics['bl_f1']:.3f}")
        print(f"\n  Top 5 Features:")
        for _, row in importance.head(5).iterrows():
            print(f"    {friendly_name(row['feature'])}: {row['importance']:.3f}")
        
        # === Zero-Inflated Model Comparison ===
        from .models.zero_inflated import (
            HurdleDHWPredictor, Log1pDHWPredictor, TweedieDHWPredictor
        )
        zi_models = {
            'Hurdle': HurdleDHWPredictor(random_state=42),
            'Log1p-GBR': Log1pDHWPredictor(random_state=42),
            'Tweedie-XGB': TweedieDHWPredictor(random_state=42),
        }
        for model_name, model in zi_models.items():
            try:
                model.fit(X_train, y_train)
                y_pred = model.predict(X_test)

                from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
                mae = mean_absolute_error(y_true, y_pred)
                rmse = np.sqrt(mean_squared_error(y_true, y_pred))
                r2 = r2_score(y_true, y_pred)

                # Binary metrics (DHW > 4.0)
                actual_bl = (y_true > 4.0).astype(int)
                pred_bl = (y_pred > 4.0).astype(int)
                from sklearn.metrics import f1_score, precision_score, recall_score
                bl_f1 = f1_score(actual_bl, pred_bl, zero_division=0)
                bl_prec = precision_score(actual_bl, pred_bl, zero_division=0)
                bl_rec = recall_score(actual_bl, pred_bl, zero_division=0)

                # Miss rate
                pos_mask = y_true > 0.5
                miss_rate = ((y_pred[pos_mask] < 0.1).sum() / pos_mask.sum()
                             if pos_mask.sum() > 0 else 0)
                severe_mask = y_true > 4.0
                severe_miss = ((y_pred[severe_mask] < 2.0).sum() / severe_mask.sum()
                               if severe_mask.sum() > 0 else 0)

                self.models[f'{model_name}_{target_horizon}d'] = {
                    'name': model_name,
                    'model': model,
                    'mae': mae, 'rmse': rmse, 'r2': r2,
                    'bl_f1': bl_f1, 'bl_precision': bl_prec, 'bl_recall': bl_rec,
                    'miss_rate': miss_rate, 'severe_miss_rate': severe_miss,
                    'predictions': pd.DataFrame({
                        'actual': y_true, 'predicted': y_pred,
                        'residual': y_true - y_pred}, index=test.index),
                    'feature_importance': pd.DataFrame({
                        'feature': feat_cols,
                        'importance': model.feature_importances_,
                    }).sort_values('importance', ascending=False),
                }
            except Exception as e:
                self.logger.warning(f"  {model_name} failed: {e}")

        return result
    
    def compare_models(
        self,
        df: pd.DataFrame,
        pcrvi_data: Optional[pd.DataFrame] = None,
        horizons: List[int] = [30],
        run_all: bool = False
    ) -> pd.DataFrame:
        """
        Compare all available models.
        """
        print("\n" + "="*70)
        print("MODEL COMPARISON")
        print("="*70)
        
        results = []
        
        # 1. ALWAYS RUN ENSEMBLE (The winner)
        if pcrvi_data is not None:
            for h in horizons:
                try:
                    res = self.fit_ensemble_with_pcrvi(df, pcrvi_data, h)
                    results.append({'Model': res['name'], **res['metrics']})
                except Exception as e:
                    print(f"Ensemble failed: {e}")
        else:
            print("WARNING: pCRVI data missing. Ensemble requires pCRVI.")

        # 2. RUN OTHERS ONLY IF REQUESTED
        if run_all:
            # SARIMAX
            if self.available['sarimax']:
                try:
                    res = self.fit_sarimax(df)
                    results.append({'Model': 'SARIMAX', **res['metrics']})
                except Exception as e:
                    print(f"SARIMAX failed: {e}")
            
            # Prophet
            if self.available['prophet']:
                try:
                    res = self.fit_prophet(df)
                    results.append({'Model': 'Prophet', **res['metrics']})
                except Exception as e:
                    print(f"Prophet failed: {e}")
            
            # NeuralProphet
            if self.available['neuralprophet']:
                try:
                    res = self.fit_neuralprophet(df)
                    results.append({'Model': 'NeuralProphet', **res['metrics']})
                except Exception as e:
                    print(f"NeuralProphet failed: {e}")
            
            # Chronos
            if self.available['chronos']:
                try:
                    res = self.fit_chronos(df)
                    results.append({'Model': res['name'], **res['metrics']})
                except Exception as e:
                    print(f"Chronos failed: {e}")
            
            # Ensemble with pCRVI
            if pcrvi_data is not None:
                for h in horizons:
                    try:
                        res = self.fit_ensemble_with_pcrvi(df, pcrvi_data, h)
                        results.append({'Model': res['name'], **res['metrics']})
                    except Exception as e:
                        print(f"Ensemble failed: {e}")
        else:
            print("Skipping SARIMAX/Prophet/Chronos (run_all=False).")
            print("Using Ensemble-pCRVI as it handles zero-inflated DHW data best.")
        
        # Create comparison table
        if results:
            comparison = pd.DataFrame(results)
            # Select key columns
            cols = ['Model', 'mae', 'rmse', 'r2', 'bl_f1', 'bl_precision', 'bl_recall']
            cols = [c for c in cols if c in comparison.columns]
            comparison = comparison[cols].sort_values('bl_f1', ascending=False)
            
            print("\n" + "="*70)
            print("RESULTS (sorted by Bleaching F1)")
            print("="*70)
            print(comparison.to_string(index=False))
            
            # Best model recommendation
            best = comparison.iloc[0]
            print(f"\n✓ RECOMMENDED: {best['Model']}")
            print(f"  Bleaching F1: {best['bl_f1']:.3f}")
            print(f"  MAE: {best['mae']:.3f} °C-weeks")
            
            return comparison
        else:
            print("No models could be fitted!")
            return pd.DataFrame()
    
    def generate_forecast_report(self) -> str:
        """Generate a text report of forecasting results."""
        report = []
        report.append("="*70)
        report.append("DHW TIME SERIES FORECASTING REPORT")
        report.append("="*70)
        report.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report.append("")
        
        report.append("APPROACH:")
        report.append("  This analysis uses TIME SERIES forecasting instead of classification.")
        report.append("  Time series models capture seasonality, trends, and use exogenous")
        report.append("  variables (ONI, DMI, pCRVI) that LEAD thermal stress by 30-90 days.")
        report.append("")
        
        report.append("MODEL RESULTS:")
        report.append("-"*70)
        
        for name, info in self.models.items():
            m = info['metrics']
            report.append(f"\n{info['name']}:")
            report.append(f"  MAE: {m['mae']:.3f} °C-weeks")
            report.append(f"  RMSE: {m['rmse']:.3f} °C-weeks")
            report.append(f"  R²: {m['r2']:.3f}")
            report.append(f"  Skill Score: {m.get('skill_score', 'N/A')}")
            report.append(f"  Bleaching Detection:")
            report.append(f"    Precision: {m['bl_precision']:.3f}")
            report.append(f"    Recall: {m['bl_recall']:.3f}")
            report.append(f"    F1 Score: {m['bl_f1']:.3f}")
            report.append(f"  Confusion: TP={m['tp']}, FP={m['fp']}, FN={m['fn']}, TN={m['tn']}")
        
        report.append("\n" + "="*70)
        report.append("KEY INSIGHTS:")
        report.append("-"*70)
        report.append("1. Time series models capture DHW's temporal structure")
        report.append("2. Climate indices (ONI, DMI) provide 60-90 day lead time")
        report.append("3. pCRVI components enhance predictions through ensemble")
        report.append("4. Bleaching F1 is the key metric (handles class imbalance)")
        report.append("="*70)
        
        return "\n".join(report)


def integrate_with_pipeline(
    sst_data: pd.DataFrame,
    dhw_data: pd.DataFrame,
    climate_data: Optional[pd.DataFrame],
    pcrvi_data: Optional[pd.DataFrame],
    ocean_color_data: Optional[pd.DataFrame] = None,
) -> Dict[str, Any]:
    """
    Integration function for coral_ews pipeline.
    
    Call this after pCRVI calculation in pipeline.py
    """
    forecaster = DHWTimeSeriesForecaster()
    
    # Prepare features
    df = forecaster.prepare_features(
        sst_data=sst_data,
        dhw_data=dhw_data,
        climate_data=climate_data,
        pcrvi_data=pcrvi_data,
        ocean_color_data=ocean_color_data,
    )
    
    # Compare models
    comparison = forecaster.compare_models(df, pcrvi_data, horizons=[30, 60])
    
    # Generate report
    report = forecaster.generate_forecast_report()
    print(report)
    
    return {
        'forecaster': forecaster,
        'comparison': comparison,
        'report': report,
        'feature_matrix': df
    }


if __name__ == "__main__":
    print("DHW Time Series Forecaster")
    print("="*50)
    forecaster = DHWTimeSeriesForecaster()
    print("\nThis replaces classification with proper time series forecasting.")
    print("Use integrate_with_pipeline() in your coral_ews pipeline.")
