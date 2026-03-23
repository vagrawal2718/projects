"""
Enhanced Predictive Coral Reef Vulnerability Index (Enhanced-pCRVI)
===================================================================

This module replaces BOTH the old CRVICalculator and original PredictiveCRVI
with a single, unified, literature-grounded index that integrates ALL available
remote sensing and climate features.

Enhanced-pCRVI Formula:
    pCRVI = w1*TA + w2*AS + w3*SR + w4*CDR + w5*BH + w6*WQ + w7*LA

7 Components:
    1. TA  - Thermal Anomaly: SST deviation from NOAA OISST climatology + HotSpot
    2. AS  - Accumulating Stress: DHW trend, momentum, current magnitude
    3. SR  - Seasonal Risk: Cosine function peaking at region-specific peak day
    4. CDR - Climate Driver Risk: ONI + DMI with configurable lag
    5. BH  - Bleaching History: Population vulnerability (inverted—adapted survivors)
    6. WQ  - Water Quality Stress: Chl-a anomaly (eutrophication) + Kd490 anomaly
    7. LA  - Light Availability: PAR proxy (from ERA5 cloud cover) + Kd490-derived
             underwater attenuation

Literature Basis for Default Weights:
    TA  = 0.25  Hughes et al. (2018) Nature 556:492-496
    AS  = 0.18  Liu et al. (2014) Remote Sensing 6:11579-11606
    SR  = 0.10  NOAA CRW operational methodology
    CDR = 0.12  van Hooidonk & Huber (2009) GRL 36:L05601
    BH  = 0.08  Thompson & Dolman (2010) Ecol Appl 20:1619-1627
    WQ  = 0.15  Wooldridge (2009) Mar Poll Bull; Sully et al. (2019) Nat Comms
    LA  = 0.12  Lesser (2011) Coral Reefs 30:163; Kirk (2011) Cambridge

Generalization:
    This module is parameterized via the Config object to support ANY tropical
    reef region.  Region-specific constants (MMM, peak season, bounds) are drawn
    from config rather than hardcoded.  To apply to Lakshadweep, Bay of Bengal,
    or any other reef:
        config = Config()
        config.region = LakshadweepRegion()   # custom region class
        epcrvi = EnhancedPCRVI(config=config, mmm=config.region.mmm_sst)

ML Weight Optimization:
    Gradient-boosted regression (XGBoost) with 5-fold TimeSeriesSplit to derive
    data-driven weights.  Ridge regression fallback if xgboost unavailable.

Weekly Bleaching Stress Risk Layers:
    Weekly aggregated risk summaries suitable for reef management bulletins,
    following NOAA CRW's weekly 5-km product dissemination model.

References:
    - Hughes et al. (2018) Nature 556:492-496
    - Liu et al. (2014) Remote Sensing 6:11579-11606
    - Sully et al. (2019) Nat Comms 10:1264
    - Wooldridge (2009) Mar Poll Bull 58:745-751
    - Lesser (2011) Coral Reefs 30:163-173
    - Hoegh-Guldberg (1999) Mar Fresh Res 50:839-866
    - van Hooidonk & Huber (2009) GRL 36:L05601
    - Thompson & Dolman (2010) Ecol Appl 20:1619-1627
    - Kirk (2011) "Light and Photosynthesis in Aquatic Ecosystems" 3rd ed Cambridge
    - Frouin et al. (2003) JGR 108:C68150
    - Morel & Maritorena (2001) JGR 106:7163-7180
"""

from typing import Optional, Dict, List, Any, Tuple, Union
from datetime import datetime, date
from pathlib import Path
import warnings

import numpy as np
import pandas as pd

from .logger import get_logger
from .naming import COMPONENT_LABELS
from .config import Config

# Numpy >=1.25 moved RankWarning to np.exceptions; older versions had np.RankWarning
try:
    _RankWarning = np.exceptions.RankWarning  # type: ignore[attr-defined]
except AttributeError:
    try:
        _RankWarning = np.RankWarning  # type: ignore[attr-defined]
    except AttributeError:
        _RankWarning = UserWarning  # safe fallback


# =============================================================================
# CONSTANTS
# =============================================================================

# Default expert-prior weights (sum = 1.0)
DEFAULT_WEIGHTS = {
    'thermal_anomaly': 0.25,       # Hughes et al. 2018
    'accumulating_stress': 0.18,   # Liu et al. 2014
    'seasonal_risk': 0.10,         # NOAA CRW methodology
    'climate_driver': 0.12,        # van Hooidonk & Huber 2009
    'bleaching_history': 0.08,     # Thompson & Dolman 2010
    'water_quality': 0.15,         # Wooldridge 2009; Sully et al. 2019
    'light_availability': 0.12,    # Lesser 2011; Hoegh-Guldberg 1999
}

# Risk category thresholds (pCRVI → categorical risk)
RISK_THRESHOLDS = {
    'Critical': 0.70,
    'High': 0.55,
    'Moderate': 0.35,
    'Low': 0.20,
    'Minimal': 0.0,
}

# Literature references for each component
COMPONENT_REFERENCES = {
    'thermal_anomaly': 'Hughes et al. (2018) Nature 556:492-496',
    'accumulating_stress': 'Liu et al. (2014) Remote Sensing 6:11579-11606',
    'seasonal_risk': 'NOAA CRW operational methodology',
    'climate_driver': 'van Hooidonk & Huber (2009) GRL 36:L05601',
    'bleaching_history': 'Thompson & Dolman (2010) Ecol Appl 20:1619-1627',
    'water_quality': 'Wooldridge (2009) Mar Poll Bull; Sully et al. (2019) Nat Comms',
    'light_availability': 'Lesser (2011) Coral Reefs 30:163; Kirk (2011) Cambridge',
}


class EnhancedPCRVI:
    """
    Enhanced Predictive Coral Reef Vulnerability Index.

    This is the SOLE vulnerability index in the system.  It supersedes both
    the original CRVI (retrospective) and the 5-component pCRVI.

    Parameters
    ----------
    config : Config, optional
        System configuration.  Region-specific peak season, MMM, and bounds
        are drawn from ``config.region``.
    mmm : float
        Maximum Monthly Mean SST for the region (°C).
        Default 29.87 for ANI (NOAA CRW Virtual Station, Andaman).
    weights : dict, optional
        Component weights.  Must sum to 1.0.  Keys must match DEFAULT_WEIGHTS.
    peak_season_months : tuple, optional
        Months of peak bleaching season (1-12).  Default from config or (3,4,5,6).
    peak_day_of_year : int, optional
        Day of year for peak seasonal risk.  Default from config or 105 (~Apr 15).
    """

    def __init__(
        self,
        config: Optional[Config] = None,
        mmm: float = 29.87,
        weights: Optional[Dict[str, float]] = None,
        peak_season_months: Optional[Tuple[int, ...]] = None,
        peak_day_of_year: Optional[int] = None,
    ):
        self.config = config or Config()
        self.logger = get_logger("coral_ews.enhanced_pcrvi")
        self.mmm = mmm

        # Region-aware peak season configuration (generalizable)
        region = self.config.region
        self.peak_season_months = peak_season_months or getattr(
            region, 'peak_season_months', (3, 4, 5, 6))
        self.peak_day_of_year = peak_day_of_year or self._infer_peak_day()
        self.region_name = getattr(region, 'name', 'Study Region')

        # Set and validate weights
        self.climate_driver_weights = getattr(
            region, 'climate_driver_weights', {'oni': 0.55, 'dmi': 0.45}
        )
        cdr_drivers = ', '.join(
            f"{k}={v:.0%}" for k, v in self.climate_driver_weights.items())
        self.logger.info(f"CDR driver blend: {cdr_drivers}")

        # Set and validate weights
        self.weights = weights or DEFAULT_WEIGHTS.copy()
        w_sum = sum(self.weights.values())
        if abs(w_sum - 1.0) > 0.01:
            self.logger.warning(f"Weights sum to {w_sum:.3f}; normalizing to 1.0")
            for k in self.weights:
                self.weights[k] /= w_sum

        self.logger.info(
            f"Enhanced-pCRVI initialized for {self.region_name} "
            f"(MMM={self.mmm}°C, peak DoY={self.peak_day_of_year}):\n"
            + "\n".join(f"  {k}: {v:.3f}" for k, v in self.weights.items())
        )

    def _infer_peak_day(self) -> int:
        """Infer peak day of year from peak season months."""
        if self.peak_season_months:
            mid = self.peak_season_months[len(self.peak_season_months) // 2]
            return int(mid * 30.5 - 15)  # approximate mid-month
        return 105  # April 15 default

    # =========================================================================
    # MAIN CALCULATION
    # =========================================================================

    def calculate_timeseries(
        self,
        sst_data: pd.DataFrame,
        dhw_data: pd.DataFrame,
        ocean_color_data: Optional[pd.DataFrame] = None,
        atmospheric_data: Optional[pd.DataFrame] = None,
        climate_data: Optional[pd.DataFrame] = None,
        smoothing_days: int = 7,
    ) -> pd.DataFrame:
        """
        Calculate daily Enhanced-pCRVI time series.

        Parameters
        ----------
        sst_data : DataFrame
            Must contain 'sst' column (°C) with DatetimeIndex.
        dhw_data : DataFrame
            Must contain 'dhw' column (°C-weeks) with DatetimeIndex.
        ocean_color_data : DataFrame, optional
            Columns: 'KD490' (m⁻¹), 'CHL' (mg/m³).
        atmospheric_data : DataFrame, optional
            Columns: 'cloud_cover' (0-1 fraction), 'wind_speed' (m/s).
        climate_data : DataFrame, optional
            Columns: 'oni', 'dmi'.
        smoothing_days : int
            EWM smoothing span (default 7 days).

        Returns
        -------
        DataFrame
            Daily time series with columns: pcrvi, ta_norm, as_norm, sr_norm,
            cdr_norm, bh_norm, wq_norm, la_norm, risk_category, plus diagnostics.
        """
        self.logger.info("Calculating Enhanced-pCRVI time series (7 components)...")

        # --- validate inputs ---
        if sst_data is None or sst_data.empty:
            self.logger.error("SST data is empty or None")
            return pd.DataFrame()
        if dhw_data is None or dhw_data.empty:
            self.logger.error("DHW data is empty or None")
            return pd.DataFrame()

        # Ensure DatetimeIndex
        for name, df in [('sst_data', sst_data), ('dhw_data', dhw_data)]:
            if not isinstance(df.index, pd.DatetimeIndex):
                self.logger.warning(f"{name} index is not DatetimeIndex; attempting conversion")
                try:
                    df.index = pd.to_datetime(df.index)
                except Exception as e:
                    self.logger.error(f"Cannot convert {name} index to datetime: {e}")
                    return pd.DataFrame()

        # --- common date range ---
        common_idx = sst_data.index.intersection(dhw_data.index)
        if len(common_idx) == 0:
            self.logger.error("No overlapping dates between SST and DHW")
            return pd.DataFrame()

        self.logger.info(f"Processing {len(common_idx)} days "
                         f"({common_idx[0].date()} to {common_idx[-1].date()})")

        # --- pre-compute ancillary lookups ---
        sst_climatology = self._monthly_climatology(sst_data, 'sst')
        sst_clim_mean, sst_clim_sd = self._monthly_climatology_with_sd(sst_data, 'sst')
        bleaching_dates = self._find_bleaching_events(dhw_data)

        # Ocean-color climatology (if available)
        oc_clim_kd = None
        oc_clim_chl = None
        oc_clim_kd_mean, oc_clim_kd_sd = None, None
        oc_clim_chl_mean, oc_clim_chl_sd = None, None
        if ocean_color_data is not None and not ocean_color_data.empty:
            kd_col = self._find_column(ocean_color_data, ['KD490', 'kd490', 'Kd490'])
            chl_col = self._find_column(ocean_color_data, ['CHL', 'chlor_a', 'chl', 'Chlorophyll'])
            if kd_col:
                oc_clim_kd = self._monthly_climatology(ocean_color_data, kd_col)
                oc_clim_kd_mean, oc_clim_kd_sd = self._monthly_climatology_with_sd(
                    ocean_color_data, kd_col)
            if chl_col:
                oc_clim_chl = self._monthly_climatology(ocean_color_data, chl_col)
                oc_clim_chl_mean, oc_clim_chl_sd = self._monthly_climatology_with_sd(
                    ocean_color_data, chl_col)

        rows: List[Dict[str, Any]] = []
        # Forward-fill monthly climate indices to daily resolution
        if climate_data is not None and not climate_data.empty:
            climate_data = climate_data.copy()
            for col in ['oni', 'dmi']:
                actual_col = self._find_column(climate_data, [col, col.upper()])
                if actual_col:
                    climate_data[actual_col] = climate_data[actual_col].ffill()

        for dt in common_idx:
            # 1. Thermal Anomaly (TA)
            ta, ta_d = self._calc_ta(sst_data, dt, sst_climatology)
            # 2. Accumulating Stress (AS)
            as_, as_d = self._calc_as(dhw_data, dt)
            # 3. Seasonal Risk (SR)
            sr = self._calc_sr(dt)
            # 4. Climate Driver Risk (CDR)
            cdr, cdr_d = self._calc_cdr(climate_data, dt)
            # 5. Bleaching History (BH)
            bh, bh_d = self._calc_bh(dt, bleaching_dates)
            # 6. Water Quality (WQ)
            wq, wq_d = self._calc_wq(ocean_color_data, dt, oc_clim_kd, oc_clim_chl)
            # 7. Light Availability (LA)
            la, la_d = self._calc_la(atmospheric_data, ocean_color_data, dt, oc_clim_kd)
            # 8. Extreme Variability (EV) — variance-based risk amplifier
            ev, ev_d = self._calc_extreme_variability(
                sst_data, dhw_data, ocean_color_data, atmospheric_data, dt,
                sst_clim_mean, sst_clim_sd,
                oc_clim_chl_mean, oc_clim_chl_sd,
                oc_clim_kd_mean, oc_clim_kd_sd,
            )

            # ── Base pCRVI (7-component weighted mean) ──────────────
            pcrvi_base = (
                self.weights['thermal_anomaly'] * ta
                + self.weights['accumulating_stress'] * as_
                + self.weights['seasonal_risk'] * sr
                + self.weights['climate_driver'] * cdr
                + self.weights['bleaching_history'] * bh
                + self.weights['water_quality'] * wq
                + self.weights['light_availability'] * la
            )

            # ── Extreme-variability amplification ───────────────────
            # EV acts as a multiplicative boost: when extremes co-occur,
            # the risk is *worse* than the linear combination suggests.
            # At ev=0 (no extremes): no change.
            # At ev=0.5: +15% amplification.
            # At ev=1.0 (multiple co-occurring extremes): +30%.
            # This captures synergistic / compound event risk.
            amplification = 1.0 + 0.30 * ev
            pcrvi = float(np.clip(pcrvi_base * amplification, 0.0, 1.0))

            risk = self._risk_category(pcrvi)
            current_dhw = float(dhw_data.loc[dt, 'dhw']) if dt in dhw_data.index else np.nan
            if isinstance(dhw_data.loc[dt, 'dhw'] if dt in dhw_data.index else np.nan, pd.Series):
                current_dhw = float(dhw_data.loc[dt, 'dhw'].iloc[0])

            rows.append({
                'date': dt,
                'pcrvi': pcrvi,
                'pcrvi_base': pcrvi_base,
                'ta_norm': ta,
                'as_norm': as_,
                'sr_norm': sr,
                'cdr_norm': cdr,
                'bh_norm': bh,
                'wq_norm': wq,
                'la_norm': la,
                # ── Extreme variability features ────────────────────
                'ev_score': ev,
                'ev_amplification': amplification,
                'sst_sigma_departure': ev_d.get('sst_sigma_departure', np.nan),
                'sst_rolling_sd_30d': ev_d.get('sst_rolling_sd_30d', np.nan),
                'sst_variability_amp': ev_d.get('sst_variability_amplification', np.nan),
                'sst_exceed_2sd': ev_d.get('sst_exceed_2sd', 0),
                'sst_exceed_3sd': ev_d.get('sst_exceed_3sd', 0),
                'dhw_rolling_sd_rate': ev_d.get('dhw_rolling_sd_rate', np.nan),
                'chl_sigma_departure': ev_d.get('chl_sigma_departure', np.nan),
                'kd490_sigma_departure': ev_d.get('kd490_sigma_departure', np.nan),
                'cloud_sigma_departure': ev_d.get('cloud_sigma_departure', np.nan),
                'n_concurrent_extremes': ev_d.get('n_concurrent_extremes', 0),
                # ── Standard diagnostics ────────────────────────────
                'risk_category': risk,
                'dhw_current': current_dhw,
                'sst_anomaly': ta_d.get('sst_anomaly', np.nan),
                'hotspot': ta_d.get('hotspot', np.nan),
                'current_sst': ta_d.get('current_sst', np.nan),
                'dhw_trend': as_d.get('dhw_trend', np.nan),
                'dhw_momentum': as_d.get('dhw_momentum', np.nan),
                'oni': cdr_d.get('oni', np.nan),
                'dmi': cdr_d.get('dmi', np.nan),
                'years_since_bleaching': bh_d.get('years_since', np.nan),
                'adaptation_status': bh_d.get('status', 'unknown'),
                'chl_anomaly': wq_d.get('chl_anomaly', np.nan),
                'kd490_anomaly': wq_d.get('kd490_anomaly', np.nan),
                'par_proxy': la_d.get('par_proxy', np.nan),
                'clarity_score': la_d.get('clarity_score', np.nan),
                'is_peak_season': dt.month in self.peak_season_months,
            })

        if not rows:
            self.logger.warning("No rows generated — check data alignment")
            return pd.DataFrame()

        df = pd.DataFrame(rows).set_index('date').sort_index()

        # Exponential smoothing for stability
        if smoothing_days > 1 and len(df) > smoothing_days:
            df['pcrvi_raw'] = df['pcrvi'].copy()
            df['pcrvi'] = df['pcrvi'].ewm(span=smoothing_days, adjust=False).mean()

        self.logger.info(
            f"Enhanced-pCRVI complete: {len(df)} daily values, "
            f"mean={df['pcrvi'].mean():.3f}, max={df['pcrvi'].max():.3f}"
        )
        return df

    # =========================================================================
    # COMPONENT CALCULATORS
    # =========================================================================

    def _calc_ta(
        self, sst: pd.DataFrame, dt: pd.Timestamp, clim: Dict[int, float]
    ) -> Tuple[float, Dict]:
        """
        Thermal Anomaly (TA).

        Combines SST departure from monthly climatology with NOAA HotSpot
        (SST − MMM).  Dual score ensures both seasonal anomalies and
        absolute threshold exceedance are captured.

        Ref: Hughes et al. (2018) Nature 556:492-496
        """
        try:
            current_sst = sst.loc[dt, 'sst']
            if isinstance(current_sst, pd.Series):
                current_sst = current_sst.iloc[0]
            current_sst = float(current_sst)
            if np.isnan(current_sst):
                return 0.0, {}

            expected = clim.get(dt.month, self.mmm)
            anomaly = current_sst - float(expected)
            hotspot = max(0.0, current_sst - self.mmm)

            # Normalize anomaly: −1°C → 0, +2°C → 1 (linear)
            anom_score = float(np.clip((anomaly + 1.0) / 3.0, 0.0, 1.0))
            # Normalize HotSpot: 0°C → 0, ≥2°C → 1
            hs_score = float(np.clip(hotspot / 2.0, 0.0, 1.0))

            # 60-40 blend: anomaly gives earlier signal, HotSpot confirms
            ta = 0.6 * anom_score + 0.4 * hs_score
            return ta, {'sst_anomaly': anomaly, 'hotspot': hotspot,
                        'current_sst': current_sst}
        except (KeyError, TypeError, IndexError, ValueError):
            return 0.0, {}

    def _calc_as(
        self, dhw: pd.DataFrame, dt: pd.Timestamp, lookback: int = 30
    ) -> Tuple[float, Dict]:
        """
        Accumulating Stress (AS).

        Combines current DHW magnitude, 30-day linear trend, and momentum
        (second half vs first half of lookback window).

        Ref: Liu et al. (2014) Remote Sensing 6:11579-11606
        """
        try:
            start = dt - pd.Timedelta(days=lookback)
            recent = dhw.loc[start:dt, 'dhw'].dropna()
            if len(recent) < 7:
                return 0.0, {'current_dhw': 0.0, 'dhw_trend': 0.0, 'dhw_momentum': 0.0}

            cur_dhw = float(recent.iloc[-1])
            # DHW score: 0→0, 8→1
            dhw_score = float(np.clip(cur_dhw / 8.0, 0.0, 1.0))

            slope = 0.0
            trend_score = 0.5
            momentum = 0.0
            momentum_score = 0.5
            if len(recent) >= 14:
                x = np.arange(len(recent), dtype=float)
                with warnings.catch_warnings():
                    warnings.simplefilter("ignore", _RankWarning)
                    slope = float(np.polyfit(x, recent.values, 1)[0])
                # Slope normalization: −0.02 → 0, +0.10 → 1
                trend_score = float(np.clip((slope + 0.02) / 0.12, 0.0, 1.0))

                mid = len(recent) // 2
                momentum = float(recent.iloc[mid:].mean() - recent.iloc[:mid].mean())
                momentum_score = float(np.clip((momentum + 0.5) / 2.0, 0.0, 1.0))

            as_norm = 0.5 * dhw_score + 0.3 * trend_score + 0.2 * momentum_score
            return as_norm, {'current_dhw': cur_dhw, 'dhw_trend': slope,
                             'dhw_momentum': momentum}
        except (KeyError, TypeError, ValueError):
            return 0.0, {'current_dhw': 0.0, 'dhw_trend': 0.0, 'dhw_momentum': 0.0}

    def _calc_sr(self, dt: pd.Timestamp) -> float:
        """
        Seasonal Risk (SR).

        Cosine function centred on the region's peak bleaching day.
        Output is rescaled to [0.15, 0.85] to avoid zero/one boundaries.

        Generalizable: ``self.peak_day_of_year`` is drawn from config.

        Ref: NOAA CRW seasonal risk methodology
        """
        doy = dt.timetuple().tm_yday
        cos_val = 0.5 * (1.0 + np.cos(
            2.0 * np.pi * (doy - self.peak_day_of_year) / 365.0))
        return float(0.15 + 0.70 * cos_val)

    def _calc_cdr(
        self, climate: Optional[pd.DataFrame], dt: pd.Timestamp
    ) -> Tuple[float, Dict]:
        """
        Climate Driver Risk (CDR).

        Blends climate oscillation indices using region-specific weights
        from ``self.climate_driver_weights``.  Supported indices:

        * **oni** – Oceanic Niño Index (El Niño risk everywhere)
        * **dmi** – Dipole Mode Index (Indian Ocean Dipole; Indian Ocean /
          Coral Triangle regions)
        * **amo** – Atlantic Multidecadal Oscillation (Caribbean / Florida)

        Weights are set per-region in ``reef_regions.py`` based on
        peer-reviewed literature (see docstrings there).
        """
        oni, dmi, amo = 0.0, 0.0, 0.0
        if climate is not None and not climate.empty:
            try:
                month_start = dt.replace(day=1)
                for col_name, var_name in [('oni', 'oni'), ('dmi', 'dmi'),
                                           ('amo', 'amo')]:
                    # Only look up indices that have non-zero weight
                    if self.climate_driver_weights.get(var_name, 0.0) == 0.0:
                        continue
                    # Case-insensitive column lookup
                    actual_col = self._find_column(climate, [col_name, col_name.upper()])
                    if actual_col:
                        s = climate[actual_col].dropna()
                        if len(s) > 0:
                            idx = s.index.get_indexer([month_start], method='nearest')[0]
                            if 0 <= idx < len(s):
                                val = float(s.iloc[idx])
                                if not np.isnan(val):
                                    if var_name == 'oni':
                                        oni = val
                                    elif var_name == 'dmi':
                                        dmi = val
                                    else:
                                        amo = val
            except Exception:
                pass


        # ONI: −2→0, +2→1 (El Niño risk)
        oni_score = float(np.clip((oni + 1.0) / 3.0, 0.0, 1.0))
        # DMI: −1→0, +1→1 (positive IOD risk for Indian Ocean)
        dmi_score = float(np.clip((dmi + 0.5) / 1.5, 0.0, 1.0))

        # 55-45 blend: ONI has wider basin influence
        amo_score = float(np.clip((amo + 0.3) / 0.6, 0.0, 1.0))

        scores = {'oni': oni_score, 'dmi': dmi_score, 'amo': amo_score}

        # Weighted blend using region-specific driver weights
        w = self.climate_driver_weights
        cdr = sum(w.get(k, 0.0) * scores.get(k, 0.0) for k in w)
        # Normalise if weights don't quite sum to 1
        w_total = sum(w.values())
        if w_total > 0 and abs(w_total - 1.0) > 0.01:
            cdr /= w_total

        details = {
            'oni': oni, 'dmi': dmi, 'amo': amo,
            'oni_score': oni_score, 'dmi_score': dmi_score,
            'amo_score': amo_score,
            'driver_weights': dict(w),
        }
        return float(cdr), details

    def _calc_bh(
        self, dt: pd.Timestamp, bleaching_dates: List[pd.Timestamp]
    ) -> Tuple[float, Dict]:
        """
        Bleaching History / Population Vulnerability (BH).

        INVERTED: recently bleached reefs that survived are LESS vulnerable
        due to Symbiodiniaceae shuffling and selective mortality.

        Ref: Thompson & Dolman (2010) Ecol Appl 20:1619-1627
        """
        if not bleaching_dates:
            return 0.9, {'years_since': float('inf'), 'status': 'naive'}

        past = [e for e in bleaching_dates if e < dt]
        if not past:
            return 0.9, {'years_since': float('inf'), 'status': 'naive'}

        years_since = (dt - max(past)).days / 365.25

        # Piecewise-linear vulnerability curve
        if years_since < 2:
            bh = 0.2 + 0.1 * years_since        # 0.20-0.40
        elif years_since < 5:
            bh = 0.4 + 0.1 * (years_since - 2)  # 0.40-0.70
        elif years_since < 10:
            bh = 0.7 + 0.04 * (years_since - 5)  # 0.70-0.90
        else:
            bh = 0.9

        status = ('adapted' if years_since < 3
                  else 'transitional' if years_since < 7
                  else 'naive')
        return float(np.clip(bh, 0.0, 1.0)), {'years_since': years_since, 'status': status}

    def _calc_wq(
        self,
        oc: Optional[pd.DataFrame],
        dt: pd.Timestamp,
        kd_clim: Optional[Dict[int, float]],
        chl_clim: Optional[Dict[int, float]],
    ) -> Tuple[float, Dict]:
        """
        Water Quality Stress (WQ).

        (a) Chlorophyll-a anomaly — positive anomaly = eutrophication
        (b) Kd490 anomaly — U-shaped: moderate turbidity is protective,
            extreme turbidity = sedimentation stress

        Ref: Sully et al. (2019) Nat Comms 10:1264; Wooldridge (2009)
        """
        chl_anom = np.nan
        kd_anom = np.nan
        chl_score = 0.5  # neutral default
        kd_score = 0.5   # neutral default

        if oc is not None and not oc.empty:
            try:
                # --- Chlorophyll anomaly ---
                chl_col = self._find_column(oc, ['CHL', 'chlor_a', 'chl', 'Chlorophyll'])
                if chl_col and dt in oc.index and chl_clim:
                    chl_val = oc.loc[dt, chl_col]
                    if isinstance(chl_val, pd.Series):
                        chl_val = chl_val.iloc[0]
                    chl_val = float(chl_val)
                    expected_chl = chl_clim.get(dt.month, np.nan)
                    if not np.isnan(chl_val) and not np.isnan(expected_chl) and expected_chl > 0:
                        chl_anom = (chl_val - expected_chl) / expected_chl
                        # Positive anomaly → eutrophication → higher risk
                        chl_score = float(np.clip(0.5 + chl_anom, 0.0, 1.0))

                # --- Kd490 anomaly ---
                kd_col = self._find_column(oc, ['KD490', 'kd490', 'Kd490'])
                if kd_col and dt in oc.index and kd_clim:
                    kd_val = oc.loc[dt, kd_col]
                    if isinstance(kd_val, pd.Series):
                        kd_val = kd_val.iloc[0]
                    kd_val = float(kd_val)
                    expected_kd = kd_clim.get(dt.month, np.nan)
                    if not np.isnan(kd_val) and not np.isnan(expected_kd) and expected_kd > 0:
                        kd_anom = (kd_val - expected_kd) / expected_kd
                        # U-shaped response
                        if kd_anom < 0:
                            # Clearer water → more light stress
                            kd_score = float(np.clip(0.6 - kd_anom * 0.5, 0.0, 1.0))
                        elif kd_anom < 0.5:
                            # Moderately turbid → protective
                            kd_score = float(np.clip(0.4 - kd_anom * 0.3, 0.0, 1.0))
                        else:
                            # Extreme turbidity → sedimentation stress
                            kd_score = float(np.clip(0.3 + (kd_anom - 0.5) * 0.6, 0.0, 1.0))

            except (KeyError, TypeError, IndexError, ValueError):
                pass

        wq = 0.55 * chl_score + 0.45 * kd_score
        return float(wq), {'chl_anomaly': chl_anom, 'kd490_anomaly': kd_anom,
                           'chl_score': chl_score, 'kd_score': kd_score}

    def _calc_la(
        self,
        atm: Optional[pd.DataFrame],
        oc: Optional[pd.DataFrame],
        dt: pd.Timestamp,
        kd_clim: Optional[Dict[int, float]],
    ) -> Tuple[float, Dict]:
        """
        Light Availability (LA).

        (a) Surface PAR proxy from cloud cover:
            PAR ≈ PAR_max × (1 − 0.75 × cloud_fraction^3.4)
            Ref: Kirk (2011) eq 2.14
        (b) Underwater attenuation from Kd490:
            Z_eu ≈ 4.6 / Kd490.  Lower Kd490 → deeper light.
            Ref: Morel & Maritorena (2001) JGR 106:7163-7180

        High surface PAR + clear water = maximum light co-stress.

        Ref: Lesser (2011) Coral Reefs 30:163-173
        """
        par_proxy = np.nan
        par_score = 0.5  # neutral default
        clarity_score = 0.5  # neutral default

        if atm is not None and not atm.empty:
            try:
                cc_col = self._find_column(atm, ['cloud_cover', 'total_cloud_cover', 'tcc'])
                if cc_col and dt in atm.index:
                    cc = atm.loc[dt, cc_col]
                    if isinstance(cc, pd.Series):
                        cc = cc.iloc[0]
                    cc = float(cc)
                    if not np.isnan(cc):
                        cc = float(np.clip(cc, 0.0, 1.0))
                        par_proxy = 1.0 - 0.75 * (cc ** 3.4)
                        par_score = float(np.clip(par_proxy, 0.0, 1.0))
            except (KeyError, TypeError, IndexError, ValueError):
                pass

        if oc is not None and not oc.empty:
            try:
                kd_col = self._find_column(oc, ['KD490', 'kd490', 'Kd490'])
                if kd_col and dt in oc.index:
                    kd_val = oc.loc[dt, kd_col]
                    if isinstance(kd_val, pd.Series):
                        kd_val = kd_val.iloc[0]
                    kd_val = float(kd_val)
                    if not np.isnan(kd_val) and kd_val > 0:
                        # Lower Kd490 → deeper euphotic zone → more light stress
                        # Typical range: 0.03-0.20 m⁻¹
                        clarity_score = float(np.clip(1.0 - (kd_val - 0.03) / 0.17, 0.0, 1.0))
            except (KeyError, TypeError, IndexError, ValueError):
                pass

        la = 0.50 * par_score + 0.50 * clarity_score
        return float(la), {'par_proxy': par_proxy, 'par_score': par_score,
                           'clarity_score': clarity_score}

    # =========================================================================
    # EXTREME VARIABILITY & VARIANCE-BASED FEATURES
    # =========================================================================
    #
    # Rationale (from literature):
    #
    # Climate science overwhelmingly uses *means* (e.g. IPCC 1.5°C target)
    # but coral bleaching is triggered by *extremes*: the tails of the SST
    # distribution, not its centre.  Anthropogenic forcing has increased not
    # just mean SST but also its *variance* (Frölicher et al. 2018 Nature
    # 560:360; Oliver et al. 2019 Ann. Rev. Mar. Sci. 11:313-339).
    #
    # Standard pCRVI components use anomaly from monthly mean.  This misses:
    #   1. SST > mean + 2σ events (marine heatwave spikes that trigger mass
    #      bleaching even when mean anomaly is <1°C)
    #   2. Increased variability (rolling σ exceeding historical σ), which
    #      indicates an unstable thermal environment → compound stress
    #   3. Rapid DHW acceleration (d²DHW/dt² spikes), which is more
    #      predictive than DHW level alone (Donner 2011 PLoS ONE 6:e14307)
    #   4. Co-occurring extremes (SST extreme + turbidity extreme + low-wind
    #      calm → synergistic bleaching risk)
    #
    # The features below capture these using σ-departure scores at 1σ, 2σ,
    # 3σ thresholds.  For each variable the relevant threshold is:
    #
    #   SST:      mean + 2σ  → marine heatwave (Hobday et al. 2016)
    #                          mean + 3σ  → extreme MHW
    #   DHW rate: mean + 2σ  → acceleration spike (Donner 2011)
    #   Chlor-a:  mean + 2σ  → algal bloom / nutrient overload
    #   Kd490:    mean + 2σ  → extreme turbidity (reduced PAR)
    #   Cloud:    mean - 2σ  → extreme clearness → high irradiance stress
    #
    # These are aggregated into a composite Extreme Variability (EV) score
    # that acts as an *amplifier* on the base pCRVI: when extremes co-occur,
    # risk is higher than the weighted mean of components suggests.
    # =========================================================================

    def _calc_extreme_variability(
        self,
        sst_data: pd.DataFrame,
        dhw_data: pd.DataFrame,
        ocean_color_data: Optional[pd.DataFrame],
        atmospheric_data: Optional[pd.DataFrame],
        dt: pd.Timestamp,
        sst_clim_mean: Dict[int, float],
        sst_clim_sd: Dict[int, float],
        oc_clim_chl_mean: Optional[Dict[int, float]] = None,
        oc_clim_chl_sd: Optional[Dict[int, float]] = None,
        oc_clim_kd_mean: Optional[Dict[int, float]] = None,
        oc_clim_kd_sd: Optional[Dict[int, float]] = None,
        rolling_window: int = 30,
    ) -> Tuple[float, Dict[str, Any]]:
        """
        Compute Extreme Variability (EV) score and diagnostics.

        This captures the *variance / tail-risk* dimension that means miss.

        Parameters
        ----------
        rolling_window : int
            Days for rolling variance (default 30 — one tidal cycle).

        Returns
        -------
        (ev_score, diagnostics_dict)
            ev_score ∈ [0, 1]:  0 = no extremes; 1 = multiple co-occurring
        """
        diag: Dict[str, Any] = {}
        sub_scores: List[float] = []

        month = dt.month

        # ── 1. SST σ-departure ──────────────────────────────────────────
        sst_sigma_dep = np.nan
        sst_rolling_sd = np.nan
        sst_variability_amp = np.nan
        try:
            if dt in sst_data.index:
                cur_sst = float(sst_data.loc[dt, 'sst'])
                if isinstance(sst_data.loc[dt, 'sst'], pd.Series):
                    cur_sst = float(sst_data.loc[dt, 'sst'].iloc[0])
                mu = sst_clim_mean.get(month)
                sd = sst_clim_sd.get(month)
                if mu is not None and sd is not None and sd > 0:
                    sst_sigma_dep = (cur_sst - mu) / sd
                    # Score: 0 at ≤0σ, 0.5 at 2σ, 1.0 at ≥3σ
                    sigma_score = float(np.clip(sst_sigma_dep / 3.0, 0.0, 1.0))
                    sub_scores.append(sigma_score)

                # Rolling 30-day SD of SST
                start = dt - pd.Timedelta(days=rolling_window)
                window = sst_data.loc[start:dt, 'sst'].dropna()
                if len(window) >= 14:
                    sst_rolling_sd = float(window.std())
                    # Variability amplification: recent σ / historical σ
                    if sd and sd > 0:
                        sst_variability_amp = sst_rolling_sd / sd
                        # Score: 0 at ratio ≤1, 0.5 at 1.5×, 1.0 at ≥2×
                        amp_score = float(np.clip((sst_variability_amp - 1.0), 0.0, 1.0))
                        sub_scores.append(amp_score)
        except (KeyError, TypeError, IndexError, ValueError):
            pass

        diag['sst_sigma_departure'] = sst_sigma_dep
        diag['sst_rolling_sd_30d'] = sst_rolling_sd
        diag['sst_variability_amplification'] = sst_variability_amp
        diag['sst_exceed_2sd'] = 1 if (isinstance(sst_sigma_dep, float)
                                        and not np.isnan(sst_sigma_dep)
                                        and sst_sigma_dep >= 2.0) else 0
        diag['sst_exceed_3sd'] = 1 if (isinstance(sst_sigma_dep, float)
                                        and not np.isnan(sst_sigma_dep)
                                        and sst_sigma_dep >= 3.0) else 0

        # ── 2. DHW acceleration (d(DHW)/dt volatility) ──────────────────
        dhw_accel_score = 0.0
        dhw_rolling_sd = np.nan
        try:
            start = dt - pd.Timedelta(days=rolling_window)
            dhw_win = dhw_data.loc[start:dt, 'dhw'].dropna()
            if len(dhw_win) >= 14:
                dhw_diff = dhw_win.diff().dropna()
                dhw_rolling_sd = float(dhw_diff.std())
                dhw_diff_mean = float(dhw_diff.mean())
                dhw_diff_sd = float(dhw_diff.std())
                if dhw_diff_sd > 0.001:
                    cur_rate = float(dhw_diff.iloc[-1])
                    dhw_accel_sigma = (cur_rate - dhw_diff_mean) / dhw_diff_sd
                    # Score: 0 at ≤0σ, 1.0 at ≥2σ
                    dhw_accel_score = float(np.clip(dhw_accel_sigma / 2.0, 0.0, 1.0))
                    sub_scores.append(dhw_accel_score)
                    diag['dhw_rate_sigma'] = dhw_accel_sigma
        except (KeyError, TypeError, ValueError):
            pass
        diag['dhw_rolling_sd_rate'] = dhw_rolling_sd

        # ── 3. Ocean-colour extremes ────────────────────────────────────
        chl_sigma_dep = np.nan
        kd_sigma_dep = np.nan
        if ocean_color_data is not None and not ocean_color_data.empty:
            try:
                chl_col = self._find_column(ocean_color_data,
                                            ['CHL', 'chlor_a', 'chl', 'Chlorophyll'])
                if chl_col and dt in ocean_color_data.index:
                    cur_chl = float(ocean_color_data.loc[dt, chl_col])
                    if isinstance(ocean_color_data.loc[dt, chl_col], pd.Series):
                        cur_chl = float(ocean_color_data.loc[dt, chl_col].iloc[0])
                    mu_c = (oc_clim_chl_mean or {}).get(month)
                    sd_c = (oc_clim_chl_sd or {}).get(month)
                    if mu_c and sd_c and sd_c > 0:
                        chl_sigma_dep = (cur_chl - mu_c) / sd_c
                        # Chlor > mean+2σ  → algal bloom stress
                        chl_score = float(np.clip(chl_sigma_dep / 3.0, 0.0, 1.0))
                        sub_scores.append(chl_score * 0.5)  # lower weight

                kd_col = self._find_column(ocean_color_data,
                                           ['KD490', 'kd490', 'Kd490'])
                if kd_col and dt in ocean_color_data.index:
                    cur_kd = float(ocean_color_data.loc[dt, kd_col])
                    if isinstance(ocean_color_data.loc[dt, kd_col], pd.Series):
                        cur_kd = float(ocean_color_data.loc[dt, kd_col].iloc[0])
                    mu_k = (oc_clim_kd_mean or {}).get(month)
                    sd_k = (oc_clim_kd_sd or {}).get(month)
                    if mu_k and sd_k and sd_k > 0:
                        kd_sigma_dep = (cur_kd - mu_k) / sd_k
                        kd_score = float(np.clip(kd_sigma_dep / 3.0, 0.0, 1.0))
                        sub_scores.append(kd_score * 0.5)
            except (KeyError, TypeError, IndexError, ValueError):
                pass
        diag['chl_sigma_departure'] = chl_sigma_dep
        diag['kd490_sigma_departure'] = kd_sigma_dep

        # ── 4. Atmospheric extreme (low cloud → high irradiance) ────────
        cloud_sigma_dep = np.nan
        if atmospheric_data is not None and not atmospheric_data.empty:
            try:
                if 'cloud_cover' in atmospheric_data.columns and dt in atmospheric_data.index:
                    cc = float(atmospheric_data.loc[dt, 'cloud_cover'])
                    if isinstance(atmospheric_data.loc[dt, 'cloud_cover'], pd.Series):
                        cc = float(atmospheric_data.loc[dt, 'cloud_cover'].iloc[0])
                    start = dt - pd.Timedelta(days=rolling_window * 12)
                    cloud_win = atmospheric_data.loc[start:dt, 'cloud_cover'].dropna()
                    if len(cloud_win) > 60:
                        c_month = cloud_win[cloud_win.index.month == month]
                        if len(c_month) > 10:
                            mu_cc = float(c_month.mean())
                            sd_cc = float(c_month.std())
                            if sd_cc > 0.01:
                                # Negative departure → abnormally clear skies → more PAR
                                cloud_sigma_dep = (cc - mu_cc) / sd_cc
                                if cloud_sigma_dep < -1.5:
                                    irrad_score = float(np.clip(
                                        (-cloud_sigma_dep - 1.0) / 2.0, 0.0, 1.0))
                                    sub_scores.append(irrad_score * 0.3)
            except (KeyError, TypeError, IndexError, ValueError):
                pass
        diag['cloud_sigma_departure'] = cloud_sigma_dep

        # ── Composite EV score ──────────────────────────────────────────
        if sub_scores:
            ev = float(np.clip(np.mean(sub_scores), 0.0, 1.0))
        else:
            ev = 0.0

        # Count how many extremes are co-occurring (≥2σ in any variable)
        n_extremes = sum([
            1 for v in [sst_sigma_dep, chl_sigma_dep, kd_sigma_dep]
            if isinstance(v, (int, float)) and not np.isnan(v) and abs(v) >= 2.0
        ])
        if isinstance(cloud_sigma_dep, (int, float)) and not np.isnan(cloud_sigma_dep):
            if cloud_sigma_dep <= -2.0:
                n_extremes += 1
        diag['n_concurrent_extremes'] = n_extremes

        # Amplify if multiple extremes co-occur (synergistic risk)
        if n_extremes >= 3:
            ev = float(np.clip(ev * 1.5, 0.0, 1.0))
        elif n_extremes >= 2:
            ev = float(np.clip(ev * 1.25, 0.0, 1.0))

        diag['ev_score'] = ev
        return ev, diag

    # =========================================================================
    # UTILITY METHODS
    # =========================================================================

    @staticmethod
    def _find_column(df: pd.DataFrame, candidates: List[str]) -> Optional[str]:
        """Find first matching column name (case-insensitive fallback)."""
        # Exact match first
        for c in candidates:
            if c in df.columns:
                return c
        # Case-insensitive fallback
        col_lower = {col.lower(): col for col in df.columns}
        for c in candidates:
            if c.lower() in col_lower:
                return col_lower[c.lower()]
        return None

    @staticmethod
    def _monthly_climatology(df: pd.DataFrame, col: str) -> Dict[int, float]:
        """Compute monthly mean climatology for a given column."""
        if col not in df.columns:
            return {}
        tmp = df[[col]].copy()
        tmp['_month'] = tmp.index.month
        result = tmp.groupby('_month')[col].mean().to_dict()
        return {k: v for k, v in result.items() if not np.isnan(v)}

    @staticmethod
    def _monthly_climatology_with_sd(
        df: pd.DataFrame, col: str
    ) -> Tuple[Dict[int, float], Dict[int, float]]:
        """Compute monthly mean AND standard deviation climatology.

        This is critical for detecting extreme events.  Literature
        (e.g., Frölicher et al. 2018; Oliver et al. 2019) shows that
        marine heatwave intensity is better characterised by how far
        SST exceeds the local monthly σ than by absolute anomaly.

        Returns
        -------
        (monthly_mean_dict, monthly_sd_dict)
            {month: mean}, {month: sd}  (months 1-12)
        """
        if col not in df.columns:
            return {}, {}
        tmp = df[[col]].copy()
        tmp['_month'] = tmp.index.month
        grp = tmp.groupby('_month')[col]
        means = grp.mean().to_dict()
        sds   = grp.std().to_dict()
        means = {k: v for k, v in means.items() if not np.isnan(v)}
        sds   = {k: v for k, v in sds.items()
                 if not np.isnan(v) and v > 0}
        return means, sds

    @staticmethod
    def _find_bleaching_events(
        dhw: pd.DataFrame, threshold: float = 4.0
    ) -> List[pd.Timestamp]:
        """Find bleaching event onset dates (DHW crossing threshold with hysteresis)."""
        events: List[pd.Timestamp] = []
        in_event = False
        for dt, row in dhw.iterrows():
            dhw_val = row['dhw']
            if isinstance(dhw_val, pd.Series):
                dhw_val = dhw_val.iloc[0]
            if np.isnan(dhw_val):
                continue
            if dhw_val >= threshold and not in_event:
                events.append(dt)
                in_event = True
            elif dhw_val < threshold * 0.5:
                in_event = False
        return events

    @staticmethod
    def _risk_category(pcrvi: float) -> str:
        """Map pCRVI score to categorical risk label."""
        if np.isnan(pcrvi):
            return 'Minimal'
        if pcrvi >= RISK_THRESHOLDS['Critical']:
            return 'Critical'
        elif pcrvi >= RISK_THRESHOLDS['High']:
            return 'High'
        elif pcrvi >= RISK_THRESHOLDS['Moderate']:
            return 'Moderate'
        elif pcrvi >= RISK_THRESHOLDS['Low']:
            return 'Low'
        return 'Minimal'

    # =========================================================================
    # WEEKLY BLEACHING STRESS RISK LAYERS
    # =========================================================================

    def generate_weekly_risk_layers(
        self, pcrvi_ts: pd.DataFrame
    ) -> pd.DataFrame:
        """
        Aggregate daily pCRVI into weekly bleaching stress risk layers.

        Output format follows NOAA CRW's weekly 5-km product model for
        reef manager bulletins.

        Returns
        -------
        DataFrame
            Columns: week_start, week_end, pcrvi_mean, pcrvi_max, pcrvi_min,
            pcrvi_trend, risk_category, dhw_mean, dhw_max, ta_mean, as_mean,
            sr_mean, cdr_mean, bh_mean, wq_mean, la_mean, recommendation,
            alert_color, iso_year, iso_week.
        """
        self.logger.info("Generating weekly bleaching stress risk layers...")

        if pcrvi_ts is None or pcrvi_ts.empty:
            self.logger.warning("Empty pCRVI timeseries; returning empty weekly layers")
            return pd.DataFrame()

        # Resample to weekly (Monday start)
        weekly_groups = pcrvi_ts.resample('W-MON', label='left', closed='left')

        rows = []
        for week_start, group in weekly_groups:
            if group.empty:
                continue

            week_end = week_start + pd.Timedelta(days=6)
            pcrvi_vals = group['pcrvi'].dropna()
            if pcrvi_vals.empty:
                continue

            mean_val = float(pcrvi_vals.mean())
            max_val = float(pcrvi_vals.max())
            min_val = float(pcrvi_vals.min())

            # Linear trend within the week
            if len(pcrvi_vals) >= 3:
                x = np.arange(len(pcrvi_vals), dtype=float)
                with warnings.catch_warnings():
                    warnings.simplefilter("ignore", _RankWarning)
                    trend = float(np.polyfit(x, pcrvi_vals.values, 1)[0])
            else:
                trend = 0.0

            risk = self._risk_category(max_val)

            # DHW stats
            dhw_mean = float(group['dhw_current'].mean()) if 'dhw_current' in group.columns else np.nan
            dhw_max = float(group['dhw_current'].max()) if 'dhw_current' in group.columns else np.nan

            # ALL 7 component means for comprehensive output
            comp_means = {}
            for comp in ['ta_norm', 'as_norm', 'sr_norm', 'cdr_norm',
                         'bh_norm', 'wq_norm', 'la_norm']:
                if comp in group.columns:
                    comp_means[comp.replace('_norm', '_mean')] = round(
                        float(group[comp].mean()), 4)
                else:
                    comp_means[comp.replace('_norm', '_mean')] = None

            recommendation, color = self._weekly_recommendation(risk, trend, max_val)

            # ISO week for better cross-year comparison
            iso = week_start.isocalendar()

            row = {
                'week_start': week_start.strftime('%Y-%m-%d'),
                'week_end': week_end.strftime('%Y-%m-%d'),
                'iso_year': int(iso[0]),
                'iso_week': int(iso[1]),
                'pcrvi_mean': round(mean_val, 4),
                'pcrvi_max': round(max_val, 4),
                'pcrvi_min': round(min_val, 4),
                'pcrvi_trend': round(trend, 6),
                'risk_category': risk,
                'dhw_mean': round(dhw_mean, 2) if not np.isnan(dhw_mean) else None,
                'dhw_max': round(dhw_max, 2) if not np.isnan(dhw_max) else None,
                'recommendation': recommendation,
                'alert_color': color,
            }
            row.update(comp_means)
            rows.append(row)

        df = pd.DataFrame(rows)
        self.logger.info(f"Generated {len(df)} weekly risk layers")
        return df

    @staticmethod
    def _weekly_recommendation(risk: str, trend: float, max_pcrvi: float) -> Tuple[str, str]:
        """Generate reef-manager recommendation and alert color."""
        trend_word = "rising" if trend > 0.005 else "falling" if trend < -0.005 else "stable"

        if risk == 'Critical':
            return (f"IMMEDIATE ACTION: Bleaching likely imminent. Risk {trend_word}. "
                    "Deploy emergency monitoring. Document baseline. "
                    "Restrict reef access if possible.", "#8B0000")
        elif risk == 'High':
            return (f"ELEVATED ALERT: Risk {trend_word}. Increase monitoring to twice-weekly. "
                    "Notify stakeholders. Prepare response plans.", "#FF4500")
        elif risk == 'Moderate':
            return (f"WATCH: Risk {trend_word}. Maintain weekly monitoring. "
                    "Review contingency plans.", "#FFA500")
        elif risk == 'Low':
            return (f"ROUTINE: Risk {trend_word}. Standard monitoring sufficient. "
                    "Good period for baseline surveys.", "#FFD700")
        else:
            return (f"ALL CLEAR: Risk {trend_word}. Minimal stress. "
                    "Ideal for restoration and survey activities.", "#228B22")

    # =========================================================================
    # ML WEIGHT OPTIMIZATION
    # =========================================================================

    def optimize_weights_ml(
        self,
        pcrvi_ts: pd.DataFrame,
        dhw_data: pd.DataFrame,
        method: str = 'xgboost',
    ) -> Dict[str, Any]:
        """
        Derive data-driven weights using ML feature importance.

        Trains XGBoost regressor with 5-fold TimeSeriesSplit to predict DHW
        from the 7 normalised pCRVI components.  Feature importances are
        re-normalised to sum to 1.0 as optimised weights.

        Parameters
        ----------
        pcrvi_ts : DataFrame from calculate_timeseries()
        dhw_data : DataFrame with 'dhw' column
        method : str
            'xgboost' (default) or 'ridge' fallback.

        Returns
        -------
        dict with 'expert_weights', 'ml_weights', 'comparison', 'model_metrics'.
        """
        self.logger.info(f"Optimizing pCRVI weights via {method}...")

        component_cols = ['ta_norm', 'as_norm', 'sr_norm', 'cdr_norm',
                          'bh_norm', 'wq_norm', 'la_norm']
        component_names = list(DEFAULT_WEIGHTS.keys())

        # Validate input
        missing_cols = [c for c in component_cols if c not in pcrvi_ts.columns]
        if missing_cols:
            self.logger.warning(f"Missing columns for ML optimization: {missing_cols}")
            return {'error': 'missing_columns', 'missing': missing_cols}

        # Build aligned dataset
        # IMPORTANT: predict FUTURE DHW (30-day lead), not concurrent.
        # Concurrent prediction is circular (as_norm IS current DHW).
        combined = pcrvi_ts[component_cols].copy()
        dhw_aligned = dhw_data.reindex(combined.index)['dhw']
        # Target = max DHW in next 30 days (rolling forward window)
        combined['dhw_future'] = dhw_aligned.rolling(30, min_periods=1).max().shift(-30)
        combined = combined.dropna()

        if len(combined) < 100:
            self.logger.warning(
                f"Only {len(combined)} samples; need ≥100 for reliable optimization")
            return {'error': 'insufficient_data', 'n_samples': len(combined)}

        X = combined[component_cols].values
        y = combined['dhw_future'].values

        # Check for constant target (would crash regression)
        if np.std(y) < 1e-6:
            self.logger.warning("DHW is near-constant; skipping ML optimization")
            return {'error': 'constant_target', 'n_samples': len(combined)}

        results: Dict[str, Any] = {
            'n_samples': len(combined),
            'expert_weights': self.weights.copy(),
            'method': method,
        }

        if method == 'xgboost':
            try:
                from xgboost import XGBRegressor
                from sklearn.model_selection import TimeSeriesSplit
                from sklearn.metrics import mean_absolute_error, r2_score

                tscv = TimeSeriesSplit(n_splits=5)
                importances_list = []
                mae_list, r2_list = [], []

                for train_idx, test_idx in tscv.split(X):
                    model = XGBRegressor(
                        n_estimators=200, max_depth=4, learning_rate=0.05,
                        subsample=0.8, colsample_bytree=0.8, random_state=42,
                        reg_alpha=0.1, reg_lambda=1.0,
                    )
                    model.fit(
                        X[train_idx], y[train_idx],
                        eval_set=[(X[test_idx], y[test_idx])],
                        verbose=False,
                    )
                    importances_list.append(model.feature_importances_)
                    y_pred = model.predict(X[test_idx])
                    mae_list.append(mean_absolute_error(y[test_idx], y_pred))
                    r2_list.append(r2_score(y[test_idx], y_pred))

                avg_imp = np.mean(importances_list, axis=0)
                imp_sum = avg_imp.sum()
                ml_weights_arr = avg_imp / imp_sum if imp_sum > 0 else np.full_like(avg_imp, 1.0 / len(avg_imp))

                ml_weights = {name: float(w) for name, w in zip(component_names, ml_weights_arr)}

                results['ml_weights'] = ml_weights
                results['feature_importances'] = {
                    name: float(imp) for name, imp in zip(component_names, avg_imp)
                }
                results['model_metrics'] = {
                    'mean_mae': float(np.mean(mae_list)),
                    'mean_r2': float(np.mean(r2_list)),
                    'std_mae': float(np.std(mae_list)),
                    'std_r2': float(np.std(r2_list)),
                    'target': 'future_dhw_30d',
                }

                # Quality gate: if R² < 0.3, ML weights are unreliable
                mean_r2 = float(np.mean(r2_list))
                if mean_r2 < 0.3:
                    self.logger.warning(
                        f"ML weight model R²={mean_r2:.3f} (< 0.3). "
                        f"ML weights are UNRELIABLE — expert weights preferred.")
                    results['quality_warning'] = (
                        f"R²={mean_r2:.3f} is too low for reliable weight derivation. "
                        f"Expert weights should be used for operational deployment."
                    )
                    results['use_expert'] = True
                else:
                    results['use_expert'] = False
                results['comparison'] = {
                    name: {
                        'expert': float(self.weights[name]),
                        'ml': float(ml_weights[name]),
                        'diff': float(ml_weights[name] - self.weights[name]),
                    }
                    for name in component_names
                }

                self.logger.info("ML weight optimization complete:")
                for name in component_names:
                    self.logger.info(
                        f"  {name}: expert={self.weights[name]:.3f}, "
                        f"ml={ml_weights[name]:.3f}"
                    )

            except ImportError:
                self.logger.warning("xgboost not available; falling back to ridge regression")
                method = 'ridge'

        if method == 'ridge':
            from sklearn.linear_model import Ridge
            from sklearn.preprocessing import StandardScaler
            from sklearn.metrics import mean_absolute_error, r2_score

            scaler = StandardScaler()
            X_s = scaler.fit_transform(X)
            model = Ridge(alpha=1.0)
            model.fit(X_s, y)
            y_pred = model.predict(X_s)

            abs_coef = np.abs(model.coef_)
            coef_sum = abs_coef.sum()
            ml_weights_arr = abs_coef / coef_sum if coef_sum > 0 else np.full_like(abs_coef, 1.0 / len(abs_coef))
            ml_weights = {name: float(w) for name, w in zip(component_names, ml_weights_arr)}

            results['ml_weights'] = ml_weights
            results['feature_importances'] = {
                name: float(c) for name, c in zip(component_names, abs_coef)
            }
            results['model_metrics'] = {
                'mae': float(mean_absolute_error(y, y_pred)),
                'r2': float(r2_score(y, y_pred)),
            }
            results['comparison'] = {
                name: {
                    'expert': float(self.weights[name]),
                    'ml': float(ml_weights[name]),
                    'diff': float(ml_weights[name] - self.weights[name]),
                }
                for name in component_names
            }
            results['method'] = 'ridge'

        return results

    # =========================================================================
    # PREDICTIVE SKILL ANALYSIS
    # =========================================================================

    def analyze_predictive_skill(
        self,
        pcrvi_ts: pd.DataFrame,
        dhw_data: pd.DataFrame,
        lead_days: List[int] = None,
        threshold: float = 0.4,
    ) -> Dict[str, Any]:
        """
        Evaluate pCRVI predictive skill at multiple lead times.

        Computes correlation, precision, recall, F1, MCC, HSS for each
        lead time.  Also performs threshold optimization using the 30-day
        lead window.

        Returns
        -------
        dict with 'lead_time_analysis', 'threshold_analysis', 'optimal_threshold',
        'optimal_f1', 'current_assessment'.
        """
        lead_days = lead_days or [7, 14, 30, 60, 90]
        self.logger.info("Analyzing Enhanced-pCRVI predictive skill...")

        results: Dict[str, Any] = {
            'lead_time_analysis': {},
            'threshold_analysis': {},
        }

        all_pcrvi, all_future_dhw = [], []

        for lead in lead_days:
            pv, fd = [], []
            for dt in pcrvi_ts.index[:-lead]:
                p = pcrvi_ts.loc[dt, 'pcrvi']
                if isinstance(p, pd.Series):
                    p = p.iloc[0]
                end_dt = dt + pd.Timedelta(days=lead)
                period = dhw_data.loc[dt:end_dt, 'dhw']
                if not period.empty:
                    pv.append(float(p))
                    fd.append(float(period.max()))

            if len(pv) < 30:
                self.logger.debug(f"Lead {lead}d: only {len(pv)} samples, skipping")
                continue

            pa = np.array(pv)
            da = np.array(fd)
            if lead == 30:
                all_pcrvi, all_future_dhw = pv, fd

            corr = float(np.corrcoef(pa, da)[0, 1]) if np.std(pa) > 0 and np.std(da) > 0 else 0.0
            high = pa >= threshold
            bleach = da >= 4.0
            tp = int(np.sum(high & bleach))
            fp = int(np.sum(high & ~bleach))
            fn = int(np.sum(~high & bleach))
            tn = int(np.sum(~high & ~bleach))
            prec = tp / (tp + fp) if (tp + fp) > 0 else 0
            rec = tp / (tp + fn) if (tp + fn) > 0 else 0
            f1 = 2 * prec * rec / (prec + rec) if (prec + rec) > 0 else 0
            acc = (tp + tn) / len(pa) if len(pa) > 0 else 0
            denom = np.sqrt(float((tp + fp) * (tp + fn) * (tn + fp) * (tn + fn)))
            mcc = (tp * tn - fp * fn) / denom if denom > 0 else 0
            denom2 = (tp + fn) * (fn + tn) + (tp + fp) * (fp + tn)
            hss = 2 * (tp * tn - fp * fn) / denom2 if denom2 > 0 else 0

            results['lead_time_analysis'][f'{lead}_days'] = {
                'correlation': round(corr, 4),
                'precision': round(prec, 4),
                'recall': round(rec, 4),
                'f1_score': round(f1, 4),
                'accuracy': round(acc, 4),
                'mcc': round(mcc, 4),
                'heidke_skill_score': round(hss, 4),
                'peirce_skill_score': round(
                    rec - (fp / (fp + tn)) if (fp + tn) > 0 else 0.0, 4),
                'critical_success_index': round(
                    tp / (tp + fn + fp) if (tp + fn + fp) > 0 else 0.0, 4),
                'frequency_bias': round(
                    (tp + fp) / (tp + fn) if (tp + fn) > 0 else 0.0, 4),
                'false_alarm_ratio': round(
                    fp / (tp + fp) if (tp + fp) > 0 else 0.0, 4),
                'prob_false_detection': round(
                    fp / (fp + tn) if (fp + tn) > 0 else 0.0, 4),
                'n_samples': len(pa),
                'tp': tp, 'fp': fp, 'fn': fn, 'tn': tn,
            }

        # Threshold optimization at 30-day lead
        best_f1, best_thresh = 0.0, 0.4
        if all_pcrvi:
            pa = np.array(all_pcrvi)
            da = np.array(all_future_dhw)
            for thr in np.arange(0.15, 0.80, 0.05):
                h = pa >= thr
                b = da >= 4.0
                t_p = int(np.sum(h & b))
                f_p = int(np.sum(h & ~b))
                f_n = int(np.sum(~h & b))
                t_n = int(np.sum(~h & ~b))
                p_ = t_p / (t_p + f_p) if (t_p + f_p) > 0 else 0
                r_ = t_p / (t_p + f_n) if (t_p + f_n) > 0 else 0
                f_ = 2 * p_ * r_ / (p_ + r_) if (p_ + r_) > 0 else 0
                pofd_ = f_p / (f_p + t_n) if (f_p + t_n) > 0 else 0
                pss_ = r_ - pofd_
                csi_ = t_p / (t_p + f_n + f_p) if (t_p + f_n + f_p) > 0 else 0
                fb_  = (t_p + f_p) / (t_p + f_n) if (t_p + f_n) > 0 else 0
                d2 = (t_p + f_n) * (f_n + t_n) + (t_p + f_p) * (f_p + t_n)
                hss_ = 2 * (t_p * t_n - f_p * f_n) / d2 if d2 > 0 else 0
                d3 = np.sqrt(float((t_p+f_p)*(t_p+f_n)*(t_n+f_p)*(t_n+f_n)))
                mcc_ = (t_p * t_n - f_p * f_n) / d3 if d3 > 0 else 0

                results['threshold_analysis'][f'{thr:.2f}'] = {
                    'f1_score': round(f_, 4),
                    'precision': round(p_, 4),
                    'recall': round(r_, 4),
                    'mcc': round(mcc_, 4),
                    'hss': round(hss_, 4),
                    'pss': round(pss_, 4),
                    'csi': round(csi_, 4),
                    'frequency_bias': round(fb_, 4),
                    'false_alarm_ratio': round(1 - p_ if (t_p + f_p) > 0 else 1.0, 4),
                    'pofd': round(pofd_, 4),
                    'n_alerts': int(h.sum()),
                }
                if f_ > best_f1:
                    best_f1, best_thresh = f_, float(thr)

        results['optimal_threshold'] = round(best_thresh, 2)
        results['optimal_f1'] = round(best_f1, 4)

        # Current risk assessment
        if not pcrvi_ts.empty:
            results['current_assessment'] = self.get_current_risk(pcrvi_ts)

        self.logger.info(
            f"Skill analysis complete: optimal threshold={best_thresh:.2f}, "
            f"F1={best_f1:.3f}"
        )
        return results

    def get_current_risk(self, pcrvi_ts: pd.DataFrame) -> Dict[str, Any]:
        """Get current (latest date) risk assessment with recommendation."""
        latest = pcrvi_ts.iloc[-1]
        dt = pcrvi_ts.index[-1]

        lookback = dt - pd.Timedelta(days=14)
        recent = pcrvi_ts.loc[lookback:dt, 'pcrvi']
        if len(recent) >= 2:
            trend = ('increasing' if recent.iloc[-1] > recent.iloc[0] + 0.01 else
                     'decreasing' if recent.iloc[-1] < recent.iloc[0] - 0.01 else 'stable')
            trend_val = float(recent.iloc[-1] - recent.iloc[0])
        else:
            trend, trend_val = 'unknown', 0.0

        components = {}
        for col, label in [
            ('ta_norm', COMPONENT_LABELS.get('ta_norm', 'Thermal Anomaly')),
            ('as_norm', COMPONENT_LABELS.get('as_norm', 'Accumulated Heat Stress')),
            ('sr_norm', COMPONENT_LABELS.get('sr_norm', 'Seasonal Bleaching Risk')),
            ('cdr_norm', COMPONENT_LABELS.get('cdr_norm', 'Climate Driver Response')),
            ('bh_norm', COMPONENT_LABELS.get('bh_norm', 'Population Vulnerability')),
            ('wq_norm', COMPONENT_LABELS.get('wq_norm', 'Water Quality Stress')),
            ('la_norm', COMPONENT_LABELS.get('la_norm', 'Light Availability')),
        ]:
            val = latest.get(col, 0)
            components[label] = float(val) if not np.isnan(val) else 0.0

        primary_driver = max(components, key=components.get) if components else 'Unknown'

        risk_cat = str(latest.get('risk_category', 'Minimal'))
        pcrvi_val = float(latest.get('pcrvi', 0))
        rec, _ = self._weekly_recommendation(risk_cat, trend_val, pcrvi_val)

        dhw_val = latest.get('dhw_current', np.nan)
        if isinstance(dhw_val, pd.Series):
            dhw_val = dhw_val.iloc[0]

        return {
            'date': str(dt.date()),
            'pcrvi': round(pcrvi_val, 4),
            'risk_category': risk_cat,
            'trend': trend,
            'trend_14d': round(trend_val, 4),
            'components': components,
            'primary_driver': primary_driver,
            'current_dhw': round(float(dhw_val), 2) if not np.isnan(dhw_val) else None,
            'is_peak_season': bool(latest.get('is_peak_season', False)),
            'recommendation': rec,
        }
