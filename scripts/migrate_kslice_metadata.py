#!/usr/bin/env python3
"""Explicitly convert historical SHA-bound K-slice metadata to captured geometry.

Original metadata/model bytes are preserved. Only an explicit SHA-bound legacy TB
or schema-1.3 packed manifest is convertible; local file-state observations do not
prove historical content equality and are rejected.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import numpy as np
from visualization.common import VisualizationError, finite_array, sha256_file
from visualization.kslice_parser import _metadata_entries


# Read only the three lattice header lines after historical content verification.
def legacy_lattice(path: Path) -> np.ndarray:
    with path.open(encoding="utf-8") as stream:
        next(stream, "")
        rows = [stream.readline().split() for _ in range(3)]
    try:
        lattice = finite_array([[float(x.replace("D", "E").replace("d", "e")) for x in row] for row in rows], "legacy lattice")
    except (ValueError, TypeError) as exc:
        raise VisualizationError("legacy lattice must contain three numeric rows") from exc
    return lattice


# Reuse the existing strict packed publication/geometry probe, without loading operators.
def packed_lattice(path: Path) -> np.ndarray:
    root = Path(__file__).resolve().parents[1]
    command = ["julia", f"--project={root}", "--startup-file=no", "--compiled-modules=no", str(root / "scripts/visualization/model_lattice_probe.jl"), str(path)]
    try:
        completed = subprocess.run(command, capture_output=True, text=True, timeout=120, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise VisualizationError("existing packed manifest probe is unavailable") from exc
    if completed.returncode:
        raise VisualizationError("existing packed manifest probe rejected the model: " + completed.stderr.strip())
    payload = json.loads(completed.stdout)
    if payload.get("schema") != "wanniernlqg.visualization-model-lattice" or payload.get("schema_version") != "1.1":
        raise VisualizationError("unsupported packed geometry probe result")
    return finite_array(payload.get("lattice_rows_angstrom"), "packed lattice")


# Convert one historical observation into a new file; no ordinary-reader fallback.
def convert_metadata(source: Path, output: Path, model_override: Path | None = None) -> dict:
    source, output = source.resolve(), output.absolute()
    if output.exists() or output.is_symlink() or source == output:
        raise VisualizationError("conversion output must be a new path")
    original = source.read_bytes()
    sections = _metadata_entries(source)
    if "Geometry" in sections:
        raise VisualizationError("metadata already contains Geometry; conversion is not applicable")
    inputs = sections.get("Input", {})
    identity = inputs.get("model_identity") or inputs.get("model_sha256", "")
    if not re.fullmatch(r"[0-9a-f]{64}", identity):
        raise VisualizationError("conversion requires a historical content SHA-256; file-state/publication observations cannot authenticate old geometry")
    mode = inputs.get("model_input_mode", "")
    if mode not in {"legacy", "packed_hdf5"}:
        raise VisualizationError("conversion supports only historical legacy or packed_hdf5 inputs")
    case = Path(inputs.get("case_root", "."))
    if not case.is_absolute():
        case = source.parent / case
    declared = inputs.get("model_file", "")
    if not declared:
        raise VisualizationError("historical metadata must declare model_file")
    model = model_override.resolve() if model_override else (case / declared).resolve()
    if sha256_file(model) != identity:
        raise VisualizationError("historical model content SHA-256 mismatch")
    lattice = legacy_lattice(model) if mode == "legacy" else packed_lattice(model)
    if lattice.shape != (3, 3) or not np.all(np.isfinite(lattice)) or abs(float(np.linalg.det(lattice))) <= 1e-14:
        raise VisualizationError("converted lattice must be finite nonsingular 3x3")
    # Recheck the explicitly consumed historical model before publishing derived metadata.
    if sha256_file(model) != identity or source.read_bytes() != original:
        raise VisualizationError("historical input changed during explicit conversion")
    geometry = "\n[Geometry]\nschema = wanniernlqg.model-geometry/1\nlattice_convention = row-lattice: R_cart = R_frac(row) * lattice; q_frac = lattice * q_cart / 2pi\n"
    geometry += "".join(f"lattice_row.{i}_angstrom = (" + ", ".join(repr(float(x)) for x in row) + ")\n" for i, row in enumerate(lattice, 1))
    geometry += "\n[GeometryMigration]\nsource_metadata_sha256 = " + sha256_file(source) + "\nsource_model_sha256 = " + identity + "\n"
    with output.open("xb") as stream:
        stream.write(original + geometry.encode("utf-8"))
    return {"source": str(source), "output": str(output), "source_metadata_sha256": sha256_file(source), "source_model_sha256": identity, "output_sha256": sha256_file(output), "geometry_schema": "wanniernlqg.model-geometry/1", "qualification": "FORMAT_CONVERSION_ONLY"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--model-file", type=Path, help="explicit relocated historical model; original SHA must match")
    args = parser.parse_args()
    try:
        print(json.dumps(convert_metadata(args.source, args.output, args.model_file)))
        return 0
    except (VisualizationError, OSError, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
