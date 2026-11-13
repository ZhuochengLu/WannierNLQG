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
        qualification = assess_response_qualification(manifest, ctx, cfg, plan.specs)
        progress_response_qualification!(qualification)
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
        if rank == 0 && maximum_residual > cfg.band_hermiticity_tolerance
            @warn "Band input Hermiticity residual exceeds the reporting tolerance; inspect the input and solver representation" maximum_residual tolerance =
                cfg.band_hermiticity_tolerance
        end
        manifest_source_identity =
            manifest === nothing ? nothing :
            bundle_mpi_root_call(
                () -> scientific_file_identity(observe_scientific_source(realpath(manifest.path)));
                comm,
            )
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
            schema = "wanniernlqg.band-metadata/3",
            total_kpoints = point_count,
            node_count = length(path_plan.nodes),
            segment_count = length(path_plan.kpoints_per_segment),
            E_ref_eV = cfg.fermi_energy,
            energy_unit = "eV",
            distance_unit = "A^-1",
            energy_convention = "ascending_eigenvalues_minus_E_ref",
            fourier_phase = model isa AnalyticKModel ? "NOT_APPLICABLE_ANALYTIC_EVALUATION" :
                            model isa NonorthogonalLocalizedModel ?
                            "exp(2pi*i*R_dot_k); explicit localized blocks, no degeneracy weights" :
                            "exp(2pi*i*R_dot_k)/real_space_multiplicity",
            reciprocal_lattice = "B=2pi*A^(-T), row-lattice A",
            maximum_hermiticity_residual = maximum_residual,
            hermiticity_tolerance = cfg.band_hermiticity_tolerance,
            hermiticity_warning = maximum_residual > cfg.band_hermiticity_tolerance,
            hermiticity_tolerance_semantics = "reporting threshold; finite residual does not prevent spectrum output",
            requested_replica_policy = replica.requested_policy,
            effective_replica_policy = replica.effective_policy,
            replica_source = replica.source,
            mp_grid = replica.mp_grid,
            wigner_seitz_tolerance = replica.wigner_seitz_tolerance,
            wigner_seitz_search_size = replica.wigner_seitz_search_size,
            replica_mapping_reference = replica.mapping_reference,
            replica_mapping_reference_schema = replica.mapping_reference_schema,
            input_support_definition = replica.input_support_definition,
            replica_summary_schema = "wanniernlqg.runtime-replica-summary/4",
            wsvec_file = replica.wsvec_file,
            wsvec_identity = replica.wsvec_identity,
            input_minimum_distance_materialized = replica.input_materialized,
            output_minimum_distance_materialized = replica.output_materialized,
            replica_transformed_this_run = replica.transformed_this_run,
            input_num_r_vectors = replica.input_num_r_vectors,
            effective_num_r_vectors = replica.output_num_r_vectors,
            lattice_A = model.lattice,
            reciprocal_lattice_A_inverse = reciprocal_lattice(model.lattice),
            r_vector_support_minimum = model isa AnalyticKModel ? nothing :
                                       Tuple(vec(minimum(model.r_vectors; dims = 2))),
            r_vector_support_maximum = model isa AnalyticKModel ? nothing :
                                       Tuple(vec(maximum(model.r_vectors; dims = 2))),
            r_vector_support_definition = model isa AnalyticKModel ? nothing :
                                          Tuple(
                ntuple(axis -> model.r_vectors[axis, index], 3) for
                index in axes(model.r_vectors, 2)
            ),
            degeneracy_count = model isa Union{AnalyticKModel, NonorthogonalLocalizedModel} ?
                               nothing : length(model.r_degeneracies),
            degeneracy_minimum = model isa Union{AnalyticKModel, NonorthogonalLocalizedModel} ?
                                 nothing : minimum(model.r_degeneracies),
            degeneracy_maximum = model isa Union{AnalyticKModel, NonorthogonalLocalizedModel} ?
                                 nothing : maximum(model.r_degeneracies),
            degeneracy_sum = model isa Union{AnalyticKModel, NonorthogonalLocalizedModel} ?
                             nothing : sum(model.r_degeneracies),
            scalar_degeneracy_definition = model isa
                                           Union{AnalyticKModel, NonorthogonalLocalizedModel} ?
                                           nothing : Tuple(model.r_degeneracies),
            real_space_multiplicity_applied = model isa TightBindingModel,
            model_num_orbitals = model.num_orbitals,
            qualification = "COMPUTATION_READY",
            production_eligible = false,
            qualification_note = "Ordinary spectrum output; measured residuals and retained historical input records are reported separately.",
            manifest_schema = manifest === nothing ? nothing : manifest.schema_version,
            manifest_publication_identity = manifest === nothing ? nothing :
                                            manifest.publication_identity,
            manifest_geometry_definition_hex = manifest === nothing ? nothing :
                                               manifest.geometry_metadata_definition_hex,
            manifest_source_identity = manifest_source_identity,
            manifest_paired_tb_source_bytes = manifest === nothing ? nothing :
                                              manifest.paired_tb_source_bytes,
            manifest_hamiltonian_component_reference = if manifest === nothing
                nothing
            else
                entry_index = findfirst(
                    entry ->
                        entry.kind == REAL_SPACE_HAMILTONIAN &&
                        entry.component_indices == (Int8(0), Int8(0)),
                    manifest.entries,
                )
                entry_index === nothing ? nothing :
                manifest.entries[entry_index].component_reference
            end,
            manifest_quality_review_recommended = manifest === nothing ? nothing :
                                                  manifest.quality_review_recommended,
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
            qualification,
            runtime_model_geometry(model),
        )
    finally
        release_runtime_storage!(loaded_sources)
    end
end
