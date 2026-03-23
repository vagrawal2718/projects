"""
Processing Module
=================

Data processing and feature engineering:
- DHW calculation (Liu et al. 2014)
- Anomaly calculation
- Feature engineering
"""

from .dhw_calculator import DHWCalculator, calculate_dhw_from_sst
from .feature_engineering import FeatureEngineer

__all__ = [
    'DHWCalculator',
    'calculate_dhw_from_sst',
    'FeatureEngineer'
]
