from __future__ import annotations

import hashlib
import json
import math
import os
import tempfile
from pathlib import Path
from typing import Any, Iterable

import numpy as np


class VisualizationError(RuntimeError):
    """Fail-stop input, configuration, or publication error."""


def sha256_file(path: str | Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def finite_array(values: Any, context: str) -> np.ndarray:
    array = np.asarray(values)
    if array.size == 0:
        raise VisualizationError(f"{context} is empty")
    if not np.all(np.isfinite(array)):
        raise VisualizationError(f"{context} contains NaN or Inf")
    return array


def load_json(path: str | Path) -> dict[str, Any]:
    source = Path(path).resolve()
    if not source.is_file():
        raise VisualizationError(f"JSON file does not exist: {source}")
    try:
        payload = json.loads(source.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise VisualizationError(f"cannot parse JSON {source}: {exc}") from exc
    if not isinstance(payload, dict):
        raise VisualizationError(f"JSON root must be an object: {source}")
    return payload


def merge_known(defaults: dict[str, Any], override: dict[str, Any], context: str = "config") -> dict[str, Any]:
    unknown = sorted(set(override) - set(defaults))
    if unknown:
        raise VisualizationError(f"unknown {context} fields: {', '.join(unknown)}")
    merged: dict[str, Any] = {}
    for key, default in defaults.items():
        value = override.get(key, default)
        if isinstance(default, dict):
            if not isinstance(value, dict):
                raise VisualizationError(f"{context}.{key} must be an object")
            merged[key] = merge_known(default, value, f"{context}.{key}")
        else:
            merged[key] = value
    return merged


def relative_l2(left: np.ndarray, right: np.ndarray) -> float:
    difference = np.asarray(left) - np.asarray(right)
    denominator = max(float(np.linalg.norm(left)), float(np.linalg.norm(right)), np.finfo(float).tiny)
    return float(np.linalg.norm(difference) / denominator)


def atomic_json(path: str | Path, payload: dict[str, Any]) -> Path:
    destination = Path(path).resolve()
    destination.parent.mkdir(parents=True, exist_ok=True)
    handle, temporary_name = tempfile.mkstemp(prefix=f".{destination.name}.", dir=destination.parent)
    try:
        with os.fdopen(handle, "w", encoding="utf-8") as stream:
            json.dump(payload, stream, ensure_ascii=False, indent=2, sort_keys=True, allow_nan=False)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary_name, destination)
    except Exception:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass
        raise
    return destination


def validate_formats(formats: Iterable[str]) -> list[str]:
    normalized = [str(value).lower() for value in formats]
    if not normalized or len(set(normalized)) != len(normalized):
        raise VisualizationError("output formats must be a nonempty unique list")
    if any(value not in {"pdf", "png"} for value in normalized):
        raise VisualizationError("output formats may contain only pdf and png")
    return normalized


def save_figure_atomic(fig: Any, stem: str | Path, dpi: int, formats: Iterable[str]) -> list[Path]:
    if not isinstance(dpi, int) or dpi <= 0:
        raise VisualizationError("dpi must be a positive integer")
    output_stem = Path(stem).resolve()
    output_stem.parent.mkdir(parents=True, exist_ok=True)
    resolved_formats = validate_formats(formats)
    temporary_directory = Path(tempfile.mkdtemp(prefix=".wanniernlqg-plot-", dir=output_stem.parent))
    temporary_outputs: list[Path] = []
    outputs: list[Path] = []
    try:
        for output_format in resolved_formats:
            temporary = temporary_directory / f"{output_stem.name}.{output_format}"
            fig.savefig(temporary, dpi=dpi, format=output_format, facecolor="white")
            if not temporary.is_file() or temporary.stat().st_size == 0:
                raise VisualizationError(f"renderer produced an empty {output_format} file")
            temporary_outputs.append(temporary)
            outputs.append(output_stem.with_suffix(f".{output_format}"))
        for temporary, output in zip(temporary_outputs, outputs):
            os.replace(temporary, output)
    finally:
        for temporary in temporary_outputs:
            if temporary.exists():
                temporary.unlink()
        try:
            temporary_directory.rmdir()
        except OSError:
            pass
    return outputs


def audited_file(path: str | Path, role: str) -> dict[str, Any]:
    source = Path(path).resolve()
    if not source.is_file():
        raise VisualizationError(f"{role} does not exist: {source}")
    return {
        "role": role,
        "path": str(source),
        "sha256": sha256_file(source),
        "bytes": source.stat().st_size,
    }


def seal_plot_sidecar(
    stem: str | Path,
    *,
    plot_kind: str,
    script_path: str | Path,
    inputs: list[dict[str, Any]],
    outputs: list[Path],
    resolved_config: dict[str, Any],
    datasets: list[dict[str, Any]],
    transforms: list[dict[str, Any]],
    comparisons: list[dict[str, Any]],
    notes: list[str] | None = None,
) -> Path:
    output_records = [audited_file(path, f"plot_{path.suffix[1:]}") for path in outputs]
    payload = {
        "schema": "wanniernlqg.presentation-plot",
        "schema_version": "1.0",
        "plot_kind": plot_kind,
        "qualification": "PRESENTATION_ONLY",
        "production_eligible": False,
        "qualification_note": (
            "Visualization does not recompute or promote numerical, physical, or production qualification."
        ),
        "script": audited_file(script_path, "entry_script"),
        "inputs": inputs,
        "datasets": datasets,
        "resolved_config": resolved_config,
        "transforms": transforms,
        "comparisons": comparisons,
        "outputs": output_records,
        "notes": list(notes or []),
    }
    return atomic_json(Path(stem).resolve().with_suffix(".plot.json"), payload)


def parse_numeric_sequence(text: str, expected: int | None = None) -> list[float]:
    stripped = text.strip().strip("()[]")
    try:
        result = [float(value.strip()) for value in stripped.split(",") if value.strip()]
    except ValueError as exc:
        raise VisualizationError(f"invalid numeric sequence: {text}") from exc
    if expected is not None and len(result) != expected:
        raise VisualizationError(f"expected {expected} values, got {len(result)}")
    if not all(math.isfinite(value) for value in result):
        raise VisualizationError("numeric sequence contains NaN or Inf")
    return result

