module ReleaseWhitelistFixture

include(joinpath(@__DIR__, "..", "scripts", "check_release_whitelist.jl"))

end

@testset "release gate accepts Git metadata and keeps rejecting unknown payload" begin
    mktempdir() do directory
        for name in ReleaseWhitelistFixture.ALLOWED_TOP_LEVEL
            if name in (".github", "docs", "examples", "ext", "scripts", "src", "test", "theory")
                mkdir(joinpath(directory, name))
            else
                write(joinpath(directory, name), "")
            end
        end
        write(joinpath(directory, "Project.toml"), "version = \"1.0.0\"\n")
        for name in ReleaseWhitelistFixture.ALLOWED_SCRIPT_FILES
            path = joinpath(directory, "scripts", name)
            mkpath(dirname(path))
            write(path, "")
        end
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
