function test_operator_bundle_geometry(lattice, degeneracies, operators)
    position = operators[WannierNLQG.Core.REAL_SPACE_POSITION]
    home = only(
        findall(
            index -> all(iszero, @view(position.r_vectors[:, index])),
            axes(position.r_vectors, 2),
        ),
    )
    centers = zeros(Float64, size(position.data, 1), 3)
    for orbital in axes(centers, 1), direction in 1:3
        centers[orbital, direction] =
            real(position.data[orbital, orbital, direction, home] / degeneracies[home])
    end
    fractional = centers * inv(Matrix{Float64}(lattice))
    return Dict(
        "wannier_center_policy" => "symmetrize",
        "real_space_replica_policy" => "input",
        "production_eligible" => true,
        "minimum_distance_materialized" => false,
        "mp_grid" => [1, 1, 1],
        "wannier_center_tolerance" => 1.0e-8,
        "wigner_seitz_tolerance" => 1.0e-5,
        "wigner_seitz_search_size" => 3,
        "raw_wannier_centers_cartesian" => centers,
        "raw_wannier_centers_fractional" => fractional,
        "final_wannier_centers_cartesian" => centers,
        "final_wannier_centers_fractional" => fractional,
        "center_alignment_lattice_shifts" => zeros(Int, size(centers)),
        "replica_mapping_reference" => repeat("0", 64),
    )
end

# Current format mutations exercise mathematical validators directly, without receipts.
function with_republished_bundle_fixture(mutate::F, path) where {F}
    return HDF5.h5open(mutate, path, "r+")
end

# Fixtures are prepared in the current mathematical format before distribution.
function current_packed_fixture_copy(filename, directory)
    version = HDF5.h5open(filename, "r") do handle
        String(read(HDF5.attributes(handle)["schema_version"]))
    end
    version == WannierNLQG.IO.OPERATOR_BUNDLE_SCHEMA_VERSION ||
        throw(ArgumentError("fixture requires the current mathematical model format"))
    target = joinpath(directory, basename(filename))
    cp(filename, target)
    return target
end

function current_model_geometry(manifest)
    return Dict(
        "wannier_center_policy"=>String(manifest.wannier_center_policy),
        "real_space_replica_policy"=>String(manifest.real_space_replica_policy),
        "minimum_distance_materialized"=>manifest.minimum_distance_materialized,
        "mp_grid"=>collect(manifest.mp_grid),
        "wigner_seitz_tolerance"=>manifest.wigner_seitz_tolerance,
        "wigner_seitz_search_size"=>manifest.wigner_seitz_search_size,
        "replica_mapping_reference"=>manifest.replica_mapping_reference,
    )
end
function current_model_provenance(manifest)
    definitions=get(
        manifest.operator_qualification,
        "mathematical_definitions",
        Dict{String, Any}(),
    )
    return merge(
        Dict{String, Any}(k=>v for (k, v) in definitions if !occursin('.', k)),
        Dict(
            "operator_qualification"=>Dict(
                "operators"=>get(manifest.operator_qualification, "operators", Dict()),
            ),
        ),
    )
end
