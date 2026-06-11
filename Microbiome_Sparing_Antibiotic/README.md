# Microbiome-Sparing Antibiotic Discovery Pipeline

**Author:** Vishakha Agrawal, IIIT Hyderabad
**Course:** Machine Learning for Natural Sciences (MLNS), Spring 2026

## Overview

A multi-architecture consensus pipeline for discovering antibiotics that kill
pathogens while sparing beneficial gut bacteria. Five architecturally diverse
models jointly predict pathogen activity and commensal harm from molecular
structure, integrated through a selectivity score:

```
S = P_pathogen x (1 - P_gut)
```

where `P_pathogen` is the predicted probability of pathogen inhibition and
`P_gut` is the predicted probability of commensal harm. A compound receives
high S only if it is simultaneously predicted to kill the target pathogen
and spare gut commensals.

The motivation comes from Stokes et al. (Cell, 2020), who noted in their
discussion that training across phylogenetically diverse species may make it
possible to predict narrow-spectrum agents that can be administered without
damaging the host microbiota.

## Key Numbers

- **108,625** pathogen training instances across 4 WHO-priority pathogens
- **1,177** gut commensal compounds from the Maier et al. screen (40 gut strains)
- **6,739** Drug Repurposing Hub compounds screened
- **5** architecturally diverse models, **210** trained models total
- **60** selectivity-ranked screening lists (5 models x 4 pathogens x 3 thresholds)
- **890** consensus candidate compounds, 3 with unanimous 5/5 model agreement
- **66** interactive HTML visualizations

## Models

| Model | Input | Parameters | Description |
|-------|-------|------------|-------------|
| Random Forest | 2,048-bit Morgan FP (ECFP4) | 500 trees | Baseline, best-calibrated |
| D-MPNN | Molecular graph | ~200K | Chemprop v2.2.2 |
| CheMeleon (frozen) | Molecular graph | ~615K trainable | Pretrained D-MPNN encoder, frozen backbone |
| MoLFormer-XL | SMILES string | ~47M | Pretrained transformer, fine-tuned |
| D-MPNN+RDKit | Graph + 200 descriptors | ~3.4M | Follows the Stokes et al. architecture |

Each model is trained independently on identical 5-fold Bemis-Murcko scaffold
splits across 7 binary classification tasks (4 pathogen + 3 gut harm thresholds).

## Pathogens

| Key | Organism | N | Active % | Clinical relevance |
|-----|----------|---|----------|-------------------|
| ecoli | *E. coli* | 28,284 | 32.7% | Urinary tract infections |
| saureus | *S. aureus* | 43,853 | 43.9% | Skin/soft tissue, MRSA |
| paeruginosa | *P. aeruginosa* | 17,783 | 26.2% | Hospital-acquired pneumonia |
| mtb | *M. tuberculosis* | 18,705 | 43.5% | Tuberculosis |

## Data Sources

- **ChEMBL 34**: MIC assay data for pathogen activity (REST API)
- **Maier et al. (Nature, 2018; Nature, 2021)**: Commensal growth inhibition screen
  (40 gut strains x 1,197 compounds, 24 supplementary Excel files)
- **Drug Repurposing Hub** (Corsello et al., Nature Medicine, 2017): Screening
  library of 6,739 compounds spanning Launched through Preclinical stages

## Data Roles

| Role | Data | N | Purpose |
|------|------|---|---------|
| Training | ChEMBL MIC (4 pathogens) + Maier gut harm (3 thresholds) | 108,625 + 1,177 | Learn structure-activity relationships |
| Internal validation | 5-fold Bemis-Murcko scaffold CV (held-out fold per split) | 20% per fold | Estimate generalization; all reported ROC-AUC values are CV means |
| External screening | Drug Repurposing Hub (never seen during training) | 6,739 | Selectivity-ranked candidate lists |
| External validation | Stokes et al. lab scores, halicin case, known drug spectra | 4,343 + 1 + 14 | Independent check against published experimental data |

## Quick Start

### Ada HPC (IIIT Hyderabad)

```bash
bash ada_full_setup.sh            # one-time environment setup
bash run_ada.sh                   # interactive run
bash run_batch.sh                 # SLURM batch submission
```

### Ubuntu/Debian

```bash
bash setup_ubuntu.sh --install-system
bash run_ubuntu.sh --real-data
```

### macOS

```bash
bash setup_mac.sh
bash run_mac.sh --real-data
```

## Python Version

Python >= 3.12 required. On Ada HPC, load via `module load u22/python/3.12.4`.
All setup scripts enforce this minimum.

## Pipeline Phases

| Phase | Script(s) | Description |
|-------|-----------|-------------|
| 1A | `01_fetch_chembl.py` | Fetch pathogen MIC data from ChEMBL 34 |
| 1B | `02_process_maier.py` | Process Maier commensal screen (xlsx to CSV with SMILES) |
| 1C | `03_fetch_repurposing_hub.py` | Fetch and clean Drug Repurposing Hub |
| 2 | `04_compute_morgan_fps.py` | Compute Morgan fingerprints, prepare model inputs |
| 3A | `05_train_rf.py` | Train Random Forest (5-fold scaffold CV + final) |
| 3B | `06_train_dmpnn.py` | Train D-MPNN via Chemprop v2 |
| 3C | `09_train_chemeleon.py` / `11_train_chemeleon_frozen.py` | Train CheMeleon frozen encoder |
| 3D | `10_train_molformer.py` | Fine-tune MoLFormer-XL |
| 3E | `20_retrain_dmpnn_rdkit.py` | Train D-MPNN+RDKit (Stokes architecture) |
| 4 | `07_evaluate.py` | Screen Hub, compute selectivity scores, 5 statistical tests |
| 5 | `12_compare_models.py` | Cross-model comparison (full metrics, pairwise correlation) |
| 6 | `13_candidate_report.py` | Build consensus, identify top candidates |
| 7 | `14_external_benchmark.py` / `17_external_benchmark_comparison.py` | Stokes correlation, halicin case, known drugs |
| 8 | `18_diagnostic_analysis.py` | Disagreement analysis, property diagnostics |
| 9 | `19_interpretability.py` | RF importance, MoLFormer attention, BRICS occlusion |
| 10 | `22_dataset_analysis.py` | Dataset statistics, distribution plots, overlap analysis |
| 11 | `08_create_showcase.py` | Generate 66 interactive visualizations |

Supporting scripts: `15_backfill_full_metrics.py` (backfill missing CV metrics),
`16_interim_report.py` (interim summary), `21_consolidated_report.py` (final report),
`23_uncertainty_and_adjustment.py` (RF uncertainty estimation).

## Multi-Model Consensus

For each of the 60 ranked lists, the top-50 compounds by S are selected.
A compound's consensus tier is the number of models (out of 5) that
independently place it in their top-50 for any pathogen-threshold combination.

Tier distribution: 3 at 5/5, 9 at 4/5, 40 at 3/5, 183 at 2/5, 655 at 1/5.

## Validation

- **Cross-validation**: 5-fold Bemis-Murcko scaffold CV. RF achieves 0.811-0.877
  ROC-AUC on pathogen tasks.
- **External (Stokes et al.)**: Spearman rho = 0.363 (RF) against 4,343
  Stokes lab-scored compounds.
- **Halicin case study**: S < 0.13 across all models for this known
  broad-spectrum antibiotic, consistent with the selectivity framework.
- **Known drug validation**: Narrow-spectrum drugs (daptomycin, fidaxomicin,
  methenamine, nitrofurantoin) receive higher mean S than broad-spectrum drugs
  (amoxicillin, ciprofloxacin, chloramphenicol, clindamycin, doxycycline,
  rifabutin) across RF, CheMeleon, and MoLFormer.

## Visualizations

All 66 interactive HTML visualizations are deployed at:
https://web.iiit.ac.in/~vishakha.agrawal/viz/other/mlns/

## Repository Structure

```
2023101040_MLNS_CourseProject/
├── scripts/
│   ├── 00_verify_environment.py      # Dependency checker
│   ├── 01_fetch_chembl.py            # Phase 1A: ChEMBL pathogen data
│   ├── 02_process_maier.py           # Phase 1B: Maier commensal screen
│   ├── 03_fetch_repurposing_hub.py   # Phase 1C: Broad Hub
│   ├── 04_compute_morgan_fps.py      # Phase 2: Morgan fingerprints
│   ├── 05_train_rf.py                # Phase 3A: Random Forest
│   ├── 06_train_dmpnn.py             # Phase 3B: D-MPNN
│   ├── 07_evaluate.py                # Phase 4: Evaluation suite
│   ├── 08_create_showcase.py         # Visualization generation
│   ├── 09_train_chemeleon.py         # Phase 3C: CheMeleon
│   ├── 10_train_molformer.py         # Phase 3D: MoLFormer-XL
│   ├── 11_train_chemeleon_frozen.py  # Phase 3C: Frozen-encoder variant
│   ├── 12_compare_models.py          # Cross-model comparison
│   ├── 13_candidate_report.py        # Consensus candidate report
│   ├── 14_external_benchmark.py      # External validation (Stokes, halicin)
│   ├── 15_backfill_full_metrics.py   # Backfill missing metrics
│   ├── 16_interim_report.py          # Interim summary
│   ├── 17_external_benchmark_comparison.py  # Extended Stokes analysis
│   ├── 18_diagnostic_analysis.py     # Disagreement and property diagnostics
│   ├── 19_interpretability.py        # RF importance, attention, BRICS
│   ├── 20_retrain_dmpnn_rdkit.py     # Phase 3E: D-MPNN+RDKit
│   ├── 21_consolidated_report.py     # Final consolidated report
│   ├── 22_dataset_analysis.py        # Dataset statistics and plots
│   ├── 23_uncertainty_and_adjustment.py  # RF uncertainty estimation
│   ├── config.py                     # All hyperparameters and paths
│   ├── run_pipeline.py               # Orchestrator
│   ├── restore_data.py               # Restore data from backup
│   ├── test_local.py                 # Local test runner
│   └── utils/
│       ├── gdrive_backup.py          # DataManager (4-tier priority chain)
│       ├── scaffold_split.py         # Bemis-Murcko splitter
│       ├── smiles_utils.py           # SMILES canonicalization
│       ├── data_cache.py             # File integrity cache
│       ├── network_utils.py          # Retry-aware HTTP
│       ├── diagnostics.py            # System diagnostics
│       ├── logging_utils.py          # Structured logging
│       ├── viz_utils.py              # Shared plot helpers
│       ├── full_metrics.py           # Extended metric computation
│       ├── alternative_data.py       # Fallback data sources
│       └── __init__.py
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
│   │           ├── screening/        # 60+ ranked CSVs + raw predictions
│   │           └── reports/          # Quality report JSONs
│   └── shared/
│       ├── features/                 # Morgan FP .npz + index .json (6 datasets)
│       └── splits/                   # Scaffold fold .pkl (5 datasets)
├── Report/
│   ├── report.tex                    # LaTeX source
│   ├── references.bib                # BibTeX
│   └── NarrowSpectrum_final.pdf      # Compiled report
├── jobs/                             # SLURM job scripts (phases 1a-4)
├── logs/                             # Run logs (20 files)
├── resources/
│   └── maier/                        # Backup copy of Maier xlsx files
├── ada_full_setup.sh                 # One-time Ada environment setup
├── run_ada.sh                        # Interactive Ada run
├── run_batch.sh                      # SLURM batch submission
├── run_all.sh                        # Submit all SLURM jobs
├── run_ubuntu.sh                     # Ubuntu run
├── run_mac.sh                        # macOS run
├── setup_ubuntu.sh                   # Ubuntu setup
├── setup_mac.sh                      # macOS setup
├── setup_rclone_gdrive.sh            # Google Drive rclone setup
├── backup_to_drive.sh                # Backup to Google Drive
├── collect_and_archive.sh            # Archive outputs
├── job_manager.sh                    # SLURM job management utility
├── reconstitute.sh                   # Reconstitute repo from export
├── requirements.txt                  # Python dependencies
├── requirements_aidp.txt             # AIDP-specific dependencies
├── README.md
└── WORKFLOW.md
```

## Trained Models (not in this repository)

The 210 trained model weights (24 GB total) exceed GitHub file size limits
and are excluded. They are available in the backup on Google Drive.

To retrain from scratch:
```bash
bash run_ada.sh        # on Ada HPC
bash run_ubuntu.sh     # on Ubuntu with GPU
```

## Computing Infrastructure

All training and inference were performed on the Ada HPC cluster at IIIT
Hyderabad (partition u22) using NVIDIA GeForce RTX 2080 Ti GPUs (11 GB),
managed via SLURM. PyTorch 2.4.1, CUDA 11.8.

## References

1. Stokes et al. "A deep learning approach to antibiotic discovery." Cell 180(4):688-702, 2020.
2. Liu et al. "Deep learning-guided discovery of an antibiotic targeting A. baumannii." Nature Chemical Biology 19(11):1342-1350, 2023.
3. Wong et al. "Discovery of a structural class of antibiotics with explainable deep learning." Nature 626:177-185, 2024.
4. Maier et al. "Extensive impact of non-antibiotic drugs on human gut bacteria." Nature 555:623-628, 2018.
5. Maier et al. "Unravelling the collateral damage of antibiotics on gut bacteria." Nature 599:120-124, 2021.
6. Corsello et al. "The Drug Repurposing Hub." Nature Medicine 23(4):405-408, 2017.
7. Yang et al. "Analyzing learned molecular representations for property prediction." JCIM 59(8):3370-3388, 2019.

## License

Academic use. ChEMBL data is licensed under CC BY-SA 3.0.
Maier et al. data is from Nature supplementary materials.
Drug Repurposing Hub data is publicly available.