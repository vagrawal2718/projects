"""
Cross-Region Comparison Module
================================

Contains RegionResult dataclass, summary/metrics table builders, 
cross-region comparison plots, and the extract_region_result helper
that pulls results from a completed CoralBleachingEWS pipeline.

Extracted from run_regions.py to be importable by the main CLI.

Place this file at:  coral_ews/cross_region.py
"""
from __future__ import annotations

import json
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional, TYPE_CHECKING

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from matplotlib.patches import Patch
import numpy as np
import pandas as pd

from .reef_regions import (
    list_indian_regions, list_southeast_asian_regions, list_global_hotspots,
)
from .naming import COMPONENT_LABELS, WEIGHT_KEY_TO_COMPONENT


if TYPE_CHECKING:
    from .pipeline import CoralBleachingEWS

# ═══════════════════════════════════════════════════════════════════════
# COLOUR / ABBREVIATION HELPERS  (unchanged from run_regions.py)
# ═══════════════════════════════════════════════════════════════════════
_INDIA_KEYS  = set(list_indian_regions().keys()) | {'andaman'}
_SEA_KEYS    = set(list_southeast_asian_regions().keys())
_GLOBAL_KEYS = set(list_global_hotspots().keys())

def _rc(key):
    if key in _INDIA_KEYS:  return '#D62728'
    if key in _SEA_KEYS:    return '#FF7F0E'
    if key in _GLOBAL_KEYS: return '#1F77B4'
    return '#2CA02C'

_CC = {
    'thermal_anomaly':'#E74C3C','accumulating_stress':'#FF8C00',
    'seasonal_risk':'#F1C40F','climate_driver':'#27AE60',
    'bleaching_history':'#3498DB','water_quality':'#8E44AD',
    'light_availability':'#1ABC9C',
}

def _ab(name):
    return {
        'Lakshadweep Islands':'Lakshadweep','Gulf of Mannar':'G. Mannar',
        'Gulf of Kachchh':'G. Kachchh','Malvan Marine Sanctuary':'Malvan',
        'Coral Triangle \u2013 Indonesia':'Coral Tri.',
        'Thailand \u2013 Andaman Sea':'Thailand','Malaysia \u2013 Sabah':'Sabah',
        'Great Barrier Reef':'GBR','Florida Reef Tract':'Florida',
        'Mesoamerican Barrier Reef':'Mesoamerican',
        'Andaman & Nicobar Islands':'Andaman',
        'Andaman & Nicobar':'Andaman',
    }.get(name, name)

_LEG = [
    Patch(fc='#D62728', ec='k', lw=.4, label='India'),
    Patch(fc='#FF7F0E', ec='k', lw=.4, label='SE Asia'),
    Patch(fc='#1F77B4', ec='k', lw=.4, label='Global'),
]


# ═══════════════════════════════════════════════════════════════════════
# RESULT CONTAINER
# ═══════════════════════════════════════════════════════════════════════
@dataclass
class RegionResult:
    key: str; name: str; mmm_sst: float; peak_season: tuple
    n_known_events: int; n_days: int = 0
    optimal_threshold: float = 0.0; optimal_f1: float = 0.0
    precision: float = 0.0; recall: float = 0.0; f1: float = 0.0
    far: float = 0.0; pofd: float = 0.0; pss: float = 0.0
    hss: float = 0.0; mcc: float = 0.0; csi: float = 0.0
    freq_bias: float = 0.0; correlation: float = 0.0
    tp: int = 0; fp: int = 0; fn: int = 0; tn: int = 0
    events_detected: int = 0; events_total: int = 0
    event_detection_rate: float = 0.0; mean_lead_days: float = 0.0
    pcrvi_mean: float = 0.0; pcrvi_max: float = 0.0
    pcrvi_p10: float = 0.0; pcrvi_dynamic_range: float = 0.0
    ev_mean: float = 0.0; ev_max: float = 0.0
    sst_sd_mean: float = 0.0; sst_sd_max: float = 0.0
    pct_days_2sd: float = 0.0; pct_days_3sd: float = 0.0
    max_concurrent_extremes: int = 0
    data_source: str = 'pipeline'
    ml_r2: float = 0.0; ml_top_comp: str = ''; ml_top_weight: float = 0.0
    ml_weights: Dict[str, float] = field(default_factory=dict)
    expert_weights: Dict[str, float] = field(default_factory=dict)
    roc_thresholds: List[float] = field(default_factory=list)
    roc_tpr: List[float] = field(default_factory=list)
    roc_fpr: List[float] = field(default_factory=list)
    thresh_sweep: Dict[str, Dict] = field(default_factory=dict)
    runtime_s: float = 0.0


# ═══════════════════════════════════════════════════════════════════════
# EXTRACT RESULT FROM COMPLETED PIPELINE
# ═══════════════════════════════════════════════════════════════════════
def extract_region_result(
    ews: 'CoralBleachingEWS',
    region_key: str,
    runtime_s: float,
) -> RegionResult:
    """
    Build a RegionResult from a completed CoralBleachingEWS pipeline run.

    This replaces the old run_single_region() which bypassed the pipeline.
    """
    from .enhanced_pcrvi import EnhancedPCRVI

    region = ews.config.region
    ts = getattr(ews, '_enhanced_pcrvi_ts', None)
    if ts is None:
        ts = pd.DataFrame()
    skill = getattr(ews, '_enhanced_pcrvi_skill', None)
    if skill is None:
        skill = {}
    ml = getattr(ews, '_ml_weight_results', None)
    if ml is None:
        ml = {}

    opt_thresh = skill.get('optimal_threshold', 0.5)

    # Event-level detection
    detected, lead_list = 0, []
    for yr, ev in region.KNOWN_BLEACHING_EVENTS.items():
        pk = ev.get('peak_month',
                     region.peak_season_months[len(region.peak_season_months)//2])
        try:
            ws = pd.Timestamp(f'{yr}-{max(1, pk-3):02d}-01')
            we = pd.Timestamp(f'{yr}-{pk:02d}-28')
        except Exception:
            continue
        if ts.empty:
            continue
        w = ts.loc[str(ws):str(we)]
        if not w.empty and w['pcrvi'].max() >= opt_thresh:
            detected += 1
            cross = w[w['pcrvi'] >= opt_thresh].index[0]
            lead_list.append(max(0, (we - cross).days))

    lead_30 = skill.get('lead_time_analysis', {}).get('30_days', {})
    td = skill.get('threshold_analysis', {})
    opt_key = f'{opt_thresh:.2f}'
    om = td.get(opt_key, {})

    roc_ths, roc_tpr, roc_fpr = [], [], []
    for tk in sorted(td.keys(), key=float):
        roc_ths.append(float(tk))
        roc_tpr.append(td[tk].get('recall', 0))
        roc_fpr.append(td[tk].get('pofd', 0))

    ml_w = ml.get('ml_weights', {})
    top_c = max(ml_w, key=ml_w.get) if ml_w else ''
    total = len(region.KNOWN_BLEACHING_EVENTS)

    return RegionResult(
        key=region_key, name=region.name, mmm_sst=region.mmm_sst,
        peak_season=region.peak_season_months,
        n_known_events=total, n_days=len(ts),
        optimal_threshold=opt_thresh,
        optimal_f1=skill.get('optimal_f1', 0),
        precision=om.get('precision', lead_30.get('precision', 0)),
        recall=om.get('recall', lead_30.get('recall', 0)),
        f1=om.get('f1_score', skill.get('optimal_f1', 0)),
        far=om.get('false_alarm_ratio', 0), pofd=om.get('pofd', 0),
        pss=om.get('pss', lead_30.get('peirce_skill_score', 0)),
        hss=om.get('hss', lead_30.get('heidke_skill_score', 0)),
        mcc=om.get('mcc', lead_30.get('mcc', 0)),
        csi=om.get('csi', lead_30.get('critical_success_index', 0)),
        freq_bias=om.get('frequency_bias', lead_30.get('frequency_bias', 0)),
        correlation=lead_30.get('correlation', 0),
        tp=lead_30.get('tp', 0), fp=lead_30.get('fp', 0),
        fn=lead_30.get('fn', 0), tn=lead_30.get('tn', 0),
        events_detected=detected, events_total=total,
        event_detection_rate=detected / total if total > 0 else 0,
        mean_lead_days=float(np.mean(lead_list)) if lead_list else 0,
        pcrvi_mean=float(ts['pcrvi'].mean()) if len(ts) else 0,
        pcrvi_max=float(ts['pcrvi'].max()) if len(ts) else 0,
        pcrvi_p10=float(ts['pcrvi'].quantile(.10)) if len(ts) else 0,
        pcrvi_dynamic_range=(
            float(ts['pcrvi'].max() - ts['pcrvi'].quantile(.10))
            if len(ts) else 0),
        ev_mean=float(ts['ev_score'].mean()) if 'ev_score' in ts.columns else 0,
        ev_max=float(ts['ev_score'].max()) if 'ev_score' in ts.columns else 0,
        sst_sd_mean=(float(ts['sst_rolling_sd_30d'].mean())
                     if 'sst_rolling_sd_30d' in ts.columns else 0),
        sst_sd_max=(float(ts['sst_rolling_sd_30d'].max())
                    if 'sst_rolling_sd_30d' in ts.columns else 0),
        pct_days_2sd=(float(ts['sst_exceed_2sd'].mean() * 100)
                      if 'sst_exceed_2sd' in ts.columns else 0),
        pct_days_3sd=(float(ts['sst_exceed_3sd'].mean() * 100)
                      if 'sst_exceed_3sd' in ts.columns else 0),
        max_concurrent_extremes=(int(ts['n_concurrent_extremes'].max())
                                 if 'n_concurrent_extremes' in ts.columns else 0),
        data_source='pipeline',
        ml_r2=ml.get('model_metrics', {}).get('r2', 0),
        ml_top_comp=top_c, ml_top_weight=ml_w.get(top_c, 0),
        ml_weights=ml_w,
        expert_weights=dict(EnhancedPCRVI().weights),
        roc_thresholds=roc_ths, roc_tpr=roc_tpr, roc_fpr=roc_fpr,
        thresh_sweep={k: v for k, v in td.items()},
        runtime_s=round(runtime_s, 1),
    )


# ═══════════════════════════════════════════════════════════════════════
# TABLE BUILDERS
# ═══════════════════════════════════════════════════════════════════════
def build_summary_df(results: List[RegionResult]) -> pd.DataFrame:
    return pd.DataFrame([dict(
        Region=r.name, Key=r.key, MMM=r.mmm_sst,
        N_Events=r.n_known_events, Detected=r.events_detected,
        Detect_Rate=r.event_detection_rate, Lead_Days=r.mean_lead_days,
        Opt_Thresh=r.optimal_threshold,
    ) for r in results])


def build_metrics_df(results: List[RegionResult]) -> pd.DataFrame:
    return pd.DataFrame([dict(
        Region=r.name, Key=r.key, Data_Source=r.data_source,
        Event_Det=r.event_detection_rate,
        Lead_d=r.mean_lead_days, Thresh=r.optimal_threshold,
        Precision=r.precision, Recall_POD=r.recall, F1=r.f1,
        FAR=r.far, POFD=r.pofd, PSS_TSS=r.pss, HSS=r.hss,
        MCC=r.mcc, CSI=r.csi, Freq_Bias=r.freq_bias,
        Correlation=r.correlation, Dyn_Range=r.pcrvi_dynamic_range,
        EV_Mean=r.ev_mean, EV_Max=r.ev_max,
        SST_SD_Mean=r.sst_sd_mean, SST_SD_Max=r.sst_sd_max,
        Pct_Days_2SD=r.pct_days_2sd, Pct_Days_3SD=r.pct_days_3sd,
        Max_Concurrent_Extremes=r.max_concurrent_extremes,
        ML_R2=r.ml_r2, ML_Top=r.ml_top_comp,
    ) for r in results])


# ═══════════════════════════════════════════════════════════════════════
# 8 CROSS-REGION PLOTS  (unchanged logic from run_regions.py)
# ═══════════════════════════════════════════════════════════════════════
def plot_detection_f1_lead(R, od):
    fig, axes = plt.subplots(1, 3, figsize=(16, .5*len(R)+2))
    nm = [_ab(r.name) for r in R]; cl = [_rc(r.key) for r in R]; y = np.arange(len(R))
    ax = axes[0]; v = [r.event_detection_rate*100 for r in R]
    bars = ax.barh(y, v, color=cl, ec='k', lw=.4, height=.6)
    for b, val in zip(bars, v):
        ax.text(min(b.get_width()+1, 102), b.get_y()+b.get_height()/2,
                f'{val:.0f}%', va='center', fontsize=8)
    ax.axvline(80, color='gray', ls='--', lw=.8, alpha=.4); ax.set_xlim(0, 112)
    ax.set_yticks(y); ax.set_yticklabels(nm, fontsize=9)
    ax.set_xlabel('Event Detection Rate (%)')
    ax.set_title('A.  Bleaching Event Detection', fontweight='bold')
    ax = axes[1]; v = [r.f1 for r in R]
    bars = ax.barh(y, v, color=cl, ec='k', lw=.4, height=.6)
    for b, val in zip(bars, v):
        ax.text(b.get_width()+.01, b.get_y()+b.get_height()/2,
                f'{val:.2f}', va='center', fontsize=8)
    ax.set_xlim(0, 1); ax.set_yticks(y); ax.set_yticklabels(nm, fontsize=9)
    ax.set_xlabel('F1 Score (optimal threshold)')
    ax.set_title('B.  Day-Level F1', fontweight='bold')
    ax = axes[2]; v = [r.mean_lead_days for r in R]
    bars = ax.barh(y, v, color=cl, ec='k', lw=.4, height=.6)
    for b, val in zip(ax.patches, v):
        if val > 0:
            ax.text(b.get_width()+.5, b.get_y()+b.get_height()/2,
                    f'{val:.0f}d', va='center', fontsize=8)
    ax.set_yticks(y); ax.set_yticklabels(nm, fontsize=9)
    ax.set_xlabel('Mean Lead Time (days)')
    ax.set_title('C.  Early Warning Lead Time', fontweight='bold')
    fig.legend(handles=_LEG, loc='lower center', ncol=3, fontsize=9, frameon=True)
    fig.suptitle('Enhanced-pCRVI: Cross-Region Detection Performance',
                 fontsize=13, fontweight='bold')
    fig.tight_layout(rect=[0, .06, 1, .94])
    p = od / 'fig_detection_f1_lead.png'
    fig.savefig(p, dpi=200, bbox_inches='tight', facecolor='white')
    plt.close(fig)
    return p


def plot_signal(R, od):
    fig, axes = plt.subplots(1, 3, figsize=(16, .5*len(R)+2))
    nm = [_ab(r.name) for r in R]; cl = [_rc(r.key) for r in R]; y = np.arange(len(R))
    ax = axes[0]
    bases = [r.pcrvi_p10 for r in R]; drs = [r.pcrvi_dynamic_range for r in R]
    ax.barh(y, bases, height=.6, color='#D5DBDB', ec='k', lw=.4, label='Baseline (P10)')
    ax.barh(y, drs, left=bases, height=.6, color=cl, ec='k', lw=.4, label='Dynamic range')
    for i in range(len(R)):
        ax.text(bases[i]+drs[i]+.01, y[i], f'{drs[i]:.2f}', va='center', fontsize=7.5)
    ax.set_yticks(y); ax.set_yticklabels(nm, fontsize=9); ax.set_xlabel('pCRVI')
    ax.legend(fontsize=7, loc='lower right')
    ax.set_title('A.  Baseline & Dynamic Range', fontweight='bold')
    ax = axes[1]; v = [r.optimal_threshold for r in R]
    ax.barh(y, v, height=.6, color=cl, ec='k', lw=.4)
    for i, val in enumerate(v):
        ax.text(val+.01, y[i], f'{val:.2f}', va='center', fontsize=8)
    ax.set_yticks(y); ax.set_yticklabels(nm, fontsize=9)
    ax.set_xlabel('Optimal Threshold')
    ax.set_title('B.  Region-Specific Thresholds', fontweight='bold')
    ax = axes[2]; v = [r.ml_r2 for r in R]
    ax.barh(y, v, height=.6, color=cl, ec='k', lw=.4)
    for i, val in enumerate(v):
        ax.text(val+.01, y[i], f'{val:.2f}', va='center', fontsize=8)
    ax.set_yticks(y); ax.set_yticklabels(nm, fontsize=9); ax.set_xlabel('R\u00b2')
    ax.set_xlim(0, 1.05)
    ax.set_title('C.  ML Weight Optimization Fit', fontweight='bold')
    fig.suptitle('Enhanced-pCRVI: Signal Characteristics',
                 fontsize=13, fontweight='bold')
    fig.tight_layout(rect=[0, 0, 1, .94])
    p = od / 'fig_signal_characteristics.png'
    fig.savefig(p, dpi=200, bbox_inches='tight', facecolor='white')
    plt.close(fig)
    return p


def plot_verification_heatmap(R, od):
    nm = [_ab(r.name) for r in R]
    labels = ['Event\nDet', 'F1', 'PSS\nTSS', 'HSS', 'MCC',
              'CSI', 'Prec', 'Recall', 'Corr', 'DR']
    data = np.array([
        [r.event_detection_rate, r.f1, r.pss, r.hss, r.mcc, r.csi,
         r.precision, r.recall, r.correlation,
         min(r.pcrvi_dynamic_range, 1)]
        for r in R
    ])
    fig, ax = plt.subplots(figsize=(10, max(3.5, .48*len(R)+1)))
    im = ax.imshow(data, aspect='auto', cmap='RdYlGn', vmin=0, vmax=1)
    ax.set_xticks(range(len(labels))); ax.set_xticklabels(labels, fontsize=9)
    ax.set_yticks(range(len(nm))); ax.set_yticklabels(nm, fontsize=9)
    for i in range(len(nm)):
        for j in range(len(labels)):
            v = data[i, j]
            c = 'white' if v < .35 or v > .85 else 'black'
            ax.text(j, i, f'{v:.2f}', ha='center', va='center',
                    fontsize=9, color=c, fontweight='bold')
    plt.colorbar(im, ax=ax, shrink=.8, label='Score (0\u20131)')
    ax.set_title(
        'Enhanced-pCRVI: Comprehensive Verification Metrics\n'
        '(at optimal threshold, 30-day lead)',
        fontsize=12, fontweight='bold')
    fig.tight_layout()
    p = od / 'fig_verification_heatmap.png'
    fig.savefig(p, dpi=200, bbox_inches='tight', facecolor='white')
    plt.close(fig)
    return p


def plot_ml_weights(R, od):
    fig, axes = plt.subplots(1, 2, figsize=(14, .5*len(R)+2))
    nm = [_ab(r.name) for r in R]; y = np.arange(len(R))
    co = ['thermal_anomaly', 'accumulating_stress', 'seasonal_risk',
          'climate_driver', 'bleaching_history', 'water_quality',
          'light_availability']
    for ai, (title, wk) in enumerate([
        ('Expert Weights', 'expert_weights'),
        ('ML-Optimized Weights', 'ml_weights'),
    ]):
        ax = axes[ai]; left = np.zeros(len(R))
        for comp in co:
            v = [getattr(r, wk).get(comp, 0) for r in R]
            ax.barh(y, v, left=left, height=.6,
                    color=_CC.get(comp, '#888'), ec='white', lw=.3,
                    label=COMPONENT_LABELS.get(WEIGHT_KEY_TO_COMPONENT.get(comp, comp), comp.replace('_', ' ').title()) if ai == 0 else '')
            left += np.array(v)
        ax.set_yticks(y); ax.set_yticklabels(nm, fontsize=9)
        ax.set_xlabel('Weight'); ax.set_xlim(0, 1.05)
        ax.set_title(title, fontweight='bold')
    axes[0].legend(fontsize=7, loc='lower right', ncol=1)
    fig.suptitle('Component Weight Allocation: Expert vs ML-Optimized',
                 fontsize=13, fontweight='bold')
    fig.tight_layout(rect=[0, 0, 1, .94])
    p = od / 'fig_ml_weights.png'
    fig.savefig(p, dpi=200, bbox_inches='tight', facecolor='white')
    plt.close(fig)
    return p


def plot_threshold_sweep(R, od):
    n = len(R); cols = min(n, 4); rows = (n + cols - 1) // cols
    fig, axes = plt.subplots(rows, cols, figsize=(4.2*cols, 3.2*rows), squeeze=False)
    for idx, r in enumerate(R):
        ax = axes[idx // cols][idx % cols]
        if not r.thresh_sweep:
            ax.text(.5, .5, 'No data', transform=ax.transAxes, ha='center')
            ax.set_title(_ab(r.name), fontsize=9)
            continue
        ths = sorted(r.thresh_sweep.keys(), key=float)
        x = [float(t) for t in ths]
        ax.plot(x, [r.thresh_sweep[t].get('f1_score', 0) for t in ths],
                'o-', color='#E74C3C', lw=1.5, ms=3, label='F1')
        ax.plot(x, [r.thresh_sweep[t].get('pss', 0) for t in ths],
                's-', color='#3498DB', lw=1.2, ms=2.5, label='PSS/TSS')
        ax.plot(x, [r.thresh_sweep[t].get('mcc', 0) for t in ths],
                '^-', color='#27AE60', lw=1.2, ms=2.5, label='MCC')
        ax.plot(x, [r.thresh_sweep[t].get('csi', 0) for t in ths],
                'D-', color='#FF8C00', lw=1, ms=2, label='CSI')
        ax.plot(x, [r.thresh_sweep[t].get('hss', 0) for t in ths],
                'v-', color='#8E44AD', lw=1, ms=2, label='HSS')
        ax.axvline(r.optimal_threshold, color='green', ls=':', lw=1.3)
        ax.set_xlim(.15, .78); ax.set_ylim(-.05, 1.05)
        ax.set_title(_ab(r.name), fontsize=9, fontweight='bold')
        ax.tick_params(labelsize=7)
        if idx == 0:
            ax.legend(fontsize=5.5, loc='upper right', ncol=2)
    for idx in range(len(R), rows * cols):
        axes[idx // cols][idx % cols].set_visible(False)
    fig.suptitle(
        'Threshold Optimization: Verification Scores vs pCRVI Threshold\n'
        '(green dotted = optimal, 30-day lead)',
        fontsize=12, fontweight='bold')
    fig.tight_layout(rect=[0, 0, 1, .92])
    p = od / 'fig_threshold_sweep.png'
    fig.savefig(p, dpi=200, bbox_inches='tight', facecolor='white')
    plt.close(fig)
    return p


def plot_roc_curves(R, od):
    fig, ax = plt.subplots(figsize=(7, 6.5))
    ax.plot([0, 1], [0, 1], 'k--', lw=.8, alpha=.4, label='Random (AUC=0.5)')
    for r in R:
        if not r.roc_fpr or not r.roc_tpr:
            continue
        fpr = np.array(r.roc_fpr); tpr = np.array(r.roc_tpr)
        order = np.argsort(fpr); fpr_s, tpr_s = fpr[order], tpr[order]
        auc = float(np.trapz(tpr_s, fpr_s)); col = _rc(r.key)
        ax.plot(fpr_s, tpr_s, 'o-', color=col, lw=1.8, ms=3,
                label=f'{_ab(r.name)} (AUC\u2248{auc:.2f})')
        io = np.argmin(np.abs(np.array(r.roc_thresholds) - r.optimal_threshold))
        if io < len(r.roc_fpr):
            ax.plot(r.roc_fpr[io], r.roc_tpr[io], '*', color=col,
                    ms=12, mew=.5, mec='black')
    ax.set_xlabel('False Positive Rate (POFD)', fontsize=11)
    ax.set_ylabel('True Positive Rate (POD / Recall)', fontsize=11)
    ax.set_xlim(-.02, 1.02); ax.set_ylim(-.02, 1.05)
    ax.legend(fontsize=8, loc='lower right')
    ax.set_title(
        'ROC Curves: Enhanced-pCRVI Bleaching Detection\n'
        '(\u2605 = optimal threshold, 30-day lead)',
        fontsize=12, fontweight='bold')
    ax.set_aspect('equal'); fig.tight_layout()
    p = od / 'fig_roc_curves.png'
    fig.savefig(p, dpi=200, bbox_inches='tight', facecolor='white')
    plt.close(fig)
    return p


def plot_metric_radar(R, od):
    labels = ['Event\nDetect', 'F1', 'PSS/TSS', 'HSS', 'MCC',
              'CSI', 'Precision', 'Recall']
    nm = len(labels)
    angles = np.linspace(0, 2*np.pi, nm, endpoint=False).tolist()
    angles += angles[:1]
    fig, ax = plt.subplots(figsize=(8, 7), subplot_kw=dict(polar=True))
    for r in R:
        vals = [r.event_detection_rate, r.f1, max(0, r.pss), max(0, r.hss),
                max(0, r.mcc), r.csi, r.precision, r.recall]
        vals += vals[:1]; col = _rc(r.key)
        ax.plot(angles, vals, 'o-', color=col, lw=1.5, ms=4, label=_ab(r.name))
        ax.fill(angles, vals, color=col, alpha=.08)
    ax.set_xticks(angles[:-1]); ax.set_xticklabels(labels, fontsize=9)
    ax.set_ylim(0, 1.05)
    ax.set_yticks([.2, .4, .6, .8, 1.0])
    ax.set_yticklabels(['0.2', '0.4', '0.6', '0.8', '1.0'], fontsize=7)
    ax.legend(fontsize=7.5, loc='upper right', bbox_to_anchor=(1.25, 1.1))
    ax.set_title(
        'Enhanced-pCRVI: Multi-Metric Verification Radar\n'
        '(at optimal threshold, 30-day lead)',
        fontsize=12, fontweight='bold', pad=20)
    fig.tight_layout()
    p = od / 'fig_metric_radar.png'
    fig.savefig(p, dpi=200, bbox_inches='tight', facecolor='white')
    plt.close(fig)
    return p


def plot_extreme_variability(R, od):
    """Extreme Variability / Variance features across regions."""
    fig, axes = plt.subplots(1, 3, figsize=(16, .5*len(R)+2))
    nm = [_ab(r.name) for r in R]; cl = [_rc(r.key) for r in R]
    y = np.arange(len(R))
    ax = axes[0]
    v2 = [r.pct_days_2sd for r in R]; v3 = [r.pct_days_3sd for r in R]
    ax.barh(y, v2, height=.6, color=cl, ec='k', lw=.4, label='>mean+2\u03c3')
    ax.barh(y, v3, height=.3, color='#2C3E50', ec='k', lw=.3,
            label='>mean+3\u03c3')
    for i in range(len(R)):
        ax.text(v2[i]+.1, y[i], f'{v2[i]:.1f}%', va='center', fontsize=7.5)
    ax.set_yticks(y); ax.set_yticklabels(nm, fontsize=9)
    ax.set_xlabel('% of Days Exceeding Threshold')
    ax.legend(fontsize=7, loc='lower right')
    ax.set_title('A.  SST Extreme Days (>mean+n\u03c3)', fontweight='bold')
    ax = axes[1]
    ev_means = [r.ev_mean for r in R]; ev_maxs = [r.ev_max for r in R]
    ax.barh(y, ev_means, height=.6, color=cl, ec='k', lw=.4, alpha=.7,
            label='Mean EV')
    ax.scatter(ev_maxs, y, marker='D', c='#2C3E50', s=30, zorder=3,
              label='Max EV')
    for i in range(len(R)):
        ax.text(ev_maxs[i]+.01, y[i], f'{ev_maxs[i]:.2f}',
                va='center', fontsize=7)
    ax.set_yticks(y); ax.set_yticklabels(nm, fontsize=9)
    ax.set_xlabel('Extreme Variability Score'); ax.set_xlim(0, 1.1)
    ax.legend(fontsize=7)
    ax.set_title('B.  Extreme Variability Score', fontweight='bold')
    ax = axes[2]
    nce = [r.max_concurrent_extremes for r in R]
    ax.barh(y, nce, height=.6, color=cl, ec='k', lw=.4)
    for i, v in enumerate(nce):
        ax.text(v+.1, y[i], f'{v}', va='center', fontsize=8)
    ax.set_yticks(y); ax.set_yticklabels(nm, fontsize=9)
    ax.set_xlabel('Max Concurrent Extremes (\u22652\u03c3)')
    ax.set_title('C.  Co-occurring Extreme Events', fontweight='bold')
    fig.suptitle(
        'Extreme Variability Analysis: Beyond the Mean\n'
        '(captures tail-risk that mean-based metrics miss)',
        fontsize=13, fontweight='bold')
    fig.tight_layout(rect=[0, .04, 1, .92])
    fig.legend(handles=_LEG, loc='lower center', ncol=3, fontsize=9, frameon=True)
    p = od / 'fig_extreme_variability.png'
    fig.savefig(p, dpi=200, bbox_inches='tight', facecolor='white')
    plt.close(fig)
    return p


def generate_all_comparison_plots(
    results: List[RegionResult],
    output_dir: Path,
) -> Dict[str, Path]:
    """Generate all 8 cross-region comparison plots + CSV summaries."""
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    saved = {}
    for fn in [plot_detection_f1_lead, plot_signal, plot_verification_heatmap,
               plot_ml_weights, plot_threshold_sweep, plot_roc_curves,
               plot_metric_radar, plot_extreme_variability]:
        try:
            p = fn(results, output_dir)
            saved[fn.__name__] = p
        except Exception as e:
            print(f"  Warning: {fn.__name__} failed: {e}")

    # Save summary CSVs
    build_summary_df(results).to_csv(
        output_dir / 'cross_region_summary.csv', index=False)
    build_metrics_df(results).to_csv(
        output_dir / 'cross_region_metrics_full.csv', index=False)

    return saved
