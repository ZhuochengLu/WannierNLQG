# Hash one typed numerical array for compact TB-support provenance.
function _band_array_sha256(values::Array)
    return bytes2hex(SHA.sha256(reinterpret(UInt8, vec(values))))
end

"""
Execute the spectrum-only Band plan with deterministic global-index ownership.
"""
function run_task_bundle_fused!(
    cfg::EffectiveTaskConfig,
    ctx::RunContext,
    plan::BandStructureBundlePlan,
)
    spec = only(plan.specs)
    comm = bundle_mpi_comm_world()
    rank = bundle_mpi_comm_rank(comm)
    data_path = result_output_path(ctx, spec.quantity, spec.method, spec.calculation)
    json_path = joinpath(ctx.run_dir, "$(ctx.system_name)_kpath.json")
    if rank == 0
        isfile(data_path) && rm(data_path; force = true)
        isfile(json_path) && rm(json_path; force = true)
    end
    bundle_mpi_barrier(comm)
    loaded_sources = load_runtime_model_and_sources(ctx, cfg)
    try
        replica = loaded_sources.replica_summary
        model = loaded_sources.model
        manifest = loaded_sources.manifest
        progress_system_summary!(model)
        progress_task_start!(spec)
        path_plan = make_kpath_plan(cfg, model.lattice)
        point_count = size(path_plan.kpoints, 1)
        execution = execute_kpath_driver(BandStructureKPathKernel(cfg), path_plan, model, comm)
        energies = execution.values
        residuals = execution.residuals

        fourier_summary = (
            backend = :direct,
            NKdiv = nothing,
            NKFFT = nothing,
            factor_source = :arbitrary_fractional_path,
            estimated_memory_bytes = 0,
            memory_limit_bytes = 0,
            path_kpoint_count = point_count,
            mpi_size = execution.mpi_size,
            julia_threads = execution.worker_count,
        )
        progress_fourier_backend!(fourier_summary)
        maximum_residual = rank == 0 ? maximum(residuals; init = 0.0) : 0.0
        maximum_residual = bundle_mpi_bcast(maximum_residual, 0, comm)
        manifest_file_sha256 =
            manifest === nothing ? nothing :
            bundle_mpi_root_call(() -> checksum_file(manifest.path); comm)
        outputs = bundle_mpi_root_call(
            () -> begin
                isfile(data_path) && rm(data_path; force = true)
                isfile(json_path) && rm(json_path; force = true)
                try
                    write_band_structure(
                        data_path,
                        path_plan.cumulative_distances,
                        path_plan.kpoints,
                        energies;
                        energy_reference_eV = cfg.fermi_energy,
                    )
                    _write_kpath_json(json_path, path_plan)
                    return [data_path, json_path]
                catch
                    isfile(data_path) && rm(data_path; force = true)
                    isfile(json_path) && rm(json_path; force = true)
                    rethrow()
                end
            end;
            comm,
        )
        band_summary = (
            schema = "wanniernlqg.band-metadata",
            total_kpoints = point_count,
            node_count = length(path_plan.nodes),
            segment_count = length(path_plan.kpoints_per_segment),
            E_ref_eV = cfg.fermi_energy,
            energy_unit = "eV",
            distance_unit = "A^-1",
            energy_convention = "ascending_eigenvalues_minus_E_ref",
            fourier_phase = "exp(2pi*i*R_dot_k)/wannier90_degeneracy",
            reciprocal_lattice = "B=2pi*A^(-T), row-lattice A",
            maximum_hermiticity_residual = maximum_residual,
            hermiticity_tolerance = cfg.band_hermiticity_tolerance,
            requested_replica_policy = replica.requested_policy,
            effective_replica_policy = replica.effective_policy,
            replica_source = replica.source,
            mp_grid = replica.mp_grid,
            wigner_seitz_tolerance = replica.wigner_seitz_tolerance,
            wigner_seitz_search_size = replica.wigner_seitz_search_size,
            replica_mapping_sha256 = replica.mapping_sha256,
            replica_mapping_digest_scheme = replica.mapping_digest_scheme,
            wsvec_file = replica.wsvec_file,
            wsvec_sha256 = replica.wsvec_sha256,
            input_minimum_distance_materialized = replica.input_materialized,
            output_minimum_distance_materialized = replica.output_materialized,
            replica_transformed_this_run = replica.transformed_this_run,
            input_num_r_vectors = replica.input_num_r_vectors,
            effective_num_r_vectors = replica.output_num_r_vectors,
            lattice_A = model.lattice,
            reciprocal_lattice_A_inverse = reciprocal_lattice(model.lattice),
            r_vector_support_minimum = Tuple(vec(minimum(model.r_vectors; dims = 2))),
            r_vector_support_maximum = Tuple(vec(maximum(model.r_vectors; dims = 2))),
            r_vector_support_sha256 = _band_array_sha256(model.r_vectors),
            degeneracy_count = length(model.r_degeneracies),
            degeneracy_minimum = minimum(model.r_degeneracies),
            degeneracy_maximum = maximum(model.r_degeneracies),
            degeneracy_sum = sum(model.r_degeneracies),
            degeneracy_sha256 = _band_array_sha256(model.r_degeneracies),
            wannier90_degeneracy_applied = true,
            model_num_orbitals = model.num_orbitals,
            qualification = if manifest === nothing
                "INPUT_QUALIFICATION_NOT_PROVIDED"
            elseif manifest.production_eligible
                "INPUT_PRODUCTION_ELIGIBLE"
            else
                "DIAGNOSTIC_ONLY"
            end,
            production_eligible = manifest === nothing ? false : manifest.production_eligible,
            qualification_note = "Numerical Hermiticity does not promote physical or production qualification.",
            manifest_schema = manifest === nothing ? nothing : manifest.schema_version,
            manifest_scientific_sha256 = manifest === nothing ? nothing :
                                         manifest.scientific_content_sha256,
            manifest_geometry_sha256 = manifest === nothing ? nothing :
                                       manifest.geometry_content_sha256,
            manifest_file_sha256 = manifest_file_sha256,
            manifest_paired_tb_sha256 = manifest === nothing ? nothing : manifest.paired_tb_sha256,
            manifest_hamiltonian_component_sha256 = if manifest === nothing
                nothing
            else
                entry_index = findfirst(
                    entry ->
                        entry.kind == REAL_SPACE_HAMILTONIAN &&
                        entry.component_indices == (Int8(0), Int8(0)),
                    manifest.entries,
                )
                entry_index === nothing ? nothing : manifest.entries[entry_index].component_sha256
            end,
            manifest_diagnostic_only = manifest === nothing ? nothing : manifest.diagnostic_only,
            manifest_physics_qualification = manifest === nothing ? nothing :
                                             manifest.physics_qualification,
            manifest_tb_usability = manifest === nothing ? nothing : manifest.tb_usability,
            manifest_final_physics_qualification = manifest === nothing ? nothing :
                                                   manifest.final_physics_qualification,
            manifest_final_production_eligible = manifest === nothing ? nothing :
                                                 manifest.final_production_eligible,
            kpath_json = json_path,
        )
        progress_task_done!(spec, outputs)
        return FusedBundleRunResult(
            outputs,
            ["spectrum"],
            NamedTuple[(family = "spectrum", active = point_count, skipped = 0)],
            fourier_summary,
            NamedTuple(),
            band_summary,
            runtime_replica_summary(replica),
        )
    finally
        release_runtime_storage!(loaded_sources)
    end
end
