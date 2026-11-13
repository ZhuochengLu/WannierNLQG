from __future__ import annotations

import hashlib
import json
import math
import os
import shutil
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


def _publish_output_set(items: list[tuple[Path, Path]], staging: Path) -> None:
    """Rollback ordinary rename failures; report exact state if rollback fails.

    This is not a crash-atomic multi-file filesystem transaction. Publication
    consumers must still verify the final sidecar/manifest and every hash.
    """
    baseline = {destination: sha256_file(destination) if destination.is_file() else None
                for _, destination in items}
    backups: dict[Path, Path] = {}
    backup_root = staging / "publication-backup"
    def changed_paths() -> list[Path]:
        return [path for path, digest in baseline.items()
                if (sha256_file(path) if path.is_file() else None) != digest]
    try:
        backup_root.mkdir()
        for index, (_, destination) in enumerate(items):
            if baseline[destination] is not None:
                backup = backup_root / str(index)
                shutil.copy2(destination, backup)
                if sha256_file(backup) != baseline[destination]:
                    raise VisualizationError(f"publication backup identity mismatch: {destination}")
                backups[destination] = backup
        for source, destination in items:
            os.replace(source, destination)
    except Exception as error:
        changed = changed_paths()
        rollback_errors = []
        for destination in reversed(changed):
            try:
                if baseline[destination] is None:
                    destination.unlink(missing_ok=True)
                else:
                    os.replace(backups[destination], destination)
            except Exception as rollback_error:
                rollback_errors.append({"path": str(destination), "error": str(rollback_error)})
        remaining = changed_paths()
        state = {"status": "PARTIAL_PUBLICATION_FAILURE" if remaining else "ROLLED_BACK",
                 "changed_before_rollback": [str(path) for path in changed],
                 "remaining_changed": [str(path) for path in remaining],
                 "rollback_errors": rollback_errors,
                 "baseline_sha256": {str(path): digest for path, digest in baseline.items()}}
        description = ("partial publication failure; remaining changed: " + ", ".join(map(str, remaining))
                       if remaining else "publication failed; rollback verified; primary unchanged")
        failure = VisualizationError(f"{description}; {error}")
        failure.publication_state = state
        raise failure from error


def save_figure_atomic(fig: Any, stem: str | Path, dpi: int, formats: Iterable[str], *, bbox_inches: str | None = None) -> list[Path]:
    if not isinstance(dpi, int) or dpi <= 0:
        raise VisualizationError("dpi must be a positive integer")
    output_stem = Path(stem).resolve()
    output_stem.parent.mkdir(parents=True, exist_ok=True)
    resolved_formats = validate_formats(formats)
    temporary_directory = Path(tempfile.mkdtemp(prefix=".wanniernlqg-plot-", dir=output_stem.parent))
    temporary_outputs: list[Path] = []
    outputs: list[Path] = []
    proofs: list[tuple[Path, Path]] = []
    try:
        for output_format in resolved_formats:
            temporary = temporary_directory / f"{output_stem.name}.{output_format}"
            fig.savefig(temporary, dpi=dpi, format=output_format, facecolor="white", bbox_inches=bbox_inches)
            if not temporary.is_file() or temporary.stat().st_size == 0:
                raise VisualizationError(f"renderer produced an empty {output_format} file")
            if output_format == "pdf":
                from .pdf_validation import validate_native_pdf, render_pdf_previews, validate_readback_records
                validation = validate_native_pdf(temporary)
                previews = temporary_directory / "pdf-readback"
                validation["renderers"] = render_pdf_previews(temporary, previews, dpi=180)
                validate_readback_records(temporary, validation["renderers"])
                proof_parent = output_stem.parent / (output_stem.name + ".pdf-qa") / validation["pdf"]["sha256"]
                proof_parent.mkdir(parents=True, exist_ok=True)
                # A fresh directory for every export, including byte-identical PDFs.
                proof = Path(tempfile.mkdtemp(prefix="export-", dir=proof_parent))
                shutil.copytree(previews, proof, dirs_exist_ok=True)
                def relocate(node):
                    if isinstance(node, dict):
                        return {key: relocate(value) for key, value in node.items()}
                    if isinstance(node, list):
                        return [relocate(value) for value in node]
                    if isinstance(node, str):
                        return node.replace(str(previews), str(proof)).replace(str(temporary), str(output_stem.with_suffix(".pdf")))
                    return node
                validation = relocate(validation)
                # Verify copied previews against the actual staged PDF, before publication.
                validate_readback_records(temporary, validation["renderers"], published_pdf=output_stem.with_suffix(".pdf"))
                validation["proof_schema"] = "wanniernlqg.native-pdf-proof/2"
                temporary_proof = atomic_json(temporary_directory / "native-pdf.qa.json", validation)
                proofs.append((temporary_proof, output_stem.with_suffix(".pdf.qa.json")))
            temporary_outputs.append(temporary)
            outputs.append(output_stem.with_suffix(f".{output_format}"))
        # Proof publishes last. Ordinary exceptions restore all prior output/proof bytes.
        _publish_output_set(list(zip(temporary_outputs, outputs)) + proofs, temporary_directory)
    except Exception as exc:
        diagnostics = output_stem.parent / "diagnostics" / output_stem.name / temporary_directory.name
        diagnostics.parent.mkdir(parents=True, exist_ok=True)
        state = getattr(exc, "publication_state", {"status": "NOT_PUBLISHED", "remaining_changed": []})
        if temporary_directory.exists():
            atomic_json(temporary_directory / "publication-failure.json", state)
            shutil.move(str(temporary_directory), str(diagnostics))
        detail = str(exc) if hasattr(exc, "publication_state") else f"export validation failed; primary unchanged; {exc}"
        failure = VisualizationError(f"{detail}; evidence: {diagnostics}")
        failure.publication_state = state
        raise failure from exc
    finally:
        if temporary_directory.exists():
            shutil.rmtree(temporary_directory, ignore_errors=True)
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
    pdf_outputs = [path for path in outputs if path.suffix == ".pdf"]
    export_validation = []
    for path in pdf_outputs:
        proof_path = path.with_suffix(".pdf.qa.json")
        if not proof_path.is_file():
            raise VisualizationError(f"PDF validation proof missing: {proof_path}")
        proof = load_json(proof_path)
        if proof.get("status") != "PASS" or proof["pdf"]["sha256"] != sha256_file(path):
            raise VisualizationError(f"PDF validation identity mismatch: {path}")
        from .pdf_validation import validate_readback_records, PDFValidationError
        if proof.get("proof_schema") != "wanniernlqg.native-pdf-proof/2":
            raise VisualizationError(f"PDF readback identity mismatch: legacy/missing proof schema: {path}")
        try:
            validate_readback_records(path, proof["renderers"])
        except (KeyError, PDFValidationError) as exc:
            raise VisualizationError(f"PDF readback identity mismatch: {path}; {exc}") from exc
        export_validation.append({"proof": audited_file(proof_path, "native_pdf_validation"), "record": proof})
    payload = {
        "export_validation": export_validation,
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

