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
            construction_policy = :standard,
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
        @test config.construction_policy == :standard
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
        execution = UIU_WANNIERIZATION.WavefunctionPreparationExecutionConfig(
            checkpoint_directory = joinpath(directory, "qe-explicit-preparation"),
        )
        explicit_config = UIU_WANNIERIZATION.WannierUIUGenerationConfig(
            source = source,
            topology_file = fixture.nnkp_file,
            output_file = joinpath(directory, "explicit.uIu"),
            oracle_mmn_file = oracle,
            max_cached_wavefunction_kpoints = 2,
            execution = execution,
            overwrite = true,
        )
        explicit_result = UIU_WANNIERIZATION.generate_wannier_uiu(explicit_config)
        @test explicit_result.passed
        @test explicit_result.artifacts["uiu_sha256"] == result.artifacts["uiu_sha256"]
        @test isdir(joinpath(execution.checkpoint_directory, "shared-qe-native"))
        resumed_explicit = UIU_WANNIERIZATION.generate_wannier_uiu(explicit_config)
        @test resumed_explicit.artifacts["uiu_sha256"] == result.artifacts["uiu_sha256"]
        @test result.generalized_norm_max_absolute <= 1.0e-12
        @test result.mmn_parity.max_absolute <= 1.0e-12
        @test result.diagonal_identity_max_absolute <= 1.0e-12
        @test result.exchange_hermiticity_max_absolute <= 1.0e-12
        @test isfile(output)
        @test isfile(provenance)
        sidecar = JSON3.read(read(provenance, String))
        @test sidecar.schema_version == "1.1"
        @test sidecar.construction_policy == "standard"
        @test sidecar.model_qualification == "STANDARD"
        @test sidecar.quality_review_recommended
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
        # Earlier stages have sealed all native overlap blocks for this input.
        @test sidecar.wavefunction_cache.peak_cached_kpoints == 0
        @test sidecar.wavefunction_cache.evictions == 0
        @test sidecar.wavefunction_cache.reloads == 0
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
        before_reuse = stat(output)
        restored = UIU_WANNIERIZATION.generate_wannier_uiu(config)
        after_reuse = stat(output)
        # ctime can change from filesystem metadata; content digests below, inode,
        # mtime and size establish the publication invariants.
        @test (before_reuse.inode, before_reuse.mtime, before_reuse.size) ==
              (after_reuse.inode, after_reuse.mtime, after_reuse.size)
        @test restored.artifacts["uiu_sha256"] == result.artifacts["uiu_sha256"]
        completed_code = """
        using WannierNLQG,HDF5,JSON3,EzXML,Spglib,LinearAlgebra
        W=WannierNLQG.Wannierization
        E=first(W._load_wannierization_extension!()).PAWMatrixElements
        @eval E _uiu_source_state(source::QuantumEspressoWavefunctionSource, topology, cache_size) = error("COMPLETED_QE_UIU_PREPARATION_FORBIDDEN")
        source=WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(ARGS[1];include_time_reversal=false)
        result=W.generate_wannier_uiu(W.WannierUIUGenerationConfig(source=source,
            topology_file=ARGS[2],output_file=ARGS[3],oracle_mmn_file=ARGS[4],max_cached_wavefunction_kpoints=2))
        @assert result.passed
        println("FRESH_QE_UIU_COMPLETE_REUSE_PASS")
        """
        completed_child =
            `$(Base.julia_cmd()) --startup-file=no --project=$(dirname(Base.active_project())) --threads=$(Threads.nthreads()) -e $completed_code $(fixture.save_directory) $(fixture.nnkp_file) $output $oracle`
        @test occursin("FRESH_QE_UIU_COMPLETE_REUSE_PASS", read(completed_child, String))
        original = read(output)
        try
            write(output, vcat(original, UInt8[0]))
            @test_throws ArgumentError UIU_WANNIERIZATION.generate_wannier_uiu(config)
        finally
            write(output, original)
        end
        # Recreate the exact crash state after final data rename but before
        # provenance commit; the child forbids any center recomputation.
        recovery_state = paw_extension._uiu_qe_state(source, fixture.nnkp_file, 2)
        recovery_paths = paw_extension._uiu_partial_paths(config)
        completed, checksums, _, _ =
            paw_extension._uiu_scan_partial(output, recovery_state.topology)
        paw_extension._uiu_atomic_json(
            recovery_paths.checkpoint,
            paw_extension._uiu_checkpoint_payload(
                String(sidecar.input_fingerprint_sha256),
                recovery_state.topology,
                completed,
                checksums,
                paw_extension._uiu_execution_contract(recovery_state),
            ),
        )
        original_digest = uiu_test_file_sha256(output)
        mv(provenance, provenance * ".before-interruption")
        recovery_code = """
        using WannierNLQG,HDF5,JSON3,EzXML,Spglib,LinearAlgebra
        BLAS.set_num_threads(1)
        W=WannierNLQG.Wannierization
        E=first(W._load_wannierization_extension!()).PAWMatrixElements
        @eval E _uiu_compute_center_blocks(state, center::Int, gauge_contract=nothing) = error("CENTER_RECOMPUTATION_FORBIDDEN")
        source=WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(ARGS[1];include_time_reversal=false)
        result=W.generate_wannier_uiu(W.WannierUIUGenerationConfig(source=source,
            topology_file=ARGS[2],output_file=ARGS[3],oracle_mmn_file=ARGS[4],max_cached_wavefunction_kpoints=2))
        @assert result.passed
        @assert JSON3.read(read(ARGS[3]*".provenance.json",String)).resumed_from_kpoint == 3
        println("FRESH_UIU_PUBLICATION_RECOVERY_PASS")
        """
        child =
            `$(Base.julia_cmd()) --startup-file=no --project=$(dirname(Base.active_project())) --threads=$(Threads.nthreads()) -e $recovery_code $(fixture.save_directory) $(fixture.nnkp_file) $output $oracle`
        @test occursin("FRESH_UIU_PUBLICATION_RECOVERY_PASS", read(child, String))
        @test uiu_test_file_sha256(output) == original_digest
        @test !isfile(recovery_paths.checkpoint)
        @test !isfile(recovery_paths.partial)
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
        config = UIU_WANNIERIZATION.ExactWannierOperatorBundleConfig(
            tb_file = tb_file,
            chk_file = chk_file,
            eig_file = eig_file,
            mmn_file = mmn_file,
            uiu_file = uiu_file,
            uiu_provenance_json = provenance_file,
            output_bundle_file = output_bundle,
        )
        result = UIU_WANNIERIZATION.prepare_exact_wannier_operator_bundle(config)
        @test result.passed
        @test result.operator_bundle_file == output_bundle
        @test result.operator_bundle_sha256 == uiu_test_file_sha256(output_bundle)
        bundle = WannierNLQG.IO.read_real_space_operator_bundle(output_bundle)
        @test bundle.manifest.schema_version == "1.1"
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
        exporter = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).OperatorExport
        values = NamedTuple{fieldnames(typeof(config))}(
            Tuple(getfield(config, name) for name in fieldnames(typeof(config))),
        )
        baseline_config = UIU_WANNIERIZATION.ExactWannierOperatorBundleConfig(;
            merge(values, (output_bundle_file = joinpath(directory, "unscoped-reference.h5"),))...,
        )
        baseline = exporter._prepare_exact_wannier_operator_bundle(
            baseline_config,
            exporter._exact_bundle_paths(baseline_config),
        )
        baseline_bundle =
            WannierNLQG.IO.read_real_space_operator_bundle(baseline.operator_bundle_file)
        @test result.input_sha256 == baseline.input_sha256
        @test result.scientific_content_sha256 == baseline.scientific_content_sha256
        @test all(
            bundle.operators[kind].data == baseline_bundle.operators[kind].data for
            kind in keys(bundle.operators)
        )
    end
end

@testset "VASP native overlap cache survives a fresh process without coefficient reads" begin
    isdefined(@__MODULE__, :write_bounded_vasp_fixture) ||
        include(joinpath(@__DIR__, "VASPNativeTestSupport.jl"))
    for use_incar in (true, false)
        mktempdir() do directory
            poscar, wavecar, _ = write_bounded_vasp_fixture(directory, 2, ComplexF64)
            potcar = joinpath(directory, "POTCAR")
            # Zero augmentation and identical radial waves define an exactly orthonormal
            # PAW fixture; numerical-quality gates remain at their production thresholds.
            write(
                potcar,
                replace(
                    synthetic_potcar_block("X"; q0 = 0.0),
                    "0.12 0.22 0.32" => "0.10 0.20 0.30",
                ),
            )
            open(wavecar, "r+") do stream
                for kpoint in 1:2, band in 1:2
                    coefficients = zeros(ComplexF64, 2kpoint)
                    coefficients[1 + (band - 1) * kpoint] = 1
                    seek(stream, 512*(2 + (kpoint - 1)*3 + band))
                    write(stream, coefficients)
                end
            end
            incar = joinpath(directory, "INCAR")
            use_incar && write(incar, "LNONCOLLINEAR = .TRUE.\nSAXIS = 0 0 1\n")
            source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
                poscar,
                wavecar;
                potcar_file = potcar,
                incar_file = use_incar ? incar : nothing,
                band_range = 1:2,
                spinor = true,
                spin_basis_saxis = (0.0, 0.0, 1.0),
                include_time_reversal = false,
            )
            topology = joinpath(directory, "topology.mmn")
            WannierNLQG.IO.write_wannier_mmn(
                topology,
                WannierNLQG.IO.WannierMMN(
                    2,
                    2,
                    1,
                    zeros(ComplexF64, 2, 2, 1, 2),
                    reshape([1, 2], 1, 2),
                    zeros(Int, 3, 1, 2),
                ),
            )
            extension = UIU_PAW_EXTENSION
            evaluate = () -> begin
                state = extension._uiu_vasp_state(source, topology)
                [state.overlap(k, k, (0, 0, 0), zeros(3)) for k in 1:2]
            end
            dense = evaluate()
            cold = extension._with_vasp_operator_artifacts(
                evaluate,
                source,
                directory;
                additional_inputs = [topology],
            )
            @test all(maximum(abs.(a .- b)) == 0.0 for (a, b) in zip(dense, cold))
            oracle = joinpath(directory, "oracle.mmn")
            data = zeros(ComplexF64, 2, 2, 1, 2)
            for k in 1:2
                data[:, :, 1, k] = cold[k]
            end
            WannierNLQG.IO.write_wannier_mmn(
                oracle,
                WannierNLQG.IO.WannierMMN(
                    2,
                    2,
                    1,
                    data,
                    reshape([1, 2], 1, 2),
                    zeros(Int, 3, 1, 2),
                ),
            )
            output = joinpath(directory, "native.uIu")
            config = UIU_WANNIERIZATION.WannierUIUGenerationConfig(
                source = source,
                topology_file = oracle,
                output_file = output,
                oracle_mmn_file = oracle,
                max_cached_wavefunction_kpoints = 2,
                overwrite = true,
            )
            legacy_args = ntuple(i -> getfield(config, i), 16)
            legacy = UIU_WANNIERIZATION.WannierUIUGenerationConfig(legacy_args...)
            @test legacy.execution === nothing
            @test all(getfield(legacy, i) == getfield(config, i) for i in 1:16)
            result = UIU_WANNIERIZATION.generate_wannier_uiu(config)
            @test isfile(output)
            digest = uiu_test_file_sha256(output)
            execution = UIU_WANNIERIZATION.WavefunctionPreparationExecutionConfig(
                checkpoint_directory = joinpath(directory, "explicit-preparation"),
            )
            explicit = UIU_WANNIERIZATION.WannierUIUGenerationConfig(legacy_args..., execution)
            UIU_WANNIERIZATION.generate_wannier_uiu(explicit)
            @test isdir(joinpath(execution.checkpoint_directory, "shared-native"))
            @test uiu_test_file_sha256(output) == digest
            eig = joinpath(directory, "native.eig")
            WannierNLQG.IO.write_wannier_eig(
                eig,
                WannierNLQG.IO.WannierEIG(2, 2, [-1.0 -1.0; 1.0 1.0]),
            )
            spin = joinpath(directory, "native.spn")
            spin_provenance = spin * ".h5"
            UIU_WANNIERIZATION.generate_vasp_paw_spn(
                source;
                output_spn_file = spin,
                provenance_hdf5 = spin_provenance,
                spin_channel = 1,
            )
            validations = Ref(0)
            validate =
                () -> extension._read_and_validate_spn_provenance(
                    spin_provenance,
                    spin;
                    expected_num_bands = 2,
                    expected_num_kpoints = 2,
                    target_authority = UIU_WANNIERIZATION.NativeDFTHamiltonian(),
                    reader = (args...; kwargs...) -> begin
                        validations[] += 1
                        extension._read_and_validate_spn_provenance_uncached(args...; kwargs...)
                    end,
                )
            extension._with_vasp_operator_artifacts(
                source,
                directory;
                additional_inputs = String[],
            ) do
                first = validate()
                expected = first.spn_sha256
                first.artifacts["spn_sha256"] = "caller-mutated-copy"
                second = extension._with_spn_provenance_reuse(validate)
                @test second.artifacts["spn_sha256"] == expected
                @test validations[] == 1
                chmod(spin, 0o400)
                chmod(spin_provenance, 0o400)
                refreshed = validate()
                @test refreshed.spn_sha256 == expected
                @test refreshed.artifacts["spn_sha256"] == expected
                @test validations[] == 1
                chmod(spin, 0o600)
                chmod(spin_provenance, 0o600)
                @test_throws ArgumentError extension._read_and_validate_spn_provenance(
                    spin_provenance,
                    spin;
                    expected_num_bands = 3,
                    expected_num_kpoints = 2,
                    target_authority = UIU_WANNIERIZATION.NativeDFTHamiltonian(),
                )
                validate()
                original = read(spin_provenance)
                try
                    write(spin_provenance, vcat(original, UInt8[0]))
                    @test_throws ArgumentError validate()
                finally
                    write(spin_provenance, original)
                end
            end
            count_after_scope = validations[]
            validate()
            @test validations[] == count_after_scope + 1
            @test !haskey(task_local_storage(), :wannier_spn_provenance_reuse) ||
                  task_local_storage(:wannier_spn_provenance_reuse) === nothing
            operator_digests = String[]
            for operator in (:uhu, :siu, :shu)
                operator_output = joinpath(directory, "native.$operator")
                operator_config = UIU_WANNIERIZATION.WannierHamiltonianOperatorGenerationConfig(
                    source = source,
                    topology_file = oracle,
                    eig_file = eig,
                    output_file = operator_output,
                    spn_file = spin,
                    spn_provenance_file = spin_provenance,
                    overwrite = true,
                    max_cached_wavefunction_kpoints = 2,
                )
                generated = getproperty(UIU_WANNIERIZATION, Symbol("generate_wannier_$operator"))(
                    operator_config,
                )
                @test generated.artifact_published
                push!(operator_digests, uiu_test_file_sha256(operator_output))
                before = stat(operator_output)
                resumed_operator =
                    getproperty(UIU_WANNIERIZATION, Symbol("generate_wannier_$operator"))(
                        operator_config,
                    )
                after = stat(operator_output)
                @test (before.inode, before.mtime, before.size) ==
                      (after.inode, after.mtime, after.size)
                @test resumed_operator.input_sha256 == generated.input_sha256
                if operator == :uhu
                    original = read(operator_output)
                    try
                        write(operator_output, vcat(original, UInt8[0]))
                        @test_throws ArgumentError UIU_WANNIERIZATION.generate_wannier_uhu(
                            operator_config,
                        )
                    finally
                        write(operator_output, original)
                    end
                end
            end
            script = joinpath(directory, "resume-uiu.jl")
            write(
                script,
                """
    using WannierNLQG, SHA
    W = WannierNLQG.Wannierization
    W._load_wannierization_extension!()
    @eval WannierNLQG.SymmetryFoundation function _read_vasp_coefficient_record(path, header, bands, record, spin_transform; normalize_coefficients::Bool)
        error("VASP_UIU_RESTORE_COEFFICIENT_READ_FORBIDDEN")
    end
    paw = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).PAWMatrixElements
    @eval paw _uiu_source_state(source::VASPWavefunctionSource, topology, cache_size) = error("COMPLETED_VASP_UIU_PREPARATION_FORBIDDEN")
    source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(ARGS[1], ARGS[2];
        potcar_file=ARGS[3], incar_file=isfile(joinpath(dirname(ARGS[3]),"INCAR")) ? joinpath(dirname(ARGS[3]),"INCAR") : nothing, band_range=1:2, spinor=true,
        spin_basis_saxis=(0.0,0.0,1.0), include_time_reversal=false)
    config = W.WannierUIUGenerationConfig(source=source, topology_file=ARGS[4],
        output_file=ARGS[5], oracle_mmn_file=ARGS[6], max_cached_wavefunction_kpoints=2, overwrite=false,
        execution=W.WavefunctionPreparationExecutionConfig(checkpoint_directory=joinpath(dirname(ARGS[5]),"explicit-preparation")))
    W.generate_wannier_uiu(config)
    @assert bytes2hex(open(SHA.sha256, ARGS[5])) == ARGS[7]
    println("VASP_PUBLIC_UIU_FRESH_REUSE_PASS ", ARGS[7])
    root = dirname(ARGS[5])
    spin = joinpath(root, "native.spn")
    spin_provenance = spin * ".h5"
    export_extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).OperatorExport
    @eval export_extension function _hamiltonian_operator_overlap_state(config::WannierHamiltonianOperatorGenerationConfig)
        error("COMPLETED_OPERATOR_PREPARATION_FORBIDDEN")
    end
    for (index, operator) in enumerate((:uhu, :siu, :shu))
        output = joinpath(root, "native." * string(operator))
        cfg = W.WannierHamiltonianOperatorGenerationConfig(source=source,
            topology_file=ARGS[6], eig_file=joinpath(root,"native.eig"), output_file=output,
            spn_file=spin, spn_provenance_file=spin_provenance, overwrite=false,
            max_cached_wavefunction_kpoints=2)
        result = getproperty(W, Symbol("generate_wannier_" * string(operator)))(cfg)
        @assert result.artifact_published
        @assert bytes2hex(open(SHA.sha256, output)) == ARGS[7+index]
    end
    @eval paw function _generate_vasp_paw_spn_prepared(source::VASPWavefunctionSource; kwargs...)
        error("COMPLETED_VASP_SPN_PREPARATION_FORBIDDEN")
    end
    W.generate_vasp_paw_spn(source; output_spn_file=spin,
        provenance_hdf5=spin_provenance, spin_channel=1)
    println("VASP_ALL_OPERATORS_FRESH_REUSE_PASS")
    println("VASP_COMPLETED_OPERATORS_NO_PREPARATION_PASS")
    """,
            )
            # Publication receipts bind the environment: preserve Pkg.test's active
            # project in the child instead of switching to the source project.
            resumed = read(
                `$(Base.julia_cmd()) --startup-file=no --project=$(dirname(Base.active_project())) $script $poscar $wavecar $potcar $oracle $output $oracle $digest $operator_digests`,
                String,
            )
            print(resumed)
            @test occursin("VASP_PUBLIC_UIU_FRESH_REUSE_PASS", resumed)
            @test occursin("VASP_ALL_OPERATORS_FRESH_REUSE_PASS", resumed)
            @test uiu_test_file_sha256(output) == digest
        end
    end
end

@testset "Standard uIu publishes finite warnings but retains integrity failures" begin
    mktempdir() do directory
        poscar, wavecar, _ = write_bounded_vasp_fixture(directory, 2, ComplexF64)
        potcar = joinpath(directory, "POTCAR")
        write(potcar, synthetic_potcar_block("X"; q0 = 0.02))
        source = WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
            poscar,
            wavecar;
            potcar_file = potcar,
            band_range = 1:2,
            spinor = true,
            spin_basis_saxis = (0.0, 0.0, 1.0),
            include_time_reversal = false,
        )
        topology = joinpath(directory, "source.mmn")
        WannierNLQG.IO.write_wannier_mmn(
            topology,
            WannierNLQG.IO.WannierMMN(
                2,
                2,
                1,
                zeros(ComplexF64, 2, 2, 1, 2),
                reshape([1, 2], 1, 2),
                zeros(Int, 3, 1, 2),
            ),
        )
        make_config =
            (policy, filename) -> UIU_WANNIERIZATION.WannierUIUGenerationConfig(
                construction_policy = policy,
                source = source,
                topology_file = topology,
                output_file = joinpath(directory, filename),
                oracle_mmn_file = topology,
                max_cached_wavefunction_kpoints = 2,
            )
        standard = make_config(:standard, "warning.uIu")
        result = UIU_WANNIERIZATION.generate_wannier_uiu(standard)
        @test !result.passed
        @test isfile(standard.output_file)
        @test result.generalized_norm_max_absolute >
              standard.thresholds.generalized_norm_max_absolute
        payload = JSON3.read(read(result.artifacts["provenance_json"], String))
        @test payload.status == "EXPORTED_WITH_WARNING"
        @test !payload.passed && payload.physical_overlap_available
        @test !payload.production_eligible
        @test payload.diagonal_identity_max_absolute >
              standard.thresholds.diagonal_identity_max_absolute
        @test "NUMERICAL_WARNING:UIU_PREFLIGHT_GATE_FAILED" in payload.diagnostics
        @test "NUMERICAL_WARNING:UIU_OUTPUT_GATE_FAILED" in payload.diagnostics
        before_reuse = stat(standard.output_file)
        reused_warning = UIU_WANNIERIZATION.generate_wannier_uiu(standard)
        after_reuse = stat(standard.output_file)
        @test !reused_warning.passed
        @test reused_warning.diagonal_identity_max_absolute == result.diagonal_identity_max_absolute
        @test reused_warning.artifacts == result.artifacts
        @test (before_reuse.inode, before_reuse.mtime, before_reuse.size) ==
              (after_reuse.inode, after_reuse.mtime, after_reuse.size)
        export_extension =
            Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt).OperatorExport
        gauge = UIU_PAW_EXTENSION.generation_band_gauge_contract(
            source,
            UIU_WANNIERIZATION.NativeDFTHamiltonian(),
            nothing,
            2,
            2;
            construction_policy = :standard,
        )
        accepted = export_extension._qualified_uiu_sidecar(
            result.artifacts["provenance_json"],
            standard.output_file,
            topology,
            gauge;
            construction_policy = :standard,
        )
        @test !accepted.passed && accepted.status == "EXPORTED_WITH_WARNING"
        @test_throws ArgumentError export_extension._qualified_uiu_sidecar(
            result.artifacts["provenance_json"],
            standard.output_file,
            topology,
            gauge,
        )
        tampered = Dict{Symbol, Any}(Symbol(key) => value for (key, value) in pairs(payload))
        tampered[:production_eligible] = true
        @test !export_extension._uiu_sidecar_quality_available(
            JSON3.read(JSON3.write(tampered)),
            :standard,
        )
        tampered[:production_eligible] = false
        tampered[:generalized_normalization_max_absolute] = nothing
        @test !export_extension._uiu_sidecar_quality_available(
            JSON3.read(JSON3.write(tampered)),
            :standard,
        )
        strict = make_config(:strict, "strict.uIu")
        rejected = UIU_WANNIERIZATION.generate_wannier_uiu(strict)
        @test !rejected.passed
        @test !isfile(strict.output_file)
        @test rejected.generalized_norm_max_absolute == result.generalized_norm_max_absolute
        open(wavecar, "r+") do stream
            seek(stream, 512*3)
            write(stream, ComplexF64(NaN, 0))
        end
        nonfinite = make_config(:standard, "nonfinite.uIu")
        @test_throws ArgumentError UIU_WANNIERIZATION.generate_wannier_uiu(nonfinite)
        @test !isfile(nonfinite.output_file)
    end
end

@testset "single-k-point QE operator preparation retains matrix coordinates" begin
    mktempdir() do directory
        fixture = write_qe_paw_fixture(
            directory;
            metric_kind = :paw,
            spinor = true,
            spinorbit = true,
            num_kpoints = 1,
        )
        source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
            fixture.save_directory;
            include_time_reversal = false,
        )
        state = UIU_PAW_EXTENSION._uiu_qe_state(source, fixture.nnkp_file, 2)
        @test state.native.kpoints_fractional == zeros(1, 3)
        @test state.native.mp_grid == (1, 1, 1)
        @test state.generalized_norm == 0.0
    end
end

struct UIUCanonicalFrameAuthority end
const UIU_CANONICAL_FRAME_BUILDS = Ref(0)
@eval UIU_PAW_EXTENSION begin
    function _build_generation_band_gauge_contract(
        source,
        ::$(UIUCanonicalFrameAuthority),
        gauge,
        bands::Int,
        points::Int;
        construction_policy::Symbol = :strict,
    )
        $(UIU_CANONICAL_FRAME_BUILDS)[] += 1
        source.band_range == 1:bands || error("unresolved full native frame")
        return reshape(ComplexF64.(1:(bands * points)), bands, points)
    end
end

@testset "Implicit full native source shares the sealed gauge frame" begin
    mktempdir() do directory
        gauge = joinpath(directory, "gauge.h5")
        function write_header(target, parent)
            HDF5.h5open(gauge, "w") do handle
                attrs = HDF5.attributes(handle)
                attrs["target_band_start"] = first(target)
                attrs["target_band_stop"] = last(target)
                attrs["parent_band_start"] = first(parent)
                attrs["parent_band_stop"] = last(parent)
            end
        end
        write_header(1:2, 1:2)
        sources = (
            WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(directory),
            WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
                joinpath(directory, "POSCAR"),
                joinpath(directory, "WAVECAR"),
            ),
        )
        for (index, source) in enumerate(sources)
            explicit = UIU_PAW_EXTENSION._generation_gauge_source(source, gauge)
            @test source.band_range === nothing
            @test explicit.band_range == 1:2
            for field in fieldnames(typeof(source))
                field == :band_range && continue
                @test isequal(getfield(source, field), getfield(explicit, field))
            end
            @test UIU_PAW_EXTENSION._generation_gauge_source(source, nothing) === source
            @test UIU_PAW_EXTENSION._generation_gauge_source(explicit, gauge) === explicit
            UIU_CANONICAL_FRAME_BUILDS[] = 0
            cache = joinpath(directory, "cache-$(index)")
            load_frame = function (selected)
                UIU_PAW_EXTENSION._generation_band_gauge_contract(
                    selected,
                    UIUCanonicalFrameAuthority(),
                    gauge,
                    2,
                    3;
                    construction_policy = :standard,
                )
            end
            expected = WannierNLQG.IO.with_preparation_artifact_cache(cache, "full-frame-test") do
                first_result = load_frame(source)
                second_result = load_frame(explicit)
                @test first_result == second_result
                @test UIU_CANONICAL_FRAME_BUILDS[] == 1
                first_result
            end
            restored = WannierNLQG.IO.with_preparation_artifact_cache(cache, "full-frame-test") do
                load_frame(source)
            end
            @test restored == expected
            @test UIU_CANONICAL_FRAME_BUILDS[] == 1
        end
        for (target, parent) in ((2:2, 1:2), (1:1, 1:2), (2:3, 2:3))
            write_header(target, parent)
            for source in sources
                @test_throws ArgumentError UIU_PAW_EXTENSION._generation_gauge_source(source, gauge)
            end
        end
    end
end
