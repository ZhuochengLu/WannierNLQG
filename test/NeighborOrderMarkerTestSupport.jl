# Actual native-source assembly evidence only. This does not add qualification
# metadata back to the three-file mathematical payload or reseal any digest.
function neighbor_order_marker_tests(fixture, directory)
    extension = first(OTS_IO._load_operator_bundle_extension!())
    loaded = OTS_IO.read_real_space_operator_bundle(fixture.output)
    qualification = fixture.provenance["operator_qualification"]
    entries = loaded.manifest.entries
    validate(q) = Base.invokelatest(extension._validate_streamed_neighbor_evidence, q, entries)
    @test validate(qualification) === nothing
    shared = qualification["source_neighbor_order_contract"]
    n, nk = Int(shared["num_neighbors"]), Int(shared["num_kpoints"])
    flat = Int.(shared["source_to_internal"])
    @test length(flat) == n * nk
    @test all(sort(flat[((k - 1) * n + 1):(k * n)]) == collect(1:n) for k in 1:nk)
    @test shared["source_to_internal_definition"] == string(n, ",", nk, ";", join(flat, ","))
    affected = (
        OTS_C.REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR,
        OTS_C.REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP,
    )
    for kind in affected
        name = OTS_C.real_space_operator_name(kind)
        record = qualification["operators"][name]
        evidence = record["source_neighbor_order_contract"]
        @test record["content_authentication"] == "NOT_PERFORMED"
        for field in ("source_input_definitions", "operator_target_contract_definition")
            @test evidence[field] == record[field]
        end
        @test Base.invokelatest(
            extension._streamed_neighbor_order_status,
            qualification,
            entries,
            kind,
        ) == "REBUILT_SOURCE_TO_INTERNAL"
    end
    name = OTS_C.real_space_operator_name(first(affected))
    cases = (
        "missing-map" => q -> delete!(q, "source_neighbor_order_contract"),
        "axes" =>
            q -> (q["source_neighbor_order_contract"]["axis_order"] = "kpoint,source_neighbor"),
        "count" => q -> (q["source_neighbor_order_contract"]["num_neighbors"] = 0),
        "length" => q -> pop!(q["source_neighbor_order_contract"]["source_to_internal"]),
        "duplicate" =>
            q -> (
                q["source_neighbor_order_contract"]["source_to_internal"][1] =
                    q["source_neighbor_order_contract"]["source_to_internal"][2]
            ),
        "definition" =>
            q -> (
                q["source_neighbor_order_contract"]["source_to_internal_definition"] = "inconsistent-map"
            ),
        "source" =>
            q -> (
                q["operators"][name]["source_neighbor_order_contract"]["source_input_definitions"] =
                    Dict("wrong" => "input")
            ),
        "target" =>
            q -> (
                q["operators"][name]["source_neighbor_order_contract"]["operator_target_contract_definition"] = "wrong-target"
            ),
        "component" =>
            q -> (
                q["operators"][name]["source_neighbor_order_contract"]["delivery_component_reference"] = "wrong-component"
            ),
    )
    for (label, mutate) in cases
        bad = deepcopy(qualification)
        mutate(bad)
        @test_throws ArgumentError validate(bad)
    end
    absent = deepcopy(qualification)
    delete!(absent, "source_neighbor_order_contract")
    for record in values(absent["operators"])
        pop!(record, "source_neighbor_order_contract", nothing)
    end
    @test validate(absent) === nothing
    for kind in affected
        @test Base.invokelatest(extension._streamed_neighbor_order_status, absent, entries, kind) ==
              "LEGACY_UNVERIFIED"
    end
    # Missing old metadata never upgrades a source or licenses a changed array.
    return nothing
end
