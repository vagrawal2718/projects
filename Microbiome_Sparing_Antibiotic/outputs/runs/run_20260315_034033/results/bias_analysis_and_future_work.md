# Model Bias Analysis, Attempted Fixes, and Literature-Supported Future Directions

**Author:** Vishakha Agrawal, Lab for Spatial Informatics, IIIT Hyderabad
**Date:** April 2026
**Pipeline:** Microbiome-Sparing Antibiotic Discovery (5-Model Selectivity Pipeline)

---

## 1. Overview

This document provides a systematic analysis of prediction biases identified across all five ML models in our antibiotic selectivity pipeline, documents the fixes we attempted and their outcomes, and proposes literature-supported directions for further improvement. All results cited are from our pipeline run (run_20260315_034033) on the Ada HPC cluster.

---

## 2. Complete Bias Inventory

### 2.1 D-MPNN: Phosphate Group Bias (Severe)

**Observation:** The original D-MPNN (depth=3, hidden=300, single final model) assigns disproportionately high selectivity scores to phosphate-containing compounds such as nucleotide cofactors (ATP, NADPH, coenzyme-A). From our diagnostic analysis:

- Phosphate/non-phosphate mean S ratio: 3.1x (vs 1.3x for RF)
- The top 10 ranked compounds for E. coli (t=10) are entirely cofactors and nucleotides (ATP S=0.9996, NADPH S=0.9998)
- These are biologically implausible antibiotic candidates

**Root cause:** The D-MPNN message-passing mechanism aggregates information from local atomic neighborhoods. Phosphate groups create distinctive subgraph patterns (P atoms bonded to multiple oxygens) that are rare in the training data but strongly associated with bioactivity labels in ChEMBL, where phosphorylated compounds appear in kinase assays alongside antibacterial screens. The model overfits to phosphate as a general "bioactivity" signal rather than learning it as an antibiotic-specific feature.

**Impact:** Renders the old D-MPNN's top candidate rankings unusable for drug prioritization.

### 2.2 D-MPNN: Probability Saturation (Severe)

**Observation:** The single final model (trained on 100% data, no validation set, no early stopping) pushes predicted probabilities toward 0 or 1:

- 4,153 of 6,739 Hub compounds (61.6%) receive S < 0.01
- Only 646 compounds (9.6%) fall in the mid-range 0.2 < S < 0.8
- 114 compounds receive S > 0.95

**Root cause:** Training without a validation set means no early stopping. The model trains until all training examples are classified with near-certainty, and this overconfidence propagates to screening predictions. This is a well-documented phenomenon in deep neural networks (Guo et al., ICML 2017).

**Impact:** Compresses the usable dynamic range, making it impossible to distinguish moderately selective from highly selective candidates.

### 2.3 CheMeleon (Frozen): Small Molecule / Low MW Bias (Moderate)

**Observation:** CheMeleon's top-50 candidates are biased toward smaller molecules:

- Top-50 median MW = 302 Da vs Hub median MW = 358 Da
- 6 compounds below 200 Da in top-50 (vs 2 for RF)
- Methenamine (MW = 140 Da) ranks #1 with S = 1.000

**Root cause:** The CheMeleon encoder was pretrained on approximately 1 million compounds from diverse assays (Burns et al., arXiv:2506.15792v2, 2026). Small molecules produce simpler molecular graphs with fewer message-passing steps, resulting in more confident (lower-entropy) encoder representations. Since only the FFN head is trainable (~10K parameters), the classification head overfits to these high-confidence representations from the frozen encoder.

**Impact:** Inflates rankings of fragments and small molecules that may lack sufficient pharmacophoric features for meaningful antibacterial activity. However, CheMeleon still contributes useful signal to consensus (2.3x antibiotic enrichment, 4 antibiotics in top-50).

### 2.4 MoLFormer-XL: Probability Saturation (Severe)

**Observation:** Similar to D-MPNN, MoLFormer pushes most predictions to extremes:

- 3,571 of 6,739 compounds (53.0%) receive S < 0.01
- Only 826 compounds (12.3%) in mid-range
- 36 compounds at S > 0.95

**Root cause:** Same as D-MPNN: single final model screening without ensemble averaging. The transformer architecture's softmax attention mechanism can amplify overconfident predictions when trained without calibration.

**Impact:** Low antibiotic enrichment (0.58x for E. coli), indicating the model's top rankings don't preferentially select antibiotics.

### 2.5 Cross-Model: Gut Harm Underestimation for Specific Drug Classes (Moderate)

**Observation:** All graph-based models (D-MPNN, D-MPNN+RDKit, CheMeleon, MoLFormer) underestimate P_gut for clinically important broad-spectrum drugs:

- Clindamycin (lincosamide, causes C. difficile): P_gut ranges from 0.063 (D-MPNN+RDKit) to 0.444 (D-MPNN old). Clinical expectation: P_gut should be near 1.0.
- Ciprofloxacin (fluoroquinolone, kills 39/40 Maier strains): P_gut = 0.730 in D-MPNN+RDKit (should be > 0.95). RF correctly assigns P_gut = 0.952.

**Root cause:** The Maier et al. (Nature 2018, 2021) training data contains limited examples of lincosamides and fluoroquinolones. Graph neural networks learn abstract structural representations that may miss pharmacokinetic correlates of gut toxicity when those drug classes are underrepresented. RF handles these drugs better because Morgan fingerprints (ECFP4) explicitly encode substructural motifs (aromatic nitrogen patterns in fluoroquinolones, chloro-substituted pyrrolidine in clindamycin) that correlate with broad-spectrum activity.

**Impact:** Causes the narrow vs. broad-spectrum validation test to fail (mean S for broad-spectrum drugs exceeds mean S for narrow-spectrum drugs) for all graph-based models.

### 2.6 RF: No Significant Biases Identified

RF shows minimal phosphate bias (1.3x ratio), best calibration (14 saturated compounds), correct narrow/broad drug ordering, and highest antibiotic enrichment. The only limitation is that RF cannot capture long-range electronic effects or 3D geometry, but this does not manifest as a systematic bias in our screening results.

---

## 3. Fixes Attempted: D-MPNN+RDKit Retraining

### 3.1 Motivation

The D-MPNN's phosphate bias and probability saturation were the most severe biases in the pipeline, rendering its top candidate rankings unusable. We hypothesized that two interventions could address these issues:

1. **RDKit 2D molecular descriptors:** Adding 200 global molecular features (MW, LogP, TPSA, ring counts, hydrogen bond donors/acceptors, etc.) should allow the model to distinguish cofactors (high MW, high TPSA, many phosphate oxygens) from drug-like molecules. This approach was introduced by Yang et al. (JCIM, 2019) and used in both the Stokes et al. (Cell, 2020) and Wong et al. (Nature, 2024) antibiotic discovery campaigns.

2. **Ensemble screening:** Averaging predictions from 5 fold models (instead of using a single final model trained on all data) should smooth overconfident predictions, improving calibration. Lakshminarayanan et al. (NeurIPS, 2017) showed deep ensembles provide well-calibrated uncertainty estimates.

### 3.2 Architecture

We matched the Stokes et al. (Cell, 2020) architecture as closely as possible:

| Parameter | Our D-MPNN (old) | Our D-MPNN+RDKit (new) | Stokes et al. |
|-----------|-----------------|----------------------|--------------|
| Depth | 3 | 5 | 5 |
| Hidden dim | 300 | 1600 | 1600 |
| Dropout | 0.0 | 0.35 | 0.35 |
| FFN layers | 2 | 2 | 1 |
| Features | None | v1_rdkit_2d_normalized (200) | rdkit_2d_normalized (200) |
| Ensemble | 1 final model | 5 fold models | 20 models |
| Training set | 1.2K-44K per task | 1.2K-44K per task | 2,335 compounds |
| Trainable params | ~200K | ~10.8M | ~5.6M |

The Stokes command was: `python train.py --depth 5 --hidden_size 1600 --dropout 0.35 --features_generator rdkit_2d_normalized --no_features_scaling --ffn_num_layers 1 --ensemble 20` (confirmed from a DNAnexus reproduction blog post and the Stokes supplementary materials).

### 3.3 Results: What Improved

| Metric | D-MPNN (old) | D-MPNN+RDKit (new) | Improvement |
|--------|-------------|-------------------|-------------|
| Saturation (S < 0.01) | 4,153 / 6,739 | 212 / 6,739 | 95% reduction |
| Mid-range (0.2 < S < 0.8) | 646 | 1,612 | 2.5x more usable scores |
| S > 0.95 | 114 | 0 | Eliminated |
| Phosphate bias ratio | 3.1x | 2.0x | 35% reduction |
| Top-10 quality | All nucleotides/cofactors | Real drug candidates (asciminib, gepotidacin, AZD3965) | Pharmaceutically meaningful |
| Stokes correlation (E. coli) | rho = 0.154 | rho = 0.187 | +0.033 |
| Stokes correlation (P. aeruginosa) | rho = 0.032 | rho = 0.239 | +0.207 |
| Antibiotics in top-50 (E. coli) | 1 | 4 | 4x |

### 3.4 Results: What Did Not Improve

| Metric | D-MPNN (old) | D-MPNN+RDKit (new) | Change |
|--------|-------------|-------------------|--------|
| ROC-AUC (E. coli) | 0.8525 | 0.8408 | -0.012 |
| ROC-AUC (S. aureus) | 0.8544 | 0.8386 | -0.016 |
| ROC-AUC (6/7 tasks) | Higher | Lower | Decreased |
| Narrow > Broad validation | Wrong | Wrong | No improvement |
| Enrichment (E. coli) | 0.58x | 0.58x | Same |
| Clindamycin P_gut | 0.444 | 0.063 | Worse |

### 3.5 Interpretation

The D-MPNN+RDKit retraining achieved its primary goals (fixing saturation and phosphate bias) but introduced a tradeoff: the larger model (10.8M parameters) slightly overfits relative to the smaller D-MPNN (200K parameters) on our dataset sizes (1.2K to 44K samples per task). This aligns with the observation from the DNAnexus blog reproducing Stokes' work: "the training set they provide consists of 2,560 molecules, of which only 120 are positive for antibiotic activity, which is very small compared to the number of free parameters in the model (5.6 million)."

The key thesis finding is that **raw classification accuracy (ROC-AUC) does not predict screening utility**. The old D-MPNN has higher ROC-AUC but produces unusable rankings. The new D-MPNN+RDKit has lower ROC-AUC but produces pharmaceutically meaningful rankings with properly calibrated probability estimates.

### 3.6 Residual Phosphate Bias

The phosphate bias was reduced from 3.1x to 2.0x but not eliminated. RDKit descriptors encode MW and TPSA, which partially distinguish cofactors from drug-like molecules, but phosphorylated drug-like molecules (e.g., nucleotide analogs used as antivirals) still receive elevated scores. Complete elimination would require explicit filtering or domain-specific feature engineering targeting phosphate groups.

---

## 4. Biases Not Addressed (and Why)

### 4.1 MoLFormer Saturation

MoLFormer's probability saturation (3,571 compounds at S < 0.01) was not addressed because it would require either:

- Retraining with ensemble screening (same approach as D-MPNN+RDKit), which would require extensive GPU time for the transformer model
- Post-hoc calibration (see Future Work)

MoLFormer's primary value in the pipeline is as a consensus contributor using a fundamentally different molecular representation (SMILES tokens vs. graph structure), not as a standalone screening model.

### 4.2 CheMeleon MW Bias

Not addressed because:

- Full fine-tuning risks overfitting on our small gut datasets (1,177 compounds)
- The frozen encoder design is a deliberate architectural choice for small-data regimes
- CheMeleon's bias is moderate and does not dominate consensus rankings

### 4.3 Clindamycin/Ciprofloxacin Gut Misclassification

Not fixable within the current pipeline because the root cause is insufficient training data for lincosamides and fluoroquinolones in the Maier et al. dataset. Adding class-weighted loss functions could partially address the imbalance, but the fundamental limitation is data coverage, not architecture.

---

## 5. Literature-Supported Future Directions

### 5.1 Post-Hoc Probability Calibration

**Method:** Temperature scaling (Guo et al., ICML 2017) or Platt scaling (Platt, 1999).

**How it works:** After training, a single scalar parameter T (temperature) is learned on a held-out validation set to divide logits before the sigmoid/softmax function. This corrects systematic overconfidence or underconfidence without changing the model's discriminative ability (rank ordering preserved). For binary classification: P_calibrated = sigmoid(logit / T).

**Expected benefit:** Could fix MoLFormer and old D-MPNN saturation without retraining. The original work showed that on most neural network architectures, temperature scaling is effective at calibrating predictions with just one parameter.

**Feasibility:** Very high. Requires only validation set predictions (already available from fold models). Approximately 1 hour of implementation and testing.

**References:**
- Guo, C., Pleiss, G., Sun, Y., and Weinberger, K. Q. "On Calibration of Modern Neural Networks." ICML 2017.
- Platt, J. "Probabilistic Outputs for Support Vector Machines and Comparisons to Regularized Likelihood Methods." Advances in Large Margin Classifiers, 1999.

### 5.2 Larger Ensemble Size

**Method:** Train 20-model ensembles instead of 5-fold ensembles.

**How it works:** Stokes et al. (Cell, 2020) used `--ensemble 20` in their chemprop training, creating 20 independently initialized models trained on the same data with different random seeds. Predictions are averaged across all 20 models. Wong et al. (Nature, 2024) used ensembles of 10 models for their MRSA campaign.

**Expected benefit:** More models in the ensemble further smooth overconfident predictions and reduce variance. Our 5-fold ensemble already reduced saturation from 4,153 to 212 compounds. A 20-model ensemble could potentially reduce this further.

**Feasibility:** Medium. Would require approximately 4x the training time (~32 hours on Ada HPC with 3 GPUs). Disk space for 140 additional model files (~20 GB).

**References:**
- Stokes, J. M. et al. "A Deep Learning Approach to Antibiotic Discovery." Cell 180(2), 688-702.e13, 2020.
- Wong, F. et al. "Discovery of a Structural Class of Antibiotics with Explainable Deep Learning." Nature 626, 177-185, 2024.
- Lakshminarayanan, B., Pritzel, A., and Blundell, C. "Simple and Scalable Predictive Uncertainty Estimation Using Deep Ensembles." NeurIPS 2017.

### 5.3 Hyperparameter Optimization

**Method:** Automated hyperparameter search (Bayesian optimization or random search) for depth, hidden_dim, dropout, learning rate, and FFN architecture.

**How it works:** Our D-MPNN+RDKit used hyperparameters copied directly from Stokes et al. (depth=5, hidden=1600, dropout=0.35). However, Stokes trained on 2,335 compounds with 120 positives (5.1% positive rate), while our tasks range from 1,177 to 43,837 compounds with varying positive rates. Optimal hyperparameters are dataset-dependent. Chemprop v2 (Heid et al., JCIM 2024) includes built-in hyperparameter optimization functionality.

**Expected benefit:** Could recover the ROC-AUC loss observed when scaling from depth=3/hidden=300 to depth=5/hidden=1600. A smaller model (e.g., depth=4, hidden=800) might achieve better calibration while maintaining the benefits of RDKit features.

**Feasibility:** Medium to high effort. Requires 2-3 days of GPU time on Ada for a full hyperparameter search across 7 tasks.

**References:**
- Heid, E. et al. "Chemprop: A Machine Learning Package for Chemical Property Prediction." JCIM 64(1), 9-17, 2024.
- Yang, K. et al. "Analyzing Learned Molecular Representations for Property Prediction." JCIM 59(8), 3370-3388, 2019.

### 5.4 Evidential Deep Learning for Uncertainty Quantification

**Method:** Replace standard sigmoid output with an evidential distribution (Dirichlet prior for classification).

**How it works:** Instead of predicting a single probability, the model predicts parameters of a Dirichlet distribution, from which both the expected probability and an uncertainty estimate are derived. High-uncertainty predictions can be flagged or filtered during screening. An evidential variant of chemprop has been developed (Amini et al., available at github.com/aamini/chemprop).

**Expected benefit:** Would provide per-compound uncertainty estimates, enabling confidence-weighted consensus scoring. Could identify compounds where model predictions are unreliable (e.g., out-of-distribution scaffolds).

**Feasibility:** Medium effort. Requires modifying the training paradigm and loss function. A working implementation exists but has not been integrated into chemprop v2.

**References:**
- Amini, A. et al. "Deep Evidential Regression." NeurIPS 2020.
- Soleimany, A. P. et al. "Evidential Deep Learning for Guided Molecular Property Prediction and Discovery." ACS Central Science 7(8), 1356-1367, 2021.

### 5.5 Shapley Value-Based Interpretability

**Method:** Use SHAP (Shapley Additive Explanations) or the Shapley value analysis built into chemprop v2.

**How it works:** Chemprop v2 (2025 preprint) introduces Shapley value analysis that enables feature-level and per-atom/bond explanations by masking specific features, atoms, and bonds to quantify their importance. This is more principled than our BRICS occlusion approach, which decomposes molecules into fragments and predicts each independently (producing near-zero scores due to loss of molecular context).

**Expected benefit:** Would provide decomposable, theoretically grounded attribution for graph-based models (D-MPNN, CheMeleon), resolving the "holistic non-decomposable prediction" limitation we identified in our interpretability analysis.

**Feasibility:** Medium. Requires upgrading to the latest chemprop v2 release and running Shapley analysis on the 15 consensus candidates.

**References:**
- Graff, D. E. et al. "Chemprop v2: An Efficient, Modular Machine Learning Package for Chemical Property Prediction." ChemRxiv preprint, September 2025.
- Lundberg, S. M. and Lee, S. I. "A Unified Approach to Interpreting Model Predictions." NeurIPS 2017.

### 5.6 Data Augmentation for Underrepresented Drug Classes

**Method:** Augment the Maier gut harm training data with additional lincosamide and fluoroquinolone examples.

**How it works:** The clindamycin/ciprofloxacin P_gut misclassification is fundamentally a data coverage problem. Potential approaches include:

- Synthetic minority oversampling (SMOTE) for underrepresented drug classes
- Incorporating additional gut toxicity data from Maier et al. (Nature 2021, extended to 1,197 drugs)
- Using COCONUT or ChEMBL gut toxicity assay data as supplementary training examples

**Expected benefit:** Would directly address the validation test failure by improving P_gut predictions for broad-spectrum antibiotics.

**Feasibility:** Requires careful data curation to avoid label noise. The Maier 2021 extension data is already in our pipeline but may not include sufficient lincosamide/fluoroquinolone examples.

**References:**
- Maier, L. et al. "Extensive Impact of Non-Antibiotic Drugs on Human Gut Bacteria." Nature 555, 623-628, 2018.
- Maier, L. et al. "Unravelling the Collateral Damage of Antibiotics on Gut Bacteria." Nature 599, 120-124, 2021.

---

## 6. Prioritized Recommendations

For immediate thesis impact (ordered by effort-to-benefit ratio):

| Priority | Improvement | Effort | Expected Impact | Status |
|----------|------------|--------|-----------------|--------|
| 1 | Temperature scaling (post-hoc) | 1 hour | Fix MoLFormer + old D-MPNN saturation | Future work |
| 2 | Hyperparameter optimization for D-MPNN+RDKit | 2-3 days | Recover ROC-AUC while keeping calibration gains | Future work |
| 3 | 20-model ensemble | 32 hours GPU | Further calibration improvement | Future work |
| 4 | Shapley interpretability | 1 day | Resolve non-decomposability limitation | Future work |
| 5 | Evidential deep learning | 3-5 days | Per-compound uncertainty | Future work |
| 6 | Data augmentation for gut model | 1 week | Fix validation test | Future work |

For the thesis, items 1-3 are best described as "proposed future work with literature support," while the bias analysis and D-MPNN+RDKit retraining results constitute the completed experimental contribution.

---

## 7. Conclusion

Our 5-model pipeline reveals a fundamental tension in ML-guided antibiotic discovery: **classification accuracy and screening utility are not the same thing**. The old D-MPNN achieves higher ROC-AUC than D-MPNN+RDKit but produces unusable rankings dominated by cofactors. RF, with the simplest architecture, produces the most reliable screening results.

The D-MPNN+RDKit retraining demonstrates that the Stokes et al. architecture (depth=5, hidden=1600, RDKit features, ensemble screening) successfully addresses probability saturation and phosphate bias, but at the cost of reduced discriminative accuracy on our dataset sizes. This finding contributes to the growing understanding that model calibration and bias removal are at least as important as raw predictive performance for virtual screening applications.

The multi-model consensus approach, where 5 architecturally diverse models must independently agree on a candidate, remains the most robust strategy for identifying high-confidence selective antibiotic candidates. The 3 compounds achieving 5/5 model agreement (retapamulin, AFN-1252, trimetrexate) represent the highest-confidence predictions of our pipeline and the strongest candidates for experimental validation.

---

*Microbiome-Sparing Antibiotic Discovery Pipeline | April 2026 | IIIT Hyderabad*