import JSON3
using LinearAlgebra
isdefined(@__MODULE__, :ExampleSupport) ||
    include(joinpath(@__DIR__, "..", "examples", "ExampleSupport.jl"))

const PAIRED_PHOTON_TEST_ROOT = Ref{String}("")

# Build a real public finite-q task; no response formula or synthetic result is substituted.
function paired_photon_test_task(
    quantity,
    energies;
    momentum = nothing,
    momenta = nothing,
    width = 0.08,
    temperature = 125.0,
)
    return WannierNLQG.TaskSpec(
        id = "paired_" * lowercase(quantity),
        quantity = quantity,
        method = quantity == "PDSC" ? "Geometric_Loop" : "Conventional",
        physics = WannierNLQG.FiniteQOpticalParameters(;
            photon_energies = energies,
            fermi_energy = 0.1,
            temperature,
            photon_momentum = momentum,
            photon_momenta = momenta,
        ),
        numerics = WannierNLQG.Numerics(broadening = width, denominator_regularization = 0.003),
        observable = WannierNLQG.FullTensor(),
    )
end

# Keep all generated files in the test-private temporary domain.
function paired_photon_test_config(tasks; backend = "direct", sampling = nothing, model = nothing)
    fixture = joinpath(@__DIR__, "..", "examples", "fixtures", "synthetic_runtime")
    return WannierNLQG.TaskConfig(;
        model = model === nothing ?
                WannierNLQG.ModelInput(
            model_file = joinpath(fixture, "synthetic_tb.dat"),
            real_space_operator_bundle_file = joinpath(fixture, "synthetic_operators.h5"),
            real_space_replica_policy = "minimum_distance",
            wsvec_file = joinpath(fixture, "synthetic_wsvec.dat"),
            mp_grid = (2, 1, 1),
        ) : model,
        sampling = sampling === nothing ?
                   WannierNLQG.BZMesh(k_mesh = (3, 2), spatial_dimension = 2) : sampling,
        tasks,
        execution = WannierNLQG.ExecutionOptions(fourier_backend = backend),
        output = WannierNLQG.OutputOptions(
            output_root = mktempdir(PAIRED_PHOTON_TEST_ROOT[]),
            system_name = "paired",
            response_output_digits = 17,
            progress_enabled = false,
        ),
    )
end

# Read all real/imaginary tensor columns at round-trip precision, in original row order.
function paired_photon_test_payload(result)
    path = only(filter(path -> endswith(path, ".dat"), result.outputs))
    rows = [
        parse.(Float64, split(line)) for
        line in eachline(path) if !isempty(strip(line)) && !startswith(strip(line), '#')
    ]
    return permutedims(reduce(hcat, rows))
end

# A closed linear two-band Hamiltonian in one fixed orthonormal basis.
function fixed_basis_photon_hamiltonian(k, parameters)
    return parameters.h0 + k[1] * parameters.dx + k[2] * parameters.dy
end

# Exact Cartesian derivatives of the same declared Hamiltonian, in eV Angstrom.
function fixed_basis_photon_first_derivative(k, parameters)
    derivative = zeros(ComplexF64, 2, 2, 3)
    derivative[:, :, 1] .= parameters.dx
    derivative[:, :, 2] .= parameters.dy
    return derivative
end

# Higher derivatives vanish for the linear closed model.
fixed_basis_photon_second_derivative(k, parameters) = zeros(ComplexF64, 2, 2, 3, 3)
fixed_basis_photon_third_derivative(k, parameters) = zeros(ComplexF64, 2, 2, 3, 3, 3)

# Build the explicit finite-basis payload; there is no real-space TB representation.
function fixed_basis_photon_test_model()
    return WannierNLQG.AnalyticKInput(
        hamiltonian = fixed_basis_photon_hamiltonian,
        derivatives = (
            fixed_basis_photon_first_derivative,
            fixed_basis_photon_second_derivative,
            fixed_basis_photon_third_derivative,
        ),
        num_orbitals = 2,
        lattice = Matrix{Float64}(LinearAlgebra.I, 3, 3),
        basis = :fixed_orthonormal,
        periodic = false,
        derivative_method = :explicit,
        parameters = (
            h0 = ComplexF64[0.65 0.28-0.14im; 0.28+0.14im -0.65],
            dx = ComplexF64[0.11 0.21; 0.21 -0.11],
            dy = ComplexF64[0.17 -0.23im; 0.23im -0.17],
        ),
        source_file = @__FILE__,
    )
end

# Independent scalar PDIC equation in the declared fixed basis, before the physical prefactor.
function fixed_basis_photon_pdic_oracle(model, energy, momentum, width, gamma)
    lower = -0.5 .* collect(momentum)
    upper = 0.5 .* collect(momentum)
    valence = LinearAlgebra.eigen(
        LinearAlgebra.Hermitian(fixed_basis_photon_hamiltonian(lower, model.parameters)),
    )
    conduction = LinearAlgebra.eigen(
        LinearAlgebra.Hermitian(fixed_basis_photon_hamiltonian(upper, model.parameters)),
    )
    derivatives = fixed_basis_photon_first_derivative(lower, model.parameters)
    average = 0.5 .* (derivatives + fixed_basis_photon_first_derivative(upper, model.parameters))
    response = zeros(ComplexF64, 2, 2, 2)
    for n in 1:2, m in 1:2
        difference = Float64(valence.values[n] < 0.1) - Float64(conduction.values[m] < 0.1)
        gap = conduction.values[m] - valence.values[n]
        delta = exp(-((gap - energy) / width)^2) / (sqrt(pi) * width)
        weight = difference * delta * (gap / (gap^2 + gamma^2))^2
        for a in 1:2, b in 1:2, c in 1:2
            velocity_difference = real(
                conduction.vectors[:, m]' * derivatives[:, :, a] * conduction.vectors[:, m] -
                valence.vectors[:, n]' * derivatives[:, :, a] * valence.vectors[:, n],
            )
            forward = valence.vectors[:, n]' * average[:, :, c] * conduction.vectors[:, m]
            backward = conduction.vectors[:, m]' * average[:, :, b] * valence.vectors[:, n]
            response[a, b, c] += weight * velocity_difference * forward * backward
        end
    end
    return response
end

ExampleSupport.with_synthetic_operator_bundle() do
    mktempdir() do test_root
        PAIRED_PHOTON_TEST_ROOT[] = test_root

        @testset "photon-drag transition gap weight and explicit fixed basis" begin
            responses = WannierNLQG.Responses
            for gap in (-0.7, -0.02, 0.0, 0.02, 0.7), gamma in (0.001, 0.04)
                expected = (gap / (gap^2 + gamma^2))^2
                @test isapprox(
                    responses.photon_drag_transition_denominator_weight(gap, gamma),
                    expected;
                    atol = 1e-12,
                    rtol = 1e-12,
                )
            end
            @test_throws DomainError responses.photon_drag_transition_denominator_weight(0.0, 0.0)
            @test_throws ArgumentError responses.photon_drag_transition_denominator_weight(
                0.1,
                -0.1,
            )
            @test_throws ArgumentError responses.photon_drag_transition_denominator_weight(
                NaN,
                0.01,
            )
            occupations = [0.0 1.0; -1.0 0.0]
            gaps = [0.0 0.5; -0.5 0.0]
            weighted = zeros(2, 2)
            responses.photon_drag_weighted_occupations!(weighted, occupations, gaps, 0.0)
            @test weighted == occupations .* [0.0 4.0; 4.0 0.0]
            @test occupations == [0.0 1.0; -1.0 0.0]
            @test responses.photon_drag_band_windows([-0.5, 0.5], [-0.4, 0.6], 2.0, -1, 2) ==
                  (1, 2, 1, 2, true)
            @test_throws ArgumentError responses.photon_drag_band_windows(
                [-0.5, 0.5],
                [-0.4, 0.6],
                0.0,
                1,
                2,
            )
            @test_throws DimensionMismatch responses.photon_drag_band_windows(
                [-0.5, 0.5],
                [-0.4],
                0.0,
                -1,
                2,
            )
            model = fixed_basis_photon_test_model()
            @test model.orbital_positions === nothing
            @test model.basis == :fixed_orthonormal
            @test WannierNLQG.Core.AnalyticKModel(model).num_r_vectors == 0
            @test all(iszero, WannierNLQG.MatrixElements.analytic_position(model, [0.1, 0.2, 0.0]))
            @test_throws ArgumentError WannierNLQG.AnalyticKInput(
                hamiltonian = fixed_basis_photon_hamiltonian,
                num_orbitals = 2,
                lattice = model.lattice,
                basis = :fixed_orthonormal,
                orbital_positions = zeros(3, 2),
            )
            @test_throws ArgumentError WannierNLQG.AnalyticKInput(
                hamiltonian = fixed_basis_photon_hamiltonian,
                num_orbitals = 2,
                lattice = model.lattice,
                basis = :fixed_orthonormal,
                wannier_center_convention = "Convention_I",
            )
        end

        @testset "fixed-basis photon-drag oracle and paired region exact rows" begin
            model = fixed_basis_photon_test_model()
            region =
                WannierNLQG.KRegion(lower = (-0.02, -0.02), upper = (0.02, 0.02), k_mesh = (1, 1))
            q = (0.0, 0.03, 0.0)
            lower = -0.5 .* collect(q)
            upper = 0.5 .* collect(q)
            gap =
                maximum(
                    LinearAlgebra.eigvals(
                        LinearAlgebra.Hermitian(
                            fixed_basis_photon_hamiltonian(upper, model.parameters),
                        ),
                    ),
                ) - minimum(
                    LinearAlgebra.eigvals(
                        LinearAlgebra.Hermitian(
                            fixed_basis_photon_hamiltonian(lower, model.parameters),
                        ),
                    ),
                )
            energies = [gap - 0.02, gap, gap - 0.02]
            momenta = [q, q, q]
            for quantity in ("PDIC", "PDSC")
                task = paired_photon_test_task(
                    quantity,
                    energies;
                    momenta,
                    width = 0.08,
                    temperature = 0.0,
                )
                configuration = paired_photon_test_config([task]; model, sampling = region)
                result = WannierNLQG.run(configuration)
                payload = paired_photon_test_payload(result)
                evidence_root = get(ENV, "WANNIERNLQG_TRANSITION_EVIDENCE_DIR", "")
                if !isempty(evidence_root)
                    mkpath(evidence_root)
                    for path in result.outputs
                        cp(
                            path,
                            joinpath(
                                evidence_root,
                                lowercase(quantity) * "_paired_" * basename(path),
                            );
                            force = true,
                        )
                    end
                    cp(
                        only(result.task_results).metadata_path,
                        joinpath(evidence_root, lowercase(quantity) * "_paired_metadata.txt");
                        force = true,
                    )
                end
                @test size(payload, 1) == length(energies)
                @test all(isfinite, payload)
                task_metadata = only(result.task_results).metadata_path
                metadata_text = read(task_metadata, String)
                @test occursin("[DeltaE/(DeltaE^2+gamma^2)]^2", metadata_text)
                @test occursin("producer_source_manifest_sha256_declared", metadata_text)
                @test occursin(
                    WannierNLQG.IO.sha256_file(joinpath(dirname(@__DIR__), "SOURCE_MANIFEST.tsv")),
                    metadata_text,
                )
                @test occursin(
                    WannierNLQG.IO.sha256_file(
                        joinpath(
                            dirname(@__DIR__),
                            "src",
                            "MatrixElements",
                            "OpticalMomentumOverlap.jl",
                        ),
                    ),
                    metadata_text,
                )
                for index in eachindex(energies)
                    reference = WannierNLQG.run(
                        paired_photon_test_config(
                            [
                                paired_photon_test_task(
                                    quantity,
                                    [energies[index]];
                                    momentum = q,
                                    width = 0.08,
                                    temperature = 0.0,
                                ),
                            ];
                            model,
                            sampling = region,
                        ),
                    )
                    @test payload[index, 2:end] == paired_photon_test_payload(reference)[1, 2:end]
                    if !isempty(evidence_root)
                        path = only(filter(path -> endswith(path, ".dat"), reference.outputs))
                        cp(
                            path,
                            joinpath(evidence_root, lowercase(quantity) * "_single_$(index).dat");
                            force = true,
                        )
                    end
                end
                if quantity == "PDIC"
                    # Compare the physical rate after removing the existing KRegion prefactor.
                    prefactor =
                        -pi * WannierNLQG.Core.ELEMENTARY_CHARGE_C /
                        WannierNLQG.Core.REDUCED_PLANCK_CONSTANT_EV_S^2
                    measure = 0.04^2 / (2pi)^2 * 1e-10
                    expected = fixed_basis_photon_pdic_oracle(model, energies[2], q, 0.08, 0.003)
                    actual = permutedims(
                        reshape(complex.(payload[2, 3:2:end], payload[2, 4:2:end]), 2, 2, 2),
                        (3, 2, 1),
                    )
                    if !isempty(evidence_root)
                        open(
                            joinpath(evidence_root, "pdic_independent_scalar_oracle.json"),
                            "w",
                        ) do stream
                            JSON3.write(
                                stream,
                                Dict(
                                    "formula" => "full fixed-basis average velocity; transition-gap-only W",
                                    "source" => "independent scalar two-band equation",
                                    "energy_ev" => energies[2],
                                    "q_A_inverse" => collect(q),
                                    "prefactor" => prefactor,
                                    "domain_measure" => measure,
                                    "expected_real" => vec(real.(expected)),
                                    "expected_imag" => vec(imag.(expected)),
                                    "actual_normalized_real" =>
                                        vec(real.(actual / (prefactor * measure))),
                                    "actual_normalized_imag" =>
                                        vec(imag.(actual / (prefactor * measure))),
                                    "array_order" => "Julia a-fastest; shape2x2x2",
                                    "max_abs" =>
                                        maximum(abs, actual / (prefactor * measure) - expected),
                                ),
                            )
                        end
                    end
                    @test maximum(abs, expected) > 0
                    @test isapprox(
                        actual / (prefactor * measure),
                        expected;
                        atol = 1e-10,
                        rtol = 1e-8,
                    )
                end
            end
        end

        @testset "paired photon momentum input contract and ownership" begin
            runtime = WannierNLQG.Runtime
            constructor = WannierNLQG.FiniteQOpticalParameters
            energies = [0.3, 0.7, 0.3, 1.0]
            momenta = [[0.04, 0.02, 0.0], [-0.04, -0.02, -0.0], [0.04, 0.02, 0.0], [0.0, 0.0, 0.0]]
            parameters = constructor(
                photon_energies = energies,
                photon_momenta = momenta,
                fermi_energy = 0.1,
                temperature = 125.0,
            )
            energies[1] = 9.0
            momenta[1][1] = 9.0
            @test parameters.photon_energies[1] == 0.3
            @test parameters.photon_momenta[1] == (0.04, 0.02, 0.0)
            path = runtime.make_photon_momentum_path(
                parameters.photon_energies,
                parameters.photon_momenta,
            )
            @test [group.row_indices for group in path.groups] == [[1, 3], [2], [4]]
            parameters.photon_momenta[1] = (1.0, 1.0, 1.0)
            @test path.photon_momenta[1] == (0.04, 0.02, 0.0)
            zero_path =
                runtime.make_photon_momentum_path([0.3, 0.3], [(0.0, 0.0, 0.0), (-0.0, 0.0, 0.0)])
            @test length(zero_path.groups) == 2
            @test signbit(zero_path.photon_momenta[2][1])
            @test length(
                runtime.make_photon_momentum_path(
                    [0.3, 0.3],
                    [(0.04, 0.02, 0.0), (nextfloat(0.04), 0.02, 0.0)],
                ).groups,
            ) == 2
            for invalid in (
                [],
                [(0.0, 0.0, 0.0)],
                [(true, 0, 0), (0, 0, 0)],
                [(NaN, 0, 0), (0, 0, 0)],
                [(Inf, 0, 0), (0, 0, 0)],
                [[0, 0], [0, 0, 0]],
            )
                @test_throws ArgumentError constructor(
                    photon_energies = [0.3, 0.7],
                    photon_momenta = invalid,
                    fermi_energy = 0.0,
                    temperature = 0.0,
                )
            end
            @test_throws ArgumentError constructor(
                photon_energies = [true],
                photon_momentum = (0, 0, 0),
                fermi_energy = 0.0,
                temperature = 0.0,
            )
            @test_throws ArgumentError constructor(
                photon_energies = [0.3],
                photon_momentum = (0, 0, 0),
                photon_momenta = [(0, 0, 0)],
                fermi_energy = 0.0,
                temperature = 0.0,
            )
            @test_throws ArgumentError constructor(
                photon_energies = [0.3],
                fermi_energy = 0.0,
                temperature = 0.0,
            )
            task =
                paired_photon_test_task("PDIC", [0.3, 0.7]; momenta = [(0, 0, 0), (0.04, 0.02, 0)])
            for backend in ("mixed", "auto")
                @test_throws ArgumentError runtime.compile_task_configs(
                    paired_photon_test_config([task]; backend),
                )
            end
            slice = WannierNLQG.KSlice(
                k_mesh = (2, 2),
                spatial_dimension = 2,
                origin = (0, 0, 0),
                vector_1 = (1, 0, 0),
                vector_2 = (0, 1, 0),
            )
            slice_task = WannierNLQG.TaskSpec(
                id = "paired_slice",
                quantity = "PDICK",
                method = "Conventional",
                physics = task.physics,
                observable = WannierNLQG.KSliceSelection(
                    component = WannierNLQG.TensorComponent(1, 1, 1),
                    bands = WannierNLQG.BandSelection(),
                ),
            )
            @test_throws ArgumentError runtime.compile_task_configs(
                paired_photon_test_config([slice_task]; sampling = slice),
            )
        end

        @testset "paired public response exact rows, fixed q and bounded reuse" begin
            energies = [0.3, 1.0, 0.3, 0.7, 1.0, 0.5, 0.3]
            q = (0.04, 0.02, 0.0)
            momenta = [q, (-q[1], -q[2], -0.0), q, (0.0, 0.0, 0.0), (0.0, 0.03, 0.0), q, q]
            for quantity in ("PDIC", "PDSC")
                paired_task = paired_photon_test_task(quantity, energies; momenta)
                paired = WannierNLQG.run(paired_photon_test_config([paired_task]))
                payload = paired_photon_test_payload(paired)
                @test size(payload, 1) == length(energies)
                for index in eachindex(energies)
                    reference = WannierNLQG.run(
                        paired_photon_test_config([
                            paired_photon_test_task(
                                quantity,
                                [energies[index]];
                                momentum = momenta[index],
                            ),
                        ]),
                    )
                    @test isequal(payload[index, :], vec(paired_photon_test_payload(reference)))
                end
                record_path = only(
                    filter(path -> endswith(path, ".photon_momentum_path.toml"), paired.outputs),
                )
                record = WannierNLQG.IO.read_photon_momentum_path_record(record_path)
                @test [row["row_index"] for row in record["rows"]] == collect(eachindex(energies))
                @test [row["photon_energy_ev"] for row in record["rows"]] == energies
                @test isequal(
                    [Tuple(row["photon_momentum_A_inverse"]) for row in record["rows"]],
                    momenta,
                )
                fixed = WannierNLQG.run(
                    paired_photon_test_config([
                        paired_photon_test_task(quantity, energies; momentum = q),
                    ]),
                )
                repeated = WannierNLQG.run(
                    paired_photon_test_config([
                        paired_photon_test_task(
                            quantity,
                            energies;
                            momenta = fill(q, length(energies)),
                        ),
                    ]),
                )
                @test isequal(
                    paired_photon_test_payload(fixed),
                    paired_photon_test_payload(repeated),
                )
                @test !any(path -> endswith(path, ".photon_momentum_path.toml"), fixed.outputs)
                for (block_size, bytes) in ((1, 0), (2, 4096), (3, 16384))
                    variant = withenv(
                        "WANNIERNLQG_PHOTON_PATH_BLOCK_SIZE" => string(block_size),
                        "WANNIERNLQG_PHOTON_PATH_CACHE_BYTES" => string(bytes),
                    ) do
                        WannierNLQG.run(paired_photon_test_config([paired_task]))
                    end
                    @test isequal(payload, paired_photon_test_payload(variant))
                    @test all(
                        stat -> stat.peak_retained_bytes <= bytes && stat.peak_entries <= 128,
                        variant.sharing.worker_statistics,
                    )
                end
            end
        end

        @testset "paired TOML axis and effective replay" begin
            mktempdir() do directory
                fixture = joinpath(
                    @__DIR__,
                    "..",
                    "examples",
                    "fixtures",
                    "synthetic_runtime",
                    "synthetic_tb.dat",
                )
                momenta = [[0.04, 0.02, 0.0], [-0.04, -0.02, -0.0], [0.04, 0.02, 0.0]]
                document = Dict{String, Any}(
                    "model" => Dict("source" => "wannier", "model_file" => fixture),
                    "response" => Dict{String, Any}(
                        "energy_zero" => "synthetic model Hamiltonian reference",
                        "photon_energies_ev" => [0.3, 1.0, 0.3],
                        "photon_momenta_A_inverse" => momenta,
                        "fermi_energy_ev" => 0.1,
                        "temperature_k" => 125.0,
                        "sampling" => Dict(
                            "kind" => "bz_mesh",
                            "k_mesh" => [1, 1],
                            "spatial_dimension" => 2,
                        ),
                        "execution" => Dict("fourier_backend" => "direct"),
                        "tasks" => Dict{String, Any}(
                            "paired" => Dict("kind" => "photon_drag_injection_current"),
                        ),
                    ),
                    "output" => Dict(
                        "output_root" => joinpath(directory, "results"),
                        "progress_enabled" => false,
                    ),
                )
                input_path = joinpath(directory, "input.toml")
                WannierNLQG.IO.write_task_input_file(input_path, document)
                input = WannierNLQG.Runtime.read_task_input(input_path)
                @test input.config !== nothing
                @test isequal(input.config.tasks[1].physics.photon_momenta, Tuple.(momenta))
                @test input.config.tasks[1].physics.photon_momentum === nothing
                @test only(input.summaries).physics.momentum_pairing == "zip"
                records = joinpath(directory, "records")
                WannierNLQG.Runtime.write_task_input_resolution(input, records)
                replay =
                    WannierNLQG.Runtime.read_task_input(joinpath(records, "effective_config.toml"))
                @test isequal(only(input.summaries).physics, only(replay.summaries).physics)
                @test input.provenance["response.tasks.paired.photon_momenta_A_inverse"]["source"] ==
                      "USER"
                for change in ("both", "unequal", "Boolean", "wrong dimension")
                    invalid = deepcopy(document)
                    response = invalid["response"]
                    if change == "both"
                        response["photon_momentum_A_inverse"] = [0.0, 0.0, 0.0]
                    elseif change == "unequal"
                        pop!(response["photon_momenta_A_inverse"])
                    elseif change == "Boolean"
                        # Preserve Bool in the test input; a Float64 array would coerce it before parsing.
                        response["photon_momenta_A_inverse"] =
                            Any[Any[true, 0.0, 0.0], deepcopy(momenta[2]), deepcopy(momenta[3])]
                    else
                        response["photon_momenta_A_inverse"][1] = [0.0, 0.0]
                    end
                    @test_throws ArgumentError WannierNLQG.Runtime.resolve_task_input(invalid)
                    @test !isdir(joinpath(directory, "results"))
                end
            end
        end

        @testset "paired 3D native source ownership and final short block" begin
            lattice = [3.0 0.0 0.0; 0.0 3.0 0.0; 0.0 0.0 3.0]
            vectors = [0 1 -1 0 0 0 0; 0 0 0 1 -1 0 0; 0 0 0 0 0 1 -1]
            hamiltonian = zeros(ComplexF64, 4, 4, 7)
            for orbital in 1:4
                hamiltonian[orbital, orbital, 1] = (-1.4, -0.8, 0.9, 1.6)[orbital]
            end
            for replica in (2, 4, 6)
                for first in 1:4, second in 1:4
                    hamiltonian[first, second, replica] =
                        0.01 * (first + second + replica) + 0.004im * (first - second + replica)
                end
                hamiltonian[:, :, replica + 1] .= hamiltonian[:, :, replica]'
            end
            native = WannierNLQG.RealSpaceTBInput(
                lattice = lattice,
                r_vectors = vectors,
                hamiltonian_r = hamiltonian,
                orbital_positions = [0.0 0.2 0.4 0.6; 0.0 0.1 0.2 0.3; 0.0 0.15 0.3 0.45],
                position_model = :point_orbitals,
            )
            owned = WannierNLQG.Runtime.freeze_paired_runtime_sources((; model = native.model))
            original = copy(owned.model.hamiltonian_r)
            native.model.hamiltonian_r[1, 1, 1] += 0.125
            @test isequal(owned.model.hamiltonian_r, original)
            native.model.hamiltonian_r[1, 1, 1] -= 0.125
            mesh = WannierNLQG.BZMesh(k_mesh = (2, 1, 1), spatial_dimension = 3)
            energies = [0.3, 1.0, 2.5]
            q = (0.04, 0.02, 0.01)
            momenta = [q, (-0.04, -0.02, -0.01), (0.0, 0.0, 0.0)]
            for quantity in ("PDIC", "PDSC")
                paired = WannierNLQG.run(
                    paired_photon_test_config(
                        [paired_photon_test_task(quantity, energies; momenta)];
                        model = native,
                        sampling = mesh,
                    ),
                )
                values = paired_photon_test_payload(paired)
                @test size(values, 2) == 56
                for index in eachindex(energies)
                    single = WannierNLQG.run(
                        paired_photon_test_config(
                            [
                                paired_photon_test_task(
                                    quantity,
                                    [energies[index]];
                                    momentum = momenta[index],
                                ),
                            ];
                            model = native,
                            sampling = mesh,
                        ),
                    )
                    @test isequal(values[index, :], vec(paired_photon_test_payload(single)))
                end
                axis = repeat(energies, 22) # 66 rows: two full blocks and an actual short tail.
                fixed = WannierNLQG.run(
                    paired_photon_test_config(
                        [paired_photon_test_task(quantity, axis; momentum = q)];
                        model = native,
                        sampling = mesh,
                    ),
                )
                blocked = WannierNLQG.run(
                    paired_photon_test_config(
                        [paired_photon_test_task(quantity, axis; momenta = fill(q, length(axis)))];
                        model = native,
                        sampling = mesh,
                    ),
                )
                @test isequal(
                    paired_photon_test_payload(fixed),
                    paired_photon_test_payload(blocked),
                )
                @test all(
                    stat -> stat.max_entries == 128 && stat.max_bytes == 16 * 1024^2,
                    blocked.sharing.worker_statistics,
                )
                evicted = withenv("WANNIERNLQG_PHOTON_PATH_CACHE_BYTES" => "8192") do
                    WannierNLQG.run(
                        paired_photon_test_config(
                            [
                                paired_photon_test_task(
                                    quantity,
                                    axis;
                                    momenta = fill(q, length(axis)),
                                ),
                            ];
                            model = native,
                            sampling = mesh,
                        ),
                    )
                end
                @test isequal(
                    paired_photon_test_payload(blocked),
                    paired_photon_test_payload(evicted),
                )
                @test all(
                    stat -> stat.peak_retained_bytes <= 8192,
                    evicted.sharing.worker_statistics,
                )
                @test sum(stat -> stat.evictions, evicted.sharing.worker_statistics) > 0
            end
            tasks = [
                paired_photon_test_task(quantity, energies; momenta) for
                quantity in ("PDIC", "PDSC")
            ]
            combined =
                WannierNLQG.run(paired_photon_test_config(tasks; model = native, sampling = mesh))
            @test length(combined.task_results) == 2
            for (task, result) in zip(tasks, combined.task_results)
                separate = WannierNLQG.run(
                    paired_photon_test_config([task]; model = native, sampling = mesh),
                )
                @test isequal(
                    paired_photon_test_payload(result),
                    paired_photon_test_payload(separate),
                )
            end
        end

        @testset "representative paired public workload input" begin
            mktempdir(PAIRED_PHOTON_TEST_ROOT[]) do directory
                input_path = WannierNLQG._first_use_paired_photon_input(directory)
                result = WannierNLQG.run_task_input(
                    WannierNLQG.read_task_input(input_path);
                    record_directory = joinpath(directory, "records"),
                )
                paths = filter(path -> endswith(path, ".photon_momentum_path.toml"), result.outputs)
                @test length(paths) == 2
                for path in paths
                    rows = WannierNLQG.IO.read_photon_momentum_path_record(path)["rows"]
                    @test length(rows) == 4
                    @test signbit(rows[2]["photon_momentum_A_inverse"][3])
                end
            end
        end

        @testset "representative paired operator source closures" begin
            mktempdir(PAIRED_PHOTON_TEST_ROOT[]) do directory
                configurations = WannierNLQG._first_use_operator_configs(directory)
                for config in (configurations.paired_injection, configurations.paired_shift)
                    result = WannierNLQG.run(config)
                    @test length(result.task_results) == 1
                    path = only(
                        filter(
                            path -> endswith(path, ".photon_momentum_path.toml"),
                            result.outputs,
                        ),
                    )
                    rows = WannierNLQG.IO.read_photon_momentum_path_record(path)["rows"]
                    @test length(rows) == 4
                    @test signbit(rows[2]["photon_momentum_A_inverse"][3])
                end
            end
        end
    end # The test-private parent removes every generated response and temporary record.
end # Explicit private receipt for the declared immutable miniature bundle.

# A four-band strict-degeneracy oracle with a nonzero intrablock current.
# The expected trace is assembled independently from the declared source matrices.
function strict_degenerate_photon_current_test(rotation)
    elements = WannierNLQG.MatrixElements
    responses = WannierNLQG.Responses
    count = 4
    plan = elements.compile_matrix_plan(
        elements.MatrixElementRequest(
            elements.SPECTRUM,
            elements.HAMILTONIAN_DERIVATIVES,
            elements.VELOCITY_VERTICES;
            spatial_dimension = 2,
        ),
    )
    valence = elements.KPointMatrixData(count, 1, plan)
    conduction = elements.KPointMatrixData(count, 1, plan)
    derivatives = zeros(ComplexF64, count, count, 2)
    derivatives[1, 2, 1]=derivatives[2, 1, 1]=1
    optical = ComplexF64[1 0; 1 1]
    derivatives[1:2, 3:4, 2] .= optical
    derivatives[3:4, 1:2, 2] .= optical'
    for data in (valence, conduction)
        data.spectrum.energies .= [-0.5, -0.5, 0.5, 0.5]
        data.spectrum.source_eigenvectors .= rotation
        data.spectrum.source_eigenvectors_adjoint .= rotation'
        for axis in 1:2
            data.source_gauge_hamiltonian_derivatives[:, :, axis] .=
                rotation'*derivatives[:, :, axis]*rotation
            data.source_gauge_velocity_vertices[:, :, axis] .=
                data.source_gauge_hamiltonian_derivatives[:, :, axis]
        end
    end
    mask=falses(count, count);
    mask[1:2, 3:4].=true
    active=[(n, m) for n in 1:2 for m in 3:4]
    kernel=zeros(ComplexF64, count, count, 2, 2, 2)
    forward=zeros(ComplexF64, count, count, 2);
    backward=similar(forward)
    overlap1=zeros(ComplexF64, count, count);
    overlap2=similar(overlap1)
    responses.compute_photon_drag_injection_current_kernel!(
        kernel,
        forward,
        backward,
        overlap1,
        overlap2,
        valence,
        conduction,
        zeros(3),
        zeros(3),
        zeros(3, count),
        false,
        1,
        count,
        1,
        count,
        count,
        2;
        active_pair_mask = mask,
        active_pairs_nmajor = active,
        active_pair_count = length(active),
        valence_velocity_vertices = valence.source_gauge_hamiltonian_derivatives,
        conduction_velocity_vertices = conduction.source_gauge_hamiltonian_derivatives,
    )
    original=sum(@view kernel[1:2, 3:4, 1, 2, 2])
    responses.complete_photon_drag_injection_degenerate_blocks!(
        kernel,
        forward,
        backward,
        overlap1,
        overlap2,
        valence,
        conduction,
        valence.source_gauge_hamiltonian_derivatives,
        conduction.source_gauge_hamiltonian_derivatives,
        count,
        2;
        active_pair_mask = mask,
    )
    actual=[sum(@view kernel[1:2, 3:4, a, b, c]) for a in 1:2, b in 1:2, c in 1:2]
    expected=zeros(ComplexF64, 2, 2, 2)
    for a in 1:2, b in 1:2, c in 1:2
        forward=derivatives[1:2, 3:4, c];
        backward=derivatives[3:4, 1:2, b]
        expected[
            a,
            b,
            c,
        ]=tr(
            derivatives[3:4, 3:4, a]*backward*forward,
        )-tr(derivatives[1:2, 1:2, a]*forward*backward)
    end
    return (; original, actual, expected)
end

@testset "strict-degenerate photon-drag full-current trace and gap boundary" begin
    identity=Matrix{ComplexF64}(I, 4, 4)
    unrotated=strict_degenerate_photon_current_test(identity)
    @test unrotated.original==0
    @test unrotated.expected[1, 2, 2]==-2
    @test isapprox(unrotated.actual, unrotated.expected; atol = 1e-10, rtol = 1e-8)
    for angle in (0.13, 0.71, 1.02)
        rotation=copy(identity)
        rotation[1:2, 1:2] .= [cos(angle) sin(angle); -sin(angle) cos(angle)]
        rotation[3:4, 3:4] .= [cos(2angle) im*sin(2angle); im*sin(2angle) cos(2angle)]
        rotated=strict_degenerate_photon_current_test(rotation)
        @test isapprox(rotated.actual, unrotated.expected; atol = 1e-10, rtol = 1e-8)
    end
    for tolerance in (1e-12, 1e-10, 1e-8)
        @test WannierNLQG.MatrixElements.spectral_subspace_blocks(
            [-0.5, -0.5, 0.5, 0.5];
            gap_tolerance = tolerance,
        )==[1:2, 3:4]
        @test WannierNLQG.MatrixElements.spectral_subspace_blocks(
            [-0.5, -0.5+2tolerance, 0.5, 0.5+2tolerance];
            gap_tolerance = tolerance,
        )==[1:1, 2:2, 3:3, 4:4]
        @test_throws ErrorException WannierNLQG.MatrixElements.spectral_subspace_blocks(
            [-0.5, -0.5+0.5tolerance, 0.5, 0.5];
            gap_tolerance = tolerance,
        )
    end
    @testset "Paired tensor publication replaces content certificates" begin
        io_layer = WannierNLQG.IO
        mktempdir() do directory
            tensor = joinpath(directory, "response.dat")
            original = "# declared columns\n1.0 3.0000000e-01 5.0000000e-01\n"
            write(tensor, original)
            record_path =
                io_layer.write_photon_momentum_path_record(tensor, [0.3], [(0.1, -0.0, 0.0)])
            record = io_layer.read_photon_momentum_path_record(record_path)
            @test record["schema"] == "wanniernlqg.photon-momentum-path/2.0"
            @test !haskey(record, "response_sha256")
            @test isequal(Tuple(record["rows"][1]["photon_momentum_A_inverse"]), (0.1, -0.0, 0.0))
            @test_throws ArgumentError io_layer.write_photon_momentum_path_record(
                tensor,
                [0.3],
                [(0.1, -0.0, 0.0)],
            )
            changed = deepcopy(record)
            changed["rows"][1]["photon_energy_ev"] = 0.4
            io_layer.write_task_input_file(record_path, changed)
            @test_throws ArgumentError io_layer.read_photon_momentum_path_record(record_path)
            legacy = deepcopy(record)
            legacy["schema"] = "wanniernlqg.photon-momentum-path/1.0"
            io_layer.write_task_input_file(record_path, legacy)
            @test_throws ArgumentError io_layer.read_photon_momentum_path_record(record_path)
            malformed = deepcopy(record)
            malformed["response_publication"]["bytes"] = true
            io_layer.write_task_input_file(record_path, malformed)
            @test_throws ArgumentError io_layer.read_photon_momentum_path_record(record_path)
            io_layer.write_task_input_file(record_path, record)
            write(tensor, replace(original, "5.0000000e-01" => "6.0000000e-01"))
            @test sizeof(read(tensor, String)) == sizeof(original)
            @test_throws ArgumentError io_layer.read_photon_momentum_path_record(record_path)
            # A copied publication has a new lifetime and needs a new declaration.
            adopted = joinpath(directory, "adopted.dat")
            write(adopted, original)
            new_record =
                io_layer.write_photon_momentum_path_record(adopted, [0.3], [(0.1, -0.0, 0.0)])
            @test io_layer.read_photon_momentum_path_record(new_record)["rows"] == record["rows"]
        end
    end
end
