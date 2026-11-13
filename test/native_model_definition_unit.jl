module NativeModelDefinitionUnit
using Test, LinearAlgebra, SHA, WannierNLQG
const C = WannierNLQG.Core
const IOLayer = WannierNLQG.IO

# Frozen source013 is the historical v1 byte contract, never a runtime reader.
# Current stable-type encoding is tested separately; do not compare new-version bytes
# with this historical digest or weaken either version's exact comparison.
module PreviousNativeBinding
using SHA
using WannierNLQG.Core
import WannierNLQG.IO: scientific_file_identity
include(joinpath(@__DIR__, "reference", "NativeModelProvenanceBeforeStreaming.jl"))
end

@testset "Legacy v1 native definition streams preserve complete original bindings" begin
    lattice = Matrix{Float64}(I, 3, 3)
    translations = [0 1 -1; 0 0 0; 0 0 0]
    hopping = zeros(ComplexF64, 2, 2, 3)
    hopping[:, :, 1] = [0.4 0.2; 0.2 -0.4]
    hopping[:, :, 2] = [0.0 0.0; 0.1 0.0]
    hopping[:, :, 3] = hopping[:, :, 2]'
    positions = [0.0 0.3; 0.0 0.0; 0.0 0.0]
    real_space = RealSpaceTBInput(
        lattice = lattice,
        r_vectors = translations,
        hamiltonian_r = hopping,
        orbital_positions = positions,
        position_model = :point_orbitals,
        parameters = (label = "owned", values = [1.0, -0.0, 3.0]),
    )
    captured = ComplexF64[0.4 0.2; 0.2 -0.4]
    callback = let coefficients = captured
        (k, parameters) -> coefficients
    end
    analytic = AnalyticKInput(
        hamiltonian = callback,
        num_orbitals = 2,
        lattice = lattice,
        basis = :fixed_orthonormal,
        source_file = @__FILE__,
        parameters = Dict("coefficient" => [1.0, 2.0], "description" => "ordered parameters"),
    )
    metric = C.NonorthogonalLocalizedModel(
        lattice = lattice,
        r_vectors = zeros(Int, 3, 1),
        hamiltonian_r = reshape(ComplexF64[0.4, 0.2, 0.2, -0.4], 2, 2, 1),
        overlap_r = reshape(Matrix{ComplexF64}(I, 2, 2), 2, 2, 1),
        position_r = nothing,
    )
    localized = C.NonorthogonalLocalizedInput(metric; parameters = (units = "eV",))
    for input in (real_space, analytic, localized)
        expected = PreviousNativeBinding.native_model_digest(input)
        buffer = IOBuffer()
        @test IOLayer.write_native_model_definition(buffer, input; definition_version = 1) ===
              nothing
        bytes = take!(buffer)
        @test !isempty(bytes)
        @test bytes2hex(SHA.sha256(bytes)) == expected
        mktemp() do path, stream
            IOLayer.write_native_model_definition(stream, input; definition_version = 1)
            flush(stream)
            @test read(path) == bytes
        end
        definition = IOLayer.native_model_definition_stream(input; definition_version = 1)
        path = definition.path
        @test definition.byte_count == length(bytes)
        consumed = UInt8[]
        while !eof(definition)
            append!(consumed, read(definition, min(17, definition.byte_count - length(consumed))))
        end
        @test consumed == bytes
        @test bytes2hex(SHA.sha256(consumed)) == expected
        close(definition)
        @test !ispath(path)
        changed_definition = IOLayer.native_model_definition_stream(input; definition_version = 1)
        open(changed_definition.path, "a") do stream
            write(stream, UInt8(0))
        end
        @test_throws ArgumentError read(changed_definition, 1)
        close(changed_definition; retain = true)
        @test isfile(changed_definition.path)
    end
    changed_hopping = copy(hopping)
    changed_hopping[1, 1, 1] = nextfloat(real(changed_hopping[1, 1, 1]))
    changed = RealSpaceTBInput(
        lattice = lattice,
        r_vectors = translations,
        hamiltonian_r = changed_hopping,
        orbital_positions = positions,
        position_model = :point_orbitals,
        parameters = (label = "owned", values = [1.0, -0.0, 3.0]),
    )
    original_stream = IOBuffer()
    changed_stream = IOBuffer()
    IOLayer.write_native_model_definition(original_stream, real_space)
    IOLayer.write_native_model_definition(changed_stream, changed)
    @test take!(original_stream) != take!(changed_stream)
    C.invalidate_scientific_data!(real_space)
    @test_throws ArgumentError IOLayer.write_native_model_definition(IOBuffer(), real_space)
end
end

include(joinpath(@__DIR__, "NativeDefinitionEncodingContracts.jl"))
