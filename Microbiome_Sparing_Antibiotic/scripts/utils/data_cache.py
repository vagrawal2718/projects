"""
data_cache.py -- Data caching and integrity verification framework.

DESIGN PRINCIPLES:
  1. Never re-download data that's already been fetched and validated
  2. Every cached file has an integrity record (size, hash, timestamp)
  3. Cache status is checked FIRST in every data-loading function
  4. Integrity failures trigger re-fetch automatically
  5. All cache operations are logged with file/function location tags

Usage in scripts:
    from utils.data_cache import DataCache
    cache = DataCache(config.PROJECT_DIR, logger)

    # Check before fetching
    if cache.is_valid('chembl/ecoli_activity.csv', min_rows=1000):
        df = pd.read_csv(cache.get_path('chembl/ecoli_activity.csv'))
    else:
        df = fetch_from_api(...)
        df.to_csv(cache.get_path('chembl/ecoli_activity.csv'), index=False)
        cache.register('chembl/ecoli_activity.csv', n_rows=len(df))

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import os
import sys
import json
import time
import hashlib
import logging
from typing import Optional


class DataCache:
    """
    Manages cached data files with integrity verification.

    Maintains a JSON manifest at {project_dir}/checkpoints/data_manifest.json
    tracking every data file's size, row count, hash, and fetch timestamp.
    """

    def __init__(self, project_dir: str, logger: logging.Logger):
        self.project_dir = project_dir
        self.data_dir = os.path.join(project_dir, 'data')
        self.logger = logger
        self._F = "data_cache.py:DataCache"

        self.manifest_path = os.path.join(project_dir, 'checkpoints', 'data_manifest.json')
        self.manifest = self._load_manifest()

    def _load_manifest(self) -> dict:
        """Load or create the data manifest."""
        if os.path.exists(self.manifest_path):
            try:
                with open(self.manifest_path, 'r') as f:
                    data = json.load(f)
                self.logger.info(f"  [{self._F}] Manifest loaded: "
                                 f"{len(data.get('files', {}))} cached files")
                return data
            except Exception as e:
                self.logger.warning(f"  [{self._F}] Manifest corrupt ({e}), starting fresh")
        return {'files': {}, 'created': time.strftime('%Y-%m-%d %H:%M:%S')}

    def _save_manifest(self):
        """Save manifest to disk."""
        try:
            os.makedirs(os.path.dirname(self.manifest_path), exist_ok=True)
            self.manifest['last_updated'] = time.strftime('%Y-%m-%d %H:%M:%S')
            with open(self.manifest_path, 'w') as f:
                json.dump(self.manifest, f, indent=2, default=str)
        except Exception as e:
            self.logger.warning(f"  [{self._F}] Failed to save manifest: {e}")

    def get_path(self, relative_path: str) -> str:
        """Get absolute path for a data file."""
        return os.path.join(self.data_dir, relative_path)

    def exists(self, relative_path: str) -> bool:
        """Check if a cached file exists and is non-empty."""
        full_path = self.get_path(relative_path)
        return os.path.exists(full_path) and os.path.getsize(full_path) > 0

    def is_valid(self, relative_path: str, min_size: int = 100,
                 min_rows: Optional[int] = None) -> bool:
        """
        Check if a cached file is valid.

        Parameters
        ----------
        relative_path : str
            Path relative to data directory.
        min_size : int
            Minimum file size in bytes.
        min_rows : int, optional
            If set, checks the manifest for recorded row count.

        Returns True if file exists, meets size requirement, and
        (if min_rows set) has enough recorded rows.
        """
        full_path = self.get_path(relative_path)
        if not os.path.exists(full_path):
            self.logger.info(f"  [{self._F}] Cache MISS: {relative_path} (not found)")
            return False

        file_size = os.path.getsize(full_path)
        if file_size < min_size:
            self.logger.warning(f"  [{self._F}] Cache INVALID: {relative_path} "
                                f"(size={file_size} < {min_size})")
            return False

        if min_rows is not None:
            record = self.manifest.get('files', {}).get(relative_path, {})
            recorded_rows = record.get('n_rows', 0)
            if recorded_rows < min_rows:
                self.logger.warning(f"  [{self._F}] Cache INVALID: {relative_path} "
                                    f"(rows={recorded_rows} < {min_rows})")
                return False

        self.logger.info(f"  [{self._F}] Cache HIT: {relative_path} "
                         f"(size={file_size:,} bytes)")
        return True

    def register(self, relative_path: str, n_rows: int = 0,
                 description: str = '', compute_hash: bool = False):
        """
        Register a file in the cache manifest after successful creation.

        Parameters
        ----------
        relative_path : str
        n_rows : int
            Number of data rows (for validation).
        description : str
            Human-readable description.
        compute_hash : bool
            If True, compute MD5 hash (slow for large files).
        """
        full_path = self.get_path(relative_path)
        if not os.path.exists(full_path):
            self.logger.warning(f"  [{self._F}] Cannot register non-existent file: {full_path}")
            return

        record = {
            'path': full_path,
            'size_bytes': os.path.getsize(full_path),
            'n_rows': n_rows,
            'description': description,
            'cached_at': time.strftime('%Y-%m-%d %H:%M:%S'),
        }

        if compute_hash:
            try:
                h = hashlib.md5()
                with open(full_path, 'rb') as f:
                    for chunk in iter(lambda: f.read(8192), b''):
                        h.update(chunk)
                record['md5'] = h.hexdigest()
            except Exception as e:
                self.logger.warning(f"  [{self._F}] Hash computation failed: {e}")

        self.manifest.setdefault('files', {})[relative_path] = record
        self._save_manifest()

        self.logger.info(f"  [{self._F}] Registered: {relative_path} "
                         f"({record['size_bytes']:,} bytes, {n_rows} rows)")

    def get_record(self, relative_path: str) -> Optional[dict]:
        """Get the manifest record for a file, or None."""
        return self.manifest.get('files', {}).get(relative_path)

    def summary(self) -> str:
        """Return a summary of all cached files."""
        files = self.manifest.get('files', {})
        lines = [f"Data cache: {len(files)} files"]
        total_size = 0
        for path, record in sorted(files.items()):
            size = record.get('size_bytes', 0)
            total_size += size
            rows = record.get('n_rows', '?')
            cached = record.get('cached_at', '?')
            lines.append(f"  {path}: {size:,} bytes, {rows} rows, cached {cached}")
        lines.append(f"  Total: {total_size / (1024*1024):.1f} MB")
        return '\n'.join(lines)


# ===========================================================================
# Self-test
# ===========================================================================
def _run_tests():
    """Test the data cache framework."""
    import tempfile
    print("Running data_cache unit tests...")
    n_pass = 0; n_fail = 0

    def _assert(cond, msg):
        nonlocal n_pass, n_fail
        if cond: n_pass += 1; print(f"  [PASS] {msg}")
        else: n_fail += 1; print(f"  [FAIL] {msg}")

    test_logger = logging.getLogger('cache_test')
    test_logger.setLevel(logging.DEBUG)
    if not test_logger.handlers:
        test_logger.addHandler(logging.StreamHandler(sys.stdout))

    with tempfile.TemporaryDirectory() as tmpdir:
        # Create project structure
        os.makedirs(os.path.join(tmpdir, 'data', 'test'), exist_ok=True)
        os.makedirs(os.path.join(tmpdir, 'checkpoints'), exist_ok=True)

        cache = DataCache(tmpdir, test_logger)
        _assert(not cache.is_valid('test/missing.csv'), "Missing file is invalid")

        # Create a test file
        test_file = os.path.join(tmpdir, 'data', 'test', 'sample.csv')
        with open(test_file, 'w') as f:
            f.write('col1,col2\n1,a\n2,b\n3,c\n')

        _assert(cache.exists('test/sample.csv'), "Existing file detected")
        _assert(cache.is_valid('test/sample.csv', min_size=10), "Valid by size")
        _assert(not cache.is_valid('test/sample.csv', min_size=10, min_rows=100),
                "Invalid by row count (no manifest entry)")

        cache.register('test/sample.csv', n_rows=3, description='test data')
        _assert(cache.is_valid('test/sample.csv', min_size=10, min_rows=2),
                "Valid after registration")
        _assert(not cache.is_valid('test/sample.csv', min_size=10, min_rows=100),
                "Still invalid if min_rows too high")

        record = cache.get_record('test/sample.csv')
        _assert(record is not None, "Record exists after registration")
        _assert(record['n_rows'] == 3, f"Row count correct: {record['n_rows']}")

        # Test manifest persistence
        cache2 = DataCache(tmpdir, test_logger)
        _assert(cache2.is_valid('test/sample.csv', min_size=10, min_rows=2),
                "Cache persists across instances")

        summary = cache.summary()
        _assert('sample.csv' in summary, "Summary includes file")

    print(f"\nUnit tests: {n_pass} passed, {n_fail} failed")
    return n_fail == 0


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    success = _run_tests()
    exit(0 if success else 1)
