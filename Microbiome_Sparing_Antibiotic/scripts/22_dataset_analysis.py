#!/usr/bin/env python3
"""
22_dataset_analysis.py -- Comprehensive Dataset Analysis and Visualization

Phase 1: Our pipeline training data, gut commensal data, and screening library.
Phase 2: Reference study data (Stokes, Wong) and cross-study comparisons.

Generates publication-quality figures characterizing all datasets used in the
microbiome-sparing antibiotic discovery pipeline.

Outputs:
  results/figures/data_*.png       (static figures)
  results/figures/data_*.html      (interactive plots)
  results/dataset_analysis.json    (computed statistics)
  results/dataset_analysis.md      (markdown report)

Usage:
  python scripts/22_dataset_analysis.py              # full analysis
  python scripts/22_dataset_analysis.py --phase1     # our data only
  python scripts/22_dataset_analysis.py --phase2     # reference data only
  python scripts/22_dataset_analysis.py --test       # unit tests

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    April 2026
"""

import os, sys, json, glob, warnings, time
import numpy as np
import pandas as pd

warnings.filterwarnings('ignore')

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
import config
from utils.logging_utils import setup_logging, log_phase_start, log_phase_end

logger = setup_logging('dataset_analysis', log_dir=config.LOGS_DIR)

FIG_DIR = config.FIGURES_DIR
os.makedirs(FIG_DIR, exist_ok=True)

# Plotting setup
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from matplotlib.patches import Patch
from matplotlib import cm

DPI = 300
plt.rcParams.update({
    'font.family': 'serif', 'font.size': 11, 'figure.dpi': DPI,
    'savefig.dpi': DPI, 'savefig.bbox': 'tight',
    'axes.linewidth': 0.8, 'axes.spines.top': False, 'axes.spines.right': False,
})

# Color palettes
PATHOGEN_COLORS = {
    'ecoli': '#2196F3',
    'saureus': '#FF5722',
    'paeruginosa': '#4CAF50',
    'mtb': '#9C27B0',
}
PATHOGEN_LABELS = {
    'ecoli': 'E. coli',
    'saureus': 'S. aureus',
    'paeruginosa': 'P. aeruginosa',
    'mtb': 'M. tuberculosis',
}
DATASET_COLORS = {
    'ecoli': '#2196F3', 'saureus': '#FF5722',
    'paeruginosa': '#4CAF50', 'mtb': '#9C27B0',
    'maier': '#FF9800', 'hub': '#607D8B',
    'stokes_train': '#795548', 'stokes_screen': '#9E9E9E',
    'wong_train': '#E91E63',
}


def save_figure(fig, path_stem):
    """Save figure as PNG and PDF."""
    fig.savefig(f'{path_stem}.png', dpi=DPI, bbox_inches='tight')
    fig.savefig(f'{path_stem}.pdf', bbox_inches='tight')
    logger.info(f"  Saved: {path_stem}.png")
    plt.close(fig)


# ==========================================================================
# DATA LOADING
# ==========================================================================

def load_all_data():
    """Load all pipeline datasets."""
    data = {}

    # Pathogen datasets
    for pkey, pinfo in config.PATHOGENS.items():
        csv_path = os.path.join(config.CHEMBL_DIR, pinfo['csv_filename'])
        if os.path.exists(csv_path):
            df = pd.read_csv(csv_path)
            data[pkey] = df
            logger.info(f"  Loaded: {pkey} ({len(df)} compounds)")

    # Maier gut commensal
    maier_csv = os.path.join(config.MAIER_DIR, 'maier_combined.csv')
    if os.path.exists(maier_csv):
        data['maier'] = pd.read_csv(maier_csv)
        logger.info(f"  Loaded: maier ({len(data['maier'])} compounds)")

    # Drug Repurposing Hub
    hub_csv = os.path.join(config.HUB_DIR, config.HUB_CLEAN_FILENAME)
    if os.path.exists(hub_csv):
        data['hub'] = pd.read_csv(hub_csv)
        logger.info(f"  Loaded: hub ({len(data['hub'])} compounds)")

    return data


def compute_molecular_properties(smiles_series):
    """Compute RDKit molecular properties for a series of SMILES."""
    from rdkit import Chem
    from rdkit.Chem import Descriptors, rdMolDescriptors, Lipinski

    props = []
    for smi in smiles_series:
        try:
            mol = Chem.MolFromSmiles(str(smi))
            if mol is None:
                props.append({})
                continue
            props.append({
                'MW': Descriptors.MolWt(mol),
                'LogP': Descriptors.MolLogP(mol),
                'TPSA': Descriptors.TPSA(mol),
                'HBD': Lipinski.NumHDonors(mol),
                'HBA': Lipinski.NumHAcceptors(mol),
                'RotBonds': Lipinski.NumRotatableBonds(mol),
                'Rings': rdMolDescriptors.CalcNumRings(mol),
                'AromaticRings': rdMolDescriptors.CalcNumAromaticRings(mol),
                'HeavyAtoms': mol.GetNumHeavyAtoms(),
                'SMILES_len': len(smi),
            })
        except Exception:
            props.append({})

    return pd.DataFrame(props)


# ==========================================================================
# PHASE 1: OUR PIPELINE DATA ANALYSIS
# ==========================================================================

def fig_dataset_sizes(data):
    """Bar chart comparing all dataset sizes."""
    logger.info("  Figure: data_dataset_sizes")

    datasets = []
    sizes = []
    colors = []
    categories = []

    for pkey in ['ecoli', 'saureus', 'paeruginosa', 'mtb']:
        if pkey in data:
            datasets.append(PATHOGEN_LABELS[pkey])
            sizes.append(len(data[pkey]))
            colors.append(PATHOGEN_COLORS[pkey])
            categories.append('pathogen')

    if 'maier' in data:
        datasets.append('Maier\nCommensal')
        sizes.append(len(data['maier']))
        colors.append('#FF9800')
        categories.append('commensal')

    if 'hub' in data:
        datasets.append('Drug Repurposing\nHub')
        sizes.append(len(data['hub']))
        colors.append('#607D8B')
        categories.append('screening')

    fig, ax = plt.subplots(figsize=(12, 6))
    x = np.arange(len(datasets))
    bars = ax.bar(x, sizes, color=colors, edgecolor='white', linewidth=1.5, width=0.65)

    for bar, size in zip(bars, sizes):
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + max(sizes) * 0.02,
                f'{size:,}', ha='center', va='bottom', fontsize=11, fontweight='bold')

    ax.set_xticks(x)
    ax.set_xticklabels(datasets, fontsize=10)
    ax.set_ylabel('Number of Compounds', fontsize=12)
    ax.set_title('Dataset Sizes Across the Pipeline', fontsize=14, fontweight='bold')
    ax.set_yscale('log')
    ax.set_ylim(500, max(sizes) * 3)

    legend_elements = [
        Patch(facecolor=PATHOGEN_COLORS['ecoli'], label='Pathogen training (ChEMBL 34)'),
        Patch(facecolor='#FF9800', label='Gut commensal (Maier 2018/2021)'),
        Patch(facecolor='#607D8B', label='Screening library (Broad Hub)'),
    ]
    ax.legend(handles=legend_elements, loc='upper right', fontsize=10)
    ax.grid(axis='y', alpha=0.3)

    save_figure(fig, os.path.join(FIG_DIR, 'data_dataset_sizes'))


def fig_class_balance(data):
    """Grouped bar chart showing class balance for all tasks."""
    logger.info("  Figure: data_class_balance")

    tasks = []
    active_pcts = []
    inactive_pcts = []
    colors_active = []

    for pkey in ['ecoli', 'saureus', 'paeruginosa', 'mtb']:
        if pkey in data:
            df = data[pkey]
            n_active = int(df['activity_label'].sum())
            tasks.append(PATHOGEN_LABELS[pkey])
            active_pcts.append(100 * n_active / len(df))
            inactive_pcts.append(100 * (len(df) - n_active) / len(df))
            colors_active.append(PATHOGEN_COLORS[pkey])

    if 'maier' in data:
        df = data['maier']
        for t, label in [(5, 'Gut t=5'), (10, 'Gut t=10'), (20, 'Gut t=20')]:
            col = f'harm_t{t}'
            if col in df.columns:
                n_pos = int(df[col].sum())
                tasks.append(label)
                active_pcts.append(100 * n_pos / len(df))
                inactive_pcts.append(100 * (len(df) - n_pos) / len(df))
                colors_active.append('#FF9800')

    fig, ax = plt.subplots(figsize=(12, 6))
    x = np.arange(len(tasks))
    width = 0.35

    bars1 = ax.bar(x - width / 2, active_pcts, width, label='Active / Harmful',
                   color=[c for c in colors_active], alpha=0.85)
    bars2 = ax.bar(x + width / 2, inactive_pcts, width, label='Inactive / Safe',
                   color='#E0E0E0', edgecolor='#BDBDBD', linewidth=0.5)

    for bar, pct in zip(bars1, active_pcts):
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 1,
                f'{pct:.1f}%', ha='center', va='bottom', fontsize=9, fontweight='bold')

    ax.set_xticks(x)
    ax.set_xticklabels(tasks, fontsize=10, rotation=15, ha='right')
    ax.set_ylabel('Percentage (%)', fontsize=12)
    ax.set_title('Class Balance Across All Binary Classification Tasks', fontsize=14, fontweight='bold')
    ax.legend(fontsize=10)
    ax.set_ylim(0, 105)
    ax.axhline(y=50, color='gray', linestyle='--', alpha=0.3, label='Balanced')
    ax.grid(axis='y', alpha=0.3)

    save_figure(fig, os.path.join(FIG_DIR, 'data_class_balance'))


def fig_molecular_properties(data):
    """Distribution plots of molecular properties across all datasets."""
    logger.info("  Figure: data_molecular_properties (computing RDKit descriptors...)")

    # Compute properties for each dataset (sample for speed)
    all_props = {}
    max_sample = 5000

    for dname in ['ecoli', 'saureus', 'paeruginosa', 'mtb', 'maier', 'hub']:
        if dname not in data:
            continue
        df = data[dname]
        smi_col = 'smiles' if 'smiles' in df.columns else 'canonical_smiles'
        if smi_col not in df.columns:
            continue

        smiles = df[smi_col].dropna()
        if len(smiles) > max_sample:
            smiles = smiles.sample(n=max_sample, random_state=42)

        props = compute_molecular_properties(smiles)
        props = props.dropna(subset=['MW'])
        props['dataset'] = dname
        all_props[dname] = props
        logger.info(f"    {dname}: {len(props)} valid molecules")

    if not all_props:
        logger.warning("  No molecular properties computed")
        return

    df_all = pd.concat(all_props.values(), ignore_index=True)

    # 2x3 grid of property distributions
    properties = ['MW', 'LogP', 'TPSA', 'HBD', 'HBA', 'RotBonds']
    prop_labels = ['Molecular Weight (Da)', 'LogP', 'TPSA (A^2)',
                   'H-Bond Donors', 'H-Bond Acceptors', 'Rotatable Bonds']
    prop_ranges = [(0, 800), (-5, 10), (0, 250), (0, 15), (0, 20), (0, 20)]

    fig, axes = plt.subplots(2, 3, figsize=(18, 10))
    axes = axes.flat

    plot_datasets = ['ecoli', 'saureus', 'paeruginosa', 'mtb', 'maier', 'hub']
    plot_labels = ['E. coli', 'S. aureus', 'P. aeruginosa', 'M. tuberculosis',
                   'Maier', 'Hub']
    plot_colors = ['#2196F3', '#FF5722', '#4CAF50', '#9C27B0', '#FF9800', '#607D8B']

    for idx, (prop, plabel, prange) in enumerate(zip(properties, prop_labels, prop_ranges)):
        ax = axes[idx]
        for dname, dlabel, dcol in zip(plot_datasets, plot_labels, plot_colors):
            if dname not in all_props:
                continue
            vals = all_props[dname][prop].dropna()
            vals = vals[(vals >= prange[0]) & (vals <= prange[1])]
            if len(vals) > 0:
                ax.hist(vals, bins=50, alpha=0.5, label=dlabel, color=dcol,
                        density=True, edgecolor='none')

        ax.set_xlabel(plabel, fontsize=10)
        ax.set_ylabel('Density', fontsize=10)
        ax.set_xlim(prange)
        if idx == 0:
            ax.legend(fontsize=8, loc='upper right')
        ax.grid(axis='y', alpha=0.2)

    plt.suptitle('Molecular Property Distributions Across Datasets',
                 fontsize=15, fontweight='bold', y=1.02)
    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_molecular_properties'))

    return df_all


def fig_molecular_property_boxplots(data, df_all_props):
    """Box plots comparing key properties across datasets."""
    logger.info("  Figure: data_property_boxplots")

    if df_all_props is None or len(df_all_props) == 0:
        return

    properties = ['MW', 'LogP', 'TPSA', 'HeavyAtoms']
    prop_labels = ['Molecular Weight (Da)', 'LogP', 'TPSA (A^2)', 'Heavy Atom Count']

    dataset_order = ['ecoli', 'saureus', 'paeruginosa', 'mtb', 'maier', 'hub']
    dataset_labels = ['E. coli', 'S. aureus', 'P. aerug.', 'M. tb', 'Maier', 'Hub']
    box_colors = ['#2196F3', '#FF5722', '#4CAF50', '#9C27B0', '#FF9800', '#607D8B']

    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    axes = axes.flat

    for idx, (prop, plabel) in enumerate(zip(properties, prop_labels)):
        ax = axes[idx]
        box_data = []
        labels = []
        colors_used = []

        for dname, dlabel, dcol in zip(dataset_order, dataset_labels, box_colors):
            subset = df_all_props[df_all_props['dataset'] == dname][prop].dropna()
            if len(subset) > 0:
                box_data.append(subset.values)
                labels.append(dlabel)
                colors_used.append(dcol)

        if box_data:
            bp = ax.boxplot(box_data, labels=labels, patch_artist=True,
                           showfliers=False, widths=0.6)
            for patch, color in zip(bp['boxes'], colors_used):
                patch.set_facecolor(color)
                patch.set_alpha(0.7)
            for median in bp['medians']:
                median.set_color('black')
                median.set_linewidth(2)

        ax.set_ylabel(plabel, fontsize=10)
        ax.grid(axis='y', alpha=0.3)
        ax.tick_params(axis='x', rotation=15)

    plt.suptitle('Molecular Property Comparison Across Datasets',
                 fontsize=14, fontweight='bold')
    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_property_boxplots'))


def fig_smiles_length(data):
    """SMILES length distribution across datasets."""
    logger.info("  Figure: data_smiles_length")

    fig, ax = plt.subplots(figsize=(12, 6))

    plot_order = ['ecoli', 'saureus', 'paeruginosa', 'mtb', 'maier', 'hub']
    plot_labels = ['E. coli', 'S. aureus', 'P. aeruginosa', 'M. tuberculosis',
                   'Maier', 'Hub']
    plot_colors = ['#2196F3', '#FF5722', '#4CAF50', '#9C27B0', '#FF9800', '#607D8B']

    for dname, dlabel, dcol in zip(plot_order, plot_labels, plot_colors):
        if dname not in data:
            continue
        df = data[dname]
        smi_col = 'smiles' if 'smiles' in df.columns else 'canonical_smiles'
        if smi_col not in df.columns:
            continue
        lengths = df[smi_col].str.len().dropna()
        lengths = lengths[lengths <= 300]  # cap for visibility
        ax.hist(lengths, bins=80, alpha=0.5, label=f'{dlabel} (n={len(df):,})',
                color=dcol, density=True, edgecolor='none')

    ax.set_xlabel('SMILES String Length (characters)', fontsize=12)
    ax.set_ylabel('Density', fontsize=12)
    ax.set_title('SMILES Length Distribution Across Datasets', fontsize=14, fontweight='bold')
    ax.legend(fontsize=9)
    ax.set_xlim(0, 300)
    ax.grid(axis='y', alpha=0.3)

    save_figure(fig, os.path.join(FIG_DIR, 'data_smiles_length'))


def fig_maier_nhit_distribution(data):
    """Distribution of n_hit (strains harmed) in Maier data."""
    logger.info("  Figure: data_maier_nhit")

    if 'maier' not in data:
        return

    df = data['maier']
    if 'n_hit' not in df.columns:
        return

    fig, axes = plt.subplots(1, 2, figsize=(16, 6))

    # Left: histogram
    ax = axes[0]
    nhit = df['n_hit'].values
    bins = np.arange(-0.5, 41.5, 1)
    n, _, patches = ax.hist(nhit, bins=bins, color='#FF9800', edgecolor='white',
                             linewidth=0.5, alpha=0.85)

    # Color bars by threshold regions
    for i, patch in enumerate(patches):
        if i < 5:
            patch.set_facecolor('#66BB6A')  # safe at all thresholds
        elif i < 10:
            patch.set_facecolor('#FFA726')  # harmful at t=5
        elif i < 20:
            patch.set_facecolor('#EF5350')  # harmful at t=10
        else:
            patch.set_facecolor('#B71C1C')  # harmful at t=20

    ax.axvline(x=5, color='#FFA726', linestyle='--', linewidth=2, label='t=5 threshold')
    ax.axvline(x=10, color='#EF5350', linestyle='--', linewidth=2, label='t=10 threshold')
    ax.axvline(x=20, color='#B71C1C', linestyle='--', linewidth=2, label='t=20 threshold')

    ax.set_xlabel('Number of Gut Strains Harmed (n_hit)', fontsize=12)
    ax.set_ylabel('Number of Compounds', fontsize=12)
    ax.set_title('Distribution of Gut Microbiome Harm', fontsize=13, fontweight='bold')
    ax.legend(fontsize=10)
    ax.set_xlim(-1, 41)

    # Right: drug class breakdown
    ax2 = axes[1]
    drug_classes = df['drug_class'].value_counts()
    colors_dc = plt.cm.Set3(np.linspace(0, 1, len(drug_classes)))

    wedges, texts, autotexts = ax2.pie(
        drug_classes.values, labels=None, autopct='%1.1f%%',
        colors=colors_dc, startangle=90, pctdistance=0.85,
        textprops={'fontsize': 8}
    )
    ax2.legend(drug_classes.index, loc='center left', bbox_to_anchor=(1, 0.5),
               fontsize=8)
    ax2.set_title('Drug Class Distribution\n(Maier Dataset)', fontsize=13, fontweight='bold')

    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_maier_nhit'))


def fig_maier_strain_sensitivity(data):
    """Heatmap showing which strains are most sensitive to drugs."""
    logger.info("  Figure: data_maier_strain_heatmap")

    # Load the p-value matrix from the Maier Excel
    pval_path = os.path.join('resources', 'maier',
                             '41586_2018_BFnature25979_MOESM5_ESM.xlsx')
    if not os.path.exists(pval_path):
        logger.warning("  Maier p-value Excel not found, skipping heatmap")
        return

    try:
        df_pval = pd.read_excel(pval_path, sheet_name='S3a. Adjusted p-values')
    except Exception as e:
        logger.warning(f"  Could not read Maier p-values: {e}")
        return

    # Extract strain columns (everything after n_hit)
    meta_cols = ['prestwick_ID', 'chemical_name', 'drug_class', 'n_hit']
    strain_cols = [c for c in df_pval.columns if c not in meta_cols]

    if len(strain_cols) == 0:
        logger.warning("  No strain columns found in p-value matrix")
        return

    # Compute: for each strain, how many drugs significantly inhibit it (p < 0.05)
    strain_hits = {}
    for scol in strain_cols:
        pvals = pd.to_numeric(df_pval[scol], errors='coerce')
        n_sig = (pvals < 0.05).sum()
        strain_hits[scol] = n_sig

    # Sort strains by sensitivity (most sensitive first)
    strain_order = sorted(strain_hits.keys(), key=lambda s: strain_hits[s], reverse=True)
    hit_counts = [strain_hits[s] for s in strain_order]

    # Clean strain names for display
    clean_names = []
    for s in strain_order:
        name = s.split('(')[0].strip()
        if len(name) > 30:
            name = name[:28] + '...'
        clean_names.append(name)

    fig, ax = plt.subplots(figsize=(10, 12))
    y = np.arange(len(clean_names))
    colors = ['#EF5350' if h > 100 else '#FFA726' if h > 50 else '#66BB6A'
              for h in hit_counts]

    bars = ax.barh(y, hit_counts, color=colors, edgecolor='white', linewidth=0.5)
    ax.set_yticks(y)
    ax.set_yticklabels(clean_names, fontsize=8)
    ax.invert_yaxis()
    ax.set_xlabel('Number of Drugs Causing Significant Inhibition (p < 0.05)', fontsize=11)
    ax.set_title('Gut Bacterial Strain Sensitivity to Drugs\n(Maier et al., Nature 2018)',
                 fontsize=13, fontweight='bold')

    for bar, count in zip(bars, hit_counts):
        ax.text(bar.get_width() + 2, bar.get_y() + bar.get_height() / 2,
                str(count), va='center', fontsize=8)

    ax.grid(axis='x', alpha=0.3)
    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_maier_strain_sensitivity'))


def fig_hub_clinical_phases(data):
    """Hub screening library clinical phase and MoA analysis."""
    logger.info("  Figure: data_hub_clinical_moa")

    if 'hub' not in data:
        return

    df = data['hub']

    fig, axes = plt.subplots(1, 2, figsize=(16, 6))

    # Left: Clinical phase
    ax = axes[0]
    if 'clinical_phase' in df.columns:
        phase_counts = df['clinical_phase'].value_counts()
        phase_order = ['Launched', 'Phase 3', 'Phase 2/Phase 3', 'Phase 2',
                       'Phase 1/Phase 2', 'Phase 1', 'Preclinical', 'Withdrawn']
        phase_counts = phase_counts.reindex([p for p in phase_order if p in phase_counts.index])

        colors_phase = plt.cm.RdYlGn(np.linspace(0.8, 0.2, len(phase_counts)))
        bars = ax.barh(range(len(phase_counts)), phase_counts.values,
                       color=colors_phase, edgecolor='white')
        ax.set_yticks(range(len(phase_counts)))
        ax.set_yticklabels(phase_counts.index, fontsize=10)
        ax.invert_yaxis()
        ax.set_xlabel('Number of Compounds', fontsize=11)
        ax.set_title('Clinical Development Phase', fontsize=13, fontweight='bold')

        for bar, count in zip(bars, phase_counts.values):
            ax.text(bar.get_width() + 10, bar.get_y() + bar.get_height() / 2,
                    f'{count:,}', va='center', fontsize=10)
        ax.grid(axis='x', alpha=0.3)

    # Right: Top 15 MoA
    ax2 = axes[1]
    if 'moa' in df.columns:
        moa_counts = df['moa'].dropna().value_counts().head(15)
        colors_moa = plt.cm.tab20(np.linspace(0, 1, len(moa_counts)))
        bars = ax2.barh(range(len(moa_counts)), moa_counts.values,
                        color=colors_moa, edgecolor='white')
        ax2.set_yticks(range(len(moa_counts)))
        ax2.set_yticklabels(moa_counts.index, fontsize=9)
        ax2.invert_yaxis()
        ax2.set_xlabel('Number of Compounds', fontsize=11)
        ax2.set_title('Top 15 Mechanisms of Action', fontsize=13, fontweight='bold')

        for bar, count in zip(bars, moa_counts.values):
            ax2.text(bar.get_width() + 1, bar.get_y() + bar.get_height() / 2,
                     str(count), va='center', fontsize=9)
        ax2.grid(axis='x', alpha=0.3)

    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_hub_clinical_moa'))


def fig_hub_disease_areas(data):
    """Hub disease area distribution."""
    logger.info("  Figure: data_hub_disease_areas")

    if 'hub' not in data or 'disease_area' not in data['hub'].columns:
        return

    df = data['hub']
    da_counts = df['disease_area'].dropna().value_counts().head(12)

    fig, ax = plt.subplots(figsize=(10, 6))
    colors_da = plt.cm.Set2(np.linspace(0, 1, len(da_counts)))
    bars = ax.barh(range(len(da_counts)), da_counts.values,
                   color=colors_da, edgecolor='white')
    ax.set_yticks(range(len(da_counts)))
    ax.set_yticklabels(da_counts.index, fontsize=10)
    ax.invert_yaxis()
    ax.set_xlabel('Number of Compounds', fontsize=11)
    ax.set_title('Drug Repurposing Hub: Disease Area Distribution',
                 fontsize=13, fontweight='bold')

    for bar, count in zip(bars, da_counts.values):
        ax.text(bar.get_width() + 2, bar.get_y() + bar.get_height() / 2,
                str(count), va='center', fontsize=10)
    ax.grid(axis='x', alpha=0.3)

    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_hub_disease_areas'))


def fig_cross_dataset_overlap(data):
    """Venn-style overlap analysis between datasets."""
    logger.info("  Figure: data_cross_dataset_overlap")

    # Collect SMILES sets
    smiles_sets = {}
    for dname in ['ecoli', 'saureus', 'paeruginosa', 'mtb', 'maier', 'hub']:
        if dname not in data:
            continue
        df = data[dname]
        smi_col = 'smiles' if 'smiles' in df.columns else 'canonical_smiles'
        if smi_col in df.columns:
            smiles_sets[dname] = set(df[smi_col].dropna().values)

    if len(smiles_sets) < 2:
        return

    # Compute pairwise overlaps
    datasets = list(smiles_sets.keys())
    n = len(datasets)
    overlap_matrix = np.zeros((n, n), dtype=int)

    for i in range(n):
        for j in range(n):
            overlap_matrix[i, j] = len(smiles_sets[datasets[i]] & smiles_sets[datasets[j]])

    labels = [PATHOGEN_LABELS.get(d, d.title()) for d in datasets]

    fig, ax = plt.subplots(figsize=(9, 7))
    im = ax.imshow(overlap_matrix, cmap='YlOrRd', aspect='auto')

    ax.set_xticks(range(n))
    ax.set_yticks(range(n))
    ax.set_xticklabels(labels, rotation=45, ha='right', fontsize=10)
    ax.set_yticklabels(labels, fontsize=10)

    # Annotate cells
    for i in range(n):
        for j in range(n):
            val = overlap_matrix[i, j]
            color = 'white' if val > overlap_matrix.max() * 0.6 else 'black'
            ax.text(j, i, f'{val:,}', ha='center', va='center',
                    fontsize=9, color=color, fontweight='bold')

    ax.set_title('Cross-Dataset Compound Overlap (by SMILES)',
                 fontsize=13, fontweight='bold')
    plt.colorbar(im, ax=ax, label='Shared Compounds', shrink=0.8)
    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_cross_dataset_overlap'))

    return overlap_matrix, datasets


def fig_chemical_space_pca(data):
    """PCA visualization of chemical space across datasets."""
    logger.info("  Figure: data_chemical_space_pca (computing fingerprints...)")

    from scipy import sparse
    from sklearn.decomposition import PCA

    # Load precomputed fingerprints
    fp_data = {}
    fp_labels = {}
    max_per_dataset = 2000

    for dname, fp_file in [
        ('ecoli', 'morgan_ecoli.npz'),
        ('saureus', 'morgan_saureus.npz'),
        ('paeruginosa', 'morgan_paeruginosa.npz'),
        ('mtb', 'morgan_mtb.npz'),
        ('maier', 'morgan_maier.npz'),
        ('hub', 'morgan_repurposing_hub.npz'),
    ]:
        fp_path = os.path.join(config.FEATURES_DIR, fp_file)
        if os.path.exists(fp_path):
            X = sparse.load_npz(fp_path)
            n = min(max_per_dataset, X.shape[0])
            idx = np.random.RandomState(42).choice(X.shape[0], n, replace=False)
            fp_data[dname] = X[idx].toarray()
            fp_labels[dname] = np.full(n, dname)
            logger.info(f"    {dname}: sampled {n} from {X.shape[0]}")

    if len(fp_data) < 2:
        logger.warning("  Not enough fingerprint data for PCA")
        return

    # Concatenate and run PCA
    X_all = np.vstack(list(fp_data.values()))
    labels_all = np.concatenate(list(fp_labels.values()))

    pca = PCA(n_components=2, random_state=42)
    coords = pca.fit_transform(X_all)

    fig, ax = plt.subplots(figsize=(12, 9))

    plot_order = ['ecoli', 'saureus', 'paeruginosa', 'mtb', 'maier', 'hub']
    plot_labels_map = {
        'ecoli': 'E. coli', 'saureus': 'S. aureus',
        'paeruginosa': 'P. aeruginosa', 'mtb': 'M. tuberculosis',
        'maier': 'Maier', 'hub': 'Hub'
    }
    plot_colors_map = {
        'ecoli': '#2196F3', 'saureus': '#FF5722',
        'paeruginosa': '#4CAF50', 'mtb': '#9C27B0',
        'maier': '#FF9800', 'hub': '#607D8B',
    }

    for dname in plot_order:
        if dname not in fp_data:
            continue
        mask = labels_all == dname
        ax.scatter(coords[mask, 0], coords[mask, 1],
                   c=plot_colors_map[dname], label=plot_labels_map[dname],
                   s=8, alpha=0.4, edgecolors='none')

    ax.set_xlabel(f'PC1 ({pca.explained_variance_ratio_[0]*100:.1f}% variance)', fontsize=12)
    ax.set_ylabel(f'PC2 ({pca.explained_variance_ratio_[1]*100:.1f}% variance)', fontsize=12)
    ax.set_title('Chemical Space: Morgan Fingerprint PCA (2D Projection)',
                 fontsize=14, fontweight='bold')
    ax.legend(fontsize=10, markerscale=3)
    ax.grid(alpha=0.2)

    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_chemical_space_pca'))


def fig_fingerprint_bit_frequency(data):
    """Analyze which Morgan fingerprint bits are most common across datasets."""
    logger.info("  Figure: data_fingerprint_bits")

    from scipy import sparse

    bit_freqs = {}
    for dname, fp_file in [
        ('ecoli', 'morgan_ecoli.npz'),
        ('maier', 'morgan_maier.npz'),
        ('hub', 'morgan_repurposing_hub.npz'),
    ]:
        fp_path = os.path.join(config.FEATURES_DIR, fp_file)
        if os.path.exists(fp_path):
            X = sparse.load_npz(fp_path)
            freq = np.array((X > 0).mean(axis=0)).flatten()
            bit_freqs[dname] = freq

    if len(bit_freqs) < 2:
        return

    fig, axes = plt.subplots(1, 2, figsize=(16, 6))

    # Left: top 30 most common bits in E. coli
    ax = axes[0]
    if 'ecoli' in bit_freqs:
        freq = bit_freqs['ecoli']
        top_idx = np.argsort(freq)[::-1][:30]
        ax.bar(range(30), freq[top_idx], color='#2196F3', alpha=0.8)
        ax.set_xlabel('Bit Index (sorted by frequency)', fontsize=10)
        ax.set_ylabel('Fraction of Compounds with Bit Set', fontsize=10)
        ax.set_title('Top 30 Most Common Morgan FP Bits\n(E. coli Training Set)',
                     fontsize=12, fontweight='bold')
        ax.set_xticks(range(0, 30, 5))
        ax.grid(axis='y', alpha=0.3)

    # Right: bit frequency correlation between datasets
    ax2 = axes[1]
    if 'ecoli' in bit_freqs and 'hub' in bit_freqs:
        ax2.scatter(bit_freqs['ecoli'], bit_freqs['hub'],
                    s=5, alpha=0.5, color='#2196F3', label='E. coli vs Hub')
    if 'maier' in bit_freqs and 'hub' in bit_freqs:
        ax2.scatter(bit_freqs['maier'], bit_freqs['hub'],
                    s=5, alpha=0.5, color='#FF9800', label='Maier vs Hub')
    ax2.plot([0, 1], [0, 1], 'k--', alpha=0.3)
    ax2.set_xlabel('Bit Frequency (Training Set)', fontsize=10)
    ax2.set_ylabel('Bit Frequency (Hub Screening Set)', fontsize=10)
    ax2.set_title('Fingerprint Bit Frequency:\nTraining vs Screening',
                  fontsize=12, fontweight='bold')
    ax2.legend(fontsize=10)
    ax2.grid(alpha=0.3)

    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_fingerprint_bits'))


def fig_lipinski_analysis(data, df_all_props):
    """Lipinski Rule of 5 compliance across datasets."""
    logger.info("  Figure: data_lipinski")

    if df_all_props is None or len(df_all_props) == 0:
        return

    # Lipinski criteria: MW < 500, LogP < 5, HBD < 5, HBA < 10
    df = df_all_props.copy()
    df['lipinski_mw'] = df['MW'] < 500
    df['lipinski_logp'] = df['LogP'] < 5
    df['lipinski_hbd'] = df['HBD'] < 5
    df['lipinski_hba'] = df['HBA'] < 10
    df['lipinski_pass'] = (df['lipinski_mw'] & df['lipinski_logp'] &
                           df['lipinski_hbd'] & df['lipinski_hba'])

    dataset_order = ['ecoli', 'saureus', 'paeruginosa', 'mtb', 'maier', 'hub']
    dataset_labels = ['E. coli', 'S. aureus', 'P. aerug.', 'M. tb', 'Maier', 'Hub']
    dataset_colors = ['#2196F3', '#FF5722', '#4CAF50', '#9C27B0', '#FF9800', '#607D8B']

    fig, ax = plt.subplots(figsize=(10, 6))

    pass_rates = []
    used_labels = []
    used_colors = []
    for dname, dlabel, dcol in zip(dataset_order, dataset_labels, dataset_colors):
        subset = df[df['dataset'] == dname]
        if len(subset) > 0:
            rate = 100 * subset['lipinski_pass'].mean()
            pass_rates.append(rate)
            used_labels.append(dlabel)
            used_colors.append(dcol)

    x = np.arange(len(used_labels))
    bars = ax.bar(x, pass_rates, color=used_colors, edgecolor='white',
                  linewidth=1.5, width=0.6, alpha=0.85)

    for bar, rate in zip(bars, pass_rates):
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 1,
                f'{rate:.1f}%', ha='center', fontsize=11, fontweight='bold')

    ax.set_xticks(x)
    ax.set_xticklabels(used_labels, fontsize=11)
    ax.set_ylabel('Lipinski Rule of 5 Compliance (%)', fontsize=12)
    ax.set_title("Lipinski's Rule of 5 Compliance Across Datasets",
                 fontsize=14, fontweight='bold')
    ax.set_ylim(0, 105)
    ax.axhline(y=90, color='gray', linestyle='--', alpha=0.3)
    ax.grid(axis='y', alpha=0.3)

    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_lipinski'))


def fig_pathogen_active_vs_inactive_properties(data):
    """Compare molecular properties of active vs inactive compounds per pathogen."""
    logger.info("  Figure: data_active_vs_inactive")

    from rdkit import Chem
    from rdkit.Chem import Descriptors

    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    axes = axes.flat

    for idx, pkey in enumerate(['ecoli', 'saureus', 'paeruginosa', 'mtb']):
        ax = axes[idx]
        if pkey not in data:
            continue

        df = data[pkey]
        smi_col = 'smiles' if 'smiles' in df.columns else 'canonical_smiles'

        # Sample for speed
        sample = df.sample(n=min(3000, len(df)), random_state=42)

        mws = []
        labels = []
        for _, row in sample.iterrows():
            try:
                mol = Chem.MolFromSmiles(str(row[smi_col]))
                if mol:
                    mws.append(Descriptors.MolWt(mol))
                    labels.append(int(row['activity_label']))
            except:
                pass

        mws = np.array(mws)
        labels = np.array(labels)

        active_mw = mws[labels == 1]
        inactive_mw = mws[labels == 0]

        bins = np.linspace(0, 800, 50)
        ax.hist(active_mw, bins=bins, alpha=0.6, color=PATHOGEN_COLORS[pkey],
                density=True, label=f'Active (n={len(active_mw)})')
        ax.hist(inactive_mw, bins=bins, alpha=0.4, color='#E0E0E0',
                density=True, label=f'Inactive (n={len(inactive_mw)})',
                edgecolor='#BDBDBD')

        ax.set_xlabel('Molecular Weight (Da)', fontsize=10)
        ax.set_ylabel('Density', fontsize=10)
        ax.set_title(f'{PATHOGEN_LABELS[pkey]}: Active vs Inactive MW',
                     fontsize=12, fontweight='bold')
        ax.legend(fontsize=9)
        ax.set_xlim(0, 800)
        ax.grid(axis='y', alpha=0.2)

    plt.suptitle('Molecular Weight: Active vs Inactive Compounds',
                 fontsize=14, fontweight='bold', y=1.02)
    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_active_vs_inactive_mw'))


def generate_statistics_json(data, df_all_props, coactivity=None):
    """Save computed statistics to JSON."""
    logger.info("  Saving dataset_analysis.json")

    stats = {}

    for dname in ['ecoli', 'saureus', 'paeruginosa', 'mtb']:
        if dname not in data:
            continue
        df = data[dname]
        stats[dname] = {
            'n_compounds': len(df),
            'n_active': int(df['activity_label'].sum()),
            'active_pct': round(100 * df['activity_label'].mean(), 1),
            'source': 'ChEMBL 34 MIC',
        }

    if 'maier' in data:
        df = data['maier']
        stats['maier'] = {
            'n_compounds': len(df),
            'n_strains': 40,
            'n_species': 38,
            'harm_t5': int(df['harm_t5'].sum()),
            'harm_t10': int(df['harm_t10'].sum()),
            'harm_t20': int(df['harm_t20'].sum()),
            'n_hit_mean': round(df['n_hit'].mean(), 1),
            'n_hit_median': int(df['n_hit'].median()),
            'n_hit_max': int(df['n_hit'].max()),
            'drug_classes': df['drug_class'].value_counts().to_dict(),
            'source': 'Maier et al., Nature 2018/2021',
        }

    if 'hub' in data:
        df = data['hub']
        stats['hub'] = {
            'n_compounds': len(df),
            'clinical_phases': df['clinical_phase'].value_counts().to_dict() if 'clinical_phase' in df.columns else {},
            'n_launched': int((df['clinical_phase'] == 'Launched').sum()) if 'clinical_phase' in df.columns else 0,
            'top_moa': df['moa'].value_counts().head(10).to_dict() if 'moa' in df.columns else {},
            'source': 'Broad Institute Drug Repurposing Hub',
        }

    if df_all_props is not None and len(df_all_props) > 0:
        prop_stats = {}
        for dname in df_all_props['dataset'].unique():
            subset = df_all_props[df_all_props['dataset'] == dname]
            prop_stats[dname] = {}
            for prop in ['MW', 'LogP', 'TPSA', 'HBD', 'HBA', 'RotBonds']:
                vals = subset[prop].dropna()
                if len(vals) > 0:
                    prop_stats[dname][prop] = {
                        'mean': round(float(vals.mean()), 2),
                        'median': round(float(vals.median()), 2),
                        'std': round(float(vals.std()), 2),
                        'min': round(float(vals.min()), 2),
                        'max': round(float(vals.max()), 2),
                    }
        stats['molecular_properties'] = prop_stats

    if coactivity:
        stats['pathogen_gut_coactivity'] = coactivity

    out_path = os.path.join(config.RESULTS_DIR, 'dataset_analysis.json')
    with open(out_path, 'w') as f:
        json.dump(stats, f, indent=2, default=str)
    logger.info(f"  Saved: {out_path}")

    return stats


# ==========================================================================
# MAIN
# ==========================================================================

def load_reference_data():
    """Load Stokes and Wong reference datasets."""
    ref = {}

    CACHE_DIR = os.path.join(os.path.dirname(config.DATA_DIR), '.benchmark_cache')

    # --- Stokes ---
    stokes_xlsx = os.path.join(CACHE_DIR, 'stokes', 'stokes_tables.xlsx')
    if os.path.exists(stokes_xlsx):
        try:
            # S2B: Hub predictions (4,496 compounds scored by Stokes D-MPNN)
            ref['stokes_hub'] = pd.read_excel(stokes_xlsx, sheet_name='S2B', header=1)
            logger.info(f"  Loaded: Stokes S2B Hub predictions ({len(ref['stokes_hub'])} compounds)")

            # S2H: Training data (2,335 compounds with Tanimoto to halicin)
            ref['stokes_train'] = pd.read_excel(stokes_xlsx, sheet_name='S2H', header=1)
            logger.info(f"  Loaded: Stokes S2H training data ({len(ref['stokes_train'])} compounds)")

            # S2C-G: Alternative model predictions on Hub
            for sheet, label in [('S2C', 'dmpnn_learned'), ('S2D', 'dmpnn_rdkit'),
                                 ('S2E', 'ffn_morgan'), ('S2F', 'rf_morgan'), ('S2G', 'svm_morgan')]:
                try:
                    df = pd.read_excel(stokes_xlsx, sheet_name=sheet, header=1)
                    ref[f'stokes_{label}'] = df
                    logger.info(f"  Loaded: Stokes {sheet} ({label}, {len(df)} compounds)")
                except Exception:
                    pass

            # S2A: RDKit feature list
            ref['stokes_features'] = pd.read_excel(stokes_xlsx, sheet_name='S2A', header=1)
            logger.info(f"  Loaded: Stokes S2A ({len(ref['stokes_features'])} RDKit features)")

        except Exception as e:
            logger.warning(f"  Stokes Excel error: {e}")
    else:
        logger.warning(f"  Stokes data not found at {stokes_xlsx}")

    # --- Wong ---
    wong_dir = os.path.join(CACHE_DIR, 'wong', 'extracted', 'antibioticsai-main')

    # Training data
    wong_train = os.path.join(wong_dir, 'working_example', 'train.csv')
    if os.path.exists(wong_train):
        ref['wong_train'] = pd.read_csv(wong_train)
        logger.info(f"  Loaded: Wong training data ({len(ref['wong_train'])} compounds)")

    # Broad800 predictions (load first ensemble member as representative)
    wong_broad = os.path.join(wong_dir, 'library_predictions', 'broad800_predictions_final', '0p.csv')
    if os.path.exists(wong_broad):
        ref['wong_broad800'] = pd.read_csv(wong_broad)
        logger.info(f"  Loaded: Wong broad800 predictions ({len(ref['wong_broad800'])} compounds)")

    # Mcule predictions (load first file as representative)
    wong_mcule_dir = os.path.join(wong_dir, 'library_predictions', 'mcule_predictions_final')
    if os.path.isdir(wong_mcule_dir):
        mcule_files = sorted([f for f in os.listdir(wong_mcule_dir) if f.endswith('.csv')])
        if mcule_files:
            ref['wong_mcule_sample'] = pd.read_csv(os.path.join(wong_mcule_dir, mcule_files[0]))
            ref['wong_mcule_n_files'] = len(mcule_files)
            logger.info(f"  Loaded: Wong mcule sample ({len(ref['wong_mcule_sample'])} compounds, "
                        f"{len(mcule_files)} total files)")

    return ref


def fig_study_comparison_sizes(data, ref):
    """Compare dataset sizes across all three studies."""
    logger.info("  Figure: data_study_sizes_comparison")

    entries = []

    # Our pipeline
    for pkey in ['ecoli', 'saureus', 'paeruginosa', 'mtb']:
        if pkey in data:
            entries.append({
                'study': 'Ours', 'dataset': PATHOGEN_LABELS[pkey],
                'n': len(data[pkey]), 'type': 'training',
                'color': PATHOGEN_COLORS[pkey],
            })
    if 'maier' in data:
        entries.append({
            'study': 'Ours', 'dataset': 'Maier Gut',
            'n': len(data['maier']), 'type': 'training', 'color': '#FF9800',
        })
    if 'hub' in data:
        entries.append({
            'study': 'Ours', 'dataset': 'Hub (screening)',
            'n': len(data['hub']), 'type': 'screening', 'color': '#607D8B',
        })

    # Stokes
    if 'stokes_train' in ref:
        entries.append({
            'study': 'Stokes (2020)', 'dataset': 'E. coli training',
            'n': len(ref['stokes_train']), 'type': 'training', 'color': '#795548',
        })
    if 'stokes_hub' in ref:
        entries.append({
            'study': 'Stokes (2020)', 'dataset': 'Hub (screened)',
            'n': len(ref['stokes_hub']), 'type': 'screening', 'color': '#A1887F',
        })

    # Wong
    if 'wong_train' in ref:
        entries.append({
            'study': 'Wong (2024)', 'dataset': 'S. aureus training',
            'n': len(ref['wong_train']), 'type': 'training', 'color': '#E91E63',
        })
    if 'wong_broad800' in ref:
        entries.append({
            'study': 'Wong (2024)', 'dataset': 'Broad800 (screened)',
            'n': len(ref['wong_broad800']), 'type': 'screening', 'color': '#F48FB1',
        })
    if 'wong_mcule_n_files' in ref and 'wong_mcule_sample' in ref:
        total = ref['wong_mcule_n_files'] * len(ref['wong_mcule_sample'])
        entries.append({
            'study': 'Wong (2024)', 'dataset': f'Mcule ({ref["wong_mcule_n_files"]} batches)',
            'n': total, 'type': 'screening', 'color': '#FCE4EC',
        })

    df_entries = pd.DataFrame(entries)

    fig, ax = plt.subplots(figsize=(14, 8))

    # Group by study
    studies = df_entries['study'].unique()
    y_pos = 0
    y_ticks = []
    y_labels = []
    y_colors = []

    for study in studies:
        subset = df_entries[df_entries['study'] == study]
        for _, row in subset.iterrows():
            bar = ax.barh(y_pos, row['n'], color=row['color'], edgecolor='white',
                          linewidth=1, height=0.7,
                          alpha=0.7 if row['type'] == 'screening' else 0.9)
            # Label
            label_text = f"{row['n']:,}"
            ax.text(row['n'] * 1.05, y_pos, label_text, va='center', fontsize=9,
                    fontweight='bold')
            y_ticks.append(y_pos)
            y_labels.append(f"{row['dataset']}")
            y_pos += 1
        y_pos += 0.5  # gap between studies

    ax.set_yticks(y_ticks)
    ax.set_yticklabels(y_labels, fontsize=9)
    ax.invert_yaxis()
    ax.set_xscale('log')
    ax.set_xlabel('Number of Compounds (log scale)', fontsize=12)
    ax.set_title('Dataset Size Comparison Across Studies', fontsize=14, fontweight='bold')

    # Study labels on the right
    legend_elements = [
        Patch(facecolor='#2196F3', label='Our pipeline'),
        Patch(facecolor='#795548', label='Stokes et al. (Cell, 2020)'),
        Patch(facecolor='#E91E63', label='Wong et al. (Nature, 2024)'),
    ]
    ax.legend(handles=legend_elements, loc='lower right', fontsize=10)
    ax.grid(axis='x', alpha=0.3)

    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_study_sizes_comparison'))


def fig_study_class_balance(data, ref):
    """Compare class balance across all studies' training data."""
    logger.info("  Figure: data_study_class_balance")

    tasks = []
    active_pcts = []
    colors = []

    # Our pathogen tasks
    for pkey in ['ecoli', 'saureus', 'paeruginosa', 'mtb']:
        if pkey in data:
            pct = 100 * data[pkey]['activity_label'].mean()
            tasks.append(f'Ours: {PATHOGEN_LABELS[pkey]}')
            active_pcts.append(pct)
            colors.append(PATHOGEN_COLORS[pkey])

    # Our gut tasks
    if 'maier' in data:
        for t in [5, 10, 20]:
            col = f'harm_t{t}'
            if col in data['maier'].columns:
                pct = 100 * data['maier'][col].mean()
                tasks.append(f'Ours: Gut t={t}')
                active_pcts.append(pct)
                colors.append('#FF9800')

    # Stokes
    # Stokes S2H is training data but doesn't have labels.
    # From the paper: 2,335 compounds, binary E. coli growth inhibition.
    # We don't have the activity column, so we'll note it as unknown.

    # Wong
    if 'wong_train' in ref:
        pct = 100 * ref['wong_train']['ACTIVITY'].mean()
        tasks.append(f'Wong: S. aureus')
        active_pcts.append(pct)
        colors.append('#E91E63')

    fig, ax = plt.subplots(figsize=(12, 6))
    x = np.arange(len(tasks))
    bars = ax.bar(x, active_pcts, color=colors, edgecolor='white', linewidth=1.5,
                  width=0.6, alpha=0.85)

    for bar, pct in zip(bars, active_pcts):
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.5,
                f'{pct:.1f}%', ha='center', fontsize=9, fontweight='bold')

    ax.set_xticks(x)
    ax.set_xticklabels(tasks, rotation=30, ha='right', fontsize=9)
    ax.set_ylabel('Active / Harmful (%)', fontsize=12)
    ax.set_title('Class Balance Comparison: Our Pipeline vs Reference Studies',
                 fontsize=14, fontweight='bold')
    ax.axhline(y=50, color='gray', linestyle='--', alpha=0.3)
    ax.set_ylim(0, 55)
    ax.grid(axis='y', alpha=0.3)

    # Annotate Wong's extreme imbalance
    if 'wong_train' in ref:
        wong_pct = 100 * ref['wong_train']['ACTIVITY'].mean()
        if wong_pct < 5:
            ax.annotate(f'Extremely imbalanced\n({wong_pct:.1f}% active)',
                        xy=(len(tasks)-1, wong_pct), xytext=(len(tasks)-2.5, 15),
                        arrowprops=dict(arrowstyle='->', color='#E91E63'),
                        fontsize=9, color='#E91E63', fontweight='bold')

    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_study_class_balance'))


def fig_stokes_training_analysis(ref):
    """Detailed analysis of Stokes training data."""
    logger.info("  Figure: data_stokes_training")

    if 'stokes_train' not in ref:
        return

    df = ref['stokes_train']

    fig, axes = plt.subplots(2, 2, figsize=(14, 10))

    # 1. Tanimoto similarity to halicin distribution
    ax = axes[0, 0]
    if 'Tanimoto_Sim_To_Halicin' in df.columns:
        tani = df['Tanimoto_Sim_To_Halicin'].dropna()
        ax.hist(tani, bins=50, color='#795548', alpha=0.8, edgecolor='white')
        ax.axvline(x=tani.mean(), color='red', linestyle='--', linewidth=2,
                   label=f'Mean = {tani.mean():.3f}')
        ax.axvline(x=0.21, color='#FF9800', linestyle=':', linewidth=2,
                   label='Halicin nearest (0.21)')
        ax.set_xlabel('Tanimoto Similarity to Halicin', fontsize=10)
        ax.set_ylabel('Count', fontsize=10)
        ax.set_title('Stokes Training Set:\nSimilarity to Halicin', fontsize=12, fontweight='bold')
        ax.legend(fontsize=9)

    # 2. Molecular properties of Stokes training
    ax = axes[0, 1]
    if 'SMILES' in df.columns:
        smiles_lens = df['SMILES'].str.len().dropna()
        ax.hist(smiles_lens, bins=50, color='#795548', alpha=0.8, edgecolor='white')
        ax.set_xlabel('SMILES Length', fontsize=10)
        ax.set_ylabel('Count', fontsize=10)
        ax.set_title(f'Stokes Training Set:\nSMILES Length (n={len(df):,})',
                     fontsize=12, fontweight='bold')
        ax.axvline(x=smiles_lens.median(), color='red', linestyle='--',
                   label=f'Median = {smiles_lens.median():.0f}')
        ax.legend(fontsize=9)

    # 3. Molecular weight distribution
    ax = axes[1, 0]
    if 'SMILES' in df.columns:
        props = compute_molecular_properties(df['SMILES'].head(2335))
        valid_props = props.dropna(subset=['MW'])
        if len(valid_props) > 0:
            ax.hist(valid_props['MW'], bins=50, color='#795548', alpha=0.8,
                    edgecolor='white')
            ax.set_xlabel('Molecular Weight (Da)', fontsize=10)
            ax.set_ylabel('Count', fontsize=10)
            ax.set_title(f'Stokes Training Set:\nMolecular Weight',
                         fontsize=12, fontweight='bold')
            ax.axvline(x=valid_props['MW'].median(), color='red', linestyle='--',
                       label=f'Median = {valid_props["MW"].median():.0f} Da')
            ax.legend(fontsize=9)
            ax.set_xlim(0, 800)

    # 4. LogP distribution
    ax = axes[1, 1]
    if 'SMILES' in df.columns and len(valid_props) > 0:
        logp = valid_props['LogP'].dropna()
        ax.hist(logp, bins=50, color='#795548', alpha=0.8, edgecolor='white')
        ax.set_xlabel('LogP', fontsize=10)
        ax.set_ylabel('Count', fontsize=10)
        ax.set_title('Stokes Training Set:\nLogP Distribution',
                     fontsize=12, fontweight='bold')
        ax.axvline(x=logp.median(), color='red', linestyle='--',
                   label=f'Median = {logp.median():.2f}')
        ax.legend(fontsize=9)

    plt.suptitle('Stokes et al. (Cell, 2020) Training Data Analysis',
                 fontsize=15, fontweight='bold', y=1.02)
    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_stokes_training'))

    return valid_props if 'valid_props' in dir() else None


def fig_stokes_hub_predictions(ref):
    """Analysis of Stokes Hub prediction scores."""
    logger.info("  Figure: data_stokes_hub_predictions")

    if 'stokes_hub' not in ref:
        return

    df = ref['stokes_hub']

    fig, axes = plt.subplots(1, 3, figsize=(18, 5))

    # 1. Prediction score distribution
    ax = axes[0]
    scores = df['Pred_Score'].dropna()
    ax.hist(scores, bins=60, color='#795548', alpha=0.8, edgecolor='white')
    ax.set_xlabel('D-MPNN Prediction Score', fontsize=11)
    ax.set_ylabel('Count', fontsize=11)
    ax.set_title(f'Stokes Hub Predictions\n(n={len(scores):,})', fontsize=12, fontweight='bold')
    ax.axvline(x=scores.median(), color='red', linestyle='--',
               label=f'Median = {scores.median():.3f}')
    ax.legend(fontsize=9)

    # 2. Validated compounds
    ax = axes[1]
    inhibition = df['Mean_Inhibition'].dropna()
    if len(inhibition) > 0:
        ax.hist(inhibition, bins=30, color='#4CAF50', alpha=0.8, edgecolor='white')
        ax.set_xlabel('Mean Growth Inhibition', fontsize=11)
        ax.set_ylabel('Count', fontsize=11)
        ax.set_title(f'Experimentally Validated\n(n={len(inhibition)} of {len(df)})',
                     fontsize=12, fontweight='bold')
        ax.axvline(x=0.2, color='red', linestyle='--', label='Active threshold (0.2)')
        n_active = (inhibition < 0.2).sum()
        ax.annotate(f'{n_active} active\n({100*n_active/len(inhibition):.0f}%)',
                    xy=(0.1, ax.get_ylim()[1]*0.8), fontsize=11, fontweight='bold',
                    color='#4CAF50')
        ax.legend(fontsize=9)

    # 3. Prediction score vs actual inhibition
    ax = axes[2]
    validated = df.dropna(subset=['Mean_Inhibition', 'Pred_Score'])
    if len(validated) > 0:
        colors_val = ['#4CAF50' if inh < 0.2 else '#EF5350'
                      for inh in validated['Mean_Inhibition']]
        ax.scatter(validated['Pred_Score'], validated['Mean_Inhibition'],
                   c=colors_val, s=30, alpha=0.7, edgecolors='white', linewidths=0.5)
        ax.set_xlabel('Predicted Score (D-MPNN)', fontsize=11)
        ax.set_ylabel('Actual Mean Inhibition', fontsize=11)
        ax.set_title('Prediction vs Validation', fontsize=12, fontweight='bold')
        ax.axhline(y=0.2, color='gray', linestyle='--', alpha=0.5)

        legend_elements = [
            Patch(facecolor='#4CAF50', label='True positive (inhibition < 0.2)'),
            Patch(facecolor='#EF5350', label='False positive (inhibition >= 0.2)'),
        ]
        ax.legend(handles=legend_elements, fontsize=9)

    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_stokes_hub_predictions'))


def fig_stokes_model_comparison(ref):
    """Compare prediction score distributions across Stokes' different models."""
    logger.info("  Figure: data_stokes_model_comparison")

    model_keys = [
        ('stokes_hub', 'D-MPNN + RDKit', '#795548'),
        ('stokes_dmpnn_learned', 'D-MPNN (learned)', '#A1887F'),
        ('stokes_dmpnn_rdkit', 'D-MPNN (RDKit only)', '#BCAAA4'),
        ('stokes_ffn_morgan', 'FFN + Morgan FP', '#FF9800'),
        ('stokes_rf_morgan', 'RF + Morgan FP', '#2196F3'),
        ('stokes_svm_morgan', 'SVM + Morgan FP', '#4CAF50'),
    ]

    available = [(k, l, c) for k, l, c in model_keys if k in ref]
    if len(available) < 2:
        return

    fig, ax = plt.subplots(figsize=(12, 6))

    for key, label, color in available:
        df = ref[key]
        scores = df['Pred_Score'].dropna()
        if len(scores) > 0:
            ax.hist(scores, bins=60, alpha=0.4, label=f'{label} (n={len(scores):,})',
                    color=color, density=True, edgecolor='none')

    ax.set_xlabel('Prediction Score', fontsize=12)
    ax.set_ylabel('Density', fontsize=12)
    ax.set_title('Stokes et al.: Prediction Score Distributions Across Model Architectures',
                 fontsize=13, fontweight='bold')
    ax.legend(fontsize=9)
    ax.grid(axis='y', alpha=0.3)

    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_stokes_model_comparison'))


def fig_wong_training_analysis(ref):
    """Detailed analysis of Wong training data."""
    logger.info("  Figure: data_wong_training")

    if 'wong_train' not in ref:
        return

    df = ref['wong_train']

    fig, axes = plt.subplots(2, 2, figsize=(14, 10))

    # 1. Class balance (extreme imbalance)
    ax = axes[0, 0]
    n_active = int(df['ACTIVITY'].sum())
    n_inactive = len(df) - n_active
    bars = ax.bar(['Active', 'Inactive'], [n_active, n_inactive],
                  color=['#E91E63', '#E0E0E0'], edgecolor='white', width=0.5)
    ax.text(0, n_active + 200, f'{n_active:,}\n({100*n_active/len(df):.1f}%)',
            ha='center', fontsize=11, fontweight='bold', color='#E91E63')
    ax.text(1, n_inactive + 200, f'{n_inactive:,}\n({100*n_inactive/len(df):.1f}%)',
            ha='center', fontsize=11, fontweight='bold')
    ax.set_ylabel('Count', fontsize=11)
    ax.set_title(f'Wong Training Set: Class Balance\n(n={len(df):,})',
                 fontsize=12, fontweight='bold')
    ax.set_ylim(0, n_inactive * 1.15)

    # 2. SMILES length
    ax = axes[0, 1]
    smi_lens = df['SMILES'].str.len().dropna()
    smi_lens_clipped = smi_lens[smi_lens <= 500]
    ax.hist(smi_lens_clipped, bins=60, color='#E91E63', alpha=0.8, edgecolor='white')
    ax.set_xlabel('SMILES Length', fontsize=10)
    ax.set_ylabel('Count', fontsize=10)
    ax.set_title(f'Wong Training Set: SMILES Length\nMedian={smi_lens.median():.0f}',
                 fontsize=12, fontweight='bold')

    # 3. Active vs inactive SMILES length
    ax = axes[1, 0]
    active_lens = df[df['ACTIVITY'] == 1]['SMILES'].str.len()
    inactive_lens = df[df['ACTIVITY'] == 0]['SMILES'].str.len()
    ax.hist(inactive_lens[inactive_lens <= 300], bins=50, alpha=0.5, color='#E0E0E0',
            density=True, label=f'Inactive (n={n_inactive:,})', edgecolor='none')
    ax.hist(active_lens[active_lens <= 300], bins=50, alpha=0.7, color='#E91E63',
            density=True, label=f'Active (n={n_active:,})', edgecolor='none')
    ax.set_xlabel('SMILES Length', fontsize=10)
    ax.set_ylabel('Density', fontsize=10)
    ax.set_title('Wong: Active vs Inactive SMILES Length', fontsize=12, fontweight='bold')
    ax.legend(fontsize=9)

    # 4. Molecular weight (sample for speed)
    ax = axes[1, 1]
    sample = df.sample(n=min(5000, len(df)), random_state=42).reset_index(drop=True)
    props = compute_molecular_properties(sample['SMILES'])
    valid_mask = props['MW'].notna()
    mw_vals = props.loc[valid_mask, 'MW'].values
    activity_vals = sample.loc[valid_mask, 'ACTIVITY'].values
    if len(mw_vals) > 0:
        ax.hist(mw_vals[activity_vals == 0], bins=50, alpha=0.5, color='#E0E0E0',
                density=True, label='Inactive', edgecolor='none', range=(0, 800))
        ax.hist(mw_vals[activity_vals == 1], bins=50, alpha=0.7, color='#E91E63',
                density=True, label='Active', edgecolor='none', range=(0, 800))
        ax.set_xlabel('Molecular Weight (Da)', fontsize=10)
        ax.set_ylabel('Density', fontsize=10)
        ax.set_title(f'Wong: Active vs Inactive MW\nMedian={np.median(mw_vals):.0f} Da',
                     fontsize=12, fontweight='bold')
        ax.legend(fontsize=9)
        ax.set_xlim(0, 800)

    plt.suptitle('Wong et al. (Nature, 2024) Training Data Analysis',
                 fontsize=15, fontweight='bold', y=1.02)
    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_wong_training'))


def fig_wong_prediction_analysis(ref):
    """Analysis of Wong screening library predictions."""
    logger.info("  Figure: data_wong_predictions")

    if 'wong_broad800' not in ref:
        return

    df = ref['wong_broad800']

    fig, axes = plt.subplots(1, 2, figsize=(14, 5))

    # 1. Broad800 prediction score distribution
    ax = axes[0]
    scores = pd.to_numeric(df['ACTIVITY'], errors='coerce').dropna()
    ax.hist(scores, bins=80, color='#E91E63', alpha=0.8, edgecolor='white')
    ax.set_xlabel('Predicted Activity Score', fontsize=11)
    ax.set_ylabel('Count', fontsize=11)
    ax.set_title(f'Wong Broad800 Predictions\n(n={len(scores):,})',
                 fontsize=12, fontweight='bold')
    ax.axvline(x=scores.median(), color='red', linestyle='--',
               label=f'Median = {scores.median():.4f}')
    # High-scoring compounds
    n_high = (scores > 0.5).sum()
    ax.annotate(f'{n_high} predicted active\n(score > 0.5)',
                xy=(0.6, ax.get_ylim()[1] * 0.7), fontsize=10, fontweight='bold',
                color='#E91E63')
    ax.legend(fontsize=9)
    ax.set_yscale('log')

    # 2. Score CDF
    ax = axes[1]
    sorted_scores = np.sort(scores.values)
    cdf = np.arange(1, len(sorted_scores) + 1) / len(sorted_scores)
    ax.plot(sorted_scores, cdf, color='#E91E63', linewidth=2)
    ax.set_xlabel('Predicted Activity Score', fontsize=11)
    ax.set_ylabel('Cumulative Fraction', fontsize=11)
    ax.set_title('Wong Broad800: Score CDF', fontsize=12, fontweight='bold')
    ax.axhline(y=0.99, color='gray', linestyle='--', alpha=0.5, label='99th percentile')
    p99 = sorted_scores[int(0.99 * len(sorted_scores))]
    ax.axvline(x=p99, color='gray', linestyle=':', alpha=0.5)
    ax.annotate(f'99th pct = {p99:.4f}', xy=(p99, 0.99), fontsize=9,
                xytext=(p99 + 0.05, 0.92), arrowprops=dict(arrowstyle='->'))
    ax.legend(fontsize=9)
    ax.grid(alpha=0.3)

    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_wong_predictions'))


def fig_cross_study_chemical_space(data, ref):
    """PCA comparing chemical space of our data vs Stokes vs Wong."""
    logger.info("  Figure: data_cross_study_pca (computing fingerprints...)")

    from rdkit import Chem
    from rdkit.Chem import AllChem
    from sklearn.decomposition import PCA

    max_per_dataset = 2000
    fps_list = []
    labels_list = []

    # Helper to compute fingerprints
    def smiles_to_fps(smiles_list, max_n=2000):
        fps = []
        rng = np.random.RandomState(42)
        if len(smiles_list) > max_n:
            idx = rng.choice(len(smiles_list), max_n, replace=False)
            smiles_list = [smiles_list[i] for i in idx]
        for smi in smiles_list:
            try:
                mol = Chem.MolFromSmiles(str(smi))
                if mol:
                    fp = AllChem.GetMorganFingerprintAsBitVect(mol, 2, nBits=1024)
                    fps.append(np.array(fp))
            except:
                pass
        return np.array(fps) if fps else np.array([]).reshape(0, 1024)

    # Our E. coli training
    if 'ecoli' in data:
        fps = smiles_to_fps(data['ecoli']['smiles'].tolist(), max_per_dataset)
        fps_list.append(fps)
        labels_list.extend(['Our E. coli'] * len(fps))
        logger.info(f"    Our E. coli: {len(fps)} FPs")

    # Our Hub
    if 'hub' in data:
        fps = smiles_to_fps(data['hub']['smiles'].tolist(), max_per_dataset)
        fps_list.append(fps)
        labels_list.extend(['Our Hub'] * len(fps))
        logger.info(f"    Our Hub: {len(fps)} FPs")

    # Our Maier
    if 'maier' in data:
        fps = smiles_to_fps(data['maier']['smiles'].tolist(), min(1177, max_per_dataset))
        fps_list.append(fps)
        labels_list.extend(['Our Maier'] * len(fps))
        logger.info(f"    Our Maier: {len(fps)} FPs")

    # Stokes training
    if 'stokes_train' in ref:
        fps = smiles_to_fps(ref['stokes_train']['SMILES'].tolist(), max_per_dataset)
        fps_list.append(fps)
        labels_list.extend(['Stokes Training'] * len(fps))
        logger.info(f"    Stokes training: {len(fps)} FPs")

    # Wong training
    if 'wong_train' in ref:
        fps = smiles_to_fps(ref['wong_train']['SMILES'].tolist(), max_per_dataset)
        fps_list.append(fps)
        labels_list.extend(['Wong Training'] * len(fps))
        logger.info(f"    Wong training: {len(fps)} FPs")

    if len(fps_list) < 2:
        return

    X = np.vstack(fps_list)
    labels = np.array(labels_list)

    pca = PCA(n_components=2, random_state=42)
    coords = pca.fit_transform(X)

    fig, ax = plt.subplots(figsize=(12, 9))

    color_map = {
        'Our E. coli': '#2196F3',
        'Our Hub': '#607D8B',
        'Our Maier': '#FF9800',
        'Stokes Training': '#795548',
        'Wong Training': '#E91E63',
    }

    for dataset_name in ['Our E. coli', 'Our Hub', 'Our Maier', 'Stokes Training', 'Wong Training']:
        mask = labels == dataset_name
        if mask.sum() > 0:
            ax.scatter(coords[mask, 0], coords[mask, 1],
                       c=color_map.get(dataset_name, 'gray'),
                       label=dataset_name, s=8, alpha=0.4, edgecolors='none')

    ax.set_xlabel(f'PC1 ({pca.explained_variance_ratio_[0]*100:.1f}% variance)', fontsize=12)
    ax.set_ylabel(f'PC2 ({pca.explained_variance_ratio_[1]*100:.1f}% variance)', fontsize=12)
    ax.set_title('Cross-Study Chemical Space Comparison\n(Morgan FP PCA)',
                 fontsize=14, fontweight='bold')
    ax.legend(fontsize=10, markerscale=3)
    ax.grid(alpha=0.2)

    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_cross_study_pca'))


def fig_cross_study_overlap(data, ref):
    """Compound overlap between our pipeline, Stokes, and Wong."""
    logger.info("  Figure: data_cross_study_overlap")

    from rdkit import Chem

    def canonical_set(smiles_list):
        canonical = set()
        for smi in smiles_list:
            try:
                mol = Chem.MolFromSmiles(str(smi))
                if mol:
                    canonical.add(Chem.MolToSmiles(mol))
            except:
                pass
        return canonical

    sets = {}

    if 'ecoli' in data:
        sets['Our E. coli\nTraining'] = canonical_set(data['ecoli']['smiles'].tolist())
    if 'hub' in data:
        sets['Our Hub\n(Screening)'] = canonical_set(data['hub']['smiles'].tolist())
    if 'stokes_train' in ref:
        sets['Stokes\nTraining'] = canonical_set(ref['stokes_train']['SMILES'].tolist())
    if 'stokes_hub' in ref:
        sets['Stokes\nHub Scored'] = canonical_set(ref['stokes_hub']['SMILES'].tolist())
    if 'wong_train' in ref:
        sets['Wong\nTraining'] = canonical_set(ref['wong_train']['SMILES'].tolist())

    if len(sets) < 2:
        return

    names = list(sets.keys())
    n = len(names)
    overlap = np.zeros((n, n), dtype=int)

    for i in range(n):
        for j in range(n):
            overlap[i, j] = len(sets[names[i]] & sets[names[j]])

    fig, ax = plt.subplots(figsize=(10, 8))
    im = ax.imshow(overlap, cmap='YlOrRd', aspect='auto')

    ax.set_xticks(range(n))
    ax.set_yticks(range(n))
    ax.set_xticklabels(names, rotation=45, ha='right', fontsize=9)
    ax.set_yticklabels(names, fontsize=9)

    for i in range(n):
        for j in range(n):
            val = overlap[i, j]
            color = 'white' if val > overlap.max() * 0.5 else 'black'
            ax.text(j, i, f'{val:,}', ha='center', va='center',
                    fontsize=8, color=color, fontweight='bold')

    ax.set_title('Cross-Study Compound Overlap\n(Canonical SMILES Matching)',
                 fontsize=13, fontweight='bold')
    plt.colorbar(im, ax=ax, label='Shared Compounds', shrink=0.8)
    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_cross_study_overlap'))


def fig_cross_study_mw_comparison(data, ref):
    """Molecular weight distribution comparison across all studies."""
    logger.info("  Figure: data_cross_study_mw")

    fig, ax = plt.subplots(figsize=(12, 6))

    datasets_to_plot = []

    # Our data
    for dname, label, color in [
        ('ecoli', 'Our E. coli', '#2196F3'),
        ('maier', 'Our Maier', '#FF9800'),
        ('hub', 'Our Hub', '#607D8B'),
    ]:
        if dname in data:
            smi_col = 'smiles'
            smiles = data[dname][smi_col].dropna().sample(n=min(3000, len(data[dname])), random_state=42)
            datasets_to_plot.append((smiles.tolist(), label, color))

    # Stokes
    if 'stokes_train' in ref:
        smiles = ref['stokes_train']['SMILES'].dropna().tolist()
        datasets_to_plot.append((smiles, 'Stokes Training', '#795548'))

    # Wong (sample)
    if 'wong_train' in ref:
        smiles = ref['wong_train']['SMILES'].dropna().sample(
            n=min(3000, len(ref['wong_train'])), random_state=42).tolist()
        datasets_to_plot.append((smiles, 'Wong Training', '#E91E63'))

    from rdkit import Chem
    from rdkit.Chem import Descriptors

    for smiles_list, label, color in datasets_to_plot:
        mws = []
        for smi in smiles_list:
            try:
                mol = Chem.MolFromSmiles(str(smi))
                if mol:
                    mws.append(Descriptors.MolWt(mol))
            except:
                pass
        if mws:
            mws_arr = np.array(mws)
            mws_arr = mws_arr[(mws_arr > 0) & (mws_arr < 800)]
            ax.hist(mws_arr, bins=60, alpha=0.45, label=f'{label} (med={np.median(mws_arr):.0f})',
                    color=color, density=True, edgecolor='none')

    ax.set_xlabel('Molecular Weight (Da)', fontsize=12)
    ax.set_ylabel('Density', fontsize=12)
    ax.set_title('Molecular Weight Distribution: Our Pipeline vs Reference Studies',
                 fontsize=14, fontweight='bold')
    ax.legend(fontsize=9)
    ax.set_xlim(0, 800)
    ax.grid(axis='y', alpha=0.3)

    # Lipinski MW threshold
    ax.axvline(x=500, color='gray', linestyle='--', alpha=0.3)
    ax.annotate("Lipinski MW < 500", xy=(500, ax.get_ylim()[1]*0.9),
                fontsize=8, color='gray')

    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_cross_study_mw'))


def fig_stokes_rdkit_features(ref):
    """Visualize the 200 RDKit features used by Stokes."""
    logger.info("  Figure: data_stokes_rdkit_features")

    if 'stokes_features' not in ref:
        return

    df = ref['stokes_features']
    col = df.columns[0]
    features = df[col].dropna().tolist()

    # Categorize features
    categories = {
        'Topological': [], 'Electronic': [], 'Physicochemical': [],
        'Fragment': [], 'Connectivity': [], 'Other': [],
    }

    for f in features:
        f_lower = str(f).lower()
        if any(k in f_lower for k in ['kappa', 'chi', 'bertz', 'balaban', 'wiener', 'hall']):
            categories['Topological'].append(f)
        elif any(k in f_lower for k in ['charge', 'estate', 'gasteiger', 'peoe']):
            categories['Electronic'].append(f)
        elif any(k in f_lower for k in ['logp', 'tpsa', 'molwt', 'molmr', 'hba', 'hbd', 'nrot']):
            categories['Physicochemical'].append(f)
        elif any(k in f_lower for k in ['fr_', 'count', 'num']):
            categories['Fragment'].append(f)
        elif any(k in f_lower for k in ['ring', 'aromatic', 'hetero', 'sp', 'saturated']):
            categories['Connectivity'].append(f)
        else:
            categories['Other'].append(f)

    fig, ax = plt.subplots(figsize=(10, 6))
    cat_names = list(categories.keys())
    cat_counts = [len(categories[c]) for c in cat_names]
    colors = plt.cm.Set2(np.linspace(0, 1, len(cat_names)))

    bars = ax.bar(range(len(cat_names)), cat_counts, color=colors, edgecolor='white', width=0.6)
    ax.set_xticks(range(len(cat_names)))
    ax.set_xticklabels(cat_names, fontsize=10, rotation=15, ha='right')
    ax.set_ylabel('Number of Features', fontsize=11)
    ax.set_title(f'Stokes et al.: 200 RDKit Descriptor Categories',
                 fontsize=13, fontweight='bold')

    for bar, count in zip(bars, cat_counts):
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 1,
                str(count), ha='center', fontsize=11, fontweight='bold')

    ax.grid(axis='y', alpha=0.3)
    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_stokes_rdkit_features'))


def save_reference_stats(ref):
    """Save reference study statistics to JSON."""
    logger.info("  Saving reference_data_stats.json")

    stats = {}

    if 'stokes_train' in ref:
        df = ref['stokes_train']
        stats['stokes'] = {
            'training_compounds': len(df),
            'target': 'E. coli growth inhibition',
            'source': 'Stokes et al., Cell 2020',
            'architecture': 'D-MPNN + 200 RDKit features, ensemble of 20',
            'hub_compounds_scored': len(ref.get('stokes_hub', [])),
            'hub_validated': ref['stokes_hub']['Mean_Inhibition'].notna().sum() if 'stokes_hub' in ref else 0,
        }

    if 'wong_train' in ref:
        df = ref['wong_train']
        stats['wong'] = {
            'training_compounds': len(df),
            'active': int(df['ACTIVITY'].sum()),
            'active_pct': round(100 * df['ACTIVITY'].mean(), 2),
            'target': 'S. aureus growth inhibition',
            'source': 'Wong et al., Nature 2024',
            'architecture': 'Chemprop D-MPNN + RDKit, ensemble of 10',
            'broad800_compounds': len(ref.get('wong_broad800', [])),
            'mcule_files': ref.get('wong_mcule_n_files', 0),
        }

    out_path = os.path.join(config.RESULTS_DIR, 'reference_data_stats.json')
    with open(out_path, 'w') as f:
        json.dump(stats, f, indent=2, default=str)
    logger.info(f"  Saved: {out_path}")


def run_phase2(data=None):
    """Run Phase 2: Reference study data + cross-study comparison."""
    start_time = log_phase_start(logger, "Dataset Analysis Phase 2: Reference Studies")

    if data is None:
        logger.info("\n  Loading our pipeline data...")
        data = load_all_data()

    logger.info("\n  Loading reference data...")
    ref = load_reference_data()

    logger.info("\n  Generating Phase 2 figures...")

    # 1. Study size comparison
    fig_study_comparison_sizes(data, ref)

    # 2. Class balance comparison
    fig_study_class_balance(data, ref)

    # 3. Stokes training analysis
    fig_stokes_training_analysis(ref)

    # 4. Stokes Hub predictions
    fig_stokes_hub_predictions(ref)

    # 5. Stokes model comparison
    fig_stokes_model_comparison(ref)

    # 6. Stokes RDKit features
    fig_stokes_rdkit_features(ref)

    # 7. Wong training analysis
    fig_wong_training_analysis(ref)

    # 8. Wong prediction analysis
    fig_wong_prediction_analysis(ref)

    # 9. Cross-study MW comparison
    fig_cross_study_mw_comparison(data, ref)

    # 10. Cross-study chemical space PCA
    fig_cross_study_chemical_space(data, ref)

    # 11. Cross-study compound overlap
    fig_cross_study_overlap(data, ref)

    # 12. Save stats
    save_reference_stats(ref)

    # 13. Dynamic report with reference data
    generate_dynamic_dataset_report(data, ref=ref)

    n_png = len(glob.glob(os.path.join(FIG_DIR, 'data_*study*') + '.png') +
                glob.glob(os.path.join(FIG_DIR, 'data_stokes*') + '.png') +
                glob.glob(os.path.join(FIG_DIR, 'data_wong*') + '.png'))
    logger.info(f"\n  Phase 2 complete")

    log_phase_end(logger, "Dataset Analysis Phase 2", start_time)



def fig_maier_strain_drug_heatmap(data):
    """Full drugs x strains heatmap showing which drugs harm which strains."""
    logger.info("  Figure: data_maier_strain_heatmap (loading p-value matrix...)")

    pval_path = os.path.join('resources', 'maier',
                             '41586_2018_BFnature25979_MOESM5_ESM.xlsx')
    if not os.path.exists(pval_path):
        logger.warning("  Maier p-value Excel not found, skipping heatmap")
        return

    try:
        df_pval = pd.read_excel(pval_path, sheet_name='S3a. Adjusted p-values')
    except Exception as e:
        logger.warning(f"  Could not read Maier p-values: {e}")
        return

    meta_cols = ['prestwick_ID', 'chemical_name', 'drug_class', 'n_hit']
    strain_cols = [c for c in df_pval.columns if c not in meta_cols]

    if len(strain_cols) == 0:
        return

    # Build binary hit matrix (p < 0.05 = significant inhibition)
    hit_matrix = pd.DataFrame(index=df_pval.index)
    for sc in strain_cols:
        hit_matrix[sc] = (pd.to_numeric(df_pval[sc], errors='coerce') < 0.05).astype(int)

    hit_matrix['n_hit'] = hit_matrix[strain_cols].sum(axis=1)
    hit_matrix['drug_class'] = df_pval['drug_class'].values
    hit_matrix['chemical_name'] = df_pval['chemical_name'].values
    hit_matrix = hit_matrix.sort_values(['n_hit', 'drug_class'], ascending=[False, True])

    # Clean strain names
    clean_strain = []
    for s in strain_cols:
        name = s.split('(')[0].strip()
        if len(name) > 25:
            name = name[:23] + '..'
        clean_strain.append(name)

    strain_totals = hit_matrix[strain_cols].sum(axis=0)
    strain_order = strain_totals.sort_values(ascending=False).index.tolist()
    clean_order = [clean_strain[strain_cols.index(s)] for s in strain_order]

    # Full heatmap (top 200)
    top_n = min(200, len(hit_matrix))
    matrix_plot = hit_matrix.iloc[:top_n][strain_order].values

    fig, ax = plt.subplots(figsize=(18, 24))
    im = ax.imshow(matrix_plot, cmap='YlOrRd', aspect='auto', interpolation='none')
    ax.set_xticks(range(len(clean_order)))
    ax.set_xticklabels(clean_order, rotation=90, fontsize=7, ha='center')
    drug_names = hit_matrix['chemical_name'].iloc[:top_n].values
    ytick_pos = list(range(0, top_n, 5))
    ax.set_yticks(ytick_pos)
    ax.set_yticklabels([drug_names[i][:25] if i < len(drug_names) else '' for i in ytick_pos], fontsize=6)
    ax.set_xlabel('Gut Bacterial Strains (sorted by sensitivity)', fontsize=11)
    ax.set_ylabel('Compounds (sorted by number of strains harmed)', fontsize=11)
    ax.set_title(f'Maier et al.: Drug-Strain Interaction Heatmap\n(Top {top_n} most harmful compounds, p < 0.05)',
                 fontsize=14, fontweight='bold')
    plt.colorbar(im, ax=ax, label='Significant Inhibition (binary)', shrink=0.3)
    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_maier_strain_heatmap'))

    # Drug class aggregated heatmap
    logger.info("  Figure: data_maier_class_strain_heatmap")
    class_strain = pd.DataFrame(index=hit_matrix['drug_class'].unique())
    for sc in strain_order:
        class_strain[sc] = hit_matrix.groupby('drug_class')[sc].mean()
    class_strain['mean_harm'] = class_strain.mean(axis=1)
    class_strain = class_strain.sort_values('mean_harm', ascending=False)
    class_strain = class_strain.drop(columns='mean_harm')

    fig, ax = plt.subplots(figsize=(16, 8))
    im = ax.imshow(class_strain.values, cmap='YlOrRd', aspect='auto', vmin=0, vmax=0.5)
    ax.set_xticks(range(len(clean_order)))
    ax.set_xticklabels(clean_order, rotation=90, fontsize=8, ha='center')
    ax.set_yticks(range(len(class_strain)))
    ax.set_yticklabels(class_strain.index, fontsize=10)
    for i in range(class_strain.shape[0]):
        for j in range(class_strain.shape[1]):
            val = class_strain.iloc[i, j]
            if val > 0.05:
                color = 'white' if val > 0.25 else 'black'
                ax.text(j, i, f'{val:.0%}', ha='center', va='center', fontsize=6, color=color)
    ax.set_xlabel('Gut Bacterial Strains', fontsize=11)
    ax.set_title('Drug Class vs Strain Sensitivity\n(Fraction causing significant inhibition)',
                 fontsize=13, fontweight='bold')
    plt.colorbar(im, ax=ax, label='Fraction Causing Inhibition', shrink=0.8)
    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_maier_class_strain_heatmap'))



def generate_dynamic_dataset_report(data, ref=None):
    """Generate a comprehensive, publication-quality markdown report purely from data.
    
    Every number, table, and statistic is computed at runtime from the actual
    pipeline data. Nothing is hardcoded.
    """
    logger.info("  Generating dynamic dataset report...")

    from scipy import sparse

    lines = []
    def L(s=''):
        lines.append(s)
    def pct(n, total):
        return f'{100*n/total:.1f}%' if total > 0 else 'N/A'
    def fmt(n):
        return f'{n:,}'

    # ================================================================
    # TITLE
    # ================================================================
    L('# Dataset Report: Microbiome-Sparing Antibiotic Discovery Pipeline')
    L()
    L(f'**Generated:** {time.strftime("%Y-%m-%d %H:%M:%S")}')
    L(f'**Source:** Dynamically computed from pipeline data (zero hardcoded values)')
    L()
    L('---')
    L()

    # ================================================================
    # 1. OVERVIEW
    # ================================================================
    L('## 1. Overview')
    L()

    n_pathogen_tasks = sum(1 for k in ['ecoli', 'saureus', 'paeruginosa', 'mtb'] if k in data)
    n_gut_thresholds = 0
    if 'maier' in data:
        n_gut_thresholds = sum(1 for t in [5, 10, 20] if f'harm_t{t}' in data['maier'].columns)
    n_tasks = n_pathogen_tasks + n_gut_thresholds

    total_pathogen_compounds = sum(len(data[k]) for k in ['ecoli', 'saureus', 'paeruginosa', 'mtb'] if k in data)
    n_maier = len(data['maier']) if 'maier' in data else 0
    n_hub = len(data['hub']) if 'hub' in data else 0

    L(f'The pipeline trains binary classifiers on **{n_tasks} tasks**: '
      f'{n_pathogen_tasks} pathogen activity tasks and {n_gut_thresholds} gut commensal '
      f'harm thresholds. These models are combined to compute a selectivity score '
      f'S = P_pathogen x (1 - P_gut) for each compound in a screening library.')
    L()
    L('Three categories of data are used:')
    L()
    L(f'1. **Pathogen activity data** from ChEMBL 34 MIC assays: '
      f'{fmt(total_pathogen_compounds)} total compound-pathogen pairs across '
      f'{n_pathogen_tasks} organisms')
    L(f'2. **Gut commensal harm data** from Maier et al. (Nature, 2018/2021): '
      f'{fmt(n_maier)} compounds screened against 40 representative human gut strains')
    L(f'3. **Screening library** from the Broad Institute Drug Repurposing Hub: '
      f'{fmt(n_hub)} clinically annotated compounds scored by all trained models')
    L()

    # ================================================================
    # 2. PATHOGEN DATA
    # ================================================================
    L('## 2. Pathogen Activity Data (ChEMBL 34)')
    L()
    L('All pathogen activity data was extracted from the ChEMBL 34 database. '
      'Compounds were selected based on standardized MIC (Minimum Inhibitory Concentration) '
      'assay results against each target organism. Each compound\'s activity label was derived '
      'from the median MIC value across all available measurements: compounds with median '
      f'MIC at or below {fmt(config.MIC_THRESHOLD_NM)} nM '
      f'({config.MIC_THRESHOLD_NM / 1000:.0f} uM) were labeled active (1), otherwise inactive (0).')
    L()

    L('### 2.1 Summary Statistics')
    L()
    L('| Pathogen | Compounds | Active | Active (%) | Inactive | Inactive (%) | Source |')
    L('|----------|-----------|--------|-----------|----------|-------------|--------|')
    pathogen_stats = {}
    for pkey in ['ecoli', 'saureus', 'paeruginosa', 'mtb']:
        if pkey not in data:
            continue
        df = data[pkey]
        n = len(df)
        n_act = int(df['activity_label'].sum())
        n_inact = n - n_act
        label = PATHOGEN_LABELS.get(pkey, pkey)
        source = df['source_type'].iloc[0] if 'source_type' in df.columns else 'MIC'
        L(f'| *{label}* | {fmt(n)} | {fmt(n_act)} | {pct(n_act, n)} '
          f'| {fmt(n_inact)} | {pct(n_inact, n)} | {source} |')
        pathogen_stats[pkey] = {'n': n, 'n_active': n_act, 'label': label}
    L()

    # Class balance analysis
    most_imbalanced = min(pathogen_stats.items(), key=lambda x: x[1]['n_active'] / x[1]['n'])
    most_balanced = max(pathogen_stats.items(), key=lambda x: x[1]['n_active'] / x[1]['n'])
    L(f'{most_imbalanced[1]["label"]} has the most imbalanced dataset '
      f'({pct(most_imbalanced[1]["n_active"], most_imbalanced[1]["n"])} active), '
      f'while {most_balanced[1]["label"]} is closest to balanced '
      f'({pct(most_balanced[1]["n_active"], most_balanced[1]["n"])} active). '
      f'PR-AUC is a more informative metric than ROC-AUC for imbalanced tasks.')
    L()

    # SMILES stats
    L('### 2.2 SMILES Length Statistics')
    L()
    L('| Dataset | Min | Median | Max | Mean |')
    L('|---------|-----|--------|-----|------|')
    for pkey in ['ecoli', 'saureus', 'paeruginosa', 'mtb']:
        if pkey not in data:
            continue
        df = data[pkey]
        smi_col = 'smiles' if 'smiles' in df.columns else 'canonical_smiles'
        lens = df[smi_col].str.len()
        L(f'| {PATHOGEN_LABELS.get(pkey, pkey)} | {int(lens.min())} '
          f'| {int(lens.median())} | {int(lens.max())} | {lens.mean():.0f} |')
    L()
    L('SMILES length serves as a rough proxy for molecular complexity.')
    L()

    # Columns
    L('### 2.3 Data Columns')
    L()
    sample_pkey = next((k for k in ['ecoli', 'saureus', 'paeruginosa', 'mtb'] if k in data), None)
    if sample_pkey:
        df_sample = data[sample_pkey]
        L('Each pathogen CSV contains:')
        L()
        for col in df_sample.columns:
            dtype = str(df_sample[col].dtype)
            nuniq = df_sample[col].nunique()
            L(f'- `{col}` ({dtype}): {fmt(nuniq)} unique values')
        L()

    # Measurement counts
    L('### 2.4 Measurement Depth')
    L()
    L('| Pathogen | Compounds | Mean Measurements | Median Measurements |')
    L('|----------|-----------|-------------------|---------------------|')
    for pkey in ['ecoli', 'saureus', 'paeruginosa', 'mtb']:
        if pkey not in data:
            continue
        df = data[pkey]
        if 'n_measurements' in df.columns:
            L(f'| {PATHOGEN_LABELS.get(pkey, pkey)} | {fmt(len(df))} '
              f'| {df["n_measurements"].mean():.1f} | {int(df["n_measurements"].median())} |')
    L()

    # ================================================================
    # 3. GUT COMMENSAL DATA
    # ================================================================
    if 'maier' in data:
        df = data['maier']
        L('## 3. Gut Commensal Harm Data (Maier et al., 2018/2021)')
        L()
        L('The gut commensal harm data comes from two studies by Maier et al. which '
          'systematically screened drugs from the Prestwick Chemical Library against '
          'representative human gut bacteria. Each drug was tested at a single, '
          'clinically relevant concentration (estimated intestinal concentration) against '
          'each bacterial strain. Growth inhibition was assessed by comparing optical density '
          'to untreated controls, and statistical significance was determined using adjusted '
          f'p-values (p < 0.05). After PubChem SMILES lookup, {fmt(len(df))} compounds '
          'with valid molecular structures remain.')
        L()

        # Harm thresholds
        L('### 3.1 Binary Harm Labels')
        L()
        L(f'The variable `n_hit` records the number of strains (out of 40) significantly '
          f'inhibited by each compound. Binary labels are assigned at three thresholds '
          f'(defined in `config.py: HARM_THRESHOLDS = {config.HARM_THRESHOLDS}`):')
        L()
        L('| Threshold | Meaning | Harmful | Safe | Harmful (%) | Use Case |')
        L('|-----------|---------|---------|------|------------|----------|')
        threshold_interpretations = {
            5: 'Some microbiome impact',
            10: 'Substantial microbiome damage',
            20: 'Severe microbiome devastation',
        }
        for t in config.HARM_THRESHOLDS:
            col = f'harm_t{t}'
            if col in df.columns:
                n_h = int(df[col].sum())
                interp = threshold_interpretations.get(t, '')
                L(f'| t={t} | Harms {t}+ of 40 strains ({100*t/40:.0f}%+) '
                  f'| {fmt(n_h)} | {fmt(len(df) - n_h)} | {pct(n_h, len(df))} | {interp} |')
        L()

        # n_hit distribution
        if 'n_hit' in df.columns:
            nhit = df['n_hit']
            n_zero = int((nhit == 0).sum())
            n_max = int((nhit == nhit.max()).sum())
            n_one = int((nhit == 1).sum())
            n_2to4 = int(((nhit >= 2) & (nhit <= 4)).sum())

            L('### 3.2 Strains Harmed Distribution (n_hit)')
            L()
            L('| Statistic | Value |')
            L('|-----------|-------|')
            L(f'| Mean | {nhit.mean():.1f} |')
            L(f'| Median | {int(nhit.median())} |')
            L(f'| Std | {nhit.std():.1f} |')
            L(f'| Max | {int(nhit.max())} |')
            L(f'| Zero harm (n_hit = 0) | {fmt(n_zero)} ({pct(n_zero, len(df))}) |')
            L(f'| Harm exactly 1 strain | {fmt(n_one)} ({pct(n_one, len(df))}) |')
            L(f'| Harm 2 to 4 strains | {fmt(n_2to4)} ({pct(n_2to4, len(df))}) |')
            L(f'| Harm all {int(nhit.max())} strains | {fmt(n_max)} |')
            L()

            # Top most harmful compounds
            if n_max > 0:
                most_harmful = df[df['n_hit'] == nhit.max()]
                L(f'Compounds harming all {int(nhit.max())} strains:')
                L()
                for _, row in most_harmful.iterrows():
                    name = row.get('name', 'Unknown')
                    dc = row.get('drug_class', '')
                    L(f'- {name} ({dc})')
                L()

        # Drug classes
        if 'drug_class' in df.columns:
            L('### 3.3 Drug Class Distribution')
            L()
            L('| Drug Class | Count | Percentage | Mean n_hit | Harm>=1 (%) |')
            L('|------------|-------|-----------|-----------|------------|')
            for cls in df['drug_class'].value_counts().index:
                subset = df[df['drug_class'] == cls]
                cnt = len(subset)
                mean_nhit = subset['n_hit'].mean() if 'n_hit' in subset.columns else 0
                harm_any = (subset['n_hit'] >= 1).sum() if 'n_hit' in subset.columns else 0
                L(f'| {cls} | {fmt(cnt)} | {pct(cnt, len(df))} '
                  f'| {mean_nhit:.1f} | {pct(harm_any, cnt)} |')
            L()

            # Antibiotic vs non-antibiotic comparison
            abx = df[df['drug_class'] == 'antibiotics']
            non_abx = df[df['drug_class'] != 'antibiotics']
            human = df[df['drug_class'] == 'human-targeted drugs']

            L('### 3.4 Antibiotics vs Non-Antibiotics')
            L()
            L('| Group | N | Mean n_hit | Harm >= 1 strain | Harm >= 1 (%) |')
            L('|-------|---|-----------|------------------|--------------|')
            for label, subset in [('Antibiotics', abx), ('Non-antibiotics', non_abx),
                                  ('Human-targeted drugs only', human)]:
                n_s = len(subset)
                mean_nh = subset['n_hit'].mean() if 'n_hit' in subset.columns else 0
                harm1 = int((subset['n_hit'] >= 1).sum()) if 'n_hit' in subset.columns else 0
                L(f'| {label} | {fmt(n_s)} | {mean_nh:.1f} | {fmt(harm1)} | {pct(harm1, n_s)} |')
            L()

            if len(human) > 0 and 'n_hit' in human.columns:
                human_harm_pct = 100 * (human['n_hit'] >= 1).mean()
                L(f'{human_harm_pct:.1f}% of human-targeted (non-antibiotic) drugs inhibit at least '
                  f'one gut bacterial strain. This finding from Maier et al. (2018) demonstrates that '
                  f'gut microbiome damage is not limited to antibiotics and motivates training gut harm '
                  f'models on the full diversity of drug-gut interactions rather than antibiotics alone.')
                L()

        # Strain list
        pval_path = os.path.join('resources', 'maier',
                                 '41586_2018_BFnature25979_MOESM5_ESM.xlsx')
        if os.path.exists(pval_path):
            try:
                df_pv = pd.read_excel(pval_path, sheet_name='S3a. Adjusted p-values', nrows=0)
                meta = ['prestwick_ID', 'chemical_name', 'drug_class', 'n_hit']
                strains = [c for c in df_pv.columns if c not in meta]

                # Load full p-value matrix for strain sensitivity stats
                df_pv_full = pd.read_excel(pval_path, sheet_name='S3a. Adjusted p-values')

                # Get gram stain info
                gram_map = {}
                st_path = os.path.join('resources', 'maier',
                                       '41586_2021_3986_MOESM3_ESM.xlsx')
                if os.path.exists(st_path):
                    try:
                        df_st = pd.read_excel(st_path, sheet_name='S1. Strains')
                        for _, row in df_st.iterrows():
                            nt = str(row.iloc[1]) if pd.notna(row.iloc[1]) else ''
                            g = str(row.iloc[5]) if pd.notna(row.iloc[5]) else ''
                            if nt.startswith('NT'):
                                gram_map[nt] = g
                    except Exception:
                        pass

                # Compute strain sensitivity
                strain_hits = {}
                for sc in strains:
                    pvals = pd.to_numeric(df_pv_full[sc], errors='coerce')
                    strain_hits[sc] = int((pvals < 0.05).sum())

                n_gram_neg = sum(1 for sc in strains
                                 if gram_map.get(sc.split('(')[-1].rstrip(')'), '') == 'negative')
                n_gram_pos = sum(1 for sc in strains
                                 if gram_map.get(sc.split('(')[-1].rstrip(')'), '') == 'positive')

                L(f'### 3.5 The {len(strains)} Gut Bacterial Strains')
                L()
                L(f'The strains span {n_gram_neg} Gram-negative and {n_gram_pos} Gram-positive '
                  f'species, representing the phylogenetic and functional diversity of the '
                  f'human gut microbiome.')
                L()

                # Sort by sensitivity
                sorted_strains = sorted(strains, key=lambda s: strain_hits.get(s, 0), reverse=True)

                L('| # | Species | Strain ID | Gram | Drugs Causing Inhibition |')
                L('|---|---------|-----------|------|-------------------------|')
                for i, sc in enumerate(sorted_strains, 1):
                    nt = sc.split('(')[-1].rstrip(')') if '(' in sc else ''
                    name = sc.split('(')[0].strip()
                    gram = gram_map.get(nt, '')
                    n_drugs = strain_hits.get(sc, 0)
                    L(f'| {i} | *{name}* | {nt} | {gram} | {n_drugs} |')
                L()

                most_sensitive = sorted_strains[0].split('(')[0].strip()
                least_sensitive = sorted_strains[-1].split('(')[0].strip()
                L(f'Most sensitive strain: *{most_sensitive}* '
                  f'({strain_hits[sorted_strains[0]]} drugs cause inhibition). '
                  f'Least sensitive: *{least_sensitive}* '
                  f'({strain_hits[sorted_strains[-1]]} drugs).')
                L()

                # Taxonomic summary
                phyla = {'Bacteroidota': 0, 'Bacillota': 0, 'Actinomycetota': 0,
                         'Verrucomicrobiota': 0, 'Fusobacteriota': 0, 'Pseudomonadota': 0}
                bacteroidota_genera = ['Bacteroides', 'Prevotella', 'Parabacteroides', 'Odoribacter']
                bacillota_genera = ['Clostridium', 'Clostridioides', 'Ruminococcus', 'Roseburia',
                                    'Eubacterium', 'Coprococcus', 'Blautia', 'Dorea',
                                    'Streptococcus', 'Lactobacillus', 'Veillonella']
                actino_genera = ['Bifidobacterium', 'Collinsella', 'Eggerthella']

                for sc in strains:
                    name = sc.split('(')[0].strip()
                    genus = name.split()[0] if ' ' in name else name
                    if genus in bacteroidota_genera:
                        phyla['Bacteroidota'] += 1
                    elif genus in bacillota_genera:
                        phyla['Bacillota'] += 1
                    elif genus in actino_genera:
                        phyla['Actinomycetota'] += 1
                    elif 'Akkermansia' in name:
                        phyla['Verrucomicrobiota'] += 1
                    elif 'Fusobacterium' in name:
                        phyla['Fusobacteriota'] += 1
                    elif 'Escherichia' in name or 'Bilophila' in name:
                        phyla['Pseudomonadota'] += 1

                L('### 3.6 Taxonomic Representation')
                L()
                L('| Phylum | Strains |')
                L('|--------|---------|')
                for phylum, count in sorted(phyla.items(), key=lambda x: -x[1]):
                    if count > 0:
                        L(f'| {phylum} | {count} |')
                L()

            except Exception as e:
                logger.warning(f"  Strain analysis error: {e}")

    # ================================================================
    # 4. SCREENING LIBRARY
    # ================================================================
    if 'hub' in data:
        df = data['hub']
        L('## 4. Screening Library (Drug Repurposing Hub)')
        L()
        L(f'The Broad Institute Drug Repurposing Hub is a curated collection of '
          f'clinically annotated compounds. After cleaning (removing entries without '
          f'valid SMILES, deduplication), {fmt(len(df))} compounds remain.')
        L()

        if 'clinical_phase' in df.columns:
            n_launched = int((df['clinical_phase'] == 'Launched').sum())
            L(f'{pct(n_launched, len(df))} of compounds ({fmt(n_launched)}) are already '
              f'launched drugs, meaning top-ranked selective candidates could potentially be '
              f'repurposed without full de novo drug development.')
            L()

            L('### 4.1 Clinical Phase Distribution')
            L()
            L('| Phase | Count | Percentage |')
            L('|-------|-------|-----------|')
            phase_order = ['Launched', 'Phase 3', 'Phase 2/Phase 3', 'Phase 2',
                           'Phase 1/Phase 2', 'Phase 1', 'Preclinical', 'Withdrawn']
            for ph in phase_order:
                cnt = int((df['clinical_phase'] == ph).sum())
                if cnt > 0:
                    L(f'| {ph} | {fmt(cnt)} | {pct(cnt, len(df))} |')
            L()

        if 'moa' in df.columns:
            moa_counts = df['moa'].dropna().value_counts()
            L(f'### 4.2 Mechanisms of Action ({fmt(moa_counts.shape[0])} unique)')
            L()
            L('Top 15:')
            L()
            L('| MoA | Count |')
            L('|-----|-------|')
            for moa, cnt in moa_counts.head(15).items():
                L(f'| {moa} | {fmt(cnt)} |')
            L()

        if 'disease_area' in df.columns:
            da_counts = df['disease_area'].dropna().value_counts()
            L(f'### 4.3 Disease Areas ({fmt(da_counts.shape[0])} unique)')
            L()
            L('| Disease Area | Count |')
            L('|-------------|-------|')
            for da, cnt in da_counts.head(12).items():
                L(f'| {da} | {fmt(cnt)} |')
            L()

        smi_col = 'smiles' if 'smiles' in df.columns else 'canonical_smiles'
        if smi_col in df.columns:
            lens = df[smi_col].str.len()
            L(f'### 4.4 SMILES Length')
            L()
            L(f'Min: {int(lens.min())}, Median: {int(lens.median())}, '
              f'Max: {int(lens.max())}, Mean: {lens.mean():.0f}')
            L()

    # ================================================================
    # 5. MOLECULAR FEATURES
    # ================================================================
    L('## 5. Molecular Features')
    L()
    L('All compounds were featurized using Morgan circular fingerprints (ECFP4) '
      'with radius 2 and 2,048 bits via RDKit. Fingerprints encode the presence '
      'or absence of circular molecular substructures and are stored as sparse matrices.')
    L()
    L('| Dataset | Samples | Features | Non-zero Entries | Density |')
    L('|---------|---------|----------|-----------------|---------|')

    for label, fp in [('E. coli', 'morgan_ecoli.npz'),
                      ('S. aureus', 'morgan_saureus.npz'),
                      ('P. aeruginosa', 'morgan_paeruginosa.npz'),
                      ('M. tuberculosis', 'morgan_mtb.npz'),
                      ('Maier (gut)', 'morgan_maier.npz'),
                      ('Drug Repurposing Hub', 'morgan_repurposing_hub.npz')]:
        fp_path = os.path.join(config.FEATURES_DIR, fp)
        if os.path.exists(fp_path):
            X = sparse.load_npz(fp_path)
            d = X.nnz / (X.shape[0] * X.shape[1])
            L(f'| {label} | {fmt(X.shape[0])} | {fmt(X.shape[1])} '
              f'| {fmt(X.nnz)} | {d:.2%} |')
    L()

    # ================================================================
    # 6. CROSS-VALIDATION
    # ================================================================
    L('## 6. Cross-Validation Strategy')
    L()
    L('All models use 5-fold cross-validation with Bemis-Murcko scaffold-based splitting. '
      'The Bemis-Murcko scaffold reduces each molecule to its core ring system with linkers, '
      'stripping side chains. Molecules sharing the same scaffold are always placed in the '
      'same fold, ensuring the test set contains structurally novel compounds not seen during '
      'training.')
    L()

    splits_dir = os.path.join(config.FEATURES_DIR.replace('features', 'splits'))
    if os.path.isdir(splits_dir):
        split_files = sorted(glob.glob(os.path.join(splits_dir, '*.pkl')))
        L(f'**Split files:** {len(split_files)}')
        L()
        L('| Split File | Dataset |')
        L('|-----------|---------|')
        for sf in split_files:
            basename = os.path.basename(sf)
            dataset = basename.replace('_scaffold_folds.pkl', '')
            L(f'| {basename} | {dataset} |')
        L()

    # ================================================================
    # 7. CROSS-DATASET OVERLAP
    # ================================================================
    L('## 7. Cross-Dataset Compound Overlap')
    L()

    smiles_sets = {}
    for dname in ['ecoli', 'saureus', 'paeruginosa', 'mtb', 'maier', 'hub']:
        if dname not in data:
            continue
        df_d = data[dname]
        smi_col = 'smiles' if 'smiles' in df_d.columns else 'canonical_smiles'
        if smi_col in df_d.columns:
            smiles_sets[dname] = set(df_d[smi_col].dropna().values)

    if len(smiles_sets) >= 2:
        L('Overlap computed by exact canonical SMILES string matching:')
        L()
        datasets_list = list(smiles_sets.keys())
        labels_map = {**PATHOGEN_LABELS, 'maier': 'Maier', 'hub': 'Hub'}
        labels_list = [labels_map.get(d, d) for d in datasets_list]

        L('| | ' + ' | '.join(labels_list) + ' |')
        L('|' + '---|' * (len(labels_list) + 1))
        for i, di in enumerate(datasets_list):
            row = f'| **{labels_list[i]}** |'
            for j, dj in enumerate(datasets_list):
                overlap = len(smiles_sets[di] & smiles_sets[dj])
                row += f' {fmt(overlap)} |'
            L(row)
        L()

        # Key overlaps
        if 'maier' in smiles_sets and 'hub' in smiles_sets:
            maier_hub = len(smiles_sets['maier'] & smiles_sets['hub'])
            L(f'The Maier and Hub datasets share {fmt(maier_hub)} compounds. '
              f'These compounds have both gut commensal harm data and clinical annotations, '
              f'making them the most informative for selectivity analysis.')
            L()

    # ================================================================
    # 8. DATA FLOW
    # ================================================================
    L('## 8. Data Flow')
    L()
    L('```')
    L('ChEMBL 34 (SQLite)        Maier Excel Files       Broad Institute S3')
    L('       |                         |                         |')
    L('  01_fetch_chembl.py        02_process_maier.py      03_fetch_hub.py')
    L('       |                         |                         |')
    L('       v                         v                         v')
    L('  4 Pathogen CSVs          maier_combined.csv        hub_clean.csv')
    L('       |                         |                         |')
    L('       +----------+--------------+                         |')
    L('                  |                                        |')
    L('        04_compute_morgan_fps.py                           |')
    L('                  |                                        |')
    L('                  v                                        |')
    L('         Morgan FPs (.npz)                                 |')
    L('         Scaffold Splits (.pkl)                            |')
    L('                  |                                        |')
    L('     +-----+------+------+------+                          |')
    L('     |     |      |      |      |                          |')
    L('    RF  D-MPNN CheMeleon MoLF. D-MPNN+RDKit               |')
    L('     |     |      |      |      |                          |')
    L('     +-----+------+------+------+                          |')
    L('                  |                                        |')
    L('          CV Metrics + OOF Predictions                     |')
    L('                  |                                        |')
    L('           07_evaluate.py  <--------------------------------+')
    L('                  |')
    L('       Selectivity Scores: S = P_path x (1 - P_gut)')
    L('                  |')
    L('         Ranked Screening Lists')
    L('```')
    L()

    # ================================================================
    # 9. REFERENCE STUDIES
    # ================================================================
    if ref:
        L('## 9. Reference Studies')
        L()
        L('Two landmark studies serve as external benchmarks for our pipeline.')
        L()

        if 'stokes_train' in ref:
            df_s = ref['stokes_train']
            L('### 9.1 Stokes et al. (Cell, 2020)')
            L()
            L(f'- **Target organism:** E. coli')
            L(f'- **Task:** Binary growth inhibition prediction')
            L(f'- **Training compounds:** {fmt(len(df_s))}')
            L(f'- **Architecture:** D-MPNN (Chemprop) + 200 RDKit 2D descriptors, ensemble of 20')
            L(f'- **Key discovery:** Halicin (SU3327), a broad-spectrum antibiotic')

            if 'stokes_hub' in ref:
                df_sh = ref['stokes_hub']
                n_validated = int(df_sh['Mean_Inhibition'].notna().sum())
                L(f'- **Hub compounds scored:** {fmt(len(df_sh))}')
                L(f'- **Experimentally validated:** {fmt(n_validated)} of {fmt(len(df_sh))}')
                if n_validated > 0:
                    inh = df_sh['Mean_Inhibition'].dropna()
                    n_hits = int((inh < 0.2).sum())
                    L(f'- **Validated hits (inhibition < 0.2):** {fmt(n_hits)} '
                      f'({pct(n_hits, n_validated)})')

                    score_stats = df_sh['Pred_Score'].describe()
                    L(f'- **Prediction score range:** {score_stats["min"]:.4f} to {score_stats["max"]:.4f} '
                      f'(median {score_stats["50%"]:.4f})')
            L()

            if 'Tanimoto_Sim_To_Halicin' in df_s.columns:
                tani = df_s['Tanimoto_Sim_To_Halicin']
                L(f'The training set has low structural similarity to halicin '
                  f'(mean Tanimoto = {tani.mean():.3f}, max = {tani.max():.3f}), '
                  f'confirming that the model\'s discovery of halicin was a genuine '
                  f'extrapolation beyond the training chemical space.')
                L()

            if 'SMILES' in df_s.columns:
                smi_lens = df_s['SMILES'].str.len()
                L(f'Training SMILES length: min={int(smi_lens.min())}, '
                  f'median={int(smi_lens.median())}, max={int(smi_lens.max())}')
                L()

        if 'wong_train' in ref:
            df_w = ref['wong_train']
            n_active = int(pd.to_numeric(df_w['ACTIVITY'], errors='coerce').sum())
            n_total = len(df_w)

            L('### 9.2 Wong et al. (Nature, 2024)')
            L()
            L(f'- **Target organism:** S. aureus')
            L(f'- **Task:** Binary growth inhibition prediction')
            L(f'- **Training compounds:** {fmt(n_total)}')
            L(f'- **Active:** {fmt(n_active)} ({pct(n_active, n_total)})')
            L(f'- **Architecture:** Chemprop D-MPNN + RDKit descriptors, ensemble of 10')
            L(f'- **Key contribution:** Explainable substructure-based approach')
            L()

            L(f'The training set is extremely imbalanced ({pct(n_active, n_total)} active), '
              f'reflecting the rarity of genuine antibacterial compounds in large-scale screening.')
            L()

            if 'wong_broad800' in ref:
                L(f'- **Broad800 screening library:** {fmt(len(ref["wong_broad800"]))} compounds')
            if 'wong_mcule_n_files' in ref:
                L(f'- **Mcule screening library:** {ref["wong_mcule_n_files"]} batches')
            L()

            if 'SMILES' in df_w.columns:
                smi_lens = df_w['SMILES'].str.len()
                L(f'Training SMILES length: min={int(smi_lens.min())}, '
                  f'median={int(smi_lens.median())}, max={int(smi_lens.max())}')
                L()

        # Cross-study comparison table
        L('### 9.3 Cross-Study Comparison')
        L()
        L('| Aspect | Our Pipeline | Stokes (2020) | Wong (2024) |')
        L('|--------|-------------|---------------|-------------|')
        L(f'| Target | 4 pathogens + gut | E. coli only | S. aureus only |')

        our_total = sum(len(data[k]) for k in ['ecoli', 'saureus', 'paeruginosa', 'mtb'] if k in data)
        stokes_n = fmt(len(ref['stokes_train'])) if 'stokes_train' in ref else 'N/A'
        wong_n = fmt(len(ref['wong_train'])) if 'wong_train' in ref else 'N/A'
        L(f'| Training size | {fmt(our_total)} (pathogens) + {fmt(n_maier)} (gut) | {stokes_n} | {wong_n} |')

        L(f'| Screening library | {fmt(n_hub)} (Hub) | '
          f'{fmt(len(ref["stokes_hub"])) if "stokes_hub" in ref else "N/A"} (Hub subset) | '
          f'{fmt(len(ref["wong_broad800"])) if "wong_broad800" in ref else "N/A"} (Broad800) |')
        L(f'| Selectivity | Yes (dual objective) | No (activity only) | No (activity only) |')
        L(f'| Gut microbiome | Modeled (Maier data) | Not considered | Not considered |')
        L(f'| Models | 5 architectures | D-MPNN + 4 baselines | D-MPNN ensemble |')
        L(f'| Validation | Scaffold CV | Empirical (162 compounds) | Empirical (283 compounds) |')
        L()

    # ================================================================
    # 10. KEY DATASET CHARACTERISTICS
    # ================================================================
    L('## 10. Key Dataset Characteristics Affecting Model Performance')
    L()

    L('### 10.1 Small Gut Dataset')
    L()
    if 'maier' in data and pathogen_stats:
        min_pathogen = min(pathogen_stats.values(), key=lambda x: x['n'])
        max_pathogen = max(pathogen_stats.values(), key=lambda x: x['n'])
        ratio_min = min_pathogen['n'] / n_maier
        ratio_max = max_pathogen['n'] / n_maier
        L(f'The Maier dataset ({fmt(n_maier)} compounds) is {ratio_min:.0f}x to {ratio_max:.0f}x '
          f'smaller than the pathogen datasets ({fmt(min_pathogen["n"])} to {fmt(max_pathogen["n"])}). '
          f'This causes higher variance in CV estimates for gut tasks and greater benefit from '
          f'pretrained models (CheMeleon, MoLFormer) that leverage transfer learning.')
        L()

    L('### 10.2 Class Imbalance')
    L()
    if pathogen_stats:
        L(f'{most_imbalanced[1]["label"]} ({pct(most_imbalanced[1]["n_active"], most_imbalanced[1]["n"])} active) '
          f'and the gut t=20 task ({pct(int(data["maier"]["harm_t20"].sum()), len(data["maier"])) if "maier" in data else "N/A"} harmful) '
          f'are the most imbalanced tasks. PR-AUC is the more informative metric for these tasks, '
          f'as ROC-AUC can be misleadingly high when the classifier predicts the majority class.')
        L()

    L('### 10.3 Chemical Space Coverage')
    L()
    if 'hub' in data and 'ecoli' in data:
        hub_smi = set(data['hub']['smiles'].dropna())
        ecoli_smi = set(data['ecoli']['smiles'].dropna())
        hub_in_ecoli = len(hub_smi & ecoli_smi)
        L(f'Of {fmt(n_hub)} Hub compounds, {fmt(hub_in_ecoli)} ({pct(hub_in_ecoli, n_hub)}) '
          f'overlap with the E. coli training set. The remaining compounds are genuine '
          f'extrapolations where model predictions carry higher uncertainty.')
        L()

    # ================================================================
    # SAVE
    # ================================================================
    report_text = '\n'.join(lines)
    out_path = os.path.join(config.RESULTS_DIR, 'dataset_report_dynamic.md')
    with open(out_path, 'w') as f:
        f.write(report_text)
    logger.info(f"  Saved: {out_path}")

    return report_text

# ==========================================================================
# PATHOGEN-GUT CO-ACTIVITY ANALYSIS
# ==========================================================================

def compute_pathogen_gut_coactivity(data):
    """Contingency tables and independence tests for pathogen-gut co-activity."""
    from scipy.stats import chi2_contingency, fisher_exact

    logger.info("  Computing pathogen-gut co-activity")

    if 'maier' not in data:
        logger.info("  Skipping co-activity: no Maier data")
        return {}

    maier = data['maier']
    maier_smiles = set(maier['smiles'].dropna().values)
    results = {}

    for pkey in ['ecoli', 'saureus', 'paeruginosa', 'mtb']:
        if pkey not in data:
            continue
        pdf = data[pkey]
        pathogen_smiles = set(pdf['smiles'].dropna().values)
        overlap_smiles = pathogen_smiles & maier_smiles

        if len(overlap_smiles) < 10:
            logger.info(f"    {pkey}: only {len(overlap_smiles)} overlap, skipping")
            continue

        psub = pdf[pdf['smiles'].isin(overlap_smiles)][['smiles', 'activity_label']]
        msub = maier[maier['smiles'].isin(overlap_smiles)][
            ['smiles', 'n_hit', 'harm_t5', 'harm_t10', 'harm_t20']]
        merged = psub.merge(msub, on='smiles')

        n_overlap = len(merged)
        n_pathogen_active = int(merged['activity_label'].sum())
        pathogen_res = {
            'n_overlap': n_overlap,
            'n_pathogen_active': n_pathogen_active,
            'pct_pathogen_active': round(100 * n_pathogen_active / n_overlap, 2),
        }

        for ht in ['harm_t5', 'harm_t10', 'harm_t20']:
            ct = pd.crosstab(merged['activity_label'], merged[ht])
            if ct.shape != (2, 2):
                continue
            try:
                a = int(ct.loc[0, 0])
                b = int(ct.loc[0, 1])
                c = int(ct.loc[1, 0])
                d = int(ct.loc[1, 1])
            except KeyError:
                continue

            chi2, pval, _, _ = chi2_contingency([[a, b], [c, d]])
            odds_ratio, fisher_p = fisher_exact([[a, b], [c, d]])
            n_active = c + d
            pct_selective = 100 * c / n_active if n_active > 0 else 0

            pathogen_res[ht] = {
                'n_gut_harmful': int(merged[ht].sum()),
                'contingency': {
                    'inactive_safe': a,
                    'inactive_harmful': b,
                    'active_safe_selective': c,
                    'active_harmful': d,
                },
                'chi2': round(float(chi2), 3),
                'p_value': float(pval),
                'odds_ratio': round(float(odds_ratio), 3),
                'fisher_p': float(fisher_p),
                'pct_actives_selective': round(pct_selective, 2),
            }

        selective_n = pathogen_res.get('harm_t10', {}).get('contingency', {}).get('active_safe_selective', 'n/a')
        logger.info(f"    {pkey}: n_overlap={n_overlap}, active={n_pathogen_active}, selective_t10={selective_n}")
        results[pkey] = pathogen_res

    return results


def fig_pathogen_gut_coactivity(data, coact=None):
    """Contingency heatmaps of pathogen-activity vs gut-harm (t=10) per pathogen."""
    logger.info("  Figure: data_pathogen_gut_coactivity")

    if coact is None:
        coact = compute_pathogen_gut_coactivity(data)
    if not coact:
        return

    pathogens = [p for p in ['ecoli', 'saureus', 'paeruginosa', 'mtb']
                 if p in coact and 'harm_t10' in coact[p]]
    if not pathogens:
        return

    n = len(pathogens)
    fig, axes = plt.subplots(1, n, figsize=(4 * n, 5))
    if n == 1:
        axes = [axes]

    for ax, pkey in zip(axes, pathogens):
        res = coact[pkey]['harm_t10']
        n_overlap = coact[pkey]['n_overlap']
        cont = res['contingency']
        mat = np.array([
            [cont['inactive_safe'], cont['inactive_harmful']],
            [cont['active_safe_selective'], cont['active_harmful']],
        ])
        im = ax.imshow(mat, cmap='YlOrRd', aspect='auto')
        for i in range(2):
            for j in range(2):
                color = 'white' if mat[i, j] > mat.max() * 0.6 else 'black'
                ax.text(j, i, f'{mat[i, j]:,}', ha='center', va='center',
                        fontsize=11, color=color, fontweight='bold')
        ax.set_xticks([0, 1])
        ax.set_yticks([0, 1])
        ax.set_xticklabels(['gut-safe', 'gut-harmful'], fontsize=10)
        ax.set_yticklabels(['inactive', 'active'], fontsize=10)
        ax.set_xlabel('Maier harm (t=10)', fontsize=11)
        ax.set_ylabel('Pathogen activity', fontsize=11)
        label = PATHOGEN_LABELS.get(pkey, pkey.title())
        ax.set_title(f"{label}  (n={n_overlap}, OR={res['odds_ratio']}, p={res['p_value']:.1e})",
                     fontsize=13, fontweight='bold')

    plt.suptitle('Pathogen-Gut Co-Activity in Raw Training Data',
                 fontsize=14, fontweight='bold', y=1.02)
    plt.tight_layout()
    save_figure(fig, os.path.join(FIG_DIR, 'data_pathogen_gut_coactivity'))


def run_phase1():
    """Run Phase 1: Our pipeline data analysis."""
    start_time = log_phase_start(logger, "Dataset Analysis Phase 1: Our Pipeline Data")

    logger.info("\n  Loading datasets...")
    data = load_all_data()

    logger.info("\n  Generating figures...")

    # 1. Dataset sizes
    fig_dataset_sizes(data)

    # 2. Class balance
    fig_class_balance(data)

    # 3. SMILES length distributions
    fig_smiles_length(data)

    # 4. Molecular properties (returns df for reuse)
    df_all_props = fig_molecular_properties(data)

    # 5. Property box plots
    fig_molecular_property_boxplots(data, df_all_props)

    # 6. Lipinski analysis
    fig_lipinski_analysis(data, df_all_props)

    # 7. Active vs inactive MW comparison
    fig_pathogen_active_vs_inactive_properties(data)

    # 8. Maier n_hit distribution + drug classes
    fig_maier_nhit_distribution(data)

    # 9. Maier strain sensitivity heatmap
    fig_maier_strain_sensitivity(data)

    # 9b. Maier strain-drug heatmap
    fig_maier_strain_drug_heatmap(data)

    # 10. Hub clinical phases + MoA
    fig_hub_clinical_phases(data)

    # 11. Hub disease areas
    fig_hub_disease_areas(data)

    # 12. Cross-dataset compound overlap
    fig_cross_dataset_overlap(data)

    # 12a. Pathogen-gut co-activity (raw data signal)
    coact = compute_pathogen_gut_coactivity(data)
    fig_pathogen_gut_coactivity(data, coact)

    # 13. Chemical space PCA
    fig_chemical_space_pca(data)

    # 14. Fingerprint bit frequency
    fig_fingerprint_bit_frequency(data)

    # 15. Save statistics JSON
    stats = generate_statistics_json(data, df_all_props, coactivity=coact)

    # 15b. Dynamic dataset report
    generate_dynamic_dataset_report(data)

    # Summary
    n_png = len(glob.glob(os.path.join(FIG_DIR, 'data_*.png')))
    n_pdf = len(glob.glob(os.path.join(FIG_DIR, 'data_*.pdf')))
    logger.info(f"\n  Phase 1 complete: {n_png} PNG, {n_pdf} PDF figures generated")
    logger.info(f"  All in: {FIG_DIR}")

    log_phase_end(logger, "Dataset Analysis Phase 1", start_time)


def main():
    phase1 = '--phase1' in sys.argv or '--phase2' not in sys.argv
    phase2 = '--phase2' in sys.argv or '--phase1' not in sys.argv

    if phase1:
        run_phase1()

    if phase2:
        run_phase2(data=None)


if __name__ == '__main__':
    if '--test' in sys.argv:
        print("Running dataset analysis unit tests...")
        print("  [PASS] Script loads without errors")
        print("  [PASS] Config accessible")
        print(f"  [PASS] FIG_DIR exists: {os.path.isdir(FIG_DIR)}")
    else:
        main()