"""
Variable Naming Registry
=========================

Single source of truth for all variable names used across the Coral
Bleaching Early Warning System.  Every plot, CSV header, HTML report,
poster, presentation slide, and journal manuscript pulls display names
from this module.

Usage
-----
    from .naming import label, units, csv_header, paper_ref, description
    from .naming import COMPONENT_LABELS, COMPONENT_COLORS, WEIGHT_LABELS

    ax.set_ylabel(label('sst'))                       # → "Sea Surface Temperature (SST)"
    ax.set_ylabel(f"{label('sst')} ({units('sst')})")  # → "Sea Surface Temperature (SST) (°C)"
    df.rename(columns=csv_header)                      # renames all columns at once
    caption = f"{paper_ref('dhw')} ..."                # → "Degree Heating Weeks (DHW; Liu et al. 2014)"
"""

from dataclasses import dataclass, field
from typing import Dict, Optional, List


@dataclass(frozen=True)
class VariableInfo:
    """Metadata for a single variable."""
    # ── Required ──────────────────────────────────────────────────
    key: str                       # Internal column name (e.g. 'sst')
    common: str                    # Plain-English name
    abbreviation: str              # Short code (e.g. 'SST')
    # ── Optional ──────────────────────────────────────────────────
    scientific: str = ""           # Formal / journal name
    technical: str = ""            # Algorithmic / product name
    agency: str = ""               # Government agency product name
    unit: str = ""                 # Physical unit string
    description: str = ""          # One-liner tooltip / caption text
    reference: str = ""            # Key citation (Author Year)
    aliases: tuple = ()            # Other column names that map here


# ══════════════════════════════════════════════════════════════════
#  REGISTRY — every variable the system uses
# ══════════════════════════════════════════════════════════════════

_REGISTRY: Dict[str, VariableInfo] = {}


def _reg(v: VariableInfo):
    """Register a variable and all its aliases."""
    _REGISTRY[v.key] = v
    for a in v.aliases:
        _REGISTRY[a] = v


# ── Sea Surface Temperature & Thermal Products ──────────────────

_reg(VariableInfo(
    key='sst',
    common='Sea Surface Temperature',
    abbreviation='SST',
    scientific='Sea Surface Temperature',
    technical='NOAA OISSTv2.1 daily mean SST',
    agency='NOAA OISST / NOAA Coral Reef Watch SST',
    unit='°C',
    description='Satellite-derived ocean skin temperature at ~5 km resolution',
    reference='Reynolds et al. (2007)',
    aliases=('sea_surface_temperature',),
))

_reg(VariableInfo(
    key='sst_anomaly',
    common='SST Anomaly',
    abbreviation='SSTA',
    scientific='Sea Surface Temperature Anomaly',
    technical='SST departure from MMM climatology',
    agency='NOAA CRW SST Anomaly',
    unit='°C',
    description='Departure of SST from the Maximum Monthly Mean (MMM) climatology',
    reference='Liu et al. (2014)',
))

_reg(VariableInfo(
    key='hotspot',
    common='Coral Bleaching HotSpot',
    abbreviation='HS',
    scientific='Coral Bleaching HotSpot',
    technical='max(SST − MMM, 0)',
    agency='NOAA Coral Reef Watch HotSpot',
    unit='°C',
    description='Positive SST exceedance above MMM; HS ≥ 1°C triggers Bleaching Watch',
    reference='Liu et al. (2003)',
))

_reg(VariableInfo(
    key='dhw',
    common='Degree Heating Weeks',
    abbreviation='DHW',
    scientific='Degree Heating Weeks',
    technical='12-week rolling accumulation of HotSpot ≥ 1°C',
    agency='NOAA Coral Reef Watch DHW',
    unit='°C-weeks',
    description='Accumulated thermal stress; DHW ≥ 4 = bleaching likely, '
                'DHW ≥ 8 = mass bleaching & mortality likely',
    reference='Liu et al. (2014)',
))

_reg(VariableInfo(
    key='mmm_sst',
    common='Maximum Monthly Mean SST',
    abbreviation='MMM',
    scientific='Maximum Monthly Mean Sea Surface Temperature',
    technical='Warmest month in the 1985-2012 SST climatology',
    agency='NOAA CRW MMM Climatology',
    unit='°C',
    description='Bleaching baseline: the warmest monthly climatological SST '
                'for a given location (1985-2012 baseline)',
    reference='Liu et al. (2014)',
))

# SST derived features
_reg(VariableInfo(key='sst_7d_mean', common='SST 7-Day Mean', abbreviation='SST₇',
    unit='°C', description='7-day rolling mean SST'))
_reg(VariableInfo(key='sst_30d_mean', common='SST 30-Day Mean', abbreviation='SST₃₀',
    unit='°C', description='30-day rolling mean SST'))
_reg(VariableInfo(key='sst_trend_7d', common='SST 7-Day Trend', abbreviation='ΔSST₇',
    unit='°C', description='SST change over the past 7 days'))
_reg(VariableInfo(key='hotspot_4w_sum', common='HotSpot 4-Week Accumulation',
    abbreviation='HS₄w', unit='°C-weeks',
    description='4-week sum of daily HotSpot values (DHW building block)'))
_reg(VariableInfo(key='dhw_7d_max', common='DHW 7-Day Maximum', abbreviation='DHW₇max',
    unit='°C-weeks', description='Maximum DHW in the trailing 7 days'))

# SST lagged
for _lag in [7, 14, 30, 60]:
    _reg(VariableInfo(key=f'sst_lag{_lag}', common=f'SST ({_lag}-day lag)',
        abbreviation=f'SST_L{_lag}', unit='°C',
        description=f'SST lagged by {_lag} days'))
for _lag in [7, 14, 30]:
    _reg(VariableInfo(key=f'dhw_lag{_lag}', common=f'DHW ({_lag}-day lag)',
        abbreviation=f'DHW_L{_lag}', unit='°C-weeks',
        description=f'DHW lagged by {_lag} days'))


# ── NOAA Alert Products ─────────────────────────────────────────

_reg(VariableInfo(
    key='baa',
    common='Bleaching Alert Area',
    abbreviation='BAA',
    scientific='Bleaching Alert Area',
    technical='Spatial alert classification from HotSpot + DHW thresholds',
    agency='NOAA Coral Reef Watch Bleaching Alert Area (v3.1)',
    description='5 km gridded alert: No Stress → Watch → Warning → '
                'Alert Level 1 → Alert Level 2',
    reference='Liu et al. (2014)',
    aliases=('baa-max', 'baa5-max', 'alert_level'),
))

_reg(VariableInfo(
    key='baa5',
    common='Bleaching Alert Area (5-Level)',
    abbreviation='BAA-5',
    scientific='Extended Bleaching Alert Area',
    technical='CRW v3.1 extended 5-level alert (adds Levels 3 & 4)',
    agency='NOAA Coral Reef Watch BAA 5-Level (v3.1, 2023+)',
    description='Extended to include Alert Level 3 (DHW ≥ 12) and '
                'Level 4 (DHW ≥ 16) for extreme events',
    reference='NOAA CRW (2023)',
))


# ── Ocean Color / Water Quality ─────────────────────────────────

_reg(VariableInfo(
    key='chlorophyll',
    common='Chlorophyll-a',
    abbreviation='Chl-a',
    scientific='Chlorophyll-a concentration',
    technical='Copernicus OCEANCOLOUR_GLO_BGC_L3 CHL variable',
    agency='Copernicus Marine Service (CMEMS) Ocean Colour',
    unit='mg/m³',
    description='Phytoplankton pigment concentration; proxy for '
                'nutrient loading and eutrophication stress',
    reference='Wooldridge (2009)',
    aliases=('CHL', 'chl', 'chlor_a', 'Chlorophyll', 'chlorophyll_a'),
))

_reg(VariableInfo(
    key='chlorophyll_anomaly',
    common='Chlorophyll-a Anomaly',
    abbreviation='Chl-a Anom',
    scientific='Chlorophyll-a concentration anomaly',
    technical='Departure from monthly Chl-a climatology',
    agency='Derived from CMEMS Ocean Colour',
    unit='mg/m³',
    description='Positive anomaly indicates eutrophication / algal bloom stress',
    aliases=('chl_anomaly',),
))

_reg(VariableInfo(
    key='turbidity',
    common='Turbidity',
    abbreviation='Kd490',
    scientific='Diffuse attenuation coefficient at 490 nm',
    technical='Copernicus OCEANCOLOUR_GLO_BGC_L3 KD490 variable',
    agency='Copernicus Marine Service (CMEMS) / NASA Ocean Color (MODIS/VIIRS)',
    unit='m⁻¹',
    description='Measure of water clarity / turbidity; higher values = '
                'murkier water, reduced light for corals',
    reference='Sully et al. (2019)',
    aliases=('KD490', 'kd490', 'Kd490', 'kd_490'),
))

_reg(VariableInfo(
    key='turbidity_anomaly',
    common='Turbidity Anomaly',
    abbreviation='Kd490 Anom',
    scientific='Kd490 anomaly',
    technical='Departure from monthly Kd490 climatology',
    agency='Derived from CMEMS Ocean Colour',
    unit='m⁻¹',
    description='Positive anomaly indicates increased turbidity / reduced clarity',
    aliases=('kd490_anomaly',),
))

_reg(VariableInfo(
    key='light_attenuation',
    common='Light Attenuation',
    abbreviation='Kd490',
    scientific='Diffuse attenuation coefficient at 490 nm',
    technical='Same physical quantity as turbidity (Kd490)',
    agency='CMEMS / NASA Ocean Color',
    unit='m⁻¹',
    description='Rate at which downwelling irradiance is attenuated '
                'with depth; controls light reaching corals',
    reference='Kirk (2011)',
))

_reg(VariableInfo(
    key='par_proxy',
    common='PAR Proxy',
    abbreviation='PAR',
    scientific='Photosynthetically Active Radiation (proxy)',
    technical='Estimated from cloud cover inversion and Kd490',
    agency='Derived (ERA5 cloud + CMEMS Kd490)',
    unit='relative (0–1)',
    description='Proxy for photosynthetically active radiation reaching coral;'
                ' combines atmospheric transparency and water clarity',
))

_reg(VariableInfo(
    key='clarity_score',
    common='Water Clarity Score',
    abbreviation='Clarity',
    scientific='Composite water clarity index',
    technical='Normalized inverse Kd490',
    unit='0–1',
    description='Higher values = clearer water, more light stress on bleached corals',
))


# ── Climate Indices ──────────────────────────────────────────────

_reg(VariableInfo(
    key='oni',
    common='El Niño Index',
    abbreviation='ONI',
    scientific='Oceanic Niño Index',
    technical='3-month running mean of SST anomaly in Niño 3.4 region',
    agency='NOAA Climate Prediction Center (CPC) ONI',
    unit='°C',
    description='Primary ENSO indicator; ONI > +0.5 = El Niño, '
                'ONI < −0.5 = La Niña',
    reference='Barnston et al. (1997)',
))

_reg(VariableInfo(
    key='dmi',
    common='Indian Ocean Dipole',
    abbreviation='DMI',
    scientific='Dipole Mode Index',
    technical='SST gradient between western and eastern equatorial Indian Ocean',
    agency='NOAA PSL / Japan Agency for Marine-Earth Science (JAMSTEC)',
    unit='°C',
    description='Positive DMI = warm western Indian Ocean, '
                'influences Andaman/Indian reef thermal stress',
    reference='Saji et al. (1999)',
))

# Climate lagged
for _base, _lbl, _abbr in [('oni', 'El Niño Index', 'ONI'), ('dmi', 'Indian Ocean Dipole', 'DMI')]:
    for _lag in [30, 60, 90]:
        _reg(VariableInfo(
            key=f'{_base}_lag{_lag}',
            common=f'{_lbl} ({_lag}-day lag)',
            abbreviation=f'{_abbr}_L{_lag}',
            unit='°C',
            description=f'{_lbl} ({_abbr}) lagged by {_lag} days as leading predictor',
        ))

_reg(VariableInfo(
    key='is_elnino',
    common='El Niño Active',
    abbreviation='ENSO+',
    scientific='El Niño phase indicator',
    technical='ONI > 0.5 binary flag',
    agency='NOAA CPC ENSO classification',
    unit='boolean',
    description='1 when ONI > 0.5°C (El Niño conditions)',
))


# ── pCRVI Components ────────────────────────────────────────────

_reg(VariableInfo(
    key='pcrvi',
    common='Coral Reef Vulnerability Index',
    abbreviation='pCRVI',
    scientific='Predictive Coral Reef Vulnerability Index',
    technical='Weighted 7-component composite vulnerability score',
    unit='0–1',
    description='Primary bleaching risk index combining thermal, environmental, '
                'ecological, and climate-driver components',
    aliases=('pcrvi_base',),
))

_reg(VariableInfo(
    key='ta_norm',
    common='Thermal Anomaly',
    abbreviation='TA',
    scientific='Normalized thermal anomaly component',
    technical='SST anomaly above MMM, logistic-scaled to 0–1',
    unit='0–1',
    description='Current thermal stress relative to bleaching threshold',
    reference='Liu et al. (2014)',
))

_reg(VariableInfo(
    key='as_norm',
    common='Accumulated Heat Stress',
    abbreviation='AS',
    scientific='Normalized accumulating stress component',
    technical='DHW normalized to 12 °C-weeks ceiling, with trend bonus',
    unit='0–1',
    description='Cumulative thermal stress representing prolonged heating',
    reference='Liu et al. (2014)',
    aliases=('accumulating_stress',),
))

_reg(VariableInfo(
    key='sr_norm',
    common='Seasonal Bleaching Risk',
    abbreviation='SR',
    scientific='Normalized seasonal risk component',
    technical='Sinusoidal peak-season model (Mar–Jun for Indian Ocean)',
    unit='0–1',
    description='Seasonal probability of bleaching based on climatological timing',
    aliases=('seasonal_risk',),
))

_reg(VariableInfo(
    key='cdr_norm',
    common='Climate Driver Response',
    abbreviation='CDR',
    scientific='Normalized climate driver response component',
    technical='Weighted combination of lagged ONI and DMI',
    agency='Derived from NOAA CPC ONI + JAMSTEC DMI',
    unit='0–1',
    description='Large-scale climate teleconnection signal (ENSO + IOD) '
                'that leads thermal stress by 60–90 days',
    reference='Heron et al. (2016)',
    aliases=('climate_driver',),
))

_reg(VariableInfo(
    key='bh_norm',
    common='Population Vulnerability',
    abbreviation='BH',
    scientific='Bleaching history & population vulnerability component',
    technical='Time-since-last-bleaching decay model with adaptation',
    unit='0–1',
    description='Coral population susceptibility based on bleaching history; '
                'recently bleached reefs can be more or less vulnerable',
    reference='Hughes et al. (2019)',
    aliases=('bleaching_history',),
))

_reg(VariableInfo(
    key='wq_norm',
    common='Water Quality Stress',
    abbreviation='WQ',
    scientific='Water quality stress component (Chlorophyll-a + Turbidity)',
    technical='Normalized combination of Chl-a anomaly and Kd490 anomaly',
    agency='Derived from Copernicus Marine Service ocean colour',
    unit='0–1',
    description='Eutrophication and turbidity stress; elevated nutrients '
                'and poor clarity reduce coral resilience',
    reference='Wooldridge (2009); Sully et al. (2019)',
    aliases=('water_quality',),
))

_reg(VariableInfo(
    key='la_norm',
    common='Light Availability',
    abbreviation='LA',
    scientific='Light availability component (PAR proxy + attenuation)',
    technical='Combines ERA5 cloud cover inversion with Kd490 clarity',
    agency='Derived from ECMWF ERA5 + CMEMS ocean colour',
    unit='0–1',
    description='Photosynthetically Active Radiation proxy; high light on '
                'thermally stressed corals accelerates bleaching',
    reference='Lesser & Farrell (2004)',
    aliases=('light_availability',),
))

# pCRVI lagged
for _base in ['pcrvi', 'ta_norm', 'as_norm', 'sr_norm', 'cdr_norm',
              'bh_norm', 'wq_norm', 'la_norm']:
    _info = _REGISTRY[_base]
    for _lag in [7, 14, 30]:
        _reg(VariableInfo(
            key=f'{_base}_lag{_lag}',
            common=f'{_info.common} ({_lag}-day lag)',
            abbreviation=f'{_info.abbreviation}_L{_lag}',
            unit=_info.unit,
            description=f'{_info.common} lagged by {_lag} days',
        ))

# ocean color lagged
for _base in ['chlorophyll', 'turbidity', 'light_attenuation']:
    _info = _REGISTRY[_base]
    for _lag in [7, 14, 30]:
        _reg(VariableInfo(
            key=f'{_base}_lag{_lag}',
            common=f'{_info.common} ({_lag}-day lag)',
            abbreviation=f'{_info.abbreviation}_L{_lag}',
            unit=_info.unit,
            description=f'{_info.common} lagged by {_lag} days',
        ))


# ── Atmospheric ──────────────────────────────────────────────────

_reg(VariableInfo(
    key='cloud_cover',
    common='Cloud Cover',
    abbreviation='CC',
    scientific='Total cloud cover fraction',
    technical='ERA5 total cloud cover (TCC)',
    agency='ECMWF ERA5 Reanalysis',
    unit='0–1',
    description='Fraction of sky covered by cloud; modulates PAR reaching reef',
    aliases=('tcc',),
))

_reg(VariableInfo(
    key='wind_speed',
    common='Wind Speed',
    abbreviation='WS',
    scientific='10-metre wind speed',
    technical='sqrt(u10² + v10²) from ERA5',
    agency='ECMWF ERA5 Reanalysis',
    unit='m/s',
    description='Surface wind speed; affects ocean mixing and cooling',
    aliases=('u_wind', 'v_wind'),
))

_reg(VariableInfo(
    key='current_speed',
    common='Ocean Current Speed',
    abbreviation='CS',
    scientific='Sea surface current speed',
    technical='Copernicus GLORYS12V1 surface current magnitude',
    agency='Copernicus Marine Service (CMEMS)',
    unit='m/s',
    description='Surface current speed affecting heat advection and flushing',
))


# ── Temporal Features ────────────────────────────────────────────

_reg(VariableInfo(key='doy', common='Day of Year', abbreviation='DoY',
    unit='1–366', description='Calendar day of the year'))
_reg(VariableInfo(key='month', common='Month', abbreviation='Mo',
    unit='1–12', description='Calendar month'))
_reg(VariableInfo(key='doy_sin', common='Seasonal Cycle (sine)', abbreviation='DoY_sin',
    description='Sine-encoded day-of-year for cyclical seasonality'))
_reg(VariableInfo(key='doy_cos', common='Seasonal Cycle (cosine)', abbreviation='DoY_cos',
    description='Cosine-encoded day-of-year for cyclical seasonality'))
_reg(VariableInfo(key='is_peak', common='Peak Bleaching Season', abbreviation='Peak',
    unit='boolean', description='1 during climatological peak bleaching months (Mar–Jun)'))


# ── Extreme Variability Diagnostics ─────────────────────────────

_reg(VariableInfo(key='ev_score', common='Extreme Variability Score', abbreviation='EV',
    unit='0–1', description='Composite measure of unusual environmental variability'))
_reg(VariableInfo(key='ev_amplification', common='EV Amplification Factor',
    abbreviation='EV_amp', description='Multiplier applied to pCRVI during extremes'))
_reg(VariableInfo(key='sst_sigma_departure', common='SST Sigma Departure',
    abbreviation='SST_σ', unit='σ',
    description='SST departure from climatology in standard deviations'))
_reg(VariableInfo(key='sst_rolling_sd_30d', common='SST 30-Day Std Dev',
    abbreviation='SST_SD₃₀', unit='°C',
    description='Rolling 30-day standard deviation of SST'))
_reg(VariableInfo(key='sst_variability_amp',
    common='SST Variability Amplification', abbreviation='SST_VA',
    description='Ratio of current SST variability to climatological variability'))
_reg(VariableInfo(key='sst_exceed_2sd', common='SST Exceeds 2σ', abbreviation='SST>2σ',
    unit='boolean', description='SST exceeds 2 standard deviations above climatology'))
_reg(VariableInfo(key='sst_exceed_3sd', common='SST Exceeds 3σ', abbreviation='SST>3σ',
    unit='boolean', description='SST exceeds 3 standard deviations above climatology'))
_reg(VariableInfo(key='dhw_rolling_sd_rate', common='DHW Rate-of-Change Volatility',
    abbreviation='DHW_σ_rate', description='Rolling SD of DHW rate of change'))
_reg(VariableInfo(key='chl_sigma_departure', common='Chlorophyll-a Sigma Departure',
    abbreviation='Chl-a_σ', unit='σ',
    description='Chlorophyll-a departure in standard deviations'))
_reg(VariableInfo(key='kd490_sigma_departure', common='Turbidity Sigma Departure',
    abbreviation='Kd490_σ', unit='σ',
    description='Kd490 departure in standard deviations'))
_reg(VariableInfo(key='cloud_sigma_departure', common='Cloud Cover Sigma Departure',
    abbreviation='CC_σ', unit='σ',
    description='Cloud cover departure in standard deviations'))
_reg(VariableInfo(key='n_concurrent_extremes', common='Concurrent Extreme Count',
    abbreviation='N_ext', description='Number of variables simultaneously extreme'))


# ── Other Diagnostics ───────────────────────────────────────────

_reg(VariableInfo(key='dhw_current', common='Current DHW', abbreviation='DHW_now',
    unit='°C-weeks', description='Most recent DHW value'))
_reg(VariableInfo(key='current_sst', common='Current SST', abbreviation='SST_now',
    unit='°C', description='Most recent SST value'))
_reg(VariableInfo(key='dhw_trend', common='DHW Trend', abbreviation='ΔDHW',
    unit='°C-weeks/week', description='Rate of DHW change'))
_reg(VariableInfo(key='dhw_momentum', common='DHW Momentum', abbreviation='DHW_mom',
    description='Acceleration of DHW accumulation'))
_reg(VariableInfo(key='years_since_bleaching', common='Years Since Last Bleaching',
    abbreviation='YSB', unit='years',
    description='Time elapsed since last documented bleaching event'))
_reg(VariableInfo(key='risk_category', common='Risk Category', abbreviation='Risk',
    description='Categorical bleaching risk level'))

# ── Weight keys (used in pCRVI weight dicts) ────────────────────

_reg(VariableInfo(key='thermal_anomaly', common='Thermal Anomaly Weight',
    abbreviation='TA', description='pCRVI weight for TA component'))
_reg(VariableInfo(key='accumulating_stress', common='Accumulated Heat Stress Weight',
    abbreviation='AS', description='pCRVI weight for AS component'))
_reg(VariableInfo(key='seasonal_risk', common='Seasonal Bleaching Risk Weight',
    abbreviation='SR', description='pCRVI weight for SR component'))
_reg(VariableInfo(key='climate_driver', common='Climate Driver Response Weight',
    abbreviation='CDR', description='pCRVI weight for CDR component'))
_reg(VariableInfo(key='bleaching_history', common='Population Vulnerability Weight',
    abbreviation='BH', description='pCRVI weight for BH component'))
_reg(VariableInfo(key='water_quality', common='Water Quality Stress Weight',
    abbreviation='WQ', description='pCRVI weight for WQ component'))
_reg(VariableInfo(key='light_availability', common='Light Availability Weight',
    abbreviation='LA', description='pCRVI weight for LA component'))


# ══════════════════════════════════════════════════════════════════
#  PUBLIC LOOKUP FUNCTIONS
# ══════════════════════════════════════════════════════════════════

def info(key: str) -> Optional[VariableInfo]:
    """Return full VariableInfo for a key, or None."""
    return _REGISTRY.get(key)


def label(key: str, style: str = 'common') -> str:
    """
    Display label for plots and reports.

    Parameters
    ----------
    key : str
        Internal column name.
    style : str
        'common'     → "Chlorophyll-a"               (default — plots, posters)
        'abbrev'     → "Chl-a"                       (compact axis labels)
        'full'       → "Chlorophyll-a (Chl-a)"       (first mention in papers)
        'scientific' → "Chlorophyll-a concentration"  (formal methods section)
        'technical'  → "Copernicus OCEANCOLOUR..."    (data description)
        'agency'     → "Copernicus Marine Service..." (acknowledgements)
    """
    v = _REGISTRY.get(key)
    if v is None:
        return key.replace('_', ' ').title()
    if style == 'common':
        return v.common
    elif style == 'abbrev':
        return v.abbreviation
    elif style == 'full':
        return f'{v.common} ({v.abbreviation})' if v.abbreviation else v.common
    elif style == 'scientific':
        return v.scientific or v.common
    elif style == 'technical':
        return v.technical or v.common
    elif style == 'agency':
        return v.agency or v.common
    return v.common


def units(key: str) -> str:
    """Return unit string for a variable, or '' if dimensionless."""
    v = _REGISTRY.get(key)
    return v.unit if v else ''


def label_with_units(key: str, style: str = 'common') -> str:
    """'Chlorophyll-a (mg/m³)' — ready for axis labels."""
    u = units(key)
    lbl = label(key, style)
    return f'{lbl} ({u})' if u else lbl


def description(key: str) -> str:
    """Tooltip / caption text."""
    v = _REGISTRY.get(key)
    return v.description if v else ''


def paper_ref(key: str) -> str:
    """
    Name suitable for first mention in a journal paper, with citation.
    e.g. "Degree Heating Weeks (DHW; Liu et al. 2014)"
    """
    v = _REGISTRY.get(key)
    if v is None:
        return key
    parts = [v.common]
    if v.abbreviation:
        parts.append(f'({v.abbreviation}')
        if v.reference:
            parts[-1] += f'; {v.reference})'
        else:
            parts[-1] += ')'
    elif v.reference:
        parts.append(f'({v.reference})')
    return ' '.join(parts)


def csv_header(key: str) -> str:
    """
    Column header for CSV exports.
    e.g. 'Chlorophyll-a (Chl-a) [mg/m³]'
    """
    v = _REGISTRY.get(key)
    if v is None:
        return key
    hdr = f'{v.common} ({v.abbreviation})' if v.abbreviation else v.common
    if v.unit:
        hdr += f' [{v.unit}]'
    return hdr


def csv_rename_dict(columns) -> Dict[str, str]:
    """
    Build {old_col: csv_header} dict for DataFrame.rename(columns=...).
    Only renames columns that are in the registry.
    """
    return {c: csv_header(c) for c in columns if c in _REGISTRY}


def friendly_name(key: str) -> str:
    """
    Backward-compatible short label used in console prints and
    feature-importance bar charts.  Equivalent to label(key, 'full').
    """
    return label(key, 'full')


# ══════════════════════════════════════════════════════════════════
#  CONVENIENCE DICTS (drop-in replacements for poster_visualizations.py)
# ══════════════════════════════════════════════════════════════════

COMPONENT_LABELS = {
    k: label(k, 'full') for k in
    ['ta_norm', 'as_norm', 'sr_norm', 'cdr_norm',
     'bh_norm', 'wq_norm', 'la_norm']
}

COMPONENT_COLORS = {
    'ta_norm':  '#D62728',    # Thermal Anomaly – red
    'as_norm':  '#FF7F0E',    # Accumulating Stress – orange
    'sr_norm':  '#9467BD',    # Seasonal Risk – purple
    'cdr_norm': '#1F77B4',    # Climate Drivers – blue
    'bh_norm':  '#8C564B',    # Bleaching History – brown
    'wq_norm':  '#2CA02C',    # Water Quality – green
    'la_norm':  '#E377C2',    # Light Availability – pink
}

WEIGHT_LABELS = {
    k: label(k, 'abbrev') for k in
    ['thermal_anomaly', 'accumulating_stress', 'seasonal_risk',
     'climate_driver', 'bleaching_history', 'water_quality',
     'light_availability']
}

# Weight keys → component column keys (for cross_region.py label lookups)
WEIGHT_KEY_TO_COMPONENT = {
    'thermal_anomaly': 'ta_norm',
    'accumulating_stress': 'as_norm',
    'seasonal_risk': 'sr_norm',
    'climate_driver': 'cdr_norm',
    'bleaching_history': 'bh_norm',
    'water_quality': 'wq_norm',
    'light_availability': 'la_norm',
}