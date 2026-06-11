#!/bin/bash
# ============================================================================
# run_batch.sh v3
#
# Full pipeline on Ada HPC. Everything on scratch + Google Drive. NO home writes.
#
# FLAGS:
#   --fresh    Deep-verify all outputs. Rerun any phase with gaps.
#   --resume   (default) Quick skip if metrics JSON has 4+ tasks.
#
# FLOW:
#   home2 -> scratch (copy at start, read-only after that)
#   scratch (ALL computation, ALL temp files, ALL caches)
#   scratch -> Google Drive (zip + rclone at end)
#   /tmp -> SLURM log (copied to scratch at end)
#   NOTHING written to home2.
#
# Usage:
#   sbatch run_batch.sh              # resume mode
#   sbatch run_batch.sh --fresh      # deep-verify, rerun gaps
#
# ============================================================================
#SBATCH --partition=u22
#SBATCH -A research
## SBATCH --qos=low
#SBATCH -n 10
#SBATCH --gres=gpu:1
#SBATCH --mem-per-cpu=2G
#SBATCH --time=2-00:00:00
#SBATCH --output=/tmp/all_models_%j.log
#SBATCH --job-name=all_models
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=vishakha.agrawal@students.iiit.ac.in

module load u22/python/3.12.4
export PYTHONUNBUFFERED=1

set -eo pipefail

# ============================================================================
# REDIRECT ALL TEMP/CACHE TO SCRATCH (home is full, never write there)
# ============================================================================
export TMPDIR=/scratch/vishakha.agrawal/tmp
export TEMPDIR=/scratch/vishakha.agrawal/tmp
export PIP_CACHE_DIR=/scratch/vishakha.agrawal/pip_cache
export XDG_CACHE_HOME=/scratch/vishakha.agrawal/cache
export PIP_NO_CACHE_DIR=0
mkdir -p "$TMPDIR" "$PIP_CACHE_DIR" "$XDG_CACHE_HOME" 2>/dev/null || true

# ============================================================================
# FLAG PARSING
# ============================================================================
FRESH_MODE=false
for arg in "$@"; do
    case "$arg" in
        --fresh) FRESH_MODE=true ;;
        --resume) FRESH_MODE=false ;;
    esac
done

HOME_DIR="/home2/vishakha.agrawal/antibiotic-selectivity"
SCRATCH_DIR="/scratch/vishakha.agrawal/antibiotic-selectivity-v2"
SCRATCH_BASE="/scratch/vishakha.agrawal"
RCLONE_BIN="$SCRATCH_BASE/rclone"
RCLONE_CONF="$SCRATCH_BASE/.config/rclone/rclone.conf"
DRIVE_REMOTE="gdrive"
DRIVE_FOLDER="antibiotic_data/ada_backup_v2"
SLURM_LOG="/tmp/all_models_${SLURM_JOB_ID:-unknown}.log"

log() { echo "[$(date '+%H:%M:%S')] $*"; }
die() { log "FATAL: $*"; exit 1; }

echo "=========================================="
echo "SLURM_JOB_ID = ${SLURM_JOB_ID:-unknown}"
echo "SLURM_NODELIST = ${SLURM_NODELIST:-unknown}"
echo "SLURM_JOB_GPUS = ${SLURM_JOB_GPUS:-none}"
echo "=========================================="

log "============================================================"
log "  All Models Pipeline (Ada HPC) v3"
log "  Mode:    $([ "$FRESH_MODE" = true ] && echo 'FRESH (deep-verify, rerun gaps)' || echo 'RESUME (quick skip)')"
log "  RF + D-MPNN + CheMeleon + MoLFormer + Compare"
log "============================================================"
log "  Home:    $HOME_DIR (READ ONLY)"
log "  Scratch: $SCRATCH_DIR"
log "  Node:    $(hostname)"
log "  Job ID:  ${SLURM_JOB_ID:-interactive}"
log "  TMPDIR:  $TMPDIR"
log "  PIP:     $PIP_CACHE_DIR"
log "  Log:     $SLURM_LOG"
log ""

# ============================================================================
# STEP 0: Copy project from home to scratch
# ============================================================================
log "[0/10] Copying project from home to scratch..."
log "  This copies venv (~6 GB) + all code/data. May take 5-7 minutes."

t_copy_start=$(date +%s)
mkdir -p "$SCRATCH_DIR"
# DISABLED: rsync -av --stats "$HOME_DIR/" "$SCRATCH_DIR/" 2>&1 | tail -10
rc=$?
t_copy_end=$(date +%s)

[ $rc -ne 0 ] && die "rsync from home to scratch failed (exit $rc)"

SCRATCH_FILES=$(find "$SCRATCH_DIR" -type f | wc -l)
SCRATCH_SIZE=$(du -sh "$SCRATCH_DIR" | cut -f1)
log "  OK: $SCRATCH_FILES files, $SCRATCH_SIZE in $((t_copy_end - t_copy_start))s"
log "  Scratch free: $(df -h /scratch | tail -1 | awk '{print $4}')"
log ""

PROJECT_DIR="$SCRATCH_DIR"
cd "$PROJECT_DIR"
source "$PROJECT_DIR/venv/bin/activate"

# ============================================================================
# STEP 0b: Fix venv_v1 (install chemprop v1 for external benchmark)
# ============================================================================
log "[0b/10] venv_v1 SKIPPED (chemprop v1 requires Python <3.9, Ada has 3.12)"

VENV_V1="$PROJECT_DIR/venv_v1"

VENV1_OK=true
if [ -f "$VENV_V1/bin/activate" ]; then
    VENV1_CHEMPROP=$("$VENV_V1/bin/python3" -c "import chemprop; print(chemprop.__version__)" 2>/dev/null || echo "none")
    log "  Current venv_v1 chemprop: $VENV1_CHEMPROP"
    if echo "$VENV1_CHEMPROP" | grep -q "^1\."; then
        VENV1_OK=true
        log "  venv_v1 OK: chemprop $VENV1_CHEMPROP"
    else
        log "  Need chemprop v1.x. Rebuilding venv_v1..."
    fi
else
    log "  venv_v1 does not exist. Creating..."
fi

if [ "$VENV1_OK" = false ]; then
    SYSTEM_PYTHON="/usr/local/apps/python-3.12.4/bin/python3"
    [ ! -x "$SYSTEM_PYTHON" ] && SYSTEM_PYTHON=$(which python3)
    log "  Using Python: $($SYSTEM_PYTHON --version 2>&1)"

    rm -rf "$VENV_V1"
    log "  Creating fresh venv_v1..."
    $SYSTEM_PYTHON -m venv "$VENV_V1"
    source "$VENV_V1/bin/activate"

    log "  Upgrading pip in venv_v1..."
    pip install --upgrade pip setuptools wheel --progress-bar on -v 2>&1 | tail -5

    log "  Installing PyTorch 2.0 (cu118) for chemprop v1..."
    pip install 'torch==2.4.*' --index-url https://download.pytorch.org/whl/cu118 --progress-bar on 2>&1 | tee >(tail -10)
    log "  PyTorch install exit: $?"

    log "  Installing chemprop 1.7.1..."
    pip install chemprop==1.7.1 --progress-bar on 2>&1 | tee >(tail -10)
    rc=$?
    log "  chemprop 1.7.1 install exit: $rc"

    if [ $rc -ne 0 ]; then
        log "  chemprop 1.7.1 failed. Trying 1.6.1..."
        pip install chemprop==1.6.1 --progress-bar on 2>&1 | tee >(tail -10)
        rc=$?
        log "  chemprop 1.6.1 install exit: $rc"
    fi

    # Verify
    log "  Verifying venv_v1..."
    VENV1_RESULT=$("$VENV_V1/bin/python3" -c "
import sys
print(f'  Python: {sys.version}')
try:
    import torch
    print(f'  torch: {torch.__version__}')
except ImportError as e:
    print(f'  torch: FAILED ({e})')
try:
    import chemprop
    print(f'  chemprop: {chemprop.__version__}')
except ImportError as e:
    print(f'  chemprop: FAILED ({e})')
" 2>&1)
    log "$VENV1_RESULT"

    if echo "$VENV1_RESULT" | grep -q "chemprop: 1\."; then
        log "  venv_v1 OK"
    else
        log "  WARN: chemprop v1 install failed. External benchmark will be skipped."
        log "  This does NOT affect main pipeline results."
    fi

    deactivate 2>/dev/null
    source "$PROJECT_DIR/venv/bin/activate"
fi

log ""

# ============================================================================
# STEP 1: Verify main Python environment (DO NOT TOUCH main venv)
# ============================================================================
log "[1/10] Verifying main Python environment..."

PYTHON=$(command -v python3)
[ -z "$PYTHON" ] && die "python3 not found"
log "  Python: $($PYTHON --version 2>&1) at $(which python3)"

python3 << 'PYCHECK'
import sys
print(f"  sys.prefix: {sys.prefix}")
print(f"  sys.executable: {sys.executable}")

checks = []
def check(name, fn):
    try:
        result = fn()
        print(f"  [OK]   {name}: {result}")
        checks.append(True)
    except Exception as e:
        print(f"  [FAIL] {name}: {e}")
        checks.append(False)

check("numpy",    lambda: __import__('numpy').__version__)
check("pandas",   lambda: __import__('pandas').__version__)
check("scipy",    lambda: __import__('scipy').__version__)
check("sklearn",  lambda: __import__('sklearn').__version__)
check("rdkit",    lambda: __import__('rdkit').__version__)
check("torch",    lambda: f"{__import__('torch').__version__}, CUDA={__import__('torch').cuda.is_available()}")
check("chemprop", lambda: __import__('chemprop').__version__)
check("transformers", lambda: __import__('transformers').__version__)
check("matplotlib", lambda: __import__('matplotlib').__version__)
check("seaborn",  lambda: __import__('seaborn').__version__)
check("plotly",   lambda: __import__('plotly').__version__)
check("openpyxl", lambda: __import__('openpyxl').__version__)
check("tqdm",     lambda: __import__('tqdm').__version__)
check("joblib",   lambda: __import__('joblib').__version__)

import torch
if torch.cuda.is_available():
    props = torch.cuda.get_device_properties(0)
    print(f"  GPU: {torch.cuda.get_device_name(0)} ({props.total_memory/(1024**3):.1f} GB)")
else:
    print(f"  GPU: NOT AVAILABLE (will be slow)")

n_ok = sum(checks)
n_fail = len(checks) - n_ok
print(f"\n  Verification: {n_ok}/{len(checks)} OK, {n_fail} failed")
if n_fail > 0:
    import sys; sys.exit(1)
PYCHECK
[ $? -ne 0 ] && die "Main venv verification failed."
log ""

# ============================================================================
# STEP 2: Restore pretrained weights
# ============================================================================
log "[2/10] Checking pretrained weight caches..."

if [ -d "${PROJECT_DIR}/pretrained_weights" ]; then
    log "  Found pretrained_weights/. Restoring..."

    CHEMPROP_CACHE="$SCRATCH_BASE/.chemprop"
    mkdir -p "$CHEMPROP_CACHE" 2>/dev/null || true
    if [ -d "${PROJECT_DIR}/pretrained_weights/chemprop" ]; then
        for f in "${PROJECT_DIR}/pretrained_weights/chemprop"/*.pt; do
            [ -f "$f" ] || continue
            fname=$(basename "$f")
            if [ ! -f "$CHEMPROP_CACHE/$fname" ]; then
                cp "$f" "$CHEMPROP_CACHE/$fname"
                log "    Restored: $fname ($(du -sh "$f" | cut -f1))"
            else
                log "    Cached: $fname"
            fi
        done
    fi

    if [ -d "${PROJECT_DIR}/pretrained_weights/hf_cache" ]; then
        mkdir -p "${PROJECT_DIR}/.hf_cache"
        if [ -z "$(find "${PROJECT_DIR}/.hf_cache" -name '*.bin' -o -name '*.safetensors' 2>/dev/null | head -1)" ]; then
            cp -rv "${PROJECT_DIR}/pretrained_weights/hf_cache/"* "${PROJECT_DIR}/.hf_cache/" 2>&1 | tail -5
            log "    Restored: .hf_cache/"
        else
            log "    Cached: .hf_cache/"
        fi
    fi

    if [ -d "${PROJECT_DIR}/pretrained_weights/benchmark_cache" ]; then
        mkdir -p "${PROJECT_DIR}/.benchmark_cache"
        cp -rn "${PROJECT_DIR}/pretrained_weights/benchmark_cache/"* "${PROJECT_DIR}/.benchmark_cache/" 2>/dev/null || true
        log "    Restored: .benchmark_cache/"
    fi
else
    log "  No pretrained_weights/ directory."
fi
log ""

# ============================================================================
# STEP 3: Find run + verify data + deep verification
# ============================================================================
log "[3/10] Verifying data and finding run..."

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

[ -z "$EXISTING_RUN" ] && die "No run with RF models found. Extract pre-DMPNN package first."

RUN_ID="$EXISTING_RUN"
log "  Run ID: $RUN_ID"

export ANTIBIOTIC_PROJECT_DIR="$PROJECT_DIR"
export ANTIBIOTIC_DATA_MODE="real"
export ANTIBIOTIC_RUN_ID="$RUN_ID"
export HF_HOME="${PROJECT_DIR}/.hf_cache"
export TRANSFORMERS_CACHE="${PROJECT_DIR}/.hf_cache"
mkdir -p "$HF_HOME"

# Data verification (verbose)
python3 -u << 'PYVERIFY'
import sys, os, glob
sys.path.insert(0, 'scripts')
import config, pandas as pd

errors = []
print()
print("  DATA VERIFICATION:")
for k, v in config.PATHOGENS.items():
    p = os.path.join(config.CHEMBL_DIR, v['csv_filename'])
    if os.path.exists(p) and os.path.getsize(p) > 10_000:
        df = pd.read_csv(p)
        print(f"    {k:20s} {len(df):>6} compounds, {len(df.columns)} cols  [OK]")
    else:
        exists = os.path.exists(p)
        size = os.path.getsize(p) if exists else 0
        print(f"    {k:20s} exists={exists}, size={size}  [ERROR]")
        errors.append(k)

for label, path, mn in [('maier', os.path.join(config.MAIER_DIR,'maier_combined.csv'), 900),
                         ('hub', os.path.join(config.HUB_DIR,config.HUB_CLEAN_FILENAME), 5000)]:
    if os.path.exists(path) and os.path.getsize(path) > 1000:
        n = len(pd.read_csv(path))
        ok = n > mn
        print(f"    {label:20s} {n:>6} compounds  [{'OK' if ok else 'ERROR: too few'}]")
        if not ok: errors.append(label)
    else:
        print(f"    {label:20s} MISSING  [ERROR]")
        errors.append(label)

if errors:
    print(f"\n  MISSING DATA: {', '.join(errors)}")
    sys.exit(1)
print(f"\n  All data OK.")
PYVERIFY
[ $? -ne 0 ] && die "Data verification failed."

# Deep verification of existing outputs
log ""
log "  DEEP OUTPUT VERIFICATION:"
VERIFY_JSON=$(python3 -u << 'PYDEEP'
import sys, os, glob, json
sys.path.insert(0, 'scripts')
import config

results = {}

def count_check(label, directory, pattern, min_count, recursive=False):
    if os.path.isdir(directory):
        n = len(glob.glob(os.path.join(directory, pattern), recursive=recursive))
    else:
        n = 0
    ok = n >= min_count
    status = 'OK' if ok else f'NEED {min_count}, have {n}'
    print(f"    {label:25s} {n:>4} files  [{status}]", file=sys.stderr)
    return ok, n

def metrics_check(label, filepath, min_tasks=7):
    tasks = 0
    if os.path.exists(filepath):
        try:
            with open(filepath) as f:
                d = json.load(f)
            tasks = sum(1 for v in d.values() if v.get('mean_roc_auc') is not None)
        except Exception:
            pass
    ok = tasks >= min_tasks
    status = 'OK' if ok else f'NEED {min_tasks}, have {tasks}'
    print(f"    {label:25s} {tasks:>4} tasks [{status}]", file=sys.stderr)
    return ok, tasks

r = {}

# RF
rf_models_ok, rf_n = count_check('RF models (.pkl)', config.RF_DIR, '*.pkl', 7)
rf_metrics_ok, rf_tasks = metrics_check('RF metrics', os.path.join(config.RESULTS_DIR, 'rf_cv_metrics.json'))
rf_screen_ok, rf_scr = count_check('RF screening', config.SCREENING_DIR, 'rf_*.csv', 12)
r['rf'] = {'ok': rf_models_ok and rf_metrics_ok, 'models': rf_n, 'tasks': rf_tasks, 'screening': rf_scr}

# D-MPNN
dm_models_ok, dm_n = count_check('DMPNN checkpoints', config.DMPNN_DIR, '**/*.ckpt', 7, recursive=True)
dm_metrics_ok, dm_tasks = metrics_check('DMPNN metrics', os.path.join(config.RESULTS_DIR, 'dmpnn_cv_metrics.json'))
dm_screen_ok, dm_scr = count_check('DMPNN screening', config.SCREENING_DIR, 'dmpnn_*.csv', 4)
r['dmpnn'] = {'ok': dm_models_ok and dm_metrics_ok, 'ckpts': dm_n, 'tasks': dm_tasks, 'screening': dm_scr}

# CheMeleon Frozen
cf_dir = os.path.join(config.MODELS_DIR, 'chemeleon_frozen')
cf_models_ok, cf_n = count_check('CheMeleon Frozen models', cf_dir, '**/*.pt', 7, recursive=True)
cf_metrics_ok, cf_tasks = metrics_check('CheMeleon Frozen metrics', os.path.join(config.RESULTS_DIR, 'chemeleon_frozen_cv_metrics.json'))
r['chemeleon_frozen'] = {'ok': cf_models_ok and cf_metrics_ok, 'models': cf_n, 'tasks': cf_tasks}

# MoLFormer
mf_dir = os.path.join(config.MODELS_DIR, 'molformer')
mf_models_ok, mf_n = count_check('MoLFormer models', mf_dir, '**/*.pt', 7, recursive=True)
mf_metrics_ok, mf_tasks = metrics_check('MoLFormer metrics', os.path.join(config.RESULTS_DIR, 'molformer_cv_metrics.json'))
r['molformer'] = {'ok': mf_models_ok and mf_metrics_ok, 'models': mf_n, 'tasks': mf_tasks}

# Features + splits
feat_ok, _ = count_check('Features (.npz)', config.FEATURES_DIR, '*.npz', 5)
split_ok, _ = count_check('Splits', config.SPLITS_DIR, '*', 5)
r['features'] = {'ok': feat_ok}
r['splits'] = {'ok': split_ok}

# Evaluation
fig_ok, n_fig = count_check('Figures (.png)', config.FIGURES_DIR, '*.png', 10)
comp_ok = os.path.exists(os.path.join(config.RESULTS_DIR, 'comparison_full_metrics.csv'))
print(f"    {'Comparison CSV':25s} {'yes' if comp_ok else 'no':>4}       [{'OK' if comp_ok else 'MISSING'}]", file=sys.stderr)
r['evaluation'] = {'ok': fig_ok and comp_ok, 'figures': n_fig, 'comparison': comp_ok}

print(json.dumps(r))
PYDEEP
)

log "  Verification JSON: $VERIFY_JSON"

# Parse what needs running
NEED_DMPNN=true
NEED_CHEMELEON=true
NEED_MOLFORMER=true
NEED_EVAL=true

if [ "$FRESH_MODE" = true ]; then
    log ""
    log "  FRESH MODE: rerun only phases with gaps."
    NEED_DMPNN=$(echo "$VERIFY_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print('false' if d['dmpnn']['ok'] else 'true')")
    NEED_CHEMELEON=$(echo "$VERIFY_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print('false' if d['chemeleon_frozen']['ok'] else 'true')")
    NEED_MOLFORMER=$(echo "$VERIFY_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print('false' if d['molformer']['ok'] else 'true')")
    NEED_EVAL=$(echo "$VERIFY_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print('false' if d['evaluation']['ok'] else 'true')")
else
    log ""
    log "  RESUME MODE: quick skip checks."
fi

log ""
log "  === EXECUTION PLAN ==="
log "  D-MPNN:          $([ "$NEED_DMPNN" = true ] && echo 'WILL RUN' || echo 'SKIP (complete)')"
log "  CheMeleon Frozen: $([ "$NEED_CHEMELEON" = true ] && echo 'WILL RUN' || echo 'SKIP (complete)')"
log "  MoLFormer:        $([ "$NEED_MOLFORMER" = true ] && echo 'WILL RUN' || echo 'SKIP (complete)')"
log "  Evaluation:       $([ "$NEED_EVAL" = true ] && echo 'WILL RUN' || echo 'SKIP (complete)')"
log "  ======================"
log ""

# ============================================================================
# STEP 4: D-MPNN Training
# ============================================================================
log "[4/10] Phase 3B: D-MPNN Training..."
log "============================================================"

DMPNN_METRICS="${PROJECT_DIR}/outputs/runs/${RUN_ID}/results/dmpnn_cv_metrics.json"

if [ "$FRESH_MODE" = false ]; then
    if [ -f "$DMPNN_METRICS" ] && [ "$(python3 -c "
import json
with open('$DMPNN_METRICS') as f: d=json.load(f)
ok = sum(1 for v in d.values() if v.get('mean_roc_auc') is not None)
print(ok)" 2>/dev/null)" -ge 4 ]; then
        NEED_DMPNN=false
    fi
fi

if [ "$NEED_DMPNN" = true ]; then
    log "  Starting D-MPNN training (7 tasks, 5-fold CV each)..."
    t0=$(date +%s)
    python3 -u scripts/06_train_dmpnn.py 2>&1
    rc=$?
    t1=$(date +%s)
    log "  D-MPNN exit code: $rc, time: $((t1 - t0))s"
    [ $rc -ne 0 ] && log "  WARNING: D-MPNN had issues (exit $rc)"
else
    log "  SKIP: D-MPNN outputs verified complete"
    t0=$(date +%s); t1=$t0
fi

log "  Generating interim report..."
python3 -u scripts/16_interim_report.py 2>&1 || true
log ""

# ============================================================================
# STEP 5: CheMeleon Frozen Encoder
# ============================================================================
log "[5/10] Phase 3C: CheMeleon Frozen Encoder..."
log "============================================================"

CHEMELEON_FROZEN_METRICS="${PROJECT_DIR}/outputs/runs/${RUN_ID}/results/chemeleon_frozen_cv_metrics.json"

if [ "$FRESH_MODE" = false ]; then
    if [ -f "$CHEMELEON_FROZEN_METRICS" ] && [ "$(python3 -c "
import json
with open('$CHEMELEON_FROZEN_METRICS') as f: d=json.load(f)
ok = sum(1 for v in d.values() if v.get('mean_roc_auc') is not None)
print(ok)" 2>/dev/null)" -ge 4 ]; then
        NEED_CHEMELEON=false
    fi
fi

if [ "$NEED_CHEMELEON" = true ]; then
    log "  Starting CheMeleon Frozen training..."
    python3 -u scripts/11_train_chemeleon_frozen.py 2>&1
    rc=$?
    log "  CheMeleon Frozen exit code: $rc"
    [ $rc -ne 0 ] && log "  WARNING: CheMeleon Frozen had issues (exit $rc)"
else
    log "  SKIP: CheMeleon Frozen outputs verified complete"
fi
t2=$(date +%s)

log "  Generating interim report..."
python3 -u scripts/16_interim_report.py 2>&1 || true
log ""
log "[5b/10] CheMeleon Fine-Tune... SKIPPED (disabled)"
log ""

# ============================================================================
# STEP 6: MoLFormer-XL
# ============================================================================
log "[6/10] Phase 3D: MoLFormer-XL Fine-Tuning..."
log "============================================================"

log "  HuggingFace cache: $HF_HOME"
MOLFORMER_CACHED=$(find "$HF_HOME" -name "*.bin" -o -name "*.safetensors" 2>/dev/null | head -1)
if [ -n "$MOLFORMER_CACHED" ]; then
    log "  Pretrained weights: cached locally"
else
    log "  Pretrained weights: NOT cached. Testing network..."
    python3 -u -c "
import urllib.request
try:
    resp = urllib.request.urlopen('https://huggingface.co', timeout=10)
    print(f'  Network: OK (status {resp.status})')
except Exception as e:
    print(f'  Network: FAILED ({e})')
    print('  MoLFormer needs ~200 MB from HuggingFace.')
    import sys; sys.exit(1)
" 2>&1 || log "  WARNING: Network unavailable. MoLFormer may fail."
fi

MOLFORMER_METRICS="${PROJECT_DIR}/outputs/runs/${RUN_ID}/results/molformer_cv_metrics.json"

if [ "$FRESH_MODE" = false ]; then
    if [ -f "$MOLFORMER_METRICS" ] && [ "$(python3 -c "
import json
with open('$MOLFORMER_METRICS') as f: d=json.load(f)
ok = sum(1 for v in d.values() if v.get('mean_roc_auc') is not None)
print(ok)" 2>/dev/null)" -ge 4 ]; then
        NEED_MOLFORMER=false
    fi
fi

if [ "$NEED_MOLFORMER" = true ]; then
    log "  Starting MoLFormer-XL training..."
    set +e
    python3 -u scripts/10_train_molformer.py 2>&1
    MOLFORMER_EXIT=$?
    set -e
    t3=$(date +%s)
    log "  MoLFormer exit code: $MOLFORMER_EXIT, time: $((t3 - t2))s"
    [ $MOLFORMER_EXIT -ne 0 ] && log "  WARNING: MoLFormer failed. Other results still valid."
else
    log "  SKIP: MoLFormer outputs verified complete"
    t3=$t2
fi
log ""

# ============================================================================
# STEP 7: Evaluation + Showcase + Comparative Analysis
# ============================================================================
log "[7/10] Evaluation, Showcase, Comparative Analysis..."
log "============================================================"

if [ "$FRESH_MODE" = true ] || [ "$NEED_EVAL" = true ]; then
    log "  Running 07_evaluate.py..."
    python3 -u scripts/07_evaluate.py 2>&1
    log "  Exit: $?"

    log "  Running 08_create_showcase.py..."
    python3 -u scripts/08_create_showcase.py 2>&1
    log "  Exit: $?"

    log "  Running 15_backfill_full_metrics.py..."
    python3 -u scripts/15_backfill_full_metrics.py 2>&1
    log "  Exit: $?"

    log "  Running 12_compare_models.py..."
    python3 -u scripts/12_compare_models.py 2>&1
    log "  Exit: $?"

    log "  Running 13_candidate_report.py..."
    python3 -u scripts/13_candidate_report.py 2>&1
    log "  Exit: $?"
else
    log "  SKIP: Evaluation outputs already complete"
fi

log ""
log "  External benchmark: SKIPPED (chemprop v1 not available on Python 3.12)"
set +e
echo "  Skipped: 14_external_benchmark.py (requires chemprop v1 / Python <3.9)"
EXT_EXIT=$?
set -e
log "  External benchmark exit: $EXT_EXIT"
if [ $EXT_EXIT -eq 0 ]; then
    log "  Re-running candidate report with external scores..."
    python3 -u scripts/13_candidate_report.py 2>&1 || true
else
    log "  External benchmark failed. Main results unaffected."
fi

t4=$(date +%s)
log ""

# ============================================================================
# STEP 8: Create SEPARATE zips on scratch
# ============================================================================
log "[8/10] Creating separate zip archives on scratch..."

t_zip_start=$(date +%s)
cd "$SCRATCH_DIR"

ZIP_DIR="$SCRATCH_DIR/_zips"
rm -rf "$ZIP_DIR"
mkdir -p "$ZIP_DIR"

zip_it() {
    local zipname="$1"; shift
    local zippath="$ZIP_DIR/$zipname"
    log "  Zipping: $* -> $zipname"
    rm -f "$zippath"
    zip -rq "$zippath" "$@" 2>/dev/null
    local rc=$?
    if [ $rc -eq 0 ] && [ -f "$zippath" ]; then
        local size=$(du -sh "$zippath" | cut -f1)
        local count=$(unzip -l "$zippath" 2>/dev/null | tail -1 | awk '{print $2}')
        log "    OK: $size ($count files)"
    else
        log "    FAILED (exit $rc). Source dirs: $*"
        ls -la "$@" 2>/dev/null | head -5 | while read line; do log "      $line"; done
    fi
}

log ""
log "  --- Priority 1: Results (small, upload first) ---"
RESULTS_REL="outputs/runs/$RUN_ID/results"
[ -d "$RESULTS_REL" ] && zip_it "results.zip" "$RESULTS_REL" || log "  WARN: $RESULTS_REL not found"

log ""
log "  --- Priority 2: Small files ---"
zip_it "features_splits.zip" outputs/shared/
zip_it "data.zip" data/
zip_it "scripts_and_jobs.zip" scripts/ jobs/
zip_it "resources.zip" resources/

# Copy the /tmp log into scratch logs/ before zipping
cp "$SLURM_LOG" "$SCRATCH_DIR/logs/" 2>/dev/null || true
zip_it "logs.zip" logs/

find . -maxdepth 1 -type f -not -name '*.zip' -not -path './_zips/*' -printf '%f\n' > /tmp/root_list_$$.txt
if [ -s /tmp/root_list_$$.txt ]; then
    cat /tmp/root_list_$$.txt | zip -q "$ZIP_DIR/root_files.zip" -@
    log "  root_files.zip: OK ($(du -sh "$ZIP_DIR/root_files.zip" | cut -f1))"
fi
rm -f /tmp/root_list_$$.txt

log ""
log "  --- Priority 3: Caches ---"
zip_it "benchmark_cache.zip" .benchmark_cache/
zip_it "hf_cache.zip" .hf_cache/

log ""
log "  --- Priority 4: Models (large) ---"
MODELS_REL="outputs/runs/$RUN_ID/models"
[ -d "$MODELS_REL" ] && zip_it "models.zip" "$MODELS_REL" || log "  WARN: $MODELS_REL not found"

log ""
log "  --- Priority 5: Environments (largest) ---"
zip_it "venv.zip" venv/
zip_it "venv_v1.zip" venv_v1/

t_zip_end=$(date +%s)
log ""
log "  All zips created in $((t_zip_end - t_zip_start))s"
log ""
log "  ZIP INVENTORY:"
ls -lhS "$ZIP_DIR/"*.zip 2>/dev/null | awk '{print "    " $5 "  " $NF}'
TOTAL_ZIPS=$(ls "$ZIP_DIR/"*.zip 2>/dev/null | wc -l)
log "  Total: $TOTAL_ZIPS zips"
log ""

# ============================================================================
# STEP 9: Upload to Google Drive via rclone
# ============================================================================
log "[9/10] Uploading to Google Drive..."
log "============================================================"

UPLOAD_OK=false

if [ -x "$RCLONE_BIN" ] && [ -f "$RCLONE_CONF" ]; then
    export RCLONE_CONFIG="$RCLONE_CONF"

    log "  Testing Drive connection..."
    $RCLONE_BIN lsf "$DRIVE_REMOTE": --max-depth 1 > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        log "  Drive connection: OK"
        log "  Target: $DRIVE_FOLDER/"
        log ""

        UPLOAD_ERRORS=0
        UPLOAD_COUNT=0
        t_upload_start=$(date +%s)

        UPLOAD_ORDER=(
            "results.zip"
            "features_splits.zip"
            "data.zip"
            "scripts_and_jobs.zip"
            "resources.zip"
            "logs.zip"
            "root_files.zip"
            "benchmark_cache.zip"
            "hf_cache.zip"
            "models.zip"
            "venv.zip"
            "venv_v1.zip"
        )

        for zipname in "${UPLOAD_ORDER[@]}"; do
            zippath="$ZIP_DIR/$zipname"
            [ -f "$zippath" ] || { log "  SKIP: $zipname (not found)"; continue; }
            zipsize=$(du -sh "$zippath" | cut -f1)

            log "  Uploading: $zipname ($zipsize)..."
            t_up0=$(date +%s)

            $RCLONE_BIN copy "$zippath" "$DRIVE_REMOTE:$DRIVE_FOLDER/" \
                --progress --transfers=1 --checkers=1 \
                --drive-chunk-size=64M 2>&1 | grep -E "%|Transferred" | tail -5

            rc=${PIPESTATUS[0]}
            t_up1=$(date +%s)

            if [ $rc -eq 0 ]; then
                log "    OK ($zipsize in $((t_up1 - t_up0))s)"
                UPLOAD_COUNT=$((UPLOAD_COUNT + 1))
            else
                log "    FAILED (exit $rc). Will retry with collect_and_archive.sh --drive"
                UPLOAD_ERRORS=$((UPLOAD_ERRORS + 1))
            fi
        done

        # Upload the batch log too
        if [ -f "$SLURM_LOG" ]; then
            log "  Uploading: batch log..."
            $RCLONE_BIN copy "$SLURM_LOG" "$DRIVE_REMOTE:$DRIVE_FOLDER/" --quiet 2>/dev/null
            log "    OK"
        fi

        t_upload_end=$(date +%s)

        # Verify
        log ""
        log "  DRIVE CONTENTS:"
        $RCLONE_BIN lsf "$DRIVE_REMOTE:$DRIVE_FOLDER/" --format "ps" 2>/dev/null | while read line; do
            log "    $line"
        done

        if [ $UPLOAD_ERRORS -eq 0 ]; then
            UPLOAD_OK=true
            log ""
            log "  All $UPLOAD_COUNT zips uploaded in $(( (t_upload_end - t_upload_start) / 60 ))m"
        else
            log ""
            log "  $UPLOAD_COUNT uploaded, $UPLOAD_ERRORS failed."
            log "  Retry: bash ~/collect_and_archive.sh --drive"
        fi
    else
        log "  Drive connection FAILED. Token expired?"
        log "  FIX: bash ~/collect_and_archive.sh --setup-drive"
    fi
else
    log "  rclone not configured. Skipping Drive upload."
    log "  FIX: bash ~/collect_and_archive.sh --setup-drive"
fi
log ""

# ============================================================================
# STEP 10: Save metadata (to SCRATCH, not home) + summary
# ============================================================================
log "[10/10] Summary..."

METADATA_FILE="$SCRATCH_DIR/.last_batch_job.txt"
cat > "$METADATA_FILE" << METAEOF
NODE=$(hostname)
SCRATCH_DIR=$SCRATCH_DIR
ZIP_DIR=$ZIP_DIR
JOB_ID=${SLURM_JOB_ID:-unknown}
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
RUN_ID=${RUN_ID}
FRESH_MODE=${FRESH_MODE}
UPLOAD_OK=${UPLOAD_OK}
ZIPS=$(ls -1 "$ZIP_DIR/"*.zip 2>/dev/null | xargs -I{} basename {} | tr '\n' ' ')
METAEOF

t_end=$(date +%s)
TOTAL_SECS=$((t_end - t_copy_start))
TOTAL_MINS=$((TOTAL_SECS / 60))

log ""
log "============================================================"
log "  COMPLETE"
log "============================================================"
log "  Run ID:     $RUN_ID"
log "  Mode:       $([ "$FRESH_MODE" = true ] && echo 'FRESH' || echo 'RESUME')"
log "  Node:       $(hostname)"
log "  Time:       ${TOTAL_MINS}m ${TOTAL_SECS}s"
log "  Drive:      $([ "$UPLOAD_OK" = true ] && echo 'ALL UPLOADED' || echo 'NOT uploaded')"
log "  Log:        $SLURM_LOG"
log "  Scratch:    $ZIP_DIR/"
log ""

python3 -u << 'PYSUMMARY'
import sys, os, json, glob
sys.path.insert(0, 'scripts')
import config

print("  MODEL RESULTS:")
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
            best = max((v.get('mean_roc_auc', 0) for v in d.values() if v.get('mean_roc_auc')), default=0)
            all_aucs = [v.get('mean_roc_auc', 0) for v in d.values() if v.get('mean_roc_auc')]
            avg = sum(all_aucs)/len(all_aucs) if all_aucs else 0
            print(f"    {label:15s} {n_ok}/7 tasks  best={best:.4f}  avg={avg:.4f}  [DONE]")
        except Exception as e:
            print(f"    {label:15s} corrupt: {e}  [ERROR]")
    else:
        print(f"    {label:15s} not found  [SKIPPED]")

comp = os.path.join(config.RESULTS_DIR, 'comparison_full_metrics.csv')
if os.path.exists(comp):
    import pandas as pd
    df = pd.read_csv(comp)
    print(f"\n  Comparison: {len(df)} rows in comparison_full_metrics.csv")
    print(f"  Columns: {', '.join(df.columns[:8])}...")

n_fig_png = len(glob.glob(os.path.join(config.FIGURES_DIR, '*.png')))
n_fig_html = len(glob.glob(os.path.join(config.FIGURES_DIR, '*.html')))
n_fig_pdf = len(glob.glob(os.path.join(config.FIGURES_DIR, '*.pdf')))
n_scr = len(glob.glob(os.path.join(config.SCREENING_DIR, '*.csv')))
n_reports = len(glob.glob(os.path.join(config.REPORTS_DIR, '*'))) if os.path.isdir(config.REPORTS_DIR) else 0

print(f"  Figures:    {n_fig_png} PNG, {n_fig_html} HTML, {n_fig_pdf} PDF")
print(f"  Screening:  {n_scr} lists")
print(f"  Reports:    {n_reports}")
PYSUMMARY

log ""
if [ "$UPLOAD_OK" = true ]; then
    log "  Results on Google Drive: $DRIVE_FOLDER/"
    log "  In Colab: Run All (auto-loads from Drive ada_backup/)"
else
    log "  Results on SCRATCH (purged in 7 days!):"
    log "    Node: $(hostname)"
    log "    Path: $ZIP_DIR/"
    log "  Upload: srun on $(hostname), then: bash ~/collect_and_archive.sh --drive"
fi
log "============================================================"
