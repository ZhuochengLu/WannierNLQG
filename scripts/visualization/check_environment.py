#!/usr/bin/env python3
"""Verify the declared publication environment by actually rendering PDF and PNG."""
from __future__ import annotations

import argparse
import importlib.metadata
import json
from pathlib import Path
import shutil
import sys
import tempfile


def check_publication_environment(output: Path) -> dict:
    """Reject missing dependencies and record the exact interpreter and font used."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import matplotlib.font_manager as fonts
    import numpy as np

    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
    from visualization.style import apply_style, resolve_style

    versions = {}
    requirements = Path(__file__).with_name("requirements.txt")
    for line in requirements.read_text().splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        package, required = line.strip().split("==", 1)
        actual = importlib.metadata.version(package)
        if actual != required:
            raise RuntimeError(f"{package} version {actual} differs from required {required}")
        versions[package] = actual
    style = resolve_style()
    apply_style(style)
    output.mkdir(parents=True, exist_ok=True)
    figure, axis = plt.subplots(figsize=(3.2, 2.4))
    axis.plot(np.array([0.0, 1.0]), np.array([0.0, 1.0]))
    axis.set_xlabel(r"$\hbar\omega\;[\mathrm{eV}]$")
    axis.set_ylabel(r"$\sigma^{xxx}$")
    figure.tight_layout()
    artifacts = []
    try:
        for suffix in ("pdf", "png"):
            path = output / f"publication-environment.{suffix}"
            figure.savefig(path, dpi=style["dpi"])
            if not path.is_file() or path.stat().st_size == 0:
                raise RuntimeError(f"empty publication probe: {path}")
            artifacts.append(str(path.resolve()))
    finally:
        plt.close(figure)
    record = {
        "status": "PASS",
        "python": sys.executable,
        "python_version": sys.version,
        "packages": versions,
        "font_family": style["font_family"],
        "font_path": fonts.findfont(style["font_family"], fallback_to_default=False),
        "latex": style["latex"],
        "pdflatex": shutil.which("pdflatex"),
        "kpsewhich": shutil.which("kpsewhich"),
        "artifacts": artifacts,
    }
    (output / "publication-environment.json").write_text(json.dumps(record, indent=2))
    return record


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    arguments = parser.parse_args()
    try:
        if arguments.output is None:
            with tempfile.TemporaryDirectory(prefix="wanniernlqg-publication-") as directory:
                record = check_publication_environment(Path(directory))
        else:
            record = check_publication_environment(arguments.output)
        print(json.dumps(record, sort_keys=True))
        return 0
    except Exception as exception:
        print(f"Publication environment preflight failed: {exception}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
