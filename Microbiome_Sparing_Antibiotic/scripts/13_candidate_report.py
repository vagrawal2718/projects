"""
13_candidate_report.py -- Publication-quality antibiotic candidate analysis.

Scientific Framework:
  The WHO declared antimicrobial resistance (AMR) a top-10 global health threat.
  Traditional broad-spectrum antibiotics devastate the gut microbiome, driving
  C. difficile infection, metabolic dysfunction, and paradoxically accelerating
  resistance evolution. This pipeline identifies SELECTIVE compounds: those
  predicted to kill specific pathogens while sparing commensal gut flora.

  Selectivity Score S = P_pathogen x (1 - P_gut)
    P_pathogen: probability of inhibiting pathogen (from ChEMBL MIC data)
    P_gut:      probability of harming gut flora (from Maier et al. Nature 2018)

Outputs:
  REPORTS (Markdown):
    report_known_antibiotics.md   - Validation: known antimicrobials rediscovered
    report_novel_candidates.md    - Discovery: repurposing candidates the field missed

  INTERACTIVE HTML:
    candidates_3d_landscape_{pathogen}.html   - 3D selectivity surface
    candidates_scatter_{pathogen}.html        - 2D P(kill) vs P(gut) with ideal zone
    candidates_consensus_heatmap.html         - Cross-model agreement matrix
    candidates_known_vs_novel.html            - Comparison analysis
    candidates_radar_top20.html               - Radar chart per candidate
    candidates_master_dashboard.html          - All-in-one dashboard

  DATA (CSV):
    candidate_consensus.csv          - All consensus candidates
    candidate_known_antibiotics.csv  - Known antimicrobials only
    candidate_novel_discoveries.csv  - Novel repurposing candidates only
    candidate_detailed_top100.csv    - Top 100 with all metadata

Author:  Vishakha Agrawal, Lab for Spatial Informatics, IIIT Hyderabad
Date:    March 2026
"""

import os, sys, json, warnings, math
import numpy as np
import pandas as pd
from collections import defaultdict
from datetime import datetime

warnings.filterwarnings('ignore')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import config
from utils.logging_utils import setup_logging

logger = setup_logging('phase6_report', log_dir=config.LOGS_DIR)

TOP_N = 50  # per-list cutoff for consensus

# ============================================================================
# SCIENTIFIC CONTEXT
# ============================================================================
PATHOGEN_SCIENCE = {
    'ecoli': {
        'full_name': 'Escherichia coli',
        'short': 'E. coli',
        'gram': 'Gram-negative',
        'who_priority': 'Critical',
        'who_year': 2024,
        'diseases': 'urinary tract infections (UTIs), bloodstream infections, neonatal meningitis, intra-abdominal infections',
        'resistance': (
            'Extended-spectrum beta-lactamases (ESBLs) and carbapenemases (NDM, KPC, OXA-48) '
            'have rendered many E. coli strains resistant to virtually all beta-lactam antibiotics. '
            'Fluoroquinolone resistance exceeds 50% in many countries. Colistin resistance '
            '(mediated by mcr genes) threatens the last-resort treatment.'
        ),
        'current_treatment': 'carbapenems (meropenem, imipenem), colistin, ceftazidime-avibactam',
        'microbiome_concern': (
            'E. coli is itself a commensal gut organism. Many E. coli strains are harmless '
            'or even beneficial. Broad-spectrum antibiotics targeting pathogenic E. coli '
            'also eliminate beneficial strains, creating ecological niches for resistant clones '
            'and opportunistic pathogens like C. difficile.'
        ),
    },
    'saureus': {
        'full_name': 'Staphylococcus aureus',
        'short': 'S. aureus',
        'gram': 'Gram-positive',
        'who_priority': 'High',
        'who_year': 2024,
        'diseases': 'skin and soft tissue infections, bacteremia, endocarditis, osteomyelitis, pneumonia',
        'resistance': (
            'Methicillin-resistant S. aureus (MRSA) carries mecA encoding PBP2a, conferring '
            'resistance to all beta-lactams. Vancomycin-intermediate (VISA) and vancomycin-resistant '
            '(VRSA) strains, though rare, represent a critical threat. Daptomycin resistance '
            'via mprF mutations is emerging in clinical settings.'
        ),
        'current_treatment': 'vancomycin, daptomycin, linezolid, ceftaroline',
        'microbiome_concern': (
            'Current MRSA treatments (vancomycin, linezolid) have significant '
            'anti-anaerobic activity that disrupts Bacteroides and Clostridium species '
            'in the gut. Wong et al. (Nature 2023) demonstrated that structure-aware ML '
            'can identify MRSA-active compounds with reduced collateral microbiome damage.'
        ),
    },
    'paeruginosa': {
        'full_name': 'Pseudomonas aeruginosa',
        'short': 'P. aeruginosa',
        'gram': 'Gram-negative',
        'who_priority': 'Critical',
        'who_year': 2024,
        'diseases': 'ventilator-associated pneumonia (VAP), chronic lung infections in cystic fibrosis, burn wound infections, bloodstream infections',
        'resistance': (
            'Intrinsically resistant to many antibiotics due to low outer membrane permeability, '
            'constitutive efflux pumps (MexAB-OprM, MexXY-OprM), and chromosomal AmpC beta-lactamase. '
            'Acquired resistance via metallo-beta-lactamases (VIM, IMP, NDM) can render strains '
            'pan-drug-resistant. Biofilm formation in chronic infections further reduces antibiotic efficacy.'
        ),
        'current_treatment': 'piperacillin-tazobactam, ceftazidime, meropenem, colistin',
        'microbiome_concern': (
            'Anti-pseudomonal antibiotics (piperacillin-tazobactam, carbapenems) are among '
            'the most microbiome-destructive drug classes. Treatment courses for P. aeruginosa '
            'infections are typically prolonged (10-21 days), amplifying collateral gut damage.'
        ),
    },
    'mtb': {
        'full_name': 'Mycobacterium tuberculosis',
        'short': 'M. tuberculosis',
        'gram': 'Acid-fast (Mycobacterium)',
        'who_priority': 'Critical',
        'who_year': 2024,
        'diseases': 'pulmonary tuberculosis, extrapulmonary TB (meningeal, miliary, skeletal)',
        'resistance': (
            'Multi-drug resistant TB (MDR-TB: resistant to isoniazid + rifampicin) affects '
            '~500,000 new cases/year. Extensively drug-resistant TB (XDR-TB: additionally '
            'resistant to fluoroquinolones + injectable agents) has mortality >50%. '
            'Resistance arises from chromosomal mutations in target genes (katG, rpoB, gyrA).'
        ),
        'current_treatment': 'isoniazid, rifampicin, pyrazinamide, ethambutol (first-line); bedaquiline, pretomanid, linezolid (BPaL regimen for MDR-TB)',
        'microbiome_concern': (
            'Standard 6-month TB treatment with rifampicin causes profound microbiome disruption. '
            'Rifampicin has one of the broadest antimicrobial spectra of any drug, eliminating '
            'Bacteroides, Bifidobacterium, and Lactobacillus populations. Recovery takes months '
            'to years. A selective anti-TB agent could preserve gut health during treatment.'
        ),
    },
}

MODEL_SCIENCE = {
    'rf': {
        'name': 'Random Forest',
        'year': 'Baseline',
        'architecture': 'Ensemble of 500 decision trees on 2048-bit Morgan (ECFP4) fingerprints',
        'training': '5-fold scaffold-based cross-validation',
        'strengths': 'Fast, interpretable, strong on small datasets, captures substructure patterns',
        'limitations': 'Fixed-length fingerprints lose 3D and electronic information',
        'reference': 'Breiman (2001), Morgan fingerprints: Rogers & Hahn, JCICS (2010)',
    },
    'dmpnn': {
        'name': 'D-MPNN (Directed Message Passing Neural Network)',
        'year': '2020',
        'architecture': 'Graph neural network that passes messages along directed bonds in the molecular graph',
        'training': '5-fold scaffold CV, 50 epochs, batch size 50',
        'strengths': 'Learns task-specific molecular representations directly from structure; discovered halicin (Stokes et al., Cell 2020) and abaucin (Wong et al., Nature 2023)',
        'limitations': 'Requires more data than RF; does not capture long-range electronic effects',
        'reference': 'Yang et al., JCICS (2019); Stokes et al., Cell (2020)',
    },
    'chemeleon': {
        'name': 'CheMeleon (Fine-tune)',
        'year': '2026',
        'architecture': 'Foundation model: D-MPNN backbone pretrained on ~1M compounds across diverse assays, then fine-tuned (all weights trainable) on target task',
        'training': '5-fold scaffold CV, 5 epochs, lr=1e-4, dropout=0.3',
        'strengths': 'State-of-the-art: wins 75-79% of Polaris benchmarks. Full fine-tuning adapts both encoder and head.',
        'limitations': 'Risk of overfitting on very small datasets even with low LR',
        'reference': 'Burns et al., arXiv:2506.15792v2 (2026)',
    },
    'chemeleon_frozen': {
        'name': 'CheMeleon (Frozen Encoder)',
        'year': '2026',
        'architecture': 'Same pretrained D-MPNN backbone (FROZEN), only the classification FFN head trains',
        'training': '5-fold scaffold CV, 10 epochs, lr=1e-3 (safe since only FFN trains)',
        'strengths': 'Cannot overfit encoder. Only ~10K trainable params. Very fast. Best for tiny datasets (<1K compounds).',
        'limitations': 'Cannot adapt molecular representations to task; limited by quality of pretrained features',
        'reference': 'Burns et al., arXiv:2506.15792v2 (2026); standard transfer learning practice',
    },
    'dmpnn_rdkit': {
        'name': 'D-MPNN+RDKit (Stokes Architecture)',
        'year': '2026',
        'architecture': 'D-MPNN (depth=5, hidden=1600) with 200 RDKit 2D normalized descriptors',
        'training': '5-fold scaffold CV, 50 epochs, ensemble of 5 fold models for screening',
        'strengths': 'Matches Stokes architecture. RDKit features fix phosphate bias. Ensemble fixes saturation.',
        'limitations': 'Slower inference. Lower ROC-AUC than simpler D-MPNN on pathogen tasks.',
        'reference': 'Stokes et al., Cell (2020); Yang et al., JCICS (2019)',
    },
    'molformer': {
        'name': 'MoLFormer-XL',
        'year': '2022',
        'architecture': 'Transformer (BERT-style) pretrained on 1.1 billion SMILES strings using masked language modeling',
        'training': 'Fine-tuned with classification head, AdamW + cosine LR, early stopping',
        'strengths': 'Captures SMILES syntax patterns analogous to natural language; pretrained on largest molecular corpus; good at scaffold-hopping',
        'limitations': 'SMILES representation is not unique (same molecule has multiple SMILES); may miss 3D geometry',
        'reference': 'Ross et al., Nature Machine Intelligence (2022)',
    },
}

# ============================================================================
# REGULATORY STANDARDS & QUANTITATIVE CRITERIA
# ============================================================================

# Selected CLSI M100 Ed35 (2025) MIC breakpoints (ug/mL)
# Reference: CLSI. Performance Standards for Antimicrobial Susceptibility
# Testing. 35th ed. CLSI Supplement M100. 2025.
CLSI_BREAKPOINTS = {
    'ecoli': [
        ('Ciprofloxacin', 0.25, 0.5, 1),
        ('Meropenem', 1, 2, 4),
        ('Ceftriaxone', 1, 2, 4),
        ('Amoxicillin-clavulanate', 8, 16, 32),
        ('Piperacillin-tazobactam', 16, 32, 128),
        ('Gentamicin', 4, 8, 16),
    ],
    'saureus': [
        ('Vancomycin', 2, None, 16),
        ('Daptomycin', 1, None, None),
        ('Linezolid', 4, None, 8),
        ('Oxacillin (MRSA screen)', 2, None, 4),
        ('Clindamycin', 0.5, 1, 4),
        ('Trimethoprim-sulfamethoxazole', 2, None, 4),
    ],
    'paeruginosa': [
        ('Meropenem', 2, 4, 8),
        ('Ceftazidime', 8, 16, 32),
        ('Piperacillin-tazobactam', 16, 32, 128),
        ('Tobramycin', 4, 8, 16),
        ('Colistin', None, 2, None),
    ],
    'mtb': [
        ('Rifampicin', 1, None, None),
        ('Isoniazid (low-level)', 0.2, None, 1),
        ('Moxifloxacin', 0.25, 0.5, 2),
        ('Bedaquiline', 0.25, None, None),
    ],
}  # Format: (drug, S_breakpoint, I_breakpoint, R_breakpoint), None=not defined

# WHO BPPL 2024 scores and CDC burden data
# Reference: WHO. WHO bacterial priority pathogens list, 2024.
#   ISBN 978-92-4-009346-1. Lancet Infect Dis (Sati et al., 2025).
# Reference: CDC. Antibiotic Resistance Threats in the United States, 2019.
WHO_BURDEN = {
    'ecoli': {
        'who_bppl_category': 'Critical',
        'who_bppl_resistance': '3rd-gen cephalosporin-resistant, carbapenem-resistant',
        'cdc_cases_per_year': 197400,
        'cdc_deaths_per_year': 9100,
        'global_burden_note': 'One of two pathogens responsible for ~50% of AMR-attributable fatal burden in high-income countries (GBD 2019)',
    },
    'saureus': {
        'who_bppl_category': 'High',
        'who_bppl_score_pct': 59,
        'who_bppl_resistance': 'Methicillin-resistant (MRSA)',
        'cdc_cases_per_year': 323700,
        'cdc_deaths_per_year': 10600,
        'global_burden_note': 'One of two pathogens responsible for ~50% of AMR-attributable fatal burden in high-income countries (GBD 2019)',
    },
    'paeruginosa': {
        'who_bppl_category': 'Critical',
        'who_bppl_resistance': 'Carbapenem-resistant',
        'cdc_cases_per_year': 32600,
        'cdc_deaths_per_year': 2700,
        'global_burden_note': 'Intrinsically resistant to many antibiotics; biofilm-forming; common in ICU settings',
    },
    'mtb': {
        'who_bppl_category': 'Critical',
        'who_bppl_resistance': 'Rifampicin-resistant',
        'who_note': 'Added to BPPL 2024 after independent analysis; ~500,000 new MDR-TB cases/year globally',
        'global_burden_note': 'Leading infectious disease killer worldwide; 1.3 million deaths in 2022 (WHO GTB Report)',
    },
}

# Selectivity Index definitions
# Reference: Standard pharmacological metric.
#   SI = CC50_human / MIC_pathogen
SELECTIVITY_INDEX_TIERS = [
    (1, 'NOT viable: toxic at therapeutic dose'),
    (10, 'Narrow therapeutic window (problematic)'),
    (100, 'Promising (typical for approved antibiotics)'),
    (1000, 'Exceptional selectivity'),
]

# PK/PD targets (FDA/EMA guidelines)
# Reference: FDA Guidance (2018); EMA CHMP/594085/2015
PKPD_TARGETS = {
    'time_dependent': {
        'index': '%fT>MIC',
        'target': '40-70% of dosing interval',
        'drug_classes': 'Beta-lactams (penicillins, cephalosporins, carbapenems)',
        'note': 'Free drug concentration must exceed MIC for 40-70% of the dosing interval',
    },
    'concentration_dependent': {
        'index': 'fAUC/MIC',
        'target': '30-50 (Gram-negative), 80-100 (Gram-positive)',
        'drug_classes': 'Fluoroquinolones, daptomycin, tigecycline',
        'note': 'Ratio of free-drug area under curve to MIC',
    },
    'peak_dependent': {
        'index': 'fCmax/MIC',
        'target': '8-10',
        'drug_classes': 'Aminoglycosides (gentamicin, tobramycin, amikacin)',
        'note': 'Peak free concentration must be 8-10x MIC',
    },
}

# Published ML benchmark thresholds for antibiotic discovery
PUBLISHED_ML_THRESHOLDS = {
    'stokes_2020': {
        'paper': 'Stokes et al., Cell (2020)',
        'model': 'Chemprop ensemble x20 + RDKit features',
        'training_size': 2335,
        'positive_rate': 0.051,  # 120/2335
        'hit_rate_top99': 0.515,  # 51/99
        'screening_library': 'Drug Repurposing Hub (~6,111 compounds)',
        'zenodo': 'https://zenodo.org/records/6527883',
    },
    'wong_2024': {
        'paper': 'Wong et al., Nature (2024)',
        'model': 'Chemprop ensemble x20 + RDKit features',
        'training_size': 39312,
        'positive_rate': 0.013,  # 512/39312
        'activity_threshold_mcule': 0.4,
        'activity_threshold_broad': 0.2,
        'cytotox_threshold': 0.2,
        'screening_library': 'Mcule (11.3M) + Broad (800K)',
        'github': 'https://github.com/felixjwong/antibioticsai',
    },
}


# ============================================================================
# KNOWN ANTIBIOTIC CLASSIFIER
# ============================================================================
ANTIBIOTIC_MOA_KEYWORDS = [
    'antibacterial', 'antibiotic', 'antimicrobial', 'antifungal', 'antiseptic',
    'beta-lactam', 'penicillin', 'cephalosporin', 'carbapenem', 'monobactam',
    'aminoglycoside', 'tetracycline', 'macrolide', 'fluoroquinolone', 'quinolone',
    'sulfonamide', 'trimethoprim', 'glycopeptide', 'vancomycin', 'lipopeptide',
    'polymyxin', 'colistin', 'rifamycin', 'rifampicin', 'nitroimidazole',
    'metronidazole', 'oxazolidinone', 'linezolid', 'daptomycin',
    'cell wall synthesis', 'peptidoglycan', 'dna gyrase', 'topoisomerase',
    'dihydrofolate reductase', '30s ribosom', '50s ribosom',
    'transpeptidase', 'beta-lactamase', 'mycobacter', 'tuberculosis',
    'isoniazid', 'ethambutol', 'pyrazinamide', 'nitrofurantoin',
    'fosfomycin', 'mupirocin', 'fusidic', 'clindamycin',
    'chloramphenicol', 'streptomycin', 'kanamycin', 'gentamicin',
    'erythromycin', 'azithromycin', 'clarithromycin', 'ciprofloxacin',
    'levofloxacin', 'moxifloxacin', 'doxycycline', 'minocycline',
    'tigecycline', 'amoxicillin', 'ampicillin', 'ceftriaxone',
    'cefepime', 'doripenem', 'ertapenem', 'aztreonam',
]

ANTIBIOTIC_DISEASE_KEYWORDS = [
    'bacterial infection', 'antimicrobial', 'tuberculosis', 'pneumonia',
    'sepsis', 'urinary tract', 'meningitis', 'endocarditis',
    'osteomyelitis', 'cellulitis', 'abscess', 'peritonitis',
]


def is_known_antibiotic(row):
    """Classify based on MoA, disease area, and target keywords."""
    text = ' '.join([
        str(row.get('moa', '')),
        str(row.get('disease_area', '')),
        str(row.get('target', '')),
    ]).lower()
    for kw in ANTIBIOTIC_MOA_KEYWORDS:
        if kw in text:
            return True
    for kw in ANTIBIOTIC_DISEASE_KEYWORDS:
        if kw in text:
            return True
    return False


# ============================================================================
# DATA LOADING + CONSENSUS
# ============================================================================
def load_all_screening_lists():
    lists = {}
    if not os.path.isdir(config.SCREENING_DIR):
        return lists
    for f in sorted(os.listdir(config.SCREENING_DIR)):
        if f.endswith('.csv') and 'ranked' in f:
            try:
                df = pd.read_csv(os.path.join(config.SCREENING_DIR, f))
                if 'selectivity_score' in df.columns and len(df) > 0:
                    lists[f.replace('.csv', '')] = df
            except Exception:
                pass
    return lists


def parse_list_key(key):
    parts = key.split('_ranked_')
    if len(parts) != 2:
        return None, None, None
    pipeline = parts[0]
    rest = parts[1]
    for t in [5, 10, 20]:
        if rest.endswith(f'_t{t}'):
            return pipeline, rest[:-len(f'_t{t}')], t
    return pipeline, rest, None


def build_consensus(all_lists, top_n=TOP_N):
    evidence = defaultdict(lambda: {
        'models': set(), 'pathogens': set(), 'thresholds': set(),
        'scores': [], 'p_paths': [], 'p_guts': [], 'ranks': [],
        'per_pathogen_scores': defaultdict(list),
        'per_model_scores': defaultdict(list),
        'name': '', 'moa': '', 'clinical_phase': '',
        'disease_area': '', 'target': '',
    })
    for key, df in all_lists.items():
        pipeline, pathogen, threshold = parse_list_key(key)
        if pipeline is None or threshold is None:
            continue
        for _, row in df.head(top_n).iterrows():
            smi = row.get('smiles', '')
            if not smi:
                continue
            info = evidence[smi]
            info['models'].add(pipeline)
            info['pathogens'].add(pathogen)
            info['thresholds'].add(threshold)
            s = row.get('selectivity_score', 0)
            info['scores'].append(s)
            info['p_paths'].append(row.get('p_pathogen', 0))
            info['p_guts'].append(row.get('p_gut', 0))
            info['ranks'].append(row.get('rank', 9999))
            info['per_pathogen_scores'][pathogen].append(s)
            info['per_model_scores'][pipeline].append(s)
            for col in ['name', 'moa', 'clinical_phase', 'disease_area', 'target']:
                if not info[col]:
                    info[col] = str(row.get(col, '') or '')

    rows = []
    for smi, info in evidence.items():
        r = {
            'smiles': smi, 'name': info['name'],
            'n_models': len(info['models']),
            'models': ', '.join(sorted(info['models'])),
            'n_pathogens': len(info['pathogens']),
            'pathogens': ', '.join(sorted(info['pathogens'])),
            'thresholds': ', '.join(str(t) for t in sorted(info['thresholds'])),
            'best_selectivity': round(max(info['scores']), 4),
            'mean_selectivity': round(np.mean(info['scores']), 4),
            'std_selectivity': round(np.std(info['scores']), 4) if len(info['scores']) > 1 else 0.0,
            'mean_p_pathogen': round(np.mean(info['p_paths']), 4),
            'mean_p_gut': round(np.mean(info['p_guts']), 4),
            'best_rank': min(info['ranks']),
            'moa': info['moa'], 'clinical_phase': info['clinical_phase'],
            'disease_area': info['disease_area'], 'target': info['target'],
        }
        # Per-pathogen best selectivity
        for pk in ['ecoli', 'saureus', 'paeruginosa', 'mtb']:
            pscores = info['per_pathogen_scores'].get(pk, [])
            r[f's_{pk}'] = round(max(pscores), 4) if pscores else 0.0
        # Per-model best selectivity
        for mk in ['rf', 'dmpnn', 'chemeleon_frozen', 'molformer', 'dmpnn_rdkit']:
            mscores = info['per_model_scores'].get(mk, [])
            r[f's_{mk}'] = round(max(mscores), 4) if mscores else 0.0
        r['is_known_antibiotic'] = is_known_antibiotic(r)
        rows.append(r)

    df = pd.DataFrame(rows)
    df = df.sort_values(['n_models', 'best_selectivity'], ascending=[False, False])
    return df.reset_index(drop=True)


def build_benchmark_data(all_lists, consensus_df):
    """
    Build a per-pathogen benchmark comparing novel candidates against known antibiotics.

    For each screening list (pathogen x threshold x model), partitions compounds into
    known antibiotics and novel candidates, then computes distributional statistics.
    Also identifies specific novel candidates that outscore the best/median known antibiotic.

    Returns:
        benchmark: dict keyed by pathogen, each containing:
            - known_stats: {mean_S, median_S, max_S, p25_S, p75_S, top5_names, ...}
            - novel_stats: same structure
            - novel_outperformers: DataFrame of novels scoring above median known S
            - n_novel_above_best_known: count of novels above best known S
    """
    benchmark = {}

    for pk in ['ecoli', 'saureus', 'paeruginosa', 'mtb']:
        pk_data = {'lists': {}}

        for key, df_list in all_lists.items():
            pipeline, pathogen, threshold = parse_list_key(key)
            if pathogen != pk or threshold != 10:
                continue

            df = df_list.copy()
            df['is_ab'] = df.apply(is_known_antibiotic, axis=1)
            k = df[df['is_ab'] == True]
            n = df[df['is_ab'] == False]

            def dist_stats(sub, label):
                if len(sub) == 0:
                    return {'count': 0, 'mean_S': 0, 'median_S': 0, 'max_S': 0,
                            'p25_S': 0, 'p75_S': 0, 'min_S': 0, 'std_S': 0,
                            'mean_p_path': 0, 'mean_p_gut': 0, 'top5': []}
                s = sub['selectivity_score']
                top5 = sub.nlargest(5, 'selectivity_score')
                return {
                    'count': len(sub),
                    'mean_S': round(s.mean(), 4),
                    'median_S': round(s.median(), 4),
                    'max_S': round(s.max(), 4),
                    'min_S': round(s.min(), 4),
                    'p25_S': round(s.quantile(0.25), 4),
                    'p75_S': round(s.quantile(0.75), 4),
                    'std_S': round(s.std(), 4),
                    'mean_p_path': round(sub['p_pathogen'].mean(), 4),
                    'mean_p_gut': round(sub['p_gut'].mean(), 4),
                    'top5': [(str(r.get('name', ''))[:25] or r['smiles'][:20],
                              round(r['selectivity_score'], 4),
                              round(r['p_pathogen'], 4),
                              round(r['p_gut'], 4))
                             for _, r in top5.iterrows()],
                }

            known_stats = dist_stats(k, 'known')
            novel_stats = dist_stats(n, 'novel')

            # Novels that outscore the median known antibiotic
            if known_stats['median_S'] > 0:
                outperformers = n[n['selectivity_score'] > known_stats['median_S']]
            else:
                outperformers = n.head(0)

            # Novels that outscore the BEST known antibiotic
            n_above_best = int((n['selectivity_score'] > known_stats['max_S']).sum()) if known_stats['max_S'] > 0 else 0

            pk_data['lists'][pipeline] = {
                'known_stats': known_stats,
                'novel_stats': novel_stats,
                'n_novel_above_median_known': len(outperformers),
                'n_novel_above_best_known': n_above_best,
                'outperformers': outperformers,
            }

        benchmark[pk] = pk_data

    return benchmark


def make_benchmark_html(benchmark, consensus_df, save_dir):
    """
    Interactive benchmark visualization: novel candidates vs known antibiotics.

    Panel 1: Box/violin comparison of selectivity distributions per pathogen
    Panel 2: Ranked lollipop chart showing where novels land vs known reference lines
    Panel 3: Summary statistics table
    """
    try:
        import plotly.graph_objects as go
        from plotly.subplots import make_subplots
    except ImportError:
        logger.warning("  plotly not available, skipping benchmark plot")
        return None

    pathogens = ['ecoli', 'saureus', 'paeruginosa', 'mtb']
    p_shorts = [PATHOGEN_SCIENCE[p]['short'] for p in pathogens]

    # Collect all scores from t10 lists for the violin/box plot
    known_all = {p: [] for p in pathogens}
    novel_all = {p: [] for p in pathogens}
    for pk in pathogens:
        for pipeline, pdata in benchmark.get(pk, {}).get('lists', {}).items():
            ks = pdata['known_stats']
            ns = pdata['novel_stats']
            # We need the raw scores; reconstruct from the top5 at least
            # Better: pull from the screening lists directly
            pass

    # Pull raw scores from screening lists (more accurate)
    from collections import defaultdict as dd
    known_scores = dd(list)
    novel_scores = dd(list)
    known_names_scores = dd(list)
    novel_names_scores = dd(list)

    screening_dir = config.SCREENING_DIR
    if os.path.isdir(screening_dir):
        for f in sorted(os.listdir(screening_dir)):
            if not (f.endswith('.csv') and 'ranked' in f and '_t10' in f):
                continue
            pipeline, pathogen, threshold = parse_list_key(f.replace('.csv', ''))
            if pathogen not in pathogens or threshold != 10:
                continue
            try:
                df = pd.read_csv(os.path.join(screening_dir, f))
                df['is_ab'] = df.apply(is_known_antibiotic, axis=1)
                # Use top 300 for visualization
                top = df.head(300)
                for _, row in top.iterrows():
                    s = row.get('selectivity_score', 0)
                    nm = str(row.get('name', ''))[:25] or row.get('smiles', '')[:20]
                    if row['is_ab']:
                        known_scores[pathogen].append(s)
                        known_names_scores[pathogen].append((nm, s, pipeline))
                    else:
                        novel_scores[pathogen].append(s)
                        novel_names_scores[pathogen].append((nm, s, pipeline))
            except Exception:
                pass

    # ---- Build the figure ----
    fig = make_subplots(
        rows=2, cols=2,
        subplot_titles=[
            f'{PATHOGEN_SCIENCE[p]["short"]}: Novel vs Known Selectivity'
            for p in pathogens
        ],
        vertical_spacing=0.14, horizontal_spacing=0.1,
    )

    positions = [(1,1), (1,2), (2,1), (2,2)]
    for idx, pk in enumerate(pathogens):
        r, c = positions[idx]
        k_scores = known_scores.get(pk, [])
        n_scores = novel_scores.get(pk, [])

        if len(k_scores) > 0:
            fig.add_trace(go.Violin(
                y=k_scores, name='Known AB', side='negative',
                line_color='#D32F2F', fillcolor='rgba(211,47,47,0.25)',
                meanline_visible=True, showlegend=(idx == 0),
                legendgroup='known',
                hoverinfo='y',
            ), row=r, col=c)

        if len(n_scores) > 0:
            fig.add_trace(go.Violin(
                y=n_scores, name='Novel', side='positive',
                line_color='#1565C0', fillcolor='rgba(21,101,192,0.25)',
                meanline_visible=True, showlegend=(idx == 0),
                legendgroup='novel',
                hoverinfo='y',
            ), row=r, col=c)

        # Reference lines for known antibiotic benchmarks
        if len(k_scores) > 0:
            k_med = float(np.median(k_scores))
            k_max = float(np.max(k_scores))
            fig.add_hline(y=k_med, line_dash='dash', line_color='#D32F2F',
                          annotation_text=f'Known median: {k_med:.3f}',
                          annotation_font_size=9,
                          row=r, col=c)
            fig.add_hline(y=k_max, line_dash='dot', line_color='#B71C1C',
                          annotation_text=f'Best known: {k_max:.3f}',
                          annotation_font_size=9,
                          row=r, col=c)

        fig.update_yaxes(title_text='Selectivity Score', range=[0, 1.05], row=r, col=c)

    fig.update_layout(
        title=dict(
            text=('<b>Benchmark: How Do Novel Candidates Compare to Known Antibiotics?</b><br>'
                  '<sup>Violin distributions from top-300 screening results (t10 threshold) | '
                  'Dashed line = median known antibiotic | Dotted = best known</sup>'),
            font=dict(size=14),
        ),
        width=1100, height=900,
        template='plotly_white',
        violingap=0, violinmode='overlay',
    )

    path = os.path.join(save_dir, 'candidates_benchmark_comparison.html')
    fig.write_html(path, include_plotlyjs='cdn')
    logger.info(f"    Benchmark comparison: {path}")

    # ---- Lollipop chart: top 30 novels with known reference bands ----
    fig2 = go.Figure()

    # Get top 30 novels overall from consensus
    novel_consensus = consensus_df[consensus_df['is_known_antibiotic'] == False].head(30)
    known_consensus = consensus_df[consensus_df['is_known_antibiotic'] == True]

    if len(novel_consensus) > 0:
        names = []
        for _, row in novel_consensus.iterrows():
            nm = row['name'][:22] if row['name'] else row['smiles'][:18]
            names.append(nm)

        # Known antibiotic reference band
        if len(known_consensus) > 0:
            k_median = known_consensus['best_selectivity'].median()
            k_p75 = known_consensus['best_selectivity'].quantile(0.75)
            k_max = known_consensus['best_selectivity'].max()
            k_p25 = known_consensus['best_selectivity'].quantile(0.25)

            fig2.add_vrect(x0=k_p25, x1=k_p75,
                           fillcolor='rgba(211,47,47,0.1)', line_width=0,
                           annotation_text='Known AB IQR', annotation_position='top left',
                           annotation_font_size=10)
            fig2.add_vline(x=k_median, line_dash='dash', line_color='#D32F2F',
                           annotation_text=f'Known median ({k_median:.3f})',
                           annotation_font_size=10)
            fig2.add_vline(x=k_max, line_dash='dot', line_color='#B71C1C',
                           annotation_text=f'Best known ({k_max:.3f})',
                           annotation_font_size=10)

        hover = []
        for _, row in novel_consensus.iterrows():
            nm = row['name'][:25] if row['name'] else row['smiles'][:20]
            moa = row['moa'][:40] if row['moa'] else 'Unknown'
            disease = row['disease_area'][:30] if row['disease_area'] else '--'
            hover.append(
                f"<b>{nm}</b><br>"
                f"S = {row['best_selectivity']:.3f}<br>"
                f"P(kill) = {row['mean_p_pathogen']:.3f}<br>"
                f"P(gut) = {row['mean_p_gut']:.3f}<br>"
                f"Models: {row['n_models']}/4<br>"
                f"MoA: {moa}<br>"
                f"Original use: {disease}"
            )

        # Color by whether they beat known median
        colors = []
        for _, row in novel_consensus.iterrows():
            s = row['best_selectivity']
            if len(known_consensus) > 0 and s > k_max:
                colors.append('#2E7D32')  # dark green = beats best known
            elif len(known_consensus) > 0 and s > k_median:
                colors.append('#1565C0')  # blue = beats median known
            else:
                colors.append('#90CAF9')  # light blue = below median

        fig2.add_trace(go.Bar(
            y=names[::-1],
            x=novel_consensus['best_selectivity'].values[::-1],
            orientation='h',
            marker=dict(color=colors[::-1], line=dict(width=1, color='white')),
            text=hover[::-1], hoverinfo='text',
        ))

    fig2.update_layout(
        title=dict(
            text=('<b>Top 30 Novel Candidates vs Known Antibiotic Benchmarks</b><br>'
                  '<sup>Green = outscores best known AB | Blue = above known median | '
                  'Light blue = below known median | Red band = known AB interquartile range</sup>'),
            font=dict(size=14),
        ),
        xaxis_title='Best Selectivity Score',
        width=1000, height=max(600, len(novel_consensus) * 24),
        template='plotly_white',
        showlegend=False,
        margin=dict(l=180),
    )

    path2 = os.path.join(save_dir, 'candidates_benchmark_lollipop.html')
    fig2.write_html(path2, include_plotlyjs='cdn')
    logger.info(f"    Benchmark lollipop: {path2}")

    return [path, path2]


# ============================================================================
# HTML VISUALIZATIONS (Plotly)
# ============================================================================

def make_3d_landscape(df_list, pathogen, pipeline, save_dir):
    """Interactive 3D scatter: P_pathogen x P_gut x S, hover shows full compound info."""
    try:
        import plotly.graph_objects as go
    except ImportError:
        logger.warning("  plotly not installed, skipping 3D landscape")
        return None

    df = df_list.head(800).copy()
    df['is_ab'] = df.apply(is_known_antibiotic, axis=1)
    df['cat'] = df['is_ab'].map({True: 'Known Antibiotic', False: 'Novel Candidate'})
    df['label'] = df['name'].fillna('').str[:30]

    pname = PATHOGEN_SCIENCE[pathogen]['full_name'] if pathogen in PATHOGEN_SCIENCE else pathogen
    mname = MODEL_SCIENCE[pipeline]['name'] if pipeline in MODEL_SCIENCE else pipeline

    fig = go.Figure()

    # Ideal zone surface: high P_path, low P_gut
    xx = np.linspace(0.7, 1.0, 20)
    yy = np.linspace(0.0, 0.3, 20)
    X, Y = np.meshgrid(xx, yy)
    Z = X * (1 - Y)
    fig.add_trace(go.Surface(
        x=X, y=Y, z=Z, opacity=0.15, colorscale='Greens', showscale=False,
        name='Ideal Zone', hoverinfo='skip',
    ))

    for cat, color, sym, sz in [
        ('Novel Candidate', '#1976D2', 'circle', 6),
        ('Known Antibiotic', '#D32F2F', 'diamond', 8),
    ]:
        mask = df['cat'] == cat
        sub = df[mask]
        if len(sub) == 0:
            continue
        hover_text = []
        for _, row in sub.iterrows():
            nm = row['label'] if row['label'] else row['smiles'][:25]
            moa = str(row.get('moa', ''))[:50] or 'Unknown'
            hover_text.append(
                f"<b>{nm}</b><br>"
                f"Selectivity: {row['selectivity_score']:.3f}<br>"
                f"P(kills {PATHOGEN_SCIENCE.get(pathogen,{}).get('short',pathogen)}): "
                f"{row['p_pathogen']:.3f}<br>"
                f"P(harms gut): {row['p_gut']:.3f}<br>"
                f"MoA: {moa}<br>"
                f"Rank: {int(row.get('rank', 0))}"
            )
        fig.add_trace(go.Scatter3d(
            x=sub['p_pathogen'], y=sub['p_gut'], z=sub['selectivity_score'],
            mode='markers',
            marker=dict(
                size=np.clip(sub['selectivity_score'] * 10 + 2, 3, 14),
                color=sub['selectivity_score'],
                colorscale='Viridis' if cat == 'Novel Candidate' else 'Reds',
                opacity=0.85 if cat == 'Known Antibiotic' else 0.7,
                symbol=sym,
                line=dict(width=0.5, color='white'),
                showscale=(cat == 'Novel Candidate'),
                colorbar=dict(title='S', x=1.02) if cat == 'Novel Candidate' else None,
            ),
            text=hover_text, hoverinfo='text', name=cat,
        ))

    pshort = PATHOGEN_SCIENCE.get(pathogen, {}).get('short', pathogen)
    fig.update_layout(
        title=dict(
            text=(f"<b>Selectivity Landscape: {pname}</b><br>"
                  f"<sup>Model: {mname} | Top 800 from Repurposing Hub | "
                  f"Diamonds = known antibiotics</sup>"),
            font=dict(size=15),
        ),
        scene=dict(
            xaxis_title=f'P(kills {pshort})',
            yaxis_title='P(harms gut flora)',
            zaxis_title='Selectivity Score S',
            xaxis=dict(range=[0, 1.05], backgroundcolor='rgba(240,245,255,0.9)'),
            yaxis=dict(range=[0, 1.05], backgroundcolor='rgba(255,240,240,0.9)'),
            zaxis=dict(range=[0, 1.05], backgroundcolor='rgba(240,255,240,0.9)'),
            camera=dict(eye=dict(x=1.6, y=1.6, z=0.7)),
            aspectratio=dict(x=1, y=1, z=0.8),
        ),
        width=1100, height=850,
        template='plotly_white',
        legend=dict(x=0.01, y=0.99, bgcolor='rgba(255,255,255,0.8)'),
        margin=dict(l=0, r=0, t=80, b=0),
    )

    path = os.path.join(save_dir, f'candidates_3d_landscape_{pipeline}_{pathogen}.html')
    fig.write_html(path, include_plotlyjs='cdn')
    logger.info(f"    3D landscape: {path}")
    return path


def make_2d_scatter(df_list, pathogen, pipeline, save_dir):
    """Interactive 2D scatter with ideal zone, contour lines, and hover details."""
    try:
        import plotly.graph_objects as go
    except ImportError:
        return None

    df = df_list.head(500).copy()
    df['is_ab'] = df.apply(is_known_antibiotic, axis=1)
    df['label'] = df['name'].fillna('').str[:30]
    pshort = PATHOGEN_SCIENCE.get(pathogen, {}).get('short', pathogen)
    mname = MODEL_SCIENCE.get(pipeline, {}).get('name', pipeline)

    fig = go.Figure()

    # Ideal zone rectangle
    fig.add_shape(type='rect', x0=0.7, x1=1.02, y0=-0.02, y1=0.3,
                  fillcolor='rgba(76,175,80,0.08)', line=dict(width=0))
    fig.add_annotation(x=0.85, y=0.05, text='<b>IDEAL ZONE</b><br>High kill, low gut harm',
                       showarrow=False, font=dict(size=11, color='rgba(76,175,80,0.5)'))

    # Selectivity contours
    x = np.linspace(0, 1, 200)
    y_arr = np.linspace(0, 1, 200)
    for s_val, dash_style in [(0.3, 'dot'), (0.5, 'dash'), (0.7, 'dashdot')]:
        # S = x*(1-y) => y = 1 - S/x
        y_line = 1 - s_val / x
        valid = (y_line >= 0) & (y_line <= 1) & (x > 0.01)
        fig.add_trace(go.Scatter(
            x=x[valid], y=y_line[valid], mode='lines',
            line=dict(color='gray', width=1, dash=dash_style),
            name=f'S = {s_val}', showlegend=True, hoverinfo='name',
        ))

    for cat, color, sym, sz in [
        ('Novel Candidate', '#1565C0', 'circle', 8),
        ('Known Antibiotic', '#C62828', 'diamond', 10),
    ]:
        mask = (df['is_ab'] == True) if cat == 'Known Antibiotic' else (df['is_ab'] == False)
        sub = df[mask]
        if len(sub) == 0:
            continue
        hover = []
        for _, row in sub.iterrows():
            nm = row['label'] if row['label'] else row['smiles'][:20]
            moa = str(row.get('moa', ''))[:50] or 'Unknown'
            hover.append(
                f"<b>{nm}</b><br>"
                f"S = {row['selectivity_score']:.3f}<br>"
                f"P(kill) = {row['p_pathogen']:.3f}<br>"
                f"P(gut harm) = {row['p_gut']:.3f}<br>"
                f"MoA: {moa}<br>"
                f"Rank: {int(row.get('rank', 0))}"
            )
        fig.add_trace(go.Scatter(
            x=sub['p_pathogen'], y=sub['p_gut'], mode='markers',
            marker=dict(
                size=np.clip(sub['selectivity_score'] * 15 + 4, 5, 18),
                color=sub['selectivity_score'],
                colorscale='Viridis' if cat == 'Novel Candidate' else 'Reds',
                opacity=0.8, symbol=sym,
                line=dict(width=1, color='white'),
                showscale=(cat == 'Novel Candidate'),
                colorbar=dict(title='S') if cat == 'Novel Candidate' else None,
            ),
            text=hover, hoverinfo='text', name=cat,
        ))

    fig.update_layout(
        title=dict(
            text=(f"<b>Selectivity Map: {PATHOGEN_SCIENCE.get(pathogen,{}).get('full_name',pathogen)}</b><br>"
                  f"<sup>{mname} | Dashed lines = constant selectivity</sup>"),
            font=dict(size=15),
        ),
        xaxis_title=f'P(kills {pshort}) --- Higher is better --->',
        yaxis_title='<--- Lower is better --- P(harms gut bacteria)',
        xaxis=dict(range=[-0.02, 1.05]),
        yaxis=dict(range=[-0.02, 1.05]),
        width=1000, height=800,
        template='plotly_white',
        legend=dict(x=0.01, y=0.99, bgcolor='rgba(255,255,255,0.85)'),
    )

    path = os.path.join(save_dir, f'candidates_scatter_{pipeline}_{pathogen}.html')
    fig.write_html(path, include_plotlyjs='cdn')
    logger.info(f"    2D scatter: {path}")
    return path


def make_consensus_heatmap(consensus_df, save_dir):
    """Interactive heatmap: top 40 compounds x 4 models."""
    try:
        import plotly.graph_objects as go
    except ImportError:
        return None

    top = consensus_df.head(40)
    if len(top) == 0:
        return None

    pipelines = ['rf', 'dmpnn', 'chemeleon_frozen', 'molformer', 'dmpnn_rdkit']
    p_labels = [MODEL_SCIENCE.get(p, {}).get('name', p) for p in pipelines]

    names = []
    matrix = np.zeros((len(top), len(pipelines)))
    hover = []
    for i, (_, row) in enumerate(top.iterrows()):
        nm = row['name'][:28] if row['name'] else row['smiles'][:22]
        tag = ' *' if row.get('is_known_antibiotic') else ''
        names.append(f"{nm}{tag}")
        models_set = set(row['models'].split(', '))
        row_hover = []
        for j, p in enumerate(pipelines):
            s = row.get(f's_{p}', 0)
            matrix[i, j] = s if p in models_set else 0
            row_hover.append(
                f"<b>{nm}</b><br>{p_labels[j]}<br>"
                f"S = {s:.3f}<br>"
                f"{'IN top-50' if p in models_set else 'Not in top-50'}"
            )
        hover.append(row_hover)

    hover_text = [[hover[i][j] for j in range(len(pipelines))] for i in range(len(top))]

    fig = go.Figure(data=go.Heatmap(
        z=matrix, x=p_labels, y=names,
        colorscale='YlGn', zmin=0, zmax=1,
        text=hover_text, hoverinfo='text',
        colorbar=dict(title='Selectivity'),
    ))

    fig.update_layout(
        title=dict(
            text='<b>Cross-Model Consensus: Top 40 Candidates</b><br><sup>* = known antibiotic | Brighter = higher selectivity</sup>',
            font=dict(size=14)),
        width=900, height=max(600, len(top) * 22),
        template='plotly_white',
        yaxis=dict(autorange='reversed'),
        margin=dict(l=200),
    )

    path = os.path.join(save_dir, 'candidates_consensus_heatmap.html')
    fig.write_html(path, include_plotlyjs='cdn')
    logger.info(f"    Consensus heatmap: {path}")
    return path


def make_known_vs_novel(consensus_df, save_dir):
    """Interactive comparison: known antibiotics vs novel candidates across pathogens."""
    try:
        import plotly.graph_objects as go
        from plotly.subplots import make_subplots
    except ImportError:
        return None

    fig = make_subplots(rows=2, cols=2,
                        subplot_titles=[
                            'Candidate Counts (Known vs Novel)',
                            'Mean Selectivity by Pathogen',
                            'Gut Safety Profile',
                            'Cross-Model Agreement Distribution',
                        ],
                        vertical_spacing=0.15, horizontal_spacing=0.12)

    pathogens = ['ecoli', 'saureus', 'paeruginosa', 'mtb']
    p_labels = [PATHOGEN_SCIENCE[p]['short'] for p in pathogens]

    # 1. Counts
    known_n, novel_n = [], []
    for p in pathogens:
        mask = consensus_df['pathogens'].str.contains(p)
        sub = consensus_df[mask]
        known_n.append(len(sub[sub['is_known_antibiotic'] == True]))
        novel_n.append(len(sub[sub['is_known_antibiotic'] == False]))

    fig.add_trace(go.Bar(x=p_labels, y=known_n, name='Known Antibiotics',
                         marker_color='#D32F2F', opacity=0.85), row=1, col=1)
    fig.add_trace(go.Bar(x=p_labels, y=novel_n, name='Novel Candidates',
                         marker_color='#1565C0', opacity=0.85), row=1, col=1)

    # 2. Mean selectivity
    known_s, novel_s = [], []
    for p in pathogens:
        mask = consensus_df['pathogens'].str.contains(p)
        sub = consensus_df[mask]
        k = sub[sub['is_known_antibiotic'] == True]
        n = sub[sub['is_known_antibiotic'] == False]
        known_s.append(k['mean_selectivity'].mean() if len(k) > 0 else 0)
        novel_s.append(n['mean_selectivity'].mean() if len(n) > 0 else 0)

    fig.add_trace(go.Bar(x=p_labels, y=known_s, name='Known S', showlegend=False,
                         marker_color='#D32F2F', opacity=0.85), row=1, col=2)
    fig.add_trace(go.Bar(x=p_labels, y=novel_s, name='Novel S', showlegend=False,
                         marker_color='#1565C0', opacity=0.85), row=1, col=2)

    # 3. Gut safety: violin of P_gut for known vs novel
    known = consensus_df[consensus_df['is_known_antibiotic'] == True]
    novel = consensus_df[consensus_df['is_known_antibiotic'] == False]
    if len(known) > 0:
        fig.add_trace(go.Violin(y=known['mean_p_gut'], name='Known', side='negative',
                                line_color='#D32F2F', fillcolor='rgba(211,47,47,0.3)',
                                showlegend=False), row=2, col=1)
    if len(novel) > 0:
        fig.add_trace(go.Violin(y=novel['mean_p_gut'], name='Novel', side='positive',
                                line_color='#1565C0', fillcolor='rgba(21,101,192,0.3)',
                                showlegend=False), row=2, col=1)

    # 4. Model agreement histogram
    for df_sub, nm, col in [(known, 'Known', '#D32F2F'), (novel, 'Novel', '#1565C0')]:
        if len(df_sub) == 0:
            continue
        counts = df_sub['n_models'].value_counts().sort_index()
        fig.add_trace(go.Bar(x=[f'{v} models' for v in counts.index], y=counts.values,
                             name=nm, marker_color=col, opacity=0.8,
                             showlegend=False), row=2, col=2)

    fig.update_layout(
        title=dict(text='<b>Known Antibiotics vs Novel Candidates: Full Comparison</b>',
                   font=dict(size=15)),
        width=1100, height=900, template='plotly_white',
        barmode='group',
    )

    path = os.path.join(save_dir, 'candidates_known_vs_novel.html')
    fig.write_html(path, include_plotlyjs='cdn')
    logger.info(f"    Known vs Novel: {path}")
    return path


def make_radar_top(consensus_df, save_dir, n=20):
    """Radar chart showing per-pathogen selectivity for top N candidates."""
    try:
        import plotly.graph_objects as go
    except ImportError:
        return None

    top = consensus_df.head(n)
    if len(top) == 0:
        return None

    categories = ['E. coli', 'S. aureus', 'P. aeruginosa', 'M. tuberculosis']
    cat_keys = ['s_ecoli', 's_saureus', 's_paeruginosa', 's_mtb']

    fig = go.Figure()
    colors = ['#1565C0', '#D32F2F', '#2E7D32', '#F57F17', '#6A1B9A',
              '#00838F', '#BF360C', '#1B5E20', '#4A148C', '#E65100',
              '#0D47A1', '#B71C1C', '#33691E', '#FF6F00', '#4527A0',
              '#006064', '#DD2C00', '#1B5E20', '#311B92', '#E65100']

    for i, (_, row) in enumerate(top.iterrows()):
        nm = row['name'][:25] if row['name'] else f"Compound {i+1}"
        tag = ' [AB]' if row.get('is_known_antibiotic') else ''
        vals = [row.get(k, 0) for k in cat_keys]
        vals.append(vals[0])  # close the polygon
        fig.add_trace(go.Scatterpolar(
            r=vals,
            theta=categories + [categories[0]],
            name=f"{nm}{tag}",
            line=dict(color=colors[i % len(colors)], width=2),
            fill='toself', fillcolor=f'rgba({int(colors[i%len(colors)][1:3],16)},'
                                     f'{int(colors[i%len(colors)][3:5],16)},'
                                     f'{int(colors[i%len(colors)][5:7],16)},0.05)',
            opacity=0.8,
        ))

    fig.update_layout(
        polar=dict(
            radialaxis=dict(visible=True, range=[0, 1], tickfont=dict(size=10)),
        ),
        title=dict(
            text=f'<b>Multi-Pathogen Selectivity Profiles: Top {n} Candidates</b><br>'
                 f'<sup>[AB] = known antibiotic | Each axis = selectivity against that pathogen</sup>',
            font=dict(size=14)),
        width=1000, height=800,
        template='plotly_white',
        legend=dict(font=dict(size=9)),
    )

    path = os.path.join(save_dir, f'candidates_radar_top{n}.html')
    fig.write_html(path, include_plotlyjs='cdn')
    logger.info(f"    Radar chart: {path}")
    return path


def make_master_dashboard(consensus_df, all_lists, save_dir):
    """All-in-one interactive dashboard: table + filters."""
    try:
        import plotly.graph_objects as go
        from plotly.subplots import make_subplots
    except ImportError:
        return None

    top = consensus_df.head(100)
    if len(top) == 0:
        return None

    fig = make_subplots(
        rows=2, cols=2,
        specs=[[{'type': 'scatter'}, {'type': 'scatter'}],
               [{'type': 'table', 'colspan': 2}, None]],
        subplot_titles=['Selectivity vs Models Agreeing',
                        'P(kill) vs P(gut harm)',
                        'Top 50 Candidates'],
        row_heights=[0.45, 0.55],
        vertical_spacing=0.08,
    )

    top['color'] = top['is_known_antibiotic'].map({True: '#D32F2F', False: '#1565C0'})
    top['label_short'] = top['name'].fillna('').str[:20]

    # 1. S vs n_models (jittered)
    jitter = np.random.uniform(-0.15, 0.15, len(top))
    fig.add_trace(go.Scatter(
        x=top['n_models'] + jitter, y=top['best_selectivity'],
        mode='markers',
        marker=dict(size=10, color=top['color'], opacity=0.7,
                    line=dict(width=1, color='white')),
        text=[f"<b>{n}</b><br>S={s:.3f}<br>Models={m}" for n, s, m in
              zip(top['label_short'], top['best_selectivity'], top['n_models'])],
        hoverinfo='text', showlegend=False,
    ), row=1, col=1)

    # 2. P_kill vs P_gut
    fig.add_trace(go.Scatter(
        x=top['mean_p_pathogen'], y=top['mean_p_gut'],
        mode='markers',
        marker=dict(size=top['best_selectivity'] * 15 + 5,
                    color=top['best_selectivity'], colorscale='Viridis',
                    opacity=0.7, line=dict(width=1, color='white'),
                    showscale=True, colorbar=dict(title='S', x=1.02)),
        text=[f"<b>{n}</b><br>P(kill)={pp:.3f}<br>P(gut)={pg:.3f}<br>S={s:.3f}" for
              n, pp, pg, s in zip(top['label_short'], top['mean_p_pathogen'],
                                   top['mean_p_gut'], top['best_selectivity'])],
        hoverinfo='text', showlegend=False,
    ), row=1, col=2)

    # 3. Table
    t50 = top.head(50)
    fig.add_trace(go.Table(
        header=dict(
            values=['<b>Rank</b>', '<b>Name</b>', '<b>Type</b>', '<b>Models</b>',
                    '<b>Pathogens</b>', '<b>S</b>', '<b>P(kill)</b>',
                    '<b>P(gut)</b>', '<b>MoA</b>'],
            fill_color='#1565C0', font=dict(color='white', size=11),
            align='left', height=30,
        ),
        cells=dict(
            values=[
                list(range(1, len(t50) + 1)),
                [n[:25] if n else s[:20] for n, s in zip(t50['name'], t50['smiles'])],
                ['Known AB' if v else 'Novel' for v in t50['is_known_antibiotic']],
                [f"{v}/4" for v in t50['n_models']],
                t50['pathogens'].str.replace('ecoli', 'Ec').str.replace('saureus', 'Sa')
                    .str.replace('paeruginosa', 'Pa').str.replace('mtb', 'Mtb').tolist(),
                [f"{v:.3f}" for v in t50['best_selectivity']],
                [f"{v:.3f}" for v in t50['mean_p_pathogen']],
                [f"{v:.3f}" for v in t50['mean_p_gut']],
                [m[:30] if m else '?' for m in t50['moa']],
            ],
            fill_color=[['#FFEBEE' if v else '#E3F2FD' for v in t50['is_known_antibiotic']]] * 9,
            font=dict(size=10), align='left', height=25,
        ),
    ), row=2, col=1)

    fig.update_xaxes(title_text='Number of Models Agreeing', row=1, col=1)
    fig.update_yaxes(title_text='Best Selectivity Score', row=1, col=1)
    fig.update_xaxes(title_text='P(kills pathogen)', row=1, col=2)
    fig.update_yaxes(title_text='P(harms gut)', row=1, col=2)

    fig.update_layout(
        title=dict(text='<b>Antibiotic Candidate Dashboard</b><br>'
                        '<sup>Blue = novel candidate | Red = known antibiotic</sup>',
                   font=dict(size=16)),
        width=1200, height=1200,
        template='plotly_white',
    )

    path = os.path.join(save_dir, 'candidates_master_dashboard.html')
    fig.write_html(path, include_plotlyjs='cdn')
    logger.info(f"    Master dashboard: {path}")
    return path


# ============================================================================
# MARKDOWN REPORT WRITER
# ============================================================================
def write_report(df, title, filename, is_novel, all_lists, metrics, all_plots,
                 benchmark=None, full_consensus=None):
    """Generate thorough scientific Markdown report."""
    L = []
    w = L.append

    w(f"# {title}")
    w("")
    w(f"**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    w(f"**Pipeline:** Microbiome-Sparing Antibiotic Discovery")
    w(f"**Author:** Vishakha Agrawal, Lab for Spatial Informatics, IIIT Hyderabad")
    w("")

    # ---- Executive Summary ----
    w("## Executive Summary")
    w("")
    total = len(df)
    multi = len(df[df['n_models'] >= 3])
    if is_novel:
        w(f"This report identifies **{total} non-antibiotic compounds** from the Broad Institute "
          f"Drug Repurposing Hub (~6,800 compounds) that are predicted to have selective "
          f"antimicrobial activity: high probability of killing target pathogens while "
          f"sparing beneficial gut bacteria. Of these, **{multi} compounds are supported "
          f"by 3 or more independent ML models**, providing robust computational evidence "
          f"for experimental follow-up.")
        w("")
        w("**Why drug repurposing?** These compounds already have known safety, "
          "pharmacokinetic, and toxicity profiles from their original therapeutic indications. "
          "Repurposing dramatically reduces the time and cost of bringing a new antibiotic "
          "to clinical use (estimated savings: 5-7 years and $1-2 billion per compound).")
    else:
        w(f"This report shows **{total} known antimicrobial compounds** that our ML pipeline "
          f"independently ranked highly for selective antibacterial activity. This serves "
          f"as **validation**: the pipeline correctly identifies compounds with established "
          f"antibacterial mechanisms, increasing confidence in the novel candidate predictions.")

    w("")

    # ---- Scientific Background ----
    w("---")
    w("## Scientific Background")
    w("")
    w("### The Antimicrobial Resistance Crisis")
    w("")
    w("The World Health Organization has declared antimicrobial resistance (AMR) one of the "
      "top 10 global public health threats. An estimated 1.27 million deaths were directly "
      "attributable to bacterial AMR in 2019 (Lancet, 2022), projected to reach 10 million "
      "annually by 2050 without intervention.")
    w("")
    w("### The Microbiome Collateral Damage Problem")
    w("")
    w("Most antibiotics in clinical use are broad-spectrum: they kill target pathogens but "
      "also devastate the gut microbiome. This causes:")
    w("")
    w("- **Clostridioides difficile infection (CDI):** The leading cause of "
      "hospital-acquired diarrhea, directly linked to antibiotic-induced microbiome disruption.")
    w("- **Resistance amplification:** Antibiotic-depleted gut niches are colonized by "
      "resistant organisms, creating reservoirs for horizontal gene transfer.")
    w("- **Metabolic disruption:** Gut bacteria produce essential vitamins (K, B12), "
      "short-chain fatty acids, and neurotransmitter precursors. Disruption affects "
      "systemic health.")
    w("- **Immune dysregulation:** 70-80% of immune cells reside in the gut. Microbiome "
      "disruption impairs immune homeostasis.")
    w("")
    w("Maier et al. (Nature, 2018) screened 1,197 marketed drugs against 40 representative "
      "human gut bacterial strains and found that 24% of non-antibiotic drugs also inhibited "
      "gut bacteria, underscoring the widespread extent of collateral microbiome damage.")
    w("")

    w("### Selectivity Score: The Core Metric")
    w("")
    w("```")
    w("S = P_pathogen x (1 - P_gut)")
    w("```")
    w("")
    w("| Component | Range | Meaning | Ideal Value |")
    w("|-----------|-------|---------|-------------|")
    w("| P_pathogen | 0-1 | Probability that the compound inhibits the target pathogen at therapeutic concentrations. Trained on ChEMBL MIC data (IC50/MIC below 10 uM). | Near 1.0 |")
    w("| P_gut | 0-1 | Probability that the compound inhibits gut commensal bacteria. Trained on Maier et al. (Nature, 2018/2021) growth inhibition data across 40 strains. | Near 0.0 |")
    w("| S | 0-1 | Combined selectivity. S = 1.0 would be a perfect microbiome-sparing antibiotic. In practice, S > 0.5 is a strong lead; S > 0.7 is exceptional. | Near 1.0 |")
    w("")

    w("### Gut Harm Thresholds (t5, t10, t20)")
    w("")
    w("The Maier et al. studies measured the number of gut strains inhibited (n_hit out of 40). "
      "We train separate gut harm classifiers at three thresholds:")
    w("")
    w("| Threshold | Binary Label | Clinical Interpretation |")
    w("|-----------|-------------|------------------------|")
    w("| **t5** | n_hit >= 5 out of 40 | Mild gut disruption. Even narrow-spectrum antibiotics may hit 5 strains. Lenient threshold. |")
    w("| **t10** | n_hit >= 10 out of 40 | Moderate disruption. Our **default** threshold. Clinically meaningful: 25% of gut flora affected. |")
    w("| **t20** | n_hit >= 20 out of 40 | Severe disruption. Comparable to broad-spectrum antibiotics. Strict threshold. |")
    w("")

    # ---- Target Pathogens ----
    w("---")
    w("## Target Pathogens")
    w("")
    for pk, pinfo in PATHOGEN_SCIENCE.items():
        w(f"### {pinfo['full_name']} ({pinfo['short']})")
        w("")
        w(f"- **Gram stain:** {pinfo['gram']}")
        w(f"- **WHO Priority (BPPL {pinfo['who_year']}):** {pinfo['who_priority']}")
        w(f"- **Key diseases:** {pinfo['diseases']}")
        w(f"- **Resistance landscape:** {pinfo['resistance']}")
        w(f"- **Current treatment:** {pinfo['current_treatment']}")
        w(f"- **Microbiome concern:** {pinfo['microbiome_concern']}")
        w("")

        # Add WHO burden data if available
        burden = WHO_BURDEN.get(pk, {})
        if burden:
            w(f"- **WHO BPPL 2024 Category:** {burden.get('who_bppl_category', 'N/A')}")
            if 'who_bppl_score_pct' in burden:
                w(f"- **WHO BPPL 2024 Score:** {burden['who_bppl_score_pct']}%")
            w(f"- **Resistance phenotype (BPPL):** {burden.get('who_bppl_resistance', 'N/A')}")
            if 'cdc_cases_per_year' in burden:
                w(f"- **CDC US burden:** {burden['cdc_cases_per_year']:,} cases/year, "
                  f"{burden['cdc_deaths_per_year']:,} deaths/year")
            if 'global_burden_note' in burden:
                w(f"- **Global burden:** {burden['global_burden_note']}")
            w("")

    # ---- Regulatory & Clinical Standards ----
    w("---")
    w("## Regulatory and Clinical Standards for Antibiotic Development")
    w("")
    w("The following quantitative standards from regulatory bodies define what "
      "constitutes a viable antibiotic candidate and provide context for "
      "interpreting our computational predictions.")
    w("")

    w("### CLSI MIC Breakpoints (M100 Ed35, 2025)")
    w("")
    w("The Clinical and Laboratory Standards Institute (CLSI) defines MIC "
      "breakpoints (in ug/mL) that classify bacteria as susceptible (S), "
      "intermediate (I), or resistant (R) to specific antibiotics. These are "
      "the gold standard used by FDA and clinical laboratories worldwide.")
    w("")
    w("Reference: CLSI. Performance Standards for Antimicrobial Susceptibility "
      "Testing. 35th ed. CLSI Supplement M100. 2025.")
    w("")

    for pk, pinfo in PATHOGEN_SCIENCE.items():
        breakpoints = CLSI_BREAKPOINTS.get(pk, [])
        if not breakpoints:
            continue
        w(f"**{pinfo['full_name']}:**")
        w("")
        w("| Antibiotic | S (ug/mL) | I (ug/mL) | R (ug/mL) |")
        w("|------------|-----------|-----------|-----------|")
        for drug, s, i, r in breakpoints:
            s_str = f"<= {s}" if s else "--"
            i_str = str(i) if i else "--"
            r_str = f">= {r}" if r else "--"
            w(f"| {drug} | {s_str} | {i_str} | {r_str} |")
        w("")

    w("**Relevance to our pipeline:** Our models predict binary activity "
      "(active/inactive) at a fixed MIC threshold of 10 uM (~3-5 ug/mL for "
      "typical small molecules). Candidates with high P(kill) scores are "
      "predicted to inhibit growth at concentrations in the range of CLSI "
      "susceptible breakpoints for many drug-pathogen combinations.")
    w("")

    w("### Selectivity Index (SI)")
    w("")
    w("The Selectivity Index quantifies the safety margin between antimicrobial "
      "potency and human/commensal toxicity:")
    w("")
    w("```")
    w("SI = CC50 (human cells) / MIC (pathogen)")
    w("```")
    w("")
    w("| SI Value | Clinical Interpretation |")
    w("|----------|------------------------|")
    w("| SI < 1 | NOT viable: toxic at therapeutic dose |")
    w("| SI 1-10 | Narrow therapeutic window (problematic for systemic use) |")
    w("| SI 10-100 | Promising (typical range for approved antibiotics) |")
    w("| SI > 100 | Exceptional selectivity (ideal for systemic therapy) |")
    w("")
    w("Our selectivity score S = P_pathogen x (1 - P_gut) is a computational "
      "analog. High S correlates with compounds that have high predicted "
      "antimicrobial potency (low MIC against pathogen) and low predicted "
      "collateral damage (high MIC against gut commensals), consistent with "
      "a favorable Selectivity Index.")
    w("")

    w("### PK/PD Targets (FDA/EMA Guidelines)")
    w("")
    w("The FDA and EMA require pharmacokinetic/pharmacodynamic (PK/PD) target "
      "attainment analysis for new antibiotic applications. The relevant PK/PD "
      "index depends on the drug's killing mechanism:")
    w("")
    w("| Killing Pattern | PK/PD Index | Target | Drug Classes |")
    w("|----------------|-------------|--------|-------------|")
    for key, info in PKPD_TARGETS.items():
        w(f"| {key.replace('_', '-').title()} | {info['index']} | "
          f"{info['target']} | {info['drug_classes']} |")
    w("")
    w("Reference: FDA. Microbiology Data for Systemic Antibacterial Drugs (2018). "
      "EMA/CHMP/594085/2015.")
    w("")

    w("### Published ML Benchmark Thresholds")
    w("")
    w("Our candidates can be contextualized against operational thresholds "
      "from the two most successful ML-guided antibiotic discovery campaigns:")
    w("")
    for key, info in PUBLISHED_ML_THRESHOLDS.items():
        w(f"**{info['paper']}:**")
        w(f"- Model: {info['model']}")
        w(f"- Training: {info['training_size']:,} compounds ({info['positive_rate']*100:.1f}% positive)")
        w(f"- Screening: {info['screening_library']}")
        if 'hit_rate_top99' in info:
            w(f"- Validation: {info['hit_rate_top99']*100:.0f}% hit rate in top 99 predictions")
        if 'activity_threshold_mcule' in info:
            w(f"- Activity threshold: > {info['activity_threshold_mcule']} (Mcule), > {info['activity_threshold_broad']} (Broad)")
            w(f"- Cytotoxicity filter: < {info['cytotox_threshold']}")
        w("")

    # ---- Models ----
    w("---")
    w("## ML Models Used")
    w("")
    for mk, minfo in MODEL_SCIENCE.items():
        w(f"### {minfo['name']} ({minfo['year']})")
        w("")
        w(f"- **Architecture:** {minfo['architecture']}")
        w(f"- **Training:** {minfo['training']}")
        w(f"- **Strengths:** {minfo['strengths']}")
        w(f"- **Limitations:** {minfo['limitations']}")
        w(f"- **Reference:** {minfo['reference']}")
        w("")

    # ---- Performance ----
    w("---")
    w("## Model Performance (5-Fold Scaffold Cross-Validation)")
    w("")
    w("ROC-AUC: 1.0 = perfect discrimination, 0.5 = random. Scaffold-based CV ensures "
      "that structurally similar molecules are not split across train/test, providing a "
      "realistic estimate of generalization to novel chemical scaffolds.")
    w("")
    header = "| Task |"
    sep = "|------|"
    for p in sorted(metrics.keys()):
        header += f" {MODEL_SCIENCE.get(p,{}).get('name',p)} |"
        sep += "------|"
    w(header)
    w(sep)
    for task in ['ecoli', 'saureus', 'paeruginosa', 'mtb', 'gut_t5', 'gut_t10', 'gut_t20']:
        if 'gut' in task:
            label = task.replace('gut_t', 'Gut harm (t=') + ')'
        else:
            label = PATHOGEN_SCIENCE.get(task, {}).get('full_name', task)
        row = f"| {label} |"
        for p in sorted(metrics.keys()):
            roc = metrics[p].get(task, {}).get('mean_roc_auc')
            pr = metrics[p].get(task, {}).get('mean_pr_auc')
            if roc is not None:
                row += f" {roc:.3f}"
                if pr is not None:
                    row += f" (PR: {pr:.3f})"
                row += " |"
            else:
                row += " -- |"
        w(row)
    w("")

    # ---- Candidates ----
    w("---")
    tag = "Novel Repurposing" if is_novel else "Known Antibiotic"
    w(f"## {tag} Candidates by Pathogen")
    w("")

    for pk, pinfo in PATHOGEN_SCIENCE.items():
        sub = df[df['pathogens'].str.contains(pk)]
        if len(sub) == 0:
            continue
        top20 = sub.head(20)

        w(f"### {pinfo['full_name']} ({pinfo['short']})")
        w(f"**WHO Priority: {pinfo['who_priority']}** | "
          f"Candidates found: {len(sub)} | "
          f"Multi-model consensus (3+): {len(sub[sub['n_models'] >= 3])}")
        w("")
        w("| # | Compound | Models | S (best) | P(kill) | P(gut) | Mechanism of Action | Clinical Phase | Original Indication |")
        w("|---|----------|--------|----------|---------|--------|---------------------|----------------|---------------------|")

        for i, (_, row) in enumerate(top20.iterrows(), 1):
            name = row['name'][:28] if row['name'] else row['smiles'][:22]
            moa = row['moa'][:40] if row['moa'] else 'Unknown'
            phase = row['clinical_phase'][:12] if row['clinical_phase'] else '--'
            disease = row['disease_area'][:25] if row['disease_area'] else '--'
            w(f"| {i} | **{name}** | {row['n_models']}/4 | "
              f"{row['best_selectivity']:.3f} | {row['mean_p_pathogen']:.2f} | "
              f"{row['mean_p_gut']:.2f} | {moa} | {phase} | {disease} |")
        w("")

        # Scientific interpretation for top novel candidate
        if is_novel and len(top20) > 0:
            best = top20.iloc[0]
            bname = best['name'] if best['name'] else 'Top compound'
            bmoa = best['moa'] if best['moa'] else 'an unknown mechanism'
            w(f"**Scientific note on {bname}:** This compound, originally developed for "
              f"{best['disease_area'] if best['disease_area'] else 'another therapeutic area'}, "
              f"acts via {bmoa}. "
              f"Our models predict a {best['mean_p_pathogen']*100:.0f}% probability of "
              f"inhibiting {pinfo['short']} at therapeutic concentrations, with only a "
              f"{best['mean_p_gut']*100:.0f}% probability of collateral gut damage. "
              f"The selectivity score of {best['best_selectivity']:.3f} places it in the "
              f"{'top tier (S > 0.7)' if best['best_selectivity'] > 0.7 else 'promising range (S > 0.5)' if best['best_selectivity'] > 0.5 else 'moderate range'}. "
              f"Critically, {best['n_models']} of 4 independent ML architectures "
              f"(spanning classical ML to 2026 foundation models) agree on this ranking, "
              f"providing cross-architectural validation.")
            w("")

    # ---- Benchmark: Novel vs Known ----
    if is_novel and benchmark is not None and full_consensus is not None:
        w("---")
        w("## Benchmark: How Do Novel Candidates Compare to Known Antibiotics?")
        w("")
        w("The most important question for any novel candidate: **does it score as well "
          "as drugs we already know work?** Below, we compare the selectivity scores of "
          "novel candidates against known antibiotics from the same screening run. If a "
          "compound developed for oncology or cardiology scores higher than established "
          "antibiotics like ciprofloxacin or vancomycin, it provides strong computational "
          "evidence that its antibacterial selectivity deserves experimental validation.")
        w("")

        known_df = full_consensus[full_consensus['is_known_antibiotic'] == True]
        novel_df = full_consensus[full_consensus['is_known_antibiotic'] == False]

        if len(known_df) > 0 and len(novel_df) > 0:
            k_med = known_df['best_selectivity'].median()
            k_max = known_df['best_selectivity'].max()
            k_mean = known_df['best_selectivity'].mean()
            n_above_med = int((novel_df['best_selectivity'] > k_med).sum())
            n_above_best = int((novel_df['best_selectivity'] > k_max).sum())

            w("### Overall Comparison (All Pathogens Combined)")
            w("")
            w("| Metric | Known Antibiotics | Novel Candidates |")
            w("|--------|-------------------|------------------|")
            w(f"| Total compounds in consensus | {len(known_df)} | {len(novel_df)} |")
            w(f"| Mean selectivity | {k_mean:.3f} | {novel_df['best_selectivity'].mean():.3f} |")
            w(f"| Median selectivity | {k_med:.3f} | {novel_df['best_selectivity'].median():.3f} |")
            w(f"| Best selectivity | {k_max:.3f} | {novel_df['best_selectivity'].max():.3f} |")
            w(f"| Mean P(kill pathogen) | {known_df['mean_p_pathogen'].mean():.3f} | {novel_df['mean_p_pathogen'].mean():.3f} |")
            w(f"| Mean P(gut harm) | {known_df['mean_p_gut'].mean():.3f} | {novel_df['mean_p_gut'].mean():.3f} |")
            w(f"| 3+ model consensus | {len(known_df[known_df['n_models'] >= 3])} | {len(novel_df[novel_df['n_models'] >= 3])} |")
            w("")

            w(f"**Key finding:** **{n_above_med} novel candidates** score above the median "
              f"known antibiotic selectivity ({k_med:.3f}), and **{n_above_best} novel "
              f"candidates** outscore even the best known antibiotic ({k_max:.3f}). This "
              f"means our pipeline identifies non-antibiotic compounds with predicted "
              f"selectivity profiles competitive with or superior to established drugs.")
            w("")

            # Per-pathogen benchmark
            w("### Per-Pathogen Benchmark")
            w("")
            for pk, pinfo in PATHOGEN_SCIENCE.items():
                pk_bench = benchmark.get(pk, {}).get('lists', {})
                if not pk_bench:
                    continue

                w(f"#### {pinfo['full_name']} ({pinfo['short']})")
                w("")

                for pipeline, pdata in pk_bench.items():
                    ks = pdata['known_stats']
                    ns = pdata['novel_stats']
                    if ks['count'] == 0 and ns['count'] == 0:
                        continue

                    mname = MODEL_SCIENCE.get(pipeline, {}).get('name', pipeline)
                    w(f"**{mname}** (top 300 from Repurposing Hub, t10 threshold):")
                    w("")
                    w("| | Known Antibiotics | Novel Candidates |")
                    w("|---|---|---|")
                    w(f"| Count | {ks['count']} | {ns['count']} |")
                    w(f"| Mean S | {ks['mean_S']:.3f} | {ns['mean_S']:.3f} |")
                    w(f"| Median S | {ks['median_S']:.3f} | {ns['median_S']:.3f} |")
                    w(f"| Best S | {ks['max_S']:.3f} | {ns['max_S']:.3f} |")
                    w(f"| IQR (25th-75th) | {ks['p25_S']:.3f} - {ks['p75_S']:.3f} | {ns['p25_S']:.3f} - {ns['p75_S']:.3f} |")
                    w(f"| Mean P(kill) | {ks['mean_p_path']:.3f} | {ns['mean_p_path']:.3f} |")
                    w(f"| Mean P(gut harm) | {ks['mean_p_gut']:.3f} | {ns['mean_p_gut']:.3f} |")
                    w(f"| **Novels above known median** | -- | **{pdata['n_novel_above_median_known']}** |")
                    w(f"| **Novels above best known** | -- | **{pdata['n_novel_above_best_known']}** |")
                    w("")

                    # Name the top known antibiotics for context
                    if ks['top5']:
                        w(f"Top known antibiotics (reference): "
                          + ", ".join(f"{nm} (S={s:.3f})" for nm, s, _, _ in ks['top5']))
                        w("")

                    # Highlight outperforming novels
                    if ns['top5'] and ks['median_S'] > 0:
                        outperformers = [(nm, s) for nm, s, _, _ in ns['top5'] if s > ks['median_S']]
                        if outperformers:
                            w(f"**Novel candidates outscoring known median ({ks['median_S']:.3f}):** "
                              + ", ".join(f"**{nm}** (S={s:.3f})" for nm, s in outperformers))
                            w("")

            # Interpretation
            w("### What This Benchmark Means for Real-World Performance")
            w("")
            w("The selectivity score benchmarks above provide a **computational analog** "
              "of experimental performance expectations:")
            w("")
            w("1. **Compounds scoring near known antibiotics** are predicted to have "
              "similar pathogen-killing potency AND similar (or better) gut safety. "
              "Since known antibiotics in this list have confirmed in vitro activity, "
              "a novel candidate with comparable scores is a strong lead for wet-lab testing.")
            w("")
            w("2. **Compounds scoring above known antibiotics** may represent "
              "**truly selective** agents: drugs that kill pathogens at least as well as "
              "existing antibiotics but with substantially less gut microbiome damage. "
              "These are the highest-priority candidates for the drug repurposing pipeline.")
            w("")
            w("3. **Caveats on benchmarking:** Known antibiotics in the Hub are labeled "
              "based on mechanism-of-action metadata, not on our model's predictions. A known "
              "antibiotic may score low if it is broad-spectrum (high P_gut) or if it targets "
              "a different pathogen than the one being screened. Conversely, a novel candidate "
              "scoring high does not guarantee in vivo efficacy, but it does mean the model "
              "identifies structural features associated with selective activity.")
            w("")

    # ---- External Benchmark (Stokes/Wong) ----
    if is_novel:
        ext_path = os.path.join(config.RESULTS_DIR, 'external_benchmark_merged.csv')
        if os.path.exists(ext_path):
            ext_df = pd.read_csv(ext_path)
            ext_cols = [c for c in ext_df.columns if 'stokes_' in c or 'wong_' in c]
            if ext_cols:
                w("---")
                w("## External Validation: Published Antibiotic Discovery Models")
                w("")
                w("To assess real-world potential, we scored our candidates against "
                  "pretrained models from two landmark antibiotic discovery papers:")
                w("")
                if any('stokes' in c for c in ext_cols):
                    w("- **Stokes et al. (Cell, 2020):** The model that discovered halicin. "
                      "Trained on 2,335 compounds screened for E. coli growth inhibition. "
                      "Ensemble of 20 D-MPNN models with RDKit features. "
                      "(Zenodo DOI: 10.5281/zenodo.6527883)")
                if any('wong' in c for c in ext_cols):
                    w("- **Wong et al. (Nature, 2023):** The model that discovered abaucin. "
                      "Trained on 39,312 compounds for antibiotic activity and cytotoxicity. "
                      "(Zenodo DOI: 10.5281/zenodo.10095879)")
                w("")
                w("A high score from these external models means an independent model, "
                  "trained on different data in a different lab, also predicts the compound "
                  "has antibacterial activity. This is the strongest computational "
                  "validation available.")
                w("")

                # Show top candidates with external scores
                novel_ext = ext_df[ext_df.get('is_known_antibiotic', True) == False].copy()
                if len(novel_ext) > 0 and 'best_selectivity' in novel_ext.columns:
                    for col in ext_cols:
                        novel_ext_valid = novel_ext.dropna(subset=[col])
                        if len(novel_ext_valid) == 0:
                            continue
                        top = novel_ext_valid.nlargest(10, col)
                        col_label = col.replace('_', ' ').replace('score', '').strip().title()
                        w(f"### Top Novels by {col_label}")
                        w("")
                        w("| # | Name | Our S | External Score | Models | MoA |")
                        w("|---|------|-------|----------------|--------|-----|")
                        for i, (_, row) in enumerate(top.iterrows(), 1):
                            nm = str(row.get('name', ''))[:25] or str(row.get('smiles', ''))[:20]
                            our_s = row.get('best_selectivity', 0)
                            ext_s = row.get(col, 0)
                            n_m = row.get('n_models', 0)
                            moa = str(row.get('moa', ''))[:30] or '?'
                            w(f"| {i} | **{nm}** | {our_s:.3f} | {ext_s:.3f} | {n_m}/4 | {moa} |")
                        w("")

                    # Correlation summary
                    if 'best_selectivity' in novel_ext.columns:
                        w("### Correlation Between Our Pipeline and External Models")
                        w("")
                        for col in ext_cols:
                            valid = novel_ext.dropna(subset=[col, 'best_selectivity'])
                            if len(valid) > 10:
                                corr = valid[['best_selectivity', col]].corr().iloc[0, 1]
                                w(f"- Our selectivity vs {col.replace('_', ' ')}: "
                                  f"Pearson r = {corr:.3f} (n = {len(valid)})")
                        w("")

    # ---- Interactive Visualizations ----
    w("---")
    w("## Interactive Visualizations")
    w("")
    w("The following HTML files are generated alongside this report. Open them "
      "in any browser for interactive exploration (zoom, hover, rotate):")
    w("")
    for p in sorted(all_plots):
        if p:
            w(f"- `{os.path.basename(p)}`")
    w("")

    # ---- Interpretation ----
    w("---")
    w("## How to Read These Results")
    w("")
    w("### Candidate Tiers")
    w("")
    w("| Tier | Criteria | Confidence | Recommended Action |")
    w("|------|----------|------------|-------------------|")
    w("| **Tier 1** | S > 0.7, 4/4 models agree | Very High | Priority experimental validation (MIC + gut panel) |")
    w("| **Tier 2** | S > 0.5, 3/4 models agree | High | Include in screening campaign |")
    w("| **Tier 3** | S > 0.5, 2/4 models agree | Moderate | Test if structurally distinct from Tier 1-2 |")
    w("| **Tier 4** | S > 0.3, 1 model only | Low | Reserve for scaffold diversity analysis |")
    w("")
    w("### What Cross-Model Consensus Means")
    w("")
    w("When four completely different ML architectures (fingerprint-based Random Forest, "
      "graph neural network D-MPNN, foundation model CheMeleon, and transformer MoLFormer) "
      "independently rank the same compound highly, this means:")
    w("")
    w("1. The signal is **not an artifact** of one particular molecular representation")
    w("2. The prediction is **robust to architectural choices**")
    w("3. The underlying structure-activity relationship is **strong enough** to be detected "
      "by fundamentally different learning algorithms")
    w("")
    w("This is analogous to obtaining consistent results across independent experimental "
      "replicates: each model is a different \"measurement instrument\" for the same "
      "underlying biological activity.")
    w("")

    # ---- Caveats ----
    w("### Important Caveats")
    w("")
    w("1. **Computational predictions only.** Every candidate requires wet-lab validation "
      "(minimum inhibitory concentration assays, gut bacteria growth inhibition panels).")
    w("2. **Binary activity models.** Our classifiers predict active/inactive at a fixed "
      "MIC threshold. They do not predict concentration-dependent selectivity windows.")
    w("3. **In vitro data.** Both ChEMBL MIC data and Maier gut inhibition data are "
      "in vitro. In vivo pharmacokinetics (absorption, distribution, metabolism, excretion) "
      "will modulate actual selectivity.")
    w("4. **Scaffold bias.** Models perform best on scaffolds similar to training data. "
      "Novel scaffolds in the Hub may have less reliable predictions.")
    w("5. **Resistance potential.** These predictions do not account for resistance "
      "emergence rates or mechanisms.")
    w("")

    # ---- Recommended validation ----
    w("### Recommended Experimental Validation Protocol")
    w("")
    w("1. **MIC determination:** Measure minimum inhibitory concentration against target "
      "pathogen (CLSI broth microdilution, EUCAST guidelines)")
    w("2. **Gut bacteria panel:** Test against 10-40 representative commensal strains "
      "(replicating the Maier et al. protocol)")
    w("3. **Selectivity index:** Calculate SI = MIC_gut / MIC_pathogen. SI > 10 is "
      "promising; SI > 100 is exceptional.")
    w("4. **Cytotoxicity:** Test against mammalian cell lines (HEK293, HepG2) to "
      "confirm therapeutic window")
    w("5. **Mechanism investigation:** For novel candidates without known antibacterial "
      "MoA, use resistance evolution + whole-genome sequencing to identify targets")
    w("")

    w("---")
    w(f"*Microbiome-Sparing Antibiotic Discovery Pipeline | "
      f"{datetime.now().strftime('%Y-%m-%d')} | IIIT Hyderabad*")

    report_path = os.path.join(config.RESULTS_DIR, filename)
    with open(report_path, 'w') as f:
        f.write("\n".join(L))
    logger.info(f"  Report written: {report_path}")


# ============================================================================
# CONSENSUS PROPERTY CHARACTERIZATION (additive: new outputs only)
# ============================================================================
def characterize_consensus_properties(consensus_df):
    """Compute molecular properties for consensus candidates by consensus tier.

    Does NOT modify consensus_df. Writes two NEW files:
      - candidate_consensus_properties.csv (per-compound properties)
      - candidate_properties_summary.json  (tier-level statistics + Lipinski)
    """
    try:
        from rdkit import Chem
        from rdkit.Chem import Descriptors, Lipinski, rdMolDescriptors
    except ImportError:
        logger.warning("  RDKit not available; skipping property characterization")
        return None

    logger.info("\n" + "=" * 70)
    logger.info("  CONSENSUS CANDIDATE PROPERTY CHARACTERIZATION")
    logger.info("=" * 70)

    rows = []
    for _, row in consensus_df.iterrows():
        mol = Chem.MolFromSmiles(str(row['smiles']))
        if mol is None:
            continue
        mw = Descriptors.MolWt(mol)
        logp = Descriptors.MolLogP(mol)
        tpsa = Descriptors.TPSA(mol)
        hbd = Lipinski.NumHDonors(mol)
        hba = Lipinski.NumHAcceptors(mol)
        rot = Lipinski.NumRotatableBonds(mol)
        rings = rdMolDescriptors.CalcNumRings(mol)
        # Lipinski Rule of 5 violation count (Lipinski 1997)
        viol = int(mw > 500) + int(logp > 5) + int(hbd > 5) + int(hba > 10)
        rows.append({
            'smiles': row['smiles'],
            'name': row.get('name', ''),
            'n_models': row['n_models'],
            'is_known_antibiotic': row.get('is_known_antibiotic', False),
            'best_selectivity': row['best_selectivity'],
            'MW': round(mw, 2),
            'LogP': round(logp, 3),
            'TPSA': round(tpsa, 2),
            'HBD': hbd,
            'HBA': hba,
            'RotBonds': rot,
            'Rings': rings,
            'lipinski_violations': viol,
            'lipinski_pass': viol <= 1,
        })

    props_df = pd.DataFrame(rows)
    if len(props_df) == 0:
        logger.warning("  No valid RDKit-parseable compounds; skipping")
        return None

    # Save per-compound properties (NEW file, does not overlap)
    out_csv = os.path.join(config.RESULTS_DIR, 'candidate_consensus_properties.csv')
    props_df.to_csv(out_csv, index=False)
    logger.info(f"  Saved: {out_csv}")

    # Tier-level summary statistics
    summary = {}
    for tier_min, label in [(1, 'all'), (2, 'tier_2plus'),
                            (3, 'tier_3plus'), (4, 'tier_4plus'),
                            (5, 'tier_5')]:
        sub = props_df[props_df['n_models'] >= tier_min]
        if len(sub) == 0:
            continue
        n_ab = int(sub['is_known_antibiotic'].sum())
        tier_stats = {
            'n_total': len(sub),
            'n_known_antibiotic': n_ab,
            'n_novel': len(sub) - n_ab,
            'pct_antibiotic': round(100 * n_ab / len(sub), 2),
            'lipinski_pass_count': int(sub['lipinski_pass'].sum()),
            'lipinski_pass_pct': round(100 * sub['lipinski_pass'].mean(), 2),
        }
        for prop in ['MW', 'LogP', 'TPSA', 'HBD', 'HBA', 'RotBonds', 'Rings']:
            vals = sub[prop].dropna()
            if len(vals) > 0:
                tier_stats[prop] = {
                    'mean': round(float(vals.mean()), 3),
                    'median': round(float(vals.median()), 3),
                    'std': round(float(vals.std()), 3) if len(vals) > 1 else 0.0,
                    'min': round(float(vals.min()), 3),
                    'max': round(float(vals.max()), 3),
                }
        summary[label] = tier_stats

        logger.info(f"  {label:15s} (n>={tier_min}): {len(sub):4d} compounds, "
                    f"antibiotics={n_ab}/{len(sub)} ({tier_stats['pct_antibiotic']}%), "
                    f"Lipinski-compliant={tier_stats['lipinski_pass_count']} "
                    f"({tier_stats['lipinski_pass_pct']}%)")

    # Save summary JSON (NEW file, does not overlap)
    out_json = os.path.join(config.RESULTS_DIR, 'candidate_properties_summary.json')
    with open(out_json, 'w') as f:
        json.dump(summary, f, indent=2, default=str)
    logger.info(f"  Saved: {out_json}")

    return props_df


# ============================================================================
# MAIN
# ============================================================================
def main():
    logger.info("=" * 70)
    logger.info("  CANDIDATE REPORT GENERATION (Scientific + Interactive HTML)")
    logger.info("=" * 70)

    os.makedirs(config.FIGURES_DIR, exist_ok=True)

    # Load data
    all_lists = load_all_screening_lists()
    logger.info(f"  Loaded {len(all_lists)} screening lists")
    if not all_lists:
        logger.error("  No screening lists found. Run 07_evaluate.py first.")
        return

    metrics = {}
    for p in ['rf', 'dmpnn', 'chemeleon_frozen', 'molformer', 'dmpnn_rdkit']:
        path = os.path.join(config.RESULTS_DIR, f'{p}_cv_metrics.json')
        if os.path.exists(path):
            with open(path) as f:
                metrics[p] = json.load(f)

    # Build consensus
    consensus = build_consensus(all_lists, top_n=TOP_N)
    logger.info(f"  Total unique compounds in consensus: {len(consensus)}")

    known = consensus[consensus['is_known_antibiotic'] == True].copy().reset_index(drop=True)
    novel = consensus[consensus['is_known_antibiotic'] == False].copy().reset_index(drop=True)
    logger.info(f"  Known antibiotics rediscovered: {len(known)}")
    logger.info(f"  Novel repurposing candidates: {len(novel)}")
    logger.info(f"  Multi-model consensus (3+): {len(consensus[consensus['n_models'] >= 3])}")
    logger.info(f"  Multi-model consensus (4/4): {len(consensus[consensus['n_models'] >= 4])}")

    # Save CSVs
    consensus.to_csv(os.path.join(config.RESULTS_DIR, 'candidate_consensus.csv'), index=False)
    known.to_csv(os.path.join(config.RESULTS_DIR, 'candidate_known_antibiotics.csv'), index=False)
    novel.to_csv(os.path.join(config.RESULTS_DIR, 'candidate_novel_discoveries.csv'), index=False)
    consensus.head(100).to_csv(os.path.join(config.RESULTS_DIR, 'candidate_detailed_top100.csv'), index=False)

    # Property characterization (additive: new files only, does not modify consensus)
    characterize_consensus_properties(consensus)

    # ---- Generate Interactive HTML Visualizations ----
    logger.info("\n  Generating interactive HTML visualizations...")
    all_plots = []

    # Build benchmark data (novel vs known comparison)
    benchmark = build_benchmark_data(all_lists, consensus)
    for pk in ['ecoli', 'saureus', 'paeruginosa', 'mtb']:
        pk_b = benchmark.get(pk, {}).get('lists', {})
        for pipeline, pdata in pk_b.items():
            ks = pdata['known_stats']
            ns = pdata['novel_stats']
            if ks['count'] > 0 or ns['count'] > 0:
                logger.info(f"    Benchmark {pk}/{pipeline}: "
                            f"known={ks['count']} (median S={ks['median_S']:.3f}), "
                            f"novel={ns['count']} (median S={ns['median_S']:.3f}), "
                            f"novels>known_median={pdata['n_novel_above_median_known']}, "
                            f"novels>known_best={pdata['n_novel_above_best_known']}")

    # Benchmark comparison HTML
    try:
        paths = make_benchmark_html(benchmark, consensus, config.FIGURES_DIR)
        if paths:
            all_plots.extend(paths)
    except Exception as e:
        logger.warning(f"    Benchmark HTML failed: {e}")

    # 3D and 2D per pathogen (use t10 screening lists)
    for key, df_list in all_lists.items():
        pipeline, pathogen, threshold = parse_list_key(key)
        if pipeline is None or threshold != 10:
            continue
        try:
            p = make_3d_landscape(df_list, pathogen, pipeline, config.FIGURES_DIR)
            all_plots.append(p)
        except Exception as e:
            logger.warning(f"    3D failed {key}: {e}")
        try:
            p = make_2d_scatter(df_list, pathogen, pipeline, config.FIGURES_DIR)
            all_plots.append(p)
        except Exception as e:
            logger.warning(f"    2D failed {key}: {e}")

    # Consensus heatmap
    try:
        p = make_consensus_heatmap(consensus, config.FIGURES_DIR)
        all_plots.append(p)
    except Exception as e:
        logger.warning(f"    Heatmap failed: {e}")

    # Known vs Novel
    try:
        p = make_known_vs_novel(consensus, config.FIGURES_DIR)
        all_plots.append(p)
    except Exception as e:
        logger.warning(f"    Known vs Novel failed: {e}")

    # Radar chart
    try:
        p = make_radar_top(consensus, config.FIGURES_DIR, n=20)
        all_plots.append(p)
    except Exception as e:
        logger.warning(f"    Radar failed: {e}")

    # Master dashboard
    try:
        p = make_master_dashboard(consensus, all_lists, config.FIGURES_DIR)
        all_plots.append(p)
    except Exception as e:
        logger.warning(f"    Dashboard failed: {e}")

    all_plots = [p for p in all_plots if p]

    # ---- Generate Markdown Reports ----
    logger.info("\n  Writing Markdown reports...")
    write_report(known, "Known Antibiotics Rediscovered by ML Pipeline",
                 "report_known_antibiotics.md", is_novel=False,
                 all_lists=all_lists, metrics=metrics, all_plots=all_plots,
                 benchmark=benchmark, full_consensus=consensus)
    write_report(novel,
                 "Novel Antibiotic Candidates: Compounds the Field May Have Missed",
                 "report_novel_candidates.md", is_novel=True,
                 all_lists=all_lists, metrics=metrics, all_plots=all_plots,
                 benchmark=benchmark, full_consensus=consensus)

    # ---- Console summary ----
    logger.info("\n" + "=" * 70)
    logger.info("  TOP NOVEL CANDIDATES (potential new antibiotics)")
    logger.info("=" * 70)
    for i, (_, row) in enumerate(novel.head(15).iterrows(), 1):
        name = row['name'] if row['name'] else row['smiles'][:30]
        logger.info(f"  {i:2d}. {name:30s} S={row['best_selectivity']:.3f} "
                     f"models={row['n_models']}/5  [{row['pathogens']}]  "
                     f"MoA: {(row['moa'] or '?')[:30]}")

    logger.info("\n  KNOWN ANTIBIOTICS REDISCOVERED (pipeline validation)")
    logger.info("-" * 70)
    for i, (_, row) in enumerate(known.head(10).iterrows(), 1):
        name = row['name'] if row['name'] else row['smiles'][:30]
        logger.info(f"  {i:2d}. {name:30s} S={row['best_selectivity']:.3f} "
                     f"models={row['n_models']}/5  MoA: {(row['moa'] or '?')[:30]}")

    logger.info("\n" + "=" * 70)
    logger.info(f"  FILES GENERATED:")
    logger.info(f"    Reports:  report_known_antibiotics.md, report_novel_candidates.md")
    logger.info(f"    CSVs:     candidate_consensus.csv, candidate_known_antibiotics.csv")
    logger.info(f"              candidate_novel_discoveries.csv, candidate_detailed_top100.csv")
    logger.info(f"    HTML viz: {len(all_plots)} interactive plots in {config.FIGURES_DIR}")
    logger.info("=" * 70)


# ============================================================================
# UNIT TESTS
# ============================================================================
def run_tests():
    print("Running Phase 6 (Candidate Report) unit tests...")
    passed, failed = 0, 0
    def _assert(cond, msg):
        nonlocal passed, failed
        if cond: print(f"  [PASS] {msg}"); passed += 1
        else: print(f"  [FAIL] {msg}"); failed += 1

    # parse_list_key
    p, pa, t = parse_list_key('rf_ranked_ecoli_t10')
    _assert(p == 'rf' and pa == 'ecoli' and t == 10, "parse rf_ranked_ecoli_t10")
    p, pa, t = parse_list_key('chemeleon_ranked_saureus_t20')
    _assert(p == 'chemeleon' and pa == 'saureus' and t == 20, "parse chemeleon key")
    p, pa, t = parse_list_key('molformer_ranked_mtb_t5')
    _assert(p == 'molformer' and pa == 'mtb' and t == 5, "parse molformer key")

    # is_known_antibiotic
    _assert(is_known_antibiotic({'moa': 'DNA gyrase inhibitor', 'disease_area': '', 'target': ''}), "gyrase=known")
    _assert(is_known_antibiotic({'moa': 'beta-lactam antibiotic', 'disease_area': '', 'target': ''}), "beta-lactam=known")
    _assert(is_known_antibiotic({'moa': '', 'disease_area': 'bacterial infection', 'target': ''}), "bact inf=known")
    _assert(is_known_antibiotic({'moa': '', 'disease_area': '', 'target': 'dihydrofolate reductase'}), "DHFR=known")
    _assert(not is_known_antibiotic({'moa': 'HDAC inhibitor', 'disease_area': 'oncology', 'target': 'HDAC'}), "HDAC=novel")
    _assert(not is_known_antibiotic({'moa': 'kinase inhibitor', 'disease_area': 'cancer', 'target': 'EGFR'}), "kinase=novel")

    # consensus building
    mock = pd.DataFrame({
        'smiles': ['CCO', 'CCN', 'CCC'],
        'name': ['ethanol', 'amine', 'propane'],
        'selectivity_score': [0.9, 0.8, 0.7],
        'p_pathogen': [0.95, 0.85, 0.75],
        'p_gut': [0.05, 0.15, 0.25],
        'rank': [1, 2, 3],
        'moa': ['antibacterial', 'kinase inhibitor', ''],
        'clinical_phase': ['', '', ''],
        'disease_area': ['infection', 'oncology', ''],
        'target': ['', '', ''],
    })
    cons = build_consensus({
        'rf_ranked_ecoli_t10': mock,
        'dmpnn_ranked_ecoli_t10': mock,
    }, top_n=5)
    _assert(len(cons) == 3, f"consensus rows=3: {len(cons)}")
    _assert(cons.iloc[0]['n_models'] == 2, "top=2 models")
    _assert(cons.iloc[0]['best_selectivity'] == 0.9, "best S=0.9")
    n_known = int(cons['is_known_antibiotic'].sum())
    _assert(n_known == 1, f"1 known: {n_known}")
    _assert('s_ecoli' in cons.columns, "per-pathogen score column")

    # PATHOGEN_SCIENCE completeness
    _assert(len(PATHOGEN_SCIENCE) == 4, "4 pathogens")
    for pk in ['ecoli', 'saureus', 'paeruginosa', 'mtb']:
        _assert(pk in PATHOGEN_SCIENCE, f"{pk} in science dict")
        for field in ['full_name', 'gram', 'who_priority', 'resistance', 'microbiome_concern']:
            _assert(field in PATHOGEN_SCIENCE[pk], f"{pk}.{field}")

    # MODEL_SCIENCE completeness
    _assert(len(MODEL_SCIENCE) == 6, "6 models")
    for mk in ['rf', 'dmpnn', 'chemeleon_frozen', 'molformer', 'dmpnn_rdkit']:
        _assert(mk in MODEL_SCIENCE, f"{mk} in model dict")

    # Benchmark building
    mock_known = pd.DataFrame({
        'smiles': ['CCO', 'CCN'],
        'name': ['ampicillin', 'ciprofloxacin'],
        'selectivity_score': [0.7, 0.6],
        'p_pathogen': [0.8, 0.7],
        'p_gut': [0.125, 0.167],
        'rank': [1, 2],
        'moa': ['beta-lactam antibiotic', 'fluoroquinolone'],
        'clinical_phase': ['Launched', 'Launched'],
        'disease_area': ['bacterial infection', 'bacterial infection'],
        'target': ['PBP', 'DNA gyrase'],
    })
    mock_novel = pd.DataFrame({
        'smiles': ['CCC', 'CCCC', 'CCCCC'],
        'name': ['compound_X', 'compound_Y', 'compound_Z'],
        'selectivity_score': [0.85, 0.55, 0.40],
        'p_pathogen': [0.9, 0.6, 0.5],
        'p_gut': [0.059, 0.083, 0.2],
        'rank': [3, 4, 5],
        'moa': ['kinase inhibitor', 'HDAC inhibitor', 'PARP inhibitor'],
        'clinical_phase': ['Phase 2', 'Phase 1', ''],
        'disease_area': ['oncology', 'oncology', 'oncology'],
        'target': ['EGFR', 'HDAC', 'PARP'],
    })
    mock_combined = pd.concat([mock_known, mock_novel], ignore_index=True)
    mock_lists_bench = {'rf_ranked_ecoli_t10': mock_combined}
    mock_cons = build_consensus(mock_lists_bench, top_n=10)
    bench = build_benchmark_data(mock_lists_bench, mock_cons)
    _assert('ecoli' in bench, "benchmark has ecoli")
    ecoli_b = bench['ecoli']['lists'].get('rf', {})
    if ecoli_b:
        ks = ecoli_b['known_stats']
        ns = ecoli_b['novel_stats']
        _assert(ks['count'] == 2, f"2 known: {ks['count']}")
        _assert(ns['count'] == 3, f"3 novel: {ns['count']}")
        _assert(ks['max_S'] == 0.7, f"known max=0.7: {ks['max_S']}")
        _assert(ns['max_S'] == 0.85, f"novel max=0.85: {ns['max_S']}")
        # compound_X (0.85) > known median (0.65)
        _assert(ecoli_b['n_novel_above_median_known'] >= 1, "at least 1 novel above known median")
        # compound_X (0.85) > best known (0.7)
        _assert(ecoli_b['n_novel_above_best_known'] >= 1, "at least 1 novel above best known")

    # Regulatory standards data integrity
    _assert(len(CLSI_BREAKPOINTS) == 4, "CLSI breakpoints for 4 pathogens")
    for pk in ['ecoli', 'saureus', 'paeruginosa', 'mtb']:
        _assert(pk in CLSI_BREAKPOINTS, f"CLSI has {pk}")
        _assert(len(CLSI_BREAKPOINTS[pk]) >= 4, f"CLSI {pk} has >= 4 drugs")
    _assert(len(WHO_BURDEN) == 4, "WHO burden for 4 pathogens")
    _assert(WHO_BURDEN['saureus']['who_bppl_score_pct'] == 59, "MRSA score=59%")
    _assert(WHO_BURDEN['saureus']['cdc_deaths_per_year'] == 10600, "MRSA deaths=10600")
    _assert(len(PKPD_TARGETS) == 3, "3 PK/PD target types")
    _assert(len(PUBLISHED_ML_THRESHOLDS) == 2, "2 published benchmarks")
    _assert(PUBLISHED_ML_THRESHOLDS['stokes_2020']['hit_rate_top99'] == 0.515, "Stokes hit rate")
    _assert(len(SELECTIVITY_INDEX_TIERS) == 4, "4 SI tiers")

    print(f"Unit tests: {passed} passed, {failed} failed")


if __name__ == '__main__':
    if '--test' in sys.argv:
        run_tests()
    else:
        main()
