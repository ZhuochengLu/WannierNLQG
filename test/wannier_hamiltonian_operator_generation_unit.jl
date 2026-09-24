using EzXML
using HDF5
using JSON3
using LinearAlgebra
using SHA
using Serialization
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

function _hop_verify_publication_recovery(config, operator)
    original = bytes2hex(SHA.sha256(read(config.output_file)))
    mv(config.provenance_json, config.provenance_json * ".before-interruption")
    serialized = config.output_file * ".config.bin"
    serialize(serialized, config)
    code = """
    using WannierNLQG,HDF5,JSON3,EzXML,Spglib,Serialization,LinearAlgebra
    BLAS.set_num_threads(1)
    W=WannierNLQG.Wannierization
    E=first(W._load_wannierization_extension!()).OperatorExport
    @eval E function _operator_center_checkpoint(builder,validator,config,operator,contract,center)
        path=joinpath(config.execution.checkpoint_directory,string(operator),"center-"*string(center)*".bin")
        payload=IO.read_preparation_checkpoint(path,contract*":"*string(center))
        payload === nothing && error("CENTER_RECOMPUTATION_FORBIDDEN")
        validator(payload) || error("INVALID_CHECKPOINT")
        return payload
    end
    config=deserialize(ARGS[1])
    result=getproperty(W,Symbol("generate_wannier_"*ARGS[2]))(config)
    @assert result.artifact_published
    println("FRESH_OPERATOR_PUBLICATION_RECOVERY_PASS")
    """
    command =
        `$(Base.julia_cmd()) --startup-file=no --project=$(dirname(Base.active_project())) --threads=$(Threads.nthreads()) -e $code $serialized $(lowercase(string(operator)))`
    @test occursin("FRESH_OPERATOR_PUBLICATION_RECOVERY_PASS", read(command, String))
    @test bytes2hex(SHA.sha256(read(config.output_file))) == original
    @test isfile(config.provenance_json)
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
            status = "STANDARD",
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
            construction_policy = :standard,
        )
        @test diagnostic_scope.outer_mask == outer_mask
        # The production gauge writer serializes :STANDARD as DIAGNOSTIC_ONLY.
        wire_artifact = _hop_write_scope_artifact(
            joinpath(directory, "wire-diagnostic-scope.h5"),
            outer_mask;
            status = "DIAGNOSTIC_ONLY",
        )
        wire_bytes = read(wire_artifact)
        wire_contract = _hop_scope_contract(bytes2hex(SHA.sha256(wire_bytes)))
        wire_scope = extension._hamiltonian_operator_closure_scope(
            wire_artifact,
            wire_contract,
            topology;
            construction_policy = :standard,
        )
        @test wire_scope.outer_mask == diagnostic_scope.outer_mask
        @test wire_scope.frozen_mask == diagnostic_scope.frozen_mask
        @test wire_scope.outer_mask_sha256 == diagnostic_scope.outer_mask_sha256
        @test wire_scope.frozen_mask_sha256 == diagnostic_scope.frozen_mask_sha256
        @test read(wire_artifact) == wire_bytes
        @test_throws ArgumentError extension._hamiltonian_operator_closure_scope(
            wire_artifact,
            wire_contract,
            topology;
            construction_policy = :strict,
        )
        for status in ("FAIL", "INCOMPLETE", "UNKNOWN")
            rejected = _hop_write_scope_artifact(
                joinpath(directory, "rejected-$(status).h5"),
                outer_mask;
                status,
            )
            rejected_contract = _hop_scope_contract(bytes2hex(SHA.sha256(read(rejected))))
            @test_throws ArgumentError extension._hamiltonian_operator_closure_scope(
                rejected,
                rejected_contract,
                topology;
                construction_policy = :standard,
            )
        end
        for (label, options, message) in (
            ("digest", (; outer_digest = repeat("0", 64)), "CLOSURE_SCOPE_MASK_DIGEST_MISMATCH"),
            ("missing", (; include_scope = false), "CLOSURE_QUALIFICATION_SCOPE_REQUIRED"),
        )
            invalid = _hop_write_scope_artifact(
                joinpath(directory, "invalid-wire-$(label).h5"),
                outer_mask;
                status = "DIAGNOSTIC_ONLY",
                options...,
            )
            invalid_contract = _hop_scope_contract(bytes2hex(SHA.sha256(read(invalid))))
            caught = try
                extension._hamiltonian_operator_closure_scope(
                    invalid,
                    invalid_contract,
                    topology;
                    construction_policy = :standard,
                )
                nothing
            catch exception
                exception
            end
            @test caught isa ArgumentError
            @test occursin(message, sprint(showerror, caught))
        end
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
            construction_policy = :standard,
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
        before_spn_reuse = stat(qe_spn_file)
        expected_spn_digest = extension._star_array_sha256(something(qe_spn.spn).data)
        spn_reuse_code = """
        using WannierNLQG,HDF5,JSON3,EzXML,Spglib,LinearAlgebra
        W=WannierNLQG.Wannierization
        E=first(W._load_wannierization_extension!()).PAWMatrixElements
        @eval E _uiu_qe_state(source::QuantumEspressoWavefunctionSource, topology, cache_size) = error("COMPLETED_QE_SPN_PREPARATION_FORBIDDEN")
        source=WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(ARGS[1];include_time_reversal=false)
        result=W.generate_qe_paw_spn(source,ARGS[2];output_spn_file=ARGS[3],
            provenance_json=ARGS[3]*".json",max_cached_wavefunction_kpoints=2)
        @assert result.passed
        @assert E._star_array_sha256(something(result.spn).data) == ARGS[4]
        println("QE_SPN_COMPLETE_FRESH_REUSE_PASS")
        """
        spn_child =
            `$(Base.julia_cmd()) --startup-file=no --project=$(dirname(Base.active_project())) --threads=$(Threads.nthreads()) -e $spn_reuse_code $(fixture.save_directory) $(fixture.nnkp_file) $qe_spn_file $expected_spn_digest`
        @test occursin("QE_SPN_COMPLETE_FRESH_REUSE_PASS", read(spn_child, String))
        after_spn_reuse = stat(qe_spn_file)
        # ctime can change from filesystem metadata; content digests below, inode,
        # mtime and size establish the publication invariants.
        @test (before_spn_reuse.inode, before_spn_reuse.mtime, before_spn_reuse.size) ==
              (after_spn_reuse.inode, after_spn_reuse.mtime, after_spn_reuse.size)
        @test maximum(abs, something(qe_spn.spn).data[:, :, 1:2, :]; init = 0.0) <= 1.0e-12
        @test something(qe_spn.spn).data[1, 1, 3, :] ≈ ones(3) atol = 1.0e-12 rtol = 0.0
        qe_spn_provenance = JSON3.read(read(qe_spn.provenance_json, String))
        @test qe_spn_provenance.schema == "wanniernlqg.qe-paw-spn"
        @test qe_spn_provenance.schema_version == "1.1"
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
        uhu_config = _hop_native_config(
            source,
            fixture,
            eig_file,
            uhu_file;
            execution = HOP_WANNIERIZATION.WavefunctionPreparationExecutionConfig(
                checkpoint_directory = joinpath(directory, "operator-checkpoints"),
            ),
        )
        @test uhu_config.construction_policy == :standard
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
        before_resume = stat(uhu_file)
        reused_uhu = HOP_WANNIERIZATION.generate_wannier_uhu(uhu_config)
        after_resume = stat(uhu_file)
        @test (before_resume.inode, before_resume.mtime, before_resume.size) ==
              (after_resume.inode, after_resume.mtime, after_resume.size)
        @test reused_uhu.input_sha256 == uhu.input_sha256
        _hop_verify_publication_recovery(uhu_config, :uHu)
        uhu_blocks = Tuple{Int, Int, Int, Matrix{ComplexF64}}[]
        WannierNLQG.IO.foreach_wannier_uhu_block(uhu_file) do block, center, second, first, _
            push!(uhu_blocks, (center, second, first, block))
        end
        @test length(uhu_blocks) == 3
        @test [only(block) for (_, _, _, block) in uhu_blocks] == ComplexF64[1, 2, 3]
        uhu_provenance = JSON3.read(read(uhu.provenance_json, String))
        @test uhu_provenance.status == "PASS"
        @test uhu_provenance.construction_policy == "standard"
        @test uhu_provenance.model_qualification == "STANDARD"
        @test uhu_provenance.quality_review_recommended
        @test !uhu_provenance.production_eligible
        @test uhu_provenance.record_order == "ik->nn2->nn1"
        @test uhu_provenance.authoritative_hamiltonian == "native_dft"
        @test uhu_provenance.schema_version == "1.1"
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
            operator_config = _hop_native_config(
                source,
                fixture,
                eig_file,
                output;
                spn_file = qe_spn_file,
                spn_provenance_file = qe_spn.provenance_json,
                execution = HOP_WANNIERIZATION.WavefunctionPreparationExecutionConfig(
                    checkpoint_directory = joinpath(directory, "operator-checkpoints"),
                ),
            )
            result = generator(operator_config)
            before_resume = stat(output)
            reused = generator(operator_config)
            after_resume = stat(output)
            @test (before_resume.inode, before_resume.mtime, before_resume.size) ==
                  (after_resume.inode, after_resume.mtime, after_resume.size)
            @test reused.input_sha256 == result.input_sha256
            _hop_verify_publication_recovery(operator_config, operator)
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
            @test sidecar.schema_version == "1.1"
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

@testset "Operator target MMN role reuse preserves live validation" begin
    extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).OperatorExport
    mktempdir() do directory
        mmn = WannierNLQG.IO.WannierMMN(
            1,
            2,
            1,
            ones(ComplexF64, 1, 1, 1, 2),
            reshape([1, 2], 1, 2),
            zeros(Int, 3, 1, 2),
        )
        path = joinpath(directory, "accepted.mmn")
        WannierNLQG.IO.write_wannier_mmn(path, mmn)
        alias = joinpath(directory, "solver.mmn")
        symlink(path, alias)
        reads = Ref(0)
        hashes = Ref(0)
        reader = p -> begin
            reads[] += 1
            WannierNLQG.IO.read_wannier_mmn_topology(p)
        end
        hasher = p -> begin
            hashes[] += 1
            bytes2hex(SHA.sha256(read(p)))
        end
        before = read(path)
        identities = extension._operator_mmn_file_identities(
            mmn,
            path,
            alias;
            topology_reader = reader,
            file_hasher = hasher,
        )
        @test reads[] == hashes[] == 1
        @test identities[realpath(path)] == bytes2hex(SHA.sha256(before))
        @test read(path) == before
        copy_path = joinpath(directory, "separate.mmn")
        cp(path, copy_path)
        extension._operator_mmn_file_identities(
            mmn,
            path,
            copy_path;
            topology_reader = reader,
            file_hasher = hasher,
        )
        @test reads[] == hashes[] == 3
        # The registry is scoped to this validation, never a stale path-only global cache.
        changed = WannierNLQG.IO.WannierMMN(
            1,
            2,
            1,
            ones(ComplexF64, 1, 1, 1, 2),
            reshape([2, 1], 1, 2),
            zeros(Int, 3, 1, 2),
        )
        WannierNLQG.IO.write_wannier_mmn(copy_path, changed)
        @test_throws ArgumentError extension._operator_mmn_file_identities(mmn, path, copy_path)
    end
end

@testset "Compact beta cache has bounded bytes and exact reuse" begin
    extension = HOP_PAW_EXTENSION
    value = reshape(ComplexF64[1 + 2im, 3 - 4im], 2, 1, 1)
    bytes = Base.summarysize(value)
    cache = extension.QEBetaOverlapCache(bytes)
    builds = Ref(0)
    builder = () -> (builds[] += 1; copy(value))
    first_value = extension._qe_cached_beta_overlap!(builder, cache, 1)
    @test extension._qe_cached_beta_overlap!(builder, cache, 1) === first_value
    @test builds[] == 1
    @test first_value == value
    @test cache.resident_bytes <= bytes
    @test extension._qe_cached_beta_overlap!(builder, cache, 2) == value
    @test !haskey(cache.entries, 1)
    @test cache.resident_bytes <= bytes
    @test extension._qe_cached_beta_overlap!(builder, cache, 1) == value
    @test builds[] == 3
    disabled = extension.QEBetaOverlapCache(0)
    @test extension._qe_cached_beta_overlap!(builder, disabled, 1) == value
    @test isempty(disabled.entries)
    @test disabled.resident_bytes == 0
    @test_throws ArgumentError extension.QEBetaOverlapCache(-1)
    @test_throws ArgumentError extension._qe_cached_beta_overlap!(
        () -> fill(ComplexF64(NaN), 2, 1, 1),
        cache,
        3,
    )
    @test !haskey(cache.entries, 3)
    @test first_value == value
end

@testset "Declared input digest registry is execution scoped" begin
    foundation = WannierNLQG.SymmetryFoundation
    mktempdir() do directory
        path = joinpath(directory, "input")
        alias = joinpath(directory, "alias")
        write(path, "accepted input")
        symlink(path, alias)
        expected = bytes2hex(SHA.sha256(read(path)))
        calls = Ref(0)
        hasher = p -> (calls[] += 1; bytes2hex(SHA.sha256(read(p))))
        foundation.with_verified_file_digests([path, alias]; file_hasher = hasher) do
            @test calls[] == 1
            @test foundation.sha256_file(path) == expected
            @test foundation.sha256_file(alias) == expected
            inner = joinpath(directory, "inner")
            write(inner, "inner input")
            outer_registry = get(task_local_storage(), :wannier_verified_file_digests, nothing)
            foundation.with_verified_file_digests([inner]; file_hasher = hasher) do
                @test calls[] == 2
                @test foundation.sha256_file(path) == expected
                @test foundation.sha256_file(alias) == expected
                @test foundation.sha256_file(inner) == bytes2hex(SHA.sha256(read(inner)))
                @test length(get(task_local_storage(), :wannier_verified_file_digests, nothing)) ==
                      2
            end
            @test get(task_local_storage(), :wannier_verified_file_digests, nothing) ===
                  outer_registry
            @test length(outer_registry) == 1
            foundation.with_verified_file_digests([alias]; file_hasher = hasher) do
                @test calls[] == 2
                @test foundation.sha256_file(path) == expected
            end
            output = joinpath(directory, "output")
            write(output, "first")
            first_digest = foundation.sha256_file(output)
            write(output, "second")
            @test foundation.sha256_file(output) != first_digest
            write(path, "changed input with different length")
            @test_throws ArgumentError foundation.sha256_file(path)
            @test_throws ArgumentError foundation.with_verified_file_digests(
                [alias];
                file_hasher = hasher,
            ) do
                error("changed inherited input must not enter callback")
            end
        end
        @test foundation.sha256_file(path) == bytes2hex(SHA.sha256(read(path)))
        @test get(task_local_storage(), :wannier_verified_file_digests, nothing) === nothing
        @test_throws ErrorException foundation.with_verified_file_digests([path]) do
            error("scope failure")
        end
        @test get(task_local_storage(), :wannier_verified_file_digests, nothing) === nothing
        @test_throws ArgumentError foundation.with_verified_file_digests(
            [path];
            file_hasher = p -> begin
                write(p, "changed while hashing")
                expected
            end,
        ) do
            error("must not enter callback")
        end
    end
end

@testset "QE operator preparation scope reuses native state exactly" begin
    extension = HOP_PAW_EXTENSION
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
        baseline = extension._uiu_qe_state(source, fixture.nnkp_file, 2)
        expected = [baseline.spn_block(k) for k in 1:3]
        extension._with_qe_operator_preparation(source, fixture.nnkp_file, 2) do
            state = extension._uiu_qe_state(source, fixture.nnkp_file, 2)
            next_state = extension._uiu_source_state(source, fixture.nnkp_file, 2)
            @test state.wavefunction_cache === next_state.wavefunction_cache
            @test state.beta_cache === next_state.beta_cache
            outer_context = get(task_local_storage(), :wannier_qe_operator_preparation, nothing)
            extension._with_qe_operator_preparation(source, fixture.nnkp_file, 2) do
                @test get(task_local_storage(), :wannier_qe_operator_preparation, nothing) ===
                      outer_context
                nested = extension._uiu_qe_state(source, fixture.nnkp_file, 2)
                @test nested.wavefunction_cache === state.wavefunction_cache
                @test nested.beta_cache === state.beta_cache
                @test nested.input_sha256 !== state.input_sha256
                @test nested.spn_block(1) == expected[1]
            end
            @test_throws ErrorException extension._with_qe_operator_preparation(
                source,
                fixture.nnkp_file,
                2,
            ) do
                error("intentional nested preparation failure")
            end
            @test get(task_local_storage(), :wannier_qe_operator_preparation, nothing) ===
                  outer_context

            @test state.input_sha256 !== next_state.input_sha256
            @test state.diagnostics !== next_state.diagnostics
            state.input_sha256["OPERATOR_TARGET_CONTRACT"] = "stage-local"
            push!(state.diagnostics, "STAGE_LOCAL_DIAGNOSTIC")
            @test next_state.input_sha256 == baseline.input_sha256
            @test !("STAGE_LOCAL_DIAGNOSTIC" in next_state.diagnostics)
            @test extension._uiu_qe_state(source, fixture.nnkp_file, 2).input_sha256 ==
                  baseline.input_sha256
            delete!(state.input_sha256, "OPERATOR_TARGET_CONTRACT")
            @test state.input_sha256 == baseline.input_sha256
            @test state.generalized_norm == baseline.generalized_norm
            for k in 1:3
                @test state.spn_block(k) == expected[k]
            end
            @test_throws ArgumentError extension._uiu_qe_state(source, fixture.nnkp_file, 3)
            write(fixture.nnkp_file, read(fixture.nnkp_file, String) * "\n")
            @test_throws ArgumentError extension._uiu_qe_state(source, fixture.nnkp_file, 2)
        end
        @test get(task_local_storage(), :wannier_qe_operator_preparation, nothing) === nothing
        @test get(task_local_storage(), :wannier_verified_file_digests, nothing) === nothing
    end
end

@testset "SPN bounded workers and block resume preserve scientific arrays" begin
    extension = HOP_PAW_EXTENSION
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
        extension._with_qe_operator_preparation(source, fixture.nnkp_file, 2) do
            reference = nothing
            state = extension._uiu_qe_state(source, fixture.nnkp_file, 2)
            for workers in (1, 2, 4)
                checkpoint_directory = joinpath(directory, "blocks-$workers")
                execution = HOP_WANNIERIZATION.WavefunctionPreparationExecutionConfig(
                    mode = :streaming_threads,
                    max_workers = workers,
                    checkpoint_directory = checkpoint_directory,
                    resume = true,
                )
                output = joinpath(directory, "spin-$workers.spn")
                result = HOP_WANNIERIZATION.generate_qe_paw_spn(
                    source,
                    fixture.nnkp_file;
                    output_spn_file = output,
                    max_cached_wavefunction_kpoints = 2,
                    execution,
                )
                @test result.passed
                bytes = read(output)
                reference === nothing && (reference = bytes)
                @test bytes == reference
                before = state.wavefunction_cache.hits + state.wavefunction_cache.misses
                resumed = HOP_WANNIERIZATION.generate_qe_paw_spn(
                    source,
                    fixture.nnkp_file;
                    output_spn_file = output,
                    max_cached_wavefunction_kpoints = 2,
                    execution,
                    overwrite = true,
                )
                @test resumed.passed
                @test read(output) == bytes
                @test state.wavefunction_cache.hits + state.wavefunction_cache.misses == before
                # Interruption after SPN publication: keep the original bytes
                # and recover provenance entirely from verified checkpoint blocks.
                provenance_path = output * ".provenance.json"
                mv(provenance_path, provenance_path * ".before-interruption")
                recovered = HOP_WANNIERIZATION.generate_qe_paw_spn(
                    source,
                    fixture.nnkp_file;
                    output_spn_file = output,
                    max_cached_wavefunction_kpoints = 2,
                    execution,
                )
                @test recovered.passed
                @test read(output) == bytes
                @test state.wavefunction_cache.hits + state.wavefunction_cache.misses == before
                @test isfile(provenance_path)
                open(joinpath(checkpoint_directory, "qe-spn", "block-1.bin"), "a") do stream
                    write(stream, "corrupt")
                end
                repaired = HOP_WANNIERIZATION.generate_qe_paw_spn(
                    source,
                    fixture.nnkp_file;
                    output_spn_file = output,
                    max_cached_wavefunction_kpoints = 2,
                    execution,
                    overwrite = true,
                )
                @test repaired.passed
                @test read(output) == bytes
                @test state.wavefunction_cache.hits + state.wavefunction_cache.misses == before + 1
            end
        end
    end
end

@testset "Hamiltonian operator center checkpoints resume and invalidate" begin
    extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).OperatorExport
    mktempdir() do directory
        config = (
            execution = HOP_WANNIERIZATION.WavefunctionPreparationExecutionConfig(
                checkpoint_directory = directory,
                resume = true,
            ),
        )
        calls = Ref(0)
        value = reshape([reshape(ComplexF64[1 + 2im], 1, 1)], 1, 1)
        builder = () -> (calls[] += 1; deepcopy(value))
        validator = x -> size(x) == (1, 1) && all(y -> size(y) == (1, 1) && all(isfinite, y), x)
        for operator in (:uHu, :sIu, :sHu)
            before = calls[]
            first = extension._operator_center_checkpoint(
                builder,
                validator,
                config,
                operator,
                "bound-input-a",
                1,
            )
            @test first == value
            @test calls[] == before + 1
            @test extension._operator_center_checkpoint(
                builder,
                validator,
                config,
                operator,
                "bound-input-a",
                1,
            ) == first
            @test calls[] == before + 1
            @test extension._operator_center_checkpoint(
                builder,
                validator,
                config,
                operator,
                "bound-input-b",
                1,
            ) == first
            @test calls[] == before + 2
            open(joinpath(directory, string(operator), "center-1.bin"), "a") do stream
                write(stream, "truncated-or-corrupt")
            end
            @test extension._operator_center_checkpoint(
                builder,
                validator,
                config,
                operator,
                "bound-input-b",
                1,
            ) == first
            @test calls[] == before + 3
        end
        @test_throws ArgumentError extension._operator_center_checkpoint(
            () -> [fill(ComplexF64(NaN), 1, 1);;],
            validator,
            config,
            :uHu,
            "bad",
            2,
        )
        @test !isfile(joinpath(directory, "uHu", "center-2.bin"))
    end
end

@testset "Compact preparation artifacts persist without rebuilding" begin
    io_layer = WannierNLQG.IO
    mktempdir() do directory
        calls = Ref(0)
        original = ComplexF64[1 + 2im, 3 - 4im]
        builder = () -> (calls[] += 1; copy(original))
        io_layer.with_preparation_artifact_cache(directory, "implementation-a") do
            @test io_layer.cached_preparation_artifact(
                builder,
                "compact",
                () -> "inputs-a";
                build_missing = false,
            ) === nothing
            @test calls[] == 0
            result = io_layer.cached_preparation_artifact(builder, "compact", () -> "inputs-a")
            @test io_layer.cached_preparation_artifact(
                builder,
                "compact",
                () -> "inputs-a";
                build_missing = false,
            ) == original
            @test result == original
            result[1] = 0
            @test io_layer.cached_preparation_artifact(builder, "compact", () -> "inputs-a") ==
                  original
            @test calls[] == 1
        end
        code = "using WannierNLQG; WannierNLQG.IO.with_preparation_artifact_cache(ARGS[1], \"implementation-a\") do; value=WannierNLQG.IO.cached_preparation_artifact(() -> error(\"REBUILD_FORBIDDEN\"), \"compact\", () -> \"inputs-a\"); @assert value == ComplexF64[1+2im,3-4im]; println(\"FRESH_REUSE_PASS\"); end"
        command =
            `$(Base.julia_cmd()) --startup-file=no --project=$(dirname(@__DIR__)) -e $code $directory`
        @test strip(read(command, String)) == "FRESH_REUSE_PASS"
        io_layer.with_preparation_artifact_cache(directory, "implementation-a") do
            @test io_layer.cached_preparation_artifact(builder, "compact", () -> "inputs-b") ==
                  original
        end
        @test calls[] == 2
        io_layer.with_preparation_artifact_cache(directory, "implementation-b") do
            @test io_layer.cached_preparation_artifact(builder, "compact", () -> "inputs-a") ==
                  original
        end
        @test calls[] == 3
        @test get(task_local_storage(), :wannier_preparation_artifact_cache, nothing) === nothing
        @test_throws ArgumentError io_layer.with_preparation_artifact_cache(
            directory,
            "small";
            max_artifact_bytes = 1,
        ) do
            io_layer.cached_preparation_artifact(builder, "compact", () -> "inputs-a")
        end
    end
end

@testset "QE compact preparation skips repeated norm and beta contractions" begin
    extension = HOP_PAW_EXTENSION
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
        cache = joinpath(directory, "preparation")
        expected = Ref{Any}(nothing)
        reference_norm = Ref(0.0)
        extension._with_qe_operator_preparation(
            source,
            fixture.nnkp_file,
            2;
            checkpoint_directory = cache,
            implementation_contract = "fixture-implementation-v1",
        ) do
            state = extension._uiu_qe_state(source, fixture.nnkp_file, 2)
            @test state.normalization_points[] == 3
            @test state.beta_contractions[] == 3
            expected[] = [state.spn_block(k) for k in 1:3]
            reference_norm[] = state.generalized_norm
        end
        extension._with_qe_operator_preparation(
            source,
            fixture.nnkp_file,
            2;
            checkpoint_directory = cache,
            implementation_contract = "fixture-implementation-v1",
        ) do
            state = extension._uiu_qe_state(source, fixture.nnkp_file, 2)
            @test state.normalization_points[] == 0
            @test isempty(state.wavefunction_cache.load_counts)
            @test state.generalized_norm == reference_norm[]
            @test [state.spn_block(k) for k in 1:3] == expected[]
            @test state.beta_contractions[] == 0
        end
        code = "using WannierNLQG,HDF5,JSON3,EzXML,Spglib; W=WannierNLQG.Wannierization; E=first(W._load_wannierization_extension!()).PAWMatrixElements; source=WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(ARGS[1];include_time_reversal=false); E._with_qe_operator_preparation(source,ARGS[2],2;checkpoint_directory=ARGS[3],implementation_contract=\"fixture-implementation-v1\") do; state=E._uiu_qe_state(source,ARGS[2],2); @assert state.normalization_points[]==0; @assert isempty(state.wavefunction_cache.load_counts); state.spn_block(1); @assert state.beta_contractions[]==0; println(\"FRESH_QE_REUSE_PASS\"); end"
        command =
            `$(Base.julia_cmd()) --startup-file=no --project=$(dirname(@__DIR__)) -e $code $(fixture.save_directory) $(fixture.nnkp_file) $cache`
        @test strip(read(command, String)) == "FRESH_QE_REUSE_PASS"
    end
end

@testset "QE overlap cache restores before wavefunction access" begin
    extension = HOP_PAW_EXTENSION
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
        cache = joinpath(directory, "preparation")
        expected = Ref{Any}(nothing)
        extension._with_qe_operator_preparation(
            source,
            fixture.nnkp_file,
            2;
            checkpoint_directory = cache,
            implementation_contract = "overlap-fixture-v1",
        ) do
            state = extension._uiu_qe_state(source, fixture.nnkp_file, 2)
            expected[] = extension._uiu_center_neighbor_block(state, 1, 1)
            @test state.overlap_contractions[] == 1
            @test extension._uiu_center_neighbor_block(state, 1, 1) == expected[]
            @test state.overlap_contractions[] == 1
        end
        extension._with_qe_operator_preparation(
            source,
            fixture.nnkp_file,
            2;
            checkpoint_directory = cache,
            implementation_contract = "overlap-fixture-v1",
        ) do
            state = extension._uiu_qe_state(source, fixture.nnkp_file, 2)
            @test extension._uiu_center_neighbor_block(state, 1, 1) == expected[]
            @test state.overlap_contractions[] == 0
            @test isempty(state.wavefunction_cache.load_counts)
        end
        code = "using WannierNLQG,HDF5,JSON3,EzXML,Spglib; W=WannierNLQG.Wannierization; E=first(W._load_wannierization_extension!()).PAWMatrixElements; source=WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(ARGS[1];include_time_reversal=false); E._with_qe_operator_preparation(source,ARGS[2],2;checkpoint_directory=ARGS[3],implementation_contract=\"overlap-fixture-v1\") do; state=E._uiu_qe_state(source,ARGS[2],2); block=E._uiu_center_neighbor_block(state,1,1); @assert all(isfinite,block); @assert state.overlap_contractions[]==0; @assert isempty(state.wavefunction_cache.load_counts); println(\"FRESH_OVERLAP_REUSE_PASS\"); end"
        command =
            `$(Base.julia_cmd()) --startup-file=no --project=$(dirname(@__DIR__)) -e $code $(fixture.save_directory) $(fixture.nnkp_file) $cache`
        @test strip(read(command, String)) == "FRESH_OVERLAP_REUSE_PASS"
    end
end

@testset "First target construction shares one strict gauge read" begin
    extension = HOP_PAW_EXTENSION
    mktempdir() do directory
        path = joinpath(directory, "gauge.h5")
        write(path, "sealed gauge identity")
        calls = Ref(0)
        reader =
            (p; construction_policy, source) -> begin
                calls[] += 1
                (data = ComplexF64[1 + 2im], policy = construction_policy, source = source)
            end
        extension._with_generation_gauge_reuse() do
            first = extension._read_generation_gauge(
                path;
                construction_policy = :standard,
                source = :fixture,
                reader,
            )
            second = extension._read_generation_gauge(
                path;
                construction_policy = :standard,
                source = :fixture,
                reader,
            )
            @test first === second
            @test calls[] == 1
            @test second.data == ComplexF64[1 + 2im]
            chmod(path, 0o400)
            refreshed = extension._read_generation_gauge(
                path;
                construction_policy = :standard,
                source = :fixture,
                reader,
            )
            @test refreshed === first
            @test calls[] == 1
            @test refreshed.data == ComplexF64[1 + 2im]
            chmod(path, 0o600)
            write(path, "modified gauge identity with new length")
            @test_throws ArgumentError extension._read_generation_gauge(
                path;
                construction_policy = :standard,
                source = :fixture,
                reader,
            )
        end
        @test get(task_local_storage(), :wannier_generation_gauge_reuse, nothing) === nothing
        extension._read_generation_gauge(
            path;
            construction_policy = :standard,
            source = :fixture,
            reader,
        )
        @test calls[] == 2
        @test_throws ErrorException extension._with_generation_gauge_reuse() do
            error("stop target preparation")
        end
        @test get(task_local_storage(), :wannier_generation_gauge_reuse, nothing) === nothing
    end
end

@testset "Preparation progress separates build and reuse with point identity" begin
    io_layer = WannierNLQG.IO
    mktempdir() do directory
        io_layer.with_preparation_artifact_cache(directory, "progress-contract") do
            for _ in 1:2
                io_layer.cached_preparation_artifact("qe-beta", () -> "point-7"; unit = 7) do
                    ComplexF64[1 + 2im]
                end
            end
        end
        records = [
            JSON3.read(line) for
            line in readlines(joinpath(directory, "preparation_progress.jsonl"))
        ]
        @test [String(record.event) for record in records] == ["BUILD_STARTED", "BUILD_COMMITTED", "CACHE_HIT"]
        @test all(record -> record.unit == 7 && record.stage == "qe-beta", records)
        @test all(record -> isfinite(record.wall_seconds) && record.wall_seconds >= 0, records)
    end
end

@testset "Completed operator reuse does not materialize native PAW preparation" begin
    extension = HOP_PAW_EXTENSION
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
        cache = joinpath(directory, "compact-cache")
        result = extension._with_qe_operator_preparation(
            source,
            fixture.nnkp_file,
            2;
            checkpoint_directory = cache,
            implementation_contract = "lazy-preparation-v1",
        ) do
            :verified_completed_operator
        end
        @test result == :verified_completed_operator
        @test !isdir(joinpath(cache, "qe-projector-plan"))
        @test !isdir(joinpath(cache, "qe-generalized-norm"))
        extension._with_qe_operator_preparation(
            source,
            fixture.nnkp_file,
            2;
            checkpoint_directory = cache,
            implementation_contract = "lazy-preparation-v1",
        ) do
            state = extension._uiu_qe_state(source, fixture.nnkp_file, 2)
            @test isfinite(state.generalized_norm)
        end
        @test isdir(joinpath(cache, "qe-generalized-norm"))
    end
end

@testset "uIu final rename interruption retains verified center payloads" begin
    extension = HOP_PAW_EXTENSION
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
        state = extension._uiu_qe_state(source, fixture.nnkp_file, 2)
        topology = state.topology
        paths = (
            output = joinpath(directory, "model.uIu"),
            partial = joinpath(directory, "model.uIu.partial"),
            provenance = joinpath(directory, "model.uIu.provenance.json"),
            checkpoint = joinpath(directory, "model.uIu.partial.json"),
        )
        checksums = String[]
        open(paths.output, "w") do io
            extension._uiu_header!(io, topology)
            for center in 1:topology.num_kpts
                blocks = [
                    Matrix{ComplexF64}(I, topology.num_bands, topology.num_bands) for
                    first in 1:topology.num_neighbors, second in 1:topology.num_neighbors
                ]
                push!(checksums, extension._uiu_write_center!(io, blocks, topology))
            end
        end
        fingerprint="accepted-input-fingerprint"
        contract=extension._uiu_execution_contract(state)
        extension._uiu_atomic_json(
            paths.checkpoint,
            extension._uiu_checkpoint_payload(
                fingerprint,
                topology,
                topology.num_kpts,
                checksums,
                contract,
            ),
        )
        original=read(paths.output)
        @test_throws ArgumentError extension._uiu_recover_publication!(
            paths,
            topology,
            "changed-input",
            contract,
        )
        @test read(paths.output)==original
        @test !ispath(paths.partial)
        open(paths.output, "w") do io
            write(io, original[1:(end - 1)])
        end
        truncated=read(paths.output)
        @test_throws ArgumentError extension._uiu_recover_publication!(
            paths,
            topology,
            fingerprint,
            contract,
        )
        @test read(paths.output)==truncated
        write(paths.output, original)
        @test extension._uiu_recover_publication!(
            paths,
            topology,
            fingerprint,
            contract,
        )==topology.num_kpts
        @test !ispath(paths.output)
        @test read(paths.partial)==original
        @test isfile(paths.checkpoint)
        completed, restored, _, _=extension._uiu_scan_partial(paths.partial, topology)
        @test completed==topology.num_kpts
        @test restored==checksums
    end
end

@testset "Interrupted publication mismatch preserves both files" begin
    mktempdir() do directory
        output=joinpath(directory, "operator")
        write(output, "accepted bytes")
        candidate=WannierNLQG.IO.operator_publication_candidate(output)
        write(candidate, "different bytes")
        @test_throws ArgumentError WannierNLQG.IO.verify_operator_publication_candidate(
            candidate,
            output,
        )
        @test read(output, String)=="accepted bytes"
        @test read(candidate, String)=="different bytes"
        write(candidate, "accepted bytes")
        @test WannierNLQG.IO.verify_operator_publication_candidate(candidate, output)==output
        @test !ispath(candidate)
        @test read(output, String)=="accepted bytes"
    end
end

@testset "Standalone QE stages share native artifacts but verify stage inputs" begin
    extension = HOP_PAW_EXTENSION
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
        first_input = joinpath(directory, "stage-a.input")
        second_input = joinpath(directory, "stage-b.input")
        write(first_input, "first stage")
        write(second_input, "second stage")
        reference = extension._with_qe_operator_artifacts(
            source,
            fixture.nnkp_file,
            directory,
            2;
            additional_inputs = [first_input],
        ) do
            state = extension._uiu_qe_state(source, fixture.nnkp_file, 2)
            @test state.normalization_points[] == 3
            @test state.beta_contractions[] == 3
            (norm = state.generalized_norm, inputs = copy(state.input_sha256))
        end
        extension._with_qe_operator_artifacts(
            source,
            fixture.nnkp_file,
            directory,
            2;
            additional_inputs = [second_input],
        ) do
            state = extension._uiu_qe_state(source, fixture.nnkp_file, 2)
            @test state.normalization_points[] == 0
            @test state.beta_contractions[] == 0
            @test isempty(state.wavefunction_cache.load_counts)
            @test state.generalized_norm == reference.norm
            @test state.input_sha256 == reference.inputs
            write(second_input, "mutated second stage dependency")
            @test_throws ArgumentError extension.sha256_file(second_input)
        end
        metadata = extension.read_qe_xml(source)
        upf = first(values(metadata.upf_files))
        open(upf, "a") do stream
            write(stream, "\n")
        end
        extension._with_qe_operator_artifacts(
            source,
            fixture.nnkp_file,
            directory,
            2;
            additional_inputs = [first_input],
        ) do
            state = extension._uiu_qe_state(source, fixture.nnkp_file, 2)
            @test state.normalization_points[] == 3
            @test state.beta_contractions[] == 3
            @test state.generalized_norm == reference.norm
            @test state.input_sha256 != reference.inputs
        end
        # Exercise eviction independently of the durable overlap cache hits above.
        state = extension._uiu_qe_state(source, fixture.nnkp_file, 2)
        cache = extension.QEUIUWavefunctionCache(2, state.wavefunction_cache.loader)
        first_entry = extension._qe_uiu_cache_entry!(cache, 1)
        second_entry = extension._qe_uiu_cache_entry!(cache, 2)
        @test extension._qe_uiu_cache_entry!(cache, 1) === first_entry
        extension._qe_uiu_cache_entry!(cache, 3)
        @test !haskey(cache.entries, 2)
        restored = extension._qe_uiu_cache_entry!(cache, 2)
        @test restored.point.coefficients == second_entry.point.coefficients
        @test restored.beta_overlap == second_entry.beta_overlap
        @test cache.hits == 1
        @test cache.misses == 4
        @test cache.evictions == 2
        @test cache.reloads == 1
        @test cache.peak_entries == 2
    end
end

@testset "QE cold SPN fuses normalization without a second coefficient sweep" begin
    extension = HOP_PAW_EXTENSION
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
        reference = extension._uiu_qe_state(source, fixture.nnkp_file, 2)
        expected = cat((reference.spn_block(k)[1] for k in 1:3)...; dims = 4)
        for workers in (1, 2, 4)
            extension._with_qe_operator_preparation(source, fixture.nnkp_file, 2) do
                deferred = task_local_storage(:wannier_qe_defer_norm, true) do
                    extension._uiu_qe_state(source, fixture.nnkp_file, 2)
                end
                @test deferred.generalized_norm === nothing
                @test isempty(deferred.wavefunction_cache.load_counts)
                execution = HOP_WANNIERIZATION.WavefunctionPreparationExecutionConfig(
                    mode = :streaming_threads,
                    max_workers = workers,
                    checkpoint_directory = joinpath(directory, "fused-$workers"),
                )
                output = joinpath(directory, "fused-$workers.spn")
                result = HOP_WANNIERIZATION.generate_qe_paw_spn(
                    source,
                    fixture.nnkp_file;
                    output_spn_file = output,
                    max_cached_wavefunction_kpoints = 2,
                    execution,
                )
                @test result.passed
                @test result.spn.data == expected
                @test bytes2hex(sha256(reinterpret(UInt8, vec(result.spn.data)))) ==
                      bytes2hex(sha256(reinterpret(UInt8, vec(expected))))
                state = extension._uiu_qe_state(source, fixture.nnkp_file, 2)
                @test state.generalized_norm == reference.generalized_norm
                @test state.normalization_points[] == 3
                @test state.wavefunction_cache.load_counts == Dict(k => 1 for k in 1:3)
                @test state.wavefunction_cache.reloads == 0
                resumed = HOP_WANNIERIZATION.generate_qe_paw_spn(
                    source,
                    fixture.nnkp_file;
                    output_spn_file = output,
                    max_cached_wavefunction_kpoints = 2,
                    execution,
                )
                @test resumed.spn.data == expected
                @test state.wavefunction_cache.load_counts == Dict(k => 1 for k in 1:3)
            end
        end
    end
end

@testset "QE coefficient cache enforces bytes without changing payloads" begin
    extension = HOP_PAW_EXTENSION
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
        state = extension._uiu_qe_state(source, fixture.nnkp_file, 2)
        entries = [state.wavefunction_cache.loader(k) for k in 1:3]
        sizes = extension._qe_uiu_entry_bytes.(entries)
        @test allequal(sizes)
        cache = extension.QEUIUWavefunctionCache(
            8,
            k -> entries[k];
            max_bytes = 2 * first(sizes),
            estimate_bytes = k -> sizes[k],
        )
        for k in (1, 2, 3, 2, 1)
            value = extension._qe_uiu_cache_entry!(cache, k)
            @test value.point.coefficients == entries[k].point.coefficients
            @test value.beta_overlap == entries[k].beta_overlap
            @test cache.resident_bytes == sum(values(cache.entry_bytes))
            @test cache.resident_bytes <= cache.max_bytes
        end
        @test cache.peak_entries == 2
        @test cache.evictions == 2
        @test cache.hits == 1
        @test cache.reloads == 1
        @test cache.peak_resident_bytes == 2 * first(sizes)
        transient = extension.QEUIUWavefunctionCache(
            8,
            k -> entries[k];
            max_bytes = first(sizes) - 1,
            estimate_bytes = k -> sizes[k],
        )
        @test extension._qe_uiu_cache_entry!(transient, 1) === entries[1]
        @test isempty(transient.entries)
        @test transient.resident_bytes == 0
        @test_throws ArgumentError extension.QEUIUWavefunctionCache(8, identity; max_bytes = 0)
        execution =
            HOP_WANNIERIZATION.WavefunctionPreparationExecutionConfig(memory_budget_bytes = 1024^2)
        extension._with_qe_operator_artifacts(source, fixture.nnkp_file, directory, 8; execution) do
            bounded = extension._uiu_qe_state(source, fixture.nnkp_file, 8)
            @test bounded.wavefunction_cache.max_bytes == 3 * 1024^2 ÷ 16
            @test bounded.generalized_norm == state.generalized_norm
        end
    end
end

@testset "metadata refresh preserves content authority" begin
    foundation=WannierNLQG.SymmetryFoundation
    mktempdir() do dir
        p=joinpath(dir, "input");
        write(p, "accepted")
        expected=bytes2hex(sha256(read(p)))
        foundation.with_verified_file_digests([p]) do
            old=get(task_local_storage(), :wannier_verified_file_digests, nothing)
            chmod(p, 0o400)
            @test foundation.sha256_file(p)==expected
            refreshed=get(task_local_storage(), :wannier_verified_file_digests, nothing)
            @test refreshed!==old
            @test old[realpath(p)][1]!=refreshed[realpath(p)][1]
            @test foundation.sha256_file(p)==expected
            @test get(task_local_storage(), :wannier_verified_file_digests, nothing)===refreshed
            foundation.with_verified_file_digests([p]) do
                @test foundation.sha256_file(p)==expected
            end
            child = fetch(Threads.@spawn task_local_storage(:wannier_verified_file_digests, old) do
                @test foundation.sha256_file(p) == expected
                get(task_local_storage(), :wannier_verified_file_digests, nothing)
            end)
            @test child !== old
            @test child !== refreshed
            @test get(task_local_storage(), :wannier_verified_file_digests, nothing) === refreshed
            chmod(p, 0o600);
            write(p, "tampered")
            @test_throws ArgumentError foundation.sha256_file(p)
        end
        @test get(task_local_storage(), :wannier_verified_file_digests, nothing)===nothing
        identity=foundation._digest_file_identity(p);
        prior=(identity[1:4]..., identity[5]-1)
        calls=Ref(0);
        h=p->(calls[]+=1; bytes2hex(sha256(read(p))))
        @test_throws ArgumentError foundation.verified_file_digest_identity(
            p,
            prior,
            expected;
            file_hasher = h,
        )
        @test calls[]==1
        changed=bytes2hex(sha256(read(p)))
        @test foundation.verified_file_digest_identity(p, prior, changed; file_hasher = h)==identity
        @test calls[]==2
        @test foundation.verified_file_digest_identity(
            p,
            identity,
            changed;
            file_hasher = h,
        )==identity
        @test calls[]==2
    end
end
