#!/bin/bash
# ============================================================================
# collect_and_archive.sh v2
#
# Transfers pipeline results from scratch to Google Drive or share1.
# Consistent with run_batch.sh v2 (_zips/ directory, 12 separate zips).
#
# Commands:
#   bash ~/collect_and_archive.sh --setup-drive      Install rclone + configure Drive
#   bash ~/collect_and_archive.sh --drive             Upload _zips/ to Drive (compute node)
#   bash ~/collect_and_archive.sh --bridge [NODE]     Bridge via home to share1 (login node)
#   bash ~/collect_and_archive.sh --verify            Verify all outputs exist on Drive
#   bash ~/collect_and_archive.sh --help              Show help
#   bash ~/collect_and_archive.sh                     Auto-detect: Drive if configured
#
# Expected zips (from run_batch.sh v2):
#   results.zip, features_splits.zip, data.zip, scripts_and_jobs.zip,
#   resources.zip, logs.zip, root_files.zip, benchmark_cache.zip,
#   hf_cache.zip, models.zip, venv.zip, venv_v1.zip
#
# ============================================================================

set -uo pipefail

HOME_DIR="/home2/vishakha.agrawal/antibiotic-selectivity"
SHARE_DIR="/share1/vishakha.agrawal/antibiotic-selectivity"
BRIDGE_DIR="/home2/vishakha.agrawal/_bridge"
SCRATCH_BASE="/scratch/vishakha.agrawal"
RCLONE_BIN="$SCRATCH_BASE/rclone"
RCLONE_CONF="$SCRATCH_BASE/.config/rclone/rclone.conf"
DRIVE_REMOTE="gdrive"
DRIVE_FOLDER="antibiotic_data/ada_backup_v2"
METADATA="$HOME_DIR/.last_batch_job.txt"

# All 12 expected zips in upload priority order
EXPECTED_ZIPS=(
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

log() { echo "[$(date '+%H:%M:%S')] $*"; }
die() { log "FATAL: $*"; exit 1; }

# ---- Parse arguments ----
MODE=""
MANUAL_NODE=""
for arg in "$@"; do
    case "$arg" in
        --setup-drive) MODE="setup" ;;
        --drive)       MODE="drive" ;;
        --bridge)      MODE="bridge" ;;
        --verify)      MODE="verify" ;;
        --help|-h)     MODE="help" ;;
        gnode*)        MANUAL_NODE="$arg" ;;
    esac
done

# ---- Help ----
if [ "$MODE" = "help" ]; then
    echo "============================================================"
    echo " collect_and_archive.sh v2"
    echo "============================================================"
    echo ""
    echo " Commands (run from indicated location):"
    echo "   --setup-drive   [COMPUTE NODE] Install rclone + configure Drive"
    echo "   --drive         [COMPUTE NODE] Upload _zips/ to Google Drive"
    echo "   --bridge NODE   [LOGIN NODE]   Bridge: scratch -> home -> share1"
    echo "   --verify        [COMPUTE NODE] Verify all outputs on Drive"
    echo "   (no args)       Auto: Drive if configured, else bridge"
    echo ""
    echo " Workflow:"
    echo "   1. bash ~/collect_and_archive.sh --setup-drive    (once)"
    echo "   2. sbatch run_batch.sh --fresh                    (runs + uploads)"
    echo "   3. bash ~/collect_and_archive.sh --verify         (confirm)"
    echo ""
    echo " Expected 12 zips: results, features_splits, data, scripts_and_jobs,"
    echo "   resources, logs, root_files, benchmark_cache, hf_cache,"
    echo "   models, venv, venv_v1"
    echo "============================================================"
    exit 0
fi

# ---- Read metadata ----
NODE=""
SCRATCH_DIR=""
ZIP_DIR=""
RUN_ID=""
JOB_ID=""
TIMESTAMP=""
UPLOAD_OK=""

if [ -f "$METADATA" ]; then
    source "$METADATA"
    ZIP_DIR="${ZIP_DIR:-$SCRATCH_DIR/_zips}"
fi
[ -n "$MANUAL_NODE" ] && NODE="$MANUAL_NODE"
[ -z "$SCRATCH_DIR" ] && SCRATCH_DIR="$SCRATCH_BASE/antibiotic-selectivity-v2"
[ -z "$ZIP_DIR" ] && ZIP_DIR="$SCRATCH_DIR/_zips"

# ============================================================================
# MODE: setup-drive
# ============================================================================
if [ "$MODE" = "setup" ]; then
    echo "============================================================"
    echo " Google Drive Setup (one-time)"
    echo "============================================================"
    echo ""

    # Install rclone
    if [ -x "$RCLONE_BIN" ]; then
        log "rclone installed: $($RCLONE_BIN version | head -1)"
    else
        log "Installing rclone..."
        cd "$SCRATCH_BASE"
        rm -f rclone-current-linux-amd64.zip
        curl -O https://downloads.rclone.org/rclone-current-linux-amd64.zip
        [ $? -ne 0 ] && die "Download failed."
        unzip -oq rclone-current-linux-amd64.zip
        cp rclone-v*-linux-amd64/rclone "$RCLONE_BIN"
        chmod +x "$RCLONE_BIN"
        rm -rf rclone-v*-linux-amd64 rclone-current-linux-amd64.zip
        log "Installed: $($RCLONE_BIN version | head -1)"
    fi

    echo ""
    log "============================================================"
    log "On your LOCAL machine (with browser), run:"
    log ""
    log "  curl -O https://downloads.rclone.org/rclone-current-linux-amd64.zip"
    log "  unzip rclone-current-linux-amd64.zip"
    log "  ./rclone-v*-linux-amd64/rclone authorize \"drive\""
    log ""
    log "Paste the ENTIRE JSON token below (starts with {, ends with }):"
    log "============================================================"
    echo ""
    read -r TOKEN

    [ -z "$TOKEN" ] && die "No token provided."
    echo "$TOKEN" | grep -q "access_token" || die "Token invalid. Must contain 'access_token'."

    mkdir -p "$(dirname "$RCLONE_CONF")"
    cat > "$RCLONE_CONF" << CONFEOF
[gdrive]
type = drive
scope = drive
token = $TOKEN
CONFEOF

    log "Config saved: $RCLONE_CONF"
    echo ""

    export RCLONE_CONFIG="$RCLONE_CONF"
    log "Testing connection..."
    $RCLONE_BIN lsf "$DRIVE_REMOTE": --max-depth 1 > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        log "Connection OK."
        log ""
        log "============================================================"
        log " SETUP COMPLETE"
        log " Upload: bash ~/collect_and_archive.sh --drive"
        log " Or let run_batch.sh upload automatically."
        log "============================================================"
    else
        die "Connection failed. Generate a fresh token and retry."
    fi
    exit 0
fi

# ---- Auto-detect mode ----
if [ -z "$MODE" ]; then
    if [ -x "$RCLONE_BIN" ] && [ -f "$RCLONE_CONF" ]; then
        MODE="drive"
        log "Auto: rclone configured, using Drive."
    else
        MODE="bridge"
        log "Auto: rclone not configured, using bridge."
    fi
fi

echo "============================================================"
echo " Collect and Archive v2"
echo " Mode:      $MODE"
echo " Node:      ${NODE:-auto}"
echo " ZIP dir:   $ZIP_DIR"
echo " Run ID:    ${RUN_ID:-unknown}"
echo " Job:       ${JOB_ID:-unknown} at ${TIMESTAMP:-unknown}"
echo " Time:      $(date)"
echo "============================================================"
echo ""

# ============================================================================
# MODE: drive (upload from scratch to Google Drive)
# ============================================================================
if [ "$MODE" = "drive" ]; then

    [ ! -d "$ZIP_DIR" ] && die "ZIP directory not found: $ZIP_DIR
  Are you on the correct compute node (${NODE:-unknown})?
  Run: srun --pty --partition=u22 -A research --nodelist=${NODE:-gnode049} --mem-per-cpu=2G -c 2 --time=2:00:00 bash -l"

    [ ! -x "$RCLONE_BIN" ] && die "rclone not installed. Run: bash ~/collect_and_archive.sh --setup-drive"
    [ ! -f "$RCLONE_CONF" ] && die "rclone not configured. Run: bash ~/collect_and_archive.sh --setup-drive"

    export RCLONE_CONFIG="$RCLONE_CONF"

    log "Testing Drive connection..."
    $RCLONE_BIN lsf "$DRIVE_REMOTE": --max-depth 1 > /dev/null 2>&1
    [ $? -ne 0 ] && die "Drive connection failed. Re-run: bash ~/collect_and_archive.sh --setup-drive"
    log "  OK"
    echo ""

    # Show what's available
    log "Available zips in $ZIP_DIR:"
    AVAILABLE=0
    MISSING=0
    for z in "${EXPECTED_ZIPS[@]}"; do
        if [ -f "$ZIP_DIR/$z" ]; then
            log "  [OK]   $(d