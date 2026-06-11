#!/bin/bash
# ============================================================================
# backup_to_drive.sh
#
# Zips the entire antibiotic-selectivity-v2 project into 12 archives and
# uploads them to Google Drive via rclone.
#
# Usage:
#   bash backup_to_drive.sh              # uploads to ada_backup_v4 (default)
#   bash backup_to_drive.sh v5           # uploads to ada_backup_v5
#   bash backup_to_drive.sh v4 --dry-run # zip only, no upload
#
# Run from the project root or any directory (auto-detects project path).
# ============================================================================

set -e

# ---------- CONFIG ----------
PROJECT_DIR="/scratch/vishakha.agrawal/antibiotic-selectivity-v2"
RUN_ID="run_20260315_034033"
RCLONE_BIN="rclone"
DRIVE_REMOTE="gdrive"
DRIVE_BASE="antibiotic_data"
TMP_DIR="/tmp/backup_zips_$$"

# ---------- ARGS ----------
VERSION="${1:-v4}"
DRY_RUN=false
[[ "$2" == "--dry-run" ]] && DRY_RUN=true

DRIVE_FOLDER="${DRIVE_BASE}/ada_backup_${VERSION}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

log "============================================================"
log "  Backup: antibiotic-selectivity-v2"
log "  Version:  ${VERSION}"
log "  Drive:    ${DRIVE_REMOTE}:${DRIVE_FOLDER}/"
log "  Dry run:  ${DRY_RUN}"
log "============================================================"

# ---------- VERIFY ----------
cd "$PROJECT_DIR" || { log "FATAL: $PROJECT_DIR not found"; exit 1; }

if [ ! -d "outputs/runs/${RUN_ID}/results" ]; then
    log "FATAL: Run directory outputs/runs/${RUN_ID}/results not found"
    exit 1
fi

log "  Project: $PROJECT_DIR"
log "  Run ID:  $RUN_ID"
log ""

# ---------- ZIP ----------
mkdir -p "$TMP_DIR"

zip_it() {
    local zipname="$1"; shift
    local zippath="${TMP_DIR}/${zipname}"
    log "  Zipping: $* -> $zipname"
    rm -f "$zippath"
    zip -rq "$zippath" "$@" 2>/dev/null
    if [ -f "$zippath" ]; then
        log "    OK: $(du -sh "$zippath" | cut -f1)"
    else
        log "    FAILED"
    fi
}

t_start=$(date +%s)

log "--- Small files ---"
zip_it "results.zip"           "outputs/runs/${RUN_ID}/results/"
zip_it "features_splits.zip"   "outputs/shared/"
zip_it "data.zip"              "data/"
zip_it "scripts_and_jobs.zip"  "scripts/" "jobs/"
zip_it "resources.zip"         "resources/"
zip_it "logs.zip"              "logs/"

# Root-level files (non-directory, non-zip)
find . -maxdepth 1 -type f -not -name '*.zip' -printf '%f\n' > "${TMP_DIR}/_rootlist.txt"
if [ -s "${TMP_DIR}/_rootlist.txt" ]; then
    cat "${TMP_DIR}/_rootlist.txt" | zip -q "${TMP_DIR}/root_files.zip" -@
    log "  Zipping: root files -> root_files.zip"
    log "    OK: $(du -sh "${TMP_DIR}/root_files.zip" | cut -f1)"
fi
rm -f "${TMP_DIR}/_rootlist.txt"

log ""
log "--- Caches ---"
zip_it "benchmark_cache.zip"   ".benchmark_cache/"
zip_it "hf_cache.zip"          ".hf_cache/"

log ""
log "--- Models (large) ---"
zip_it "models.zip"            "outputs/runs/${RUN_ID}/models/"
zip_it "checkpoints.zip"       "outputs/runs/${RUN_ID}/checkpoints/"

log ""
log "--- Environments (largest) ---"
zip_it "venv.zip"              "venv/"
zip_it "venv_v1.zip"           "venv_v1/"

t_zip=$(date +%s)
log ""
log "  Zipping complete in $(( t_zip - t_start ))s"
log ""
log "  Inventory:"
ls -lhS "${TMP_DIR}/"*.zip 2>/dev/null | awk '{print "    " $5 "  " $NF}'
TOTAL=$(ls "${TMP_DIR}/"*.zip 2>/dev/null | wc -l)
log "  Total: ${TOTAL} zips"

# ---------- UPLOAD ----------
if [ "$DRY_RUN" = true ]; then
    log ""
    log "  DRY RUN: skipping upload. Zips are in ${TMP_DIR}/"
    log "  To upload manually:"
    log "    rclone copy ${TMP_DIR}/ ${DRIVE_REMOTE}:${DRIVE_FOLDER}/ --progress --transfers=1 --drive-chunk-size=64M"
    exit 0
fi

log ""
log "============================================================"
log "  Uploading to ${DRIVE_REMOTE}:${DRIVE_FOLDER}/"
log "============================================================"

# Upload in priority order (smallest/most important first)
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
    "checkpoints.zip"
    "venv.zip"
    "venv_v1.zip"
)

UPLOAD_OK=0
UPLOAD_FAIL=0

for zipname in "${UPLOAD_ORDER[@]}"; do
    zippath="${TMP_DIR}/${zipname}"
    [ -f "$zippath" ] || continue
    zipsize=$(du -sh "$zippath" | cut -f1)

    log "  Uploading: $zipname ($zipsize) ..."
    t_up=$(date +%s)

    $RCLONE_BIN copy "$zippath" "${DRIVE_REMOTE}:${DRIVE_FOLDER}/" \
        --progress --transfers=1 --checkers=1 \
        --drive-chunk-size=64M 2>&1 | grep -E "%|Transferred" | tail -3

    rc=${PIPESTATUS[0]}
    t_up_end=$(date +%s)

    if [ $rc -eq 0 ]; then
        log "    OK ($zipsize in $(( t_up_end - t_up ))s)"
        UPLOAD_OK=$(( UPLOAD_OK + 1 ))
    else
        log "    FAILED (exit $rc)"
        UPLOAD_FAIL=$(( UPLOAD_FAIL + 1 ))
    fi
done

# ---------- VERIFY ----------
log ""
log "  Drive contents:"
$RCLONE_BIN ls "${DRIVE_REMOTE}:${DRIVE_FOLDER}/" 2>/dev/null | while read line; do
    log "    $line"
done

# ---------- CLEANUP ----------
log ""
log "  Cleaning up ${TMP_DIR}/ ..."
rm -rf "$TMP_DIR"

# ---------- SUMMARY ----------
t_end=$(date +%s)
log ""
log "============================================================"
log "  BACKUP COMPLETE"
log "============================================================"
log "  Version:   ${VERSION}"
log "  Location:  ${DRIVE_REMOTE}:${DRIVE_FOLDER}/"
log "  Zips:      ${TOTAL}"
log "  Uploaded:  ${UPLOAD_OK} OK, ${UPLOAD_FAIL} failed"
log "  Time:      $(( t_end - t_start ))s ($(( (t_end - t_start) / 60 ))m)"
log "============================================================"