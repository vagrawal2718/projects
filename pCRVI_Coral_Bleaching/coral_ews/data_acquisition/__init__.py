"""
Data Acquisition Module
=======================

Provides clients for acquiring data from various sources:
- Google Earth Engine (GEE)
- Copernicus Marine Data Store
- NOAA Coral Reef Watch
- Climate Indices
"""

from .gee_client import GEEClient
from .copernicus_client import CopernicusClient
from .noaa_client import NOAAClient, ClimateIndicesClient

__all__ = [
    'GEEClient',
    'CopernicusClient', 
    'NOAAClient',
    'ClimateIndicesClient'
]
