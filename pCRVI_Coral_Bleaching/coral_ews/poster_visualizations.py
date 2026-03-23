"""
Publication-Quality Poster & Slide Visualizations
==================================================

All plots are designed for:
  - 4 ft × 3 ft (48" × 36") landscape poster at 300 DPI
  - 16:9 slide decks
  - Tier 1 conference standards (AGU, EGU, ICRS style)

Design principles:
  - High-contrast colormaps (colourblind-safe: viridis, cividis, RdYlBu_r)
  - Large font sizes (poster: 18-28 pt; slides: 14-22 pt)
  - Publication-grade axis labels with units
  - NOAA CRW-style alert colour scheme
  - Minimal chartjunk; data-to-ink ratio maximised (Tufte)

Usage:
    from coral_ews.poster_visualizations import PosterVisualizer

    pv = PosterVisualizer(output_dir=Path('output/poster'))
    pv.plot_pcrvi_7component_dashboard(pcrvi_ts, dhw_data)
    pv.plot_weekly_risk_heatmap(weekly_df)
    pv.plot_ml_weight_comparison(opt_results)
    pv.plot_historical_validation_panel(pcrvi_ts, dhw_data, known_events)
    pv.plot_component_contribution_stacked(pcrvi_ts)
    pv.plot_skill_leadtime_bars(skill_results)
"""

from typing import Optional, Dict, Any, List, Tuple
from pathlib import Path
from datetime import datetime

import numpy as np
import pandas as pd

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import matplotlib.gridspec as gridspec
import matplotlib.patches as mpatches
import matplotlib.colors as mcolors
from matplotlib.ticker import MaxNLocator, FuncFormatter
from matplotlib.lines import Line2D

# ---- style constants ----
# NOAA CRW-inspired alert palette
ALERT_COLORS = {
    'Critical': '#8B0000',
    'High': '#FF4500',
    'Moderate': '#FFA500',
    'Low': '#FFD700',
    'Minimal': '#228B22',
}

from .naming import (
    COMPONENT_COLORS, COMPONENT_LABELS, WEIGHT_LABELS,
    label, label_with_units, friendly_name,
)


def _apply_poster_style():
    """Apply poster-grade matplotlib rcParams."""
    plt.rcParams.update({
        'font.family': 'sans-serif',
        'font.sans-serif': ['DejaVu Sans', 'Arial', 'Helvetica'],
        'font.size': 18,
        'axes.titlesize': 24,
        'axes.labelsize': 20,
        'xtick.labelsize': 16,
        'ytick.labelsize': 16,
        'legend.fontsize': 16,
        'figure.titlesize': 28,
        'lines.linewidth': 2.0,
        'axes.linewidth': 1.5,
        'xtick.major.width': 1.2,
        'ytick.major.width': 1.2,
        'axes.grid': True,
        'grid.alpha': 0.3,
        'grid.linewidth': 0.8,
        'figure.dpi': 150,
        'savefig.dpi': 300,
        'savefig.bbox': 'tight',
        'savefig.pad_inches': 0.3,
    })


def _apply_slide_style():
    """Apply slide-grade matplotlib rcParams (16:9)."""
    plt.rcParams.update({
        'font.family': 'sans-serif',
        'font.size': 14,
        'axes.titlesize': 20,
        'axes.labelsize': 16,
        'xtick.labelsize': 12,
        'ytick.labelsize': 12,
        'legend.fontsize': 13,
        'figure.titlesize': 22,
        'lines.linewidth': 2.0,
        'axes.linewidth': 1.2,
        'axes.grid': True,
        'grid.alpha': 0.3,
        'figure.dpi': 150,
        'savefig.dpi': 200,
        'savefig.bbox': 'tight',
    })


def _add_bleaching_events(ax, known_events: Dict[int, Dict], ymin=0, ymax=1):
    """Overlay known bleaching event markers on any time-series axis."""
    for year, info in known_events.items():
        month = info.get('peak_month', 5)
        dt = pd.Timestamp(f"{year}-{month:02d}-15")
        severity = info.get('severity', 'unknown')
        color = ('#8B0000' if severity in ['catastrophic', 'severe']
                 else '#FF4500' if severity == 'moderate'
                 else '#FFA500')
        ax.axvline(dt, color=color, alpha=0.5, linewidth=1.5, linestyle='--')
        ax.text(dt, ymax * 0.97, str(year), ha='center', va='top',
                fontsize=11, fontweight='bold', color=color, rotation=90)


class PosterVisualizer:
    """Publication-quality visualization generator.
    
    Parameters
    ----------
    output_dir : Path
        Directory for saving plots.
    known_events : dict, optional
        Historical bleaching events {year: {severity, dhw_reported, ...}}.
    region_name : str, optional
        Region name for plot titles (generalizable to any reef region).
    """

    def __init__(self, output_dir: Path, known_events: Optional[Dict] = None,
                 region_name: str = "Andaman & Nicobar Islands"):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.known_events = known_events or {}
        self.region_name = region_name

    # ------------------------------------------------------------------
    # 1. MAIN DASHBOARD: 7-Component pCRVI Time Series
    # ------------------------------------------------------------------
    def plot_pcrvi_7component_dashboard(
        self,
        pcrvi_ts: pd.DataFrame,
        dhw_data: pd.DataFrame,
        title: str = None,
        save_poster: bool = True,
        save_slide: bool = True,
    ) -> Dict[str, Path]:
        """
        4-panel dashboard:
          (a) pCRVI time series with risk-category shading
          (b) DHW overlay with NOAA alert levels
          (c) Stacked component contributions
          (d) Seasonal pattern heatmap (month × year)
        """
        paths: Dict[str, Path] = {}

        if title is None:
            yr_start = pcrvi_ts.index.year.min()
            yr_end = pcrvi_ts.index.year.max()
            title = (f"Enhanced-pCRVI: 7-Component Bleaching Early Warning Index\n"
                     f"{self.region_name} ({yr_start}–{yr_end})")

        for mode in (['poster'] if save_poster else []) + (['slide'] if save_slide else []):
            if mode == 'poster':
                _apply_poster_style()
                fig = plt.figure(figsize=(48, 30))  # poster proportions
            else:
                _apply_slide_style()
                fig = plt.figure(figsize=(16, 9))

            gs = gridspec.GridSpec(2, 2, hspace=0.30, wspace=0.25)

            # Panel (a): pCRVI time series
            ax_a = fig.add_subplot(gs[0, 0])
            ax_a.fill_between(pcrvi_ts.index, 0, 1, where=pcrvi_ts['pcrvi'] >= 0.70,
                              color=ALERT_COLORS['Critical'], alpha=0.20, label='Critical')
            ax_a.fill_between(pcrvi_ts.index, 0, 1, 
                              where=(pcrvi_ts['pcrvi'] >= 0.55) & (pcrvi_ts['pcrvi'] < 0.70),
                              color=ALERT_COLORS['High'], alpha=0.15, label='High')
            ax_a.plot(pcrvi_ts.index, pcrvi_ts['pcrvi'], color='#1a1a2e', linewidth=1.5)
            ax_a.set_ylabel('pCRVI Score')
            ax_a.set_ylim(0, 1)
            ax_a.set_title('(a) Enhanced-pCRVI Time Series')
            _add_bleaching_events(ax_a, self.known_events)
            ax_a.legend(loc='upper left', framealpha=0.8)

            # Panel (b): DHW with NOAA alert levels
            ax_b = fig.add_subplot(gs[0, 1])
            dhw_aligned = dhw_data.reindex(pcrvi_ts.index)
            if 'dhw' in dhw_aligned.columns:
                ax_b.fill_between(dhw_aligned.index, 0, dhw_aligned['dhw'],
                                  color='#D62728', alpha=0.35)
                ax_b.plot(dhw_aligned.index, dhw_aligned['dhw'], color='#D62728', linewidth=1.2)
            # NOAA alert thresholds
            for level, val, col in [('Alert 2', 8, '#8B0000'), ('Alert 1', 4, '#FF4500'),
                                     ('Watch', 1, '#FFA500')]:
                ax_b.axhline(val, color=col, linestyle='--', linewidth=1.0, alpha=0.7)
                ax_b.text(dhw_aligned.index[-1], val + 0.3, level, color=col,
                          fontsize=11, va='bottom', ha='right')
            ax_b.set_ylabel('DHW (°C-weeks)')
            ax_b.set_title('(b) Degree Heating Weeks with NOAA Alert Levels')
            _add_bleaching_events(ax_b, self.known_events, ymax=dhw_aligned['dhw'].max() * 1.1 if 'dhw' in dhw_aligned.columns else 12)

            # Panel (c): Stacked component contributions
            ax_c = fig.add_subplot(gs[1, 0])
            comp_cols = ['ta_norm', 'as_norm', 'sr_norm', 'cdr_norm', 'bh_norm', 'wq_norm', 'la_norm']
            available = [c for c in comp_cols if c in pcrvi_ts.columns]
            if available:
                # Monthly resample for readability
                monthly = pcrvi_ts[available].resample('ME').mean()
                bottom = np.zeros(len(monthly))
                for col in available:
                    vals = monthly[col].fillna(0).values
                    ax_c.bar(monthly.index, vals, bottom=bottom, width=25,
                             color=COMPONENT_COLORS.get(col, '#999'), alpha=0.85,
                             label=COMPONENT_LABELS.get(col, col))
                    bottom += vals
            ax_c.set_ylabel('Component Contribution')
            ax_c.set_title('(c) Monthly Component Contributions (Stacked)')
            ax_c.legend(loc='upper left', ncol=2, fontsize=10 if mode == 'slide' else 14,
                        framealpha=0.8)

            # Panel (d): Seasonal heatmap (month × year)
            ax_d = fig.add_subplot(gs[1, 1])
            pcrvi_ts_copy = pcrvi_ts.copy()
            pcrvi_ts_copy['year'] = pcrvi_ts_copy.index.year
            pcrvi_ts_copy['month'] = pcrvi_ts_copy.index.month
            pivot = pcrvi_ts_copy.pivot_table(values='pcrvi', index='year',
                                               columns='month', aggfunc='mean')
            if not pivot.empty:
                im = ax_d.imshow(pivot.values, aspect='auto', cmap='RdYlBu_r',
                                  vmin=0, vmax=0.8, interpolation='nearest')
                ax_d.set_yticks(range(len(pivot.index)))
                ax_d.set_yticklabels(pivot.index)
                month_labels = ['J', 'F', 'M', 'A', 'M', 'J',
                                'J', 'A', 'S', 'O', 'N', 'D']
                ax_d.set_xticks(range(12))
                ax_d.set_xticklabels(month_labels)
                ax_d.set_title('(d) Seasonal Risk Heatmap (pCRVI)')
                plt.colorbar(im, ax=ax_d, shrink=0.8, label='pCRVI')

            fig.suptitle(title, fontsize=28 if mode == 'poster' else 20,
                         fontweight='bold', y=0.98)

            fname = f"pcrvi_dashboard_{mode}.png"
            path = self.output_dir / fname
            fig.savefig(path, dpi=300, bbox_inches="tight")
            plt.close(fig)
            paths[f'dashboard_{mode}'] = path

        return paths

    # ------------------------------------------------------------------
    # 2. WEEKLY RISK HEATMAP
    # ------------------------------------------------------------------
    def plot_weekly_risk_heatmap(
        self,
        weekly_df: pd.DataFrame,
        save_poster: bool = True,
    ) -> Path:
        """Year × Week heatmap of weekly risk layers."""
        _apply_poster_style() if save_poster else _apply_slide_style()

        weekly_df = weekly_df.copy()
        weekly_df['date'] = pd.to_datetime(weekly_df['week_start'])
        weekly_df['year'] = weekly_df['date'].dt.year
        weekly_df['week'] = weekly_df['date'].dt.isocalendar().week.astype(int)

        pivot = weekly_df.pivot_table(values='pcrvi_max', index='year',
                                      columns='week', aggfunc='max')

        fig, ax = plt.subplots(figsize=(24 if save_poster else 14, 10 if save_poster else 6))

        cmap = mcolors.LinearSegmentedColormap.from_list(
            'risk', ['#228B22', '#FFD700', '#FFA500', '#FF4500', '#8B0000'])
        im = ax.imshow(pivot.values, aspect='auto', cmap=cmap, vmin=0, vmax=0.85,
                        interpolation='nearest')

        ax.set_yticks(range(len(pivot.index)))
        ax.set_yticklabels(pivot.index)
        ax.set_xlabel('Week of Year')
        ax.set_ylabel('Year')
        ax.set_title(f'Weekly Bleaching Stress Risk Layers — {self.region_name}',
                      fontsize=22 if save_poster else 16, fontweight='bold')

        # Mark peak season (weeks 13-26 ≈ April-June)
        ax.axvline(13, color='white', linewidth=2, linestyle='--', alpha=0.7)
        ax.axvline(26, color='white', linewidth=2, linestyle='--', alpha=0.7)
        ax.text(19.5, -0.5, 'Peak Season', ha='center', va='bottom',
                fontsize=14, color='white', fontweight='bold',
                bbox=dict(boxstyle='round,pad=0.3', facecolor='#FF4500', alpha=0.8))

        plt.colorbar(im, ax=ax, shrink=0.7, label='pCRVI (max)', pad=0.02)

        path = self.output_dir / "weekly_risk_heatmap.png"
        fig.savefig(path, dpi=300, bbox_inches="tight")
        plt.close(fig)
        return path

    # ------------------------------------------------------------------
    # 3. ML vs EXPERT WEIGHT COMPARISON
    # ------------------------------------------------------------------
    def plot_ml_weight_comparison(
        self,
        opt_results: Dict[str, Any],
    ) -> Path:
        """Side-by-side bar chart of expert vs ML-derived weights."""
        _apply_poster_style()

        if 'ml_weights' not in opt_results or 'expert_weights' not in opt_results:
            return Path()

        names = list(opt_results['expert_weights'].keys())
        expert_vals = [opt_results['expert_weights'][n] for n in names]
        ml_vals = [opt_results['ml_weights'][n] for n in names]
        labels = [WEIGHT_LABELS.get(n, n) for n in names]

        x = np.arange(len(names))
        width = 0.35

        fig, ax = plt.subplots(figsize=(14, 8))
        bars1 = ax.bar(x - width / 2, expert_vals, width, color='#1F77B4',
                        label='Expert Weights (Literature)', alpha=0.85, edgecolor='black')
        bars2 = ax.bar(x + width / 2, ml_vals, width, color='#FF7F0E',
                        label='ML-Optimized Weights (XGBoost)', alpha=0.85, edgecolor='black')

        ax.set_xticks(x)
        ax.set_xticklabels(labels, fontsize=16)
        ax.set_ylabel('Weight', fontsize=18)
        ax.set_title('Expert vs ML-Optimized pCRVI Component Weights',
                      fontsize=22, fontweight='bold')
        ax.legend(fontsize=16)
        ax.set_ylim(0, max(max(expert_vals), max(ml_vals)) * 1.25)

        # Add value labels on bars
        for bar in bars1:
            ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.005,
                    f'{bar.get_height():.3f}', ha='center', va='bottom', fontsize=12)
        for bar in bars2:
            ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.005,
                    f'{bar.get_height():.3f}', ha='center', va='bottom', fontsize=12)

        # Add R² annotation
        metrics = opt_results.get('model_metrics', {})
        r2 = metrics.get('mean_r2', metrics.get('r2', None))
        if r2 is not None:
            ax.text(0.98, 0.95, f'XGBoost R² = {r2:.3f}', transform=ax.transAxes,
                    ha='right', va='top', fontsize=15,
                    bbox=dict(boxstyle='round,pad=0.4', facecolor='lightyellow',
                              edgecolor='gray'))

        path = self.output_dir / "ml_weight_comparison.png"
        fig.savefig(path, dpi=300, bbox_inches="tight")
        plt.close(fig)
        return path

    # ------------------------------------------------------------------
    # 4. HISTORICAL VALIDATION PANEL
    # ------------------------------------------------------------------
    def plot_historical_validation_panel(
        self,
        pcrvi_ts: pd.DataFrame,
        dhw_data: pd.DataFrame,
        known_events: Optional[Dict[int, Dict]] = None,
    ) -> Path:
        """
        Multi-panel validation: pCRVI and DHW leading up to each known event.
        One subplot per bleaching year.
        """
        _apply_poster_style()
        known_events = known_events or self.known_events

        years = sorted(known_events.keys())
        n = len(years)
        if n == 0:
            return Path()

        ncols = min(4, n)
        nrows = int(np.ceil(n / ncols))
        fig, axes = plt.subplots(nrows, ncols, figsize=(6 * ncols, 5 * nrows), squeeze=False)

        for i, year in enumerate(years):
            r, c = divmod(i, ncols)
            ax = axes[r][c]
            info = known_events[year]
            peak_month = info.get('peak_month', 5)

            # Window: 6 months before to 3 months after peak
            start = pd.Timestamp(f"{year}-{max(1, peak_month - 6):02d}-01")
            end = pd.Timestamp(f"{year}-{min(12, peak_month + 3):02d}-28")

            # pCRVI
            mask = (pcrvi_ts.index >= start) & (pcrvi_ts.index <= end)
            ts_window = pcrvi_ts.loc[mask]
            if not ts_window.empty:
                ax.plot(ts_window.index, ts_window['pcrvi'], color='#1a1a2e',
                        linewidth=2, label='pCRVI')
                ax.axhline(0.55, color='#FF4500', linestyle='--', alpha=0.5, linewidth=1)
                ax.axhline(0.70, color='#8B0000', linestyle='--', alpha=0.5, linewidth=1)

            # DHW on twin axis
            ax2 = ax.twinx()
            dhw_mask = (dhw_data.index >= start) & (dhw_data.index <= end)
            dhw_window = dhw_data.loc[dhw_mask]
            if not dhw_window.empty and 'dhw' in dhw_window.columns:
                ax2.fill_between(dhw_window.index, 0, dhw_window['dhw'],
                                 color='#D62728', alpha=0.2)
                ax2.plot(dhw_window.index, dhw_window['dhw'], color='#D62728',
                         linewidth=1.5, linestyle='--', label='DHW')
                ax2.set_ylabel('DHW', color='#D62728', fontsize=12)

            severity = info.get('severity', '?')
            pct = info.get('bleaching_pct', '?')
            ax.set_title(f"{year} — {severity} ({pct}% bleached)",
                         fontsize=14, fontweight='bold')
            ax.set_ylim(0, 1)
            ax.set_ylabel('pCRVI', fontsize=12)
            ax.xaxis.set_major_formatter(mdates.DateFormatter('%b'))

        # Remove empty subplots
        for i in range(n, nrows * ncols):
            r, c = divmod(i, ncols)
            fig.delaxes(axes[r][c])

        fig.suptitle('Historical Event Validation: pCRVI Lead-up to Known Bleaching Events',
                      fontsize=22, fontweight='bold', y=1.02)
        fig.tight_layout()

        path = self.output_dir / "historical_validation_panel.png"
        fig.savefig(path, dpi=300, bbox_inches="tight")
        plt.close(fig)
        return path

    # ------------------------------------------------------------------
    # 5. COMPONENT CONTRIBUTION STACKED AREA
    # ------------------------------------------------------------------
    def plot_component_contribution_stacked(
        self,
        pcrvi_ts: pd.DataFrame,
    ) -> Path:
        """Stacked area chart of weighted component contributions over time."""
        _apply_poster_style()

        fig, ax = plt.subplots(figsize=(20, 8))

        comp_cols = ['ta_norm', 'as_norm', 'sr_norm', 'cdr_norm',
                     'bh_norm', 'wq_norm', 'la_norm']
        available = [c for c in comp_cols if c in pcrvi_ts.columns]
        if not available:
            plt.close(fig)
            return Path()

        # Weekly resample for cleaner viz
        weekly = pcrvi_ts[available].resample('W').mean().fillna(0)

        colors = [COMPONENT_COLORS[c] for c in available]
        labels = [COMPONENT_LABELS[c] for c in available]

        ax.stackplot(weekly.index, *[weekly[c].values for c in available],
                     labels=labels, colors=colors, alpha=0.80)
        ax.set_ylabel('Normalised Component Score')
        ax.set_xlabel('')
        ax.set_title('Weighted Component Contributions to Enhanced-pCRVI',
                      fontsize=22, fontweight='bold')
        ax.legend(loc='upper left', ncol=3, fontsize=14, framealpha=0.9)
        ax.set_xlim(weekly.index[0], weekly.index[-1])

        _add_bleaching_events(ax, self.known_events, ymax=ax.get_ylim()[1])

        path = self.output_dir / "component_stacked_area.png"
        fig.savefig(path, dpi=300, bbox_inches="tight")
        plt.close(fig)
        return path

    # ------------------------------------------------------------------
    # 6. PREDICTIVE SKILL vs LEAD TIME
    # ------------------------------------------------------------------
    def plot_skill_leadtime_bars(
        self,
        skill_results: Dict[str, Any],
    ) -> Path:
        """
        Comprehensive predictive skill at various lead times (4-panel).

        Panel A — Classification: F1, MCC, PSS/TSS, HSS
        Panel B — Detection:      Precision, Recall/POD, CSI
        Panel C — Error:          FAR, POFD, Frequency Bias (log)
        Panel D — Threshold:      F1 vs threshold curve (30-day lead)
        """
        _apply_poster_style()

        lead_data = skill_results.get('lead_time_analysis', {})
        if not lead_data:
            return Path()

        leads = sorted(lead_data.keys(), key=lambda k: int(k.split('_')[0]))
        lead_labels = [k.replace('_', ' ') for k in leads]

        def _get(metric):
            return [lead_data[k].get(metric, 0) for k in leads]

        f1s   = _get('f1_score')
        mccs  = _get('mcc')
        hsss  = _get('heidke_skill_score')
        psss  = _get('peirce_skill_score')
        precs = _get('precision')
        recs  = _get('recall')
        csis  = _get('critical_success_index')
        fars  = _get('false_alarm_ratio')
        pofds = _get('prob_false_detection')
        fbias = _get('frequency_bias')
        corrs = _get('correlation')

        x = np.arange(len(leads))
        opt_thresh = skill_results.get('optimal_threshold', 0.4)
        opt_f1 = skill_results.get('optimal_f1', 0)

        fig = plt.figure(figsize=(22, 16))
        gs = gridspec.GridSpec(2, 2, hspace=0.35, wspace=0.30)

        # ── Panel A: Classification Skill ────────────────────────
        ax_a = fig.add_subplot(gs[0, 0])
        w = 0.18
        bars_a = [
            (x - 1.5*w, f1s,  '#1F77B4', 'F1 Score'),
            (x - 0.5*w, mccs, '#FF7F0E', 'MCC'),
            (x + 0.5*w, psss, '#2CA02C', 'PSS / TSS'),
            (x + 1.5*w, hsss, '#9467BD', 'HSS (Heidke)'),
        ]
        for pos, vals, col, lbl in bars_a:
            ax_a.bar(pos, vals, w, color=col, label=lbl, edgecolor='black', lw=0.5)
        ax_a.set_xticks(x); ax_a.set_xticklabels(lead_labels, fontsize=12)
        ax_a.set_ylabel('Score', fontsize=14)
        ax_a.set_title('A)  Classification Skill Scores', fontsize=16, fontweight='bold')
        ax_a.legend(fontsize=11, loc='upper left')
        ymax_a = max(max(f1s + mccs + psss + hsss, default=0) * 1.3, 0.5)
        ax_a.set_ylim(0, ymax_a)
        ax_a.axhline(0, color='black', lw=0.5)
        ax_a.grid(axis='y', alpha=0.3)
        # Value annotations
        for pos, vals, _, _ in bars_a:
            for i, v in enumerate(vals):
                if v > 0.01:
                    ax_a.text(pos[i], v + ymax_a*0.01, f'{v:.2f}',
                              ha='center', va='bottom', fontsize=8, rotation=45)

        # ── Panel B: Detection Skill ─────────────────────────────
        ax_b = fig.add_subplot(gs[0, 1])
        w2 = 0.22
        bars_b = [
            (x - w2, precs, '#E74C3C', 'Precision (PPV)'),
            (x,      recs,  '#3498DB', 'Recall / POD'),
            (x + w2, csis,  '#F39C12', 'CSI (Threat Score)'),
        ]
        for pos, vals, col, lbl in bars_b:
            ax_b.bar(pos, vals, w2, color=col, label=lbl, edgecolor='black', lw=0.5)
        ax_b.set_xticks(x); ax_b.set_xticklabels(lead_labels, fontsize=12)
        ax_b.set_ylabel('Score', fontsize=14)
        ax_b.set_title('B)  Detection Skill', fontsize=16, fontweight='bold')
        ax_b.legend(fontsize=11, loc='upper right')
        ax_b.set_ylim(0, 1.05)
        ax_b.grid(axis='y', alpha=0.3)
        # Highlight over-alerting
        ax_b.text(0.02, 0.85, f'⚠ At threshold={skill_results.get("optimal_threshold", 0.4):.2f}\n'
                  f'these improve to:\n'
                  f'Prec={skill_results.get("threshold_analysis", {}).get(f"{opt_thresh:.2f}", {}).get("precision", 0):.2f}, '
                  f'Rec={skill_results.get("threshold_analysis", {}).get(f"{opt_thresh:.2f}", {}).get("recall", 0):.2f}',
                  transform=ax_b.transAxes, fontsize=10, va='top',
                  bbox=dict(boxstyle='round', facecolor='lightyellow', edgecolor='orange', alpha=0.9))

        # ── Panel C: Error Characteristics ───────────────────────
        ax_c = fig.add_subplot(gs[1, 0])
        ax_c.plot(lead_labels, fars, 'o-', color='#E74C3C', lw=2, ms=8, label='FAR (False Alarm Ratio)')
        ax_c.plot(lead_labels, pofds, 's-', color='#8E44AD', lw=2, ms=8, label='POFD (Prob False Detection)')
        ax_c.set_ylabel('Rate', fontsize=14, color='#333')
        ax_c.set_ylim(0, 1.05)
        ax_c.legend(fontsize=11, loc='upper right')
        ax_c.grid(True, alpha=0.3)

        # Twin axis for frequency bias (different scale)
        ax_c2 = ax_c.twinx()
        ax_c2.bar(x, fbias, 0.35, color='#3498DB', alpha=0.4, label='Freq Bias (ideal=1)')
        ax_c2.axhline(1.0, color='green', ls='--', lw=1.5, label='Perfect bias (=1)')
        ax_c2.set_ylabel('Frequency Bias', fontsize=14, color='#3498DB')
        ax_c2.legend(fontsize=10, loc='center right')
        ax_c.set_title('C)  Error Characteristics (threshold={:.2f})'.format(
            float(lead_data[leads[0]].get('_threshold', 0.4)) if '_threshold' in lead_data.get(leads[0], {}) else 0.4),
            fontsize=16, fontweight='bold')

        # ── Panel D: Threshold Sensitivity ───────────────────────
        ax_d = fig.add_subplot(gs[1, 1])
        thresh_data = skill_results.get('threshold_analysis', {})
        if thresh_data:
            thresholds = sorted(thresh_data.keys(), key=float)
            thr_vals = [float(t) for t in thresholds]
            thr_f1  = [thresh_data[t].get('f1_score', 0) for t in thresholds]
            thr_mcc = [thresh_data[t].get('mcc', 0) for t in thresholds]
            thr_pss = [thresh_data[t].get('pss', 0) for t in thresholds]
            thr_hss = [thresh_data[t].get('hss', 0) for t in thresholds]
            thr_prec = [thresh_data[t].get('precision', 0) for t in thresholds]
            thr_rec = [thresh_data[t].get('recall', 0) for t in thresholds]

            ax_d.plot(thr_vals, thr_f1,  'o-', color='#1F77B4', lw=2.5, ms=6, label='F1 Score')
            ax_d.plot(thr_vals, thr_mcc, 's-', color='#FF7F0E', lw=2, ms=5, label='MCC')
            ax_d.plot(thr_vals, thr_pss, '^-', color='#2CA02C', lw=2, ms=5, label='PSS / TSS')
            ax_d.plot(thr_vals, thr_hss, 'D-', color='#9467BD', lw=2, ms=5, label='HSS')
            ax_d.plot(thr_vals, thr_prec, '--', color='#E74C3C', lw=1.5, alpha=0.7, label='Precision')
            ax_d.plot(thr_vals, thr_rec,  '--', color='#3498DB', lw=1.5, alpha=0.7, label='Recall')

            # Mark optimal
            ax_d.axvline(opt_thresh, color='red', ls=':', lw=2, alpha=0.8)
            ax_d.annotate(f'Optimal = {opt_thresh:.2f}\nF1 = {opt_f1:.3f}',
                         xy=(opt_thresh, opt_f1), xytext=(opt_thresh + 0.07, opt_f1 + 0.1),
                         fontsize=12, fontweight='bold', color='red',
                         arrowprops=dict(arrowstyle='->', color='red', lw=1.5),
                         bbox=dict(boxstyle='round', facecolor='lightyellow', edgecolor='red'))

        ax_d.set_xlabel('pCRVI Threshold', fontsize=14)
        ax_d.set_ylabel('Score', fontsize=14)
        ax_d.set_title('D)  Threshold Sensitivity (30-day lead)', fontsize=16, fontweight='bold')
        ax_d.legend(fontsize=10, loc='upper left', ncol=2)
        ax_d.set_ylim(0, 1.05)
        ax_d.set_xlim(0.1, 0.8)
        ax_d.grid(True, alpha=0.3)

        # ── Global annotation ────────────────────────────────────
        fig.suptitle('Enhanced-pCRVI Comprehensive Predictive Skill Assessment',
                     fontsize=22, fontweight='bold', y=0.98)

        # Summary text box
        summary = (f"Optimal threshold = {opt_thresh:.2f}  |  "
                   f"Best F1 = {opt_f1:.3f}  |  "
                   f"n = {lead_data.get(leads[0], {}).get('n_samples', '?'):,} samples  |  "
                   f"Lead times: {lead_labels[0]} – {lead_labels[-1]}")
        fig.text(0.5, 0.01, summary, ha='center', fontsize=13,
                 bbox=dict(boxstyle='round', facecolor='lightyellow', edgecolor='gray', alpha=0.9))

        path = self.output_dir / "skill_leadtime_bars.png"
        fig.savefig(path, dpi=300, bbox_inches="tight")
        plt.close(fig)
        return path

        # ------------------------------------------------------------------
    # 7. FORMULA SCHEMATIC (for poster methodology panel)
    # ------------------------------------------------------------------
    def plot_formula_schematic(
        self,
        weights: Dict[str, float],
    ) -> Path:
        """Visual representation of the Enhanced-pCRVI formula with weights."""
        _apply_poster_style()

        fig, ax = plt.subplots(figsize=(16, 5))
        ax.axis('off')

        names = list(WEIGHT_LABELS.values())
        full_names = list(WEIGHT_LABELS.keys())
        w_vals = [weights.get(k, 0) for k in full_names]
        comp_cols_ordered = ['ta_norm', 'as_norm', 'sr_norm', 'cdr_norm',
                              'bh_norm', 'wq_norm', 'la_norm']
        colors = [COMPONENT_COLORS[c] for c in comp_cols_ordered]

        x_positions = np.linspace(0.05, 0.95, len(names))
        for i, (name, w, color, x_pos) in enumerate(zip(names, w_vals, colors, x_positions)):
            # Draw circle sized by weight
            radius = 0.04 + w * 0.12
            circle = plt.Circle((x_pos, 0.5), radius, color=color, alpha=0.8)
            ax.add_patch(circle)
            ax.text(x_pos, 0.5, f'{name}\n{w:.2f}', ha='center', va='center',
                    fontsize=14, fontweight='bold', color='white')
            # Plus sign between components
            if i < len(names) - 1:
                mid_x = (x_positions[i] + x_positions[i + 1]) / 2
                ax.text(mid_x, 0.5, '+', ha='center', va='center',
                        fontsize=18, fontweight='bold', color='gray')

        ax.text(0.5, 0.95, 'Enhanced pCRVI = Σ wᵢ × Componentᵢ',
                ha='center', va='top', fontsize=22, fontweight='bold',
                transform=ax.transAxes)
        ax.set_xlim(-0.02, 1.02)
        ax.set_ylim(0, 1)

        path = self.output_dir / "formula_schematic.png"
        fig.savefig(path, dpi=300, bbox_inches="tight")
        plt.close(fig)
        return path

    # ------------------------------------------------------------------
    # GENERATE ALL POSTER PLOTS
    # ------------------------------------------------------------------
    def generate_all(
        self,
        pcrvi_ts: pd.DataFrame,
        dhw_data: pd.DataFrame,
        weekly_df: Optional[pd.DataFrame] = None,
        skill_results: Optional[Dict] = None,
        opt_results: Optional[Dict] = None,
        weights: Optional[Dict] = None,
        known_events: Optional[Dict] = None,
    ) -> Dict[str, Path]:
        """Generate the complete poster visualization suite."""
        if known_events:
            self.known_events = known_events

        paths: Dict[str, Path] = {}

        try:
            d = self.plot_pcrvi_7component_dashboard(pcrvi_ts, dhw_data)
            paths.update(d)
        except Exception as e:
            print(f"[PosterViz] Dashboard failed: {e}")

        if weekly_df is not None and not weekly_df.empty:
            try:
                paths['weekly_risk'] = self.plot_weekly_risk_heatmap(weekly_df)
            except Exception as e:
                print(f"[PosterViz] Weekly risk heatmap failed: {e}")

        if opt_results and 'ml_weights' in opt_results:
            try:
                paths['ml_weights'] = self.plot_ml_weight_comparison(opt_results)
            except Exception as e:
                print(f"[PosterViz] ML weight comparison failed: {e}")

        if known_events:
            try:
                paths['historical_validation'] = self.plot_historical_validation_panel(
                    pcrvi_ts, dhw_data, known_events)
            except Exception as e:
                print(f"[PosterViz] Historical validation failed: {e}")
        elif self.known_events:
            try:
                paths['historical_validation'] = self.plot_historical_validation_panel(
                    pcrvi_ts, dhw_data, self.known_events)
            except Exception as e:
                print(f"[PosterViz] Historical validation failed: {e}")

        try:
            paths['component_stacked'] = self.plot_component_contribution_stacked(pcrvi_ts)
        except Exception as e:
            print(f"[PosterViz] Component stacked failed: {e}")

        if skill_results:
            try:
                paths['skill_leadtime'] = self.plot_skill_leadtime_bars(skill_results)
            except Exception as e:
                print(f"[PosterViz] Skill lead time failed: {e}")

        if weights:
            try:
                paths['formula'] = self.plot_formula_schematic(weights)
            except Exception as e:
                print(f"[PosterViz] Formula schematic failed: {e}")

        # Data sources summary panel for poster methodology section
        try:
            paths['data_sources'] = self.plot_data_sources_panel()
        except Exception as e:
            print(f"[PosterViz] Data sources panel failed: {e}")

        # Correlation matrix between components
        try:
            paths['component_correlation'] = self.plot_component_correlation(pcrvi_ts)
        except Exception as e:
            print(f"[PosterViz] Component correlation failed: {e}")

        return paths

    # ------------------------------------------------------------------
    # 8. DATA SOURCES PANEL (for poster methodology section)
    # ------------------------------------------------------------------
    def plot_data_sources_panel(self) -> Path:
        """Table-style summary of all data sources used, for poster methodology."""
        _apply_poster_style()

        data_sources = [
            ('NOAA OISST v2.1', 'SST (°C)', 'GEE', '1982–present', '¼° daily',
             'Hughes et al. 2018'),
            ('Copernicus GlobColour', 'CHL (mg/m³), Kd490 (m⁻¹)', 'CMEMS',
             '1998–present', '4 km daily', 'Sully et al. 2019'),
            ('ERA5 Hourly', 'Cloud cover, Wind speed', 'GEE', '1940–present',
             '0.25° hourly', 'Kirk 2011'),
            ('NOAA ONI / BOM DMI', 'ENSO index, IOD index', 'NOAA/PSL',
             '1950–present', 'Monthly', 'van Hooidonk 2009'),
            ('NOAA CRW', 'MMM climatology, DHW', 'coralreefwatch.noaa.gov',
             '1985–present', '5 km daily', 'Liu et al. 2014'),
            ('Historical Events', 'Bleaching records', 'Literature',
             '1998–2024', 'Event-based', 'Krishnan et al. 2011'),
        ]

        fig, ax = plt.subplots(figsize=(20, 6))
        ax.axis('off')
        ax.set_title(f'Data Sources — {self.region_name}',
                     fontsize=22, fontweight='bold', pad=20)

        headers = ['Dataset', 'Variables', 'Source', 'Period', 'Resolution', 'Reference']
        table = ax.table(
            cellText=data_sources,
            colLabels=headers,
            cellLoc='center',
            loc='center',
        )
        table.auto_set_font_size(False)
        table.set_fontsize(13)
        table.scale(1.0, 2.0)

        # Style header
        for j, h in enumerate(headers):
            table[0, j].set_facecolor('#2c3e50')
            table[0, j].set_text_props(color='white', fontweight='bold')

        # Alternate row colors
        for i in range(1, len(data_sources) + 1):
            color = '#ecf0f1' if i % 2 == 0 else 'white'
            for j in range(len(headers)):
                table[i, j].set_facecolor(color)

        path = self.output_dir / "data_sources_panel.png"
        fig.savefig(path, dpi=300, bbox_inches='tight', pad_inches=0.5)
        plt.close(fig)
        return path

    # ------------------------------------------------------------------
    # 9. COMPONENT CORRELATION MATRIX
    # ------------------------------------------------------------------
    def plot_component_correlation(self, pcrvi_ts: pd.DataFrame) -> Path:
        """Correlation heatmap between 7 pCRVI components."""
        _apply_poster_style()

        comp_cols = ['ta_norm', 'as_norm', 'sr_norm', 'cdr_norm',
                     'bh_norm', 'wq_norm', 'la_norm']
        available = [c for c in comp_cols if c in pcrvi_ts.columns]
        if len(available) < 3:
            return Path()

        corr = pcrvi_ts[available].corr()
        labels = [COMPONENT_LABELS.get(c, c) for c in available]

        fig, ax = plt.subplots(figsize=(10, 8))
        im = ax.imshow(corr.values, cmap='RdBu_r', vmin=-1, vmax=1, aspect='auto')
        ax.set_xticks(range(len(labels)))
        ax.set_xticklabels([l.split('(')[0].strip() for l in labels],
                           rotation=45, ha='right', fontsize=12)
        ax.set_yticks(range(len(labels)))
        ax.set_yticklabels([l.split('(')[0].strip() for l in labels], fontsize=12)

        # Add correlation values
        for i in range(len(available)):
            for j in range(len(available)):
                val = corr.values[i, j]
                color = 'white' if abs(val) > 0.5 else 'black'
                ax.text(j, i, f'{val:.2f}', ha='center', va='center',
                        fontsize=11, color=color, fontweight='bold')

        ax.set_title('Inter-Component Correlation Matrix',
                     fontsize=20, fontweight='bold')
        plt.colorbar(im, ax=ax, shrink=0.8, label='Pearson r')

        path = self.output_dir / "component_correlation.png"
        fig.savefig(path, dpi=300, bbox_inches="tight")
        plt.close(fig)
        return path
