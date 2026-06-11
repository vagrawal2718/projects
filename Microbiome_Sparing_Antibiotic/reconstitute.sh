#!/bin/bash
# ============================================================================
# reconstitute.sh - Rebuild full antibiotic-selectivity project from share1 zips
#
# Usage:
#   bash reconstitute.sh                                          # default: ~/antibiotic-selectivity
#   bash reconstitute.sh /scratch/$USER/antibiotic-selectivity    # to scratch (compute node only)
#   bash reconstitute.sh /home2/$USER/antibiotic-selectivity      # to home
#   bash reconstitute.sh /path/to/anywhere                        # custom
#
# NOTE: Reconstituting to /scratch must be done from a compute node.
#       Reconstituting to /home2 can be done from login or compute node.
# ============================================================================

set -uo pipefail

DST="${1:-$HOME/antibiotic-selectivity}"
SRC="/share1/vishakha.agrawal/antibiotic-selectivity"

echo "============================================================"
echo " Reconstitute: share1 zips -> full project"
echo " Source: $SRC"
echo " Dest:   $DST"
echo " Time:   $(date)"
echo "============================================================"
echo ""

# Pre-flight checks
if ! ls "$SRC/"*.zip &>/dev/null; then
    echo "FATAL: No zip files found in $SRC"
    echo "Run backup_zip.sh first."
    exit 1
fi

# Check if destination is scratch and we're on a compute node
if echo "$DST" | grep -q "/scratch"; then
    if [ ! -d "/scratch" ]; then
        echo "FATAL: /scratch not accessible. Are you on a compute node?"
        echo "Run: srun --pty --partition=u22 -A research --mem-per-cpu=2G -c 10 --time=6:00:00 bash -l"
        exit 1
    fi
fi

mkdir -p "$DST"

ERRORS=0
RESTORED=0
SKIPPED=0

# ---- Core project zips (order matters: root files first, then folders) ----
ZIPS=(
    "root_files.zip"
    "data.zip"
    "outputs.zip"
    "scripts_and_jobs.zip"
    "logs.zip"
    "hf_cache.zip"
    "benchmark_cache.zip"
    "resources.zip"
    "venv.zip"
    "venv_v1.zip"
)

echo "[1/4] Extracting project zips..."
echo ""

for z in "${ZIPS[@]}"; do
    zippath="$SRC/$z"
    if [ -f "$zippath" ]; then
        echo "  Extracting: $z"
        local_size=$(du -sh "$zippath" | cut -f1)
        t0=$(date +%s)
        unzip -qo "$zippath" -d "$DST"
        rc=$?
        t1=$(date +%s)
        if [ $rc -eq 0 ]; then
            echo "    OK ($local_size, $((t1 - t0))s)"
            RESTORED=$((RESTORED + 1))
        else
            echo "    FAILED (exit code $rc)"
            echo "    FIX: Check disk space at destination"
            echo "    FIX: Try manually: unzip -o $zippath -d $DST"
            ERRORS=$((ERRORS + 1))
        fi
    else
        echo "  MISSING: $z (skipped)"
        SKIPPED=$((SKIPPED + 1))
    fi
done

# ---- Copy any other zips that were in the original home directory ----
echo ""
echo "[2/4] Copying additional zip files..."

for z in "$SRC"/*.zip; do
    [ -f "$z" ] || continue
    zname=$(basename "$z")

    # Skip the zips we just extracted (they are backups, not part of the project)
    case "$zname" in
        root_files.zip|data.zip|outputs.zip|scripts_and_jobs.zip|logs.zip|\
        hf_cache.zip|benchmark_cache.zip|resources.zip|venv.zip|venv_v1.zip)
            continue ;;
    esac

    # These are original project zips (like antibiotic_pipeline_FINAL.zip)
    if [ ! -f "$DST/$zname" ]; then
        echo "  Copying: $zname"
        cp "$z" "$DST/"
        echo "    OK ($(du -sh "$DST/$zname" | cut -f1))"
    else
        echo "  SKIP: $zname (already exists)"
    fi
done

# ---- Restore home dotfiles (if requested) ----
echo ""
echo "[3/4] Home dotfiles..."

DOTFILES_ZIP="/share1/vishakha.agrawal/home_dotfiles.zip"
if [ -f "$DOTFILES_ZIP" ]; then
    echo "  home_dotfiles.zip found ($(du -sh "$DOTFILES_ZIP" | cut -f1))"
    echo "  NOTE: Dotfiles are restored to your HOME directory, not to $DST"
    echo "  NOTE: .ssh/, .bashrc, .config/ were excluded from backup"
    read -p "  Restore home dotfiles to $HOME? (y/n): " RESTORE_DOTS
    if [ "$RESTORE_DOTS" = "y" ] || [ "$RESTORE_DOTS" = "Y" ]; then
        cd "$HOME"
        unzip -qo "$DOTFILES_ZIP"
        rc=$?
        if [ $rc -eq 0 ]; then
            echo "    OK: dotfiles restored to $HOME"
        else
            echo "    FAILED (exit code $rc)"
            echo "    FIX: Try manually: cd ~ && unzip -o $DOTFILES_ZIP"
            ERRORS=$((ERRORS + 1))
        fi
        cd "$DST"
    else
        echo "  Skipped. To restore later: cd ~ && unzip -o $DOTFILES_ZIP"
    fi
else
    echo "  home_dotfiles.zip not found (skipped)"
fi

# ---- Verification ----
echo ""
echo "[4/4] Verification..."
echo ""

# Check expected structure
EXPECTED_DIRS=("data" "outputs" "scripts" "jobs" "logs" "resources")
echo "  Directory structure:"
for d in "${EXPECTED_DIRS[@]}"; do
    if [ -d "$DST/$d" ]; then
        count=$(find "$DST/$d" -type f | wc -l)
        size=$(du -sh "$DST/$d" | cut -f1)
        echo "    [OK]   $d/ ($count files, $size)"
    else
        echo "    [MISS] $d/"
    fi
done

# Optional dirs
for d in ".hf_cache" ".benchmark_cache" "venv" "venv_v1"; do
    if [ -d "$DST/$d" ]; then
        size=$(du -sh "$DST/$d" | cut -f1)
        echo "    [OK]   $d/ ($size)"
    else
        echo "    [MISS] $d/ (optional)"
    fi
done

# Root files
ROOT_COUNT=$(find "$DST" -maxdepth 1 -type f | wc -l)
echo "    [OK]   root files: $ROOT_COUNT"

echo ""
TOTAL_FILES=$(find "$DST" -type f | wc -l)
TOTAL_SIZE=$(du -sh "$DST" | cut -f1)
echo "  Total files: $TOTAL_FILES"
echo "  Total size:  $TOTAL_SIZE"

# Check venv is functional
if [ -f "$DST/venv/bin/activate" ]; then
    echo ""
    echo "  Venv activation test:"
    echo "    source $DST/venv/bin/activate"
    source "$DST/venv/bin/activate" 2>/dev/null && {
        echo "    Python: $(python3 --version 2>&1)"
        python3 -c "import torch, chemprop, rdkit; print('    Imports: OK')" 2>/dev/null || \
            echo "    Imports: FAILED (may need module load u22/python/3.12.4 first)"
        deactivate 2>/dev/null
    } || echo "    Activation failed (may need to be on compute node)"
fi

echo ""
echo "============================================================"
if [ $ERRORS -eq 0 ]; then
    echo " RECONSTITUTION COMPLETE"
    echo " Restored: $RESTORED zips, Skipped: $SKIPPED"
else
    echo " RECONSTITUTION COMPLETED WITH $ERRORS ERROR(S)"
    echo " Review output above."
fi
echo " Time: $(date)"
echo "============================================================"
echo ""
echo " To use:"
echo "   cd $DST"
echo "   module load u22/python/3.12.4"
echo "   source venv/bin/activate"
echo "   python3 scripts/00_verify_environment.py"
echo "============================================================"

