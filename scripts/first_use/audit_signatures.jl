#!/usr/bin/env julia

"""Audit retained first-use precompile calls against identity-matched path traces.

This does not rewrite or remove an existing call. `--write` records deterministic
provenance, including explicitly unobserved calls; `--check` requires no gaps.
"""

using JSON3
using SHA
using Serialization
using Test # Actual captured MethodInstance Type graphs include Test module types.
using WannierNLQG, Spglib, HDF5, Serialization, EzXML, MPI

const ROOT = abspath(get(ENV, "FIRSTUSE_AUDIT_SOURCE_ROOT", dirname(Base.active_project())))
digest(data) = bytes2hex(sha256(data))
ast_text(expression) = sprint(show, expression)

function source_digest(root)
    stream = IOBuffer()
    for parent in ("src", "ext")
        top = joinpath(root, parent)
        files = String[]
        for (directory, _, names) in walkdir(top)
            for name in names
                endswith(name, ".jl") && push!(files, relpath(joinpath(directory, name), root))
            end
        end
        for relative in sort!(files)
            write(stream, replace(relative, '\\' => '/'), '\0', read(joinpath(root, relative)))
        end
    end
    return digest(take!(stream))
end

include(joinpath(@__DIR__, "source_equivalence.jl"))
load_source_equivalence!()
const RAW_ORIGIN_SOURCES=Dict{String, String}()

function trace_calls!(result::Vector{String}, expression)
    expression isa Expr || return
    if expression.head == :call && length(expression.args) == 2 && expression.args[1] == :precompile
        push!(result, ast_text(expression.args[2]))
    end
    for child in expression.args
        trace_calls!(result, child)
    end
end

function trace_signatures(path)
    result = String[]
    trace_calls!(result, Meta.parseall(read(path, String)))
    return Set(result)
end

# The package has several owner-local recording helpers. Each call below is a
# literal precompile declaration even when the helper also creates a bridge
# signature. The bridge is derived from this declaration and is not a second
# independently authored source call.
const SIGNATURE_RECORDERS = Set((
    :precompile,
    :_record_precompile,
    :_record_early_prepare,
    :_record_matrix_first_use,
    :_record_sequence,
    :_record_symmetrization,
    :_record_foundation,
    :_foundation_owner_sequence,
    :_record_response_writer_symmetrization,
    :_record_response_writer_foundation,
    :_record_vasp_spn_residual,
))

function recorder_definition(expression)
    expression isa Expr && expression.head == :call || return false
    return expression.args[1] in SIGNATURE_RECORDERS
end

# Recorder signatures sometimes name a type assembled immediately above the
# call (for example `keywords = NamedTuple{...}`). Resolve that lexical alias
# when recording the declaration; a raw symbol is not the compiled signature.
function expand_local_signature(expression, bindings::Dict{Symbol, Any})
    expression isa Symbol && return get(bindings, expression, expression)
    expression isa Expr || return expression
    return Expr(
        expression.head,
        (expand_local_signature(child, bindings) for child in expression.args)...,
    )
end

# Owner-local bridge adaptation: certify semantics before applying the existing
# derived-bridge rule. This does not match names or signatures approximately.
function _audit_find_named_function(expression, name)
    expression isa Expr || return nothing
    if expression.head==:function
        head=expression.args[1]
        while head isa Expr && head.head==:where
            head=head.args[1]
        end
        if head isa Expr && head.head==:call && head.args[1]==name
            return deepcopy(expression)
        end
    end
    for child in expression.args
        found=_audit_find_named_function(child, name)
        found===nothing || return found
    end
    return nothing
end
# Macrocall position nodes survive Base.remove_linenums!. Normalize only
# LineNumberNode source locations; no expression, symbol, type or argument is
# discarded. The exact function AST check still rejects semantic changes.
function _audit_bridge_source_positions(expression)
    expression isa LineNumberNode && return LineNumberNode(0, :AUDIT_SOURCE_POSITION)
    expression isa Expr || return expression
    return Expr(expression.head, (_audit_bridge_source_positions(x) for x in expression.args)...)
end
function _audit_canonical_bridge(expression)
    node=deepcopy(expression)
    Base.remove_linenums!(node)
    node=_audit_bridge_source_positions(node)
    head=node.args[1]
    while head isa Expr && head.head==:where
        head=head.args[1]
    end
    @assert head isa Expr && head.head==:call
    head.args[1]=:_audit_same_foreign_bridge
    return node
end
const ADDITIONAL_CERTIFIED_BRIDGES=Set{Any}()
let owner="ext/WannierNLQGOperatorBundleExt/OperatorBundleExtFirstUsePrecompile.jl",
    reference="src/FirstUse/Generated/RegistrySignatures.jl"

    candidate=isfile(joinpath(ROOT, owner)) ?
              _audit_find_named_function(
        Meta.parseall(read(joinpath(ROOT, owner), String)),
        :_operator_bundle_first_use_call,
    ) : nothing
    if candidate!==nothing
        base=_audit_find_named_function(
            Meta.parseall(read(joinpath(ROOT, reference), String)),
            :_first_use_foreign_call,
        )
        base===nothing && error("DERIVED_BRIDGE_REFERENCE_MISSING")
        _audit_canonical_bridge(candidate)==_audit_canonical_bridge(base) ||
            error("NEW_BRIDGE_NOT_SEMANTICALLY_IDENTICAL_TO_CERTIFIED_REFERENCE")
        push!(ADDITIONAL_CERTIFIED_BRIDGES, :(typeof(_operator_bundle_first_use_call)))
        proof=get(ENV, "FIRSTUSE_ADDITIONAL_BRIDGE_PROOF", "")
        isempty(proof) || write(
            proof,
            JSON3.write((
                source_sha256 = source_digest(ROOT),
                owner = owner,
                reference = reference,
                owner_file_sha256 = digest(read(joinpath(ROOT, owner))),
                reference_file_sha256 = digest(read(joinpath(ROOT, reference))),
                exact_function_ast_identical_after_function_name_and_source_positions_only = true,
                macrocall_positions_only_normalized = true,
                exact_underlying_Type_matching_unchanged = true,
                scope = "New owner helper certified; not a provenance PASS",
            )),
        )
    end
end

# A compiler-only bridge in the actually active Wannierization owner is admitted
# only after exact AST identity with the already certified foreign-call body.
let owner="ext/WannierNLQGWannierizationExt/TBQualificationFirstUseCoverage.jl",
    reference="src/FirstUse/Generated/RegistrySignatures.jl"

    candidate=isfile(joinpath(ROOT, owner)) ?
              _audit_find_named_function(
        Meta.parseall(read(joinpath(ROOT, owner), String)),
        :_wannierization_entry_compile_call,
    ) : nothing
    if candidate!==nothing
        base=_audit_find_named_function(
            Meta.parseall(read(joinpath(ROOT, reference), String)),
            :_first_use_foreign_call,
        )
        base===nothing && error("DERIVED_BRIDGE_REFERENCE_MISSING")
        _audit_canonical_bridge(candidate)==_audit_canonical_bridge(base) ||
            error("NEW_WANNIERIZATION_BRIDGE_NOT_SEMANTICALLY_IDENTICAL_TO_CERTIFIED_REFERENCE")
        push!(ADDITIONAL_CERTIFIED_BRIDGES, :(typeof(_wannierization_entry_compile_call)))
        proof=get(ENV, "FIRSTUSE_WANNIERIZATION_BRIDGE_PROOF", "")
        isempty(proof) || write(
            proof,
            JSON3.write((
                source_sha256 = source_digest(ROOT),
                owner = owner,
                reference = reference,
                owner_file_sha256 = digest(read(joinpath(ROOT, owner))),
                reference_file_sha256 = digest(read(joinpath(ROOT, reference))),
                exact_function_ast_identical_after_function_name_and_source_positions_only = true,
                exact_underlying_Type_matching_unchanged = true,
                scope = "Compiler-only active-owner helper certified; not a provenance PASS",
            )),
        )
    end
end

# Exact declared contract for each legacy implicit bridge. Parameter spelling,
# annotations, varargs, macro, call and return are checked; only source positions
# are normalized. Negative return/body mutation must be rejected for every helper.
function _audit_find_bridge_definition(expression, name)
    expression isa Expr || return nothing
    if expression.head in (:function, :(=))
        head=expression.args[1]
        while head isa Expr && head.head==:where
            head=head.args[1]
        end
        if head isa Expr && head.head==:call && head.args[1]==name
            return deepcopy(expression)
        end
    end
    for child in expression.args
        result=_audit_find_bridge_definition(child, name)
        result===nothing || return result
    end
    nothing
end
function _audit_exact_bridge_contract(expression)
    node=deepcopy(expression)
    Base.remove_linenums!(node)
    _audit_bridge_source_positions(node)
end
const ALL_BRIDGE_CONTRACT_PROOFS=Any[]
const CERTIFIED_LEGACY_COMPILER_BRIDGES=Set{Any}()
let contracts=(
        (
            "src/FirstUse/Generated/RegistrySignatures.jl",
            :_first_use_foreign_call,
            "function _first_use_foreign_call(function_value::F, arguments::Vararg{Any, N}) where {F, N}; return Base.@noinline function_value(arguments...); end",
        ),
        (
            "ext/WannierNLQGWannierizationPrecompileExt/WannierNLQGWannierizationPrecompileExt.jl",
            :_first_solve_compile_call,
            "_first_solve_compile_call(f::F, args::Vararg{Any, N}) where {F, N} = Base.@noinline f(args...)",
        ),
        (
            "ext/WannierNLQGSymmetryFoundationExt/SymmetryFoundationExtFirstUsePrecompile.jl",
            :_foundation_compile_call,
            "_foundation_compile_call(f::F, args::Vararg{Any, N}) where {F, N} = Base.@noinline f(args...)",
        ),
        (
            "ext/WannierNLQGSymmetrizationExt/SymmetrizationExtFirstUsePrecompile.jl",
            :_symmetrization_compile_call,
            "_symmetrization_compile_call(f::F, args::Vararg{Any, N}) where {F, N} = Base.@noinline f(args...)",
        ),
        (
            "ext/WannierNLQGWannierizationExt/WannierizationExtFirstUsePrecompile.jl",
            :_early_prepare_compile_call,
            "_early_prepare_compile_call(f::F, args::Vararg{Any, N}) where {F, N} = Base.@noinline f(args...)",
        ),
    )
    for (owner, name, contract_text) in contracts
        actual=_audit_find_bridge_definition(
            Meta.parseall(read(joinpath(ROOT, owner), String)),
            name,
        )
        actual===nothing && error("BRIDGE_DEFINITION_MISSING: $(name)")
        expected=Meta.parse(contract_text)
        _audit_exact_bridge_contract(actual)==_audit_exact_bridge_contract(expected) ||
            error("BRIDGE_PARAMETER_BODY_OR_RETURN_CONTRACT_CHANGED: $(name)")
        changed=deepcopy(actual)
        changed.args[2]=actual.head==:function ? Expr(:block, Expr(:return, 1)) : 1
        _audit_exact_bridge_contract(changed)!=_audit_exact_bridge_contract(expected) ||
            error("BRIDGE_CHANGED_RETURN_NEGATIVE_NOT_REJECTED: $(name)")
        changed_header=deepcopy(actual)
        header=changed_header.args[1]
        while header isa Expr && header.head==:where
            header=header.args[1]
        end
        header.args[2]=:untyped_function_parameter
        _audit_exact_bridge_contract(changed_header)!=_audit_exact_bridge_contract(expected) ||
            error("BRIDGE_CHANGED_PARAMETER_NEGATIVE_NOT_REJECTED: $(name)")
        push!(CERTIFIED_LEGACY_COMPILER_BRIDGES, Expr(:call, :typeof, name))
        push!(
            ALL_BRIDGE_CONTRACT_PROOFS,
            (
                owner = owner,
                name = String(name),
                owner_file_sha256 = digest(read(joinpath(ROOT, owner))),
                exact_parameter_body_and_return = true,
                changed_return_rejected = true,
                changed_parameter_rejected = true,
                source_positions_only_normalized = true,
            ),
        )
    end
end
proof_output=get(ENV, "FIRSTUSE_ALL_BRIDGE_CONTRACT_PROOF", "")
isempty(proof_output) || write(
    proof_output,
    JSON3.write((
        source_sha256 = source_digest(ROOT),
        julia = string(VERSION),
        proofs = ALL_BRIDGE_CONTRACT_PROOFS,
        additional_full_function_bridges_ast_verified = collect(
            string(x) for x in ADDITIONAL_CERTIFIED_BRIDGES
        ),
        scope = "Compiler-only bridge contract safety; underlying exact-Type trace attribution still required",
    )),
)

function source_calls!(result::Vector{NamedTuple}, expression, bindings::Dict{Symbol, Any})
    expression isa Expr || return
    # These definitions implement a recorder; their dynamic precompile calls
    # are counted through the literal calls to the recorder, not as a separate
    # signature with an unresolved `signature` local variable.
    if expression.head == :function && recorder_definition(expression.args[1])
        return
    end
    # Generated owner-local recorders can use the short `f(signature) = ...`
    # syntax. Count their literal callers, not the dynamic implementation body.
    if expression.head == :(=) && recorder_definition(expression.args[1])
        return
    end
    if expression.head == :let
        local_bindings = copy(bindings)
        for child in expression.args[1:(end - 1)]
            if child isa Expr && child.head == :(=) && child.args[1] isa Symbol
                local_bindings[child.args[1]] = child.args[2]
            end
        end
        source_calls!(result, last(expression.args), local_bindings)
        return
    end
    if expression.head == :block
        local_bindings = copy(bindings)
        for child in expression.args
            source_calls!(result, child, local_bindings)
            if child isa Expr && child.head == :(=) && child.args[1] isa Symbol
                local_bindings[child.args[1]] =
                    expand_local_signature(child.args[2], local_bindings)
            end
        end
        return
    end
    if expression.head == :call &&
       expression.args[1] in SIGNATURE_RECORDERS &&
       length(expression.args) in (2, 3)
        if length(expression.args) == 3
            expression.args[1] == :precompile || error("TWO_ARGUMENT_RECORDER_IS_NOT_PRECOMPILE")
            argument_types = expression.args[3]
            argument_types isa Expr && argument_types.head == :tuple ||
                error("PRECOMPILE_ARGUMENT_TYPES_NOT_LITERAL_TUPLE")
            signature = Expr(
                :curly,
                :Tuple,
                Expr(:call, :typeof, expression.args[2]),
                argument_types.args...,
            )
        else
            signature = expression.args[2]
        end
        if signature isa Symbol && haskey(bindings, signature)
            signature = bindings[signature]
        elseif signature isa Expr &&
               signature.head == :curly &&
               length(signature.args) == 3 &&
               signature.args[1] == :Tuple &&
               haskey(bindings, :signature)
            # The owned extension bridge uses `signature.parameters...` to
            # precompile the same path through `_first_solve_compile_call`.
            tail = signature.args[3]
            if tail isa Expr &&
               tail.head == :... &&
               bindings[:signature] isa Expr &&
               bindings[:signature].head == :curly
                signature =
                    Expr(:curly, :Tuple, signature.args[2], bindings[:signature].args[2:end]...)
            end
        end
        signature = expand_local_signature(signature, bindings)
        lookup = signature
        derived = false
        if signature isa Expr &&
           signature.head == :curly &&
           length(signature.args) >= 3 &&
           signature.args[1] == :Tuple &&
           (
               signature.args[2] in CERTIFIED_LEGACY_COMPILER_BRIDGES ||
               signature.args[2] in ADDITIONAL_CERTIFIED_BRIDGES
           )
            # These package-owned noinline bridges are compiled but not
            # invoked by the user workload. A bridge gets provenance only
            # when the exact underlying call was observed in a real trace.
            lookup = Expr(:curly, :Tuple, signature.args[3:end]...)
            derived = true
        end
        push!(result, (; signature = ast_text(signature), lookup = ast_text(lookup), derived))
    end
    for child in expression.args
        source_calls!(result, child, bindings)
    end
end

function retained_signatures(root)
    rows = NamedTuple[]
    files = String[]
    for parent in ("src", "ext")
        for (directory, _, names) in walkdir(joinpath(root, parent))
            for name in names
                endswith(name, ".jl") || continue
                push!(files, relpath(joinpath(directory, name), root))
            end
        end
    end
    for relative in sort!(files)
        relative = replace(relative, '\\' => '/')
        found = NamedTuple[]
        source_calls!(
            found,
            Meta.parseall(read(joinpath(root, relative), String)),
            Dict{Symbol, Any}(),
        )
        for (index, call) in enumerate(found)
            push!(rows, (; owner = relative, index, call...))
        end
    end
    return rows
end

# Resolve the actual evidence directory from the authoritative completed index.
# A prelaunch-only pause may leave an empty canonical directory; never rename
# that historical attempt or silently read it instead of a successful continuation.
function indexed_trace_directory(directory, row, size, trace_source; expected = nothing)
    expected===nothing && (
        expected=(
            source = source_digest(trace_source),
            manifest = digest(read(joinpath(trace_source, "Manifest.toml"))),
            source_manifest = digest(read(joinpath(trace_source, "SOURCE_MANIFEST.tsv"))),
        )
    )
    row.source_src_ext_sha256==expected.source || error("INDEX_TRACE_SOURCE_MISMATCH")
    row.manifest_sha256==expected.manifest || error("INDEX_TRACE_MANIFEST_MISMATCH")
    row.source_manifest_sha256==expected.source_manifest || error("INDEX_SOURCE_MANIFEST_MISMATCH")
    length(row.ranks)==size && Set(Int(r.rank) for r in row.ranks)==Set(0:(size - 1)) ||
        error("INDEX_INCOMPLETE_TRACE_RANKS")
    destinations=String[]
    for rank in row.ranks
        path=normpath(joinpath(abspath(directory), String(rank.target_trace)))
        startswith(relpath(path, abspath(directory)), "..") &&
            error("INDEX_TARGET_OUTSIDE_EVIDENCE")
        isfile(path) || error("INDEX_TARGET_MISSING")
        digest(read(path))==rank.target_trace_sha256 || error("INDEX_TARGET_SHA256_MISMATCH")
        push!(destinations, dirname(path))
    end
    length(unique(destinations))==1 || error("INDEX_TARGET_DIRECTORY_MISMATCH")
    return only(unique(destinations))
end

function read_trace_index(registry, serial, mpi, trace_source)
    index = Dict{String, Set{String}}()
    trace_hashes = Dict{String, Set{String}}()
    manifest_hash = digest(read(joinpath(trace_source, "Manifest.toml")))
    source_hash = digest(read(joinpath(trace_source, "SOURCE_MANIFEST.tsv")))
    source_identity=(
        source = source_digest(trace_source),
        manifest = manifest_hash,
        source_manifest = source_hash,
    )
    for (directory, size) in ((serial, 1), (mpi, 12))
        directory == "-" && continue  # diagnostic inventory only; never passes --check
        index_path=joinpath(directory, "index.json")
        isfile(index_path) || error("MISSING_COMPLETE_TRACE_INDEX")
        actual_rows=JSON3.read(read(index_path, String))
        indexed=Dict(String(r.id)=>r for r in actual_rows)
        length(actual_rows)==length(registry)==length(indexed) &&
        Set(keys(indexed))==Set(String(r.id) for r in registry) ||
            error("INCOMPLETE_OR_DUPLICATE_REGISTRY_INDEX")
        for row in registry
            id = String(row.id)
            indexed_row=indexed[id]
            RAW_ORIGIN_SOURCES["$(id)@$(size)"]=String(indexed_row.source_src_ext_sha256)
            actual_directory=indexed_trace_directory(
                directory,
                indexed_row,
                size,
                trace_source;
                expected = source_identity,
            )
            receipt_path = joinpath(actual_directory, "receipt.json")
            isfile(receipt_path) || error("MISSING_PATH_TRACE: $(id), size=$(size)")
            receipt = JSON3.read(read(receipt_path, String))
            receipt.return_code == 0 && receipt.stop_reason===nothing ||
                error("FAILED_PATH_TRACE: $(id), size=$(size)")
            indexed_row.runner_sha256==receipt.runner_sha256 ||
                error("INDEX_RUNNER_SHA256_MISMATCH")
            receipt.manifest_sha256 == manifest_hash || error("TRACE_MANIFEST_IDENTITY_MISMATCH")
            receipt.source_manifest_sha256 == source_hash ||
                error("TRACE_SOURCE_MANIFEST_IDENTITY_MISMATCH")
            length(receipt.traces) == size || error("INCOMPLETE_RANK_TRACES: $(id), size=$(size)")
            for rank in 0:(size - 1)
                filename = "rank_$(rank).jl"
                haskey(receipt.traces, Symbol(filename)) ||
                    error("MISSING_RANK_TRACE: $(id), size=$(size), rank=$(rank)")
                path = joinpath(actual_directory, "trace", filename)
                hash = digest(read(path))
                receipt.traces[Symbol(filename)] == hash || error("TRACE_SHA256_MISMATCH")
                phase_record=JSON3.read(
                    read(joinpath(actual_directory, "output", "rank_$(rank).json"), String),
                )
                raw=read(path)
                before=Int(phase_record.first_call_trace_bytes_before)
                after=Int(phase_record.first_call_trace_bytes_after)
                0<=before<=after<=length(raw)||error("INVALID_TRACE_PHASE_INTERVAL")
                indexed_rank=only(filter(r->Int(r.rank)==rank, indexed_row.ranks))
                target_path=normpath(joinpath(directory, String(indexed_rank.target_trace)))
                raw[(before + 1):after]==read(target_path) ||
                    error("INDEX_TARGET_NOT_ACTUAL_FIRST_CALL_INTERVAL")
                for (phase, part) in (
                    ("outside_first_call_before", raw[1:before]),
                    ("first_call_compile_request", raw[(before + 1):after]),
                    ("outside_first_call_after", raw[(after + 1):end]),
                )
                    signatures=String[]
                    trace_calls!(signatures, Meta.parseall(String(part)))
                    for signature in signatures
                        push!(
                            get!(index, signature, Set{String}()),
                            "$(id)@$(size):$(rank):$(phase)",
                        )
                        push!(get!(trace_hashes, signature, Set{String}()), hash)
                    end
                end
            end
        end
    end
    return index, trace_hashes
end

function include_expert_traces!(index, trace_hashes, index_path, manifest_hash, source_hash)
    index_path == "-" && return
    root = dirname(abspath(index_path))
    rows = JSON3.read(read(index_path, String))
    ids = Set{String}()
    for row in rows
        id = String(row.id)
        id in ids && error("DUPLICATE_EXPERT_TRACE_ID: $(id)")
        push!(ids, id)
        row.manifest_sha256 == manifest_hash || error("EXPERT_TRACE_MANIFEST_MISMATCH")
        observation_source_matches(row.source_src_ext_sha256, source_hash) ||
            error("EXPERT_TRACE_SOURCE_IDENTITY_MISMATCH: $(id)")
        row.trace_scope == "first_successful_public_call_byte_interval" ||
            error("EXPERT_TRACE_NOT_TARGET_SCOPED: $(id)")
        digest(read(String(row.fixture_path))) == row.fixture_sha256 ||
            error("EXPERT_FIXTURE_SHA256_MISMATCH: $(id)")
        digest(read(String(row.runner_path))) == row.runner_sha256 ||
            error("EXPERT_RUNNER_SHA256_MISMATCH: $(id)")
        observations = haskey(row, :rank_traces) ? row.rank_traces : [row]
        sizevalue = haskey(row, :mpi_size) ? Int(row.mpi_size) : 1
        sizevalue > 0 || error("INVALID_EXPERT_MPI_SIZE")
        RAW_ORIGIN_SOURCES["$(id)@$(sizevalue)"]=String(row.source_src_ext_sha256)
        if haskey(row, :rank_traces)
            Set(Int(o.rank) for o in observations)==Set(0:(sizevalue - 1)) &&
            length(observations)==sizevalue || error("INCOMPLETE_EXPERT_MPI_RANKS")
        end
        for observation in observations
            rankvalue = haskey(observation, :rank) ? Int(observation.rank) : 0
            0 <= rankvalue < sizevalue || error("INVALID_EXPERT_MPI_RANK")
            label = "$(id)@$(sizevalue):$(rankvalue)"
            path = normpath(joinpath(root, String(observation.trace)))
            startswith(relpath(path, root), "..") && error("EXPERT_TRACE_OUTSIDE_EVIDENCE")
            hash = digest(read(path))
            hash == observation.sha256 || error("EXPERT_TRACE_SHA256_MISMATCH")
            for signature in trace_signatures(path)
                push!(get!(index, signature, Set{String}()), label)
                push!(get!(trace_hashes, signature, Set{String}()), hash)
            end
            # Same exact Type-equality matching. Rank labels only describe the
            # actual observation; native and inference remain distinct kinds.
            if haskey(observation, :inference)
                inference_path = normpath(joinpath(root, String(observation.inference)))
                startswith(relpath(inference_path, root), "..") &&
                    error("INFERENCE_TRACE_OUTSIDE_EVIDENCE")
                inference_hash = digest(read(inference_path))
                inference_hash == observation.inference_sha256 ||
                    error("INFERENCE_TRACE_SHA256_MISMATCH")
                for frame in JSON3.read(read(inference_path, String))
                    signature = String(frame.signature)
                    push!(get!(index, signature, Set{String}()), label * ":inference")
                    push!(get!(trace_hashes, signature, Set{String}()), inference_hash)
                end
            end
        end
    end
end

const TRACE_THREAD_NAME_MAP=Dict{String, String}()
const TRACE_THREAD_PROOF_HASHES=Set{String}()
proof_artifact(proof_path, value) =
    isabspath(String(value)) ? String(value) :
    normpath(joinpath(dirname(abspath(proof_path)), String(value)))

function load_thread_name_proof!(path)
    isempty(path)&&return
    d=JSON3.read(read(path, String))
    hasproperty(d, :source_src_ext_sha256) &&
        !observation_source_matches(d.source_src_ext_sha256) &&
        error("THREAD_PROOF_SOURCE_IDENTITY_MISMATCH")
    hasproperty(d, :julia) && d.julia != string(VERSION) && error("THREAD_PROOF_JULIA_MISMATCH")
    old=JSON3.read(read(joinpath(proof_artifact(path, d.old.folder), "descriptors.json"), String))
    new=JSON3.read(read(joinpath(proof_artifact(path, d.new.folder), "descriptors.json"), String))
    samefile(String(old.source), ROOT)||error("THREAD_PROOF_CURRENT_SOURCE_MISMATCH")
    observation_source_matches(source_digest(String(new.source))) ||
        error("THREAD_PROOF_TRACED_SOURCE_MISMATCH")
    old.julia == new.julia == string(VERSION) || error("THREAD_PROOF_JULIA_MISMATCH")
    if hasproperty(d, :descriptor_sha256)
        digest(read(joinpath(proof_artifact(path, d.old.folder), "descriptors.json"))) ==
        d.descriptor_sha256[1] || error("THREAD_DESCRIPTOR_SHA_MISMATCH")
        digest(read(joinpath(proof_artifact(path, d.new.folder), "descriptors.json"))) ==
        d.descriptor_sha256[2] || error("THREAD_DESCRIPTOR_SHA_MISMATCH")
    end
    for suffix in (
        "#threadsfor_fun#576",
        "#threadsfor_fun#573#577",
        "#threadsfor_fun#809",
        "#threadsfor_fun#805#810",
    )
        rows=filter(r->endswith(String(r.old_binding), suffix), d.rows)
        length(rows)==1||error("THREAD_PROOF_CALLSITE_NOT_UNIQUE")
        row=only(rows)
        row.unique && length(row.new_candidates)==1||error("THREAD_PROOF_LAYOUT_NOT_UNIQUE")
        current=String(row.old_binding);
        traced=String(only(row.new_candidates))
        isdefined(
            WannierNLQG.Runtime,
            Symbol(current),
        )||error("THREAD_PROOF_CURRENT_BINDING_MISSING")
        a=only(filter(r->String(r.binding)==current, old.rows))
        b=only(filter(r->String(r.binding)==traced, new.rows))
        a.stable_method_layout_key==b.stable_method_layout_key==row.stable_method_layout_key||error(
            "THREAD_PROOF_KEY_MISMATCH",
        )
        TRACE_THREAD_NAME_MAP["WannierNLQG.Runtime.var\"" * traced * "\""]="WannierNLQG.Runtime.var\""*current*"\""
    end
    for file in (
        path,
        joinpath(proof_artifact(path, d.old.folder), "descriptors.json"),
        joinpath(proof_artifact(path, d.new.folder), "descriptors.json"),
    )
        push!(TRACE_THREAD_PROOF_HASHES, digest(read(file)))
    end
end

const ACTUAL_INFERRED_TYPES = Dict{String, Any}()
function evaluated_type(context_module, text)
    haskey(ACTUAL_INFERRED_TYPES, text) && return ACTUAL_INFERRED_TYPES[text]
    for (traced, current) in TRACE_THREAD_NAME_MAP
        text=replace(text, traced=>current)
    end
    # Julia's trace printer renders Char parameters as Char(0xNN000000),
    # which is not a valid source constructor for the same value.
    normalized = replace(
        text,
        r"Char\(0x([0-9a-fA-F]{8})\)" =>
            m -> "reinterpret(Char, UInt32(0x$(match(r"0x([0-9a-fA-F]{8})", m).captures[1])))",
    )
    expression = Meta.parse(normalized)
    expression isa Expr && expression.head == :quote && (expression = expression.args[1])
    # Audit-only process: bind optional module aliases once, then evaluate
    # the type expression directly. This avoids one compiled let thunk for
    # each of tens of thousands of trace rows. Existing bindings must agree.
    for name in (
        :StaticArrays,
        :StaticArraysCore,
        :CrystallographyCore,
        :WannierNLQGOperatorBundleExt,
        :StructTypes,
        :spglib_jll,
        :Serialization,
    )
        isdefined(Main, name)||continue
        desired=getfield(Main, name)
        if isdefined(context_module, name)
            getfield(context_module, name)===desired||error("AUDIT_ALIAS_IDENTITY_MISMATCH")
        else
            Core.eval(context_module, Expr(:(=), name, QuoteNode(desired)))
        end
    end
    value = Core.eval(context_module, expression)
    value isa Type || error("NOT_A_TYPE")
    return value
end

function owner_modules(owner)
    options = Module[]
    if startswith(owner, "ext/")
        extension = Base.get_extension(WannierNLQG, Symbol(split(owner, '/')[2]))
        extension !== nothing && push!(options, extension)
    else
        segments = split(owner, '/')
        if length(segments) > 2
            name = Symbol(segments[2])
            isdefined(WannierNLQG, name) &&
                getproperty(WannierNLQG, name) isa Module &&
                push!(options, getproperty(WannierNLQG, name))
        end
        push!(options, WannierNLQG)
    end
    for parent in copy(options)
        for name in names(parent; all = true)
            isdefined(parent, name) || continue
            value = getproperty(parent, name)
            value isa Module && parentmodule(value) === parent && push!(options, value)
        end
    end
    return unique(options)
end

function enrich_semantic_provenance!(rows, index, trace_hashes)
    # Resolve only unmatched declarations, in the frozen package world. This
    # avoids counting textual differences in pretty-printed Julia types as
    # missing provenance. Failed evaluations are never accepted as matches.
    samefile(pkgdir(WannierNLQG), ROOT) || error(
        "AUDIT_PACKAGE_SOURCE_IDENTITY_MISMATCH: loaded=$(pkgdir(WannierNLQG)) expected=$(ROOT)",
    )
    WannierNLQG.SymmetryFoundation.symmetry_detection_backend_provenance()
    WannierNLQG.Wannierization._load_wannierization_extension!()
    for loaded_module in Base.loaded_modules_array()
        name = nameof(loaded_module)
        isdefined(Main, name) || Core.eval(Main, Expr(:(=), name, loaded_module))
    end
    isdefined(Main, :StructTypes) || Core.eval(Main, :(StructTypes = JSON3.StructTypes))
    # Inference collector explicitly prints specTypes with module=>Base.Core.
    # Core-owned names are therefore intentionally unqualified in that corpus.
    # Bind only absent names that actually exist in Base.Core; keep exact Type
    # equality and never guess a Base/package function from a similar name.
    core_alias_rows = Any[]
    for symbol in names(Base.Core; all = true, imported = false)
        isdefined(Base.Core, symbol) || continue
        isdefined(Main, symbol) && continue
        value=getfield(Base.Core, symbol)
        try
            Core.eval(Main, Expr(:(=), symbol, QuoteNode(value)))
            getfield(Main, symbol)===value || error("CORE_PRINT_ALIAS_IDENTITY")
            push!(
                core_alias_rows,
                (
                    name = String(symbol),
                    owner = "Base.Core",
                    value_type = string(typeof(value)),
                    identity_verified = true,
                ),
            )
        catch exception
            push!(
                core_alias_rows,
                (
                    name = String(symbol),
                    owner = "Base.Core",
                    error = sprint(showerror, exception),
                    identity_verified = false,
                ),
            )
        end
    end
    alias_output=get(ENV, "FIRSTUSE_AUDIT_CORE_ALIAS_PROOF", "")
    isempty(alias_output) || write(
        alias_output,
        JSON3.write((
            scope = "inference show context Base.Core; namespace reconstruction only, no provenance by name",
            aliases = core_alias_rows,
        )),
    )
    MPI.Initialized() && error("PROVENANCE_AUDIT_INITIALIZED_MPI")

    println("semantic phase: ", length(index), " distinct trace signatures");
    flush(stdout)
    # Resolve source declarations first. Traces can then be screened by the
    # actual callable Type value, never by name similarity. Full Type equality
    # remains the only attribution rule after this conservative screen.
    source_values=Dict{Tuple{String, Int}, Any}()
    wanted_callables=Set{Any}()
    any_callable=false
    function callable_key(value)
        body=Base.unwrap_unionall(value)
        body isa DataType && body<:Tuple || return nothing
        p=body.parameters
        isempty(p) && return nothing
        head=p[1]
        if head===typeof(Base.Core.kwcall)
            length(p)>=3||return nothing
            head=p[3]
        end
        return head isa TypeVar ? nothing : head
    end
    source_cache=Dict{Tuple{Module, String}, Any}()
    for row in rows
        isempty(get(index, row.lookup, Set{String}()))||continue
        occursin("try_close_finalizer", row.signature)&&occursin("type", row.signature)&&continue
        value=nothing
        for context_module in owner_modules(row.owner)
            ck=(context_module, row.lookup)
            if haskey(source_cache, ck)
                value=source_cache[ck]
            else
                value=try
                    evaluated_type(context_module, row.lookup)
                catch
                    ;
                    nothing
                end
                source_cache[ck]=value
            end
            value===nothing||break
        end
        source_values[(row.owner, row.index)]=value
        value===nothing&&continue
        ck=callable_key(value)
        ck===nothing ? (any_callable=true) : push!(wanted_callables, ck)
    end
    push!(wanted_callables, typeof(HDF5.API.try_close_finalizer))
    println("semantic callable screen: ", length(wanted_callables), "; wildcard=", any_callable);
    flush(stdout)
    trace_head_cache=Dict{String, Any}()
    # Parse only the callable argument when the printer emits Tuple{...}.
    # Nested braces/parentheses and quoted generated names are balanced; any
    # unsupported shape falls back to the complete Julia AST. Unknown heads
    # are never excluded. The full tuple is still resolved before attribution.
    function tuple_prefix_arguments(text, requested)
        startswith(text, "Tuple{") || return nothing
        result=String[];
        start=7;
        braces=1;
        parens=0;
        brackets=0
        quoted=false;
        escaped=false
        for i in eachindex(text)
            i<7 && continue
            c=text[i]
            if quoted
                if escaped
                    escaped=false
                elseif c=='\\'
                    escaped=true
                elseif c=='"'
                    quoted=false
                end
                continue
            elseif c=='"'
                quoted=true;
                continue
            end
            if (c==',' || c=='}') && braces==1 && parens==0 && brackets==0
                push!(result, strip(String(SubString(text, start, prevind(text, i)))))
                length(result)>=requested && return result
                c=='}' && return nothing
                start=nextind(text, i);
                continue
            end
            c=='{' && (braces+=1)
            c=='}' && (braces-=1)
            c=='(' && (parens+=1)
            c==')' && (parens-=1)
            c=='[' && (brackets+=1)
            c==']' && (brackets-=1)
            min(braces, parens, brackets)<0 && return nothing
        end
        return nothing
    end
    function trace_callable(text)
        function evaluate_head_text(k)
            return get!(trace_head_cache, k) do
                try
                    evaluated_type(Main, k)
                catch
                    ;
                    nothing
                end
            end
        end
        args=tuple_prefix_arguments(text, 1)
        if args!==nothing
            head=evaluate_head_text(args[1])
            if head===typeof(Base.Core.kwcall)
                args=tuple_prefix_arguments(text, 3)
                args===nothing || return evaluate_head_text(args[3])
            else
                return head
            end
        end
        ex=Meta.parse(text)
        ex isa Expr && ex.head==:quote && (ex=only(ex.args))
        while ex isa Expr && ex.head==:where
            ex=ex.args[1]
        end
        ex isa Expr && ex.head==:curly && ex.args[1]==:Tuple||return nothing
        head=evaluate_head_text(ast_text(ex.args[2]))
        if head===typeof(Base.Core.kwcall)
            length(ex.args)>=4||return nothing
            head=evaluate_head_text(ast_text(ex.args[4]))
        end
        return head
    end
    by_type = Dict{Any, Set{String}}()
    hashes_by_type = Dict{Any, Set{String}}()
    trace_failures = 0
    failed_trace_rows=Any[]
    for (trace_number, (text, observations)) in enumerate(index)
        trace_number % 2000 == 0 &&
            (println("semantic trace progress: ", trace_number); flush(stdout))
        try
            head=trace_callable(text)
            # An undecidable head is included, never silently excluded.
            if !any_callable && head!==nothing && !(head in wanted_callables)
                continue
            end
            value = evaluated_type(Main, text)
            union!(get!(by_type, value, Set{String}()), observations)
            union!(get!(hashes_by_type, value, Set{String}()), trace_hashes[text])
            if any(occursin(k, text) for k in keys(TRACE_THREAD_NAME_MAP))
                union!(hashes_by_type[value], TRACE_THREAD_PROOF_HASHES)
            end
        catch err
            trace_failures += 1
            push!(
                failed_trace_rows,
                (
                    signature = text,
                    error = sprint(showerror, err),
                    observations = sort!(collect(observations)),
                    trace_hashes = sort!(collect(trace_hashes[text])),
                ),
            )
        end
    end
    classifications = Dict{Tuple{String, Int}, String}()
    semantic_observations = Dict{Tuple{String, Int}, Set{String}}()
    semantic_hashes = Dict{Tuple{String, Int}, Set{String}}()
    unresolved_sources = 0
    for (source_number, row) in enumerate(rows)
        source_number % 1000 == 0 &&
            (println("semantic source progress: ", source_number); flush(stdout))
        isempty(get(index, row.lookup, Set{String}())) || continue
        key = (row.owner, row.index)
        if row.owner ==
           "ext/WannierNLQGWannierizationPrecompileExt/FinalizerEntryInitialization.jl" &&
           occursin("type", row.signature)
            initializer = read(joinpath(ROOT, row.owner), String)
            matched = match(r"for type in \((.*?)\)"s, initializer)
            matched === nothing && error("RUNTIME_INITIALIZER_TYPE_INVENTORY_MISSING")
            names = filter(!isempty, strip.(split(matched.captures[1], ',')))
            length(names) == 16 && length(unique(names)) == 16 ||
                error("RUNTIME_INITIALIZER_TYPE_INVENTORY_CHANGED")
            observations = Set{String}()
            hashes = Set{String}()
            missing = String[]
            for name in names
                instance =
                    evaluated_type(Main, "Tuple{typeof(HDF5.API.try_close_finalizer)," * name * "}")
                if !haskey(by_type, instance)
                    push!(missing, name)
                else
                    union!(observations, by_type[instance])
                    union!(hashes, hashes_by_type[instance])
                end
            end
            if isempty(missing)
                classifications[key] = "RUNTIME_INITIALIZER_16_INSTANCES_TRACED"
                semantic_observations[key] = observations
                semantic_hashes[key] = hashes
            else
                classifications[key] = "UNOBSERVED_RUNTIME_INSTANCES"
                println("unobserved runtime initializer instances: ", join(missing, ","))
            end
            continue
        end
        value = get(source_values, key, nothing)
        if value === nothing
            classifications[key] = "UNRESOLVED_SOURCE"
            unresolved_sources += 1
        elseif haskey(by_type, value)
            # The same printed expression may appear under different owner
            # modules. Never promote one owner's semantic match to a global
            # text match for the next declaration.
            semantic_observations[key] = by_type[value]
            semantic_hashes[key] = hashes_by_type[value]
            classifications[key] = "SEMANTIC_TRACED"
        else
            classifications[key] = "UNOBSERVED"
        end
    end
    failure_file=get(ENV, "FIRSTUSE_AUDIT_TRACE_FAILURES", "")
    isempty(failure_file)||write(failure_file, JSON3.write(failed_trace_rows))
    println(
        "semantic audit: $(trace_failures) unresolved trace expressions, $(unresolved_sources) unresolved source expressions",
    )
    return classifications, semantic_observations, semantic_hashes
end

function provenance_text(
    rows,
    index,
    trace_hashes,
    classifications,
    semantic_observations,
    semantic_hashes,
    source_hash,
    julia_version,
    manifest_hash,
)
    stream = IOBuffer()
    println(
        stream,
        "owner\tordinal\tsignature_sha256\tstatus\tpath_ids\trank_observations\ttrace_set_sha256\tanonymous\tsource_sha256\tjulia\tmanifest_sha256\traw_origin_source_sha256\tsource_equivalence_certificate_sha256",
    )
    gaps = 0
    for row in rows
        key = (row.owner, row.index)
        observations =
            sort!(collect(get(semantic_observations, key, get(index, row.lookup, Set{String}()))))
        paths = sort!(unique(first(split(value, '@')) for value in observations))
        hashes =
            sort!(collect(get(semantic_hashes, key, get(trace_hashes, row.lookup, Set{String}()))))
        classification = get(classifications, key, "")
        isempty(paths) && (gaps += 1)
        inference_only =
            !isempty(observations) && all(endswith(value, ":inference") for value in observations)
        status = if inference_only && row.derived
            "DERIVED_BRIDGE_INFERENCE_DEPENDENCY"
        elseif inference_only
            "INFERENCE_DEPENDENCY_TRACED"
        elseif classification == "SEMANTIC_TRACED" && row.derived
            "DERIVED_BRIDGE_SEMANTIC"
        elseif !isempty(classification)
            classification
        elseif isempty(paths)
            "UNOBSERVED"
        elseif row.derived
            "DERIVED_BRIDGE"
        else
            "TRACED"
        end
        println(
            stream,
            join(
                (
                    row.owner,
                    row.index,
                    digest(codeunits(row.signature)),
                    status,
                    join(paths, ","),
                    length(observations),
                    digest(join(hashes, "\n")),
                    occursin("var\"#", row.signature),
                    source_hash,
                    julia_version,
                    manifest_hash,
                    join(
                        sort!(
                            unique(RAW_ORIGIN_SOURCES[first(split(o, ':'))] for o in observations),
                        ),
                        ",",
                    ),
                    SOURCE_EQUIVALENCE[]===nothing ? "" :
                    digest(read(ENV["FIRSTUSE_SOURCE_EQUIVALENCE"])),
                ),
                '\t',
            ),
        )
    end
    return String(take!(stream)), gaps
end

# Exact MethodInstance.specTypes fallback for Julia's non-parseable dotted
# NamedTuple field printer. Never reconstruct a Type from similar text.
function load_exact_actual_type_proof!(path, index, trace_hashes, source_hash, manifest_hash)
    proof=JSON3.read(read(path, String))
    observation_source_matches(proof.source_src_ext_sha256, source_hash) ||
        error("ACTUAL_TYPE_SOURCE_MISMATCH")
    proof.manifest_sha256==manifest_hash || error("ACTUAL_TYPE_MANIFEST_MISMATCH")
    for (file_key, hash_key) in (
        (:file, :sha256),
        (:runner_path, :runner_sha256),
        (:trace_index, :trace_index_sha256),
        (:original_capture_file, :original_capture_sha256),
        (:original_inference_file, :original_inference_sha256),
        (:lossless_reduction_runner, :lossless_reduction_runner_sha256),
        (:original_parse_failures_file, :original_parse_failures_sha256),
    )
        digest(
            read(proof_artifact(path, getproperty(proof, file_key))),
        )==getproperty(proof, hash_key) || error("ACTUAL_TYPE_ARTIFACT_SHA_MISMATCH: $(file_key)")
    end
    observation=String(proof.observation)
    row=only(
        filter(
            r->String(r.id)==first(split(observation, "@")),
            JSON3.read(read(proof_artifact(path, proof.trace_index), String)),
        ),
    )
    row.actual_types_sha256==proof.original_capture_sha256 ||
        error("ACTUAL_TYPE_ORIGINAL_INDEX_SHA_MISMATCH")
    row.inference_sha256==proof.original_inference_sha256 ||
        error("ACTUAL_TYPE_ORIGINAL_INFERENCE_INDEX_SHA_MISMATCH")
    original=Serialization.deserialize(proof_artifact(path, proof.original_capture_file))
    frames=JSON3.read(read(proof_artifact(path, proof.original_inference_file), String))
    length(original)==length(frames) || error("ACTUAL_TYPE_FRAME_COUNT_MISMATCH")
    required=Set(String.(proof.required_printed_keys))
    failures=JSON3.read(read(proof_artifact(path, proof.original_parse_failures_file), String))
    dotted=Set(
        String(f.signature) for
        f in failures if startswith(String(f.error), "TypeError: in Type, in parameter") &&
        occursin("topology.num_kpts::", String(f.signature)) &&
        observation in String.(f.observations)
    )
    required==dotted && !isempty(required) || error("ACTUAL_TYPE_REQUESTED_SCOPE_CHANGED")
    originals=Dict{String, Any}()
    for (ordinal, value) in enumerate(original)
        printed=String(frames[ordinal].signature)
        if value isa Pair
            first(value)==printed || error("ACTUAL_TYPE_FRAME_ORDER_MISMATCH")
            value=last(value)
        end
        printed in required || continue
        value isa Type || error("ACTUAL_INFERENCE_NOT_TYPE")
        sprint(show, value; context = :module=>Base.Core)==printed ||
            error("ACTUAL_TYPE_PRINT_IDENTITY")
        haskey(originals, printed) &&
            originals[printed]!==value &&
            error("ACTUAL_TYPE_INCONSISTENT")
        originals[printed]=value
    end
    reduced=Serialization.deserialize(proof_artifact(path, proof.file))
    length(reduced)==length(required) && Set(first.(reduced))==required ||
        error("ACTUAL_DOTTED_TYPES_INCOMPLETE")
    for (printed, value) in reduced
        haskey(originals, printed) && originals[printed]===value ||
            error("ACTUAL_TYPE_NOT_ORIGINAL_FRAME_TYPE")
        haskey(index, printed) && observation in index[printed] ||
            error("ACTUAL_TYPE_NO_ORIGINAL_REAL_OBSERVATION")
        ACTUAL_INFERRED_TYPES[printed]=value
        push!(get!(trace_hashes, printed, Set{String}()), String(proof.sha256))
    end
    Set(keys(ACTUAL_INFERRED_TYPES))==required || error("ACTUAL_DOTTED_TYPES_INCOMPLETE")
    println("exact original MethodInstance dotted-field Types verified: ", length(required));
    flush(stdout)
end

function main(arguments)
    length(arguments) in (6, 7) || error(
        "usage: audit_signatures.jl --write|--check registry.json serial_traces mpi_traces trace_source output.tsv [expert_index.json]",
    )
    mode, registry_path, serial, mpi, trace_source, output = arguments[1:6]
    experts = length(arguments) == 7 ? arguments[7] : "-"
    mode in ("--write", "--check") || error("expected --write or --check")
    mode == "--check" && mpi == "-" && error("MPI traces required for release check")
    mode == "--check" && experts == "-" && error("expert traces required for release check")
    registry = JSON3.read(read(registry_path, String))
    length(registry) == 52 && length(Set(String(row.id) for row in registry)) == 52 ||
        error("registry must contain 52 unique paths")
    trace_source = abspath(trace_source)
    source_hash = source_digest(ROOT)
    (source_hash == source_digest(trace_source) || original_trace_source_matches(trace_source)) ||
        error("TRACE_COMPUTATION_SOURCE_MISMATCH")
    index, trace_hashes = read_trace_index(registry, serial, mpi, trace_source)
    # Additional inferred dependencies come from the same real run(cfg) interval.
    # Keep their observation kind distinct from native execution/compile requests.
    for directory in (serial, mpi)
        directory == "-" && continue
        index_path = joinpath(directory, "index.json")
        isfile(index_path) || error("MISSING_REGISTRY_INFERENCE_INDEX")
        for row in JSON3.read(read(index_path, String))
            observation_source_matches(row.source_src_ext_sha256, source_hash) ||
                error("INFERENCE_SOURCE_MISMATCH")
            row.manifest_sha256 == digest(read(joinpath(trace_source, "Manifest.toml"))) ||
                error("INFERENCE_MANIFEST_MISMATCH")
            for rank in row.ranks
                get(rank, :inference_collected, true)||continue
                path = joinpath(directory, String(rank.inference))
                hash = digest(read(path))
                hash == rank.inference_sha256 || error("INFERENCE_SHA256_MISMATCH")
                size = directory == serial ? 1 : 12
                observation = "$(row.id)@$(size):$(rank.rank):inference"
                for frame in JSON3.read(read(path, String))
                    signature = String(frame.signature)
                    push!(get!(index, signature, Set{String}()), observation)
                    push!(get!(trace_hashes, signature, Set{String}()), hash)
                end
            end
        end
    end
    load_thread_name_proof!(get(ENV, "FIRSTUSE_THREAD_BINDING_PROOF", ""))
    rows = retained_signatures(ROOT)
    focus_file=get(ENV, "FIRSTUSE_AUDIT_FOCUS_ROWS", "")
    if !isempty(focus_file)
        mode=="--write"||error("FOCUSED_AUDIT_IS_DIAGNOSTIC_ONLY")
        selected=Set((String(x.owner), Int(x.index)) for x in JSON3.read(read(focus_file, String)))
        rows=filter(r->(r.owner, r.index) in selected, rows)
        length(rows)==length(selected)||error("FOCUS_ROW_MISSING")
        println("FOCUSED_DIAGNOSTIC_ONLY rows=", length(rows));
        flush(stdout)
    end
    write(output*".declarations.json", JSON3.write(rows))
    expected_experts=get(ENV, "FIRSTUSE_EXPERT_REGISTRY", "")
    if experts!="-" && !isempty(expected_experts)
        wanted=JSON3.read(read(expected_experts, String)).entries
        observed=JSON3.read(read(experts, String))
        Set(String(r.id) for r in wanted)==Set(String(r.id) for r in observed) ||
            error("INCOMPLETE_EXPERT_TRACE_REGISTRY")
    elseif mode=="--check"
        error("EXPERT_REGISTRY_REQUIRED_FOR_RELEASE_CHECK")
    end
    println(
        "AST inventory: ",
        length(rows),
        "; literal observed before semantic: ",
        count(r->haskey(index, r.lookup), rows),
    );
    flush(stdout)
    manifest_hash = digest(read(joinpath(trace_source, "Manifest.toml")))
    include_expert_traces!(index, trace_hashes, experts, manifest_hash, source_hash)
    additional=get(ENV, "FIRSTUSE_ADDITIONAL_TRACE_INDEX", "")
    if !isempty(additional)
        extra=JSON3.read(read(additional, String))
        valid_ids=Set(String(r.id) for r in registry)
        all(r->hasproperty(r, :base_path_id) && String(r.base_path_id) in valid_ids, extra) ||
            error("SUPPLEMENT_NOT_REGISTERED_PATH")
        include_expert_traces!(index, trace_hashes, additional, manifest_hash, source_hash)
    end
    actual_type_index=get(ENV, "FIRSTUSE_AUDIT_ACTUAL_TYPED_INDEX", "")
    isempty(actual_type_index) || load_exact_actual_type_proof!(
        actual_type_index,
        index,
        trace_hashes,
        source_hash,
        manifest_hash,
    )
    classifications, semantic_observations, semantic_hashes =
        enrich_semantic_provenance!(rows, index, trace_hashes)
    value, gaps = provenance_text(
        rows,
        index,
        trace_hashes,
        classifications,
        semantic_observations,
        semantic_hashes,
        source_hash,
        string(VERSION),
        manifest_hash,
    )
    if mode == "--write"
        write(output, value)
        println("provenance written: $(length(rows)) retained calls, $(gaps) unobserved")
    else
        isfile(output) && read(output, String) == value || error("PROVENANCE_NOT_REPRODUCIBLE")
        gaps == 0 || error("UNOWNED_RETAINED_SIGNATURES: $(gaps)")
        println("provenance check passed: $(length(rows)) retained calls")
    end
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main(ARGS)
