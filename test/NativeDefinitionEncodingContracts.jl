module NativeDefinitionEncodingTests
using WannierNLQG, Test, LinearAlgebra, JSON3
const IOModel=WannierNLQG.IO
const CoreModel=WannierNLQG.Core
function value_bytes(value; version = 2)
    io=IOBuffer();
    IOModel.write_native_definition_value(io, value; definition_version = version);
    take!(io)
end
function model_bytes(model; version = 2)
    io=IOBuffer();
    IOModel.write_native_model_definition(io, model; definition_version = version);
    take!(io)
end
capture(value)=(k, p)->ComplexF64[value 0; 0 -value]
struct BitsStyle
    number::Float64
    flag::UInt8
end
struct LiteralFunction{Style} <: Function end
(::LiteralFunction)(k, p)=ComplexF64[0.4 0; 0 -0.4]
function compare_worlds()
    namespace=Module(gensym(:NativeEncodingBoundary))
    Core.eval(namespace, :(callback(k, p)=ComplexF64[0.4 0; 0 -0.4]))
    callback=Base.invokelatest(getproperty, namespace, :callback)
    old=value_bytes(callback; version = 1)
    latest=Base.invokelatest(value_bytes, callback; version = 1)
    stable=value_bytes(callback)
    stable_latest=Base.invokelatest(value_bytes, callback)
    return (; old, latest, stable, stable_latest)
end
@testset "Stable native type encoding and legacy boundary" begin
    boundary=compare_worlds()
    @test boundary.stable==boundary.stable_latest
    @test !isempty(boundary.stable)
    @test value_bytes(0.5; version = 1)==collect(codeunits("Float64:0.5;"))
    for value in (0.5, (1, :a), BitMatrix([true false; false true]), [1.0, 2.0])
        io=IOBuffer();
        IOModel.write_native_definition_value(io, value)
        @test take!(io)==value_bytes(value; version = 1)
    end
    @test value_bytes((x = 1,))!=value_bytes((y = 1,))
    @test value_bytes([1.0, 2.0])!=value_bytes(reshape([1.0, 2.0], 1, 2))
    @test value_bytes(0.0)!=value_bytes(-0.0)
    @test value_bytes([0.2])!=value_bytes([nextfloat(0.2)])
    @test value_bytes(capture(0.2))!=value_bytes(capture(nextfloat(0.2)))
    @test value_bytes((
        label = "Main.var\"#callback\"",
    ))!=value_bytes((label = "typeof(Main.callback)",))
    @test value_bytes(Dict(:b=>2, :a=>1))==value_bytes(Dict(:a=>1, :b=>2))
    @test value_bytes(
        LiteralFunction{BitsStyle(0.4, 0x01)}(),
    )==value_bytes(LiteralFunction{BitsStyle(0.4, 0x01)}())
    @test value_bytes(
        LiteralFunction{BitsStyle(0.4, 0x01)}(),
    )!=value_bytes(LiteralFunction{BitsStyle(0.4, 0x02)}())
    @test value_bytes(
        Vector{Union{Float64, Nothing}}([0.4, nothing]),
    )==value_bytes(Vector{Union{Nothing, Float64}}([0.4, nothing]))
    @test value_bytes(Vector{Vector}([[0.4]]))==value_bytes(Vector{Vector}([[0.4]]))
    # The v1 value domain includes abstract tuple containers. Stable type encoding
    # must support their Vararg/UnionAll parameters without widening value kinds.
    for value in (
        Tuple[(1, 2.0), (3,)],
        NamedTuple[(x = 1,), (y = 2.0,)],
        Tuple{Vararg{Float64}}[(1.0,), (2.0, 3.0)],
        Dict{Symbol, Tuple}(:a => (1, 2.0)),
    )
        @test !isempty(value_bytes(value; version = 1))
        @test !isempty(value_bytes(value))
        @test value_bytes(value) == value_bytes(deepcopy(value))
    end
    @test value_bytes(Tuple[(1,)]) != value_bytes(Tuple{Int}[(1,)])
    @test value_bytes(Tuple[(1.0,)]) != value_bytes(Tuple[(nextfloat(1.0),)])
    @test_throws ArgumentError value_bytes(Ref(1))
    @test_throws ArgumentError value_bytes(1; version = 3)
    mktempdir() do directory
        h=reshape(ComplexF64[0.4, 0.2, 0.2, -0.4], 2, 2, 1)
        model=RealSpaceTBInput(
            lattice = Matrix{Float64}(I, 3, 3),
            r_vectors = zeros(Int, 3, 1),
            hamiltonian_r = h,
            orbital_positions = zeros(3, 2),
            position_model = :point_orbitals,
            parameters = (control = [1.0, 2.0],),
        )
        operations=[
            PointOrbitalSymmetryOperation(
                rotation_fractional = Matrix{Int}(I, 3, 3),
                representation = Matrix{ComplexF64}(I, 2, 2),
            ),
        ]
        current=joinpath(directory, "current.json")
        write_native_response_symmetry(current, model, operations)
        payload=JSON3.read(read(current, String), Dict{String, Any})
        @test payload["model_definition"]["schema"]=="wanniernlqg.native-model-definition/2"
        artifact=IOModel.read_native_response_symmetry(current)
        @test artifact.definition_version==2
        @test IOModel.validate_native_response_symmetry_model(artifact, model)===nothing
        @test IOModel.validate_native_response_symmetry_model(artifact, deepcopy(model))===nothing
        legacy=joinpath(directory, "legacy.json");
        legacy_file=joinpath(directory, "legacy.definition")
        write(legacy_file, model_bytes(model; version = 1))
        old=deepcopy(payload);
        old["model_definition"]=Dict(
            "schema"=>"wanniernlqg.native-model-definition/1",
            "file"=>basename(legacy_file),
            "bytes"=>filesize(legacy_file),
        )
        write(legacy, JSON3.write(old));
        old_artifact=IOModel.read_native_response_symmetry(legacy)
        @test old_artifact.definition_version==1
        @test IOModel.validate_native_response_symmetry_model(old_artifact, model)===nothing
        compatibility=IOModel.NativeResponseSymmetryArtifact(
            old_artifact.source_path,
            old_artifact.source_state,
            old_artifact.definition_path,
            old_artifact.definition_state,
            old_artifact.operations,
        )
        @test IOModel.validate_native_response_symmetry_model(compatibility, model)===nothing
        relabeled=deepcopy(old);
        relabeled["model_definition"]["schema"]="wanniernlqg.native-model-definition/2"
        relabeled_file=joinpath(directory, "relabeled.json");
        write(relabeled_file, JSON3.write(relabeled))
        @test_throws ArgumentError IOModel.read_native_response_symmetry(relabeled_file)
        unknown=deepcopy(payload);
        unknown["model_definition"]["schema"]="wanniernlqg.native-model-definition/3"
        unknown_file=joinpath(directory, "unknown.json");
        write(unknown_file, JSON3.write(unknown))
        @test_throws ArgumentError IOModel.read_native_response_symmetry(unknown_file)
        changed=copy(h);
        changed[1]=nextfloat(real(changed[1]))+0im
        other=RealSpaceTBInput(
            lattice = Matrix{Float64}(I, 3, 3),
            r_vectors = zeros(Int, 3, 1),
            hamiltonian_r = changed,
            orbital_positions = zeros(3, 2),
            position_model = :point_orbitals,
            parameters = (control = [1.0, 2.0],),
        )
        @test_throws ArgumentError IOModel.validate_native_response_symmetry_model(artifact, other)
        @test_throws ArgumentError IOModel.validate_native_response_symmetry_model(
            old_artifact,
            other,
        )
        retired=deepcopy(model);
        CoreModel.invalidate_scientific_data!(retired)
        @test_throws ArgumentError IOModel.validate_native_response_symmetry_model(
            artifact,
            retired,
        )
        open(artifact.definition_path, "a") do io
            write(io, UInt8(0))
        end
        @test_throws ArgumentError IOModel.validate_native_response_symmetry_source(artifact)
        @test_throws ArgumentError IOModel.read_native_response_symmetry(current)
    end
end
end
