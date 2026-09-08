from __future__ import annotations

from dataclasses import dataclass, field, replace
from pathlib import Path
from typing import Any
import re
import xml.etree.ElementTree as ET

import numpy as np

from .common import VisualizationError, audited_file, finite_array, load_json, sha256_file
from .vasp_native import load_vasp_native_pair


HARTREE_TO_EV = 27.211386245988

COMMON_SPEC_FIELDS = {
    "type", "id", "label", "qualification_label", "band_indices_zero_based",
    "fitted_band_indices_zero_based", "expected_sha256",
}
TYPE_SPEC_FIELDS = {
    "wanniernlqg": {"bands", "path"},
    "table": {"data", "path", "x_column", "energy_columns", "energy_unit", "energy_convention"},
    "qe_table": {"data", "path", "x_column", "energy_columns", "energy_unit", "energy_convention"},
    "vasp_table": {"data", "path", "x_column", "energy_columns", "energy_unit", "energy_convention"},
    "qe_xml": {"data", "path", "energy_unit", "energy_convention", "kpoint_coordinate_convention"},
    "vasp_xml": {"data", "path", "energy_unit", "energy_convention", "kpoint_coordinate_convention", "spin_channel"},
    "vasprun_xml": {"data", "path", "energy_unit", "energy_convention", "kpoint_coordinate_convention", "spin_channel"},
    "vasp_eigenval_kpoints": {
        "eigenval", "kpoints", "poscar", "energy_reference_ev", "energy_unit",
        "energy_convention", "kpoint_coordinate_convention", "spin_channel",
    },
}
REQUIRED_SPEC_FIELDS = {
    "wanniernlqg": {"bands", "path"},
    "table": {"data", "path", "energy_columns", "energy_unit", "energy_convention"},
    "qe_table": {"data", "path", "energy_columns", "energy_unit", "energy_convention"},
    "vasp_table": {"data", "path", "energy_columns", "energy_unit", "energy_convention"},
    "qe_xml": {"data", "path", "energy_unit", "energy_convention", "kpoint_coordinate_convention"},
    "vasp_xml": {"data", "path", "energy_unit", "energy_convention", "kpoint_coordinate_convention", "spin_channel"},
    "vasprun_xml": {"data", "path", "energy_unit", "energy_convention", "kpoint_coordinate_convention", "spin_channel"},
    "vasp_eigenval_kpoints": {
        "eigenval", "kpoints", "poscar", "energy_reference_ev", "energy_unit",
        "energy_convention", "kpoint_coordinate_convention", "spin_channel",
    },
}


def _validate_spec(spec: Any, source_type: str) -> None:
    if not isinstance(spec, dict):
        raise VisualizationError("each band dataset specification must be an object")
    allowed = COMMON_SPEC_FIELDS | TYPE_SPEC_FIELDS[source_type]
    unknown = sorted(set(spec) - allowed)
    if unknown:
        raise VisualizationError(f"unknown {source_type} dataset fields: {', '.join(unknown)}")
    missing = sorted(field for field in REQUIRED_SPEC_FIELDS[source_type] if field not in spec)
    if missing:
        raise VisualizationError(f"missing {source_type} dataset fields: {', '.join(missing)}")
    for field in ("id", "label"):
        if field in spec and (not isinstance(spec[field], str) or not spec[field].strip()):
            raise VisualizationError(f"band dataset {field} must be a nonempty string")
    if "energy_columns" in spec:
        columns = spec["energy_columns"]
        if not isinstance(columns, dict) or set(columns) != {"start", "stop"}:
            raise VisualizationError("energy_columns must contain exactly start and stop")
    expected = spec.get("expected_sha256")
    if expected is None:
        return
    if not isinstance(expected, dict) or not expected:
        raise VisualizationError("expected_sha256 must be a nonempty object keyed by input field")
    path_fields = {"bands", "path", "data", "eigenval", "kpoints", "poscar"} & TYPE_SPEC_FIELDS[source_type]
    unknown_hashes = sorted(set(expected) - path_fields)
    if unknown_hashes:
        raise VisualizationError(f"expected_sha256 has unknown input fields: {', '.join(unknown_hashes)}")
    for field, digest in expected.items():
        if not isinstance(digest, str) or len(digest) != 64 or any(char not in "0123456789abcdefABCDEF" for char in digest):
            raise VisualizationError(f"expected_sha256.{field} must be a 64-character hexadecimal digest")
        source = Path(spec[field]).resolve()
        if not source.is_file():
            raise VisualizationError(f"expected_sha256 input does not exist: {source}")
        actual = sha256_file(source)
        if actual.lower() != digest.lower():
            raise VisualizationError(
                f"{source_type} input digest mismatch for {field}: expected {digest.lower()}, got {actual}"
            )


@dataclass(frozen=True)
class BandDataset:
    dataset_id: str
    label: str
    source_type: str
    distance: np.ndarray
    fractional_kpoints: np.ndarray
    energies_ev: np.ndarray
    node_distances: np.ndarray
    node_labels: tuple[str, ...]
    energy_reference_ev: float
    energies_are_relative: bool
    qualification_label: str
    inputs: tuple[dict[str, Any], ...]
    source_details: dict[str, Any] = field(default_factory=dict)

    def audit_record(self) -> dict[str, Any]:
        return {
            "id": self.dataset_id,
            "label": self.label,
            "source_type": self.source_type,
            "kpoint_count": int(self.distance.size),
            "band_count": int(self.energies_ev.shape[1]),
            "array_shape": list(self.energies_ev.shape),
            "energy_unit": "eV",
            "energy_reference_ev": float(self.energy_reference_ev),
            "energy_convention": "relative_to_declared_reference" if self.energies_are_relative else "absolute",
            "qualification_label": self.qualification_label,
            **self.source_details,
        }


def _numeric_table(path: str | Path, minimum_columns: int, header_tokens: tuple[str, ...] = ()) -> np.ndarray:
    source = Path(path).resolve()
    if not source.is_file():
        raise VisualizationError(f"band table does not exist: {source}")
    header = "\n".join(line.strip() for line in source.read_text(encoding="utf-8").splitlines() if line.lstrip().startswith("#"))
    if header_tokens and not all(token in header for token in header_tokens):
        raise VisualizationError(f"band table is missing required header tokens: {header_tokens}")
    try:
        table = np.loadtxt(source, comments="#", ndmin=2)
    except (OSError, ValueError) as exc:
        raise VisualizationError(f"cannot parse numeric band table {source}: {exc}") from exc
    table = finite_array(table, "band table")
    if table.ndim != 2 or table.shape[1] < minimum_columns:
        raise VisualizationError(f"band table requires at least {minimum_columns} columns")
    return np.asarray(table, dtype=float)


def _wanniernlqg_band_contract(path: str | Path) -> float:
    source = Path(path).resolve()
    fields: dict[str, str] = {}
    pattern = re.compile(r"^#\s*([^=]+?)\s*=\s*(.*?)\s*$")
    with source.open("r", encoding="utf-8") as stream:
        for line in stream:
            matched = pattern.match(line.rstrip("\n"))
            if matched is not None:
                fields[matched.group(1).strip()] = matched.group(2).strip()
    if fields.get("energy_convention") != "ascending_eigenvalues_minus_E_ref":
        raise VisualizationError("unsupported WannierNLQG band energy convention")
    if fields.get("energy_unit") != "eV":
        raise VisualizationError("WannierNLQG band table must declare eV energy")
    try:
        reference = float(fields["energy_reference_E_ref_eV"])
    except (KeyError, ValueError) as exception:
        raise VisualizationError("WannierNLQG band table lacks a valid E_ref_eV") from exception
    if not np.isfinite(reference):
        raise VisualizationError("WannierNLQG band table E_ref_eV must be finite")
    return reference


def _path_contract(path: str | Path, point_count: int, table_kpoints: np.ndarray | None = None) -> tuple[np.ndarray, np.ndarray, tuple[str, ...], float | None, tuple[dict[str, Any], ...]]:
    source = Path(path).resolve()
    payload = load_json(source)
    schema = payload.get("schema")
    if schema == "wanniernlqg.kpath":
        if payload.get("schema_version") != "1.0":
            raise VisualizationError("unsupported WannierNLQG kpath schema_version")
        if int(payload.get("total_kpoints", -1)) != point_count:
            raise VisualizationError("band path total_kpoints disagrees with the energy data")
        if payload.get("distance_unit") != "A^-1":
            raise VisualizationError("KPath sidecar must declare A^-1 distance")
        if payload.get("shared_segment_endpoints_written_once") is not True:
            raise VisualizationError("band path must write shared segment endpoints once")
        if payload.get("fractional_coordinates_folded") is not False:
            raise VisualizationError("band path must retain the declared unfurled coordinates")
        if payload.get("lattice_convention") != "row-lattice":
            raise VisualizationError("unsupported band lattice convention")
        if payload.get("reciprocal_lattice_convention") != "B=2pi*A^(-T)":
            raise VisualizationError("unsupported band reciprocal-lattice convention")
        nodes = payload.get("node_chain")
        if not isinstance(nodes, list) or len(nodes) < 2:
            raise VisualizationError("band path needs at least two nodes")
        segments = payload.get("segments")
        if not isinstance(segments, list) or len(segments) != len(nodes) - 1:
            raise VisualizationError("band segment count disagrees with the node chain")
        if table_kpoints is None:
            raise VisualizationError("WannierNLQG path sidecar requires table k points and distance")
        node_distances: list[float] = []
        node_labels: list[str] = []
        node_indices: list[int] = []
        for node in nodes:
            index = int(node["point_index_one_based"]) - 1
            if not 0 <= index < point_count:
                raise VisualizationError("band node index is outside the data")
            label = str(node["label"])
            if not label.strip():
                raise VisualizationError("band node label cannot be empty")
            distance = float(node["cumulative_distance_A_inverse"])
            if not np.isfinite(distance):
                raise VisualizationError("band node distance must be finite")
            node_indices.append(index)
            node_distances.append(distance)
            node_labels.append(label)
            declared = finite_array(node["fractional_coordinates"], "band node coordinates")
            if declared.shape != (3,) or not np.allclose(declared, table_kpoints[index], atol=1e-12, rtol=1e-12):
                raise VisualizationError("band node coordinates disagree with the band table")
        if node_indices[0] != 0 or node_indices[-1] != point_count - 1 or any(b <= a for a, b in zip(node_indices, node_indices[1:])):
            raise VisualizationError("band nodes must span the table with strictly increasing indices")
        for segment_number, segment in enumerate(segments, start=1):
            start = node_indices[segment_number - 1]
            stop = node_indices[segment_number]
            if int(segment.get("segment_index_one_based", -1)) != segment_number:
                raise VisualizationError("band segment indices must be contiguous")
            if int(segment.get("start_node_index_one_based", -1)) != segment_number:
                raise VisualizationError("band segment start-node index is inconsistent")
            if int(segment.get("end_node_index_one_based", -1)) != segment_number + 1:
                raise VisualizationError("band segment end-node index is inconsistent")
            if int(segment.get("start_point_index_one_based", -1)) != start + 1:
                raise VisualizationError("band segment start point disagrees with the node chain")
            if int(segment.get("end_point_index_one_based", -1)) != stop + 1:
                raise VisualizationError("band segment end point disagrees with the node chain")
            if int(segment.get("kpoints_including_endpoints", -1)) != stop - start + 1:
                raise VisualizationError("band segment k-point count is inconsistent")
        return (
            np.asarray(node_distances, dtype=float),
            np.asarray(node_indices, dtype=int),
            tuple(node_labels),
            None,
            (audited_file(source, "kpath"),),
        )
    if schema == "wanniernlqg.visualization-band-path":
        if payload.get("schema_version") != "1.0":
            raise VisualizationError("unsupported visualization band-path schema_version")
        if payload.get("distance_unit") != "A^-1" or payload.get("energy_unit") != "eV":
            raise VisualizationError("visualization band path must declare A^-1 distance and eV energy")
        if payload.get("kpoint_coordinate_convention") != "fractional_crystal":
            raise VisualizationError(
                "visualization band path must declare kpoint_coordinate_convention=fractional_crystal"
            )
        kpoints = finite_array(payload.get("fractional_kpoints"), "path fractional_kpoints")
        distances = finite_array(payload.get("distances_A_inverse"), "path distances")
        if kpoints.shape != (point_count, 3) or distances.shape != (point_count,):
            raise VisualizationError("visualization path arrays disagree with the band data")
        if np.any(np.diff(distances) < 0.0):
            raise VisualizationError("visualization path distances must be nondecreasing")
        nodes = payload.get("nodes")
        if not isinstance(nodes, list) or len(nodes) < 2:
            raise VisualizationError("visualization path needs at least two nodes")
        node_indices = np.asarray([int(node["index_zero_based"]) for node in nodes], dtype=int)
        if node_indices[0] != 0 or node_indices[-1] != point_count - 1 or np.any(np.diff(node_indices) <= 0):
            raise VisualizationError("visualization path node indices are invalid")
        node_distances = distances[node_indices]
        node_labels = tuple(str(node["label"]) for node in nodes)
        if any(not label.strip() for label in node_labels):
            raise VisualizationError("visualization path node labels cannot be empty")
        reference = float(payload.get("energy_reference_ev", float("nan")))
        if not np.isfinite(reference):
            raise VisualizationError("visualization path energy_reference_ev must be finite")
        return node_distances, node_indices, node_labels, reference, (audited_file(source, "band_path"),)
    raise VisualizationError(f"unsupported band path schema: {schema}")


def load_wanniernlqg_dataset(spec: dict[str, Any]) -> BandDataset:
    bands = Path(spec["bands"]).resolve()
    table = _numeric_table(
        bands,
        5,
        ("distance_A^-1", "k1_fractional", "band_1_minus_E_ref_eV"),
    )
    if np.any(np.diff(table[:, 0]) < 0.0):
        raise VisualizationError("band distance must be nondecreasing")
    energies = table[:, 4:]
    if np.any(np.diff(energies, axis=1) < 0.0):
        raise VisualizationError("WannierNLQG energies must be ascending at each k point")
    energy_reference = _wanniernlqg_band_contract(bands)
    node_distances, _, node_labels, _, path_inputs = _path_contract(
        spec["path"], table.shape[0], table[:, 1:4]
    )
    path_payload = load_json(spec["path"])
    for node, distance in zip(path_payload["node_chain"], node_distances):
        row = int(node["point_index_one_based"]) - 1
        if not np.isclose(table[row, 0], distance, atol=1e-12, rtol=1e-12):
            raise VisualizationError("band node distance disagrees with the table")
    return BandDataset(
        str(spec.get("id", "bands")),
        str(spec.get("label", "Bands")),
        "wanniernlqg",
        table[:, 0].copy(),
        table[:, 1:4].copy(),
        energies.copy(),
        node_distances,
        node_labels,
        energy_reference,
        True,
        str(spec.get("qualification_label", "PRESENTATION_ONLY")),
        (audited_file(bands, "band_table"),) + path_inputs,
    )


def load_standard_table_dataset(spec: dict[str, Any]) -> BandDataset:
    data = Path(spec["data"]).resolve()
    table = _numeric_table(data, 2)
    x_column = int(spec.get("x_column", 0))
    start = int(spec["energy_columns"]["start"])
    stop = int(spec["energy_columns"]["stop"])
    if not (0 <= x_column < table.shape[1] and 0 <= start < stop <= table.shape[1]):
        raise VisualizationError("standard table column selection is invalid")
    distance = table[:, x_column]
    energies = table[:, start:stop]
    path_payload = load_json(spec["path"])
    kpoints = finite_array(path_payload.get("fractional_kpoints"), "path fractional_kpoints")
    node_distances, _, node_labels, path_reference, path_inputs = _path_contract(
        spec["path"], table.shape[0], kpoints
    )
    if not np.allclose(
        distance,
        finite_array(path_payload["distances_A_inverse"], "path distance"),
        atol=1e-12,
        rtol=1e-12,
    ):
        raise VisualizationError("standard table x grid disagrees with the path sidecar")
    energy_unit = str(spec.get("energy_unit", "")).lower()
    if energy_unit == "ev":
        factor = 1.0
    elif energy_unit == "hartree":
        factor = HARTREE_TO_EV
    else:
        raise VisualizationError("standard table energy_unit must be explicitly ev or hartree")
    convention = str(spec.get("energy_convention", "")).lower()
    if convention not in {"absolute", "relative_to_reference"}:
        raise VisualizationError(
            "standard table energy_convention must be absolute or relative_to_reference"
        )
    return BandDataset(
        str(spec.get("id", "table")), str(spec.get("label", "Table")), "table", distance.copy(), kpoints.copy(),
        energies.copy() * factor, node_distances, node_labels, path_reference,
        convention == "relative_to_reference",
        str(spec.get("qualification_label", "PRESENTATION_ONLY")),
        (audited_file(data, "band_table"),) + path_inputs,
    )


def _xml_local(element: ET.Element) -> str:
    return element.tag.rsplit("}", 1)[-1]


def _visualization_path_arrays(path: str | Path, point_count: int) -> tuple[np.ndarray, np.ndarray, tuple[str, ...], float, tuple[dict[str, Any], ...]]:
    payload = load_json(path)
    if payload.get("schema") != "wanniernlqg.visualization-band-path":
        raise VisualizationError("QE/VASP XML inputs require a visualization-band-path sidecar")
    kpoints = finite_array(payload.get("fractional_kpoints"), "path fractional_kpoints")
    distances = finite_array(payload.get("distances_A_inverse"), "path distances")
    if kpoints.shape != (point_count, 3) or distances.shape != (point_count,):
        raise VisualizationError("XML band path arrays disagree with the XML k-point count")
    node_distances, _, node_labels, reference, inputs = _path_contract(path, point_count, kpoints)
    return kpoints, distances, node_labels, reference, inputs


def load_qe_xml_dataset(spec: dict[str, Any]) -> BandDataset:
    source = Path(spec["data"]).resolve()
    if not source.is_file():
        raise VisualizationError(f"QE data-file-schema XML does not exist: {source}")
    try:
        root = ET.parse(source).getroot()
    except (OSError, ET.ParseError) as exc:
        raise VisualizationError(f"cannot parse QE XML {source}: {exc}") from exc
    records = [element for element in root.iter() if _xml_local(element) == "ks_energies"]
    if not records:
        raise VisualizationError("QE XML contains no ks_energies records")
    kpoints: list[list[float]] = []
    energies: list[list[float]] = []
    for record in records:
        k_element = next((child for child in record if _xml_local(child) == "k_point"), None)
        e_element = next((child for child in record if _xml_local(child) == "eigenvalues"), None)
        if k_element is None or e_element is None or not k_element.text or not e_element.text:
            raise VisualizationError("QE ks_energies record is incomplete")
        kpoints.append([float(value) for value in k_element.text.split()])
        energies.append([float(value) for value in e_element.text.split()])
    if len({len(row) for row in energies}) != 1:
        raise VisualizationError("QE XML has inconsistent band counts")
    xml_kpoints = finite_array(kpoints, "QE XML k points")
    xml_energies = finite_array(energies, "QE XML energies")
    if xml_kpoints.shape != (len(records), 3):
        raise VisualizationError("QE XML k points must be three-dimensional fractional coordinates")
    path_kpoints, distance, node_labels, reference, path_inputs = _visualization_path_arrays(
        spec["path"], len(records)
    )
    if not np.allclose(xml_kpoints, path_kpoints, atol=1e-12, rtol=1e-12):
        raise VisualizationError("QE XML ordered k points disagree with the path sidecar")
    unit = str(spec.get("energy_unit", "")).lower()
    factor = HARTREE_TO_EV if unit == "hartree" else 1.0 if unit == "ev" else None
    if factor is None:
        raise VisualizationError("QE XML energy_unit must be explicitly hartree or ev")
    if str(spec.get("energy_convention", "")).lower() != "absolute":
        raise VisualizationError("QE XML energy_convention must be explicitly absolute")
    if str(spec.get("kpoint_coordinate_convention", "")).lower() != "fractional_crystal":
        raise VisualizationError(
            "QE XML kpoint_coordinate_convention must be explicitly fractional_crystal"
        )
    payload = load_json(spec["path"])
    node_indices = np.asarray([int(node["index_zero_based"]) for node in payload["nodes"]], dtype=int)
    return BandDataset(
        str(spec.get("id", "qe")), str(spec.get("label", "QE")), "qe_data_file_schema_xml", distance,
        xml_kpoints, xml_energies * factor, distance[node_indices], node_labels, reference,
        False, str(spec.get("qualification_label", "PRESENTATION_ONLY")),
        (audited_file(source, "qe_data_file_schema_xml"),) + path_inputs,
    )


def load_vasprun_xml_dataset(spec: dict[str, Any]) -> BandDataset:
    source = Path(spec["data"]).resolve()
    if not source.is_file():
        raise VisualizationError(f"vasprun.xml does not exist: {source}")
    try:
        root = ET.parse(source).getroot()
    except (OSError, ET.ParseError) as exc:
        raise VisualizationError(f"cannot parse vasprun.xml {source}: {exc}") from exc
    kpoint_varray = next(
        (
            element
            for element in root.iter()
            if _xml_local(element) == "varray" and element.attrib.get("name") == "kpointlist"
        ),
        None,
    )
    if kpoint_varray is None:
        raise VisualizationError("vasprun.xml contains no kpointlist")
    xml_kpoints = finite_array(
        [[float(value) for value in (row.text or "").split()] for row in kpoint_varray if _xml_local(row) == "v"],
        "VASP XML k points",
    )
    eigen_arrays = [
        element
        for element in root.iter()
        if _xml_local(element) == "array" and element.attrib.get("name") == "eigenvalues"
    ]
    if not eigen_arrays:
        raise VisualizationError("vasprun.xml contains no eigenvalues array")
    outer_sets = [child for child in eigen_arrays[-1].iter() if _xml_local(child) == "set" and child.attrib.get("comment", "").startswith("spin")]
    if not outer_sets:
        raise VisualizationError("vasprun.xml eigenvalues contain no spin set")
    if "spin_channel" not in spec:
        raise VisualizationError("vasprun.xml input must explicitly select spin_channel")
    spin_channel = int(spec["spin_channel"])
    if not 1 <= spin_channel <= len(outer_sets):
        raise VisualizationError("requested VASP spin_channel is unavailable")
    k_sets = [child for child in outer_sets[spin_channel - 1] if _xml_local(child) == "set"]
    energies: list[list[float]] = []
    for k_set in k_sets:
        rows = [child for child in k_set if _xml_local(child) == "r"]
        energies.append([float((row.text or "").split()[0]) for row in rows])
    xml_energies = finite_array(energies, "VASP XML energies")
    if xml_kpoints.shape != (xml_energies.shape[0], 3):
        raise VisualizationError("vasprun.xml k-point and eigenvalue counts disagree")
    path_kpoints, distance, node_labels, reference, path_inputs = _visualization_path_arrays(
        spec["path"], xml_energies.shape[0]
    )
    if not np.allclose(xml_kpoints, path_kpoints, atol=1e-12, rtol=1e-12):
        raise VisualizationError("vasprun.xml ordered k points disagree with the path sidecar")
    if str(spec.get("energy_unit", "")).lower() != "ev":
        raise VisualizationError("vasprun.xml energy_unit must be explicitly ev")
    if str(spec.get("energy_convention", "")).lower() != "absolute":
        raise VisualizationError("vasprun.xml energy_convention must be explicitly absolute")
    if str(spec.get("kpoint_coordinate_convention", "")).lower() != "fractional_crystal":
        raise VisualizationError(
            "vasprun.xml kpoint_coordinate_convention must be explicitly fractional_crystal"
        )
    payload = load_json(spec["path"])
    node_indices = np.asarray([int(node["index_zero_based"]) for node in payload["nodes"]], dtype=int)
    return BandDataset(
        str(spec.get("id", "vasp")), str(spec.get("label", "VASP")), "vasprun_xml", distance, xml_kpoints,
        xml_energies, distance[node_indices], node_labels, reference, False,
        str(spec.get("qualification_label", "PRESENTATION_ONLY")),
        (audited_file(source, "vasprun_xml"),) + path_inputs,
    )


def load_vasp_eigenval_kpoints_dataset(spec: dict[str, Any]) -> BandDataset:
    parsed = load_vasp_native_pair(spec)
    reference = float(spec["energy_reference_ev"])
    if not np.isfinite(reference):
        raise VisualizationError("VASP energy_reference_ev must be finite")
    return BandDataset(
        str(spec.get("id", "vasp_native")),
        str(spec.get("label", "VASP EIGENVAL")),
        "vasp_eigenval_kpoints",
        parsed.distances_inverse_angstrom.copy(),
        parsed.fractional_kpoints.copy(),
        parsed.energies_ev.copy(),
        parsed.distances_inverse_angstrom[parsed.node_indices].copy(),
        parsed.node_labels,
        reference,
        False,
        str(spec.get("qualification_label", "PRESENTATION_ONLY")),
        parsed.inputs,
        {
            "EIGENVAL_kpoints_authoritative": True,
            "KPOINTS_role": "line_mode_segment_contract_only",
            "KPOINTS_coordinate_mode": parsed.kpoints_coordinate_mode,
            "points_per_segment": parsed.points_per_segment,
            "segment_count": parsed.segment_count,
            "duplicate_segment_endpoints_retained": True,
            "spin_channel": parsed.spin_channel,
            "spin_count": parsed.spin_count,
            "lattice_convention": "row_lattice_A",
            "reciprocal_lattice_convention": "B=2pi*A^{-T}",
            "lattice_rows_angstrom": parsed.lattice_rows_angstrom.tolist(),
            "reciprocal_rows_inverse_angstrom": parsed.reciprocal_rows_inverse_angstrom.tolist(),
        },
    )
def _select_bands(dataset: BandDataset, spec: dict[str, Any]) -> BandDataset:
    source_band_count = int(dataset.energies_ev.shape[1])
    selection = spec.get("band_indices_zero_based")
    if selection is None:
        selected = list(range(source_band_count))
        return replace(
            dataset,
            source_details={
                **dataset.source_details,
                "source_band_count": source_band_count,
                "selected_band_indices_zero_based": selected,
                "complete_source_band_set_loaded": True,
            },
        )
    if not isinstance(selection, list) or not selection:
        raise VisualizationError("band_indices_zero_based must be a nonempty integer list")
    indices = np.asarray(selection, dtype=int)
    if len(set(int(value) for value in indices)) != len(indices):
        raise VisualizationError("band_indices_zero_based contains duplicates")
    if np.any(indices < 0) or np.any(indices >= dataset.energies_ev.shape[1]):
        raise VisualizationError("band_indices_zero_based is outside the source band range")
    return replace(
        dataset,
        energies_ev=dataset.energies_ev[:, indices].copy(),
        source_details={
            **dataset.source_details,
            "source_band_count": source_band_count,
            "selected_band_indices_zero_based": [int(value) for value in indices],
            "complete_source_band_set_loaded": len(indices) == source_band_count,
        },
    )


def load_dataset(spec: dict[str, Any]) -> BandDataset:
    if not isinstance(spec, dict):
        raise VisualizationError("each band dataset specification must be an object")
    source_type = str(spec.get("type", "wanniernlqg")).lower()
    if source_type not in TYPE_SPEC_FIELDS:
        raise VisualizationError(
            "supported band inputs are wanniernlqg, table, qe_xml, vasprun_xml, "
            "or vasp_eigenval_kpoints"
        )
    _validate_spec(spec, source_type)
    if source_type == "wanniernlqg":
        return _select_bands(load_wanniernlqg_dataset(spec), spec)
    if source_type in {"table", "qe_table", "vasp_table"}:
        return _select_bands(load_standard_table_dataset(spec), spec)
    if source_type == "qe_xml":
        return _select_bands(load_qe_xml_dataset(spec), spec)
    if source_type in {"vasp_xml", "vasprun_xml"}:
        return _select_bands(load_vasprun_xml_dataset(spec), spec)
    if source_type == "vasp_eigenval_kpoints":
        return _select_bands(load_vasp_eigenval_kpoints_dataset(spec), spec)
    raise AssertionError("validated band source type was not dispatched")


def displayed_energies(dataset: BandDataset) -> np.ndarray:
    """Return energies relative to the one declared common reference."""
    if dataset.energies_are_relative:
        return dataset.energies_ev
    return dataset.energies_ev - dataset.energy_reference_ev


def validate_shared_path(reference: BandDataset, model: BandDataset) -> None:
    if reference.distance.shape != model.distance.shape or not np.allclose(reference.distance, model.distance, atol=1e-12, rtol=1e-12):
        raise VisualizationError("band comparison x grids differ; silent interpolation is forbidden")
    if reference.fractional_kpoints.shape != model.fractional_kpoints.shape or not np.allclose(reference.fractional_kpoints, model.fractional_kpoints, atol=1e-12, rtol=1e-12):
        raise VisualizationError("band comparison ordered k paths differ")
    if reference.node_labels != model.node_labels or not np.allclose(reference.node_distances, model.node_distances, atol=1e-12, rtol=1e-12):
        raise VisualizationError("band comparison high-symmetry paths differ")
    if not np.isclose(reference.energy_reference_ev, model.energy_reference_ev, atol=1e-12, rtol=1e-12):
        raise VisualizationError("band datasets declare different energy references; silent shifts are forbidden")
