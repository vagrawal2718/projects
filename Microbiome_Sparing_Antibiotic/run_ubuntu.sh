#!/bin/bash
# ============================================================================
# run_ubuntu.sh -- Pipeline run on Ubuntu 24.04 / Debian / WSL
#
# Usage:
#   bash run_ubuntu.sh                         # Synthetic data (no network)
#   bash run_ubuntu.sh --real-data             # Real data from APIs
#   bash run_ubuntu.sh --clean                 # Delete failed runs, re-run
#   bash run_ubuntu.sh --clean --real-data     # Clean + real data
#
# First run auto-invokes setup_ubuntu.sh if venv is missing.
# Successful runs are NEVER deleted. --clean only removes failed/incomplete.
# ============================================================================
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

VENV_DIR="${ROOT_DIR}/venv"
LOG_DIR="${ROOT_DIR}/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/run_ubuntu_$(date +%Y%m%d_%H%M%S).log"

CLEAN_START=false
USE_REAL_DATA=false
for arg in "$@"; do
    case "$arg" in
        --clean) CLEAN_START=true ;;
        --real-data) USE_REAL_DATA=true ;;
    esac
done

export ANTIBIOTIC_PROJECT_DIR="$ROOT_DIR"
if [ "$USE_REAL_DATA" = true ]; then
    export ANTIBIOTIC_DATA_MODE="real"
    OUTPUTS_BASE="${ROOT_DIR}/outputs"
else
    export ANTIBIOTIC_DATA_MODE="synthetic"
    OUTPUTS_BASE="${ROOT_DIR}/synthetic/outputs"
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
    echo "  Microbiome-Sparing Antibiotic Pipeline [REAL DATA]"
else
    echo "  Microbiome-Sparing Antibiotic Pipeline [SYNTHETIC]"
fi
echo "============================================================"
echo "  Directory: $ROOT_DIR"
echo "  Run ID:    $RUN_ID"
echo "  Log:       $LOG_FILE"
echo "  Time:      $(date)"
echo "============================================================"
echo ""

# ---- Clean: delete ALL previous runs (outputs are on Drive) ----
# NOTE: outputs/shared/ (features, splits) is PRESERVED across runs.
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
if [ "$USE_REAL_DATA" = true ] && [ -d "${ROOT_DIR}/resources/maier" ]; then
    mkdir -p "${ROOT_DIR}/data/maier"
    cp -n "${ROOT_DIR}/resources/maier/"*.xlsx "${ROOT_DIR}/data/maier/" 2>/dev/null || true
fi

# ============================================================================
# STEP 1: Check setup (auto-run if missing)
# ============================================================================
log "INFO" "[Step 1/6] Checking setup..."

if [ ! -f "$VENV_DIR/bin/activate" ]; then
    log "INFO" "  No venv found. Running setup..."
    if [ -f "${ROOT_DIR}/setup_ubuntu.sh" ]; then
        bash "${ROOT_DIR}/setup_ubuntu.sh"
    else
        die "No venv and no setup_ubuntu.sh. Run: python3 -m venv venv && source venv/bin/activate && pip install rdkit scikit-learn matplotlib seaborn tqdm chembl-downloader"
    fi
fi
source "$VENV_DIR/bin/activate"

if ! python3 -c "import rdkit, sklearn, scipy, matplotlib, tqdm" 2>/dev/null; then
    log "WARN" "  Missing packages. Running setup..."
    [ -f "${ROOT_DIR}/setup_ubuntu.sh" ] && bash "${ROOT_DIR}/setup_ubuntu.sh"
    source "$VENV_DIR/bin/activate"
fi

# Pre-flight diagnostics
log "INFO" "  Pre-flight diagnostics:"
python3 << 'PYDIAG'
import sys, os, shutil
sys.path.insert(0, 'scripts')
print(f"  Python:    {sys.version.split()[0]}")
print(f"  Venv:      {sys.prefix}")

# Core packages
import rdkit, sklearn, scipy
print(f"  RDKit:     {rdkit.__version__}")
print(f"  sklearn:   {sklearn.__version__}")

# D-MPNN packages (REQUIRED)
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

# Chemprop CLI entry point
bin_dir = os.path.dirname(sys.executable)
cp_script = os.path.join(bin_dir, 'chemprop')
cp_on_path = shutil.which('chemprop')
if os.path.exists(cp_script):
    print(f"  CLI:       {cp_script}")
elif cp_on_path:
    print(f"  CLI:       {cp_on_path}")
else:
    print(f"  CLI:       NOT FOUND [WARN] Reinstall: pip install --force-reinstall chemprop")

# Disk space
import config
for label, path in [("Project", config.PROJECT_DIR), ("Home", os.path.expanduser("~"))]:
    try:
        st = os.statvfs(path)
        free_gb = (st.f_bavail * st.f_frsize) / (1024**3)
        print(f"  Disk({label}): {free_gb:.1f} GB free")
    except Exception:
        pass

# Cached artifacts
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
print(f'  Outputs: {config.RUN_DIR}')
" || die "Directory creation failed. Check config.py and env vars."

# ============================================================================
# STEP 3: Data acquisition
# ============================================================================
log "INFO" ""
log "INFO" "[Step 3/6] Preparing data..."

if [ "$USE_REAL_DATA" = true ]; then
    # Restore pre-processed data from Drive/gdown BEFORE checking local files
    log "INFO" "  Checking for pre-processed data (local > Drive > gdown)..."
    python3 scripts/restore_data.py 2>&1 | tee -a "$LOG_FILE" || true

    HUB_CSV="${ROOT_DIR}/data/repurposing_hub/repurposing_hub_clean.csv"
    if [ -f "$HUB_CSV" ]; then
        log "INFO" "  [1C] Hub exists. Skipping."
    else
        log "INFO" "  [1C] Fetching Drug Repurposing Hub..."
        python3 scripts/03_fetch_repurposing_hub.py 2>&1 | tee -a "$LOG_FILE" || die "Phase 1C failed. Check network: curl -s https://s3.amazonaws.com/data.clue.io/"
    fi

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
        python3 scripts/01_fetch_chembl.py 2>&1 | tee -a "$LOG_FILE" || die "Phase 1A failed. Check: pip install chembl-downloader && python -c 'import chembl_downloader'"
    fi

    MAIER_CSV="${ROOT_DIR}/data/maier/maier_combined.csv"
    if [ -f "$MAIER_CSV" ]; then
        log "INFO" "  [1B] Maier data exists. Skipping."
    else
        if ls "${ROOT_DIR}/data/maier/"*.xlsx &>/dev/null; then
            log "INFO" "  [1B] Processing Maier data..."
            python3 scripts/02_process_maier.py 2>&1 | tee -a "$LOG_FILE" || die "Phase 1B failed. Check Maier Excel files in data/maier/"
        else
            die "Maier Excel files not found. Ensure resources/maier/*.xlsx exists and run setup."
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
    log "ERROR" "  Check log above and: $LOG_FILE"
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

run_phase "Phase 2: Morgan FPs + Splits" scripts/04_compute_morgan_fps.py "${CKPT_DIR}/phase2_master.json" true || die "Phase 2 failed"
pack_to_drive "data CSVs" "pack_data_csvs"
pack_to_drive "features" "pack_features"

run_phase "Phase 3A: RF Training" scripts/05_train_rf.py "${CKPT_DIR}/phase3a_master.json" true || die "Phase 3A failed"
pack_to_drive "RF models" "pack_rf_models"

# Phase 3B: D-MPNN is the MAIN pipeline (required)
python3 -c "import chemprop" 2>/dev/null || die "chemprop not installed. Install: pip install chemprop torch lightning"
run_phase "Phase 3B: D-MPNN Training" scripts/06_train_dmpnn.py "${CKPT_DIR}/phase3b_master.json" true || die "Phase 3B (D-MPNN) failed"
pack_to_drive "D-MPNN models" "pack_dmpnn_models"

# ---- Phase 3C: CheMeleon Frozen Encoder (fast, run first) ----
log "INFO" ""
log "INFO" "[Phase 3C] CheMeleon Frozen Encoder (train only FFN head)..."
RESULTS="${OUTPUTS_BASE}/runs/${RUN_ID}/results"
if [ -f "${RESULTS}/chemeleon_frozen_cv_metrics.json" ]; then
    log "INFO" "  SKIP: chemeleon_frozen_cv_metrics.json already exists"
else
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
        python3 -u scripts/10_train_molformer.py 2>&1 | tee -a "$LOG_FILE" || \
            log "WARN" "  MoLFormer had issues (other results still valid)"
    else
        log "WARN" "  transformers not installed. pip install transformers"
    fi
fi

run_phase "Phase 4: Evaluation" scripts/07_evaluate.py "${CKPT_DIR}/phase4_master.json" true || die "Phase 4 failed"

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
python3 scripts/08_create_showcase.py 2>&1 | tee -a "$LOG_FILE" || log "WARN" "  Showcase had issues (non-critical)"

# ============================================================================
# STEP 6: Mark success + summary
# ============================================================================
RUN_DIR="${OUTPUTS_BASE}/runs/${RUN_ID}"
echo "{\"status\":\"success\",\"timestamp\":\"$(date -Iseconds 2>/dev/null || date)\",\"mode\":\"${ANTIBIOTIC_DATA_MODE}\"}" \
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
    print('  Drive push returned None')
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
log "INFO" "  Log:     $LOG_FILE"
if [ "$DRIVE_OK" = true ]; then
    log "INFO" "  Drive:   outputs backed up to Google Drive"
else
    log "WARN" "  Drive:   UPLOAD FAILED. All runs kept locally."
fi
log "INFO" "============================================================"
