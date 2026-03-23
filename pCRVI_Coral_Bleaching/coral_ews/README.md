# Coral Bleaching Early Warning System

## Andaman & Nicobar Islands Implementation

A comprehensive, modular Python package for satellite-based coral bleaching prediction using Google Earth Engine, Copernicus Marine Data, and machine learning.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Data Sources](#data-sources)
- [Methodology](#methodology)
- [Usage Examples](#usage-examples)
- [Configuration](#configuration)
- [Error Handling](#error-handling)
- [References](#references)

---

## Overview

This package implements a coral bleaching early warning system following verified methodologies from peer-reviewed literature:

- **DHW Calculation**: Liu et al. 2014 (Remote Sensing 6:11579-11606)
- **ML Prediction**: Cheung et al. 2025 (Global Ecology and Biogeography)
- **Data Sources**: All asset IDs and URLs verified against official catalogs (January 2026)

### Key Features

- ✅ Modular, debuggable architecture
- ✅ Comprehensive error handling with diagnostics
- ✅ Verified data source configurations
- ✅ Leave-One-Year-Out cross-validation
- ✅ SHAP interpretability analysis
- ✅ Command-line interface

---

## Installation

### Prerequisites

- Python 3.8+
- Google Earth Engine account
- Copernicus Marine account (free registration)

### Install Package

```bash

source ./coralenv/bin/activate

# Clone or copy the coral_ews directory

# Install dependencies
pip install -r coral_ews/requirements.txt

# Authenticate with Google Earth Engine - This must always be run before running the code
earthengine authenticate

# Authenticate with Copernicus Marine - This must always be run before running the code. 
copernicusmarine login
```

---
GEE project ID is my-coral-project 
Compernicus username: hcomputing
Copernicus Password: bSv!e9.bfFdqSM7

## Quick Start
export GEE_PROJECT_ID=my-coral-project
python -m coral_ews run --start 2020-01-01 --end 2020-12-31

### Command Line

```bash
# Test connections to all data sources
python -m coral_ews test-connections --gee-project my-coral-project

# Run full workflow for a date range
python -m coral_ews run --start 2020-01-01 --end 2020-12-31 --gee-project my-coral-project

# Generate current alert
python -m coral_ews alert --days 90 --gee-project my-coral-project

# Run 20+ year analysis:
python -m coral_ews run --start 2005-01-01 --end 2025-12-31 --gee-project my-coral-project
```

**Expected Output Structure:**
```
output/
├── csv/
│   ├── sst_timeseries.csv          # ~7600 records
│   ├── dhw_timeseries.csv
│   ├── ocean_color_timeseries.csv
│   ├── atmospheric_timeseries.csv
│   ├── climate_indices.csv
│   ├── feature_matrix.csv
│   └── annual_summary.csv
├── visualizations/
│   ├── dhw_timeseries.png
│   ├── sst_dhw_combined.png
│   ├── annual_max_dhw.png
│   ├── alert_distribution.png
│   ├── seasonal_pattern.png
│   ├── feature_correlation.png
│   ├── climate_vs_dhw.png
│   ├── region_map.png              
│   ├── annual_bleaching_map.png    
│   └── bleaching_heatmap.png      
└── reports/
    └── summary_report.txt
### Python API

python
from coral_ews import Config
from coral_ews.pipeline import CoralBleachingEWS

# Initialize
ews = CoralBleachingEWS()

# Run workflow
results = ews.run_full_workflow(
    start_date='2020-01-01',
    end_date='2020-12-31'
)

# Get alert
alert = ews.generate_weekly_alert()
print(f"DHW: {alert['dhw']:.2f} °C-weeks")
print(f"Status: {alert['status']}")
```

---

## Architecture

```
coral_ews/
├── __init__.py           # Package initialization
├── __main__.py           # CLI entry point
├── config.py             # Configuration with verified data sources
├── exceptions.py         # Custom exception hierarchy
├── logger.py             # Logging with diagnostics
├── pipeline.py           # Main orchestration
│
├── data_acquisition/     # Data source clients
│   ├── gee_client.py     # Google Earth Engine
│   ├── copernicus_client.py  # Copernicus Marine
│   └── noaa_client.py    # NOAA + Climate Indices
│
├── processing/           # Data processing
│   ├── dhw_calculator.py # DHW calculation (Liu et al. 2014)
│   └── feature_engineering.py  # Feature preparation
│
└── models/              # Machine learning
    └── predictor.py     # Random Forest with LOYO CV
```

---

## Data Sources

### ✅ Verified GEE Datasets

| Dataset | Asset ID | Temporal Coverage | Notes |
|---------|----------|-------------------|-------|
| NOAA OISST v2.1 | `NOAA/CDR/OISST/V2_1` | 1981-present | SST, 27.8km |
| MODIS Aqua | `NASA/OCEANDATA/MODIS-Aqua/L3SMI` | 2002-2022 | **Kd490 NOT available** |
| ERA5 Hourly | `ECMWF/ERA5/HOURLY` | 1940-present | Cloud cover here only |
| HYCOM | `HYCOM/sea_water_velocity` | 1992-2024 | Currents |
| Allen Coral Atlas | `ACA/reef_habitat/v2_0` | Static | Reef mask |

### ⚠️ Critical Data Gaps

1. **Kd490 NOT in GEE MODIS** - Use Copernicus Marine instead
2. **GEE MODIS ended February 2022** - No recent data
3. **ERA5 DAILY has NO cloud cover** - Must use HOURLY
4. **Copernicus GEE Kd490 only from Feb 2025** - 3-year gap

### Copernicus Marine Datasets

| Dataset | ID | Coverage |
|---------|-----|----------|
| GlobColour L3 MY | `OCEANCOLOUR_GLO_BGC_L3_MY_009_103` | 1997-present |
| GlobColour L3 NRT | `OCEANCOLOUR_GLO_BGC_L3_NRT_009_101` | Recent |

---

## Methodology

### DHW Calculation (Liu et al. 2014)

```
DHW(i) = Σ(HS(j) / 7) for all j where HS(j) ≥ 1°C
         over 84 days preceding day i

Where:
  HS (HotSpot) = max(0, SST - MMM)
  MMM = Maximum Monthly Mean SST
  Accumulation = 84 days (12 weeks)
  Only HotSpots ≥ 1°C are accumulated
```

### Alert Thresholds

| Level | DHW (°C-weeks) | Expected Impact |
|-------|----------------|-----------------|
| Watch | 0 < DHW < 4 | Elevated stress |
| Alert 1 | 4 ≤ DHW < 8 | Significant bleaching |
| Alert 2 | 8 ≤ DHW < 12 | Severe bleaching/mortality |
| Alert 3 | 12 ≤ DHW < 16 | Multi-species mortality |
| Alert 4+ | DHW ≥ 16 | Near-complete mortality |

### ML Model (Cheung et al. 2025)

- **Algorithm**: Random Forest Classifier
- **Target**: 3-class ordinal (none, moderate, severe)
- **Cross-validation**: Leave-One-Year-Out (LOYO)
- **Interpretability**: SHAP analysis

---

## Usage Examples

### Individual Module Usage

```python
# 1. GEE Data Acquisition
from coral_ews.data_acquisition import GEEClient

gee = GEEClient()
gee.authenticate()

# Get SST data
sst_collection = gee.get_oisst_collection('2020-01-01', '2020-12-31')
sst_df = gee.extract_timeseries(sst_collection, 'sst')

# 2. DHW Calculation
from coral_ews.processing import DHWCalculator

dhw_calc = DHWCalculator(mmm=29.87)  # ANI MMM
dhw_df = dhw_calc.calculate_dhw_timeseries(sst_df['sst'])

print(f"Max DHW: {dhw_df['dhw'].max():.2f} °C-weeks")

# 3. Copernicus Ocean Color
from coral_ews.data_acquisition import CopernicusClient

cop = CopernicusClient()
nc_file = cop.download_kd490('2020-01-01', '2020-12-31')
ds = cop.load_downloaded_data(nc_file)

# 4. Model Training
from coral_ews.models import BleachingPredictor

model = BleachingPredictor()
cv_results = model.cross_validate_loyo(X, y, years)
print(f"Mean Accuracy: {cv_results['cv_summary']['mean_accuracy']:.3f}")
```

### Error Handling

```python
from coral_ews.exceptions import GEEError, CopernicusError, ValidationError

try:
    gee = GEEClient()
    gee.authenticate()
    collection = gee.get_oisst_collection('2020-01-01', '2020-12-31')
except GEEError as e:
    print(f"GEE Error: {e.error_code}")
    print(f"Suggestion: {e.suggestion}")
    print(f"Context: {e.context}")
except CopernicusError as e:
    print(f"Copernicus Error: {e}")
except ValidationError as e:
    print(f"Validation Error: {e.field} - expected {e.context.get('expected')}")
```

---

## Configuration

### Default Configuration

```python
from coral_ews.config import Config, ANIRegion

config = Config()

# Study region
print(config.region.name)          # "Andaman & Nicobar Islands"
print(config.region.bounds)        # (90.0, 6.0, 95.0, 14.0)
print(config.region.mmm_sst)       # 29.87°C

# DHW parameters (Liu et al. 2014)
print(config.dhw_params.accumulation_days)    # 84
print(config.dhw_params.hotspot_threshold)    # 1.0°C

# ML parameters (Cheung et al. 2025)
print(config.ml_params.rf_params['n_estimators'])  # 500
```

### Custom Configuration

```python
from coral_ews.config import Config, ANIRegion

# Custom region
custom_region = ANIRegion(
    name="Custom Study Area",
    bounds=(91.0, 7.0, 94.0, 13.0),
    mmm_sst=30.0
)

config = Config(region=custom_region)
```

---

## Error Handling

The package uses a hierarchical exception system for granular error handling:

```
CoralEWSError (base)
├── DataAcquisitionError
│   ├── GEEError
│   ├── CopernicusError
│   └── NetworkError
├── ValidationError
├── ProcessingError
└── ModelError
```

Each exception includes:
- **error_code**: Programmatic identifier
- **message**: Human-readable description
- **context**: Dictionary with debugging information
- **suggestion**: Recommended fix
- **original_exception**: Underlying exception if wrapped

### Diagnostic Reports

```python
from coral_ews.logger import create_diagnostic_report, get_logger

logger = get_logger("coral_ews")

try:
    # Some operation
    pass
except Exception as e:
    report = create_diagnostic_report(logger, e, context={
        "operation": "sst_acquisition",
        "date_range": "2020-01-01 to 2020-12-31"
    })
    # Report includes system info, traceback, and context
```

---

## ANI Bleaching Events (Validation Data)

Historical bleaching events for model validation:

| Year | DHW (°C-weeks) | Bleaching Extent | Notes |
|------|----------------|------------------|-------|
| 1998 | 4.9 | ~80% | First global mass bleaching |
| 2010 | 11.7 | Catastrophic | Most severe for ANI |
| 2016 | 7.2-9.5 | Up to 83.6% | Third global event |

---

## References

### Primary Methodology

1. **Liu G, Heron SF, Eakin CM, et al.** (2014). Reef-Scale Thermal Stress Monitoring of Coral Ecosystems: New 5-km Global Products from NOAA Coral Reef Watch. *Remote Sensing* 6:11579-11606. DOI: 10.3390/rs61111579

2. **Cheung MWM, Hock K, Skirving W, Mumby PJ.** (2025). Cumulative thermal stress forecasts coral bleaching more accurately at a global scale. *Global Ecology and Biogeography*.

### Data Sources

3. **NOAA Coral Reef Watch**: https://coralreefwatch.noaa.gov/
4. **Google Earth Engine Data Catalog**: https://developers.google.com/earth-engine/datasets
5. **Copernicus Marine Data Store**: https://data.marine.copernicus.eu/
6. **INCOIS Coral Bleaching Alert System**: https://incois.gov.in/

### Regional Studies

7. **Vivekanandan E, et al.** (2008). Thermal thresholds for coral bleaching in the Indian seas.
8. **Arthur R, et al.** (2006). Patterns of coral recovery in the Andaman and Nicobar Islands.

---

## Troubleshooting

### Common Issues

**1. GEE Authentication Failed**
```bash
earthengine authenticate
# Follow browser prompts
```

**2. Copernicus Login Failed**
```bash
copernicusmarine login
# Or set environment variables:
export COPERNICUSMARINE_SERVICE_USERNAME=your_username
export COPERNICUSMARINE_SERVICE_PASSWORD=your_password
```

**3. Kd490 Not Found in GEE MODIS**
This is expected - Kd490 is NOT available in GEE MODIS dataset. Use Copernicus Marine instead:
```python
from coral_ews.data_acquisition import CopernicusClient
cop = CopernicusClient()
cop.download_kd490('2020-01-01', '2020-12-31')
```

**4. ERA5 Cloud Cover Not Found**
Cloud cover is only in ERA5 HOURLY, not DAILY:
```python
# Correct
collection = gee.get_era5_hourly(start_date, end_date)
# Wrong - will not have cloud cover
# collection = ee.ImageCollection('ECMWF/ERA5/DAILY')
```

**5. GEE Computation Timeout**
For large regions or date ranges, export to Drive instead:
```python
task = gee.export_to_drive(image, "export_name", wait=True)
```

---

## License

This code is provided for research and educational purposes as part of M.Tech thesis work at IIIT Hyderabad.

---

## Contributing

Contributions are welcome! Please ensure:
1. All data source IDs are verified against official catalogs
2. Error handling follows the established exception hierarchy
3. New features include appropriate logging
4. Code is documented with docstrings
