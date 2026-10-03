#!/usr/bin/env python3
"""Generic RSS watcher runner. Invoked by per-watcher entry points.

Looks up the watcher name in ~/.hermes/watcher-config.json and dispatches
to the right scraper script.  One config entry + one one-liner entry point
per watcher, zero duplicated logic.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

HERMES_HOME = Path(os.environ.get("HERMES_HOME", Path.home() / ".hermes"))
CONFIG_PATH = HERMES_HOME / "watcher-config.json"
SKILLS_DIR = HERMES_HOME / "skills"


def main() -> int:
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <watcher-name>", file=sys.stderr)
        return 1

    name = sys.argv[1]

    if not CONFIG_PATH.exists():
        print(f"Config not found: {CONFIG_PATH}", file=sys.stderr)
        return 1

    config = json.loads(CONFIG_PATH.read_text())
    watcher = config.get(name)
    if watcher is None:
        print(f"Unknown watcher: {name} (known: {list(config.keys())})", file=sys.stderr)
        return 1

    script_name = watcher["script"]
    url = watcher["url"]
    max_items = watcher.get("max", 10)

    # Locate the scraper script under skills/
    # Search all skill dirs so it works regardless of skill organisation.
    script_path = None
    for p in SKILLS_DIR.rglob(script_name):
        script_path = p
        break

    if script_path is None:
        print(f"Scraper script '{script_name}' not found under {SKILLS_DIR}", file=sys.stderr)
        return 1

    cmd = [
        sys.executable,
        str(script_path),
        "--name", name,
        "--url", url,
        "--max", str(max_items),
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        # Stderr from the scraper is propagated so cron reports it.
        print(result.stderr, file=sys.stderr, end="")
        return result.returncode

    # Stdout is the watcher output — delivered verbatim by cron (no_agent mode).
    sys.stdout.write(result.stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main())
