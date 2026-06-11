# Dataset Report: Microbiome-Sparing Antibiotic Discovery Pipeline

**Generated:** 2026-04-09 13:12:16
**Source:** Dynamically computed from pipeline data (zero hardcoded values)

---

## 1. Overview

The pipeline trains binary classifiers on **7 tasks**: 4 pathogen activity tasks and 3 gut commensal harm thresholds. These models are combined to compute a selectivity score S = P_pathogen x (1 - P_gut) for each compound in a screening library.

Three categories of data are used:

1. **Pathogen activity data** from ChEMBL 34 MIC assays: 108,625 total compound-pathogen pairs across 4 organisms
2. **Gut commensal harm data** from Maier et al. (Nature, 2018/2021): 1,177 compounds screened against 40 representative human gut strains
3. **Screening library** from the Broad Institute Drug Repurposing Hub: 6,739 clinically annotated compounds scored by all trained models

## 2. Pathogen Activity Data (ChEMBL 34)

All pathogen activity data was extracted from the ChEMBL 34 database. Compounds were selected based on standardized MIC (Minimum Inhibitory Concentration) assay results against each target organism. Each compound's activity label was derived from the median MIC value across all available measurements: compounds with median MIC at or below 10,000 nM (10 uM) were labeled active (1), otherwise inactive (0).

### 2.1 Summary Statistics

| Pathogen | Compounds | Active | Active (%) | Inactive | Inactive (%) | Source |
|----------|-----------|--------|-----------|----------|-------------|--------|
| *E. coli* | 28,284 | 9,249 | 32.7% | 19,035 | 67.3% | MIC |
| *S. aureus* | 43,853 | 19,267 | 43.9% | 24,586 | 56.1% | MIC |
| *P. aeruginosa* | 17,783 | 4,657 | 26.2% | 13,126 | 73.8% | MIC |
| *M. tuberculosis* | 18,705 | 8,129 | 43.5% | 10,576 | 56.5% | MIC |

P. aeruginosa has the most imbalanced dataset (26.2% active), while S. aureus is closest to balanced (43.9% active). PR-AUC is a more informative metric than ROC-AUC for imbalanced tasks.

### 2.2 SMILES Length Statistics

| Dataset | Min | Median | Max | Mean |
|---------|-----|--------|-----|------|
| E. coli | 4 | 57 | 932 | 75 |
| S. aureus | 4 | 58 | 740 | 81 |
| P. aeruginosa | 4 | 57 | 801 | 77 |
| M. tuberculosis | 8 | 50 | 434 | 54 |

SMILES length serves as a rough proxy for molecular complexity.

### 2.3 Data Columns

Each pathogen CSV contains:

- `smiles` (object): 28,284 unique values
- `median_value_nM` (float64): 23,996 unique values
- `activity_label` (int64): 2 unique values
- `molecule_chembl_id` (object): 28,284 unique values
- `n_measurements` (int64): 90 unique values
- `source_type` (object): 1 unique values

### 2.4 Measurement Depth

| Pathogen | Compounds | Mean Measurements | Median Measurements |
|----------|-----------|-------------------|---------------------|
| E. coli | 28,284 | 2.0 | 1 |
| S. aureus | 43,853 | 2.5 | 1 |
| P. aeruginosa | 17,783 | 1.9 | 1 |
| M. tuberculosis | 18,705 | 1.9 | 1 |

## 3. Gut Commensal Harm Data (Maier et al., 2018/2021)

The gut commensal harm data comes from two studies by Maier et al. which systematically screened drugs from the Prestwick Chemical Library against representative human gut bacteria. Each drug was tested at a single, clinically relevant concentration (estimated intestinal concentration) against each bacterial strain. Growth inhibition was assessed by comparing optical density to untreated controls, and statistical significance was determined using adjusted p-values (p < 0.05). After PubChem SMILES lookup, 1,177 compounds with valid molecular structures remain.

### 3.1 Binary Harm Labels

The variable `n_hit` records the number of strains (out of 40) significantly inhibited by each compound. Binary labels are assigned at three thresholds (defined in `config.py: HARM_THRESHOLDS = [5, 10, 20]`):

| Threshold | Meaning | Harmful | Safe | Harmful (%) | Use Case |
|-----------|---------|---------|------|------------|----------|
| t=5 | Harms 5+ of 40 strains (12%+) | 233 | 944 | 19.8% | Some microbiome impact |
| t=10 | Harms 10+ of 40 strains (25%+) | 179 | 998 | 15.2% | Substantial microbiome damage |
| t=20 | Harms 20+ of 40 strains (50%+) | 127 | 1,050 | 10.8% | Severe microbiome devastation |

### 3.2 Strains Harmed Distribution (n_hit)

| Statistic | Value |
|-----------|-------|
| Mean | 4.7 |
| Median | 0 |
| Std | 10.5 |
| Max | 40 |
| Zero harm (n_hit = 0) | 780 (66.3%) |
| Harm exactly 1 strain | 88 (7.5%) |
| Harm 2 to 4 strains | 76 (6.5%) |
| Harm all 40 strains | 11 |

Compounds harming all 40 strains:

- Rifabutin (antibiotics)
- Doxycycline hydrochloride (antibiotics)
- Chlortetracycline hydrochloride (antibiotics)
- Tosufloxacin hydrochloride (antibiotics)
- Chloramphenicol (antibiotics)
- Minocycline hydrochloride (antibiotics)
- Meclocycline sulfosalicylate (antibiotics)
- Demeclocycline hydrochloride (antibiotics)
- Methacycline hydrochloride (antibiotics)
- Chlorhexidine (antiseptics)
- Florfenicol (vet: anti-infectives)

### 3.3 Drug Class Distribution

| Drug Class | Count | Percentage | Mean n_hit | Harm>=1 (%) |
|------------|-------|-----------|-----------|------------|
| human-targeted drugs | 819 | 69.6% | 1.4 | 24.7% |
| antibiotics | 142 | 12.1% | 21.5 | 77.5% |
| non-drugs | 87 | 7.4% | 0.7 | 12.6% |
| antifungals | 27 | 2.3% | 9.0 | 55.6% |
| antivirals | 22 | 1.9% | 2.2 | 40.9% |
| antiprotozoals | 20 | 1.7% | 10.6 | 65.0% |
| antiparasitics | 18 | 1.5% | 6.6 | 55.6% |
| vet: anti-infectives | 12 | 1.0% | 22.2 | 75.0% |
| antiseptics | 12 | 1.0% | 28.2 | 91.7% |
| vet: antiparasitics | 11 | 0.9% | 7.8 | 45.5% |
| vet: animal-targeted drugs | 7 | 0.6% | 2.1 | 28.6% |

### 3.4 Antibiotics vs Non-Antibiotics

| Group | N | Mean n_hit | Harm >= 1 strain | Harm >= 1 (%) |
|-------|---|-----------|------------------|--------------|
| Antibiotics | 142 | 21.5 | 110 | 77.5% |
| Non-antibiotics | 1,035 | 2.4 | 287 | 27.7% |
| Human-targeted drugs only | 819 | 1.4 | 202 | 24.7% |

24.7% of human-targeted (non-antibiotic) drugs inhibit at least one gut bacterial strain. This finding from Maier et al. (2018) demonstrates that gut microbiome damage is not limited to antibiotics and motivates training gut harm models on the full diversity of drug-gut interactions rather than antibiotics alone.

### 3.5 The 40 Gut Bacterial Strains

The strains span 18 Gram-negative and 22 Gram-positive species, representing the phylogenetic and functional diversity of the human gut microbiome.

| # | Species | Strain ID | Gram | Drugs Causing Inhibition |
|---|---------|-----------|------|-------------------------|
| 1 | *Eubacterium rectale* | NT5009 | positive | 236 |
| 2 | *Roseburia intestinalis* | NT5011 | positive | 234 |
| 3 | *Bacteroides vulgatus* | NT5001 | negative | 221 |
| 4 | *Blautia obeum* | NT5069 | positive | 214 |
| 5 | *Coprococcus comes* | NT5048 | positive | 214 |
| 6 | *Clostridium perfringens* | NT5032 | positive | 202 |
| 7 | *Ruminococcus torques* | NT5047 | positive | 198 |
| 8 | *Bacteroides uniformis* | NT5002 | negative | 197 |
| 9 | *Prevotella copri* | NT5019 | negative | 196 |
| 10 | *Eubacterium eligens* | NT5075 | positive | 193 |
| 11 | *Parabacteroides distasonis* | NT5074 | negative | 192 |
| 12 | *Parabacteroides merdae* | NT5071 | negative | 191 |
| 13 | *Collinsella aerofaciens* | NT5073 | positive | 190 |
| 14 | *Ruminococcus gnavus* | NT5046 | positive | 185 |
| 15 | *Bacteroides fragilis* | NT5003 | negative | 180 |
| 16 | *Odoribacter splanchnicus* | NT5081 | negative | 178 |
| 17 | *Roseburia hominis* | NT5079 | positive | 177 |
| 18 | *Ruminococcus bromii* | NT5045 | positive | 175 |
| 19 | *Dorea formicigenerans* | NT5076 | positive | 169 |
| 20 | *Bacteroides ovatus* | NT5054 | negative | 160 |
| 21 | *Bacteroides fragilis* | NT5033 | negative | 154 |
| 22 | *Bacteroides caccae* | NT5050 | negative | 153 |
| 23 | *Clostridium difficile* | NT5083 | positive | 152 |
| 24 | *Streptococcus salivarius* | NT5038 | positive | 152 |
| 25 | *Bacteroides thetaiotaomicron* | NT5004 | negative | 150 |
| 26 | *Veillonella parvula* | NT5017 | negative | 148 |
| 27 | *Clostridium saccharolyticum* | NT5037 | positive | 147 |
| 28 | *Eggerthella lenta* | NT5024 | positive | 144 |
| 29 | *Streptococcus parasanguinis* | NT5072 | positive | 143 |
| 30 | *Bifidobacterium longum* | NT5028 | positive | 137 |
| 31 | *Clostridium ramosum* | NT5006 | positive | 137 |
| 32 | *Bifidobacterium adolescentis* | NT5022 | positive | 133 |
| 33 | *Lactobacillus paracasei* | NT5042 | positive | 133 |
| 34 | *Clostridium bolteae* | NT5026 | positive | 131 |
| 35 | *Fusobacterium nucleatum* | NT5025 | negative | 123 |
| 36 | *Bacteroides xylanisolvens* | NT5064 | negative | 121 |
| 37 | *Akkermansia muciniphila* | NT5021 | negative | 117 |
| 38 | *Escherichia coli IAI1* | NT5077 | negative | 94 |
| 39 | *Escherichia coli ED1a* | NT5078 | negative | 90 |
| 40 | *Bilophila wadsworthia* | NT5036 | negative | 81 |

Most sensitive strain: *Eubacterium rectale* (236 drugs cause inhibition). Least sensitive: *Bilophila wadsworthia* (81 drugs).

### 3.6 Taxonomic Representation

| Phylum | Strains |
|--------|---------|
| Bacillota | 19 |
| Bacteroidota | 12 |
| Actinomycetota | 4 |
| Pseudomonadota | 3 |
| Verrucomicrobiota | 1 |
| Fusobacteriota | 1 |

## 4. Screening Library (Drug Repurposing Hub)

The Broad Institute Drug Repurposing Hub is a curated collection of clinically annotated compounds. After cleaning (removing entries without valid SMILES, deduplication), 6,739 compounds remain.

35.5% of compounds (2,393) are already launched drugs, meaning top-ranked selective candidates could potentially be repurposed without full de novo drug development.

### 4.1 Clinical Phase Distribution

| Phase | Count | Percentage |
|-------|-------|-----------|
| Launched | 2,393 | 35.5% |
| Phase 3 | 450 | 6.7% |
| Phase 2/Phase 3 | 44 | 0.7% |
| Phase 2 | 810 | 12.0% |
| Phase 1/Phase 2 | 85 | 1.3% |
| Phase 1 | 565 | 8.4% |
| Preclinical | 2,297 | 34.1% |
| Withdrawn | 95 | 1.4% |

### 4.2 Mechanisms of Action (1,432 unique)

Top 15:

| MoA | Count |
|-----|-------|
| adrenergic receptor antagonist | 102 |
| cyclooxygenase inhibitor | 102 |
| bacterial cell wall synthesis inhibitor | 96 |
| adrenergic receptor agonist | 85 |
| acetylcholine receptor antagonist | 79 |
| glutamate receptor antagonist | 77 |
| histamine receptor antagonist | 75 |
| serotonin receptor antagonist | 75 |
| phosphodiesterase inhibitor | 74 |
| dopamine receptor antagonist | 71 |
| serotonin receptor agonist | 66 |
| PI3K inhibitor | 51 |
| calcium channel blocker | 50 |
| glucocorticoid receptor agonist | 47 |
| HDAC inhibitor | 46 |

### 4.3 Disease Areas (214 unique)

| Disease Area | Count |
|-------------|-------|
| infectious disease | 420 |
| neurology/psychiatry | 339 |
| cardiology | 202 |
| endocrinology | 121 |
| gastroenterology | 119 |
| oncology | 113 |
| dermatology | 106 |
| pulmonary | 85 |
| hematologic malignancy | 59 |
| ophthalmology | 58 |
| rheumatology | 51 |
| hematology | 34 |

### 4.4 SMILES Length

Min: 1, Median: 47, Max: 700, Mean: 54

## 5. Molecular Features

All compounds were featurized using Morgan circular fingerprints (ECFP4) with radius 2 and 2,048 bits via RDKit. Fingerprints encode the presence or absence of circular molecular substructures and are stored as sparse matrices.

| Dataset | Samples | Features | Non-zero Entries | Density |
|---------|---------|----------|-----------------|---------|
| E. coli | 28,284 | 2,048 | 1,561,855 | 2.70% |
| S. aureus | 43,853 | 2,048 | 2,568,498 | 2.86% |
| P. aeruginosa | 17,783 | 2,048 | 993,237 | 2.73% |
| M. tuberculosis | 18,705 | 2,048 | 921,452 | 2.41% |
| Maier (gut) | 1,177 | 2,048 | 47,992 | 1.99% |
| Drug Repurposing Hub | 6,739 | 2,048 | 301,437 | 2.18% |

## 6. Cross-Validation Strategy

All models use 5-fold cross-validation with Bemis-Murcko scaffold-based splitting. The Bemis-Murcko scaffold reduces each molecule to its core ring system with linkers, stripping side chains. Molecules sharing the same scaffold are always placed in the same fold, ensuring the test set contains structurally novel compounds not seen during training.

**Split files:** 5

| Split File | Dataset |
|-----------|---------|
| ecoli_scaffold_folds.pkl | ecoli |
| maier_scaffold_folds.pkl | maier |
| mtb_scaffold_folds.pkl | mtb |
| paeruginosa_scaffold_folds.pkl | paeruginosa |
| saureus_scaffold_folds.pkl | saureus |

## 7. Cross-Dataset Compound Overlap

Overlap computed by exact canonical SMILES string matching:

| | E. coli | S. aureus | P. aeruginosa | M. tuberculosis | Maier | Hub |
|---|---|---|---|---|---|---|
| **E. coli** | 28,284 | 22,400 | 15,415 | 1,749 | 46 | 249 |
| **S. aureus** | 22,400 | 43,853 | 14,928 | 2,304 | 59 | 314 |
| **P. aeruginosa** | 15,415 | 14,928 | 17,783 | 1,231 | 36 | 152 |
| **M. tuberculosis** | 1,749 | 2,304 | 1,231 | 18,705 | 57 | 147 |
| **Maier** | 46 | 59 | 36 | 57 | 1,177 | 478 |
| **Hub** | 249 | 314 | 152 | 147 | 478 | 6,739 |

The Maier and Hub datasets share 478 compounds. These compounds have both gut commensal harm data and clinical annotations, making them the most informative for selectivity analysis.

## 8. Data Flow

```
ChEMBL 34 (SQLite)        Maier Excel Files       Broad Institute S3
       |                         |                         |
  01_fetch_chembl.py        02_process_maier.py      03_fetch_hub.py
       |                         |                         |
       v                         v                         v
  4 Pathogen CSVs          maier_combined.csv        hub_clean.csv
       |                         |                         |
       +----------+--------------+                         |
                  |                                        |
        04_compute_morgan_fps.py                           |
                  |                                        |
                  v                                        |
         Morgan FPs (.npz)                                 |
         Scaffold Splits (.pkl)                            |
                  |                                        |
     +-----+------+------+------+                          |
     |     |      |      |      |                          |
    RF  D-MPNN CheMeleon MoLF. D-MPNN+RDKit               |
     |     |      |      |      |                          |
     +-----+------+------+------+                          |
                  |                                        |
          CV Metrics + OOF Predictions                     |
                  |                                        |
           07_evaluate.py  <--------------------------------+
                  |
       Selectivity Scores: S = P_path x (1 - P_gut)
                  |
         Ranked Screening Lists
```

## 9. Reference Studies

Two landmark studies serve as external benchmarks for our pipeline.

### 9.1 Stokes et al. (Cell, 2020)

- **Target organism:** E. coli
- **Task:** Binary growth inhibition prediction
- **Training compounds:** 2,335
- **Architecture:** D-MPNN (Chemprop) + 200 RDKit 2D descriptors, ensemble of 20
- **Key discovery:** Halicin (SU3327), a broad-spectrum antibiotic
- **Hub compounds scored:** 4,496
- **Experimentally validated:** 162 of 4,496
- **Validated hits (inhibition < 0.2):** 53 (32.7%)
- **Prediction score range:** 0.0002 to 0.9672 (median 0.0122)

The training set has low structural similarity to halicin (mean Tanimoto = 0.054, max = 0.370), confirming that the model's discovery of halicin was a genuine extrapolation beyond the training chemical space.

Training SMILES length: min=6, median=38, max=295

### 9.2 Wong et al. (Nature, 2024)

- **Target organism:** S. aureus
- **Task:** Binary growth inhibition prediction
- **Training compounds:** 39,312
- **Active:** 512 (1.3%)
- **Architecture:** Chemprop D-MPNN + RDKit descriptors, ensemble of 10
- **Key contribution:** Explainable substructure-based approach

The training set is extremely imbalanced (1.3% active), reflecting the rarity of genuine antibacterial compounds in large-scale screening.

- **Broad800 screening library:** 99,999 compounds
- **Mcule screening library:** 1128 batches

Training SMILES length: min=3, median=81, max=700

### 9.3 Cross-Study Comparison

| Aspect | Our Pipeline | Stokes (2020) | Wong (2024) |
|--------|-------------|---------------|-------------|
| Target | 4 pathogens + gut | E. coli only | S. aureus only |
| Training size | 108,625 (pathogens) + 1,177 (gut) | 2,335 | 39,312 |
| Screening library | 6,739 (Hub) | 4,496 (Hub subset) | 99,999 (Broad800) |
| Selectivity | Yes (dual objective) | No (activity only) | No (activity only) |
| Gut microbiome | Modeled (Maier data) | Not considered | Not considered |
| Models | 5 architectures | D-MPNN + 4 baselines | D-MPNN ensemble |
| Validation | Scaffold CV | Empirical (162 compounds) | Empirical (283 compounds) |

## 10. Key Dataset Characteristics Affecting Model Performance

### 10.1 Small Gut Dataset

The Maier dataset (1,177 compounds) is 15x to 37x smaller than the pathogen datasets (17,783 to 43,853). This causes higher variance in CV estimates for gut tasks and greater benefit from pretrained models (CheMeleon, MoLFormer) that leverage transfer learning.

### 10.2 Class Imbalance

P. aeruginosa (26.2% active) and the gut t=20 task (10.8% harmful) are the most imbalanced tasks. PR-AUC is the more informative metric for these tasks, as ROC-AUC can be misleadingly high when the classifier predicts the majority class.

### 10.3 Chemical Space Coverage

Of 6,739 Hub compounds, 249 (3.7%) overlap with the E. coli training set. The remaining compounds are genuine extrapolations where model predictions carry higher uncertainty.
