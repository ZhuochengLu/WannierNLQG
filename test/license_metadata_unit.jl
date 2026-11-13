module LicenseMetadataFixture

include(joinpath(@__DIR__, "..", "scripts", "check_version_consistency.jl"))

end

@testset "software identity is independent of storage wire versions" begin
    mktempdir() do directory
        path = joinpath(directory, "Project.toml")
        write(path, "version = \"1.2.0\"\n")
        @test LicenseMetadataFixture.check_software_project_version(directory)
        write(path, "version = \"1.2.1-dev\"\n")
        @test_throws ErrorException LicenseMetadataFixture.check_software_project_version(directory)
    end
end

@testset "storage declarations are literal, unique and format-specific" begin
    mktempdir() do directory
        path = joinpath(directory, "Fixture.jl")
        write(path, "const FORMAT = \"2.0\"\n")
        @test LicenseMetadataFixture.check_schema_constant(directory, "Fixture.jl", "FORMAT", "2.0")
        @test_throws ErrorException LicenseMetadataFixture.check_schema_constant(
            directory,
            "Fixture.jl",
            "FORMAT",
            "1.3",
        )
        write(path, "# const FORMAT = \"2.0\"\n")
        @test_throws ErrorException LicenseMetadataFixture.check_schema_constant(
            directory,
            "Fixture.jl",
            "FORMAT",
            "2.0",
        )
        write(path, "const FORMAT = \"2.0\"\nconst FORMAT = \"2.0\"\n")
        @test_throws ErrorException LicenseMetadataFixture.check_schema_constant(
            directory,
            "Fixture.jl",
            "FORMAT",
            "2.0",
        )
        write(path, "const FORMAT = string(2, \".0\")\n")
        @test_throws ErrorException LicenseMetadataFixture.check_schema_constant(
            directory,
            "Fixture.jl",
            "FORMAT",
            "2.0",
        )
        write(path, "module Fixture\nconst FORMAT = \"3.0\"\nend\n")
        @test LicenseMetadataFixture.check_schema_constant(directory, "Fixture.jl", "FORMAT", "3.0")
        write(path, "const READABLE = (\"1.0\",)\n")
        @test LicenseMetadataFixture.check_schema_constant(
            directory,
            "Fixture.jl",
            "READABLE",
            ("1.0",),
        )
        @test_throws ErrorException LicenseMetadataFixture.check_schema_constant(
            directory,
            "Fixture.jl",
            "READABLE",
            ("1.1",),
        )
    end
end

@testset "Band regression registration uses the real inventory consumer" begin
    mktempdir() do directory
        tests = joinpath(directory, "test");
        mkpath(tests)
        file = joinpath(tests, "band_public_schema_unit.jl")
        write(file, "# metadata fixture only\n")
        driver = joinpath(tests, "runtests.jl")
        call = "foreach(include_test_file, CITestPlan.FAST_TEST_FILES)"
        write(driver, call)
        registered = ("band_public_schema_unit.jl",)
        @test LicenseMetadataFixture.check_band_regression_registration(directory, registered)
        @test_throws ErrorException LicenseMetadataFixture.check_band_regression_registration(
            directory,
            (),
        )
        for nonexecuted in ("# " * call, "quote\n" * call * "\nend")
            write(driver, nonexecuted)
            @test_throws ErrorException LicenseMetadataFixture.check_band_regression_registration(
                directory,
                registered,
            )
        end
        write(driver, call);
        rm(file)
        @test_throws ErrorException LicenseMetadataFixture.check_band_regression_registration(
            directory,
            registered,
        )
    end
end

@testset "current model metadata checks the active route and migration boundary" begin
    relative = joinpath("ext", "WannierNLQGOperatorBundleExt")
    extension_name = "WannierNLQGOperatorBundleExt.jl"
    current_name = "CurrentModelFormat.jl"
    extension = read(joinpath(ROOT, relative, extension_name), String)
    current = read(joinpath(ROOT, relative, current_name), String)
    # Each independent copy must reach its intended static metadata rejection.
    mutations = (
        (
            current_name,
            "CURRENT_MODEL_FORMAT_VERSION = \"3.0\"",
            "CURRENT_MODEL_FORMAT_VERSION = \"9.0\"",
        ),
        (extension_name, "include(\"CurrentModelFormat.jl\")", "include(\"WrongModelFormat.jl\")"),
        (
            current_name,
            "(\"schema_version\", CURRENT_MODEL_FORMAT_VERSION)",
            "(\"schema_version\", \"1.3\")",
        ),
        (current_name, "legacy_migration::Bool = false", "legacy_migration::Bool = true"),
        (
            current_name,
            "version==CURRENT_MODEL_FORMAT_VERSION",
            "version in (\"1.1\", CURRENT_MODEL_FORMAT_VERSION)",
        ),
        (current_name, "version in (\"1.1\", \"1.2\", \"1.3\")", "version in (\"1.1\", \"2.0\")"),
        (
            current_name,
            "m=create_group(h, \"model\");",
            "create_group(h, \"software\"); m=create_group(h, \"model\");",
        ),
        (
            current_name,
            "index=create_group(h, \"index\")",
            "index=create_group(h, \"missing_index\")",
        ),
    )
    mktempdir() do directory
        destination = joinpath(directory, relative);
        mkpath(destination)
        write(joinpath(destination, extension_name), extension)
        write(joinpath(destination, current_name), current)
        @test LicenseMetadataFixture.check_current_model_format(directory)
        for (name, old, new) in mutations
            original = name == extension_name ? extension : current
            @test length(findall(old, original)) == 1
            altered = replace(original, old => new; count = 1)
            @test altered != original && occursin(new, altered)
            write(joinpath(destination, name), altered)
            @test read(joinpath(destination, name), String) == altered
            @test_throws ErrorException LicenseMetadataFixture.check_current_model_format(directory)
            write(joinpath(destination, name), original)
        end
    end
end

@testset "response-symmetry summary documentation keeps the /1.0 marker" begin
    mktempdir() do directory
        documentation_directory = joinpath(directory, "docs")
        mkpath(documentation_directory)
        documentation_path = joinpath(documentation_directory, "STORAGE_SCHEMAS.md")
        cp(joinpath(ROOT, "docs", "STORAGE_SCHEMAS.md"), documentation_path)
        chmod(documentation_path, 0o600)
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
            chmod(joinpath(directory, relative_path), 0o600)
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
