#!/usr/bin/env python3
"""
08_create_showcase.py -- Generate Showcase Visualizations

Creates publication-quality PNG figures, interactive HTML plots with
Hans Rosling-style animations, and 3D molecular selectivity landscapes.

Run after Phase 4:
  python scripts/08_create_showcase.py

Outputs:
  results/figures/*.png  (high-res static)
  results/figures/*.html (interactive Plotly)
  outputs/showcase.zip   (all packaged)

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import os, sys, json, glob, logging, warnings, time
import numpy as np
import pandas as pd

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
import config
from utils.logging_utils import setup_logging, log_phase_start, log_phase_end

warnings.filterwarnings('ignore')
logger = setup_logging('showcase', log_dir=config.LOGS_DIR)

FIG_DIR = config.FIGURES_DIR
os.makedirs(FIG_DIR, exist_ok=True)

# All pipeline names and their display colors
ALL_PIPELINES = ['rf', 'dmpnn', 'chemeleon_frozen', 'molformer', 'dmpnn_rdkit']
PIPELINE_DISPLAY = {
    'rf': 'RF', 'dmpnn': 'D-MPNN',
    'chemeleon_frozen': 'CheMeleon', 'molformer': 'MoLFormer', 'dmpnn_rdkit': 'D-MPNN+RDKit',
}
PIPELINE_COLORS = {
    'rf': '#2196F3', 'dmpnn': '#FF5722',
    'chemeleon_frozen': '#4CAF50', 'molformer': '#9C27B0', 'dmpnn_rdkit': '#E69F00',
}


def _find_available_pipelines():
    """Discover which pipelines have screening results."""
    available = {}
    for pipe in ALL_PIPELINES:
        files = sorted(glob.glob(os.path.join(
            config.SCREENING_DIR, f'{pipe}_ranked_*_t10.csv')))
        if files:
            available[pipe] = files
            logger.info(f"  {pipe}: {len(files)} screening files")
    return available


def make_static_figures():
    """Generate beautiful, colorful static PNG figures."""
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import seaborn as sns
    from matplotlib import cm
    from matplotlib.colors import LinearSegmentedColormap

    DPI = 300
    plt.rcParams.update({
        'font.family': 'serif', 'font.size': 12, 'figure.dpi': DPI,
        'savefig.dpi': DPI, 'savefig.bbox': 'tight',
        'axes.linewidth': 0.8, 'axes.spines.top': False, 'axes.spines.right': False,
    })

    # Custom colormap: teal -> gold -> crimson
    CUSTOM_CMAP = LinearSegmentedColormap.from_list(
        'selectivity', ['#0D4F4F', '#1A936F', '#88D498', '#F6D55C', '#ED553B'], N=256
    )

    available = _find_available_pipelines()

    # ---- Fig S1: Grand overview of all datasets ----
    logger.info("  Static: dataset_grand_overview.png")
    datasets = {}
    for pkey, pinfo in config.PATHOGENS.items():
        csv = os.path.join(config.CHEMBL_DIR, pinfo['csv_filename'])
        if os.path.exists(csv):
            df = pd.read_csv(csv)
            datasets[pinfo['name']] = {'total': len(df), 'active': int(df['activity_label'].sum()),
                                        'type': 'pathogen'}
    maier_csv = os.path.join(config.MAIER_DIR, 'maier_combined.csv')
    if os.path.exists(maier_csv):
        df_m = pd.read_csv(maier_csv)
        datasets['Maier Commensal'] = {'total': len(df_m), 'active': int(df_m['harm_t10'].sum()),
                                        'type': 'commensal'}
    hub_csv = os.path.join(config.HUB_DIR, config.HUB_CLEAN_FILENAME)
    if os.path.exists(hub_csv):
        df_h = pd.read_csv(hub_csv)
        datasets['Drug Repurposing Hub'] = {'total': len(df_h), 'active': 0, 'type': 'screening'}

    if datasets:
        fig, ax = plt.subplots(figsize=(12, 6))
        names = list(datasets.keys())
        totals = [datasets[n]['total'] for n in names]
        actives = [datasets[n]['active'] for n in names]
        types = [datasets[n]['type'] for n in names]

        palette = {'pathogen': '#2196F3', 'commensal': '#FF9800', 'screening': '#4CAF50'}
        colors = [palette[t] for t in types]

        x = np.arange(len(names))
        bars = ax.bar(x, totals, color=colors, edgecolor='white', linewidth=1.5, width=0.6)

        for i, (total, active) in enumerate(zip(totals, actives)):
            if active > 0:
                ax.bar(i, active, color=colors[i], alpha=0.5, edgecolor='none', width=0.6,
                       hatch='///')
            ax.text(i, total + max(totals)*0.02, f'{total:,}', ha='center', fontsize=10,
                    fontweight='bold')

        ax.set_xticks(x)
        ax.set_xticklabels([n.replace(' ', '\n') for n in names], fontsize=9)
        ax.set_ylabel('Number of Compounds', fontsize=12)
        ax.set_title('Dataset Overview: Microbiome-Sparing Antibiotic Discovery Pipeline',
                      fontsize=14, fontweight='bold', pad=15)
        ax.set_yscale('log'); ax.set_ylim(100, max(totals) * 3)

        from matplotlib.patches import Patch
        legend = [Patch(color='#2196F3', label='Pathogen (ChEMBL)'),
                  Patch(color='#FF9800', label='Commensal (Maier)'),
                  Patch(color='#4CAF50', label='Screening Library')]
        ax.legend(handles=legend, loc='upper right', fontsize=10)

        plt.tight_layout()
        fig.savefig(os.path.join(FIG_DIR, 'showcase_dataset_overview.png'), dpi=DPI)
        plt.close(fig)

    # ---- Fig S2: Selectivity landscape heatmap (all pipelines) ----
    logger.info("  Static: selectivity_heatmap.png")
    # Collect one t=10 ecoli file per pipeline
    heatmap_files = []
    for pipe in ALL_PIPELINES:
        fpath = os.path.join(config.SCREENING_DIR,
                             f'{pipe}_ranked_ecoli_t10.csv')
        if os.path.exists(fpath):
            heatmap_files.append((pipe, fpath))

    if heatmap_files:
        n_plots = len(heatmap_files)
        ncols = min(n_plots, 2)
        nrows = (n_plots + ncols - 1) // ncols
        fig, axes = plt.subplots(nrows, ncols, figsize=(7 * ncols, 6 * nrows))
        if n_plots == 1:
            axes = [axes]
        else:
            axes = axes.flat

        for idx, (pipe, fpath) in enumerate(heatmap_files):
            ax = axes[idx]
            df = pd.read_csv(fpath)
            disp = PIPELINE_DISPLAY.get(pipe, pipe)

            sc = ax.scatter(df['p_gut'], df['p_pathogen'],
                           c=df['selectivity_score'], cmap=CUSTOM_CMAP,
                           s=3, alpha=0.6, edgecolors='none', vmin=0, vmax=1)
            ax.set_xlabel('$\\hat{P}_{gut}$ (commensal harm)', fontsize=10)
            ax.set_ylabel('$\\hat{P}_{pathogen}$ (activity)', fontsize=10)
            ax.set_title(f'{disp}: E. coli (t=10)', fontsize=12,
                         fontweight='bold')
            ax.set_xlim(-0.02, 1.02); ax.set_ylim(-0.02, 1.02)
            plt.colorbar(sc, ax=ax, label='S score', shrink=0.8)

        # Hide unused subplots
        for idx in range(len(heatmap_files), len(list(axes))):
            axes[idx].set_visible(False)

        plt.suptitle('Selectivity Landscape: S = $\\hat{P}_{pathogen}$ x (1 - $\\hat{P}_{gut}$)',
                      fontsize=15, fontweight='bold', y=1.02)
        plt.tight_layout()
        fig.savefig(os.path.join(FIG_DIR, 'showcase_selectivity_heatmap.png'), dpi=DPI)
        plt.close(fig)

    # ---- Fig S3: Validation drug comparison ----
    logger.info("  Static: validation_drugs.png")
    val_csv = os.path.join(config.RESULTS_DIR, 'validation_set.csv')
    if os.path.exists(val_csv):
        df_val = pd.read_csv(val_csv)
        for pipe in df_val['pipeline'].unique():
            df_p = df_val[df_val['pipeline'] == pipe]
            df_sub = df_p.drop_duplicates(subset='drug')
            if len(df_sub) < 3:
                continue

            fig, ax = plt.subplots(figsize=(10, 7))
            narrow = df_sub[df_sub['category'] == 'narrow'].sort_values('selectivity_score', ascending=True)
            broad = df_sub[df_sub['category'] == 'broad'].sort_values('selectivity_score', ascending=True)
            all_drugs = pd.concat([broad, narrow])

            colors = ['#E74C3C' if c == 'broad' else '#27AE60' for c in all_drugs['category']]
            bars = ax.barh(range(len(all_drugs)), all_drugs['selectivity_score'],
                          color=colors, edgecolor='white', linewidth=1)

            for i, (_, row) in enumerate(all_drugs.iterrows()):
                ax.text(row['selectivity_score'] + 0.01, i,
                        f"S={row['selectivity_score']:.4f}", va='center', fontsize=8)

            ax.set_yticks(range(len(all_drugs)))
            ax.set_yticklabels(all_drugs['drug'].str.title(), fontsize=10)
            ax.set_xlabel('Selectivity Score S', fontsize=12)
            disp = PIPELINE_DISPLAY.get(pipe, pipe)
            ax.set_title(f'{disp} Pipeline: Known Drug Selectivity Validation',
                        fontsize=13, fontweight='bold')

            from matplotlib.patches import Patch
            legend = [Patch(color='#27AE60', label='Narrow-spectrum (expected HIGH S)'),
                      Patch(color='#E74C3C', label='Broad-spectrum (expected LOW S)')]
            ax.legend(handles=legend, loc='lower right', fontsize=10)

            plt.tight_layout()
            fig.savefig(os.path.join(FIG_DIR, f'showcase_validation_{pipe}.png'), dpi=DPI)
            plt.close(fig)


def make_interactive_html():
    """Generate interactive HTML plots with Plotly: animations, 3D, etc."""
    try:
        import plotly.express as px
        import plotly.graph_objects as go
        from plotly.subplots import make_subplots
    except ImportError:
        logger.warning("  Plotly not available. Skipping interactive figures.")
        return

    available = _find_available_pipelines()

    # ---- HTML 1: 3D Selectivity Surface (per pipeline) ----
    for pipe in available:
        fpath = os.path.join(config.SCREENING_DIR,
                             f'{pipe}_ranked_ecoli_t10.csv')
        if not os.path.exists(fpath):
            continue

        logger.info(f"  Interactive: 3d_selectivity_{pipe}.html")
        df = pd.read_csv(fpath)
        sample = df.sample(n=min(3000, len(df)), random_state=42)
        disp = PIPELINE_DISPLAY.get(pipe, pipe)

        fig = go.Figure(data=[go.Scatter3d(
            x=sample['p_pathogen'], y=sample['p_gut'],
            z=sample['selectivity_score'],
            mode='markers',
            marker=dict(
                size=3, color=sample['selectivity_score'],
                colorscale='Viridis', opacity=0.7,
                colorbar=dict(title='S score'),
            ),
            text=[f"{r['name']}<br>S={r['selectivity_score']:.4f}<br>"
                  f"P_path={r['p_pathogen']:.3f}, P_gut={r['p_gut']:.3f}"
                  for _, r in sample.iterrows()],
            hoverinfo='text',
        )])
        fig.update_layout(
            title=dict(text=f'3D Selectivity Landscape: E. coli ({disp}, t=10)',
                       font=dict(size=18)),
            scene=dict(
                xaxis_title='P_pathogen',
                yaxis_title='P_gut',
                zaxis_title='Selectivity Score S',
                camera=dict(eye=dict(x=1.5, y=1.5, z=0.8)),
            ),
            width=900, height=700,
        )
        fig.write_html(os.path.join(FIG_DIR,
                                    f'3d_selectivity_{pipe}.html'))

    # ---- HTML 2: Animated bubble chart (first available pipeline) ----
    for pipe in available:
        logger.info(f"  Interactive: animated_threshold_bubbles_{pipe}.html")
        frames_data = []
        for t in config.HARM_THRESHOLDS:
            fpath = os.path.join(config.SCREENING_DIR,
                                 f'{pipe}_ranked_ecoli_t{t}.csv')
            if os.path.exists(fpath):
                df = pd.read_csv(fpath)
                top100 = df.head(100).copy()
                top100['threshold'] = f't={t}'
                top100['size'] = top100['selectivity_score'] * 30 + 5
                frames_data.append(top100)

        if frames_data:
            df_anim = pd.concat(frames_data)
            disp = PIPELINE_DISPLAY.get(pipe, pipe)
            fig = px.scatter(
                df_anim, x='p_gut', y='p_pathogen',
                size='selectivity_score', color='selectivity_score',
                animation_frame='threshold',
                hover_name='name',
                hover_data=['moa', 'clinical_phase', 'selectivity_score'],
                color_continuous_scale='RdYlGn',
                range_x=[-0.05, 1.05], range_y=[-0.05, 1.05],
                range_color=[0, 1],
                title=f'Top-100 Candidates Across Harm Thresholds (E. coli, {disp})',
                labels={'p_gut': 'P_gut (Commensal Harm)',
                        'p_pathogen': 'P_pathogen (E. coli Activity)',
                        'selectivity_score': 'Selectivity S'},
            )
            fig.update_layout(width=900, height=700)
            fig.update_traces(marker=dict(line=dict(width=0.5,
                                                     color='DarkSlateGrey')))
            fig.write_html(os.path.join(
                FIG_DIR, f'animated_threshold_bubbles_{pipe}.html'))
        break  # One animation is enough

    # ---- HTML 3: Interactive ranked list explorer (per pipeline) ----
    for pipe in available:
        fpath = os.path.join(config.SCREENING_DIR,
                             f'{pipe}_ranked_ecoli_t10.csv')
        if not os.path.exists(fpath):
            continue

        logger.info(f"  Interactive: ranked_list_explorer_{pipe}.html")
        df = pd.read_csv(fpath).head(200)
        disp = PIPELINE_DISPLAY.get(pipe, pipe)
        fig = px.scatter(
            df, x='p_gut', y='p_pathogen', color='selectivity_score',
            size='selectivity_score', hover_name='name',
            hover_data=['moa', 'clinical_phase', 'rank',
                        'selectivity_score'],
            color_continuous_scale='Turbo',
            title=f'Top-200 Drug Candidates: E. coli Selectivity ({disp}, t=10)',
            labels={'p_gut': 'P_gut', 'p_pathogen': 'P_pathogen'},
        )
        fig.update_layout(width=1000, height=700)
        fig.write_html(os.path.join(FIG_DIR,
                                    f'ranked_list_explorer_{pipe}.html'))

    # ---- HTML 4: Pipeline comparison (all pipelines) ----
    logger.info("  Interactive: pipeline_comparison.html")
    t3_csv = os.path.join(config.RESULTS_DIR, 'test3_topk_enrichment.csv')
    if os.path.exists(t3_csv):
        df_t3 = pd.read_csv(t3_csv)
        if len(df_t3) > 0 and 'enrichment_ratio' in df_t3.columns:
            color_map = {p: PIPELINE_COLORS.get(p, '#999999')
                         for p in df_t3['pipeline'].unique()}
            fig = px.bar(
                df_t3, x='pathogen', y='enrichment_ratio', color='pipeline',
                barmode='group',
                title='Top-50 Antibiotic Enrichment by Pathogen and Pipeline',
                color_discrete_map=color_map,
                labels={'enrichment_ratio': 'Enrichment Ratio',
                        'pathogen': 'Target Pathogen'},
            )
            fig.add_hline(y=1.0, line_dash='dash', line_color='gray',
                         annotation_text='Random baseline')
            fig.update_layout(width=900, height=500)
            fig.write_html(os.path.join(FIG_DIR, 'pipeline_comparison.html'))

    # ---- HTML 5: 3D rotating PCA of Morgan fingerprints ----
    logger.info("  Interactive: 3d_chemical_space.html")
    from scipy import sparse
    fp_path = os.path.join(config.FEATURES_DIR, 'morgan_repurposing_hub.npz')
    if os.path.exists(fp_path):
        X = sparse.load_npz(fp_path)
        hub_path = os.path.join(config.HUB_DIR, config.HUB_CLEAN_FILENAME)
        if os.path.exists(hub_path):
            df_hub = pd.read_csv(hub_path)
            n_sample = min(2000, X.shape[0], len(df_hub))
            idx = np.random.RandomState(42).choice(X.shape[0], n_sample,
                                                    replace=False)
            X_sub = X[idx].toarray()
            df_sub = df_hub.iloc[idx].copy()

            from sklearn.decomposition import PCA
            pca = PCA(n_components=3, random_state=42)
            coords = pca.fit_transform(X_sub)
            df_sub['PC1'] = coords[:, 0]
            df_sub['PC2'] = coords[:, 1]
            df_sub['PC3'] = coords[:, 2]

            fig = px.scatter_3d(
                df_sub, x='PC1', y='PC2', z='PC3',
                color='clinical_phase', hover_name='name',
                hover_data=['moa', 'disease_area'],
                title=f'Chemical Space of Drug Repurposing Hub (PCA, n={n_sample})',
                opacity=0.6,
                color_discrete_sequence=px.colors.qualitative.Set2,
            )
            fig.update_traces(marker=dict(size=3))
            fig.update_layout(width=1000, height=750)
            fig.write_html(os.path.join(FIG_DIR, '3d_chemical_space.html'))


def package_outputs():
    """Package all outputs into a single ZIP."""
    import zipfile
    logger.info("  Packaging all outputs...")

    output_dir = config.OUTPUTS_DIR
    os.makedirs(output_dir, exist_ok=True)

    zip_path = os.path.join(output_dir, f'showcase_results_{time.strftime("%Y%m%d")}.zip')

    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
        for f in glob.glob(os.path.join(FIG_DIR, '*')):
            zf.write(f, os.path.join('figures', os.path.basename(f)))
        for f in glob.glob(os.path.join(config.RESULTS_DIR, '*.csv')):
            zf.write(f, os.path.join('results', os.path.basename(f)))
        for f in glob.glob(os.path.join(config.REPORTS_DIR, '*.json')):
            zf.write(f, os.path.join('reports', os.path.basename(f)))
        for f in glob.glob(os.path.join(config.SCREENING_DIR, '*.csv')):
            zf.write(f, os.path.join('screening', os.path.basename(f)))

    size_mb = os.path.getsize(zip_path) / (1024 * 1024)
    logger.info(f"  Packaged: {zip_path} ({size_mb:.1f} MB)")
    return zip_path


def main():
    start_time = log_phase_start(logger, "Showcase Visualization Generation")

    logger.info("\n  Generating static PNG figures...")
    try:
        make_static_figures()
    except Exception as e:
        logger.warning(f"  Static figures error: {e}")
        import traceback; traceback.print_exc()

    logger.info("\n  Generating interactive HTML visualizations...")
    try:
        make_interactive_html()
    except Exception as e:
        logger.warning(f"  Interactive figures error: {e}")
        import traceback; traceback.print_exc()

    logger.info("\n  Packaging outputs...")
    try:
        zip_path = package_outputs()
    except Exception as e:
        logger.warning(f"  Packaging error: {e}")

    n_png = len(glob.glob(os.path.join(FIG_DIR, '*.png')))
    n_pdf = len(glob.glob(os.path.join(FIG_DIR, '*.pdf')))
    n_html = len(glob.glob(os.path.join(FIG_DIR, '*.html')))
    logger.info(f"\n  Figures generated: {n_png} PNG, {n_pdf} PDF, {n_html} interactive HTML")
    logger.info(f"  All in: {FIG_DIR}")

    log_phase_end(logger, "Showcase Visualization", start_time)


if __name__ == '__main__':
    main()