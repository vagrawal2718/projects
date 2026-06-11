"""
logging_utils.py -- Centralized logging with GUARANTEED dual console+file output.

Every log message goes to:
  1. Console (stdout) -- visible in real-time via `tail -f`
  2. Log file in logs/ -- persistent record for debugging

Messages include: timestamp, level, script name, and caller function.
File handler flushes on every write so logs are readable even during crashes.

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import logging
import os
import sys
import time
import functools
import inspect
from typing import Optional


class FlushFileHandler(logging.FileHandler):
    """FileHandler that flushes after every emit so logs survive crashes."""
    def emit(self, record):
        super().emit(record)
        self.flush()


def setup_logging(
    name: str,
    log_dir: Optional[str] = None,
    level: int = logging.INFO,
) -> logging.Logger:
    """
    Set up a logger with GUARANTEED console and file handlers.

    Both handlers are always created. If log_dir is None, it defaults
    to ~/antibiotic-selectivity/logs/.

    Parameters
    ----------
    name : str
        Logger name (typically the phase name, e.g., 'phase1a').
    log_dir : str, optional
        Directory for log files.
    level : int
        Logging level (default INFO).

    Returns
    -------
    logging.Logger
        Configured logger instance.
    """
    logger = logging.getLogger(name)
    logger.setLevel(level)

    # Prevent duplicate handlers if called multiple times
    if logger.handlers:
        return logger

    formatter = logging.Formatter(
        '%(asctime)s | %(levelname)-5s | %(name)s | %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )

    # Console handler -- ALWAYS created, flushes immediately
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(level)
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)

    # File handler -- ALWAYS created
    if log_dir is None:
        log_dir = os.path.join(os.path.expanduser('~'),
                               'antibiotic-selectivity', 'logs')
    os.makedirs(log_dir, exist_ok=True)
    log_path = os.path.join(log_dir, f"{name}.log")
    file_handler = FlushFileHandler(log_path, mode='a')
    file_handler.setLevel(level)
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)

    logger.info(f"Logging to file: {log_path}")
    return logger


def loc(depth: int = 1) -> str:
    """
    Return caller location string: [filename:line function_name].

    Usage:
        logger.info(f"  {loc()} Starting data fetch...")
        # Outputs: [01_fetch_chembl.py:145 process_one_pathogen] Starting data fetch...
    """
    frame = inspect.stack()[depth]
    filename = os.path.basename(frame.filename)
    return f"[{filename}:{frame.lineno} {frame.function}]"


def log_dataframe_summary(logger: logging.Logger, df, name: str):
    """
    Log a concise summary of a pandas DataFrame.

    Parameters
    ----------
    logger : logging.Logger
        Logger instance.
    df : pandas.DataFrame
        DataFrame to summarize.
    name : str
        Descriptive name for the DataFrame.
    """
    logger.info(f"DataFrame '{name}': {df.shape[0]} rows x {df.shape[1]} columns")
    logger.info(f"  Columns: {list(df.columns)}")
    logger.info(f"  Dtypes: {dict(df.dtypes)}")
    null_counts = df.isnull().sum()
    if null_counts.any():
        logger.info(f"  Null counts: {dict(null_counts[null_counts > 0])}")
    else:
        logger.info(f"  No null values")


def log_phase_start(logger: logging.Logger, phase_name: str) -> float:
    """
    Log the start of a pipeline phase. Returns the start time.
    """
    logger.info("=" * 60)
    logger.info(f" STARTING: {phase_name}")
    logger.info("=" * 60)
    return time.time()


def log_phase_end(logger: logging.Logger, phase_name: str, start_time: float):
    """
    Log the end of a pipeline phase with elapsed time.
    """
    elapsed = time.time() - start_time
    minutes = int(elapsed // 60)
    seconds = elapsed % 60
    logger.info("=" * 60)
    logger.info(f" COMPLETED: {phase_name}")
    logger.info(f" Elapsed: {minutes}m {seconds:.1f}s")
    logger.info("=" * 60)


def timed(logger: logging.Logger):
    """
    Decorator to log function execution time.

    Usage:
        @timed(logger)
        def my_function():
            ...
    """
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            logger.info(f"Starting {func.__name__}...")
            t0 = time.time()
            result = func(*args, **kwargs)
            elapsed = time.time() - t0
            logger.info(f"Finished {func.__name__} in {elapsed:.1f}s")
            return result
        return wrapper
    return decorator


def save_checkpoint(data: dict, filepath: str, logger: Optional[logging.Logger] = None):
    """
    Save a checkpoint dictionary to disk (JSON-serializable data).

    Parameters
    ----------
    data : dict
        Checkpoint data (must be JSON-serializable).
    filepath : str
        Output path.
    logger : logging.Logger, optional
        Logger for status message.
    """
    import json
    os.makedirs(os.path.dirname(filepath) if os.path.dirname(filepath) else '.', exist_ok=True)
    data['_checkpoint_time'] = time.strftime('%Y-%m-%d %H:%M:%S')
    with open(filepath, 'w') as f:
        json.dump(data, f, indent=2, default=str)
    if logger:
        logger.info(f"Checkpoint saved: {filepath}")


def load_checkpoint(filepath: str, logger: Optional[logging.Logger] = None) -> Optional[dict]:
    """
    Load a checkpoint dictionary from disk.

    Returns None if file does not exist.
    """
    import json
    if not os.path.exists(filepath):
        if logger:
            logger.info(f"No checkpoint found at {filepath}")
        return None
    with open(filepath, 'r') as f:
        data = json.load(f)
    if logger:
        logger.info(f"Checkpoint loaded: {filepath} (saved at {data.get('_checkpoint_time', 'unknown')})")
    return data
