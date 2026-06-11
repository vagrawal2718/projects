#!/bin/bash
# ============================================================================
# run_mac.sh -- Complete local pipeline run on Mac (or Linux/WSL)
#
# Usage:
#   bash run_mac.sh                    # Synthetic data test (no network)
#   bash run_mac.sh --real-data        # Real data from APIs (needs network)
#   bash run_mac.sh --clean            # Reset outputs, keep ALL data
#   bash run_mac.sh --clean --real-data
#
# Directory layout:
#   data/                  Downloaded real data (NEVER deleted)
#   synthetic/data/        Synthetic test data (NEVER deleted)
#   resources/maier/       Bundled Excel files (NEVER deleted)
#   logs/                  All logs (NEVER deleted)
#   outputs/               Derived outputs (deleted by --clean)
#     features/  splits/  models/  results/  checkpoints/  dmpnn_input/
#
# ============================================================================
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

VENV_DIR="${ROOT_DIR}/venv"
LOG_DIR="${ROOT_DIR}/logs"
LOG_FILE="${LOG_DIR}/run_mac_$(date +%Y%m%d_%H%M%S).log"

CLEAN_START=false
USE_REAL_DATA=false
for arg in "$@"; do
    case "$arg" in
        --clean) CLEAN_START=true ;;
        --real-data) USE_REAL_DATA=true ;;
    esac
done

# PROJECT_DIR is always the root. Data mode controls where data/ lives.
export ANTIBIOTIC_PROJECT_DIR="$ROOT_DIR"
if [ "$USE_REAL_DATA" = true ]; then
    export ANTIBIOTIC_DATA_MODE="real"
    OUTPUTS_BASE="${ROOT_DIR}/outputs"
else
    export ANTIBIOTIC_DATA_MODE="synthetic"
    OUTPUTS_BASE="${ROOT_DIR}/synthetic/outputs"
fi

# Generate timestamped run ID
RUN_ID="run_$(date +%Y%m%d_%H%M%S)"
export ANTIBIOTIC_RUN_ID="$RUN_ID"

mkdir -p "$LOG_DIR"

log() {
    local level="$1"; shift
    local msg="[$level] $(date '+%H:%M:%S') $*"
    echo "$msg" | tee -a "$LOG_FILE"
}

die() {
    log "FATAL" "$*"
    # Mark this run as failed
    mkdir -p "${OUTPUTS_BASE}/runs/${RUN_ID}"
    echo '{"status":"failed"}' > "${OUTPUTS_BASE}/runs/${RUN_ID}/run_status.json"
    echo "FAILED. Full log: $LOG_FILE"
    exit 1
}

# ---- Banner ----
echo ""
echo "============================================================"
echo "  Microbiome-Sparing Antibiotic Discovery Pipeline"
if [ "$USE_REAL_DATA" = true ]; then
    echo "  REAL DATA MODE (network required)"
    echo "  Data: data/ (protected, never deleted)"
else
    echo "  SYNTHETIC DATA MODE (no network needed)"
    echo "  Data: synthetic/data/ (separate from real data)"
fi
echo "============================================================"
echo "  Directory: $ROOT_DIR"
echo "  Run ID:    $RUN_ID"
echo "  Log:       $LOG_FILE"
echo "  Time:      $(date)"
echo "============================================================"
echo ""

# ---- Clean start ----
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

# ---- Copy bundled Maier Excel files to data/maier/ ----
if [ "$USE_REAL_DATA" = true ] && [ -d "${ROOT_DIR}/resources/maier" ]; then
    mkdir -p "${ROOT_DIR}/data/maier"
    cp -n "${ROOT_DIR}/resources/maier/"*.xlsx "${ROOT_DIR}/data/maier/" 2>/dev/null || true
    n_maier=$(ls "${ROOT_DIR}/data/maier/"*.xlsx 2>/dev/null | wc -l | tr -d ' ')
    log "INFO" "Maier Excel files: $n_maier in data/maier/"
fi

# ============================================================================
# STEP 1: Check setup (venv + packages)
# ============================================================================
log "INFO" "[Step 1/6] Checking setup..."

VENV_DIR="${ROOT_DIR}/venv"

if [ ! -f "$VENV_DIR/bin/activate" ]; then
    log "INFO" "  No virtual environment found. Running setup first..."
    log "INFO" "  (This only happens once. Future runs will be fast.)"
    echo ""
    bash "${ROOT_DIR}/setup_mac.sh"
    echo ""
    log "INFO" "  Setup complete. Continuing with pipeline run..."
fi

source "$VENV_DIR/bin/activate"

# Quick sanity check that key packages are present
if ! python3 -c "import rdkit, sklearn, scipy, matplotlib, chembl_downloader" 2>/dev/null; then
    log "WARN" "  Some packages missing. Running setup..."
    bash "${ROOT_DIR}/setup_mac.sh"
    source "$VENV_DIR/bin/activate"
fi

log "INFO" "  Python: $(python3 --version 2>&1)"
python3 -c "import torch; exit(0 if torch.backends.mps.is_available() else 1)" 2>/dev/null \
    && log "INFO" "  Apple MPS GPU detected." \
    || log "INFO" "  No GPU detected."

# ============================================================================
# STEP 3: Create directories
# ============================================================================
log "INFO" ""
log "INFO" "[Step 3/6] Creating directories..."

python3 -c "
import os, sys; sys.path.insert(0, 'scripts'); import config
for d in [config.DATA_DIR, config.CHEMBL_DIR, config.MAIER_DIR, config.HUB_DIR,
          config.FEATURES_DIR, config.SPLITS_DIR, config.RF_DIR, config.DMPNN_DIR,
          config.RESULTS_DIR, config.SCREENING_DIR, config.FIGURES_DIR,
          config.REPORTS_DIR, config.CHECKPOINTS_DIR, config.LOGS_DIR,
          config.DMPNN_INPUT_DIR]:
    os.makedirs(d, exist_ok=True)
print(f'  Data:    {config.DATA_DIR}')
print(f'  Outputs: {config.OUTPUTS_DIR}')
print(f'  Logs:    {config.LOGS_DIR}')
" || die "Directory creation failed"

# ============================================================================
# STEP 4: Prepare data
# ============================================================================
log "INFO" ""
log "INFO" "[Step 4/6] Preparing data..."

if [ "$USE_REAL_DATA" = true ]; then
    # ---- REAL DATA MODE ----

    # Restore pre-processed data from Drive/gdown BEFORE checking local files
    log "INFO" "  Checking for pre-processed data (local > Drive > gdown)..."
    python3 scripts/restore_data.py 2>&1 | tee -a "$LOG_FILE" || true

    # Phase 1C: Drug Repurposing Hub
    HUB_CSV="${ROOT_DIR}/data/repurposing_hub/repurposing_hub_clean.csv"
    # Try restore from Drive/gdown if not local
    if [ ! -f "$HUB_CSV" ]; then
        python3 -c "
import sys; sys.path.insert(0, 'scripts'); import config
try:
    from utils.gdrive_backup import get_data_manager
    dm = get_data_manager()
    dm.resolve(config.HUB_CLEAN_FILENAME, config.HUB_DIR)
except Exception: pass
" 2>&1 | tee -a "$LOG_FILE"
    fi
    if [ -f "$HUB_CSV" ]; then
        n=$(python3 -c "import pandas; print(len(pandas.read_csv('$HUB_CSV')))" 2>/dev/null || echo "?")
        log "INFO" "  [1C] Hub data exists ($n compounds). Skipping."
    else
        log "INFO" "  [1C] Fetching Drug Repurposing Hub..."
        python3 scripts/03_fetch_repurposing_hub.py 2>&1 | tee -a "$LOG_FILE" || \
            die "Phase 1C failed. Check network: curl -s https://s3.amazonaws.com/data.clue.io/"
    fi

    # Phase 1A: ChEMBL (try Drive/gdown first, then SQLite/API)
    CHEMBL_COMPLETE=true
    python3 -c "
import sys; sys.path.insert(0, 'scripts'); import config, os, pandas as pd
# Try DataManager to restore from Drive/gdown before declaring missing
try:
    from utils.gdrive_backup import get_data_manager
    dm = get_data_manager()
except Exception:
    dm = None
for pkey, pinfo in config.PATHOGENS.items():
    p = os.path.join(config.CHEMBL_DIR, pinfo['csv_filename'])
    if not os.path.exists(p) and dm:
        restored = dm.resolve(pinfo['csv_filename'], config.CHEMBL_DIR)
        if restored:
            p = restored
    if not os.path.exists(p):
        print(f'  Missing: {pkey}'); exit(1)
    n = len(pd.read_csv(p))
    print(f'  {pkey}: {n} compounds')
" 2>&1 | tee -a "$LOG_FILE" || CHEMBL_COMPLETE=false

    if [ "$CHEMBL_COMPLETE" = true ]; then
        log "INFO" "  [1A] All ChEMBL data exists. Skipping."
    else
        log "INFO" ""
        log "INFO" "  [1A] Fetching ChEMBL pathogen data (SQLite primary, API fallback)..."
        python3 scripts/01_fetch_chembl.py 2>&1 | tee -a "$LOG_FILE" || \
            die "Phase 1A failed. Check: pip install chembl-downloader && python3 -c 'import chembl_downloader'"
    fi

    # Phase 1B: Maier
    MAIER_CSV="${ROOT_DIR}/data/maier/maier_combined.csv"
    # Try restore from Drive/gdown if not local
    if [ ! -f "$MAIER_CSV" ]; then
        python3 -c "
import sys; sys.path.insert(0, 'scripts'); import config
try:
    from utils.gdrive_backup import get_data_manager
    dm = get_data_manager()
    dm.resolve('maier_combined.csv', config.MAIER_DIR)
    dm.resolve('maier_smiles_lookup.csv', config.MAIER_DIR)
except Exception: pass
" 2>&1 | tee -a "$LOG_FILE"
    fi
    if [ -f "$MAIER_CSV" ]; then
        n=$(python3 -c "import pandas; print(len(pandas.read_csv('$MAIER_CSV')))" 2>/dev/null || echo "?")
        log "INFO" "  [1B] Maier data exists ($n compounds). Skipping."
    else
        MOESM5="${ROOT_DIR}/data/maier/41586_2018_BFnature25979_MOESM5_ESM.xlsx"
        if [ -f "$MOESM5" ]; then
            log "INFO" ""
            log "INFO" "  [1B] Processing Maier commensal data..."
            python3 scripts/02_process_maier.py 2>&1 | tee -a "$LOG_FILE" || \
                die "Phase 1B failed. Check: ls data/maier/*.xlsx (need 24 files)"
        else
            die "Maier MOESM5 Excel not found at: $MOESM5. Run setup_mac.sh first."
        fi
    fi

else
    # ---- SYNTHETIC DATA MODE ----
    SYNTH_MARKER="${OUTPUTS_BASE}/shared/.synthetic_generated"

    if [ -f "$SYNTH_MARKER" ] && [ "$CLEAN_START" = false ]; then
        log "INFO" "  Synthetic data from previous run found."
    else
        log "INFO" "  Generating synthetic test data..."
        python3 -c "
import sys, logging; sys.path.insert(0, 'scripts')
logging.basicConfig(level=logging.INFO, format='%(asctime)s | %(message)s', datefmt='%H:%M:%S')
import config; from utils.alternative_data import generate_synthetic_data
generate_synthetic_data(config.PROJECT_DIR, logging.getLogger('synth'))
" 2>&1 | tee -a "$LOG_FILE" || die "Synthetic data generation failed. Check: python3 -c 'from rdkit import Chem; print(Chem.MolFromSmiles(\"CCO\"))'"
        mkdir -p "$(dirname "$SYNTH_MARKER")"
        echo '{"status":"generated"}' > "$SYNTH_MARKER"
        log "INFO" "  Synthetic data ready."
    fi
fi

# ============================================================================
# STEP 5: Run pipeline phases
# ============================================================================
log "INFO" ""
log "INFO" "[Step 5/6] Running pipeline phases..."

CKPT_DIR=$(python3 -c "import sys; sys.path.insert(0,'scripts'); import config; print(config.CHECKPOINTS_DIR)")

run_phase() {
    local phase_name="$1" script="$2" checkpoint="$3" critical="${4:-true}"
    log "INFO" ""
    log "INFO" "--- $phase_name ---"

    if [ -f "$checkpoint" ] && [ "$CLEAN_START" = false ]; then
        if python3 -c "import json; exit(0 if json.load(open('$checkpoint')).get('status')=='complete' else 1)" 2>/dev/null; then
            log "INFO" "  SKIPPED (checkpoint: complete)"
            return 0
        fi
    fi

    local t0=$(date +%s)
    python3 "$script" 2>&1 | tee -a "$LOG_FILE"
    local rc=${PIPESTATUS[0]}
    local elapsed=$(( $(date +%s) - t0 ))

    if [ $rc -eq 0 ]; then
        log "INFO" "  COMPLETED in ${elapsed}s"
        return 0
    else
        log "ERROR" "  FAILED (exit=$rc) after ${elapsed}s"
        [ "$critical" = "true" ] && return 1
        log "WARN" "  Non-critical. Continuing..."
        return 0
    fi
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

run_phase "Phase 2: Morgan FPs + Scaffold Splits" \
    "scripts/04_compute_morgan_fps.py" "${CKPT_DIR}/phase2_master.json" true || die "Phase 2 failed. Check: python3 scripts/04_compute_morgan_fps.py"
pack_to_drive "data CSVs" "pack_data_csvs"
pack_to_drive "features" "pack_features"

run_phase "Phase 3A: Random Forest Training (7 models)" \
    "scripts/05_train_rf.py" "${CKPT_DIR}/phase3a_master.json" true || die "Phase 3A failed. Check: python3 scripts/05_train_rf.py"
pack_to_drive "RF models" "pack_rf_models"

# Phase 3B: D-MPNN is the MAIN pipeline (not optional)
if ! python3 -c "import chemprop" 2>/dev/null; then
    die "chemprop not installed. D-MPNN is required.
  Install: pip install chemprop torch lightning
  Then re-run: bash run_mac.sh"
fi
# Verify the chemprop CLI entry point exists
CHEMPROP_SCRIPT="$(dirname $(which python3))/chemprop"
if [ ! -f "$CHEMPROP_SCRIPT" ]; then
    log "WARN" "  chemprop entry point not found at $CHEMPROP_SCRIPT"
    log "WARN" "  Reinstalling: pip install --force-reinstall chemprop"
    pip install --force-reinstall chemprop 2>&1 | tail -3
fi
run_phase "Phase 3B: D-MPNN Training (7 models)" \
    "scripts/06_train_dmpnn.py" "${CKPT_DIR}/phase3b_master.json" true || die "Phase 3B (D-MPNN) failed. Check: python3 scripts/06_train_dmpnn.py"
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
        log "WARN" "  Skipping MoLFormer."
    fi
fi

run_phase "Phase 4: Evaluation (5 tests)" \
    "scripts/07_evaluate.py" "${CKPT_DIR}/phase4_master.json" true || die "Phase 4 failed. Check: python3 scripts/07_evaluate.py"

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
# STEP 6: Showcase + Summary
# ============================================================================
log "INFO" ""
log "INFO" "[Step 6/6] Showcase visualizations..."
python3 scripts/08_create_showcase.py 2>&1 | tee -a "$LOG_FILE" || \
    log "WARN" "  Showcase had issues (non-critical)"

# ---- Mark run as successful ----
RUN_DIR="${OUTPUTS_BASE}/runs/${RUN_ID}"
echo "{\"status\":\"success\",\"timestamp\":\"$(date -Iseconds 2>/dev/null || date)\",\"mode\":\"${ANTIBIOTIC_DATA_MODE}\"}" \
    > "${RUN_DIR}/run_status.json" 2>/dev/null || true

# Update latest symlink
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

n_csv=$(find "$RESULTS" -name "*.csv" -type f 2>/dev/null | wc -l | tr -d ' ')
n_fig=$(find "$RESULTS/figures" -type f 2>/dev/null | wc -l | tr -d ' ')
log "INFO" "  Output:  ${n_csv} CSVs, ${n_fig} figures"
log "INFO" "  Results: $RESULTS"
log "INFO" "  Log:     $LOG_FILE"
if [ "$DRIVE_OK" = true ]; then
    log "INFO" "  Drive:   outputs backed up to Google Drive"
else
    log "WARN" "  Drive:   UPLOAD FAILED. All runs kept locally."
fi
log "INFO" ""
log "INFO" "  Re-run:   bash run_mac.sh$([ "$USE_REAL_DATA" = true ] && echo ' --real-data')"
log "INFO" "============================================================"
