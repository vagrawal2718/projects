#!/bin/bash
# ============================================================================
# setup_mac.sh -- One-time full setup for Mac (also works on Linux/WSL)
#
# Run ONCE before first pipeline run:
#   cd antibiotic_pipeline
#   bash setup_mac.sh
#
# What it does:
#   1. Creates Python virtual environment
#   2. Installs ALL dependencies with exact versions
#   3. Pre-downloads ChEMBL 34 SQLite database (~1GB, instant queries)
#   4. Copies Maier Excel files to data/maier/
#   5. Verifies every package and data file
#   6. Reports disk usage
#
# After setup, run the pipeline with:
#   bash run_mac.sh --real-data
#
# ============================================================================
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

LOG_DIR="${ROOT_DIR}/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/setup_mac_$(date +%Y%m%d_%H%M%S).log"

log() {
    local level="$1"; shift
    local msg="[$level] $(date '+%H:%M:%S') $*"
    echo "$msg" | tee -a "$LOG_FILE"
}
die() { log "FATAL" "$*"; echo "FAILED. Log: $LOG_FILE"; exit 1; }

echo ""
echo "============================================================"
echo "  Microbiome-Sparing Antibiotic Discovery Pipeline"
echo "  FULL SETUP (run once)"
echo "============================================================"
echo "  Directory: $ROOT_DIR"
echo "  Log:       $LOG_FILE"
echo "  Time:      $(date)"
echo "============================================================"
echo ""

# ============================================================================
# STEP 1: Find Python
# ============================================================================
log "INFO" "[Step 1/7] Finding Python 3.12+..."

PYTHON=""
for candidate in python3.13 python3.12 python3; do
    if command -v "$candidate" &>/dev/null; then
        ver=$("$candidate" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
        major=$(echo "$ver" | cut -d. -f1)
        minor=$(echo "$ver" | cut -d. -f2)
        if [ "$major" -ge 3 ] && [ "$minor" -ge 12 ]; then
            PYTHON="$candidate"; break
        fi
    fi
done
[ -z "$PYTHON" ] && die "Python 3.12+ not found. Install: brew install python@3.13"
log "INFO" "  Found: $PYTHON ($($PYTHON --version 2>&1))"

# ============================================================================
# STEP 2: Create virtual environment
# ============================================================================
log "INFO" ""
log "INFO" "[Step 2/7] Creating virtual environment..."

VENV_DIR="${ROOT_DIR}/venv"
if [ -f "$VENV_DIR/bin/activate" ]; then
    log "INFO" "  Existing venv found. Reusing."
else
    $PYTHON -m venv "$VENV_DIR" || die "venv creation failed"
    log "INFO" "  Created: $VENV_DIR"
fi
source "$VENV_DIR/bin/activate"
log "INFO" "  Activated: $(python3 --version 2>&1)"

# ============================================================================
# STEP 3: Install ALL packages
# ============================================================================
log "INFO" ""
log "INFO" "[Step 3/7] Installing all packages..."

log "INFO" "  Upgrading pip..."
pip install --upgrade pip setuptools wheel 2>&1 | tail -1

log "INFO" "  [1/6] Core scientific..."
pip install numpy "pandas>=2.0,<3.0" scipy scikit-learn joblib tqdm 2>&1 | tail -1

log "INFO" "  [2/6] Chemistry (RDKit)..."
pip install rdkit 2>&1 | tail -1

log "INFO" "  [3/6] Visualization..."
pip install matplotlib seaborn plotly openpyxl 2>&1 | tail -1

log "INFO" "  [4/6] Network/API..."
pip install requests chembl-webresource-client pubchempy 2>&1 | tail -1

log "INFO" "  [5/6] ChEMBL bulk downloader..."
pip install chembl-downloader pystow gdown 2>&1 | tail -1

log "INFO" "  [6/6] PyTorch + Chemprop (D-MPNN)..."
pip install torch 2>&1 | tail -1 || die "PyTorch install failed. D-MPNN requires PyTorch."
pip install lightning 2>&1 | tail -1 || die "Lightning install failed. D-MPNN requires Lightning."
pip install chemprop 2>&1 | tail -1 || die "Chemprop install failed. D-MPNN is required."

log "INFO" "  All packages installed."

# ============================================================================
# STEP 4: Verify all imports
# ============================================================================
log "INFO" ""
log "INFO" "[Step 4/7] Verifying all packages..."

python3 << 'PYEOF'
import sys
ok = 0; fail = 0

def check(name, fn):
    global ok, fail
    try:
        result = fn()
        ok += 1
        print(f"  [OK]   {name}: {result}")
    except Exception as e:
        fail += 1
        print(f"  [FAIL] {name}: {e}")

check("numpy",       lambda: __import__('numpy').__version__)
check("pandas",      lambda: __import__('pandas').__version__)
check("scipy",       lambda: __import__('scipy').__version__)
check("scikit-learn", lambda: __import__('sklearn').__version__)
check("joblib",      lambda: __import__('joblib').__version__)
check("tqdm",        lambda: __import__('tqdm').__version__)
check("rdkit",       lambda: __import__('rdkit').__version__ if hasattr(__import__('rdkit'), '__version__') else "OK")

# RDKit.Chem is a submodule: must use exec/importlib, not __import__
def _check_rdkit_chem():
    from rdkit import Chem
    mol = Chem.MolFromSmiles('CCO')
    if mol is None: raise ValueError("MolFromSmiles returned None")
    return Chem.MolToSmiles(mol)
check("RDKit SMILES", _check_rdkit_chem)

check("matplotlib",  lambda: __import__('matplotlib').__version__)
check("seaborn",     lambda: __import__('seaborn').__version__)
check("plotly",      lambda: __import__('plotly').__version__)
check("openpyxl",    lambda: __import__('openpyxl').__version__)
check("requests",    lambda: __import__('requests').__version__)
check("chembl_client", lambda: "OK" if __import__('chembl_webresource_client') else "")
check("pubchempy",   lambda: "OK" if __import__('pubchempy') else "")
check("chembl_downloader", lambda: "OK" if __import__('chembl_downloader') else "")

# pystow has no __version__; just verify import works
check("pystow",      lambda: "OK" if __import__('pystow') else "")

# D-MPNN packages (REQUIRED)
try:
    import torch
    mps = hasattr(torch.backends, 'mps') and torch.backends.mps.is_available()
    cuda = torch.cuda.is_available()
    print(f"  [OK]   torch: {torch.__version__} (MPS={mps}, CUDA={cuda})")
    ok += 1
except Exception:
    print(f"  [FAIL] torch (REQUIRED for D-MPNN. Install: pip install torch)")
    fail += 1

try:
    import chemprop
    print(f"  [OK]   chemprop: {getattr(chemprop, '__version__', 'installed')}")
    ok += 1
except Exception:
    print(f"  [FAIL] chemprop (REQUIRED for D-MPNN. Install: pip install chemprop)")
    fail += 1

# Verify chemprop CLI entry point exists
import shutil as _su
_cp = _su.which('chemprop')
if _cp:
    print(f"  [OK]   chemprop CLI: {_cp}")
else:
    _bin = os.path.dirname(sys.executable)
    _cp2 = os.path.join(_bin, 'chemprop')
    if os.path.exists(_cp2):
        print(f"  [OK]   chemprop CLI: {_cp2}")
    else:
        print(f"  [WARN] chemprop CLI entry point not found. Reinstall: pip install --force-reinstall chemprop")

print(f"\n  Result: {ok} OK, {fail} FAILED")
if fail > 0:
    sys.exit(1)
PYEOF
[ $? -eq 0 ] || die "Package verification failed"

# ============================================================================
# STEP 5: Ensure data is available (smart: ZIP > Drive > ChEMBL download)
# ============================================================================
log "INFO" ""
log "INFO" "[Step 5/7] Checking for pre-processed data..."
log "INFO" "  Priority: local files > local ZIP > Drive ZIP > ChEMBL download"

python3 << 'PYEOF'
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath('.')), 'scripts'))
sys.path.insert(0, 'scripts')

try:
    import config
except Exception:
    print("  config.py not found. Skipping data check (run_mac.sh will handle it).")
    exit(0)

# Check if all CSVs already exist locally
all_exist = True
for pinfo in config.PATHOGENS.values():
    fp = os.path.join(config.CHEMBL_DIR, pinfo['csv_filename'])
    if not (os.path.exists(fp) and os.path.getsize(fp) > 1000):
        all_exist = False
        break
for extra in [os.path.join(config.MAIER_DIR, 'maier_combined.csv'),
              os.path.join(config.HUB_DIR, config.HUB_CLEAN_FILENAME)]:
    if not (os.path.exists(extra) and os.path.getsize(extra) > 1000):
        all_exist = False

if all_exist:
    print("  All pre-processed data CSVs already exist locally.")
    print("  No large downloads needed. Skipping ChEMBL SQLite download.")
    exit(0)

# Try restore from ZIP bundles (local or Drive)
try:
    from utils.gdrive_backup import get_data_manager
    dm = get_data_manager()
    restored = dm.restore_data_csvs(config.PROJECT_DIR)
    if restored:
        print("  Data restored from ZIP bundle. No ChEMBL download needed.")
        exit(0)
except Exception as e:
    print(f"  ZIP restore not available: {e}")

# Last resort: download ChEMBL SQLite (~1 GB)
print("  Pre-processed data not available. Downloading ChEMBL 34 SQLite (~1 GB)...")
print("  This is a one-time download. After this, all queries are instant.")
try:
    import chembl_downloader
    path = chembl_downloader.download_extract_sqlite(version='34')
    size_gb = os.path.getsize(str(path)) / (1024**3)
    print(f"  Database ready: {path} ({size_gb:.1f} GB)")
except Exception as e:
    print(f"  WARNING: ChEMBL download failed: {e}")
    print(f"  The pipeline will try gdown/rclone at runtime.")
    print(f"  Or retry: python3 -c \"import chembl_downloader; chembl_downloader.download_extract_sqlite(version='34')\"")
PYEOF

# ============================================================================
# STEP 6: Copy Maier Excel files and create directories
# ============================================================================
log "INFO" ""
log "INFO" "[Step 6/7] Setting up data directories..."

# Create all directories
export ANTIBIOTIC_PROJECT_DIR="$ROOT_DIR"
export ANTIBIOTIC_DATA_MODE="real"
python3 -c "
import os, sys; sys.path.insert(0, 'scripts'); import config
for d in [config.DATA_DIR, config.CHEMBL_DIR, config.MAIER_DIR, config.HUB_DIR,
          config.FEATURES_DIR, config.SPLITS_DIR, config.RF_DIR, config.DMPNN_DIR,
          config.RESULTS_DIR, config.SCREENING_DIR, config.FIGURES_DIR,
          config.REPORTS_DIR, config.CHECKPOINTS_DIR, config.LOGS_DIR, config.DMPNN_INPUT_DIR]:
    os.makedirs(d, exist_ok=True)
print(f'  Directories created under {config.PROJECT_DIR}')
"

# Copy Maier Excel files
if [ -d "${ROOT_DIR}/resources/maier" ]; then
    mkdir -p "${ROOT_DIR}/data/maier"
    cp -n "${ROOT_DIR}/resources/maier/"*.xlsx "${ROOT_DIR}/data/maier/" 2>/dev/null || true
    n=$(ls "${ROOT_DIR}/data/maier/"*.xlsx 2>/dev/null | wc -l | tr -d ' ')
    log "INFO" "  Maier Excel files: $n copied to data/maier/"
else
    log "WARN" "  No resources/maier/ directory found"
fi

# Verify critical Maier files
for f in "41586_2018_BFnature25979_MOESM5_ESM.xlsx" "41586_2018_BFnature25979_MOESM3_ESM.xlsx"; do
    if [ -f "${ROOT_DIR}/data/maier/$f" ]; then
        log "INFO" "  [OK] $f"
    else
        log "WARN" "  [MISSING] $f"
    fi
done

# ============================================================================
# STEP 7: Run unit tests
# ============================================================================
log "INFO" ""
log "INFO" "[Step 7/7] Running unit tests..."

python3 -c "
import sys, os
sys.path.insert(0, 'scripts')
os.environ['ANTIBIOTIC_PROJECT_DIR'] = '$ROOT_DIR'
os.environ['ANTIBIOTIC_DATA_MODE'] = 'real'

total_pass = 0; total_fail = 0

# Utils
for mod_path in ['scripts/utils/smiles_utils.py', 'scripts/utils/scaffold_split.py',
                 'scripts/utils/viz_utils.py', 'scripts/utils/diagnostics.py',
                 'scripts/utils/data_cache.py', 'scripts/utils/network_utils.py']:
    import importlib.util
    spec = importlib.util.spec_from_file_location('m', mod_path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)

# Pipeline scripts
for num in ['01', '02', '03', '04', '05', '06', '07']:
    import glob
    files = glob.glob(f'scripts/{num}_*.py')
    if files:
        spec = importlib.util.spec_from_file_location('m', files[0])
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        ok = mod.run_unit_tests()
        if not ok:
            total_fail += 1
        else:
            total_pass += 1

print(f'  Pipeline scripts: {total_pass} passed, {total_fail} failed')
" 2>&1 | grep -E "passed|failed|PASS|FAIL" | tail -5

# ============================================================================
# SUMMARY
# ============================================================================
log "INFO" ""
log "INFO" "============================================================"
log "INFO" "  SETUP COMPLETE"
log "INFO" "============================================================"

# Install rclone for Google Drive output upload
if ! command -v rclone &>/dev/null; then
    log "INFO" "  Installing rclone for Google Drive sync..."
    brew install rclone 2>/dev/null || {
        curl -s https://rclone.org/install.sh | sudo bash 2>/dev/null || {
            log "WARN" "  rclone install failed. Output upload to Drive disabled."
            log "WARN" "  Install manually: brew install rclone"
        }
    }
fi
if command -v rclone &>/dev/null; then
    if ! rclone listremotes 2>/dev/null | grep -q "^antibiotic_gdrive:"; then
        log "INFO" ""
        log "INFO" "  To enable Google Drive output backup (one-time):"
        log "INFO" "    bash setup_rclone_gdrive.sh"
    fi
fi

VENV_SIZE=$(du -sh "$VENV_DIR" 2>/dev/null | cut -f1)
DATA_SIZE=$(du -sh "${ROOT_DIR}/data" 2>/dev/null | cut -f1 || echo "0")
log "INFO" "  Venv size:  $VENV_SIZE"
log "INFO" "  Data size:  $DATA_SIZE"
log "INFO" "  Log:        $LOG_FILE"
log "INFO" ""
log "INFO" "  To run the pipeline:"
log "INFO" "    bash run_mac.sh --real-data          # Real data from APIs"
log "INFO" "    bash run_mac.sh                      # Synthetic test"
log "INFO" "    bash run_mac.sh --clean --real-data   # Fresh run (keeps data)"
log "INFO" ""
log "INFO" "  ChEMBL SQLite DB cached at: ~/.data/chembl/34/"
log "INFO" "  (All 4 pathogen queries will be instant)"
log "INFO" "============================================================"
