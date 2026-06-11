#!/bin/bash
#SBATCH --partition=u22
#SBATCH -A research
## SBATCH --qos=low
#SBATCH -n 10
#SBATCH --mem-per-cpu=2G
#SBATCH --time=1:00:00
#SBATCH --output=/home2/%u/antibiotic-selectivity/logs/phase2_%j.log
#SBATCH --job-name=morgan_fp

# ===========================================================================
# Phase 2: Feature Engineering (Morgan FPs + Scaffold Splits)
# Computes 2048-bit Morgan fingerprints, generates scaffold folds
# Runtime: ~10-15 min | CPU only | No network
# ===========================================================================

echo "=== Phase 2 started at $(date) ==="
echo "Node: $(hostname) | Job ID: $SLURM_JOB_ID | CPUs: $SLURM_NTASKS"

source ~/antibiotic-selectivity/venv/bin/activate
cd ~/antibiotic-selectivity
export ANTIBIOTIC_PROJECT_DIR=~/antibiotic-selectivity
export ANTIBIOTIC_DATA_MODE=real
export ANTIBIOTIC_RUN_ID="${ANTIBIOTIC_RUN_ID:-current}"

# Try restoring from ZIP bundles first
python scripts/restore_data.py || true

python scripts/04_compute_morgan_fps.py

EXIT_CODE=$?
echo "=== Phase 2 finished at $(date) with exit code $EXIT_CODE ==="
exit $EXIT_CODE
