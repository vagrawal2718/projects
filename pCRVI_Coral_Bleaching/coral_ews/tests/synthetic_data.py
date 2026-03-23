"""
Synthetic Data Generator — TEST ONLY
======================================

Generates realistic-looking synthetic SST/DHW/ocean-color/atmospheric/climate
data for unit testing.  NOT imported by the main package.

Place at:  coral_ews/tests/__init__.py  (empty)
           coral_ews/tests/synthetic_data.py  (this file)
"""
from __future__ import annotations

import numpy as np
import pandas as pd
from typing import Dict


def generate_synthetic_data(
    region_name: str = "Test Region",
    mmm_sst: float = 29.0,
    peak_month: int = 5,
    n_years: int = 27,
    seed: int = 42,
) -> Dict[str, pd.DataFrame]:
    """
    Generate synthetic data mimicking real satellite-derived time series.

    Returns dict with keys: sst, dhw, ocean_color, atmospheric, climate
    """
    rng = np.random.default_rng(seed)
    dates = pd.date_range('1998-01-01', periods=365 * n_years, freq='D')
    n = len(dates)

    # SST: seasonal cycle + trend + noise
    day_of_year = dates.dayofyear.values
    seasonal = 1.5 * np.sin(2 * np.pi * (day_of_year - 60) / 365)
    trend = np.linspace(0, 0.8, n)
    noise = rng.normal(0, 0.3, n)
    sst = mmm_sst - 1.0 + seasonal + trend + noise
    sst_df = pd.DataFrame({'sst': sst}, index=dates)

    # DHW from SST
    hotspot = np.maximum(sst - mmm_sst, 0)
    hs_thresh = np.where(hotspot >= 1.0, hotspot, 0)
    dhw = pd.Series(hs_thresh, index=dates).rolling(84, min_periods=84).sum() / 7
    dhw_df = pd.DataFrame({
        'sst': sst, 'hotspot': hotspot, 'dhw': dhw.values,
        'alert_level': np.where(
            np.isnan(dhw), np.nan,
            np.where(dhw >= 8, 4, np.where(dhw >= 4, 2, np.where(dhw > 0, 1, 0)))
        ),
    }, index=dates)

    # Ocean color
    oc_df = pd.DataFrame({
        'kd490': 0.08 + rng.normal(0, 0.01, n),
        'chlor_a': 0.3 + rng.normal(0, 0.05, n),
    }, index=dates)

    # Atmospheric
    atm_df = pd.DataFrame({
        'cloud_cover': np.clip(0.5 + 0.2 * np.sin(
            2 * np.pi * day_of_year / 365) + rng.normal(0, 0.1, n), 0, 1),
        'wind_speed': np.clip(4.0 + rng.normal(0, 1.5, n), 0, 20),
    }, index=dates)

    # Climate indices (monthly)
    monthly = pd.date_range('1998-01-01', periods=12 * n_years, freq='MS')
    oni = 0.3 * np.sin(2 * np.pi * np.arange(len(monthly)) / 48) + \
          rng.normal(0, 0.4, len(monthly))
    dmi = 0.2 * np.sin(2 * np.pi * np.arange(len(monthly)) / 36) + \
          rng.normal(0, 0.3, len(monthly))
    clim_df = pd.DataFrame({'oni': oni, 'dmi': dmi}, index=monthly)

    return dict(
        sst=sst_df, dhw=dhw_df,
        ocean_color=oc_df, atmospheric=atm_df,
        climate=clim_df,
    )
