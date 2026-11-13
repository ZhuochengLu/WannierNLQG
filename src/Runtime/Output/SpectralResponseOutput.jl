
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
    executed_points = length(grid),
)
    slice=spec.calculation==:kslice;
    orbital=spec.quantity==:orbital_magnetization;
    optical=spec.quantity==:linear_optical_response
    intrinsic=spec.quantity==:intrinsic_ahc
    region = cfg.integration_bounds !== nothing
    dimension = integration_model_periodic(cfg) ? 3 : integration_dimension(cfg)
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
    producer_version = string(Base.pkgversion(parentmodule(@__MODULE__)))
    schema =
        intrinsic ? "wanniernlqg.intrinsic-ahc-vector/2.0" :
        orbital ? "wanniernlqg.orbital-magnetization-vector/5.0" :
        "wanniernlqg.linear-transport-vector/6.0"
    region && (schema = "wanniernlqg.cartesian-region-spectral/4.0")
    # References describe the consumed input, not a content certificate.
    input_identity = manifest === nothing ? ctx.model_identity : manifest.path
    operator_model_schema =
        manifest === nothing ? "NOT_APPLICABLE_DEFINED_FINITE_MODEL" :
        String(manifest.schema_version)
    common_headers = Pair{String, String}[
        "schema" => schema,
        "quantity" => string(spec.quantity),
        "method" => string(spec.method),
        "temperature_K" => string(cfg.temperature),
        "fermi_energies_count" => string(length(cfg.fermi_energies)),
        "fermi_energies_definition" => cfg.fermi_energies_definition,
        "producer_package_version" => producer_version,
        "model_identity" => ctx.model_identity,
        "input_identity" => input_identity,
        "gamma_intra_ev" => ((orbital || intrinsic) ? "NOT_APPLICABLE" :
                             string(cfg.gamma_intra_ev)),
        "gamma_inter_ev" => ((orbital || intrinsic) ? "NOT_APPLICABLE" :
                             string(cfg.gamma_inter_ev)),
        "fs_kind" => ((orbital || intrinsic) ? "NOT_APPLICABLE" : string(cfg.fs_kind)),
        "eta_fs_ev" => ((orbital || intrinsic) ? "NOT_APPLICABLE" : string(cfg.eta_fs_ev)),
        "mpi_size" => string(bundle_mpi_comm_size(bundle_mpi_comm_world())),
        "julia_threads_per_rank" => string(Threads.nthreads()),
        "qualification_status" => qualification.qualification_status,
        "input_semantics" => orbital ? string(cfg.orbital_input_semantics) :
                             "effective_position_operator_model",
        "operator_inventory" => manifest === nothing ? "NOT_APPLICABLE_DEFINED_FINITE_MODEL" :
                                join(real_space_operator_name.(manifest.inventory), ","),
        "operator_model_schema" => operator_model_schema,
        "content_authentication" => "NOT_PERFORMED",
    ]
    if orbital
        append!(
            common_headers,
            [
                "orbital_geometry_prescription"=>"complete-V-regularized-Sylvester/1",
                "denominator_regularization_ev"=>string(cfg.denominator_regularization),
                "zero_temperature_boundary"=>"symmetric-complete-subspace-response-average",
            ],
        )
    end
    if intrinsic
        append!(
            common_headers,
            [
                "geometry_contract"=>"complete-velocity-and-ambient-curvature",
                "occupation_contract"=>"T0-real-energy-less-than-or-equal-mu",
                "transition_denominator_contract"=>"direct-velocity-over-every-nonzero-real-gap",
                "resolved_intrinsic_method"=>(spec.method==:projector ? "Projector" : "Matrix"),
                "tensor_axis_order"=>"xx,xy,xz,yx,yy,yz,zx,zy,zz",
                "conductivity_sign"=>"minus-e-squared-over-hbar-times-occupied-Berry-curvature",
            ],
        )
    end
    if region
        append!(
            common_headers,
            [
                string(key)=>string(value) for
                (key, value) in pairs(integration_domain_metadata(cfg))
            ],
        )
    end
    task_definition = spectral_task_definition(common_headers)
    push!(common_headers, "task_definition" => task_definition)
    for (term, name) in enumerate(terms)
        for energy in (slice ? axes(result, 2) : 1:1)
            values=slice ? result[:, energy, :, term] : result[1, :, :, term]
            suffix =
                slice && optical ? "_E" * lpad(energy, 5, '0') :
                slice && intrinsic && length(cfg.fermi_energies) > 1 ? "_M" * lpad(energy, 5, '0') :
                ""
            path=joinpath(ctx.run_dir, string(spec.quantity)*"_"*string(name)*suffix*".dat")
            unit=orbital ? (slice ? "muB k_integrand" : "muB/cell") :
                 (slice ? "S*m^2 k_integrand" : "S/m")
            if region && !slice
                unit =
                    orbital ?
                    (
                        integration_model_periodic(cfg) ? "muB/cell (declared BZ fraction)" :
                        native_direct_low_dimensional(cfg) ?
                        "muB/reference-cell (declared physical-domain fraction)" :
                        string("muB/m^", dimension)
                    ) : integration_unit(cfg, "S/m")
            end
            headers =
                vector_integral ? vcat(common_headers, ["term" => string(name)]) :
                slice && intrinsic ?
                vcat(
                    common_headers,
                    [
                        "term" => string(name),
                        "mu_eV" => string(cfg.fermi_energies[energy]),
                        "sampling_measure" => "unweighted local density; no slice area or cell divisor",
                    ],
                ) : Pair{String, String}[]
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
                if !slice && !region && name==:total
                    for (c, component) in enumerate(components)
                        component[1]==component[2] && (values[1, c]+=1)
                    end
                end
                output_name=name==:total && !slice && !region ? "model_dielectric_tensor" :
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
                        units = slice ? "m^3" :
                                dimension==3 ? "dimensionless" : string("m^", 3-dimension),
                        digits = max(14, cfg.response_output_digits),
                    ),
                )
            end
        end
    end
    entries=(
        quantity = string(spec.quantity),
        formula_identity = intrinsic ? "intrinsic-berry-fermi-sea-complete-block-v1" :
                           orbital ? "modern-orbital-complete-V-eta-symmetric-boundary-v2" :
                           "length-gauge-separate-relaxation-v1",
        source_sha256 = "NOT_REQUESTED_ORDINARY_CALCULATION",
        producer_package_version = producer_version,
        method = string(spec.method),
        scope = slice ? "k_integrand" : region ? "Cartesian_region_integral" : "BZ_integral",
        terms = string.(terms),
        contribution_contract = intrinsic ? "complete-Wannier-curvature-T0-total/1.0" :
                                orbital ? "NOT_APPLICABLE" :
                                "drude-quantum_metric-berry_curvature/2.0",
        schema = vector_axis ? schema : "legacy-spectral-response-table",
        fermi_energies_ev = vector_axis ? cfg.fermi_energies : Float64[],
        fermi_energies_definition = vector_axis ? cfg.fermi_energies_definition : "NOT_APPLICABLE",
        fermi_energies_count = vector_axis ? string(length(cfg.fermi_energies)) : "0",
        task_definition = vector_axis ? task_definition : "NOT_APPLICABLE",
        producer_identity = "package_version; installation audit is optional and separate",
        temperature_K = string(cfg.temperature),
        model_identity = ctx.model_identity,
        input_identity = vector_axis ? input_identity : "NOT_APPLICABLE",
        fermi_energy_ev = vector_axis ? "NOT_APPLICABLE_VECTOR_AXIS" : cfg.fermi_energy,
        gamma_intra_ev = vector_axis ?
                         ((orbital || intrinsic) ? "NOT_APPLICABLE" : string(cfg.gamma_intra_ev)) :
                         cfg.gamma_intra_ev,
        gamma_inter_ev = vector_axis ?
                         ((orbital || intrinsic) ? "NOT_APPLICABLE" : string(cfg.gamma_inter_ev)) :
                         cfg.gamma_inter_ev,
        fs_kind = vector_axis ? ((orbital || intrinsic) ? "NOT_APPLICABLE" : string(cfg.fs_kind)) :
                  string(cfg.fs_kind),
        eta_fs_ev = vector_axis ?
                    ((orbital || intrinsic) ? "NOT_APPLICABLE" : string(cfg.eta_fs_ev)) :
                    cfg.eta_fs_ev,
        photon_energies_ev = optical ? cfg.photon_energies : Float64[],
        undefined_zero_frequency = optical ? findall(iszero, cfg.photon_energies) : Int[],
        dielectric_zero_frequency_status = optical && any(iszero, cfg.photon_energies) ?
                                           "UNDEFINED_ZERO_FREQUENCY" : "NOT_APPLICABLE",
        dielectric_background = optical ?
                                (
            region ? "no_background_for_cutoff_region" : "identity_after_full_BZ_integration_only"
        ) : "NOT_APPLICABLE",
        thermal_definition = orbital ? "thermal_convolution_of_zero_temperature_projectors" :
                             "exact_fermi_derivative_at_positive_T",
        input_semantics = orbital ? string(cfg.orbital_input_semantics) :
                          "effective_position_operator_model",
        contact_definition = orbital ? "NOT_APPLICABLE" :
                             "minus_e_squared_over_hbar_trace_f_ambient_curvature",
        spatial_dimension = dimension,
        cell_volume_m3 = volume,
        state_multiplicity = "one_per_explicit_model_state",
        spectral_gap_tolerance_ev = orbital ? "NOT_APPLICABLE" : cfg.spectral_gap_tolerance,
        model_content_identity = manifest === nothing ? ctx.model_identity : "see_bundle_manifest",
        mpi_size = string(bundle_mpi_comm_size(bundle_mpi_comm_world())),
        julia_threads_per_rank = string(Threads.nthreads()),
        chemical_potential_count = vector_axis ? length(cfg.fermi_energies) : 0,
        mu_independent_geometry_evaluations = vector_axis ? executed_points : "NOT_APPLICABLE",
        orbital_completion_evaluations = orbital ?
                                         (
            cfg.orbital_input_semantics == :defined_finite_model ? 0 : executed_points
        ) : "NOT_APPLICABLE",
        matrix_workspace_count_per_rank = Threads.nthreads(),
        vector_accumulator_shape = vector_axis ? collect(size(result)) : Int[],
        operator_inventory = manifest === nothing ? "NOT_APPLICABLE_DEFINED_FINITE_MODEL" :
                             join(real_space_operator_name.(manifest.inventory), ","),
        operator_model_schema = operator_model_schema,
        content_authentication = "NOT_PERFORMED",
    )
    if region
        entries = merge(
            entries,
            (;
                integration_bounds = cfg.integration_bounds,
                integration_measure = "d^dk/(2pi)^d",
                inverse_quadrature_density_si = volume,
                cell_volume_m3 = "NOT_APPLICABLE_CARTESIAN_REGION",
            ),
        )
    end
    entries=merge(
        entries,
        (;
            operator_qualification = manifest===nothing ? "NOT_APPLICABLE" :
                                     manifest.operator_qualification,
            scientific_input_reference = input_identity,
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
