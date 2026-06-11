#!/bin/bash
# ============================================================================
# job_manager.sh v2
#
# Master script for end-to-end pipeline management on Ada HPC.
# Run from the LOGIN NODE.
#
# Commands:
#   bash ~/job_manager.sh submit [--fresh]   Submit batch job
#   bash ~/job_manager.sh status             Check job, show log, check errors
#   bash ~/job_manager.sh collect            Transfer results to Drive or share1
#   bash ~/job_manager.sh verify             Deep-check all outputs exist
#   bash ~/job_manager.sh quota              Disk usage across all storage
#   bash ~/job_manager.sh list               List zips on share1 and/or Drive
#   bash ~/job_manager.sh download           Show download commands
#   bash ~/job_manager.sh help               Show this help
#
# Storage flow:
#   home2 (25 GB) --[batch copies]--> scratch (2 TB, 7-day purge)
#   scratch --[rclone]--> Google Drive (permanent)
#   scratch --[bridge]--> share1 (100 GB, permanent, zips only)
#
# Expected 12 zips:
#   results.zip, features_splits.zip, data.zip, scripts_and_jobs.zip,
#   resources.zip, logs.zip, root_files.zip, benchmark_cache.zip,
#   hf_cache.zip, models.zip, venv.zip, venv_v1.zip
#
# ============================================================================

set -uo pipefail

HOME_DIR="/home2/vishakha.agrawal/antibiotic-selectivity"
SHARE_DIR="/share1/vishakha.agrawal/antibiotic-selectivity"
METADATA="$HOME_DIR/.last_batch_job.txt"
USER="vishakha.agrawal"
SCRATCH_BASE="/scratch/vishakha.agrawal"
RCLONE_BIN="$SCRATCH_BASE/rclone"
RCLONE_CONF="$SCRATCH_BASE/.config/rclone/rclone.conf"
DRIVE_REMOTE="gdrive"
DRIVE_FOLDER="antibiotic_data/ada_backup_v2"

EXPECTED_ZIPS=(
    "results.zip" "features_splits.zip" "data.zip" "scripts_and_jobs.zip"
    "resources.zip" "logs.zip" "root_files.zip" "benchmark_cache.zip"
    "hf_cache.zip" "models.zip" "venv.zip" "venv_v1.zip"
)

log() { echo "[$(date '+%H:%M:%S')] $*"; }

CMD="${1:-help}"
shift 2>/dev/null || true
EXTRA_ARGS="$*"

case "$CMD" in

# ============================================================================
submit)
# ============================================================================
    echo "============================================================"
    echo " Submit Pipeline Job"
    echo "============================================================"
    echo ""

    if [ ! -f "$HOME_DIR/run_batch.sh" ]; then
        echo "FATAL: $HOME_DIR/run_batch.sh not found."
        echo "  Reconstitute: bash ~/reconstitute.sh ~/antibiotic-selectivity"
        exit 1
    fi

    # Parse --fresh flag
    BATCH_ARGS=""
    for arg in $EXTRA_ARGS; do
        case "$arg" in
            --fresh|--resume) BATCH_ARGS="$BATCH_ARGS $arg" ;;
        esac
    done

    # Check running jobs
    RUNNING=$(squeue -u $USER -h 2>/dev/null | wc -l)
    if [ "$RUNNING" -gt 0 ]; then
        echo "WARNING: Jobs already running:"
        squeue -u $USER
        echo ""
        read -p "Submit anyway? (y/n): " CONFIRM
        [ "$CONFIRM" != "y" ] && echo "Cancelled." && exit 0
    fi

    echo "  Mode: $(echo $BATCH_ARGS | grep -q 'fresh' && echo 'FRESH (deep-verify, rerun gaps)' || echo 'RESUME (quick skip)')"
    echo ""
    echo "  Quota:"
    quota -s 2>/dev/null | grep -E "home2|sdg1" || true
    echo ""

    cd "$HOME_DIR"
    JOB_OUTPUT=$(sbatch run_batch.sh $BATCH_ARGS 2>&1)
    echo "  $JOB_OUTPUT"

    JOB_ID=$(echo "$JOB_OUTPUT" | grep -oP '\d+' | tail -1)
    if [ -n "$JOB_ID" ]; then
        echo ""
        echo "  Job ID: $JOB_ID"
        echo ""
        echo "  Next steps:"
        echo "    bash ~/job_manager.sh status                    # check progress"
        echo "    tail -f ~/antibiotic-selectivity/logs/all_models_${JOB_ID}.log  # live feed"
        echo "    bash ~/job_manager.sh collect                   # after job finishes"
        echo "    bash ~/job_manager.sh verify                    # confirm all outputs"
    fi
    ;;

# ============================================================================
status)
# ============================================================================
    echo "============================================================"
    echo " Job Status"
    echo "============================================================"
    echo ""

    JOBS=$(squeue -u $USER -h 2>/dev/null)
    if [ -z "$JOBS" ]; then
        echo "  No running or pending jobs."
        echo ""

        if [ -f "$METADATA" ]; then
            source "$METADATA"
            echo "  Last batch job:"
            echo "    Node:      ${NODE:-?}"
            echo "    Job ID:    ${JOB_ID:-?}"
            echo "    Run ID:    ${RUN_ID:-?}"
            echo "    Mode:      ${FRESH_MODE:-?}"
            echo "    Timestamp: ${TIMESTAMP:-?}"
            echo "    Uploaded:  ${UPLOAD_OK:-?}"
            echo ""

            if [ "${UPLOAD_OK:-false}" = "true" ]; then
                echo "  Results uploaded to Google Drive."
                echo "  Verify: bash ~/job_manager.sh verify"
            else
                echo "  Results on scratch at ${NODE:-?} (7-day purge!)."
                echo "  Collect: bash ~/job_manager.sh collect"
            fi
        fi

        # Show last log summary
        LATEST_LOG=$(ls -t "$HOME_DIR/logs/all_models_"*.log 2>/dev/null | head -1)
        if [ -n "$LATEST_LOG" ]; then
            echo ""
            echo "  Latest log: $(basename $LATEST_LOG)"

            # Check completion
            if grep -q "COMPLETE" "$LATEST_LOG" 2>/dev/null; then
                echo "  Status: COMPLETED"
                grep "Models:" "$LATEST_LOG" | tail -1 | sed 's/^/  /'
                grep -A 4 "Models:" "$LATEST_LOG" | tail -4 | sed 's/^/  /'
            elif grep -q "FATAL" "$LATEST_LOG" 2>/dev/null; then
                echo "  Status: FAILED"
                grep "FATAL" "$LATEST_LOG" | tail -1 | sed 's/^/  /'
            else
                echo "  Status: INCOMPLETE (job may have timed out)"
            fi

            # Error count
            ERRS=$(grep -ci "error\|fatal\|fail\|traceback\|quota exceeded" "$LATEST_LOG" 2>/dev/null || echo 0)
            echo "  Error lines: $ERRS"
            if [ "$ERRS" -gt 0 ]; then
                echo ""
                echo "  Recent errors:"
                grep -i "error\|fatal\|fail\|quota" "$LATEST_LOG" | tail -5 | sed 's/^/    /'
            fi
        fi
    else
        squeue -u $USER
        echo ""

        LATEST_LOG=$(ls -t "$HOME_DIR/logs/all_models_"*.log 2>/dev/null | head -1)
        if [ -n "$LATEST_LOG" ]; then
            echo "  Log: $LATEST_LOG"
            echo "  Last 20 lines:"
            echo "  ----"
            tail -20 "$LATEST_LOG" | sed 's/^/  /'
            echo "  ----"
            echo ""
            echo "  Live: tail -f $LATEST_LOG"

            ERRS=$(grep -ci "error\|fatal\|fail\|traceback" "$LATEST_LOG" 2>/dev/null || echo 0)
            [ "$ERRS" -gt 0 ] && echo "  WARNING: $ERRS error lines found."
        fi
    fi

    echo ""
    echo "  Quota:"
    quota -s 2>/dev/null | grep -E "home2|sdg1|Filesystem" || true
    ;;

# ============================================================================
collect)
# ============================================================================
    echo "============================================================"
    echo " Collect Results"
    echo "============================================================"
    echo ""

    RUNNING=$(squeue -u $USER -h 2>/dev/null | wc -l)
    if [ "$RUNNING" -gt 0 ]; then
        echo "WARNING: Job still running:"
        squeue -u $USER
        echo "  Wait for it to finish first."
        exit 1
    fi

    # Check if already uploaded
    if [ -f "$METADATA" ]; then
        source "$METADATA"
        if [ "${UPLOAD_OK:-false}" = "true" ]; then
            echo "  Results were already uploaded to Drive by the batch job."
            echo "  Verify: bash ~/job_manager.sh verify"
            echo ""
            read -p "  Upload again anyway? (y/n): " CONFIRM
            [ "$CONFIRM" != "y" ] && exit 0
        fi
    fi

    if [ -f "$HOME/collect_and_archive.sh" ]; then
        echo "  Choose transfer method:"
        echo "    1. Google Drive (--drive, from compute node)"
        echo "    2. share1 bridge (--bridge, from login node)"
        echo ""

        if [ -f "$RCLONE_CONF" ] 2>/dev/null; then
            echo "  rclone configured. To upload from compute node:"
            echo "    srun --pty --partition=u22 -A research --nodelist=${NODE:-gnode049} --mem-per-cpu=2G -c 2 --time=2:00:00 bash -l"
            echo "    bash ~/collect_and_archive.sh --drive"
        else
            echo "  rclone not configured. Options:"
            echo "    A. Set up Drive (on compute node): bash ~/collect_and_archive.sh --setup-drive"
            echo "    B. Bridge to share1 (on login node): bash ~/collect_and_archive.sh --bridge ${NODE:-gnode049}"
        fi
    else
        echo "FATAL: ~/collect_and_archive.sh not found."
        exit 1
    fi
    ;;

# ============================================================================
verify)
# ============================================================================
    echo "============================================================"
    echo " Verify All Outputs"
    echo "============================================================"
    echo ""

    TOTAL_OK=0
    TOTAL_MISS=0

    # Check Drive if rclone available
    if [ -x "$RCLONE_BIN" ] && [ -f "$RCLONE_CONF" ]; then
        export RCLONE_CONFIG="$RCLONE_CONF"
        log "Checking Google Drive ($DRIVE_FOLDER/)..."

        DRIVE_LIST=$($RCLONE_BIN lsf "$DRIVE_REMOTE:$DRIVE_FOLDER/" --format "ps" 2>/dev/null || echo "CONNECTION_FAILED")

        if [ "$DRIVE_LIST" = "CONNECTION_FAILED" ]; then
            log "  Cannot connect to Drive. Token expired?"
            log "  FIX: bash ~/collect_and_archive.sh --setup-drive (from compute node)"
        else
            echo ""
            for z in "${EXPECTED_ZIPS[@]}"; do
                if echo "$DRIVE_LIST" | grep -q "$z"; then
                    SIZE=$(echo "$DRIVE_LIST" | grep "$z" | awk '{print $1}')
                    log "  [OK]   $z ($SIZE)"
                    TOTAL_OK=$((TOTAL_OK + 1))
                else
                    log "  [MISS] $z"
                    TOTAL_MISS=$((TOTAL_MISS + 1))
                fi
            done
        fi
    else
        log "rclone not available. Cannot check Drive."
        log "  Run from compute node: bash ~/collect_and_archive.sh --verify"
    fi

    # Check share1
    echo ""
    if ls /share1/vishakha.agrawal/ &>/dev/null; then
        log "Checking share1 ($SHARE_DIR/)..."
        S1_OK=0
        S1_MISS=0
        for z in "${EXPECTED_ZIPS[@]}"; do
            if [ -f "$SHARE_DIR/$z" ]; then
                log "  [OK]   $(du -sh "$SHARE_DIR/$z" | awk '{print $1}')  $z"
                S1_OK=$((S1_OK + 1))
            else
                log "  [MISS] $z"
                S1_MISS=$((S1_MISS + 1))
            fi
        done
        log "  share1: $S1_OK OK, $S1_MISS missing"
    else
        log "share1 not accessible (login node only)."
    fi

    # Check last log for model results
    echo ""
    LATEST_LOG=$(ls -t "$HOME_DIR/logs/all_models_"*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        log "Model results from last run:"
        grep -A 5 "Models:" "$LATEST_LOG" 2>/dev/null | grep -E "RF|MPNN|CheMeleon|MoLFormer|Figures|Screening|Comparison" | sed 's/^/  /'
    fi

    echo ""
    log "============================================================"
    if [ $TOTAL_MISS -eq 0 ] && [ $TOTAL_OK -gt 0 ]; then
        log " ALL $TOTAL_OK/${#EXPECTED_ZIPS[@]} ZIPS VERIFIED"
    elif [ $TOTAL_OK -gt 0 ]; then
        log " $TOTAL_OK OK, $TOTAL_MISS MISSING on Drive"
        log " Re-run: bash ~/collect_and_archive.sh --drive (from compute node)"
    else
        log " Could not verify Drive (run from compute node with rclone)"
    fi
    log "============================================================"
    ;;

# ============================================================================
quota)
# ========================================================================