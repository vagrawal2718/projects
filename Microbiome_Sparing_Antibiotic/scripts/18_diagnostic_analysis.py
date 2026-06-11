#!/usr/bin/env python3
"""
18_diagnostic_analysis.py -- Analyze why models disagree on candidates

Computes molecular descriptors for all Hub compounds and analyzes:
  1. Chemical property distributions of each model's top candidates
  2. Pairwise raw probability correlations between all model pairs
  3. Compound-level disagreement scores
  4. Specific bias case studies (D-MPNN phosphate, CheMeleon small molecule)
  5. Score distribution calibration analysis

NO retraining, NO GPU. Reads existing screening CSVs and computes
RDKit descriptors (~2 min for 6,739 compounds).

Outputs:
  results/diagnostic_properties.csv        (Hub + descriptors + all scores)
  results/diagnostic_disagreement.csv      (per-compound disagreement)
  results/diagnostic_summary.json          (full analysis report)
  results/figures/diagnostic_*.png/pdf/html

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    April 2026
"""

import os, sys, json, time, warnings
import numpy as np
import pandas as pd

warnings.filterwarnings('ignore')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import config
from utils.logging_utils import setup_logging, log_phase_start, log_phase_end

logger = setup_logging('phase_diagnostic', log_dir=config.LOGS_DIR)

PIPES = ['rf', 'dmpnn', 'chemeleon_frozen', 'molformer', 'dmpnn_rdkit']
PIPE_LABELS = ['RF', 'D-MPNN', 'CheMeleon', 'MoLFormer', 'D-MPNN+RDKit']
PIPE_COLORS = ['#0072B2', '#D55E00', '#009E73', '#CC79A7', '#E69F00']


# ===================================================================
# 1. Load all model predictions into one DataFrame
# ===================================================================

def load_all_predictions():
    """Load all 4 model screening results for ecoli_t10 into one DF."""
    logger.info("  Loading screening predictions...")

    dfs = {}
    for pipe in PIPES:
        path = os.path.join(config.SCREENING_DIR,
                            f'{pipe}_ranked_ecoli_t10.csv')
        if os.path.exists(path):
            df = pd.read_csv(path)
            dfs[pipe] = df
            logger.info(f"    {pipe}: {len(df)} compounds, "
                        f"cols={list(df.columns)[:6]}")

    if not dfs:
        logger.error("  No screening CSVs found")
        return None

    # Build merged DF with smiles as key
    base = dfs[PIPES[0]][['smiles', 'name', 'moa', 'clinical_phase']].copy()

    for pipe in PIPES:
        if pipe in dfs:
            df = dfs[pipe][['smiles', 'p_pathogen', 'p_gut',
                            'selectivity_score', 'rank']].copy()
            df = df.rename(columns={
                'p_pathogen': f'{pipe}_p_path',
                'p_gut': f'{pipe}_p_gut',
                'selectivity_score': f'{pipe}_S',
                'rank': f'{pipe}_rank',
            })
            base = base.merge(df, on='smiles', how='left')

    logger.info(f"  Merged: {len(base)} compounds, "
                f"{len(base.columns)} columns")
    return base


# ===================================================================
# 2. Compute RDKit molecular descriptors
# ===================================================================

def compute_descriptors(df):
    """Compute molecular descriptors for all compounds."""
    from rdkit import Chem
    from rdkit.Chem import Descriptors, Lipinski, rdMolDescriptors

    logger.info("\n  Computing RDKit molecular descriptors...")
    t0 = time.time()

    props = {
        'MW': [], 'LogP': [], 'TPSA': [], 'n_rings': [],
        'n_aromatic_rings': [], 'n_rotatable': [], 'n_HBA': [],
        'n_HBD': [], 'formal_charge': [], 'n_heavy_atoms': [],
        'fraction_sp3': [], 'n_heteroatoms': [],
        'has_phosphate': [], 'has_sulfate': [],
    }

    n_fail = 0
    for smi in df['smiles']:
        mol = Chem.MolFromSmiles(str(smi))
        if mol is None:
            n_fail += 1
            for k in props:
                props[k].append(np.nan)
            continue

        props['MW'].append(Descriptors.MolWt(mol))
        props['LogP'].append(Descriptors.MolLogP(mol))
        props['TPSA'].append(Descriptors.TPSA(mol))
        props['n_rings'].append(Lipinski.RingCount(mol))
        props['n_aromatic_rings'].append(
            rdMolDescriptors.CalcNumAromaticRings(mol))
        props['n_rotatable'].append(Lipinski.NumRotatableBonds(mol))
        props['n_HBA'].append(Lipinski.NumHAcceptors(mol))
        props['n_HBD'].append(Lipinski.NumHDonors(mol))
        props['formal_charge'].append(
            Chem.GetFormalCharge(mol))
        props['n_heavy_atoms'].append(mol.GetNumHeavyAtoms())
        props['fraction_sp3'].append(
            rdMolDescriptors.CalcFractionCSP3(mol))
        props['n_heteroatoms'].append(
            rdMolDescriptors.CalcNumHeteroatoms(mol))

        # Phosphate/sulfate detection (for D-MPNN bias analysis)
        smi_str = str(smi)
        props['has_phosphate'].append(
            1 if ('P' in smi_str and 'O' in smi_str) else 0)
        props['has_sulfate'].append(
            1 if ('S(=O)(=O)' in smi_str or 'OS(O)' in smi_str) else 0)

    for k, v in props.items():
        df[k] = v

    t1 = time.time()
    logger.info(f"  Computed {len(props)} descriptors for {len(df)} "
                f"compounds ({n_fail} failed) in {t1 - t0:.1f}s")
    return df


# ===================================================================
# 3. Top-N chemical property analysis
# ===================================================================

def analyze_top_n_properties(df, top_n=50):
    """Compare chemical properties of each model's top-N vs full Hub."""
    logger.info(f"\n" + "=" * 70)
    logger.info(f"  CHEMICAL PROPERTIES: Top-{top_n} per model vs Full Hub")
    logger.info("=" * 70)

    desc_cols = ['MW', 'LogP', 'TPSA', 'n_rings', 'n_aromatic_rings',
                 'n_rotatable', 'n_HBA', 'n_HBD', 'formal_charge',
                 'n_heavy_atoms', 'fraction_sp3', 'has_phosphate']

    hub_stats = df[desc_cols].describe().loc[['mean', 'std']]
    results = {'hub_mean': hub_stats.loc['mean'].to_dict(),
               'hub_std': hub_stats.loc['std'].to_dict(),
               'per_model': {}}

    # Header
    header = f"  {'Property':20s} {'Hub mean':>10} "
    for label in PIPE_LABELS:
        header += f"  {label + ' top50':>14}"
    logger.info(f"\n{header}")
    logger.info("  " + "-" * 80)

    for desc in desc_cols:
        hub_mean = df[desc].mean()
        line = f"  {desc:20s} {hub_mean:>10.2f} "

        model_means = {}
        for pipe, label in zip(PIPES, PIPE_LABELS):
            s_col = f'{pipe}_S'
            if s_col not in df.columns:
                continue
            top = df.nlargest(top_n, s_col)
            m = top[desc].mean()
            model_means[pipe] = m

            # Mark if significantly different from Hub
            diff = abs(m - hub_mean) / (df[desc].std() + 1e-10)
            marker = " **" if diff > 0.5 else ""
            line += f"  {m:>10.2f}{marker:>4}"

        results['per_model'][desc] = model_means
        logger.info(line)

    logger.info("\n  ** = > 0.5 std deviation from Hub mean")
    return results


# ===================================================================
# 4. Pairwise probability correlations
# ===================================================================

def pairwise_correlations(df):
    """Compute Spearman correlations between all model pairs for
    raw P_pathogen, P_gut, and S scores."""
    from scipy.stats import spearmanr

    logger.info(f"\n" + "=" * 70)
    logger.info(f"  PAIRWISE MODEL CORRELATIONS (ecoli_t10)")
    logger.info("=" * 70)

    results = {}

    for score_type, suffix, label in [
        ('P_pathogen', '_p_path', 'P(E. coli activity)'),
        ('P_gut', '_p_gut', 'P(gut harm)'),
        ('Selectivity', '_S', 'S = P_path x (1 - P_gut)'),
    ]:
        logger.info(f"\n  {label}:")
        logger.info(f"  {'Pair':30s} {'rho':>8} {'p-value':>12} {'n':>6}")
        logger.info("  " + "-" * 60)

        pair_results = {}
        for i in range(len(PIPES)):
            for j in range(i + 1, len(PIPES)):
                col_a = f'{PIPES[i]}{suffix}'
                col_b = f'{PIPES[j]}{suffix}'
                if col_a not in df.columns or col_b not in df.columns:
                    continue

                sub = df.dropna(subset=[col_a, col_b])
                rho, p = spearmanr(sub[col_a], sub[col_b])
                pair_name = f'{PIPE_LABELS[i]} vs {PIPE_LABELS[j]}'

                pair_results[pair_name] = {
                    'rho': round(float(rho), 4),
                    'p_value': float(p),
                    'n': len(sub),
                }

                logger.info(f"  {pair_name:30s} {rho:>8.4f} "
                            f"{p:>12.2e} {len(sub):>6}")

        results[score_type] = pair_results

    return results


# ===================================================================
# 5. Disagreement analysis
# ===================================================================

def compute_disagreement(df):
    """Compute per-compound disagreement score across models."""
    logger.info(f"\n" + "=" * 70)
    logger.info(f"  COMPOUND-LEVEL DISAGREEMENT")
    logger.info("=" * 70)

    # Normalize ranks to percentiles (0-1) for fair comparison
    rank_cols = []
    for pipe in PIPES:
        r_col = f'{pipe}_rank'
        p_col = f'{pipe}_pctile'
        if r_col in df.columns:
            n = df[r_col].max()
            df[p_col] = 1 - (df[r_col] / n)  # higher = better
            rank_cols.append(p_col)

    if len(rank_cols) < 2:
        return {}

    # Disagreement = std of percentile ranks across models
    df['rank_mean'] = df[rank_cols].mean(axis=1)
    df['rank_std'] = df[rank_cols].std(axis=1)
    df['disagreement'] = df['rank_std']

    # Most controversial compounds (high mean rank but high disagreement)
    controversial = df[df['rank_mean'] > 0.5].nlargest(20, 'disagreement')

    logger.info(f"\n  Most controversial compounds "
                f"(high avg rank, high disagreement):")
    logger.info(f"  {'Name':25s} {'RF pctile':>10} {'DMPNN':>8} "
                f"{'CheMel':>8} {'MoLFor':>8} {'Disagree':>10}")
    logger.info("  " + "-" * 75)

    results = {'compounds': []}
    for _, r in controversial.iterrows():
        name = str(r['name'])[:25]
        vals = [r.get(f'{pipe}_pctile', 0) for pipe in PIPES]
        logger.info(f"  {name:25s} {vals[0]:>10.3f} {vals[1]:>8.3f} "
                    f"{vals[2]:>8.3f} {vals[3]:>8.3f} "
                    f"{r['disagreement']:>10.3f}")
        results['compounds'].append({
            'name': str(r['name']),
            'smiles': str(r['smiles']),
            'percentiles': {p: round(v, 4)
                            for p, v in zip(PIPES, vals)},
            'disagreement': round(float(r['disagreement']), 4),
        })

    # Most agreed-upon (high rank, low disagreement)
    agreed = df[df['rank_mean'] > 0.8].nsmallest(15, 'disagreement')

    logger.info(f"\n  Most agreed-upon compounds "
                f"(high avg rank, low disagreement):")
    logger.info(f"  {'Name':25s} {'RF pctile':>10} {'DMPNN':>8} "
                f"{'CheMel':>8} {'MoLFor':>8} {'Disagree':>10}")
    logger.info("  " + "-" * 75)

    results['agreed'] = []
    for _, r in agreed.iterrows():
        name = str(r['name'])[:25]
        vals = [r.get(f'{pipe}_pctile', 0) for pipe in PIPES]
        logger.info(f"  {name:25s} {vals[0]:>10.3f} {vals[1]:>8.3f} "
                    f"{vals[2]:>8.3f} {vals[3]:>8.3f} "
                    f"{r['disagreement']:>10.3f}")
        results['agreed'].append({
            'name': str(r['name']),
            'percentiles': {p: round(v, 4)
                            for p, v in zip(PIPES, vals)},
            'disagreement': round(float(r['disagreement']), 4),
        })

    return results


# ===================================================================
# 6. Bias case studies
# ===================================================================

def bias_case_studies(df):
    """Identify specific model biases."""
    logger.info(f"\n" + "=" * 70)
    logger.info(f"  MODEL BIAS CASE STUDIES")
    logger.info("=" * 70)

    results = {}

    # --- D-MPNN phosphate bias ---
    logger.info(f"\n  A. D-MPNN phosphate/nucleotide bias:")
    if 'dmpnn_S' in df.columns and 'has_phosphate' in df.columns:
        phos = df[df['has_phosphate'] == 1]
        no_phos = df[df['has_phosphate'] == 0]

        dm_phos_mean = phos['dmpnn_S'].mean()
        dm_nophos_mean = no_phos['dmpnn_S'].mean()
        rf_phos_mean = phos['rf_S'].mean()
        rf_nophos_mean = no_phos['rf_S'].mean()

        logger.info(f"    Compounds with phosphate: {len(phos)}")
        logger.info(f"    D-MPNN mean S (phosphate):    {dm_phos_mean:.4f}")
        logger.info(f"    D-MPNN mean S (no phosphate): {dm_nophos_mean:.4f}")
        logger.info(f"    D-MPNN ratio: {dm_phos_mean / (dm_nophos_mean + 1e-10):.1f}x")
        logger.info(f"    RF mean S (phosphate):        {rf_phos_mean:.4f}")
        logger.info(f"    RF mean S (no phosphate):     {rf_nophos_mean:.4f}")
        # D-MPNN RDKit phosphate comparison
        if 'dmpnn_rdkit_S' in df.columns:
            rdkit_phos_mean = phos['dmpnn_rdkit_S'].mean()
            rdkit_nophos_mean = no_phos['dmpnn_rdkit_S'].mean()
            logger.info(f"    D-MPNN+RDKit mean S (phosphate):  {rdkit_phos_mean:.4f}")
            logger.info(f"    D-MPNN+RDKit mean S (no phos):    {rdkit_nophos_mean:.4f}")
            logger.info(f"    D-MPNN+RDKit ratio: {rdkit_phos_mean / (rdkit_nophos_mean + 1e-10):.1f}x")

        logger.info(f"    RF ratio: {rf_phos_mean / (rf_nophos_mean + 1e-10):.1f}x")

        # D-MPNN top-10 phosphate compounds
        dm_top_phos = phos.nlargest(10, 'dmpnn_S')
        logger.info(f"\n    D-MPNN top-10 phosphate compounds:")
        for _, r in dm_top_phos.iterrows():
            logger.info(f"      {str(r['name'])[:30]:30s} "
                        f"S={r['dmpnn_S']:.4f}  "
                        f"RF S={r['rf_S']:.4f}  "
                        f"MW={r.get('MW', 0):.0f}")

        results['dmpnn_phosphate_bias'] = {
            'n_phosphate': len(phos),
            'dmpnn_mean_S_phosphate': round(dm_phos_mean, 4),
            'dmpnn_mean_S_no_phosphate': round(dm_nophos_mean, 4),
            'dmpnn_ratio': round(dm_phos_mean / (dm_nophos_mean + 1e-10), 2),
            'rf_ratio': round(rf_phos_mean / (rf_nophos_mean + 1e-10), 2),
        }

    # --- CheMeleon small molecule bias ---
    logger.info(f"\n  B. CheMeleon molecular weight bias:")
    if 'chemeleon_frozen_S' in df.columns and 'MW' in df.columns:
        chem_top50 = df.nlargest(50, 'chemeleon_frozen_S')
        rf_top50 = df.nlargest(50, 'rf_S')
        hub_mw = df['MW'].median()
        chem_mw = chem_top50['MW'].median()
        rf_mw = rf_top50['MW'].median()

        logger.info(f"    Hub median MW:            {hub_mw:.0f}")
        logger.info(f"    CheMeleon top-50 median:  {chem_mw:.0f}")
        logger.info(f"    RF top-50 median:         {rf_mw:.0f}")

        # Fraction with very small MW
        chem_small = (chem_top50['MW'] < 200).sum()
        rf_small = (rf_top50['MW'] < 200).sum()
        logger.info(f"    CheMeleon top-50 with MW<200: {chem_small}")
        logger.info(f"    RF top-50 with MW<200:        {rf_small}")

        results['chemeleon_mw_bias'] = {
            'hub_median_MW': round(float(hub_mw), 1),
            'chemeleon_top50_median_MW': round(float(chem_mw), 1),
            'rf_top50_median_MW': round(float(rf_mw), 1),
            'chemeleon_top50_small_mw': int(chem_small),
            'rf_top50_small_mw': int(rf_small),
        }

    # --- D-MPNN probability saturation ---
    logger.info(f"\n  C. Probability calibration (saturation analysis):")
    for pipe, label in zip(PIPES, PIPE_LABELS):
        s_col = f'{pipe}_S'
        p_col = f'{pipe}_p_path'
        if s_col not in df.columns:
            continue

        near_zero = (df[s_col] < 0.01).sum()
        near_one = (df[s_col] > 0.95).sum()
        mid = ((df[s_col] > 0.2) & (df[s_col] < 0.8)).sum()
        logger.info(f"    {label:12s}: S<0.01={near_zero:>5}, "
                    f"0.2<S<0.8={mid:>5}, S>0.95={near_one:>5}")

        if p_col in df.columns:
            p_near_one = (df[p_col] > 0.99).sum()
            p_near_zero = (df[p_col] < 0.01).sum()
            results[f'{pipe}_saturation'] = {
                'p_path_near_0': int(p_near_zero),
                'p_path_near_1': int(p_near_one),
                'S_near_0': int(near_zero),
                'S_near_1': int(near_one),
                'S_mid_range': int(mid),
            }

    # --- Non-antibiotic false positives per model ---
    logger.info(f"\n  D. Non-antibiotic false positives in top-50:")
    known_ab_moas = ['antibiotic', 'antibacterial', 'bacterial',
                     'ribosom', 'cell wall', 'DNA gyrase', 'FABI',
                     'topoisomerase', 'beta-lactam', 'penicillin',
                     'cephalosporin', 'aminoglycoside', 'tetracycline',
                     'macrolide', 'fluoroquinolone', 'sulfonamide',
                     'protein synthesis', 'leucyl-tRNA']

    for pipe, label in zip(PIPES, PIPE_LABELS):
        s_col = f'{pipe}_S'
        if s_col not in df.columns:
            continue
        top50 = df.nlargest(50, s_col)
        n_ab = 0
        for _, r in top50.iterrows():
            moa = str(r.get('moa', '')).lower()
            if any(kw in moa for kw in known_ab_moas):
                n_ab += 1
        n_non_ab = 50 - n_ab
        logger.info(f"    {label:12s}: {n_ab} antibiotics, "
                    f"{n_non_ab} non-antibiotics in top 50")

    return results


# ===================================================================
# 7. Figures
# ===================================================================

def generate_figures(df):
    """Generate all Phase B figures."""
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt

    os.makedirs(config.FIGURES_DIR, exist_ok=True)
    DPI = 300
    plt.rcParams.update({
        'font.family': 'serif', 'font.size': 10,
        'figure.dpi': DPI, 'savefig.dpi': DPI,
        'axes.spines.top': False, 'axes.spines.right': False,
    })

    # ---- Figure 1: Score distributions ----
    fig, axes = plt.subplots(1, 5, figsize=(20, 4), sharey=True)
    for idx, (pipe, label, color) in enumerate(
            zip(PIPES, PIPE_LABELS, PIPE_COLORS)):
        ax = axes[idx]
        s_col = f'{pipe}_S'
        if s_col not in df.columns:
            continue
        ax.hist(df[s_col].dropna(), bins=100, color=color, alpha=0.7,
                edgecolor='none')
        ax.set_xlabel('Selectivity Score S')
        ax.set_title(label)
        ax.set_yscale('log')
        median = df[s_col].median()
        ax.axvline(median, color='black', linestyle='--', alpha=0.5)
        ax.text(median + 0.02, ax.get_ylim()[1] * 0.5,
                f'med={median:.3f}', fontsize=8)
    axes[0].set_ylabel('Count (log scale)')
    plt.suptitle('Selectivity Score Distributions (E. coli, t=10)',
                 fontsize=12)
    plt.tight_layout()
    path = os.path.join(config.FIGURES_DIR, 'diagnostic_score_distributions')
    fig.savefig(path + '.png', dpi=DPI, bbox_inches='tight')
    fig.savefig(path + '.pdf', bbox_inches='tight')
    plt.close(fig)
    logger.info(f"  Figure: diagnostic_score_distributions")

    # ---- Figure 2: Pairwise S scatter (6 panels) ----
    n_pairs = len(PIPES) * (len(PIPES) - 1) // 2
    fig, axes = plt.subplots(2, 5, figsize=(25, 10))
    pair_idx = 0
    for i in range(len(PIPES)):
        for j in range(i + 1, len(PIPES)):
            ax = axes.flat[pair_idx]
            col_a = f'{PIPES[i]}_S'
            col_b = f'{PIPES[j]}_S'
            if col_a in df.columns and col_b in df.columns:
                sub = df.dropna(subset=[col_a, col_b])
                ax.scatter(sub[col_a], sub[col_b], s=2, alpha=0.3,
                           c='#333333', edgecolors='none')
                ax.set_xlabel(f'{PIPE_LABELS[i]} S')
                ax.set_ylabel(f'{PIPE_LABELS[j]} S')
                ax.plot([0, 1], [0, 1], 'r--', alpha=0.3)

                from scipy.stats import spearmanr
                rho, _ = spearmanr(sub[col_a], sub[col_b])
                ax.text(0.05, 0.95, f'rho={rho:.3f}',
                        transform=ax.transAxes, fontsize=10, va='top')
            pair_idx += 1

    plt.suptitle('Pairwise Selectivity Score Agreement (E. coli, t=10)',
                 fontsize=12)
    plt.tight_layout()
    path = os.path.join(config.FIGURES_DIR, 'diagnostic_pairwise_scatter')
    fig.savefig(path + '.png', dpi=DPI, bbox_inches='tight')
    fig.savefig(path + '.pdf', bbox_inches='tight')
    plt.close(fig)
    logger.info(f"  Figure: diagnostic_pairwise_scatter")

    # ---- Figure 3: Top-50 property boxplots ----
    desc_cols = ['MW', 'LogP', 'TPSA', 'n_rings', 'n_heavy_atoms',
                 'fraction_sp3']
    fig, axes = plt.subplots(2, 5, figsize=(25, 10))
    for idx, desc in enumerate(desc_cols):
        ax = axes.flat[idx]
        if desc not in df.columns:
            continue

        data = [df[desc].dropna().values]
        labels_list = ['Hub']
        colors_list = ['#999999']

        for pipe, label, color in zip(PIPES, PIPE_LABELS, PIPE_COLORS):
            s_col = f'{pipe}_S'
            if s_col in df.columns:
                top50 = df.nlargest(50, s_col)
                data.append(top50[desc].dropna().values)
                labels_list.append(label)
                colors_list.append(color)

        bp = ax.boxplot(data, labels=labels_list, patch_artist=True,
                        widths=0.6)
        for patch, c in zip(bp['boxes'], colors_list):
            patch.set_facecolor(c)
            patch.set_alpha(0.6)
        ax.set_title(desc)
        ax.tick_params(axis='x', rotation=30)

    plt.suptitle('Chemical Properties: Hub vs Model Top-50 Candidates',
                 fontsize=12)
    plt.tight_layout()
    path = os.path.join(config.FIGURES_DIR, 'diagnostic_property_boxplots')
    fig.savefig(path + '.png', dpi=DPI, bbox_inches='tight')
    fig.savefig(path + '.pdf', bbox_inches='tight')
    plt.close(fig)
    logger.info(f"  Figure: diagnostic_property_boxplots")

    # ---- Figure 4: P_pathogen pairwise (raw probabilities) ----
    fig, axes = plt.subplots(2, 5, figsize=(25, 10))
    pair_idx = 0
    for i in range(len(PIPES)):
        for j in range(i + 1, len(PIPES)):
            ax = axes.flat[pair_idx]
            col_a = f'{PIPES[i]}_p_path'
            col_b = f'{PIPES[j]}_p_path'
            if col_a in df.columns and col_b in df.columns:
                sub = df.dropna(subset=[col_a, col_b])
                ax.scatter(sub[col_a], sub[col_b], s=2, alpha=0.3,
                           c='#333333', edgecolors='none')
                ax.set_xlabel(f'{PIPE_LABELS[i]} P(E. coli)')
                ax.set_ylabel(f'{PIPE_LABELS[j]} P(E. coli)')
                ax.plot([0, 1], [0, 1], 'r--', alpha=0.3)

                from scipy.stats import spearmanr
                rho, _ = spearmanr(sub[col_a], sub[col_b])
                ax.text(0.05, 0.95, f'rho={rho:.3f}',
                        transform=ax.transAxes, fontsize=10, va='top')
            pair_idx += 1

    plt.suptitle('Pairwise Raw P(E. coli) Agreement',
                 fontsize=12)
    plt.tight_layout()
    path = os.path.join(config.FIGURES_DIR, 'diagnostic_pairwise_p_pathogen')
    fig.savefig(path + '.png', dpi=DPI, bbox_inches='tight')
    fig.savefig(path + '.pdf', bbox_inches='tight')
    plt.close(fig)
    logger.info(f"  Figure: diagnostic_pairwise_p_pathogen")

    # ---- Figure 5: Interactive comparison (Plotly) ----
    try:
        import plotly.express as px
        from plotly.subplots import make_subplots
        import plotly.graph_objects as go

        # MW vs S for each model
        fig_p = make_subplots(rows=3, cols=2,
                              subplot_titles=PIPE_LABELS[:6])
        for idx, (pipe, label, color) in enumerate(
                zip(PIPES, PIPE_LABELS, PIPE_COLORS)):
            row = idx // 2 + 1
            col = idx % 2 + 1
            s_col = f'{pipe}_S'
            if s_col not in df.columns or 'MW' not in df.columns:
                continue

            fig_p.add_trace(go.Scatter(
                x=df['MW'], y=df[s_col],
                mode='markers',
                marker=dict(size=3, color=color, opacity=0.4),
                text=df['name'], name=label,
                hovertemplate='%{text}<br>MW=%{x:.0f}<br>S=%{y:.4f}',
            ), row=row, col=col)
            fig_p.update_xaxes(title_text='Molecular Weight', row=row, col=col)
            fig_p.update_yaxes(title_text='Selectivity S', row=row, col=col)

        fig_p.update_layout(
            title='Molecular Weight vs Selectivity per Model',
            width=1000, height=1200, showlegend=False)
        path = os.path.join(config.FIGURES_DIR,
                            'diagnostic_interactive_mw_vs_s.html')
        fig_p.write_html(path)
        logger.info(f"  Figure: diagnostic_interactive_mw_vs_s.html")
    except ImportError:
        pass


# ===================================================================
# Main
# ===================================================================

def main():
    t_start = log_phase_start(logger,
                              "Phase B: Diagnostic Analysis")

    os.makedirs(config.RESULTS_DIR, exist_ok=True)
    os.makedirs(config.FIGURES_DIR, exist_ok=True)

    # --- Load predictions ---
    df = load_all_predictions()
    if df is None:
        return

    # --- Compute descriptors ---
    df = compute_descriptors(df)

    # Save full properties table
    props_path = os.path.join(config.RESULTS_DIR,
                              'diagnostic_properties.csv')
    df.to_csv(props_path, index=False)
    logger.info(f"\n  Saved: {props_path}")

    # --- Analyses ---
    property_results = analyze_top_n_properties(df, top_n=50)
    correlation_results = pairwise_correlations(df)
    disagreement_results = compute_disagreement(df)
    bias_results = bias_case_studies(df)

    # Save disagreement CSV
    disagree_cols = ['smiles', 'name', 'moa', 'disagreement',
                     'rank_mean', 'rank_std']
    for pipe in PIPES:
        disagree_cols.extend([f'{pipe}_S', f'{pipe}_rank',
                              f'{pipe}_pctile'])
    disagree_cols = [c for c in disagree_cols if c in df.columns]
    disagree_path = os.path.join(config.RESULTS_DIR,
                                 'diagnostic_disagreement.csv')
    df[disagree_cols].sort_values('disagreement', ascending=False).to_csv(
        disagree_path, index=False)
    logger.info(f"  Saved: {disagree_path}")

    # --- Figures ---
    logger.info("\n  Generating figures...")
    try:
        generate_figures(df)
    except Exception as e:
        logger.warning(f"  Figure generation failed: {e}")
        import traceback; traceback.print_exc()

    # --- Summary report ---
    report = {
        'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
        'n_compounds': len(df),
        'property_analysis': property_results,
        'pairwise_correlations': correlation_results,
        'disagreement_analysis': disagreement_results,
        'bias_case_studies': bias_results,
        'key_findings': [],
    }

    # Auto-generate key findings from data
    if 'dmpnn_phosphate_bias' in bias_results:
        r = bias_results['dmpnn_phosphate_bias']
        report['key_findings'].append(
            f"D-MPNN shows {r['dmpnn_ratio']}x higher selectivity "
            f"scores for phosphate-containing compounds "
            f"(vs {r['rf_ratio']}x for RF), confirming phosphate group bias.")

    if 'chemeleon_mw_bias' in bias_results:
        r = bias_results['chemeleon_mw_bias']
        report['key_findings'].append(
            f"CheMeleon top-50 has median MW={r['chemeleon_top50_median_MW']} "
            f"vs Hub median MW={r['hub_median_MW']}, with "
            f"{r['chemeleon_top50_small_mw']} compounds below 200 Da "
            f"(vs {r['rf_top50_small_mw']} for RF).")

    report_path = os.path.join(config.RESULTS_DIR,
                               'diagnostic_summary.json')
    with open(report_path, 'w') as f:
        json.dump(report, f, indent=2, default=str)
    logger.info(f"\n  Saved: {report_path}")

    # --- Print summary ---
    logger.info("\n" + "=" * 70)
    logger.info("  DIAGNOSTIC SUMMARY")
    logger.info("=" * 70)
    for finding in report['key_findings']:
        logger.info(f"  - {finding}")
    logger.info("=" * 70)

    log_phase_end(logger, "Phase B: Diagnostic Analysis", t_start)


if __name__ == '__main__':
    main()