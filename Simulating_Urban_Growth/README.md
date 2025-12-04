# Simulating Urban Growth: Hyderabad Metropolitan Expansion (2020-2050)

**Course:** Spatial Informatics
**Institution:** IIIT Hyderabad

## Overview

Hybrid Cellular Automata model predicting Hyderabad's urban expansion using satellite imagery, machine learning, and spatial simulation. Projects built-up area growth from 456.76 km² (2020) to 1,006.91 km² (2050) under business-as-usual scenario.

## Project Structure
```
.
├── TeamX_Workflow.ipynb          # Complete implementation pipeline
├── TeamX_Report.pdf              # Full technical report
├── TeamX_MidEval.pptx            # Mid-term presentation
├── TeamX_EndEval.pptx            # Final presentation
├── TeamX_Result_Code_Demo.mp4   # Demo video
├── Vani_Prasad.pdf               # Reference paper
└── README.md
```

## Methodology

### Framework: CA-MLR-GA Hybrid

**1. LULC Classification (1990-2020)**
- Random Forest on Landsat imagery
- 4 classes: Water, Vegetation, Barren, Built-up
- Training: ESA WorldCover 2020
- Accuracy: 80.12%, Kappa: 0.735

**2. Driver Extraction (5 variables)**
- Terrain: Slope, Elevation (SRTM DEM)
- Socio-economic: Population density (GHS-POP)
- Accessibility: Distance to roads (OSM), Distance to city center
- Z-score standardization, VIF < 4.0

**3. Multinomial Logistic Regression**
- Estimates urbanization probabilities
- Dominant drivers: Population (+1.71), Road proximity (-0.59)
- Pseudo R²: 0.226

**4. Cellular Automata Simulation**
- GA-optimized parameters: ω=1.20, α=0.05, 10 iterations
- 5×5 Moore neighborhood (distance-weighted)
- **Quota-based allocation**: 2.67% annual growth
- Full resolution: 1,691×1,691 grid (2.86M cells, 30m)

**5. Calibration & Validation**
- Sample-based: 4,126 points
- Calibration (1990→2000): 93.65% accuracy, Kappa 0.915
- Validation (2000→2010): 93.43% accuracy, Kappa 0.912

## Key Results

### Urban Expansion
| Year | Built-up (km²) | Vegetation (km²) | Barren (km²) |
|------|----------------|------------------|--------------|
| 2020 | 456.76 | 1,052.28 | 410.76 |
| 2030 | 594.46 | 1,015.88 | 311.60 |
| 2040 | 773.66 | 933.43 | 217.34 |
| 2050 | 1,006.91 | 777.52 | 144.16 |

**Growth:** +550.15 km² (+120.4%) over 30 years  
**Critical Year ~2044:** Built-up surpasses vegetation

### Spatial Patterns
- Core densification along existing urban areas
- Corridor expansion following major roads
- Peripheral sprawl within 25km radius
- 274.76 km² vegetation loss (-26.1%)

### Parameter Sensitivity (17 scenarios)
- **Growth rate** dominates spatial patterns (14-53× stronger than CA parameters)
- Quota-based allocation prevents over-prediction
- Neighborhood weight: moderate clustering effect
- Stochasticity: minimal spatial impact

## Implementation

### Data Sources
- **Imagery:** Landsat TM/ETM+/OLI (USGS, 30m)
- **Reference:** ESA WorldCover 2020 (10m)
- **Terrain:** SRTM DEM (30m)
- **Population:** GHS-POP (100m)
- **Roads:** OpenStreetMap

### Platform
- Google Earth Engine (data acquisition)
- Google Colab (computation)
- Python: scikit-learn, scipy, rasterio, numpy
- GeoServer (Local WMS deployment)

### Workflow

1. **Preprocessing:** Cloud masking, annual composites, reprojection to UTM 43N
2. **Classification:** Random Forest with 100 trees on 10 Landsat bands
3. **Driver Extraction:** Standardization, multicollinearity testing (VIF)
4. **MLR Training:** 4 classes, 5 predictors, 4,126 samples
5. **GA Optimization:** 20 individuals, 30 generations
6. **CA Simulation:** Quota-based allocation, top-K selection
7. **Validation:** Sample-based accuracy assessment

## Key Work

**Quota-Based Allocation**
- Replaces threshold-based conversion (Ptrans > 0.5)
- Constrains growth to historical demand (2.67% annual)
- Selects top-K highest probability cells per iteration
- Prevents 25.4% over-prediction observed in threshold models
- Maintains spatial realism through probability-weighted selection

## Results Visualization

See `TeamX_Result_Code_Demo.mp4` for spatial predictions and change detection maps.

**WMS Endpoint:** Predictions deployed on local GeoServer (EPSG:32643, 30m resolution)

## Code Resources

**Colab Notebook:** [Complete Implementation Pipeline](https://colab.research.google.com/drive/1Tw-NrrvHlCrBogY2ReBTiQJYylnOt4Vb?usp=sharing)
- LULC classification workflow
- Driver extraction and standardization
- MLR model training and probability generation
- GA parameter optimization
- CA simulation and spatial prediction
- Validation and accuracy assessment


## Reference

Based on methodology from:  
**Vani, M. & Rama Chandra Prasad, P. (2022).** "Modelling urban expansion of a south-east Asian city, India: comparison between SLEUTH and a hybrid CA model." Modeling Earth Systems and Environment (2022).

## Team

- Vishakha Agrawal
- Aakrit Kumar 
- Aniket Bansal 

---

**Study Area:** 25km radius around Hyderabad city center  
**Projection:** UTM Zone 43N (EPSG:32643)  
**Resolution:** 30m (2,859,481 cells)  
**Timeline:** 1990-2050 (7 historical years, 6 prediction scenarios)
