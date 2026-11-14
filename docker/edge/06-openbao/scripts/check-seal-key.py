#!/usr/bin/env python3
"""Validate the 1Password static-seal reference without printing the secret.

Reads the seal key from the path given as argv[1] and checks the shape OpenBao
requires: exactly 32 bytes, here expressed as 64 hex characters.
"""
import pathlib
import re
import sys


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check-seal-key.py <path-to-seal-key>", file=sys.stderr)
        return 2
    raw = pathlib.Path(sys.argv[1]).read_text().strip()
    if not re.fullmatch(r"[0-9a-fA-F]{64}", raw):
        print(
            f"FAIL: seal key must be 64 hex characters (32 bytes); got {len(raw)} characters",
            file=sys.stderr,
        )
        return 1
    print("OK: seal key is 64 hex characters (32 bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
