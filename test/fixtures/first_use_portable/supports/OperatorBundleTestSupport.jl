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
        "replica_mapping_sha256" => repeat("0", 64),
    )
end
