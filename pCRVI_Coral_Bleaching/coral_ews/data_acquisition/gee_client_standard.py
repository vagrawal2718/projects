"""
Google Earth Engine Data Acquisition Module
============================================

Handles all interactions with Google Earth Engine including:
- Authentication and initialization
- Data extraction for SST, ocean color, atmospheric, and current data
- Export to Drive/local
- Error handling and retry logic

All asset IDs verified against GEE Data Catalog (January 2026).
"""

import os
import time
from typing import Optional, Dict, List, Any, Tuple, Union
from datetime import datetime, date, timedelta
from pathlib import Path
import json
from datetime import timedelta

import numpy as np
import pandas as pd

from ..exceptions import GEEError, ValidationError, DataAcquisitionError
from ..logger import get_logger, log_execution_time, ProgressLogger
from ..config import Config, GEEDatasets, ANIRegion

# Try to import Earth Engine
try:
    import ee
    EE_AVAILABLE = True
except ImportError:
    EE_AVAILABLE = False


class GEEClient:
    """
    Google Earth Engine client for coral bleaching data acquisition.
    
    Handles authentication, data extraction, and export with comprehensive
    error handling and retry logic.
    
    Attributes
    ----------
    config : Config
        Configuration object
    logger : ContextLogger
        Logger instance
    initialized : bool
        Whether GEE has been initialized
    """
    
    def __init__(self, config: Optional[Config] = None, project_id: Optional[str] = None):
        """
        Initialize GEE client.
        
        Parameters
        ----------
        config : Config, optional
            Configuration object (default: create new)
        project_id : str, optional
            GEE project ID for authentication
        """
        if not EE_AVAILABLE:
            raise GEEError(
                "Earth Engine Python API not installed",
                suggestion="Install with: pip install earthengine-api"
            )
        
        self.config = config or Config()
        self.logger = get_logger("coral_ews.gee")
        self.project_id = project_id or os.environ.get("GEE_PROJECT_ID")
        self.initialized = False
        self._geometry = None
    
    def authenticate(self, force: bool = False) -> bool:
        """
        Authenticate with Google Earth Engine.
        
        Automatically detects credentials from:
        1. Explicit project_id parameter
        2. GEE_PROJECT_ID environment variable
        3. ~/.config/earthengine/credentials (from 'earthengine authenticate')
        """
        if self.initialized and not force:
            self.logger.info("Already authenticated with GEE")
            return True
        
        self.logger.info("Authenticating with Google Earth Engine...")
        
        # Check for project ID from multiple sources
        project = self.project_id or os.environ.get('GEE_PROJECT_ID') or os.environ.get('GOOGLE_CLOUD_PROJECT')
        
        try:
            if project:
                ee.Initialize(project=project)
                self.logger.info(f"GEE initialized with project: {project}")
            else:
                # Try high-volume endpoint which may work without explicit project
                ee.Initialize(opt_url='https://earthengine-highvolume.googleapis.com')
                self.logger.info("GEE initialized with high-volume endpoint")
            
            self.initialized = True
            return True
            
        except Exception as e1:
            # If high-volume fails, try standard endpoint
            if not project:
                try:
                    ee.Initialize()
                    self.initialized = True
                    self.logger.info("GEE initialized with default settings")
                    return True
                except Exception as e2:
                    raise GEEError(
                        "GEE initialization failed. No project ID found.",
                        operation="authenticate",
                        context={"tried_project": project, "error": str(e2)},
                        suggestion="Either: (1) Set GEE_PROJECT_ID environment variable, "
                                   "(2) Pass --gee-project flag, or "
                                   "(3) Run 'gcloud config set project YOUR_PROJECT_ID'",
                        original_exception=e2
                    )
            raise GEEError(
                "Failed to authenticate with Google Earth Engine",
                operation="authenticate",
                context={"project_id": project},
                original_exception=e1
            )
    def _ensure_initialized(self):
        """Ensure GEE is initialized before operations."""
        if not self.initialized:
            self.authenticate()
    
    def _get_geometry(self) -> 'ee.Geometry':
        """Get or create the study region geometry."""
        self._ensure_initialized()
        
        if self._geometry is None:
            bounds = self.config.region.bounds
            self._geometry = ee.Geometry.Rectangle([
                bounds[0], bounds[1], bounds[2], bounds[3]
            ])
        
        return self._geometry
    
    def _safe_get_info(self, ee_object: Any, timeout: int = 300) -> Any:
        """
        Safely get info from an Earth Engine object with timeout handling.
        
        Parameters
        ----------
        ee_object : ee.ComputedObject
            Earth Engine object
        timeout : int
            Timeout in seconds
        
        Returns
        -------
        Any
            Result from getInfo()
        
        Raises
        ------
        GEEError
            If operation times out or fails
        """
        try:
            return ee_object.getInfo()
        except ee.EEException as e:
            error_msg = str(e)
            if "deadline" in error_msg.lower() or "timeout" in error_msg.lower():
                raise GEEError(
                    "GEE computation timed out",
                    operation="getInfo",
                    context={"timeout": timeout},
                    suggestion="Try reducing region size or date range, or export to Drive instead",
                    original_exception=e
                )
            raise GEEError(
                f"GEE computation failed: {error_msg}",
                operation="getInfo",
                original_exception=e
            )
    
    @log_execution_time()
    def get_oisst_collection(
        self,
        start_date: Union[str, date],
        end_date: Union[str, date],
        bands: Optional[List[str]] = None
    ) -> 'ee.ImageCollection':
        """
        Get NOAA OISST v2.1 ImageCollection.
        
        Parameters
        ----------
        start_date : str or date
            Start date (YYYY-MM-DD)
        end_date : str or date
            End date (YYYY-MM-DD)
        bands : list, optional
            Bands to select (default: ['sst'])
        
        Returns
        -------
        ee.ImageCollection
            Filtered and processed ImageCollection
        
        Raises
        ------
        GEEError
            If data acquisition fails
        ValidationError
            If date range is invalid
        """
        self._ensure_initialized()
        
        # Validate dates
        start_str = str(start_date)
        end_str = str(end_date)
        
        dataset_start = datetime.strptime("1981-09-01", "%Y-%m-%d")
        requested_start = datetime.strptime(start_str, "%Y-%m-%d")
        
        if requested_start < dataset_start:
            raise ValidationError(
                f"Requested start date {start_str} is before OISST availability",
                field="start_date",
                expected=f">= 1981-09-01",
                actual=start_str,
                suggestion="OISST v2.1 is available from 1981-09-01"
            )
        
        bands = bands or ['sst']
        self.logger.info(f"Fetching OISST data: {start_str} to {end_str}, bands: {bands}")
        
        try:
            collection = (
                ee.ImageCollection(GEEDatasets.OISST['asset_id'])
                .filterDate(start_str, end_str)
                .filterBounds(self._get_geometry())
                .select(bands)
            )
            
            # Apply scale factor for SST
            def apply_scale(img):
                scaled = img.multiply(0.01)
                return scaled.copyProperties(img, ['system:time_start'])
            
            if 'sst' in bands or 'anom' in bands:
                collection = collection.map(apply_scale)
            
            # Verify collection is not empty
            size = collection.size().getInfo()
            if size == 0:
                raise GEEError(
                    f"No OISST data found for date range {start_str} to {end_str}",
                    asset_id=GEEDatasets.OISST['asset_id'],
                    context={"start_date": start_str, "end_date": end_str}
                )
            
            self.logger.info(f"Retrieved OISST collection with {size} images")
            return collection
            
        except ee.EEException as e:
            raise GEEError(
                f"Failed to fetch OISST data",
                asset_id=GEEDatasets.OISST['asset_id'],
                operation="filterDate/filterBounds",
                context={"start_date": start_str, "end_date": end_str, "bands": bands},
                original_exception=e
            )
    
    @log_execution_time()
    def get_modis_ocean_color(
        self,
        start_date: Union[str, date],
        end_date: Union[str, date],
        bands: Optional[List[str]] = None
    ) -> 'ee.ImageCollection':
        """
        Get MODIS Aqua ocean color ImageCollection.
        
        CRITICAL NOTE: Kd490 is NOT available in GEE MODIS dataset.
        Dataset ended February 28, 2022.
        
        Parameters
        ----------
        start_date : str or date
            Start date (YYYY-MM-DD)
        end_date : str or date
            End date (YYYY-MM-DD)
        bands : list, optional
            Bands to select (default: ['chlor_a'])
        
        Returns
        -------
        ee.ImageCollection
            Filtered ImageCollection
        
        Raises
        ------
        GEEError
            If data acquisition fails
        ValidationError
            If requesting unavailable bands or dates
        """
        self._ensure_initialized()
        
        start_str = str(start_date)
        end_str = str(end_date)
        bands = bands or ['chlor_a']
        
        # Check for Kd490 request
        if 'Kd_490' in bands or 'Kd490' in bands or 'kd490' in bands:
            raise ValidationError(
                "Kd490 is NOT available in GEE MODIS dataset",
                field="bands",
                expected="chlor_a, sst, nflh, poc, Rrs_*",
                actual=bands,
                suggestion="Download Kd490 from Copernicus Marine (OCEANCOLOUR_GLO_BGC_L3_MY_009_103) "
                          "or calculate from Rrs bands using NASA algorithm"
            )
        
        # Validate date range
        dataset_end = datetime.strptime("2022-02-28", "%Y-%m-%d")
        requested_end = datetime.strptime(end_str, "%Y-%m-%d")
        
        if requested_end > dataset_end:
            self.logger.warning(
                f"Requested end date {end_str} is after MODIS GEE dataset end (2022-02-28). "
                f"Adjusting to 2022-02-28. For recent data, use Copernicus Marine."
            )
            end_str = "2022-02-28"
        
        self.logger.info(f"Fetching MODIS ocean color: {start_str} to {end_str}, bands: {bands}")
        
        try:
            collection = (
                ee.ImageCollection(GEEDatasets.MODIS_AQUA['asset_id'])
                .filterDate(start_str, end_str)
                .filterBounds(self._get_geometry())
                .select(bands)
            )
            
            size = collection.size().getInfo()
            if size == 0:
                raise GEEError(
                    f"No MODIS data found for date range",
                    asset_id=GEEDatasets.MODIS_AQUA['asset_id'],
                    context={"start_date": start_str, "end_date": end_str}
                )
            
            self.logger.info(f"Retrieved MODIS collection with {size} images")
            return collection
            
        except ee.EEException as e:
            raise GEEError(
                "Failed to fetch MODIS ocean color data",
                asset_id=GEEDatasets.MODIS_AQUA['asset_id'],
                operation="filterDate/filterBounds",
                original_exception=e
            )
    
    @log_execution_time()
    def get_era5_hourly(
        self,
        start_date: Union[str, date],
        end_date: Union[str, date],
        bands: Optional[List[str]] = None
    ) -> 'ee.ImageCollection':
        """
        Get ERA5 Hourly ImageCollection.
        
        CRITICAL: Cloud cover (total_cloud_cover) is ONLY in HOURLY dataset.
        
        Parameters
        ----------
        start_date : str or date
            Start date
        end_date : str or date
            End date
        bands : list, optional
            Bands to select (default: cloud cover and wind)
        
        Returns
        -------
        ee.ImageCollection
            Filtered ImageCollection
        """
        self._ensure_initialized()
        
        start_str = str(start_date)
        end_str = str(end_date)
        bands = bands or ['total_cloud_cover', 'u_component_of_wind_10m', 'v_component_of_wind_10m']
        
        self.logger.info(f"Fetching ERA5 HOURLY: {start_str} to {end_str}, bands: {bands}")
        
        try:
            collection = (
                ee.ImageCollection(GEEDatasets.ERA5_HOURLY['asset_id'])
                .filterDate(start_str, end_str)
                .filterBounds(self._get_geometry())
                .select(bands)
            )
            
            size = collection.size().getInfo()
            self.logger.info(f"Retrieved ERA5 HOURLY collection with {size} images")
            return collection
            
        except ee.EEException as e:
            raise GEEError(
                "Failed to fetch ERA5 HOURLY data",
                asset_id=GEEDatasets.ERA5_HOURLY['asset_id'],
                original_exception=e
            )
    
    def aggregate_era5_to_daily(
        self,
        collection: 'ee.ImageCollection',
        start_date: Union[str, date],
        end_date: Union[str, date]
    ) -> 'ee.ImageCollection':
        """
        Aggregate ERA5 hourly data to daily means.
        
        Parameters
        ----------
        collection : ee.ImageCollection
            Hourly ERA5 collection
        start_date : str or date
            Start date
        end_date : str or date
            End date
        
        Returns
        -------
        ee.ImageCollection
            Daily aggregated collection
        """
        self._ensure_initialized()
        
        start_str = str(start_date)
        end_str = str(end_date)
        
        self.logger.info("Aggregating ERA5 hourly to daily...")
        
        # Create list of dates
        start = ee.Date(start_str)
        end = ee.Date(end_str)
        n_days = end.difference(start, 'day').round()
        
        def aggregate_day(day_offset):
            day_offset = ee.Number(day_offset)
            current_date = start.advance(day_offset, 'day')
            next_date = current_date.advance(1, 'day')
            
            daily = collection.filterDate(current_date, next_date)
            
            # Mean cloud cover
            cloud = daily.select('total_cloud_cover').mean()
            
            # Mean wind components
            u = daily.select('u_component_of_wind_10m').mean()
            v = daily.select('v_component_of_wind_10m').mean()
            
            # Calculate wind speed
            wind_speed = u.pow(2).add(v.pow(2)).sqrt().rename('wind_speed')
            
            return (
                ee.Image.cat([cloud.rename('cloud_cover'), wind_speed])
                .set('system:time_start', current_date.millis())
                .set('date', current_date.format('YYYY-MM-dd'))
            )
        
        daily_collection = ee.ImageCollection(
            ee.List.sequence(0, n_days.subtract(1)).map(aggregate_day)
        )
        
        return daily_collection
    
    @log_execution_time()
    def get_hycom_currents(
        self,
        start_date: Union[str, date],
        end_date: Union[str, date]
    ) -> 'ee.ImageCollection':
        """
        Get HYCOM ocean current velocity ImageCollection.
        
        Parameters
        ----------
        start_date : str or date
            Start date
        end_date : str or date
            End date
        
        Returns
        -------
        ee.ImageCollection
            Current velocity collection with calculated speed
        """
        self._ensure_initialized()
        
        start_str = str(start_date)
        end_str = str(end_date)
        
        # Check date range
        dataset_end = datetime.strptime("2024-09-05", "%Y-%m-%d")
        requested_end = datetime.strptime(end_str, "%Y-%m-%d")
        
        if requested_end > dataset_end:
            self.logger.warning(
                f"HYCOM data ends 2024-09-05. Adjusting end date from {end_str}"
            )
            end_str = "2024-09-05"
        
        self.logger.info(f"Fetching HYCOM currents: {start_str} to {end_str}")
        
        try:
            collection = (
                ee.ImageCollection(GEEDatasets.HYCOM['asset_id'])
                .filterDate(start_str, end_str)
                .filterBounds(self._get_geometry())
                .select(['velocity_u_0', 'velocity_v_0'])
            )
            
            # Apply scale and calculate speed
            def process_hycom(img):
                # Apply scale factor (0.001)
                u = img.select('velocity_u_0').multiply(0.001)
                v = img.select('velocity_v_0').multiply(0.001)
                
                # Calculate speed
                speed = u.pow(2).add(v.pow(2)).sqrt().rename('current_speed')
                
                return img.addBands([u.rename('u_velocity'), v.rename('v_velocity'), speed])
            
            processed = collection.map(process_hycom)
            
            size = processed.size().getInfo()
            self.logger.info(f"Retrieved HYCOM collection with {size} images")
            return processed
            
        except ee.EEException as e:
            raise GEEError(
                "Failed to fetch HYCOM current data",
                asset_id=GEEDatasets.HYCOM['asset_id'],
                original_exception=e
            )
    
    @log_execution_time()
    def get_reef_mask(self) -> 'ee.Image':
        """
        Get Allen Coral Atlas reef mask for the study region.
        
        Returns
        -------
        ee.Image
            Binary reef mask
        """
        self._ensure_initialized()
        
        self.logger.info("Fetching Allen Coral Atlas reef mask...")
        
        try:
            reef_data = ee.Image(GEEDatasets.ALLEN_CORAL_ATLAS['asset_id'])
            
            # Clip to study region
            reef_mask = reef_data.select('reef_mask').clip(self._get_geometry())
            
            # Get reef area statistics
            stats = reef_mask.reduceRegion(
                reducer=ee.Reducer.sum(),
                geometry=self._get_geometry(),
                scale=100,  # Coarser scale for speed
                maxPixels=1e9
            )
            
            self.logger.info("Reef mask retrieved successfully")
            return reef_mask
            
        except ee.EEException as e:
            raise GEEError(
                "Failed to fetch reef mask",
                asset_id=GEEDatasets.ALLEN_CORAL_ATLAS['asset_id'],
                original_exception=e
            )
    
    @log_execution_time()
    def extract_timeseries_chunked(
        self,
        start_date: Union[str, date],
        end_date: Union[str, date],
        band: str = 'sst',
        reducer: str = 'mean',
        scale: int = 5000,
        chunk_size_days: int = 365,
        cache_dir: Optional[Path] = None
    ) -> pd.DataFrame:
        """
        Extract time series in chunks to avoid GEE 5000 element limit.
        
        Parameters
        ----------
        start_date, end_date : str or date
            Date range
        band : str
            Band name to extract
        reducer : str
            Reduction method
        scale : int
            Scale in meters
        chunk_size_days : int
            Days per chunk (default: 365 = 1 year)
        cache_dir : Path, optional
            Directory to cache yearly CSV files
        
        Returns
        -------
        pd.DataFrame
            Combined time series
        """
        self._ensure_initialized()
        
        start_dt = datetime.strptime(str(start_date), "%Y-%m-%d")
        end_dt = datetime.strptime(str(end_date), "%Y-%m-%d")
        
        total_days = (end_dt - start_dt).days
        num_chunks = (total_days // chunk_size_days) + 1
        
        self.logger.info(
            f"Extracting {band} time series in {num_chunks} chunks "
            f"({chunk_size_days} days each) to avoid GEE limits"
        )
        
        all_dfs = []
    
        for year in range(start_year, end_year + 1):
            # Use calendar year boundaries - this is the KEY FIX
            # For leap years, Dec 31 is day 366, which is handled automatically
            year_start = datetime(year, 1, 1)
            year_end = datetime(year, 12, 31)
            
            # Clip to requested date range
            chunk_start = max(year_start, start_dt)
            chunk_end = min(year_end, end_dt)
            
            chunk_start_str = chunk_start.strftime("%Y-%m-%d")
            chunk_end_str = chunk_end.strftime("%Y-%m-%d")
            
            # Check cache first
            if cache_dir:
                cache_file = Path(cache_dir) / f"gee_{band}_{chunk_start_str}_{chunk_end_str}.csv"
                if cache_file.exists():
                    self.logger.info(f"Loading cached chunk: {cache_file.name}")
                    try:
                        chunk_df = pd.read_csv(cache_file, index_col=0, parse_dates=True)
                        all_dfs.append(chunk_df)
                        continue
                    except Exception as e:
                        self.logger.warning(f"Failed to load cache {cache_file.name}: {e}")
            
            self.logger.info(
                f"Year {year} ({len(all_dfs)+1}/{num_years}): {chunk_start_str} to {chunk_end_str}"
            )
            
            try:
                # Get collection for this calendar year chunk
                collection = self.get_oisst_collection(chunk_start_str, chunk_end_str, bands=[band])
                
                # Extract time series for chunk
                chunk_df = self.extract_timeseries(collection, band=band, reducer=reducer, scale=scale)
                
                # Save to cache
                if cache_dir:
                    cache_file = Path(cache_dir) / f"gee_{band}_{chunk_start_str}_{chunk_end_str}.csv"
                    cache_file.parent.mkdir(parents=True, exist_ok=True)
                    chunk_df.to_csv(cache_file)
                    self.logger.info(f"Cached chunk: {cache_file.name}")
                
                all_dfs.append(chunk_df)
                self.logger.info(f"Year {year}: Retrieved {len(chunk_df)} records")
                
            except Exception as e:
                self.logger.warning(f"Year {year} failed: {e}. Continuing...")
        
        if not all_dfs:
            raise GEEError(
                "No data retrieved from any year",
                operation="extract_timeseries_chunked",
                context={"start_date": str(start_date), "end_date": str(end_date)}
            )
        
        # Combine all years
        combined_df = pd.concat(all_dfs).sort_index()
        combined_df = combined_df[~combined_df.index.duplicated(keep='first')]
        
        self.logger.info(f"Combined {len(combined_df)} total records from {len(all_dfs)} years")
        return combined_df

    @log_execution_time()
    def extract_era5_chunked(
        self,
        start_date: Union[str, date],
        end_date: Union[str, date],
        chunk_size_days: int = 365,
        cache_dir: Optional[Path] = None
    ) -> pd.DataFrame:
        """
        Extract ERA5 atmospheric data in yearly chunks.
        
        Returns DataFrame with cloud_cover and wind_speed columns.
        """
        self._ensure_initialized()
        
        start_dt = datetime.strptime(str(start_date), "%Y-%m-%d")
        end_dt = datetime.strptime(str(end_date), "%Y-%m-%d")
        
        self.logger.info(f"Extracting ERA5 data in yearly chunks: {start_date} to {end_date}")
        
        all_cloud = []
        all_wind = []
        current_start = start_dt
    
        for year in range(start_year, end_year + 1):
            # Use calendar year boundaries
            year_start = datetime(year, 1, 1)
            year_end = datetime(year, 12, 31)
            
            # Clip to requested date range
            chunk_start = max(year_start, start_dt)
            chunk_end = min(year_end, end_dt)
            
            chunk_start_str = chunk_start.strftime("%Y-%m-%d")
            chunk_end_str = chunk_end.strftime("%Y-%m-%d")
            
            self.logger.info(
                f"ERA5 year {year}: {chunk_start_str} to {chunk_end_str}"
            )
            
            try:
                # Get hourly collection
                hourly_collection = self.get_era5_hourly(chunk_start_str, chunk_end_str)
                
                # Aggregate to daily
                daily_collection = self.aggregate_era5_to_daily(
                    hourly_collection,
                    chunk_start_str,
                    chunk_end_str
                )
                
                # Extract time series
                cloud_df = self.extract_timeseries(daily_collection, 'cloud_cover')
                wind_df = self.extract_timeseries(daily_collection, 'wind_speed')
                
                all_cloud.append(cloud_df)
                all_wind.append(wind_df)
                
                self.logger.info(f"ERA5 year {year}: Retrieved {len(cloud_df)} records")
                
            except Exception as e:
                self.logger.warning(f"ERA5 year {year} failed: {e}. Continuing...")
        
            # Combine
            if all_cloud:
                cloud_combined = pd.concat(all_cloud).sort_index()
                cloud_combined = cloud_combined[~cloud_combined.index.duplicated(keep='first')]
            else:
                cloud_combined = pd.DataFrame()
            
            if all_wind:
                wind_combined = pd.concat(all_wind).sort_index()
                wind_combined = wind_combined[~wind_combined.index.duplicated(keep='first')]
            else:
                wind_combined = pd.DataFrame()
            
            result = pd.concat([cloud_combined, wind_combined], axis=1)
            self.logger.info(f"Combined ERA5: {len(result)} total records")
            return result
    
    @log_execution_time()
    def extract_timeseries(
        self,
        collection: 'ee.ImageCollection',
        band: str,
        reducer: str = 'mean',
        scale: int = 5000
    ) -> pd.DataFrame:
        """
        Extract time series from an ImageCollection over the study region.
        
        Parameters
        ----------
        collection : ee.ImageCollection
            Input collection
        band : str
            Band name to extract
        reducer : str
            Reduction method ('mean', 'median', 'max', 'min')
        scale : int
            Scale in meters for reduction
        
        Returns
        -------
        pd.DataFrame
            Time series with date index
        """
        self._ensure_initialized()
        
        self.logger.info(f"Extracting time series for band '{band}' with {reducer} reducer")
        
        reducer_map = {
            'mean': ee.Reducer.mean(),
            'median': ee.Reducer.median(),
            'max': ee.Reducer.max(),
            'min': ee.Reducer.min()
        }
        
        if reducer not in reducer_map:
            raise ValidationError(
                f"Invalid reducer: {reducer}",
                field="reducer",
                expected=list(reducer_map.keys()),
                actual=reducer
            )
        
        geometry = self._get_geometry()
        ee_reducer = reducer_map[reducer]
        
        def extract_value(img):
            """Extract reduced value for a single image."""
            stats = img.select(band).reduceRegion(
                reducer=ee_reducer,
                geometry=geometry,
                scale=scale,
                maxPixels=1e9,
                bestEffort=True
            )
            
            return ee.Feature(None, {
                'date': ee.Date(img.get('system:time_start')).format('YYYY-MM-dd'),
                'value': stats.get(band)
            })
        
        try:
            # Map extraction over collection
            features = collection.map(extract_value)
            feature_collection = ee.FeatureCollection(features)
            
            # Get info (this may be slow for large collections)
            self.logger.info("Retrieving time series data from GEE (this may take a while)...")
            data = feature_collection.getInfo()
            
            # Convert to DataFrame
            records = []
            for feature in data['features']:
                props = feature['properties']
                if props['value'] is not None:
                    records.append({
                        'date': props['date'],
                        band: props['value']
                    })
            
            if not records:
                raise GEEError(
                    "No valid data extracted from collection",
                    operation="extract_timeseries",
                    context={"band": band, "reducer": reducer}
                )
            
            df = pd.DataFrame(records)
            df['date'] = pd.to_datetime(df['date'])
            df = df.set_index('date').sort_index()
            
            self.logger.info(f"Extracted {len(df)} time series records")
            return df
            
        except ee.EEException as e:
            raise GEEError(
                "Failed to extract time series",
                operation="extract_timeseries",
                context={"band": band, "reducer": reducer, "scale": scale},
                original_exception=e
            )
    
    @log_execution_time()
    def export_to_drive(
        self,
        image: 'ee.Image',
        description: str,
        folder: str = "coral_ews_exports",
        scale: int = 5000,
        region: Optional['ee.Geometry'] = None,
        file_format: str = "GeoTIFF",
        wait: bool = False
    ) -> Dict[str, Any]:
        """
        Export an image to Google Drive.
        
        Parameters
        ----------
        image : ee.Image
            Image to export
        description : str
            Export task description (also used as filename)
        folder : str
            Drive folder name
        scale : int
            Export scale in meters
        region : ee.Geometry, optional
            Export region (default: study region)
        file_format : str
            Export format ('GeoTIFF' or 'TFRecord')
        wait : bool
            Whether to wait for export to complete
        
        Returns
        -------
        dict
            Export task information
        """
        self._ensure_initialized()
        
        region = region or self._get_geometry()
        
        self.logger.info(f"Starting export to Drive: {description}")
        
        try:
            task = ee.batch.Export.image.toDrive(
                image=image,
                description=description,
                folder=folder,
                scale=scale,
                region=region,
                fileFormat=file_format,
                maxPixels=1e13
            )
            
            task.start()
            
            task_info = {
                "id": task.id,
                "description": description,
                "folder": folder,
                "status": "RUNNING"
            }
            
            self.logger.info(f"Export task started: {task.id}")
            
            if wait:
                self.logger.info("Waiting for export to complete...")
                while task.status()['state'] in ['READY', 'RUNNING']:
                    time.sleep(10)
                    status = task.status()
                    self.logger.info(f"Export status: {status['state']}")
                
                final_status = task.status()
                task_info['status'] = final_status['state']
                
                if final_status['state'] == 'FAILED':
                    raise GEEError(
                        f"Export failed: {final_status.get('error_message', 'Unknown error')}",
                        operation="export_to_drive",
                        context=task_info
                    )
                
                self.logger.info(f"Export completed: {final_status['state']}")
            
            return task_info
            
        except ee.EEException as e:
            raise GEEError(
                "Failed to start export task",
                operation="export_to_drive",
                context={"description": description, "folder": folder},
                original_exception=e
            )
    
    def check_dataset_availability(self, dataset_id: str) -> Dict[str, Any]:
        """
        Check if a dataset is available and get its metadata.
        
        Parameters
        ----------
        dataset_id : str
            GEE asset ID
        
        Returns
        -------
        dict
            Dataset availability and metadata
        """
        self._ensure_initialized()
        
        self.logger.info(f"Checking availability: {dataset_id}")
        
        try:
            collection = ee.ImageCollection(dataset_id)
            
            # Get collection info
            size = collection.size().getInfo()
            first = collection.first()
            
            if size == 0:
                return {
                    "available": False,
                    "dataset_id": dataset_id,
                    "message": "Dataset exists but contains no images"
                }
            
            # Get date range
            first_date = ee.Date(first.get('system:time_start')).format('YYYY-MM-dd').getInfo()
            last = collection.sort('system:time_start', False).first()
            last_date = ee.Date(last.get('system:time_start')).format('YYYY-MM-dd').getInfo()
            
            # Get band names
            bands = first.bandNames().getInfo()
            
            return {
                "available": True,
                "dataset_id": dataset_id,
                "size": size,
                "date_range": (first_date, last_date),
                "bands": bands
            }
            
        except ee.EEException as e:
            return {
                "available": False,
                "dataset_id": dataset_id,
                "error": str(e)
            }
