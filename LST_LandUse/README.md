# Intro to Spatial Sciences - Course Project

## Team Members
* Vishakha Agrawal
* Kashik P
* Keerthana Korlapati
* Shambhavi

## Problem Statement

To study the changes in Land Surface Temperature (LST) due to increased urbanization of a city every five years between 2014 and 2024.

**City of Study:** Jaipur

## Methodology

1.  **Identify City Center and Region of Interest:**
    * The city center of Jaipur was identified and marked as a Point.
    * The region of interest for the study is the area within 30km from the city center.

2.  **Data Acquisition and Land Cover Classification:**
    * Cloud-free satellite data was selected for the study dates.
    * Land cover was classified into Urban or Builtup, Vegetation, Waterbodies, and others.
    * Statistics were reported for each year within the 45-degree sector from the city center.

3.  **Index-Based Land Cover Classification and Comparison:**
    * Land cover was classified again for the same classes using an index-based approach (NDBI, NDVI, and MNDWI indices).
    * The results were compared against the one obtained in Step-2 sector-wise.

4.  **LST Derivation:**
    * LST was derived for the same dates using the Mono-window algorithm.

5.  **Sector Analysis:**
    * A sector analysis for LST vs Land cover for the 3 time steps was presented.

6.  **LST Variation Analysis near Water Bodies:**
    * A water body was picked and the variation in LST for every 2km within a 10 km distance from water bodies was analyzed.

## Code Resources

**Google Earth Engine Script:** [LULC Classification & LST Calculation](https://code.earthengine.google.com/69458f14648bf7bf1c84d1d5aad60063?noload=true)
- Landsat imagery preprocessing
- LULC classification (Urban, Vegetation, Waterbodies, Others)
- Feature collection export for multiple years
- LST calculation using Mono-window algorithm

**Colab Notebook:** [Project Analysis & Visualization](https://colab.research.google.com/drive/1PNAbq__Pu8oDyzgRlZDwVDhGDp0eWIat?usp=sharing)
- Complete analysis pipeline
- Sector-wise statistics
- LST vs land cover analysis