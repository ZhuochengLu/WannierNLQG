module WannierizationSourceAuditDefinitionTests
using Test, WannierNLQG, HDF5, JSON3
const E = first(WannierNLQG.Wannierization._load_wannierization_extension!())
const P = E.PAWMatrixElements
const O = WannierNLQG.IO
const S = E.WannierizationInternalSupport

@testset "Input audit complete-value binding and digest-only rejection" begin
    mktempdir() do directory
        source = O.scientific_input_definition_bytes() do stream
            write(stream, "actual labelled source bytes")
        end
        reference_file = joinpath(directory, "source.h5")
        h5open(reference_file, "w") do handle
            S.write_scientific_input_reference_hdf5(handle, "source_definition", source)
        end
        qe_source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
            directory;
            band_range = 1:1,
            include_time_reversal = false,
        )
        descriptor = P._star_source_replay_metadata(qe_source)
        descriptor["source_replay_descriptor_definition"] =
            P._star_source_replay_descriptor_definition(descriptor)
        @test descriptor["source_replay_schema"] == "2.0"
        restored = P._star_source_from_replay_metadata(descriptor)
        @test restored.band_range == qe_source.band_range
        @test restored.save_directory == qe_source.save_directory
        invalid = copy(descriptor);
        invalid["source_replay_band_stop"] = "2"
        @test_throws ArgumentError P._star_source_from_replay_metadata(invalid)
        invalid = copy(descriptor);
        invalid["source_replay_schema"] = "1.0"
        @test_throws ArgumentError P._star_source_from_replay_metadata(invalid)
        records = Dict{String, Any}[]
        for (kind, residual) in (("smooth_density", 2e-14), ("paw_onsite", 3e-14))
            component = Dict(
                "schema"=>"fixture."*kind,
                "status"=>"PASS",
                "operation_count"=>32,
                "residual"=>residual,
            )
            write(joinpath(directory, kind*".json"), JSON3.write(component))
            push!(
                records,
                Dict(
                    "kind"=>kind,
                    "path"=>kind*".json",
                    "definition"=>component,
                    "schema"=>component["schema"],
                    "residual_field"=>"residual",
                    "maximum_residual"=>residual,
                ),
            )
        end
        payload = Dict{String, Any}(
            "schema"=>"wanniernlqg.input-symmetry-audit-manifest",
            "schema_version"=>"2.0",
            "status"=>"PASS",
            "operation_count"=>32,
            "maximum_residual"=>3e-14,
            "qualification_threshold"=>5e-6,
            "source_reference_hdf5"=>"source.h5",
            "component_audits"=>records,
        )
        path = joinpath(directory, "audit.json")
        config = (; input_symmetry_audit_json = path)
        write(path, JSON3.write(payload))
        result = P._star_input_audit_definition(config, source, 32)
        @test result["INPUT_SYMMETRY_CONTENT_AUTHENTICATION"] == "NOT_PERFORMED"
        @test JSON3.read(result["INPUT_SYMMETRY_AUDIT_DEFINITION"], Dict{String, Any}) == payload
        @test Set(keys(result)) == Set((
            "INPUT_SYMMETRY_CONTENT_AUTHENTICATION",
            "INPUT_SYMMETRY_AUDIT_DEFINITION",
            "INPUT_SYMMETRY_COMPONENT_DEFINITION:smooth_density",
            "INPUT_SYMMETRY_COMPONENT_DEFINITION:paw_onsite",
        ))
        @test_throws ArgumentError P._star_input_audit_definition(config, source, 31)
        changed = O.scientific_input_definition_bytes() do stream
            ;
            write(stream, "other source");
        end
        @test_throws ArgumentError P._star_input_audit_definition(config, changed, 32)
        @test isempty(
            P._star_input_audit_definition((; input_symmetry_audit_json = nothing), source, 32),
        )
        payload["schema_version"]="1.0";
        write(path, JSON3.write(payload))
        @test_throws ArgumentError P._star_input_audit_definition(config, source, 32)
        # A legacy status label is not an authorization credential. The actual
        # finite residual and complete source/component definitions decide.
        payload["schema_version"]="2.0";
        payload["status"]="FAIL";
        write(path, JSON3.write(payload))
        labelled=P._star_input_audit_definition(config, source, 32)
        @test JSON3.read(labelled["INPUT_SYMMETRY_AUDIT_DEFINITION"], Dict{String, Any})["status"] ==
              "FAIL"
        payload["maximum_residual"]=1.0;
        write(path, JSON3.write(payload))
        @test_throws ArgumentError P._star_input_audit_definition(config, source, 32)
        payload["maximum_residual"]=3e-14
        payload["status"]="PASS";
        write(path, JSON3.write(payload))
        # Changing even an unconsumed field is an actual definition mismatch.
        component=copy(records[1]["definition"]);
        component["unexpected"]=true
        write(joinpath(directory, records[1]["path"]), JSON3.write(component))
        @test_throws ArgumentError P._star_input_audit_definition(config, source, 32)
        rm(source.path);
        rm(changed.path)
    end
end
end
