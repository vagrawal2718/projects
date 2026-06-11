#!/usr/bin/env python3
"""
05_train_rf.py -- Phase 3A: Random Forest Pipeline Training

Trains 7 RF models (4 pathogens + 3 gut harm thresholds) using Morgan
fingerprints with 5-fold scaffold-based cross-validation.

For each model:
  1. Load Morgan FPs and scaffold folds from Phase 2
  2. Run 5-fold CV, collecting OOF predictions
  3. Compute diagnostic metrics (ROC-AUC, PR-AUC per fold)
  4. Train final model on all data
  5. Save model (.pkl) and per-fold predictions

Then:
  6. Screen the Drug Repurposing Hub with all 7 final models
  7. Compute selectivity scores S = P_pathogen * (1 - P_gut)
     for 4 pathogens x 3 thresholds = 12 combinations
  8. Save 12 ranked lists
  9. Generate publication-quality figures

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import os, sys, json, time, logging, warnings, pickle
from typing import Dict, List, Tuple

import numpy as np
import pandas as pd
from scipy import sparse
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import roc_auc_score, average_precision_score, roc_curve, precision_recall_curve
from sklearn.calibration import CalibratedClassifierCV

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)

import config
from utils.scaffold_split import load_folds, get_train_test_indices
from utils.logging_utils import (
    setup_logging, log_phase_start, log_phase_end,
    save_checkpoint, load_checkpoint,
)
from utils.viz_utils import (
    setup_publication_style, plot_roc_curve, plot_class_distribution,
    save_figure, COLORS,
)
from utils.full_metrics import compute_full_metrics, aggregate_fold_metrics

warnings.filterwarnings('ignore')
logger = setup_logging('phase3a', log_dir=config.LOGS_DIR)


# ===========================================================================
# Data loading
# ===========================================================================

def load_dataset(name: str) -> Tuple[sparse.csr_matrix, List[int], pd.DataFrame]:
    """
    Load Morgan FP matrix, scaffold folds, and source CSV for a dataset.

    Folds cover ALL rows of the source CSV (from Phase 2). We subset both
    folds and the DataFrame to valid_indices (rows with successful FPs)
    so that X, folds_valid, and df_valid are all aligned.

    Returns (X, folds_valid, df_valid)
    """
    fp_path = os.path.join(config.FEATURES_DIR, f'morgan_{name}.npz')
    idx_path = os.path.join(config.FEATURES_DIR, f'morgan_{name}_indices.json')
    fold_path = os.path.join(config.SPLITS_DIR, f'{name}_scaffold_folds.pkl')

    X = sparse.load_npz(fp_path)

    with open(idx_path, 'r') as f:
        idx_info = json.load(f)
    valid_indices = idx_info['valid_indices']
    source_csv = idx_info['source_csv']

    df = pd.read_csv(source_csv)
    # Subset to valid indices (rows that produced valid fingerprints)
    df_valid = df.iloc[valid_indices].reset_index(drop=True)

    # Folds cover ALL rows; subset to valid_indices for RF alignment
    folds_all = load_folds(fold_path)
    folds_valid = [folds_all[i] for i in valid_indices]

    assert X.shape[0] == len(folds_valid) == len(df_valid), \
        f"Shape mismatch: X={X.shape[0]}, folds={len(folds_valid)}, df={len(df_valid)}"

    logger.info(f"  Loaded {name}: X={X.shape}, folds={len(folds_valid)} "
                f"(from {len(folds_all)} total, {len(folds_all) - len(folds_valid)} dropped)")

    return X, folds_valid, df_valid


def load_screening_library() -> Tuple[sparse.csr_matrix, pd.DataFrame]:
    """Load the Drug Repurposing Hub fingerprints and metadata."""
    fp_path = os.path.join(config.FEATURES_DIR, 'morgan_repurposing_hub.npz')
    idx_path = os.path.join(config.FEATURES_DIR, 'morgan_repurposing_hub_indices.json')

    X = sparse.load_npz(fp_path)

    with open(idx_path, 'r') as f:
        idx_info = json.load(f)
    valid_indices = idx_info['valid_indices']

    df = pd.read_csv(os.path.join(config.HUB_DIR, config.HUB_CLEAN_FILENAME))
    df_valid = df.iloc[valid_indices].reset_index(drop=True)

    assert X.shape[0] == len(df_valid)
    return X, df_valid


# ===========================================================================
# Model training with 5-fold scaffold CV
# ===========================================================================

def train_rf_with_cv(
    X: sparse.csr_matrix,
    y: np.ndarray,
    folds: List[int],
    model_name: str,
) -> Tuple[RandomForestClassifier, dict]:
    """
    Train RF with 5-fold scaffold CV.

    Returns (final_model_trained_on_all_data, metrics_dict).
    metrics_dict contains per-fold and mean ROC-AUC and PR-AUC.
    """
    n_folds = config.N_FOLDS
    fold_metrics = []
    oof_probs = np.full(len(y), np.nan)
    oof_true = np.full(len(y), np.nan)

    logger.info(f"\n  Training RF: {model_name}")
    logger.info(f"  Data: {X.shape[0]} samples, {X.shape[1]} features")
    logger.info(f"  Class balance: {int(y.sum())} positive ({y.mean()*100:.1f}%), "
                f"{int((y==0).sum())} negative")

    from tqdm import tqdm
    for fold_i in tqdm(range(n_folds), desc=f"    CV folds ({model_name})", unit=" fold"):
        _FF = f"05_train_rf.py:train_rf_with_cv({model_name}):fold_{fold_i}"
        try:
            train_idx, test_idx = get_train_test_indices(folds, fold_i)

            X_train, X_test = X[train_idx], X[test_idx]
            y_train, y_test = y[train_idx], y[test_idx]
        except Exception as e:
            logger.error(f"  [{_FF}] Fold split FAILED: {type(e).__name__}: {e}")
            logger.error(f"  [{_FF}] X.shape={X.shape}, len(folds)={len(folds)}, n_folds={n_folds}")
            fold_metrics.append({'fold': fold_i, 'roc_auc': float('nan'), 'pr_auc': float('nan')})
            continue

        # Check for degenerate folds
        if len(np.unique(y_train)) < 2 or len(np.unique(y_test)) < 2:
            logger.warning(f"    Fold {fold_i}: degenerate (single class), skipping")
            continue

        rf = RandomForestClassifier(**config.RF_PARAMS)
        rf.fit(X_train, y_train)

        probs = rf.predict_proba(X_test)[:, 1]
        oof_probs[test_idx] = probs
        oof_true[test_idx] = y_test

        roc = roc_auc_score(y_test, probs)
        pr = average_precision_score(y_test, probs)

        # Full metrics suite for publication-quality comparison
        full_m = compute_full_metrics(y_test, probs)

        fold_metrics.append({'fold': fold_i, 'roc_auc': roc, 'pr_auc': pr,
                             'full_metrics': full_m,
                             'n_train': len(train_idx), 'n_test': len(test_idx)})

        logger.info(f"    Fold {fold_i}: ROC-AUC={roc:.4f}, PR-AUC={pr:.4f} "
                    f"(train={len(train_idx)}, test={len(test_idx)})")

    # Aggregate metrics
    roc_aucs = [m['roc_auc'] for m in fold_metrics]
    pr_aucs = [m['pr_auc'] for m in fold_metrics]

    # Aggregate full metrics suite across folds
    fold_full_list = [m['full_metrics'] for m in fold_metrics if m.get('full_metrics')]
    full_metrics_agg = aggregate_fold_metrics(fold_full_list) if fold_full_list else {}

    metrics = {
        'model_name': model_name,
        'n_samples': int(len(y)),
        'n_positive': int(y.sum()),
        'n_folds_completed': len(fold_metrics),
        'mean_roc_auc': round(float(np.mean(roc_aucs)), 4),
        'std_roc_auc': round(float(np.std(roc_aucs)), 4),
        'mean_pr_auc': round(float(np.mean(pr_aucs)), 4),
        'std_pr_auc': round(float(np.std(pr_aucs)), 4),
        'full_metrics_agg': full_metrics_agg,
        'per_fold': fold_metrics,
    }

    logger.info(f"  CV Result: ROC-AUC = {metrics['mean_roc_auc']:.4f} "
                f"+/- {metrics['std_roc_auc']:.4f}, "
                f"PR-AUC = {metrics['mean_pr_auc']:.4f} "
                f"+/- {metrics['std_pr_auc']:.4f}")

    # Compute OOF ROC curve for plotting
    valid_mask = ~np.isnan(oof_probs)
    if valid_mask.sum() > 0:
        fpr, tpr, _ = roc_curve(oof_true[valid_mask], oof_probs[valid_mask])
        metrics['oof_fpr'] = fpr.tolist()
        metrics['oof_tpr'] = tpr.tolist()
        metrics['oof_roc_auc'] = round(float(roc_auc_score(oof_true[valid_mask], oof_probs[valid_mask])), 4)

    # Train final model on ALL data
    logger.info(f"  Training final model on all {len(y)} samples...")
    final_rf = RandomForestClassifier(**config.RF_PARAMS)
    final_rf.fit(X, y)

    return final_rf, metrics


# ===========================================================================
# Virtual screening
# ===========================================================================

def screen_hub(
    models: Dict[str, RandomForestClassifier],
    X_hub: sparse.csr_matrix,
    df_hub: pd.DataFrame,
) -> Dict[str, pd.DataFrame]:
    """
    Screen the Drug Repurposing Hub with all RF models and compute
    selectivity scores.

    Returns dict of ranked DataFrames: key = '{pathogen}_t{threshold}'.
    """
    logger.info("\n  Screening Drug Repurposing Hub with RF models...")

    # Predict P_pathogen for each pathogen
    pathogen_probs = {}
    for pkey in config.PATHOGENS:
        model_key = f'rf_{pkey}'
        if model_key in models:
            probs = models[model_key].predict_proba(X_hub)[:, 1]
            pathogen_probs[pkey] = probs
            logger.info(f"    {pkey}: P_pathogen mean={probs.mean():.4f}, "
                        f"median={np.median(probs):.4f}")

    # Predict P_gut for each threshold
    gut_probs = {}
    for t in config.HARM_THRESHOLDS:
        model_key = f'rf_gut_t{t}'
        if model_key in models:
            probs = models[model_key].predict_proba(X_hub)[:, 1]
            gut_probs[t] = probs
            logger.info(f"    gut_t{t}: P_gut mean={probs.mean():.4f}, "
                        f"median={np.median(probs):.4f}")

    # Compute selectivity scores: S = P_pathogen * (1 - P_gut)
    ranked_lists = {}
    for pkey in pathogen_probs:
        for t in gut_probs:
            S = pathogen_probs[pkey] * (1.0 - gut_probs[t])

            df_ranked = df_hub[['smiles', 'name', 'clinical_phase', 'moa',
                                'disease_area', 'target']].copy()
            # Ensure string columns don't have NaN (causes slice errors in figures)
            for col in ['name', 'clinical_phase', 'moa', 'disease_area', 'target']:
                df_ranked[col] = df_ranked[col].fillna('').astype(str)
            df_ranked['p_pathogen'] = pathogen_probs[pkey]
            df_ranked['p_gut'] = gut_probs[t]
            df_ranked['selectivity_score'] = S
            df_ranked = df_ranked.sort_values('selectivity_score', ascending=False).reset_index(drop=True)
            df_ranked['rank'] = range(1, len(df_ranked) + 1)

            list_key = f'{pkey}_t{t}'
            ranked_lists[list_key] = df_ranked

            top5 = df_ranked.head(5)
            logger.info(f"    S_{pkey}_t{t}: top-5 = "
                        f"{list(zip(top5['name'].tolist(), top5['selectivity_score'].round(4).tolist()))}")

    return ranked_lists


# ===========================================================================
# Visualization
# ===========================================================================

def generate_phase3a_figures(all_metrics, ranked_lists):
    import matplotlib; matplotlib.use('Agg')
    import matplotlib.pyplot as plt; import seaborn as sns
    os.makedirs(config.FIGURES_DIR, exist_ok=True)
    setup_publication_style()

    # 1. CV metrics bar chart
    model_names = list(all_metrics.keys())
    roc_means = [all_metrics[m]['mean_roc_auc'] for m in model_names]
    roc_stds = [all_metrics[m]['std_roc_auc'] for m in model_names]
    pr_means = [all_metrics[m]['mean_pr_auc'] for m in model_names]
    pr_stds = [all_metrics[m]['std_pr_auc'] for m in model_names]

    fig, axes = plt.subplots(1, 2, figsize=(14, 5))
    x = np.arange(len(model_names))

    for ax, means, stds, title in [(axes[0], roc_means, roc_stds, 'ROC-AUC'),
                                    (axes[1], pr_means, pr_stds, 'PR-AUC')]:
        bars = ax.bar(x, means, yerr=stds, color=COLORS['rf'], edgecolor='black',
                      linewidth=0.5, capsize=3, width=0.6)
        ax.set_xticks(x)
        ax.set_xticklabels([m.replace('rf_', '') for m in model_names], rotation=30, ha='right', fontsize=9)
        ax.set_ylabel(title)
        ax.set_title(f'RF Pipeline: {title} (5-fold scaffold CV)')
        ax.set_ylim(0, 1.05)
        ax.axhline(y=0.5, color='gray', linestyle='--', alpha=0.3)
        for bar, mean in zip(bars, means):
            ax.text(bar.get_x() + bar.get_width()/2., bar.get_height() + 0.02,
                    f'{mean:.3f}', ha='center', va='bottom', fontsize=8)
        sns.despine(ax=ax)

    plt.tight_layout()
    save_figure(fig, os.path.join(config.FIGURES_DIR, 'phase3a_cv_metrics'))
    logger.info("  Figure: phase3a_cv_metrics")

    # 2. OOF ROC curves for pathogen models
    fig, ax = plt.subplots(figsize=(7, 7))
    colors_list = [COLORS['rf'], COLORS['dmpnn'], COLORS['highlight'], COLORS['broad']]
    pathogen_models = [f'rf_{p}' for p in config.PATHOGENS]
    for i, mkey in enumerate(pathogen_models):
        if mkey in all_metrics and 'oof_fpr' in all_metrics[mkey]:
            m = all_metrics[mkey]
            ax.plot(m['oof_fpr'], m['oof_tpr'], color=colors_list[i % len(colors_list)],
                    linewidth=1.5, label=f"{mkey.replace('rf_', '')} (AUC={m['oof_roc_auc']:.3f})")
    ax.plot([0, 1], [0, 1], 'k--', alpha=0.3)
    ax.set_xlabel('False Positive Rate'); ax.set_ylabel('True Positive Rate')
    ax.set_title('RF Pathogen Models: OOF ROC Curves')
    ax.legend(loc='lower right'); ax.set_aspect('equal')
    sns.despine()
    save_figure(fig, os.path.join(config.FIGURES_DIR, 'phase3a_roc_curves'))
    logger.info("  Figure: phase3a_roc_curves")

    # 3. Selectivity score distribution for one example (E. coli, t=10)
    example_key = 'ecoli_t10'
    if example_key in ranked_lists:
        df_r = ranked_lists[example_key]
        fig, axes = plt.subplots(1, 2, figsize=(13, 5))

        # Panel A: S distribution
        ax = axes[0]
        ax.hist(df_r['selectivity_score'], bins=50, color=COLORS['rf'],
                edgecolor='white', linewidth=0.3, alpha=0.8)
        ax.set_xlabel('Selectivity Score $S = P_{pathogen} \\times (1 - P_{gut})$')
        ax.set_ylabel('Count')
        ax.set_title(f'A. Selectivity Score Distribution\n(E. coli, t=10, RF pipeline)')
        sns.despine(ax=ax)

        # Panel B: P_pathogen vs P_gut scatter
        ax2 = axes[1]
        sc = ax2.scatter(df_r['p_gut'], df_r['p_pathogen'], c=df_r['selectivity_score'],
                         cmap='RdYlGn', s=4, alpha=0.5, edgecolors='none', vmin=0, vmax=1)
        plt.colorbar(sc, ax=ax2, label='Selectivity S')
        ax2.set_xlabel('$P_{gut}$'); ax2.set_ylabel('$P_{pathogen}$')
        ax2.set_title('B. Pathogen Activity vs Gut Harm')
        ax2.set_xlim(-0.02, 1.02); ax2.set_ylim(-0.02, 1.02)
        sns.despine(ax=ax2)

        plt.tight_layout()
        save_figure(fig, os.path.join(config.FIGURES_DIR, 'phase3a_selectivity_example'))
        logger.info("  Figure: phase3a_selectivity_example")

    # 4. Top-20 candidates table figure for E. coli t=10
    if example_key in ranked_lists:
        df_top = ranked_lists[example_key].head(20)
        fig, ax = plt.subplots(figsize=(12, 7))
        ax.axis('off')
        cell_text = []
        for _, row in df_top.iterrows():
            cell_text.append([
                int(row['rank']),
                str(row.get('name', ''))[:25],
                f"{row['selectivity_score']:.4f}",
                f"{row['p_pathogen']:.3f}",
                f"{row['p_gut']:.3f}",
                str(row.get('clinical_phase', ''))[:12],
                str(row.get('moa', ''))[:25],
            ])
        table = ax.table(cellText=cell_text,
                         colLabels=['Rank', 'Name', 'S', 'P_path', 'P_gut', 'Phase', 'MOA'],
                         cellLoc='center', loc='center')
        table.auto_set_font_size(False); table.set_fontsize(8); table.scale(1.1, 1.4)
        for j in range(7):
            table[0, j].set_facecolor('#4472C4')
            table[0, j].set_text_props(color='white', fontweight='bold')
        ax.set_title(f'Top 20 RF Candidates: E. coli, t=10', fontsize=13, fontweight='bold', pad=20)
        plt.tight_layout()
        save_figure(fig, os.path.join(config.FIGURES_DIR, 'phase3a_top20_ecoli'))
        logger.info("  Figure: phase3a_top20_ecoli")


# ===========================================================================
# Unit tests
# ===========================================================================

def run_unit_tests() -> bool:
    """Test RF training logic on synthetic data."""
    print("Running Phase 3A unit tests...")
    n_pass = n_fail = 0
    def _assert(c, m):
        nonlocal n_pass, n_fail
        if c: n_pass += 1; print(f"  [PASS] {m}")
        else: n_fail += 1; print(f"  [FAIL] {m}")

    np.random.seed(42)

    # Create synthetic dataset
    n_samples = 200
    n_features = 100
    X_syn = sparse.random(n_samples, n_features, density=0.1, format='csr')
    y_syn = np.random.randint(0, 2, n_samples)
    folds_syn = [i % 5 for i in range(n_samples)]

    # Test train_rf_with_cv
    rf_model, metrics = train_rf_with_cv(X_syn, y_syn, folds_syn, 'test_model')
    _assert(rf_model is not None, "RF model created")
    _assert(hasattr(rf_model, 'predict_proba'), "RF has predict_proba")
    _assert('mean_roc_auc' in metrics, "Metrics has roc_auc_mean")
    _assert('mean_pr_auc' in metrics, "Metrics has pr_auc_mean")
    _assert(0 <= metrics['mean_roc_auc'] <= 1, f"ROC-AUC in [0,1]: {metrics['mean_roc_auc']}")
    _assert(metrics['n_folds_completed'] == 5, f"Completed 5 folds: {metrics['n_folds_completed']}")

    # Test predict_proba output
    probs = rf_model.predict_proba(X_syn)
    _assert(probs.shape == (n_samples, 2), f"Proba shape: {probs.shape}")
    _assert(np.allclose(probs.sum(axis=1), 1.0), "Probabilities sum to 1")
    _assert((probs >= 0).all() and (probs <= 1).all(), "Probabilities in [0,1]")

    # Test selectivity score computation
    P_path = np.array([0.9, 0.1, 0.5, 0.8])
    P_gut = np.array([0.1, 0.9, 0.5, 0.0])
    S = P_path * (1 - P_gut)
    expected = np.array([0.81, 0.01, 0.25, 0.80])
    _assert(np.allclose(S, expected, atol=1e-6), f"Selectivity formula: {S} vs {expected}")

    # Test ranking
    df_test = pd.DataFrame({'name': ['A', 'B', 'C', 'D'], 'S': S})
    df_ranked = df_test.sort_values('S', ascending=False)
    _assert(df_ranked.iloc[0]['name'] == 'A', "Highest S ranked first")
    _assert(df_ranked.iloc[-1]['name'] == 'B', "Lowest S ranked last")

    # Test model serialization
    import tempfile
    with tempfile.NamedTemporaryFile(suffix='.pkl', delete=False) as tmp:
        tmppath = tmp.name
    try:
        with open(tmppath, 'wb') as f:
            pickle.dump(rf_model, f)
        with open(tmppath, 'rb') as f:
            loaded = pickle.load(f)
        probs2 = loaded.predict_proba(X_syn)
        _assert(np.allclose(probs, probs2), "Serialized model produces same predictions")
    finally:
        os.unlink(tmppath)

    print(f"\nUnit tests: {n_pass} passed, {n_fail} failed")
    return n_fail == 0


# ===========================================================================
# Main
# ===========================================================================

def main():
    logger.info("Running unit tests...")
    # Suppress noisy output during tests (expected errors look alarming to users)
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

    start_time = log_phase_start(logger, "Phase 3A: RF Pipeline Training")
    os.makedirs(config.RF_DIR, exist_ok=True)
    os.makedirs(config.SCREENING_DIR, exist_ok=True)
    os.makedirs(config.FIGURES_DIR, exist_ok=True)
    os.makedirs(config.REPORTS_DIR, exist_ok=True)

    # Try restoring pre-trained RF models from ZIP (local or Drive)
    try:
        from utils.gdrive_backup import get_data_manager
        dm = get_data_manager()
        if dm.restore_rf_models(config.PROJECT_DIR):
            # Verify all 7 models exist
            n_pkl = len([f for f in os.listdir(config.RF_DIR) if f.endswith('.pkl')])
            metrics_path = os.path.join(config.RESULTS_DIR, 'rf_cv_metrics.json')
            n_screen = len([f for f in os.listdir(config.SCREENING_DIR) if f.startswith('rf_ranked_')]) if os.path.isdir(config.SCREENING_DIR) else 0
            if n_pkl >= 7 and os.path.exists(metrics_path) and n_screen >= 12:
                logger.info(f"\n  RF models restored from cache: {n_pkl} models, {n_screen} screening lists")
                logger.info(f"  Skipping training (already computed).")
                log_phase_end(logger, "Phase 3A (cached)", start_time)
                return
            else:
                logger.info(f"  Partial restore: {n_pkl} models, {n_screen} screening lists. Retraining...")
    except Exception:
        pass

    all_models = {}
    all_metrics = {}

    # ---------------------------------------------------------------
    # Train 4 pathogen models
    # ---------------------------------------------------------------
    total_models = len(config.PATHOGENS) + len(config.HARM_THRESHOLDS)
    model_num = 0
    for pkey in config.PATHOGENS:
        model_num += 1
        model_key = f'rf_{pkey}'
        _PM = f"05_train_rf.py:main:pathogen_{pkey}"
        logger.info(f"\n{'='*60}")
        logger.info(f"  Model {model_num}/{total_models}: {model_key}")
        logger.info(f"{'='*60}")
        try:
            X, folds, df = load_dataset(pkey)
        except FileNotFoundError as e:
            logger.error(f"  [{_PM}] Data not found for {pkey}: {e}")
            logger.error(f"  [{_PM}] ACTION: Check Phase 1A and Phase 2 completed for {pkey}")
            continue
        except Exception as e:
            logger.error(f"  [{_PM}] load_dataset FAILED: {type(e).__name__}: {e}")
            continue

        try:
            y = df['activity_label'].values.astype(int)
        except KeyError:
            logger.error(f"  [{_PM}] Column 'activity_label' not in df. Columns: {list(df.columns)}")
            continue

        model, metrics = train_rf_with_cv(X, y, folds, model_key)
        all_models[model_key] = model
        all_metrics[model_key] = metrics

        # Save model
        model_path = os.path.join(config.RF_DIR, f'{model_key}.pkl')
        with open(model_path, 'wb') as f:
            pickle.dump(model, f, protocol=pickle.HIGHEST_PROTOCOL)
        logger.info(f"  Saved: {model_path}")

    # ---------------------------------------------------------------
    # Train 3 gut harm models (one per threshold)
    # ---------------------------------------------------------------
    try:
        X_maier, folds_maier, df_maier = load_dataset('maier')
    except FileNotFoundError as e:
        logger.error(f"  [05_train_rf.py:main] Maier data not found: {e}")
        logger.error(f"  ACTION: Check Phase 1B and Phase 2 completed for Maier data")
        X_maier, folds_maier, df_maier = None, None, None
    except Exception as e:
        logger.error(f"  [05_train_rf.py:main] load_dataset('maier') FAILED: {type(e).__name__}: {e}")
        X_maier, folds_maier, df_maier = None, None, None

    if X_maier is not None:
      for t in config.HARM_THRESHOLDS:
        model_num += 1
        model_key = f'rf_gut_t{t}'
        _GM = f"05_train_rf.py:main:gut_t{t}"
        logger.info(f"\n{'='*60}")
        logger.info(f"  Model {model_num}/{total_models}: {model_key}")
        logger.info(f"{'='*60}")
        try:
            y = df_maier[f'harm_t{t}'].values.astype(int)
        except KeyError:
            logger.error(f"  [{_GM}] Column 'harm_t{t}' not in df. Columns: {list(df_maier.columns)}")
            continue

        model, metrics = train_rf_with_cv(X_maier, y, folds_maier, model_key)
        all_models[model_key] = model
        all_metrics[model_key] = metrics

        model_path = os.path.join(config.RF_DIR, f'{model_key}.pkl')
        with open(model_path, 'wb') as f:
            pickle.dump(model, f, protocol=pickle.HIGHEST_PROTOCOL)
        logger.info(f"  Saved: {model_path}")

    # Save CV metrics summary
    metrics_summary = {}
    for mkey, m in all_metrics.items():
        # Use bare task name (strip 'rf_' prefix) for cross-pipeline comparison in Phase 4
        bare_key = mkey.replace('rf_', '', 1)
        metrics_summary[bare_key] = {
            'mean_roc_auc': m['mean_roc_auc'],
            'std_roc_auc': m['std_roc_auc'],
            'mean_pr_auc': m['mean_pr_auc'],
            'std_pr_auc': m['std_pr_auc'],
            'n_samples': m['n_samples'],
            'n_positive': m['n_positive'],
            'full_metrics_agg': m.get('full_metrics_agg', {}),
        }

    metrics_path = os.path.join(config.RESULTS_DIR, 'rf_cv_metrics.json')
    with open(metrics_path, 'w') as f:
        json.dump(metrics_summary, f, indent=2)
    logger.info(f"\nCV metrics saved: {metrics_path}")

    # Also save as CSV for easy comparison in Phase 4
    rows = []
    for mkey, m in metrics_summary.items():
        rows.append({
            'model': mkey, 'pipeline': 'RF',
            'mean_roc_auc': m['mean_roc_auc'], 'std_roc_auc': m['std_roc_auc'],
            'mean_pr_auc': m['mean_pr_auc'], 'std_pr_auc': m['std_pr_auc'],
            'n_samples': m['n_samples'], 'n_positive': m['n_positive'],
        })
    pd.DataFrame(rows).to_csv(
        os.path.join(config.RESULTS_DIR, 'rf_cv_metrics.csv'), index=False
    )

    # ---------------------------------------------------------------
    # Screen the Drug Repurposing Hub
    # ---------------------------------------------------------------
    logger.info("\n" + "=" * 60)
    logger.info(" VIRTUAL SCREENING")
    logger.info("=" * 60)

    X_hub, df_hub = load_screening_library()
    ranked_lists = screen_hub(all_models, X_hub, df_hub)

    # Save ranked lists
    for list_key, df_ranked in ranked_lists.items():
        out_path = os.path.join(config.SCREENING_DIR, f'rf_ranked_{list_key}.csv')
        df_ranked.to_csv(out_path, index=False)
        logger.info(f"  Saved: {out_path} ({len(df_ranked)} compounds)")

    # ---------------------------------------------------------------
    # Generate figures
    # ---------------------------------------------------------------
    logger.info("\nGenerating Phase 3A figures...")
    try:
        generate_phase3a_figures(all_metrics, ranked_lists)
    except Exception as e:
        logger.warning(f"Figure generation failed: {e}")

    # ---------------------------------------------------------------
    # Summary
    # ---------------------------------------------------------------
    logger.info("\n" + "=" * 70)
    logger.info(" PHASE 3A SUMMARY: RF Pipeline")
    logger.info("=" * 70)
    logger.info(f"{'Model':<20} {'ROC-AUC':>15} {'PR-AUC':>15} {'Samples':>10} {'Pos':>8}")
    logger.info("-" * 70)
    for mkey, m in metrics_summary.items():
        logger.info(f"{mkey:<20} "
                    f"{m['mean_roc_auc']:.4f} +/- {m['std_roc_auc']:.4f}  "
                    f"{m['mean_pr_auc']:.4f} +/- {m['std_pr_auc']:.4f}  "
                    f"{m['n_samples']:>8}  {m['n_positive']:>6}")
    logger.info("-" * 70)
    logger.info(f"Models saved: {len(all_models)} .pkl files in {config.RF_DIR}")
    logger.info(f"Ranked lists: {len(ranked_lists)} files in {config.SCREENING_DIR}")
    logger.info("=" * 70)

    save_checkpoint(
        {'status': 'complete', 'metrics': metrics_summary,
         'ranked_lists': list(ranked_lists.keys())},
        os.path.join(config.CHECKPOINTS_DIR, 'phase3a_master.json'), logger,
    )

    # Pack trained RF models + screening lists into ZIP and push to Drive
    try:
        from utils.gdrive_backup import get_data_manager
        dm = get_data_manager()
        dm.pack_rf_models(config.PROJECT_DIR)
    except Exception as e:
        logger.debug(f"  RF model packing skipped: {e}")

    log_phase_end(logger, "Phase 3A", start_time)


if __name__ == '__main__':
    main()
