"""
12_compare_models.py -- Cross-model comparative analysis for publication.

Loads CV metrics from all pipelines (RF, D-MPNN, CheMeleon, MoLFormer),
produces:
  1. Full classification metrics CSV (ROC-AUC, PR-AUC, F1, MCC, sensitivity, etc.)
  2. Pairwise comparison heatmap (which model wins on which task)
  3. 3D surface plot: ROC-AUC x task x model
  4. Radar/spider charts per pathogen
  5. Screening list overlap analysis
  6. Publication-ready LaTeX table

Input:
  - results/rf_cv_metrics.json
  - results/dmpnn_cv_metrics.json
  - results/chemeleon_cv_metrics.json  (if available)
  - results/molformer_cv_metrics.json  (if available)
  - results/screening/*.csv

Output:
  - results/comparison_full_metrics.csv
  - results/comparison_summary.csv
  - results/comparison_summary.tex
  - results/figures/comparison_*.png
  - results/figures/comparison_3d_*.html

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import os
import sys
import json
import warnings
import numpy as np
import pandas as pd
from typing import Dict, Optional

warnings.filterwarnings('ignore')

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import config
from utils.logging_utils import setup_logging, log_phase_start, log_phase_end

logger = setup_logging('phase5_compare', log_dir=config.LOGS_DIR)

PIPELINES = ['rf', 'dmpnn', 'chemeleon_frozen', 'molformer', 'dmpnn_rdkit']
PIPELINE_LABELS = {
    'rf': 'RF + Morgan FP',
    'dmpnn': 'D-MPNN (Chemprop)',
    'chemeleon': 'CheMeleon (Fine-tune)',  # kept for backward compat if JSON exists
    'chemeleon_frozen': 'CheMeleon (Frozen Enc.)',
    'molformer': 'MoLFormer-XL (Transformer)', 'dmpnn_rdkit': 'D-MPNN+RDKit (Stokes)',
}
TASK_ORDER = ['ecoli', 'saureus', 'paeruginosa', 'mtb', 'gut_t10', 'gut_t15', 'gut_t20']
TASK_LABELS = {
    'ecoli': 'E. coli',
    'saureus': 'S. aureus',
    'paeruginosa': 'P. aeruginosa',
    'mtb': 'M. tuberculosis',
    'gut_t10': 'Gut Harm (t=10)',
    'gut_t15': 'Gut Harm (t=15)',
    'gut_t20': 'Gut Harm (t=20)',
}

# Key metrics for publication
PUB_METRICS = ['roc_auc', 'pr_auc', 'f1_macro', 'mcc', 'sensitivity', 'specificity',
               'balanced_accuracy', 'brier_score']


def load_all_metrics() -> Dict[str, dict]:
    """Load CV metrics from all available pipelines."""
    all_metrics = {}
    for pipeline in PIPELINES:
        path = os.path.join(config.RESULTS_DIR, f'{pipeline}_cv_metrics.json')
        if os.path.exists(path):
            try:
                with open(path) as f:
                    all_metrics[pipeline] = json.load(f)
                logger.info(f"  Loaded: {pipeline} ({len(all_metrics[pipeline])} tasks)")
            except Exception as e:
                logger.warning(f"  Failed to load {pipeline}: {e}")
        else:
            logger.info(f"  Not found: {path}")
    return all_metrics


def build_comparison_table(all_metrics: dict) -> pd.DataFrame:
    """
    Build a wide-format comparison table: tasks x (pipeline_metric) combinations.
    """
    rows = []
    for task in TASK_ORDER:
        row = {'task': task, 'task_label': TASK_LABELS.get(task, task)}
        for pipeline in PIPELINES:
            if pipeline not in all_metrics:
                continue
            m = all_metrics[pipeline].get(task, {})
            prefix = pipeline

            # Standard metrics
            for metric in ['mean_roc_auc', 'std_roc_auc', 'mean_pr_auc', 'std_pr_auc']:
                row[f'{prefix}_{metric}'] = m.get(metric)

            # Full metrics (from full_metrics_agg)
            agg = m.get('full_metrics_agg', {})
            for metric in PUB_METRICS:
                row[f'{prefix}_mean_{metric}'] = agg.get(f'mean_{metric}', m.get(f'mean_{metric}'))
                row[f'{prefix}_std_{metric}'] = agg.get(f'std_{metric}', m.get(f'std_{metric}'))

        rows.append(row)
    return pd.DataFrame(rows)


def build_full_metrics_csv(all_metrics: dict) -> pd.DataFrame:
    """Build a long-format CSV with all metrics for each task x pipeline."""
    rows = []
    for pipeline in PIPELINES:
        if pipeline not in all_metrics:
            continue
        for task in TASK_ORDER:
            m = all_metrics[pipeline].get(task, {})
            if not m:
                continue
            row = {
                'pipeline': pipeline,
                'pipeline_label': PIPELINE_LABELS.get(pipeline, pipeline),
                'task': task,
                'task_label': TASK_LABELS.get(task, task),
                'n_samples': m.get('n_samples'),
                'n_positive': m.get('n_positive'),
                'n_folds': m.get('n_folds_completed'),
            }
            # Standard
            for k in ['mean_roc_auc', 'std_roc_auc', 'mean_pr_auc', 'std_pr_auc']:
                row[k] = m.get(k)
            # Full metrics
            agg = m.get('full_metrics_agg', {})
            for metric in PUB_METRICS:
                row[f'mean_{metric}'] = agg.get(f'mean_{metric}', m.get(f'mean_{metric}'))
                row[f'std_{metric}'] = agg.get(f'std_{metric}', m.get(f'std_{metric}'))

            rows.append(row)
    return pd.DataFrame(rows)


def generate_latex_table(df_full: pd.DataFrame) -> str:
    """Generate a publication-ready LaTeX table."""
    lines = []
    available = df_full['pipeline'].unique().tolist()

    lines.append(r"\begin{table}[ht]")
    lines.append(r"\centering")
    lines.append(r"\caption{Cross-validation performance across all models and tasks. "
                 r"Values are mean $\pm$ std over 5 scaffold CV folds.}")
    lines.append(r"\label{tab:model_comparison}")
    lines.append(r"\small")

    # Columns: Task | pipeline1_ROC | pipeline1_MCC | pipeline2_ROC | ...
    col_spec = "l" + "cc" * len(available)
    lines.append(r"\begin{tabular}{" + col_spec + "}")
    lines.append(r"\toprule")

    # Header row 1: pipeline names
    header1 = "Task"
    for p in available:
        label = PIPELINE_LABELS.get(p, p)
        header1 += f" & \\multicolumn{{2}}{{c}}{{{label}}}"
    header1 += r" \\"
    lines.append(header1)

    # Header row 2: metric names
    header2 = ""
    for p in available:
        header2 += " & ROC-AUC & MCC"
    header2 += r" \\"
    lines.append(header2)
    lines.append(r"\midrule")

    # Data rows
    for task in TASK_ORDER:
        task_label = TASK_LABELS.get(task, task)
        row_str = task_label
        for p in available:
            subset = df_full[(df_full['pipeline'] == p) & (df_full['task'] == task)]
            if len(subset) > 0:
                s = subset.iloc[0]
                roc = s.get('mean_roc_auc')
                roc_std = s.get('std_roc_auc')
                mcc = s.get('mean_mcc')
                mcc_std = s.get('std_mcc')
                roc_str = f"{roc:.3f}$\\pm${roc_std:.3f}" if roc is not None and not np.isnan(roc) else "--"
                mcc_str = f"{mcc:.3f}$\\pm${mcc_std:.3f}" if mcc is not None and not np.isnan(mcc) else "--"
                row_str += f" & {roc_str} & {mcc_str}"
            else:
                row_str += " & -- & --"
        row_str += r" \\"
        lines.append(row_str)

    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"\end{table}")

    return "\n".join(lines)


def plot_comparison_bar(df_full: pd.DataFrame, metric='mean_roc_auc', save_dir=None):
    """Grouped bar chart: tasks on x-axis, bars for each pipeline."""
    import matplotlib.pyplot as plt
    import matplotlib

    matplotlib.use('Agg')

    available = sorted(df_full['pipeline'].unique())
    tasks = TASK_ORDER

    fig, ax = plt.subplots(figsize=(14, 6))
    x = np.arange(len(tasks))
    width = 0.8 / len(available)
    colors = ['#2196F3', '#FF5722', '#4CAF50', '#9C27B0', '#FF9800']

    for i, pipeline in enumerate(available):
        vals = []
        errs = []
        for task in tasks:
            subset = df_full[(df_full['pipeline'] == pipeline) & (df_full['task'] == task)]
            if len(subset) > 0:
                v = subset.iloc[0].get(metric)
                e = subset.iloc[0].get(metric.replace('mean_', 'std_'))
                vals.append(v if v is not None and not np.isnan(v) else 0)
                errs.append(e if e is not None and not np.isnan(e) else 0)
            else:
                vals.append(0)
                errs.append(0)

        label = PIPELINE_LABELS.get(pipeline, pipeline)
        ax.bar(x + i * width, vals, width, yerr=errs, label=label,
               color=colors[i % len(colors)], capsize=3, alpha=0.85)

    metric_label = metric.replace('mean_', '').replace('_', ' ').upper()
    ax.set_xlabel('Task')
    ax.set_ylabel(metric_label)
    ax.set_title(f'{metric_label} Comparison Across Models and Tasks')
    ax.set_xticks(x + width * (len(available) - 1) / 2)
    ax.set_xticklabels([TASK_LABELS.get(t, t) for t in tasks], rotation=30, ha='right')
    ax.legend(loc='lower right', fontsize=9)
    ax.set_ylim(0, 1.05)
    ax.grid(axis='y', alpha=0.3)
    plt.tight_layout()

    if save_dir:
        path = os.path.join(save_dir, f'comparison_bar_{metric}.png')
        fig.savefig(path, dpi=300, bbox_inches='tight')
        logger.info(f"  Saved: {path}")
    plt.close(fig)


def plot_3d_surface(df_full: pd.DataFrame, metric='mean_roc_auc', save_dir=None):
    """3D surface/bar plot using plotly."""
    try:
        import plotly.graph_objects as go
    except ImportError:
        logger.warning("  plotly not available, skipping 3D plot")
        return

    available = sorted(df_full['pipeline'].unique())
    tasks = TASK_ORDER

    # Build matrix: tasks x pipelines
    z = []
    for task in tasks:
        row = []
        for pipeline in available:
            subset = df_full[(df_full['pipeline'] == pipeline) & (df_full['task'] == task)]
            if len(subset) > 0:
                v = subset.iloc[0].get(metric)
                row.append(v if v is not None and not np.isnan(v) else 0)
            else:
                row.append(0)
        z.append(row)

    z = np.array(z)

    fig = go.Figure(data=[go.Surface(
        z=z,
        x=[PIPELINE_LABELS.get(p, p) for p in available],
        y=[TASK_LABELS.get(t, t) for t in tasks],
        colorscale='Viridis',
        colorbar=dict(title=metric.replace('mean_', '').upper()),
    )])

    metric_label = metric.replace('mean_', '').replace('_', ' ').upper()
    fig.update_layout(
        title=f'{metric_label} Across Models and Tasks',
        scene=dict(
            xaxis_title='Model',
            yaxis_title='Task',
            zaxis_title=metric_label,
            zaxis=dict(range=[0, 1]),
        ),
        width=900, height=700,
    )

    if save_dir:
        path = os.path.join(save_dir, f'comparison_3d_{metric}.html')
        fig.write_html(path)
        logger.info(f"  Saved: {path}")


def plot_radar_per_task(df_full: pd.DataFrame, save_dir=None):
    """Spider/radar chart showing all metrics for each task, one line per pipeline."""
    import matplotlib.pyplot as plt
    import matplotlib
    matplotlib.use('Agg')

    metrics_to_plot = ['mean_roc_auc', 'mean_pr_auc', 'mean_f1_macro',
                       'mean_mcc', 'mean_sensitivity', 'mean_specificity']
    metric_labels = ['ROC-AUC', 'PR-AUC', 'F1 (Macro)', 'MCC', 'Sensitivity', 'Specificity']
    available = sorted(df_full['pipeline'].unique())
    colors = ['#2196F3', '#FF5722', '#4CAF50', '#9C27B0', '#E69F00']

    for task in TASK_ORDER:
        fig, ax = plt.subplots(figsize=(8, 8), subplot_kw=dict(polar=True))
        angles = np.linspace(0, 2 * np.pi, len(metrics_to_plot), endpoint=False).tolist()
        angles += angles[:1]  # close the polygon

        for i, pipeline in enumerate(available):
            subset = df_full[(df_full['pipeline'] == pipeline) & (df_full['task'] == task)]
            if len(subset) == 0:
                continue
            s = subset.iloc[0]
            values = []
            for m in metrics_to_plot:
                v = s.get(m)
                # MCC ranges [-1, 1], normalize to [0, 1] for radar
                if 'mcc' in m and v is not None and not np.isnan(v):
                    v = (v + 1) / 2
                values.append(v if v is not None and not np.isnan(v) else 0)
            values += values[:1]

            label = PIPELINE_LABELS.get(pipeline, pipeline)
            ax.plot(angles, values, '-o', color=colors[i % len(colors)],
                    linewidth=2, markersize=6, label=label, alpha=0.8)
            ax.fill(angles, values, color=colors[i % len(colors)], alpha=0.1)

        ax.set_xticks(angles[:-1])
        ax.set_xticklabels(metric_labels, fontsize=10)
        ax.set_ylim(0, 1)
        ax.set_title(f'{TASK_LABELS.get(task, task)}', fontsize=14, pad=20)
        ax.legend(loc='upper right', bbox_to_anchor=(1.3, 1.1), fontsize=9)
        plt.tight_layout()

        if save_dir:
            path = os.path.join(save_dir, f'comparison_radar_{task}.png')
            fig.savefig(path, dpi=200, bbox_inches='tight')
        plt.close(fig)


def screening_overlap_analysis(save_dir=None):
    """Analyze overlap in top-N screening lists across models."""
    screening_dir = config.SCREENING_DIR
    if not os.path.isdir(screening_dir):
        return None

    # Load all screening lists
    lists = {}
    for f in sorted(os.listdir(screening_dir)):
        if f.endswith('.csv') and 'ranked' in f:
            path = os.path.join(screening_dir, f)
            try:
                df = pd.read_csv(path)
                lists[f.replace('.csv', '')] = df
            except Exception:
                pass

    if not lists:
        logger.info("  No screening lists found")
        return None

    # For each pathogen, compare top-100 across pipelines
    overlap_rows = []
    for pathogen in ['ecoli', 'saureus', 'paeruginosa', 'mtb']:
        pathogen_lists = {}
        for name, df in lists.items():
            if pathogen in name:
                pipeline = name.split('_ranked_')[0]
                if 'smiles' in df.columns:
                    top100 = set(df.head(100)['smiles'].tolist())
                    pathogen_lists[pipeline] = top100

        if len(pathogen_lists) < 2:
            continue

        pipelines = sorted(pathogen_lists.keys())
        for i in range(len(pipelines)):
            for j in range(i + 1, len(pipelines)):
                p1, p2 = pipelines[i], pipelines[j]
                overlap = len(pathogen_lists[p1] & pathogen_lists[p2])
                overlap_rows.append({
                    'pathogen': pathogen,
                    'pipeline_1': p1,
                    'pipeline_2': p2,
                    'top100_overlap': overlap,
                    'jaccard': round(overlap / len(pathogen_lists[p1] | pathogen_lists[p2]), 3),
                })

    if overlap_rows:
        df_overlap = pd.DataFrame(overlap_rows)
        if save_dir:
            path = os.path.join(save_dir, 'screening_overlap.csv')
            df_overlap.to_csv(path, index=False)
            logger.info(f"  Screening overlap: {path}")
        return df_overlap
    return None


# ===========================================================================
# MAIN
# ===========================================================================
def main():
    start_time = log_phase_start(logger, "Phase 5: Cross-Model Comparative Analysis")

    os.makedirs(config.FIGURES_DIR, exist_ok=True)
    os.makedirs(config.RESULTS_DIR, exist_ok=True)

    # Load metrics
    all_metrics = load_all_metrics()
    if not all_metrics:
        logger.error("No metrics found. Run training phases first.")
        return

    # Build tables
    logger.info("\n  Building comparison tables...")
    df_full = build_full_metrics_csv(all_metrics)
    df_full.to_csv(os.path.join(config.RESULTS_DIR, 'comparison_full_metrics.csv'), index=False)
    logger.info(f"  Full metrics: {len(df_full)} rows x {len(df_full.columns)} columns")

    # Summary table (wide format)
    df_wide = build_comparison_table(all_metrics)
    df_wide.to_csv(os.path.join(config.RESULTS_DIR, 'comparison_summary.csv'), index=False)

    # LaTeX table
    latex = generate_latex_table(df_full)
    tex_path = os.path.join(config.RESULTS_DIR, 'comparison_summary.tex')
    with open(tex_path, 'w') as f:
        f.write(latex)
    logger.info(f"  LaTeX table: {tex_path}")

    # Plots
    logger.info("\n  Generating comparison plots...")
    for metric in ['mean_roc_auc', 'mean_pr_auc', 'mean_mcc']:
        plot_comparison_bar(df_full, metric=metric, save_dir=config.FIGURES_DIR)

    # 3D surface plots
    for metric in ['mean_roc_auc', 'mean_mcc']:
        plot_3d_surface(df_full, metric=metric, save_dir=config.FIGURES_DIR)

    # Radar charts
    plot_radar_per_task(df_full, save_dir=config.FIGURES_DIR)

    # Screening overlap
    logger.info("\n  Screening list overlap analysis...")
    screening_overlap_analysis(save_dir=config.RESULTS_DIR)

    # Print summary
    logger.info("\n" + "=" * 80)
    logger.info("  COMPARISON SUMMARY")
    logger.info("=" * 80)
    for task in TASK_ORDER:
        logger.info(f"\n  {TASK_LABELS.get(task, task)}:")
        for pipeline in PIPELINES:
            if pipeline not in all_metrics:
                continue
            m = all_metrics[pipeline].get(task, {})
            roc = m.get('mean_roc_auc')
            if roc is not None:
                roc_std = m.get('std_roc_auc', 0)
                logger.info(f"    {PIPELINE_LABELS.get(pipeline, pipeline):35s} "
                            f"ROC-AUC = {roc:.4f} +/- {roc_std:.4f}")

    # Best model per task
    logger.info("\n  BEST MODEL PER TASK (by ROC-AUC):")
    for task in TASK_ORDER:
        best_pipeline = None
        best_roc = -1
        for pipeline in PIPELINES:
            if pipeline not in all_metrics:
                continue
            m = all_metrics[pipeline].get(task, {})
            roc = m.get('mean_roc_auc')
            if roc is not None and roc > best_roc:
                best_roc = roc
                best_pipeline = pipeline
        if best_pipeline:
            logger.info(f"    {TASK_LABELS.get(task, task):25s} -> "
                        f"{PIPELINE_LABELS.get(best_pipeline, best_pipeline)} "
                        f"({best_roc:.4f})")

    log_phase_end(logger, "Phase 5: Cross-Model Comparative Analysis", start_time)


def run_tests():
    """Quick unit tests."""
    print("Running Phase 5 (Comparison) unit tests...")
    passed, failed = 0, 0

    def _assert(cond, msg):
        nonlocal passed, failed
        if cond:
            print(f"  [PASS] {msg}")
            passed += 1
        else:
            print(f"  [FAIL] {msg}")
            failed += 1

    _assert(len(PIPELINES) == 4, f"4 pipelines defined: {PIPELINES}")
    _assert(len(TASK_ORDER) == 7, f"7 tasks defined")
    _assert(len(PUB_METRICS) == 8, f"8 publication metrics")

    # Test LaTeX generation
    test_df = pd.DataFrame([{
        'pipeline': 'rf', 'task': 'ecoli',
        'mean_roc_auc': 0.85, 'std_roc_auc': 0.02,
        'mean_mcc': 0.65, 'std_mcc': 0.03,
    }])
    tex = generate_latex_table(test_df)
    _assert('tabular' in tex, "LaTeX has tabular")
    _assert('0.850' in tex, "LaTeX has ROC value")

    print(f"Unit tests: {passed} passed, {failed} failed")


if __name__ == '__main__':
    if '--test' in sys.argv:
        run_tests()
    else:
        main()
