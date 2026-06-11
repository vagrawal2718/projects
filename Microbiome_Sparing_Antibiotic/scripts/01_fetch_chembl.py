#!/usr/bin/env python3
"""
01_fetch_chembl.py -- Phase 1A: ChEMBL Pathogen Data Acquisition

Fetches MIC bioactivity data for 4 pathogens from ChEMBL v34 via the
Python API. For each pathogen:
  1. Finds the ORGANISM-level target in ChEMBL
  2. Queries all MIC activities with valid units and relations
  3. Converts ug/mL values to nM using RDKit molecular weights
  4. Canonicalizes SMILES (salt removal + neutralization)
  5. Deduplicates by canonical SMILES (median across replicates)
  6. Assigns binary labels: active if MIC <= 10,000 nM (10 uM)
  7. Falls back to IC50 data if MIC yields < 2,000 compounds

Outputs per pathogen:
  - CSV: [smiles, median_value_nM, activity_label, molecule_chembl_id,
          n_measurements, source_type]
  - Data quality report (JSON)
  - Class distribution figure (PDF)

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import os
import sys
import json
import time
import logging
import warnings
from typing import Dict, List, Optional, Tuple

import numpy as np
import pandas as pd

# ---------------------------------------------------------------------------
# Path setup: ensure project scripts are importable
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
sys.path.insert(0, SCRIPT_DIR)

import config
from utils.smiles_utils import canonicalize_smiles, get_molecular_weight, convert_ugml_to_nM
from utils.logging_utils import (
    setup_logging, log_phase_start, log_phase_end,
    log_dataframe_summary, save_checkpoint, load_checkpoint, timed,
)
from utils.viz_utils import (
    setup_publication_style, plot_class_distribution,
    plot_data_summary_table, save_figure, COLORS,
)

warnings.filterwarnings('ignore', category=FutureWarning)

logger = setup_logging('phase1a', log_dir=config.LOGS_DIR)

# ===========================================================================
# ChEMBL target IDs (verified via API test)
# ===========================================================================
PATHOGEN_TARGETS = {
    'ecoli':       'CHEMBL354',
    'saureus':     'CHEMBL352',
    'paeruginosa': 'CHEMBL348',
    'mtb':         'CHEMBL360',
}


# ===========================================================================
# Core functions
# ===========================================================================

def fetch_activities_for_target(
    target_chembl_id: str,
    standard_type: str = 'MIC',
    max_retries: int = 5,
) -> pd.DataFrame:
    """
    Fetch all activities for a ChEMBL target.

    PRIMARY path: ChEMBL SQLite bulk database (fast, ~2 min download, instant query).
    FALLBACK path: ChEMBL REST API (slow, 5-30 min per pathogen).
    """
    _F = "01_fetch_chembl.py:fetch_activities_for_target"

    # ---- PRIMARY: SQLite bulk download (instant queries) ----
    try:
        df = _fetch_via_sqlite(target_chembl_id, standard_type)
        if df is not None and len(df) > 0:
            logger.info(f"  [{_F}] SQLite query returned {len(df)} records for "
                        f"{target_chembl_id}/{standard_type}")
            return df
        logger.warning(f"  [{_F}] SQLite returned 0 records, falling back to API")
    except Exception as e:
        logger.warning(f"  [{_F}] SQLite path failed: {type(e).__name__}: {e}")
        logger.info(f"  [{_F}] Falling back to REST API (slower)...")

    # ---- FALLBACK: REST API (paginated, slow for large targets) ----
    return _fetch_via_api(target_chembl_id, standard_type, max_retries)


# Global: cache the SQLite DB path so we download only once per run
_CHEMBL_SQLITE_PATH = None

def _fetch_via_sqlite(target_chembl_id: str, standard_type: str) -> 'Optional[pd.DataFrame]':
    """Query the ChEMBL SQLite bulk database. Downloads once (~1GB), queries instantly."""
    global _CHEMBL_SQLITE_PATH
    _F = "01_fetch_chembl.py:_fetch_via_sqlite"

    if _CHEMBL_SQLITE_PATH is None:
        # Priority: local pystow -> Drive (.db or tar.gz) -> network download
        try:
            from utils.gdrive_backup import get_data_manager
            dm = get_data_manager()
            restored = dm.resolve_chembl_sqlite()
            if restored and os.path.exists(restored):
                _CHEMBL_SQLITE_PATH = restored
                logger.info(f"  [{_F}] ChEMBL SQLite found: {restored}")
        except Exception as e:
            logger.debug(f"  [{_F}] DataManager lookup skipped: {e}")

    if _CHEMBL_SQLITE_PATH is None:
        try:
            import chembl_downloader
        except ImportError:
            logger.info(f"  [{_F}] chembl-downloader not installed. Install: pip install chembl-downloader")
            return None

        logger.info(f"  [{_F}] Downloading ChEMBL 34 SQLite (first time: ~1GB, 2-5 min)...")
        logger.info(f"  [{_F}] After first download, this is cached locally and on Drive.")
        try:
            # Download tar.gz first (for Drive backup), then extract
            targz_path = chembl_downloader.download_sqlite(version='34')
            _CHEMBL_SQLITE_PATH = chembl_downloader.download_extract_sqlite(version='34')
            logger.info(f"  [{_F}] Database ready: {_CHEMBL_SQLITE_PATH}")

            # Push both tar.gz and .db to Google Drive
            try:
                from utils.gdrive_backup import get_data_manager
                get_data_manager().push_chembl_sqlite(
                    str(_CHEMBL_SQLITE_PATH), str(targz_path))
            except Exception:
                pass  # Non-critical
        except Exception as e:
            logger.warning(f"  [{_F}] SQLite download failed: {type(e).__name__}: {e}")
            return None

    import sqlite3

    query = """
    SELECT
        cs.canonical_smiles,
        act.standard_value,
        act.standard_units,
        act.standard_relation,
        act.pchembl_value,
        md.chembl_id  AS molecule_chembl_id,
        ass.chembl_id AS assay_chembl_id,
        docs.chembl_id AS document_chembl_id
    FROM activities act
    JOIN assays ass ON act.assay_id = ass.assay_id
    JOIN target_dictionary td ON ass.tid = td.tid
    JOIN molecule_dictionary md ON act.molregno = md.molregno
    JOIN compound_structures cs ON act.molregno = cs.molregno
    LEFT JOIN docs ON act.doc_id = docs.doc_id
    WHERE td.chembl_id = ?
      AND act.standard_type = ?
      AND cs.canonical_smiles IS NOT NULL
    """

    logger.info(f"  [{_F}] Querying SQLite: target={target_chembl_id}, type={standard_type}...")
    try:
        conn = sqlite3.connect(str(_CHEMBL_SQLITE_PATH))
        df = pd.read_sql_query(query, conn, params=(target_chembl_id, standard_type))
        conn.close()
        logger.info(f"  [{_F}] Query returned {len(df)} records in <1s")
        return df
    except Exception as e:
        logger.warning(f"  [{_F}] SQLite query failed: {type(e).__name__}: {e}")
        return None


def _fetch_via_api(
    target_chembl_id: str,
    standard_type: str = 'MIC',
    max_retries: int = 5,
) -> pd.DataFrame:
    """Fallback: Fetch via ChEMBL REST API (slow for large targets)."""
    _F = "01_fetch_chembl.py:_fetch_via_api"

    try:
        from chembl_webresource_client.new_client import new_client
        activity_api = new_client.activity
    except ImportError as e:
        logger.error(f"  [{_F}] Cannot import chembl_webresource_client: {e}")
        logger.error(f"  [{_F}] ACTION: pip install chembl-webresource-client")
        raise
    except Exception as e:
        logger.error(f"  [{_F}] ChEMBL client init failed: {type(e).__name__}: {e}")
        raise

    logger.info(f"  [{_F}] Querying ChEMBL: target={target_chembl_id}, type={standard_type}")
    logger.info(f"  [{_F}] This may take 5-15 minutes per pathogen...")

    for attempt in range(1, max_retries + 1):
        try:
            query = activity_api.filter(
                target_chembl_id=target_chembl_id,
                standard_type=standard_type,
            )

            records = []
            parse_errors = 0
            from tqdm import tqdm
            pbar = tqdm(desc=f"  ChEMBL {target_chembl_id}/{standard_type}",
                        unit=" records", miniters=100, dynamic_ncols=True)
            for i, act in enumerate(query):
                try:
                    records.append({
                        'canonical_smiles': act.get('canonical_smiles'),
                        'standard_value': act.get('standard_value'),
                        'standard_units': act.get('standard_units'),
                        'standard_relation': act.get('standard_relation'),
                        'molecule_chembl_id': act.get('molecule_chembl_id'),
                        'assay_chembl_id': act.get('assay_chembl_id'),
                        'document_chembl_id': act.get('document_chembl_id'),
                        'pchembl_value': act.get('pchembl_value'),
                    })
                except Exception as row_err:
                    parse_errors += 1
                    if parse_errors <= 3:
                        logger.warning(f"  [{_F}] Record {i}: parse error: {row_err}")

                pbar.update(1)
                if (i + 1) % 2000 == 0:
                    logger.info(f"    [{_F}] ...fetched {i + 1} records so far "
                                f"({parse_errors} parse errors)")
            pbar.close()

            logger.info(f"  [{_F}] Fetched {len(records)} raw {standard_type} records "
                        f"({parse_errors} parse errors)")
            if len(records) == 0:
                logger.warning(f"  [{_F}] ZERO records returned for {target_chembl_id}/{standard_type}! "
                               f"Check if target ID is correct.")
            return pd.DataFrame(records)

        except Exception as e:
            wait_time = 2 ** attempt
            logger.warning(
                f"  [{_F}] Attempt {attempt}/{max_retries} FAILED: "
                f"{type(e).__name__}: {e}. Retrying in {wait_time}s..."
            )
            if attempt == max_retries:
                logger.error(f"  [{_F}] ALL {max_retries} attempts failed for "
                             f"{target_chembl_id}/{standard_type}.")
                logger.error(f"  [{_F}] ACTION: Check network connectivity from compute node.")
                logger.error(f"  [{_F}]   Test: curl -s https://www.ebi.ac.uk/chembl/api/data/activity.json?limit=1")
            time.sleep(wait_time)

    return pd.DataFrame()


def filter_valid_activities(df: pd.DataFrame) -> pd.DataFrame:
    """
    Filter activities to those with valid units, relations, and SMILES.
    """
    _F = "01_fetch_chembl.py:filter_valid_activities"
    n_start = len(df)
    logger.info(f"  [{_F}] Filtering {n_start} records...")

    if n_start == 0:
        logger.warning(f"  [{_F}] Empty DataFrame, nothing to filter")
        return df

    try:
        # Drop rows with missing critical fields
        required_cols = ['canonical_smiles', 'standard_value']
        missing_cols = [c for c in required_cols if c not in df.columns]
        if missing_cols:
            logger.error(f"  [{_F}] MISSING COLUMNS: {missing_cols}. Have: {list(df.columns)}")
            raise KeyError(f"Missing required columns: {missing_cols}")

        df = df.dropna(subset=['canonical_smiles', 'standard_value'])
        n_after_nulls = len(df)

        # Filter by valid units
        df = df[df['standard_units'].isin(config.CHEMBL_VALID_UNITS)]
        n_after_units = len(df)

        # Filter by valid relations
        df = df[df['standard_relation'].isin(config.CHEMBL_VALID_RELATIONS)]
        n_after_rels = len(df)

        # Ensure numeric value > 0
        df['standard_value'] = pd.to_numeric(df['standard_value'], errors='coerce')
        df = df[df['standard_value'] > 0]
        n_after_values = len(df)

        # Ensure SMILES is a non-empty string
        df = df[df['canonical_smiles'].str.strip().str.len() > 0]
        n_final = len(df)

        logger.info(f"  [{_F}] {n_start} -> {n_after_nulls} (nulls) "
                    f"-> {n_after_units} (units) -> {n_after_rels} (relations) "
                    f"-> {n_after_values} (values) -> {n_final} (SMILES)")

        if n_final == 0:
            logger.warning(f"  [{_F}] ALL records filtered out! Check data quality.")
            logger.warning(f"  [{_F}] Units seen: {df['standard_units'].value_counts().to_dict() if 'standard_units' in df else 'N/A'}")

        return df.reset_index(drop=True)

    except Exception as e:
        logger.error(f"  [{_F}] FATAL: {type(e).__name__}: {e}")
        logger.error(f"  [{_F}] DataFrame shape={df.shape}, columns={list(df.columns)}")
        logger.error(f"  [{_F}] Sample row: {df.iloc[0].to_dict() if len(df) > 0 else 'empty'}")
        raise


def convert_to_nM(df: pd.DataFrame) -> pd.DataFrame:
    """
    Convert all values to nM. Records already in nM are kept as-is.
    Records in ug/mL are converted using RDKit molecular weight.

    Adds column: value_nM
    """
    _F = "01_fetch_chembl.py:convert_to_nM"
    logger.info(f"  [{_F}] Converting {len(df)} records to nM...")

    if len(df) == 0:
        logger.warning(f"  [{_F}] Empty DataFrame, nothing to convert")
        df = df.copy()
        df['value_nM'] = []
        return df

    values_nM = []
    conversion_failures = 0
    n_rows = len(df)

    from tqdm import tqdm
    for row_idx, (_, row) in enumerate(tqdm(df.iterrows(), total=n_rows,
                                             desc="  Converting to nM", unit=" rows")):
        try:
            val = row['standard_value']
            units = row['standard_units']
            smiles = row['canonical_smiles']

            if units == 'nM':
                values_nM.append(val)
            elif units == 'ug.mL-1':
                mw = get_molecular_weight(smiles)
                if mw is not None and mw > 0:
                    val_nM = convert_ugml_to_nM(val, mw)
                    values_nM.append(val_nM)
                else:
                    values_nM.append(None)
                    conversion_failures += 1
                    if conversion_failures <= 5:
                        logger.debug(f"  [{_F}] Row {row_idx}: MW lookup failed for "
                                     f"SMILES='{str(smiles)[:60]}', val={val} {units}")
            else:
                values_nM.append(None)
                conversion_failures += 1

        except Exception as e:
            values_nM.append(None)
            conversion_failures += 1
            logger.warning(f"  [{_F}] Row {row_idx}/{n_rows}: EXCEPTION {type(e).__name__}: {e} | "
                           f"SMILES='{str(row.get('canonical_smiles','?'))[:50]}', "
                           f"val={row.get('standard_value','?')}, units={row.get('standard_units','?')}")



    try:
        df = df.copy()
        df['value_nM'] = values_nM

        if conversion_failures > 0:
            logger.warning(f"  [{_F}] Unit conversion failed for {conversion_failures}/{n_rows} records")

        df = df.dropna(subset=['value_nM'])
        df = df[df['value_nM'] > 0]
        logger.info(f"  [{_F}] After unit conversion: {len(df)} records with valid nM values")

        return df.reset_index(drop=True)

    except Exception as e:
        logger.error(f"  [{_F}] FATAL during post-processing: {type(e).__name__}: {e}")
        logger.error(f"  [{_F}] DataFrame shape={df.shape}, columns={list(df.columns)}")
        raise


def canonicalize_and_deduplicate(df: pd.DataFrame) -> pd.DataFrame:
    """
    Canonicalize SMILES and deduplicate by taking the median value per
    unique canonical SMILES.

    Returns DataFrame with columns:
    [smiles, median_value_nM, activity_label, molecule_chembl_id,
     n_measurements, source_type]
    """
    _F = "01_fetch_chembl.py:canonicalize_and_deduplicate"

    # Canonicalize with per-SMILES error handling
    logger.info(f"  [{_F}] Canonicalizing {len(df)} SMILES...")
    canonical_list = []
    canon_failures = 0
    n_total = len(df)

    from tqdm import tqdm
    for idx, smi in enumerate(tqdm(df['canonical_smiles'], total=n_total,
                                    desc="  Canonicalizing", unit=" SMILES")):
        try:
            canonical_list.append(canonicalize_smiles(smi))
        except Exception as e:
            canonical_list.append(None)
            canon_failures += 1
            if canon_failures <= 5:
                logger.warning(f"  [{_F}] Row {idx}: canonicalize_smiles() raised "
                               f"{type(e).__name__}: {e} for SMILES='{str(smi)[:60]}'")



    try:
        df = df.copy()
        df['canon_smiles'] = canonical_list
        n_before = len(df)
        df = df.dropna(subset=['canon_smiles'])
        n_after = len(df)
        logger.info(f"  [{_F}] Canonicalization: {n_before} -> {n_after} "
                    f"({n_before - n_after} failed)")

        if n_after == 0:
            logger.error(f"  [{_F}] ALL SMILES failed canonicalization! Check RDKit installation.")
            raise ValueError("Zero valid SMILES after canonicalization")

        # Deduplicate: median value per unique canonical SMILES
        logger.info(f"  [{_F}] Deduplicating by canonical SMILES (median of replicates)...")

        grouped = df.groupby('canon_smiles').agg(
            median_value_nM=('value_nM', 'median'),
            n_measurements=('value_nM', 'count'),
            molecule_chembl_id=('molecule_chembl_id', 'first'),
        ).reset_index()

        grouped.rename(columns={'canon_smiles': 'smiles'}, inplace=True)

        logger.info(f"  [{_F}] Deduplicated: {n_after} records -> {len(grouped)} unique compounds")

        return grouped

    except Exception as e:
        logger.error(f"  [{_F}] FATAL: {type(e).__name__}: {e}")
        logger.error(f"  [{_F}] DataFrame shape={df.shape}, columns={list(df.columns)}")
        raise


def assign_binary_labels(
    df: pd.DataFrame,
    threshold_nM: float,
    source_type: str = 'MIC',
) -> pd.DataFrame:
    """
    Assign binary activity labels based on MIC threshold.

    active (1) if median_value_nM <= threshold_nM
    inactive (0) otherwise
    """
    df = df.copy()
    df['activity_label'] = (df['median_value_nM'] <= threshold_nM).astype(int)
    df['source_type'] = source_type

    n_active = int(df['activity_label'].sum())
    n_inactive = len(df) - n_active
    pct_active = n_active / len(df) * 100 if len(df) > 0 else 0

    logger.info(f"  Labels at {threshold_nM/1000:.0f} uM threshold: "
                f"{n_active} active ({pct_active:.1f}%), "
                f"{n_inactive} inactive")

    return df


def process_one_pathogen(
    pathogen_key: str,
    checkpoint_dir: str,
) -> Tuple[pd.DataFrame, dict]:
    """
    Full pipeline for one pathogen: fetch, filter, convert, deduplicate, label.
    Includes IC50 fallback logic if MIC yields < 2000 compounds.
    Returns (DataFrame, quality_report_dict).
    """
    _F = f"01_fetch_chembl.py:process_one_pathogen({pathogen_key})"
    pathogen_info = config.PATHOGENS[pathogen_key]
    target_id = PATHOGEN_TARGETS[pathogen_key]
    organism_name = pathogen_info['name']

    logger.info(f"\n{'='*60}")
    logger.info(f"[{_F}] Processing: {organism_name} (target: {target_id})")
    logger.info(f"{'='*60}")

    # Check for existing checkpoint
    ckpt_path = os.path.join(checkpoint_dir, f"phase1a_{pathogen_key}.json")
    csv_path = os.path.join(config.CHEMBL_DIR, pathogen_info['csv_filename'])

    try:
        ckpt = load_checkpoint(ckpt_path, logger)
        if ckpt and ckpt.get('status') == 'complete' and os.path.exists(csv_path):
            logger.info(f"  [{_F}] Found completed checkpoint. Loading from {csv_path}")
            df = pd.read_csv(csv_path)
            return df, ckpt.get('quality_report', {})
    except Exception as e:
        logger.warning(f"  [{_F}] Checkpoint load failed ({e}), reprocessing from scratch")

    quality_report = {
        'pathogen': organism_name,
        'target_chembl_id': target_id,
    }
    t0 = time.time()

    # Step 1: Fetch MIC data
    try:
        logger.info(f"  [{_F}] Step 1: Fetching MIC activities from ChEMBL...")
        df_raw = fetch_activities_for_target(target_id, 'MIC')
        quality_report['raw_mic_records'] = len(df_raw)
        if len(df_raw) == 0:
            logger.error(f"  [{_F}] Step 1: ZERO MIC data returned for {organism_name}!")
            logger.error(f"  [{_F}] ACTION: Check network, or try: curl https://www.ebi.ac.uk/chembl/api/data/activity.json?limit=1")
            return pd.DataFrame(), quality_report
        if 'standard_units' in df_raw.columns:
            unit_counts = df_raw['standard_units'].value_counts().to_dict()
            quality_report['unit_distribution_raw'] = {str(k): int(v) for k, v in unit_counts.items()}
            logger.info(f"  [{_F}] Unit distribution: {unit_counts}")
        # Save intermediate
        _ipath = os.path.join(config.CHEMBL_DIR, f'{pathogen_key}_step1_raw.csv')
        df_raw.to_csv(_ipath, index=False)
        logger.info(f"  [{_F}] Intermediate saved: {_ipath} ({len(df_raw)} rows)")
    except Exception as e:
        logger.error(f"  [{_F}] Step 1 FAILED: {type(e).__name__}: {e}")
        raise

    # Step 2: Filter
    try:
        logger.info(f"  [{_F}] Step 2: Filtering valid activities...")
        df_filt = filter_valid_activities(df_raw)
        quality_report['after_filtering'] = len(df_filt)
        if len(df_filt) == 0:
            logger.error(f"  [{_F}] Step 2: ALL records filtered out for {organism_name}!")
            return pd.DataFrame(), quality_report
        _ipath = os.path.join(config.CHEMBL_DIR, f'{pathogen_key}_step2_filtered.csv')
        df_filt.to_csv(_ipath, index=False)
        logger.info(f"  [{_F}] Intermediate saved: {_ipath} ({len(df_filt)} rows)")
    except Exception as e:
        logger.error(f"  [{_F}] Step 2 FAILED: {type(e).__name__}: {e}")
        raise

    # Step 3: Convert to nM
    try:
        logger.info(f"  [{_F}] Step 3: Converting to nM...")
        df_nM = convert_to_nM(df_filt)
        quality_report['after_unit_conversion'] = len(df_nM)
        _ipath = os.path.join(config.CHEMBL_DIR, f'{pathogen_key}_step3_nM.csv')
        df_nM.to_csv(_ipath, index=False)
        logger.info(f"  [{_F}] Intermediate saved: {_ipath} ({len(df_nM)} rows)")
    except Exception as e:
        logger.error(f"  [{_F}] Step 3 FAILED: {type(e).__name__}: {e}")
        raise

    # Step 4: Canonicalize and deduplicate
    try:
        logger.info(f"  [{_F}] Step 4: Canonicalizing and deduplicating...")
        df_dedup = canonicalize_and_deduplicate(df_nM)
        quality_report['unique_compounds_mic'] = len(df_dedup)
        _ipath = os.path.join(config.CHEMBL_DIR, f'{pathogen_key}_step4_deduped.csv')
        df_dedup.to_csv(_ipath, index=False)
        logger.info(f"  [{_F}] Intermediate saved: {_ipath} ({len(df_dedup)} rows)")
    except Exception as e:
        logger.error(f"  [{_F}] Step 4 FAILED: {type(e).__name__}: {e}")
        raise

    # Step 5: IC50 fallback check
    used_ic50_fallback = False
    try:
        if len(df_dedup) < config.IC50_FALLBACK_MIN_COMPOUNDS:
            logger.warning(f"  [{_F}] MIC yielded only {len(df_dedup)} compounds "
                           f"(< {config.IC50_FALLBACK_MIN_COMPOUNDS}). Adding IC50 data...")
            df_ic50_raw = fetch_activities_for_target(target_id, 'IC50')
            quality_report['raw_ic50_records'] = len(df_ic50_raw)

            if len(df_ic50_raw) > 0:
                df_ic50_filt = filter_valid_activities(df_ic50_raw)
                df_ic50_nM = convert_to_nM(df_ic50_filt)
                df_ic50_dedup = canonicalize_and_deduplicate(df_ic50_nM)
                df_ic50_dedup = assign_binary_labels(
                    df_ic50_dedup, config.IC50_FALLBACK_THRESHOLD_NM, source_type='IC50')
                mic_smiles = set(df_dedup['smiles'].values)
                df_ic50_new = df_ic50_dedup[~df_ic50_dedup['smiles'].isin(mic_smiles)]
                logger.info(f"  [{_F}] IC50 fallback adds {len(df_ic50_new)} new compounds")
                df_mic_labeled = assign_binary_labels(
                    df_dedup, config.MIC_THRESHOLD_NM, source_type='MIC')
                df_dedup = pd.concat([df_mic_labeled, df_ic50_new], ignore_index=True)
                used_ic50_fallback = True
                quality_report['ic50_compounds_added'] = len(df_ic50_new)
                quality_report['total_after_ic50_merge'] = len(df_dedup)
    except Exception as e:
        logger.warning(f"  [{_F}] IC50 fallback failed ({type(e).__name__}: {e}), continuing with MIC only")

    if not used_ic50_fallback:
        try:
            logger.info(f"  [{_F}] Step 5: Assigning binary labels...")
            df_dedup = assign_binary_labels(df_dedup, config.MIC_THRESHOLD_NM, source_type='MIC')
        except Exception as e:
            logger.error(f"  [{_F}] Step 5 (labeling) FAILED: {type(e).__name__}: {e}")
            raise

    quality_report['used_ic50_fallback'] = used_ic50_fallback

    # Final output
    try:
        output_cols = ['smiles', 'median_value_nM', 'activity_label',
                       'molecule_chembl_id', 'n_measurements', 'source_type']
        missing_cols = [c for c in output_cols if c not in df_dedup.columns]
        if missing_cols:
            logger.error(f"  [{_F}] Missing output columns: {missing_cols}")
            logger.error(f"  [{_F}] Available columns: {list(df_dedup.columns)}")
            raise KeyError(f"Missing columns: {missing_cols}")

        df_final = df_dedup[output_cols].copy()
        quality_report['final_compounds'] = len(df_final)
        quality_report['n_active'] = int(df_final['activity_label'].sum())
        quality_report['n_inactive'] = int((df_final['activity_label'] == 0).sum())
        quality_report['pct_active'] = round(
            quality_report['n_active'] / len(df_final) * 100, 1) if len(df_final) > 0 else 0

        if len(df_final) > 0:
            quality_report['median_value_nM_stats'] = {
                'mean': round(float(df_final['median_value_nM'].mean()), 1),
                'median': round(float(df_final['median_value_nM'].median()), 1),
                'min': round(float(df_final['median_value_nM'].min()), 3),
                'max': round(float(df_final['median_value_nM'].max()), 1),
            }
            quality_report['measurements_per_compound'] = {
                'mean': round(float(df_final['n_measurements'].mean()), 1),
                'median': float(df_final['n_measurements'].median()),
                'max': int(df_final['n_measurements'].max()),
            }
        quality_report['processing_time_seconds'] = round(time.time() - t0, 1)

        # Expected count range check
        lo, hi = pathogen_info['expected_count_range']
        if len(df_final) < lo:
            logger.warning(f"  [{_F}] COUNT WARNING: {len(df_final)} below expected [{lo}, {hi}]")
            quality_report['count_warning'] = f"Below expected range [{lo}, {hi}]"
        elif len(df_final) > hi:
            logger.warning(f"  [{_F}] COUNT WARNING: {len(df_final)} above expected [{lo}, {hi}]")
        else:
            logger.info(f"  [{_F}] Count {len(df_final)} within expected [{lo}, {hi}]")

        # Save CSV
        os.makedirs(config.CHEMBL_DIR, exist_ok=True)
        df_final.to_csv(csv_path, index=False)
        logger.info(f"  [{_F}] Saved: {csv_path} ({len(df_final)} rows)")

        # Back up to Google Drive
        try:
            from utils.gdrive_backup import get_data_manager
            get_data_manager().push(csv_path)
        except Exception:
            pass  # Non-critical

        # Save checkpoint
        save_checkpoint(
            {'status': 'complete', 'quality_report': quality_report},
            ckpt_path, logger)

        return df_final, quality_report

    except Exception as e:
        logger.error(f"  [{_F}] Final output assembly FAILED: {type(e).__name__}: {e}")
        logger.error(f"  [{_F}] df_dedup shape={df_dedup.shape}, columns={list(df_dedup.columns)}")
        raise


# ===========================================================================
# Visualization and reporting
# ===========================================================================

def generate_phase1a_figures(all_results: Dict[str, pd.DataFrame]):
    """Generate publication-quality figures for Phase 1A data."""
    os.makedirs(config.FIGURES_DIR, exist_ok=True)

    # 1. Per-pathogen class distributions
    for key, df in all_results.items():
        if len(df) == 0:
            continue
        name = config.PATHOGENS[key]['name']
        plot_class_distribution(
            df['activity_label'].values,
            f'{name}\nMIC Activity Distribution (threshold: 10 $\\mu$M)',
            os.path.join(config.FIGURES_DIR, f'phase1a_classdist_{key}'),
        )
        logger.info(f"  Figure: class distribution for {key}")

    # 2. Combined overview bar chart
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import seaborn as sns

    setup_publication_style()
    fig, axes = plt.subplots(1, 2, figsize=(12, 5))

    # Panel A: compound counts
    names = []
    totals = []
    actives = []
    inactives = []
    for key in config.PATHOGENS:
        if key in all_results and len(all_results[key]) > 0:
            df = all_results[key]
            names.append(config.PATHOGENS[key]['name'].replace(' ', '\n'))
            totals.append(len(df))
            actives.append(int(df['activity_label'].sum()))
            inactives.append(int((df['activity_label'] == 0).sum()))

    x = np.arange(len(names))
    width = 0.35
    ax = axes[0]
    ax.bar(x - width/2, actives, width, label='Active (MIC $\\leq$ 10 $\\mu$M)',
           color=COLORS['active'], edgecolor='black', linewidth=0.5)
    ax.bar(x + width/2, inactives, width, label='Inactive',
           color=COLORS['inactive'], edgecolor='black', linewidth=0.5)
    ax.set_xticks(x)
    ax.set_xticklabels(names, fontsize=9)
    ax.set_ylabel('Number of compounds')
    ax.set_title('A. Compound counts per pathogen')
    ax.legend(fontsize=9)
    for i, total in enumerate(totals):
        ax.text(i, max(actives[i], inactives[i]) + total * 0.02,
                f'n={total:,}', ha='center', va='bottom', fontsize=8)
    sns.despine(ax=ax)

    # Panel B: active fraction
    ax2 = axes[1]
    pct_active = [a / t * 100 for a, t in zip(actives, totals)]
    bars = ax2.bar(x, pct_active, color=[COLORS['active']]*len(x),
                   edgecolor='black', linewidth=0.5, width=0.5)
    ax2.set_xticks(x)
    ax2.set_xticklabels(names, fontsize=9)
    ax2.set_ylabel('Active compounds (%)')
    ax2.set_title('B. Active fraction per pathogen')
    ax2.set_ylim(0, 100)
    ax2.axhline(y=50, color='gray', linestyle='--', alpha=0.3)
    for bar, pct in zip(bars, pct_active):
        ax2.text(bar.get_x() + bar.get_width()/2., bar.get_height() + 1,
                 f'{pct:.1f}%', ha='center', va='bottom', fontsize=10)
    sns.despine(ax=ax2)

    plt.tight_layout()
    save_figure(fig, os.path.join(config.FIGURES_DIR, 'phase1a_overview'))
    logger.info("  Figure: phase1a_overview")

    # 3. Value distribution (log-scale histogram)
    fig, axes = plt.subplots(2, 2, figsize=(12, 10))
    for idx, (key, ax) in enumerate(zip(config.PATHOGENS, axes.flat)):
        if key not in all_results or len(all_results[key]) == 0:
            continue
        df = all_results[key]
        name = config.PATHOGENS[key]['name']

        log_vals = np.log10(df['median_value_nM'].clip(lower=0.01))
        ax.hist(log_vals, bins=50, color=COLORS['rf'], edgecolor='white',
                linewidth=0.3, alpha=0.8)
        threshold_log = np.log10(config.MIC_THRESHOLD_NM)
        ax.axvline(x=threshold_log, color='red', linestyle='--', linewidth=1.5,
                   label=f'Threshold: 10 $\\mu$M')
        ax.set_xlabel('log$_{10}$(MIC / nM)')
        ax.set_ylabel('Count')
        ax.set_title(name)
        ax.legend(fontsize=9)
        sns.despine(ax=ax)

    plt.suptitle('MIC Value Distributions (log-scale)', fontsize=14, y=1.02)
    plt.tight_layout()
    save_figure(fig, os.path.join(config.FIGURES_DIR, 'phase1a_value_distributions'))
    logger.info("  Figure: phase1a_value_distributions")


def generate_phase1a_report(all_reports: Dict[str, dict]):
    """Save combined quality report as JSON and log summary table."""
    report_path = os.path.join(config.REPORTS_DIR, 'phase1a_quality_report.json')
    os.makedirs(config.REPORTS_DIR, exist_ok=True)
    with open(report_path, 'w') as f:
        json.dump(all_reports, f, indent=2, default=str)
    logger.info(f"Quality report saved: {report_path}")

    # Log summary table
    logger.info("\n" + "="*80)
    logger.info(" PHASE 1A SUMMARY")
    logger.info("="*80)
    header = f"{'Pathogen':<25} {'Raw':>8} {'Filtered':>8} {'Unique':>8} {'Active':>8} {'%Act':>6} {'IC50?':>6}"
    logger.info(header)
    logger.info("-" * 80)
    for key, report in all_reports.items():
        logger.info(
            f"{report.get('pathogen','?'):<25} "
            f"{report.get('raw_mic_records',0):>8} "
            f"{report.get('after_filtering',0):>8} "
            f"{report.get('final_compounds',0):>8} "
            f"{report.get('n_active',0):>8} "
            f"{report.get('pct_active',0):>5.1f}% "
            f"{'Yes' if report.get('used_ic50_fallback') else 'No':>6}"
        )
    logger.info("="*80)


# ===========================================================================
# Unit tests
# ===========================================================================

def run_unit_tests() -> bool:
    """
    Run unit tests for Phase 1A functions.
    Tests use small synthetic data (no network calls).
    """
    print("Running Phase 1A unit tests...")
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

    # Test filter_valid_activities
    test_data = pd.DataFrame({
        'canonical_smiles': ['CCO', 'CCN', '', None, 'CCC', 'CCCC', 'CCCCC'],
        'standard_value': [100, None, 50, 60, -5, 200, 300],
        'standard_units': ['ug.mL-1', 'nM', 'nM', 'ug.mL-1', 'nM', 'mg.mL-1', 'nM'],
        'standard_relation': ['=', '=', '<', '<=', '=', '=', '>'],
        'molecule_chembl_id': [f'CHEMBL{i}' for i in range(7)],
    })
    filtered = filter_valid_activities(test_data)
    _assert(len(filtered) == 1, f"filter_valid: expected 1 row, got {len(filtered)}")
    _assert(filtered.iloc[0]['canonical_smiles'] == 'CCO',
            "filter_valid: correct row survives")

    # Test convert_to_nM
    test_nM = pd.DataFrame({
        'canonical_smiles': ['CCO', 'c1ccccc1'],
        'standard_value': [46.04, 1000.0],  # ethanol MW=46.04, benzene MW=78.11
        'standard_units': ['ug.mL-1', 'nM'],
    })
    converted = convert_to_nM(test_nM)
    _assert(len(converted) == 2, f"convert_to_nM: expected 2 rows, got {len(converted)}")
    # ethanol: 46.04 ug/mL / 46.04 g/mol * 1e6 = ~1e6 nM
    ethanol_nM = converted[converted['canonical_smiles'] == 'CCO']['value_nM'].iloc[0]
    _assert(abs(ethanol_nM - 1e6) < 5e4,
            f"convert_to_nM ethanol: expected ~1e6, got {ethanol_nM:.0f}")
    # benzene: already in nM, should stay 1000
    benzene_nM = converted[converted['canonical_smiles'] == 'c1ccccc1']['value_nM'].iloc[0]
    _assert(abs(benzene_nM - 1000.0) < 1,
            f"convert_to_nM benzene: expected 1000, got {benzene_nM:.0f}")

    # Test canonicalize_and_deduplicate
    test_dedup = pd.DataFrame({
        'canonical_smiles': ['CCO', 'OCC', 'CCO', 'c1ccccc1'],
        'value_nM': [100, 200, 300, 500],
        'molecule_chembl_id': ['C1', 'C1', 'C1', 'C2'],
    })
    deduped = canonicalize_and_deduplicate(test_dedup)
    _assert(len(deduped) == 2, f"dedup: expected 2, got {len(deduped)}")
    ethanol_row = deduped[deduped['smiles'] == 'CCO']
    _assert(len(ethanol_row) == 1, "dedup: ethanol deduplicated")
    _assert(ethanol_row.iloc[0]['median_value_nM'] == 200.0,
            f"dedup: ethanol median={ethanol_row.iloc[0]['median_value_nM']}")
    _assert(ethanol_row.iloc[0]['n_measurements'] == 3,
            f"dedup: ethanol n_meas={ethanol_row.iloc[0]['n_measurements']}")

    # Test assign_binary_labels
    test_labels = pd.DataFrame({
        'smiles': ['A', 'B', 'C'],
        'median_value_nM': [5000, 10000, 20000],
        'molecule_chembl_id': ['C1', 'C2', 'C3'],
        'n_measurements': [1, 1, 1],
    })
    labeled = assign_binary_labels(test_labels, 10000, 'MIC')
    _assert(labeled.iloc[0]['activity_label'] == 1, "label: 5000 nM -> active")
    _assert(labeled.iloc[1]['activity_label'] == 1, "label: 10000 nM -> active (<=)")
    _assert(labeled.iloc[2]['activity_label'] == 0, "label: 20000 nM -> inactive")

    print(f"\nUnit tests: {n_pass} passed, {n_fail} failed")
    return n_fail == 0


# ===========================================================================
# Main
# ===========================================================================

def main():
    """Main entry point for Phase 1A."""
    _F = "01_fetch_chembl.py:main"

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

    start_time = log_phase_start(logger, "Phase 1A: ChEMBL Pathogen Data Acquisition")

    # Create directories
    for d in [config.CHEMBL_DIR, config.CHECKPOINTS_DIR, config.FIGURES_DIR, config.REPORTS_DIR]:
        os.makedirs(d, exist_ok=True)

    # Test connectivity BEFORE expensive API calls
    from utils.network_utils import test_connectivity
    logger.info(f"[{_F}] Testing network connectivity...")
    conn = test_connectivity(logger, urls=[
        'https://www.ebi.ac.uk/chembl/api/data/activity.json?limit=1',
    ])
    chembl_ok = any(v['reachable'] for v in conn.values())
    if not chembl_ok:
        logger.error(f"[{_F}] ChEMBL API unreachable! Check network from compute node.")
        logger.error(f"[{_F}] ACTION: Try 'curl -s https://www.ebi.ac.uk/chembl/api/data/activity.json?limit=1'")
        logger.error(f"[{_F}] If blocked, run Phase 1A from the login node instead.")
        # Don't exit - checkpointed data may exist for some pathogens

    # Initialize data cache for tracking
    from utils.data_cache import DataCache
    cache = DataCache(config.PROJECT_DIR, logger)

    # Process each pathogen
    all_results = {}
    all_reports = {}
    n_pathogens = len(config.PATHOGENS)

    for p_idx, pathogen_key in enumerate(config.PATHOGENS, 1):
        pinfo = config.PATHOGENS[pathogen_key]
        cache_key = f"chembl/{pinfo['csv_filename']}"

        logger.info(f"\n{'='*60}")
        logger.info(f"  Pathogen {p_idx}/{n_pathogens}: {pinfo['name']} ({pathogen_key})")
        logger.info(f"  Target: {PATHOGEN_TARGETS.get(pathogen_key, '?')}, Expected: {pinfo['expected_count_range']}")
        logger.info(f"{'='*60}")

        # Check cache first
        if cache.is_valid(cache_key, min_rows=pinfo['expected_count_range'][0] // 2):
            logger.info(f"[{_F}] Cache HIT for {pathogen_key}, loading from disk")
            csv_path = cache.get_path(cache_key)
            try:
                df = pd.read_csv(csv_path)
                all_results[pathogen_key] = df
                all_reports[pathogen_key] = {'status': 'loaded_from_cache', 'n_compounds': len(df)}
                continue
            except Exception as e:
                logger.warning(f"[{_F}] Cache read failed for {pathogen_key}: {e}, refetching")

        # Try local cache -> Drive -> network fetch
        try:
            from utils.gdrive_backup import get_data_manager
            dm = get_data_manager()
            csv_path_local = os.path.join(config.CHEMBL_DIR, pinfo['csv_filename'])
            restored = dm.resolve(pinfo['csv_filename'], config.CHEMBL_DIR)
            if restored:
                df = pd.read_csv(restored)
                if len(df) >= pinfo['expected_count_range'][0] // 2:
                    logger.info(f"[{_F}] Found {pathogen_key}: {len(df)} rows (from {restored})")
                    all_results[pathogen_key] = df
                    all_reports[pathogen_key] = {'status': 'restored', 'n_compounds': len(df)}
                    cache.register(cache_key, n_rows=len(df),
                                   description=f"ChEMBL {pinfo['name']}")
                    continue
        except Exception:
            pass  # Fall through to network fetch

        try:
            df, report = process_one_pathogen(pathogen_key, config.CHECKPOINTS_DIR)
            all_results[pathogen_key] = df
            all_reports[pathogen_key] = report

            # Register in cache
            if len(df) > 0:
                cache.register(cache_key, n_rows=len(df),
                               description=f"ChEMBL {pinfo['name']} activity data")
        except Exception as e:
            logger.error(f"[{_F}] FAILED processing {pathogen_key}: {type(e).__name__}: {e}")
            import traceback
            logger.error(traceback.format_exc())
            logger.error(f"[{_F}] Continuing with remaining pathogens...")

    # Generate figures (non-critical)
    logger.info(f"\n[{_F}] Generating Phase 1A figures...")
    try:
        generate_phase1a_figures(all_results)
    except Exception as e:
        logger.warning(f"[{_F}] Figure generation failed (non-critical): {e}")

    # Generate report (non-critical)
    try:
        generate_phase1a_report(all_reports)
    except Exception as e:
        logger.warning(f"[{_F}] Report generation failed (non-critical): {e}")

    # Save master checkpoint
    save_checkpoint(
        {
            'status': 'complete',
            'pathogens_processed': list(all_results.keys()),
            'compound_counts': {k: len(v) for k, v in all_results.items()},
        },
        os.path.join(config.CHECKPOINTS_DIR, 'phase1a_master.json'),
        logger,
    )

    # Save quality reports as JSON
    import json
    report_path = os.path.join(config.CHEMBL_DIR, 'phase1a_quality_reports.json')
    try:
        with open(report_path, 'w') as f:
            json.dump(all_reports, f, indent=2, default=str)
        logger.info(f"[{_F}] Quality reports saved: {report_path}")
        try:
            from utils.gdrive_backup import get_data_manager
            get_data_manager().push(report_path)
        except Exception:
            pass
    except Exception as e:
        logger.warning(f"[{_F}] Quality report save failed: {e}")

    logger.info(f"\n[{_F}] Summary:")
    for k, v in all_results.items():
        logger.info(f"  {k}: {len(v)} compounds")
    n_ok = sum(1 for v in all_results.values() if len(v) > 0)
    logger.info(f"  {n_ok}/{len(config.PATHOGENS)} pathogens completed successfully")

    log_phase_end(logger, "Phase 1A", start_time)


if __name__ == '__main__':
    main()
