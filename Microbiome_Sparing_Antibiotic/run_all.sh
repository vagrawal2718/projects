#!/bin/bash
# ============================================================================
# run_all.sh -- End-to-End Pipeline Runner with Detailed Diagnostics
# Project: Microbiome-Sparing Antibiotic Discovery
# ============================================================================
#
# USAGE (on Ada login node):
#   bash run_all.sh           # Submit all phases sequentially
#   bash run_all.sh --from 3a # Resume from Phase 3A
#   bash run_all.sh --phase 2 # Run only Phase 2
#
# Each phase is submitted via SLURM and the script waits for completion
# before submitting the next phase. Detailed diagnostics are logged.
# ============================================================================

set -euo pipefail

PROJECT_DIR="$HOME/antibiotic-selectivity"
export ANTIBIOTIC_PROJECT_DIR="$PROJECT_DIR"
export ANTIBIOTIC_DATA_MODE="real"
RUN_ID="run_$(date +%Y%m%d_%H%M%S)"
export ANTIBIOTIC_RUN_ID="$RUN_ID"
LOG_DIR="${PROJECT_DIR}/logs"
JOBS_DIR="${PROJECT_DIR}/jobs"
SHARED_DIR="${PROJECT_DIR}/outputs/shared"
RESULTS_DIR="${PROJECT_DIR}/outputs/runs/${RUN_ID}/results"
DIAG_LOG="${LOG_DIR}/run_all_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$LOG_DIR" "$RESULTS_DIR"

# ---- Argument parsing ----
START_PHASE="1a"
SINGLE_PHASE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --from)  START_PHASE="$2"; shift 2 ;;
        --phase) SINGLE_PHASE="$2"; shift 2 ;;
        *)       echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# ---- Logging ----
log() {
    local level="$1"; shift
    local msg="[${level}] $(date '+%Y-%m-%d %H:%M:%S') | run_all | $*"
    echo "$msg" | tee -a "$DIAG_LOG"
}

# ---- Activate venv ----
if [ -f "${PROJECT_DIR}/venv/bin/activate" ]; then
    source "${PROJECT_DIR}/venv/bin/activate"
    log "INFO" "Activated venv: $(which python3)"
else
    log "FATAL" "Virtual environment not found. Run ada_full_setup.sh first."
    exit 1
fi

# ---- Phase submission and monitoring ----
submit_and_wait() {
    local phase_name="$1"
    local job_script="$2"
    local expected_outputs="$3"  # Pipe-separated list of expected output files

    log "INFO" ""
    log "INFO" "============================================================"
    log "INFO" " SUBMITTING: $phase_name"
    log "INFO" " Job script: $job_script"
    log "INFO" " Time: $(date '+%Y-%m-%d %H:%M:%S')"
    log "INFO" "============================================================"

    if [ ! -f "$job_script" ]; then
        log "FATAL" "Job script not found: $job_script"
        return 1
    fi

    # Submit
    local submit_output
    submit_output=$(sbatch --export=ALL,ANTIBIOTIC_PROJECT_DIR,ANTIBIOTIC_DATA_MODE,ANTIBIOTIC_RUN_ID "$job_script" 2>&1)
    local job_id
    job_id=$(echo "$submit_output" | grep -oP '\d+' | tail -1)

    if [ -z "$job_id" ]; then
        log "FATAL" "Failed to submit job: $submit_output"
        return 1
    fi

    log "INFO" "  Submitted: Job ID $job_id"
    log "INFO" "  Monitoring: squeue -j $job_id"

    # Wait for completion
    local status="PENDING"
    local wait_count=0
    local max_wait=2880  # 4 hours in 5-second intervals

    while [ "$status" != "COMPLETED" ] && [ "$status" != "FAILED" ] && \
          [ "$status" != "CANCELLED" ] && [ "$status" != "TIMEOUT" ] && \
          [ $wait_count -lt $max_wait ]; do

        sleep 5
        wait_count=$((wait_count + 1))

        # Get job status
        local squeue_out
        squeue_out=$(squeue -j "$job_id" --noheader -o "%T" 2>/dev/null || echo "")

        if [ -z "$squeue_out" ]; then
            # Job no longer in queue -- check sacct
            local sacct_state
            sacct_state=$(sacct -j "$job_id" --noheader -o State -X 2>/dev/null | tr -d ' ' | head -1)
            if [ -n "$sacct_state" ]; then
                status="$sacct_state"
            else
                status="COMPLETED"  # Assume completed if not in queue
            fi
        else
            status=$(echo "$squeue_out" | tr -d ' ')
        fi

        # Progress indicator every 60 seconds
        if [ $((wait_count % 12)) -eq 0 ]; then
            local elapsed=$((wait_count * 5 / 60))
            log "INFO" "  Status: $status (${elapsed}m elapsed)"

            # Show last 3 lines of log if available
            local latest_log
            latest_log=$(ls -t ${LOG_DIR}/${phase_name,,}*.log 2>/dev/null | head -1)
            if [ -n "$latest_log" ] && [ -f "$latest_log" ]; then
                local last_line
                last_line=$(tail -1 "$latest_log" 2>/dev/null)
                if [ -n "$last_line" ]; then
                    log "INFO" "  Log tail: $last_line"
                fi
            fi
        fi
    done

    # Final status
    local elapsed_min=$((wait_count * 5 / 60))
    log "INFO" "  Final status: $status (${elapsed_min}m total)"

    if [ "$status" = "COMPLETED" ]; then
        log "INFO" "  $phase_name COMPLETED SUCCESSFULLY"

        # Verify expected outputs
        if [ -n "$expected_outputs" ]; then
            local IFS='|'
            local all_found=true
            for expected in $expected_outputs; do
                # Handle glob patterns
                local matches
                matches=$(ls $expected 2>/dev/null | wc -l)
                if [ "$matches" -gt 0 ]; then
                    log "INFO" "  Output verified: $expected ($matches files)"
                else
                    log "WARN" "  MISSING output: $expected"
                    all_found=false
                fi
            done
            if [ "$all_found" = false ]; then
                log "WARN" "  Some expected outputs missing. Check logs."
            fi
        fi

        # Report resource usage
        sacct -j "$job_id" --format=JobID,Elapsed,MaxRSS,State -X 2>/dev/null | head -3 | \
            while read line; do log "INFO" "  Resources: $line"; done

        return 0
    else
        log "FATAL" "  $phase_name FAILED with status: $status"
        log "FATAL" "  Check log: ls -t ${LOG_DIR}/${phase_name,,}*.log | head -1"

        # Show last 20 lines of job log
        local latest_log
        latest_log=$(ls -t ${LOG_DIR}/${phase_name,,}*.log 2>/dev/null | head -1)
        if [ -n "$latest_log" ]; then
            log "FATAL" "  Last 10 lines of $latest_log:"
            tail -10 "$latest_log" | while read line; do log "FATAL" "    $line"; done
        fi

        return 1
    fi
}

# ---- Pre-flight checks ----
log "INFO" "============================================================"
log "INFO" " PIPELINE RUNNER: Pre-flight Checks"
log "INFO" "============================================================"

# Check venv
python3 -c "import config; print(f'Config loaded: PROJECT_DIR={config.PROJECT_DIR}')" \
    2>/dev/null || {
    cd "$PROJECT_DIR"
    python3 -c "
import sys; sys.path.insert(0, 'scripts')
import config; print(f'Config loaded: PROJECT_DIR={config.PROJECT_DIR}')
" || log "WARN" "Could not import config.py"
}

# Check Maier data
n_maier=$(ls "${PROJECT_DIR}/data/maier/"*.xlsx 2>/dev/null | wc -l)
log "INFO" "  Maier Excel files: $n_maier"
if [ "$n_maier" -lt 4 ]; then
    log "WARN" "  Expected at least 4 key Maier files. Phase 1B may fail."
fi

# Check SLURM
if command -v sbatch &>/dev/null; then
    log "INFO" "  SLURM: available (sbatch at $(which sbatch))"
else
    log "FATAL" "  SLURM not available. Are you on Ada login node?"
    exit 1
fi

log "INFO" "  Start phase: $START_PHASE"
if [ -n "$SINGLE_PHASE" ]; then
    log "INFO" "  Single phase mode: $SINGLE_PHASE"
fi

# ---- Phase definitions ----
# Format: phase_id|phase_name|job_script|expected_outputs (pipe-separated globs)
PHASES=(
    "1a|Phase1A_ChEMBL|${JOBS_DIR}/phase1a_chembl.sh|${PROJECT_DIR}/data/chembl/*_activity.csv"
    "1b|Phase1B_Maier|${JOBS_DIR}/phase1b_maier.sh|${PROJECT_DIR}/data/maier/maier_combined.csv"
    "1c|Phase1C_Hub|${JOBS_DIR}/phase1c_hub.sh|${PROJECT_DIR}/data/repurposing_hub/repurposing_hub_clean.csv"
    "2|Phase2_Features|${JOBS_DIR}/phase2_features.sh|${SHARED_DIR}/features/morgan_*.npz|${SHARED_DIR}/splits/*_scaffold_folds.pkl"
    "3a|Phase3A_RF|${JOBS_DIR}/phase3a_rf.sh|${RESULTS_DIR}/screening/rf_ranked_*.csv"
    "3b|Phase3B_DMPNN|${JOBS_DIR}/phase3b_dmpnn.sh|${RESULTS_DIR}/screening/dmpnn_ranked_*.csv"
    "4|Phase4_Evaluate|${JOBS_DIR}/phase4_evaluate.sh|${RESULTS_DIR}/cv_metrics_diagnostic.csv"
)

# ---- Determine which phases to run ----
should_run() {
    local phase_id="$1"
    if [ -n "$SINGLE_PHASE" ]; then
        [ "$phase_id" = "$SINGLE_PHASE" ] && return 0 || return 1
    fi
    # Compare phase ordering
    local phase_order="1a 1b 1c 2 3a 3b 4"
    local start_found=false
    for p in $phase_order; do
        if [ "$p" = "$START_PHASE" ]; then
            start_found=true
        fi
        if [ "$start_found" = true ] && [ "$p" = "$phase_id" ]; then
            return 0
        fi
    done
    return 1
}

# ---- Execute phases ----
log "INFO" ""
log "INFO" "============================================================"
log "INFO" " PIPELINE EXECUTION"
log "INFO" " Start: $(date '+%Y-%m-%d %H:%M:%S')"
log "INFO" "============================================================"

PIPELINE_START=$(date +%s)
PHASES_RUN=0
PHASES_FAILED=0

for phase_def in "${PHASES[@]}"; do
    IFS='|' read -r phase_id phase_name job_script expected_outputs <<< "$phase_def"

    if ! should_run "$phase_id"; then
        log "INFO" "  Skipping $phase_name (before start phase)"
        continue
    fi

    if submit_and_wait "$phase_name" "$job_script" "$expected_outputs"; then
        PHASES_RUN=$((PHASES_RUN + 1))
    else
        PHASES_FAILED=$((PHASES_FAILED + 1))
        log "FATAL" "Pipeline halted at $phase_name."
        log "FATAL" "Fix the issue, then resume with:"
        log "FATAL" "  bash run_all.sh --from $phase_id"
        break
    fi
done

# ---- Package outputs ----
if [ $PHASES_FAILED -eq 0 ] && [ $PHASES_RUN -gt 0 ]; then
    log "INFO" ""
    log "INFO" "============================================================"
    log "INFO" " PACKAGING OUTPUTS"
    log "INFO" "============================================================"

    OUTPUT_DIR="${PROJECT_DIR}/outputs"
    mkdir -p "$OUTPUT_DIR"

    # Copy key results
    cp -r "${RESULTS_DIR}/"*.csv "$OUTPUT_DIR/" 2>/dev/null || true
    cp -r "${RESULTS_DIR}/figures" "$OUTPUT_DIR/" 2>/dev/null || true
    cp -r "${RESULTS_DIR}/reports" "$OUTPUT_DIR/" 2>/dev/null || true
    cp -r "${RESULTS_DIR}/screening" "$OUTPUT_DIR/" 2>/dev/null || true

    # Create ZIP
    ZIP_FILE="${PROJECT_DIR}/outputs/all_results_$(date +%Y%m%d).zip"
    cd "${RESULTS_DIR}"
    zip -r "$ZIP_FILE" . -x "*.pyc" 2>/dev/null || true
    log "INFO" "  Results packaged: $ZIP_FILE"
    log "INFO" "  Download with:"
    log "INFO" "    scp ${USER}@ada.iiit.ac.in:${ZIP_FILE} ."
fi

# ---- Final summary ----
PIPELINE_END=$(date +%s)
PIPELINE_ELAPSED=$(( (PIPELINE_END - PIPELINE_START) / 60 ))

log "INFO" ""
log "INFO" "============================================================"
log "INFO" " PIPELINE SUMMARY"
log "INFO" "============================================================"
log "INFO" "  Phases run:    $PHASES_RUN"
log "INFO" "  Phases failed: $PHASES_FAILED"
log "INFO" "  Total time:    ${PIPELINE_ELAPSED} minutes"
log "INFO" "  Diagnostic log: $DIAG_LOG"
log "INFO" ""

if [ $PHASES_FAILED -eq 0 ]; then
    log "INFO" "  STATUS: ALL PHASES COMPLETED SUCCESSFULLY"

    # Mark run as successful
    RUN_STATUS_DIR="${PROJECT_DIR}/outputs/runs/${RUN_ID}"
    mkdir -p "$RUN_STATUS_DIR" 2>/dev/null || true
    echo "{\"status\":\"success\",\"timestamp\":\"$(date -Iseconds 2>/dev/null || date)\",\"phases_run\":$PHASES_RUN}" \
        > "${RUN_STATUS_DIR}/run_status.json" 2>/dev/null || true
    rm -f "${PROJECT_DIR}/outputs/latest"
    ln -sf "runs/${RUN_ID}" "${PROJECT_DIR}/outputs/latest" 2>/dev/null || true

    log "INFO" ""
    log "INFO" "  Key outputs:"
    log "INFO" "    ${RESULTS_DIR}/cv_metrics_diagnostic.csv"
    log "INFO" "    ${RESULTS_DIR}/test1_rank_separation.csv"
    log "INFO" "    ${RESULTS_DIR}/test2_selectivity_auc.csv"
    log "INFO" "    ${RESULTS_DIR}/test3_topk_enrichment.csv"
    log "INFO" "    ${RESULTS_DIR}/test4_rank_correlation.csv"
    log "INFO" "    ${RESULTS_DIR}/test5_threshold_sensitivity.csv"
    log "INFO" "    ${RESULTS_DIR}/validation_set.csv"
    log "INFO" "    ${RESULTS_DIR}/figures/ (publication-quality PDFs)"
    log "INFO" "    ${RESULTS_DIR}/screening/ (24 ranked lists)"
else
    log "INFO" "  STATUS: PIPELINE INCOMPLETE ($PHASES_FAILED phases failed)"

    # Mark run as failed
    RUN_STATUS_DIR="${PROJECT_DIR}/outputs/runs/${RUN_ID}"
    mkdir -p "$RUN_STATUS_DIR" 2>/dev/null || true
    echo "{\"status\":\"failed\",\"timestamp\":\"$(date -Iseconds 2>/dev/null || date)\",\"phases_failed\":$PHASES_FAILED}" \
        > "${RUN_STATUS_DIR}/run_status.json" 2>/dev/null || true
fi
log "INFO" "============================================================"
