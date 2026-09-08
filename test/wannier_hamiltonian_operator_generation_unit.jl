using EzXML
using HDF5
using JSON3
using LinearAlgebra
using SHA
using Spglib

if !isdefined(Main, :QEPAWMatrixElementsTestSupport)
    include(joinpath(@__DIR__, "QEPAWMatrixElementsTestSupport.jl"))
end
using .QEPAWMatrixElementsTestSupport

const HOP_WANNIERIZATION = WannierNLQG.Wannierization

struct HOPPreflightCountingSource <: WannierNLQG.SymmetryFoundation.AbstractWavefunctionSource end
const HOP_PREFLIGHT_SOURCE_CALLS = Ref(0)
const HOP_PAW_EXTENSION =
    Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).PAWMatrixElements
@eval HOP_PAW_EXTENSION begin
    _generation_source_protected_paths(::$(HOPPreflightCountingSource)) = ()
    function _uiu_source_state(::$(HOPPreflightCountingSource), args...)
        $(HOP_PREFLIGHT_SOURCE_CALLS)[] += 1
        error("Hamiltonian-operator counting overlap seam reached")
    end
end

function _hop_native_config(source, fixture, eig_file, output; kwargs...)
    return HOP_WANNIERIZATION.WannierHamiltonianOperatorGenerationConfig(
        source = source,
        topology_file = fixture.nnkp_file,
        eig_file = eig_file,
        output_file = output,
        max_cached_wavefunction_kpoints = 2;
        kwargs...,
    )
end

function _hop_scope_topology(; neighbor_override = nothing)
    neighbors = neighbor_override === nothing ? reshape([2, 1], 1, 2) : neighbor_override
    return (
        num_bands = 2,
        num_kpts = 2,
        num_neighbors = 1,
        neighbors = neighbors,
        reciprocal_shifts = zeros(Int, 3, 1, 2),
        source_sha256 = "synthetic-topology-sha256",
    )
end

function _hop_scope_contract(artifact_sha256; transforms = zeros(ComplexF64, 2, 2, 2))
    return (
        gauge_artifact_sha256 = artifact_sha256,
        contract_sha256 = "synthetic-frame-contract-sha256",
        status = "PASS",
        legacy = false,
        transforms = transforms,
        physical_isometry_maximum = 1.0e-13,
        replay_maximum = 2.0e-13,
    )
end

function _hop_write_scope_artifact(
    path,
    outer_mask;
    frozen_mask = falses(size(outer_mask)),
    include_scope::Bool = true,
    outer_digest = nothing,
    schema_version::String = "1.11",
    status::String = "PASS",
)
    HDF5.h5open(path, "w") do handle
        attributes = HDF5.attributes(handle)
        attributes["schema"] = "WannierNLQG.star_covariant_paw_gauge"
        attributes["schema_version"] = schema_version
        attributes["status"] = status
        if include_scope
            group = HDF5.create_group(handle, "qualification_scope")
            group_attributes = HDF5.attributes(group)
            group_attributes["authority"] = "outer_window"
            group_attributes["parent_audit_policy"] = "audit_only"
            expected_outer =
                WannierNLQG.SymmetryFoundation.qualification_mask_sha256(BitMatrix(outer_mask))
            expected_frozen =
                WannierNLQG.SymmetryFoundation.qualification_mask_sha256(BitMatrix(frozen_mask))
            group_attributes["outer_mask_sha256"] =
                outer_digest === nothing ? expected_outer : String(outer_digest)
            group_attributes["frozen_mask_sha256"] = expected_frozen
            group["outer_mask"] = UInt8.(outer_mask)
            group["frozen_mask"] = UInt8.(frozen_mask)
        end
    end
    return path
end

@testset "target-scoped Galerkin probability closure" begin
    extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).OperatorExport
    topology = _hop_scope_topology()
    target_first_band = (outer_mask = BitMatrix(Bool[true true; false false]),)

    high_complement_leakage = zeros(ComplexF64, 2, 2, 1, 2)
    high_complement_leakage[:, :, 1, 1] .= Diagonal(ComplexF64[1, 0])
    high_complement_leakage[:, :, 1, 2] .= Diagonal(ComplexF64[1, 0])
    metrics = extension._hamiltonian_operator_closure_metrics(
        high_complement_leakage,
        topology,
        target_first_band;
        numerical_tolerance = 1.0e-12,
    )
    @test metrics.target_probability_leakage_maximum == 0.0
    @test metrics.parent_mutual_containment_audit_maximum == 1.0
    @test metrics.contraction_excess_maximum == 0.0
    @test metrics.defect_psd_violation_maximum == 0.0
    @test metrics.frozen_probability_leakage_audit_maximum === nothing
    @test isempty(extension._hamiltonian_operator_closure_failure_reasons(metrics, 1.0e-6))

    target_leakage = zeros(ComplexF64, 2, 2, 1, 2)
    target_leakage[:, :, 1, 1] .= Diagonal(ComplexF64[sqrt(1 - 2.0e-6), 1])
    target_leakage[:, :, 1, 2] .= Diagonal(ComplexF64[sqrt(1 - 2.0e-6), 1])
    leaking = extension._hamiltonian_operator_closure_metrics(
        target_leakage,
        topology,
        target_first_band;
        numerical_tolerance = 1.0e-12,
    )
    @test leaking.target_probability_leakage_maximum ≈ 2.0e-6 atol = 1.0e-14 rtol = 0.0
    @test leaking.target_probability_leakage_maximum > 1.0e-6

    noncontractive = copy(high_complement_leakage)
    noncontractive[:, :, 1, 1] .= Diagonal(ComplexF64[1.0001, 0])
    noncontractive_metrics = extension._hamiltonian_operator_closure_metrics(
        noncontractive,
        topology,
        target_first_band;
        numerical_tolerance = 1.0e-12,
    )
    @test noncontractive_metrics.contraction_excess_maximum ≈ 0.00020001 atol = 1.0e-12
    @test noncontractive_metrics.defect_psd_violation_maximum ≈ 0.00020001 atol = 1.0e-12
    @test isempty(
        extension._hamiltonian_operator_closure_failure_reasons(noncontractive_metrics, 1.0e-6),
    )
    @test "OUTER_CONTRACTION_EXCESS_AUDIT" in
          extension._hamiltonian_operator_closure_audit_findings(noncontractive_metrics, 1.0e-6)

    nonfinite = copy(high_complement_leakage)
    nonfinite[1, 1, 1, 1] = NaN
    @test_throws ArgumentError extension._hamiltonian_operator_closure_metrics(
        nonfinite,
        topology,
        target_first_band;
        numerical_tolerance = 1.0e-12,
    )

    bad_topology = _hop_scope_topology(neighbor_override = reshape([3, 1], 1, 2))
    @test_throws ArgumentError extension._hamiltonian_operator_closure_metrics(
        high_complement_leakage,
        bad_topology,
        target_first_band;
        numerical_tolerance = 1.0e-12,
    )
end

@testset "digest-bound operator closure scope" begin
    extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).OperatorExport
    topology = _hop_scope_topology()
    outer_mask = BitMatrix(Bool[true true; false false])

    mktempdir() do directory
        artifact = _hop_write_scope_artifact(joinpath(directory, "scope.h5"), outer_mask)
        artifact_sha256 = bytes2hex(SHA.sha256(read(artifact)))
        scope = extension._hamiltonian_operator_closure_scope(
            artifact,
            _hop_scope_contract(artifact_sha256),
            topology,
        )
        @test scope.authority == "outer_window"
        @test scope.parent_audit_policy == "audit_only"
        @test scope.outer_mask == outer_mask
        @test scope.outer_rank_minimum == 1
        @test scope.outer_rank_maximum == 1
        @test length(scope.contract_sha256) == 64

        diagnostic_artifact = _hop_write_scope_artifact(
            joinpath(directory, "diagnostic-scope.h5"),
            outer_mask;
            status = "DIAGNOSTIC_ONLY",
        )
        diagnostic_sha256 = bytes2hex(SHA.sha256(read(diagnostic_artifact)))
        diagnostic_contract = _hop_scope_contract(diagnostic_sha256)
        @test_throws ArgumentError extension._hamiltonian_operator_closure_scope(
            diagnostic_artifact,
            diagnostic_contract,
            topology,
        )
        diagnostic_scope = extension._hamiltonian_operator_closure_scope(
            diagnostic_artifact,
            diagnostic_contract,
            topology;
            construction_policy = :diagnostic,
        )
        @test diagnostic_scope.outer_mask == outer_mask
        @test_throws ArgumentError extension._hamiltonian_operator_closure_scope(
            diagnostic_artifact,
            diagnostic_contract,
            topology;
            construction_policy = :invalid,
        )

        tampered = _hop_write_scope_artifact(
            joinpath(directory, "tampered.h5"),
            outer_mask;
            outer_digest = repeat("0", 64),
        )
        tampered_sha256 = bytes2hex(SHA.sha256(read(tampered)))
        error = try
            extension._hamiltonian_operator_closure_scope(
                tampered,
                _hop_scope_contract(tampered_sha256),
                topology,
            )
            nothing
        catch caught
            caught
        end
        @test error isa ArgumentError
        @test occursin("CLOSURE_SCOPE_MASK_DIGEST_MISMATCH", sprint(showerror, error))

        missing = _hop_write_scope_artifact(
            joinpath(directory, "missing.h5"),
            outer_mask;
            include_scope = false,
        )
        missing_sha256 = bytes2hex(SHA.sha256(read(missing)))
        error = try
            extension._hamiltonian_operator_closure_scope(
                missing,
                _hop_scope_contract(missing_sha256),
                topology,
            )
            nothing
        catch caught
            caught
        end
        @test error isa ArgumentError
        @test occursin("CLOSURE_QUALIFICATION_SCOPE_REQUIRED", sprint(showerror, error))
    end

    identity_contract = _hop_scope_contract(nothing; transforms = nothing)
    native_scope =
        extension._hamiltonian_operator_closure_scope(nothing, identity_contract, topology)
    @test native_scope.authority == "full_parent_native_identity"
    @test all(native_scope.outer_mask)
    @test native_scope.parent_audit_policy == "audit_only"

    @test_throws ArgumentError extension._hamiltonian_operator_closure_scope(
        nothing,
        _hop_scope_contract(nothing),
        topology,
    )
end

@testset "finite-parent leakage is not an actual Hamiltonian-operator error proxy" begin
    leakage = 1.0e-4
    represented_amplitude = sqrt(1.0 - leakage)
    complement_amplitude = sqrt(leakage)
    exact_neighbor_state = ComplexF64[represented_amplitude, complement_amplitude]
    represented_hamiltonian_ev = 2.0
    galerkin_uhu_ev = abs2(represented_amplitude) * represented_hamiltonian_ev

    complement_free = Diagonal(ComplexF64[represented_hamiltonian_ev, 0.0])
    complement_weighted = Diagonal(ComplexF64[represented_hamiltonian_ev, 100.0])
    exact_free_ev = real(exact_neighbor_state' * complement_free * exact_neighbor_state)
    exact_weighted_ev = real(exact_neighbor_state' * complement_weighted * exact_neighbor_state)
    error_free_ev = abs(exact_free_ev - galerkin_uhu_ev)
    error_weighted_ev = abs(exact_weighted_ev - galerkin_uhu_ev)

    # Both full-space completions produce the same finite-parent overlap and
    # hence the same leakage diagnostic, while the unobserved Hamiltonian block
    # changes the actual uHu truncation error by a finite, independently
    # selectable amount.
    @test 1.0 - abs2(represented_amplitude) ≈ leakage atol = 1.0e-15 rtol = 0.0
    @test error_free_ev ≈ 0.0 atol = 1.0e-15 rtol = 0.0
    @test error_weighted_ev ≈ leakage * 100.0 atol = 1.0e-14 rtol = 0.0
    @test error_weighted_ev > 1.0e4 * max(error_free_ev, eps(Float64))
end

@testset "SPN source-specific topology provenance" begin
    extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).PAWMatrixElements
    state_hashes = Dict(
        "WAVECAR" => repeat("1", 64),
        "POTCAR" => repeat("2", 64),
        "TOPOLOGY" => repeat("3", 64),
    )
    vasp_without_topology = (
        source_code = :vasp,
        input_sha256 = Dict("WAVECAR" => repeat("1", 64), "POTCAR" => repeat("2", 64)),
    )
    @test extension._validate_generation_spn_input_sha256(vasp_without_topology, state_hashes) ===
          nothing

    vasp_wrong_topology = (
        source_code = :vasp,
        input_sha256 = merge(
            vasp_without_topology.input_sha256,
            Dict("TOPOLOGY" => repeat("4", 64)),
        ),
    )
    @test_throws ArgumentError extension._validate_generation_spn_input_sha256(
        vasp_wrong_topology,
        state_hashes,
    )

    qe_without_topology =
        (source_code = :qe, input_sha256 = copy(vasp_without_topology.input_sha256))
    @test_throws ArgumentError extension._validate_generation_spn_input_sha256(
        qe_without_topology,
        state_hashes,
    )

    vasp_wrong_source = (
        source_code = :vasp,
        input_sha256 = Dict("WAVECAR" => repeat("5", 64), "POTCAR" => repeat("2", 64)),
    )
    @test_throws ArgumentError extension._validate_generation_spn_input_sha256(
        vasp_wrong_source,
        state_hashes,
    )
end

@testset "formal QE PAW uHu/sHu/sIu generators" begin
    mktempdir() do directory
        fixture = write_qe_paw_fixture(
            directory;
            metric_kind = :paw,
            spinor = true,
            spinorbit = true,
            num_kpoints = 3,
        )
        source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
            fixture.save_directory;
            include_time_reversal = false,
        )
        eig_file = joinpath(directory, "fixture.eig")
        energies = reshape([1.0, 2.0, 3.0], 1, 3)
        WannierNLQG.IO.write_wannier_eig(eig_file, WannierNLQG.IO.WannierEIG(1, 3, energies))
        extension = HOP_PAW_EXTENSION
        oracle_mmn = joinpath(directory, "operator-oracle.mmn")
        WannierNLQG.IO.write_wannier_mmn(
            oracle_mmn,
            WannierNLQG.IO.WannierMMN(
                1,
                3,
                1,
                ones(ComplexF64, 1, 1, 1, 3),
                reshape(collect(1:3), 1, 3),
                zeros(Int, 3, 1, 3),
            ),
        )
        solver_mmn = joinpath(directory, "solver.mmn")
        cp(oracle_mmn, solver_mmn)
        identity_gauge = extension.generation_band_gauge_contract(
            source,
            HOP_WANNIERIZATION.NativeDFTHamiltonian(),
            nothing,
            1,
            3;
            construction_policy = :diagnostic,
        )
        authority_mismatch_target = HOP_WANNIERIZATION.WannierOperatorTargetContract(
            oracle_mmn,
            bytes2hex(SHA.sha256(read(oracle_mmn))),
            solver_mmn,
            bytes2hex(SHA.sha256(read(solver_mmn))),
            identity_gauge.source_band_gauge,
            identity_gauge.target_band_gauge,
            identity_gauge.transform_sha256,
            identity_gauge.contract_sha256,
            "NOT_APPLICABLE",
            "symmetrized_dft_hamiltonian",
            repeat("a", 64),
            1,
            3,
            1,
        )
        HOP_PREFLIGHT_SOURCE_CALLS[] = 0
        authority_mismatch_error = try
            HOP_WANNIERIZATION.generate_wannier_uhu(
                HOP_WANNIERIZATION.WannierHamiltonianOperatorGenerationConfig(
                    source = HOPPreflightCountingSource(),
                    topology_file = fixture.nnkp_file,
                    eig_file = eig_file,
                    output_file = joinpath(directory, "authority-mismatch.uHu"),
                    target_contract = authority_mismatch_target,
                    max_cached_wavefunction_kpoints = 2,
                ),
            )
            nothing
        catch exception
            exception
        end
        @test authority_mismatch_error isa ArgumentError
        @test occursin("Hamiltonian authority differs", sprint(showerror, authority_mismatch_error))
        @test HOP_PREFLIGHT_SOURCE_CALLS[] == 0

        gauge_file = joinpath(directory, "gauge.h5")
        write(gauge_file, "gauge artifact fixture")
        gauge_mismatch_target = HOP_WANNIERIZATION.WannierOperatorTargetContract(
            oracle_mmn,
            bytes2hex(SHA.sha256(read(oracle_mmn))),
            solver_mmn,
            bytes2hex(SHA.sha256(read(solver_mmn))),
            "native_dft_eigenstate",
            "sawf_completed_native_dft",
            identity_gauge.transform_sha256,
            identity_gauge.contract_sha256,
            repeat("b", 64),
            "native_dft",
            repeat("a", 64),
            1,
            3,
            1,
        )
        HOP_PREFLIGHT_SOURCE_CALLS[] = 0
        gauge_mismatch_error = try
            HOP_WANNIERIZATION.generate_wannier_uhu(
                HOP_WANNIERIZATION.WannierHamiltonianOperatorGenerationConfig(
                    source = HOPPreflightCountingSource(),
                    topology_file = fixture.nnkp_file,
                    eig_file = eig_file,
                    output_file = joinpath(directory, "gauge-mismatch.uHu"),
                    wavefunction_gauge_hdf5 = gauge_file,
                    target_contract = gauge_mismatch_target,
                    max_cached_wavefunction_kpoints = 2,
                ),
            )
            nothing
        catch exception
            exception
        end
        @test gauge_mismatch_error isa ArgumentError
        @test occursin("gauge artifact digest differs", sprint(showerror, gauge_mismatch_error))
        @test HOP_PREFLIGHT_SOURCE_CALLS[] == 0
        qe_spn_file = joinpath(directory, "qe-native.spn")
        qe_spn = HOP_WANNIERIZATION.generate_qe_paw_spn(
            source,
            fixture.nnkp_file;
            output_spn_file = qe_spn_file,
            provenance_json = qe_spn_file * ".json",
            max_cached_wavefunction_kpoints = 2,
        )
        @test qe_spn.passed
        @test qe_spn.spn !== nothing
        @test isfile(qe_spn_file)
        @test maximum(abs, something(qe_spn.spn).data[:, :, 1:2, :]; init = 0.0) <= 1.0e-12
        @test something(qe_spn.spn).data[1, 1, 3, :] ≈ ones(3) atol = 1.0e-12 rtol = 0.0
        qe_spn_provenance = JSON3.read(read(qe_spn.provenance_json, String))
        @test qe_spn_provenance.schema == "wanniernlqg.qe-paw-spn"
        @test qe_spn_provenance.schema_version == "1.0"
        @test qe_spn_provenance.algorithm_version ==
              "pw2wannier90-compute-spin-paw-q0-v3-frame-contract-bound"
        @test qe_spn_provenance.status == "PASS"
        @test qe_spn_provenance.source_band_gauge == "native_dft_eigenstate"
        @test qe_spn_provenance.target_band_gauge == "native_dft_eigenstate"
        @test qe_spn_provenance.band_frame_transform_sha256 ==
              qe_spn_provenance.band_gauge_rotation_sha256
        @test qe_spn_provenance.band_frame_contract.status == "PASS"
        @test qe_spn_provenance.band_frame_contract.metric_kind == "not_applicable_native_identity"
        @test qe_spn_provenance.artifacts.spn_sha256 == bytes2hex(SHA.sha256(read(qe_spn_file)))
        extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).PAWMatrixElements
        normalized = extension.read_qe_paw_spn_provenance(qe_spn.provenance_json)
        @test normalized.num_bands == 1
        @test normalized.num_kpoints == 3
        tampered_provenance = joinpath(directory, "qe-native-tampered.json")
        tampered_payload = JSON3.read(read(qe_spn.provenance_json, String), Dict{String, Any})
        tampered_payload["physical_metric"] = "tampered"
        open(tampered_provenance, "w") do stream
            JSON3.write(stream, tampered_payload)
        end
        @test_throws ArgumentError extension.read_qe_paw_spn_provenance(
            tampered_provenance;
            verify_spn = false,
        )
        oracle_spn = HOP_WANNIERIZATION.generate_qe_paw_spn(
            source,
            fixture.nnkp_file;
            output_spn_file = joinpath(directory, "qe-native-oracle.spn"),
            provenance_json = joinpath(directory, "qe-native-oracle.json"),
            oracle_spn_file = qe_spn_file,
            require_oracle = true,
            max_cached_wavefunction_kpoints = 2,
        )
        @test oracle_spn.passed
        @test something(oracle_spn.oracle_parity).max_absolute == 0.0
        uhu_file = joinpath(directory, "fixture.uHu")
        uhu_config = _hop_native_config(source, fixture, eig_file, uhu_file)
        @test uhu_config.construction_policy == :diagnostic
        operator_export =
            Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).OperatorExport
        @test_throws ArgumentError operator_export._hamiltonian_operator_paths(
            _hop_native_config(
                source,
                fixture,
                eig_file,
                joinpath(directory, "invalid-policy.uHu");
                construction_policy = :invalid,
            ),
        )
        protected_wfc = joinpath(fixture.save_directory, "wfc1.hdf5")
        protected_wfc_sha256 = bytes2hex(SHA.sha256(read(protected_wfc)))
        protected_collision = try
            HOP_WANNIERIZATION.generate_wannier_uhu(
                _hop_native_config(source, fixture, eig_file, protected_wfc; overwrite = true),
            )
            nothing
        catch exception
            exception
        end
        @test protected_collision isa ArgumentError
        @test occursin(
            "GENERATOR_PROTECTED_INPUT_COLLISION",
            sprint(showerror, protected_collision),
        )
        @test bytes2hex(SHA.sha256(read(protected_wfc))) == protected_wfc_sha256
        protected_spn_sha256 = bytes2hex(SHA.sha256(read(qe_spn_file)))
        spn_collision = try
            HOP_WANNIERIZATION.generate_wannier_siu(
                _hop_native_config(
                    source,
                    fixture,
                    eig_file,
                    qe_spn_file;
                    spn_file = qe_spn_file,
                    spn_provenance_file = qe_spn.provenance_json,
                    overwrite = true,
                ),
            )
            nothing
        catch exception
            exception
        end
        @test spn_collision isa ArgumentError
        @test occursin("GENERATOR_PROTECTED_INPUT_COLLISION", sprint(showerror, spn_collision))
        @test bytes2hex(SHA.sha256(read(qe_spn_file))) == protected_spn_sha256
        uhu = HOP_WANNIERIZATION.generate_wannier_uhu(uhu_config)
        @test uhu.passed
        @test uhu.operator == :uHu
        @test uhu.closure_residual <= 1.0e-12
        @test isfile(uhu_file)
        uhu_blocks = Tuple{Int, Int, Int, Matrix{ComplexF64}}[]
        WannierNLQG.IO.foreach_wannier_uhu_block(uhu_file) do block, center, second, first, _
            push!(uhu_blocks, (center, second, first, block))
        end
        @test length(uhu_blocks) == 3
        @test [only(block) for (_, _, _, block) in uhu_blocks] == ComplexF64[1, 2, 3]
        uhu_provenance = JSON3.read(read(uhu.provenance_json, String))
        @test uhu_provenance.status == "PASS"
        @test uhu_provenance.construction_policy == "diagnostic"
        @test uhu_provenance.model_qualification == "DIAGNOSTIC_ONLY"
        @test uhu_provenance.manual_review_required
        @test !uhu_provenance.production_eligible
        @test uhu_provenance.record_order == "ik->nn2->nn1"
        @test uhu_provenance.authoritative_hamiltonian == "native_dft"
        @test uhu_provenance.schema_version == "1.0"
        @test uhu_provenance.source_generation_qualified
        @test uhu_provenance.artifact_published
        @test uhu_provenance.diagnostic_reference_status == "WITHIN_REFERENCE"
        @test uhu_provenance.actual_operator_error_status ==
              "NOT_AVAILABLE_WITHOUT_COMPLEMENT_HAMILTONIAN_OR_NBANDS_REFERENCE"
        @test uhu_provenance.nbands_convergence_status == "NOT_ESTABLISHED"
        @test uhu_provenance.galerkin_block_audit.exchange_hermiticity_status == "PASS"
        @test uhu_provenance.galerkin_block_audit.maximum_frobenius_product_bound_slack_fraction >=
              0.0
        @test uhu_provenance.galerkin_cancellation_audit.status ==
              "NOT_AVAILABLE_BEFORE_FINAL_WANNIER_PROFILE_ASSEMBLY"
        @test uhu_provenance.galerkin_cancellation_audit.cancellation_ratio === nothing
        @test uhu_provenance.source_band_gauge == "native_dft_eigenstate"
        @test uhu_provenance.target_band_gauge == "native_dft_eigenstate"
        @test uhu_provenance.gauge_artifact_sha256 == "NOT_APPLICABLE"
        @test uhu_provenance.band_frame_contract.status == "PASS"
        @test uhu_provenance.band_frame_transform_sha256 ==
              uhu_provenance.band_gauge_rotation_sha256
        @test uhu_provenance.output_sha256 !== nothing

        missing_spn_output = joinpath(directory, "missing-spn-must-not-publish.sIu")
        missing_spn_error = try
            HOP_WANNIERIZATION.generate_wannier_siu(
                _hop_native_config(source, fixture, eig_file, missing_spn_output),
            )
            nothing
        catch exception
            exception
        end
        @test missing_spn_error isa ArgumentError
        @test occursin("SPN_FILE_REQUIRED", sprint(showerror, missing_spn_error))
        @test !ispath(missing_spn_output)
        @test !ispath(missing_spn_output * ".provenance.json")

        for (operator, suffix, expected_factor, generator, reader) in (
            (
                :sIu,
                "sIu",
                (spin, energy) -> spin,
                HOP_WANNIERIZATION.generate_wannier_siu,
                WannierNLQG.IO.foreach_wannier_siu_block,
            ),
            (
                :sHu,
                "sHu",
                (spin, energy) -> spin * energy,
                HOP_WANNIERIZATION.generate_wannier_shu,
                WannierNLQG.IO.foreach_wannier_shu_block,
            ),
        )
            output = joinpath(directory, "fixture.$(suffix)")
            result = generator(
                _hop_native_config(
                    source,
                    fixture,
                    eig_file,
                    output;
                    spn_file = qe_spn_file,
                    spn_provenance_file = qe_spn.provenance_json,
                ),
            )
            @test result.passed
            @test result.operator == operator
            blocks = Tuple{Int, Int, Int, Matrix{ComplexF64}}[]
            reader(output) do block, center, neighbor, ispol, _
                push!(blocks, (center, neighbor, ispol, block))
            end
            @test length(blocks) == 9
            for (center, neighbor, ispol, block) in blocks
                @test neighbor == 1
                native_spin = ispol == 3 ? 1.0 : 0.0
                @test only(block) == expected_factor(native_spin, energies[1, center])
            end
            sidecar = JSON3.read(read(result.provenance_json, String))
            @test sidecar.schema_version == "1.0"
            @test sidecar.source_generation_qualified
            @test sidecar.artifact_published
            @test sidecar.galerkin_block_audit.exchange_hermiticity_status == "NOT_APPLICABLE"
            @test sidecar.band_frame_contract.status == "PASS"
            @test sidecar.spn_provenance_sha256 ==
                  bytes2hex(SHA.sha256(read(qe_spn.provenance_json)))
        end

        formatted_file = joinpath(directory, "fixture-formatted.uHu")
        formatted = HOP_WANNIERIZATION.generate_wannier_uhu(
            _hop_native_config(source, fixture, eig_file, formatted_file; formatted = true),
        )
        @test formatted.passed
        formatted_blocks = Matrix{ComplexF64}[]
        WannierNLQG.IO.foreach_wannier_uhu_block(formatted_file; formatted = true) do block, _...
            push!(formatted_blocks, block)
        end
        @test [only(block) for block in formatted_blocks] == ComplexF64[1, 2, 3]
    end
end

@testset "band-gauge endpoint rotations" begin
    parent_extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)
    extension = parent_extension.PAWMatrixElements
    operator_export = parent_extension.OperatorExport
    phase = exp(0.37im)
    u1 = ComplexF64[1 0; 0 phase]
    u2 = ComplexF64[0 1; 1 0] * ComplexF64[phase 0; 0 1]
    operator = ComplexF64[1 + 0.2im 2 - 0.3im; -0.4 + 0.1im 0.7]
    @test extension._rotate_single_point_operator(operator, u1) == u1' * operator * u1
    @test extension._rotate_link_operator(operator, u1, u2) == u1' * operator * u2
    @test extension._rotate_double_endpoint_operator(operator, u1, u2) == u1' * operator * u2

    nonunitary_transform = ComplexF64[1.000001 0.2im; 0 0.999999]
    eig = WannierNLQG.IO.WannierEIG(2, 1, reshape([-2.0, 3.0], 2, 1))
    transformed = operator_export._native_completed_frame_hamiltonian_matrices(
        eig,
        (transforms = reshape(nonunitary_transform, 2, 2, 1),),
    )
    native = Matrix(Diagonal([-2.0, 3.0]))
    @test transformed[:, :, 1] == nonunitary_transform' * native * nonunitary_transform
    @test transformed[:, :, 1] != native
end

@testset "VASP uHu route fails closed without the complete PAW source" begin
    mktempdir() do directory
        fixture = write_qe_paw_fixture(
            directory;
            metric_kind = :paw,
            spinor = true,
            spinorbit = true,
            num_kpoints = 2,
        )
        eig_file = joinpath(directory, "fixture.eig")
        WannierNLQG.IO.write_wannier_eig(
            eig_file,
            WannierNLQG.IO.WannierEIG(1, 2, reshape([1.0, 2.0], 1, 2)),
        )
        source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
            joinpath(directory, "POSCAR"),
            joinpath(directory, "WAVECAR"),
        )
        output = joinpath(directory, "must-not-exist.uHu")
        error = try
            HOP_WANNIERIZATION.generate_wannier_uhu(
                _hop_native_config(source, fixture, eig_file, output),
            )
            nothing
        catch caught
            caught
        end
        @test error isa ArgumentError
        @test occursin("VASP_PAW_DATA_REQUIRED", sprint(showerror, error))
        @test !ispath(output)
        @test !ispath(output * ".provenance.json")
    end
end

@testset "finite-band leakage above reference remains an auditable published Galerkin source" begin
    mktempdir() do directory
        fixture = write_qe_paw_fixture(
            directory;
            metric_kind = :paw,
            spinor = true,
            spinorbit = true,
            num_kpoints = 2,
        )
        HDF5.h5open(joinpath(fixture.save_directory, "wfc2.hdf5"), "r+") do handle
            handle["evc"][:, :] = reshape([0.0, 0.0, 1.0, 0.0], 4, 1)
        end
        nnkp_text = read(fixture.nnkp_file, String)
        nnkp_text = replace(
            nnkp_text,
            "      1 1 0 0 0\n      2 2 0 0 0" => "      1 2 0 0 0\n      2 1 0 0 0",
        )
        write(fixture.nnkp_file, nnkp_text)
        source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
            fixture.save_directory;
            include_time_reversal = false,
        )
        eig_file = joinpath(directory, "fixture.eig")
        WannierNLQG.IO.write_wannier_eig(
            eig_file,
            WannierNLQG.IO.WannierEIG(1, 2, reshape([1.0, 2.0], 1, 2)),
        )
        output = joinpath(directory, "leakage-audited.uHu")
        result = HOP_WANNIERIZATION.generate_wannier_uhu(
            _hop_native_config(source, fixture, eig_file, output; closure_tolerance = 1.0e-6),
        )
        @test result.passed
        @test result.source_generation_qualified
        @test result.artifact_published
        @test result.output_file == abspath(output)
        @test result.closure_residual > result.closure_tolerance
        @test result.diagnostic_reference_status == "ABOVE_REFERENCE"
        @test isfile(output)
        @test isfile(result.provenance_json)
        provenance = JSON3.read(read(result.provenance_json, String))
        @test provenance.status == "PASS"
        @test provenance.source_generation_qualified
        @test provenance.artifact_published
        @test provenance.diagnostic_reference == 1.0e-6
        @test provenance.diagnostic_reference_status == "ABOVE_REFERENCE"
        @test provenance.outer_probability_leakage_audit_status == "ABOVE_REFERENCE"
        @test provenance.actual_operator_error_status ==
              "NOT_AVAILABLE_WITHOUT_COMPLEMENT_HAMILTONIAN_OR_NBANDS_REFERENCE"
        @test provenance.nbands_convergence_status == "NOT_ESTABLISHED"
        @test provenance.suggested_minimum_nbands === nothing
        @test "FINITE_BAND_TRUNCATION_AUDIT_ONLY" in provenance.diagnostics
    end
end

@testset "uHu exchange-Hermiticity is a structural hard gate" begin
    extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).OperatorExport
    diagonal_first = ComplexF64[1 2im; -2im 3]
    off_diagonal = ComplexF64[0.5 1; -0.2im 0.7]
    diagonal_second = ComplexF64[2 0; 0 4]
    good = reshape(
        Matrix{ComplexF64}[diagonal_first, off_diagonal', off_diagonal, diagonal_second],
        2,
        2,
    )
    good_audit = extension._hamiltonian_operator_uhu_exchange_hermiticity(good, 1.0e-12)
    @test good_audit.status == "PASS"
    @test good_audit.maximum_residual == 0.0

    bad = copy(good)
    bad[2, 1] = copy(bad[2, 1])
    bad[2, 1][1, 2] += 1.0e-4
    bad_audit = extension._hamiltonian_operator_uhu_exchange_hermiticity(bad, 1.0e-12)
    @test bad_audit.status == "FAILED"
    @test bad_audit.maximum_residual > bad_audit.tolerance

    bad[1, 1][1, 1] = NaN
    @test_throws ArgumentError extension._hamiltonian_operator_uhu_exchange_hermiticity(
        bad,
        1.0e-12,
    )
end
