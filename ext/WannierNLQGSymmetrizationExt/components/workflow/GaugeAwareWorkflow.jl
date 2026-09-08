"""
Symmetrize an existing model in its actual CHK composite gauge.

Numerical gates either stop at their legacy stage or are recorded while the
unaltered group-average workflow continues, according to `threshold_policy`.
Structural input and serialization errors remain fatal.
"""
function symmetrize_existing_wannier_model(config::GaugeAwareSymmetrizationConfig)
    _validate_gauge_aware_config(config)
    ispath(config.output_root) &&
        !config.overwrite &&
        throw(ArgumentError("refusing to overwrite output root $(config.output_root)"))
    mkpath(config.output_root)
    directories = ["analysis", "dmn", "figures", "logs", "manifests", "scripts"]
    append!(
        directories,
        [joinpath("outputs", String(variant)) for variant in config.materialization_variants],
    )
    for directory in directories
        mkpath(joinpath(config.output_root, directory))
    end
    artifacts = Dict{String, String}()
    metrics = Dict{String, Float64}()
    diagnostics = String[]
    threshold_events = GaugeAwareThresholdEvent[]
    for script in config.provenance_scripts
        isfile(script) || throw(ArgumentError("provenance script does not exist: $(script)"))
        destination = joinpath(config.output_root, "scripts", basename(script))
        cp(script, destination; force = config.overwrite)
        artifacts["script_$(basename(script))"] = destination
    end
    input_files = [
        "representation" => config.representation_hdf5_file,
        "poscar" => config.poscar_file,
        "wavecar" => config.wavecar_file,
        "source_win" => config.source_win_file,
        "source_eig" => config.source_eig_file,
        "source_mmn" => config.source_mmn_file,
        "target_win" => config.win_file,
        "target_eig" => config.eig_file,
        "target_mmn" => config.mmn_file,
        "target_chk" => config.chk_file,
        "target_tb" => config.tb_file,
    ]
    config.oracle_hdf5_file === nothing ||
        push!(input_files, "oracle" => something(config.oracle_hdf5_file))
    for (_, filename) in input_files
        isfile(filename) || throw(ArgumentError("required input does not exist: $(filename)"))
    end
    artifacts["input_manifest"] = _write_gauge_aware_input_manifest(config, input_files)

    source_hashes = Dict(label => _sha256_file(path) for (label, path) in input_files)
    provenance_ok = _matching_gauge_aware_wannier_inputs(source_hashes)
    if !provenance_ok
        push!(diagnostics, "source and target WIN/EIG/MMN identities are mixed")
        return _publish_gauge_aware_status(
            config,
            FAILED_INPUT_PROVENANCE,
            artifacts,
            metrics,
            diagnostics,
            threshold_events,
        )
    end
    representation = read_band_representation_hdf5(config.representation_hdf5_file)
    source_eig = read_wannier_eig(config.source_eig_file)
    eig_provenance = _validate_and_attach_gauge_aware_eig!(
        representation,
        source_eig,
        source_hashes["source_eig"],
    )
    metrics["representation_vs_eig_max_ev"] = eig_provenance.maximum_error
    eig_provenance.augmented && push!(
        diagnostics,
        "legacy representation lacked EIG hash; exact energy equality was verified before attaching it",
    )
    representation_provenance_ok =
        eig_provenance.passed &&
        _matching_gauge_aware_representation_inputs(source_hashes, representation)
    if !representation_provenance_ok
        push!(diagnostics, "POSCAR/WAVECAR/EIG hashes disagree with band-representation provenance")
        return _publish_gauge_aware_status(
            config,
            FAILED_INPUT_PROVENANCE,
            artifacts,
            metrics,
            diagnostics,
            threshold_events,
        )
    end
    try
        configure_band_qualification_window!(representation, config.qualification_window_ev)
    catch exception
        push!(diagnostics, sprint(showerror, exception))
        return _publish_gauge_aware_status(
            config,
            FAILED_BAND_REPRESENTATION,
            artifacts,
            metrics,
            diagnostics,
            threshold_events,
        )
    end
    representation_validation = try
        validate_band_representation(
            representation;
            absolute_tolerance = config.thresholds.group_law_absolute,
            oracle_excess_tolerance = config.thresholds.group_law_oracle_excess,
            oracle_hdf5_file = config.oracle_hdf5_file,
            require_oracle = config.require_oracle,
        )
    catch exception
        push!(diagnostics, sprint(showerror, exception))
        return _publish_gauge_aware_status(
            config,
            FAILED_BAND_REPRESENTATION,
            artifacts,
            metrics,
            diagnostics,
            threshold_events,
        )
    end
    metrics["band_group_law_absolute_max"] =
        maximum(representation_validation.maximum_group_law_residuals)
    metrics["band_unitarity_max"] = representation_validation.maximum_unitarity_residual
    metrics["band_theta_max"] = representation_validation.maximum_theta_residual
    if representation_validation.oracle_excess_group_law_residuals !== nothing
        metrics["band_group_law_oracle_excess_max"] =
            maximum(something(representation_validation.oracle_excess_group_law_residuals))
    end
    metrics["band_reciprocal_shift_max"] =
        representation_validation.maximum_reciprocal_shift_residual
    representation_passed = Bool[
        _record_gauge_aware_threshold!(
            threshold_events,
            diagnostics,
            :band_representation,
            "band_group_law_absolute_max",
            metrics["band_group_law_absolute_max"],
            config.thresholds.group_law_absolute,
        ),
        _record_gauge_aware_threshold!(
            threshold_events,
            diagnostics,
            :band_representation,
            "band_reciprocal_shift_max",
            metrics["band_reciprocal_shift_max"],
            config.thresholds.group_law_absolute,
        ),
        _record_gauge_aware_threshold!(
            threshold_events,
            diagnostics,
            :band_representation,
            "band_unitarity_max",
            metrics["band_unitarity_max"],
            config.thresholds.group_law_absolute,
        ),
        _record_gauge_aware_threshold!(
            threshold_events,
            diagnostics,
            :band_representation,
            "band_theta_max",
            metrics["band_theta_max"],
            config.thresholds.group_law_absolute,
        ),
    ]
    if representation_validation.oracle_excess_group_law_residuals !== nothing
        push!(
            representation_passed,
            _record_gauge_aware_threshold!(
                threshold_events,
                diagnostics,
                :band_representation,
                "band_group_law_oracle_excess_max",
                metrics["band_group_law_oracle_excess_max"],
                config.thresholds.group_law_oracle_excess,
            ),
        )
    end
    numeric_representation_passed = all(representation_passed) && representation_validation.passed
    if !representation_validation.passed && all(representation_passed)
        push!(
            representation_passed,
            _record_gauge_aware_threshold!(
                threshold_events,
                diagnostics,
                :band_representation,
                "band_representation_oracle_parity_flag",
                1.0,
                0.5;
                context = join(representation_validation.diagnostics, "; "),
            ),
        )
        numeric_representation_passed = false
    end
    if _gauge_aware_fail_stop(config, numeric_representation_passed)
        append!(diagnostics, representation_validation.diagnostics)
        return _publish_gauge_aware_status(
            config,
            FAILED_BAND_REPRESENTATION,
            artifacts,
            metrics,
            diagnostics,
            threshold_events,
        )
    elseif !numeric_representation_passed
        append!(diagnostics, representation_validation.diagnostics)
    end
    dmn_hdf5 = joinpath(config.output_root, "dmn", "band_representation.h5")
    artifacts["band_representation_hdf5"] = write_band_representation_hdf5(
        dmn_hdf5,
        representation;
        validation = representation_validation,
        overwrite = config.overwrite,
    )
    dmn_json = joinpath(config.output_root, "dmn", "band_representation.json")
    artifacts["band_representation_json"] = write_band_representation_summary(
        dmn_json,
        representation,
        representation_validation;
        overwrite = config.overwrite,
    )

    target_win = read_wannier_win(config.win_file)
    chk = read_wannier_chk(config.chk_file)
    eig = read_wannier_eig(config.eig_file)
    mmn_dimensions = _read_gauge_aware_mmn_dimensions(config.mmn_file)
    model = read_wannier_tb(config.tb_file)
    dimensions_ok =
        target_win.num_wannier == chk.num_orbitals == model.num_orbitals &&
        target_win.num_bands == chk.num_bands == eig.num_bands == mmn_dimensions.num_bands &&
        target_win.mp_grid == chk.mp_grid &&
        chk.num_kpts == eig.num_kpts == mmn_dimensions.num_kpoints &&
        size(representation.energies_ev) == size(eig.data) &&
        representation.mp_grid == chk.mp_grid
    lattice_ok =
        maximum(abs, target_win.lattice - chk.real_lattice) <= 1.0e-8 &&
        maximum(abs, model.lattice - chk.real_lattice) <= 1.0e-8 &&
        maximum(abs, representation.real_lattice - chk.real_lattice) <= 1.0e-7
    if !(dimensions_ok && lattice_ok && target_win.spinors == representation.spinor)
        push!(
            diagnostics,
            "WIN/EIG/MMN/CHK/TB/representation dimensions, lattice, mesh, or spinor convention disagree",
        )
        return _publish_gauge_aware_status(
            config,
            FAILED_INPUT_PROVENANCE,
            artifacts,
            metrics,
            diagnostics,
            threshold_events,
        )
    end
    representation_to_chk = try
        _match_gauge_aware_kpoints(representation.kpoints_fractional, chk.kpt_red)
    catch exception
        push!(diagnostics, sprint(showerror, exception))
        return _publish_gauge_aware_status(
            config,
            FAILED_INPUT_PROVENANCE,
            artifacts,
            metrics,
            diagnostics,
            threshold_events,
        )
    end
    artifacts["kpoint_permutation_tsv"] =
        _write_gauge_aware_kpoint_permutation(config, representation, chk, representation_to_chk)

    actual = _build_actual_wannier_sewing(representation, chk, representation_to_chk)
    artifacts["actual_wannier_sewing_tsv"] =
        _write_actual_sewing_analysis(config, actual, representation.operations)
    metrics["chk_semiunitarity_opnorm"] = actual.maximum_semiunitarity
    metrics["subspace_closure_opnorm"] = actual.maximum_closure
    metrics["subspace_closure_rms"] = actual.closure_rms
    metrics["wannier_sewing_unitarity_opnorm"] = actual.maximum_unitarity
    metrics["wannier_sewing_group_law_opnorm"] = maximum(actual.maximum_group_law_residuals)
    unitary_indices = findall(operation -> !operation.antiunitary, representation.operations)
    antiunitary_indices = findall(operation -> operation.antiunitary, representation.operations)
    metrics["subspace_closure_unitary_opnorm"] =
        isempty(unitary_indices) ? 0.0 : maximum(@view actual.closure_residuals[unitary_indices, :])
    metrics["subspace_closure_antiunitary_opnorm"] =
        isempty(antiunitary_indices) ? 0.0 :
        maximum(@view actual.closure_residuals[antiunitary_indices, :])
    metrics["wannier_sewing_unitarity_unitary_opnorm"] =
        isempty(unitary_indices) ? 0.0 :
        maximum(@view actual.unitarity_residuals[unitary_indices, :])
    metrics["wannier_sewing_unitarity_antiunitary_opnorm"] =
        isempty(antiunitary_indices) ? 0.0 :
        maximum(@view actual.unitarity_residuals[antiunitary_indices, :])
    worst_semiunitarity_kpoint = argmax(actual.semiunitarity_residuals)
    worst_block =
        actual.block_residuals[argmax(getproperty.(actual.block_residuals, :closure_opnorm))]
    worst_group_combination = argmax(collect(actual.maximum_group_law_residuals))
    worst_group = actual.worst_group[worst_group_combination]
    closure_passed = all((
        _record_gauge_aware_threshold!(
            threshold_events,
            diagnostics,
            :wannier_sewing,
            "chk_semiunitarity_opnorm",
            actual.maximum_semiunitarity,
            config.thresholds.chk_semiunitarity;
            kpoint = worst_semiunitarity_kpoint,
        ),
        _record_gauge_aware_threshold!(
            threshold_events,
            diagnostics,
            :wannier_sewing,
            "subspace_closure_opnorm",
            actual.maximum_closure,
            config.thresholds.subspace_closure;
            operation = actual.worst_closure.operation,
            kpoint = actual.worst_closure.source,
            band_block = worst_block.block_label,
            context = "target_kpoint=$(actual.worst_closure.target)",
        ),
        _record_gauge_aware_threshold!(
            threshold_events,
            diagnostics,
            :wannier_sewing,
            "wannier_sewing_unitarity_opnorm",
            actual.maximum_unitarity,
            config.thresholds.wannier_sewing_unitarity;
            operation = actual.worst_unitarity.operation,
            kpoint = actual.worst_unitarity.source,
            context = "target_kpoint=$(actual.worst_unitarity.target)",
        ),
        _record_gauge_aware_threshold!(
            threshold_events,
            diagnostics,
            :wannier_sewing,
            "wannier_sewing_group_law_opnorm",
            maximum(actual.maximum_group_law_residuals),
            config.thresholds.group_law_absolute;
            operation = worst_group.left,
            kpoint = worst_group.source,
            context = "right_operation=$(worst_group.right), combination=$(worst_group_combination)",
        ),
    ))
    if _gauge_aware_fail_stop(config, closure_passed)
        return _publish_gauge_aware_status(
            config,
            FAILED_INPUT_SUBSPACE_NOT_CLOSED,
            artifacts,
            metrics,
            diagnostics,
            threshold_events,
        )
    end

    raw_hamiltonian_q =
        _gauge_aware_r_to_q(model.hamiltonian_r, model.r_vectors, model.r_degeneracies, chk.kpt_red)
    eig_hamiltonian_q = zeros(ComplexF64, chk.num_orbitals, chk.num_orbitals, chk.num_kpts)
    for kpoint in 1:chk.num_kpts
        gauge = @view chk.v_matrix[:, :, kpoint]
        eig_hamiltonian_q[:, :, kpoint] .= gauge' * Diagonal(@view(eig.data[:, kpoint])) * gauge
    end
    metrics["raw_tb_vs_chk_eig_matrix_max_ev"] = maximum(abs, raw_hamiltonian_q - eig_hamiltonian_q)
    metrics["raw_hamiltonian_hermiticity_max_ev"] = _matrix_field_hermiticity(raw_hamiltonian_q)
    input_unitary, input_antiunitary = _hamiltonian_covariance_residuals(
        raw_hamiltonian_q,
        actual.sewing,
        actual.operation_map,
        representation.operations,
    )
    metrics["raw_hamiltonian_unitary_covariance_max_ev"] = input_unitary
    metrics["raw_hamiltonian_antiunitary_covariance_max_ev"] = input_antiunitary
    symmetrized_hamiltonian_q = _project_gauge_aware_hamiltonian(
        raw_hamiltonian_q,
        actual.sewing,
        actual.operation_map,
        representation.operations,
    )
    all(isfinite, symmetrized_hamiltonian_q) || begin
        push!(diagnostics, "symmetrized Hamiltonian contains non-finite values")
        return _publish_gauge_aware_status(
            config,
            FAILED_BAND_REPRESENTATION,
            artifacts,
            metrics,
            diagnostics,
            threshold_events,
        )
    end
    repeated_hamiltonian_q = _project_gauge_aware_hamiltonian(
        symmetrized_hamiltonian_q,
        actual.sewing,
        actual.operation_map,
        representation.operations,
    )
    metrics["hamiltonian_idempotence_max_ev"] =
        maximum(abs, repeated_hamiltonian_q - symmetrized_hamiltonian_q)
    metrics["sym_hamiltonian_hermiticity_max_ev"] =
        _matrix_field_hermiticity(symmetrized_hamiltonian_q)
    output_unitary, output_antiunitary = _hamiltonian_covariance_residuals(
        symmetrized_hamiltonian_q,
        actual.sewing,
        actual.operation_map,
        representation.operations,
    )
    metrics["sym_hamiltonian_unitary_covariance_max_ev"] = output_unitary
    metrics["sym_hamiltonian_antiunitary_covariance_max_ev"] = output_antiunitary
    symmetrized_hamiltonian_r, hamiltonian_roundtrip = _gauge_aware_q_to_input_replicas(
        symmetrized_hamiltonian_q,
        chk,
        model.r_vectors,
        model.r_degeneracies,
    )
    metrics["hamiltonian_fourier_roundtrip_max_ev"] = hamiltonian_roundtrip
    mp_max, mp_rms = _band_difference_metrics(raw_hamiltonian_q, symmetrized_hamiltonian_q)
    metrics["raw_to_c00_mp_band_max_ev"] = mp_max
    metrics["raw_to_c00_mp_band_rms_ev"] = mp_rms
    path = _ges_validation_path()
    raw_path_q =
        _gauge_aware_r_to_q(model.hamiltonian_r, model.r_vectors, model.r_degeneracies, path)
    sym_path_q =
        _gauge_aware_r_to_q(symmetrized_hamiltonian_r, model.r_vectors, model.r_degeneracies, path)
    path_max, _ = _band_difference_metrics(raw_path_q, sym_path_q)
    metrics["raw_to_c00_path_band_max_ev"] = path_max
    hamiltonian_passed = all((
        _record_gauge_aware_threshold!(
            threshold_events,
            diagnostics,
            :hamiltonian,
            "raw_hamiltonian_hermiticity_max_ev",
            metrics["raw_hamiltonian_hermiticity_max_ev"],
            config.thresholds.fourier_roundtrip,
        ),
        _record_gauge_aware_threshold!(
            threshold_events,
            diagnostics,
            :hamiltonian,
            "sym_hamiltonian_hermiticity_max_ev",
            metrics["sym_hamiltonian_hermiticity_max_ev"],
            config.thresholds.fourier_roundtrip,
        ),
        _record_gauge_aware_threshold!(
            threshold_events,
            diagnostics,
            :hamiltonian,
            "hamiltonian_idempotence_max_ev",
            metrics["hamiltonian_idempotence_max_ev"],
            config.thresholds.hamiltonian_idempotence,
        ),
        _record_gauge_aware_threshold!(
            threshold_events,
            diagnostics,
            :hamiltonian,
            "sym_hamiltonian_unitary_covariance_max_ev",
            output_unitary,
            config.thresholds.hamiltonian_idempotence,
        ),
        _record_gauge_aware_threshold!(
            threshold_events,
            diagnostics,
            :hamiltonian,
            "sym_hamiltonian_antiunitary_covariance_max_ev",
            output_antiunitary,
            config.thresholds.hamiltonian_idempotence,
        ),
        _record_gauge_aware_threshold!(
            threshold_events,
            diagnostics,
            :hamiltonian,
            "hamiltonian_fourier_roundtrip_max_ev",
            hamiltonian_roundtrip,
            config.thresholds.fourier_roundtrip,
        ),
        _record_gauge_aware_threshold!(
            threshold_events,
            diagnostics,
            :hamiltonian,
            "raw_to_c00_mp_band_max_ev",
            mp_max,
            config.thresholds.mp_band_max_ev,
        ),
        _record_gauge_aware_threshold!(
            threshold_events,
            diagnostics,
            :hamiltonian,
            "raw_to_c00_mp_band_rms_ev",
            mp_rms,
            config.thresholds.mp_band_rms_ev,
        ),
        _record_gauge_aware_threshold!(
            threshold_events,
            diagnostics,
            :hamiltonian,
            "raw_to_c00_path_band_max_ev",
            path_max,
            config.thresholds.path_band_max_ev,
        ),
    ))
    if _gauge_aware_fail_stop(config, hamiltonian_passed)
        return _publish_gauge_aware_status(
            config,
            FAILED_PHYSICAL_BAND_PRESERVATION,
            artifacts,
            metrics,
            diagnostics,
            threshold_events,
        )
    end
    hamiltonian_only = WannierHR(
        model.num_orbitals,
        model.num_r_vectors,
        model.r_degeneracies,
        model.r_vectors,
        symmetrized_hamiltonian_r,
    )
    hr_file = joinpath(config.output_root, "outputs", "C00", "wannier90_sym_hr.dat")
    write_wannier_hr(hr_file, hamiltonian_only; overwrite = config.overwrite)
    artifacts["c00_hr"] = hr_file
    if !config.complete_position
        push!(diagnostics, "Hamiltonian gates passed; position stage was explicitly deferred")
        return _publish_gauge_aware_status(
            config,
            HOLD_POSITION_PENDING,
            artifacts,
            metrics,
            diagnostics,
            threshold_events,
        )
    end

    mmn = read_wannier_mmn(config.mmn_file)
    weights = _gauge_aware_mmn_weights(chk, mmn)
    raw_links = _wannier_gauge_links(chk, mmn)
    raw_position_q =
        _position_from_wannier_links(raw_links, chk, mmn, weights, chk.wannier_centers_cart)
    input_position_q =
        _gauge_aware_r_to_q(model.position_r, model.r_vectors, model.r_degeneracies, chk.kpt_red)
    metrics["raw_mmn_to_tb_position_max_angstrom"] = maximum(abs, raw_position_q - input_position_q)
    raw_position_passed = _record_gauge_aware_threshold!(
        threshold_events,
        diagnostics,
        :position_input,
        "raw_mmn_to_tb_position_max_angstrom",
        metrics["raw_mmn_to_tb_position_max_angstrom"],
        config.thresholds.raw_position_angstrom,
    )
    if _gauge_aware_fail_stop(config, raw_position_passed)
        return _publish_gauge_aware_status(
            config,
            FAILED_INPUT_PROVENANCE,
            artifacts,
            metrics,
            diagnostics,
            threshold_events,
        )
    end
    edge_map = _gauge_aware_edge_map(chk, mmn, actual.operation_map, representation.operations)
    symmetrized_links = _project_gauge_aware_links(
        raw_links,
        mmn,
        actual.sewing,
        actual.operation_map,
        edge_map,
        representation.operations,
    )
    repeated_links = _project_gauge_aware_links(
        symmetrized_links,
        mmn,
        actual.sewing,
        actual.operation_map,
        edge_map,
        representation.operations,
    )
    metrics["position_link_idempotence_max"] = maximum(abs, repeated_links - symmetrized_links)
    symmetrized_position_q =
        _position_from_wannier_links(symmetrized_links, chk, mmn, weights, chk.wannier_centers_cart)
    repeated_position_q =
        _position_from_wannier_links(repeated_links, chk, mmn, weights, chk.wannier_centers_cart)
    metrics["position_covariance_max_angstrom"] =
        maximum(abs, repeated_position_q - symmetrized_position_q)
    symmetrized_position_r, position_roundtrip = _gauge_aware_q_to_input_replicas(
        symmetrized_position_q,
        chk,
        model.r_vectors,
        model.r_degeneracies,
    )
    metrics["position_fourier_roundtrip_max_angstrom"] = position_roundtrip
    all(isfinite, symmetrized_position_q) && all(isfinite, symmetrized_position_r) || begin
        push!(diagnostics, "symmetrized position matrices contain non-finite values")
        return _publish_gauge_aware_status(
            config,
            FAILED_POSITION_VALIDATION,
            artifacts,
            metrics,
            diagnostics,
            threshold_events,
        )
    end
    projected_home_index = only(
        findall(index -> all(iszero, @view(model.r_vectors[:, index])), axes(model.r_vectors, 2)),
    )
    projected_centers = zeros(Float64, chk.num_orbitals, 3)
    for wannier in 1:chk.num_orbitals, direction in 1:3
        projected_centers[wannier, direction] =
            real(symmetrized_position_r[wannier, wannier, direction, projected_home_index])
    end
    position_passed = all((
        _record_gauge_aware_threshold!(
            threshold_events,
            diagnostics,
            :position,
            "position_link_idempotence_max",
            metrics["position_link_idempotence_max"],
            config.thresholds.fourier_roundtrip,
        ),
        _record_gauge_aware_threshold!(
            threshold_events,
            diagnostics,
            :position,
            "position_covariance_max_angstrom",
            metrics["position_covariance_max_angstrom"],
            config.thresholds.position_covariance_angstrom,
        ),
        _record_gauge_aware_threshold!(
            threshold_events,
            diagnostics,
            :position,
            "position_fourier_roundtrip_max_angstrom",
            position_roundtrip,
            config.thresholds.position_roundtrip_angstrom,
        ),
    ))
    if _gauge_aware_fail_stop(config, position_passed)
        return _publish_gauge_aware_status(
            config,
            FAILED_POSITION_VALIDATION,
            artifacts,
            metrics,
            diagnostics,
            threshold_events,
        )
    end
    materialized = Dict{Symbol, Any}()
    for variant in config.materialization_variants
        variant_result = _materialize_gauge_aware_variant(
            config,
            variant,
            model,
            chk,
            symmetrized_hamiltonian_q,
            symmetrized_position_q,
            symmetrized_hamiltonian_r,
            symmetrized_position_r,
            projected_centers,
        )
        label = lowercase(String(variant))
        stage = Symbol(label * "_materialization")
        metrics["$(label)_hamiltonian_roundtrip_max_ev"] = variant_result.hamiltonian_roundtrip
        metrics["$(label)_position_roundtrip_max_angstrom"] = variant_result.position_roundtrip
        metrics["$(label)_wcc_displacement_max_angstrom"] = maximum(
            norm(
                @view(variant_result.centers_cartesian[index, :]) -
                @view(chk.wannier_centers_cart[index, :]),
            ) for index in 1:chk.num_orbitals
        )
        hamiltonian_materialization_passed = _record_gauge_aware_threshold!(
            threshold_events,
            diagnostics,
            stage,
            "$(label)_hamiltonian_roundtrip_max_ev",
            variant_result.hamiltonian_roundtrip,
            config.thresholds.fourier_roundtrip,
        )
        position_materialization_passed = _record_gauge_aware_threshold!(
            threshold_events,
            diagnostics,
            stage,
            "$(label)_position_roundtrip_max_angstrom",
            variant_result.position_roundtrip,
            config.thresholds.position_roundtrip_angstrom,
        )
        center_serialization_error = maximum(
            abs,
            _gauge_aware_tb_centers(variant_result.model) - variant_result.centers_cartesian,
        )
        metrics["$(label)_wcc_serialization_max_angstrom"] = center_serialization_error
        center_materialization_passed = _record_gauge_aware_threshold!(
            threshold_events,
            diagnostics,
            stage,
            "$(label)_wcc_serialization_max_angstrom",
            center_serialization_error,
            config.thresholds.raw_position_angstrom,
        )
        if _gauge_aware_fail_stop(
            config,
            hamiltonian_materialization_passed &&
            position_materialization_passed &&
            center_materialization_passed,
        )
            return _publish_gauge_aware_status(
                config,
                FAILED_POSITION_VALIDATION,
                artifacts,
                metrics,
                diagnostics,
                threshold_events,
            )
        end

        output_directory = joinpath(config.output_root, "outputs", String(variant))
        tb_file = joinpath(output_directory, "wannier90_sym_tb.dat")
        write_wannier_tb(tb_file, variant_result.model; overwrite = config.overwrite)
        roundtrip = read_wannier_tb(tb_file)
        roundtrip.r_vectors == variant_result.model.r_vectors ||
            throw(ArgumentError("written $(variant) TB R support failed round-trip validation"))
        roundtrip.r_degeneracies == variant_result.model.r_degeneracies ||
            throw(ArgumentError("written $(variant) TB degeneracies failed round-trip validation"))
        maximum(abs, roundtrip.hamiltonian_r - variant_result.model.hamiltonian_r) <= 1.0e-12 ||
            throw(ArgumentError("written $(variant) TB Hamiltonian failed round-trip validation"))
        maximum(abs, roundtrip.position_r - variant_result.model.position_r) <= 1.0e-12 ||
            throw(ArgumentError("written $(variant) TB position failed round-trip validation"))
        artifacts["$(label)_tb"] = tb_file

        variant_hr = WannierHR(
            roundtrip.num_orbitals,
            roundtrip.num_r_vectors,
            roundtrip.r_degeneracies,
            roundtrip.r_vectors,
            roundtrip.hamiltonian_r,
        )
        variant_hr_file = joinpath(output_directory, "wannier90_sym_hr.dat")
        if !(variant == :C00 && isfile(variant_hr_file))
            write_wannier_hr(variant_hr_file, variant_hr; overwrite = config.overwrite)
        end
        hr_roundtrip = read_wannier_hr(variant_hr_file)
        hr_roundtrip.r_vectors == roundtrip.r_vectors ||
            throw(ArgumentError("written $(variant) HR support differs from paired TB"))
        hr_roundtrip.r_degeneracies == roundtrip.r_degeneracies ||
            throw(ArgumentError("written $(variant) HR degeneracies differ from paired TB"))
        maximum(abs, hr_roundtrip.hamiltonian_r - roundtrip.hamiltonian_r) <= 1.0e-12 ||
            throw(ArgumentError("written $(variant) HR Hamiltonian differs from paired TB"))
        artifacts["$(label)_hr"] = variant_hr_file
        materialized[variant] = merge(variant_result, (; tb_file))
    end

    for variant in config.materialization_variants
        variant_result = materialized[variant]
        label = lowercase(String(variant))
        bundle_file = joinpath(config.output_root, "outputs", String(variant), "wannierNLQG_tb.h5")
        artifacts["$(label)_operator_bundle_hdf5"] = _write_gauge_aware_operator_bundle(
            config,
            variant_result.tb_file,
            bundle_file,
            chk.wannier_centers_cart,
            variant_result.center_policy,
            variant_result.replica_policy,
            threshold_events,
            source_hashes,
        )
    end
    final_status = all(event -> event.passed, threshold_events) ? PASS : PASS_WITH_WARNINGS
    return _publish_gauge_aware_status(
        config,
        final_status,
        artifacts,
        metrics,
        diagnostics,
        threshold_events,
    )
end
