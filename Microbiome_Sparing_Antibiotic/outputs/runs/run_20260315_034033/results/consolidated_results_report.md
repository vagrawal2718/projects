# Microbiome-Sparing Antibiotic Discovery: Consolidated Results

**Generated:** 2026-04-05 10:07
**Run ID:** run_20260315_034033
**Author:** Vishakha Agrawal, Lab for Spatial Informatics, IIIT Hyderabad
**Pipeline:** 5-model ML pipeline for selective antibiotic candidate identification

---
## 1. Model Architecture Summary

| Model | Architecture | Screening Method | Key Feature |
|-------|-------------|-----------------|-------------|
| RF | 500 trees, 2048-bit Morgan FP (ECFP4) | Single final model | Fingerprint-based |
| D-MPNN | depth=3, hidden=300, graph neural network | Single final model | Learned graph representation |
| CheMeleon | Pretrained 6-layer D-MPNN encoder (frozen) + FFN head | Single final model | Transfer learning |
| MoLFormer | Transformer pretrained on 1.1B SMILES, fine-tuned | Single final model | SMILES language model |
| D-MPNN+RDKit | depth=5, hidden=1600 + 200 RDKit 2D descriptors | Ensemble of 5 fold models | Stokes architecture |

All models trained with 5-fold scaffold-based cross-validation on the same splits.
Screening performed on the Broad Institute Drug Repurposing Hub (6,739 compounds).

---
## 2. Cross-Validation Performance (ROC-AUC)

| Task | RF | D-MPNN | CheMeleon | MoLFormer | D-MPNN+RDKit |
|------|------|------|------|------|------|
| E. coli | **0.8765 +/- 0.0107** | 0.8525 +/- 0.0123 | 0.8330 +/- 0.0113 | 0.8378 +/- 0.0178 | 0.8408 +/- 0.0137 |
| S. aureus | **0.8708 +/- 0.0073** | 0.8544 +/- 0.0125 | 0.8311 +/- 0.0100 | 0.8346 +/- 0.0150 | 0.8386 +/- 0.0089 |
| P. aeruginosa | **0.8610 +/- 0.0135** | 0.8379 +/- 0.0131 | 0.8204 +/- 0.0184 | 0.8275 +/- 0.0110 | 0.8233 +/- 0.0141 |
| M. tuberculosis | **0.8112 +/- 0.0178** | 0.7599 +/- 0.0232 | 0.7620 +/- 0.0129 | 0.7640 +/- 0.0177 | 0.7376 +/- 0.0309 |
| Gut harm (t=5) | 0.8035 +/- 0.0729 | 0.8248 +/- 0.0514 | 0.8257 +/- 0.0387 | 0.8471 +/- 0.0412 | **0.8486 +/- 0.0542** |
| Gut harm (t=10) | 0.8232 +/- 0.0898 | **0.8410 +/- 0.0391** | 0.8122 +/- 0.0709 | 0.8219 +/- 0.0640 | 0.8286 +/- 0.0910 |
| Gut harm (t=20) | **0.8798 +/- 0.0500** | 0.8776 +/- 0.0716 | 0.8581 +/- 0.0759 | 0.8616 +/- 0.0665 | 0.8559 +/- 0.1117 |

**Bold** = best model for that task.

**Key finding:** RF achieves the highest ROC-AUC on 4 of 4 pathogen classification tasks.
 RF achieves the best gut harm prediction at t=t20 (0.8798).

*Figure: `figures/phase4_level1_diagnostic.png`*

---
## 3. Probability Calibration (Score Distribution Analysis)

| Model | S < 0.01 (saturated low) | 0.2 < S < 0.8 (mid-range) | S > 0.95 (saturated high) |
|-------|------------------------|--------------------------|-------------------------|
| RF | 14 | 1941 | 0 |
| D-MPNN | 4153 | 646 | 114 |
| CheMeleon | 742 | 1440 | 9 |
| MoLFormer | 3571 | 826 | 36 |
| D-MPNN+RDKit | 212 | 1612 | 0 |

**Key finding:** D-MPNN suffers from severe probability saturation: 4153 of 6739 compounds receive S < 0.01, compressing the usable dynamic range. RF has the best calibration with only 14 saturated compounds.
 D-MPNN+RDKit reduces saturation from 4153 to 212 (95% reduction) through ensemble averaging.

*Figure: `figures/diagnostic_score_distributions.png`*

---
## 4. Structural Bias Analysis

### 4.1 Phosphate Group Bias

| Metric | Value |
|--------|-------|
| Phosphate-containing compounds in Hub | 154 |
| D-MPNN phosphate/non-phosphate S ratio | 3.05x |
| RF phosphate/non-phosphate S ratio | 1.3x |
| D-MPNN+RDKit phosphate/non-phosphate S ratio | 2.0x |

**Key finding:** D-MPNN assigns 3.05x higher selectivity scores to phosphate-containing compounds.
 D-MPNN+RDKit reduces this to 2.0x through RDKit descriptors.
 RF shows minimal bias (1.3x).

### 4.2 Molecular Weight Bias

| Set | Median MW (Da) | Compounds < 200 Da |
|-----|---------------|-------------------|
| Full Hub | 358.4 | -- |
| CheMeleon top-50 | 302.3 | 6 |
| RF top-50 | 347.9 | 2 |

**Key finding:** CheMeleon top-50 has median MW = 302.3 Da vs Hub median = 358.4 Da, with 6 compounds below 200 Da (vs 2 for RF).

---
## 5. Top-10 Candidate Quality Comparison

### RF

| Rank | Compound | S | P(kill) | P(gut) | MoA |
|------|----------|---|---------|--------|-----|
| 1 | sisomicin | 0.6825 | 0.8376 | 0.1852 | protein synthesis inhibitor |
| 2 | gepotidacin | 0.6748 | 0.8636 | 0.2186 | topoisomerase inhibitor |
| 3 | netilmicin | 0.6718 | 0.8479 | 0.2077 | protein synthesis inhibitor |
| 4 | gentamycin | 0.6630 | 0.7979 | 0.1690 | bacterial 50S ribosomal subunit inh |
| 5 | AFN-1252 | 0.6518 | 0.9174 | 0.2896 | FABI inhibitor |
| 6 | avibactam | 0.6194 | 0.7765 | 0.2024 | beta lactamase inhibitor |
| 7 | aztreonam | 0.6013 | 0.9579 | 0.3723 | bacterial cell wall synthesis inhib |
| 8 | alafosfalin | 0.6001 | 0.7253 | 0.1726 | bacterial cell wall synthesis inhib |
| 9 | relebactam | 0.5920 | 0.8021 | 0.2619 | beta lactamase inhibitor |
| 10 | micronomicin | 0.5887 | 0.7120 | 0.1731 | protein synthesis inhibitor |

### D-MPNN

| Rank | Compound | S | P(kill) | P(gut) | MoA |
|------|----------|---|---------|--------|-----|
| 1 | diadenosine-tetraphosphate | 0.9998 | 0.9999 | 0.0001 | adenosine kinase inhibitor |
| 2 | NADPH | 0.9998 | 0.9999 | 0.0001 | nan |
| 3 | adenosine-triphosphate | 0.9996 | 0.9997 | 0.0002 | adenosine receptor agonist |
| 4 | coenzyme-I | 0.9991 | 0.9994 | 0.0003 | nan |
| 5 | mangafodipir | 0.9990 | 0.9995 | 0.0006 | contrast agent |
| 6 | diflorasone-diacetate | 0.9988 | 0.9998 | 0.0010 | glucocorticoid receptor agonist |
| 7 | coenzyme-A | 0.9987 | 0.9987 | 0.0001 | nan |
| 8 | uridine-5'-triphosphate | 0.9986 | 0.9997 | 0.0011 | purinergic receptor activator |
| 9 | fluticasone-propionate | 0.9983 | 0.9998 | 0.0015 | glucocorticoid receptor agonist |
| 10 | INS316 | 0.9981 | 0.9992 | 0.0011 | purinergic receptor antagonist |

### CheMeleon

| Rank | Compound | S | P(kill) | P(gut) | MoA |
|------|----------|---|---------|--------|-----|
| 1 | methenamine | 1.0000 | 1.0000 | 0.0000 | bacterial DNA inhibitor |
| 2 | 1-((Z)-3-chloroallyl)-1,3,5, | 1.0000 | 1.0000 | 0.0000 | nan |
| 3 | Y-11 | 1.0000 | 1.0000 | 0.0000 | focal adhesion kinase inhibitor |
| 4 | PR-619 | 0.9907 | 0.9940 | 0.0033 | DUB inhibitor |
| 5 | memantine | 0.9884 | 0.9890 | 0.0006 | glutamate receptor antagonist |
| 6 | saxagliptin | 0.9795 | 0.9807 | 0.0012 | dipeptidyl peptidase inhibitor |
| 7 | vildagliptin | 0.9677 | 0.9721 | 0.0046 | dipeptidyl peptidase inhibitor |
| 8 | BC-11 | 0.9583 | 0.9764 | 0.0185 | urokinase inhibitor |
| 9 | thiotepa | 0.9572 | 0.9572 | 0.0000 | cytochrome P450 inhibitor |
| 10 | haloprogin | 0.9297 | 0.9388 | 0.0097 | other antifungal |

### MoLFormer

| Rank | Compound | S | P(kill) | P(gut) | MoA |
|------|----------|---|---------|--------|-----|
| 1 | imexon | 0.9983 | 0.9987 | 0.0004 | apoptosis stimulant|ribonucleotide  |
| 2 | alafosfalin | 0.9962 | 0.9965 | 0.0003 | bacterial cell wall synthesis inhib |
| 3 | sugammadex | 0.9959 | 0.9977 | 0.0018 | neuromuscular blockade reversal age |
| 4 | OP-0595 | 0.9917 | 0.9925 | 0.0008 | beta lactamase inhibitor |
| 5 | epetraborole | 0.9899 | 0.9921 | 0.0022 | leucyl-tRNA synthetase inhibitor |
| 6 | paeoniflorin | 0.9869 | 0.9898 | 0.0029 | anticonvulsant |
| 7 | monocrotaline | 0.9853 | 0.9877 | 0.0024 | antitumor agent |
| 8 | gepotidacin | 0.9813 | 0.9920 | 0.0108 | topoisomerase inhibitor |
| 9 | heptaminol | 0.9763 | 0.9766 | 0.0003 | vasoconstrictor |
| 10 | Proxyphylline | 0.9758 | 0.9798 | 0.0040 | nan |

### D-MPNN+RDKit

| Rank | Compound | S | P(kill) | P(gut) | MoA |
|------|----------|---|---------|--------|-----|
| 1 | asciminib | 0.8246 | 0.9375 | 0.1204 | Bcr-Abl kinase inhibitor |
| 2 | CUDC-907 | 0.7817 | 0.9731 | 0.1967 | PI3K inhibitor |
| 3 | AZD3965 | 0.7518 | 0.9100 | 0.1739 | monocarboxylate transporter inhibit |
| 4 | AR-C155858 | 0.7518 | 0.8410 | 0.1061 | monocarboxylate transporter inhibit |
| 5 | BEBT-908 | 0.7240 | 0.9135 | 0.2074 | PI3K inhibitor |
| 6 | ketohexokinase-inhibitor-1 | 0.7078 | 0.8499 | 0.1672 | kinase inhibitor |
| 7 | itacitinib | 0.6824 | 0.8496 | 0.1968 | JAK inhibitor |
| 8 | alanosine | 0.6823 | 0.6936 | 0.0163 | antimetabolite |
| 9 | gepotidacin | 0.6727 | 0.7982 | 0.1573 | topoisomerase inhibitor |
| 10 | TS-011 | 0.6672 | 0.6775 | 0.0152 | delayed vasospasm antagonist |

**Key finding:** RF has the most pharmacologically meaningful top-10, containing 7 known antibiotics. D-MPNN has the fewest (0).

---
## 6. Narrow vs Broad-Spectrum Drug Validation

| Drug | Category | RF | D-MPNN | CheMeleon | MoLFormer | D-MPNN+RDKit |
|------|----------|------|------|------|------|------|
| daptomycin | Narrow | 0.228 | 0.041 | 0.221 | 0.686 | 0.277 |
| fidaxomicin | Narrow | 0.155 | 0.001 | 0.246 | 0.021 | 0.057 |
| nitrofurantoin | Narrow | 0.029 | 0.000 | 0.043 | 0.000 | 0.032 |
| methenamine | Narrow | 0.239 | 0.001 | 1.000 | 0.376 | 0.061 |
| ciprofloxacin | Broad | 0.047 | 0.031 | 0.125 | 0.026 | 0.263 |
| amoxicillin | Broad | 0.021 | 0.005 | 0.020 | 0.002 | 0.046 |
| clindamycin | Broad | 0.173 | 0.545 | 0.375 | 0.178 | 0.300 |
| doxycycline | Broad | 0.172 | 0.027 | 0.054 | 0.002 | 0.082 |

**Key finding:** RF, CheMeleon, MoLFormer correctly assign higher mean S to narrow-spectrum drugs than broad-spectrum drugs.
 D-MPNN, D-MPNN+RDKit show reversed ordering (broad > narrow), driven by individual drug misclassifications.

Notable misclassification: clindamycin (broad-spectrum, expected high P_gut) receives low P_gut from: CheMeleon (P_gut=0.098), MoLFormer (P_gut=0.044), D-MPNN+RDKit (P_gut=0.063).

---
## 7. Top-50 Antibiotic Enrichment

| Model | E. coli | S. aureus | P. aeruginosa | M. tuberculosis |
|-------|---------|-----------|---------------|-----------------|
| RF | 5/50 (2.9x) | 9/50 (5.2x) | 2/50 (1.2x) | 8/50 (4.7x) |
| D-MPNN | 1/50 (0.6x) | 0/50 (0.0x) | 0/50 (0.0x) | 1/50 (0.6x) |
| CheMeleon | 4/50 (2.3x) | 4/50 (2.3x) | 4/50 (2.3x) | 3/50 (1.8x) |
| MoLFormer | 1/50 (0.6x) | 1/50 (0.6x) | 2/50 (1.2x) | 5/50 (2.9x) |
| D-MPNN+RDKit | 1/50 (0.6x) | 0/50 (0.0x) | 1/50 (0.6x) | 0/50 (0.0x) |

**Key finding:** RF achieves the highest average antibiotic enrichment (1.2-5.2x). D-MPNN has the lowest average enrichment (0.3x).

*Figure: `figures/phase4_test3_enrichment.png`*

---
## 8. Pairwise Model Agreement (Selectivity Score Correlation)

### Selectivity S

| Pair | rho | Agreement |
|------|-----|-----------|
| MoLFormer vs D-MPNN+RDKit | 0.4315 | low |
| CheMeleon vs MoLFormer | 0.4085 | low |
| RF vs CheMeleon | 0.4038 | low |
| RF vs MoLFormer | 0.3940 | low |
| RF vs D-MPNN+RDKit | 0.3938 | low |
| D-MPNN vs D-MPNN+RDKit | 0.3590 | low |
| D-MPNN vs MoLFormer | 0.3578 | low |
| D-MPNN vs CheMeleon | 0.3569 | low |
| CheMeleon vs D-MPNN+RDKit | 0.3497 | low |
| RF vs D-MPNN | 0.3034 | low |

**Highest agreement:** MoLFormer vs D-MPNN+RDKit (rho = 0.4315). **Lowest agreement:** RF vs D-MPNN (rho = 0.3034).

### P(gut harm)

| Pair | rho | Agreement |
|------|-----|-----------|
| MoLFormer vs D-MPNN+RDKit | 0.7297 | moderate |
| RF vs D-MPNN+RDKit | 0.6858 | moderate |
| CheMeleon vs MoLFormer | 0.6635 | moderate |
| D-MPNN vs CheMeleon | 0.6592 | moderate |
| RF vs MoLFormer | 0.6276 | moderate |
| D-MPNN vs MoLFormer | 0.6133 | moderate |
| CheMeleon vs D-MPNN+RDKit | 0.6037 | moderate |
| D-MPNN vs D-MPNN+RDKit | 0.5976 | moderate |
| RF vs CheMeleon | 0.5937 | moderate |
| RF vs D-MPNN | 0.5585 | moderate |

**Highest agreement:** MoLFormer vs D-MPNN+RDKit (rho = 0.7297). **Lowest agreement:** RF vs D-MPNN (rho = 0.5585).

*Figure: `figures/diagnostic_pairwise_scatter.png`*

---
## 9. D-MPNN vs D-MPNN+RDKit: Architecture Comparison

### 9.1 CV Metrics Change

| Task | D-MPNN | D-MPNN+RDKit | Change |
|------|--------|-------------|--------|
| E. coli | 0.8525 | 0.8408 | -0.0117 |
| S. aureus | 0.8544 | 0.8386 | -0.0158 |
| P. aeruginosa | 0.8379 | 0.8233 | -0.0146 |
| M. tuberculosis | 0.7599 | 0.7376 | -0.0223 |
| Gut harm (t=5) | 0.8248 | 0.8486 | +0.0238 |
| Gut harm (t=10) | 0.8410 | 0.8286 | -0.0124 |
| Gut harm (t=20) | 0.8776 | 0.8559 | -0.0217 |

ROC-AUC decreased on 6/7 tasks. The larger model does not improve classification accuracy over the smaller D-MPNN on these dataset sizes.

### 9.2 Stokes et al. (Cell, 2020) Correlation

| Pathogen | D-MPNN rho | D-MPNN+RDKit rho | Change |
|----------|-----------|-----------------|--------|
| E. coli | 0.1535 | 0.1868 | +0.0333 |
| S. aureus | 0.1983 | 0.2716 | +0.0733 |
| P. aeruginosa | 0.0323 | 0.2392 | +0.2069 |
| M. tuberculosis | 0.1988 | 0.1630 | -0.0358 |

D-MPNN+RDKit shows improved Stokes correlation on 3/4 pathogens.
 Largest improvement on P. aeruginosa (0.032 to 0.239).

### 9.3 Calibration Improvement

| Metric | D-MPNN (old) | D-MPNN+RDKit (new) |
|--------|-------------|-------------------|
| S_lt_0.01 | 4153 | 212 |
| S_0.2_to_0.8 | 646 | 1612 |
| S_gt_0.95 | 114 | 0 |
| median | 0.003 | 0.1082 |
| n_above_0.5 | 551 | 58 |

*Figure: `figures/dmpnn_rdkit_score_comparison.png`*
*Figure: `figures/dmpnn_rdkit_old_vs_new_scatter.png`*

---
## 10. Multi-Model Consensus Candidates

Total unique compounds appearing in any model's top-50: **890**

| Agreement Level | Count | Interpretation |
|----------------|-------|---------------|
| 5/5 models | 3 | Highest confidence: all architectures agree |
| 4/5 models | 9 | Very high confidence |
| 3/5 models | 40 | High confidence |
| 2/5 models | 183 | Moderate confidence |
| 1/5 models | 655 | Single model only |

Known antibiotics rediscovered: **58** | Novel repurposing candidates: **832**

### 10.1 Highest-Confidence Candidates (3+ models)

| # | Compound | Models | S (best) | P(kill) | P(gut) | Type | MoA |
|---|----------|--------|----------|---------|--------|------|-----|
| 1 | retapamulin | 5/5 | 1.000 | 0.893 | 0.104 | Novel | protein synthesis inhibitor |
| 2 | AFN-1252 | 5/5 | 0.998 | 0.915 | 0.136 | Novel | FABI inhibitor |
| 3 | trimetrexate | 5/5 | 0.992 | 0.804 | 0.199 | Known AB | dihydrofolate reductase inhibi |
| 4 | micronomicin | 4/5 | 1.000 | 0.791 | 0.121 | Novel | protein synthesis inhibitor |
| 5 | SQ-109 | 4/5 | 1.000 | 0.972 | 0.073 | Known AB | bacterial cell wall synthesis  |
| 6 | netilmicin | 4/5 | 1.000 | 0.814 | 0.106 | Novel | protein synthesis inhibitor |
| 7 | macozinone | 4/5 | 0.999 | 0.984 | 0.219 | Novel | DPRE1 inhibitor |
| 8 | GSK656 | 4/5 | 0.995 | 0.980 | 0.085 | Novel | leucyl-tRNA synthetase inhibit |
| 9 | gepotidacin | 4/5 | 0.994 | 0.908 | 0.096 | Known AB | topoisomerase inhibitor |
| 10 | vinburnine | 4/5 | 0.993 | 0.782 | 0.039 | Novel | adrenergic receptor antagonist |
| 11 | sisomicin | 4/5 | 0.989 | 0.809 | 0.123 | Novel | protein synthesis inhibitor |
| 12 | SB-772077B | 4/5 | 0.975 | 0.881 | 0.015 | Novel | rho associated kinase inhibito |
| 13 | guadecitabine | 3/5 | 1.000 | 0.899 | 0.012 | Novel | DNA methyltransferase inhibito |
| 14 | sodium-nitroprusside | 3/5 | 1.000 | 0.918 | 0.016 | Novel | nitric oxide donor |
| 15 | colistimethate | 3/5 | 1.000 | 0.828 | 0.104 | Novel | bacterial permeability inducer |
| 16 | diquafosol | 3/5 | 1.000 | 0.938 | 0.020 | Novel | purinergic receptor activator |
| 17 | diadenosine-tetraphosphat | 3/5 | 1.000 | 0.829 | 0.029 | Novel | adenosine kinase inhibitor |
| 18 | relebactam | 3/5 | 1.000 | 0.915 | 0.093 | Novel | beta lactamase inhibitor |
| 19 | gentamycin | 3/5 | 1.000 | 0.885 | 0.123 | Known AB | bacterial 50S ribosomal subuni |
| 20 | GSK690693 | 3/5 | 1.000 | 0.847 | 0.060 | Novel | AKT inhibitor |
| 21 | diphenyleneiodonium | 3/5 | 1.000 | 0.884 | 0.042 | Novel | nitric oxide synthase inhibito |
| 22 | PR-619 | 3/5 | 1.000 | 0.885 | 0.040 | Novel | DUB inhibitor |
| 23 | adenosine-triphosphate | 3/5 | 1.000 | 0.787 | 0.038 | Novel | adenosine receptor agonist |
| 24 | uridine-5'-triphosphate | 3/5 | 1.000 | 0.924 | 0.017 | Novel | purinergic receptor activator |
| 25 | BTZ043-racemate | 3/5 | 1.000 | 0.988 | 0.272 | Novel | DPRE1 inhibitor |

### 10.2 Unanimous Agreement (5/5 Models)

**retapamulin**: S = 1.000, supported by all 5 architectures across 2 pathogen(s) (paeruginosa, saureus). MoA: protein synthesis inhibitor. Clinical phase: Launched.

**AFN-1252**: S = 0.998, supported by all 5 architectures across 2 pathogen(s) (ecoli, saureus). MoA: FABI inhibitor. Clinical phase: Phase 2.

**trimetrexate**: S = 0.992, supported by all 5 architectures across 3 pathogen(s) (ecoli, paeruginosa, saureus). MoA: dihydrofolate reductase inhibitor. Clinical phase: Phase 3.

---
## 11. External Validation (Stokes et al., Cell 2020)

Matched 4343 of 6,739 Hub compounds to Stokes et al. Table S2.

### Golden Intersection: 10 compounds validated by Stokes AND predicted selective by our pipeline

| Compound | Our S | Stokes Score | MoA |
|----------|-------|-------------|-----|
| AFN-1252 | 0.000 | 0.000 | FABI inhibitor |
| carumonam | 0.000 | 0.726 | bacterial cell wall synthesis  |
| isepamicin | 0.000 | 0.406 | protein synthesis inhibitor |
| colistimethate | 0.000 | 0.612 | bacterial permeability inducer |
| ulifloxacin | 0.000 | 0.957 | nan |
| oxolinic-acid | 0.000 | 0.735 | bacterial DNA gyrase inhibitor |
| fdcyd | 0.000 | 0.524 | DNA methyltransferase inhibito |
| colistin | 0.000 | 0.583 | bacterial permeability inducer |
| faropenem-medoxomil | 0.000 | 0.565 | lactamase inhibitor |
| solithromycin | 0.000 | 0.473 | protein synthesis inhibitor |

### Halicin Case Study

Halicin (SU-3327), discovered by Stokes et al. as a broad-spectrum antibiotic, receives the following selectivity scores:



---
## 12. Model Interpretability Summary

| Model | Method | Status | Result |
|-------|--------|--------|--------|
| RF | Global feature importance | complete | Top 30 Morgan bits explain 19.7% of importance |
| | | | Most important bit: 456 (importance = 0.01612) |
| D-MPNN | BRICS fragment occlusion | complete | Holistic predictions (fragments score near 0) (15 compounds) |
| D-MPNN+RDKit | BRICS fragment occlusion | complete | Same holistic behavior as D-MPNN (15 compounds) |
| chemeleon | BRICS fragment occlusion | complete | Non-decomposable pretrained representations (15 compounds) |
| MoLFormer | Self-attention extraction | complete | Heteroatom tokens dominate attention (15 compounds) |

**Key finding:** D-MPNN, D-MPNN+RDKit, chemeleon produce holistic, non-decomposable predictions where individual BRICS fragments score near zero. Only RF, MoLFormer provide decomposable feature attributions.

---
## 13. Summary of Key Findings

### Architecture Comparison

1. **RF is the most reliable model for pathogen classification**, achieving the highest ROC-AUC on 4/4 pathogen tasks, best calibration (14 saturated compounds).

2. **D-MPNN+RDKit fixed the old D-MPNN's probability saturation** (from 4153 to 212 compounds at S < 0.01) and reduced phosphate bias, but ROC-AUC decreased on 6/7 tasks.

3. **Raw classification accuracy (ROC-AUC) does not predict screening utility.** A model can have higher ROC-AUC but produce worse drug rankings due to probability saturation and structural biases.

4. **Cross-model consensus is the strongest validation signal.** 3 compound(s) achieve 5/5 model agreement (retapamulin, AFN-1252, trimetrexate).

### Limitations

1. All predictions are computational. Experimental MIC and gut bacteria panel validation required.
2. Binary activity models at fixed MIC threshold (10 uM). No dose-response modeling.
3. In vitro training data. In vivo pharmacokinetics will modulate actual selectivity.
4. The narrow/broad validation uses only 4-6 drugs per category. Individual drug quirks can flip the result.

---
## 14. Output File Inventory

### Data Files

- `candidate_consensus.csv` (231.2 KB)
- `candidate_detailed_top100.csv` (32.3 KB)
- `candidate_known_antibiotics.csv` (18.0 KB)
- `candidate_novel_discoveries.csv` (213.5 KB)
- `chemeleon_frozen_cv_metrics.json` (17.6 KB)
- `comparison_full_metrics.csv` (4.3 KB)
- `comparison_summary.csv` (4.3 KB)
- `consolidated_results_report.md` (22.9 KB)
- `cv_metrics_diagnostic.csv` (1.7 KB)
- `diagnostic_disagreement.csv` (2.2 MB)
- `diagnostic_properties.csv` (2.6 MB)
- `diagnostic_summary.json` (18.9 KB)
- `dmpnn_cv_metrics.json` (8.9 MB)
- `dmpnn_rdkit_checkpoint.json` (7.2 KB)
- `dmpnn_rdkit_cv_metrics.json` (6.2 KB)
- `dmpnn_rdkit_full_report.json` (11.7 KB)
- `external_golden_intersection.csv` (2.8 KB)
- `external_halicin_case_study.json` (1.1 KB)
- `external_stokes_comparison.csv` (1.6 MB)
- `interim_comparison.csv` (1.5 KB)
- `interim_summary.md` (1.6 KB)
- `interpret_molformer_attention.json` (95.4 KB)
- `interpret_occlusion_chemeleon.json` (11.9 KB)
- `interpret_occlusion_dmpnn.json` (12.0 KB)
- `interpret_occlusion_dmpnn_rdkit.json` (11.8 KB)
- `interpret_rf_feature_importance.csv` (717 B)
- `interpret_rf_top_bits.json` (35.2 KB)
- `interpret_summary.json` (439 B)
- `molformer_cv_metrics.json` (10.7 MB)
- `report_known_antibiotics.md` (31.8 KB)
- `report_novel_candidates.md` (52.2 KB)
- `rf_cv_metrics.json` (10.3 KB)
- `screening_overlap.csv` (873 B)
- `test1_rank_separation.csv` (4.5 KB)
- `test2_selectivity_auc.csv` (4.6 KB)
- `test3_topk_enrichment.csv` (1011 B)
- `test4_rank_correlation.csv` (8.9 KB)
- `test5_threshold_sensitivity.csv` (3.5 KB)
- `validation_set.csv` (63.5 KB)

### Figures

- 100 PNG files, 83 PDF files, 64 interactive HTML files
- Location: `/scratch/vishakha.agrawal/antibiotic-selectivity-v2/outputs/runs/run_20260315_034033/results/figures`

---
*Microbiome-Sparing Antibiotic Discovery Pipeline | 2026-04-05 | IIIT Hyderabad*