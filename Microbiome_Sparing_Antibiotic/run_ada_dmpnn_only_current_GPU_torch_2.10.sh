#!/bin/bash
# ============================================================================
# run_ada_dmpnn_only.sh
#
# Self-contained runner for Ada HPC. Same packages as Google Colab.
# Creates venv + installs everything if needed, then runs D-MPNN pipeline.
#
# 100% OFFLINE for data. All data comes from the pre-DMPNN ZIP package.
# Network is ONLY used for pip install (one-time).
#
# Usage:
#   cd ~/antibiotic-selectivity
#   unzip -o antibiotic_pre_dmpnn_YYYYMMDD.zip
#   bash run_ada_dmpnn_only.sh
#
# Or via SLURM (GPU):
#   sbatch run_ada_dmpnn_only.sh
#
# ============================================================================
#SBATCH --partition=u22
#SBATCH -A research
#SBATCH --qos=low
#SBATCH -n 10
#SBATCH --gres=gpu:1
#SBATCH --mem-per-cpu=2G
#SBATCH --time=4:00:00
#SBATCH --output=logs/dmpnn_%j.log
#SBATCH --job-name=dmpnn

set -eo pipefail

# ---- Auto-detect project directory ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
if [ -d "$PROJECT_DIR/scripts/utils" ]; then
    :
elif [ -d "$PROJECT_DIR/../scripts/utils" ]; then
    PROJECT_DIR="$(cd "$PROJECT_DIR/.." && pwd)"
fi
cd "$PROJECT_DIR"

log() { echo "[$(date '+%H:%M:%S')] $*"; }
die() { log "FATAL: $*"; exit 1; }

log "============================================================"
log "  Antibiotic D-MPNN Pipeline (Ada)"
log "  Same setup as Google Colab"
log "============================================================"
log "  Directory: $PROJECT_DIR"
mkdir -p logs

# ============================================================================
# STEP 1: Python + venv (same as Colab)
# ============================================================================
log ""
log "[1/5] Setting up Python environment..."

module load u22/python/3.12.4 2>/dev/null || \
    module load u22/python/3.12 2>/dev/null || \
    module load u22/python/3.13 2>/dev/null || \
    module load u22/python/3.11.2 2>/dev/null || true

PYTHON=$(command -v python3)
[ -z "$PYTHON" ] && die "python3 not found"
log "  System Python: $($PYTHON --version 2>&1)"

VENV_DIR="${PROJECT_DIR}/venv"

if [ ! -f "$VENV_DIR/bin/activate" ]; then
    log "  Creating venv (one-time)..."
    $PYTHON -m venv "$VENV_DIR" || die "venv creation failed"
    log "  Created: $VENV_DIR"
fi

source "$VENV_DIR/bin/activate"
log "  Venv Python: $(python3 --version 2>&1)"

# ============================================================================
# STEP 2: Install packages (IDENTICAL to Colab cell 1.3)
# ============================================================================
log ""
log "[2/5] Installing packages (same as Colab)..."

if python3 -c "import chemprop, torch, rdkit, sklearn, pandas" 2>/dev/null; then
    log "  All packages already installed. Skipping pip."
    python3 -c "
import torch, chemprop, rdkit, pandas, numpy
print(f'  numpy={numpy.__version__}, pandas={pandas.__version__}')
print(f'  torch={torch.__version__}, chemprop={chemprop.__version__}')
print(f'  rdkit={rdkit.__version__}')
print(f'  CUDA={torch.cuda.is_available()}')
"
else
    log "  Installing (first time, needs network)..."
    PIP="python3 -m pip --disable-pip-version-check"
    #$PIP install --upgrade pip setuptools wheel -q 2>&1 | tail -1

    # EXACT same packages as Colab cell 1.3
    $PIP install numpy 'pandas>=2.0,<3.0' scipy scikit-learn joblib tqdm
    $PIP install rdkit
    $PIP install matplotlib seaborn plotly openpyxl
    $PIP install requests chembl-webresource-client pubchempy
    $PIP install chembl-downloader pystow
    $PIP install torch lightning
    $PIP install chemprop

    log "  Verifying..."
    python3 -c "
import torch, chemprop, rdkit, pandas, numpy
from rdkit import Chem
assert Chem.MolFromSmiles('CCO') is not None
print(f'  numpy={numpy.__version__}, pandas={pandas.__version__}')
print(f'  torch={torch.__version__}, chemprop={chemprop.__version__}')
print(f'  CUDA={torch.cuda.is_available()}')
print('  All imports OK.')
" || die "Package verification failed"
fi

python3 -c "
import torch, shutil, os, sys
if torch.cuda.is_available():
    print(f'  GPU: {torch.cuda.get_device_name(0)} ({torch.cuda.get_device_properties(0).total_mem/(1024**3):.1f} GB)')
else:
    print('  GPU: not available (CPU mode)')
cp = shutil.which('chemprop')
if not cp:
    cp = os.path.join(os.path.dirname(sys.executable), 'chemprop')
    cp = cp if os.path.exists(cp) else None
print(f'  CLI: {cp or \"Python API fallback\"}')
"

# ============================================================================
# STEP 3: Find existing run + verify all data
# ============================================================================
log ""
log "[3/5] Verifying package data..."

EXISTING_RUN=""
if [ -d "${PROJECT_DIR}/outputs/runs" ]; then
    for d in "${PROJECT_DIR}/outputs/runs"/run_*; do
        [ -d "$d" ] || continue
        if [ -d "$d/models/rf" ] && [ "$(find "$d/models/rf" -name '*.pkl' 2>/dev/null | head -1)" ]; then
            EXISTING_RUN="$(basename $d)"
            break
        fi
    done
fi

[ -z "$EXISTING_RUN" ] && die "No run with RF models found in outputs/runs/.
  Did you extract the pre-DMPNN package?
  Run: unzip -o antibiotic_pre_dmpnn_YYYYMMDD.zip"

RUN_ID="$EXISTING_RUN"
log "  Run ID: $RUN_ID"

export ANTIBIOTIC_PROJECT_DIR="$PROJECT_DIR"
export ANTIBIOTIC_DATA_MODE="real"
export ANTIBIOTIC_RUN_ID="$RUN_ID"

python3 << 'PYVERIFY'
import sys, os, glob
sys.path.insert(0, 'scripts')
import config, pandas as pd

errors = []
print()
for k, v in config.PATHOGENS.items():
    p = os.path.join(config.CHEMBL_DIR, v['csv_filename'])
    if os.path.exists(p) and os.path.getsize(p) > 10_000:
        print(f"  {k:20s} {len(pd.read_csv(p)):>6} compounds  [OK]")
    else:
        print(f"  {k:20s} MISSING  [ERROR]"); errors.append(v['csv_filename'])

for label, path, mn in [('maier', os.path.join(config.MAIER_DIR,'maier_combined.csv'), 900),
                         ('hub', os.path.join(config.HUB_DIR,config.HUB_CLEAN_FILENAME), 5000)]:
    n = len(pd.read_csv(path)) if os.path.exists(path) and os.path.getsize(path) > 1000 else 0
    ok = n > mn
    print(f"  {label:20s} {n:>6} compounds  [{'OK' if ok else 'ERROR'}]")
    if not ok: errors.append(label)

checks = [
    ('features', config.FEATURES_DIR, '*.npz', 5),
    ('splits', config.SPLITS_DIR, '*', 5),
    ('rf_models', config.RF_DIR, '**/*.pkl', 7),
    ('rf_screening', config.SCREENING_DIR, 'rf_*.csv', 12),
]
for label, d, pat, mn in checks:
    n = len(glob.glob(os.path.join(d, pat), recursive=('**' in pat)))
    ok = n >= mn
    print(f"  {label:20s} {n:>6} files      [{'OK' if ok else 'WARN' if n > 0 else 'ERROR'}]")
    if n == 0: errors.append(label)

if errors:
    print(f"\nMISSING: {', '.join(errors)}")
    sys.exit(1)
print(f"\n  All data verified.")
PYVERIFY

[ $? -ne 0 ] && die "Data verification failed."

# ============================================================================
# STEP 4: D-MPNN Training + Evaluation + Showcase
# ============================================================================
log ""
log "[4/5] D-MPNN Training..."
log "============================================================"
t0=$(date +%s)

python3 -u scripts/06_train_dmpnn.py

t1=$(date +%s)
log "  D-MPNN: $((t1 - t0))s"

log ""
log "  Evaluation..."
log "============================================================"

python3 scripts/07_evaluate.py

t2=$(date +%s)
log "  Eval: $((t2 - t1))s"

log ""
log "  Showcase..."
log "============================================================"

python3 scripts/08_create_showcase.py

t3=$(date +%s)

# ============================================================================
# STEP 5: Summary
# ============================================================================
RESULTS=$(python3 -c "import sys; sys.path.insert(0,'scripts'); import config; print(config.RESULTS_DIR)")
n_csv=$(find "$RESULTS" -name "*.csv" -type f 2>/dev/null | wc -l | tr -d ' ')
n_fig=$(find "$RESULTS/figures" -type f 2>/dev/null | wc -l | tr -d ' ')

log ""
log "============================================================"
log "  COMPLETE"
log "============================================================"
log "  Run ID:   $RUN_ID"
log "  Results:  $RESULTS"
log "  Output:   ${n_csv} CSVs, ${n_fig} figures"
log "  Time:     D-MPNN $((t1-t0))s + Eval $((t2-t1))s + Showcase $((t3-t2))s = $((t3-t0))s"
log ""
log "  Download:"
log "    scp -r $(whoami)@ada.iiit.ac.in:${RESULTS} ."
log "============================================================"