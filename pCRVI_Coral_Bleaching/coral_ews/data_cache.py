"""
Data Caching Module
===================

Provides caching functionality to avoid re-downloading data.
Supports CSV and NetCDF file checking and management.
"""

import os
import hashlib
from pathlib import Path
from typing import Optional, Dict, List, Any, Union
from datetime import datetime
import json

import pandas as pd

from .logger import get_logger


class DataCache:
    """
    Manages data caching to avoid redundant downloads.
    
    Features:
    - Check for existing files before downloading
    - Generate cache keys based on parameters
    - Track download metadata
    - Clean up old cache files
    """
    
    def __init__(self, cache_dir: Path, metadata_file: str = "cache_metadata.json"):
        """
        Initialize data cache.
        
        Parameters
        ----------
        cache_dir : Path
            Directory for cached files
        metadata_file : str
            Name of metadata tracking file
        """
        self.logger = get_logger("coral_ews.cache")
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        
        self.metadata_path = self.cache_dir / metadata_file
        self.metadata = self._load_metadata()
        
        self.logger.info(f"Data cache initialized: {self.cache_dir}")
    
    def _load_metadata(self) -> Dict[str, Any]:
        """Load cache metadata from file."""
        if self.metadata_path.exists():
            try:
                with open(self.metadata_path, 'r') as f:
                    return json.load(f)
            except Exception as e:
                self.logger.warning(f"Failed to load cache metadata: {e}")
        return {"files": {}, "downloads": []}
    
    def _save_metadata(self):
        """Save cache metadata to file."""
        try:
            with open(self.metadata_path, 'w') as f:
                json.dump(self.metadata, f, indent=2, default=str)
        except Exception as e:
            self.logger.warning(f"Failed to save cache metadata: {e}")
    
    def generate_cache_key(
        self,
        data_type: str,
        start_date: str,
        end_date: str,
        **kwargs
    ) -> str:
        """
        Generate a unique cache key for a data request.
        
        Parameters
        ----------
        data_type : str
            Type of data (e.g., 'sst', 'ocean_color', 'era5')
        start_date : str
            Start date
        end_date : str
            End date
        **kwargs
            Additional parameters
        
        Returns
        -------
        str
            Unique cache key
        """
        key_parts = [data_type, start_date, end_date]
        for k, v in sorted(kwargs.items()):
            key_parts.append(f"{k}={v}")
        
        key_string = "_".join(key_parts)
        return hashlib.md5(key_string.encode()).hexdigest()[:12]
    
    def get_csv_path(
        self,
        data_type: str,
        start_date: str,
        end_date: str,
        suffix: str = ""
    ) -> Path:
        """
        Get the expected CSV path for cached data.
        
        Parameters
        ----------
        data_type : str
            Type of data
        start_date : str
            Start date
        end_date : str
            End date
        suffix : str
            Additional suffix for filename
        
        Returns
        -------
        Path
            Path to CSV file
        """
        filename = f"{data_type}_{start_date}_{end_date}"
        if suffix:
            filename += f"_{suffix}"
        filename += ".csv"
        return self.cache_dir / filename
    
    def check_csv_exists(
        self,
        data_type: str,
        start_date: str,
        end_date: str,
        suffix: str = ""
    ) -> Optional[Path]:
        """
        Check if cached CSV exists and return path if found.
        
        Parameters
        ----------
        data_type : str
            Type of data
        start_date : str
            Start date
        end_date : str
            End date
        suffix : str
            Additional suffix
        
        Returns
        -------
        Path or None
            Path if file exists, None otherwise
        """
        csv_path = self.get_csv_path(data_type, start_date, end_date, suffix)
        
        if csv_path.exists():
            file_size = csv_path.stat().st_size
            if file_size > 0:
                self.logger.info(f"Cache hit: {csv_path.name} ({file_size/1024:.1f} KB)")
                return csv_path
        
        self.logger.info(f"Cache miss: {csv_path.name}")
        return None
    
    def load_csv(
        self,
        data_type: str,
        start_date: str,
        end_date: str,
        suffix: str = "",
        index_col: Union[str, int] = 0,
        parse_dates: bool = True
    ) -> Optional[pd.DataFrame]:
        """
        Load cached CSV if it exists.
        
        Parameters
        ----------
        data_type : str
            Type of data
        start_date : str
            Start date
        end_date : str
            End date
        suffix : str
            Additional suffix
        index_col : str or int
            Index column
        parse_dates : bool
            Whether to parse dates
        
        Returns
        -------
        pd.DataFrame or None
            DataFrame if file exists, None otherwise
        """
        csv_path = self.check_csv_exists(data_type, start_date, end_date, suffix)
        
        if csv_path is None:
            return None
        
        try:
            df = pd.read_csv(
                csv_path,
                index_col=index_col,
                parse_dates=parse_dates if index_col is not None else False
            )
            self.logger.info(f"Loaded cached data: {len(df)} records from {csv_path.name}")
            return df
        except Exception as e:
            self.logger.warning(f"Failed to load cached CSV: {e}")
            return None
    
    def save_csv(
        self,
        df: pd.DataFrame,
        data_type: str,
        start_date: str,
        end_date: str,
        suffix: str = ""
    ) -> Path:
        """
        Save DataFrame to CSV cache.
        
        Parameters
        ----------
        df : pd.DataFrame
            Data to save
        data_type : str
            Type of data
        start_date : str
            Start date
        end_date : str
            End date
        suffix : str
            Additional suffix
        
        Returns
        -------
        Path
            Path to saved file
        """
        csv_path = self.get_csv_path(data_type, start_date, end_date, suffix)
        
        df.to_csv(csv_path)
        
        # Update metadata
        self.metadata["files"][str(csv_path)] = {
            "data_type": data_type,
            "start_date": start_date,
            "end_date": end_date,
            "rows": len(df),
            "columns": list(df.columns),
            "saved_at": datetime.utcnow().isoformat(),
            "size_bytes": csv_path.stat().st_size
        }
        self._save_metadata()
        
        self.logger.info(f"Saved to cache: {csv_path.name} ({len(df)} records)")
        return csv_path
    
    def check_netcdf_exists(
        self,
        pattern: str,
        directory: Optional[Path] = None
    ) -> List[Path]:
        """
        Find existing NetCDF files matching a pattern.
        
        Parameters
        ----------
        pattern : str
            Filename pattern (e.g., 'copernicus_transp_2020')
        directory : Path, optional
            Directory to search (default: cache_dir)
        
        Returns
        -------
        list
            List of matching file paths
        """
        search_dir = directory or self.cache_dir
        
        matching_files = []
        for f in search_dir.glob("*.nc"):
            if pattern in f.name:
                matching_files.append(f)
        
        if matching_files:
            self.logger.info(f"Found {len(matching_files)} NetCDF files matching '{pattern}'")
        
        return matching_files
    
    def find_existing_yearly_files(
        self,
        prefix: str,
        start_year: int,
        end_year: int,
        directory: Optional[Path] = None
    ) -> Dict[int, Path]:
        """
        Find existing yearly data files.
        
        Parameters
        ----------
        prefix : str
            File prefix (e.g., 'copernicus_transp')
        start_year : int
            Start year
        end_year : int
            End year
        directory : Path, optional
            Search directory
        
        Returns
        -------
        dict
            Dictionary mapping year to file path
        """
        search_dir = directory or self.cache_dir
        found_files = {}
        
        for year in range(start_year, end_year + 1):
            # Check for various date formats
            patterns = [
                f"{prefix}_{year}-01-01_{year}-12-31.nc",
                f"{prefix}_{year}-01-01_{year}-12-31.csv",
            ]
            
            for pattern in patterns:
                filepath = search_dir / pattern
                if filepath.exists():
                    found_files[year] = filepath
                    break
        
        self.logger.info(
            f"Found {len(found_files)}/{end_year - start_year + 1} "
            f"yearly files for '{prefix}'"
        )
        
        return found_files
    
    def get_missing_years(
        self,
        prefix: str,
        start_year: int,
        end_year: int,
        directory: Optional[Path] = None
    ) -> List[int]:
        """
        Get list of years that need to be downloaded.
        
        Parameters
        ----------
        prefix : str
            File prefix
        start_year : int
            Start year
        end_year : int
            End year
        directory : Path, optional
            Search directory
        
        Returns
        -------
        list
            List of years missing data
        """
        existing = self.find_existing_yearly_files(prefix, start_year, end_year, directory)
        all_years = set(range(start_year, end_year + 1))
        missing = sorted(all_years - set(existing.keys()))
        
        if missing:
            self.logger.info(f"Missing years for '{prefix}': {missing}")
        
        return missing
    
    def list_cached_files(self) -> pd.DataFrame:
        """
        List all cached files with metadata.
        
        Returns
        -------
        pd.DataFrame
            Summary of cached files
        """
        files_info = []
        
        for filepath, info in self.metadata.get("files", {}).items():
            files_info.append({
                "filename": Path(filepath).name,
                "data_type": info.get("data_type"),
                "start_date": info.get("start_date"),
                "end_date": info.get("end_date"),
                "rows": info.get("rows"),
                "size_kb": info.get("size_bytes", 0) / 1024,
                "saved_at": info.get("saved_at")
            })
        
        return pd.DataFrame(files_info)
    
    def clear_cache(self, older_than_days: Optional[int] = None):
        """
        Clear cache files.
        
        Parameters
        ----------
        older_than_days : int, optional
            Only clear files older than this many days
        """
        from datetime import timedelta
        
        cutoff = None
        if older_than_days:
            cutoff = datetime.utcnow() - timedelta(days=older_than_days)
        
        removed = 0
        for filepath, info in list(self.metadata.get("files", {}).items()):
            should_remove = True
            
            if cutoff and "saved_at" in info:
                saved_at = datetime.fromisoformat(info["saved_at"])
                if saved_at > cutoff:
                    should_remove = False
            
            if should_remove:
                try:
                    Path(filepath).unlink(missing_ok=True)
                    del self.metadata["files"][filepath]
                    removed += 1
                except Exception as e:
                    self.logger.warning(f"Failed to remove {filepath}: {e}")
        
        self._save_metadata()
        self.logger.info(f"Cleared {removed} cached files")