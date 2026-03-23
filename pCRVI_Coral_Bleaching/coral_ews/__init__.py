"""
Coral Bleaching Early Warning System
====================================

A comprehensive, modular Python package for satellite-based coral bleaching
prediction using Google Earth Engine, Copernicus Marine Data, NOAA climate products, and machine learning.

Primary vulnerability index: Enhanced-pCRVI (7 components).
All data sources, methodologies, and algorithms verified against:
- Google Earth Engine Data Catalog
- NOAA Coral Reef Watch official documentation
- Copernicus Marine Data Store
- Liu et al. 2014 (Remote Sensing 6:11579-11606)
- Cheung et al. 2025 (Global Ecology and Biogeography)

Author: Vishakha Agrawal
Date: January 2026
"""

__version__ = "2.0.0"
__author__ = "Vishakha Agrawal"

from .config import Config, ANIRegion
from .logger import setup_logger, get_logger
from .enhanced_pcrvi import EnhancedPCRVI
from .poster_visualizations import PosterVisualizer
from .data_cache import DataCache
from .models.xgboost_model import XGBoostPredictor, compare_models
from .models.zero_inflated import HurdleDHWPredictor, Log1pDHWPredictor, TweedieDHWPredictor
from .cross_region import RegionResult, extract_region_result

from .exceptions import (
    CoralEWSError,
    DataAcquisitionError,
    GEEError,
    CopernicusError,
    ValidationError,
    ProcessingError,
    ModelError
)
from .outputs import OutputManager
from .visualization import Visualizer
from .dhw_forecaster import DHWTimeSeriesForecaster

__all__ = [
    'Config',
    'ANIRegion',
    'setup_logger',
    'get_logger',
    'CoralEWSError',
    'OutputManager',
    'Visualizer',
    'DataAcquisitionError',
    'GEEError',
    'CopernicusError',
    'ValidationError',
    'ProcessingError',
    'ModelError',
    'EnhancedPCRVI',
    'PosterVisualizer',
    'DataCache',
    'XGBoostPredictor',
    'compare_models',
    'DHWTimeSeriesForecaster',
    'HurdleDHWPredictor',
    'Log1pDHWPredictor',
    'TweedieDHWPredictor',
    'RegionResult',
    'extract_region_result',
]