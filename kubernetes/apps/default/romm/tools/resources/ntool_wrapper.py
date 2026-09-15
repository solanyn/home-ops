"""Small, fail-closed adapter for the pinned ntool checkout."""

import os
import subprocess
from pathlib import Path

EXPECTED_COMMIT = os.environ.get("NTOOL_COMMIT", "")
PROJECT = Path(os.environ.get("NTOOL_PROJECT", "/tooling/project"))
CHECKOUT = Path(os.environ.get("NTOOL_CHECKOUT", "/tooling/git-sync/current"))
SCRIPT = CHECKOUT / "ntool.py"


def _contract() -> tuple[str, Path, Path]:
    """Validate the immutable runtime contract before invoking third-party code."""
    expected_commit = os.environ.get("NTOOL_COMMIT", EXPECTED_COMMIT)
    project = Path(os.environ.get("NTOOL_PROJECT", str(PROJECT)))
    checkout = Path(os.environ.get("NTOOL_CHECKOUT", str(CHECKOUT)))
    script = checkout / "ntool.py"
    if not expected_commit or len(expected_commit) != 40 or any(
        character not in "0123456789abcdef" for character in expected_commit
    ):
        raise RuntimeError("NTOOL_COMMIT must be a 40-character lowercase SHA-1")
    if not project.is_dir() or not checkout.is_dir() or not script.is_file():
        raise RuntimeError("ntool project or checkout is unavailable")
    try:
        actual = subprocess.run(
            ["git", "-C", str(checkout), "rev-parse", "HEAD"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError) as error:
        raise RuntimeError("ntool checkout cannot be verified") from error
    if actual != expected_commit:
        raise RuntimeError("ntool checkout commit does not match NTOOL_COMMIT")
    return actual, project, script


def command(source: Path, output: Path, extra: list[str] | None = None) -> list[str]:
    """Build the only supported ntool invocation for CDN conversion."""
    _actual, project, script = _contract()
    return [
        "uv",
        "run",
        "--project",
        str(project),
        "--frozen",
        "python",
        str(script),
        "cdn2cia",
        str(source),
        "--out",
        str(output),
        "--decrypt",
        *(extra or []),
    ]


def run(source: Path, output: Path, extra: list[str] | None = None) -> None:
    """Run ntool only after the checkout and uv project pass contract checks."""
    subprocess.run(command(source, output, extra), check=True)
