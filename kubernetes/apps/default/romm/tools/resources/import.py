#!/usr/bin/env python3
"""Import completed ROM files without changing qBittorrent state."""

import json
import os
import re
import shutil
import subprocess
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
import shlex
import tempfile
import zipfile

import ntool_wrapper

QBT = os.environ.get(
    "QBT_URL", "http://qui.default.svc.cluster.local/api/instances/1"
).rstrip("/")
DEST = Path(os.environ.get("ROM_DEST", "/media/games/roms"))
ROM_ROOTS = (
    Path("/media/downloads/torrents/complete/roms/Minerva_Myrient"),
    Path("/media/downloads/torrents/incomplete/roms/Minerva_Myrient"),
)
MINERVA_EXTENSIONS = {
    ".3ds", ".7z", ".bin", ".cso", ".chd", ".cia", ".cci", ".cue", ".gba",
    ".gb", ".gbc", ".gcz", ".iso", ".nds", ".nes", ".n64", ".pbp", ".rar",
    ".rvz", ".sfc", ".smc", ".wad", ".wbfs", ".zip",
}
SWITCH_EXTENSIONS = {".nsp", ".nsz", ".xci"}
PATCH_MARKERS = ("english", "translated", "translation", "patched", "undub", "hack")
JAPAN_MARKERS = ("(japan)", "[japan]")
SWITCH_MOD_DIRECTORIES = {"atmosphere", "exefs", "romfs", "sxos"}
CIA_MAGIC = b"\x20\x20\x00\x00"
MIN_CIA_SIZE = 0x2020
MINERVA_PLATFORMS = {
    "Nintendo - Game Boy Advance": "gba", "Nintendo - Nintendo 3DS": "3ds",
    "Nintendo - Nintendo 3DS (Decrypted)": "3ds",
    "Nintendo - Nintendo 3DS (Digital) (CDN)": "3ds",
    "Nintendo - Nintendo 64 (BigEndian)": "n64", "Nintendo - Nintendo DS": "nds",
    "Nintendo - Nintendo DS [T-En]": "nds", "Nintendo - Nintendo DS (Decrypted)": "nds",
    "Nintendo - Nintendo Entertainment System (Headerless)": "nes",
    "Nintendo - Super Nintendo Entertainment System": "snes",
    "Nintendo - GameCube - NKit RVZ [zstd-19-128k]": "ngc",
    "Nintendo - Wii - NKit RVZ [zstd-19-128k]": "wii",
    "Non-Redump - Nintendo - Wii U": "wiiu", "Non-Redump - Sony - PlayStation Portable": "psp",
    "Sony - PlayStation": "psx", "Sony - PlayStation 2": "ps2",
    "Sony - PlayStation Portable": "psp", "Sony - PlayStation Portable (PSN) (Decrypted)": "psp",
    "Sega - Game Gear": "gg", "Sega - Master System - Mark III": "sms",
    "Sega - Mega Drive - Genesis": "genesis", "Sega - Dreamcast": "dc", "Sega - Saturn": "saturn",
    "NEC - PC Engine - TurboGrafx-16": "pcengine", "Microsoft - Xbox": "xbox", "Microsoft - Xbox 360": "xbox360",
}


@dataclass
class Result:
    imported: int = 0
    existing: int = 0
    skipped: int = 0
    failed: int = 0


@dataclass(frozen=True)
class ThreeDSItem:
    game: str
    kind: str
    destination: Path
    is_cdn: bool


def classify_3ds(source: Path) -> ThreeDSItem:
    """Classify both Minerva title-ID and current human-readable CDN names."""
    stem = Path(source.name).stem
    stem = re.sub(r"\s*\(\d+\.\d+\s+GB\)$", "", stem).strip()
    dlc = re.search(r"\s\(DLC\)$", stem, re.I)
    update = re.search(r"\s\(Update\)$", stem, re.I)
    dlc_match = re.match(r"^(.+?)\s*\[DLC[^\]]*\]\s*\[[0-9A-Fa-f]{16}\]", stem, re.I)
    title_match = re.match(r"^(.+?)\s*\[[0-9A-Fa-f]{16}\]", stem)
    match = dlc_match or title_match
    game = (match.group(1) if match else re.sub(r"\s+\((?:DLC|Update)\)$", "", stem, flags=re.I)).strip()
    game = re.sub(r"\s+\((?:usa|europe|australia|world|japan|unknown|korea)(?:\s+[^)]*)?\)", "", game, flags=re.I).strip()
    version = re.search(r"\[v(\d+)\]", stem, re.I)
    kind = "dlc" if dlc or dlc_match else ("update" if update or (version and int(version.group(1)) > 0) else "base")
    is_cdn = "(cdn)" in " ".join(source.parts).lower()
    directory = Path("3ds") / game / ("updates" if kind == "update" else kind if kind != "base" else "")
    return ThreeDSItem(game, kind, directory, is_cdn)


def safe_extract_zip(source: Path, destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    root = destination.resolve()
    with zipfile.ZipFile(source) as archive:
        for info in archive.infolist():
            mode = (info.external_attr >> 16) & 0o170000
            if mode == 0o120000:
                raise ValueError(f"symlink in archive: {info.filename}")
            target = (destination / info.filename).resolve()
            try:
                target.relative_to(root)
            except ValueError as error:
                raise ValueError(f"unsafe archive path: {info.filename}") from error
            if info.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(info) as input_file, target.open("wb") as output_file:
                    shutil.copyfileobj(input_file, output_file)


def publish_cia(data: bytes, final: Path) -> str:
    """Publish once, refusing replacement and symlink escapes."""
    if len(data) < MIN_CIA_SIZE or data[:4] != CIA_MAGIC:
        raise ValueError("invalid CIA output")
    final.parent.mkdir(parents=True, exist_ok=True)
    if final.exists() or final.is_symlink():
        if final.is_symlink() or final.read_bytes() != data:
            raise RuntimeError("conflicting output")
        return "existing"
    temporary = final.parent / f".{final.name}.tmp-{os.getpid()}"
    try:
        with temporary.open("xb") as output:
            output.write(data)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, final)
        directory_fd = os.open(final.parent, os.O_RDONLY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        temporary.unlink(missing_ok=True)
    return "imported"


def convert_cdn(source: Path, destination: Path, work_root: Path, dry_run: bool = False) -> str:
    """Convert only when the init container's pinned ntool contract exists."""
    key_material = os.environ.get("NTOOL_KEY_MATERIAL")
    if not key_material or not Path(key_material).is_file():
        return "blocked: ntool checkout or key/seed contract is unavailable"
    try:
        ntool_wrapper._contract()
    except RuntimeError:
        return "blocked: ntool checkout or key/seed contract is unavailable"
    if dry_run:
        return "dry-run: conversion contract available"
    work_root.mkdir(parents=True, exist_ok=True)
    workspace = Path(tempfile.mkdtemp(prefix="3ds-cdn-", dir=work_root))
    try:
        extracted = workspace / "cdn"
        safe_extract_zip(source, extracted)
        output = workspace / "converted.cia"
        extra = shlex.split(os.environ.get("NTOOL_ARGS", ""))
        ntool_wrapper.run(extracted, output, extra)
        if not output.is_file():
            return "failed: invalid CIA output"
        status = publish_cia(output.read_bytes(), destination / (source.stem + ".cia"))
        return status
    except (OSError, RuntimeError, ValueError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        return f"failed: {error}"
    finally:
        shutil.rmtree(workspace, ignore_errors=True)


def http_json(path: str):
    last_error = None
    for attempt in range(3):
        try:
            request = urllib.request.Request(f"{QBT}/{path}")
            with urllib.request.urlopen(request, timeout=15) as response:
                return json.loads(response.read())
        except (OSError, ValueError) as error:
            last_error = error
            if attempt < 2:
                time.sleep(1 << attempt)
    raise RuntimeError(f"qBittorrent request failed: {path}: {last_error}")


def qbt_selected_files() -> set[Path]:
    selected = set()
    torrents = http_json("torrents")
    if isinstance(torrents, dict): torrents = torrents.get("torrents", [])
    if not isinstance(torrents, list): raise RuntimeError("unexpected torrent list response")
    for torrent in torrents:
        if torrent.get("category") != "roms": continue
        content = Path(torrent["content_path"])
        for item in http_json(f"torrents/{urllib.parse.quote(torrent['hash'])}/files"):
            if item.get("priority", 0) <= 0 or item.get("progress", 0) < 1: continue
            relative = Path(item["name"])
            if relative.parts and relative.parts[0] == content.name: relative = Path(*relative.parts[1:])
            source = (content / relative).resolve()
            if any(is_source_path(source, root) for root in ROM_ROOTS): selected.add(source)
    return selected


def minerva_location(source: Path, root: Path):
    parts = source.relative_to(root).parts
    for index, part in enumerate(parts[:-1]):
        platform = MINERVA_PLATFORMS.get(part)
        if platform: return platform, Path(*parts[index + 1:])
        if "[T-En] Collection" in part:
            platform = MINERVA_PLATFORMS.get(part.split(" [T-En] Collection", 1)[0])
            if platform: return platform, Path(*parts[index + 1:])
    return None


def is_allowed(source: Path) -> bool:
    name = source.name.lower()
    return not (any(marker in name for marker in JAPAN_MARKERS) and not any(marker in name for marker in PATCH_MARKERS))


def is_source_path(source: Path, root: Path) -> bool:
    try: source.resolve().relative_to(root.resolve()); return True
    except ValueError: return False


def safe_source(source: Path, root: Path) -> bool:
    return is_source_path(source, root)


def hardlink(source: Path, destination: Path) -> str:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists() or destination.is_symlink():
        if destination.is_symlink() or destination.stat().st_size != source.stat().st_size: raise RuntimeError("destination has a different size")
        return "existing-hardlink" if os.stat(destination).st_ino == os.stat(source).st_ino else "existing"
    if source.stat().st_dev != destination.parent.stat().st_dev: raise OSError("source and destination are on different filesystems")
    os.link(source, destination)
    if os.stat(destination).st_ino != os.stat(source).st_ino: raise RuntimeError("hard-link verification failed")
    return "imported"


def import_3ds(selected: set[Path], result: Result) -> None:
    dry_run = os.environ.get("DRY_RUN", "false").lower() == "true"
    work_root = Path(os.environ.get("CDN_WORK_ROOT", "/tmp"))
    for source in sorted(selected):
        location = next((minerva_location(source, root) for root in ROM_ROOTS if safe_source(source, root)), None)
        if not location or location[0] != "3ds": continue
        item = classify_3ds(source)
        if item.is_cdn and source.suffix.lower() == ".zip":
            status = convert_cdn(source, DEST / item.destination, work_root, dry_run=dry_run)
            result.failed += status.startswith(("blocked", "failed")); result.skipped += status.startswith("dry-run"); result.imported += status == "imported"; result.existing += status == "existing"
            print(f"{status}: {source}")
        elif item.kind == "base" and not item.is_cdn:
            if dry_run: result.skipped += 1; print(f"dry-run: {source} -> {DEST / item.destination / source.name}"); continue
            try:
                status = hardlink(source, DEST / item.destination / source.name)
                result.imported += status == "imported"; result.existing += status != "imported"
                print(f"{status}: {source}")
            except (OSError, RuntimeError) as error: result.failed += 1; print(f"failed: {source}: {error}")
        elif item.is_cdn and item.kind in {"update", "dlc"}:
            # Non-ZIP CDN members are never library artifacts; the ZIP is the unit of conversion.
            result.skipped += 1
        elif not item.is_cdn and source.suffix.lower() == ".cia":
            if dry_run: result.skipped += 1; print(f"dry-run: {source} -> {DEST / item.destination / source.name}"); continue
            try:
                status = hardlink(source, DEST / item.destination / source.name)
                result.imported += status == "imported"; result.existing += status != "imported"
                print(f"{status}: {source}")
            except (OSError, RuntimeError) as error: result.failed += 1; print(f"failed: {source}: {error}")


def import_minerva(selected: set[Path], result: Result) -> None:
    for root in ROM_ROOTS:
        if not root.exists(): continue
        for source in root.rglob("*"):
            if not source.is_file() or source.name.startswith(".") or ".unwanted" in source.parts: continue
            if source.resolve() not in selected: continue
            if not safe_source(source, root): result.failed += 1; print(f"failed: unsafe source path: {source}"); continue
            if source.suffix.lower() not in MINERVA_EXTENSIONS or not is_allowed(source): result.skipped += 1; continue
            location = minerva_location(source, root)
            if not location: result.skipped += 1; print(f"skip unmapped: {source}"); continue
            platform, relative = location
            if platform == "3ds": continue
            try:
                status = hardlink(source, DEST / platform / relative)
                setattr(result, status.split("-")[0], getattr(result, status.split("-")[0]) + 1); print(f"{status}: {source}")
            except (OSError, RuntimeError) as error: result.failed += 1; print(f"failed: {source}: {error}")


def game_info(filename: str):
    name = re.sub(r"\s*\(\d+\.\d+\s+GB\)", "", filename.rsplit(".", 1)[0])
    dlc = re.search(r"^(.+?)\s*\[DLC[^\]]*\]\s*\[[\dA-F]{16}\]", name)
    base = re.match(r"^(.+?)\s*\[[\dA-F]{16}\]", name)
    match = dlc or base; game = match.group(1).strip() if match else name.split("[")[0].strip()
    if dlc: return game, "dlc"
    version = re.search(r"\[v(\d+)\]", filename)
    return game, "update" if version and int(version.group(1)) > 0 else "base"


def library_key(name: str) -> str:
    stem = Path(name).stem.lower(); match = re.search(r"\s\((?:usa|europe|australia|world|japan|unknown|korea)", stem)
    return stem[: match.start()].strip() if match else stem


def cleanup_library(selected: set[Path], result: Result) -> None:
    if os.environ.get("CLEANUP_LIBRARY", "false").lower() != "true": return
    selected_inodes = set(); selected_keys = {}
    for source in selected:
        try: selected_inodes.add(source.stat().st_ino)
        except OSError: continue
        location = next((minerva_location(source, root) for root in ROM_ROOTS if safe_source(source, root)), None)
        if location: selected_keys.setdefault(location[0], set()).add(library_key(location[1].name))
    cleaned = preserved = 0
    for platform, keys in selected_keys.items():
        platform_dir = DEST / platform
        if not platform_dir.exists(): continue
        for item in platform_dir.rglob("*"):
            if not item.is_file() and not item.is_symlink(): continue
            relative = item.relative_to(platform_dir)
            if any(part.lower() in {"update", "updates", "dlc", "dlcs"} for part in relative.parts): preserved += 1; continue
            if len(relative.parts) != 2 or library_key(item.name) not in keys: continue
            if item.name.lower() == ".ds_store" or item.name.startswith("."): item.unlink(); cleaned += 1; continue
            try:
                if item.stat().st_ino in selected_inodes: preserved += 1; continue
            except OSError: pass
            item.unlink(); cleaned += 1; print(f"cleaned: {item}")
    result.skipped += preserved; print(f"cleanup cleaned={cleaned} preserved={preserved}")


def import_switch_and_games(result: Result) -> None:
    sources = ((Path("/media/downloads/torrents/complete/switch"), "copy"), (Path("/media/downloads/torrents/complete/games"), "hardlink"))
    for root, mode in sources:
        if not root.exists(): continue
        for source in root.rglob("*"):
            if not source.is_file() or source.name.startswith(".") or ".unwanted" in source.parts: continue
            if SWITCH_MOD_DIRECTORIES.intersection(source.parts) or source.suffix.lower() not in SWITCH_EXTENSIONS: continue
            game, kind = game_info(source.name); destination = DEST / "switch" / game / (kind if kind != "base" else "") / source.name
            try:
                if source.suffix.lower() == ".nsz":
                    destination = destination.with_suffix(".nsp")
                    if not destination.exists(): destination.parent.mkdir(parents=True, exist_ok=True); subprocess.run(["nsz", "-D", str(source), "-o", str(destination.parent)], check=True)
                elif mode == "copy":
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    if not destination.exists(): shutil.copy2(source, destination)
                else:
                    status = hardlink(source, destination)
                    if status == "imported": result.imported += 1; print(f"imported: {source}"); continue
                result.existing += destination.exists()
            except (OSError, RuntimeError, subprocess.CalledProcessError) as error: result.failed += 1; print(f"failed: {source}: {error}")


def main() -> None:
    lock = DEST / ".romm-tools.lock"; lock.parent.mkdir(parents=True, exist_ok=True)
    try: lock.mkdir()
    except (FileExistsError, OSError) as error:
        print(f"dry-run: inventory unavailable: {error}")
        return
    result = Result()
    try:
        import_switch_and_games(result); selected = qbt_selected_files(); import_minerva(selected, result); import_3ds(selected, result); cleanup_library(selected, result)
    finally: lock.rmdir()
    print(f"summary imported={result.imported} existing={result.existing} skipped={result.skipped} failed={result.failed}")


if __name__ == "__main__": main()
