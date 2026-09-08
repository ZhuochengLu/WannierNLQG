# Convert typed validation results to stable JSON storage names.
function _json_validation(validation::Dict{RealSpaceOperatorKind, OperatorValidationSummary})
    return Dict(operator_storage_name(kind) => value for (kind, value) in validation)
end

# Convert center and replica lifecycle evidence to HDF5/JSON-compatible metadata.
function _geometry_metadata(
    center_geometry::WannierCenterGeometry,
    durable_final_cartesian::Matrix{Float64},
    durable_final_fractional::Matrix{Float64},
    replica_result::RealSpaceReplicaPolicyResult,
    context,
    config::SymmetrizationConfig,
    checkpoint_center_max_abs::Union{Nothing, Float64},
    checkpoint_center_tolerance::Float64,
)
    durable_residuals = _wannier_center_operation_residuals(durable_final_fractional, context.plan)
    durable_maximum_residual = maximum(durable_residuals; init = 0.0)
    center_geometry.policy in (:symmetrize, :validate) &&
        durable_maximum_residual > config.wannier_center_tolerance &&
        throw(
            ArgumentError(
                "durable Wannier-center covariance residual $(durable_maximum_residual) " *
                "exceeds $(config.wannier_center_tolerance)",
            ),
        )
    durable_repeated =
        center_geometry.policy == :symmetrize ?
        _project_wannier_centers(durable_final_fractional, context.plan) : durable_final_fractional
    durable_idempotence_error =
        maximum(abs, durable_repeated .- durable_final_fractional; init = 0.0)
    center_geometry.policy == :symmetrize &&
        durable_idempotence_error > config.wannier_center_tolerance &&
        throw(
            ArgumentError(
                "durable Wannier-center idempotence error $(durable_idempotence_error) " *
                "exceeds $(config.wannier_center_tolerance)",
            ),
        )
    aligned_cartesian = _center_rows_fractional_to_cartesian(
        center_geometry.aligned_fractional,
        context.model.lattice,
    )
    durable_displacements =
        center_geometry.policy == :keep_input ? zeros(Float64, size(durable_final_cartesian)) :
        durable_final_cartesian .- aligned_cartesian
    durable_displacement_norms =
        [norm(@view(durable_displacements[index, :])) for index in axes(durable_displacements, 1)]
    raw_branch_displacements = durable_final_cartesian .- center_geometry.raw_cartesian
    raw_branch_displacement_norms = [
        norm(@view(raw_branch_displacements[index, :])) for
        index in axes(raw_branch_displacements, 1)
    ]
    return Dict(
        "wannier_center_policy" => String(center_geometry.policy),
        "real_space_replica_policy" => String(replica_result.policy),
        "production_eligible" => center_geometry.production_eligible,
        "model_status" =>
            center_geometry.production_eligible ? "production_eligible" :
            "diagnostic_non_covariant_wcc",
        "minimum_distance_materialized" => replica_result.policy == :minimum_distance,
        "mp_grid" => collect(something(context.input.mp_grid)),
        "wannier_center_tolerance" => config.wannier_center_tolerance,
        "wigner_seitz_tolerance" => config.wigner_seitz_tolerance,
        "wigner_seitz_search_size" => config.wigner_seitz_search_size,
        "wannier_center_algorithm" => "affine-representation-projector-v1",
        "real_space_replica_algorithm" => "center-aware-minimum-distance-v1",
        "checkpoint_center_max_abs_modulo_lattice" => checkpoint_center_max_abs,
        "checkpoint_center_tolerance" => checkpoint_center_tolerance,
        "raw_wannier_centers_cartesian" => center_geometry.raw_cartesian,
        "raw_wannier_centers_fractional" => center_geometry.raw_fractional,
        "aligned_wannier_centers_fractional" => center_geometry.aligned_fractional,
        "projected_wannier_centers_cartesian" => center_geometry.final_cartesian,
        "projected_wannier_centers_fractional" => center_geometry.final_fractional,
        "final_wannier_centers_cartesian" => durable_final_cartesian,
        "final_wannier_centers_fractional" => durable_final_fractional,
        "center_alignment_lattice_shifts" => center_geometry.alignment_lattice_shifts,
        "raw_operation_residuals" => center_geometry.raw_operation_residuals,
        "aligned_operation_residuals" => center_geometry.aligned_operation_residuals,
        "projected_operation_residuals" => center_geometry.final_operation_residuals,
        "final_operation_residuals" => durable_residuals,
        "projected_wannier_center_idempotence_error" => center_geometry.idempotence_error,
        "wannier_center_idempotence_error" => durable_idempotence_error,
        "tb_roundtrip_wannier_center_max_abs" =>
            maximum(abs, durable_final_cartesian .- center_geometry.final_cartesian; init = 0.0),
        "maximum_wannier_center_displacement_cartesian" =>
            maximum(durable_displacement_norms; init = 0.0),
        "rms_wannier_center_displacement_cartesian" =>
            isempty(durable_displacement_norms) ? 0.0 :
            sqrt(sum(abs2, durable_displacement_norms) / length(durable_displacement_norms)),
        "maximum_raw_branch_displacement_cartesian" =>
            maximum(raw_branch_displacement_norms; init = 0.0),
        "rms_raw_branch_displacement_cartesian" =>
            isempty(raw_branch_displacement_norms) ? 0.0 :
            sqrt(sum(abs2, raw_branch_displacement_norms) / length(raw_branch_displacement_norms)),
        "replica_mapping_sha256" => replica_result.mapping_sha256,
        "replica_total_assignment_count" => replica_result.total_assignment_count,
        "replica_changed_assignment_count" => replica_result.changed_assignment_count,
        "replica_changed_pair_count" => replica_result.changed_pair_count,
        "replica_tied_assignment_count" => replica_result.tied_assignment_count,
        "replica_pair_changed_counts" => replica_result.pair_changed_counts,
        "replica_original_num_r_vectors" => replica_result.original_num_r_vectors,
        "replica_output_num_r_vectors" => replica_result.output_num_r_vectors,
        "input_link_length_summary_cartesian" =>
            real_space_link_length_summary(replica_result.input_link_lengths_cartesian),
        "output_link_length_summary_cartesian" =>
            real_space_link_length_summary(replica_result.output_link_lengths_cartesian),
    )
end

# Return the lowercase SHA-256 of one durable file.
function _sha256_file(path::AbstractString)
    return open(path, "r") do io
        bytes2hex(SHA.sha256(io))
    end
end

# Record both present and explicitly absent auxiliary inputs.
function _input_file_evidence(paths)
    evidence = Dict{String, Any}()
    for (name, path) in (
        ("win_file", paths.win),
        ("tb_file", paths.tb),
        ("chk_file", paths.chk),
        ("eig_file", paths.eig),
        ("mmn_file", paths.mmn),
        ("spn_file", paths.spn),
    )
        evidence[name] = if path === nothing
            Dict("status" => "not_provided")
        else
            Dict(
                "status" => "provided",
                "path" => path,
                "size_bytes" => filesize(path),
                "sha256" => _sha256_file(path),
            )
        end
    end
    return evidence
end

# Hash the source-bearing candidate tree independently of absolute checkout paths.
function _source_tree_sha256()
    root = pkgdir(WannierNLQG)
    relative_files = String["Project.toml"]
    for subtree in ("src", "ext")
        subtree_path = joinpath(root, subtree)
        for (directory, _, files) in walkdir(subtree_path), file in files
            push!(relative_files, relpath(joinpath(directory, file), root))
        end
    end
    sort!(relative_files)
    manifest = IOBuffer()
    for relative in relative_files
        path = joinpath(root, relative)
        write(manifest, relative, '\0', _sha256_file(path), '\n')
    end
    return bytes2hex(SHA.sha256(take!(manifest)))
end

# Write compact versioned JSON evidence.
function _write_symmetrization_report(config::SymmetrizationConfig, path, payload)
    mkpath(dirname(path))
    versioned_payload = merge(
        Dict("schema" => "wanniernlqg.symmetrization-report", "schema_version" => "1.0"),
        payload,
    )
    open(path, "w") do io
        JSON3.pretty(io, versioned_payload)
        println(io)
    end
    return path
end

# Write a conventional checksum manifest for the three durable scientific outputs.
function _write_sha256sums(path::AbstractString, output_paths; overwrite::Bool)
    ispath(path) && !overwrite && throw(ArgumentError("refusing to overwrite output: $(path)"))
    mkpath(dirname(path))
    open(path, "w") do io
        for output in output_paths
            println(io, _sha256_file(output), "  ", basename(output))
        end
    end
    return path
end
