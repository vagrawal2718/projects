#!/bin/bash
#SBATCH --partition=u22
#SBATCH -A research
## SBATCH --qos=low
#SBATCH -n 4
#SBATCH --mem-per-cpu=2G
#SBATCH --time=1:00:00
#SBATCH --output=/home2/%u/antibiotic-selectivity/logs/phase1b_%j.log
#SBATCH --job-name=maier_proc

# ===========================================================================
# Phase 1B: Maier Commensal Harm Data Processing
# Extracts n_hit labels, maps to SMILES via STITCH/PubChem
# Runtime: ~15-30 min | CPU only | Network required (PubChem API)
# ===========================================================================

echo "=== Phase 1B started at $(date) ==="
echo "Node: $(hostname) | Job ID: $SLURM_JOB_ID | CPUs: $SLURM_NTASKS"

source ~/antibiotic-selectivity/venv/bin/activate
cd ~/antibiotic-selectivity
export ANTIBIOTIC_PROJECT_DIR=~/antibiotic-selectivity
export ANTIBIOTIC_DATA_MODE=real
export ANTIBIOTIC_RUN_ID="${ANTIBIOTIC_RUN_ID:-current}"

# Try restoring from ZIP bundles first
python scripts/restore_data.py || true

python scripts/02_process_maier.py

EXIT_CODE=$?
echo "=== Phase 1B finished at $(date) with exit code $EXIT_CODE ==="
exit $EXIT_CODE
