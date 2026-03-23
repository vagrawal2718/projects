"""
Models Module
=============

Machine learning models for coral bleaching prediction.
"""

from .predictor import BleachingPredictor, evaluate_model
from .xgboost_model import XGBoostPredictor, compare_models

__all__ = [
    'BleachingPredictor',
    'evaluate_model',
    'XGBoostPredictor',
    'compare_models'
]