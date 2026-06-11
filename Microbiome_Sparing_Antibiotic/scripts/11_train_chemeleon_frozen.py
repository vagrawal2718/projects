"""
11_train_chemeleon_frozen.py -- CheMeleon with Frozen Encoder

Loads the CheMeleon pretrained MPNN (6-layer, 2048-dim), FREEZES it,
and trains ONLY a fresh binary classification FFN head on top.

This is the standard transfer learning approach for foundation models:
  - Encoder (MPNN): pretrained on 1M molecules, FROZEN during fine-tuning
  - Head (FFN): randomly initialized, trained on our 2-5K compounds

Advantages over full fine-tuning (09_train_chemeleon.py):
  - Cannot overfit the encoder (it's frozen)
  - Only ~10K trainable parameters (vs 10M), so very fast
  - Can use more epochs and higher LR safely
  - Better generalization on small datasets

Uses chemprop Python API because the CLI --checkpoint + --freeze-encoder
path requires matching FFN architecture, but CheMeleon was pretrained for
Mordred descriptor regression, not binary classification.

CheMeleon weights: https://zenodo.org/records/15460715/files/chemeleon_mp.pt
Cached at: ~/.chemprop/chemeleon_mp.pt (auto-downloaded on first use)

Output:
  models/chemeleon_frozen/  (model checkpoints per task per fold)
  results/chemeleon_frozen_cv_metrics.json
  results/screening/chemeleon_frozen_ranked_*.csv

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import os, sys, json, time, warnings, glob
import numpy as np
import pandas as pd
from pathlib import Path

warnings.filterwarnings('ignore')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import config
from utils.logging_utils import setup_logging, log_phase_start, log_phase_end
from utils.scaffold_split import load_folds, get_train_test_indices
from utils.full_metrics import compute_full_metrics, aggregate_fold_metrics

logger = setup_logging('phase3c_frozen', log_dir=config.LOGS_DIR)

FROZEN_DIR = os.path.join(config.MODELS_DIR, 'chemeleon_frozen')
CHEMELEON_MP_URL = "https://zenodo.org/records/15460715/files/chemeleon_mp.pt"


def ensure_chemeleon_weights():
    """Download CheMeleon MPNN weights if not cached."""
    ckpt_dir = Path.home() / ".chemprop"
    ckpt_dir.mkdir(exist_ok=True)
    mp_path = ckpt_dir / "chemeleon_mp.pt"

    if mp_path.exists() and mp_path.stat().st_size > 1_000_000:
        logger.info(f"  CheMeleon weights cached: {mp_path} ({mp_path.stat().st_size / 1e6:.1f} MB)")
        return str(mp_path)

    logger.info(f"  Downloading CheMeleon weights from Zenodo...")
    try:
        from urllib.request import urlretrieve
        urlretrieve(CHEMELEON_MP_URL, str(mp_path))
        logger.info(f"  Downloaded: {mp_path} ({mp_path.stat().st_size / 1e6:.1f} MB)")
        return str(mp_path)
    except Exception as e:
        logger.error(f"  Download failed: {e}")
        # Fallback: check if --from-foundation already cached it
        alt = ckpt_dir / "CheMeleon.pt"
        if alt.exists():
            return str(alt)
        return None


def _build_frozen_model(mp_path):
    """
    Build a CheMeleon frozen encoder model (shared by fold training,
    final training, and hub prediction).

    Returns (model, gpu_flag).
    """
    import torch
    from chemprop import data, featurizers, models, nn

    mp_weights = torch.load(mp_path, map_location='cpu', weights_only=False)
    mp = nn.BondMessagePassing(d_h=2048, depth=6)
    mp.load_state_dict(mp_weights, strict=False)

    for param in mp.parameters():
        param.requires_grad = False

    agg = nn.MeanAggregation()
    ffn = nn.BinaryClassificationFFN(input_dim=mp.output_dim)

    model = models.MPNN(
        message_passing=mp,
        agg=agg,
        predictor=ffn,
        batch_norm=True,
        warmup_epochs=0,
        init_lr=1e-3,
        max_lr=1e-3,
        final_lr=1e-4,
    )

    gpu = torch.cuda.is_available()
    return model, gpu


def train_frozen_fold(mp_path, train_smiles, train_labels, val_smiles, val_labels,
                      save_dir, gpu=False):
    """Train one fold with frozen CheMeleon encoder + fresh classification head."""
    import torch
    from chemprop import data, featurizers, models, nn

    # Build datasets
    train_dps = [data.MoleculeDatapoint.from_smi(smi, [y])
                 for smi, y in zip(train_smiles, train_labels)]
    val_dps = [data.MoleculeDatapoint.from_smi(smi, [y])
               for smi, y in zip(val_smiles, val_labels)]

    train_ds = data.MoleculeDataset(train_dps)
    val_ds = data.MoleculeDataset(val_dps)

    train_loader = data.build_dataloader(train_ds, batch_size=64, shuffle=True, num_workers=0)
    val_loader = data.build_dataloader(val_ds, batch_size=64, shuffle=False, num_workers=0)

    # Load pretrained MPNN weights
    mp_weights = torch.load(mp_path, map_location='cpu', weights_only=False)

    # Build message passing with CheMeleon architecture
    # CheMeleon: 6 layers, 2048 hidden dim, V2 multi-hot atom featurizer
    mp = nn.BondMessagePassing(d_h=2048, depth=6)
    mp.load_state_dict(mp_weights, strict=False)

    # FREEZE encoder: no gradients flow through MPNN
    for param in mp.parameters():
        param.requires_grad = False

    # Fresh classification head (only trainable part)
    agg = nn.MeanAggregation()
    ffn = nn.BinaryClassificationFFN(input_dim=mp.output_dim)

    # Assemble model
    model = models.MPNN(
        message_passing=mp,
        agg=agg,
        predictor=ffn,
        batch_norm=True,
        warmup_epochs=0,  # no warmup needed for small FFN
        init_lr=1e-3,
        max_lr=1e-3,
        final_lr=1e-4,
    )

    # --- FOLD SKIP: if model.pt exists, load and predict only ---
    model_path = os.path.join(save_dir, 'model.pt')
    if os.path.exists(model_path):
        logger.info(f"    SKIP training (loading saved {model_path})")
        state = torch.load(model_path, map_location='cpu', weights_only=False)
        model.load_state_dict(state)
        if gpu and torch.cuda.is_available():
            model = model.cuda()
        model.eval()
        from lightning import pytorch as pl
        trainer = pl.Trainer(
            logger=False, enable_checkpointing=False, enable_progress_bar=False,
            accelerator='gpu' if gpu else 'cpu', devices=1,
        )
        preds_list = trainer.predict(model, val_loader)
        preds = torch.cat(preds_list, dim=0).squeeze(-1).numpy()
        return preds

    # Count parameters
    total_params = sum(p.numel() for p in model.parameters())
    trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
    frozen_count = total_params - trainable
    logger.info(f"    Parameters: {trainable:,} trainable, {frozen_count:,} frozen, {total_params:,} total")

    # Train with Lightning
    from lightning import pytorch as pl

    class EpochLogger(pl.Callback):
        """Log validation loss after each epoch for progress visibility."""
        def on_train_epoch_end(self, trainer, pl_module):
            epoch = trainer.current_epoch
            metrics = trainer.callback_metrics
            val_loss = metrics.get('val_loss', None)
            train_loss = metrics.get('train_loss', None)
            parts = [f"Epoch {epoch+1}/{trainer.max_epochs}"]
            if train_loss is not None:
                parts.append(f"train_loss={float(train_loss):.4f}")
            if val_loss is not None:
                parts.append(f"val_loss={float(val_loss):.4f}")
            print(f"      {', '.join(parts)}", flush=True)

    os.makedirs(save_dir, exist_ok=True)
    trainer = pl.Trainer(
        logger=False,
        enable_checkpointing=True,
        enable_progress_bar=True,
        accelerator='gpu' if gpu else 'cpu',
        devices=1,
        max_epochs=10,  # Safe with frozen encoder: only FFN trains
        default_root_dir=save_dir,
        callbacks=[EpochLogger()],
    )

    trainer.fit(model, train_loader, val_loader)

    # Get validation predictions
    model.eval()
    preds_list = trainer.predict(model, val_loader)
    preds = torch.cat(preds_list, dim=0).squeeze(-1).numpy()

    # Save model
    torch.save(model.state_dict(), model_path)

    return preds


def compute_fold_metrics(y_true, y_pred):
    """Compute classification metrics for one fold using the shared full_metrics module."""
    return compute_full_metrics(y_true, y_pred)


def _json_safe(obj):
    """Convert numpy types to Python types for JSON serialization."""
    if isinstance(obj, (np.integer,)):
        return int(obj)
    if isinstance(obj, (np.floating,)):
        return float(obj)
    if isinstance(obj, np.ndarray):
        return obj.tolist()
    return str(obj)


# ===========================================================================
# NEW: Final model training + hub screening
# ===========================================================================

def train_final_chemeleon(mp_path, smiles_list, labels_list, save_dir, gpu=False):
    """
    Train a CheMeleon frozen encoder model on ALL data (no validation)
    for final hub screening. Saves state dict to save_dir/final_model.pt.
    """
    import torch
    from chemprop import data, models
    from lightning import pytorch as pl

    final_path = os.path.join(save_dir, 'final_model.pt')

    # Smart-skip
    if os.path.exists(final_path):
        logger.info(f"    Final model: SKIP (exists: {final_path})")
        return final_path

    logger.info(f"    Training final model on {len(smiles_list)} compounds...")
    os.makedirs(save_dir, exist_ok=True)

    model, _ = _build_frozen_model(mp_path)

    train_dps = [data.MoleculeDatapoint.from_smi(smi, [y])
                 for smi, y in zip(smiles_list, labels_list)]
    train_ds = data.MoleculeDataset(train_dps)
    train_loader = data.build_dataloader(train_ds, batch_size=64,
                                         shuffle=True, num_workers=0)

    trainer = pl.Trainer(
        logger=False,
        enable_checkpointing=False,
        enable_progress_bar=True,
        accelerator='gpu' if gpu else 'cpu',
        devices=1,
        max_epochs=10,
    )

    trainer.fit(model, train_loader)
    torch.save(model.state_dict(), final_path)
    logger.info(f"    Saved final model: {final_path}")
    return final_path


def predict_chemeleon(mp_path, model_state_path, smiles_list, gpu=False):
    """
    Load a saved CheMeleon model and predict probabilities for a list
    of SMILES. Returns numpy array of probabilities.
    """
    import torch
    from chemprop import data
    from lightning import pytorch as pl

    model, _ = _build_frozen_model(mp_path)
    state = torch.load(model_state_path, map_location='cpu',
                       weights_only=False)
    model.load_state_dict(state)
    if gpu and torch.cuda.is_available():
        model = model.cuda()
    model.eval()

    # Build dataloader (dummy labels, only SMILES matter for prediction)
    dps = [data.MoleculeDatapoint.from_smi(smi, [0])
           for smi in smiles_list]
    ds = data.MoleculeDataset(dps)
    loader = data.build_dataloader(ds, batch_size=64, shuffle=False,
                                   num_workers=0)

    trainer = pl.Trainer(
        logger=False, enable_checkpointing=False,
        enable_progress_bar=False,
        accelerator='gpu' if gpu else 'cpu', devices=1,
    )
    preds_list = trainer.predict(model, loader)
    probs = torch.cat(preds_list, dim=0).squeeze(-1).numpy()
    return probs


def screen_hub_chemeleon(mp_path, gpu=False):
    """
    Screen the Drug Repurposing Hub with all 7 CheMeleon final models.
    Produces 7 raw prob CSVs and 12 selectivity-ranked CSVs.

    Returns dict of ranked DataFrames keyed by 'pathogen_tN'.
    """
    hub_csv = os.path.join(config.HUB_DIR, config.HUB_CLEAN_FILENAME)
    if not os.path.exists(hub_csv):
        logger.warning(f"    Hub CSV not found: {hub_csv}")
        return {}

    df_hub = pd.read_csv(hub_csv)
    hub_smiles = df_hub['smiles'].values.tolist()
    metadata_cols = ['smiles', 'name', 'clinical_phase', 'moa',
                     'disease_area', 'target']

    os.makedirs(config.SCREENING_DIR, exist_ok=True)

    pathogen_keys = list(config.PATHOGENS.keys())
    gut_keys = [f'gut_t{t}' for t in config.HARM_THRESHOLDS]
    all_task_keys = pathogen_keys + gut_keys

    # --- Step 1: Predict raw probabilities for each task ---
    logger.info("\n  Screening hub with CheMeleon frozen models...")
    task_probs = {}

    for task_key in all_task_keys:
        raw_csv = os.path.join(config.SCREENING_DIR,
                               f'chemeleon_frozen_ranked_{task_key}.csv')

        # Smart-skip: if raw prob CSV exists, load it
        if os.path.exists(raw_csv):
            logger.info(f"    {task_key}: SKIP raw probs (exists)")
            df_raw = pd.read_csv(raw_csv)
            task_probs[task_key] = df_raw['prob'].values
            continue

        final_dir = os.path.join(FROZEN_DIR, task_key)
        final_model_path = os.path.join(final_dir, 'final_model.pt')

        if not os.path.exists(final_model_path):
            logger.warning(f"    {task_key}: no final model at "
                           f"{final_model_path}")
            continue

        logger.info(f"    {task_key}: predicting on {len(hub_smiles)} "
                    f"compounds...")
        probs = predict_chemeleon(mp_path, final_model_path, hub_smiles,
                                 gpu=gpu)
        task_probs[task_key] = probs

        # Save raw prob CSV (same format as MoLFormer raw files)
        df_raw = df_hub.copy()
        df_raw['prob'] = probs
        df_raw = df_raw.sort_values('prob', ascending=False)
        df_raw.to_csv(raw_csv, index=False)
        logger.info(f"    Saved: {os.path.basename(raw_csv)} "
                    f"(top prob={probs.max():.4f})")

    # --- Step 2: Compute selectivity scores (4 x 3 = 12 CSVs) ---
    logger.info("\n  Computing CheMeleon selectivity scores...")
    ranked_lists = {}

    for pk in pathogen_keys:
        if pk not in task_probs:
            continue

        for gt in config.HARM_THRESHOLDS:
            gut_key = f'gut_t{gt}'
            if gut_key not in task_probs:
                continue

            out_name = f'chemeleon_frozen_ranked_{pk}_t{gt}.csv'
            out_path = os.path.join(config.SCREENING_DIR, out_name)

            # Smart-skip
            if os.path.exists(out_path):
                logger.info(f"    SKIP (exists): {out_name}")
                try:
                    ranked_lists[f'{pk}_t{gt}'] = pd.read_csv(out_path)
                except Exception:
                    pass
                continue

            p_path = task_probs[pk]
            p_gut = task_probs[gut_key]
            S = p_path * (1.0 - p_gut)

            ranked_df = df_hub[metadata_cols].copy()
            ranked_df['p_pathogen'] = np.round(p_path, 6)
            ranked_df['p_gut'] = np.round(p_gut, 6)
            ranked_df['selectivity_score'] = np.round(S, 6)
            ranked_df = ranked_df.sort_values(
                'selectivity_score', ascending=False
            ).reset_index(drop=True)
            ranked_df['rank'] = range(1, len(ranked_df) + 1)

            ranked_df.to_csv(out_path, index=False)
            ranked_lists[f'{pk}_t{gt}'] = ranked_df
            logger.info(f"    Saved: {out_name} "
                        f"({len(ranked_df)} compounds, "
                        f"top S={S.max():.4f})")

    return ranked_lists


# ===========================================================================
# NEW: Publication-quality figures for Phase 3C
# ===========================================================================

def generate_phase3c_figures(all_cv_results, ranked_lists):
    """
    Generate publication-quality figures for CheMeleon Frozen (Phase 3C).
    Matches D-MPNN Phase 3B figure style.
    """
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import seaborn as sns
    from utils.viz_utils import setup_publication_style, save_figure, COLORS

    os.makedirs(config.FIGURES_DIR, exist_ok=True)

    CHEMELEON_COLOR = '#009E73'  # Green, from colorblind-friendly palette

    # --- Smart-skip ---
    cv_fig_path = os.path.join(config.FIGURES_DIR, 'phase3c_cv_metrics')
    sel_fig_path = os.path.join(config.FIGURES_DIR,
                                'phase3c_selectivity_ecoli')
    if (os.path.exists(cv_fig_path + '.png')
            and os.path.exists(sel_fig_path + '.png')):
        logger.info("  Figures: SKIP (phase3c figures already exist)")
        return

    setup_publication_style()

    # ---- Figure 1: CV metrics bar chart ----
    if all_cv_results:
        model_names = [k for k in all_cv_results.keys()
                       if all_cv_results[k].get('mean_roc_auc') is not None]
        roc_means = [all_cv_results[m].get('mean_roc_auc', 0)
                     for m in model_names]
        roc_stds = [all_cv_results[m].get('std_roc_auc', 0)
                    for m in model_names]
        pr_means = [all_cv_results[m].get('mean_pr_auc', 0)
                    for m in model_names]
        pr_stds = [all_cv_results[m].get('std_pr_auc', 0)
                   for m in model_names]

        fig, axes = plt.subplots(1, 2, figsize=(14, 5))
        x = np.arange(len(model_names))
        display_names = [n.replace('_', '\n') for n in model_names]

        ax = axes[0]
        ax.bar(x, roc_means, yerr=roc_stds, color=CHEMELEON_COLOR,
               edgecolor='black', linewidth=0.5, capsize=3)
        for i, (m, s) in enumerate(zip(roc_means, roc_stds)):
            ax.text(i, m + s + 0.01, f'{m:.3f}', ha='center',
                    va='bottom', fontsize=8)
        ax.set_xticks(x)
        ax.set_xticklabels(display_names, fontsize=7)
        ax.set_ylabel('ROC-AUC')
        ax.set_title('A. CheMeleon Frozen ROC-AUC (5-fold scaffold CV)')
        ax.set_ylim(0, 1.05)
        ax.axhline(y=0.5, color='gray', linestyle='--', alpha=0.3)
        sns.despine(ax=ax)

        ax = axes[1]
        ax.bar(x, pr_means, yerr=pr_stds, color=CHEMELEON_COLOR,
               edgecolor='black', linewidth=0.5, capsize=3)
        for i, (m, s) in enumerate(zip(pr_means, pr_stds)):
            ax.text(i, m + s + 0.01, f'{m:.3f}', ha='center',
                    va='bottom', fontsize=8)
        ax.set_xticks(x)
        ax.set_xticklabels(display_names, fontsize=7)
        ax.set_ylabel('PR-AUC')
        ax.set_title('B. CheMeleon Frozen PR-AUC (5-fold scaffold CV)')
        ax.set_ylim(0, 1.05)
        sns.despine(ax=ax)

        plt.tight_layout()
        save_figure(fig, cv_fig_path)
        logger.info("  Figure: phase3c_cv_metrics")

    # ---- Figure 2: Selectivity for E. coli t=10 ----
    key = 'ecoli_t10'
    if key in ranked_lists:
        df_r = ranked_lists[key]
        fig, axes = plt.subplots(1, 3, figsize=(15, 4.5))

        ax = axes[0]
        ax.hist(df_r['selectivity_score'], bins=60, color=CHEMELEON_COLOR,
                edgecolor='white', linewidth=0.3, alpha=0.8)
        ax.set_xlabel('Selectivity Score S')
        ax.set_ylabel('Count')
        ax.set_title('A. S distribution (CheMeleon, E. coli, t=10)')
        sns.despine(ax=ax)

        ax = axes[1]
        sc = ax.scatter(df_r['p_gut'], df_r['p_pathogen'],
                        c=df_r['selectivity_score'], cmap='RdYlGn',
                        s=4, alpha=0.5, edgecolors='none', vmin=0, vmax=1)
        plt.colorbar(sc, ax=ax, label='S score')
        ax.set_xlabel(r'$\hat{P}_{gut}$')
        ax.set_ylabel(r'$\hat{P}_{pathogen}$')
        ax.set_title('B. Pathogen vs Gut probability')
        sns.despine(ax=ax)

        ax = axes[2]
        top20 = df_r.head(20)
        ax.barh(range(len(top20)), top20['selectivity_score'],
                color=COLORS['highlight'], edgecolor='black',
                linewidth=0.5)
        ax.set_yticks(range(len(top20)))
        ax.set_yticklabels(
            [f"{r['name'][:25]}" for _, r in top20.iterrows()],
            fontsize=7)
        ax.set_xlabel('Selectivity Score S')
        ax.set_title('C. Top 20 Candidates (CheMeleon)')
        ax.invert_yaxis()
        sns.despine(ax=ax)

        plt.tight_layout()
        save_figure(fig, sel_fig_path)
        logger.info("  Figure: phase3c_selectivity_ecoli")


# ===========================================================================
# MAIN
# ===========================================================================

def main():
    log_phase_start(logger, "Phase 3C-Frozen: CheMeleon Frozen Encoder Training")

    t_start = time.time()
    os.makedirs(FROZEN_DIR, exist_ok=True)
    os.makedirs(config.RESULTS_DIR, exist_ok=True)

    metrics_path = os.path.join(config.RESULTS_DIR, 'chemeleon_frozen_cv_metrics.json')

    # ---------------------------------------------------------------
    # RESUME: load any previously saved metrics
    # ---------------------------------------------------------------
    all_metrics = {}
    if os.path.exists(metrics_path):
        try:
            with open(metrics_path) as f:
                all_metrics = json.load(f)
        except Exception:
            all_metrics = {}

    # Build task list
    tasks = []
    for pkey, pinfo in config.PATHOGENS.items():
        csv_path = os.path.join(config.CHEMBL_DIR, pinfo['csv_filename'])
        if os.path.exists(csv_path):
            tasks.append((pkey, csv_path))
    for t in config.HARM_THRESHOLDS:
        tasks.append((f'gut_t{t}', None))

    # Check if ALL tasks are already complete
    n_ok = sum(1 for tn, _ in tasks
               if tn in all_metrics and all_metrics[tn].get('mean_roc_auc') is not None)
    if n_ok >= len(tasks):
        logger.info(f"  SKIP: all {n_ok}/{len(tasks)} tasks already complete in {metrics_path}")
    elif n_ok > 0:
        logger.info(f"  RESUME: {n_ok}/{len(tasks)} tasks already complete, continuing...")

    # Download CheMeleon weights
    mp_path = ensure_chemeleon_weights()
    if mp_path is None:
        logger.error("  Cannot download CheMeleon weights. Skipping frozen encoder.")
        return

    # GPU detection
    gpu = False
    try:
        import torch
        gpu = torch.cuda.is_available()
        if gpu:
            props = torch.cuda.get_device_properties(0)
            logger.info(f"  GPU: {torch.cuda.get_device_name(0)} "
                        f"({props.total_memory / 1e9:.1f} GB)")
    except Exception:
        pass

    # ---------------------------------------------------------------
    # Train each task (CV)
    # ---------------------------------------------------------------
    if n_ok < len(tasks):
        for task_idx, (task_name, csv_path) in enumerate(tasks):
            logger.info(f"\n  Task {task_idx+1}/{len(tasks)}: {task_name}")

            # TASK-LEVEL SKIP: if this task is already complete
            if task_name in all_metrics and all_metrics[task_name].get('mean_roc_auc') is not None:
                roc = all_metrics[task_name].get('mean_roc_auc', '?')
                logger.info(f"    SKIP (already complete, ROC-AUC={roc})")
                continue

            # Load splits
            if task_name.startswith('gut_'):
                splits_name = 'maier_scaffold_folds'
            else:
                splits_name = f'{task_name}_scaffold_folds'

            splits_path = os.path.join(config.SPLITS_DIR, f'{splits_name}.pkl')
            if not os.path.exists(splits_path):
                splits_path_json = os.path.join(config.SPLITS_DIR, f'{splits_name}.json')
                if os.path.exists(splits_path_json):
                    splits_path = splits_path_json
                else:
                    logger.warning(f"    No splits for {task_name}, skipping")
                    logger.warning(f"    Searched: {splits_path} and {splits_path_json}")
                    continue

            # Load SMILES and labels from the DMPNN input CSVs
            dmpnn_csv = os.path.join(config.DATA_DIR, 'dmpnn_input', f'{task_name}.csv')
            if not os.path.exists(dmpnn_csv):
                dmpnn_csv = os.path.join(config.DMPNN_INPUT_DIR, f'{task_name}.csv')
            if not os.path.exists(dmpnn_csv):
                logger.warning(f"    No DMPNN input CSV for {task_name}, skipping")
                continue

            df = pd.read_csv(dmpnn_csv)
            if 'smiles' not in df.columns or 'label' not in df.columns:
                logger.warning(f"    Missing columns in {dmpnn_csv}, skipping")
                continue

            smiles_arr = df['smiles'].values
            labels_arr = df['label'].values
            folds = load_folds(splits_path)

            fold_metrics = []
            task_dir = os.path.join(FROZEN_DIR, task_name)
            os.makedirs(task_dir, exist_ok=True)
            n_folds = min(len(folds), config.N_FOLDS)

            for fold_idx in range(n_folds):
                fold_dir = os.path.join(task_dir, f'fold_{fold_idx}')
                os.makedirs(fold_dir, exist_ok=True)

                # -------------------------------------------------------
                # FOLD-LEVEL RESUME: check for saved fold metrics
                # -------------------------------------------------------
                fold_metrics_path = os.path.join(fold_dir, 'fold_metrics.json')
                if os.path.exists(fold_metrics_path):
                    try:
                        with open(fold_metrics_path) as f:
                            fm = json.load(f)
                        if fm.get('roc_auc') is not None:
                            fold_metrics.append(fm)
                            logger.info(f"    Fold {fold_idx}: RESUME "
                                        f"(ROC-AUC={fm['roc_auc']:.4f})")
                            continue
                    except Exception:
                        pass  # corrupt file, retrain

                t0 = time.time()
                train_idx, val_idx = get_train_test_indices(folds, fold_idx)

                train_smi = smiles_arr[train_idx].tolist()
                train_lab = labels_arr[train_idx].tolist()
                val_smi = smiles_arr[val_idx].tolist()
                val_lab = labels_arr[val_idx].tolist()

                try:
                    preds = train_frozen_fold(
                        mp_path, train_smi, train_lab, val_smi, val_lab,
                        fold_dir, gpu=gpu
                    )
                    fm = compute_fold_metrics(np.array(val_lab), preds)
                    fold_metrics.append(fm)
                    t1 = time.time()
                    roc = fm.get('roc_auc', '?')
                    logger.info(f"    Fold {fold_idx}: ROC-AUC={roc}, time={t1-t0:.0f}s")

                    # FOLD-LEVEL SAVE: persist metrics immediately
                    with open(fold_metrics_path, 'w') as f:
                        json.dump(fm, f, indent=2, default=_json_safe)

                except Exception as e:
                    logger.warning(f"    Fold {fold_idx} failed: {e}")
                    import traceback
                    traceback.print_exc()

            # ---------------------------------------------------------------
            # Aggregate task metrics
            # ---------------------------------------------------------------
            if fold_metrics:
                task_agg = aggregate_fold_metrics(fold_metrics)
                task_agg['n_folds'] = len(fold_metrics)

                # CRITICAL: avoid circular reference.
                full_agg_copy = {k: v for k, v in task_agg.items()}
                task_agg['full_metrics_agg'] = full_agg_copy

                all_metrics[task_name] = task_agg
                logger.info(f"    {task_name}: mean ROC-AUC="
                            f"{task_agg.get('mean_roc_auc', '?')} "
                            f"(+/- {task_agg.get('std_roc_auc', '?')})")

                # INCREMENTAL SAVE: write metrics after each task
                with open(metrics_path, 'w') as f:
                    json.dump(all_metrics, f, indent=2, default=_json_safe)
                logger.info(f"    Saved: {metrics_path} "
                            f"({len(all_metrics)}/{len(tasks)} tasks)")

        # Final save
        with open(metrics_path, 'w') as f:
            json.dump(all_metrics, f, indent=2, default=_json_safe)
        logger.info(f"\n  Final save: {metrics_path} ({len(all_metrics)} tasks)")

    # ---------------------------------------------------------------
    # NEW: Train final models on all data + screen hub
    # ---------------------------------------------------------------
    logger.info("\n" + "=" * 70)
    logger.info("  Training final models and screening hub...")
    logger.info("=" * 70)

    for task_name, csv_path in tasks:
        # Load data
        dmpnn_csv = os.path.join(config.DATA_DIR, 'dmpnn_input',
                                 f'{task_name}.csv')
        if not os.path.exists(dmpnn_csv):
            dmpnn_csv = os.path.join(config.DMPNN_INPUT_DIR,
                                     f'{task_name}.csv')
        if not os.path.exists(dmpnn_csv):
            continue

        df = pd.read_csv(dmpnn_csv)
        smiles_list = df['smiles'].values.tolist()
        labels_list = df['label'].values.tolist()

        task_dir = os.path.join(FROZEN_DIR, task_name)
        train_final_chemeleon(mp_path, smiles_list, labels_list,
                              task_dir, gpu=gpu)

    # Screen hub and compute selectivity
    ranked_lists = screen_hub_chemeleon(mp_path, gpu=gpu)

    # ---------------------------------------------------------------
    # NEW: Generate figures
    # ---------------------------------------------------------------
    logger.info("\n  Generating Phase 3C figures...")
    generate_phase3c_figures(all_metrics, ranked_lists)

    # ---------------------------------------------------------------
    # NEW: Quality report
    # ---------------------------------------------------------------
    os.makedirs(config.REPORTS_DIR, exist_ok=True)
    report_path = os.path.join(config.REPORTS_DIR,
                               'phase3c_quality_report.json')
    quality_report = {
        'phase': '3C',
        'model': 'CheMeleon Frozen Encoder',
        'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
        'n_tasks_trained': len(all_metrics),
        'n_selectivity_lists': len(ranked_lists),
        'cv_summary': {},
        'selectivity_summary': {},
    }
    for tk, m in all_metrics.items():
        quality_report['cv_summary'][tk] = {
            'roc_auc': m.get('mean_roc_auc'),
            'pr_auc': m.get('mean_pr_auc'),
            'n_folds': m.get('n_folds'),
        }
    for rk, df_r in ranked_lists.items():
        quality_report['selectivity_summary'][rk] = {
            'n_compounds': len(df_r),
            'top_score': round(float(df_r['selectivity_score'].iloc[0]), 4),
            'mean_score': round(
                float(df_r['selectivity_score'].mean()), 4),
            'n_above_0.5': int(
                (df_r['selectivity_score'] > 0.5).sum()),
        }
    with open(report_path, 'w') as f:
        json.dump(quality_report, f, indent=2)
    logger.info(f"  Saved: {report_path}")

    t_total = time.time() - t_start
    logger.info(f"  CheMeleon Frozen: {len(all_metrics)} tasks, {t_total:.0f}s")
    log_phase_end(logger, "Phase 3C-Frozen", t_start)


# ===========================================================================
# Unit tests
# ===========================================================================

def run_tests():
    print("Running Phase 3C-Frozen (CheMeleon Frozen) unit tests...")
    passed, failed = 0, 0
    def _assert(cond, msg):
        nonlocal passed, failed
        if cond: print(f"  [PASS] {msg}"); passed += 1
        else: print(f"  [FAIL] {msg}"); failed += 1

    _assert(CHEMELEON_MP_URL.startswith('https://zenodo.org'), "URL valid")
    _assert('15460715' in CHEMELEON_MP_URL, "Zenodo record ID correct")
    _assert('chemeleon_mp.pt' in CHEMELEON_MP_URL, "File name correct")

    # Test metrics computation (now uses full_metrics module)
    y_true = np.array([1, 1, 0, 0, 1, 0])
    y_pred = np.array([0.9, 0.8, 0.2, 0.1, 0.7, 0.3])
    m = compute_fold_metrics(y_true, y_pred)
    _assert(m['roc_auc'] is not None, f"ROC-AUC computed: {m['roc_auc']:.3f}")
    _assert(m['roc_auc'] > 0.9, f"ROC-AUC > 0.9: {m['roc_auc']:.3f}")
    _assert(m['pr_auc'] is not None, "PR-AUC computed")
    _assert(m['mcc'] is not None, "MCC computed")
    _assert('brier_score' in m, "Brier score computed (full_metrics key)")
    _assert(m['brier_score'] < 0.1, f"Brier < 0.1: {m['brier_score']:.3f}")
    _assert('sensitivity' in m, "Sensitivity present (from full_metrics)")
    _assert('specificity' in m, "Specificity present (from full_metrics)")
    _assert('f1_macro' in m, "F1 macro present (from full_metrics)")
    _assert('balanced_accuracy' in m, "Balanced accuracy present (from full_metrics)")

    # Test aggregation and JSON serialization (circular ref regression test)
    agg = aggregate_fold_metrics([m, m])
    _assert('mean_roc_auc' in agg, "Aggregation has mean_roc_auc")
    _assert('mean_sensitivity' in agg, "Aggregation has mean_sensitivity")
    _assert('mean_brier_score' in agg, "Aggregation has mean_brier_score")
    _assert(agg['n_folds'] == 2, f"Aggregation n_folds=2: {agg['n_folds']}")

    # CRITICAL: test that full_metrics_agg copy does not create circular ref
    agg_copy = {k: v for k, v in agg.items()}
    agg['full_metrics_agg'] = agg_copy
    try:
        serialized = json.dumps(agg, indent=2, default=_json_safe)
        _assert(True, "JSON serialization: no circular reference")
        _assert('"mean_roc_auc"' in serialized, "JSON contains mean_roc_auc")
        _assert('"full_metrics_agg"' in serialized, "JSON contains full_metrics_agg")
    except ValueError as e:
        _assert(False, f"JSON serialization FAILED: {e}")

    # Test _json_safe handles numpy types
    _assert(_json_safe(np.float64(0.5)) == 0.5, "numpy float64 -> float")
    _assert(_json_safe(np.int64(42)) == 42, "numpy int64 -> int")

    # Test path construction
    _assert(os.path.basename(FROZEN_DIR) == 'chemeleon_frozen', f"Dir name: {FROZEN_DIR}")

    print(f"Unit tests: {passed} passed, {failed} failed")


if __name__ == '__main__':
    if '--test' in sys.argv:
        run_tests()
    else:
        main()