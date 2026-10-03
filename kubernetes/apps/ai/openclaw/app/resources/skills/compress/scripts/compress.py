#!/usr/bin/env python3
"""
Compress natural language markdown files to reduce token usage.

Usage:
    python3 compress.py <filepath> [--output <outpath>] [--dry-run]
"""

import json
import os
import re
import sys
import urllib.request
from pathlib import Path
from typing import List

from .detect import should_compress
from .validate import validate

MAX_RETRIES = 2
MAX_FILE_SIZE = 500_000  # 500KB

OUTER_FENCE_RE = re.compile(
    r"\A\s*(`{3,}|~{3,})[^\n]*\n(.*)\n\1\s*\Z", re.DOTALL
)


def strip_llm_wrapper(text: str) -> str:
    m = OUTER_FENCE_RE.match(text)
    return m.group(2) if m else text


def call_llm(prompt: str) -> str:
    """Call LLM via OpenAI-compatible API (kgateway)."""
    base_url = os.environ.get("OPENAI_BASE_URL", "https://gateway.goyangi.io/v1/auto")
    api_key = os.environ.get("OPENAI_API_KEY", "dummy")
    model = os.environ.get("COMPRESS_MODEL", "auto")

    url = f"{base_url.rstrip('/')}/chat/completions"
    if not url.startswith("http"):
        url = f"https://{url}"

    body = json.dumps({
        "model": model,
        "max_tokens": 8192,
        "messages": [{"role": "user", "content": prompt}],
    }).encode()

    req = urllib.request.Request(
        url,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
    )

    import ssl
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    with urllib.request.urlopen(req, context=ctx) as resp:
        data = json.loads(resp.read())

    return strip_llm_wrapper(data["choices"][0]["message"]["content"].strip())


def build_compress_prompt(original: str) -> str:
    return f"""Compress this markdown into terse format. Cut filler, articles, hedging. Keep fragments.

STRICT RULES:
- Do NOT modify anything inside ``` code blocks — copy exactly
- Do NOT modify anything inside inline backticks
- Preserve ALL URLs exactly
- Preserve ALL headings exactly (text and level)
- Preserve file paths and commands exactly
- Preserve markdown structure (bullets, numbering, tables)
- Return ONLY the compressed markdown — no outer fence wrapping

Only compress natural language prose. Technical content stays untouched.

TEXT:
{original}
"""


def build_fix_prompt(original: str, compressed: str, errors: List[str]) -> str:
    errors_str = "\n".join(f"- {e}" for e in errors)
    return f"""Fix specific validation errors in this compressed markdown. Do NOT recompress — only fix listed errors.

ERRORS:
{errors_str}

ORIGINAL (reference):
{original}

COMPRESSED (fix this):
{compressed}

Return ONLY the fixed file. No explanation."""


def compress_file(filepath: Path, output: Path = None, dry_run: bool = False) -> bool:
    filepath = filepath.resolve()

    if not filepath.exists():
        print(f"Error: file not found: {filepath}")
        return False

    if filepath.stat().st_size > MAX_FILE_SIZE:
        print(f"Error: file too large (max 500KB): {filepath}")
        return False

    if not should_compress(filepath):
        print(f"Skipping (not natural language): {filepath}")
        return False

    print(f"Compressing: {filepath}")
    original_text = filepath.read_text(errors="ignore")

    # Compress
    print("  Sending to LLM...")
    compressed = call_llm(build_compress_prompt(original_text))

    if dry_run:
        orig_len = len(original_text)
        comp_len = len(compressed)
        savings = (1 - comp_len / orig_len) * 100 if orig_len > 0 else 0
        print(f"  Original: {orig_len} chars")
        print(f"  Compressed: {comp_len} chars")
        print(f"  Savings: {savings:.1f}%")
        print(compressed)
        return True

    # Determine output path
    out_path = output or filepath
    backup_path = filepath.with_name(filepath.stem + ".original.md")

    if out_path == filepath:
        if backup_path.exists():
            print(f"  Warning: backup exists: {backup_path}")
            print("  Aborting to prevent data loss. Remove backup first.")
            return False
        backup_path.write_text(original_text)
        print(f"  Backup: {backup_path}")

    out_path.write_text(compressed)

    # Validate + retry
    ref_path = backup_path if backup_path.exists() else filepath
    for attempt in range(MAX_RETRIES):
        result = validate(ref_path if ref_path.exists() else filepath, out_path)

        if result.is_valid:
            orig_len = len(original_text)
            comp_len = len(compressed)
            savings = (1 - comp_len / orig_len) * 100 if orig_len > 0 else 0
            print(f"  Done: {orig_len} → {comp_len} chars ({savings:.1f}% savings)")
            if result.warnings:
                for w in result.warnings:
                    print(f"  Warning: {w}")
            return True

        print(f"  Validation failed (attempt {attempt + 1}):")
        for err in result.errors:
            print(f"    - {err}")

        if attempt == MAX_RETRIES - 1:
            # Restore original on failure
            if out_path == filepath and backup_path.exists():
                filepath.write_text(original_text)
                backup_path.unlink(missing_ok=True)
            print("  Failed after retries — original restored")
            return False

        print("  Fixing...")
        compressed = call_llm(build_fix_prompt(original_text, compressed, result.errors))
        out_path.write_text(compressed)

    return False


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Compress markdown files to reduce tokens")
    parser.add_argument("filepath", help="File to compress")
    parser.add_argument("--output", "-o", help="Output path (default: overwrite original)")
    parser.add_argument("--dry-run", "-n", action="store_true", help="Preview without writing")
    args = parser.parse_args()

    filepath = Path(args.filepath)
    output = Path(args.output) if args.output else None

    success = compress_file(filepath, output=output, dry_run=args.dry_run)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
