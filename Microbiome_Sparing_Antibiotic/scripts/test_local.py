#!/usr/bin/env python3
"""
test_local.py -- Run the full pipeline locally without GPU or network.

Works on Mac, Windows, Ubuntu, and Google Colab.

What it does:
  1. Generates synthetic test data (no network needed)
  2. Runs Phase 2 (Morgan FPs + scaffold splits)
  3. Runs Phase 3A (RF training)
  4. Skips Phase 3B (D-MPNN, optional)
  5. Runs Phase 4 (evaluation, RF-only)
  6. Generates showcase visualizations
  7. Reports all results

Usage:
  python scripts/test_local.py

  # Google Colab:
  !pip install rdkit scikit-learn matplotlib seaborn plotly
  !python scripts/test_local.py
"""

import os, sys, time, logging, importlib

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)

# Test_local always uses synthetic mode
os.environ['ANTIBIOTIC_DATA_MODE'] = 'synthetic'
if 'ANTIBIOTIC_PROJECT_DIR' not in os.environ:
    os.environ['ANTIBIOTIC_PROJECT_DIR'] = os.path.dirname(SCRIPT_DIR)

import config

def main():
    logging.basicConfig(level=logging.INFO,
        format='%(asctime)s | %(levelname)-5s | %(message)s', datefmt='%H:%M:%S')
    logger = logging.getLogger('test_local')

    logger.info("=" * 60)
    logger.info(" LOCAL TEST: Microbiome-Sparing Antibiotic Pipeline")
    logger.info(f"  Platform: {sys.platform}, Python: {sys.version.split()[0]}")
    logger.info(f"  Project: {config.PROJECT_DIR}")
    logger.info("=" * 60)

    # Check dependencies
    required = {'numpy': 'numpy', 'pandas': 'pandas', 'scipy': 'scipy',
                'sklearn': 'scikit-learn', 'rdkit': 'rdkit', 'matplotlib': 'matplotlib'}
    missing = []
    for pkg, pip_name in required.items():
        try:
            __import__(pkg)
        except ImportError:
            missing.append(pip_name)
    if missing:
        logger.error(f"  Missing: pip install {' '.join(missing)}")
        sys.exit(1)
    logger.info("  All required packages present.")

    has_chemprop = False
    try:
        import chemprop; has_chemprop = True
    except ImportError:
        pass

    t_start = time.time()
    results = {}

    # Step 1: Synthetic data
    logger.info("\n[Step 1] Generating synthetic test data...")
    try:
        from utils.alternative_data import generate_synthetic_data
        for d in [config.DATA_DIR, config.CHEMBL_DIR, config.MAIER_DIR, config.HUB_DIR,
                  config.FEATURES_DIR, config.SPLITS_DIR, config.RF_DIR, config.DMPNN_DIR,
                  config.RESULTS_DIR, config.SCREENING_DIR, config.FIGURES_DIR,
                  config.REPORTS_DIR, config.CHECKPOINTS_DIR, config.LOGS_DIR]:
            os.makedirs(d, exist_ok=True)
        generate_synthetic_data(config.PROJECT_DIR, logger)
        results['synthetic_data'] = 'PASS'
    except Exception as e:
        logger.error(f"  FAILED: {e}")
        import traceback; traceback.print_exc()
        results['synthetic_data'] = 'FAIL'
        sys.exit(1)

    # Step 2: Phase 2
    logger.info("\n[Step 2] Phase 2: Morgan FPs + Scaffold Splits...")
    try:
        mod = importlib.import_module('04_compute_morgan_fps')
        mod.main()
        results['phase2'] = 'PASS'
    except SystemExit as e:
        results['phase2'] = 'PASS' if e.code in (0, None) else 'FAIL'
    except Exception as e:
        logger.error(f"  FAILED: {type(e).__name__}: {e}")
        import traceback; traceback.print_exc()
        results['phase2'] = 'FAIL'

    # Step 3: Phase 3A
    if results.get('phase2') == 'PASS':
        logger.info("\n[Step 3] Phase 3A: RF Training...")
        try:
            mod = importlib.import_module('05_train_rf')
            mod.main()
            results['phase3a'] = 'PASS'
        except SystemExit as e:
            results['phase3a'] = 'PASS' if e.code in (0, None) else 'FAIL'
        except Exception as e:
            logger.error(f"  FAILED: {type(e).__name__}: {e}")
            import traceback; traceback.print_exc()
            results['phase3a'] = 'FAIL'
    else:
        logger.warning("  Skipping Phase 3A (Phase 2 failed)")
        results['phase3a'] = 'SKIP'

    # Step 4: Phase 3B (optional)
    if has_chemprop and results.get('phase2') == 'PASS':
        logger.info("\n[Step 4] Phase 3B: D-MPNN Training (optional)...")
        try:
            mod = importlib.import_module('06_train_dmpnn')
            mod.main()
            results['phase3b'] = 'PASS'
        except Exception as e:
            logger.warning(f"  Phase 3B failed (expected without GPU): {e}")
            results['phase3b'] = 'SKIP'
    else:
        logger.info("\n  Skipping Phase 3B (chemprop not installed or Phase 2 failed)")
        results['phase3b'] = 'SKIP'

    # Step 5: Phase 4
    if results.get('phase3a') == 'PASS':
        logger.info("\n[Step 5] Phase 4: Evaluation...")
        try:
            mod = importlib.import_module('07_evaluate')
            mod.main()
            results['phase4'] = 'PASS'
        except SystemExit as e:
            results['phase4'] = 'PASS' if e.code in (0, None) else 'FAIL'
        except Exception as e:
            logger.error(f"  FAILED: {type(e).__name__}: {e}")
            import traceback; traceback.print_exc()
            results['phase4'] = 'FAIL'
    else:
        results['phase4'] = 'SKIP'

    # Step 6: Showcase
    logger.info("\n[Step 6] Showcase Visualizations...")
    try:
        mod = importlib.import_module('08_create_showcase')
        mod.main()
        results['showcase'] = 'PASS'
    except Exception as e:
        logger.warning(f"  Showcase failed (non-critical): {e}")
        results['showcase'] = 'SKIP'

    # Summary
    elapsed = time.time() - t_start
    logger.info("\n" + "=" * 60)
    logger.info(" LOCAL TEST SUMMARY")
    logger.info("=" * 60)
    for step, status in results.items():
        icon = {'PASS': '[OK]  ', 'FAIL': '[FAIL]', 'SKIP': '[SKIP]'}[status]
        logger.info(f"  {icon} {step}")
    logger.info(f"  Total time: {elapsed:.0f}s ({elapsed/60:.1f}m)")

    n_pass = sum(1 for v in results.values() if v == 'PASS')
    n_fail = sum(1 for v in results.values() if v == 'FAIL')
    logger.info(f"  {n_pass} passed, {n_fail} failed, {len(results)-n_pass-n_fail} skipped")

    # List outputs
    if os.path.exists(config.RESULTS_DIR):
        n_files = sum(len(files) for _, _, files in os.walk(config.RESULTS_DIR))
        logger.info(f"  Output files: {n_files} in {config.RESULTS_DIR}")

    logger.info(f"\n  NOTE: These results are from SYNTHETIC data.")
    logger.info(f"        Real analysis requires Ada HPC with actual data.")
    logger.info("=" * 60)

    return n_fail == 0

if __name__ == '__main__':
    ok = main()
    sys.exit(0 if ok else 1)
