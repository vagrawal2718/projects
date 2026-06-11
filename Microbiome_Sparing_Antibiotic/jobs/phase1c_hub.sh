#!/bin/bash
#SBATCH --partition=u22
#SBATCH -A research
## SBATCH --qos=low
#SBATCH -n 2
#SBATCH --mem-per-cpu=2G
#SBATCH --time=0:30:00
#SBATCH --output=/home2/%u/antibiotic-selectivity/logs/phase1c_%j.log
#SBATCH --job-name=hub_fetch

# ===========================================================================
# Phase 1C: Drug Repurposing Hub Download and Cleaning
# Downloads from S3 direct link, cleans SMILES via RDKit
# Runtime: <5 min | CPU only | Network required
# ===========================================================================

echo "=== Phase 1C started at $(date) ==="
echo "Node: $(hostname) | Job ID: $SLURM_JOB_ID | CPUs: $SLURM_NTASKS"

source ~/antibiotic-selectivity/venv/bin/activate
cd ~/antibiotic-selectivity
export ANTIBIOTIC_PROJECT_DIR=~/antibiotic-selectivity
export ANTIBIOTIC_DATA_MODE=real
export ANTIBIOTIC_RUN_ID="${ANTIBIOTIC_RUN_ID:-current}"

# Try restoring from ZIP bundles first
python scripts/restore_data.py || true

python scripts/03_fetch_repurposing_hub.py

EXIT_CODE=$?
echo "=== Phase 1C finished at $(date) with exit code $EXIT_CODE ==="
exit $EXIT_CODE
