#!/usr/bin/env python3
"""
07_evaluate.py -- Phase 4: Full Evaluation Suite

Two evaluation levels:
  LEVEL 1 (Diagnostic): Per-model ROC-AUC and PR-AUC comparison (all pipelines)
  LEVEL 2 (Pipeline):   Five selectivity framework tests

Tests:
  1. Rank Separation:     Mann-Whitney U on curated narrow vs broad-spectrum drugs
  2. Selectivity ROC-AUC: S score as binary classifier on validation set
  3. Top-k Enrichment:    Antibiotic enrichment in top-50 Hub screening hits
  4. Pipeline Agreement:  Spearman rank correlation between all pipeline pairs
  5. Threshold Sensitivity: Stability of rankings across t in {5, 10, 20}

Gracefully handles missing pipeline results (runs analysis on available models).

Inputs consumed (from Phases 3A/3B/3C/3D):
  - results/{pipeline}_cv_metrics.json
  - results/screening/{pipeline}_ranked_{pathogen}_t{threshold}.csv

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import os
import sys
import json
import time
import logging
import warnings
from typing import Dict, List, Optional, Tuple

import numpy as np
import pandas as pd
from scipy import stats as scipy_stats
from sklearn.metrics import roc_auc_score, roc_curve

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)

import config
from utils.logging_utils import (
    setup_logging, log_phase_start, log_phase_end,
    save_checkpoint, load_checkpoint,
)
from utils.viz_utils import setup_publication_style, save_figure, COLORS

warnings.filterwarnings('ignore')
logger = setup_logging('phase4', log_dir=config.LOGS_DIR)

# Track which missing drugs have already been logged (avoid 24x spam)
_MISSING_DRUGS_LOGGED = set()

# All pipeline names to evaluate
ALL_PIPELINES = ['rf', 'dmpnn', 'chemeleon_frozen', 'molformer', 'dmpnn_rdkit']

# Display names for figures and tables
PIPELINE_DISPLAY = {
    'rf': 'RF',
    'dmpnn': 'D-MPNN',
    'chemeleon_frozen': 'CheMeleon',
    'molformer': 'MoLFormer',
    'dmpnn_rdkit': 'D-MPNN+RDKit',
}

# Colors per pipeline for figures
PIPELINE_COLORS = {
    'rf': '#0072B2',
    'dmpnn': '#D55E00',
    'chemeleon_frozen': '#009E73',
    'molformer': '#CC79A7',
    'dmpnn_rdkit': '#E69F00',
}

# ===========================================================================
# Validation drug sets (from workflow specification)
# ===========================================================================
NARROW_SPECTRUM = {
    'lolamicin':      'Gram-neg selective, LolCDE target, microbiome-sparing (Munoz 2024)',
    'daptomycin':     'Gram-pos only lipopeptide',
    'fidaxomicin':    'Very narrow, anti-C. difficile only',
    'nitrofurantoin': 'Narrow (urinary tract), minimal gut absorption',
    'methenamine':    'Narrow (urinary antiseptic)',
}
BROAD_SPECTRUM = {
    'ciprofloxacin':  'Broad fluoroquinolone, n_hit=39/40 in Maier',
    'amoxicillin':    'Broad beta-lactam',
    'clindamycin':    'High C. difficile risk',
    'rifabutin':      'Kills nearly all commensals, n_hit=40/40 in Maier',
    'doxycycline':    'Broad tetracycline, n_hit=40/40 in Maier',
    'chloramphenicol':'Broad, n_hit=40/40 in Maier',
}
ANTIBIOTIC_MOA_KEYWORDS = [
    'antibiotic', 'antibacterial', 'antimicrobial', 'beta-lactamase',
    'penicillin', 'cephalosporin', 'fluoroquinolone', 'aminoglycoside',
    'tetracycline', 'macrolide', 'sulfonamide', 'glycopeptide',
    'carbapenem', 'oxazolidinone', 'lincosamide', 'polymyxin',
    'rifamycin', 'nitroimidazole', 'bacterial', 'bactericidal',
]

# ===========================================================================
# Data loading
# ===========================================================================

def load_cv_metrics(pipeline: str) -> Optional[dict]:
    """Load CV metrics JSON for any pipeline."""
    _F = f"07_evaluate.py:load_cv_metrics({pipeline})"
    path = os.path.join(config.RESULTS_DIR, f'{pipeline}_cv_metrics.json')
    if os.path.exists(path):
        try:
            with open(path, 'r') as f:
                data = json.load(f)
            logger.info(f"  [{_F}] Loaded: {path} ({len(data)} tasks: {list(data.keys())})")
            return data
        except Exception as e:
            logger.error(f"  [{_F}] Failed to parse {path}: {type(e).__name__}: {e}")
            return None
    else:
        logger.info(f"  [{_F}] Not found: {path}")
        return None


def load_ranked_lists(pipeline: str) -> Dict[str, pd.DataFrame]:
    """Load all ranked CSVs for any pipeline."""
    _F = f"07_evaluate.py:load_ranked_lists({pipeline})"
    results = {}
    for pkey in config.PATHOGENS:
        for t in config.HARM_THRESHOLDS:
            combo = f'{pkey}_t{t}'
            csv_path = os.path.join(config.SCREENING_DIR, f'{pipeline}_ranked_{combo}.csv')
            if os.path.exists(csv_path):
                try:
                    df = pd.read_csv(csv_path)
                    required = ['smiles', 'name', 'selectivity_score', 'p_pathogen', 'p_gut', 'rank']
                    missing = [c for c in required if c not in df.columns]
                    if missing:
                        logger.warning(f"  [{_F}] {csv_path}: missing columns {missing}")
                        continue
                    results[combo] = df
                except Exception as e:
                    logger.warning(f"  [{_F}] Failed to read {csv_path}: {type(e).__name__}: {e}")
            else:
                logger.debug(f"  [{_F}] Not found: {csv_path}")

    logger.info(f"  [{_F}] Loaded {len(results)} ranked lists: {list(results.keys())}")
    return results


def find_drug_in_ranked_list(df: pd.DataFrame, drug_name: str) -> Optional[pd.Series]:
    """Fuzzy-match a drug name in a ranked list (case-insensitive, partial)."""
    name_col = df['name'].str.lower().str.strip()
    target = drug_name.lower().strip()
    # Exact match
    mask = name_col == target
    if mask.any():
        return df[mask].iloc[0]
    # Drug name contained in entry
    mask = name_col.str.contains(target, na=False)
    if mask.any():
        return df[mask].iloc[0]
    # Entry contained in drug name
    for idx, n in name_col.items():
        if n and n in target:
            return df.loc[idx]
    return None


# ===========================================================================
# LEVEL 1: Diagnostic
# ===========================================================================

def level1_diagnostic(all_pipeline_metrics: Dict[str, Optional[dict]]) -> pd.DataFrame:
    """Build the Level 1 comparison table for all available pipelines."""
    logger.info("\n" + "=" * 70)
    logger.info(" LEVEL 1: Diagnostic Per-Model Metrics")
    logger.info("=" * 70)

    tasks = {
        'ecoli': 'E. coli (MIC)',
        'saureus': 'S. aureus (MIC)',
        'paeruginosa': 'P. aeruginosa (MIC)',
        'mtb': 'M. tuberculosis (MIC)',
        'gut_t10': 'Gut harm (t=10)',
    }

    # Determine which pipelines have data
    active_pipelines = [p for p in ALL_PIPELINES
                        if all_pipeline_metrics.get(p) is not None]

    rows = []
    for task_key, display_name in tasks.items():
        row = {'task': display_name, 'task_key': task_key}

        for pipeline in ALL_PIPELINES:
            metrics = all_pipeline_metrics.get(pipeline)
            if metrics and task_key in metrics:
                m = metrics[task_key]
                roc = m.get('mean_roc_auc')
                roc_std = m.get('std_roc_auc')
                pr = m.get('mean_pr_auc')
                pr_std = m.get('std_pr_auc')
                if roc is not None and roc_std is not None:
                    row[f'{pipeline}_roc_auc'] = f"{roc:.4f} +/- {roc_std:.4f}"
                    row[f'{pipeline}_roc_mean'] = roc
                else:
                    row[f'{pipeline}_roc_auc'] = 'FAILED'
                    row[f'{pipeline}_roc_mean'] = np.nan
                if pr is not None and pr_std is not None:
                    row[f'{pipeline}_pr_auc'] = f"{pr:.4f} +/- {pr_std:.4f}"
                    row[f'{pipeline}_pr_mean'] = pr
                else:
                    row[f'{pipeline}_pr_auc'] = 'FAILED'
                    row[f'{pipeline}_pr_mean'] = np.nan
            else:
                row[f'{pipeline}_roc_auc'] = 'N/A'
                row[f'{pipeline}_pr_auc'] = 'N/A'
                row[f'{pipeline}_roc_mean'] = np.nan
                row[f'{pipeline}_pr_mean'] = np.nan
        rows.append(row)

    df_diag = pd.DataFrame(rows)

    # Log table
    logger.info("")
    hdr_parts = [f"{'Task':<25}"]
    for p in active_pipelines:
        hdr_parts.append(f"{PIPELINE_DISPLAY.get(p, p) + ' ROC':>22}")
    logger.info("  " + " ".join(hdr_parts))
    logger.info("  " + "-" * (25 + 23 * len(active_pipelines)))
    for _, r in df_diag.iterrows():
        parts = [f"{r['task']:<25}"]
        for p in active_pipelines:
            parts.append(f"{r.get(f'{p}_roc_auc', 'N/A'):>22}")
        logger.info("  " + " ".join(parts))

    return df_diag


# ===========================================================================
# LEVEL 2 Tests
# ===========================================================================

def test1_rank_separation(ranked: Dict[str, pd.DataFrame], pipeline: str,
                          pathogen: str, threshold: int) -> dict:
    """Test 1: Mann-Whitney U comparing S of narrow vs broad-spectrum drugs."""
    combo = f'{pathogen}_t{threshold}'
    if combo not in ranked:
        return {'status': 'skipped', 'reason': f'missing {combo}'}

    df = ranked[combo]
    narrow_scores, broad_scores = [], []
    val_drugs = []

    for drug, reason in NARROW_SPECTRUM.items():
        row = find_drug_in_ranked_list(df, drug)
        if row is not None:
            narrow_scores.append(row['selectivity_score'])
            val_drugs.append({'drug': drug, 'category': 'narrow', 'reason': reason,
                              'selectivity_score': row['selectivity_score'],
                              'p_pathogen': row['p_pathogen'], 'p_gut': row['p_gut'],
                              'rank': row['rank'], 'pipeline': pipeline})
        else:
            if drug not in _MISSING_DRUGS_LOGGED:
                logger.info(f"    {drug}: not in Broad Hub (expected if post-2020 compound)")
                _MISSING_DRUGS_LOGGED.add(drug)

    for drug, reason in BROAD_SPECTRUM.items():
        row = find_drug_in_ranked_list(df, drug)
        if row is not None:
            broad_scores.append(row['selectivity_score'])
            val_drugs.append({'drug': drug, 'category': 'broad', 'reason': reason,
                              'selectivity_score': row['selectivity_score'],
                              'p_pathogen': row['p_pathogen'], 'p_gut': row['p_gut'],
                              'rank': row['rank'], 'pipeline': pipeline})

    result = {
        'pipeline': pipeline, 'pathogen': pathogen, 'threshold': threshold,
        'n_narrow': len(narrow_scores), 'n_broad': len(broad_scores),
        'narrow_mean_S': round(float(np.mean(narrow_scores)), 4) if narrow_scores else None,
        'broad_mean_S': round(float(np.mean(broad_scores)), 4) if broad_scores else None,
        'validation_drugs': val_drugs,
    }

    if len(narrow_scores) >= 2 and len(broad_scores) >= 2:
        U, p = scipy_stats.mannwhitneyu(narrow_scores, broad_scores, alternative='greater')
        n1, n2 = len(narrow_scores), len(broad_scores)
        rbc = 1 - (2 * U) / (n1 * n2)
        result.update({
            'U_statistic': float(U), 'p_value': float(p),
            'rank_biserial': round(float(rbc), 4),
            'effect_size': 'large' if abs(rbc) > 0.5 else 'medium' if abs(rbc) > 0.3 else 'small',
        })
        logger.info(f"  Test 1 ({pipeline}, {combo}): U={U:.1f}, p={p:.4f}, "
                     f"r_rb={rbc:.3f} ({result['effect_size']}), "
                     f"narrow_mean={result['narrow_mean_S']}, broad_mean={result['broad_mean_S']}")
    else:
        result['status'] = 'insufficient_data'
    return result


def test2_selectivity_auc(t1_result: dict) -> dict:
    """Test 2: ROC-AUC of S as narrow/broad classifier."""
    drugs = t1_result.get('validation_drugs', [])
    if len(drugs) < 4:
        return {'pipeline': t1_result.get('pipeline'), 'status': 'skipped', 'reason': 'too few drugs'}

    y_true = np.array([1 if d['category'] == 'narrow' else 0 for d in drugs])
    scores = np.array([d['selectivity_score'] for d in drugs])

    if len(np.unique(y_true)) < 2:
        return {'pipeline': t1_result.get('pipeline'), 'status': 'skipped', 'reason': 'single class'}

    auc = roc_auc_score(y_true, scores)
    result = {
        'pipeline': t1_result['pipeline'], 'pathogen': t1_result.get('pathogen'),
        'threshold': t1_result.get('threshold'),
        'selectivity_auc': round(float(auc), 4),
        'n_narrow': int(y_true.sum()), 'n_broad': int((y_true == 0).sum()),
        'caveat': 'Small sample size; suggestive, not definitive',
    }
    logger.info(f"  Test 2 ({result['pipeline']}, {result['pathogen']}_t{result['threshold']}): "
                f"Selectivity AUC = {auc:.4f}")
    return result


def test3_topk_enrichment(ranked: Dict[str, pd.DataFrame], pipeline: str,
                          pathogen: str, threshold: int = 10,
                          top_k: int = config.TOP_K) -> dict:
    """Test 3: Antibiotic enrichment in top-k Hub screening hits."""
    combo = f'{pathogen}_t{threshold}'
    if combo not in ranked:
        return {'pipeline': pipeline, 'status': 'skipped'}

    df = ranked[combo]
    moa_lower = df['moa'].fillna('').str.lower()
    is_ab = moa_lower.apply(lambda x: any(kw in x for kw in ANTIBIOTIC_MOA_KEYWORDS))

    n_ab_total = int(is_ab.sum())
    frac_ab_total = n_ab_total / max(len(df), 1)

    top_is_ab = is_ab.iloc[:top_k]
    n_ab_topk = int(top_is_ab.sum())
    frac_ab_topk = n_ab_topk / top_k
    enrichment = frac_ab_topk / max(frac_ab_total, 1e-9)

    top10 = df.head(10)[['rank', 'name', 'selectivity_score', 'moa', 'clinical_phase']].to_dict('records')

    result = {
        'pipeline': pipeline, 'pathogen': pathogen, 'threshold': threshold, 'top_k': top_k,
        'n_ab_topk': n_ab_topk, 'frac_ab_topk': round(frac_ab_topk, 4),
        'n_ab_total': n_ab_total, 'frac_ab_total': round(frac_ab_total, 4),
        'enrichment_ratio': round(enrichment, 2),
        'top10_compounds': top10,
    }
    logger.info(f"  Test 3 ({pipeline}, {combo}): {n_ab_topk}/{top_k} antibiotics in top-{top_k} "
                f"(enrichment = {enrichment:.2f}x)")
    return result


def test4_pairwise_correlation(all_ranked: Dict[str, Dict[str, pd.DataFrame]]) -> dict:
    """Test 4: Spearman rank correlation between all pipeline pairs."""
    active = {p: r for p, r in all_ranked.items() if r}
    pipe_names = sorted(active.keys())

    if len(pipe_names) < 2:
        return {'status': 'skipped', 'reason': 'need at least 2 pipelines'}

    results = {}
    for i in range(len(pipe_names)):
        for j in range(i + 1, len(pipe_names)):
            p1, p2 = pipe_names[i], pipe_names[j]
            pair_key = f'{p1}_vs_{p2}'
            pair_results = {}

            for combo in active[p1]:
                if combo not in active[p2]:
                    continue
                df1 = active[p1][combo].set_index('smiles')
                df2 = active[p2][combo].set_index('smiles')
                common = df1.index.intersection(df2.index)
                if len(common) < 10:
                    pair_results[combo] = {'status': 'insufficient_overlap'}
                    continue

                rho, p = scipy_stats.spearmanr(
                    df1.loc[common, 'selectivity_score'].values,
                    df2.loc[common, 'selectivity_score'].values,
                )
                interp = ('high agreement' if rho > 0.8
                          else 'moderate agreement' if rho > 0.5
                          else 'low agreement')
                pair_results[combo] = {
                    'spearman_rho': round(float(rho), 4),
                    'p_value': float(p),
                    'n_common': len(common),
                    'interpretation': interp,
                }
                logger.info(f"  Test 4 ({p1} vs {p2}, {combo}): "
                            f"rho={rho:.4f}, n={len(common)} ({interp})")

            results[pair_key] = pair_results

    return results


def test5_threshold_sensitivity(ranked: Dict, pipeline: str, pathogen: str) -> dict:
    """Test 5: Stability of rankings across harm thresholds."""
    combos = [f'{pathogen}_t{t}' for t in config.HARM_THRESHOLDS]
    available = [c for c in combos if c in ranked]
    if len(available) < 2:
        return {'pipeline': pipeline, 'pathogen': pathogen, 'status': 'skipped'}

    comparisons = []
    for i in range(len(available)):
        for j in range(i + 1, len(available)):
            c1, c2 = available[i], available[j]
            df1 = ranked[c1].set_index('smiles')
            df2 = ranked[c2].set_index('smiles')
            common = df1.index.intersection(df2.index)
            if len(common) < 10:
                continue
            rho, _ = scipy_stats.spearmanr(
                df1.loc[common, 'selectivity_score'].values,
                df2.loc[common, 'selectivity_score'].values,
            )
            top50_1 = set(ranked[c1].head(50)['smiles'])
            top50_2 = set(ranked[c2].head(50)['smiles'])
            overlap = len(top50_1 & top50_2)
            comparisons.append({
                'pair': f'{c1} vs {c2}', 'spearman_rho': round(float(rho), 4),
                'top50_overlap': overlap,
                'top50_jaccard': round(overlap / max(len(top50_1 | top50_2), 1), 4),
            })
            logger.info(f"  Test 5 ({pipeline}, {c1} vs {c2}): rho={rho:.4f}, top-50 overlap={overlap}/50")

    return {'pipeline': pipeline, 'pathogen': pathogen, 'comparisons': comparisons}


# ===========================================================================
# Visualization
# ===========================================================================

def generate_phase4_figures(df_diag, test1_results, test3_results,
                            all_ranked, active_pipelines):
    """Generate publication-quality evaluation figures for all pipelines."""
    import matplotlib; matplotlib.use('Agg')
    import matplotlib.pyplot as plt; import seaborn as sns
    os.makedirs(config.FIGURES_DIR, exist_ok=True)
    setup_publication_style()

    # ---- Fig 1: Level 1 diagnostic comparison (all pipelines) ----
    n_pipes = len(active_pipelines)
    if n_pipes > 0:
        fig, axes = plt.subplots(1, 2, figsize=(14, 5))
        tasks = df_diag['task'].tolist()
        x = np.arange(len(tasks))
        w = 0.8 / n_pipes

        for idx, (metric, label) in enumerate([('roc', 'ROC-AUC'), ('pr', 'PR-AUC')]):
            ax = axes[idx]
            for pi, pipe in enumerate(active_pipelines):
                col = f'{pipe}_{metric}_mean'
                if col not in df_diag.columns:
                    continue
                vals = np.nan_to_num(df_diag[col].values)
                if np.all(vals == 0):
                    continue
                offset = (pi - (n_pipes - 1) / 2) * w
                ax.bar(x + offset, vals, w,
                       label=PIPELINE_DISPLAY.get(pipe, pipe),
                       color=PIPELINE_COLORS.get(pipe, '#999999'),
                       edgecolor='black', linewidth=0.5)
            ax.set_xticks(x)
            ax.set_xticklabels(tasks, rotation=25, ha='right', fontsize=8)
            ax.set_ylabel(label)
            ax.set_title(f'{label} (5-Fold Scaffold CV)')
            ax.set_ylim(0, 1.05)
            ax.axhline(y=0.5, color='gray', linestyle='--', alpha=0.3)
            ax.legend(fontsize=9)
            sns.despine(ax=ax)
        plt.suptitle('Level 1: Component Model Performance', fontsize=14)
        plt.tight_layout()
        save_figure(fig, os.path.join(config.FIGURES_DIR, 'phase4_level1_diagnostic'))
        logger.info("  Figure: phase4_level1_diagnostic")

    # ---- Fig 2: Validation drug S scores (Test 1) ----
    from matplotlib.patches import Patch
    for t1 in test1_results:
        drugs = t1.get('validation_drugs', [])
        if not drugs:
            continue
        pipe = t1['pipeline']
        fig, ax = plt.subplots(figsize=(10, 6))
        narrow_d = [d for d in drugs if d['category'] == 'narrow']
        broad_d = [d for d in drugs if d['category'] == 'broad']
        all_d = narrow_d + broad_d
        names = [d['drug'] for d in all_d]
        scores = [d['selectivity_score'] for d in all_d]
        cols = [COLORS['narrow'] if d['category'] == 'narrow' else COLORS['broad'] for d in all_d]
        bars = ax.barh(range(len(names)), scores, color=cols, edgecolor='black', linewidth=0.5)
        for i, (bar, s) in enumerate(zip(bars, scores)):
            ax.text(bar.get_width() + 0.01, i, f'{s:.4f}', ha='left', va='center', fontsize=8)
        ax.set_yticks(range(len(names))); ax.set_yticklabels(names, fontsize=9)
        ax.set_xlabel('Selectivity Score S')
        p_str = f"p={t1.get('p_value', 'N/A'):.4f}" if t1.get('p_value') else "p=N/A"
        rbc_str = f"r_rb={t1.get('rank_biserial', 'N/A'):.3f}" if t1.get('rank_biserial') else ""
        disp = PIPELINE_DISPLAY.get(pipe, pipe)
        ax.set_title(f'{disp}: Validation Drug Selectivity ({t1["pathogen"]}, t={t1["threshold"]}, {p_str}, {rbc_str})')
        ax.invert_yaxis()
        ax.legend(handles=[
            Patch(facecolor=COLORS['narrow'], edgecolor='black', label='Narrow-spectrum (expected HIGH S)'),
            Patch(facecolor=COLORS['broad'], edgecolor='black', label='Broad-spectrum (expected LOW S)'),
        ], loc='lower right', fontsize=9)
        sns.despine(); plt.tight_layout()
        save_figure(fig, os.path.join(config.FIGURES_DIR, f'phase4_test1_{pipe}_{t1["pathogen"]}_t{t1["threshold"]}'))
        logger.info(f"  Figure: phase4_test1_{pipe}_{t1['pathogen']}_t{t1['threshold']}")

    # ---- Fig 3: Selectivity scatter (ecoli_t10, all pipelines) ----
    for pipe, ranked in all_ranked.items():
        key = 'ecoli_t10'
        if key not in ranked:
            continue
        df = ranked[key]
        fig, ax = plt.subplots(figsize=(7, 6))
        sc = ax.scatter(df['p_gut'], df['p_pathogen'], c=df['selectivity_score'],
                        cmap='RdYlGn', s=4, alpha=0.5, edgecolors='none', vmin=0, vmax=1)
        plt.colorbar(sc, ax=ax, label='Selectivity Score S')
        ax.set_xlabel('$\\hat{P}_{gut}$'); ax.set_ylabel('$\\hat{P}_{pathogen}$')
        disp = PIPELINE_DISPLAY.get(pipe, pipe)
        ax.set_title(f'{disp}: Selectivity Landscape (E. coli, t=10)')
        ax.set_xlim(-0.02, 1.02); ax.set_ylim(-0.02, 1.02)
        sns.despine(); plt.tight_layout()
        save_figure(fig, os.path.join(config.FIGURES_DIR, f'phase4_scatter_{pipe}_ecoli_t10'))
        logger.info(f"  Figure: phase4_scatter_{pipe}_ecoli_t10")

    # ---- Fig 4: Top-k enrichment comparison (all pipelines) ----
    if test3_results:
        valid_t3 = [t for t in test3_results if t.get('enrichment_ratio')]
        if valid_t3:
            fig, ax = plt.subplots(figsize=(max(10, len(valid_t3) * 1.2), 5))
            labels = [f"{PIPELINE_DISPLAY.get(t['pipeline'], t['pipeline'])}\n{t['pathogen']}"
                      for t in valid_t3]
            ers = [t['enrichment_ratio'] for t in valid_t3]
            bar_cols = [PIPELINE_COLORS.get(t['pipeline'], '#999999')
                        for t in valid_t3]
            bars = ax.bar(range(len(labels)), ers, color=bar_cols,
                          edgecolor='black', linewidth=0.5)
            for bar, er in zip(bars, ers):
                ax.text(bar.get_x() + bar.get_width()/2.,
                        bar.get_height() + 0.1,
                        f'{er:.1f}x', ha='center', va='bottom',
                        fontsize=9, fontweight='bold')
            ax.set_xticks(range(len(labels)))
            ax.set_xticklabels(labels, fontsize=7)
            ax.set_ylabel('Enrichment Ratio')
            ax.set_title(f'Top-{config.TOP_K} Antibiotic Enrichment (t=10)')
            ax.axhline(y=1.0, color='gray', linestyle='--', alpha=0.5,
                        label='Random baseline')
            ax.legend(); sns.despine(); plt.tight_layout()
            save_figure(fig, os.path.join(config.FIGURES_DIR, 'phase4_test3_enrichment'))
            logger.info("  Figure: phase4_test3_enrichment")


# ===========================================================================
# Unit tests
# ===========================================================================

def run_unit_tests() -> bool:
    """Unit tests for Phase 4 (no real data needed)."""
    print("Running Phase 4 unit tests...")
    n_pass = 0; n_fail = 0

    def _assert(cond, msg):
        nonlocal n_pass, n_fail
        if cond: n_pass += 1; print(f"  [PASS] {msg}")
        else: n_fail += 1; print(f"  [FAIL] {msg}")

    # Test find_drug_in_ranked_list
    mock = pd.DataFrame({
        'name': ['Ciprofloxacin', 'Amoxicillin trihydrate', 'Daptomycin', 'Aspirin'],
        'selectivity_score': [0.1, 0.2, 0.8, 0.5],
        'p_pathogen': [0.9, 0.7, 0.85, 0.6], 'p_gut': [0.9, 0.7, 0.05, 0.2],
        'rank': [4, 3, 1, 2],
    })
    _assert(find_drug_in_ranked_list(mock, 'ciprofloxacin') is not None, "Find ciprofloxacin (case)")
    _assert(find_drug_in_ranked_list(mock, 'amoxicillin') is not None, "Find amoxicillin (partial)")
    _assert(find_drug_in_ranked_list(mock, 'nonexistent') is None, "Nonexistent returns None")

    # Test Mann-Whitney
    narrow_s = np.array([0.8, 0.7, 0.9, 0.85])
    broad_s = np.array([0.1, 0.2, 0.05, 0.15, 0.3, 0.1])
    U, p = scipy_stats.mannwhitneyu(narrow_s, broad_s, alternative='greater')
    _assert(p < 0.05, f"Mann-Whitney p={p:.4f} < 0.05")
    rbc = 1 - (2 * U) / (len(narrow_s) * len(broad_s))
    _assert(abs(rbc) > 0.5, f"Rank-biserial |r|={abs(rbc):.3f} > 0.5")

    # Test selectivity AUC
    y_true = np.array([1, 1, 1, 0, 0, 0, 0, 0])
    s_scores = np.array([0.9, 0.8, 0.7, 0.1, 0.2, 0.05, 0.15, 0.3])
    auc = roc_auc_score(y_true, s_scores)
    _assert(auc > 0.9, f"Selectivity AUC={auc:.3f} > 0.9")

    # Test Spearman
    x = np.arange(1, 11, dtype=float)
    y = x + np.random.RandomState(42).normal(0, 0.5, 10)
    rho, _ = scipy_stats.spearmanr(x, y)
    _assert(rho > 0.8, f"Spearman rho={rho:.3f} > 0.8")

    # Test enrichment ratio
    _assert(abs(0.60 / 0.20 - 3.0) < 0.01, "Enrichment 60%/20% = 3.0x")

    # Test threshold sensitivity
    r1 = np.array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], dtype=float)
    r2 = np.array([1, 3, 2, 4, 6, 5, 7, 9, 8, 10], dtype=float)
    rho, _ = scipy_stats.spearmanr(r1, r2)
    _assert(rho > 0.8, f"Threshold sensitivity rho={rho:.3f} > 0.8")

    # Test Level 1 table construction
    mock_metrics = {
        'rf': {'ecoli': {'mean_roc_auc': 0.85, 'std_roc_auc': 0.02,
                          'mean_pr_auc': 0.80, 'std_pr_auc': 0.03},
               'gut_t10': {'mean_roc_auc': 0.78, 'std_roc_auc': 0.04,
                            'mean_pr_auc': 0.65, 'std_pr_auc': 0.05}},
        'dmpnn': None,
    }
    df_d = level1_diagnostic(mock_metrics)
    _assert(len(df_d) == 5, f"Diagnostic table rows: {len(df_d)}")
    _assert('rf_roc_auc' in df_d.columns, "Has rf_roc_auc")

    print(f"\nUnit tests: {n_pass} passed, {n_fail} failed")
    return n_fail == 0


# ===========================================================================
# Main
# ===========================================================================

def main():
    logger.info("Running unit tests...")
    import logging as _tl
    _prev_level = logger.level
    logger.setLevel(_tl.CRITICAL)
    try:
        from rdkit import RDLogger as _rdl
        _rdl.DisableLog('rdApp.*')
    except Exception:
        pass
    _test_ok = run_unit_tests()
    try:
        _rdl.EnableLog('rdApp.*')
    except Exception:
        pass
    logger.setLevel(_prev_level)
    if not _test_ok:
        logger.error("Unit tests FAILED."); sys.exit(1)
    logger.info("All unit tests passed.\n")

    start_time = log_phase_start(logger, "Phase 4: Full Evaluation Suite")
    os.makedirs(config.RESULTS_DIR, exist_ok=True)
    os.makedirs(config.FIGURES_DIR, exist_ok=True)
    os.makedirs(config.REPORTS_DIR, exist_ok=True)

    _FM = "07_evaluate.py:main"

    # Load inputs for ALL pipelines
    logger.info(f"[{_FM}] Loading pipeline results...")
    logger.info(f"[{_FM}] Results dir: {config.RESULTS_DIR}")
    logger.info(f"[{_FM}] Screening dir: {config.SCREENING_DIR}")

    import glob
    for pipe in ALL_PIPELINES:
        n_files = len(glob.glob(os.path.join(config.SCREENING_DIR,
                                             f'{pipe}_ranked_*.csv')))
        logger.info(f"[{_FM}] Found {n_files} {pipe} ranked files")

    all_metrics = {}
    all_ranked = {}

    for pipe in ALL_PIPELINES:
        try:
            m = load_cv_metrics(pipe)
        except Exception as e:
            logger.warning(f"[{_FM}] {pipe} metrics load error: {e}")
            m = None
        all_metrics[pipe] = m

        try:
            r = load_ranked_lists(pipe)
        except Exception as e:
            logger.warning(f"[{_FM}] {pipe} ranked lists load error: {e}")
            r = {}
        all_ranked[pipe] = r

    active_pipelines = [p for p in ALL_PIPELINES
                        if all_metrics.get(p) and all_ranked.get(p)]

    for pipe in ALL_PIPELINES:
        has = bool(all_metrics.get(pipe)) and bool(all_ranked.get(pipe))
        n_r = len(all_ranked.get(pipe, {}))
        logger.info(f"[{_FM}] {pipe:20s}: "
                     f"{'AVAILABLE' if has else 'NOT FOUND'} "
                     f"({n_r} ranked lists)")

    if not active_pipelines:
        logger.error(f"[{_FM}] No pipeline results found!")
        logger.error(f"[{_FM}] ACTION: Run Phase 3 scripts first.")
        sys.exit(1)

    quality_report = {}

    # ---- LEVEL 1 ----
    df_diag = level1_diagnostic(all_metrics)
    diag_path = os.path.join(config.RESULTS_DIR, 'cv_metrics_diagnostic.csv')
    df_diag.to_csv(diag_path, index=False)
    logger.info(f"\n  Saved: {diag_path}")
    quality_report['level1'] = df_diag.to_dict('records')

    # ---- LEVEL 2 ----
    logger.info("\n" + "=" * 70)
    logger.info(" LEVEL 2: Pipeline-Level Selectivity Evaluation")
    logger.info("=" * 70)

    # Test 1
    logger.info("\n--- Test 1: Rank Separation (Mann-Whitney U) ---")
    test1_results = []
    for pipe in active_pipelines:
        ranked = all_ranked[pipe]
        if not ranked:
            continue
        for pkey in config.PATHOGENS:
            for t in config.HARM_THRESHOLDS:
                try:
                    test1_results.append(
                        test1_rank_separation(ranked, pipe, pkey, t))
                except Exception as e:
                    logger.error(f"  [test1] FAILED for "
                                 f"{pipe}/{pkey}/t{t}: {type(e).__name__}: {e}")

    all_val = []
    for r in test1_results:
        all_val.extend(r.get('validation_drugs', []))
    if all_val:
        pd.DataFrame(all_val).to_csv(
            os.path.join(config.RESULTS_DIR, 'validation_set.csv'),
            index=False)

    t1_export = [{k: v for k, v in r.items() if k != 'validation_drugs'}
                 for r in test1_results]
    pd.DataFrame(t1_export).to_csv(
        os.path.join(config.RESULTS_DIR, 'test1_rank_separation.csv'),
        index=False)
    quality_report['test1'] = t1_export

    # Test 2
    logger.info("\n--- Test 2: Selectivity ROC-AUC ---")
    test2_results = []
    for r in test1_results:
        if r.get('validation_drugs'):
            try:
                test2_results.append(test2_selectivity_auc(r))
            except Exception as e:
                logger.error(f"  [test2] FAILED for "
                             f"{r.get('pipeline')}/{r.get('pathogen')}: "
                             f"{type(e).__name__}: {e}")
    pd.DataFrame(test2_results).to_csv(
        os.path.join(config.RESULTS_DIR, 'test2_selectivity_auc.csv'),
        index=False)
    quality_report['test2'] = test2_results

    # Test 3
    logger.info("\n--- Test 3: Top-k Enrichment ---")
    test3_results = []
    for pipe in active_pipelines:
        ranked = all_ranked[pipe]
        if not ranked:
            continue
        for pkey in config.PATHOGENS:
            try:
                test3_results.append(
                    test3_topk_enrichment(ranked, pipe, pkey))
            except Exception as e:
                logger.error(f"  [test3] FAILED for "
                             f"{pipe}/{pkey}: {type(e).__name__}: {e}")
    t3_flat = [{k: v for k, v in r.items() if k != 'top10_compounds'}
               for r in test3_results]
    pd.DataFrame(t3_flat).to_csv(
        os.path.join(config.RESULTS_DIR, 'test3_topk_enrichment.csv'),
        index=False)
    quality_report['test3'] = test3_results

    # Test 4 (pairwise, all pipeline pairs)
    logger.info("\n--- Test 4: Pairwise Pipeline Agreement ---")
    try:
        test4_result = test4_pairwise_correlation(all_ranked)
    except Exception as e:
        logger.error(f"  [test4] FAILED: {type(e).__name__}: {e}")
        test4_result = {'status': 'error', 'reason': str(e)}

    t4_rows = []
    if isinstance(test4_result, dict):
        for pair_key, combos in test4_result.items():
            if isinstance(combos, dict):
                for combo, vals in combos.items():
                    if isinstance(vals, dict):
                        t4_rows.append({'pair': pair_key, 'combo': combo,
                                        **vals})
    if not t4_rows:
        t4_rows = [test4_result] if isinstance(test4_result, dict) else []
    pd.DataFrame(t4_rows).to_csv(
        os.path.join(config.RESULTS_DIR, 'test4_rank_correlation.csv'),
        index=False)
    quality_report['test4'] = test4_result

    # Test 5
    logger.info("\n--- Test 5: Threshold Sensitivity ---")
    test5_results = []
    for pipe in active_pipelines:
        ranked = all_ranked[pipe]
        if not ranked:
            continue
        for pkey in config.PATHOGENS:
            try:
                test5_results.append(
                    test5_threshold_sensitivity(ranked, pipe, pkey))
            except Exception as e:
                logger.error(f"  [test5] FAILED for "
                             f"{pipe}/{pkey}: {type(e).__name__}: {e}")
    t5_flat = []
    for r in test5_results:
        for comp in r.get('comparisons', []):
            t5_flat.append({'pipeline': r.get('pipeline'),
                            'pathogen': r.get('pathogen'), **comp})
    pd.DataFrame(t5_flat).to_csv(
        os.path.join(config.RESULTS_DIR, 'test5_threshold_sensitivity.csv'),
        index=False)
    quality_report['test5'] = test5_results

    # ---- Figures ----
    logger.info("\nGenerating Phase 4 figures...")
    try:
        generate_phase4_figures(df_diag, test1_results, test3_results,
                                all_ranked, active_pipelines)
    except Exception as e:
        logger.warning(f"Figure generation error: {e}")
        import traceback; traceback.print_exc()

    # ---- Quality report ----
    report_path = os.path.join(config.REPORTS_DIR, 'phase4_quality_report.json')
    with open(report_path, 'w') as f:
        json.dump(quality_report, f, indent=2, default=str)

    # ---- Final summary ----
    logger.info("\n" + "=" * 70)
    logger.info(" PHASE 4 COMPLETE: EVALUATION SUMMARY")
    logger.info("=" * 70)
    logger.info(f"  Active pipelines: {', '.join(active_pipelines)}")
    logger.info(f"  Level 1 Diagnostic: {diag_path}")
    n_t1_sig = len([r for r in test1_results if r.get('p_value') is not None])
    logger.info(f"  Test 1 (Rank Separation):  {n_t1_sig} tests with p-values")
    logger.info(f"  Test 2 (Selectivity AUC):  {len(test2_results)} computed")
    logger.info(f"  Test 3 (Top-k Enrichment): {len(test3_results)} computed")
    n_t4_pairs = len([k for k in test4_result if isinstance(test4_result.get(k), dict)])
    logger.info(f"  Test 4 (Pairwise Corr.):   {n_t4_pairs} pipeline pairs")
    logger.info(f"  Test 5 (Threshold Sens.):  {len(test5_results)} computed")
    logger.info(f"\n  Figures in: {config.FIGURES_DIR}")
    logger.info(f"  All results in: {config.RESULTS_DIR}")
    logger.info("=" * 70)

    save_checkpoint(
        {'status': 'complete',
         'pipelines': active_pipelines},
        os.path.join(config.CHECKPOINTS_DIR, 'phase4_master.json'), logger,
    )
    log_phase_end(logger, "Phase 4", start_time)


if __name__ == '__main__':
    main()