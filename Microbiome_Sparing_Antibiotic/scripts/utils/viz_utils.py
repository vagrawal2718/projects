"""
viz_utils.py -- Publication-quality visualization utilities.

Generates figures suitable for LaTeX beamer presentations and scientific
publications. All figures are saved in PDF format at 300 DPI.

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import os
import logging
from typing import Dict, List, Optional, Tuple

import numpy as np
import matplotlib
matplotlib.use('Agg')  # Non-interactive backend for HPC
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import seaborn as sns

logger = logging.getLogger(__name__)


def setup_publication_style():
    """
    Configure matplotlib for publication-quality figures.
    Call once at the start of any visualization script.
    """
    plt.rcParams.update({
        'font.family': 'serif',
        'font.size': 12,
        'axes.labelsize': 13,
        'axes.titlesize': 14,
        'xtick.labelsize': 11,
        'ytick.labelsize': 11,
        'legend.fontsize': 11,
        'figure.dpi': 300,
        'savefig.dpi': 300,
        'savefig.bbox': 'tight',
        'savefig.pad_inches': 0.05,
        'axes.linewidth': 0.8,
        'axes.grid': False,
        'grid.alpha': 0.3,
        'lines.linewidth': 1.5,
        'lines.markersize': 6,
        'text.usetex': False,  # Set True if LaTeX is available on Ada
    })
    sns.set_palette("colorblind")
    logger.info("Publication style configured")


# Colorblind-friendly palette
COLORS = {
    'rf': '#0072B2',
    'dmpnn': '#D55E00',
    'highlight': '#009E73',
    'neutral': '#999999',
    'narrow': '#009E73',
    'broad': '#CC79A7',
    'active': '#E69F00',
    'inactive': '#56B4E9',
}


def save_figure(fig, filepath: str, formats: List[str] = None):
    """
    Save a figure in multiple formats (default: PDF + PNG).

    Parameters
    ----------
    fig : matplotlib.figure.Figure
        The figure to save.
    filepath : str
        Base filepath without extension.
    formats : list of str
        File formats to save. Default ['pdf', 'png'].
    """
    if formats is None:
        formats = ['pdf', 'png']

    os.makedirs(os.path.dirname(filepath) if os.path.dirname(filepath) else '.', exist_ok=True)

    for fmt in formats:
        outpath = f"{filepath}.{fmt}"
        fig.savefig(outpath, format=fmt, dpi=300, bbox_inches='tight')
        logger.info(f"Saved figure: {outpath}")
    plt.close(fig)


def plot_class_distribution(
    labels: np.ndarray,
    title: str,
    filepath: str,
    class_names: Tuple[str, str] = ('Inactive', 'Active'),
):
    """
    Plot binary class distribution as a bar chart with counts and percentages.

    Parameters
    ----------
    labels : array-like
        Binary labels (0 or 1).
    title : str
        Plot title.
    filepath : str
        Base output path (without extension).
    class_names : tuple of str
        Names for class 0 and class 1.
    """
    setup_publication_style()
    labels = np.asarray(labels)
    counts = [int((labels == 0).sum()), int((labels == 1).sum())]
    total = sum(counts)
    fracs = [c / total * 100 for c in counts]

    fig, ax = plt.subplots(figsize=(5, 4))
    bars = ax.bar(class_names, counts, color=[COLORS['inactive'], COLORS['active']],
                  edgecolor='black', linewidth=0.5, width=0.5)

    for bar, count, frac in zip(bars, counts, fracs):
        ax.text(bar.get_x() + bar.get_width() / 2., bar.get_height() + total * 0.01,
                f'{count:,}\n({frac:.1f}%)', ha='center', va='bottom', fontsize=10)

    ax.set_ylabel('Number of compounds')
    ax.set_title(title)
    ax.set_ylim(0, max(counts) * 1.2)
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f'{int(x):,}'))
    sns.despine()

    save_figure(fig, filepath)


def plot_cv_metrics_comparison(
    metrics_dict: Dict[str, Dict[str, Tuple[float, float]]],
    metric_name: str,
    title: str,
    filepath: str,
):
    """
    Plot grouped bar chart comparing RF vs D-MPNN across tasks.

    Parameters
    ----------
    metrics_dict : dict
        Structure: {task_name: {'rf': (mean, std), 'dmpnn': (mean, std)}}
    metric_name : str
        Y-axis label (e.g., 'ROC-AUC', 'PR-AUC').
    title : str
        Plot title.
    filepath : str
        Base output path.
    """
    setup_publication_style()
    tasks = list(metrics_dict.keys())
    n_tasks = len(tasks)

    rf_means = [metrics_dict[t]['rf'][0] for t in tasks]
    rf_stds = [metrics_dict[t]['rf'][1] for t in tasks]
    dmpnn_means = [metrics_dict[t]['dmpnn'][0] for t in tasks]
    dmpnn_stds = [metrics_dict[t]['dmpnn'][1] for t in tasks]

    x = np.arange(n_tasks)
    width = 0.35

    fig, ax = plt.subplots(figsize=(max(8, n_tasks * 1.5), 5))
    bars1 = ax.bar(x - width/2, rf_means, width, yerr=rf_stds,
                   label='RF', color=COLORS['rf'], edgecolor='black',
                   linewidth=0.5, capsize=3)
    bars2 = ax.bar(x + width/2, dmpnn_means, width, yerr=dmpnn_stds,
                   label='D-MPNN', color=COLORS['dmpnn'], edgecolor='black',
                   linewidth=0.5, capsize=3)

    ax.set_ylabel(metric_name)
    ax.set_title(title)
    ax.set_xticks(x)
    ax.set_xticklabels(tasks, rotation=30, ha='right')
    ax.legend()
    ax.set_ylim(0, 1.05)
    ax.axhline(y=0.5, color='gray', linestyle='--', alpha=0.3, linewidth=0.8)
    sns.despine()

    save_figure(fig, filepath)


def plot_roc_curve(
    fpr_list: List[np.ndarray],
    tpr_list: List[np.ndarray],
    auc_list: List[float],
    labels: List[str],
    title: str,
    filepath: str,
    colors: List[str] = None,
):
    """
    Plot one or more ROC curves with AUC values in legend.

    Parameters
    ----------
    fpr_list : list of arrays
        False positive rates for each curve.
    tpr_list : list of arrays
        True positive rates for each curve.
    auc_list : list of float
        AUC values for each curve.
    labels : list of str
        Curve labels.
    title : str
        Plot title.
    filepath : str
        Base output path.
    colors : list of str, optional
        Colors for each curve.
    """
    setup_publication_style()
    if colors is None:
        colors = [COLORS['rf'], COLORS['dmpnn'], COLORS['highlight'],
                  COLORS['neutral']][:len(labels)]

    fig, ax = plt.subplots(figsize=(6, 6))

    for fpr, tpr, auc_val, label, color in zip(fpr_list, tpr_list, auc_list, labels, colors):
        ax.plot(fpr, tpr, color=color, linewidth=1.8,
                label=f'{label} (AUC = {auc_val:.3f})')

    ax.plot([0, 1], [0, 1], 'k--', alpha=0.3, linewidth=0.8)
    ax.set_xlabel('False Positive Rate')
    ax.set_ylabel('True Positive Rate')
    ax.set_title(title)
    ax.legend(loc='lower right')
    ax.set_xlim([-0.01, 1.01])
    ax.set_ylim([-0.01, 1.01])
    ax.set_aspect('equal')
    sns.despine()

    save_figure(fig, filepath)


def plot_selectivity_scatter(
    p_pathogen: np.ndarray,
    p_gut: np.ndarray,
    selectivity: np.ndarray,
    title: str,
    filepath: str,
    highlight_names: Optional[Dict[int, str]] = None,
):
    """
    Scatter plot of P_pathogen vs P_gut colored by selectivity score.

    Parameters
    ----------
    p_pathogen : array
        Pathogen activity probabilities.
    p_gut : array
        Gut harm probabilities.
    selectivity : array
        Selectivity scores S = P_pathogen * (1 - P_gut).
    title : str
        Plot title.
    filepath : str
        Base output path.
    highlight_names : dict, optional
        {index: name} for specific compounds to annotate.
    """
    setup_publication_style()
    fig, ax = plt.subplots(figsize=(7, 6))

    sc = ax.scatter(p_gut, p_pathogen, c=selectivity, cmap='RdYlGn',
                    s=8, alpha=0.6, edgecolors='none', vmin=0, vmax=1)
    cbar = plt.colorbar(sc, ax=ax, label='Selectivity Score S')

    if highlight_names:
        for idx, name in highlight_names.items():
            ax.annotate(name, (p_gut[idx], p_pathogen[idx]),
                       fontsize=8, fontweight='bold',
                       arrowprops=dict(arrowstyle='->', color='black', lw=0.8),
                       textcoords='offset points', xytext=(10, 10))

    ax.set_xlabel(r'$\hat{P}_{gut}$ (commensal harm probability)')
    ax.set_ylabel(r'$\hat{P}_{pathogen}$ (pathogen activity probability)')
    ax.set_title(title)
    ax.set_xlim([-0.02, 1.02])
    ax.set_ylim([-0.02, 1.02])

    # Quadrant labels
    ax.text(0.05, 0.95, 'Ideal\n(high activity,\nlow harm)',
            transform=ax.transAxes, fontsize=9, va='top', color=COLORS['highlight'],
            fontweight='bold', alpha=0.7)
    ax.text(0.75, 0.95, 'Broad-spectrum\n(high activity,\nhigh harm)',
            transform=ax.transAxes, fontsize=9, va='top', color=COLORS['broad'],
            fontweight='bold', alpha=0.7)

    sns.despine()
    save_figure(fig, filepath)


def plot_nhit_distribution(
    nhit_values: np.ndarray,
    thresholds: List[int],
    title: str,
    filepath: str,
):
    """
    Plot histogram of n_hit values with threshold lines.

    Parameters
    ----------
    nhit_values : array
        Number of strains inhibited per compound.
    thresholds : list of int
        Harm thresholds to mark (e.g., [5, 10, 20]).
    title : str
        Plot title.
    filepath : str
        Base output path.
    """
    setup_publication_style()
    fig, ax = plt.subplots(figsize=(8, 5))

    ax.hist(nhit_values, bins=np.arange(-0.5, 41.5, 1), color=COLORS['rf'],
            edgecolor='white', linewidth=0.3, alpha=0.8)

    threshold_colors = ['#E69F00', '#D55E00', '#CC79A7']
    for t, color in zip(thresholds, threshold_colors):
        n_above = int((nhit_values >= t).sum())
        frac = n_above / len(nhit_values) * 100
        ax.axvline(x=t, color=color, linestyle='--', linewidth=1.5,
                   label=f't={t} ({n_above} cpds, {frac:.1f}%)')

    ax.set_xlabel('Number of strains inhibited ($n_{hit}$)')
    ax.set_ylabel('Number of compounds')
    ax.set_title(title)
    ax.legend(loc='upper right')
    ax.set_xlim(-0.5, 40.5)
    sns.despine()

    save_figure(fig, filepath)


def plot_data_summary_table(
    data: Dict[str, Dict[str, str]],
    title: str,
    filepath: str,
):
    """
    Create a table figure (no axes, just text) for data summary.

    Parameters
    ----------
    data : dict of dict
        {row_label: {col_label: value_string}}
    title : str
        Table title.
    filepath : str
        Base output path.
    """
    setup_publication_style()
    rows = list(data.keys())
    cols = list(data[rows[0]].keys())

    cell_text = [[data[r][c] for c in cols] for r in rows]

    fig, ax = plt.subplots(figsize=(max(8, len(cols) * 2), max(3, len(rows) * 0.5 + 1)))
    ax.axis('off')

    table = ax.table(
        cellText=cell_text,
        rowLabels=rows,
        colLabels=cols,
        cellLoc='center',
        loc='center',
    )
    table.auto_set_font_size(False)
    table.set_fontsize(10)
    table.scale(1.2, 1.5)

    # Style header
    for j in range(len(cols)):
        table[0, j].set_facecolor('#4472C4')
        table[0, j].set_text_props(color='white', fontweight='bold')

    ax.set_title(title, fontsize=13, fontweight='bold', pad=20)

    save_figure(fig, filepath)


# ---- Unit tests ----
def _run_tests():
    """Run basic unit tests for visualization functions."""
    import tempfile
    print("Running viz_utils unit tests...")
    n_pass = 0
    n_fail = 0

    def _assert(condition, msg):
        nonlocal n_pass, n_fail
        if condition:
            n_pass += 1
            print(f"  [PASS] {msg}")
        else:
            n_fail += 1
            print(f"  [FAIL] {msg}")

    tmpdir = tempfile.mkdtemp()

    # Test class distribution plot
    try:
        labels = np.array([0]*800 + [1]*200)
        plot_class_distribution(labels, "Test Distribution",
                                os.path.join(tmpdir, "test_dist"))
        _assert(os.path.exists(os.path.join(tmpdir, "test_dist.pdf")), "Class dist PDF created")
    except Exception as e:
        _assert(False, f"Class dist plot: {e}")

    # Test ROC curve
    try:
        fpr = np.array([0.0, 0.2, 0.5, 1.0])
        tpr = np.array([0.0, 0.8, 0.9, 1.0])
        plot_roc_curve([fpr], [tpr], [0.85], ['Test'],
                       "Test ROC", os.path.join(tmpdir, "test_roc"))
        _assert(os.path.exists(os.path.join(tmpdir, "test_roc.pdf")), "ROC PDF created")
    except Exception as e:
        _assert(False, f"ROC plot: {e}")

    # Test n_hit distribution
    try:
        nhits = np.concatenate([np.zeros(800), np.random.randint(1, 41, 400)])
        plot_nhit_distribution(nhits, [5, 10, 20], "Test n_hit",
                               os.path.join(tmpdir, "test_nhit"))
        _assert(os.path.exists(os.path.join(tmpdir, "test_nhit.pdf")), "n_hit PDF created")
    except Exception as e:
        _assert(False, f"n_hit plot: {e}")

    # Cleanup
    import shutil
    shutil.rmtree(tmpdir, ignore_errors=True)

    print(f"\nUnit tests: {n_pass} passed, {n_fail} failed")
    return n_fail == 0


if __name__ == "__main__":
    success = _run_tests()
    exit(0 if success else 1)
