#!/bin/bash
#SBATCH --partition=u22
#SBATCH -A research
## SBATCH --qos=low
#SBATCH -n 4
#SBATCH --mem-per-cpu=2G
#SBATCH --time=2:00:00
#SBATCH --output=/home2/%u/antibiotic-selectivity/logs/phase1a_%j.log
#SBATCH --job-name=chembl_fetch

# ===========================================================================
# Phase 1A: ChEMBL Pathogen Data Acquisition
# Fetches MIC bioactivity data for 4 pathogens from ChEMBL v34
# Runtime: ~30-60 min | CPU only | Network required
# ===========================================================================

echo "=== Phase 1A started at $(date) ==="
echo "Node: $(hostname) | Job ID: $SLURM_JOB_ID | CPUs: $SLURM_NTASKS"

source ~/antibiotic-selectivity/venv/bin/activate
cd ~/antibiotic-selectivity
export ANTIBIOTIC_PROJECT_DIR=~/antibiotic-selectivity
export ANTIBIOTIC_DATA_MODE=real
export ANTIBIOTIC_RUN_ID="${ANTIBIOTIC_RUN_ID:-current}"

# Try restoring from ZIP bundles first (avoids ChEMBL download)
python scripts/restore_data.py || true

python scripts/01_fetch_chembl.py

EXIT_CODE=$?
echo "=== Phase 1A finished at $(date) with exit code $EXIT_CODE ==="
exit $EXIT_CODE
