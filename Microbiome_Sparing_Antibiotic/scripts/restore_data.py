"""
restore_data.py -- Restore all data and features from ZIP bundles.

Called by run_mac.sh, run_ubuntu.sh, run_ada.sh before Phase 1 checks.

Priority for each bundle:
  1. Local files already exist (skip)
  2. Local ZIP exists (unzip)
  3. Drive ZIP exists (download + unzip)
  4. gdown public link ZIP (download + unzip)
  5. Not available (Phase 1/2 will fetch from source)

Two bundles:
  antibiotic_data_csvs.zip  (~10 MB) processed CSVs
  antibiotic_features.zip   (~15 MB) Morgan FPs + scaffold folds

Usage:
    python3 scripts/restore_data.py
"""

import os
import sys
import logging

sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
import config

logging.basicConfig(level=logging.INFO, format='%(message)s')
logger = logging.getLogger('restore_data')


def _is_valid_csv(path):
    """Check that a file is actually a CSV, not an HTML page from Google Drive."""
    if not os.path.exists(path) or os.path.getsize(path) < 100:
        return False
    try:
        with open(path, 'rb') as f:
            header = f.read(512)
        # HTML page detection (Google Drive login/confirmation pages)
        if b'<!DOCTYPE' in header or b'<html' in header or b'<HTML' in header:
            logger.warning(f"  [restore] CORRUPTED (HTML page): {os.path.basename(path)}")
            os.remove(path)
            return False
        # CSV should have comma in first line
        first_line = header.split(b'\n')[0]
        if b',' not in first_line:
            logger.warning(f"  [restore] CORRUPTED (not CSV): {os.path.basename(path)}")
            os.remove(path)
            return False
        return True
    except Exception:
        return False


def main():
    try:
        from utils.gdrive_backup import get_data_manager, _purge_poisoned_cache
        # Purge any previously cached HTML pages FIRST
        _purge_poisoned_cache()
        dm = get_data_manager()
    except Exception as e:
        logger.debug(f"DataManager not available: {e}")
        dm = None

    # ---- Pre-check: validate any existing CSVs (catch HTML garbage from prior runs) ----
    logger.info("  [restore] Validating existing data files...")
    for pkey, pinfo in config.PATHOGENS.items():
        csv_path = os.path.join(config.CHEMBL_DIR, pinfo['csv_filename'])
        _is_valid_csv(csv_path)  # Deletes if corrupted
    _is_valid_csv(os.path.join(config.HUB_DIR, config.HUB_CLEAN_FILENAME))
    _is_valid_csv(os.path.join(config.MAIER_DIR, 'maier_combined.csv'))
    _is_valid_csv(os.path.join(config.MAIER_DIR, 'maier_smiles_lookup.csv'))

    # ---- Step 1: Restore data CSVs from ZIP ----
    logger.info("  [restore] Checking data CSVs...")
    data_ok = False
    if dm:
        data_ok = dm.restore_data_csvs(config.PROJECT_DIR)

    # Fall back to individual file restore if ZIP didn't work
    if not data_ok and dm:
        restored = 0
        for pkey, pinfo in config.PATHOGENS.items():
            fname = pinfo['csv_filename']
            local = os.path.join(config.CHEMBL_DIR, fname)
            if os.path.exists(local) and os.path.getsize(local) > 1000:
                continue
            result = dm.resolve(fname, config.CHEMBL_DIR)
            if result:
                restored += 1
                logger.info(f"    Restored: {fname}")

        local_hub = os.path.join(config.HUB_DIR, config.HUB_CLEAN_FILENAME)
        if not (os.path.exists(local_hub) and os.path.getsize(local_hub) > 1000):
            if dm.resolve(config.HUB_CLEAN_FILENAME, config.HUB_DIR):
                restored += 1

        local_maier = os.path.join(config.MAIER_DIR, 'maier_combined.csv')
        if not (os.path.exists(local_maier) and os.path.getsize(local_maier) > 1000):
            if dm.resolve('maier_combined.csv', config.MAIER_DIR):
                restored += 1
            dm.resolve('maier_smiles_lookup.csv', config.MAIER_DIR)
            dm.resolve_maier_excel(config.MAIER_DIR)

        if restored > 0:
            logger.info(f"    Restored {restored} individual file(s)")

    # ---- Step 2: Restore features from ZIP ----
    logger.info("  [restore] Checking features + splits...")
    feat_ok = False
    if dm:
        feat_ok = dm.restore_features(config.PROJECT_DIR)

    # ---- Step 3: Restore RF models from ZIP ----
    logger.info("  [restore] Checking RF models...")
    rf_ok = False
    if dm:
        rf_ok = dm.restore_rf_models(config.PROJECT_DIR)

    # ---- Step 4: Restore D-MPNN models from ZIP ----
    logger.info("  [restore] Checking D-MPNN models...")
    dmpnn_ok = False
    if dm:
        dmpnn_ok = dm.restore_dmpnn_models(config.PROJECT_DIR)

    # ---- Step 5: Report (with validation) ----
    missing_data = []
    for pkey, pinfo in config.PATHOGENS.items():
        local = os.path.join(config.CHEMBL_DIR, pinfo['csv_filename'])
        if not _is_valid_csv(local):
            missing_data.append(pkey)
    local_hub = os.path.join(config.HUB_DIR, config.HUB_CLEAN_FILENAME)
    if not _is_valid_csv(local_hub):
        missing_data.append('repurposing_hub')
    local_maier = os.path.join(config.MAIER_DIR, 'maier_combined.csv')
    if not _is_valid_csv(local_maier):
        missing_data.append('maier')

    n_npz = len([f for f in os.listdir(config.FEATURES_DIR) if f.endswith('.npz')]) if os.path.isdir(config.FEATURES_DIR) else 0
    n_pkl = len([f for f in os.listdir(config.SPLITS_DIR) if f.endswith('.pkl')]) if os.path.isdir(config.SPLITS_DIR) else 0

    if missing_data:
        logger.info(f"  [restore] Data: {len(missing_data)} missing ({', '.join(missing_data)})")
    else:
        logger.info(f"  [restore] Data: all CSVs available")

    logger.info(f"  [restore] Features: {n_npz} .npz, {n_pkl} fold files")

    n_rf = len([f for f in os.listdir(config.RF_DIR) if f.endswith('.pkl')]) if os.path.isdir(config.RF_DIR) else 0
    logger.info(f"  [restore] RF models: {n_rf} .pkl files")

    n_dmpnn = 0
    if os.path.isdir(config.DMPNN_DIR):
        for root, dirs, files in os.walk(config.DMPNN_DIR):
            n_dmpnn += len([f for f in files if f.endswith(('.pt', '.ckpt'))])
    logger.info(f"  [restore] D-MPNN models: {n_dmpnn} checkpoints")

    return 1 if missing_data else 0


if __name__ == '__main__':
    sys.exit(main())
