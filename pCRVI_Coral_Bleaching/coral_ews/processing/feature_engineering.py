"""
Feature Engineering Module
===========================

Processes raw satellite data into features for machine learning:
- Anomaly calculation
- Temporal aggregation
- Lag features
- Derived variables

Based on methodology from:
- Cheung et al. 2025 (Global Ecology and Biogeography)
- Sully & van Woesik 2020 (turbidity-bleaching relationship)
"""

from typing import Optional, Union, List, Dict, Any, Tuple
from datetime import datetime, date, timedelta
from pathlib import Path

import numpy as np
import pandas as pd

from ..exceptions import ProcessingError, ValidationError
from ..logger import get_logger, log_execution_time, ProgressLogger
from ..config import Config, MLParameters


class FeatureEngineer:
    """
    Feature engineering for coral bleaching prediction.
    
    Creates standardized features from raw satellite data including:
    - SST and DHW (primary thermal stress indicators)
    - Ocean color anomalies (Kd490, Chlorophyll-a)
    - Atmospheric variables (cloud cover, wind speed)
    - Ocean dynamics (current speed)
    - Climate indices with lags (ONI, DMI)
    """
    
    def __init__(self, config: Optional[Config] = None):
        """
        Initialize feature engineer.
        
        Parameters
        ----------
        config : Config, optional
            Configuration object
        """
        self.config = config or Config()
        self.logger = get_logger("coral_ews.features")
        self.ml_params = self.config.ml_params
    
    @log_execution_time()
    def calculate_climatology(
        self,
        data: pd.DataFrame,
        variable: str,
        baseline_start: str = '2002-01-01',
        baseline_end: str = '2020-12-31',
        method: str = 'monthly'
    ) -> pd.Series:
        """
        Calculate climatological baseline for a variable.
        
        Parameters
        ----------
        data : pd.DataFrame
            Input data with datetime index
        variable : str
            Variable column name
        baseline_start : str
            Baseline period start date
        baseline_end : str
            Baseline period end date
        method : str
            'monthly' or 'daily' climatology
        
        Returns
        -------
        pd.Series
            Climatology values indexed by day-of-year or month
        """
        self.logger.info(
            f"Calculating {method} climatology for {variable}\n"
            f"  Baseline: {baseline_start} to {baseline_end}"
        )
        
        if variable not in data.columns:
            raise ValidationError(
                f"Variable '{variable}' not found in data",
                field="variable",
                expected=list(data.columns),
                actual=variable
            )
        
        # Filter to baseline period
        baseline_data = data.loc[baseline_start:baseline_end, variable]
        
        if len(baseline_data) == 0:
            raise ValidationError(
                "No data in baseline period",
                field="baseline_period",
                context={"start": baseline_start, "end": baseline_end}
            )
        
        if method == 'monthly':
            climatology = baseline_data.groupby(baseline_data.index.month).mean()
            climatology.index.name = 'month'
        elif method == 'daily':
            climatology = baseline_data.groupby(baseline_data.index.dayofyear).mean()
            climatology.index.name = 'dayofyear'
        else:
            raise ValidationError(
                f"Invalid climatology method: {method}",
                field="method",
                expected=['monthly', 'daily'],
                actual=method
            )
        
        self.logger.info(f"Climatology calculated: {len(climatology)} values")
        return climatology
    
    @log_execution_time()
    def calculate_anomaly(
        self,
        data: pd.DataFrame,
        variable: str,
        climatology: Optional[pd.Series] = None,
        baseline_start: str = '2002-01-01',
        baseline_end: str = '2020-12-31'
    ) -> pd.Series:
        """
        Calculate anomaly for a variable.
        
        Anomaly = Observed - Climatology
        
        Parameters
        ----------
        data : pd.DataFrame
            Input data with datetime index
        variable : str
            Variable column name
        climatology : pd.Series, optional
            Pre-calculated climatology
        baseline_start : str
            Baseline period start (if climatology not provided)
        baseline_end : str
            Baseline period end
        
        Returns
        -------
        pd.Series
            Anomaly values
        """
        self.logger.info(f"Calculating anomaly for {variable}")
        
        if variable not in data.columns:
            raise ValidationError(
                f"Variable '{variable}' not found",
                field="variable"
            )
        
        # Calculate climatology if not provided
        if climatology is None:
            climatology = self.calculate_climatology(
                data, variable, baseline_start, baseline_end
            )
        
        # Determine climatology type
        if climatology.index.name == 'month':
            grouper = data.index.month
        else:
            grouper = data.index.dayofyear
        
        # Calculate anomaly
        clim_values = grouper.map(climatology)
        anomaly = data[variable] - clim_values
        anomaly.name = f"{variable}_anomaly"
        
        self.logger.info(
            f"Anomaly calculated:\n"
            f"  Range: {anomaly.min():.3f} to {anomaly.max():.3f}\n"
            f"  Mean: {anomaly.mean():.3f}"
        )
        
        return anomaly
    
    def calculate_wind_speed(
        self,
        u_wind: pd.Series,
        v_wind: pd.Series
    ) -> pd.Series:
        """
        Calculate wind speed from u and v components.
        
        Speed = sqrt(u² + v²)
        
        Parameters
        ----------
        u_wind : pd.Series
            U (eastward) wind component
        v_wind : pd.Series
            V (northward) wind component
        
        Returns
        -------
        pd.Series
            Wind speed
        """
        speed = np.sqrt(u_wind**2 + v_wind**2)
        speed.name = 'wind_speed'
        return speed
    
    def calculate_current_speed(
        self,
        u_current: pd.Series,
        v_current: pd.Series
    ) -> pd.Series:
        """
        Calculate ocean current speed from u and v components.
        
        Parameters
        ----------
        u_current : pd.Series
            U (eastward) current component
        v_current : pd.Series
            V (northward) current component
        
        Returns
        -------
        pd.Series
            Current speed
        """
        speed = np.sqrt(u_current**2 + v_current**2)
        speed.name = 'current_speed'
        return speed
    
    def add_temporal_features(
        self,
        data: pd.DataFrame
    ) -> pd.DataFrame:
        """
        Add temporal features to DataFrame.
        
        Features added:
        - month (1-12)
        - day_of_year (1-366)
        - is_peak_season (boolean)
        
        Parameters
        ----------
        data : pd.DataFrame
            Input data with datetime index
        
        Returns
        -------
        pd.DataFrame
            DataFrame with added temporal features
        """
        result = data.copy()
        
        result['month'] = result.index.month
        result['day_of_year'] = result.index.dayofyear
        
        # Peak bleaching season for Indian Ocean: April-June
        peak_months = self.config.region.peak_season_months
        result['is_peak_season'] = result['month'].isin(peak_months).astype(int)
        
        return result
    
    def add_rolling_features(
        self,
        data: pd.DataFrame,
        variables: List[str],
        windows: List[int] = [7, 14, 30],
        statistics: List[str] = ['mean', 'std', 'max']
    ) -> pd.DataFrame:
        """
        Add rolling window statistics as features.
        
        Parameters
        ----------
        data : pd.DataFrame
            Input data
        variables : list
            Variables to calculate rolling stats for
        windows : list
            Window sizes in days
        statistics : list
            Statistics to calculate ('mean', 'std', 'max', 'min')
        
        Returns
        -------
        pd.DataFrame
            DataFrame with added rolling features
        """
        result = data.copy()
        
        for var in variables:
            if var not in data.columns:
                self.logger.warning(f"Variable '{var}' not found, skipping")
                continue
            
            for window in windows:
                rolling = data[var].rolling(window=window, min_periods=1)
                
                for stat in statistics:
                    col_name = f"{var}_rolling{window}d_{stat}"
                    
                    if stat == 'mean':
                        result[col_name] = rolling.mean()
                    elif stat == 'std':
                        result[col_name] = rolling.std()
                    elif stat == 'max':
                        result[col_name] = rolling.max()
                    elif stat == 'min':
                        result[col_name] = rolling.min()
        
        n_new_features = len(result.columns) - len(data.columns)
        self.logger.info(f"Added {n_new_features} rolling features")
        
        return result
    
    @log_execution_time()
    def build_feature_matrix(
        self,
        sst_data: pd.DataFrame,
        ocean_color_data: Optional[pd.DataFrame] = None,
        atmospheric_data: Optional[pd.DataFrame] = None,
        current_data: Optional[pd.DataFrame] = None,
        climate_indices: Optional[pd.DataFrame] = None,
        dhw_data: Optional[pd.DataFrame] = None
    ) -> pd.DataFrame:
        """
        Build complete feature matrix from all data sources.
        
        Parameters
        ----------
        sst_data : pd.DataFrame
            SST data (required, with 'sst' column)
        ocean_color_data : pd.DataFrame, optional
            Ocean color data (Kd490, chlor_a)
        atmospheric_data : pd.DataFrame, optional
            Atmospheric data (cloud_cover, wind)
        current_data : pd.DataFrame, optional
            Ocean current data
        climate_indices : pd.DataFrame, optional
            Climate indices (ONI, DMI with lags)
        dhw_data : pd.DataFrame, optional
            Pre-calculated DHW data
        
        Returns
        -------
        pd.DataFrame
            Complete feature matrix
        """
        self.logger.info("Building feature matrix...")
        
        # Start with SST as base
        if 'sst' not in sst_data.columns:
            raise ValidationError(
                "SST data must contain 'sst' column",
                field="sst_data.columns"
            )
        
        # Initialize with SST
        features = sst_data[['sst']].copy()
        
        # Add SST anomaly
        sst_anomaly = self.calculate_anomaly(sst_data, 'sst')
        features['sst_anomaly'] = sst_anomaly
        
        # Add DHW if provided
        if dhw_data is not None and 'dhw' in dhw_data.columns:
            features = features.join(dhw_data[['dhw', 'hotspot']], how='left')
        
        # Add ocean color data
        if ocean_color_data is not None:
            for var in ['Kd490', 'KD490', 'kd490', 'chlor_a', 'CHL']:
                if var in ocean_color_data.columns:
                    # Use standardized name
                    std_name = var.lower()
                    if 'kd' in std_name:
                        std_name = 'kd490'
                    elif 'chl' in std_name:
                        std_name = 'chlor_a'
                    
                    features[std_name] = ocean_color_data[var]
                    
                    # Add anomaly
                    try:
                        anomaly = self.calculate_anomaly(ocean_color_data, var)
                        features[f'{std_name}_anomaly'] = anomaly
                    except Exception as e:
                        self.logger.warning(f"Could not calculate {var} anomaly: {e}")
        
        # Add atmospheric data
        if atmospheric_data is not None:
            if 'cloud_cover' in atmospheric_data.columns:
                features['cloud_cover'] = atmospheric_data['cloud_cover']
            
            # Calculate wind speed if components available
            if 'u_wind' in atmospheric_data.columns and 'v_wind' in atmospheric_data.columns:
                features['wind_speed'] = self.calculate_wind_speed(
                    atmospheric_data['u_wind'],
                    atmospheric_data['v_wind']
                )
            elif 'wind_speed' in atmospheric_data.columns:
                features['wind_speed'] = atmospheric_data['wind_speed']
        
        # Add current data
        if current_data is not None:
            if 'current_speed' in current_data.columns:
                features['current_speed'] = current_data['current_speed']
            elif 'u_current' in current_data.columns and 'v_current' in current_data.columns:
                features['current_speed'] = self.calculate_current_speed(
                    current_data['u_current'],
                    current_data['v_current']
                )
        
         # Add climate indices (monthly → daily via forward-fill)
        if climate_indices is not None:
            for col in climate_indices.columns:
                if 'oni' in col.lower() or 'dmi' in col.lower():
                    features[col] = climate_indices[col]
            # Forward-fill: monthly indices → daily rows
            if 'oni' in features.columns:
                features['oni'] = features['oni'].ffill()
            if 'dmi' in features.columns:
                features['dmi'] = features['dmi'].ffill()
        
        # Add temporal features
        features = self.add_temporal_features(features)
        
        # Log feature matrix info
        self.logger.info(
            f"Feature matrix built:\n"
            f"  Shape: {features.shape}\n"
            f"  Features: {list(features.columns)}\n"
            f"  Date range: {features.index.min()} to {features.index.max()}\n"
            f"  Missing values: {features.isna().sum().sum()}"
        )
        
        return features
    
    def prepare_for_training(
        self,
        feature_matrix: pd.DataFrame,
        target: pd.Series,
        feature_columns: Optional[List[str]] = None,
        drop_na: bool = True,
        scale_features: bool = True
    ) -> Tuple[np.ndarray, np.ndarray, List[str]]:
        """
        Prepare feature matrix for model training.
        
        Parameters
        ----------
        feature_matrix : pd.DataFrame
            Feature matrix
        target : pd.Series
            Target variable (bleaching severity)
        feature_columns : list, optional
            Columns to use as features (default: from config)
        drop_na : bool
            Whether to drop rows with missing values
        scale_features : bool
            Whether to standardize features
        
        Returns
        -------
        tuple
            (X, y, feature_names)
        """
        self.logger.info("Preparing data for training...")
        
        # Use default features if not specified
        if feature_columns is None:
            feature_columns = self.ml_params.features
        
        # Filter to available features
        available_features = [f for f in feature_columns if f in feature_matrix.columns]
        missing_features = [f for f in feature_columns if f not in feature_matrix.columns]
        
        if missing_features:
            self.logger.warning(f"Features not available: {missing_features}")
        
        if not available_features:
            raise ValidationError(
                "No features available for training",
                field="feature_columns",
                expected=feature_columns,
                actual=list(feature_matrix.columns)
            )
        
        # Extract features and target
        X = feature_matrix[available_features].copy()
        y = target.loc[X.index].copy()
        
        # Handle missing values
        if drop_na:
            valid_mask = ~(X.isna().any(axis=1) | y.isna())
            n_dropped = (~valid_mask).sum()
            if n_dropped > 0:
                self.logger.info(f"Dropping {n_dropped} rows with missing values")
            X = X.loc[valid_mask]
            y = y.loc[valid_mask]
        
        # Scale features
        if scale_features:
            from sklearn.preprocessing import StandardScaler
            scaler = StandardScaler()
            X_scaled = scaler.fit_transform(X)
        else:
            X_scaled = X.values
        
        self.logger.info(
            f"Training data prepared:\n"
            f"  Samples: {len(X)}\n"
            f"  Features: {len(available_features)}\n"
            f"  Target classes: {np.unique(y)}"
        )
        
        return X_scaled, y.values, available_features
