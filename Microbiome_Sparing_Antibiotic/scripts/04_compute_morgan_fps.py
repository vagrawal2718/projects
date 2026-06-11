#!/usr/bin/env python3
"""
04_compute_morgan_fps.py -- Phase 2: Feature Engineering

Computes Morgan fingerprints (ECFP4, 2048-bit) for the RF pipeline and
generates scaffold-based 5-fold CV splits shared by BOTH pipelines.

Processes all 6 datasets from Phase 1:
  - 4 pathogen CSVs (ChEMBL)
  - 1 Maier commensal harm CSV
  - 1 Drug Repurposing Hub CSV (screening library)

Outputs:
  - data/features/morgan_{dataset}.npz  (sparse fingerprint matrices)
  - data/splits/{dataset}_scaffold_folds.pkl  (fold assignments)
  - results/figures/phase2_*.pdf
  - results/reports/phase2_quality_report.json

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import os, sys, json, time, logging, warnings
import numpy as np
import pandas as pd
from scipy import sparse

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)

import config
from utils.scaffold_split import generate_scaffold_folds, save_folds, scaffold_split_summary
from utils.logging_utils import (
    setup_logging, log_phase_start, log_phase_end,
    log_dataframe_summary, save_checkpoint, load_checkpoint,
)
from utils.viz_utils import setup_publication_style, save_figure, COLORS

warnings.filterwarnings('ignore')
logger = setup_logging('phase2', log_dir=config.LOGS_DIR)


def compute_morgan_fingerprints(smiles_list, radius=config.MORGAN_RADIUS, n_bits=config.MORGAN_NBITS):
    """Compute Morgan FPs. Returns (sparse_matrix, valid_indices, n_failed)."""
    _F = "04_compute_morgan_fps.py:compute_morgan_fingerprints"
    from rdkit import Chem
    from rdkit.Chem import rdFingerprintGenerator

    logger.info(f"  [{_F}] Computing Morgan FPs for {len(smiles_list)} SMILES "
                f"(radius={radius}, nBits={n_bits})...")

    # Create generator ONCE (new API, no deprecation warnings)
    morgan_gen = rdFingerprintGenerator.GetMorganGenerator(radius=radius, fpSize=n_bits)

    fps, valid_idx, n_failed = [], [], 0
    from tqdm import tqdm
    for i, smi in enumerate(tqdm(smiles_list, desc="  Computing Morgan FPs", unit=" mol")):
        try:
            mol = Chem.MolFromSmiles(smi)
            if mol is None:
                n_failed += 1
                if n_failed <= 3:
                    logger.debug(f"  [{_F}] Row {i}: RDKit parse returned None for "
                                 f"SMILES=\'{str(smi)[:60]}\'")
                continue
            fp = morgan_gen.GetFingerprintAsNumPy(mol)
            fps.append(fp.astype(np.int8))
            valid_idx.append(i)
        except Exception as e:
            n_failed += 1
            if n_failed <= 5:
                logger.warning(f"  [{_F}] Row {i}: {type(e).__name__}: {e} for "
                               f"SMILES=\'{str(smi)[:60]}\'")


    try:
        matrix = sparse.csr_matrix(np.array(fps)) if fps else sparse.csr_matrix((0, n_bits))
    except MemoryError:
        logger.error(f"  [{_F}] MEMORY ERROR: Cannot create {len(fps)}x{n_bits} matrix")
        logger.error(f"  [{_F}] ACTION: Reduce dataset size or request more memory in SLURM (--mem-per-cpu)")
        raise

    logger.info(f"  [{_F}] Done: {len(valid_idx)} valid, {n_failed} failed, "
                f"matrix shape={matrix.shape}")
    return matrix, valid_idx, n_failed


def process_dataset(name, csv_path, smiles_col='smiles', compute_splits=True):
    """Compute Morgan FPs and optionally scaffold splits for one dataset.

    Checks local shared dir and Google Drive before recomputing.
    Saves results to both local and Drive.
    """
    report = {'dataset': name}
    logger.info(f"\n  Processing: {name} from {csv_path}")

    if not os.path.exists(csv_path):
        logger.error(f"  File not found: {csv_path}")
        report['status'] = 'FILE_NOT_FOUND'
        return report

    df = pd.read_csv(csv_path)
    report['total_rows'] = len(df)
    smiles_list = df[smiles_col].tolist()

    fp_path = os.path.join(config.FEATURES_DIR, f'morgan_{name}.npz')
    idx_path = os.path.join(config.FEATURES_DIR, f'morgan_{name}_indices.json')
    split_path = os.path.join(config.SPLITS_DIR, f'{name}_scaffold_folds.pkl') if compute_splits else None

    # ---- Check if already computed (local shared dir) ----
    if os.path.exists(fp_path) and os.path.exists(idx_path):
        try:
            fp_matrix = sparse.load_npz(fp_path)
            with open(idx_path) as f:
                idx_data = json.load(f)
            valid_idx = idx_data['valid_indices']
            # Validate row count matches
            if fp_matrix.shape[0] == len(valid_idx) and fp_matrix.shape[0] > 0:
                logger.info(f"  FPs already computed: {fp_path} ({fp_matrix.shape[0]} x {fp_matrix.shape[1]})")
                report.update({
                    'valid_fps': len(valid_idx), 'failed_fps': len(smiles_list) - len(valid_idx),
                    'matrix_shape': list(fp_matrix.shape), 'status': 'CACHED_LOCAL',
                })
                # Still need splits
                if compute_splits and not os.path.exists(split_path):
                    _compute_and_save_splits(smiles_list, split_path, report)
                elif compute_splits and os.path.exists(split_path):
                    report['scaffold_splits'] = {'status': 'cached'}
                    logger.info(f"  Splits already computed: {split_path}")
                report['status'] = 'OK'
                return report
        except Exception as e:
            logger.debug(f"  Cache load failed: {e}, recomputing")

    # ---- Check Google Drive for cached FPs ----
    try:
        from utils.gdrive_backup import get_data_manager
        dm = get_data_manager()
        fp_name = f'morgan_{name}.npz'
        idx_name = f'morgan_{name}_indices.json'
        restored_fp = dm.resolve(fp_name, config.FEATURES_DIR)
        restored_idx = dm.resolve(idx_name, config.FEATURES_DIR)
        if restored_fp and restored_idx:
            fp_matrix = sparse.load_npz(restored_fp)
            with open(restored_idx) as f:
                idx_data = json.load(f)
            valid_idx = idx_data['valid_indices']
            if fp_matrix.shape[0] == len(valid_idx) and fp_matrix.shape[0] > 0:
                logger.info(f"  FPs restored from Drive: {fp_name} ({fp_matrix.shape[0]} x {fp_matrix.shape[1]})")
                report.update({
                    'valid_fps': len(valid_idx), 'failed_fps': len(smiles_list) - len(valid_idx),
                    'matrix_shape': list(fp_matrix.shape), 'status': 'CACHED_DRIVE',
                })
                if compute_splits:
                    split_name = f'{name}_scaffold_folds.pkl'
                    dm.resolve(split_name, config.SPLITS_DIR)
                    if os.path.exists(split_path):
                        report['scaffold_splits'] = {'status': 'cached_drive'}
                        logger.info(f"  Splits restored from Drive")
                    else:
                        _compute_and_save_splits(smiles_list, split_path, report)
                report['status'] = 'OK'
                return report
    except Exception as e:
        logger.debug(f"  Drive FP restore failed: {e}")

    # ---- Compute from scratch ----
    t0 = time.time()
    fp_matrix, valid_idx, n_failed = compute_morgan_fingerprints(smiles_list)
    fp_time = time.time() - t0

    report.update({
        'valid_fps': len(valid_idx), 'failed_fps': n_failed,
        'fp_time_seconds': round(fp_time, 1),
        'matrix_shape': list(fp_matrix.shape),
        'sparsity': round(1.0 - fp_matrix.nnz / max(fp_matrix.shape[0] * fp_matrix.shape[1], 1), 4),
    })
    logger.info(f"  FPs: {len(valid_idx)} valid, {n_failed} failed, "
                f"shape={fp_matrix.shape}, time={fp_time:.1f}s")

    sparse.save_npz(fp_path, fp_matrix)
    logger.info(f"  Saved: {fp_path}")

    # Save index mapping
    with open(idx_path, 'w') as f:
        json.dump({'valid_indices': valid_idx, 'source_csv': csv_path}, f)

    # Push FPs to Google Drive
    try:
        from utils.gdrive_backup import get_data_manager
        dm = get_data_manager()
        dm.push(fp_path)
        dm.push(idx_path)
    except Exception:
        pass

    # Scaffold splits
    if compute_splits:
        _compute_and_save_splits(smiles_list, split_path, report)

    report['status'] = 'OK'
    return report


def _compute_and_save_splits(smiles_list, split_path, report):
    """Compute scaffold folds and save locally + Drive."""
    t1 = time.time()
    folds = generate_scaffold_folds(smiles_list, n_folds=config.N_FOLDS, random_seed=config.RANDOM_SEED)
    save_folds(folds, split_path)
    summary = scaffold_split_summary(smiles_list, folds)
    report['scaffold_splits'] = summary
    report['split_time_seconds'] = round(time.time() - t1, 1)
    logger.info(f"  Splits: {summary['n_unique_scaffolds']} scaffolds, "
                f"imbalance={summary['imbalance_ratio']:.3f}, folds={summary['fold_sizes']}")
    # Push to Drive
    try:
        from utils.gdrive_backup import get_data_manager
        get_data_manager().push(split_path)
    except Exception:
        pass


def generate_phase2_figures(all_reports):
    import matplotlib; matplotlib.use('Agg')
    import matplotlib.pyplot as plt; import seaborn as sns
    os.makedirs(config.FIGURES_DIR, exist_ok=True)
    setup_publication_style()

    # Dataset sizes
    names = [n for n, r in all_reports.items() if r.get('status') == 'OK']
    sizes = [all_reports[n]['valid_fps'] for n in names]

    fig, ax = plt.subplots(figsize=(9, 5))
    bars = ax.barh(range(len(names)), sizes, color=COLORS['rf'], edgecolor='black', linewidth=0.5)
    ax.set_yticks(range(len(names))); ax.set_yticklabels(names)
    ax.set_xlabel('Compounds with valid Morgan FPs')
    ax.set_title('Phase 2: Dataset Sizes After Featurization')
    for bar, s in zip(bars, sizes):
        ax.text(bar.get_width() + max(sizes)*0.01, bar.get_y() + bar.get_height()/2.,
                f'{s:,}', ha='left', va='center', fontsize=9)
    ax.invert_yaxis(); ax.set_xlim(0, max(sizes)*1.15)
    sns.despine(); plt.tight_layout()
    save_figure(fig, os.path.join(config.FIGURES_DIR, 'phase2_dataset_sizes'))

    # Fold balance
    split_ds = {k: v for k, v in all_reports.items() if v.get('scaffold_splits')}
    if split_ds:
        n_plots = len(split_ds)
        fig, axes = plt.subplots(1, min(n_plots, 5), figsize=(3.5 * min(n_plots, 5), 4))
        if n_plots == 1: axes = [axes]
        for ax, (name, r) in zip(axes, list(split_ds.items())[:5]):
            fs = r['scaffold_splits']['fold_sizes']
            ax.bar(list(fs.keys()), list(fs.values()), color=COLORS['rf'], edgecolor='black', linewidth=0.5)
            ax.set_xlabel('Fold'); ax.set_ylabel('Compounds')
            ax.set_title(f'{name}'); sns.despine(ax=ax)
        plt.suptitle('Scaffold-Based Fold Balance', fontsize=13)
        plt.tight_layout()
        save_figure(fig, os.path.join(config.FIGURES_DIR, 'phase2_fold_balance'))
    logger.info("  Figures generated")


def run_unit_tests():
    print("Running Phase 2 unit tests...")
    n_pass = n_fail = 0
    def _assert(c, m):
        nonlocal n_pass, n_fail
        if c: n_pass += 1; print(f"  [PASS] {m}")
        else: n_fail += 1; print(f"  [FAIL] {m}")

    test_smiles = ['CCO', 'c1ccccc1', 'CC(=O)Oc1ccccc1C(=O)O', 'INVALID']
    matrix, valid_idx, n_failed = compute_morgan_fingerprints(test_smiles, radius=2, n_bits=2048)
    _assert(matrix.shape == (3, 2048), f"FP shape: {matrix.shape}")
    _assert(len(valid_idx) == 3, f"Valid count: {len(valid_idx)}")
    _assert(n_failed == 1, f"Failed count: {n_failed}")
    _assert(matrix.nnz > 0, "Non-zero bits exist")
    row0 = matrix[0].toarray().flatten(); row1 = matrix[1].toarray().flatten()
    _assert(not np.array_equal(row0, row1), "Different molecules get different FPs")
    sparsity = 1.0 - matrix.nnz / (matrix.shape[0] * matrix.shape[1])
    _assert(sparsity > 0.9, f"Sparsity={sparsity:.4f}")

    import tempfile
    with tempfile.NamedTemporaryFile(suffix='.npz', delete=False) as tmp: tmppath = tmp.name
    try:
        sparse.save_npz(tmppath, matrix)
        loaded = sparse.load_npz(tmppath)
        _assert(np.array_equal(matrix.toarray(), loaded.toarray()), "NPZ roundtrip OK")
    finally:
        os.unlink(tmppath)

    print(f"\nUnit tests: {n_pass} passed, {n_fail} failed")
    return n_fail == 0


def main():
    _F = "04_compute_morgan_fps.py:main"
    logger.info(f"[{_F}] Running unit tests...")
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
        logger.error(f"[{_F}] Unit tests FAILED."); sys.exit(1)
    logger.info(f"[{_F}] All unit tests passed.\n")

    start_time = log_phase_start(logger, "Phase 2: Feature Engineering")
    for d in [config.FEATURES_DIR, config.SPLITS_DIR, config.FIGURES_DIR, config.REPORTS_DIR]:
        os.makedirs(d, exist_ok=True)

    # Try restoring features from ZIP (local or Drive) before computing
    try:
        from utils.gdrive_backup import get_data_manager
        dm = get_data_manager()
        dm.restore_features(config.PROJECT_DIR)
    except Exception:
        pass

    # Validate ALL input files exist before starting
    missing = []
    for pkey, pinfo in config.PATHOGENS.items():
        csv_path = os.path.join(config.CHEMBL_DIR, pinfo['csv_filename'])
        if not os.path.exists(csv_path):
            missing.append(f"  {pkey}: {csv_path}")
    maier_csv = os.path.join(config.MAIER_DIR, 'maier_combined.csv')
    if not os.path.exists(maier_csv):
        missing.append(f"  maier: {maier_csv}")
    hub_csv = os.path.join(config.HUB_DIR, config.HUB_CLEAN_FILENAME)
    if not os.path.exists(hub_csv):
        missing.append(f"  hub: {hub_csv}")
    if missing:
        logger.error(f"[{_F}] MISSING INPUT FILES (run Phase 1 first):")
        for m in missing:
            logger.error(f"  {m}")
        sys.exit(1)
    logger.info(f"[{_F}] All input files verified.")

    all_reports = {}
    for pkey, pinfo in config.PATHOGENS.items():
        csv_path = os.path.join(config.CHEMBL_DIR, pinfo['csv_filename'])
        try:
            all_reports[pkey] = process_dataset(pkey, csv_path, compute_splits=True)
        except Exception as e:
            logger.error(f"[{_F}] FAILED processing {pkey}: {type(e).__name__}: {e}")
            import traceback; logger.error(traceback.format_exc())

    try:
        all_reports['maier'] = process_dataset('maier', maier_csv, compute_splits=True)
    except Exception as e:
        logger.error(f"[{_F}] FAILED processing maier: {type(e).__name__}: {e}")
        import traceback; logger.error(traceback.format_exc())

    try:
        all_reports['repurposing_hub'] = process_dataset('repurposing_hub', hub_csv, compute_splits=False)
    except Exception as e:
        logger.error(f"[{_F}] FAILED processing hub: {type(e).__name__}: {e}")
        import traceback; logger.error(traceback.format_exc())

    logger.info("\nGenerating figures...")
    try: generate_phase2_figures(all_reports)
    except Exception as e: logger.warning(f"Figures failed: {e}")

    report_path = os.path.join(config.REPORTS_DIR, 'phase2_quality_report.json')
    with open(report_path, 'w') as f:
        json.dump(all_reports, f, indent=2, default=str)

    logger.info("\n" + "=" * 70)
    logger.info(" PHASE 2 SUMMARY")
    logger.info("=" * 70)
    logger.info(f"{'Dataset':<20} {'Rows':>8} {'Valid FPs':>10} {'Scaffolds':>10}")
    logger.info("-" * 70)
    for name, r in all_reports.items():
        scaff = r.get('scaffold_splits', {}).get('n_unique_scaffolds', '--')
        logger.info(f"{name:<20} {r.get('total_rows','?'):>8} {r.get('valid_fps','?'):>10} {scaff:>10}")
    logger.info("=" * 70)

    save_checkpoint({'status': 'complete'}, os.path.join(config.CHECKPOINTS_DIR, 'phase2_master.json'), logger)

    # Pack all features + splits into a ZIP and push to Drive
    try:
        from utils.gdrive_backup import get_data_manager
        dm = get_data_manager()
        dm.pack_features(config.PROJECT_DIR)
    except Exception as e:
        logger.debug(f"  Feature packing skipped: {e}")

    log_phase_end(logger, "Phase 2", start_time)

if __name__ == '__main__':
    main()
