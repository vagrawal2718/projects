"""
Google Drive Sync for Coral Bleaching EWS
==========================================

Backs up pipeline outputs and downloaded data to Google Drive with
region-specific directory structure.

Google Drive structure:
    coral_ews/
        {region_key}/
            output/         ← reports, CSVs, visualizations
            noaa_maps/      ← NOAA CRW bleaching maps (basin-specific)
            data/           ← cached climate indices, SST data
        _comparison/        ← cross-region comparison plots

Supports three sync backends (auto-detected in order):
    1. **Mounted path** – Google Drive Desktop / Drive File Stream
       Set ``GDRIVE_MOUNT`` env var or pass ``gdrive_root``
       (e.g. ``~/Google Drive/My Drive/coral_ews``)
    2. **rclone** – if ``rclone`` is on PATH and a remote named
       ``gdrive:`` is configured
    3. **Skip** – logs a warning; no upload

Usage from pipeline:
    from coral_ews.gdrive_sync import sync_to_gdrive
    sync_to_gdrive(
        local_dir=Path("output/andaman"),
        region_key="andaman",
        gdrive_root=Path("~/Google Drive/My Drive/coral_ews"),
    )

Author: Coral Bleaching EWS Team
Date:   February 2026
"""

from __future__ import annotations

import logging
import os
import shutil
import subprocess
from pathlib import Path
from typing import Optional

logger = logging.getLogger("coral_ews.gdrive_sync")


def _find_gdrive_root(explicit_root: Optional[Path] = None) -> Optional[Path]:
    """Resolve the Google Drive root directory."""
    # 1. Explicit argument
    if explicit_root:
        p = Path(explicit_root).expanduser()
        if p.exists():
            return p
        # Try creating it
        try:
            p.mkdir(parents=True, exist_ok=True)
            return p
        except OSError:
            pass

    # 2. Environment variable
    env = os.environ.get("GDRIVE_MOUNT")
    if env:
        p = Path(env).expanduser()
        if p.exists():
            return p

    # 3. Common mount points
    for candidate in [
        Path.home() / "Google Drive" / "My Drive" / "coral_ews",
        Path.home() / "GoogleDrive" / "My Drive" / "coral_ews",
        Path("/Volumes/GoogleDrive/My Drive/coral_ews"),  # macOS
        Path.home() / "gdrive" / "coral_ews",
        Path.home() / "google-drive" / "coral_ews",
    ]:
        if candidate.parent.exists():
            candidate.mkdir(parents=True, exist_ok=True)
            return candidate

    return None


def _has_rclone() -> bool:
    """Check if rclone is available and has a gdrive remote."""
    try:
        result = subprocess.run(
            ["rclone", "listremotes"],
            capture_output=True, text=True, timeout=5)
        return "gdrive:" in result.stdout
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def _sync_via_mount(
    local_dir: Path,
    gdrive_root: Path,
    region_key: str,
    subdir: str = "",
) -> int:
    """Copy files to a mounted Google Drive path."""
    dest = gdrive_root / region_key
    if subdir:
        dest = dest / subdir
    dest.mkdir(parents=True, exist_ok=True)

    copied = 0
    for src_file in local_dir.rglob("*"):
        if src_file.is_file():
            rel = src_file.relative_to(local_dir)
            dst = dest / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            # Only copy if source is newer or different size
            if dst.exists():
                if (dst.stat().st_size == src_file.stat().st_size
                        and dst.stat().st_mtime >= src_file.stat().st_mtime):
                    continue
            shutil.copy2(src_file, dst)
            copied += 1

    return copied


def _sync_via_rclone(
    local_dir: Path,
    region_key: str,
    subdir: str = "",
    gdrive_remote: str = "gdrive:",
) -> int:
    """Sync via rclone to a Google Drive remote."""
    remote_path = f"{gdrive_remote}coral_ews/{region_key}"
    if subdir:
        remote_path += f"/{subdir}"

    cmd = [
        "rclone", "sync",
        str(local_dir),
        remote_path,
        "--update",           # skip files that are newer on dest
        "--checksum",         # use checksums instead of mod time
        "--transfers", "4",
        "--progress",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    if result.returncode != 0:
        logger.warning(f"rclone sync failed: {result.stderr}")
        return 0
    # Count transferred files from rclone output
    lines = result.stderr.split('\n')
    for line in lines:
        if 'Transferred:' in line and 'files' in line.lower():
            try:
                return int(line.split(':')[1].split('/')[0].strip())
            except (ValueError, IndexError):
                pass
    return 0


def sync_to_gdrive(
    local_dir: Path,
    region_key: str,
    gdrive_root: Optional[Path] = None,
    subdir: str = "",
) -> bool:
    """
    Sync a local directory to Google Drive.

    Parameters
    ----------
    local_dir : Path
        Local directory to sync (e.g. ``output/andaman``)
    region_key : str
        Region identifier (e.g. ``'andaman'``, ``'great_barrier_reef'``)
    gdrive_root : Path, optional
        Google Drive mount point. Auto-detected if not provided.
    subdir : str, optional
        Subdirectory within the region folder (e.g. ``'noaa_maps'``).

    Returns
    -------
    bool
        True if sync succeeded, False otherwise.
    """
    if not local_dir.exists():
        logger.warning(f"Local dir does not exist: {local_dir}")
        return False

    # Try mounted path first
    root = _find_gdrive_root(gdrive_root)
    if root:
        try:
            n = _sync_via_mount(local_dir, root, region_key, subdir)
            target = root / region_key / subdir if subdir else root / region_key
            logger.info(
                f"Google Drive sync (mount): {n} files → {target}")
            return True
        except Exception as e:
            logger.warning(f"Mounted sync failed: {e}")

    # Try rclone
    if _has_rclone():
        try:
            n = _sync_via_rclone(local_dir, region_key, subdir)
            logger.info(f"Google Drive sync (rclone): {n} files uploaded")
            return True
        except Exception as e:
            logger.warning(f"rclone sync failed: {e}")

    logger.warning(
        "Google Drive sync skipped — no mounted drive or rclone found.\n"
        "  To enable sync, either:\n"
        "  1. Set GDRIVE_MOUNT env var to your Google Drive path\n"
        "  2. Install rclone and configure a 'gdrive:' remote\n"
        "  3. Pass gdrive_root= to sync_to_gdrive()")
    return False


def sync_pipeline_outputs(
    config,
    gdrive_root: Optional[Path] = None,
) -> bool:
    """
    Sync all pipeline outputs for a region to Google Drive.

    Called at end of ``run_full_workflow``.  Syncs:
      - output/{region}/     → coral_ews/{region}/output/
      - data/noaa_maps/      → coral_ews/{region}/noaa_maps/
      - data/climate_indices → coral_ews/{region}/data/

    Parameters
    ----------
    config : Config
        Pipeline config with output_dir and data_dir.
    gdrive_root : Path, optional
        Google Drive root. Auto-detected if not provided.
    """
    region_key = getattr(config, 'region_key', None)
    if not region_key:
        # Derive from region name
        region_key = getattr(config.region, 'name', 'unknown').lower()
        region_key = region_key.replace(' ', '_').replace('&', 'and')
        region_key = region_key.replace('–', '-').replace('—', '-')

    success = True

    # 1. Sync outputs (reports, CSVs, visualizations)
    if config.output_dir.exists():
        ok = sync_to_gdrive(
            config.output_dir, region_key, gdrive_root, subdir="output")
        success = success and ok

    # 2. Sync NOAA maps
    noaa_dir = config.data_dir / "noaa_maps"
    if noaa_dir.exists():
        ok = sync_to_gdrive(
            noaa_dir, region_key, gdrive_root, subdir="noaa_maps")
        success = success and ok

    # 3. Sync climate index data (shared, but store per-region for completeness)
    climate_dir = config.data_dir
    if climate_dir.exists():
        # Only sync CSV/json climate files, not huge raw data
        ok = sync_to_gdrive(
            climate_dir, region_key, gdrive_root, subdir="data")
        success = success and ok

    return success
