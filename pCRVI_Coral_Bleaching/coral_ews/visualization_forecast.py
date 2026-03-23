"""
DHW Forecast Visualization Module
===================================

Plotting functions for DHW time series forecasting results.
This module was missing from the original codebase but is imported
by pipeline.py at line ~1062.

Functions:
    - plot_forecast_model_comparison: Bar chart comparing forecast models
    - create_forecast_dashboard: Multi-panel forecast dashboard
    - plot_forecast_feature_importance: Feature importance bar chart
"""

from typing import Optional, Dict, Any
from pathlib import Path

import numpy as np
import pandas as pd

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

from .naming import friendly_name


def plot_forecast_model_comparison(
    comparison_df: pd.DataFrame,
    output_path: Optional[Path] = None,
    figsize: tuple = (14, 7),
) -> Path:
    """
    Bar chart comparing forecast models on key metrics.

    Parameters
    ----------
    comparison_df : DataFrame
        Model comparison DataFrame with columns: Model, mae, r2, bl_f1, etc.
    output_path : Path, optional
        Where to save the figure.
    """
    fig, axes = plt.subplots(1, 3, figsize=figsize, sharey=False)

    if comparison_df is None or comparison_df.empty:
        plt.close(fig)
        return output_path or Path()

    models = comparison_df['Model'].tolist() if 'Model' in comparison_df.columns else [
        f"Model {i}" for i in range(len(comparison_df))]

    # Panel 1: MAE
    ax = axes[0]
    mae_col = 'mae' if 'mae' in comparison_df.columns else None
    if mae_col:
        bars = ax.barh(models, comparison_df[mae_col], color='#3498db', edgecolor='black')
        ax.set_xlabel('MAE (°C-weeks)')
        ax.set_title('Mean Absolute Error')
        for bar, val in zip(bars, comparison_df[mae_col]):
            ax.text(bar.get_width() + 0.01, bar.get_y() + bar.get_height() / 2,
                    f'{val:.3f}', va='center', fontsize=10)

    # Panel 2: R²
    ax = axes[1]
    r2_col = 'r2' if 'r2' in comparison_df.columns else None
    if r2_col:
        colors = ['#2ecc71' if v > 0.5 else '#e74c3c' if v < 0 else '#f39c12'
                  for v in comparison_df[r2_col]]
        bars = ax.barh(models, comparison_df[r2_col], color=colors, edgecolor='black')
        ax.set_xlabel('R²')
        ax.set_title('R² Score')
        ax.axvline(0, color='gray', linestyle='--', linewidth=0.8)

    # Panel 3: Bleaching F1
    ax = axes[2]
    f1_col = 'bl_f1' if 'bl_f1' in comparison_df.columns else None
    if f1_col:
        bars = ax.barh(models, comparison_df[f1_col], color='#e74c3c', edgecolor='black')
        ax.set_xlabel('F1 Score')
        ax.set_title('Bleaching Detection F1')

    fig.suptitle('DHW Forecast Model Comparison', fontsize=16, fontweight='bold')
    fig.tight_layout()

    if output_path:
        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        fig.savefig(output_path, dpi=300, bbox_inches='tight')

    plt.close(fig)
    return output_path or Path()


def create_forecast_dashboard(
    forecaster: Any,
    dhw_data: pd.DataFrame,
    pcrvi_data: Optional[pd.DataFrame] = None,
    output_path: Optional[Path] = None,
    figsize: tuple = (16, 10),
) -> Path:
    """
    Multi-panel forecast dashboard.

    Parameters
    ----------
    forecaster : DHWTimeSeriesForecaster
        Fitted forecaster object with .models attribute.
    dhw_data : DataFrame
        DHW time series.
    pcrvi_data : DataFrame, optional
        pCRVI time series.
    output_path : Path, optional
        Where to save.
    """
    fig, axes = plt.subplots(2, 2, figsize=figsize)

    # Panel (a): DHW time series with predictions overlay
    ax = axes[0, 0]
    if dhw_data is not None and 'dhw' in dhw_data.columns:
        ax.plot(dhw_data.index, dhw_data['dhw'], color='#D62728',
                alpha=0.7, linewidth=1.2, label='Observed DHW')
        ax.axhline(4, color='orange', linestyle='--', alpha=0.5, label='Alert 1')
        ax.axhline(8, color='red', linestyle='--', alpha=0.5, label='Alert 2')
        ax.set_ylabel('DHW (°C-weeks)')
        ax.set_title('(a) DHW Time Series')
        ax.legend(fontsize=10)

    # Panel (b): Residuals distribution (if predictions available)
    ax = axes[0, 1]
    plotted = False
    if hasattr(forecaster, 'models') and forecaster.models:
        for key, info in forecaster.models.items():
            if 'predictions' in info:
                pred_df = info['predictions']
                if 'residual' in pred_df.columns:
                    ax.hist(pred_df['residual'].dropna(), bins=30,
                            color='#3498db', alpha=0.7, edgecolor='black')
                    plotted = True
                    break
    if not plotted:
        ax.text(0.5, 0.5, 'No predictions available', ha='center', va='center',
                transform=ax.transAxes, fontsize=14, color='gray')
    ax.set_title('(b) Forecast Residuals')
    ax.set_xlabel('Residual (°C-weeks)')
    ax.set_ylabel('Frequency')

    # Panel (c): pCRVI overlay
    ax = axes[1, 0]
    if pcrvi_data is not None and 'pcrvi' in pcrvi_data.columns:
        ax.plot(pcrvi_data.index, pcrvi_data['pcrvi'], color='#1a1a2e',
                linewidth=1.2, label='pCRVI')
        ax.axhline(0.55, color='#FF4500', linestyle='--', alpha=0.5)
        ax.axhline(0.70, color='#8B0000', linestyle='--', alpha=0.5)
        ax.set_ylabel('pCRVI Score')
        ax.set_ylim(0, 1)
        ax.set_title('(c) pCRVI Risk Index')
    else:
        ax.text(0.5, 0.5, 'No pCRVI data', ha='center', va='center',
                transform=ax.transAxes, fontsize=14, color='gray')

    # Panel (d): Feature importance
    ax = axes[1, 1]
    plotted = False
    if hasattr(forecaster, 'models') and forecaster.models:
        for key, info in forecaster.models.items():
            if 'feature_importance' in info:
                imp_df = info['feature_importance']
                if isinstance(imp_df, pd.DataFrame) and len(imp_df) > 0:
                    top = imp_df.nlargest(10, 'importance') if 'importance' in imp_df.columns else imp_df.head(10)
                    if 'feature' in top.columns and 'importance' in top.columns:
                        ax.barh(top['feature'].map(friendly_name), top['importance'],
                                color='#2ecc71', edgecolor='black')
                        plotted = True
                        break
    if not plotted:
        ax.text(0.5, 0.5, 'No feature importance data', ha='center', va='center',
                transform=ax.transAxes, fontsize=14, color='gray')
    ax.set_title('(d) Top Feature Importances')

    fig.suptitle('DHW Forecasting Dashboard', fontsize=18, fontweight='bold')
    fig.tight_layout()

    if output_path:
        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        fig.savefig(output_path, dpi=300, bbox_inches='tight')

    plt.close(fig)
    return output_path or Path()


def plot_forecast_feature_importance(
    importance_df: pd.DataFrame,
    model_name: str = "Ensemble-pCRVI",
    output_path: Optional[Path] = None,
    top_n: int = 15,
    figsize: tuple = (10, 7),
) -> Path:
    """
    Horizontal bar chart of feature importance.

    Parameters
    ----------
    importance_df : DataFrame
        Must have 'feature' and 'importance' columns.
    model_name : str
        Model name for title.
    """
    fig, ax = plt.subplots(figsize=figsize)

    # Accept dict → DataFrame conversion
    if isinstance(importance_df, dict):
        importance_df = pd.DataFrame([
            {'feature': k, 'importance': v} for k, v in importance_df.items()
        ])

    if importance_df is None or (hasattr(importance_df, 'empty') and importance_df.empty):
        ax.text(0.5, 0.5, 'No data', ha='center', va='center',
                transform=ax.transAxes, fontsize=14, color='gray')
    elif 'feature' in importance_df.columns and 'importance' in importance_df.columns:
        top = importance_df.nlargest(top_n, 'importance')
        colors = plt.cm.viridis(np.linspace(0.3, 0.9, len(top)))
        ax.barh(top['feature'].map(friendly_name), top['importance'], color=colors, edgecolor='black')
        ax.set_xlabel('Importance')
    else:
        ax.text(0.5, 0.5, 'Missing columns', ha='center', va='center',
                transform=ax.transAxes, fontsize=14, color='gray')

    ax.set_title(f'Feature Importance: {model_name}', fontsize=16, fontweight='bold')
    fig.tight_layout()

    if output_path:
        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        fig.savefig(output_path, dpi=300, bbox_inches='tight')

    plt.close(fig)
    return output_path or Path()
