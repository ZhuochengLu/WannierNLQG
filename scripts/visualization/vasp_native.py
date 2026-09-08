from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np

from .common import VisualizationError, audited_file, finite_array


@dataclass(frozen=True)
class VASPNativeBandData:
    fractional_kpoints: np.ndarray
    energies_ev: np.ndarray
    distances_inverse_angstrom: np.ndarray
    node_indices: np.ndarray
    node_labels: tuple[str, ...]
    lattice_rows_angstrom: np.ndarray
    reciprocal_rows_inverse_angstrom: np.ndarray
    spin_channel: int
    spin_count: int
    points_per_segment: int
    segment_count: int
    kpoints_coordinate_mode: str
    inputs: tuple[dict[str, Any], ...]


def _float_tokens(line: str, label: str) -> list[float]:
    try:
        values = [float(token.replace("D", "E").replace("d", "e")) for token in line.split()]
    except ValueError as exc:
        raise VisualizationError(f"{label} contains a nonnumeric token") from exc
    if not values or not np.all(np.isfinite(values)):
        raise VisualizationError(f"{label} must contain finite numeric values")
    return values


def _parse_poscar(path: str | Path) -> tuple[np.ndarray, float | None, dict[str, Any]]:
    source = Path(path).resolve()
    if not source.is_file():
        raise VisualizationError(f"POSCAR/structure does not exist: {source}")
    lines = source.read_text(encoding="utf-8").splitlines()
    if len(lines) < 5:
        raise VisualizationError("POSCAR is too short to contain a lattice")
    scale_values = _float_tokens(lines[1], "POSCAR scaling line")
    if len(scale_values) not in {1, 3}:
        raise VisualizationError("POSCAR scaling line must contain one or three values")
    raw = finite_array([_float_tokens(lines[index], f"POSCAR lattice row {index - 1}") for index in range(2, 5)], "POSCAR lattice")
    if raw.shape != (3, 3) or abs(float(np.linalg.det(raw))) <= 1.0e-14:
        raise VisualizationError("POSCAR lattice must be a nonsingular 3x3 matrix")
    cartesian_kpoints_scale: float | None = None
    if len(scale_values) == 1:
        scale = float(scale_values[0])
        if scale == 0.0:
            raise VisualizationError("POSCAR scale cannot be zero")
        if scale > 0.0:
            lattice = raw * scale
            cartesian_kpoints_scale = scale
        else:
            requested_volume = -scale
            factor = (requested_volume / abs(float(np.linalg.det(raw)))) ** (1.0 / 3.0)
            lattice = raw * factor
    else:
        scales = np.asarray(scale_values, dtype=float)
        if np.any(scales <= 0.0):
            raise VisualizationError("three-component POSCAR scales must all be positive")
        lattice = raw * scales[np.newaxis, :]
    if abs(float(np.linalg.det(lattice))) <= 1.0e-14:
        raise VisualizationError("scaled POSCAR lattice is singular")
    return np.asarray(lattice, dtype=float), cartesian_kpoints_scale, audited_file(source, "vasp_poscar")


def _parse_eigenval(path: str | Path, spin_channel: int) -> tuple[np.ndarray, np.ndarray, int, int, int, int, dict[str, Any]]:
    source = Path(path).resolve()
    if not source.is_file():
        raise VisualizationError(f"EIGENVAL does not exist: {source}")
    lines = source.read_text(encoding="utf-8").splitlines()
    if len(lines) < 7:
        raise VisualizationError("EIGENVAL is too short")
    first = _float_tokens(lines[0], "EIGENVAL header line 1")
    if len(first) < 4 or any(not float(value).is_integer() for value in first[:4]):
        raise VisualizationError("EIGENVAL header line 1 must begin with four integers")
    spin_count = int(first[3])
    if spin_count not in {1, 2}:
        raise VisualizationError(f"unsupported EIGENVAL spin-channel count: {spin_count}")
    if spin_channel not in range(1, spin_count + 1):
        raise VisualizationError(
            f"requested VASP spin_channel={spin_channel} is unavailable for ISPIN={spin_count}"
        )
    counts = _float_tokens(lines[5], "EIGENVAL NELECT/NKPTS/NBANDS line")
    if len(counts) != 3 or not all(float(value).is_integer() for value in counts):
        raise VisualizationError("EIGENVAL line 6 must contain exactly integer NELECT NKPTS NBANDS")
    nelect, nkpts, nbands = (int(value) for value in counts)
    if nkpts <= 0 or nbands <= 0:
        raise VisualizationError("EIGENVAL NKPTS and NBANDS must be positive")
    cursor = 6
    kpoints: list[list[float]] = []
    energies: list[list[float]] = []
    for k_index in range(nkpts):
        while cursor < len(lines) and not lines[cursor].strip():
            cursor += 1
        if cursor >= len(lines):
            raise VisualizationError(f"EIGENVAL ends before k-point block {k_index + 1}")
        row = _float_tokens(lines[cursor], f"EIGENVAL k-point row {k_index + 1}")
        cursor += 1
        if len(row) != 4:
            raise VisualizationError("each EIGENVAL k-point row must contain kx ky kz weight")
        kpoints.append(row[:3])
        band_energies: list[float] = []
        for expected_band in range(1, nbands + 1):
            if cursor >= len(lines) or not lines[cursor].strip():
                raise VisualizationError(
                    f"EIGENVAL k-point {k_index + 1} has fewer than NBANDS={nbands} rows"
                )
            band_row = _float_tokens(
                lines[cursor], f"EIGENVAL k-point {k_index + 1} band {expected_band}"
            )
            cursor += 1
            expected_columns = 3 if spin_count == 1 else 5
            if len(band_row) != expected_columns:
                raise VisualizationError(
                    f"EIGENVAL ISPIN={spin_count} band rows require {expected_columns} columns"
                )
            if not float(band_row[0]).is_integer() or int(band_row[0]) != expected_band:
                raise VisualizationError("EIGENVAL band indices are not consecutive 1:NBANDS")
            band_energies.append(float(band_row[spin_channel]))
        energies.append(band_energies)
    if any(line.strip() for line in lines[cursor:]):
        raise VisualizationError("EIGENVAL has trailing nonblank data beyond declared NKPTS/NBANDS")
    return (
        finite_array(kpoints, "EIGENVAL k points"),
        finite_array(energies, "EIGENVAL energies"),
        nelect,
        nkpts,
        nbands,
        spin_count,
        audited_file(source, "vasp_eigenval"),
    )


def _coordinate_line(line: str, line_number: int) -> tuple[np.ndarray, str]:
    coordinates, separator, comment = line.partition("!")
    values = _float_tokens(coordinates, f"KPOINTS coordinate line {line_number}")
    if len(values) not in {3, 4}:
        raise VisualizationError("KPOINTS line-mode endpoints require 3 coordinates and optional weight")
    label = comment.strip() if separator else ""
    if not label:
        raise VisualizationError("each KPOINTS line-mode endpoint must have an explicit ! label")
    return np.asarray(values[:3], dtype=float), label


def _parse_kpoints_line_mode(
    path: str | Path,
    lattice: np.ndarray,
    cartesian_scale: float | None,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, tuple[str, ...], str, dict[str, Any]]:
    source = Path(path).resolve()
    if not source.is_file():
        raise VisualizationError(f"KPOINTS does not exist: {source}")
    raw_lines = source.read_text(encoding="utf-8").splitlines()
    if len(raw_lines) < 6:
        raise VisualizationError("KPOINTS is too short for line-mode data")
    try:
        points_per_segment = int(raw_lines[1].strip())
    except ValueError as exc:
        raise VisualizationError("KPOINTS line 2 must be the integer points-per-segment") from exc
    if points_per_segment < 2:
        raise VisualizationError("KPOINTS line-mode requires at least two points per segment")
    if not raw_lines[2].strip().lower().startswith("l"):
        raise VisualizationError("KPOINTS must explicitly use line-mode")
    coordinate_token = raw_lines[3].strip().lower()
    if coordinate_token.startswith(("r", "d")):
        coordinate_mode = "reciprocal"
    elif coordinate_token.startswith(("c", "k")):
        coordinate_mode = "cartesian"
    else:
        raise VisualizationError("KPOINTS line-mode coordinate system must be Reciprocal or Cartesian")
    endpoint_lines = [(index + 1, line) for index, line in enumerate(raw_lines[4:], start=4) if line.strip()]
    if len(endpoint_lines) < 2 or len(endpoint_lines) % 2 != 0:
        raise VisualizationError("KPOINTS line-mode requires an even number of endpoint lines")
    endpoints = [_coordinate_line(line, number) for number, line in endpoint_lines]
    reciprocal_rows = 2.0 * np.pi * np.linalg.inv(lattice).T

    def to_fractional(values: np.ndarray) -> np.ndarray:
        if coordinate_mode == "reciprocal":
            return values
        if cartesian_scale is None:
            raise VisualizationError(
                "Cartesian KPOINTS requires a POSCAR with one positive scalar scale; "
                "negative-volume or three-scale POSCAR is ambiguous for the 2pi/a convention"
            )
        cart = values * (2.0 * np.pi / cartesian_scale)
        return np.linalg.solve(reciprocal_rows.T, cart)

    generated: list[np.ndarray] = []
    node_indices: list[int] = []
    node_labels: list[str] = []
    for segment_index in range(0, len(endpoints), 2):
        start, start_label = endpoints[segment_index]
        stop, stop_label = endpoints[segment_index + 1]
        start_fractional = to_fractional(start)
        stop_fractional = to_fractional(stop)
        segment = np.linspace(start_fractional, stop_fractional, points_per_segment, endpoint=True)
        start_index = len(generated)
        generated.extend(segment)
        node_indices.extend((start_index, start_index + points_per_segment - 1))
        node_labels.extend((start_label, stop_label))
    return (
        finite_array(generated, "KPOINTS generated line path"),
        np.asarray(node_indices, dtype=int),
        np.asarray([points_per_segment, len(endpoints) // 2], dtype=int),
        tuple(node_labels),
        coordinate_mode,
        audited_file(source, "vasp_kpoints_line_mode"),
    )


def load_vasp_native_pair(spec: dict[str, Any]) -> VASPNativeBandData:
    if str(spec.get("energy_unit", "")).lower() != "ev":
        raise VisualizationError("EIGENVAL energy_unit must be explicitly ev")
    if str(spec.get("energy_convention", "")).lower() != "absolute":
        raise VisualizationError("EIGENVAL energy_convention must be explicitly absolute")
    if str(spec.get("kpoint_coordinate_convention", "")).lower() != "fractional_crystal":
        raise VisualizationError(
            "EIGENVAL kpoint_coordinate_convention must explicitly be fractional_crystal"
        )
    try:
        spin_channel = int(spec["spin_channel"])
    except (KeyError, TypeError, ValueError) as exc:
        raise VisualizationError("EIGENVAL input requires integer spin_channel") from exc
    lattice, cartesian_scale, poscar_record = _parse_poscar(spec["poscar"])
    eigen_kpoints, energies, _, nkpts, _, spin_count, eigen_record = _parse_eigenval(
        spec["eigenval"], spin_channel
    )
    expected_kpoints, node_indices, segment_summary, node_labels, mode, kpoints_record = (
        _parse_kpoints_line_mode(spec["kpoints"], lattice, cartesian_scale)
    )
    if expected_kpoints.shape != eigen_kpoints.shape:
        raise VisualizationError(
            f"EIGENVAL NKPTS={nkpts} disagrees with KPOINTS line-mode expected "
            f"{expected_kpoints.shape[0]} (= segments x points-per-segment, with duplicate endpoints retained)"
        )
    if not np.allclose(eigen_kpoints, expected_kpoints, atol=1.0e-8, rtol=1.0e-10):
        delta = np.abs(eigen_kpoints - expected_kpoints)
        flat = int(np.argmax(delta))
        row, component = np.unravel_index(flat, delta.shape)
        raise VisualizationError(
            "EIGENVAL ordered k points disagree with KPOINTS line-mode at "
            f"point {row + 1}, component {component + 1}: max_abs={delta[row, component]:.6e}"
        )
    points_per_segment, segment_count = (int(value) for value in segment_summary)
    for segment in range(segment_count - 1):
        left = (segment + 1) * points_per_segment - 1
        right = left + 1
        if node_labels[2 * segment + 1] == node_labels[2 * segment + 2]:
            if not np.allclose(eigen_kpoints[left], eigen_kpoints[right], atol=1.0e-8, rtol=1.0e-10):
                raise VisualizationError(
                    "KPOINTS repeated labeled endpoint is not duplicated in EIGENVAL"
                )
    reciprocal_rows = 2.0 * np.pi * np.linalg.inv(lattice).T
    cartesian = eigen_kpoints @ reciprocal_rows
    steps = np.linalg.norm(np.diff(cartesian, axis=0), axis=1)
    # Line-mode segments are independent.  The first point of a new segment is
    # plotted at the preceding segment's terminal abscissa, even for a path
    # discontinuity; no unrequested Cartesian jump is inserted.
    for next_point in range(points_per_segment, nkpts, points_per_segment):
        steps[next_point - 1] = 0.0
    distance = np.concatenate(([0.0], np.cumsum(steps)))
    if distance.shape != (nkpts,) or np.any(np.diff(distance) < 0.0):
        raise VisualizationError("derived VASP path distance is invalid")
    return VASPNativeBandData(
        eigen_kpoints,
        energies,
        distance,
        node_indices,
        node_labels,
        lattice,
        reciprocal_rows,
        spin_channel,
        spin_count,
        points_per_segment,
        segment_count,
        mode,
        (eigen_record, kpoints_record, poscar_record),
    )
