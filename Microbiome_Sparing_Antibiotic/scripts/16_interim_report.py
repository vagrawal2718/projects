"""
16_interim_report.py -- Generate progress report from whatever models have completed.

Reads all available *_cv_metrics.json files and produces:
  1. Terminal summary table
  2. results/interim_comparison.csv
  3. figures/interim_comparison.png (bar chart)
  4. results/interim_summary.md (Markdown report for leadership)

Safe to run at any point during the pipeline. Fast (~2s).

Usage:
  python scripts/16_interim_report.py          # generate report
  python scripts/16_interim_report.py --test   # unit tests

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import os, sys, json, time
from datetime import datetime
import numpy as np
import pandas as pd

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)

import config
from utils.logging_utils import setup_logging

logger = setup_logging('interim_report', log_dir=config.LOGS_DIR)

# Pipeline definitions (order matters for display)
PIPELINES = [
    ('rf',               'RF + Morgan FP',           'rf_cv_metrics.json'),
    ('dmpnn',            'D-MPNN (Chemprop)',         'dmpnn_cv_metrics.json'),
    ('chemeleon_frozen',  'CheMeleon (Frozen Enc.)',  'chemeleon_frozen_cv_metrics.json'),
    ('molformer',        'MoLFormer-XL',              'molformer_cv_metrics.json'),
]

TASK_LABELS = {
    'ecoli': 'E. coli',
    'saureus': 'S. aureus',
    'paeruginosa': 'P. aeruginosa',
    'mtb': 'M. tuberculosis',
    'gut_t5': 'Gut (t=5)',
    'gut_t10': 'Gut (t=10)',
    'gut_t15': 'Gut (t=15)',
    'gut_t20': 'Gut (t=20)',
}


def load_available_metrics():
    """Load all available pipeline metrics JSONs."""
    available = {}
    for key, label, filename in PIPELINES:
        path = os.path.join(config.RESULTS_DIR, filename)
        if os.path.exists(path):
            try:
                with open(path) as f:
                    data = json.load(f)
                n_ok = sum(1 for v in data.values()
                           if isinstance(v, dict) and v.get('mean_roc_auc') is not None)
                if n_ok > 0:
                    available[key] = {'label': label, 'data': data, 'n_tasks': n_ok}
                    logger.info(f"  Loaded: {key} ({n_ok} tasks)")
            except Exception as e:
                logger.warning(f"  Failed to load {filename}: {e}")
    return available


def build_comparison_df(available):
    """Build a DataFrame comparing all available models."""
    rows = []
    all_tasks = set()
    for key, info in available.items():
        all_tasks.update(info['data'].keys())

    # Sort tasks in a sensible order
    task_order = ['ecoli', 'saureus', 'paeruginosa', 'mtb',
                  'gut_t5', 'gut_t10', 'gut_t15', 'gut_t20']
    tasks = [t for t in task_order if t in all_tasks]
    tasks += sorted(all_tasks - set(task_order))

    for task in tasks:
        row = {'task': task, 'task_label': TASK_LABELS.get(task, task)}
        for key, info in available.items():
            m = info['data'].get(task, {})
            if not isinstance(m, dict):
                continue
            row[f'{key}_roc_auc'] = m.get('mean_roc_auc')
            row[f'{key}_std'] = m.get('std_roc_auc')
            row[f'{key}_pr_auc'] = m.get('mean_pr_auc')

            # Full metrics from full_metrics_agg
            agg = m.get('full_metrics_agg', {})
            row[f'{key}_mcc'] = agg.get('mean_mcc')
            row[f'{key}_sensitivity'] = agg.get('mean_sensitivity')
            row[f'{key}_specificity'] = agg.get('mean_specificity')
            row[f'{key}_brier'] = agg.get('mean_brier_score')
        rows.append(row)
    return pd.DataFrame(rows)


def print_terminal_summary(available, df):
    """Print a nicely formatted summary to terminal."""
    print("\n" + "=" * 70)
    print("  INTERIM MODEL COMPARISON")
    print(f"  Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print(f"  Models completed: {len(available)}/4")
    print("=" * 70)

    # Header
    model_keys = list(available.keys())
    header = f"  {'Task':<18}"
    for key in model_keys:
        header += f" {available[key]['label']:<22}"
    print(header)
    print("  " + "-" * (18 + 22 * len(model_keys)))

    # Rows
    for _, row in df.iterrows():
        line = f"  {row['task_label']:<18}"
        for key in model_keys:
            roc = row.get(f'{key}_roc_auc')
            std = row.get(f'{key}_std')
            if roc is not None and not np.isnan(roc):
                val = f"{roc:.4f}"
                if std is not None and not np.isnan(std):
                    val += f" +/- {std:.3f}"
                line += f" {val:<22}"
            else:
                line += f" {'--':<22}"
        print(line)

    # Overall means
    print("  " + "-" * (18 + 22 * len(model_keys)))
    line = f"  {'MEAN':<18}"
    for key in model_keys:
        col = f'{key}_roc_auc'
        vals = df[col].dropna()
        if len(vals) > 0:
            line += f" {vals.mean():.4f} (n={len(vals)}){'':<10}"
        else:
            line += f" {'--':<22}"
    print(line)

    # Best model per task
    print("\n  Best model per task:")
    for _, row in df.iterrows():
        best_key, best_val = None, -1
        for key in model_keys:
            roc = row.get(f'{key}_roc_auc')
            if roc is not None and not np.isnan(roc) and roc > best_val:
                best_val = roc
                best_key = key
        if best_key:
            print(f"    {row['task_label']:<18} {available[best_key]['label']:<22} "
                  f"ROC-AUC={best_val:.4f}")
    print("=" * 70)


def generate_bar_chart(available, df):
    """Generate a bar chart comparing models."""
    try:
        import matplotlib
        matplotlib.use('Agg')
        import matplotlib.pyplot as plt

        model_keys = list(available.keys())
        tasks = df['task_label'].tolist()
        n_tasks = len(tasks)
        n_models = len(model_keys)

        if n_tasks == 0 or n_models == 0:
            return None

        fig, ax = plt.subplots(figsize=(max(10, n_tasks * 1.5), 6))

        x = np.arange(n_tasks)
        width = 0.8 / n_models
        colors = ['#2196F3', '#4CAF50', '#FF9800', '#9C27B0', '#F44336']

        for i, key in enumerate(model_keys):
            vals = []
            errs = []
            for _, row in df.iterrows():
                roc = row.get(f'{key}_roc_auc')
                std = row.get(f'{key}_std', 0)
                vals.append(roc if roc is not None and not np.isnan(roc) else 0)
                errs.append(std if std is not None and not np.isnan(std) else 0)

            offset = (i - n_models / 2 + 0.5) * width
            bars = ax.bar(x + offset, vals, width, yerr=errs,
                         label=available[key]['label'],
                         color=colors[i % len(colors)], alpha=0.85,
                         capsize=3)

        ax.set_xlabel('Task', fontsize=12)
        ax.set_ylabel('ROC-AUC', fontsize=12)
        ax.set_title(f'Model Comparison ({len(available)}/4 models completed)',
                     fontsize=14, fontweight='bold')
        ax.set_xticks(x)
        ax.set_xticklabels(tasks, rotation=30, ha='right')
        ax.set_ylim(0.4, 1.05)
        ax.axhline(y=0.5, color='gray', linestyle='--', alpha=0.5, label='Random')
        ax.legend(loc='lower right', fontsize=9)
        ax.grid(axis='y', alpha=0.3)

        plt.tight_layout()

        fig_path = os.path.join(config.FIGURES_DIR, 'interim_comparison.png')
        os.makedirs(config.FIGURES_DIR, exist_ok=True)
        fig.savefig(fig_path, dpi=150, bbox_inches='tight')
        plt.close(fig)
        logger.info(f"  Figure: {fig_path}")
        return fig_path
    except Exception as e:
        logger.warning(f"  Chart generation failed: {e}")
        return None


def generate_markdown_report(available, df, fig_path=None):
    """Generate a Markdown summary for leadership."""
    os.makedirs(config.RESULTS_DIR, exist_ok=True)
    report_path = os.path.join(config.RESULTS_DIR, 'interim_summary.md')
    model_keys = list(available.keys())

    with open(report_path, 'w') as f:
        f.write("# Microbiome-Sparing Antibiotic Discovery: Interim Results\n\n")
        f.write(f"**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M')}\n\n")
        f.write(f"**Models completed:** {len(available)}/4\n\n")

        # Status table
        f.write("## Pipeline Status\n\n")
        f.write("| Model | Status | Tasks | Mean ROC-AUC |\n")
        f.write("|-------|--------|-------|--------------|\n")
        for key, label, filename in PIPELINES:
            if key in available:
                info = available[key]
                roc_col = f'{key}_roc_auc'
                vals = df[roc_col].dropna() if roc_col in df.columns else pd.Series()
                mean_roc = f"{vals.mean():.4f}" if len(vals) > 0 else "N/A"
                f.write(f"| {label} | DONE | {info['n_tasks']} | {mean_roc} |\n")
            else:
                f.write(f"| {label} | PENDING | 0 | -- |\n")

        # Detailed results
        f.write("\n## ROC-AUC by Task\n\n")
        header = "| Task |"
        sep = "|------|"
        for key in model_keys:
            header += f" {available[key]['label']} |"
            sep += "------|"
        f.write(header + "\n")
        f.write(sep + "\n")

        for _, row in df.iterrows():
            line = f"| {row['task_label']} |"
            for key in model_keys:
                roc = row.get(f'{key}_roc_auc')
                std = row.get(f'{key}_std')
                if roc is not None and not np.isnan(roc):
                    val = f"{roc:.4f}"
                    if std is not None and not np.isnan(std):
                        val += f" +/- {std:.3f}"
                    line += f" {val} |"
                else:
                    line += " -- |"
            f.write(line + "\n")

        # Key findings
        f.write("\n## Key Findings\n\n")
        for _, row in df.iterrows():
            best_key, best_val = None, -1
            for key in model_keys:
                roc = row.get(f'{key}_roc_auc')
                if roc is not None and not np.isnan(roc) and roc > best_val:
                    best_val = roc
                    best_key = key
            if best_key and best_val > 0.5:
                f.write(f"- **{row['task_label']}**: Best model is "
                        f"{available[best_key]['label']} "
                        f"(ROC-AUC = {best_val:.4f})\n")

        if fig_path:
            f.write(f"\n## Visualization\n\n")
            f.write(f"![Model Comparison](../figures/interim_comparison.png)\n")

    logger.info(f"  Report: {report_path}")
    return report_path


def main():
    logger.info("=" * 60)
    logger.info("  Interim Progress Report")
    logger.info("=" * 60)

    available = load_available_metrics()
    if not available:
        logger.warning("  No completed models found. Nothing to report.")
        print("\n  No completed models found. Run training first.")
        return

    df = build_comparison_df(available)

    # Save CSV
    os.makedirs(config.RESULTS_DIR, exist_ok=True)
    csv_path = os.path.join(config.RESULTS_DIR, 'interim_comparison.csv')
    df.to_csv(csv_path, index=False)
    logger.info(f"  CSV: {csv_path}")

    # Terminal summary
    print_terminal_summary(available, df)

    # Bar chart
    fig_path = generate_bar_chart(available, df)

    # Markdown report
    report_path = generate_markdown_report(available, df, fig_path)

    logger.info(f"\n  Done. {len(available)} models, {len(df)} tasks.")


def run_tests():
    """Unit tests."""
    print("Running interim report unit tests...")
    passed, failed = 0, 0

    def _assert(cond, msg):
        nonlocal passed, failed
        if cond:
            print(f"  [PASS] {msg}")
            passed += 1
        else:
            print(f"  [FAIL] {msg}")
            failed += 1

    _assert(len(PIPELINES) == 4, f"4 pipelines defined: {len(PIPELINES)}")
    _assert(all(len(p) == 3 for p in PIPELINES), "Each pipeline has (key, label, filename)")

    # Test with mock data
    mock_available = {
        'rf': {
            'label': 'RF',
            'data': {
                'ecoli': {'mean_roc_auc': 0.85, 'std_roc_auc': 0.02,
                           'mean_pr_auc': 0.80, 'full_metrics_agg': {'mean_mcc': 0.6}},
                'saureus': {'mean_roc_auc': 0.82, 'std_roc_auc': 0.03,
                             'mean_pr_auc': 0.78},
            },
            'n_tasks': 2,
        },
    }

    df = build_comparison_df(mock_available)
    _assert(len(df) == 2, f"2 tasks in df: {len(df)}")
    _assert('rf_roc_auc' in df.columns, "rf_roc_auc column exists")
    _assert(df['rf_roc_auc'].iloc[0] == 0.85, f"ecoli ROC-AUC=0.85: {df['rf_roc_auc'].iloc[0]}")
    _assert(df['rf_mcc'].iloc[0] == 0.6, f"ecoli MCC=0.6: {df['rf_mcc'].iloc[0]}")

    # Test with 2 models
    mock_available['dmpnn'] = {
        'label': 'D-MPNN',
        'data': {
            'ecoli': {'mean_roc_auc': 0.90, 'std_roc_auc': 0.01},
        },
        'n_tasks': 1,
    }
    df2 = build_comparison_df(mock_available)
    _assert('dmpnn_roc_auc' in df2.columns, "dmpnn_roc_auc column exists")
    _assert(df2[df2['task'] == 'ecoli']['dmpnn_roc_auc'].iloc[0] == 0.90, "dmpnn ecoli=0.90")

    # Test JSON serializable
    try:
        json.dumps(df.to_dict(orient='records'))
        _assert(True, "DataFrame is JSON serializable")
    except Exception as e:
        _assert(False, f"JSON serialization failed: {e}")

    print(f"\nUnit tests: {passed} passed, {failed} failed")


if __name__ == '__main__':
    if '--test' in sys.argv:
        run_tests()
    else:
        main()
