#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import sys
from typing import Any

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from visualization.backend import (
        render_band_config,
        render_kslice_config,
        render_response_config,
    )
    from visualization.common import VisualizationError, load_json, merge_known
    from visualization.style import STYLE_DEFAULTS
else:
    from .backend import (
        render_band_config,
        render_kslice_config,
        render_response_config,
    )
    from .common import VisualizationError, load_json, merge_known
    from .style import STYLE_DEFAULTS


BAND_DEFAULTS: dict[str, Any] = {
    "mode": "single",
    "comparison_audit": "equal_bandwise",
    "reference": None,
    "models": [],
    "energy_window": None,
    "display_window_policy": {
        "mode": "as_configured",
        "padding_ev": 0.0,
        "unfitted_reference_bands_below": 1,
        "unfitted_reference_bands_above": 1,
        "minimum_unmatched_reference_states_per_k": 0,
        "maximum_unmatched_reference_states_per_k": None,
    },
    "error_assessment": {
        "mode": "none",
        "maps": [],
        "energy_tolerance_ev": 1.0e-10,
        "output_suffix": "_errors",
        "title": "",
        "ylabel": "Matched energy error (eV)",
        "y_window": None,
        "legend_location": "upper right",
        "legend_columns": 2,
    },
    "unfitted_reference_curve": {
        "color": "#C2C2C2",
        "linestyle": "-",
        "linewidth": 0.9,
        "marker": "",
        "markerfacecolor": "none",
        "markeredgecolor": "",
        "markersize": 4.0,
        "markevery": 1,
        "zorder": 1,
    },
    "title": "",
    "xlabel": "",
    "ylabel": "",
    "diagnostic_banner": "",
    "curves": {},
    "style": STYLE_DEFAULTS,
    "output": {"stem": "band_structure", "formats": ["pdf", "png"]},
}

RESPONSE_DEFAULTS: dict[str, Any] = {
    "mode": "single",
    "input": "",
    "compare": "",
    "label": "Data",
    "compare_label": "Comparison",
    "components": "all",
    "part": "real",
    "unit": "output units",
    "scale": 1.0,
    "x_window": None,
    "title": "",
    "xlabel": "",
    "ylabel": "",
    "panel_columns": 3,
    "panels_per_page": 27,
    "panel_size_inches": [2.4, 1.8],
    "maximum_page_pixels": 32000000,
    "share_y": False,
    "legend_location": "",
    "legend_bbox_to_anchor": None,
    "legend_columns": None,
    "legend_frame": None,
    "diagnostic_banner": "",
    "curves": {},
    "style": STYLE_DEFAULTS,
    "output": {"stem": "response_integral", "formats": ["pdf", "png"]},
}


CURVE_DEFAULTS: dict[str, Any] = {
    "color": "#104E8B",
    "linestyle": "-",
    "linewidth": 1.6,
    "marker": "",
    "markerfacecolor": "none",
    "markeredgecolor": "",
    "markersize": 4.0,
    "markevery": 1,
    "zorder": 2,
}


def _validate_curves(value: Any) -> dict[str, dict[str, Any]]:
    if not isinstance(value, dict):
        raise VisualizationError("config.curves must be an object keyed by dataset id or label")
    resolved: dict[str, dict[str, Any]] = {}
    for dataset, override in value.items():
        if not isinstance(dataset, str) or not dataset:
            raise VisualizationError("config.curves keys must be nonempty strings")
        if not isinstance(override, dict):
            raise VisualizationError(f"config.curves.{dataset} must be an object")
        unknown = sorted(set(override) - set(CURVE_DEFAULTS))
        if unknown:
            raise VisualizationError(
                f"unknown config.curves.{dataset} fields: {', '.join(unknown)}"
            )
        curve = dict(override)
        string_fields = ("color", "linestyle", "marker", "markerfacecolor", "markeredgecolor")
        if any(field in curve and not isinstance(curve[field], str) for field in string_fields):
            raise VisualizationError(f"config.curves.{dataset} line and marker styles must be strings")
        if "linewidth" in curve and (not isinstance(curve["linewidth"], (int, float)) or not math.isfinite(float(curve["linewidth"])) or not curve["linewidth"] > 0):
            raise VisualizationError(f"config.curves.{dataset}.linewidth must be positive")
        if "markevery" in curve and (not isinstance(curve["markevery"], int) or curve["markevery"] <= 0):
            raise VisualizationError(f"config.curves.{dataset}.markevery must be a positive integer")
        if "markersize" in curve and (not isinstance(curve["markersize"], (int, float)) or not math.isfinite(float(curve["markersize"])) or curve["markersize"] <= 0):
            raise VisualizationError(f"config.curves.{dataset}.markersize must be finite and positive")
        if "zorder" in curve and (not isinstance(curve["zorder"], (int, float)) or not math.isfinite(float(curve["zorder"]))):
            raise VisualizationError(f"config.curves.{dataset}.zorder must be finite and numeric")
        resolved[dataset] = curve
    return resolved

KSLICE_DEFAULTS: dict[str, Any] = {
    "mode": "single-map",
    "metadata": "",
    "data": [],
    "imag": [],
    "panels": [],
    "panel_manifest": "",
    "part": "real",
    "coordinate": "fractional",
    "model_file": "",
    "projection": "intrinsic-plane",
    "explicit_projection_axes": None,
    "periodic_centered": False,
    "norm": "auto",
    "vmin": None,
    "vmax": None,
    "linthresh": 1.0e-3,
    "percentile": None,
    "cmap": "",
    "colorbar_label": "output units",
    "title": "",
    "xlabel": "",
    "ylabel": "",
    "panel_columns": 3,
    "diagnostic_banner": "",
    "style": STYLE_DEFAULTS,
    "output": {"stem": "kslice", "formats": ["pdf", "png"]},
}


def _config(defaults: dict[str, Any], config_path: str | None) -> tuple[dict[str, Any], Path | None]:
    if not config_path:
        return merge_known(defaults, {}), None
    source = Path(config_path).resolve()
    override = load_json(source)
    curves = override.pop("curves", None)
    config = merge_known(defaults, override)
    if curves is not None:
        config["curves"] = _validate_curves(curves)
    config["_config_source"] = str(source)
    return config, source


def _resolve_config_paths(config: dict[str, Any], source: Path | None, path_fields: list[str]) -> None:
    base = source.parent if source is not None else Path.cwd()
    for field in path_fields:
        value = config.get(field)
        if isinstance(value, str) and value:
            config[field] = str((base / value).resolve()) if not Path(value).is_absolute() else str(Path(value).resolve())
        elif isinstance(value, list):
            config[field] = [str((base / item).resolve()) if not Path(item).is_absolute() else str(Path(item).resolve()) for item in value]
    output = config.get("output")
    if isinstance(output, dict) and output.get("stem"):
        value = Path(str(output["stem"]))
        output["stem"] = str((base / value).resolve()) if not value.is_absolute() else str(value.resolve())


def _dump(payload: dict[str, Any]) -> int:
    json.dump(payload, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


def _formats(value: str) -> list[str]:
    return ["pdf", "png"] if value == "both" else [value]


def _apply_style_assignments(config: dict[str, Any], assignments: list[str] | None) -> None:
    for assignment in assignments or []:
        if "=" not in assignment:
            raise VisualizationError("--style requires FIELD=JSON")
        field, encoded = assignment.split("=", 1)
        path = [item for item in field.split(".") if item]
        if not path:
            raise VisualizationError("--style field cannot be empty")
        default_cursor: Any = STYLE_DEFAULTS
        config_cursor: Any = config["style"]
        for item in path[:-1]:
            if not isinstance(default_cursor, dict) or item not in default_cursor or not isinstance(default_cursor[item], dict):
                raise VisualizationError(f"unknown style field: {field}")
            default_cursor = default_cursor[item]
            config_cursor = config_cursor[item]
        leaf = path[-1]
        if not isinstance(default_cursor, dict) or leaf not in default_cursor:
            raise VisualizationError(f"unknown style field: {field}")
        try:
            config_cursor[leaf] = json.loads(encoded)
        except json.JSONDecodeError as exc:
            raise VisualizationError(f"invalid JSON value for style field {field}") from exc


def _apply_curve_assignments(config: dict[str, Any], assignments: list[str] | None) -> None:
    curves = dict(config.get("curves") or {})
    for assignment in assignments or []:
        if "=" not in assignment or "." not in assignment.split("=", 1)[0]:
            raise VisualizationError("--curve requires DATASET.FIELD=JSON")
        key, encoded = assignment.split("=", 1)
        dataset, field = key.rsplit(".", 1)
        if not dataset or field not in CURVE_DEFAULTS:
            raise VisualizationError(f"unknown curve field: {key}")
        curve = dict(curves.get(dataset, {}))
        try:
            curve[field] = json.loads(encoded)
        except json.JSONDecodeError as exc:
            raise VisualizationError(f"invalid JSON value for curve field {key}") from exc
        curves[dataset] = curve
    config["curves"] = _validate_curves(curves)


def _band_parser(subparsers: Any) -> None:
    parser = subparsers.add_parser(
        "band", help="single, full-display, or audited precomputed-match band comparison"
    )
    parser.add_argument("--config")
    parser.add_argument("--dump-default-config", action="store_true")
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--output")
    parser.add_argument("--title")
    parser.add_argument("--xlabel")
    parser.add_argument("--ylabel")
    parser.add_argument("--energy-window", nargs=2, type=float)
    parser.add_argument("--diagnostic-banner")
    parser.add_argument("--format", choices=("both", "pdf", "png"))
    parser.add_argument("--style", action="append", metavar="FIELD=JSON")
    parser.add_argument("--curve", action="append", metavar="DATASET.FIELD=JSON")
    parser.add_argument("--entry-script", required=True)
    parser.set_defaults(handler=_handle_band)

def _response_parser(subparsers: Any) -> None:
    parser = subparsers.add_parser("response", help="response-integral spectra")
    parser.add_argument("--config")
    parser.add_argument("--dump-default-config", action="store_true")
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--mode", choices=("single", "compare"))
    parser.add_argument("--input")
    parser.add_argument("--compare")
    parser.add_argument("--label")
    parser.add_argument("--compare-label")
    parser.add_argument("--components")
    parser.add_argument("--part", choices=("real", "imag", "abs", "phase"))
    parser.add_argument("--unit")
    parser.add_argument("--scale", type=float)
    parser.add_argument("--x-window", nargs=2, type=float)
    parser.add_argument("--title")
    parser.add_argument("--xlabel")
    parser.add_argument("--ylabel")
    parser.add_argument("--panel-columns", type=int)
    parser.add_argument("--panels-per-page", type=int)
    parser.add_argument("--maximum-page-pixels", type=int)
    y_group = parser.add_mutually_exclusive_group()
    y_group.add_argument("--share-y", dest="share_y", action="store_true", default=None)
    y_group.add_argument("--independent-y", dest="share_y", action="store_false")
    parser.add_argument("--legend-location")
    parser.add_argument("--legend-bbox-to-anchor", nargs="+", type=float)
    parser.add_argument("--legend-columns", type=int)
    legend_frame_group = parser.add_mutually_exclusive_group()
    legend_frame_group.add_argument(
        "--legend-frame", dest="legend_frame", action="store_true", default=None
    )
    legend_frame_group.add_argument(
        "--no-legend-frame", dest="legend_frame", action="store_false"
    )
    parser.add_argument("--diagnostic-banner")
    parser.add_argument("--output")
    parser.add_argument("--format", choices=("both", "pdf", "png"))
    parser.add_argument("--style", action="append", metavar="FIELD=JSON")
    parser.add_argument("--curve", action="append", metavar="DATASET.FIELD=JSON")
    parser.add_argument("--entry-script", required=True)
    parser.set_defaults(handler=_handle_response)


def _kslice_parser(subparsers: Any) -> None:
    parser = subparsers.add_parser("kslice", help="audited K-slice maps")
    parser.add_argument("--config")
    parser.add_argument("--dump-default-config", action="store_true")
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--mode", choices=("single-map", "grid"))
    parser.add_argument("--metadata")
    parser.add_argument("--data", action="append")
    parser.add_argument("--imag", action="append")
    parser.add_argument("--panel-manifest")
    parser.add_argument("--part", choices=("real", "imag", "abs", "phase"))
    parser.add_argument("--coordinate", choices=("fractional", "centered", "cartesian"))
    parser.add_argument("--model-file")
    parser.add_argument("--projection", choices=("intrinsic-plane", "kx-ky", "kx-kz", "ky-kz", "explicit"))
    parser.add_argument("--periodic-centered", action="store_true", default=None)
    parser.add_argument("--norm", choices=("linear", "diverging", "positive-log", "signed-log", "phase", "auto"))
    parser.add_argument("--vmin", type=float)
    parser.add_argument("--vmax", type=float)
    parser.add_argument("--linthresh", type=float)
    parser.add_argument("--percentile", type=float)
    parser.add_argument("--cmap")
    parser.add_argument("--colorbar-label")
    parser.add_argument("--title")
    parser.add_argument("--xlabel")
    parser.add_argument("--ylabel")
    parser.add_argument("--panel-columns", type=int)
    parser.add_argument("--diagnostic-banner")
    parser.add_argument("--output")
    parser.add_argument("--format", choices=("both", "pdf", "png"))
    parser.add_argument("--style", action="append", metavar="FIELD=JSON")
    parser.add_argument("--entry-script", required=True)
    parser.set_defaults(handler=_handle_kslice)


def _handle_band(args: argparse.Namespace) -> int:
    if args.dump_default_config:
        return _dump(BAND_DEFAULTS)
    config, source = _config(BAND_DEFAULTS, args.config)
    if config["reference"] is None:
        raise VisualizationError("band config must define reference")
    if args.output:
        config["output"]["stem"] = args.output
    for field in ("title", "xlabel", "ylabel", "energy_window", "diagnostic_banner"):
        value = getattr(args, field, None)
        if value is not None:
            config[field] = value
    if args.format:
        config["output"]["formats"] = _formats(args.format)
    _apply_style_assignments(config, args.style)
    _apply_curve_assignments(config, args.curve)
    config["unfitted_reference_curve"] = _validate_curves(
        {"unfitted_reference": config["unfitted_reference_curve"]}
    )["unfitted_reference"]
    _resolve_config_paths(config, source, [])
    if not isinstance(config["models"], list):
        raise VisualizationError("band config.models must be a list")
    specs = [config["reference"]] + config["models"]
    if any(not isinstance(spec, dict) for spec in specs):
        raise VisualizationError("band reference and model specifications must be objects")
    for spec in specs:
        for key in ("bands", "path", "data", "eigenval", "kpoints", "poscar"):
            if spec.get(key):
                value = Path(str(spec[key]))
                spec[key] = str(((source.parent if source else Path.cwd()) / value).resolve()) if not value.is_absolute() else str(value.resolve())
    error_assessment = config.get("error_assessment")
    if isinstance(error_assessment, dict):
        maps = error_assessment.get("maps")
        if isinstance(maps, list):
            for map_spec in maps:
                if isinstance(map_spec, dict) and map_spec.get("data"):
                    value = Path(str(map_spec["data"]))
                    map_spec["data"] = str(
                        ((source.parent if source else Path.cwd()) / value).resolve()
                        if not value.is_absolute()
                        else value.resolve()
                    )
    for output in render_band_config(config, args.entry_script, args.validate_only):
        print(output)
    if args.validate_only:
        print("VALIDATION_OK")
    return 0


def _handle_response(args: argparse.Namespace) -> int:
    if args.dump_default_config:
        return _dump(RESPONSE_DEFAULTS)
    config, source = _config(RESPONSE_DEFAULTS, args.config)
    for field in ("mode", "input", "compare", "label", "compare_label", "components", "part", "unit", "scale", "x_window", "title", "xlabel", "ylabel", "panel_columns", "panels_per_page", "maximum_page_pixels", "share_y", "legend_location", "legend_bbox_to_anchor", "legend_columns", "legend_frame", "diagnostic_banner"):
        value = getattr(args, field, None)
        if value is not None:
            config[field] = value
    if args.output:
        config["output"]["stem"] = args.output
    if args.format:
        config["output"]["formats"] = _formats(args.format)
    _apply_style_assignments(config, args.style)
    _apply_curve_assignments(config, args.curve)
    _resolve_config_paths(config, source, ["input", "compare"])
    if not config["input"]:
        raise VisualizationError("response input is required")
    for output in render_response_config(config, args.entry_script, args.validate_only):
        print(output)
    if args.validate_only:
        print("VALIDATION_OK")
    return 0


def _handle_kslice(args: argparse.Namespace) -> int:
    if args.dump_default_config:
        return _dump(KSLICE_DEFAULTS)
    config, source = _config(KSLICE_DEFAULTS, args.config)
    for field in ("mode", "metadata", "panel_manifest", "part", "coordinate", "model_file", "projection", "norm", "vmin", "vmax", "linthresh", "percentile", "cmap", "colorbar_label", "title", "xlabel", "ylabel", "panel_columns", "diagnostic_banner"):
        value = getattr(args, field, None)
        if value is not None:
            config[field] = value
    if args.data is not None:
        config["data"] = args.data
    if args.imag is not None:
        config["imag"] = args.imag
    if args.periodic_centered is not None:
        config["periodic_centered"] = args.periodic_centered
    if args.output:
        config["output"]["stem"] = args.output
    if args.format:
        config["output"]["formats"] = _formats(args.format)
    _apply_style_assignments(config, args.style)
    _resolve_config_paths(config, source, ["metadata", "data", "imag", "panel_manifest", "model_file"])
    base = source.parent if source else Path.cwd()
    if isinstance(config.get("panels"), list):
        for panel in config["panels"]:
            if isinstance(panel, dict):
                for key in ("real", "imag"):
                    if panel.get(key):
                        value = Path(str(panel[key]))
                        panel[key] = str((base / value).resolve()) if not value.is_absolute() else str(value.resolve())
    if not config["metadata"]:
        raise VisualizationError("K-slice metadata is required")
    for output in render_kslice_config(config, args.entry_script, args.validate_only):
        print(output)
    if args.validate_only:
        print("VALIDATION_OK")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="wanniernlqg-visualization")
    subparsers = parser.add_subparsers(dest="command", required=True)
    _band_parser(subparsers)
    _response_parser(subparsers)
    _kslice_parser(subparsers)
    args = parser.parse_args(argv)
    try:
        return int(args.handler(args))
    except VisualizationError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
