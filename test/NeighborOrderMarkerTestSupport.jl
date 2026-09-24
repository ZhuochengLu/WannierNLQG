# Staged against Lorentz's concrete additive marker API; never infer status from a label.
function neighbor_order_marker_tests(fixture, directory)
    extension = first(OTS_IO._load_operator_bundle_extension!())
    loaded = OTS_IO.read_real_space_operator_bundle(fixture.output)
    affected = (
        OTS_C.REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR,
        OTS_C.REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP,
    )
    status(q, kind) = Base.invokelatest(
        extension._streamed_neighbor_order_status,
        q,
        loaded.manifest.entries,
        kind,
    )
    qualification = loaded.manifest.operator_qualification
    @test haskey(qualification, "source_neighbor_order_contract")
    shared=qualification["source_neighbor_order_contract"]
    @test shared["algorithm"]=="source-to-internal-per-k-both-indices-v1"
    @test shared["axis_order"]=="source_neighbor,kpoint;column_major"
    n, nk=Int(shared["num_neighbors"]), Int(shared["num_kpoints"])
    flat=Int.(shared["source_to_internal"])
    @test length(flat)==n*nk
    @test shared["source_to_internal_sha256"] ==
          bytes2hex(sha256(string(n, ",", nk, ";", join(flat, ","))))
    for k in 1:nk
        @test sort(flat[((k - 1) * n + 1):(k * n)])==collect(1:n)
    end
    for kind in affected
        @test status(qualification, kind)=="REBUILT_SOURCE_TO_INTERNAL"
        name=OTS_C.real_space_operator_name(kind)
        marker=qualification["operators"][name]["source_neighbor_order_contract"]
        @test marker["status"]=="REBUILT_SOURCE_TO_INTERNAL"
        @test marker["operator_kind"]==name
        @test marker["source_to_internal_sha256"]==shared["source_to_internal_sha256"]
        entries=filter(entry->entry.kind==kind, loaded.manifest.entries)
        @test marker["delivery_component_sha256"]==join(getfield.(entries, :component_sha256), ",")
    end
    function reseal!(q)
        for record in values(q["operators"])
            payload=Dict(String(k)=>v for (k, v) in pairs(record) if String(k)!="payload_sha256")
            record["payload_sha256"]=Base.invokelatest(
                extension._operator_qualification_digest,
                payload,
            )
        end
        return q
    end
    function publish(q, path; relabel = false)
        provenance=deepcopy(fixture.provenance)
        provenance["operator_qualification"]=reseal!(q)
        if relabel
            provenance["operator_profile_assembly_algorithm_version"]="v5-source-neighbor-order"
        end
        OTS_IO.write_real_space_operator_bundle(
            path,
            fixture.model.lattice,
            fixture.model.r_degeneracies,
            fixture.operators;
            profile = nothing,
            operator_tasks = fixture.tasks,
            provenance,
            geometry = fixture.geometry,
            eligibility = fixture.eligibility,
        )
    end
    # Legacy remains readable. Resealing and relabeling cannot create a correction receipt.
    legacy=deepcopy(qualification)
    delete!(legacy, "source_neighbor_order_contract")
    for record in values(legacy["operators"])
        pop!(record, "source_neighbor_order_contract", nothing)
    end
    for relabel in (false, true)
        path=joinpath(directory, "legacy-marker-"*string(relabel)*".h5")
        publish(deepcopy(legacy), path; relabel)
        reread=OTS_IO.read_real_space_operator_bundle(path)
        @test !haskey(reread.manifest.operator_qualification, "source_neighbor_order_contract")
        for kind in affected
            @test status(reread.manifest.operator_qualification, kind)=="LEGACY_UNVERIFIED"
        end
        @test all(
            reread.operators[k].data==loaded.operators[k].data for k in keys(loaded.operators)
        )
    end
    name=OTS_C.real_space_operator_name(first(affected))
    function remove_record_markers!(q)
        for record in values(q["operators"])
            pop!(record, "source_neighbor_order_contract", nothing)
        end
    end
    cases=(
        ("root-only", remove_record_markers!),
        ("record-only", q->delete!(q, "source_neighbor_order_contract")),
        ("root-algorithm", q->q["source_neighbor_order_contract"]["algorithm"]="unsupported"),
        (
            "axis-order",
            q->q["source_neighbor_order_contract"]["axis_order"]="kpoint,source_neighbor",
        ),
        ("neighbor-count", q->q["source_neighbor_order_contract"]["num_neighbors"]=0),
        ("kpoint-count", q->q["source_neighbor_order_contract"]["num_kpoints"]=nk+1),
        ("map-length", q->pop!(q["source_neighbor_order_contract"]["source_to_internal"])),
        (
            "record-algorithm",
            q->q["operators"][name]["source_neighbor_order_contract"]["algorithm"]="unsupported",
        ),
        (
            "record-map-reference",
            q->q["operators"][name]["source_neighbor_order_contract"]["source_to_internal_sha256"]=repeat(
                "f",
                64,
            ),
        ),
        (
            "record-operator",
            q->q["operators"][name]["source_neighbor_order_contract"]["operator_kind"]="position",
        ),
        (
            "record-status",
            q->q["operators"][name]["source_neighbor_order_contract"]["status"]="LEGACY_UNVERIFIED",
        ),
        (
            "duplicate-map",
            q->q["source_neighbor_order_contract"]["source_to_internal"][1] =
                q["source_neighbor_order_contract"]["source_to_internal"][2],
        ),
        (
            "ordering-hash",
            q->q["source_neighbor_order_contract"]["source_to_internal_sha256"]=repeat("f", 64),
        ),
        (
            "source",
            q->q["operators"][name]["source_neighbor_order_contract"]["source_artifact_sha256"]=repeat(
                "f",
                64,
            ),
        ),
        (
            "input-source",
            q->q["operators"][name]["source_neighbor_order_contract"]["source_input_sha256"]["SOURCE_WAVEFUNCTIONS"]=repeat(
                "f",
                64,
            ),
        ),
        (
            "target",
            q->q["operators"][name]["source_neighbor_order_contract"]["operator_target_contract_sha256"]=repeat(
                "f",
                64,
            ),
        ),
        (
            "component",
            q->q["operators"][name]["source_neighbor_order_contract"]["delivery_component_sha256"]=repeat(
                "f",
                64,
            ),
        ),
        (
            "delivery",
            q->q["operators"][name]["source_neighbor_order_contract"]["delivery_payload_sha256"]=repeat(
                "f",
                64,
            ),
        ),
    )
    function rejects(f)
        err=try
            f();
            nothing
        catch caught
            ;
            caught
        end
        @test err isa ArgumentError
        @test err!==nothing &&
              occursin("OPERATOR_NEIGHBOR_ORDER_CONTRACT_MISMATCH", sprint(showerror, err))
    end
    for (label, mutate) in cases
        bad=deepcopy(qualification)
        mutate(bad)
        reseal!(bad)
        # The writer has actual generated bytes; the reader has persisted component index hashes.
        rejects(()->publish(deepcopy(bad), joinpath(directory, "writer-marker-"*label*".h5")))
        path=joinpath(directory, "reader-marker-"*label*".h5")
        cp(fixture.output, path)
        HDF5.h5open(path, "r+") do handle
            HDF5.delete_object(handle, "qualification")
            group=Base.invokelatest(extension._write_metadata_group, handle, "qualification", bad)
            digest=Base.invokelatest(extension._operator_qualification_digest, bad)
            HDF5.attributes(group)["payload_sha256"]=digest
            HDF5.delete_attribute(handle, "operator_qualification_sha256")
            HDF5.attributes(handle)["operator_qualification_sha256"]=digest
        end
        # Correction-specific validation precedes the aggregate scientific digest check.
        rejects(()->OTS_IO.read_real_space_operator_bundle(path))
    end
end
