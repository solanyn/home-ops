#!/usr/bin/env python3
"""Entry point: ozbargain RSS watcher."""
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).parent
runner = HERE / "_run-rss-watcher.py"

if not runner.exists():
    print(f"Runner not found: {runner}", file=sys.stderr)
    sys.exit(1)

result = subprocess.run([sys.executable, str(runner), "ozbargain"], capture_output=True, text=True)
sys.stdout.write(result.stdout)
sys.stderr.write(result.stderr)
sys.exit(result.returncode)
