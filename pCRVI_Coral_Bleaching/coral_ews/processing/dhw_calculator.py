"""
Degree Heating Week (DHW) Calculation Module
=============================================

Implements DHW calculation following Liu et al. 2014 methodology:
"Reef-Scale Thermal Stress Monitoring of Coral Ecosystems: 
New 5-km Global Products from NOAA Coral Reef Watch"
Remote Sensing 2014, 6, 11579-11606

Formula:
DHW(i) = Σ(HS(j) / 7) for all j where HS(j) ≥ 1°C, over 84 days

Where:
- HS (HotSpot) = max(0, SST - MMM)
- MMM = Maximum Monthly Mean SST (climatological baseline)
- Accumulation period = 84 days (12 weeks)
- Only HotSpots ≥ 1°C are accumulated
- Division by 7 converts daily values to degree-weeks

All formulas verified against NOAA CRW 5km Methodology:
https://coralreefwatch.noaa.gov/product/5km/methodology.php
"""

from typing import Optional, Union, Tuple, Dict, Any
from datetime import datetime, date
from pathlib import Path

import numpy as np
import pandas as pd

from ..exceptions import ProcessingError, ValidationError
from ..logger import get_logger, log_execution_time, ProgressLogger
from ..config import Config, DHWParameters

# Try to import xarray
try:
    import xarray as xr
    XARRAY_AVAILABLE = True
except ImportError:
    XARRAY_AVAILABLE = False

class DHWCalculator:
    """
    Degree Heating Week calculator following Liu et al. 2014 methodology.
    
    This class calculates DHW from SST data using the NOAA Coral Reef Watch
    algorithm, which accumulates thermal stress over 84 days.
    
    Attributes
    ----------
    config : Config
        Configuration object
    logger : ContextLogger
        Logger instance
    mmm : float or np.ndarray
        Maximum Monthly Mean SST (scalar or spatial array)
    params : DHWParameters
        DHW calculation parameters
    """
    
    def __init__(
        self,
        config: Optional[Config] = None, 
        use_calibrated_thresholds: bool = True,
        mmm: Optional[Union[float, np.ndarray]] = None
    ):
        """
        Initialize DHW calculator.
        
        Parameters
        ----------
        config : Config, optional
            Configuration object
        mmm : float or np.ndarray, optional
            Maximum Monthly Mean SST. If None, uses config.region.mmm_sst
        """
        self.config = config or Config()
        self.logger = get_logger("coral_ews.dhw")
        self.params = self.config.dhw_params
        
        # Standard NOAA thresholds
        self.NOAA_THRESHOLDS = {
            'no_stress': 0.0,
            'watch': 0.0,
            'warning': 4.0,
            'alert_level_1': 8.0,
            'alert_level_2': 12.0,
        }

        # Calibrated thresholds for Andaman & Nicobar Islands
        # Based on historical correlation analysis
        self.ANI_CALIBRATED_THRESHOLDS = {
            'no_stress': 0.0,
            'watch': 1.0,
            'warning': 3.0,
            'alert_level_1': 6.0,
            'alert_level_2': 8.0,
        }

        # Set MMM
        if mmm is not None:
            self.mmm = mmm
        else:
            self.mmm = self.config.region.mmm_sst
        
        # Set thresholds
        if use_calibrated_thresholds:
            self.thresholds = self.ANI_CALIBRATED_THRESHOLDS.copy()
            self.logger.info("Using ANI-calibrated DHW thresholds")
        else:
            self.thresholds = self.NOAA_THRESHOLDS.copy()
            self.logger.info("Using standard NOAA DHW thresholds")
        
        self.logger.info(
            f"DHW Calculator initialized:\n"
            f"  MMM: {self.mmm if isinstance(self.mmm, float) else 'Spatial array'}\n"
            f"  Accumulation window: {self.params.accumulation_days} days\n"
            f"  HotSpot threshold: {self.params.hotspot_threshold}°C"
        )
    
    def _validate_sst(self, sst: np.ndarray) -> None:
        """
        Validate SST data.
        
        Parameters
        ----------
        sst : np.ndarray
            SST array to validate
        
        Raises
        ------
        ValidationError
            If SST data is invalid
        """
        if not isinstance(sst, np.ndarray):
            raise ValidationError(
                "SST must be a numpy array",
                field="sst",
                expected="np.ndarray",
                actual=type(sst).__name__
            )
        
        # Check for reasonable temperature range
        valid_mask = ~np.isnan(sst)
        if valid_mask.sum() == 0:
            raise ValidationError(
                "SST array contains only NaN values",
                field="sst"
            )
        
        sst_valid = sst[valid_mask]
        
        if sst_valid.min() < -5 or sst_valid.max() > 45:
            self.logger.warning(
                f"SST values outside typical range: "
                f"min={sst_valid.min():.1f}°C, max={sst_valid.max():.1f}°C"
            )
        
        # Check for tropical reef SST range
        if sst_valid.mean() < 20 or sst_valid.mean() > 35:
            self.logger.warning(
                f"Mean SST ({sst_valid.mean():.1f}°C) outside typical tropical range (20-35°C)"
            )
    
    def calculate_hotspot(
        self,
        sst: Union[np.ndarray, float],
        mmm: Optional[Union[np.ndarray, float]] = None
    ) -> Union[np.ndarray, float]:
        """
        Calculate Coral Bleaching HotSpot.
        
        HotSpot = max(0, SST - MMM)
        
        Parameters
        ----------
        sst : np.ndarray or float
            Sea surface temperature
        mmm : np.ndarray or float, optional
            Maximum Monthly Mean (default: self.mmm)
        
        Returns
        -------
        np.ndarray or float
            HotSpot values (positive only)
        """
        if mmm is None:
            mmm = self.mmm
        
        hotspot = sst - mmm
        hotspot = np.maximum(0, hotspot)
        
        return hotspot
    
    def calculate_dhw_timeseries(
        self,
        sst_series: pd.Series,
        mmm: Optional[float] = None
    ) -> pd.DataFrame:
        """
        Calculate DHW time series from SST pandas Series.
        
        Parameters
        ----------
        sst_series : pd.Series
            SST time series with datetime index
        mmm : float, optional
            Maximum Monthly Mean (default: self.mmm)
        
        Returns
        -------
        pd.DataFrame
            DataFrame with date index and columns: sst, hotspot, dhw, alert_level
        
        Raises
        ------
        ValidationError
            If input data is invalid
        ProcessingError
            If calculation fails
        """
        if mmm is None:
            mmm = self.mmm
        
        self.logger.info(
            f"Calculating DHW time series:\n"
            f"  Date range: {sst_series.index.min()} to {sst_series.index.max()}\n"
            f"  Records: {len(sst_series)}\n"
            f"  MMM: {mmm}°C"
        )
        
        # Validate input
        if not isinstance(sst_series.index, pd.DatetimeIndex):
            try:
                sst_series.index = pd.to_datetime(sst_series.index)
            except Exception as e:
                raise ValidationError(
                    "Could not convert index to datetime",
                    field="sst_series.index",
                    original_exception=e
                )
        
        # Sort by date
        sst_series = sst_series.sort_index()
        
        # Check for gaps
        expected_days = (sst_series.index.max() - sst_series.index.min()).days + 1
        actual_days = len(sst_series)
        if actual_days < expected_days * 0.9:
            self.logger.warning(
                f"SST series has significant gaps: {actual_days} of {expected_days} days"
            )
        
        try:
            # Calculate HotSpot
            sst_values = sst_series.values
            hotspot = self.calculate_hotspot(sst_values, mmm)
            
            # Apply threshold for DHW accumulation
            # Only HotSpots >= 1°C contribute to DHW
            threshold = self.params.hotspot_threshold
            hotspot_thresholded = np.where(hotspot >= threshold, hotspot, 0)
            
            # Calculate DHW with rolling 84-day window
            window = self.params.accumulation_days
            divisor = self.params.daily_to_weekly_divisor
            
            # Rolling sum, divided by 7 to convert to degree-weeks
            dhw = pd.Series(hotspot_thresholded, index=sst_series.index).rolling(
                window=window,
                min_periods=window
            ).sum() / divisor
            
            # Create result DataFrame
            result = pd.DataFrame({
                'sst': sst_series.values,
                'hotspot': hotspot,
                'dhw': dhw.values
            }, index=sst_series.index)
            
            # Add alert level
            result['alert_level'] = self._classify_alert_level(result['dhw'].values)
            
            # Log statistics
            valid_dhw = result['dhw'].dropna()
            self.logger.info(
                f"DHW calculation complete:\n"
                f"  Valid DHW values: {len(valid_dhw)}\n"
                f"  DHW range: {valid_dhw.min():.2f} to {valid_dhw.max():.2f} °C-weeks\n"
                f"  Days with DHW >= 4: {(valid_dhw >= 4).sum()}\n"
                f"  Days with DHW >= 8: {(valid_dhw >= 8).sum()}"
            )
            
            return result
            
        except Exception as e:
            if isinstance(e, (ValidationError, ProcessingError)):
                raise
            raise ProcessingError(
                f"DHW calculation failed: {str(e)}",
                operation="DHW_calculation",
                context={"mmm": mmm, "n_records": len(sst_series)},
                original_exception=e
            )
    
    def calculate_dhw_spatial(
        self,
        sst_cube: 'xr.DataArray',
        mmm: Optional[Union[float, 'xr.DataArray']] = None,
        time_dim: str = 'time'
    ) -> 'xr.DataArray':
        """
        Calculate DHW for spatial SST data cube.
        
        Parameters
        ----------
        sst_cube : xr.DataArray
            SST data array with time, lat, lon dimensions
        mmm : float or xr.DataArray, optional
            Maximum Monthly Mean (scalar or spatial)
        time_dim : str
            Name of time dimension
        
        Returns
        -------
        xr.DataArray
            DHW data array
        
        Raises
        ------
        ProcessingError
            If calculation fails
        """
        if not XARRAY_AVAILABLE:
            raise ProcessingError(
                "xarray not available for spatial DHW calculation",
                operation="DHW_spatial",
                suggestion="Install with: pip install xarray"
            )
        
        if mmm is None:
            mmm = self.mmm
        
        self.logger.info(
            f"Calculating spatial DHW:\n"
            f"  Shape: {sst_cube.shape}\n"
            f"  Time range: {sst_cube[time_dim].values[0]} to {sst_cube[time_dim].values[-1]}"
        )
        
        try:
            # Calculate HotSpot
            hotspot = sst_cube - mmm
            hotspot = hotspot.where(hotspot >= 0, 0)
            
            # Apply threshold
            threshold = self.params.hotspot_threshold
            hotspot_thresh = hotspot.where(hotspot >= threshold, 0)
            
            # Rolling sum for DHW
            window = self.params.accumulation_days
            divisor = self.params.daily_to_weekly_divisor
            
            dhw = hotspot_thresh.rolling(
                {time_dim: window},
                min_periods=window
            ).sum() / divisor
            
            dhw.name = 'dhw'
            dhw.attrs['units'] = '°C-weeks'
            dhw.attrs['long_name'] = 'Degree Heating Week'
            dhw.attrs['methodology'] = 'Liu et al. 2014'
            
            self.logger.info("Spatial DHW calculation complete")
            return dhw
            
        except Exception as e:
            raise ProcessingError(
                f"Spatial DHW calculation failed: {str(e)}",
                operation="DHW_spatial",
                original_exception=e
            )
    
    def _classify_alert_level(self, dhw: np.ndarray) -> np.ndarray:
        """
        Classify bleaching alert level from DHW values.

        Uses ANI-calibrated thresholds from self.thresholds:
            0: No Stress       (DHW = 0)
            1: Watch            (DHW > watch threshold, default 1.0)
            2: Warning          (DHW > warning threshold, default 3.0)
            3: Alert Level 1    (DHW > alert_level_1 threshold, default 6.0)
            4: Alert Level 2    (DHW > alert_level_2 threshold, default 8.0)
        """
        t = self.thresholds
        alert = np.zeros_like(dhw, dtype=float)
        alert = np.where(dhw > t.get('watch', 1.0), 1, alert)
        alert = np.where(dhw > t.get('warning', 3.0), 2, alert)
        alert = np.where(dhw > t.get('alert_level_1', 6.0), 3, alert)
        alert = np.where(dhw > t.get('alert_level_2', 8.0), 4, alert)
        alert = np.where(np.isnan(dhw), np.nan, alert)
        return alert
    
    def validate_against_noaa(
        self,
        calculated_dhw: pd.Series,
        noaa_dhw: pd.Series,
        tolerance: float = 0.5
    ) -> Dict[str, Any]:
        """
        Validate calculated DHW against NOAA CRW values.
        
        Parameters
        ----------
        calculated_dhw : pd.Series
            Our calculated DHW
        noaa_dhw : pd.Series
            NOAA CRW DHW values
        tolerance : float
            Acceptable difference in °C-weeks
        
        Returns
        -------
        dict
            Validation statistics
        """
        self.logger.info("Validating DHW against NOAA CRW...")
        
        # Align series
        common_idx = calculated_dhw.index.intersection(noaa_dhw.index)
        
        if len(common_idx) == 0:
            raise ValidationError(
                "No overlapping dates between calculated and NOAA DHW",
                field="date_index"
            )
        
        calc = calculated_dhw.loc[common_idx]
        noaa = noaa_dhw.loc[common_idx]
        
        # Remove NaN
        valid_mask = ~(calc.isna() | noaa.isna())
        calc = calc[valid_mask]
        noaa = noaa[valid_mask]
        
        # Calculate metrics
        diff = calc - noaa
        mae = np.abs(diff).mean()
        rmse = np.sqrt((diff ** 2).mean())
        correlation = calc.corr(noaa)
        
        # Check tolerance
        within_tolerance = (np.abs(diff) <= tolerance).mean() * 100
        
        result = {
            'n_comparisons': len(calc),
            'date_range': (common_idx.min(), common_idx.max()),
            'mae': mae,
            'rmse': rmse,
            'correlation': correlation,
            'within_tolerance_pct': within_tolerance,
            'tolerance': tolerance,
            'max_difference': np.abs(diff).max(),
            'bias': diff.mean()
        }
        
        self.logger.info(
            f"Validation results:\n"
            f"  Comparisons: {result['n_comparisons']}\n"
            f"  MAE: {mae:.3f} °C-weeks\n"
            f"  RMSE: {rmse:.3f} °C-weeks\n"
            f"  Correlation: {correlation:.3f}\n"
            f"  Within ±{tolerance}°C-weeks: {within_tolerance:.1f}%"
        )
        
        return result


    def get_alert_level(self, dhw: float) -> Tuple[int, str]:
        """
        Get alert level for a DHW value using configured thresholds.
        
        Parameters
        ----------
        dhw : float
            DHW value
        
        Returns
        -------
        tuple
            (level_number, level_name)
        
        Alert Levels (more nuanced):
            0: No Stress (DHW = 0)
            1: Watch - Thermal Stress Building (0 < DHW < 4)
            2: Warning - Partial/Minor Bleaching Possible (4 ≤ DHW < 6)
            3: Alert Level 1 - Moderate Bleaching Likely (6 ≤ DHW < 8)
            4: Alert Level 2 - Significant Bleaching Expected (8 ≤ DHW < 12)
            5: Alert Level 3 - Mass Bleaching/Mortality (DHW ≥ 12)
        """
        if dhw >= self.thresholds['alert_level_2']:  # 12 (NOAA) or 8 (calibrated)
            return (5, 'Alert Level 3 - Mass Bleaching/Mortality')
        elif dhw >= self.thresholds['alert_level_1']:  # 8 (NOAA) or 6 (calibrated)
            return (4, 'Alert Level 2 - Significant Bleaching')
        elif dhw >= 6.0:  # New intermediate level
            return (3, 'Alert Level 1 - Moderate Bleaching')
        elif dhw >= self.thresholds['warning']:  # 4 (NOAA) or 3 (calibrated)
            return (2, 'Warning - Partial/Minor Bleaching')
        elif dhw >= self.thresholds['watch']:  # 0 (NOAA) or 1 (calibrated)
            return (1, 'Watch - Thermal Stress Building')
        else:
            return (0, 'No Stress')


    def validate_against_historical(
        self,
        dhw_data: pd.DataFrame,
        known_events: Dict[int, Dict] = None
    ) -> pd.DataFrame:
        """
        Validate calculated DHW against known historical bleaching events.
        
        Parameters
        ----------
        dhw_data : pd.DataFrame
            Calculated DHW time series
        known_events : dict
            Known bleaching events {year: {'severity': str, 'dhw_reported': float}}
        
        Returns
        -------
        pd.DataFrame
            Validation results comparing model to observations
        """
        if known_events is None:
            known_events = {
                1998: {'severity': 'severe', 'dhw_reported': 4.9, 'bleaching_pct': 80},
                2005: {'severity': 'moderate', 'dhw_reported': 6.0, 'bleaching_pct': 25},
                2010: {'severity': 'catastrophic', 'dhw_reported': 11.7, 'bleaching_pct': 70},
                2016: {'severity': 'severe', 'dhw_reported': 7.2, 'bleaching_pct': 83.6},
                2024: {'severity': 'minor', 'dhw_reported': 7.5, 'bleaching_pct': 15},
            }
        
        dhw_copy = dhw_data.copy()
        dhw_copy['year'] = dhw_copy.index.year
        annual_max = dhw_copy.groupby('year')['dhw'].max()
        
        validation_results = []
        for year, event_info in known_events.items():
            if year in annual_max.index:
                model_dhw = annual_max[year]
                reported_dhw = event_info.get('dhw_reported')
                
                # Determine model alert level
                level_num, level_name = self.get_alert_level(model_dhw)
                
                # Calculate discrepancy
                if reported_dhw:
                    discrepancy = model_dhw - reported_dhw
                    discrepancy_pct = (discrepancy / reported_dhw) * 100 if reported_dhw > 0 else 0
                else:
                    discrepancy = None
                    discrepancy_pct = None
                
                validation_results.append({
                    'year': year,
                    'model_dhw': model_dhw,
                    'reported_dhw': reported_dhw,
                    'discrepancy': discrepancy,
                    'discrepancy_pct': discrepancy_pct,
                    'model_alert_level': level_num,
                    'model_alert_name': level_name,
                    'observed_severity': event_info['severity'],
                    'observed_bleaching_pct': event_info.get('bleaching_pct'),
                    'match_quality': self._assess_match_quality(model_dhw, event_info)
                })
        
        return pd.DataFrame(validation_results)


    def _assess_match_quality(self, model_dhw: float, event_info: Dict) -> str:
        """Assess how well model matches observed event."""
        severity = event_info['severity']
        
        if severity == 'catastrophic':
            if model_dhw >= 8.0:
                return 'GOOD'
            elif model_dhw >= 6.0:
                return 'UNDERESTIMATED'
            else:
                return 'MISSED'
        elif severity == 'severe':
            if model_dhw >= 6.0:
                return 'GOOD'
            elif model_dhw >= 4.0:
                return 'UNDERESTIMATED'
            else:
                return 'MISSED'
        elif severity == 'moderate':
            if 3.0 <= model_dhw <= 7.0:
                return 'GOOD'
            elif model_dhw < 3.0:
                return 'MISSED'
            else:
                return 'OVERESTIMATED'
        elif severity == 'minor':
            if model_dhw <= 4.0:
                return 'GOOD'
            elif model_dhw <= 6.0:
                return 'SLIGHT OVERESTIMATE'
            else:
                return 'OVERESTIMATED'
        else:
            return 'UNKNOWN'
        
def calculate_dhw_from_sst(
    sst: Union[pd.Series, np.ndarray],
    mmm: float,
    dates: Optional[pd.DatetimeIndex] = None,
    accumulation_days: int = 84,
    hotspot_threshold: float = 1.0
) -> pd.DataFrame:
    """
    Convenience function to calculate DHW from SST data.
    
    Parameters
    ----------
    sst : pd.Series or np.ndarray
        SST values
    mmm : float
        Maximum Monthly Mean temperature
    dates : pd.DatetimeIndex, optional
        Dates (required if sst is np.ndarray)
    accumulation_days : int
        DHW accumulation window (default: 84)
    hotspot_threshold : float
        Minimum HotSpot for accumulation (default: 1.0)
    
    Returns
    -------
    pd.DataFrame
        DataFrame with sst, hotspot, dhw columns
    """
    logger = get_logger("coral_ews.dhw")
    
    # Convert to Series if needed
    if isinstance(sst, np.ndarray):
        if dates is None:
            raise ValidationError(
                "dates parameter required when sst is numpy array",
                field="dates"
            )
        sst = pd.Series(sst, index=dates)
    
    logger.info(f"Calculating DHW: MMM={mmm}°C, window={accumulation_days} days")
    
    # Calculate HotSpot
    hotspot = np.maximum(0, sst.values - mmm)
    
    # Threshold for accumulation
    hotspot_thresh = np.where(hotspot >= hotspot_threshold, hotspot, 0)
    
    # Rolling sum converted to degree-weeks
    dhw = pd.Series(hotspot_thresh, index=sst.index).rolling(
        window=accumulation_days,
        min_periods=accumulation_days
    ).sum() / 7.0
    
    return pd.DataFrame({
        'sst': sst.values,
        'hotspot': hotspot,
        'dhw': dhw.values
    }, index=sst.index)