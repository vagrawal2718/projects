"""
15_backfill_full_metrics.py -- Patch existing RF & DMPNN metrics JSONs with full_metrics_agg

On Ada, RF and DMPNN have already run and their *_cv_metrics.json files lack
the full_metrics_agg key needed by 12_compare_models.py. This script reads
existing on-disk fold data (predictions + labels) and backfills the missing
metrics without retraining any models.

Data sources:
  DMPNN: models/dmpnn/{task}/fold_data/fold{i}_preds.csv + fold{i}_test.csv
  RF:    Retrains per-fold RFs from features + splits (fast, ~2s/fold)
         and saves OOF predictions to models/rf/{task}/fold_data/

Usage:
  python scripts/15_backfill_full_metrics.py           # patch both RF + DMPNN
  python scripts/15_backfill_full_metrics.py --test     # unit tests only
  python scripts/15_backfill_full_metrics.py --dry-run  # show what would change

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import os, sys, json, glob, pickle
import numpy as np
import pandas as pd

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)

import config
from utils.full_metrics import compute_full_metrics, aggregate_fold_metrics
from utils.scaffold_split import load_folds, get_train_test_indices
from utils.logging_utils import setup_logging

logger = setup_logging('backfill_metrics', log_dir=config.LOGS_DIR)


# ===========================================================================
# DMPNN backfill
# ===========================================================================

def backfill_dmpnn(dry_run=False):
    """
    Backfill full_metrics_agg into dmpnn_cv_metrics.json.

    Reads fold{i}_preds.csv and fold{i}_test.csv from each task's fold_data dir.
    """
    metrics_path = os.path.join(config.RESULTS_DIR, 'dmpnn_cv_metrics.json')
    if not os.path.exists(metrics_path):
        logger.warning(f"  DMPNN metrics not found: {metrics_path}")
        return False

    with open(metrics_path) as f:
        cv_metrics = json.load(f)

    dmpnn_model_dir = os.path.join(config.MODELS_DIR, 'dmpnn')
    updated = 0

    for task_name, task_data in cv_metrics.items():
        # Skip if already has full_metrics_agg with actual data
        existing_agg = task_data.get('full_metrics_agg', {})
        if existing_agg and existing_agg.get('mean_sensitivity') is not None:
            logger.info(f"  DMPNN {task_name}: already has full_metrics_agg, skipping")
            continue

        # Find fold data on disk
        fold_data_dir = os.path.join(dmpnn_model_dir, task_name, 'fold_data')
        if not os.path.isdir(fold_data_dir):
            logger.warning(f"  DMPNN {task_name}: no fold_data dir at {fold_data_dir}")
            continue

        fold_full_metrics = []
        n_folds = config.N_FOLDS

        for fold_idx in range(n_folds):
            preds_csv = os.path.join(fold_data_dir, f'fold{fold_idx}_preds.csv')
            test_csv = os.path.join(fold_data_dir, f'fold{fold_idx}_test.csv')

            if not os.path.exists(preds_csv) or not os.path.exists(test_csv):
                logger.warning(f"  DMPNN {task_name} fold {fold_idx}: missing CSVs")
                continue

            try:
                df_preds = pd.read_csv(preds_csv)
                df_test = pd.read_csv(test_csv)

                y_true = df_test['label'].values.astype(int)

                # Chemprop preds CSV: column is either 'label' or the target name
                pred_col = [c for c in df_preds.columns if c != 'smiles']
                if not pred_col:
                    pred_col = df_preds.columns.tolist()
                y_prob = df_preds[pred_col[0]].values.astype(float)

                if len(y_true) != len(y_prob):
                    logger.warning(f"  DMPNN {task_name} fold {fold_idx}: "
                                   f"size mismatch ({len(y_true)} vs {len(y_prob)})")
                    continue

                fm = compute_full_metrics(y_true, y_prob)
                fold_full_metrics.append(fm)
                logger.info(f"  DMPNN {task_name} fold {fold_idx}: "
                            f"ROC-AUC={fm['roc_auc']:.4f}, MCC={fm['mcc']:.4f}")

            except Exception as e:
                logger.warning(f"  DMPNN {task_name} fold {fold_idx}: error: {e}")

        if fold_full_metrics:
            agg = aggregate_fold_metrics(fold_full_metrics)
            if not dry_run:
                task_data['full_metrics_agg'] = agg
                # Also patch per-fold metrics if they exist
                fold_metrics_list = task_data.get('fold_metrics', [])
                for i, fm_dict in enumerate(fold_metrics_list):
                    if i < len(fold_full_metrics):
                        fm_dict['full_metrics'] = fold_full_metrics[i]
            updated += 1
            logger.info(f"  DMPNN {task_name}: backfilled {len(fold_full_metrics)} folds, "
                        f"mean_roc_auc={agg.get('mean_roc_auc', '?')}, "
                        f"mean_mcc={agg.get('mean_mcc', '?')}, "
                        f"mean_sensitivity={agg.get('mean_sensitivity', '?')}")

    if updated > 0 and not dry_run:
        # Backup original
        backup_path = metrics_path + '.bak'
        if not os.path.exists(backup_path):
            with open(backup_path, 'w') as f:
                json.dump(cv_metrics, f, indent=2, default=str)
            logger.info(f"  Backup: {backup_path}")

        with open(metrics_path, 'w') as f:
            json.dump(cv_metrics, f, indent=2, default=str)
        logger.info(f"  Updated: {metrics_path} ({updated} tasks)")

    return updated > 0


# ===========================================================================
# RF data loading helper (matches 05_train_rf.py:load_dataset alignment)
# ===========================================================================

def _load_rf_dataset(task_name):
    """
    Load features, folds, and labels for an RF task, matching the exact
    valid_indices subsetting from 05_train_rf.py:load_dataset().

    Returns (X, folds_valid, y) or raises on failure.
    """
    from scipy import sparse

    # Determine dataset name for file paths
    if task_name.startswith('gut_'):
        ds_name = 'maier'
    else:
        ds_name = task_name

    # Load fingerprints (already subsetted to valid indices)
    fp_path = os.path.join(config.FEATURES_DIR, f'morgan_{ds_name}.npz')
    if not os.path.exists(fp_path):
        raise FileNotFoundError(f"Features not found: {fp_path}")
    X = sparse.load_npz(fp_path)

    # Load valid_indices (rows that produced valid fingerprints)
    idx_path = os.path.join(config.FEATURES_DIR, f'morgan_{ds_name}_indices.json')
    if os.path.exists(idx_path):
        with open(idx_path, 'r') as f:
            idx_info = json.load(f)
        valid_indices = idx_info['valid_indices']
    else:
        # Fallback: assume all rows are valid
        valid_indices = None

    # Load folds and subset to valid_indices
    if task_name.startswith('gut_'):
        splits_name = 'maier_scaffold_folds'
    else:
        splits_name = f'{task_name}_scaffold_folds'

    splits_path = os.path.join(config.SPLITS_DIR, f'{splits_name}.pkl')
    if not os.path.exists(splits_path):
        splits_path = os.path.join(config.SPLITS_DIR, f'{splits_name}.json')
    if not os.path.exists(splits_path):
        raise FileNotFoundError(f"Splits not found for {task_name}")

    folds_all = load_folds(splits_path)
    if valid_indices is not None:
        folds_valid = [folds_all[i] for i in valid_indices]
    else:
        folds_valid = folds_all

    # Load labels and subset to valid_indices
    if task_name.startswith('gut_'):
        t_val = task_name.replace('gut_t', '')
        maier_csv = os.path.join(config.MAIER_DIR, 'maier_combined.csv')
        if not os.path.exists(maier_csv):
            raise FileNotFoundError(f"Maier CSV not found: {maier_csv}")
        df = pd.read_csv(maier_csv)
        if valid_indices is not None:
            df = df.iloc[valid_indices].reset_index(drop=True)
        y = df[f'harm_t{t_val}'].values.astype(int)
    else:
        pinfo = config.PATHOGENS.get(task_name, {})
        csv_name = pinfo.get('csv_filename', '')
        csv_path = os.path.join(config.CHEMBL_DIR, csv_name)
        if not os.path.exists(csv_path):
            raise FileNotFoundError(f"ChEMBL CSV not found: {csv_path}")
        df = pd.read_csv(csv_path)
        if valid_indices is not None:
            df = df.iloc[valid_indices].reset_index(drop=True)
        y = df['activity_label'].values.astype(int)

    # Verify alignment
    assert X.shape[0] == len(folds_valid) == len(y), \
        (f"Shape mismatch: X={X.shape[0]}, folds={len(folds_valid)}, "
         f"y={len(y)}")

    return X, folds_valid, y


# ===========================================================================
# RF backfill (FIXED: retrains per-fold RFs instead of using final model)
# ===========================================================================

def backfill_rf(dry_run=False):
    """
    Backfill full_metrics_agg into rf_cv_metrics.json.

    FIXED: Retrains per-fold RFs on held-out splits (same as 05_train_rf.py),
    computes metrics from true held-out predictions, and saves OOF
    predictions to disk for future use.

    Previous bug: loaded the FINAL model (trained on ALL data) and predicted
    on test folds, giving in-sample ROC-AUC ~0.98 instead of real ~0.88.
    """
    metrics_path = os.path.join(config.RESULTS_DIR, 'rf_cv_metrics.json')
    if not os.path.exists(metrics_path):
        logger.warning(f"  RF metrics not found: {metrics_path}")
        return False

    with open(metrics_path) as f:
        cv_metrics = json.load(f)

    # Backup before any modifications
    if not dry_run:
        backup_path = metrics_path + '.bak'
        with open(backup_path, 'w') as f:
            json.dump(cv_metrics, f, indent=2, default=str)
        logger.info(f"  Backup: {backup_path}")

    from scipy import sparse
    from sklearn.ensemble import RandomForestClassifier

    updated = 0

    for task_name, task_data in cv_metrics.items():
        # Always recompute: previous values may be inflated from the
        # final-model bug
        logger.info(f"\n  RF {task_name}: recomputing with per-fold CV...")

        try:
            X, folds, y = _load_rf_dataset(task_name)
        except (FileNotFoundError, AssertionError, KeyError) as e:
            logger.warning(f"  RF {task_name}: {e}")
            continue

        # Create fold_data directory for saving OOF predictions
        fold_data_dir = os.path.join(config.RF_DIR, task_name, 'fold_data')

        fold_full_metrics = []
        n_folds = min(len(set(folds)), config.N_FOLDS)

        for fold_idx in range(n_folds):
            try:
                train_idx, test_idx = get_train_test_indices(folds, fold_idx)
                X_train, X_test = X[train_idx], X[test_idx]
                y_train, y_test = y[train_idx], y[test_idx]
            except Exception as e:
                logger.warning(f"  RF {task_name} fold {fold_idx}: "
                               f"split failed: {e}")
                continue

            if len(np.unique(y_test)) < 2:
                logger.warning(f"  RF {task_name} fold {fold_idx}: "
                               f"degenerate (single class)")
                continue

            # Retrain a fresh RF on training fold only
            rf_fold = RandomForestClassifier(**config.RF_PARAMS)
            rf_fold.fit(X_train, y_train)

            # Predict on held-out test fold (true OOF predictions)
            probs = rf_fold.predict_proba(X_test)[:, 1]

            # Compute full metrics from held-out predictions
            fm = compute_full_metrics(y_test, probs)
            fold_full_metrics.append(fm)

            logger.info(f"  RF {task_name} fold {fold_idx}: "
                        f"ROC-AUC={fm['roc_auc']:.4f}, "
                        f"MCC={fm['mcc']:.4f} "
                        f"(train={len(train_idx)}, test={len(test_idx)})")

            # Save OOF predictions to disk
            if not dry_run:
                os.makedirs(fold_data_dir, exist_ok=True)
                preds_df = pd.DataFrame({
                    'index': test_idx,
                    'y_true': y_test,
                    'y_prob': probs,
                })
                preds_path = os.path.join(fold_data_dir,
                                          f'fold{fold_idx}_oof.csv')
                preds_df.to_csv(preds_path, index=False)

        if fold_full_metrics:
            agg = aggregate_fold_metrics(fold_full_metrics)
            if not dry_run:
                task_data['full_metrics_agg'] = agg
            updated += 1

            # Log comparison with top-level ROC-AUC
            top_roc = task_data.get('mean_roc_auc', '?')
            new_roc = agg.get('mean_roc_auc', '?')
            logger.info(f"  RF {task_name}: backfilled {len(fold_full_metrics)} folds")
            logger.info(f"    top-level ROC-AUC = {top_roc} (from original training)")
            logger.info(f"    backfill ROC-AUC  = {new_roc} (from per-fold CV)")
            logger.info(f"    mean_mcc          = {agg.get('mean_mcc', '?')}")
            logger.info(f"    mean_sensitivity  = {agg.get('mean_sensitivity', '?')}")

    if updated > 0 and not dry_run:
        with open(metrics_path, 'w') as f:
            json.dump(cv_metrics, f, indent=2, default=str)
        logger.info(f"  Updated: {metrics_path} ({updated} tasks)")

    return updated > 0


# ===========================================================================
# Main
# ===========================================================================


# ===========================================================================
# D-MPNN+RDKit backfill (reads OOF CSVs saved by script 20)
# ===========================================================================

def backfill_dmpnn_rdkit(dry_run=False):
    """
    Backfill full_metrics_agg into dmpnn_rdkit_cv_metrics.json.

    Reads dmpnn_rdkit_{task}_oof.csv files (columns: smiles, true_label, oof_prob)
    saved by 20_train_dmpnn_rdkit.py during CV training. These are true
    out-of-fold predictions from per-fold models.
    """
    metrics_path = os.path.join(config.RESULTS_DIR, 'dmpnn_rdkit_cv_metrics.json')
    if not os.path.exists(metrics_path):
        logger.warning(f"  D-MPNN+RDKit metrics not found: {metrics_path}")
        return False

    with open(metrics_path) as f:
        cv_metrics = json.load(f)

    dmpnn_rdkit_model_dir = os.path.join(config.MODELS_DIR, 'dmpnn_rdkit')
    updated = 0

    for task_name, task_data in cv_metrics.items():
        # Skip if already has valid full_metrics_agg
        existing_agg = task_data.get('full_metrics_agg', {})
        if existing_agg and existing_agg.get('mean_sensitivity') is not None:
            logger.info(f"  D-MPNN+RDKit {task_name}: already has full_metrics_agg, skipping")
            continue

        # Find OOF CSV (single file with all fold predictions concatenated)
        oof_path = os.path.join(dmpnn_rdkit_model_dir, task_name,
                                f'dmpnn_rdkit_{task_name}_oof.csv')
        if not os.path.exists(oof_path):
            logger.warning(f"  D-MPNN+RDKit {task_name}: no OOF file at {oof_path}")
            continue

        try:
            df = pd.read_csv(oof_path)
            if 'true_label' not in df.columns or 'oof_prob' not in df.columns:
                logger.warning(f"  D-MPNN+RDKit {task_name}: unexpected columns {list(df.columns)}")
                continue

            y_true = df['true_label'].values.astype(int)
            y_prob = df['oof_prob'].values.astype(float)

            # Remove any NaN rows
            valid = ~(np.isnan(y_prob) | np.isnan(y_true))
            y_true = y_true[valid]
            y_prob = y_prob[valid]

            if len(y_true) < 10:
                logger.warning(f"  D-MPNN+RDKit {task_name}: too few valid OOF predictions ({len(y_true)})")
                continue

            if len(np.unique(y_true)) < 2:
                logger.warning(f"  D-MPNN+RDKit {task_name}: single class in OOF labels")
                continue

            fm = compute_full_metrics(y_true, y_prob)

            if not dry_run:
                # Store as full_metrics_agg with mean_ prefix (matching other models)
                agg = {f'mean_{k}': v for k, v in fm.items()}
                agg.update({f'std_{k}': 0.0 for k in fm})
                agg['n_folds'] = task_data.get('n_folds_completed', 5)
                agg['n_oof_samples'] = int(len(y_true))
                agg['note'] = 'Computed from concatenated OOF predictions (all folds)'
                task_data['full_metrics_agg'] = agg

            updated += 1
            logger.info(f"  D-MPNN+RDKit {task_name}: backfilled from {len(y_true)} OOF samples")
            logger.info(f"    ROC-AUC={fm['roc_auc']:.4f}, MCC={fm['mcc']:.4f}, "
                        f"sens={fm['sensitivity']:.4f}, spec={fm['specificity']:.4f}")

        except Exception as e:
            logger.warning(f"  D-MPNN+RDKit {task_name}: error: {e}")

    if updated > 0 and not dry_run:
        # Backup original
        backup_path = metrics_path + '.bak'
        if not os.path.exists(backup_path):
            with open(backup_path, 'w') as f_bak:
                json.dump(cv_metrics, f_bak, indent=2, default=str)
            logger.info(f"  Backup: {backup_path}")

        with open(metrics_path, 'w') as f_out:
            json.dump(cv_metrics, f_out, indent=2, default=str)
        logger.info(f"  Updated: {metrics_path} ({updated} tasks)")

    return updated > 0


def main():
    dry_run = '--dry-run' in sys.argv

    logger.info("=" * 60)
    logger.info("  Backfill full_metrics_agg into existing result JSONs")
    logger.info("=" * 60)
    if dry_run:
        logger.info("  DRY RUN: no files will be modified")

    logger.info("\n  [1/3] DMPNN backfill...")
    dmpnn_ok = backfill_dmpnn(dry_run=dry_run)

    logger.info("\n  [2/3] RF backfill...")
    rf_ok = backfill_rf(dry_run=dry_run)

    logger.info("\n  [3/3] D-MPNN+RDKit backfill...")
    rdkit_ok = backfill_dmpnn_rdkit(dry_run=dry_run)

    logger.info("\n" + "=" * 60)
    logger.info(f"  DMPNN:      {'patched' if dmpnn_ok else 'no changes needed'}")
    logger.info(f"  RF:         {'patched' if rf_ok else 'no changes needed'}")
    logger.info(f"  DMPNN+RDKit: {'patched' if rdkit_ok else 'no changes needed'}")
    logger.info("=" * 60)


def run_tests():
    """Unit tests for the backfill logic."""
    print("Running backfill unit tests...")
    passed, failed = 0, 0

    def _assert(cond, msg):
        nonlocal passed, failed
        if cond:
            print(f"  [PASS] {msg}")
            passed += 1
        else:
            print(f"  [FAIL] {msg}")
            failed += 1

    # Test compute_full_metrics returns all needed keys
    y_true = np.array([1, 1, 0, 0, 1, 0, 1, 0])
    y_prob = np.array([0.9, 0.8, 0.2, 0.1, 0.7, 0.3, 0.6, 0.4])
    fm = compute_full_metrics(y_true, y_prob)

    _assert('roc_auc' in fm, "full_metrics has roc_auc")
    _assert('pr_auc' in fm, "full_metrics has pr_auc")
    _assert('mcc' in fm, "full_metrics has mcc")
    _assert('sensitivity' in fm, "full_metrics has sensitivity")
    _assert('specificity' in fm, "full_metrics has specificity")
    _assert('brier_score' in fm, "full_metrics has brier_score")
    _assert('f1_macro' in fm, "full_metrics has f1_macro")
    _assert('balanced_accuracy' in fm, "full_metrics has balanced_accuracy")
    _assert(fm['roc_auc'] > 0.8, f"ROC-AUC > 0.8: {fm['roc_auc']:.4f}")

    # Test aggregation
    agg = aggregate_fold_metrics([fm, fm, fm])
    _assert(agg['n_folds'] == 3, f"n_folds=3: {agg['n_folds']}")
    _assert('mean_roc_auc' in agg, "agg has mean_roc_auc")
    _assert('std_roc_auc' in agg, "agg has std_roc_auc")
    _assert('mean_mcc' in agg, "agg has mean_mcc")
    _assert('mean_sensitivity' in agg, "agg has mean_sensitivity")
    _assert('mean_specificity' in agg, "agg has mean_specificity")
    _assert('mean_brier_score' in agg, "agg has mean_brier_score")
    _assert('mean_f1_macro' in agg, "agg has mean_f1_macro")
    _assert('mean_balanced_accuracy' in agg, "agg has mean_balanced_accuracy")

    # Verify backward compatibility: agg keys match what 12_compare_models.py reads
    PUB_METRICS = ['roc_auc', 'pr_auc', 'f1_macro', 'mcc', 'sensitivity', 'specificity',
                   'balanced_accuracy', 'brier_score']
    for pm in PUB_METRICS:
        _assert(f'mean_{pm}' in agg, f"agg has mean_{pm} (needed by 12_compare_models.py)")
        _assert(f'std_{pm}' in agg, f"agg has std_{pm} (needed by 12_compare_models.py)")

    # Test that JSON serialization works (no numpy types)
    try:
        json_str = json.dumps({'full_metrics_agg': agg})
        _assert(True, "JSON serialization works")
    except TypeError as e:
        _assert(False, f"JSON serialization failed: {e}")

    # Test paths exist in config
    _assert(hasattr(config, 'RESULTS_DIR'), "config.RESULTS_DIR exists")
    _assert(hasattr(config, 'MODELS_DIR'), "config.MODELS_DIR exists")
    _assert(hasattr(config, 'RF_DIR'), "config.RF_DIR exists")
    _assert(hasattr(config, 'FEATURES_DIR'), "config.FEATURES_DIR exists")
    _assert(hasattr(config, 'SPLITS_DIR'), "config.SPLITS_DIR exists")

    print(f"\nUnit tests: {passed} passed, {failed} failed")


if __name__ == '__main__':
    if '--test' in sys.argv:
        run_tests()
    else:
        main()