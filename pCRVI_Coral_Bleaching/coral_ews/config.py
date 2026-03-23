"""
Configuration Module for Coral Bleaching EWS
=============================================

Contains all verified data sources, asset IDs, parameters, and settings.
All values have been verified against authoritative sources (January 2026).

Sources verified:
- Google Earth Engine Data Catalog
- NOAA Coral Reef Watch official documentation
- Copernicus Marine Data Store
- Liu et al. 2014 methodology
"""

from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
from datetime import datetime, date
import os
import json


@dataclass
class ANIRegion:
    """
    Andaman & Nicobar Islands study region definition.
    
    Verified coordinates encompass the full island chain.
    """
    name: str = "Andaman & Nicobar Islands"
    # Regional DHW thresholds (calibrated for Andaman & Nicobar)
    # Standard NOAA: Watch=0, Warning=4, Alert1=8, Alert2=12
    # Calibrated for ANI based on historical bleaching correlation:
    DHW_THRESHOLDS = {
        'no_stress': 0.0,
        'watch': 1.0,        # Lowered from implicit 0 - early warning
        'warning': 3.0,      # Lowered from 4.0 - bleaching begins
        'alert_level_1': 6.0,  # Lowered from 8.0 - significant bleaching
        'alert_level_2': 8.0,  # Lowered from 12.0 - mass bleaching/mortality
    }
    
    # Historical bleaching events for validation
    KNOWN_BLEACHING_EVENTS = {
        1998: {
            'severity': 'severe',
            'dhw_reported': 4.9,
            'bleaching_pct': 80,
            'peak_month': 5,  # May
            'notes': 'First global bleaching event, strong El Niño',
            'source': 'Mondal et al. 2014; Arthur 2000'
        },
        2002: {
            'severity': 'minor',
            'dhw_reported': 2.5,
            'bleaching_pct': 15,
            'peak_month': 5,
            'notes': 'Localized bleaching',
            'source': 'Andaman Sea monitoring reports'
        },
        2005: {
            'severity': 'minor',
            'dhw_reported': 3.5,
            'bleaching_pct': 20,
            'peak_month': 5,
            'notes': 'Post-tsunami recovery period assessment',
            'source': 'Roy et al. 2014'
        },
        2010: {
            'severity': 'catastrophic',
            'dhw_reported': 11.7,
            'bleaching_pct': 77,
            'peak_month': 5,  # April-May
            'notes': 'El Niño Modoki, 87% in South Andaman, SST up to 34°C',
            'source': 'Krishnan et al. 2011; Marimuthu et al. 2013'
        },
        2016: {
            'severity': 'moderate',
            'dhw_reported': 8.3,
            'bleaching_pct': 40,
            'peak_month': 4,  # March-April
            'notes': 'Third global bleaching event, DHW 7.2-9.5',
            'source': 'Majumdar et al. 2018'
        },
        2020: {
            'severity': 'moderate',
            'dhw_reported': 6.0,
            'bleaching_pct': 35,
            'peak_month': 5,
            'notes': 'Following extreme IOD event of 2019',
            'source': 'Mhalaskar et al. 2024; NCCR monitoring'
        },
        2024: {
            'severity': 'moderate',
            'dhw_reported': 8.0,
            'bleaching_pct': 50,
            'peak_month': 5,  # April-May
            'notes': 'Fourth Global Coral Bleaching Event (GCBE4)',
            'source': 'PIB India 2024; Down to Earth 2024'
        },
    }

    # Bounding box [lon_min, lat_min, lon_max, lat_max]
    bounds: Tuple[float, float, float, float] = (90.0, 6.0, 95.0, 14.0)
    
    # Center point for visualization
    center_lon: float = 92.5
    center_lat: float = 10.0
    
    # Maximum Monthly Mean SST from NOAA CRW Virtual Station
    # Source: coralreefwatch.noaa.gov/product/vs/data/andaman.txt
    mmm_sst: float = 29.87  # °C
    
    # Bleaching threshold (MMM + 1°C)
    bleaching_threshold: float = 30.87  # °C
    
    # Literature-based SST threshold (Vivekanandan et al. 2008)
    sst_threshold_literature: float = 31.0  # °C
    
    # Peak bleaching season (Indian Ocean)
    # Source: NOAA CRW methodology
    peak_season_months: Tuple[int, ...] = (4, 5, 6)  # April-June
    
    # NOAA CRW real-time map basin identifier
    noaa_basin: str = "indian"
    
    # Climate driver blend: ONI (El Niño) + DMI (Indian Ocean Dipole)
    # van Hooidonk & Huber (2009); Roxy et al. (2011)
    climate_driver_weights: Dict[str, float] = field(default_factory=lambda: {
        'oni': 0.55, 'dmi': 0.45,
    })
    
    def to_gee_geometry(self) -> str:
        """Return GEE geometry code snippet."""
        return f"ee.Geometry.Rectangle([{self.bounds[0]}, {self.bounds[1]}, {self.bounds[2]}, {self.bounds[3]}])"
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "name": self.name,
            "bounds": self.bounds,
            "center": (self.center_lon, self.center_lat),
            "mmm_sst": self.mmm_sst,
            "bleaching_threshold": self.bleaching_threshold
        }
    
    # Literature references for Enhanced-pCRVI component weights
    PCRVI_WEIGHT_REFERENCES = {
        'thermal_anomaly': 'Hughes et al. (2018) Nature 556:492-496',
        'accumulating_stress': 'Liu et al. (2014) Remote Sensing 6:11579-11606',
        'seasonal_risk': 'NOAA CRW operational methodology',
        'climate_driver': 'van Hooidonk & Huber (2009) GRL 36:L05601',
        'bleaching_history': 'Thompson & Dolman (2010) Ecol Appl 20:1619-1627',
        'water_quality': 'Wooldridge (2009) Mar Poll Bull; Sully et al. (2019) Nat Comms',
        'light_availability': 'Lesser (2011) Coral Reefs 30:163; Kirk (2011) Cambridge',
    }

    # Data sources for Enhanced-pCRVI
    PCRVI_DATA_SOURCES = {
        'sst': 'NOAA OISST v2.1 (Reynolds et al. 2007)',
        'dhw': 'Calculated per Liu et al. (2014)',
        'chlorophyll': 'Copernicus GlobColour MODIS/VIIRS L3',
        'kd490': 'Copernicus GlobColour L3 MY',
        'cloud_cover': 'ERA5 Hourly (ECMWF)',
        'wind_speed': 'ERA5 Hourly (ECMWF)',
        'oni': 'NOAA CPC (Huang et al. 2017)',
        'dmi': 'PSL/BOM (Saji et al. 1999)',
    }


@dataclass
class GEEDatasets:
    """
    Google Earth Engine dataset configuration.
    
    All asset IDs and bands verified against GEE Data Catalog (January 2026).
    """
    
    # NOAA OISST v2.1 - Sea Surface Temperature
    # Source: developers.google.com/earth-engine/datasets/catalog/NOAA_CDR_OISST_V2_1
    OISST = {
        "asset_id": "NOAA/CDR/OISST/V2_1",
        "bands": {
            "sst": {"scale": 0.01, "unit": "°C", "description": "Sea surface temperature"},
            "anom": {"scale": 0.01, "unit": "°C", "description": "SST anomaly"},
            "ice": {"scale": 0.01, "unit": "fraction", "description": "Sea ice concentration"},
            "err": {"scale": 0.01, "unit": "°C", "description": "Estimated error"}
        },
        "date_range": ("1981-09-01", "present"),
        "resolution_m": 27830,
        "cadence": "daily",
        "verified_date": "2026-01-24"
    }
    
    # MODIS Aqua Ocean Color
    # Source: developers.google.com/earth-engine/datasets/catalog/NASA_OCEANDATA_MODIS-Aqua_L3SMI
    # CRITICAL: Kd490 NOT available in this dataset
    MODIS_AQUA = {
        "asset_id": "NASA/OCEANDATA/MODIS-Aqua/L3SMI",
        "bands": {
            "chlor_a": {"scale": 1.0, "unit": "mg/m³", "description": "Chlorophyll-a concentration"},
            "sst": {"scale": 1.0, "unit": "°C", "description": "Sea surface temperature"},
            "nflh": {"scale": 1.0, "unit": "mW cm⁻² µm⁻¹ sr⁻¹", "description": "Fluorescence line height"},
            "poc": {"scale": 1.0, "unit": "mg/m³", "description": "Particulate organic carbon"},
            "Rrs_412": {"scale": 1.0, "unit": "sr⁻¹", "description": "Remote sensing reflectance 412nm"},
            "Rrs_443": {"scale": 1.0, "unit": "sr⁻¹", "description": "Remote sensing reflectance 443nm"},
            "Rrs_469": {"scale": 1.0, "unit": "sr⁻¹", "description": "Remote sensing reflectance 469nm"},
            "Rrs_488": {"scale": 1.0, "unit": "sr⁻¹", "description": "Remote sensing reflectance 488nm"},
            "Rrs_531": {"scale": 1.0, "unit": "sr⁻¹", "description": "Remote sensing reflectance 531nm"},
            "Rrs_547": {"scale": 1.0, "unit": "sr⁻¹", "description": "Remote sensing reflectance 547nm"},
            "Rrs_555": {"scale": 1.0, "unit": "sr⁻¹", "description": "Remote sensing reflectance 555nm"},
            "Rrs_645": {"scale": 1.0, "unit": "sr⁻¹", "description": "Remote sensing reflectance 645nm"},
            "Rrs_667": {"scale": 1.0, "unit": "sr⁻¹", "description": "Remote sensing reflectance 667nm"},
            "Rrs_678": {"scale": 1.0, "unit": "sr⁻¹", "description": "Remote sensing reflectance 678nm"}
        },
        "date_range": ("2002-07-03", "2022-02-28"),  # CRITICAL: Dataset ENDED
        "resolution_m": 4616,
        "cadence": "daily",
        "kd490_available": False,  # CRITICAL: Kd490 NOT in GEE MODIS
        "verified_date": "2026-01-24"
    }
    
    # ERA5 Hourly - Atmospheric data
    # Source: developers.google.com/earth-engine/datasets/catalog/ECMWF_ERA5_HOURLY
    # CRITICAL: Cloud cover is ONLY in HOURLY, not DAILY
    ERA5_HOURLY = {
        "asset_id": "ECMWF/ERA5/HOURLY",
        "bands": {
            "total_cloud_cover": {"scale": 1.0, "unit": "0-1", "description": "Total cloud cover fraction"},
            "u_component_of_wind_10m": {"scale": 1.0, "unit": "m/s", "description": "U-wind at 10m"},
            "v_component_of_wind_10m": {"scale": 1.0, "unit": "m/s", "description": "V-wind at 10m"},
            "sea_surface_temperature": {"scale": 1.0, "unit": "K", "description": "SST (Kelvin)"}
        },
        "date_range": ("1940-01-01", "present"),
        "resolution_m": 27830,
        "cadence": "hourly",
        "verified_date": "2026-01-24"
    }
    
    # ERA5 Daily - NO cloud cover
    # Source: developers.google.com/earth-engine/datasets/catalog/ECMWF_ERA5_DAILY
    ERA5_DAILY = {
        "asset_id": "ECMWF/ERA5/DAILY",
        "bands": {
            "mean_2m_air_temperature": {"scale": 1.0, "unit": "K", "description": "Mean air temp"},
            "u_component_of_wind_10m": {"scale": 1.0, "unit": "m/s", "description": "U-wind"},
            "v_component_of_wind_10m": {"scale": 1.0, "unit": "m/s", "description": "V-wind"}
        },
        "date_range": ("1979-01-01", "present"),
        "resolution_m": 27830,
        "cadence": "daily",
        "has_cloud_cover": False,  # CRITICAL: NO cloud cover in DAILY
        "verified_date": "2026-01-24"
    }
    
    # HYCOM Ocean Currents
    # Source: developers.google.com/earth-engine/datasets/catalog/HYCOM_sea_water_velocity
    HYCOM = {
        "asset_id": "HYCOM/sea_water_velocity",
        "bands": {
            "velocity_u_0": {"scale": 0.001, "unit": "m/s", "description": "U-velocity surface"},
            "velocity_v_0": {"scale": 0.001, "unit": "m/s", "description": "V-velocity surface"}
        },
        "date_range": ("1992-10-02", "2024-09-05"),
        "resolution_m": 8905,
        "cadence": "daily",
        "depth_levels": 40,
        "verified_date": "2026-01-24"
    }
    
    # Copernicus Marine Kd490 in GEE
    # Source: developers.google.com/earth-engine/datasets/catalog/COPERNICUS_MARINE_OC_GLO_BGC_TRANSPARENCY_MULTI_4KM
    # CRITICAL: Only available from Feb 2025!
    COPERNICUS_KD490_GEE = {
        "asset_id": "COPERNICUS/MARINE/OC_GLO_BGC/TRANSPARENCY_MULTI_4KM",
        "bands": {
            "KD490": {"scale": 1.0, "unit": "m⁻¹", "description": "Diffuse attenuation coefficient"},
            "KD490_uncertainty": {"scale": 1.0, "unit": "m⁻¹", "description": "KD490 uncertainty"},
            "ZSD": {"scale": 1.0, "unit": "m", "description": "Secchi disk depth"},
            "ZSD_uncertainty": {"scale": 1.0, "unit": "m", "description": "ZSD uncertainty"}
        },
        "date_range": ("2025-02-10", "present"),  # CRITICAL: 3-year gap from MODIS
        "resolution_m": 4000,
        "cadence": "daily",
        "verified_date": "2026-01-24"
    }
    
    # Allen Coral Atlas Reef Mask
    # Source: developers.google.com/earth-engine/datasets/catalog/ACA_reef_habitat_v2_0
    ALLEN_CORAL_ATLAS = {
        "asset_id": "ACA/reef_habitat/v2_0",
        "bands": {
            "geomorphic": {"description": "Geomorphic zonation"},
            "benthic": {"description": "Benthic habitat classification"},
            "reef_mask": {"description": "Binary reef mask"}
        },
        "date_range": ("2018", "2021"),  # Static composite
        "resolution_m": 5,
        "cadence": "static",
        "verified_date": "2026-01-24"
    }


@dataclass
class CopernicusDatasets:
    """
    Copernicus Marine Data Store dataset configuration.
    
    All dataset IDs verified against data.marine.copernicus.eu (January 2026).
    """
    
    # GlobColour L3 Multi-Year (historical) - HAS Kd490 from 1997
    # Source: data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L3_MY_009_103
    GLOBCOLOUR_L3_MY = {
        "dataset_id": "OCEANCOLOUR_GLO_BGC_L3_MY_009_103",
        "product_id": "cmems_obs-oc_glo_bgc-plankton_my_l3-multi-4km_P1D",
        "variables": ["CHL", "KD490", "ZSD", "SPM", "BBP", "CDM"],
        "date_range": ("1997-09-01", "present"),
        "resolution_km": 4,
        "cadence": "daily",
        "description": "Multi-Year reprocessed ocean color (1997-present)",
        "verified_date": "2026-01-24"
    }
    
    # GlobColour L3 Near Real-Time
    # Source: data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L3_NRT_009_101
    GLOBCOLOUR_L3_NRT = {
        "dataset_id": "OCEANCOLOUR_GLO_BGC_L3_NRT_009_101",
        "product_id": "cmems_obs-oc_glo_bgc-plankton_nrt_l3-multi-4km_P1D",
        "variables": ["CHL", "KD490", "ZSD", "SPM", "BBP"],
        "date_range": ("recent", "present"),  # Rolling window
        "resolution_km": 4,
        "cadence": "daily",
        "description": "Near Real-Time ocean color",
        "verified_date": "2026-01-24"
    }
    
    # GlobColour L4 Monthly (gap-filled)
    # Source: data.marine.copernicus.eu/product/OCEANCOLOUR_GLO_BGC_L4_MY_009_104
    GLOBCOLOUR_L4_MY = {
        "dataset_id": "OCEANCOLOUR_GLO_BGC_L4_MY_009_104",
        "variables": ["CHL", "KD490", "ZSD", "PP"],
        "date_range": ("1997-09-01", "present"),
        "resolution_km": 4,
        "cadence": "monthly",
        "description": "Gap-filled monthly ocean color",
        "verified_date": "2026-01-24"
    }


@dataclass
class NOAADatasets:
    """
    NOAA Coral Reef Watch dataset configuration.
    
    All URLs verified against coralreefwatch.noaa.gov (January 2026).
    """
    
    # Virtual Station - Andaman
    VIRTUAL_STATION_ANDAMAN = {
        "url": "https://coralreefwatch.noaa.gov/product/vs/data/andaman.txt",
        "variables": ["SST", "SSTA", "HotSpot", "DHW", "BAA"],
        "date_range": ("1985-01-01", "present"),
        "format": "ASCII text",
        "mmm_location": "header",  # MMM value is in file header
        "verified_date": "2026-01-24"
    }
    
    # 5km Product Suite
    CRW_5KM = {
        "base_url": "https://www.star.nesdis.noaa.gov/pub/socd/mecb/crw/data/5km/v3.1",
        "products": {
            "sst": "nc/v1.0/daily/sst/",
            "dhw": "nc/v1.0/daily/dhw/",
            "hotspot": "nc/v1.0/daily/hotspot/",
            "baa": "nc/v1.0/daily/baa/"
        },
        "date_range": ("1985-01-01", "present"),
        "resolution_km": 5,
        "verified_date": "2026-01-24"
    }
    
    # MMM Climatology
    MMM_CLIMATOLOGY = {
        "url": "https://www.star.nesdis.noaa.gov/pub/socd/mecb/crw/data/5km/v3.1_op/climatology/nc/ct5km_climatology_v3.1.nc",
        "variables": ["mmm", "monthly_climatology"],
        "baseline_period": "1985-1990 plus 1993",
        "verified_date": "2026-01-24"
    }
    
    # Thermal History Products
    THERMAL_HISTORY = {
        "url": "https://coralreefwatch.noaa.gov/product/thermal_history/",
        "products": ["stress_frequency", "histSSTSD", "histmDHW4", "yr_sinceDHW4"],
        "date_range": ("1985", "2024"),
        "verified_date": "2026-01-24"
    }
    
    # ERDDAP Access
    ERDDAP = {
        "base_url": "https://coastwatch.pfeg.noaa.gov/erddap/griddap",
        "datasets": {
            "dhw": "NOAA_DHW",
            "sst": "NOAA_SST",
            "kd490_modis": "erdMH1kd4901day"  # MODIS Kd490 via ERDDAP
        },
        "verified_date": "2026-01-24"
    }


@dataclass 
class ClimateIndices:
    """
    Climate index data sources.
    
    All URLs verified (January 2026).
    """
    
    # Oceanic Niño Index
    ONI = {
        "url": "https://www.cpc.ncep.noaa.gov/products/analysis_monitoring/ensostuff/ONI_v5.php",
        "alternative_url": "https://psl.noaa.gov/data/correlation/oni.data",
        "date_range": ("1950-01-01", "present"),
        "format": "text",
        "description": "3-month running mean of ERSST.v5 SST anomalies in Niño 3.4 region",
        "verified_date": "2026-01-24"
    }
    
    # Dipole Mode Index
    DMI = {
        "url": "https://psl.noaa.gov/gcos_wgsp/Timeseries/DMI/",
        "data_url": "https://psl.noaa.gov/gcos_wgsp/Timeseries/Data/dmi.had.long.data",
        "date_range": ("1870-01-01", "present"),
        "format": "text",
        "description": "Indian Ocean Dipole index",
        "verified_date": "2026-01-24"
    }


@dataclass
class DHWParameters:
    """
    Degree Heating Week calculation parameters.
    
    Based on Liu et al. 2014 (Remote Sensing 6:11579-11606) and
    NOAA CRW 5km Methodology: coralreefwatch.noaa.gov/product/5km/methodology.php
    """
    
    # Accumulation window
    accumulation_days: int = 84  # 12 weeks
    
    # HotSpot threshold for accumulation
    hotspot_threshold: float = 1.0  # °C above MMM
    
    # Division factor (daily to weekly)
    daily_to_weekly_divisor: float = 7.0
    
    # Bleaching alert thresholds (°C-weeks)
    alert_thresholds: Dict[str, float] = field(default_factory=lambda: {
        "watch": 0.0,      # DHW > 0
        "warning": 0.0,    # HotSpot present but < threshold
        "alert_1": 4.0,    # Significant bleaching likely
        "alert_2": 8.0,    # Widespread bleaching and mortality
        "alert_3": 12.0,   # Multi-species mortality
        "alert_4": 16.0,   # Severe mortality (>50%)
        "alert_5": 20.0    # Near-complete mortality (>80%)
    })
    
    # Climatology baseline
    climatology_baseline: str = "1985-1990 plus 1993"


@dataclass
class MLParameters:
    """
    Machine learning model parameters.
    
    Based on Cheung et al. 2025 (Global Ecology and Biogeography).
    """
    
    # Target classes
    bleaching_classes: Dict[str, int] = field(default_factory=lambda: {
        "none": 0,
        "moderate": 1,
        "severe": 2
    })
    
    # Feature list
    features: List[str] = field(default_factory=lambda: [
        "DHW", "SST", "SST_anomaly", "Kd490", "Kd490_anomaly",
        "chlor_a", "cloud_cover", "wind_speed", "current_speed",
        "ONI_lag3", "ONI_lag4", "DMI_lag3"
    ])
    
    # Random Forest parameters (Cheung et al. 2025)
    rf_params: Dict[str, Any] = field(default_factory=lambda: {
        "n_estimators": 500,
        "max_depth": 10,
        "min_samples_split": 5,
        "min_samples_leaf": 2,
        "class_weight": "balanced",
        "random_state": 42,
        "n_jobs": -1
    })
    
    # Cross-validation
    cv_strategy: str = "leave_one_year_out"  # LOYO
    cv_folds: int = 10  # For kNNDM


@dataclass
class Config:
    """
    Main configuration class combining all settings.
    """

    # Study region (ANIRegion or ReefRegion from reef_regions.py)
    region: Any = field(default_factory=ANIRegion)
    
    # Data sources
    gee: GEEDatasets = field(default_factory=GEEDatasets)
    copernicus: CopernicusDatasets = field(default_factory=CopernicusDatasets)
    noaa: NOAADatasets = field(default_factory=NOAADatasets)
    climate_indices: ClimateIndices = field(default_factory=ClimateIndices)
    
    # Processing parameters
    dhw_params: DHWParameters = field(default_factory=DHWParameters)
    ml_params: MLParameters = field(default_factory=MLParameters)
    
    # Output directories
    data_dir: Path = field(default_factory=lambda: Path("./data"))
    output_dir: Path = field(default_factory=lambda: Path("./output"))
    cache_dir: Path = field(default_factory=lambda: Path("./cache"))
    log_dir: Path = field(default_factory=lambda: Path("./logs"))
    
    # Processing settings
    target_resolution_km: float = 5.0
    temporal_aggregation: str = "weekly"  # or "daily"
    
    # Network settings
    request_timeout: int = 300  # seconds
    max_retries: int = 3
    retry_delay: int = 5  # seconds
    
    def __post_init__(self):
        """Create directories if they don't exist."""
        for dir_path in [self.data_dir, self.output_dir, self.cache_dir, self.log_dir]:
            dir_path.mkdir(parents=True, exist_ok=True)
    
    @classmethod
    def for_region(cls, region_key: str, **kwargs) -> 'Config':
        """Create Config for any registered region."""
        from .reef_regions import get_region, REEF_REGISTRY, ReefRegion
        if region_key == 'andaman':
            region = ANIRegion()
        else:
            region = get_region(region_key)
        return cls(region=region, **kwargs)
    
    @classmethod
    def from_json(cls, json_path: Path) -> 'Config':
        """Load configuration from JSON file."""
        with open(json_path, 'r') as f:
            data = json.load(f)
        return cls(**data)
    
    def to_json(self, json_path: Path):
        """Save configuration to JSON file."""
        # Convert to serializable dict
        data = {
            "region": self.region.to_dict(),
            "data_dir": str(self.data_dir),
            "output_dir": str(self.output_dir),
            "target_resolution_km": self.target_resolution_km,
            "temporal_aggregation": self.temporal_aggregation
        }
        with open(json_path, 'w') as f:
            json.dump(data, f, indent=2)
    
    def validate(self) -> List[str]:
        """
        Validate configuration and return list of warnings/issues.
        
        Returns
        -------
        List[str]
            List of validation warnings
        """
        warnings = []
        
        # Check region bounds
        if not (-180 <= self.region.bounds[0] <= 180):
            warnings.append(f"Invalid longitude min: {self.region.bounds[0]}")
        
        # Check MMM value
        if not (25 <= self.region.mmm_sst <= 32):
            warnings.append(f"MMM SST {self.region.mmm_sst}°C seems unusual for tropical reefs")
        
        # Check directories exist
        for dir_name, dir_path in [("data", self.data_dir), ("output", self.output_dir)]:
            if not dir_path.exists():
                warnings.append(f"{dir_name} directory does not exist: {dir_path}")
        
        return warnings


# Global default configuration
DEFAULT_CONFIG = Config()
