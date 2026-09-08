# Return one retained solution with a passed embedding gate or fail before construction.
function _projection_materialization_solution(result, solution_index::Int)
    _validate_projection_search_result(result)
    result.complete ||
        throw(ArgumentError("projection basis materialization requires a complete search"))
    result.status == PROJECTION_SEARCH_COMPLETE ||
        throw(ArgumentError("projection basis materialization requires PROJECTION_SEARCH_COMPLETE"))
    result.payload_sha256 == _projection_search_payload_sha256(result) ||
        throw(ArgumentError("projection search result payload SHA-256 mismatch"))
    1 <= solution_index <= length(result.solutions) ||
        throw(BoundsError(result.solutions, solution_index))
    solution = result.solutions[solution_index]
    solution.validation_status == PROJECTION_VALIDATION_PASSED ||
        throw(ArgumentError("projection search solution embedding validation did not pass"))
    solution.total_dimension == result.num_wannier ||
        throw(ArgumentError("projection search solution dimension disagrees with num_wannier"))
    solution.candidate_ids == getfield.(result.candidates, :id) ||
        throw(ArgumentError("projection search solution candidate inventory mismatch"))
    length(solution.coefficients) == length(result.candidates) ||
        throw(DimensionMismatch("projection search solution coefficient count mismatch"))
    all(>=(0), solution.coefficients) ||
        throw(ArgumentError("projection search solution contains a negative coefficient"))
    return solution
end

"""
    materialize_projection_basis(result; solution_index=1)

Expand one complete solution with passed embedding validation through the canonical Symmetrization
basis builder. No AMN matrix, SAWF state, tight-binding model, or response is
constructed by this operation.
"""
function materialize_projection_basis(
    result::ProjectionRepresentationSearchResult;
    solution_index::Integer = 1,
)
    index = Int(solution_index)
    solution = _projection_materialization_solution(result, index)
    specs = _selected_projection_specs(result.candidates, solution.coefficients)
    isempty(specs) && throw(ArgumentError("projection search solution expands to no specs"))
    basis = build_wannier_projection_basis(
        specs;
        spinor = result.spinor,
        num_wannier = result.num_wannier,
        tolerance = 1.0e-8,
        radial_transform = result.radial_transform,
    )
    basis.num_wannier == result.num_wannier ||
        throw(ArgumentError("materialized projection basis dimension mismatch"))
    basis.spinor == result.spinor ||
        throw(ArgumentError("materialized projection basis spinor mismatch"))
    return basis
end

# Resolve and hash the exact representation owned by an immutable SAWF template.
function _projection_materialization_representation(template)
    input = template.input
    (input.band_representation === nothing) == (input.band_representation_hdf5 === nothing) &&
        throw(ArgumentError("SAWF materialization requires exactly one band_representation source"))
    representation = if input.band_representation !== nothing
        something(input.band_representation)
    else
        read_band_representation_hdf5(something(input.band_representation_hdf5))
    end
    return representation, representation_static_sha256(representation)
end

# Require the representation to carry the exact target-contract identity.
function _validate_projection_materialization_contract(representation, result)
    recorded_contract = get(
        representation.conventions,
        "target_subspace_contract_sha256",
        get(representation.input_sha256, "TARGET_SUBSPACE_CONTRACT_SHA256", ""),
    )
    recorded_contract == result.contract_sha256 || throw(
        ArgumentError(
            "SAWF representation does not carry the searched target-subspace contract SHA-256",
        ),
    )
    for (key, expected) in (
        "outer_mask_sha256" => result.outer_mask_sha256,
        "frozen_mask_sha256" => result.frozen_mask_sha256,
    )
        recorded = get(representation.conventions, key, expected)
        recorded == expected ||
            throw(ArgumentError("SAWF representation $(key) disagrees with search result"))
    end
    return nothing
end

# Recompute exact complete-block solver masks and compare their logical identities.
function _validate_projection_materialization_windows(template, representation, result)
    outer_masks, frozen_masks = window_masks_from_energies(
        template,
        representation.energies_ev,
        representation.band_block_labels,
    )
    outer = BitMatrix(hcat(outer_masks...))
    frozen = BitMatrix(hcat(frozen_masks...))
    outer_sha = qualification_mask_sha256(outer)
    frozen_sha = qualification_mask_sha256(frozen)
    outer_sha == result.outer_mask_sha256 || throw(
        ArgumentError("SAWF template outer window does not reproduce the searched outer mask"),
    )
    frozen_sha == result.frozen_mask_sha256 || throw(
        ArgumentError("SAWF template frozen window does not reproduce the searched frozen mask"),
    )
    return nothing
end

"""
    materialize_symmetry_adapted_wannierization_config(template, result; solution_index=1)

Reconstruct the immutable SAWF config with only `projection_basis` replaced.
The representation, target-contract identity, exact complete-block windows,
spinor convention, and dimension are checked before reconstruction. The
routine does not enter initialization or either Z/U solver stage.
"""
function materialize_symmetry_adapted_wannierization_config(
    template::SymmetryAdaptedWannierizationConfig,
    result::ProjectionRepresentationSearchResult;
    solution_index::Integer = 1,
)
    basis = materialize_projection_basis(result; solution_index)
    template.input.num_wannier == result.num_wannier ||
        throw(ArgumentError("SAWF template num_wannier disagrees with projection search result"))
    representation, representation_sha256 = _projection_materialization_representation(template)
    representation_sha256 == result.representation_sha256 ||
        throw(ArgumentError("SAWF template band representation SHA-256 mismatch"))
    representation.spinor == result.spinor ||
        throw(ArgumentError("SAWF template spinor convention mismatch"))
    _validate_projection_materialization_contract(representation, result)
    _validate_projection_materialization_windows(template, representation, result)

    materialized = replace_wannierization_config(template; input = (projection_basis = basis,))
    for group_name in fieldnames(SymmetryAdaptedWannierizationConfig)
        materialized_group = getfield(materialized, group_name)
        template_group = getfield(template, group_name)
        for name in fieldnames(typeof(template_group))
            name == :projection_basis && continue
            isequal(getfield(materialized_group, name), getfield(template_group, name)) || throw(
                ErrorException(
                    "SAWF materializer changed field $(group_name).$(name) in addition to input.projection_basis",
                ),
            )
        end
    end
    return materialized
end
