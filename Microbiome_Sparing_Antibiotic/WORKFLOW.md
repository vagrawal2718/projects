# Microbiome-Sparing Antibiotic Discovery: Implementation Workflow

**Project:** Multi-Architecture Consensus for Selectivity-Based Antibiotic Discovery
**Author:** Vishakha Agrawal, IIIT Hyderabad
**Compute:** Ada HPC cluster (IIITH), partition u22, RTX 2080 Ti GPUs
**Date:** March-May 2026

---

## Table of Contents

1. Project Overview
2. Five Models, One Framework
3. Data Sources and Verified Numbers
4. Ada Environment Setup
5. Phase 1: Data Acquisition
6. Phase 2: Feature Engineering and Input Preparation
7. Phase 3: Model Training (5 Architectures)
8. Phase 4: Screening, Selectivity Scoring, and Consensus
9. Phase 5: External Validation
10. Phase 6: Interpretability Analysis
11. Phase 7: Visualization
12. File Structure
13. Compute Configuration and SLURM Reference
14. Execution Summary

---

## 1. Project Overview

This pipeline trains five architecturally diverse binary classifiers on seven
tasks (4 pathogens + 3 gut harm thresholds), screens the Drug Repurposing Hub,
and integrates predictions via a selectivity score:

```
S = P_pathogen x (1 - P_gut)
```

The motivation comes directly from the Stokes et al. (Cell, 2020) discussion,
which noted that training across phylogenetically diverse species may make it
possible to predict narrow-spectrum agents that spare the host microbiota.

The primary contribution is the dual-objective integration and multi-architecture
consensus, not any single model. Predicting pathogen activity alone is
Stokes 2020. Predicting commensal harm alone is McCoubrey 2021 / Zheng 2019.
What this pipeline adds is: (i) combining both into a selectivity score,
(ii) scaling to 4 pathogens, (iii) using 5 diverse architectures, and
(iv) aggregating them into a multi-model consensus.

---

## 2. Five Models, One Framework

All five models are trained on identical data and identical 5-fold Bemis-Murcko
scaffold splits. Each produces independent P_pathogen and P_gut predictions for
every Hub compound, yielding 60 selectivity-ranked lists (5 x 4 x 3).

```
MODEL                        INPUT              PARAMS       ROLE
Random Forest                2048-bit Morgan FP  500 trees    Baseline (best calibrated)
D-MPNN (Chemprop v2)         Molecular graph     ~200K        Learned graph repr.
CheMeleon (frozen encoder)   Molecular graph     ~615K train  Pretrained graph encoder
MoLFormer-XL                 SMILES string       ~47M         Pretrained transformer
D-MPNN+RDKit                 Graph + 200 desc.   ~3.4M        Stokes architecture
```

Consensus: for each of the 60 lists, the top-50 compounds are selected.
A compound's tier = number of models (out of 5) placing it in any top-50.
890 unique compounds appear; 3 achieve 5/5 agreement.

---

## 3. Data Sources and Verified Numbers

All numbers below verified against Ada data files (May 2026).

### Pathogen training data (ChEMBL 34, REST API)

| Pathogen | N | Active | % | Median MW |
|----------|---|--------|---|-----------|
| E. coli | 28,284 | 9,249 | 32.7% | 437 Da |
| S. aureus | 43,853 | 19,267 | 43.9% | 443 Da |
| P. aeruginosa | 17,783 | 4,657 | 26.2% | 446 Da |
| M. tuberculosis | 18,705 | 8,129 | 43.5% | 391 Da |
| **Total** | **108,625** | **41,302** | | |
| Unique SMILES | **67,155** | | | |

Activity threshold: MIC <= 10,000 nM (10 uM). Only standard_type = 'MIC',
valid units (nM or ug/mL), relations (=, <=, <). Median of replicates.

### Gut commensal harm data (Maier et al., Nature 2018 + 2021)

- 1,177 compounds after SMILES canonicalization and deduplication
- 40 gut bacterial strains (19 Firmicutes, 12 Bacteroidetes, 4 Actinobacteria,
  3 Proteobacteria, 1 Verrucomicrobia, 1 Fusobacteria)
- Binary harm labels at three thresholds:

| Threshold | Harmful | % |
|-----------|---------|---|
| t >= 5 | 233 | 19.8% |
| t >= 10 | 179 | 15.2% |
| t >= 20 | 127 | 10.8% |

### Screening library (Drug Repurposing Hub)

- 6,739 compounds total
- Launched: 2,393 / Preclinical: 2,297 / Phase 2: 810 / Phase 1: 565 /
  Phase 3: 450 / Withdrawn: 95
- Hub-Maier overlap: 478 compounds
- Hub-pathogen overlaps: 147 (MTB) to 314 (S. aureus)

### Data roles

| Role | Data | N | Purpose |
|------|------|---|---------|
| Training | ChEMBL MIC (4 pathogens) + Maier gut harm (3 thresholds) | 108,625 + 1,177 | Learn structure-activity relationships |
| Internal validation | 5-fold Bemis-Murcko scaffold CV (held-out fold per split) | 20% per fold | Estimate generalization; all reported ROC-AUC values are CV means |
| External screening | Drug Repurposing Hub (never seen during training) | 6,739 | Selectivity-ranked candidate lists |
| External validation | Stokes et al. lab scores, halicin case, known drug spectra | 4,343 + 1 + 14 | Independent check against published experimental data |

---

## 4. Ada Environment Setup

### One-time setup

```bash
cd /scratch/$USER
git clone <repo-url> antibiotic-selectivity-v2
cd antibiotic-selectivity-v2
bash ada_full_setup.sh
```

This creates a Python 3.12 virtual environment and installs all dependencies
from requirements.txt, including Chemprop v2.2.2, PyTorch 2.4.1, RDKit,
scikit-learn, and MoLFormer dependencies.

### Python version

Python >= 3.12 required. On Ada: `module load u22/python/3.12.4`.

### Maier supplementary data

The 24 Maier xlsx files are included in `data/maier/`. They were downloaded
from the Nature supplementary materials for Maier et al. 2018 and 2021.

---

## 5. Phase 1: Data Acquisition

### Phase 1A: ChEMBL pathogen data

Fetches MIC bioactivity data for 4 pathogens from ChEMBL 34 via REST API.
Query logic: target_type = 'ORGANISM', standard_type = 'MIC', valid units,
deduplicate by canonical SMILES (median of replicates), binary label at 10 uM.

Output: `data/chembl/{ecoli,saureus,paeruginosa,mtb}_activity.csv`

### Phase 1B: Maier commensal harm processing

Extracts n_hit labels from Maier 2018 MOESM5 (adjusted p-values for 1,197
drugs x 40 strains), maps compound names to SMILES via PubChem, constructs
binary harm labels at t = 5, 10, 20.

Output: `data/maier/maier_combined.csv`, `data/dmpnn_input/gut_{t5,t10,t20}.csv`

### Phase 1C: Drug Repurposing Hub

Downloads and cleans the Broad Hub, extracts SMILES, names, clinical phases,
mechanisms of action.

Output: `data/repurposing_hub/repurposing_hub_clean.csv`

---

## 6. Phase 2: Feature Engineering and Input Preparation

- Computes 2,048-bit Morgan fingerprints (ECFP4, radius 2) via RDKit for all
  compounds across all datasets. Zero failures on 116,541 compounds.
- Prepares model-specific input CSVs:
  - `data/dmpnn_input/` : (smiles, label) format for Chemprop and RF
  - `data/chemeleon_input/` : same format for CheMeleon
  - `data/dmpnn_input/hub_screen.csv` : Hub SMILES for screening
- Generates 5-fold Bemis-Murcko scaffold splits, saved and reused by all models.

---

## 7. Phase 3: Model Training (5 Architectures)

Total: 7 tasks x 6 models (5 CV folds + 1 final) x 5 architectures = 210 models.

### Phase 3A: Random Forest

- 500 decision trees, balanced class weighting, sqrt(2048) ~ 45 features per split
- CPU only (scikit-learn), sizes 6 MB (gut) to 383 MB (S. aureus)
- Best ROC-AUC on all 4 pathogen tasks (0.811-0.877)

### Phase 3B: D-MPNN (Chemprop v2)

- Depth 3, hidden 300, dropout 0.1, ~200K params
- Single RTX 2080 Ti per task

### Phase 3C: CheMeleon (frozen encoder)

- Pretrained D-MPNN encoder (8.7M params) frozen; only 615K-param classification
  head trained. Prevents catastrophic forgetting on the 1,177-compound gut dataset.
- All 7 tasks completed in 26 minutes total.

### Phase 3D: MoLFormer-XL

- 47M-param BERT-style transformer, pretrained on 1.1B SMILES
- All layers fine-tuned. 170 MB per checkpoint. Largest and most expensive model.
- Single RTX 2080 Ti per task

### Phase 3E: D-MPNN+RDKit

- Follows Stokes et al. architecture: depth 5, hidden 1600, dropout 0.35,
  200 RDKit 2D descriptors concatenated with graph embedding
- ~3.4M params, 124 MB per checkpoint
- 3 GPUs in parallel (2x RTX 2080 Ti + 1x RTX 4070)

---

## 8. Phase 4: Screening, Selectivity Scoring, and Consensus

For each of the 210 final models, screen all 6,739 Hub compounds:
- Predict P_pathogen (from pathogen model) and P_gut (from gut model)
- Compute S = P_pathogen x (1 - P_gut)
- Rank all Hub compounds by S

Produces 60 ranked CSV files (5 models x 4 pathogens x 3 thresholds) plus
21 raw prediction CSVs. Total screening time: 37.5 seconds.

### Calibration analysis

RF distributes scores across [0,1] (only 14 at S < 0.01). D-MPNN shows
probability saturation (4,153 at S < 0.01, 61.6%). D-MPNN+RDKit reduces
this to 212 (3.1%), a 95% reduction.

### Multi-model consensus

Top-50 per list selected. Tier = number of models placing compound in any
top-50 across all pathogen-threshold combinations.

| Tier | Compounds |
|------|-----------|
| 5/5 | 3 (retapamulin, AFN-1252, trimetrexate) |
| 4/5 | 9 |
| 3/5 | 40 |
| 2/5 | 183 |
| 1/5 | 655 |
| **Total** | **890** |

58 known antibiotics (6.5%), 832 novel (93.5%).

---

## 9. Phase 5: External Validation

### Stokes correlation

4,343 Hub compounds overlap with Stokes et al. Table S2 (D-MPNN scores).
616 overlap with Stokes RF scores.

| Model | rho(Pp) | rho(S) | Gap |
|-------|---------|--------|-----|
| RF | 0.363 | 0.177 | 0.186 |
| D-MPNN+RDKit | 0.331 | 0.187 | 0.145 |
| MoLFormer | 0.261 | 0.189 | 0.072 |
| CheMeleon | 0.260 | 0.161 | 0.099 |
| D-MPNN | 0.235 | 0.154 | 0.081 |

RF-to-RF (616 compounds): rho(Pp) = 0.500.

### Halicin case study

Halicin (SU3327) receives S < 0.13 across all 5 models. RF decomposition:
Pp = 0.173, Pg = 0.509, S = 0.085. Consistent with halicin being a known
broad-spectrum antibiotic.

### Known drug validation

Narrow-spectrum drugs (daptomycin, fidaxomicin, methenamine, nitrofurantoin)
receive higher mean S than broad-spectrum drugs (amoxicillin, ciprofloxacin,
chloramphenicol, clindamycin, doxycycline, rifabutin) across RF, CheMeleon,
and MoLFormer.

---

## 10. Phase 6: Interpretability Analysis

- **RF feature importance**: Top 30 Morgan FP bits by Gini importance.
  Tertiary amine and heterocyclic substructures dominate.
- **MoLFormer self-attention**: Nitrogen atoms dominate attention in 12/15
  tier-3+ candidates. Compound-specific pharmacophore attention identified
  (macozinone thiazole S, GSK656 boron B, guadecitabine imidazole N).
- **BRICS occlusion**: All graph-based models produce non-decomposable
  predictions; activity is a holistic property of the complete molecular graph.

---

## 11. Phase 7: Visualization

66 interactive HTML visualizations generated and deployed at:
https://web.iiit.ac.in/~vishakha.agrawal/viz/other/mlns/

Categories: Overview (4), 3D Selectivity (7), Candidate Landscapes (20),
Candidate Scatters (20), Consensus (6), Model Comparison (2),
Ranked List Explorers (6), Diagnostics (1).

---

## 12. File Structure

```
2023101040_MLNS_CourseProject/
├── scripts/
│   ├── 00_verify_environment.py      # Dependency checker
│   ├── 01_fetch_chembl.py            # Phase 1A
│   ├── 02_process_maier.py           # Phase 1B
│   ├── 03_fetch_repurposing_hub.py   # Phase 1C
│   ├── 04_compute_morgan_fps.py      # Phase 2
│   ├── 05_train_rf.py                # Phase 3A
│   ├── 06_train_dmpnn.py             # Phase 3B
│   ├── 07_evaluate.py                # Phase 4
│   ├── 08_create_showcase.py         # Visualizations
│   ├── 09_train_chemeleon.py         # Phase 3C
│   ├── 10_train_molformer.py         # Phase 3D
│   ├── 11_train_chemeleon_frozen.py  # Phase 3C frozen variant
│   ├── 12_compare_models.py          # Cross-model comparison
│   ├── 13_candidate_report.py        # Consensus candidates
│   ├── 14_external_benchmark.py      # External validation
│   ├── 15_backfill_full_metrics.py   # Backfill metrics
│   ├── 16_interim_report.py          # Interim summary
│   ├── 17_external_benchmark_comparison.py  # Extended Stokes
│   ├── 18_diagnostic_analysis.py     # Diagnostics
│   ├── 19_interpretability.py        # RF, attention, BRICS
│   ├── 20_retrain_dmpnn_rdkit.py     # Phase 3E
│   ├── 21_consolidated_report.py     # Final report
│   ├── 22_dataset_analysis.py        # Dataset statistics
│   ├── 23_uncertainty_and_adjustment.py  # RF uncertainty
│   ├── config.py                     # Hyperparameters and paths
│   ├── run_pipeline.py               # Orchestrator
│   └── utils/                        # Shared utilities
├── data/
│   ├── chembl/                       # Raw ChEMBL pathogen CSVs (4 files)
│   ├── dmpnn_input/                  # Training CSVs: smiles, label (8 files)
│   ├── chemeleon_input/              # CheMeleon-format CSVs (8 files)
│   ├── maier/                        # Maier xlsx (24 files) + combined CSV
│   └── repurposing_hub/              # repurposing_hub_clean.csv
├── outputs/
│   ├── runs/
│   │   └── run_20260315_034033/
│   │       ├── checkpoints/          # Phase progress JSONs
│   │       └── results/
│   │           ├── *.json            # CV metrics, diagnostics, halicin
│   │           ├── *.csv             # Comparisons, Stokes, candidates
│   │           ├── figures/          # 66 HTML + PNG/PDF plots
│   │           └── screening/        # 60+ ranked CSVs + raw predictions
│   └── shared/
│       ├── features/                 # Morgan FP .npz + index .json
│       └── splits/                   # Scaffold fold .pkl
├── Report/
│   ├── report.tex                    # LaTeX source
│   ├── references.bib                # BibTeX
│   └── NarrowSpectrum_final.pdf      # Compiled report
├── jobs/                             # SLURM job scripts
├── logs/                             # Run logs
├── resources/maier/                  # Backup copy of Maier xlsx
├── requirements.txt
├── README.md
└── WORKFLOW.md
```

---

## 13. Compute Configuration and SLURM Reference

### Ada HPC configuration (verified March-May 2026)

| Parameter | Value |
|-----------|-------|
| Partition | u22 |
| Account | research |
| QoS | low |
| GPU hardware | NVIDIA GeForce RTX 2080 Ti (11 GB VRAM) |
| GPU pool also includes | RTX 4070 |
| PyTorch | 2.4.1, CUDA 11.8 |
| Python | 3.12.4 (module u22/python/3.12.4) |
| Storage | /scratch (large, shared across nodes) |

### SLURM header template (GPU jobs)

```bash
#!/bin/bash
#SBATCH --partition=u22
#SBATCH -A research
#SBATCH --qos=low
#SBATCH -n 10
#SBATCH --gres=gpu:1
#SBATCH --mem-per-cpu=2G
#SBATCH --time=4:00:00
#SBATCH --output=logs/<phase>_%j.log
#SBATCH --job-name=<name>

source /scratch/$USER/antibiotic-selectivity-v2/venv/bin/activate
cd /scratch/$USER/antibiotic-selectivity-v2
```

### SLURM commands

```bash
sbatch jobs/<phase>.sh          # Submit
squeue -u $USER                 # Check status
tail -f logs/<phase>_<jobid>.log  # Watch log
scancel <jobid>                 # Cancel
```

---

## 14. Execution Summary

| Phase | Description | GPU | Est. time |
|-------|-------------|-----|-----------|
| 1A | ChEMBL fetch | No | 30-60 min |
| 1B | Maier processing | No | 15-30 min |
| 1C | Hub download | No | 5 min |
| 2 | Feature engineering | No | 10-15 min |
| 3A | RF training | No | 30-90 min |
| 3B | D-MPNN training | 1x RTX 2080 Ti | 30-60 min |
| 3C | CheMeleon frozen | 1x RTX 2080 Ti | 26 min |
| 3D | MoLFormer fine-tune | 1x RTX 2080 Ti | 2-4 hours |
| 3E | D-MPNN+RDKit | 3 GPUs | 2-4 hours |
| 4 | Screening + consensus | No | 37.5 sec |
| 5 | External validation | No | 5-10 min |
| 6 | Interpretability | No | 10-15 min |
| 7 | Visualizations | No | 15-30 min |

Execution order:
```
1A -> 1B -> 1C -> 2 -> 3A/3B/3C/3D/3E (sequential) -> 4 -> 5 -> 6 -> 7
```

Total wall-clock time: approximately 8-12 hours.