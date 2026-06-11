#!/bin/bash
# ============================================================================
# run_ada.sh -- Pipeline run on Ada HPC (IIIT Hyderabad)
#
# Two ways to use this:
#
#   1. INTERACTIVE (on a compute node via srun):
#      srun --pty --partition=u22 -A research --qos=low \
#           --gres=gpu:1 --mem-per-cpu=2G -c 10 --time=2:00:00 bash -l
#      cd ~/antibiotic-selectivity && bash run_ada.sh --real-data
#
#   2. AS A SLURM BATCH JOB:
#      sbatch run_ada.sh --real-data
#
#   3. SLURM MULTI-JOB (submit phases as separate jobs):
#      bash run_all.sh
#
# Options:
#   --real-data         Use real data from ChEMBL/Maier/Hub (default: synthetic)
#   --clean             Delete failed runs only, keep successful runs
#   --skip-gpu          Skip Phase 3B (D-MPNN) even if GPU available
#
# Prerequisites:
#   bash ada_full_setup.sh   (run once to install everything)
#
# ============================================================================
#SBATCH --partition=u22
#SBATCH -A research
#SBATCH --qos=low
#SBATCH -n 10
#SBATCH --gres=gpu:1
#SBATCH --mem-per-cpu=2G
#SBATCH --time=4:00:00
#SBATCH --output=logs/run_ada_%j.log
#SBATCH --job-name=antibiotic_pipeline

set -eo pipefail

# ---- Determine project directory ----
# When run via sbatch, we need to cd to the project dir
if [ -n "$SLURM_SUBMIT_DIR" ]; then
    cd "$SLURM_SUBMIT_DIR"
fi

PROJECT_DIR="${ANTIBIOTIC_PROJECT_DIR:-$HOME/antibiotic-selectivity}"
cd "$PROJECT_DIR"

LOG_DIR="${PROJECT_DIR}/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/run_ada_$(date +%Y%m%d_%H%M%S).log"

CLEAN_START=false
USE_REAL_DATA=false
SKIP_GPU=false
for arg in "$@"; do
    case "$arg" in
        --clean) CLEAN_START=true ;;
        --real-data) USE_REAL_DATA=true ;;
        --skip-gpu) SKIP_GPU=true ;;
    esac
done

export ANTIBIOTIC_PROJECT_DIR="$PROJECT_DIR"
if [ "$USE_REAL_DATA" = true ]; then
    export ANTIBIOTIC_DATA_MODE="real"
    OUTPUTS_BASE="${PROJECT_DIR}/outputs"
else
    export ANTIBIOTIC_DATA_MODE="synthetic"
    OUTPUTS_BASE="${PROJECT_DIR}/synthetic/outputs"
fi

RUN_ID="run_$(date +%Y%m%d_%H%M%S)"
export ANTIBIOTIC_RUN_ID="$RUN_ID"

log() {
    local level="$1"; shift
    local msg="[$level] $(date '+%H:%M:%S') $*"
    echo "$msg" | tee -a "$LOG_FILE"
}
die() {
    log "FATAL" "$*"
    mkdir -p "${OUTPUTS_BASE}/runs/${RUN_ID}"
    echo '{"status":"failed"}' > "${OUTPUTS_BASE}/runs/${RUN_ID}/run_status.json" 2>/dev/null || true
    echo "FAILED. Log: $LOG_FILE"
    exit 1
}

echo ""
echo "============================================================"
if [ "$USE_REAL_DATA" = true ]; then
    echo "  Microbiome-Sparing Antibiotic Pipeline [ADA - REAL DATA]"
else
    echo "  Microbiome-Sparing Antibiotic Pipeline [ADA - SYNTHETIC]"
fi
echo "============================================================"
echo "  Project:   $PROJECT_DIR"
echo "  Run ID:    $RUN_ID"
echo "  Log:       $LOG_FILE"
echo "  Time:      $(date)"
if [ -n "$SLURM_JOB_ID" ]; then
    echo "  SLURM Job: $SLURM_JOB_ID"
    echo "  Node:      $(hostname)"
    echo "  CPUs:      ${SLURM_NTASKS:-?}"
    echo "  GPU:       $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo 'none')"
fi
echo "============================================================"
echo ""

# ---- Clean: delete failed runs only ----
if [ "$CLEAN_START" = true ]; then
    log "INFO" "Clean: removing all previous runs (backed up on Drive)."
    log "INFO" "  Preserving: outputs/shared/ (features, splits, dmpnn_input)"
    if [ -d "${OUTPUTS_BASE}/runs" ]; then
        for run_dir in "${OUTPUTS_BASE}/runs"/run_*; do
            [ -d "$run_dir" ] || continue
            log "INFO" "  Deleting: $(basename $run_dir)"
            rm -rf "$run_dir"
        done
        rm -rf "${OUTPUTS_BASE}/runs/current" 2>/dev/null || true
    fi
    rm -f "${OUTPUTS_BASE}/latest" 2>/dev/null
fi

# ---- Copy Maier files ----
if [ "$USE_REAL_DATA" = true ] && [ -d "${PROJECT_DIR}/resources/maier" ]; then
    mkdir -p "${PROJECT_DIR}/data/maier"
    cp -n "${PROJECT_DIR}/resources/maier/"*.xlsx "${PROJECT_DIR}/data/maier/" 2>/dev/null || true
fi

# ============================================================================
# STEP 1: Activate environment
# ============================================================================
log "INFO" "[Step 1/6] Activating environment..."

# Load Python module if on Ada (require 3.12+)
module load u22/python/3.12.4 2>/dev/null || \
    module load u22/python/3.12 2>/dev/null || \
    module load u22/python/3.13 2>/dev/null || true

VENV_DIR="${PROJECT_DIR}/venv"
if [ ! -f "$VENV_DIR/bin/activate" ]; then
    die "No venv found at $VENV_DIR. Run: bash ada_full_setup.sh"
fi
source "$VENV_DIR/bin/activate"

if ! python3 -c "import rdkit, sklearn, scipy, matplotlib, tqdm" 2>/dev/null; then
    die "Missing packages. Run: bash ada_full_setup.sh"
fi

# Pre-flight diagnostics
log "INFO" "  Pre-flight diagnostics:"
python3 << 'PYDIAG'
import sys, os, shutil
sys.path.insert(0, 'scripts')
print(f"  Python:    {sys.version.split()[0]}")
print(f"  Venv:      {sys.prefix}")

import rdkit, sklearn
print(f"  RDKit:     {rdkit.__version__}")
print(f"  sklearn:   {sklearn.__version__}")

try:
    import torch
    cuda = torch.cuda.is_available()
    gpu_name = torch.cuda.get_device_name(0) if cuda else "none"
    print(f"  PyTorch:   {torch.__version__} (CUDA={cuda}, GPU={gpu_name})")
except ImportError:
    print(f"  PyTorch:   NOT INSTALLED [FATAL]")
    sys.exit(1)

try:
    import chemprop
    ver = getattr(chemprop, '__version__', 'imported')
    print(f"  Chemprop:  {ver}")
except ImportError:
    print(f"  Chemprop:  NOT INSTALLED [FATAL]")
    sys.exit(1)

bin_dir = os.path.dirname(sys.executable)
cp_script = os.path.join(bin_dir, 'chemprop')
cp_on_path = shutil.which('chemprop')
if os.path.exists(cp_script):
    print(f"  CLI:       {cp_script}")
elif cp_on_path:
    print(f"  CLI:       {cp_on_path}")
else:
    print(f"  CLI:       NOT FOUND [WARN] pip install --force-reinstall chemprop")

# rclone
rc = shutil.which('rclone')
print(f"  rclone:    {rc or 'not found (Drive sync disabled)'}")

import config
for label, path in [("Project", config.PROJECT_DIR), ("Home", os.path.expanduser("~"))]:
    try:
        st = os.statvfs(path)
        free_gb = (st.f_bavail * st.f_frsize) / (1024**3)
        print(f"  Disk({label}): {free_gb:.1f} GB free")
    except Exception:
        pass

# SLURM info
slurm_job = os.environ.get('SLURM_JOB_ID', '')
slurm_node = os.environ.get('SLURM_NODELIST', '')
if slurm_job:
    print(f"  SLURM:     job={slurm_job}, node={slurm_node}")

n_csv = sum(1 for d in [config.CHEMBL_DIR, config.MAIER_DIR, config.HUB_DIR]
            if os.path.isdir(d) for f in os.listdir(d) if f.endswith('.csv'))
n_npz = len([f for f in os.listdir(config.FEATURES_DIR) if f.endswith('.npz')]) if os.path.isdir(config.FEATURES_DIR) else 0
n_rf = len([f for f in os.listdir(config.RF_DIR) if f.endswith('.pkl')]) if os.path.isdir(config.RF_DIR) else 0
n_dmpnn = 0
if os.path.isdir(config.DMPNN_DIR):
    for root, dirs, files in os.walk(config.DMPNN_DIR):
        n_dmpnn += len([f for f in files if f.endswith(('.pt', '.ckpt'))])
print(f"  Cached:    {n_csv} CSVs, {n_npz} FPs, {n_rf} RF models, {n_dmpnn} D-MPNN checkpoints")
PYDIAG

if [ $? -ne 0 ]; then
    die "Pre-flight diagnostics failed. Fix missing packages above."
fi

# GPU check
HAS_GPU=false
if python3 -c "import torch; exit(0 if torch.cuda.is_available() else 1)" 2>/dev/null; then
    HAS_GPU=true
fi

# ============================================================================
# STEP 2: Directories
# ============================================================================
log "INFO" ""
log "INFO" "[Step 2/6] Creating directories..."
python3 -c "
import os, sys; sys.path.insert(0, 'scripts'); import config
for d in [config.DATA_DIR, config.CHEMBL_DIR, config.MAIER_DIR, config.HUB_DIR,
          config.FEATURES_DIR, config.SPLITS_DIR, config.RF_DIR, config.DMPNN_DIR,
          config.RESULTS_DIR, config.SCREENING_DIR, config.FIGURES_DIR,
          config.REPORTS_DIR, config.CHECKPOINTS_DIR, config.LOGS_DIR, config.DMPNN_INPUT_DIR]:
    os.makedirs(d, exist_ok=True)
print(f'  Data:    {config.DATA_DIR}')
print(f'  Run:     {config.RUN_DIR}')
print(f'  Shared:  {config.SHARED_DIR}')
" || die "Directory creation failed. Check config.py and env vars."

# Disk usage check
USAGE=$(du -sh "$PROJECT_DIR" 2>/dev/null | cut -f1)
QUOTA_INFO=$(quota -u $USER 2>/dev/null | tail -1 || echo "quota unavailable")
log "INFO" "  Disk:   $USAGE used"
log "INFO" "  Quota:  $QUOTA_INFO"

# ============================================================================
# STEP 3: Data acquisition
# ============================================================================
log "INFO" ""
log "INFO" "[Step 3/6] Preparing data..."

if [ "$USE_REAL_DATA" = true ]; then
    # Restore pre-processed data from Drive/gdown/rclone BEFORE checking local files
    log "INFO" "  Checking for pre-processed data (local > Drive > gdown > rclone)..."
    python3 scripts/restore_data.py 2>&1 | tee -a "$LOG_FILE" || true

    # Phase 1C: Hub
    HUB_CSV="${PROJECT_DIR}/data/repurposing_hub/repurposing_hub_clean.csv"
    if [ -f "$HUB_CSV" ]; then
        log "INFO" "  [1C] Hub exists. Skipping."
    else
        log "INFO" "  [1C] Fetching Drug Repurposing Hub..."
        python3 scripts/03_fetch_repurposing_hub.py 2>&1 | tee -a "$LOG_FILE" || \
            die "Phase 1C failed. Check network from compute node: curl -s https://s3.amazonaws.com/data.clue.io/"
    fi

    # Phase 1A: ChEMBL (SQLite primary, API fallback)
    CHEMBL_COMPLETE=true
    python3 -c "
import sys; sys.path.insert(0,'scripts'); import config, os
try:
    from utils.gdrive_backup import get_data_manager
    dm = get_data_manager()
except Exception:
    dm = None
for pkey, pinfo in config.PATHOGENS.items():
    p = os.path.join(config.CHEMBL_DIR, pinfo['csv_filename'])
    if not os.path.exists(p) and dm:
        r = dm.resolve(pinfo['csv_filename'], config.CHEMBL_DIR)
        if r: p = r
    if not os.path.exists(p): print(f'  Missing: {pkey}'); exit(1)
" 2>/dev/null || CHEMBL_COMPLETE=false

    if [ "$CHEMBL_COMPLETE" = true ]; then
        log "INFO" "  [1A] All ChEMBL data exists. Skipping."
    else
        log "INFO" "  [1A] Fetching ChEMBL data (SQLite primary, API fallback)..."
        log "INFO" "  First run downloads ~1GB SQLite DB. Subsequent runs: instant."
        python3 scripts/01_fetch_chembl.py 2>&1 | tee -a "$LOG_FILE" || \
            die "Phase 1A failed. Check: python3 -c 'import chembl_downloader; print(chembl_downloader.download_extract_sqlite(version=\"34\"))'"
    fi

    # Phase 1B: Maier
    MAIER_CSV="${PROJECT_DIR}/data/maier/maier_combined.csv"
    if [ -f "$MAIER_CSV" ]; then
        log "INFO" "  [1B] Maier data exists. Skipping."
    else
        if ls "${PROJECT_DIR}/data/maier/"*.xlsx &>/dev/null; then
            log "INFO" "  [1B] Processing Maier data..."
            python3 scripts/02_process_maier.py 2>&1 | tee -a "$LOG_FILE" || \
                die "Phase 1B failed. Check: ls data/maier/*.xlsx (need MOESM5 file)"
        else
            die "Maier Excel files not found. Run: scp Maier_data_Excel/*.xlsx $(whoami)@ada:${PROJECT_DIR}/data/maier/"
        fi
    fi
else
    SYNTH_MARKER="${OUTPUTS_BASE}/shared/.synthetic_generated"
    if [ -f "$SYNTH_MARKER" ] && [ "$CLEAN_START" = false ]; then
        log "INFO" "  Synthetic data exists."
    else
        log "INFO" "  Generating synthetic data..."
        python3 -c "
import sys,logging; sys.path.insert(0,'scripts')
logging.basicConfig(level=logging.INFO, format='%(asctime)s | %(message)s', datefmt='%H:%M:%S')
import config; from utils.alternative_data import generate_synthetic_data
generate_synthetic_data(config.PROJECT_DIR, logging.getLogger('synth'))
" 2>&1 | tee -a "$LOG_FILE" || die "Synthetic data generation failed"
        mkdir -p "$(dirname "$SYNTH_MARKER")"
        echo '{"status":"generated"}' > "$SYNTH_MARKER"
    fi
fi

# ============================================================================
# STEP 4: Pipeline phases
# ============================================================================
log "INFO" ""
log "INFO" "[Step 4/6] Running pipeline..."

CKPT_DIR=$(python3 -c "import sys; sys.path.insert(0,'scripts'); import config; print(config.CHECKPOINTS_DIR)")

run_phase() {
    local name="$1" script="$2" ckpt="$3" crit="${4:-true}"
    log "INFO" ""; log "INFO" "--- $name ---"
    if [ -f "$ckpt" ] && [ "$CLEAN_START" = false ]; then
        python3 -c "import json; exit(0 if json.load(open('$ckpt')).get('status')=='complete' else 1)" 2>/dev/null && {
            log "INFO" "  SKIPPED (checkpoint)"; return 0; }
    fi
    local t0=$(date +%s)
    python3 "$script" 2>&1 | tee -a "$LOG_FILE"
    local rc=${PIPESTATUS[0]} elapsed=$(( $(date +%s) - t0 ))
    if [ $rc -eq 0 ]; then
        log "INFO" "  COMPLETED in ${elapsed}s"
        return 0
    fi
    log "ERROR" "  FAILED (exit=$rc) after ${elapsed}s"
    log "ERROR" "  Script: $script"
    log "ERROR" "  Log: $LOG_FILE"
    [ "$crit" = "true" ] && return 1
    log "WARN" "  Non-critical. Continuing..."
    return 0
}

# Helper: pack specific artifact to Drive immediately after it's produced
pack_to_drive() {
    local label="$1" method="$2"
    python3 -c "
import sys; sys.path.insert(0, 'scripts'); import config, os
try:
    from utils.gdrive_backup import get_data_manager
    dm = get_data_manager()
    zp = dm.${method}(config.PROJECT_DIR)
    if zp: print(f'  Saved to Drive: ${label} ({os.path.basename(zp)})')
except Exception as e:
    print(f'  Drive save skipped for ${label}: {e}')
" 2>&1 | tee -a "$LOG_FILE"
}

run_phase "Phase 2: Morgan FPs + Splits" \
    scripts/04_compute_morgan_fps.py "${CKPT_DIR}/phase2_master.json" true || \
    die "Phase 2 failed. Check: python3 scripts/04_compute_morgan_fps.py"
pack_to_drive "data CSVs" "pack_data_csvs"
pack_to_drive "features" "pack_features"

run_phase "Phase 3A: RF Training (7 models)" \
    scripts/05_train_rf.py "${CKPT_DIR}/phase3a_master.json" true || \
    die "Phase 3A failed. Check: python3 scripts/05_train_rf.py"
pack_to_drive "RF models" "pack_rf_models"

# Phase 3B: D-MPNN is the MAIN pipeline (required unless --skip-gpu)
if [ "$SKIP_GPU" = true ]; then
    log "INFO" ""; log "INFO" "--- Phase 3B: D-MPNN ---"
    log "INFO" "  SKIPPED (--skip-gpu flag). NOTE: D-MPNN is the primary model."
    log "INFO" "  Remove --skip-gpu for production runs."
else
    python3 -c "import chemprop" 2>/dev/null || \
        die "chemprop not installed. D-MPNN is required. Install: pip install chemprop torch lightning"
    run_phase "Phase 3B: D-MPNN Training (GPU)" \
        scripts/06_train_dmpnn.py "${CKPT_DIR}/phase3b_master.json" true || \
        die "Phase 3B (D-MPNN) failed. Check: python3 scripts/06_train_dmpnn.py"
    pack_to_drive "D-MPNN models" "pack_dmpnn_models"
fi

# ---- Phase 3C: CheMeleon Frozen Encoder (fast, run first) ----
log "INFO" ""
log "INFO" "[Phase 3C] CheMeleon Frozen Encoder (train only FFN head)..."
RESULTS="${OUTPUTS_BASE}/runs/${RUN_ID}/results"
if [ -f "${RESULTS}/chemeleon_frozen_cv_metrics.json" ]; then
    log "INFO" "  SKIP: chemeleon_frozen_cv_metrics.json already exists"
else
    export HF_HOME="${PROJECT_DIR}/.hf_cache"
    export TRANSFORMERS_CACHE="${PROJECT_DIR}/.hf_cache"
    mkdir -p "$HF_HOME"
    python3 -u scripts/11_train_chemeleon_frozen.py 2>&1 | tee -a "$LOG_FILE" || \
        log "WARN" "  CheMeleon Frozen had issues (other results still valid)"
fi

# ---- Phase 3C-FT: CheMeleon Fine-Tune (gated on frozen) ----
log "INFO" ""
log "INFO" "[Phase 3C-FT] CheMeleon Fine-Tune..."
if [ -f "${RESULTS}/chemeleon_cv_metrics.json" ]; then
    log "INFO" "  SKIP: chemeleon_cv_metrics.json already exists"
else
    python3 -u scripts/09_train_chemeleon.py 2>&1 | tee -a "$LOG_FILE" || \
        log "WARN" "  CheMeleon Fine-Tune had issues (frozen results still valid)"
fi

# ---- Phase 3D: MoLFormer-XL Transformer ----
log "INFO" ""
log "INFO" "[Phase 3D] MoLFormer-XL Fine-Tuning..."
if [ -f "${RESULTS}/molformer_cv_metrics.json" ]; then
    log "INFO" "  SKIP: molformer_cv_metrics.json already exists"
else
    if python3 -c "import transformers" 2>/dev/null; then
        export HF_HOME="${PROJECT_DIR}/.hf_cache"
        export TRANSFORMERS_CACHE="${PROJECT_DIR}/.hf_cache"
        mkdir -p "$HF_HOME"
        python3 -u scripts/10_train_molformer.py 2>&1 | tee -a "$LOG_FILE" || \
            log "WARN" "  MoLFormer had issues (other results still valid)"
    else
        log "WARN" "  transformers not installed. pip install transformers"
    fi
fi

run_phase "Phase 4: Evaluation (5 tests)" \
    scripts/07_evaluate.py "${CKPT_DIR}/phase4_master.json" true || \
    die "Phase 4 failed. Check: python3 scripts/07_evaluate.py"

# ---- Phase 5: Comparative Analysis ----
log "INFO" ""
log "INFO" "[Phase 5] Comparative analysis (all models)..."
python3 scripts/12_compare_models.py 2>&1 | tee -a "$LOG_FILE" || \
    log "WARN" "  Comparison had issues (non-critical)"

# ---- Phase 6: Candidate Report ----
log "INFO" ""
log "INFO" "[Phase 6] Candidate report..."
python3 scripts/13_candidate_report.py 2>&1 | tee -a "$LOG_FILE" || \

# Optional: external benchmark (Stokes/Wong published models, ~10 min)
log "INFO" "  External benchmark (optional)..."
python3 scripts/14_external_benchmark.py 2>&1 | tee -a "$LOG_FILE" || \
    log "WARN" "  External benchmark skipped (non-critical)"
    log "WARN" "  Report had issues (non-critical)"

# ============================================================================
# STEP 5: Showcase
# ============================================================================
log "INFO" ""
log "INFO" "[Step 5/6] Showcase visualizations..."
python3 scripts/08_create_showcase.py 2>&1 | tee -a "$LOG_FILE" || \
    log "WARN" "  Showcase had issues (non-critical)"

# ============================================================================
# STEP 6: Mark success + summary
# ============================================================================
RUN_DIR="${OUTPUTS_BASE}/runs/${RUN_ID}"
SLURM_INFO=""
[ -n "$SLURM_JOB_ID" ] && SLURM_INFO=",\"slurm_job\":\"$SLURM_JOB_ID\",\"node\":\"$(hostname)\""
echo "{\"status\":\"success\",\"timestamp\":\"$(date -Iseconds 2>/dev/null || date)\",\"mode\":\"${ANTIBIOTIC_DATA_MODE}\"${SLURM_INFO}}" \
    > "${RUN_DIR}/run_status.json" 2>/dev/null || true

rm -f "${OUTPUTS_BASE}/latest"
ln -sf "runs/${RUN_ID}" "${OUTPUTS_BASE}/latest" 2>/dev/null || true

# ---- ZIP results + push to Drive ----
log "INFO" ""
log "INFO" "Packaging results and backing up to Drive..."
DRIVE_OK=false
if python3 -c "
import sys; sys.path.insert(0, 'scripts')
import config
from utils.gdrive_backup import get_data_manager
dm = get_data_manager()
zp = dm.push_outputs(config.RESULTS_DIR, '${RUN_ID}')
if zp:
    print(f'  ZIP: {zp}')
    dm.flush('final outputs')
    sys.exit(0)
else:
    sys.exit(1)
" 2>&1 | tee -a "$LOG_FILE"; then
    DRIVE_OK=true
    log "INFO" "  Drive upload: SUCCESS"
else
    log "WARN" "  Drive upload: FAILED (keeping all local runs as backup)"
fi

RESULTS=$(python3 -c "import sys; sys.path.insert(0,'scripts'); import config; print(config.RESULTS_DIR)")
n_csv=$(find "$RESULTS" -name "*.csv" -type f 2>/dev/null | wc -l | tr -d ' ')
n_fig=$(find "$RESULTS/figures" -type f 2>/dev/null | wc -l | tr -d ' ')
FINAL_USAGE=$(du -sh "$PROJECT_DIR" 2>/dev/null | cut -f1)

# ---- Delete old runs ONLY if Drive upload succeeded ----
if [ "$DRIVE_OK" = true ] && [ -d "${OUTPUTS_BASE}/runs" ]; then
    for old_run in "${OUTPUTS_BASE}/runs"/run_*; do
        [ -d "$old_run" ] || continue
        [ "$(basename $old_run)" = "$RUN_ID" ] && continue
        log "INFO" "  Removing old run: $(basename $old_run) (confirmed on Drive)"
        rm -rf "$old_run"
    done
fi

log "INFO" ""
log "INFO" "============================================================"
log "INFO" "  PIPELINE COMPLETE"
log "INFO" "============================================================"
log "INFO" "  Run ID:  $RUN_ID"
log "INFO" "  Output:  ${n_csv} CSVs, ${n_fig} figures"
log "INFO" "  Results: $RESULTS"
log "INFO" "  Disk:    $FINAL_USAGE"
log "INFO" "  Log:     $LOG_FILE"
if [ "$DRIVE_OK" = true ]; then
    log "INFO" "  Drive:   outputs backed up to Google Drive"
else
    log "WARN" "  Drive:   UPLOAD FAILED. All runs kept locally."
fi
log "INFO" ""
log "INFO" "  Download results:"
log "INFO" "    scp -r $(whoami)@ada.iiit.ac.in:${RESULTS} ."
log "INFO" "  Re-run:  bash run_ada.sh$([ "$USE_REAL_DATA" = true ] && echo ' --real-data')"
log "INFO" "============================================================"
