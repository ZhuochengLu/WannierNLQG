
"""Format already-normalized physical outputs, retaining exact energy indices and static labels."""
function write_spectral_task_outputs(
    ctx,
    cfg,
    spec,
    grid,
    result,
    components,
    terms,
    volume;
    manifest = nothing,
    qualification = not_evaluated_response_qualification(),
)
    slice=spec.calculation==:kslice;
    orbital=spec.quantity==:orbital_magnetization;
    optical=spec.quantity==:linear_optical_response
    outputs=String[]
    vector_axis = !optical
    vector_integral = vector_axis && !slice
    labels=[join("xyz"[a] for a in component) for component in components]
    coordinates=slice ? zeros(length(grid), 3) :
                optical ? reshape(copy(cfg.photon_energies), :, 1) :
                reshape(copy(cfg.fermi_energies), :, 1)
    if slice
        point=zeros(3)
        for index in 1:length(grid)
            kslice_kpoint!(point, grid, index);
            coordinates[index, :].=point
        end
    end
    coordinate_labels=slice ? ["kx", "ky", "kz"] : optical ? ["energy_eV"] : ["mu_eV"]
    release_sha = vector_axis ? release_tree_sha256() : spectral_response_source_digest()
    schema =
        orbital ? "wanniernlqg.orbital-magnetization-vector/1.0" :
        "wanniernlqg.linear-transport-vector/2.0"
    input_identity = manifest === nothing ? ctx.model_sha256 : manifest.scientific_content_sha256
    authority_sha =
        manifest === nothing ? "NOT_APPLICABLE_DEFINED_FINITE_MODEL" :
        manifest.authoritative_hamiltonian_sha256
    frame_contract_sha =
        manifest === nothing ? "NOT_APPLICABLE_DEFINED_FINITE_MODEL" :
        manifest.band_frame_contract_sha256
    selection_sha =
        manifest === nothing ? "NOT_APPLICABLE_DEFINED_FINITE_MODEL" :
        something(manifest.operator_selection_sha256, "NOT_RECORDED")
    common_headers = Pair{String, String}[
        "schema" => schema,
        "quantity" => string(spec.quantity),
        "method" => string(spec.method),
        "temperature_K" => string(cfg.temperature),
        "fermi_energies_count" => string(length(cfg.fermi_energies)),
        "fermi_energies_sha256" => cfg.fermi_energies_sha256,
        "release_tree_sha256" => release_sha,
        "model_sha256" => ctx.model_sha256,
        "input_identity_sha256" => input_identity,
        "gamma_intra_ev" => (orbital ? "NOT_APPLICABLE" : string(cfg.gamma_intra_ev)),
        "gamma_inter_ev" => (orbital ? "NOT_APPLICABLE" : string(cfg.gamma_inter_ev)),
        "fs_kind" => (orbital ? "NOT_APPLICABLE" : string(cfg.fs_kind)),
        "eta_fs_ev" => (orbital ? "NOT_APPLICABLE" : string(cfg.eta_fs_ev)),
        "mpi_size" => string(bundle_mpi_comm_size(bundle_mpi_comm_world())),
        "julia_threads_per_rank" => string(Threads.nthreads()),
        "qualification_status" => qualification.qualification_status,
        "input_semantics" => orbital ? string(cfg.orbital_input_semantics) :
                             "effective_position_operator_model",
        "operator_inventory" => manifest === nothing ? "NOT_APPLICABLE_DEFINED_FINITE_MODEL" :
                                join(real_space_operator_name.(manifest.inventory), ","),
        "target_contract_sha256" => manifest === nothing ?
                                    "NOT_APPLICABLE_DEFINED_FINITE_MODEL" :
                                    something(
            manifest.operator_target_contract_sha256,
            "NOT_RECORDED",
        ),
        "authoritative_hamiltonian_sha256" => authority_sha,
        "band_frame_contract_sha256" => frame_contract_sha,
        "operator_selection_sha256" => selection_sha,
    ]
    task_stream = IOBuffer()
    for (key, value) in common_headers
        write(task_stream, key, '=', value, '\0')
    end
    task_sha = bytes2hex(sha256(take!(task_stream)))
    push!(common_headers, "task_sha256" => task_sha)
    for (term, name) in enumerate(terms)
        for energy in (slice ? axes(result, 2) : 1:1)
            values=slice ? result[:, energy, :, term] : result[1, :, :, term]
            suffix=slice && optical ? "_E"*lpad(energy, 5, '0') : ""
            path=joinpath(ctx.run_dir, string(spec.quantity)*"_"*string(name)*suffix*".dat")
            unit=orbital ? (slice ? "muB k_integrand" : "muB/cell") :
                 (slice ? "S*m^2 k_integrand" : "S/m")
            headers =
                vector_integral ? vcat(common_headers, ["term" => string(name)]) :
                Pair{String, String}[]
            push!(
                outputs,
                write_spectral_response_table(
                    path,
                    coordinates,
                    coordinate_labels,
                    values,
                    labels;
                    units = unit,
                    digits = vector_integral ? max(16, cfg.response_output_digits) :
                             max(14, cfg.response_output_digits),
                    headers,
                ),
            )
        end
    end
    if optical
        for energy in eachindex(cfg.photon_energies)
            photon=cfg.photon_energies[energy]
            photon==0 && continue
            factor=im/(Responses.RESPONSE_EPSILON0*photon/Responses.RESPONSE_HBAR_EVS)
            for (term, name) in enumerate(terms)
                values=copy(result[:, energy, :, term]) .* factor
                if !slice && name==:total
                    for (c, component) in enumerate(components)
                        component[1]==component[2] && (values[1, c]+=1)
                    end
                end
                output_name=name==:total && !slice ? "model_dielectric_tensor" :
                            "model_dielectric_increment_"*string(name)*(slice ? "_integrand" : "")
                path=joinpath(ctx.run_dir, output_name*"_E"*lpad(energy, 5, '0')*".dat")
                coords=slice ? coordinates : reshape([photon], 1, 1)
                push!(
                    outputs,
                    write_spectral_response_table(
                        path,
                        coords,
                        coordinate_labels,
                        values,
                        labels;
                        units = slice ? "m^3" : "dimensionless",
                        digits = max(14, cfg.response_output_digits),
                    ),
                )
            end
        end
    end
    entries=(
        quantity = string(spec.quantity),
        formula_identity = orbital ? "modern-orbital-W7-W12-thermal-convolution-v1" :
                           "length-gauge-separate-relaxation-v1",
        source_sha256 = spectral_response_source_digest(),
        method = string(spec.method),
        scope = slice ? "k_integrand" : "BZ_integral",
        terms = string.(terms),
        contribution_contract = orbital ? "NOT_APPLICABLE" :
                                "drude-quantum_metric-berry_curvature/2.0",
        schema = vector_axis ? schema : "legacy-spectral-response-table",
        fermi_energies_ev = vector_axis ? cfg.fermi_energies : Float64[],
        fermi_energies_sha256 = vector_axis ? cfg.fermi_energies_sha256 : "NOT_APPLICABLE",
        fermi_energies_count = vector_axis ? string(length(cfg.fermi_energies)) : "0",
        task_sha256 = vector_axis ? task_sha : "NOT_APPLICABLE",
        release_tree_sha256 = vector_axis ? release_sha : "NOT_APPLICABLE",
        temperature_K = string(cfg.temperature),
        model_sha256 = ctx.model_sha256,
        input_identity_sha256 = vector_axis ? input_identity : "NOT_APPLICABLE",
        fermi_energy_ev = vector_axis ? "NOT_APPLICABLE_VECTOR_AXIS" : cfg.fermi_energy,
        gamma_intra_ev = vector_axis ? (orbital ? "NOT_APPLICABLE" : string(cfg.gamma_intra_ev)) :
                         cfg.gamma_intra_ev,
        gamma_inter_ev = vector_axis ? (orbital ? "NOT_APPLICABLE" : string(cfg.gamma_inter_ev)) :
                         cfg.gamma_inter_ev,
        fs_kind = vector_axis ? (orbital ? "NOT_APPLICABLE" : string(cfg.fs_kind)) :
                  string(cfg.fs_kind),
        eta_fs_ev = vector_axis ? (orbital ? "NOT_APPLICABLE" : string(cfg.eta_fs_ev)) :
                    cfg.eta_fs_ev,
        photon_energies_ev = optical ? cfg.photon_energies : Float64[],
        undefined_zero_frequency = optical ? findall(iszero, cfg.photon_energies) : Int[],
        dielectric_zero_frequency_status = optical && any(iszero, cfg.photon_energies) ?
                                           "UNDEFINED_ZERO_FREQUENCY" : "NOT_APPLICABLE",
        dielectric_background = optical ? "identity_after_full_BZ_integration_only" :
                                "NOT_APPLICABLE",
        thermal_definition = orbital ? "thermal_convolution_of_zero_temperature_projectors" :
                             "exact_fermi_derivative_at_positive_T",
        input_semantics = orbital ? string(cfg.orbital_input_semantics) :
                          "effective_position_operator_model",
        contact_definition = orbital ? "NOT_APPLICABLE" :
                             "minus_e_squared_over_hbar_trace_f_ambient_curvature",
        spatial_dimension = 3,
        cell_volume_m3 = volume,
        state_multiplicity = "one_per_explicit_model_state",
        spectral_gap_tolerance_ev = cfg.spectral_gap_tolerance,
        model_content_sha256 = ctx.model_input_mode==:legacy ?
                               bytes2hex(sha256(read(ctx.model_file))) : "see_bundle_manifest",
        mpi_size = string(bundle_mpi_comm_size(bundle_mpi_comm_world())),
        julia_threads_per_rank = string(Threads.nthreads()),
        chemical_potential_count = vector_axis ? length(cfg.fermi_energies) : 0,
        mu_independent_geometry_evaluations = vector_axis ? length(grid) : "NOT_APPLICABLE",
        orbital_completion_evaluations = orbital ?
                                         (
            cfg.orbital_input_semantics == :defined_finite_model ? 0 : length(grid)
        ) : "NOT_APPLICABLE",
        matrix_workspace_count_per_rank = Threads.nthreads(),
        vector_accumulator_shape = vector_axis ? collect(size(result)) : Int[],
        operator_inventory = manifest === nothing ? "NOT_APPLICABLE_DEFINED_FINITE_MODEL" :
                             join(real_space_operator_name.(manifest.inventory), ","),
        target_contract_sha256 = manifest === nothing ? "NOT_APPLICABLE_DEFINED_FINITE_MODEL" :
                                 something(
            manifest.operator_target_contract_sha256,
            "NOT_RECORDED",
        ),
        authoritative_hamiltonian_sha256 = authority_sha,
        band_frame_contract_sha256 = frame_contract_sha,
        operator_selection_sha256 = selection_sha,
    )
    entries=merge(
        entries,
        (;
            operator_qualification = manifest===nothing ? "NOT_APPLICABLE" :
                                     manifest.operator_qualification,
            scientific_content_sha256 = manifest===nothing ? "see_model_sha256" :
                                        manifest.scientific_content_sha256,
            finite_band_galerkin_qualification = manifest===nothing ? "NOT_APPLICABLE" :
                                                 manifest.finite_band_galerkin_qualification,
            execution_eligible = qualification.execution_eligible,
            qualification_status = qualification.qualification_status,
            production_eligible = qualification.production_eligible,
            quality_review_recommended = qualification.quality_review_recommended,
            qualification_reasons = qualification.reasons,
            verified_contracts = qualification.verified_contracts,
            unverified_contracts = qualification.unverified_contracts,
            conflicting_contracts = qualification.conflicting_contracts,
            input_qualification = qualification.input_qualification,
        ),
    )
    push!(
        outputs,
        write_spectral_response_metadata(
            joinpath(ctx.run_dir, "spectral_response_metadata.txt"),
            entries,
        ),
    )
    return outputs
end
