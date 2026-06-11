"""
diagnostics.py -- Bulletproof diagnostics and resilient execution framework.

Provides:
  - safe_run(): Execute a function with full error context (file, function, line)
  - StepRunner: Run a sequence of steps, continuing on failure where possible
  - diag(): Print a diagnostic message with timestamp, file, and function context

Every error is caught, logged with ACTIONABLE information, and the pipeline
continues wherever possible.

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import os
import sys
import time
import traceback
import logging
import functools
import inspect
from typing import Any, Callable, Dict, List, Optional, Tuple


def diag(logger: logging.Logger, level: str, msg: str, depth: int = 1):
    """
    Log a diagnostic message with caller file, function, and line number.

    Parameters
    ----------
    logger : logging.Logger
    level : str
        'INFO', 'WARN', 'ERROR', 'DEBUG'
    msg : str
        Message to log
    depth : int
        Call stack depth (1 = immediate caller, 2 = caller's caller)
    """
    frame = inspect.stack()[depth]
    filename = os.path.basename(frame.filename)
    funcname = frame.function
    lineno = frame.lineno

    prefix = f"[{filename}:{lineno} {funcname}()]"
    full_msg = f"{prefix} {msg}"

    if level == 'INFO':
        logger.info(full_msg)
    elif level == 'WARN':
        logger.warning(full_msg)
    elif level == 'ERROR':
        logger.error(full_msg)
    elif level == 'DEBUG':
        logger.debug(full_msg)
    else:
        logger.info(full_msg)


def safe_run(
    func: Callable,
    *args,
    logger: logging.Logger = None,
    step_name: str = None,
    critical: bool = True,
    default: Any = None,
    **kwargs,
) -> Tuple[Any, bool]:
    """
    Execute a function with full error handling and diagnostics.

    Parameters
    ----------
    func : callable
        Function to execute.
    *args : positional args for func.
    logger : logging.Logger
        Logger instance.
    step_name : str
        Human-readable step name for diagnostics.
    critical : bool
        If True, re-raise the exception after logging.
        If False, return (default, False) on failure.
    default : any
        Default return value on failure (when critical=False).
    **kwargs : keyword args for func.

    Returns
    -------
    tuple of (result, success_bool)
    """
    name = step_name or func.__name__
    source_file = inspect.getfile(func)
    source_name = os.path.basename(source_file)

    if logger:
        logger.info(f"[{source_name}:{func.__name__}()] STARTING: {name}")

    t0 = time.time()
    try:
        result = func(*args, **kwargs)
        elapsed = time.time() - t0
        if logger:
            logger.info(f"[{source_name}:{func.__name__}()] COMPLETED: {name} ({elapsed:.1f}s)")
        return result, True

    except Exception as e:
        elapsed = time.time() - t0
        error_type = type(e).__name__
        error_msg = str(e)

        # Get the exact line that failed
        tb = traceback.extract_tb(sys.exc_info()[2])
        if tb:
            last_frame = tb[-1]
            fail_file = os.path.basename(last_frame.filename)
            fail_line = last_frame.lineno
            fail_func = last_frame.name
            fail_code = last_frame.line or ''
        else:
            fail_file = source_name
            fail_line = '?'
            fail_func = func.__name__
            fail_code = ''

        error_report = (
            f"\n{'='*70}\n"
            f"  STEP FAILED: {name}\n"
            f"{'='*70}\n"
            f"  Error type:  {error_type}\n"
            f"  Error msg:   {error_msg}\n"
            f"  Failed at:   {fail_file}:{fail_line} in {fail_func}()\n"
            f"  Code line:   {fail_code}\n"
            f"  Called from: {source_name}:{func.__name__}()\n"
            f"  Elapsed:     {elapsed:.1f}s\n"
            f"  Traceback:\n"
        )

        # Full traceback
        tb_str = traceback.format_exc()
        for line in tb_str.strip().split('\n'):
            error_report += f"    {line}\n"

        # Actionable advice
        error_report += f"\n  ACTION NEEDED:\n"
        if 'FileNotFoundError' in error_type:
            error_report += f"    -> Check that previous phases completed successfully.\n"
            error_report += f"    -> Verify the file exists: {error_msg}\n"
        elif 'ImportError' in error_type or 'ModuleNotFoundError' in error_type:
            error_report += f"    -> Activate venv: source ~/antibiotic-selectivity/venv/bin/activate\n"
            pkg_name = error_msg.split("'")[1] if "'" in error_msg else '?'
            error_report += f"    -> Install missing package: pip install {pkg_name}\n"
        elif 'KeyError' in error_type:
            error_report += f"    -> A required column or key is missing from the data.\n"
            error_report += f"    -> Check that Phase 1 output CSV has the expected columns.\n"
        elif 'MemoryError' in error_type:
            error_report += f"    -> Reduce batch size in config.py or request more memory in SLURM.\n"
        elif 'ConnectionError' in error_type or 'Timeout' in error_type:
            error_report += f"    -> Network issue. Retry the job or check Ada network.\n"
        elif 'AssertionError' in error_type or 'AssertionError' in error_type:
            error_report += f"    -> Data validation failed. Check input data integrity.\n"
        else:
            error_report += f"    -> Review the traceback above for the root cause.\n"
            error_report += f"    -> Share this FULL error report for debugging.\n"

        error_report += f"{'='*70}\n"

        if logger:
            logger.error(error_report)
        else:
            print(error_report, file=sys.stderr)

        if critical:
            raise
        return default, False


class StepRunner:
    """
    Execute a sequence of named steps with resilient error handling.

    Steps marked as critical=True will halt the pipeline on failure.
    Steps marked as critical=False will log the error and continue.

    Usage:
        runner = StepRunner(logger, 'Phase 1A')
        runner.run('Fetch ChEMBL data', fetch_data, critical=True)
        runner.run('Generate figures', make_plots, critical=False)
        runner.summary()
    """

    def __init__(self, logger: logging.Logger, phase_name: str):
        self.logger = logger
        self.phase_name = phase_name
        self.steps: List[Dict] = []
        self.start_time = time.time()

    def run(self, step_name: str, func: Callable, *args,
            critical: bool = True, default: Any = None, **kwargs) -> Any:
        """
        Run a step with full diagnostics.

        Returns the function result, or default on non-critical failure.
        """
        step_num = len(self.steps) + 1
        total_label = f"[Step {step_num}] {step_name}"

        self.logger.info(f"\n{'~'*60}")
        self.logger.info(f"  {self.phase_name} >> {total_label}")
        self.logger.info(f"  Time: {time.strftime('%H:%M:%S')}")
        self.logger.info(f"{'~'*60}")

        result, success = safe_run(
            func, *args,
            logger=self.logger,
            step_name=total_label,
            critical=critical,
            default=default,
            **kwargs,
        )

        self.steps.append({
            'step': step_num,
            'name': step_name,
            'success': success,
            'critical': critical,
            'elapsed': time.time() - (self.start_time if step_num == 1 else self.start_time),
        })

        return result

    def summary(self) -> bool:
        """Print step summary. Returns True if all critical steps passed."""
        elapsed = time.time() - self.start_time
        n_pass = sum(1 for s in self.steps if s['success'])
        n_fail = sum(1 for s in self.steps if not s['success'])
        n_critical_fail = sum(1 for s in self.steps if not s['success'] and s['critical'])

        self.logger.info(f"\n{'='*60}")
        self.logger.info(f"  {self.phase_name} STEP SUMMARY")
        self.logger.info(f"{'='*60}")
        for s in self.steps:
            status = 'PASS' if s['success'] else 'FAIL'
            crit = ' [CRITICAL]' if s['critical'] and not s['success'] else ''
            self.logger.info(f"  [{status}] Step {s['step']}: {s['name']}{crit}")
        self.logger.info(f"{'='*60}")
        self.logger.info(f"  Passed: {n_pass}/{len(self.steps)}")
        self.logger.info(f"  Failed: {n_fail}/{len(self.steps)} ({n_critical_fail} critical)")
        self.logger.info(f"  Total time: {elapsed:.0f}s ({elapsed/60:.1f}m)")
        self.logger.info(f"{'='*60}")

        return n_critical_fail == 0


def resilient_main(phase_name: str, logger: logging.Logger):
    """
    Create a StepRunner for use in a script's main() function.

    Usage:
        runner = resilient_main('Phase 1A', logger)
        data = runner.run('Fetch data', fetch_fn, critical=True)
        runner.run('Make plots', plot_fn, data, critical=False)
        if not runner.summary():
            sys.exit(1)
    """
    return StepRunner(logger, phase_name)


# ---- Self-test ----
def _run_tests():
    """Test the diagnostics framework itself."""
    print("Running diagnostics unit tests...")
    n_pass = 0; n_fail = 0

    def _assert(cond, msg):
        nonlocal n_pass, n_fail
        if cond: n_pass += 1; print(f"  [PASS] {msg}")
        else: n_fail += 1; print(f"  [FAIL] {msg}")

    # Setup test logger
    test_logger = logging.getLogger('diag_test')
    test_logger.setLevel(logging.DEBUG)
    if not test_logger.handlers:
        test_logger.addHandler(logging.StreamHandler(sys.stdout))

    # Test safe_run with success
    def good_fn(x, y):
        return x + y
    result, ok = safe_run(good_fn, 3, 4, logger=test_logger, step_name='addition')
    _assert(ok and result == 7, f"safe_run success: {result}")

    # Test safe_run with failure (non-critical)
    def bad_fn():
        raise ValueError("test error")
    result, ok = safe_run(bad_fn, logger=test_logger, step_name='bad_fn',
                          critical=False, default=-1)
    _assert(not ok and result == -1, "safe_run non-critical failure returns default")

    # Test StepRunner
    runner = StepRunner(test_logger, 'Test Phase')
    r1 = runner.run('Good step', good_fn, 2, 3, critical=True)
    _assert(r1 == 5, "StepRunner good step returns result")

    r2 = runner.run('Bad step (non-critical)', bad_fn, critical=False, default=None)
    _assert(r2 is None, "StepRunner non-critical failure returns None")

    r3 = runner.run('Another good step', good_fn, 10, 20, critical=True)
    _assert(r3 == 30, "StepRunner continues after non-critical failure")

    all_ok = runner.summary()
    _assert(all_ok, "StepRunner summary: all critical steps passed")

    # Test diag function
    diag(test_logger, 'INFO', 'test diagnostic message')
    _assert(True, "diag() runs without error")

    print(f"\nUnit tests: {n_pass} passed, {n_fail} failed")
    return n_fail == 0


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    success = _run_tests()
    exit(0 if success else 1)
