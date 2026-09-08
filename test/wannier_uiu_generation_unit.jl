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

const UIU_WANNIERIZATION = WannierNLQG.Wannierization

struct UIUPreflightCountingSource <: WannierNLQG.SymmetryFoundation.AbstractWavefunctionSource end
const UIU_PREFLIGHT_SOURCE_CALLS = Ref(0)
const UIU_PAW_EXTENSION =
    Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).PAWMatrixElements
@eval UIU_PAW_EXTENSION begin
    _generation_source_protected_paths(::$(UIUPreflightCountingSource)) = ()
    function _uiu_source_state(::$(UIUPreflightCountingSource), args...)
        $(UIU_PREFLIGHT_SOURCE_CALLS)[] += 1
        error("UIU counting source seam reached")
    end
end

uiu_test_file_sha256(path::AbstractString) =
    open(path, "r") do io
        bytes2hex(SHA.sha256(io))
    end

function uiu_test_blocks(center::Int)
    first = ComplexF64[1 0; 0 1]
    second = ComplexF64[1 0; 0 1]
    cross = ComplexF64[0.1center + 0.2im 0.3-0.1im; -0.2+0.4im 0.7]
    blocks = Matrix{Matrix{ComplexF64}}(undef, 2, 2)
    blocks[1, 1] = first
    blocks[2, 2] = second
    blocks[1, 2] = cross
    blocks[2, 1] = cross'
    return blocks
end

@testset "native QE PAW uIu generation and MMN oracle" begin
    mktempdir() do directory
        fixture = write_qe_paw_fixture(
            directory;
            metric_kind = :paw,
            spinor = true,
            spinorbit = true,
            num_kpoints = 3,
        )
        oracle = joinpath(directory, "oracle.mmn")
        WannierNLQG.IO.write_wannier_mmn(
            oracle,
            WannierNLQG.IO.WannierMMN(
                1,
                3,
                1,
                ones(ComplexF64, 1, 1, 1, 3),
                reshape(collect(1:3), 1, 3),
                zeros(Int, 3, 1, 3),
            ),
        )
        output = joinpath(directory, "fixture.uIu")
        provenance = output * ".provenance.json"
        source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
            fixture.save_directory;
            include_time_reversal = false,
        )
        config = UIU_WANNIERIZATION.WannierUIUGenerationConfig(
            source = source,
            topology_file = fixture.nnkp_file,
            output_file = output,
            provenance_json = provenance,
            oracle_mmn_file = oracle,
            max_cached_wavefunction_kpoints = 2,
        )
        paw_extension =
            Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).PAWMatrixElements
        solver_mmn_file = joinpath(directory, "solver.mmn")
        solver_mmn = WannierNLQG.IO.read_wannier_mmn(oracle)
        solver_data = copy(solver_mmn.data)
        solver_data[1] += 0.25
        WannierNLQG.IO.write_wannier_mmn(
            solver_mmn_file,
            WannierNLQG.IO.WannierMMN(
                solver_mmn.num_bands,
                solver_mmn.num_kpts,
                solver_mmn.num_neighbors,
                solver_data,
                solver_mmn.neighbors,
                solver_mmn.reciprocal_shifts,
            ),
        )
        target_gauge = paw_extension.generation_band_gauge_contract(
            source,
            UIU_WANNIERIZATION.NativeDFTHamiltonian(),
            nothing,
            1,
            3;
            construction_policy = :diagnostic,
        )
        target = UIU_WANNIERIZATION.WannierOperatorTargetContract(
            oracle,
            uiu_test_file_sha256(oracle),
            solver_mmn_file,
            uiu_test_file_sha256(solver_mmn_file),
            target_gauge.source_band_gauge,
            target_gauge.target_band_gauge,
            target_gauge.transform_sha256,
            target_gauge.contract_sha256,
            "NOT_APPLICABLE",
            "native_dft",
            repeat("a", 64),
            1,
            3,
            1,
        )
        authority_mismatch_target = UIU_WANNIERIZATION.WannierOperatorTargetContract(
            oracle,
            uiu_test_file_sha256(oracle),
            solver_mmn_file,
            uiu_test_file_sha256(solver_mmn_file),
            target_gauge.source_band_gauge,
            target_gauge.target_band_gauge,
            target_gauge.transform_sha256,
            target_gauge.contract_sha256,
            "NOT_APPLICABLE",
            "symmetrized_dft_hamiltonian",
            repeat("a", 64),
            1,
            3,
            1,
        )
        UIU_PREFLIGHT_SOURCE_CALLS[] = 0
        authority_mismatch_error = try
            UIU_WANNIERIZATION.generate_wannier_uiu(
                UIU_WANNIERIZATION.WannierUIUGenerationConfig(
                    source = UIUPreflightCountingSource(),
                    topology_file = fixture.nnkp_file,
                    output_file = joinpath(directory, "authority-mismatch.uIu"),
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
        @test UIU_PREFLIGHT_SOURCE_CALLS[] == 0

        gauge_file = joinpath(directory, "gauge.h5")
        write(gauge_file, "gauge artifact fixture")
        gauge_mismatch_target = UIU_WANNIERIZATION.WannierOperatorTargetContract(
            oracle,
            uiu_test_file_sha256(oracle),
            solver_mmn_file,
            uiu_test_file_sha256(solver_mmn_file),
            "native_dft_eigenstate",
            "sawf_completed_native_dft",
            target_gauge.transform_sha256,
            target_gauge.contract_sha256,
            repeat("b", 64),
            "native_dft",
            repeat("a", 64),
            1,
            3,
            1,
        )
        UIU_PREFLIGHT_SOURCE_CALLS[] = 0
        gauge_mismatch_error = try
            UIU_WANNIERIZATION.generate_wannier_uiu(
                UIU_WANNIERIZATION.WannierUIUGenerationConfig(
                    source = UIUPreflightCountingSource(),
                    topology_file = fixture.nnkp_file,
                    output_file = joinpath(directory, "gauge-mismatch.uIu"),
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
        @test UIU_PREFLIGHT_SOURCE_CALLS[] == 0
        target_only_output = joinpath(directory, "target-only.uIu")
        target_only = UIU_WANNIERIZATION.generate_wannier_uiu(
            UIU_WANNIERIZATION.WannierUIUGenerationConfig(
                source = source,
                topology_file = fixture.nnkp_file,
                output_file = target_only_output,
                target_contract = target,
                max_cached_wavefunction_kpoints = 2,
            ),
        )
        @test target.operator_oracle_mmn_sha256 != target.solver_mmn_sha256
        @test target_only.passed
        target_only_sidecar = JSON3.read(read(target_only_output * ".provenance.json", String))
        @test target_only_sidecar.input_sha256.ORACLE_MMN == target.operator_oracle_mmn_sha256
        @test target_only_sidecar.input_sha256.OPERATOR_TARGET_CONTRACT == target.contract_sha256

        missing_target = UIU_WANNIERIZATION.WannierOperatorTargetContract(
            joinpath(directory, "missing-oracle.mmn"),
            repeat("b", 64),
            solver_mmn_file,
            uiu_test_file_sha256(solver_mmn_file),
            target_gauge.source_band_gauge,
            target_gauge.target_band_gauge,
            target_gauge.transform_sha256,
            target_gauge.contract_sha256,
            "NOT_APPLICABLE",
            "native_dft",
            repeat("a", 64),
            1,
            3,
            1,
        )
        missing_target_output = joinpath(directory, "missing-target.uIu")
        missing_target_error = try
            UIU_WANNIERIZATION.generate_wannier_uiu(
                UIU_WANNIERIZATION.WannierUIUGenerationConfig(
                    source = source,
                    topology_file = fixture.nnkp_file,
                    output_file = missing_target_output,
                    target_contract = missing_target,
                    max_cached_wavefunction_kpoints = 2,
                ),
            )
            nothing
        catch exception
            exception
        end
        @test missing_target_error isa ArgumentError
        @test occursin("UIU_MMN_ORACLE_REQUIRED", sprint(showerror, missing_target_error))
        @test !ispath(missing_target_output)
        @test !ispath(missing_target_output * ".provenance.json")

        protected_wfc = joinpath(fixture.save_directory, "wfc1.hdf5")
        protected_wfc_sha256 = uiu_test_file_sha256(protected_wfc)
        protected_collision = try
            UIU_WANNIERIZATION.generate_wannier_uiu(
                UIU_WANNIERIZATION.WannierUIUGenerationConfig(
                    source = source,
                    topology_file = fixture.nnkp_file,
                    output_file = protected_wfc,
                    oracle_mmn_file = oracle,
                    overwrite = true,
                    max_cached_wavefunction_kpoints = 2,
                ),
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
        @test uiu_test_file_sha256(protected_wfc) == protected_wfc_sha256
        save_alias = joinpath(directory, "qe-save-alias")
        symlink(fixture.save_directory, save_alias)
        symlink_output = joinpath(save_alias, "must-not-create.uIu")
        symlink_collision = try
            UIU_WANNIERIZATION.generate_wannier_uiu(
                UIU_WANNIERIZATION.WannierUIUGenerationConfig(
                    source = source,
                    topology_file = fixture.nnkp_file,
                    output_file = symlink_output,
                    oracle_mmn_file = oracle,
                    overwrite = true,
                    max_cached_wavefunction_kpoints = 2,
                ),
            )
            nothing
        catch exception
            exception
        end
        @test symlink_collision isa ArgumentError
        @test occursin("GENERATOR_PROTECTED_INPUT_COLLISION", sprint(showerror, symlink_collision))
        @test !ispath(joinpath(fixture.save_directory, basename(symlink_output)))
        @test config.construction_policy == :diagnostic
        @test_throws ArgumentError UIU_WANNIERIZATION.generate_wannier_uiu(
            UIU_WANNIERIZATION.WannierUIUGenerationConfig(
                construction_policy = :invalid,
                source = source,
                topology_file = fixture.nnkp_file,
                output_file = joinpath(directory, "invalid-policy.uIu"),
                oracle_mmn_file = oracle,
                max_cached_wavefunction_kpoints = 2,
            ),
        )
        mismatched_authority = joinpath(directory, "mismatched-authority.mmn")
        WannierNLQG.IO.write_wannier_mmn(
            mismatched_authority,
            WannierNLQG.IO.WannierMMN(
                1,
                3,
                1,
                zeros(ComplexF64, 1, 1, 1, 3),
                reshape(collect(1:3), 1, 3),
                zeros(Int, 3, 1, 3),
            ),
        )
        rejected_output = joinpath(directory, "must-fail-before-overlaps.uIu")
        rejected = try
            UIU_WANNIERIZATION.generate_wannier_uiu(
                UIU_WANNIERIZATION.WannierUIUGenerationConfig(
                    source = source,
                    topology_file = fixture.nnkp_file,
                    output_file = rejected_output,
                    oracle_mmn_file = oracle,
                    authoritative_mmn_file = mismatched_authority,
                    max_cached_wavefunction_kpoints = 2,
                ),
            )
            nothing
        catch exception
            exception
        end
        @test rejected isa ArgumentError
        @test occursin("AUTHORITATIVE_MMN_MISMATCH", sprint(showerror, rejected))
        @test !ispath(rejected_output)
        @test !ispath(rejected_output * ".provenance.json")
        result = UIU_WANNIERIZATION.generate_wannier_uiu(config)
        @test result.passed
        @test result.source_code == :qe
        @test result.generalized_norm_max_absolute <= 1.0e-12
        @test result.mmn_parity.max_absolute <= 1.0e-12
        @test result.diagonal_identity_max_absolute <= 1.0e-12
        @test result.exchange_hermiticity_max_absolute <= 1.0e-12
        @test isfile(output)
        @test isfile(provenance)
        sidecar = JSON3.read(read(provenance, String))
        @test sidecar.schema_version == "1.0"
        @test sidecar.construction_policy == "diagnostic"
        @test sidecar.model_qualification == "DIAGNOSTIC_ONLY"
        @test sidecar.manual_review_required
        @test !sidecar.production_eligible
        @test sidecar.source_band_gauge == "native_dft_eigenstate"
        @test sidecar.target_band_gauge == "native_dft_eigenstate"
        @test sidecar.gauge_artifact_sha256 == "NOT_APPLICABLE"
        @test sidecar.band_frame_contract.status == "PASS"
        @test sidecar.band_frame_transform_sha256 == sidecar.band_gauge_rotation_sha256
        @test sidecar.record_order == "ik->nn2->nn1"
        @test sidecar.relative_reciprocal_shift == "G2-G1"
        @test sidecar.output_sha256 == result.artifacts["uiu_sha256"]
        @test sidecar.wavefunction_cache.max_cached_wavefunction_kpoints == 2
        @test sidecar.wavefunction_cache.peak_cached_kpoints == 2
        @test sidecar.wavefunction_cache.evictions > 0
        @test sidecar.wavefunction_cache.reloads > 0
        blocks = Matrix{ComplexF64}[]
        WannierNLQG.IO.foreach_wannier_uiu_block(output) do block, _, _, _, _
            push!(blocks, block)
        end
        @test blocks == fill(ones(ComplexF64, 1, 1), 3)

        parent_extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)
        extension = parent_extension.PAWMatrixElements
        preparation = parent_extension.RepresentationPreparation
        for count in 1:8
            pairs = extension._uiu_directed_euler_pair_order(count)
            @test length(pairs) == count^2
            @test length(unique(pairs)) == count^2
            @test all(pairs[index][2] == pairs[index + 1][1] for index in 1:(length(pairs) - 1))
            @test pairs[end][2] == pairs[1][1]
        end
        cache_limited_state =
            (wavefunction_cache = (max_entries = 2,), topology = (num_neighbors = 6,))
        @test extension._uiu_center_pair_order(cache_limited_state, 6) ==
              extension._uiu_directed_euler_pair_order(6)
        cache_ample_state =
            (wavefunction_cache = (max_entries = 8,), topology = (num_neighbors = 6,))
        @test extension._uiu_center_pair_order(cache_ample_state, 6) ==
              extension._uiu_directed_euler_pair_order(6)
        lazy_state = extension._uiu_qe_state(source, fixture.nnkp_file, 2)
        @test extension._uiu_native_frame_offset(lazy_state.native, lazy_state.topology, 3) ==
              [-1, 0, 0]
        frame_topology = extension.WannierNeighborTopology(
            1,
            3,
            2,
            Int[1 2 3; 2 3 1],
            zeros(Int, 3, 2, 3),
            copy(lazy_state.topology.kpoints_fractional),
            copy(lazy_state.topology.real_lattice),
            copy(lazy_state.topology.reciprocal_lattice),
            :nnkp,
            repeat("0", 64),
        )
        _, _, frame_shift, frame_b =
            extension._uiu_overlap_geometry(lazy_state.native, frame_topology, 2, 1, 2)
        @test frame_shift == (1, 0, 0)
        @test isapprox(frame_b, [1 / 3, 0, 0]; atol = 1.0e-12, rtol = 0.0)
        metadata = preparation._read_qe_xml(source)
        raw_native = preparation._read_qe_raw_wavefunctions(source, metadata)
        nnkp = WannierNLQG.IO.read_wannier_nnkp(fixture.nnkp_file)
        extension._qe_validate_nnkp_contract(raw_native, nnkp)
        eager_native = extension._qe_select_nnkp_bands(raw_native, nnkp)
        @test extension._paw_pseudo_mmn_block(
            eager_native.kpoints[1],
            eager_native.kpoints[2],
            (0, 0, 0);
            threaded_spin = false,
        ) == extension._paw_pseudo_mmn_block(
            eager_native.kpoints[1],
            eager_native.kpoints[2],
            (0, 0, 0);
            threaded_spin = true,
        )
        upf_data = Dict(
            label => preparation._read_qe_upf_data(path) for (label, path) in metadata.upf_files
        )
        plan = preparation._build_qe_projector_plan(metadata, upf_data)
        eager_beta, _ = extension._qe_beta_overlaps(eager_native, upf_data, plan)
        eager_finite_b_cache =
            Dict{Tuple{String, NTuple{3, Float64}, Int, Bool}, Array{ComplexF64, 4}}()
        for index in 1:3
            pseudo = extension._paw_pseudo_mmn_block(
                eager_native.kpoints[index],
                eager_native.kpoints[index],
                (0, 0, 0),
            )
            augmentation = extension._qe_augmentation_block(
                eager_beta[index],
                eager_beta[index],
                upf_data,
                plan,
                zeros(3),
                zeros(3),
                metadata.spinorbit,
                eager_finite_b_cache,
            )
            @test blocks[index] == pseudo + augmentation
        end

        output_eight = joinpath(directory, "fixture-cache-eight.uIu")
        result_eight = UIU_WANNIERIZATION.generate_wannier_uiu(
            UIU_WANNIERIZATION.WannierUIUGenerationConfig(
                source = source,
                topology_file = fixture.nnkp_file,
                output_file = output_eight,
                oracle_mmn_file = oracle,
                max_cached_wavefunction_kpoints = 8,
            ),
        )
        @test result_eight.passed
        @test read(output_eight) == read(output)
        @test sidecar.wavefunction_cache.block_evaluation_order == "directed_euler_cache_aware"
        @test_throws ArgumentError UIU_WANNIERIZATION.generate_wannier_uiu(config)
        @test_throws ArgumentError UIU_WANNIERIZATION.generate_wannier_uiu(
            UIU_WANNIERIZATION.WannierUIUGenerationConfig(
                source = source,
                topology_file = fixture.nnkp_file,
                output_file = joinpath(directory, "invalid-cache.uIu"),
                oracle_mmn_file = oracle,
                max_cached_wavefunction_kpoints = 1,
            ),
        )
    end
end

@testset "streamed Wannier uIu protocol and restart boundaries" begin
    import Spglib, HDF5, EzXML
    extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).PAWMatrixElements
    @test extension !== nothing
    topology = extension.WannierNeighborTopology(
        2,
        2,
        2,
        Int[1 2; 2 1],
        zeros(Int, 3, 2, 2),
        nothing,
        nothing,
        nothing,
        :mmn,
        repeat("0", 64),
    )
    mktempdir() do directory
        protected_input = joinpath(directory, "protected-input.dat")
        write(protected_input, "immutable")
        for role in (:output, :provenance, :scratch, :partial, :checkpoint)
            error = try
                extension.validate_generation_output_paths(
                    Dict(role => protected_input),
                    (protected_input,),
                )
                nothing
            catch exception
                exception
            end
            @test error isa ArgumentError
            @test occursin("GENERATOR_PROTECTED_INPUT_COLLISION", sprint(showerror, error))
        end
        partial = joinpath(directory, "synthetic.uIu.partial")
        header_end = open(partial, "w") do io
            extension._uiu_header!(io, topology)
        end
        first_checksum = open(partial, "a") do io
            extension._uiu_write_center!(io, uiu_test_blocks(1), topology)
        end
        open(partial, "a") do io
            write(io, Int32(128))
            write(io, zeros(UInt8, 16))
        end
        completed, checksums, diagonal, hermiticity = extension._uiu_scan_partial(partial, topology)
        @test completed == 1
        @test checksums == [first_checksum]
        @test diagonal == 0.0
        @test hermiticity == 0.0
        expected_size = header_end + 4 * (2^2 * sizeof(ComplexF64) + 8)
        @test filesize(partial) == expected_size

        second_checksum = open(partial, "a") do io
            extension._uiu_write_center!(io, uiu_test_blocks(2), topology)
        end
        completed, checksums, diagonal, hermiticity = extension._uiu_scan_partial(partial, topology)
        @test completed == 2
        @test checksums == [first_checksum, second_checksum]
        @test diagonal == 0.0
        @test hermiticity == 0.0

        observed = Dict{NTuple{3, Int}, Matrix{ComplexF64}}()
        header = WannierNLQG.IO.foreach_wannier_uiu_block(partial) do block, ik, nn2, nn1, _
            observed[(ik, nn1, nn2)] = block
        end
        @test (header.num_bands, header.num_kpts, header.num_neighbors) == (2, 2, 2)
        for center in 1:2, first in 1:2, second in 1:2
            @test observed[(center, first, second)] == uiu_test_blocks(center)[first, second]
        end

        corrupted = joinpath(directory, "corrupted.uIu.partial")
        cp(partial, corrupted)
        open(corrupted, "r+") do io
            extension._uiu_read_header!(io, topology)
            write(io, Int32(17))
        end
        @test_throws Exception extension._uiu_scan_partial(corrupted, topology)

        fingerprint = repeat("a", 64)
        execution_contract = "test-contract"
        checkpoint = joinpath(directory, "checkpoint.json")
        extension._uiu_atomic_json(
            checkpoint,
            extension._uiu_checkpoint_payload(
                fingerprint,
                topology,
                2,
                checksums,
                execution_contract,
            ),
        )
        @test extension._uiu_validate_checkpoint(
            checkpoint,
            fingerprint,
            2,
            checksums,
            execution_contract,
        ) === nothing
        @test_throws ArgumentError extension._uiu_validate_checkpoint(
            checkpoint,
            repeat("b", 64),
            2,
            checksums,
            execution_contract,
        )
        @test_throws ArgumentError extension._uiu_validate_checkpoint(
            checkpoint,
            fingerprint,
            2,
            checksums,
            "different-contract",
        )
    end
end

@testset "uIu and exact-bundle public expert models" begin
    thresholds = UIU_WANNIERIZATION.WannierUIUGenerationThresholds()
    @test thresholds.mmn_max_absolute == 1.0e-5
    @test_throws ArgumentError UIU_WANNIERIZATION.WannierUIUGenerationThresholds(mmn_rms = 0.0)
    for name in (
        :WannierOperatorTargetContract,
        :WannierUIUGenerationConfig,
        :WannierUIUGenerationResult,
        :WannierUIUGenerationThresholds,
        :WannierUIUParityMetrics,
        :ExactWannierOperatorBundleConfig,
        :ExactWannierOperatorBundleResult,
        :generate_wannier_uiu,
        :prepare_wannier_operator_target_contract,
        :prepare_exact_wannier_operator_bundle,
    )
        @test isdefined(UIU_WANNIERIZATION, name)
    end
    native_target = UIU_WANNIERIZATION.WannierOperatorTargetContract(
        abspath("raw-operator-oracle.mmn"),
        repeat("a", 64),
        abspath("solver-gauge.mmn"),
        repeat("b", 64),
        "native_dft_eigenstate",
        "native_dft_eigenstate",
        repeat("c", 64),
        repeat("d", 64),
        "NOT_APPLICABLE",
        "native_dft_hamiltonian",
        repeat("e", 64),
        2,
        3,
        4,
    )
    @test native_target.operator_oracle_mmn_sha256 != native_target.solver_mmn_sha256
    @test occursin(r"^[0-9a-f]{64}$", native_target.contract_sha256)
    @test_throws ArgumentError UIU_WANNIERIZATION.WannierOperatorTargetContract(
        abspath("raw-operator-oracle.mmn"),
        repeat("a", 64),
        abspath("solver-gauge.mmn"),
        repeat("b", 64),
        "native_dft_eigenstate",
        "native_dft_eigenstate",
        repeat("c", 64),
        repeat("d", 64),
        "NOT_A_DIGEST",
        "native_dft_hamiltonian",
        repeat("e", 64),
        2,
        3,
        4,
    )
end

@testset "Wannierization-owned exact uIu operator bundle" begin
    extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).PAWMatrixElements
    fixture_root = joinpath(@__DIR__, "..", "examples", "symmetrization", "fixture", "inputs")
    tb_file = joinpath(fixture_root, "synthetic_tb.dat")
    chk_file = joinpath(fixture_root, "synthetic.chk")
    eig_file = joinpath(fixture_root, "synthetic.eig")
    mmn_file = joinpath(fixture_root, "synthetic.mmn")
    chk = WannierNLQG.IO.read_wannier_chk(chk_file)
    mmn = WannierNLQG.IO.read_wannier_mmn(mmn_file)
    mktempdir() do directory
        uiu_file = joinpath(directory, "synthetic.uIu")
        open(uiu_file, "w") do io
            extension._uiu_write_fortran_record(
                io,
                Vector{UInt8}(codeunits("WannierNLQG exact-bundle synthetic oracle")),
            )
            extension._uiu_write_fortran_record(
                io,
                extension._uiu_int32_bytes((chk.num_bands, chk.num_kpts, mmn.num_neighbors)),
            )
            direct_overlap = Matrix{ComplexF64}(I, chk.num_bands, chk.num_bands)
            for _ in 1:(chk.num_kpts * mmn.num_neighbors ^ 2)
                extension._uiu_write_fortran_record(io, extension._uiu_matrix_bytes(direct_overlap))
            end
        end
        provenance_file = uiu_file * ".provenance.json"
        mmn_sha256 = uiu_test_file_sha256(mmn_file)
        uiu_sha256 = uiu_test_file_sha256(uiu_file)
        write(
            provenance_file,
            JSON3.write(
                Dict(
                    "schema" => extension.WANNIER_UIU_GENERATION_SCHEMA,
                    # Preserve the original minimal historical sidecar reader contract.
                    "schema_version" => "1.2",
                    "status" => "PASS_SYNTHETIC_EXACT_BUNDLE",
                    "passed" => true,
                    "physical_overlap_available" => true,
                    "output_sha256" => uiu_sha256,
                    "algorithm_version" => extension.WANNIER_UIU_ALGORITHM_VERSION,
                    "input_fingerprint_sha256" => repeat("a", 64),
                    "input_sha256" => Dict("ORACLE_MMN" => mmn_sha256),
                ),
            ),
        )
        output_bundle = joinpath(directory, "synthetic-exact-bundle.h5")
        result = UIU_WANNIERIZATION.prepare_exact_wannier_operator_bundle(
            UIU_WANNIERIZATION.ExactWannierOperatorBundleConfig(
                tb_file = tb_file,
                chk_file = chk_file,
                eig_file = eig_file,
                mmn_file = mmn_file,
                uiu_file = uiu_file,
                uiu_provenance_json = provenance_file,
                output_bundle_file = output_bundle,
            ),
        )
        @test result.passed
        @test result.operator_bundle_file == output_bundle
        @test result.operator_bundle_sha256 == uiu_test_file_sha256(output_bundle)
        bundle = WannierNLQG.IO.read_real_space_operator_bundle(output_bundle)
        @test bundle.manifest.schema_version == "1.0"
        @test bundle.manifest.band_frame_contract_status == "NOT_APPLICABLE"
        @test bundle.manifest.profile == :derivative
        @test bundle.manifest.derivative_overlap_completeness == "full_hilbert_space"
        @test Set(keys(bundle.operators)) == Set((
            WannierNLQG.Core.REAL_SPACE_HAMILTONIAN,
            WannierNLQG.Core.REAL_SPACE_POSITION,
            WannierNLQG.Core.REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION,
            WannierNLQG.Core.REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP,
            WannierNLQG.Core.REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR,
            WannierNLQG.Core.REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP,
            WannierNLQG.Core.REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP,
        ),)
        @test !(:uiu_file in fieldnames(WannierNLQG.Symmetrization.SymmetrizationConfig))
    end
end
