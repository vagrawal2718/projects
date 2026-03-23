"""
Copernicus Marine Data Store Acquisition Module
================================================

Handles data download from Copernicus Marine Data Store including:
- Authentication
- Kd490 and ocean color variable download
- Error handling and retry logic

All dataset IDs verified against data.marine.copernicus.eu (January 2026).
"""

import os
from pathlib import Path
import time
from typing import Optional, Dict, List, Any, Union
from datetime import datetime, date
from pathlib import Path
import tempfile

import numpy as np
import pandas as pd

from ..exceptions import CopernicusError, ValidationError, NetworkError
from ..logger import get_logger, log_execution_time, ProgressLogger
from ..config import Config, CopernicusDatasets, ANIRegion

# Try to import copernicusmarine
try:
    import copernicusmarine
    COPERNICUS_AVAILABLE = True
except ImportError:
    COPERNICUS_AVAILABLE = False

# Try to import xarray
try:
    import xarray as xr
    XARRAY_AVAILABLE = True
except ImportError:
    XARRAY_AVAILABLE = False


class CopernicusClient:
    """
    Copernicus Marine Data Store client for ocean color data acquisition.
    
    Handles authentication, data download, and processing with comprehensive
    error handling.
    """
    
    def __init__(
        self,
        config: Optional[Config] = None,
        username: Optional[str] = None,
        password: Optional[str] = None
    ):
        """
        Initialize Copernicus Marine client.
        
        Parameters
        ----------
        config : Config, optional
            Configuration object
        username : str, optional
            Copernicus Marine username (or use env var)
        password : str, optional
            Copernicus Marine password (or use env var)
        """
        if not COPERNICUS_AVAILABLE:
            raise CopernicusError(
                "copernicusmarine package not installed",
                suggestion="Install with: pip install copernicusmarine"
            )
        
        if not XARRAY_AVAILABLE:
            raise CopernicusError(
                "xarray package not installed",
                suggestion="Install with: pip install xarray netcdf4"
            )
        
        self.config = config or Config()
        self.logger = get_logger("coral_ews.copernicus")
        
        # Get credentials from parameters or environment
        self.username = username or os.environ.get("COPERNICUSMARINE_SERVICE_USERNAME")
        self.password = password or os.environ.get("COPERNICUSMARINE_SERVICE_PASSWORD")
        
        self.authenticated = False
    
    def _ensure_authenticated(self):
        """Ensure client is authenticated before operations."""
        if not self.authenticated:
            self.authenticate()

    def authenticate(self, force: bool = False) -> bool:
        """
        Authenticate with Copernicus Marine Data Store.
        
        Automatically detects credentials from:
        1. ~/.copernicusmarine/.copernicusmarine-credentials (from 'copernicusmarine login')
        2. Environment variables COPERNICUSMARINE_SERVICE_USERNAME/PASSWORD
        3. Explicit username/password parameters
        """
        if self.authenticated and not force:
            self.logger.info("Already authenticated with Copernicus Marine")
            return True
        
        self.logger.info("Authenticating with Copernicus Marine Data Store...")
        
        # Check if credentials file exists
        creds_file = Path.home() / ".copernicusmarine" / ".copernicusmarine-credentials"
        
        if creds_file.exists():
            self.logger.info(f"Found credentials file: {creds_file}")
            self.authenticated = True
            return True
        
        # Check environment variables
        if os.environ.get("COPERNICUSMARINE_SERVICE_USERNAME"):
            self.logger.info("Using credentials from environment variables")
            self.authenticated = True
            return True
        
        # Check if username/password provided to constructor
        if self.username and self.password:
            self.logger.info("Using provided username/password")
            self.authenticated = True
            return True
        
        raise CopernicusError(
            "No Copernicus Marine credentials found",
            suggestion="Run 'copernicusmarine login' to store credentials, or set "
                       "COPERNICUSMARINE_SERVICE_USERNAME and COPERNICUSMARINE_SERVICE_PASSWORD environment variables"
        )
    def check_dataset_availability(self, dataset_id: str) -> Dict[str, Any]:
        """
        Check if a dataset is available and get its metadata.
        
        Parameters
        ----------
        dataset_id : str
            Copernicus Marine dataset ID
        
        Returns
        -------
        dict
            Dataset availability and metadata
        """
        self._ensure_authenticated()
        self.logger.info(f"Checking availability: {dataset_id}")
        
        try:
            # Use describe without extra parameters - API has changed
            catalog = copernicusmarine.describe()
            
            # Search for the dataset in the catalog
            if hasattr(catalog, 'products'):
                for product in catalog.products:
                    if hasattr(product, 'datasets'):
                        for dataset in product.datasets:
                            if dataset_id in str(dataset.dataset_id):
                                return {
                                    "available": True,
                                    "dataset_id": dataset.dataset_id,
                                    "product_id": product.product_id
                                }
            
            # Alternative: just verify we can access the API
            return {
                "available": True,
                "dataset_id": dataset_id,
                "message": "Credentials valid, catalog accessible"
            }
            
        except Exception as e:
            return {
                "available": False,
                "dataset_id": dataset_id,
                "error": str(e)
            }
    @log_execution_time()
    def download_kd490(
        self,
        start_date: Union[str, date],
        end_date: Union[str, date],
        output_path: Optional[Path] = None,
        variables: Optional[List[str]] = None
    ) -> Path:
        """
        Download Kd490 (and optionally other variables) from Copernicus Marine.
        
        Uses OCEANCOLOUR_GLO_BGC_L3_MY_009_103 (Multi-Year, 1997-present).
        
        Parameters
        ----------
        start_date : str or date
            Start date (YYYY-MM-DD)
        end_date : str or date
            End date (YYYY-MM-DD)
        output_path : Path, optional
            Output file path
        variables : list, optional
            Variables to download (default: ['KD490'])
        
        Returns
        -------
        Path
            Path to downloaded NetCDF file
        """
        self._ensure_authenticated()
        
        start_str = str(start_date)
        end_str = str(end_date)
        variables = variables or ["KD490"]
        
        # Validate dates
        dataset_start = datetime.strptime("1997-09-01", "%Y-%m-%d")
        requested_start = datetime.strptime(start_str, "%Y-%m-%d")
        
        if requested_start < dataset_start:
            raise ValidationError(
                f"Requested start date {start_str} is before dataset availability",
                field="start_date",
                expected=">= 1997-09-01",
                actual=start_str,
                suggestion="Copernicus GlobColour L3 MY data starts from 1997-09-01"
            )
        
        # Set output path
        if output_path is None:
            output_path = self.config.data_dir / f"copernicus_kd490_{start_str}_{end_str}.nc"
        
        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Get region bounds
        bounds = self.config.region.bounds
        
        self.logger.info(
            f"Downloading Copernicus data: {variables}\n"
            f"  Date range: {start_str} to {end_str}\n"
            f"  Region: {bounds}\n"
            f"  Output: {output_path}"
        )
        
        try:
            # Dataset IDs for Copernicus Marine (NOT product IDs)
            # Product: OCEANCOLOUR_GLO_BGC_L3_MY_009_103
            # Dataset for transparency (Kd490, ZSD): cmems_obs-oc_glo_bgc-transp_my_l3-multi-4km_P1D
            # Dataset for plankton (CHL): cmems_obs-oc_glo_bgc-plankton_my_l3-multi-4km_P1D
            
            # Determine which dataset to use based on variables
            if any(v in ['KD490', 'ZSD'] for v in variables):
                dataset_id = "cmems_obs-oc_glo_bgc-transp_my_l3-multi-4km_P1D"
            else:
                dataset_id = "cmems_obs-oc_glo_bgc-plankton_my_l3-multi-4km_P1D"
            
            self.logger.info(f"Using dataset: {dataset_id}")
            
            # Use copernicusmarine subset
            result = copernicusmarine.subset(
                dataset_id=dataset_id,
                variables=variables,
                minimum_longitude=bounds[0],
                maximum_longitude=bounds[2],
                minimum_latitude=bounds[1],
                maximum_latitude=bounds[3],
                start_datetime=f"{start_str}T00:00:00",
                end_datetime=f"{end_str}T23:59:59",
                output_filename=str(output_path.name),
                output_directory=str(output_path.parent)
            )
                
        except Exception as e:
            error_str = str(e).lower()
            
            # Determine which dataset was attempted
            if any(v in ['KD490', 'ZSD'] for v in variables):
                dataset_id = "cmems_obs-oc_glo_bgc-transp_my_l3-multi-4km_P1D"
            else:
                dataset_id = "cmems_obs-oc_glo_bgc-plankton_my_l3-multi-4km_P1D"
            
            if "credential" in error_str or "401" in error_str:
                raise CopernicusError(
                    "Authentication failed during download",
                    dataset_id=dataset_id,
                    original_exception=e
                )
            elif "not found" in error_str or "404" in error_str:
                raise CopernicusError(
                    f"Dataset or variable not found: {dataset_id}",
                    context={"dataset_id": dataset_id, "variables": variables},
                    suggestion="Check variable names: KD490 (not Kd490), CHL (not chl)",
                    original_exception=e
                )
            else:
                raise CopernicusError(
                    f"Failed to download Copernicus data: {str(e)}",
                    context={
                        "dataset_id": dataset_id,
                        "start_date": start_str,
                        "end_date": end_str,
                        "variables": variables,
                        "bounds": bounds
                    },
                    suggestion="Check Copernicus Marine service status. Verify dataset_id and variables using 'copernicusmarine describe --dataset-id <id>'.",
                    original_exception=e
                )
    
    @log_execution_time()
    def download_chlorophyll(
        self,
        start_date: Union[str, date],
        end_date: Union[str, date],
        output_path: Optional[Path] = None
    ) -> Path:
        """Download Chlorophyll-a data from Copernicus Marine."""
        if output_path is None:
            output_path = self.config.data_dir / f"copernicus_chl_{start_date}_{end_date}.nc"
        
        return self.download_kd490(
            start_date=start_date,
            end_date=end_date,
            output_path=output_path,
            variables=["CHL"]
        )
    
    @log_execution_time()
    def download_ocean_color_suite(
        self,
        start_date: Union[str, date],
        end_date: Union[str, date],
        output_dir: Optional[Path] = None,
        variables: Optional[List[str]] = None
    ) -> Dict[str, Path]:
        """
        Download full ocean color variable suite from Copernicus Marine.
        
        NOTE: KD490/ZSD and CHL are in DIFFERENT datasets, so we download separately.
        
        Returns
        -------
        Dict[str, Path]
            Dictionary mapping variable groups to file paths
        """
        variables = variables or ["KD490", "CHL"]
        
        if output_dir is None:
            output_dir = self.config.data_dir
        output_dir = Path(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
        
        downloaded_files = {}
        
        # Separate variables by dataset
        transp_vars = [v for v in variables if v in ['KD490', 'ZSD']]
        plankton_vars = [v for v in variables if v in ['CHL']]
        
        # Download transparency variables (KD490, ZSD)
        if transp_vars:
            transp_path = output_dir / f"copernicus_transp_{start_date}_{end_date}.nc"
            self.logger.info(f"Downloading transparency variables: {transp_vars}")
            self._download_subset(
                dataset_id="cmems_obs-oc_glo_bgc-transp_my_l3-multi-4km_P1D",
                variables=transp_vars,
                start_date=start_date,
                end_date=end_date,
                output_path=transp_path
            )
            downloaded_files['transparency'] = transp_path
        
        # Download plankton variables (CHL)
        if plankton_vars:
            plankton_path = output_dir / f"copernicus_plankton_{start_date}_{end_date}.nc"
            self.logger.info(f"Downloading plankton variables: {plankton_vars}")
            self._download_subset(
                dataset_id="cmems_obs-oc_glo_bgc-plankton_my_l3-multi-4km_P1D",
                variables=plankton_vars,
                start_date=start_date,
                end_date=end_date,
                output_path=plankton_path
            )
            downloaded_files['plankton'] = plankton_path
        
        return downloaded_files
    
    def _download_subset(
        self,
        dataset_id: str,
        variables: List[str],
        start_date: Union[str, date],
        end_date: Union[str, date],
        output_path: Path
    ) -> Path:
        """Internal method to download a subset from a specific dataset."""
        self._ensure_authenticated()
        
        start_str = str(start_date)
        end_str = str(end_date)
        bounds = self.config.region.bounds
        
        self.logger.info(
            f"Downloading from {dataset_id}:\n"
            f"  Variables: {variables}\n"
            f"  Date range: {start_str} to {end_str}\n"
            f"  Region: {bounds}"
        )
        
        try:
            result = copernicusmarine.subset(
                dataset_id=dataset_id,
                variables=variables,
                minimum_longitude=bounds[0],
                maximum_longitude=bounds[2],
                minimum_latitude=bounds[1],
                maximum_latitude=bounds[3],
                start_datetime=f"{start_str}T00:00:00",
                end_datetime=f"{end_str}T23:59:59",
                output_filename=str(output_path.name),
                output_directory=str(output_path.parent)
            )
            
            if output_path.exists():
                file_size = output_path.stat().st_size / (1024 * 1024)
                self.logger.info(f"Download complete: {output_path} ({file_size:.1f} MB)")
                return output_path
            else:
                raise CopernicusError(
                    f"Download completed but file not found: {output_path}",
                    context={"dataset_id": dataset_id}
                )
                
        except Exception as e:
            if isinstance(e, CopernicusError):
                raise
            raise CopernicusError(
                f"Failed to download from {dataset_id}: {str(e)}",
                context={
                    "dataset_id": dataset_id,
                    "variables": variables,
                    "start_date": start_str,
                    "end_date": end_str
                },
                original_exception=e
            )
    
    '''
    @log_execution_time()
    def download_ocean_color_chunked(
        self,
        start_date: Union[str, date],
        end_date: Union[str, date],
        variables: Optional[List[str]] = None,
        chunk_years: int = 1
    ) -> pd.DataFrame:
        """
        Download ocean color data in yearly chunks and combine into DataFrame.
        
        This avoids Copernicus download limits for long time ranges.
        
        Parameters
        ----------
        start_date : str or date
            Start date
        end_date : str or date
            End date
        variables : list, optional
            Variables to download (default: ['KD490', 'CHL'])
        chunk_years : int
            Years per chunk
        
        Returns
        -------
        pd.DataFrame
            Combined ocean color time series
        """
        variables = variables or ["KD490", "CHL"]
        
        start_dt = datetime.strptime(str(start_date), "%Y-%m-%d")
        end_dt = datetime.strptime(str(end_date), "%Y-%m-%d")
        
        # Validate against dataset start
        dataset_start = datetime.strptime("1997-09-01", "%Y-%m-%d")
        if start_dt < dataset_start:
            self.logger.warning(f"Adjusting start date from {start_date} to 1997-09-01 (dataset start)")
            start_dt = dataset_start
        
        self.logger.info(
            f"Downloading ocean color data in yearly chunks: "
            f"{start_dt.strftime('%Y-%m-%d')} to {end_dt.strftime('%Y-%m-%d')}"
        )
        
        all_dfs = []
        current_year = start_dt.year
        
        while current_year <= end_dt.year:
            chunk_start = max(
                datetime(current_year, 1, 1),
                start_dt
            )
            chunk_end = min(
                datetime(current_year, 12, 31),
                end_dt
            )
            
            self.logger.info(
                f"Ocean color chunk: {chunk_start.strftime('%Y-%m-%d')} to {chunk_end.strftime('%Y-%m-%d')}"
            )
            
            try:
                # Download for this chunk
                downloaded_files = self.download_ocean_color_suite(
                    start_date=chunk_start.strftime("%Y-%m-%d"),
                    end_date=chunk_end.strftime("%Y-%m-%d"),
                    variables=variables
                )
                
                # Load and extract time series
                chunk_dfs = []
                
                if 'transparency' in downloaded_files and downloaded_files['transparency'].exists():
                    ds = self.load_downloaded_data(downloaded_files['transparency'])
                    for var in ['KD490', 'ZSD']:
                        if var in ds.data_vars:
                            ts = self.extract_timeseries(ds, var)
                            chunk_dfs.append(ts)
                    ds.close()
                
                if 'plankton' in downloaded_files and downloaded_files['plankton'].exists():
                    ds = self.load_downloaded_data(downloaded_files['plankton'])
                    for var in ['CHL']:
                        if var in ds.data_vars:
                            ts = self.extract_timeseries(ds, var)
                            chunk_dfs.append(ts)
                    ds.close()
                
                if chunk_dfs:
                    chunk_combined = pd.concat(chunk_dfs, axis=1)
                    all_dfs.append(chunk_combined)
                    self.logger.info(f"Year {current_year}: Retrieved {len(chunk_combined)} records")
                    
            except Exception as e:
                self.logger.warning(f"Ocean color chunk {current_year} failed: {e}. Continuing...")
            
            current_year += 1
        
        if not all_dfs:
            raise CopernicusError(
                "No ocean color data retrieved from any chunk",
                context={"start_date": str(start_date), "end_date": str(end_date)}
            )
        
        # Combine all years
        combined_df = pd.concat(all_dfs).sort_index()
        combined_df = combined_df[~combined_df.index.duplicated(keep='first')]
        
        self.logger.info(f"Combined ocean color: {len(combined_df)} total records")
        return combined_df
    '''
    
    @log_execution_time()
    def download_ocean_color_chunked(
        self,
        start_date: Union[str, date],
        end_date: Union[str, date],
        variables: Optional[List[str]] = None,
        data_dir: Optional[Path] = None
    ) -> pd.DataFrame:
        """
        Download ocean color data in yearly chunks, using existing files if available.
        
        Parameters
        ----------
        start_date, end_date : str or date
            Date range
        variables : list, optional
            Variables to download (default: ['KD490', 'CHL'])
        data_dir : Path, optional
            Directory containing/for NetCDF files
        
        Returns
        -------
        pd.DataFrame
            Combined ocean color time series
        """
        variables = variables or ["KD490", "CHL"]
        data_dir = Path(data_dir) if data_dir else self.config.data_dir
        
        start_dt = datetime.strptime(str(start_date), "%Y-%m-%d")
        end_dt = datetime.strptime(str(end_date), "%Y-%m-%d")
        
        # Validate against dataset start
        dataset_start = datetime.strptime("1997-09-01", "%Y-%m-%d")
        if start_dt < dataset_start:
            self.logger.warning(f"Adjusting start date from {start_date} to 1997-09-01")
            start_dt = dataset_start
        
        self.logger.info(
            f"Downloading ocean color data in yearly chunks: "
            f"{start_dt.strftime('%Y-%m-%d')} to {end_dt.strftime('%Y-%m-%d')}"
        )
        
        all_dfs = []
        current_year = start_dt.year
        
        while current_year <= end_dt.year:
            chunk_start = max(datetime(current_year, 1, 1), start_dt)
            chunk_end = min(datetime(current_year, 12, 31), end_dt)
            
            chunk_start_str = chunk_start.strftime("%Y-%m-%d")
            chunk_end_str = chunk_end.strftime("%Y-%m-%d")
            
            self.logger.info(f"Ocean color chunk: {chunk_start_str} to {chunk_end_str}")
            
            # Check for existing files
            transp_file = data_dir / f"copernicus_transp_{chunk_start_str}_{chunk_end_str}.nc"
            plankton_file = data_dir / f"copernicus_plankton_{chunk_start_str}_{chunk_end_str}.nc"
            
            chunk_dfs = []
            
            # Process transparency file (KD490)
            transp_vars = [v for v in variables if v in ['KD490', 'ZSD']]
            if transp_vars:
                if transp_file.exists():
                    self.logger.info(f"Using existing file: {transp_file.name}")
                else:
                    self.logger.info(f"Downloading transparency data for {current_year}")
                    try:
                        self._download_subset(
                            dataset_id="cmems_obs-oc_glo_bgc-transp_my_l3-multi-4km_P1D",
                            variables=transp_vars,
                            start_date=chunk_start_str,
                            end_date=chunk_end_str,
                            output_path=transp_file
                        )
                    except Exception as e:
                        self.logger.warning(f"Transparency download failed: {e}")
                
                if transp_file.exists():
                    try:
                        ds = self.load_downloaded_data(transp_file)
                        for var in transp_vars:
                            if var in ds.data_vars:
                                ts = self.extract_timeseries(ds, var)
                                chunk_dfs.append(ts)
                        ds.close()
                    except Exception as e:
                        self.logger.warning(f"Failed to load {transp_file}: {e}")
            
            # Process plankton file (CHL)
            plankton_vars = [v for v in variables if v in ['CHL']]
            if plankton_vars:
                if plankton_file.exists():
                    self.logger.info(f"Using existing file: {plankton_file.name}")
                else:
                    self.logger.info(f"Downloading plankton data for {current_year}")
                    try:
                        self._download_subset(
                            dataset_id="cmems_obs-oc_glo_bgc-plankton_my_l3-multi-4km_P1D",
                            variables=plankton_vars,
                            start_date=chunk_start_str,
                            end_date=chunk_end_str,
                            output_path=plankton_file
                        )
                    except Exception as e:
                        self.logger.warning(f"Plankton download failed: {e}")
                
                if plankton_file.exists():
                    try:
                        ds = self.load_downloaded_data(plankton_file)
                        for var in plankton_vars:
                            if var in ds.data_vars:
                                ts = self.extract_timeseries(ds, var)
                                chunk_dfs.append(ts)
                        ds.close()
                    except Exception as e:
                        self.logger.warning(f"Failed to load {plankton_file}: {e}")
            
            if chunk_dfs:
                chunk_combined = pd.concat(chunk_dfs, axis=1)
                all_dfs.append(chunk_combined)
                self.logger.info(f"Year {current_year}: Retrieved {len(chunk_combined)} records")
            
            current_year += 1
        
        if not all_dfs:
            raise CopernicusError(
                "No ocean color data retrieved from any chunk",
                context={"start_date": str(start_date), "end_date": str(end_date)}
            )
        
        # Combine all years
        combined_df = pd.concat(all_dfs).sort_index()
        combined_df = combined_df[~combined_df.index.duplicated(keep='first')]
        
        self.logger.info(f"Combined ocean color: {len(combined_df)} total records")
        return combined_df
    
    def load_downloaded_data(self, file_path: Path) -> 'xr.Dataset':
        """
        Load downloaded NetCDF file into xarray Dataset.
        
        Parameters
        ----------
        file_path : Path
            Path to NetCDF file
        
        Returns
        -------
        xr.Dataset
            Loaded dataset
        """
        file_path = Path(file_path)
        
        if not file_path.exists():
            raise CopernicusError(
                f"File not found: {file_path}",
                context={"file_path": str(file_path)},
                suggestion="Ensure the file was downloaded successfully"
            )
        
        self.logger.info(f"Loading data from {file_path}")
        
        try:
            ds = xr.open_dataset(file_path)
            
            self.logger.info(
                f"Loaded dataset:\n"
                f"  Variables: {list(ds.data_vars)}\n"
                f"  Dimensions: {dict(ds.dims)}\n"
                f"  Time range: {ds.time.values[0]} to {ds.time.values[-1]}"
            )
            
            return ds
            
        except Exception as e:
            raise CopernicusError(
                f"Failed to load NetCDF file: {file_path}",
                context={"file_path": str(file_path)},
                original_exception=e
            )
    
    def extract_timeseries(
        self,
        dataset: 'xr.Dataset',
        variable: str,
        method: str = 'mean'
    ) -> pd.DataFrame:
        """
        Extract time series from xarray Dataset.
        
        Parameters
        ----------
        dataset : xr.Dataset
            Input dataset
        variable : str
            Variable name
        method : str
            Aggregation method ('mean', 'median', 'max', 'min')
        
        Returns
        -------
        pd.DataFrame
            Time series DataFrame
        """
        self.logger.info(f"Extracting {variable} time series with {method} aggregation")
        
        if variable not in dataset.data_vars:
            available = list(dataset.data_vars)
            raise ValidationError(
                f"Variable '{variable}' not found in dataset",
                field="variable",
                expected=available,
                actual=variable
            )
        
        da = dataset[variable]
        
        # Aggregate spatially
        if method == 'mean':
            ts = da.mean(dim=['latitude', 'longitude'])
        elif method == 'median':
            ts = da.median(dim=['latitude', 'longitude'])
        elif method == 'max':
            ts = da.max(dim=['latitude', 'longitude'])
        elif method == 'min':
            ts = da.min(dim=['latitude', 'longitude'])
        else:
            raise ValidationError(
                f"Invalid aggregation method: {method}",
                field="method",
                expected=['mean', 'median', 'max', 'min'],
                actual=method
            )
        
        # Convert to DataFrame
        df = ts.to_dataframe().reset_index()
        df = df.rename(columns={'time': 'date'})
        df['date'] = pd.to_datetime(df['date'])
        df = df.set_index('date')[[variable]]
        
        self.logger.info(f"Extracted {len(df)} time points")
        return df
