module NativeModelResponseTests
using WannierNLQG, LinearAlgebra, Random, Test
const R=WannierNLQG.Runtime
const C=WannierNLQG.Core
const ROOT=dirname(dirname(pathof(WannierNLQG)))
Random.seed!(971)
lat=Matrix{Float64}(I, 3, 3)*3
rv=[0 1 -1 0 0 0 0; 0 0 0 1 -1 0 0; 0 0 0 0 0 1 -1]
h=zeros(ComplexF64, 4, 4, 7);
h[:, :, 1]=Diagonal([-1.4, -0.8, 0.9, 1.6])
for j in (2, 4, 6)
    ;
    h[:, :, j].=0.08randn(ComplexF64, 4, 4);
    h[:, :, j + 1].=h[:, :, j]';
end
tau=repeat(rand(3, 2)*0.4; inner = (1, 2))
spin=zeros(ComplexF64, 4, 4, 3)
spin[:, :, 1]=[0 1 0 0; 1 0 0 0; 0 0 0 1; 0 0 1 0]
spin[:, :, 2]=[0 -im 0 0; im 0 0 0; 0 0 0 -im; 0 0 im 0]
spin[:, :, 3]=Diagonal([1, -1, 1, -1])
params=(lattice = lat, rv = rv, h = h, spin = spin)
function hj(k, p, order)
    out=zeros(promote_type(ComplexF64, eltype(k)), 4, 4, ntuple(_->3, order)...)
    for r in axes(p.rv, 2)
        v=transpose(p.lattice)*p.rv[:, r];
        phase=exp(im*sum(v .* k))
        for ix in CartesianIndices(ntuple(_->3, order))
            factor=phase*prod((im*v[a] for a in Tuple(ix)); init = 1.0+0im)
            view(out,:,:,(Tuple(ix)...)).+=factor .* p.h[:, :, r]
        end
    end
    return out
end
ham(k, p)=hj(k, p, 0)
d1(k, p)=hj(k, p, 1)
d2(k, p)=hj(k, p, 2)
d3(k, p)=hj(k, p, 3)
sp(k, p)=p.spin
native=RealSpaceTBInput(
    lattice = lat,
    r_vectors = rv,
    hamiltonian_r = h,
    orbital_positions = tau,
    position_model = :point_orbitals,
    operators = (spin = spin,),
)
analytic=AnalyticKInput(
    hamiltonian = ham,
    derivatives = (d1, d2, d3),
    num_orbitals = 4,
    lattice = lat,
    orbital_positions = tau,
    operators = (spin = spin,),
    parameters = params,
    source_file = @__FILE__
)
function values(path)
    rows=[
        parse.(Float64, split(line)) for
        line in eachline(path) if !isempty(strip(line)) && !startswith(strip(line), "#")
    ]
    return isempty(rows) ? Float64[] : reduce(vcat, rows)
end
outroot=mktempdir()
println("OUTPUT_ROOT ", outroot);
flush(stdout)
const EXPECTED_NATIVE_TASKS = (
    (:berry_curvature_dipole_conductivity, :conventional, :integral),
    (:berry_curvature_dipole_conductivity, :conventional, :kslice),
    (:berry_curvature_quadrupole_conductivity, :conventional, :integral),
    (:berry_curvature_quadrupole_conductivity, :conventional, :kslice),
    (:intrinsic_ahc, :conventional, :integral),
    (:intrinsic_ahc, :conventional, :kslice),
    (:intrinsic_ahc, :projector, :integral),
    (:intrinsic_ahc, :projector, :kslice),
    (:linear_transport, :conventional, :integral),
    (:linear_transport, :conventional, :kslice),
    (:linear_transport, :projector, :integral),
    (:linear_transport, :projector, :kslice),
    (:linear_optical_response, :conventional, :integral),
    (:linear_optical_response, :conventional, :kslice),
    (:linear_optical_response, :projector, :integral),
    (:linear_optical_response, :projector, :kslice),
    (:orbital_magnetization, :conventional, :integral),
    (:orbital_magnetization, :conventional, :kslice),
    (:orbital_magnetization, :projector, :integral),
    (:orbital_magnetization, :projector, :kslice),
    (:jerk_current, :conventional, :integral),
    (:jerk_current, :conventional, :kslice),
    (:third_harmonic_generation, :conventional, :integral),
    (:third_harmonic_generation, :conventional, :kslice),
    (:second_harmonic_generation, :conventional, :integral),
    (:second_harmonic_generation, :conventional, :kslice),
    (:band_structure, :conventional, :kpath),
    (:shift_current, :conventional, :integral),
    (:shift_current, :projector, :integral),
    (:shift_current, :geometric_loop, :integral),
    (:shift_current, :wilson_loop, :integral),
    (:shift_current, :conventional, :kslice),
    (:shift_current, :projector, :kslice),
    (:shift_current, :geometric_loop, :kslice),
    (:shift_current, :wilson_loop, :kslice),
    (:quantum_hermitian_connection, :conventional, :kslice),
    (:quantum_hermitian_connection, :projector, :kslice),
    (:quantum_hermitian_connection, :wilson_loop, :kslice),
    (:hermitian_curvature_tensor, :conventional, :kslice),
    (:berry_curvature, :conventional, :kslice),
    (:berry_curvature_dipole, :conventional, :kslice),
    (:berry_curvature_quadrupole, :conventional, :kslice),
    (:quantum_metric, :conventional, :kslice),
    (:interband_berry_curvature, :conventional, :kslice),
    (:interband_quantum_metric, :conventional, :kslice),
    (:zeeman_interband_berry_curvature, :conventional, :kslice),
    (:zeeman_interband_quantum_metric, :conventional, :kslice),
    (:quantum_metric_dipole, :conventional, :kslice),
    (:quantum_metric_quadrupole, :conventional, :kslice),
    (:quantum_christoffel_symbol, :conventional, :kslice),
    (:triple_phase_product, :conventional, :kslice),
    (:photon_drag_shift_current, :geometric_loop, :integral),
    (:photon_drag_shift_current, :geometric_loop, :kslice),
    (:shift_vector, :geometric_loop, :kslice),
    (:shift_vector, :wilson_loop, :kslice),
    (:injection_current, :conventional, :integral),
    (:injection_current, :conventional, :kslice),
    (:injection_spin_current, :conventional, :integral),
    (:injection_spin_current, :conventional, :kslice),
    (:shift_spin_current, :conventional, :integral),
    (:shift_spin_current, :conventional, :kslice),
    (:photon_drag_injection_current, :conventional, :integral),
    (:photon_drag_injection_current, :conventional, :kslice),
)
@test Tuple(
    (R.quantity_symbol(t.quantity), R.method_symbol(t.method), R.calculation_symbol(t.calculation))
    for t in R.TASK_DEFINITIONS
)==EXPECTED_NATIVE_TASKS
failed=String[]
for (index, t) in enumerate(R.TASK_DEFINITIONS)
    quantity=R.quantity_symbol(t.quantity);
    method=R.method_symbol(t.method);
    calculation=R.calculation_symbol(t.calculation)
    label=join((quantity, method, calculation), "/")
    example=calculation==:kpath ? joinpath(ROOT, "examples", "tasks", "band", "band_structure.jl") :
            joinpath(
        ROOT,
        "examples",
        "tasks",
        String(calculation),
        string(quantity, "_", method, ".jl"),
    )
    println("START ", index, " ", label);
    flush(stdout)
    try
        # Exercise both native backends and both AHC consumers under the
        # T=0/all-band contract; the sampling selects the requested calculation.
        template = if quantity == :intrinsic_ahc
            TaskConfig(
                model = native,
                sampling = calculation == :kslice ?
                           KSlice(
                    k_mesh = (2, 2),
                    spatial_dimension = 3,
                    origin = (0.0, 0.0, 0.0),
                    vector_1 = (1.0, 0.0, 0.0),
                    vector_2 = (0.0, 1.0, 0.0),
                ) : BZMesh(k_mesh = (2, 2, 2), spatial_dimension = 3),
                tasks = [
                    TaskSpec(
                        id = "native_intrinsic_ahc_$(method)_$(calculation)",
                        quantity = String(quantity),
                        method = String(method),
                        physics = IntrinsicHallParameters(fermi_energies = [0.13]),
                        observable = calculation == :kslice ?
                                     KSliceSelection(
                            component = TensorComponent(1, 2),
                            bands = BandSelection(),
                        ) : FullTensor(),
                    ),
                ],
                execution = ExecutionOptions(fourier_backend = "direct"),
                output = OutputOptions(output_root = mktempdir(), progress_enabled = false),
            )
        else
            mod=Module(Symbol("Example", index));
            Core.eval(mod, :(include(path)=Base.include(@__MODULE__, path)));
            Base.include(mod, example)
            calculation==:kpath ?
            Base.invokelatest(
                mod.build_config;
                output_root = mktempdir(),
                progress_enabled = false,
            ) :
            Base.invokelatest(
                mod.build_config;
                k_mesh = (2, 2),
                output_root = mktempdir(),
                progress_enabled = false,
            )
        end
        # The current point-orbital API cannot supply full derivative overlaps.
        # Explicit external completion must reject that input under the full-geometry contract.
        if quantity in (
            :quantum_metric,
            :quantum_metric_dipole,
            :quantum_metric_quadrupole,
            :quantum_christoffel_symbol,
        )
            for model in (native, analytic)
                cfg = TaskConfig(
                    model = model,
                    sampling = template.sampling,
                    tasks = [
                        TaskSpec(;
                            id = t.id,
                            quantity = t.quantity,
                            method = t.method,
                            physics = GeometryParameters(
                                fermi_energy = t.physics.fermi_energy,
                                temperature = t.physics.temperature,
                                photon_momentum = t.physics.photon_momentum,
                                include_external = true,
                            ),
                            numerics = t.numerics,
                            observable = t.observable,
                        ) for t in template.tasks
                    ],
                    execution = ExecutionOptions(fourier_backend = "direct"),
                    output = OutputOptions(output_root = mktempdir(), progress_enabled = false),
                )
                err = try
                    Base.invokelatest(WannierNLQG.run, cfg)
                    nothing
                catch exception
                    exception
                end
                @test err isa ArgumentError
                @test occursin(
                    "QUANTUM_METRIC_FULL_DERIVATIVE_OVERLAP_REQUIRED",
                    sprint(showerror, err),
                )
            end
            println("PASS_REQUIRED_OVERLAP ", index, " ", label)
            continue
        end
        ladder = Vector{Vector{Vector{Float64}}}()
        # The derivative-sensitive fixtures have an independently checked O(h^2)
        # convergence range. Tolerances and production defaults are unchanged.
        steps =
            (quantity, method, calculation) in (
                (:quantum_hermitian_connection, :projector, :kslice),
                (:berry_curvature_quadrupole, :conventional, :kslice),
                (:quantum_metric_quadrupole, :conventional, :kslice),
            ) ? (0.002, 0.001, 0.0005) : (nothing,)
        for step in steps
            tasks = template.tasks
            if step !== nothing
                task = only(tasks)
                fields = (;
                    (
                        name=>getproperty(task.numerics.values, name) for
                        name in task.numerics.supplied
                    )...
                )
                numerics=Numerics(; merge(fields, (finite_difference_step = step,))...)
                tasks=[
                    TaskSpec(
                        id = task.id,
                        quantity = task.quantity,
                        method = task.method,
                        physics = task.physics,
                        numerics = numerics,
                        observable = task.observable,
                    ),
                ]
            end
            outputs=Vector{String}[]
            for (name, model) in (("native", native), ("analytic", analytic))
                cfg=TaskConfig(
                    model = model,
                    sampling = template.sampling,
                    tasks = tasks,
                    execution = ExecutionOptions(fourier_backend = "direct"),
                    output = OutputOptions(
                        output_root = joinpath(outroot, string(index), string(step), name),
                        progress_enabled = false,
                        response_output_digits = 16,
                    ),
                )
                result=Base.invokelatest(WannierNLQG.run, cfg)
                if quantity == :linear_transport && calculation == :integral
                    leaf = isempty(result.task_results) ? result : only(result.task_results)
                    restored = read_linear_transport_result(leaf.run_dir)
                    @test startswith(
                        restored.metadata["model_identity"],
                        "wanniernlqg.owned-data/1:",
                    )
                    @test restored.metadata["input_identity"] == restored.metadata["model_identity"]
                    @test !haskey(restored.metadata, "model_sha256") &&
                          !haskey(restored.metadata, "input_identity_sha256")
                end
                push!(outputs, filter(x->endswith(x, ".dat"), result.outputs))
            end
            push!(ladder, [reduce(vcat, values.(paths)) for paths in outputs])
            @test length(outputs[1])==length(outputs[2])>0
            for (a, b) in zip(outputs...)
                x=values(a);
                y=values(b)
                @test all(isfinite, x)&&all(isfinite, y)
                @test isapprox(x, y; atol = 1e-10, rtol = 1e-8)
            end
        end
        if length(ladder)==3
            for backend in 1:2
                e1=maximum(abs, ladder[1][backend] .- ladder[2][backend])
                e2=maximum(abs, ladder[2][backend] .- ladder[3][backend])
                @test e2 <= 0.3e1 || e2 < 1e-8
            end
        end
        println("PASS ", index, " ", label)
    catch err
        push!(failed, label)
        println("FAIL ", index, " ", label, " ", sprint(showerror, err))
        Base.show_backtrace(stdout, catch_backtrace());
        println()
    end
    flush(stdout)
end
println("MATRIX_DONE failures=", length(failed), " ", failed)

isempty(failed) || error("native model response matrix has failing rows")

end
