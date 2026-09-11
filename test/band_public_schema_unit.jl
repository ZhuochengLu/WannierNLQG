using Test, HDF5, WannierNLQG, SHA

isdefined(@__MODULE__, :BandPublicSchemaTestSupport) || include("BandPublicSchemaTestSupport.jl")

const BAND_PUBLIC_S = WannierNLQG.SymmetryFoundation
const BAND_PUBLIC_EXT = first(BAND_PUBLIC_S._load_symmetry_foundation_extension!())
const BAND_PUBLIC_FORMER =
    joinpath(@__DIR__, "fixtures", "band_public_schema", "former_complete_1_17.h5")
const BAND_PUBLIC_NORMAL_BASELINE =
    joinpath(@__DIR__, "fixtures", "band_public_schema", "former_normal_prepared_1_16.h5")

# Current fixtures originate in raw synthetic input and the production preparation
# workflow; the frozen historical file is never relabelled into a positive fixture.
function band_public_fixture_path(directory)
    path, _ = BandPublicSchemaTestSupport.write_prepared_time_reversal_fixture(directory)
    return path
end

# Compare every HDF5 dataset and attribute, including type, shape and numeric bytes.
function band_public_inventory(object, path = "")
    rows = Dict{String, Any}()
    for key in keys(HDF5.attributes(object))
        rows[path * "@" * key] = read(HDF5.attributes(object)[key])
    end
    if object isa HDF5.Dataset
        data = read(object)
        rows[path * "#type"] = string(typeof(data))
        rows[path * "#shape"] = data isa AbstractArray ? size(data) : ()
        rows[path * "#value"] = data
        data isa AbstractArray{<:Number} &&
            (rows[path * "#bytes"] = collect(reinterpret(UInt8, vec(data))))
    else
        for key in keys(object)
            merge!(rows, band_public_inventory(object[key], path * "/" * key))
        end
    end
    return rows
end

@testset "Band public reader rejects every nonpublic header" begin
    # The supplied representation is deliberately not needed: the shared header
    # check must reject the file before any preparation payload is considered.
    for version in (string.("1.", 1:17)..., "2.0", "")
        mktempdir() do directory
            current =
                BAND_PUBLIC_S.read_band_representation_hdf5(band_public_fixture_path(directory))
            path = joinpath(directory, "nonpublic.h5")
            cp(BAND_PUBLIC_FORMER, path)
            HDF5.h5open(path, "r+") do handle
                HDF5.delete_attribute(handle, "schema_version")
                HDF5.attributes(handle)["schema_version"] = version
            end
            @test_throws ArgumentError BAND_PUBLIC_S.read_band_representation_hdf5(path)
            @test_throws ArgumentError BAND_PUBLIC_S.read_band_representation_preparation_hdf5(
                path,
                current,
            )
            @test_throws ArgumentError Base.invokelatest(
                BAND_PUBLIC_EXT._read_band_representation_qualification_hdf5,
                path,
            )
        end
    end
end

@testset "Band current complete payload has one public wire identity" begin
    @test BAND_PUBLIC_S.band_representation_schema_version() == "1.0"
    mktempdir() do directory
        path = band_public_fixture_path(directory)
        restored = BAND_PUBLIC_S.read_band_representation_hdf5(path)
        @test restored.schema_version == "1.0"
        @test get(restored.conventions, "qualification_scope", "full_parent") == "full_parent"
        @test !haskey(restored.conventions, "product_metadata_origin")
        preparation = BAND_PUBLIC_S.read_band_representation_preparation_hdf5(path, restored)
        output = joinpath(directory, "rewritten.h5")
        BAND_PUBLIC_S.write_band_representation_hdf5(output, restored; overwrite = false)
        reread = BAND_PUBLIC_S.read_band_representation_hdf5(output)
        @test reread.schema_version == "1.0"
        @test isequal(reread.sewing_matrices, restored.sewing_matrices)
        @test reread.conventions == restored.conventions
        for version in ("1.9", "1.17", "2.0")
            rejected = joinpath(directory, "preparation-$(version).h5")
            cp(path, rejected)
            HDF5.h5open(rejected, "r+") do handle
                write(HDF5.attributes(handle)["schema_version"], version)
            end
            @test_throws ArgumentError BAND_PUBLIC_S.read_band_representation_preparation_hdf5(
                rejected,
                restored,
            )
        end
        for group in
            ("products", "compatibility", "conventions", "sewing_backend", "wavefunction_gauge")
            rejected = joinpath(directory, "missing-$(group).h5")
            cp(path, rejected)
            HDF5.h5open(rejected, "r+") do handle
                HDF5.delete_object(handle, group)
            end
            @test_throws ArgumentError BAND_PUBLIC_S.read_band_representation_hdf5(rejected)
            @test_throws ArgumentError BAND_PUBLIC_S.read_band_representation_preparation_hdf5(
                rejected,
                restored,
            )
            @test_throws ArgumentError Base.invokelatest(
                BAND_PUBLIC_EXT._read_band_representation_qualification_hdf5,
                rejected,
            )
        end
        # Every public entry must reject damaged primary content before returning
        # preparation or qualification metadata, even when its own subgroup is intact.
        for mutation in (:digest, :mode, :target, :preparation_digest, :preparation_rows)
            rejected = joinpath(directory, "damaged-primary-$(mutation).h5")
            cp(path, rejected)
            HDF5.h5open(rejected, "r+") do handle
                if mutation == :digest
                    write(
                        HDF5.attributes(handle["compatibility"])["representation_sha256"],
                        repeat("0", 64),
                    )
                elseif mutation == :mode
                    HDF5.delete_attribute(handle["conventions"], "effective_wannierization_mode")
                elseif mutation == :preparation_digest
                    write(HDF5.attributes(handle)["preparation_digest"], repeat("0", 64))
                elseif mutation == :preparation_rows
                    HDF5.delete_object(handle["raw_diagnostics"], "real_values")
                else
                    attributes = HDF5.attributes(handle["conventions"])
                    haskey(attributes, "qualification_scope") &&
                        HDF5.delete_attribute(handle["conventions"], "qualification_scope")
                    attributes["qualification_scope"] = "target_subspace"
                end
            end
            @test_throws ArgumentError BAND_PUBLIC_S.read_band_representation_hdf5(rejected)
            @test_throws ArgumentError BAND_PUBLIC_S.read_band_representation_preparation_hdf5(
                rejected,
                restored,
            )
            @test_throws ArgumentError Base.invokelatest(
                BAND_PUBLIC_EXT._read_band_representation_qualification_hdf5,
                rejected,
            )
        end
        wrong_schema = joinpath(directory, "wrong-schema.h5")
        cp(path, wrong_schema)
        HDF5.h5open(wrong_schema, "r+") do handle
            HDF5.delete_attribute(handle, "schema")
            HDF5.attributes(handle)["schema"] = "unrelated.format"
        end
        @test_throws ArgumentError BAND_PUBLIC_S.read_band_representation_hdf5(wrong_schema)
        @test_throws ArgumentError BAND_PUBLIC_S.read_band_representation_preparation_hdf5(
            wrong_schema,
            restored,
        )
        @test_throws ArgumentError Base.invokelatest(
            BAND_PUBLIC_EXT._read_band_representation_qualification_hdf5,
            wrong_schema,
        )
        invalid_mode = deepcopy(restored)
        delete!(invalid_mode.conventions, "effective_wannierization_mode")
        invalid_output = joinpath(directory, "invalid-mode.h5")
        @test_throws ArgumentError BAND_PUBLIC_S.write_band_representation_hdf5(
            invalid_output,
            invalid_mode,
        )
        @test !ispath(invalid_output)
        internal = BAND_PUBLIC_S.BandRepresentation(
            "1.17",
            (getfield(restored, name) for name in fieldnames(typeof(restored))[2:16])...;
            conventions = restored.conventions,
            input_sha256 = restored.input_sha256,
        )
        @test_throws ArgumentError BAND_PUBLIC_S.write_band_representation_hdf5(
            invalid_output,
            internal,
        )
        @test !ispath(invalid_output)
        original = read(output)
        before_paths = sort(readdir(directory))
        @test_throws ArgumentError BAND_PUBLIC_S.write_band_representation_hdf5(
            output,
            restored;
            overwrite = true,
            qualification_outer_mask = falses(size(restored.energies_ev)),
            qualification_frozen_mask = trues(size(restored.energies_ev)),
        )
        @test read(output) == original
        @test sort(readdir(directory)) == before_paths
        for key in ("schema", "schema_version")
            rejected = joinpath(directory, "missing-$(key).h5")
            cp(path, rejected)
            HDF5.h5open(rejected, "r+") do handle
                HDF5.delete_attribute(handle, key)
            end
            @test_throws ArgumentError BAND_PUBLIC_S.read_band_representation_hdf5(rejected)
            @test_throws ArgumentError BAND_PUBLIC_S.read_band_representation_preparation_hdf5(
                rejected,
                restored,
            )
            @test_throws ArgumentError Base.invokelatest(
                BAND_PUBLIC_EXT._read_band_representation_qualification_hdf5,
                rejected,
            )
        end
    end
end

@testset "Band normal preparation preserves former scientific bytes" begin
    @test bytes2hex(SHA.sha256(read(BAND_PUBLIC_NORMAL_BASELINE))) ==
          "fb8d734541be917bedb34c3e7bce2cb055f951df66154b7a9eebe1d6cb7c4c43"
    @test bytes2hex(SHA.sha256(read(BAND_PUBLIC_FORMER))) ==
          "155e1c3b91a2e44838ccaa70d41b68649db9acc0a74e592039bb5c8d683acfdf"
    mktempdir() do directory
        path = band_public_fixture_path(directory)
        representation = BAND_PUBLIC_S.read_band_representation_hdf5(path)
        validation = BAND_PUBLIC_S.validate_band_representation(
            representation;
            absolute_tolerance = 1.0e-8,
            oracle_excess_tolerance = 1.0e-8,
            require_oracle = false,
        )
        @test validation.passed
        # Compare the actual normal-prepare writer output, including its original
        # compatibility report, with the matching normal-prepare baseline.
        output = path
        former = HDF5.h5open(band_public_inventory, BAND_PUBLIC_NORMAL_BASELINE, "r")
        current = HDF5.h5open(band_public_inventory, output, "r")
        @test keys(former) == keys(current)
        differences = sort!([key for key in keys(former) if !isequal(former[key], current[key])])
        # The frozen fixture records its original software and interpreter;
        # these provenance identities may vary across release verification.
        @test current["/environment@julia_version"] == string(VERSION)
        @test setdiff(
            differences,
            [
                "@schema_version",
                "/environment@generated_at_utc",
                "/environment@julia_version",
                "/environment@wanniernlqg_version",
            ],
        ) == String[]
        @test current["/compatibility@representation_sha256"] ==
              former["/compatibility@representation_sha256"]
        @test current["@preparation_digest"] == former["@preparation_digest"]
        project = dirname(@__DIR__)
        script = "using WannierNLQG; S=WannierNLQG.SymmetryFoundation; r=S.read_band_representation_hdf5(ARGS[1]); @assert r.schema_version == \"1.0\"; S.read_band_representation_preparation_hdf5(ARGS[1],r); println(\"BAND_PUBLIC_FRESH_PROCESS_PASS\")"
        command =
            `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(project) -e $(script) $(output)`
        @test occursin("BAND_PUBLIC_FRESH_PROCESS_PASS", read(command, String))
    end
end
