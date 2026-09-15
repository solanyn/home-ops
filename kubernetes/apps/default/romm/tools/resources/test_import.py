import importlib.util
import os
import sys
import zipfile
from pathlib import Path

import pytest


SCRIPT = Path(__file__).with_name("import.py")
sys.path.insert(0, str(SCRIPT.parent))
spec = importlib.util.spec_from_file_location("romm_import", SCRIPT)
romm_import = importlib.util.module_from_spec(spec)
spec.loader.exec_module(romm_import)


def test_wrapper_rejects_unpinned_checkout(tmp_path, monkeypatch):
    monkeypatch.setenv("NTOOL_PROJECT", str(tmp_path))
    monkeypatch.setenv("NTOOL_COMMIT", "not-a-commit")
    with pytest.raises(RuntimeError, match="40-character"):
        romm_import.ntool_wrapper.command(tmp_path / "cdn", tmp_path / "out")


def test_classifies_actual_minerva_update_name():
    source = Path("Nintendo - Nintendo 3DS (Digital) (CDN)") / (
        "Legend of Zelda, The - Majora's Mask 3D (USA) (Update).zip"
    )
    item = romm_import.classify_3ds(source)
    assert (item.game, item.kind, item.destination, item.is_cdn) == (
        "Legend of Zelda, The - Majora's Mask 3D",
        "update",
        Path("3ds/Legend of Zelda, The - Majora's Mask 3D/update"),
        True,
    )


def test_classifies_actual_minerva_dlc_name():
    source = Path("Nintendo - Nintendo 3DS (Digital) (CDN)") / (
        "Legend of Zelda, The - Majora's Mask 3D (USA) (DLC).zip"
    )
    item = romm_import.classify_3ds(source)
    assert item.kind == "dlc"
    assert item.game == "Legend of Zelda, The - Majora's Mask 3D"


def test_classifies_legacy_title_id_layout():
    source = Path("Nintendo - Nintendo 3DS (Digital) (CDN)") / (
        "Metroid Prime [0004000000123400] [v16].zip"
    )
    item = romm_import.classify_3ds(source)
    assert item.kind == "update"
    assert item.game == "Metroid Prime"


def test_zip_slip_and_symlink_are_rejected(tmp_path):
    source = tmp_path / "update.zip"
    outside = tmp_path / "outside"
    with zipfile.ZipFile(source, "w") as archive:
        archive.writestr("../../outside/escape", b"bad")
        archive.writestr("safe/../also-unsafe", b"bad")
    with pytest.raises(ValueError, match="unsafe archive path"):
        romm_import.safe_extract_zip(source, tmp_path / "extract")
    assert not outside.exists()

    symlink = tmp_path / "link.zip"
    with zipfile.ZipFile(symlink, "w") as archive:
        info = zipfile.ZipInfo("link")
        info.external_attr = (0o120777 << 16)
        archive.writestr(info, "target")
    with pytest.raises(ValueError, match="symlink"):
        romm_import.safe_extract_zip(symlink, tmp_path / "extract-link")


def test_invalid_cia_is_rejected_and_destination_is_unchanged(tmp_path, monkeypatch):
    source = tmp_path / "update.zip"
    with zipfile.ZipFile(source, "w") as archive:
        archive.writestr("00000000", b"cdn content")
    key = tmp_path / "seed.bin"
    key.write_bytes(b"seed")
    destination = tmp_path / "romm" / "update"
    monkeypatch.setenv("NTOOL_KEY_MATERIAL", str(key))
    assert romm_import.convert_cdn(source, destination, tmp_path / "work") == "blocked: ntool checkout or key/seed contract is unavailable"
    assert not destination.exists()


def test_conversion_is_explicitly_blocked_without_pinned_contract(tmp_path, monkeypatch):
    source = tmp_path / "update.zip"
    with zipfile.ZipFile(source, "w") as archive:
        archive.writestr("00000000", b"cdn content")
    monkeypatch.setenv("NTOOL_BIN", "/bin/true")
    monkeypatch.setenv("NTOOL_KEY_MATERIAL", str(tmp_path / "seed"))
    assert romm_import.convert_cdn(source, tmp_path / "dest", tmp_path / "work") == (
        "blocked: ntool checkout or key/seed contract is unavailable"
    )


def test_existing_valid_output_is_idempotent_and_conflict_fails(tmp_path):
    destination = tmp_path / "romm" / "update"
    destination.mkdir(parents=True)
    output = destination / "game.cia"
    output.write_bytes(romm_import.CIA_MAGIC + b"payload" + b"x" * (romm_import.MIN_CIA_SIZE - 8))
    source = tmp_path / "game.zip"
    source.write_bytes(b"irrelevant")
    data = romm_import.CIA_MAGIC + b"payload" + b"x" * (romm_import.MIN_CIA_SIZE - 8)
    assert romm_import.publish_cia(data, output) == "existing"
    with pytest.raises(RuntimeError, match="conflicting output"):
        romm_import.publish_cia(data[:-1] + b"y", output)


def test_cleanup_does_not_remove_update_or_dlc_outputs(tmp_path, monkeypatch):
    base = tmp_path / "3ds" / "Game"
    (base / "update").mkdir(parents=True)
    (base / "dlc").mkdir()
    (base / "Game.cia").write_bytes(b"base")
    (base / "update" / "Game-v1.cia").write_bytes(b"update")
    (base / "dlc" / "Game-dlc.cia").write_bytes(b"dlc")
    monkeypatch.setenv("CLEANUP_LIBRARY", "true")
    old_dest = romm_import.DEST
    old_roots = romm_import.ROM_ROOTS
    try:
        romm_import.DEST = tmp_path
        romm_import.ROM_ROOTS = (tmp_path / "source",)
        result = romm_import.Result()
        romm_import.cleanup_library(set(), result)
    finally:
        romm_import.DEST = old_dest
        romm_import.ROM_ROOTS = old_roots
    assert (base / "update" / "Game-v1.cia").exists()
    assert (base / "dlc" / "Game-dlc.cia").exists()


def test_conversion_creates_missing_work_root_before_staging(tmp_path, monkeypatch):
    source = tmp_path / "missing.zip"
    source.write_bytes(b"not a zip")
    monkeypatch.setenv("NTOOL_BIN", str(tmp_path / "missing"))
    monkeypatch.setenv("NTOOL_IMAGE_DIGEST", "sha256:" + "a" * 64)
    monkeypatch.setenv("NTOOL_KEY_MATERIAL", str(tmp_path / "seed"))
    (tmp_path / "seed").write_bytes(b"seed")
    assert romm_import.convert_cdn(source, tmp_path / "dest", tmp_path / "new-work") == (
        "blocked: ntool checkout or key/seed contract is unavailable"
    )
    assert not (tmp_path / "new-work").exists()
