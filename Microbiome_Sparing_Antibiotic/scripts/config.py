"""
config.py -- Project-wide configuration for the antibiotic selectivity pipeline.

All paths, thresholds, model hyperparameters, and constants are defined here.
Changing a parameter in this file propagates to all scripts automatically.

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import os

# ===========================================================================
# PATHS -- Auto-detect project directory
# ===========================================================================
# Priority:
#   1. ANTIBIOTIC_PROJECT_DIR environment variable (explicit override)
#   2. Parent of the scripts/ directory (works when running from project root)
#   3. Current working directory (if it has scripts/ or data/ subdirectory)
#   4. ~/antibiotic-selectivity (Ada default)

def _find_project_dir():
    """Auto-detect the project root directory."""
    # 1. Environment variable
    env_dir = os.environ.get('ANTIBIOTIC_PROJECT_DIR')
    if env_dir and os.path.isdir(env_dir):
        return env_dir

    # 2. Parent of this file's directory (config.py lives in scripts/)
    this_dir = os.path.dirname(os.path.abspath(__file__))
    parent = os.path.dirname(this_dir)
    if os.path.basename(this_dir) == 'scripts':
        return parent

    # 3. Current working directory
    cwd = os.getcwd()
    if os.path.isdir(os.path.join(cwd, 'scripts')):
        return cwd

    # 4. Fallback
    return os.path.expanduser("~/antibiotic-selectivity")

PROJECT_DIR = _find_project_dir()

# ============================================================================
# DIRECTORY LAYOUT
# ============================================================================
#
# NEVER DELETED (even with --clean):
#   resources/maier/        Bundled Maier Excel files (shipped with package)
#   data/chembl/            Downloaded from ChEMBL API (hours to fetch)
#   data/maier/             Processed Maier data + Excel copies
#   data/repurposing_hub/   Downloaded from Broad Institute S3
#   logs/                   All log files (append-only)
#
# DELETED by --clean (fast to regenerate):
#   outputs/features/       Morgan fingerprints (.npz)
#   outputs/splits/         Scaffold fold assignments (.pkl)
#   outputs/models/rf/      Trained RF .pkl files
#   outputs/models/dmpnn/   Trained D-MPNN checkpoints
#   outputs/results/        Evaluation CSVs, ranked lists, figures
#   outputs/checkpoints/    Phase completion markers
#   outputs/dmpnn_input/    D-MPNN formatted CSVs
#   synthetic/              Synthetic test data (separate from real)
#
# ============================================================================

# --- Data mode: real (default) or synthetic ---
# Set ANTIBIOTIC_DATA_MODE=synthetic to use synthetic/data/ instead of data/
_DATA_MODE = os.environ.get('ANTIBIOTIC_DATA_MODE', 'real')

if _DATA_MODE == 'synthetic':
    DATA_DIR = os.path.join(PROJECT_DIR, "synthetic", "data")
else:
    DATA_DIR = os.path.join(PROJECT_DIR, "data")

CHEMBL_DIR = os.path.join(DATA_DIR, "chembl")
MAIER_DIR = os.path.join(DATA_DIR, "maier")
HUB_DIR = os.path.join(DATA_DIR, "repurposing_hub")

# --- Sacred: bundled resources (NEVER deleted) ---
RESOURCES_DIR = os.path.join(PROJECT_DIR, "resources")

# --- Outputs: timestamped runs + shared features ---
# Layout:
#   outputs/shared/          Features, splits, dmpnn_input (shared, regenerated from data)
#   outputs/runs/RUN_ID/     Models, results, checkpoints (one per pipeline run)
#   outputs/latest           Symlink to most recent successful run
#
# Set ANTIBIOTIC_RUN_ID to resume a specific run, or leave unset for a new run.
# The run_mac.sh / run_all.sh scripts handle this automatically.

_base_outputs = os.path.join(PROJECT_DIR, "synthetic", "outputs") if _DATA_MODE == 'synthetic' \
                else os.path.join(PROJECT_DIR, "outputs")

# Shared outputs (features, splits) are deterministic from data
SHARED_DIR = os.path.join(_base_outputs, "shared")
FEATURES_DIR = os.path.join(SHARED_DIR, "features")
SPLITS_DIR = os.path.join(SHARED_DIR, "splits")
DMPNN_INPUT_DIR = os.path.join(SHARED_DIR, "dmpnn_input")

# Run-specific outputs (models, results) are timestamped
_run_id = os.environ.get('ANTIBIOTIC_RUN_ID', '')
if not _run_id:
    # Default: use "current" as a working directory (shell scripts set the real ID)
    _run_id = 'current'
RUN_ID = _run_id
RUN_DIR = os.path.join(_base_outputs, "runs", RUN_ID)
OUTPUTS_DIR = RUN_DIR  # Backward compat: scripts that use OUTPUTS_DIR get the run dir

MODELS_DIR = os.path.join(RUN_DIR, "models")
RF_DIR = os.path.join(MODELS_DIR, "rf")
DMPNN_DIR = os.path.join(MODELS_DIR, "dmpnn")
CHEMELEON_DIR = os.path.join(MODELS_DIR, "chemeleon")
MOLFORMER_DIR = os.path.join(MODELS_DIR, "molformer")
RESULTS_DIR = os.path.join(RUN_DIR, "results")
SCREENING_DIR = os.path.join(RESULTS_DIR, "screening")
FIGURES_DIR = os.path.join(RESULTS_DIR, "figures")
REPORTS_DIR = os.path.join(RESULTS_DIR, "reports")
CHECKPOINTS_DIR = os.path.join(RUN_DIR, "checkpoints")

# --- Logs (never deleted, append-only) ---
LOGS_DIR = os.path.join(PROJECT_DIR, "logs")

# ===========================================================================
# PATHOGEN CONFIGURATION
# ===========================================================================
# ChEMBL organism-level targets for each pathogen
# target_type = 'ORGANISM' in ChEMBL
PATHOGENS = {
    'ecoli': {
        'name': 'Escherichia coli',
        'chembl_organism': 'Escherichia coli',
        'expected_count_range': (7000, 15000),
        'csv_filename': 'ecoli_activity.csv',
    },
    'saureus': {
        'name': 'Staphylococcus aureus',
        'chembl_organism': 'Staphylococcus aureus',
        'expected_count_range': (8000, 18000),
        'csv_filename': 'saureus_activity.csv',
    },
    'paeruginosa': {
        'name': 'Pseudomonas aeruginosa',
        'chembl_organism': 'Pseudomonas aeruginosa',
        'expected_count_range': (3000, 8000),
        'csv_filename': 'paeruginosa_activity.csv',
    },
    'mtb': {
        'name': 'Mycobacterium tuberculosis',
        'chembl_organism': 'Mycobacterium tuberculosis',
        'expected_count_range': (12000, 25000),
        'csv_filename': 'mtb_activity.csv',
    },
}

# ===========================================================================
# ACTIVITY THRESHOLDS
# ===========================================================================
# MIC threshold for pathogen activity (in nM)
# MIC <= 10 uM = 10000 nM --> active (label = 1)
MIC_THRESHOLD_NM = 10000  # 10 uM in nM

# IC50 fallback threshold (if MIC yields < 2000 compounds)
IC50_FALLBACK_THRESHOLD_NM = 2000  # 2 uM in nM
IC50_FALLBACK_MIN_COMPOUNDS = 2000

# Commensal harm thresholds (number of strains inhibited out of 40)
HARM_THRESHOLDS = [5, 10, 20]

# Total number of strains in the Maier 2018 screen
N_STRAINS = 40

# ===========================================================================
# ChEMBL QUERY PARAMETERS
# ===========================================================================
CHEMBL_STANDARD_TYPE = 'MIC'
CHEMBL_VALID_UNITS = ['nM', 'ug.mL-1']
CHEMBL_VALID_RELATIONS = ['=', '<=', '<']

# ===========================================================================
# MAIER DATA FILES
# ===========================================================================
# Filenames relative to the Maier data directory on Ada
MAIER_FILES = {
    # 2018 files
    'moesm5_2018': '41586_2018_BFnature25979_MOESM5_ESM.xlsx',
    'moesm3_2018': '41586_2018_BFnature25979_MOESM3_ESM.xlsx',
    'moesm4_2018': '41586_2018_BFnature25979_MOESM4_ESM.xlsx',
    # 2021 files
    'moesm11_2021': '41586_2021_3986_MOESM11_ESM.xlsx',
    'moesm3_2021': '41586_2021_3986_MOESM3_ESM.xlsx',
    'moesm12_2021': '41586_2021_3986_MOESM12_ESM.xlsx',
    'moesm13_2021': '41586_2021_3986_MOESM13_ESM.xlsx',
    'moesm14_2021': '41586_2021_3986_MOESM14_ESM.xlsx',
}

# Sheet names for key files
MAIER_SHEETS = {
    'training_labels': ('moesm5_2018', 'S3a. Adjusted p-values'),
    'id_mapping': ('moesm3_2018', 'S1a. Prestwick_Libery'),
    'ab_binary_screen': ('moesm11_2021', 'EDFig1'),
    'ab_annotation': ('moesm3_2021', 'S2. AB annotation'),
    'ab_quant_mics': ('moesm3_2021', 'S4. MICs'),
    'validation_mics': ('moesm12_2021', 'EDFig2'),
    'cross_validation': ('moesm13_2021', 'Panel_b'),
}

# ===========================================================================
# DRUG REPURPOSING HUB
# ===========================================================================
# S3 direct link (verified working from Ada compute nodes, March 2026)
HUB_DOWNLOAD_URL = (
    "https://s3.amazonaws.com/data.clue.io/repurposing/downloads/"
    "repurposing_drugs_20200324.txt"
)
HUB_RAW_FILENAME = "repurposing_drugs_raw.txt"
HUB_CLEAN_FILENAME = "repurposing_hub_clean.csv"

# ===========================================================================
# FEATURE ENGINEERING
# ===========================================================================
MORGAN_RADIUS = 2        # ECFP4
MORGAN_NBITS = 2048      # Standard bit vector length

# ===========================================================================
# MODEL HYPERPARAMETERS
# ===========================================================================
# Random Forest
RF_PARAMS = {
    'n_estimators': 500,
    'class_weight': 'balanced',
    'n_jobs': -1,            # Use all SLURM-allocated CPUs
    'random_state': 42,
    'max_features': 'sqrt',
    'min_samples_leaf': 2,
}

# D-MPNN (Chemprop v2)
DMPNN_PARAMS = {
    'hidden_dim': 300,
    'depth': 3,              # Message passing steps
    'dropout': 0.1,
    'epochs': 50,
    'batch_size': 50,
    'lr': 1e-3,
    'ffn_num_layers': 2,
    'ffn_hidden_dim': 300,
}

# Cross-validation
N_FOLDS = 5
RANDOM_SEED = 42

# ===========================================================================
# EVALUATION
# ===========================================================================
# Validation set drugs for biological sanity checks
NARROW_SPECTRUM_DRUGS = [
    'lolamicin',
    'daptomycin',
    'fidaxomicin',
    'nitrofurantoin',
    'methenamine',
]

BROAD_SPECTRUM_DRUGS = [
    'ciprofloxacin',
    'amoxicillin',
    'clindamycin',
    'rifabutin',
    'doxycycline',
    'chloramphenicol',
]

# Top-k for enrichment analysis
TOP_K = 50

# ===========================================================================
# ADA / SLURM
# ===========================================================================
SLURM_PARTITION = "u22"
SLURM_ACCOUNT = "research"
SLURM_QOS = "low"
SLURM_MAX_CPUS = 10
SLURM_MAX_GPUS = 1

# ===========================================================================
# API ENDPOINTS (verified on Ada compute nodes, March 2026)
# ===========================================================================
CHEMBL_API_BASE = "https://www.ebi.ac.uk/chembl/api/data/"
PUBCHEM_REST_BASE = "https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/"

# ===========================================================================
# VISUALIZATION
# ===========================================================================
# Publication-quality figure settings
FIGURE_DPI = 300
FIGURE_FORMAT = 'pdf'   # For LaTeX inclusion
FIGURE_FONT_SIZE = 12
FIGURE_FONT_FAMILY = 'serif'

# Color scheme (colorblind-friendly)
COLORS = {
    'rf': '#0072B2',         # Blue
    'dmpnn': '#D55E00',      # Red-orange
    'highlight': '#009E73',  # Green
    'neutral': '#999999',    # Gray
    'narrow': '#009E73',     # Green (narrow-spectrum)
    'broad': '#CC79A7',      # Pink (broad-spectrum)
}
