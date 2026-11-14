using WannierNLQG, MPI, LinearAlgebra, JSON3, Test, SHA

BLAS.set_num_threads(1)
MPI.Initialized() || MPI.Init()
include(joinpath(@__DIR__, "support", "FullMPIRankProfile.jl"))
const COMM = MPI.COMM_WORLD
const RANK = MPI.Comm_rank(COMM)
const RANKS = MPI.Comm_size(COMM)
const RUNTIME = WannierNLQG.Runtime
const CORE = WannierNLQG.Core
const OUTPUT_ROOT = abspath(only(ARGS))
RUNTIME.bundle_mpi_initialize()
@test RANKS in FullMPIRankProfile.adaptive_ranks()
@test realpath(dirname(pathof(WannierNLQG))) == joinpath(realpath(dirname(@__DIR__)), "src")

function decode_fixture_array(raw; complex_values = true)
    values =
        complex_values ? ComplexF64[complex(value...) for value in raw.values] :
        Float64.(raw.values)
    return reshape(values, Tuple(Int.(raw.shape)))
end

raw = JSON3.read(
    read(joinpath(@__DIR__, "fixtures", "nonorthogonal_adaptive_mpi_model.json"), String),
).model
model = CORE.NonorthogonalLocalizedModel(
    lattice = decode_fixture_array(raw.lattice_angstrom; complex_values = false),
    r_vectors = Int.(decode_fixture_array(raw.r_vectors; complex_values = false)),
    hamiltonian_r = decode_fixture_array(raw.raw_hamiltonian_r),
    overlap_r = decode_fixture_array(raw.raw_overlap_r),
    position_r = decode_fixture_array(raw.raw_position_r),
    spin_representation = Symbol(raw.spin_representation),
    magnetic_state = Symbol(raw.magnetic_state),
    spin_orbit_coupling = Bool(raw.spin_orbit_coupling),
    spin_ordering = Symbol(raw.spin_ordering),
    orbital_centers_cartesian = decode_fixture_array(
        raw.orbital_centers_cartesian;
        complex_values = false,
    ),
)

function numerical_tables(result)
    tables = Dict{String, Any}()
    for path in result.outputs
        endswith(path, ".dat") || continue
        rows = [
            parse.(Float64, split(line)) for
            line in eachline(path) if !isempty(strip(line)) && !startswith(strip(line), "#")
        ]
        @test !haskey(tables, basename(path))
        @test all(isfinite, (value for row in rows for value in row))
        tables[basename(path)] = rows
    end
    @test !isempty(tables)
    return tables
end

function numerical_diagnostics(directory)
    paths = [
        joinpath(root, file) for (root, _, files) in walkdir(directory) for
        file in files if file == "integration_diagnostics.txt"
    ]
    @test length(paths) == 1
    records = Dict(Pair(split(line, '='; limit = 2)...) for line in eachline(only(paths)))
    # Rank count is execution metadata. All algorithm controls and numerical results compare exactly.
    delete!(records, "execution_parallelism")
    for key in ("embedded_estimate", "evaluations", "termination", "estimate_converged")
        @test haskey(records, key)
    end
    return records
end

payload = Dict{String, Any}()
@testset "Synthetic nonorthogonal public adaptive responses, conventions I/II, dimensions 1/2/3" begin
    for convention in ("Convention_I", "Convention_II"),
        dimension in 1:3,
        quantity in ("SC", "IC", "SHG")

        id = "$(convention)-$(dimension)D-$(quantity)"
        directory = joinpath(OUTPUT_ROOT, id)
        physics =
            quantity == "SHG" ?
            SHGParameters(
                photon_energies = [0.8, 1.5, 2.1],
                fermi_energy = 0.4,
                temperature = 300.0,
                output = :both,
                response = :both,
            ) :
            OpticalParameters(
                photon_energies = [0.8, 1.5, 2.1],
                fermi_energy = 0.4,
                temperature = 300.0,
            )
        numerics =
            quantity == "SHG" ?
            Numerics(denominator_regularization = 0.001, broadening = 0.2, eta_correction = false) :
            Numerics(denominator_regularization = 0.001, broadening = 0.2)
        task = TaskSpec(
            id = lowercase(quantity),
            quantity = quantity,
            method = "Conventional",
            physics = physics,
            numerics = numerics,
            observable = FullTensor(),
        )
        lower = (0.65, 0.3, 0.4)
        upper = (0.95, 0.58, 0.69)
        cfg = TaskConfig(
            model = CORE.NonorthogonalLocalizedInput(model; wannier_center_convention = convention),
            sampling = KRegion(
                lower = lower[1:dimension],
                upper = upper[1:dimension],
                k_mesh = ntuple(_ -> 2, dimension),
            ),
            tasks = [task],
            execution = ExecutionOptions(
                fourier_backend = "direct",
                integration_algorithm = HAdaptiveCubature(
                    atol = 1e-12,
                    rtol = 1e-6,
                    max_evaluations = 2000,
                ),
            ),
            output = OutputOptions(
                output_root = directory,
                progress_enabled = false,
                response_output_digits = 17,
            ),
        )
        result = WannierNLQG.run(cfg)
        if RANK == 0
            payload[id] = Dict(
                "tables" => numerical_tables(result),
                "diagnostics" => numerical_diagnostics(directory),
            )
        end
    end
end

local_nodes = Vector{Vector{Float64}}()
@testset "Analytic SC/IC/THG complete one collective diagnostic finalization" begin
    lattice = 2Matrix{Float64}(I, 3, 3)
    hamiltonian = ComplexF64[-1 0.4; 0.4 1]
    input = AnalyticKInput(
        hamiltonian = (k, p) ->
            hamiltonian +
            k[1] * [0.1 0.3+0.2im; 0.3-0.2im -0.1] +
            k[1]^2 * [0.2 -0.1im; 0.1im -0.2],
        num_orbitals = 2,
        periodic = false,
        lattice = lattice,
        orbital_positions = [0.0 0.3; 0.0 0.2; 0.0 0.1],
        source_file = @__FILE__
    )
    for quantity in ("SC", "IC", "THG")
        directory = joinpath(OUTPUT_ROOT, "analytic-" * lowercase(quantity))
        physics =
            quantity == "THG" ?
            THGParameters(
                photon_energies = [0.8, 1.5],
                fermi_energy = 0.0,
                temperature = 300.0,
                output = :both,
                response = :both,
            ) :
            OpticalParameters(photon_energies = [0.8, 1.5], fermi_energy = 0.0, temperature = 300.0)
        task = TaskSpec(
            id = lowercase(quantity),
            quantity = quantity,
            method = "Conventional",
            physics = physics,
            observable = quantity == "THG" ? TensorComponents(TensorComponent(1, 1, 1, 1)) :
                         FullTensor(),
        )
        config = TaskConfig(
            model = input,
            sampling = KRegion(lower = (0.2,), upper = (0.3,), k_mesh = (1,)),
            tasks = [task],
            execution = ExecutionOptions(
                fourier_backend = "direct",
                integration_algorithm = HAdaptiveCubature(
                    atol = 1e-12,
                    rtol = 1e-6,
                    max_evaluations = 15,
                ),
            ),
            output = OutputOptions(
                output_root = directory,
                progress_enabled = false,
                response_output_digits = 17,
            ),
        )
        if quantity in ("SC", "IC")
            failed_config = TaskConfig(
                model = config.model,
                sampling = config.sampling,
                tasks = config.tasks,
                execution = config.execution,
                output = OutputOptions(
                    output_root = directory * "-failed-output",
                    system_name = "bad/name",
                    progress_enabled = false,
                ),
            )
            failure_message = ""
            failed = try
                WannierNLQG.run(failed_config)
                false
            catch exception
                failure_message = sprint(showerror, exception)
                true
            end
            @test failed
            @test occursin("opening file", failure_message)
            @test occursin("bad/name", failure_message)
            @test RANKS == 1 || occursin("adaptive collective completion failed", failure_message)
            @test MPI.Allreduce(Int(failed), +, COMM) == RANKS
        end
        result = WannierNLQG.run(config)
        if RANK == 0
            diagnostics = [
                joinpath(root, name) for (root, _, files) in walkdir(directory) for
                name in files if name == "native_derivatives.tsv"
            ]
            @test length(diagnostics) == 1
            payload["analytic-" * quantity] = Dict(
                "tables" => numerical_tables(result),
                "diagnostics" => numerical_diagnostics(directory),
            )
        end
    end
end

RANK == 0 && println("ADAPTIVE_FINISH_FAILURE_RECOVERY_COMPLETED")

@testset "Concurrent rule values preserve exact serial fields and collective recovery" begin
    @test_throws (RANKS == 1 ? ArgumentError : ErrorException) RUNTIME.bundle_mpi_collective_call(
        () -> RANK == 0 ? throw(ArgumentError("controlled completion failure")) : RANK;
        enabled = true,
    )
    @test RUNTIME.bundle_mpi_collective_call(() -> RANK; enabled = true) == RANK
    for dimension in 1:3
        domain = RUNTIME.IntegrationDomain{dimension}()
        rule_nodes = (15, 17, 33)[dimension]
        algorithm = HAdaptiveCubature(atol = 0.0, rtol = 1e-12, max_evaluations = rule_nodes + 1)
        evaluator = node -> ComplexF64[exp(3sum(node)) + im * sin(5node[1]), 1e-9 * cos(sum(node))]
        serial = RUNTIME.integrate_response(evaluator, domain, algorithm)
        actual = RUNTIME.integrate_response_mpi(evaluator, domain, algorithm)
        for field in fieldnames(typeof(serial))
            @test getfield(actual, field) == getfield(serial, field)
        end
    end
    domain = RUNTIME.IntegrationDomain{3}()
    algorithm = HAdaptiveCubature(max_evaluations = 33)
    # Complex scalar values need 64 estimated packet bytes. This cap forces several
    # packets within one rule while retaining exactly the reference arithmetic.
    bounded_value = node -> exp(sum(node)) + im*cos(node[1])
    bounded_serial = RUNTIME.integrate_response(bounded_value, domain, algorithm)
    bounded = RUNTIME.integrate_response_mpi(
        bounded_value,
        domain,
        algorithm;
        pending_memory_limit_bytes = 128,
    )
    for field in fieldnames(typeof(bounded_serial))
        @test getfield(bounded, field) == getfield(bounded_serial, field)
    end
    # FFT cache controls do not constrain Direct cubature transport. The same
    # established default1GiB packet cap and explicit pending-memory overrides apply.
    withenv("WANNIERNLQG_MIXED_MEMORY_LIMIT_BYTES" => "1") do
        uncached = RUNTIME.integrate_response_mpi(bounded_value, domain, algorithm)
        for field in fieldnames(typeof(bounded_serial))
            @test getfield(uncached, field) == getfield(bounded_serial, field)
        end
    end
    calls = Ref(0)
    rendezvoused = Ref(false)
    simultaneous = node -> begin
        calls[] += 1
        # The first root-only physical node establishes result storage. During
        # the following rule batch every rank has work and must enter this
        # rendezvous before any can return, proving simultaneous evaluator entry.
        if RANKS > 1 && !(RANK == 0 && calls[] == 1) && !rendezvoused[]
            @test MPI.Allreduce(1, +, COMM) == RANKS
            rendezvoused[] = true
        end
        2.0
    end
    @test RUNTIME.integrate_response_mpi(simultaneous, domain, algorithm).value ≈ 2.0
    @test RANKS == 1 || rendezvoused[]
    RANK == 0 && RANKS > 1 && println("ADAPTIVE_CONCURRENT_RULE_RENDEZVOUS ranks=", RANKS)
    @test_throws (RANKS == 1 ? ArgumentError : ErrorException) RUNTIME.integrate_response_mpi(
        node -> RANK == RANKS - 1 ? NaN : 1.0,
        domain,
        algorithm,
    )
    shape_calls = Ref(0)
    changing_shape =
        node -> begin
            shape_calls[] += 1
            RANKS == 1 ? ones(shape_calls[] == 1 ? 1 : 2) : (RANK == 0 ? [1.0] : [1.0, 2.0])
        end
    @test_throws (RANKS == 1 ? DimensionMismatch : ErrorException) RUNTIME.integrate_response_mpi(
        changing_shape,
        domain,
        algorithm,
    )
    if RANKS > 1
        @test_throws ErrorException RUNTIME.integrate_response_mpi(
            node -> 2.0,
            domain,
            algorithm;
            pending_memory_limit_bytes = 1,
        )
        @test_throws ArgumentError RUNTIME.integrate_response_mpi(
            node -> 2.0,
            domain,
            algorithm;
            pending_memory_limit_bytes = RANK + 1,
        )
    end
    @test RUNTIME.integrate_response_mpi(node -> 2.0, domain, algorithm).value ≈ 2.0
    RANK == 0 && println("ADAPTIVE_RULE_FAILURE_RECOVERY_COMPLETED")
end

# This fixture consumes the unchanged bounded-packet integrator. It observes
# evaluator ownership, not the private per-rank shape reference or whole-rule idleness.
packet_fixture_receipt = Ref{Any}(nothing)
if FullMPIRankProfile.adaptive_packet_fixture()
    @testset "Short scalar/tensor packets retain idle owners and recover collectively" begin
        domain = RUNTIME.IntegrationDomain{3}()
        algorithm = HAdaptiveCubature(max_evaluations = 33)
        serial_nodes = Vector{Vector{Float64}}()
        scalar_value = node -> exp(sum(node)) + im * cos(node[1])
        scalar_serial = RUNTIME.integrate_response(
            node -> (push!(serial_nodes, collect(node)); scalar_value(node)),
            domain,
            algorithm,
        )
        @test length(serial_nodes) == 33
        ordinals = Dict(Tuple(node) => ordinal for (ordinal, node) in enumerate(serial_nodes))
        @test length(ordinals) == 33
        prefix_nodes = min(3, max(1, RANKS - 1))
        scalar_trace = Int[]
        for tensor in (false, true)
            value_at =
                tensor ? (node -> ComplexF64[scalar_value(node) 0; 0 1e-9 * sin(sum(node))]) :
                scalar_value
            sample = value_at(first(serial_nodes))
            bytes_per_value = 4 * Base.summarysize(sample)
            limit = tensor ? 2 * bytes_per_value : 128
            capacity = CORE.ESKernel.WorkspacePlanning.batch_capacity(33, bytes_per_value, 0, limit)
            @test capacity == 2
            # Only this rank's nodes have usable values. Looking up an unowned
            # value is poison; the production ownership branch must skip it.
            owned_values = Dict(
                ordinal => value_at(node) for
                (ordinal, node) in enumerate(serial_nodes) if mod(ordinal - 1, RANKS) == RANK
            )
            trace = Int[]
            evaluator =
                node -> begin
                    ordinal = ordinals[Tuple(node)]
                    haskey(owned_values, ordinal) ||
                        error("unowned packet evaluator was called")
                    push!(trace, ordinal)
                    owned_values[ordinal]
                end
            reference =
                tensor ? RUNTIME.integrate_response(value_at, domain, algorithm) : scalar_serial
            actual = RUNTIME.integrate_response_mpi(
                evaluator,
                domain,
                algorithm;
                pending_memory_limit_bytes = limit,
            )
            @test trace == collect((RANK + 1):RANKS:33)
            @test isempty(filter(ordinal -> ordinal <= prefix_nodes, trace)) ==
                  (RANK >= prefix_nodes)
            for field in fieldnames(typeof(reference))
                @test getfield(actual, field) == getfield(reference, field)
            end
            tensor || append!(scalar_trace, trace)
        end
        # Failure after the root-only first packet reaches the existing terminal
        # broadcast. Every rank must return and reuse this same communicator.
        failure_sequence = min(3, RANKS)
        @test_throws ErrorException RUNTIME.integrate_response_mpi(
            node -> begin
                ordinal = ordinals[Tuple(node)]
                mod(ordinal - 1, RANKS) == RANK ||
                    error("unowned failure evaluator was called")
                ordinal == failure_sequence && error("controlled short-packet owner failure")
                scalar_value(node)
            end,
            domain,
            algorithm;
            pending_memory_limit_bytes = 128,
        )
        recovered = RUNTIME.integrate_response_mpi(
            scalar_value,
            domain,
            algorithm;
            pending_memory_limit_bytes = 128,
        )
        for field in fieldnames(typeof(scalar_serial))
            @test getfield(recovered, field) == getfield(scalar_serial, field)
        end
        packet_fixture_receipt[] = Dict(
            "capacity" => 2,
            "rule_nodes" => 33,
            "local_ordinals" => scalar_trace,
            "prefix_nodes" => prefix_nodes,
            "empty_prefix_owner" => (RANK >= prefix_nodes),
            "scalar_tensor_exact" => true,
            "failure_recovery" => true,
            "internal_shape_state_observed" => false,
        )
        RANK == 0 && println("ADAPTIVE_SHORT_PACKET_EMPTY_OWNERS_PASS ranks=", RANKS)
    end
end

@testset "Round-robin owner distribution and collective error recovery" begin
    domain = RUNTIME.IntegrationDomain(lower = [0.0], upper = [1.0], coordinates = :cartesian)
    algorithm = HAdaptiveCubature(atol = 1e-12, rtol = 1e-6, max_evaluations = 2000)
    serial_nodes = Vector{Vector{Float64}}()
    serial = RUNTIME.integrate_response(
        node -> (push!(serial_nodes, collect(node)); 2.0),
        domain,
        algorithm,
    )
    actual = RUNTIME.integrate_response_mpi(
        node -> (push!(local_nodes, collect(node)); 2.0),
        domain,
        algorithm,
    )
    @test serial.evaluations == 15
    @test local_nodes == serial_nodes[(RANK + 1):RANKS:end]
    for field in fieldnames(typeof(serial))
        @test getfield(actual, field) == getfield(serial, field)
    end
    @test isempty(local_nodes) == (RANK >= min(RANKS, serial.evaluations))
    error_domain =
        RUNTIME.IntegrationDomain(lower = zeros(3), upper = ones(3), coordinates = :cartesian)
    @test_throws ErrorException RUNTIME.integrate_response_mpi(
        node -> (RANK == RANKS-1 ? error("controlled final owner failure") : 1.0),
        error_domain,
        algorithm,
    )
    @test_throws ErrorException RUNTIME.integrate_response_mpi(
        node -> error("controlled root first-node failure; peers own no node"),
        domain,
        algorithm,
    )
    @test RUNTIME.integrate_response_mpi(node -> 2.0, domain, algorithm).value == 2.0
end

write(
    joinpath(OUTPUT_ROOT, "rank-$(RANK).json"),
    JSON3.write(
        Dict(
            "rank" => RANK,
            "ranks" => RANKS,
            "pid" => getpid(),
            "source" => realpath(dirname(@__DIR__)),
            "probe_sha256" => bytes2hex(sha256(read(@__FILE__))),
            "normal_constant_local_nodes" => length(local_nodes),
            "normal_empty_owner_boundary_exercised" => RANKS > 15,
            "mpi_profile" => get(ENV, "WANNIERNLQG_TEST_MPI_PROFILE", "legacy16"),
            "mpi_library_version" => MPI.Get_library_version(),
            "short_packet_fixture" => packet_fixture_receipt[],
        ),
    ),
)
if RANK == 0
    @test length(payload) == 21
    write(joinpath(OUTPUT_ROOT, "numerical.json"), JSON3.write(payload))
    println("NONORTHOGONAL_ADAPTIVE_MPI_PROBE_PASS")
end
MPI.Finalized() || MPI.Finalize()
