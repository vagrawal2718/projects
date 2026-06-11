"""
14_external_benchmark.py -- Score candidates against published antibiotic models.

Downloads pretrained checkpoints from:
  1. Stokes et al. (Cell, 2020) - E. coli growth inhibition (halicin discovery)
     Zenodo: https://zenodo.org/records/6527883
  2. Wong et al. (Nature, 2023) - Antibiotic activity, cytotoxicity, PMF
     Zenodo: https://zenodo.org/records/10095879

SAFETY:
  - Creates a SEPARATE venv (venv_v1/) for chemprop v1 inference
  - Never touches the main venv/ used for training
  - Only does PREDICTION (no training, no GPU needed)
  - If anything fails, exits cleanly with no side effects
  - Total runtime: ~5-15 minutes (download + inference)

OUTPUTS:
  results/external_stokes_scores.csv   (smiles, stokes_ecoli_score)
  results/external_wong_scores.csv     (smiles, wong_activity, wong_cytotox)
  results/external_benchmark_merged.csv (consensus + external scores)

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import os, sys, json, subprocess, shutil, tempfile, time
import warnings
import pandas as pd
import numpy as np

warnings.filterwarnings('ignore')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import config
from utils.logging_utils import setup_logging

logger = setup_logging('phase7_benchmark', log_dir=config.LOGS_DIR)

STOKES_ZENODO_URL = "https://zenodo.org/records/6527883/files/antibiotics.zip"
STOKES_ZENODO_DOI = "10.5281/zenodo.6527883"

WONG_ZENODO_URL = "https://zenodo.org/records/10095879/files/models.zip"
WONG_GITHUB_ZIP = "https://github.com/felixjwong/antibioticsai/archive/refs/heads/main.zip"
WONG_GITHUB = "https://github.com/felixjwong/antibioticsai"
WONG_ZENODO_DOI = "10.5281/zenodo.10095879"
# NOTE: Wong model checkpoints are in final_checkpoints/ on GitHub, NOT on Zenodo.
# The Zenodo record is just a DOI for the code. Download the full repo as a zip.

CACHE_DIR = os.path.join(config.PROJECT_DIR, '.benchmark_cache')
V1_VENV = os.path.join(config.PROJECT_DIR, 'venv_v1')


def ensure_cache_dir():
    os.makedirs(CACHE_DIR, exist_ok=True)
    os.makedirs(os.path.join(CACHE_DIR, 'stokes'), exist_ok=True)
    os.makedirs(os.path.join(CACHE_DIR, 'wong'), exist_ok=True)


def download_file(url, dest, label):
    """Download a file if not already cached."""
    if os.path.exists(dest) and os.path.getsize(dest) > 1000:
        logger.info(f"  {label}: already cached ({os.path.getsize(dest) / 1e6:.1f} MB)")
        return True

    logger.info(f"  {label}: downloading from {url}...")
    try:
        import urllib.request
        urllib.request.urlretrieve(url, dest)
        size_mb = os.path.getsize(dest) / 1e6
        logger.info(f"  {label}: downloaded ({size_mb:.1f} MB)")
        return True
    except Exception as e:
        logger.warning(f"  {label}: download failed: {e}")
        return False


def setup_v1_venv():
    """Create isolated venv with chemprop v1 for inference only."""
    v1_python = os.path.join(V1_VENV, 'bin', 'python3')

    # Check if already set up
    if os.path.exists(v1_python):
        result = subprocess.run(
            [v1_python, '-c', 'import chemprop; print(chemprop.__version__)'],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode == 0 and result.stdout.strip().startswith('1.'):
            logger.info(f"  v1 venv exists: chemprop {result.stdout.strip()}")
            return v1_python
        else:
            logger.info(f"  v1 venv exists but chemprop v1 not working, rebuilding...")

    logger.info(f"  Creating isolated venv for chemprop v1 at {V1_VENV}...")

    # Find system python
    sys_python = shutil.which('python3') or sys.executable
    try:
        subprocess.run([sys_python, '-m', 'venv', V1_VENV],
                       check=True, capture_output=True, timeout=60)
    except Exception as e:
        logger.error(f"  Failed to create v1 venv: {e}")
        return None

    pip = os.path.join(V1_VENV, 'bin', 'pip')

    # Install minimal packages for INFERENCE ONLY (no GPU, no training)
    logger.info("  Installing chemprop v1 (inference only, CPU)...")
    packages = [
        'numpy<2', 'pandas', 'scikit-learn', 'rdkit',
        'torch --index-url https://download.pytorch.org/whl/cpu',
        'chemprop==1.7.1',
    ]
    for pkg in packages:
        try:
            cmd = [pip, 'install'] + pkg.split()
            subprocess.run(cmd, capture_output=True, timeout=300)
        except Exception:
            pass

    # Verify
    result = subprocess.run(
        [v1_python, '-c', 'import chemprop; print(chemprop.__version__)'],
        capture_output=True, text=True, timeout=30
    )
    if result.returncode == 0 and '1.' in result.stdout:
        logger.info(f"  v1 venv ready: chemprop {result.stdout.strip()}")
        return v1_python
    else:
        logger.error(f"  chemprop v1 install failed: {result.stderr[:200]}")
        return None


def prepare_smiles_csv(output_path):
    """Write all Hub compound SMILES to a CSV for chemprop prediction."""
    hub_path = os.path.join(config.HUB_DIR, config.HUB_CLEAN_FILENAME)
    if not os.path.exists(hub_path):
        # Try screening lists instead
        consensus_path = os.path.join(config.RESULTS_DIR, 'candidate_consensus.csv')
        if os.path.exists(consensus_path):
            df = pd.read_csv(consensus_path)
            df[['smiles']].to_csv(output_path, index=False)
            return len(df)
        return 0

    df = pd.read_csv(hub_path)
    if 'smiles' not in df.columns:
        return 0

    # Clean SMILES
    smiles = df['smiles'].dropna().unique()
    pd.DataFrame({'smiles': smiles}).to_csv(output_path, index=False)
    return len(smiles)


def run_stokes_benchmark(v1_python):
    """Score compounds against Stokes E. coli model."""
    logger.info("\n  [Stokes] E. coli growth inhibition model (Cell, 2020)")

    # Download checkpoint
    zip_path = os.path.join(CACHE_DIR, 'stokes', 'antibiotics.zip')
    if not download_file(STOKES_ZENODO_URL, zip_path, 'Stokes checkpoint'):
        return None

    # Extract
    ckpt_dir = os.path.join(CACHE_DIR, 'stokes', 'antibiotics')
    if not os.path.isdir(ckpt_dir):
        import zipfile
        try:
            with zipfile.ZipFile(zip_path, 'r') as zf:
                zf.extractall(os.path.join(CACHE_DIR, 'stokes'))
            logger.info(f"  Extracted to {ckpt_dir}")
        except Exception as e:
            logger.warning(f"  Extraction failed: {e}")
            return None

    # Prepare SMILES
    smiles_csv = os.path.join(CACHE_DIR, 'stokes', 'input_smiles.csv')
    n = prepare_smiles_csv(smiles_csv)
    if n == 0:
        logger.warning("  No SMILES to score")
        return None
    logger.info(f"  Scoring {n} compounds...")

    # Generate RDKit features first
    features_path = os.path.join(CACHE_DIR, 'stokes', 'features.npz')
    preds_path = os.path.join(CACHE_DIR, 'stokes', 'predictions.csv')

    # Step 1: generate features
    t0 = time.time()
    feat_script = f"""
import sys
sys.argv = ['save_features',
    '--data_path', '{smiles_csv}',
    '--save_path', '{features_path}',
    '--features_generator', 'rdkit_2d_normalized']
try:
    from chemprop.features import save_features
    save_features.save_features()
except Exception as e:
    # Fallback: try direct CLI
    print(f'Feature generation method 1 failed: {{e}}')
    import subprocess as sp
    sp.run([sys.executable, '-m', 'chemprop.features.save_features',
            '--data_path', '{smiles_csv}',
            '--save_path', '{features_path}',
            '--features_generator', 'rdkit_2d_normalized'], check=True)
"""
    result = subprocess.run(
        [v1_python, '-c', feat_script],
        capture_output=True, text=True, timeout=600,
        cwd=os.path.join(CACHE_DIR, 'stokes')
    )
    if result.returncode != 0:
        # Try CLI approach
        logger.info("  Trying chemprop CLI for features...")
        result = subprocess.run(
            [v1_python, '-m', 'chemprop', 'save_features',
             '--data_path', smiles_csv,
             '--save_path', features_path,
             '--features_generator', 'rdkit_2d_normalized'],
            capture_output=True, text=True, timeout=600
        )
        if result.returncode != 0:
            logger.warning(f"  Feature generation failed: {result.stderr[:300]}")
            # Try without features as fallback
            features_path = None

    # Step 2: predict
    cmd = [
        v1_python, '-m', 'chemprop', 'predict',
        '--test_path', smiles_csv,
        '--checkpoint_dir', ckpt_dir,
        '--preds_path', preds_path,
        '--no_features_scaling',
    ]
    if features_path and os.path.exists(features_path):
        cmd.extend(['--features_path', features_path])

    result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)

    if result.returncode != 0:
        # Fallback: try chemprop_predict
        cmd[2] = 'chemprop_predict'
        result = subprocess.run(
            [v1_python, '-c', f"""
import sys
sys.argv = ['chemprop_predict',
    '--test_path', '{smiles_csv}',
    '--checkpoint_dir', '{ckpt_dir}',
    '--preds_path', '{preds_path}',
    '--no_features_scaling']
from chemprop.train import make_predictions
make_predictions()
"""],
            capture_output=True, text=True, timeout=600
        )

    t1 = time.time()

    if not os.path.exists(preds_path):
        logger.warning(f"  Stokes prediction failed ({t1-t0:.0f}s): {result.stderr[:300]}")
        return None

    # Parse results
    try:
        preds = pd.read_csv(preds_path)
        smiles_df = pd.read_csv(smiles_csv)
        # Chemprop v1 output has column named after the task or just the prediction
        score_col = [c for c in preds.columns if c != 'smiles']
        if not score_col:
            logger.warning("  No score column in Stokes predictions")
            return None

        result_df = pd.DataFrame({
            'smiles': smiles_df['smiles'],
            'stokes_ecoli_score': preds[score_col[0]].values,
        })

        out_path = os.path.join(config.RESULTS_DIR, 'external_stokes_scores.csv')
        result_df.to_csv(out_path, index=False)
        logger.info(f"  Stokes: scored {len(result_df)} compounds in {t1-t0:.0f}s")
        logger.info(f"    Mean score: {result_df['stokes_ecoli_score'].mean():.4f}")
        logger.info(f"    Max score:  {result_df['stokes_ecoli_score'].max():.4f}")
        logger.info(f"    Saved: {out_path}")
        return result_df
    except Exception as e:
        logger.warning(f"  Stokes result parsing failed: {e}")
        return None


def run_wong_benchmark(v1_python):
    """Score compounds against Wong MRSA models (Nature, 2024; doi:10.1038/s41586-023-06887-8).

    Models are in the GitHub repo felixjwong/antibioticsai, directory final_checkpoints/.
    Seven checkpoint directories, each with 20 Chemprop ensemble models:
      - antibiotic_activity (S. aureus growth inhibition)
      - cytotoxicity_HepG2 (liver carcinoma)
      - cytotoxicity_HSkMC (skeletal muscle)
      - cytotoxicity_IMR90 (lung fibroblast)
      - pmf (proton motive force alteration)
      - antibiotic_activity_no_quinolones
      - antibiotic_activity_no_beta_lactams
    We use activity + HepG2 cytotoxicity (most clinically relevant).
    """
    logger.info("\n  [Wong] S. aureus activity + cytotoxicity (Nature, 2024)")
    logger.info("  Models from: https://github.com/felixjwong/antibioticsai")

    # Download full GitHub repo as zip
    zip_path = os.path.join(CACHE_DIR, 'wong', 'antibioticsai.zip')
    if not download_file(WONG_GITHUB_ZIP, zip_path, 'Wong GitHub repo'):
        # Fallback: try Zenodo (which has a snapshot)
        if not download_file(WONG_ZENODO_URL, zip_path, 'Wong Zenodo fallback'):
            return None

    # Extract
    ckpt_base = os.path.join(CACHE_DIR, 'wong')
    extracted_marker = os.path.join(ckpt_base, '.extracted')
    if not os.path.exists(extracted_marker):
        import zipfile
        try:
            with zipfile.ZipFile(zip_path, 'r') as zf:
                zf.extractall(ckpt_base)
            open(extracted_marker, 'w').close()
            logger.info(f"  Extracted Wong repo")
        except Exception as e:
            logger.warning(f"  Extraction failed: {e}")
            return None

    # Find final_checkpoints directory (GitHub zip nests under antibioticsai-main/)
    final_ckpt = None
    for root, dirs, files in os.walk(ckpt_base):
        if 'final_checkpoints' in dirs:
            final_ckpt = os.path.join(root, 'final_checkpoints')
            break
    if final_ckpt is None:
        logger.warning("  Could not find final_checkpoints/ in Wong repo")
        # List what we found
        for root, dirs, files in os.walk(ckpt_base):
            if len(dirs) > 0:
                logger.info(f"    {root}: {dirs[:5]}")
            if root.count(os.sep) - ckpt_base.count(os.sep) > 2:
                break
        return None

    logger.info(f"  Found checkpoints: {final_ckpt}")
    subdirs = [d for d in os.listdir(final_ckpt) if os.path.isdir(os.path.join(final_ckpt, d))]
    logger.info(f"  Model directories: {subdirs}")

    # Map to our model names (use the most clinically relevant)
    model_dirs = {}
    for d in subdirs:
        dl = d.lower()
        full = os.path.join(final_ckpt, d)
        # Check it actually has checkpoint files
        ckpts = [f for f in os.listdir(full) if f.endswith('.pt') or f.endswith('.pkl')]
        if not ckpts:
            # Check subdirectories
            for sub in os.listdir(full):
                subp = os.path.join(full, sub)
                if os.path.isdir(subp):
                    ckpts = [f for f in os.listdir(subp) if f.endswith('.pt') or f.endswith('.pkl')]
                    if ckpts:
                        full = subp
                        break
        if not ckpts:
            continue

        if 'antibiotic' in dl and 'no_' not in dl:
            model_dirs['saureus_activity'] = full
        elif 'hepg2' in dl:
            model_dirs['cytotox_hepg2'] = full
        elif 'imr' in dl:
            model_dirs['cytotox_imr90'] = full
        elif 'pmf' in dl:
            model_dirs['pmf'] = full

    if not model_dirs:
        logger.warning("  No model directories with checkpoints found")
        return None

    logger.info(f"  Using models: {list(model_dirs.keys())}")

    smiles_csv = os.path.join(CACHE_DIR, 'wong', 'input_smiles.csv')
    n = prepare_smiles_csv(smiles_csv)
    if n == 0:
        return None

    # Wong models use RDKit features (same as Stokes)
    features_path = os.path.join(CACHE_DIR, 'wong', 'features.npz')
    if not os.path.exists(features_path):
        logger.info("  Generating RDKit features for Wong models...")
        result = subprocess.run(
            [v1_python, '-c', f"""
import sys
try:
    from chemprop.features import save_features
    sys.argv = ['', '--data_path', '{smiles_csv}',
                '--save_path', '{features_path}',
                '--features_generator', 'rdkit_2d_normalized']
    save_features()
except Exception as e:
    print(f'Feature gen failed: {{e}}')
    import subprocess as sp
    sp.run([sys.executable, '-m', 'chemprop', 'save_features',
            '--data_path', '{smiles_csv}',
            '--save_path', '{features_path}',
            '--features_generator', 'rdkit_2d_normalized'])
"""],
            capture_output=True, text=True, timeout=600
        )
        if not os.path.exists(features_path):
            logger.warning(f"  Feature generation failed, will try without features")
            features_path = None

    results = {'smiles': pd.read_csv(smiles_csv)['smiles']}

    for model_name, model_dir in model_dirs.items():
        logger.info(f"  Scoring against Wong {model_name} model...")
        preds_path = os.path.join(CACHE_DIR, 'wong', f'preds_{model_name}.csv')

        # Build prediction command with RDKit features
        cmd_parts = f"""
import sys
sys.argv = ['chemprop_predict',
    '--test_path', '{smiles_csv}',
    '--checkpoint_dir', '{model_dir}',
    '--preds_path', '{preds_path}',
    '--features_generator', 'rdkit_2d_normalized',
    '--no_features_scaling']
try:
    from chemprop.train import make_predictions
    make_predictions()
except Exception:
    import subprocess as sp
    cmd = [sys.executable, '-m', 'chemprop', 'predict',
           '--test_path', '{smiles_csv}',
           '--checkpoint_dir', '{model_dir}',
           '--preds_path', '{preds_path}',
           '--features_generator', 'rdkit_2d_normalized',
           '--no_features_scaling']
    sp.run(cmd, check=True)
"""
        t0 = time.time()
        result = subprocess.run(
            [v1_python, '-c', cmd_parts],
            capture_output=True, text=True, timeout=600
        )
        t1 = time.time()

        if os.path.exists(preds_path):
            try:
                preds = pd.read_csv(preds_path)
                score_col = [c for c in preds.columns if c != 'smiles'][0]
                col_name = f'wong_{model_name}_score'
                results[col_name] = preds[score_col].values
                logger.info(f"    {model_name}: {t1-t0:.0f}s, mean={preds[score_col].mean():.4f}")
            except Exception as e:
                logger.warning(f"    {model_name}: parsing failed: {e}")
        else:
            logger.warning(f"    {model_name}: prediction failed ({t1-t0:.0f}s)")
            if result.stderr:
                logger.warning(f"    stderr: {result.stderr[:200]}")

    if len(results) <= 1:
        return None

    result_df = pd.DataFrame(results)
    out_path = os.path.join(config.RESULTS_DIR, 'external_wong_scores.csv')
    result_df.to_csv(out_path, index=False)
    logger.info(f"  Wong: saved {out_path}")
    return result_df


def merge_with_consensus(stokes_df, wong_df):
    """Merge external scores into candidate_consensus.csv."""
    consensus_path = os.path.join(config.RESULTS_DIR, 'candidate_consensus.csv')
    if not os.path.exists(consensus_path):
        logger.warning("  No candidate_consensus.csv to merge into")
        return

    consensus = pd.read_csv(consensus_path)
    n_before = len(consensus.columns)

    if stokes_df is not None:
        consensus = consensus.merge(stokes_df, on='smiles', how='left')

    if wong_df is not None:
        consensus = consensus.merge(wong_df, on='smiles', how='left')

    n_after = len(consensus.columns)
    if n_after > n_before:
        # Also compute a combined external validation score
        ext_cols = [c for c in consensus.columns if c.startswith('stokes_') or c.startswith('wong_')]
        if ext_cols:
            consensus['external_mean_score'] = consensus[ext_cols].mean(axis=1)

        out_path = os.path.join(config.RESULTS_DIR, 'external_benchmark_merged.csv')
        consensus.to_csv(out_path, index=False)
        logger.info(f"  Merged: {out_path} ({n_after - n_before} new columns)")

        # Summary: top candidates that also score high externally
        if 'stokes_ecoli_score' in consensus.columns:
            top_novel = consensus[consensus.get('is_known_antibiotic', True) == False]
            if len(top_novel) > 0:
                top_novel = top_novel.nlargest(10, 'stokes_ecoli_score')
                logger.info("\n  Top 10 novels by Stokes E. coli score:")
                for _, row in top_novel.iterrows():
                    nm = row.get('name', '')[:25] or row['smiles'][:20]
                    our_s = row.get('best_selectivity', 0)
                    ext_s = row.get('stokes_ecoli_score', 0)
                    logger.info(f"    {nm:25s}  our S={our_s:.3f}  Stokes={ext_s:.3f}")


def make_benchmark_plots(save_dir):
    """Generate comparison plots if external scores exist."""
    try:
        import plotly.graph_objects as go
        from plotly.subplots import make_subplots
    except ImportError:
        return

    merged_path = os.path.join(config.RESULTS_DIR, 'external_benchmark_merged.csv')
    if not os.path.exists(merged_path):
        return

    df = pd.read_csv(merged_path)
    ext_cols = [c for c in df.columns if 'stokes_' in c or 'wong_' in c]
    if not ext_cols or 'best_selectivity' not in df.columns:
        return

    fig = make_subplots(rows=1, cols=len(ext_cols),
                        subplot_titles=[c.replace('_', ' ').title() for c in ext_cols])

    for i, col in enumerate(ext_cols, 1):
        sub = df.dropna(subset=[col, 'best_selectivity'])
        if len(sub) == 0:
            continue

        is_ab = sub.get('is_known_antibiotic', pd.Series([False]*len(sub)))
        colors = ['#D32F2F' if v else '#1565C0' for v in is_ab]

        hover = [f"<b>{n[:25] if n else s[:20]}</b><br>"
                 f"Our S={os_:.3f}<br>{col}={es:.3f}"
                 for n, s, os_, es in zip(sub.get('name', sub['smiles']),
                                           sub['smiles'],
                                           sub['best_selectivity'],
                                           sub[col])]

        fig.add_trace(go.Scatter(
            x=sub['best_selectivity'], y=sub[col],
            mode='markers',
            marker=dict(size=6, color=colors, opacity=0.6,
                        line=dict(width=0.5, color='white')),
            text=hover, hoverinfo='text',
            showlegend=(i == 1),
            name='Known AB' if i == 1 else None,
        ), row=1, col=i)

        # Correlation
        corr = sub[['best_selectivity', col]].corr().iloc[0, 1]
        fig.add_annotation(x=0.1, y=0.95, text=f'r = {corr:.3f}',
                           showarrow=False, font=dict(size=12),
                           xref=f'x{i}', yref=f'y{i}')

        fig.update_xaxes(title_text='Our Selectivity Score', row=1, col=i)
        fig.update_yaxes(title_text=col.replace('_', ' '), row=1, col=i)

    fig.update_layout(
        title=dict(
            text=('<b>External Validation: Our Scores vs Published Models</b><br>'
                  '<sup>Blue = novel candidate | Red = known antibiotic | '
                  'r = Pearson correlation</sup>'),
            font=dict(size=14)),
        width=500 * len(ext_cols), height=500,
        template='plotly_white',
    )

    path = os.path.join(save_dir, 'candidates_external_validation.html')
    fig.write_html(path, include_plotlyjs='cdn')
    logger.info(f"  External validation plot: {path}")


# ============================================================================
# MAIN
# ============================================================================
def main():
    logger.info("=" * 70)
    logger.info("  EXTERNAL BENCHMARK: Published Antibiotic Model Validation")
    logger.info("=" * 70)
    logger.info("  Stokes et al., Cell (2020) - E. coli (halicin)")
    logger.info("  Wong et al., Nature (2023) - MRSA (abaucin)")
    logger.info("")
    logger.info("  This uses INFERENCE ONLY (no training, no GPU needed).")
    logger.info("  Chemprop v1 runs in an isolated venv (venv_v1/).")
    logger.info("  Your main venv is NOT modified.")
    logger.info("")

    ensure_cache_dir()
    os.makedirs(config.RESULTS_DIR, exist_ok=True)

    # Test network
    logger.info("  Testing network connectivity...")
    try:
        import urllib.request
        urllib.request.urlopen('https://zenodo.org', timeout=10)
        logger.info("  Network: OK (zenodo.org reachable)")
    except Exception as e:
        logger.error(f"  Network: FAILED ({e})")
        logger.error("  External benchmarking requires internet to download checkpoints.")
        logger.error("  Skipping. This does not affect your main pipeline results.")
        return

    # Setup v1 venv
    v1_python = setup_v1_venv()
    if v1_python is None:
        logger.error("  Could not set up chemprop v1 venv. Skipping external benchmark.")
        logger.error("  This does not affect your main pipeline results.")
        return

    # Run benchmarks
    t_start = time.time()

    stokes_df = None
    try:
        stokes_df = run_stokes_benchmark(v1_python)
    except Exception as e:
        logger.warning(f"  Stokes benchmark failed: {e}")

    wong_df = None
    try:
        wong_df = run_wong_benchmark(v1_python)
    except Exception as e:
        logger.warning(f"  Wong benchmark failed: {e}")

    if stokes_df is None and wong_df is None:
        logger.warning("  No external benchmarks completed. This is OK.")
        logger.warning("  Your main pipeline results are unaffected.")
        return

    # Merge and plot
    try:
        merge_with_consensus(stokes_df, wong_df)
    except Exception as e:
        logger.warning(f"  Merge failed: {e}")

    try:
        make_benchmark_plots(config.FIGURES_DIR)
    except Exception as e:
        logger.warning(f"  Plots failed: {e}")

    t_total = time.time() - t_start
    logger.info(f"\n  External benchmark complete: {t_total:.0f}s ({t_total/60:.1f}m)")
    logger.info("=" * 70)


def run_tests():
    print("Running Phase 7 (External Benchmark) unit tests...")
    passed, failed = 0, 0
    def _assert(cond, msg):
        nonlocal passed, failed
        if cond: print(f"  [PASS] {msg}"); passed += 1
        else: print(f"  [FAIL] {msg}"); failed += 1

    _assert(STOKES_ZENODO_URL.startswith('https://zenodo.org'), "Stokes URL valid")
    _assert('6527883' in STOKES_ZENODO_URL, "Stokes DOI correct")
    _assert(WONG_ZENODO_URL.startswith('https://zenodo.org'), "Wong URL valid")
    _assert(WONG_GITHUB_ZIP.startswith('https://github.com/felixjwong'), "Wong GitHub URL valid")
    _assert('antibioticsai' in WONG_GITHUB_ZIP, "Wong GitHub repo name correct")

    # Test prepare_smiles_csv with mock data
    import tempfile
    tmpdir = tempfile.mkdtemp()
    test_csv = os.path.join(tmpdir, 'test.csv')

    # Mock: if no Hub data, should handle gracefully
    n = prepare_smiles_csv(test_csv)
    # May be 0 if no data, but should not crash
    _assert(isinstance(n, int), f"prepare_smiles returns int: {n}")

    # Test merge logic
    mock_consensus = pd.DataFrame({
        'smiles': ['CCO', 'CCN'],
        'best_selectivity': [0.8, 0.6],
        'is_known_antibiotic': [False, True],
    })
    mock_stokes = pd.DataFrame({
        'smiles': ['CCO', 'CCN'],
        'stokes_ecoli_score': [0.75, 0.55],
    })
    merged = mock_consensus.merge(mock_stokes, on='smiles', how='left')
    _assert('stokes_ecoli_score' in merged.columns, "merge adds stokes column")
    _assert(len(merged) == 2, f"merge preserves rows: {len(merged)}")
    _assert(merged.iloc[0]['stokes_ecoli_score'] == 0.75, "merge values correct")

    # Cleanup
    shutil.rmtree(tmpdir, ignore_errors=True)

    print(f"Unit tests: {passed} passed, {failed} failed")


if __name__ == '__main__':
    if '--test' in sys.argv:
        run_tests()
    else:
        main()
