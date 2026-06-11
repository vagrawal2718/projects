"""
23_uncertainty_and_adjustment.py -- Post-hoc uncertainty quantification and
coactivity-adjusted selectivity scores.

This script performs two analyses on existing RF screening predictions:
  1. RF tree-level uncertainty: extracts per-tree probability estimates from
     the 500-tree RF ensemble to compute confidence intervals on P_pathogen,
     P_gut, and selectivity S for every Hub compound.
  2. Coactivity-adjusted selectivity: uses empirically measured pathogen-gut
     odds ratios (from Fisher exact tests in dataset_analysis.json) to adjust
     P_gut via Bayes' rule before computing S, partially addressing the
     independence assumption in S = P_pathogen * (1 - P_gut).

Reads:
  - RF model .pkl files from models/rf/
  - Hub compound SMILES from data/repurposing_hub/
  - Pathogen-gut coactivity odds ratios from results/dataset_analysis.json
  - Existing RF screening CSVs from results/screening/

Writes (new files only, nothing overwritten):
  - results/uncertainty_rf_*.csv          (screening with CI columns)
  - results/coactivity_adjusted_rf_*.csv  (screening with adjusted S)
  - results/uncertainty_summary.json      (summary statistics)
  - results/figures/uncertainty_*.png/pdf (figures)

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    April 2026
"""

import os
import sys
import json
import time
import glob
import logging
import traceback
import pickle

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

# ---------------------------------------------------------------------------
# Path setup
# ---------------------------------------------------------------------------
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import config

RESULTS_DIR = config.RESULTS_DIR
SCREENING_DIR = config.SCREENING_DIR
FIGURES_DIR = config.FIGURES_DIR
RF_DIR = config.RF_DIR
LOGS_DIR = config.LOGS_DIR

PATHOGEN_TASKS = ['ecoli', 'saureus', 'paeruginosa', 'mtb']
GUT_TASKS = ['gut_t5', 'gut_t10', 'gut_t20']
ALL_TASKS = PATHOGEN_TASKS + GUT_TASKS

SCRIPT_NAME = 'uncertainty_adjustment'

# ---------------------------------------------------------------------------
# Logging (matches pipeline convention)
# ---------------------------------------------------------------------------
logger = logging.getLogger(SCRIPT_NAME)
logger.setLevel(logging.INFO)

_log_fmt = logging.Formatter(
    '%(asctime)s | %(levelname)-5s | %(name)s | %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S')

_ch = logging.StreamHandler()
_ch.setFormatter(_log_fmt)
logger.addHandler(_ch)

os.makedirs(LOGS_DIR, exist_ok=True)
_fh = logging.FileHandler(
    os.path.join(LOGS_DIR, f'{SCRIPT_NAME}.log'), mode='a')
_fh.setFormatter(_log_fmt)
logger.addHandler(_fh)


def log_phase_start(logger, name):
    logger.info("\n" + "=" * 70)
    logger.info(f"  {name}")
    logger.info("=" * 70)
    return time.time()


def log_phase_end(logger, name, t_start):
    elapsed = time.time() - t_start
    m, s = divmod(int(elapsed), 60)
    logger.info(f"\n  {name} completed in {m:02d}:{s:02d}")
    logger.info("=" * 70)


# ---------------------------------------------------------------------------
# Figure saving (matches pipeline convention: PDF + PNG, DPI=300)
# ---------------------------------------------------------------------------
def save_figure(fig, path_stem):
    """Save figure as both PDF and PNG. path_stem has no extension."""
    os.makedirs(os.path.dirname(path_stem), exist_ok=True)
    for fmt in ['pdf', 'png']:
        out = f"{path_stem}.{fmt}"
        fig.savefig(out, dpi=config.FIGURE_DPI, bbox_inches='tight',
                    facecolor='white', edgecolor='none')
        logger.info(f"  Saved: {out}")
    plt.close(fig)


# ===================================================================
# PHASE 1: RF Tree-Level Uncertainty
# ===================================================================

def load_precomputed_fps(dataset_name='repurposing_hub'):
    """Load precomputed Morgan fingerprints from shared features."""
    from scipy import sparse
    npz_path = os.path.join(config.SHARED_DIR, 'features',
                            f'morgan_{dataset_name}.npz')
    if not os.path.exists(npz_path):
        raise FileNotFoundError(f"Precomputed FPs not found: {npz_path}")
    data = sparse.load_npz(npz_path)
    logger.info(f"  Loaded precomputed FPs: {npz_path} "
                f"({data.shape[0]} x {data.shape[1]})")
    return data


def load_rf_model(task):
    """Load the final RF model for a task."""
    model_path = os.path.join(RF_DIR, f'rf_{task}.pkl')
    if not os.path.exists(model_path):
        logger.warning(f"  RF model not found: {model_path}")
        return None
    with open(model_path, 'rb') as f:
        model = pickle.load(f)
    logger.info(f"  Loaded RF model: {model_path} "
                f"({len(model.estimators_)} trees)")
    return model


def tree_level_predictions(model, X):
    """
    Extract per-tree probability predictions from an RF model.

    Returns:
        proba_mean:  (n_samples,) mean probability across trees
        proba_std:   (n_samples,) std across trees
        proba_lower: (n_samples,) 2.5th percentile (95% CI lower)
        proba_upper: (n_samples,) 97.5th percentile (95% CI upper)
    """
    n_trees = len(model.estimators_)
    n_samples = X.shape[0]

    # Collect per-tree predictions
    tree_probas = np.zeros((n_trees, n_samples))
    for i, tree in enumerate(model.estimators_):
        tree_probas[i] = tree.predict_proba(X)[:, 1]

    proba_mean = tree_probas.mean(axis=0)
    proba_std = tree_probas.std(axis=0)
    proba_lower = np.percentile(tree_probas, 2.5, axis=0)
    proba_upper = np.percentile(tree_probas, 97.5, axis=0)

    return proba_mean, proba_std, proba_lower, proba_upper


def run_rf_uncertainty(hub_fps, hub_meta):
    """
    Compute tree-level uncertainty for all RF task models on Hub compounds.

    Returns dict: task -> {mean, std, lower, upper} arrays
    """
    logger.info("\n  PHASE 1/3: RF TREE-LEVEL UNCERTAINTY")

    uncertainty = {}

    for task in ALL_TASKS:
        model = load_rf_model(task)
        if model is None:
            continue

        mean, std, lower, upper = tree_level_predictions(model, hub_fps)
        uncertainty[task] = {
            'mean': mean,
            'std': std,
            'lower': lower,
            'upper': upper,
        }
        logger.info(f"    {task:18s}: mean_std={std.mean():.4f}, "
                    f"max_std={std.max():.4f}, "
                    f"mean_CI_width={np.mean(upper - lower):.4f}")

    return uncertainty


# ===================================================================
# PHASE 2: Coactivity-Adjusted Selectivity
# ===================================================================

def load_coactivity_odds_ratios():
    """
    Load empirically measured pathogen-gut odds ratios from
    dataset_analysis.json.
    """
    da_path = os.path.join(RESULTS_DIR, 'dataset_analysis.json')
    if not os.path.exists(da_path):
        logger.error(f"  dataset_analysis.json not found at {da_path}")
        return {}

    with open(da_path) as f:
        da = json.load(f)

    odds = {}
    coact = da.get('pathogen_gut_coactivity', {})
    for pathogen in PATHOGEN_TASKS:
        if pathogen in coact:
            # Use t=10 odds ratio as the default correction
            t10 = coact[pathogen].get('harm_t10', {})
            or_val = t10.get('odds_ratio')
            p_val = t10.get('fisher_p')
            if or_val is not None:
                odds[pathogen] = {
                    'odds_ratio': float(or_val),
                    'fisher_p': float(p_val) if p_val else None,
                }
                logger.info(f"    {pathogen:18s}: OR={or_val:.3f}, "
                            f"p={p_val:.6f}" if p_val else
                            f"    {pathogen:18s}: OR={or_val:.3f}")

    return odds


def bayesian_adjust_p_gut(p_gut, p_pathogen, odds_ratio,
                          pathogen_threshold=0.5):
    """
    Apply Bayesian correction to P_gut using the empirical odds ratio.

    For compounds predicted active against the pathogen (P_path > threshold),
    inflate P_gut to reflect the measured correlation between pathogen
    activity and gut harm.

    P_gut_adjusted = (P_gut * OR) / (1 + P_gut * (OR - 1))

    This is Bayes' rule applied to the prior P_gut with the likelihood
    ratio given by the odds ratio from Fisher exact test.
    """
    adjusted = p_gut.copy()
    active_mask = p_pathogen > pathogen_threshold

    if odds_ratio <= 1.0:
        # No positive correlation, no adjustment needed
        return adjusted

    # Apply Bayesian update only to predicted-active compounds
    p = p_gut[active_mask]
    p_adj = (p * odds_ratio) / (1.0 + p * (odds_ratio - 1.0))
    p_adj = np.clip(p_adj, 0.0, 1.0)
    adjusted[active_mask] = p_adj

    return adjusted


def compute_adjusted_selectivity(uncertainty, odds_ratios, hub_meta):
    """
    Compute coactivity-adjusted selectivity scores.

    For each pathogen x gut threshold combination:
    1. Get P_pathogen and P_gut from RF predictions
    2. Adjust P_gut using the pathogen-specific odds ratio
    3. Compute S_adjusted = P_pathogen * (1 - P_gut_adjusted)
    """
    logger.info("\n  PHASE 2/3: COACTIVITY-ADJUSTED SELECTIVITY")

    results = {}

    for pathogen in PATHOGEN_TASKS:
        if pathogen not in uncertainty:
            continue

        or_info = odds_ratios.get(pathogen)
        if or_info is None:
            logger.warning(f"  No odds ratio for {pathogen}, skipping")
            continue

        odds_ratio = or_info['odds_ratio']
        fisher_p = or_info.get('fisher_p')

        p_path_mean = uncertainty[pathogen]['mean']
        p_path_std = uncertainty[pathogen]['std']
        p_path_lower = uncertainty[pathogen]['lower']
        p_path_upper = uncertainty[pathogen]['upper']

        for gut_task in GUT_TASKS:
            if gut_task not in uncertainty:
                continue

            threshold = gut_task.replace('gut_t', '')
            combo_key = f'{pathogen}_t{threshold}'

            p_gut_mean = uncertainty[gut_task]['mean']
            p_gut_std = uncertainty[gut_task]['std']
            p_gut_lower = uncertainty[gut_task]['lower']
            p_gut_upper = uncertainty[gut_task]['upper']

            # --- Original selectivity ---
            S_original = p_path_mean * (1.0 - p_gut_mean)

            # --- Adjusted selectivity ---
            p_gut_adjusted = bayesian_adjust_p_gut(
                p_gut_mean, p_path_mean, odds_ratio)
            S_adjusted = p_path_mean * (1.0 - p_gut_adjusted)

            # --- Uncertainty on S (propagated from tree-level) ---
            # S = P_path * (1 - P_gut)
            # Var(S) approx (1-P_gut)^2 * Var(P_path) + P_path^2 * Var(P_gut)
            # (first-order delta method, assuming independence of RF models)
            S_var = ((1.0 - p_gut_mean)**2 * p_path_std**2 +
                     p_path_mean**2 * p_gut_std**2)
            S_std = np.sqrt(S_var)

            # Conservative CI from percentile propagation
            S_lower = p_path_lower * (1.0 - p_gut_upper)
            S_upper = p_path_upper * (1.0 - p_gut_lower)
            S_lower = np.clip(S_lower, 0.0, 1.0)
            S_upper = np.clip(S_upper, 0.0, 1.0)

            results[combo_key] = {
                'p_pathogen': p_path_mean,
                'p_pathogen_std': p_path_std,
                'p_pathogen_lower': p_path_lower,
                'p_pathogen_upper': p_path_upper,
                'p_gut': p_gut_mean,
                'p_gut_std': p_gut_std,
                'p_gut_lower': p_gut_lower,
                'p_gut_upper': p_gut_upper,
                'p_gut_adjusted': p_gut_adjusted,
                'selectivity_score': S_original,
                'selectivity_std': S_std,
                'selectivity_lower': S_lower,
                'selectivity_upper': S_upper,
                'selectivity_adjusted': S_adjusted,
                'odds_ratio': odds_ratio,
                'fisher_p': fisher_p,
            }

            # Summary statistics
            n_active = int((p_path_mean > 0.5).sum())
            delta_S = S_original - S_adjusted
            mean_delta = float(delta_S[p_path_mean > 0.5].mean()) \
                if n_active > 0 else 0.0

            logger.info(
                f"    {combo_key:25s}: OR={odds_ratio:.1f}, "
                f"n_active={n_active}, "
                f"mean_S={S_original.mean():.4f}, "
                f"mean_S_adj={S_adjusted.mean():.4f}, "
                f"mean_delta(active)={mean_delta:.4f}, "
                f"mean_CI_width={np.mean(S_upper - S_lower):.4f}")

    return results


# ===================================================================
# PHASE 3: Save Outputs and Figures
# ===================================================================

def save_outputs(results, hub_meta):
    """Save screening CSVs with uncertainty and adjusted selectivity."""
    logger.info("\n  PHASE 3/3: SAVING OUTPUTS AND FIGURES")

    summary = {
        'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
        'run_id': config.RUN_ID,
        'method': 'RF tree-level uncertainty + Bayesian coactivity adjustment',
        'n_trees': 500,
        'ci_method': '2.5th/97.5th percentile of per-tree predictions',
        'adjustment_method': 'Bayesian P_gut correction using Fisher OR',
        'per_combination': {},
    }

    for combo_key, data in results.items():
        # Build output DataFrame
        df = hub_meta.copy()
        df['p_pathogen'] = data['p_pathogen']
        df['p_pathogen_std'] = data['p_pathogen_std']
        df['p_pathogen_lower'] = data['p_pathogen_lower']
        df['p_pathogen_upper'] = data['p_pathogen_upper']
        df['p_gut'] = data['p_gut']
        df['p_gut_std'] = data['p_gut_std']
        df['p_gut_adjusted'] = data['p_gut_adjusted']
        df['selectivity_score'] = data['selectivity_score']
        df['selectivity_std'] = data['selectivity_std']
        df['selectivity_lower'] = data['selectivity_lower']
        df['selectivity_upper'] = data['selectivity_upper']
        df['selectivity_adjusted'] = data['selectivity_adjusted']

        # Sort by original selectivity (consistent with existing pipeline)
        df = df.sort_values('selectivity_score', ascending=False)
        df['rank'] = range(1, len(df) + 1)

        # Also compute adjusted rank
        df['rank_adjusted'] = df['selectivity_adjusted'].rank(
            ascending=False, method='min').astype(int)

        # Save uncertainty CSV
        out_uncert = os.path.join(
            RESULTS_DIR, f'uncertainty_rf_{combo_key}.csv')
        df.to_csv(out_uncert, index=False)
        logger.info(f"    Saved: {out_uncert}")

        # Summary stats for JSON
        ci_widths = data['selectivity_upper'] - data['selectivity_lower']
        delta_s = data['selectivity_score'] - data['selectivity_adjusted']

        summary['per_combination'][combo_key] = {
            'odds_ratio': data['odds_ratio'],
            'fisher_p': data['fisher_p'],
            'n_compounds': len(df),
            'selectivity_mean': float(data['selectivity_score'].mean()),
            'selectivity_std_mean': float(data['selectivity_std'].mean()),
            'ci_width_mean': float(ci_widths.mean()),
            'ci_width_median': float(np.median(ci_widths)),
            'ci_width_max': float(ci_widths.max()),
            'adjusted_mean': float(data['selectivity_adjusted'].mean()),
            'delta_S_mean': float(delta_s.mean()),
            'delta_S_mean_active': float(
                delta_s[data['p_pathogen'] > 0.5].mean())
            if (data['p_pathogen'] > 0.5).any() else 0.0,
            'n_rank_changes_top50': int(
                (df['rank'] <= 50).sum() -
                (df[df['rank'] <= 50]['rank_adjusted'] <= 50).sum()),
        }

    # Save summary JSON
    summary_path = os.path.join(RESULTS_DIR, 'uncertainty_summary.json')
    with open(summary_path, 'w') as f:
        json.dump(summary, f, indent=2, default=str)
    logger.info(f"    Saved: {summary_path}")

    return summary


def generate_figures(results, hub_meta):
    """Generate publication-quality figures for uncertainty analysis."""

    plt.rcParams.update({
        'font.size': config.FIGURE_FONT_SIZE,
        'font.family': config.FIGURE_FONT_FAMILY,
    })

    # --- Figure 1: CI width distribution across pathogens (t=10) ---
    fig, axes = plt.subplots(1, 4, figsize=(16, 4), sharey=True)
    for i, pathogen in enumerate(PATHOGEN_TASKS):
        combo = f'{pathogen}_t10'
        if combo not in results:
            continue
        data = results[combo]
        ci_widths = data['selectivity_upper'] - data['selectivity_lower']
        axes[i].hist(ci_widths, bins=50, color=config.COLORS['rf'],
                     alpha=0.7, edgecolor='white')
        axes[i].set_xlabel('95% CI width on S')
        axes[i].set_title(pathogen.replace('paeruginosa', 'P. aeruginosa')
                          .replace('ecoli', 'E. coli')
                          .replace('saureus', 'S. aureus')
                          .replace('mtb', 'M. tuberculosis'),
                          fontsize=11, fontstyle='italic')
        axes[i].axvline(np.median(ci_widths), color='red', linestyle='--',
                        linewidth=1, label=f'median={np.median(ci_widths):.3f}')
        axes[i].legend(fontsize=8)
    axes[0].set_ylabel('Number of compounds')
    fig.suptitle('RF Tree-Level Uncertainty: Selectivity Score CI Width',
                 fontsize=13, y=1.02)
    fig.tight_layout()
    save_figure(fig, os.path.join(FIGURES_DIR, 'uncertainty_ci_width'))

    # --- Figure 2: S vs S_adjusted scatter (t=10) ---
    fig, axes = plt.subplots(1, 4, figsize=(16, 4))
    for i, pathogen in enumerate(PATHOGEN_TASKS):
        combo = f'{pathogen}_t10'
        if combo not in results:
            continue
        data = results[combo]
        ax = axes[i]
        ax.scatter(data['selectivity_score'], data['selectivity_adjusted'],
                   alpha=0.15, s=3, color=config.COLORS['rf'])
        ax.plot([0, 1], [0, 1], 'k--', linewidth=0.5, alpha=0.5)
        ax.set_xlabel('S (original)')
        ax.set_ylabel('S (coactivity-adjusted)')
        or_val = data['odds_ratio']
        ax.set_title(f'{pathogen} (OR={or_val:.1f})',
                     fontsize=11, fontstyle='italic')
        ax.set_xlim(0, 0.8)
        ax.set_ylim(0, 0.8)
        ax.set_aspect('equal')
    fig.suptitle('Coactivity-Adjusted Selectivity: '
                 'S_original vs S_adjusted (RF, t=10)',
                 fontsize=13, y=1.02)
    fig.tight_layout()
    save_figure(fig, os.path.join(FIGURES_DIR, 'uncertainty_adjusted_scatter'))

    # --- Figure 3: Top-20 candidates with error bars (ecoli t=10) ---
    combo = 'ecoli_t10'
    if combo in results:
        data = results[combo]
        top_idx = np.argsort(data['selectivity_score'])[::-1][:20]
        names = hub_meta['name'].values[top_idx]
        s_mean = data['selectivity_score'][top_idx]
        s_lower = data['selectivity_lower'][top_idx]
        s_upper = data['selectivity_upper'][top_idx]
        s_adj = data['selectivity_adjusted'][top_idx]

        fig, ax = plt.subplots(figsize=(10, 6))
        y_pos = np.arange(len(names))
        xerr_lower = s_mean - s_lower
        xerr_upper = s_upper - s_mean

        ax.barh(y_pos, s_mean, color=config.COLORS['rf'], alpha=0.7,
                label='S (original)')
        ax.errorbar(s_mean, y_pos, xerr=[xerr_lower, xerr_upper],
                    fmt='none', ecolor='black', capsize=3, linewidth=1)
        ax.scatter(s_adj, y_pos, color=config.COLORS['broad'],
                   marker='|', s=100, linewidths=2, zorder=5,
                   label='S (adjusted)')

        ax.set_yticks(y_pos)
        ax.set_yticklabels(names, fontsize=8)
        ax.set_xlabel('Selectivity Score S')
        ax.set_title('Top-20 RF Candidates (E. coli, t=10) '
                     'with 95% CI and Coactivity Adjustment')
        ax.legend(fontsize=9)
        ax.invert_yaxis()
        fig.tight_layout()
        save_figure(fig, os.path.join(FIGURES_DIR,
                                      'uncertainty_top20_errorbars'))


# ===================================================================
# Main
# ===================================================================

def main():
    t_start = log_phase_start(logger,
                              "Phase 23: Uncertainty and Coactivity Adjustment")

    os.makedirs(RESULTS_DIR, exist_ok=True)
    os.makedirs(FIGURES_DIR, exist_ok=True)
    os.makedirs(SCREENING_DIR, exist_ok=True)

    # --- Load Hub data ---
    logger.info("\n  Loading Hub compounds...")
    hub_path = os.path.join(config.HUB_DIR, config.HUB_CLEAN_FILENAME)
    hub_df = pd.read_csv(hub_path)
    metadata_cols = ['smiles', 'name', 'clinical_phase', 'moa',
                     'disease_area', 'target']
    hub_meta = hub_df[[c for c in metadata_cols
                       if c in hub_df.columns]].copy()
    logger.info(f"  Hub: {len(hub_df)} compounds")

    # --- Load precomputed Morgan fingerprints ---
    logger.info("\n  Loading precomputed Morgan fingerprints for Hub...")
    hub_fps = load_precomputed_fps('repurposing_hub')
    logger.info(f"  Fingerprints: {hub_fps.shape}")

    # --- Phase 1: RF tree-level uncertainty ---
    try:
        uncertainty = run_rf_uncertainty(hub_fps, hub_meta)
    except Exception as e:
        logger.error(f"  RF uncertainty FAILED: {type(e).__name__}: {e}")
        logger.error(traceback.format_exc())
        log_phase_end(logger,
                      "Phase 23: Uncertainty (INCOMPLETE)", t_start)
        return

    # --- Load coactivity odds ratios ---
    logger.info("\n  Loading coactivity odds ratios...")
    odds_ratios = load_coactivity_odds_ratios()

    # --- Phase 2: Coactivity-adjusted selectivity ---
    try:
        results = compute_adjusted_selectivity(
            uncertainty, odds_ratios, hub_meta)
    except Exception as e:
        logger.error(f"  Adjusted selectivity FAILED: "
                     f"{type(e).__name__}: {e}")
        logger.error(traceback.format_exc())
        log_phase_end(logger,
                      "Phase 23: Adjustment (INCOMPLETE)", t_start)
        return

    # --- Phase 3: Save outputs and figures ---
    try:
        summary = save_outputs(results, hub_meta)
    except Exception as e:
        logger.error(f"  Output saving FAILED: {type(e).__name__}: {e}")
        logger.error(traceback.format_exc())

    try:
        generate_figures(results, hub_meta)
    except Exception as e:
        logger.error(f"  Figure generation FAILED: {type(e).__name__}: {e}")
        logger.error(traceback.format_exc())

    # --- Summary ---
    logger.info("\n" + "=" * 70)
    logger.info("  UNCERTAINTY AND ADJUSTMENT SUMMARY")
    logger.info("=" * 70)
    logger.info(f"  RF models loaded: {len(uncertainty)} tasks")
    logger.info(f"  Odds ratios loaded: {len(odds_ratios)} pathogens")
    logger.info(f"  Combinations computed: {len(results)}")

    if results:
        # Print top-5 for ecoli_t10 with CI
        combo = 'ecoli_t10'
        if combo in results:
            data = results[combo]
            top5 = np.argsort(data['selectivity_score'])[::-1][:5]
            logger.info(f"\n  Top-5 E. coli (t=10) with uncertainty:")
            for idx in top5:
                name = hub_meta['name'].values[idx]
                s = data['selectivity_score'][idx]
                s_lo = data['selectivity_lower'][idx]
                s_hi = data['selectivity_upper'][idx]
                s_adj = data['selectivity_adjusted'][idx]
                logger.info(
                    f"    {name:25s} S={s:.4f} "
                    f"[{s_lo:.4f}, {s_hi:.4f}] "
                    f"S_adj={s_adj:.4f}")

    n_csv = len(glob.glob(os.path.join(RESULTS_DIR, 'uncertainty_*.csv')))
    n_fig = len(glob.glob(os.path.join(FIGURES_DIR, 'uncertainty_*.png')))
    logger.info(f"\n  Output: {n_csv} CSVs, {n_fig} figure pairs, "
                f"1 summary JSON")
    logger.info("=" * 70)

    log_phase_end(logger,
                  "Phase 23: Uncertainty and Coactivity Adjustment",
                  t_start)


if __name__ == '__main__':
    main()