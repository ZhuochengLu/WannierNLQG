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
