"""
10_train_molformer.py -- Phase 3D: Fine-tune MoLFormer-XL on antibiotic activity data.

MoLFormer-XL (IBM, Nature Machine Intelligence 2022) is a transformer pretrained
on 1.1B SMILES from ZINC+PubChem using masked language modeling. We fine-tune it
with a binary classification head on our pathogen/gut datasets using the same
5-fold scaffold CV splits as RF and D-MPNN.

Input:
  - data/chembl/{pathogen}_activity.csv (SMILES + label)
  - data/maier/maier_combined.csv (gut harm)
  - outputs/shared/splits/ (precomputed scaffold folds)

Output:
  - outputs/runs/{run_id}/models/molformer/{task}/fold_{i}/model.pt
  - outputs/runs/{run_id}/results/molformer_cv_metrics.json
  - outputs/runs/{run_id}/results/screening/molformer_ranked_*.csv

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import os
import sys
import json
import time
import warnings
import argparse
import numpy as np
import pandas as pd
from typing import Optional, Dict, List

# Suppress noisy warnings
warnings.filterwarnings('ignore', category=FutureWarning)
warnings.filterwarnings('ignore', category=UserWarning)

# Add scripts/ to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import config
from utils.logging_utils import setup_logging, log_phase_start, log_phase_end
from utils.scaffold_split import load_folds, get_train_test_indices
from utils.smiles_utils import canonicalize_smiles

logger = setup_logging('phase3d', log_dir=config.LOGS_DIR)

MOLFORMER_DIR = os.path.join(config.MODELS_DIR, 'molformer')
MOLFORMER_MODEL_ID = "ibm/MoLFormer-XL-both-10pct"

# --------------------------------------------------------------------------
# HuggingFace environment setup (defensive: works even without shell script)
# --------------------------------------------------------------------------
_HF_CACHE = os.path.join(config.PROJECT_DIR, '.hf_cache')
if 'HF_HOME' not in os.environ:
    os.environ['HF_HOME'] = _HF_CACHE
    os.environ['TRANSFORMERS_CACHE'] = _HF_CACHE
os.makedirs(os.environ.get('HF_HOME', _HF_CACHE), exist_ok=True)

# Hyperparameters for fine-tuning
MOLFORMER_PARAMS = {
    'learning_rate': 1e-5,
    'batch_size': 32,
    'epochs': 20,
    'warmup_ratio': 0.1,
    'weight_decay': 0.01,
    'max_length': 202,  # MoLFormer max token length
    'patience': 5,      # Early stopping patience
}


def check_dependencies():
    """Verify torch and transformers are available."""
    try:
        import torch
        ver_torch = torch.__version__
    except ImportError:
        logger.error("PyTorch not installed. Run: pip install torch")
        return False

    try:
        import transformers
        ver_tf = transformers.__version__
    except ImportError:
        logger.error("transformers not installed. Run: pip install transformers")
        return False

    logger.info(f"  torch={ver_torch}, transformers={ver_tf}")

    # MoLFormer custom code was written for transformers 4.x.
    # Versions 5.x may have breaking API changes in PreTrainedModel.
    major = int(ver_tf.split('.')[0])
    if major >= 5:
        logger.warning(f"  transformers {ver_tf} detected (major version {major}).")
        logger.warning(f"  MoLFormer custom code was authored for transformers 4.x.")
        logger.warning(f"  If model loading fails, try: pip install 'transformers>=4.30,<5.0'")

    gpu = torch.cuda.is_available()
    if gpu:
        props = torch.cuda.get_device_properties(0)
        mem = props.total_memory / (1024**3)
        logger.info(f"  GPU: {torch.cuda.get_device_name(0)} ({mem:.1f} GB)")
    else:
        logger.info("  GPU: not available (CPU mode)")
    return True


class MoLFormerClassifier:
    """
    Fine-tunes MoLFormer-XL for binary classification.

    Adds a linear classification head on top of the pooled [CLS] output.
    Uses AdamW with linear warmup + cosine decay.
    """

    def __init__(self, model_id=MOLFORMER_MODEL_ID, device=None):
        import torch
        from transformers import AutoModel, AutoTokenizer
        import transformers

        self.device = device or ('cuda' if torch.cuda.is_available() else 'cpu')
        logger.info(f"    Loading MoLFormer from {model_id}...")
        logger.info(f"    transformers version: {transformers.__version__}")

        self.tokenizer = AutoTokenizer.from_pretrained(
            model_id, trust_remote_code=True
        )

        # MoLFormer custom code may not be compatible with all transformers versions.
        # Try with deterministic_eval first (as in model card), fall back without it.
        try:
            self.encoder = AutoModel.from_pretrained(
                model_id, deterministic_eval=True, trust_remote_code=True
            )
        except (TypeError, AttributeError) as e:
            logger.warning(f"    MoLFormer load with deterministic_eval failed: {e}")
            logger.info("    Retrying without deterministic_eval...")
            try:
                self.encoder = AutoModel.from_pretrained(
                    model_id, trust_remote_code=True
                )
            except Exception as e2:
                logger.error(f"    MoLFormer load failed entirely: {e2}")
                logger.error(f"    This is likely a transformers version incompatibility.")
                logger.error(f"    Try: pip install 'transformers>=4.30,<5.0'")
                raise

        # Get hidden size from encoder config
        hidden_size = self.encoder.config.hidden_size

        # Classification head: dropout + linear
        self.classifier = torch.nn.Sequential(
            torch.nn.Dropout(0.1),
            torch.nn.Linear(hidden_size, 1)
        )

        self.encoder.to(self.device)
        self.classifier.to(self.device)

        n_params_enc = sum(p.numel() for p in self.encoder.parameters())
        n_params_cls = sum(p.numel() for p in self.classifier.parameters())
        logger.info(f"    Encoder: {n_params_enc/1e6:.1f}M params")
        logger.info(f"    Classifier: {n_params_cls} params")
        logger.info(f"    Device: {self.device}")

    def _tokenize(self, smiles_list, max_length=202):
        """Tokenize SMILES strings for MoLFormer."""
        return self.tokenizer(
            smiles_list,
            padding=True,
            truncation=True,
            max_length=max_length,
            return_tensors='pt'
        )

    def fit(self, train_smiles, train_labels, val_smiles=None, val_labels=None,
            epochs=20, batch_size=32, lr=1e-5, patience=5):
        """
        Fine-tune the model.

        Returns dict with training history.
        """
        import torch
        from torch.utils.data import DataLoader, TensorDataset

        self.encoder.train()
        self.classifier.train()

        # Tokenize all at once (fits in memory for our dataset sizes)
        logger.info(f"    Tokenizing {len(train_smiles)} training SMILES...")
        tok_t0 = time.time()
        train_enc = self._tokenize(train_smiles)
        train_ids = train_enc['input_ids']
        train_mask = train_enc['attention_mask']
        train_y = torch.tensor(train_labels, dtype=torch.float32)
        logger.info(f"    Tokenized in {time.time()-tok_t0:.1f}s, "
                    f"input shape: {train_ids.shape}")

        dataset = TensorDataset(train_ids, train_mask, train_y)
        loader = DataLoader(dataset, batch_size=batch_size, shuffle=True)

        # Optimizer: AdamW with different LR for encoder vs classifier
        optimizer = torch.optim.AdamW([
            {'params': self.encoder.parameters(), 'lr': lr},
            {'params': self.classifier.parameters(), 'lr': lr * 10},
        ], weight_decay=0.01)

        # Scheduler: linear warmup + cosine decay
        total_steps = len(loader) * epochs
        warmup_steps = int(total_steps * 0.1)

        def lr_lambda(step):
            if step < warmup_steps:
                return float(step) / float(max(1, warmup_steps))
            progress = float(step - warmup_steps) / float(max(1, total_steps - warmup_steps))
            return max(0.0, 0.5 * (1.0 + np.cos(np.pi * progress)))

        scheduler = torch.optim.lr_scheduler.LambdaLR(optimizer, lr_lambda)
        criterion = torch.nn.BCEWithLogitsLoss()

        best_val_loss = float('inf')
        best_state = None
        patience_counter = 0
        history = []

        n_total_batches = len(loader)
        logger.info(f"    Training: {epochs} epochs, {n_total_batches} batches/epoch, "
                    f"batch_size={batch_size}, {len(train_smiles)} compounds")
        logger.info(f"    LR: encoder={lr}, classifier={lr*10}, warmup={warmup_steps}/{total_steps} steps")

        for epoch in range(epochs):
            self.encoder.train()
            self.classifier.train()
            epoch_loss = 0.0
            n_batches = 0
            epoch_t0 = time.time()

            for batch_i, (batch_ids, batch_mask, batch_y) in enumerate(loader):
                batch_ids = batch_ids.to(self.device)
                batch_mask = batch_mask.to(self.device)
                batch_y = batch_y.to(self.device)

                optimizer.zero_grad()
                outputs = self.encoder(input_ids=batch_ids, attention_mask=batch_mask)
                pooled = outputs.pooler_output  # [batch, hidden]
                logits = self.classifier(pooled).squeeze(-1)  # [batch]
                loss = criterion(logits, batch_y)
                loss.backward()
                torch.nn.utils.clip_grad_norm_(
                    list(self.encoder.parameters()) + list(self.classifier.parameters()),
                    max_norm=1.0
                )
                optimizer.step()
                scheduler.step()

                epoch_loss += loss.item()
                n_batches += 1

                # Batch-level progress every 50 batches
                if (batch_i + 1) % 50 == 0 or (batch_i + 1) == n_total_batches:
                    cur_lr = scheduler.get_last_lr()[0]
                    elapsed = time.time() - epoch_t0
                    speed = (batch_i + 1) / elapsed if elapsed > 0 else 0
                    print(f"      Epoch {epoch+1}/{epochs} | "
                          f"Batch {batch_i+1}/{n_total_batches} | "
                          f"loss={loss.item():.4f} | "
                          f"lr={cur_lr:.2e} | "
                          f"{speed:.1f} batch/s",
                          flush=True)

            avg_train_loss = epoch_loss / max(n_batches, 1)

            # Validation
            val_loss = None
            if val_smiles is not None and len(val_smiles) > 0:
                val_probs = self.predict_proba(val_smiles, batch_size=batch_size)
                val_loss = float(criterion(
                    torch.tensor(np.log(val_probs / (1 - val_probs + 1e-8))),
                    torch.tensor(val_labels, dtype=torch.float32)
                ).item())

                if val_loss < best_val_loss:
                    best_val_loss = val_loss
                    best_state = {
                        'encoder': {k: v.cpu().clone() for k, v in self.encoder.state_dict().items()},
                        'classifier': {k: v.cpu().clone() for k, v in self.classifier.state_dict().items()},
                    }
                    patience_counter = 0
                else:
                    patience_counter += 1

            epoch_elapsed = time.time() - epoch_t0
            epoch_info = f"    Epoch {epoch+1}/{epochs}: train_loss={avg_train_loss:.4f}"
            if val_loss is not None:
                epoch_info += f", val_loss={val_loss:.4f}"
                marker = " *" if patience_counter == 0 and val_loss <= best_val_loss else ""
                epoch_info += f", best={best_val_loss:.4f}{marker}"
                epoch_info += f", patience={patience_counter}/{patience}"
            epoch_info += f", {epoch_elapsed:.0f}s"
            print(epoch_info, flush=True)
            logger.info(epoch_info)

            history.append({'epoch': epoch + 1, 'train_loss': avg_train_loss, 'val_loss': val_loss})

            if patience_counter >= patience and val_smiles is not None:
                print(f"    Early stopping at epoch {epoch+1} (patience={patience})", flush=True)
                logger.info(f"      Early stopping at epoch {epoch+1}")
                break

        # Restore best model (if validation was used)
        if best_state is not None:
            self.encoder.load_state_dict(best_state['encoder'])
            self.classifier.load_state_dict(best_state['classifier'])

        return {'history': history, 'best_val_loss': best_val_loss}

    def predict_proba(self, smiles_list, batch_size=64):
        """Predict probability of class 1."""
        import torch

        self.encoder.eval()
        self.classifier.eval()

        all_probs = []
        for i in range(0, len(smiles_list), batch_size):
            batch = smiles_list[i:i + batch_size]
            enc = self._tokenize(batch)
            with torch.no_grad():
                outputs = self.encoder(
                    input_ids=enc['input_ids'].to(self.device),
                    attention_mask=enc['attention_mask'].to(self.device)
                )
                logits = self.classifier(outputs.pooler_output).squeeze(-1)
                probs = torch.sigmoid(logits).cpu().numpy()
            all_probs.append(probs)

        return np.concatenate(all_probs)

    def save(self, path):
        """Save model weights. Makes tensors contiguous to avoid MoLFormer save errors."""
        import torch
        os.makedirs(path, exist_ok=True)
        # MoLFormer's linear attention layers may have non-contiguous tensors.
        # .contiguous() fixes "non contiguous tensor" errors during save.
        encoder_state = {k: v.cpu().contiguous() for k, v in self.encoder.state_dict().items()}
        classifier_state = {k: v.cpu().contiguous() for k, v in self.classifier.state_dict().items()}
        torch.save({
            'encoder_state': encoder_state,
            'classifier_state': classifier_state,
        }, os.path.join(path, 'molformer_finetuned.pt'))

    def load(self, path):
        """Load model weights."""
        import torch
        ckpt = torch.load(os.path.join(path, 'molformer_finetuned.pt'),
                          map_location=self.device, weights_only=False)
        self.encoder.load_state_dict(ckpt['encoder_state'])
        self.classifier.load_state_dict(ckpt['classifier_state'])


def train_molformer_with_cv(
    data_csv: str,
    fold_assignments: List[int],
    model_name: str,
    model_base_dir: str,
) -> Dict:
    """
    Train MoLFormer with 5-fold scaffold CV.
    """
    from sklearn.metrics import roc_auc_score, roc_curve, average_precision_score
    try:
        from utils.full_metrics import compute_full_metrics, aggregate_fold_metrics
        HAS_FULL_METRICS = True
    except ImportError:
        HAS_FULL_METRICS = False

    n_folds = config.N_FOLDS
    df = pd.read_csv(data_csv)
    y = df['label'].values.astype(int)
    smiles = df['smiles'].values.tolist()

    oof_preds = np.full(len(y), np.nan)
    fold_metrics = []
    fold_full_metrics = []

    logger.info(f"\n  Training {model_name} with {n_folds}-fold scaffold CV...")

    for fold_idx in range(n_folds):
        _FF = f"10_train_molformer.py:{model_name}:fold_{fold_idx}"
        logger.info(f"    [{_FF}] Starting fold {fold_idx}/{n_folds}...")

        try:
            train_idx, test_idx = get_train_test_indices(fold_assignments, fold_idx)
        except Exception as e:
            logger.error(f"    [{_FF}] Fold split FAILED: {e}")
            fold_metrics.append({'fold': fold_idx, 'roc_auc': np.nan, 'pr_auc': np.nan})
            continue

        train_smiles = [smiles[i] for i in train_idx]
        test_smiles = [smiles[i] for i in test_idx]
        train_labels = y[train_idx]
        test_labels = y[test_idx]

        if len(np.unique(train_labels)) < 2 or len(np.unique(test_labels)) < 2:
            logger.warning(f"    Fold {fold_idx}: degenerate (single class)")
            fold_metrics.append({'fold': fold_idx, 'roc_auc': np.nan, 'pr_auc': np.nan})
            continue

        fold_dir = os.path.join(model_base_dir, f'fold_{fold_idx}')
        os.makedirs(fold_dir, exist_ok=True)

        # --- FOLD SKIP: if saved model exists, load and predict only ---
        saved_model_path = os.path.join(fold_dir, 'molformer_finetuned.pt')
        if os.path.exists(saved_model_path):
            try:
                model = MoLFormerClassifier()
                model.load(fold_dir)
                probs = model.predict_proba(test_smiles, batch_size=64)
                oof_preds[test_idx] = probs

                roc_auc = roc_auc_score(test_labels, probs)
                pr_auc = average_precision_score(test_labels, probs)
                fpr, tpr, _ = roc_curve(test_labels, probs)
                full_m = compute_full_metrics(test_labels, probs) if HAS_FULL_METRICS else {}

                fold_metrics.append({
                    'fold': fold_idx, 'roc_auc': round(roc_auc, 4),
                    'pr_auc': round(pr_auc, 4),
                    'train_size': len(train_idx), 'test_size': len(test_idx),
                    'full_metrics': full_m,
                })
                if full_m:
                    fold_full_metrics.append(full_m)

                logger.info(f"    [{_FF}] SKIP (cached model), "
                            f"ROC-AUC={roc_auc:.4f}, PR-AUC={pr_auc:.4f}")
                del model
                import torch
                if torch.cuda.is_available():
                    torch.cuda.empty_cache()
                continue
            except Exception as e:
                logger.warning(f"    [{_FF}] Cached model unreadable ({e}), retraining")

        try:
            # Create model (downloads pretrained weights on first use)
            model = MoLFormerClassifier()

            # Fine-tune
            params = MOLFORMER_PARAMS
            logger.info(f"    [{_FF}] Train: {len(train_smiles)} compounds, "
                        f"Test: {len(test_smiles)} compounds")
            logger.info(f"    [{_FF}] Params: lr={params['learning_rate']}, "
                        f"batch={params['batch_size']}, "
                        f"epochs={params['epochs']}, "
                        f"patience={params['patience']}")
            fold_t0 = time.time()

            fit_result = model.fit(
                train_smiles, train_labels,
                val_smiles=test_smiles, val_labels=test_labels,
                epochs=params['epochs'],
                batch_size=params['batch_size'],
                lr=params['learning_rate'],
                patience=params['patience'],
            )

            # Save model
            model.save(fold_dir)

            # Predict on test fold
            probs = model.predict_proba(test_smiles, batch_size=64)
            oof_preds[test_idx] = probs

            roc_auc = roc_auc_score(test_labels, probs)
            pr_auc = average_precision_score(test_labels, probs)
            fpr, tpr, _ = roc_curve(test_labels, probs)

            # Full metrics
            full_m = {}
            if HAS_FULL_METRICS:
                full_m = compute_full_metrics(test_labels, probs)

            fold_metrics.append({
                'fold': fold_idx, 'roc_auc': round(roc_auc, 4),
                'pr_auc': round(pr_auc, 4),
                'train_size': len(train_idx), 'test_size': len(test_idx),
                'full_metrics': full_m,
            })
            if full_m:
                fold_full_metrics.append(full_m)

            fold_elapsed = time.time() - fold_t0
            logger.info(f"    [{_FF}] ROC-AUC={roc_auc:.4f}, PR-AUC={pr_auc:.4f}, "
                        f"MCC={full_m.get('mcc', 'N/A')}, {fold_elapsed:.0f}s")
            print(f"    Fold {fold_idx} complete: ROC-AUC={roc_auc:.4f}, "
                  f"time={fold_elapsed:.0f}s", flush=True)

            # Free GPU memory
            del model
            import torch
            if torch.cuda.is_available():
                torch.cuda.empty_cache()

        except Exception as e:
            logger.error(f"    [{_FF}] FAILED: {type(e).__name__}: {e}")
            import traceback
            logger.error(traceback.format_exc())
            fold_metrics.append({
                'fold': fold_idx, 'roc_auc': np.nan, 'pr_auc': np.nan,
                'train_size': len(train_idx), 'test_size': len(test_idx),
            })

    # Aggregate
    valid_rocs = [m['roc_auc'] for m in fold_metrics if not np.isnan(m.get('roc_auc', np.nan))]
    valid_prs = [m['pr_auc'] for m in fold_metrics if not np.isnan(m.get('pr_auc', np.nan))]

    result = {
        'model_name': model_name,
        'n_samples': len(y),
        'n_positive': int(y.sum()),
        'n_folds_completed': len(valid_rocs),
        'mean_roc_auc': round(float(np.mean(valid_rocs)), 4) if valid_rocs else None,
        'std_roc_auc': round(float(np.std(valid_rocs)), 4) if valid_rocs else None,
        'mean_pr_auc': round(float(np.mean(valid_prs)), 4) if valid_prs else None,
        'std_pr_auc': round(float(np.std(valid_prs)), 4) if valid_prs else None,
        'per_fold': fold_metrics,
    }

    # Full metrics aggregation
    if fold_full_metrics:
        from utils.full_metrics import aggregate_fold_metrics
        result['full_metrics_agg'] = aggregate_fold_metrics(fold_full_metrics)

    # OOF predictions
    valid_mask = ~np.isnan(oof_preds)
    if valid_mask.sum() > 0:
        from sklearn.metrics import roc_curve
        fpr, tpr, _ = roc_curve(y[valid_mask], oof_preds[valid_mask])
        result['oof_fpr'] = fpr.tolist()
        result['oof_tpr'] = tpr.tolist()

    if valid_rocs:
        logger.info(f"  {model_name} CV: ROC-AUC = {result['mean_roc_auc']:.4f} "
                     f"+/- {result['std_roc_auc']:.4f}")
    else:
        logger.warning(f"  {model_name}: ALL FOLDS FAILED")

    return result


def train_final_model(data_csv: str, model_name: str, model_dir: str):
    """Train on all data (no validation) for final screening."""
    df = pd.read_csv(data_csv)
    smiles = df['smiles'].values.tolist()
    labels = df['label'].values.astype(int)

    final_dir = os.path.join(model_dir, 'final')
    os.makedirs(final_dir, exist_ok=True)

    logger.info(f"    Training final {model_name} on all {len(df)} samples...")
    model = MoLFormerClassifier()
    model.fit(smiles, labels, epochs=MOLFORMER_PARAMS['epochs'],
              batch_size=MOLFORMER_PARAMS['batch_size'],
              lr=MOLFORMER_PARAMS['learning_rate'], patience=999)
    model.save(final_dir)

    return model


def screen_hub(model, hub_csv: str, save_path: str, model_name: str):
    """Screen the Drug Repurposing Hub with a trained model."""
    df_hub = pd.read_csv(hub_csv)
    smiles = df_hub['smiles'].values.tolist()
    probs = model.predict_proba(smiles, batch_size=64)

    df_hub['prob'] = probs
    df_hub = df_hub.sort_values('prob', ascending=False)
    df_hub.to_csv(save_path, index=False)
    logger.info(f"    Screening: {save_path} ({len(df_hub)} compounds)")
    return df_hub


# ===========================================================================
# NEW: Selectivity score computation from existing raw prob files
# ===========================================================================

def compute_selectivity_scores():
    """
    Compute selectivity S = P_pathogen * (1 - P_gut) for all pathogen x gut
    threshold combinations (4 x 3 = 12). Reads existing raw prob CSVs produced
    by screen_hub(), merges on SMILES, and writes 12 ranked CSVs matching the
    RF/D-MPNN output format.

    Output columns: smiles, name, clinical_phase, moa, disease_area, target,
                    p_pathogen, p_gut, selectivity_score, rank
    """
    pathogen_keys = list(config.PATHOGENS.keys())
    gut_thresholds = config.HARM_THRESHOLDS
    metadata_cols = ['smiles', 'name', 'clinical_phase', 'moa',
                     'disease_area', 'target']

    n_computed = 0
    n_skipped = 0
    ranked_lists = {}

    # Load all raw prob files once
    pathogen_probs = {}
    gut_probs = {}

    for pk in pathogen_keys:
        path = os.path.join(config.SCREENING_DIR,
                            f'molformer_ranked_{pk}.csv')
        if os.path.exists(path):
            pathogen_probs[pk] = pd.read_csv(path)
            logger.info(f"    Loaded pathogen probs: {pk} "
                        f"({len(pathogen_probs[pk])} compounds)")
        else:
            logger.warning(f"    Missing pathogen prob file: {path}")

    for gt in gut_thresholds:
        path = os.path.join(config.SCREENING_DIR,
                            f'molformer_ranked_gut_t{gt}.csv')
        if os.path.exists(path):
            gut_probs[gt] = pd.read_csv(path)
            logger.info(f"    Loaded gut probs: t={gt} "
                        f"({len(gut_probs[gt])} compounds)")
        else:
            logger.warning(f"    Missing gut prob file: {path}")

    if not pathogen_probs or not gut_probs:
        logger.warning("    Cannot compute selectivity: missing prob files.")
        return ranked_lists

    # Compute selectivity for each pathogen x gut threshold combination
    for pk in pathogen_keys:
        if pk not in pathogen_probs:
            continue
        df_path = pathogen_probs[pk]

        for gt in gut_thresholds:
            if gt not in gut_probs:
                continue

            out_name = f'molformer_ranked_{pk}_t{gt}.csv'
            out_path = os.path.join(config.SCREENING_DIR, out_name)

            # Smart-skip: if output already exists, load and continue
            if os.path.exists(out_path):
                logger.info(f"    SKIP (exists): {out_name}")
                try:
                    ranked_lists[f'{pk}_t{gt}'] = pd.read_csv(out_path)
                except Exception:
                    pass
                n_skipped += 1
                continue

            df_gut = gut_probs[gt]

            # Merge on SMILES (1:1, verified: zero duplicates in both files)
            merged = df_path[['smiles', 'prob']].merge(
                df_gut[['smiles', 'prob']],
                on='smiles',
                suffixes=('_pathogen', '_gut'),
                how='inner'
            )

            if len(merged) == 0:
                logger.warning(f"    Empty merge for {pk} x gut_t{gt}")
                continue

            # Compute selectivity
            merged['selectivity_score'] = (
                merged['prob_pathogen'] * (1.0 - merged['prob_gut'])
            )

            # Add metadata from pathogen prob file
            meta = df_path[metadata_cols].drop_duplicates(subset='smiles')
            merged = merged.merge(meta, on='smiles', how='left')

            # Sort by selectivity score descending, assign rank
            merged = merged.sort_values('selectivity_score',
                                        ascending=False).reset_index(drop=True)
            merged['rank'] = range(1, len(merged) + 1)

            # Rename prob columns to match RF/D-MPNN format
            merged = merged.rename(columns={
                'prob_pathogen': 'p_pathogen',
                'prob_gut': 'p_gut',
            })

            # Select output columns in exact order
            out_cols = ['smiles', 'name', 'clinical_phase', 'moa',
                        'disease_area', 'target', 'p_pathogen', 'p_gut',
                        'selectivity_score', 'rank']
            df_out = merged[out_cols]
            df_out.to_csv(out_path, index=False)

            ranked_lists[f'{pk}_t{gt}'] = df_out
            n_computed += 1
            logger.info(f"    Saved: {out_name} "
                        f"({len(df_out)} compounds, "
                        f"top S={df_out['selectivity_score'].iloc[0]:.4f})")

    logger.info(f"    Selectivity: {n_computed} computed, "
                f"{n_skipped} skipped (already exist)")
    return ranked_lists


# ===========================================================================
# NEW: Publication-quality figures for Phase 3D
# ===========================================================================

def generate_phase3d_figures(all_cv_results, ranked_lists):
    """
    Generate publication-quality figures for MoLFormer (Phase 3D).
    Matches D-MPNN Phase 3B figure style exactly.
    """
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import seaborn as sns
    from utils.viz_utils import setup_publication_style, save_figure, COLORS

    os.makedirs(config.FIGURES_DIR, exist_ok=True)

    MOLFORMER_COLOR = '#CC79A7'  # Pink, complements existing palette

    # --- Smart-skip: check if figures already exist ---
    cv_fig_path = os.path.join(config.FIGURES_DIR, 'phase3d_cv_metrics')
    sel_fig_path = os.path.join(config.FIGURES_DIR,
                                'phase3d_selectivity_ecoli')
    if (os.path.exists(cv_fig_path + '.png')
            and os.path.exists(sel_fig_path + '.png')):
        logger.info("  Figures: SKIP (phase3d figures already exist)")
        return

    setup_publication_style()

    # ---- Figure 1: CV metrics bar chart ----
    if all_cv_results:
        model_names = list(all_cv_results.keys())
        roc_means = [all_cv_results[m].get('mean_roc_auc') or 0
                     for m in model_names]
        roc_stds = [all_cv_results[m].get('std_roc_auc') or 0
                    for m in model_names]
        pr_means = [all_cv_results[m].get('mean_pr_auc') or 0
                    for m in model_names]
        pr_stds = [all_cv_results[m].get('std_pr_auc') or 0
                   for m in model_names]

        fig, axes = plt.subplots(1, 2, figsize=(14, 5))
        x = np.arange(len(model_names))
        display_names = [n.replace('_', '\n') for n in model_names]

        ax = axes[0]
        ax.bar(x, roc_means, yerr=roc_stds, color=MOLFORMER_COLOR,
               edgecolor='black', linewidth=0.5, capsize=3)
        for i, (m, s) in enumerate(zip(roc_means, roc_stds)):
            ax.text(i, m + s + 0.01, f'{m:.3f}', ha='center',
                    va='bottom', fontsize=8)
        ax.set_xticks(x)
        ax.set_xticklabels(display_names, fontsize=7)
        ax.set_ylabel('ROC-AUC')
        ax.set_title('A. MoLFormer ROC-AUC (5-fold scaffold CV)')
        ax.set_ylim(0, 1.05)
        ax.axhline(y=0.5, color='gray', linestyle='--', alpha=0.3)
        sns.despine(ax=ax)

        ax = axes[1]
        ax.bar(x, pr_means, yerr=pr_stds, color=MOLFORMER_COLOR,
               edgecolor='black', linewidth=0.5, capsize=3)
        for i, (m, s) in enumerate(zip(pr_means, pr_stds)):
            ax.text(i, m + s + 0.01, f'{m:.3f}', ha='center',
                    va='bottom', fontsize=8)
        ax.set_xticks(x)
        ax.set_xticklabels(display_names, fontsize=7)
        ax.set_ylabel('PR-AUC')
        ax.set_title('B. MoLFormer PR-AUC (5-fold scaffold CV)')
        ax.set_ylim(0, 1.05)
        sns.despine(ax=ax)

        plt.tight_layout()
        save_figure(fig, cv_fig_path)
        logger.info("  Figure: phase3d_cv_metrics")

    # ---- Figure 2: Selectivity for E. coli t=10 ----
    key = 'ecoli_t10'
    if key in ranked_lists:
        df_r = ranked_lists[key]
        fig, axes = plt.subplots(1, 3, figsize=(15, 4.5))

        ax = axes[0]
        ax.hist(df_r['selectivity_score'], bins=60, color=MOLFORMER_COLOR,
                edgecolor='white', linewidth=0.3, alpha=0.8)
        ax.set_xlabel('Selectivity Score S')
        ax.set_ylabel('Count')
        ax.set_title('A. S distribution (MoLFormer, E. coli, t=10)')
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
        ax.set_title('C. Top 20 Candidates (MoLFormer)')
        ax.invert_yaxis()
        sns.despine(ax=ax)

        plt.tight_layout()
        save_figure(fig, sel_fig_path)
        logger.info("  Figure: phase3d_selectivity_ecoli")


# ===========================================================================
# MAIN
# ===========================================================================
def main():
    _FM = "10_train_molformer.py:main"
    start_time = log_phase_start(logger, "Phase 3D: MoLFormer-XL Fine-Tuning")

    if not check_dependencies():
        logger.error("Missing dependencies. Cannot proceed.")
        return

    os.makedirs(MOLFORMER_DIR, exist_ok=True)
    os.makedirs(config.SCREENING_DIR, exist_ok=True)

    # ---- Prepare data CSVs (same as 06_train_dmpnn.py) ----
    dmpnn_input_dir = os.path.join(config.DATA_DIR, 'dmpnn_input')
    os.makedirs(dmpnn_input_dir, exist_ok=True)

    # Build task list
    tasks = {}
    for key, info in config.PATHOGENS.items():
        csv_path = os.path.join(config.CHEMBL_DIR, info['csv_filename'])
        if os.path.exists(csv_path):
            out_csv = os.path.join(dmpnn_input_dir, f'{key}.csv')
            if not os.path.exists(out_csv):
                df = pd.read_csv(csv_path)
                if 'smiles' in df.columns and 'label' in df.columns:
                    df[['smiles', 'label']].to_csv(out_csv, index=False)
            tasks[f'molformer_{key}'] = out_csv

    # Gut harm tasks
    maier_csv = os.path.join(config.MAIER_DIR, 'maier_combined.csv')
    if os.path.exists(maier_csv):
        df_maier = pd.read_csv(maier_csv)
        for t in config.HARM_THRESHOLDS:
            name = f'gut_t{t}'
            out_csv = os.path.join(dmpnn_input_dir, f'{name}.csv')
            if not os.path.exists(out_csv) and 'n_hit' in df_maier.columns:
                df_g = df_maier[df_maier['smiles'].notna()].copy()
                df_g['label'] = (df_g['n_hit'] >= t).astype(int)
                df_g[['smiles', 'label']].to_csv(out_csv, index=False)
            tasks[f'molformer_{name}'] = out_csv

    all_metrics = {}
    n_tasks = len(tasks)
    logger.info(f"\n  {n_tasks} tasks to train")

    for task_i, (model_name, data_csv) in enumerate(tasks.items()):
        logger.info(f"\n  >>> Model {task_i+1}/{n_tasks}: {model_name} <<<")

        if not os.path.exists(data_csv):
            logger.warning(f"  Data not found: {data_csv}")
            continue

        task_key = model_name.replace('molformer_', '')
        model_dir = os.path.join(MOLFORMER_DIR, task_key)
        os.makedirs(model_dir, exist_ok=True)

        # Load fold assignments
        # Gut tasks share maier_scaffold_folds; pathogen tasks have their own
        if task_key.startswith('gut_'):
            splits_name = 'maier_scaffold_folds'
        else:
            splits_name = f'{task_key}_scaffold_folds'

        fold_file = os.path.join(config.SPLITS_DIR, f'{splits_name}.pkl')
        if not os.path.exists(fold_file):
            fold_file = os.path.join(config.SPLITS_DIR, f'{splits_name}.npy')
        if not os.path.exists(fold_file):
            logger.warning(f"  Fold file not found: {config.SPLITS_DIR}/{splits_name}.[pkl|npy]")
            logger.info("  Run 04_compute_morgan_fps.py first.")
            continue

        if fold_file.endswith('.pkl'):
            fold_assignments = load_folds(fold_file)
        else:
            fold_assignments = np.load(fold_file).tolist()

        # CV training
        t0 = time.time()
        folds_list = fold_assignments if isinstance(fold_assignments, list) else fold_assignments.tolist()
        metrics = train_molformer_with_cv(
            data_csv, folds_list,
            model_name, model_dir
        )
        elapsed = time.time() - t0
        metrics['training_time_s'] = round(elapsed, 1)
        all_metrics[task_key] = metrics

        logger.info(f"  {model_name}: {elapsed:.0f}s")

        # Train final model and screen hub (with smart-skip)
        hub_csv = os.path.join(config.HUB_DIR, config.HUB_CLEAN_FILENAME)
        if os.path.exists(hub_csv):
            final_dir = os.path.join(model_dir, 'final')
            final_ckpt = os.path.join(final_dir, 'molformer_finetuned.pt')
            screen_path = os.path.join(config.SCREENING_DIR,
                                        f'molformer_ranked_{task_key}.csv')

            # Smart-skip: only train final model if checkpoint missing
            if os.path.exists(final_ckpt):
                logger.info(f"    Final model: SKIP (exists: {final_ckpt})")
                # Load existing model for screening if needed
                if not os.path.exists(screen_path):
                    logger.info(f"    Loading final model for screening...")
                    final_model = MoLFormerClassifier()
                    final_model.load(final_dir)
                else:
                    final_model = None
            else:
                final_model = train_final_model(data_csv, model_name,
                                                model_dir)

            # Smart-skip: only screen if output missing
            if os.path.exists(screen_path):
                logger.info(f"    Screening: SKIP (exists: {screen_path})")
            elif final_model is not None:
                screen_hub(final_model, hub_csv, screen_path, model_name)

            if final_model is not None:
                del final_model
            import torch
            if torch.cuda.is_available():
                torch.cuda.empty_cache()

    # Save metrics
    metrics_path = os.path.join(config.RESULTS_DIR,
                                'molformer_cv_metrics.json')
    with open(metrics_path, 'w') as f:
        json.dump(all_metrics, f, indent=2, default=str)
    logger.info(f"\n  Saved: {metrics_path}")

    # Summary table
    logger.info("\n" + "=" * 70)
    logger.info("  MoLFormer-XL CV Results Summary")
    logger.info("=" * 70)
    for task_key, m in all_metrics.items():
        roc = m.get('mean_roc_auc')
        roc_std = m.get('std_roc_auc')
        pr = m.get('mean_pr_auc')
        mcc = None
        if 'full_metrics_agg' in m:
            mcc = m['full_metrics_agg'].get('mean_mcc')
        roc_str = f"{roc:.4f} +/- {roc_std:.4f}" if roc else "FAILED"
        mcc_str = f"{mcc:.4f}" if mcc else "N/A"
        logger.info(f"  {task_key:<25} ROC-AUC={roc_str}  MCC={mcc_str}")

    # ---- NEW: Compute selectivity scores from raw prob files ----
    logger.info("\n" + "=" * 70)
    logger.info("  Computing MoLFormer selectivity scores...")
    logger.info("=" * 70)
    ranked_lists = compute_selectivity_scores()

    # ---- NEW: Generate Phase 3D figures ----
    logger.info("\n  Generating Phase 3D figures...")
    generate_phase3d_figures(all_metrics, ranked_lists)

    # ---- NEW: Quality report ----
    os.makedirs(config.REPORTS_DIR, exist_ok=True)
    report_path = os.path.join(config.REPORTS_DIR,
                               'phase3d_quality_report.json')
    quality_report = {
        'phase': '3D',
        'model': 'MoLFormer-XL',
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
            'n_folds': m.get('n_folds_completed'),
        }
    for rk, df_r in ranked_lists.items():
        quality_report['selectivity_summary'][rk] = {
            'n_compounds': len(df_r),
            'top_score': round(float(df_r['selectivity_score'].iloc[0]), 4),
            'mean_score': round(float(df_r['selectivity_score'].mean()), 4),
            'n_above_0.5': int((df_r['selectivity_score'] > 0.5).sum()),
        }
    with open(report_path, 'w') as f:
        json.dump(quality_report, f, indent=2)
    logger.info(f"  Saved: {report_path}")

    log_phase_end(logger, "Phase 3D: MoLFormer-XL Fine-Tuning", start_time)


# ===========================================================================
# Unit tests
# ===========================================================================
def run_tests():
    """Quick unit tests."""
    print("Running Phase 3D (MoLFormer) unit tests...")
    passed, failed = 0, 0

    def _assert(cond, msg):
        nonlocal passed, failed
        if cond:
            print(f"  [PASS] {msg}")
            passed += 1
        else:
            print(f"  [FAIL] {msg}")
            failed += 1

    # Test full_metrics module
    try:
        from utils.full_metrics import compute_full_metrics, aggregate_fold_metrics
        y_true = np.array([0, 0, 1, 1, 1, 0, 1, 0])
        y_prob = np.array([0.1, 0.2, 0.8, 0.9, 0.7, 0.3, 0.6, 0.4])
        m = compute_full_metrics(y_true, y_prob)
        _assert('roc_auc' in m, "full_metrics has roc_auc")
        _assert('mcc' in m, "full_metrics has mcc")
        _assert('f1_macro' in m, "full_metrics has f1_macro")
        _assert('sensitivity' in m, "full_metrics has sensitivity")
        _assert('specificity' in m, "full_metrics has specificity")
        _assert('brier_score' in m, "full_metrics has brier_score")
        _assert(0 <= m['roc_auc'] <= 1, f"roc_auc in range: {m['roc_auc']}")
        _assert(-1 <= m['mcc'] <= 1, f"mcc in range: {m['mcc']}")

        # Test aggregation
        agg = aggregate_fold_metrics([m, m])
        _assert('mean_roc_auc' in agg, "aggregation has mean_roc_auc")
        _assert('mean_mcc' in agg, "aggregation has mean_mcc")
    except ImportError:
        _assert(False, "full_metrics import")

    # Test MOLFORMER_PARAMS
    _assert(MOLFORMER_PARAMS['batch_size'] == 32, "batch_size=32")
    _assert(MOLFORMER_PARAMS['epochs'] == 20, "epochs=20")
    _assert(MOLFORMER_PARAMS['learning_rate'] == 1e-5, "lr=1e-5")

    print(f"Unit tests: {passed} passed, {failed} failed")


if __name__ == '__main__':
    if '--test' in sys.argv:
        run_tests()
    else:
        main()