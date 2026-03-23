"""
Global Reef Region Registry for Enhanced-pCRVI
===============================================

Comprehensive region definitions for applying the Enhanced 7-component
Predictive Coral Reef Vulnerability Index (pCRVI) to reefs worldwide.

Regions Included
----------------
**India & Surrounding (5 regions):**
  1. Andaman & Nicobar Islands (reference — defined in config.py as ANIRegion)
  2. Lakshadweep Islands
  3. Gulf of Mannar & Palk Bay
  4. Gulf of Kachchh (Kutch)
  5. Malvan Marine Sanctuary

**Southeast Asia (4 regions):**
  6. Coral Triangle – Indonesia (Raja Ampat & Thousand Islands)
  7. Southwestern Thailand (Andaman Sea)
  8. Philippines (Tubbataha & Coral Triangle)
  9. Malaysia (Sabah & Coral Triangle)

**Global Top-5 Bleaching Hotspots (5 regions):**
  10. Great Barrier Reef, Australia
  11. Florida Reef Tract, USA
  12. Maldives
  13. Seychelles (Inner Islands)
  14. Mesoamerican Barrier Reef (Belize / Mexico)

Data Sources
------------
- MMM SST: NOAA CRW 5 km Regional Virtual Stations (coralreefwatch.noaa.gov)
  Climatological baseline: 1985-2012, centered to 1988.3
  (Liu et al. 2014, Heron et al. 2015)
- Peak bleaching seasons: Heron et al. (2016) Curr. Clim. Change Rep. 2:148-159
- Bleaching events: NOAA GCBE records; peer-reviewed literature as cited
- Bounding boxes: GEE-compatible [lon_min, lat_min, lon_max, lat_max]

Usage
-----
    from coral_ews.reef_regions import REEF_REGISTRY, get_region
    from coral_ews.config import Config
    from coral_ews.enhanced_pcrvi import EnhancedPCRVI

    region = get_region('lakshadweep')
    config = Config()
    config.region = region
    epcrvi = EnhancedPCRVI(
        config=config,
        mmm=region.mmm_sst,
        peak_season_months=region.peak_season_months,
    )

Author: Coral Bleaching EWS Team
Date:   February 2026
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, Optional, Tuple


# ════════════════════════════════════════════════════════════════════════════
# BASE CLASS
# ════════════════════════════════════════════════════════════════════════════

@dataclass
class ReefRegion:
    """
    Base reef region definition compatible with EnhancedPCRVI.

    Every region must supply at minimum:
      - name, bounds, center_lon, center_lat
      - mmm_sst (from NOAA CRW or literature)
      - bleaching_threshold (typically mmm_sst + 1.0)
      - peak_season_months (tuple of 1-indexed month numbers)
      - KNOWN_BLEACHING_EVENTS (dict year → event info)
    """

    name: str = ""
    bounds: Tuple[float, float, float, float] = (0.0, 0.0, 0.0, 0.0)
    center_lon: float = 0.0
    center_lat: float = 0.0
    mmm_sst: float = 29.0
    bleaching_threshold: float = 30.0
    sst_threshold_literature: float = 30.0
    peak_season_months: Tuple[int, ...] = (4, 5, 6)

    # Standard NOAA CRW DHW thresholds; override per-region if calibrated
    # Valid values (from coralreefwatch.noaa.gov/product/5km/):
    #   indian, pacific, caribbean, florida, gbr, triangle, satlantic,
    #   hawaii, tropics, global, east, west
    noaa_basin: str = "indian"

    # Climate driver blend weights for the pCRVI Climate Driver Risk (CDR)
    # component.  Keys are climate index names ('oni', 'dmi', 'amo');
    # values are weights that must sum to 1.0.
    # Default: Indian Ocean blend (ONI 55 / DMI 45) per
    #   van Hooidonk & Huber (2009); Roxy et al. (2011)
    climate_driver_weights: Dict[str, float] = field(default_factory=lambda: {
        'oni': 0.55, 'dmi': 0.45,
    })

    # Standard NOAA CRW DHW thresholds; override per-region if calibrated
    DHW_THRESHOLDS: Dict[str, float] = field(default_factory=lambda: {
        'no_stress': 0.0,
        'watch': 1.0,
        'warning': 4.0,
        'alert_level_1': 8.0,
        'alert_level_2': 12.0,
    })

    KNOWN_BLEACHING_EVENTS: Dict[int, Dict[str, Any]] = field(
        default_factory=dict
    )

    # ── Convenience ─────────────────────────────────────────────────────

    def to_gee_geometry(self) -> str:
        """Return GEE geometry code snippet."""
        return (
            f"ee.Geometry.Rectangle([{self.bounds[0]}, {self.bounds[1]}, "
            f"{self.bounds[2]}, {self.bounds[3]}])"
        )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "name": self.name,
            "bounds": self.bounds,
            "center": (self.center_lon, self.center_lat),
            "mmm_sst": self.mmm_sst,
            "bleaching_threshold": self.bleaching_threshold,
            "peak_season_months": self.peak_season_months,
            "noaa_basin": self.noaa_basin,
            "climate_driver_weights": self.climate_driver_weights,
        }


# ════════════════════════════════════════════════════════════════════════════
# INDIA & SURROUNDING
# ════════════════════════════════════════════════════════════════════════════

@dataclass
class LakshadweepRegion(ReefRegion):
    """
    Lakshadweep Islands – 36 atolls in the Arabian Sea, western India.

    MMM SST: NOAA CRW Virtual Station "Lakshadweep"
             coralreefwatch.noaa.gov/product/vs/gauges/lakshadweep.php
    Bleaching: Arthur (2000); Vinoth et al. (2011); INCOIS reports
    """

    name: str = "Lakshadweep Islands"
    bounds: Tuple[float, float, float, float] = (71.5, 8.0, 74.5, 13.0)
    center_lon: float = 72.75
    center_lat: float = 10.50
    mmm_sst: float = 29.50       # NOAA CRW Virtual Station, warmest month May
    bleaching_threshold: float = 30.50
    sst_threshold_literature: float = 30.5   # Vinoth et al. 2011
    peak_season_months: Tuple[int, ...] = (4, 5, 6)   # April-June (pre-monsoon)

    KNOWN_BLEACHING_EVENTS: Dict[int, Dict[str, Any]] = field(
        default_factory=lambda: {
            1998: {
                'severity': 'catastrophic',
                'dhw_reported': 7.5,
                'bleaching_pct': 82,
                'peak_month': 5,
                'notes': '82% bleaching in lagoon reefs; 26% mortality; strong El Niño',
                'source': 'Arthur (2000) Current Science 79(12):1723-1729',
            },
            2010: {
                'severity': 'severe',
                'dhw_reported': 9.0,
                'bleaching_pct': 75,
                'peak_month': 5,
                'notes': 'Bleaching at Agatti, Kadmat, Kavaratti; SST >31°C for 50+ days',
                'source': 'Vinoth et al. (2011) J Ocean Univ China 10:209-216',
            },
            2016: {
                'severity': 'severe',
                'dhw_reported': 8.8,
                'bleaching_pct': 60,
                'peak_month': 5,
                'notes': 'Third global event; Acropora most affected genus',
                'source': 'Arora et al. (2019) Reg Stud Mar Sci 29:100672',
            },
            2020: {
                'severity': 'moderate',
                'dhw_reported': 5.5,
                'bleaching_pct': 30,
                'peak_month': 5,
                'notes': 'Post-IOD 2019 warm anomaly',
                'source': 'INCOIS coral bleaching alert system',
            },
            2024: {
                'severity': 'severe',
                'dhw_reported': 9.5,
                'bleaching_pct': 70,
                'peak_month': 5,
                'notes': '4th Global Coral Bleaching Event (GCBE4); among most affected in India',
                'source': 'Down to Earth 2024; NOAA CRW GCBE4 report',
            },
        }
    )


@dataclass
class GulfOfMannarRegion(ReefRegion):
    """
    Gulf of Mannar Biosphere Reserve – 21 islands, SE India / Tamil Nadu.

    MMM SST: NOAA CRW, confirmed by INCOIS thermal analysis
    Bleaching: Edward et al. (2008, 2018); Krishnan et al. (2011, 2018)
    """

    name: str = "Gulf of Mannar"
    bounds: Tuple[float, float, float, float] = (78.0, 8.5, 79.5, 10.0)
    center_lon: float = 78.80
    center_lat: float = 9.15
    mmm_sst: float = 29.20       # NOAA CRW; GoM has slightly lower MMM due to upwelling
    bleaching_threshold: float = 30.20
    sst_threshold_literature: float = 31.0   # Edward et al. 2008: 31-33.5°C triggers bleaching
    peak_season_months: Tuple[int, ...] = (4, 5, 6)   # April-June (pre-SW monsoon)

    KNOWN_BLEACHING_EVENTS: Dict[int, Dict[str, Any]] = field(
        default_factory=lambda: {
            1998: {
                'severity': 'catastrophic',
                'dhw_reported': 8.0,
                'bleaching_pct': 89,
                'peak_month': 5,
                'notes': '89% coral cover bleached; 23% mortality; El Niño driven',
                'source': 'Arthur (2000) Current Science 79(12):1723-1729',
            },
            2010: {
                'severity': 'severe',
                'dhw_reported': 10.5,
                'bleaching_pct': 70,
                'peak_month': 5,
                'notes': 'Algal phase shift initiated; SST anomaly persisted 50+ days',
                'source': 'Krishnan et al. (2011); Jeevamani et al. (2013)',
            },
            2016: {
                'severity': 'severe',
                'dhw_reported': 9.2,
                'bleaching_pct': 46,
                'peak_month': 4,
                'notes': '46% GoM, 70% Palk Bay; SST reached 34°C',
                'source': 'Edward et al. (2018); Krishnan et al. (2018)',
            },
            2020: {
                'severity': 'severe',
                'dhw_reported': 7.0,
                'bleaching_pct': 85,
                'peak_month': 5,
                'notes': 'Marine heatwave; 85% bleaching per underwater survey',
                'source': 'Raj et al. (2022) Indo-Pac J Ocean Life 6(2)',
            },
            2024: {
                'severity': 'severe',
                'dhw_reported': 8.5,
                'bleaching_pct': 60,
                'peak_month': 5,
                'notes': 'GCBE4; significant die-off especially Mandapam islands',
                'source': 'Down to Earth May 2024; SDMRI reports',
            },
        }
    )


@dataclass
class GulfOfKachchhRegion(ReefRegion):
    """
    Gulf of Kachchh (Kutch) Marine National Park – Gujarat, NW India.
    Northernmost coral reefs in India; adapted to high turbidity and
    extreme temperature range (20-33°C). More bleaching-resistant.

    MMM SST: NOAA CRW; high due to extreme summer heating in shallow gulf
    Bleaching: Arthur (2000); GEER Foundation monitoring
    """

    name: str = "Gulf of Kachchh"
    bounds: Tuple[float, float, float, float] = (68.5, 22.0, 70.5, 23.5)
    center_lon: float = 69.50
    center_lat: float = 22.60
    mmm_sst: float = 30.10       # Very high MMM due to shallow, enclosed gulf
    bleaching_threshold: float = 31.10
    sst_threshold_literature: float = 33.0   # Higher tolerance — acclimated populations
    peak_season_months: Tuple[int, ...] = (5, 6, 7)   # May-July (delayed summer peak)

    KNOWN_BLEACHING_EVENTS: Dict[int, Dict[str, Any]] = field(
        default_factory=lambda: {
            1998: {
                'severity': 'minor',
                'dhw_reported': 3.0,
                'bleaching_pct': 11,
                'peak_month': 6,
                'notes': 'Only 11% bleaching; no mortality; corals pre-adapted to extremes',
                'source': 'Arthur (2000) Current Science 79(12):1723-1729',
            },
            2010: {
                'severity': 'moderate',
                'dhw_reported': 5.5,
                'bleaching_pct': 25,
                'peak_month': 6,
                'notes': 'Moderate bleaching; Pirotan reef affected; high sedimentation',
                'source': 'GEER Foundation & ZSI monitoring',
            },
            2016: {
                'severity': 'moderate',
                'dhw_reported': 6.0,
                'bleaching_pct': 30,
                'peak_month': 5,
                'notes': 'Third global event; successful Biorock restoration ongoing',
                'source': 'Gujarat Forest Dept & WTI coral recovery project',
            },
            2024: {
                'severity': 'moderate',
                'dhw_reported': 7.0,
                'bleaching_pct': 35,
                'peak_month': 6,
                'notes': 'GCBE4; bleaching observed but lower than other Indian reefs',
                'source': 'Down to Earth 2024',
            },
        }
    )


@dataclass
class MalvanRegion(ReefRegion):
    """
    Malvan Marine Sanctuary – patch reefs off Sindhudurg, Maharashtra.
    Small but ecologically significant; southernmost reef on India's west coast.

    MMM SST: Derived from NOAA OISST for Malvan coast
    """

    name: str = "Malvan Marine Sanctuary"
    bounds: Tuple[float, float, float, float] = (73.2, 15.8, 73.7, 16.2)
    center_lon: float = 73.45
    center_lat: float = 16.05
    mmm_sst: float = 29.30
    bleaching_threshold: float = 30.30
    sst_threshold_literature: float = 30.5
    peak_season_months: Tuple[int, ...] = (4, 5, 6)

    KNOWN_BLEACHING_EVENTS: Dict[int, Dict[str, Any]] = field(
        default_factory=lambda: {
            2016: {
                'severity': 'moderate',
                'dhw_reported': 5.0,
                'bleaching_pct': 35,
                'peak_month': 5,
                'notes': 'First documented bleaching in Malvan; Goniopora affected',
                'source': 'National Centre for Coastal Research (NCCR)',
            },
            2024: {
                'severity': 'moderate',
                'dhw_reported': 6.0,
                'bleaching_pct': 25,
                'peak_month': 5,
                'notes': 'GCBE4; bleaching limited to one species (Goniopora)',
                'source': 'Vision IAS June 2024 report',
            },
        }
    )


# ════════════════════════════════════════════════════════════════════════════
# SOUTHEAST ASIA
# ════════════════════════════════════════════════════════════════════════════

@dataclass
class CoralTriangleIndonesiaRegion(ReefRegion):
    """
    Indonesia – Coral Triangle core (Raja Ampat, Thousand Islands, Sulawesi).
    World's highest coral species diversity (>590 species).

    MMM SST: NOAA CRW Virtual Station composite
    Peak season: April-August (Heron et al. 2016)
    Bleaching: Rudi et al. (2012); Kimura et al. (2018, 2022)
    """

    name: str = "Coral Triangle – Indonesia"
    bounds: Tuple[float, float, float, float] = (95.0, -11.0, 141.0, 6.0)
    center_lon: float = 118.0
    center_lat: float = -2.5
    mmm_sst: float = 29.60       # Regional average; varies ~28.5–30.5 across archipelago
    bleaching_threshold: float = 30.60
    sst_threshold_literature: float = 30.5
    peak_season_months: Tuple[int, ...] = (4, 5, 6, 7, 8)  # Apr-Aug

    # Coral Triangle: NOAA CRW provides dedicated "triangle" basin maps
    noaa_basin: str = "triangle"
    # ENSO dominates; IOD moderate via Walker Circulation changes
    # Ref: Kimura et al. (2018); Heron et al. (2016)
    climate_driver_weights: Dict[str, float] = field(default_factory=lambda: {
        'oni': 0.70, 'dmi': 0.30,
    })

    KNOWN_BLEACHING_EVENTS: Dict[int, Dict[str, Any]] = field(
        default_factory=lambda: {
            1983: {
                'severity': 'severe',
                'dhw_reported': 6.0,
                'bleaching_pct': 50,
                'peak_month': 5,
                'notes': 'First recorded bleaching in Indonesia (Thousand Islands, Jakarta)',
                'source': 'Brown & Suharsono (1990) Coral Reefs 8:163-170',
            },
            1998: {
                'severity': 'catastrophic',
                'dhw_reported': 10.0,
                'bleaching_pct': 90,
                'peak_month': 4,
                'notes': 'Widespread across Indonesia; mass mortality reported',
                'source': 'Wilkinson (2000) GCRMN Status Report',
            },
            2010: {
                'severity': 'severe',
                'dhw_reported': 9.0,
                'bleaching_pct': 60,
                'peak_month': 5,
                'notes': 'Aceh (Sabang) ~60% hard coral mortality',
                'source': 'Rudi et al. (2012)',
            },
            2016: {
                'severity': 'severe',
                'dhw_reported': 8.5,
                'bleaching_pct': 50,
                'peak_month': 5,
                'notes': 'E. Nusa Tenggara & W. Sumatra 30-90% mortality',
                'source': 'Kimura et al. (2018, 2022)',
            },
            2024: {
                'severity': 'moderate',
                'dhw_reported': 8.1,
                'bleaching_pct': 40,
                'peak_month': 6,
                'notes': 'GCBE4; DHW peak 8.1 °C-weeks at Thousand Islands (June)',
                'source': 'Margaritis et al. (2025) Diversity 17(8):540',
            },
        }
    )


@dataclass
class ThailandAndamanSeaRegion(ReefRegion):
    """
    Southwestern Thailand – Andaman Sea side (Phuket, Similan, Surin).
    153 km² of coral reef; strong tourism pressure.

    MMM SST: NOAA CRW Virtual Station "Southwestern Thailand"
    Peak season: April-August (Heron et al. 2016)
    Bleaching: Phongsuwan & Chansang (2012); Yeemin et al. (2012)
    """

    name: str = "Thailand – Andaman Sea"
    bounds: Tuple[float, float, float, float] = (97.5, 6.0, 99.5, 10.0)
    center_lon: float = 98.40
    center_lat: float = 8.00
    mmm_sst: float = 29.80       # NOAA CRW Southwestern Thailand VS
    bleaching_threshold: float = 30.80
    sst_threshold_literature: float = 30.8
    peak_season_months: Tuple[int, ...] = (4, 5, 6, 7)   # Apr-Jul

    KNOWN_BLEACHING_EVENTS: Dict[int, Dict[str, Any]] = field(
        default_factory=lambda: {
            1998: {
                'severity': 'severe',
                'dhw_reported': 8.0,
                'bleaching_pct': 70,
                'peak_month': 5,
                'notes': 'Severe bleaching on Andaman Sea reefs',
                'source': 'Phongsuwan & Chansang (2012)',
            },
            2010: {
                'severity': 'catastrophic',
                'dhw_reported': 14.0,
                'bleaching_pct': 80,
                'peak_month': 5,
                'notes': 'Worst event on record; 80% bleaching in Similan Is.',
                'source': 'Yeemin et al. (2012) Phuket Mar Biol Cent Res Bull 71:75-85',
            },
            2016: {
                'severity': 'moderate',
                'dhw_reported': 6.0,
                'bleaching_pct': 40,
                'peak_month': 5,
                'notes': 'Some resilience observed from 2010 survivors',
                'source': 'DMCR (Dept. of Marine & Coastal Resources) Thailand',
            },
            2024: {
                'severity': 'moderate',
                'dhw_reported': 7.5,
                'bleaching_pct': 45,
                'peak_month': 5,
                'notes': 'GCBE4; Andaman Sea side less affected than Gulf of Thailand',
                'source': 'NOAA CRW GCBE4; DMCR 2024 assessment',
            },
        }
    )


@dataclass
class PhilippinesRegion(ReefRegion):
    """
    Philippines – 2nd largest reef area in Asia (~27,000 km²).
    Coral Triangle hotspot; Tubbataha Reef Natural Park UNESCO site.

    MMM SST: NOAA CRW Virtual Station composite for Philippine Sea
    Peak season: May-August (Heron et al. 2016; Yu et al. 2025 Remote Sensing)
    """

    name: str = "Philippines"
    bounds: Tuple[float, float, float, float] = (116.0, 4.5, 127.0, 21.0)
    center_lon: float = 121.50
    center_lat: float = 12.50
    mmm_sst: float = 29.70       # NOAA CRW; monthly avg SST range 26.6-29.3°C
    bleaching_threshold: float = 30.70
    sst_threshold_literature: float = 30.5
    peak_season_months: Tuple[int, ...] = (5, 6, 7, 8)   # May-Aug

    # Philippines sits in Coral Triangle; ENSO dominant driver
    # Ref: Licuanan et al. (2019); Arceo et al. (2001)
    noaa_basin: str = "triangle"
    climate_driver_weights: Dict[str, float] = field(default_factory=lambda: {
        'oni': 0.75, 'dmi': 0.25,
    })

    KNOWN_BLEACHING_EVENTS: Dict[int, Dict[str, Any]] = field(
        default_factory=lambda: {
            1998: {
                'severity': 'severe',
                'dhw_reported': 9.0,
                'bleaching_pct': 65,
                'peak_month': 7,
                'notes': 'Widespread across Visayas and Palawan',
                'source': 'Arceo et al. (2001); Wilkinson (2000) GCRMN',
            },
            2010: {
                'severity': 'severe',
                'dhw_reported': 10.0,
                'bleaching_pct': 55,
                'peak_month': 6,
                'notes': 'Severe in Bolinao, Batangas; patchy recovery',
                'source': 'Licuanan & Gomez (2012)',
            },
            2016: {
                'severity': 'moderate',
                'dhw_reported': 7.0,
                'bleaching_pct': 40,
                'peak_month': 6,
                'notes': 'Third global event; Tubbataha moderately affected',
                'source': 'Tubbataha Management Office; Reef Check Philippines',
            },
            2024: {
                'severity': 'severe',
                'dhw_reported': 9.5,
                'bleaching_pct': 55,
                'peak_month': 7,
                'notes': 'GCBE4; Lingayen Gulf 293 MHW days in 2022 precursor',
                'source': 'Yu et al. (2025) Remote Sensing 17(6):1048',
            },
        }
    )


@dataclass
class MalaysiaSabahRegion(ReefRegion):
    """
    Malaysia – Sabah / Coral Triangle (Sipadan, Semporna, Tunku Abdul Rahman).

    MMM SST: NOAA CRW Virtual Station "Sabah"
    """

    name: str = "Malaysia – Sabah"
    bounds: Tuple[float, float, float, float] = (115.5, 4.0, 119.5, 8.0)
    center_lon: float = 117.50
    center_lat: float = 6.00
    mmm_sst: float = 29.50
    bleaching_threshold: float = 30.50
    sst_threshold_literature: float = 30.5
    peak_season_months: Tuple[int, ...] = (4, 5, 6, 7)   # Apr-Jul

    # Malaysia Sabah (Coral Triangle edge, Sulu-Sulawesi Sea)
    # Ref: Tanzil et al. (2013); Reef Check Malaysia
    noaa_basin: str = "triangle"
    climate_driver_weights: Dict[str, float] = field(default_factory=lambda: {
        'oni': 0.70, 'dmi': 0.30,
    })

    KNOWN_BLEACHING_EVENTS: Dict[int, Dict[str, Any]] = field(
        default_factory=lambda: {
            1998: {
                'severity': 'severe',
                'dhw_reported': 8.5,
                'bleaching_pct': 70,
                'peak_month': 5,
                'notes': 'Severe across Semporna; Sipadan reef severely affected',
                'source': 'Wilkinson (2000) GCRMN Status Report',
            },
            2010: {
                'severity': 'severe',
                'dhw_reported': 8.0,
                'bleaching_pct': 50,
                'peak_month': 5,
                'notes': 'Extensive bleaching in Tunku Abdul Rahman Marine Park',
                'source': 'Reef Check Malaysia 2010 report',
            },
            2016: {
                'severity': 'moderate',
                'dhw_reported': 6.0,
                'bleaching_pct': 35,
                'peak_month': 5,
                'notes': 'Third global event; moderate impacts',
                'source': 'Reef Check Malaysia; NOAA CRW',
            },
        }
    )


# ════════════════════════════════════════════════════════════════════════════
# GLOBAL TOP-5 BLEACHING HOTSPOTS
# ════════════════════════════════════════════════════════════════════════════

@dataclass
class GreatBarrierReefRegion(ReefRegion):
    """
    Great Barrier Reef, Australia – World's largest coral reef system
    (~2,300 km, 344,400 km²). UNESCO World Heritage Site.
    Six mass bleaching events: 1998, 2002, 2016, 2017, 2020, 2022, 2024.

    MMM SST: NOAA CRW Virtual Station — varies ~27-29°C along 2,300 km
    Peak season: February-April (Southern Hemisphere summer)
    References: Hughes et al. (2017) Nature 543; (2018) Nature 556
    """

    name: str = "Great Barrier Reef"
    bounds: Tuple[float, float, float, float] = (142.0, -24.5, 154.0, -10.0)
    center_lon: float = 148.0
    center_lat: float = -17.25
    mmm_sst: float = 27.80       # Northern GBR representative (varies 27-29 along reef)
    bleaching_threshold: float = 28.80
    sst_threshold_literature: float = 29.0
    peak_season_months: Tuple[int, ...] = (1, 2, 3, 4)   # Jan-Apr (SH summer)

    # GBR: NOAA CRW provides dedicated 'gbr' basin maps
    # ENSO is dominant but acts through local meteorology (McGowan et al. 2017 GRL).
    # PDO modulates bleaching decades (Roff et al. 2020 Sci Rep).
    # DMI (IOD) has minimal direct influence on Coral Sea SST.
    noaa_basin: str = "gbr"
    climate_driver_weights: Dict[str, float] = field(default_factory=lambda: {
        'oni': 0.85, 'dmi': 0.15,
    })

    KNOWN_BLEACHING_EVENTS: Dict[int, Dict[str, Any]] = field(
        default_factory=lambda: {
            1998: {
                'severity': 'severe',
                'dhw_reported': 8.0,
                'bleaching_pct': 42,
                'peak_month': 2,
                'notes': 'First mass bleaching on GBR; northern reefs most affected',
                'source': 'Berkelmans & Oliver (1999) Coral Reefs 18:55-60',
            },
            2002: {
                'severity': 'severe',
                'dhw_reported': 7.5,
                'bleaching_pct': 54,
                'peak_month': 2,
                'notes': 'More extensive than 1998; both inshore and offshore reefs',
                'source': 'Berkelmans et al. (2004) Coral Reefs 23:74-83',
            },
            2016: {
                'severity': 'catastrophic',
                'dhw_reported': 12.0,
                'bleaching_pct': 93,
                'peak_month': 3,
                'notes': 'Worst on record; 93% reefs bleached; mass mortality in north',
                'source': 'Hughes et al. (2017) Nature 543:373-377',
            },
            2017: {
                'severity': 'catastrophic',
                'dhw_reported': 9.0,
                'bleaching_pct': 89,
                'peak_month': 3,
                'notes': 'Back-to-back with 2016; central GBR most affected',
                'source': 'Hughes et al. (2018) Nature 556:492-496',
            },
            2020: {
                'severity': 'severe',
                'dhw_reported': 8.5,
                'bleaching_pct': 60,
                'peak_month': 2,
                'notes': 'First bleaching during La Niña; most extensive heat stress',
                'source': 'Hughes et al. (2021) Current Biology 31(19)',
            },
            2022: {
                'severity': 'severe',
                'dhw_reported': 9.5,
                'bleaching_pct': 91,
                'peak_month': 3,
                'notes': '6th mass event; unprecedented early-summer onset; La Niña',
                'source': 'AIMS LTMP 2022; Bainbridge et al. (2022) PMC9652503',
            },
            2024: {
                'severity': 'severe',
                'dhw_reported': 10.0,
                'bleaching_pct': 73,
                'peak_month': 2,
                'notes': 'GCBE4; 7th mass event; widespread across all sectors',
                'source': 'GBRMPA aerial surveys Feb-Apr 2024; NOAA CRW',
            },
        }
    )


@dataclass
class FloridaReefTractRegion(ReefRegion):
    """
    Florida Reef Tract, USA – 3rd largest barrier reef (~580 km).
    Includes Florida Keys, Dry Tortugas, SE Florida coast.

    MMM SST: NOAA CRW Virtual Station "Florida Keys"
    Peak season: August-October (NH summer / hurricane season)
    References: Manzello et al. (2007); Eakin et al. (2010)
    """

    name: str = "Florida Reef Tract"
    bounds: Tuple[float, float, float, float] = (-83.0, 24.0, -79.5, 27.0)
    center_lon: float = -81.25
    center_lat: float = 25.50
    mmm_sst: float = 29.30       # NOAA CRW Florida Keys VS
    bleaching_threshold: float = 30.30
    sst_threshold_literature: float = 30.5
    peak_season_months: Tuple[int, ...] = (7, 8, 9, 10)   # Jul-Oct

    # Florida: NOAA CRW provides dedicated 'florida' basin maps
    # Atlantic Multidecadal Oscillation (AMO) is the dominant secondary driver.
    # 2005 Caribbean bleaching was AMO+phase-driven, weak ENSO connection.
    # Ref: Manzello (2015) J Geophys Res Oceans; Eakin et al. (2010)
    noaa_basin: str = "florida"
    climate_driver_weights: Dict[str, float] = field(default_factory=lambda: {
        'oni': 0.60, 'amo': 0.40,
    })

    KNOWN_BLEACHING_EVENTS: Dict[int, Dict[str, Any]] = field(
        default_factory=lambda: {
            1998: {
                'severity': 'severe',
                'dhw_reported': 8.5,
                'bleaching_pct': 50,
                'peak_month': 9,
                'notes': 'Widespread Keys bleaching; first major event',
                'source': 'Causey (2001) NOAA FKNMS',
            },
            2005: {
                'severity': 'severe',
                'dhw_reported': 10.0,
                'bleaching_pct': 55,
                'peak_month': 9,
                'notes': 'Caribbean-wide event; record Atlantic SSTs',
                'source': 'Eakin et al. (2010) PLoS ONE 5(11):e13969',
            },
            2014: {
                'severity': 'moderate',
                'dhw_reported': 5.0,
                'bleaching_pct': 35,
                'peak_month': 10,
                'notes': 'Third global event onset in Florida',
                'source': 'NOAA CRCP Mission: Iconic Reefs',
            },
            2023: {
                'severity': 'catastrophic',
                'dhw_reported': 20.0,
                'bleaching_pct': 95,
                'peak_month': 8,
                'notes': 'Unprecedented marine heatwave; SST >38°C; DHW ~20; '
                         'nurseries relocated to deeper waters',
                'source': 'NOAA CRW; Manzello et al. (2024); GCBE4 announcement',
            },
            2024: {
                'severity': 'severe',
                'dhw_reported': 12.0,
                'bleaching_pct': 65,
                'peak_month': 8,
                'notes': 'GCBE4 continuation; heat-driven functional extinction of Acropora',
                'source': 'NOAA CRW 2025 Science paper',
            },
        }
    )


@dataclass
class MaldivesRegion(ReefRegion):
    """
    Maldives – 1,192 coral islands across 26 atolls, Indian Ocean.

    MMM SST: NOAA CRW Virtual Station "Maldives"
    Peak season: April-May (inter-monsoon) and November (NE monsoon onset)
    References: Morri et al. (2015); Perry & Morgan (2017)
    """

    name: str = "Maldives"
    bounds: Tuple[float, float, float, float] = (72.0, -1.0, 74.0, 8.0)
    center_lon: float = 73.00
    center_lat: float = 3.50
    mmm_sst: float = 29.50       # NOAA CRW Maldives VS
    bleaching_threshold: float = 30.50
    sst_threshold_literature: float = 30.5
    peak_season_months: Tuple[int, ...] = (3, 4, 5)   # Mar-May (inter-monsoon)

    KNOWN_BLEACHING_EVENTS: Dict[int, Dict[str, Any]] = field(
        default_factory=lambda: {
            1998: {
                'severity': 'catastrophic',
                'dhw_reported': 12.0,
                'bleaching_pct': 90,
                'peak_month': 5,
                'notes': 'Up to 90% bleaching; estimated 60% mortality nationwide',
                'source': 'McClanahan (2000) Conserv Biol 14(5):1547-1549',
            },
            2016: {
                'severity': 'severe',
                'dhw_reported': 10.0,
                'bleaching_pct': 73,
                'peak_month': 5,
                'notes': '73% bleaching; significant Acropora loss',
                'source': 'Perry & Morgan (2017) Sci Rep 7:40581',
            },
            2020: {
                'severity': 'moderate',
                'dhw_reported': 5.0,
                'bleaching_pct': 30,
                'peak_month': 4,
                'notes': 'Moderate; post-IOD warm anomaly',
                'source': 'Maldives Marine Research Institute',
            },
            2024: {
                'severity': 'severe',
                'dhw_reported': 9.0,
                'bleaching_pct': 65,
                'peak_month': 4,
                'notes': 'GCBE4; severe bleaching confirmed across multiple atolls',
                'source': 'NOAA CRW GCBE4 report; Maldives EPA',
            },
        }
    )


@dataclass
class SeychellesRegion(ReefRegion):
    """
    Seychelles – Inner granitic islands, western Indian Ocean.

    MMM SST: NOAA CRW Virtual Station "Seychelles"
    Peak season: March-May (inter-monsoon period)
    References: Graham et al. (2015) Current Biology; Wilson et al. (2012)
    """

    name: str = "Seychelles"
    bounds: Tuple[float, float, float, float] = (55.0, -5.0, 57.0, -3.5)
    center_lon: float = 55.50
    center_lat: float = -4.70
    mmm_sst: float = 29.20       # NOAA CRW Seychelles VS
    bleaching_threshold: float = 30.20
    sst_threshold_literature: float = 30.0
    peak_season_months: Tuple[int, ...] = (3, 4, 5)   # Mar-May

    KNOWN_BLEACHING_EVENTS: Dict[int, Dict[str, Any]] = field(
        default_factory=lambda: {
            1998: {
                'severity': 'catastrophic',
                'dhw_reported': 15.0,
                'bleaching_pct': 95,
                'peak_month': 4,
                'notes': '>90% bleaching; ~50% mortality; regime shift on some reefs',
                'source': 'Goreau et al. (2000); Graham et al. (2015) Curr Biol',
            },
            2016: {
                'severity': 'severe',
                'dhw_reported': 10.0,
                'bleaching_pct': 70,
                'peak_month': 4,
                'notes': 'Third global event; ~70% bleaching across inner islands',
                'source': 'Wilson et al. (2019) Coral Reefs 38:437-449',
            },
            2024: {
                'severity': 'severe',
                'dhw_reported': 9.5,
                'bleaching_pct': 60,
                'peak_month': 4,
                'notes': 'GCBE4; confirmed by NOAA; widespread in inner islands',
                'source': 'NOAA CRW GCBE4 confirmation April 2024',
            },
        }
    )


@dataclass
class MesoamericanBarrierReefRegion(ReefRegion):
    """
    Mesoamerican Barrier Reef System – 2nd largest barrier reef (>1,000 km).
    Spans Mexico (Quintana Roo), Belize, Guatemala, Honduras.

    MMM SST: NOAA CRW Virtual Station composite
    Peak season: August-October (NH summer / hurricane season)
    References: Eakin et al. (2010); McField (2017)
    """

    name: str = "Mesoamerican Barrier Reef"
    bounds: Tuple[float, float, float, float] = (-89.5, 15.5, -86.0, 21.5)
    center_lon: float = -87.50
    center_lat: float = 18.50
    mmm_sst: float = 29.40       # NOAA CRW Belize VS
    bleaching_threshold: float = 30.40
    sst_threshold_literature: float = 30.0
    peak_season_months: Tuple[int, ...] = (8, 9, 10)   # Aug-Oct

    # Caribbean: NOAA CRW 'caribbean' basin maps
    # AMO is the dominant secondary driver for Caribbean bleaching.
    # 2005 Caribbean bleaching (worst on record pre-2023) was AMO+phase, not ENSO.
    # Ref: Eakin et al. (2010) PLoS ONE 5(11):e13969; McField (2017)
    noaa_basin: str = "caribbean"
    climate_driver_weights: Dict[str, float] = field(default_factory=lambda: {
        'oni': 0.45, 'amo': 0.55,
    })

    KNOWN_BLEACHING_EVENTS: Dict[int, Dict[str, Any]] = field(
        default_factory=lambda: {
            1998: {
                'severity': 'severe',
                'dhw_reported': 9.0,
                'bleaching_pct': 75,
                'peak_month': 9,
                'notes': 'Major Caribbean-wide event; Belize and Honduras hardest hit',
                'source': 'Aronson et al. (2002) Nature 405:36-38',
            },
            2005: {
                'severity': 'catastrophic',
                'dhw_reported': 12.0,
                'bleaching_pct': 80,
                'peak_month': 10,
                'notes': 'Most destructive Caribbean event to date; record Atlantic SST',
                'source': 'Eakin et al. (2010) PLoS ONE 5(11):e13969',
            },
            2010: {
                'severity': 'moderate',
                'dhw_reported': 6.5,
                'bleaching_pct': 40,
                'peak_month': 9,
                'notes': 'Moderate bleaching; cold water anomalies helped some reefs',
                'source': 'McField (2012) Healthy Reefs Report Card',
            },
            2016: {
                'severity': 'moderate',
                'dhw_reported': 7.0,
                'bleaching_pct': 35,
                'peak_month': 9,
                'notes': 'Third global event; less severe than 2005 for this system',
                'source': 'Healthy Reefs Initiative 2016',
            },
            2023: {
                'severity': 'severe',
                'dhw_reported': 12.0,
                'bleaching_pct': 70,
                'peak_month': 9,
                'notes': 'Record marine heatwave across Caribbean',
                'source': 'NOAA CRW; Healthy Reefs Initiative 2023',
            },
        }
    )


# ════════════════════════════════════════════════════════════════════════════
# REGISTRY & HELPER FUNCTIONS
# ════════════════════════════════════════════════════════════════════════════

# Complete registry — maps short keys → region class instances
REEF_REGISTRY: Dict[str, ReefRegion] = {
    # India
    'lakshadweep':        LakshadweepRegion(),
    'gulf_of_mannar':     GulfOfMannarRegion(),
    'gulf_of_kachchh':    GulfOfKachchhRegion(),
    'malvan':             MalvanRegion(),
    # Southeast Asia
    'indonesia':          CoralTriangleIndonesiaRegion(),
    'thailand_andaman':   ThailandAndamanSeaRegion(),
    'philippines':        PhilippinesRegion(),
    'malaysia_sabah':     MalaysiaSabahRegion(),
    # Global top-5 bleaching hotspots
    'great_barrier_reef': GreatBarrierReefRegion(),
    'florida':            FloridaReefTractRegion(),
    'maldives':           MaldivesRegion(),
    'seychelles':         SeychellesRegion(),
    'mesoamerican':       MesoamericanBarrierReefRegion(),
}

# Aliases for convenience
_ALIASES: Dict[str, str] = {
    'lak': 'lakshadweep',
    'gom': 'gulf_of_mannar',
    'mannar': 'gulf_of_mannar',
    'palk_bay': 'gulf_of_mannar',         # covered by same bounding box
    'gok': 'gulf_of_kachchh',
    'kutch': 'gulf_of_kachchh',
    'kachchh': 'gulf_of_kachchh',
    'coral_triangle': 'indonesia',
    'raja_ampat': 'indonesia',
    'thousand_islands': 'indonesia',
    'thailand': 'thailand_andaman',
    'phuket': 'thailand_andaman',
    'similan': 'thailand_andaman',
    'sabah': 'malaysia_sabah',
    'sipadan': 'malaysia_sabah',
    'gbr': 'great_barrier_reef',
    'australia': 'great_barrier_reef',
    'florida_keys': 'florida',
    'keys': 'florida',
    'belize': 'mesoamerican',
    'caribbean': 'mesoamerican',
}


def get_region(key: str) -> ReefRegion:
    """
    Look up a reef region by name or alias.

    Parameters
    ----------
    key : str
        Region identifier (case-insensitive). Accepts both canonical keys
        (e.g. 'lakshadweep') and aliases (e.g. 'gbr', 'gom', 'kutch').

    Returns
    -------
    ReefRegion
        Dataclass instance ready to pass to Config or EnhancedPCRVI.

    Raises
    ------
    KeyError
        If key is not found in registry or aliases.

    Examples
    --------
    >>> region = get_region('gbr')
    >>> print(region.name, region.mmm_sst)
    Great Barrier Reef 27.8

    >>> region = get_region('lakshadweep')
    >>> epcrvi = EnhancedPCRVI(mmm=region.mmm_sst,
    ...     peak_season_months=region.peak_season_months)
    """
    k = key.strip().lower().replace(' ', '_').replace('-', '_')

    # Direct match
    if k in REEF_REGISTRY:
        return REEF_REGISTRY[k]

    # Alias match
    if k in _ALIASES:
        return REEF_REGISTRY[_ALIASES[k]]

    available = sorted(set(list(REEF_REGISTRY.keys()) + list(_ALIASES.keys())))
    raise KeyError(
        f"Unknown reef region '{key}'. Available keys: {available}"
    )


def list_regions() -> Dict[str, str]:
    """Return dict of {key: region_name} for all registered regions."""
    return {k: v.name for k, v in REEF_REGISTRY.items()}


def list_indian_regions() -> Dict[str, str]:
    """Return only Indian reef regions."""
    indian_keys = ['lakshadweep', 'gulf_of_mannar', 'gulf_of_kachchh', 'malvan']
    return {k: REEF_REGISTRY[k].name for k in indian_keys}


def list_southeast_asian_regions() -> Dict[str, str]:
    """Return only SE Asian reef regions."""
    sea_keys = ['indonesia', 'thailand_andaman', 'philippines', 'malaysia_sabah']
    return {k: REEF_REGISTRY[k].name for k in sea_keys}


def list_global_hotspots() -> Dict[str, str]:
    """Return the top-5 global bleaching hotspot regions."""
    global_keys = ['great_barrier_reef', 'florida', 'maldives',
                   'seychelles', 'mesoamerican']
    return {k: REEF_REGISTRY[k].name for k in global_keys}
