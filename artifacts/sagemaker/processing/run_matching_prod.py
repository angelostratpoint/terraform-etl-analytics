"""Install CDCU wheelhouse dependencies, then run the matching script."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


CODE_DIR = Path("/opt/ml/processing/input/code")
WHEELHOUSE_DIR = Path("/opt/ml/processing/input/wheelhouse")
SCRIPT_NAME = os.getenv("CDCU_MATCHING_SCRIPT_NAME", "matching_prod.py")


def install_wheelhouse() -> None:
    requirements = WHEELHOUSE_DIR / "requirements.txt"
    if not requirements.exists():
        print(f"No wheelhouse requirements found at {requirements}; skipping install.")
        return

    cmd = [
        sys.executable,
        "-m",
        "pip",
        "install",
        "--no-index",
        "--find-links",
        str(WHEELHOUSE_DIR),
        "-r",
        str(requirements),
    ]
    print("Installing CDCU dependencies from local S3 wheelhouse input...")
    subprocess.check_call(cmd)


def main() -> None:
    install_wheelhouse()

    script_path = CODE_DIR / SCRIPT_NAME
    if not script_path.exists():
        raise FileNotFoundError(f"Matching script not found: {script_path}")

    print(f"Running CDCU matching script: {script_path}")
    subprocess.check_call([sys.executable, str(script_path)])


if __name__ == "__main__":
    main()
