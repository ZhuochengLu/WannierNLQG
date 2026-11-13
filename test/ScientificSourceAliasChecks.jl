using Test
@testset "Scientific source aliases retain one actual file lifetime" begin
    io = WannierNLQG.IO
    mktempdir() do directory
        parent = joinpath(directory, "source")
        alternate = joinpath(directory, "alternate")
        mkpath(parent);
        mkpath(alternate)
        file = joinpath(parent, "data")
        write(file, "actual scientific source")
        write(joinpath(alternate, "data"), "replacement scientific source")
        alias = joinpath(directory, "parent-alias")
        symlink(parent, alias; dir_target = true)
        declared = joinpath(alias, "data")
        state = io.scientific_file_state(declared)
        @test state.path == realpath(file)
        @test isnothing(io.validate_scientific_source_state(state; declared_path = declared))
        @test io.with_scientific_source(read, declared).value == read(file)
        link = joinpath(directory, "file-alias")
        symlink(file, link)
        @test_throws ArgumentError io.scientific_file_state(link)
        @test_throws ArgumentError io.with_scientific_source(declared) do observed
            bytes = read(observed)
            rm(alias)
            symlink(alternate, alias; dir_target = true)
            bytes
        end
        @test_throws ArgumentError io.validate_scientific_source_state(
            state;
            declared_path = declared,
        )
        write(file, "changed bytes and file size")
        @test_throws ArgumentError io.validate_scientific_source_state(state; declared_path = file)
        rm(file)
        @test_throws ArgumentError io.validate_scientific_source_state(state)
    end
end
