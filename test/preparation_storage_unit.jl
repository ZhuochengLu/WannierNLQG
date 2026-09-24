module PreparationStorageUnitTests

using Test, WannierNLQG, HDF5, JSON3
isdefined(@__MODULE__, :QEPAWMatrixElementsTestSupport) ||
    include(joinpath(@__DIR__, "QEPAWMatrixElementsTestSupport.jl"))
using .QEPAWMatrixElementsTestSupport

@testset "bounded preparation storage" begin
    storage = WannierNLQG.IO
    mktempdir() do directory
        storage.with_preparation_storage(directory) do
            values = storage.preparation_vector(Matrix{ComplexF64}, "arrays")
            original = reshape(ComplexF64.(1:12), 3, 4)
            push!(values, original)
            push!(values, -original)
            @test values[1] == original
            @test values[2] == -original
            storage.preparation_release!()
            @test values[1] == original
            storage.preparation_release!()
            open(joinpath(values.directory, "1.bin"), "a") do io
                write(io, UInt8(0))
            end
            @test_throws ArgumentError values[1]
        end
        @test storage.preparation_vector(Float64, "dense", 2) isa Vector{Float64}
    end
end

@testset "native dimension validation visits a bounded provider once" begin
    S = WannierNLQG.SymmetryFoundation
    visits = zeros(Int, 3)
    provider = WannierNLQG.IO.preparation_source_vector(S.PlaneWaveKPoint, 3) do index
        visits[index] += 1
        S.PlaneWaveKPoint(zeros(3), zeros(Int, 1, 3), ones(ComplexF64, 2, 1, 1), [-1.0, 1.0])
    end
    @test S._native_point_dimensions(provider) == (2, 1)
    @test visits == [1, 1, 1]
    invalid = WannierNLQG.IO.preparation_source_vector(S.PlaneWaveKPoint, 3) do index
        bands = index == 3 ? 1 : 2
        S.PlaneWaveKPoint(zeros(3), zeros(Int, 1, 3), ones(ComplexF64, bands, 1, 1), zeros(bands))
    end
    @test_throws ArgumentError S._native_point_dimensions(invalid)
end

isdefined(@__MODULE__, :write_bounded_vasp_fixture) ||
    include(joinpath(@__DIR__, "VASPNativeTestSupport.jl"))

@testset "VASP indexed WAVECAR exact arrays and lazy access" begin
    S = WannierNLQG.SymmetryFoundation
    E = first(WannierNLQG.Wannierization._load_wannierization_extension!()).PAWMatrixElements
    for spins in (1, 2), precision in (ComplexF32, ComplexF64)
        mktempdir() do directory
            poscar, wavecar, expected = write_bounded_vasp_fixture(directory, spins, precision)
            source = S.VASPWavefunctionSource(
                poscar,
                wavecar;
                spinor = spins == 2,
                spin_basis_saxis = (0.0, 0.0, 1.0),
                include_time_reversal = false,
            )
            dense = S.read_vasp_wavefunctions(source; normalize_coefficients = false)
            reads = zeros(Int, 2)
            provider =
                (loader, count) ->
                    WannierNLQG.IO.preparation_source_vector(S.PlaneWaveKPoint, count) do index
                        reads[index] += 1
                        loader(index)
                    end
            bounded = S.read_vasp_wavefunctions(
                source;
                normalize_coefficients = false,
                point_provider = provider,
            )
            @test reads == [0, 0]
            for index in 1:2
                metadata = S.native_point_metadata(bounded, index)
                @test metadata.k_fractional == dense.kpoints[index].k_fractional
                @test metadata.energies_ev == dense.kpoints[index].energies_ev
                @test metadata.num_bands == 2
                @test metadata.spin_components == spins
            end
            @test reads == [0, 0]
            @test E._uiu_num_bands(bounded) == 2
            @test E._uiu_kpoint_fractional(bounded, 2) == [0.5, 0.0, 0.0]
            @test reads == [0, 0]
            @test bounded.input_sha256 == dense.input_sha256
            @test bounded.source_metadata == dense.source_metadata
            @test bounded.mp_grid == (2, 1, 1)
            for index in 1:2
                point = bounded.kpoints[index]
                @test point.coefficients == expected[index] == dense.kpoints[index].coefficients
                @test point.g_vectors == dense.kpoints[index].g_vectors
                @test point.energies_ev == dense.kpoints[index].energies_ev
                @test point.k_fractional == dense.kpoints[index].k_fractional
                @test bounded.kpoints[index] === point
            end
            @test reads == [1, 1]
            @test bounded.kpoints[1].coefficients == expected[1]
            @test reads == [2, 1]
            # The lazy path must reject truncated coefficient records when consumed.
            open(wavecar, "r+") do io
                truncate(io, 512*6)
            end
            @test_throws ArgumentError bounded.kpoints[2]
        end
    end
end

@testset "compact artifact memory reuse is bounded and isolated" begin
    storage = WannierNLQG.IO
    mktempdir() do directory
        payload = [1.0, 2.0, 3.0, 4.0]
        budget = Base.summarysize(payload)
        storage.with_preparation_artifact_cache(
            directory,
            "memory-fixture";
            max_resident_bytes = budget,
        ) do
            fetch(label, builder) =
                storage.cached_preparation_artifact(builder, label, () -> "identity")
            @test fetch("a", () -> copy(payload)) == payload
            restored = fetch("a", () -> error("disk cache must avoid builder"))
            restored[1] = 99.0
            borrowed = fetch("a", () -> error("memory cache must avoid builder"))
            @test borrowed == payload
            @test borrowed !== restored
            context = get(task_local_storage(), :wannier_preparation_artifact_cache, nothing)
            @test context.resident_bytes[] <= budget
            @test fetch("b", () -> -payload) == -payload
            @test fetch("b", () -> error("b must be durable")) == -payload
            @test length(context.resident) == 1
            @test context.resident_bytes[] <= budget
            @test fetch("a", () -> error("eviction must restore from disk")) == payload
            artifact = only(
                filter(p -> endswith(p, ".bin"), readdir(joinpath(directory, "a"); join = true)),
            )
            key = only(keys(context.resident))
            cached_payload = context.resident[key].payload
            digest = context.resident[key].digest
            before = storage._preparation_artifact_identity(artifact)
            chmod(artifact, 0o400)
            chmod(artifact * ".sha256", 0o400)
            @test fetch("a", () -> error("metadata changes must not rebuild")) == payload
            @test context.resident[key].payload === cached_payload
            @test context.resident[key].digest == digest
            @test context.resident[key].identity != before
            @test storage._preparation_verified_artifact_identity(artifact, before, "invalid") ===
                  nothing
            chmod(artifact, 0o600)
            chmod(artifact * ".sha256", 0o600)
            open(artifact, "a") do stream
                write(stream, UInt8(0))
            end
            @test fetch("a", () -> fill(7.0, 4)) == fill(7.0, 4)
        end
        storage.with_preparation_artifact_cache(
            directory,
            "memory-fixture";
            max_resident_bytes = 0,
        ) do
            restored = storage.cached_preparation_artifact(
                () -> error("new scope must restore"),
                "a",
                () -> "identity",
            )
            @test restored == fill(7.0, 4)
            @test isempty(
                get(task_local_storage(), :wannier_preparation_artifact_cache, nothing).resident,
            )
        end
        progress = read(joinpath(directory, "preparation_progress.jsonl"), String)
        @test occursin("MEMORY_HIT", progress)
    end
end

@testset "preparation checksum sidecars use independent atomic temporaries" begin
    storage = WannierNLQG.IO
    mktempdir() do directory
        path_a = joinpath(directory, "payload-a.bin")
        path_b = joinpath(directory, "payload-b.bin")
        @sync begin
            Threads.@spawn storage.write_preparation_checkpoint(path_a, "contract-a", [1, 2, 3])
            Threads.@spawn storage.write_preparation_checkpoint(path_b, "contract-b", [4, 5, 6])
        end
        @test storage.read_preparation_checkpoint(path_a, "contract-a") == [1, 2, 3]
        @test storage.read_preparation_checkpoint(path_b, "contract-b") == [4, 5, 6]
        @test isempty(filter(name -> endswith(name, ".tmp"), readdir(directory; join = true)))
    end
end

@testset "multi-star Standard symmetrized preparation and resume" begin
    W = WannierNLQG.Wannierization
    S = WannierNLQG.SymmetryFoundation
    E = first(W._load_wannierization_extension!()).PAWMatrixElements
    mktempdir() do directory
        fixture = write_qe_paw_fixture(directory; num_kpoints = 7)
        xml = joinpath(fixture.save_directory, "data-file-schema.xml")
        text = replace(
            read(xml, String),
            "<a2>0.0 2.0 0.0</a2>" => "<a2>0.2 2.3 0.0</a2>",
            "<a3>0.0 0.0 2.0</a3>" => "<a3>0.1 0.3 2.7</a3>",
        )
        write(xml, text)
        source = S.QuantumEspressoWavefunctionSource(
            fixture.save_directory;
            band_range = 1:1,
            include_time_reversal = false,
        )
        scope = S.BandRepresentationQualificationScope(trues(1, 7), trues(1, 7))
        contract = W.TargetSubspaceQualificationContract(
            scope;
            outer_min_ev = -18.0,
            outer_max_ev = 3.5,
            frozen_min_ev = -18.0,
            frozen_max_ev = 0.5,
            num_wannier = 1,
        )
        results = []
        digests = String[]
        for (index, (mode, workers)) in enumerate([
            (:dense_reference, 1),
            (:streaming_serial, 1),
            (:streaming_threads, 2),
            (:streaming_threads, 4),
            (:streaming_serial, 1),
            (:streaming_serial, 1),
            (:streaming_serial, 1),
        ])
            checkpoint = joinpath(directory, index == 5 ? "checkpoint-2" : "checkpoint-$(index)")
            config = W.SymmetryCovariantWavefunctionPreparationConfig(
                execution = W.WavefunctionPreparationExecutionConfig(
                    mode = mode,
                    max_workers = workers,
                    checkpoint_directory = checkpoint,
                ),
                construction_policy = :standard,
                source = source,
                wavefunction_gauge_backend = W.StarCovariantPAWGauge(
                    block_partition_policy = W.HamiltonianWeightedPAWBlockPartition(),
                    hamiltonian_correction = W.FarBandCovarianceCorrection(
                        qualification_mode = :standard,
                    ),
                ),
                authoritative_hamiltonian = W.SymmetrizedDFTHamiltonian(),
                target_subspace_contract = contract,
                output_hdf5 = joinpath(directory, "multi-$(index).h5"),
                target_band_count = 1,
            )
            prior_star_mtime = nothing
            if index in (6, 7)
                fields =
                    (; (name => getfield(config, name) for name in fieldnames(typeof(config)))...)
                pilot = W.SymmetryCovariantWavefunctionPreparationConfig(;
                    merge(fields, (; maximum_star_count = 1))...,
                )
                interrupted = try
                    W.prepare_symmetry_covariant_wavefunctions(pilot)
                    nothing
                catch exception
                    exception
                end
                @test interrupted isa ArgumentError &&
                      occursin("STAR_PREFLIGHT_LIMIT_REACHED_PASS", sprint(showerror, interrupted))
                @test !isfile(joinpath(checkpoint, "stages", "completed_payload.bin"))
                prior_star_mtime = stat(joinpath(checkpoint, "stars", "star-1.bin")).mtime
                if index == 7
                    write(joinpath(checkpoint, "stars", "star-1.bin.sha256"), repeat("0", 64))
                end
            end
            event_path = joinpath(checkpoint, "resource_events.jsonl")
            previous_events = isfile(event_path) ? readlines(event_path) : String[]
            previous_native_reads =
                count(line -> occursin("native_read_started", line), previous_events)
            result = W.prepare_symmetry_covariant_wavefunctions(config)
            if index == 5
                events = readlines(event_path)
                @test previous_native_reads > 0
                @test count(line -> occursin("native_read_started", line), events) ==
                      previous_native_reads
                @test any(
                    line -> occursin("completed_payload_resumed", line),
                    events[(length(previous_events) + 1):end],
                )
            end
            if index == 6
                @test stat(joinpath(checkpoint, "stars", "star-1.bin")).mtime == prior_star_mtime
            elseif index == 7
                @test stat(joinpath(checkpoint, "stars", "star-1.bin")).mtime != prior_star_mtime
            end
            @test result.status == :STANDARD
            @test length(result.star_representatives) == 4
            push!(results, result)
            restored =
                WannierNLQG.IO.with_preparation_storage(joinpath(directory, "readback-$(index)")) do
                    Base.invokelatest(
                        E._read_star_covariant_paw_gauge_hdf5,
                        result.output_hdf5;
                        construction_policy = :standard,
                    )
                end
            push!(digests, Base.invokelatest(E._star_payload_sha256, restored.payload))
        end
        @test length(unique(digests)) == 1
        @test all(result -> result.maxima == results[1].maxima, results)
        @test all(result -> result.maximum_contexts == results[1].maximum_contexts, results)
    end
end

@testset "dense versus streamed NC gauge exact parity" begin
    W = WannierNLQG.Wannierization
    E = first(W._load_wannierization_extension!()).PAWMatrixElements
    mktempdir() do directory
        fixture = write_qe_paw_fixture(directory; metric_kind = :norm_conserving)
        source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
            fixture.save_directory;
            band_range = 1:1,
            include_time_reversal = false,
        )
        outcomes = []
        payloads = []
        for mode in (:dense_reference, :streaming_serial)
            config = W.SymmetryCovariantWavefunctionPreparationConfig(
                execution = W.WavefunctionPreparationExecutionConfig(mode = mode),
                construction_policy = :strict,
                source = source,
                wavefunction_gauge_backend = W.StarCovariantPAWGauge(
                    buffer_policy = W.ClosureDrivenBandBuffer(max_extra_bands = 0),
                ),
                output_hdf5 = joinpath(directory, string(mode) * ".h5"),
                target_band_count = 1,
            )
            result = W.prepare_symmetry_covariant_wavefunctions(config)
            @test result.status == :PASS
            push!(outcomes, result)
            restored = Base.invokelatest(E._read_star_covariant_paw_gauge_hdf5, result.output_hdf5)
            push!(payloads, restored.payload)
        end
        @test outcomes[1].maxima == outcomes[2].maxima
        @test outcomes[1].maximum_contexts == outcomes[2].maximum_contexts
        @test payloads[1].rotations == payloads[2].rotations
        @test payloads[1].native.kpoints[1].coefficients ==
              payloads[2].native.kpoints[1].coefficients
    end
end

@testset "preparation checkpoint commit and invalidation" begin
    storage = WannierNLQG.IO
    mktempdir() do directory
        path = joinpath(directory, "star-1.bin")
        payload = (coefficients = reshape(ComplexF64.(1:12), 3, 4), diagnostics = [0.0, 1.0])
        @test storage.read_preparation_checkpoint(path, "contract-A") === nothing
        storage.write_preparation_checkpoint(path, "contract-A", payload)
        @test storage.read_preparation_checkpoint(path, "contract-A") == payload
        @test storage.read_preparation_checkpoint(path, "contract-B") === nothing
        rm(path * ".sha256") # Interrupted before the commit marker.
        @test storage.read_preparation_checkpoint(path, "contract-A") === nothing
        storage.write_preparation_checkpoint(path, "contract-A", payload)
        open(path, "a") do io
            write(io, UInt8(0))
        end
        @test storage.read_preparation_checkpoint(path, "contract-A") === nothing
        storage.write_preparation_checkpoint(path, "contract-A", payload)
        @test storage.read_preparation_checkpoint(path, "contract-A") == payload
        write(path * ".partial", "uncommitted")
        @test storage.read_preparation_checkpoint(path * ".partial", "contract-A") === nothing
    end
end

@testset "committed workspace lifecycle preserves reachable scientific arrays" begin
    storage = WannierNLQG.IO
    mktempdir() do directory
        storage.with_preparation_storage(directory) do
            keep = storage.preparation_vector(Matrix{ComplexF64}, "committed")
            superseded = storage.preparation_vector(Matrix{ComplexF64}, "superseded")
            original = reshape(ComplexF64.(1:12), 3, 4)
            push!(keep, original)
            push!(superseded, -original)
            payload = (points = keep,)
            path = joinpath(directory, "completed.bin")
            storage.preparation_release!()
            storage.write_preparation_checkpoint(path, "contract", payload)
            evidence = storage.preparation_compact_workspace!(payload)
            @test evidence.removed_bytes > 0
            @test !isdir(superseded.directory)
            @test keep[1] == original
            restored = storage.read_preparation_checkpoint(path, "contract")
            @test storage.preparation_restore_vectors!(restored)
            @test restored.points[1] == original
        end
    end
end

@testset "ordinary independent preparation blocks and resume" begin
    storage = WannierNLQG.IO
    W = WannierNLQG.Wannierization
    mktempdir() do directory
        reference = [reshape(ComplexF64.(1:9), 3, 3) .* k for k in 1:5]
        for workers in (1, 2, 4)
            execution = W.WavefunctionPreparationExecutionConfig(
                mode = :streaming_threads,
                max_workers = workers,
                checkpoint_directory = joinpath(directory, string(workers)),
            )
            for resumed in (false, true)
                outputs = Matrix{ComplexF64}[]
                owner = current_task()
                work =
                    resumed ? ((i, a) -> error("completed block was recomputed")) :
                    ((i, a) -> a' * a)
                task_local_storage(:wannier_preparation_execution, execution) do
                    storage.foreach_preparation_block(
                        work,
                        i -> begin
                            @test current_task() === owner
                            reference[i]
                        end,
                        (i, a) -> push!(outputs, a),
                        length(reference);
                        contract = "ordinary-test-v1",
                        label = "blocks",
                        fingerprint = a -> string(sum(a)),
                    )
                end
                @test outputs == [a' * a for a in reference]
            end
        end
    end
end

@testset "ordinary native AMN dense oracle and workers" begin
    include(joinpath(@__DIR__, "WannierizationFixtureSupport.jl"))
    W = WannierNLQG.Wannierization
    E = first(W._load_wannierization_extension!()).RepresentationPreparation
    Base.include(E, joinpath(@__DIR__, "NativeAMNDenseOracle.jl"))
    mktempdir() do directory
        fixture = write_qe_paw_fixture(directory; metric_kind = :norm_conserving, num_kpoints = 3)
        source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
            fixture.save_directory;
            include_time_reversal = false,
        )
        native = Base.invokelatest(E.read_native_source, source; purpose = :physical_overlap)
        basis = synthetic_wannierization_fixture().basis
        expected = Base.invokelatest(E._dense_native_amn_test_oracle, native, basis)
        for workers in (1, 2, 4)
            execution = W.WavefunctionPreparationExecutionConfig(
                mode = :streaming_threads,
                max_workers = workers,
                checkpoint_directory = joinpath(directory, "amn-$(workers)"),
            )
            actual = task_local_storage(:wannier_preparation_execution, execution) do
                Base.invokelatest(E._generate_amn, native, basis)
            end
            @test actual == expected
            resumed = task_local_storage(:wannier_preparation_execution, execution) do
                Base.invokelatest(E._generate_amn, native, basis)
            end
            @test resumed == expected
        end
    end
end

@testset "MMN parsing preserves original Float64 tokens and ordering" begin
    parser = WannierNLQG.IO._wannier_complex_pair
    tokens = [
        "-0.0",
        "+0.0",
        "1.2345678901234567E-12",
        "-2.3e+08",
        string(floatmin(Float64)),
        string(floatmax(Float64)),
        string(nextfloat(0.0)),
        "NaN",
        "Inf",
    ]
    for left in tokens, right in tokens, whitespace in (" ", "\t", "\u2003")
        row = "  " * left * whitespace * right * " ignored third token "
        fields = split(strip(row))
        expected = ComplexF64(parse(Float64, fields[1]), parse(Float64, fields[2]))
        @test isequal(parser(row), expected)
    end
    for row in ("", " ", "1.0", "1.0 \t ")
        @test parser(row) === nothing
    end
    @test_throws ArgumentError parser("invalid 1.0")
    mktempdir() do directory
        path = joinpath(directory, "fixture.mmn")
        rows = ["-0.0 1e-12", "2.0\t-3.0 trailing", "4.0 5.0", "6.0\u20037.0"]
        write(path, "fixture\n2 1 1\n1 1 0 0 0\n" * join(rows, "\n") * "\n")
        result = WannierNLQG.IO.read_wannier_mmn(path)
        expected =
            reshape(ComplexF64[ComplexF64(-0.0, 1e-12), 2 - 3im, 4 + 5im, 6 + 7im], 2, 2, 1, 1)
        @test isequal(result.data, expected)
        @test result.neighbors == reshape([1], 1, 1)
        write(path, "fixture\n2 1 1\n1 1 0 0 0\n1 0\n")
        @test_throws ErrorException WannierNLQG.IO.read_wannier_mmn(path)
    end
end

end

module AcceptedMatrixResolutionTests
using Test, WannierNLQG
const W = WannierNLQG.Wannierization
const E = first(W._load_wannierization_extension!()).WorkflowOrchestration
@testset "resolved matrix checkpoint preserves payload and avoids generator" begin
    mktempdir() do directory
        mmn = WannierNLQG.IO.WannierMMN(
            1,
            1,
            1,
            ones(ComplexF64, 1, 1, 1, 1),
            ones(Int, 1, 1),
            zeros(Int, 3, 1, 1),
        )
        file=joinpath(directory, "input.mmn")
        WannierNLQG.IO.write_wannier_mmn(file, mmn)
        resolved=(;
            mmn,
            amn = nothing,
            mmn_file = file,
            amn_file = nothing,
            raw_amn_file = nothing,
            source_kind = "native_fixture",
            paw_result = nothing,
            gauge_sha256 = "",
            gauge_provenance_file = nothing,
        )
        path=joinpath(directory, "accepted.bin")
        count=Ref(0)
        first_result=E._cached_resolved_matrices(path, "bound-inputs-v1") do
            count[]+=1
            resolved
        end
        second_result=E._cached_resolved_matrices(path, "bound-inputs-v1") do
            error("MATRIX_REGENERATION_FORBIDDEN")
        end
        @test count[]==1
        @test second_result.mmn.data==first_result.mmn.data
        @test second_result.source_kind==first_result.source_kind
        @test read(file, String)==read(second_result.mmn_file, String)
        bound = E._cached_resolved_matrices(
            () -> error("REBUILD_FORBIDDEN"),
            path,
            "bound-inputs-v1";
            acceptance_identity = "native-inputs-v1",
        )
        reference = bound.accepted_matrix_reference
        before = read(path)
        restored = E._restore_accepted_matrix_reference(reference, "native-inputs-v1")
        @test restored.mmn.data == resolved.mmn.data
        @test read(path) == before
        @test_throws ArgumentError E._restore_accepted_matrix_reference(reference, "changed-inputs")
        bad = merge(reference, Dict("payload_sha256" => repeat("0", 64)))
        @test_throws ArgumentError E._restore_accepted_matrix_reference(bad, "native-inputs-v1")
        open(file, "a") do io
            write(io, "tampered")
        end
        @test_throws ArgumentError E._cached_resolved_matrices(
            ()->error("MATRIX_REGENERATION_FORBIDDEN"),
            path,
            "bound-inputs-v1",
        )
    end
end
end
