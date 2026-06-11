#!/usr/bin/env python3
"""
03_fetch_repurposing_hub.py -- Phase 1C: Drug Repurposing Hub Preparation

Downloads and cleans the Drug Repurposing Hub (Broad Institute) to create
the virtual screening library:
  1. Downloads TWO tab-separated files from S3 (verified on Ada):
     - repurposing_drugs_20200324.txt (6,798 drugs with annotations)
     - repurposing_samples_20200324.txt (13,553 samples with SMILES)
  2. Deduplicates samples by drug name (pert_iname) to get one SMILES per drug
  3. Merges drug annotations with SMILES
  4. Canonicalizes all SMILES via RDKit (salt removal + neutralization)
  5. Drops invalid/duplicate SMILES
  6. Records: smiles, name, clinical_phase, moa, disease_area, target, inchikey

DO NOT use https://repo-hub.broadinstitute.org (blocked on Ada compute nodes).

Outputs:
  - data/repurposing_hub/repurposing_hub_clean.csv
  - data/repurposing_hub/repurposing_drugs_raw.txt   (cached raw download)
  - data/repurposing_hub/repurposing_samples_raw.txt  (cached raw download)
  - results/figures/phase1c_*.pdf
  - results/reports/phase1c_quality_report.json

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import os
import sys
import json
import time
import logging
import warnings
from io import StringIO
from typing import Dict, Tuple

import numpy as np
import pandas as pd
import requests

# ---------------------------------------------------------------------------
# Path setup
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)

import config
from utils.smiles_utils import canonicalize_smiles, validate_smiles
from utils.logging_utils import (
    setup_logging, log_phase_start, log_phase_end,
    log_dataframe_summary, save_checkpoint, load_checkpoint,
)
from utils.viz_utils import (
    setup_publication_style, save_figure, COLORS,
)

warnings.filterwarnings('ignore', category=FutureWarning)

logger = setup_logging('phase1c', log_dir=config.LOGS_DIR)

# ===========================================================================
# URLs (S3 direct links, verified on Ada compute nodes March 2026)
# ===========================================================================
DRUGS_URL = (
    "https://s3.amazonaws.com/data.clue.io/repurposing/downloads/"
    "repurposing_drugs_20200324.txt"
)
SAMPLES_URL = (
    "https://s3.amazonaws.com/data.clue.io/repurposing/downloads/"
    "repurposing_samples_20200324.txt"
)


# ===========================================================================
# Download functions
# ===========================================================================

def download_file(url: str, save_path: str, max_retries: int = 5) -> str:
    """
    Download a file from URL with retry logic and local caching.
    If save_path already exists and is non-empty, reads from cache.
    Returns the file content as a string.
    """
    _F = "03_fetch_repurposing_hub.py:download_file"

    # Check for cached file
    if os.path.exists(save_path) and os.path.getsize(save_path) > 100:
        logger.info(f"  [{_F}] Using cached file: {save_path} "
                    f"({os.path.getsize(save_path)} bytes)")
        try:
            with open(save_path, 'r', encoding='utf-8', errors='replace') as f:
                return f.read()
        except Exception as e:
            logger.warning(f"  [{_F}] Cache read failed ({e}), re-downloading")

    logger.info(f"  [{_F}] Downloading: {url}")
    for attempt in range(1, max_retries + 1):
        try:
            resp = requests.get(url, timeout=120)
            if resp.status_code == 200:
                content = resp.text
                os.makedirs(os.path.dirname(save_path), exist_ok=True)
                with open(save_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                logger.info(f"  [{_F}] Downloaded {len(content)} bytes, saved to {save_path}")
                return content
            else:
                logger.warning(f"  [{_F}] HTTP {resp.status_code} on attempt {attempt}/{max_retries}")
        except requests.exceptions.Timeout:
            logger.warning(f"  [{_F}] TIMEOUT on attempt {attempt}/{max_retries}")
        except requests.exceptions.ConnectionError as e:
            logger.warning(f"  [{_F}] CONNECTION ERROR on attempt {attempt}/{max_retries}: {e}")
            logger.warning(f"  [{_F}] ACTION: Check Ada compute node has internet access")
        except Exception as e:
            logger.warning(f"  [{_F}] {type(e).__name__} on attempt {attempt}/{max_retries}: {e}")

        wait = 2 ** attempt
        logger.info(f"  [{_F}] Retrying in {wait}s...")
        time.sleep(wait)

    logger.error(f"  [{_F}] FAILED after {max_retries} attempts for {url}")
    logger.error(f"  [{_F}] ACTION: Test connectivity with: curl -s '{url}' | head -5")
    raise RuntimeError(f"Failed to download {url} after {max_retries} attempts")


def parse_hub_tsv(content: str) -> pd.DataFrame:
    """
    Parse a Drug Repurposing Hub TSV file, skipping comment lines.
    """
    _F = "03_fetch_repurposing_hub.py:parse_hub_tsv"
    logger.info(f"  [{_F}] Parsing TSV content ({len(content)} chars)...")

    try:
        lines = []
        for line in content.split('\n'):
            line = line.strip('\r').strip()
            if line and not line.startswith('!'):
                lines.append(line)

        if not lines:
            logger.error(f"  [{_F}] No data lines found! Content starts with: {content[:200]}")
            raise ValueError("No data lines found in file")

        logger.info(f"  [{_F}] Found {len(lines)} data lines (header + {len(lines)-1} rows)")

        csv_text = '\n'.join(lines)
        df = pd.read_csv(StringIO(csv_text), sep='\t', dtype=str)
        df.columns = [c.strip() for c in df.columns]

        logger.info(f"  [{_F}] Parsed: {len(df)} rows, {len(df.columns)} columns: "
                    f"{list(df.columns)[:5]}...")
        return df

    except Exception as e:
        logger.error(f"  [{_F}] FAILED: {type(e).__name__}: {e}")
        logger.error(f"  [{_F}] Content preview: {content[:300]}")
        raise


# ===========================================================================
# Processing functions
# ===========================================================================

def process_hub_data() -> Tuple[pd.DataFrame, dict]:
    """
    Full Phase 1C pipeline.
    Returns (clean_df, quality_report).
    """
    _F = "03_fetch_repurposing_hub.py:process_hub_data"
    quality_report = {}

    # Check checkpoint
    ckpt_path = os.path.join(config.CHECKPOINTS_DIR, 'phase1c_master.json')
    csv_path = os.path.join(config.HUB_DIR, config.HUB_CLEAN_FILENAME)

    try:
        ckpt = load_checkpoint(ckpt_path, logger)
        if ckpt and ckpt.get('status') == 'complete' and os.path.exists(csv_path):
            logger.info(f"[{_F}] Found completed checkpoint. Loading from {csv_path}")
            df = pd.read_csv(csv_path)
            return df, ckpt.get('quality_report', {})
    except Exception as e:
        logger.warning(f"[{_F}] Checkpoint load failed ({e}), reprocessing")

    os.makedirs(config.HUB_DIR, exist_ok=True)

    # ---- Step 1: Download (local cache -> Drive -> network) ----
    try:
        logger.info(f"\n[{_F}] Step 1: Downloading Drug Repurposing Hub files...")
        drugs_raw_path = os.path.join(config.HUB_DIR, 'repurposing_drugs_raw.txt')
        samples_raw_path = os.path.join(config.HUB_DIR, 'repurposing_samples_raw.txt')

        # Try Drive restore for raw files before network download
        try:
            from utils.gdrive_backup import get_data_manager
            dm = get_data_manager()
            dm.resolve('repurposing_drugs_raw.txt', config.HUB_DIR)
            dm.resolve('repurposing_samples_raw.txt', config.HUB_DIR)
        except Exception:
            pass

        drugs_content = download_file(DRUGS_URL, drugs_raw_path)
        samples_content = download_file(SAMPLES_URL, samples_raw_path)

        # Push raw files to Drive
        try:
            from utils.gdrive_backup import get_data_manager
            dm = get_data_manager()
            dm.push(drugs_raw_path)
            dm.push(samples_raw_path)
        except Exception:
            pass
    except Exception as e:
        logger.error(f"[{_F}] Step 1 FAILED: {type(e).__name__}: {e}")
        logger.error(f"[{_F}] ACTION: Test connectivity from compute node:")
        logger.error(f"[{_F}]   curl -s '{DRUGS_URL}' | head -5")
        raise

    # ---- Step 2: Parse ----
    try:
        logger.info(f"\n[{_F}] Step 2: Parsing TSV files...")
        df_drugs = parse_hub_tsv(drugs_content)
        df_samples = parse_hub_tsv(samples_content)
        logger.info(f"  [{_F}] Drugs: {len(df_drugs)} rows, columns: {list(df_drugs.columns)}")
        logger.info(f"  [{_F}] Samples: {len(df_samples)} rows, columns: {list(df_samples.columns)}")
        quality_report['raw_drugs'] = len(df_drugs)
        quality_report['raw_samples'] = len(df_samples)
        quality_report['drugs_columns'] = list(df_drugs.columns)
        quality_report['samples_columns'] = list(df_samples.columns)
        # Save intermediates
        df_drugs.to_csv(os.path.join(config.HUB_DIR, 'hub_step2_drugs_parsed.csv'), index=False)
        df_samples.to_csv(os.path.join(config.HUB_DIR, 'hub_step2_samples_parsed.csv'), index=False)
        logger.info(f"  [{_F}] Intermediates saved: hub_step2_drugs_parsed.csv, hub_step2_samples_parsed.csv")
    except Exception as e:
        logger.error(f"[{_F}] Step 2 FAILED: {type(e).__name__}: {e}")
        raise

    # ---- Step 3: Deduplicate samples ----
    try:
        logger.info(f"\n[{_F}] Step 3: Deduplicating samples by drug name...")
        n_unique_drugs = df_samples['pert_iname'].nunique()
        logger.info(f"  [{_F}] Unique drug names in samples: {n_unique_drugs}")
        quality_report['unique_drugs_in_samples'] = n_unique_drugs

        df_smiles = df_samples.dropna(subset=['smiles']).drop_duplicates(
            subset='pert_iname', keep='first'
        )[['pert_iname', 'smiles', 'InChIKey', 'pubchem_cid']].copy()
        df_smiles = df_smiles.rename(columns={'InChIKey': 'inchikey'})
        logger.info(f"  [{_F}] Unique drugs with SMILES: {len(df_smiles)}")
        quality_report['drugs_with_smiles'] = len(df_smiles)
        df_smiles.to_csv(os.path.join(config.HUB_DIR, 'hub_step3_smiles_deduped.csv'), index=False)
        logger.info(f"  [{_F}] Intermediate saved: hub_step3_smiles_deduped.csv")
    except KeyError as e:
        logger.error(f"[{_F}] Step 3 FAILED: Missing column {e}")
        logger.error(f"[{_F}] Samples columns: {list(df_samples.columns)}")
        logger.error(f"[{_F}] ACTION: Check if Hub TSV format changed")
        raise
    except Exception as e:
        logger.error(f"[{_F}] Step 3 FAILED: {type(e).__name__}: {e}")
        raise

    # ---- Step 4: Merge ----
    try:
        logger.info(f"\n[{_F}] Step 4: Merging drug annotations with SMILES...")
        df_drugs_clean = df_drugs.rename(columns={
            'pert_iname': 'pert_iname', 'clinical_phase': 'clinical_phase',
            'moa': 'moa', 'target': 'target',
            'disease_area': 'disease_area', 'indication': 'indication',
        })
        df_merged = df_drugs_clean.merge(df_smiles, on='pert_iname', how='inner')
        logger.info(f"  [{_F}] Merged: {len(df_merged)} drugs with annotations + SMILES")
        quality_report['after_merge'] = len(df_merged)
        if len(df_merged) == 0:
            logger.error(f"[{_F}] Step 4: ZERO rows after merge!")
            logger.error(f"[{_F}] Drugs pert_iname sample: {df_drugs_clean['pert_iname'].head().tolist()}")
            logger.error(f"[{_F}] Smiles pert_iname sample: {df_smiles['pert_iname'].head().tolist()}")
            raise ValueError("Zero rows after merge, column name mismatch?")
        df_merged.to_csv(os.path.join(config.HUB_DIR, 'hub_step4_merged.csv'), index=False)
        logger.info(f"  [{_F}] Intermediate saved: hub_step4_merged.csv ({len(df_merged)} rows)")
    except Exception as e:
        logger.error(f"[{_F}] Step 4 FAILED: {type(e).__name__}: {e}")
        raise

    # ---- Step 5: Canonicalize ----
    try:
        logger.info(f"\n[{_F}] Step 5: Canonicalizing SMILES via RDKit...")
        canon_results = []
        canon_errors = 0
        from tqdm import tqdm
        for idx, smi in enumerate(tqdm(df_merged['smiles'], total=len(df_merged),
                                        desc="  Canonicalizing Hub SMILES", unit=" mol")):
            try:
                canon_results.append(canonicalize_smiles(smi))
            except Exception as ce:
                canon_results.append(None)
                canon_errors += 1
                if canon_errors <= 5:
                    logger.warning(f"  [{_F}] Row {idx}: canonicalize error "
                                   f"{type(ce).__name__} for '{str(smi)[:50]}'")

        df_merged['canonical_smiles'] = canon_results
        n_canon_ok = df_merged['canonical_smiles'].notna().sum()
        n_canon_fail = df_merged['canonical_smiles'].isna().sum()
        logger.info(f"  [{_F}] Canonicalization: {n_canon_ok} success, {n_canon_fail} failed")
        quality_report['canonicalization_success'] = int(n_canon_ok)
        quality_report['canonicalization_failed'] = int(n_canon_fail)

        if n_canon_fail > 0:
            failures = df_merged[df_merged['canonical_smiles'].isna()].head(5)
            for _, row in failures.iterrows():
                logger.debug(f"  [{_F}] Failed: {row['pert_iname']} | SMILES: {str(row['smiles'])[:60]}")

        df_merged = df_merged.dropna(subset=['canonical_smiles']).reset_index(drop=True)
        df_merged.to_csv(os.path.join(config.HUB_DIR, 'hub_step5_canonicalized.csv'), index=False)
        logger.info(f"  [{_F}] Intermediate saved: hub_step5_canonicalized.csv ({len(df_merged)} rows)")
    except Exception as e:
        logger.error(f"[{_F}] Step 5 FAILED: {type(e).__name__}: {e}")
        raise

    # ---- Step 6: Deduplicate ----
    try:
        logger.info(f"\n[{_F}] Step 6: Removing duplicate canonical SMILES...")
        n_before = len(df_merged)
        df_merged = df_merged.drop_duplicates(subset='canonical_smiles', keep='first')
        n_after = len(df_merged)
        n_dups = n_before - n_after
        logger.info(f"  [{_F}] Removed {n_dups} duplicates: {n_before} -> {n_after}")
        quality_report['duplicates_removed'] = n_dups
        df_merged.to_csv(os.path.join(config.HUB_DIR, 'hub_step6_deduped.csv'), index=False)
        logger.info(f"  [{_F}] Intermediate saved: hub_step6_deduped.csv ({n_after} rows)")
    except Exception as e:
        logger.error(f"[{_F}] Step 6 FAILED: {type(e).__name__}: {e}")
        raise

    # ---- Step 7: Build final output ----
    try:
        logger.info(f"\n[{_F}] Step 7: Building final output...")
        df_final = pd.DataFrame({
            'smiles': df_merged['canonical_smiles'],
            'name': df_merged['pert_iname'],
            'clinical_phase': df_merged['clinical_phase'].fillna(''),
            'moa': df_merged['moa'].fillna(''),
            'disease_area': df_merged['disease_area'].fillna(''),
            'target': df_merged['target'].fillna(''),
            'indication': df_merged['indication'].fillna(''),
            'inchikey': df_merged['inchikey'].fillna(''),
            'pubchem_cid': df_merged['pubchem_cid'].fillna(''),
        })

        quality_report['final_compounds'] = len(df_final)
        phase_dist = df_final['clinical_phase'].value_counts().to_dict()
        quality_report['clinical_phase_distribution'] = phase_dist
        logger.info(f"  [{_F}] Clinical phases: {phase_dist}")

        n_with_moa = int((df_final['moa'] != '').sum())
        quality_report['compounds_with_moa'] = n_with_moa
        logger.info(f"  [{_F}] Compounds with MOA annotation: {n_with_moa}/{len(df_final)}")

        antibiotic_moas = ['antibiotic', 'antibacterial', 'antimicrobial',
            'beta-lactamase', 'penicillin', 'cephalosporin',
            'fluoroquinolone', 'aminoglycoside', 'tetracycline',
            'macrolide', 'sulfonamide', 'glycopeptide']
        moa_lower = df_final['moa'].str.lower()
        is_antibiotic = moa_lower.apply(lambda x: any(kw in str(x) for kw in antibiotic_moas))
        n_antibiotics = int(is_antibiotic.sum())
        quality_report['known_antibiotics_by_moa'] = n_antibiotics
        logger.info(f"  [{_F}] Known antibiotics (by MOA keyword): {n_antibiotics}")

        return df_final, quality_report

    except Exception as e:
        logger.error(f"[{_F}] Step 7 FAILED: {type(e).__name__}: {e}")
        logger.error(f"[{_F}] df_merged shape={df_merged.shape}, columns={list(df_merged.columns)}")
        raise


# ===========================================================================
# Visualization
# ===========================================================================

def generate_phase1c_figures(df: pd.DataFrame):
    """Generate publication-quality figures for Phase 1C."""
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import seaborn as sns

    os.makedirs(config.FIGURES_DIR, exist_ok=True)
    setup_publication_style()

    # 1. Clinical phase distribution
    fig, ax = plt.subplots(figsize=(8, 5))
    phase_order = ['Launched', 'Phase 3', 'Phase 2/Phase 3', 'Phase 2',
                   'Phase 1/Phase 2', 'Phase 1', 'Preclinical', 'Withdrawn']
    phase_counts = df['clinical_phase'].value_counts()
    # Reorder
    ordered_phases = [p for p in phase_order if p in phase_counts.index]
    ordered_counts = [phase_counts[p] for p in ordered_phases]

    bars = ax.barh(range(len(ordered_phases)), ordered_counts,
                   color=COLORS['rf'], edgecolor='black', linewidth=0.5)
    ax.set_yticks(range(len(ordered_phases)))
    ax.set_yticklabels(ordered_phases)
    ax.set_xlabel('Number of compounds')
    ax.set_title(f'Drug Repurposing Hub: Clinical Phase Distribution\n(n = {len(df):,})')
    ax.invert_yaxis()

    for bar, count in zip(bars, ordered_counts):
        pct = count / len(df) * 100
        ax.text(bar.get_width() + 20, bar.get_y() + bar.get_height()/2.,
                f'{count:,} ({pct:.1f}%)', ha='left', va='center', fontsize=9)

    ax.set_xlim(0, max(ordered_counts) * 1.35)
    sns.despine()
    plt.tight_layout()
    save_figure(fig, os.path.join(config.FIGURES_DIR, 'phase1c_clinical_phases'))
    logger.info("  Figure: phase1c_clinical_phases")

    # 2. Top MOAs
    fig, ax = plt.subplots(figsize=(8, 6))
    moa_counts = df[df['moa'] != '']['moa'].value_counts().head(20)

    ax.barh(range(len(moa_counts)), moa_counts.values,
            color=COLORS['dmpnn'], edgecolor='black', linewidth=0.5)
    ax.set_yticks(range(len(moa_counts)))
    ax.set_yticklabels([m[:45] for m in moa_counts.index], fontsize=8)
    ax.set_xlabel('Number of compounds')
    ax.set_title('Top 20 Mechanisms of Action')
    ax.invert_yaxis()
    sns.despine()
    plt.tight_layout()
    save_figure(fig, os.path.join(config.FIGURES_DIR, 'phase1c_top_moas'))
    logger.info("  Figure: phase1c_top_moas")

    # 3. Disease area distribution
    fig, ax = plt.subplots(figsize=(8, 5))
    da_counts = df[df['disease_area'] != '']['disease_area'].value_counts().head(15)

    ax.barh(range(len(da_counts)), da_counts.values,
            color=COLORS['highlight'], edgecolor='black', linewidth=0.5)
    ax.set_yticks(range(len(da_counts)))
    ax.set_yticklabels([d[:40] for d in da_counts.index], fontsize=9)
    ax.set_xlabel('Number of compounds')
    ax.set_title('Top 15 Disease Areas')
    ax.invert_yaxis()
    sns.despine()
    plt.tight_layout()
    save_figure(fig, os.path.join(config.FIGURES_DIR, 'phase1c_disease_areas'))
    logger.info("  Figure: phase1c_disease_areas")

    # 4. Summary statistics figure
    fig, axes = plt.subplots(1, 2, figsize=(11, 4.5))

    # Panel A: key stats
    ax = axes[0]
    ax.axis('off')
    stats_text = (
        f"Drug Repurposing Hub Summary\n"
        f"{'='*35}\n"
        f"Total compounds:  {len(df):,}\n"
        f"With MOA:         {(df['moa'] != '').sum():,}\n"
        f"With target:      {(df['target'] != '').sum():,}\n"
        f"With disease area: {(df['disease_area'] != '').sum():,}\n"
        f"Launched drugs:   {(df['clinical_phase'] == 'Launched').sum():,}\n"
        f"Preclinical:      {(df['clinical_phase'] == 'Preclinical').sum():,}\n"
    )
    ax.text(0.1, 0.5, stats_text, transform=ax.transAxes, fontsize=11,
            verticalalignment='center', fontfamily='monospace',
            bbox=dict(boxstyle='round', facecolor='lightyellow', alpha=0.8))
    ax.set_title('A. Key Statistics', fontsize=12)

    # Panel B: SMILES length distribution (proxy for molecular complexity)
    ax2 = axes[1]
    smi_lens = df['smiles'].str.len()
    ax2.hist(smi_lens, bins=50, color=COLORS['rf'], edgecolor='white',
             linewidth=0.3, alpha=0.8)
    ax2.set_xlabel('SMILES string length')
    ax2.set_ylabel('Count')
    ax2.set_title('B. Molecular Complexity Proxy')
    ax2.axvline(x=smi_lens.median(), color='red', linestyle='--',
                label=f'Median: {smi_lens.median():.0f}')
    ax2.legend()
    sns.despine(ax=ax2)

    plt.tight_layout()
    save_figure(fig, os.path.join(config.FIGURES_DIR, 'phase1c_summary'))
    logger.info("  Figure: phase1c_summary")


# ===========================================================================
# Unit tests
# ===========================================================================

def run_unit_tests() -> bool:
    """Run unit tests for Phase 1C functions (minimal network for download test)."""
    print("Running Phase 1C unit tests...")
    n_pass = 0
    n_fail = 0

    def _assert(condition, msg):
        nonlocal n_pass, n_fail
        if condition:
            n_pass += 1
            print(f"  [PASS] {msg}")
        else:
            n_fail += 1
            print(f"  [FAIL] {msg}")

    # ---- Test parse_hub_tsv ----
    test_content = (
        "!Source\ttest\n"
        "!Date\t2024\n"
        "col_a\tcol_b\tcol_c\n"
        "val1\tval2\tval3\n"
        "val4\tval5\tval6\r\n"
        "val7\tval8\tval9\n"
    )
    df_test = parse_hub_tsv(test_content)
    _assert(len(df_test) == 3, f"parse_hub_tsv: expected 3 rows, got {len(df_test)}")
    _assert(list(df_test.columns) == ['col_a', 'col_b', 'col_c'],
            f"parse_hub_tsv: columns correct")
    _assert(df_test.iloc[0]['col_a'] == 'val1', "parse_hub_tsv: first value correct")
    _assert(df_test.iloc[2]['col_c'] == 'val9', "parse_hub_tsv: last value correct")

    # Test with empty content
    try:
        parse_hub_tsv("!comment only\n")
        _assert(False, "parse_hub_tsv: should raise on empty data")
    except ValueError:
        _assert(True, "parse_hub_tsv: raises ValueError on empty data")

    # ---- Test canonicalize_smiles on Hub-like data ----
    # Some real Hub SMILES
    hub_smiles = [
        'CN1CCc2cccc-3c2[C@H]1Cc1ccc(O)c(O)c-31',       # apomorphine
        'COc1ccc(cc1OC1CCCC1)[C@@H]1CNC(=O)C1',           # rolipram
        'CC(C)(C)NCC(O)c1cc(Cl)c(N)c(Cl)c1',              # clenbuterol
        'INVALID_SMILES_XYZ',                                # invalid
        '',                                                   # empty
    ]
    canon_results = [canonicalize_smiles(s) for s in hub_smiles]
    _assert(canon_results[0] is not None, "Hub SMILES: apomorphine canonical OK")
    _assert(canon_results[1] is not None, "Hub SMILES: rolipram canonical OK")
    _assert(canon_results[2] is not None, "Hub SMILES: clenbuterol canonical OK")
    _assert(canon_results[3] is None, "Hub SMILES: invalid returns None")
    _assert(canon_results[4] is None, "Hub SMILES: empty returns None")

    # ---- Test dedup logic on mock data ----
    mock_samples = pd.DataFrame({
        'pert_iname': ['drugA', 'drugA', 'drugB', 'drugC', 'drugC'],
        'smiles': ['CCO', 'CCO', 'CCN', 'CCC', 'CCC'],
        'InChIKey': ['IK1', 'IK1', 'IK2', 'IK3', 'IK3'],
        'pubchem_cid': ['1', '1', '2', '3', '3'],
    })
    deduped = mock_samples.drop_duplicates(subset='pert_iname', keep='first')
    _assert(len(deduped) == 3, f"Dedup: expected 3, got {len(deduped)}")

    mock_drugs = pd.DataFrame({
        'pert_iname': ['drugA', 'drugB', 'drugC', 'drugD'],
        'clinical_phase': ['Launched', 'Phase 1', 'Phase 2', 'Preclinical'],
        'moa': ['kinase inhibitor', 'antibiotic', '', 'antibiotic'],
    })
    merged = mock_drugs.merge(
        deduped[['pert_iname', 'smiles']], on='pert_iname', how='inner'
    )
    _assert(len(merged) == 3, f"Merge: expected 3 (drugD has no SMILES match), got {len(merged)}")

    # ---- Test antibiotic MOA detection ----
    moa_test = pd.Series(['kinase inhibitor', 'antibiotic', 'beta-lactamase inhibitor',
                          'fluoroquinolone antibiotic', '', 'dopamine agonist'])
    antibiotic_kws = ['antibiotic', 'antibacterial', 'beta-lactamase', 'fluoroquinolone']
    is_ab = moa_test.str.lower().apply(
        lambda x: any(kw in str(x) for kw in antibiotic_kws)
    )
    _assert(int(is_ab.sum()) == 3,
            f"Antibiotic detection: expected 3, got {int(is_ab.sum())}")

    print(f"\nUnit tests: {n_pass} passed, {n_fail} failed")
    return n_fail == 0


# ===========================================================================
# Main
# ===========================================================================

def main():
    """Main entry point for Phase 1C."""
    _F = "03_fetch_repurposing_hub.py:main"

    # Run unit tests first
    logger.info(f"[{_F}] Running unit tests before data acquisition...")
    # Suppress noisy output during tests (expected errors look alarming to users)
    import logging as _tl
    _prev_level = logger.level
    logger.setLevel(_tl.CRITICAL)
    try:
        from rdkit import RDLogger as _rdl
        _rdl.DisableLog('rdApp.*')
    except Exception:
        pass
    _test_ok = run_unit_tests()
    try:
        _rdl.EnableLog('rdApp.*')
    except Exception:
        pass
    logger.setLevel(_prev_level)
    if not _test_ok:
        logger.error(f"[{_F}] Unit tests FAILED. Aborting.")
        sys.exit(1)
    logger.info(f"[{_F}] All unit tests passed.\n")

    start_time = log_phase_start(logger, "Phase 1C: Drug Repurposing Hub Preparation")

    # Create directories
    for d in [config.HUB_DIR, config.CHECKPOINTS_DIR, config.FIGURES_DIR, config.REPORTS_DIR]:
        os.makedirs(d, exist_ok=True)

    # Check cache for existing output
    from utils.data_cache import DataCache
    cache = DataCache(config.PROJECT_DIR, logger)
    cache_key = f"repurposing_hub/{config.HUB_CLEAN_FILENAME}"

    if cache.is_valid(cache_key, min_rows=5000):
        logger.info(f"[{_F}] Cache HIT for Hub data, validating...")
        try:
            csv_path = cache.get_path(cache_key)
            df_check = pd.read_csv(csv_path)
            required = ['smiles', 'name', 'moa', 'clinical_phase']
            if all(c in df_check.columns for c in required) and len(df_check) > 5000:
                logger.info(f"[{_F}] Cached Hub data valid: {len(df_check)} compounds. Skipping download.")
                log_phase_end(logger, "Phase 1C (from cache)", start_time)
                return
        except Exception as e:
            logger.warning(f"[{_F}] Cache validation failed: {e}, re-downloading")

    # Try local -> Drive before network download
    try:
        from utils.gdrive_backup import get_data_manager
        dm = get_data_manager()
        restored = dm.resolve(config.HUB_CLEAN_FILENAME, config.HUB_DIR)
        if restored:
            df_check = pd.read_csv(restored)
            if len(df_check) > 5000:
                logger.info(f"[{_F}] Found Hub data: {len(df_check)} compounds (from {restored})")
                cache.register(cache_key, n_rows=len(df_check),
                               description='Drug Repurposing Hub')
                log_phase_end(logger, "Phase 1C (from cache/Drive)", start_time)
                return
    except Exception:
        pass  # Fall through to network download

    # Test S3 connectivity
    from utils.network_utils import test_connectivity
    logger.info(f"[{_F}] Testing S3 connectivity...")
    test_connectivity(logger, urls=[DRUGS_URL])

    # Run the pipeline
    try:
        df_final, quality_report = process_hub_data()
    except Exception as e:
        logger.error(f"[{_F}] process_hub_data() FAILED: {type(e).__name__}: {e}")
        import traceback
        logger.error(traceback.format_exc())
        sys.exit(1)

    if len(df_final) == 0:
        logger.error(f"[{_F}] No compounds produced! Check network connectivity.")
        sys.exit(1)

    # Save output
    try:
        csv_path = os.path.join(config.HUB_DIR, config.HUB_CLEAN_FILENAME)
        df_final.to_csv(csv_path, index=False)
        logger.info(f"\n[{_F}] Saved: {csv_path} ({len(df_final)} compounds)")
        cache.register(cache_key, n_rows=len(df_final),
                       description='Drug Repurposing Hub cleaned data')
        # Back up to Google Drive
        try:
            from utils.gdrive_backup import get_data_manager
            get_data_manager().push(csv_path)
        except Exception:
            pass
    except Exception as e:
        logger.error(f"[{_F}] Save FAILED: {type(e).__name__}: {e}")
        raise

    log_dataframe_summary(logger, df_final, 'repurposing_hub_clean')

    # Generate figures (non-critical)
    logger.info(f"\n[{_F}] Generating Phase 1C figures...")
    try:
        generate_phase1c_figures(df_final)
    except Exception as e:
        logger.warning(f"[{_F}] Figure generation failed (non-critical): {e}")

    # Save quality report (non-critical)
    try:
        report_path = os.path.join(config.REPORTS_DIR, 'phase1c_quality_report.json')
        with open(report_path, 'w') as f:
            json.dump(quality_report, f, indent=2, default=str)
        logger.info(f"[{_F}] Quality report saved: {report_path}")
    except Exception as e:
        logger.warning(f"[{_F}] Report save failed (non-critical): {e}")

    # Summary
    logger.info("\n" + "=" * 60)
    logger.info(" PHASE 1C SUMMARY")
    logger.info("=" * 60)
    logger.info(f"  Raw drugs file:       {quality_report.get('raw_drugs', '?')} drugs")
    logger.info(f"  Raw samples file:     {quality_report.get('raw_samples', '?')} samples")
    logger.info(f"  Unique with SMILES:   {quality_report.get('drugs_with_smiles', '?')}")
    logger.info(f"  After canonicalization: {quality_report.get('canonicalization_success', '?')}")
    logger.info(f"  Duplicates removed:   {quality_report.get('duplicates_removed', '?')}")
    logger.info(f"  Final compounds:      {quality_report.get('final_compounds', '?')}")
    logger.info(f"  Known antibiotics:    {quality_report.get('known_antibiotics_by_moa', '?')}")
    logger.info("=" * 60)

    # Save master checkpoint
    save_checkpoint(
        {
            'status': 'complete',
            'quality_report': quality_report,
            'final_compounds': quality_report.get('final_compounds', 0),
        },
        os.path.join(config.CHECKPOINTS_DIR, 'phase1c_master.json'),
        logger,
    )

    # Save quality report as standalone JSON
    import json as _json
    report_path = os.path.join(config.HUB_DIR, 'phase1c_quality_report.json')
    try:
        with open(report_path, 'w') as f:
            _json.dump(quality_report, f, indent=2, default=str)
        logger.info(f"[{_F}] Quality report saved: {report_path}")
        try:
            from utils.gdrive_backup import get_data_manager
            get_data_manager().push(report_path)
        except Exception:
            pass
    except Exception:
        pass

    log_phase_end(logger, "Phase 1C", start_time)


if __name__ == '__main__':
    main()
