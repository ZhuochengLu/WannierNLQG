# Cover measured cold group classification and report construction.
# Three in-memory sites; no user I/O, solver iteration, or MPI initialization.
@compile_workload let
    if workload_enabled(parentmodule(BandRepresentation))
        for include_time_reversal in (false, true)
            identity_operation = Dict(
                "rotation_fractional" => [[1, 0, 0], [0, 1, 0], [0, 0, 1]],
                "translation_fractional" => [0.0, 0.0, 0.0],
                "antiunitary" => false,
                "source_space_group_indices" => [1],
            )
            antiunitary_identity = merge(
                deepcopy(identity_operation),
                Dict("antiunitary" => true, "source_space_group_indices" => [2]),
            )
            active_operations =
                include_time_reversal ? [identity_operation, antiunitary_identity] :
                [identity_operation]
            payload = Dict{String, Any}(
                "provenance" => Dict(
                    "include_time_reversal" => include_time_reversal,
                    "spglib_version" => string(pkgversion(Spglib)),
                    "spglib_symprec_angstrom" => 1.0e-5,
                ),
                "structure" => Dict(
                    "lattice_rows_angstrom" =>
                        [[1.0, 0.0, 0.0], [0.2, 1.1, 0.0], [0.1, 0.3, 1.3]],
                    "elements" => ["X", "Y", "Z"],
                    "positions_fractional_columns" =>
                        [[0.13, 0.27, 0.39], [0.22, 0.41, 0.58], [0.71, 0.17, 0.83]],
                    "magnetic_moments_cartesian_columns" => [zeros(3) for _ in 1:3],
                ),
                "symmetry" => Dict(
                    "magnetic" => false,
                    "msg_type" => include_time_reversal ? 2 : 1,
                    "uni_number" => nothing,
                    "hall_number" => 1,
                    "unitary_operation_count" => 1,
                    "antiunitary_operation_count" => include_time_reversal ? 1 : 0,
                    "space_group_operations" => active_operations,
                    "point_group_operations" => deepcopy(active_operations),
                    "checks" => Dict(
                        "space_group" => Dict("translation_tolerance_fractional" => 1.0e-8),
                        "tolerance_stability" => Dict("status" => "PASS"),
                    ),
                ),
            )
            report = response_symmetry_group_report(payload; strict = true)
            @assert report["status"] == "RESOLVED"
            @assert report["active_constraint_group"]["group_order"] ==
                    (include_time_reversal ? 2 : 1)
            @assert report["generators"]["magnetic_point_group"]["group_order"] == 2
        end
    end
end
