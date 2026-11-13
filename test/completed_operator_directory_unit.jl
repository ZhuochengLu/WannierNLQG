using Test

# Load only the filesystem selector, so these tests do not launch science or MPI.
source = read(
    joinpath(
        @__DIR__,
        "..",
        "ext",
        "WannierNLQGWannierizationExt",
        "NativeOperatorOutputGeneration.jl",
    ),
    String,
)
start = findfirst("function _validate_native_restart_output_directory", source)
stop = findnext("\nend\n\n\"\"\"Generate", source, first(start))
eval(Meta.parse(source[first(start):(first(stop) + 3)]))

@testset "completed pair selection" begin
    mktempdir() do root
        directory = joinpath(realpath(root), "native-operators")
        paths = Dict(
            key => joinpath(directory, name) for (key, name) in (
                :uiu_file => "native.uIu",
                :uhu_file => "native.uHu",
                :uiu_provenance_json => "native.uIu.provenance.json",
                :uhu_provenance_json => "native.uHu.provenance.json",
            )
        )
        @test _validate_native_restart_output_directory(directory, paths, true) == :empty
        mkpath(directory)
        for path in values(paths)
            write(path, "fixture")
            endswith(path, ".json") && write(path * ".references.h5", "fixture")
        end
        @test _validate_native_restart_output_directory(directory, paths, true) == :completed_pair
        @test_throws ArgumentError _validate_native_restart_output_directory(
            directory,
            paths,
            false,
        )
        extra_paths = Dict(
            key => joinpath(directory, name) for (key, name) in (
                :spn_file => "native.spn",
                :spn_provenance_file => "native.spn.h5",
                :siu_file => "native.sIu",
                :shu_file => "native.sHu",
                :siu_provenance_json => "native.sIu.provenance.json",
                :shu_provenance_json => "native.sHu.provenance.json",
            )
        )
        merge!(paths, extra_paths)
        for path in values(extra_paths)
            write(path, "fixture")
            endswith(path, ".json") && write(path * ".references.h5", "fixture")
        end
        @test _validate_native_restart_output_directory(directory, paths, true) == :completed_all
        for path in values(extra_paths)
            rm(path)
            endswith(path, ".json") && rm(path * ".references.h5")
        end
        rm(paths[:uiu_file])
        @test_throws ArgumentError _validate_native_restart_output_directory(directory, paths, true)
        write(paths[:uiu_file], "fixture")
        write(joinpath(directory, "unexpected"), "fixture")
        @test_throws ArgumentError _validate_native_restart_output_directory(directory, paths, true)
        rm(joinpath(directory, "unexpected"))
        rm(paths[:uhu_file])
        symlink(paths[:uiu_file], paths[:uhu_file])
        @test_throws ArgumentError _validate_native_restart_output_directory(directory, paths, true)
        rm(directory; recursive = true)
        mkpath(directory)
        write(paths[:uiu_file] * ".partial", "fixture")
        write(paths[:uiu_file] * ".partial.json", "fixture")
        write(paths[:uiu_provenance_json] * ".references.h5", "fixture")
        @test _validate_native_restart_output_directory(directory, paths, true) == :partial
        @test_throws ArgumentError _validate_native_restart_output_directory(
            directory,
            paths,
            false,
        )
    end
end
