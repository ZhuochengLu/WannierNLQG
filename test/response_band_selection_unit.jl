module ResponseBandSelectionTests

using Test, LinearAlgebra, Random, WannierNLQG
const R = WannierNLQG.Runtime
const C = WannierNLQG.Core
const RESULTS = NamedTuple[]
include(joinpath(@__DIR__, "TestCountCompatibilitySupport.jl"))
const PHASE = get(ENV, "WANNIERNLQG_SELECTION_TEST_PHASE", "all")
PHASE in ("contract", "public", "boundaries", "helpers", "all") ||
    error("Unknown band-selection test phase")

# Record the original Test counters, including nested tests, after a case finishes.
function case!(f, label)
    result = @testset "$label" begin
        f()
    end
    counts = test_result_totals(result)
    push!(
        RESULTS,
        (; label, passed = counts.passed, failed = counts.failed, errored = counts.errored),
    )
    flush(stdout)
end

# A noncentrosymmetric four-state model with paired orbital centers and physical spin.
function model_input(; degenerate = false)
    rng = MersenneTwister(971)
    lattice = 3.0Matrix{Float64}(I, 3, 3)
    rv = [0 1 -1 0 0 0 0; 0 0 0 1 -1 0 0; 0 0 0 0 0 1 -1]
    h = zeros(ComplexF64, 4, 4, 7)
    h[:, :, 1] = Diagonal(degenerate ? [-1.0, -1.0, 1.0, 1.0] : [-1.4, -0.8, 0.9, 1.6])
    for j in (2, 4, 6)
        h[:, :, j] .= 0.08randn(rng, ComplexF64, 4, 4)
        h[:, :, j + 1] .= h[:, :, j]'
        if degenerate
            # Vanishing hopping value at Gamma retains nonzero first derivatives.
            h[:, :, 1] .-= h[:, :, j] + h[:, :, j + 1]
        end
    end
    centers = repeat(rand(rng, 3, 2) .* 0.4; inner = (1, 2))
    spin = zeros(ComplexF64, 4, 4, 3)
    spin[:, :, 1] = [0 1 0 0; 1 0 0 0; 0 0 0 1; 0 0 1 0]
    spin[:, :, 2] = [0 -im 0 0; im 0 0 0; 0 0 0 -im; 0 0 im 0]
    spin[:, :, 3] = Diagonal([1, -1, 1, -1])
    return RealSpaceTBInput(;
        lattice,
        r_vectors = rv,
        hamiltonian_r = h,
        orbital_positions = centers,
        position_model = :point_orbitals,
        operators = (spin = spin,),
    )
end

# Keep the public task's physical controls identical between integral and slice.
function task(id, quantity, method, slice; groups = nothing, window = -1)
    component = quantity in ("ISC", "SSC") ? (1, 3, 1, 2) : (1, 1, 2)
    bands = BandSelection(; groups)
    return TaskSpec(;
        id,
        quantity = slice ? quantity * "K" : quantity,
        method,
        physics = OpticalParameters(
            photon_energies = [2.4],
            fermi_energy = 0.0,
            temperature = 100.0,
        ),
        numerics = Numerics(
            broadening = 0.08,
            broadening_type = "Gaussian",
            band_window_size = window,
        ),
        observable = slice ?
                     KSliceSelection(component = TensorComponent(component...), bands = bands) :
                     FullTensor(; bands),
    )
end

# Use identical half-open fractional points; only the consumer and tensor layout differ.
function configuration(model, tasks, slice; mesh = 2, progress_enabled = false)
    sampling =
        slice ?
        KSlice(
            k_mesh = (mesh, mesh),
            spatial_dimension = 3,
            origin = (0.0, 0.0, 0.0),
            vector_1 = (1.0, 0.0, 0.0),
            vector_2 = (0.0, 1.0, 0.0),
        ) : BZMesh(k_mesh = (mesh, mesh, 1), spatial_dimension = 3)
    return TaskConfig(;
        model,
        sampling,
        tasks,
        execution = ExecutionOptions(fourier_backend = "direct"),
        output = OutputOptions(
            output_root = mktempdir(),
            progress_enabled = progress_enabled,
            response_output_digits = 17,
        ),
    )
end

# Measure the concrete shared screen call after compilation, excluding setup and logs.
function screen_bytes(screen, energies, photons, broadening)
    return @allocated R._fill_transition_screen!(
        screen,
        energies,
        photons,
        broadening,
        1.0,
        5.0;
        external_selection = screen,
    )
end

# Exercise the real spectrum-to-screen path on a constant, explicitly defined model.
function prepare_screen(energies, selection; window = 1, require_complete_groups = true)
    input = AnalyticKInput(
        hamiltonian = (k, p) -> Matrix(Diagonal(p)),
        parameters = collect(energies),
        num_orbitals = length(energies),
        lattice = Matrix{Float64}(I, 3, 3),
        basis = :fixed_orthonormal,
        source_file = @__FILE__
    )
    model = C.AnalyticKModel(input)
    m = WannierNLQG.MatrixElements
    plan = m.compile_matrix_plan(m.MatrixElementRequest(m.SPECTRUM))
    workspace = m.prepare_real_space!(m.MatrixElementWorkspace(model, plan), model)
    screen = R.make_transition_screen_workspace(
        length(energies),
        1,
        1;
        matrix_elements = workspace,
        band_selection = selection,
    )
    cfg = R.EffectiveTaskConfig(
        fourier_backend = "direct",
        spatial_dimension = 3,
        native_model_input = input,
        band_selection = selection,
        band_window_size = window,
        photon_energies = [2.005],
        fermi_energy = 0.0,
        broadening = 0.001,
        degeneracy_threshold = 0.002,
    )
    R._prepare_transition_screen!(
        screen,
        zeros(3),
        cfg,
        model,
        length(energies);
        require_complete_groups,
    )
    return screen, cfg
end

if PHASE in ("contract", "all")
    case!("common_group_input") do
        original = [[1, 2], [3, 4]]
        bands = BandSelection(groups = original)
        original[1][1] = 99
        @test bands.groups == [[1, 2], [3, 4]]
        @test BandSelection().groups === nothing
        for invalid in ([], [[0]], [[true]], [[1, 1]], [[1], [1]], [1, 2])
            @test_throws ArgumentError BandSelection(groups = invalid)
        end
        @test_throws ArgumentError BandSelection(occupied_sum = :average)
        @test_throws ArgumentError BandSelection(groups = [[1]], occupied_sum = :only)
        model = model_input()
        for slice in (false, true), quantity in ("SC", "IC", "ISC", "SSC")
            t = task("pair", quantity, "Conventional", slice; groups = [[1, 2], [3, 4]])
            cfg = configuration(model, [t], slice)
            effective = only(R.compile_task_configs(cfg))
            @test effective.band_selection == ([3, 4], [1, 2])
            summary = R.task_parameter_summary(cfg, t)
            @test summary.observable.bands.groups == [[1, 2], [3, 4]]
            @test only(
                R.compile_task_configs(
                    configuration(model, [task("total", quantity, "Conventional", slice)], slice),
                ),
            ).band_selection == -1
            table = Dict{String, Any}(
                "kind" => slice ? "kslice" : "full_tensor",
                "groups" => [[1, 2], [3, 4]],
            )
            slice && (table["component"] = collect(t.observable.component.indices))
            parsed = R._task_input_observable(table, cfg.sampling, R.normalize_quantity(quantity))
            @test parsed.bands.groups == t.observable.bands.groups
            old =
                slice ?
                Dict(
                    "kind" => "transition",
                    "component" => [1, 1, 2],
                    "conduction" => [3, 4],
                    "valence" => [1, 2],
                ) : Dict("kind" => "full_tensor", "bands" => [1])
            @test_throws ArgumentError R._task_input_observable(old, cfg.sampling)
        end
        for quantity in ("SHG", "THG", "LT", "LOR", "AHC", "OM", "BCDC", "BCQC")
            definition = R.task_definition(R.normalize_quantity(quantity), :conventional, :integral)
            @test_throws ArgumentError R._task_group_observation(
                BandSelection(groups = [[1], [2]]),
                definition,
                "undefined",
            )
        end
    end
    case!("shared_external_screen") do
        energies = [-3.0, -2.0, 1.0, 2.0]
        photons = [4.0]
        for broadening in ("Gaussian", "Lorentzian")
            whole = R.make_transition_screen_workspace(4, 1, 1)
            selected = R.make_transition_screen_workspace(4, 1, 1; band_selection = ([4], [1]))
            for screen in (whole, selected)
                screen.has_bands = true
                screen.band_start, screen.band_end = 1, 4
                screen.occupations .= [1.0, 1.0, 0.0, 0.0]
                R._fill_transition_screen!(
                    screen,
                    energies,
                    [4.0],
                    broadening,
                    1.0,
                    5.0;
                    external_selection = screen,
                )
            end
            @test selected.delta == whole.delta
            @test selected.occupation_differences == whole.occupation_differences
            @test selected.active_pairs_nmajor_length == 1
            @test selected.active_pairs_nmajor[1] == (1, 4)
            @test selected.active_pairs_mmajor[1] == (1, 4)
            @test findall(selected.active_pair_mask) == [CartesianIndex(1, 4)]
            @test selected.derivative_required_pairs_nmajor_length == 2
            @test selected.derivative_required_pairs_nmajor[1:2] == [(1, 4), (4, 1)]
            screen_bytes(selected, energies, photons, broadening)
            @test screen_bytes(selected, energies, photons, broadening) == 0
        end
        for invalid in (([1], [1]), ([5], [1]), ([3, 3], [1]), (Int[], [1]))
            @test_throws Exception R.make_transition_screen_workspace(
                4,
                1,
                1;
                band_selection = invalid,
            )
        end
    end
    case!("window_and_block_boundaries") do
        # Exercise the shared grouping and window guard with a transitive near-degenerate chain.
        screen =
            R.make_transition_screen_workspace(6, 1, 1; band_selection = ([4, 5, 6], [1, 2, 3]))
        screen.data.spectrum.energies .= [-1.003, -1.0015, -1.0, 1.0, 1.0015, 1.003]
        groups = (;
            spectrum = screen.data.spectrum,
            num_orbitals = 6,
            degeneracy_group_starts = screen.degeneracy_group_starts,
            degeneracy_group_stops = screen.degeneracy_group_stops,
            degeneracy_weights = screen.degeneracy_weights,
        )
        WannierNLQG.MatrixElements._mark_response_degeneracy_groups!(groups, 0.002)
        @test screen.degeneracy_group_starts == [1, 1, 1, 4, 4, 4]
        @test screen.degeneracy_group_stops == [3, 3, 3, 6, 6, 6]
        screen.band_start, screen.band_end = 1, 6
        cfg = (; band_selection = ([4, 5, 6], [1, 2, 3]))
        @test R._validate_transition_selection_window!(
            screen,
            cfg;
            require_complete_groups = true,
        ) === screen
        screen.band_start, screen.band_end = 3, 4
        error = try
            R._validate_transition_selection_window!(screen, cfg; require_complete_groups = true)
            nothing
        catch caught
            caught
        end
        @test error isa ArgumentError
        @test occursin("band_window_size=-1", sprint(showerror, error))
        screen.band_start, screen.band_end = 1, 6
        screen.valence_mask[1] = false
        @test_throws ArgumentError R._validate_transition_selection_window!(
            screen,
            cfg;
            require_complete_groups = true,
        )
        @test_logs (:warn, r"basis") R._validate_transition_selection_window!(
            screen,
            cfg;
            require_complete_groups = false,
        )
        @test screen.selection_splits_group
        prepared, actual_cfg =
            prepare_screen([-1.003, -1.0015, -1.0, 1.0, 1.0015, 1.003], ([4, 5, 6], [1, 2, 3]))
        @test (prepared.requested_band_start, prepared.requested_band_end) == (3, 4)
        @test (prepared.band_start, prepared.band_end) == (1, 6)
        @test prepared.active_pair_mask[1, 6]
        @test prepared.window_records[(3, 4, 1, 6)] == (1, 0)
        summary = R._transition_selection_summary([prepared], actual_cfg, 0, 0, nothing)
        @test only(summary.effective_windows).effective == (1, 6)
        @test only(summary.effective_windows).evaluations == 1
        @test summary.groups == [[1, 2, 3], [4, 5, 6]]
        @test_throws ArgumentError prepare_screen([-2.0, -1.0, 1.0, 2.0], ([4], [1]))
    end
end

# Read numerical rows only; response output columns retain the historical real/imag layout.
function numeric_rows(path)
    return [
        parse.(Float64, split(line)) for
        line in eachline(path) if !isempty(strip(line)) && !startswith(strip(line), "#")
    ]
end

# The first task is total; four nonempty, unequal one-pair channels partition its active transitions.
function channel_tasks(quantity, method, slice)
    return vcat(
        [task("total", quantity, method, slice)],
        [
            task("v$(v)c$(c)", quantity, method, slice; groups = [[v], [c]]) for v in 1:2 for
            c in 3:4
        ],
    )
end

# Extract one requested tensor component from the original integral column order.
function integral_value(result, component)
    data = only(numeric_rows(only(filter(path -> endswith(path, ".dat"), result.outputs))))
    ordinal = foldl((value, axis) -> 3value + axis - 1, component; init = 0)
    return data[3 + 2ordinal] + im * data[4 + 2ordinal]
end

# Retain the two original real/imaginary slice matrices and their point ordering.
function slice_values(result)
    real_path = only(filter(p -> occursin("_r_", basename(p)), result.outputs))
    imag_path = only(filter(p -> occursin("_i_", basename(p)), result.outputs))
    return reduce(vcat, numeric_rows(real_path)) + im * reduce(vcat, numeric_rows(imag_path))
end

if PHASE in ("public", "all")
    for (quantity, method) in (
        ("SC", "Conventional"),
        ("SC", "Projector"),
        ("SC", "Geometric_Loop"),
        ("SC", "Wilson_Loop"),
        ("IC", "Conventional"),
        ("ISC", "Conventional"),
        ("SSC", "Conventional"),
    )
        case!("public_$(quantity)_$(method)") do
            model = model_input()
            component = quantity in ("ISC", "SSC") ? (1, 3, 1, 2) : (1, 1, 2)
            integrated =
                WannierNLQG.run(configuration(model, channel_tasks(quantity, method, false), false))
            sliced =
                WannierNLQG.run(configuration(model, channel_tasks(quantity, method, true), true))
            totals = [integral_value(result, component) for result in integrated.task_results]
            points = [slice_values(result) for result in sliced.task_results]
            if quantity == "SC" && method == "Conventional"
                # The retained single-task executor emits the final window summary.
                # Compare its total/selected integral and slice to the shared bundle.
                for slice in (false, true), channel in (1, 2)
                    configured = configuration(
                        model,
                        [channel_tasks(quantity, method, slice)[channel]],
                        slice;
                        progress_enabled = true,
                    )
                    result = WannierNLQG.run(only(R.compile_task_configs(configured)))
                    progress = read(result.progress_out_path, String)
                    @test occursin("BAND SELECTION", progress)
                    @test occursin("effective_windows", progress)
                    @test occursin("source, target", progress)
                    @test channel == 1 ? occursin(r"groups\s*:\s*all bands", progress) :
                          occursin("[[1], [3]]", progress)
                    @test slice ? slice_values(result) == points[channel] :
                          integral_value(result, component) == totals[channel]
                end
            end
            @test all(isfinite, totals)
            @test abs(totals[1]) > 0
            @test any(abs.(totals[2:end] .- totals[1]) .> abs(totals[1]) * 1e-3)
            # Linear decomposition error is bounded relative to all channel magnitudes, not a unit-dependent absolute tolerance.
            scale = sum(abs, totals)
            @test abs(totals[1] - sum(totals[2:end])) <= 1e-12scale
            @test maximum(abs, points[1] - reduce(+, points[2:end])) <=
                  1e-12maximum(sum(abs, p) for p in points)
            for i in eachindex(totals)
                @test isapprox(
                    totals[i],
                    sum(points[i]) / length(points[i]);
                    rtol = 1e-12,
                    atol = 1e-12scale,
                )
                metadata = read(sliced.task_results[i].metadata_path, String)
                @test occursin("effective_windows", metadata)
                @test occursin("source, target", metadata)
            end
        end
    end
end

# Two identical orbital sectors provide complete two-band degeneracy blocks at every k.
function block_model_input()
    rng = MersenneTwister(213)
    rv = [0 1 -1 0 0; 0 0 0 1 -1; 0 0 0 0 0]
    h = zeros(ComplexF64, 4, 4, 5)
    h[:, :, 1] = kron(Matrix{ComplexF64}(I, 2, 2), ComplexF64[-0.8 0.25+0.15im; 0.25-0.15im 0.8])
    for j in (2, 4)
        hopping = 0.12randn(rng, ComplexF64, 2, 2)
        h[:, :, j] = kron(Matrix{ComplexF64}(I, 2, 2), hopping)
        h[:, :, j + 1] = h[:, :, j]'
    end
    return RealSpaceTBInput(
        lattice = 3.0Matrix{Float64}(I, 3, 3),
        r_vectors = rv,
        hamiltonian_r = h,
        orbital_positions = zeros(3, 4),
        position_model = :point_orbitals,
    )
end

# Use a channel-only difference scale for these algebraic equality checks.
function same_channels(left, right)
    scale = max(maximum(abs, left), maximum(abs, right))
    return iszero(scale) ? left == right : maximum(abs, left - right) <= 1e-12scale
end

if PHASE in ("boundaries", "all")
    for method in ("Conventional", "Projector", "Geometric_Loop", "Wilson_Loop")
        case!("public_window_$(method)") do
            model = block_model_input()
            result = WannierNLQG.run(
                configuration(
                    model,
                    [
                        task("whole", "SC", method, true),
                        task("closed", "SC", method, true; groups = [[1, 2], [3, 4]], window = 1),
                    ],
                    true,
                ),
            )
            whole, closed = slice_values.(result.task_results)
            @test maximum(abs, whole) > 0
            @test same_channels(whole, closed)
            metadata = read(result.task_results[2].metadata_path, String)
            @test occursin("effective = (1, 4)", metadata)
            @test occursin("requested = (2, 3)", metadata)
            @test occursin("evaluations = 4", metadata)
            if method != "Conventional"
                rejected = try
                    WannierNLQG.run(
                        configuration(
                            model,
                            [task("cut", "SC", method, true; groups = [[1], [3, 4]], window = 1)],
                            true,
                        ),
                    )
                    nothing
                catch error
                    error
                end
                @test rejected isa Exception
                @test occursin("complete block", sprint(showerror, rejected))
            else
                result = WannierNLQG.run(
                    configuration(
                        model,
                        [task("cut", "SC", method, true; groups = [[1], [3, 4]], window = 1)],
                        true,
                    ),
                )
                @test all(isfinite, slice_values(only(result.task_results)))
                @test occursin(
                    "basis_dependent_evaluations = 4",
                    read(only(result.task_results).metadata_path, String),
                )
            end
        end
    end
    case!("public_input_roundtrip_and_rejection") do
        for slice in (false, true), quantity in ("SC", "IC", "ISC", "SSC")
            component = quantity in ("ISC", "SSC") ? [1, 3, 1, 2] : [1, 1, 2]
            sample =
                slice ?
                Dict(
                    "kind" => "k_slice",
                    "k_mesh" => [2, 2],
                    "spatial_dimension" => 3,
                    "origin" => [0.0, 0.0, 0.0],
                    "vector_1" => [1.0, 0.0, 0.0],
                    "vector_2" => [0.0, 1.0, 0.0],
                ) : Dict("kind" => "bz_mesh", "k_mesh" => [2, 2, 1], "spatial_dimension" => 3)
            observable = Dict{String, Any}(
                "kind" => slice ? "kslice" : "full_tensor",
                "groups" => [[1], [3]],
            )
            slice && (observable["component"] = component)
            document = Dict(
                "model" =>
                    Dict("source" => "julia", "identity" => "explicit selection fixture"),
                "response" => Dict(
                    "energy_zero" => "fixture Hamiltonian reference",
                    "fermi_energy_ev" => 0.0,
                    "temperature_k" => 100.0,
                    "photon_energies_ev" => [2.4],
                    "sampling" => sample,
                    "execution" => Dict("fourier_backend" => "direct"),
                    "tasks" => Dict(
                        "channel" => Dict(
                            "kind" => slice ? quantity * "K" : quantity,
                            "method" => "Conventional",
                            "observable" => observable,
                        ),
                    ),
                ),
                "output" => Dict("output_root" => mktempdir(), "progress_enabled" => false),
            )
            model = model_input()
            resolved = resolve_task_input(document; model)
            @test isempty(resolved.pending)
            @test only(R.compile_task_configs(resolved.config)).band_selection == ([3], [1])
            file = joinpath(mktempdir(), "input.toml")
            WannierNLQG.IO.write_task_input_file(file, document)
            # The native model is explicitly reattached; this is not standalone callback replay.
            replayed = read_task_input(file; model)
            @test only(R.compile_task_configs(replayed.config)).band_selection == ([3], [1])
        end
        for quantity in ("LT", "LOR", "SHG", "THG"), groups in ([[1]], [[1], [2]])
            definition = R.task_definition(R.normalize_quantity(quantity), :conventional, :integral)
            @test_throws ArgumentError R._task_group_observation(
                BandSelection(; groups),
                definition,
                "unsupported",
            )
        end
        outside = try
            WannierNLQG.run(
                configuration(
                    model_input(),
                    [task("outside", "SC", "Conventional", true; groups = [[1], [4]], window = 1)],
                    true,
                ),
            )
            nothing
        catch error
            error
        end
        @test outside isa Exception
        @test occursin("band_window_size=-1", sprint(showerror, outside))
    end
end

end # module ResponseBandSelectionTests
