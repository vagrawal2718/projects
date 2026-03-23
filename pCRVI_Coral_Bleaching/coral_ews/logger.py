"""
Logging Configuration for Coral Bleaching EWS
==============================================

Provides structured logging with:
- Console and file handlers
- Color-coded output
- Performance timing
- Progress tracking
- Diagnostic context
"""

import logging
import sys
from pathlib import Path
from datetime import datetime
from typing import Optional, Dict, Any
from functools import wraps
import time
import traceback

# Global logger registry
_loggers: Dict[str, logging.Logger] = {}


class ColorFormatter(logging.Formatter):
    """Custom formatter with colors for console output."""
    
    # ANSI color codes
    COLORS = {
        'DEBUG': '\033[36m',     # Cyan
        'INFO': '\033[32m',      # Green
        'WARNING': '\033[33m',   # Yellow
        'ERROR': '\033[31m',     # Red
        'CRITICAL': '\033[35m',  # Magenta
        'RESET': '\033[0m'       # Reset
    }
    
    def format(self, record: logging.LogRecord) -> str:
        # Add color for console
        color = self.COLORS.get(record.levelname, self.COLORS['RESET'])
        reset = self.COLORS['RESET']
        
        # Format the message
        formatted = super().format(record)
        
        # Add color codes
        return f"{color}{formatted}{reset}"


class ContextLogger(logging.LoggerAdapter):
    """Logger adapter that adds context to all log messages."""
    
    def __init__(self, logger: logging.Logger, extra: Optional[Dict[str, Any]] = None):
        super().__init__(logger, extra or {})
    
    def process(self, msg: str, kwargs: Dict[str, Any]) -> tuple:
        # Add context to message if available
        if self.extra:
            context_str = " | ".join(f"{k}={v}" for k, v in self.extra.items())
            msg = f"[{context_str}] {msg}"
        return msg, kwargs
    
    def with_context(self, **kwargs) -> 'ContextLogger':
        """Create a new logger with additional context."""
        new_extra = {**self.extra, **kwargs}
        return ContextLogger(self.logger, new_extra)


def setup_logger(
    name: str = "coral_ews",
    level: int = logging.INFO,
    log_dir: Optional[Path] = None,
    log_to_file: bool = True,
    log_to_console: bool = True
) -> ContextLogger:
    """
    Set up a logger with console and file handlers.
    
    Parameters
    ----------
    name : str
        Logger name
    level : int
        Logging level (default: logging.INFO)
    log_dir : Path, optional
        Directory for log files (default: ./logs)
    log_to_file : bool
        Whether to log to file
    log_to_console : bool
        Whether to log to console
    
    Returns
    -------
    ContextLogger
        Configured logger with context support
    """
    # Check if logger already exists
    if name in _loggers:
        return ContextLogger(_loggers[name])
    
    # Create logger
    logger = logging.getLogger(name)
    logger.setLevel(level)
    logger.handlers = []  # Clear any existing handlers
    
    # Console handler with colors
    if log_to_console:
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setLevel(level)
        console_format = ColorFormatter(
            fmt='%(asctime)s | %(levelname)-8s | %(name)s | %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        console_handler.setFormatter(console_format)
        logger.addHandler(console_handler)
    
    # File handler
    if log_to_file:
        if log_dir is None:
            log_dir = Path("./logs")
        log_dir.mkdir(parents=True, exist_ok=True)
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_file = log_dir / f"{name}_{timestamp}.log"
        
        file_handler = logging.FileHandler(log_file, encoding='utf-8')
        file_handler.setLevel(logging.DEBUG)  # File gets all messages
        file_format = logging.Formatter(
            fmt='%(asctime)s | %(levelname)-8s | %(name)s | %(funcName)s:%(lineno)d | %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        file_handler.setFormatter(file_format)
        logger.addHandler(file_handler)
        
        logger.info(f"Log file created: {log_file}")
    
    # Store in registry
    _loggers[name] = logger
    
    return ContextLogger(logger)


def get_logger(name: str = "coral_ews") -> ContextLogger:
    """
    Get an existing logger or create a new one.
    
    Parameters
    ----------
    name : str
        Logger name
    
    Returns
    -------
    ContextLogger
        Logger instance
    """
    if name not in _loggers:
        return setup_logger(name)
    return ContextLogger(_loggers[name])


def log_execution_time(logger: Optional[ContextLogger] = None):
    """
    Decorator to log function execution time.
    
    Parameters
    ----------
    logger : ContextLogger, optional
        Logger to use (default: get_logger())
    """
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            _logger = logger or get_logger()
            func_name = func.__qualname__
            
            _logger.info(f"Starting: {func_name}")
            start_time = time.time()
            
            try:
                result = func(*args, **kwargs)
                elapsed = time.time() - start_time
                _logger.info(f"Completed: {func_name} in {elapsed:.2f}s")
                return result
            except Exception as e:
                elapsed = time.time() - start_time
                _logger.error(f"Failed: {func_name} after {elapsed:.2f}s - {type(e).__name__}: {e}")
                raise
        
        return wrapper
    return decorator


def log_exception(logger: Optional[ContextLogger] = None):
    """
    Decorator to log exceptions with full traceback.
    
    Parameters
    ----------
    logger : ContextLogger, optional
        Logger to use (default: get_logger())
    """
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            _logger = logger or get_logger()
            try:
                return func(*args, **kwargs)
            except Exception as e:
                _logger.error(
                    f"Exception in {func.__qualname__}: {type(e).__name__}: {e}\n"
                    f"Traceback:\n{traceback.format_exc()}"
                )
                raise
        return wrapper
    return decorator


class ProgressLogger:
    """
    Context manager for logging progress of long-running operations.
    
    Usage
    -----
    with ProgressLogger(logger, "Processing data", total=100) as progress:
        for i in range(100):
            # do work
            progress.update(1)
    """
    
    def __init__(
        self,
        logger: ContextLogger,
        description: str,
        total: Optional[int] = None,
        log_interval: int = 10
    ):
        """
        Initialize progress logger.
        
        Parameters
        ----------
        logger : ContextLogger
            Logger instance
        description : str
            Description of the operation
        total : int, optional
            Total number of items (for percentage calculation)
        log_interval : int
            Log progress every N percent (default: 10)
        """
        self.logger = logger
        self.description = description
        self.total = total
        self.log_interval = log_interval
        self.current = 0
        self.start_time = None
        self.last_logged_percent = -log_interval
    
    def __enter__(self) -> 'ProgressLogger':
        self.start_time = time.time()
        self.logger.info(f"Started: {self.description}")
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        elapsed = time.time() - self.start_time
        if exc_type is None:
            self.logger.info(f"Completed: {self.description} in {elapsed:.2f}s")
        else:
            self.logger.error(f"Failed: {self.description} after {elapsed:.2f}s - {exc_val}")
        return False  # Don't suppress exceptions
    
    def update(self, n: int = 1):
        """Update progress by n items."""
        self.current += n
        
        if self.total:
            percent = (self.current / self.total) * 100
            if percent - self.last_logged_percent >= self.log_interval:
                elapsed = time.time() - self.start_time
                rate = self.current / elapsed if elapsed > 0 else 0
                eta = (self.total - self.current) / rate if rate > 0 else 0
                
                self.logger.info(
                    f"{self.description}: {percent:.0f}% ({self.current}/{self.total}) "
                    f"| Rate: {rate:.1f}/s | ETA: {eta:.0f}s"
                )
                self.last_logged_percent = percent
    
    def set_description(self, description: str):
        """Update the description."""
        self.description = description


class DiagnosticContext:
    """
    Context manager for adding diagnostic information to logs.
    
    Usage
    -----
    with DiagnosticContext(logger, dataset="MODIS", region="ANI"):
        # All logs within this block will include the context
        logger.info("Processing data")  # -> [dataset=MODIS | region=ANI] Processing data
    """
    
    def __init__(self, logger: ContextLogger, **context):
        self.logger = logger
        self.context = context
        self.original_extra = None
    
    def __enter__(self) -> ContextLogger:
        self.original_extra = dict(self.logger.extra)
        self.logger.extra.update(self.context)
        return self.logger
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.logger.extra = self.original_extra
        return False


def create_diagnostic_report(
    logger: ContextLogger,
    error: Exception,
    context: Optional[Dict[str, Any]] = None
) -> str:
    """
    Create a comprehensive diagnostic report for an error.
    
    Parameters
    ----------
    logger : ContextLogger
        Logger instance
    error : Exception
        The exception that occurred
    context : dict, optional
        Additional context information
    
    Returns
    -------
    str
        Formatted diagnostic report
    """
    import platform
    
    report_lines = [
        "",
        "=" * 70,
        "DIAGNOSTIC REPORT",
        "=" * 70,
        f"Timestamp: {datetime.utcnow().isoformat()}Z",
        "",
        "SYSTEM INFORMATION",
        "-" * 40,
        f"Python Version: {sys.version}",
        f"Platform: {platform.platform()}",
        f"Architecture: {platform.machine()}",
        "",
        "ERROR DETAILS",
        "-" * 40,
        f"Exception Type: {type(error).__name__}",
        f"Exception Message: {str(error)}",
        "",
        "TRACEBACK",
        "-" * 40,
        traceback.format_exc(),
    ]
    
    if context:
        report_lines.extend([
            "CONTEXT",
            "-" * 40,
        ])
        for key, value in context.items():
            report_lines.append(f"  {key}: {value}")
    
    report_lines.extend([
        "",
        "=" * 70,
        "END OF DIAGNOSTIC REPORT",
        "=" * 70,
    ])
    
    report = "\n".join(report_lines)
    logger.error(report)
    
    return report
