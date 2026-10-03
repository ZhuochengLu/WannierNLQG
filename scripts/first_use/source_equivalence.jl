# Optional, explicit raw-origin reuse. Original identities remain immutable.
# This certificate cannot qualify performance or bypass exact Type matching.
include(joinpath(@__DIR__, "compiler_append_contract.jl"))

# These are compiler declaration edits, never scientific execution equivalence.
_equivalence_strip(x) =
    x isa Expr ?
    Expr(x.head, (_equivalence_strip(a) for a in x.args if !(a isa LineNumberNode))...) : x
_equivalence_parse(s) = _equivalence_strip(Meta.parseall(s))
const OPTIONAL_COMPILER_OWNERS = Dict(
    "ext/WannierNLQGSymmetryFoundationExt/Generated/NativeCanonicalBuilderInference.jl" => "_foundation_owner_sequence",
    "ext/WannierNLQGWannierizationPrecompileExt/LocalizationFirstUseCoverage.jl" => "_record_sequence",
)
function optional_compiler_guard_contract(original, current, relative)
    haskey(OPTIONAL_COMPILER_OWNERS, relative) || error("EQUIVALENCE_UNKNOWN_COMPILER_GUARD_FILE")
    owner = OPTIONAL_COMPILER_OWNERS[relative]
    oldlookup = _equivalence_parse(
        "Base.loaded_modules[Base.PkgId(Base.UUID(\"fe0851c0-eecd-5654-98d4-656369965a5c\"),\"OpenMPI_jll\")]",
    ).args[1]
    newlookup = _equivalence_parse(
        "Base.get(Base.loaded_modules,Base.PkgId(Base.UUID(\"fe0851c0-eecd-5654-98d4-656369965a5c\"),\"OpenMPI_jll\"),nothing)",
    ).args[1]
    condition = _equivalence_parse("OpenMPI_jll !== nothing").args[1]
    hints = [
        _equivalence_parse(owner * "(Tuple{typeof(OpenMPI_jll." * f * ")})").args[1] for
        f in ("find_artifact_dir", "eager_mode")
    ]
    counters = [0, 0, 0]
    function inverse(x)
        if isequal(x, newlookup)
            counters[1] += 1
            return oldlookup
        end
        if x isa Expr && x.head === :if && length(x.args) == 2 && isequal(x.args[1], condition)
            body = x.args[2]
            if body isa Expr && body.head === :block && length(body.args) == 1
                index = findfirst(h -> isequal(body.args[1], h), hints)
                if index !== nothing
                    counters[index + 1] += 1
                    return body.args[1]
                end
            end
        end
        return x isa Expr ? Expr(x.head, (inverse(a) for a in x.args)...) : x
    end
    restored = inverse(_equivalence_parse(current))
    counters == [1, 1, 1] && isequal(_equivalence_parse(original), restored) ||
        error("EQUIVALENCE_COMPILER_GUARD_AST")
    return true
end
const REVIEWED_NAMING_GATE = "@testset \"Symmetrization production naming gate\" begin\n    package_root = normpath(joinpath(@__DIR__, \"..\"))\n    roots = (\n        joinpath(package_root, \"src\", \"Symmetrization\"),\n        joinpath(package_root, \"ext\", \"WannierNLQGSymmetrizationExt\"),\n    )\n    forbidden = (\n        r\"\\bMatrixSymmetrySpec\\b\",\n        r\"\\bSymmetrizeTBConfig\\b\",\n        r\"\\bSymmetrizeSpinConfig\\b\",\n        r\"\\bsymmetrize_tb\\b\",\n        r\"\\bsymmetrize_spin_operators\\b\",\n        r\"\\bWannierInputData\\b\",\n        r\"\\bread_wannier_input\\b\",\n        r\"\\bOrbitalOperatorSet\\b\",\n        r\"\\bconstruct_orbital_operators\\b\",\n        r\"\\brequested_operators\\b\",\n        r\"\\boutput_operators_hdf5_file\\b\",\n        r\"\\breal_space_covariance_error\\b\",\n        r\"\\b_rotate_cartesian_backwards\\b\",\n        r\"\\b_backward_operator_element\\b\",\n        r\"\\b_operator_element_norm\\b\",\n        r\"\\b_hermitianize_standard\\b\",\n        r\"\\b_apply_center_phases!\\b\",\n        r\"\\b_orbital_centers_fractional\\b\",\n        r\"\\b_nearest_center_images\\b\",\n        r\"\\b_density_centered_mesh\\b\",\n        r\"\\b_make_projection_basis\\b\",\n        r\"\\b_hybrid_basis_data\\b\",\n        r\"\\btargets\\b\",\n        r\"\\boperation_count\\b\",\n        r\"\\bsymprec\\b\",\n        r\"\\b[A-Za-z0-9_]+_cart\\b\",\n        r\"\\bSymWann\\b\",\n        r\"\\bcollinear_axis_cart\\b\",\n        r\"\\b(BB|CC|FF|OO|GG|UIU|UHU|SS|SH|SR|SHR|AA)\\b\",\n    )\n    # This exact ISO timestamp type tag belongs to Julia's Dates.DateFormat,\n    # including in compiler-only declarations; SS here denotes seconds.\n    # Keep every physical/API identifier and every other type tag in the audit.\n    timestamp_type_tag = r\"(Dates\\.DateFormat\\{\\s*):var\\\"yyyy-mm-ddTHH:MM:SS\\\"(?=\\s*,)\"\n    audit_type_tags(source) = replace(source, timestamp_type_tag => s\"\\1:iso8601_timestamp\")\n    physical_short_names = r\"\\b(BB|CC|FF|OO|GG|UIU|UHU|SS|SH|SR|SHR|AA)\\b\"\n    timestamp_declaration = \"Dates.DateFormat{ :var\\\"yyyy-mm-ddTHH:MM:SS\\\", Tuple{Dates.DatePart}}\"\n    @test !occursin(physical_short_names, audit_type_tags(timestamp_declaration))\n    for short_name in (\"BB\", \"CC\", \"FF\", \"OO\", \"GG\", \"UIU\", \"UHU\", \"SS\", \"SH\", \"SR\", \"SHR\", \"AA\")\n        @test occursin(\n            physical_short_names,\n            audit_type_tags(timestamp_declaration * \"; const \" * short_name * \" = 1\"),\n        )\n    end\n    @test occursin(physical_short_names, audit_type_tags(\"Dates.DateFormat{:SS, Tuple{}}\"))\n    @test occursin(\n        physical_short_names,\n        audit_type_tags(\"OtherType{ :var\\\"yyyy-mm-ddTHH:MM:SS\\\", Tuple{}}\"),\n    )\n    @test occursin(physical_short_names, audit_type_tags(\"const SS = :var\\\"yyyy-mm-ddTHH:MM:SS\\\"\"))\n    for root in roots, (directory, _, files) in walkdir(root), file in files\n        endswith(file, \".jl\") || continue\n        source = read(joinpath(directory, file), String)\n        for pattern in forbidden\n            audited_source = if pattern == r\"\\b[A-Za-z0-9_]+_cart\\b\"\n                replace(source, r\"\\b(wannier_centers_cart|unit_cell_cart|atoms_cart)\\b\" => \"\")\n            elseif pattern == physical_short_names\n                audit_type_tags(source)\n            else\n                source\n            end\n            @test !occursin(pattern, audited_source)\n        end\n    end\nend\n\n"
function naming_gate_parts(source)
    start = findfirst("@testset \"Symmetrization production naming gate\" begin", source)
    start === nothing && error("EQUIVALENCE_NAMING_GATE_MISSING")
    stop = findnext("@testset \"Spin-velocity stencil", source, last(start))
    stop === nothing && error("EQUIVALENCE_NAMING_GATE_BOUNDARY")
    return (
        source[begin:prevind(source, first(start))],
        source[first(start):prevind(source, first(stop))],
        source[first(stop):end],
    )
end
function naming_qualification_contract(original, current)
    a, b = naming_gate_parts(original), naming_gate_parts(current)
    isequal(_equivalence_parse(a[1]), _equivalence_parse(b[1])) &&
    isequal(_equivalence_parse(a[3]), _equivalence_parse(b[3])) ||
        error("EQUIVALENCE_NON_NAMING_TEST_CHANGED")
    isequal(_equivalence_parse(b[2]), _equivalence_parse(REVIEWED_NAMING_GATE)) ||
        error("EQUIVALENCE_NAMING_TEST_NOT_REVIEWED")
    return true
end

const EQUIVALENCE_MAINTENANCE_TOOLS = Set([
    "scripts/first_use/audit_signatures.jl",
    "scripts/first_use/compiler_append_contract.jl",
    "scripts/first_use/source_equivalence.jl",
    "scripts/first_use/provenance_shards.py",
    "scripts/check_release_whitelist.jl",
])
const EQUIVALENCE_APPEND_CONTRACTS = Dict(
    "src/FirstUse/Generated/ValidZeemanMeasuredResidual.jl" =>
        (["FIRST_USE_WORKLOAD_ENABLED", "WannierNLQG.FIRST_USE_WORKLOAD_ENABLED"], 144),
    "ext/WannierNLQGOperatorBundleExt/OperatorBundleTaskInferenceResidualCoverage.jl" =>
        (["WannierNLQG.FIRST_USE_WORKLOAD_ENABLED"], 38),
)

const SOURCE_EQUIVALENCE = Ref{Any}(nothing)
function validate_source_equivalence(path, current_root = ROOT)
    d=JSON3.read(read(path, String))
    d.schema==1 &&
    d.exact_type_matching_required &&
    d.new_full_audit_and_independent_check_required || error("EQUIVALENCE_SCHEMA")
    d.julia==string(VERSION) || error("EQUIVALENCE_JULIA")
    samefile(String(d.candidate), current_root) || error("EQUIVALENCE_CURRENT_ROOT")
    source_digest(current_root)==d.candidate_source_sha256 || error("EQUIVALENCE_CURRENT_SOURCE")
    source_digest(String(d.parent))==source_digest(String(d.original_trace_source))==d.parent_source_sha256 ||
        error("EQUIVALENCE_ORIGINAL_SOURCE")
    digest(
        read(joinpath(String(d.original_trace_source), "SOURCE_MANIFEST.tsv")),
    )==d.original_trace_source_manifest_sha256 || error("EQUIVALENCE_ORIGINAL_MANIFEST")
    digest(read(String(d.ast_qualification)))==d.ast_qualification_sha256 ||
        error("EQUIVALENCE_AST_RECEIPT")
    digest(read(String(d.frozen_original_inputs)))==d.frozen_original_inputs_sha256 ||
        error("EQUIVALENCE_INPUT_LIST")
    guard_rows = haskey(d, :optional_compiler_guards) ? d.optional_compiler_guards : []
    test_rows = haskey(d, :qualification_only_tests) ? d.qualification_only_tests : []
    guarded = Set(String(x.path) for x in guard_rows)
    qualified = Set(String(x.path) for x in test_rows)
    isempty(guarded) ||
        guarded == Set(keys(OPTIONAL_COMPILER_OWNERS)) ||
        error("EQUIVALENCE_COMPILER_GUARD_SET")
    isempty(qualified) ||
        qualified == Set(["test/symmetrization_unit.jl"]) ||
        error("EQUIVALENCE_QUALIFICATION_TEST_SET")
    length(guard_rows) == length(guarded) && length(test_rows) == length(qualified) ||
        error("EQUIVALENCE_DUPLICATE_REVIEWED_FILE")
    changed=union(Set(String(x.path) for x in d.append_rows), guarded, qualified)
    allowed=Set(String(x.path) for x in d.maintenance_tools)
    allowed == EQUIVALENCE_MAINTENANCE_TOOLS && length(d.maintenance_tools) == length(allowed) ||
        error("EQUIVALENCE_UNREVIEWED_TOOL_SCOPE")
    Set(String(x.path) for x in d.append_rows) == Set(keys(EQUIVALENCE_APPEND_CONTRACTS)) &&
    length(d.append_rows) == 2 || error("EQUIVALENCE_UNREVIEWED_APPEND_SCOPE")
    expected=Set(String(x.path) for x in d.immutable_files)
    for item in d.immutable_files
        relative=String(item.path)
        digest(read(joinpath(String(d.parent), relative)))==item.sha256 ||
            error("EQUIVALENCE_PARENT_FILE_CHANGED")
        relative in union(allowed, guarded, qualified) && continue
        digest(read(joinpath(current_root, relative)))==item.sha256 ||
            error("EQUIVALENCE_COMPUTATIONAL_FIXTURE_OR_ENVIRONMENT_CHANGED: $(relative)")
    end
    actual=Set{String}()
    for top in ("src", "ext", "test", "examples", "scripts")
        for (folder, _, names) in walkdir(joinpath(current_root, top)), name in names
            endswith(name, ".pyc") && continue
            push!(actual, replace(relpath(joinpath(folder, name), current_root), '\\'=>'/'))
        end
    end
    push!(actual, "Project.toml");
    push!(actual, "Manifest.toml")
    actual==union(expected, changed, allowed) || error("EQUIVALENCE_FILE_SET_CHANGED")
    for item in d.maintenance_tools
        digest(read(joinpath(current_root, String(item.path))))==item.sha256 ||
            error("EQUIVALENCE_TOOL_CHANGED")
    end
    for row in vcat(collect(guard_rows), collect(test_rows))
        relative = String(row.path)
        original = read(joinpath(String(d.parent), relative), String)
        current = read(joinpath(current_root, relative), String)
        digest(original) == row.original_sha256 && digest(current) == row.candidate_sha256 ||
            error("EQUIVALENCE_REVIEWED_FILE_SHA")
        if relative in guarded
            optional_compiler_guard_contract(original, current, relative)
        else
            naming_qualification_contract(original, current)
        end
    end
    count=0
    for row in d.append_rows
        relative=String(row.path);
        expected_flags, expected_count = EQUIVALENCE_APPEND_CONTRACTS[relative]
        flags = row.guard isa AbstractString ? [String(row.guard)] : String.(row.guard)
        flags == expected_flags && row.declarations == expected_count ||
            error("EQUIVALENCE_APPEND_GUARD_OR_COUNT_SCOPE")
        a=read(joinpath(String(d.parent), relative));
        b=read(joinpath(current_root, relative))
        digest(a)==row.original_sha256 && digest(b)==row.candidate_sha256 ||
            error("EQUIVALENCE_DECLARATION_FILE_CHANGED")
        length(a)==row.original_bytes && length(b)>length(a) && b[1:length(a)]==a ||
            error("EQUIVALENCE_ORIGINAL_DECLARATION_PREFIX_CHANGED")
        appended=b[(length(a) + 1):end]
        digest(appended)==row.append_sha256 && length(appended)==row.append_bytes ||
            error("EQUIVALENCE_APPEND_CHANGED")
        n=compile_append(
            String(appended),
            row.guard isa AbstractString ? String(row.guard) : String.(row.guard),
        )
        n==row.declarations || error("EQUIVALENCE_DECLARATION_COUNT")
        count+=n
    end
    count==182 || error("EQUIVALENCE_TOTAL_DECLARATIONS")
    for item in JSON3.read(read(String(d.frozen_original_inputs), String))
        digest(read(String(item.path)))==item.sha256 ||
            error("EQUIVALENCE_ORIGINAL_INPUT_CHANGED: $(item.path)")
    end
    return d
end
function load_source_equivalence!()
    path=get(ENV, "FIRSTUSE_SOURCE_EQUIVALENCE", "")
    isempty(path) && return
    SOURCE_EQUIVALENCE[]=validate_source_equivalence(path)
    println(
        "STRICT_RAW_ORIGIN_EQUIVALENCE_VALIDATED original=",
        SOURCE_EQUIVALENCE[].parent_source_sha256,
        " current=",
        SOURCE_EQUIVALENCE[].candidate_source_sha256,
    );
    flush(stdout)
end
function observation_source_matches(observed, current = source_digest(ROOT))
    observed==current && return true
    d=SOURCE_EQUIVALENCE[]
    d!==nothing && current==d.candidate_source_sha256 && observed==d.parent_source_sha256
end
function original_trace_source_matches(path)
    d=SOURCE_EQUIVALENCE[]
    d!==nothing &&
        samefile(path, String(d.original_trace_source)) &&
        source_digest(path)==d.parent_source_sha256
end
