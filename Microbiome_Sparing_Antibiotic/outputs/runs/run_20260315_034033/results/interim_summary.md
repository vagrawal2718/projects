# Microbiome-Sparing Antibiotic Discovery: Interim Results

**Generated:** 2026-03-21 19:07

**Models completed:** 3/4

## Pipeline Status

| Model | Status | Tasks | Mean ROC-AUC |
|-------|--------|-------|--------------|
| RF + Morgan FP | DONE | 7 | 0.8466 |
| D-MPNN (Chemprop) | DONE | 7 | 0.8354 |
| CheMeleon (Frozen Enc.) | DONE | 7 | 0.8204 |
| MoLFormer-XL | PENDING | 0 | -- |

## ROC-AUC by Task

| Task | RF + Morgan FP | D-MPNN (Chemprop) | CheMeleon (Frozen Enc.) |
|------|------|------|------|
| E. coli | 0.8765 +/- 0.011 | 0.8525 +/- 0.012 | 0.8330 +/- 0.011 |
| S. aureus | 0.8708 +/- 0.007 | 0.8544 +/- 0.013 | 0.8311 +/- 0.010 |
| P. aeruginosa | 0.8610 +/- 0.013 | 0.8379 +/- 0.013 | 0.8204 +/- 0.018 |
| M. tuberculosis | 0.8112 +/- 0.018 | 0.7599 +/- 0.023 | 0.7620 +/- 0.013 |
| Gut (t=5) | 0.8035 +/- 0.073 | 0.8248 +/- 0.051 | 0.8257 +/- 0.039 |
| Gut (t=10) | 0.8232 +/- 0.090 | 0.8410 +/- 0.039 | 0.8122 +/- 0.071 |
| Gut (t=20) | 0.8798 +/- 0.050 | 0.8776 +/- 0.072 | 0.8581 +/- 0.076 |

## Key Findings

- **E. coli**: Best model is RF + Morgan FP (ROC-AUC = 0.8765)
- **S. aureus**: Best model is RF + Morgan FP (ROC-AUC = 0.8708)
- **P. aeruginosa**: Best model is RF + Morgan FP (ROC-AUC = 0.8610)
- **M. tuberculosis**: Best model is RF + Morgan FP (ROC-AUC = 0.8112)
- **Gut (t=5)**: Best model is CheMeleon (Frozen Enc.) (ROC-AUC = 0.8257)
- **Gut (t=10)**: Best model is D-MPNN (Chemprop) (ROC-AUC = 0.8410)
- **Gut (t=20)**: Best model is RF + Morgan FP (ROC-AUC = 0.8798)

## Visualization

![Model Comparison](../figures/interim_comparison.png)
