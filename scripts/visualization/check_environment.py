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
    from visualization.common import save_figure_atomic
    from visualization.pdf_validation import validate_minus_probe

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
    style = resolve_style({"dpi": 180})
    apply_style(style)
    output.mkdir(parents=True, exist_ok=True)
    figure = plt.figure(figsize=(3.2, 2.4))
    axis = figure.add_axes([0.22, 0.22, 0.65, 0.55])
    axis.plot(np.array([-1.0, 1.0]), np.array([-1.0, 1.0]))
    figure.text(0.84, 0.9, r"$-$", fontsize=18, ha="center", va="center")
    axis.set_xlabel(r"$k\;[\mathrm{\AA^{-1}}]$")
    axis.set_ylabel(r"$10^{-3}\;E-E_{\mathrm{VBM}}$")
    try:
        paths = save_figure_atomic(figure, output / "publication-environment", 180, ["pdf", "png"])
        artifacts = [str(path.resolve()) for path in paths]
        minus_probe = validate_minus_probe(output / "publication-environment.pdf",
                                          output / "publication-environment.png",
                                          output / "minus-qa", (0.84, 0.9), 180)
    finally:
        plt.close(figure)
    record = {
        "status": "PASS",
        "native_vector_minus_probe": minus_probe,
        "artifact_class": "native_vector",
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
