using Test, HDF5, WannierNLQG, SHA, JSON3

isdefined(@__MODULE__, :BandPublicSchemaTestSupport) || include("BandPublicSchemaTestSupport.jl")
const BAND_PUBLIC_S = WannierNLQG.SymmetryFoundation
const BAND_PUBLIC_EXT = first(BAND_PUBLIC_S._load_symmetry_foundation_extension!())
const BAND_PUBLIC_FORMER =
    joinpath(@__DIR__, "fixtures", "band_public_schema", "former_complete_1_17.h5")
const BAND_PUBLIC_NORMAL_BASELINE =
    joinpath(@__DIR__, "fixtures", "band_public_schema", "former_normal_prepared_1_16.h5")

# Normal preparation is explicitly non-authenticated; the expert default is not changed.
function band_public_fixture_path(directory; compatibility_policy = :warn)
    path, _ = BandPublicSchemaTestSupport.write_prepared_time_reversal_fixture(
        directory;
        compatibility_policy,
    )
    return path
end

function band_public_inventory(object, path = "")
    rows = Dict{String, Any}()
    for key in keys(HDF5.attributes(object))
        rows[path * "@" * key] = HDF5.read_attribute(object, key)
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
            child = object[key]
            try
                merge!(rows, band_public_inventory(child, path * "/" * key))
            finally
                close(child)
            end
        end
    end
    return rows
end

# Every entry must reach the same intended rejection layer; a setup failure is not success.
function band_public_rejections(path, representation, reason; content_authentication)
    readers = (
        () -> BAND_PUBLIC_S.read_band_representation_hdf5(path; content_authentication),
        () -> BAND_PUBLIC_S.read_band_representation_preparation_hdf5(
            path,
            representation;
            content_authentication,
        ),
        () -> Base.invokelatest(
            BAND_PUBLIC_EXT._read_band_representation_qualification_hdf5,
            path;
            content_authentication,
        ),
    )
    for reader in readers
        exception = try
            reader()
            nothing
        catch error
            error
        end
        @test exception isa ArgumentError
        if exception isa ArgumentError
            @test occursin(reason, sprint(showerror, exception))
        end
    end
end

# Delete/recreate attributes while the owning object is live. Verify after reopening.
function band_public_set_attribute(object, key, value)
    BandPublicSchemaTestSupport.replace_band_attribute!(object, key, value)
end

@testset "Band public shared headers reject independently of authentication" begin
    mktempdir() do directory
        current_path = band_public_fixture_path(directory)
        current = BAND_PUBLIC_S.read_band_representation_hdf5(
            current_path;
            content_authentication = false,
        )
        for version in (string.("1.", 1:17)..., "2.0", "")
            path = joinpath(directory, "nonpublic-$(version).h5")
            # A real archived artifact supplies historical storage, never a relabelled positive.
            cp(BAND_PUBLIC_FORMER, path)
            chmod(path, 0o600)
            HDF5.h5open(path, "r+") do handle
                band_public_set_attribute(handle, "schema_version", version)
            end
            HDF5.h5open(path, "r") do handle
                @test HDF5.read_attribute(handle, "schema_version") == version
            end
            for authentication in (false, true)
                band_public_rejections(
                    path,
                    current,
                    "unsupported band-representation schema";
                    content_authentication = authentication,
                )
            end
        end
        for key in ("schema", "schema_version")
            path = joinpath(directory, "missing-$(key).h5")
            cp(current_path, path)
            HDF5.h5open(path, "r+") do handle
                @test haskey(HDF5.attributes(handle), key)
                HDF5.delete_attribute(handle, key)
            end
            HDF5.h5open(path, "r") do handle
                @test !haskey(HDF5.attributes(handle), key)
            end
            band_public_rejections(
                path,
                current,
                "missing attribute $(key)";
                content_authentication = false,
            )
        end
        wrong = joinpath(directory, "wrong-schema.h5")
        cp(current_path, wrong)
        HDF5.h5open(wrong, "r+") do handle
            band_public_set_attribute(handle, "schema", "unrelated.format")
        end
        band_public_rejections(
            wrong,
            current,
            "not a WannierNLQG band representation";
            content_authentication = false,
        )
    end
end

@testset "Band normal preparation retains complete mathematical rejection paths" begin
    @test BAND_PUBLIC_S.band_representation_schema_version() == "1.0"
    mktempdir() do directory
        path = band_public_fixture_path(directory)
        restored = BAND_PUBLIC_S.read_band_representation_hdf5(path; content_authentication = false)
        preparation = BAND_PUBLIC_S.read_band_representation_preparation_hdf5(
            path,
            restored;
            content_authentication = false,
        )
        @test restored.schema_version == "1.0"
        @test get(restored.conventions, "qualification_scope", "full_parent") == "full_parent"
        @test !haskey(restored.conventions, "product_metadata_origin")
        @test preparation.preparation_digest === nothing
        HDF5.h5open(path, "r") do handle
            @test !haskey(HDF5.attributes(handle), "preparation_digest")
            @test HDF5.read_attribute(handle["compatibility"], "content_authentication") ==
                  "NOT_PERFORMED"
        end
        # Default authentication must still refuse this file; no implicit downgrade.
        band_public_rejections(
            path,
            restored,
            "missing attribute preparation_digest";
            content_authentication = true,
        )
        output = joinpath(directory, "rewritten.h5")
        BAND_PUBLIC_S.write_band_representation_hdf5(
            output,
            restored;
            content_authentication = false,
            qualification_scope = preparation.qualification_scope,
            inventory = preparation.inventory,
            raw_diagnostics = preparation.raw_diagnostics,
            requested_policy = preparation.requested_policy,
            effective_policy = preparation.effective_policy,
            symmetry_tolerance_status = preparation.symmetry_tolerance_status,
        )
        reread = BAND_PUBLIC_S.read_band_representation_hdf5(output; content_authentication = false)
        @test isequal(reread.sewing_matrices, restored.sewing_matrices)
        @test reread.conventions == restored.conventions
        for group in
            ("products", "compatibility", "conventions", "sewing_backend", "wavefunction_gauge")
            bad = joinpath(directory, "missing-$(group).h5")
            cp(path, bad)
            HDF5.h5open(bad, "r+") do handle
                @test haskey(handle, group)
                HDF5.delete_object(handle, group)
            end
            HDF5.h5open(bad, "r") do handle
                @test !haskey(handle, group)
            end
            band_public_rejections(
                bad,
                restored,
                "missing $(group)";
                content_authentication = false,
            )
        end
        cases = (
            (:mode, "missing effective_wannierization_mode"),
            (:target, "target_authority must be outer_window"),
            (:preparation_rows, "missing raw_diagnostics/real_values"),
            (:product, "product table contradicts operation metadata"),
            (:mask, "frozen qualification mask must be contained in outer mask"),
        )
        for (mutation, reason) in cases
            @testset "Non-authenticated mathematical mutation $mutation" begin
                bad = joinpath(directory, "damaged-$(mutation).h5")
                cp(path, bad)
                HDF5.h5open(bad, "r+") do handle
                    if mutation == :mode
                        HDF5.delete_attribute(
                            handle["conventions"],
                            "effective_wannierization_mode",
                        )
                    elseif mutation == :target
                        band_public_set_attribute(
                            handle["conventions"],
                            "qualification_scope",
                            "target_subspace",
                        )
                    elseif mutation == :preparation_rows
                        HDF5.delete_object(handle["raw_diagnostics"], "real_values")
                    elseif mutation == :product
                        values = read(handle["products/product_index"])
                        @test values[1, 1] == 1
                        values[1, 1] = 2
                        write(handle["products/product_index"], values)
                    else
                        write(handle["qualification_scope/outer_mask"], zeros(UInt8, 2, 2))
                        write(handle["qualification_scope/frozen_mask"], ones(UInt8, 2, 2))
                    end
                end
                HDF5.h5open(bad, "r") do handle
                    if mutation == :mode
                        @test !haskey(
                            HDF5.attributes(handle["conventions"]),
                            "effective_wannierization_mode",
                        )
                    elseif mutation == :target
                        @test HDF5.read_attribute(handle["conventions"], "qualification_scope") ==
                              "target_subspace"
                    elseif mutation == :preparation_rows
                        @test !haskey(handle["raw_diagnostics"], "real_values")
                    elseif mutation == :product
                        @test read(handle["products/product_index"])[1, 1] == 2
                    else
                        @test read(handle["qualification_scope/outer_mask"]) == zeros(UInt8, 2, 2)
                        @test read(handle["qualification_scope/frozen_mask"]) == ones(UInt8, 2, 2)
                    end
                end
                band_public_rejections(bad, restored, reason; content_authentication = false)
            end
        end
        invalid_mode = deepcopy(restored)
        delete!(invalid_mode.conventions, "effective_wannierization_mode")
        invalid_output = joinpath(directory, "invalid-mode.h5")
        @test_throws ArgumentError BAND_PUBLIC_S.write_band_representation_hdf5(
            invalid_output,
            invalid_mode;
            content_authentication = false,
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
            internal;
            content_authentication = false,
        )
        @test !ispath(invalid_output)
        original = read(output)
        before_paths = sort(readdir(directory))
        @test_throws ArgumentError BAND_PUBLIC_S.write_band_representation_hdf5(
            output,
            restored;
            content_authentication = false,
            overwrite = true,
            qualification_outer_mask = falses(size(restored.energies_ev)),
            qualification_frozen_mask = trues(size(restored.energies_ev)),
        )
        @test read(output) == original
        @test sort(readdir(directory)) == before_paths
    end
end

@testset "Band explicit expert authentication remains enforced" begin
    mktempdir() do directory
        normal = band_public_fixture_path(directory)
        representation =
            BAND_PUBLIC_S.read_band_representation_hdf5(normal; content_authentication = false)
        path = joinpath(directory, "explicit-authenticated.h5")
        BAND_PUBLIC_S.write_band_representation_hdf5(
            path,
            representation;
            content_authentication = true,
        )
        restored = BAND_PUBLIC_S.read_band_representation_hdf5(path)
        metadata = BAND_PUBLIC_S.read_band_representation_preparation_hdf5(path, restored)
        @test metadata.preparation_digest isa String
        @test length(metadata.preparation_digest) == 64
        band_public_rejections(
            path,
            restored,
            "EXPLICIT_CONTENT_MIGRATION_REQUIRED";
            content_authentication = false,
        )
        for (name, location, key, reason) in (
            (
                :representation,
                "compatibility",
                "representation_sha256",
                "band-representation SHA-256 mismatch",
            ),
            (:preparation, "", "preparation_digest", "preparation digest mismatch"),
        )
            bad = joinpath(directory, "authenticated-$(name)-tampered.h5")
            cp(path, bad)
            HDF5.h5open(bad, "r+") do handle
                object = isempty(location) ? handle : handle[location]
                try
                    @test HDF5.read_attribute(object, key) != repeat("0", 64)
                    band_public_set_attribute(object, key, repeat("0", 64))
                finally
                    isempty(location) || close(object)
                end
            end
            HDF5.h5open(bad, "r") do handle
                object = isempty(location) ? handle : handle[location]
                try
                    @test HDF5.read_attribute(object, key) == repeat("0", 64)
                finally
                    isempty(location) || close(object)
                end
            end
            band_public_rejections(bad, restored, reason; content_authentication = true)
        end
    end
end

@testset "Band normal preparation preserves archived mathematical values" begin
    # External immutable-fixture integrity is separate from normal scientific admission.
    @test bytes2hex(SHA.sha256(read(BAND_PUBLIC_NORMAL_BASELINE))) ==
          "fb8d734541be917bedb34c3e7bce2cb055f951df66154b7a9eebe1d6cb7c4c43"
    @test bytes2hex(SHA.sha256(read(BAND_PUBLIC_FORMER))) ==
          "155e1c3b91a2e44838ccaa70d41b68649db9acc0a74e592039bb5c8d683acfdf"
    mktempdir() do directory
        output = band_public_fixture_path(directory)
        representation =
            BAND_PUBLIC_S.read_band_representation_hdf5(output; content_authentication = false)
        raw = BandPublicSchemaTestSupport.raw_time_reversal_representation_fixture()
        # Independent raw mathematical input, before any writer or reader.
        for field in (
            :real_lattice,
            :reciprocal_lattice,
            :mp_grid,
            :kpoints_fractional,
            :energies_ev,
            :kpoint_map,
            :reciprocal_shifts,
            :sewing_matrices,
            :band_block_labels,
            :irreducible_indices,
            :full_to_irreducible,
            :full_to_operation,
        )
            @test isequal(getfield(representation, field), getfield(raw, field))
        end
        validation = BAND_PUBLIC_S.validate_band_representation(
            representation;
            absolute_tolerance = 1.0e-8,
            oracle_excess_tolerance = 1.0e-8,
            require_oracle = false,
        )
        @test validation.passed
        former = HDF5.h5open(band_public_inventory, BAND_PUBLIC_NORMAL_BASELINE, "r")
        current = HDF5.h5open(band_public_inventory, output, "r")
        @test current["/conventions@construction_policy"] == "standard"
        @test current["/environment@julia_version"] == string(VERSION)
        mappings = JSON3.read(current["/conventions@construction_mapping_diagnostics"])
        @test length(mappings) == 6
        @test all(
            row -> row["result"] == "PASS" && row["value"] == 0.0 && row["action"] == "CONTINUE",
            mappings,
        )
        @test former["/compatibility_policy@requested"] ==
              current["/compatibility_policy@requested"] ==
              "warn"
        @test former["/compatibility_policy@effective"] == "strict"
        @test current["/compatibility_policy@effective"] == "warn"
        preparation = BAND_PUBLIC_S.read_band_representation_preparation_hdf5(
            output,
            representation;
            content_authentication = false,
        )
        @test preparation.preparation_digest === nothing
        @test !haskey(current, "@preparation_digest")
        @test !haskey(current, "/compatibility@representation_sha256")
        strict_path = band_public_fixture_path(
            joinpath(directory, "strict-compatibility");
            compatibility_policy = :strict,
        )
        strict_representation =
            BAND_PUBLIC_S.read_band_representation_hdf5(strict_path; content_authentication = false)
        strict_preparation = BAND_PUBLIC_S.read_band_representation_preparation_hdf5(
            strict_path,
            strict_representation;
            content_authentication = false,
        )
        @test strict_preparation.requested_policy == strict_preparation.effective_policy == :strict
        strict_inventory = HDF5.h5open(band_public_inventory, strict_path, "r")
        # Explicit mathematical domains, not equality of retired audit inventories.
        groups = (
            "/geometry/",
            "/bands/",
            "/operations/",
            "/action/",
            "/stars/",
            "/products/",
            "/qualification_scope/",
            "/raw_diagnostics/",
        )
        scientific_keys = sort!([
            key for key in keys(former) if any(prefix -> startswith(key, prefix), groups) &&
            any(suffix -> endswith(key, suffix), ("#type", "#shape", "#value", "#bytes"))
        ])
        @test !isempty(scientific_keys)
        for key in scientific_keys
            @test haskey(current, key) && haskey(strict_inventory, key)
            if haskey(current, key) && haskey(strict_inventory, key)
                @test isequal(former[key], current[key])
                @test isequal(former[key], strict_inventory[key])
            end
        end
        # Metadata removal is not a new mathematical oracle or a promotion to PASS.
        project = dirname(@__DIR__)
        script = "using WannierNLQG; S=WannierNLQG.SymmetryFoundation; r=S.read_band_representation_hdf5(ARGS[1];content_authentication=false); @assert r.schema_version == \"1.0\"; S.read_band_representation_preparation_hdf5(ARGS[1],r;content_authentication=false); println(\"BAND_PUBLIC_FRESH_PROCESS_PASS\")"
        command =
            `$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$(project) -e $(script) $(output)`
        @test occursin("BAND_PUBLIC_FRESH_PROCESS_PASS", read(command, String))
    end
end
