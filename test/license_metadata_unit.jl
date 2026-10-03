module LicenseMetadataFixture

include(joinpath(@__DIR__, "..", "scripts", "check_version_consistency.jl"))

end

@testset "response-symmetry summary documentation keeps the /1.0 marker" begin
    mktempdir() do directory
        documentation_directory = joinpath(directory, "docs")
        mkpath(documentation_directory)
        documentation_path = joinpath(documentation_directory, "STORAGE_SCHEMAS.md")
        cp(joinpath(ROOT, "docs", "STORAGE_SCHEMAS.md"), documentation_path)
        @test LicenseMetadataFixture.check_response_summary_schema_documentation(directory)

        source = read(documentation_path, String)
        marker = LicenseMetadataFixture.RESPONSE_SUMMARY_SCHEMA_DOCUMENTATION_MARKER
        occursin(marker, source) || error("test schema documentation marker is missing")
        write(documentation_path, replace(source, marker => replace(marker, "/1.0" => "/1.1")))
        @test_throws ErrorException LicenseMetadataFixture.check_response_summary_schema_documentation(
            directory,
        )
    end
end

const LICENSE_METADATA_FILES =
    ("LICENSE", "CITATION.cff", "README.md", "CONTRIBUTING.md", "THIRD_PARTY_NOTICE.md")

function with_license_metadata_fixture(f::Function)
    mktempdir() do directory
        for relative_path in LICENSE_METADATA_FILES
            cp(joinpath(ROOT, relative_path), joinpath(directory, relative_path))
        end
        f(directory)
    end
end

function replace_license_fixture_marker(
    directory::AbstractString,
    relative_path::AbstractString,
    old::AbstractString,
    new::AbstractString,
)
    path = joinpath(directory, relative_path)
    source = read(path, String)
    occursin(old, source) || error("test fixture marker is missing: $(old)")
    write(path, replace(source, old => new))
    return nothing
end

@testset "GPL-2.0-only release metadata is exact and mutually consistent" begin
    with_license_metadata_fixture() do directory
        @test LicenseMetadataFixture.check_license_metadata(directory)
    end

    with_license_metadata_fixture() do directory
        open(joinpath(directory, "LICENSE"), "a") do io
            write(io, '\n')
        end
        @test_throws ErrorException LicenseMetadataFixture.check_license_metadata(directory)
    end

    with_license_metadata_fixture() do directory
        replace_license_fixture_marker(
            directory,
            "CITATION.cff",
            "license: GPL-2.0-only",
            "license: MIT",
        )
        @test_throws ErrorException LicenseMetadataFixture.check_license_metadata(directory)
    end

    with_license_metadata_fixture() do directory
        replace_license_fixture_marker(directory, "README.md", "GPL-2.0-only", "GPL-2.0-or-later")
        @test_throws ErrorException LicenseMetadataFixture.check_license_metadata(directory)
    end

    with_license_metadata_fixture() do directory
        path = joinpath(directory, "README.md")
        write(path, read(path, String) * "\n[MIT License](LICENSE)\n")
        @test_throws ErrorException LicenseMetadataFixture.check_license_metadata(directory)
    end

    with_license_metadata_fixture() do directory
        replace_license_fixture_marker(directory, "CONTRIBUTING.md", "GPL-2.0-only", "GPL-2.0")
        @test_throws ErrorException LicenseMetadataFixture.check_license_metadata(directory)
    end

    with_license_metadata_fixture() do directory
        replace_license_fixture_marker(
            directory,
            "THIRD_PARTY_NOTICE.md",
            "remain under their respective licenses",
            "have unspecified licensing",
        )
        @test_throws ErrorException LicenseMetadataFixture.check_license_metadata(directory)
    end
end
