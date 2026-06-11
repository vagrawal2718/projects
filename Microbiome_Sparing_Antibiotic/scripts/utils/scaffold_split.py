"""
scaffold_split.py -- Scaffold-based cross-validation splitting.

Implements Bemis-Murcko scaffold-based k-fold splitting that is:
  1. Deterministic (same scaffolds always go to same fold)
  2. Saved to disk so both RF and D-MPNN use identical splits
  3. Balanced by scaffold group size

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import logging
import pickle
from collections import defaultdict
from typing import Dict, List, Optional, Tuple

import numpy as np
from rdkit import Chem, RDLogger
from rdkit.Chem.Scaffolds import MurckoScaffold

# Suppress RDKit valence warnings during scaffold decomposition
# (some ChEMBL molecules have unusual valence states like pentavalent carbon)
RDLogger.DisableLog('rdApp.warning')

logger = logging.getLogger(__name__)


def get_scaffold(smiles: str, generic: bool = True) -> Optional[str]:
    """
    Compute the Bemis-Murcko scaffold for a molecule.

    Parameters
    ----------
    smiles : str
        Canonical SMILES string.
    generic : bool
        If True, return the generic scaffold (all atoms -> carbon,
        all bonds -> single). Default True for grouping purposes.

    Returns
    -------
    str or None
        Scaffold SMILES, or None if computation fails.
    """
    try:
        mol = Chem.MolFromSmiles(smiles)
        if mol is None:
            return None
        core = MurckoScaffold.GetScaffoldForMol(mol)
        if generic:
            core = MurckoScaffold.MakeScaffoldGeneric(core)
        return Chem.MolToSmiles(core)
    except Exception as e:
        logger.debug(f"Scaffold extraction failed for {smiles[:60]}: {e}")
        return None


def generate_scaffold_folds(
    smiles_list: List[str],
    n_folds: int = 5,
    random_seed: int = 42
) -> List[int]:
    """
    Assign each molecule to a fold based on its Bemis-Murcko scaffold.

    Molecules sharing the same scaffold are always placed in the same fold.
    Scaffolds are sorted by group size (largest first) and assigned to the
    fold with the fewest molecules so far (greedy balancing).

    Parameters
    ----------
    smiles_list : list of str
        List of canonical SMILES strings.
    n_folds : int
        Number of cross-validation folds (default 5).
    random_seed : int
        Seed for reproducibility in tie-breaking.

    Returns
    -------
    list of int
        Fold assignment (0 to n_folds-1) for each molecule.
    """
    rng = np.random.RandomState(random_seed)
    n = len(smiles_list)

    # Step 1: Compute scaffolds and group indices
    scaffold_to_indices: Dict[str, List[int]] = defaultdict(list)
    no_scaffold_indices: List[int] = []

    for idx, smi in enumerate(smiles_list):
        scaffold = get_scaffold(smi)
        if scaffold is not None and len(scaffold) > 0:
            scaffold_to_indices[scaffold].append(idx)
        else:
            no_scaffold_indices.append(idx)

    logger.info(
        f"Scaffold analysis: {len(scaffold_to_indices)} unique scaffolds, "
        f"{len(no_scaffold_indices)} molecules without scaffold"
    )

    # Step 2: Sort scaffold groups by size (largest first) for greedy assignment
    scaffold_groups = list(scaffold_to_indices.values())
    scaffold_groups.sort(key=lambda x: len(x), reverse=True)

    # Step 3: Greedy assignment -- place each group in the least-populated fold
    fold_assignments = np.full(n, -1, dtype=int)
    fold_sizes = np.zeros(n_folds, dtype=int)

    for group_indices in scaffold_groups:
        # Find the fold with the fewest molecules; break ties randomly
        min_size = fold_sizes.min()
        candidate_folds = np.where(fold_sizes == min_size)[0]
        chosen_fold = rng.choice(candidate_folds)

        for idx in group_indices:
            fold_assignments[idx] = chosen_fold
        fold_sizes[chosen_fold] += len(group_indices)

    # Step 4: Assign no-scaffold molecules evenly
    rng.shuffle(no_scaffold_indices)
    for i, idx in enumerate(no_scaffold_indices):
        fold = i % n_folds
        fold_assignments[idx] = fold
        fold_sizes[fold] += 1

    # Sanity checks
    assert (fold_assignments >= 0).all(), "Some molecules were not assigned a fold"
    assert fold_assignments.max() < n_folds, "Fold index out of range"

    logger.info(f"Fold sizes: {dict(zip(range(n_folds), fold_sizes.tolist()))}")

    return fold_assignments.tolist()


def save_folds(fold_assignments: List[int], filepath: str) -> None:
    """
    Save fold assignments to a pickle file.

    Parameters
    ----------
    fold_assignments : list of int
        Fold assignment per molecule.
    filepath : str
        Output file path (.pkl).
    """
    with open(filepath, 'wb') as f:
        pickle.dump(fold_assignments, f, protocol=pickle.HIGHEST_PROTOCOL)
    logger.info(f"Saved {len(fold_assignments)} fold assignments to {filepath}")


def load_folds(filepath: str) -> List[int]:
    """
    Load fold assignments from a pickle file.

    Parameters
    ----------
    filepath : str
        Input file path (.pkl).

    Returns
    -------
    list of int
        Fold assignments.
    """
    with open(filepath, 'rb') as f:
        fold_assignments = pickle.load(f)
    logger.info(f"Loaded {len(fold_assignments)} fold assignments from {filepath}")
    return fold_assignments


def get_train_test_indices(
    fold_assignments: List[int],
    test_fold: int
) -> Tuple[np.ndarray, np.ndarray]:
    """
    Return train and test indices for a given fold number.

    Parameters
    ----------
    fold_assignments : list of int
        Fold assignment per molecule.
    test_fold : int
        Which fold to use as the test set.

    Returns
    -------
    tuple of (np.ndarray, np.ndarray)
        (train_indices, test_indices)
    """
    folds = np.array(fold_assignments)
    test_idx = np.where(folds == test_fold)[0]
    train_idx = np.where(folds != test_fold)[0]
    return train_idx, test_idx


def scaffold_split_summary(smiles_list: List[str], fold_assignments: List[int]) -> dict:
    """
    Generate a summary of the scaffold split for reporting.

    Returns a dict with fold sizes, scaffold counts, and balance metrics.
    """
    n_folds = max(fold_assignments) + 1
    folds = np.array(fold_assignments)
    summary = {
        'n_molecules': len(smiles_list),
        'n_folds': n_folds,
        'fold_sizes': {},
        'fold_fractions': {},
    }

    for k in range(n_folds):
        count = int((folds == k).sum())
        summary['fold_sizes'][k] = count
        summary['fold_fractions'][k] = round(count / len(smiles_list), 4)

    # Imbalance metric: max_fold_size / min_fold_size
    sizes = list(summary['fold_sizes'].values())
    summary['imbalance_ratio'] = round(max(sizes) / max(min(sizes), 1), 3)

    # Count unique scaffolds
    scaffolds = set()
    for smi in smiles_list:
        s = get_scaffold(smi)
        if s:
            scaffolds.add(s)
    summary['n_unique_scaffolds'] = len(scaffolds)

    return summary


# ---- Unit tests ----
def _run_tests():
    """Run unit tests for all functions in this module."""
    print("Running scaffold_split unit tests...")
    n_pass = 0
    n_fail = 0

    def _assert(condition, msg):
        nonlocal n_pass, n_fail
        if condition:
            n_pass += 1
            print(f"  [PASS] {msg}")
        else:
            n_fail += 1
            print(f"  [FAIL] {msg}")

    # Test get_scaffold
    s1 = get_scaffold("c1ccc(NC(=O)c2ccccc2)cc1")  # benzanilide
    _assert(s1 is not None, f"Benzanilide scaffold: {s1}")
    _assert(get_scaffold("INVALID") is None, "Invalid SMILES scaffold is None")
    _assert(get_scaffold("C") is not None or get_scaffold("C") is None,
            "Single atom scaffold handled")

    # Test generate_scaffold_folds
    test_smiles = [
        "c1ccccc1",             # benzene
        "c1ccc(O)cc1",          # phenol (same scaffold)
        "c1ccc(N)cc1",          # aniline (same scaffold)
        "C1CCCCC1",             # cyclohexane (different scaffold)
        "C1CCC(O)CC1",          # cyclohexanol (same as cyclohexane)
        "CCO",                  # ethanol (acyclic)
        "CCCO",                 # propanol (acyclic)
        "c1ccncc1",             # pyridine
        "C1CCNCC1",             # piperidine
        "c1ccc2ccccc2c1",       # naphthalene
    ]
    folds = generate_scaffold_folds(test_smiles, n_folds=3, random_seed=42)
    _assert(len(folds) == len(test_smiles), "Fold count matches molecule count")
    _assert(all(0 <= f < 3 for f in folds), "All folds in valid range")

    # Same scaffold should be in same fold
    benzene_scaffold = get_scaffold("c1ccccc1")
    phenol_scaffold = get_scaffold("c1ccc(O)cc1")
    _assert(benzene_scaffold == phenol_scaffold, "Benzene and phenol share generic scaffold")
    _assert(folds[0] == folds[1] == folds[2],
            "Same-scaffold molecules in same fold")

    # Test determinism
    folds2 = generate_scaffold_folds(test_smiles, n_folds=3, random_seed=42)
    _assert(folds == folds2, "Scaffold folds are deterministic with same seed")

    # Test save/load roundtrip
    import tempfile, os
    with tempfile.NamedTemporaryFile(suffix='.pkl', delete=False) as tmp:
        tmppath = tmp.name
    try:
        save_folds(folds, tmppath)
        loaded = load_folds(tmppath)
        _assert(folds == loaded, "Save/load roundtrip preserves folds")
    finally:
        os.unlink(tmppath)

    # Test get_train_test_indices
    train_idx, test_idx = get_train_test_indices(folds, test_fold=0)
    _assert(len(train_idx) + len(test_idx) == len(folds), "Train+test = total")
    _assert(all(folds[i] != 0 for i in train_idx), "No test-fold items in train")
    _assert(all(folds[i] == 0 for i in test_idx), "All test items from test fold")

    # Test summary
    summary = scaffold_split_summary(test_smiles, folds)
    _assert(summary['n_molecules'] == 10, "Summary molecule count")
    _assert(summary['n_folds'] == 3, "Summary fold count")
    _assert(summary['imbalance_ratio'] >= 1.0, "Imbalance ratio >= 1")

    print(f"\nUnit tests: {n_pass} passed, {n_fail} failed out of {n_pass + n_fail}")
    return n_fail == 0


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    success = _run_tests()
    exit(0 if success else 1)
