"""
Custom Exceptions for Coral Bleaching EWS
==========================================

Hierarchical exception classes for granular error handling and diagnostics.
Each exception includes context, suggestions, and diagnostic information.
"""

from typing import Optional, Dict, Any
from datetime import datetime
import traceback
import sys


class CoralEWSError(Exception):
    """
    Base exception class for all Coral EWS errors.
    
    Provides structured error information including:
    - Error message
    - Error code for programmatic handling
    - Context dictionary for debugging
    - Suggestions for resolution
    - Timestamp
    - Full traceback
    """
    
    def __init__(
        self,
        message: str,
        error_code: str = "CORAL_EWS_ERROR",
        context: Optional[Dict[str, Any]] = None,
        suggestion: Optional[str] = None,
        original_exception: Optional[Exception] = None
    ):
        self.message = message
        self.error_code = error_code
        self.context = context or {}
        self.suggestion = suggestion
        self.original_exception = original_exception
        self.timestamp = datetime.utcnow().isoformat()
        self.traceback_str = traceback.format_exc()
        
        # Build comprehensive error message
        full_message = self._build_full_message()
        super().__init__(full_message)
    
    def _build_full_message(self) -> str:
        """Build a comprehensive, diagnostic error message."""
        lines = [
            "",
            "=" * 70,
            f"CORAL EWS ERROR: {self.error_code}",
            "=" * 70,
            f"Timestamp: {self.timestamp}",
            f"Message: {self.message}",
        ]
        
        if self.context:
            lines.append("")
            lines.append("Context:")
            for key, value in self.context.items():
                # Truncate very long values
                str_value = str(value)
                if len(str_value) > 200:
                    str_value = str_value[:200] + "..."
                lines.append(f"  - {key}: {str_value}")
        
        if self.suggestion:
            lines.append("")
            lines.append(f"Suggestion: {self.suggestion}")
        
        if self.original_exception:
            lines.append("")
            lines.append(f"Original Exception: {type(self.original_exception).__name__}")
            lines.append(f"Original Message: {str(self.original_exception)}")
        
        lines.append("=" * 70)
        
        return "\n".join(lines)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert exception to dictionary for logging/serialization."""
        return {
            "error_code": self.error_code,
            "message": self.message,
            "context": self.context,
            "suggestion": self.suggestion,
            "timestamp": self.timestamp,
            "original_exception": str(self.original_exception) if self.original_exception else None,
            "traceback": self.traceback_str
        }


class DataAcquisitionError(CoralEWSError):
    """
    Errors during data acquisition from any source.
    
    Covers:
    - Network failures
    - Authentication issues
    - Data not found
    - Timeout errors
    - Rate limiting
    """
    
    def __init__(
        self,
        message: str,
        source: str,
        context: Optional[Dict[str, Any]] = None,
        suggestion: Optional[str] = None,
        original_exception: Optional[Exception] = None
    ):
        context = context or {}
        context["data_source"] = source
        
        if suggestion is None:
            suggestion = self._get_default_suggestion(source)
        
        super().__init__(
            message=message,
            error_code=f"DATA_ACQUISITION_{source.upper()}",
            context=context,
            suggestion=suggestion,
            original_exception=original_exception
        )
    
    @staticmethod
    def _get_default_suggestion(source: str) -> str:
        """Get default suggestion based on data source."""
        suggestions = {
            "GEE": "Check Earth Engine authentication with 'earthengine authenticate'. "
                   "Verify your GEE project ID and quotas.",
            "COPERNICUS": "Verify Copernicus Marine credentials. Register at "
                          "https://data.marine.copernicus.eu if needed. Check network connectivity.",
            "NOAA": "Check NOAA server status. Try alternative mirror or retry later.",
            "ERDDAP": "ERDDAP server may be temporarily unavailable. Retry with exponential backoff.",
            "LOCAL": "Check file path exists and has read permissions."
        }
        return suggestions.get(source.upper(), "Check data source availability and credentials.")


class GEEError(CoralEWSError):
    """
    Google Earth Engine specific errors.
    
    Covers:
    - Authentication failures
    - Invalid asset IDs
    - Computation timeouts
    - Export failures
    - Memory limits exceeded
    """
    
    def __init__(
        self,
        message: str,
        asset_id: Optional[str] = None,
        operation: Optional[str] = None,
        context: Optional[Dict[str, Any]] = None,
        suggestion: Optional[str] = None,
        original_exception: Optional[Exception] = None
    ):
        context = context or {}
        if asset_id:
            context["asset_id"] = asset_id
        if operation:
            context["operation"] = operation
        
        # Detect specific GEE error types and provide targeted suggestions
        if suggestion is None:
            suggestion = self._diagnose_gee_error(message, original_exception)
        
        super().__init__(
            message=message,
            error_code="GEE_ERROR",
            context=context,
            suggestion=suggestion,
            original_exception=original_exception
        )
    
    @staticmethod
    def _diagnose_gee_error(message: str, original: Optional[Exception]) -> str:
        """Diagnose GEE error and provide specific suggestion."""
        msg_lower = message.lower() if message else ""
        orig_str = str(original).lower() if original else ""
        combined = msg_lower + orig_str
        
        if "not found" in combined or "does not exist" in combined:
            return ("Asset ID may be incorrect or inaccessible. Verify the asset exists in "
                    "GEE Data Catalog: https://developers.google.com/earth-engine/datasets")
        elif "timeout" in combined or "deadline" in combined:
            return ("Computation timed out. Try: (1) Reduce region size, (2) Use coarser scale, "
                    "(3) Export to Drive instead of getInfo(), (4) Split into smaller date ranges.")
        elif "memory" in combined or "limit" in combined:
            return ("Memory limit exceeded. Try: (1) Process smaller regions, (2) Use reduceRegion "
                    "with bestEffort=True, (3) Export results instead of inline computation.")
        elif "authenticate" in combined or "credential" in combined:
            return ("Authentication failed. Run 'earthengine authenticate' in terminal and follow prompts.")
        elif "permission" in combined or "access" in combined:
            return ("Permission denied. Ensure you have access to this asset and your GEE account is active.")
        else:
            return ("Check GEE status at https://code.earthengine.google.com. "
                    "Verify asset ID and try reducing computation complexity.")


class CopernicusError(CoralEWSError):
    """
    Copernicus Marine Data Store specific errors.
    
    Covers:
    - Authentication failures
    - Invalid dataset IDs
    - Variable not found
    - Spatial/temporal bounds errors
    - Download failures
    """
    
    def __init__(
        self,
        message: str,
        dataset_id: Optional[str] = None,
        variables: Optional[list] = None,
        context: Optional[Dict[str, Any]] = None,
        suggestion: Optional[str] = None,
        original_exception: Optional[Exception] = None
    ):
        context = context or {}
        if dataset_id:
            context["dataset_id"] = dataset_id
        if variables:
            context["variables"] = variables
        
        if suggestion is None:
            suggestion = self._diagnose_copernicus_error(message, original_exception)
        
        super().__init__(
            message=message,
            error_code="COPERNICUS_ERROR",
            context=context,
            suggestion=suggestion,
            original_exception=original_exception
        )
    
    @staticmethod
    def _diagnose_copernicus_error(message: str, original: Optional[Exception]) -> str:
        """Diagnose Copernicus error and provide specific suggestion."""
        msg_lower = message.lower() if message else ""
        orig_str = str(original).lower() if original else ""
        combined = msg_lower + orig_str
        
        if "credential" in combined or "login" in combined or "401" in combined:
            return ("Authentication failed. Run 'copernicusmarine login' or set environment "
                    "variables COPERNICUSMARINE_SERVICE_USERNAME and COPERNICUSMARINE_SERVICE_PASSWORD.")
        elif "not found" in combined or "404" in combined:
            return ("Dataset or variable not found. Verify dataset_id at "
                    "https://data.marine.copernicus.eu. Use 'copernicusmarine describe' to list available datasets.")
        elif "bound" in combined or "range" in combined:
            return ("Spatial or temporal bounds invalid. Check that requested area/dates are within dataset coverage.")
        elif "timeout" in combined or "connection" in combined:
            return ("Network error. Check internet connection. Copernicus servers may be busy - retry with backoff.")
        else:
            return ("Check Copernicus Marine service status. Verify dataset_id and variables using "
                    "'copernicusmarine describe --dataset-id <id>'.")


class ValidationError(CoralEWSError):
    """
    Data validation errors.
    
    Covers:
    - Missing required data
    - Data type mismatches
    - Out of range values
    - Inconsistent dimensions
    - Invalid formats
    """
    
    def __init__(
        self,
        message: str,
        field: Optional[str] = None,
        expected: Optional[Any] = None,
        actual: Optional[Any] = None,
        context: Optional[Dict[str, Any]] = None,
        suggestion: Optional[str] = None,
        original_exception: Optional[Exception] = None
    ):
        context = context or {}
        if field:
            context["field"] = field
        if expected is not None:
            context["expected"] = str(expected)
        if actual is not None:
            context["actual"] = str(actual)
        
        super().__init__(
            message=message,
            error_code="VALIDATION_ERROR",
            context=context,
            suggestion=suggestion or "Review input data and ensure it meets required specifications.",
            original_exception=original_exception
        )


class ProcessingError(CoralEWSError):
    """
    Data processing and computation errors.
    
    Covers:
    - DHW calculation failures
    - Resampling errors
    - Interpolation failures
    - Feature engineering errors
    - Array computation errors
    """
    
    def __init__(
        self,
        message: str,
        operation: str,
        context: Optional[Dict[str, Any]] = None,
        suggestion: Optional[str] = None,
        original_exception: Optional[Exception] = None
    ):
        context = context or {}
        context["operation"] = operation
        
        super().__init__(
            message=message,
            error_code=f"PROCESSING_{operation.upper().replace(' ', '_')}",
            context=context,
            suggestion=suggestion or f"Review input data for '{operation}' operation. Check for NaN/Inf values.",
            original_exception=original_exception
        )


class ModelError(CoralEWSError):
    """
    Machine learning model errors.
    
    Covers:
    - Training failures
    - Prediction errors
    - Invalid hyperparameters
    - Cross-validation errors
    - Feature mismatch
    """
    
    def __init__(
        self,
        message: str,
        model_type: Optional[str] = None,
        stage: Optional[str] = None,  # 'training', 'prediction', 'validation'
        context: Optional[Dict[str, Any]] = None,
        suggestion: Optional[str] = None,
        original_exception: Optional[Exception] = None
    ):
        context = context or {}
        if model_type:
            context["model_type"] = model_type
        if stage:
            context["stage"] = stage
        
        super().__init__(
            message=message,
            error_code=f"MODEL_{(stage or 'GENERAL').upper()}",
            context=context,
            suggestion=suggestion or "Check training data quality, feature scaling, and hyperparameters.",
            original_exception=original_exception
        )


class NetworkError(DataAcquisitionError):
    """Specific network-related errors with retry guidance."""
    
    def __init__(
        self,
        message: str,
        url: Optional[str] = None,
        status_code: Optional[int] = None,
        context: Optional[Dict[str, Any]] = None,
        original_exception: Optional[Exception] = None
    ):
        context = context or {}
        if url:
            context["url"] = url
        if status_code:
            context["status_code"] = status_code
        
        suggestion = self._get_network_suggestion(status_code)
        
        super().__init__(
            message=message,
            source="NETWORK",
            context=context,
            suggestion=suggestion,
            original_exception=original_exception
        )
    
    @staticmethod
    def _get_network_suggestion(status_code: Optional[int]) -> str:
        """Get suggestion based on HTTP status code."""
        if status_code is None:
            return "Check network connectivity and firewall settings."
        elif status_code == 401:
            return "Authentication required. Check credentials."
        elif status_code == 403:
            return "Access forbidden. Verify permissions and API keys."
        elif status_code == 404:
            return "Resource not found. Verify URL and resource availability."
        elif status_code == 429:
            return "Rate limited. Implement exponential backoff and retry."
        elif status_code >= 500:
            return "Server error. Service may be temporarily unavailable. Retry later."
        else:
            return f"HTTP error {status_code}. Check request parameters."


class FileIOError(CoralEWSError):
    """File I/O specific errors."""
    
    def __init__(
        self,
        message: str,
        file_path: Optional[str] = None,
        operation: Optional[str] = None,  # 'read', 'write', 'delete'
        context: Optional[Dict[str, Any]] = None,
        original_exception: Optional[Exception] = None
    ):
        context = context or {}
        if file_path:
            context["file_path"] = file_path
        if operation:
            context["operation"] = operation
        
        super().__init__(
            message=message,
            error_code=f"FILE_{(operation or 'IO').upper()}",
            context=context,
            suggestion="Check file path, permissions, and available disk space.",
            original_exception=original_exception
        )
