using Test
module SourceFixture
using SHA
include("../src/IO/ScientificSourceFiles.jl")
include("../src/IO/ScientificInputDefinitions.jl")
include("../src/IO/ScientificInputReferences.jl")
end

@testset "operator source identity" begin
    mktempdir() do dir
        source = joinpath(dir, "WAVECAR")
        write(source, "source-01")
        files = Dict("WAVECAR" => source)
        saved = SourceFixture.scientific_source_collection_definition(files; directory = dir)
        @test SourceFixture.validate_scientific_source_collection(files, saved) === nothing
        write(source, "source-02")
        @test_throws ArgumentError SourceFixture.validate_scientific_source_collection(files, saved)
        rm(source)
        @test_throws Exception SourceFixture.validate_scientific_source_collection(files, saved)
    end
end
