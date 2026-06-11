#!/bin/bash
# ============================================================================
# ada_full_setup.sh -- Complete One-Time Setup for Ada HPC
# Project: Microbiome-Sparing Antibiotic Discovery
# Author:  Vishakha Agrawal, IIIT Hyderabad
# ============================================================================
#
# USAGE:  Run on Ada LOGIN node (NOT via SLURM):
#         bash ada_full_setup.sh
#
# This script:
#   1. Creates the full project directory tree
#   2. Copies all scripts, jobs, utilities, and config
#   3. Copies Maier Excel data files
#   4. Loads the Python module and creates a virtual environment
#   5. Installs all required packages (with version pinning)
#   6. Runs comprehensive environment verification
#   7. Tests every utility module
#   8. Reports disk usage and quota
#
# Estimated time: 10-15 minutes (mostly pip install)
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# ---- Configuration ----
PROJECT_DIR="$HOME/antibiotic-selectivity"
SCRIPT_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# ---- Environment variables (real data mode on Ada) ----
export ANTIBIOTIC_PROJECT_DIR="$PROJECT_DIR"
export ANTIBIOTIC_DATA_MODE="real"

# ---- Logging ----
LOG_FILE="${PROJECT_DIR}/logs/setup_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    local level="$1"; shift
    local msg="[${level}] $(date '+%H:%M:%S') | setup | $*"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

die() {
    log "FATAL" "$*"
    echo ""
    echo "SETUP FAILED. See log: $LOG_FILE"
    exit 1
}

log "INFO" "============================================================"
log "INFO" " Microbiome-Sparing Antibiotic Discovery -- Full Ada Setup"
log "INFO" " Started: $TIMESTAMP"
log "INFO" " Project: $PROJECT_DIR"
log "INFO" " Source:  $SCRIPT_SOURCE_DIR"
log "INFO" "============================================================"

# ============================================================================
# STEP 1: Create directory tree
# ============================================================================
log "INFO" ""
log "INFO" "[1/8] Creating project directory structure..."

dirs=(
    "data/chembl" "data/maier" "data/repurposing_hub"
    "outputs/features" "outputs/splits" "outputs/dmpnn_input"
    "outputs/models/rf"
    "outputs/models/dmpnn/ecoli" "outputs/models/dmpnn/saureus"
    "outputs/models/dmpnn/paeruginosa" "outputs/models/dmpnn/mtb"
    "outputs/models/dmpnn/gut_t5" "outputs/models/dmpnn/gut_t10" "outputs/models/dmpnn/gut_t20"
    "outputs/results/screening" "outputs/results/figures" "outputs/results/reports"
    "outputs/checkpoints"
    "scripts/utils" "logs" "jobs" "resources/maier"
)

for d in "${dirs[@]}"; do
    mkdir -p "${PROJECT_DIR}/${d}"
done
log "INFO" "  Created $(echo "${dirs[@]}" | wc -w) directories"

# ============================================================================
# STEP 2: Copy scripts, utilities, config, jobs
# ============================================================================
log "INFO" ""
log "INFO" "[2/8] Copying scripts and job files..."

# Copy all Python scripts
if [ -d "${SCRIPT_SOURCE_DIR}/scripts" ]; then
    cp -v "${SCRIPT_SOURCE_DIR}/scripts/"*.py "${PROJECT_DIR}/scripts/" 2>/dev/null || true
    cp -v "${SCRIPT_SOURCE_DIR}/scripts/"*.sh "${PROJECT_DIR}/scripts/" 2>/dev/null || true
    # Copy utils
    cp -v "${SCRIPT_SOURCE_DIR}/scripts/utils/"*.py "${PROJECT_DIR}/scripts/utils/" 2>/dev/null || true
    log "INFO" "  Scripts copied"
else
    # If running from the ZIP structure
    for f in "${SCRIPT_SOURCE_DIR}/"*.py; do
        [ -f "$f" ] && cp -v "$f" "${PROJECT_DIR}/scripts/"
    done
    for f in "${SCRIPT_SOURCE_DIR}/utils/"*.py; do
        [ -f "$f" ] && cp -v "$f" "${PROJECT_DIR}/scripts/utils/"
    done
fi

# Copy SLURM job scripts
if [ -d "${SCRIPT_SOURCE_DIR}/jobs" ]; then
    cp -v "${SCRIPT_SOURCE_DIR}/jobs/"*.sh "${PROJECT_DIR}/jobs/" 2>/dev/null || true
elif [ -d "${SCRIPT_SOURCE_DIR}/../jobs" ]; then
    cp -v "${SCRIPT_SOURCE_DIR}/../jobs/"*.sh "${PROJECT_DIR}/jobs/" 2>/dev/null || true
fi
chmod +x "${PROJECT_DIR}/jobs/"*.sh 2>/dev/null || true

# Copy checkpoints
if [ -d "${SCRIPT_SOURCE_DIR}/checkpoints" ]; then
    cp -v "${SCRIPT_SOURCE_DIR}/checkpoints/"*.json "${PROJECT_DIR}/checkpoints/" 2>/dev/null || true
elif [ -d "${SCRIPT_SOURCE_DIR}/../checkpoints" ]; then
    cp -v "${SCRIPT_SOURCE_DIR}/../checkpoints/"*.json "${PROJECT_DIR}/checkpoints/" 2>/dev/null || true
fi

# Verify critical files exist
CRITICAL_FILES=(
    "scripts/config.py"
    "scripts/utils/__init__.py"
    "scripts/utils/smiles_utils.py"
    "scripts/utils/scaffold_split.py"
    "scripts/utils/viz_utils.py"
    "scripts/utils/logging_utils.py"
    "scripts/01_fetch_chembl.py"
    "scripts/02_process_maier.py"
    "scripts/03_fetch_repurposing_hub.py"
    "scripts/04_compute_morgan_fps.py"
    "scripts/05_train_rf.py"
    "scripts/06_train_dmpnn.py"
    "scripts/07_evaluate.py"
    "jobs/phase1a_chembl.sh"
    "jobs/phase1b_maier.sh"
    "jobs/phase1c_hub.sh"
    "jobs/phase2_features.sh"
    "jobs/phase3a_rf.sh"
    "jobs/phase3b_dmpnn.sh"
    "jobs/phase4_evaluate.sh"
)

missing=0
for f in "${CRITICAL_FILES[@]}"; do
    if [ ! -f "${PROJECT_DIR}/${f}" ]; then
        log "ERROR" "  MISSING: ${f}"
        missing=$((missing + 1))
    fi
done
if [ $missing -gt 0 ]; then
    die "$missing critical files missing. Check source directory."
fi
log "INFO" "  All ${#CRITICAL_FILES[@]} critical files verified"

# ============================================================================
# STEP 3: Copy Maier Excel data files
# ============================================================================
log "INFO" ""
log "INFO" "[3/8] Copying Maier Excel data files..."

MAIER_SOURCE=""
# Try multiple possible locations (resources/maier/ is the bundled location)
for candidate in \
    "${SCRIPT_SOURCE_DIR}/resources/maier" \
    "${SCRIPT_SOURCE_DIR}/Maier_data_Excel" \
    "${SCRIPT_SOURCE_DIR}/../Maier_data_Excel" \
    "${SCRIPT_SOURCE_DIR}/data/maier" \
    "$HOME/Maier_data_Excel" \
    "$HOME/resources/Maier_data_Excel"; do
    if [ -d "$candidate" ] && ls "$candidate"/*.xlsx &>/dev/null; then
        MAIER_SOURCE="$candidate"
        break
    fi
done

if [ -n "$MAIER_SOURCE" ]; then
    n_files=$(ls "$MAIER_SOURCE"/*.xlsx 2>/dev/null | wc -l)
    cp -v "$MAIER_SOURCE"/*.xlsx "${PROJECT_DIR}/data/maier/" 2>/dev/null || true
    # Also copy to resources/maier/ so scripts can find them after clean
    cp "$MAIER_SOURCE"/*.xlsx "${PROJECT_DIR}/resources/maier/" 2>/dev/null || true
    log "INFO" "  Copied $n_files Excel files from $MAIER_SOURCE"
else
    n_existing=$(ls "${PROJECT_DIR}/data/maier/"*.xlsx 2>/dev/null | wc -l)
    if [ "$n_existing" -gt 0 ]; then
        log "INFO" "  Maier files already present: $n_existing files"
    else
        log "WARN" "  No Maier Excel files found! Upload manually:"
        log "WARN" "    scp Maier_data_Excel/*.xlsx ${USER}@ada.iiit.ac.in:${PROJECT_DIR}/data/maier/"
    fi
fi

# Verify key Maier files
REQUIRED_MAIER=(
    "41586_2018_BFnature25979_MOESM3_ESM.xlsx"
    "41586_2018_BFnature25979_MOESM5_ESM.xlsx"
    "41586_2021_3986_MOESM11_ESM.xlsx"
    "41586_2021_3986_MOESM3_ESM.xlsx"
)
maier_ok=0
for f in "${REQUIRED_MAIER[@]}"; do
    if [ -f "${PROJECT_DIR}/data/maier/${f}" ]; then
        maier_ok=$((maier_ok + 1))
    else
        log "WARN" "  Missing Maier file: ${f}"
    fi
done
log "INFO" "  Key Maier files: ${maier_ok}/${#REQUIRED_MAIER[@]} present"

# ============================================================================
# STEP 4: Load Python module
# ============================================================================
log "INFO" ""
log "INFO" "[4/8] Loading Python module..."

PYTHON_LOADED=false
for pymod in "u22/python/3.12.4" "u22/python/3.13" "u22/python/3.12" "u22/python/3.11.2"; do
    if module load "$pymod" 2>/dev/null; then
        log "INFO" "  Loaded module: $pymod"
        PYTHON_LOADED=true
        break
    fi
done

if [ "$PYTHON_LOADED" = false ]; then
    log "WARN" "  No module loaded. Trying system Python..."
    if command -v python3 &>/dev/null; then
        log "INFO" "  Using system python3: $(python3 --version 2>&1)"
    else
        die "No Python 3 found. Check 'module avail python'."
    fi
fi

PYTHON_BIN=$(which python3)
PYTHON_VER=$($PYTHON_BIN --version 2>&1)
log "INFO" "  Python: $PYTHON_VER at $PYTHON_BIN"

# Validate Python >= 3.12
PY_MINOR=$($PYTHON_BIN -c "import sys; print(sys.version_info.minor)")
if [ "$PY_MINOR" -lt 12 ]; then
    die "Python 3.12+ required (found $PYTHON_VER). Check 'module avail python' for newer versions."
fi

# ============================================================================
# STEP 5: Create virtual environment and install packages
# ============================================================================
log "INFO" ""
log "INFO" "[5/8] Setting up virtual environment..."

VENV_DIR="${PROJECT_DIR}/venv"

if [ -d "$VENV_DIR" ] && [ -f "$VENV_DIR/bin/activate" ]; then
    log "INFO" "  Existing venv found. Activating..."
    source "$VENV_DIR/bin/activate"
else
    log "INFO" "  Creating new virtual environment..."
    $PYTHON_BIN -m venv "$VENV_DIR" || die "Failed to create venv"
    source "$VENV_DIR/bin/activate"
fi

log "INFO" "  Venv Python: $(which python3) ($(python3 --version 2>&1))"

# Upgrade pip
log "INFO" "  Upgrading pip..."
pip install --upgrade pip setuptools wheel 2>&1 | tail -1

# Install packages in groups for better error isolation
log "INFO" "  Installing core scientific packages..."
pip install numpy "pandas>=2.0,<3.0" scipy scikit-learn 2>&1 | tail -2
log "INFO" "  Installing chemistry packages..."
pip install rdkit chembl-webresource-client pubchempy chembl-downloader pystow gdown 2>&1 | tail -2
log "INFO" "  Installing I/O packages..."
pip install openpyxl requests joblib tqdm 2>&1 | tail -2
log "INFO" "  Installing visualization packages..."
pip install matplotlib seaborn plotly 2>&1 | tail -2
log "INFO" "  Installing Chemprop (D-MPNN) and dependencies..."
pip install torch lightning 2>&1 | tail -2
if ! python3 -c "import torch" 2>/dev/null; then
    log "ERROR" "  PyTorch install failed. D-MPNN requires PyTorch."
    log "ERROR" "  Ada GPU nodes need: pip install torch --index-url https://download.pytorch.org/whl/cu121"
    exit 1
fi
pip install chemprop 2>&1 | tail -3
if ! python3 -c "import chemprop" 2>/dev/null; then
    log "ERROR" "  Chemprop install failed. D-MPNN is required."
    log "ERROR" "  Try: pip install chemprop --no-deps && pip install lightning"
    exit 1
fi

log "INFO" "  Package installation complete."

# ============================================================================
# STEP 6: Comprehensive verification
# ============================================================================
log "INFO" ""
log "INFO" "[6/8] Running verification checks..."

python3 << 'PYVERIFY'
import sys, os
checks_pass = 0; checks_fail = 0

def check(name, fn):
    global checks_pass, checks_fail
    try:
        result = fn()
        checks_pass += 1
        print(f"  [OK]   {name}: {result}")
    except Exception as e:
        checks_fail += 1
        print(f"  [FAIL] {name}: {e}")

# Core packages
check("numpy",    lambda: __import__('numpy').__version__)
check("pandas",   lambda: __import__('pandas').__version__)
check("scipy",    lambda: __import__('scipy').__version__)
check("sklearn",  lambda: __import__('sklearn').__version__)

# Chemistry
def _check_rdkit():
    from rdkit import Chem
    mol = Chem.MolFromSmiles('CCO')
    if mol is None: raise ValueError("MolFromSmiles returned None")
    return Chem.MolToSmiles(mol)
check("RDKit",    _check_rdkit)
check("ChEMBL client", lambda: str(type(__import__('chembl_webresource_client.new_client').new_client.target)))
check("pubchempy", lambda: "OK")

# I/O
check("openpyxl", lambda: __import__('openpyxl').__version__)
check("requests", lambda: __import__('requests').__version__)
check("joblib",   lambda: __import__('joblib').__version__)
check("tqdm",     lambda: __import__('tqdm').__version__)

# Visualization
check("matplotlib", lambda: __import__('matplotlib').__version__)
check("seaborn",    lambda: __import__('seaborn').__version__)
check("plotly",     lambda: __import__('plotly').__version__)

# ChEMBL bulk download
check("chembl_downloader", lambda: "OK" if __import__('chembl_downloader') else "")
check("pystow",    lambda: "OK" if __import__('pystow') else "")

# ML / Deep Learning
check("torch", lambda: f"{__import__('torch').__version__}, CUDA={__import__('torch').cuda.is_available()}")
check("chemprop", lambda: getattr(__import__('chemprop'), '__version__', 'imported'))

print(f"\n  Verification: {checks_pass}/{checks_pass + checks_fail} packages OK")
if checks_fail > 0:
    print(f"  WARNING: {checks_fail} packages failed")
    sys.exit(1)
PYVERIFY

VERIFY_EXIT=$?
if [ $VERIFY_EXIT -ne 0 ]; then
    log "WARN" "  Some packages failed verification. Check output above."
else
    log "INFO" "  All packages verified."
fi

# ============================================================================
# STEP 6b: Smart data check (skips ChEMBL download if CSVs available)
# ============================================================================
log "INFO" ""
log "INFO" "[6b/8] Checking for pre-processed data (skips large downloads if available)..."
log "INFO" "  Priority: local files > local ZIP > rclone from Drive > ChEMBL download"

cd "${PROJECT_DIR}"
export ANTIBIOTIC_PROJECT_DIR="${PROJECT_DIR}"
export ANTIBIOTIC_DATA_MODE="real"

python3 << 'PYCHEMBL'
import os, sys
sys.path.insert(0, 'scripts')
try:
    import config
    # Check if all CSVs exist
    all_ok = True
    for v in config.PATHOGENS.values():
        fp = os.path.join(config.CHEMBL_DIR, v['csv_filename'])
        if not (os.path.exists(fp) and os.path.getsize(fp) > 1000):
            all_ok = False; break
    if all_ok:
        print("  All pre-processed CSVs exist. No ChEMBL download needed.")
        exit(0)

    # Try ZIP restore (local or rclone)
    try:
        from utils.gdrive_backup import get_data_manager
        dm = get_data_manager()
        if dm.restore_data_csvs(config.PROJECT_DIR):
            print("  Data restored from ZIP. No ChEMBL download needed.")
            exit(0)
    except Exception:
        pass
except Exception:
    pass

# Last resort
print("  Pre-processed data not available. Downloading ChEMBL 34 SQLite (~1 GB)...")
try:
    import chembl_downloader, os
    path = chembl_downloader.download_extract_sqlite(version='34')
    size_gb = os.path.getsize(str(path)) / (1024**3)
    print(f"  Database ready: {path} ({size_gb:.1f} GB)")
except Exception as e:
    print(f"  WARNING: ChEMBL download failed: {e}")
    print(f"  Pipeline will try rclone/gdown at runtime.")
PYCHEMBL

# ============================================================================
# STEP 7: Test utility modules
# ============================================================================
log "INFO" ""
log "INFO" "[7/8] Testing utility modules..."

cd "${PROJECT_DIR}"
UTILS_OK=true

for util in scripts/utils/smiles_utils.py scripts/utils/scaffold_split.py scripts/utils/viz_utils.py; do
    if [ -f "$util" ]; then
        result=$(python3 "$util" 2>&1 | tail -1)
        if echo "$result" | grep -q "0 failed"; then
            log "INFO" "  $(basename $util): $result"
        else
            log "WARN" "  $(basename $util): $result"
            UTILS_OK=false
        fi
    fi
done

if [ "$UTILS_OK" = true ]; then
    log "INFO" "  All utility modules passed."
else
    log "WARN" "  Some utility tests failed. Review output above."
fi

# ============================================================================
# STEP 8: Disk usage report
# ============================================================================
log "INFO" ""
log "INFO" "[8/8] Disk usage report..."

PROJ_SIZE=$(du -sh "${PROJECT_DIR}" 2>/dev/null | cut -f1)
VENV_SIZE=$(du -sh "${PROJECT_DIR}/venv" 2>/dev/null | cut -f1)
log "INFO" "  Project total: $PROJ_SIZE"
log "INFO" "  Venv:          $VENV_SIZE"

# Try quota
quota -u $USER 2>/dev/null | head -5 || log "INFO" "  (quota command not available)"

# ============================================================================
# RCLONE SETUP (for Google Drive read/write on Ada)
# ============================================================================
log "INFO" ""
log "INFO" "Setting up rclone for Google Drive access..."

if command -v rclone &>/dev/null; then
    log "INFO" "  rclone already installed: $(rclone version 2>/dev/null | head -1)"
else
    log "INFO" "  Installing rclone to ~/.local/bin..."
    mkdir -p ~/.local/bin
    cd /tmp
    curl -sO https://downloads.rclone.org/rclone-current-linux-amd64.zip 2>/dev/null && {
        unzip -oq rclone-current-linux-amd64.zip 2>/dev/null
        cp rclone-*-linux-amd64/rclone ~/.local/bin/ 2>/dev/null
        chmod +x ~/.local/bin/rclone 2>/dev/null
        rm -rf rclone-*-linux-amd64*
        export PATH="$HOME/.local/bin:$PATH"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
        log "INFO" "  rclone installed: $(~/.local/bin/rclone version 2>/dev/null | head -1)"
    } || {
        log "WARN" "  rclone install failed (no network?). Drive upload disabled."
    }
    cd "${PROJECT_DIR}"
fi

# Check if rclone is configured
if rclone listremotes 2>/dev/null | grep -q "^antibiotic_gdrive:"; then
    log "INFO" "  rclone remote 'antibiotic_gdrive' configured."
    log "INFO" "  Testing: rclone lsf antibiotic_gdrive:antibiotic_data/ ..."
    rclone lsf antibiotic_gdrive:antibiotic_data/ --max-depth 1 2>/dev/null | head -5 && {
        log "INFO" "  Google Drive connection OK."
    } || {
        log "WARN" "  Google Drive connection failed. Run: bash setup_rclone_gdrive.sh"
    }
else
    log "INFO" "  rclone not yet configured for Google Drive."
    log "INFO" "  To enable Drive data sync, run:"
    log "INFO" "    bash ${PROJECT_DIR}/setup_rclone_gdrive.sh"
fi

# ============================================================================
# SUMMARY
# ============================================================================
log "INFO" ""
log "INFO" "============================================================"
log "INFO" " SETUP COMPLETE at $(date '+%Y-%m-%d %H:%M:%S')"
log "INFO" "============================================================"
log "INFO" "  Project directory: ${PROJECT_DIR}"
log "INFO" "  Virtual environment: ${VENV_DIR}"
log "INFO" "  Log file: ${LOG_FILE}"
log "INFO" ""
log "INFO" "  To activate in future sessions:"
log "INFO" "    source ${PROJECT_DIR}/venv/bin/activate"
log "INFO" ""
log "INFO" "  To run the full pipeline:"
log "INFO" "    bash ${PROJECT_DIR}/run_all.sh"
log "INFO" ""
log "INFO" "  To enable Google Drive sync (optional, one-time):"
log "INFO" "    bash ${PROJECT_DIR}/setup_rclone_gdrive.sh"
log "INFO" "============================================================"
