"""
Symmetrize the complete input-inferred real-space operator profile in one context.

The workflow reads structure only from WIN, projects Hamiltonian/position first,
then derivative and spin families in registry order, and writes one Packed HDF5
v5 model bundle in the serialized-degeneracy convention. Input files are
read-only. No SCF k mesh is consumed and no legacy cache is created.
"""
function symmetrize_wannier_operators(config::SymmetrizationConfig)
    paths = _validate_symmetrization_config(config)
    input_evidence_before = _input_file_evidence(paths)
    source_tree_digest = _source_tree_sha256()
    context = _build_symmetrization_context(config, paths)
    auxiliary = _read_auxiliary_operator_inputs(paths)
    tb_result = _symmetrize_tight_binding_operators(context, config)
    checkpoint_center_tolerance = max(config.wannier_center_tolerance, config.projection_tolerance)
    checkpoint_center_max_abs = if auxiliary.chk === nothing
        nothing
    else
        _validate_checkpoint_wannier_centers(
            auxiliary.chk,
            tb_result.center_geometry,
            checkpoint_center_tolerance,
        )
    end
    needs_pair_transform = !isempty(paths.families.derivative) || !isempty(paths.families.spin)
    transform_plan = if needs_pair_transform
        auxiliary.chk === nothing && error("validated checkpoint input is absent")
        WannierPairWignerSeitzTransformPlan(
            auxiliary.chk,
            context.model.r_vectors;
            wigner_seitz_tolerance = config.wigner_seitz_tolerance,
            search_size = config.wigner_seitz_search_size,
            image_policy = :input,
            wannier_centers_fractional = tb_result.center_geometry.final_fractional,
        )
    else
        nothing
    end
    derivative_result = _symmetrize_wannier_derivative_operators(
        context,
        tb_result,
        auxiliary,
        transform_plan,
        paths.families.derivative,
        config,
    )
    spin_result = _symmetrize_spin_family(
        context,
        tb_result,
        auxiliary,
        transform_plan,
        paths.families.spin,
        config,
    )

    validation = copy(tb_result.validation)
    merge!(validation, derivative_result.validation)
    merge!(validation, spin_result.validation)

    normalized_operators = copy(tb_result.operators)
    merge!(normalized_operators, derivative_result.operators)
    merge!(normalized_operators, spin_result.operators)
    common_r_vectors = _common_result_r_vectors([
        RealSpaceSymmetrizationResult(
            operator,
            size(operator.r_vectors, 2),
            zeros(Int, 3, 0),
            context.plan.operation_indices,
        ) for operator in values(normalized_operators)
    ])
    input_degeneracies = _output_degeneracies(context.model, common_r_vectors)
    replica_result = apply_real_space_replica_policy(
        normalized_operators,
        input_degeneracies,
        context.model.lattice,
        something(context.input.mp_grid),
        tb_result.center_geometry.final_fractional,
        config.real_space_replica_policy;
        tolerance = config.wigner_seitz_tolerance,
        search_size = config.wigner_seitz_search_size,
    )
    output_model = _tight_binding_model_from_normalized_operators(
        context.model.lattice,
        replica_result.operators,
        replica_result.degeneracies,
    )

    write_wannier_tb(paths.output_tb, output_model; overwrite = config.overwrite)
    tb_roundtrip = read_wannier_tb(paths.output_tb)
    maximum(abs, tb_roundtrip.hamiltonian_r .- output_model.hamiltonian_r; init = 0.0) <= 1.0e-12 ||
        throw(ArgumentError("written TB Hamiltonian failed round-trip validation"))
    maximum(abs, tb_roundtrip.position_r .- output_model.position_r; init = 0.0) <= 1.0e-12 ||
        throw(ArgumentError("written TB position matrix failed round-trip validation"))

    serialized_operators = Dict{RealSpaceOperatorKind, RealSpaceOperator}()
    for (kind, operator) in replica_result.operators
        serialized_values = if kind == REAL_SPACE_HAMILTONIAN
            copy(tb_roundtrip.hamiltonian_r)
        elseif kind == REAL_SPACE_POSITION
            copy(tb_roundtrip.position_r)
        else
            _serialized_operator_values(operator, tb_roundtrip.r_degeneracies)
        end
        serialized_operators[kind] =
            RealSpaceOperator(operator.spec, operator.r_vectors, serialized_values)
    end
    inventory = validate_operator_profile(paths.families.profile, keys(serialized_operators))
    tb_digest = _sha256_file(paths.output_tb)
    validation_json = _json_validation(validation)
    durable_position = _normalized_real_space_operator(
        POSITION_SYMMETRY_SPEC,
        tb_roundtrip,
        tb_roundtrip.position_r,
    )
    durable_final_centers_cartesian = _position_wannier_centers_cartesian(durable_position)
    durable_final_centers_fractional =
        _center_rows_cartesian_to_fractional(durable_final_centers_cartesian, tb_roundtrip.lattice)
    geometry_metadata = _geometry_metadata(
        tb_result.center_geometry,
        durable_final_centers_cartesian,
        durable_final_centers_fractional,
        replica_result,
        context,
        config,
        checkpoint_center_max_abs,
        checkpoint_center_tolerance,
    )
    operator_qualification_hold = paths.families.profile in (:hamiltonian_position_spin, :full)
    if operator_qualification_hold
        geometry_metadata["center_geometry_production_eligible"] =
            geometry_metadata["production_eligible"]
        geometry_metadata["production_eligible"] = false
        geometry_metadata["model_status"] = "diagnostic_operator_qualification_not_provided"
        geometry_metadata["qualification_hold"] = "spin-bearing Symmetrization output has no independent source/gauge qualification"
    end
    symmetry_metadata = Dict(
        "symmetrization_status" => "applied",
        "include_time_reversal" => config.include_time_reversal,
        "selected_operation_count" => length(context.plan.operation_indices),
        "operation_indices" => context.plan.operation_indices,
        "symmetry_tolerance" => config.symmetry_tolerance,
        "projection_tolerance" => config.projection_tolerance,
        "representation_tolerance" => config.representation_tolerance,
        "support_tolerance" => config.support_tolerance,
        "wigner_seitz_tolerance" => config.wigner_seitz_tolerance,
        "wigner_seitz_search_size" => config.wigner_seitz_search_size,
        "roundtrip_tolerance" => config.roundtrip_tolerance,
        "covariance_tolerance" => config.covariance_tolerance,
        "idempotence_tolerance" => config.idempotence_tolerance,
    )
    provenance = Dict(
        "wanniernlqg_version" => string(Base.pkgversion(WannierNLQG)),
        "source_tree_sha256" => source_tree_digest,
        "julia_version" => string(VERSION),
        "hdf5_jl_version" => string(Base.pkgversion(HDF5)),
        "spglib_version" => symmetry_detection_backend_provenance().version,
        "input_files" => input_evidence_before,
    )
    if operator_qualification_hold
        provenance["operator_qualification_status"] = "DIAGNOSTIC_ONLY"
        provenance["operator_qualification_reason"] = "QUALIFICATION_NOT_PROVIDED"
    end
    if !isempty(spin_result.roundtrip_residuals)
        provenance["operator_profile_assembly_algorithm_version"] =
            SYMMETRIZATION_OPERATOR_PROFILE_ASSEMBLY_ALGORITHM_VERSION
        provenance["pair_wigner_seitz_roundtrip_policy"] =
            SYMMETRIZATION_PAIR_WIGNER_SEITZ_STORAGE_POLICY
        provenance["pair_wigner_seitz_roundtrip_tolerance"] = config.roundtrip_tolerance
        provenance["pair_wigner_seitz_roundtrip_residuals"] = spin_result.roundtrip_residuals
    end
    write_real_space_operator_bundle(
        paths.operator_bundle,
        context.input.lattice,
        tb_roundtrip.r_degeneracies,
        serialized_operators;
        profile = paths.families.profile,
        overwrite = config.overwrite,
        paired_tb_sha256 = tb_digest,
        provenance = provenance,
        symmetry = symmetry_metadata,
        geometry = geometry_metadata,
        diagnostics = Dict("operator_validation" => validation_json),
    )
    roundtrip = read_real_space_operator_bundle(paths.operator_bundle)
    roundtrip.manifest.profile == paths.families.profile ||
        throw(ArgumentError("operator-bundle profile round-trip validation failed"))
    roundtrip.manifest.inventory == inventory ||
        throw(ArgumentError("operator-bundle inventory round-trip validation failed"))
    for kind in inventory
        difference =
            _operator_maximum_difference(serialized_operators[kind], roundtrip.operators[kind])
        difference == 0.0 || throw(
            ArgumentError(
                "$(operator_storage_name(kind)) Packed HDF5 round-trip must be bit exact; max_abs=$(difference)",
            ),
        )
    end
    roundtrip.operators[REAL_SPACE_HAMILTONIAN].data == tb_roundtrip.hamiltonian_r ||
        throw(ArgumentError("HDF5 Hamiltonian differs from paired TB readback"))
    roundtrip.operators[REAL_SPACE_POSITION].data == tb_roundtrip.position_r ||
        throw(ArgumentError("HDF5 position differs from paired TB readback"))

    input_evidence_after = _input_file_evidence(paths)
    input_evidence_after == input_evidence_before ||
        throw(ArgumentError("a scientific input changed during symmetrization"))
    bundle_digest = _sha256_file(paths.operator_bundle)
    report_path = _write_symmetrization_report(
        config,
        paths.report,
        Dict(
            "status" => "PASS",
            "wanniernlqg_version" => string(Base.pkgversion(WannierNLQG)),
            "source_tree_sha256" => source_tree_digest,
            "input_win" => context.input.source_path,
            "input_files" => input_evidence_before,
            "output_tb" => paths.output_tb,
            "real_space_operator_bundle" => paths.operator_bundle,
            "output_tb_sha256" => tb_digest,
            "real_space_operator_bundle_sha256" => bundle_digest,
            "operator_profile" => String(paths.families.profile),
            "operator_inventory" => operator_storage_name.(inventory),
            "selected_operation_count" => length(context.plan.operation_indices),
            "operation_indices" => context.plan.operation_indices,
            "original_num_r_vectors" => context.model.num_r_vectors,
            "output_num_r_vectors" => output_model.num_r_vectors,
            "generated_num_r_vectors" => tb_result.generated_num_r_vectors,
            "validation" => validation_json,
            "geometry" => geometry_metadata,
            "hdf5_read_mode" => String(roundtrip.read_mode),
        ),
    )
    _write_sha256sums(
        paths.checksums,
        (paths.output_tb, paths.operator_bundle, report_path);
        overwrite = config.overwrite,
    )
    return SymmetrizationResult(
        paths.output_tb,
        paths.operator_bundle,
        report_path,
        paths.families.profile,
        inventory,
        validation,
    )
end
