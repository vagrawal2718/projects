#!/usr/bin/env python3
"""
02_process_maier.py -- Phase 1B: Maier Commensal Harm Data Processing

Processes Maier et al. 2018 and 2021 supplementary data to create the
commensal harm training dataset:
  1. Reads MOESM5 S3a (1,197 drugs x 40 strains, n_hit counts)
  2. Reads MOESM3 S1a (1,200 drugs with STITCH4 IDs)
  3. Joins on prestwick_ID
  4. Converts STITCH4 IDs to PubChem CIDs
  5. Fetches canonical SMILES from PubChem REST API (batch, 100/call)
  6. Canonicalizes via RDKit (salt removal + neutralization)
  7. Assigns binary harm labels at thresholds {5, 10, 20}

Outputs:
  - data/maier/maier_combined.csv
  - data/maier/smiles_lookup_log.csv
  - results/figures/phase1b_*.pdf  (publication-quality figures)
  - results/reports/phase1b_quality_report.json

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
# Path setup
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
sys.path.insert(0, SCRIPT_DIR)

import config
from utils.smiles_utils import canonicalize_smiles, validate_smiles
from utils.logging_utils import (
    setup_logging, log_phase_start, log_phase_end,
    log_dataframe_summary, save_checkpoint, load_checkpoint, timed,
)
from utils.viz_utils import (
    setup_publication_style, plot_class_distribution,
    plot_nhit_distribution, save_figure, COLORS,
)

warnings.filterwarnings('ignore', category=FutureWarning)
warnings.filterwarnings('ignore', category=UserWarning)

logger = setup_logging('phase1b', log_dir=config.LOGS_DIR)


# ===========================================================================
# Step 1: Read MOESM5 S3a (training labels)
# ===========================================================================

def read_moesm5_training_labels(filepath: str) -> pd.DataFrame:
    """
    Read Maier 2018 MOESM5, sheet 'S3a. Adjusted p-values'.
    Extracts: prestwick_ID, chemical_name, drug_class, n_hit.
    """
    _F = "02_process_maier.py:read_moesm5_training_labels"
    logger.info(f"  [{_F}] Reading MOESM5 S3a from: {filepath}")

    if not os.path.exists(filepath):
        logger.error(f"  [{_F}] FILE NOT FOUND: {filepath}")
        logger.error(f"  [{_F}] ACTION: Upload Maier Excel files to ~/antibiotic-selectivity/data/maier/")
        raise FileNotFoundError(f"Maier file not found: {filepath}")

    try:
        df = pd.read_excel(
            filepath,
            sheet_name='S3a. Adjusted p-values',
            engine='openpyxl',
        )
    except Exception as e:
        logger.error(f"  [{_F}] Failed to read Excel: {type(e).__name__}: {e}")
        logger.error(f"  [{_F}] File: {filepath}, size: {os.path.getsize(filepath) if os.path.exists(filepath) else 'N/A'}")
        logger.error(f"  [{_F}] ACTION: Check if file is a valid .xlsx (not corrupted)")
        raise

    # Rename columns to standardized names
    df = df.rename(columns={
        'prestwick_ID': 'prestwick_id',
        'chemical_name': 'name',
    })

    # Keep only the metadata columns
    result = df[['prestwick_id', 'name', 'drug_class', 'n_hit']].copy()

    # Validate
    assert result['prestwick_id'].notna().all(), "Null prestwick_IDs found"
    assert result['n_hit'].notna().all(), "Null n_hit values found"
    assert (result['n_hit'] >= 0).all() and (result['n_hit'] <= 40).all(), \
        "n_hit values out of range [0, 40]"

    logger.info(f"  Loaded {len(result)} compounds with n_hit labels")
    logger.info(f"  n_hit range: [{result['n_hit'].min()}, {result['n_hit'].max()}]")
    logger.info(f"  n_hit == 0: {int((result['n_hit'] == 0).sum())} ({(result['n_hit'] == 0).mean()*100:.1f}%)")
    logger.info(f"  Drug classes: {dict(result['drug_class'].value_counts())}")

    return result


# ===========================================================================
# Step 2: Read MOESM3 S1a (STITCH4 ID mapping)
# ===========================================================================

def read_moesm3_id_mapping(filepath: str) -> pd.DataFrame:
    """Read Maier 2018 MOESM3, sheet 'S1a. Prestwick_Libery'."""
    _F = "02_process_maier.py:read_moesm3_id_mapping"
    logger.info(f"  [{_F}] Reading MOESM3 S1a from: {filepath}")

    if not os.path.exists(filepath):
        logger.error(f"  [{_F}] FILE NOT FOUND: {filepath}")
        logger.error(f"  [{_F}] ACTION: Upload Maier Excel files to ~/antibiotic-selectivity/data/maier/")
        raise FileNotFoundError(f"Maier file not found: {filepath}")

    try:
        df = pd.read_excel(
            filepath,
            sheet_name='S1a. Prestwick_Libery',
            engine='openpyxl',
        )
    except Exception as e:
        logger.error(f"  [{_F}] Failed to read Excel: {type(e).__name__}: {e}")
        logger.error(f"  [{_F}] ACTION: Check file integrity: {filepath}")
        raise

    result = df[['prestwick_ID', 'STITCH4 id']].copy()
    result.columns = ['prestwick_id', 'stitch4_id']

    # Validate STITCH ID format
    n_valid = result['stitch4_id'].str.startswith('CID').sum()
    logger.info(f"  Loaded {len(result)} ID mappings, {n_valid} with valid STITCH4 IDs")

    return result


# ===========================================================================
# Step 3: STITCH4 to PubChem CID conversion
# ===========================================================================

def stitch_to_pubchem_cid(stitch_id: str) -> Optional[int]:
    """
    Convert STITCH4 ID to PubChem CID.

    STITCH4 format: CID[stereo_flag(1 digit)][zero-padded PubChem CID(8 digits)]
    Example: CID100008646 -> drop first 4 chars -> '00008646' -> int 8646

    Parameters
    ----------
    stitch_id : str
        STITCH4 identifier string.

    Returns
    -------
    int or None
        PubChem CID, or None if conversion fails.
    """
    if not stitch_id or not isinstance(stitch_id, str):
        return None
    stitch_id = stitch_id.strip()
    if not stitch_id.startswith('CID'):
        return None
    try:
        return int(stitch_id[4:])  # Drop 'CID' + stereo flag
    except (ValueError, IndexError):
        return None


# ===========================================================================
# Step 4: PubChem SMILES lookup (batch)
# ===========================================================================

def fetch_smiles_batch_pubchem(
    cids: List[int],
    batch_size: int = 100,
    max_retries: int = 5,
    delay_between_batches: float = 0.5,
) -> Dict[int, Optional[str]]:
    """
    Fetch canonical SMILES from PubChem REST API in batches.

    Uses PUG REST endpoint:
    https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/{cids}/property/CanonicalSMILES/JSON

    Parameters
    ----------
    cids : list of int
        PubChem CIDs to look up.
    batch_size : int
        Number of CIDs per API call (max ~100 recommended).
    max_retries : int
        Max retries per batch on failure.
    delay_between_batches : float
        Seconds to wait between batches (rate limiting).

    Returns
    -------
    dict
        {cid: smiles_string_or_None}
    """
    import requests

    results = {}
    # Normalize all CIDs to Python int (not numpy.int64)
    cids = [int(c) for c in cids]
    total_batches = (len(cids) + batch_size - 1) // batch_size
    base_url = "https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid"

    logger.info(f"  Fetching SMILES for {len(cids)} CIDs in {total_batches} batches...")

    from tqdm import tqdm
    for batch_idx in tqdm(range(total_batches), desc="  PubChem SMILES lookup",
                          unit=" batch", total=total_batches):
        start = batch_idx * batch_size
        end = min(start + batch_size, len(cids))
        batch_cids = cids[start:end]
        cid_str = ','.join(str(c) for c in batch_cids)

        url = f"{base_url}/{cid_str}/property/CanonicalSMILES/JSON"

        for attempt in range(1, max_retries + 1):
            try:
                resp = requests.get(url, timeout=60)

                if resp.status_code == 200:
                    data = resp.json()
                    props = data.get('PropertyTable', {}).get('Properties', [])
                    for p in props:
                        results[int(p['CID'])] = p.get('CanonicalSMILES')
                    break  # Success

                elif resp.status_code == 404:
                    # Some CIDs not found; try individual lookups for this batch
                    logger.debug(f"    Batch {batch_idx+1}: 404, trying individual lookups")
                    for cid in batch_cids:
                        try:
                            r = requests.get(
                                f"{base_url}/{cid}/property/CanonicalSMILES/JSON",
                                timeout=30,
                            )
                            if r.ok:
                                d = r.json()
                                p = d.get('PropertyTable', {}).get('Properties', [])
                                if p:
                                    results[int(cid)] = p[0].get('CanonicalSMILES')
                            time.sleep(0.2)
                        except Exception:
                            pass
                    break

                else:
                    wait_time = 2 ** attempt
                    logger.warning(
                        f"    Batch {batch_idx+1}: HTTP {resp.status_code}, "
                        f"retry {attempt}/{max_retries} in {wait_time}s"
                    )
                    time.sleep(wait_time)

            except Exception as e:
                wait_time = 2 ** attempt
                logger.warning(
                    f"    Batch {batch_idx+1}: {type(e).__name__}, "
                    f"retry {attempt}/{max_retries} in {wait_time}s"
                )
                time.sleep(wait_time)

        # Progress logging
        if (batch_idx + 1) % 5 == 0 or batch_idx == total_batches - 1:
            logger.info(
                f"    Progress: {batch_idx+1}/{total_batches} batches, "
                f"{len(results)}/{len(cids)} SMILES resolved"
            )

        time.sleep(delay_between_batches)

    return results


def fetch_smiles_pubchempy_fallback(
    cids: List[int],
) -> Dict[int, Optional[str]]:
    """
    Fallback: use pubchempy for any CIDs not resolved by REST API.

    This is slower (one CID at a time) but handles edge cases.
    """
    try:
        import pubchempy as pcp
    except ImportError:
        logger.warning("  pubchempy not available for fallback lookups")
        return {}

    results = {}
    from tqdm import tqdm
    for i, cid in enumerate(tqdm(cids, desc="  PubChem fallback lookups", unit=" CID")):
        try:
            compounds = pcp.Compound.from_cid(int(cid))
            if compounds and compounds.isomeric_smiles:
                results[int(cid)] = compounds.isomeric_smiles
            time.sleep(0.3)  # Rate limit
        except Exception as e:
            logger.debug(f"  pubchempy fallback failed for CID {cid}: {e}")

    return results


# ===========================================================================
# Step 5-7: Full pipeline
# ===========================================================================

def process_maier_data() -> Tuple[pd.DataFrame, pd.DataFrame, dict]:
    """
    Full Phase 1B pipeline.

    Returns
    -------
    tuple of (maier_combined_df, lookup_log_df, quality_report)
    """
    quality_report = {}

    # Check for completed checkpoint
    ckpt_path = os.path.join(config.CHECKPOINTS_DIR, 'phase1b_master.json')
    csv_path = os.path.join(config.MAIER_DIR, 'maier_combined.csv')

    ckpt = load_checkpoint(ckpt_path, logger)
    if ckpt and ckpt.get('status') == 'complete' and os.path.exists(csv_path):
        logger.info(f"Found completed checkpoint. Loading from {csv_path}")
        df = pd.read_csv(csv_path)
        log_path = os.path.join(config.MAIER_DIR, 'smiles_lookup_log.csv')
        log_df = pd.read_csv(log_path) if os.path.exists(log_path) else pd.DataFrame()
        return df, log_df, ckpt.get('quality_report', {})

    # ---------------------------------------------------------------
    # Step 1: Read training labels from MOESM5 S3a
    # ---------------------------------------------------------------
    logger.info("\nStep 1: Reading MOESM5 S3a (training labels)...")
    moesm5_path = os.path.join(
        config.MAIER_DIR, config.MAIER_FILES['moesm5_2018']
    )
    df_labels = read_moesm5_training_labels(moesm5_path)
    quality_report['moesm5_compounds'] = len(df_labels)
    _ipath = os.path.join(config.MAIER_DIR, 'maier_step1_labels.csv')
    df_labels.to_csv(_ipath, index=False)
    logger.info(f"  Intermediate saved: {_ipath}")

    # ---------------------------------------------------------------
    # Step 2: Read ID mapping from MOESM3 S1a
    # ---------------------------------------------------------------
    logger.info("\nStep 2: Reading MOESM3 S1a (STITCH4 ID mapping)...")
    moesm3_path = os.path.join(
        config.MAIER_DIR, config.MAIER_FILES['moesm3_2018']
    )
    df_ids = read_moesm3_id_mapping(moesm3_path)
    quality_report['moesm3_mappings'] = len(df_ids)
    _ipath = os.path.join(config.MAIER_DIR, 'maier_step2_id_mapping.csv')
    df_ids.to_csv(_ipath, index=False)
    logger.info(f"  Intermediate saved: {_ipath}")

    # ---------------------------------------------------------------
    # Step 3: Join on prestwick_ID
    # ---------------------------------------------------------------
    logger.info("\nStep 3: Joining labels with ID mapping...")
    df_merged = df_labels.merge(df_ids, on='prestwick_id', how='left')

    n_with_stitch = df_merged['stitch4_id'].notna().sum()
    n_without = df_merged['stitch4_id'].isna().sum()
    logger.info(f"  Merged: {len(df_merged)} rows, "
                f"{n_with_stitch} with STITCH4 ID, "
                f"{n_without} without")
    quality_report['merged_total'] = len(df_merged)
    quality_report['with_stitch_id'] = int(n_with_stitch)
    quality_report['without_stitch_id'] = int(n_without)

    # Drop rows without STITCH IDs
    df_merged = df_merged.dropna(subset=['stitch4_id']).reset_index(drop=True)
    _ipath = os.path.join(config.MAIER_DIR, 'maier_step3_merged.csv')
    df_merged.to_csv(_ipath, index=False)
    logger.info(f"  Intermediate saved: {_ipath} ({len(df_merged)} rows)")

    # ---------------------------------------------------------------
    # Step 4: Convert STITCH4 to PubChem CIDs
    # ---------------------------------------------------------------
    logger.info("\nStep 4: Converting STITCH4 IDs to PubChem CIDs...")
    df_merged['pubchem_cid'] = df_merged['stitch4_id'].apply(stitch_to_pubchem_cid)

    n_cid_ok = df_merged['pubchem_cid'].notna().sum()
    n_cid_fail = df_merged['pubchem_cid'].isna().sum()
    logger.info(f"  CID conversion: {n_cid_ok} success, {n_cid_fail} failed")
    quality_report['cid_conversion_success'] = int(n_cid_ok)
    quality_report['cid_conversion_failed'] = int(n_cid_fail)

    df_merged = df_merged.dropna(subset=['pubchem_cid']).reset_index(drop=True)
    df_merged['pubchem_cid'] = df_merged['pubchem_cid'].astype(int)
    _ipath = os.path.join(config.MAIER_DIR, 'maier_step4_with_cids.csv')
    df_merged.to_csv(_ipath, index=False)
    logger.info(f"  Intermediate saved: {_ipath} ({len(df_merged)} rows)")

    # ---------------------------------------------------------------
    # Step 5: Fetch SMILES from PubChem
    # Priority: local CSV -> Drive CSV -> local checkpoint -> PubChem API
    # ---------------------------------------------------------------
    logger.info("\nStep 5: Fetching SMILES from PubChem...")

    smiles_csv_path = os.path.join(config.MAIER_DIR, 'maier_smiles_lookup.csv')
    smiles_ckpt_path = os.path.join(config.CHECKPOINTS_DIR, 'phase1b_smiles_cache.json')
    cid_to_smiles = {}

    # 5a. Check for saved SMILES CSV (local or Drive)
    smiles_loaded = False
    try:
        from utils.gdrive_backup import get_data_manager
        dm = get_data_manager()
        resolved = dm.resolve('maier_smiles_lookup.csv', config.MAIER_DIR)
        if resolved and os.path.exists(resolved):
            import pandas as _pd
            df_smi = _pd.read_csv(resolved)
            if 'pubchem_cid' in df_smi.columns and 'smiles' in df_smi.columns:
                n_valid = df_smi['smiles'].notna().sum()
                if n_valid > 900:
                    cid_to_smiles = {
                        int(row['pubchem_cid']): row['smiles']
                        for _, row in df_smi.iterrows()
                        if pd.notna(row['smiles']) and str(row['smiles']).strip()
                    }
                    logger.info(f"  Loaded {len(cid_to_smiles)} SMILES from saved CSV ({resolved})")
                    smiles_loaded = True
    except Exception as e:
        logger.debug(f"  SMILES CSV load failed: {e}")

    # 5b. Fall back to checkpoint JSON
    if not smiles_loaded:
        smiles_cache = load_checkpoint(smiles_ckpt_path, logger)
        if smiles_cache and 'cid_to_smiles' in smiles_cache:
            cid_to_smiles = {
                int(k): v for k, v in smiles_cache['cid_to_smiles'].items()
                if v is not None and str(v).strip()
            }
            if len(cid_to_smiles) > 900:
                logger.info(f"  Loaded {len(cid_to_smiles)} SMILES from checkpoint")
                smiles_loaded = True
            else:
                logger.warning(f"  Checkpoint has only {len(cid_to_smiles)} valid SMILES, refetching")
                cid_to_smiles = {}

    # 5c. Fetch missing from PubChem
    unique_cids = [int(c) for c in df_merged['pubchem_cid'].unique().tolist()]
    cids_to_fetch = [c for c in unique_cids if c not in cid_to_smiles]

    if cids_to_fetch:
        logger.info(f"  Need to fetch {len(cids_to_fetch)} new CIDs "
                     f"({len(cid_to_smiles)} already have SMILES)")

        # Primary: batch REST API
        new_smiles = fetch_smiles_batch_pubchem(cids_to_fetch)
        # Ensure all keys are Python int
        new_smiles = {int(k): v for k, v in new_smiles.items()}
        cid_to_smiles.update(new_smiles)

        # Fallback: pubchempy for any remaining
        still_missing = [c for c in cids_to_fetch if c not in cid_to_smiles or not cid_to_smiles.get(c)]
        if still_missing:
            logger.info(f"  Trying pubchempy fallback for {len(still_missing)} missing CIDs...")
            fallback_smiles = fetch_smiles_pubchempy_fallback(still_missing)
            fallback_smiles = {int(k): v for k, v in fallback_smiles.items()}
            cid_to_smiles.update(fallback_smiles)

        # Save checkpoint JSON
        save_checkpoint(
            {'cid_to_smiles': {str(k): v for k, v in cid_to_smiles.items()}},
            smiles_ckpt_path, logger,
        )

    # 5d. Validate we actually have SMILES
    n_valid_smiles = sum(1 for v in cid_to_smiles.values() if v and str(v).strip())
    logger.info(f"  Total SMILES available: {n_valid_smiles} (for {len(unique_cids)} unique CIDs)")
    if n_valid_smiles == 0:
        logger.error("  ZERO valid SMILES! PubChem batch API likely returned empty results.")
        logger.error("  Check: curl 'https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/2244/property/CanonicalSMILES/JSON'")
        raise ValueError("No SMILES resolved from PubChem. Cannot continue.")

    # 5e. Save SMILES as a standalone CSV (for Drive backup + future reuse)
    smiles_rows = [
        {'pubchem_cid': int(k), 'smiles': v}
        for k, v in cid_to_smiles.items()
        if v and str(v).strip()
    ]
    df_smiles_out = pd.DataFrame(smiles_rows)
    df_smiles_out.to_csv(smiles_csv_path, index=False)
    logger.info(f"  Saved SMILES lookup: {smiles_csv_path} ({len(df_smiles_out)} entries)")

    # Push to Drive
    try:
        from utils.gdrive_backup import get_data_manager
        get_data_manager().push(smiles_csv_path)
    except Exception:
        pass

    # Map SMILES to dataframe
    # Ensure key types match (pandas 3.x is strict about int vs numpy.int64)
    cid_to_smiles_clean = {int(k): v for k, v in cid_to_smiles.items()
                           if v is not None and str(v).strip()}
    df_merged['raw_smiles'] = df_merged['pubchem_cid'].astype(int).map(cid_to_smiles_clean)

    n_smiles_found = df_merged['raw_smiles'].notna().sum()
    n_smiles_miss = df_merged['raw_smiles'].isna().sum()
    logger.info(f"  SMILES resolved: {n_smiles_found}/{len(df_merged)} "
                f"({n_smiles_miss} missing)")
    quality_report['smiles_resolved'] = int(n_smiles_found)
    quality_report['smiles_missing'] = int(n_smiles_miss)

    # Build lookup log BEFORE dropping missing SMILES
    lookup_log = df_merged[['prestwick_id', 'name', 'stitch4_id',
                             'pubchem_cid', 'raw_smiles']].copy()
    lookup_log['smiles_found'] = lookup_log['raw_smiles'].notna()

    # Drop rows without SMILES
    df_merged = df_merged.dropna(subset=['raw_smiles']).reset_index(drop=True)

    # ---------------------------------------------------------------
    # Step 6: Canonicalize SMILES
    # ---------------------------------------------------------------
    _F6 = "02_process_maier.py:process_maier_data:Step6_canonicalize"
    logger.info(f"\n[{_F6}] Canonicalizing SMILES...")
    canon_results = []
    canon_errors = 0
    n_total = len(df_merged)
    from tqdm import tqdm
    for idx, raw_smi in enumerate(tqdm(df_merged['raw_smiles'], total=n_total,
                                        desc="  Canonicalizing Maier SMILES", unit=" mol")):
        try:
            canon_results.append(canonicalize_smiles(raw_smi))
        except Exception as e:
            canon_results.append(None)
            canon_errors += 1
            if canon_errors <= 5:
                logger.warning(f"  [{_F6}] Row {idx}: canonicalize raised {type(e).__name__}: {e} "
                               f"for SMILES=\'{str(raw_smi)[:60]}\'")

    df_merged['smiles'] = canon_results
    n_canon_ok = df_merged['smiles'].notna().sum()
    n_canon_fail = df_merged['smiles'].isna().sum()
    logger.info(f"  [{_F6}] Canonicalization: {n_canon_ok} success, {n_canon_fail} failed "
                f"({canon_errors} exceptions)")
    quality_report['canonicalization_success'] = int(n_canon_ok)
    quality_report['canonicalization_failed'] = int(n_canon_fail)

    df_merged = df_merged.dropna(subset=['smiles']).reset_index(drop=True)

    if len(df_merged) == 0:
        logger.error(f"  [{_F6}] ALL rows lost after canonicalization/dropna!")
        logger.error(f"  [{_F6}] This means SMILES lookup returned 0 valid SMILES.")
        logger.error(f"  [{_F6}] raw_smiles column had {n_smiles_found} entries before canonicalization.")
        logger.error(f"  [{_F6}] Check PubChem batch API response format.")
        raise ValueError("Zero rows after canonicalization. SMILES lookup likely failed.")

    # Check for duplicate canonical SMILES (different prestwick IDs mapping
    # to the same molecule after salt removal)
    n_before_dedup = len(df_merged)
    df_merged = df_merged.drop_duplicates(subset='smiles', keep='first')
    n_after_dedup = len(df_merged)
    if n_before_dedup != n_after_dedup:
        logger.info(f"  Removed {n_before_dedup - n_after_dedup} duplicate SMILES")
    quality_report['duplicates_removed'] = n_before_dedup - n_after_dedup

    # ---------------------------------------------------------------
    # Step 7: Assign binary harm labels
    # ---------------------------------------------------------------
    _F7 = "02_process_maier.py:process_maier_data:Step7_labels"
    logger.info(f"\n[{_F7}] Assigning binary harm labels...")

    try:
        for t in config.HARM_THRESHOLDS:
            col_name = f'harm_t{t}'
            df_merged[col_name] = (df_merged['n_hit'] >= t).astype(int)
            n_harmful = int(df_merged[col_name].sum())
            n_total = len(df_merged)
            pct = (n_harmful / n_total * 100) if n_total > 0 else 0.0
            logger.info(f"  [{_F7}] Threshold t={t}: {n_harmful} harmful "
                         f"({pct:.1f}%), {len(df_merged) - n_harmful} safe")
            quality_report[f'harmful_t{t}'] = n_harmful
            quality_report[f'safe_t{t}'] = len(df_merged) - n_harmful
    except Exception as e:
        logger.error(f"  [{_F7}] FAILED: {type(e).__name__}: {e}")
        logger.error(f"  [{_F7}] n_hit dtype={df_merged['n_hit'].dtype}, "
                     f"sample values={df_merged['n_hit'].head().tolist()}")
        raise

    # ---------------------------------------------------------------
    # Build final output
    # ---------------------------------------------------------------
    output_cols = [
        'smiles', 'pubchem_cid', 'prestwick_id', 'name',
        'drug_class', 'n_hit',
    ] + [f'harm_t{t}' for t in config.HARM_THRESHOLDS]

    df_final = df_merged[output_cols].copy()
    quality_report['final_compounds'] = len(df_final)

    # n_hit distribution stats
    quality_report['n_hit_stats'] = {
        'mean': round(float(df_final['n_hit'].mean()), 2),
        'median': float(df_final['n_hit'].median()),
        'zero_count': int((df_final['n_hit'] == 0).sum()),
        'zero_pct': round((df_final['n_hit'] == 0).mean() * 100, 1),
    }

    # Drug class distribution
    quality_report['drug_class_distribution'] = (
        df_final['drug_class'].value_counts().to_dict()
    )

    return df_final, lookup_log, quality_report


# ===========================================================================
# Visualization
# ===========================================================================

def generate_phase1b_figures(df: pd.DataFrame):
    """Generate publication-quality figures for Phase 1B."""
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import seaborn as sns

    os.makedirs(config.FIGURES_DIR, exist_ok=True)
    setup_publication_style()

    # 1. n_hit distribution with threshold lines
    plot_nhit_distribution(
        df['n_hit'].values,
        config.HARM_THRESHOLDS,
        f'Distribution of Commensal Harm ($n_{{hit}}$)\n'
        f'{len(df)} compounds, 40 gut bacterial strains',
        os.path.join(config.FIGURES_DIR, 'phase1b_nhit_distribution'),
    )
    logger.info("  Figure: phase1b_nhit_distribution")

    # 2. Class distribution per threshold
    fig, axes = plt.subplots(1, 3, figsize=(14, 4.5))
    for ax, t in zip(axes, config.HARM_THRESHOLDS):
        col = f'harm_t{t}'
        n_harm = int(df[col].sum())
        n_safe = len(df) - n_harm
        bars = ax.bar(
            ['Safe\n(not harmful)', f'Harmful\n($n_{{hit}} \\geq {t}$)'],
            [n_safe, n_harm],
            color=[COLORS['narrow'], COLORS['broad']],
            edgecolor='black', linewidth=0.5, width=0.5,
        )
        for bar, count in zip(bars, [n_safe, n_harm]):
            pct = count / len(df) * 100
            ax.text(bar.get_x() + bar.get_width()/2., bar.get_height() + len(df)*0.01,
                    f'{count}\n({pct:.1f}%)', ha='center', va='bottom', fontsize=10)
        ax.set_title(f'Threshold $t = {t}$', fontsize=12)
        ax.set_ylabel('Number of compounds')
        ax.set_ylim(0, max(n_safe, n_harm) * 1.2)
        sns.despine(ax=ax)

    plt.suptitle('Binary Harm Labels at Three Thresholds', fontsize=14)
    plt.tight_layout()
    save_figure(fig, os.path.join(config.FIGURES_DIR, 'phase1b_harm_thresholds'))
    logger.info("  Figure: phase1b_harm_thresholds")

    # 3. Drug class breakdown
    fig, ax = plt.subplots(figsize=(8, 5))
    class_counts = df['drug_class'].value_counts()
    class_means = df.groupby('drug_class')['n_hit'].mean().reindex(class_counts.index)

    x = np.arange(len(class_counts))
    bars = ax.bar(x, class_counts.values, color=COLORS['rf'],
                  edgecolor='black', linewidth=0.5)

    # Add mean n_hit as text
    for i, (count, mean_nh) in enumerate(zip(class_counts.values, class_means.values)):
        ax.text(i, count + 5, f'$\\overline{{n_{{hit}}}}$={mean_nh:.1f}',
                ha='center', va='bottom', fontsize=8)

    ax.set_xticks(x)
    ax.set_xticklabels(class_counts.index, rotation=30, ha='right')
    ax.set_ylabel('Number of compounds')
    ax.set_title('Compound Distribution by Drug Class\n(with mean $n_{hit}$)')
    sns.despine()
    plt.tight_layout()
    save_figure(fig, os.path.join(config.FIGURES_DIR, 'phase1b_drug_classes'))
    logger.info("  Figure: phase1b_drug_classes")

    # 4. Cumulative n_hit curve
    fig, ax = plt.subplots(figsize=(7, 5))
    nhits_sorted = np.sort(df['n_hit'].values)
    fractions = np.arange(1, len(nhits_sorted) + 1) / len(nhits_sorted)

    ax.plot(nhits_sorted, fractions, color=COLORS['rf'], linewidth=2)

    for t, color in zip(config.HARM_THRESHOLDS, ['#E69F00', '#D55E00', '#CC79A7']):
        frac_at_t = (df['n_hit'] >= t).mean()
        ax.axvline(x=t, color=color, linestyle='--', linewidth=1,
                   label=f'$t={t}$ ({frac_at_t*100:.1f}% harmful)')

    ax.set_xlabel('$n_{hit}$ (number of strains inhibited)')
    ax.set_ylabel('Cumulative fraction of compounds')
    ax.set_title('Cumulative Distribution of Commensal Harm')
    ax.legend(loc='center right')
    ax.set_xlim(-0.5, 40.5)
    ax.set_ylim(0, 1.05)
    sns.despine()
    save_figure(fig, os.path.join(config.FIGURES_DIR, 'phase1b_cumulative_nhit'))
    logger.info("  Figure: phase1b_cumulative_nhit")


# ===========================================================================
# Unit tests
# ===========================================================================

def run_unit_tests() -> bool:
    """Run unit tests for Phase 1B functions (no network calls)."""
    print("Running Phase 1B unit tests...")
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

    # ---- Test stitch_to_pubchem_cid ----
    _assert(stitch_to_pubchem_cid('CID100008646') == 8646,
            "STITCH CID100008646 -> 8646")
    _assert(stitch_to_pubchem_cid('CID100005324') == 5324,
            "STITCH CID100005324 -> 5324")
    _assert(stitch_to_pubchem_cid('CID154687131') == 54687131,
            "STITCH CID154687131 -> 54687131")
    _assert(stitch_to_pubchem_cid('CID100002764') == 2764,
            "STITCH CID100002764 -> 2764 (ciprofloxacin)")
    _assert(stitch_to_pubchem_cid('CID105361912') == 5361912,
            "STITCH CID105361912 -> 5361912 (rifabutin)")
    _assert(stitch_to_pubchem_cid(None) is None, "None input -> None")
    _assert(stitch_to_pubchem_cid('') is None, "Empty string -> None")
    _assert(stitch_to_pubchem_cid('INVALID') is None, "Non-CID string -> None")
    _assert(stitch_to_pubchem_cid('CID') is None, "Too short -> None")

    # ---- Test n_hit label assignment logic ----
    # Simulate a mini-dataset
    test_df = pd.DataFrame({
        'smiles': ['CCO', 'CCN', 'CCC', 'CCCC', 'CCCCC'],
        'pubchem_cid': [1, 2, 3, 4, 5],
        'prestwick_id': ['P1', 'P2', 'P3', 'P4', 'P5'],
        'name': ['A', 'B', 'C', 'D', 'E'],
        'drug_class': ['x'] * 5,
        'n_hit': [0, 4, 5, 10, 25],
    })

    for t in [5, 10, 20]:
        test_df[f'harm_t{t}'] = (test_df['n_hit'] >= t).astype(int)

    _assert(test_df.loc[0, 'harm_t5'] == 0, "n_hit=0 -> harm_t5=0")
    _assert(test_df.loc[1, 'harm_t5'] == 0, "n_hit=4 -> harm_t5=0")
    _assert(test_df.loc[2, 'harm_t5'] == 1, "n_hit=5 -> harm_t5=1 (>=5)")
    _assert(test_df.loc[3, 'harm_t10'] == 1, "n_hit=10 -> harm_t10=1 (>=10)")
    _assert(test_df.loc[3, 'harm_t20'] == 0, "n_hit=10 -> harm_t20=0 (<20)")
    _assert(test_df.loc[4, 'harm_t20'] == 1, "n_hit=25 -> harm_t20=1 (>=20)")

    # ---- Test data reading (if files available) ----
    moesm5_path = os.path.join(
        config.MAIER_DIR, config.MAIER_FILES['moesm5_2018']
    )
    if os.path.exists(moesm5_path):
        df_labels = read_moesm5_training_labels(moesm5_path)
        _assert(len(df_labels) == 1197,
                f"MOESM5 row count: {len(df_labels)} (expected 1197)")
        _assert('n_hit' in df_labels.columns, "MOESM5 has n_hit column")
        _assert(df_labels['n_hit'].min() >= 0, "n_hit min >= 0")
        _assert(df_labels['n_hit'].max() <= 40, "n_hit max <= 40")

        moesm3_path = os.path.join(
            config.MAIER_DIR, config.MAIER_FILES['moesm3_2018']
        )
        if os.path.exists(moesm3_path):
            df_ids = read_moesm3_id_mapping(moesm3_path)
            _assert(len(df_ids) == 1200,
                    f"MOESM3 row count: {len(df_ids)} (expected 1200)")

            # Test join
            df_merged = df_labels.merge(df_ids, on='prestwick_id', how='left')
            n_matched = df_merged['stitch4_id'].notna().sum()
            _assert(n_matched >= 1190,
                    f"Join matched {n_matched}/1197 (expected ~1197)")
    else:
        print("  [SKIP] Maier Excel files not found (run on Ada)")

    print(f"\nUnit tests: {n_pass} passed, {n_fail} failed")
    return n_fail == 0


# ===========================================================================
# Main
# ===========================================================================

def main():
    """Main entry point for Phase 1B."""
    _F = "02_process_maier.py:main"

    # Run unit tests first
    logger.info(f"[{_F}] Running unit tests before data processing...")
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

    start_time = log_phase_start(logger, "Phase 1B: Maier Commensal Harm Data Processing")

    # Create directories
    for d in [config.MAIER_DIR, config.CHECKPOINTS_DIR, config.FIGURES_DIR, config.REPORTS_DIR]:
        os.makedirs(d, exist_ok=True)

    # Check Excel files exist BEFORE doing anything
    from utils.data_cache import DataCache
    cache = DataCache(config.PROJECT_DIR, logger)

    moesm5_name = '41586_2018_BFnature25979_MOESM5_ESM.xlsx'
    moesm3_name = '41586_2018_BFnature25979_MOESM3_ESM.xlsx'
    moesm5_path = os.path.join(config.MAIER_DIR, moesm5_name)
    moesm3_path = os.path.join(config.MAIER_DIR, moesm3_name)

    # Auto-copy from resources/maier/ if files aren't in data/maier/
    resources_maier = os.path.join(config.PROJECT_DIR, 'resources', 'maier')
    for fname in [moesm5_name, moesm3_name]:
        dest = os.path.join(config.MAIER_DIR, fname)
        src = os.path.join(resources_maier, fname)
        if not os.path.exists(dest) and os.path.exists(src):
            import shutil
            shutil.copy2(src, dest)
            logger.info(f"[{_F}] Copied {fname} from resources/maier/ to data/maier/")

    for fpath, label in [(moesm5_path, 'MOESM5'), (moesm3_path, 'MOESM3')]:
        if not os.path.exists(fpath):
            logger.error(f"[{_F}] MISSING: {label} file: {fpath}")
            logger.error(f"[{_F}] Also checked: {os.path.join(resources_maier, os.path.basename(fpath))}")
            logger.error(f"[{_F}] ACTION: Place Maier Excel files in data/maier/ or resources/maier/")
            logger.error(f"[{_F}] Files in data/maier/: {os.listdir(config.MAIER_DIR)}")
            sys.exit(1)

    # Check cache for existing output
    cache_key = 'maier/maier_combined.csv'
    if cache.is_valid(cache_key, min_rows=900):
        logger.info(f"[{_F}] Cache HIT for Maier data, loading from disk")
        csv_path = cache.get_path(cache_key)
        try:
            df_check = pd.read_csv(csv_path)
            harm_cols = [f'harm_t{t}' for t in config.HARM_THRESHOLDS]
            if all(c in df_check.columns for c in ['smiles', 'n_hit'] + harm_cols):
                logger.info(f"[{_F}] Cached data valid: {len(df_check)} compounds")
                log_phase_end(logger, "Phase 1B (from cache)", start_time)
                return
        except Exception as e:
            logger.warning(f"[{_F}] Cache validation failed: {e}, reprocessing")

    # Try local -> Drive before PubChem lookup
    try:
        from utils.gdrive_backup import get_data_manager
        dm = get_data_manager()
        csv_path_local = os.path.join(config.MAIER_DIR, 'maier_combined.csv')
        restored = dm.resolve('maier_combined.csv', config.MAIER_DIR)
        if restored:
            df_check = pd.read_csv(restored)
            harm_cols = [f'harm_t{t}' for t in config.HARM_THRESHOLDS]
            if all(c in df_check.columns for c in ['smiles', 'n_hit'] + harm_cols) and len(df_check) > 900:
                logger.info(f"[{_F}] Found Maier data: {len(df_check)} compounds (from {restored})")
                cache.register(cache_key, n_rows=len(df_check),
                               description='Maier commensal data')
                log_phase_end(logger, "Phase 1B (from cache/Drive)", start_time)
                return
            # Also try to restore raw Excel files from Drive
            dm.resolve_maier_excel(config.MAIER_DIR)
    except Exception:
        pass  # Fall through to normal processing

    # Test PubChem connectivity (needed for SMILES lookup)
    from utils.network_utils import test_connectivity
    logger.info(f"[{_F}] Testing PubChem connectivity...")
    conn = test_connectivity(logger, urls=[
        'https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/2244/property/CanonicalSMILES/JSON',
    ])

    # Run the pipeline
    try:
        df_final, lookup_log, quality_report = process_maier_data()
    except Exception as e:
        logger.error(f"[{_F}] process_maier_data() FAILED: {type(e).__name__}: {e}")
        import traceback
        logger.error(traceback.format_exc())
        sys.exit(1)

    if len(df_final) == 0:
        logger.error(f"[{_F}] No compounds produced! Check data files and network.")
        sys.exit(1)

    # Save outputs
    try:
        csv_path = os.path.join(config.MAIER_DIR, 'maier_combined.csv')
        df_final.to_csv(csv_path, index=False)
        logger.info(f"\n[{_F}] Saved: {csv_path} ({len(df_final)} compounds)")
        cache.register(cache_key, n_rows=len(df_final), description='Maier commensal harm data')
        # Back up to Google Drive (processed CSV + raw Excel files)
        try:
            from utils.gdrive_backup import get_data_manager
            dm = get_data_manager()
            dm.push(csv_path)
            dm.push_maier_excel(config.MAIER_DIR)
        except Exception:
            pass

        log_path = os.path.join(config.MAIER_DIR, 'smiles_lookup_log.csv')
        lookup_log.to_csv(log_path, index=False)
        logger.info(f"[{_F}] Saved: {log_path}")
        # Also push lookup log to Drive
        try:
            from utils.gdrive_backup import get_data_manager
            get_data_manager().push(log_path)
        except Exception:
            pass
    except Exception as e:
        logger.error(f"[{_F}] Save FAILED: {type(e).__name__}: {e}")
        raise

    log_dataframe_summary(logger, df_final, 'maier_combined')

    # Generate figures (non-critical)
    logger.info(f"\n[{_F}] Generating Phase 1B figures...")
    try:
        generate_phase1b_figures(df_final)
    except Exception as e:
        logger.warning(f"[{_F}] Figure generation failed (non-critical): {e}")

    # Save quality report (non-critical)
    try:
        report_path = os.path.join(config.REPORTS_DIR, 'phase1b_quality_report.json')
        with open(report_path, 'w') as f:
            json.dump(quality_report, f, indent=2, default=str)
        logger.info(f"[{_F}] Quality report saved: {report_path}")
    except Exception as e:
        logger.warning(f"[{_F}] Report save failed (non-critical): {e}")

    # Print summary
    logger.info("\n" + "=" * 60)
    logger.info(" PHASE 1B SUMMARY")
    logger.info("=" * 60)
    logger.info(f"  MOESM5 compounds:     {quality_report.get('moesm5_compounds', '?')}")
    logger.info(f"  With STITCH4 ID:      {quality_report.get('with_stitch_id', '?')}")
    logger.info(f"  SMILES resolved:      {quality_report.get('smiles_resolved', '?')}")
    logger.info(f"  After canonicalization: {quality_report.get('canonicalization_success', '?')}")
    logger.info(f"  Final unique compounds: {quality_report.get('final_compounds', '?')}")
    logger.info(f"  ")
    for t in config.HARM_THRESHOLDS:
        n_h = quality_report.get(f'harmful_t{t}', '?')
        n_s = quality_report.get(f'safe_t{t}', '?')
        logger.info(f"  Threshold t={t}: {n_h} harmful, {n_s} safe")
    logger.info("=" * 60)

    # Update abstract corrections
    logger.info("\n  ABSTRACT CORRECTION: The combined dataset contains "
                f"{quality_report.get('final_compounds', '?')} unique compounds "
                f"(not 979 as stated in the draft abstract).")

    # Save master checkpoint
    save_checkpoint(
        {
            'status': 'complete',
            'quality_report': quality_report,
            'final_compounds': quality_report.get('final_compounds', 0),
        },
        os.path.join(config.CHECKPOINTS_DIR, 'phase1b_master.json'),
        logger,
    )

    # Save quality report as standalone JSON
    import json as _json
    report_path = os.path.join(config.MAIER_DIR, 'phase1b_quality_report.json')
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

    log_phase_end(logger, "Phase 1B", start_time)


if __name__ == '__main__':
    main()
