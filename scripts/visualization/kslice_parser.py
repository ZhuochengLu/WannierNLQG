from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
import subprocess
from typing import Any

import numpy as np

from .common import VisualizationError, audited_file, finite_array, parse_numeric_sequence, sha256_file


@dataclass(frozen=True)
class KSliceMetadata:
    path: Path
    calculation: str
    k_mesh: tuple[int, int]
    origin: tuple[float, float, float]
    vector_1: tuple[float, float, float]
    vector_2: tuple[float, float, float]
    quantity: str
    method: str
    outputs: tuple[str, ...]
    case_root: str
    model_file: str
    model_sha256: str
    model_input_mode: str

    def audit_record(self) -> dict[str, Any]:
        return {
            "calculation": self.calculation, "k_mesh": list(self.k_mesh),
            "kslice_origin": list(self.origin), "kslice_vector_1": list(self.vector_1),
            "kslice_vector_2": list(self.vector_2), "quantity": self.quantity,
            "method": self.method, "outputs": list(self.outputs), "case_root": self.case_root,
            "model_file": self.model_file, "model_sha256": self.model_sha256,
            "model_input_mode": self.model_input_mode,
        }


@dataclass(frozen=True)
class ModelLattice:
    model_path: Path
    model_sha256: str
    input_mode: str
    lattice_rows_angstrom: np.ndarray
    reciprocal_rows_inverse_angstrom: np.ndarray
    input_record: dict[str, Any]
    manifest_record: dict[str, Any]


def _metadata_entries(path: Path) -> dict[str, dict[str, str]]:
    sections: dict[str, dict[str, str]] = {}
    current = ""
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
            sections.setdefault(current, {})
        elif "=" in line and current:
            key, value = line.split("=", 1)
            sections[current][key.strip()] = value.strip()
    return sections


def load_metadata(path: str | Path) -> KSliceMetadata:
    source = Path(path).resolve()
    if not source.is_file():
        raise VisualizationError(f"K-slice metadata does not exist: {source}")
    sections = _metadata_entries(source)
    run, numerics, inputs, outputs_section = (
        sections.get("Run", {}), sections.get("Numerics", {}),
        sections.get("Input", {}), sections.get("Outputs", {}),
    )
    calculation = run.get("calculation", "").replace("-", "_").lower()
    if calculation not in {"kslice", "k_slice"}:
        raise VisualizationError("metadata [Run].calculation is not K-slice")
    mesh_values = parse_numeric_sequence(numerics.get("k_mesh", ""))
    if len(mesh_values) != 2 or any(value <= 0 or not float(value).is_integer() for value in mesh_values):
        raise VisualizationError("metadata k_mesh must contain two positive integers")
    def tuple3(key: str) -> tuple[float, float, float]:
        return tuple(parse_numeric_sequence(numerics.get(key, ""), 3))  # type: ignore[return-value]
    count = int(outputs_section.get("outputs.count", "0"))
    outputs = tuple(outputs_section.get(f"output.{index}", "") for index in range(1, count + 1))
    if count <= 0 or any(not output for output in outputs):
        raise VisualizationError("metadata must enumerate K-slice outputs")
    origin, vector_1, vector_2 = tuple3("kslice_origin"), tuple3("kslice_vector_1"), tuple3("kslice_vector_2")
    if np.linalg.norm(vector_1) == 0.0 or np.linalg.norm(vector_2) == 0.0:
        raise VisualizationError("metadata K-slice vectors must be nonzero")
    if np.linalg.norm(np.cross(vector_1, vector_2)) <= 1.0e-14:
        raise VisualizationError("metadata K-slice vectors must be linearly independent")
    model_sha = inputs.get("model_sha256", "").lower()
    if model_sha and (len(model_sha) != 64 or any(char not in "0123456789abcdef" for char in model_sha)):
        raise VisualizationError("metadata [Input].model_sha256 must be a lowercase SHA-256 digest")
    model_mode = inputs.get("model_input_mode", "").lower()
    if model_mode and model_mode not in {"legacy", "packed_hdf5"}:
        raise VisualizationError("metadata [Input].model_input_mode must be legacy or packed_hdf5")
    return KSliceMetadata(
        source, calculation, (int(mesh_values[0]), int(mesh_values[1])), origin, vector_1,
        vector_2, run.get("quantity", ""), run.get("method", ""), outputs,
        inputs.get("case_root", ""), inputs.get("model_file", ""), model_sha, model_mode,
    )


def load_matrix(path: str | Path, metadata: KSliceMetadata, role: str) -> tuple[np.ndarray, dict[str, Any]]:
    source = Path(path).resolve()
    if not source.is_file():
        raise VisualizationError(f"K-slice matrix does not exist: {source}")
    if source.name not in metadata.outputs:
        raise VisualizationError("K-slice matrix is not enumerated by metadata [Outputs]")
    try:
        matrix = np.loadtxt(source, ndmin=2)
    except (OSError, ValueError) as exc:
        raise VisualizationError(f"cannot parse K-slice matrix {source}: {exc}") from exc
    matrix = finite_array(matrix, role)
    if matrix.shape != metadata.k_mesh:
        raise VisualizationError(f"K-slice matrix shape {matrix.shape} disagrees with metadata k_mesh {metadata.k_mesh}")
    return np.asarray(matrix, dtype=float), audited_file(source, role)


def combine_parts(real_values: np.ndarray, imag_values: np.ndarray | None, part: str) -> np.ndarray:
    if part == "real":
        return real_values
    if imag_values is None:
        raise VisualizationError(f"K-slice part={part} requires an explicit paired imaginary matrix")
    if real_values.shape != imag_values.shape:
        raise VisualizationError("paired K-slice real/imag matrices have different shapes")
    values = real_values + 1j * imag_values
    if part == "imag":
        return imag_values
    if part == "abs":
        return np.abs(values)
    if part == "phase":
        return np.angle(values)
    raise VisualizationError("K-slice part must be real, imag, abs, or phase")


def _resolve_declared_model(metadata: KSliceMetadata, override: str | None) -> Path:
    if not metadata.case_root or not metadata.model_file or not metadata.model_sha256 or not metadata.model_input_mode:
        raise VisualizationError("Cartesian K-slice plotting requires metadata [Input] case_root, model_file, model_sha256, and model_input_mode")
    case_root = Path(metadata.case_root)
    if not case_root.is_absolute():
        case_root = (metadata.path.parent / case_root).resolve()
    declared = Path(metadata.model_file)
    declared = declared.resolve() if declared.is_absolute() else (case_root / declared).resolve()
    chosen = Path(override).resolve() if override else declared
    if not chosen.is_file():
        raise VisualizationError(f"K-slice model file does not exist: {chosen}")
    actual = sha256_file(chosen)
    if actual.lower() != metadata.model_sha256:
        raise VisualizationError(f"K-slice model SHA-256 mismatch: metadata={metadata.model_sha256}, actual={actual}")
    return chosen


def _legacy_lattice(path: Path) -> np.ndarray:
    lines = path.read_text(encoding="utf-8").splitlines()
    if len(lines) < 4:
        raise VisualizationError("legacy TB is too short to contain three lattice rows")
    rows: list[list[float]] = []
    for index in range(1, 4):
        try:
            row = [float(value.replace("D", "E").replace("d", "e")) for value in lines[index].split()]
        except ValueError as exc:
            raise VisualizationError(f"legacy TB lattice row {index} is not numeric") from exc
        if len(row) != 3:
            raise VisualizationError("legacy TB lattice rows must contain exactly three values")
        rows.append(row)
    lattice = finite_array(rows, "legacy TB lattice")
    if abs(float(np.linalg.det(lattice))) <= 1.0e-14:
        raise VisualizationError("legacy TB lattice is singular")
    return lattice


def _packed_lattice(path: Path) -> tuple[np.ndarray, dict[str, Any]]:
    probe = Path(__file__).resolve().with_name("model_lattice_probe.jl")
    repository = Path(__file__).resolve().parents[2]
    command = ["julia", f"--project={repository}", "--startup-file=no", "--compiled-modules=no", str(probe), str(path)]
    try:
        completed = subprocess.run(command, check=False, capture_output=True, text=True, timeout=120)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise VisualizationError(f"cannot run packed-HDF5 manifest probe: {exc}") from exc
    if completed.returncode != 0:
        raise VisualizationError(f"packed-HDF5 manifest validation failed: {(completed.stderr or completed.stdout).strip()}")
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError as exc:
        raise VisualizationError("packed-HDF5 manifest probe did not return valid JSON") from exc
    if payload.get("schema") != "wanniernlqg.visualization-model-lattice" or payload.get("schema_version") != "1.0":
        raise VisualizationError("packed-HDF5 manifest probe returned an unsupported schema")
    lattice = finite_array(payload.get("lattice_rows_angstrom"), "packed-HDF5 lattice")
    if lattice.shape != (3, 3) or abs(float(np.linalg.det(lattice))) <= 1.0e-14:
        raise VisualizationError("packed-HDF5 manifest lattice must be nonsingular 3x3")
    return lattice, payload


def load_model_lattice(metadata: KSliceMetadata, override: str | None = None) -> ModelLattice:
    model = _resolve_declared_model(metadata, override)
    manifest: dict[str, Any] = {"reader": "legacy_tb_lattice_rows"}
    if metadata.model_input_mode == "legacy":
        lattice = _legacy_lattice(model)
    elif metadata.model_input_mode == "packed_hdf5":
        lattice, manifest = _packed_lattice(model)
    else:
        raise VisualizationError("unsupported model_input_mode for Cartesian K-slice")
    reciprocal = 2.0 * np.pi * np.linalg.inv(lattice).T
    return ModelLattice(model, metadata.model_sha256, metadata.model_input_mode, lattice, reciprocal, audited_file(model, "kslice_model"), manifest)


def cartesian_projection_grid(metadata: KSliceMetadata, lattice: ModelLattice, projection: str, explicit_axes: Any = None) -> tuple[np.ndarray, np.ndarray, dict[str, Any]]:
    nu, nv = metadata.k_mesh
    u_edges = (np.arange(nu + 1, dtype=float) - 0.5) / nu
    v_edges = (np.arange(nv + 1, dtype=float) - 0.5) / nv
    u, v = np.meshgrid(u_edges, v_edges, indexing="ij")
    origin, vector_1, vector_2 = np.asarray(metadata.origin), np.asarray(metadata.vector_1), np.asarray(metadata.vector_2)
    fractional = origin + u[..., None] * vector_1 + v[..., None] * vector_2
    cartesian = fractional @ lattice.reciprocal_rows_inverse_angstrom
    key, relative = projection.lower(), False
    if key == "intrinsic-plane":
        c1 = vector_1 @ lattice.reciprocal_rows_inverse_angstrom
        c2 = vector_2 @ lattice.reciprocal_rows_inverse_angstrom
        e1 = c1 / np.linalg.norm(c1)
        perpendicular = c2 - np.dot(c2, e1) * e1
        if np.linalg.norm(perpendicular) <= 1.0e-14:
            raise VisualizationError("Cartesian K-slice vectors become collinear in reciprocal space")
        projection_rows = np.stack((e1, perpendicular / np.linalg.norm(perpendicular)), axis=0)
        labels = (r"$k_{\parallel 1}\ \mathrm{(\AA^{-1})}$", r"$k_{\parallel 2}\ \mathrm{(\AA^{-1})}$")
        relative = True
    elif key in {"kx-ky", "kx-kz", "ky-kz"}:
        first, second = {"kx-ky": (0, 1), "kx-kz": (0, 2), "ky-kz": (1, 2)}[key]
        projection_rows = np.eye(3)[[first, second]]
        names = ("x", "y", "z")
        labels = (rf"$k_{names[first]}\ \mathrm{{(\AA^{{-1}})}}$", rf"$k_{names[second]}\ \mathrm{{(\AA^{{-1}})}}$")
    elif key == "explicit":
        axes = finite_array(explicit_axes, "explicit Cartesian projection axes")
        if axes.shape != (2, 3):
            raise VisualizationError("explicit_projection_axes must be a 2x3 array")
        norms = np.linalg.norm(axes, axis=1)
        if np.any(norms <= 1.0e-14):
            raise VisualizationError("explicit Cartesian projection axes must be nonzero")
        projection_rows = axes / norms[:, None]
        if abs(float(np.dot(projection_rows[0], projection_rows[1]))) > 1.0e-10:
            raise VisualizationError("explicit Cartesian projection axes must be orthogonal")
        labels = (r"$k_{p1}\ \mathrm{(\AA^{-1})}$", r"$k_{p2}\ \mathrm{(\AA^{-1})}$")
    else:
        raise VisualizationError("Cartesian projection must be intrinsic-plane, kx-ky, kx-kz, ky-kz, or explicit")
    coordinates = cartesian - (origin @ lattice.reciprocal_rows_inverse_angstrom) if relative else cartesian
    x, y = coordinates @ projection_rows[0], coordinates @ projection_rows[1]
    edge_1_x, edge_1_y = x[1:, :-1] - x[:-1, :-1], y[1:, :-1] - y[:-1, :-1]
    edge_2_x, edge_2_y = x[:-1, 1:] - x[:-1, :-1], y[:-1, 1:] - y[:-1, :-1]
    area = np.abs(edge_1_x * edge_2_y - edge_1_y * edge_2_x)
    if np.any(~np.isfinite(area)) or np.any(area <= 1.0e-16):
        raise VisualizationError("Cartesian projection creates degenerate or folded K-slice cells")
    record = {
        "coordinate_contract": "row_lattice_A; B=2pi*A^{-T}; k_cart=B^T*k_frac",
        "lattice_rows_angstrom": lattice.lattice_rows_angstrom.tolist(),
        "reciprocal_rows_inverse_angstrom": lattice.reciprocal_rows_inverse_angstrom.tolist(),
        "projection": key, "projection_rows_cartesian": projection_rows.tolist(),
        "relative_to_slice_origin": relative, "grid_storage": "matrix[u_index,v_index]",
        "runtime_sampling": "u=i/nu, v=j/nv; plot uses half-cell edge extrapolation",
        "x_range_inverse_angstrom": [float(np.min(x)), float(np.max(x))],
        "y_range_inverse_angstrom": [float(np.min(y)), float(np.max(y))],
        "xlabel": labels[0], "ylabel": labels[1],
    }
    return x, y, record
