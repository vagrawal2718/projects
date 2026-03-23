"""
NOAA Data Acquisition Module
=============================

Handles data download from NOAA sources including:
- Coral Reef Watch Virtual Station data
- MMM Climatology
- Climate Indices (ONI, DMI)
- ERDDAP access

All URLs verified against official NOAA sources (January 2026).
"""

import os
import time
import re
from typing import Optional, Dict, List, Any, Union, Tuple
from datetime import datetime, date, timedelta
from pathlib import Path
from io import StringIO
import urllib.request
import urllib.error
import shutil
import numpy as np
import pandas as pd

from ..exceptions import DataAcquisitionError, ValidationError, NetworkError
from ..logger import get_logger, log_execution_time, ProgressLogger
from ..config import Config, NOAADatasets, ClimateIndices

# Try to import requests
try:
    import requests
    REQUESTS_AVAILABLE = True
except ImportError:
    REQUESTS_AVAILABLE = False

# Try to import xarray
try:
    import xarray as xr
    XARRAY_AVAILABLE = True
except ImportError:
    XARRAY_AVAILABLE = False


class NOAAClient:
    """
    NOAA data client for coral bleaching data acquisition.
    
    Handles download of:
    - Virtual Station time series data
    - MMM Climatology
    - DHW/SST products
    """
    
    def __init__(self, config: Optional[Config] = None):
        """
        Initialize NOAA client.
        
        Parameters
        ----------
        config : Config, optional
            Configuration object
        """
        self.config = config or Config()
        self.logger = get_logger("coral_ews.noaa")
        
        if not REQUESTS_AVAILABLE:
            self.logger.warning("requests package not installed, using urllib")
    
    def _make_request(
        self,
        url: str,
        timeout: int = 60,
        retries: int = 3,
        retry_delay: int = 5
    ) -> str:
        """
        Make HTTP request with retry logic.
        
        Parameters
        ----------
        url : str
            URL to request
        timeout : int
            Request timeout in seconds
        retries : int
            Number of retry attempts
        retry_delay : int
            Delay between retries in seconds
        
        Returns
        -------
        str
            Response text
        
        Raises
        ------
        NetworkError
            If request fails after all retries
        """
        last_error = None
        
        for attempt in range(retries):
            try:
                self.logger.debug(f"Request attempt {attempt + 1}/{retries}: {url}")
                
                if REQUESTS_AVAILABLE:
                    response = requests.get(url, timeout=timeout)
                    response.raise_for_status()
                    return response.text
                else:
                    with urllib.request.urlopen(url, timeout=timeout) as response:
                        return response.read().decode('utf-8')
                        
            except Exception as e:
                last_error = e
                self.logger.warning(
                    f"Request failed (attempt {attempt + 1}/{retries}): {str(e)}"
                )
                
                if attempt < retries - 1:
                    time.sleep(retry_delay)
        
        raise NetworkError(
            f"Failed to fetch URL after {retries} attempts",
            url=url,
            context={"retries": retries, "timeout": timeout},
            original_exception=last_error
        )
    
    # ── NOAA CRW 5 km v3.1 URL patterns (verified Feb 2026) ───────────
    # Historical annual composites live on the STAR NESDIS archive:
    #   .../image_plain/annual/png/ct5km_baa-max_v3.1_{year}.png   (BAA 2-level)
    #   .../image_plain/annual/png/ct5km_baa5-max_v3.1_{year}.png  (BAA 5-level, post-2023)
    #   .../image_plain/annual/png/ct5km_dhw-max_v3.1_{year}.png   (DHW max)
    # Real-time (current) regional maps on the CRW website:
    #   .../daily/png/ct5km_baa5-max-7d_v3.1_{region}_current.png
    #   .../daily/png/ct5km_dhw_v3.1_{region}_current.png
    #   .../year-to-date/png/ct5km_baa5-max-ytd_v3.1_{region}_current.png
    _STAR_BASE = (
        "https://www.star.nesdis.noaa.gov/pub/sod/mecb/crw/data/"
        "5km/v3.1_op/image_plain/annual/png"
    )
    _CRW_RT = (
        "https://coralreefwatch.noaa.gov/data_current/5km/v3.1_op"
    )

    def download_crw_bleaching_maps(
        self,
        years: List[int],
        output_dir: Path,
        products: List[str] = None,
        noaa_basin: str = "indian",
    ) -> Dict[str, Path]:
        """
        Download NOAA Coral Reef Watch 5 km v3.1 bleaching maps.

        Downloads annual-maximum Alert-Area and DHW composites from the
        STAR/NESDIS public archive for each requested year, plus the
        current real-time Alert-Area and DHW maps for the specified ocean
        basin (region-specific, from ``region.noaa_basin``).

        Parameters
        ----------
        years : list[int]
            Bleaching years to download annual composites for.
        output_dir : Path
            Directory to save maps into.
        products : list[str], optional
            Which annual products to fetch.
            Default ``['baa-max', 'baa5-max', 'dhw-max']``.
        noaa_basin : str
            NOAA CRW basin identifier for real-time regional maps.
            Valid: indian, pacific, caribbean, florida, gbr, triangle,
            satlantic, hawaii, tropics, global, east, west.
            Default 'indian'; sourced from ``region.noaa_basin``.

        Returns
        -------
        dict  {label: Path}
            Keys like ``'baa-max_1998'``, ``'current_alert_indian'``, etc.
        
        NOAA CRW Product Glossary
        -------------------------
        SST – Sea Surface Temperature (°C). Daily satellite-derived ocean skin
            temperature at ~5 km resolution.

        SST Anomaly – Departure of current SST from the long-term monthly
            climatological mean (MMM). Positive = warmer than average.

        HotSpot (HS) – max(SST − MMM, 0). HS ≥ 1°C triggers Bleaching Watch.

        DHW (Degree Heating Weeks) – Accumulated thermal stress over 12 weeks.
            DHW ≥ 4 → Alert Level 1 (bleaching likely).
            DHW ≥ 8 → Alert Level 2 (mass bleaching/mortality likely).

        BAA (Bleaching Alert Area) – Spatial classification combining HS + DHW:
            No Stress (HS<0), Watch (0<HS<1), Warning (HS≥1, DHW<4),
            Alert 1 (DHW≥4), Alert 2 (DHW≥8).

        baa5-max – Extended 5-level scale (CRW v3.1, 2023+) adding
            Alert Level 3 (DHW≥12) and Level 4 (DHW≥16).

        Annual composites (baa-max, baa5-max, dhw-max) show worst value
            at each pixel for the entire year.

        Real-time maps (current_alert, current_dhw) show the latest
            7-day or year-to-date status for a specific ocean basin.
                
        """
        import urllib.request
        output_dir = Path(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)

        if products is None:
            products = ['baa-max', 'baa5-max', 'dhw-max']

        # Validate basin identifier
        valid_basins = {
            'indian', 'pacific', 'caribbean', 'florida', 'gbr',
            'triangle', 'satlantic', 'hawaii', 'tropics', 'global',
            'east', 'west',
        }
        if noaa_basin not in valid_basins:
            self.logger.warning(
                f"Unknown NOAA basin '{noaa_basin}'; falling back to 'tropics'")
            noaa_basin = 'tropics'

        self.logger.info(f"NOAA CRW downloads for basin: {noaa_basin}")
        saved: Dict[str, Path] = {}

        # ── 1. Historical annual composites ────────────────────────────
        for year in years:
            for prod in products:
                fname = f"ct5km_{prod}_v3.1_{year}.png"
                url   = f"{self._STAR_BASE}/{fname}"
                fp    = output_dir / f"noaa_crw_{prod}_{year}.png"
                label = f"{prod}_{year}"

                if fp.exists():
                    saved[label] = fp
                    continue

                try:
                    urllib.request.urlretrieve(url, fp)
                    # Verify we got a real PNG, not a 404 HTML page
                    with open(fp, 'rb') as fh:
                        hdr = fh.read(8)
                    if hdr[:4] != b'\x89PNG':
                        fp.unlink(missing_ok=True)
                        continue
                    self.logger.info(
                        f"Downloaded NOAA {prod} map for {year}: {fp}")
                    saved[label] = fp
                except Exception:
                    fp.unlink(missing_ok=True)
                    continue

            if not any(f'_{year}' in k for k in saved):
                self.logger.warning(
                    f"Could not download any NOAA maps for {year}")

        # ── 2. Current real-time regional maps (cached per day) ──────
        from datetime import date as _date
        import shutil
        today_str = _date.today().strftime('%Y%m%d')

        # URL templates use the basin identifier from region config
        # Source: coralreefwatch.noaa.gov/product/5km/index_5km_baa-max-7d.php
        rt_maps = {
            'current_alert':  f'daily/png/ct5km_baa5-max-7d_v3.1_{noaa_basin}_current.png',
            'current_dhw':    f'daily/png/ct5km_dhw_v3.1_{noaa_basin}_current.png',
            'current_ytd':    f'year-to-date/png/ct5km_baa5-max-ytd_v3.1_{noaa_basin}_current.png',
            'current_ytd_dhw':f'year-to-date/png/ct5km_dhw-max-ytd_v3.1_{noaa_basin}_current.png',
        }
        for label, rel_path in rt_maps.items():
            # Date-stamped filename — only download once per calendar day
            fp_dated = output_dir / f"noaa_crw_{label}_{noaa_basin}_{today_str}.png"
            fp_latest = output_dir / f"noaa_crw_{label}.png"

            if fp_dated.exists():
                # Already downloaded today — just ensure the "latest" symlink/copy exists
                if not fp_latest.exists():
                    import shutil
                    shutil.copy2(fp_dated, fp_latest)
                saved[label] = fp_latest
                self.logger.debug(
                    f"NOAA {label} ({noaa_basin}) already downloaded today, skipping")
                continue

            url = f"{self._CRW_RT}/{rel_path}"
            try:
                urllib.request.urlretrieve(url, fp_dated)
                with open(fp_dated, 'rb') as fh:
                    hdr = fh.read(8)
                if hdr[:4] == b'\x89PNG':
                    # Copy to "latest" path for backward compatibility
                    import shutil
                    shutil.copy2(fp_dated, fp_latest)
                    saved[label] = fp_latest
                    self.logger.info(
                        f"Downloaded NOAA {label} ({noaa_basin}): {fp_dated}")
                else:
                    fp_dated.unlink(missing_ok=True)
            except Exception as e:
                fp_dated.unlink(missing_ok=True)
                self.logger.debug(f"Real-time map {label}: {e}")

        self.logger.info(
            f"NOAA CRW download complete ({noaa_basin}): {len(saved)} maps saved")
        return saved

    def _download_file(
        self,
        url: str,
        output_path: Path,
        timeout: int = 300
    ) -> Path:
        """
        Download file from URL.
        
        Parameters
        ----------
        url : str
            URL to download
        output_path : Path
            Output file path
        timeout : int
            Download timeout in seconds
        
        Returns
        -------
        Path
            Path to downloaded file
        """
        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        self.logger.info(f"Downloading: {url}")
        
        try:
            if REQUESTS_AVAILABLE:
                response = requests.get(url, timeout=timeout, stream=True)
                response.raise_for_status()
                
                total_size = int(response.headers.get('content-length', 0))
                
                with open(output_path, 'wb') as f:
                    downloaded = 0
                    for chunk in response.iter_content(chunk_size=8192):
                        f.write(chunk)
                        downloaded += len(chunk)
                        
                        if total_size > 0:
                            percent = (downloaded / total_size) * 100
                            if percent % 20 < 1:
                                self.logger.info(f"Download progress: {percent:.0f}%")
            else:
                urllib.request.urlretrieve(url, output_path)
            
            file_size = output_path.stat().st_size / (1024 * 1024)
            self.logger.info(f"Downloaded: {output_path} ({file_size:.1f} MB)")
            return output_path
            
        except Exception as e:
            raise NetworkError(
                f"Failed to download file",
                url=url,
                context={"output_path": str(output_path)},
                original_exception=e
            )
    
    @log_execution_time()
    def download_virtual_station_andaman(
        self,
        output_path: Optional[Path] = None
    ) -> Tuple[pd.DataFrame, Dict[str, Any]]:
        """
        Download and parse NOAA CRW Virtual Station data for Andaman.
        
        The Virtual Station file contains:
        - Header with MMM and climatology values
        - Daily time series of SST, SSTA, HotSpot, DHW, BAA
        
        Parameters
        ----------
        output_path : Path, optional
            Path to save raw file (default: data_dir/andaman_vs.txt)
        
        Returns
        -------
        tuple
            (DataFrame with time series, dict with header metadata including MMM)
        """
        url = NOAADatasets.VIRTUAL_STATION_ANDAMAN['url']
        
        self.logger.info("Downloading NOAA CRW Virtual Station data for Andaman...")
        
        try:
            # Download raw text
            raw_text = self._make_request(url, timeout=60)
            
            # Optionally save raw file
            if output_path:
                output_path = Path(output_path)
                output_path.parent.mkdir(parents=True, exist_ok=True)
                with open(output_path, 'w') as f:
                    f.write(raw_text)
                self.logger.info(f"Raw data saved to: {output_path}")
            
            # Parse the file
            return self._parse_virtual_station_file(raw_text)
            
        except Exception as e:
            raise DataAcquisitionError(
                "Failed to download Virtual Station data",
                source="NOAA",
                context={"url": url},
                original_exception=e
            )
    
    def _parse_virtual_station_file(
        self,
        raw_text: str
    ) -> Tuple[pd.DataFrame, Dict[str, Any]]:
        """
        Parse NOAA CRW Virtual Station file format.
        
        Parameters
        ----------
        raw_text : str
            Raw file content
        
        Returns
        -------
        tuple
            (DataFrame, metadata dict)
        """
        lines = raw_text.strip().split('\n')
        
        # Parse header to extract MMM and other metadata
        metadata = {
            'raw_header': [],
            'mmm': None,
            'monthly_climatology': {},
            'first_dhw_date': None,
            'first_baa_date': None
        }
        
        header_end = 0
        for i, line in enumerate(lines):
            if line.startswith('YYYY'):
                header_end = i
                break
            
            metadata['raw_header'].append(line)
            
            # Extract MMM (Averaged Maximum Monthly Mean)
            if 'Averaged Maximum Monthly Mean' in line or 'MMM' in line:
                mmm_match = re.search(r'(\d+\.\d+)', line)
                if mmm_match:
                    metadata['mmm'] = float(mmm_match.group(1))
                    self.logger.info(f"Extracted MMM: {metadata['mmm']}°C")
            
            # Extract climatology values
            month_match = re.search(r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*[=:]\s*(\d+\.\d+)', line, re.IGNORECASE)
            if month_match:
                month_name = month_match.group(1)[:3].capitalize()
                value = float(month_match.group(2))
                metadata['monthly_climatology'][month_name] = value
        
        # Parse data section
        if header_end == 0:
            raise ValidationError(
                "Could not find data section in Virtual Station file",
                field="file_format",
                suggestion="File format may have changed. Check NOAA CRW website."
            )
        
        # Get column names from header line
        header_line = lines[header_end]
        
        # Read data starting after header
        data_lines = lines[header_end + 1:]
        
        records = []
        for line in data_lines:
            parts = line.split()
            if len(parts) >= 10:
                try:
                    record = {
                        'year': int(parts[0]),
                        'month': int(parts[1]),
                        'day': int(parts[2]),
                        'sst_min': float(parts[3]),
                        'sst_max': float(parts[4]),
                        'sst_90th': float(parts[5]),
                        'ssta_90th': float(parts[6]),
                        'hotspot_90th': float(parts[7]),
                        'dhw': float(parts[8]),
                        'baa_7day_max': int(parts[9])
                    }
                    records.append(record)
                except (ValueError, IndexError) as e:
                    continue  # Skip malformed lines
        
        if not records:
            raise ValidationError(
                "No valid data records found in Virtual Station file",
                field="data_records"
            )
        
        df = pd.DataFrame(records)
        df['date'] = pd.to_datetime(df[['year', 'month', 'day']])
        df = df.set_index('date')
        df = df.drop(columns=['year', 'month', 'day'])
        df = df.sort_index()
        
        self.logger.info(
            f"Parsed Virtual Station data:\n"
            f"  Date range: {df.index.min()} to {df.index.max()}\n"
            f"  Records: {len(df)}\n"
            f"  MMM: {metadata['mmm']}°C"
        )
        
        return df, metadata
    
    @log_execution_time()
    def download_mmm_climatology(
        self,
        output_path: Optional[Path] = None
    ) -> Path:
        """
        Download NOAA CRW MMM Climatology NetCDF file.
        
        Parameters
        ----------
        output_path : Path, optional
            Output file path
        
        Returns
        -------
        Path
            Path to downloaded file
        """
        url = NOAADatasets.MMM_CLIMATOLOGY['url']
        
        if output_path is None:
            output_path = self.config.data_dir / "crw_mmm_climatology_v3.1.nc"
        
        self.logger.info("Downloading NOAA CRW MMM Climatology...")
        return self._download_file(url, output_path)
    
    def load_mmm_climatology(
        self,
        file_path: Path,
        bounds: Optional[Tuple[float, float, float, float]] = None
    ) -> 'xr.Dataset':
        """
        Load and optionally subset MMM climatology.
        
        Parameters
        ----------
        file_path : Path
            Path to climatology NetCDF file
        bounds : tuple, optional
            Spatial bounds (lon_min, lat_min, lon_max, lat_max)
        
        Returns
        -------
        xr.Dataset
            MMM climatology dataset
        """
        if not XARRAY_AVAILABLE:
            raise DataAcquisitionError(
                "xarray not available",
                source="LOCAL",
                suggestion="Install with: pip install xarray netcdf4"
            )
        
        file_path = Path(file_path)
        if not file_path.exists():
            raise DataAcquisitionError(
                f"Climatology file not found: {file_path}",
                source="LOCAL"
            )
        
        self.logger.info(f"Loading MMM climatology from {file_path}")
        
        try:
            ds = xr.open_dataset(file_path)
            
            # Subset to region if bounds provided
            if bounds:
                lon_min, lat_min, lon_max, lat_max = bounds
                ds = ds.sel(
                    lon=slice(lon_min, lon_max),
                    lat=slice(lat_min, lat_max)
                )
                self.logger.info(f"Subset to region: {bounds}")
            
            return ds
            
        except Exception as e:
            raise DataAcquisitionError(
                f"Failed to load climatology file",
                source="LOCAL",
                context={"file_path": str(file_path)},
                original_exception=e
            )


class ClimateIndicesClient:
    """
    Client for downloading climate indices (ONI, DMI).
    """
    
    def __init__(self, config: Optional[Config] = None):
        """Initialize client."""
        self.config = config or Config()
        self.logger = get_logger("coral_ews.climate_indices")
    
    def _make_request(self, url: str, timeout: int = 60) -> str:
        """Make HTTP request."""
        try:
            if REQUESTS_AVAILABLE:
                response = requests.get(url, timeout=timeout)
                response.raise_for_status()
                return response.text
            else:
                with urllib.request.urlopen(url, timeout=timeout) as response:
                    return response.read().decode('utf-8')
        except Exception as e:
            raise NetworkError(
                "Failed to fetch climate index data",
                url=url,
                original_exception=e
            )
    
    @log_execution_time()
    def download_oni(self) -> pd.DataFrame:
        """
        Download Oceanic Niño Index (ONI) data.
        
        Returns
        -------
        pd.DataFrame
            ONI time series with monthly values
        """
        url = ClimateIndices.ONI['alternative_url']
        
        self.logger.info(f"Downloading ONI data from {url}")
        
        try:
            raw_text = self._make_request(url)
            
            # Parse the ONI data format
            lines = raw_text.strip().split('\n')
            
            records = []
            for line in lines:
                parts = line.split()
                if len(parts) >= 13:
                    try:
                        year = int(parts[0])
                        for month, value in enumerate(parts[1:13], 1):
                            if value != '-99.99' and value != '-99.9':
                                records.append({
                                    'year': year,
                                    'month': month,
                                    'oni': float(value)
                                })
                    except ValueError:
                        continue
            
            if not records:
                raise ValidationError(
                    "No valid ONI records found",
                    field="oni_data"
                )
            
            df = pd.DataFrame(records)
            df['date'] = pd.to_datetime(df[['year', 'month']].assign(day=1))
            df = df.set_index('date')[['oni']]
            df = df.sort_index()

            # Clean NOAA sentinel values that slipped through string filter
            df['oni'] = df['oni'].replace(-99.9, np.nan)
            df['oni'] = df['oni'].replace(-99.90, np.nan)
            
            self.logger.info(
                f"Downloaded ONI data:\n"
                f"  Date range: {df.index.min()} to {df.index.max()}\n"
                f"  Records: {len(df)}"
            )
            
            return df
            
        except Exception as e:
            if isinstance(e, (ValidationError, NetworkError)):
                raise
            raise DataAcquisitionError(
                "Failed to download ONI data",
                source="NOAA",
                context={"url": url},
                original_exception=e
            )
    
    @log_execution_time()
    def download_dmi(self) -> pd.DataFrame:
        """
        Download Dipole Mode Index (DMI) data.
        
        Returns
        -------
        pd.DataFrame
            DMI time series with monthly values
        """
        url = ClimateIndices.DMI['data_url']
        
        self.logger.info(f"Downloading DMI data from {url}")
        
        try:
            raw_text = self._make_request(url)
            
            # Parse DMI data format (similar to ONI)
            lines = raw_text.strip().split('\n')
            
            records = []
            for line in lines:
                parts = line.split()
                if len(parts) >= 13:
                    try:
                        year = int(parts[0])
                        for month, value in enumerate(parts[1:13], 1):
                            if value != '-99.99' and value != '-999.00' and value != '-99.9':
                                records.append({
                                    'year': year,
                                    'month': month,
                                    'dmi': float(value)
                                })
                    except ValueError:
                        continue
            
            if not records:
                raise ValidationError(
                    "No valid DMI records found",
                    field="dmi_data"
                )
            
            df = pd.DataFrame(records)
            df['date'] = pd.to_datetime(df[['year', 'month']].assign(day=1))
            df = df.set_index('date')[['dmi']]
            df = df.sort_index()

            # Clean NOAA sentinel values
            df['dmi'] = df['dmi'].replace(-9999, np.nan)
            df['dmi'] = df['dmi'].replace(-9999.0, np.nan)

            self.logger.info(
                f"Downloaded DMI data:\n"
                f"  Date range: {df.index.min()} to {df.index.max()}\n"
                f"  Records: {len(df)}"
            )
            
            return df
            
        except Exception as e:
            if isinstance(e, (ValidationError, NetworkError)):
                raise
            raise DataAcquisitionError(
                "Failed to download DMI data",
                source="NOAA",
                context={"url": url},
                original_exception=e
            )
    
    @log_execution_time()
    def download_amo(self) -> pd.DataFrame:
        """
        Download Atlantic Multidecadal Oscillation (AMO) index.

        The unsmoothed monthly AMO index from NOAA PSL/ESRL.
        Essential for Caribbean / Florida bleaching prediction where
        AMO is the dominant secondary climate driver.

        Source: NOAA Physical Sciences Laboratory
        https://psl.noaa.gov/data/correlation/amon.us.data

        Returns
        -------
        pd.DataFrame
            AMO time series with monthly datetime index and 'amo' column.
        """
        url = "https://psl.noaa.gov/data/correlation/amon.us.data"
        self.logger.info(f"Downloading AMO data from {url}")

        try:
            raw_text = self._make_request(url)
            lines = raw_text.strip().split('\n')

            records = []
            for line in lines:
                parts = line.split()
                if len(parts) >= 13:
                    try:
                        year = int(float(parts[0]))
                        if year < 1850 or year > 2100:
                            continue
                        for month_idx in range(12):
                            val = float(parts[month_idx + 1])
                            # NOAA uses -99.99 or -99.990 as missing
                            if val < -90:
                                continue
                            dt = pd.Timestamp(year=year, month=month_idx + 1, day=1)
                            records.append({'date': dt, 'amo': val})
                    except (ValueError, IndexError):
                        continue

            if not records:
                raise DataAcquisitionError(
                    "No valid AMO records parsed", source="NOAA PSL")

            df = pd.DataFrame(records).set_index('date').sort_index()

            self.logger.info(
                f"AMO data downloaded:\n"
                f"  Period: {df.index.min().date()} to {df.index.max().date()}\n"
                f"  Records: {len(df)}"
            )
            return df

        except Exception as e:
            if isinstance(e, (ValidationError, NetworkError, DataAcquisitionError)):
                raise
            raise DataAcquisitionError(
                "Failed to download AMO data",
                source="NOAA PSL",
                context={"url": url},
                original_exception=e
            )
    
    def add_lagged_indices(
        self,
        df: pd.DataFrame,
        oni: pd.DataFrame,
        dmi: pd.DataFrame,
        amo: Optional[pd.DataFrame] = None,
        oni_lag_months: List[int] = [3, 4],
        dmi_lag_months: List[int] = [3],
        amo_lag_months: List[int] = [2, 3],
    ) -> pd.DataFrame:
        """
        Add lagged climate indices to a DataFrame.
        
        Parameters
        ----------
        df : pd.DataFrame
            Target DataFrame with datetime index
        oni : pd.DataFrame
            ONI data
        dmi : pd.DataFrame
            DMI data
        amo : pd.DataFrame, optional
            AMO data (for Caribbean / Florida regions)
        oni_lag_months : list
            ONI lag periods in months
        dmi_lag_months : list
            DMI lag periods in months
        amo_lag_months : list
            AMO lag periods in months
        
        Returns
        -------
        pd.DataFrame
            DataFrame with added lagged indices
        """
        self.logger.info("Adding lagged climate indices...")
        
        result = df.copy()
        
        # Resample indices to daily if needed
        oni_daily = oni.resample('D').ffill()
        dmi_daily = dmi.resample('D').ffill()
        
        # Add lagged ONI
        for lag in oni_lag_months:
            col_name = f'ONI_lag{lag}'
            shifted = oni_daily.shift(periods=lag * 30)  # Approximate monthly lag
            result = result.join(shifted.rename(columns={'oni': col_name}), how='left')
            self.logger.debug(f"Added {col_name}")
        
        # Add lagged DMI
        for lag in dmi_lag_months:
            col_name = f'DMI_lag{lag}'
            shifted = dmi_daily.shift(periods=lag * 30)
            result = result.join(shifted.rename(columns={'dmi': col_name}), how='left')
            self.logger.debug(f"Added {col_name}")

        # Add lagged AMO (for Caribbean / Florida / Atlantic regions)
        if amo is not None and not amo.empty:
            amo_daily = amo.resample('D').ffill()
            for lag in amo_lag_months:
                col_name = f'AMO_lag{lag}'
                shifted = amo_daily.shift(periods=lag * 30)
                result = result.join(
                    shifted.rename(columns={'amo': col_name}), how='left')
            self.logger.debug(f"Added {col_name}")
        
        return result
