"""
alternative_data.py -- Fallback data acquisition paths.

When primary APIs (ChEMBL, PubChem, S3) are blocked or unreliable on compute
nodes, these functions provide alternative download methods:

  1. ChEMBL: Direct FTP/HTTPS download of pre-built SQLite or TSV dumps
  2. PubChem: Batch SDF download instead of REST API
  3. Hub: Alternative mirror URLs

Also provides a function to generate synthetic test data for local testing
without any network access.

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import os
import sys
import logging
import time
from typing import Optional

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(SCRIPT_DIR))
import config


# ===========================================================================
# Alternative ChEMBL data paths
# ===========================================================================

CHEMBL_ALTERNATIVE_URLS = {
    # ChEMBL FTP bulk download (works when API is blocked)
    'ftp_tsv': 'https://ftp.ebi.ac.uk/pub/databases/chembl/ChEMBLdb/latest/',
    # ChEMBL web interface CSV export (manual fallback)
    'web_export': 'https://www.ebi.ac.uk/chembl/g/#browse/activities',
}

CHEMBL_TARGET_URLS = {
    'ecoli': 'https://www.ebi.ac.uk/chembl/api/data/activity.json?target_chembl_id=CHEMBL354&standard_type=MIC&limit=1000&format=json',
    'saureus': 'https://www.ebi.ac.uk/chembl/api/data/activity.json?target_chembl_id=CHEMBL352&standard_type=MIC&limit=1000&format=json',
    'paeruginosa': 'https://www.ebi.ac.uk/chembl/api/data/activity.json?target_chembl_id=CHEMBL348&standard_type=MIC&limit=1000&format=json',
    'mtb': 'https://www.ebi.ac.uk/chembl/api/data/activity.json?target_chembl_id=CHEMBL360&standard_type=MIC&limit=1000&format=json',
}

def fetch_chembl_via_json_api(target_chembl_id: str, standard_type: str,
                               logger: logging.Logger) -> 'pd.DataFrame':
    """
    Fallback: Fetch ChEMBL data via direct JSON REST API instead of Python client.
    Works when chembl_webresource_client is broken but HTTP access works.
    """
    import requests
    import pandas as pd

    _F = "alternative_data.py:fetch_chembl_via_json_api"
    base_url = "https://www.ebi.ac.uk/chembl/api/data/activity.json"

    all_records = []
    offset = 0
    limit = 1000

    logger.info(f"  [{_F}] Fetching via JSON API: target={target_chembl_id}, type={standard_type}")

    while True:
        url = (f"{base_url}?target_chembl_id={target_chembl_id}"
               f"&standard_type={standard_type}&limit={limit}&offset={offset}&format=json")
        try:
            resp = requests.get(url, timeout=120)
            if resp.status_code != 200:
                logger.warning(f"  [{_F}] HTTP {resp.status_code} at offset {offset}")
                break

            data = resp.json()
            activities = data.get('activities', [])
            if not activities:
                break

            for act in activities:
                all_records.append({
                    'canonical_smiles': act.get('canonical_smiles'),
                    'standard_value': act.get('standard_value'),
                    'standard_units': act.get('standard_units'),
                    'standard_relation': act.get('standard_relation'),
                    'molecule_chembl_id': act.get('molecule_chembl_id'),
                    'assay_chembl_id': act.get('assay_chembl_id'),
                    'document_chembl_id': act.get('document_chembl_id'),
                    'pchembl_value': act.get('pchembl_value'),
                })

            offset += limit
            logger.info(f"  [{_F}] Fetched {len(all_records)} records so far (offset={offset})")

            # Check if there are more pages
            if len(activities) < limit:
                break
            time.sleep(0.5)  # Rate limiting

        except Exception as e:
            logger.warning(f"  [{_F}] Error at offset {offset}: {type(e).__name__}: {e}")
            break

    logger.info(f"  [{_F}] Total: {len(all_records)} records for {target_chembl_id}/{standard_type}")
    return pd.DataFrame(all_records)


# ===========================================================================
# Alternative PubChem paths
# ===========================================================================

PUBCHEM_BATCH_URL = "https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/{cids}/property/CanonicalSMILES/JSON"

def fetch_pubchem_smiles_batch_alt(cids: list, logger: logging.Logger,
                                    batch_size: int = 50) -> dict:
    """
    Alternative PubChem SMILES lookup using comma-separated CID batches.
    Smaller batches (50 instead of 100) for more reliable responses.
    """
    import requests

    _F = "alternative_data.py:fetch_pubchem_smiles_batch_alt"
    results = {}
    n_total = len(cids)

    for i in range(0, n_total, batch_size):
        batch = cids[i:i+batch_size]
        cid_str = ','.join(str(c) for c in batch)
        url = PUBCHEM_BATCH_URL.format(cids=cid_str)

        for attempt in range(3):
            try:
                resp = requests.get(url, timeout=60)
                if resp.status_code == 200:
                    data = resp.json()
                    for prop in data.get('PropertyTable', {}).get('Properties', []):
                        cid = prop.get('CID')
                        smi = prop.get('CanonicalSMILES')
                        if cid and smi:
                            results[int(cid)] = smi
                    break
                elif resp.status_code == 404:
                    logger.debug(f"  [{_F}] Batch {i//batch_size}: some CIDs not found (404)")
                    break
                else:
                    logger.warning(f"  [{_F}] HTTP {resp.status_code} for batch {i//batch_size}")
            except Exception as e:
                logger.warning(f"  [{_F}] Batch {i//batch_size} attempt {attempt+1}: {e}")
                time.sleep(2 ** attempt)

        if (i + batch_size) % 500 == 0:
            logger.info(f"  [{_F}] Progress: {min(i+batch_size, n_total)}/{n_total} CIDs, "
                        f"{len(results)} resolved")
        time.sleep(0.3)  # Rate limiting

    logger.info(f"  [{_F}] Resolved {len(results)}/{n_total} CIDs")
    return results


# ===========================================================================
# Alternative Hub URLs
# ===========================================================================

HUB_ALTERNATIVE_URLS = {
    'drugs': [
        'https://s3.amazonaws.com/data.clue.io/repurposing/downloads/repurposing_drugs_20200324.txt',
        # If S3 is blocked, try the repo-hub directly (may also be blocked on Ada)
    ],
    'samples': [
        'https://s3.amazonaws.com/data.clue.io/repurposing/downloads/repurposing_samples_20200324.txt',
    ],
}


# ===========================================================================
# Synthetic test data for local testing without network
# ===========================================================================

def generate_synthetic_data(output_dir: str, logger: logging.Logger):
    """
    Generate synthetic test data for all phases so the pipeline can be
    tested locally without network access or GPU.

    Uses config.CHEMBL_DIR, config.MAIER_DIR, config.HUB_DIR which
    respect ANTIBIOTIC_DATA_MODE (synthetic -> synthetic/data/, real -> data/).
    """
    import numpy as np
    import pandas as pd
    from rdkit import Chem

    _F = "alternative_data.py:generate_synthetic_data"
    logger.info(f"  [{_F}] Generating synthetic test data...")
    logger.info(f"  [{_F}] ChEMBL dir: {config.CHEMBL_DIR}")
    logger.info(f"  [{_F}] Maier dir:  {config.MAIER_DIR}")
    logger.info(f"  [{_F}] Hub dir:    {config.HUB_DIR}")

    np.random.seed(42)

    # Known drug SMILES for realistic data
    DRUG_SMILES = {
        'ethanol': 'CCO', 'aspirin': 'CC(=O)Oc1ccccc1C(=O)O',
        'caffeine': 'Cn1c(=O)c2c(ncn2C)n(C)c1=O',
        'ibuprofen': 'CC(C)Cc1ccc(cc1)C(C)C(=O)O',
        'acetaminophen': 'CC(=O)Nc1ccc(O)cc1',
        'ciprofloxacin': 'O=C(O)c1cc(N2CCNCC2)c2cc(F)c(=O)c(n2)c1=O',
        'metformin': 'CN(C)C(=N)NC(=N)N',
        'amoxicillin': 'CC1(C)SC2C(NC(=O)C(N)c3ccc(O)cc3)C(=O)N2C1C(=O)O',
        'benzene': 'c1ccccc1', 'phenol': 'Oc1ccccc1',
        'toluene': 'Cc1ccccc1', 'aniline': 'Nc1ccccc1',
        'naphthalene': 'c1ccc2ccccc2c1', 'pyridine': 'c1ccncc1',
        'furan': 'c1ccoc1', 'thiophene': 'c1ccsc1',
        'indole': 'c1ccc2[nH]ccc2c1', 'quinoline': 'c1ccc2ncccc2c1',
    }

    # Fragments that produce valid SMILES when concatenated (no bare halogens)
    # Each is a valid molecule by itself, and concatenation produces valid larger molecules
    valid_smiles_pool = [
        'CCO', 'CCCO', 'CC(C)O', 'CCC', 'CCCC', 'CCCCC', 'CCCCCC',
        'CC=O', 'CCC=O', 'CC(=O)C', 'CC(=O)O', 'CC(=O)N',
        'c1ccccc1', 'c1ccc(O)cc1', 'c1ccc(N)cc1', 'c1ccc(C)cc1',
        'c1ccncc1', 'c1ccoc1', 'c1ccsc1', 'c1ccc2ccccc2c1',
        'C1CCCCC1', 'C1CCCC1', 'C1CCC1',
        'OC(=O)C', 'NCC', 'NCCO', 'OCC', 'SCC',
        'CC(N)C(=O)O', 'CCOC(=O)C', 'CC(O)CC',
        'c1ccc(-c2ccccc2)cc1', 'c1ccc2[nH]ccc2c1', 'c1ccc2ncccc2c1',
        'CC(F)(F)F', 'ClCCCl', 'c1ccc(Cl)cc1', 'c1ccc(F)cc1',
        'c1ccc(Br)cc1', 'CC#N', 'C=CC=C', 'CC=CC',
        'OC(=O)c1ccccc1', 'Cc1ccc(O)cc1', 'CCN(CC)CC',
    ]

    def random_smiles(n=200):
        smiles_list = list(DRUG_SMILES.values())
        while len(smiles_list) < n:
            smi = np.random.choice(valid_smiles_pool)
            mol = Chem.MolFromSmiles(smi)
            if mol:
                smiles_list.append(Chem.MolToSmiles(mol))
            else:
                smiles_list.append('CCO')  # Safe fallback
        return smiles_list[:n]

    # ---- Phase 1A: ChEMBL pathogen data ----
    os.makedirs(config.CHEMBL_DIR, exist_ok=True)

    for pkey, pinfo in config.PATHOGENS.items():
        n = 200  # Small synthetic set
        smiles = random_smiles(n)
        df = pd.DataFrame({
            'smiles': smiles,
            'median_value_nM': np.random.lognormal(mean=8, sigma=2, size=n),
            'activity_label': np.random.binomial(1, 0.3, size=n),
            'molecule_chembl_id': [f'CHEMBL{np.random.randint(100000,999999)}' for _ in range(n)],
            'n_measurements': np.random.randint(1, 10, size=n),
            'source_type': 'MIC',
        })
        csv_path = os.path.join(config.CHEMBL_DIR, pinfo['csv_filename'])
        df.to_csv(csv_path, index=False)
        logger.info(f"  [{_F}] Created: {csv_path} ({n} rows)")

    # ---- Phase 1B: Maier commensal data ----
    os.makedirs(config.MAIER_DIR, exist_ok=True)

    n_maier = 150
    smiles = random_smiles(n_maier)
    n_hits = np.random.choice([0]*100 + list(range(1, 41))*5, size=n_maier)
    df_maier = pd.DataFrame({
        'smiles': smiles,
        'pubchem_cid': np.random.randint(1000, 99999, size=n_maier),
        'prestwick_id': [f'Prestwick-{i:04d}' for i in range(n_maier)],
        'name': [f'drug_{i}' for i in range(n_maier)],
        'drug_class': np.random.choice(['antibiotic', 'antifungal', 'NSAID', 'other'], size=n_maier),
        'n_hit': n_hits,
        'harm_t5': (n_hits >= 5).astype(int),
        'harm_t10': (n_hits >= 10).astype(int),
        'harm_t20': (n_hits >= 20).astype(int),
    })
    csv_path = os.path.join(config.MAIER_DIR, 'maier_combined.csv')
    df_maier.to_csv(csv_path, index=False)
    logger.info(f"  [{_F}] Created: {csv_path} ({n_maier} rows)")

    # ---- Phase 1C: Hub screening library ----
    os.makedirs(config.HUB_DIR, exist_ok=True)

    n_hub = 500
    smiles = random_smiles(n_hub)
    moa_choices = ['antibiotic', 'antibacterial', 'NSAID', 'antiviral',
                   'kinase inhibitor', 'GPCR agonist', '', 'other']
    phase_choices = ['Phase 1', 'Phase 2', 'Phase 3', 'Launched', 'Preclinical', '']

    # Insert known validation drugs at known positions
    known_drugs = {
        'ciprofloxacin': 'O=C(O)c1cc(N2CCNCC2)c2cc(F)c(=O)c(n2)c1=O',
        'daptomycin': 'CCCCCCCCCC(=O)NC1CC(=O)NC(CC(=O)O)C(=O)NC(CCCN)C(=O)NC(C)C(=O)NC2C(=O)NC(CC(=O)c3ccccc3)C(=O)NC(CC(=O)O)C(=O)NC(C(C)O)C(=O)NC(CC(C)C)C(=O)OC2C(=O)NC(CC(=O)O)C(=O)NC(CCCN)C(=O)N1',
        'amoxicillin': 'CC1(C)SC2C(NC(=O)C(N)c3ccc(O)cc3)C(=O)N2C1C(=O)O',
        'doxycycline': 'CC1C2C(O)C3C(=O)C(=C(O)C(=C3C(O)=C2C(=O)C(N(C)C)C1O)O)C(N)=O',
        'nitrofurantoin': 'O=C1CN(/N=C/c2ccc(o2)[N+](=O)[O-])C(=O)N1',
        'methenamine': 'C1N2CN3CN1CN(C2)C3',
        'chloramphenicol': 'OC(c1ccc([N+](=O)[O-])cc1)C(CO)NC(=O)C(Cl)Cl',
        'rifabutin': 'CC1C=CC=C(C)C(OC2OC(C)C(O)C(OC)C2O)C(C)=CC=CC(OC(=O)C)C3(O)C(=O)NC(=CC1=O)C(=O)C3(C)O',
    }
    for i, (name, smi) in enumerate(known_drugs.items()):
        if i < n_hub:
            smiles[i] = smi

    drug_names = [f'compound_{i}' for i in range(n_hub)]
    for i, name in enumerate(known_drugs.keys()):
        if i < n_hub:
            drug_names[i] = name

    df_hub = pd.DataFrame({
        'smiles': smiles,
        'name': drug_names,
        'clinical_phase': np.random.choice(phase_choices, size=n_hub),
        'moa': np.random.choice(moa_choices, size=n_hub),
        'disease_area': '',
        'target': '',
        'indication': '',
        'inchikey': '',
        'pubchem_cid': '',
    })
    # Set known drugs' MOAs correctly
    df_hub.loc[df_hub['name'] == 'ciprofloxacin', 'moa'] = 'fluoroquinolone antibiotic'
    df_hub.loc[df_hub['name'] == 'amoxicillin', 'moa'] = 'penicillin antibiotic'
    df_hub.loc[df_hub['name'] == 'daptomycin', 'moa'] = 'antibacterial lipopeptide'
    df_hub.loc[df_hub['name'] == 'doxycycline', 'moa'] = 'tetracycline antibiotic'

    csv_path = os.path.join(config.HUB_DIR, config.HUB_CLEAN_FILENAME)
    df_hub.to_csv(csv_path, index=False)
    logger.info(f"  [{_F}] Created: {csv_path} ({n_hub} rows)")

    logger.info(f"  [{_F}] Synthetic data generation complete.")
    logger.info(f"  [{_F}] This data is for TESTING ONLY, not for real analysis.")


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger('alt_data')
    import tempfile
    with tempfile.TemporaryDirectory() as tmpdir:
        generate_synthetic_data(tmpdir, logger)
        print(f"Generated synthetic data in {tmpdir}")
        for root, dirs, files in os.walk(tmpdir):
            for f in files:
                path = os.path.join(root, f)
                size = os.path.getsize(path)
                print(f"  {os.path.relpath(path, tmpdir)}: {size:,} bytes")
