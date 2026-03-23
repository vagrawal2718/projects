# Enhanced Predictive Coral Reef Vulnerability Index (pCRVI)

A seven-component satellite-based early warning system for coral bleaching, validated across 14 reef systems in three ocean basins.

## Overview

The standard operational metric for coral bleaching risk, NOAA's Degree Heating Weeks (DHW), is a single-variable thermal accumulator that is inherently reactive and does not account for non-thermal stressors. pCRVI addresses these limitations by integrating seven normalised sub-indices spanning thermal, environmental, and climatological drivers of bleaching vulnerability into a single composite index.

**Primary study area:** Andaman and Nicobar Islands (ANI), India (12 reef sites, 28-year record: 1998-2025)

**Key results on the ANI calibration domain:**
- 7/7 documented bleaching events detected (vs. 3/7 for DHW)
- 86% early warning rate (moderate-risk threshold exceeded at least 30 days before peak bleaching in 6/7 events)
- Day-level skill at optimal threshold: F1 = 0.54, MCC = 0.54, HSS = 0.53 over 10,167 daily observations

**Cross-region generalisation (14 reef systems, ANI-calibrated weights, no recalibration):**
- Mean event detection rate: 91%
- Median early warning lead time: 79 days
- Day-level F1 range: 0.49 (Gulf of Kachchh) to 0.89 (Great Barrier Reef)

## The Seven Components

| # | Component | Weight | What it captures |
|---|-----------|--------|------------------|
| 1 | **Thermal Anomaly (TA)** | 0.25 | SST departure from seasonal norm and HotSpot exceedance above MMM |
| 2 | **Accumulating Stress (AS)** | 0.18 | DHW magnitude, 30-day trend, and acceleration momentum |
| 3 | **Water Quality Stress (WQ)** | 0.15 | Chlorophyll-a anomalies (nutrient proxy) and Kd490 turbidity (U-shaped) |
| 4 | **Climate Driver Risk (CDR)** | 0.12 | ENSO (ONI), Indian Ocean Dipole (DMI), AMO teleconnections |
| 5 | **Light Availability (LA)** | 0.12 | Cloud-derived PAR proxy and water clarity for photo-oxidative co-stress |
| 6 | **Seasonal Risk (SR)** | 0.10 | Cosine-based seasonal susceptibility window centred on peak bleaching day |
| 7 | **Bleaching History (BH)** | 0.08 | Inverted adaptive capacity based on time since last bleaching event |

An **Extreme Variability (EV) amplifier** increases the base index by up to 15% when multiple variables simultaneously exceed their 2-sigma thresholds.

The composite index is computed as:

```
pCRVI = 0.25*TA + 0.18*AS + 0.10*SR + 0.12*CDR + 0.08*BH + 0.15*WQ + 0.12*LA
pCRVI_final = pCRVI_base * (1 + 0.15 * EV)
```

## Data Sources

| Variable | Product | Source | Resolution |
|----------|---------|--------|------------|
| Sea Surface Temperature | NOAA OISSTv2.1 | NOAA/NCEI via GEE | 0.25 deg, daily |
| Degree Heating Weeks | NOAA CRW | NOAA Coral Reef Watch | 5 km, daily |
| Chlorophyll-a | CMEMS GlobColour L3 | Copernicus Marine | 4 km, daily |
| Kd490 | CMEMS GlobColour L3 | Copernicus Marine | 4 km, daily |
| Cloud cover, Wind speed | ERA5 Reanalysis | ECMWF via GEE | 0.25 deg, hourly |
| ONI | Nino-3.4 SSTA | NOAA CPC | Monthly |
| DMI | IOD index | NOAA PSL / BoM | Monthly |
| AMO | North Atlantic SSTA | NOAA ESRL/PSL | Monthly |

All data span 1998-2025 (28 years, 10,167 daily records).

## Risk Thresholds

| Level | pCRVI Threshold | Interpretation |
|-------|----------------|----------------|
| Low | < 0.35 | Background conditions |
| Moderate | 0.35 - 0.55 | Elevated risk, monitoring recommended |
| High | 0.55 - 0.70 | Significant bleaching risk, management action advised |
| Critical | > 0.70 | Severe bleaching likely imminent |

## Cross-Region Coverage

pCRVI was parameterised for 14 reef systems across three ocean basins. Only three parameters are tuned per region (MMM climatology, peak bleaching season, climate driver blending weights). All component formulas and weights remain fixed.

**Indian Ocean (5 reefs):** Andaman and Nicobar Islands, Lakshadweep, Gulf of Mannar, Gulf of Kachchh, Malvan Sanctuary

**Southeast Asia (4 reefs):** Coral Triangle (Indonesia), Thailand (Andaman Sea), Philippines, Malaysia (Sabah)

**Global (5 reefs):** Great Barrier Reef, Florida Reef Tract, Maldives, Seychelles, Mesoamerican Barrier Reef

## Validation Summary

### ANI Calibration Domain (7 events, 1998-2024)

| Year | Severity | Bleaching % | pCRVI Max | DHW | pCRVI Detection | DHW Detection |
|------|----------|-------------|-----------|-----|-----------------|---------------|
| 1998 | Severe | 80% | 0.695 | 4.9 | CORRECT | UNDER |
| 2002 | Minor | 15% | 0.490 | 2.5 | CLOSE | UNDER |
| 2005 | Minor | 20% | 0.579 | 3.5 | CLOSE | UNDER |
| 2010 | Catastrophic | 77% | 0.738 | 11.7 | CLOSE | UNDER |
| 2016 | Moderate | 40% | 0.748 | 8.3 | CLOSE | CORRECT |
| 2020 | Moderate | 35% | 0.504 | 6.0 | CORRECT | UNDER |
| 2024 | Moderate | 50% | 0.808 | 8.0 | CLOSE | CORRECT |

### Day-Level Skill Metrics (at optimal threshold = 0.60)

| Metric | Value |
|--------|-------|
| True Negatives | 9,771 |
| False Positives | 187 |
| False Negatives | 63 |
| True Positives | 146 |
| Precision | 43.8% |
| Recall | 69.9% |
| F1 Score | 0.54 |
| MCC | 0.54 |
| HSS | 0.53 |

## Implementation

The pipeline is implemented in Python with data acquisition through:
- Google Earth Engine (SST, ERA5)
- Copernicus Marine Service (ocean colour)
- NOAA CRW APIs (DHW, HotSpot)
- NOAA CPC/PSL (climate indices)

## Project Structure

```
pCRVI_Coral_Bleaching/
├── 2023101040_BTP_PCRVI_Report.docx
├── 2023101040_BTP_PCRVI_Report.pdf
├── pCRVI_2026_El_Nino_Projection_Report.pdf
├── README.md
├── coral_ews/                          # Core Python package
│   ├── __init__.py
│   ├── __main__.py                     # Entry point
│   ├── config.py                       # Configuration and parameters
│   ├── enhanced_pcrvi.py               # pCRVI composite index computation
│   ├── cross_region.py                 # Multi-region parameterisation
│   ├── pipeline.py                     # End-to-end processing pipeline
│   ├── dhw_forecaster.py               # DHW forecasting models
│   ├── data_cache.py                   # Local data caching
│   ├── exceptions.py                   # Custom exceptions
│   ├── gdrive_sync.py                  # Google Drive sync utilities
│   ├── logger.py                       # Logging configuration
│   ├── naming.py                       # Output file naming conventions
│   ├── outputs.py                      # Output generation
│   ├── paper_results.py                # Paper-ready tables and statistics
│   ├── poster_visualizations.py        # Poster figure generation
│   ├── reef_regions.py                 # Reef site definitions (14 regions)
│   ├── visualization.py                # Main visualisation module
│   ├── visualization_forecast.py       # Forecast-specific plots
│   ├── requirements.txt
│   ├── README.md
│   ├── data_acquisition/               # Satellite data clients
│   │   ├── __init__.py
│   │   ├── gee_client.py               # Google Earth Engine (SST, ERA5)
│   │   ├── gee_client_standard.py
│   │   ├── copernicus_client.py         # CMEMS ocean colour
│   │   └── noaa_client.py              # NOAA CRW DHW/HotSpot
│   ├── models/                         # ML models
│   │   ├── __init__.py
│   │   ├── predictor.py
│   │   ├── xgboost_model.py
│   │   └── zero_inflated.py
│   ├── processing/                     # Data processing
│   │   ├── __init__.py
│   │   ├── dhw_calculator.py
│   │   └── feature_engineering.py
│   └── tests/
│       ├── tests__init__.py
│       └── synthetic_data.py
├── output/                             # Generated outputs (excluded from git)
│   ├── andaman/                        # Per-region results
│   │   ├── csv/                        # Time series, feature matrices, predictions
│   │   ├── paper/                      # Paper-ready tables and statistics
│   │   ├── reports/                    # Text and HTML reports
│   │   └── visualizations/             # Plots, dashboards, poster figures
│   ├── florida/
│   ├── great_barrier_reef/
│   ├── gulf_of_kachchh/
│   ├── gulf_of_mannar/
│   ├── indonesia/
│   ├── lakshadweep/
│   ├── malaysia_sabah/
│   ├── maldives/
│   ├── malvan/
│   ├── mesoamerican/
│   ├── philippines/
│   ├── seychelles/
│   ├── thailand_andaman/
│   └── _comparison/                    # Cross-region comparison figures
└── reef_maps/                          # Regional reef location and DHW spatial maps
    ├── all_reef_maps.pdf
    ├── andaman_01_regional_map_reef_locations.png
    ├── andaman_04_spatial_dhw_bleaching_years.png
    └── ... (maps for all 14 regions)
```

**Note:** The `output/` directory (317 MB of generated CSVs, reports, and visualisations) is excluded from the repository via `.gitignore`. To regenerate outputs, run the pipeline for each region.

## Limitations

- Component weights were optimised against 7 events in the ANI domain and should be treated as domain-tuned parameters rather than universal constants
- Satellite-derived chlorophyll-a is an indirect proxy for dissolved inorganic nitrogen (DIN), the actual mechanistic driver of lowered bleaching thresholds
- SST input resolution (0.25 deg) is coarser than the NOAA CRW product (5 km), smoothing out reef-scale thermal heterogeneity
- The Bleaching History component relies on published records that may be incomplete for older events
- Day-level F1 of 0.54 reflects severe class imbalance (bleaching days constitute less than 3% of the record)

## References

Key references underpinning the pCRVI framework:

- Hughes, T.P., et al. (2018). Global warming transforms coral reef assemblages. *Nature*, 556, 492-496.
- Liu, G., et al. (2014). Reef-scale thermal stress monitoring of coral ecosystems. *Remote Sensing*, 6(11), 11579-11606.
- Wooldridge, S.A. (2009). Water quality and coral bleaching thresholds. *Marine Pollution Bulletin*, 58(5), 745-751.
- Lesser, M.P. (2011). Coral bleaching: causes and mechanisms. In *Coral Reefs: An Ecosystem in Transition*, Springer.
- Sully, S., et al. (2019). A global analysis of coral bleaching over the past two decades. *Nature Communications*, 10, 1264.
- DeCarlo, T.M. (2020). Treating coral bleaching as weather. *PeerJ*, 8, e9449.
- Cheung, M.W.M., et al. (2025). Moving beyond temperature metrics in coral bleaching prediction. *Global Ecology and Biogeography*, 34(8), e70105.

## Authors

**Vishakha Agrawal**

B.Tech.Project (BTP) carried out under the supervision of **Dr. Rama Chandra Prasad**, Lab for Spatial Informatics, International Institute of Information Technology Hyderabad (IIIT-H).
