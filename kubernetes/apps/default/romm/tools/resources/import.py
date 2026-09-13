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

QBT = os.environ.get(
    "QBT_URL", "http://qui.default.svc.cluster.local/api/instances/1"
).rstrip("/")
DEST = Path(os.environ.get("ROM_DEST", "/media/games/roms"))
ROM_ROOTS = (
    Path("/media/downloads/torrents/complete/roms/Minerva_Myrient"),
    Path("/media/downloads/torrents/incomplete/roms/Minerva_Myrient"),
)
MINERVA_EXTENSIONS = {
    ".3ds", ".7z", ".bin", ".cso", ".chd", ".cia", ".cue", ".gba",
    ".gb", ".gbc", ".gcz", ".iso", ".nds", ".nes", ".n64", ".pbp",
    ".rar", ".rvz", ".sfc", ".smc", ".wad", ".wbfs", ".zip",
}
SWITCH_EXTENSIONS = {".nsp", ".nsz", ".xci"}
PATCH_MARKERS = ("english", "translated", "translation", "patched", "undub", "hack")
JAPAN_MARKERS = ("(japan)", "[japan]")
SWITCH_MOD_DIRECTORIES = {"atmosphere", "exefs", "romfs", "sxos"}
MINERVA_PLATFORMS = {
    "Nintendo - Game Boy Advance": "gba",
    "Nintendo - Nintendo 3DS": "3ds",
    "Nintendo - Nintendo 3DS (Decrypted)": "3ds",
    "Nintendo - Nintendo 3DS (Digital) (CDN)": "3ds",
    "Nintendo - Nintendo 64 (BigEndian)": "n64",
    "Nintendo - Nintendo DS": "nds",
    "Nintendo - Nintendo DS [T-En]": "nds",
    "Nintendo - Nintendo DS (Decrypted)": "nds",
    "Nintendo - Nintendo Entertainment System (Headerless)": "nes",
    "Nintendo - Super Nintendo Entertainment System": "snes",
    "Nintendo - GameCube - NKit RVZ [zstd-19-128k]": "ngc",
    "Nintendo - Wii - NKit RVZ [zstd-19-128k]": "wii",
    "Non-Redump - Nintendo - Wii U": "wiiu",
    "Non-Redump - Sony - PlayStation Portable": "psp",
    "Sony - PlayStation": "psx",
    "Sony - PlayStation 2": "ps2",
    "Sony - PlayStation Portable": "psp",
    "Sony - PlayStation Portable (PSN) (Decrypted)": "psp",
    "Sega - Game Gear": "gg",
    "Sega - Master System - Mark III": "sms",
    "Sega - Mega Drive - Genesis": "genesis",
    "Sega - Dreamcast": "dc",
    "Sega - Saturn": "saturn",
    "NEC - PC Engine - TurboGrafx-16": "pcengine",
    "Microsoft - Xbox": "xbox",
    "Microsoft - Xbox 360": "xbox360",
}


@dataclass
class Result:
    imported: int = 0
    existing: int = 0
    skipped: int = 0
    failed: int = 0


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
    if isinstance(torrents, dict):
        torrents = torrents.get("torrents", [])
    if not isinstance(torrents, list):
        raise RuntimeError("unexpected torrent list response")
    for torrent in torrents:
        if torrent.get("category") != "roms":
            continue
        content = Path(torrent["content_path"])
        for item in http_json(f"torrents/{urllib.parse.quote(torrent['hash'])}/files"):
            if item.get("priority", 0) <= 0 or item.get("progress", 0) < 1:
                continue
            relative = Path(item["name"])
            if relative.parts and relative.parts[0] == content.name:
                relative = Path(*relative.parts[1:])
            source = (content / relative).resolve()
            if any(is_source_path(source, root) for root in ROM_ROOTS):
                selected.add(source)
    return selected


def minerva_location(source: Path, root: Path):
    parts = source.relative_to(root).parts
    for index, part in enumerate(parts[:-1]):
        platform = MINERVA_PLATFORMS.get(part)
        if platform:
            return platform, Path(*parts[index + 1:])
        if "[T-En] Collection" in part:
            platform = MINERVA_PLATFORMS.get(part.split(" [T-En] Collection", 1)[0])
            if platform:
                return platform, Path(*parts[index + 1:])
    return None


def is_allowed(source: Path) -> bool:
    name = source.name.lower()
    return not (
        any(marker in name for marker in JAPAN_MARKERS)
        and not any(marker in name for marker in PATCH_MARKERS)
    )


def is_source_path(source: Path, root: Path) -> bool:
    try:
        source.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def safe_source(source: Path, root: Path) -> bool:
    try:
        source.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def hardlink(source: Path, destination: Path) -> str:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        if destination.stat().st_size != source.stat().st_size:
            raise RuntimeError("destination has a different size")
        return "existing-hardlink" if os.stat(destination).st_ino == os.stat(source).st_ino else "existing"
    if source.stat().st_dev != destination.parent.stat().st_dev:
        raise OSError("source and destination are on different filesystems")
    os.link(source, destination)
    if os.stat(destination).st_ino != os.stat(source).st_ino:
        raise RuntimeError("hard-link verification failed")
    return "imported"


def import_minerva(selected: set[Path], result: Result) -> None:
    for root in ROM_ROOTS:
        if not root.exists():
            continue
        for source in root.rglob("*"):
            if not source.is_file() or source.name.startswith(".") or ".unwanted" in source.parts:
                continue
            if source.resolve() not in selected:
                continue
            if not safe_source(source, root):
                result.failed += 1
                print(f"failed: unsafe source path: {source}")
                continue
            if source.suffix.lower() not in MINERVA_EXTENSIONS or not is_allowed(source):
                result.skipped += 1
                continue
            location = minerva_location(source, root)
            if not location:
                result.skipped += 1
                print(f"skip unmapped: {source}")
                continue
            platform, relative = location
            try:
                status = hardlink(source, DEST / platform / relative)
                setattr(result, status.split("-")[0], getattr(result, status.split("-")[0]) + 1)
                print(f"{status}: {source}")
            except (OSError, RuntimeError) as error:
                result.failed += 1
                print(f"failed: {source}: {error}")


def game_info(filename: str):
    name = re.sub(r"\s*\(\d+\.\d+\s+GB\)", "", filename.rsplit(".", 1)[0])
    dlc = re.search(r"^(.+?)\s*\[DLC[^\]]*\]\s*\[[\dA-F]{16}\]", name)
    base = re.match(r"^(.+?)\s*\[[\dA-F]{16}\]", name)
    match = dlc or base
    game = match.group(1).strip() if match else name.split("[")[0].strip()
    if dlc:
        return game, "dlc"
    version = re.search(r"\[v(\d+)\]", filename)
    return game, "update" if version and int(version.group(1)) > 0 else "base"


def import_switch_and_games(result: Result) -> None:
    sources = ((Path("/media/downloads/torrents/complete/switch"), "copy"),
               (Path("/media/downloads/torrents/complete/games"), "hardlink"))
    for root, mode in sources:
        if not root.exists():
            continue
        for source in root.rglob("*"):
            if not source.is_file() or source.name.startswith(".") or ".unwanted" in source.parts:
                continue
            if SWITCH_MOD_DIRECTORIES.intersection(source.parts) or source.suffix.lower() not in SWITCH_EXTENSIONS:
                continue
            game, kind = game_info(source.name)
            destination = DEST / "switch" / game / (kind if kind != "base" else "") / source.name
            try:
                if source.suffix.lower() == ".nsz":
                    destination = destination.with_suffix(".nsp")
                    if not destination.exists():
                        destination.parent.mkdir(parents=True, exist_ok=True)
                        subprocess.run(["nsz", "-D", str(source), "-o", str(destination.parent)], check=True)
                elif mode == "copy":
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    if not destination.exists():
                        shutil.copy2(source, destination)
                else:
                    status = hardlink(source, destination)
                    if status == "imported":
                        result.imported += 1
                        print(f"imported: {source}")
                        continue
                result.existing += 1 if destination.exists() else 0
            except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
                result.failed += 1
                print(f"failed: {source}: {error}")


def main() -> None:
    lock = DEST / ".romm-tools.lock"
    try:
        lock.mkdir()
    except FileExistsError:
        print("another romm-tools run is active")
        return
    result = Result()
    try:
        import_switch_and_games(result)
        import_minerva(qbt_selected_files(), result)
    finally:
        lock.rmdir()
    print(f"summary imported={result.imported} existing={result.existing} skipped={result.skipped} failed={result.failed}")


if __name__ == "__main__":
    main()
