isdefined(@__MODULE__, :_profile_modified_config) ||
    include(joinpath(@__DIR__, "WannierOperatorProfileTestSupport.jl"))

@testset "final-projector matrices and endpoint leakage are Wannier-gauge invariant" begin
    extension = first(PROFILE_W._load_wannierization_extension!()).OperatorExport
    v_matrix = zeros(ComplexF64, 3, 2, 2)
    v_matrix[:, :, 1] .= Matrix(qr(ComplexF64[1 0; 0 1; 1 1im]).Q)[:, 1:2]
    v_matrix[:, :, 2] .= Matrix(qr(ComplexF64[1 1im; 1 0; 0 1]).Q)[:, 1:2]
    rotation = ComplexF64[1 1im; 1im 1] / sqrt(2)
    rotated = similar(v_matrix)
    for kpoint in 1:2
        rotated[:, :, kpoint] .= v_matrix[:, :, kpoint] * rotation
    end
    common = (
        3,
        2,
        2,
        (2, 1, 1),
        [0.0 0.0 0.0; 0.5 0.0 0.0],
        Matrix{Float64}(I, 3, 3),
        2pi .* Matrix{Float64}(I, 3, 3),
        zeros(2, 3),
    )
    chk = PROFILE_IO.WannierCHK(common..., v_matrix)
    rotated_chk = PROFILE_IO.WannierCHK(common..., rotated)
    mmn_data = zeros(ComplexF64, 3, 3, 1, 2)
    mmn_data[:, :, 1, 1] .= Diagonal(ComplexF64[0.97, 0.91, 0.83])
    mmn_data[:, :, 1, 2] .= ComplexF64[0.92 0.03im 0; -0.03im 0.88 0; 0 0 0.79]
    mmn = PROFILE_IO.WannierMMN(3, 2, 1, mmn_data, reshape([2, 1], 1, 2), zeros(Int, 3, 1, 2))
    # Mathematical gauge invariance replaces the removed content fingerprint.
    for kpoint in 1:chk.num_kpts
        left = chk.v_matrix[:, :, kpoint]
        right = rotated_chk.v_matrix[:, :, kpoint]
        @test isapprox(left * left', right * right'; atol = 5.0e-14, rtol = 0.0)
    end
    @test Base.invokelatest(extension._profile_final_subspace_isometry, chk) <= 5.0e-14
    @test Base.invokelatest(extension._profile_final_subspace_isometry, rotated_chk) <= 5.0e-14
    audit = Base.invokelatest(extension._profile_final_projector_leakage_audit, chk, mmn, 1.0e-6)
    rotated_audit = Base.invokelatest(
        extension._profile_final_projector_leakage_audit,
        rotated_chk,
        mmn,
        1.0e-6,
    )
    for field in ("leakage_maximum", "leakage_p95", "leakage_rms")
        @test isapprox(audit[field], rotated_audit[field]; atol = 5.0e-14, rtol = 0.0)
    end
    @test audit["worst_endpoint"] in ("left", "right")
    @test audit["endpoint_count"] == 4
end

@testset "profile spin family uses pair-dependent Wigner-Seitz support" begin
    extension = first(PROFILE_W._load_wannierization_extension!()).OperatorExport
    kpoints = [0.0 0.0 0.0; 0.5 0.0 0.0]
    centers = [0.0 0.0 0.0; 0.4 0.0 0.0]
    v_matrix = zeros(ComplexF64, 2, 2, 2)
    for kpoint in 1:2
        v_matrix[:, :, kpoint] .= Matrix{ComplexF64}(I, 2, 2)
    end
    chk = PROFILE_IO.WannierCHK(
        2,
        2,
        2,
        (2, 1, 1),
        kpoints,
        Matrix{Float64}(I, 3, 3),
        2.0pi * Matrix{Float64}(I, 3, 3),
        centers,
        v_matrix,
    )
    r_vectors = [
        -1 0 1
        0 0 0
        0 0 0
    ]
    plan = Base.invokelatest(
        WannierNLQG.MatrixElements.WannierPairWignerSeitzTransformPlan,
        chk,
        r_vectors;
        wigner_seitz_tolerance = 1.0e-5,
        search_size = 1,
    )
    spin_q = zeros(ComplexF64, 2, 2, 3, 2)
    spin_q[1, 2, 1, :] .= (1.0, -1.0)
    spin_q[2, 1, 1, :] .= (2.0, -2.0)
    spin_q[1, 1, 1, :] .= (3.0, -3.0)
    model = PROFILE_CORE.TightBindingModel(
        Matrix{Float64}(I, 3, 3),
        2,
        3,
        ones(Int, 3),
        r_vectors,
        zeros(ComplexF64, 2, 2, 3),
        zeros(ComplexF64, 2, 2, 3, 3),
    )
    @test_throws ErrorException WannierNLQG.MatrixElements.spin_velocity_q_to_r(
        spin_q,
        chk,
        model;
        label = "legacy-profile-SPN",
    )
    spin_r, roundtrip =
        Base.invokelatest(extension._profile_spin_q_to_r, spin_q, chk, plan, "profile-SPN")
    @test spin_r[1, 2, 1, :] ≈ ComplexF64[1.0, 0.0, 0.0] atol = 1.0e-15
    @test spin_r[2, 1, 1, :] ≈ ComplexF64[0.0, 0.0, 2.0] atol = 1.0e-15
    @test spin_r[1, 1, 1, :] ≈ ComplexF64[1.5, 0.0, 1.5] atol = 1.0e-15
    @test roundtrip <= 1.0e-12
end

@testset "weighted axial delivery excludes unused symmetric tensor components" begin
    extension = first(PROFILE_W._load_wannierization_extension!()).OperatorExport
    M = WannierNLQG.MatrixElements
    chk = PROFILE_IO.WannierCHK(
        1,
        1,
        2,
        (2, 1, 1),
        [0.0 0.0 0.0; 0.5 0.0 0.0],
        Matrix{Float64}(I, 3, 3),
        2pi * Matrix{Float64}(I, 3, 3),
        zeros(1, 3),
        ones(ComplexF64, 1, 1, 2),
    )
    r_vectors = [-1 0 1; 0 0 0; 0 0 0]
    plan = M.WannierPairWignerSeitzTransformPlan(
        chk,
        r_vectors;
        wigner_seitz_tolerance = 1e-5,
        search_size = 1,
    )
    tensor = zeros(ComplexF64, 1, 1, 3, 3, 2)
    tensor[1, 1, 3, 3, :] .= 1e10
    tensor[1, 1, 1, 2, :] .= im .* [0.25, 0.5]
    tensor[1, 1, 2, 1, :] .= -im .* [0.25, 0.5]
    values_r, full_residual = Base.invokelatest(
        extension._profile_q_to_r,
        tensor,
        chk,
        plan,
        "unused symmetric stress fixture",
    )
    axial_q, _ = M.derive_axial_and_symmetric_derivative_overlaps(tensor)
    axial_r, _ = M.derive_axial_and_symmetric_derivative_overlaps(values_r)
    axial_r = M.hermitianize_real_space_pairs(axial_r, r_vectors)
    actual_residual = M.unit_degeneracy_roundtrip_error(axial_q, axial_r, chk, plan)
    @test full_residual > 1e-8
    @test actual_residual < 1e-12
    @test extension.PROFILE_PAIR_WIGNER_SEITZ_ROUNDTRIP_TOLERANCE == 1e-8
end

@testset "ordinary/native-SAWF/symmetrized-SAWF schema-6 profile matrix" begin
    fixture = standard_export_fixture()
    # Seal the accepted-state fixture with the same topology used by full operator profiles.
    raw_stencil = WannierNLQG.MatrixElements.build_finite_difference_stencil(
        something(fixture.result.wannier_chk),
    )
    profile_mmn_data = zeros(ComplexF64, 2, 2, length(raw_stencil.weights), 2)
    for kpoint in 1:2, neighbor in eachindex(raw_stencil.weights)
        profile_mmn_data[:, :, neighbor, kpoint] .= Matrix{ComplexF64}(I, 2, 2)
    end
    profile_mmn = PROFILE_IO.WannierMMN(
        2,
        2,
        length(raw_stencil.weights),
        profile_mmn_data,
        copy(raw_stencil.neighbors),
        copy(raw_stencil.reciprocal_shifts),
    )
    fixture = standard_export_fixture(; mmn_override = profile_mmn)
    parent_extension = first(PROFILE_W._load_wannierization_extension!())
    extension = parent_extension.OperatorExport
    eligible = parent_extension.WannierizationInternalSupport.updated_wannierization_result(
        fixture.result;
        input_summary = merge(fixture.result.input_summary, Dict("hard_gate_frozen" => "0.0")),
    )
    prepared, quality, _, _, _ =
        Base.invokelatest(extension._prepare_wannierization_tb_state, eligible, fixture.config)
    @test quality == "PASS"
    native = Base.invokelatest(extension._native_authoritative_band_hamiltonian, fixture.eig)
    # This witness cannot silently substitute different explicit frozen states.
    changed_selection = _profile_modified_config(fixture.config; frozen_states = [(1, 2), (2, 2)])
    @test_throws ArgumentError _profile_preparation_scope(changed_selection, fixture.eig)
    for route in (:ordinary, :native_sawf, :symmetrized_sawf)
        mktempdir() do directory
            gauge_hdf5 =
                _profile_write_gauge(directory, route, fixture.eig; target_config = fixture.config)
            source =
                route == :ordinary ? nothing :
                WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
                    joinpath(directory, "gauge-source", "fixture.save");
                    band_range = 1:2,
                    include_time_reversal = false,
                )
            gauge_contract = _profile_gauge_contract(
                parent_extension,
                route,
                2,
                2;
                artifact_path = gauge_hdf5,
                source,
            )
            authority_config = _profile_modified_config(
                fixture.config;
                source,
                wavefunction_gauge_hdf5 = gauge_hdf5,
                authoritative_hamiltonian = route == :symmetrized_sawf ?
                                            PROFILE_W.SymmetrizedDFTHamiltonian() :
                                            PROFILE_W.NativeDFTHamiltonian(),
            )
            authority = Base.invokelatest(
                extension.authoritative_band_hamiltonian,
                authority_config,
                fixture.eig,
            )
            inputs = _profile_write_inputs(
                directory,
                profile_mmn,
                authority,
                gauge_contract,
                parent_extension;
                gauge_hdf5,
                eig = fixture.eig,
                target_config = authority_config,
            )
            if gauge_hdf5 !== nothing
                HDF5.h5open(gauge_hdf5, "r") do handle
                    attrs = HDF5.attributes(handle)
                    @test !haskey(attrs, "status")
                    @test !haskey(attrs, "production_eligible")
                    @test haskey(handle, "qualification_scope/outer_mask")
                    @test haskey(handle, "qualification_scope/frozen_mask")
                    @test Bool.(read(handle["qualification_scope/outer_mask"])) ==
                          inputs.target_contract.qualification_scope.outer_mask
                    @test Bool.(read(handle["qualification_scope/frozen_mask"])) ==
                          inputs.target_contract.qualification_scope.frozen_mask
                end
            end
            profile_mmn = inputs.target_mmn
            source_native =
                parent_extension.PAWMatrixElements._read_augmentation_aware_native_source(
                    inputs.links.source,
                )
            center_fractional = reshape(_profile_plane_wave_packet(1).center, 3, 1)
            center_cartesian =
                transpose(transpose(source_native.structure.lattice) * center_fractional)
            fixture = standard_export_fixture(;
                mmn_override = profile_mmn,
                real_lattice_override = source_native.structure.lattice,
                centers_override = center_cartesian,
                frames_override = profile_packet_target_frames(
                    gauge_contract,
                    profile_mmn.num_kpts,
                ),
            )
            eligible = parent_extension.WannierizationInternalSupport.updated_wannierization_result(
                fixture.result;
                input_summary = merge(
                    fixture.result.input_summary,
                    Dict(
                        "hard_gate_frozen" => "0.0",
                        "numerical_quality" => "VALID_ACCEPTED_STATE",
                    ),
                ),
            )
            prepared, quality, _, _, _ = Base.invokelatest(
                extension._prepare_wannierization_tb_state,
                eligible,
                fixture.config,
            )
            @test quality == "PASS"
            model = Base.invokelatest(
                extension.build_wannier_tight_binding_model,
                prepared,
                authority,
                profile_mmn,
            )
            symmetry_plan = _profile_symmetry_plan(
                route,
                model.num_orbitals;
                source = inputs.links.source,
                centers_fractional = center_fractional,
                spinors = reshape(ComplexF64[1, 0], 2, 1),
                parent = parent_extension,
            )
            target_contract = inputs.target_contract
            full_target = target_contract
            for profile in (:hamiltonian_position, :hamiltonian_position_spin, :full)
                config = _profile_modified_config(
                    fixture.config;
                    profile = profile == :hamiltonian_position_spin ? nothing : profile,
                    operator_tasks = profile == :hamiltonian_position_spin ?
                                     (
                        PROFILE_CORE.OperatorTask(quantity = :zeeman_interband_berry_curvature),
                    ) : (),
                    construction_policy = :standard,
                    authoritative_hamiltonian = route == :symmetrized_sawf ?
                                                PROFILE_W.SymmetrizedDFTHamiltonian() :
                                                PROFILE_W.NativeDFTHamiltonian(),
                    source = source,
                    wavefunction_gauge_hdf5 = gauge_hdf5,
                    mmn_file = inputs.mmn_file,
                    spn_file = inputs.spn_file,
                    spn_provenance_file = inputs.spn_provenance,
                    uiu_file = inputs.uiu_file,
                    uhu_file = inputs.uhu_file,
                    siu_file = inputs.siu_file,
                    shu_file = inputs.shu_file,
                    uiu_provenance_json = inputs.uiu_provenance,
                    uhu_provenance_json = inputs.uhu_provenance,
                    siu_provenance_json = inputs.siu_provenance,
                    shu_provenance_json = inputs.shu_provenance,
                )
                assembly_target = target_contract
                if route == :ordinary && profile == :full
                    factory_eig_file = joinpath(directory, "factory.eig")
                    PROFILE_IO.write_wannier_eig(factory_eig_file, fixture.eig)
                    factory_config = _profile_modified_config(
                        config;
                        eig_file = factory_eig_file,
                        initialization = :random,
                    )
                    factory_target =
                        PROFILE_W.prepare_wannier_operator_target_contract(factory_config)
                    @test factory_target.operator_oracle_mmn_file == abspath(inputs.mmn_file)
                    @test factory_target.solver_mmn_file == abspath(inputs.mmn_file)
                    @test factory_target.gauge_definition == "NOT_APPLICABLE"
                    @test startswith(factory_target.definition, "operator-target-values/2:")

                    distinct_solver_mmn_file = joinpath(directory, "distinct-solver.mmn")
                    distinct_solver_data = copy(profile_mmn.data)
                    distinct_solver_data[1] += 0.125
                    PROFILE_IO.write_wannier_mmn(
                        distinct_solver_mmn_file,
                        PROFILE_IO.WannierMMN(
                            profile_mmn.num_bands,
                            profile_mmn.num_kpts,
                            profile_mmn.num_neighbors,
                            distinct_solver_data,
                            profile_mmn.neighbors,
                            profile_mmn.reciprocal_shifts,
                        ),
                    )
                    distinct_target = Base.invokelatest(
                        extension._wannier_operator_target_contract,
                        factory_config,
                        fixture.eig,
                        profile_mmn,
                        inputs.mmn_file,
                        distinct_solver_mmn_file,
                    )
                    @test distinct_target.operator_oracle_mmn_reference !=
                          distinct_target.solver_mmn_reference
                    @test isnothing(
                        Base.invokelatest(
                            extension._validate_wannier_operator_target_contract,
                            factory_config,
                            fixture.eig,
                            profile_mmn,
                            distinct_target,
                        ),
                    )
                end
                if profile == :full
                    full_target = assembly_target
                    # Generated payloads retain their real target contract. The
                    # distinct-file constructor case above is not a source licence.
                    snapshot_result =
                        _profile_snapshot_result(parent_extension, eligible, fixture, config)
                    @test isnothing(
                        Base.invokelatest(
                            extension._validate_operator_profile_preflight_snapshot,
                            snapshot_result,
                            config,
                        ),
                    )
                    original_uiu_sidecar = read(inputs.uiu_provenance)
                    write(inputs.uiu_provenance, [original_uiu_sidecar; UInt8(' ')])
                    @test_throws ArgumentError Base.invokelatest(
                        extension._validate_operator_profile_preflight_snapshot,
                        snapshot_result,
                        config,
                    )
                    @test_throws ArgumentError Base.invokelatest(
                        extension._export_wannierization_tb,
                        snapshot_result,
                        fixture.eig,
                        profile_mmn,
                        config,
                        nothing,
                        symmetry_plan;
                        operator_target_contract = assembly_target,
                    )
                    write(inputs.uiu_provenance, original_uiu_sidecar)
                    original_spn = read(inputs.spn_file)
                    write(inputs.spn_file, [original_spn; UInt8(0)])
                    @test_throws ArgumentError Base.invokelatest(
                        extension._validate_operator_profile_preflight_snapshot,
                        snapshot_result,
                        config,
                    )
                    write(inputs.spn_file, original_spn)
                end
                operators, provenance = if profile == :hamiltonian_position
                    Base.invokelatest(
                        extension._assemble_wannierization_operator_profile,
                        model,
                        prepared,
                        profile_mmn,
                        config,
                        authority,
                        symmetry_plan,
                    )
                else
                    Base.invokelatest(
                        extension._assemble_wannierization_operator_profile_from_qualified_sources,
                        model,
                        prepared,
                        profile_mmn,
                        config,
                        authority,
                        symmetry_plan,
                        gauge_contract,
                        inputs.spn_attestation,
                        0.0,
                        assembly_target,
                    )
                end
                expected = collect(PROFILE_IO.OPERATOR_PROFILE_INVENTORIES[profile])
                @test Set(keys(operators)) == Set(expected)
                @test all(operator -> operator.r_vectors == model.r_vectors, values(operators))
                operator_qualification = provenance["operator_qualification"]
                spin_family = operator_qualification["families"]["spin"]
                # Construction records are in-memory observations, not scientific
                # qualification restored into a mathematical model file.
                @test operator_qualification["construction_policy"] == "standard"
                @test Set(keys(operator_qualification["operators"])) ==
                      Set(PROFILE_CORE.real_space_operator_name.(expected))
                @test spin_family["route"] ==
                      (profile == :hamiltonian_position ? "not_applicable" : String(route))
                @test spin_family["pair_wigner_seitz_roundtrip_status"] ==
                      (profile == :hamiltonian_position ? "NOT_APPLICABLE" : "PASS")
                if profile != :hamiltonian_position
                    @test spin_family["pair_wigner_seitz_transform_algorithm"] ==
                          "PAIR_DEPENDENT_WIGNER_SEITZ_Q_TO_R"
                    @test spin_family["pair_wigner_seitz_storage_policy"] ==
                          "PAIR_DEPENDENT_MINIMUM_DISTANCE_UNIT_DEGENERACY"
                    @test spin_family["pair_wigner_seitz_roundtrip_maximum"] <= 1.0e-8
                    @test spin_family["pair_wigner_seitz_roundtrip_worst_operator"] in
                          keys(provenance["pair_wigner_seitz_roundtrip_residuals"])
                end
                finite_band_family =
                    provenance["operator_qualification"]["families"]["finite_band_galerkin"]
                @test finite_band_family["overall"] ==
                      (profile == :full ? "RISK_RECORDED_NOT_CONVERGED" : "NOT_APPLICABLE")
                output = joinpath(directory, "$(route)-$(profile).h5")
                geometry = _profile_geometry(model)
                eligibility = _profile_model_semantics(authority)
                diagnostics = Dict{String, Any}()
                if profile == :full || route == :symmetrized_sawf
                    geometry["production_eligible"] = false
                    eligibility["production_eligible"] = false
                    eligibility["scoped_production_eligible"] = false
                end
                if route == :symmetrized_sawf
                    retained_records = [
                        Dict(
                            "code" => "FOCUSED_DIAGNOSTIC_GAUGE",
                            "severity" => "error",
                            "message" => "retained diagnostic gauge quality failure",
                            "context" => Dict(
                                "gate_result" => "FAIL",
                                "action" => "CONTINUE_STANDARD",
                                "stage" => "operator_profile_assembly",
                            ),
                        ),
                    ]
                    merge!(
                        eligibility,
                        Dict(
                            "construction_policy" => "standard",
                            "construction_gate_records_json" =>
                                String(JSON3.write(retained_records)),
                            "quality_review_recommended" => true,
                            "construction_quality_failed" => true,
                            "model_availability" => "AVAILABLE_WITH_QUALITY_WARNINGS",
                            "quality_review_recommended" => true,
                            "production_eligible" => false,
                        ),
                    )
                    diagnostics = copy(eligibility)
                end
                PROFILE_IO.write_real_space_operator_bundle(
                    output,
                    model.lattice,
                    model.r_degeneracies,
                    operators;
                    profile,
                    overwrite = true,
                    provenance = merge(
                        Dict(
                            "route" => String(route),
                            "authoritative_hamiltonian" => authority.authority,
                            "authoritative_hamiltonian_definition" => authority.definition,
                        ),
                        provenance,
                    ),
                    geometry,
                    diagnostics,
                    eligibility,
                )
                loaded = PROFILE_IO.read_real_space_operator_bundle(output)
                if profile == :full && route == :symmetrized_sawf
                    original_sidecar = read(inputs.uiu_provenance)
                    warning = JSON3.read(original_sidecar, Dict{String, Any})
                    merge!(
                        warning,
                        Dict(
                            "construction_policy" => "standard",
                            "status" => "EXPORTED_WITH_WARNING",
                            "passed" => false,
                            "physical_overlap_available" => true,
                            "production_eligible" => false,
                            "generalized_normalization_max_absolute" => 0.01,
                            "radial_q_max_absolute" => 0.0,
                            "diagonal_identity_max_absolute" => 0.02,
                            "exchange_hermiticity_max_absolute" => 0.0,
                            "diagnostics" => [
                                "UIU_GENERATION_NUMERICAL_WARNING",
                                "NUMERICAL_WARNING:UIU_PREFLIGHT_GATE_FAILED",
                                "NUMERICAL_WARNING:UIU_OUTPUT_GATE_FAILED",
                            ],
                        ),
                    )
                    write(inputs.uiu_provenance, JSON3.write(warning))
                    warning_operators, warning_provenance = Base.invokelatest(
                        extension._assemble_wannierization_operator_profile_from_qualified_sources,
                        model,
                        prepared,
                        profile_mmn,
                        config,
                        authority,
                        symmetry_plan,
                        gauge_contract,
                        inputs.spn_attestation,
                        0.0,
                        assembly_target,
                    )
                    @test warning_provenance["uiu_generation_status"] == "EXPORTED_WITH_WARNING"
                    @test warning_provenance["uiu_generation_numerical_warning"]["generalized_normalization_max_absolute"] ==
                          0.01
                    @test all(
                        warning_operators[k].data == operators[k].data for k in keys(operators)
                    )
                    warning_eligibility = merge(
                        copy(eligibility),
                        Dict(
                            "numerical_quality" => "NUMERICAL_WARNING",
                            "tb_export_status" => "EXPORTED_WITH_WARNING",
                            "construction_quality_failed" => true,
                            "production_eligible" => false,
                            "physics_qualification" => "PHYSICS_HOLD",
                        ),
                    )
                    warning_output = joinpath(directory, "full-warning.h5")
                    PROFILE_IO.write_real_space_operator_bundle(
                        warning_output,
                        model.lattice,
                        model.r_degeneracies,
                        warning_operators;
                        profile,
                        provenance = merge(
                            Dict(
                                "route" => String(route),
                                "authoritative_hamiltonian" => authority.authority,
                                "authoritative_hamiltonian_definition" => authority.definition,
                            ),
                            warning_provenance,
                        ),
                        geometry,
                        diagnostics = warning_eligibility,
                        eligibility = warning_eligibility,
                    )
                    warning_loaded = PROFILE_IO.read_real_space_operator_bundle(warning_output)
                    # Warning remains true at its actual consumer/report boundary.
                    @test warning_eligibility["physics_qualification"] == "PHYSICS_HOLD"
                    @test warning_eligibility["numerical_quality"] == "NUMERICAL_WARNING"
                    @test !warning_eligibility["production_eligible"]
                    @test warning_loaded.manifest.numerical_quality === nothing
                    @test warning_loaded.manifest.physics_qualification === nothing
                    @test !warning_loaded.manifest.production_eligible
                    @test all(
                        warning_loaded.operators[k].data == loaded.operators[k].data for
                        k in keys(operators)
                    )
                    HDF5.h5open(warning_output, "r") do h
                        @test !haskey(h, "qualification")
                        @test !haskey(h, "construction_evidence")
                        @test !haskey(h, "diagnostics")
                    end
                    write(inputs.uiu_provenance, original_sidecar)
                end
                @test loaded.manifest.schema_version == PROFILE_IO.OPERATOR_BUNDLE_SCHEMA_VERSION
                @test loaded.manifest.inventory == expected
                @test Set(keys(loaded.operators)) == Set(expected)
                @test loaded.manifest.authoritative_hamiltonian == authority.authority
                @test loaded.manifest.lattice == model.lattice
                @test loaded.manifest.r_vectors == model.r_vectors
                @test loaded.manifest.degeneracies == model.r_degeneracies
                @test all(
                    reinterpret(UInt8, vec(loaded.operators[k].data)) ==
                    reinterpret(UInt8, vec(operators[k].data)) for k in expected
                )
                @test !loaded.manifest.production_eligible
                @test loaded.manifest.physics_qualification === nothing
                @test loaded.manifest.numerical_quality === nothing
                HDF5.h5open(output, "r") do h
                    @test !haskey(h, "qualification")
                    @test !haskey(h, "construction_evidence")
                    @test !haskey(HDF5.attributes(h), "operator_qualification_sha256")
                end
                # Keep measured transform/covariance checks at assembly, rather
                # than requiring their old permission labels in the output schema.
                for record in values(operator_qualification["operators"])
                    if record["pair_wigner_seitz_roundtrip_status"] != "NOT_APPLICABLE"
                        @test isfinite(record["pair_wigner_seitz_roundtrip_residual"])
                        @test record["pair_wigner_seitz_roundtrip_residual"] <=
                              record["pair_wigner_seitz_roundtrip_tolerance"]
                    end
                end
                if profile == :full
                    @test provenance["derivative_overlap_source"] == "neighbor_pair_overlap"
                    @test provenance["derivative_overlap_completeness"] == "full_hilbert_space"
                    @test loaded.manifest.derivative_overlap_source == "neighbor_pair_overlap"
                    @test loaded.manifest.derivative_overlap_completeness == "full_hilbert_space"
                    @test loaded.manifest.derivative_overlap_algorithm_version ==
                          PROFILE_IO.FULL_DERIVATIVE_OVERLAP_ALGORITHM_VERSION
                    # Lack of a band-convergence study remains lack of evidence.
                    @test finite_band_family["overall"] == "RISK_RECORDED_NOT_CONVERGED"
                    @test !loaded.manifest.finite_band_galerkin_production_eligible
                    # Removing a consumed mathematical definition does not invent
                    # the legacy mmn_product semantics or a convergence result.
                    absent_provenance = deepcopy(provenance)
                    for key in (
                        "derivative_overlap_source",
                        "derivative_overlap_completeness",
                        "derivative_overlap_algorithm_version",
                    )
                        pop!(absent_provenance, key, nothing)
                    end
                    absent_file = joinpath(directory, "full-missing-definition.h5")
                    PROFILE_IO.write_real_space_operator_bundle(
                        absent_file,
                        model.lattice,
                        model.r_degeneracies,
                        operators;
                        profile,
                        provenance = absent_provenance,
                        geometry,
                        eligibility,
                    )
                    absent = PROFILE_IO.read_real_space_operator_bundle(absent_file)
                    @test absent.manifest.derivative_overlap_source == "NOT_RECORDED"
                    @test absent.manifest.derivative_overlap_completeness == "NOT_RECORDED"
                    @test !absent.manifest.production_eligible
                    @test all(
                        absent.operators[k].data == loaded.operators[k].data for k in expected
                    )
                    if route == :ordinary
                        legacy_file = joinpath(directory, "unsupported-schema.h5")
                        cp(output, legacy_file)
                        HDF5.h5open(legacy_file, "r+") do h
                            HDF5.delete_attribute(h, "schema_version")
                            HDF5.attributes(h)["schema_version"] = "1.3"
                        end
                        @test_throws ArgumentError PROFILE_IO.read_real_space_operator_bundle(
                            legacy_file,
                        )
                    end
                end
            end
            if route == :ordinary
                checkpoint = joinpath(directory, "preserved.wannierization.h5")
                PROFILE_W.write_wannierization_checkpoint_hdf5(checkpoint, eligible)
                checkpoint_bytes = read(checkpoint)
                tampered_sidecar = joinpath(directory, "tampered-sHu.json")
                tampered_payload =
                    JSON3.read(read(inputs.shu_provenance, String), Dict{String, Any})
                tampered_payload["authoritative_hamiltonian_definition"] = "wrong-authority-definition"
                open(tampered_sidecar, "w") do stream
                    JSON3.write(stream, tampered_payload)
                end
                structural_config = _profile_modified_config(
                    fixture.config;
                    profile = :full,
                    authoritative_hamiltonian = PROFILE_W.NativeDFTHamiltonian(),
                    mmn_file = inputs.mmn_file,
                    spn_file = inputs.spn_file,
                    spn_provenance_file = inputs.spn_provenance,
                    uiu_file = inputs.uiu_file,
                    uhu_file = inputs.uhu_file,
                    siu_file = inputs.siu_file,
                    shu_file = inputs.shu_file,
                    uiu_provenance_json = inputs.uiu_provenance,
                    uhu_provenance_json = inputs.uhu_provenance,
                    siu_provenance_json = inputs.siu_provenance,
                    shu_provenance_json = tampered_sidecar,
                )
                target_h5 = joinpath(directory, "structural-failure-must-not-publish.h5")
                structural_error = try
                    Base.invokelatest(
                        extension._assemble_wannierization_operator_profile_from_qualified_sources,
                        model,
                        prepared,
                        profile_mmn,
                        structural_config,
                        authority,
                        nothing,
                        gauge_contract,
                        inputs.spn_attestation,
                        0.0,
                        full_target,
                    )
                    nothing
                catch exception
                    exception
                end
                @test structural_error isa ArgumentError
                @test occursin(
                    "HAMILTONIAN_REFERENCE_MISMATCH",
                    sprint(showerror, structural_error),
                )
                @test !isfile(target_h5)
                @test isfile(checkpoint)
                @test read(checkpoint) == checkpoint_bytes
            end
        end
    end
end

@testset "removed spin profile reports migration error" begin
    error = try
        PROFILE_IO.validate_operator_profile(
            :spin,
            PROFILE_IO.OPERATOR_PROFILE_INVENTORIES[:hamiltonian_position_spin],
        )
        nothing
    catch exception
        exception
    end
    @test error isa ArgumentError
    @test occursin("migrate to :hamiltonian_position_spin", sprint(showerror, error))
end

@testset "public Wannierization profiles are exactly two" begin
    for profile in
        (:hamiltonian_position_spin, :spin, :orbital_magnetization, :derivative, :task_derived)
        @test_throws PROFILE_CORE.OperatorSelectionError PROFILE_IO.resolve_operator_selection(
            profile,
        )
    end
end
