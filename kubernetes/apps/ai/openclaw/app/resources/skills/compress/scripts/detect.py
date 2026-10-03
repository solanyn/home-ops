#!/usr/bin/env python3
"""Detect whether a file should be compressed."""

import re
from pathlib import Path

SKIP_EXTENSIONS = {
    ".py", ".js", ".ts", ".jsx", ".tsx", ".json", ".yaml", ".yml",
    ".toml", ".env", ".lock", ".css", ".html", ".xml", ".sql", ".sh",
    ".bash", ".zsh", ".go", ".rs", ".c", ".cpp", ".h", ".java",
    ".rb", ".php", ".nix", ".tf", ".hcl",
}

COMPRESS_EXTENSIONS = {".md", ".txt", ""}


def should_compress(filepath: Path) -> bool:
    """Return True if file is natural language and should be compressed."""
    if filepath.suffix in SKIP_EXTENSIONS:
        return False
    if ".original." in filepath.name:
        return False
    if filepath.suffix not in COMPRESS_EXTENSIONS:
        return False
    # Quick heuristic: if >60% of lines look like code, skip
    try:
        text = filepath.read_text(errors="ignore")
    except Exception:
        return False
    lines = text.splitlines()
    if not lines:
        return False
    code_lines = sum(1 for l in lines if re.match(r"^(\s{4,}|\t)", l) or l.strip().startswith("```"))
    ratio = code_lines / len(lines)
    return ratio < 0.6
