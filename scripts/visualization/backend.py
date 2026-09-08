from __future__ import annotations

import copy
import math
from pathlib import Path
from typing import Any

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm, Normalize, SymLogNorm, TwoSlopeNorm
from mpl_toolkits.axes_grid1 import make_axes_locatable
import numpy as np

from .band_adapters import displayed_energies, load_dataset, validate_shared_path
from .band_comparison import (
    BandErrorAssessment,
    load_error_assessments,
    resolve_full_display_sets,
)
from .common import (
    VisualizationError,
    audited_file,
    load_json,
    relative_l2,
    save_figure_atomic,
    seal_plot_sidecar,
)
from .kslice_parser import (
    cartesian_projection_grid,
    combine_parts,
    load_matrix,
    load_metadata,
    load_model_lattice,
)
from .response_parser import load_response, select_part, validate_response_comparison
from .style import apply_margins, apply_style, resolve_style, style_axes, tex_text


DEFAULT_CURVES = [
    {"color": "#606060", "linestyle": "-", "linewidth": 1.4, "marker": "", "markerfacecolor": "none", "markeredgecolor": "", "markersize": 4.0, "markevery": 1, "zorder": 2},
    {"color": "#104E8B", "linestyle": "--", "linewidth": 1.6, "marker": "", "markerfacecolor": "none", "markeredgecolor": "", "markersize": 4.0, "markevery": 1, "zorder": 3},
    {"color": "#FF7F24", "linestyle": "-.", "linewidth": 1.6, "marker": "", "markerfacecolor": "none", "markeredgecolor": "", "markersize": 4.0, "markevery": 1, "zorder": 4},
    {"color": "#3CB371", "linestyle": ":", "linewidth": 1.6, "marker": "", "markerfacecolor": "none", "markeredgecolor": "", "markersize": 4.0, "markevery": 1, "zorder": 5},
]

RESPONSE_CURVES = [
    {**curve, "marker": marker, "markevery": 8}
    for curve, marker in zip(DEFAULT_CURVES, ("o", "s", "^", "D"))
]


def _banner(axis: Any, text: str | None) -> None:
    if text:
        axis.text(
            0.5,
            0.97,
            tex_text(text),
            transform=axis.transAxes,
            ha="center",
            va="top",
            color="#9B1C1C",
            fontsize=10,
            fontweight="bold",
            bbox={"facecolor": "white", "edgecolor": "#9B1C1C", "alpha": 0.88},
            zorder=20,
        )


def _band_figure(datasets: list[Any], config: dict[str, Any], style: dict[str, Any]) -> Any:
    figure, axis = plt.subplots(figsize=tuple(style["figsize"]))
    effective_curves: dict[str, dict[str, Any]] = {}
    for dataset_index, dataset in enumerate(datasets):
        curve = dict(DEFAULT_CURVES[min(dataset_index, len(DEFAULT_CURVES) - 1)])
        curve.update((config.get("curves") or {}).get(dataset.dataset_id, {}))
        effective_curves[dataset.dataset_id] = curve
        energies = displayed_energies(dataset)
        band_roles = config.get("_reference_band_roles") if dataset_index == 0 else None
        fitted_indices = (
            set(int(value) for value in band_roles["fitted_indices_zero_based"])
            if isinstance(band_roles, dict)
            else None
        )
        unfitted_curve = dict(config.get("unfitted_reference_curve") or {})
        for band_index in range(energies.shape[1]):
            band_curve = (
                curve
                if fitted_indices is None or band_index in fitted_indices
                else unfitted_curve
            )
            label = None
            if fitted_indices is None and band_index == 0:
                label = dataset.label
            elif fitted_indices is not None and band_index == min(fitted_indices):
                label = dataset.label
            axis.plot(
                dataset.distance,
                energies[:, band_index],
                color=band_curve["color"],
                linestyle=band_curve["linestyle"],
                linewidth=float(band_curve["linewidth"]),
                marker=band_curve.get("marker") or None,
                markerfacecolor=band_curve.get("markerfacecolor", "none"),
                markeredgecolor=band_curve.get("markeredgecolor") or band_curve["color"],
                markersize=float(band_curve.get("markersize", 4.0)),
                markevery=int(band_curve.get("markevery", 1)),
                solid_capstyle="round",
                label=label,
                zorder=float(band_curve.get("zorder", 2 + dataset_index)),
            )
    config["effective_curves"] = effective_curves
    reference = datasets[0]
    for location in reference.node_distances:
        axis.axvline(location, color="#777777", linewidth=0.65, linestyle="-", zorder=0)
    axis.axhline(0.0, color="#404040", linewidth=0.85, linestyle="--", dashes=(4, 3), zorder=1)
    axis.set_xticks(reference.node_distances)
    axis.set_xticklabels([tex_text(label) for label in reference.node_labels])
    axis.set_xlim(float(reference.distance[0]), float(reference.distance[-1]))
    if config.get("energy_window") is not None:
        minimum, maximum = [float(value) for value in config["energy_window"]]
        if not minimum < maximum:
            raise VisualizationError("band energy_window minimum must be below maximum")
        axis.set_ylim(minimum, maximum)
    axis.set_xlabel(config.get("xlabel") or r"$k$-path distance $\mathrm{(\AA^{-1})}$")
    axis.set_ylabel(config.get("ylabel") or r"$E_n-E_{\mathrm{ref}}\ \mathrm{(eV)}$")
    if config.get("title"):
        axis.set_title(tex_text(str(config["title"])), pad=8.0)
    if len(datasets) > 1:
        legend = style["legend"]
        axis.legend(
            loc=legend["location"], ncol=int(legend["columns"]), frameon=bool(legend["frame"]),
            framealpha=float(legend["framealpha"]), facecolor=legend["facecolor"],
            edgecolor=legend["edgecolor"],
        )
    style_axes(axis, style)
    _banner(axis, config.get("diagnostic_banner"))
    apply_margins(figure, style)
    return figure


def _band_error_figure(
    reference: Any,
    models: list[Any],
    assessments: list[BandErrorAssessment],
    config: dict[str, Any],
    style: dict[str, Any],
) -> Any:
    """Plot per-k RMS and maximum errors recomputed from sealed match maps."""
    figure, axis = plt.subplots(figsize=tuple(style["figsize"]))
    model_by_id = {model.dataset_id: model for model in models}
    for model_index, assessment in enumerate(assessments):
        model = model_by_id[assessment.model_id]
        base_curve = dict(DEFAULT_CURVES[min(model_index + 1, len(DEFAULT_CURVES) - 1)])
        base_curve.update((config.get("curves") or {}).get(model.dataset_id, {}))
        axis.plot(
            reference.distance,
            assessment.per_k_rms_ev,
            color=base_curve["color"],
            linestyle="-",
            linewidth=float(base_curve["linewidth"]),
            label=(
                "Per-k RMS error"
                if len(assessments) == 1
                else f"{model.label}: per-k RMS"
            ),
            zorder=4 + model_index,
        )
        axis.plot(
            reference.distance,
            assessment.per_k_maximum_ev,
            color="#FF7F24" if len(assessments) == 1 else base_curve["color"],
            linestyle="--",
            linewidth=float(base_curve["linewidth"]),
            label=(
                "Per-k maximum absolute error"
                if len(assessments) == 1
                else f"{model.label}: per-k maximum absolute error"
            ),
            zorder=8 + model_index,
        )
    for location in reference.node_distances:
        axis.axvline(location, color="#777777", linewidth=0.65, linestyle="-", zorder=0)
    axis.set_xticks(reference.node_distances)
    axis.set_xticklabels([tex_text(label) for label in reference.node_labels])
    axis.set_xlim(float(reference.distance[0]), float(reference.distance[-1]))
    error_config = config["error_assessment"]
    y_window = error_config.get("y_window")
    if y_window is None:
        maximum = max(float(np.max(item.per_k_maximum_ev)) for item in assessments)
        axis.set_ylim(0.0, 1.08 * maximum if maximum > 0.0 else 1.0)
    else:
        if (
            not isinstance(y_window, list)
            or len(y_window) != 2
            or not all(isinstance(value, (int, float)) and np.isfinite(value) for value in y_window)
            or not float(y_window[0]) < float(y_window[1])
        ):
            raise VisualizationError("error_assessment.y_window must contain two increasing finite values")
        if float(y_window[0]) > 0.0 or any(
            float(np.max(item.per_k_maximum_ev)) > float(y_window[1]) for item in assessments
        ):
            raise VisualizationError("error_assessment.y_window clips a computed error curve")
        axis.set_ylim(float(y_window[0]), float(y_window[1]))
    axis.set_xlabel(config.get("xlabel") or r"$k$-path distance $\mathrm{(\AA^{-1})}$")
    axis.set_ylabel(str(error_config.get("ylabel") or "Matched energy error (eV)"))
    title = str(error_config.get("title") or "")
    if title:
        axis.set_title(tex_text(title), pad=8.0)
    legend = style["legend"]
    legend_location = str(error_config.get("legend_location", "upper right"))
    legend_columns = error_config.get("legend_columns", 2)
    if isinstance(legend_columns, bool) or not isinstance(legend_columns, int) or legend_columns <= 0:
        raise VisualizationError("error_assessment.legend_columns must be a positive integer")
    axis.legend(
        loc=legend_location,
        ncol=legend_columns,
        frameon=bool(legend["frame"]),
        framealpha=float(legend["framealpha"]),
        facecolor=legend["facecolor"],
        edgecolor=legend["edgecolor"],
    )
    style_axes(axis, style)
    apply_margins(figure, style)
    return figure


def render_band_config(config: dict[str, Any], entry_script: str | Path, validate_only: bool = False) -> list[Path]:
    mode = str(config.get("mode", "single"))
    if mode not in {"single", "compare"}:
        raise VisualizationError("band mode must be single or compare")
    comparison_audit = str(config.get("comparison_audit", "equal_bandwise"))
    if comparison_audit not in {"equal_bandwise", "display_only", "full_display_sets"}:
        raise VisualizationError(
            "band comparison_audit must be equal_bandwise, display_only, or full_display_sets"
        )
    reference_spec = config["reference"]
    model_specs = config.get("models", [])
    reference = load_dataset(config["reference"])
    models = [load_dataset(spec) for spec in model_specs]
    if not config.get("diagnostic_banner") and any(
        token in dataset.qualification_label.upper()
        for dataset in [reference] + models
        for token in ("HOLD", "DIAGNOSTIC", "NOT_PRODUCTION")
    ):
        config["diagnostic_banner"] = "DIAGNOSTIC ONLY"
    if mode == "single" and models:
        raise VisualizationError("band single mode does not accept models")
    if mode == "compare" and not models:
        raise VisualizationError("band compare mode requires at least one model")
    for model in models:
        validate_shared_path(reference, model)
    assessments = load_error_assessments(config, reference, models)
    display_audit = None
    if comparison_audit == "full_display_sets":
        display_audit = resolve_full_display_sets(
            config, reference, models, reference_spec, model_specs, assessments
        )
    if assessments and comparison_audit != "full_display_sets":
        raise VisualizationError(
            "precomputed match-map error assessment requires comparison_audit=full_display_sets"
        )
    error_suffix = ""
    if assessments:
        error_suffix = str(config["error_assessment"].get("output_suffix", "_errors"))
        if not error_suffix.startswith("_") or any(
            character in error_suffix for character in ("/", "\\")
        ):
            raise VisualizationError(
                "error_assessment.output_suffix must start with '_' and contain no path separator"
            )
    assessment_by_model = {assessment.model_id: assessment for assessment in assessments}
    comparisons: list[dict[str, Any]] = []
    for model in models:
        reference_energies = displayed_energies(reference)
        model_energies = displayed_energies(model)
        if comparison_audit == "equal_bandwise" and reference_energies.shape != model_energies.shape:
            raise VisualizationError(
                "generic band comparison requires equal displayed band counts; select explicit "
                "energy columns before plotting instead of silently matching or dropping bands"
            )
        if comparison_audit == "equal_bandwise":
            difference = model_energies - reference_energies
            comparisons.append(
                {
                    "reference_id": reference.dataset_id,
                    "model_id": model.dataset_id,
                    "audit_mode": "equal_bandwise",
                    "max_abs_ev": float(np.max(np.abs(difference))),
                    "relative_l2": relative_l2(model_energies, reference_energies),
                    "interpolation": "none",
                    "energy_shift": "none",
                }
            )
        elif comparison_audit == "display_only":
            comparisons.append(
                {
                    "reference_id": reference.dataset_id,
                    "model_id": model.dataset_id,
                    "audit_mode": "display_only",
                    "reference_band_count": int(reference_energies.shape[1]),
                    "model_band_count": int(model_energies.shape[1]),
                    "numerical_difference": "not_computed",
                    "interpolation": "none",
                    "energy_shift": "none",
                }
            )
        else:
            comparison = {
                **dict(display_audit or {}),
                "reference_id": reference.dataset_id,
                "model_id": model.dataset_id,
                "model_loaded_band_count": int(model_energies.shape[1]),
            }
            if model.dataset_id in assessment_by_model:
                comparison["precomputed_match_map_metrics"] = assessment_by_model[
                    model.dataset_id
                ].metrics
            comparisons.append(comparison)
    style = resolve_style(config.get("style"))
    if validate_only:
        return []
    apply_style(style)
    figure = _band_figure([reference] + models, config, style)
    output = config.get("output", {})
    stem = Path(output["stem"]).resolve()
    formats = output.get("formats", ["pdf", "png"])
    try:
        outputs = save_figure_atomic(figure, stem, int(style["dpi"]), formats)
    finally:
        plt.close(figure)
    input_records = [record for dataset in [reference] + models for record in dataset.inputs]
    input_records.extend(assessment.match_map_input for assessment in assessments)
    if config.get("_config_source"):
        input_records.append(audited_file(config["_config_source"], "visualization_config"))
    sidecar = seal_plot_sidecar(
        stem,
        plot_kind="band_structure",
        script_path=entry_script,
        inputs=input_records,
        outputs=outputs,
        resolved_config={**config, "style": style},
        datasets=[dataset.audit_record() for dataset in [reference] + models],
        transforms=[{"name": "common_energy_reference", "value_ev": reference.energy_reference_ev}],
        comparisons=comparisons,
        notes=[
            "No interpolation, fitted offset, or dataset-specific energy shift was applied.",
            (
                "Display-only overlay: unequal reference/model band counts are shown without "
                "a columnwise numerical comparison; formal metrics remain external evidence."
                if comparison_audit == "display_only"
                else (
                    "Complete DFT and TB display sets were loaded; the resolved window contains "
                    "every model band and the requested unfitted DFT context."
                    if comparison_audit == "full_display_sets"
                    else "Equal-bandwise numerical comparison was computed."
                )
            ),
        ],
    )
    published = outputs + [sidecar]
    if assessments:
        error_config = config["error_assessment"]
        error_stem = Path(str(stem) + error_suffix)
        error_figure = _band_error_figure(reference, models, assessments, config, style)
        try:
            error_outputs = save_figure_atomic(
                error_figure, error_stem, int(style["dpi"]), formats
            )
        finally:
            plt.close(error_figure)
        error_sidecar = seal_plot_sidecar(
            error_stem,
            plot_kind="band_error_assessment",
            script_path=entry_script,
            inputs=input_records,
            outputs=error_outputs,
            resolved_config={**config, "style": style},
            datasets=[dataset.audit_record() for dataset in [reference] + models],
            transforms=[
                {"name": "common_energy_reference", "value_ev": reference.energy_reference_ev},
                {"name": "precomputed_match_map_revalidation", "interpolation": "none"},
            ],
            comparisons=[
                {
                    "reference_id": reference.dataset_id,
                    "model_id": assessment.model_id,
                    "audit_mode": "precomputed_match_map",
                    **assessment.metrics,
                }
                for assessment in assessments
            ],
            notes=[
                "Matching was not recomputed or optimized by the renderer.",
                "Every map entry was revalidated against the current complete DFT/TB inputs.",
                "Per-k RMS and maximum absolute errors were recomputed from those validated pairs.",
            ],
        )
        published.extend(error_outputs + [error_sidecar])
    return published


def _response_roman(value: str) -> str:
    """Escape untrusted response metadata for a LaTeX roman-text fragment."""
    escaped: list[str] = []
    for character in str(value):
        if character.isalnum() or character in ".,+-/":
            escaped.append(character)
        elif character == " ":
            escaped.append(r"\ ")
        elif character in "_%&#{}":
            escaped.append("\\" + character)
        elif character == "−":
            escaped.append("-")
        else:
            escaped.append(r"\,")
    return "".join(escaped)


def _response_component_title(component: str) -> str:
    return rf"$\sigma^{{\mathrm{{{_response_roman(component)}}}}}$"


def _response_ylabel(part: str, component: str, unit: str, scale: float) -> str:
    tensor = rf"\sigma^{{\mathrm{{{_response_roman(component)}}}}}"
    if part == "real":
        expression = rf"\mathrm{{Re}}\,{tensor}"
    elif part == "imag":
        expression = rf"\mathrm{{Im}}\,{tensor}"
    elif part == "abs":
        expression = rf"\left|{tensor}\right|"
    else:
        expression = rf"\arg\,{tensor}"
    scale_prefix = "" if scale == 1.0 else rf"{scale:.8g}\times "
    resolved_unit = "rad" if part == "phase" else _response_roman(unit)
    return rf"${scale_prefix}{expression}\ \mathrm{{({resolved_unit})}}$"


def _response_shared_ylabel(part: str, unit: str, scale: float) -> str:
    """Build one page-level response label when panel titles own component identity."""
    if part == "real":
        expression = r"\mathrm{Re}\,\sigma"
    elif part == "imag":
        expression = r"\mathrm{Im}\,\sigma"
    elif part == "abs":
        expression = r"\left|\sigma\right|"
    else:
        expression = r"\arg\,\sigma"
    scale_prefix = "" if scale == 1.0 else rf"{scale:.8g}\times "
    resolved_unit = "rad" if part == "phase" else _response_roman(unit)
    return rf"${scale_prefix}{expression}\ \mathrm{{({resolved_unit})}}$"


def _response_x_window(
    config: dict[str, Any], datasets: list[Any]
) -> tuple[list[float], str, float, float]:
    data_minimum = min(float(np.min(dataset.omega_ev)) for dataset in datasets)
    data_maximum = max(float(np.max(dataset.omega_ev)) for dataset in datasets)
    if not np.isfinite(data_minimum) or not np.isfinite(data_maximum):
        raise VisualizationError("response Omega bounds must be finite")
    requested = config.get("x_window")
    if requested is None:
        if not data_minimum < data_maximum:
            raise VisualizationError(
                "response Omega data must span a strictly increasing range when x_window is omitted"
            )
        return [data_minimum, data_maximum], "data_bounds", data_minimum, data_maximum
    if (
        not isinstance(requested, list)
        or len(requested) != 2
        or any(
            isinstance(value, bool)
            or not isinstance(value, (int, float))
            or not np.isfinite(float(value))
            for value in requested
        )
    ):
        raise VisualizationError("response x_window must contain two finite numbers")
    lower, upper = [float(value) for value in requested]
    if not lower < upper:
        raise VisualizationError("response x_window must satisfy xmin < xmax")
    return [lower, upper], "explicit", data_minimum, data_maximum


_RESPONSE_LEGEND_LOCATIONS = {
    "best",
    "upper right",
    "upper left",
    "lower left",
    "lower right",
    "right",
    "center left",
    "center right",
    "lower center",
    "upper center",
    "center",
}


def _response_legend_contract(
    config: dict[str, Any], style: dict[str, Any]
) -> dict[str, Any]:
    legend_style = style["legend"]
    configured_location = config.get("legend_location")
    requested_location = str(configured_location or legend_style["location"]).strip()
    if requested_location not in _RESPONSE_LEGEND_LOCATIONS:
        raise VisualizationError(f"unsupported response legend location: {requested_location}")
    bbox = config.get("legend_bbox_to_anchor")
    bbox_source = "response_config"
    if bbox is None:
        bbox = legend_style.get("bbox_to_anchor")
        bbox_source = "style.legend" if bbox is not None else "none"
    if bbox is not None:
        if (
            not isinstance(bbox, list)
            or len(bbox) not in {2, 4}
            or any(
                isinstance(value, bool)
                or not isinstance(value, (int, float))
                or not np.isfinite(float(value))
                for value in bbox
            )
        ):
            raise VisualizationError(
                "response legend_bbox_to_anchor must be null or contain two/four finite numbers"
            )
        bbox = [float(value) for value in bbox]
    columns = config.get("legend_columns")
    if columns is None:
        columns = legend_style["columns"]
    if isinstance(columns, bool) or not isinstance(columns, int) or columns <= 0:
        raise VisualizationError("response legend_columns must be a positive integer")
    frame = config.get("legend_frame")
    if frame is None:
        frame = legend_style["frame"]
    if not isinstance(frame, bool):
        raise VisualizationError("response legend_frame must be boolean")
    return {
        "requested_location": requested_location,
        "location": requested_location,
        "location_source": (
            "response_config" if configured_location else "style.legend"
        ),
        "bbox_to_anchor": bbox,
        "bbox_source": bbox_source,
        "placement_scope": "axes_internal" if bbox is None else "figure_anchored",
        "columns": columns,
        "frame": frame,
        "framealpha": float(legend_style["framealpha"]),
        "facecolor": legend_style["facecolor"],
        "edgecolor": legend_style["edgecolor"],
    }


def _response_page_style(
    style: dict[str, Any], legend: dict[str, Any], has_legend: bool, has_title: bool
) -> tuple[dict[str, Any], dict[str, Any]]:
    page_style = copy.deepcopy(style)
    layout = dict(legend)
    margins = page_style["margins"]
    if not has_legend:
        return page_style, layout
    if layout["placement_scope"] == "axes_internal":
        return page_style, layout
    location = str(layout["location"])
    bbox = layout["bbox_to_anchor"]
    if location.startswith("upper") or (bbox is not None and float(bbox[1]) >= 0.90):
        margins["top"] = min(float(margins["top"]), 0.80 if has_title else 0.86)
    elif location.startswith("lower") or (bbox is not None and float(bbox[1]) <= 0.10):
        margins["bottom"] = max(float(margins["bottom"]), 0.18)
    elif location in {"right", "center right"}:
        margins["right"] = min(float(margins["right"]), 0.84)
    elif location == "center left":
        margins["left"] = max(float(margins["left"]), 0.22)
    return page_style, layout


def _display_bbox(bounds: Any) -> list[float]:
    return [float(bounds.x0), float(bounds.y0), float(bounds.x1), float(bounds.y1)]


def _bbox_contains(outer: Any, inner: Any, tolerance_pixels: float = 0.5) -> bool:
    return bool(
        inner.x0 >= outer.x0 - tolerance_pixels
        and inner.y0 >= outer.y0 - tolerance_pixels
        and inner.x1 <= outer.x1 + tolerance_pixels
        and inner.y1 <= outer.y1 + tolerance_pixels
    )


def _bbox_location_class(outer: Any, inner: Any) -> str:
    relative_x = (0.5 * (inner.x0 + inner.x1) - outer.x0) / outer.width
    relative_y = (0.5 * (inner.y0 + inner.y1) - outer.y0) / outer.height
    horizontal = (
        "left"
        if relative_x < 1.0 / 3.0
        else "right"
        if relative_x > 2.0 / 3.0
        else "center"
    )
    vertical = (
        "lower"
        if relative_y < 1.0 / 3.0
        else "upper"
        if relative_y > 2.0 / 3.0
        else "center"
    )
    return "center" if horizontal == vertical == "center" else f"{vertical} {horizontal}"


def _line_vertex_overlap(lines: list[Any], bounds: Any) -> tuple[int, int]:
    total = 0
    inside = 0
    for line in lines:
        vertices = line.get_transform().transform(line.get_path().vertices)
        finite = np.all(np.isfinite(vertices), axis=1)
        vertices = vertices[finite]
        total += int(vertices.shape[0])
        inside += int(
            np.count_nonzero(
                (vertices[:, 0] >= bounds.x0)
                & (vertices[:, 0] <= bounds.x1)
                & (vertices[:, 1] >= bounds.y0)
                & (vertices[:, 1] <= bounds.y1)
            )
        )
    return total, inside


def _display_union(axes: list[Any], renderer: Any) -> list[float]:
    bounds = [axis.get_window_extent(renderer) for axis in axes]
    return [
        min(bound.x0 for bound in bounds),
        min(bound.y0 for bound in bounds),
        max(bound.x1 for bound in bounds),
        max(bound.y1 for bound in bounds),
    ]


def _response_page_capacity(config: dict[str, Any], style: dict[str, Any], component_count: int) -> tuple[int, list[float], int]:
    panel_size = config.get("panel_size_inches", [2.4, 1.8])
    if (
        not isinstance(panel_size, list) or len(panel_size) != 2
        or any(not isinstance(value, (int, float)) or not np.isfinite(value) or value <= 0.0 for value in panel_size)
    ):
        raise VisualizationError("response panel_size_inches must contain two finite positive values")
    maximum_pixels = int(config.get("maximum_page_pixels", 32000000))
    if maximum_pixels <= 0:
        raise VisualizationError("response maximum_page_pixels must be positive")
    requested = int(config.get("panels_per_page", 27))
    columns = int(config.get("panel_columns", 3))
    if requested <= 0 or columns <= 0:
        raise VisualizationError("response panel counts must be positive")
    dpi = int(style["dpi"])
    for capacity in range(min(requested, component_count), 0, -1):
        page_columns = min(columns, capacity)
        rows = int(math.ceil(capacity / page_columns))
        size = [float(panel_size[0]) * page_columns, float(panel_size[1]) * rows]
        pixels = int(math.ceil(size[0] * dpi) * math.ceil(size[1] * dpi))
        if pixels <= maximum_pixels:
            return capacity, size, pixels
    raise VisualizationError("response maximum_page_pixels is smaller than one panel at the selected DPI")


def render_response_config(config: dict[str, Any], entry_script: str | Path, validate_only: bool = False) -> list[Path]:
    mode = str(config.get("mode", "single"))
    if mode not in {"single", "compare"}:
        raise VisualizationError("response mode must be single or compare")
    datasets = [load_response(config["input"], str(config.get("label", "Data")))]
    if mode == "compare":
        if not config.get("compare"):
            raise VisualizationError("response compare mode requires compare input")
        datasets.append(load_response(config["compare"], str(config.get("compare_label", "Comparison"))))
        validate_response_comparison(datasets[0], datasets[1])
    elif config.get("compare"):
        raise VisualizationError("response single mode does not accept compare input")
    requested = str(config.get("components", "all"))
    if requested == "all":
        component_indices = list(range(len(datasets[0].components)))
    else:
        labels = [label.strip() for label in requested.split(",") if label.strip()]
        missing = [label for label in labels if label not in datasets[0].components]
        if missing:
            raise VisualizationError(f"response components are absent: {', '.join(missing)}")
        component_indices = [datasets[0].components.index(label) for label in labels]
    if not component_indices:
        raise VisualizationError("response component selection is empty")
    part = str(config.get("part", "real"))
    scale = float(config.get("scale", 1.0))
    if not np.isfinite(scale):
        raise VisualizationError("response scale must be finite")
    values = [select_part(dataset.values, part) * scale for dataset in datasets]
    style = resolve_style(config.get("style"))
    x_window, x_window_source, omega_minimum, omega_maximum = _response_x_window(
        config, datasets
    )
    explicit_xlabel = config.get("xlabel")
    explicit_ylabel = config.get("ylabel")
    if not isinstance(explicit_xlabel, str) or not isinstance(explicit_ylabel, str):
        raise VisualizationError("response xlabel and ylabel must be strings")
    xlabel = explicit_xlabel or r"$\hbar\omega\ \mathrm{(eV)}$"
    xlabel_source = "manual" if explicit_xlabel else "automatic"
    unit = config.get("unit", "output units")
    if not isinstance(unit, str) or not unit.strip():
        raise VisualizationError("response unit must be a nonempty string")
    ylabel_source = "manual" if explicit_ylabel else "automatic"
    shared_ylabel = explicit_ylabel or _response_shared_ylabel(part, unit, scale)
    ylabel_layout = "page_shared" if len(component_indices) > 1 else "per_panel"
    panel_labels = [
        {
            "component": datasets[0].components[index],
            "title": _response_component_title(datasets[0].components[index]),
            "ylabel": explicit_ylabel
            or _response_ylabel(part, datasets[0].components[index], unit, scale),
        }
        for index in component_indices
    ]
    panel_label_by_component = {item["component"]: item for item in panel_labels}
    legend_contract = _response_legend_contract(config, style)
    columns = int(config.get("panel_columns", 3))
    panels_per_page, _, planned_max_pixels = _response_page_capacity(config, style, len(component_indices))
    comparisons: list[dict[str, Any]] = []
    if len(datasets) == 2:
        for index in component_indices:
            comparisons.append(
                {
                    "component": datasets[0].components[index],
                    "max_abs": float(np.max(np.abs(values[1][:, index] - values[0][:, index]))),
                    "relative_l2": relative_l2(values[1][:, index], values[0][:, index]),
                    "interpolation": "none",
                }
            )
    config["effective_x_window"] = x_window
    config["x_window_source"] = x_window_source
    config["effective_xlabel"] = xlabel
    config["xlabel_source"] = xlabel_source
    config["ylabel_source"] = ylabel_source
    config["ylabel_layout"] = ylabel_layout
    config["effective_shared_ylabel"] = shared_ylabel
    config["effective_panel_labels"] = panel_labels
    if validate_only:
        return []
    apply_style(style)
    output = config.get("output", {})
    base_stem = Path(output["stem"]).resolve()
    formats = output.get("formats", ["pdf", "png"])
    outputs: list[Path] = []
    pages = [component_indices[index : index + panels_per_page] for index in range(0, len(component_indices), panels_per_page)]
    effective_curves: dict[str, dict[str, Any]] = {}
    legend_placements: list[dict[str, Any]] = []
    xlabel_placements: list[dict[str, Any]] = []
    for page_number, page_indices in enumerate(pages, start=1):
        page_columns = min(columns, len(page_indices))
        rows = int(math.ceil(len(page_indices) / page_columns))
        panel_size = config.get("panel_size_inches", [2.4, 1.8])
        page_style, page_legend = _response_page_style(
            style, legend_contract, len(datasets) > 1, bool(config.get("title"))
        )
        page_style["figsize"] = [float(panel_size[0]) * page_columns, float(panel_size[1]) * rows]
        page_legend["applied_margins"] = dict(page_style["margins"])
        figure, axes = plt.subplots(
            rows,
            page_columns,
            figsize=tuple(page_style["figsize"]),
            squeeze=False,
            sharey=bool(config.get("share_y", False)),
        )
        for panel, component_index in zip(axes.flat, page_indices):
            for dataset_index, dataset in enumerate(datasets):
                curve = dict(RESPONSE_CURVES[dataset_index])
                curve.update((config.get("curves") or {}).get(dataset.label, {}))
                effective_curves[dataset.label] = curve
                panel.plot(
                    dataset.omega_ev,
                    values[dataset_index][:, component_index],
                    label=dataset.label,
                    color=curve["color"],
                    linestyle=curve["linestyle"],
                    linewidth=curve["linewidth"],
                    marker=curve.get("marker") or None,
                    markerfacecolor=curve.get("markerfacecolor", "none"),
                    markeredgecolor=curve.get("markeredgecolor") or curve["color"],
                    markersize=float(curve.get("markersize", 4.0)),
                    markevery=int(curve.get("markevery", 1)),
                    zorder=float(curve.get("zorder", 2 + dataset_index)),
                )
            panel.axhline(0.0, color="#777777", linewidth=0.7, linestyle="--")
            component = datasets[0].components[component_index]
            label_contract = panel_label_by_component[component]
            panel.set_title(label_contract["title"])
            if ylabel_layout == "per_panel":
                panel.set_ylabel(label_contract["ylabel"])
            panel.set_xlim(float(x_window[0]), float(x_window[1]))
            style_axes(panel, style)
            _banner(panel, config.get("diagnostic_banner"))
        for panel in list(axes.flat)[len(page_indices) :]:
            panel.set_visible(False)
        if ylabel_layout == "page_shared":
            figure.supylabel(shared_ylabel)
        legend_artist = None
        legend_axis = axes.flat[0]
        if len(datasets) > 1:
            handles, labels = legend_axis.get_legend_handles_labels()
            legend_arguments = {
                "loc": page_legend["location"],
                "ncols": int(page_legend["columns"]),
                "frameon": bool(page_legend["frame"]),
                "framealpha": float(page_legend["framealpha"]),
                "facecolor": page_legend["facecolor"],
                "edgecolor": page_legend["edgecolor"],
            }
            if page_legend["bbox_to_anchor"] is not None:
                legend_arguments["bbox_to_anchor"] = tuple(page_legend["bbox_to_anchor"])
                legend_arguments["bbox_transform"] = figure.transFigure
            legend_artist = legend_axis.legend(handles, labels, **legend_arguments)
        if config.get("title"):
            figure.suptitle(tex_text(str(config["title"])), y=0.995)
        apply_margins(figure, page_style)
        visible_axes = [panel for panel in axes.flat if panel.get_visible()]
        if len(visible_axes) == 1:
            xlabel_artist = visible_axes[0].set_xlabel(
                xlabel, fontsize=float(style["axis_font_size"])
            )
            xlabel_scope = "axes_panel"
            xlabel_target: str | list[str] = datasets[0].components[page_indices[0]]
            xlabel_position_source = "axes.set_xlabel"
            xlabel_y_figure = None
        else:
            axes_left = min(panel.get_position().x0 for panel in visible_axes)
            axes_right = max(panel.get_position().x1 for panel in visible_axes)
            xlabel_y_figure = max(
                0.01, min(float(page_style["margins"]["bottom"]) * 0.32, 0.12)
            )
            xlabel_artist = figure.supxlabel(
                xlabel,
                x=0.5 * (axes_left + axes_right),
                y=xlabel_y_figure,
                fontsize=float(style["axis_font_size"]),
            )
            xlabel_scope = "figure_shared"
            xlabel_target = [datasets[0].components[index] for index in page_indices]
            xlabel_position_source = "figure.supxlabel_visible_axes_union"
        figure.canvas.draw()
        renderer = figure.canvas.get_renderer()
        xlabel_bbox = xlabel_artist.get_window_extent(renderer)
        xlabel_bottom_adjustment = 0.0
        minimum_canvas_padding = 2.0
        if xlabel_bbox.y0 < minimum_canvas_padding:
            required_fraction = (
                minimum_canvas_padding - xlabel_bbox.y0
            ) / figure.bbox.height
            if xlabel_scope == "axes_panel":
                previous_bottom = float(page_style["margins"]["bottom"])
                adjusted_bottom = previous_bottom + required_fraction
                if adjusted_bottom >= float(page_style["margins"]["top"]) - 0.05:
                    raise VisualizationError(
                        "response panel is too short to contain the configured x label"
                    )
                page_style["margins"]["bottom"] = adjusted_bottom
                xlabel_bottom_adjustment = adjusted_bottom - previous_bottom
                apply_margins(figure, page_style)
            else:
                xlabel_y_figure = float(xlabel_y_figure) + required_fraction
                xlabel_artist.set_y(xlabel_y_figure)
                xlabel_bottom_adjustment = required_fraction
            figure.canvas.draw()
            renderer = figure.canvas.get_renderer()
            xlabel_bbox = xlabel_artist.get_window_extent(renderer)
        page_legend["applied_margins"] = dict(page_style["margins"])
        if legend_artist is not None:
            legend_bbox = legend_artist.get_window_extent(renderer)
            axes_bbox = legend_axis.get_window_extent(renderer)
            data_vertex_count, covered_data_vertices = _line_vertex_overlap(
                handles, legend_bbox
            )
            target_component = datasets[0].components[page_indices[0]]
            legend_placements.append(
                {
                    **page_legend,
                    "page": page_number,
                    "target_panel": target_component,
                    "target_panel_index_on_page": 1,
                    "inside_axes": _bbox_contains(axes_bbox, legend_bbox),
                    "legend_bbox_pixels": _display_bbox(legend_bbox),
                    "target_axes_bbox_pixels": _display_bbox(axes_bbox),
                    "resolved_location_class": _bbox_location_class(
                        axes_bbox, legend_bbox
                    ),
                    "curve_vertex_count": data_vertex_count,
                    "curve_vertices_inside_legend": covered_data_vertices,
                    "curve_vertex_overlap_fraction": (
                        covered_data_vertices / data_vertex_count
                        if data_vertex_count
                        else 0.0
                    ),
                    "legend_artist_count": (
                        len(figure.legends)
                        + sum(
                            panel.get_legend() is not None
                            for panel in axes.flat
                            if panel.get_visible()
                        )
                    ),
                }
            )
        axes_union = _display_union(visible_axes, renderer)
        axes_union_center = 0.5 * (axes_union[0] + axes_union[2])
        xlabel_placements.append(
            {
                "page": page_number,
                "placement_scope": xlabel_scope,
                "target_panel": xlabel_target,
                "position_source": xlabel_position_source,
                "font_size_source": "style.axis_font_size",
                "requested_font_size_points": float(style["axis_font_size"]),
                "rendered_font_size_points": float(xlabel_artist.get_fontsize()),
                "labelpad_points": (
                    float(visible_axes[0].xaxis.labelpad)
                    if xlabel_scope == "axes_panel"
                    else None
                ),
                "shared_y_figure_fraction": xlabel_y_figure,
                "bottom_layout_adjustment_figure_fraction": xlabel_bottom_adjustment,
                "minimum_canvas_padding_pixels": minimum_canvas_padding,
                "xlabel_bbox_canvas_pixels": _display_bbox(xlabel_bbox),
                "target_axes_union_bbox_canvas_pixels": axes_union,
                "horizontal_center_difference_canvas_pixels": abs(
                    0.5 * (xlabel_bbox.x0 + xlabel_bbox.x1) - axes_union_center
                ),
                "vertical_gap_canvas_pixels": axes_union[1] - xlabel_bbox.y1,
                "inside_figure": _bbox_contains(figure.bbox, xlabel_bbox),
            }
        )
        page_stem = base_stem if len(pages) == 1 else base_stem.with_name(f"{base_stem.name}_page{page_number:02d}")
        try:
            outputs.extend(save_figure_atomic(figure, page_stem, int(style["dpi"]), formats))
        finally:
            plt.close(figure)
    config["effective_curves"] = effective_curves
    config["effective_xlabel_layout"] = {
        "text": xlabel,
        "text_source": xlabel_source,
        "font_size_source": "style.axis_font_size",
        "placements": xlabel_placements,
    }
    if legend_placements:
        config["effective_legend"] = {
            **legend_contract,
            "placement_scope": legend_contract["placement_scope"],
            "target_panel": (
                legend_placements[0]["target_panel"]
                if len(legend_placements) == 1
                else [placement["target_panel"] for placement in legend_placements]
            ),
            "inside_axes": all(
                bool(placement["inside_axes"]) for placement in legend_placements
            ),
            "applied_margins": legend_placements[0]["applied_margins"],
            "placements": legend_placements,
        }
    input_records = [dataset.input_record for dataset in datasets]
    if config.get("_config_source"):
        input_records.append(audited_file(config["_config_source"], "visualization_config"))
    sidecar = seal_plot_sidecar(
        base_stem,
        plot_kind="response_integral",
        script_path=entry_script,
        inputs=input_records,
        outputs=outputs,
        resolved_config={**config, "style": style},
        datasets=[dataset.audit_record() for dataset in datasets],
        transforms=[
            {"name": "complex_part", "value": part},
            {"name": "scale", "value": scale, "unit": str(config.get("unit", "output units"))},
            {"name": "automatic_pagination", "panels_per_page": panels_per_page,
             "requested_panels_per_page": int(config.get("panels_per_page", 27)),
             "maximum_page_pixels": int(config.get("maximum_page_pixels", 32000000)),
             "planned_page_pixel_upper_bound": planned_max_pixels,
             "panel_size_inches": config.get("panel_size_inches", [2.4, 1.8])},
            {"name": "response_axis_contract",
             "omega_ev_minimum": omega_minimum,
             "omega_ev_maximum": omega_maximum,
             "final_x_window_ev": x_window,
             "axis_method": "set_xlim",
             "x_window_source": x_window_source,
             "xlabel_source": xlabel_source,
             "xlabel": xlabel,
             "xlabel_layout": config["effective_xlabel_layout"],
             "ylabel_source": ylabel_source,
             "ylabel_layout": ylabel_layout,
             "shared_ylabel": shared_ylabel,
             "panel_labels": panel_labels},
            {"name": "response_legend_layout",
             **(config.get("effective_legend") or {**legend_contract, "placements": []}),
             "minor_ticks": bool(style["minor_ticks"])},
        ],
        comparisons=comparisons,
        notes=["Omega interpolation is not implemented; comparison requires an exactly identical grid."],
    )
    return outputs + [sidecar]


def _resolve_norm(values: np.ndarray, requested: str, part: str, quantity: str, config: dict[str, Any]) -> tuple[Any, str, float | None, float | None]:
    kind = requested
    if kind == "auto":
        signed_quantities = {
            "berry_curvature",
            "berry_curvature_dipole",
            "berry_curvature_quadrupole",
            "shift_vector",
            "shift_current",
            "injection_current",
        }
        kind = (
            "phase"
            if part == "phase"
            else "positive-log"
            if part == "abs" and np.all(values > 0.0) and float(np.max(values)) / max(float(np.min(values)), np.finfo(float).tiny) >= 100.0
            else "diverging"
            if quantity in signed_quantities or np.min(values) < 0.0 < np.max(values)
            else "linear"
        )
    vmin = config.get("vmin")
    vmax = config.get("vmax")
    percentile = config.get("percentile")
    if percentile is not None:
        percentile = float(percentile)
        if not 50.0 < percentile <= 100.0:
            raise VisualizationError("K-slice percentile must be in (50,100]")
        if vmin is not None or vmax is not None:
            raise VisualizationError("K-slice percentile cannot be combined with vmin/vmax")
    if kind == "phase":
        return Normalize(-math.pi, math.pi), kind, -math.pi, math.pi
    if kind == "diverging":
        limit = max(abs(float(np.min(values))), abs(float(np.max(values))))
        if percentile is not None:
            limit = float(np.percentile(np.abs(values), percentile))
        if vmin is not None or vmax is not None:
            if vmin is None or vmax is None:
                raise VisualizationError("diverging norm requires both vmin and vmax")
            if not np.isclose(abs(float(vmin)), abs(float(vmax))):
                raise VisualizationError("diverging vmin/vmax must be symmetric about zero")
            limit = abs(float(vmax))
        if not limit > 0.0:
            limit = 1.0
        return TwoSlopeNorm(vmin=-limit, vcenter=0.0, vmax=limit), kind, -limit, limit
    if kind == "positive-log":
        positive = values[values > 0.0]
        if positive.size == 0:
            raise VisualizationError("positive-log norm requires positive values")
        lower = float(vmin) if vmin is not None else float(np.min(positive))
        upper = float(vmax) if vmax is not None else float(np.max(positive))
        if not (0.0 < lower < upper):
            raise VisualizationError("positive-log limits must satisfy 0 < vmin < vmax")
        return LogNorm(lower, upper), kind, lower, upper
    if kind == "signed-log":
        limit = max(abs(float(np.min(values))), abs(float(np.max(values))))
        lower = -limit if vmin is None else float(vmin)
        upper = limit if vmax is None else float(vmax)
        linthresh = float(config.get("linthresh", 0.0))
        if linthresh <= 0.0 or not lower < 0.0 < upper:
            raise VisualizationError("signed-log requires positive linthresh and signed limits")
        return SymLogNorm(linthresh=linthresh, vmin=lower, vmax=upper), kind, lower, upper
    if kind == "linear":
        lower = float(vmin) if vmin is not None else float(np.min(values))
        upper = float(vmax) if vmax is not None else float(np.max(values))
        if percentile is not None:
            lower, upper = [float(value) for value in np.percentile(values, [100.0 - percentile, percentile])]
        if not lower < upper:
            lower, upper = lower - 0.5, upper + 0.5
        return Normalize(lower, upper), kind, lower, upper
    raise VisualizationError("K-slice norm must be linear, diverging, positive-log, signed-log, phase, or auto")


def render_kslice_config(config: dict[str, Any], entry_script: str | Path, validate_only: bool = False) -> list[Path]:
    mode = str(config.get("mode", "single-map"))
    if mode not in {"single-map", "grid"}:
        raise VisualizationError("K-slice mode must be single-map or grid")
    metadata = load_metadata(config["metadata"])
    panel_fields = {
        "id", "real", "imag", "part", "norm", "vmin", "vmax", "linthresh",
        "percentile", "cmap", "colorbar_label", "title", "math_title", "label", "order",
    }
    panels = config.get("panels") or []
    manifest_path = str(config.get("panel_manifest") or "")
    if panels and manifest_path:
        raise VisualizationError("K-slice panels and panel_manifest are mutually exclusive")
    manifest_record = None
    if manifest_path:
        manifest_payload = load_json(manifest_path)
        if manifest_payload.get("schema") != "wanniernlqg.kslice-panels" or manifest_payload.get("schema_version") != "1.0":
            raise VisualizationError("K-slice panel manifest must use wanniernlqg.kslice-panels schema 1.0")
        if set(manifest_payload) != {"schema", "schema_version", "panels"}:
            raise VisualizationError("K-slice panel manifest contains unknown top-level fields")
        panels = manifest_payload.get("panels")
        if isinstance(panels, list):
            for panel in panels:
                if isinstance(panel, dict):
                    for field in ("real", "imag"):
                        if panel.get(field):
                            value = Path(str(panel[field]))
                            panel[field] = str((Path(manifest_path).parent / value).resolve()) if not value.is_absolute() else str(value.resolve())
        manifest_record = audited_file(manifest_path, "kslice_panel_manifest")
    if not panels:
        data_paths = config.get("data")
        if isinstance(data_paths, str):
            data_paths = [data_paths]
        imag_paths = config.get("imag") or []
        if isinstance(imag_paths, str):
            imag_paths = [imag_paths]
        if not isinstance(data_paths, list) or not data_paths:
            raise VisualizationError("K-slice requires data or an explicit panel manifest")
        if mode == "grid":
            raise VisualizationError("K-slice grid mode requires explicit panels or panel_manifest; metadata output discovery is forbidden")
        if len(data_paths) != 1 or (imag_paths and len(imag_paths) != 1):
            raise VisualizationError("single-map legacy input requires one real and at most one imaginary matrix")
        panels = [{"id": "panel_1", "real": data_paths[0], "imag": imag_paths[0] if imag_paths else "", "order": 1}]
    if not isinstance(panels, list) or not panels:
        raise VisualizationError("K-slice panels must be a nonempty array")
    resolved_panels: list[dict[str, Any]] = []
    ids: set[str] = set()
    orders: set[int] = set()
    for index, source_panel in enumerate(panels):
        if not isinstance(source_panel, dict):
            raise VisualizationError("each K-slice panel must be an object")
        unknown = sorted(set(source_panel) - panel_fields)
        if unknown:
            raise VisualizationError(f"unknown K-slice panel fields: {', '.join(unknown)}")
        panel = dict(source_panel)
        panel_id = str(panel.get("id", "")).strip()
        if not panel_id or panel_id in ids:
            raise VisualizationError("K-slice panel ids must be nonempty and unique")
        ids.add(panel_id)
        order = panel.get("order", index + 1)
        if not isinstance(order, int) or order in orders:
            raise VisualizationError("K-slice panel order values must be unique integers")
        orders.add(order)
        panel["order"] = order
        panel["id"] = panel_id
        if not panel.get("real"):
            raise VisualizationError(f"K-slice panel {panel_id} requires an explicit real dataset")
        resolved_panels.append(panel)
    resolved_panels.sort(key=lambda panel: (int(panel["order"]), str(panel["id"])))
    if mode == "single-map" and len(resolved_panels) != 1:
        raise VisualizationError("single-map mode requires exactly one panel")
    coordinate = str(config.get("coordinate", "fractional"))
    if coordinate not in {"fractional", "centered", "cartesian"}:
        raise VisualizationError("K-slice coordinate supports fractional, centered, or cartesian")
    if coordinate == "centered" and not bool(config.get("periodic_centered", False)):
        raise VisualizationError("centered K-slice coordinates require --periodic-centered")
    matrices: list[np.ndarray] = []
    input_records = [audited_file(metadata.path, "kslice_metadata")]
    if manifest_record:
        input_records.append(manifest_record)
    if config.get("_config_source"):
        input_records.append(audited_file(config["_config_source"], "visualization_config"))
    transforms: list[dict[str, Any]] = []
    effective_panels: list[dict[str, Any]] = []
    for panel in resolved_panels:
        real_values, real_record = load_matrix(panel["real"], metadata, f"kslice_real:{panel['id']}")
        input_records.append(real_record)
        imag_values = None
        if panel.get("imag"):
            imag_values, imag_record = load_matrix(panel["imag"], metadata, f"kslice_imag:{panel['id']}")
            input_records.append(imag_record)
        part = str(panel.get("part", config.get("part", "real")))
        values = combine_parts(real_values, imag_values, part)
        applied: list[str] = []
        if coordinate == "centered":
            values = np.fft.fftshift(values).T
            applied = ["fftshift", "transpose"]
        matrices.append(values)
        effective = {**config, **panel, "part": part}
        effective_panels.append(effective)
        transforms.append({"panel_id": panel["id"], "complex_part": part, "coordinate": coordinate, "operations": applied})
    model_lattice = None
    cartesian_x = cartesian_y = None
    cartesian_record = None
    if coordinate == "cartesian":
        model_lattice = load_model_lattice(metadata, str(config.get("model_file") or "") or None)
        input_records.append(model_lattice.input_record)
        cartesian_x, cartesian_y, cartesian_record = cartesian_projection_grid(
            metadata, model_lattice, str(config.get("projection", "intrinsic-plane")),
            config.get("explicit_projection_axes"),
        )
        cartesian_record.update(
            {
                "model_path": str(model_lattice.model_path),
                "model_sha256": model_lattice.model_sha256,
                "model_input_mode": model_lattice.input_mode,
                "packed_manifest": model_lattice.manifest_record,
            }
        )
    style = resolve_style(config.get("style"))
    norms = [
        _resolve_norm(values, str(panel.get("norm", "auto")), str(panel["part"]), metadata.quantity, panel)
        for values, panel in zip(matrices, effective_panels)
    ]
    if validate_only:
        return []
    apply_style(style)
    requested_columns = int(config.get("panel_columns", 3))
    if requested_columns <= 0:
        raise VisualizationError("K-slice panel_columns must be positive")
    columns = min(requested_columns, len(matrices))
    rows = int(math.ceil(len(matrices) / columns))
    figure, axes = plt.subplots(rows, columns, figsize=(float(style["figsize"][0]) * columns, float(style["figsize"][1]) * rows), squeeze=False)
    colorbar_layout_pairs: list[tuple[Any, Any, int]] = []
    for index, (axis, values, norm_info, panel) in enumerate(zip(axes.flat, matrices, norms, effective_panels)):
        norm, norm_name, lower, upper = norm_info
        cmap = str(panel.get("cmap") or ("twilight" if norm_name == "phase" else "RdBu_r" if norm_name in {"diverging", "signed-log"} else "viridis"))
        if coordinate == "cartesian":
            image = axis.pcolormesh(cartesian_x, cartesian_y, values, cmap=cmap, norm=norm, shading="flat")
            axis.set_aspect("equal", adjustable="box")
        else:
            extent = [-0.5, 0.5, -0.5, 0.5] if coordinate == "centered" else [0.0, 1.0, 0.0, 1.0]
            image = axis.imshow(values, origin="lower", extent=extent, aspect="equal", cmap=cmap, norm=norm, interpolation="nearest")
        if coordinate == "centered":
            axis.set_xlabel(config.get("xlabel") or r"$u$ along $\bm{v}_1$")
            axis.set_ylabel(config.get("ylabel") or r"$v$ along $\bm{v}_2$")
        elif coordinate == "cartesian":
            axis.set_xlabel(config.get("xlabel") or cartesian_record["xlabel"])
            axis.set_ylabel(config.get("ylabel") or cartesian_record["ylabel"])
        else:
            axis.set_xlabel(config.get("xlabel") or r"$v$ along $\bm{v}_2$")
            axis.set_ylabel(config.get("ylabel") or r"$u$ along $\bm{v}_1$")
        if panel.get("math_title"):
            axis.set_title(str(panel["math_title"]))
        else:
            title = str(panel.get("title") or panel.get("label") or f"{panel['part']}: {Path(panel['real']).name}")
            axis.set_title(tex_text(title))
        divider = make_axes_locatable(axis)
        colorbar_axis = divider.append_axes("right", size="5%", pad=0.08)
        colorbar = figure.colorbar(image, cax=colorbar_axis)
        colorbar_layout_pairs.append((axis, colorbar_axis, index))
        colorbar.ax.tick_params(labelsize=float(style["colorbar_tick_font_size"]))
        colorbar_label = str(panel.get("colorbar_label", "output units"))
        if panel["part"] == "phase" and colorbar_label == "output units":
            colorbar_label = r"$\arg\,R\ \mathrm{(rad)}$"
        colorbar.set_label(colorbar_label)
        style_axes(axis, style)
        _banner(axis, config.get("diagnostic_banner"))
        transforms[index].update({"norm": norm_name, "vmin": lower, "vmax": upper, "linthresh": panel.get("linthresh"), "cmap": cmap, "percentile": panel.get("percentile"), "colorbar_label": colorbar_label, "order": panel["order"]})
        if cartesian_record:
            transforms[index]["cartesian_projection"] = cartesian_record
    for axis in list(axes.flat)[len(matrices) :]:
        axis.set_visible(False)
    if config.get("title"):
        figure.suptitle(tex_text(str(config["title"])))
    grid_style = dict(style)
    grid_style["figsize"] = [float(style["figsize"][0]) * columns, float(style["figsize"][1]) * rows]
    apply_margins(figure, grid_style)
    figure.canvas.draw()
    renderer = figure.canvas.get_renderer()
    output_pixel_scale = float(style["dpi"]) / float(figure.dpi)
    for axis, colorbar_axis, index in colorbar_layout_pairs:
        axes_bbox = axis.get_window_extent(renderer)
        colorbar_bbox = colorbar_axis.get_window_extent(renderer)
        transforms[index]["colorbar_layout"] = {
            "placement": "axes_grid1_explicit_cax",
            "axes_bbox_pixels": _display_bbox(axes_bbox),
            "colorbar_bbox_pixels": _display_bbox(colorbar_bbox),
            "y0_difference_output_pixels": abs(colorbar_bbox.y0 - axes_bbox.y0)
            * output_pixel_scale,
            "y1_difference_output_pixels": abs(colorbar_bbox.y1 - axes_bbox.y1)
            * output_pixel_scale,
            "output_dpi": int(style["dpi"]),
        }
    output = config.get("output", {})
    stem = Path(output["stem"]).resolve()
    try:
        outputs = save_figure_atomic(figure, stem, int(style["dpi"]), output.get("formats", ["pdf", "png"]))
    finally:
        plt.close(figure)
    sidecar = seal_plot_sidecar(
        stem,
        plot_kind="kslice",
        script_path=entry_script,
        inputs=input_records,
        outputs=outputs,
        resolved_config={**config, "style": style},
        datasets=[metadata.audit_record()] + [
            {"panel_id": panel["id"], "real": str(Path(panel["real"]).resolve()),
             "imag": str(Path(panel["imag"]).resolve()) if panel.get("imag") else None,
             "array_shape": list(matrix.shape)}
            for panel, matrix in zip(effective_panels, matrices)
        ],
        transforms=transforms,
        comparisons=[],
        notes=[
            "No transform or real/imag pairing is inferred from a filename; panel pairing is explicit.",
            "Cartesian plots use the declared model lattice after SHA-256 validation and pcolormesh cell geometry.",
        ],
    )
    return outputs + [sidecar]
