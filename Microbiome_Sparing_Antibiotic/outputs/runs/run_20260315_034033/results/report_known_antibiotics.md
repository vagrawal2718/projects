# Known Antibiotics Rediscovered by ML Pipeline

**Generated:** 2026-04-05 09:07
**Pipeline:** Microbiome-Sparing Antibiotic Discovery
**Author:** Vishakha Agrawal, Lab for Spatial Informatics, IIIT Hyderabad

## Executive Summary

This report shows **58 known antimicrobial compounds** that our ML pipeline independently ranked highly for selective antibacterial activity. This serves as **validation**: the pipeline correctly identifies compounds with established antibacterial mechanisms, increasing confidence in the novel candidate predictions.

---
## Scientific Background

### The Antimicrobial Resistance Crisis

The World Health Organization has declared antimicrobial resistance (AMR) one of the top 10 global public health threats. An estimated 1.27 million deaths were directly attributable to bacterial AMR in 2019 (Lancet, 2022), projected to reach 10 million annually by 2050 without intervention.

### The Microbiome Collateral Damage Problem

Most antibiotics in clinical use are broad-spectrum: they kill target pathogens but also devastate the gut microbiome. This causes:

- **Clostridioides difficile infection (CDI):** The leading cause of hospital-acquired diarrhea, directly linked to antibiotic-induced microbiome disruption.
- **Resistance amplification:** Antibiotic-depleted gut niches are colonized by resistant organisms, creating reservoirs for horizontal gene transfer.
- **Metabolic disruption:** Gut bacteria produce essential vitamins (K, B12), short-chain fatty acids, and neurotransmitter precursors. Disruption affects systemic health.
- **Immune dysregulation:** 70-80% of immune cells reside in the gut. Microbiome disruption impairs immune homeostasis.

Maier et al. (Nature, 2018) screened 1,197 marketed drugs against 40 representative human gut bacterial strains and found that 24% of non-antibiotic drugs also inhibited gut bacteria, underscoring the widespread extent of collateral microbiome damage.

### Selectivity Score: The Core Metric

```
S = P_pathogen x (1 - P_gut)
```

| Component | Range | Meaning | Ideal Value |
|-----------|-------|---------|-------------|
| P_pathogen | 0-1 | Probability that the compound inhibits the target pathogen at therapeutic concentrations. Trained on ChEMBL MIC data (IC50/MIC below 10 uM). | Near 1.0 |
| P_gut | 0-1 | Probability that the compound inhibits gut commensal bacteria. Trained on Maier et al. (Nature, 2018/2021) growth inhibition data across 40 strains. | Near 0.0 |
| S | 0-1 | Combined selectivity. S = 1.0 would be a perfect microbiome-sparing antibiotic. In practice, S > 0.5 is a strong lead; S > 0.7 is exceptional. | Near 1.0 |

### Gut Harm Thresholds (t5, t10, t20)

The Maier et al. studies measured the number of gut strains inhibited (n_hit out of 40). We train separate gut harm classifiers at three thresholds:

| Threshold | Binary Label | Clinical Interpretation |
|-----------|-------------|------------------------|
| **t5** | n_hit >= 5 out of 40 | Mild gut disruption. Even narrow-spectrum antibiotics may hit 5 strains. Lenient threshold. |
| **t10** | n_hit >= 10 out of 40 | Moderate disruption. Our **default** threshold. Clinically meaningful: 25% of gut flora affected. |
| **t20** | n_hit >= 20 out of 40 | Severe disruption. Comparable to broad-spectrum antibiotics. Strict threshold. |

---
## Target Pathogens

### Escherichia coli (E. coli)

- **Gram stain:** Gram-negative
- **WHO Priority (BPPL 2024):** Critical
- **Key diseases:** urinary tract infections (UTIs), bloodstream infections, neonatal meningitis, intra-abdominal infections
- **Resistance landscape:** Extended-spectrum beta-lactamases (ESBLs) and carbapenemases (NDM, KPC, OXA-48) have rendered many E. coli strains resistant to virtually all beta-lactam antibiotics. Fluoroquinolone resistance exceeds 50% in many countries. Colistin resistance (mediated by mcr genes) threatens the last-resort treatment.
- **Current treatment:** carbapenems (meropenem, imipenem), colistin, ceftazidime-avibactam
- **Microbiome concern:** E. coli is itself a commensal gut organism. Many E. coli strains are harmless or even beneficial. Broad-spectrum antibiotics targeting pathogenic E. coli also eliminate beneficial strains, creating ecological niches for resistant clones and opportunistic pathogens like C. difficile.

- **WHO BPPL 2024 Category:** Critical
- **Resistance phenotype (BPPL):** 3rd-gen cephalosporin-resistant, carbapenem-resistant
- **CDC US burden:** 197,400 cases/year, 9,100 deaths/year
- **Global burden:** One of two pathogens responsible for ~50% of AMR-attributable fatal burden in high-income countries (GBD 2019)

### Staphylococcus aureus (S. aureus)

- **Gram stain:** Gram-positive
- **WHO Priority (BPPL 2024):** High
- **Key diseases:** skin and soft tissue infections, bacteremia, endocarditis, osteomyelitis, pneumonia
- **Resistance landscape:** Methicillin-resistant S. aureus (MRSA) carries mecA encoding PBP2a, conferring resistance to all beta-lactams. Vancomycin-intermediate (VISA) and vancomycin-resistant (VRSA) strains, though rare, represent a critical threat. Daptomycin resistance via mprF mutations is emerging in clinical settings.
- **Current treatment:** vancomycin, daptomycin, linezolid, ceftaroline
- **Microbiome concern:** Current MRSA treatments (vancomycin, linezolid) have significant anti-anaerobic activity that disrupts Bacteroides and Clostridium species in the gut. Wong et al. (Nature 2023) demonstrated that structure-aware ML can identify MRSA-active compounds with reduced collateral microbiome damage.

- **WHO BPPL 2024 Category:** High
- **WHO BPPL 2024 Score:** 59%
- **Resistance phenotype (BPPL):** Methicillin-resistant (MRSA)
- **CDC US burden:** 323,700 cases/year, 10,600 deaths/year
- **Global burden:** One of two pathogens responsible for ~50% of AMR-attributable fatal burden in high-income countries (GBD 2019)

### Pseudomonas aeruginosa (P. aeruginosa)

- **Gram stain:** Gram-negative
- **WHO Priority (BPPL 2024):** Critical
- **Key diseases:** ventilator-associated pneumonia (VAP), chronic lung infections in cystic fibrosis, burn wound infections, bloodstream infections
- **Resistance landscape:** Intrinsically resistant to many antibiotics due to low outer membrane permeability, constitutive efflux pumps (MexAB-OprM, MexXY-OprM), and chromosomal AmpC beta-lactamase. Acquired resistance via metallo-beta-lactamases (VIM, IMP, NDM) can render strains pan-drug-resistant. Biofilm formation in chronic infections further reduces antibiotic efficacy.
- **Current treatment:** piperacillin-tazobactam, ceftazidime, meropenem, colistin
- **Microbiome concern:** Anti-pseudomonal antibiotics (piperacillin-tazobactam, carbapenems) are among the most microbiome-destructive drug classes. Treatment courses for P. aeruginosa infections are typically prolonged (10-21 days), amplifying collateral gut damage.

- **WHO BPPL 2024 Category:** Critical
- **Resistance phenotype (BPPL):** Carbapenem-resistant
- **CDC US burden:** 32,600 cases/year, 2,700 deaths/year
- **Global burden:** Intrinsically resistant to many antibiotics; biofilm-forming; common in ICU settings

### Mycobacterium tuberculosis (M. tuberculosis)

- **Gram stain:** Acid-fast (Mycobacterium)
- **WHO Priority (BPPL 2024):** Critical
- **Key diseases:** pulmonary tuberculosis, extrapulmonary TB (meningeal, miliary, skeletal)
- **Resistance landscape:** Multi-drug resistant TB (MDR-TB: resistant to isoniazid + rifampicin) affects ~500,000 new cases/year. Extensively drug-resistant TB (XDR-TB: additionally resistant to fluoroquinolones + injectable agents) has mortality >50%. Resistance arises from chromosomal mutations in target genes (katG, rpoB, gyrA).
- **Current treatment:** isoniazid, rifampicin, pyrazinamide, ethambutol (first-line); bedaquiline, pretomanid, linezolid (BPaL regimen for MDR-TB)
- **Microbiome concern:** Standard 6-month TB treatment with rifampicin causes profound microbiome disruption. Rifampicin has one of the broadest antimicrobial spectra of any drug, eliminating Bacteroides, Bifidobacterium, and Lactobacillus populations. Recovery takes months to years. A selective anti-TB agent could preserve gut health during treatment.

- **WHO BPPL 2024 Category:** Critical
- **Resistance phenotype (BPPL):** Rifampicin-resistant
- **Global burden:** Leading infectious disease killer worldwide; 1.3 million deaths in 2022 (WHO GTB Report)

---
## Regulatory and Clinical Standards for Antibiotic Development

The following quantitative standards from regulatory bodies define what constitutes a viable antibiotic candidate and provide context for interpreting our computational predictions.

### CLSI MIC Breakpoints (M100 Ed35, 2025)

The Clinical and Laboratory Standards Institute (CLSI) defines MIC breakpoints (in ug/mL) that classify bacteria as susceptible (S), intermediate (I), or resistant (R) to specific antibiotics. These are the gold standard used by FDA and clinical laboratories worldwide.

Reference: CLSI. Performance Standards for Antimicrobial Susceptibility Testing. 35th ed. CLSI Supplement M100. 2025.

**Escherichia coli:**

| Antibiotic | S (ug/mL) | I (ug/mL) | R (ug/mL) |
|------------|-----------|-----------|-----------|
| Ciprofloxacin | <= 0.25 | 0.5 | >= 1 |
| Meropenem | <= 1 | 2 | >= 4 |
| Ceftriaxone | <= 1 | 2 | >= 4 |
| Amoxicillin-clavulanate | <= 8 | 16 | >= 32 |
| Piperacillin-tazobactam | <= 16 | 32 | >= 128 |
| Gentamicin | <= 4 | 8 | >= 16 |

**Staphylococcus aureus:**

| Antibiotic | S (ug/mL) | I (ug/mL) | R (ug/mL) |
|------------|-----------|-----------|-----------|
| Vancomycin | <= 2 | -- | >= 16 |
| Daptomycin | <= 1 | -- | -- |
| Linezolid | <= 4 | -- | >= 8 |
| Oxacillin (MRSA screen) | <= 2 | -- | >= 4 |
| Clindamycin | <= 0.5 | 1 | >= 4 |
| Trimethoprim-sulfamethoxazole | <= 2 | -- | >= 4 |

**Pseudomonas aeruginosa:**

| Antibiotic | S (ug/mL) | I (ug/mL) | R (ug/mL) |
|------------|-----------|-----------|-----------|
| Meropenem | <= 2 | 4 | >= 8 |
| Ceftazidime | <= 8 | 16 | >= 32 |
| Piperacillin-tazobactam | <= 16 | 32 | >= 128 |
| Tobramycin | <= 4 | 8 | >= 16 |
| Colistin | -- | 2 | -- |

**Mycobacterium tuberculosis:**

| Antibiotic | S (ug/mL) | I (ug/mL) | R (ug/mL) |
|------------|-----------|-----------|-----------|
| Rifampicin | <= 1 | -- | -- |
| Isoniazid (low-level) | <= 0.2 | -- | >= 1 |
| Moxifloxacin | <= 0.25 | 0.5 | >= 2 |
| Bedaquiline | <= 0.25 | -- | -- |

**Relevance to our pipeline:** Our models predict binary activity (active/inactive) at a fixed MIC threshold of 10 uM (~3-5 ug/mL for typical small molecules). Candidates with high P(kill) scores are predicted to inhibit growth at concentrations in the range of CLSI susceptible breakpoints for many drug-pathogen combinations.

### Selectivity Index (SI)

The Selectivity Index quantifies the safety margin between antimicrobial potency and human/commensal toxicity:

```
SI = CC50 (human cells) / MIC (pathogen)
```

| SI Value | Clinical Interpretation |
|----------|------------------------|
| SI < 1 | NOT viable: toxic at therapeutic dose |
| SI 1-10 | Narrow therapeutic window (problematic for systemic use) |
| SI 10-100 | Promising (typical range for approved antibiotics) |
| SI > 100 | Exceptional selectivity (ideal for systemic therapy) |

Our selectivity score S = P_pathogen x (1 - P_gut) is a computational analog. High S correlates with compounds that have high predicted antimicrobial potency (low MIC against pathogen) and low predicted collateral damage (high MIC against gut commensals), consistent with a favorable Selectivity Index.

### PK/PD Targets (FDA/EMA Guidelines)

The FDA and EMA require pharmacokinetic/pharmacodynamic (PK/PD) target attainment analysis for new antibiotic applications. The relevant PK/PD index depends on the drug's killing mechanism:

| Killing Pattern | PK/PD Index | Target | Drug Classes |
|----------------|-------------|--------|-------------|
| Time-Dependent | %fT>MIC | 40-70% of dosing interval | Beta-lactams (penicillins, cephalosporins, carbapenems) |
| Concentration-Dependent | fAUC/MIC | 30-50 (Gram-negative), 80-100 (Gram-positive) | Fluoroquinolones, daptomycin, tigecycline |
| Peak-Dependent | fCmax/MIC | 8-10 | Aminoglycosides (gentamicin, tobramycin, amikacin) |

Reference: FDA. Microbiology Data for Systemic Antibacterial Drugs (2018). EMA/CHMP/594085/2015.

### Published ML Benchmark Thresholds

Our candidates can be contextualized against operational thresholds from the two most successful ML-guided antibiotic discovery campaigns:

**Stokes et al., Cell (2020):**
- Model: Chemprop ensemble x20 + RDKit features
- Training: 2,335 compounds (5.1% positive)
- Screening: Drug Repurposing Hub (~6,111 compounds)
- Validation: 52% hit rate in top 99 predictions

**Wong et al., Nature (2024):**
- Model: Chemprop ensemble x20 + RDKit features
- Training: 39,312 compounds (1.3% positive)
- Screening: Mcule (11.3M) + Broad (800K)
- Activity threshold: > 0.4 (Mcule), > 0.2 (Broad)
- Cytotoxicity filter: < 0.2

---
## ML Models Used

### Random Forest (Baseline)

- **Architecture:** Ensemble of 500 decision trees on 2048-bit Morgan (ECFP4) fingerprints
- **Training:** 5-fold scaffold-based cross-validation
- **Strengths:** Fast, interpretable, strong on small datasets, captures substructure patterns
- **Limitations:** Fixed-length fingerprints lose 3D and electronic information
- **Reference:** Breiman (2001), Morgan fingerprints: Rogers & Hahn, JCICS (2010)

### D-MPNN (Directed Message Passing Neural Network) (2020)

- **Architecture:** Graph neural network that passes messages along directed bonds in the molecular graph
- **Training:** 5-fold scaffold CV, 50 epochs, batch size 50
- **Strengths:** Learns task-specific molecular representations directly from structure; discovered halicin (Stokes et al., Cell 2020) and abaucin (Wong et al., Nature 2023)
- **Limitations:** Requires more data than RF; does not capture long-range electronic effects
- **Reference:** Yang et al., JCICS (2019); Stokes et al., Cell (2020)

### CheMeleon (Fine-tune) (2026)

- **Architecture:** Foundation model: D-MPNN backbone pretrained on ~1M compounds across diverse assays, then fine-tuned (all weights trainable) on target task
- **Training:** 5-fold scaffold CV, 5 epochs, lr=1e-4, dropout=0.3
- **Strengths:** State-of-the-art: wins 75-79% of Polaris benchmarks. Full fine-tuning adapts both encoder and head.
- **Limitations:** Risk of overfitting on very small datasets even with low LR
- **Reference:** Burns et al., arXiv:2506.15792v2 (2026)

### CheMeleon (Frozen Encoder) (2026)

- **Architecture:** Same pretrained D-MPNN backbone (FROZEN), only the classification FFN head trains
- **Training:** 5-fold scaffold CV, 10 epochs, lr=1e-3 (safe since only FFN trains)
- **Strengths:** Cannot overfit encoder. Only ~10K trainable params. Very fast. Best for tiny datasets (<1K compounds).
- **Limitations:** Cannot adapt molecular representations to task; limited by quality of pretrained features
- **Reference:** Burns et al., arXiv:2506.15792v2 (2026); standard transfer learning practice

### D-MPNN+RDKit (Stokes Architecture) (2026)

- **Architecture:** D-MPNN (depth=5, hidden=1600) with 200 RDKit 2D normalized descriptors
- **Training:** 5-fold scaffold CV, 50 epochs, ensemble of 5 fold models for screening
- **Strengths:** Matches Stokes architecture. RDKit features fix phosphate bias. Ensemble fixes saturation.
- **Limitations:** Slower inference. Lower ROC-AUC than simpler D-MPNN on pathogen tasks.
- **Reference:** Stokes et al., Cell (2020); Yang et al., JCICS (2019)

### MoLFormer-XL (2022)

- **Architecture:** Transformer (BERT-style) pretrained on 1.1 billion SMILES strings using masked language modeling
- **Training:** Fine-tuned with classification head, AdamW + cosine LR, early stopping
- **Strengths:** Captures SMILES syntax patterns analogous to natural language; pretrained on largest molecular corpus; good at scaffold-hopping
- **Limitations:** SMILES representation is not unique (same molecule has multiple SMILES); may miss 3D geometry
- **Reference:** Ross et al., Nature Machine Intelligence (2022)

---
## Model Performance (5-Fold Scaffold Cross-Validation)

ROC-AUC: 1.0 = perfect discrimination, 0.5 = random. Scaffold-based CV ensures that structurally similar molecules are not split across train/test, providing a realistic estimate of generalization to novel chemical scaffolds.

| Task | CheMeleon (Frozen Encoder) | D-MPNN (Directed Message Passing Neural Network) | D-MPNN+RDKit (Stokes Architecture) | MoLFormer-XL | Random Forest |
|------|------|------|------|------|------|
| Escherichia coli | 0.833 (PR: 0.750) | 0.853 (PR: 0.774) | 0.841 (PR: 0.757) | 0.838 (PR: 0.755) | 0.876 (PR: 0.805) |
| Staphylococcus aureus | 0.831 (PR: 0.800) | 0.854 (PR: 0.825) | 0.839 (PR: 0.805) | 0.835 (PR: 0.802) | 0.871 (PR: 0.847) |
| Pseudomonas aeruginosa | 0.820 (PR: 0.659) | 0.838 (PR: 0.687) | 0.823 (PR: 0.660) | 0.828 (PR: 0.673) | 0.861 (PR: 0.719) |
| Mycobacterium tuberculosis | 0.762 (PR: 0.715) | 0.760 (PR: 0.722) | 0.738 (PR: 0.696) | 0.764 (PR: 0.719) | 0.811 (PR: 0.775) |
| Gut harm (t=5) | 0.826 (PR: 0.631) | 0.825 (PR: 0.647) | 0.849 (PR: 0.669) | 0.847 (PR: 0.652) | 0.803 (PR: 0.645) |
| Gut harm (t=10) | 0.812 (PR: 0.615) | 0.841 (PR: 0.597) | 0.829 (PR: 0.623) | 0.822 (PR: 0.587) | 0.823 (PR: 0.665) |
| Gut harm (t=20) | 0.858 (PR: 0.659) | 0.878 (PR: 0.643) | 0.856 (PR: 0.644) | 0.862 (PR: 0.608) | 0.880 (PR: 0.685) |

---
## Known Antibiotic Candidates by Pathogen

### Escherichia coli (E. coli)
**WHO Priority: Critical** | Candidates found: 21 | Multi-model consensus (3+): 5

| # | Compound | Models | S (best) | P(kill) | P(gut) | Mechanism of Action | Clinical Phase | Original Indication |
|---|----------|--------|----------|---------|--------|---------------------|----------------|---------------------|
| 1 | **trimetrexate** | 5/4 | 0.992 | 0.80 | 0.20 | dihydrofolate reductase inhibitor | Phase 3 | nan |
| 2 | **gepotidacin** | 4/4 | 0.994 | 0.91 | 0.10 | topoisomerase inhibitor | Phase 2 | nan |
| 3 | **gentamycin** | 3/4 | 1.000 | 0.89 | 0.12 | bacterial 50S ribosomal subunit inhibito | Launched | infectious disease|critic |
| 4 | **alafosfalin** | 3/4 | 0.996 | 0.87 | 0.05 | bacterial cell wall synthesis inhibitor | Phase 1 | nan |
| 5 | **AZ-7371** | 3/4 | 0.994 | 0.83 | 0.12 | antibacterial | Preclinical | nan |
| 6 | **carumonam** | 2/4 | 1.000 | 0.96 | 0.21 | bacterial cell wall synthesis inhibitor | Launched | infectious disease |
| 7 | **aztreonam** | 2/4 | 0.998 | 0.97 | 0.26 | bacterial cell wall synthesis inhibitor | Launched | infectious disease |
| 8 | **neomycin** | 2/4 | 0.998 | 0.67 | 0.10 | bacterial 30S ribosomal subunit inhibito | Launched | infectious disease|gastro |
| 9 | **haloprogin** | 2/4 | 0.998 | 0.97 | 0.02 | other antifungal | Launched | infectious disease |
| 10 | **apramycin** | 2/4 | 0.997 | 0.79 | 0.05 | bacterial 30S ribosomal subunit inhibito | Launched | infectious disease |
| 11 | **amikacin** | 2/4 | 0.997 | 0.89 | 0.12 | bacterial 30S ribosomal subunit inhibito | Launched | infectious disease |
| 12 | **irinotecan** | 2/4 | 0.995 | 0.90 | 0.16 | topoisomerase inhibitor | Launched | oncology |
| 13 | **danofloxacin** | 2/4 | 0.907 | 0.98 | 0.20 | bacterial DNA gyrase inhibitor | Launched | pulmonary |
| 14 | **enrofloxacin** | 1/4 | 0.981 | 0.97 | 0.01 | bacterial DNA gyrase inhibitor | Launched | infectious disease |
| 15 | **pivmecillinam** | 1/4 | 0.981 | 0.99 | 0.00 | bacterial cell wall synthesis inhibitor | Launched | infectious disease |
| 16 | **cefcapene-pivoxil** | 1/4 | 0.774 | 0.87 | 0.11 | bacterial cell wall synthesis inhibitor | Launched | infectious disease |
| 17 | **imidurea** | 1/4 | 0.771 | 0.78 | 0.02 | other antibiotic | Preclinical | nan |
| 18 | **valnemulin** | 1/4 | 0.755 | 0.85 | 0.25 | bacterial 50S ribosomal subunit inhibito | Launched | infectious disease|gastro |
| 19 | **garenoxacin** | 1/4 | 0.678 | 0.88 | 0.23 | topoisomerase inhibitor | Launched | infectious disease |
| 20 | **tobramycin** | 1/4 | 0.643 | 0.64 | 0.07 | bacterial 30S ribosomal subunit inhibito | Launched | infectious disease |

### Staphylococcus aureus (S. aureus)
**WHO Priority: High** | Candidates found: 28 | Multi-model consensus (3+): 5

| # | Compound | Models | S (best) | P(kill) | P(gut) | Mechanism of Action | Clinical Phase | Original Indication |
|---|----------|--------|----------|---------|--------|---------------------|----------------|---------------------|
| 1 | **trimetrexate** | 5/4 | 0.992 | 0.80 | 0.20 | dihydrofolate reductase inhibitor | Phase 3 | nan |
| 2 | **gepotidacin** | 4/4 | 0.994 | 0.91 | 0.10 | topoisomerase inhibitor | Phase 2 | nan |
| 3 | **gentamycin** | 3/4 | 1.000 | 0.89 | 0.12 | bacterial 50S ribosomal subunit inhibito | Launched | infectious disease|critic |
| 4 | **AZ-7371** | 3/4 | 0.994 | 0.83 | 0.12 | antibacterial | Preclinical | nan |
| 5 | **iclaprim** | 3/4 | 0.954 | 0.88 | 0.06 | dihydrofolate reductase inhibitor | Phase 3 | nan |
| 6 | **neomycin** | 2/4 | 0.998 | 0.67 | 0.10 | bacterial 30S ribosomal subunit inhibito | Launched | infectious disease|gastro |
| 7 | **paromomycin** | 2/4 | 0.998 | 0.70 | 0.12 | bacterial 30S ribosomal subunit inhibito | Launched | infectious disease |
| 8 | **haloprogin** | 2/4 | 0.998 | 0.97 | 0.02 | other antifungal | Launched | infectious disease |
| 9 | **irinotecan** | 2/4 | 0.995 | 0.90 | 0.16 | topoisomerase inhibitor | Launched | oncology |
| 10 | **teicoplanin-A2-1** | 2/4 | 0.980 | 0.99 | 0.36 | bacterial cell wall synthesis inhibitor | Launched | infectious disease |
| 11 | **teicoplanin** | 2/4 | 0.935 | 0.99 | 0.37 | bacterial cell wall synthesis inhibitor | Launched | infectious disease |
| 12 | **tedizolid** | 2/4 | 0.887 | 0.84 | 0.17 | bacterial 50S ribosomal subunit inhibito | Launched | infectious disease |
| 13 | **daptomycin** | 2/4 | 0.871 | 0.89 | 0.07 | bacterial cell wall synthesis inhibitor | Launched | infectious disease |
| 14 | **dibekacin** | 2/4 | 0.808 | 0.67 | 0.04 | bacterial 30S ribosomal subunit inhibito | Launched | infectious disease |
| 15 | **tilmicosin** | 1/4 | 0.999 | 1.00 | 0.00 | bacterial 50S ribosomal subunit inhibito | Launched | pulmonary |
| 16 | **teicoplanin-A2-3** | 1/4 | 0.996 | 1.00 | 0.00 | bacterial cell wall synthesis inhibitor | Launched | infectious disease |
| 17 | **demeclocycline** | 1/4 | 0.996 | 1.00 | 0.00 | bacterial 30S ribosomal subunit inhibito | Launched | endocrinology|infectious  |
| 18 | **karenitecin** | 1/4 | 0.994 | 0.99 | 0.01 | topoisomerase inhibitor | Phase 3 | nan |
| 19 | **chlorproguanil** | 1/4 | 0.981 | 0.99 | 0.01 | dihydrofolate reductase inhibitor | Launched | infectious disease |
| 20 | **crystal-violet** | 1/4 | 0.976 | 0.98 | 0.00 | other antibiotic | Launched | nan |

### Pseudomonas aeruginosa (P. aeruginosa)
**WHO Priority: Critical** | Candidates found: 12 | Multi-model consensus (3+): 3

| # | Compound | Models | S (best) | P(kill) | P(gut) | Mechanism of Action | Clinical Phase | Original Indication |
|---|----------|--------|----------|---------|--------|---------------------|----------------|---------------------|
| 1 | **trimetrexate** | 5/4 | 0.992 | 0.80 | 0.20 | dihydrofolate reductase inhibitor | Phase 3 | nan |
| 2 | **gentamycin** | 3/4 | 1.000 | 0.89 | 0.12 | bacterial 50S ribosomal subunit inhibito | Launched | infectious disease|critic |
| 3 | **iclaprim** | 3/4 | 0.954 | 0.88 | 0.06 | dihydrofolate reductase inhibitor | Phase 3 | nan |
| 4 | **ribostamycin-sulfate** | 2/4 | 0.994 | 0.70 | 0.03 | bacterial 30S ribosomal subunit inhibito | Launched | infectious disease |
| 5 | **ribostamycin** | 2/4 | 0.993 | 0.70 | 0.03 | bacterial 30S ribosomal subunit inhibito | Launched | infectious disease |
| 6 | **danofloxacin** | 2/4 | 0.907 | 0.98 | 0.20 | bacterial DNA gyrase inhibitor | Launched | pulmonary |
| 7 | **dibekacin** | 2/4 | 0.808 | 0.67 | 0.04 | bacterial 30S ribosomal subunit inhibito | Launched | infectious disease |
| 8 | **rolitetracycline** | 1/4 | 0.995 | 1.00 | 0.00 | bacterial 30S ribosomal subunit inhibito | Launched | infectious disease |
| 9 | **enrofloxacin** | 1/4 | 0.981 | 0.97 | 0.01 | bacterial DNA gyrase inhibitor | Launched | infectious disease |
| 10 | **tobramycin** | 1/4 | 0.643 | 0.64 | 0.07 | bacterial 30S ribosomal subunit inhibito | Launched | infectious disease |
| 11 | **bekanamycin** | 1/4 | 0.612 | 0.60 | 0.05 | bacterial 30S ribosomal subunit inhibito | Launched | infectious disease |
| 12 | **prulifloxacin** | 1/4 | 0.415 | 0.88 | 0.53 | bacterial DNA gyrase inhibitor | Launched | infectious disease|pulmon |

### Mycobacterium tuberculosis (M. tuberculosis)
**WHO Priority: Critical** | Candidates found: 27 | Multi-model consensus (3+): 6

| # | Compound | Models | S (best) | P(kill) | P(gut) | Mechanism of Action | Clinical Phase | Original Indication |
|---|----------|--------|----------|---------|--------|---------------------|----------------|---------------------|
| 1 | **SQ-109** | 4/4 | 1.000 | 0.97 | 0.07 | bacterial cell wall synthesis inhibitor | Phase 3 | nan |
| 2 | **gepotidacin** | 4/4 | 0.994 | 0.91 | 0.10 | topoisomerase inhibitor | Phase 2 | nan |
| 3 | **gentamycin** | 3/4 | 1.000 | 0.89 | 0.12 | bacterial 50S ribosomal subunit inhibito | Launched | infectious disease|critic |
| 4 | **AZ-7371** | 3/4 | 0.994 | 0.83 | 0.12 | antibacterial | Preclinical | nan |
| 5 | **dihydrostreptomycin** | 3/4 | 0.993 | 0.86 | 0.10 | bacterial 30S ribosomal subunit inhibito | Withdrawn | nan |
| 6 | **streptomycin** | 3/4 | 0.991 | 0.85 | 0.15 | bacterial 30S ribosomal subunit inhibito | Launched | infectious disease |
| 7 | **neomycin** | 2/4 | 0.998 | 0.67 | 0.10 | bacterial 30S ribosomal subunit inhibito | Launched | infectious disease|gastro |
| 8 | **paromomycin** | 2/4 | 0.998 | 0.70 | 0.12 | bacterial 30S ribosomal subunit inhibito | Launched | infectious disease |
| 9 | **apramycin** | 2/4 | 0.997 | 0.79 | 0.05 | bacterial 30S ribosomal subunit inhibito | Launched | infectious disease |
| 10 | **amikacin** | 2/4 | 0.997 | 0.89 | 0.12 | bacterial 30S ribosomal subunit inhibito | Launched | infectious disease |
| 11 | **irinotecan** | 2/4 | 0.995 | 0.90 | 0.16 | topoisomerase inhibitor | Launched | oncology |
| 12 | **ribostamycin-sulfate** | 2/4 | 0.994 | 0.70 | 0.03 | bacterial 30S ribosomal subunit inhibito | Launched | infectious disease |
| 13 | **kanamycin** | 2/4 | 0.993 | 0.83 | 0.03 | bacterial 30S ribosomal subunit inhibito | Launched | infectious disease |
| 14 | **ribostamycin** | 2/4 | 0.993 | 0.70 | 0.03 | bacterial 30S ribosomal subunit inhibito | Launched | infectious disease |
| 15 | **fosfluconazole** | 2/4 | 0.927 | 0.79 | 0.09 | other antifungal | Preclinical | nan |
| 16 | **dibekacin** | 2/4 | 0.808 | 0.67 | 0.04 | bacterial 30S ribosomal subunit inhibito | Launched | infectious disease |
| 17 | **omadacycline** | 1/4 | 1.000 | 1.00 | 0.00 | bacterial 30S ribosomal subunit inhibito | Launched | infectious disease |
| 18 | **pralatrexate** | 1/4 | 0.997 | 1.00 | 0.00 | dihydrofolate reductase inhibitor | Launched | hematologic malignancy |
| 19 | **gamithromycin** | 1/4 | 0.983 | 1.00 | 0.02 | antibacterial | Preclinical | nan |
| 20 | **azithromycin** | 1/4 | 0.981 | 1.00 | 0.02 | bacterial 50S ribosomal subunit inhibito | Launched | infectious disease |

---
## Interactive Visualizations

The following HTML files are generated alongside this report. Open them in any browser for interactive exploration (zoom, hover, rotate):

- `candidates_3d_landscape_chemeleon_frozen_ecoli.html`
- `candidates_3d_landscape_chemeleon_frozen_mtb.html`
- `candidates_3d_landscape_chemeleon_frozen_paeruginosa.html`
- `candidates_3d_landscape_chemeleon_frozen_saureus.html`
- `candidates_3d_landscape_dmpnn_ecoli.html`
- `candidates_3d_landscape_dmpnn_mtb.html`
- `candidates_3d_landscape_dmpnn_paeruginosa.html`
- `candidates_3d_landscape_dmpnn_rdkit_ecoli.html`
- `candidates_3d_landscape_dmpnn_rdkit_mtb.html`
- `candidates_3d_landscape_dmpnn_rdkit_paeruginosa.html`
- `candidates_3d_landscape_dmpnn_rdkit_saureus.html`
- `candidates_3d_landscape_dmpnn_saureus.html`
- `candidates_3d_landscape_molformer_ecoli.html`
- `candidates_3d_landscape_molformer_mtb.html`
- `candidates_3d_landscape_molformer_paeruginosa.html`
- `candidates_3d_landscape_molformer_saureus.html`
- `candidates_3d_landscape_rf_ecoli.html`
- `candidates_3d_landscape_rf_mtb.html`
- `candidates_3d_landscape_rf_paeruginosa.html`
- `candidates_3d_landscape_rf_saureus.html`
- `candidates_benchmark_comparison.html`
- `candidates_benchmark_lollipop.html`
- `candidates_consensus_heatmap.html`
- `candidates_known_vs_novel.html`
- `candidates_master_dashboard.html`
- `candidates_radar_top20.html`
- `candidates_scatter_chemeleon_frozen_ecoli.html`
- `candidates_scatter_chemeleon_frozen_mtb.html`
- `candidates_scatter_chemeleon_frozen_paeruginosa.html`
- `candidates_scatter_chemeleon_frozen_saureus.html`
- `candidates_scatter_dmpnn_ecoli.html`
- `candidates_scatter_dmpnn_mtb.html`
- `candidates_scatter_dmpnn_paeruginosa.html`
- `candidates_scatter_dmpnn_rdkit_ecoli.html`
- `candidates_scatter_dmpnn_rdkit_mtb.html`
- `candidates_scatter_dmpnn_rdkit_paeruginosa.html`
- `candidates_scatter_dmpnn_rdkit_saureus.html`
- `candidates_scatter_dmpnn_saureus.html`
- `candidates_scatter_molformer_ecoli.html`
- `candidates_scatter_molformer_mtb.html`
- `candidates_scatter_molformer_paeruginosa.html`
- `candidates_scatter_molformer_saureus.html`
- `candidates_scatter_rf_ecoli.html`
- `candidates_scatter_rf_mtb.html`
- `candidates_scatter_rf_paeruginosa.html`
- `candidates_scatter_rf_saureus.html`

---
## How to Read These Results

### Candidate Tiers

| Tier | Criteria | Confidence | Recommended Action |
|------|----------|------------|-------------------|
| **Tier 1** | S > 0.7, 4/4 models agree | Very High | Priority experimental validation (MIC + gut panel) |
| **Tier 2** | S > 0.5, 3/4 models agree | High | Include in screening campaign |
| **Tier 3** | S > 0.5, 2/4 models agree | Moderate | Test if structurally distinct from Tier 1-2 |
| **Tier 4** | S > 0.3, 1 model only | Low | Reserve for scaffold diversity analysis |

### What Cross-Model Consensus Means

When four completely different ML architectures (fingerprint-based Random Forest, graph neural network D-MPNN, foundation model CheMeleon, and transformer MoLFormer) independently rank the same compound highly, this means:

1. The signal is **not an artifact** of one particular molecular representation
2. The prediction is **robust to architectural choices**
3. The underlying structure-activity relationship is **strong enough** to be detected by fundamentally different learning algorithms

This is analogous to obtaining consistent results across independent experimental replicates: each model is a different "measurement instrument" for the same underlying biological activity.

### Important Caveats

1. **Computational predictions only.** Every candidate requires wet-lab validation (minimum inhibitory concentration assays, gut bacteria growth inhibition panels).
2. **Binary activity models.** Our classifiers predict active/inactive at a fixed MIC threshold. They do not predict concentration-dependent selectivity windows.
3. **In vitro data.** Both ChEMBL MIC data and Maier gut inhibition data are in vitro. In vivo pharmacokinetics (absorption, distribution, metabolism, excretion) will modulate actual selectivity.
4. **Scaffold bias.** Models perform best on scaffolds similar to training data. Novel scaffolds in the Hub may have less reliable predictions.
5. **Resistance potential.** These predictions do not account for resistance emergence rates or mechanisms.

### Recommended Experimental Validation Protocol

1. **MIC determination:** Measure minimum inhibitory concentration against target pathogen (CLSI broth microdilution, EUCAST guidelines)
2. **Gut bacteria panel:** Test against 10-40 representative commensal strains (replicating the Maier et al. protocol)
3. **Selectivity index:** Calculate SI = MIC_gut / MIC_pathogen. SI > 10 is promising; SI > 100 is exceptional.
4. **Cytotoxicity:** Test against mammalian cell lines (HEK293, HepG2) to confirm therapeutic window
5. **Mechanism investigation:** For novel candidates without known antibacterial MoA, use resistance evolution + whole-genome sequencing to identify targets

---
*Microbiome-Sparing Antibiotic Discovery Pipeline | 2026-04-05 | IIIT Hyderabad*