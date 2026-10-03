#!/usr/bin/env python3
"""Validate compressed output preserves technical content."""

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Set


@dataclass
class ValidationResult:
    errors: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)

    @property
    def is_valid(self) -> bool:
        return len(self.errors) == 0

    def add_error(self, msg: str):
        self.errors.append(msg)

    def add_warning(self, msg: str):
        self.warnings.append(msg)


def read_file(path: Path) -> str:
    return path.read_text(errors="ignore")


def extract_headings(text: str) -> List[str]:
    return re.findall(r"^#{1,6}\s+.+$", text, re.MULTILINE)


def extract_code_blocks(text: str) -> List[str]:
    return re.findall(r"```[\s\S]*?```", text)


def extract_urls(text: str) -> Set[str]:
    return set(re.findall(r"https?://[^\s\)>\]]+", text))


def extract_paths(text: str) -> Set[str]:
    return set(re.findall(r"(?:^|\s)([~/.][\w/.\-]+(?:\.\w+)?)", text))


def count_bullets(text: str) -> int:
    return len(re.findall(r"^\s*[-*]\s", text, re.MULTILINE))


def validate(original_path: Path, compressed_path: Path) -> ValidationResult:
    result = ValidationResult()
    orig = read_file(original_path)
    comp = read_file(compressed_path)

    # Headings
    h1 = extract_headings(orig)
    h2 = extract_headings(comp)
    if len(h1) != len(h2):
        result.add_error(f"Heading count mismatch: {len(h1)} vs {len(h2)}")
    if h1 != h2:
        result.add_warning("Heading text/order changed")

    # Code blocks
    c1 = extract_code_blocks(orig)
    c2 = extract_code_blocks(comp)
    if c1 != c2:
        result.add_error("Code blocks not preserved exactly")

    # URLs
    u1 = extract_urls(orig)
    u2 = extract_urls(comp)
    if u1 != u2:
        result.add_error(f"URL mismatch: lost={u1 - u2}, added={u2 - u1}")

    # Paths
    p1 = extract_paths(orig)
    p2 = extract_paths(comp)
    if p1 != p2:
        result.add_warning(f"Path mismatch: lost={p1 - p2}, added={p2 - p1}")

    # Bullets
    b1 = count_bullets(orig)
    b2 = count_bullets(comp)
    if b1 > 0:
        diff = abs(b1 - b2) / b1
        if diff > 0.15:
            result.add_warning(f"Bullet count changed significantly: {b1} -> {b2}")

    return result


if __name__ == "__main__":
    import sys
    if len(sys.argv) != 3:
        print("Usage: python validate.py <original> <compressed>")
        sys.exit(1)
    res = validate(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve())
    print(f"\nValid: {res.is_valid}")
    if res.errors:
        print("\nErrors:")
        for e in res.errors:
            print(f"  - {e}")
    if res.warnings:
        print("\nWarnings:")
        for w in res.warnings:
            print(f"  - {w}")
