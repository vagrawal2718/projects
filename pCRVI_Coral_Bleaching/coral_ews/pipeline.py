"""
Coral Bleaching EWS Pipeline
=============================

Main orchestration module that ties together all components:
1. Data acquisition from multiple sources
2. DHW calculation
3. Feature engineering
4. Model training and prediction
5. Output generation

This provides a high-level interface for running the complete workflow.
"""

from typing import Optional, Dict, List, Any, Union, Tuple
from datetime import datetime, date, timedelta
from pathlib import Path
import json

import numpy as np
import pandas as pd


from .config import Config, ANIRegion
from .logger import get_logger, setup_logger, log_execution_time, ProgressLogger
from .exceptions import (
    CoralEWSError, DataAcquisitionError, ProcessingError, 
    ModelError, ValidationError, GEEError, CopernicusError
)
from .data_acquisition import GEEClient, CopernicusClient, NOAAClient, ClimateIndicesClient
from .processing import DHWCalculator, FeatureEngineer
from .models import BleachingPredictor, evaluate_model
from .outputs import OutputManager
from .visualization import Visualizer
from .enhanced_pcrvi import EnhancedPCRVI, DEFAULT_WEIGHTS
from .poster_visualizations import PosterVisualizer
from .data_cache import DataCache
from .models.xgboost_model import XGBoostPredictor, compare_models
from .dhw_forecaster import DHWTimeSeriesForecaster, integrate_with_pipeline

class CoralBleachingEWS:
    """
    Main orchestration class for Coral Bleaching Early Warning System.
    
    This class provides a high-level interface for the complete workflow:
    - Data acquisition from GEE, Copernicus, NOAA
    - DHW calculation
    - Feature engineering
    - Model training and prediction
    - Weekly risk assessment output
    """

    def __init__(
        self,
        config: Optional[Config] = None,
        region_key: Optional[str] = None,
        gee_project_id: Optional[str] = None,
        copernicus_username: Optional[str] = None,
        copernicus_password: Optional[str] = None,
        log_level: int = 20  # INFO
    ):
        """
        Initialize the Coral Bleaching EWS.
        
        This system uses Predictive CRVI (pCRVI) as the PRIMARY vulnerability index.
        Traditional CRVI is only calculated for comparison purposes.
        """
        # Setup configuration
        if config is not None:
            self.config = config
        elif region_key:
            self.config = Config.for_region(region_key)
        else:
            self.config = Config()  # defaults to ANI
        
        # Setup logging
        self.logger = setup_logger(
            name="coral_ews",
            level=log_level,
            log_dir=self.config.log_dir
        )
        
        self.logger.info("=" * 60)
        self.logger.info("Coral Bleaching Early Warning System - Initializing")
        self.logger.info("Primary Vulnerability Index: pCRVI")
        self.logger.info("=" * 60)
        self.logger.info(f"Study region: {self.config.region.name}")
        self.logger.info(f"Bounds: {self.config.region.bounds}")
        self.logger.info(f"MMM SST: {self.config.region.mmm_sst}°C")
        
        # Initialize clients (lazily)
        self._gee_project_id = gee_project_id
        self._copernicus_username = copernicus_username
        self._copernicus_password = copernicus_password
        
        self._gee_client = None
        self._copernicus_client = None
        self._noaa_client = None
        self._climate_client = None
        # DHW Time Series Forecaster results
        self._dhw_forecaster = None
        self._forecast_comparison = None
        
        # Initialize processors
        self.dhw_calculator = DHWCalculator(config=self.config)
        self.feature_engineer = FeatureEngineer(config=self.config)
        self.predictor = BleachingPredictor(config=self.config)

        # Enhanced pCRVI (7-component) — PRIMARY VULNERABILITY INDEX
        self._enhanced_pcrvi_ts = None
        self._enhanced_pcrvi_skill = None
        self._enhanced_pcrvi_weekly = None
        self._ml_weight_results = None

        # Initialize data cache
        self.data_cache = DataCache(cache_dir=self.config.data_dir)
        
        # Predictive CRVI (pCRVI) results - PRIMARY VULNERABILITY INDEX
        self._pcrvi_timeseries = None
        self._pcrvi_skill = None
        self._pcrvi_predictions = None
        
        # Historical validation results
        self._historical_validation = None
        self._dhw_validation_df = None  # Store DHW validation for comprehensive report
        
        # Model comparison results
        self._model_comparison = None
        
        # Data storage
        self._sst_data = None
        self._dhw_data = None
        self._ocean_color_data = None
        self._atmospheric_data = None
        self._current_data = None
        self._climate_indices = None
        self._feature_matrix = None
        
        self.logger.info("Initialization complete")
    
    @property
    def gee_client(self) -> GEEClient:
        """Lazy initialization of GEE client."""
        if self._gee_client is None:
            self._gee_client = GEEClient(
                config=self.config,
                project_id=self._gee_project_id
            )
        return self._gee_client
    
    @property
    def copernicus_client(self) -> CopernicusClient:
        """Lazy initialization of Copernicus client."""
        if self._copernicus_client is None:
            self._copernicus_client = CopernicusClient(
                config=self.config,
                username=self._copernicus_username,
                password=self._copernicus_password
            )
        return self._copernicus_client
    
    @property
    def noaa_client(self) -> NOAAClient:
        """Lazy initialization of NOAA client."""
        if self._noaa_client is None:
            self._noaa_client = NOAAClient(config=self.config)
        return self._noaa_client
    
    @property
    def climate_client(self) -> ClimateIndicesClient:
        """Lazy initialization of climate indices client."""
        if self._climate_client is None:
            self._climate_client = ClimateIndicesClient(config=self.config)
        return self._climate_client
    
    @log_execution_time()
    def acquire_sst_data(
        self,
        start_date: Union[str, date],
        end_date: Union[str, date],
        source: str = 'gee',
        use_chunked: bool = True,
        sst_reducer: str = 'mean'
    ) -> pd.DataFrame:
        """
        Acquire SST data with caching support.
        
        Parameters
        ----------
        start_date, end_date : str or date
            Date range
        source : str
            Data source ('gee' or 'noaa_vs')
        use_chunked : bool
            Whether to use chunked extraction
        sst_reducer : str
            Reducer method for SST extraction. Options:
            - 'mean': Simple mean (default, may underestimate hotspots)
            - 'median': Median value
            - 'mean_plus_1sd': Mean + 1 standard deviation (captures warmer areas)
            - 'mean_plus_2sd': Mean + 2 standard deviations (captures hotspots)
            - 'median_plus_1sd': Median + 1 standard deviation
            - 'percentile_90': 90th percentile
            - 'percentile_95': 95th percentile
            
            Recommendation: Use 'mean_plus_1sd' or 'percentile_90' to better capture
            bleaching hotspots instead of averaging them out.
        """
        self.logger.info(f"Acquiring SST data from {source}: {start_date} to {end_date} (reducer={sst_reducer})")
        
        # Check cache first (include reducer in cache key)
        cache_suffix = f"_{sst_reducer}" if sst_reducer != 'mean' else ""
        cached_df = self.data_cache.load_csv('sst', str(start_date), str(end_date), suffix=cache_suffix)
        if cached_df is not None:
            self._sst_data = cached_df
            self.logger.info(f"Loaded SST from cache: {len(cached_df)} records (reducer={sst_reducer})")
            return cached_df
        
        # Calculate date range
        start_dt = datetime.strptime(str(start_date), "%Y-%m-%d")
        end_dt = datetime.strptime(str(end_date), "%Y-%m-%d")
        total_days = (end_dt - start_dt).days
        
        try:
            if source == 'gee':
                self.gee_client.authenticate()
                
                # Use chunked extraction for long date ranges (> 3 years)
                if use_chunked and total_days > 1095:
                    self.logger.info(f"Using chunked acquisition for {total_days} days with {sst_reducer} reducer")
                    sst_df = self.gee_client.extract_timeseries_chunked(
                        start_date=start_date,
                        end_date=end_date,
                        band='sst',
                        reducer=sst_reducer,
                        chunk_size_days=365,
                        cache_dir=self.config.data_dir
                    )
                else:
                    collection = self.gee_client.get_oisst_collection(start_date, end_date)
                    sst_df = self.gee_client.extract_timeseries(collection, 'sst', reducer=sst_reducer)
                
            elif source == 'noaa_vs':
                vs_df, metadata = self.noaa_client.download_virtual_station_andaman()
                sst_df = vs_df[['sst_90th']].rename(columns={'sst_90th': 'sst'})
                sst_df = sst_df.loc[str(start_date):str(end_date)]
                
            else:
                raise ValidationError(f"Unknown SST source: {source}")
            
            # Save to cache (with reducer suffix)
            self.data_cache.save_csv(sst_df, 'sst', str(start_date), str(end_date), suffix=cache_suffix)
            
            self._sst_data = sst_df
            self.logger.info(f"SST data acquired: {len(sst_df)} records (reducer={sst_reducer})")
            return sst_df
            
        except Exception as e:
            if isinstance(e, (ValidationError, DataAcquisitionError, GEEError)):
                raise
            raise DataAcquisitionError(f"Failed to acquire SST data: {str(e)}", source=source.upper(), original_exception=e)
    
    @log_execution_time()
    def step_dhw_forecasting(self) -> Dict[str, Any]:
        """
        Step 9: DHW Time Series Forecasting
        
        This REPLACES the old classification approach. Uses Ensemble-pCRVI
        which combines time series features with pCRVI components.
        
        Returns
        -------
        dict
            Contains forecaster, comparison DataFrame, predictions, feature importance
        """
        self.logger.info("Step 9: DHW Time Series Forecasting (Ensemble-pCRVI)")
        
        from .dhw_forecaster import DHWTimeSeriesForecaster
        
        # Initialize forecaster
        forecaster = DHWTimeSeriesForecaster(
            mmm_sst=self.config.region.mmm_sst,
            bleaching_threshold=4.0,
            severe_threshold=8.0
        )
        
        # Prepare features
        feature_df = forecaster.prepare_features(
            sst_data=self._sst_data,
            dhw_data=self._dhw_data,
            climate_data=self._climate_indices,
            pcrvi_data=self._pcrvi_timeseries,
            ocean_color_data=self._ocean_color_data,
        )
        
        # Run model comparison (only Ensemble-pCRVI, not old classifiers)
        comparison = forecaster.compare_models(
            df=feature_df,
            pcrvi_data=self._pcrvi_timeseries,
            horizons=[30, 60],
            run_all=False  # CRITICAL: Only run ensemble, skip SARIMAX/Prophet
        )
        
        # Store results
        self._dhw_forecaster = forecaster
        self._forecast_comparison = comparison
        
        # Log best model
        results = {
            'forecaster': forecaster,
            'comparison': comparison,
            'feature_matrix': feature_df,
            'best_model': None,
            'predictions': {},
            'feature_importance': {}
        }
        
        if len(comparison) > 0:
            best = comparison.iloc[0]
            results['best_model'] = best['Model']
            self.logger.info(f"Best forecasting model: {best['Model']}")
            self.logger.info(f"  Bleaching F1: {best['bl_f1']:.3f}")
            self.logger.info(f"  MAE: {best['mae']:.3f} °C-weeks")
            self.logger.info(f"  R²: {best['r2']:.3f}")
        
        # Extract predictions and feature importance
        for key, model_info in forecaster.models.items():
            if 'predictions' in model_info:
                results['predictions'][key] = model_info['predictions']
            if 'feature_importance' in model_info:
                results['feature_importance'][key] = model_info['feature_importance']
        
        return results

    @log_execution_time() 
    def acquire_ocean_color_data(
        self,
        start_date: Union[str, date],
        end_date: Union[str, date],
        variables: List[str] = ['KD490', 'CHL'],
        use_chunked: bool = True
    ) -> pd.DataFrame:
        """
        Acquire ocean color data with caching support.
        """
        self.logger.info(f"Acquiring ocean color data: {variables}")
        
        # Check cache first
        cached_df = self.data_cache.load_csv('ocean_color', str(start_date), str(end_date))
        if cached_df is not None:
            self._ocean_color_data = cached_df
            self.logger.info(f"Loaded ocean color from cache: {len(cached_df)} records")
            return cached_df
        
        start_dt = datetime.strptime(str(start_date), "%Y-%m-%d")
        end_dt = datetime.strptime(str(end_date), "%Y-%m-%d")
        total_days = (end_dt - start_dt).days
        
        try:
            # Always use chunked for ocean color (checks existing files)
            ocean_color_df = self.copernicus_client.download_ocean_color_chunked(
                start_date=start_date,
                end_date=end_date,
                variables=variables,
                data_dir=self.config.data_dir
            )
            
            # Save combined timeseries to cache
            self.data_cache.save_csv(ocean_color_df, 'ocean_color', str(start_date), str(end_date))
            
            self._ocean_color_data = ocean_color_df
            self.logger.info(f"Ocean color data acquired: {len(ocean_color_df)} records")
            return ocean_color_df
            
        except (ValidationError, DataAcquisitionError, CopernicusError):
            raise
        except Exception as e:
            raise DataAcquisitionError(f"Failed to acquire ocean color data: {str(e)}", source="COPERNICUS", original_exception=e)
    
    @log_execution_time()
    def acquire_atmospheric_data(
        self,
        start_date: Union[str, date],
        end_date: Union[str, date],
        use_chunked: bool = True
    ) -> pd.DataFrame:
        """
        Acquire atmospheric data with caching support.
        """
        self.logger.info("Acquiring atmospheric data from ERA5 HOURLY")
        
        # Check cache first
        cached_df = self.data_cache.load_csv('atmospheric', str(start_date), str(end_date))
        if cached_df is not None:
            self._atmospheric_data = cached_df
            self.logger.info(f"Loaded atmospheric from cache: {len(cached_df)} records")
            return cached_df
        
        start_dt = datetime.strptime(str(start_date), "%Y-%m-%d")
        end_dt = datetime.strptime(str(end_date), "%Y-%m-%d")
        total_days = (end_dt - start_dt).days
        
        try:
            self.gee_client.authenticate()
            
            # Use chunked extraction for long date ranges
            if use_chunked and total_days > 730:
                self.logger.info(f"Using chunked acquisition for {total_days} days of ERA5 data")
                atmospheric_df = self.gee_client.extract_era5_chunked(
                    start_date=start_date,
                    end_date=end_date,
                    chunk_size_days=365,
                    cache_dir=self.config.data_dir
                )
            else:
                hourly_collection = self.gee_client.get_era5_hourly(start_date, end_date)
                daily_collection = self.gee_client.aggregate_era5_to_daily(hourly_collection, start_date, end_date)
                cloud_df = self.gee_client.extract_timeseries(daily_collection, 'cloud_cover')
                wind_df = self.gee_client.extract_timeseries(daily_collection, 'wind_speed')
                atmospheric_df = pd.concat([cloud_df, wind_df], axis=1)
            
            # Save to cache
            self.data_cache.save_csv(atmospheric_df, 'atmospheric', str(start_date), str(end_date))
            
            self._atmospheric_data = atmospheric_df
            self.logger.info(f"Atmospheric data acquired: {len(atmospheric_df)} records")
            return atmospheric_df
            
        except Exception as e:
            if isinstance(e, (ValidationError, GEEError)):
                raise
            raise DataAcquisitionError(f"Failed to acquire atmospheric data: {str(e)}", source="GEE", original_exception=e)
            
    @log_execution_time()
    def acquire_climate_indices(self) -> pd.DataFrame:
        """
        Acquire climate indices (ONI, DMI, and optionally AMO).

        AMO is downloaded when the region's ``climate_driver_weights``
        include an ``'amo'`` key (Caribbean / Florida / Atlantic regions).
        """
        region = self.config.region
        cdr_weights = getattr(region, 'climate_driver_weights',
                              {'oni': 0.55, 'dmi': 0.45})
        need_amo = cdr_weights.get('amo', 0.0) > 0.0

        indices_str = "ONI, DMI" + (", AMO" if need_amo else "")
        self.logger.info(f"Acquiring climate indices ({indices_str})")
        
        try:
            oni_df = self.climate_client.download_oni()
            dmi_df = self.climate_client.download_dmi()
            
            frames = [oni_df, dmi_df]

            if need_amo:
                try:
                    amo_df = self.climate_client.download_amo()
                    frames.append(amo_df)
                    self.logger.info("AMO data acquired for Atlantic/Caribbean CDR")
                except Exception as e:
                    self.logger.warning(
                        f"AMO download failed (CDR will use ONI only): {e}")

            climate_df = pd.concat(frames, axis=1)
            
            self._climate_indices = climate_df
            self.logger.info(f"Climate indices acquired: {len(climate_df)} records, "
                           f"columns: {list(climate_df.columns)}")
            return climate_df
            
        except Exception as e:
            if isinstance(e, DataAcquisitionError):
                raise
            raise DataAcquisitionError(
                f"Failed to acquire climate indices: {str(e)}",
                source="NOAA",
                original_exception=e
            )
    
    @log_execution_time()
    def calculate_dhw(self, sst_data: Optional[pd.DataFrame] = None) -> pd.DataFrame:
        """
        Calculate Degree Heating Weeks from SST data.
        """
        if sst_data is None:
            sst_data = self._sst_data
        
        if sst_data is None:
            raise ProcessingError(
                "No SST data available. Call acquire_sst_data() first.",
                operation="DHW_calculation"
            )
        
        self.logger.info("Calculating DHW using Liu et al. 2014 methodology")
        
        # Get SST series
        if 'sst' in sst_data.columns:
            sst_series = sst_data['sst']
        else:
            sst_series = sst_data.iloc[:, 0]
        
        dhw_df = self.dhw_calculator.calculate_dhw_timeseries(sst_series)
        
        self._dhw_data = dhw_df
        self.logger.info(f"DHW calculated: {len(dhw_df)} records")
        return dhw_df
    
    @log_execution_time()
    def build_features(
        self,
        include_ocean_color: bool = True,
        include_atmospheric: bool = True,
        include_climate: bool = True
    ) -> pd.DataFrame:
        """
        Build complete feature matrix from all acquired data.
        """
        self.logger.info("Building feature matrix")
        
        # Check required data
        if self._sst_data is None:
            raise ProcessingError(
                "SST data not available. Call acquire_sst_data() first.",
                operation="feature_building"
            )
        
        if self._dhw_data is None:
            self.calculate_dhw()
        
        # Build feature matrix
        feature_matrix = self.feature_engineer.build_feature_matrix(
            sst_data=self._sst_data,
            dhw_data=self._dhw_data,
            ocean_color_data=self._ocean_color_data if include_ocean_color else None,
            atmospheric_data=self._atmospheric_data if include_atmospheric else None,
            climate_indices=self._climate_indices if include_climate else None
        )
        
        self._feature_matrix = feature_matrix
        self.logger.info(f"Feature matrix built: {feature_matrix.shape}")
        return feature_matrix
    
    @log_execution_time()
    def train_model(
        self,
        X: np.ndarray,
        y: np.ndarray,
        feature_names: List[str],
        cross_validate: bool = True,
        years: Optional[np.ndarray] = None
    ) -> Dict[str, Any]:
        """
        Train the bleaching prediction model.
        """
        self.logger.info(f"Training model with {len(X)} samples")
        
        results = {}
        
        # Cross-validate if requested
        if cross_validate and years is not None:
            cv_results = self.predictor.cross_validate_loyo(
                X, y, years, feature_names=feature_names
            )
            results['cv_results'] = cv_results
        
        # Fit final model on all data
        self.predictor.fit(X, y, feature_names=feature_names)
        
        # Get feature importance
        importance = self.predictor.get_feature_importance()
        results['feature_importance'] = importance
        
        self.logger.info("Model training complete")
        return results
    
    def predict(
        self,
        X: np.ndarray
    ) -> Tuple[np.ndarray, np.ndarray]:
        """
        Generate predictions for new data.
        """
        predictions = self.predictor.predict(X)
        probabilities = self.predictor.predict_proba(X)
        
        return predictions, probabilities

    @log_execution_time()
    def validate_against_historical_events(self) -> pd.DataFrame:
        """
        Validate pCRVI and DHW predictions against documented historical bleaching events.
        
        Uses the KNOWN_BLEACHING_EVENTS from config to compare model predictions
        with actual documented bleaching severity.
        
        Returns
        -------
        pd.DataFrame
            Validation results comparing predictions to historical records
        """
        if self._dhw_data is None:
            raise ProcessingError(
                "DHW data required. Run calculate_dhw() first.",
                operation="historical_validation"
            )
        
        self.logger.info("Validating predictions against historical bleaching events...")
        
        # Get known events from config
        known_events = self.config.region.KNOWN_BLEACHING_EVENTS
        
        validation_results = []
        
        for year, event_data in known_events.items():
            # Get model DHW for this year
            year_data = self._dhw_data[self._dhw_data.index.year == year]
            
            if len(year_data) == 0:
                self.logger.warning(f"No data available for year {year}")
                continue
            
            model_dhw_max = year_data['dhw'].max()
            model_dhw_date = year_data['dhw'].idxmax()
            
            # Get pCRVI if available
            pcrvi_max = None
            pcrvi_30d_before = None
            if self._pcrvi_timeseries is not None:
                pcrvi_year = self._pcrvi_timeseries[self._pcrvi_timeseries.index.year == year]
                if len(pcrvi_year) > 0:
                    pcrvi_max = pcrvi_year['pcrvi'].max()
                    # Get pCRVI 30 days before peak DHW
                    if model_dhw_date is not None:
                        lookback_date = model_dhw_date - pd.Timedelta(days=30)
                        try:
                            pcrvi_30d_before = self._pcrvi_timeseries.loc[lookback_date:model_dhw_date, 'pcrvi'].mean()
                        except:
                            pcrvi_30d_before = None
            
            # Determine model prediction severity based on DHW
            # Using ANI-calibrated thresholds
            if model_dhw_max >= 8:
                dhw_severity = 'severe'
            elif model_dhw_max >= 6:
                dhw_severity = 'moderate'
            elif model_dhw_max >= 3:
                dhw_severity = 'minor'
            else:
                dhw_severity = 'none'
            
            # Determine pCRVI prediction severity
            pcrvi_severity = None
            if pcrvi_max is not None:
                if pcrvi_max >= 0.6:
                    pcrvi_severity = 'severe'
                elif pcrvi_max >= 0.4:
                    pcrvi_severity = 'moderate'
                elif pcrvi_max >= 0.2:
                    pcrvi_severity = 'minor'
                else:
                    pcrvi_severity = 'none'
            
            # Compare to actual
            actual_severity = event_data['severity']
            dhw_match = self._severity_match(dhw_severity, actual_severity)
            pcrvi_match = self._severity_match(pcrvi_severity, actual_severity) if pcrvi_severity else None
            
            # Check if pCRVI would have provided early warning
            early_warning = False
            if pcrvi_30d_before is not None and pcrvi_30d_before >= 0.4:
                early_warning = True
            
            validation_results.append({
                'year': year,
                'actual_severity': actual_severity,
                'actual_dhw': event_data['dhw_reported'],
                'actual_bleaching_pct': event_data['bleaching_pct'],
                'peak_month': event_data.get('peak_month', 5),
                'model_dhw_max': round(model_dhw_max, 2) if not pd.isna(model_dhw_max) else None,
                'dhw_severity_prediction': dhw_severity,
                'dhw_match': dhw_match,
                'pcrvi_max': round(pcrvi_max, 3) if pcrvi_max else None,
                'pcrvi_30d_lead': round(pcrvi_30d_before, 3) if pcrvi_30d_before else None,
                'pcrvi_severity_prediction': pcrvi_severity,
                'pcrvi_match': pcrvi_match,
                'pcrvi_early_warning': early_warning,
                'notes': event_data.get('notes', ''),
                'source': event_data.get('source', '')
            })
        
        validation_df = pd.DataFrame(validation_results)
        
        # Calculate accuracy metrics
        if len(validation_df) > 0:
            dhw_correct = (validation_df['dhw_match'] == 'CORRECT').sum()
            dhw_close = (validation_df['dhw_match'] == 'CLOSE').sum()
            dhw_accuracy = (dhw_correct + dhw_close * 0.5) / len(validation_df)
            
            pcrvi_valid = validation_df[validation_df['pcrvi_match'].notna()]
            if len(pcrvi_valid) > 0:
                pcrvi_correct = (pcrvi_valid['pcrvi_match'] == 'CORRECT').sum()
                pcrvi_close = (pcrvi_valid['pcrvi_match'] == 'CLOSE').sum()
                pcrvi_accuracy = (pcrvi_correct + pcrvi_close * 0.5) / len(pcrvi_valid)
                early_warning_rate = pcrvi_valid['pcrvi_early_warning'].sum() / len(pcrvi_valid)
            else:
                pcrvi_accuracy = 0
                early_warning_rate = 0
            
            self.logger.info(f"Historical Validation Results:")
            self.logger.info(f"  Events validated: {len(validation_df)}")
            self.logger.info(f"  DHW Accuracy: {dhw_accuracy:.1%}")
            self.logger.info(f"  pCRVI Accuracy: {pcrvi_accuracy:.1%}")
            self.logger.info(f"  pCRVI Early Warning Rate: {early_warning_rate:.1%}")
        
        self._historical_validation = validation_df
        return validation_df
    
    def _severity_match(self, predicted: str, actual: str) -> str:
        """Helper to determine if prediction matches actual severity."""
        if predicted is None:
            return None

        severity_levels = {
            'none': 0, 'minor': 1, 'moderate': 2,
            'severe': 3, 'catastrophic': 4,
        }
        pred_level = severity_levels.get(predicted.lower(), -1)
        actual_level = severity_levels.get(actual.lower(), -1)

        if pred_level == actual_level:
            return 'CORRECT'
        elif abs(pred_level - actual_level) == 1 and pred_level > 0:
            return 'CLOSE'
        elif pred_level == 0 and actual_level >= 1:
            # Predicting no stress when there was actual stress = underestimate
            return 'UNDERESTIMATE'
        elif pred_level < actual_level:
            return 'UNDERESTIMATE'
        else:
            return 'OVERESTIMATE'

    @log_execution_time()
    def calculate_predictive_crvi(
        self,
        smoothing_days: int = 7
    ) -> Tuple[pd.DataFrame, Dict[str, Any]]:
        """
        Calculate Enhanced-pCRVI (7-component) with weekly risk layers
        and ML weight optimization.

        This replaces BOTH the old CRVICalculator and the 5-component PredictiveCRVI.
        Uses: TA, AS, SR, CDR, BH, WQ (Chl-a + Kd490), LA (PAR proxy + attenuation).
        """
        if self._dhw_data is None or self._sst_data is None:
            raise ProcessingError(
                "SST and DHW data required. Run data acquisition first.",
                operation="enhanced_pcrvi"
            )

        self.logger.info("=" * 50)
        self.logger.info("Calculating Enhanced-pCRVI (7 components)")
        self.logger.info("Components: TA, AS, SR, CDR, BH, WQ, LA")
        self.logger.info("=" * 50)

        # Initialize Enhanced-pCRVI (region-aware)
        epcrvi = EnhancedPCRVI(
            config=self.config,
            mmm=self.config.region.mmm_sst
        )

        # Calculate 7-component time series
        pcrvi_ts = epcrvi.calculate_timeseries(
            sst_data=self._sst_data,
            dhw_data=self._dhw_data,
            ocean_color_data=self._ocean_color_data,
            atmospheric_data=self._atmospheric_data,
            climate_data=self._climate_indices,
            smoothing_days=smoothing_days,
        )

        if pcrvi_ts.empty:
            self.logger.warning("Enhanced-pCRVI returned empty timeseries")
            return pd.DataFrame(), {}

        # Analyze predictive skill
        skill_results = epcrvi.analyze_predictive_skill(
            pcrvi_ts=pcrvi_ts,
            dhw_data=self._dhw_data,
            lead_days=[7, 14, 30, 60, 90],
            threshold=0.4,
        )

        # Generate weekly risk layers (NEW — for reef managers)
        weekly_risk = epcrvi.generate_weekly_risk_layers(pcrvi_ts)

        # ML weight optimization (NEW)
        ml_results = epcrvi.optimize_weights_ml(pcrvi_ts, self._dhw_data)

        # Store all results
        self._enhanced_pcrvi_ts = pcrvi_ts
        self._pcrvi_timeseries = pcrvi_ts  # backwards compat
        self._pcrvi_skill = skill_results
        self._enhanced_pcrvi_skill = skill_results
        self._enhanced_pcrvi_weekly = weekly_risk
        self._ml_weight_results = ml_results

        # Log summary
        if 'lead_time_analysis' in skill_results:
            lead_30 = skill_results['lead_time_analysis'].get('30_days', {})
            self.logger.info(
                f"Enhanced-pCRVI complete: {len(pcrvi_ts)} daily values\n"
                f"  30-day F1: {lead_30.get('f1_score', 0):.3f}\n"
                f"  30-day MCC: {lead_30.get('mcc', 0):.3f}\n"
                f"  Optimal threshold: {skill_results.get('optimal_threshold', 0.4):.2f}\n"
                f"  Weekly risk layers: {len(weekly_risk)}"
            )
        if 'ml_weights' in ml_results:
            self.logger.info("ML weight optimization successful")

        return pcrvi_ts, skill_results
    
    @log_execution_time()
    def run_model_comparison(
        self,
        test_size: float = 0.2
    ) -> pd.DataFrame:
        """
        Run comparison of multiple ML models with comprehensive metrics.
        """
        if self._feature_matrix is None:
            raise ProcessingError("Feature matrix required. Run build_features() first.", operation="model_comparison")
        
        self.logger.info("Running model comparison...")
        
        from sklearn.model_selection import train_test_split
        
        # Prepare data
        X = self._feature_matrix.select_dtypes(include=[np.number]).dropna()
        
        # Create binary target (bleaching if DHW >= 4)
        y = (X['dhw'] >= 4).astype(int) if 'dhw' in X.columns else np.zeros(len(X))
        
        # Remove target from features
        feature_cols = [c for c in X.columns if c not in ['dhw', 'alert_level']]
        X_features = X[feature_cols].values
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X_features, y.values, test_size=test_size, random_state=42, stratify=y
        )
        
        # Run comparison
        comparison_df = compare_models(
            X_train, y_train, X_test, y_test,
            feature_names=feature_cols,
            task='classification'
        )
        
        # Store results
        self._model_comparison = comparison_df
        
        self.logger.info(f"Model comparison complete:\n{comparison_df.to_string()}")
        return comparison_df

    @log_execution_time()
    def save_all_outputs(self, output_dir: Optional[Path] = None, prefix: str = "") -> Dict[str, Path]:
        """
        Save ALL acquired data and results to CSV files.

        Outputs every dataframe used in the study.  NO CRVI outputs.
        pCRVI (7-component Enhanced) is the primary vulnerability index.
        """
        output_dir = output_dir or self.config.output_dir
        output_manager = OutputManager(output_dir)

        saved_files = {}

        # 2. DHW data
        if self._dhw_data is not None and not self._dhw_data.empty:
            saved_files['dhw'] = output_manager.save_dhw_data(self._dhw_data, prefix)

        # 6. Feature matrix (comprehensive)
        if self._feature_matrix is not None and not self._feature_matrix.empty:
            saved_files['features'] = output_manager.save_feature_matrix(
                self._feature_matrix, prefix)

        # 7. Enhanced-pCRVI timeseries (all 7 components + diagnostics)
        pcrvi_ts = getattr(self, '_enhanced_pcrvi_ts', self._pcrvi_timeseries)
        if pcrvi_ts is not None and not pcrvi_ts.empty:
            saved_files['pcrvi'] = output_manager.save_pcrvi_timeseries(pcrvi_ts, prefix)

        # 8. pCRVI skill analysis
        skill = getattr(self, '_enhanced_pcrvi_skill', self._pcrvi_skill)
        if skill:
            saved_files['pcrvi_skill'] = output_manager.save_pcrvi_skill(skill, prefix)

        # 9. Weekly risk layers (NEW)
        weekly = getattr(self, '_enhanced_pcrvi_weekly', None)
        if weekly is not None and not weekly.empty:
            saved_files['weekly_risk'] = output_manager.save_weekly_risk_layers(weekly, prefix)

        # 10. ML weight optimization (NEW)
        ml_results = getattr(self, '_ml_weight_results', None)
        if ml_results is not None and isinstance(ml_results, dict) and 'ml_weights' in ml_results:
            fname = f"{prefix}ml_weight_optimization.json" if prefix else "ml_weight_optimization.json"
            path = output_manager.reports_dir / fname
            path.parent.mkdir(parents=True, exist_ok=True)

            def convert(obj):
                if isinstance(obj, (np.integer,)):
                    return int(obj)
                elif isinstance(obj, (np.floating,)):
                    return float(obj)
                elif isinstance(obj, np.ndarray):
                    return obj.tolist()
                elif isinstance(obj, pd.Timestamp):
                    return str(obj)
                return obj

            with open(path, 'w') as f:
                json.dump(ml_results, f, indent=2, default=convert)
            saved_files['ml_weights_json'] = path

            # Also save comparison as CSV
            comparison = ml_results.get('comparison', {})
            if comparison:
                comp_df = pd.DataFrame(comparison).T
                csv_path = output_manager.csv_dir / (
                    f"{prefix}ml_weight_comparison.csv" if prefix else "ml_weight_comparison.csv")
                comp_df.to_csv(csv_path)
                saved_files['ml_weights_csv'] = csv_path

        # 11. Annual summary
        if self._dhw_data is not None:
            try:
                annual_summary = self._calculate_annual_summary()
                saved_files['annual_summary'] = output_manager.save_annual_summary(
                    annual_summary, prefix)
            except Exception as e:
                self.logger.warning(f"Annual summary failed: {e}")

        # 12. Historical validation
        if self._historical_validation is not None and not self._historical_validation.empty:
            fname = f"{prefix}validation_results.csv" if prefix else "validation_results.csv"
            path = output_manager.csv_dir / fname
            self._historical_validation.to_csv(path, index=False)
            saved_files['validation'] = path

        # 13. DHW forecast results
        if self._forecast_comparison is not None and len(self._forecast_comparison) > 0:
            fname = f"{prefix}dhw_forecast_comparison.csv" if prefix else "dhw_forecast_comparison.csv"
            path = output_manager.csv_dir / fname
            self._forecast_comparison.to_csv(path, index=False)
            saved_files['forecast_comparison'] = path

        if self._dhw_forecaster is not None:
            for key, model_info in self._dhw_forecaster.models.items():
                if 'predictions' in model_info:
                    pred_df = model_info['predictions']
                    fname = f"{prefix}dhw_predictions_{key}.csv"
                    path = output_manager.csv_dir / fname
                    pred_df.to_csv(path, index=False)
                    saved_files[f'predictions_{key}'] = path
                if 'feature_importance' in model_info:
                    imp_df = model_info['feature_importance']
                    fname = f"{prefix}feature_importance_{key}.csv"
                    path = output_manager.csv_dir / fname
                    imp_df.to_csv(path, index=False)
                    saved_files[f'feature_importance_{key}'] = path

        self.logger.info(f"Saved {len(saved_files)} output files to {output_dir}")
        return saved_files

    def _calculate_annual_summary(self) -> pd.DataFrame:
        """Calculate annual summary statistics using calibrated thresholds."""
        if self._dhw_data is None:
            return pd.DataFrame()

        dhw_copy = self._dhw_data.copy()
        dhw_copy['year'] = dhw_copy.index.year

        t = self.dhw_calculator.thresholds
        annual_stats = []
        for year in dhw_copy['year'].unique():
            yd = dhw_copy[dhw_copy['year'] == year]
            dhw = yd['dhw'].dropna()
            stats = {
                'year': year,
                'dhw_max': dhw.max(),
                'dhw_mean': dhw.mean(),
                'days_no_stress': (dhw <= t.get('watch', 1.0)).sum(),
                'days_watch': ((dhw > t.get('watch', 1.0)) & (dhw <= t.get('warning', 3.0))).sum(),
                'days_warning': ((dhw > t.get('warning', 3.0)) & (dhw <= t.get('alert_level_1', 6.0))).sum(),
                'days_alert1': ((dhw > t.get('alert_level_1', 6.0)) & (dhw <= t.get('alert_level_2', 8.0))).sum(),
                'days_alert2': (dhw > t.get('alert_level_2', 8.0)).sum(),
            }
            if 'sst' in yd.columns:
                stats['sst_max'] = yd['sst'].max()
                stats['sst_mean'] = yd['sst'].mean()
            annual_stats.append(stats)

        return pd.DataFrame(annual_stats)

    @log_execution_time()
    def generate_visualizations(self, output_dir: Optional[Path] = None, prefix: str = "") -> Dict[str, Path]:
        """
        Generate all visualizations.
        
        """
        output_dir = output_dir or (self.config.output_dir / "visualizations")
        viz = Visualizer(output_dir)
        
        saved_plots = {}
        
        # Get historical events for marking on plots
        historical_events = self.config.region.KNOWN_BLEACHING_EVENTS
        
        # NEW: DHW Forecast plots (REPLACES old model_comparison plot)
        if self._dhw_forecaster is not None and self._forecast_comparison is not None:
            try:
                # Import new visualization functions
                from .visualization_forecast import (
                    plot_forecast_model_comparison,
                    create_forecast_dashboard,
                    plot_forecast_feature_importance
                )
                '''
                # Forecast model comparison
                path = output_dir / f"{prefix}dhw_forecast_comparison.png"
                plot_forecast_model_comparison(self._forecast_comparison, output_path=path)
                saved_plots['dhw_forecast_comparison'] = path
                '''
                # Forecast dashboard
                path = output_dir / f"{prefix}dhw_forecast_dashboard.png"
                create_forecast_dashboard(
                    self._dhw_forecaster,
                    self._dhw_data,
                    self._pcrvi_timeseries,
                    output_path=path
                )
                saved_plots['dhw_forecast_dashboard'] = path
                
                # Feature importance
                for key, model_info in self._dhw_forecaster.models.items():
                    if 'feature_importance' in model_info:
                        path = output_dir / f"{prefix}feature_importance_{key}.png"
                        plot_forecast_feature_importance(
                            model_info['feature_importance'],
                            model_name=model_info.get('name', key),
                            output_path=path
                        )
                        saved_plots[f'feature_importance_{key}'] = path
                        break  # Only need one
                        
            except Exception as e:
                self.logger.warning(f"DHW forecast visualization failed: {e}")

        # Standard DHW/SST plots
        if self._sst_data is not None and self._dhw_data is not None:
            '''
            try:
                saved_plots['dhw_timeseries'] = viz.plot_dhw_timeseries(
                    self._dhw_data, 
                    historical_events=historical_events,
                    prefix=prefix
                )
            except Exception as e:
                self.logger.warning(f"DHW timeseries plot failed: {e}")
            '''
            try:
                saved_plots['sst_dhw_combined'] = viz.plot_sst_and_dhw(
                    self._sst_data, self._dhw_data, mmm=self.config.region.mmm_sst, prefix=prefix
                )
            except Exception as e:
                self.logger.warning(f"SST/DHW combined plot failed: {e}")
            
            try:
                saved_plots['annual_max_dhw'] = viz.plot_annual_max_dhw(
                    self._dhw_data, 
                    historical_events=historical_events,
                    prefix=prefix
                )
            except Exception as e:
                self.logger.warning(f"Annual max DHW plot failed: {e}")
            
            try:
                saved_plots['seasonal_pattern'] = viz.plot_seasonal_pattern(self._dhw_data, prefix=prefix)
            except Exception as e:
                self.logger.warning(f"Seasonal pattern plot failed: {e}")
            
            try:
                saved_plots['alert_distribution'] = viz.plot_alert_distribution(self._dhw_data, prefix=prefix)
            except Exception as e:
                self.logger.warning(f"Alert distribution plot failed: {e}")
            
            try:
                saved_plots['bleaching_heatmap'] = viz.plot_bleaching_heatmap(self._dhw_data, prefix=prefix)
            except Exception as e:
                self.logger.warning(f"Bleaching heatmap plot failed: {e}")
            
            try:
                saved_plots['dhw_severity'] = viz.plot_dhw_severity_relationship(
                    self._dhw_data, prefix=prefix,
                    known_events=self.config.region.KNOWN_BLEACHING_EVENTS)
            except Exception as e:
                self.logger.warning(f"DHW severity plot failed: {e}")
            
            try:
                saved_plots['noaa_bleaching_alert'] = viz.plot_noaa_style_bleaching_alert(
                    self._dhw_data, bounds=self.config.region.bounds, prefix=prefix
                )
            except Exception as e:
                self.logger.warning(f"NOAA alert plot failed: {e}")
            
            try:
                saved_plots['annual_bleaching_map'] = viz.plot_annual_bleaching_map(
                    self._dhw_data, bounds=self.config.region.bounds, prefix=prefix
                )
            except Exception as e:
                self.logger.warning(f"Annual bleaching map failed: {e}")
        
        # Feature correlation
        if self._feature_matrix is not None:
            try:
                saved_plots['feature_correlation'] = viz.plot_feature_correlation(self._feature_matrix, prefix=prefix)
            except Exception as e:
                self.logger.warning(f"Feature correlation plot failed: {e}")
        
        # Climate indices
        if self._climate_indices is not None and self._dhw_data is not None:
            try:
                saved_plots['climate_vs_dhw'] = viz.plot_climate_indices_vs_dhw(
                    self._dhw_data, self._climate_indices, prefix=prefix
                )
            except Exception as e:
                self.logger.warning(f"Climate vs DHW plot failed: {e}")
        
        # =========================================================================
        # NOTE: STANDALONE CRVI PLOTS REMOVED
        # CRVI is NOT predictive - only shown in comparison with pCRVI
        # =========================================================================
        
        # Predictive CRVI (pCRVI) plots - PRIMARY VISUALIZATIONS
        if self._pcrvi_timeseries is not None and not self._pcrvi_timeseries.empty:
            '''
            try:
                saved_plots['pcrvi_timeseries'] = viz.plot_pcrvi_timeseries(
                    self._pcrvi_timeseries,
                    self._dhw_data,
                    historical_events=historical_events,
                    prefix=prefix
                )
            except Exception as e:
                self.logger.warning(f"pCRVI timeseries plot failed: {e}")
            '''
            # pCRVI predictive dashboard
            if self._pcrvi_skill is not None:
                try:
                    saved_plots['pcrvi_dashboard'] = viz.plot_pcrvi_predictive_dashboard(
                        self._pcrvi_timeseries,
                        self._dhw_data,
                        self._pcrvi_skill,
                        historical_events=historical_events,
                        prefix=prefix
                    )
                except Exception as e:
                    self.logger.warning(f"pCRVI dashboard plot failed: {e}")
        
        # Historical validation plot
        if self._historical_validation is not None and not self._historical_validation.empty:
            try:
                saved_plots['historical_validation'] = viz.plot_historical_validation(
                    self._historical_validation,
                    self._dhw_data,
                    self._pcrvi_timeseries,
                    prefix=prefix
                )
            except Exception as e:
                self.logger.warning(f"Historical validation plot failed: {e}")
        
        # ---------- POSTER-QUALITY VISUALIZATIONS (NEW) ----------
        try:
            poster_dir = output_dir / 'poster'
            poster_dir.mkdir(parents=True, exist_ok=True)

            poster_viz = PosterVisualizer(
                output_dir=poster_dir,
                known_events=self.config.region.KNOWN_BLEACHING_EVENTS,
                region_name=self.config.region.name,
            )

            pcrvi_ts = getattr(self, '_enhanced_pcrvi_ts', self._pcrvi_timeseries)
            weekly = getattr(self, '_enhanced_pcrvi_weekly', None)
            skill = getattr(self, '_enhanced_pcrvi_skill', self._pcrvi_skill)
            ml_results = getattr(self, '_ml_weight_results', None)

            if pcrvi_ts is not None and not pcrvi_ts.empty and self._dhw_data is not None:
                poster_paths = poster_viz.generate_all(
                    pcrvi_ts=pcrvi_ts,
                    dhw_data=self._dhw_data,
                    weekly_df=weekly,
                    skill_results=skill,
                    opt_results=ml_results,
                    weights=dict(DEFAULT_WEIGHTS),
                    known_events=self.config.region.KNOWN_BLEACHING_EVENTS,
                )
                saved_plots.update({f'poster_{k}': v for k, v in poster_paths.items()})
                self.logger.info(f"Generated {len(poster_paths)} poster visualizations")
        except Exception as e:
            self.logger.warning(f"Poster visualization generation failed: {e}")
            import traceback
            self.logger.warning(traceback.format_exc())

        self.logger.info(f"Generated {len(saved_plots)} visualizations")
        return saved_plots

    @log_execution_time()
    def generate_report(self, output_dir: Optional[Path] = None, prefix: str = "", visualization_paths: Optional[Dict[str, Path]] = None) -> Dict[str, Path]:
        """
        Generate comprehensive summary reports (text and HTML).
        
        IMPORTANT: Reports focus on pCRVI as the PRIMARY vulnerability index.
        Uses Ensemble-pCRVI forecast results instead of old classification models.
        """
        output_dir = output_dir or self.config.output_dir
        output_manager = OutputManager(output_dir)
        
        start_date = str(self._dhw_data.index.min().date()) if self._dhw_data is not None else "N/A"
        end_date = str(self._dhw_data.index.max().date()) if self._dhw_data is not None else "N/A"
        
        reports = {}
        
        # Generate comprehensive report with forecast data
        if self._forecast_comparison is not None:
            try:
                report_path = output_manager.generate_pcrvi_comprehensive_report(
                    dhw_data=self._dhw_data,
                    pcrvi_results=self._pcrvi_skill,
                    pcrvi_timeseries=self._pcrvi_timeseries,
                    historical_validation=self._historical_validation,
                    forecast_comparison=self._forecast_comparison,
                    forecaster=self._dhw_forecaster,
                    climate_data=self._climate_indices,
                    visualization_paths=visualization_paths,
                    start_date=str(self._dhw_data.index.min()),
                    end_date=str(self._dhw_data.index.max())
                )
                reports['comprehensive'] = report_path
            except Exception as e:
                self.logger.warning(f"Comprehensive report generation failed: {e}")
        
        # Generate text report - pCRVI focused with forecast data
        try:
            reports['text'] = output_manager.generate_pcrvi_summary_report(
                dhw_data=self._dhw_data,
                pcrvi_results=self._pcrvi_skill,
                historical_validation=self._historical_validation,
                forecast_comparison=self._forecast_comparison,
                forecaster=self._dhw_forecaster,
                climate_data=self._climate_indices,
                start_date=start_date,
                end_date=end_date,
                prefix=prefix
            )
        except Exception as e:
            self.logger.warning(f"Summary report generation failed: {e}")
        
        # Generate HTML report - pCRVI focused with forecast data
        try:
            reports['html'] = output_manager.generate_pcrvi_html_report(
                dhw_data=self._dhw_data,
                pcrvi_results=self._pcrvi_skill,
                pcrvi_timeseries=self._pcrvi_timeseries,
                historical_validation=self._historical_validation,
                forecast_comparison=self._forecast_comparison,
                forecaster=self._dhw_forecaster,
                climate_data=self._climate_indices,
                visualization_paths=visualization_paths,
                start_date=start_date,
                end_date=end_date,
                prefix=prefix
            )
            self.logger.info(f"Generated HTML report: {reports['html']}")
        except Exception as e:
            self.logger.warning(f"HTML report generation failed: {e}")
        
        return reports

    def generate_weekly_alert(
        self,
        as_of_date: Optional[date] = None
    ) -> Dict[str, Any]:
        """
        Generate weekly bleaching risk alert.
        """
        if self._dhw_data is None:
            raise ProcessingError(
                "DHW data not available. Run workflow first.",
                operation="alert_generation"
            )
        
        if as_of_date is None:
            as_of_date = self._dhw_data.index.max()
        
        # Get current DHW — handle duplicate index entries
        current_row = self._dhw_data.loc[as_of_date]
        if isinstance(current_row, pd.DataFrame):
            current_row = current_row.iloc[-1]
        current_dhw = float(current_row['dhw'])
        alert_level = int(current_row['alert_level'])
        
        # Determine alert status
        alert_descriptions = {
            0: ("No Stress", "green", "Normal conditions. Continue routine monitoring."),
            1: ("Watch", "yellow", "Elevated SST detected. Increase monitoring frequency."),
            2: ("Alert Level 1", "orange", "Significant bleaching likely. Prepare response protocols."),
            3: ("Alert Level 2", "red", "Severe bleaching and mortality expected. Implement emergency protocols."),
            4: ("Alert Level 3", "darkred", "Extreme thermal stress. Widespread mortality likely."),
            5: ("Alert Level 4+", "purple", "Catastrophic conditions. Maximum emergency response.")
        }
        
        status, color, recommendation = alert_descriptions.get(
            alert_level, 
            ("Unknown", "gray", "Check data quality.")
        )
        
        # Include pCRVI if available
        pcrvi_info = {}
        if (self._pcrvi_skill is not None
                and isinstance(self._pcrvi_skill, dict)
                and 'current_assessment' in self._pcrvi_skill):
            pcrvi_info = self._pcrvi_skill['current_assessment']
        
        alert = {
            'date': str(as_of_date),
            'region': self.config.region.name,
            'dhw': current_dhw if not np.isnan(current_dhw) else None,
            'alert_level': alert_level,
            'status': status,
            'color': color,
            'recommendation': recommendation,
            'mmm': self.config.region.mmm_sst,
            'current_sst': float(current_row['sst']) if 'sst' in current_row.index else None,
            'pcrvi': pcrvi_info
        }
        
        self.logger.info(
            f"Weekly Alert Generated:\n"
            f"  Date: {as_of_date}\n"
            f"  DHW: {current_dhw:.2f} °C-weeks\n"
            f"  Status: {status}\n"
            f"  Recommendation: {recommendation}"
        )
        return alert
    
    def save_state(self, path: Path) -> None:
        """
        Save pipeline state to file.
        """
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        
        state = {
            'config': str(self.config.to_json),
            'has_sst_data': self._sst_data is not None,
            'has_dhw_data': self._dhw_data is not None,
            'has_ocean_color': self._ocean_color_data is not None,
            'has_atmospheric': self._atmospheric_data is not None,
            'has_climate_indices': self._climate_indices is not None,
            'has_pcrvi': self._pcrvi_timeseries is not None,
            'has_weekly_risk': getattr(self, '_enhanced_pcrvi_weekly', None) is not None,
            'has_ml_weights': getattr(self, '_ml_weight_results', None) is not None,
            'has_model_comparison': self._model_comparison is not None,
            'model_fitted': self.predictor.is_fitted
        }
        
        with open(path, 'w') as f:
            json.dump(state, f, indent=2)
        
        self.logger.info(f"State saved to {path}")
    
    @log_execution_time()
    def run_full_workflow(
        self,
        start_date: Union[str, date],
        end_date: Union[str, date],
        skip_ocean_color: bool = False,
        skip_atmospheric: bool = False,
        sst_reducer: str = 'mean'
    ) -> Dict[str, Any]:
        """
        Run the complete EWS workflow with Enhanced-pCRVI (7 components).

        NO old CRVI is calculated anywhere.  Only Enhanced-pCRVI is used.
        """
        self.logger.info("=" * 60)
        self.logger.info("Running Full Coral Bleaching EWS Workflow")
        self.logger.info("Vulnerability Index: Enhanced-pCRVI (7 components)")
        self.logger.info(f"Components: TA, AS, SR, CDR, BH, WQ, LA")
        self.logger.info(f"SST Reducer: {sst_reducer}")
        self.logger.info("=" * 60)

        results = {
            'start_date': str(start_date),
            'end_date': str(end_date),
            'region': self.config.region.name,
            'sst_reducer': sst_reducer,
            'steps_completed': [],
        }

        try:
            # Step 1: Acquire SST (NOAA OISST via GEE)
            self.logger.info("Step 1: Acquiring SST data...")
            self.acquire_sst_data(start_date, end_date, source='gee',
                                  sst_reducer=sst_reducer)
            results['steps_completed'].append('sst_acquisition')

            # Step 2: Calculate DHW (Liu et al. 2014)
            self.logger.info("Step 2: Calculating DHW...")
            self.calculate_dhw()
            results['steps_completed'].append('dhw_calculation')

            # Step 2b: DHW historical validation
            self.logger.info("Step 2b: DHW historical validation...")
            try:
                validation_df = self.dhw_calculator.validate_against_historical(
                    self._dhw_data)
                results['dhw_validation'] = validation_df.to_dict('records')
                self._dhw_validation_df = validation_df
                results['steps_completed'].append('dhw_validation')
            except Exception as e:
                self.logger.warning(f"DHW validation failed: {e}")

            # Step 3: Ocean color (Copernicus — CHL, KD490)
            if not skip_ocean_color:
                self.logger.info("Step 3: Acquiring ocean color (CHL, KD490)...")
                try:
                    self.acquire_ocean_color_data(start_date, end_date)
                    results['steps_completed'].append('ocean_color')
                except Exception as e:
                    self.logger.warning(f"Ocean color failed: {e}")

            # Step 4: Atmospheric (ERA5 — cloud cover, wind → PAR proxy)
            if not skip_atmospheric:
                self.logger.info("Step 4: Acquiring atmospheric data...")
                try:
                    self.acquire_atmospheric_data(start_date, end_date)
                    results['steps_completed'].append('atmospheric')
                except Exception as e:
                    self.logger.warning(f"Atmospheric failed: {e}")

            # Step 5: Climate indices (ONI, DMI)
            self.logger.info("Step 5: Acquiring climate indices (ONI, DMI)...")
            try:
                self.acquire_climate_indices()
                results['steps_completed'].append('climate_indices')
            except Exception as e:
                self.logger.warning(f"Climate indices failed: {e}")

            # Step 6: Build feature matrix
            self.logger.info("Step 6: Building feature matrix...")
            self.build_features(
                include_ocean_color=(not skip_ocean_color
                                     and self._ocean_color_data is not None),
                include_atmospheric=(not skip_atmospheric
                                     and self._atmospheric_data is not None),
                include_climate=self._climate_indices is not None,
            )
            results['steps_completed'].append('features')

            # Step 7: Enhanced-pCRVI (7 components + weekly risk + ML weights)
            self.logger.info("Step 7: Enhanced-pCRVI (7 components)...")
            try:
                pcrvi_ts, pcrvi_skill = self.calculate_predictive_crvi(
                    smoothing_days=7)
                results['pcrvi'] = {
                    'data_points': len(pcrvi_ts),
                    'components': 7,
                    'optimal_threshold': pcrvi_skill.get('optimal_threshold'),
                    'optimal_f1': pcrvi_skill.get('optimal_f1'),
                    '30day_f1': pcrvi_skill.get(
                        'lead_time_analysis', {}).get('30_days', {}).get('f1_score'),
                    '30day_mcc': pcrvi_skill.get(
                        'lead_time_analysis', {}).get('30_days', {}).get('mcc'),
                }
                weekly = getattr(self, '_enhanced_pcrvi_weekly', None)
                if weekly is not None and not weekly.empty:
                    results['weekly_risk_layers'] = len(weekly)
                ml = getattr(self, '_ml_weight_results', None)
                if ml is not None and isinstance(ml, dict) and 'ml_weights' in ml:
                    results['ml_weights'] = ml['ml_weights']
                if 'current_assessment' in pcrvi_skill:
                    results['pcrvi']['current_risk'] = (
                        pcrvi_skill['current_assessment']['risk_category'])
                results['steps_completed'].append('enhanced_pcrvi')
            except Exception as e:
                self.logger.warning(f"Enhanced-pCRVI failed: {e}")
                import traceback
                self.logger.warning(traceback.format_exc())

            # Step 8: Historical validation
            self.logger.info("Step 8: Historical validation...")
            try:
                hist_val = self.validate_against_historical_events()
                results['historical_validation'] = hist_val.to_dict('records')
                results['steps_completed'].append('historical_validation')
            except Exception as e:
                self.logger.warning(f"Historical validation failed: {e}")

            # Step 8b: Validation report
            try:
                output_manager = OutputManager(self.config.output_dir)
                dhw_val = getattr(self, '_dhw_validation_df', None)
                if dhw_val is not None:
                    output_manager.generate_validation_report(
                        validation_df=dhw_val,
                        dhw_data=self._dhw_data,
                        pcrvi_data=getattr(self, '_enhanced_pcrvi_ts',
                                           self._pcrvi_timeseries),
                        pcrvi_skill=getattr(self, '_enhanced_pcrvi_skill',
                                            self._pcrvi_skill),
                    )
                    results['steps_completed'].append('validation_report')
            except Exception as e:
                self.logger.warning(f"Validation report failed: {e}")

            # Step 9: DHW Forecasting
            if self._sst_data is not None and self._dhw_data is not None:
                try:
                    forecast_results = self.step_dhw_forecasting()
                    results['dhw_forecasting'] = forecast_results
                    results['steps_completed'].append('dhw_forecasting')
                except Exception as e:
                    self.logger.warning(f"DHW forecasting failed: {e}")

            # Step 10: Save ALL outputs
            self.logger.info("Step 10: Saving all outputs...")
            saved = self.save_all_outputs()
            results['saved_files'] = {k: str(v) for k, v in saved.items()}
            results['steps_completed'].append('outputs_saved')

            # Step 11: Generate visualizations + poster plots
            self.logger.info("Step 11: Generating visualizations + poster plots...")
            saved_plots = {}
            try:
                saved_plots = self.generate_visualizations()
                results['visualizations'] = {
                    k: str(v) for k, v in saved_plots.items() if v}
                results['steps_completed'].append('visualizations')
            except Exception as e:
                self.logger.warning(f"Visualization failed: {e}")

            # Step 12: NOAA bleaching maps
            try:
                # Filter to satellite era (NOAA CRW ≥ 1998) and data range
                data_start_year = self._dhw_data.index.min().year if self._dhw_data is not None else 1998
                min_year = max(1998, data_start_year)
                bleaching_years = [
                    y for y in self.config.region.KNOWN_BLEACHING_EVENTS.keys()
                    if y >= min_year
                ]
                noaa_maps_dir = self.config.data_dir / "noaa_maps"
                noaa_basin = getattr(
                    self.config.region, 'noaa_basin', 'indian')
                noaa_maps = self.noaa_client.download_crw_bleaching_maps(
                    years=bleaching_years, output_dir=noaa_maps_dir,
                    noaa_basin=noaa_basin)
                self.logger.info(f"Downloaded {len(noaa_maps)} NOAA maps "
                               f"(basin: {noaa_basin})")
            except Exception as e:
                self.logger.warning(f"NOAA maps failed: {e}")

            # Step 13: Reports
            self.logger.info("Step 13: Generating reports...")
            report_paths = self.generate_report(
                visualization_paths=saved_plots)
            results['report'] = {k: str(v) for k, v in report_paths.items()}
            results['steps_completed'].append('reports')

            # Step 14: Alert
            self.logger.info("Step 14: Weekly alert...")
            try:
                alert = self.generate_weekly_alert()
                results['latest_alert'] = alert
                results['steps_completed'].append('alert')
            except Exception as e:
                import traceback
                self.logger.warning(f"Weekly alert failed: {e}")
                self.logger.warning(traceback.format_exc())

            results['success'] = True
            self.logger.info("=" * 60)
            self.logger.info(
                f"Workflow COMPLETE — {len(results['steps_completed'])} steps")
            self.logger.info("=" * 60)

            # Step 15: Google Drive backup (non-critical)
            # Set config.gdrive_enabled = True and config.gdrive_root to enable
            if getattr(self.config, 'gdrive_enabled', False):
                try:
                    from .gdrive_sync import sync_pipeline_outputs
                    gdrive_root = getattr(self.config, 'gdrive_root', None)
                    ok = sync_pipeline_outputs(self.config, gdrive_root)
                    if ok:
                        results['steps_completed'].append('gdrive_sync')
                except ImportError:
                    self.logger.debug("gdrive_sync module not available")
                except Exception as e:
                    self.logger.warning(f"Google Drive sync failed: {e}")

        except Exception as e:
            results['success'] = False
            results['error'] = str(e)
            import traceback
            tb = traceback.format_exc()
            self.logger.error(f"Workflow failed: {e}\n{tb}")
            raise

        return results
    
    
