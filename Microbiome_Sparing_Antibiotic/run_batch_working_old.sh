#!/bin/bash
# ============================================================================
# run_ada_all_models.sh
#
# Runs the full pipeline on Ada HPC:
#   Phase 3B: D-MPNN (Chemprop)           -- skip if already done
#   Phase 3C: CheMeleon (Foundation D-MPNN) -- skip if already done
#   Phase 3D: MoLFormer-XL (Transformer)   -- skip if already done
#   Phase 4:  Evaluate + Showcase
#   Phase 5:  Comparative Analysis (all 4 models)
#   Phase 6:  Package everything into downloadable ZIP
#
# SMART SKIP: each phase checks for existing outputs and skips if found.
# This means you can re-run after a crash and it picks up where it left off.
#
# DATA: 100% offline (from extracted pre-DMPNN package).
# NETWORK: needed only for pip install (one-time) and MoLFormer HuggingFace
#          model download (~200 MB, cached for future runs).
#
# Usage:
#   cd ~/antibiotic-selectivity
#   bash run_ada_all_models.sh           # interactive (use tmux!)
#   sbatch run_ada_all_models.sh         # SLURM batch
#
# ============================================================================
#SBATCH --partition=u22
#SBATCH -A research
#SBATCH --qos=low
#SBATCH -n 10
#SBATCH --gres=gpu:1
#SBATCH --mem-per-cpu=2G
#SBATCH --time=1-00:00:00
#SBATCH --output=/home2/%u/antibiotic-selectivity/logs/all_models_%j.log
#SBATCH --job-name=all_models
#SBATCH --chdir=/home2/vishakha.agrawal/antibiotic-selectivity
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=vishakha.agrawal@students.iiit.ac.in

module load u22/python/3.12.4
source ~/antibiotic-selectivity/venv/bin/activate
cd ~/antibiotic-selectivity

set -eo pipefail

# ---- Project directory auto-detection ----
SCRIPT_DIR="/home2/vishakha.agrawal/antibiotic-selectivity"
PROJECT_DIR="$SCRIPT_DIR"
if [ -d "$PROJECT_DIR/scripts/utils" ]; then :
elif [ -d "$PROJECT_DIR/../scripts/utils" ]; then
    PROJECT_DIR="$(cd "$PROJECT_DIR/.." && pwd)"
fi
cd "$PROJECT_DIR"

log() { echo "[$(date '+%H:%M:%S')] $*"; }
die() { log "FATAL: $*"; exit 1; }

log "============================================================"
log "  All Models Pipeline (Ada HPC)"
log "  RF + D-MPNN + CheMeleon + MoLFormer + Compare"
log "============================================================"
log "  Directory: $PROJECT_DIR"
mkdir -p logs

# ============================================================================
# STEP 1: Python + venv
# ============================================================================
log ""
log "[1/8] Setting up Python environment..."

module load u22/python/3.12.4 2>/dev/null || \
    module load u22/python/3.12 2>/dev/null || \
    module load u22/python/3.13 2>/dev/null || true

PYTHON=$(command -v python3)
[ -z "$PYTHON" ] && die "python3 not found"
log "  System Python: $($PYTHON --version 2>&1)"

VENV_DIR="${PROJECT_DIR}/venv"
if [ ! -f "$VENV_DIR/bin/activate" ]; then
    log "  Creating venv..."
    $PYTHON -m venv "$VENV_DIR" || die "venv creation failed"
fi
source "$VENV_DIR/bin/activate"
log "  Venv Python: $(python3 --version 2>&1)"

# ============================================================================
# STEP 2: Install packages (all models, same as Colab)
# ============================================================================
log ""
log "[2/8] Installing packages..."

# Check if everything is already installed (fast path)
NEED_INSTALL=true
if python3 -c "import chemprop, torch, rdkit, sklearn, pandas, transformers" 2>/dev/null; then
    # Check GPU compat
    GPU_OK=$(python3 -c "
import torch, warnings
warnings.filterwarnings('ignore')
if not torch.cuda.is_available():
    print('no_gpu')
else:
    try:
        t = torch.zeros(1, device='cuda')
        print('ok')
    except Exception:
        print('incompatible')
" 2>/dev/null)
    if [ "$GPU_OK" = "ok" ] || [ "$GPU_OK" = "no_gpu" ]; then
        NEED_INSTALL=false
        log "  All packages installed and compatible."
        python3 -c "
import torch, chemprop, rdkit, pandas, numpy, transformers
print(f'  numpy={numpy.__version__}, pandas={pandas.__version__}')
print(f'  torch={torch.__version__}, chemprop={chemprop.__version__}')
print(f'  transformers={transformers.__version__}')
print(f'  CUDA={torch.cuda.is_available()}')
"
    else
        log "  Torch installed but incompatible with GPU. Reinstalling..."
    fi
fi

if [ "$NEED_INSTALL" = true ]; then
    log "  Installing packages (needs network)..."
    PIP="python3 -m pip --disable-pip-version-check"
    $PIP install --upgrade pip setuptools wheel

    # Core
    $PIP install numpy 'pandas>=2.0,<3.0' scipy scikit-learn joblib tqdm
    $PIP install rdkit
    $PIP install matplotlib seaborn plotly openpyxl
    $PIP install requests chembl-webresource-client pubchempy
    $PIP install chembl-downloader pystow

    # PyTorch: Ada GTX 1080 Ti (sm_61) needs cu118
    log "  Installing PyTorch (cu118 for GTX 1080 Ti)..."
    $PIP install 'torch==2.4.*' --index-url https://download.pytorch.org/whl/cu118
    $PIP install 'lightning>=2.0,<2.5'
    $PIP install chemprop

    # MoLFormer needs HuggingFace transformers
    # IMPORTANT: MoLFormer custom code (modeling_molformer.py on HuggingFace) was
    # written for transformers 4.x. Version 5.x has breaking API changes in
    # PreTrainedModel. Pin to 4.x until IBM updates the model.
    log "  Installing transformers (for MoLFormer, pinned to 4.x)..."
    $PIP install 'transformers>=4.30,<5.0'

    log "  Verifying..."
    python3 -c "
import torch, chemprop, rdkit, pandas, numpy, transformers
from rdkit import Chem
assert Chem.MolFromSmiles('CCO') is not None
print(f'  numpy={numpy.__version__}, pandas={pandas.__version__}')
print(f'  torch={torch.__version__}, chemprop={chemprop.__version__}')
print(f'  transformers={transformers.__version__}')
cuda_ok = torch.cuda.is_available()
print(f'  CUDA={cuda_ok}')
if cuda_ok:
    props = torch.cuda.get_device_properties(0)
    mem = props.total_memory / (1024**3)
    print(f'  GPU: {torch.cuda.get_device_name(0)} ({mem:.1f} GB)')
print('  All imports OK.')
" || die "Package verification failed"
fi

# GPU summary
python3 -c "
import torch
if torch.cuda.is_available():
    props = torch.cuda.get_device_properties(0)
    mem = props.total_memory / (1024**3)
    print(f'  GPU: {torch.cuda.get_device_name(0)} ({mem:.1f} GB)')
else:
    print('  GPU: not available (CPU mode, will be slow)')
"

# ============================================================================
# STEP 2b: Restore pretrained weights from packaged ZIP (if present)
# ============================================================================
if [ -d "${PROJECT_DIR}/pretrained_weights" ]; then
    log "  Restoring pretrained weights from package..."

    # CheMeleon MPNN weights -> ~/.chemprop/
    CHEMPROP_CACHE="$HOME/.chemprop"
    mkdir -p "$CHEMPROP_CACHE"
    if [ -d "${PROJECT_DIR}/pretrained_weights/chemprop" ]; then
        for f in "${PROJECT_DIR}/pretrained_weights/chemprop"/*.pt; do
            [ -f "$f" ] || continue
            fname=$(basename "$f")
            if [ ! -f "$CHEMPROP_CACHE/$fname" ]; then
                cp "$f" "$CHEMPROP_CACHE/$fname"
                log "    Restored: ~/.chemprop/$fname"
            else
                log "    Already cached: ~/.chemprop/$fname"
            fi
        done
    fi

    # MoLFormer HF cache -> $PROJECT_DIR/.hf_cache/
    if [ -d "${PROJECT_DIR}/pretrained_weights/hf_cache" ]; then
        mkdir -p "${PROJECT_DIR}/.hf_cache"
        if [ -z "$(find "${PROJECT_DIR}/.hf_cache" -name '*.bin' -o -name '*.safetensors' 2>/dev/null | head -1)" ]; then
            cp -r "${PROJECT_DIR}/pretrained_weights/hf_cache/"* "${PROJECT_DIR}/.hf_cache/" 2>/dev/null || true
            log "    Restored: .hf_cache/ (MoLFormer)"
        else
            log "    Already cached: .hf_cache/ (MoLFormer)"
        fi
    fi

    # External benchmark caches -> $PROJECT_DIR/.benchmark_cache/
    if [ -d "${PROJECT_DIR}/pretrained_weights/benchmark_cache" ]; then
        mkdir -p "${PROJECT_DIR}/.benchmark_cache"
        if [ ! -d "${PROJECT_DIR}/.benchmark_cache/stokes" ] || [ ! -d "${PROJECT_DIR}/.benchmark_cache/wong" ]; then
            cp -r "${PROJECT_DIR}/pretrained_weights/benchmark_cache/"* "${PROJECT_DIR}/.benchmark_cache/" 2>/dev/null || true
            log "    Restored: .benchmark_cache/ (Stokes/Wong)"
        else
            log "    Already cached: .benchmark_cache/ (Stokes/Wong)"
        fi
    fi
fi

# ============================================================================
# STEP 3: Find run + verify all data
# ============================================================================
log ""
log "[3/8] Verifying data and existing results..."

# Find the run directory (from Colab package)
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

[ -z "$EXISTING_RUN" ] && die "No run with RF models found.
  Extract pre-DMPNN package first: unzip -o antibiotic_pre_dmpnn_YYYYMMDD.zip"

RUN_ID="$EXISTING_RUN"
log "  Run ID: $RUN_ID"

export ANTIBIOTIC_PROJECT_DIR="$PROJECT_DIR"
export ANTIBIOTIC_DATA_MODE="real"
export ANTIBIOTIC_RUN_ID="$RUN_ID"

# HuggingFace cache: store downloaded models persistently in project dir
export HF_HOME="${PROJECT_DIR}/.hf_cache"
export TRANSFORMERS_CACHE="${PROJECT_DIR}/.hf_cache"
mkdir -p "$HF_HOME"
log "  HuggingFace cache: $HF_HOME"

# Verify data and detect which phases are already complete
python3 << 'PYVERIFY'
import sys, os, glob
sys.path.insert(0, 'scripts')
import config, pandas as pd

errors = []
print()
print("  DATA:")
for k, v in config.PATHOGENS.items():
    p = os.path.join(config.CHEMBL_DIR, v['csv_filename'])
    if os.path.exists(p) and os.path.getsize(p) > 10_000:
        print(f"    {k:20s} {len(pd.read_csv(p)):>6} compounds  [OK]")
    else:
        print(f"    {k:20s} MISSING  [ERROR]"); errors.append(v['csv_filename'])

for label, path, mn in [('maier', os.path.join(config.MAIER_DIR,'maier_combined.csv'), 900),
                         ('hub', os.path.join(config.HUB_DIR,config.HUB_CLEAN_FILENAME), 5000)]:
    n = len(pd.read_csv(path)) if os.path.exists(path) and os.path.getsize(path) > 1000 else 0
    ok = n > mn
    print(f"    {label:20s} {n:>6} compounds  [{'OK' if ok else 'ERROR'}]")
    if not ok: errors.append(label)

print()
print("  EXISTING RESULTS:")
checks = [
    ('rf_models', config.RF_DIR, '**/*.pkl', 7),
    ('rf_screening', config.SCREENING_DIR, 'rf_*.csv', 4),
    ('dmpnn_models', config.DMPNN_DIR, '**/*.ckpt', 1),
    ('dmpnn_metrics', config.RESULTS_DIR, 'dmpnn_cv_metrics.json', 1),
    ('chemeleon_frozen',  os.path.join(config.MODELS_DIR, 'chemeleon_frozen'), '**/*.pt', 1),
    ('chemeleon_f_metrics', config.RESULTS_DIR, 'chemeleon_frozen_cv_metrics.json', 1),
    ('molformer_models', os.path.join(config.MODELS_DIR, 'molformer'), '**/*.pt', 1),
    ('molformer_metrics', config.RESULTS_DIR, 'molformer_cv_metrics.json', 1),
    ('features', config.FEATURES_DIR, '*.npz', 5),
    ('splits', config.SPLITS_DIR, '*', 5),
]
for label, d, pat, mn in checks:
    if os.path.isfile(d):
        n = 1
    else:
        n = len(glob.glob(os.path.join(d, pat), recursive=('**' in pat)))
    status = 'DONE' if n >= mn else 'PENDING' if n == 0 else f'PARTIAL ({n})'
    print(f"    {label:20s} {n:>6} files      [{status}]")

if errors:
    print(f"\nMISSING DATA: {', '.join(errors)}")
    sys.exit(1)
print(f"\n  Data verified. Ready to run.")
PYVERIFY
[ $? -ne 0 ] && die "Data verification failed."

# ============================================================================
# STEP 4: D-MPNN Training (skip if already done)
# ============================================================================
log ""
log "[4/8] Phase 3B: D-MPNN Training..."
log "============================================================"

DMPNN_METRICS="${PROJECT_DIR}/outputs/runs/${RUN_ID}/results/dmpnn_cv_metrics.json"
if [ -f "$DMPNN_METRICS" ] && [ "$(python3 -c "
import json
with open('$DMPNN_METRICS') as f: d=json.load(f)
ok = sum(1 for v in d.values() if v.get('mean_roc_auc') is not None)
print(ok)
" 2>/dev/null)" -ge 4 ]; then
    log "  SKIP: D-MPNN already trained ($DMPNN_METRICS exists with 4+ tasks)"
    t0=$(date +%s); t1=$t0
else
    t0=$(date +%s)
    python3 -u scripts/06_train_dmpnn.py
    t1=$(date +%s)
    log "  D-MPNN: $((t1 - t0))s"
fi

# Interim report: RF + D-MPNN
log "  Generating interim progress report..."
python3 scripts/16_interim_report.py 2>/dev/null || true

# ============================================================================
# STEP 5: CheMeleon Frozen Encoder (fast baseline, ~10 min)
# ============================================================================
log ""
log "[5/8] Phase 3C: CheMeleon Frozen Encoder (train only FFN head)..."
log "============================================================"

CHEMELEON_FROZEN_METRICS="${PROJECT_DIR}/outputs/runs/${RUN_ID}/results/chemeleon_frozen_cv_metrics.json"
if [ -f "$CHEMELEON_FROZEN_METRICS" ] && [ "$(python3 -c "
import json
with open('$CHEMELEON_FROZEN_METRICS') as f: d=json.load(f)
ok = sum(1 for v in d.values() if v.get('mean_roc_auc') is not None)
print(ok)
" 2>/dev/null)" -ge 4 ]; then
    log "  SKIP: CheMeleon Frozen already trained"
else
    python3 -u scripts/11_train_chemeleon_frozen.py
    log "  CheMeleon Frozen: done"
fi
t2=$(date +%s)

# Interim report: RF + D-MPNN + CheMeleon Frozen
log "  Generating interim progress report..."
python3 scripts/16_interim_report.py 2>/dev/null || true

# ============================================================================
# STEP 5b: CheMeleon Fine-Tune (DISABLED -- too slow for current run)
# Code is kept in scripts/09_train_chemeleon.py for future use.
# To re-enable: uncomment the block below and add 'chemeleon' back to
# PIPELINES in 12_compare_models.py and 13_candidate_report.py.
# ============================================================================
log ""
log "[5b/8] Phase 3C: CheMeleon Fine-Tune... SKIPPED (disabled to save time)"
log "  To run manually later: python3 -u scripts/09_train_chemeleon.py"

# ============================================================================
# STEP 6: MoLFormer-XL Transformer (skip if already done)
# ============================================================================
log ""
log "[6/8] Phase 3D: MoLFormer-XL Fine-Tuning..."
log "============================================================"

# MoLFormer downloads pretrained weights from HuggingFace (~200 MB).
# Test network connectivity first.
log "  HuggingFace cache: $HF_HOME"
MOLFORMER_CACHED=$(find "$HF_HOME" -name "*.bin" -o -name "*.safetensors" 2>/dev/null | head -1)
if [ -n "$MOLFORMER_CACHED" ]; then
    log "  Pretrained weights already cached locally."
else
    log "  Pretrained weights not cached. Testing network for HuggingFace download..."
    if python3 -c "
import urllib.request
try:
    urllib.request.urlopen('https://huggingface.co', timeout=10)
    print('  Network: OK (huggingface.co reachable)')
except Exception as e:
    print(f'  Network: FAILED ({e})')
    print('  MoLFormer needs to download pretrained weights (~200 MB) from HuggingFace.')
    print('  Options:')
    print('    1. Run on a node with internet access')
    print('    2. Pre-download on login node: python3 -c \"from transformers import AutoModel; AutoModel.from_pretrained(\\\"ibm/MoLFormer-XL-both-10pct\\\", trust_remote_code=True)\"')
    print('    3. Copy .hf_cache/ from another machine')
    import sys; sys.exit(1)
" 2>&1; then
        log "  Will download pretrained weights on first model load."
    else
        log "  WARNING: Network unavailable. MoLFormer may fail if weights are not cached."
        log "  Continuing anyway (CheMeleon and D-MPNN results are still valid)."
    fi
fi

MOLFORMER_METRICS="${PROJECT_DIR}/outputs/runs/${RUN_ID}/results/molformer_cv_metrics.json"
if [ -f "$MOLFORMER_METRICS" ] && [ "$(python3 -c "
import json
with open('$MOLFORMER_METRICS') as f: d=json.load(f)
ok = sum(1 for v in d.values() if v.get('mean_roc_auc') is not None)
print(ok)
" 2>/dev/null)" -ge 4 ]; then
    log "  SKIP: MoLFormer already trained ($MOLFORMER_METRICS exists with 4+ tasks)"
    t3=$t2
else
    # Run MoLFormer (may fail if network unavailable, that's OK)
    set +e
    python3 -u scripts/10_train_molformer.py
    MOLFORMER_EXIT=$?
    set -e
    t3=$(date +%s)
    if [ $MOLFORMER_EXIT -eq 0 ]; then
        log "  MoLFormer: $((t3 - t2))s"
    else
        log "  WARNING: MoLFormer failed (exit code $MOLFORMER_EXIT)."
        log "  This is OK. D-MPNN + CheMeleon results are still valid."
        log "  Common cause: network unavailable for HuggingFace download."
    fi
fi

# ============================================================================
# STEP 7: Evaluation + Showcase + Comparative Analysis
# ============================================================================
log ""
log "[7/8] Evaluation, Showcase, and Comparative Analysis..."
log "============================================================"

log "  Running evaluation (07_evaluate.py)..."
python3 scripts/07_evaluate.py || log "  WARNING: Evaluation had issues"

log "  Running showcase (08_create_showcase.py)..."
python3 scripts/08_create_showcase.py || log "  WARNING: Showcase had issues"

log "  Backfilling full metrics into existing result JSONs (15_backfill_full_metrics.py)..."
python3 scripts/15_backfill_full_metrics.py || log "  WARNING: Backfill had issues"

log "  Running comparative analysis (12_compare_models.py)..."
python3 scripts/12_compare_models.py || log "  WARNING: Comparison had issues"

log "  Generating candidate report (13_candidate_report.py)..."
python3 scripts/13_candidate_report.py || log "  WARNING: Report had issues"

# Optional: external benchmark (Stokes/Wong published models)
# This downloads pretrained checkpoints and scores our candidates.
# Uses a separate venv (venv_v1/) - does NOT touch main venv.
# If it fails, all other results are still valid.
log ""
log "  External benchmark (optional, ~10 min)..."
set +e
python3 scripts/14_external_benchmark.py
EXT_EXIT=$?
set -e
if [ $EXT_EXIT -eq 0 ]; then
    log "  External benchmark: OK"
    # Re-run report to incorporate external scores
    python3 scripts/13_candidate_report.py 2>/dev/null || true
else
    log "  External benchmark: skipped or failed (exit $EXT_EXIT)"
    log "  This is OK. All other results are valid."
fi

t4=$(date +%s)
log "  Eval + Compare: $((t4 - t3))s"

# ============================================================================
# STEP 8: Package everything into downloadable ZIP
# ============================================================================
log ""
log "[8/8] Packaging all results..."
log "============================================================"

PACKAGE_NAME="${RUN_ID}_all_models_complete"
ZIP_PATH="${PROJECT_DIR}/${PACKAGE_NAME}.zip"

python3 << PYPACKAGE
import zipfile, os, sys, glob
sys.path.insert(0, 'scripts')
import config

zip_path = "${ZIP_PATH}"
n_files = 0

with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:

    # 1. Pipeline scripts + utils
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
                    zf.write(src, arc); n_files += 1
    n_py = len(glob.glob(os.path.join('${PROJECT_DIR}', 'scripts', '*.py')))
    n_util = len(glob.glob(os.path.join('${PROJECT_DIR}', 'scripts', 'utils', '*.py')))
    print(f'    {n_py} scripts, {n_util} utils')

    # 2. Shell scripts, notebooks, docs
    print('  [2/10] Shell scripts, notebooks, docs...')
    for pat in ['*.sh', '*.bat', '*.ps1', '*.txt', '*.md', '*.ipynb']:
        for f in glob.glob(os.path.join('${PROJECT_DIR}', pat)):
            arc = os.path.relpath(f, '${PROJECT_DIR}')
            zf.write(f, arc); n_files += 1

    # 3. Resources (Maier Excel)
    print('  [3/10] Resources...')
    res = os.path.join('${PROJECT_DIR}', 'resources')
    if os.path.isdir(res):
        for root, dirs, files in os.walk(res):
            for f in files:
                src = os.path.join(root, f)
                arc = os.path.relpath(src, '${PROJECT_DIR}')
                zf.write(src, arc); n_files += 1

    # 4-5. ALL model directories
    for label, model_dir in [('D-MPNN', config.DMPNN_DIR),
                              ('CheMeleon', os.path.join(config.MODELS_DIR, 'chemeleon')),
                              ('CheMeleon-Frozen', os.path.join(config.MODELS_DIR, 'chemeleon_frozen')),
                              ('MoLFormer', os.path.join(config.MODELS_DIR, 'molformer')),
                              ('RF', config.RF_DIR)]:
        print(f'  [model] {label}...')
        if os.path.isdir(model_dir):
            count = 0
            for root, dirs, files in os.walk(model_dir):
                for f in files:
                    src = os.path.join(root, f)
                    arc = os.path.relpath(src, '${PROJECT_DIR}')
                    zf.write(src, arc); n_files += 1; count += 1
            print(f'    {count} files')
        else:
            print(f'    not found (skipped)')

    # 6. ALL results (screening, metrics, figures, comparison)
    print('  [6/10] Results + figures + comparison...')
    if os.path.isdir(config.RESULTS_DIR):
        count = 0
        for root, dirs, files in os.walk(config.RESULTS_DIR):
            for f in files:
                src = os.path.join(root, f)
                arc = os.path.relpath(src, '${PROJECT_DIR}')
                zf.write(src, arc); n_files += 1; count += 1
        print(f'    {count} files')

    # 7. Processed data CSVs
    print('  [7/10] Processed data CSVs...')
    import pandas as pd
    for k, v in config.PATHOGENS.items():
        p = os.path.join(config.CHEMBL_DIR, v['csv_filename'])
        if os.path.exists(p):
            arc = os.path.relpath(p, '${PROJECT_DIR}')
            zf.write(p, arc); n_files += 1
            print(f'    {v["csv_filename"]}: {len(pd.read_csv(p))} compounds')
    for fname in ['maier_combined.csv', 'maier_smiles_lookup.csv']:
        fpath = os.path.join(config.MAIER_DIR, fname)
        if os.path.exists(fpath):
            arc = os.path.relpath(fpath, '${PROJECT_DIR}')
            zf.write(fpath, arc); n_files += 1
    for f in glob.glob(os.path.join(config.MAIER_DIR, '*.xlsx')):
        arc = os.path.relpath(f, '${PROJECT_DIR}')
        zf.write(f, arc); n_files += 1
    hub_path = os.path.join(config.HUB_DIR, config.HUB_CLEAN_FILENAME)
    if os.path.exists(hub_path):
        arc = os.path.relpath(hub_path, '${PROJECT_DIR}')
        zf.write(hub_path, arc); n_files += 1

    # 8. Features + splits + D-MPNN input
    print('  [8/10] Features + splits...')
    for d in [config.FEATURES_DIR, config.SPLITS_DIR, config.DMPNN_INPUT_DIR]:
        if os.path.isdir(d):
            for root, dirs, files in os.walk(d):
                for f in files:
                    src = os.path.join(root, f)
                    arc = os.path.relpath(src, '${PROJECT_DIR}')
                    zf.write(src, arc); n_files += 1

    # 9. Logs
    print('  [9/12] Logs...')
    if os.path.isdir(config.LOGS_DIR):
        for f in glob.glob(os.path.join(config.LOGS_DIR, '*.log')):
            arc = os.path.relpath(f, '${PROJECT_DIR}')
            zf.write(f, arc); n_files += 1

    # 10. Pretrained model weights (CheMeleon + MoLFormer)
    print('  [10/12] Pretrained weights...')

    # 10a. CheMeleon MPNN weights from ~/.chemprop/ and $PROJECT_DIR/.chemprop/
    chemprop_dirs = [
        os.path.expanduser('~/.chemprop'),
        os.path.join('${PROJECT_DIR}', '.chemprop'),
    ]
    chemprop_count = 0
    for cpdir in chemprop_dirs:
        if os.path.isdir(cpdir):
            for f in os.listdir(cpdir):
                if f.endswith('.pt') or f.endswith('.ckpt'):
                    src = os.path.join(cpdir, f)
                    # Store under pretrained_weights/chemprop/ in the ZIP
                    arc = os.path.join('pretrained_weights', 'chemprop', f)
                    if arc not in [info.filename for info in zf.infolist()]:
                        zf.write(src, arc); n_files += 1; chemprop_count += 1
                        size_mb_f = os.path.getsize(src) / (1024**2)
                        print(f'    {f} ({size_mb_f:.1f} MB)')
    if chemprop_count == 0:
        print('    No CheMeleon .pt files found (will re-download on next run)')

    # 10b. MoLFormer HuggingFace cache from $PROJECT_DIR/.hf_cache/
    hf_dir = os.path.join('${PROJECT_DIR}', '.hf_cache')
    hf_count = 0
    if os.path.isdir(hf_dir):
        for root, dirs, files in os.walk(hf_dir):
            for f in files:
                src = os.path.join(root, f)
                arc = os.path.join('pretrained_weights', 'hf_cache',
                                   os.path.relpath(src, hf_dir))
                zf.write(src, arc); n_files += 1; hf_count += 1
        hf_size = sum(os.path.getsize(os.path.join(r, f))
                      for r, _, fs in os.walk(hf_dir) for f in fs) / (1024**2)
        print(f'    MoLFormer HF cache: {hf_count} files ({hf_size:.0f} MB)')
    else:
        print('    No HuggingFace cache found (will re-download on next run)')

    # 11. External benchmark caches (Stokes/Wong pretrained checkpoints)
    print('  [11/12] External benchmark caches...')
    bench_dir = os.path.join('${PROJECT_DIR}', '.benchmark_cache')
    bench_count = 0
    if os.path.isdir(bench_dir):
        for root, dirs, files in os.walk(bench_dir):
            for f in files:
                src = os.path.join(root, f)
                arc = os.path.join('pretrained_weights', 'benchmark_cache',
                                   os.path.relpath(src, bench_dir))
                zf.write(src, arc); n_files += 1; bench_count += 1
        bench_size = sum(os.path.getsize(os.path.join(r, f))
                         for r, _, fs in os.walk(bench_dir) for f in fs) / (1024**2)
        print(f'    Stokes/Wong caches: {bench_count} files ({bench_size:.0f} MB)')
    else:
        print('    No benchmark cache found (will re-download on next run)')

    # 12. Survey
    print('  [12/12] Documentation...')
    for doc in ['beyond_dmpnn_survey.md']:
        dp = os.path.join('${PROJECT_DIR}', doc)
        if os.path.exists(dp):
            zf.write(dp, doc); n_files += 1

size_mb = os.path.getsize(zip_path) / (1024**2)
print(f'\n  Package: {zip_path}')
print(f'  Size:    {size_mb:.1f} MB')
print(f'  Files:   {n_files}')
PYPACKAGE

# ============================================================================
# Summary
# ============================================================================
ZIP_SIZE=$(du -h "$ZIP_PATH" 2>/dev/null | cut -f1 || echo "?")
t_end=$(date +%s)

log ""
log "============================================================"
log "  COMPLETE"
log "============================================================"
log "  Run ID:   $RUN_ID"
log "  Package:  $ZIP_PATH ($ZIP_SIZE)"
log "  Time:     total $((t_end - t0))s ($( echo "scale=1; ($t_end-$t0)/60" | bc 2>/dev/null || echo '?')m)"
log ""

# Show which models completed
python3 << 'PYSUMMARY'
import sys, os, json, glob
sys.path.insert(0, 'scripts')
import config

print("  Models trained:")
for label, metrics_file in [
    ('RF',               'rf_cv_metrics.json'),
    ('D-MPNN',           'dmpnn_cv_metrics.json'),
    ('CheMeleon-Frozen', 'chemeleon_frozen_cv_metrics.json'),
    ('MoLFormer',        'molformer_cv_metrics.json'),
]:
    path = os.path.join(config.RESULTS_DIR, metrics_file)
    if os.path.exists(path):
        try:
            with open(path) as f:
                d = json.load(f)
            n_ok = sum(1 for v in d.values() if v.get('mean_roc_auc') is not None)
            best_roc = max((v.get('mean_roc_auc', 0) for v in d.values() if v.get('mean_roc_auc')), default=0)
            print(f"    {label:15s} {n_ok}/7 tasks  best ROC-AUC={best_roc:.4f}  [DONE]")
        except Exception:
            print(f"    {label:15s} metrics file corrupt  [ERROR]")
    else:
        print(f"    {label:15s} not found  [SKIPPED]")

# Comparison outputs
comp = os.path.join(config.RESULTS_DIR, 'comparison_full_metrics.csv')
if os.path.exists(comp):
    import pandas as pd
    df = pd.read_csv(comp)
    print(f"\n  Comparison: {len(df)} rows in comparison_full_metrics.csv")

n_fig = len(glob.glob(os.path.join(config.FIGURES_DIR, '*'))) if os.path.isdir(config.FIGURES_DIR) else 0
n_scr = len(glob.glob(os.path.join(config.SCREENING_DIR, '*.csv'))) if os.path.isdir(config.SCREENING_DIR) else 0
print(f"  Figures:    {n_fig}")
print(f"  Screening:  {n_scr} lists")
PYSUMMARY

log ""
log "  DOWNLOAD TO YOUR LAPTOP:"
log "    scp $(whoami)@ada.iiit.ac.in:${ZIP_PATH} ."
log ""
log "  THEN IN COLAB:"
log "    1. Upload ZIP"
log "    2. Run cell 4.3d (Import Ada results)"
log "    3. Run cell 4.5b (Comparative analysis)"
log "    4. Run cell 5.1-5.3 (View results)"
log "============================================================"
