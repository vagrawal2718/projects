"""
network_utils.py -- Robust network operations with retry, caching, and diagnostics.

Every external call goes through this module so that:
  1. Retry logic is consistent (exponential backoff, configurable max retries)
  2. Network failures produce ACTIONABLE error messages
  3. Connection is tested before expensive operations
  4. Downloaded content is always cached to disk before processing
  5. Timeouts are configurable per operation type

Usage:
    from utils.network_utils import robust_get, test_connectivity, robust_api_call

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import os
import sys
import time
import logging
import hashlib
from typing import Any, Callable, Optional


def test_connectivity(logger: logging.Logger, urls: list = None) -> dict:
    """
    Test connectivity to critical external services.

    Returns dict mapping url -> (reachable: bool, status_code: int, latency_ms: float).
    """
    import requests

    _F = "network_utils.py:test_connectivity"
    if urls is None:
        urls = [
            'https://www.ebi.ac.uk/chembl/api/data/activity.json?limit=1',
            'https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/2244/property/CanonicalSMILES/JSON',
            'https://s3.amazonaws.com/data.clue.io/repurposing/downloads/repurposing_drugs_20200324.txt',
        ]

    results = {}
    for url in urls:
        domain = url.split('/')[2]
        try:
            t0 = time.time()
            resp = requests.get(url, timeout=30)
            latency = (time.time() - t0) * 1000
            results[domain] = {
                'reachable': resp.status_code < 400,
                'status_code': resp.status_code,
                'latency_ms': round(latency, 1),
            }
            logger.info(f"  [{_F}] {domain}: HTTP {resp.status_code} ({latency:.0f}ms)")
        except requests.exceptions.Timeout:
            results[domain] = {'reachable': False, 'status_code': 0, 'latency_ms': 30000}
            logger.warning(f"  [{_F}] {domain}: TIMEOUT (30s)")
        except requests.exceptions.ConnectionError as e:
            results[domain] = {'reachable': False, 'status_code': 0, 'latency_ms': 0}
            logger.warning(f"  [{_F}] {domain}: CONNECTION ERROR: {e}")
        except Exception as e:
            results[domain] = {'reachable': False, 'status_code': 0, 'latency_ms': 0}
            logger.warning(f"  [{_F}] {domain}: {type(e).__name__}: {e}")

    n_ok = sum(1 for v in results.values() if v['reachable'])
    logger.info(f"  [{_F}] Connectivity: {n_ok}/{len(results)} services reachable")

    if n_ok == 0:
        logger.error(f"  [{_F}] NO external services reachable!")
        logger.error(f"  [{_F}] ACTION: Check if compute node has internet access.")
        logger.error(f"  [{_F}]   Try: curl -s https://www.ebi.ac.uk/chembl/api/data/activity.json?limit=1")
        logger.error(f"  [{_F}]   If blocked, use a login node for network phases.")

    return results


def robust_get(
    url: str,
    logger: logging.Logger,
    cache_path: Optional[str] = None,
    max_retries: int = 5,
    timeout: int = 120,
    min_size: int = 100,
    description: str = '',
) -> str:
    """
    Download a URL with retry logic and local disk caching.

    Parameters
    ----------
    url : str
    logger : logging.Logger
    cache_path : str, optional
        If provided, content is cached here. On subsequent calls, the cached
        file is returned without any network call.
    max_retries : int
    timeout : int
        Per-request timeout in seconds.
    min_size : int
        Minimum cached file size to consider valid.
    description : str
        Human-readable label for log messages.

    Returns str content on success.
    Raises RuntimeError on failure after all retries.
    """
    import requests

    _F = f"network_utils.py:robust_get"
    label = description or url.split('/')[-1]

    # Check cache FIRST
    if cache_path and os.path.exists(cache_path) and os.path.getsize(cache_path) >= min_size:
        size = os.path.getsize(cache_path)
        logger.info(f"  [{_F}] CACHE HIT: {label} ({size:,} bytes at {cache_path})")
        try:
            with open(cache_path, 'r', encoding='utf-8', errors='replace') as f:
                content = f.read()
            if len(content) >= min_size:
                return content
            else:
                logger.warning(f"  [{_F}] Cache file too small ({len(content)} chars), re-downloading")
        except Exception as e:
            logger.warning(f"  [{_F}] Cache read failed ({e}), re-downloading")

    # Download with retries
    logger.info(f"  [{_F}] Downloading: {label}")
    logger.info(f"  [{_F}] URL: {url}")

    last_error = None
    for attempt in range(1, max_retries + 1):
        try:
            t0 = time.time()
            resp = requests.get(url, timeout=timeout)
            latency = time.time() - t0

            if resp.status_code == 200:
                content = resp.text
                logger.info(f"  [{_F}] Downloaded: {len(content):,} bytes in {latency:.1f}s")

                # Save to cache
                if cache_path:
                    try:
                        os.makedirs(os.path.dirname(cache_path), exist_ok=True)
                        with open(cache_path, 'w', encoding='utf-8') as f:
                            f.write(content)
                        logger.info(f"  [{_F}] Cached to: {cache_path}")
                    except Exception as e:
                        logger.warning(f"  [{_F}] Cache write failed: {e}")

                return content

            else:
                logger.warning(f"  [{_F}] HTTP {resp.status_code} on attempt "
                               f"{attempt}/{max_retries} for {label}")
                if resp.status_code == 404:
                    logger.error(f"  [{_F}] 404 Not Found. URL may have changed.")
                    logger.error(f"  [{_F}] ACTION: Verify URL is correct: {url}")
                elif resp.status_code == 403:
                    logger.error(f"  [{_F}] 403 Forbidden. IP may be blocked.")
                elif resp.status_code >= 500:
                    logger.warning(f"  [{_F}] Server error. Will retry.")
                last_error = f"HTTP {resp.status_code}"

        except requests.exceptions.Timeout:
            logger.warning(f"  [{_F}] TIMEOUT ({timeout}s) on attempt "
                           f"{attempt}/{max_retries} for {label}")
            last_error = f"Timeout after {timeout}s"

        except requests.exceptions.ConnectionError as e:
            logger.warning(f"  [{_F}] CONNECTION ERROR on attempt "
                           f"{attempt}/{max_retries}: {e}")
            last_error = f"ConnectionError: {e}"

        except Exception as e:
            logger.warning(f"  [{_F}] {type(e).__name__} on attempt "
                           f"{attempt}/{max_retries}: {e}")
            last_error = f"{type(e).__name__}: {e}"

        # Exponential backoff
        wait = min(2 ** attempt, 60)  # Cap at 60s
        if attempt < max_retries:
            logger.info(f"  [{_F}] Retrying in {wait}s...")
            time.sleep(wait)

    # All retries exhausted
    logger.error(f"  [{_F}] FAILED after {max_retries} attempts: {label}")
    logger.error(f"  [{_F}] Last error: {last_error}")
    logger.error(f"  [{_F}] URL: {url}")
    logger.error(f"  [{_F}] ACTION: Test manually from the compute node:")
    logger.error(f"  [{_F}]   curl -v '{url}' 2>&1 | head -20")
    raise RuntimeError(f"Failed to download {label} after {max_retries} attempts: {last_error}")


def robust_api_call(
    func: Callable,
    *args,
    logger: logging.Logger,
    max_retries: int = 5,
    description: str = '',
    **kwargs,
) -> Any:
    """
    Call an API function with retry logic and exponential backoff.

    Parameters
    ----------
    func : callable
        API function to call.
    *args : positional args for func.
    logger : logging.Logger
    max_retries : int
    description : str
        Human-readable label.
    **kwargs : keyword args for func.

    Returns the function result on success.
    Raises RuntimeError on failure after all retries.
    """
    _F = "network_utils.py:robust_api_call"
    label = description or func.__name__

    last_error = None
    for attempt in range(1, max_retries + 1):
        try:
            t0 = time.time()
            result = func(*args, **kwargs)
            elapsed = time.time() - t0
            logger.info(f"  [{_F}] {label}: success in {elapsed:.1f}s "
                        f"(attempt {attempt}/{max_retries})")
            return result

        except KeyboardInterrupt:
            raise

        except Exception as e:
            elapsed = time.time() - t0
            last_error = f"{type(e).__name__}: {e}"
            logger.warning(f"  [{_F}] {label}: attempt {attempt}/{max_retries} "
                           f"FAILED after {elapsed:.1f}s: {last_error}")

            if attempt < max_retries:
                wait = min(2 ** attempt, 60)
                logger.info(f"  [{_F}] Retrying in {wait}s...")
                time.sleep(wait)

    logger.error(f"  [{_F}] {label}: FAILED after {max_retries} attempts")
    logger.error(f"  [{_F}] Last error: {last_error}")
    raise RuntimeError(f"API call {label} failed after {max_retries} attempts: {last_error}")


# ===========================================================================
# Self-test
# ===========================================================================
def _run_tests():
    """Test network utilities (without actual network calls)."""
    print("Running network_utils unit tests...")
    n_pass = 0; n_fail = 0

    def _assert(cond, msg):
        nonlocal n_pass, n_fail
        if cond: n_pass += 1; print(f"  [PASS] {msg}")
        else: n_fail += 1; print(f"  [FAIL] {msg}")

    test_logger = logging.getLogger('net_test')
    test_logger.setLevel(logging.DEBUG)
    if not test_logger.handlers:
        test_logger.addHandler(logging.StreamHandler(sys.stdout))

    import tempfile

    # Test robust_get with cache
    with tempfile.TemporaryDirectory() as tmpdir:
        cache_file = os.path.join(tmpdir, 'cached.txt')

        # Write a fake cache file
        with open(cache_file, 'w') as f:
            f.write('x' * 200)

        # Should return from cache without network
        content = robust_get('http://fake.invalid/test', test_logger,
                             cache_path=cache_file, min_size=100)
        _assert(len(content) == 200, "Cache hit returns correct content")

    # Test robust_api_call with success
    def good_api(x):
        return x * 2
    result = robust_api_call(good_api, 5, logger=test_logger, description='test_good')
    _assert(result == 10, "Successful API call returns result")

    # Test robust_api_call with retry then success
    call_count = [0]
    def flaky_api():
        call_count[0] += 1
        if call_count[0] < 3:
            raise ConnectionError("simulated failure")
        return "ok"
    result = robust_api_call(flaky_api, logger=test_logger, max_retries=5,
                             description='test_flaky')
    _assert(result == "ok", f"Flaky API succeeded after {call_count[0]} attempts")
    _assert(call_count[0] == 3, f"Took exactly 3 attempts: {call_count[0]}")

    # Test robust_api_call total failure
    def always_fail():
        raise ValueError("always fails")
    try:
        robust_api_call(always_fail, logger=test_logger, max_retries=2,
                        description='test_fail')
        _assert(False, "Should have raised RuntimeError")
    except RuntimeError:
        _assert(True, "Total failure raises RuntimeError after max retries")

    print(f"\nUnit tests: {n_pass} passed, {n_fail} failed")
    return n_fail == 0


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    success = _run_tests()
    exit(0 if success else 1)
