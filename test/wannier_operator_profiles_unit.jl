using HDF5
using JSON3
using LinearAlgebra
using SHA

const PROFILE_W = WannierNLQG.Wannierization
const PROFILE_IO = WannierNLQG.IO
const PROFILE_CORE = WannierNLQG.Core

function _profile_modified_config(config; keywords...)
    replacements = NamedTuple(keywords)
    unknown = setdiff(keys(replacements), PROFILE_W.WANNIERIZATION_CONFIG_LEAF_FIELDS)
    isempty(unknown) || throw(ArgumentError("unknown Wannierization config fields: $(unknown)"))
    select(fields) = begin
        selected = Tuple(name for name in keys(replacements) if name in fields)
        NamedTuple{selected}(Tuple(getfield(replacements, name) for name in selected))
    end
    return PROFILE_W._replace_wannierization_config(
        config;
        input = select(PROFILE_W.WANNIERIZATION_INPUT_CONFIG_FIELDS),
        solver = select(PROFILE_W.WANNIERIZATION_SOLVER_CONFIG_FIELDS),
        checkpoint = select(PROFILE_W.WANNIERIZATION_CHECKPOINT_CONFIG_FIELDS),
        runtime = select(PROFILE_W.WANNIERIZATION_RUNTIME_CONFIG_FIELDS),
        output = select(PROFILE_W.WANNIERIZATION_OUTPUT_CONFIG_FIELDS),
    )
end

function _profile_scientific_digest_for_schema(manifest, schema_version)
    extension, _ = PROFILE_IO._load_operator_bundle_extension!()
    return Base.invokelatest(
        extension._scientific_content_digest,
        manifest.profile,
        manifest.inventory,
        manifest.lattice,
        manifest.r_vectors,
        manifest.degeneracies,
        getfield.(manifest.entries, :component_sha256),
        manifest.paired_tb_sha256,
        schema_version,
        manifest.geometry_content_sha256,
        manifest.authoritative_hamiltonian,
        manifest.authoritative_hamiltonian_sha256,
        manifest.energy_shift_qualification,
        manifest.maximum_energy_shift_audit_reference_ev,
        manifest.rms_energy_shift_audit_reference_ev,
        manifest.target_energy_shift_audit_status,
        manifest.symmetrized_parent_energy_shift_audit_status,
        manifest.residual_gate_phase,
        manifest.raw_preflight_diagnostic_status,
        manifest.native_difference_qualification,
        manifest.native_difference_audit_status,
        manifest.qualification_scope,
        manifest.target_anchor,
        manifest.target_complement_completion,
        manifest.target_complement_max_element_ev,
        manifest.auxiliary_parent_qualification,
        manifest.symmetrized_target_subspace_status,
        manifest.auxiliary_parent_audit_status,
        manifest.target_scope_production_eligible,
        manifest.parent_audit_policy,
        manifest.outer_mask_sha256,
        manifest.frozen_mask_sha256,
        manifest.target_subspace_contract_sha256,
        manifest.target_leakage_semantics,
        manifest.target_leakage_formula_sha256,
        manifest.target_leakage_threshold,
        manifest.derivative_overlap_source,
        manifest.derivative_overlap_completeness,
        something(manifest.derivative_overlap_source_sha256, "not_provided"),
        manifest.derivative_overlap_algorithm_version,
        manifest.target_authority,
        manifest.operator_qualification_sha256,
        manifest.band_frame_contract_sha256,
    )
end

function _profile_geometry(model)
    home = only(
        findall(index -> all(iszero, @view(model.r_vectors[:, index])), axes(model.r_vectors, 2)),
    )
    centers = zeros(Float64, model.num_orbitals, 3)
    for orbital in 1:model.num_orbitals, direction in 1:3
        centers[orbital, direction] =
            real(model.position_r[orbital, orbital, direction, home] / model.r_degeneracies[home])
    end
    return Dict(
        "wannier_center_policy" => "keep_input",
        "real_space_replica_policy" => "input",
        "production_eligible" => true,
        "minimum_distance_materialized" => false,
        "mp_grid" => [2, 1, 1],
        "wannier_center_tolerance" => 1.0e-8,
        "wigner_seitz_tolerance" => 1.0e-5,
        "wigner_seitz_search_size" => 3,
        "raw_wannier_centers_cartesian" => centers,
        "raw_wannier_centers_fractional" => centers * inv(model.lattice),
        "final_wannier_centers_cartesian" => centers,
        "final_wannier_centers_fractional" => centers * inv(model.lattice),
        "center_alignment_lattice_shifts" => zeros(Int, size(centers)),
        "replica_mapping_sha256" => repeat("0", 64),
    )
end

function _profile_gauge_contract(
    parent_extension,
    route,
    num_bands,
    num_kpoints;
    artifact_sha256 = nothing,
)
    paw = parent_extension.PAWMatrixElements
    support = parent_extension.WannierizationInternalSupport
    operator_export = parent_extension.OperatorExport
    if route == :ordinary
        return Base.invokelatest(paw._identity_band_frame_contract, num_bands, num_kpoints)
    end
    artifact_sha256 === nothing && error("SAWF focused contract requires an artifact digest")
    rotations = zeros(ComplexF64, num_bands, num_bands, num_kpoints)
    phase_offset = route == :native_sawf ? 0.17 : 0.31
    for kpoint in 1:num_kpoints, band in 1:num_bands
        rotations[band, band, kpoint] = cis(phase_offset * (band + kpoint))
    end
    transform_sha256 = Base.invokelatest(operator_export._authoritative_array_sha256, rotations)
    target_band_gauge =
        route == :native_sawf ? support.SAWF_COMPLETED_NATIVE_DFT_BAND_GAUGE :
        support.SYMMETRIZED_DFT_BAND_GAUGE
    contract_sha256 = bytes2hex(
        SHA.sha256(
            codeunits(
                join(
                    (
                        support.NATIVE_DFT_BAND_GAUGE,
                        target_band_gauge,
                        transform_sha256,
                        String(something(artifact_sha256)),
                    ),
                    '\0',
                ),
            ),
        ),
    )
    return Base.invokelatest(
        support.BandFrameTransformContract,
        support.NATIVE_DFT_BAND_GAUGE,
        target_band_gauge,
        rotations,
        transform_sha256,
        contract_sha256,
        String(something(artifact_sha256)),
        "focused_identity_metric",
        0.0,
        1.0e-8,
        0.0,
        1.0e-8,
        0.0,
        1.0,
        1.0,
        "WannierNLQG.band_frame_transform_contract",
        "1.0",
        "PASS",
        false,
    )
end

function _profile_symmetry_plan(route, num_wannier)
    route == :ordinary && return nothing
    identity = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
        false,
    )
    if route == :native_sawf
        return WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
            [identity],
            reshape(Matrix{ComplexF64}(I, num_wannier, num_wannier), num_wannier, num_wannier, 1),
            zeros(Int, 3, num_wannier, 1),
        )
    end
    inversion = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        -Matrix{Int}(I, 3, 3),
        zeros(3),
        -Matrix{Float64}(I, 3, 3),
        false,
    )
    operations = [identity, inversion]
    representations = zeros(ComplexF64, num_wannier, num_wannier, 2)
    representations[:, :, 1] .= Matrix{ComplexF64}(I, num_wannier, num_wannier)
    representations[:, :, 2] .=
        Diagonal(ComplexF64[isodd(index) ? -1 : 1 for index in 1:num_wannier])
    return WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
        operations,
        representations,
        zeros(Int, 3, num_wannier, 2),
    )
end

function _profile_write_inputs(directory, mmn, authority, gauge_contract, parent_extension)
    paw = parent_extension.PAWMatrixElements
    support = parent_extension.WannierizationInternalSupport
    mmn_file = joinpath(directory, "fixture.mmn")
    PROFILE_IO.write_wannier_mmn(mmn_file, mmn)
    spn_data = zeros(ComplexF64, 2, 2, 3, 2)
    pauli = (ComplexF64[0 1; 1 0], ComplexF64[0 -im; im 0], ComplexF64[1 0; 0 -1])
    for kpoint in 1:2, axis in 1:3
        spn_data[:, :, axis, kpoint] .= pauli[axis]
    end
    spn_file = joinpath(directory, "fixture.spn")
    PROFILE_IO.write_wannier_spn(spn_file, PROFILE_IO.WannierSPN(2, 2, spn_data))
    spn_provenance = joinpath(directory, "fixture.spn.provenance.json")
    write(spn_provenance, "{\"fixture\":\"normalized-schema-1.2-attestation\"}")
    spn_sha256 = bytes2hex(SHA.sha256(read(spn_file)))
    spn_provenance_sha256 = bytes2hex(SHA.sha256(read(spn_provenance)))
    source_hashes = Dict("SOURCE_WAVEFUNCTIONS" => repeat("a", 64), "TOPOLOGY" => repeat("b", 64))
    common_hashes = merge(
        source_hashes,
        Dict(
            "BAND_FRAME_TRANSFORM" => gauge_contract.transform_sha256,
            "BAND_FRAME_CONTRACT" => gauge_contract.contract_sha256,
        ),
    )
    gauge_contract.gauge_artifact_sha256 === nothing ||
        (common_hashes["WAVEFUNCTION_GAUGE_HDF5"] = something(gauge_contract.gauge_artifact_sha256))
    native_spn_contract = Base.invokelatest(paw._identity_band_frame_contract, 2, 2)
    spn_attestation = (
        schema = "WannierNLQG.qe_paw_spn",
        schema_version = "1.2",
        source_code = :synthetic,
        passed = true,
        status = "PASS",
        physical_metric = "PAW/USPP generalized overlap",
        spinor = true,
        num_bands = 2,
        num_kpts = 2,
        source_band_gauge = gauge_contract.source_band_gauge,
        target_band_gauge = gauge_contract.source_band_gauge,
        transform_sha256 = native_spn_contract.transform_sha256,
        contract_sha256 = native_spn_contract.contract_sha256,
        frame_contract = Dict{String, Any}(
            String(key) => value for
            (key, value) in pairs(support.band_frame_contract_summary(native_spn_contract))
        ),
        rotation_sha256 = native_spn_contract.transform_sha256,
        input_sha256 = source_hashes,
        diagnostics = String[],
        spn_sha256,
        provenance_sha256 = spn_provenance_sha256,
        qualification_target_band_gauge = gauge_contract.target_band_gauge,
        qualification_transform_sha256 = gauge_contract.transform_sha256,
        qualification_contract_sha256 = gauge_contract.contract_sha256,
        qualification_rotation_sha256 = gauge_contract.transform_sha256,
        gauge_artifact_sha256 = something(gauge_contract.gauge_artifact_sha256, "NOT_APPLICABLE"),
    )
    spn_target = similar(spn_data)
    for kpoint in 1:2, axis in 1:3
        spn_target[:, :, axis, kpoint] .= Base.invokelatest(
            paw._rotate_generation_single,
            @view(spn_data[:, :, axis, kpoint]),
            gauge_contract,
            kpoint,
        )
    end
    header_uiu = PROFILE_IO.WannierUIUHeader("profile", 2, 2, mmn.num_neighbors)
    header_uhu = PROFILE_IO.WannierUHUHeader("profile", 2, 2, mmn.num_neighbors)
    header_siu = PROFILE_IO.WannierSIUHeader("profile", 2, 2, mmn.num_neighbors)
    header_shu = PROFILE_IO.WannierSHUHeader("profile", 2, 2, mmn.num_neighbors)
    uiu_file = joinpath(directory, "fixture.uIu")
    uhu_file = joinpath(directory, "fixture.uHu")
    siu_file = joinpath(directory, "fixture.sIu")
    shu_file = joinpath(directory, "fixture.sHu")
    PROFILE_IO.write_wannier_uiu(uiu_file, header_uiu) do _...
        Matrix{ComplexF64}(I, 2, 2)
    end
    PROFILE_IO.write_wannier_uhu(uhu_file, header_uhu) do kpoint, _...
        Matrix{ComplexF64}(@view authority.matrices_ev[:, :, kpoint])
    end
    PROFILE_IO.write_wannier_siu(siu_file, header_siu) do kpoint, _neighbor, axis, _
        Matrix{ComplexF64}(@view spn_target[:, :, axis, kpoint])
    end
    PROFILE_IO.write_wannier_shu(shu_file, header_shu) do kpoint, _neighbor, axis, _
        (@view spn_target[:, :, axis, kpoint]) * (@view authority.matrices_ev[:, :, kpoint])
    end
    uiu_provenance = uiu_file * ".json"
    open(uiu_provenance, "w") do io
        JSON3.write(
            io,
            Dict(
                "schema" => "WannierNLQG.wannier_uiu_generation",
                "schema_version" => "1.2",
                "algorithm_version" => "focused-profile-fixture",
                "passed" => true,
                "physical_overlap_available" => true,
                "output_sha256" => bytes2hex(SHA.sha256(read(uiu_file))),
                "source_band_gauge" => gauge_contract.source_band_gauge,
                "target_band_gauge" => gauge_contract.target_band_gauge,
                "band_frame_transform_sha256" => gauge_contract.transform_sha256,
                "band_frame_contract_sha256" => gauge_contract.contract_sha256,
                "band_frame_contract" => support.band_frame_contract_summary(gauge_contract),
                "band_gauge_rotation_sha256" => gauge_contract.transform_sha256,
                "band_gauge_rotation_semantics" => "legacy_alias_of_band_frame_transform_sha256",
                "gauge_artifact_sha256" =>
                    something(gauge_contract.gauge_artifact_sha256, "NOT_APPLICABLE"),
                "input_sha256" => merge(
                    common_hashes,
                    Dict("ORACLE_MMN" => bytes2hex(SHA.sha256(read(mmn_file)))),
                ),
            ),
        )
    end
    sidecars = Dict{Symbol, String}()
    for (operator, path) in ((:uHu, uhu_file), (:sIu, siu_file), (:sHu, shu_file))
        sidecar = path * ".json"
        open(sidecar, "w") do io
            JSON3.write(
                io,
                Dict(
                    "schema" => "WannierNLQG.wannier_hamiltonian_operator_generation",
                    "schema_version" => "1.3",
                    "algorithm_version" => "focused-profile-fixture",
                    "operator" => String(operator),
                    "status" => "PASS",
                    "passed" => true,
                    "qualification_stage" => "SOURCE_OPERATOR_GENERATION",
                    "source_generation_qualified" => true,
                    "artifact_published" => true,
                    "closure_residual" => 0.0,
                    "diagnostic_reference" => 1.0e-6,
                    "diagnostic_reference_status" =>
                        operator == :uHu ? "ABOVE_REFERENCE" : "WITHIN_REFERENCE",
                    "diagnostic_reference_policy" => "AUDIT_ONLY_NOT_AN_ACTUAL_OPERATOR_ERROR_BOUND",
                    "actual_operator_error_status" => "NOT_AVAILABLE_WITHOUT_COMPLEMENT_HAMILTONIAN_OR_NBANDS_REFERENCE",
                    "nbands_convergence_status" => "NOT_ESTABLISHED",
                    "outer_probability_leakage_audit_maximum" => operator == :uHu ? 2.0e-6 : 0.0,
                    "outer_probability_leakage_audit_status" =>
                        operator == :uHu ? "ABOVE_REFERENCE" : "WITHIN_REFERENCE",
                    "frozen_probability_leakage_audit_maximum" => 0.0,
                    "frozen_probability_leakage_audit_status" => "WITHIN_REFERENCE",
                    "parent_mutual_containment_audit_maximum" => 0.0,
                    "parent_mutual_containment_audit_status" => "WITHIN_REFERENCE",
                    "parent_overlap_contraction_excess_audit_maximum" => 0.0,
                    "outer_overlap_contraction_excess_audit_maximum" => 0.0,
                    "frozen_overlap_contraction_excess_audit_maximum" => 0.0,
                    "galerkin_block_audit" => Dict(
                        "status" => "RECORDED",
                        "block_count" => 1,
                        "norm_kind" => "frobenius",
                        "maximum_frobenius_norm" => 1.0,
                        "maximum_frobenius_product_bound" => 1.0,
                        "minimum_block_to_bound_ratio" => 1.0,
                        "maximum_frobenius_product_bound_slack_fraction" => 0.0,
                        "exchange_hermiticity_max_absolute_ev" =>
                            operator == :uHu ? 0.0 : nothing,
                        "exchange_hermiticity_tolerance_ev" =>
                            operator == :uHu ? 1.0e-12 : nothing,
                        "exchange_hermiticity_status" =>
                            operator == :uHu ? "PASS" : "NOT_APPLICABLE",
                    ),
                    "galerkin_cancellation_audit" => Dict(
                        "status" => "NOT_AVAILABLE_BEFORE_FINAL_WANNIER_PROFILE_ASSEMBLY",
                        "policy" => "DEFER_TO_FINITE_DIFFERENCE_PROFILE_CONTRACTION",
                        "semantics" => "requires_absolute_sum_and_final_combination_in_the_actual_wannier_finite_difference_stencil",
                        "absolute_sum" => nothing,
                        "final_combination" => nothing,
                        "cancellation_ratio" => nothing,
                    ),
                    "output_sha256" => bytes2hex(SHA.sha256(read(path))),
                    "authoritative_hamiltonian" => authority.authority,
                    "authoritative_hamiltonian_digest" => authority.digest,
                    "source_band_gauge" => gauge_contract.source_band_gauge,
                    "target_band_gauge" => gauge_contract.target_band_gauge,
                    "band_frame_transform_sha256" => gauge_contract.transform_sha256,
                    "band_frame_contract_sha256" => gauge_contract.contract_sha256,
                    "band_frame_contract" => support.band_frame_contract_summary(gauge_contract),
                    "band_gauge_rotation_sha256" => gauge_contract.transform_sha256,
                    "band_gauge_rotation_semantics" => "legacy_alias_of_band_frame_transform_sha256",
                    "gauge_artifact_sha256" =>
                        something(gauge_contract.gauge_artifact_sha256, "NOT_APPLICABLE"),
                    "spn_provenance_sha256" =>
                        operator in (:sIu, :sHu) ? spn_provenance_sha256 : "NOT_APPLICABLE",
                    "input_sha256" => merge(
                        common_hashes,
                        Dict("EIG" => first(values(authority.input_sha256))),
                        operator in (:sIu, :sHu) ?
                        Dict("SPN" => spn_sha256, "SPN_PROVENANCE" => spn_provenance_sha256) :
                        Dict{String, String}(),
                    ),
                ),
            )
        end
        sidecars[operator] = sidecar
    end
    return (;
        mmn_file,
        spn_file,
        spn_provenance,
        spn_attestation,
        uiu_file,
        uhu_file,
        siu_file,
        shu_file,
        uiu_provenance,
        uhu_provenance = sidecars[:uHu],
        siu_provenance = sidecars[:sIu],
        shu_provenance = sidecars[:sHu],
    )
end

function _profile_eligibility(authority)
    metadata = Dict{String, Any}(
        "authoritative_hamiltonian" => authority.authority,
        "authoritative_hamiltonian_sha256" => authority.digest,
    )
    authority.authority == "native_dft" && return metadata
    merge!(
        metadata,
        Dict(
            "energy_shift_qualification" => "audit_only",
            "residual_gate_phase" => "post_symmetrization",
            "native_difference_qualification" => "audit_only",
            "qualification_scope" => "target_subspace",
            "parent_audit_policy" => "audit_only",
            "target_authority" => "outer_window",
            "disentanglement_outer_mask_sha256" => repeat("1", 64),
            "disentanglement_frozen_mask_sha256" => repeat("2", 64),
            "target_subspace_contract_sha256" => repeat("3", 64),
            "target_leakage_semantics" => PROFILE_W.TB_TARGET_LEAKAGE_WEIGHT_SEMANTICS,
            "target_leakage_formula_sha256" => PROFILE_W.TB_TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256,
            "target_leakage_threshold" => 1.0e-6,
            "target_anchor" => "completed_symmetrized_target",
            "auxiliary_parent_qualification" => "audit_only",
        ),
    )
    return metadata
end

@testset "final-projector digest and endpoint leakage are Wannier-gauge invariant" begin
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
    digest = Base.invokelatest(extension._profile_final_subspace_projector_digest, chk)
    rotated_digest =
        Base.invokelatest(extension._profile_final_subspace_projector_digest, rotated_chk)
    @test digest.sha256 == rotated_digest.sha256
    audit = Base.invokelatest(extension._profile_final_projector_leakage_audit, chk, mmn, 1.0e-6)
    rotated_audit = Base.invokelatest(
        extension._profile_final_projector_leakage_audit,
        rotated_chk,
        mmn,
        1.0e-6,
    )
    @test audit["final_subspace_projector_sha256"] ==
          rotated_audit["final_subspace_projector_sha256"]
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

@testset "ordinary/native-SAWF/symmetrized-SAWF schema-6 profile matrix" begin
    fixture = diagnostic_export_fixture()
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
    fixture = diagnostic_export_fixture(; mmn_override = profile_mmn)
    parent_extension = first(PROFILE_W._load_wannierization_extension!())
    extension = parent_extension.OperatorExport
    eligible = PROFILE_W.WannierizationResult(
        PROFILE_W.COMPLETED,
        fixture.result.v_matrix,
        fixture.result.wannier_centers_cartesian,
        fixture.result.spreads_angstrom2,
        fixture.result.history,
        PROFILE_W.WannierizationDiagnostic[],
        merge(
            fixture.result.input_summary,
            Dict(
                "hard_gate_frozen" => "0.0",
                "solver_convergence" => "CONVERGED",
                "stopping_reason" => "CONVERGED",
            ),
        ),
        fixture.result.wannier_chk,
        nothing,
        fixture.result.restart_state,
        fixture.result.artifacts,
        fixture.result.initialization_report,
    )
    prepared, quality, _, _, _ =
        Base.invokelatest(extension._prepare_wannierization_tb_state, eligible, fixture.config)
    @test quality == "PASS"
    native = Base.invokelatest(extension._native_authoritative_band_hamiltonian, fixture.eig)
    for route in (:ordinary, :native_sawf, :symmetrized_sawf)
        mktempdir() do directory
            gauge_hdf5 = if route == :ordinary
                nothing
            else
                path = joinpath(directory, "$(route)-sealed-gauge-fixture.h5")
                write(path, "focused seam uses the equivalent normalized sealed contract")
                path
            end
            gauge_contract = _profile_gauge_contract(
                parent_extension,
                route,
                2,
                2;
                artifact_sha256 = gauge_hdf5 === nothing ? nothing :
                                  bytes2hex(SHA.sha256(read(gauge_hdf5))),
            )
            authority = if route == :symmetrized_sawf
                sym_inputs = Dict(
                    "WAVEFUNCTION_GAUGE_HDF5" =>
                        something(gauge_contract.gauge_artifact_sha256),
                    "NATIVE_TO_SYMMETRIZED_ROTATIONS" => gauge_contract.rotation_sha256,
                )
                sym_matrices = copy(native.matrices_ev)
                sym_digest = Base.invokelatest(
                    extension._authoritative_band_hamiltonian_digest,
                    sym_matrices,
                    "symmetrized_dft_hamiltonian",
                    sym_inputs,
                )
                Base.invokelatest(
                    extension.AuthoritativeBandHamiltonian,
                    sym_matrices,
                    "symmetrized_dft_hamiltonian",
                    sym_digest,
                    sym_inputs,
                    extension.AUTHORITATIVE_BAND_HAMILTONIAN_ALGORITHM_VERSION,
                    something(gauge_contract.gauge_artifact_sha256),
                    true,
                )
            else
                native
            end
            model = Base.invokelatest(
                extension.build_wannier_tight_binding_model,
                prepared,
                authority,
                profile_mmn,
            )
            symmetry_plan = _profile_symmetry_plan(route, model.num_orbitals)
            inputs = _profile_write_inputs(
                directory,
                profile_mmn,
                authority,
                gauge_contract,
                parent_extension,
            )
            target_contract = PROFILE_W.WannierOperatorTargetContract(
                abspath(inputs.mmn_file),
                bytes2hex(SHA.sha256(read(inputs.mmn_file))),
                abspath(inputs.mmn_file),
                bytes2hex(SHA.sha256(read(inputs.mmn_file))),
                gauge_contract.source_band_gauge,
                gauge_contract.target_band_gauge,
                gauge_contract.transform_sha256,
                gauge_contract.contract_sha256,
                something(gauge_contract.gauge_artifact_sha256, "NOT_APPLICABLE"),
                authority.authority,
                authority.digest,
                profile_mmn.num_bands,
                profile_mmn.num_kpts,
                profile_mmn.num_neighbors,
            )
            full_target = target_contract
            for profile in (:hamiltonian_position, :hamiltonian_position_spin, :full)
                config = _profile_modified_config(
                    fixture.config;
                    profile,
                    construction_policy = route == :symmetrized_sawf ? :diagnostic : :strict,
                    authoritative_hamiltonian = route == :symmetrized_sawf ?
                                                PROFILE_W.SymmetrizedDFTHamiltonian() :
                                                PROFILE_W.NativeDFTHamiltonian(),
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
                    @test factory_target.gauge_artifact_sha256 == "NOT_APPLICABLE"
                    @test occursin(r"^[0-9a-f]{64}$", factory_target.contract_sha256)

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
                    assembly_target = Base.invokelatest(
                        extension._wannier_operator_target_contract,
                        factory_config,
                        fixture.eig,
                        profile_mmn,
                        inputs.mmn_file,
                        distinct_solver_mmn_file,
                    )
                    @test assembly_target.operator_oracle_mmn_sha256 !=
                          assembly_target.solver_mmn_sha256
                    @test isnothing(
                        Base.invokelatest(
                            extension._validate_wannier_operator_target_contract,
                            factory_config,
                            fixture.eig,
                            profile_mmn,
                            assembly_target,
                        ),
                    )
                end
                if profile == :full
                    full_target = assembly_target
                    for sidecar in (
                        inputs.uiu_provenance,
                        inputs.uhu_provenance,
                        inputs.siu_provenance,
                        inputs.shu_provenance,
                    )
                        payload = JSON3.read(read(sidecar, String), Dict{String, Any})
                        payload["input_sha256"]["OPERATOR_TARGET_CONTRACT"] =
                            assembly_target.contract_sha256
                        open(sidecar, "w") do stream
                            JSON3.write(stream, payload)
                        end
                    end
                    snapshot_summary = copy(eligible.input_summary)
                    snapshot_summary["operator_profile_preflight_operator_target_contract_sha256"] =
                        assembly_target.contract_sha256
                    for (label, artifact, sidecar) in (
                        ("uiu", inputs.uiu_file, inputs.uiu_provenance),
                        ("uhu", inputs.uhu_file, inputs.uhu_provenance),
                        ("siu", inputs.siu_file, inputs.siu_provenance),
                        ("shu", inputs.shu_file, inputs.shu_provenance),
                    )
                        snapshot_summary["operator_profile_preflight_$(label)_sha256"] =
                            bytes2hex(SHA.sha256(read(artifact)))
                        snapshot_summary["operator_profile_preflight_$(label)_provenance_sha256"] =
                            bytes2hex(SHA.sha256(read(sidecar)))
                    end
                    snapshot_summary["operator_profile_preflight_spn_sha256"] =
                        bytes2hex(SHA.sha256(read(inputs.spn_file)))
                    snapshot_summary["operator_profile_preflight_spn_provenance_sha256"] =
                        bytes2hex(SHA.sha256(read(inputs.spn_provenance)))
                    snapshot_result =
                        parent_extension.WannierizationInternalSupport.updated_wannierization_result(
                            eligible;
                            input_summary = snapshot_summary,
                        )
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
                if route == :symmetrized_sawf
                    @test operator_qualification["construction_policy"] == "diagnostic"
                    @test operator_qualification["model_qualification"] == "DIAGNOSTIC_ONLY"
                    @test operator_qualification["manual_review_required"]
                    @test !operator_qualification["production_eligible"]
                    @test all(
                        record ->
                            record["source_status"] == "PASS" &&
                            record["gauge_status"] == "PASS" &&
                            record["qualification"] == "PASS",
                        values(operator_qualification["operators"]),
                    )
                end
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
                eligibility = _profile_eligibility(authority)
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
                                "action" => "CONTINUE_DIAGNOSTIC",
                                "stage" => "operator_profile_assembly",
                            ),
                        ),
                    ]
                    merge!(
                        eligibility,
                        Dict(
                            "construction_policy" => "diagnostic",
                            "construction_gate_records_json" =>
                                String(JSON3.write(retained_records)),
                            "manual_review_required" => true,
                            "construction_quality_failed" => true,
                            "diagnostic_classification" => "DIAGNOSTIC_ONLY_QUALITY_FAILED",
                            "diagnostic_only" => true,
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
                            "authoritative_hamiltonian_digest" => authority.digest,
                        ),
                        provenance,
                    ),
                    geometry,
                    diagnostics,
                    eligibility,
                )
                loaded = PROFILE_IO.read_real_space_operator_bundle(output)
                @test loaded.manifest.schema_version == "1.0"
                @test loaded.manifest.profile == profile
                @test loaded.manifest.inventory == expected
                @test Set(keys(loaded.operators)) == Set(expected)
                @test loaded.manifest.authoritative_hamiltonian == authority.authority
                @test loaded.manifest.band_frame_contract_status ==
                      (profile == :hamiltonian_position ? "NOT_APPLICABLE" : "PASS")
                if route == :symmetrized_sawf
                    @test loaded.manifest.diagnostic_only
                    @test !loaded.manifest.production_eligible
                    HDF5.h5open(output, "r") do handle
                        evidence = HDF5.attributes(handle["construction_evidence"])
                        @test String(read(evidence["construction_policy"])) == "diagnostic"
                        @test String(read(evidence["diagnostic_classification"])) ==
                              "DIAGNOSTIC_ONLY_QUALITY_FAILED"
                        @test Bool(read(evidence["manual_review_required"]))
                        @test !Bool(read(evidence["production_eligible"]))
                        retained =
                            JSON3.read(String(read(evidence["construction_gate_records_json"])))
                        @test retained[1].context.gate_result == "FAIL"
                    end
                end
                if profile != :hamiltonian_position
                    @test loaded.manifest.band_frame_transform_sha256 ==
                          gauge_contract.transform_sha256
                end
                qualification_operators = loaded.manifest.operator_qualification["operators"]
                @test Set(keys(qualification_operators)) ==
                      Set(PROFILE_CORE.real_space_operator_name.(expected))
                @test all(
                    record -> occursin(r"^[0-9a-f]{64}$", record["payload_sha256"]),
                    values(qualification_operators),
                )
                spin_names = Set((
                    "spin",
                    "spin_times_hamiltonian",
                    "spin_times_position",
                    "spin_times_hamiltonian_position",
                ))
                for (name, record) in qualification_operators
                    if name in spin_names
                        @test record["pair_wigner_seitz_transform_algorithm"] ==
                              "PAIR_DEPENDENT_WIGNER_SEITZ_Q_TO_R"
                        @test record["pair_wigner_seitz_storage_policy"] ==
                              "PAIR_DEPENDENT_MINIMUM_DISTANCE_UNIT_DEGENERACY"
                        @test record["pair_wigner_seitz_roundtrip_status"] == "PASS"
                        @test record["pair_wigner_seitz_roundtrip_residual"] <=
                              record["pair_wigner_seitz_roundtrip_tolerance"]
                    else
                        @test record["pair_wigner_seitz_roundtrip_status"] == "NOT_APPLICABLE"
                    end
                end
                if profile == :full
                    expected_uiu_sha256 = bytes2hex(SHA.sha256(read(inputs.uiu_file)))
                    @test provenance["derivative_overlap_source"] == "wannier90_uIu"
                    @test provenance["derivative_overlap_completeness"] == "full_hilbert_space"
                    @test provenance["derivative_overlap_source_sha256"] == expected_uiu_sha256
                    @test provenance["derivative_overlap_algorithm_version"] ==
                          PROFILE_IO.FULL_DERIVATIVE_OVERLAP_ALGORITHM_VERSION
                    @test loaded.manifest.derivative_overlap_source == "wannier90_uIu"
                    @test loaded.manifest.derivative_overlap_completeness == "full_hilbert_space"
                    @test loaded.manifest.derivative_overlap_source_sha256 == expected_uiu_sha256
                    @test loaded.manifest.derivative_overlap_algorithm_version ==
                          PROFILE_IO.FULL_DERIVATIVE_OVERLAP_ALGORITHM_VERSION
                    @test provenance["uIu_sha256"] == expected_uiu_sha256
                    @test qualification_operators["derivative_overlap_tensor"]["source_artifact_sha256"] ==
                          expected_uiu_sha256

                    legacy_provenance = copy(provenance)
                    for key in (
                        "derivative_overlap_source",
                        "derivative_overlap_completeness",
                        "derivative_overlap_source_sha256",
                        "derivative_overlap_algorithm_version",
                    )
                        delete!(legacy_provenance, key)
                    end
                    legacy_metadata_output =
                        joinpath(directory, "$(route)-full-missing-derivative-provenance.h5")
                    PROFILE_IO.write_real_space_operator_bundle(
                        legacy_metadata_output,
                        model.lattice,
                        model.r_degeneracies,
                        operators;
                        profile,
                        overwrite = true,
                        provenance = merge(
                            Dict(
                                "route" => String(route),
                                "authoritative_hamiltonian" => authority.authority,
                                "authoritative_hamiltonian_digest" => authority.digest,
                            ),
                            legacy_provenance,
                        ),
                        geometry,
                        diagnostics,
                        eligibility,
                    )
                    legacy_metadata =
                        PROFILE_IO.read_real_space_operator_bundle(legacy_metadata_output)
                    @test legacy_metadata.manifest.derivative_overlap_source == "mmn_product"
                    @test legacy_metadata.manifest.derivative_overlap_completeness ==
                          "finite_window_internal"
                    @test legacy_metadata.manifest.scientific_content_sha256 !=
                          loaded.manifest.scientific_content_sha256
                    @test getfield.(legacy_metadata.manifest.entries, :component_sha256) ==
                          getfield.(loaded.manifest.entries, :component_sha256)
                    byte_exact = true
                    maximum_absolute_difference = 0.0
                    for kind in expected
                        corrected = loaded.operators[kind].data
                        legacy = legacy_metadata.operators[kind].data
                        assembled = operators[kind].data
                        component_byte_exact =
                            reinterpret(UInt8, vec(corrected)) ==
                            reinterpret(UInt8, vec(legacy)) ==
                            reinterpret(UInt8, vec(assembled))
                        component_maximum_absolute_difference = maximum(abs, corrected .- legacy)
                        byte_exact &= component_byte_exact
                        maximum_absolute_difference =
                            max(maximum_absolute_difference, component_maximum_absolute_difference)
                        @test component_byte_exact
                        @test component_maximum_absolute_difference == 0.0
                    end
                    @test byte_exact
                    @test maximum_absolute_difference == 0.0
                    @info "full-profile derivative provenance re-export evidence" route =
                        String(route) uiu_sha256 = expected_uiu_sha256 legacy_scientific_content_sha256 =
                        legacy_metadata.manifest.scientific_content_sha256 corrected_scientific_content_sha256 =
                        loaded.manifest.scientific_content_sha256 component_sha256_equal = true array_bytes_equal =
                        byte_exact max_abs = maximum_absolute_difference

                    @test qualification_operators["spin_times_hamiltonian"]["authoritative_hamiltonian_digest"] ==
                          authority.digest
                    @test qualification_operators["spin_times_hamiltonian_position"]["authoritative_hamiltonian_digest"] ==
                          authority.digest
                    @test qualification_operators["spin"]["authoritative_hamiltonian"] ==
                          "NOT_APPLICABLE"
                    @test loaded.manifest.finite_band_galerkin_qualification ==
                          "RISK_RECORDED_NOT_CONVERGED"
                    @test loaded.manifest.finite_band_galerkin_qualification_reason ==
                          "NBANDS_CONVERGENCE_NOT_ESTABLISHED"
                    @test !loaded.manifest.finite_band_galerkin_production_eligible
                    @test loaded.manifest.diagnostic_only
                    finite_band =
                        loaded.manifest.operator_qualification["families"]["finite_band_galerkin"]
                    @test finite_band["finite_band_risk_audit"]["uHu"]["diagnostic_reference_status"] ==
                          "ABOVE_REFERENCE"
                    @test finite_band["final_projector_galerkin_audit"]["final_subspace_dimension"] ==
                          model.num_orbitals
                    @test finite_band["galerkin_cancellation_audit"]["sHu"]["status"] == "RECORDED"
                    if route == :ordinary
                        legacy_62 = joinpath(directory, "full-schema-6.2-legacy-galerkin.h5")
                        cp(output, legacy_62; force = true)
                        legacy_digest =
                            _profile_scientific_digest_for_schema(loaded.manifest, "6.2")
                        HDF5.h5open(legacy_62, "r+") do handle
                            HDF5.delete_attribute(handle, "schema_version")
                            HDF5.attributes(handle)["schema_version"] = "6.2"
                            HDF5.delete_attribute(handle, "scientific_content_sha256")
                            HDF5.attributes(handle)["scientific_content_sha256"] = legacy_digest
                        end
                        legacy_manifest =
                            PROFILE_IO.read_real_space_operator_bundle_manifest(legacy_62)
                        @test legacy_manifest.schema_version == "6.2"
                        @test legacy_manifest.profile == :full
                        @test legacy_manifest.inventory == expected
                        @test legacy_manifest.finite_band_galerkin_qualification ==
                              "LEGACY_NOT_RECORDED"
                        @test legacy_manifest.finite_band_galerkin_qualification_reason ==
                              "LEGACY_GALERKIN_RISK_CONTRACT_NOT_RECORDED"
                        @test !legacy_manifest.finite_band_galerkin_production_eligible
                        @test legacy_manifest.diagnostic_only
                    end
                else
                    @test loaded.manifest.finite_band_galerkin_qualification == "NOT_APPLICABLE"
                end
                @test loaded.manifest.spin_family_qualification ==
                      (profile == :hamiltonian_position ? "NOT_APPLICABLE" : "PASS")
                @test loaded.manifest.spin_family_production_eligible ==
                      (profile != :hamiltonian_position)
            end
            if route == :ordinary
                checkpoint = joinpath(directory, "preserved.wannierization.h5")
                PROFILE_W.write_wannierization_checkpoint_hdf5(checkpoint, eligible)
                checkpoint_sha256 = bytes2hex(SHA.sha256(read(checkpoint)))
                tampered_sidecar = joinpath(directory, "tampered-sHu.json")
                tampered_payload =
                    JSON3.read(read(inputs.shu_provenance, String), Dict{String, Any})
                delete!(tampered_payload["input_sha256"], "SOURCE_WAVEFUNCTIONS")
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
                    "sHu common source hash SOURCE_WAVEFUNCTIONS differs",
                    sprint(showerror, structural_error),
                )
                @test !isfile(target_h5)
                @test isfile(checkpoint)
                @test bytes2hex(SHA.sha256(read(checkpoint))) == checkpoint_sha256
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
