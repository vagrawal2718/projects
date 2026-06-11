# Regulatory Standards Reference for Antibiotic Candidate Reports

## 1. CLSI M100 (35th Edition, 2025) - MIC Breakpoints

Reference: CLSI. Performance Standards for Antimicrobial Susceptibility Testing.
35th ed. CLSI Supplement M100. Clinical and Laboratory Standards Institute; 2025.

Selected CLSI MIC breakpoints (ug/mL):

| Pathogen | Drug | S (<=) | I | R (>=) |
|----------|------|--------|---|--------|
| E. coli | Ciprofloxacin | 0.25 | 0.5 | 1 |
| E. coli | Meropenem | 1 | 2 | 4 |
| E. coli | Ceftriaxone | 1 | 2 | 4 |
| E. coli | Amoxicillin-clav | 8/4 | 16/8 | 32/16 |
| S. aureus | Vancomycin | 2 | 4-8 | 16 |
| S. aureus | Daptomycin | 1 | -- | -- |
| S. aureus | Linezolid | 4 | -- | 8 |
| S. aureus | Oxacillin (MRSA) | 2 | -- | 4 |
| P. aeruginosa | Meropenem | 2 | 4 | 8 |
| P. aeruginosa | Piperacillin-tazo | 16/4 | 32/4-64/4 | 128/4 |
| P. aeruginosa | Ceftazidime | 8 | 16 | 32 |
| M. tuberculosis | Rifampicin | 1 | -- | -- |
| M. tuberculosis | Isoniazid | 0.2 (low-level) | -- | 1 (high-level) |

Note: "S" = susceptible, "I" = intermediate, "R" = resistant.
CLSI and EUCAST breakpoints differ for some drug/pathogen combinations.

## 2. EUCAST Clinical Breakpoints v15 (2025)

Reference: EUCAST. Clinical Breakpoint Tables v15.0.
European Committee on Antimicrobial Susceptibility Testing; 2025.
URL: https://www.eucast.org/clinical_breakpoints

EUCAST often sets stricter breakpoints than CLSI.

## 3. WHO Bacterial Priority Pathogens List 2024

Reference: WHO. WHO bacterial priority pathogens list, 2024.
Geneva: World Health Organization; 2024. ISBN 978-92-4-009346-1.
DOI: https://doi.org/10.1016/S1473-3099(25)00118-5
Lancet Infect Dis 2025 (Sati et al.)

Rankings (total score 0-100%):

CRITICAL priority:
- Carbapenem-resistant K. pneumoniae: 84%
- Carbapenem-resistant A. baumannii: 82%
- 3rd-gen cephalosporin-resistant E. coli: top quartile
- Carbapenem-resistant E. coli: top quartile
- Rifampicin-resistant M. tuberculosis: critical (independent analysis)
- Carbapenem-resistant P. aeruginosa: critical

HIGH priority:
- Fluoroquinolone-resistant S. Typhi: 72%
- Fluoroquinolone-resistant Shigella: 70%
- Fluoroquinolone-resistant N. gonorrhoeae: 64%
- Vancomycin-resistant E. faecium: 69%
- Methicillin-resistant S. aureus (MRSA): 59%

24 pathogens scored across 8 criteria:
mortality, non-fatal burden, incidence, 10-year resistance trends,
preventability, transmissibility, treatability, antibacterial pipeline.

## 4. FDA Guidance for Antibiotic Development

Reference: FDA. Microbiology Data for Systemic Antibacterial Drugs:
Development, Analysis, and Presentation. Guidance for Industry (2018).
URL: https://www.fda.gov/media/77442/download

Key quantitative requirements:
- MIC distributions against recent clinical isolates
- PK/PD target attainment analysis
- %fT>MIC for time-dependent agents (beta-lactams)
- AUC/MIC for concentration-dependent agents (fluoroquinolones)
- Cmax/MIC for aminoglycosides
- Spectrum of activity against prominent genotypes and resistance mechanisms

## 5. EMA PK/PD Guidance

Reference: EMA. Guideline on the use of pharmacokinetics and
pharmacodynamics in the development of antimicrobial medicinal products.
EMA/CHMP/594085/2015.

Key PK/PD indices and targets:
- Time-dependent killing: %fT>MIC >= 40-70% (beta-lactams)
- Concentration-dependent: fAUC/MIC >= 30-50 (fluoroquinolones)
- fCmax/MIC >= 8-10 (aminoglycosides)
- PDT for >= 1 log10 CFU reduction for severe infections

## 6. Selectivity Index (SI)

Standard pharmacological metric:
SI = CC50 / MIC  (or IC50_human / MIC_pathogen)

| SI Value | Interpretation |
|----------|---------------|
| SI < 1   | Toxic at therapeutic dose (NOT viable) |
| SI 1-10  | Narrow therapeutic window (problematic) |
| SI 10-100 | Promising (typical for approved antibiotics) |
| SI > 100  | Exceptional selectivity |

For our pipeline analog:
SI_analog = (1 - P_gut) / P_pathogen_complement
Higher selectivity score S = P_pathogen * (1 - P_gut) correlates with higher SI.

## 7. Wong et al. (Nature 2024) Operational Thresholds

- Antibiotic activity prediction > 0.4: retained from Mcule database
- Antibiotic activity prediction > 0.2: retained from Broad database
- Cytotoxicity prediction < 0.2: retained as non-cytotoxic
- 39,312 compounds screened; 512 active (1.3%)
- 306 of 512 active were also non-cytotoxic for all 3 cell types
- 283 compounds empirically tested; structural classes validated

## 8. Stokes et al. (Cell 2020) Operational Thresholds

- Top 99 predictions tested: 51 validated (52% hit rate)
- Bottom 63 predictions tested: validation rate much lower
- Halicin: Tanimoto similarity to nearest antibiotic (metronidazole) = 0.21
- Training set: 2,335 compounds, 120 positive (5.1% active)

## 9. CDC AR Threats Report (2019/2022)

Reference: CDC. Antibiotic Resistance Threats in the United States, 2019.
Atlanta, GA: U.S. Department of Health and Human Services, CDC; 2019.
DOI: https://dx.doi.org/10.15620/cdc:82532

Key statistics:
- 2.8 million antibiotic-resistant infections per year in the US
- 35,000+ deaths per year
- MRSA: 323,700 cases/year, 10,600 deaths/year
- ESBL E. coli: 197,400 cases/year, 9,100 deaths/year
- C. difficile: 223,900 cases/year, 12,800 deaths/year

## 10. Maier et al. Reference Thresholds

Reference: Maier et al. Extensive impact of non-antibiotic drugs on human
gut bacteria. Nature 555, 623-628 (2018).
Maier et al. Unravelling the collateral damage of antibiotics on gut
bacteria. Nature 599, 120-124 (2021).

- 1,197 marketed drugs screened against 40 gut bacterial strains
- 24% of non-antibiotic drugs inhibited at least 1 gut strain
- Antibiotics inhibited mean 15.4 of 40 strains
- Non-antibiotic hits inhibited mean 6.2 strains
- Our thresholds: t5 (>=5/40), t10 (>=10/40), t20 (>=20/40)

## CheMeleon Frozen Encoder Implementation Notes

### Key finding from OPI docs (https://www.faccts.de/docs/opi/1.0/docs/contents/notebooks/chemeleon_orca.html):
```python
ckpt_dir = Path().home() / ".chemprop"
mp_path = ckpt_dir / "chemeleon_mp.pt"
# Download URL: https://zenodo.org/records/15460715/files/chemeleon_mp.pt
```

### Architecture:
- CheMeleon MPNN: 6 layers, 2048 hidden dim, V2 atom featurizer
- Pretrained FFN: 3 layers x 2048 (for Mordred descriptor prediction)
- Our FFN: 1 layer (binary classification head) - initialized from scratch

### Two approaches:
1. `--from-foundation CheMeleon` (CLI): loads MPNN, creates new FFN, both trainable
2. Python API: load MPNN weights, freeze them, create classification FFN, train only FFN

### Cannot use `--checkpoint + --freeze-encoder` because:
- CheMeleon pretrained model has FFN for regression (Mordred descriptors)
- Our task needs FFN for classification (binary)
- Architecture mismatch causes error when loading with --checkpoint
