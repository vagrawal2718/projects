#!/usr/bin/env python3
"""
19_interpretability.py -- Targeted interpretability for top candidates

For each model type, applies the appropriate interpretability method
to the top consensus candidates:

  RF:       Global feature importance (top Morgan FP bits mapped to
            substructures) + per-compound bit activation analysis
  D-MPNN:   Atom-level occlusion attribution (remove functional groups,
            measure prediction change)
  CheMeleon: Same occlusion approach as D-MPNN (uses Chemprop encoder)
  MoLFormer: Self-attention weight extraction from final transformer layer

Runs on top 15 consensus candidates only (not full Hub).
GPU recommended for D-MPNN/CheMeleon/MoLFormer but not required.

Outputs:
  results/interpret_rf_feature_importance.csv
  results/interpret_rf_top_bits.json
  results/interpret_occlusion_dmpnn.csv
  results/interpret_occlusion_chemeleon.csv
  results/interpret_molformer_attention.csv
  results/interpret_summary.json
  results/figures/interpret_*.png/pdf

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    April 2026
"""

import os, sys, json, time, warnings, pickle
import numpy as np
import pandas as pd

warnings.filterwarnings('ignore')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import config
from utils.logging_utils import setup_logging, log_phase_start, log_phase_end

logger = setup_logging('phase_interpret', log_dir=config.LOGS_DIR)

TOP_N = 15  # Number of consensus candidates to interpret


# ===================================================================
# Helper: load top consensus candidates
# ===================================================================

def load_top_candidates():
    """Load top consensus candidates for interpretation."""
    consensus_path = os.path.join(config.RESULTS_DIR,
                                  'candidate_consensus.csv')
    if not os.path.exists(consensus_path):
        logger.error("  candidate_consensus.csv not found")
        return None

    df = pd.read_csv(consensus_path)
    top = df.sort_values(['n_models', 'best_selectivity'],
                         ascending=[False, False]).head(TOP_N)
    logger.info(f"  Selected top {len(top)} candidates for interpretation")
    for _, r in top.iterrows():
        logger.info(f"    {str(r['name']):25s} n_models={r['n_models']} "
                    f"S={r['best_selectivity']:.3f}")
    return top


# ===================================================================
# 1. RF Feature Importance
# ===================================================================

def rf_feature_importance():
    """
    Extract global feature importance from trained RF models and map
    the most important Morgan FP bits to chemical substructures.
    """
    logger.info("\n" + "=" * 70)
    logger.info("  RF FEATURE IMPORTANCE")
    logger.info("=" * 70)

    from rdkit import Chem
    from rdkit.Chem import AllChem, Draw

    # Load RF model for E. coli (primary pathogen)
    rf_path = os.path.join(config.RF_DIR, 'rf_ecoli.pkl')
    if not os.path.exists(rf_path):
        logger.warning(f"  RF model not found: {rf_path}")
        return {}

    with open(rf_path, 'rb') as f:
        rf_model = pickle.load(f)

    importances = rf_model.feature_importances_  # 2048-element array
    logger.info(f"  RF E. coli model: {len(importances)} features")
    logger.info(f"  Total importance sum: {importances.sum():.4f}")

    # Top 30 most important bits
    top_indices = np.argsort(importances)[::-1][:30]
    top_importances = importances[top_indices]

    logger.info(f"\n  Top 30 Morgan FP bits (E. coli model):")
    logger.info(f"  {'Rank':>5} {'Bit':>6} {'Importance':>12} "
                f"{'Cumulative':>12}")
    logger.info("  " + "-" * 40)

    cum = 0
    bit_data = []
    for rank, (idx, imp) in enumerate(
            zip(top_indices, top_importances), 1):
        cum += imp
        logger.info(f"  {rank:>5} {idx:>6} {imp:>12.6f} {cum:>12.4f}")
        bit_data.append({
            'rank': rank,
            'bit_index': int(idx),
            'importance': round(float(imp), 6),
            'cumulative': round(float(cum), 4),
        })

    logger.info(f"\n  Top 30 bits explain {cum:.1%} of total importance")

    # Map bits to substructures using example molecules
    # Load top candidates to find which bits they activate
    top = load_top_candidates()
    if top is None:
        return {'bits': bit_data}

    # For each top candidate, compute Morgan FP with bitInfo
    logger.info(f"\n  Mapping top bits to substructures in top candidates:")
    bit_to_substructure = {}

    for _, row in top.iterrows():
        mol = Chem.MolFromSmiles(str(row['smiles']))
        if mol is None:
            continue

        bit_info = {}
        fp = AllChem.GetMorganFingerprintAsBitVect(
            mol, radius=2, nBits=2048, bitInfo=bit_info)

        for bit_idx in top_indices[:20]:
            if bit_idx in bit_info:
                # bit_info[bit] = list of (atom_center, radius) tuples
                for atom_center, radius in bit_info[bit_idx]:
                    if bit_idx not in bit_to_substructure:
                        bit_to_substructure[bit_idx] = []
                    # Get the atoms in this substructure
                    env = Chem.FindAtomEnvironmentOfRadiusN(
                        mol, radius, atom_center)
                    atoms = set()
                    for bond_idx in env:
                        bond = mol.GetBondWithIdx(bond_idx)
                        atoms.add(bond.GetBeginAtomIdx())
                        atoms.add(bond.GetEndAtomIdx())
                    atoms.add(atom_center)

                    # Get SMARTS for this environment
                    try:
                        submol = Chem.PathToSubmol(mol, list(env))
                        smarts = Chem.MolToSmarts(submol)
                    except Exception:
                        smarts = f"atom_{atom_center}_r{radius}"

                    bit_to_substructure[bit_idx].append({
                        'compound': str(row['name']),
                        'atom_center': int(atom_center),
                        'radius': int(radius),
                        'smarts': smarts,
                        'n_atoms': len(atoms),
                    })

    # Log substructure mappings
    logger.info(f"\n  Substructure examples for top bits:")
    for bit_idx in top_indices[:20]:
        imp = importances[bit_idx]
        if bit_idx in bit_to_substructure:
            examples = bit_to_substructure[bit_idx][:3]
            ex_str = "; ".join(
                f"{e['compound']}: {e['smarts']}" for e in examples)
            logger.info(f"    Bit {bit_idx:>5} (imp={imp:.5f}): {ex_str}")
        else:
            logger.info(f"    Bit {bit_idx:>5} (imp={imp:.5f}): "
                        f"not active in top candidates")

    # Per-compound analysis: which important bits are active?
    logger.info(f"\n  Per-compound important bit activation:")
    compound_bits = []
    for _, row in top.iterrows():
        mol = Chem.MolFromSmiles(str(row['smiles']))
        if mol is None:
            continue

        fp = AllChem.GetMorganFingerprintAsBitVect(
            mol, radius=2, nBits=2048)
        active_important = []
        total_importance_active = 0
        for bit_idx in top_indices[:50]:
            if fp[int(bit_idx)]:
                active_important.append(int(bit_idx))
                total_importance_active += importances[bit_idx]

        compound_bits.append({
            'name': str(row['name']),
            'smiles': str(row['smiles']),
            'n_active_top50': len(active_important),
            'total_importance': round(float(total_importance_active), 4),
            'active_bits': active_important[:10],
        })

        logger.info(f"    {str(row['name']):25s}: "
                    f"{len(active_important)} of top-50 bits active, "
                    f"imp_sum={total_importance_active:.4f}")

    # Save
    bit_df = pd.DataFrame(bit_data)
    bit_path = os.path.join(config.RESULTS_DIR,
                            'interpret_rf_feature_importance.csv')
    bit_df.to_csv(bit_path, index=False)
    logger.info(f"\n  Saved: {bit_path}")

    results = {
        'bits': bit_data,
        'bit_to_substructure': {
            str(k): v for k, v in bit_to_substructure.items()},
        'compound_bits': compound_bits,
        'top30_cumulative': round(float(cum), 4),
    }

    results_path = os.path.join(config.RESULTS_DIR,
                                'interpret_rf_top_bits.json')
    with open(results_path, 'w') as f:
        json.dump(results, f, indent=2, default=str)
    logger.info(f"  Saved: {results_path}")

    return results


# ===================================================================
# 2. D-MPNN Occlusion Attribution
# ===================================================================

def dmpnn_occlusion(top_candidates):
    """
    For each top candidate, systematically remove functional groups
    and measure the change in D-MPNN prediction (P_ecoli).
    Uses chemprop CLI for prediction (same as training pipeline).
    """
    logger.info("\n" + "=" * 70)
    logger.info("  D-MPNN OCCLUSION ATTRIBUTION")
    logger.info("=" * 70)

    import subprocess, tempfile
    from rdkit import Chem
    from rdkit.Chem import BRICS

    # Find model path
    model_dir = os.path.join(config.MODELS_DIR, 'dmpnn', 'ecoli')
    logger.info(f"  Searching for model in: {model_dir}")
    model_path = None
    for candidate in ['final/model_0/best.pt',
                       'final/model_0/model.pt',
                       'fold_0/model_0/best.pt']:
        p = os.path.join(model_dir, candidate)
        if os.path.exists(p):
            model_path = p
            logger.info(f"  Found: {model_path}")
            break

    if model_path is None:
        logger.warning(f"  No D-MPNN model found")
        return {}

    # Prediction helper using CLI
    def predict_smiles_batch(smiles_list):
        """Predict via chemprop CLI. Returns list of probabilities."""
        try:
            with tempfile.NamedTemporaryFile(mode='w', suffix='.csv',
                                              delete=False) as f:
                f.write('smiles\n')
                for smi in smiles_list:
                    f.write(f'{smi}\n')
                input_csv = f.name

            output_csv = input_csv.replace('.csv', '_preds.csv')

            cmd = [
                'chemprop', 'predict',
                '--test-path', input_csv,
                '--model-path', model_path,
                '--preds-path', output_csv,
                '--smiles-column', 'smiles',
            ]
            result = subprocess.run(cmd, capture_output=True, text=True,
                                    timeout=120)

            if os.path.exists(output_csv):
                preds_df = pd.read_csv(output_csv)
                # Find the prediction column (not 'smiles')
                pred_cols = [c for c in preds_df.columns
                             if c != 'smiles']
                if pred_cols:
                    probs = preds_df[pred_cols[0]].values.tolist()
                    # Cleanup
                    os.unlink(input_csv)
                    os.unlink(output_csv)
                    return probs

            logger.warning(f"    CLI prediction failed: "
                           f"{result.stderr[:200]}")
            os.unlink(input_csv)
            return None
        except Exception as e:
            logger.warning(f"    Batch prediction failed: {e}")
            return None

    # Test CLI works
    test_preds = predict_smiles_batch(['CCO', 'c1ccccc1'])
    if test_preds is None:
        logger.warning("  CLI prediction test failed, skipping D-MPNN")
        return {}
    logger.info(f"  CLI prediction test OK: {test_preds}")

    # Build all SMILES to predict (originals + fragments)
    # First pass: collect all fragments
    compound_data = []
    for _, row in top_candidates.iterrows():
        name = str(row['name'])
        smiles = str(row['smiles'])
        mol = Chem.MolFromSmiles(smiles)
        if mol is None:
            continue

        try:
            fragments = list(BRICS.BRICSDecompose(mol))
        except Exception:
            fragments = []

        # Clean fragments
        clean_frags = []
        seen = set()
        for frag_smi in fragments[:15]:
            if frag_smi in seen:
                continue
            seen.add(frag_smi)
            clean_frag = frag_smi
            for dummy in ['[1*]', '[2*]', '[3*]', '[4*]', '[5*]',
                          '[6*]', '[7*]', '[8*]', '[9*]',
                          '[10*]', '[11*]', '[12*]', '[13*]',
                          '[14*]', '[15*]', '[16*]']:
                clean_frag = clean_frag.replace(dummy, '[H]')
            if Chem.MolFromSmiles(clean_frag) is not None:
                clean_frags.append((frag_smi, clean_frag))

        compound_data.append({
            'name': name,
            'smiles': smiles,
            'fragments': clean_frags,
        })

    # Build one big batch of all SMILES
    all_smiles = []
    smiles_map = {}  # index -> (compound_idx, 'base'|frag_idx)

    for ci, comp in enumerate(compound_data):
        idx = len(all_smiles)
        all_smiles.append(comp['smiles'])
        smiles_map[idx] = (ci, 'base')

        for fi, (orig_frag, clean_frag) in enumerate(comp['fragments']):
            idx = len(all_smiles)
            all_smiles.append(clean_frag)
            smiles_map[idx] = (ci, fi)

    logger.info(f"  Predicting {len(all_smiles)} SMILES in one batch "
                f"({len(compound_data)} compounds + fragments)...")

    all_preds = predict_smiles_batch(all_smiles)
    if all_preds is None:
        logger.warning("  Batch prediction failed")
        return {}

    logger.info(f"  Got {len(all_preds)} predictions")

    # Parse results
    results = []
    for ci, comp in enumerate(compound_data):
        base_idx = [k for k, v in smiles_map.items()
                    if v == (ci, 'base')][0]
        base_p = all_preds[base_idx]

        logger.info(f"\n    {comp['name']}:")
        logger.info(f"      Base P(ecoli) = {base_p:.4f}")

        attributions = []
        for fi, (orig_frag, clean_frag) in enumerate(comp['fragments']):
            frag_idx = [k for k, v in smiles_map.items()
                        if v == (ci, fi)][0]
            frag_p = all_preds[frag_idx]
            attribution = base_p - frag_p

            attributions.append({
                'fragment': orig_frag,
                'fragment_p': round(float(frag_p), 4),
                'attribution': round(float(attribution), 4),
            })

        attributions.sort(key=lambda x: abs(x['attribution']),
                          reverse=True)

        for attr in attributions[:5]:
            logger.info(f"      Fragment: {attr['fragment'][:40]:40s} "
                        f"P={attr['fragment_p']:.4f} "
                        f"attr={attr['attribution']:+.4f}")

        results.append({
            'name': comp['name'],
            'smiles': comp['smiles'],
            'base_p_ecoli': round(float(base_p), 4),
            'attributions': attributions,
        })

    # Save
    if results:
        save_path = os.path.join(config.RESULTS_DIR,
                                 'interpret_occlusion_dmpnn.json')
        with open(save_path, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        logger.info(f"\n  Saved: {save_path}")

    return results


# ===================================================================
# 3. CheMeleon Occlusion (same approach as D-MPNN)
# ===================================================================

def chemeleon_occlusion(top_candidates):
    """Same occlusion approach but using CheMeleon frozen model."""
    logger.info("\n" + "=" * 70)
    logger.info("  CheMeleon OCCLUSION ATTRIBUTION")
    logger.info("=" * 70)

    try:
        import torch
        from rdkit import Chem
        from rdkit.Chem import BRICS
    except ImportError:
        logger.warning("  Required packages not available, skipping")
        return {}

    # Import predict_chemeleon from training script
    try:
        sys.path.insert(0, os.path.join(config.PROJECT_DIR, 'scripts'))
        from importlib import import_module
        chem_module = import_module('11_train_chemeleon_frozen')
        predict_chemeleon_fn = chem_module.predict_chemeleon
        logger.info("  Imported predict_chemeleon from "
                    "11_train_chemeleon_frozen.py")
    except Exception as e:
        logger.warning(f"  Could not import predict_chemeleon: {e}")
        return {}

    # Find pretrained CheMeleon encoder weights
    from pathlib import Path
    mp_path = str(Path.home() / ".chemprop" / "chemeleon_mp.pt")
    if not os.path.exists(mp_path):
        logger.info(f"  chemeleon_mp.pt not found at {mp_path}")
        logger.info("  Trying to download...")
        try:
            chem_module.ensure_chemeleon_weights()
            if not os.path.exists(mp_path):
                logger.warning("  Download failed, skipping")
                return {'status': 'skipped',
                        'reason': 'chemeleon_mp.pt not available'}
        except Exception as e:
            logger.warning(f"  Download failed: {e}")
            return {'status': 'skipped',
                    'reason': str(e)}

    logger.info(f"  Pretrained encoder: {mp_path}")

    # Find saved model state for E. coli
    model_state_path = os.path.join(config.MODELS_DIR,
                                     'chemeleon_frozen', 'ecoli',
                                     'final_model.pt')
    if not os.path.exists(model_state_path):
        logger.warning(f"  Model state not found: {model_state_path}")
        return {}

    logger.info(f"  Model state: {model_state_path}")

    # Prediction helper using training script's function
    def predict_smiles(smiles_list):
        try:
            probs = predict_chemeleon_fn(mp_path, model_state_path,
                                        smiles_list)
            return probs.tolist() if hasattr(probs, 'tolist') else list(probs)
        except Exception as e:
            logger.warning(f"    Prediction failed: {e}")
            return None

    # Test with first candidate
    test_smi = str(top_candidates.iloc[0]['smiles'])
    test_pred = predict_smiles([test_smi])
    if test_pred is None:
        logger.warning("  Test prediction failed, skipping CheMeleon")
        return {}
    logger.info(f"  Test prediction OK: P={test_pred[0]:.4f}")

    # For each candidate, do fragment removal
    results = []
    for _, row in top_candidates.iterrows():
        name = str(row['name'])
        smiles = str(row['smiles'])
        mol = Chem.MolFromSmiles(smiles)
        if mol is None:
            continue

        logger.info(f"\n    {name}:")

        # Get base prediction
        base_preds = predict_smiles([smiles])
        if base_preds is None or len(base_preds) == 0:
            logger.info(f"      Base prediction failed, skipping")
            continue
        base_p = float(base_preds[0])
        logger.info(f"      Base P(ecoli) = {base_p:.4f}")

        # Fragment using BRICS decomposition
        try:
            fragments = list(BRICS.BRICSDecompose(mol))
        except Exception:
            fragments = []

        attributions = []
        seen_frags = set()

        for frag_smi in fragments[:15]:
            if frag_smi in seen_frags:
                continue
            seen_frags.add(frag_smi)

            # Clean BRICS dummy atoms
            clean_frag = frag_smi
            for dummy in ['[1*]', '[2*]', '[3*]', '[4*]', '[5*]',
                          '[6*]', '[7*]', '[8*]', '[9*]',
                          '[10*]', '[11*]', '[12*]', '[13*]',
                          '[14*]', '[15*]', '[16*]']:
                clean_frag = clean_frag.replace(dummy, '[H]')

            frag_mol = Chem.MolFromSmiles(clean_frag)
            if frag_mol is None:
                continue

            frag_preds = predict_smiles([clean_frag])
            if frag_preds is None or len(frag_preds) == 0:
                continue

            frag_p = float(frag_preds[0])
            attribution = base_p - frag_p

            attributions.append({
                'fragment': frag_smi,
                'fragment_p': round(frag_p, 4),
                'attribution': round(attribution, 4),
            })

        attributions.sort(key=lambda x: abs(x['attribution']),
                          reverse=True)

        for attr in attributions[:5]:
            logger.info(f"      Fragment: {attr['fragment'][:40]:40s} "
                        f"P={attr['fragment_p']:.4f} "
                        f"attr={attr['attribution']:+.4f}")

        results.append({
            'name': name,
            'smiles': smiles,
            'base_p_ecoli': round(base_p, 4),
            'attributions': attributions,
        })

    # Save
    if results:
        save_path = os.path.join(config.RESULTS_DIR,
                                 'interpret_occlusion_chemeleon.json')
        with open(save_path, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        logger.info(f"\n  Saved: {save_path}")

    return results


# ===================================================================
# 4. MoLFormer Attention Extraction
# ===================================================================

def molformer_attention(top_candidates):
    """Extract self-attention weights from MoLFormer for top candidates."""
    logger.info("\n" + "=" * 70)
    logger.info("  MoLFormer ATTENTION WEIGHTS")
    logger.info("=" * 70)

    try:
        import torch
        from transformers import AutoTokenizer, AutoModel
    except ImportError:
        logger.warning("  transformers not available, skipping")
        return {}

    # Find the finetuned MoLFormer model
    model_dir = os.path.join(config.MODELS_DIR, 'molformer', 'ecoli')
    model_path = None
    for root, dirs, files in os.walk(model_dir):
        for f in files:
            if f == 'molformer_finetuned.pt':
                model_path = os.path.join(root, f)
                break
        if model_path:
            break

    if model_path is None:
        logger.warning(f"  MoLFormer model not found in {model_dir}")
        return {}

    logger.info(f"  Loading MoLFormer from: {model_path}")

    try:
        import torch

        # Load tokenizer
        tokenizer = AutoTokenizer.from_pretrained(
            "ibm/MoLFormer-XL-both-10pct",
            trust_remote_code=True,
            cache_dir=os.path.join(config.PROJECT_DIR, '.hf_cache'))

        # Load base model with attention output
        base_model = AutoModel.from_pretrained(
            "ibm/MoLFormer-XL-both-10pct",
            trust_remote_code=True,
            output_attentions=True,
            cache_dir=os.path.join(config.PROJECT_DIR, '.hf_cache'))

        # Load our finetuned weights.
        # Checkpoint structure (from scripts/10_train_molformer.py):
        #   { 'encoder_state': <AutoModel state_dict>,
        #     'classifier_state': <classifier head state_dict> }
        # For attention extraction we need only the encoder.
        state = torch.load(model_path, map_location='cpu', weights_only=False)
        if isinstance(state, dict) and 'encoder_state' in state:
            missing, unexpected = base_model.load_state_dict(
                state['encoder_state'], strict=False)
            if missing or unexpected:
                logger.info(f"  Loaded finetuned encoder weights "
                            f"(missing={len(missing)}, unexpected={len(unexpected)})")
            else:
                logger.info("  Loaded finetuned encoder weights (exact match)")
        else:
            logger.warning("  Checkpoint missing 'encoder_state' key; "
                           "using pretrained weights")

        base_model.eval()

    except Exception as e:
        logger.warning(f"  Failed to load MoLFormer: {e}")
        return {}

    # Extract attention for each candidate
    results = []
    for _, row in top_candidates.iterrows():
        name = str(row['name'])
        smiles = str(row['smiles'])

        try:
            inputs = tokenizer(smiles, return_tensors='pt',
                               padding=True, truncation=True,
                               max_length=512)
            with torch.no_grad():
                outputs = base_model(**inputs)

            # Get attention from last layer
            # Shape: (1, n_heads, seq_len, seq_len)
            if hasattr(outputs, 'attentions') and outputs.attentions:
                last_attention = outputs.attentions[-1]
                # Average across heads
                avg_attention = last_attention.mean(dim=1).squeeze(0)
                # Per-token importance = sum of attention received
                token_importance = avg_attention.sum(dim=0).numpy()

                # Map back to SMILES characters
                tokens = tokenizer.convert_ids_to_tokens(
                    inputs['input_ids'][0])

                token_data = []
                for tok, imp in zip(tokens, token_importance):
                    if tok not in ['[CLS]', '[SEP]', '[PAD]']:
                        token_data.append({
                            'token': tok,
                            'attention': round(float(imp), 4),
                        })

                # Normalize
                total_att = sum(t['attention'] for t in token_data)
                if total_att > 0:
                    for t in token_data:
                        t['normalized'] = round(
                            t['attention'] / total_att, 4)

                # Top-5 tokens
                token_data.sort(key=lambda x: x['attention'],
                                reverse=True)
                top5 = token_data[:5]

                logger.info(f"    {name:25s}: top tokens = "
                            + ", ".join(f"{t['token']}({t['normalized']:.3f})"
                                        for t in top5))

                results.append({
                    'name': name,
                    'smiles': smiles,
                    'n_tokens': len(token_data),
                    'top_tokens': top5,
                    'all_tokens': token_data,
                })
            else:
                logger.info(f"    {name:25s}: no attention output")

        except Exception as e:
            logger.info(f"    {name:25s}: failed ({str(e)[:50]})")

    # Save
    if results:
        save_path = os.path.join(config.RESULTS_DIR,
                                 'interpret_molformer_attention.json')
        with open(save_path, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        logger.info(f"\n  Saved: {save_path}")

    return results


# ===================================================================
# 5. Figures
# ===================================================================

def generate_figures(rf_results):
    """Generate interpretability figures."""
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

    if not rf_results or 'bits' not in rf_results:
        return

    # ---- Figure 1: RF Feature Importance Bar Chart ----
    bits = rf_results['bits'][:20]
    fig, ax = plt.subplots(figsize=(10, 6))
    x = range(len(bits))
    ax.bar(x, [b['importance'] for b in bits], color='#0072B2',
           alpha=0.8, edgecolor='none')
    ax.set_xticks(x)
    ax.set_xticklabels([f"Bit {b['bit_index']}" for b in bits],
                       rotation=45, ha='right', fontsize=8)
    ax.set_xlabel('Morgan Fingerprint Bit')
    ax.set_ylabel('Gini Importance')
    ax.set_title('RF E. coli Model: Top 20 Most Important Features')

    # Add cumulative line
    ax2 = ax.twinx()
    ax2.plot(x, [b['cumulative'] for b in bits], 'r-o', markersize=4,
             label='Cumulative')
    ax2.set_ylabel('Cumulative Importance', color='red')
    ax2.tick_params(axis='y', labelcolor='red')

    plt.tight_layout()
    path = os.path.join(config.FIGURES_DIR,
                        'interpret_rf_importance')
    fig.savefig(path + '.png', dpi=DPI, bbox_inches='tight')
    fig.savefig(path + '.pdf', bbox_inches='tight')
    plt.close(fig)
    logger.info(f"  Figure: interpret_rf_importance")

    # ---- Figure 2: Per-compound bit activation ----
    if 'compound_bits' in rf_results:
        cb = rf_results['compound_bits']
        fig, ax = plt.subplots(figsize=(10, 6))
        names = [c['name'][:20] for c in cb]
        vals = [c['total_importance'] for c in cb]
        counts = [c['n_active_top50'] for c in cb]

        y = range(len(names))
        bars = ax.barh(y, vals, color='#0072B2', alpha=0.8)
        ax.set_yticks(y)
        ax.set_yticklabels(names, fontsize=9)
        ax.set_xlabel('Sum of Active Top-50 Bit Importances')
        ax.set_title('RF: Feature Importance Mass per Candidate')

        # Add count labels
        for i, (v, c) in enumerate(zip(vals, counts)):
            ax.text(v + 0.001, i, f'{c} bits', va='center', fontsize=8)

        ax.invert_yaxis()
        plt.tight_layout()
        path = os.path.join(config.FIGURES_DIR,
                            'interpret_rf_per_compound')
        fig.savefig(path + '.png', dpi=DPI, bbox_inches='tight')
        fig.savefig(path + '.pdf', bbox_inches='tight')
        plt.close(fig)
        logger.info(f"  Figure: interpret_rf_per_compound")


# ===================================================================
# Main
# ===================================================================

def main():
    t_start = log_phase_start(logger,
                              "Phase C: Targeted Interpretability")

    os.makedirs(config.RESULTS_DIR, exist_ok=True)
    os.makedirs(config.FIGURES_DIR, exist_ok=True)

    top = load_top_candidates()
    if top is None:
        logger.error("  No candidates to interpret")
        return

    # --- RF Feature Importance (always works) ---
    rf_results = {}
    try:
        rf_results = rf_feature_importance()
    except Exception as e:
        logger.warning(f"  RF interpretation failed: {e}")
        import traceback; traceback.print_exc()

    # --- D-MPNN Occlusion ---
    dmpnn_results = {}
    try:
        dmpnn_results = dmpnn_occlusion(top)
    except Exception as e:
        logger.warning(f"  D-MPNN interpretation failed: {e}")
        import traceback; traceback.print_exc()

    # --- D-MPNN RDKit Occlusion ---
    dmpnn_rdkit_results = {}
    try:
        logger.info("\n" + "=" * 70)
        logger.info("  D-MPNN+RDKit OCCLUSION ATTRIBUTION")
        logger.info("=" * 70)
        rdkit_model_dir = os.path.join(config.MODELS_DIR, 'dmpnn_rdkit', 'ecoli')
        rdkit_model_path = None
        for cand in ['fold_0/model_0/best.pt', 'final/model_0/best.pt']:
            p = os.path.join(rdkit_model_dir, cand)
            if os.path.exists(p):
                rdkit_model_path = p
                break
        if rdkit_model_path:
            logger.info(f"  Found model: {rdkit_model_path}")
            logger.info("  Using same BRICS occlusion as D-MPNN (with --molecule-featurizers)")
            # Predict helper with RDKit features
            import subprocess, tempfile
            def predict_rdkit(smiles_list):
                with tempfile.NamedTemporaryFile(mode='w', suffix='.csv', delete=False) as f:
                    f.write('smiles\n')
                    for smi in smiles_list:
                        f.write(f'{smi}\n')
                    input_csv = f.name
                output_csv = input_csv.replace('.csv', '_preds.csv')
                cmd = ['chemprop', 'predict',
                       '--test-path', input_csv,
                       '--model-path', rdkit_model_path,
                       '--preds-path', output_csv,
                       '--smiles-column', 'smiles',
                       '--molecule-featurizers', 'v1_rdkit_2d_normalized']
                env = os.environ.copy()
                env['SLURM_NTASKS'] = '1'
                env['SLURM_NTASKS_PER_NODE'] = '1'
                env['SLURM_JOB_NAME'] = 'bash'
                result = subprocess.run(cmd, capture_output=True, text=True, env=env)
                if os.path.exists(output_csv):
                    preds_df = pd.read_csv(output_csv)
                    pred_cols = [c for c in preds_df.columns if c != 'smiles']
                    if pred_cols:
                        probs = preds_df[pred_cols[0]].values.tolist()
                        os.unlink(input_csv)
                        os.unlink(output_csv)
                        return probs
                os.unlink(input_csv)
                return None

            from rdkit import Chem
            from rdkit.Chem import BRICS
            rdkit_occlusion = []
            for _, row in top.iterrows():
                smi = row['smiles']
                name = row.get('name', smi[:20])
                mol = Chem.MolFromSmiles(smi)
                if mol is None:
                    continue
                base_prob = predict_rdkit([smi])
                if base_prob is None:
                    continue
                base_p = base_prob[0]
                frags = list(BRICS.BRICSDecompose(mol))
                frag_results = []
                if frags and len(frags) > 1:
                    frag_probs = predict_rdkit(frags)
                    if frag_probs:
                        for frag_smi, fp in zip(frags, frag_probs):
                            frag_results.append({
                                'fragment': frag_smi,
                                'p_fragment': round(fp, 4),
                                'delta': round(fp - base_p, 4),
                            })
                rdkit_occlusion.append({
                    'name': str(name),
                    'smiles': smi,
                    'base_p_ecoli': round(base_p, 4),
                    'n_fragments': len(frags),
                    'fragments': frag_results,
                })
                logger.info(f"    {str(name)[:25]:25s} base_P={base_p:.4f} "
                            f"frags={len(frags)}")
            dmpnn_rdkit_results = rdkit_occlusion
            # Save
            rdkit_occ_path = os.path.join(config.RESULTS_DIR,
                                          'interpret_occlusion_dmpnn_rdkit.json')
            with open(rdkit_occ_path, 'w') as f:
                json.dump(rdkit_occlusion, f, indent=2)
            logger.info(f"  Saved: {rdkit_occ_path}")
        else:
            logger.warning("  No D-MPNN+RDKit model found")
    except Exception as e:
        logger.warning(f"  D-MPNN RDKit interpretation failed: {e}")
        import traceback; traceback.print_exc()

    # --- CheMeleon Occlusion ---
    chemeleon_results = {}
    try:
        chemeleon_results = chemeleon_occlusion(top)
    except Exception as e:
        logger.warning(f"  CheMeleon interpretation failed: {e}")
        import traceback; traceback.print_exc()

    # --- MoLFormer Attention ---
    molformer_results = {}
    try:
        molformer_results = molformer_attention(top)
    except Exception as e:
        logger.warning(f"  MoLFormer interpretation failed: {e}")
        import traceback; traceback.print_exc()

    # --- Figures ---
    logger.info("\n  Generating figures...")
    try:
        generate_figures(rf_results)
    except Exception as e:
        logger.warning(f"  Figure generation failed: {e}")
        import traceback; traceback.print_exc()

    # --- Summary ---
    report = {
        'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
        'n_candidates': TOP_N,
        'rf': {
            'status': 'complete' if rf_results else 'failed',
            'n_bits_analyzed': len(rf_results.get('bits', [])),
            'top30_cumulative': rf_results.get('top30_cumulative', 0),
        },
        'dmpnn': {
            'status': 'complete' if dmpnn_results else 'skipped',
            'n_compounds': len(dmpnn_results) if isinstance(
                dmpnn_results, list) else 0,
        },
        'chemeleon': {
            'status': ('complete' if isinstance(chemeleon_results, list)
                       and len(chemeleon_results) > 0
                       else chemeleon_results.get('status', 'skipped')
                       if isinstance(chemeleon_results, dict)
                       else 'skipped'),
            'n_compounds': (len(chemeleon_results)
                            if isinstance(chemeleon_results, list) else 0),
        },
        'molformer': {
            'status': 'complete' if molformer_results else 'skipped',
            'n_compounds': len(molformer_results) if isinstance(
                molformer_results, list) else 0,
        },
        'dmpnn_rdkit': {
            'status': 'complete' if dmpnn_rdkit_results else 'skipped',
            'n_compounds': len(dmpnn_rdkit_results) if isinstance(
                dmpnn_rdkit_results, list) else 0,
        },
    }

    report_path = os.path.join(config.RESULTS_DIR,
                               'interpret_summary.json')
    with open(report_path, 'w') as f:
        json.dump(report, f, indent=2, default=str)
    logger.info(f"\n  Saved: {report_path}")

    # --- Print summary ---
    logger.info("\n" + "=" * 70)
    logger.info("  INTERPRETABILITY SUMMARY")
    logger.info("=" * 70)
    logger.info(f"  RF:        {report['rf']['status']} "
                f"({report['rf']['n_bits_analyzed']} bits, "
                f"top-30 explains "
                f"{report['rf']['top30_cumulative']:.1%})")
    logger.info(f"  D-MPNN:    {report['dmpnn']['status']}")
    logger.info(f"  CheMeleon: {report['chemeleon']['status']} "
                f"({report['chemeleon']['n_compounds']} compounds)")
    logger.info(f"  MoLFormer: {report['molformer']['status']}")
    logger.info(f"  D-MPNN+RDKit: {report['dmpnn_rdkit']['status']} "
                f"({report['dmpnn_rdkit']['n_compounds']} compounds)")
    logger.info("=" * 70)

    log_phase_end(logger, "Phase C: Interpretability", t_start)


if __name__ == '__main__':
    main()