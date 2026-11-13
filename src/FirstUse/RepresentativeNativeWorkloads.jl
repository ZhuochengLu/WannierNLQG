# Native inputs enter additional model/metric/derivative trees. These small
# public calls complement the file-backed workloads; they are not a public-path
# registry. Cold qualification uses independently defined user callbacks.
function _first_use_native_tb()
    vectors = [0 1 -1; 0 0 0; 0 0 0]
    h = zeros(ComplexF64, 2, 2, 3)
    h[:, :, 1] = [0.3 1.0; 1.0 -0.3]
    h[:, :, 2] = [0 0; 0.7 0]
    h[:, :, 3] = h[:, :, 2]'
    return RealSpaceTBInput(
        lattice = Matrix{Float64}(LinearAlgebra.I, 3, 3),
        r_vectors = vectors,
        hamiltonian_r = h,
        orbital_positions = [0.0 0.3; 0.0 0.0; 0.0 0.0],
    )
end

# Positive-metric native input reaches the generalized eigensystem and position operators.
function _first_use_native_metric()
    tb = _first_use_native_tb().model
    metric = zeros(ComplexF64, 2, 2, 3)
    metric[:, :, 1] = [1.0 0.08; 0.08 1.1]
    position = zeros(ComplexF64, 2, 2, 3, 3)
    position[:, :, 1, 1] = [0.1 0.025; 0.025 0.3]
    model = Core.NonorthogonalLocalizedModel(
        lattice = tb.lattice,
        r_vectors = tb.r_vectors,
        hamiltonian_r = tb.hamiltonian_r,
        overlap_r = metric,
        position_r = position,
    )
    return Core.NonorthogonalLocalizedInput(model; source_file = @__FILE__)
end

# Tiny periodic hopping or finite polynomial Hamiltonian for real analytic workloads.
function _first_use_native_h(k, p)
    if p.periodic
        off = p.intra + p.inter * exp(-im * k[1])
        return [p.mass off; conj(off) -p.mass]
    end
    x = p.gap + p.beta * k[1]^2
    y = p.velocity * k[1]
    z = p.mass + p.tilt * k[1]
    return [z x-im*y; x+im*y -z]
end

# Supply exact periodic hopping derivatives through the third optical order.
function _first_use_native_derivative(k, p, order)
    result = zeros(promote_type(ComplexF64, eltype(k)), 2, 2, ntuple(_ -> 3, order)...)
    index = ntuple(_ -> 1, order)
    off = p.inter * (-im)^order * exp(-im * k[1])
    result[1, 2, index...] = off
    result[2, 1, index...] = conj(off)
    return result
end
# First-order callback for the explicit analytic public input.
_first_use_native_d1(k, p) = _first_use_native_derivative(k, p, 1)
# Second-order callback for the explicit analytic public input.
_first_use_native_d2(k, p) = _first_use_native_derivative(k, p, 2)
# Third-order callback for the explicit analytic public input.
_first_use_native_d3(k, p) = _first_use_native_derivative(k, p, 3)

# Build one tiny analytic input with an explicit, automatic, or finite-difference derivative route.
function _first_use_native_analytic(method; periodic = true)
    derivatives =
        method == :explicit ? (_first_use_native_d1, _first_use_native_d2, _first_use_native_d3) :
        (nothing, nothing, nothing)
    return AnalyticKInput(
        hamiltonian = _first_use_native_h,
        derivatives = derivatives,
        derivative_method = method,
        num_orbitals = 2,
        lattice = Matrix{Float64}(LinearAlgebra.I, 3, 3),
        orbital_positions = [0.0 0.3; 0.0 0.0; 0.0 0.0],
        parameters = (
            periodic = periodic,
            mass = 0.3,
            intra = 1.0,
            inter = 0.7,
            gap = 0.4,
            beta = 0.2,
            velocity = 0.7,
            tilt = 0.1,
        ),
        periodic = periodic,
        finite_difference_step = 1e-3,
        source_file = @__FILE__,
    )
end

# Bundle shift current and SHG with bounded direct, FFT, or adaptive public execution.
function _first_use_native_config(
    model,
    destination;
    mixed = false,
    adaptive = false,
    region = adaptive,
)
    sampling =
        region ? KRegion(lower = (-0.5,), upper = (0.5,), k_mesh = (2,)) :
        BZMesh(k_mesh = (2, 1, 1), spatial_dimension = 3)
    algorithm =
        adaptive ?
        HAdaptiveCubature(atol = 1e-8, rtol = 1e-5, max_evaluations = 45, initial_divisions = 1) :
        UniformIntegration()
    return TaskConfig(
        model = model,
        sampling = sampling,
        tasks = [
            TaskSpec(
                id = "shift",
                quantity = "SC",
                method = "Conventional",
                physics = OpticalParameters(
                    photon_energies = [0.73],
                    fermi_energy = 0.0,
                    temperature = 300.0,
                ),
                numerics = Numerics(broadening = 0.12, denominator_regularization = 0.001),
                observable = FullTensor(),
            ),
            TaskSpec(
                id = "shg",
                quantity = "SHG",
                method = "Conventional",
                physics = SHGParameters(
                    photon_energies = [0.73],
                    fermi_energy = 0.0,
                    temperature = 300.0,
                    output = :both,
                ),
                observable = FullTensor(),
            ),
        ],
        execution = mixed ?
                    ExecutionOptions(
            fourier_backend = "mixed",
            NKdiv = (1, 1, 1),
            NKFFT = (2, 1, 1),
            integration_algorithm = algorithm,
        ) : ExecutionOptions(fourier_backend = "direct", integration_algorithm = algorithm),
        output = OutputOptions(output_root = destination, progress_enabled = false),
    )
end

# Reuse the existing public spectral tasks for the distinct metric pair/OM types.
# Only Conventional is supported for this metric input; no Projector expansion.
function _first_use_native_metric_spectral(model, destination)
    tasks=filter(task->task.method=="Conventional", _first_use_spectral_tasks())
    return _first_use_config(
        model,
        BZMesh(k_mesh = (1, 1, 1), spatial_dimension = 3),
        tasks,
        destination,
    )
end

@setup_workload let
    _first_use_require_serial()
    root = mktempdir()
    try
        # Array-backed native input admission/provenance plus the actual FFT plan.
        # The already-covered orthogonal Direct kernels share this model tree.
        tb = _first_use_native_config(_first_use_native_tb(), joinpath(root, "tb"); mixed = true)
        metric = _first_use_native_metric()
        metric_direct = _first_use_native_config(metric, joinpath(root, "metric_direct"))
        metric_mixed =
            _first_use_native_config(metric, joinpath(root, "metric_mixed"); mixed = true)
        analytic = [
            _first_use_native_config(
                _first_use_native_analytic(method),
                joinpath(root, string(method)),
            ) for method in (:explicit, :automatic, :finite_difference)
        ]
        finite = _first_use_native_config(
            _first_use_native_analytic(:automatic; periodic = false),
            joinpath(root, "finite_adaptive");
            adaptive = true,
        )
        finite_uniform = _first_use_native_config(
            _first_use_native_analytic(:automatic; periodic = false),
            joinpath(root, "finite_uniform");
            region = true,
        )
        @compile_workload begin
            run(tb)
            # Generalized metric/eigensystem and separate direct/FFT storage.
            run(metric_direct)
            run(metric_mixed)
            # Build through the real public configuration inside capture as well
            # as running the generalized spectral-pair and finite-model OM entry.
            run(_first_use_native_metric_spectral(metric, joinpath(root, "metric_spectral")))
            # Supplied derivatives, ForwardDiff, and checked finite differences
            # have genuinely different evaluation trees; no synthetic signature.
            for cfg in analytic
                run(cfg)
            end
            # Unfolded finite-domain provenance and bounded adaptive integration.
            run(finite)
            # Uniform finite-domain task lowering has a different sampling tuple.
            run(finite_uniform)
            @assert !MPI.Initialized()
            @assert Runtime.ACTIVE_PROGRESS[] === nothing
        end
    finally
        rm(root; recursive = true, force = true)
    end
end
