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

# Check if all packages import AND torch supports the GPU
NEED_INSTALL=true
if python3 -c "import chemprop, torch, rdkit, sklearn, pandas" 2>/dev/null; then
    # Packages exist, but check if torch supports Ada's GPU (GTX 1080 Ti = sm_61)
    GPU_OK=$(python3 -c "
import torch, warnings
warnings.filterwarnings('ignore')
if not torch.cuda.is_available():
    print('no_gpu')
else:
    try:
        # This will fail if sm_61 not supported
        t = torch.zeros(1, device='cuda')
        print('ok')
    except Exception:
        print('incompatible')
" 2>/dev/null)

    if [ "$GPU_OK" = "ok" ] || [ "$GPU_OK" = "no_gpu" ]; then
        NEED_INSTALL=false
        log "  All packages installed and GPU compatible."
        python3 -c "
import torch, chemprop, rdkit, pandas, numpy
print(f'  numpy={numpy.__version__}, pandas={pandas.__version__}')
print(f'  torch={torch.__version__}, chemprop={chemprop.__version__}')
print(f'  rdkit={rdkit.__version__}')
print(f'  CUDA={torch.cuda.is_available()}')
"
    else
        log "  Torch installed but INCOMPATIBLE with Ada GPU (GTX 1080 Ti = sm_61)."
        log "  Reinstalling torch with cu118 support..."
    fi
fi

if [ "$NEED_INSTALL" = true ]; then
    log "  Installing (first time, needs network)..."
    PIP="python3 -m pip --disable-pip-version-check"
    $PIP install --upgrade pip setuptools wheel

    # Same packages as Colab (except torch, handled specially for Ada GPU)
    $PIP install numpy 'pandas>=2.0,<3.0' scipy scikit-learn joblib tqdm
    $PIP install rdkit
    $PIP install matplotlib seaborn plotly openpyxl
    $PIP install requests chembl-webresource-client pubchempy
    $PIP install chembl-downloader pystow

    # ---- PyTorch: Ada has GTX 1080 Ti (sm_61, CUDA capability 6.1) ----
    # PyTorch >= 2.5 dropped sm_61 support. Must use 2.4.x with cu118.
    log "  Installing PyTorch for Ada GPU (GTX 1080 Ti needs cu118)..."
    $PIP install 'torch==2.4.*' 'lightning>=2.0,<2.5' --index-url https://download.pytorch.org/whl/cu118
    $PIP install chemprop

    log "  Verifying..."
    python3 -c "
import torch, chemprop, rdkit, pandas, numpy
from rdkit import Chem
assert Chem.MolFromSmiles('CCO') is not None
print(f'  numpy={numpy.__version__}, pandas={pandas.__version__}')
print(f'  torch={torch.__version__}, chemprop={chemprop.__version__}')
cuda_ok = torch.cuda.is_available()
print(f'  CUDA={cuda_ok}')
if cuda_ok:
    props = torch.cuda.get_device_properties(0)
    cap = f'{props.major}.{props.minor}'
    mem = props.total_memory / (1024**3)
    print(f'  GPU: {torch.cuda.get_device_name(0)} (sm_{props.major}{props.minor}, {mem:.1f} GB)')
print('  All imports OK.')
" || die "Package verification failed"
fi

python3 -c "
import torch, shutil, os, sys
cuda_ok = torch.cuda.is_available()
if cuda_ok:
    props = torch.cuda.get_device_properties(0)
    mem = props.total_memory / (1024**3)
    print(f'  GPU: {torch.cuda.get_device_name(0)} ({mem:.1f} GB)')
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
# STEP 5: Package all results into a single ZIP
# ============================================================================
log ""
log "[5/5] Packaging results..."
log "============================================================"

RUN_DIR=$(python3 -c "import sys; sys.path.insert(0,'scripts'); import config; print(config.RUN_DIR)")
RESULTS_DIR=$(python3 -c "import sys; sys.path.insert(0,'scripts'); import config; print(config.RESULTS_DIR)")

PACKAGE_NAME="${RUN_ID}_ada_complete"
ZIP_PATH="${PROJECT_DIR}/${PACKAGE_NAME}.zip"

python3 << PYPACKAGE
import zipfile, os, sys, glob
sys.path.insert(0, 'scripts')
import config

zip_path = "${ZIP_PATH}"
n_files = 0

with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:

    # 1. Pipeline code (scripts, utils, jobs)
    print('  [1/10] Pipeline scripts...')
    for code_dir in ['scripts', 'jobs']:
        full = os.path.join('${PROJECT_DIR}', code_dir)
        if os.path.isdir(full):
            for root, dirs, files in os.walk(full):
                dirs[:] = [d for d in dirs if d != '__pycache__']
                for f in files:
                    if f.endswith('.pyc'): continue
                    src = os.path.join(root, f)
                    arc = os.path.relpath(src, '${PROJECT_DIR}')
                    zf.write(src, arc)
                    n_files += 1
    n_py = len(glob.glob(os.path.join('${PROJECT_DIR}', 'scripts', '*.py')))
    n_util = len(glob.glob(os.path.join('${PROJECT_DIR}', 'scripts', 'utils', '*.py')))
    print(f'    {n_py} scripts, {n_util} utils')

    # 2. Shell scripts, requirements, docs, notebooks (top-level)
    print('  [2/10] Shell scripts, notebooks, docs...')
    for pat in ['*.sh', '*.bat', '*.ps1', '*.txt', '*.md', '*.ipynb']:
        for f in glob.glob(os.path.join('${PROJECT_DIR}', pat)):
            arc = os.path.relpath(f, '${PROJECT_DIR}')
            zf.write(f, arc)
            n_files += 1
            print(f'    {arc}')

    # 3. Resources (Maier Excel files)
    print('  [3/10] Maier Excel files (resources/)...')
    res_maier = os.path.join('${PROJECT_DIR}', 'resources', 'maier')
    if os.path.isdir(res_maier):
        for f in glob.glob(os.path.join(res_maier, '*.xlsx')):
            arc = os.path.relpath(f, '${PROJECT_DIR}')
            zf.write(f, arc)
            n_files += 1
    n_xlsx = len(glob.glob(os.path.join(res_maier, '*.xlsx'))) if os.path.isdir(res_maier) else 0
    print(f'    {n_xlsx} Excel files')

    # 4. D-MPNN models (checkpoints, configs, training logs)
    print('  [4/10] D-MPNN models...')
    dmpnn_dir = config.DMPNN_DIR
    if os.path.isdir(dmpnn_dir):
        for root, dirs, files in os.walk(dmpnn_dir):
            for f in files:
                src = os.path.join(root, f)
                arc = os.path.relpath(src, '${PROJECT_DIR}')
                zf.write(src, arc)
                n_files += 1
    n_ckpt = len(glob.glob(os.path.join(dmpnn_dir, '**', '*.ckpt'), recursive=True))
    n_pt = len(glob.glob(os.path.join(dmpnn_dir, '**', '*.pt'), recursive=True))
    print(f'    {n_ckpt} .ckpt + {n_pt} .pt files')

    # 5. RF models
    print('  [5/10] RF models...')
    rf_dir = config.RF_DIR
    if os.path.isdir(rf_dir):
        for root, dirs, files in os.walk(rf_dir):
            for f in files:
                src = os.path.join(root, f)
                arc = os.path.relpath(src, '${PROJECT_DIR}')
                zf.write(src, arc)
                n_files += 1
    n_rf = len(glob.glob(os.path.join(rf_dir, '**', '*.pkl'), recursive=True))
    print(f'    {n_rf} .pkl files')

    # 6. All results (screening lists, CV metrics, quality reports)
    print('  [6/10] Results (screening lists, metrics)...')
    results_dir = config.RESULTS_DIR
    if os.path.isdir(results_dir):
        for root, dirs, files in os.walk(results_dir):
            dirs[:] = [d for d in dirs if d != 'figures']
            for f in files:
                src = os.path.join(root, f)
                arc = os.path.relpath(src, '${PROJECT_DIR}')
                zf.write(src, arc)
                n_files += 1
    n_scr = len(glob.glob(os.path.join(config.SCREENING_DIR, '*.csv')))
    print(f'    {n_scr} screening lists')

    # 7. Figures (PNG + HTML)
    print('  [7/10] Figures...')
    fig_dir = config.FIGURES_DIR
    if os.path.isdir(fig_dir):
        for f in os.listdir(fig_dir):
            src = os.path.join(fig_dir, f)
            if os.path.isfile(src):
                arc = os.path.relpath(src, '${PROJECT_DIR}')
                zf.write(src, arc)
                n_files += 1
    n_png = len(glob.glob(os.path.join(fig_dir, '*.png'))) if os.path.isdir(fig_dir) else 0
    n_html = len(glob.glob(os.path.join(fig_dir, '*.html'))) if os.path.isdir(fig_dir) else 0
    print(f'    {n_png} PNGs, {n_html} interactive HTMLs')

    # 8. Processed data CSVs
    print('  [8/10] Processed data CSVs...')
    import pandas as pd
    for k, v in config.PATHOGENS.items():
        csv_path = os.path.join(config.CHEMBL_DIR, v['csv_filename'])
        if os.path.exists(csv_path):
            arc = os.path.relpath(csv_path, '${PROJECT_DIR}')
            zf.write(csv_path, arc)
            n_files += 1
            print(f'    {v["csv_filename"]}: {len(pd.read_csv(csv_path))} compounds')
    for fname in ['maier_combined.csv', 'maier_smiles_lookup.csv']:
        fpath = os.path.join(config.MAIER_DIR, fname)
        if os.path.exists(fpath):
            arc = os.path.relpath(fpath, '${PROJECT_DIR}')
            zf.write(fpath, arc)
            n_files += 1
    # Include Maier Excel files from data/maier/ too
    for f in glob.glob(os.path.join(config.MAIER_DIR, '*.xlsx')):
        arc = os.path.relpath(f, '${PROJECT_DIR}')
        zf.write(f, arc)
        n_files += 1
    hub_path = os.path.join(config.HUB_DIR, config.HUB_CLEAN_FILENAME)
    if os.path.exists(hub_path):
        arc = os.path.relpath(hub_path, '${PROJECT_DIR}')
        zf.write(hub_path, arc)
        n_files += 1

    # 9. Features + splits + D-MPNN input CSVs
    print('  [9/10] Features + splits + D-MPNN input...')
    for shared_dir in [config.FEATURES_DIR, config.SPLITS_DIR, config.DMPNN_INPUT_DIR]:
        if os.path.isdir(shared_dir):
            for root, dirs, files in os.walk(shared_dir):
                for f in files:
                    src = os.path.join(root, f)
                    arc = os.path.relpath(src, '${PROJECT_DIR}')
                    zf.write(src, arc)
                    n_files += 1
    n_npz = len(glob.glob(os.path.join(config.FEATURES_DIR, '*.npz')))
    n_splits = len(glob.glob(os.path.join(config.SPLITS_DIR, '*')))
    print(f'    {n_npz} .npz features, {n_splits} split files')

    # 10. Logs
    print('  [10/10] Logs...')
    if os.path.isdir(config.LOGS_DIR):
        for f in glob.glob(os.path.join(config.LOGS_DIR, '*.log')):
            arc = os.path.relpath(f, '${PROJECT_DIR}')
            zf.write(f, arc)
            n_files += 1

size_mb = os.path.getsize(zip_path) / (1024**2)
print(f'\n  Package: {zip_path}')
print(f'  Size:    {size_mb:.1f} MB')
print(f'  Files:   {n_files}')
PYPACKAGE

# ============================================================================
# Summary + download instructions
# ============================================================================
ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1)

log ""
log "============================================================"
log "  COMPLETE"
log "============================================================"
log "  Run ID:   $RUN_ID"
log "  Package:  $ZIP_PATH ($ZIP_SIZE)"
log "  Time:     D-MPNN $((t1-t0))s + Eval $((t2-t1))s + Showcase $((t3-t2))s = $((t3-t0))s total"
log ""
log "  DOWNLOAD TO YOUR LAPTOP:"
log "    scp $(whoami)@ada.iiit.ac.in:${ZIP_PATH} ."
log ""
log "  UPLOAD TO GOOGLE DRIVE:"
log "    1. Download the ZIP above to your laptop"
log "    2. Upload to Drive: My Drive/antibiotic_output/"
log "    3. Or in Colab, upload and extract into the pipeline directory"
log ""
log "  IN COLAB (to generate viz from Ada results):"
log "    1. Upload ${PACKAGE_NAME}.zip to Colab"
log "    2. Run:"
log "       import zipfile"
log "       zipfile.ZipFile('${PACKAGE_NAME}.zip').extractall(PIPELINE_DIR)"
log "    3. Then run cells 5.1, 5.2, 5.3 to view results"
log "============================================================"
