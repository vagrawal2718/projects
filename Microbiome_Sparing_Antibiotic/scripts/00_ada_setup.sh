#!/bin/bash
# ===========================================================================
# Phase 0: Ada One-Time Environment Setup
# Project: Microbiome-Sparing Antibiotic Discovery
# Author:  Vishakha Agrawal, IIIT Hyderabad
# Date:    March 2026
# ===========================================================================
# Usage:   Run on Ada LOGIN node (not via SLURM):
#          bash scripts/00_ada_setup.sh
# ===========================================================================

set -euo pipefail

echo "============================================================"
echo " Microbiome-Sparing Antibiotic Discovery -- Ada Setup"
echo " $(date)"
echo "============================================================"

# ------------------------------------------------------------------
# 1. Create project directory tree
# ------------------------------------------------------------------
echo ""
echo "[1/5] Creating project directory structure..."

PROJECT_DIR="$HOME/antibiotic-selectivity"
mkdir -p "${PROJECT_DIR}"/{data/{chembl,maier,repurposing_hub,features,splits},models/{rf,dmpnn/{ecoli,saureus,paeruginosa,mtb,gut_t5,gut_t10,gut_t20}},results/{screening,figures,reports},scripts/utils,logs,jobs,checkpoints}

echo "  Directory tree created at: ${PROJECT_DIR}"
echo "  Subdirectories:"
find "${PROJECT_DIR}" -type d | head -40

# ------------------------------------------------------------------
# 2. Load Python module and create virtual environment
# ------------------------------------------------------------------
echo ""
echo "[2/5] Setting up Python virtual environment..."

module load u22/python/3.11.2 2>/dev/null || {
    echo "  WARNING: u22/python/3.11.2 not available, trying alternatives..."
    module load u22/python/3.10.2 2>/dev/null || {
        echo "  Trying python3.9..."
        module load u22/python/3.9.7 2>/dev/null || {
            echo "  ERROR: No suitable Python module found."
            echo "  Available Python modules:"
            module avail python 2>&1 | grep -i python || true
            exit 1
        }
    }
}

PYTHON_BIN=$(which python3)
PYTHON_VER=$($PYTHON_BIN --version 2>&1)
echo "  Using: ${PYTHON_VER} at ${PYTHON_BIN}"

if [ -d "${PROJECT_DIR}/venv" ]; then
    echo "  Virtual environment already exists. Activating..."
else
    echo "  Creating virtual environment..."
    $PYTHON_BIN -m venv "${PROJECT_DIR}/venv"
fi

source "${PROJECT_DIR}/venv/bin/activate"
echo "  Activated venv: $(which python3)"
echo "  Python version: $(python3 --version)"

# ------------------------------------------------------------------
# 3. Install Python packages
# ------------------------------------------------------------------
echo ""
echo "[3/5] Installing Python packages..."

pip install --upgrade pip setuptools wheel 2>&1 | tail -1

# Core scientific stack
pip install \
    numpy==1.26.4 \
    pandas==2.2.1 \
    scipy==1.12.0 \
    scikit-learn==1.4.1 \
    2>&1 | tail -3

# Chemistry
pip install \
    rdkit \
    chembl-webresource-client==0.10.9 \
    pubchempy==1.0.4 \
    2>&1 | tail -3

# File handling and I/O
pip install \
    openpyxl==3.1.2 \
    requests==2.31.0 \
    joblib==1.3.2 \
    tqdm==4.66.2 \
    2>&1 | tail -3

# Visualization (publication-quality)
pip install \
    matplotlib==3.8.3 \
    seaborn==0.13.2 \
    2>&1 | tail -3

# Chemprop v2 (D-MPNN) -- installs PyTorch as dependency
echo "  Installing Chemprop v2 (this may take several minutes)..."
pip install chemprop 2>&1 | tail -5

echo "  Package installation complete."

# ------------------------------------------------------------------
# 4. Check disk usage
# ------------------------------------------------------------------
echo ""
echo "[4/5] Disk usage report..."

QUOTA_INFO=$(quota -u $USER 2>/dev/null || echo "quota command not available")
echo "  Quota info:"
echo "  ${QUOTA_INFO}" | head -5

VENV_SIZE=$(du -sh "${PROJECT_DIR}/venv" 2>/dev/null | cut -f1)
PROJECT_SIZE=$(du -sh "${PROJECT_DIR}" 2>/dev/null | cut -f1)
echo "  Venv size:    ${VENV_SIZE}"
echo "  Project size: ${PROJECT_SIZE}"

# ------------------------------------------------------------------
# 5. Run verification
# ------------------------------------------------------------------
echo ""
echo "[5/5] Running verification checks..."

python3 << 'PYEOF'
import sys
print(f"Python: {sys.version}")

checks_passed = 0
checks_total = 0

def check(name, test_fn):
    global checks_passed, checks_total
    checks_total += 1
    try:
        result = test_fn()
        print(f"  [PASS] {name}: {result}")
        checks_passed += 1
    except Exception as e:
        print(f"  [FAIL] {name}: {e}")

# Core
check("numpy", lambda: __import__('numpy').__version__)
check("pandas", lambda: __import__('pandas').__version__)
check("scipy", lambda: __import__('scipy').__version__)
check("scikit-learn", lambda: __import__('sklearn').__version__)

# Chemistry
check("RDKit", lambda: (
    __import__('rdkit').Chem.MolToSmiles(
        __import__('rdkit').Chem.MolFromSmiles('CCO'))
))
check("chembl_webresource_client", lambda: (
    str(type(__import__('chembl_webresource_client.new_client').new_client.target))
))
check("pubchempy", lambda: __import__('pubchempy').__version__ if hasattr(__import__('pubchempy'), '__version__') else "imported OK")

# I/O
check("openpyxl", lambda: __import__('openpyxl').__version__)
check("requests", lambda: __import__('requests').__version__)
check("tqdm", lambda: __import__('tqdm').__version__)
check("joblib", lambda: __import__('joblib').__version__)

# Visualization
check("matplotlib", lambda: __import__('matplotlib').__version__)
check("seaborn", lambda: __import__('seaborn').__version__)

# Chemprop / PyTorch
check("torch", lambda: (
    f"{__import__('torch').__version__}, CUDA={__import__('torch').cuda.is_available()}"
))
check("chemprop", lambda: __import__('chemprop').__version__ if hasattr(__import__('chemprop'), '__version__') else "imported OK")

print(f"\n  Verification: {checks_passed}/{checks_total} checks passed.")
if checks_passed == checks_total:
    print("  All checks passed. Environment is ready.")
else:
    print("  WARNING: Some checks failed. Review output above.")
PYEOF

echo ""
echo "============================================================"
echo " Setup complete at $(date)"
echo " Project directory: ${PROJECT_DIR}"
echo " To activate environment in future sessions:"
echo "   source ${PROJECT_DIR}/venv/bin/activate"
echo "============================================================"
