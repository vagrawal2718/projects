#!/bin/bash
#SBATCH --partition=u22
#SBATCH -A research
## SBATCH --qos=low
#SBATCH -n 10
#SBATCH --gres=gpu:1
#SBATCH --mem-per-cpu=2G
#SBATCH --time=4:00:00
#SBATCH --output=/home2/%u/antibiotic-selectivity/logs/phase3b_%j.log
#SBATCH --job-name=dmpnn_train

# ===========================================================================
# Phase 3B: D-MPNN Pipeline Training (Chemprop v2)
# Trains 7 D-MPNN models on GPU, screens Hub
# Runtime: ~30-60 min | 1x GTX 1080 Ti (11 GB) | No network
# ===========================================================================

echo "=== Phase 3B started at $(date) ==="
echo "Node: $(hostname) | Job ID: $SLURM_JOB_ID | CPUs: $SLURM_NTASKS"
nvidia-smi

source ~/antibiotic-selectivity/venv/bin/activate
cd ~/antibiotic-selectivity
export ANTIBIOTIC_PROJECT_DIR=~/antibiotic-selectivity
export ANTIBIOTIC_DATA_MODE=real
export ANTIBIOTIC_RUN_ID="${ANTIBIOTIC_RUN_ID:-current}"

# Try restoring from ZIP bundles first
python scripts/restore_data.py || true

python scripts/06_train_dmpnn.py

EXIT_CODE=$?
echo "=== Phase 3B finished at $(date) with exit code $EXIT_CODE ==="
exit $EXIT_CODE
