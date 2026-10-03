using Test, JSON3, Serialization, SHA
include(joinpath(@__DIR__, "audit_signatures.jl"))
@test !MPI.Initialized()
proofpath, threadpath, out=abspath.(ARGS)
ispath(out) && error("qualification output must be fresh")
mkpath(out)
p=JSON3.read(read(proofpath, String))
index=Dict(String(k)=>Set([String(p.observation)]) for k in p.required_printed_keys)
hashes=Dict{String, Set{String}}()
load_exact_actual_type_proof!(
    proofpath,
    index,
    hashes,
    source_digest(ROOT),
    digest(read(joinpath(ROOT, "Manifest.toml"))),
)
@test length(ACTUAL_INFERRED_TYPES)==8
results=String[]
function rejected(label, mutate; observations = index)
    proof=JSON3.read(read(proofpath, String), Dict{String, Any})
    for key in (
        "file",
        "runner_path",
        "trace_index",
        "original_capture_file",
        "original_inference_file",
        "lossless_reduction_runner",
        "original_parse_failures_file",
    )
        proof[key]=proof_artifact(proofpath, proof[key])
    end
    mutate(proof)
    path=joinpath(out, label*".json");
    write(path, JSON3.write(proof))
    empty!(ACTUAL_INFERRED_TYPES)
    errorvalue=try
        load_exact_actual_type_proof!(
            path,
            observations,
            Dict{String, Set{String}}(),
            source_digest(ROOT),
            digest(read(joinpath(ROOT, "Manifest.toml"))),
        )
        nothing
    catch e
        e
    end
    @test errorvalue!==nothing
    push!(results, label*": "*sprint(showerror, errorvalue))
end
rejected("source_identity", p->p["source_src_ext_sha256"]="changed")
rejected("manifest_identity", p->p["manifest_sha256"]="changed")
rejected("capture_hash", p->p["original_capture_sha256"]="changed")
rejected("inference_hash", p->p["original_inference_sha256"]="changed")
rejected("runner_hash", p->p["runner_sha256"]="changed")
rejected("reduction_runner_hash", p->p["lossless_reduction_runner_sha256"]="changed")
rejected("original_failure_hash", p->p["original_parse_failures_sha256"]="changed")
rejected("index_hash", p->p["trace_index_sha256"]="changed")
rejected("subset_scope", p->pop!(p["required_printed_keys"]))
rejected("missing_real_observation", p->nothing; observations = Dict{String, Set{String}}())
# Even a correctly hashed reduced file must equal the captured original Type.
rejected("forged_reduced_type", p->begin
    pairs=deserialize(p["file"]);
    pairs[1]=first(pairs[1])=>Int
    path=joinpath(out, "forged_reduced_type.jls");
    serialize(path, pairs)
    p["file"]=path;
    p["sha256"]=digest(read(path))
end)
load_thread_name_proof!(threadpath)
@test length(TRACE_THREAD_NAME_MAP)==4
for (label, mutate) in (
    "thread_descriptor_hash" => (d->d["descriptor_sha256"][1]="changed"),
    "thread_source" => (d->d["source_src_ext_sha256"]="changed"),
    "thread_julia" => (d->d["julia"]="changed"),
    "thread_ambiguous_layout" => (d->begin
        row=only(filter(r->endswith(r["old_binding"], "#threadsfor_fun#576"), d["rows"]))
        push!(row["new_candidates"], "forged")
    end),
)
    d=JSON3.read(read(threadpath, String), Dict{String, Any})
    for side in ("old", "new")
        d[side]["folder"]=proof_artifact(threadpath, d[side]["folder"])
    end
    mutate(d)
    path=joinpath(out, label*".json");
    write(path, JSON3.write(d))
    @test_throws Exception load_thread_name_proof!(path)
    push!(results, label)
end
@test !MPI.Initialized()
write(
    joinpath(out, "qualification.json"),
    JSON3.write((
        tests = results,
        positive_exact_types = 8,
        negative_cases = length(results),
        checkpoint = false,
        full_audit_pass = false,
        mpi_initialized = MPI.Initialized(),
    )),
)
println("PACKAGED_TYPES_AND_THREADS_POSITIVE_NEGATIVE_PASS")
