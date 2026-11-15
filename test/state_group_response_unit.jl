module StateGroupResponseTests
using Test, LinearAlgebra, Random, WannierNLQG
const M = WannierNLQG.MatrixElements
const R = WannierNLQG.Responses
const RESULTS = NamedTuple[]
include(joinpath(@__DIR__, "TestCountCompatibilitySupport.jl"))
const PHASE = get(ENV, "WANNIERNLQG_SELECTION_TEST_PHASE", "all")
PHASE in ("state_pure", "state_runtime", "helpers", "all") ||
    error("Unknown state-group test phase")

# Retain the actual Test counters of each independently named check.
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

# Fixed band-frame operators with nonzero ambient and velocity-pair curvature.
function hall_geometry(energy; orthogonal = true)
    n = length(energy)
    velocity = zeros(ComplexF64, n, n, 3)
    ambient = zeros(ComplexF64, n, n, 3, 3)
    for l in 1:n, m in (l + 1):n
        velocity[l, m, 1] = velocity[m, l, 1] = 0.3 + 0.1l
        velocity[l, m, 2] = im * (0.2 + 0.05m)
        velocity[m, l, 2] = conj(velocity[l, m, 2])
        velocity[l, m, 3] = 0.11 + 0.02m + 0.03im*l
        velocity[m, l, 3] = conj(velocity[l, m, 3])
    end
    for l in 1:n
        ambient[l, l, 1, 2] = 0.07l
        ambient[l, l, 2, 1] = -0.07l
    end
    return M.intrinsic_hall_geometry(
        energy,
        Matrix{ComplexF64}(I, n, n),
        velocity,
        ambient;
        orthonormal_basis = orthogonal,
    )
end

# Independent high-precision sum: the selected outer index retains the original empty complement.
function hall_oracle(geometry, mu, mask)
    return setprecision(BigFloat, 256) do
        energy = geometry.energies
        out = zeros(BigFloat, 3, 3)
        for a in 1:3, b in 1:3, l in eachindex(energy)
            energy[l] <= mu && mask[l] || continue
            out[a, b] += real(Complex{BigFloat}(geometry.ambient_curvature[l, l, a, b]))
            for m in eachindex(energy)
                energy[m] > mu || continue
                gap = BigFloat(energy[l]) - BigFloat(energy[m])
                left =
                    Complex{BigFloat}(geometry.velocity[l, m, a]) *
                    Complex{BigFloat}(geometry.velocity[m, l, b])
                right =
                    Complex{BigFloat}(geometry.velocity[l, m, b]) *
                    Complex{BigFloat}(geometry.velocity[m, l, a])
                out[a, b] -= imag((left - right) / gap^2)
            end
        end
        Float64.(out)
    end
end

# Build physical Hermitian Cartesian geometry and an optional synthetic completion.
function magnetic_geometry(energy; completion = false)
    n = length(energy)
    rng = MersenneTwister(119)
    connection = zeros(ComplexF64, n, n, 3)
    velocity = similar(connection)
    for axis in 1:3
        connection[:, :, axis] = Hermitian(randn(rng, ComplexF64, n, n))
        velocity[:, :, axis] = Hermitian(randn(rng, ComplexF64, n, n))
    end
    geometry = M.spectral_response_geometry(
        energy,
        Matrix{ComplexF64}(I, n, n),
        velocity,
        connection,
        zeros(ComplexF64, n, n, 3, 3);
        gap_tolerance = 0.0,
    )
    external = M.finite_model_orbital_completion(n)
    if completion
        frames = [randn(rng, ComplexF64, n + 2, n) for _ in 1:3]
        weights = Diagonal(collect(range(-0.8, 1.1; length = n + 2)))
        for a in 1:3, b in 1:3
            external.derivative_overlap[:, :, a, b] .= frames[a]' * frames[b]
            external.energy_overlap[:, :, a, b] .= frames[a]' * weights * frames[b]
        end
        external.energy_connection .= randn(rng, ComplexF64, n, n, 3)
    end
    return geometry, external
end

# Construct a mask without changing the physical geometry or its occupations.
function mask_for(group, n)
    mask = falses(n)
    mask[group] .= true
    return mask
end

if PHASE in ("state_pure", "all")
    case!("intrinsic_group_kernels") do
        for energy in ([-0.3, -0.1, 0.2, 0.4], [-0.3, -0.3, 0.2, 0.4])
            geometry = hall_geometry(energy)
            groups = energy[1] == energy[2] ? [[1, 2], [3], [4]] : [[1], [2], [3], [4]]
            mus = [-0.5, -0.3, -0.1, 0.0, 0.2, 0.4, 0.7]
            for method in (:Matrix, :Projector)
                whole = R.intrinsic_hall_fermi_sea(geometry, mus; method)
                @test whole ==
                      R.intrinsic_hall_fermi_sea(geometry, mus; method, band_mask = trues(4))
                parts = [
                    R.intrinsic_hall_fermi_sea(geometry, mus; method, band_mask = mask_for(g, 4)) for g in groups
                ]
                @test whole ≈ reduce(+, parts) atol = 2e-12 rtol = 2e-12
                for (group, part) in zip(groups, parts), (i, mu) in enumerate(mus)
                    @test part[i, :, :] ≈ hall_oracle(geometry, mu, mask_for(group, 4)) atol = 2e-12 rtol =
                        2e-12
                end
                @test all(
                    iszero,
                    R.intrinsic_hall_fermi_sea(geometry, 0.0; method, band_mask = mask_for([4], 4)),
                )
                @test all(
                    iszero,
                    R.intrinsic_hall_fermi_sea(geometry, mus; method, band_mask = falses(4)),
                )
            end
            if energy[1] == energy[2]
                for method in (:Matrix, :Projector)
                    @test_throws ArgumentError R.intrinsic_hall_fermi_sea(
                        geometry,
                        mus;
                        method,
                        band_mask = mask_for([1], 4),
                    )
                end
            end
        end
        close = hall_geometry([1.0, 1.0 + 8eps(1.0), 2.0, 3.0])
        @test_throws ArgumentError R.intrinsic_hall_fermi_sea(
            close,
            1.0;
            band_mask = mask_for([1], 4),
        )
        @test R.intrinsic_hall_fermi_sea(close, 1.0; band_mask = mask_for([1, 2], 4))[1, :, :] ≈
              hall_oracle(close, 1.0, mask_for([1, 2], 4)) atol = 2e-12 rtol = 2e-12
        metric = hall_geometry([-0.3, -0.1, 0.2, 0.4]; orthogonal = false)
        selected = R.intrinsic_hall_fermi_sea(metric, 0.0; band_mask = mask_for([1], 4))
        @test selected[1, :, :] ≈ hall_oracle(metric, 0.0, mask_for([1], 4)) atol = 2e-12 rtol =
            2e-12
        @test_throws ArgumentError R.intrinsic_hall_fermi_sea(
            metric,
            0.0;
            method = :Projector,
            band_mask = mask_for([1], 4),
        )
        @test_throws ArgumentError R.intrinsic_hall_fermi_sea(metric, 0.0; temperature = 1.0)
        @test_throws ArgumentError R.intrinsic_hall_fermi_sea(metric, 0.0; band_mask = trues(3))
    end
    case!("orbital_group_kernels") do
        for energy in ([-0.3, -0.1, 0.2, 0.4], [-0.3, -0.3, 0.2, 0.4]), completion in (false, true)
            geometry, external = magnetic_geometry(energy; completion)
            groups = energy[1] == energy[2] ? [[1, 2], [3], [4]] : [[1], [2], [3], [4]]
            mus = [-0.5, -0.3, -0.1, 0.0, 0.2, 0.4, 0.7]
            for temperature in (0.0, 300.0, 1500.0)
                method_values = Any[]
                for projector in (false, true)
                    options = (;
                        projector,
                        fermi_energies = mus,
                        temperature,
                        denominator_regularization = 0.001,
                    )
                    whole = R.orbital_magnetization_response(geometry, external; options...)
                    @test whole == R.orbital_magnetization_response(
                        geometry,
                        external;
                        options...,
                        band_mask = trues(4),
                    )
                    parts = [
                        R.orbital_magnetization_response(
                            geometry,
                            external;
                            options...,
                            band_mask = mask_for(g, 4),
                        ) for g in groups
                    ]
                    for term in 1:3
                        @test whole[:, :, term] ≈ reduce(+, parts)[:, :, term] atol = 2e-12 rtol =
                            2e-12
                    end
                    @test all(
                        iszero,
                        R.orbital_magnetization_response(
                            geometry,
                            external;
                            options...,
                            band_mask = falses(4),
                        ),
                    )
                    push!(method_values, parts)
                end
                for (left, right) in zip(method_values[1], method_values[2])
                    @test left ≈ right atol = 2e-12 rtol = 2e-12
                end
            end
            if energy[1] == energy[2]
                for projector in (false, true)
                    @test_throws ArgumentError R.orbital_magnetization_response(
                        geometry,
                        external;
                        projector,
                        fermi_energies = [0.0],
                        temperature = 300.0,
                        band_mask = mask_for([1], 4),
                    )
                end
            end
        end
        geometry, external = magnetic_geometry([-0.3, -0.1, 0.2, 0.4])
        band3 = mask_for([3], 4)
        @test all(
            iszero,
            R.orbital_magnetization_response(
                geometry,
                external;
                fermi_energies = [0.0],
                temperature = 0.0,
                band_mask = band3,
            ),
        )
        @test maximum(
            abs,
            R.orbital_magnetization_response(
                geometry,
                external;
                fermi_energies = [0.0],
                temperature = 1500.0,
                band_mask = band3,
            ),
        ) > 0
        metric = M.NonorthogonalSpectralResponseGeometry(geometry, 0.001)
        options = (; fermi_energies = [0.0], temperature = 300.0)
        whole = R.orbital_magnetization_response(metric, external; options...)
        parts = [
            R.orbital_magnetization_response(
                metric,
                external;
                options...,
                band_mask = mask_for([i], 4),
            ) for i in 1:4
        ]
        @test whole ≈ reduce(+, parts) atol = 2e-12 rtol = 2e-12
        @test_throws ArgumentError R.orbital_magnetization_response(
            metric,
            external;
            options...,
            projector = true,
            band_mask = band3,
        )
    end
end
if PHASE in ("state_runtime", "helpers", "all")
    include(joinpath(@__DIR__, "SpectralResponseTestSupport.jl"))
end

# Reuse the retained finite-model fixture; a fixed metric representation is a separate admitted input.
function runtime_input(; metric = false, doubled = false)
    base = spectral_test_model()
    if metric
        x = ComplexF64[1.2 0.3im; 0.1 0.9]
        hr = similar(base.hamiltonian_r)
        sr = zero(base.hamiltonian_r)
        pr = zero(base.position_r)
        zero_cell = only(findall(i -> all(iszero, base.r_vectors[:, i]), axes(base.r_vectors, 2)))
        sr[:, :, zero_cell] .= x' * x
        for i in axes(hr, 3)
            hr[:, :, i] .= x' * base.hamiltonian_r[:, :, i] * x
            for a in 1:3
                pr[:, :, a, i] .= x' * base.position_r[:, :, a, i] * x
            end
        end
        model = WannierNLQG.Core.NonorthogonalLocalizedModel(
            lattice = base.lattice,
            r_vectors = base.r_vectors,
            hamiltonian_r = hr,
            overlap_r = sr,
            position_r = pr,
        )
        return WannierNLQG.Core.NonorthogonalLocalizedInput(model)
    end
    h = doubled ? cat(base.hamiltonian_r, base.hamiltonian_r; dims = (1, 2)) : base.hamiltonian_r
    centers = hcat([real.(diag(base.position_r[:, :, a, 1])) for a in 1:3]...)'
    doubled && (centers = hcat(centers, centers))
    return RealSpaceTBInput(
        lattice = base.lattice,
        r_vectors = base.r_vectors,
        hamiltonian_r = h,
        orbital_positions = centers,
        position_model = :point_orbitals,
    )
end

# Only the observable changes between the ordinary total and single-group tasks.
function state_task(id, quantity, method, slice; group = nothing, temperature = 0.0)
    physics =
        quantity == "AHC" ? IntrinsicHallParameters(fermi_energies = [0.0]) :
        OrbitalMagnetizationParameters(
            fermi_energies = [0.0],
            temperature = temperature,
            input_semantics = :defined_finite_model,
        )
    bands = BandSelection(groups = group === nothing ? nothing : [group])
    component = quantity == "AHC" ? TensorComponent(1, 2) : TensorComponent(3)
    return TaskSpec(;
        id,
        quantity = slice ? quantity * "K" : quantity,
        method,
        physics,
        observable = slice ? KSliceSelection(; component, bands) : FullTensor(; bands),
    )
end

# The two consumers visit the same four fractional points at kz=0.
function state_config(model, tasks, slice)
    sampling =
        slice ?
        KSlice(
            k_mesh = (2, 2),
            spatial_dimension = 3,
            origin = (0.0, 0.0, 0.0),
            vector_1 = (1.0, 0.0, 0.0),
            vector_2 = (0.0, 1.0, 0.0),
        ) : BZMesh(k_mesh = (2, 2, 1), spatial_dimension = 3)
    return TaskConfig(;
        model,
        tasks,
        sampling,
        execution = ExecutionOptions(fourier_backend = "direct"),
        output = OutputOptions(
            output_root = mktempdir(),
            progress_enabled = false,
            response_output_digits = 17,
        ),
    )
end

# Return the unchanged physical numerical columns of one response term.
function term_values(result, quantity, term; slice)
    file = only(
        filter(
            p ->
                basename(p) ==
                (quantity == "AHC" ? "intrinsic_ahc" : "orbital_magnetization") *
                "_" *
                term *
                ".dat",
            result.outputs,
        ),
    )
    table = spectral_test_table(file)
    first_value = slice ? 4 : 2
    return complex.(table[:, first_value:2:end], table[:, (first_value + 1):2:end]), file
end

# Preserve the original reader and every component, not just the chosen slice axis.
function verify_public_groups(model, quantity, method, temperature)
    ordinary = Any[]
    for slice in (false, true)
        tasks = [
            state_task("total", quantity, method, slice; temperature),
            state_task("first", quantity, method, slice; group = [1], temperature),
            state_task("second", quantity, method, slice; group = [2], temperature),
            state_task("all", quantity, method, slice; group = [1, 2], temperature),
        ]
        result = WannierNLQG.run(state_config(model, tasks, slice))
        terms = quantity == "AHC" ? ("total",) : ("srocc", "cmocc", "total")
        values = Dict{String, Any}()
        for term in terms
            parts = [term_values(leaf, quantity, term; slice) for leaf in result.task_results]
            data = first.(parts)
            @test data[1] ≈ data[2] + data[3] atol = 2e-12 rtol = 2e-12
            @test data[1] ≈ data[4] atol = 2e-12 rtol = 2e-12
            for i in 1:4
                text = read(parts[i][2], String)
                @test occursin(r"(?m)^# groups=", text) == (i != 1)
                @test all(isfinite, data[i])
            end
            values[term] = data
        end
        if quantity == "OM" && !slice
            for leaf in result.task_results
                parsed = try
                    read_orbital_magnetization_result(leaf.run_dir)
                catch caught
                    # Preserve exact failing serialized columns before temporary fixtures are cleaned.
                    diagnostic = Dict(
                        term => first(term_values(leaf, quantity, term; slice = false)) for
                        term in terms
                    )
                    println(
                        stdout,
                        "STATE_GROUP_SERIALIZED_TERMS ",
                        repr(diagnostic; context = :limit => false),
                    )
                    flush(stdout)
                    @error "STATE_GROUP_READER_DIAGNOSTIC" quantity method temperature model_type =
                        typeof(model) output_directory = leaf.run_dir values = diagnostic exception =
                        caught
                    rethrow()
                end
                @test parsed.vectors[:total] ≈ parsed.vectors[:srocc] + parsed.vectors[:cmocc] atol =
                    1e-20 rtol = 2e-12
            end
            selected = result.task_results[2]
            for invalid in ("[[2]]", "[[0]]")
                directory = mktempdir()
                for source in selected.outputs
                    cp(source, joinpath(directory, basename(source)))
                end
                file = joinpath(directory, "orbital_magnetization_srocc.dat")
                text = read(file, String)
                @test occursin("# groups=[[1]]", text)
                write(file, replace(text, "# groups=[[1]]" => "# groups=" * invalid; count = 1))
                @test_throws ErrorException read_orbital_magnetization_result(directory)
            end
        end
        push!(ordinary, values)
    end
    volume = abs(det(spectral_test_model().lattice)) * 1e-30
    for (term, integrated) in ordinary[1], i in 1:4
        slice = ordinary[2][term][i]
        component = quantity == "AHC" ? 2 : 3
        reconstructed = sum(slice) / length(slice) / (quantity == "AHC" ? volume : 1.0)
        absolute_bound = 1e-28
        if quantity == "OM" && term == "total"
            # Integral sums SRocc/CMocc before their final addition; a slice
            # adds them at each point. Near cancellation a relative bound on
            # total alone is meaningless. Bound these different addition trees
            # by gamma_(2N+4) times the mean absolute primitive terms. The
            # separate physical terms retain the original strict comparison.
            operations = 2length(slice) + 4
            gamma = operations * eps(Float64) / (1 - operations * eps(Float64))
            primitives = sum(abs, ordinary[2]["srocc"][i]) + sum(abs, ordinary[2]["cmocc"][i])
            absolute_bound = max(absolute_bound, gamma * primitives / length(slice))
        end
        @test isapprox(
            integrated[i][1, component],
            reconstructed;
            atol = absolute_bound,
            rtol = 2e-12,
        )
    end
end

if PHASE in ("state_runtime", "all")
    for (quantity, method) in
        (("AHC", "Conventional"), ("AHC", "Projector"), ("OM", "Conventional"), ("OM", "Projector"))
        case!("public_$(quantity)_$(method)") do
            for temperature in (quantity == "AHC" ? (0.0,) : (0.0, 300.0))
                verify_public_groups(runtime_input(), quantity, method, temperature)
            end
            model = runtime_input(doubled = true)
            tasks = [
                state_task("total", quantity, method, false),
                state_task("block", quantity, method, false; group = [1, 2]),
                state_task("empty", quantity, method, false; group = [3, 4]),
            ]
            result = WannierNLQG.run(state_config(model, tasks, false))
            for term in (quantity == "AHC" ? ("total",) : ("srocc", "cmocc", "total"))
                values = [
                    first(term_values(leaf, quantity, term; slice = false)) for
                    leaf in result.task_results
                ]
                @test values[1] ≈ values[2] + values[3] atol = 2e-12 rtol = 2e-12
            end
            error = try
                WannierNLQG.run(
                    state_config(
                        model,
                        [state_task("cut", quantity, method, true; group = [1])],
                        true,
                    ),
                )
                nothing
            catch caught
                caught
            end
            @test error isa Exception
            @test occursin("complete block", sprint(showerror, error))
        end
    end
    case!("public_metric_state_groups") do
        model = runtime_input(metric = true)
        for quantity in ("AHC", "OM")
            verify_public_groups(model, quantity, "Conventional", quantity == "OM" ? 300.0 : 0.0)
            @test_throws ArgumentError WannierNLQG.run(
                state_config(
                    model,
                    [state_task("unsupported", quantity, "Projector", false; group = [1])],
                    false,
                ),
            )
        end
    end
end

end # module StateGroupResponseTests
