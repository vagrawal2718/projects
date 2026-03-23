"""
Zero-Inflated DHW Prediction Models
=====================================

Three approaches to handle the zero-heavy distribution of DHW values:
  1. HurdleDHWPredictor  — Two-stage: P(stress) × E[DHW|stress]
  2. Log1pDHWPredictor   — log1p target transform + GBR
  3. TweedieDHWPredictor — Tweedie loss (compound Poisson-Gamma) via XGBoost

All share the same interface: fit(X, y) and predict(X).

Place this file at:  coral_ews/models/zero_inflated.py
"""

import numpy as np
import pandas as pd
from sklearn.ensemble import GradientBoostingClassifier, GradientBoostingRegressor


class HurdleDHWPredictor:
    """
    Two-stage hurdle model for zero-inflated DHW prediction.

    Stage 1: Binary classifier — P(DHW > 0)
    Stage 2: Positive-only regressor — E[DHW | DHW > 0]
    Final:   y_pred = P(stress) × E[DHW | stress > 0]

    Mirrors the physical process: (1) does thermal anomaly occur?
    (2) how much heat accumulates?
    """

    def __init__(self, n_estimators=200, max_depth=5, learning_rate=0.1,
                 random_state=42):
        self.classifier = GradientBoostingClassifier(
            n_estimators=n_estimators, max_depth=max_depth,
            learning_rate=learning_rate, random_state=random_state)
        self.regressor = GradientBoostingRegressor(
            n_estimators=n_estimators, max_depth=max_depth,
            learning_rate=learning_rate, random_state=random_state)
        self._positive_threshold = 0.0
        self._fitted = False

    def fit(self, X, y):
        y_binary = (y > self._positive_threshold).astype(int)
        self.classifier.fit(X, y_binary)
        pos_mask = y > self._positive_threshold
        if pos_mask.sum() >= 50:
            self.regressor.fit(X[pos_mask], y[pos_mask])
        else:
            # Fallback: train on everything (rare edge case)
            self.regressor.fit(X, np.maximum(y, 0))
        self._fitted = True
        return self

    def predict(self, X):
        p_stress = self.classifier.predict_proba(X)[:, 1]
        dhw_given_stress = np.maximum(self.regressor.predict(X), 0)
        return p_stress * dhw_given_stress

    def predict_components(self, X):
        """Return both P(stress) and E[DHW|stress] separately for analysis."""
        return {
            'p_stress': self.classifier.predict_proba(X)[:, 1],
            'dhw_given_stress': np.maximum(self.regressor.predict(X), 0),
        }

    @property
    def feature_importances_(self):
        """Combined feature importance (average of classifier and regressor)."""
        return (self.classifier.feature_importances_ +
                self.regressor.feature_importances_) / 2


class Log1pDHWPredictor:
    """
    Target-transformed DHW predictor using log1p/expm1.

    Transforms DHW with log(1+x) before training, then inverse-transforms
    predictions with exp(x)-1.  This spreads the zero-heavy distribution
    and reduces MSE dominance of zeros.
    """

    def __init__(self, n_estimators=200, max_depth=5, learning_rate=0.1,
                 random_state=42):
        from sklearn.compose import TransformedTargetRegressor
        base = GradientBoostingRegressor(
            n_estimators=n_estimators, max_depth=max_depth,
            learning_rate=learning_rate, random_state=random_state)
        self.model = TransformedTargetRegressor(
            regressor=base, func=np.log1p, inverse_func=np.expm1)
        self._fitted = False

    def fit(self, X, y):
        self.model.fit(X, y)
        self._fitted = True
        return self

    def predict(self, X):
        return np.maximum(self.model.predict(X), 0)

    @property
    def feature_importances_(self):
        return self.model.regressor_.feature_importances_


class TweedieDHWPredictor:
    """
    Tweedie loss DHW predictor using XGBoost.

    Tweedie distribution (compound Poisson-Gamma) naturally models
    zero-inflated continuous data with a point mass at zero.
    variance_power between 1.0 (Poisson) and 2.0 (Gamma).
    """

    def __init__(self, n_estimators=200, max_depth=5, learning_rate=0.1,
                 tweedie_variance_power=1.5, random_state=42):
        self._use_xgboost = False
        try:
            import xgboost as xgb
            self.model = xgb.XGBRegressor(
                objective='reg:tweedie',
                tweedie_variance_power=tweedie_variance_power,
                n_estimators=n_estimators, max_depth=max_depth,
                learning_rate=learning_rate, random_state=random_state)
            self._use_xgboost = True
        except ImportError:
            from sklearn.linear_model import TweedieRegressor
            self.model = TweedieRegressor(
                power=tweedie_variance_power, link='log')
        self._fitted = False

    def fit(self, X, y):
        self.model.fit(X, y)
        self._fitted = True
        return self

    def predict(self, X):
        return np.maximum(self.model.predict(X), 0)

    @property
    def feature_importances_(self):
        if self._use_xgboost:
            return self.model.feature_importances_
        return np.abs(self.model.coef_)
