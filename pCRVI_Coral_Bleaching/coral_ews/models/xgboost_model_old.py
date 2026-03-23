"""
XGBoost Model Module
====================

Adds XGBoost classifier and regressor for comparison with Random Forest.
"""

from typing import Optional, Dict, List, Any, Tuple
import numpy as np
import pandas as pd

from ..logger import get_logger
from ..exceptions import ModelError

# Try to import XGBoost
try:
    import xgboost as xgb
    XGBOOST_AVAILABLE = True
except ImportError:
    XGBOOST_AVAILABLE = False

# Try to import sklearn
try:
    from sklearn.model_selection import cross_val_score, StratifiedKFold
    from sklearn.metrics import (
        accuracy_score, roc_auc_score, classification_report,
        mean_squared_error, r2_score, mean_absolute_error
    )
    SKLEARN_AVAILABLE = True
except ImportError:
    SKLEARN_AVAILABLE = False


class XGBoostPredictor:
    """
    XGBoost-based predictor for coral bleaching.
    
    Provides both classification (bleaching/no bleaching) and
    regression (severity prediction) capabilities.
    """
    
    def __init__(
        self,
        task: str = 'classification',
        n_estimators: int = 200,
        max_depth: int = 8,
        learning_rate: float = 0.05,
        random_state: int = 42
    ):
        """
        Initialize XGBoost predictor.
        
        Parameters
        ----------
        task : str
            'classification' or 'regression'
        n_estimators : int
            Number of boosting rounds
        max_depth : int
            Maximum tree depth
        learning_rate : float
            Learning rate (eta)
        random_state : int
            Random seed
        """
        if not XGBOOST_AVAILABLE:
            raise ModelError(
                "XGBoost not installed",
                model_type="XGBoost",
                suggestion="Install with: pip install xgboost"
            )
        
        self.logger = get_logger("coral_ews.xgboost")
        self.task = task
        self.random_state = random_state
        
        # Model parameters
        self.params = {
            'n_estimators': n_estimators,
            'max_depth': max_depth,
            'learning_rate': learning_rate,
            'random_state': random_state,
            'n_jobs': -1,
            'verbosity': 0
        }
        
        # Initialize model
        if task == 'classification':
            self.model = xgb.XGBClassifier(
                **self.params,
                objective='binary:logistic',
                eval_metric='auc'
            )
        else:
            self.model = xgb.XGBRegressor(
                **self.params,
                objective='reg:squarederror'
            )
        
        self.is_fitted = False
        self.feature_names = None
        
        self.logger.info(f"XGBoost {task} model initialized")
    
    def fit(
        self,
        X: np.ndarray,
        y: np.ndarray,
        feature_names: Optional[List[str]] = None,
        eval_set: Optional[List[Tuple]] = None
    ) -> 'XGBoostPredictor':
        """
        Fit the XGBoost model.
        
        Parameters
        ----------
        X : np.ndarray
            Feature matrix
        y : np.ndarray
            Target variable
        feature_names : list, optional
            Names of features
        eval_set : list, optional
            Validation set for early stopping
        
        Returns
        -------
        self
        """
        self.feature_names = feature_names or [f"feature_{i}" for i in range(X.shape[1])]
        
        self.logger.info(f"Training XGBoost on {X.shape[0]} samples, {X.shape[1]} features")
        
        # Handle NaN values
        X_clean = np.nan_to_num(X, nan=0.0)
        
        if eval_set:
            self.model.fit(
                X_clean, y,
                eval_set=eval_set,
                verbose=False
            )
        else:
            self.model.fit(X_clean, y)
        
        self.is_fitted = True
        self.logger.info("XGBoost training complete")
        
        return self
    
    def predict(self, X: np.ndarray) -> np.ndarray:
        """Make predictions."""
        if not self.is_fitted:
            raise ModelError("Model not fitted", model_type="XGBoost")
        
        X_clean = np.nan_to_num(X, nan=0.0)
        return self.model.predict(X_clean)
    
    def predict_proba(self, X: np.ndarray) -> np.ndarray:
        """Get probability predictions (classification only)."""
        if self.task != 'classification':
            raise ModelError("predict_proba only available for classification")
        
        if not self.is_fitted:
            raise ModelError("Model not fitted", model_type="XGBoost")
        
        X_clean = np.nan_to_num(X, nan=0.0)
        return self.model.predict_proba(X_clean)
    
    def get_feature_importance(self) -> pd.DataFrame:
        """
        Get feature importance scores.
        
        Returns
        -------
        pd.DataFrame
            Feature importance ranked by score
        """
        if not self.is_fitted:
            raise ModelError("Model not fitted", model_type="XGBoost")
        
        importance = self.model.feature_importances_
        
        df = pd.DataFrame({
            'feature': self.feature_names,
            'importance': importance
        }).sort_values('importance', ascending=False)
        
        df['importance_pct'] = df['importance'] / df['importance'].sum() * 100
        
        return df
    
    def cross_validate(
        self,
        X: np.ndarray,
        y: np.ndarray,
        cv: int = 5
    ) -> Dict[str, Any]:
        """
        Perform cross-validation.
        
        Parameters
        ----------
        X : np.ndarray
            Feature matrix
        y : np.ndarray
            Target
        cv : int
            Number of folds
        
        Returns
        -------
        dict
            Cross-validation results
        """
        X_clean = np.nan_to_num(X, nan=0.0)
        
        if self.task == 'classification':
            scoring = 'roc_auc'
            cv_strategy = StratifiedKFold(n_splits=cv, shuffle=True, random_state=self.random_state)
        else:
            scoring = 'r2'
            from sklearn.model_selection import KFold
            cv_strategy = KFold(n_splits=cv, shuffle=True, random_state=self.random_state)
        
        scores = cross_val_score(self.model, X_clean, y, cv=cv_strategy, scoring=scoring)
        
        results = {
            'cv_scores': scores.tolist(),
            'cv_mean': scores.mean(),
            'cv_std': scores.std(),
            'metric': scoring,
            'n_folds': cv
        }
        
        self.logger.info(f"XGBoost CV {scoring}: {scores.mean():.4f} ± {scores.std():.4f}")
        
        return results
    
    def evaluate(
        self,
        X: np.ndarray,
        y_true: np.ndarray
    ) -> Dict[str, float]:
        """
        Evaluate model on test data.
        
        Parameters
        ----------
        X : np.ndarray
            Feature matrix
        y_true : np.ndarray
            True labels/values
        
        Returns
        -------
        dict
            Evaluation metrics
        """
        y_pred = self.predict(X)
        
        if self.task == 'classification':
            y_proba = self.predict_proba(X)[:, 1]
            
            metrics = {
                'accuracy': accuracy_score(y_true, y_pred),
                'roc_auc': roc_auc_score(y_true, y_proba),
            }
        else:
            metrics = {
                'r2': r2_score(y_true, y_pred),
                'rmse': np.sqrt(mean_squared_error(y_true, y_pred)),
                'mae': mean_absolute_error(y_true, y_pred)
            }
        
        return metrics


def compare_models(
    X_train: np.ndarray,
    y_train: np.ndarray,
    X_test: np.ndarray,
    y_test: np.ndarray,
    feature_names: List[str],
    task: str = 'classification'
) -> pd.DataFrame:
    """
    Compare XGBoost with other models.
    
    Parameters
    ----------
    X_train, y_train : np.ndarray
        Training data
    X_test, y_test : np.ndarray
        Test data
    feature_names : list
        Feature names
    task : str
        'classification' or 'regression'
    
    Returns
    -------
    pd.DataFrame
        Comparison results
    """
    from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
    from sklearn.ensemble import GradientBoostingClassifier, GradientBoostingRegressor
    from sklearn.linear_model import LogisticRegression, Ridge
    
    logger = get_logger("coral_ews.model_comparison")
    
    results = []
    
    # Define models
    if task == 'classification':
        models = {
            'Logistic Regression': LogisticRegression(max_iter=1000, random_state=42),
            'Random Forest': RandomForestClassifier(n_estimators=200, max_depth=15, random_state=42),
            'Gradient Boosting': GradientBoostingClassifier(n_estimators=200, max_depth=8, random_state=42),
            'XGBoost': xgb.XGBClassifier(n_estimators=200, max_depth=8, learning_rate=0.05, random_state=42)
        }
    else:
        models = {
            'Ridge Regression': Ridge(alpha=1.0, random_state=42),
            'Random Forest': RandomForestRegressor(n_estimators=200, max_depth=15, random_state=42),
            'Gradient Boosting': GradientBoostingRegressor(n_estimators=200, max_depth=8, random_state=42),
            'XGBoost': xgb.XGBRegressor(n_estimators=200, max_depth=8, learning_rate=0.05, random_state=42)
        }
    
    # Clean data
    X_train_clean = np.nan_to_num(X_train, nan=0.0)
    X_test_clean = np.nan_to_num(X_test, nan=0.0)
    
    for name, model in models.items():
        logger.info(f"Training {name}...")
        
        try:
            model.fit(X_train_clean, y_train)
            y_pred = model.predict(X_test_clean)
            
            if task == 'classification':
                if hasattr(model, 'predict_proba'):
                    y_proba = model.predict_proba(X_test_clean)[:, 1]
                    roc_auc = roc_auc_score(y_test, y_proba)
                else:
                    roc_auc = None
                
                results.append({
                    'model': name,
                    'accuracy': accuracy_score(y_test, y_pred),
                    'roc_auc': roc_auc
                })
            else:
                results.append({
                    'model': name,
                    'r2': r2_score(y_test, y_pred),
                    'rmse': np.sqrt(mean_squared_error(y_test, y_pred)),
                    'mae': mean_absolute_error(y_test, y_pred)
                })
        except Exception as e:
            logger.warning(f"Failed to train {name}: {e}")
            continue
    
    return pd.DataFrame(results)