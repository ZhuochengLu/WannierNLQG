module NativeModelSymmetryTests
using WannierNLQG, LinearAlgebra, Random, Test, JSON3
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
time_reversal=kron(Matrix{ComplexF64}(I, 2, 2), ComplexF64[0 1; -1 0])
for r in axes(h, 3)
    h[:, :, r].=(h[:, :, r]+time_reversal*conj.(h[:, :, r])*time_reversal')/2
end
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
function numbers(path)
    reduce(
        vcat,
        [
            parse.(Float64, split(line)) for
            line in eachline(path) if !isempty(strip(line)) && !startswith(strip(line), "#")
        ];
        init = Float64[],
    )
end
operations=[
    PointOrbitalSymmetryOperation(
        rotation_fractional = Matrix{Int}(I, 3, 3),
        representation = Matrix{ComplexF64}(I, 4, 4),
    ),
    PointOrbitalSymmetryOperation(
        rotation_fractional = Matrix{Int}(I, 3, 3),
        antiunitary = true,
        representation = time_reversal,
    ),
]
outroot=mktempdir()
println("SYMMETRY_ROOT ", outroot)
@test length(R.RESPONSE_SYMMETRY_SUPPORTED_TASKS)==14
failures=String[]
for (index, t) in enumerate(R.TASK_DEFINITIONS)
    q=R.quantity_symbol(t.quantity);
    m=R.method_symbol(t.method);
    calc=R.calculation_symbol(t.calculation)
    (q, m, calc) in R.RESPONSE_SYMMETRY_SUPPORTED_TASKS || continue
    label=string(q, "/", m, "/", calc)
    mod=Module(gensym(:SymmetryExample));
    Core.eval(mod, :(include(path)=Base.include(@__MODULE__, path)))
    Base.include(mod, joinpath(ROOT, "examples/tasks", string(calc), string(q, "_", m, ".jl")))
    template=Base.invokelatest(
        mod.build_config;
        k_mesh = (3, 3),
        output_root = mktempdir(),
        progress_enabled = false,
    )
    for (name, model) in (("tb", native), ("analytic", analytic))
        try
            artifact=write_native_response_symmetry(
                joinpath(outroot, string(index, "-", name, ".json")),
                model,
                operations,
            )
            outputs=[]
            for mode in ("full", "reduced")
                cfg=TaskConfig(
                    model = model,
                    sampling = template.sampling,
                    tasks = template.tasks,
                    execution = ExecutionOptions(
                        fourier_backend = "direct",
                        response_symmetry_file = artifact,
                        response_symmetry_report_enabled = true,
                        response_symmetry_kmesh_mode = mode,
                    ),
                    output = OutputOptions(
                        output_root = joinpath(outroot, string(index), name, mode),
                        response_output_digits = 16,
                        progress_enabled = false,
                    ),
                )
                result=Base.invokelatest(WannierNLQG.run, cfg)
                leaves=isempty(result.task_results) ? (result,) : result.task_results
                for leaf in leaves
                    summary=JSON3.read(
                        read(joinpath(leaf.run_dir, "response_symmetry_summary.json"), String),
                    )
                    @test summary.status == "COMPUTATION_READY"
                    @test summary.schema == "wanniernlqg.response-symmetry-summary/2.0"
                    @test summary.model_binding == "complete_definition_byte_comparison/1"
                    @test !haskey(summary, :artifact_sha256) && !haskey(summary, :model_sha256)
                    @test !summary.production_eligible
                    @test !("FINITE_MODEL_NOT_MATERIAL_QUALIFIED" in summary.warnings)
                end
                push!(outputs, filter(p->endswith(p, ".dat"), result.outputs))
            end
            @test length(outputs[1])==length(outputs[2])>0
            for (a, b) in zip(outputs...)
                @test numbers(a) ≈ numbers(b) atol=1e-10 rtol=1e-8
            end
            println("PASS_SYMMETRY ", name, " ", label)
        catch exception
            push!(failures, name*"/"*label)
            println("FAIL_SYMMETRY ", name, " ", label, " ", sprint(showerror, exception))
        end
        flush(stdout)
    end
end
println("SYMMETRY_DONE ", failures)
isempty(failures)||error("symmetry comparisons failed")
@testset "Native symmetry rejects invalid qualification" begin
    fixture=Module(gensym(:SymmetryNegative));
    Core.eval(fixture, :(include(path)=Base.include(@__MODULE__, path)))
    Base.include(fixture, joinpath(ROOT, "examples/tasks/integral/shift_current_conventional.jl"))
    template=Base.invokelatest(
        fixture.build_config;
        k_mesh = (3, 3),
        output_root = mktempdir(),
        progress_enabled = false,
    )
    function configured(model, artifact)
        TaskConfig(
            model = model,
            sampling = template.sampling,
            tasks = template.tasks,
            execution = ExecutionOptions(
                fourier_backend = "direct",
                response_symmetry_file = artifact,
                response_symmetry_report_enabled = true,
                response_symmetry_kmesh_mode = "reduced",
            ),
            output = OutputOptions(output_root = mktempdir(), progress_enabled = false),
        )
    end
    function rejection(config)
        try
            Base.invokelatest(WannierNLQG.run, config)
            return "NOT_REJECTED"
        catch exception
            return sprint(showerror, exception)
        end
    end
    artifact=write_native_response_symmetry(
        joinpath(outroot, "negative-model.json"),
        native,
        operations,
    )
    @test occursin(
        "NATIVE_SYMMETRY_MODEL_DEFINITION_MISMATCH",
        rejection(configured(analytic, artifact)),
    )
    false_time_reversal=PointOrbitalSymmetryOperation(
        rotation_fractional = Matrix{Int}(I, 3, 3),
        antiunitary = true,
        representation = Matrix{ComplexF64}(I, 4, 4),
    )
    bad=write_native_response_symmetry(
        joinpath(outroot, "negative-operation.json"),
        native,
        [first(operations), false_time_reversal],
    )
    @test occursin("covariance", rejection(configured(native, bad)))
    bounded=AnalyticKInput(
        hamiltonian = ham,
        num_orbitals = 4,
        lattice = lat,
        orbital_positions = tau,
        operators = (spin = spin,),
        parameters = params,
        periodic = false,
        source_file = @__FILE__
    )
    @test_throws ArgumentError write_native_response_symmetry(
        joinpath(outroot, "bounded.json"),
        bounded,
        operations,
    )
    @test_throws ArgumentError PointOrbitalSymmetryOperation(
        rotation_fractional = Matrix{Int}(I, 3, 3),
        representation = 2Matrix{ComplexF64}(I, 4, 4),
    )
    # A square-lattice rotation is valid for the model, but not for a 3 x 4 mesh.
    square_model=RealSpaceTBInput(
        lattice = lat,
        r_vectors = zeros(Int, 3, 1),
        hamiltonian_r = reshape(Matrix(Diagonal([-1.4, -0.8, 0.9, 1.6])), 4, 4, 1),
        orbital_positions = zeros(3, 4),
    )
    quarter=[0 -1 0; 1 0 0; 0 0 1]
    square_operations=[
        PointOrbitalSymmetryOperation(
            rotation_fractional = quarter^j,
            representation = Matrix{ComplexF64}(I, 4, 4),
        ) for j in 0:3
    ]
    square_artifact=write_native_response_symmetry(
        joinpath(outroot, "nonclosed-grid.json"),
        square_model,
        square_operations,
    )
    nonclosed=TaskConfig(
        model = square_model,
        sampling = BZMesh(k_mesh = (3, 4), spatial_dimension = 2),
        tasks = template.tasks,
        execution = ExecutionOptions(
            fourier_backend = "direct",
            response_symmetry_file = square_artifact,
            response_symmetry_kmesh_mode = "reduced",
        ),
        output = OutputOptions(output_root = mktempdir(), progress_enabled = false),
    )
    @test occursin("mesh", lowercase(rejection(nonclosed)))
    # This perturbation and its first two jets vanish on a 3-point mesh,
    # but break time reversal at the Projector stencil offsets.
    perturbation=kron(Matrix{ComplexF64}(I, 2, 2), ComplexF64[1 0; 0 -1])
    offset_hamiltonian(k, p)=ham(k, p)+1e12*(1-cos(9k[1]))^2*perturbation
    offset_model=AnalyticKInput(
        hamiltonian = offset_hamiltonian,
        num_orbitals = 4,
        lattice = lat,
        orbital_positions = tau,
        operators = (spin = spin,),
        parameters = params,
        source_file = @__FILE__
    )
    offset_artifact=write_native_response_symmetry(
        joinpath(outroot, "offset-broken.json"),
        offset_model,
        operations,
    )
    projector_fixture=Module(gensym(:OffsetNegative));
    Core.eval(projector_fixture, :(include(path)=Base.include(@__MODULE__, path)))
    Base.include(
        projector_fixture,
        joinpath(ROOT, "examples/tasks/integral/shift_current_projector.jl"),
    )
    projector_template=Base.invokelatest(
        projector_fixture.build_config;
        k_mesh = (3, 3),
        output_root = mktempdir(),
        progress_enabled = false,
    )
    offset_cfg=TaskConfig(
        model = offset_model,
        sampling = projector_template.sampling,
        tasks = projector_template.tasks,
        execution = ExecutionOptions(
            fourier_backend = "direct",
            response_symmetry_file = offset_artifact,
            response_symmetry_report_enabled = true,
            response_symmetry_kmesh_mode = "reduced",
        ),
        output = OutputOptions(output_root = mktempdir(), progress_enabled = false),
    )
    @test occursin("covariance", rejection(offset_cfg))
end

@testset "Nontrivial unitary reduction with nonzero allowed response" begin
    for name in ("real_space_tb", "periodic_analytic")
        tutorial=Module(gensym(:UnitaryTutorial));
        Core.eval(tutorial, :(include(path)=Base.include(@__MODULE__, path)))
        Base.include(tutorial, joinpath(ROOT, "examples/native_models", name*".jl"))
        model=Base.invokelatest(tutorial.build_model)
        operations2=[
            PointOrbitalSymmetryOperation(
                rotation_fractional = Matrix{Int}(I, 3, 3),
                representation = Matrix{ComplexF64}(I, 2, 2),
            ),
            PointOrbitalSymmetryOperation(
                rotation_fractional = diagm([1, -1, 1]),
                representation = Matrix{ComplexF64}(I, 2, 2),
            ),
        ]
        artifact=write_native_response_symmetry(
            joinpath(outroot, "mirror-"*name*".json"),
            model,
            operations2,
        )
        template=Base.invokelatest(
            tutorial.shift_config,
            model,
            BZMesh(k_mesh = (3, 3), spatial_dimension = 2),
            mktempdir(),
        )
        tables=[]
        for mode in ("full", "reduced")
            cfg=TaskConfig(
                model = model,
                sampling = template.sampling,
                tasks = template.tasks,
                execution = ExecutionOptions(
                    fourier_backend = "direct",
                    response_symmetry_file = artifact,
                    response_symmetry_report_enabled = true,
                    response_symmetry_kmesh_mode = mode,
                ),
                output = OutputOptions(
                    output_root = mktempdir(),
                    progress_enabled = false,
                    response_output_digits = 16,
                ),
            )
            result=Base.invokelatest(WannierNLQG.run, cfg)
            file=only(filter(path->endswith(path, ".dat"), result.outputs))
            rows=[
                parse.(Float64, split(line)) for
                line in eachline(file) if !isempty(strip(line)) && !startswith(strip(line), "#")
            ]
            @test maximum(abs(row[3]) for row in rows)>1e-12
            @test maximum(maximum(abs, row[5:end]) for row in rows)<1e-10
            push!(tables, reduce(vcat, rows))
        end
        @test tables[1] ≈ tables[2] atol=1e-10 rtol=1e-8
    end
end

@testset "Native symmetry adopts complete definitions without certificates" begin
    io_layer = WannierNLQG.IO
    directory = mktempdir()
    path = joinpath(directory, "symmetry.json")
    write_native_response_symmetry(path, native, operations)
    payload = JSON3.read(read(path, String), Dict{String, Any})
    @test payload["schema"] == io_layer.NATIVE_RESPONSE_SYMMETRY_SCHEMA
    @test !haskey(payload, "model_sha256")
    first_definition = joinpath(directory, payload["model_definition"]["file"])
    artifact = io_layer.read_native_response_symmetry(path)
    @test io_layer.validate_native_response_symmetry_model(artifact, native) === nothing
    @test io_layer.validate_native_response_symmetry_model(artifact, deepcopy(native)) === nothing
    changed = copy(h)
    changed[1, 1, 1] = nextfloat(real(changed[1, 1, 1]))
    one_ulp = RealSpaceTBInput(;
        lattice = lat,
        r_vectors = rv,
        hamiltonian_r = changed,
        orbital_positions = tau,
        position_model = :point_orbitals,
        operators = (spin = spin,),
    )
    @test_throws ArgumentError io_layer.validate_native_response_symmetry_model(artifact, one_ulp)
    retired = deepcopy(native)
    C.invalidate_scientific_data!(retired)
    @test_throws ArgumentError io_layer.validate_native_response_symmetry_model(artifact, retired)
    copied_directory = mktempdir()
    copied_path = joinpath(copied_directory, "copied.json")
    cp(path, copied_path)
    cp(first_definition, joinpath(copied_directory, basename(first_definition)))
    @test io_layer.validate_native_response_symmetry_model(
        io_layer.read_native_response_symmetry(copied_path),
        native,
    ) === nothing
    # Select a body byte after the version and backend lines. A hardcoded offset
    # can instead damage the version header when its encoding revision changes.
    definition_bytes = read(first_definition)
    version_end = findfirst(==(UInt8('\n')), definition_bytes)
    backend_end = findnext(==(UInt8('\n')), definition_bytes, version_end + 1)
    @assert backend_end !== nothing && backend_end < length(definition_bytes)
    body_offset = backend_end # seek uses zero-based offsets: first byte after newline.
    open(first_definition, "r+") do stream
        seek(stream, body_offset)
        original = read(stream, UInt8)
        seek(stream, body_offset)
        write(stream, xor(original, UInt8(1)))
    end
    @test_throws ArgumentError io_layer.validate_native_response_symmetry_source(artifact)
    changed_artifact = io_layer.read_native_response_symmetry(path)
    @test_throws ArgumentError io_layer.validate_native_response_symmetry_model(
        changed_artifact,
        native,
    )
    # Header corruption is a separate, deliberately early reader rejection.
    bad_header_file = joinpath(directory, "bad-header.definition")
    cp(first_definition, bad_header_file)
    open(bad_header_file, "r+") do stream
        original = read(stream, UInt8)
        seekstart(stream)
        write(stream, xor(original, UInt8(1)))
    end
    bad_header_payload = deepcopy(payload)
    bad_header_payload["model_definition"]["file"] = basename(bad_header_file)
    bad_header_path = joinpath(directory, "bad-header.json")
    write(bad_header_path, JSON3.write(bad_header_payload))
    @test_throws ArgumentError io_layer.read_native_response_symmetry(bad_header_path)
    write_native_response_symmetry(path, native, operations)
    fresh = JSON3.read(read(path, String), Dict{String, Any})
    @test fresh["model_definition"]["file"] != payload["model_definition"]["file"]
    @test isfile(first_definition)
    @test_throws ArgumentError io_layer.validate_native_response_symmetry_source(changed_artifact)
    old_schema = deepcopy(fresh)
    old_schema["schema"] = "wanniernlqg.point-orbital-response-symmetry/1.0"
    write(path, JSON3.write(old_schema))
    @test_throws ArgumentError io_layer.read_native_response_symmetry(path)
    invalid = deepcopy(fresh)
    invalid["model_definition"]["file"] = "../outside"
    write(path, JSON3.write(invalid))
    @test_throws ArgumentError io_layer.read_native_response_symmetry(path)
    invalid = deepcopy(fresh)
    invalid["model_definition"]["bytes"] += 1
    write(path, JSON3.write(invalid))
    @test_throws ArgumentError io_layer.read_native_response_symmetry(path)
    invalid = deepcopy(fresh)
    invalid["model_sha256"] = repeat("a", 64)
    write(path, JSON3.write(invalid))
    @test_throws ArgumentError io_layer.read_native_response_symmetry(path)
    write(path, JSON3.write(fresh))
    symlink(
        joinpath(directory, fresh["model_definition"]["file"]),
        joinpath(directory, "linked-definition"),
    )
    invalid = deepcopy(fresh)
    invalid["model_definition"]["file"] = "linked-definition"
    write(path, JSON3.write(invalid))
    @test_throws ArgumentError io_layer.read_native_response_symmetry(path)
    write(path, JSON3.write(fresh))
    artifact = io_layer.read_native_response_symmetry(path)
    open(artifact.definition_path, "a") do stream
        write(stream, UInt8(0))
    end
    @test_throws ArgumentError io_layer.validate_native_response_symmetry_source(artifact)
    @test_throws ArgumentError io_layer.read_native_response_symmetry(path)
end

end
