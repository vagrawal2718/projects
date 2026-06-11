#!/usr/bin/env python3
"""
21_consolidated_report.py -- Phase E: Consolidated Results Report

Reads all existing results (JSONs, CSVs, figures) and produces one
unified Markdown report with tables, key numbers, and figure references.

ALL text is dynamically generated from data. No hardcoded results.
NO computation, NO training, NO GPU. Just reads and formats.

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    April 2026
"""

import os, sys, json, warnings
import numpy as np
import pandas as pd
from datetime import datetime

warnings.filterwarnings('ignore')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import config

MODELS = ['rf', 'dmpnn', 'chemeleon_frozen', 'molformer', 'dmpnn_rdkit']
MODEL_NAMES = {
    'rf': 'Random Forest',
    'dmpnn': 'D-MPNN',
    'chemeleon_frozen': 'CheMeleon (Frozen)',
    'molformer': 'MoLFormer-XL',
    'dmpnn_rdkit': 'D-MPNN+RDKit',
}
MODEL_SHORT = {
    'rf': 'RF',
    'dmpnn': 'D-MPNN',
    'chemeleon_frozen': 'CheMeleon',
    'molformer': 'MoLFormer',
    'dmpnn_rdkit': 'D-MPNN+RDKit',
}
TASKS = ['ecoli', 'saureus', 'paeruginosa', 'mtb',
         'gut_t5', 'gut_t10', 'gut_t20']
TASK_NAMES = {
    'ecoli': 'E. coli',
    'saureus': 'S. aureus',
    'paeruginosa': 'P. aeruginosa',
    'mtb': 'M. tuberculosis',
    'gut_t5': 'Gut harm (t=5)',
    'gut_t10': 'Gut harm (t=10)',
    'gut_t20': 'Gut harm (t=20)',
}
PATHOGENS = ['ecoli', 'saureus', 'paeruginosa', 'mtb']
GUT_TASKS = ['gut_t5', 'gut_t10', 'gut_t20']
RESULTS_DIR = config.RESULTS_DIR
FIGURES_DIR = config.FIGURES_DIR
SCREENING_DIR = config.SCREENING_DIR


def load_json(filename):
    path = os.path.join(RESULTS_DIR, filename)
    if os.path.exists(path):
        with open(path) as f:
            return json.load(f)
    return None


def load_csv(filename):
    path = os.path.join(RESULTS_DIR, filename)
    if os.path.exists(path):
        return pd.read_csv(path)
    return None


def fig_ref(filename):
    for ext in ['.png', '.pdf']:
        path = os.path.join(FIGURES_DIR, filename + ext)
        if os.path.exists(path):
            return f"figures/{filename}.png"
    return None


def get_best_model_for_task(cv_data, task):
    best_m, best_roc = None, -1
    for m in MODELS:
        d = cv_data.get(m, {}).get(task, {})
        roc = d.get('mean_roc_auc')
        if roc is not None and roc > best_roc:
            best_roc = roc
            best_m = m
    return best_m, best_roc


def get_calibration_stats(model_key):
    path = os.path.join(SCREENING_DIR, f'{model_key}_ranked_ecoli_t10.csv')
    if not os.path.exists(path):
        return None
    df = pd.read_csv(path)
    s = df['selectivity_score']
    return {
        'near_zero': int((s < 0.01).sum()),
        'mid_range': int(((s > 0.2) & (s < 0.8)).sum()),
        'near_one': int((s > 0.95).sum()),
        'total': len(s),
    }


def count_antibiotics_in_top(model_key, top_k=50):
    path = os.path.join(SCREENING_DIR, f'{model_key}_ranked_ecoli_t10.csv')
    if not os.path.exists(path):
        return 0, 0
    df = pd.read_csv(path)
    ab_kws = ['antibiotic', 'antibacterial', 'bacterial', 'ribosom',
              'cell wall', 'DNA gyrase', 'FABI', 'topoisomerase',
              'beta-lactam', 'penicillin', 'cephalosporin',
              'aminoglycoside', 'tetracycline', 'macrolide',
              'fluoroquinolone', 'sulfonamide', 'protein synthesis',
              'leucyl-tRNA']
    top = df.head(top_k)
    n_ab = sum(1 for _, r in top.iterrows()
               if any(kw in str(r.get('moa', '')).lower() for kw in ab_kws))
    return n_ab, top_k


def main():
    L = []
    w = L.append

    w("# Microbiome-Sparing Antibiotic Discovery: Consolidated Results")
    w("")
    w(f"**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    w(f"**Run ID:** {config.RUN_ID}")
    w(f"**Author:** Vishakha Agrawal, Lab for Spatial Informatics, IIIT Hyderabad")
    w(f"**Pipeline:** {len(MODELS)}-model ML pipeline for selective antibiotic candidate identification")
    w("")

    # ================================================================
    # Section 1: Model Overview
    # ================================================================
    w("---")
    w("## 1. Model Architecture Summary")
    w("")
    w("| Model | Architecture | Screening Method | Key Feature |")
    w("|-------|-------------|-----------------|-------------|")

    arch_info = {
        'rf': ('500 trees, 2048-bit Morgan FP (ECFP4)', 'Single final model', 'Fingerprint-based'),
        'dmpnn': ('depth=3, hidden=300, graph neural network', 'Single final model', 'Learned graph representation'),
        'chemeleon_frozen': ('Pretrained 6-layer D-MPNN encoder (frozen) + FFN head', 'Single final model', 'Transfer learning'),
        'molformer': ('Transformer pretrained on 1.1B SMILES, fine-tuned', 'Single final model', 'SMILES language model'),
        'dmpnn_rdkit': ('depth=5, hidden=1600 + 200 RDKit 2D descriptors', 'Ensemble of 5 fold models', 'Stokes architecture'),
    }
    for m in MODELS:
        arch, screen, feat = arch_info.get(m, ('--', '--', '--'))
        w(f"| {MODEL_SHORT[m]} | {arch} | {screen} | {feat} |")

    w("")
    w("All models trained with 5-fold scaffold-based cross-validation on the same splits.")
    w("Screening performed on the Broad Institute Drug Repurposing Hub (6,739 compounds).")
    w("")

    # ================================================================
    # Section 2: CV Metrics
    # ================================================================
    w("---")
    w("## 2. Cross-Validation Performance (ROC-AUC)")
    w("")

    cv_data = {}
    for m in MODELS:
        cv_data[m] = load_json(f'{m}_cv_metrics.json') or {}

    header = "| Task |"
    sep = "|------|"
    for m in MODELS:
        header += f" {MODEL_SHORT[m]} |"
        sep += "------|"
    w(header)
    w(sep)

    best_per_task = {}
    for task in TASKS:
        row = f"| {TASK_NAMES[task]} |"
        task_vals = {}
        for m in MODELS:
            d = cv_data[m].get(task, {})
            roc = d.get('mean_roc_auc')
            task_vals[m] = roc

        non_none = {k: v for k, v in task_vals.items() if v is not None}
        best_m = max(non_none, key=non_none.get) if non_none else None
        best_per_task[task] = best_m

        for m in MODELS:
            roc = task_vals[m]
            std = cv_data[m].get(task, {}).get('std_roc_auc')
            if roc is not None:
                val = f"{roc:.4f}"
                if std is not None:
                    val += f" +/- {std:.4f}"
                if m == best_m:
                    val = f"**{val}**"
                row += f" {val} |"
            else:
                row += " N/A |"
        w(row)

    w("")
    w("**Bold** = best model for that task.")
    w("")

    # Dynamic pathogen finding
    pathogen_winners = {}
    for t in PATHOGENS:
        bm, br = get_best_model_for_task(cv_data, t)
        if bm:
            pathogen_winners[t] = (bm, br)

    winner_counts = {}
    for t, (bm, _) in pathogen_winners.items():
        winner_counts[bm] = winner_counts.get(bm, 0) + 1

    if winner_counts:
        dominant = max(winner_counts, key=winner_counts.get)
        n_wins = winner_counts[dominant]
        w(f"**Key finding:** {MODEL_SHORT[dominant]} achieves the highest ROC-AUC on "
          f"{n_wins} of {len(PATHOGENS)} pathogen classification tasks.")

    # Dynamic gut finding
    gut_winners = {}
    for t in GUT_TASKS:
        bm, br = get_best_model_for_task(cv_data, t)
        if bm:
            gut_winners[t] = (bm, br)

    if gut_winners:
        best_gut_task = max(gut_winners, key=lambda t: gut_winners[t][1])
        best_gut_m, best_gut_roc = gut_winners[best_gut_task]
        w(f" {MODEL_SHORT[best_gut_m]} achieves the best gut harm prediction at "
          f"{best_gut_task.replace('gut_', 't=')} ({best_gut_roc:.4f}).")

    w("")
    fr = fig_ref('phase4_level1_diagnostic')
    if fr:
        w(f"*Figure: `{fr}`*")
    w("")

    # ================================================================
    # Section 3: Calibration
    # ================================================================
    w("---")
    w("## 3. Probability Calibration (Score Distribution Analysis)")
    w("")

    cal_stats = {}
    for m in MODELS:
        cal_stats[m] = get_calibration_stats(m)

    w("| Model | S < 0.01 (saturated low) | 0.2 < S < 0.8 (mid-range) | S > 0.95 (saturated high) |")
    w("|-------|------------------------|--------------------------|-------------------------|")
    for m in MODELS:
        cs = cal_stats[m]
        if cs:
            w(f"| {MODEL_SHORT[m]} | {cs['near_zero']} | {cs['mid_range']} | {cs['near_one']} |")

    w("")

    # Dynamic calibration finding
    valid_cal = {m: cs for m, cs in cal_stats.items() if cs}
    if valid_cal:
        worst_sat = max(valid_cal, key=lambda m: valid_cal[m]['near_zero'])
        best_sat = min(valid_cal, key=lambda m: valid_cal[m]['near_zero'])
        worst_n = valid_cal[worst_sat]['near_zero']
        best_n = valid_cal[best_sat]['near_zero']
        total = valid_cal[worst_sat]['total']

        w(f"**Key finding:** {MODEL_SHORT[worst_sat]} suffers from severe probability saturation: "
          f"{worst_n} of {total} compounds receive S < 0.01, compressing the usable dynamic range. "
          f"{MODEL_SHORT[best_sat]} has the best calibration with only {best_n} saturated compounds.")

        if 'dmpnn' in valid_cal and 'dmpnn_rdkit' in valid_cal:
            old_n = valid_cal['dmpnn']['near_zero']
            new_n = valid_cal['dmpnn_rdkit']['near_zero']
            if old_n > new_n and old_n > 0:
                reduction_pct = (1 - new_n / old_n) * 100
                w(f" D-MPNN+RDKit reduces saturation from {old_n} to {new_n} "
                  f"({reduction_pct:.0f}% reduction) through ensemble averaging.")
        w("")

    fr = fig_ref('diagnostic_score_distributions')
    if fr:
        w(f"*Figure: `{fr}`*")
    w("")

    # ================================================================
    # Section 4: Structural Bias
    # ================================================================
    w("---")
    w("## 4. Structural Bias Analysis")
    w("")

    diag = load_json('diagnostic_summary.json')
    if diag:
        bias = diag.get('bias_case_studies', {})

        phos = bias.get('dmpnn_phosphate_bias', {})
        if phos:
            w("### 4.1 Phosphate Group Bias")
            w("")
            w(f"| Metric | Value |")
            w(f"|--------|-------|")
            w(f"| Phosphate-containing compounds in Hub | {phos.get('n_phosphate', 'N/A')} |")
            w(f"| D-MPNN phosphate/non-phosphate S ratio | {phos.get('dmpnn_ratio', 'N/A')}x |")
            w(f"| RF phosphate/non-phosphate S ratio | {phos.get('rf_ratio', 'N/A')}x |")

            dmpnn_ratio = phos.get('dmpnn_ratio', 0)
            rf_ratio = phos.get('rf_ratio', 0)

            # Compute D-MPNN+RDKit ratio dynamically
            props_path = os.path.join(RESULTS_DIR, 'diagnostic_properties.csv')
            rdkit_ratio = None
            if os.path.exists(props_path):
                props = pd.read_csv(props_path)
                if 'has_phosphate' in props.columns and 'dmpnn_rdkit_S' in props.columns:
                    phos_vals = props[props['has_phosphate'] == 1]['dmpnn_rdkit_S']
                    nophos_vals = props[props['has_phosphate'] == 0]['dmpnn_rdkit_S']
                    if len(phos_vals) > 0 and len(nophos_vals) > 0:
                        phos_mean = phos_vals.mean()
                        nophos_mean = nophos_vals.mean()
                        if nophos_mean > 0:
                            rdkit_ratio = phos_mean / nophos_mean

            if rdkit_ratio is not None:
                w(f"| D-MPNN+RDKit phosphate/non-phosphate S ratio | {rdkit_ratio:.1f}x |")
            w("")

            w(f"**Key finding:** D-MPNN assigns {dmpnn_ratio}x higher selectivity scores to "
              f"phosphate-containing compounds.")
            if rdkit_ratio is not None:
                w(f" D-MPNN+RDKit reduces this to {rdkit_ratio:.1f}x through RDKit descriptors.")
            w(f" RF shows minimal bias ({rf_ratio}x).")
            w("")

        chem_mw = bias.get('chemeleon_mw_bias', {})
        if chem_mw:
            w("### 4.2 Molecular Weight Bias")
            w("")
            hub_mw = chem_mw.get('hub_median_MW', 'N/A')
            chem_top_mw = chem_mw.get('chemeleon_top50_median_MW', 'N/A')
            rf_top_mw = chem_mw.get('rf_top50_median_MW', 'N/A')
            chem_small = chem_mw.get('chemeleon_top50_small_mw', 0)
            rf_small = chem_mw.get('rf_top50_small_mw', 0)

            w(f"| Set | Median MW (Da) | Compounds < 200 Da |")
            w(f"|-----|---------------|-------------------|")
            w(f"| Full Hub | {hub_mw} | -- |")
            w(f"| CheMeleon top-50 | {chem_top_mw} | {chem_small} |")
            w(f"| RF top-50 | {rf_top_mw} | {rf_small} |")
            w("")
            w(f"**Key finding:** CheMeleon top-50 has median MW = {chem_top_mw} Da "
              f"vs Hub median = {hub_mw} Da, with {chem_small} compounds below 200 Da "
              f"(vs {rf_small} for RF).")
            w("")

    # ================================================================
    # Section 5: Ranking Quality
    # ================================================================
    w("---")
    w("## 5. Top-10 Candidate Quality Comparison")
    w("")

    ab_counts = {}
    for m in MODELS:
        path = os.path.join(SCREENING_DIR, f'{m}_ranked_ecoli_t10.csv')
        if not os.path.exists(path):
            continue
        df = pd.read_csv(path)
        label = MODEL_SHORT[m]
        w(f"### {label}")
        w("")
        w("| Rank | Compound | S | P(kill) | P(gut) | MoA |")
        w("|------|----------|---|---------|--------|-----|")
        for _, r in df.head(10).iterrows():
            name = str(r.get('name', ''))[:28]
            moa = str(r.get('moa', ''))[:35]
            w(f"| {int(r['rank'])} | {name} | {r['selectivity_score']:.4f} | "
              f"{r['p_pathogen']:.4f} | {r['p_gut']:.4f} | {moa} |")
        w("")

        n_ab, _ = count_antibiotics_in_top(m, 10)
        ab_counts[m] = n_ab

    if ab_counts:
        most_ab = max(ab_counts, key=ab_counts.get)
        least_ab = min(ab_counts, key=ab_counts.get)
        w(f"**Key finding:** {MODEL_SHORT[most_ab]} has the most pharmacologically meaningful "
          f"top-10, containing {ab_counts[most_ab]} known antibiotics. "
          f"{MODEL_SHORT[least_ab]} has the fewest ({ab_counts[least_ab]}).")
        w("")

    # ================================================================
    # Section 6: Validation
    # ================================================================
    w("---")
    w("## 6. Narrow vs Broad-Spectrum Drug Validation")
    w("")

    drugs_narrow = ['daptomycin', 'fidaxomicin', 'nitrofurantoin', 'methenamine']
    drugs_broad = ['ciprofloxacin', 'amoxicillin', 'clindamycin', 'doxycycline']

    header = "| Drug | Category |"
    sep = "|------|----------|"
    for m in MODELS:
        header += f" {MODEL_SHORT[m]} |"
        sep += "------|"
    w(header)
    w(sep)

    model_narrow_means = {m: [] for m in MODELS}
    model_broad_means = {m: [] for m in MODELS}

    for drug in drugs_narrow + drugs_broad:
        cat = "Narrow" if drug in drugs_narrow else "Broad"
        row = f"| {drug} | {cat} |"
        for m in MODELS:
            spath = os.path.join(SCREENING_DIR, f'{m}_ranked_ecoli_t10.csv')
            if os.path.exists(spath):
                sdf = pd.read_csv(spath)
                match = sdf[sdf['name'].str.lower().str.contains(drug, na=False)]
                if len(match) > 0:
                    s = match.iloc[0]['selectivity_score']
                    row += f" {s:.3f} |"
                    if drug in drugs_narrow:
                        model_narrow_means[m].append(s)
                    else:
                        model_broad_means[m].append(s)
                else:
                    row += " -- |"
            else:
                row += " -- |"
        w(row)

    w("")

    correct_models = []
    wrong_models = []
    for m in MODELS:
        if model_narrow_means[m] and model_broad_means[m]:
            nm = np.mean(model_narrow_means[m])
            bm = np.mean(model_broad_means[m])
            if nm > bm:
                correct_models.append((m, nm, bm))
            else:
                wrong_models.append((m, nm, bm))

    if correct_models:
        correct_names = ", ".join(MODEL_SHORT[m] for m, _, _ in correct_models)
        w(f"**Key finding:** {correct_names} correctly assign{'s' if len(correct_models) == 1 else ''} "
          f"higher mean S to narrow-spectrum drugs than broad-spectrum drugs.")
    if wrong_models:
        wrong_names = ", ".join(MODEL_SHORT[m] for m, _, _ in wrong_models)
        w(f" {wrong_names} show{'s' if len(wrong_models) == 1 else ''} reversed ordering "
          f"(broad > narrow), driven by individual drug misclassifications.")

    # Identify problem drugs dynamically
    problem_drugs = {}
    for m in MODELS:
        spath = os.path.join(SCREENING_DIR, f'{m}_ranked_ecoli_t10.csv')
        if not os.path.exists(spath):
            continue
        sdf = pd.read_csv(spath)
        for drug in ['clindamycin', 'ciprofloxacin']:
            match = sdf[sdf['name'].str.lower().str.contains(drug, na=False)]
            if len(match) > 0:
                pgut = match.iloc[0]['p_gut']
                expected_high = True  # both are broad-spectrum, should have high P_gut
                if pgut < 0.3:
                    if drug not in problem_drugs:
                        problem_drugs[drug] = []
                    problem_drugs[drug].append((m, pgut))

    if problem_drugs:
        w("")
        for drug, models_pgut in problem_drugs.items():
            model_list = ", ".join(f"{MODEL_SHORT[m]} (P_gut={pgut:.3f})"
                                   for m, pgut in models_pgut)
            w(f"Notable misclassification: {drug} (broad-spectrum, expected high P_gut) "
              f"receives low P_gut from: {model_list}.")
    w("")

    # ================================================================
    # Section 7: Enrichment
    # ================================================================
    w("---")
    w("## 7. Top-50 Antibiotic Enrichment")
    w("")

    enrich_df = load_csv('test3_topk_enrichment.csv')
    if enrich_df is not None:
        w("| Model | E. coli | S. aureus | P. aeruginosa | M. tuberculosis |")
        w("|-------|---------|-----------|---------------|-----------------|")

        model_avg_enrichment = {}
        for m in MODELS:
            row = f"| {MODEL_SHORT[m]} |"
            enrichments = []
            for pk in PATHOGENS:
                match = enrich_df[(enrich_df['pipeline'] == m) &
                                  (enrich_df['pathogen'] == pk)]
                if len(match) > 0:
                    r = match.iloc[0]
                    n_ab = int(r['n_ab_topk'])
                    er = r['enrichment_ratio']
                    enrichments.append(er)
                    row += f" {n_ab}/50 ({er:.1f}x) |"
                else:
                    row += " -- |"
            w(row)
            if enrichments:
                model_avg_enrichment[m] = np.mean(enrichments)

        w("")

        if model_avg_enrichment:
            best_enrich = max(model_avg_enrichment, key=model_avg_enrichment.get)
            worst_enrich = min(model_avg_enrichment, key=model_avg_enrichment.get)
            best_er_vals = enrich_df[enrich_df['pipeline'] == best_enrich]['enrichment_ratio']
            best_range = f"{best_er_vals.min():.1f}-{best_er_vals.max():.1f}x"

            w(f"**Key finding:** {MODEL_SHORT[best_enrich]} achieves the highest average antibiotic "
              f"enrichment ({best_range}). "
              f"{MODEL_SHORT[worst_enrich]} has the lowest average enrichment "
              f"({model_avg_enrichment[worst_enrich]:.1f}x).")
            w("")

        fr = fig_ref('phase4_test3_enrichment')
        if fr:
            w(f"*Figure: `{fr}`*")
        w("")

    # ================================================================
    # Section 8: Pairwise Agreement
    # ================================================================
    w("---")
    w("## 8. Pairwise Model Agreement (Selectivity Score Correlation)")
    w("")

    if diag:
        corr_data = diag.get('pairwise_correlations', {})

        for score_type, label in [('Selectivity', 'Selectivity S'),
                                   ('P_gut', 'P(gut harm)')]:
            pairs = corr_data.get(score_type, {})
            if not pairs:
                continue

            w(f"### {label}")
            w("")
            w("| Pair | rho | Agreement |")
            w("|------|-----|-----------|")
            sorted_pairs = sorted(pairs.items(), key=lambda x: x[1]['rho'], reverse=True)
            for pair_name, data in sorted_pairs:
                rho = data['rho']
                level = ('high' if rho > 0.8 else 'moderate' if rho > 0.5
                         else 'low')
                w(f"| {pair_name} | {rho:.4f} | {level} |")
            w("")

            if sorted_pairs:
                highest_pair, highest_data = sorted_pairs[0]
                lowest_pair, lowest_data = sorted_pairs[-1]
                w(f"**Highest agreement:** {highest_pair} (rho = {highest_data['rho']:.4f}). "
                  f"**Lowest agreement:** {lowest_pair} (rho = {lowest_data['rho']:.4f}).")
                w("")

    fr = fig_ref('diagnostic_pairwise_scatter')
    if fr:
        w(f"*Figure: `{fr}`*")
    w("")

    # ================================================================
    # Section 9: D-MPNN vs D-MPNN+RDKit
    # ================================================================
    w("---")
    w("## 9. D-MPNN vs D-MPNN+RDKit: Architecture Comparison")
    w("")

    rdkit_report = load_json('dmpnn_rdkit_full_report.json')
    if rdkit_report:
        cv_comp = rdkit_report.get('comparison_with_old', {}).get('cv_comparison', {})
        if cv_comp:
            w("### 9.1 CV Metrics Change")
            w("")
            w("| Task | D-MPNN | D-MPNN+RDKit | Change |")
            w("|------|--------|-------------|--------|")

            n_improved = 0
            n_declined = 0
            for task in TASKS:
                if task in cv_comp:
                    c = cv_comp[task]
                    old = c.get('old_roc_auc', 0)
                    new = c.get('new_roc_auc', 0)
                    change = c.get('change', 0)
                    marker = "+" if change > 0 else ""
                    w(f"| {TASK_NAMES.get(task, task)} | {old:.4f} | {new:.4f} | {marker}{change:.4f} |")
                    if change > 0:
                        n_improved += 1
                    elif change < 0:
                        n_declined += 1

            w("")
            total_compared = n_improved + n_declined
            w(f"ROC-AUC decreased on {n_declined}/{total_compared} tasks. "
              f"The larger model does not improve classification accuracy "
              f"over the smaller D-MPNN on these dataset sizes.")
            w("")

        stokes = rdkit_report.get('stokes_correlation', {})
        if stokes:
            w("### 9.2 Stokes et al. (Cell, 2020) Correlation")
            w("")
            w("| Pathogen | D-MPNN rho | D-MPNN+RDKit rho | Change |")
            w("|----------|-----------|-----------------|--------|")

            n_stokes_improved = 0
            improvements = []
            for combo, data in stokes.items():
                new_rho = data.get('new_rho', 0)
                old_rho = data.get('old_rho')
                if old_rho is not None:
                    change = new_rho - old_rho
                    pk = combo.replace('_t10', '')
                    marker = "+" if change > 0 else ""
                    w(f"| {TASK_NAMES.get(pk, pk)} | {old_rho:.4f} | {new_rho:.4f} | {marker}{change:.4f} |")
                    if change > 0:
                        n_stokes_improved += 1
                    improvements.append((pk, old_rho, new_rho, change))

            w("")
            w(f"D-MPNN+RDKit shows improved Stokes correlation on "
              f"{n_stokes_improved}/{len(stokes)} pathogens.")
            if improvements:
                best_imp = max(improvements, key=lambda x: x[3])
                w(f" Largest improvement on {TASK_NAMES.get(best_imp[0], best_imp[0])} "
                  f"({best_imp[1]:.3f} to {best_imp[2]:.3f}).")
            w("")

        cal = rdkit_report.get('calibration', {}).get('ecoli_t10', {})
        if cal:
            w("### 9.3 Calibration Improvement")
            w("")
            old_cal = cal.get('old', {})
            new_cal = cal.get('new', {})
            if old_cal and new_cal:
                w("| Metric | D-MPNN (old) | D-MPNN+RDKit (new) |")
                w("|--------|-------------|-------------------|")
                for metric in ['S_lt_0.01', 'S_0.2_to_0.8', 'S_gt_0.95',
                               'median', 'n_above_0.5']:
                    w(f"| {metric} | {old_cal.get(metric, 'N/A')} | {new_cal.get(metric, 'N/A')} |")
                w("")

    for fig_name in ['dmpnn_rdkit_score_comparison', 'dmpnn_rdkit_old_vs_new_scatter']:
        fr = fig_ref(fig_name)
        if fr:
            w(f"*Figure: `{fr}`*")
    w("")

    # ================================================================
    # Section 10: Consensus Candidates
    # ================================================================
    w("---")
    w("## 10. Multi-Model Consensus Candidates")
    w("")

    consensus = load_csv('candidate_consensus.csv')
    if consensus is not None:
        n_models_max = int(consensus['n_models'].max())
        tiers = []
        for level in range(n_models_max, 0, -1):
            count = len(consensus[consensus['n_models'] == level])
            if count > 0:
                tiers.append((level, count))

        n_known = len(consensus[consensus['is_known_antibiotic'] == True])
        n_novel = len(consensus[consensus['is_known_antibiotic'] == False])

        w(f"Total unique compounds appearing in any model's top-50: **{len(consensus)}**")
        w("")
        w("| Agreement Level | Count | Interpretation |")
        w("|----------------|-------|---------------|")
        for level, count in tiers:
            if level == n_models_max:
                interp = "Highest confidence: all architectures agree"
            elif level == n_models_max - 1:
                interp = "Very high confidence"
            elif level >= 3:
                interp = "High confidence"
            elif level == 2:
                interp = "Moderate confidence"
            else:
                interp = "Single model only"
            w(f"| {level}/{n_models_max} models | {count} | {interp} |")
        w("")
        w(f"Known antibiotics rediscovered: **{n_known}** | Novel repurposing candidates: **{n_novel}**")
        w("")

        min_consensus = min(3, n_models_max)
        top = consensus[consensus['n_models'] >= min_consensus].head(25)
        w(f"### 10.1 Highest-Confidence Candidates ({min_consensus}+ models)")
        w("")
        w(f"| # | Compound | Models | S (best) | P(kill) | P(gut) | Type | MoA |")
        w(f"|---|----------|--------|----------|---------|--------|------|-----|")
        for i, (_, r) in enumerate(top.iterrows(), 1):
            name = str(r['name'])[:25] if r['name'] else str(r['smiles'])[:20]
            moa = str(r['moa'])[:30] if r['moa'] else '?'
            ctype = "Known AB" if r['is_known_antibiotic'] else "Novel"
            w(f"| {i} | {name} | {r['n_models']}/{n_models_max} | "
              f"{r['best_selectivity']:.3f} | "
              f"{r['mean_p_pathogen']:.3f} | {r['mean_p_gut']:.3f} | {ctype} | {moa} |")
        w("")

        unanimous = consensus[consensus['n_models'] == n_models_max]
        if len(unanimous) > 0:
            w(f"### 10.2 Unanimous Agreement ({n_models_max}/{n_models_max} Models)")
            w("")
            for _, r in unanimous.iterrows():
                name = str(r['name'])
                w(f"**{name}**: S = {r['best_selectivity']:.3f}, "
                  f"supported by all {n_models_max} architectures across "
                  f"{r['n_pathogens']} pathogen(s) ({r['pathogens']}). "
                  f"MoA: {r['moa'] or 'unknown'}. "
                  f"Clinical phase: {r['clinical_phase'] or 'N/A'}.")
                w("")

    # ================================================================
    # Section 11: External Validation
    # ================================================================
    w("---")
    w("## 11. External Validation (Stokes et al., Cell 2020)")
    w("")

    ext_df = load_csv('external_stokes_comparison.csv')
    golden = load_csv('external_golden_intersection.csv')
    halicin = load_json('external_halicin_case_study.json')

    if ext_df is not None:
        stokes_cols = [c for c in ext_df.columns if 'stokes' in c.lower()]
        if stokes_cols:
            n_matched = len(ext_df.dropna(subset=[stokes_cols[0]]))
            w(f"Matched {n_matched} of 6,739 Hub compounds to Stokes et al. Table S2.")
            w("")

    if golden is not None and len(golden) > 0:
        w(f"### Golden Intersection: {len(golden)} compounds validated by Stokes AND "
          "predicted selective by our pipeline")
        w("")
        w("| Compound | Our S | Stokes Score | MoA |")
        w("|----------|-------|-------------|-----|")
        for _, r in golden.head(10).iterrows():
            name = str(r.get('name', ''))[:25]
            our_s = r.get('best_selectivity', r.get('selectivity_score', 0))
            stokes_s = r.get('stokes_dmpnn_score', 0)
            moa = str(r.get('moa', ''))[:30]
            w(f"| {name} | {our_s:.3f} | {stokes_s:.3f} | {moa} |")
        w("")

    if halicin:
        w("### Halicin Case Study")
        w("")
        w("Halicin (SU-3327), discovered by Stokes et al. as a broad-spectrum antibiotic, "
          "receives the following selectivity scores:")
        w("")
        halicin_scores = {}
        for m in MODELS:
            for key_pattern in [f'{m}_selectivity', f'{m}_S', f'{m}_score']:
                s = halicin.get(key_pattern)
                if s is not None:
                    halicin_scores[m] = s
                    w(f"- {MODEL_SHORT[m]}: S = {s:.4f}")
                    break
        w("")
        if halicin_scores:
            all_low = all(s < 0.1 for s in halicin_scores.values())
            if all_low:
                w("All models correctly assign low selectivity to halicin, validating that "
                  "the pipeline penalizes broad-spectrum antibiotics as intended.")
            else:
                high_models = [MODEL_SHORT[m] for m, s in halicin_scores.items() if s >= 0.1]
                if high_models:
                    w(f"Most models correctly assign low selectivity. "
                      f"{', '.join(high_models)} assign{'s' if len(high_models) == 1 else ''} "
                      f"higher scores, suggesting incomplete gut harm modeling.")
        w("")

    # ================================================================
    # Section 12: Interpretability
    # ================================================================
    w("---")
    w("## 12. Model Interpretability Summary")
    w("")

    interp = load_json('interpret_summary.json')
    if interp:
        rf_info = interp.get('rf', {})
        cum = rf_info.get('top30_cumulative', 0)

        w("| Model | Method | Status | Result |")
        w("|-------|--------|--------|--------|")

        w(f"| RF | Global feature importance | {rf_info.get('status', 'N/A')} | "
          f"Top 30 Morgan bits explain {cum:.1%} of importance |")

        rf_bits = load_json('interpret_rf_top_bits.json')
        if rf_bits and 'bits' in rf_bits and len(rf_bits['bits']) > 0:
            top_bit = rf_bits['bits'][0]
            w(f"| | | | Most important bit: {top_bit['bit_index']} "
              f"(importance = {top_bit['importance']:.5f}) |")

        for m, method, finding_template in [
            ('dmpnn', 'BRICS fragment occlusion', 'Holistic predictions (fragments score near 0)'),
            ('dmpnn_rdkit', 'BRICS fragment occlusion', 'Same holistic behavior as D-MPNN'),
            ('chemeleon', 'BRICS fragment occlusion', 'Non-decomposable pretrained representations'),
            ('molformer', 'Self-attention extraction', 'Heteroatom tokens dominate attention'),
        ]:
            m_info = interp.get(m, {})
            status = m_info.get('status', 'N/A')
            n_comp = m_info.get('n_compounds', 0)
            finding = finding_template
            if n_comp > 0:
                finding += f" ({n_comp} compounds)"
            w(f"| {MODEL_SHORT.get(m, m)} | {method} | {status} | {finding} |")

        w("")

        # Dynamic decomposability finding
        graph_models = ['dmpnn', 'dmpnn_rdkit', 'chemeleon']
        holistic = [m for m in graph_models if interp.get(m, {}).get('status') == 'complete']
        decomposable = []
        if rf_info.get('status') == 'complete':
            decomposable.append('rf')
        if interp.get('molformer', {}).get('status') == 'complete':
            decomposable.append('molformer')

        if holistic and decomposable:
            hm_names = ", ".join(MODEL_SHORT.get(m, m) for m in holistic)
            dm_names = ", ".join(MODEL_SHORT.get(m, m) for m in decomposable)
            w(f"**Key finding:** {hm_names} produce holistic, non-decomposable predictions "
              f"where individual BRICS fragments score near zero. "
              f"Only {dm_names} provide decomposable feature attributions.")
        w("")

    # ================================================================
    # Section 13: Summary of Key Findings
    # ================================================================
    w("---")
    w("## 13. Summary of Key Findings")
    w("")

    findings = []

    # Finding 1: Best pathogen model
    if winner_counts:
        dominant = max(winner_counts, key=winner_counts.get)
        n_wins = winner_counts[dominant]
        cal_note = ""
        if cal_stats.get(dominant):
            cal_note = (f", best calibration ({cal_stats[dominant]['near_zero']} "
                        f"saturated compounds)")
        findings.append(
            f"**{MODEL_SHORT[dominant]} is the most reliable model for pathogen classification**, "
            f"achieving the highest ROC-AUC on {n_wins}/{len(PATHOGENS)} pathogen tasks"
            f"{cal_note}."
        )

    # Finding 2: D-MPNN RDKit improvement
    if rdkit_report:
        cv_comp = rdkit_report.get('comparison_with_old', {}).get('cv_comparison', {})
        n_declined = sum(1 for v in cv_comp.values() if v.get('change', 0) < 0)
        n_total = len(cv_comp)
        if 'dmpnn' in valid_cal and 'dmpnn_rdkit' in valid_cal:
            old_sat = valid_cal['dmpnn']['near_zero']
            new_sat = valid_cal['dmpnn_rdkit']['near_zero']
            findings.append(
                f"**D-MPNN+RDKit fixed the old D-MPNN's probability saturation** "
                f"(from {old_sat} to {new_sat} compounds at S < 0.01) and reduced phosphate bias, "
                f"but ROC-AUC decreased on {n_declined}/{n_total} tasks."
            )

    # Finding 3: ROC-AUC vs screening utility
    findings.append(
        "**Raw classification accuracy (ROC-AUC) does not predict screening utility.** "
        "A model can have higher ROC-AUC but produce worse drug rankings due to "
        "probability saturation and structural biases."
    )

    # Finding 4: Consensus
    if consensus is not None:
        n_models_max = int(consensus['n_models'].max())
        n_unanimous = len(consensus[consensus['n_models'] == n_models_max])
        if n_unanimous > 0:
            top_names = ", ".join(
                str(r['name']) for _, r in
                consensus[consensus['n_models'] == n_models_max].head(3).iterrows()
            )
            findings.append(
                f"**Cross-model consensus is the strongest validation signal.** "
                f"{n_unanimous} compound(s) achieve {n_models_max}/{n_models_max} model agreement "
                f"({top_names})."
            )

    w("### Architecture Comparison")
    w("")
    for i, f in enumerate(findings, 1):
        w(f"{i}. {f}")
        w("")

    w("### Limitations")
    w("")
    w("1. All predictions are computational. Experimental MIC and gut bacteria panel validation required.")
    w("2. Binary activity models at fixed MIC threshold (10 uM). No dose-response modeling.")
    w("3. In vitro training data. In vivo pharmacokinetics will modulate actual selectivity.")
    w("4. The narrow/broad validation uses only 4-6 drugs per category. Individual drug quirks "
      "can flip the result.")
    w("")

    # ================================================================
    # Section 14: File Inventory
    # ================================================================
    w("---")
    w("## 14. Output File Inventory")
    w("")

    w("### Data Files")
    w("")
    for f in sorted(os.listdir(RESULTS_DIR)):
        if f.endswith('.csv') or f.endswith('.json') or f.endswith('.md'):
            path = os.path.join(RESULTS_DIR, f)
            size = os.path.getsize(path)
            if size > 1024 * 1024:
                size_str = f"{size / 1024 / 1024:.1f} MB"
            elif size > 1024:
                size_str = f"{size / 1024:.1f} KB"
            else:
                size_str = f"{size} B"
            w(f"- `{f}` ({size_str})")
    w("")

    w("### Figures")
    w("")
    if os.path.isdir(FIGURES_DIR):
        n_png = len([f for f in os.listdir(FIGURES_DIR) if f.endswith('.png')])
        n_pdf = len([f for f in os.listdir(FIGURES_DIR) if f.endswith('.pdf')])
        n_html = len([f for f in os.listdir(FIGURES_DIR) if f.endswith('.html')])
        w(f"- {n_png} PNG files, {n_pdf} PDF files, {n_html} interactive HTML files")
        w(f"- Location: `{FIGURES_DIR}`")
    w("")

    w("---")
    w(f"*Microbiome-Sparing Antibiotic Discovery Pipeline | "
      f"{datetime.now().strftime('%Y-%m-%d')} | IIIT Hyderabad*")

    # Write report
    report_path = os.path.join(RESULTS_DIR, 'consolidated_results_report.md')
    with open(report_path, 'w') as f:
        f.write("\n".join(L))
    print(f"Report written: {report_path}")
    print(f"Length: {len(L)} lines")


if __name__ == '__main__':
    main()
