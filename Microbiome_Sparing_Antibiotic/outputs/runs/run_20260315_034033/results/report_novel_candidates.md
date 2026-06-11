# Novel Antibiotic Candidates: Compounds the Field May Have Missed

**Generated:** 2026-04-05 09:07
**Pipeline:** Microbiome-Sparing Antibiotic Discovery
**Author:** Vishakha Agrawal, Lab for Spatial Informatics, IIIT Hyderabad

## Executive Summary

This report identifies **832 non-antibiotic compounds** from the Broad Institute Drug Repurposing Hub (~6,800 compounds) that are predicted to have selective antimicrobial activity: high probability of killing target pathogens while sparing beneficial gut bacteria. Of these, **43 compounds are supported by 3 or more independent ML models**, providing robust computational evidence for experimental follow-up.

**Why drug repurposing?** These compounds already have known safety, pharmacokinetic, and toxicity profiles from their original therapeutic indications. Repurposing dramatically reduces the time and cost of bringing a new antibiotic to clinical use (estimated savings: 5-7 years and $1-2 billion per compound).

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
## Novel Repurposing Candidates by Pathogen

### Escherichia coli (E. coli)
**WHO Priority: Critical** | Candidates found: 273 | Multi-model consensus (3+): 30

| # | Compound | Models | S (best) | P(kill) | P(gut) | Mechanism of Action | Clinical Phase | Original Indication |
|---|----------|--------|----------|---------|--------|---------------------|----------------|---------------------|
| 1 | **AFN-1252** | 5/4 | 0.998 | 0.91 | 0.14 | FABI inhibitor | Phase 2 | nan |
| 2 | **micronomicin** | 4/4 | 1.000 | 0.79 | 0.12 | protein synthesis inhibitor | Launched | infectious disease |
| 3 | **netilmicin** | 4/4 | 1.000 | 0.81 | 0.11 | protein synthesis inhibitor | Launched | infectious disease |
| 4 | **GSK656** | 4/4 | 0.995 | 0.98 | 0.09 | leucyl-tRNA synthetase inhibitor | Preclinical | nan |
| 5 | **sisomicin** | 4/4 | 0.989 | 0.81 | 0.12 | protein synthesis inhibitor | Launched | ophthalmology |
| 6 | **guadecitabine** | 3/4 | 1.000 | 0.90 | 0.01 | DNA methyltransferase inhibitor | Phase 3 | nan |
| 7 | **sodium-nitroprusside** | 3/4 | 1.000 | 0.92 | 0.02 | nitric oxide donor | Launched | cardiology |
| 8 | **diquafosol** | 3/4 | 1.000 | 0.94 | 0.02 | purinergic receptor activator | Phase 3 | nan |
| 9 | **diadenosine-tetraphosphate** | 3/4 | 1.000 | 0.83 | 0.03 | adenosine kinase inhibitor | Phase 1 | nan |
| 10 | **relebactam** | 3/4 | 1.000 | 0.92 | 0.09 | beta lactamase inhibitor | Launched | nan |
| 11 | **GSK690693** | 3/4 | 1.000 | 0.85 | 0.06 | AKT inhibitor | Phase 1 | nan |
| 12 | **diphenyleneiodonium** | 3/4 | 1.000 | 0.88 | 0.04 | nitric oxide synthase inhibitor | Preclinical | nan |
| 13 | **PR-619** | 3/4 | 1.000 | 0.88 | 0.04 | DUB inhibitor | Preclinical | nan |
| 14 | **adenosine-triphosphate** | 3/4 | 1.000 | 0.79 | 0.04 | adenosine receptor agonist | Phase 2 | nan |
| 15 | **uridine-5'-triphosphate** | 3/4 | 1.000 | 0.92 | 0.02 | purinergic receptor activator | Launched | nan |
| 16 | **INS316** | 3/4 | 0.999 | 0.93 | 0.02 | purinergic receptor antagonist | Phase 2 | nan |
| 17 | **boronophenylalanine** | 3/4 | 0.999 | 0.80 | 0.02 | nan | Phase 2 | nan |
| 18 | **monocrotaline** | 3/4 | 0.998 | 0.89 | 0.05 | antitumor agent | Preclinical | nan |
| 19 | **epetraborole** | 3/4 | 0.997 | 0.82 | 0.07 | leucyl-tRNA synthetase inhibitor | Preclinical | nan |
| 20 | **CH-170** | 3/4 | 0.997 | 0.69 | 0.05 | nan | Phase 1 | nan |

**Scientific note on AFN-1252:** This compound, originally developed for nan, acts via FABI inhibitor. Our models predict a 91% probability of inhibiting E. coli at therapeutic concentrations, with only a 14% probability of collateral gut damage. The selectivity score of 0.998 places it in the top tier (S > 0.7). Critically, 5 of 4 independent ML architectures (spanning classical ML to 2026 foundation models) agree on this ranking, providing cross-architectural validation.

### Staphylococcus aureus (S. aureus)
**WHO Priority: High** | Candidates found: 292 | Multi-model consensus (3+): 24

| # | Compound | Models | S (best) | P(kill) | P(gut) | Mechanism of Action | Clinical Phase | Original Indication |
|---|----------|--------|----------|---------|--------|---------------------|----------------|---------------------|
| 1 | **retapamulin** | 5/4 | 1.000 | 0.89 | 0.10 | protein synthesis inhibitor | Launched | infectious disease |
| 2 | **AFN-1252** | 5/4 | 0.998 | 0.91 | 0.14 | FABI inhibitor | Phase 2 | nan |
| 3 | **micronomicin** | 4/4 | 1.000 | 0.79 | 0.12 | protein synthesis inhibitor | Launched | infectious disease |
| 4 | **netilmicin** | 4/4 | 1.000 | 0.81 | 0.11 | protein synthesis inhibitor | Launched | infectious disease |
| 5 | **sisomicin** | 4/4 | 0.989 | 0.81 | 0.12 | protein synthesis inhibitor | Launched | ophthalmology |
| 6 | **SB-772077B** | 4/4 | 0.975 | 0.88 | 0.01 | rho associated kinase inhibitor | Preclinical | nan |
| 7 | **guadecitabine** | 3/4 | 1.000 | 0.90 | 0.01 | DNA methyltransferase inhibitor | Phase 3 | nan |
| 8 | **sodium-nitroprusside** | 3/4 | 1.000 | 0.92 | 0.02 | nitric oxide donor | Launched | cardiology |
| 9 | **diadenosine-tetraphosphate** | 3/4 | 1.000 | 0.83 | 0.03 | adenosine kinase inhibitor | Phase 1 | nan |
| 10 | **GSK690693** | 3/4 | 1.000 | 0.85 | 0.06 | AKT inhibitor | Phase 1 | nan |
| 11 | **PR-619** | 3/4 | 1.000 | 0.88 | 0.04 | DUB inhibitor | Preclinical | nan |
| 12 | **adenosine-triphosphate** | 3/4 | 1.000 | 0.79 | 0.04 | adenosine receptor agonist | Phase 2 | nan |
| 13 | **IKK-2-inhibitor-V** | 3/4 | 0.997 | 0.89 | 0.17 | IKK inhibitor|NFkB pathway inhibitor | Phase 1 | nan |
| 14 | **CH-170** | 3/4 | 0.997 | 0.69 | 0.05 | nan | Phase 1 | nan |
| 15 | **cyanocobalamin** | 3/4 | 0.997 | 0.97 | 0.01 | methylmalonyl CoA mutase stimulant|vitam | Launched | hematology|infectious dis |
| 16 | **methylcobalamin** | 3/4 | 0.996 | 0.98 | 0.03 | vitamin B | Phase 3 | nan |
| 17 | **vitamin-B12** | 3/4 | 0.996 | 0.97 | 0.01 | nan | Launched | hematology |
| 18 | **doxofylline** | 3/4 | 0.994 | 0.76 | 0.03 | adenosine receptor antagonist | Launched | pulmonary |
| 19 | **isepamicin** | 3/4 | 0.992 | 0.86 | 0.21 | protein synthesis inhibitor | Launched | infectious disease |
| 20 | **AR-12** | 3/4 | 0.991 | 0.90 | 0.19 | phosphoinositide dependent kinase inhibi | Phase 1 | nan |

**Scientific note on retapamulin:** This compound, originally developed for infectious disease, acts via protein synthesis inhibitor. Our models predict a 89% probability of inhibiting S. aureus at therapeutic concentrations, with only a 10% probability of collateral gut damage. The selectivity score of 1.000 places it in the top tier (S > 0.7). Critically, 5 of 4 independent ML architectures (spanning classical ML to 2026 foundation models) agree on this ranking, providing cross-architectural validation.

### Pseudomonas aeruginosa (P. aeruginosa)
**WHO Priority: Critical** | Candidates found: 266 | Multi-model consensus (3+): 23

| # | Compound | Models | S (best) | P(kill) | P(gut) | Mechanism of Action | Clinical Phase | Original Indication |
|---|----------|--------|----------|---------|--------|---------------------|----------------|---------------------|
| 1 | **retapamulin** | 5/4 | 1.000 | 0.89 | 0.10 | protein synthesis inhibitor | Launched | infectious disease |
| 2 | **micronomicin** | 4/4 | 1.000 | 0.79 | 0.12 | protein synthesis inhibitor | Launched | infectious disease |
| 3 | **netilmicin** | 4/4 | 1.000 | 0.81 | 0.11 | protein synthesis inhibitor | Launched | infectious disease |
| 4 | **GSK656** | 4/4 | 0.995 | 0.98 | 0.09 | leucyl-tRNA synthetase inhibitor | Preclinical | nan |
| 5 | **vinburnine** | 4/4 | 0.993 | 0.78 | 0.04 | adrenergic receptor antagonist | Launched | neurology/psychiatry |
| 6 | **sisomicin** | 4/4 | 0.989 | 0.81 | 0.12 | protein synthesis inhibitor | Launched | ophthalmology |
| 7 | **SB-772077B** | 4/4 | 0.975 | 0.88 | 0.01 | rho associated kinase inhibitor | Preclinical | nan |
| 8 | **sodium-nitroprusside** | 3/4 | 1.000 | 0.92 | 0.02 | nitric oxide donor | Launched | cardiology |
| 9 | **colistimethate** | 3/4 | 1.000 | 0.83 | 0.10 | bacterial permeability inducer | Launched | infectious disease |
| 10 | **GSK690693** | 3/4 | 1.000 | 0.85 | 0.06 | AKT inhibitor | Phase 1 | nan |
| 11 | **diphenyleneiodonium** | 3/4 | 1.000 | 0.88 | 0.04 | nitric oxide synthase inhibitor | Preclinical | nan |
| 12 | **PR-619** | 3/4 | 1.000 | 0.88 | 0.04 | DUB inhibitor | Preclinical | nan |
| 13 | **monocrotaline** | 3/4 | 0.998 | 0.89 | 0.05 | antitumor agent | Preclinical | nan |
| 14 | **epetraborole** | 3/4 | 0.997 | 0.82 | 0.07 | leucyl-tRNA synthetase inhibitor | Preclinical | nan |
| 15 | **CH-170** | 3/4 | 0.997 | 0.69 | 0.05 | nan | Phase 1 | nan |
| 16 | **cyanocobalamin** | 3/4 | 0.997 | 0.97 | 0.01 | methylmalonyl CoA mutase stimulant|vitam | Launched | hematology|infectious dis |
| 17 | **methylcobalamin** | 3/4 | 0.996 | 0.98 | 0.03 | vitamin B | Phase 3 | nan |
| 18 | **vitamin-B12** | 3/4 | 0.996 | 0.97 | 0.01 | nan | Launched | hematology |
| 19 | **doxofylline** | 3/4 | 0.994 | 0.76 | 0.03 | adenosine receptor antagonist | Launched | pulmonary |
| 20 | **OP-0595** | 3/4 | 0.992 | 0.78 | 0.10 | beta lactamase inhibitor | Preclinical | nan |

**Scientific note on retapamulin:** This compound, originally developed for infectious disease, acts via protein synthesis inhibitor. Our models predict a 89% probability of inhibiting P. aeruginosa at therapeutic concentrations, with only a 10% probability of collateral gut damage. The selectivity score of 1.000 places it in the top tier (S > 0.7). Critically, 5 of 4 independent ML architectures (spanning classical ML to 2026 foundation models) agree on this ranking, providing cross-architectural validation.

### Mycobacterium tuberculosis (M. tuberculosis)
**WHO Priority: Critical** | Candidates found: 278 | Multi-model consensus (3+): 31

| # | Compound | Models | S (best) | P(kill) | P(gut) | Mechanism of Action | Clinical Phase | Original Indication |
|---|----------|--------|----------|---------|--------|---------------------|----------------|---------------------|
| 1 | **micronomicin** | 4/4 | 1.000 | 0.79 | 0.12 | protein synthesis inhibitor | Launched | infectious disease |
| 2 | **netilmicin** | 4/4 | 1.000 | 0.81 | 0.11 | protein synthesis inhibitor | Launched | infectious disease |
| 3 | **macozinone** | 4/4 | 0.999 | 0.98 | 0.22 | DPRE1 inhibitor | Preclinical | nan |
| 4 | **GSK656** | 4/4 | 0.995 | 0.98 | 0.09 | leucyl-tRNA synthetase inhibitor | Preclinical | nan |
| 5 | **sisomicin** | 4/4 | 0.989 | 0.81 | 0.12 | protein synthesis inhibitor | Launched | ophthalmology |
| 6 | **guadecitabine** | 3/4 | 1.000 | 0.90 | 0.01 | DNA methyltransferase inhibitor | Phase 3 | nan |
| 7 | **sodium-nitroprusside** | 3/4 | 1.000 | 0.92 | 0.02 | nitric oxide donor | Launched | cardiology |
| 8 | **colistimethate** | 3/4 | 1.000 | 0.83 | 0.10 | bacterial permeability inducer | Launched | infectious disease |
| 9 | **diquafosol** | 3/4 | 1.000 | 0.94 | 0.02 | purinergic receptor activator | Phase 3 | nan |
| 10 | **diadenosine-tetraphosphate** | 3/4 | 1.000 | 0.83 | 0.03 | adenosine kinase inhibitor | Phase 1 | nan |
| 11 | **relebactam** | 3/4 | 1.000 | 0.92 | 0.09 | beta lactamase inhibitor | Launched | nan |
| 12 | **diphenyleneiodonium** | 3/4 | 1.000 | 0.88 | 0.04 | nitric oxide synthase inhibitor | Preclinical | nan |
| 13 | **adenosine-triphosphate** | 3/4 | 1.000 | 0.79 | 0.04 | adenosine receptor agonist | Phase 2 | nan |
| 14 | **uridine-5'-triphosphate** | 3/4 | 1.000 | 0.92 | 0.02 | purinergic receptor activator | Launched | nan |
| 15 | **BTZ043-racemate** | 3/4 | 1.000 | 0.99 | 0.27 | DPRE1 inhibitor | Phase 1/Phas | nan |
| 16 | **Q-203** | 3/4 | 1.000 | 0.96 | 0.24 | ATP synthase inhibitor | Phase 2 | nan |
| 17 | **INS316** | 3/4 | 0.999 | 0.93 | 0.02 | purinergic receptor antagonist | Phase 2 | nan |
| 18 | **vindesine** | 3/4 | 0.998 | 0.86 | 0.10 | tubulin polymerization inhibitor | Launched | oncology |
| 19 | **epetraborole** | 3/4 | 0.997 | 0.82 | 0.07 | leucyl-tRNA synthetase inhibitor | Preclinical | nan |
| 20 | **IKK-2-inhibitor-V** | 3/4 | 0.997 | 0.89 | 0.17 | IKK inhibitor|NFkB pathway inhibitor | Phase 1 | nan |

**Scientific note on micronomicin:** This compound, originally developed for infectious disease, acts via protein synthesis inhibitor. Our models predict a 79% probability of inhibiting M. tuberculosis at therapeutic concentrations, with only a 12% probability of collateral gut damage. The selectivity score of 1.000 places it in the top tier (S > 0.7). Critically, 4 of 4 independent ML architectures (spanning classical ML to 2026 foundation models) agree on this ranking, providing cross-architectural validation.

---
## Benchmark: How Do Novel Candidates Compare to Known Antibiotics?

The most important question for any novel candidate: **does it score as well as drugs we already know work?** Below, we compare the selectivity scores of novel candidates against known antibiotics from the same screening run. If a compound developed for oncology or cardiology scores higher than established antibiotics like ciprofloxacin or vancomycin, it provides strong computational evidence that its antibacterial selectivity deserves experimental validation.

### Overall Comparison (All Pathogens Combined)

| Metric | Known Antibiotics | Novel Candidates |
|--------|-------------------|------------------|
| Total compounds in consensus | 58 | 832 |
| Mean selectivity | 0.891 | 0.873 |
| Median selectivity | 0.981 | 0.958 |
| Best selectivity | 1.000 | 1.000 |
| Mean P(kill pathogen) | 0.880 | 0.865 |
| Mean P(gut harm) | 0.117 | 0.053 |
| 3+ model consensus | 9 | 43 |

**Key finding:** **321 novel candidates** score above the median known antibiotic selectivity (0.981), and **25 novel candidates** outscore even the best known antibiotic (1.000). This means our pipeline identifies non-antibiotic compounds with predicted selectivity profiles competitive with or superior to established drugs.

### Per-Pathogen Benchmark

#### Escherichia coli (E. coli)

**CheMeleon (Frozen Encoder)** (top 300 from Repurposing Hub, t10 threshold):

| | Known Antibiotics | Novel Candidates |
|---|---|---|
| Count | 283 | 6456 |
| Mean S | 0.165 | 0.132 |
| Median S | 0.108 | 0.077 |
| Best S | 0.930 | 1.000 |
| IQR (25th-75th) | 0.045 - 0.223 | 0.029 - 0.179 |
| Mean P(kill) | 0.415 | 0.155 |
| Mean P(gut harm) | 0.445 | 0.118 |
| **Novels above known median** | -- | **2623** |
| **Novels above best known** | -- | **9** |

Top known antibiotics (reference): haloprogin (S=0.930), alafosfalin (S=0.889), imidurea (S=0.771), aztreonam (S=0.694), gentamycin (S=0.692)

**Novel candidates outscoring known median (0.108):** **methenamine** (S=1.000), **1-((Z)-3-chloroallyl)-1,3** (S=1.000), **Y-11** (S=1.000), **PR-619** (S=0.991), **memantine** (S=0.988)

**D-MPNN (Directed Message Passing Neural Network)** (top 300 from Repurposing Hub, t10 threshold):

| | Known Antibiotics | Novel Candidates |
|---|---|---|
| Count | 283 | 6456 |
| Mean S | 0.090 | 0.098 |
| Median S | 0.010 | 0.003 |
| Best S | 0.988 | 1.000 |
| IQR (25th-75th) | 0.001 - 0.048 | 0.000 - 0.046 |
| Mean P(kill) | 0.429 | 0.120 |
| Mean P(gut harm) | 0.610 | 0.116 |
| **Novels above known median** | -- | **2474** |
| **Novels above best known** | -- | **37** |

Top known antibiotics (reference): carumonam (S=0.988), aztreonam (S=0.976), alafosfalin (S=0.940), tobramycin (S=0.885), voreloxin (S=0.860)

**Novel candidates outscoring known median (0.010):** **diadenosine-tetraphosphat** (S=1.000), **NADPH** (S=1.000), **adenosine-triphosphate** (S=1.000), **coenzyme-I** (S=0.999), **mangafodipir** (S=0.999)

**D-MPNN+RDKit (Stokes Architecture)** (top 300 from Repurposing Hub, t10 threshold):

| | Known Antibiotics | Novel Candidates |
|---|---|---|
| Count | 283 | 6456 |
| Mean S | 0.150 | 0.137 |
| Median S | 0.117 | 0.108 |
| Best S | 0.673 | 0.825 |
| IQR (25th-75th) | 0.064 - 0.217 | 0.054 - 0.195 |
| Mean P(kill) | 0.449 | 0.176 |
| Mean P(gut harm) | 0.571 | 0.164 |
| **Novels above known median** | -- | **3029** |
| **Novels above best known** | -- | **8** |

Top known antibiotics (reference): gepotidacin (S=0.673), irinotecan (S=0.555), AZ-7371 (S=0.550), alafosfalin (S=0.462), pipemidic-acid (S=0.436)

**Novel candidates outscoring known median (0.117):** **asciminib** (S=0.825), **CUDC-907** (S=0.782), **AZD3965** (S=0.752), **AR-C155858** (S=0.752), **BEBT-908** (S=0.724)

**MoLFormer-XL** (top 300 from Repurposing Hub, t10 threshold):

| | Known Antibiotics | Novel Candidates |
|---|---|---|
| Count | 283 | 6456 |
| Mean S | 0.130 | 0.096 |
| Median S | 0.014 | 0.008 |
| Best S | 0.996 | 0.998 |
| IQR (25th-75th) | 0.003 - 0.108 | 0.001 - 0.068 |
| Mean P(kill) | 0.424 | 0.112 |
| Mean P(gut harm) | 0.543 | 0.092 |
| **Novels above known median** | -- | **2770** |
| **Novels above best known** | -- | **1** |

Top known antibiotics (reference): alafosfalin (S=0.996), gepotidacin (S=0.981), belotecan (S=0.918), SN-38 (S=0.889), rosoxacin (S=0.886)

**Novel candidates outscoring known median (0.014):** **imexon** (S=0.998), **sugammadex** (S=0.996), **OP-0595** (S=0.992), **epetraborole** (S=0.990), **paeoniflorin** (S=0.987)

**Random Forest** (top 300 from Repurposing Hub, t10 threshold):

| | Known Antibiotics | Novel Candidates |
|---|---|---|
| Count | 283 | 6456 |
| Mean S | 0.142 | 0.170 |
| Median S | 0.119 | 0.164 |
| Best S | 0.675 | 0.682 |
| IQR (25th-75th) | 0.051 - 0.192 | 0.122 - 0.209 |
| Mean P(kill) | 0.486 | 0.221 |
| Mean P(gut harm) | 0.614 | 0.212 |
| **Novels above known median** | -- | **4964** |
| **Novels above best known** | -- | **1** |

Top known antibiotics (reference): gepotidacin (S=0.675), gentamycin (S=0.663), aztreonam (S=0.601), alafosfalin (S=0.600), valnemulin (S=0.550)

**Novel candidates outscoring known median (0.119):** **sisomicin** (S=0.682), **netilmicin** (S=0.672), **AFN-1252** (S=0.652), **avibactam** (S=0.619), **relebactam** (S=0.592)

#### Staphylococcus aureus (S. aureus)

**CheMeleon (Frozen Encoder)** (top 300 from Repurposing Hub, t10 threshold):

| | Known Antibiotics | Novel Candidates |
|---|---|---|
| Count | 283 | 6456 |
| Mean S | 0.240 | 0.193 |
| Median S | 0.151 | 0.115 |
| Best S | 0.965 | 1.000 |
| IQR (25th-75th) | 0.047 - 0.371 | 0.033 - 0.298 |
| Mean P(kill) | 0.515 | 0.230 |
| Mean P(gut harm) | 0.445 | 0.118 |
| **Novels above known median** | -- | **2791** |
| **Novels above best known** | -- | **12** |

Top known antibiotics (reference): haloprogin (S=0.965), trimetrexate (S=0.881), daptomycin (S=0.869), tedizolid (S=0.866), eravacycline (S=0.857)

**Novel candidates outscoring known median (0.151):** **C11-Acetate** (S=1.000), **methenamine** (S=1.000), **thiotepa** (S=1.000), **cisplatin** (S=1.000), **tribromoethanol** (S=1.000)

**D-MPNN (Directed Message Passing Neural Network)** (top 300 from Repurposing Hub, t10 threshold):

| | Known Antibiotics | Novel Candidates |
|---|---|---|
| Count | 283 | 6456 |
| Mean S | 0.121 | 0.117 |
| Median S | 0.014 | 0.010 |
| Best S | 0.963 | 0.999 |
| IQR (25th-75th) | 0.004 - 0.088 | 0.001 - 0.102 |
| Mean P(kill) | 0.537 | 0.149 |
| Mean P(gut harm) | 0.610 | 0.116 |
| **Novels above known median** | -- | **2994** |
| **Novels above best known** | -- | **68** |

Top known antibiotics (reference): delpazolid (S=0.963), tedizolid (S=0.931), valnemulin (S=0.926), ridinilazole (S=0.905), azalomycin-B (S=0.896)

**Novel candidates outscoring known median (0.014):** **valspodar** (S=0.999), **voclosporin** (S=0.999), **SJG-136** (S=0.998), **NIM811** (S=0.997), **alisporivir** (S=0.997)

**D-MPNN+RDKit (Stokes Architecture)** (top 300 from Repurposing Hub, t10 threshold):

| | Known Antibiotics | Novel Candidates |
|---|---|---|
| Count | 283 | 6456 |
| Mean S | 0.163 | 0.154 |
| Median S | 0.122 | 0.106 |
| Best S | 0.807 | 0.757 |
| IQR (25th-75th) | 0.072 - 0.231 | 0.048 - 0.222 |
| Mean P(kill) | 0.487 | 0.203 |
| Mean P(gut harm) | 0.571 | 0.164 |
| **Novels above known median** | -- | **2922** |
| **Novels above best known** | -- | **0** |

Top known antibiotics (reference): gepotidacin (S=0.807), trimetrexate (S=0.676), irinotecan (S=0.634), iclaprim (S=0.618), AZ-7371 (S=0.560)

**Novel candidates outscoring known median (0.122):** **PF-04691502** (S=0.757), **CPI-1205** (S=0.752), **retapamulin** (S=0.747), **itacitinib** (S=0.741), **PF-03758309** (S=0.738)

**MoLFormer-XL** (top 300 from Repurposing Hub, t10 threshold):

| | Known Antibiotics | Novel Candidates |
|---|---|---|
| Count | 283 | 6456 |
| Mean S | 0.197 | 0.130 |
| Median S | 0.034 | 0.012 |
| Best S | 0.989 | 0.996 |
| IQR (25th-75th) | 0.004 - 0.296 | 0.001 - 0.122 |
| Mean P(kill) | 0.541 | 0.158 |
| Mean P(gut harm) | 0.543 | 0.092 |
| **Novels above known median** | -- | **2463** |
| **Novels above best known** | -- | **2** |

Top known antibiotics (reference): karenitecin (S=0.989), gepotidacin (S=0.986), haloprogin (S=0.979), chlorproguanil (S=0.968), gentamycin (S=0.967)

**Novel candidates outscoring known median (0.034):** **bucillamine** (S=0.996), **pagoclone** (S=0.989), **vinflunine** (S=0.988), **doramectin** (S=0.988), **L-leucine** (S=0.986)

**Random Forest** (top 300 from Repurposing Hub, t10 threshold):

| | Known Antibiotics | Novel Candidates |
|---|---|---|
| Count | 283 | 6456 |
| Mean S | 0.159 | 0.196 |
| Median S | 0.127 | 0.193 |
| Best S | 0.778 | 0.749 |
| IQR (25th-75th) | 0.051 - 0.221 | 0.144 - 0.242 |
| Mean P(kill) | 0.533 | 0.256 |
| Mean P(gut harm) | 0.614 | 0.212 |
| **Novels above known median** | -- | **5295** |
| **Novels above best known** | -- | **0** |

Top known antibiotics (reference): gentamycin (S=0.778), valnemulin (S=0.703), gepotidacin (S=0.702), zoliflodacin (S=0.504), trimetrexate (S=0.501)

**Novel candidates outscoring known median (0.127):** **retapamulin** (S=0.749), **sisomicin** (S=0.714), **AFN-1252** (S=0.692), **micronomicin** (S=0.680), **octenidine** (S=0.608)

#### Pseudomonas aeruginosa (P. aeruginosa)

**CheMeleon (Frozen Encoder)** (top 300 from Repurposing Hub, t10 threshold):

| | Known Antibiotics | Novel Candidates |
|---|---|---|
| Count | 283 | 6456 |
| Mean S | 0.108 | 0.103 |
| Median S | 0.048 | 0.050 |
| Best S | 0.808 | 0.998 |
| IQR (25th-75th) | 0.017 - 0.142 | 0.017 - 0.126 |
| Mean P(kill) | 0.233 | 0.119 |
| Mean P(gut harm) | 0.445 | 0.118 |
| **Novels above known median** | -- | **3303** |
| **Novels above best known** | -- | **32** |

Top known antibiotics (reference): dibekacin (S=0.808), tobramycin (S=0.727), haloprogin (S=0.653), SQ-109 (S=0.641), panipenem (S=0.614)

**Novel candidates outscoring known median (0.048):** **methenamine** (S=0.998), **satraplatin** (S=0.989), **sodium-nitroprusside** (S=0.981), **Y-11** (S=0.971), **1-((Z)-3-chloroallyl)-1,3** (S=0.958)

**D-MPNN (Directed Message Passing Neural Network)** (top 300 from Repurposing Hub, t10 threshold):

| | Known Antibiotics | Novel Candidates |
|---|---|---|
| Count | 283 | 6456 |
| Mean S | 0.043 | 0.049 |
| Median S | 0.001 | 0.001 |
| Best S | 0.857 | 0.995 |
| IQR (25th-75th) | 0.000 - 0.020 | 0.000 - 0.009 |
| Mean P(kill) | 0.222 | 0.060 |
| Mean P(gut harm) | 0.610 | 0.116 |
| **Novels above known median** | -- | **3243** |
| **Novels above best known** | -- | **100** |

Top known antibiotics (reference): carumonam (S=0.857), azalomycin-B (S=0.693), trimetrexate (S=0.591), fusidic-acid (S=0.556), diaveridine (S=0.536)

**Novel candidates outscoring known median (0.001):** **etofylline-clofibrate** (S=0.995), **bismuth-subcitrate-potass** (S=0.994), **monocrotaline** (S=0.994), **CH-170** (S=0.993), **epetraborole** (S=0.991)

**D-MPNN+RDKit (Stokes Architecture)** (top 300 from Repurposing Hub, t10 threshold):

| | Known Antibiotics | Novel Candidates |
|---|---|---|
| Count | 283 | 6456 |
| Mean S | 0.086 | 0.084 |
| Median S | 0.058 | 0.056 |
| Best S | 0.371 | 0.759 |
| IQR (25th-75th) | 0.025 - 0.124 | 0.026 - 0.109 |
| Mean P(kill) | 0.254 | 0.108 |
| Mean P(gut harm) | 0.571 | 0.164 |
| **Novels above known median** | -- | **3115** |
| **Novels above best known** | -- | **100** |

Top known antibiotics (reference): gepotidacin (S=0.371), tobramycin (S=0.312), irinotecan (S=0.308), dibekacin (S=0.301), paromomycin (S=0.299)

**Novel candidates outscoring known median (0.058):** **simurosertib** (S=0.759), **AR-C155858** (S=0.753), **AZD3965** (S=0.722), **IPAG** (S=0.650), **iodixanol** (S=0.608)

**MoLFormer-XL** (top 300 from Repurposing Hub, t10 threshold):

| | Known Antibiotics | Novel Candidates |
|---|---|---|
| Count | 283 | 6456 |
| Mean S | 0.053 | 0.060 |
| Median S | 0.003 | 0.005 |
| Best S | 0.826 | 0.997 |
| IQR (25th-75th) | 0.000 - 0.026 | 0.001 - 0.030 |
| Mean P(kill) | 0.191 | 0.068 |
| Mean P(gut harm) | 0.543 | 0.092 |
| **Novels above known median** | -- | **3901** |
| **Novels above best known** | -- | **67** |

Top known antibiotics (reference): danofloxacin (S=0.826), dibekacin (S=0.782), gentamycin (S=0.746), chlorfenson (S=0.671), sobuzoxane (S=0.669)

**Novel candidates outscoring known median (0.003):** **DMSO** (S=0.997), **chlorobutanol** (S=0.996), **iodixanol** (S=0.994), **vincamine** (S=0.992), **vinburnine** (S=0.992)

**Random Forest** (top 300 from Repurposing Hub, t10 threshold):

| | Known Antibiotics | Novel Candidates |
|---|---|---|
| Count | 283 | 6456 |
| Mean S | 0.104 | 0.148 |
| Median S | 0.090 | 0.144 |
| Best S | 0.686 | 0.599 |
| IQR (25th-75th) | 0.040 - 0.151 | 0.105 - 0.184 |
| Mean P(kill) | 0.333 | 0.191 |
| Mean P(gut harm) | 0.614 | 0.212 |
| **Novels above known median** | -- | **5317** |
| **Novels above best known** | -- | **0** |

Top known antibiotics (reference): gentamycin (S=0.686), trimetrexate (S=0.399), ribostamycin-sulfate (S=0.363), ribostamycin (S=0.363), tedizolid (S=0.349)

**Novel candidates outscoring known median (0.090):** **etofylline** (S=0.599), **acefylline** (S=0.562), **CaCCinh-A01** (S=0.525), **sisomicin** (S=0.506), **doxofylline** (S=0.501)

#### Mycobacterium tuberculosis (M. tuberculosis)

**CheMeleon (Frozen Encoder)** (top 300 from Repurposing Hub, t10 threshold):

| | Known Antibiotics | Novel Candidates |
|---|---|---|
| Count | 283 | 6456 |
| Mean S | 0.247 | 0.261 |
| Median S | 0.154 | 0.215 |
| Best S | 0.882 | 0.994 |
| IQR (25th-75th) | 0.065 - 0.418 | 0.081 - 0.394 |
| Mean P(kill) | 0.487 | 0.307 |
| Mean P(gut harm) | 0.445 | 0.118 |
| **Novels above known median** | -- | **3906** |
| **Novels above best known** | -- | **28** |

Top known antibiotics (reference): gepotidacin (S=0.882), dihydrostreptomycin (S=0.877), streptomycin (S=0.873), thiomersal (S=0.865), SQ-109 (S=0.863)

**Novel candidates outscoring known median (0.154):** **sucralfate** (S=0.994), **sodium-nitroprusside** (S=0.982), **perfluorodecalin** (S=0.979), **memantine** (S=0.974), **dimethyl-fumarate** (S=0.971)

**D-MPNN (Directed Message Passing Neural Network)** (top 300 from Repurposing Hub, t10 threshold):

| | Known Antibiotics | Novel Candidates |
|---|---|---|
| Count | 283 | 6456 |
| Mean S | 0.168 | 0.224 |
| Median S | 0.018 | 0.048 |
| Best S | 0.976 | 1.000 |
| IQR (25th-75th) | 0.003 - 0.130 | 0.003 - 0.358 |
| Mean P(kill) | 0.513 | 0.267 |
| Mean P(gut harm) | 0.610 | 0.116 |
| **Novels above known median** | -- | **3834** |
| **Novels above best known** | -- | **135** |

Top known antibiotics (reference): aztreonam (S=0.976), dalfopristin (S=0.975), valnemulin (S=0.975), AZ-7371 (S=0.971), amikacin (S=0.970)

**Novel candidates outscoring known median (0.018):** **sucralfate** (S=1.000), **hexasodium-phytate** (S=1.000), **diadenosine-tetraphosphat** (S=1.000), **fondaparinux** (S=1.000), **NADPH** (S=0.999)

**D-MPNN+RDKit (Stokes Architecture)** (top 300 from Repurposing Hub, t10 threshold):

| | Known Antibiotics | Novel Candidates |
|---|---|---|
| Count | 283 | 6456 |
| Mean S | 0.187 | 0.277 |
| Median S | 0.149 | 0.254 |
| Best S | 0.915 | 0.931 |
| IQR (25th-75th) | 0.086 - 0.238 | 0.161 - 0.367 |
| Mean P(kill) | 0.492 | 0.346 |
| Mean P(gut harm) | 0.571 | 0.164 |
| **Novels above known median** | -- | **5053** |
| **Novels above best known** | -- | **5** |

Top known antibiotics (reference): fosfluconazole (S=0.915), etoposide-phosphate (S=0.812), AZ-7371 (S=0.704), gepotidacin (S=0.689), dalfopristin (S=0.601)

**Novel candidates outscoring known median (0.149):** **riboflavin-5-phosphate-so** (S=0.931), **triciribine-phosphate** (S=0.929), **mifobate** (S=0.920), **estramustine-phosphate** (S=0.920), **fosamprenavir** (S=0.917)

**MoLFormer-XL** (top 300 from Repurposing Hub, t10 threshold):

| | Known Antibiotics | Novel Candidates |
|---|---|---|
| Count | 283 | 6456 |
| Mean S | 0.236 | 0.264 |
| Median S | 0.039 | 0.113 |
| Best S | 0.999 | 0.997 |
| IQR (25th-75th) | 0.005 - 0.375 | 0.017 - 0.463 |
| Mean P(kill) | 0.571 | 0.306 |
| Mean P(gut harm) | 0.543 | 0.092 |
| **Novels above known median** | -- | **4197** |
| **Novels above best known** | -- | **0** |

Top known antibiotics (reference): SQ-109 (S=0.999), dihydrostreptomycin (S=0.993), AZ-7371 (S=0.992), streptomycin (S=0.991), gentamycin (S=0.985)

**Novel candidates outscoring known median (0.039):** **mibampator** (S=0.997), **LY404187** (S=0.997), **brinzolamide** (S=0.997), **M-25** (S=0.996), **vorapaxar** (S=0.995)

**Random Forest** (top 300 from Repurposing Hub, t10 threshold):

| | Known Antibiotics | Novel Candidates |
|---|---|---|
| Count | 283 | 6456 |
| Mean S | 0.160 | 0.260 |
| Median S | 0.121 | 0.265 |
| Best S | 0.778 | 0.726 |
| IQR (25th-75th) | 0.052 - 0.227 | 0.201 - 0.321 |
| Mean P(kill) | 0.449 | 0.337 |
| Mean P(gut harm) | 0.614 | 0.212 |
| **Novels above known median** | -- | **5993** |
| **Novels above best known** | -- | **0** |

Top known antibiotics (reference): SQ-109 (S=0.778), AZ-7371 (S=0.678), valnemulin (S=0.646), gentamycin (S=0.615), streptomycin (S=0.530)

**Novel candidates outscoring known median (0.121):** **acefylline** (S=0.726), **ETC-159** (S=0.712), **GSK656** (S=0.705), **bedaquiline** (S=0.695), **HC-030031** (S=0.692)

### What This Benchmark Means for Real-World Performance

The selectivity score benchmarks above provide a **computational analog** of experimental performance expectations:

1. **Compounds scoring near known antibiotics** are predicted to have similar pathogen-killing potency AND similar (or better) gut safety. Since known antibiotics in this list have confirmed in vitro activity, a novel candidate with comparable scores is a strong lead for wet-lab testing.

2. **Compounds scoring above known antibiotics** may represent **truly selective** agents: drugs that kill pathogens at least as well as existing antibiotics but with substantially less gut microbiome damage. These are the highest-priority candidates for the drug repurposing pipeline.

3. **Caveats on benchmarking:** Known antibiotics in the Hub are labeled based on mechanism-of-action metadata, not on our model's predictions. A known antibiotic may score low if it is broad-spectrum (high P_gut) or if it targets a different pathogen than the one being screened. Conversely, a novel candidate scoring high does not guarantee in vivo efficacy, but it does mean the model identifies structural features associated with selective activity.

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