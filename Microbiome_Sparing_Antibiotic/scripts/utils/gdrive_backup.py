"""
gdrive_backup.py -- Data Manager with Google Drive backup for all platforms.

Priority chain for every file:
  1. LOCAL disk (instant)
  2. Google Drive mounted folder (fast, local copy from mounted Drive)
  3. Public Google Drive link via HTTP (works on Ada, any machine)
  4. Network download (slowest: ChEMBL FTP, S3, PubChem)

After any network download, files are automatically pushed to Drive.
All pipeline outputs are saved to both local and Drive.

Drive layout (in Google Drive / antibiotic_data /):
  chembl_34_sqlite.tar.gz     ~1 GB   compressed archive
  chembl_34.db                ~4 GB   extracted SQLite
  ecoli_activity.csv          ~5 MB   processed pathogen data
  saureus_activity.csv        ~8 MB
  paeruginosa_activity.csv    ~3 MB
  mtb_activity.csv            ~12 MB
  repurposing_hub_clean.csv   ~1 MB   screening library
  maier_combined.csv          ~0.2 MB commensal harm data
  raw_maier/*.xlsx            ~2 MB   24 original Excel files
  outputs/*.zip               variable pipeline run results

Public link (anyone with link, read-only):
  https://drive.google.com/drive/folders/1-7hiX-fZkUrpc_-1QMbF6_QC51hVW2W7

Author:  Vishakha Agrawal, IIIT Hyderabad
Date:    March 2026
"""

import os
import shutil
import logging
import subprocess
import time
from pathlib import Path
from typing import Optional, List

logger = logging.getLogger(__name__)

# ---- Public Google Drive folders ----
# READ-ONLY input data (anyone with link, no auth needed):
PUBLIC_DRIVE_FOLDER_ID = "1-7hiX-fZkUrpc_-1QMbF6_QC51hVW2W7"
PUBLIC_DRIVE_FOLDER_URL = f"https://drive.google.com/drive/folders/{PUBLIC_DRIVE_FOLDER_ID}"

# READ-WRITE output folder (requires auth via rclone):
OUTPUT_DRIVE_FOLDER_ID = "15eW2vTMllJySlFzkdKeC8-nKZ7pskqPR"
OUTPUT_DRIVE_FOLDER_URL = f"https://drive.google.com/drive/folders/{OUTPUT_DRIVE_FOLDER_ID}"

# rclone remote name (configured during setup)
RCLONE_REMOTE = "antibiotic_gdrive"

BACKUP_FOLDER = "antibiotic_data"

# Common Drive mount points
_DRIVE_CANDIDATES = [
    "~/Google Drive/My Drive",
    "~/Google Drive",
    "~/Library/CloudStorage/GoogleDrive-*/My Drive",
    "/content/drive/MyDrive",
    "~/GoogleDrive",
    "~/gdrive",
    "G:\\My Drive",
    "G:\\",
]


def _gdown_available() -> bool:
    """Check if gdown is installed."""
    try:
        import gdown
        return True
    except ImportError:
        return False


def _validate_downloaded_file(filepath: str, expected_ext: str) -> bool:
    """Verify a downloaded file is real content, not an HTML error page."""
    if not os.path.exists(filepath) or os.path.getsize(filepath) == 0:
        return False
    try:
        with open(filepath, 'rb') as f:
            header = f.read(512)
        # HTML page detection (Google Drive login/confirmation pages)
        if b'<!DOCTYPE' in header or b'<html' in header or b'<HTML' in header:
            logger.warning(f"  [DataManager] {os.path.basename(filepath)}: "
                           f"downloaded HTML page, not real file. Deleting.")
            os.remove(filepath)
            return False
        # ZIP validation
        if expected_ext in ('.zip',) and header[:4] != b'PK\x03\x04':
            logger.warning(f"  [DataManager] {os.path.basename(filepath)}: "
                           f"not a valid ZIP file. Deleting.")
            os.remove(filepath)
            return False
        # CSV: should have comma or tab in first line
        if expected_ext in ('.csv', '.tsv'):
            first_line = header.split(b'\n')[0]
            if b',' not in first_line and b'\t' not in first_line:
                logger.warning(f"  [DataManager] {os.path.basename(filepath)}: "
                               f"not a valid CSV. Deleting.")
                os.remove(filepath)
                return False
        return True
    except Exception:
        return False


def _purge_poisoned_cache():
    """Remove any HTML files masquerading as data in the gdown cache."""
    cache_dir = os.path.join(os.path.expanduser("~"), ".antibiotic_gdrive_cache")
    if not os.path.isdir(cache_dir):
        return
    purged = 0
    for root, dirs, files in os.walk(cache_dir):
        for fname in files:
            fpath = os.path.join(root, fname)
            ext = os.path.splitext(fname)[1].lower()
            if ext in ('.csv', '.tsv', '.zip', '.json'):
                try:
                    with open(fpath, 'rb') as f:
                        header = f.read(256)
                    if b'<!DOCTYPE' in header or b'<html' in header or b'<HTML' in header:
                        os.remove(fpath)
                        purged += 1
                except Exception:
                    pass
    if purged:
        logger.info(f"  [DataManager] Purged {purged} poisoned files from gdown cache")


def download_from_public_drive(filename: str, dest_path: str) -> bool:
    """
    Download a single file from the public Drive folder by name.

    Uses gdown to list the public folder, find the file, and download it
    by individual file ID. Does NOT use folder-URL fuzzy download (which
    returns the HTML page instead of the file).

    Parameters
    ----------
    filename : str
        Name of the file to download (e.g., 'ecoli_activity.csv').
    dest_path : str
        Local path where the file should be saved.

    Returns
    -------
    bool
        True if download succeeded and file content is valid.
    """
    # REFUSE known large files via this path
    LARGE_EXTENSIONS = {'.db', '.tar.gz', '.sqlite', '.tar'}
    for ext in LARGE_EXTENSIONS:
        if filename.endswith(ext):
            logger.debug(f"  [DataManager] {filename}: large file, use rclone instead")
            return False

    os.makedirs(os.path.dirname(dest_path) or '.', exist_ok=True)
    file_ext = os.path.splitext(filename)[1].lower()

    cache_dir = os.path.join(os.path.expanduser("~"), ".antibiotic_gdrive_cache")
    os.makedirs(cache_dir, exist_ok=True)

    # Purge any previously cached HTML pages on first call
    _purge_poisoned_cache()

    # Check local cache first (with content validation)
    for root, dirs, files in os.walk(cache_dir):
        if filename in files:
            src = os.path.join(root, filename)
            if _validate_downloaded_file(src, file_ext):
                shutil.copy2(src, dest_path)
                size_mb = os.path.getsize(dest_path) / (1024 * 1024)
                logger.info(f"  [DataManager] From gdown cache: {filename} ({size_mb:.1f} MB)")
                return True

    if not _gdown_available():
        logger.debug("  [DataManager] gdown not installed. pip install gdown")
        return False

    import gdown

    # Get folder listing (file IDs) via gdown API or HTML scrape
    file_map = _get_drive_folder_listing()
    if file_map and filename in file_map:
        file_id, file_size = file_map[filename]
        if file_id and file_id not in ('cached', 'large', '') and len(file_id) > 10:
            try:
                url = f"https://drive.google.com/uc?id={file_id}"
                cached_path = os.path.join(cache_dir, filename)
                logger.info(f"  [DataManager] Downloading {filename} by file ID...")
                gdown.download(url, cached_path, quiet=True)
                if _validate_downloaded_file(cached_path, file_ext):
                    shutil.copy2(cached_path, dest_path)
                    size_mb = os.path.getsize(dest_path) / (1024 * 1024)
                    logger.info(f"  [DataManager] Downloaded: {filename} ({size_mb:.1f} MB)")
                    return True
            except Exception as e:
                logger.debug(f"  [DataManager] File ID download failed: {e}")

    # File ID approach failed. Do NOT try fuzzy download with a folder URL
    # because gdown returns the folder HTML page instead of the actual file.
    logger.warning(f"  [DataManager] {filename} not available via public Drive link")
    logger.warning(f"  [DataManager] Tip: set up rclone (bash setup_rclone_gdrive.sh) for reliable Drive access")
    return False


# Cached folder listing
_folder_listing_cache = None

# Hardcoded fallback: if HTML scraping fails, try gdown's own folder API
# This is populated once and cached. Users can also set file IDs manually
# via ~/.antibiotic_gdrive_cache/_file_listing.json
_KNOWN_FILE_EXTENSIONS = {'.csv', '.db', '.gz', '.xlsx', '.zip', '.json', '.txt'}


def _get_drive_folder_listing() -> dict:
    """
    List files in the public Drive folder. Returns {filename: (file_id, size_bytes)}.

    Priority:
      1. In-memory cache
      2. Disk cache (valid 24 hours)
      3. gdown.download_folder(..., skip_download=True)
      4. HTML scraping (fragile, fallback only)
    """
    global _folder_listing_cache
    if _folder_listing_cache is not None:
        return _folder_listing_cache

    cache_dir = os.path.join(os.path.expanduser("~"), ".antibiotic_gdrive_cache")
    os.makedirs(cache_dir, exist_ok=True)
    listing_path = os.path.join(cache_dir, '_file_listing.json')

    # Check disk cache (valid for 24 hours)
    if os.path.exists(listing_path):
        try:
            import json as _json
            mtime = os.path.getmtime(listing_path)
            age_hours = (time.time() - mtime) / 3600
            if age_hours < 24:
                with open(listing_path) as f:
                    data = _json.load(f)
                _folder_listing_cache = {k: tuple(v) for k, v in data.items()}
                return _folder_listing_cache
        except Exception:
            pass

    # Strategy 1: gdown folder listing via API (no download, just metadata)
    result = _gdown_list_folder()

    # Strategy 2: HTML scraping fallback
    if not result:
        result = _scrape_drive_folder_html()

    if result:
        _folder_listing_cache = result
        import json as _json
        with open(listing_path, 'w') as f:
            _json.dump({k: list(v) for k, v in result.items()}, f)
        logger.info(f"  [DataManager] Found {len(result)} files in public Drive folder")

    return result or {}


def _gdown_list_folder() -> dict:
    """Use gdown's Google Drive API to list folder contents (no file downloads)."""
    if not _gdown_available():
        return {}

    try:
        import gdown
        url = f"https://drive.google.com/drive/folders/{PUBLIC_DRIVE_FOLDER_ID}"

        # gdown >= 4.6 supports return_list=True
        if hasattr(gdown, 'download_folder'):
            import tempfile
            with tempfile.TemporaryDirectory() as tmpdir:
                try:
                    # Some gdown versions support skip_download
                    filenames = gdown.download_folder(
                        url, output=tmpdir, quiet=True,
                        skip_download=True
                    )
                except TypeError:
                    # Older gdown: no skip_download param
                    # Use the folder listing from gdown internals
                    filenames = None

                if filenames and isinstance(filenames, list):
                    result = {}
                    for f in filenames:
                        name = os.path.basename(f) if isinstance(f, str) else str(f)
                        ext = os.path.splitext(name)[1].lower()
                        if ext in _KNOWN_FILE_EXTENSIONS:
                            # File ID unknown from this path, but name is known
                            result[name] = ('', 0)
                    if result:
                        logger.info(f"  [DataManager] gdown folder API listed {len(result)} files")
                        return result
    except Exception as e:
        logger.debug(f"  [DataManager] gdown folder listing failed: {e}")

    return {}


def _scrape_drive_folder_html() -> dict:
    """Extract file IDs from Google Drive folder page's embedded JSON data.

    Google Drive embeds file metadata in JavaScript callbacks within the HTML.
    This is more reliable than regex on HTML tags (which fails on JS-rendered pages).
    """
    try:
        import requests
        import re
        import json as _json

        logger.info(f"  [DataManager] Fetching public Drive folder metadata...")
        url = f"https://drive.google.com/drive/folders/{PUBLIC_DRIVE_FOLDER_ID}"
        resp = requests.get(url, timeout=30, headers={
            'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
        })

        if resp.status_code != 200:
            logger.debug(f"  [DataManager] Folder page returned HTTP {resp.status_code}")
            return {}

        result = {}
        text = resp.text

        # Method 1: Parse AF_initDataCallback JSON blobs
        # Google embeds data as: AF_initDataCallback({key:'ds:N', data:[...]})
        # File entries contain [file_id, filename, mimetype, ...]
        callback_pattern = re.compile(
            r'AF_initDataCallback\(\{[^}]*data:\s*(\[.+?\])\s*\}\s*\)',
            re.DOTALL
        )
        for cb_match in callback_pattern.finditer(text):
            try:
                blob = cb_match.group(1)
                # Look for arrays containing Google Drive file ID patterns
                # File IDs are 33+ char strings, followed by filename strings
                id_name_pairs = re.findall(
                    r'\["(1[\w_-]{20,50})","([^"]+?\.\w{2,5})"',
                    blob
                )
                for fid, fname in id_name_pairs:
                    ext = os.path.splitext(fname)[1].lower()
                    if ext in _KNOWN_FILE_EXTENSIONS and len(fid) > 20:
                        result[fname] = (fid, 0)
            except Exception:
                continue

        # Method 2: Look for file IDs in any JSON-like structure in the page
        if not result:
            # Pattern: "FILE_ID","filename.ext" anywhere in the page
            pairs = re.findall(
                r'"(1[\w_-]{25,50})"\s*,\s*"([^"]{3,80}\.(?:csv|zip|json|xlsx|txt|db|gz))"',
                text
            )
            for fid, fname in pairs:
                if len(fid) > 20:
                    result[fname] = (fid, 0)

        # Method 3: Look for /file/d/ID patterns with nearby filenames
        if not result:
            dl_matches = re.findall(
                r'/file/d/([\w-]{25,50})[^"]*?["\s,]([^"<>\s]{3,80}\.(?:csv|zip|json|xlsx|txt|db|gz))',
                text
            )
            for fid, fname in dl_matches:
                result[fname] = (fid, 0)

        if result:
            logger.info(f"  [DataManager] Found {len(result)} files in Drive folder: "
                         f"{', '.join(sorted(result.keys())[:5])}...")
        else:
            logger.debug(f"  [DataManager] Could not extract file IDs from Drive page "
                          f"({len(text)} bytes, {text.count('AF_initDataCallback')} callbacks)")

        return result

    except Exception as e:
        logger.debug(f"  [DataManager] Drive folder metadata fetch failed: {e}")

    return {}


def _is_colab() -> bool:
    """Detect if running in Google Colab (Drive is mounted, no need for gdown)."""
    try:
        import google.colab
        return True
    except ImportError:
        return False


def _detect_platform() -> str:
    """Detect the current platform for output versioning."""
    if _is_colab():
        return "colab"
    import platform
    system = platform.system().lower()
    if system == "darwin":
        return "mac"
    elif system == "linux":
        # Check for Ada HPC markers
        hostname = platform.node().lower()
        if "ada" in hostname or "iiit" in hostname:
            return "ada"
        if os.path.exists("/etc/slurm") or os.environ.get("SLURM_JOB_ID"):
            return "ada"
        return "ubuntu"
    elif system == "windows":
        return "windows"
    return system


def _rclone_available() -> bool:
    """Check if rclone is installed and configured with our remote."""
    try:
        result = subprocess.run(
            ['rclone', 'listremotes'],
            capture_output=True, text=True, timeout=10
        )
        return RCLONE_REMOTE + ':' in result.stdout
    except Exception:
        return False


def rclone_upload(local_path: str, remote_subpath: str) -> bool:
    """
    Upload a file to Google Drive via rclone.

    Parameters
    ----------
    local_path : str
        Local file to upload.
    remote_subpath : str
        Path relative to the Drive folder root
        (e.g., 'antibiotic_output/mac_20260314_run_xxx/results.zip').
    """
    if not _rclone_available():
        return False
    if not os.path.exists(local_path):
        return False

    remote_dest = f"{RCLONE_REMOTE}:{remote_subpath}"
    try:
        size_mb = os.path.getsize(local_path) / (1024 * 1024)
        logger.info(f"  [rclone] Uploading {os.path.basename(local_path)} ({size_mb:.1f} MB) to {remote_dest}")
        result = subprocess.run(
            ['rclone', 'copyto', local_path, remote_dest,
             '--progress', '--retries', '3'],
            capture_output=True, text=True, timeout=600
        )
        if result.returncode == 0:
            logger.info(f"  [rclone] Upload complete: {remote_dest}")
            return True
        else:
            logger.warning(f"  [rclone] Upload failed: {result.stderr[:200]}")
            return False
    except Exception as e:
        logger.warning(f"  [rclone] Upload error: {e}")
        return False


def rclone_upload_dir(local_dir: str, remote_subpath: str) -> bool:
    """Upload an entire directory to Drive via rclone."""
    if not _rclone_available():
        return False
    if not os.path.isdir(local_dir):
        return False

    remote_dest = f"{RCLONE_REMOTE}:{remote_subpath}"
    try:
        logger.info(f"  [rclone] Uploading directory to {remote_dest}...")
        result = subprocess.run(
            ['rclone', 'copy', local_dir, remote_dest,
             '--progress', '--retries', '3'],
            capture_output=True, text=True, timeout=1200
        )
        if result.returncode == 0:
            logger.info(f"  [rclone] Directory upload complete")
            return True
        else:
            logger.warning(f"  [rclone] Directory upload failed: {result.stderr[:200]}")
            return False
    except Exception as e:
        logger.warning(f"  [rclone] Directory upload error: {e}")
        return False


def rclone_download(remote_subpath: str, local_path: str) -> bool:
    """Download a file from Google Drive via rclone."""
    if not _rclone_available():
        return False

    remote_src = f"{RCLONE_REMOTE}:{remote_subpath}"
    try:
        os.makedirs(os.path.dirname(local_path) or '.', exist_ok=True)
        result = subprocess.run(
            ['rclone', 'copyto', remote_src, local_path,
             '--retries', '3'],
            capture_output=True, text=True, timeout=600
        )
        if result.returncode == 0 and os.path.exists(local_path):
            size_mb = os.path.getsize(local_path) / (1024 * 1024)
            logger.info(f"  [rclone] Downloaded: {os.path.basename(local_path)} ({size_mb:.1f} MB)")
            return True
        return False
    except Exception:
        return False


class DataManager:
    """
    Manages data files with local-first, Drive-second, network-last priority.

    Usage:
        dm = get_data_manager()

        # Check if file exists (local or Drive):
        path = dm.resolve("chembl/ecoli_activity.csv", local_dir=config.CHEMBL_DIR)
        if path:
            df = pd.read_csv(path)  # Found locally or restored from Drive

        # After creating/downloading a file, push to Drive:
        dm.push(local_path)

        # Push pipeline outputs:
        dm.push_outputs(results_dir, run_id)
    """

    def __init__(self, drive_root: Optional[str] = None):
        self.drive_root = drive_root or self._find_drive()
        if self.drive_root:
            self.backup_dir = os.path.join(self.drive_root, BACKUP_FOLDER)
            os.makedirs(self.backup_dir, exist_ok=True)
            logger.info(f"  [DataManager] Drive: {self.backup_dir}")
        else:
            self.backup_dir = None
            logger.debug("  [DataManager] No Google Drive found. Drive backup disabled.")

    @property
    def available(self) -> bool:
        return self.backup_dir is not None

    # ---- Drive detection ----

    def _find_drive(self) -> Optional[str]:
        env_root = os.environ.get("ANTIBIOTIC_GDRIVE_ROOT")
        if env_root and os.path.isdir(env_root):
            return env_root

        import glob as _glob
        for pattern in _DRIVE_CANDIDATES:
            expanded = os.path.expanduser(pattern)
            matches = _glob.glob(expanded)
            for m in matches:
                if os.path.isdir(m):
                    return m
        return None

    # ---- Core: resolve (local -> Drive -> gdown -> rclone -> None) ----

    def resolve(self, filename: str, local_dir: str) -> Optional[str]:
        """
        Find a file with full priority chain. Returns local path or None.

        Priority:
          1. Local disk (instant, with content validation)
          2. Mounted Google Drive folder (Colab or Drive for Desktop)
          3. Public Google Drive link via gdown (non-Colab only)
          4. rclone from antibiotic_data (Ada or any configured machine)
          5. Returns None (caller downloads from original source)

        On Colab, steps 3-4 are skipped because Drive is already mounted.
        """
        basename = os.path.basename(filename)
        local_path = os.path.join(local_dir, basename)
        file_ext = os.path.splitext(basename)[1].lower()

        # 1. Local (with content validation to catch poisoned HTML files)
        if os.path.exists(local_path) and os.path.getsize(local_path) > 0:
            if _validate_downloaded_file(local_path, file_ext):
                return local_path
            else:
                logger.warning(f"  [DataManager] Local file invalid (HTML?): {local_path}")

        # 2. Mounted Drive (Colab gets data here; Mac/Win via Drive for Desktop)
        if self.available:
            drive_path = os.path.join(self.backup_dir, basename)
            if os.path.exists(drive_path) and os.path.getsize(drive_path) > 0:
                if _validate_downloaded_file(drive_path, file_ext):
                    try:
                        size_mb = os.path.getsize(drive_path) / (1024 * 1024)
                        logger.info(f"  [DataManager] Restoring from mounted Drive: {basename} ({size_mb:.1f} MB)")
                        os.makedirs(local_dir, exist_ok=True)
                        shutil.copy2(drive_path, local_path)
                        return local_path
                    except Exception as e:
                        logger.warning(f"  [DataManager] Mounted Drive restore failed: {e}")

        # 3. Public Drive link via gdown (non-Colab only; read-only download)
        if not _is_colab():
            try:
                os.makedirs(local_dir, exist_ok=True)
                if download_from_public_drive(basename, local_path):
                    # download_from_public_drive already validates content
                    return local_path
            except Exception as e:
                logger.debug(f"  [DataManager] gdown download skipped: {e}")

        # 4. rclone from antibiotic_data (Ada with rclone configured)
        if not _is_colab() and _rclone_available():
            try:
                os.makedirs(local_dir, exist_ok=True)
                remote_path = f"antibiotic_data/{basename}"
                if rclone_download(remote_path, local_path):
                    if _validate_downloaded_file(local_path, file_ext):
                        return local_path
            except Exception as e:
                logger.debug(f"  [DataManager] rclone download skipped: {e}")

        return None

    # ---- Push to Drive ----

    def push(self, local_path: str, subfolder: str = "") -> bool:
        """
        Copy a local file to Drive backup.

        Priority: mounted Drive (fast copy) -> rclone (authenticated upload).
        Skips if Drive already has same-size copy.
        """
        if not os.path.exists(local_path):
            return False

        basename = os.path.basename(local_path)

        # 1. Mounted Drive (Colab, Mac with Drive for Desktop)
        if self.available:
            if subfolder:
                dest_dir = os.path.join(self.backup_dir, subfolder)
                os.makedirs(dest_dir, exist_ok=True)
            else:
                dest_dir = self.backup_dir
            dest = os.path.join(dest_dir, basename)

            local_size = os.path.getsize(local_path)
            if os.path.exists(dest) and os.path.getsize(dest) == local_size:
                return True

            try:
                size_mb = local_size / (1024 * 1024)
                if size_mb > 100:
                    logger.info(f"  [DataManager] Uploading to mounted Drive: {basename} ({size_mb:.0f} MB)...")
                else:
                    logger.info(f"  [DataManager] Uploading to mounted Drive: {basename} ({size_mb:.1f} MB)")
                shutil.copy2(local_path, dest)
                self._flush()
                return True
            except Exception as e:
                logger.warning(f"  [DataManager] Mounted Drive push failed: {e}")

        # 2. rclone (Ada, any platform without mounted Drive)
        if subfolder:
            remote_path = f"antibiotic_data/{subfolder}/{basename}"
        else:
            remote_path = f"antibiotic_data/{basename}"
        return rclone_upload(local_path, remote_path)

    # ---- ChEMBL SQLite special handling ----

    def resolve_chembl_sqlite(self) -> Optional[str]:
        """
        Find ChEMBL 34 SQLite DB with full priority chain.

        Priority:
          1. Local pystow cache (~instant)
          2. Mounted Drive .db (fast copy)
          3. Mounted Drive tar.gz (extract locally)
          4. Public Drive link: tar.gz (~1GB download, then extract)
          5. Returns None (caller downloads via chembl_downloader)
        """
        # 1. Check pystow cache (local)
        try:
            import pystow
            pystow_dir = str(pystow.join("chembl", "34"))
            for root, dirs, files in os.walk(pystow_dir):
                for f in files:
                    if f.endswith('.db') and 'chembl' in f.lower():
                        fp = os.path.join(root, f)
                        if os.path.getsize(fp) > 1_000_000_000:
                            logger.debug(f"  [DataManager] ChEMBL SQLite in pystow: {fp}")
                            return fp
        except Exception:
            pass

        # 2. Check mounted Drive for extracted .db
        if self.available:
            drive_db = os.path.join(self.backup_dir, "chembl_34.db")
            if os.path.exists(drive_db) and os.path.getsize(drive_db) > 1_000_000_000:
                logger.info(f"  [DataManager] Using ChEMBL SQLite from mounted Drive")
                # On Colab, query directly from Drive mount
                if '/content/drive' in drive_db:
                    return drive_db
                # On Mac/Linux, copy to pystow cache for speed
                try:
                    import pystow
                    local_target = os.path.join(str(pystow.join("chembl", "34")), "chembl_34.db")
                    if not os.path.exists(local_target):
                        size_gb = os.path.getsize(drive_db) / (1024**3)
                        logger.info(f"  [DataManager] Copying to local cache ({size_gb:.1f} GB)...")
                        os.makedirs(os.path.dirname(local_target), exist_ok=True)
                        shutil.copy2(drive_db, local_target)
                    return local_target
                except Exception as e:
                    logger.warning(f"  [DataManager] Local cache failed, using Drive directly: {e}")
                    return drive_db

        # 3. Check mounted Drive for tar.gz (extract without network)
        if self.available:
            drive_targz = os.path.join(self.backup_dir, "chembl_34_sqlite.tar.gz")
            if os.path.exists(drive_targz) and os.path.getsize(drive_targz) > 500_000_000:
                db_path = self._extract_chembl_targz(drive_targz)
                if db_path:
                    return db_path

        # 4. rclone: download tar.gz (~1GB) from Drive (non-Colab only)
        #    gdown refuses files > 50MB; rclone handles large files properly
        if not _is_colab() and _rclone_available():
            try:
                import pystow
                local_targz = os.path.join(str(pystow.join("chembl", "34")), "chembl_34_sqlite.tar.gz")
                if not os.path.exists(local_targz) or os.path.getsize(local_targz) < 500_000_000:
                    logger.info(f"  [DataManager] Downloading ChEMBL tar.gz via rclone (~1 GB)...")
                    if rclone_download("antibiotic_data/chembl_34_sqlite.tar.gz", local_targz):
                        db_path = self._extract_chembl_targz(local_targz)
                        if db_path:
                            return db_path
            except Exception as e:
                logger.debug(f"  [DataManager] rclone ChEMBL download skipped: {e}")

        # 5. chembl_downloader (last resort: downloads ~1GB from EBI FTP)
        #    This is only reached if local, mounted Drive, AND rclone all failed

        return None

    def _extract_chembl_targz(self, targz_path: str) -> Optional[str]:
        """Extract ChEMBL tar.gz and return path to .db file."""
        try:
            import tarfile, pystow
            extract_dir = str(pystow.join("chembl", "34"))
            os.makedirs(extract_dir, exist_ok=True)
            logger.info(f"  [DataManager] Extracting ChEMBL tar.gz...")
            with tarfile.open(targz_path, 'r:gz') as tar:
                tar.extractall(extract_dir)
            for root, dirs, files in os.walk(extract_dir):
                for f in files:
                    if f.endswith('.db') and 'chembl' in f.lower():
                        fp = os.path.join(root, f)
                        if os.path.getsize(fp) > 1_000_000_000:
                            logger.info(f"  [DataManager] Extracted: {fp}")
                            return fp
        except Exception as e:
            logger.warning(f"  [DataManager] tar.gz extraction failed: {e}")
        return None

    def push_chembl_sqlite(self, db_path: str, targz_path: Optional[str] = None) -> None:
        """Push both the .db and tar.gz to Drive."""
        if not self.available:
            return

        # Push .db
        if db_path and os.path.exists(str(db_path)):
            dest_db = os.path.join(self.backup_dir, "chembl_34.db")
            if not os.path.exists(dest_db) or \
               os.path.getsize(dest_db) != os.path.getsize(str(db_path)):
                size_gb = os.path.getsize(str(db_path)) / (1024**3)
                logger.info(f"  [DataManager] Uploading chembl_34.db to Drive ({size_gb:.1f} GB)...")
                try:
                    shutil.copy2(str(db_path), dest_db)
                    self._flush()
                except Exception as e:
                    logger.warning(f"  [DataManager] DB upload failed: {e}")

        # Push tar.gz
        if targz_path and os.path.exists(str(targz_path)):
            dest_tgz = os.path.join(self.backup_dir, "chembl_34_sqlite.tar.gz")
            if not os.path.exists(dest_tgz) or \
               os.path.getsize(dest_tgz) != os.path.getsize(str(targz_path)):
                size_mb = os.path.getsize(str(targz_path)) / (1024**2)
                logger.info(f"  [DataManager] Uploading tar.gz to Drive ({size_mb:.0f} MB)...")
                try:
                    shutil.copy2(str(targz_path), dest_tgz)
                    self._flush()
                except Exception as e:
                    logger.warning(f"  [DataManager] tar.gz upload failed: {e}")

    # ---- Maier raw Excel files ----

    def resolve_maier_excel(self, local_maier_dir: str) -> bool:
        """
        Ensure Maier Excel files exist locally. Checks Drive if missing.
        Returns True if at least the critical MOESM5 file exists.
        """
        moesm5 = "41586_2018_BFnature25979_MOESM5_ESM.xlsx"
        if os.path.exists(os.path.join(local_maier_dir, moesm5)):
            return True

        if not self.available:
            return False

        drive_maier = os.path.join(self.backup_dir, "raw_maier")
        if not os.path.isdir(drive_maier):
            return False

        import glob
        xlsx_files = glob.glob(os.path.join(drive_maier, "*.xlsx"))
        if not xlsx_files:
            return False

        logger.info(f"  [DataManager] Restoring {len(xlsx_files)} Maier Excel files from Drive...")
        os.makedirs(local_maier_dir, exist_ok=True)
        for f in xlsx_files:
            dest = os.path.join(local_maier_dir, os.path.basename(f))
            if not os.path.exists(dest):
                shutil.copy2(f, dest)
        return os.path.exists(os.path.join(local_maier_dir, moesm5))

    def push_maier_excel(self, local_maier_dir: str) -> None:
        """Push raw Maier Excel files to Drive."""
        if not self.available:
            return
        import glob
        xlsx_files = glob.glob(os.path.join(local_maier_dir, "*.xlsx"))
        if not xlsx_files:
            return
        drive_maier = os.path.join(self.backup_dir, "raw_maier")
        os.makedirs(drive_maier, exist_ok=True)
        for f in xlsx_files:
            dest = os.path.join(drive_maier, os.path.basename(f))
            if not os.path.exists(dest):
                shutil.copy2(f, dest)
        self._flush()

    # ---- Output management ----

    def push_outputs(self, results_dir: str, run_id: str) -> Optional[str]:
        """
        ZIP pipeline outputs, save locally, and push to Drive.

        Outputs are versioned by platform and date:
          antibiotic_output/{platform}_{YYYYMMDD}_{run_id}/
            results.zip
            cv_metrics_diagnostic.csv  (key files copied individually)
            test1_rank_separation.csv
            ...

        All past versions are preserved on Drive. Never overwrites.

        Returns the local ZIP path.
        """
        if not os.path.isdir(results_dir):
            return None

        platform = _detect_platform()
        date_str = time.strftime("%Y%m%d")
        version_name = f"{platform}_{date_str}_{run_id}"

        # Create local ZIP
        zip_base = os.path.join(os.path.dirname(results_dir), f"{run_id}_results")
        try:
            zip_path = shutil.make_archive(zip_base, 'zip', results_dir)
            size_mb = os.path.getsize(zip_path) / (1024 * 1024)
            logger.info(f"  [DataManager] Results packaged: {zip_path} ({size_mb:.1f} MB)")
        except Exception as e:
            logger.warning(f"  [DataManager] ZIP creation failed: {e}")
            return None

        # Push to Drive under antibiotic_output/{version_name}/
        if self.available:
            try:
                # antibiotic_output is a sibling of antibiotic_data on Drive
                drive_root = os.path.dirname(self.backup_dir)
                output_base = os.path.join(drive_root, "antibiotic_output")
                version_dir = os.path.join(output_base, version_name)
                os.makedirs(version_dir, exist_ok=True)

                # Copy ZIP
                shutil.copy2(zip_path, os.path.join(version_dir, "results.zip"))
                logger.info(f"  [DataManager] Output ZIP -> Drive: antibiotic_output/{version_name}/results.zip")

                # Copy key CSVs individually for easy browsing
                key_files = [
                    'cv_metrics_diagnostic.csv',
                    'test1_rank_separation.csv',
                    'test2_selectivity_auc.csv',
                    'test3_topk_enrichment.csv',
                    'test5_threshold_sensitivity.csv',
                    'validation_set.csv',
                ]
                for kf in key_files:
                    src = os.path.join(results_dir, kf)
                    if os.path.exists(src):
                        shutil.copy2(src, os.path.join(version_dir, kf))

                # Copy figures subfolder
                fig_src = os.path.join(results_dir, 'figures')
                fig_dst = os.path.join(version_dir, 'figures')
                if os.path.isdir(fig_src):
                    if os.path.exists(fig_dst):
                        shutil.rmtree(fig_dst)
                    shutil.copytree(fig_src, fig_dst)

                self._flush()
                logger.info(f"  [DataManager] Full output -> Drive: antibiotic_output/{version_name}/")

                # List all versions on Drive
                if os.path.isdir(output_base):
                    versions = sorted(os.listdir(output_base))
                    if versions:
                        logger.info(f"  [DataManager] All output versions on Drive ({len(versions)}):")
                        for v in versions:
                            vp = os.path.join(output_base, v)
                            if os.path.isdir(vp):
                                n = sum(1 for _, _, fs in os.walk(vp) for _ in fs)
                                logger.info(f"    {v}/ ({n} files)")

            except Exception as e:
                logger.warning(f"  [DataManager] Mounted Drive output upload failed: {e}")

        elif _rclone_available():
            # Fall back to rclone for platforms without mounted Drive (Ada)
            try:
                import tempfile
                staging = tempfile.mkdtemp(prefix="pipeline_output_")

                # Stage ZIP
                shutil.copy2(zip_path, os.path.join(staging, "results.zip"))

                # Stage key CSVs
                key_files = [
                    'cv_metrics_diagnostic.csv',
                    'test1_rank_separation.csv',
                    'test2_selectivity_auc.csv',
                    'test3_topk_enrichment.csv',
                    'test5_threshold_sensitivity.csv',
                    'validation_set.csv',
                ]
                for kf in key_files:
                    src = os.path.join(results_dir, kf)
                    if os.path.exists(src):
                        shutil.copy2(src, os.path.join(staging, kf))

                # Stage figures
                fig_src = os.path.join(results_dir, 'figures')
                if os.path.isdir(fig_src):
                    shutil.copytree(fig_src, os.path.join(staging, 'figures'))

                # Upload entire staging dir via rclone
                remote_path = f"antibiotic_output/{version_name}"
                rclone_upload_dir(staging, remote_path)
                logger.info(f"  [DataManager] Output uploaded via rclone: {remote_path}/")

                shutil.rmtree(staging, ignore_errors=True)
            except Exception as e:
                logger.warning(f"  [DataManager] rclone output upload failed: {e}")

        return zip_path

    # ---- Drive flush ----

    def _flush(self):
        """Force filesystem sync (important for Colab Drive mount)."""
        try:
            subprocess.run(['sync'], timeout=120, capture_output=True)
        except Exception:
            pass

    def flush(self, label: str = ""):
        """Public flush with logging."""
        if not self.available:
            return
        if label:
            logger.info(f"  [DataManager] Flushing Drive ({label})...")
        try:
            subprocess.run(['sync'], timeout=300, capture_output=True)
            # Touch sentinel to trigger Drive sync
            sentinel = os.path.join(self.backup_dir, '.sync_check')
            with open(sentinel, 'w') as f:
                f.write(f'last_sync={time.strftime("%Y-%m-%d %H:%M:%S")}')
            subprocess.run(['sync'], timeout=300, capture_output=True)
            time.sleep(1)
        except Exception:
            pass

    # ---- Status ----

    def status(self) -> dict:
        if not self.available:
            return {"available": False}
        files = {}
        if os.path.isdir(self.backup_dir):
            for f in os.listdir(self.backup_dir):
                fp = os.path.join(self.backup_dir, f)
                if os.path.isfile(fp):
                    files[f] = os.path.getsize(fp)
        return {
            "available": True,
            "path": self.backup_dir,
            "files": files,
            "total_mb": sum(files.values()) / (1024 * 1024) if files else 0,
        }

    # ---- ZIP pack/unpack for data bundles ----

    def pack_data_csvs(self, project_dir: str) -> Optional[str]:
        """
        ZIP all processed data CSVs into antibiotic_data_csvs.zip.
        Saves locally + pushes to Drive.
        Returns ZIP path.
        """
        import zipfile
        data_dir = os.path.join(project_dir, 'data')
        if not os.path.isdir(data_dir):
            return None

        zip_path = os.path.join(project_dir, 'antibiotic_data_csvs.zip')

        csv_files = []
        for root, dirs, files in os.walk(data_dir):
            for f in files:
                if f.endswith('.csv') or f.endswith('.json'):
                    csv_files.append(os.path.join(root, f))
        if not csv_files:
            return None

        try:
            with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
                for fp in csv_files:
                    arcname = os.path.relpath(fp, project_dir)
                    zf.write(fp, arcname)
            size_mb = os.path.getsize(zip_path) / (1024 * 1024)
            logger.info(f"  [DataManager] Packed {len(csv_files)} data files -> {zip_path} ({size_mb:.1f} MB)")
            self.push(zip_path)
            return zip_path
        except Exception as e:
            logger.warning(f"  [DataManager] pack_data_csvs failed: {e}")
            return None

    def pack_features(self, project_dir: str) -> Optional[str]:
        """
        ZIP all Morgan FPs + scaffold splits into antibiotic_features.zip.
        Saves locally + pushes to Drive.
        Returns ZIP path.
        """
        import zipfile

        # Determine shared dir (could be outputs/shared or synthetic/outputs/shared)
        mode = os.environ.get('ANTIBIOTIC_DATA_MODE', 'real')
        if mode == 'synthetic':
            shared_dir = os.path.join(project_dir, 'synthetic', 'outputs', 'shared')
        else:
            shared_dir = os.path.join(project_dir, 'outputs', 'shared')

        features_dir = os.path.join(shared_dir, 'features')
        splits_dir = os.path.join(shared_dir, 'splits')

        files_to_zip = []
        for d in [features_dir, splits_dir]:
            if os.path.isdir(d):
                for f in os.listdir(d):
                    fp = os.path.join(d, f)
                    if os.path.isfile(fp):
                        files_to_zip.append(fp)

        if not files_to_zip:
            return None

        zip_name = 'antibiotic_features_synthetic.zip' if mode == 'synthetic' else 'antibiotic_features.zip'
        zip_path = os.path.join(project_dir, zip_name)

        try:
            with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
                for fp in files_to_zip:
                    arcname = os.path.relpath(fp, shared_dir)
                    zf.write(fp, arcname)
            size_mb = os.path.getsize(zip_path) / (1024 * 1024)
            logger.info(f"  [DataManager] Packed {len(files_to_zip)} feature files -> {zip_path} ({size_mb:.1f} MB)")
            self.push(zip_path)
            return zip_path
        except Exception as e:
            logger.warning(f"  [DataManager] pack_features failed: {e}")
            return None

    def restore_data_csvs(self, project_dir: str) -> bool:
        """
        Restore data CSVs from ZIP. Checks: local ZIP -> Drive ZIP -> returns False.

        Unzips to project_dir/ preserving data/chembl/, data/maier/, data/repurposing_hub/.
        """
        import zipfile
        zip_name = 'antibiotic_data_csvs.zip'
        zip_path = os.path.join(project_dir, zip_name)

        # Check if already has data (skip if all CSVs exist)
        try:
            import sys
            if 'scripts' not in sys.path[0]:
                sys.path.insert(0, os.path.join(project_dir, 'scripts'))
            import importlib
            cfg = importlib.import_module('config')
            all_exist = True
            for pinfo in cfg.PATHOGENS.values():
                if not os.path.exists(os.path.join(cfg.CHEMBL_DIR, pinfo['csv_filename'])):
                    all_exist = False; break
            if all_exist and os.path.exists(os.path.join(cfg.MAIER_DIR, 'maier_combined.csv')):
                if os.path.exists(os.path.join(cfg.HUB_DIR, cfg.HUB_CLEAN_FILENAME)):
                    logger.debug("  [DataManager] All data CSVs exist locally, skip restore")
                    return True
        except Exception:
            pass

        # Try local ZIP
        if not os.path.exists(zip_path):
            # Try Drive
            resolved = self.resolve(zip_name, project_dir)
            if resolved:
                zip_path = resolved

        if os.path.exists(zip_path):
            try:
                with zipfile.ZipFile(zip_path, 'r') as zf:
                    zf.extractall(project_dir)
                n = len(zipfile.ZipFile(zip_path).namelist())
                logger.info(f"  [DataManager] Restored {n} data files from {zip_name}")
                return True
            except Exception as e:
                logger.warning(f"  [DataManager] Unzip failed: {e}")

        return False

    def restore_features(self, project_dir: str) -> bool:
        """
        Restore Morgan FPs + splits from ZIP.
        Checks: local shared dir -> local ZIP -> Drive ZIP -> returns False.

        Unzips to outputs/shared/ (features/ and splits/).
        """
        import zipfile

        mode = os.environ.get('ANTIBIOTIC_DATA_MODE', 'real')
        if mode == 'synthetic':
            shared_dir = os.path.join(project_dir, 'synthetic', 'outputs', 'shared')
            zip_name = 'antibiotic_features_synthetic.zip'
        else:
            shared_dir = os.path.join(project_dir, 'outputs', 'shared')
            zip_name = 'antibiotic_features.zip'

        features_dir = os.path.join(shared_dir, 'features')
        splits_dir = os.path.join(shared_dir, 'splits')

        # Check if already has features
        if os.path.isdir(features_dir):
            npz_count = len([f for f in os.listdir(features_dir) if f.endswith('.npz')])
            if npz_count >= 5:
                logger.debug(f"  [DataManager] Features already exist ({npz_count} .npz files)")
                return True

        zip_path = os.path.join(project_dir, zip_name)

        # Try local ZIP
        if not os.path.exists(zip_path):
            resolved = self.resolve(zip_name, project_dir)
            if resolved:
                zip_path = resolved

        if os.path.exists(zip_path):
            try:
                os.makedirs(shared_dir, exist_ok=True)
                with zipfile.ZipFile(zip_path, 'r') as zf:
                    zf.extractall(shared_dir)
                n = len(zipfile.ZipFile(zip_path).namelist())
                logger.info(f"  [DataManager] Restored {n} feature files from {zip_name}")
                return True
            except Exception as e:
                logger.warning(f"  [DataManager] Feature unzip failed: {e}")

        return False

    # ---- ZIP pack/unpack for trained RF models ----

    def pack_rf_models(self, project_dir: str) -> Optional[str]:
        """
        ZIP all trained RF models + CV metrics + screening lists.
        These are deterministic given same data + features, so cache them.
        """
        import zipfile

        mode = os.environ.get('ANTIBIOTIC_DATA_MODE', 'real')
        if mode == 'synthetic':
            runs_dir = os.path.join(project_dir, 'synthetic', 'outputs', 'runs')
        else:
            runs_dir = os.path.join(project_dir, 'outputs', 'runs')

        # Find the latest successful run
        latest = os.path.join(os.path.dirname(runs_dir), 'latest')
        if os.path.islink(latest):
            run_dir = os.path.realpath(latest)
        else:
            # Find most recent run dir
            run_dirs = sorted([d for d in os.listdir(runs_dir) if d.startswith('run_')]) if os.path.isdir(runs_dir) else []
            if not run_dirs:
                return None
            run_dir = os.path.join(runs_dir, run_dirs[-1])

        rf_dir = os.path.join(run_dir, 'models', 'rf')
        results_dir = os.path.join(run_dir, 'results')

        if not os.path.isdir(rf_dir):
            return None

        pkl_files = [f for f in os.listdir(rf_dir) if f.endswith('.pkl')]
        if len(pkl_files) < 7:
            logger.debug(f"  [DataManager] Only {len(pkl_files)} RF models, need 7. Skipping pack.")
            return None

        zip_name = 'antibiotic_rf_models_synthetic.zip' if mode == 'synthetic' else 'antibiotic_rf_models.zip'
        zip_path = os.path.join(project_dir, zip_name)

        try:
            with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
                # RF model .pkl files
                for f in os.listdir(rf_dir):
                    if f.endswith('.pkl'):
                        zf.write(os.path.join(rf_dir, f), f'models/rf/{f}')

                # CV metrics JSON
                for f in ['rf_cv_metrics.json']:
                    fp = os.path.join(results_dir, f)
                    if os.path.exists(fp):
                        zf.write(fp, f'results/{f}')

                # Screening CSVs
                screening_dir = os.path.join(results_dir, 'screening')
                if os.path.isdir(screening_dir):
                    for f in os.listdir(screening_dir):
                        if f.startswith('rf_ranked_') and f.endswith('.csv'):
                            zf.write(os.path.join(screening_dir, f), f'results/screening/{f}')

            size_mb = os.path.getsize(zip_path) / (1024 * 1024)
            n_files = len(zipfile.ZipFile(zip_path).namelist())
            logger.info(f"  [DataManager] Packed {n_files} RF model files -> {zip_name} ({size_mb:.1f} MB)")
            self.push(zip_path)
            return zip_path
        except Exception as e:
            logger.warning(f"  [DataManager] pack_rf_models failed: {e}")
            return None

    def restore_rf_models(self, project_dir: str) -> bool:
        """
        Restore RF models + metrics + screening lists from ZIP.
        Unzips into the current run's directory.
        """
        import zipfile

        mode = os.environ.get('ANTIBIOTIC_DATA_MODE', 'real')
        run_id = os.environ.get('ANTIBIOTIC_RUN_ID', '')
        if mode == 'synthetic':
            run_dir = os.path.join(project_dir, 'synthetic', 'outputs', 'runs', run_id)
        else:
            run_dir = os.path.join(project_dir, 'outputs', 'runs', run_id)

        rf_dir = os.path.join(run_dir, 'models', 'rf')

        # Check if already has models
        if os.path.isdir(rf_dir):
            pkl_count = len([f for f in os.listdir(rf_dir) if f.endswith('.pkl')])
            if pkl_count >= 7:
                logger.debug(f"  [DataManager] RF models already exist ({pkl_count} .pkl files)")
                return True

        zip_name = 'antibiotic_rf_models_synthetic.zip' if mode == 'synthetic' else 'antibiotic_rf_models.zip'
        zip_path = os.path.join(project_dir, zip_name)

        # Try local ZIP, then Drive
        if not os.path.exists(zip_path):
            resolved = self.resolve(zip_name, project_dir)
            if resolved:
                zip_path = resolved

        if os.path.exists(zip_path):
            try:
                os.makedirs(run_dir, exist_ok=True)
                with zipfile.ZipFile(zip_path, 'r') as zf:
                    zf.extractall(run_dir)
                n = len(zipfile.ZipFile(zip_path).namelist())
                logger.info(f"  [DataManager] Restored {n} RF model files from {zip_name}")
                return True
            except Exception as e:
                logger.warning(f"  [DataManager] RF model unzip failed: {e}")

        return False

    # ---- ZIP pack/unpack for trained D-MPNN models ----

    def pack_dmpnn_models(self, project_dir: str) -> Optional[str]:
        """
        ZIP all trained D-MPNN model checkpoints + CV metrics + screening lists.
        """
        import zipfile

        mode = os.environ.get('ANTIBIOTIC_DATA_MODE', 'real')
        if mode == 'synthetic':
            runs_dir = os.path.join(project_dir, 'synthetic', 'outputs', 'runs')
        else:
            runs_dir = os.path.join(project_dir, 'outputs', 'runs')

        latest = os.path.join(os.path.dirname(runs_dir), 'latest')
        if os.path.islink(latest):
            run_dir = os.path.realpath(latest)
        else:
            run_dirs = sorted([d for d in os.listdir(runs_dir) if d.startswith('run_')]) if os.path.isdir(runs_dir) else []
            if not run_dirs:
                return None
            run_dir = os.path.join(runs_dir, run_dirs[-1])

        dmpnn_dir = os.path.join(run_dir, 'models', 'dmpnn')
        results_dir = os.path.join(run_dir, 'results')

        if not os.path.isdir(dmpnn_dir):
            return None

        # Collect all model files (.pt, .ckpt, config.toml)
        model_files = []
        for root, dirs, files in os.walk(dmpnn_dir):
            for f in files:
                if f.endswith(('.pt', '.ckpt', '.toml', '.json', '.yaml')):
                    model_files.append(os.path.join(root, f))

        if len(model_files) < 5:
            logger.debug(f"  [DataManager] Only {len(model_files)} D-MPNN files, likely incomplete. Skipping pack.")
            return None

        zip_name = 'antibiotic_dmpnn_models_synthetic.zip' if mode == 'synthetic' else 'antibiotic_dmpnn_models.zip'
        zip_path = os.path.join(project_dir, zip_name)

        try:
            with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
                for fp in model_files:
                    arcname = os.path.relpath(fp, run_dir)
                    zf.write(fp, arcname)

                # D-MPNN CV metrics
                for f in ['dmpnn_cv_metrics.json']:
                    fp = os.path.join(results_dir, f)
                    if os.path.exists(fp):
                        zf.write(fp, f'results/{f}')

                # D-MPNN screening CSVs
                screening_dir = os.path.join(results_dir, 'screening')
                if os.path.isdir(screening_dir):
                    for f in os.listdir(screening_dir):
                        if f.startswith('dmpnn_ranked_') and f.endswith('.csv'):
                            zf.write(os.path.join(screening_dir, f), f'results/screening/{f}')

            size_mb = os.path.getsize(zip_path) / (1024 * 1024)
            n_files = len(zipfile.ZipFile(zip_path).namelist())
            logger.info(f"  [DataManager] Packed {n_files} D-MPNN files -> {zip_name} ({size_mb:.1f} MB)")
            self.push(zip_path)
            return zip_path
        except Exception as e:
            logger.warning(f"  [DataManager] pack_dmpnn_models failed: {e}")
            return None

    def restore_dmpnn_models(self, project_dir: str) -> bool:
        """
        Restore D-MPNN models + metrics + screening lists from ZIP.
        """
        import zipfile

        mode = os.environ.get('ANTIBIOTIC_DATA_MODE', 'real')
        run_id = os.environ.get('ANTIBIOTIC_RUN_ID', '')
        if mode == 'synthetic':
            run_dir = os.path.join(project_dir, 'synthetic', 'outputs', 'runs', run_id)
        else:
            run_dir = os.path.join(project_dir, 'outputs', 'runs', run_id)

        dmpnn_dir = os.path.join(run_dir, 'models', 'dmpnn')

        # Check if already has models
        if os.path.isdir(dmpnn_dir):
            pt_count = 0
            for root, dirs, files in os.walk(dmpnn_dir):
                pt_count += len([f for f in files if f.endswith(('.pt', '.ckpt'))])
            if pt_count >= 5:
                logger.debug(f"  [DataManager] D-MPNN models already exist ({pt_count} checkpoints)")
                return True

        zip_name = 'antibiotic_dmpnn_models_synthetic.zip' if mode == 'synthetic' else 'antibiotic_dmpnn_models.zip'
        zip_path = os.path.join(project_dir, zip_name)

        if not os.path.exists(zip_path):
            resolved = self.resolve(zip_name, project_dir)
            if resolved:
                zip_path = resolved

        if os.path.exists(zip_path):
            try:
                os.makedirs(run_dir, exist_ok=True)
                with zipfile.ZipFile(zip_path, 'r') as zf:
                    zf.extractall(run_dir)
                n = len(zipfile.ZipFile(zip_path).namelist())
                logger.info(f"  [DataManager] Restored {n} D-MPNN files from {zip_name}")
                return True
            except Exception as e:
                logger.warning(f"  [DataManager] D-MPNN unzip failed: {e}")

        return False


# ---- Singleton ----
_instance = None

def get_data_manager() -> DataManager:
    global _instance
    if _instance is None:
        _instance = DataManager()
    return _instance

# Backward compat aliases
GDriveBackup = DataManager
get_backup = get_data_manager
