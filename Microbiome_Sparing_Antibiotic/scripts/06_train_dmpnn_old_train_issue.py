#!/usr/bin/env python3
"""
06_train_dmpnn.py -- Phase 3B: D-MPNN Pipeline Training (Chemprop v2)

Trains 7 D-MPNN models using Chemprop v2 with the SAME scaffold folds as RF:
  - 4 pathogen models (E. coli, S. aureus, P. aeruginosa, M. tuberculosis)
  - 3 commensal harm models (thresholds t=5, t=10, t=20)

For each model:
  1. Loads scaffold folds from Phase 2 (.pkl, shared with RF)
  2. Writes per-fold train/test CSVs
  3. Runs Chemprop train via CLI (GPU-accelerated)
  4. Collects OOF predictions and computes ROC-AUC, PR-AUC
  5. Trains a final model on all data

Then screens the Drug Repurposing Hub:
  6. Predicts P_pathogen and P_gut via Chemprop predict
  7. Computes S = P_pathogen * (1 - P_gut)
  8. Saves 12 ranked lists

Requires: GPU (1x GTX 1080 Ti), Chemprop v2, PyTorch with CUDA.

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import os
import sys
import json
import time
import shutil
import logging
import warnings
import subprocess
from typing import Dict, List, Optional, Tuple

import numpy as np
import pandas as pd
from sklearn.metrics import roc_auc_score, average_precision_score, roc_curve

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)

import config
from utils.scaffold_split import load_folds, get_train_test_indices
from utils.logging_utils import (
    setup_logging, log_phase_start, log_phase_end,
    save_checkpoint, load_checkpoint,
)
from utils.viz_utils import setup_publication_style, save_figure, COLORS

warnings.filterwarnings('ignore')
logger = setup_logging('phase3b', log_dir=config.LOGS_DIR)


# ===========================================================================
# Chemprop version detection and CLI wrapper
# ===========================================================================

def detect_chemprop_version() -> Tuple[str, str]:
    """
    Detect Chemprop version and CLI command format.

    Returns (version_string, cli_prefix).
    cli_prefix is either 'chemprop' (v2) or 'chemprop' (v1, with underscore args).
    """
    # Find the chemprop entry point script
    # In a venv, it's at {venv}/bin/chemprop (same dir as python executable)
    bin_dir = os.path.dirname(sys.executable)
    chemprop_script = os.path.join(bin_dir, 'chemprop')
    if os.name == 'nt':
        chemprop_script = os.path.join(bin_dir, 'chemprop.exe')
        if not os.path.exists(chemprop_script):
            chemprop_script = os.path.join(bin_dir, 'Scripts', 'chemprop.exe')

    # Try v2 entry point script in venv
    if os.path.exists(chemprop_script):
        try:
            result = subprocess.run(
                [chemprop_script, '--version'], capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                ver = result.stdout.strip()
                logger.info(f"  Chemprop v2 script found: {chemprop_script}")
                logger.info(f"  Version: {ver}")
                return ver, 'v2'
        except Exception:
            pass

    # Try chemprop on PATH
    import shutil as _shutil
    chemprop_on_path = _shutil.which('chemprop')
    if chemprop_on_path:
        try:
            result = subprocess.run(
                [chemprop_on_path, '--version'], capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                ver = result.stdout.strip()
                logger.info(f"  Chemprop on PATH: {chemprop_on_path}")
                return ver, 'v2'
        except Exception:
            pass

    # Try importing to get version (for API-only usage)
    try:
        import chemprop
        ver = getattr(chemprop, '__version__', 'unknown')
        logger.info(f"  Chemprop importable: v{ver}")
        if ver.startswith('1.'):
            return ver, 'v1'
        # v2 is importable but python -m chemprop does NOT work (no __main__.py)
        # We must use the CLI entry point or the Python API
        return ver, 'v2_api'
    except ImportError:
        pass

    logger.error("  Chemprop not found! Install with: pip install chemprop")
    return 'not_found', 'none'


def get_chemprop_cmd(version_type: str) -> List[str]:
    """Get the base command for Chemprop CLI.

    IMPORTANT: Chemprop v2 does NOT support `python -m chemprop`.
    It uses an installed entry point script `chemprop` in the venv bin dir.
    """
    if version_type == 'v2':
        # Use the entry point script (already found by detect_chemprop_version)
        bin_dir = os.path.dirname(sys.executable)
        script = os.path.join(bin_dir, 'chemprop')
        if os.name == 'nt':
            script = os.path.join(bin_dir, 'chemprop.exe')
            if not os.path.exists(script):
                script = os.path.join(bin_dir, 'Scripts', 'chemprop.exe')
        if os.path.exists(script):
            return [script]
        # Fallback to PATH
        import shutil as _shutil
        found = _shutil.which('chemprop')
        if found:
            return [found]

    if version_type == 'v2_api':
        # v2 importable but no CLI script found. Use Python API entry point.
        return [sys.executable, '-c',
                'from chemprop.cli.main import main; main()']

    if version_type == 'v1':
        # v1 supports python -m chemprop
        return [sys.executable, '-m', 'chemprop']

    # Fallback: try chemprop on PATH
    return ['chemprop']


# ===========================================================================
# Training and prediction via CLI
# ===========================================================================

def train_chemprop_model(
    train_csv: str,
    val_csv: str,
    save_dir: str,
    version_type: str,
    gpu: bool = True,
) -> bool:
    """
    Train a single Chemprop model via CLI.

    Parameters
    ----------
    train_csv : str
        Path to training CSV (columns: smiles, label).
    val_csv : str
        Path to validation CSV (columns: smiles, label).
    save_dir : str
        Directory to save model checkpoints.
    version_type : str
        Chemprop version type from detect_chemprop_version().
    gpu : bool
        Whether to use GPU.

    Returns True on success, False on failure.
    """
    os.makedirs(save_dir, exist_ok=True)

    base_cmd = get_chemprop_cmd(version_type)

    if version_type == 'v1':
        # ---- Chemprop v1 argument format (underscore args) ----
        cmd = base_cmd + [
            'train',
            '--data_path', train_csv,
            '--dataset_type', 'classification',
            '--save_dir', save_dir,
            '--epochs', str(config.DMPNN_PARAMS['epochs']),
            '--batch_size', str(config.DMPNN_PARAMS['batch_size']),
            '--hidden_size', str(config.DMPNN_PARAMS['hidden_dim']),
            '--depth', str(config.DMPNN_PARAMS['depth']),
            '--dropout', str(config.DMPNN_PARAMS['dropout']),
            '--ffn_hidden_size', str(config.DMPNN_PARAMS['ffn_hidden_dim']),
            '--ffn_num_layers', str(config.DMPNN_PARAMS['ffn_num_layers']),
            '--split_type', 'random',
            '--num_folds', '1',
            '--smiles_column', 'smiles',
        ]
        if val_csv and os.path.exists(val_csv):
            cmd.extend(['--separate_val_path', val_csv])
        if not gpu:
            cmd.append('--no_cuda')
    else:
        # ---- Chemprop v2.2+ argument format ----
        # v2.2 uses --split (not --split-type) with enum values:
        #   SCAFFOLD_BALANCED, RANDOM_WITH_REPEATED_SMILES, RANDOM, KENNARD_STONE, KMEANS
        # For pre-split data: combine CSVs + --splits-file JSON
        # For no-val (final model): --split RANDOM --split-sizes 1.0 0.0 0.0

        if val_csv and os.path.exists(val_csv):
            # Combine train+val into one CSV, write splits JSON
            import json as _json
            df_train = pd.read_csv(train_csv)
            df_val = pd.read_csv(val_csv)
            n_train = len(df_train)
            n_val = len(df_val)
            combined_csv = os.path.join(save_dir, 'combined_data.csv')
            pd.concat([df_train, df_val], ignore_index=True).to_csv(combined_csv, index=False)

            # splits JSON: [[train_indices], [val_indices], [test_indices]]
            train_indices = list(range(n_train))
            val_indices = list(range(n_train, n_train + n_val))
            splits_file = os.path.join(save_dir, 'splits.json')
            with open(splits_file, 'w') as sf:
                _json.dump([train_indices, val_indices, []], sf)

            logger.info(f"    Combined {n_train} train + {n_val} val -> {combined_csv}")
            data_path = combined_csv
            split_args = ['--splits-file', splits_file]
        else:
            data_path = train_csv
            # Train on everything, no validation
            split_args = ['--split', 'RANDOM', '--split-sizes', '1.0', '0.0', '0.0']

        cmd = base_cmd + [
            'train',
            '--data-path', data_path,
            '--task-type', 'classification',
            '--output-dir', save_dir,
            '--epochs', str(config.DMPNN_PARAMS['epochs']),
            '--batch-size', str(config.DMPNN_PARAMS['batch_size']),
            '--message-hidden-dim', str(config.DMPNN_PARAMS['hidden_dim']),
            '--depth', str(config.DMPNN_PARAMS['depth']),
            '--dropout', str(config.DMPNN_PARAMS['dropout']),
            '--ffn-hidden-dim', str(config.DMPNN_PARAMS['ffn_hidden_dim']),
            '--ffn-num-layers', str(config.DMPNN_PARAMS['ffn_num_layers']),
            '--smiles-columns', 'smiles',
            '--target-columns', 'label',
            '--num-workers', '0',
        ] + split_args

        if gpu:
            cmd.extend(['--accelerator', 'gpu', '--devices', '1'])
        else:
            cmd.extend(['--accelerator', 'cpu'])

    _F = f"06_train_dmpnn.py:train_chemprop_model({os.path.basename(save_dir)})"
    logger.info(f"    [{_F}] Running: {' '.join(cmd[:8])}...")
    logger.info(f"    [{_F}] Full cmd: {' '.join(cmd)}")

    try:
        # Stream output live (visible in notebooks and terminals)
        proc = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, bufsize=1
        )

        # Read stdout line by line in real-time
        stderr_lines = []
        import threading
        def _read_stderr():
            for line in proc.stderr:
                stderr_lines.append(line.rstrip())
        t = threading.Thread(target=_read_stderr, daemon=True)
        t.start()

        for line in proc.stdout:
            line = line.rstrip()
            if line:
                logger.info(f"      [{_F}] {line}")

        proc.wait(timeout=7200)
        t.join(timeout=5)

        if proc.returncode == 0:
            logger.info(f"    [{_F}] Training completed successfully")
            return True
        else:
            logger.warning(f"    [{_F}] Training FAILED (exit code {proc.returncode})")
            logger.warning(f"    [{_F}] train_csv: {train_csv} ({os.path.exists(train_csv)})")
            logger.warning(f"    [{_F}] val_csv: {val_csv} ({os.path.exists(val_csv) if val_csv else 'None'})")
            for line in stderr_lines[-15:]:
                if line.strip():
                    logger.warning(f"      [{_F}] stderr: {line}")

            return _try_v1_fallback(train_csv, val_csv, save_dir, gpu)

    except subprocess.TimeoutExpired:
        logger.error(f"    [{_F}] TIMEOUT after 2 hours. ACTION: Reduce epochs or batch_size in config.py")
        return False
    except FileNotFoundError:
        logger.error(f"    [{_F}] chemprop CLI not found. ACTION: pip install chemprop")
        return False
    except Exception as e:
        logger.error(f"    [{_F}] {type(e).__name__}: {e}")
        return False


def _try_v1_fallback(train_csv, val_csv, save_dir, gpu):
    """Fallback: try training via Chemprop v2 Python API (no CLI needed)."""
    logger.info("    CLI failed. Trying Chemprop v2 Python API as fallback...")

    try:
        import chemprop
        from chemprop import data as chemprop_data, models, nn, train as chemprop_train
        import lightning.pytorch as pl
        import torch

        # Load data
        smiles_col = 'smiles'
        target_col = 'label'

        train_df = pd.read_csv(train_csv)
        train_smiles = train_df[smiles_col].tolist()
        train_targets = train_df[target_col].values.reshape(-1, 1).tolist()

        train_datapoints = [
            chemprop_data.MoleculeDatapoint(chemprop_data.MoleculeDatapoint.from_smi(smi), y)
            for smi, y in zip(train_smiles, train_targets)
        ]

        logger.info(f"    Python API: loaded {len(train_datapoints)} training molecules")
        logger.info(f"    This is experimental. If it fails, ensure chemprop >= 2.2.0.")
        return False  # For now, just log and return False until API is stable

    except Exception as e:
        logger.error(f"    Python API fallback also failed: {type(e).__name__}: {e}")
        return False


def predict_chemprop(
    model_dir: str,
    test_csv: str,
    preds_csv: str,
    version_type: str,
    gpu: bool = True,
) -> Optional[np.ndarray]:
    """
    Run Chemprop prediction via CLI. Returns array of predicted probabilities.
    """
    base_cmd = get_chemprop_cmd(version_type)

    # Find model checkpoint
    model_path = None
    for candidate in ['best.pt', 'model_0/best.pt', 'fold_0/best.pt',
                       'best_model.pt', 'model.pt']:
        full = os.path.join(model_dir, candidate)
        if os.path.exists(full):
            model_path = full
            break

    # Also search recursively
    if model_path is None:
        import glob
        pts = glob.glob(os.path.join(model_dir, '**', '*.pt'), recursive=True)
        ckpts = glob.glob(os.path.join(model_dir, '**', '*.ckpt'), recursive=True)
        candidates = pts + ckpts
        if candidates:
            model_path = candidates[0]

    if model_path is None:
        logger.error(f"    No model checkpoint found in {model_dir}")
        logger.error(f"    Contents: {os.listdir(model_dir) if os.path.isdir(model_dir) else 'NOT A DIR'}")
        return None

    if version_type == 'v1':
        # v1: uses --test_path, --checkpoint_dir, --preds_path (underscore args)
        cmd = base_cmd + [
            'predict',
            '--test_path', test_csv,
            '--checkpoint_dir', model_dir,
            '--preds_path', preds_csv,
            '--smiles_column', 'smiles',
        ]
        if not gpu:
            cmd.append('--no_cuda')
    else:
        # v2: uses --test-path, --model-paths, --preds-path (hyphen args)
        cmd = base_cmd + [
            'predict',
            '--test-path', test_csv,
            '--model-paths', model_path,
            '--preds-path', preds_csv,
            '--smiles-columns', 'smiles',
        ]
        if gpu:
            cmd.extend(['--accelerator', 'gpu', '--devices', '1'])
        else:
            cmd.extend(['--accelerator', 'cpu'])

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=3600)

        if result.returncode == 0 and os.path.exists(preds_csv):
            df_preds = pd.read_csv(preds_csv)
            # Chemprop outputs column named after the target or 'label'
            pred_col = [c for c in df_preds.columns if c != 'smiles'][0] if len(df_preds.columns) > 1 else df_preds.columns[0]
            probs = df_preds[pred_col].values.astype(float)
            return probs
        else:
            stderr_lines = result.stderr.strip().split('\n')[-5:]
            for line in stderr_lines:
                if line.strip():
                    logger.error(f"    Predict stderr: {line}")
            logger.error(f"    Prediction failed for {model_dir} (exit code {result.returncode})")
            return None
    except Exception as e:
        logger.error(f"    Prediction error: {e}")
        return None


# ===========================================================================
# 5-fold CV pipeline
# ===========================================================================

def train_dmpnn_with_cv(
    data_csv: str,
    fold_assignments: List[int],
    model_name: str,
    model_base_dir: str,
    version_type: str,
    gpu: bool = True,
) -> Dict:
    """
    Train D-MPNN with 5-fold scaffold CV using pre-computed folds.

    Writes per-fold train/test CSVs, trains via CLI, collects OOF predictions.
    """
    n_folds = config.N_FOLDS
    df = pd.read_csv(data_csv)
    y = df['label'].values.astype(int)

    oof_preds = np.full(len(y), np.nan)
    fold_metrics = []
    fold_roc_curves = []

    # Create temporary directory for fold CSVs
    fold_csv_dir = os.path.join(model_base_dir, 'fold_data')
    os.makedirs(fold_csv_dir, exist_ok=True)

    logger.info(f"\n  Training {model_name} with {n_folds}-fold scaffold CV...")

    for fold_idx in range(n_folds):
        _FF = f"06_train_dmpnn.py:train_dmpnn_with_cv({model_name}):fold_{fold_idx}"
        logger.info(f"    [{_FF}] Starting fold {fold_idx}/{n_folds}...")
        try:
            train_idx, test_idx = get_train_test_indices(fold_assignments, fold_idx)
        except Exception as e:
            logger.error(f"    [{_FF}] Fold split FAILED: {type(e).__name__}: {e}")
            logger.error(f"    [{_FF}] n_data={len(df)}, n_folds_assigned={len(fold_assignments)}")
            fold_metrics.append({'fold': fold_idx, 'roc_auc': np.nan, 'pr_auc': np.nan,
                                 'train_size': 0, 'test_size': 0})
            continue

        df_train = df.iloc[train_idx]
        df_test = df.iloc[test_idx]
        y_test = y[test_idx]

        # Check for degenerate folds
        if len(df_train['label'].unique()) < 2 or len(df_test['label'].unique()) < 2:
            logger.warning(f"    Fold {fold_idx}: degenerate (single class)")
            fold_metrics.append({
                'fold': fold_idx, 'roc_auc': np.nan, 'pr_auc': np.nan,
                'train_size': len(train_idx), 'test_size': len(test_idx),
            })
            continue

        # Write fold CSVs
        train_csv = os.path.join(fold_csv_dir, f'fold{fold_idx}_train.csv')
        test_csv = os.path.join(fold_csv_dir, f'fold{fold_idx}_test.csv')
        df_train.to_csv(train_csv, index=False)
        df_test.to_csv(test_csv, index=False)

        # Train
        fold_model_dir = os.path.join(model_base_dir, f'fold_{fold_idx}')
        success = train_chemprop_model(
            train_csv, test_csv, fold_model_dir, version_type, gpu
        )

        if not success:
            logger.warning(f"    Fold {fold_idx}: training failed")
            fold_metrics.append({
                'fold': fold_idx, 'roc_auc': np.nan, 'pr_auc': np.nan,
                'train_size': len(train_idx), 'test_size': len(test_idx),
            })
            continue

        # Predict on test fold
        preds_csv = os.path.join(fold_csv_dir, f'fold{fold_idx}_preds.csv')
        probs = predict_chemprop(fold_model_dir, test_csv, preds_csv, version_type, gpu)

        if probs is not None and len(probs) == len(test_idx):
            oof_preds[test_idx] = probs

            roc_auc = roc_auc_score(y_test, probs)
            pr_auc = average_precision_score(y_test, probs)
            fpr, tpr, _ = roc_curve(y_test, probs)

            fold_metrics.append({
                'fold': fold_idx, 'roc_auc': round(roc_auc, 4),
                'pr_auc': round(pr_auc, 4),
                'train_size': len(train_idx), 'test_size': len(test_idx),
                'train_pos_rate': round(float(df_train['label'].mean()), 4),
                'test_pos_rate': round(float(y_test.mean()), 4),
            })
            fold_roc_curves.append((fpr, tpr))

            logger.info(f"    Fold {fold_idx}: ROC-AUC={roc_auc:.4f}, PR-AUC={pr_auc:.4f}")
        else:
            logger.warning(f"    Fold {fold_idx}: prediction failed or size mismatch")
            fold_metrics.append({
                'fold': fold_idx, 'roc_auc': np.nan, 'pr_auc': np.nan,
                'train_size': len(train_idx), 'test_size': len(test_idx),
            })

    # Aggregate
    valid_rocs = [m['roc_auc'] for m in fold_metrics if not np.isnan(m.get('roc_auc', np.nan))]
    valid_prs = [m['pr_auc'] for m in fold_metrics if not np.isnan(m.get('pr_auc', np.nan))]

    mean_roc = float(np.mean(valid_rocs)) if valid_rocs else np.nan
    std_roc = float(np.std(valid_rocs)) if valid_rocs else np.nan
    mean_pr = float(np.mean(valid_prs)) if valid_prs else np.nan
    std_pr = float(np.std(valid_prs)) if valid_prs else np.nan

    logger.info(f"  {model_name} CV: ROC-AUC={mean_roc:.4f} +/- {std_roc:.4f}, "
                f"PR-AUC={mean_pr:.4f} +/- {std_pr:.4f}")

    # Train final model on all data
    logger.info(f"  Training final model on all {len(df)} samples...")
    final_model_dir = os.path.join(model_base_dir, 'final')
    all_csv = os.path.join(fold_csv_dir, 'all_data.csv')
    df.to_csv(all_csv, index=False)
    train_chemprop_model(all_csv, None, final_model_dir, version_type, gpu)

    return {
        'fold_metrics': fold_metrics,
        'mean_roc_auc': round(mean_roc, 4) if not np.isnan(mean_roc) else None,
        'std_roc_auc': round(std_roc, 4) if not np.isnan(std_roc) else None,
        'mean_pr_auc': round(mean_pr, 4) if not np.isnan(mean_pr) else None,
        'std_pr_auc': round(std_pr, 4) if not np.isnan(std_pr) else None,
        'oof_predictions': oof_preds,
        'oof_labels': y,
        'fold_roc_curves': fold_roc_curves,
        'final_model_dir': final_model_dir,
    }


# ===========================================================================
# Virtual screening
# ===========================================================================

def screen_hub_dmpnn(
    pathogen_model_dirs: Dict[str, str],
    gut_model_dirs: Dict[str, str],
    hub_csv: str,
    version_type: str,
    gpu: bool = True,
) -> Dict[str, pd.DataFrame]:
    """Screen the Hub with all D-MPNN models."""
    logger.info("\n  Screening Drug Repurposing Hub with D-MPNN models...")

    df_hub = pd.read_csv(hub_csv)
    # Write Hub smiles-only CSV for prediction
    hub_smiles_csv = os.path.join(config.DATA_DIR, 'dmpnn_input', 'hub_screen.csv')

    pathogen_probs = {}
    for key, model_dir in pathogen_model_dirs.items():
        preds_csv = os.path.join(config.SCREENING_DIR, f'dmpnn_preds_{key}.csv')
        probs = predict_chemprop(model_dir, hub_smiles_csv, preds_csv, version_type, gpu)
        if probs is not None:
            pathogen_probs[key] = probs
            logger.info(f"    P_{key}: mean={probs.mean():.4f}, max={probs.max():.4f}")
        else:
            logger.warning(f"    Failed to get predictions for {key}")

    gut_probs = {}
    for key, model_dir in gut_model_dirs.items():
        preds_csv = os.path.join(config.SCREENING_DIR, f'dmpnn_preds_{key}.csv')
        probs = predict_chemprop(model_dir, hub_smiles_csv, preds_csv, version_type, gpu)
        if probs is not None:
            gut_probs[key] = probs
            logger.info(f"    P_{key}: mean={probs.mean():.4f}")
        else:
            logger.warning(f"    Failed to get predictions for {key}")

    # Compute selectivity scores
    ranked_lists = {}
    for pathogen_key, p_path in pathogen_probs.items():
        for gut_key, p_gut in gut_probs.items():
            threshold = gut_key.replace('gut_t', '')
            combo_key = f'{pathogen_key}_t{threshold}'

            S = p_path * (1.0 - p_gut)

            ranked_df = df_hub[['smiles', 'name', 'clinical_phase', 'moa',
                                 'disease_area', 'target']].copy()
            ranked_df['p_pathogen'] = np.round(p_path, 6)
            ranked_df['p_gut'] = np.round(p_gut, 6)
            ranked_df['selectivity_score'] = np.round(S, 6)
            ranked_df = ranked_df.sort_values('selectivity_score', ascending=False).reset_index(drop=True)
            ranked_df['rank'] = range(1, len(ranked_df) + 1)

            csv_path = os.path.join(config.SCREENING_DIR, f'dmpnn_ranked_{combo_key}.csv')
            ranked_df.to_csv(csv_path, index=False)
            ranked_lists[combo_key] = ranked_df

            logger.info(f"    {combo_key}: S max={S.max():.4f}, "
                         f"top-1: {ranked_df.iloc[0]['name']}")

    return ranked_lists


# ===========================================================================
# Visualization
# ===========================================================================

def generate_phase3b_figures(all_cv_results: Dict, ranked_lists: Dict):
    """Generate publication-quality figures for Phase 3B."""
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import seaborn as sns

    os.makedirs(config.FIGURES_DIR, exist_ok=True)
    setup_publication_style()

    # Figure 1: CV metrics bar chart
    if all_cv_results:
        model_names = list(all_cv_results.keys())
        roc_means = [all_cv_results[m].get('mean_roc_auc') or 0 for m in model_names]
        roc_stds = [all_cv_results[m].get('std_roc_auc') or 0 for m in model_names]
        pr_means = [all_cv_results[m].get('mean_pr_auc') or 0 for m in model_names]
        pr_stds = [all_cv_results[m].get('std_pr_auc') or 0 for m in model_names]

        fig, axes = plt.subplots(1, 2, figsize=(14, 5))
        x = np.arange(len(model_names))
        display_names = [n.replace('_', '\n') for n in model_names]

        ax = axes[0]
        ax.bar(x, roc_means, yerr=roc_stds, color=COLORS['dmpnn'],
               edgecolor='black', linewidth=0.5, capsize=3)
        for i, (m, s) in enumerate(zip(roc_means, roc_stds)):
            ax.text(i, m + s + 0.01, f'{m:.3f}', ha='center', va='bottom', fontsize=8)
        ax.set_xticks(x); ax.set_xticklabels(display_names, fontsize=7)
        ax.set_ylabel('ROC-AUC'); ax.set_title('A. D-MPNN ROC-AUC (5-fold scaffold CV)')
        ax.set_ylim(0, 1.05); ax.axhline(y=0.5, color='gray', linestyle='--', alpha=0.3)
        sns.despine(ax=ax)

        ax = axes[1]
        ax.bar(x, pr_means, yerr=pr_stds, color=COLORS['dmpnn'],
               edgecolor='black', linewidth=0.5, capsize=3)
        for i, (m, s) in enumerate(zip(pr_means, pr_stds)):
            ax.text(i, m + s + 0.01, f'{m:.3f}', ha='center', va='bottom', fontsize=8)
        ax.set_xticks(x); ax.set_xticklabels(display_names, fontsize=7)
        ax.set_ylabel('PR-AUC'); ax.set_title('B. D-MPNN PR-AUC (5-fold scaffold CV)')
        ax.set_ylim(0, 1.05); sns.despine(ax=ax)

        plt.tight_layout()
        save_figure(fig, os.path.join(config.FIGURES_DIR, 'phase3b_cv_metrics'))
        logger.info("  Figure: phase3b_cv_metrics")

    # Figure 2: Selectivity for E. coli t=10
    key = 'ecoli_t10'
    if key in ranked_lists:
        df_r = ranked_lists[key]
        fig, axes = plt.subplots(1, 3, figsize=(15, 4.5))

        ax = axes[0]
        ax.hist(df_r['selectivity_score'], bins=60, color=COLORS['dmpnn'],
                edgecolor='white', linewidth=0.3, alpha=0.8)
        ax.set_xlabel('Selectivity Score S'); ax.set_ylabel('Count')
        ax.set_title('A. S distribution (D-MPNN, E. coli, t=10)')
        sns.despine(ax=ax)

        ax = axes[1]
        sc = ax.scatter(df_r['p_gut'], df_r['p_pathogen'],
                        c=df_r['selectivity_score'], cmap='RdYlGn',
                        s=4, alpha=0.5, edgecolors='none', vmin=0, vmax=1)
        plt.colorbar(sc, ax=ax, label='S score')
        ax.set_xlabel('$\\hat{P}_{gut}$'); ax.set_ylabel('$\\hat{P}_{pathogen}$')
        ax.set_title('B. Pathogen vs Gut probability')
        sns.despine(ax=ax)

        ax = axes[2]
        top20 = df_r.head(20)
        ax.barh(range(len(top20)), top20['selectivity_score'], color=COLORS['highlight'],
                edgecolor='black', linewidth=0.5)
        ax.set_yticks(range(len(top20)))
        ax.set_yticklabels([f"{r['name'][:25]}" for _, r in top20.iterrows()], fontsize=7)
        ax.set_xlabel('Selectivity Score S')
        ax.set_title('C. Top 20 Candidates (D-MPNN)'); ax.invert_yaxis()
        sns.despine(ax=ax)

        plt.tight_layout()
        save_figure(fig, os.path.join(config.FIGURES_DIR, 'phase3b_selectivity_ecoli'))
        logger.info("  Figure: phase3b_selectivity_ecoli")


# ===========================================================================
# Unit tests
# ===========================================================================

def run_unit_tests() -> bool:
    """Run unit tests (no GPU/Chemprop required)."""
    print("Running Phase 3B unit tests...")
    n_pass = 0
    n_fail = 0

    def _assert(condition, msg):
        nonlocal n_pass, n_fail
        if condition:
            n_pass += 1; print(f"  [PASS] {msg}")
        else:
            n_fail += 1; print(f"  [FAIL] {msg}")

    # Test fold CSV writing logic
    import tempfile
    with tempfile.TemporaryDirectory() as tmpdir:
        # Create test data
        test_df = pd.DataFrame({
            'smiles': ['CCO', 'CCN', 'CCC', 'CCCC', 'CCCCC',
                        'c1ccccc1', 'c1ccc(O)cc1', 'c1ccncc1', 'C1CCCCC1', 'CC(=O)O'],
            'label': [1, 0, 1, 0, 1, 0, 1, 0, 1, 0],
        })
        csv_path = os.path.join(tmpdir, 'test_data.csv')
        test_df.to_csv(csv_path, index=False)

        # Verify CSV format
        reloaded = pd.read_csv(csv_path)
        _assert(list(reloaded.columns) == ['smiles', 'label'],
                "D-MPNN CSV has [smiles, label] columns")
        _assert(len(reloaded) == 10, "CSV row count correct")

        # Test fold splitting and writing
        folds = [i % 5 for i in range(10)]
        train_idx, test_idx = get_train_test_indices(folds, test_fold=0)

        train_df = test_df.iloc[train_idx]
        test_df_fold = test_df.iloc[test_idx]

        train_csv = os.path.join(tmpdir, 'train.csv')
        test_csv = os.path.join(tmpdir, 'test.csv')
        train_df.to_csv(train_csv, index=False)
        test_df_fold.to_csv(test_csv, index=False)

        _assert(len(pd.read_csv(train_csv)) == len(train_idx), "Train CSV size correct")
        _assert(len(pd.read_csv(test_csv)) == len(test_idx), "Test CSV size correct")

    # Test selectivity score computation
    p_path = np.array([0.9, 0.8, 0.1, 0.5])
    p_gut = np.array([0.1, 0.9, 0.1, 0.5])
    S = p_path * (1 - p_gut)
    _assert(abs(S[0] - 0.81) < 0.01, f"S(high,low)={S[0]:.3f}")
    _assert(abs(S[1] - 0.08) < 0.01, f"S(high,high)={S[1]:.3f}")
    _assert(abs(S[2] - 0.09) < 0.01, f"S(low,low)={S[2]:.3f}")
    _assert(abs(S[3] - 0.25) < 0.01, f"S(mid,mid)={S[3]:.3f}")

    # Test ranking logic
    scores = np.array([0.3, 0.9, 0.1, 0.7, 0.5])
    ranked_idx = np.argsort(scores)[::-1]
    _assert(ranked_idx[0] == 1, "Highest score ranked first")
    _assert(ranked_idx[-1] == 2, "Lowest score ranked last")

    # Test OOF aggregation logic
    oof = np.full(10, np.nan)
    oof[0:2] = [0.8, 0.3]
    oof[5:7] = [0.6, 0.1]
    valid = ~np.isnan(oof)
    _assert(valid.sum() == 4, f"OOF valid count: {valid.sum()}")

    # Test metric computation on known data
    y_true = np.array([1, 1, 0, 0, 1])
    y_prob = np.array([0.9, 0.8, 0.2, 0.1, 0.7])
    auc = roc_auc_score(y_true, y_prob)
    _assert(abs(auc - 1.0) < 0.01, f"Perfect separation AUC={auc:.3f}")

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
        logger.error("Unit tests FAILED. Aborting."); sys.exit(1)
    logger.info("All unit tests passed.\n")

    start_time = log_phase_start(logger, "Phase 3B: D-MPNN Pipeline Training")

    ckpt_path = os.path.join(config.CHECKPOINTS_DIR, 'phase3b_master.json')
    ckpt = load_checkpoint(ckpt_path, logger)
    if ckpt and ckpt.get('status') == 'complete':
        logger.info("Phase 3B already completed. Skipping.")
        log_phase_end(logger, "Phase 3B", start_time); return

    os.makedirs(config.DMPNN_DIR, exist_ok=True)
    os.makedirs(config.SCREENING_DIR, exist_ok=True)
    os.makedirs(config.FIGURES_DIR, exist_ok=True)
    os.makedirs(config.REPORTS_DIR, exist_ok=True)

    # Try restoring pre-trained D-MPNN models from ZIP (local or Drive)
    try:
        from utils.gdrive_backup import get_data_manager
        dm = get_data_manager()
        if dm.restore_dmpnn_models(config.PROJECT_DIR):
            # Verify models + metrics + screening lists exist
            pt_count = 0
            for root, dirs, files in os.walk(config.DMPNN_DIR):
                pt_count += len([f for f in files if f.endswith(('.pt', '.ckpt'))])
            metrics_path = os.path.join(config.RESULTS_DIR, 'dmpnn_cv_metrics.json')
            n_screen = len([f for f in os.listdir(config.SCREENING_DIR) if f.startswith('dmpnn_ranked_')]) if os.path.isdir(config.SCREENING_DIR) else 0
            if pt_count >= 5 and os.path.exists(metrics_path) and n_screen >= 12:
                logger.info(f"\n  D-MPNN models restored from cache: {pt_count} checkpoints, {n_screen} screening lists")
                logger.info(f"  Skipping training (already computed).")
                save_checkpoint({'status': 'complete'}, os.path.join(config.CHECKPOINTS_DIR, 'phase3b_master.json'), logger)
                log_phase_end(logger, "Phase 3B (cached)", start_time)
                return
            else:
                logger.info(f"  Partial D-MPNN restore: {pt_count} checkpoints, {n_screen} screening lists. Retraining...")
    except Exception:
        pass

    # Detect Chemprop version
    logger.info("Detecting Chemprop version...")
    version, version_type = detect_chemprop_version()
    if version_type == 'none':
        logger.error("Chemprop not available. Cannot proceed.")
        sys.exit(1)

    # Check GPU
    import torch
    gpu_available = torch.cuda.is_available()
    if gpu_available:
        logger.info(f"GPU: {torch.cuda.get_device_name(0)} "
                     f"({torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB)")
    else:
        logger.warning("No GPU detected. Training will be slow on CPU.")

    all_cv_results = {}
    pathogen_final_dirs = {}
    gut_final_dirs = {}
    quality_report = {}
    dmpnn_input_dir = os.path.join(config.DATA_DIR, 'dmpnn_input')

    # ==================================================================
    # Prepare D-MPNN input CSVs (if not already created by Phase 2)
    # ==================================================================
    os.makedirs(dmpnn_input_dir, exist_ok=True)
    logger.info("\n  Preparing D-MPNN input CSVs...")

    for key, pinfo in config.PATHOGENS.items():
        out_csv = os.path.join(dmpnn_input_dir, f'{key}.csv')
        if not os.path.exists(out_csv):
            src_csv = os.path.join(config.CHEMBL_DIR, pinfo['csv_filename'])
            if os.path.exists(src_csv):
                df_src = pd.read_csv(src_csv)
                df_src[['smiles', 'activity_label']].rename(
                    columns={'activity_label': 'label'}
                ).to_csv(out_csv, index=False)
                logger.info(f"    Created: {out_csv} ({len(df_src)} rows)")

    maier_csv = os.path.join(config.MAIER_DIR, 'maier_combined.csv')
    if os.path.exists(maier_csv):
        df_maier = pd.read_csv(maier_csv)
        for t in config.HARM_THRESHOLDS:
            out_csv = os.path.join(dmpnn_input_dir, f'gut_t{t}.csv')
            if not os.path.exists(out_csv):
                df_maier[['smiles', f'harm_t{t}']].rename(
                    columns={f'harm_t{t}': 'label'}
                ).to_csv(out_csv, index=False)
                logger.info(f"    Created: {out_csv} ({len(df_maier)} rows)")

    hub_csv_src = os.path.join(config.HUB_DIR, config.HUB_CLEAN_FILENAME)
    hub_screen_csv = os.path.join(dmpnn_input_dir, 'hub_screen.csv')
    if os.path.exists(hub_csv_src) and not os.path.exists(hub_screen_csv):
        df_hub = pd.read_csv(hub_csv_src)
        df_hub[['smiles']].to_csv(hub_screen_csv, index=False)
        logger.info(f"    Created: {hub_screen_csv} ({len(df_hub)} rows)")

    # ==================================================================
    # Train 4 pathogen models
    # ==================================================================
    total_dmpnn_models = len(config.PATHOGENS) + len(config.HARM_THRESHOLDS)
    model_num = 0
    logger.info(f"\n{'='*60}")
    logger.info(f" PATHOGEN D-MPNN MODELS ({len(config.PATHOGENS)} of {total_dmpnn_models} total)")
    logger.info(f"{'='*60}")
    logger.info(f"  Each model takes 10-30 min depending on dataset size.")

    for key in config.PATHOGENS:
        model_num += 1
        _PM = f"06_train_dmpnn.py:main:pathogen_{key}"
        logger.info(f"\n  >>> Model {model_num}/{total_dmpnn_models}: dmpnn_{key} <<<")
        data_csv = os.path.join(dmpnn_input_dir, f'{key}.csv')
        folds_path = os.path.join(config.SPLITS_DIR, f'{key}_scaffold_folds.pkl')

        if not os.path.exists(data_csv):
            logger.warning(f"  [{_PM}] MISSING: {data_csv}. Run Phase 2 first."); continue
        if not os.path.exists(folds_path):
            logger.warning(f"  [{_PM}] MISSING: {folds_path}. Run Phase 2 first."); continue

        try:
            folds = load_folds(folds_path)
        except Exception as e:
            logger.error(f"  [{_PM}] load_folds FAILED: {type(e).__name__}: {e}")
            continue

        model_dir = os.path.join(config.DMPNN_DIR, key)
        try:
            result = train_dmpnn_with_cv(
                data_csv, folds, f'dmpnn_{key}', model_dir, version_type, gpu_available
            )
        except Exception as e:
            logger.error(f"  [{_PM}] TRAINING FAILED: {type(e).__name__}: {e}")
            import traceback; logger.error(traceback.format_exc())
            continue
        all_cv_results[key] = result
        pathogen_final_dirs[key] = result['final_model_dir']

        # Save OOF predictions
        df_src = pd.read_csv(data_csv)
        oof_path = os.path.join(config.DMPNN_DIR, key, f'dmpnn_{key}_oof.csv')
        oof_df = pd.DataFrame({
            'smiles': df_src['smiles'].values,
            'true_label': result['oof_labels'],
            'oof_prob': result['oof_predictions'],
        })
        oof_df.to_csv(oof_path, index=False)

        quality_report[key] = {
            'roc_auc': f"{result.get('mean_roc_auc', '?')} +/- {result.get('std_roc_auc', '?')}",
            'pr_auc': f"{result.get('mean_pr_auc', '?')} +/- {result.get('std_pr_auc', '?')}",
            'fold_metrics': result['fold_metrics'],
        }

    # ==================================================================
    # Train 3 gut harm models
    # ==================================================================
    logger.info(f"\n{'='*60}")
    logger.info(f" GUT HARM D-MPNN MODELS (3 thresholds)")
    logger.info(f"{'='*60}")

    maier_folds_path = os.path.join(config.SPLITS_DIR, 'maier_scaffold_folds.pkl')
    if os.path.exists(maier_folds_path):
        maier_folds = load_folds(maier_folds_path)

        for t in config.HARM_THRESHOLDS:
            model_num += 1
            name = f'gut_t{t}'
            logger.info(f"\n  >>> Model {model_num}/{total_dmpnn_models}: dmpnn_{name} <<<")
            data_csv = os.path.join(dmpnn_input_dir, f'{name}.csv')
            if not os.path.exists(data_csv):
                logger.warning(f"  Missing {data_csv}, skipping."); continue

            model_dir = os.path.join(config.DMPNN_DIR, name)
            result = train_dmpnn_with_cv(
                data_csv, maier_folds, f'dmpnn_{name}', model_dir, version_type, gpu_available
            )
            all_cv_results[name] = result
            gut_final_dirs[name] = result['final_model_dir']

            df_src = pd.read_csv(data_csv)
            oof_df = pd.DataFrame({
                'smiles': df_src['smiles'].values,
                'true_label': result['oof_labels'],
                'oof_prob': result['oof_predictions'],
            })
            oof_df.to_csv(os.path.join(model_dir, f'dmpnn_{name}_oof.csv'), index=False)

            quality_report[name] = {
                'roc_auc': f"{result.get('mean_roc_auc', '?')} +/- {result.get('std_roc_auc', '?')}",
                'pr_auc': f"{result.get('mean_pr_auc', '?')} +/- {result.get('std_pr_auc', '?')}",
                'fold_metrics': result['fold_metrics'],
            }

    # ==================================================================
    # Screen Drug Repurposing Hub
    # ==================================================================
    logger.info("\n" + "="*60)
    logger.info(" D-MPNN VIRTUAL SCREENING")
    logger.info("="*60)

    hub_csv = os.path.join(config.HUB_DIR, config.HUB_CLEAN_FILENAME)
    ranked_lists = {}
    if os.path.exists(hub_csv) and pathogen_final_dirs and gut_final_dirs:
        ranked_lists = screen_hub_dmpnn(
            pathogen_final_dirs, gut_final_dirs, hub_csv, version_type, gpu_available
        )
    else:
        logger.warning("  Missing Hub or models, skipping screening.")

    # ==================================================================
    # Save CV metrics for Phase 4
    # ==================================================================
    cv_metrics_path = os.path.join(config.RESULTS_DIR, 'dmpnn_cv_metrics.json')
    cv_export = {}
    for name, result in all_cv_results.items():
        cv_export[name] = {
            'mean_roc_auc': result.get('mean_roc_auc'),
            'std_roc_auc': result.get('std_roc_auc'),
            'mean_pr_auc': result.get('mean_pr_auc'),
            'std_pr_auc': result.get('std_pr_auc'),
            'fold_metrics': result['fold_metrics'],
        }
    with open(cv_metrics_path, 'w') as f:
        json.dump(cv_export, f, indent=2, default=str)

    # ==================================================================
    # Figures
    # ==================================================================
    logger.info("\nGenerating Phase 3B figures...")
    try:
        generate_phase3b_figures(all_cv_results, ranked_lists)
    except Exception as e:
        logger.warning(f"Figure generation failed: {e}")

    # ==================================================================
    # Report and summary
    # ==================================================================
    report_path = os.path.join(config.REPORTS_DIR, 'phase3b_quality_report.json')
    with open(report_path, 'w') as f:
        json.dump(quality_report, f, indent=2, default=str)

    logger.info("\n" + "="*60)
    logger.info(" PHASE 3B SUMMARY")
    logger.info("="*60)
    header = f"{'Model':<20} {'ROC-AUC':>20} {'PR-AUC':>20}"
    logger.info(header)
    logger.info("-" * 62)
    for name, result in all_cv_results.items():
        roc = f"{result.get('mean_roc_auc', '?')} +/- {result.get('std_roc_auc', '?')}"
        pr = f"{result.get('mean_pr_auc', '?')} +/- {result.get('std_pr_auc', '?')}"
        logger.info(f"  {name:<18} {roc:>20} {pr:>20}")
    logger.info("="*60)
    if ranked_lists:
        logger.info(f"  Virtual screening: {len(ranked_lists)} ranked lists saved")

    save_checkpoint(
        {'status': 'complete', 'chemprop_version': version,
         'models_trained': list(all_cv_results.keys()),
         'ranked_lists': list(ranked_lists.keys())},
        ckpt_path, logger,
    )

    # Pack trained D-MPNN models + screening lists into ZIP and push to Drive
    try:
        from utils.gdrive_backup import get_data_manager
        dm = get_data_manager()
        dm.pack_dmpnn_models(config.PROJECT_DIR)
    except Exception as e:
        logger.debug(f"  D-MPNN model packing skipped: {e}")

    log_phase_end(logger, "Phase 3B", start_time)


if __name__ == '__main__':
    main()
