#!/usr/bin/env python3
"""
20_retrain_dmpnn_rdkit.py -- Retrain D-MPNN with RDKit 2D features

Retrains D-MPNN with Stokes-like architecture:
  - depth=5, hidden=1600, dropout=0.35 (vs current depth=3, hidden=300)
  - RDKit 2D normalized descriptors concatenated to graph representation
  - Ensemble screening: average 5 fold model predictions (vs single final)

Uses 4 GPUs in parallel. Same scaffold splits as original pipeline.
All outputs go to NEW paths (dmpnn_rdkit/). Nothing existing is modified.

Self-contained: includes training, screening, validation, enrichment,
head-to-head comparison with old D-MPNN, Stokes correlation, and figures.

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    April 2026
"""

import os, sys, json, time, warnings, pickle, subprocess
import numpy as np
import pandas as pd
from typing import Dict, List, Optional, Tuple

warnings.filterwarnings('ignore')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import config
from utils.logging_utils import setup_logging, log_phase_start, log_phase_end

logger = setup_logging('phase_dmpnn_rdkit', log_dir=config.LOGS_DIR)

# ===================================================================
# New architecture parameters (Stokes-like)
# ===================================================================

DMPNN_RDKIT_PARAMS = {
    'hidden_dim': 1600,
    'depth': 5,
    'dropout': 0.35,
    'epochs': 50,
    'batch_size': 50,
    'ffn_num_layers': 2,
    'ffn_hidden_dim': 1600,
}

PIPELINE_NAME = 'dmpnn_rdkit'
N_GPUS = 4
N_FOLDS = 5

PATHOGEN_TASKS = ['ecoli', 'saureus', 'paeruginosa', 'mtb']
GUT_TASKS = ['gut_t5', 'gut_t10', 'gut_t20']
ALL_TASKS = PATHOGEN_TASKS + GUT_TASKS

# Directories
DMPNN_RDKIT_DIR = os.path.join(config.MODELS_DIR, PIPELINE_NAME)
DMPNN_INPUT_DIR = os.path.join(config.DATA_DIR, 'dmpnn_input')

# Chemprop CLI base command
BIN_DIR = os.path.dirname(sys.executable)
CHEMPROP_CMD = os.path.join(BIN_DIR, 'chemprop')


# ===================================================================
# Fold loading
# ===================================================================

def load_folds_for_task(task):
    """Load scaffold fold assignments for a task."""
    if task.startswith('gut_'):
        folds_path = os.path.join(config.SPLITS_DIR,
                                  'maier_scaffold_folds.pkl')
    else:
        folds_path = os.path.join(config.SPLITS_DIR,
                                  f'{task}_scaffold_folds.pkl')

    if not os.path.exists(folds_path):
        logger.error(f"  Splits not found: {folds_path}")
        return None

    with open(folds_path, 'rb') as f:
        folds = pickle.load(f)
    return folds


def write_fold_data(task, fold_idx, folds):
    """
    Write combined CSV and splits JSON for one fold.
    Returns (combined_csv_path, splits_json_path).
    """
    data_csv = os.path.join(DMPNN_INPUT_DIR, f'{task}.csv')
    df = pd.read_csv(data_csv)

    fold_dir = os.path.join(DMPNN_RDKIT_DIR, task, f'fold_{fold_idx}')
    os.makedirs(fold_dir, exist_ok=True)

    # Fold assignments: test = where folds[j] == fold_idx
    train_idx = [j for j, f in enumerate(folds) if f != fold_idx]
    val_idx = [j for j, f in enumerate(folds) if f == fold_idx]

    # Write combined CSV (all data)
    combined_csv = os.path.join(fold_dir, 'combined.csv')
    df.to_csv(combined_csv, index=False)

    # Write splits JSON: [{"train": [...], "val": [...], "test": []}]
    splits_json = os.path.join(fold_dir, 'splits.json')
    with open(splits_json, 'w') as f:
        json.dump([{"train": train_idx, "val": val_idx, "test": []}], f)

    return combined_csv, splits_json, fold_dir


def write_final_data(task):
    """Prepare data for final model (all data, no val)."""
    data_csv = os.path.join(DMPNN_INPUT_DIR, f'{task}.csv')
    final_dir = os.path.join(DMPNN_RDKIT_DIR, task, 'final')
    os.makedirs(final_dir, exist_ok=True)
    return data_csv, final_dir


# ===================================================================
# Training
# ===================================================================

def build_train_cmd(data_csv, save_dir, gpu_id,
                    splits_json=None, is_final=False):
    """Build chemprop train CLI command."""
    cmd = [
        CHEMPROP_CMD, 'train',
        '--data-path', data_csv,
        '--save-dir', save_dir,
        '--task-type', 'classification',
        '--epochs', str(DMPNN_RDKIT_PARAMS['epochs']),
        '--batch-size', str(DMPNN_RDKIT_PARAMS['batch_size']),
        '--message-hidden-dim', str(DMPNN_RDKIT_PARAMS['hidden_dim']),
        '--depth', str(DMPNN_RDKIT_PARAMS['depth']),
        '--dropout', str(DMPNN_RDKIT_PARAMS['dropout']),
        '--ffn-hidden-dim', str(DMPNN_RDKIT_PARAMS['ffn_hidden_dim']),
        '--ffn-num-layers', str(DMPNN_RDKIT_PARAMS['ffn_num_layers']),
        '--smiles-columns', 'smiles',
        '--target-columns', 'label',
        '--molecule-featurizers', 'v1_rdkit_2d_normalized',
        '--num-workers', '0',
        '--accelerator', 'gpu',
        '--devices', '1',
    ]

    if is_final:
        cmd.extend(['--split', 'RANDOM',
                     '--split-sizes', '1.0', '0.0', '0.0'])
    elif splits_json:
        cmd.extend(['--splits-file', splits_json])

    return cmd


def get_clean_env():
    """Get environment with SLURM variables overridden."""
    env = os.environ.copy()
    env['SLURM_NTASKS'] = '1'
    env['SLURM_NTASKS_PER_NODE'] = '1'
    env['SLURM_JOB_NAME'] = 'bash'
    return env

def build_predict_cmd(model_path, test_csv, preds_csv):
    """Build chemprop predict CLI command."""
    return [
        CHEMPROP_CMD, 'predict',
        '--test-path', test_csv,
        '--model-path', model_path,
        '--preds-path', preds_csv,
        '--smiles-column', 'smiles',
        '--molecule-featurizers', 'v1_rdkit_2d_normalized',
    ]


class GPUPool:
    """Manage parallel training across SLURM-allocated GPUs."""

    def __init__(self, n_gpus):
        # Read SLURM-allocated GPU IDs from environment
        cuda_env = os.environ.get('CUDA_VISIBLE_DEVICES', '')
        if cuda_env:
            self.gpu_ids = [g.strip() for g in cuda_env.split(',')]
        else:
            self.gpu_ids = [str(i) for i in range(n_gpus)]

        # Only use up to n_gpus
        self.gpu_ids = self.gpu_ids[:n_gpus]
        self.available = list(self.gpu_ids)
        self.running = {}  # gpu_id -> (process, task_name, log_file, log_path)
        logger.info(f"  GPUPool initialized: {len(self.gpu_ids)} GPUs "
                    f"(IDs: {self.gpu_ids})")

    def submit(self, cmd, task_name, gpu_id):
        env = os.environ.copy()
        env['CUDA_VISIBLE_DEVICES'] = str(gpu_id)
        env['OMP_NUM_THREADS'] = '8'
        env['SLURM_NTASKS'] = '1'
        env['SLURM_JOB_NAME'] = 'bash'
        env['SLURM_NTASKS'] = '1'
        env['SLURM_JOB_NAME'] = 'bash'
        env['MKL_NUM_THREADS'] = '8'

        log_path = os.path.join(DMPNN_RDKIT_DIR,
                                f'train_{task_name}.log')
        log_file = open(log_path, 'w')

        proc = subprocess.Popen(
            cmd, env=env,
            stdout=log_file, stderr=subprocess.STDOUT)

        self.running[gpu_id] = (proc, task_name, log_file, log_path)
        self.available.remove(gpu_id)
        logger.info(f"    Launched {task_name} on GPU {gpu_id} "
                    f"(PID {proc.pid})")
        logger.info(f"    CMD: {' '.join(cmd[:6])}...")
        logger.info(f"    Log: {log_path}")

    def wait_for_one(self):
        """Wait for any task to complete. Returns (gpu_id, task_name, ok)."""
        while True:
            for gpu_id, (proc, name, log_file, log_path) in list(
                    self.running.items()):
                ret = proc.poll()
                if ret is not None:
                    log_file.close()
                    del self.running[gpu_id]
                    self.available.append(gpu_id)
                    ok = (ret == 0)
                    if not ok:
                        logger.error(f"    {name} FAILED (exit code {ret})")
                        # Log last 10 lines of training log
                        try:
                            with open(log_path, 'r') as lf:
                                lines = lf.readlines()
                                tail = lines[-10:] if len(lines) > 10 else lines
                                logger.error(f"    Last lines of {log_path}:")
                                for line in tail:
                                    logger.error(f"      {line.rstrip()}")
                        except Exception:
                            logger.error(f"    Could not read log: {log_path}")
                    else:
                        logger.info(f"    {name} completed (GPU {gpu_id})")
                    return gpu_id, name, ok
            time.sleep(5)

    def wait_all(self):
        """Wait for all running tasks to complete."""
        results = {}
        while self.running:
            gpu_id, name, ok = self.wait_for_one()
            results[name] = ok
        return results

    def get_gpu(self):
        """Get an available GPU, waiting if necessary."""
        if not self.available:
            self.wait_for_one()
        return self.available[0]


def train_all_models():
    """Train all 7 tasks x (5 folds + 1 final) = 42 models."""
    logger.info("\n" + "=" * 70)
    logger.info(f"  TRAINING D-MPNN + RDKit (Stokes architecture)")
    logger.info(f"  depth={DMPNN_RDKIT_PARAMS['depth']}, "
                f"hidden={DMPNN_RDKIT_PARAMS['hidden_dim']}, "
                f"dropout={DMPNN_RDKIT_PARAMS['dropout']}")
    logger.info(f"  Features: v1_rdkit_2d_normalized")
    logger.info(f"  GPUs: {N_GPUS} in parallel")
    logger.info("=" * 70)

    os.makedirs(DMPNN_RDKIT_DIR, exist_ok=True)
    pool = GPUPool(N_GPUS)

    # Phase 1: Train all folds (needed for ensemble + CV metrics)
    logger.info("\n  Phase 1: Training fold models (35 total)...")
    fold_results = {}
    total = 0

    for task in ALL_TASKS:
        folds = load_folds_for_task(task)
        if folds is None:
            continue

        data_csv = os.path.join(DMPNN_INPUT_DIR, f'{task}.csv')
        if not os.path.exists(data_csv):
            logger.warning(f"  Missing: {data_csv}")
            continue

        for fold_idx in range(N_FOLDS):
            task_name = f'{task}_fold{fold_idx}'

            # Skip if already trained
            model_path = os.path.join(DMPNN_RDKIT_DIR, task,
                                      f'fold_{fold_idx}',
                                      'model_0', 'best.pt')
            if os.path.exists(model_path):
                logger.info(f"    {task_name}: already trained, skipping")
                fold_results[task_name] = True
                continue

            combined_csv, splits_json, fold_dir = write_fold_data(
                task, fold_idx, folds)

            cmd = build_train_cmd(combined_csv, fold_dir,
                                  pool.get_gpu(),
                                  splits_json=splits_json)
            gpu_id = pool.get_gpu()
            pool.submit(cmd, task_name, gpu_id)
            total += 1

    # Wait for all folds to complete
    if pool.running:
        fold_results.update(pool.wait_all())

    # Verify fold models actually exist
    n_ok = 0
    n_missing = 0
    for task in ALL_TASKS:
        for fold_idx in range(N_FOLDS):
            model_path = os.path.join(DMPNN_RDKIT_DIR, task,
                                      f'fold_{fold_idx}',
                                      'model_0', 'best.pt')
            if os.path.exists(model_path):
                n_ok += 1
            else:
                n_missing += 1
                logger.error(f"    MISSING MODEL: {model_path}")
    logger.info(f"\n  Fold models: {n_ok} exist, {n_missing} missing "
                f"(expected 35)")

    # Phase 2: Train final models (all data, no validation)
    logger.info("\n  Phase 2: Training final models (7 total)...")
    final_results = {}

    for task in ALL_TASKS:
        task_name = f'{task}_final'

        model_path = os.path.join(DMPNN_RDKIT_DIR, task,
                                  'final', 'model_0', 'best.pt')
        if os.path.exists(model_path):
            logger.info(f"    {task_name}: already trained, skipping")
            final_results[task_name] = True
            continue

        data_csv, final_dir = write_final_data(task)
        if not os.path.exists(data_csv):
            logger.error(f"    {task_name}: MISSING data CSV {data_csv}")
            final_results[task_name] = False
            continue

        cmd = build_train_cmd(data_csv, final_dir,
                              pool.get_gpu(), is_final=True)
        gpu_id = pool.get_gpu()
        pool.submit(cmd, task_name, gpu_id)

    if pool.running:
        final_results.update(pool.wait_all())

    # Verify final models
    n_ok = sum(1 for t in ALL_TASKS
               if os.path.exists(os.path.join(
                   DMPNN_RDKIT_DIR, t, 'final', 'model_0', 'best.pt')))
    logger.info(f"\n  Final models: {n_ok}/7 exist")

    # Save training status checkpoint
    status = {
        'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
        'fold_results': {k: bool(v) for k, v in fold_results.items()},
        'final_results': {k: bool(v) for k, v in final_results.items()},
        'fold_models_exist': n_ok,
    }
    status_path = os.path.join(DMPNN_RDKIT_DIR, 'training_status.json')
    with open(status_path, 'w') as f:
        json.dump(status, f, indent=2)
    logger.info(f"  Saved training status: {status_path}")

    return fold_results, final_results


# ===================================================================
# CV Metrics
# ===================================================================

def collect_cv_metrics():
    """Collect OOF predictions from fold models and compute metrics."""
    from sklearn.metrics import roc_auc_score, average_precision_score

    logger.info("\n" + "=" * 70)
    logger.info("  CV METRICS (from fold model predictions)")
    logger.info("=" * 70)

    all_metrics = {}

    for task in ALL_TASKS:
        folds = load_folds_for_task(task)
        if folds is None:
            continue

        data_csv = os.path.join(DMPNN_INPUT_DIR, f'{task}.csv')
        df = pd.read_csv(data_csv)
        labels = df['label'].values

        oof_probs = np.full(len(df), np.nan)

        for fold_idx in range(N_FOLDS):
            model_path = os.path.join(DMPNN_RDKIT_DIR, task,
                                      f'fold_{fold_idx}',
                                      'model_0', 'best.pt')
            if not os.path.exists(model_path):
                logger.warning(f"  {task} fold {fold_idx}: no model")
                continue

            # Predict on test fold
            val_idx = [j for j, f in enumerate(folds) if f == fold_idx]
            val_df = df.iloc[val_idx][['smiles']].copy()

            val_csv = os.path.join(DMPNN_RDKIT_DIR, task,
                                   f'fold_{fold_idx}', 'val_smiles.csv')
            val_df.to_csv(val_csv, index=False)

            preds_csv = os.path.join(DMPNN_RDKIT_DIR, task,
                                     f'fold_{fold_idx}', 'val_preds.csv')

            cmd = build_predict_cmd(model_path, val_csv, preds_csv)
            result = subprocess.run(cmd, capture_output=True, text=True,
                                    env=get_clean_env())

            if result.returncode != 0:
                logger.error(f"  {task} fold {fold_idx}: OOF predict FAILED "
                             f"(exit {result.returncode})")
                stderr_tail = result.stderr[-300:] if result.stderr else ''
                if stderr_tail:
                    logger.error(f"    STDERR: {stderr_tail}")
                continue

            if os.path.exists(preds_csv):
                preds_df = pd.read_csv(preds_csv)
                pred_cols = [c for c in preds_df.columns if c != 'smiles']
                if pred_cols:
                    fold_probs = preds_df[pred_cols[0]].values
                    n_filled = 0
                    for i, idx in enumerate(val_idx):
                        if i < len(fold_probs):
                            oof_probs[idx] = fold_probs[i]
                            n_filled += 1
                    logger.info(f"    {task} fold {fold_idx}: "
                                f"{n_filled}/{len(val_idx)} OOF predictions")
                else:
                    logger.error(f"    {task} fold {fold_idx}: "
                                 f"no prediction column in {preds_csv}")
            else:
                logger.error(f"    {task} fold {fold_idx}: "
                             f"no output file {preds_csv}")

        # Compute metrics
        valid = ~np.isnan(oof_probs)
        if valid.sum() < 10:
            logger.warning(f"  {task}: too few OOF predictions")
            continue

        y_true = labels[valid]
        y_prob = oof_probs[valid]

        # Compute per-fold metrics
        fold_metrics_list = []
        for fold_idx in range(N_FOLDS):
            fold_mask = np.array(folds) == fold_idx
            fold_valid = valid & fold_mask
            if fold_valid.sum() < 5:
                continue
            y_f = labels[fold_valid]
            p_f = oof_probs[fold_valid]
            try:
                f_roc = roc_auc_score(y_f, p_f)
                f_pr = average_precision_score(y_f, p_f)
            except ValueError:
                f_roc = f_pr = 0.0
            fold_metrics_list.append({
                'fold': fold_idx,
                'roc_auc': round(float(f_roc), 4),
                'pr_auc': round(float(f_pr), 4),
                'train_size': int((~fold_mask).sum()),
                'test_size': int(fold_mask.sum()),
            })

        try:
            roc_auc = roc_auc_score(y_true, y_prob)
            pr_auc = average_precision_score(y_true, y_prob)
        except ValueError:
            roc_auc = pr_auc = 0.0

        fold_rocs = [fm['roc_auc'] for fm in fold_metrics_list]
        fold_prs = [fm['pr_auc'] for fm in fold_metrics_list]

        all_metrics[task] = {
            'mean_roc_auc': round(float(np.mean(fold_rocs)), 4) if fold_rocs else round(float(roc_auc), 4),
            'std_roc_auc': round(float(np.std(fold_rocs)), 4) if fold_rocs else 0.0,
            'mean_pr_auc': round(float(np.mean(fold_prs)), 4) if fold_prs else round(float(pr_auc), 4),
            'std_pr_auc': round(float(np.std(fold_prs)), 4) if fold_prs else 0.0,
            'n_samples': int(valid.sum()),
            'n_positive': int(y_true.sum()),
            'fold_metrics': fold_metrics_list,
        }

        logger.info(f"  {task:20s}: ROC-AUC={all_metrics[task]['mean_roc_auc']:.4f} "
                    f"+/- {all_metrics[task]['std_roc_auc']:.4f}  "
                    f"PR-AUC={all_metrics[task]['mean_pr_auc']:.4f}  "
                    f"n={valid.sum()} ({y_true.sum()} pos)")

        # Save OOF predictions
        oof_path = os.path.join(DMPNN_RDKIT_DIR, task,
                                f'{PIPELINE_NAME}_{task}_oof.csv')
        oof_df = pd.DataFrame({
            'smiles': df['smiles'].values,
            'true_label': labels,
            'oof_prob': oof_probs,
        })
        oof_df.to_csv(oof_path, index=False)

    # Save metrics JSON
    metrics_path = os.path.join(config.RESULTS_DIR,
                                f'{PIPELINE_NAME}_cv_metrics.json')
    with open(metrics_path, 'w') as f:
        json.dump(all_metrics, f, indent=2)
    logger.info(f"\n  Saved: {metrics_path}")

    return all_metrics


# ===================================================================
# Hub Screening (Ensemble of 5 fold models)
# ===================================================================

def ensemble_predict_task(task):
    """
    Predict on Hub using ensemble of 5 fold models.
    Returns averaged probability array.
    """
    hub_csv = os.path.join(DMPNN_INPUT_DIR, 'hub_screen.csv')
    all_probs = []

    for fold_idx in range(N_FOLDS):
        model_path = os.path.join(DMPNN_RDKIT_DIR, task,
                                  f'fold_{fold_idx}',
                                  'model_0', 'best.pt')
        if not os.path.exists(model_path):
            logger.warning(f"  {task} fold {fold_idx}: no model, skipping")
            continue

        preds_csv = os.path.join(DMPNN_RDKIT_DIR, task,
                                 f'fold_{fold_idx}', 'hub_preds.csv')

        # Skip if already predicted
        if os.path.exists(preds_csv):
            preds_df = pd.read_csv(preds_csv)
            pred_cols = [c for c in preds_df.columns if c != 'smiles']
            if pred_cols:
                all_probs.append(preds_df[pred_cols[0]].values)
                continue

        cmd = build_predict_cmd(model_path, hub_csv, preds_csv)
        logger.info(f"  Predicting {task} fold {fold_idx}...")
        result = subprocess.run(cmd, capture_output=True, text=True,
                                env=get_clean_env())

        if result.returncode != 0:
            logger.error(f"  {task} fold {fold_idx}: predict FAILED "
                         f"(exit {result.returncode})")
            logger.error(f"  CMD: {' '.join(cmd)}")
            stderr_tail = result.stderr[-500:] if result.stderr else 'no stderr'
            logger.error(f"  STDERR: {stderr_tail}")

        if os.path.exists(preds_csv):
            preds_df = pd.read_csv(preds_csv)
            pred_cols = [c for c in preds_df.columns if c != 'smiles']
            if pred_cols:
                probs = preds_df[pred_cols[0]].values
                if np.isnan(probs).any():
                    logger.warning(f"  {task} fold {fold_idx}: "
                                   f"{np.isnan(probs).sum()} NaN predictions")
                all_probs.append(probs)
            else:
                logger.error(f"  {task} fold {fold_idx}: no prediction "
                             f"column in {preds_csv}")
                logger.error(f"  Columns found: {list(preds_df.columns)}")
        else:
            logger.error(f"  {task} fold {fold_idx}: prediction failed, "
                         f"no output file {preds_csv}")

    if not all_probs:
        return None

    # Ensemble: average across folds
    ensemble = np.mean(all_probs, axis=0)
    logger.info(f"  {task:20s}: ensemble of {len(all_probs)} models, "
                f"mean={ensemble.mean():.4f}, max={ensemble.max():.4f}")
    return ensemble


def screen_hub():
    """Screen Hub with all 7 task ensembles, compute selectivity."""
    logger.info("\n" + "=" * 70)
    logger.info("  HUB SCREENING (Ensemble of 5 fold models)")
    logger.info("=" * 70)

    hub_csv = os.path.join(DMPNN_INPUT_DIR, 'hub_screen.csv')
    hub_df = pd.read_csv(hub_csv)

    # Load Hub metadata
    hub_meta_path = os.path.join(config.HUB_DIR,
                                 config.HUB_CLEAN_FILENAME)
    hub_meta = pd.read_csv(hub_meta_path)
    metadata_cols = ['smiles', 'name', 'clinical_phase', 'moa',
                     'disease_area', 'target']
    meta = hub_meta[[c for c in metadata_cols
                     if c in hub_meta.columns]].copy()

    # Predict pathogen and gut probabilities
    pathogen_probs = {}
    for task in PATHOGEN_TASKS:
        probs = ensemble_predict_task(task)
        if probs is not None:
            pathogen_probs[task] = probs

    gut_probs = {}
    for task in GUT_TASKS:
        probs = ensemble_predict_task(task)
        if probs is not None:
            gut_probs[task] = probs

    if not pathogen_probs or not gut_probs:
        logger.error("  Missing predictions, cannot compute selectivity")
        return {}

    # Compute selectivity and save ranked lists
    ranked_lists = {}
    for pathogen_key, p_path in pathogen_probs.items():
        for gut_key, p_gut in gut_probs.items():
            threshold = gut_key.replace('gut_t', '')
            combo_key = f'{pathogen_key}_t{threshold}'

            selectivity = p_path * (1 - p_gut)

            df_ranked = meta.copy()
            df_ranked['p_pathogen'] = p_path
            df_ranked['p_gut'] = p_gut
            df_ranked['selectivity_score'] = selectivity
            df_ranked = df_ranked.sort_values('selectivity_score',
                                             ascending=False)
            df_ranked['rank'] = range(1, len(df_ranked) + 1)

            out_path = os.path.join(
                config.SCREENING_DIR,
                f'{PIPELINE_NAME}_ranked_{combo_key}.csv')
            df_ranked.to_csv(out_path, index=False)
            ranked_lists[combo_key] = df_ranked

            logger.info(f"  {combo_key:25s}: median S={selectivity.mean():.4f}, "
                        f"n>0.5={int((selectivity > 0.5).sum())}")

    logger.info(f"\n  Saved {len(ranked_lists)} screening CSVs")
    return ranked_lists


# ===================================================================
# Validation
# ===================================================================

def validate(ranked_lists):
    """Narrow vs broad drug validation + enrichment."""
    from scipy.stats import mannwhitneyu

    logger.info("\n" + "=" * 70)
    logger.info("  VALIDATION")
    logger.info("=" * 70)

    NARROW = {
        'lolamicin': 'Gram-neg selective, microbiome-sparing',
        'daptomycin': 'Gram-pos only lipopeptide',
        'fidaxomicin': 'Very narrow, anti-C. difficile only',
        'nitrofurantoin': 'Narrow (urinary tract)',
        'methenamine': 'Narrow (urinary antiseptic)',
    }
    BROAD = {
        'ciprofloxacin': 'Broad fluoroquinolone',
        'amoxicillin': 'Broad beta-lactam',
        'clindamycin': 'High C. difficile risk',
        'rifabutin': 'Kills nearly all commensals',
        'doxycycline': 'Broad tetracycline',
        'chloramphenicol': 'Broad',
    }
    ANTIBIOTIC_MOA_KEYWORDS = [
        'antibiotic', 'antibacterial', 'antimicrobial', 'beta-lactamase',
        'penicillin', 'cephalosporin', 'fluoroquinolone', 'aminoglycoside',
        'tetracycline', 'macrolide', 'sulfonamide', 'glycopeptide',
        'carbapenem', 'oxazolidinone', 'lincosamide', 'polymyxin',
        'rifamycin', 'nitroimidazole', 'bacterial', 'bactericidal',
    ]

    results = {'narrow_vs_broad': {}, 'enrichment': {}}

    for combo_key, df in ranked_lists.items():
        if '_t10' not in combo_key:
            continue

        df_lower = df.copy()
        df_lower['name_lower'] = df_lower['name'].str.lower().str.strip()

        narrow_s = []
        for drug in NARROW:
            match = df_lower[df_lower['name_lower'].str.contains(
                drug, na=False)]
            if len(match) > 0:
                narrow_s.append(match.iloc[0]['selectivity_score'])

        broad_s = []
        for drug in BROAD:
            match = df_lower[df_lower['name_lower'].str.contains(
                drug, na=False)]
            if len(match) > 0:
                broad_s.append(match.iloc[0]['selectivity_score'])

        if narrow_s and broad_s:
            narrow_mean = np.mean(narrow_s)
            broad_mean = np.mean(broad_s)
            try:
                stat, p = mannwhitneyu(narrow_s, broad_s,
                                       alternative='greater')
                direction = 'CORRECT' if narrow_mean > broad_mean else 'WRONG'
            except ValueError:
                p = 1.0
                direction = 'N/A'

            results['narrow_vs_broad'][combo_key] = {
                'narrow_mean': round(float(narrow_mean), 4),
                'broad_mean': round(float(broad_mean), 4),
                'p_value': float(p),
                'direction': direction,
            }
            logger.info(f"  {combo_key:25s}: narrow={narrow_mean:.4f} "
                        f"broad={broad_mean:.4f} "
                        f"p={p:.4f} {direction}")

        # Enrichment: antibiotics in top-50
        top50 = df.head(50)
        n_ab = sum(1 for _, r in top50.iterrows()
                   if any(kw in str(r.get('moa', '')).lower()
                          for kw in ANTIBIOTIC_MOA_KEYWORDS))
        total_ab = sum(1 for _, r in df.iterrows()
                       if any(kw in str(r.get('moa', '')).lower()
                              for kw in ANTIBIOTIC_MOA_KEYWORDS))
        expected = 50 * total_ab / len(df) if len(df) > 0 else 0
        enrichment = n_ab / expected if expected > 0 else 0

        results['enrichment'][combo_key] = {
            'n_antibiotics_top50': n_ab,
            'total_antibiotics': total_ab,
            'expected': round(float(expected), 2),
            'enrichment_ratio': round(float(enrichment), 2),
        }
        logger.info(f"  {combo_key:25s}: {n_ab}/50 antibiotics "
                    f"({enrichment:.2f}x enrichment)")

    return results


# ===================================================================
# Score distribution analysis
# ===================================================================

def analyze_calibration(ranked_lists):
    """Compare score distributions with old D-MPNN."""
    logger.info("\n" + "=" * 70)
    logger.info("  CALIBRATION: New vs Old D-MPNN")
    logger.info("=" * 70)

    results = {}

    for combo_key, df_new in ranked_lists.items():
        if '_t10' not in combo_key:
            continue

        s = df_new['selectivity_score']
        near_zero = int((s < 0.01).sum())
        mid_range = int(((s > 0.2) & (s < 0.8)).sum())
        near_one = int((s > 0.95).sum())

        results[combo_key] = {
            'new': {
                'S_lt_0.01': near_zero,
                'S_0.2_to_0.8': mid_range,
                'S_gt_0.95': near_one,
                'median': round(float(s.median()), 4),
                'n_above_0.5': int((s > 0.5).sum()),
            }
        }

        # Load old D-MPNN for comparison
        old_path = os.path.join(config.SCREENING_DIR,
                                f'dmpnn_ranked_{combo_key}.csv')
        if os.path.exists(old_path):
            df_old = pd.read_csv(old_path)
            s_old = df_old['selectivity_score']
            results[combo_key]['old'] = {
                'S_lt_0.01': int((s_old < 0.01).sum()),
                'S_0.2_to_0.8': int(((s_old > 0.2) & (s_old < 0.8)).sum()),
                'S_gt_0.95': int((s_old > 0.95).sum()),
                'median': round(float(s_old.median()), 4),
                'n_above_0.5': int((s_old > 0.5).sum()),
            }

            logger.info(f"\n  {combo_key}:")
            logger.info(f"    {'Metric':20s} {'Old D-MPNN':>12} "
                        f"{'New D-MPNN+RDKit':>18}")
            logger.info(f"    {'-'*55}")
            for metric in ['S_lt_0.01', 'S_0.2_to_0.8', 'S_gt_0.95',
                           'median', 'n_above_0.5']:
                old_v = results[combo_key]['old'][metric]
                new_v = results[combo_key]['new'][metric]
                logger.info(f"    {metric:20s} {str(old_v):>12} "
                            f"{str(new_v):>18}")

    return results


# ===================================================================
# Head-to-head comparison with old D-MPNN
# ===================================================================

def compare_with_old():
    """Side-by-side comparison of old vs new D-MPNN."""
    logger.info("\n" + "=" * 70)
    logger.info("  HEAD-TO-HEAD: Old D-MPNN vs New D-MPNN+RDKit")
    logger.info("=" * 70)

    # Load old metrics
    old_metrics_path = os.path.join(config.RESULTS_DIR,
                                    'dmpnn_cv_metrics.json')
    new_metrics_path = os.path.join(config.RESULTS_DIR,
                                    f'{PIPELINE_NAME}_cv_metrics.json')

    results = {'cv_comparison': {}}

    if os.path.exists(old_metrics_path) and os.path.exists(new_metrics_path):
        with open(old_metrics_path) as f:
            old_all = json.load(f)
        with open(new_metrics_path) as f:
            new_all = json.load(f)

        logger.info(f"\n  {'Task':20s} {'Old ROC-AUC':>12} "
                    f"{'New ROC-AUC':>12} {'Change':>10}")
        logger.info(f"  {'-'*58}")

        for task in ALL_TASKS:
            old_roc = None
            if task in old_all:
                if isinstance(old_all[task], dict):
                    old_roc = old_all[task].get('mean_roc_auc',
                              old_all[task].get('roc_auc'))

            new_roc = None
            if task in new_all:
                new_roc = new_all[task].get('mean_roc_auc',
                          new_all[task].get('roc_auc'))

            if old_roc is not None and new_roc is not None:
                change = new_roc - old_roc
                marker = '+' if change > 0 else ''
                logger.info(f"  {task:20s} {old_roc:>12.4f} "
                            f"{new_roc:>12.4f} {marker}{change:>9.4f}")
                results['cv_comparison'][task] = {
                    'old_roc_auc': old_roc,
                    'new_roc_auc': new_roc,
                    'change': round(change, 4),
                }

    # Compare top candidates
    logger.info("\n  Top 10 candidates comparison (ecoli_t10):")
    old_path = os.path.join(config.SCREENING_DIR,
                            'dmpnn_ranked_ecoli_t10.csv')
    new_path = os.path.join(config.SCREENING_DIR,
                            f'{PIPELINE_NAME}_ranked_ecoli_t10.csv')

    if os.path.exists(old_path) and os.path.exists(new_path):
        df_old = pd.read_csv(old_path)
        df_new = pd.read_csv(new_path)

        logger.info(f"\n  Old D-MPNN top 10:")
        for _, r in df_old.head(10).iterrows():
            logger.info(f"    {str(r['name']):25s} S={r['selectivity_score']:.4f}")

        logger.info(f"\n  New D-MPNN+RDKit top 10:")
        for _, r in df_new.head(10).iterrows():
            logger.info(f"    {str(r['name']):25s} S={r['selectivity_score']:.4f}")

        results['old_top10'] = df_old.head(10)['name'].tolist()
        results['new_top10'] = df_new.head(10)['name'].tolist()
        results['overlap_top50'] = len(
            set(df_old.head(50)['smiles']) &
            set(df_new.head(50)['smiles']))

        logger.info(f"\n  Top-50 overlap: "
                    f"{results['overlap_top50']}/50 compounds shared")

    return results


# ===================================================================
# Stokes correlation
# ===================================================================

def stokes_correlation(ranked_lists):
    """Compare new D-MPNN scores with Stokes published predictions."""
    from scipy.stats import spearmanr

    logger.info("\n" + "=" * 70)
    logger.info("  STOKES CORRELATION")
    logger.info("=" * 70)

    stokes_path = os.path.join(config.RESULTS_DIR,
                               'external_stokes_comparison.csv')
    if not os.path.exists(stokes_path):
        logger.info("  external_stokes_comparison.csv not found, skipping")
        return {}

    stokes = pd.read_csv(stokes_path)
    results = {}

    for combo_key, df_new in ranked_lists.items():
        if '_t10' not in combo_key:
            continue

        # Merge by SMILES
        merged = df_new[['smiles', 'selectivity_score']].merge(
            stokes[['smiles', 'stokes_dmpnn_score']].dropna(),
            on='smiles', how='inner')

        if len(merged) < 50:
            continue

        rho, p = spearmanr(merged['selectivity_score'],
                           merged['stokes_dmpnn_score'])

        # Also get old D-MPNN correlation for comparison
        old_rho = None
        old_path = os.path.join(config.SCREENING_DIR,
                                f'dmpnn_ranked_{combo_key}.csv')
        if os.path.exists(old_path):
            df_old = pd.read_csv(old_path)
            merged_old = df_old[['smiles', 'selectivity_score']].merge(
                stokes[['smiles', 'stokes_dmpnn_score']].dropna(),
                on='smiles', how='inner')
            if len(merged_old) > 50:
                old_rho, _ = spearmanr(
                    merged_old['selectivity_score'],
                    merged_old['stokes_dmpnn_score'])

        results[combo_key] = {
            'new_rho': round(float(rho), 4),
            'old_rho': round(float(old_rho), 4) if old_rho else None,
            'n_matched': len(merged),
        }

        old_str = f"{old_rho:.4f}" if old_rho else "N/A"
        logger.info(f"  {combo_key:25s}: new rho={rho:.4f}, "
                    f"old rho={old_str}, n={len(merged)}")

    return results


# ===================================================================
# Figures
# ===================================================================

def generate_figures(ranked_lists, calibration):
    """Generate comparison figures."""
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt

    os.makedirs(config.FIGURES_DIR, exist_ok=True)
    DPI = 300
    plt.rcParams.update({
        'font.family': 'serif', 'font.size': 10,
        'figure.dpi': DPI, 'savefig.dpi': DPI,
        'axes.spines.top': False, 'axes.spines.right': False,
    })

    # Figure 1: Score distribution comparison
    fig, axes = plt.subplots(1, 2, figsize=(12, 5))

    for combo_key in ['ecoli_t10']:
        new_path = os.path.join(config.SCREENING_DIR,
                                f'{PIPELINE_NAME}_ranked_{combo_key}.csv')
        old_path = os.path.join(config.SCREENING_DIR,
                                f'dmpnn_ranked_{combo_key}.csv')

        if os.path.exists(new_path):
            df_new = pd.read_csv(new_path)
            axes[0].hist(df_new['selectivity_score'], bins=100,
                         alpha=0.7, color='#009E73',
                         label='D-MPNN+RDKit (new)', edgecolor='none')
            axes[0].set_title('New D-MPNN+RDKit')
            axes[0].set_xlabel('Selectivity Score S')
            axes[0].set_ylabel('Count')
            axes[0].set_yscale('log')

        if os.path.exists(old_path):
            df_old = pd.read_csv(old_path)
            axes[1].hist(df_old['selectivity_score'], bins=100,
                         alpha=0.7, color='#D55E00',
                         label='D-MPNN (old)', edgecolor='none')
            axes[1].set_title('Old D-MPNN (no RDKit)')
            axes[1].set_xlabel('Selectivity Score S')
            axes[1].set_yscale('log')

    plt.suptitle('Score Distribution: Old vs New D-MPNN (E. coli, t=10)')
    plt.tight_layout()
    path = os.path.join(config.FIGURES_DIR,
                        f'{PIPELINE_NAME}_score_comparison')
    fig.savefig(path + '.png', dpi=DPI, bbox_inches='tight')
    fig.savefig(path + '.pdf', bbox_inches='tight')
    plt.close(fig)
    logger.info(f"  Figure: {PIPELINE_NAME}_score_comparison")

    # Figure 2: Old vs New scatter
    fig, ax = plt.subplots(figsize=(8, 8))
    old_path = os.path.join(config.SCREENING_DIR,
                            'dmpnn_ranked_ecoli_t10.csv')
    new_path = os.path.join(config.SCREENING_DIR,
                            f'{PIPELINE_NAME}_ranked_ecoli_t10.csv')

    if os.path.exists(old_path) and os.path.exists(new_path):
        df_old = pd.read_csv(old_path)[['smiles', 'selectivity_score']]
        df_new = pd.read_csv(new_path)[['smiles', 'selectivity_score']]
        df_old = df_old.rename(columns={'selectivity_score': 'old_S'})
        df_new = df_new.rename(columns={'selectivity_score': 'new_S'})
        merged = df_old.merge(df_new, on='smiles')

        ax.scatter(merged['old_S'], merged['new_S'],
                   s=3, alpha=0.4, c='#333333', edgecolors='none')
        ax.plot([0, 1], [0, 1], 'r--', alpha=0.3)
        ax.set_xlabel('Old D-MPNN Selectivity S')
        ax.set_ylabel('New D-MPNN+RDKit Selectivity S')
        ax.set_title('Old vs New D-MPNN (E. coli, t=10)')

        from scipy.stats import spearmanr
        rho, _ = spearmanr(merged['old_S'], merged['new_S'])
        ax.text(0.05, 0.95, f'rho={rho:.3f}', transform=ax.transAxes,
                fontsize=12, va='top')

    plt.tight_layout()
    path = os.path.join(config.FIGURES_DIR,
                        f'{PIPELINE_NAME}_old_vs_new_scatter')
    fig.savefig(path + '.png', dpi=DPI, bbox_inches='tight')
    fig.savefig(path + '.pdf', bbox_inches='tight')
    plt.close(fig)
    logger.info(f"  Figure: {PIPELINE_NAME}_old_vs_new_scatter")


# ===================================================================
# Main
# ===================================================================

def main():
    t_start = log_phase_start(logger,
                              "Phase D: Retrain D-MPNN with RDKit features")

    os.makedirs(DMPNN_RDKIT_DIR, exist_ok=True)
    os.makedirs(config.SCREENING_DIR, exist_ok=True)
    os.makedirs(config.RESULTS_DIR, exist_ok=True)
    os.makedirs(config.FIGURES_DIR, exist_ok=True)

    # --- Training ---
    logger.info("\n  PHASE 1/7: TRAINING")
    fold_results, final_results = train_all_models()

    # --- CV Metrics ---
    logger.info("\n  PHASE 2/7: CV METRICS")
    cv_metrics = {}
    try:
        cv_metrics = collect_cv_metrics()
    except Exception as e:
        logger.error(f"  CV metrics FAILED: {type(e).__name__}: {e}")
        import traceback; logger.error(traceback.format_exc())

    # --- Hub Screening (Ensemble) ---
    logger.info("\n  PHASE 3/7: HUB SCREENING")
    ranked_lists = {}
    try:
        ranked_lists = screen_hub()
    except Exception as e:
        logger.error(f"  Hub screening FAILED: {type(e).__name__}: {e}")
        import traceback; logger.error(traceback.format_exc())

    if not ranked_lists:
        logger.error("  No ranked lists produced. Cannot run validation, "
                     "calibration, or comparison.")
        logger.error("  Check training logs in "
                     f"{DMPNN_RDKIT_DIR}/train_*.log")
        log_phase_end(logger, "Phase D: D-MPNN + RDKit (INCOMPLETE)", t_start)
        return

    # Save intermediate checkpoint
    intermediate = {
        'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
        'cv_metrics': cv_metrics,
        'n_ranked_lists': len(ranked_lists),
        'ranked_list_keys': list(ranked_lists.keys()),
    }
    ckpt_path = os.path.join(config.RESULTS_DIR,
                             f'{PIPELINE_NAME}_checkpoint.json')
    with open(ckpt_path, 'w') as f:
        json.dump(intermediate, f, indent=2, default=str)
    logger.info(f"  Checkpoint saved: {ckpt_path}")

    # --- Validation ---
    logger.info("\n  PHASE 4/7: VALIDATION")
    validation = {'narrow_vs_broad': {}, 'enrichment': {}}
    try:
        validation = validate(ranked_lists)
    except Exception as e:
        logger.error(f"  Validation FAILED: {type(e).__name__}: {e}")
        import traceback; logger.error(traceback.format_exc())

    # --- Calibration ---
    logger.info("\n  PHASE 5/7: CALIBRATION COMPARISON")
    calibration = {}
    try:
        calibration = analyze_calibration(ranked_lists)
    except Exception as e:
        logger.error(f"  Calibration FAILED: {type(e).__name__}: {e}")
        import traceback; logger.error(traceback.format_exc())

    # --- Head-to-head comparison ---
    logger.info("\n  PHASE 6/7: HEAD-TO-HEAD COMPARISON")
    comparison = {}
    try:
        comparison = compare_with_old()
    except Exception as e:
        logger.error(f"  Comparison FAILED: {type(e).__name__}: {e}")
        import traceback; logger.error(traceback.format_exc())

    # --- Stokes correlation ---
    stokes = {}
    try:
        stokes = stokes_correlation(ranked_lists)
    except Exception as e:
        logger.error(f"  Stokes correlation FAILED: {type(e).__name__}: {e}")
        import traceback; logger.error(traceback.format_exc())

    # --- Figures ---
    logger.info("\n  PHASE 7/7: FIGURES")
    try:
        generate_figures(ranked_lists, calibration)
    except Exception as e:
        logger.error(f"  Figure generation FAILED: {type(e).__name__}: {e}")
        import traceback; logger.error(traceback.format_exc())

    # --- Summary report ---
    report = {
        'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
        'architecture': DMPNN_RDKIT_PARAMS,
        'features': 'v1_rdkit_2d_normalized',
        'screening_method': 'ensemble of 5 fold models',
        'cv_metrics': cv_metrics,
        'validation': validation,
        'calibration': calibration,
        'comparison_with_old': {
            k: v for k, v in comparison.items()
            if not isinstance(v, pd.DataFrame)
        },
        'stokes_correlation': stokes,
    }

    report_path = os.path.join(config.RESULTS_DIR,
                               f'{PIPELINE_NAME}_full_report.json')
    with open(report_path, 'w') as f:
        json.dump(report, f, indent=2, default=str)
    logger.info(f"\n  Saved: {report_path}")

    # --- Print summary ---
    logger.info("\n" + "=" * 70)
    logger.info("  D-MPNN + RDKit RETRAINING SUMMARY")
    logger.info("=" * 70)
    logger.info(f"  Architecture: depth={DMPNN_RDKIT_PARAMS['depth']}, "
                f"hidden={DMPNN_RDKIT_PARAMS['hidden_dim']}, "
                f"dropout={DMPNN_RDKIT_PARAMS['dropout']}")
    logger.info(f"  Features: v1_rdkit_2d_normalized (200 descriptors)")
    logger.info(f"  Screening: ensemble of 5 fold models")
    if cv_metrics:
        for task in PATHOGEN_TASKS:
            if task in cv_metrics:
                logger.info(f"  {task:20s}: ROC-AUC = "
                            f"{cv_metrics[task]['mean_roc_auc']:.4f} "
                            f"+/- {cv_metrics[task]['std_roc_auc']:.4f}")
    if validation.get('narrow_vs_broad'):
        for k, v in validation['narrow_vs_broad'].items():
            logger.info(f"  Validation {k}: {v['direction']} "
                        f"(narrow={v['narrow_mean']:.4f}, "
                        f"broad={v['broad_mean']:.4f})")
    if validation.get('enrichment'):
        for k, v in validation['enrichment'].items():
            logger.info(f"  Enrichment {k}: "
                        f"{v['n_antibiotics_top50']}/50 "
                        f"({v['enrichment_ratio']:.2f}x)")
    logger.info("=" * 70)

    log_phase_end(logger, "Phase D: D-MPNN + RDKit", t_start)


if __name__ == '__main__':
    main()