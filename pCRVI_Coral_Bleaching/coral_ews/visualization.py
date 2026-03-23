"""
Visualization Module
====================

Creates and saves all visualizations for the Coral Bleaching EWS.
"""

from typing import Optional, List, Tuple, Dict, Any
from pathlib import Path
from datetime import datetime

import numpy as np
import pandas as pd
import requests
from io import BytesIO
import matplotlib.image as mpimg
# Try to import cartopy for maps
try:
    import cartopy.crs as ccrs
    import cartopy.feature as cfeature
    CARTOPY_AVAILABLE = True
except ImportError:
    CARTOPY_AVAILABLE = False
    
from .logger import get_logger
from .naming import (
    label, label_with_units, friendly_name,
    COMPONENT_LABELS, COMPONENT_COLORS,
)

# Try to import matplotlib
try:
    import matplotlib.pyplot as plt
    import matplotlib.dates as mdates
    from matplotlib.patches import Patch
    MATPLOTLIB_AVAILABLE = True
except ImportError:
    MATPLOTLIB_AVAILABLE = False

# Try to import seaborn
try:
    import seaborn as sns
    SEABORN_AVAILABLE = True
except ImportError:
    SEABORN_AVAILABLE = False


class Visualizer:
    """
    Creates visualizations for coral bleaching analysis.
    """
    
    def __init__(self, output_dir: Path, style: str = 'seaborn-v0_8-whitegrid'):
        """
        Initialize visualizer.
        
        Parameters
        ----------
        output_dir : Path
            Directory to save visualizations
        style : str
            Matplotlib style
        """
        if not MATPLOTLIB_AVAILABLE:
            raise ImportError("matplotlib not installed. Install with: pip install matplotlib")
        
        self.logger = get_logger("coral_ews.viz")
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        # Set style
        try:
            plt.style.use(style)
        except:
            plt.style.use('seaborn-whitegrid' if 'seaborn-whitegrid' in plt.style.available else 'default')
        
        # Color scheme for alerts (more nuanced)
        self.alert_colors = {
            0: '#2ecc71',  # Green - No stress
            1: '#3498db',  # Blue - Watch (thermal stress building)
            2: '#f1c40f',  # Yellow - Warning (partial/minor bleaching)
            3: '#e67e22',  # Orange - Alert 1 (moderate bleaching)
            4: '#e74c3c',  # Red - Alert 2 (significant bleaching)
            5: '#9b59b6',  # Purple - Alert 3 (mass bleaching/mortality)
            6: '#1a1a2e',  # Dark - Extreme
        }
        
        self.logger.info(f"Visualizer initialized. Output: {self.output_dir}")
    
    def plot_model_comparison(
        self,
        comparison_df: pd.DataFrame,
        figsize: Tuple[int, int] = (14, 8),
        prefix: str = ""
    ) -> Path:
        """
        Create comparison chart of ML model performance.
        """
        fig, axes = plt.subplots(1, 2, figsize=figsize)
        
        # Panel 1: Accuracy metrics
        ax1 = axes[0]
        metrics = ['accuracy', 'precision', 'recall', 'f1_score']
        x = np.arange(len(comparison_df))
        width = 0.2
        
        for i, metric in enumerate(metrics):
            if metric in comparison_df.columns:
                ax1.bar(x + i*width, comparison_df[metric], width, label=metric.replace('_', ' ').title())
        
        ax1.set_xlabel('Model')
        ax1.set_ylabel('Score')
        ax1.set_title('Classification Metrics by Model')
        ax1.set_xticks(x + width * 1.5)
        ax1.set_xticklabels(comparison_df['model'], rotation=45, ha='right')
        ax1.legend()
        ax1.set_ylim(0, 1)
        ax1.grid(True, alpha=0.3)
        
        # Panel 2: ROC-AUC and MCC
        ax2 = axes[1]
        if 'roc_auc' in comparison_df.columns:
            ax2.bar(x - 0.2, comparison_df['roc_auc'], 0.4, label='ROC-AUC', color='#3498db')
        if 'mcc' in comparison_df.columns:
            ax2.bar(x + 0.2, comparison_df['mcc'], 0.4, label='MCC', color='#e74c3c')
        
        ax2.set_xlabel('Model')
        ax2.set_ylabel('Score')
        ax2.set_title('Additional Metrics')
        ax2.set_xticks(x)
        ax2.set_xticklabels(comparison_df['model'], rotation=45, ha='right')
        ax2.legend()
        ax2.grid(True, alpha=0.3)
        
        plt.tight_layout()
        
        filename = f"{prefix}model_comparison.png" if prefix else "model_comparison.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved model comparison plot: {path}")
        return path

    def plot_dhw_timeseries(
        self,
        dhw_data: pd.DataFrame,
        title: str = "Degree Heating Weeks Time Series",
        figsize: Tuple[int, int] = (14, 8),
        show_thresholds: bool = True,
        historical_events: Optional[Dict[int, Dict]] = None,
        prefix: str = ""
    ) -> Path:
        """
        Plot DHW time series with alert thresholds.
        
        Parameters
        ----------
        dhw_data : pd.DataFrame
            DHW time series data
        title : str
            Plot title
        figsize : tuple
            Figure size
        show_thresholds : bool
            Whether to show threshold lines
        historical_events : dict, optional
            Known historical bleaching events {year: {'severity': ..., 'bleaching_pct': ...}}
        prefix : str
            Filename prefix
        """
        fig, ax = plt.subplots(figsize=figsize)
        
        # Plot DHW
        ax.plot(dhw_data.index, dhw_data['dhw'], 'b-', linewidth=1, label='DHW')
        ax.fill_between(dhw_data.index, 0, dhw_data['dhw'], alpha=0.3)
        
        # Add threshold lines
        if show_thresholds:
            ax.axhline(y=4, color='orange', linestyle='--', linewidth=1.5, label='Alert Level 1 (4°C-weeks)')
            ax.axhline(y=8, color='red', linestyle='--', linewidth=1.5, label='Alert Level 2 (8°C-weeks)')
            ax.axhline(y=12, color='darkred', linestyle='--', linewidth=1.5, label='Alert Level 3 (12°C-weeks)')
        
        # Mark historical bleaching events
        if historical_events:
            for year, event_info in historical_events.items():
                event_date = pd.Timestamp(f'{year}-05-15')
                if dhw_data.index.min() <= event_date <= dhw_data.index.max():
                    ax.axvline(x=event_date, color='red', linestyle='-', linewidth=2, alpha=0.5)
                    severity = event_info.get('severity', 'Unknown')
                    ax.annotate(f'{year}\n{severity}', xy=(event_date, ax.get_ylim()[1]*0.9),
                               fontsize=8, color='red', ha='center', va='top',
                               bbox=dict(boxstyle='round', facecolor='white', alpha=0.7))
        
        # Formatting
        ax.set_xlabel('Date', fontsize=12)
        ax.set_ylabel('DHW (°C-weeks)', fontsize=12)
        ax.set_title(title, fontsize=14, fontweight='bold')
        ax.legend(loc='upper right')
        ax.grid(True, alpha=0.3)
        
        # Format x-axis for long time series
        years = (dhw_data.index.max() - dhw_data.index.min()).days / 365
        if years > 5:
            ax.xaxis.set_major_locator(mdates.YearLocator())
            ax.xaxis.set_major_formatter(mdates.DateFormatter('%Y'))
        elif years > 2:
            ax.xaxis.set_major_locator(mdates.MonthLocator(interval=6))
            ax.xaxis.set_major_formatter(mdates.DateFormatter('%Y-%m'))
        
        plt.xticks(rotation=45)
        plt.tight_layout()
        
        # Save
        filename = f"{prefix}dhw_timeseries.png" if prefix else "dhw_timeseries.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved DHW time series plot: {path}")
        return path
    
    def plot_sst_and_dhw(
        self,
        sst_data: pd.DataFrame,
        dhw_data: pd.DataFrame,
        mmm: float = 29.87,
        figsize: Tuple[int, int] = (14, 10),
        prefix: str = ""
    ) -> Path:
        """
        Plot SST and DHW together with MMM threshold.
        """
        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=figsize, sharex=True)
        
        # SST plot
        sst_col = 'sst' if 'sst' in sst_data.columns else sst_data.columns[0]
        ax1.plot(sst_data.index, sst_data[sst_col], 'b-', linewidth=0.8, label='SST')
        ax1.axhline(y=mmm, color='red', linestyle='--', linewidth=1.5, label=f'MMM ({mmm}°C)')
        ax1.axhline(y=mmm + 1, color='orange', linestyle=':', linewidth=1, label=f'Bleaching Threshold ({mmm+1}°C)')
        ax1.set_ylabel('SST (°C)', fontsize=12)
        ax1.set_title('Sea Surface Temperature', fontsize=12, fontweight='bold')
        ax1.legend(loc='upper right')
        ax1.grid(True, alpha=0.3)
        
        # DHW plot
        ax2.fill_between(dhw_data.index, 0, dhw_data['dhw'], alpha=0.5, color='coral')
        ax2.plot(dhw_data.index, dhw_data['dhw'], 'r-', linewidth=1, label='DHW')
        ax2.axhline(y=4, color='orange', linestyle='--', linewidth=1, label='Alert 1')
        ax2.axhline(y=8, color='red', linestyle='--', linewidth=1, label='Alert 2')
        ax2.set_xlabel('Date', fontsize=12)
        ax2.set_ylabel('DHW (°C-weeks)', fontsize=12)
        ax2.set_title('Degree Heating Weeks', fontsize=12, fontweight='bold')
        ax2.legend(loc='upper right')
        ax2.grid(True, alpha=0.3)
        
        # Format x-axis
        years = (dhw_data.index.max() - dhw_data.index.min()).days / 365
        if years > 5:
            ax2.xaxis.set_major_locator(mdates.YearLocator())
            ax2.xaxis.set_major_formatter(mdates.DateFormatter('%Y'))
        
        plt.xticks(rotation=45)
        plt.tight_layout()
        
        filename = f"{prefix}sst_dhw_combined.png" if prefix else "sst_dhw_combined.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved SST/DHW combined plot: {path}")
        return path
    
    def plot_annual_max_dhw(
        self,
        dhw_data: pd.DataFrame,
        figsize: Tuple[int, int] = (12, 6),
        historical_events: Optional[Dict[int, Dict]] = None,
        prefix: str = ""
    ) -> Path:
        """
        Bar chart of annual maximum DHW values.
        
        Parameters
        ----------
        dhw_data : pd.DataFrame
            DHW time series data
        figsize : tuple
            Figure size
        historical_events : dict, optional
            Known historical bleaching events {year: {'severity': ..., 'bleaching_pct': ...}}
        prefix : str
            Filename prefix
        """
        # Calculate annual max
        dhw_copy = dhw_data.copy()
        dhw_copy['year'] = dhw_copy.index.year
        annual_max = dhw_copy.groupby('year')['dhw'].max()
        
        fig, ax = plt.subplots(figsize=figsize)
        
        # Color bars by alert level (more nuanced)
        colors = []
        for dhw in annual_max.values:
            if dhw >= 12:
                colors.append(self.alert_colors[5])  # Purple - mass bleaching
            elif dhw >= 8:
                colors.append(self.alert_colors[4])  # Red - significant
            elif dhw >= 6:
                colors.append(self.alert_colors[3])  # Orange - moderate
            elif dhw >= 4:
                colors.append(self.alert_colors[2])  # Yellow - partial/minor
            elif dhw > 0:
                colors.append(self.alert_colors[1])  # Blue - watch
            else:
                colors.append(self.alert_colors[0])  # Green - no stress
        
        bars = ax.bar(annual_max.index.astype(str), annual_max.values, color=colors, edgecolor='black', linewidth=0.5)
        
        # Add threshold lines
        ax.axhline(y=4, color='orange', linestyle='--', linewidth=1.5, label='Alert 1 (4)')
        ax.axhline(y=8, color='red', linestyle='--', linewidth=1.5, label='Alert 2 (8)')
        ax.axhline(y=12, color='darkred', linestyle='--', linewidth=1.5, label='Alert 3 (12)')
        
        # Add value labels on bars
        for bar, val in zip(bars, annual_max.values):
            if val > 0.5:
                ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.2, 
                       f'{val:.1f}', ha='center', va='bottom', fontsize=9)
        
        # Mark historical bleaching events with stars
        if historical_events:
            for year, event_info in historical_events.items():
                if year in annual_max.index:
                    idx = list(annual_max.index).index(year)
                    severity = event_info.get('severity', 'Unknown')
                    # Add a marker above the bar
                    ax.plot(idx, annual_max[year] + 0.8, 'r*', markersize=15, 
                           label='Documented event' if year == list(historical_events.keys())[0] else '')
        
        ax.set_xlabel('Year', fontsize=12)
        ax.set_ylabel('Maximum DHW (°C-weeks)', fontsize=12)
        ax.set_title('Annual Maximum Degree Heating Weeks', fontsize=14, fontweight='bold')
        ax.legend(loc='upper right')
        ax.grid(True, alpha=0.3, axis='y')
        
        plt.xticks(rotation=45)
        plt.tight_layout()
        
        filename = f"{prefix}annual_max_dhw.png" if prefix else "annual_max_dhw.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved annual max DHW plot: {path}")
        return path
    
    def plot_alert_distribution(
        self,
        dhw_data: pd.DataFrame,
        figsize: Tuple[int, int] = (10, 6),
        prefix: str = ""
    ) -> Path:
        """
        Pie chart of alert level distribution.
        """
        # Count days at each alert level
        alert_counts = dhw_data['alert_level'].value_counts().sort_index()
        
        # Labels and colors
        labels = ['No Stress', 'Watch', 'Alert 1', 'Alert 2', 'Alert 3', 'Alert 4+']
        colors = [self.alert_colors[i] for i in range(6)]
        
        # Only include levels that have data
        sizes = []
        plot_labels = []
        plot_colors = []
        
        for i in range(6):
            count = alert_counts.get(i, 0)
            if count > 0:
                sizes.append(count)
                plot_labels.append(f"{labels[i]} ({count} days)")
                plot_colors.append(colors[i])
        
        if not sizes:
            self.logger.warning("No alert data to plot")
            return None
        
        fig, ax = plt.subplots(figsize=figsize)
        
        wedges, texts, autotexts = ax.pie(
            sizes, labels=plot_labels, colors=plot_colors,
            autopct='%1.1f%%', startangle=90,
            textprops={'fontsize': 10}
        )
        
        ax.set_title('Distribution of Alert Levels', fontsize=14, fontweight='bold')
        
        plt.tight_layout()
        
        filename = f"{prefix}alert_distribution.png" if prefix else "alert_distribution.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved alert distribution plot: {path}")
        return path
    
    def plot_seasonal_pattern(
        self,
        dhw_data: pd.DataFrame,
        figsize: Tuple[int, int] = (12, 6),
        prefix: str = ""
    ) -> Path:
        """
        Plot seasonal DHW pattern (monthly averages across years).
        """
        dhw_copy = dhw_data.copy()
        dhw_copy['month'] = dhw_copy.index.month
        dhw_copy['year'] = dhw_copy.index.year
        
        # Monthly statistics
        monthly_mean = dhw_copy.groupby('month')['dhw'].mean()
        monthly_max = dhw_copy.groupby('month')['dhw'].max()
        monthly_std = dhw_copy.groupby('month')['dhw'].std()
        
        fig, ax = plt.subplots(figsize=figsize)
        
        months = range(1, 13)
        month_names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
        
        # Plot mean with std band
        ax.fill_between(months, 
                       monthly_mean - monthly_std, 
                       monthly_mean + monthly_std, 
                       alpha=0.3, color='blue', label='±1 Std Dev')
        ax.plot(months, monthly_mean, 'b-o', linewidth=2, markersize=8, label='Mean DHW')
        ax.plot(months, monthly_max, 'r--^', linewidth=1.5, markersize=6, label='Max DHW')
        
        # Threshold
        ax.axhline(y=4, color='orange', linestyle=':', linewidth=1.5, label='Alert 1 Threshold')
        
        ax.set_xticks(months)
        ax.set_xticklabels(month_names)
        ax.set_xlabel('Month', fontsize=12)
        ax.set_ylabel('DHW (°C-weeks)', fontsize=12)
        ax.set_title('Seasonal DHW Pattern', fontsize=14, fontweight='bold')
        ax.legend(loc='upper right')
        ax.grid(True, alpha=0.3)
        
        plt.tight_layout()
        
        filename = f"{prefix}seasonal_pattern.png" if prefix else "seasonal_pattern.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved seasonal pattern plot: {path}")
        return path
    
    def plot_feature_correlation(
        self,
        feature_matrix: pd.DataFrame,
        figsize: Tuple[int, int] = (12, 10),
        prefix: str = ""
    ) -> Path:
        """
        Heatmap of feature correlations.
        """
        if not SEABORN_AVAILABLE:
            self.logger.warning("Seaborn not available, skipping correlation plot")
            return None
        
        # Calculate correlation
        corr = feature_matrix.select_dtypes(include=[np.number]).corr()
        
        fig, ax = plt.subplots(figsize=figsize)
        
        # Create heatmap
        mask = np.triu(np.ones_like(corr, dtype=bool))
        sns.heatmap(corr, mask=mask, annot=True, fmt='.2f', cmap='RdBu_r',
                   center=0, square=True, linewidths=0.5, ax=ax,
                   annot_kws={'size': 8})
        
        ax.set_title('Feature Correlation Matrix', fontsize=14, fontweight='bold')
        
        plt.tight_layout()
        
        filename = f"{prefix}feature_correlation.png" if prefix else "feature_correlation.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved correlation plot: {path}")
        return path
    
    def plot_feature_importance(
        self,
        importance_df: pd.DataFrame,
        top_n: int = 15,
        figsize: Tuple[int, int] = (10, 8),
        prefix: str = ""
    ) -> Path:
        """
        Bar chart of feature importance.
        """
        # Get top N features
        top_features = importance_df.head(top_n)
        
        fig, ax = plt.subplots(figsize=figsize)
        
        bars = ax.barh(top_features['feature'], top_features['importance'], 
                      color='steelblue', edgecolor='black', linewidth=0.5)
        
        ax.set_xlabel('Importance', fontsize=12)
        ax.set_ylabel('Feature', fontsize=12)
        ax.set_title(f'Top {top_n} Feature Importance', fontsize=14, fontweight='bold')
        ax.invert_yaxis()
        ax.grid(True, alpha=0.3, axis='x')
        
        plt.tight_layout()
        
        filename = f"{prefix}feature_importance.png" if prefix else "feature_importance.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved feature importance plot: {path}")
        return path
    
    def plot_climate_indices_vs_dhw(
        self,
        dhw_data: pd.DataFrame,
        climate_data: pd.DataFrame,
        figsize: Tuple[int, int] = (14, 10),
        prefix: str = ""
    ) -> Path:
        """
        Plot climate indices (ONI, DMI) against DHW.
        """
        fig, axes = plt.subplots(3, 1, figsize=figsize, sharex=True)
        
        # DHW
        axes[0].fill_between(dhw_data.index, 0, dhw_data['dhw'], alpha=0.5, color='coral')
        axes[0].plot(dhw_data.index, dhw_data['dhw'], 'r-', linewidth=0.8)
        axes[0].axhline(y=4, color='orange', linestyle='--', linewidth=1)
        axes[0].set_ylabel('DHW (°C-weeks)')
        axes[0].set_title('Degree Heating Weeks', fontweight='bold')
        axes[0].grid(True, alpha=0.3)
        
        # ONI
        if 'oni' in climate_data.columns:
            oni = climate_data['oni'].reindex(dhw_data.index, method='ffill')
            colors = ['coral' if x > 0 else 'steelblue' for x in oni.fillna(0)]
            axes[1].bar(oni.index, oni.values, color=colors, width=20, alpha=0.7)
            axes[1].axhline(y=0.5, color='red', linestyle='--', linewidth=1, label='El Niño threshold')
            axes[1].axhline(y=-0.5, color='blue', linestyle='--', linewidth=1, label='La Niña threshold')
            axes[1].axhline(y=0, color='black', linestyle='-', linewidth=0.5)
            axes[1].set_ylabel(label_with_units('oni'))
            axes[1].set_title(label('oni', 'full'), fontweight='bold')
            axes[1].legend(loc='upper right', fontsize=8)
            axes[1].grid(True, alpha=0.3)
        
        # DMI
        if 'dmi' in climate_data.columns:
            dmi = climate_data['dmi'].reindex(dhw_data.index, method='ffill')
            colors = ['coral' if x > 0 else 'steelblue' for x in dmi.fillna(0)]
            axes[2].bar(dmi.index, dmi.values, color=colors, width=20, alpha=0.7)
            axes[2].axhline(y=0, color='black', linestyle='-', linewidth=0.5)
            axes[2].set_ylabel(label_with_units('dmi'))
            axes[2].set_title(label('dmi', 'full'), fontweight='bold')
            axes[2].grid(True, alpha=0.3)
        
        axes[2].set_xlabel('Date')
        
        # Format x-axis
        years = (dhw_data.index.max() - dhw_data.index.min()).days / 365
        if years > 5:
            axes[2].xaxis.set_major_locator(mdates.YearLocator())
            axes[2].xaxis.set_major_formatter(mdates.DateFormatter('%Y'))
        
        plt.xticks(rotation=45)
        plt.tight_layout()
        
        filename = f"{prefix}climate_vs_dhw.png" if prefix else "climate_vs_dhw.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved climate indices plot: {path}")
        return path
    
    def plot_annual_spatial_bleaching(
        self,
        dhw_data: pd.DataFrame,
        gee_client,
        region_bounds: Tuple[float, float, float, float],
        prefix: str = ""
    ) -> List[Path]:
        """
        Generate spatial maps of peak bleaching stress for each year.
        
        Fetches rendered thumbnails from GEE for the date of maximum DHW 
        in each year present in the data.
        
        Parameters
        ----------
        dhw_data : pd.DataFrame
            DHW time series
        gee_client : GEEClient
            Initialized GEE client instance
        region_bounds : tuple
            (lon_min, lat_min, lon_max, lat_max)
            
        Returns
        -------
        List[Path]
            List of saved map paths
        """
        import ee  # Import locally to avoid circular dependencies if strictly typed
        
        self.logger.info("Generating annual spatial bleaching maps...")
        
        # 1. Identify peak dates per year
        dhw_copy = dhw_data.copy()
        dhw_copy['year'] = dhw_copy.index.year
        
        # Find the index (date) of the maximum DHW for each year
        # Filter for years where max DHW > 0 to avoid plotting empty maps
        annual_peaks = dhw_copy.groupby('year')['dhw'].idxmax()
        
        saved_maps = []
        
        # 2. Define NOAA CRW Color Palette (Standard)
        # 0 (No Stress) -> 4 (Alert 1) -> 8 (Alert 2) -> 12+
        bleaching_palette = [
            '35a7d9',  # 0: Blue (No stress)
            '00ffff',  # 1: Cyan
            'f2ff00',  # 2-3: Yellow (Watch)
            'ffaa00',  # 4-7: Orange (Alert 1)
            'ff0000',  # 8-11: Red (Alert 2)
            '610000'   # 12+: Dark Red (Severe)
        ]
        
        vis_params = {
            'min': 0,
            'max': 12,
            'palette': bleaching_palette,
            'dimensions': 600,  # Width of the image
            'region': ee.Geometry.Rectangle([
                region_bounds[0], region_bounds[1], 
                region_bounds[2], region_bounds[3]
            ])
        }

        # 3. Generate map for each year
        for year, peak_date in annual_peaks.items():
            peak_dhw_val = dhw_copy.loc[peak_date, 'dhw']
            
            # Skip years with absolutely no stress if desired, 
            # but usually it's good to show "all clear" years too.
            if pd.isna(peak_date): 
                continue

            date_str = peak_date.strftime('%Y-%m-%d')
            self.logger.info(f"Fetching map for {year} peak: {date_str} (Max DHW: {peak_dhw_val:.2f})")
            
            try:
                # Get the OISST image for this date
                # Note: We need to reconstruct the DHW calculation for this specific day spatially
                # OR simpler: visualize the SST Anomaly if spatial DHW isn't pre-computed in GEE.
                # However, NOAA OISST doesn't have a native DHW band in GEE.
                # BETTER: Use the stored DHW if available, or visualize SST Anomaly 
                # as a proxy for the spatial distribution.
                
                # OPTION A: If using the NOAA 5km product (which has DHW), use that.
                # OPTION B (Fallback): Visualize SST Anomaly from OISST which is in the GEE config.
                
                # Using OISST Anomaly as spatial proxy for bleaching stress
                img_collection = ee.ImageCollection("NOAA/CDR/OISST/V2_1")
                image = img_collection.filterDate(date_str, 
                                                (peak_date + pd.Timedelta(days=1)).strftime('%Y-%m-%d')).first()
                
                # Select Anomaly
                band_to_viz = 'anom'
                # Re-adjust palette for Anomaly (0 to 4 degrees C)
                map_vis_params = vis_params.copy()
                map_vis_params['min'] = 0
                map_vis_params['max'] = 3.0
                map_vis_params['palette'] = ['ffffff', 'ffff00', 'ffaa00', 'ff0000', '500000']
                
                # Get Thumbnail URL
                thumb_url = image.select(band_to_viz).getThumbUrl(map_vis_params)
                
                # Download
                response = requests.get(thumb_url, timeout=15)
                if response.status_code == 200:
                    img_data = BytesIO(response.content)
                    
                    # Plot using Matplotlib to add annotations
                    fig, ax = plt.subplots(figsize=(8, 8))
                    
                    # Display image
                    img = mpimg.imread(img_data, format='png')
                    ax.imshow(img)
                    
                    # Remove axes ticks (pixels aren't lat/lon coordinates in this view)
                    ax.axis('off')
                    
                    # Add Titles
                    status = "No Stress"
                    color = "green"
                    if peak_dhw_val >= 8: status, color = "Alert Level 2", "red"
                    elif peak_dhw_val >= 4: status, color = "Alert Level 1", "orange"
                    elif peak_dhw_val > 0: status, color = "Watch", "gold"
                    
                    plt.title(f"Peak Thermal Stress: {year}\nDate: {date_str} | Region Max DHW: {peak_dhw_val:.1f}", 
                             fontsize=14, fontweight='bold')
                    
                    # Add status text
                    plt.figtext(0.5, 0.05, f"Overall Status: {status}", 
                               ha="center", fontsize=12, fontweight='bold', 
                               bbox={"facecolor": color, "alpha": 0.3, "pad": 5})
                    
                    # Save
                    filename = f"{prefix}spatial_map_{year}.png"
                    path = self.output_dir / filename
                    plt.savefig(path, dpi=150, bbox_inches='tight')
                    plt.close()
                    
                    saved_maps.append(path)
                
            except Exception as e:
                self.logger.warning(f"Failed to generate map for {year}: {e}")
                
        return saved_maps
    
    def plot_region_map(
        self,
        dhw_data: Optional[pd.DataFrame] = None,
        bounds: Tuple[float, float, float, float] = (90.0, 6.0, 95.0, 14.0),
        figsize: Tuple[int, int] = (12, 10),
        prefix: str = ""
    ) -> Path:
        """
        Plot the study region on a map.
        
        Parameters
        ----------
        dhw_data : pd.DataFrame, optional
            DHW data to determine overall bleaching status
        bounds : tuple
            Region bounds (lon_min, lat_min, lon_max, lat_max)
        figsize : tuple
            Figure size
        prefix : str
            Filename prefix
        
        Returns
        -------
        Path
            Path to saved figure
        """
        if not CARTOPY_AVAILABLE:
            self.logger.warning("Cartopy not installed. Install with: pip install cartopy")
            # Create simple plot without cartopy
            return self._plot_region_map_simple(dhw_data, bounds, figsize, prefix)
        
        fig, ax = plt.subplots(
            figsize=figsize,
            subplot_kw={'projection': ccrs.PlateCarree()}
        )
        
        # Set extent
        ax.set_extent([bounds[0]-1, bounds[2]+1, bounds[1]-1, bounds[3]+1], crs=ccrs.PlateCarree())
        
        # Add features
        ax.add_feature(cfeature.LAND, facecolor='lightgray')
        ax.add_feature(cfeature.OCEAN, facecolor='lightblue')
        ax.add_feature(cfeature.COASTLINE, linewidth=0.5)
        ax.add_feature(cfeature.BORDERS, linestyle=':', linewidth=0.5)
        ax.gridlines(draw_labels=True, alpha=0.3)
        
        # Draw study region
        from matplotlib.patches import Rectangle
        rect = Rectangle(
            (bounds[0], bounds[1]),
            bounds[2] - bounds[0],
            bounds[3] - bounds[1],
            linewidth=2,
            edgecolor='red',
            facecolor='none',
            transform=ccrs.PlateCarree()
        )
        ax.add_patch(rect)
        
        # Determine overall status from DHW data
        status_text = "No Data"
        color = 'gray'
        if dhw_data is not None and 'dhw' in dhw_data.columns:
            max_dhw = dhw_data['dhw'].max()
            if max_dhw >= 8:
                status_text = f"Severe Bleaching (Max DHW: {max_dhw:.1f})"
                color = 'darkred'
            elif max_dhw >= 4:
                status_text = f"Bleaching Likely (Max DHW: {max_dhw:.1f})"
                color = 'orange'
            else:
                status_text = f"No Significant Bleaching (Max DHW: {max_dhw:.1f})"
                color = 'green'
        
        # Add label
        ax.text(
            (bounds[0] + bounds[2]) / 2,
            bounds[3] + 0.5,
            "Andaman & Nicobar Islands\nStudy Region",
            transform=ccrs.PlateCarree(),
            fontsize=12,
            fontweight='bold',
            ha='center'
        )
        
        ax.set_title(f"Coral Bleaching Study Region\n{status_text}", fontsize=14, color=color)
        
        plt.tight_layout()
        
        filename = f"{prefix}region_map.png" if prefix else "region_map.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved region map: {path}")
        return path
    
    def _plot_region_map_simple(
        self,
        dhw_data: Optional[pd.DataFrame],
        bounds: Tuple[float, float, float, float],
        figsize: Tuple[int, int],
        prefix: str
    ) -> Path:
        """Simple region plot without cartopy."""
        fig, ax = plt.subplots(figsize=figsize)
        
        # Draw rectangle for region
        from matplotlib.patches import Rectangle
        rect = Rectangle(
            (bounds[0], bounds[1]),
            bounds[2] - bounds[0],
            bounds[3] - bounds[1],
            linewidth=2,
            edgecolor='red',
            facecolor='lightcoral',
            alpha=0.3
        )
        ax.add_patch(rect)
        
        # Set limits
        ax.set_xlim(bounds[0] - 2, bounds[2] + 2)
        ax.set_ylim(bounds[1] - 2, bounds[3] + 2)
        
        # Labels
        ax.set_xlabel('Longitude', fontsize=12)
        ax.set_ylabel('Latitude', fontsize=12)
        ax.set_title('Andaman & Nicobar Islands Study Region', fontsize=14, fontweight='bold')
        ax.grid(True, alpha=0.3)
        
        # Add center marker
        center_lon = (bounds[0] + bounds[2]) / 2
        center_lat = (bounds[1] + bounds[3]) / 2
        ax.plot(center_lon, center_lat, 'r*', markersize=15, label='Center')
        
        ax.legend()
        plt.tight_layout()
        
        filename = f"{prefix}region_map.png" if prefix else "region_map.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved simple region map: {path}")
        return path
    
    def plot_annual_bleaching_map(
        self,
        dhw_data: pd.DataFrame,
        bounds: Tuple[float, float, float, float] = (90.0, 6.0, 95.0, 14.0),
        figsize: Tuple[int, int] = (16, 12),
        prefix: str = ""
    ) -> Path:
        """
        Create a grid of maps showing bleaching status by year.
        
        Parameters
        ----------
        dhw_data : pd.DataFrame
            DHW time series data
        bounds : tuple
            Region bounds
        figsize : tuple
            Figure size
        prefix : str
            Filename prefix
        
        Returns
        -------
        Path
            Path to saved figure
        """
        # Calculate annual max DHW
        dhw_copy = dhw_data.copy()
        dhw_copy['year'] = dhw_copy.index.year
        annual_max = dhw_copy.groupby('year')['dhw'].max()
        
        years = sorted(annual_max.index.tolist())
        n_years = len(years)
        
        # Determine grid size
        n_cols = min(5, n_years)
        n_rows = (n_years + n_cols - 1) // n_cols
        
        fig, axes = plt.subplots(n_rows, n_cols, figsize=figsize)
        axes = np.array(axes).flatten() if n_years > 1 else [axes]
        
        for i, year in enumerate(years):
            ax = axes[i]
            max_dhw = annual_max[year]
            
            # Determine color based on DHW
            if max_dhw >= 12:
                color = '#9b59b6'  # Purple - severe
                status = 'Severe'
            elif max_dhw >= 8:
                color = '#e74c3c'  # Red - Alert 2
                status = 'Alert 2'
            elif max_dhw >= 4:
                color = '#e67e22'  # Orange - Alert 1
                status = 'Alert 1'
            elif max_dhw > 0:
                color = '#f1c40f'  # Yellow - Watch
                status = 'Watch'
            else:
                color = '#2ecc71'  # Green - No stress
                status = 'No Stress'
            
            # Draw region
            from matplotlib.patches import Rectangle
            rect = Rectangle(
                (bounds[0], bounds[1]),
                bounds[2] - bounds[0],
                bounds[3] - bounds[1],
                linewidth=2,
                edgecolor='black',
                facecolor=color,
                alpha=0.7
            )
            ax.add_patch(rect)
            
            ax.set_xlim(bounds[0] - 1, bounds[2] + 1)
            ax.set_ylim(bounds[1] - 1, bounds[3] + 1)
            ax.set_title(f"{year}\nMax DHW: {max_dhw:.1f}\n{status}", fontsize=10)
            ax.set_xticks([])
            ax.set_yticks([])
        
        # Hide unused axes
        for i in range(n_years, len(axes)):
            axes[i].set_visible(False)
        
        # Add legend
        from matplotlib.patches import Patch
        legend_elements = [
            Patch(facecolor='#2ecc71', edgecolor='black', label='No Stress (DHW < 0)'),
            Patch(facecolor='#f1c40f', edgecolor='black', label='Watch (0 < DHW < 4)'),
            Patch(facecolor='#e67e22', edgecolor='black', label='Alert 1 (4 ≤ DHW < 8)'),
            Patch(facecolor='#e74c3c', edgecolor='black', label='Alert 2 (8 ≤ DHW < 12)'),
            Patch(facecolor='#9b59b6', edgecolor='black', label='Severe (DHW ≥ 12)')
        ]
        fig.legend(handles=legend_elements, loc='lower center', ncol=5, fontsize=10)
        
        fig.suptitle(
            'Annual Maximum DHW - Andaman & Nicobar Islands',
            fontsize=16,
            fontweight='bold',
            y=1.02
        )
        
        plt.tight_layout()
        plt.subplots_adjust(bottom=0.1)
        
        filename = f"{prefix}annual_bleaching_map.png" if prefix else "annual_bleaching_map.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved annual bleaching map: {path}")
        return path
    
    def plot_bleaching_heatmap(
        self,
        dhw_data: pd.DataFrame,
        figsize: Tuple[int, int] = (16, 8),
        prefix: str = ""
    ) -> Path:
        """
        Create a heatmap showing DHW by month and year.
        
        Parameters
        ----------
        dhw_data : pd.DataFrame
            DHW time series data
        figsize : tuple
            Figure size
        prefix : str
            Filename prefix
        
        Returns
        -------
        Path
            Path to saved figure
        """
        # Create month-year pivot
        dhw_copy = dhw_data.copy()
        dhw_copy['year'] = dhw_copy.index.year
        dhw_copy['month'] = dhw_copy.index.month
        
        # Get monthly max DHW
        monthly_max = dhw_copy.groupby(['year', 'month'])['dhw'].max().unstack()
        
        fig, ax = plt.subplots(figsize=figsize)
        
        # Create heatmap
        if SEABORN_AVAILABLE:
            sns.heatmap(
                monthly_max,
                cmap='YlOrRd',
                annot=True,
                fmt='.1f',
                linewidths=0.5,
                ax=ax,
                cbar_kws={'label': 'Max DHW (°C-weeks)'},
                vmin=0,
                vmax=max(12, monthly_max.max().max())
            )
        else:
            im = ax.imshow(monthly_max.values, cmap='YlOrRd', aspect='auto', vmin=0)
            plt.colorbar(im, ax=ax, label='Max DHW (°C-weeks)')
            ax.set_xticks(range(12))
            ax.set_xticklabels(['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                               'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'])
            ax.set_yticks(range(len(monthly_max.index)))
            ax.set_yticklabels(monthly_max.index)
        
        ax.set_xlabel('Month', fontsize=12)
        ax.set_ylabel('Year', fontsize=12)
        ax.set_title('Monthly Maximum DHW Heatmap - Andaman & Nicobar Islands',
                    fontsize=14, fontweight='bold')
        
        # Add threshold lines annotation
        ax.text(
            1.02, 0.5,
            'Thresholds:\nAlert 1: 4°C-weeks\nAlert 2: 8°C-weeks',
            transform=ax.transAxes,
            fontsize=10,
            verticalalignment='center'
        )
        
        plt.tight_layout()
        
        filename = f"{prefix}bleaching_heatmap.png" if prefix else "bleaching_heatmap.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved bleaching heatmap: {path}")
        return path
    
    # Add these methods to the Visualizer class in visualization.py
    
    def plot_validation_comparison(
        self,
        validation_df: pd.DataFrame,
        figsize: Tuple[int, int] = (14, 8),
        prefix: str = ""
    ) -> Path:
        """
        Plot comparison of model predictions vs historical observations.
        
        Parameters
        ----------
        validation_df : pd.DataFrame
            Validation results from DHWCalculator
        figsize : tuple
            Figure size
        prefix : str
            Filename prefix
        
        Returns
        -------
        Path
            Path to saved figure
        """
        fig, axes = plt.subplots(1, 2, figsize=figsize)
        
        years = validation_df['year'].values
        model_dhw = validation_df['model_dhw'].values
        reported_dhw = validation_df['reported_dhw'].fillna(0).values
        
        # Left plot: Bar comparison
        ax1 = axes[0]
        x = np.arange(len(years))
        width = 0.35
        
        bars1 = ax1.bar(x - width/2, model_dhw, width, label='Model DHW', color='steelblue')
        bars2 = ax1.bar(x + width/2, reported_dhw, width, label='Reported DHW', color='coral')
        
        ax1.set_xlabel('Year', fontsize=12)
        ax1.set_ylabel('DHW (°C-weeks)', fontsize=12)
        ax1.set_title('Model vs Reported DHW by Event Year', fontsize=12, fontweight='bold')
        ax1.set_xticks(x)
        ax1.set_xticklabels(years)
        ax1.legend()
        ax1.axhline(y=4, color='orange', linestyle='--', alpha=0.7, label='Warning threshold')
        ax1.axhline(y=8, color='red', linestyle='--', alpha=0.7, label='Alert L2 threshold')
        
        # Add match quality colors
        match_colors = {
            'GOOD': 'green',
            'UNDERESTIMATED': 'orange',
            'OVERESTIMATED': 'purple',
            'MISSED': 'red',
            'SLIGHT OVERESTIMATE': 'yellow'
        }
        
        for i, (_, row) in enumerate(validation_df.iterrows()):
            match = row['match_quality']
            color = match_colors.get(match, 'gray')
            ax1.scatter(i, max(model_dhw[i], reported_dhw[i]) + 0.5, 
                    marker='o', s=100, c=color, edgecolors='black', zorder=5)
        
        # Right plot: Severity comparison
        ax2 = axes[1]
        
        severity_order = ['minor', 'moderate', 'severe', 'catastrophic']
        severity_numeric = validation_df['observed_severity'].map(
            {s: i for i, s in enumerate(severity_order)}
        ).fillna(-1).values
        
        # Model alert levels
        model_levels = validation_df['model_alert_level'].values
        
        ax2.scatter(severity_numeric, model_levels, s=200, c=model_dhw, 
                cmap='YlOrRd', edgecolors='black', linewidths=2)
        
        # Add year labels
        for i, year in enumerate(years):
            ax2.annotate(str(year), (severity_numeric[i], model_levels[i]),
                        textcoords="offset points", xytext=(5, 5), fontsize=10)
        
        ax2.set_xlabel('Observed Severity', fontsize=12)
        ax2.set_ylabel('Model Alert Level', fontsize=12)
        ax2.set_title('Model Alert Level vs Observed Severity', fontsize=12, fontweight='bold')
        ax2.set_xticks(range(len(severity_order)))
        ax2.set_xticklabels(['Minor', 'Moderate', 'Severe', 'Catastrophic'])
        ax2.set_yticks([0, 1, 2, 3, 4])
        ax2.set_yticklabels(['No Stress', 'Watch', 'Warning', 'Alert L1', 'Alert L2'])
        
        # Perfect match line
        ax2.plot([-0.5, 3.5], [-0.5, 3.5], 'g--', alpha=0.5, label='Perfect match')
        ax2.set_xlim(-0.5, 3.5)
        ax2.set_ylim(-0.5, 4.5)
        
        plt.colorbar(ax2.collections[0], ax=ax2, label='Model DHW')
        
        plt.tight_layout()
        
        filename = f"{prefix}validation_comparison.png" if prefix else "validation_comparison.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved validation comparison plot: {path}")
        return path
    
    def plot_noaa_style_bleaching_alert(
        self,
        dhw_data: pd.DataFrame,
        bounds: Tuple[float, float, float, float] = (90.0, 6.0, 95.0, 14.0),
        date: Optional[datetime] = None,
        figsize: Tuple[int, int] = (12, 10),
        prefix: str = ""
    ) -> Path:
        """
        Create NOAA Coral Reef Watch style bleaching alert map.
        
        Uses official NOAA color scheme:
        - No Stress (white): DHW = 0
        - Watch (yellow): 0 < DHW < 4
        - Warning (orange): 4 <= DHW < 8
        - Alert Level 1 (red): 8 <= DHW < 12
        - Alert Level 2 (dark red): DHW >= 12
        
        Parameters
        ----------
        dhw_data : pd.DataFrame
            DHW time series
        bounds : tuple
            Region bounds
        date : datetime, optional
            Date for alert (default: most recent)
        figsize : tuple
            Figure size
        prefix : str
            Filename prefix
        
        Returns
        -------
        Path
            Path to saved figure
        """
        from matplotlib.colors import LinearSegmentedColormap, BoundaryNorm
        from matplotlib.patches import Rectangle
        
        # NOAA official colors
        noaa_colors = [
            '#FFFFFF',  # No Stress (white)
            '#FFFF00',  # Watch (yellow)
            '#FFA500',  # Warning (orange) 
            '#FF0000',  # Alert Level 1 (red)
            '#8B0000',  # Alert Level 2 (dark red)
        ]
        noaa_bounds = [0, 0.001, 4, 8, 12, 25]
        
        # Get current DHW
        if date is None:
            date = dhw_data.index.max()
        
        current_dhw = dhw_data.loc[date, 'dhw'] if date in dhw_data.index else dhw_data['dhw'].iloc[-1]
        
        # Determine alert level
        if current_dhw >= 12:
            alert_level = "Alert Level 2"
            color_idx = 4
        elif current_dhw >= 8:
            alert_level = "Alert Level 1"
            color_idx = 3
        elif current_dhw >= 4:
            alert_level = "Warning"
            color_idx = 2
        elif current_dhw > 0:
            alert_level = "Watch"
            color_idx = 1
        else:
            alert_level = "No Stress"
            color_idx = 0
        
        fig, ax = plt.subplots(figsize=figsize)
        
        # Draw map background
        ax.set_facecolor('#ADD8E6')  # Light blue ocean
        
        # Draw region with alert color
        rect = Rectangle(
            (bounds[0], bounds[1]),
            bounds[2] - bounds[0],
            bounds[3] - bounds[1],
            linewidth=2,
            edgecolor='black',
            facecolor=noaa_colors[color_idx],
            alpha=0.9
        )
        ax.add_patch(rect)
        
        # Set limits
        ax.set_xlim(bounds[0] - 3, bounds[2] + 3)
        ax.set_ylim(bounds[1] - 3, bounds[3] + 3)
        
        # Add labels
        ax.text(
            (bounds[0] + bounds[2]) / 2,
            (bounds[1] + bounds[3]) / 2,
            f"DHW: {current_dhw:.1f}\n{alert_level}",
            ha='center', va='center',
            fontsize=14, fontweight='bold',
            bbox=dict(boxstyle='round', facecolor='white', alpha=0.8)
        )
        
        # Add color bar legend
        import matplotlib.patches as mpatches
        legend_elements = [
            mpatches.Patch(facecolor='#FFFFFF', edgecolor='black', label='No Stress (0)'),
            mpatches.Patch(facecolor='#FFFF00', edgecolor='black', label='Watch (0-4)'),
            mpatches.Patch(facecolor='#FFA500', edgecolor='black', label='Warning (4-8)'),
            mpatches.Patch(facecolor='#FF0000', edgecolor='black', label='Alert Level 1 (8-12)'),
            mpatches.Patch(facecolor='#8B0000', edgecolor='black', label='Alert Level 2 (>12)'),
        ]
        ax.legend(
            handles=legend_elements,
            loc='lower right',
            title='DHW Alert Levels',
            fontsize=10
        )
        
        ax.set_xlabel('Longitude (°E)', fontsize=12)
        ax.set_ylabel('Latitude (°N)', fontsize=12)
        ax.set_title(
            f'NOAA Coral Reef Watch Style Bleaching Alert\n'
            f'Andaman & Nicobar Islands - {date.strftime("%Y-%m-%d") if hasattr(date, "strftime") else date}',
            fontsize=14, fontweight='bold'
        )
        ax.grid(True, alpha=0.3, linestyle='--')
        
        plt.tight_layout()
        
        filename = f"{prefix}noaa_bleaching_alert.png" if prefix else "noaa_bleaching_alert.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved NOAA-style alert map: {path}")
        return path
    
    def plot_crvi_components(
        self,
        crvi_results: Dict[str, Any],
        figsize: Tuple[int, int] = (14, 10),
        prefix: str = ""
    ) -> Path:
        """
        Create visualization of CRVI components.
        
        Parameters
        ----------
        crvi_results : dict
            Results from CRVICalculator.calculate_crvi()
        figsize : tuple
            Figure size
        prefix : str
            Filename prefix
        
        Returns
        -------
        Path
            Path to saved figure
        """
        fig, axes = plt.subplots(2, 2, figsize=figsize)
        
        components = crvi_results['components']
        region = crvi_results['region']
        crvi = crvi_results['crvi']
        
        # 1. Component bar chart
        ax1 = axes[0, 0]
        component_names = ['Thermal\nStress', 'Recovery\nVulnerability', 'Recurrence\nIndex']
        component_values = [
            components['thermal_stress']['value'],
            components['recovery_vulnerability']['value'],
            components['recurrence_index']['value']
        ]
        colors = ['#e74c3c', '#3498db', '#2ecc71']
        
        bars = ax1.bar(component_names, component_values, color=colors, edgecolor='black')
        ax1.set_ylabel('Normalized Value (0-1)', fontsize=12)
        ax1.set_title('CRVI Components', fontsize=12, fontweight='bold')
        ax1.set_ylim(0, 1.1)
        ax1.axhline(y=0.5, color='gray', linestyle='--', alpha=0.5)
        
        # Add value labels
        for bar, val in zip(bars, component_values):
            ax1.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.02,
                    f'{val:.2f}', ha='center', va='bottom', fontsize=11)
        
        # 2. Weighted contribution pie chart
        ax2 = axes[0, 1]
        contributions = [
            components['thermal_stress']['weighted_contribution'],
            components['recovery_vulnerability']['weighted_contribution'],
            components['recurrence_index']['weighted_contribution']
        ]
        labels = [f'TS: {contributions[0]:.2f}', f'RV: {contributions[1]:.2f}', f'RI: {contributions[2]:.2f}']
        
        wedges, texts, autotexts = ax2.pie(
            contributions, labels=labels, colors=colors,
            autopct='%1.1f%%', startangle=90
        )
        ax2.set_title('Weighted Contributions to CRVI', fontsize=12, fontweight='bold')
        
        # 3. CRVI gauge
        ax3 = axes[1, 0]
        
        # Create gauge-like visualization
        theta = np.linspace(0, np.pi, 100)
        r = 1
        
        # Background arc
        for i, (start, end, color) in enumerate([
            (0, 0.2, '#2ecc71'),
            (0.2, 0.4, '#f1c40f'),
            (0.4, 0.6, '#e67e22'),
            (0.6, 0.8, '#e74c3c'),
            (0.8, 1.0, '#9b59b6')
        ]):
            theta_segment = np.linspace(np.pi * (1 - end), np.pi * (1 - start), 20)
            ax3.fill_between(
                theta_segment, 0.7, 1.0,
                color=color, alpha=0.7,
                transform=plt.matplotlib.transforms.Affine2D().scale(1, 1) + ax3.transData
            )
            x = np.cos(theta_segment) * 0.85
            y = np.sin(theta_segment) * 0.85
            ax3.fill(
                np.append(np.cos(theta_segment), 0),
                np.append(np.sin(theta_segment), 0),
                color=color, alpha=0.3
            )
        
        # Needle
        needle_angle = np.pi * (1 - crvi)
        ax3.arrow(0, 0, 0.7 * np.cos(needle_angle), 0.7 * np.sin(needle_angle),
                 head_width=0.05, head_length=0.05, fc='black', ec='black')
        
        ax3.set_xlim(-1.2, 1.2)
        ax3.set_ylim(-0.2, 1.2)
        ax3.set_aspect('equal')
        ax3.axis('off')
        ax3.set_title(f'CRVI = {crvi:.3f}\n{crvi_results["risk_category"]}',
                     fontsize=14, fontweight='bold', color=crvi_results['risk_color'])
        
        # Add labels
        ax3.text(-1.0, -0.1, 'Minimal', ha='center', fontsize=10)
        ax3.text(1.0, -0.1, 'Critical', ha='center', fontsize=10)
        
        # 4. Risk interpretation
        ax4 = axes[1, 1]
        ax4.axis('off')
        
        interpretation_text = f"""
CRVI Assessment for {region}

Overall Score: {crvi:.3f}
Risk Category: {crvi_results['risk_category']}

Component Breakdown:
- Thermal Stress (TS): {components['thermal_stress']['value']:.3f}
  Weight: {components['thermal_stress']['weight']*100:.0f}%
  
- Recovery Vulnerability (RV): {components['recovery_vulnerability']['value']:.3f}
  Weight: {components['recovery_vulnerability']['weight']*100:.0f}%
  
- Recurrence Index (RI): {components['recurrence_index']['value']:.3f}
  Weight: {components['recurrence_index']['weight']*100:.0f}%

Data Period: {crvi_results['data_period']['start']} to {crvi_results['data_period']['end']}
"""
        ax4.text(0.1, 0.9, interpretation_text, transform=ax4.transAxes,
                fontsize=11, verticalalignment='top', fontfamily='monospace',
                bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))
        
        fig.suptitle(f'Coral Reef Vulnerability Index (CRVI) Analysis\n{region}',
                    fontsize=16, fontweight='bold', y=1.02)
        
        plt.tight_layout()
        
        filename = f"{prefix}crvi_analysis.png" if prefix else "crvi_analysis.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved CRVI analysis plot: {path}")
        return path
    
    def plot_model_comparison(
        self,
        comparison_df: pd.DataFrame,
        task: str = 'classification',
        figsize: Tuple[int, int] = (12, 6),
        prefix: str = ""
    ) -> Path:
        """
        Plot model comparison results.
        
        Parameters
        ----------
        comparison_df : pd.DataFrame
            Results from compare_models()
        task : str
            'classification' or 'regression'
        figsize : tuple
            Figure size
        prefix : str
            Filename prefix
        
        Returns
        -------
        Path
            Path to saved figure
        """
        fig, axes = plt.subplots(1, 2, figsize=figsize)
        
        models = comparison_df['model'].tolist()
        colors = plt.cm.Set2(np.linspace(0, 1, len(models)))
        
        if task == 'classification':
            # Accuracy
            ax1 = axes[0]
            bars1 = ax1.barh(models, comparison_df['accuracy'], color=colors, edgecolor='black')
            ax1.set_xlabel('Accuracy', fontsize=12)
            ax1.set_title('Model Accuracy Comparison', fontsize=12, fontweight='bold')
            ax1.set_xlim(0.9, 1.0)
            for bar, val in zip(bars1, comparison_df['accuracy']):
                ax1.text(val + 0.002, bar.get_y() + bar.get_height()/2,
                        f'{val:.4f}', va='center', fontsize=10)
            
            # ROC-AUC
            ax2 = axes[1]
            bars2 = ax2.barh(models, comparison_df['roc_auc'], color=colors, edgecolor='black')
            ax2.set_xlabel('ROC-AUC', fontsize=12)
            ax2.set_title('Model ROC-AUC Comparison', fontsize=12, fontweight='bold')
            ax2.set_xlim(0.9, 1.0)
            for bar, val in zip(bars2, comparison_df['roc_auc']):
                ax2.text(val + 0.002, bar.get_y() + bar.get_height()/2,
                        f'{val:.4f}', va='center', fontsize=10)
        else:
            # R²
            ax1 = axes[0]
            bars1 = ax1.barh(models, comparison_df['r2'], color=colors, edgecolor='black')
            ax1.set_xlabel('R² Score', fontsize=12)
            ax1.set_title('Model R² Comparison', fontsize=12, fontweight='bold')
            for bar, val in zip(bars1, comparison_df['r2']):
                ax1.text(val + 0.01, bar.get_y() + bar.get_height()/2,
                        f'{val:.4f}', va='center', fontsize=10)
            
            # RMSE
            ax2 = axes[1]
            bars2 = ax2.barh(models, comparison_df['rmse'], color=colors, edgecolor='black')
            ax2.set_xlabel('RMSE', fontsize=12)
            ax2.set_title('Model RMSE Comparison (lower is better)', fontsize=12, fontweight='bold')
            for bar, val in zip(bars2, comparison_df['rmse']):
                ax2.text(val + 0.1, bar.get_y() + bar.get_height()/2,
                        f'{val:.2f}', va='center', fontsize=10)
        
        plt.tight_layout()
        
        filename = f"{prefix}model_comparison.png" if prefix else "model_comparison.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved model comparison plot: {path}")
        return path
    
    def plot_dhw_severity_relationship(
        self,
        dhw_data: pd.DataFrame,
        figsize: Tuple[int, int] = (14, 6),
        prefix: str = "",
        known_events: Optional[Dict] = None
    ) -> Path:
        """
        Create DHW-Severity relationship plot similar to paper Figure 2.
        
        Parameters
        ----------
        dhw_data : pd.DataFrame
            DHW time series
        figsize : tuple
            Figure size
        prefix : str
            Filename prefix
        
        Returns
        -------
        Path
            Path to saved figure
        """
        fig, axes = plt.subplots(1, 2, figsize=figsize)
        
        # === Panel A: Actual DHW vs observed bleaching from validation ===
        ax1 = axes[0]
        
        # Use real validation events if available from known_events
        known = known_events or getattr(self, 'known_events', None)
        has_real_data = False
        
        if known and len(known) >= 3:
            years = sorted(known.keys())
            real_dhw = []
            real_pct = []
            labels = []
            for y in years:
                ev = known[y]
                d = ev.get('dhw_reported', ev.get('dhw', None))
                p = ev.get('bleaching_pct', 0)
                if d is not None:
                    real_dhw.append(float(d))
                    real_pct.append(float(p))
                    labels.append(str(y))
            
            if len(real_dhw) >= 3:
                has_real_data = True
                colors_ev = ['#e74c3c' if p > 50 else '#f39c12' if p > 20 else '#3498db'
                             for p in real_pct]
                ax1.scatter(real_dhw, real_pct, c=colors_ev, s=200, zorder=5,
                           edgecolors='black', linewidths=1.5)
                for x, y_val, lbl in zip(real_dhw, real_pct, labels):
                    ax1.annotate(lbl, (x, y_val), textcoords="offset points",
                                xytext=(8, 8), fontsize=10, fontweight='bold')
                
                # Logistic fit to actual data
                from scipy.optimize import curve_fit
                try:
                    def logistic(x, k, x0):
                        return 100 / (1 + np.exp(-k * (x - x0)))
                    popt, _ = curve_fit(logistic, real_dhw, real_pct, p0=[0.5, 6], maxfev=5000)
                    dhw_range = np.linspace(0, max(real_dhw) * 1.2, 100)
                    ax1.plot(dhw_range, logistic(dhw_range, *popt), 'b-', lw=2,
                            label=f'Logistic fit (k={popt[0]:.2f})', alpha=0.7)
                except Exception:
                    dhw_range = np.linspace(0, max(real_dhw) * 1.2, 100)
                    ax1.plot(dhw_range, 100 / (1 + np.exp(-0.5 * (dhw_range - 8))),
                            'b--', lw=1.5, label='Reference logistic', alpha=0.5)
                
                # Compute actual correlation
                corr_val = np.corrcoef(real_dhw, real_pct)[0, 1]
                ax1.text(0.05, 0.95, f'r = {corr_val:.2f}\nn = {len(real_dhw)} events',
                        transform=ax1.transAxes, fontsize=11, va='top',
                        bbox=dict(boxstyle='round', facecolor='white', alpha=0.9))
        
        if not has_real_data:
            # Fallback: improved hexbin with log scale
            dhw_positive = dhw_data[dhw_data['dhw'] > 0]['dhw'].dropna()
            severity = 100 / (1 + np.exp(-0.5 * (dhw_positive - 8)))
            ax1.hexbin(dhw_positive, severity, gridsize=25, cmap='YlOrRd',
                      mincnt=1, norm=plt.matplotlib.colors.LogNorm())
            dhw_range = np.linspace(0, 20, 100)
            ax1.plot(dhw_range, 100 / (1 + np.exp(-0.5 * (dhw_range - 8))),
                    'b-', lw=2, label='Logistic model')
            plt.colorbar(ax1.collections[0], ax=ax1, label='Count (log)')
        
        ax1.axvline(x=4, color='orange', linestyle='--', alpha=0.7, label='Watch (4)')
        ax1.axvline(x=8, color='red', linestyle='--', alpha=0.7, label='Alert (8)')
        ax1.set_xlabel('Degree Heating Weeks (°C-weeks)', fontsize=12)
        ax1.set_ylabel('Observed Bleaching (%)', fontsize=12)
        ax1.set_title('A) DHW–Bleaching Relationship', fontsize=12, fontweight='bold')
        ax1.legend(loc='lower right', fontsize=9)
        ax1.set_ylim(-5, 105)
        ax1.grid(True, alpha=0.3)
        
        # === Panel B: Box plot by DHW category ===
        ax2 = axes[1]
        
        dhw_data_copy = dhw_data.copy()
        # Use actual severity where available, synthetic elsewhere
        dhw_data_copy['severity'] = 100 / (1 + np.exp(-0.5 * (dhw_data_copy['dhw'] - 8)))
        
        def categorize_dhw(dhw):
            if pd.isna(dhw) or dhw <= 0:
                return '0\n(No Stress)'
            elif dhw < 4:
                return '0-4\n(Watch)'
            elif dhw < 6:
                return '4-6\n(Warning)'
            elif dhw < 8:
                return '6-8\n(Alert 1)'
            elif dhw < 12:
                return '8-12\n(Alert 2)'
            else:
                return '>12\n(Severe)'
        
        dhw_data_copy['category'] = dhw_data_copy['dhw'].apply(categorize_dhw)
        
        categories = ['0\n(No Stress)', '0-4\n(Watch)', '4-6\n(Warning)', 
                      '6-8\n(Alert 1)', '8-12\n(Alert 2)', '>12\n(Severe)']
        category_data = [dhw_data_copy[dhw_data_copy['category'] == cat]['severity'].dropna() 
                        for cat in categories]
        
        present = [(cat, d) for cat, d in zip(categories, category_data) if len(d) > 0]
        if present:
            bp = ax2.boxplot([d.values for _, d in present],
                            labels=[cat for cat, _ in present],
                            patch_artist=True, widths=0.6)
            
            colors = ['#2ecc71', '#3498db', '#f1c40f', '#e67e22', '#e74c3c', '#9b59b6']
            for patch, color in zip(bp['boxes'], colors[:len(bp['boxes'])]):
                patch.set_facecolor(color)
                patch.set_alpha(0.8)
            
            # Sample sizes
            for i, (cat, data) in enumerate(present):
                ax2.text(i + 1, 102, f'n={len(data):,}', ha='center', fontsize=9, fontweight='bold')
        
        ax2.set_ylabel('Estimated Bleaching Severity (%)', fontsize=12)
        ax2.set_xlabel('DHW Category', fontsize=12)
        ax2.set_title('B) Severity by DHW Category', fontsize=12, fontweight='bold')
        ax2.set_ylim(-2, 110)
        ax2.grid(True, alpha=0.3, axis='y')
        
        plt.tight_layout()
        
        filename = f"{prefix}dhw_severity_relationship.png" if prefix else "dhw_severity_relationship.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved DHW-severity relationship plot: {path}")
        return path
    
    def plot_historical_validation(
        self,
        validation_df: pd.DataFrame,
        dhw_data: Optional[pd.DataFrame] = None,
        pcrvi_data: Optional[pd.DataFrame] = None,
        prefix: str = ""
    ) -> Path:
        """
        Plot historical validation comparing model predictions to documented events.
        
        Parameters
        ----------
        validation_df : pd.DataFrame
            Output from pipeline.validate_against_historical_events()
        dhw_data : pd.DataFrame, optional
            DHW time series for overlay
        pcrvi_data : pd.DataFrame, optional
            pCRVI time series for overlay
        prefix : str
            Output filename prefix
        
        Returns
        -------
        Path
            Path to saved figure
        """
        fig = plt.figure(figsize=(16, 14))
        
        # Create grid layout
        gs = fig.add_gridspec(3, 2, height_ratios=[1.2, 1, 1], hspace=0.3, wspace=0.25)
        
        # =========================================================================
        # Panel A: Comparison Bar Chart - Actual vs Model DHW
        # =========================================================================
        ax1 = fig.add_subplot(gs[0, 0])
        
        years = validation_df['year'].values
        actual_dhw = validation_df['actual_dhw'].fillna(0).values
        model_dhw = validation_df['model_dhw_max'].fillna(0).values
        
        x = np.arange(len(years))
        width = 0.35
        
        bars1 = ax1.bar(x - width/2, actual_dhw, width, label='Documented DHW', 
                       color='#e74c3c', alpha=0.8, edgecolor='black')
        bars2 = ax1.bar(x + width/2, model_dhw, width, label='Model DHW', 
                       color='#3498db', alpha=0.8, edgecolor='black')
        
        # Add correlation line
        valid_pairs = [(a, m) for a, m in zip(actual_dhw, model_dhw) if a > 0 and m > 0]
        if len(valid_pairs) > 2:
            corr = np.corrcoef([p[0] for p in valid_pairs], [p[1] for p in valid_pairs])[0, 1]
            ax1.text(0.98, 0.98, f'r = {corr:.3f}', transform=ax1.transAxes,
                    fontsize=12, ha='right', va='top', 
                    bbox=dict(boxstyle='round', facecolor='white', alpha=0.8))
        
        # Threshold lines
        ax1.axhline(y=4, color='orange', linestyle='--', alpha=0.7, label='Warning (DHW=4)')
        ax1.axhline(y=8, color='red', linestyle='--', alpha=0.7, label='Alert (DHW=8)')
        
        ax1.set_xlabel('Year', fontsize=11)
        ax1.set_ylabel('DHW (°C-weeks)', fontsize=11)
        ax1.set_title('A) Documented vs Model DHW by Event', fontsize=12, fontweight='bold')
        ax1.set_xticks(x)
        ax1.set_xticklabels(years, rotation=45)
        ax1.legend(loc='upper left', fontsize=9)
        ax1.grid(True, alpha=0.3)
        
        # =========================================================================
        # Panel B: Severity Match Assessment
        # =========================================================================
        ax2 = fig.add_subplot(gs[0, 1])
        
        # Count matches
        dhw_matches = validation_df['dhw_match'].value_counts()
        pcrvi_valid = validation_df[validation_df['pcrvi_match'].notna()]
        pcrvi_matches = pcrvi_valid['pcrvi_match'].value_counts() if len(pcrvi_valid) > 0 else pd.Series()
        
        categories = ['CORRECT', 'CLOSE', 'UNDERESTIMATE', 'OVERESTIMATE']
        colors = {'CORRECT': '#2ecc71', 'CLOSE': '#f1c40f', 'UNDERESTIMATE': '#e74c3c', 'OVERESTIMATE': '#9b59b6'}
        
        x = np.arange(len(categories))
        width = 0.35
        
        dhw_counts = [dhw_matches.get(c, 0) for c in categories]
        pcrvi_counts = [pcrvi_matches.get(c, 0) for c in categories]
        
        ax2.bar(x - width/2, dhw_counts, width, label='DHW Predictions',
               color=[colors[c] for c in categories], alpha=0.7, edgecolor='black')
        ax2.bar(x + width/2, pcrvi_counts, width, label='pCRVI Predictions',
               color=[colors[c] for c in categories], alpha=0.4, edgecolor='black', hatch='//')
        
        ax2.set_xlabel('Match Category', fontsize=11)
        ax2.set_ylabel('Number of Events', fontsize=11)
        ax2.set_title('B) Prediction Accuracy Assessment', fontsize=12, fontweight='bold')
        ax2.set_xticks(x)
        ax2.set_xticklabels(categories, rotation=45, ha='right')
        ax2.legend(loc='upper right', fontsize=9)
        ax2.grid(True, alpha=0.3)
        
        # =========================================================================
        # Panel C: pCRVI Early Warning Analysis
        # =========================================================================
        ax3 = fig.add_subplot(gs[1, 0])
        
        # Plot pCRVI 30-day lead values before each event
        pcrvi_lead = validation_df[validation_df['pcrvi_30d_lead'].notna()]
        if len(pcrvi_lead) > 0:
            years_lead = pcrvi_lead['year'].values
            pcrvi_values = pcrvi_lead['pcrvi_30d_lead'].values
            actual_severity = pcrvi_lead['actual_severity'].values
            
            # Color by actual severity
            severity_colors = {'minor': '#f1c40f', 'moderate': '#e67e22', 'severe': '#e74c3c', 'catastrophic': '#8e44ad'}
            colors_list = [severity_colors.get(s, '#666') for s in actual_severity]
            
            bars = ax3.bar(range(len(years_lead)), pcrvi_values, color=colors_list, edgecolor='black', alpha=0.8)
            
            # Threshold lines
            ax3.axhline(y=0.4, color='orange', linestyle='--', alpha=0.8, label='Warning (0.4)')
            ax3.axhline(y=0.5, color='darkorange', linestyle='--', alpha=0.8, label='Moderate (0.5)')
            ax3.axhline(y=0.6, color='red', linestyle='--', alpha=0.8, label='Severe (0.6)')
            
            # Calculate early warning rate
            early_warning_count = (pcrvi_values >= 0.4).sum()
            early_warning_rate = early_warning_count / len(pcrvi_values) * 100
            
            ax3.text(0.98, 0.98, f'Early Warning Rate: {early_warning_rate:.0f}%\n({early_warning_count}/{len(pcrvi_values)} events)',
                    transform=ax3.transAxes, fontsize=11, ha='right', va='top',
                    bbox=dict(boxstyle='round', facecolor='white', alpha=0.8))
            
            ax3.set_xlabel('Event', fontsize=11)
            ax3.set_ylabel('pCRVI (30 days before peak)', fontsize=11)
            ax3.set_title('C) pCRVI Early Warning Performance', fontsize=12, fontweight='bold')
            ax3.set_xticks(range(len(years_lead)))
            ax3.set_xticklabels(years_lead, rotation=45)
            ax3.legend(loc='upper left', fontsize=9)
            ax3.set_ylim(0, 1)
        else:
            ax3.text(0.5, 0.5, 'No pCRVI lead data available', ha='center', va='center',
                    fontsize=12, transform=ax3.transAxes)
        ax3.grid(True, alpha=0.3)
        
        # =========================================================================
        # Panel D: Scatter - Model vs Actual with Bleaching %
        # =========================================================================
        ax4 = fig.add_subplot(gs[1, 1])
        
        valid_data = validation_df[(validation_df['actual_dhw'] > 0) & (validation_df['model_dhw_max'] > 0)]
        if len(valid_data) > 0:
            scatter = ax4.scatter(
                valid_data['actual_dhw'],
                valid_data['model_dhw_max'],
                s=valid_data['actual_bleaching_pct'] * 5,  # Size by bleaching %
                c=valid_data['year'],
                cmap='viridis',
                alpha=0.8,
                edgecolor='black'
            )
            
            # Perfect prediction line
            max_val = max(valid_data['actual_dhw'].max(), valid_data['model_dhw_max'].max()) * 1.1
            ax4.plot([0, max_val], [0, max_val], 'k--', alpha=0.5, label='Perfect Prediction')
            
            # Add year labels
            for _, row in valid_data.iterrows():
                ax4.annotate(str(int(row['year'])), 
                            (row['actual_dhw'], row['model_dhw_max']),
                            xytext=(5, 5), textcoords='offset points',
                            fontsize=9)
            
            plt.colorbar(scatter, ax=ax4, label='Year')
            
            # Correlation
            corr = np.corrcoef(valid_data['actual_dhw'], valid_data['model_dhw_max'])[0, 1]
            ax4.text(0.02, 0.98, f'r = {corr:.3f}', transform=ax4.transAxes,
                    fontsize=11, ha='left', va='top',
                    bbox=dict(boxstyle='round', facecolor='white', alpha=0.8))
        
        ax4.set_xlabel('Documented DHW (°C-weeks)', fontsize=11)
        ax4.set_ylabel('Model DHW (°C-weeks)', fontsize=11)
        ax4.set_title('D) Model vs Documented DHW (size = bleaching %)', fontsize=12, fontweight='bold')
        ax4.legend(loc='lower right', fontsize=9)
        ax4.grid(True, alpha=0.3)
        
        # =========================================================================
        # Panel E: Timeline with DHW and Events
        # =========================================================================
        ax5 = fig.add_subplot(gs[2, :])
        
        if dhw_data is not None and len(dhw_data) > 0:
            # Plot DHW time series
            ax5.fill_between(dhw_data.index, 0, dhw_data['dhw'], alpha=0.3, color='coral')
            ax5.plot(dhw_data.index, dhw_data['dhw'], color='coral', linewidth=1, label='DHW')
            
            # Mark historical events
            for _, row in validation_df.iterrows():
                year = row['year']
                # Find peak DHW date for this year
                year_data = dhw_data[dhw_data.index.year == year]
                if len(year_data) > 0:
                    peak_date = year_data['dhw'].idxmax()
                    peak_dhw = year_data['dhw'].max()
                    
                    # Severity colors
                    severity_colors = {'minor': '#f1c40f', 'moderate': '#e67e22', 'severe': '#e74c3c', 'catastrophic': '#8e44ad'}
                    color = severity_colors.get(row['actual_severity'], '#666')
                    
                    ax5.axvline(x=peak_date, color=color, alpha=0.7, linestyle='-', linewidth=2)
                    ax5.annotate(f"{year}\n{row['actual_severity'].title()}\n{row['actual_bleaching_pct']}%",
                               xy=(peak_date, peak_dhw),
                               xytext=(0, 20), textcoords='offset points',
                               fontsize=8, ha='center',
                               arrowprops=dict(arrowstyle='->', color=color, lw=1.5),
                               bbox=dict(boxstyle='round', facecolor='white', alpha=0.8))
            
            # Threshold lines
            ax5.axhline(y=4, color='orange', linestyle='--', alpha=0.7, label='Warning (4)')
            ax5.axhline(y=8, color='red', linestyle='--', alpha=0.7, label='Alert (8)')
            
            ax5.set_xlabel('Date', fontsize=11)
            ax5.set_ylabel('DHW (°C-weeks)', fontsize=11)
            ax5.set_title('E) DHW Timeline with Documented Bleaching Events', fontsize=12, fontweight='bold')
            ax5.legend(loc='upper right', fontsize=9)
        else:
            ax5.text(0.5, 0.5, 'No DHW time series available', ha='center', va='center',
                    fontsize=12, transform=ax5.transAxes)
        ax5.grid(True, alpha=0.3)
        
        # Overall title
        fig.suptitle('Historical Bleaching Event Validation\nAndaman & Nicobar Islands',
                    fontsize=14, fontweight='bold', y=0.98)
        
        plt.tight_layout(rect=[0, 0, 1, 0.96])
        
        # Save figure
        filename = f"{prefix}historical_validation.png" if prefix else "historical_validation.png"
        path = self.output_dir / filename
        fig.savefig(path, dpi=150, bbox_inches='tight', facecolor='white')
        plt.close(fig)
        
        self.logger.info(f"Saved historical validation plot: {path}")
        return path
    
    def generate_all_plots(
        self,
        sst_data: pd.DataFrame,
        dhw_data: pd.DataFrame,
        feature_matrix: pd.DataFrame,
        climate_data: Optional[pd.DataFrame] = None,
        feature_importance: Optional[pd.DataFrame] = None,
        mmm: float = 29.87,
        bounds: Tuple[float, float, float, float] = (90.0, 6.0, 95.0, 14.0),
        prefix: str = ""
    ) -> Dict[str, Path]:
        """
        Generate all standard visualizations.
        
        Parameters
        ----------
        sst_data : pd.DataFrame
            SST time series
        dhw_data : pd.DataFrame
            DHW time series
        feature_matrix : pd.DataFrame
            Feature matrix
        climate_data : pd.DataFrame, optional
            Climate indices
        feature_importance : pd.DataFrame, optional
            Feature importance from model
        mmm : float
            Maximum Monthly Mean SST
        bounds : tuple
            Region bounds for maps
        prefix : str
            Filename prefix
        
        Returns
        -------
        Dict[str, Path]
            Dictionary of saved plot paths
        """
        self.logger.info("Generating all visualizations...")
        
        saved_plots = {}
        
        # 1. DHW time series
        try:
            saved_plots['dhw_timeseries'] = self.plot_dhw_timeseries(dhw_data, prefix=prefix)
        except Exception as e:
            self.logger.warning(f"Failed to generate DHW timeseries: {e}")
        
        # 2. SST and DHW combined
        try:
            saved_plots['sst_dhw_combined'] = self.plot_sst_and_dhw(
                sst_data, dhw_data, mmm=mmm, prefix=prefix
            )
        except Exception as e:
            self.logger.warning(f"Failed to generate SST/DHW combined: {e}")
        
        # 3. Annual max DHW bar chart
        try:
            saved_plots['annual_max_dhw'] = self.plot_annual_max_dhw(dhw_data, prefix=prefix)
        except Exception as e:
            self.logger.warning(f"Failed to generate annual max DHW: {e}")
        
        # 4. Alert distribution pie chart
        try:
            saved_plots['alert_distribution'] = self.plot_alert_distribution(dhw_data, prefix=prefix)
        except Exception as e:
            self.logger.warning(f"Failed to generate alert distribution: {e}")
        
        # 5. Seasonal pattern
        try:
            saved_plots['seasonal_pattern'] = self.plot_seasonal_pattern(dhw_data, prefix=prefix)
        except Exception as e:
            self.logger.warning(f"Failed to generate seasonal pattern: {e}")
        
        # 6. Feature correlation heatmap
        try:
            saved_plots['feature_correlation'] = self.plot_feature_correlation(
                feature_matrix, prefix=prefix
            )
        except Exception as e:
            self.logger.warning(f"Failed to generate feature correlation: {e}")
        
        # 7. Climate indices vs DHW
        if climate_data is not None:
            try:
                saved_plots['climate_vs_dhw'] = self.plot_climate_indices_vs_dhw(
                    dhw_data, climate_data, prefix=prefix
                )
            except Exception as e:
                self.logger.warning(f"Failed to generate climate vs DHW: {e}")
        
        # 8. Feature importance
        if feature_importance is not None:
            try:
                saved_plots['feature_importance'] = self.plot_feature_importance(
                    feature_importance, prefix=prefix
                )
            except Exception as e:
                self.logger.warning(f"Failed to generate feature importance: {e}")
        
        # 9. Region map
        try:
            saved_plots['region_map'] = self.plot_region_map(
                dhw_data, bounds=bounds, prefix=prefix
            )
        except Exception as e:
            self.logger.warning(f"Failed to generate region map: {e}")
        
        # 10. Annual bleaching map grid
        try:
            saved_plots['annual_bleaching_map'] = self.plot_annual_bleaching_map(
                dhw_data, bounds=bounds, prefix=prefix
            )
        except Exception as e:
            self.logger.warning(f"Failed to generate annual bleaching map: {e}")
        
        # 11. Bleaching heatmap (month x year)
        try:
            saved_plots['bleaching_heatmap'] = self.plot_bleaching_heatmap(
                dhw_data, prefix=prefix
            )
        except Exception as e:
            self.logger.warning(f"Failed to generate bleaching heatmap: {e}")
        
        self.logger.info(f"Generated {len(saved_plots)} visualizations")
        return saved_plots

    def plot_crvi_timeseries(
        self,
        crvi_timeseries: pd.DataFrame,
        dhw_data: pd.DataFrame = None,
        figsize: Tuple[int, int] = (16, 12),
        prefix: str = ""
    ) -> Path:
        """
        Plot CRVI time series with DHW and bleaching events.
        
        Parameters
        ----------
        crvi_timeseries : pd.DataFrame
            Output from CRVICalculator.calculate_crvi_timeseries()
        dhw_data : pd.DataFrame, optional
            Full DHW time series for context
        figsize : tuple
            Figure size
        prefix : str
            Filename prefix
        
        Returns
        -------
        Path
            Path to saved figure
        """
        fig, axes = plt.subplots(4, 1, figsize=figsize, sharex=True)
        
        # Panel 1: CRVI time series with risk zones
        ax1 = axes[0]
        ax1.fill_between(crvi_timeseries.index, 0, crvi_timeseries['crvi'], 
                         alpha=0.3, color='purple', label='CRVI')
        ax1.plot(crvi_timeseries.index, crvi_timeseries['crvi'], 
                 color='purple', linewidth=1.5, label='CRVI')
        
        # Risk zone backgrounds
        ax1.axhspan(0, 0.3, alpha=0.1, color='green', label='Low Risk')
        ax1.axhspan(0.3, 0.5, alpha=0.1, color='yellow')
        ax1.axhspan(0.5, 0.7, alpha=0.1, color='orange')
        ax1.axhspan(0.7, 1.0, alpha=0.1, color='red', label='Critical Risk')
        
        # Threshold lines
        ax1.axhline(y=0.3, color='green', linestyle='--', linewidth=0.8, alpha=0.7)
        ax1.axhline(y=0.5, color='orange', linestyle='--', linewidth=0.8, alpha=0.7)
        ax1.axhline(y=0.7, color='red', linestyle='--', linewidth=0.8, alpha=0.7)
        
        ax1.set_ylabel('CRVI Score', fontsize=11)
        ax1.set_title('A) Coral Reef Vulnerability Index (CRVI) Time Series', fontsize=12, fontweight='bold')
        ax1.set_ylim(0, 1)
        ax1.legend(loc='upper right', fontsize=9)
        ax1.grid(True, alpha=0.3)
        
        # Panel 2: DHW with bleaching events highlighted
        ax2 = axes[1]
        if 'dhw_current' in crvi_timeseries.columns:
            ax2.fill_between(crvi_timeseries.index, 0, crvi_timeseries['dhw_current'],
                            alpha=0.4, color='coral')
            ax2.plot(crvi_timeseries.index, crvi_timeseries['dhw_current'],
                    color='red', linewidth=1, label='DHW')
        elif dhw_data is not None:
            ax2.fill_between(dhw_data.index, 0, dhw_data['dhw'], alpha=0.4, color='coral')
            ax2.plot(dhw_data.index, dhw_data['dhw'], color='red', linewidth=0.8, label='DHW')
        
        # Mark bleaching periods
        if 'is_bleaching_period' in crvi_timeseries.columns:
            bleaching_periods = crvi_timeseries[crvi_timeseries['is_bleaching_period']]
            if not bleaching_periods.empty:
                ax2.scatter(bleaching_periods.index, 
                           bleaching_periods['dhw_current'] if 'dhw_current' in bleaching_periods.columns else [4]*len(bleaching_periods),
                           color='darkred', s=20, alpha=0.7, label='Bleaching Period', zorder=5)
        
        ax2.axhline(y=4, color='orange', linestyle='--', linewidth=1, label='Warning (DHW=4)')
        ax2.axhline(y=8, color='red', linestyle='--', linewidth=1, label='Alert (DHW=8)')
        
        ax2.set_ylabel('DHW (°C-weeks)', fontsize=11)
        ax2.set_title('B) Degree Heating Weeks with Bleaching Events', fontsize=12, fontweight='bold')
        ax2.legend(loc='upper right', fontsize=9)
        ax2.grid(True, alpha=0.3)
        
        # Panel 3: CRVI Components
        ax3 = axes[2]
        ax3.plot(crvi_timeseries.index, crvi_timeseries['ts_norm'], 
                 label='Thermal Stress (TS)', color='#e74c3c', linewidth=1.2)
        ax3.plot(crvi_timeseries.index, crvi_timeseries['rv_norm'],
                 label='Recovery Vuln. (RV)', color='#f39c12', linewidth=1.2)
        ax3.plot(crvi_timeseries.index, crvi_timeseries['ri_norm'],
                 label='Recurrence (RI)', color='#3498db', linewidth=1.2)
        
        ax3.set_ylabel('Normalized Value', fontsize=11)
        ax3.set_title('C) CRVI Component Time Series', fontsize=12, fontweight='bold')
        ax3.set_ylim(0, 1)
        ax3.legend(loc='upper right', fontsize=9)
        ax3.grid(True, alpha=0.3)
        
        # Panel 4: Years since last bleaching (inverse of RV)
        ax4 = axes[3]
        if 'years_since_bleaching' in crvi_timeseries.columns:
            years_since = crvi_timeseries['years_since_bleaching'].fillna(15)
            ax4.fill_between(crvi_timeseries.index, 0, years_since, alpha=0.4, color='teal')
            ax4.plot(crvi_timeseries.index, years_since, color='teal', linewidth=1.2)
            
            # Mark bleaching events (resets to 0)
            resets = crvi_timeseries[crvi_timeseries['years_since_bleaching'] < 0.5]
            if not resets.empty:
                ax4.scatter(resets.index, [0]*len(resets), color='red', s=50, 
                           marker='v', label='Bleaching Event', zorder=5)
        
        ax4.set_ylabel('Years Since Bleaching', fontsize=11)
        ax4.set_xlabel('Date', fontsize=11)
        ax4.set_title('D) Recovery Time (Years Since Last Bleaching Event)', fontsize=12, fontweight='bold')
        ax4.legend(loc='upper right', fontsize=9)
        ax4.grid(True, alpha=0.3)
        
        # Format x-axis
        years = (crvi_timeseries.index.max() - crvi_timeseries.index.min()).days / 365
        if years > 5:
            ax4.xaxis.set_major_locator(mdates.YearLocator())
            ax4.xaxis.set_major_formatter(mdates.DateFormatter('%Y'))
        
        plt.xticks(rotation=45)
        plt.tight_layout()
        
        filename = f"{prefix}crvi_timeseries.png" if prefix else "crvi_timeseries.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved CRVI time series plot: {path}")
        return path

    def plot_crvi_dhw_overlay(
        self,
        crvi_timeseries: pd.DataFrame,
        dhw_data: pd.DataFrame,
        figsize: Tuple[int, int] = (14, 8),
        prefix: str = ""
    ) -> Path:
        """
        Plot CRVI and DHW on dual y-axes to show relationship.
        
        Parameters
        ----------
        crvi_timeseries : pd.DataFrame
            CRVI time series
        dhw_data : pd.DataFrame
            DHW time series
        figsize : tuple
            Figure size
        prefix : str
            Filename prefix
        
        Returns
        -------
        Path
            Path to saved figure
        """
        fig, ax1 = plt.subplots(figsize=figsize)
        
        # CRVI on primary axis
        color_crvi = '#9b59b6'
        ax1.fill_between(crvi_timeseries.index, 0, crvi_timeseries['crvi'],
                        alpha=0.2, color=color_crvi)
        line1 = ax1.plot(crvi_timeseries.index, crvi_timeseries['crvi'],
                         color=color_crvi, linewidth=2, label='CRVI')
        ax1.set_ylabel('CRVI Score', fontsize=12, color=color_crvi)
        ax1.tick_params(axis='y', labelcolor=color_crvi)
        ax1.set_ylim(0, 1)
        
        # Risk thresholds on CRVI axis
        ax1.axhline(y=0.3, color='green', linestyle=':', linewidth=1, alpha=0.5)
        ax1.axhline(y=0.5, color='orange', linestyle=':', linewidth=1, alpha=0.5)
        ax1.axhline(y=0.7, color='red', linestyle=':', linewidth=1, alpha=0.5)
        
        # DHW on secondary axis
        ax2 = ax1.twinx()
        color_dhw = '#e74c3c'
        
        # Resample DHW to match CRVI frequency if needed
        dhw_resampled = dhw_data['dhw'].resample('ME').max()
        
        line2 = ax2.plot(dhw_resampled.index, dhw_resampled.values,
                         color=color_dhw, linewidth=1.5, alpha=0.8, label='DHW (monthly max)')
        ax2.fill_between(dhw_resampled.index, 0, dhw_resampled.values,
                        alpha=0.1, color=color_dhw)
        ax2.set_ylabel('DHW (°C-weeks)', fontsize=12, color=color_dhw)
        ax2.tick_params(axis='y', labelcolor=color_dhw)
        
        # DHW thresholds
        ax2.axhline(y=4, color=color_dhw, linestyle='--', linewidth=1, alpha=0.5)
        ax2.axhline(y=8, color=color_dhw, linestyle='--', linewidth=1, alpha=0.3)
        
        # Mark major bleaching events
        dhw_copy = dhw_data.copy()
        dhw_copy['year'] = dhw_copy.index.year
        annual_max = dhw_copy.groupby('year')['dhw'].max()
        bleaching_years = annual_max[annual_max >= 4]
        
        for year in bleaching_years.index:
            ax1.axvline(x=pd.Timestamp(f'{year}-05-01'), color='red', 
                       linestyle='-', alpha=0.3, linewidth=8)
        
        # Combined legend
        lines1, labels1 = ax1.get_legend_handles_labels()
        lines2, labels2 = ax2.get_legend_handles_labels()
        ax1.legend(lines1 + lines2, labels1 + labels2, loc='upper left', fontsize=10)
        
        ax1.set_xlabel('Date', fontsize=12)
        ax1.set_title('CRVI vs DHW: Vulnerability Index and Thermal Stress Over Time', 
                     fontsize=14, fontweight='bold')
        
        # Shaded regions for bleaching years
        for year in bleaching_years.index:
            ax1.annotate(f'{year}', xy=(pd.Timestamp(f'{year}-06-01'), 0.95),
                        fontsize=9, color='red', alpha=0.7, ha='center')
        
        ax1.grid(True, alpha=0.3)
        plt.tight_layout()
        
        filename = f"{prefix}crvi_dhw_overlay.png" if prefix else "crvi_dhw_overlay.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved CRVI-DHW overlay plot: {path}")
        return path

    def plot_crvi_predictive_analysis(
        self,
        crvi_timeseries: pd.DataFrame,
        predictive_results: Dict,
        figsize: Tuple[int, int] = (16, 10),
        prefix: str = ""
    ) -> Path:
        """
        Plot CRVI predictive analysis results.
        
        Parameters
        ----------
        crvi_timeseries : pd.DataFrame
            CRVI time series
        predictive_results : dict
            Output from CRVICalculator.analyze_crvi_predictive_power()
        figsize : tuple
            Figure size
        prefix : str
            Filename prefix
        
        Returns
        -------
        Path
            Path to saved figure
        """
        fig = plt.figure(figsize=figsize)
        
        # Create grid for subplots
        gs = fig.add_gridspec(2, 3, hspace=0.3, wspace=0.3)
        
        # Panel 1: CRVI vs Future DHW scatter (3-month lead)
        ax1 = fig.add_subplot(gs[0, 0])
        
        if 'lead_time_analysis' in predictive_results:
            lead_3m = predictive_results['lead_time_analysis'].get('3_months', {})
            if lead_3m:
                # Create scatter from CRVI and future DHW
                crvi_vals = crvi_timeseries['crvi'].values[:-3]  # Exclude last 3 months
                dhw_vals = crvi_timeseries['dhw_current'].shift(-3).values[:-3]  # 3-month ahead DHW
                
                valid_mask = ~np.isnan(dhw_vals)
                if valid_mask.sum() > 0:
                    scatter = ax1.scatter(crvi_vals[valid_mask], dhw_vals[valid_mask], 
                                         alpha=0.5, c=dhw_vals[valid_mask], cmap='YlOrRd', s=30)
                    plt.colorbar(scatter, ax=ax1, label='DHW')
                    
                    # Add correlation
                    corr = lead_3m.get('correlation', 0)
                    ax1.text(0.05, 0.95, f'r = {corr:.3f}', transform=ax1.transAxes,
                            fontsize=10, verticalalignment='top',
                            bbox=dict(boxstyle='round', facecolor='white', alpha=0.8))
        
        ax1.axhline(y=4, color='orange', linestyle='--', alpha=0.7, label='DHW=4')
        ax1.axhline(y=8, color='red', linestyle='--', alpha=0.7, label='DHW=8')
        ax1.axvline(x=0.4, color='purple', linestyle='--', alpha=0.7, label='CRVI=0.4')
        ax1.set_xlabel('CRVI (current)', fontsize=11)
        ax1.set_ylabel('DHW (3 months ahead)', fontsize=11)
        ax1.set_title('A) CRVI vs Future DHW (3-month lead)', fontsize=11, fontweight='bold')
        ax1.legend(loc='lower right', fontsize=8)
        ax1.grid(True, alpha=0.3)
        
        # Panel 2: Lead time correlation bars
        ax2 = fig.add_subplot(gs[0, 1])
        
        if 'lead_time_analysis' in predictive_results:
            lead_times = []
            correlations = []
            for key, val in predictive_results['lead_time_analysis'].items():
                lead_months = int(key.split('_')[0])
                lead_times.append(lead_months)
                correlations.append(val.get('correlation', 0))
            
            if lead_times:
                colors = ['#3498db' if c > 0.3 else '#95a5a6' for c in correlations]
                bars = ax2.bar(lead_times, correlations, color=colors, edgecolor='black', alpha=0.7)
                ax2.axhline(y=0.3, color='green', linestyle='--', alpha=0.7, label='Moderate correlation')
                ax2.set_xlabel('Lead Time (months)', fontsize=11)
                ax2.set_ylabel('Correlation (r)', fontsize=11)
                ax2.set_title('B) CRVI-DHW Correlation by Lead Time', fontsize=11, fontweight='bold')
                ax2.set_ylim(0, 1)
                
                # Add value labels
                for bar, corr in zip(bars, correlations):
                    ax2.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.02,
                            f'{corr:.2f}', ha='center', fontsize=9)
        
        ax2.grid(True, alpha=0.3, axis='y')
        
        # Panel 3: Precision/Recall by lead time
        ax3 = fig.add_subplot(gs[0, 2])
        
        if 'lead_time_analysis' in predictive_results:
            lead_times = []
            precisions = []
            recalls = []
            
            for key, val in predictive_results['lead_time_analysis'].items():
                lead_months = int(key.split('_')[0])
                lead_times.append(lead_months)
                precisions.append(val.get('precision', 0))
                recalls.append(val.get('recall', 0))
            
            if lead_times:
                x = np.arange(len(lead_times))
                width = 0.35
                
                ax3.bar(x - width/2, precisions, width, label='Precision', color='#2ecc71', alpha=0.7)
                ax3.bar(x + width/2, recalls, width, label='Recall', color='#e74c3c', alpha=0.7)
                
                ax3.set_xlabel('Lead Time (months)', fontsize=11)
                ax3.set_ylabel('Score', fontsize=11)
                ax3.set_title('C) Prediction Accuracy by Lead Time', fontsize=11, fontweight='bold')
                ax3.set_xticks(x)
                ax3.set_xticklabels(lead_times)
                ax3.legend(fontsize=9)
                ax3.set_ylim(0, 1)
        
        ax3.grid(True, alpha=0.3, axis='y')
        
        # Panel 4: CRVI before bleaching events
        ax4 = fig.add_subplot(gs[1, 0])
        
        if 'bleaching_event_analysis' in predictive_results:
            pre_event = predictive_results['bleaching_event_analysis'].get('pre_event_crvi_values', [])
            if pre_event:
                years = [x['year'] for x in pre_event]
                crvi_vals = [x['crvi_pre_event'] for x in pre_event]
                max_dhw = [x['max_dhw'] for x in pre_event]
                
                colors = ['#e74c3c' if d >= 8 else '#f39c12' if d >= 4 else '#3498db' for d in max_dhw]
                bars = ax4.bar(range(len(years)), crvi_vals, color=colors, edgecolor='black', alpha=0.7)
                ax4.set_xticks(range(len(years)))
                ax4.set_xticklabels(years, rotation=45)
                ax4.axhline(y=0.4, color='purple', linestyle='--', label='CRVI threshold (0.4)')
                
                # Add DHW labels
                for i, (bar, dhw) in enumerate(zip(bars, max_dhw)):
                    ax4.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.02,
                            f'DHW:{dhw:.1f}', ha='center', fontsize=8, rotation=45)
                
                mean_crvi = predictive_results['bleaching_event_analysis'].get('mean_pre_event_crvi')
                if mean_crvi:
                    ax4.axhline(y=mean_crvi, color='green', linestyle='-', linewidth=2, 
                               alpha=0.7, label=f'Mean pre-event CRVI: {mean_crvi:.2f}')
        
        ax4.set_xlabel('Bleaching Year', fontsize=11)
        ax4.set_ylabel('CRVI (6 months prior)', fontsize=11)
        ax4.set_title('D) CRVI Values Before Bleaching Events', fontsize=11, fontweight='bold')
        ax4.legend(loc='upper right', fontsize=8)
        ax4.set_ylim(0, 1)
        ax4.grid(True, alpha=0.3, axis='y')
        
        # Panel 5: Threshold optimization
        ax5 = fig.add_subplot(gs[1, 1])
        
        if 'threshold_analysis' in predictive_results:
            thresh_data = predictive_results['threshold_analysis']
            if thresh_data:
                thresholds = [t['threshold'] for t in thresh_data]
                hit_rates = [t['hit_rate'] for t in thresh_data]
                n_alerts = [t['n_alerts'] for t in thresh_data]
                
                # Dual axis for hit rate and alert count
                color1 = '#2ecc71'
                ax5.bar(thresholds, hit_rates, width=0.08, color=color1, alpha=0.7, label='Hit Rate')
                ax5.set_ylabel('Hit Rate', fontsize=11, color=color1)
                ax5.tick_params(axis='y', labelcolor=color1)
                ax5.set_ylim(0, 1)
                
                ax5b = ax5.twinx()
                color2 = '#3498db'
                ax5b.plot(thresholds, n_alerts, 'o-', color=color2, linewidth=2, markersize=8, label='# Alerts')
                ax5b.set_ylabel('Number of Alerts', fontsize=11, color=color2)
                ax5b.tick_params(axis='y', labelcolor=color2)
                
                # Mark optimal threshold
                if 'optimal_threshold' in predictive_results:
                    opt = predictive_results['optimal_threshold']
                    ax5.axvline(x=opt, color='red', linestyle='--', linewidth=2, 
                               label=f'Optimal: {opt}')
        
        ax5.set_xlabel('CRVI Threshold', fontsize=11)
        ax5.set_title('E) Alert Threshold Optimization', fontsize=11, fontweight='bold')
        ax5.legend(loc='upper left', fontsize=8)
        ax5.grid(True, alpha=0.3)
        
        # Panel 6: Confusion matrix for optimal threshold
        ax6 = fig.add_subplot(gs[1, 2])
        
        if 'lead_time_analysis' in predictive_results:
            # Use 3-month lead time for confusion matrix
            lead_3m = predictive_results['lead_time_analysis'].get('3_months', {})
            if lead_3m:
                cm = np.array([
                    [lead_3m.get('true_negatives', 0), lead_3m.get('false_positives', 0)],
                    [lead_3m.get('false_negatives', 0), lead_3m.get('true_positives', 0)]
                ])
                
                im = ax6.imshow(cm, cmap='Blues', aspect='auto')
                
                # Add text annotations
                for i in range(2):
                    for j in range(2):
                        text_color = 'white' if cm[i, j] > cm.max()/2 else 'black'
                        ax6.text(j, i, f'{cm[i, j]}', ha='center', va='center', 
                                color=text_color, fontsize=14, fontweight='bold')
                
                ax6.set_xticks([0, 1])
                ax6.set_yticks([0, 1])
                ax6.set_xticklabels(['No Bleaching', 'Bleaching'])
                ax6.set_yticklabels(['Low CRVI\n(<0.4)', 'High CRVI\n(≥0.4)'])
                ax6.set_xlabel('Actual (3 months ahead)', fontsize=11)
                ax6.set_ylabel('Predicted (CRVI)', fontsize=11)
                ax6.set_title('F) Confusion Matrix (3-month forecast)', fontsize=11, fontweight='bold')
                
                # Add accuracy text
                accuracy = lead_3m.get('accuracy', 0)
                ax6.text(0.5, -0.15, f'Accuracy: {accuracy:.1%}', transform=ax6.transAxes,
                        ha='center', fontsize=10, fontweight='bold')
        
        plt.suptitle('CRVI Predictive Power Analysis', fontsize=14, fontweight='bold', y=1.02)
        plt.tight_layout()
        
        filename = f"{prefix}crvi_predictive_analysis.png" if prefix else "crvi_predictive_analysis.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved CRVI predictive analysis plot: {path}")
        return path

    def plot_crvi_risk_periods(
        self,
        crvi_timeseries: pd.DataFrame,
        risk_periods: pd.DataFrame,
        dhw_data: pd.DataFrame,
        figsize: Tuple[int, int] = (14, 8),
        prefix: str = ""
    ) -> Path:
        """
        Plot CRVI with highlighted risk periods and outcomes.
        
        Parameters
        ----------
        crvi_timeseries : pd.DataFrame
            CRVI time series
        risk_periods : pd.DataFrame
            Output from CRVICalculator.get_crvi_risk_periods()
        dhw_data : pd.DataFrame
            DHW time series
        figsize : tuple
            Figure size
        prefix : str
            Filename prefix
        
        Returns
        -------
        Path
            Path to saved figure
        """
        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=figsize, sharex=True)
        
        # Panel 1: CRVI with risk periods highlighted
        ax1.plot(crvi_timeseries.index, crvi_timeseries['crvi'], 
                 color='purple', linewidth=1.5, label='CRVI')
        ax1.fill_between(crvi_timeseries.index, 0, crvi_timeseries['crvi'],
                        alpha=0.2, color='purple')
        
        # Highlight risk periods
        for _, period in risk_periods.iterrows():
            color = '#e74c3c' if period['bleaching_occurred'] else '#f39c12'
            alpha = 0.4 if period['bleaching_occurred'] else 0.2
            ax1.axvspan(period['start'], period['end'], alpha=alpha, color=color)
            
            # Add label
            mid_date = period['start'] + (period['end'] - period['start']) / 2
            label = '✓ Bleaching' if period['bleaching_occurred'] else 'No bleaching'
            ax1.annotate(label, xy=(mid_date, period['max_crvi']), 
                        fontsize=8, ha='center', va='bottom',
                        color='darkred' if period['bleaching_occurred'] else 'gray')
        
        ax1.axhline(y=0.4, color='red', linestyle='--', label='Risk threshold (0.4)')
        ax1.set_ylabel('CRVI Score', fontsize=11)
        ax1.set_title('CRVI Time Series with Elevated Risk Periods', fontsize=12, fontweight='bold')
        ax1.set_ylim(0, 1)
        ax1.legend(loc='upper right')
        ax1.grid(True, alpha=0.3)
        
        # Panel 2: DHW with bleaching events
        ax2.fill_between(dhw_data.index, 0, dhw_data['dhw'], alpha=0.4, color='coral')
        ax2.plot(dhw_data.index, dhw_data['dhw'], color='red', linewidth=0.8)
        
        # Mark bleaching threshold crossings
        bleaching_mask = dhw_data['dhw'] >= 4
        if bleaching_mask.any():
            ax2.scatter(dhw_data.index[bleaching_mask], dhw_data['dhw'][bleaching_mask],
                       color='darkred', s=5, alpha=0.5)
        
        ax2.axhline(y=4, color='orange', linestyle='--', label='Warning (DHW=4)')
        ax2.axhline(y=8, color='red', linestyle='--', label='Alert (DHW=8)')
        ax2.set_ylabel('DHW (°C-weeks)', fontsize=11)
        ax2.set_xlabel('Date', fontsize=11)
        ax2.set_title('DHW Time Series with Bleaching Events', fontsize=12, fontweight='bold')
        ax2.legend(loc='upper right')
        ax2.grid(True, alpha=0.3)
        
        # Add legend for risk period colors
        from matplotlib.patches import Patch
        legend_elements = [
            Patch(facecolor='#e74c3c', alpha=0.4, label='Risk period → Bleaching'),
            Patch(facecolor='#f39c12', alpha=0.2, label='Risk period → No bleaching')
        ]
        ax1.legend(handles=legend_elements + ax1.get_legend_handles_labels()[0], 
                  loc='upper right', fontsize=9)
        
        plt.tight_layout()
        
        filename = f"{prefix}crvi_risk_periods.png" if prefix else "crvi_risk_periods.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved CRVI risk periods plot: {path}")
        return path

    def plot_pcrvi_timeseries(
        self,
        pcrvi_data: pd.DataFrame,
        dhw_data: pd.DataFrame,
        figsize: Tuple[int, int] = (16, 14),
        historical_events: Optional[Dict[int, Dict]] = None,
        prefix: str = ""
    ) -> Path:
        """
        Plot Predictive CRVI time series with all components.
        
        Parameters
        ----------
        pcrvi_data : pd.DataFrame
            Output from PredictiveCRVI.calculate_pcrvi_timeseries()
        dhw_data : pd.DataFrame
            DHW time series for reference
        figsize : tuple
            Figure size
        historical_events : dict, optional
            Known historical bleaching events {year: {'severity': ..., 'bleaching_pct': ...}}
        prefix : str
            Filename prefix
        
        Returns
        -------
        Path
            Path to saved figure
        """
        fig, axes = plt.subplots(6, 1, figsize=(figsize[0], figsize[1] + 4), sharex=True)
        
        # Panel 1: pCRVI with risk zones and DHW events
        ax1 = axes[0]
        
        # Risk zone backgrounds
        ax1.axhspan(0, 0.3, alpha=0.15, color='green')
        ax1.axhspan(0.3, 0.5, alpha=0.15, color='yellow')
        ax1.axhspan(0.5, 0.7, alpha=0.15, color='orange')
        ax1.axhspan(0.7, 1.0, alpha=0.15, color='red')
        
        # pCRVI line
        ax1.plot(pcrvi_data.index, pcrvi_data['pcrvi'], 
                 color='purple', linewidth=1.5, label='pCRVI')
        ax1.fill_between(pcrvi_data.index, 0, pcrvi_data['pcrvi'], 
                         alpha=0.3, color='purple')
        
        # Mark bleaching events - use historical_events if provided, else compute from DHW
        dhw_copy = dhw_data.copy()
        dhw_copy['year'] = dhw_copy.index.year
        annual_max = dhw_copy.groupby('year')['dhw'].max()
        
        if historical_events:
            data_min_year = int(pcrvi_data.index.min().year)
            data_max_year = int(pcrvi_data.index.max().year)
            bleaching_years = [y for y in historical_events.keys()
                               if data_min_year <= y <= data_max_year]
        else:
            bleaching_years = annual_max[annual_max >= 4].index.tolist()
        
        for year in bleaching_years:
            event_date = pd.Timestamp(f'{year}-05-15')  # Approximate peak
            if pcrvi_data.index.min() <= event_date <= pcrvi_data.index.max():
                ax1.axvline(x=event_date, color='red', linestyle='-', linewidth=2, alpha=0.5)
                if historical_events and year in historical_events:
                    severity = historical_events[year].get('severity', 'Unknown')
                    label = f'{year}\n{severity}'
                else:
                    dhw_val = annual_max[year] if year in annual_max.index else 0
                    label = f'{year}\nDHW:{dhw_val:.1f}'
                ax1.annotate(label, 
                            xy=(event_date, 0.95), fontsize=8, color='red',
                            ha='center', va='top')
        
        ax1.axhline(y=0.3, color='green', linestyle='--', linewidth=0.8, alpha=0.7)
        ax1.axhline(y=0.4, color='yellow', linestyle='--', linewidth=0.8, alpha=0.7)
        ax1.axhline(y=0.5, color='orange', linestyle='--', linewidth=0.8, alpha=0.7)
        ax1.axhline(y=0.6, color='darkorange', linestyle='--', linewidth=0.8, alpha=0.7)
        ax1.axhline(y=0.85, color='red', linestyle='--', linewidth=0.8, alpha=0.7)
        
        ax1.set_ylabel('pCRVI Score', fontsize=11)
        ax1.set_title('A) Predictive CRVI with Bleaching Events (Red Lines)', 
                     fontsize=12, fontweight='bold')
        ax1.set_ylim(0, 1)
        ax1.legend(loc='upper left', fontsize=9)
        ax1.grid(True, alpha=0.3)
        
        # Add risk zone labels
        ax1.text(pcrvi_data.index[0], 0.15, 'LOW', fontsize=9, color='green', alpha=0.7)
        ax1.text(pcrvi_data.index[0], 0.4, 'WARNING', fontsize=9, color='yellow', alpha=0.7)
        ax1.text(pcrvi_data.index[0], 0.5, 'MODERATE', fontsize=9, color='orange', alpha=0.7)
        ax1.text(pcrvi_data.index[0], 0.6, 'SEVERE', fontsize=9, color='darkorange', alpha=0.7)
        ax1.text(pcrvi_data.index[0], 0.85, 'CRITICAL', fontsize=9, color='red', alpha=0.7)
        
        # Panel 2: DHW time series
        ax2 = axes[1]
        ax2.fill_between(dhw_data.index, 0, dhw_data['dhw'], alpha=0.4, color='coral')
        ax2.plot(dhw_data.index, dhw_data['dhw'], color='red', linewidth=0.8, label='DHW')
        ax2.axhline(y=4, color='orange', linestyle='--', label='Warning (4)')
        ax2.axhline(y=8, color='red', linestyle='--', label='Alert (8)')
        ax2.set_ylabel('DHW (°C-weeks)', fontsize=11)
        ax2.set_title('B) Degree Heating Weeks', fontsize=12, fontweight='bold')
        ax2.legend(loc='upper right', fontsize=9)
        ax2.grid(True, alpha=0.3)
        
        # Panel 3: Thermal components (TA + AS)
        ax3 = axes[2]
        ax3.plot(pcrvi_data.index, pcrvi_data['ta_norm'], 
                 label=COMPONENT_LABELS['ta_norm'], color=COMPONENT_COLORS['ta_norm'], linewidth=1.2, alpha=0.8)
        ax3.plot(pcrvi_data.index, pcrvi_data['as_norm'],
                 label=COMPONENT_LABELS['as_norm'], color=COMPONENT_COLORS['as_norm'], linewidth=1.2, alpha=0.8)
        ax3.fill_between(pcrvi_data.index, 0, pcrvi_data['ta_norm'], alpha=0.2, color='#e74c3c')
        ax3.set_ylabel('Normalized Value', fontsize=11)
        ax3.set_title('C) Thermal Components (Current Stress Indicators)', fontsize=12, fontweight='bold')
        ax3.set_ylim(0, 1)
        ax3.legend(loc='upper right', fontsize=9)
        ax3.grid(True, alpha=0.3)
        
        # Panel 4: Environmental components (SR + CDR)
        ax4 = axes[3]
        ax4.plot(pcrvi_data.index, pcrvi_data['sr_norm'],
                 label=COMPONENT_LABELS['sr_norm'], color=COMPONENT_COLORS['sr_norm'], linewidth=1.2)
        ax4.plot(pcrvi_data.index, pcrvi_data['cdr_norm'],
                 label=COMPONENT_LABELS['cdr_norm'], color=COMPONENT_COLORS['cdr_norm'], linewidth=1.2)
        
        # Highlight peak season
        for year in pcrvi_data.index.year.unique():
            peak_start = pd.Timestamp(f'{year}-03-01')
            peak_end = pd.Timestamp(f'{year}-06-30')
            if peak_start >= pcrvi_data.index.min() and peak_end <= pcrvi_data.index.max():
                ax4.axvspan(peak_start, peak_end, alpha=0.1, color='orange')
        
        ax4.set_ylabel('Normalized Value', fontsize=11)
        ax4.set_title('D) Environmental Risk Factors (Seasonal & Climate)', fontsize=12, fontweight='bold')
        ax4.set_ylim(0, 1)
        ax4.legend(loc='upper right', fontsize=9)
        ax4.grid(True, alpha=0.3)
        
        # Panel 5: Bleaching History component
        ax5 = axes[4]
        ax5.plot(pcrvi_data.index, pcrvi_data['bh_norm'],
                 label=COMPONENT_LABELS['bh_norm'], color=COMPONENT_COLORS['bh_norm'], linewidth=1.5)
        ax5.fill_between(pcrvi_data.index, 0, pcrvi_data['bh_norm'], alpha=0.3, color='#9b59b6')
        
        # Annotate adaptation periods
        ax5.annotate('↓ Adapted survivors\n(low vulnerability)', 
                    xy=(0.02, 0.15), xycoords='axes fraction',
                    fontsize=9, color='green')
        ax5.annotate('↑ Naive population\n(high vulnerability)', 
                    xy=(0.02, 0.85), xycoords='axes fraction',
                    fontsize=9, color='red')
        
        ax5.set_ylabel('Normalized Value', fontsize=11)
        ax5.set_title('E) Population Vulnerability (Adaptation State)', fontsize=12, fontweight='bold')
        ax5.set_ylim(0, 1)
        ax5.legend(loc='upper right', fontsize=9)
        ax5.grid(True, alpha=0.3)
        
        # Panel 6: Water Quality + Light Availability
        ax6 = axes[5]
        if 'wq_norm' in pcrvi_data.columns:
            ax6.plot(pcrvi_data.index, pcrvi_data['wq_norm'],
                     label=COMPONENT_LABELS.get('wq_norm', 'Water Quality'),
                     color=COMPONENT_COLORS.get('wq_norm', '#2CA02C'), linewidth=1.2)
        if 'la_norm' in pcrvi_data.columns:
            ax6.plot(pcrvi_data.index, pcrvi_data['la_norm'],
                     label=COMPONENT_LABELS.get('la_norm', 'Light Availability'),
                     color=COMPONENT_COLORS.get('la_norm', '#E377C2'), linewidth=1.2)
        if 'chl_anomaly' in pcrvi_data.columns:
            ax6_twin = ax6.twinx()
            ax6_twin.plot(pcrvi_data.index, pcrvi_data['chl_anomaly'],
                          label=label('chlorophyll_anomaly', 'full'),
                          color='#27ae60', linewidth=0.8, linestyle='--', alpha=0.6)
            if 'kd490_anomaly' in pcrvi_data.columns:
                ax6_twin.plot(pcrvi_data.index, pcrvi_data['kd490_anomaly'],
                              label=label('turbidity_anomaly', 'full'),
                              color='#2980b9', linewidth=0.8, linestyle='--', alpha=0.6)
            ax6_twin.set_ylabel('Anomaly Value', fontsize=10, color='gray')
            ax6_twin.legend(loc='upper left', fontsize=8)
        ax6.set_ylabel('Normalized Value', fontsize=11)
        ax6.set_xlabel('Date', fontsize=11)
        ax6.set_title('F) Water Quality (Chlorophyll-a + Turbidity) & Light Availability',
                       fontsize=12, fontweight='bold')
        ax6.set_ylim(0, 1)
        ax6.legend(loc='upper right', fontsize=9)
        ax6.grid(True, alpha=0.3)
        
        plt.tight_layout()
        
        filename = f"{prefix}pcrvi_timeseries.png" if prefix else "pcrvi_timeseries.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved pCRVI time series plot: {path}")
        return path

    def plot_pcrvi_predictive_dashboard(
        self,
        pcrvi_data: pd.DataFrame,
        dhw_data: pd.DataFrame,
        skill_results: Dict,
        figsize: Tuple[int, int] = (18, 12),
        historical_events: Optional[Dict[int, Dict]] = None,
        prefix: str = ""
    ) -> Path:
        """
        Plot comprehensive pCRVI predictive skill dashboard.
        
        Parameters
        ----------
        pcrvi_data : pd.DataFrame
            pCRVI time series
        dhw_data : pd.DataFrame
            DHW time series
        skill_results : dict
            Output from PredictiveCRVI.analyze_predictive_skill()
        figsize : tuple
            Figure size
        historical_events : dict, optional
            Known historical bleaching events {year: {'severity': ..., 'bleaching_pct': ...}}
        prefix : str
            Filename prefix
        
        Returns
        -------
        Path
            Path to saved figure
        """
        fig = plt.figure(figsize=figsize)
        gs = fig.add_gridspec(3, 3, hspace=0.35, wspace=0.3)
        
        # Panel A: pCRVI vs Future DHW scatter
        ax1 = fig.add_subplot(gs[0, 0])
        
        # Calculate scatter data for 30-day lead
        lead_days = 30
        pcrvi_vals = []
        future_dhw = []
        
        for date in pcrvi_data.index[:-lead_days]:
            pcrvi_val = pcrvi_data.loc[date, 'pcrvi']
            future_date = date + pd.Timedelta(days=lead_days)
            if future_date in dhw_data.index:
                period_dhw = dhw_data.loc[date:future_date, 'dhw'].max()
                pcrvi_vals.append(pcrvi_val)
                future_dhw.append(period_dhw)
        
        if pcrvi_vals:
            pa = np.array(pcrvi_vals, dtype=float)
            fa = np.array(future_dhw, dtype=float)
            valid = np.isfinite(pa) & np.isfinite(fa)
            pa, fa = pa[valid], fa[valid]

            scatter = ax1.scatter(pa, fa, 
                                 c=fa, cmap='YlOrRd', 
                                 alpha=0.6, s=20, edgecolors='none')
            plt.colorbar(scatter, ax=ax1, label='Future DHW')
            
            # Add correlation (safe)
            if np.std(pa) > 0 and np.std(fa) > 0:
                corr = float(np.corrcoef(pa, fa)[0, 1])
            else:
                corr = 0.0
            ax1.text(0.05, 0.95, f'r = {corr:.3f}', transform=ax1.transAxes,
                    fontsize=11, fontweight='bold', verticalalignment='top',
                    bbox=dict(boxstyle='round', facecolor='white', alpha=0.9))
            
            # Trend line
            z = np.polyfit(pa, fa, 1)
            p = np.poly1d(z)
            x_line = np.linspace(pa.min(), pa.max(), 100)
            ax1.plot(x_line, p(x_line), 'b--', alpha=0.7, linewidth=2)
        
        ax1.axhline(y=4, color='orange', linestyle='--', alpha=0.7, label='DHW=4')
        ax1.axhline(y=8, color='red', linestyle='--', alpha=0.7, label='DHW=8')
        ax1.axvline(x=0.4, color='purple', linestyle='--', alpha=0.7, label='pCRVI=0.4')
        ax1.set_xlabel('pCRVI (current)', fontsize=11)
        ax1.set_ylabel('Max DHW (30 days ahead)', fontsize=11)
        ax1.set_title('A) pCRVI vs Future DHW (30-day lead)', fontsize=11, fontweight='bold')
        ax1.grid(True, alpha=0.3)
        
        # Panel B: Correlation by lead time
        ax2 = fig.add_subplot(gs[0, 1])
        
        if 'lead_time_analysis' in skill_results:
            lead_times = []
            correlations = []
            for key, val in sorted(skill_results['lead_time_analysis'].items()):
                days = int(key.split('_')[0])
                lead_times.append(days)
                correlations.append(val.get('correlation', 0))
            
            colors = ['#27ae60' if c > 0.4 else '#3498db' if c > 0.2 else '#95a5a6' for c in correlations]
            bars = ax2.bar(lead_times, correlations, color=colors, edgecolor='black', alpha=0.8)
            
            ax2.axhline(y=0.4, color='green', linestyle='--', alpha=0.7, label='Good (r>0.4)')
            ax2.axhline(y=0.2, color='blue', linestyle='--', alpha=0.7, label='Fair (r>0.2)')
            
            for bar, corr in zip(bars, correlations):
                ax2.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.02,
                        f'{corr:.2f}', ha='center', fontsize=9, fontweight='bold')
        
        ax2.set_xlabel('Lead Time (days)', fontsize=11)
        ax2.set_ylabel('Correlation (r)', fontsize=11)
        ax2.set_title('B) Predictive Correlation by Lead Time', fontsize=11, fontweight='bold')
        ax2.set_ylim(-0.2, 1.0)
        ax2.legend(fontsize=8)
        ax2.grid(True, alpha=0.3, axis='y')
        
        # Panel C: Skill scores comparison
        ax3 = fig.add_subplot(gs[0, 2])
        
        if 'lead_time_analysis' in skill_results:
            lead_times = []
            f1_scores = []
            mcc_scores = []
            pss_scores = []
            hss_scores = []
            
            for key, val in sorted(skill_results['lead_time_analysis'].items()):
                days = int(key.split('_')[0])
                lead_times.append(days)
                f1_scores.append(val.get('f1_score', 0))
                mcc_scores.append(max(0, val.get('mcc', 0)))
                pss_scores.append(max(0, val.get('peirce_skill_score', 0)))
                hss_scores.append(max(0, val.get('heidke_skill_score', 0)))
            
            x = np.arange(len(lead_times))
            width = 0.20
            
            ax3.bar(x - 1.5*width, f1_scores, width, label='F1', color='#1F77B4', alpha=0.85)
            ax3.bar(x - 0.5*width, mcc_scores, width, label='MCC', color='#FF7F0E', alpha=0.85)
            ax3.bar(x + 0.5*width, pss_scores, width, label='PSS/TSS', color='#2CA02C', alpha=0.85)
            ax3.bar(x + 1.5*width, hss_scores, width, label='HSS', color='#9467BD', alpha=0.85)
            
            ax3.set_xlabel('Lead Time (days)', fontsize=11)
            ax3.set_ylabel('Score', fontsize=11)
            ax3.set_title('C) Skill Scores by Lead Time', fontsize=11, fontweight='bold')
            ax3.set_xticks(x)
            ax3.set_xticklabels(lead_times)
            ax3.legend(fontsize=8, ncol=2)
            ymax = max(max(f1_scores + mcc_scores + pss_scores + hss_scores, default=0) * 1.2, 0.5)
            ax3.set_ylim(0, ymax)
            ax3.grid(True, alpha=0.3, axis='y')
            ax3.text(0.02, 0.95, f'threshold={skill_results.get("optimal_threshold", 0.4):.2f}\nshown at default',
                     transform=ax3.transAxes, fontsize=7, va='top',
                     bbox=dict(boxstyle='round', facecolor='lightyellow', alpha=0.8))
        
        # Panel D: Pre-event pCRVI analysis
        ax4 = fig.add_subplot(gs[1, 0])
        
        # Find pCRVI values before each bleaching event
        dhw_copy = dhw_data.copy()
        dhw_copy['year'] = dhw_copy.index.year
        annual_max = dhw_copy.groupby('year')['dhw'].max()
        
        # Use historical_events if provided, else compute from DHW
        # Filter to years within the actual data range
        data_min_year = int(pcrvi_data.index.min().year)
        data_max_year = int(pcrvi_data.index.max().year)
        if historical_events:
            bleaching_years = [y for y in historical_events.keys()
                               if data_min_year <= y <= data_max_year]
        else:
            bleaching_years = annual_max[annual_max >= 4].index.tolist()
        
        pre_event_data = []
        for year in bleaching_years:
            # Get pCRVI 30 days before peak (estimated May 15)
            peak_date = pd.Timestamp(f'{year}-05-15')
            pre_date = peak_date - pd.Timedelta(days=30)
            
            if pre_date in pcrvi_data.index:
                pre_pcrvi = pcrvi_data.loc[pre_date, 'pcrvi']
            else:
                # Find nearest
                idx = pcrvi_data.index.get_indexer([pre_date], method='nearest')[0]
                if idx >= 0 and idx < len(pcrvi_data):
                    pre_pcrvi = pcrvi_data.iloc[idx]['pcrvi']
                else:
                    continue
            
            if year not in annual_max.index:
                continue
            pre_event_data.append({
                'year': year,
                'pcrvi': pre_pcrvi,
                'dhw': annual_max[year]
            })
        
        if pre_event_data:
            years = [d['year'] for d in pre_event_data]
            pcrvi_vals = [d['pcrvi'] for d in pre_event_data]
            dhw_vals = [d['dhw'] for d in pre_event_data]
            
            colors = ['#e74c3c' if d >= 6 else '#f39c12' for d in dhw_vals]
            bars = ax4.bar(range(len(years)), pcrvi_vals, color=colors, edgecolor='black', alpha=0.8)
            
            ax4.axhline(y=0.4, color='purple', linestyle='--', linewidth=2, 
                       label='Alert threshold (0.4)')
            
            mean_pcrvi = np.mean(pcrvi_vals)
            ax4.axhline(y=mean_pcrvi, color='green', linestyle='-', linewidth=2,
                       label=f'Mean pre-event: {mean_pcrvi:.2f}')
            
            # Add DHW labels
            for i, (bar, dhw) in enumerate(zip(bars, dhw_vals)):
                ax4.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.03,
                        f'DHW\n{dhw:.1f}', ha='center', fontsize=8)
            
            ax4.set_xticks(range(len(years)))
            ax4.set_xticklabels(years)
        
        ax4.set_xlabel('Bleaching Year', fontsize=11)
        ax4.set_ylabel('pCRVI (30 days before peak)', fontsize=11)
        ax4.set_title('D) pCRVI Before Bleaching Events', fontsize=11, fontweight='bold')
        ax4.set_ylim(0, 1)
        ax4.legend(loc='upper right', fontsize=8)
        ax4.grid(True, alpha=0.3, axis='y')
        
        # Panel E: Threshold optimization (F1 vs threshold)
        ax5 = fig.add_subplot(gs[1, 1])
        
        if 'threshold_analysis' in skill_results:
            thresholds = []
            f1_scores = []
            n_alerts = []
            
            for key, val in sorted(skill_results['threshold_analysis'].items()):
                thresholds.append(float(key))
                f1_scores.append(val.get('f1_score', 0))
                n_alerts.append(val.get('n_alerts', 0))
            
            ax5.plot(thresholds, f1_scores, 'o-', color='#2ecc71', linewidth=2, 
                    markersize=8, label='F1 Score')
            
            ax5b = ax5.twinx()
            ax5b.bar(thresholds, n_alerts, width=0.03, alpha=0.3, color='blue', label='# Alerts')
            ax5b.set_ylabel('Number of Alerts', fontsize=11, color='blue')
            ax5b.tick_params(axis='y', labelcolor='blue')
            
            # Mark optimal
            if 'optimal_threshold' in skill_results:
                opt = skill_results['optimal_threshold']
                ax5.axvline(x=opt, color='red', linestyle='--', linewidth=2,
                           label=f'Optimal: {opt:.2f}')
        
        ax5.set_xlabel('pCRVI Threshold', fontsize=11)
        ax5.set_ylabel('F1 Score', fontsize=11, color='green')
        ax5.tick_params(axis='y', labelcolor='green')
        ax5.set_title('E) Threshold Optimization', fontsize=11, fontweight='bold')
        ax5.set_ylim(0, 1)
        ax5.legend(loc='upper left', fontsize=8)
        ax5.grid(True, alpha=0.3)
        
        # Panel F: Confusion matrix at OPTIMAL threshold (30-day lead)
        ax6 = fig.add_subplot(gs[1, 2])
        
        if 'lead_time_analysis' in skill_results:
            # Use optimal threshold data if available, else fall back to default
            opt_thresh = skill_results.get('optimal_threshold', 0.4)
            opt_key = f'{opt_thresh:.2f}'
            opt_data = skill_results.get('threshold_analysis', {}).get(opt_key, {})
            lead_30d = skill_results['lead_time_analysis'].get('30_days', {})
            
            # Recalculate CM from threshold analysis if available
            if opt_data and lead_30d:
                n = lead_30d.get('n_samples', 0)
                # At optimal threshold we have precision, recall, n_alerts
                n_alerts = opt_data.get('n_alerts', 0)
                prec = opt_data.get('precision', 0)
                rec = opt_data.get('recall', 0)
                n_pos = lead_30d.get('tp', 0) + lead_30d.get('fn', 0)  # total actual positives
                tp = int(round(rec * n_pos))
                fp = n_alerts - tp
                fn = n_pos - tp
                tn = n - tp - fp - fn
                
                cm = np.array([[tn, fp], [fn, tp]])
                precision = prec
                recall = rec
            elif lead_30d:
                cm = np.array([
                    [lead_30d.get('tn', 0), lead_30d.get('fp', 0)],
                    [lead_30d.get('fn', 0), lead_30d.get('tp', 0)]
                ])
                precision = lead_30d.get('precision', 0)
                recall = lead_30d.get('recall', 0)
                opt_thresh = 0.40
            else:
                cm = None
            
            if cm is not None:
                im = ax6.imshow(cm, cmap='Blues', aspect='auto')
                
                for i in range(2):
                    for j in range(2):
                        text_color = 'white' if cm[i, j] > cm.max()/2 else 'black'
                        ax6.text(j, i, f'{int(cm[i, j])}', ha='center', va='center',
                                color=text_color, fontsize=16, fontweight='bold')
                
                ax6.set_xticks([0, 1])
                ax6.set_yticks([0, 1])
                ax6.set_xticklabels(['No Bleach', 'Bleaching'])
                ax6.set_yticklabels(['Low pCRVI', 'High pCRVI'])
                ax6.set_xlabel('Actual (30 days ahead)', fontsize=11)
                ax6.set_ylabel('Predicted', fontsize=11)
                ax6.set_title(f'F) Confusion Matrix (threshold={opt_thresh:.2f})',
                             fontsize=11, fontweight='bold')
                
                ax6.text(0.5, -0.18, f'Precision: {precision:.1%} | Recall: {recall:.1%}',
                        transform=ax6.transAxes, ha='center', fontsize=10)
        
        # Panel G: Time series comparison (pCRVI vs DHW zoomed to event)
        ax7 = fig.add_subplot(gs[2, :])
        
        # Find the most recent bleaching year with sufficient data
        if bleaching_years:
            target_year = max(bleaching_years)
            start_date = pd.Timestamp(f'{target_year-1}-10-01')
            end_date = pd.Timestamp(f'{target_year}-08-31')
            
            # Filter data to this period
            mask_pcrvi = (pcrvi_data.index >= start_date) & (pcrvi_data.index <= end_date)
            mask_dhw = (dhw_data.index >= start_date) & (dhw_data.index <= end_date)
            
            pcrvi_zoom = pcrvi_data.loc[mask_pcrvi]
            dhw_zoom = dhw_data.loc[mask_dhw]
            
            # Primary axis: pCRVI
            color1 = '#9b59b6'
            ax7.plot(pcrvi_zoom.index, pcrvi_zoom['pcrvi'], color=color1, 
                    linewidth=2, label='pCRVI')
            ax7.fill_between(pcrvi_zoom.index, 0, pcrvi_zoom['pcrvi'], 
                            alpha=0.3, color=color1)
            ax7.axhline(y=0.4, color=color1, linestyle='--', alpha=0.7)
            ax7.set_ylabel('pCRVI Score', fontsize=11, color=color1)
            ax7.tick_params(axis='y', labelcolor=color1)
            ax7.set_ylim(0, 1)
            
            # Secondary axis: DHW
            ax7b = ax7.twinx()
            color2 = '#e74c3c'
            ax7b.plot(dhw_zoom.index, dhw_zoom['dhw'], color=color2, 
                     linewidth=2, label='DHW')
            ax7b.fill_between(dhw_zoom.index, 0, dhw_zoom['dhw'], 
                             alpha=0.2, color=color2)
            ax7b.axhline(y=4, color=color2, linestyle='--', alpha=0.7)
            ax7b.set_ylabel('DHW (°C-weeks)', fontsize=11, color=color2)
            ax7b.tick_params(axis='y', labelcolor=color2)
            
            # Mark peak season
            peak_start = pd.Timestamp(f'{target_year}-03-01')
            peak_end = pd.Timestamp(f'{target_year}-06-30')
            ax7.axvspan(peak_start, peak_end, alpha=0.1, color='orange', 
                       label='Peak season')
            
            ax7.set_xlabel('Date', fontsize=11)
            ax7.set_title(f'G) pCRVI Lead Time Analysis: {target_year} Bleaching Event', 
                         fontsize=12, fontweight='bold')
            
            # Combined legend
            lines1, labels1 = ax7.get_legend_handles_labels()
            lines2, labels2 = ax7b.get_legend_handles_labels()
            ax7.legend(lines1 + lines2, labels1 + labels2, loc='upper left', fontsize=9)
        
        ax7.grid(True, alpha=0.3)
        
        plt.suptitle('Predictive CRVI (pCRVI) Skill Assessment Dashboard', 
                    fontsize=14, fontweight='bold', y=1.01)
        
        filename = f"{prefix}pcrvi_predictive_dashboard.png" if prefix else "pcrvi_predictive_dashboard.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved pCRVI predictive dashboard: {path}")
        return path

    def plot_dhw_forecast(
        predictions_df: pd.DataFrame,
        dhw_data: pd.DataFrame,
        model_name: str = "Ensemble-pCRVI",
        figsize: Tuple[int, int] = (14, 10),
        output_path: Optional[Path] = None
    ) -> Optional[Path]:
        """
        Plot DHW forecast showing actual vs predicted values.
        
        Parameters
        ----------
        predictions_df : pd.DataFrame
            Must have columns: 'date', 'actual', 'predicted'
        dhw_data : pd.DataFrame
            Full DHW time series for context
        model_name : str
            Name of the forecasting model
        figsize : tuple
            Figure size
        output_path : Path, optional
            Where to save the figure
            
        Returns
        -------
        Path or None
            Path to saved figure
        """
        if not MATPLOTLIB_AVAILABLE:
            print("matplotlib not available")
            return None
        
        fig, axes = plt.subplots(3, 1, figsize=figsize)
        
        # Panel 1: Full time series with test period highlighted
        ax1 = axes[0]
        ax1.plot(dhw_data.index, dhw_data['dhw'], 'b-', linewidth=0.8, alpha=0.7, label='Historical DHW')
        
        # Highlight test period
        if 'date' in predictions_df.columns:
            pred_dates = pd.to_datetime(predictions_df['date'])
            test_start = pred_dates.min()
            test_end = pred_dates.max()
            ax1.axvspan(test_start, test_end, alpha=0.2, color='orange', label='Forecast Period')
        
        ax1.axhline(y=4, color='orange', linestyle='--', alpha=0.7, label='Bleaching Threshold')
        ax1.axhline(y=8, color='red', linestyle='--', alpha=0.7, label='Severe Threshold')
        ax1.set_ylabel('DHW (°C-weeks)')
        ax1.set_title(f'A) Full DHW Time Series with Forecast Period Highlighted', fontweight='bold')
        ax1.legend(loc='upper right')
        ax1.grid(True, alpha=0.3)
        
        # Panel 2: Actual vs Predicted during test period
        ax2 = axes[1]
        
        if 'date' in predictions_df.columns:
            dates = pd.to_datetime(predictions_df['date'])
        else:
            dates = predictions_df.index
        
        actual = predictions_df['actual'].values
        predicted = predictions_df['predicted'].values
        
        ax2.plot(dates, actual, 'b-', linewidth=2, label='Actual DHW', marker='o', markersize=3)
        ax2.plot(dates, predicted, 'r-', linewidth=2, label='Predicted DHW', marker='s', markersize=3)
        ax2.fill_between(dates, actual, predicted, alpha=0.3, color='gray', label='Error')
        
        ax2.axhline(y=4, color='orange', linestyle='--', alpha=0.7)
        ax2.set_ylabel('DHW (°C-weeks)')
        ax2.set_title(f'B) {model_name}: Actual vs Predicted DHW', fontweight='bold')
        ax2.legend(loc='upper right')
        ax2.grid(True, alpha=0.3)
        
        # Panel 3: Scatter plot with R² and error metrics
        ax3 = axes[2]
        
        ax3.scatter(actual, predicted, alpha=0.5, s=20, c='blue', edgecolors='none')
        
        # Perfect prediction line
        max_val = max(actual.max(), predicted.max()) * 1.1
        ax3.plot([0, max_val], [0, max_val], 'k--', linewidth=2, label='Perfect Prediction')
        
        # Calculate metrics
        mae = np.mean(np.abs(actual - predicted))
        rmse = np.sqrt(np.mean((actual - predicted)**2))
        
        # R² calculation
        ss_res = np.sum((actual - predicted)**2)
        ss_tot = np.sum((actual - np.mean(actual))**2)
        r2 = 1 - (ss_res / ss_tot) if ss_tot > 0 else 0
        
        # Add metrics text
        metrics_text = f'MAE: {mae:.3f} °C-weeks\nRMSE: {rmse:.3f} °C-weeks\nR²: {r2:.3f}'
        ax3.text(0.05, 0.95, metrics_text, transform=ax3.transAxes, fontsize=11,
                verticalalignment='top', bbox=dict(boxstyle='round', facecolor='white', alpha=0.8))
        
        # Mark bleaching threshold region
        ax3.axvline(x=4, color='orange', linestyle='--', alpha=0.5)
        ax3.axhline(y=4, color='orange', linestyle='--', alpha=0.5)
        ax3.fill_between([4, max_val], 4, max_val, alpha=0.1, color='red', label='Bleaching Zone')
        
        ax3.set_xlabel('Actual DHW (°C-weeks)')
        ax3.set_ylabel('Predicted DHW (°C-weeks)')
        ax3.set_title('C) Prediction Accuracy Scatter Plot', fontweight='bold')
        ax3.legend(loc='lower right')
        ax3.grid(True, alpha=0.3)
        ax3.set_xlim(0, max_val)
        ax3.set_ylim(0, max_val)
        
        plt.tight_layout()
        
        if output_path:
            plt.savefig(output_path, dpi=150, bbox_inches='tight')
            plt.close()
            return output_path
        else:
            plt.show()
            return None


    def plot_forecast_feature_importance(
        importance_df: pd.DataFrame,
        model_name: str = "Ensemble-pCRVI",
        top_n: int = 15,
        figsize: Tuple[int, int] = (10, 8),
        output_path: Optional[Path] = None
    ) -> Optional[Path]:
        """
        Plot feature importance for DHW forecaster.
        
        Parameters
        ----------
        importance_df : pd.DataFrame
            Must have columns: 'feature', 'importance'
        model_name : str
            Model name for title
        top_n : int
            Number of top features to show
        figsize : tuple
            Figure size
        output_path : Path, optional
            Where to save
        """
        if not MATPLOTLIB_AVAILABLE:
            return None
        
        # Get top N features
        top_features = importance_df.nlargest(top_n, 'importance')
        
        fig, ax = plt.subplots(figsize=figsize)
        
        # Create horizontal bar chart
        y_pos = np.arange(len(top_features))
        colors = plt.cm.viridis(top_features['importance'] / top_features['importance'].max())
        
        bars = ax.barh(y_pos, top_features['importance'], color=colors)
        ax.set_yticks(y_pos)
        ax.set_yticklabels(top_features['feature'].map(friendly_name))
        ax.invert_yaxis()  # Top feature at top
        
        ax.set_xlabel('Importance Score')
        ax.set_title(f'{model_name}: Feature Importance for DHW Prediction', fontweight='bold')
        
        # Add value labels
        for i, (bar, val) in enumerate(zip(bars, top_features['importance'])):
            ax.text(val + 0.005, bar.get_y() + bar.get_height()/2, 
                    f'{val:.3f}', va='center', fontsize=9)
        
        # Add annotation explaining key features
        annotation = (
            "Key Features:\n"
            f"  • {label('pcrvi', 'full')}\n"
            f"  • {label('chlorophyll', 'full')}\n"
            f"  • {label('turbidity', 'full')}\n"
            f"  • {label('la_norm', 'full')}\n"
            f"  • {label('oni', 'full')}\n"
            f"  • {label('dmi', 'full')}"
        )
        ax.text(0.98, 0.02, annotation.strip(), transform=ax.transAxes, fontsize=8,
                verticalalignment='bottom', horizontalalignment='right',
                bbox=dict(boxstyle='round', facecolor='lightyellow', alpha=0.8))
        
        plt.tight_layout()
        
        if output_path:
            plt.savefig(output_path, dpi=150, bbox_inches='tight')
            plt.close()
            return output_path
        else:
            plt.show()
            return None


    def plot_forecast_model_comparison(
        comparison_df: pd.DataFrame,
        figsize: Tuple[int, int] = (14, 8),
        output_path: Optional[Path] = None
    ) -> Optional[Path]:
        """
        Plot model comparison for DHW time series forecasting.
        
        This REPLACES the old classification model comparison that showed
        RF/XGBoost etc. with their misleading 98% accuracy.
        
        Parameters
        ----------
        comparison_df : pd.DataFrame
            From DHWTimeSeriesForecaster.compare_models()
            Columns: Model, mae, rmse, r2, bl_f1, bl_precision, bl_recall
        figsize : tuple
            Figure size
        output_path : Path, optional
            Where to save
        """
        if not MATPLOTLIB_AVAILABLE:
            return None
        
        if comparison_df is None or len(comparison_df) == 0:
            return None
        
        fig, axes = plt.subplots(1, 3, figsize=figsize)
        
        models = comparison_df['Model'].values
        x = np.arange(len(models))
        
        # Panel 1: Regression metrics (MAE, RMSE)
        ax1 = axes[0]
        width = 0.35
        
        mae_vals = comparison_df.get('mae', pd.Series([0]*len(models))).values
        rmse_vals = comparison_df.get('rmse', pd.Series([0]*len(models))).values
        
        bars1 = ax1.bar(x - width/2, mae_vals, width, label='MAE', color='#3498db')
        bars2 = ax1.bar(x + width/2, rmse_vals, width, label='RMSE', color='#e74c3c')
        
        ax1.set_xlabel('Model')
        ax1.set_ylabel('Error (°C-weeks)')
        ax1.set_title('A) Prediction Error (Lower = Better)', fontweight='bold')
        ax1.set_xticks(x)
        ax1.set_xticklabels(models, rotation=45, ha='right')
        ax1.legend()
        ax1.grid(True, alpha=0.3, axis='y')
        
        # Add value labels
        for bar in bars1:
            ax1.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.01,
                    f'{bar.get_height():.2f}', ha='center', va='bottom', fontsize=9)
        
        # Panel 2: R² (coefficient of determination)
        ax2 = axes[1]
        r2_vals = comparison_df.get('r2', pd.Series([0]*len(models))).values
        
        colors = ['#27ae60' if v > 0.5 else '#f39c12' if v > 0 else '#e74c3c' for v in r2_vals]
        bars3 = ax2.bar(x, r2_vals, color=colors)
        
        ax2.set_xlabel('Model')
        ax2.set_ylabel('R² Score')
        ax2.set_title('B) Explained Variance (Higher = Better)', fontweight='bold')
        ax2.set_xticks(x)
        ax2.set_xticklabels(models, rotation=45, ha='right')
        ax2.set_ylim(0, 1)
        ax2.axhline(y=0.5, color='gray', linestyle='--', alpha=0.5, label='R²=0.5')
        ax2.legend()
        ax2.grid(True, alpha=0.3, axis='y')
        
        for bar in bars3:
            ax2.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.02,
                    f'{bar.get_height():.2f}', ha='center', va='bottom', fontsize=9)
        
        # Panel 3: Bleaching detection metrics
        ax3 = axes[2]
        
        bl_f1 = comparison_df.get('bl_f1', pd.Series([0]*len(models))).values
        bl_prec = comparison_df.get('bl_precision', pd.Series([0]*len(models))).values
        bl_rec = comparison_df.get('bl_recall', pd.Series([0]*len(models))).values
        
        width = 0.25
        bars4 = ax3.bar(x - width, bl_prec, width, label='Precision', color='#9b59b6')
        bars5 = ax3.bar(x, bl_rec, width, label='Recall', color='#1abc9c')
        bars6 = ax3.bar(x + width, bl_f1, width, label='F1 Score', color='#e74c3c')
        
        ax3.set_xlabel('Model')
        ax3.set_ylabel('Score')
        ax3.set_title('C) Bleaching Detection (F1 = Key Metric)', fontweight='bold')
        ax3.set_xticks(x)
        ax3.set_xticklabels(models, rotation=45, ha='right')
        ax3.set_ylim(0, 1.1)
        ax3.legend(loc='upper left')
        ax3.grid(True, alpha=0.3, axis='y')
        
        # Highlight best F1
        best_idx = np.argmax(bl_f1)
        ax3.annotate('✓ Best', xy=(best_idx + width, bl_f1[best_idx]), 
                    xytext=(best_idx + width + 0.3, bl_f1[best_idx] + 0.1),
                    fontsize=10, color='green', fontweight='bold',
                    arrowprops=dict(arrowstyle='->', color='green'))
        
        plt.suptitle('DHW Time Series Forecasting: Model Comparison', 
                    fontsize=14, fontweight='bold', y=1.02)
        
        plt.tight_layout()
        
        if output_path:
            plt.savefig(output_path, dpi=150, bbox_inches='tight')
            plt.close()
            return output_path
        else:
            plt.show()
            return None


    def plot_forecast_vs_old_classification(
        forecast_comparison: pd.DataFrame,
        old_classification_df: Optional[pd.DataFrame] = None,
        figsize: Tuple[int, int] = (14, 6),
        output_path: Optional[Path] = None
    ) -> Optional[Path]:
        """
        Compare new forecasting approach with old classification approach.
        
        Shows why the old approach (RF/XGBoost classification) failed and
        how the new approach (Ensemble-pCRVI regression) succeeds.
        
        Parameters
        ----------
        forecast_comparison : pd.DataFrame
            New forecaster results
        old_classification_df : pd.DataFrame, optional
            Old model comparison with RF/XGBoost etc.
            If None, uses hardcoded example values
        """
        if not MATPLOTLIB_AVAILABLE:
            return None
        
        fig, axes = plt.subplots(1, 2, figsize=figsize)
        
        # Panel 1: Old classification models (showing they fail)
        ax1 = axes[0]
        
        if old_classification_df is not None:
            models = old_classification_df['model'].values
            f1_scores = old_classification_df.get('f1_score', pd.Series([0]*len(models))).values
        else:
            # Typical values from old approach
            models = ['Logistic Regression', 'Random Forest', 'Gradient Boosting', 'XGBoost']
            f1_scores = [0.0, 0.0, 0.33, 0.0]  # They predict everything as 0
        
        x1 = np.arange(len(models))
        colors1 = ['#e74c3c' if v < 0.1 else '#f39c12' for v in f1_scores]
        bars1 = ax1.bar(x1, f1_scores, color=colors1)
        
        ax1.set_xlabel('Model')
        ax1.set_ylabel('Bleaching F1 Score')
        ax1.set_title('OLD: Classification Models\n(Predict Everything as "No Bleaching")', 
                    fontweight='bold', color='#e74c3c')
        ax1.set_xticks(x1)
        ax1.set_xticklabels(models, rotation=45, ha='right')
        ax1.set_ylim(0, 1)
        ax1.axhline(y=0.5, color='gray', linestyle='--', alpha=0.5)
        ax1.grid(True, alpha=0.3, axis='y')
        
        # Add "FAILED" annotation
        ax1.text(0.5, 0.8, '❌ FAILED\nF1 ≈ 0', transform=ax1.transAxes,
                fontsize=14, color='#e74c3c', fontweight='bold',
                ha='center', va='center',
                bbox=dict(boxstyle='round', facecolor='#ffebee', edgecolor='#e74c3c'))
        
        # Panel 2: New forecasting models
        ax2 = axes[1]
        
        models2 = forecast_comparison['Model'].values
        f1_scores2 = forecast_comparison.get('bl_f1', pd.Series([0]*len(models2))).values
        
        x2 = np.arange(len(models2))
        colors2 = ['#27ae60' if v > 0.5 else '#f39c12' for v in f1_scores2]
        bars2 = ax2.bar(x2, f1_scores2, color=colors2)
        
        ax2.set_xlabel('Model')
        ax2.set_ylabel('Bleaching F1 Score')
        ax2.set_title('NEW: Time Series Forecasting\n(Predicts Actual DHW Values)', 
                    fontweight='bold', color='#27ae60')
        ax2.set_xticks(x2)
        ax2.set_xticklabels(models2, rotation=45, ha='right')
        ax2.set_ylim(0, 1)
        ax2.axhline(y=0.5, color='gray', linestyle='--', alpha=0.5)
        ax2.grid(True, alpha=0.3, axis='y')
        
        # Add "SUCCESS" annotation
        best_f1 = max(f1_scores2)
        ax2.text(0.5, 0.8, f'✓ SUCCESS\nF1 = {best_f1:.2f}', transform=ax2.transAxes,
                fontsize=14, color='#27ae60', fontweight='bold',
                ha='center', va='center',
                bbox=dict(boxstyle='round', facecolor='#e8f5e9', edgecolor='#27ae60'))
        
        plt.suptitle('Why We Switched from Classification to Time Series Forecasting', 
                    fontsize=14, fontweight='bold', y=1.02)
        
        plt.tight_layout()
        
        if output_path:
            plt.savefig(output_path, dpi=150, bbox_inches='tight')
            plt.close()
            return output_path
        else:
            plt.show()
            return None


    def create_forecast_dashboard(
        forecaster,
        dhw_data: pd.DataFrame,
        pcrvi_data: pd.DataFrame,
        figsize: Tuple[int, int] = (16, 12),
        output_path: Optional[Path] = None
    ) -> Optional[Path]:
        """
        Create comprehensive dashboard for DHW forecasting results.
        
        Parameters
        ----------
        forecaster : DHWTimeSeriesForecaster
            Fitted forecaster with results
        dhw_data : pd.DataFrame
            DHW time series
        pcrvi_data : pd.DataFrame
            pCRVI time series
        """
        if not MATPLOTLIB_AVAILABLE:
            return None
        
        fig = plt.figure(figsize=figsize)
        
        # Create grid
        gs = fig.add_gridspec(3, 3, hspace=0.3, wspace=0.3)
        
        # Get best model results
        best_model_key = None
        best_f1 = 0
        for key, info in forecaster.models.items():
            if 'metrics' in info:
                f1 = info['metrics'].get('bl_f1', 0)
                if f1 > best_f1:
                    best_f1 = f1
                    best_model_key = key
        
        if best_model_key is None:
            return None
        
        best_info = forecaster.models[best_model_key]
        predictions = best_info.get('predictions', pd.DataFrame())
        importance = best_info.get('feature_importance', pd.DataFrame())
        metrics = best_info.get('metrics', {})
        
        # Panel A: DHW Time series with predictions
        ax1 = fig.add_subplot(gs[0, :2])
        ax1.plot(dhw_data.index, dhw_data['dhw'], 'b-', linewidth=0.8, alpha=0.6, label='Historical')
        
        if not predictions.empty:
            pred_dates = pd.to_datetime(predictions['date'])
            ax1.plot(pred_dates, predictions['actual'], 'g-', linewidth=2, label='Actual (Test)')
            ax1.plot(pred_dates, predictions['predicted'], 'r--', linewidth=2, label='Predicted')
        
        ax1.axhline(y=4, color='orange', linestyle='--', alpha=0.5)
        ax1.set_ylabel('DHW (°C-weeks)')
        ax1.set_title(f'A) DHW Forecast: {best_info["name"]}', fontweight='bold')
        ax1.legend(loc='upper right')
        ax1.grid(True, alpha=0.3)
        
        # Panel B: Metrics summary
        ax2 = fig.add_subplot(gs[0, 2])
        ax2.axis('off')
        
        metrics_text = f"""
    Model: {best_info['name']}

    REGRESSION METRICS:
    MAE:  {metrics.get('mae', 0):.3f} °C-weeks
    RMSE: {metrics.get('rmse', 0):.3f} °C-weeks
    R²:   {metrics.get('r2', 0):.3f}

    BLEACHING DETECTION:
    F1:        {metrics.get('bl_f1', 0):.3f}
    Precision: {metrics.get('bl_precision', 0):.3f}
    Recall:    {metrics.get('bl_recall', 0):.3f}
    
    TP: {metrics.get('tp', 0)}  FP: {metrics.get('fp', 0)}
    FN: {metrics.get('fn', 0)}  TN: {metrics.get('tn', 0)}
        """
        ax2.text(0.1, 0.9, metrics_text, transform=ax2.transAxes, fontsize=10,
                verticalalignment='top', fontfamily='monospace',
                bbox=dict(boxstyle='round', facecolor='#f0f0f0', alpha=0.8))
        ax2.set_title('B) Model Performance', fontweight='bold')
        
        # Panel C: Feature importance
        ax3 = fig.add_subplot(gs[1, :2])
        if not importance.empty:
            top_feat = importance.head(10)
            y_pos = np.arange(len(top_feat))
            ax3.barh(y_pos, top_feat['importance'], color='#667eea')
            ax3.set_yticks(y_pos)
            ax3.set_yticklabels(top_feat['feature'])
            ax3.invert_yaxis()
            ax3.set_xlabel('Importance')
        ax3.set_title('C) Top Predictive Features', fontweight='bold')
        ax3.grid(True, alpha=0.3, axis='x')
        
        # Panel D: Scatter plot
        ax4 = fig.add_subplot(gs[1, 2])
        if not predictions.empty:
            ax4.scatter(predictions['actual'], predictions['predicted'], alpha=0.5, s=20)
            max_val = max(predictions['actual'].max(), predictions['predicted'].max()) * 1.1
            ax4.plot([0, max_val], [0, max_val], 'k--', linewidth=1)
            ax4.axvline(x=4, color='orange', linestyle='--', alpha=0.3)
            ax4.axhline(y=4, color='orange', linestyle='--', alpha=0.3)
            ax4.set_xlabel('Actual DHW')
            ax4.set_ylabel('Predicted DHW')
            ax4.set_xlim(0, max_val)
            ax4.set_ylim(0, max_val)
        ax4.set_title('D) Prediction Accuracy', fontweight='bold')
        ax4.grid(True, alpha=0.3)
        
        # Panel E: pCRVI vs DHW relationship
        ax5 = fig.add_subplot(gs[2, :])
        
        # Align data
        common_idx = dhw_data.index.intersection(pcrvi_data.index)
        dhw_aligned = dhw_data.loc[common_idx, 'dhw']
        pcrvi_aligned = pcrvi_data.loc[common_idx, 'pcrvi']
        
        ax5_twin = ax5.twinx()
        
        ax5.plot(common_idx, pcrvi_aligned, color='#9b59b6', linewidth=1, label='pCRVI')
        ax5_twin.plot(common_idx, dhw_aligned, color='#e74c3c', linewidth=1, alpha=0.7, label='DHW')
        
        ax5.set_ylabel('pCRVI', color='#9b59b6')
        ax5_twin.set_ylabel('DHW (°C-weeks)', color='#e74c3c')
        ax5.set_xlabel('Date')
        ax5.set_title('E) pCRVI Leading Indicator vs DHW', fontweight='bold')
        
        # Combined legend
        lines1, labels1 = ax5.get_legend_handles_labels()
        lines2, labels2 = ax5_twin.get_legend_handles_labels()
        ax5.legend(lines1 + lines2, labels1 + labels2, loc='upper right')
        ax5.grid(True, alpha=0.3)
        
        plt.suptitle('DHW Time Series Forecasting Dashboard', fontsize=16, fontweight='bold', y=1.01)
        
        if output_path:
            plt.savefig(output_path, dpi=150, bbox_inches='tight')
            plt.close()
            return output_path
        else:
            plt.show()
            return None

    def plot_pcrvi_vs_old_crvi(
        self,
        pcrvi_data: pd.DataFrame,
        old_crvi_data: pd.DataFrame,
        dhw_data: pd.DataFrame,
        figsize: Tuple[int, int] = (16, 10),
        historical_events: Optional[Dict[int, Dict]] = None,
        prefix: str = ""
    ) -> Path:
        """
        Compare Predictive CRVI with old retrospective CRVI.
        
        Parameters
        ----------
        pcrvi_data : pd.DataFrame
            New Predictive CRVI time series
        old_crvi_data : pd.DataFrame
            Old retrospective CRVI time series
        dhw_data : pd.DataFrame
            DHW time series
        figsize : tuple
            Figure size
        historical_events : dict, optional
            Known historical bleaching events {year: {'severity': ..., 'bleaching_pct': ...}}
        prefix : str
            Filename prefix
        
        Returns
        -------
        Path
            Path to saved figure
        """
        fig, axes = plt.subplots(3, 1, figsize=figsize, sharex=True)
        
        # Panel 1: Both CRVI indices
        ax1 = axes[0]
        
        ax1.plot(pcrvi_data.index, pcrvi_data['pcrvi'], 
                 color='#9b59b6', linewidth=2, label='New: Predictive CRVI')
        
        if 'crvi' in old_crvi_data.columns:
            ax1.plot(old_crvi_data.index, old_crvi_data['crvi'], 
                    color='#95a5a6', linewidth=2, linestyle='--', label='Old: Retrospective CRVI')
        
        # Mark bleaching events
        dhw_copy = dhw_data.copy()
        dhw_copy['year'] = dhw_copy.index.year
        annual_max = dhw_copy.groupby('year')['dhw'].max()
        
        # Use historical_events if provided, else compute from DHW
        if historical_events:
            data_min_year = int(pcrvi_data.index.min().year)
            data_max_year = int(pcrvi_data.index.max().year)
            bleaching_years = [y for y in historical_events.keys()
                               if data_min_year <= y <= data_max_year]
        else:
            bleaching_years = annual_max[annual_max >= 4].index.tolist()
        
        for year in bleaching_years:
            event_date = pd.Timestamp(f'{year}-05-15')
            if pcrvi_data.index.min() <= event_date <= pcrvi_data.index.max():
                ax1.axvline(x=event_date, color='red', linestyle='-', linewidth=2, alpha=0.5)
        
        ax1.axhline(y=0.4, color='black', linestyle=':', alpha=0.5)
        ax1.set_ylabel('CRVI Score', fontsize=11)
        ax1.set_title('A) Comparison: Predictive vs Retrospective CRVI', fontsize=12, fontweight='bold')
        ax1.set_ylim(0, 1)
        ax1.legend(loc='upper right', fontsize=10)
        ax1.grid(True, alpha=0.3)
        
        # Panel 2: DHW for reference
        ax2 = axes[1]
        ax2.fill_between(dhw_data.index, 0, dhw_data['dhw'], alpha=0.4, color='coral')
        ax2.plot(dhw_data.index, dhw_data['dhw'], color='red', linewidth=0.8)
        ax2.axhline(y=4, color='orange', linestyle='--', label='Warning')
        ax2.axhline(y=8, color='red', linestyle='--', label='Alert')
        ax2.set_ylabel('DHW (°C-weeks)', fontsize=11)
        ax2.set_title('B) DHW Time Series (Bleaching Indicator)', fontsize=12, fontweight='bold')
        ax2.legend(loc='upper right', fontsize=10)
        ax2.grid(True, alpha=0.3)
        
        # Panel 3: Difference (pCRVI - old CRVI)
        ax3 = axes[2]
        
        if 'crvi' in old_crvi_data.columns:
            # Align indices
            common_idx = pcrvi_data.index.intersection(old_crvi_data.index)
            diff = pcrvi_data.loc[common_idx, 'pcrvi'] - old_crvi_data.loc[common_idx, 'crvi']
            
            ax3.fill_between(common_idx, 0, diff, where=diff > 0, 
                            color='#27ae60', alpha=0.5, label='pCRVI > old (earlier warning)')
            ax3.fill_between(common_idx, 0, diff, where=diff < 0,
                            color='#e74c3c', alpha=0.5, label='pCRVI < old')
            ax3.plot(common_idx, diff, color='black', linewidth=0.5)
            
            for year in bleaching_years:
                ax3.axvline(x=pd.Timestamp(f'{year}-05-15'), color='red',
                           linestyle='-', linewidth=2, alpha=0.5)
        
        ax3.axhline(y=0, color='black', linestyle='-', linewidth=1)
        ax3.set_ylabel('Difference (pCRVI - old)', fontsize=11)
        ax3.set_xlabel('Date', fontsize=11)
        ax3.set_title('C) Improvement: Positive = Earlier Warning Signal', fontsize=12, fontweight='bold')
        ax3.legend(loc='upper right', fontsize=10)
        ax3.grid(True, alpha=0.3)
        
        plt.tight_layout()
        
        filename = f"{prefix}pcrvi_comparison.png" if prefix else "pcrvi_comparison.png"
        path = self.output_dir / filename
        plt.savefig(path, dpi=150, bbox_inches='tight')
        plt.close()
        
        self.logger.info(f"Saved pCRVI comparison plot: {path}")
        return path
