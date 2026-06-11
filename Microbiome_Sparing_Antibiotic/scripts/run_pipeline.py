#!/usr/bin/env python3
"""
run_pipeline.py -- Resilient Master Pipeline Runner

Runs all phases (1A through 4 + Showcase) with:
  - StepRunner wrapping every step with try/catch and full diagnostics
  - Independent steps continue even if earlier non-critical steps fail
  - Every error shows file, function, line, code, and actionable advice
  - Timestamps and step counters on every message
  - Summary report at the end

Usage:
  python scripts/run_pipeline.py                 # Run all
  python scripts/run_pipeline.py --from phase2   # Resume
  python scripts/run_pipeline.py --phase phase1a # Single phase

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import os, sys, json, time, argparse, logging

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)

import config
from utils.logging_utils import setup_logging, log_phase_start, log_phase_end
from utils.diagnostics import StepRunner, safe_run, diag

# Configure logging to BOTH console and file
LOG_FILE = os.path.join(config.LOGS_DIR, f'pipeline_{time.strftime("%Y%m%d_%H%M%S")}.log')
os.makedirs(config.LOGS_DIR, exist_ok=True)

logger = logging.getLogger('pipeline')
logger.setLevel(logging.INFO)
fmt = logging.Formatter('[%(levelname)-5s] %(asctime)s | %(name)s | %(message)s',
                        datefmt='%Y-%m-%d %H:%M:%S')
ch = logging.StreamHandler(sys.stdout)
ch.setFormatter(fmt)
logger.addHandler(ch)
fh = logging.FileHandler(LOG_FILE)
fh.setFormatter(fmt)
logger.addHandler(fh)

logger.info(f"Pipeline log: {LOG_FILE}")


# =====================================================================
# Phase runners -- each imports its module and calls functions
# =====================================================================

def run_phase1a():
    """Phase 1A: Fetch ChEMBL pathogen data."""
    import importlib
    mod = importlib.import_module('01_fetch_chembl')
    runner = StepRunner(logger, 'Phase 1A: ChEMBL')

    runner.run('Unit tests', mod.run_unit_tests, critical=True)

    os.makedirs(config.CHEMBL_DIR, exist_ok=True)
    os.makedirs(config.CHECKPOINTS_DIR, exist_ok=True)
    os.makedirs(config.FIGURES_DIR, exist_ok=True)
    os.makedirs(config.REPORTS_DIR, exist_ok=True)

    all_results = {}
    all_reports = {}
    for key in config.PATHOGENS:
        df, report = runner.run(
            f'Process {key}', mod.process_one_pathogen,
            key, config.CHECKPOINTS_DIR, critical=True
        )
        all_results[key] = df
        all_reports[key] = report

    runner.run('Generate figures', mod.generate_phase1a_figures,
               all_results, critical=False)
    runner.run('Generate report', mod.generate_phase1a_report,
               all_reports, critical=False)

    return runner.summary()


def run_phase1b():
    """Phase 1B: Process Maier commensal data."""
    import importlib
    mod = importlib.import_module('02_process_maier')
    runner = StepRunner(logger, 'Phase 1B: Maier')

    runner.run('Unit tests', mod.run_unit_tests, critical=True)

    os.makedirs(config.MAIER_DIR, exist_ok=True)
    os.makedirs(config.CHECKPOINTS_DIR, exist_ok=True)
    os.makedirs(config.FIGURES_DIR, exist_ok=True)
    os.makedirs(config.REPORTS_DIR, exist_ok=True)

    result = runner.run('Process Maier data', mod.process_maier_data, critical=True)
    if result is not None:
        df_final, lookup_log, quality_report = result

        def save_outputs():
            csv_path = os.path.join(config.MAIER_DIR, 'maier_combined.csv')
            df_final.to_csv(csv_path, index=False)
            logger.info(f"  Saved: {csv_path} ({len(df_final)} compounds)")
            log_path = os.path.join(config.MAIER_DIR, 'smiles_lookup_log.csv')
            lookup_log.to_csv(log_path, index=False)

        runner.run('Save outputs', save_outputs, critical=True)
        runner.run('Generate figures', mod.generate_phase1b_figures,
                   df_final, critical=False)

    return runner.summary()


def run_phase1c():
    """Phase 1C: Download Drug Repurposing Hub."""
    import importlib
    mod = importlib.import_module('03_fetch_repurposing_hub')
    runner = StepRunner(logger, 'Phase 1C: Hub')

    runner.run('Unit tests', mod.run_unit_tests, critical=True)

    os.makedirs(config.HUB_DIR, exist_ok=True)
    os.makedirs(config.CHECKPOINTS_DIR, exist_ok=True)
    os.makedirs(config.FIGURES_DIR, exist_ok=True)
    os.makedirs(config.REPORTS_DIR, exist_ok=True)

    result = runner.run('Process Hub data', mod.process_hub_data, critical=True)
    if result is not None:
        df_final, quality_report = result

        def save_hub():
            csv_path = os.path.join(config.HUB_DIR, config.HUB_CLEAN_FILENAME)
            df_final.to_csv(csv_path, index=False)
            logger.info(f"  Saved: {csv_path} ({len(df_final)} compounds)")

        runner.run('Save outputs', save_hub, critical=True)
        runner.run('Generate figures', mod.generate_phase1c_figures,
                   df_final, critical=False)

    return runner.summary()


def run_phase2():
    """Phase 2: Feature engineering (Morgan FPs + scaffold splits)."""
    import importlib
    mod = importlib.import_module('04_compute_morgan_fps')
    runner = StepRunner(logger, 'Phase 2: Features')

    runner.run('Unit tests', mod.run_unit_tests, critical=True)

    # This phase calls main() which has its own internal steps
    # We wrap the whole thing in a single critical step
    runner.run('Compute features and splits', mod.main, critical=True)

    return runner.summary()


def run_phase3a():
    """Phase 3A: RF pipeline training."""
    import importlib
    mod = importlib.import_module('05_train_rf')
    runner = StepRunner(logger, 'Phase 3A: RF Training')

    runner.run('Unit tests', mod.run_unit_tests, critical=True)
    runner.run('Train RF models and screen Hub', mod.main, critical=True)

    return runner.summary()


def run_phase3b():
    """Phase 3B: D-MPNN pipeline training."""
    import importlib
    mod = importlib.import_module('06_train_dmpnn')
    runner = StepRunner(logger, 'Phase 3B: D-MPNN Training')

    runner.run('Unit tests', mod.run_unit_tests, critical=True)
    runner.run('Train D-MPNN models and screen Hub', mod.main, critical=True)

    return runner.summary()


def run_phase4():
    """Phase 4: Full evaluation suite."""
    import importlib
    mod = importlib.import_module('07_evaluate')
    runner = StepRunner(logger, 'Phase 4: Evaluation')

    runner.run('Unit tests', mod.run_unit_tests, critical=True)
    runner.run('Run full evaluation', mod.main, critical=True)

    return runner.summary()


def run_showcase():
    """Showcase: Generate beautiful visualizations."""
    import importlib
    mod = importlib.import_module('08_create_showcase')
    runner = StepRunner(logger, 'Showcase Visualizations')

    runner.run('Generate static figures', mod.make_static_figures, critical=False)
    runner.run('Generate interactive HTML', mod.make_interactive_html, critical=False)
    runner.run('Package outputs', mod.package_outputs, critical=False)

    return runner.summary()


# =====================================================================
# Phase ordering
# =====================================================================
PHASES = {
    'phase1a': ('Phase 1A: ChEMBL Pathogen Data', run_phase1a),
    'phase1b': ('Phase 1B: Maier Commensal Data', run_phase1b),
    'phase1c': ('Phase 1C: Drug Repurposing Hub', run_phase1c),
    'phase2':  ('Phase 2: Feature Engineering', run_phase2),
    'phase3a': ('Phase 3A: RF Pipeline Training', run_phase3a),
    'phase3b': ('Phase 3B: D-MPNN Pipeline Training', run_phase3b),
    'phase4':  ('Phase 4: Full Evaluation Suite', run_phase4),
    'showcase':('Showcase Visualizations', run_showcase),
}
PHASE_ORDER = ['phase1a', 'phase1b', 'phase1c', 'phase2', 'phase3a', 'phase3b', 'phase4', 'showcase']


def main():
    parser = argparse.ArgumentParser(description='Microbiome-Sparing Antibiotic Discovery Pipeline')
    parser.add_argument('--from', dest='start_from', default='phase1a',
                        choices=PHASE_ORDER, help='Resume from this phase')
    parser.add_argument('--phase', default=None, choices=PHASE_ORDER,
                        help='Run only this single phase')
    args = parser.parse_args()

    logger.info("=" * 70)
    logger.info(" MICROBIOME-SPARING ANTIBIOTIC DISCOVERY PIPELINE")
    logger.info(f" Start: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    logger.info(f" Log:   {LOG_FILE}")
    logger.info(f" Mode:  {'single phase: ' + args.phase if args.phase else 'from ' + args.start_from}")
    logger.info("=" * 70)

    # Determine phases to run
    if args.phase:
        phases_to_run = [args.phase]
    else:
        start_idx = PHASE_ORDER.index(args.start_from)
        phases_to_run = PHASE_ORDER[start_idx:]

    pipeline_start = time.time()
    results = {}

    for phase_key in phases_to_run:
        phase_name, phase_fn = PHASES[phase_key]

        logger.info(f"\n{'#' * 70}")
        logger.info(f"# STARTING: {phase_name}")
        logger.info(f"# Time: {time.strftime('%Y-%m-%d %H:%M:%S')}")
        logger.info(f"{'#' * 70}")

        phase_ok = False
        try:
            phase_ok = phase_fn()
        except SystemExit as e:
            if e.code == 0:
                phase_ok = True
            else:
                logger.error(f"  {phase_name} exited with code {e.code}")
        except Exception as e:
            logger.error(f"  {phase_name} UNHANDLED EXCEPTION: {type(e).__name__}: {e}")
            import traceback
            logger.error(traceback.format_exc())

        results[phase_key] = phase_ok

        if not phase_ok:
            # Check if next phases depend on this one
            logger.error(f"\n  {phase_name} FAILED.")
            logger.error(f"  Pipeline paused. Fix the issue and resume with:")
            logger.error(f"    python scripts/run_pipeline.py --from {phase_key}")
            break

    # ---- Final summary ----
    elapsed = time.time() - pipeline_start
    n_run = len(results)
    n_pass = sum(1 for v in results.values() if v)
    n_fail = sum(1 for v in results.values() if not v)

    logger.info(f"\n{'=' * 70}")
    logger.info(f" PIPELINE COMPLETE")
    logger.info(f"{'=' * 70}")
    for key, ok in results.items():
        status = 'PASS' if ok else 'FAIL'
        logger.info(f"  [{status}] {PHASES[key][0]}")
    logger.info(f"{'=' * 70}")
    logger.info(f"  Passed: {n_pass}/{n_run}")
    logger.info(f"  Failed: {n_fail}/{n_run}")
    logger.info(f"  Total:  {elapsed/60:.1f} minutes")
    logger.info(f"  Log:    {LOG_FILE}")

    if n_fail > 0:
        first_fail = [k for k, v in results.items() if not v][0]
        logger.info(f"\n  TO RESUME: python scripts/run_pipeline.py --from {first_fail}")

    logger.info(f"{'=' * 70}")

    sys.exit(0 if n_fail == 0 else 1)


if __name__ == '__main__':
    main()
