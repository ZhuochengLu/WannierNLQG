from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np

from .common import VisualizationError, audited_file, finite_array


@dataclass(frozen=True)
class ResponseDataset:
    label: str
    fermi_energy_ev: np.ndarray
    omega_ev: np.ndarray
    components: tuple[str, ...]
    values: np.ndarray
    input_record: dict[str, Any]

    def audit_record(self) -> dict[str, Any]:
        return {
            "label": self.label,
            "omega_count": int(self.omega_ev.size),
            "omega_minimum_ev": float(np.min(self.omega_ev)),
            "omega_maximum_ev": float(np.max(self.omega_ev)),
            "component_count": len(self.components),
            "components": list(self.components),
            "array_shape": list(self.values.shape),
            "energy_unit": "eV",
            "response_unit": "output units",
        }


def load_response(path: str | Path, label: str) -> ResponseDataset:
    source = Path(path).resolve()
    if not source.is_file():
        raise VisualizationError(f"response file does not exist: {source}")
    lines = source.read_text(encoding="utf-8").splitlines()
    header_lines = [line.strip() for line in lines if line.lstrip().startswith("#")]
    column_headers = [line for line in header_lines if "Efermi" in line and "Omega" in line]
    if len(column_headers) != 1:
        raise VisualizationError("response file must contain exactly one Efermi/Omega header")
    tokens = column_headers[0].lstrip("#").split()
    if tokens[:2] != ["Efermi", "Omega"] or len(tokens) < 3:
        raise VisualizationError("response header must start with Efermi Omega and components")
    components = tuple(tokens[2:])
    if len(set(components)) != len(components):
        raise VisualizationError("response component labels must be unique")
    try:
        table = np.loadtxt(source, comments="#", ndmin=2)
    except (OSError, ValueError) as exc:
        raise VisualizationError(f"cannot parse response table {source}: {exc}") from exc
    table = finite_array(table, "response table")
    expected_columns = 2 + 2 * len(components)
    if table.ndim != 2 or table.shape[1] != expected_columns:
        raise VisualizationError(
            f"response table has {table.shape[1]} columns; expected {expected_columns} "
            "because real/imag values are interleaved"
        )
    if np.any(np.diff(table[:, 1]) < 0.0):
        raise VisualizationError("response Omega grid must be nondecreasing")
    complex_values = table[:, 2::2] + 1j * table[:, 3::2]
    return ResponseDataset(
        str(label), table[:, 0].copy(), table[:, 1].copy(), components,
        complex_values, audited_file(source, "response_tensor"),
    )


def select_part(values: np.ndarray, part: str) -> np.ndarray:
    if part == "real":
        return values.real
    if part == "imag":
        return values.imag
    if part == "abs":
        return np.abs(values)
    if part == "phase":
        return np.angle(values)
    raise VisualizationError("response part must be real, imag, abs, or phase")


def validate_response_comparison(reference: ResponseDataset, model: ResponseDataset) -> None:
    if reference.components != model.components:
        raise VisualizationError("response component order differs")
    if not np.array_equal(reference.omega_ev, model.omega_ev):
        raise VisualizationError("response Omega grids differ; silent interpolation is forbidden")
    if not np.array_equal(reference.fermi_energy_ev, model.fermi_energy_ev):
        raise VisualizationError("response Fermi-energy columns differ")
