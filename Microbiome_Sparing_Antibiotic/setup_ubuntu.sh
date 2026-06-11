#!/bin/bash
# ============================================================================
# setup_ubuntu.sh -- One-time full setup for Ubuntu 24.04 / Debian / WSL
#
# Usage:
#   bash setup_ubuntu.sh                  # requires python3-venv already installed
#   bash setup_ubuntu.sh --install-system # also installs apt packages (needs sudo)
#
# After setup:
#   bash run_ubuntu.sh --real-data
# ============================================================================
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

INSTALL_SYSTEM=false
[ "${1:-}" = "--install-system" ] && INSTALL_SYSTEM=true

LOG_DIR="${ROOT_DIR}/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/setup_ubuntu_$(date +%Y%m%d_%H%M%S).log"

log() {
    local level="$1"; shift
    echo "[$level] $(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE"
}
die() { log "FATAL" "$*"; exit 1; }

echo ""
echo "============================================================"
echo "  Microbiome-Sparing Antibiotic Discovery Pipeline"
echo "  FULL SETUP - Ubuntu/Debian"
echo "============================================================"
echo ""

# ---- System packages ----
if [ "$INSTALL_SYSTEM" = true ]; then
    log "INFO" "[1/7] Installing system packages (sudo)..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq python3-venv python3-pip python3-dev
else
    python3 -c "import venv, ensurepip" 2>/dev/null || \
        die "Missing python3-venv. Run: bash setup_ubuntu.sh --install-system"
fi

# ---- Python ----
log "INFO" "[2/7] Finding Python..."
PYTHON=""
for c in python3.13 python3.12 python3; do
    if command -v "$c" &>/dev/null; then
        ver=$("$c" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
        major=$(echo "$ver" | cut -d. -f1); minor=$(echo "$ver" | cut -d. -f2)
        [ "$major" -ge 3 ] && [ "$minor" -ge 12 ] && { PYTHON="$c"; break; }
    fi
done
[ -z "$PYTHON" ] && die "Python 3.12+ not found. Install: sudo apt install python3.13"
log "INFO" "  $PYTHON ($($PYTHON --version 2>&1))"

# ---- Venv ----
log "INFO" "[3/7] Creating virtual environment..."
VENV_DIR="${ROOT_DIR}/venv"
[ -f "$VENV_DIR/bin/activate" ] || $PYTHON -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

# ---- Packages ----
log "INFO" "[4/7] Installing all packages..."
pip install --upgrade pip setuptools wheel 2>&1 | tail -1
pip install numpy "pandas>=2.0,<3.0" scipy scikit-learn joblib tqdm 2>&1 | tail -1
pip install rdkit 2>&1 | tail -1
pip install matplotlib seaborn plotly openpyxl 2>&1 | tail -1
pip install requests chembl-webresource-client pubchempy 2>&1 | tail -1
pip install chembl-downloader pystow gdown 2>&1 | tail -1
pip install torch lightning 2>&1 | tail -1 || die "PyTorch/Lightning install failed. D-MPNN requires these."
pip install chemprop 2>&1 | tail -1 || die "Chemprop install failed. D-MPNN is required."
log "INFO" "  Done."

# ---- Verify ----
log "INFO" "[5/7] Verifying imports..."
python3 -c "
import numpy,pandas,scipy,sklearn,matplotlib,seaborn,tqdm,requests,openpyxl,plotly
import chembl_downloader, pubchempy, chembl_webresource_client, pystow
from rdkit import Chem; assert Chem.MolFromSmiles('CCO')
print('  All core imports OK.')
try:
    import torch, chemprop
    print(f'  torch={torch.__version__}, chemprop OK')
except ImportError as e:
    print(f'  FATAL: torch/chemprop not working: {e}')
    print(f'  D-MPNN is required. Fix: pip install torch lightning chemprop')
    exit(1)
" || die "Verification failed"

# ---- Smart data check: ZIP > Drive > ChEMBL download ----
log "INFO" "[6/7] Checking for pre-processed data (skips large downloads if available)..."
export ANTIBIOTIC_PROJECT_DIR="$ROOT_DIR"
export ANTIBIOTIC_DATA_MODE="real"
python3 -c "
import os,sys; sys.path.insert(0,'scripts')
try:
    import config
    all_ok = all(os.path.exists(os.path.join(config.CHEMBL_DIR, v['csv_filename'])) and
                 os.path.getsize(os.path.join(config.CHEMBL_DIR, v['csv_filename'])) > 1000
                 for v in config.PATHOGENS.values())
    if all_ok:
        print('  All CSVs exist. No ChEMBL download needed.'); exit(0)
    from utils.gdrive_backup import get_data_manager
    dm = get_data_manager()
    if dm.restore_data_csvs(config.PROJECT_DIR):
        print('  Data restored from ZIP. No ChEMBL download needed.'); exit(0)
except Exception: pass
print('  Downloading ChEMBL 34 SQLite (~1 GB, one-time)...')
import chembl_downloader, os
path = chembl_downloader.download_extract_sqlite(version='34')
print(f'  Ready: {path} ({os.path.getsize(str(path))/(1024**3):.1f} GB)')
" || log "WARN" "  Download failed (pipeline will try gdown/rclone at runtime)"

# ---- Data dirs + Maier ----
log "INFO" "[7/7] Setting up directories and data..."
export ANTIBIOTIC_PROJECT_DIR="$ROOT_DIR"
export ANTIBIOTIC_DATA_MODE="real"
python3 -c "
import os,sys; sys.path.insert(0,'scripts'); import config
for d in [config.DATA_DIR,config.CHEMBL_DIR,config.MAIER_DIR,config.HUB_DIR,
          config.FEATURES_DIR,config.SPLITS_DIR,config.RF_DIR,config.DMPNN_DIR,
          config.RESULTS_DIR,config.SCREENING_DIR,config.FIGURES_DIR,
          config.REPORTS_DIR,config.CHECKPOINTS_DIR,config.LOGS_DIR,config.DMPNN_INPUT_DIR]:
    os.makedirs(d,exist_ok=True)
print('  Directories ready.')
"
[ -d "${ROOT_DIR}/resources/maier" ] && {
    mkdir -p "${ROOT_DIR}/data/maier"
    cp -n "${ROOT_DIR}/resources/maier/"*.xlsx "${ROOT_DIR}/data/maier/" 2>/dev/null || true
    log "INFO" "  Maier files: $(ls "${ROOT_DIR}/data/maier/"*.xlsx 2>/dev/null | wc -l | tr -d ' ') copied"
}

log "INFO" ""
log "INFO" "============================================================"
log "INFO" "  SETUP COMPLETE"
log "INFO" "============================================================"
log "INFO" "  Run: bash run_ubuntu.sh --real-data"
log "INFO" "============================================================"
