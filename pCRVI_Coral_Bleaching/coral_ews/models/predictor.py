"""
Machine Learning Models for Coral Bleaching Prediction
========================================================

Implements ML models following Cheung et al. 2025 methodology:
- Ordinal Random Forest for 3-class bleaching prediction
- Leave-One-Year-Out cross-validation
- SHAP analysis for interpretability

Based on:
- Cheung et al. 2025 (Global Ecology and Biogeography)
- Meyer et al. 2019 (spatial cross-validation)
"""

from typing import Optional, Union, List, Dict, Any, Tuple
from datetime import datetime
from pathlib import Path
import warnings

import numpy as np
import pandas as pd

from ..exceptions import ModelError, ValidationError
from ..logger import get_logger, log_execution_time, ProgressLogger
from ..config import Config, MLParameters

# Try to import sklearn
try:
    from sklearn.ensemble import RandomForestClassifier
    from sklearn.model_selection import cross_val_score, LeaveOneGroupOut
    from sklearn.metrics import (
        accuracy_score, cohen_kappa_score, classification_report,
        confusion_matrix, f1_score, precision_score, recall_score
    )
    from sklearn.preprocessing import StandardScaler
    SKLEARN_AVAILABLE = True
except ImportError:
    SKLEARN_AVAILABLE = False

# Try to import SHAP
try:
    import shap
    SHAP_AVAILABLE = True
except ImportError:
    SHAP_AVAILABLE = False


class BleachingPredictor:
    """
    Coral bleaching prediction model.
    
    Uses Random Forest classifier with ordinal encoding for 3-class
    bleaching severity prediction (none, moderate, severe).
    """
    
    def __init__(self, config: Optional[Config] = None):
        """
        Initialize predictor.
        
        Parameters
        ----------
        config : Config, optional
            Configuration object
        """
        if not SKLEARN_AVAILABLE:
            raise ModelError(
                "scikit-learn not installed",
                model_type="RandomForest",
                suggestion="Install with: pip install scikit-learn"
            )
        
        self.config = config or Config()
        self.logger = get_logger("coral_ews.model")
        self.ml_params = self.config.ml_params
        
        self.model = None
        self.feature_names = None
        self.scaler = StandardScaler()
        self.is_fitted = False
        
        self.logger.info("BleachingPredictor initialized")
    
    def _validate_data(
        self,
        X: np.ndarray,
        y: Optional[np.ndarray] = None,
        stage: str = "training"
    ) -> None:
        """Validate input data."""
        # Check X
        if not isinstance(X, np.ndarray):
            raise ValidationError(
                "X must be a numpy array",
                field="X",
                expected="np.ndarray",
                actual=type(X).__name__
            )
        
        if X.ndim != 2:
            raise ValidationError(
                f"X must be 2D, got {X.ndim}D",
                field="X.ndim",
                expected=2,
                actual=X.ndim
            )
        
        if np.isnan(X).any():
            nan_count = np.isnan(X).sum()
            raise ValidationError(
                f"X contains {nan_count} NaN values",
                field="X",
                suggestion="Remove or impute missing values before training"
            )
        
        # Check y for training
        if stage == "training":
            if y is None:
                raise ValidationError(
                    "y is required for training",
                    field="y"
                )
            
            if len(X) != len(y):
                raise ValidationError(
                    f"X and y have different lengths: {len(X)} vs {len(y)}",
                    field="X, y"
                )
            
            unique_classes = np.unique(y[~np.isnan(y)])
            if len(unique_classes) < 2:
                raise ValidationError(
                    f"y must have at least 2 classes, found {len(unique_classes)}",
                    field="y",
                    actual=unique_classes
                )
        
        # Check for prediction
        if stage == "prediction" and self.is_fitted:
            if X.shape[1] != len(self.feature_names):
                raise ValidationError(
                    f"X has {X.shape[1]} features, model expects {len(self.feature_names)}",
                    field="X.shape[1]",
                    expected=len(self.feature_names),
                    actual=X.shape[1]
                )
    
    @log_execution_time()
    def fit(
        self,
        X: np.ndarray,
        y: np.ndarray,
        feature_names: Optional[List[str]] = None,
        scale_features: bool = True
    ) -> 'BleachingPredictor':
        """
        Fit the model to training data.
        
        Parameters
        ----------
        X : np.ndarray
            Feature matrix (n_samples, n_features)
        y : np.ndarray
            Target array (n_samples,)
        feature_names : list, optional
            Names of features
        scale_features : bool
            Whether to scale features
        
        Returns
        -------
        BleachingPredictor
            Fitted model (self)
        """
        self.logger.info(f"Fitting model with {len(X)} samples, {X.shape[1]} features")
        
        # Validate data
        self._validate_data(X, y, stage="training")
        
        # Store feature names
        self.feature_names = feature_names or [f"feature_{i}" for i in range(X.shape[1])]
        
        # Scale features
        if scale_features:
            X_scaled = self.scaler.fit_transform(X)
        else:
            X_scaled = X
        
        # Create and fit model
        rf_params = self.ml_params.rf_params
        
        self.model = RandomForestClassifier(
            n_estimators=rf_params.get('n_estimators', 500),
            max_depth=rf_params.get('max_depth', 10),
            min_samples_split=rf_params.get('min_samples_split', 5),
            min_samples_leaf=rf_params.get('min_samples_leaf', 2),
            class_weight=rf_params.get('class_weight', 'balanced'),
            random_state=rf_params.get('random_state', 42),
            n_jobs=rf_params.get('n_jobs', -1)
        )
        
        try:
            self.model.fit(X_scaled, y)
            self.is_fitted = True
            
            # Log class distribution
            unique, counts = np.unique(y, return_counts=True)
            class_dist = dict(zip(unique, counts))
            
            self.logger.info(
                f"Model fitted successfully:\n"
                f"  Samples: {len(X)}\n"
                f"  Features: {len(self.feature_names)}\n"
                f"  Classes: {class_dist}"
            )
            
            return self
            
        except Exception as e:
            raise ModelError(
                f"Failed to fit model: {str(e)}",
                model_type="RandomForest",
                stage="training",
                original_exception=e
            )
    
    def predict(
        self,
        X: np.ndarray,
        scale_features: bool = True
    ) -> np.ndarray:
        """
        Predict bleaching severity.
        
        Parameters
        ----------
        X : np.ndarray
            Feature matrix
        scale_features : bool
            Whether to scale features
        
        Returns
        -------
        np.ndarray
            Predicted classes
        """
        if not self.is_fitted:
            raise ModelError(
                "Model has not been fitted. Call fit() first.",
                model_type="RandomForest",
                stage="prediction"
            )
        
        self._validate_data(X, stage="prediction")
        
        if scale_features:
            X_scaled = self.scaler.transform(X)
        else:
            X_scaled = X
        
        try:
            predictions = self.model.predict(X_scaled)
            return predictions
        except Exception as e:
            raise ModelError(
                f"Prediction failed: {str(e)}",
                model_type="RandomForest",
                stage="prediction",
                original_exception=e
            )
    
    def predict_proba(
        self,
        X: np.ndarray,
        scale_features: bool = True
    ) -> np.ndarray:
        """
        Predict class probabilities.
        
        Parameters
        ----------
        X : np.ndarray
            Feature matrix
        scale_features : bool
            Whether to scale features
        
        Returns
        -------
        np.ndarray
            Class probabilities (n_samples, n_classes)
        """
        if not self.is_fitted:
            raise ModelError(
                "Model has not been fitted. Call fit() first.",
                model_type="RandomForest",
                stage="prediction"
            )
        
        self._validate_data(X, stage="prediction")
        
        if scale_features:
            X_scaled = self.scaler.transform(X)
        else:
            X_scaled = X
        
        try:
            proba = self.model.predict_proba(X_scaled)
            return proba
        except Exception as e:
            raise ModelError(
                f"Probability prediction failed: {str(e)}",
                model_type="RandomForest",
                stage="prediction",
                original_exception=e
            )
    
    @log_execution_time()
    def cross_validate_loyo(
        self,
        X: np.ndarray,
        y: np.ndarray,
        years: np.ndarray,
        feature_names: Optional[List[str]] = None,
        scale_features: bool = True
    ) -> Dict[str, Any]:
        """
        Perform Leave-One-Year-Out cross-validation.
        
        This avoids temporal autocorrelation in validation.
        
        Parameters
        ----------
        X : np.ndarray
            Feature matrix
        y : np.ndarray
            Target array
        years : np.ndarray
            Year for each sample (for grouping)
        feature_names : list, optional
            Feature names
        scale_features : bool
            Whether to scale features
        
        Returns
        -------
        dict
            Cross-validation results including scores per fold
        """
        self.logger.info("Performing Leave-One-Year-Out cross-validation...")
        
        self._validate_data(X, y, stage="training")
        
        if len(years) != len(X):
            raise ValidationError(
                f"years length ({len(years)}) doesn't match X length ({len(X)})",
                field="years"
            )
        
        unique_years = np.unique(years)
        n_folds = len(unique_years)
        
        self.logger.info(f"Cross-validating with {n_folds} folds (years: {unique_years.min()}-{unique_years.max()})")
        
        # Store results
        fold_results = []
        all_y_true = []
        all_y_pred = []
        
        logo = LeaveOneGroupOut()
        
        for fold_idx, (train_idx, test_idx) in enumerate(logo.split(X, y, years)):
            test_year = years[test_idx[0]]
            
            X_train, X_test = X[train_idx], X[test_idx]
            y_train, y_test = y[train_idx], y[test_idx]
            
            # Scale features
            if scale_features:
                scaler = StandardScaler()
                X_train_scaled = scaler.fit_transform(X_train)
                X_test_scaled = scaler.transform(X_test)
            else:
                X_train_scaled, X_test_scaled = X_train, X_test
            
            # Train model
            rf_params = self.ml_params.rf_params
            model = RandomForestClassifier(
                n_estimators=rf_params.get('n_estimators', 500),
                max_depth=rf_params.get('max_depth', 10),
                min_samples_split=rf_params.get('min_samples_split', 5),
                min_samples_leaf=rf_params.get('min_samples_leaf', 2),
                class_weight=rf_params.get('class_weight', 'balanced'),
                random_state=rf_params.get('random_state', 42),
                n_jobs=rf_params.get('n_jobs', -1)
            )
            
            try:
                model.fit(X_train_scaled, y_train)
                y_pred = model.predict(X_test_scaled)
                
                # Calculate metrics for this fold
                fold_accuracy = accuracy_score(y_test, y_pred)
                fold_kappa = cohen_kappa_score(y_test, y_pred)
                fold_f1 = f1_score(y_test, y_pred, average='weighted')
                
                fold_results.append({
                    'year': test_year,
                    'n_train': len(train_idx),
                    'n_test': len(test_idx),
                    'accuracy': fold_accuracy,
                    'kappa': fold_kappa,
                    'f1_weighted': fold_f1
                })
                
                all_y_true.extend(y_test)
                all_y_pred.extend(y_pred)
                
                self.logger.debug(
                    f"Fold {fold_idx + 1}/{n_folds} (Year {test_year}): "
                    f"Accuracy={fold_accuracy:.3f}, Kappa={fold_kappa:.3f}"
                )
                
            except Exception as e:
                self.logger.warning(f"Fold {fold_idx + 1} failed: {str(e)}")
                fold_results.append({
                    'year': test_year,
                    'error': str(e)
                })
        
        # Calculate overall metrics
        all_y_true = np.array(all_y_true)
        all_y_pred = np.array(all_y_pred)
        
        overall_metrics = {
            'accuracy': accuracy_score(all_y_true, all_y_pred),
            'kappa': cohen_kappa_score(all_y_true, all_y_pred),
            'f1_weighted': f1_score(all_y_true, all_y_pred, average='weighted'),
            'confusion_matrix': confusion_matrix(all_y_true, all_y_pred).tolist(),
            'classification_report': classification_report(all_y_true, all_y_pred, output_dict=True)
        }
        
        # Calculate mean and std across folds
        valid_folds = [f for f in fold_results if 'accuracy' in f]
        
        cv_summary = {
            'n_folds': n_folds,
            'n_successful_folds': len(valid_folds),
            'mean_accuracy': np.mean([f['accuracy'] for f in valid_folds]),
            'std_accuracy': np.std([f['accuracy'] for f in valid_folds]),
            'mean_kappa': np.mean([f['kappa'] for f in valid_folds]),
            'std_kappa': np.std([f['kappa'] for f in valid_folds]),
            'mean_f1': np.mean([f['f1_weighted'] for f in valid_folds]),
            'std_f1': np.std([f['f1_weighted'] for f in valid_folds])
        }
        
        results = {
            'fold_results': fold_results,
            'overall_metrics': overall_metrics,
            'cv_summary': cv_summary
        }
        
        self.logger.info(
            f"LOYO Cross-validation complete:\n"
            f"  Folds: {len(valid_folds)}/{n_folds} successful\n"
            f"  Mean Accuracy: {cv_summary['mean_accuracy']:.3f} ± {cv_summary['std_accuracy']:.3f}\n"
            f"  Mean Kappa: {cv_summary['mean_kappa']:.3f} ± {cv_summary['std_kappa']:.3f}\n"
            f"  Mean F1: {cv_summary['mean_f1']:.3f} ± {cv_summary['std_f1']:.3f}"
        )
        
        return results
    
    def get_feature_importance(self) -> pd.DataFrame:
        """Get feature importance from fitted model."""
        if not self.is_fitted:
            raise ModelError(
                "Model has not been fitted",
                model_type="RandomForest",
                stage="feature_importance"
            )
        
        importance = self.model.feature_importances_
        
        df = pd.DataFrame({
            'feature': self.feature_names,
            'importance': importance
        }).sort_values('importance', ascending=False)
        
        df['cumulative_importance'] = df['importance'].cumsum()
        df['rank'] = range(1, len(df) + 1)
        
        return df.reset_index(drop=True)
    
    @log_execution_time()
    def explain_with_shap(
        self,
        X: np.ndarray,
        n_samples: Optional[int] = None,
        scale_features: bool = True
    ) -> Dict[str, Any]:
        """
        Generate SHAP explanations for predictions.
        
        Parameters
        ----------
        X : np.ndarray
            Feature matrix to explain
        n_samples : int, optional
            Number of samples to explain (default: all)
        scale_features : bool
            Whether to scale features
        
        Returns
        -------
        dict
            SHAP values and explanation objects
        """
        if not SHAP_AVAILABLE:
            raise ModelError(
                "SHAP not installed",
                model_type="RandomForest",
                suggestion="Install with: pip install shap"
            )
        
        if not self.is_fitted:
            raise ModelError(
                "Model has not been fitted",
                model_type="RandomForest",
                stage="shap_explanation"
            )
        
        self.logger.info("Generating SHAP explanations...")
        
        # Limit samples if specified
        if n_samples is not None and n_samples < len(X):
            indices = np.random.choice(len(X), n_samples, replace=False)
            X_explain = X[indices]
        else:
            X_explain = X
        
        if scale_features:
            X_scaled = self.scaler.transform(X_explain)
        else:
            X_scaled = X_explain
        
        try:
            # Create SHAP explainer
            explainer = shap.TreeExplainer(self.model)
            shap_values = explainer.shap_values(X_scaled)
            
            # Calculate mean absolute SHAP values per feature
            if isinstance(shap_values, list):
                # Multi-class: average across classes
                mean_shap = np.mean([np.abs(sv).mean(axis=0) for sv in shap_values], axis=0)
            else:
                mean_shap = np.abs(shap_values).mean(axis=0)
            
            shap_importance = pd.DataFrame({
                'feature': self.feature_names,
                'mean_abs_shap': mean_shap
            }).sort_values('mean_abs_shap', ascending=False)
            
            self.logger.info(
                f"SHAP analysis complete:\n"
                f"  Samples explained: {len(X_explain)}\n"
                f"  Top features: {list(shap_importance['feature'].head(5))}"
            )
            
            return {
                'shap_values': shap_values,
                'expected_value': explainer.expected_value,
                'feature_importance': shap_importance,
                'explainer': explainer
            }
            
        except Exception as e:
            raise ModelError(
                f"SHAP explanation failed: {str(e)}",
                model_type="RandomForest",
                stage="shap_explanation",
                original_exception=e
            )
    
    def save_model(self, path: Path) -> None:
        """Save fitted model to file."""
        import joblib
        
        if not self.is_fitted:
            raise ModelError(
                "Cannot save unfitted model",
                model_type="RandomForest"
            )
        
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        
        model_data = {
            'model': self.model,
            'scaler': self.scaler,
            'feature_names': self.feature_names,
            'ml_params': self.ml_params
        }
        
        joblib.dump(model_data, path)
        self.logger.info(f"Model saved to {path}")
    
    def load_model(self, path: Path) -> 'BleachingPredictor':
        """Load model from file."""
        import joblib
        
        path = Path(path)
        if not path.exists():
            raise ModelError(
                f"Model file not found: {path}",
                model_type="RandomForest"
            )
        
        try:
            model_data = joblib.load(path)
            self.model = model_data['model']
            self.scaler = model_data['scaler']
            self.feature_names = model_data['feature_names']
            self.ml_params = model_data.get('ml_params', self.ml_params)
            self.is_fitted = True
            
            self.logger.info(f"Model loaded from {path}")
            return self
            
        except Exception as e:
            raise ModelError(
                f"Failed to load model: {str(e)}",
                model_type="RandomForest",
                original_exception=e
            )


def evaluate_model(
    y_true: np.ndarray,
    y_pred: np.ndarray,
    class_names: Optional[List[str]] = None
) -> Dict[str, Any]:
    """
    Comprehensive model evaluation.
    
    Parameters
    ----------
    y_true : np.ndarray
        True labels
    y_pred : np.ndarray
        Predicted labels
    class_names : list, optional
        Names for classes
    
    Returns
    -------
    dict
        Evaluation metrics
    """
    logger = get_logger("coral_ews.model")
    
    if class_names is None:
        class_names = ['none', 'moderate', 'severe']
    
    metrics = {
        'accuracy': accuracy_score(y_true, y_pred),
        'kappa': cohen_kappa_score(y_true, y_pred),
        'f1_weighted': f1_score(y_true, y_pred, average='weighted'),
        'f1_macro': f1_score(y_true, y_pred, average='macro'),
        'precision_weighted': precision_score(y_true, y_pred, average='weighted'),
        'recall_weighted': recall_score(y_true, y_pred, average='weighted'),
        'confusion_matrix': confusion_matrix(y_true, y_pred),
        'classification_report': classification_report(
            y_true, y_pred, 
            target_names=class_names,
            output_dict=True
        )
    }
    
    logger.info(
        f"Model Evaluation:\n"
        f"  Accuracy: {metrics['accuracy']:.3f}\n"
        f"  Kappa: {metrics['kappa']:.3f}\n"
        f"  F1 (weighted): {metrics['f1_weighted']:.3f}\n"
        f"  F1 (macro): {metrics['f1_macro']:.3f}"
    )
    
    return metrics
