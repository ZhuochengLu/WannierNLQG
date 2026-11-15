module JerkBandSelectionTests
using Test, LinearAlgebra, WannierNLQG
const R = WannierNLQG.Runtime
const M = WannierNLQG.MatrixElements
const P = WannierNLQG.Responses
const RESULTS = NamedTuple[]
withenv("WANNIERNLQG_SELECTION_TEST_PHASE" => "helpers") do
    include("response_band_selection_unit.jl")
end
const H = ResponseBandSelectionTests

function case!(f, label)
    result = @testset "$label" begin
        f()
    end
    counts = Test.get_test_counts(result)
    push!(
        RESULTS,
        (;
            label,
            passed = counts.passes + counts.cumulative_passes,
            failed = counts.fails + counts.cumulative_fails,
            errored = counts.errors + counts.cumulative_errors,
        ),
    )
    flush(stdout)
end

function fixture()
    raw = [
        complex(parse(Float64, split(line)[1]), parse(Float64, split(line)[2])) for
        line in eachline(joinpath(@__DIR__, "fixtures/third_order/jerk_input.dat"))
    ]
    return (;
        spectrum = (; energies = [-1.5, -0.4, 0.7, 1.8]),
        hamiltonian_derivatives = reshape(raw[1:48], 4, 4, 3),
        internal_connection = reshape(raw[49:96], 4, 4, 3),
        hamiltonian_second_derivatives = reshape(raw[97:240], 4, 4, 3, 3),
    )
end

function kernel(
    data;
    selection = nothing,
    temperature = 0.0,
    gaussian = true,
    projection = :ordered,
)
    values = zeros(ComplexF64, 3, 81)
    geometry = M.JerkCurrentGeometry(4)
    occupation = zeros(4)
    P.jerk_current_response!(
        values,
        geometry,
        occupation,
        data,
        [1.1, 2.2, 3.3],
        P.JERK_CURRENT_COMPONENTS;
        fermi_energy = 0.0,
        temperature,
        broadening = 0.04,
        gaussian,
        regularization = 0.001,
        transition_window_factor = 5.0,
        band_window_size = -1,
        projection,
        external_selection = selection,
    )
    return values, geometry, occupation
end

function config(
    model;
    slice = false,
    groups = nothing,
    backend = "direct",
    window = -1,
    temperature = 300.0,
    adaptive = false,
    mesh = 2,
)
    bands = BandSelection(; groups)
    observation =
        slice ? KSliceSelection(component = TensorComponent(1, 1, 2, 1), bands = bands) :
        TensorComponents(TensorComponent(1, 1, 2, 1); bands)
    sampling =
        slice ?
        KSlice(
            k_mesh = (mesh, mesh),
            spatial_dimension = 3,
            origin = (0.0, 0.0, 0.0),
            vector_1 = (1.0, 0.0, 0.0),
            vector_2 = (0.0, 1.0, 0.0),
        ) : BZMesh(k_mesh = (mesh, mesh, 1), spatial_dimension = 3)
    task = TaskSpec(
        id = "jerk",
        quantity = slice ? "JCK" : "JC",
        method = "Conventional",
        physics = JerkParameters(
            photon_energies = [2.4],
            fermi_energy = 0.0,
            temperature = temperature,
        ),
        numerics = Numerics(
            broadening = 0.4,
            transition_window_factor = 0.0,
            band_window_size = window,
        ),
        observable = observation,
    )
    return TaskConfig(
        model = model,
        sampling = sampling,
        tasks = [task],
        execution = ExecutionOptions(
            fourier_backend = backend,
            NKFFT = backend == "mixed" ? (slice ? (mesh, mesh) : (mesh, mesh, 1)) : nothing,
            integration_algorithm = adaptive ?
                                    HAdaptiveCubature(
                atol = 0.0,
                rtol = 1e-8,
                max_evaluations = 33,
            ) : UniformIntegration(),
        ),
        output = OutputOptions(
            output_root = mktempdir(),
            progress_enabled = false,
            response_output_digits = 17,
        ),
    )
end

function table(result)
    path = only(filter(p -> endswith(p, ".dat"), result.outputs))
    return H.numeric_rows(path)
end
response(result; slice = false) = [row[end - 1] + im * row[end] for row in table(result)]

function analytic_input()
    return AnalyticKInput(
        hamiltonian = (k, p) -> [
            -1.3 + 0.12cos(3*k[1]) 0.09sin(3*k[2]) 0.17sin(3*k[1]) 0.13;
            0.09sin(3*k[2]) -0.6 + 0.08sin(3*k[1]) 0.11 0.15cos(3*k[2]);
            0.17sin(3*k[1]) 0.11 0.8 + 0.10cos(3*k[2]) 0.07;
            0.13 0.15cos(3*k[2]) 0.07 1.5 + 0.09sin(3*k[1])
        ],
        num_orbitals = 4,
        lattice = 3.0Matrix{Float64}(I, 3, 3),
        basis = :fixed_orthonormal,
        periodic = true,
        source_file = @__FILE__
    )
end

if get(ENV, "WANNIERNLQG_JERK_TEST_PHASE", "all") != "helpers"
    case!("jerk_external_kernel") do
        data = fixture()
        actual, geometry, occupation = kernel(data)
        reference = reshape(
            [
                complex(parse(Float64, split(line)[1]), parse(Float64, split(line)[2])) for
                line in eachline(joinpath(@__DIR__, "fixtures/third_order/jerk_reference.dat"))
            ],
            3,
            81,
        )
        @test actual ≈ reference atol = 1e-12 rtol = 4e-15
        for temperature in (0.0, 3000.0),
            gaussian in (true, false),
            projection in (:ordered, :symmetric, :antisymmetric)

            total, full, f = kernel(data; temperature, gaussian, projection)
            sum_pairs = zero(total)
            for m in 1:3, n in (m + 1):4
                selection = R.make_external_band_window_workspace(4; band_selection = ([n], [m]))
                selected, g, sf = kernel(data; selection, temperature, gaussian, projection)
                @test g.hessians == full.hessians && g.dipoles == full.dipoles && sf == f
                expected = zero(total)
                for (i, energy) in enumerate([1.1, 2.2, 3.3]),
                    (j, (a, b, c, d)) in enumerate(P.JERK_CURRENT_COMPONENTS)

                    gap = data.spectrum.energies[n] - data.spectrum.energies[m]
                    abs(gap-energy) > 5*0.04 && continue
                    optical = full.dipoles[n, m, b] * full.dipoles[m, n, c]
                    reverse = full.dipoles[n, m, c] * full.dipoles[m, n, b]
                    projection == :symmetric && (optical = (optical+reverse)/2)
                    projection == :antisymmetric && (optical = (optical-reverse)/2)
                    expected[i, j] =
                        (f[m]-f[n]) *
                        P.second_harmonic_delta(gap-energy, 0.04, gaussian) *
                        optical *
                        (full.hessians[n, a, d]-full.hessians[m, a, d])
                end
                @test selected == expected
                sum_pairs .+= selected
            end
            @test sum_pairs ≈ total atol = 1e-12 rtol = 4e-15
            group = R.make_external_band_window_workspace(4; band_selection = ([3, 4], [1, 2]))
            selected, _, _ = kernel(data; selection = group, temperature, gaussian, projection)
            combined = zero(total)
            for m in 1:2, n in 3:4
                combined .+= first(
                    kernel(
                        data;
                        selection = R.make_external_band_window_workspace(
                            4;
                            band_selection = ([n], [m]),
                        ),
                        temperature,
                        gaussian,
                        projection,
                    ),
                )
            end
            @test selected ≈ combined atol = 1e-12 rtol = 4e-15
        end
        selected = R.make_external_band_window_workspace(4; band_selection = ([3], [1]))
        changed = deepcopy(data)
        changed.hamiltonian_derivatives[4, :, :] .= 0
        changed.hamiltonian_derivatives[:, 4, :] .= 0
        @test maximum(
            abs,
            first(kernel(data; selection = selected)) -
            first(kernel(changed; selection = selected)),
        ) > 1e-10
    end

    case!("jerk_interface_windows") do
        for slice in (false, true), groups in (nothing, [[1], [3]], [[1, 2], [3, 4]])
            cfg = config(H.model_input(); slice, groups)
            lowered = only(R.compile_task_configs(cfg))
            @test lowered.band_selection == (groups === nothing ? -1 : (groups[2], groups[1]))
            observable = Dict{String, Any}("kind" => slice ? "kslice" : "tensor_components")
            slice ? (observable["component"] = [1, 1, 2, 1]) :
            (observable["components"] = [[1, 1, 2, 1]])
            groups === nothing || (observable["groups"] = groups)
            parsed = R._task_input_observable(observable, cfg.sampling, :jerk_current)
            @test parsed.bands.groups == groups
        end
        definition = R.task_definition(:jerk_current, :conventional, :integral)
        @test_throws ArgumentError R._task_group_observation(
            BandSelection(groups = [[1]]),
            definition,
            "invalid",
        )
        @test_throws ArgumentError R._task_group_observation(
            BandSelection(occupied_sum = :only),
            definition,
            "invalid",
        )
        lowered = only(R.compile_task_configs(config(H.model_input(); groups = [[1], [3]])))
        @test_throws ArgumentError R._validate_nonorthogonal_tasks(
            R.normalize_task_specs(lowered),
            (; include_external = false),
        )
        spectrum = (; energies = [-1.0, -1.0, 1.0, 1.0])
        selected = R.make_external_band_window_workspace(4; band_selection = ([3], [1]))
        cfg = (; band_selection = ([3], [1]), band_window_size = 1, fermi_energy = 0.0)
        @test_logs (:warn, r"basis") R._prepare_transition_selection_window!(
            selected,
            cfg,
            spectrum,
            4;
            degeneracy_threshold = 0.0,
            require_complete_groups = false,
        )
        @test (selected.requested_band_start, selected.requested_band_end) == (2, 3)
        @test (selected.band_start, selected.band_end) == (1, 4)
        @test selected.selection_splits_group
        outside = try
            R._prepare_transition_selection_window!(
                selected,
                cfg,
                (; energies = [-2.0, -1.0, 1.0, 2.0]),
                4;
                degeneracy_threshold = 0.0,
                require_complete_groups = false,
            )
            nothing
        catch error
            error
        end
        @test outside isa ArgumentError
        @test occursin("band_window_size=-1", sprint(showerror, outside))
        # Shared SC/IC helper keeps its existing transitive response grouping, not Jerk's rule.
        screen =
            R.make_transition_screen_workspace(6, 1, 1; band_selection = ([4, 5, 6], [1, 2, 3]))
        shared_cfg =
            (; band_selection = ([4, 5, 6], [1, 2, 3]), band_window_size = 1, fermi_energy = 0.0)
        R._prepare_transition_selection_window!(
            screen,
            shared_cfg,
            (; energies = [-1.003, -1.0015, -1.0, 1.0, 1.0015, 1.003]),
            6;
            degeneracy_threshold = 0.002,
            require_complete_groups = true,
        )
        @test (screen.band_start, screen.band_end) == (1, 6)
        @test screen.degeneracy_group_starts == [1, 1, 1, 4, 4, 4]
    end

    case!("jerk_periodic_consumers") do
        model = H.model_input()
        totals = Dict{Bool, Vector{ComplexF64}}()
        for slice in (false, true)
            full_result = WannierNLQG.run(config(model; slice))
            totals[slice] = response(full_result; slice)
            selected =
                response(WannierNLQG.run(config(model; slice, groups = [[1, 2], [3, 4]])); slice)
            @test selected ≈ totals[slice] atol = 1e-24 rtol = 2e-12
            pair_sum = zero(selected)
            for m in 1:2, n in 3:4
                pair_sum .+=
                    response(WannierNLQG.run(config(model; slice, groups = [[m], [n]])); slice)
            end
            @test pair_sum ≈ selected atol = 1e-24 rtol = 2e-12
            mixed = response(
                WannierNLQG.run(config(model; slice, groups = [[1], [3]], backend = "mixed"));
                slice,
            )
            direct = response(WannierNLQG.run(config(model; slice, groups = [[1], [3]])); slice)
            @test mixed ≈ direct atol = 1e-24 rtol = 2e-12
            @test maximum(abs, selected)>0
            diagnostics = read(
                only(filter(p->endswith(p, "jc_numerical_diagnostics.txt"), full_result.outputs)),
                String,
            )
            @test occursin("effective_windows", diagnostics) &&
                  occursin("groups = nothing", diagnostics)
        end
        @test only(totals[false]) ≈ sum(totals[true])/4 atol = 1e-24 rtol = 2e-12
    end

    case!("jerk_analytic_consumers") do
        model = analytic_input()
        for slice in (false, true)
            total = response(WannierNLQG.run(config(model; slice, temperature = 0.0)); slice)
            group = response(
                WannierNLQG.run(config(model; slice, groups = [[1, 2], [3, 4]], temperature = 0.0));
                slice,
            )
            @test total ≈ group atol = 1e-24 rtol = 2e-12
            @test all(isfinite, group)
        end
        # One complete original 3D cubature rule; no new tree, norm or budget policy.
        selected = WannierNLQG.run(config(model; groups = [[1], [3]], adaptive = true))
        @test all(isfinite, response(selected))
        diagnostic = read(
            only(filter(p->endswith(p, "integration_diagnostics.txt"), selected.outputs)),
            String,
        )
        @test occursin("evaluations=33", diagnostic)
    end
end # executed cases
end # module
