module CurrentFixtureContractUnit
using HDF5
include("OperatorBundleTestSupport.jl")
using Test, WannierNLQG, TOML, SHA, JSON3
include(joinpath(@__DIR__, "fixtures", "first_use_portable", "PortableFixturePayload_v1.jl"))

@testset "Current portable payload declarations and expert publication boundary" begin
    root = normpath(joinpath(@__DIR__, ".."))
    payload = joinpath(@__DIR__, "fixtures", "first_use_portable")
    manifest = PortableFixturePayload.verify_payload(payload)
    @test !isempty(manifest.files)
    @test isempty(manifest.arguments) && isempty(manifest.expert_entries)
    mktempdir() do directory
        damaged = joinpath(directory, "payload")
        cp(payload, damaged)
        open(joinpath(damaged, "assets", "frozen_solver", "synthetic.eig"), "a") do stream
            write(stream, "# deliberately changed transport helper\n")
        end
        @test_throws ErrorException PortableFixturePayload.verify_payload(damaged)
    end
    contract = TOML.parsefile(joinpath(@__DIR__, "contracts", "wannierization_components.toml"))
    # The actual boundary checker validates every component and its imports. This
    # test keeps the retired persistence API out of the current expert contract.
    text = read(joinpath(@__DIR__, "contracts", "wannierization_components.toml"), String)
    @test !occursin("bind_packed_checkpoint_sha256!", text)
    @test occursin("bind_packed_checkpoint_publication!", text)
    checker = joinpath(root, "scripts", "check_structure_boundaries.jl")
    compiled_modules = VERSION < v"1.11" ? "--compiled-modules=yes" : "--compiled-modules=existing"
    command =
        `$(Base.julia_cmd()) --startup-file=no $compiled_modules --threads=1 --gcthreads=1 --project=$root $checker`
    @test success(pipeline(command; stdout = stdout, stderr = stderr))
end

@testset "Current paired assets preserve numerical values and transport declarations" begin
    root = normpath(joinpath(@__DIR__, ".."))
    catalog =
        JSON3.read(read(joinpath(@__DIR__, "fixtures", "current_paired", "manifest.json"), String))
    @test length(catalog.rows) == 2
    @test !catalog.new_science_claim
    for row in catalog.rows
        source=joinpath(root, String(row.current_relative))
        source_state=WannierNLQG.IO.scientific_file_state(source)
        mktempdir() do directory
            target=joinpath(directory, "model.h5")
            @test WannierNLQG.IO.read_real_space_operator_bundle(source).manifest.schema_version ==
                  WannierNLQG.IO.OPERATOR_BUNDLE_SCHEMA_VERSION
            generated=current_packed_fixture_copy(source, directory)
            generated==target || mv(generated, target)
            loaded=WannierNLQG.IO.read_real_space_operator_bundle(target)
            @test loaded.manifest.schema_version==WannierNLQG.IO.OPERATOR_BUNDLE_SCHEMA_VERSION
            @test all(op->all(isfinite, op.data), values(loaded.operators))
            @test !loaded.manifest.production_eligible
            @test !isfile(target*".commit.toml")
        end
        @test WannierNLQG.IO.scientific_file_state(source)==source_state
    end
    payload = joinpath(@__DIR__, "fixtures", "first_use_portable")
    manifest = PortableFixturePayload.verify_payload(payload)
    mktempdir() do directory
        mapping = PortableFixturePayload.argument_mapping(manifest, payload, directory)
        @test mapping["@FIXTURE_PATH_11@"] ==
              joinpath(root, String(first(catalog.rows).current_relative))
    end
end
end
