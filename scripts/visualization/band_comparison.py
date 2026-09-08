from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np

from .band_adapters import BandDataset, displayed_energies
from .common import VisualizationError, audited_file, sha256_file


MATCH_MAP_COLUMN_KEYS = {
    "kpoint",
    "model_band",
    "reference_band",
    "reference_energy_ev",
    "model_energy_ev",
    "signed_error_ev",
    "cluster_mismatch_count",
}


@dataclass(frozen=True)
class BandErrorAssessment:
    model_id: str
    match_map_input: dict[str, Any]
    reference_indices_zero_based: np.ndarray
    signed_errors_ev: np.ndarray
    per_k_rms_ev: np.ndarray
    per_k_maximum_ev: np.ndarray
    cluster_mismatch_count_per_k: np.ndarray
    metrics: dict[str, Any]


def _integer_list(value: Any, context: str, upper_bound: int) -> list[int]:
    if not isinstance(value, list) or not value:
        raise VisualizationError(f"{context} must be a nonempty integer list")
    if any(isinstance(item, bool) or not isinstance(item, int) for item in value):
        raise VisualizationError(f"{context} must contain only integers")
    if len(set(value)) != len(value):
        raise VisualizationError(f"{context} contains duplicates")
    if any(item < 0 or item >= upper_bound for item in value):
        raise VisualizationError(f"{context} is outside the loaded reference band range")
    return sorted(value)


def resolve_full_display_sets(
    config: dict[str, Any],
    reference: BandDataset,
    models: list[BandDataset],
    reference_spec: dict[str, Any],
    model_specs: list[dict[str, Any]],
    assessments: list[BandErrorAssessment] | None = None,
) -> dict[str, Any]:
    """Resolve a window containing every model band plus declared unfitted DFT context."""
    if reference_spec.get("band_indices_zero_based") is not None:
        raise VisualizationError(
            "full_display_sets requires the complete loaded reference; "
            "band_indices_zero_based is not allowed"
        )
    for model_spec in model_specs:
        if model_spec.get("band_indices_zero_based") is not None:
            raise VisualizationError(
                "full_display_sets requires every loaded model band; "
                "band_indices_zero_based is not allowed on models"
            )
    reference_energies = displayed_energies(reference)
    fitted = _integer_list(
        reference_spec.get("fitted_band_indices_zero_based"),
        "reference.fitted_band_indices_zero_based",
        reference_energies.shape[1],
    )
    policy = config.get("display_window_policy")
    if not isinstance(policy, dict):
        raise VisualizationError("band display_window_policy must be an object")
    mode = str(policy.get("mode", "as_configured"))
    if mode not in {"as_configured", "full_model_with_reference_context"}:
        raise VisualizationError(
            "display_window_policy.mode must be as_configured or "
            "full_model_with_reference_context"
        )
    if mode != "full_model_with_reference_context":
        raise VisualizationError(
            "full_display_sets requires display_window_policy.mode="
            "full_model_with_reference_context"
        )
    padding = float(policy.get("padding_ev", 0.0))
    below_count = policy.get("unfitted_reference_bands_below", 1)
    above_count = policy.get("unfitted_reference_bands_above", 1)
    minimum_unmatched = policy.get("minimum_unmatched_reference_states_per_k", 0)
    maximum_unmatched = policy.get("maximum_unmatched_reference_states_per_k")
    if not np.isfinite(padding) or padding < 0.0:
        raise VisualizationError("display_window_policy.padding_ev must be finite and nonnegative")
    if any(isinstance(value, bool) or not isinstance(value, int) or value < 0 for value in (below_count, above_count)):
        raise VisualizationError(
            "display_window_policy context band counts must be nonnegative integers"
        )
    if isinstance(minimum_unmatched, bool) or not isinstance(minimum_unmatched, int) or minimum_unmatched < 0:
        raise VisualizationError(
            "display_window_policy.minimum_unmatched_reference_states_per_k must be a "
            "nonnegative integer"
        )
    if maximum_unmatched is not None and (
        isinstance(maximum_unmatched, bool)
        or not isinstance(maximum_unmatched, int)
        or maximum_unmatched < minimum_unmatched
    ):
        raise VisualizationError(
            "display_window_policy.maximum_unmatched_reference_states_per_k must be null "
            "or an integer not below the minimum"
        )
    fitted_set = set(fitted)
    lower_available = [index for index in range(min(fitted)) if index not in fitted_set]
    upper_available = [
        index
        for index in range(max(fitted) + 1, reference_energies.shape[1])
        if index not in fitted_set
    ]
    if below_count > len(lower_available) or above_count > len(upper_available):
        raise VisualizationError("requested unfitted DFT context bands are outside the reference range")
    context_below = lower_available[-below_count:] if below_count else []
    context_above = upper_available[:above_count]
    context = context_below + context_above
    model_arrays = [displayed_energies(model) for model in models]
    required_arrays = list(model_arrays)
    if context:
        required_arrays.append(reference_energies[:, context])
    required_minimum = min(float(np.min(array)) for array in required_arrays)
    required_maximum = max(float(np.max(array)) for array in required_arrays)
    required_window = [required_minimum - padding, required_maximum + padding]
    configured_window = config.get("energy_window")
    if configured_window is None:
        resolved_window = required_window
    else:
        if (
            not isinstance(configured_window, list)
            or len(configured_window) != 2
            or not all(isinstance(value, (int, float)) and np.isfinite(value) for value in configured_window)
            or not float(configured_window[0]) < float(configured_window[1])
        ):
            raise VisualizationError("band energy_window must contain two increasing finite values")
        resolved_window = [float(configured_window[0]), float(configured_window[1])]
        tolerance = 32.0 * np.finfo(float).eps * max(
            1.0, abs(required_minimum), abs(required_maximum)
        )
        if resolved_window[0] > required_minimum + tolerance or resolved_window[1] < required_maximum - tolerance:
            raise VisualizationError(
                "configured energy_window clips a complete model band or the requested "
                "unfitted DFT context"
            )
    config["energy_window"] = resolved_window
    visible_reference = [
        index
        for index in range(reference_energies.shape[1])
        if float(np.max(reference_energies[:, index])) >= resolved_window[0]
        and float(np.min(reference_energies[:, index])) <= resolved_window[1]
    ]
    config["_reference_band_roles"] = {
        "fitted_indices_zero_based": fitted,
        "unfitted_context_indices_zero_based": context,
    }
    unmatched_audit: dict[str, Any] = {}
    assessment_by_model = {
        assessment.model_id: assessment for assessment in list(assessments or [])
    }
    if minimum_unmatched > 0 or maximum_unmatched is not None:
        if set(assessment_by_model) != {model.dataset_id for model in models}:
            raise VisualizationError(
                "unmatched DFT context limits require one revalidated precomputed match map "
                "for every model"
            )
        for model in models:
            assessment = assessment_by_model[model.dataset_id]
            counts: list[int] = []
            for kpoint in range(reference_energies.shape[0]):
                visible_at_k = {
                    index
                    for index in range(reference_energies.shape[1])
                    if resolved_window[0] <= float(reference_energies[kpoint, index]) <= resolved_window[1]
                }
                matched_at_k = {
                    int(index) for index in assessment.reference_indices_zero_based[kpoint]
                }
                counts.append(len(visible_at_k - matched_at_k))
            observed_minimum = min(counts)
            observed_maximum = max(counts)
            if observed_minimum < minimum_unmatched:
                raise VisualizationError(
                    f"resolved energy window has only {observed_minimum} unmatched DFT states "
                    f"at one k point for model {model.dataset_id}; required at least "
                    f"{minimum_unmatched}"
                )
            if maximum_unmatched is not None and observed_maximum > maximum_unmatched:
                raise VisualizationError(
                    f"resolved energy window has {observed_maximum} unmatched DFT states at "
                    f"one k point for model {model.dataset_id}; allowed at most "
                    f"{maximum_unmatched}"
                )
            unmatched_audit[model.dataset_id] = {
                "minimum_per_k": observed_minimum,
                "maximum_per_k": observed_maximum,
                "mean_per_k": float(np.mean(counts)),
                "required_minimum_per_k": minimum_unmatched,
                "allowed_maximum_per_k": maximum_unmatched,
            }
    return {
        "mode": "full_display_sets",
        "reference_loaded_band_count": int(reference_energies.shape[1]),
        "reference_fitted_band_indices_zero_based": fitted,
        "reference_unfitted_context_indices_zero_based": context,
        "reference_visible_band_indices_zero_based": visible_reference,
        "model_loaded_band_counts": {
            model.dataset_id: int(array.shape[1]) for model, array in zip(models, model_arrays)
        },
        "required_energy_window_ev": required_window,
        "resolved_energy_window_ev": resolved_window,
        "all_model_bands_fully_visible": all(
            float(np.min(array)) >= resolved_window[0]
            and float(np.max(array)) <= resolved_window[1]
            for array in model_arrays
        ),
        "requested_unfitted_context_fully_visible": all(
            float(np.min(reference_energies[:, index])) >= resolved_window[0]
            and float(np.max(reference_energies[:, index])) <= resolved_window[1]
            for index in context
        ),
        "unmatched_reference_states_in_window": unmatched_audit,
        "interpolation": "none",
        "energy_shift": "none",
        "numerical_difference": "external_precomputed_match_map_only",
    }


def _validate_map_spec(spec: Any) -> dict[str, Any]:
    if not isinstance(spec, dict):
        raise VisualizationError("each error_assessment map must be an object")
    allowed = {
        "model_id", "data", "expected_sha256", "index_base", "energy_convention", "columns"
    }
    unknown = sorted(set(spec) - allowed)
    if unknown:
        raise VisualizationError(f"unknown error_assessment map fields: {', '.join(unknown)}")
    missing = sorted(
        field
        for field in ("model_id", "data", "expected_sha256", "energy_convention", "columns")
        if field not in spec
    )
    if missing:
        raise VisualizationError(f"missing error_assessment map fields: {', '.join(missing)}")
    columns = spec["columns"]
    if not isinstance(columns, dict) or set(columns) != MATCH_MAP_COLUMN_KEYS:
        raise VisualizationError(
            "error_assessment columns must contain exactly "
            + ", ".join(sorted(MATCH_MAP_COLUMN_KEYS))
        )
    if any(not isinstance(value, str) or not value for value in columns.values()):
        raise VisualizationError("error_assessment column names must be nonempty strings")
    index_base = spec.get("index_base", 1)
    if index_base not in (0, 1):
        raise VisualizationError("error_assessment index_base must be 0 or 1")
    if str(spec["energy_convention"]).lower() not in {"absolute", "relative_to_reference"}:
        raise VisualizationError(
            "error_assessment energy_convention must be absolute or relative_to_reference"
        )
    digest = spec["expected_sha256"]
    if not isinstance(digest, str) or len(digest) != 64 or any(
        char not in "0123456789abcdefABCDEF" for char in digest
    ):
        raise VisualizationError("error_assessment expected_sha256 must be a SHA-256 digest")
    return spec


def _read_precomputed_map(
    spec: dict[str, Any],
    reference: BandDataset,
    model: BandDataset,
    energy_tolerance_ev: float,
) -> BandErrorAssessment:
    source = Path(spec["data"]).resolve()
    if not source.is_file():
        raise VisualizationError(f"precomputed band match map does not exist: {source}")
    actual_digest = sha256_file(source)
    if actual_digest.lower() != str(spec["expected_sha256"]).lower():
        raise VisualizationError(
            f"precomputed band match map digest mismatch: expected {spec['expected_sha256']}, "
            f"got {actual_digest}"
        )
    columns = spec["columns"]
    relative_reference_energies = displayed_energies(reference)
    relative_model_energies = displayed_energies(model)
    convention = str(spec["energy_convention"]).lower()
    if convention == "absolute":
        reference_energies = relative_reference_energies + reference.energy_reference_ev
        model_energies = relative_model_energies + model.energy_reference_ev
    else:
        reference_energies = relative_reference_energies
        model_energies = relative_model_energies
    nkpoint, nmodel = model_energies.shape
    reference_indices = np.full((nkpoint, nmodel), -1, dtype=int)
    errors = np.full((nkpoint, nmodel), np.nan, dtype=float)
    mismatch = np.full(nkpoint, -1, dtype=int)
    seen = np.zeros((nkpoint, nmodel), dtype=bool)
    index_base = int(spec.get("index_base", 1))
    try:
        with source.open(newline="", encoding="utf-8") as stream:
            reader = csv.DictReader(stream)
            if reader.fieldnames is None:
                raise VisualizationError("precomputed band match map is missing a header")
            missing_columns = sorted(set(columns.values()) - set(reader.fieldnames))
            if missing_columns:
                raise VisualizationError(
                    "precomputed band match map is missing columns: " + ", ".join(missing_columns)
                )
            for line_number, row in enumerate(reader, start=2):
                kpoint = int(row[columns["kpoint"]]) - index_base
                model_band = int(row[columns["model_band"]]) - index_base
                reference_band = int(row[columns["reference_band"]]) - index_base
                if not (0 <= kpoint < nkpoint and 0 <= model_band < nmodel):
                    raise VisualizationError(
                        f"precomputed match index is outside the model grid at line {line_number}"
                    )
                if not 0 <= reference_band < reference_energies.shape[1]:
                    raise VisualizationError(
                        f"precomputed reference band is outside the full DFT set at line {line_number}"
                    )
                if seen[kpoint, model_band]:
                    raise VisualizationError(
                        f"duplicate precomputed match at k={kpoint + index_base}, "
                        f"model band={model_band + index_base}"
                    )
                declared_reference = float(row[columns["reference_energy_ev"]])
                declared_model = float(row[columns["model_energy_ev"]])
                declared_error = float(row[columns["signed_error_ev"]])
                declared_mismatch = int(row[columns["cluster_mismatch_count"]])
                values = (declared_reference, declared_model, declared_error)
                if not all(np.isfinite(value) for value in values) or declared_mismatch < 0:
                    raise VisualizationError(f"invalid precomputed match value at line {line_number}")
                actual_reference = float(reference_energies[kpoint, reference_band])
                actual_model = float(model_energies[kpoint, model_band])
                actual_error = actual_model - actual_reference
                if max(
                    abs(declared_reference - actual_reference),
                    abs(declared_model - actual_model),
                    abs(declared_error - actual_error),
                ) > energy_tolerance_ev:
                    raise VisualizationError(
                        f"precomputed match energies disagree with current DFT/TB inputs at "
                        f"line {line_number}"
                    )
                if mismatch[kpoint] not in (-1, declared_mismatch):
                    raise VisualizationError(
                        f"cluster mismatch count is inconsistent at k={kpoint + index_base}"
                    )
                mismatch[kpoint] = declared_mismatch
                reference_indices[kpoint, model_band] = reference_band
                errors[kpoint, model_band] = actual_error
                seen[kpoint, model_band] = True
    except (OSError, ValueError) as exc:
        if isinstance(exc, VisualizationError):
            raise
        raise VisualizationError(f"cannot parse precomputed band match map {source}: {exc}") from exc
    if not np.all(seen):
        missing = np.argwhere(~seen)[0]
        raise VisualizationError(
            f"precomputed match map does not cover k={missing[0] + index_base}, "
            f"model band={missing[1] + index_base}"
        )
    for kpoint in range(nkpoint):
        if len(set(int(value) for value in reference_indices[kpoint])) != nmodel:
            raise VisualizationError(
                f"precomputed match map reuses a DFT band at k={kpoint + index_base}"
            )
    per_k_rms = np.sqrt(np.mean(errors * errors, axis=1))
    per_k_maximum = np.max(np.abs(errors), axis=1)
    absolute = np.abs(errors).ravel()
    metrics = {
        "matched_sample_count": int(errors.size),
        "matched_state_count_per_k": int(nmodel),
        "global_rms_ev": float(np.sqrt(np.mean(errors * errors))),
        "global_p95_absolute_ev": float(np.percentile(absolute, 95.0)),
        "global_maximum_absolute_ev": float(np.max(absolute)),
        "maximum_per_k_rms_ev": float(np.max(per_k_rms)),
        "cluster_mismatch_sum": int(np.sum(mismatch)),
        "energy_tolerance_ev": float(energy_tolerance_ev),
        "matching": "precomputed_and_revalidated",
        "match_map_energy_convention": convention,
        "interpolation": "none",
        "energy_shift": "none",
    }
    return BandErrorAssessment(
        model.dataset_id,
        audited_file(source, "precomputed_band_match_map"),
        reference_indices,
        errors,
        per_k_rms,
        per_k_maximum,
        mismatch,
        metrics,
    )


def load_error_assessments(
    config: dict[str, Any],
    reference: BandDataset,
    models: list[BandDataset],
) -> list[BandErrorAssessment]:
    error_config = config.get("error_assessment")
    if not isinstance(error_config, dict):
        raise VisualizationError("band error_assessment must be an object")
    mode = str(error_config.get("mode", "none"))
    if mode == "none":
        return []
    if mode != "precomputed_match_map":
        raise VisualizationError("error_assessment.mode must be none or precomputed_match_map")
    tolerance = float(error_config.get("energy_tolerance_ev", 1.0e-10))
    if not np.isfinite(tolerance) or tolerance < 0.0:
        raise VisualizationError("error_assessment.energy_tolerance_ev must be finite and nonnegative")
    maps = error_config.get("maps")
    if not isinstance(maps, list) or len(maps) != len(models):
        raise VisualizationError("error_assessment.maps must contain exactly one map per model")
    model_by_id = {model.dataset_id: model for model in models}
    if len(model_by_id) != len(models):
        raise VisualizationError("band model ids must be unique")
    specs = [_validate_map_spec(spec) for spec in maps]
    if {str(spec["model_id"]) for spec in specs} != set(model_by_id):
        raise VisualizationError("error_assessment model ids must match the configured models exactly")
    return [
        _read_precomputed_map(spec, reference, model_by_id[str(spec["model_id"])], tolerance)
        for spec in specs
    ]
