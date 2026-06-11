#!/usr/bin/env python3
"""
00_verify_environment.py -- Comprehensive verification of the Ada environment.

Checks:
  1. Python packages and versions
  2. Directory structure
  3. Maier data files (existence and sheet structure)
  4. Network connectivity to required APIs
  5. GPU availability (informational)
  6. Disk quota
  7. Unit tests for utility modules

Run on Ada login node:
    source ~/antibiotic-selectivity/venv/bin/activate
    python scripts/00_verify_environment.py

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import os
import sys
import json
import time
import importlib
from pathlib import Path

# ===========================================================================
# Configuration
# ===========================================================================
PROJECT_DIR = os.path.expanduser("~/antibiotic-selectivity")
SCRIPTS_DIR = os.path.join(PROJECT_DIR, "scripts")

# Add scripts to path so we can import config
sys.path.insert(0, SCRIPTS_DIR)

# ===========================================================================
# Test infrastructure
# ===========================================================================
class TestResult:
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.warnings = 0
        self.details = []

    def ok(self, category, msg):
        self.passed += 1
        self.details.append(('PASS', category, msg))
        print(f"  [PASS] {msg}")

    def fail(self, category, msg):
        self.failed += 1
        self.details.append(('FAIL', category, msg))
        print(f"  [FAIL] {msg}")

    def warn(self, category, msg):
        self.warnings += 1
        self.details.append(('WARN', category, msg))
        print(f"  [WARN] {msg}")

    def summary(self):
        total = self.passed + self.failed
        print(f"\n{'='*60}")
        print(f" VERIFICATION SUMMARY")
        print(f"{'='*60}")
        print(f"  Passed:   {self.passed}/{total}")
        print(f"  Failed:   {self.failed}/{total}")
        print(f"  Warnings: {self.warnings}")
        if self.failed == 0:
            print(f"\n  STATUS: ALL CHECKS PASSED. Environment is ready.")
        else:
            print(f"\n  STATUS: {self.failed} CHECKS FAILED. Fix issues above before proceeding.")
            print(f"\n  Failed checks:")
            for status, cat, msg in self.details:
                if status == 'FAIL':
                    print(f"    - [{cat}] {msg}")
        print(f"{'='*60}")
        return self.failed == 0


results = TestResult()


# ===========================================================================
# 1. Python packages
# ===========================================================================
print("\n[1/7] Checking Python packages...")

REQUIRED_PACKAGES = {
    'numpy': '1.24',
    'pandas': '2.0',
    'scipy': '1.10',
    'sklearn': '1.3',
    'rdkit': None,
    'chembl_webresource_client': None,
    'pubchempy': None,
    'openpyxl': '3.1',
    'requests': '2.28',
    'joblib': '1.2',
    'tqdm': '4.60',
    'matplotlib': '3.7',
    'seaborn': '0.12',
    'torch': '2.0',
    'chemprop': None,
}

for pkg_name, min_version in REQUIRED_PACKAGES.items():
    try:
        if pkg_name == 'sklearn':
            mod = importlib.import_module('sklearn')
            ver = mod.__version__
        elif pkg_name == 'rdkit':
            from rdkit import Chem
            ver = "OK"
        elif pkg_name == 'chemprop':
            mod = importlib.import_module('chemprop')
            ver = getattr(mod, '__version__', 'imported OK')
        else:
            mod = importlib.import_module(pkg_name)
            ver = getattr(mod, '__version__', 'imported OK')

        if min_version and ver != 'imported OK' and ver != 'OK':
            from packaging.version import Version
            try:
                if Version(ver) < Version(min_version):
                    results.warn('packages', f"{pkg_name} {ver} (wanted >= {min_version})")
                    continue
            except Exception:
                pass  # Skip version check if packaging not available

        results.ok('packages', f"{pkg_name}: {ver}")
    except ImportError as e:
        results.fail('packages', f"{pkg_name}: NOT INSTALLED ({e})")
    except Exception as e:
        results.fail('packages', f"{pkg_name}: ERROR ({e})")


# ===========================================================================
# 2. Directory structure
# ===========================================================================
print("\n[2/7] Checking directory structure...")

REQUIRED_DIRS = [
    'data/chembl', 'data/maier', 'data/repurposing_hub',
    'data/features', 'data/splits',
    'models/rf', 'models/dmpnn',
    'models/dmpnn/ecoli', 'models/dmpnn/saureus',
    'models/dmpnn/paeruginosa', 'models/dmpnn/mtb',
    'models/dmpnn/gut_t5', 'models/dmpnn/gut_t10', 'models/dmpnn/gut_t20',
    'results/screening', 'results/figures', 'results/reports',
    'scripts/utils', 'logs', 'jobs', 'checkpoints',
]

for d in REQUIRED_DIRS:
    full_path = os.path.join(PROJECT_DIR, d)
    if os.path.isdir(full_path):
        results.ok('dirs', f"{d}/")
    else:
        results.fail('dirs', f"{d}/ -- MISSING")


# ===========================================================================
# 3. Maier data files
# ===========================================================================
print("\n[3/7] Checking Maier data files...")

MAIER_EXPECTED_FILES = {
    '41586_2018_BFnature25979_MOESM3_ESM.xlsx': {
        'sheets': ['S1a. Prestwick_Libery'],
        'description': 'ID mapping (1200 drugs, STITCH4 IDs)',
    },
    '41586_2018_BFnature25979_MOESM5_ESM.xlsx': {
        'sheets': ['S3a. Adjusted p-values'],
        'description': 'Training labels (1197 drugs, n_hit)',
    },
    '41586_2021_3986_MOESM3_ESM.xlsx': {
        'sheets': ['S2. AB annotation', 'S4. MICs'],
        'description': 'Antibiotic metadata + quantitative MICs',
    },
    '41586_2021_3986_MOESM11_ESM.xlsx': {
        'sheets': ['EDFig1'],
        'description': 'Binary screen (144 antibiotics x 40 strains)',
    },
    '41586_2021_3986_MOESM12_ESM.xlsx': {
        'sheets': ['EDFig2'],
        'description': 'Quantitative MICs for validation',
    },
    '41586_2021_3986_MOESM13_ESM.xlsx': {
        'sheets': ['Panel_b'],
        'description': 'Cross-validation (489 MIC comparisons)',
    },
    '41586_2021_3986_MOESM14_ESM.xlsx': {
        'sheets': ['Panel_a'],
        'description': 'n_hit per antibiotic by EUCAST class',
    },
}

maier_dir = os.path.join(PROJECT_DIR, "data", "maier")

for filename, info in MAIER_EXPECTED_FILES.items():
    filepath = os.path.join(maier_dir, filename)
    if os.path.exists(filepath):
        # Try to open and verify sheets
        try:
            import openpyxl
            wb = openpyxl.load_workbook(filepath, read_only=True)
            actual_sheets = wb.sheetnames
            wb.close()

            missing_sheets = [s for s in info['sheets'] if s not in actual_sheets]
            if missing_sheets:
                results.warn('maier', f"{filename}: missing sheets {missing_sheets}")
            else:
                results.ok('maier', f"{filename} ({info['description']})")
        except Exception as e:
            results.warn('maier', f"{filename}: exists but cannot read ({e})")
    else:
        results.fail('maier', f"{filename} -- NOT FOUND in {maier_dir}")


# ===========================================================================
# 4. Network connectivity
# ===========================================================================
print("\n[4/7] Checking network connectivity...")

import requests

ENDPOINTS = {
    'ChEMBL API': 'https://www.ebi.ac.uk/chembl/api/data/activity.json?limit=1',
    'PubChem REST': 'https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/2244/property/CanonicalSMILES/JSON',
    'Drug Repurposing Hub (S3)': 'https://s3.amazonaws.com/data.clue.io/repurposing/downloads/repurposing_drugs_20200324.txt',
}

for name, url in ENDPOINTS.items():
    try:
        resp = requests.head(url, timeout=15, allow_redirects=True)
        if resp.status_code < 400:
            results.ok('network', f"{name}: HTTP {resp.status_code}")
        else:
            results.warn('network', f"{name}: HTTP {resp.status_code}")
    except requests.exceptions.Timeout:
        results.warn('network', f"{name}: TIMEOUT (may work from compute nodes)")
    except Exception as e:
        results.warn('network', f"{name}: {type(e).__name__} (may work from compute nodes)")


# ===========================================================================
# 5. GPU availability
# ===========================================================================
print("\n[5/7] Checking GPU availability (informational)...")

try:
    import torch
    if torch.cuda.is_available():
        gpu_name = torch.cuda.get_device_name(0)
        gpu_mem = torch.cuda.get_device_properties(0).total_memory / (1024**3)
        results.ok('gpu', f"CUDA available: {gpu_name} ({gpu_mem:.1f} GB)")
    else:
        results.warn('gpu', "CUDA not available on login node (expected, GPUs are on compute nodes)")
except ImportError:
    results.fail('gpu', "PyTorch not installed")
except Exception as e:
    results.warn('gpu', f"GPU check error: {e}")


# ===========================================================================
# 6. Disk quota
# ===========================================================================
print("\n[6/7] Checking disk usage...")

try:
    import subprocess
    quota_out = subprocess.run(
        ['quota', '-u', os.environ.get('USER', 'unknown')],
        capture_output=True, text=True, timeout=10
    )
    if quota_out.returncode == 0:
        results.ok('disk', f"Quota check successful")
        for line in quota_out.stdout.strip().split('\n'):
            if '/home2' in line or '/share1' in line:
                print(f"    {line.strip()}")
    else:
        results.warn('disk', "Could not check quota")
except Exception as e:
    results.warn('disk', f"Quota check failed: {e}")

# Show project size
try:
    import subprocess
    du_out = subprocess.run(
        ['du', '-sh', PROJECT_DIR],
        capture_output=True, text=True, timeout=10
    )
    if du_out.returncode == 0:
        print(f"    Project size: {du_out.stdout.strip()}")
except Exception:
    pass


# ===========================================================================
# 7. Utility module unit tests
# ===========================================================================
print("\n[7/7] Running utility module unit tests...")

# Test smiles_utils
try:
    sys.path.insert(0, os.path.join(SCRIPTS_DIR, 'utils'))
    from smiles_utils import _run_tests as test_smiles
    if test_smiles():
        results.ok('unit_tests', "smiles_utils: all tests passed")
    else:
        results.fail('unit_tests', "smiles_utils: some tests failed")
except Exception as e:
    results.fail('unit_tests', f"smiles_utils: import/test error ({e})")

# Test scaffold_split
try:
    from scaffold_split import _run_tests as test_scaffold
    if test_scaffold():
        results.ok('unit_tests', "scaffold_split: all tests passed")
    else:
        results.fail('unit_tests', "scaffold_split: some tests failed")
except Exception as e:
    results.fail('unit_tests', f"scaffold_split: import/test error ({e})")


# ===========================================================================
# Summary
# ===========================================================================
all_passed = results.summary()

# Save verification log
log_path = os.path.join(PROJECT_DIR, "logs", "phase0_verification.json")
os.makedirs(os.path.dirname(log_path), exist_ok=True)
log_data = {
    'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
    'python_version': sys.version,
    'passed': results.passed,
    'failed': results.failed,
    'warnings': results.warnings,
    'details': [(s, c, m) for s, c, m in results.details],
}
with open(log_path, 'w') as f:
    json.dump(log_data, f, indent=2)
print(f"\nVerification log saved to: {log_path}")

sys.exit(0 if all_passed else 1)
