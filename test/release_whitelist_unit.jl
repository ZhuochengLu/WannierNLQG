module ReleaseWhitelistFixture

include(joinpath(@__DIR__, "..", "scripts", "check_release_whitelist.jl"))

end

@testset "release gate accepts Git metadata and keeps rejecting unknown payload" begin
    mktempdir() do directory
        for name in
            union(ReleaseWhitelistFixture.CLASSIFIED_PATHS, ReleaseWhitelistFixture.GENERATED_PATHS)
            path = joinpath(directory, name)
            mkpath(dirname(path))
            write(path, "")
        end
        write(joinpath(directory, "Project.toml"), "version = \"1.0.0\"\n")
        @test ReleaseWhitelistFixture.check_release_whitelist(directory)
        mkdir(joinpath(directory, ".git"))
        write(joinpath(directory, ".git", "config"), "not public source")
        @test ReleaseWhitelistFixture.check_release_whitelist(directory)
        rm(joinpath(directory, ".git"); recursive = true)
        write(joinpath(directory, ".git"), "gitdir: ../administration\n")
        @test ReleaseWhitelistFixture.check_release_whitelist(directory)
        write(joinpath(directory, "unknown.txt"), "unexpected")
        @test_throws ErrorException ReleaseWhitelistFixture.check_release_whitelist(directory)
        rm(joinpath(directory, "unknown.txt"))
        for part in ("src", "docs", "ext", "test", "examples")
            path = joinpath(directory, part, "unclassified.txt")
            write(path, "unexpected")
            @test_throws ErrorException ReleaseWhitelistFixture.check_release_whitelist(directory)
            rm(path)
        end
        write(joinpath(directory, "src", "unfinished.tmp"), "generated")
        @test_throws ErrorException ReleaseWhitelistFixture.check_release_whitelist(directory)
        rm(joinpath(directory, "src", "unfinished.tmp"))
        symlink(joinpath(directory, "Project.toml"), joinpath(directory, "src", "link.jl"))
        @test_throws ErrorException ReleaseWhitelistFixture.check_release_whitelist(directory)
    end
end

@testset "release inventory excludes only root Git administration" begin
    mktempdir() do directory
        write(joinpath(directory, "Project.toml"), "version = \"1.0.0\"\n")
        mkdir(joinpath(directory, ".git"))
        write(joinpath(directory, ".git", "config"), "private checkout metadata")
        mkdir(joinpath(directory, "nested"))
        mkdir(joinpath(directory, "nested", ".git"))
        write(joinpath(directory, "nested", ".git", "config"), "must remain visible")
        paths = ReleaseWhitelistFixture.release_paths(directory)
        @test !(".git" in paths)
        @test !(".git/config" in paths)
        @test "nested/.git" in paths
        @test "nested/.git/config" in paths
        rm(joinpath(directory, ".git"); recursive = true)
        write(joinpath(directory, ".git"), "gitdir: ../worktree-administration\n")
        @test !(".git" in ReleaseWhitelistFixture.release_paths(directory))
        rm(joinpath(directory, ".git"))
        symlink(joinpath(directory, "Project.toml"), joinpath(directory, ".git"))
        @test ".git" in ReleaseWhitelistFixture.release_paths(directory)
    end
end

@testset "release scripts whitelist rejects additions and removals" begin
    allowed = ReleaseWhitelistFixture.ALLOWED_SCRIPT_FILES
    exact = ReleaseWhitelistFixture.script_inventory_difference(allowed)
    @test isempty(exact.missing)
    @test isempty(exact.extra)

    with_addition = union(allowed, Set(["unexpected.jl"]))
    added = ReleaseWhitelistFixture.script_inventory_difference(with_addition)
    @test isempty(added.missing)
    @test added.extra == ["unexpected.jl"]

    removed_name = first(sort!(collect(allowed)))
    with_removal = setdiff(allowed, Set([removed_name]))
    removed = ReleaseWhitelistFixture.script_inventory_difference(with_removal)
    @test removed.missing == [removed_name]
    @test isempty(removed.extra)
end

module ReleasePortablePayloadFixture
using JSON3, SHA
include(joinpath(@__DIR__, "fixtures", "first_use_portable", "PortableFixturePayload_v1.jl"))
end

@testset "release fixture transport has current complete file bindings" begin
    transport = ReleasePortablePayloadFixture.PortableFixturePayload
    actual = joinpath(@__DIR__, "fixtures", "first_use_portable")
    # Exercise the actual shipped manifest: stale size/hash records blocked every
    # expert first call even when the outer source inventory was correct.
    @test !isempty(transport.verify_payload(actual).files)
    mktempdir() do directory
        file = joinpath(directory, "sample.dat")
        write(file, "alpha")
        declaration = Dict(
            "schema" => "wanniernlqg.first-use-fixture-payload",
            "schema_version" => "1",
            "files" => [
                Dict(
                    "file" => "sample.dat",
                    "bytes" => 5,
                    "sha256" => bytes2hex(ReleasePortablePayloadFixture.SHA.sha256(read(file))),
                ),
            ],
            "arguments" => Any[],
            "paths" => Dict(),
            "expert_entries" => Any[],
        )
        manifest = joinpath(directory, "manifest.json")
        write(manifest, ReleasePortablePayloadFixture.JSON3.write(declaration))
        @test length(transport.verify_payload(directory).files) == 1
        write(file, "bravo") # unchanged length must still reject the changed bytes
        @test_throws ErrorException transport.verify_payload(directory)
        write(file, "alpha")
        declaration["files"][1]["bytes"] = 4
        write(manifest, ReleasePortablePayloadFixture.JSON3.write(declaration))
        @test_throws ErrorException transport.verify_payload(directory)
        rm(file)
        @test_throws ErrorException transport.verify_payload(directory)
    end
end
