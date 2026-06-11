"""
smiles_utils.py -- SMILES processing utilities for the antibiotic selectivity project.

Functions for canonical SMILES generation, salt removal, validation,
and molecular weight calculation. Used across all phases.

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import logging
from typing import Optional, Tuple

from rdkit import Chem, RDLogger
from rdkit.Chem import Descriptors
from rdkit.Chem.MolStandardize import rdMolStandardize

# Suppress RDKit C++ debug messages (LargestFragmentChooser / Uncharger spam)
RDLogger.DisableLog('rdApp.info')

logger = logging.getLogger(__name__)

# Precompile the uncharger and largest-fragment chooser once
_UNCHARGER = rdMolStandardize.Uncharger()
_LFC = rdMolStandardize.LargestFragmentChooser()


def canonicalize_smiles(smiles: str) -> Optional[str]:
    """
    Convert a SMILES string to canonical form with salt removal and neutralization.

    Steps:
        1. Parse SMILES to RDKit Mol object
        2. Select the largest fragment (removes salts like HCl, Na, etc.)
        3. Neutralize charges where possible
        4. Generate canonical SMILES

    Parameters
    ----------
    smiles : str
        Input SMILES string.

    Returns
    -------
    str or None
        Canonical SMILES string, or None if parsing fails.
    """
    if not smiles or not isinstance(smiles, str):
        return None
    smiles = smiles.strip()
    if len(smiles) == 0:
        return None

    try:
        mol = Chem.MolFromSmiles(smiles)
        if mol is None:
            logger.debug(f"RDKit failed to parse SMILES: {smiles[:80]}")
            return None

        # Remove salts: keep largest fragment
        mol = _LFC.choose(mol)

        # Neutralize charges
        mol = _UNCHARGER.uncharge(mol)

        # Generate canonical SMILES
        canonical = Chem.MolToSmiles(mol, isomericSmiles=True)
        return canonical

    except Exception as e:
        logger.debug(f"Error canonicalizing '{smiles[:80]}': {e}")
        return None


def validate_smiles(smiles: str) -> bool:
    """
    Check if a SMILES string is valid (parseable by RDKit).

    Parameters
    ----------
    smiles : str
        Input SMILES string.

    Returns
    -------
    bool
        True if valid, False otherwise.
    """
    if not smiles or not isinstance(smiles, str):
        return False
    mol = Chem.MolFromSmiles(smiles.strip())
    return mol is not None


def get_molecular_weight(smiles: str) -> Optional[float]:
    """
    Calculate exact molecular weight from a SMILES string.

    Parameters
    ----------
    smiles : str
        Input SMILES string (preferably canonical).

    Returns
    -------
    float or None
        Molecular weight in g/mol, or None if SMILES is invalid.
    """
    if not smiles:
        return None
    mol = Chem.MolFromSmiles(smiles.strip())
    if mol is None:
        return None
    return Descriptors.ExactMolWt(mol)


def convert_ugml_to_nM(value_ugml: float, mw: float) -> Optional[float]:
    """
    Convert a concentration from ug/mL to nM.

    Formula: nM = (ug/mL) / (MW in g/mol) * 1e6

    Parameters
    ----------
    value_ugml : float
        Concentration in micrograms per milliliter.
    mw : float
        Molecular weight in g/mol.

    Returns
    -------
    float or None
        Concentration in nM, or None if inputs are invalid.
    """
    if value_ugml is None or mw is None or mw <= 0:
        return None
    try:
        return (value_ugml / mw) * 1e6
    except (TypeError, ZeroDivisionError):
        return None


def smiles_to_inchikey(smiles: str) -> Optional[str]:
    """
    Generate InChIKey from a SMILES string.

    Parameters
    ----------
    smiles : str
        Input SMILES string.

    Returns
    -------
    str or None
        InChIKey string, or None if conversion fails.
    """
    if not smiles:
        return None
    mol = Chem.MolFromSmiles(smiles.strip())
    if mol is None:
        return None
    try:
        from rdkit.Chem.inchi import MolToInchi, InchiToInchiKey
        inchi = MolToInchi(mol)
        if inchi is None:
            return None
        return InchiToInchiKey(inchi)
    except Exception:
        return None


def batch_canonicalize(smiles_list: list) -> Tuple[list, int, int]:
    """
    Canonicalize a list of SMILES strings.

    Parameters
    ----------
    smiles_list : list of str
        List of input SMILES strings.

    Returns
    -------
    tuple of (list, int, int)
        (canonical_smiles_list, n_success, n_fail)
        Failed entries are returned as None in the list.
    """
    results = []
    n_success = 0
    n_fail = 0
    for smi in smiles_list:
        canonical = canonicalize_smiles(smi)
        results.append(canonical)
        if canonical is not None:
            n_success += 1
        else:
            n_fail += 1
    return results, n_success, n_fail


# ---- Unit tests ----
def _run_tests():
    """Run unit tests for all functions in this module."""
    print("Running smiles_utils unit tests...")
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

    # Test canonicalize_smiles
    _assert(canonicalize_smiles("CCO") == "CCO", "Ethanol canonical")
    _assert(canonicalize_smiles("OCC") == "CCO", "Ethanol reordered")
    _assert(canonicalize_smiles("CCO.[Na]") == "CCO", "Salt removal Na")
    _assert(canonicalize_smiles("[Na+].OC(=O)c1ccccc1") is not None, "Sodium benzoate salt removal")
    _assert(canonicalize_smiles("") is None, "Empty string returns None")
    _assert(canonicalize_smiles(None) is None, "None returns None")
    _assert(canonicalize_smiles("INVALID_SMILES_XYZ") is None, "Invalid SMILES returns None")
    _assert(canonicalize_smiles("  CCO  ") == "CCO", "Whitespace handling")

    # Test validate_smiles
    _assert(validate_smiles("CCO") is True, "Valid SMILES")
    _assert(validate_smiles("NOT_A_SMILES") is False, "Invalid SMILES")
    _assert(validate_smiles("") is False, "Empty string")
    _assert(validate_smiles(None) is False, "None input")

    # Test get_molecular_weight
    mw_water = get_molecular_weight("O")
    _assert(mw_water is not None and abs(mw_water - 18.01) < 0.1, f"Water MW={mw_water:.2f}")
    mw_ethanol = get_molecular_weight("CCO")
    _assert(mw_ethanol is not None and abs(mw_ethanol - 46.04) < 0.1, f"Ethanol MW={mw_ethanol:.2f}")
    _assert(get_molecular_weight("INVALID") is None, "Invalid MW returns None")

    # Test convert_ugml_to_nM
    # 1 ug/mL of water (MW 18.015) = (1/18.015)*1e6 = ~55509 nM
    result = convert_ugml_to_nM(1.0, 18.015)
    _assert(result is not None and abs(result - 55509) < 100, f"ugml_to_nM water: {result:.0f}")
    _assert(convert_ugml_to_nM(1.0, 0) is None, "Zero MW returns None")
    _assert(convert_ugml_to_nM(None, 100) is None, "None value returns None")

    # Test smiles_to_inchikey
    ik = smiles_to_inchikey("CCO")
    _assert(ik is not None and ik.startswith("LFQSCWFLJHTTHZ"), f"Ethanol InChIKey={ik}")
    _assert(smiles_to_inchikey("INVALID") is None, "Invalid InChIKey returns None")

    # Test batch_canonicalize
    results, ns, nf = batch_canonicalize(["CCO", "OCC", "INVALID", None, "c1ccccc1"])
    _assert(ns == 3 and nf == 2, f"Batch: {ns} success, {nf} fail")
    _assert(results[0] == "CCO", "Batch result 0")
    _assert(results[1] == "CCO", "Batch result 1 (reordered)")
    _assert(results[2] is None, "Batch result 2 (invalid)")
    _assert(results[3] is None, "Batch result 3 (None)")
    _assert(results[4] == "c1ccccc1", "Batch result 4 (benzene)")

    print(f"\nUnit tests: {n_pass} passed, {n_fail} failed out of {n_pass + n_fail}")
    return n_fail == 0


if __name__ == "__main__":
    success = _run_tests()
    exit(0 if success else 1)
