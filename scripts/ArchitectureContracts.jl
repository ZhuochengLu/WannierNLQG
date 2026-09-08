module ArchitectureContracts

export exported_symbols,
    component_file_ownership_violations,
    component_private_reference_violations,
    component_qualified_reference_violations,
    declared_imported_symbols,
    dependency_cycle_violations,
    direct_import_records,
    direct_import_providers,
    direct_using_providers,
    bridge_ownership_violations,
    entrypoint_owner_map,
    entrypoint_owner_violations,
    exact_allowlist_violations,
    import_record_violations,
    integration_api_violations,
    integration_allowlist_violations,
    missing_documented_paths,
    private_module_boundary_violations,
    private_shared_boundary_violations,
    production_spglib_violations,
    relative_module_dependencies,
    root_module_usage_violations,
    semantic_duplicate_type_violations,
    test_api_violations,
    shared_boundary_reference_violations,
    typed_sawf_flat_config_reads,
    wannierization_bridge_symbols

# Blank comments and literal contents while preserving line structure for lexical checks.
function _code_only(source::AbstractString)
    bytes = collect(codeunits(source))
    output = copy(bytes)
    index = 1
    state = :code
    delimiter = UInt8(0)
    triple = false
    while index <= length(bytes)
        byte = bytes[index]
        if state == :code
            if byte == UInt8('#')
                output[index] = UInt8(' ')
                state = :comment
            elseif byte == UInt8('"') || byte == UInt8('\'')
                delimiter = byte
                triple =
                    byte == UInt8('"') &&
                    index + 2 <= length(bytes) &&
                    bytes[index + 1] == byte &&
                    bytes[index + 2] == byte
                output[index] = UInt8(' ')
                if triple
                    output[index + 1] = UInt8(' ')
                    output[index + 2] = UInt8(' ')
                    index += 2
                end
                state = :literal
            end
        elseif state == :comment
            if byte == UInt8('\n')
                state = :code
            else
                output[index] = UInt8(' ')
            end
        else
            if byte == UInt8('\n')
                output[index] = byte
            else
                output[index] = UInt8(' ')
            end
            if byte == UInt8('\\') && !triple
                if index < length(bytes)
                    output[index + 1] = bytes[index + 1] == UInt8('\n') ? UInt8('\n') : UInt8(' ')
                    index += 1
                end
            elseif triple &&
                   byte == delimiter &&
                   index + 2 <= length(bytes) &&
                   bytes[index + 1] == delimiter &&
                   bytes[index + 2] == delimiter
                output[index + 1] = UInt8(' ')
                output[index + 2] = UInt8(' ')
                index += 2
                state = :code
            elseif !triple && byte == delimiter
                state = :code
            end
        end
        index += 1
    end
    return String(output)
end

"""Return the normalized provider name represented by an import-path expression."""
function _import_provider_name(path)
    path isa Symbol && return string(path)
    path isa QuoteNode && return _import_provider_name(path.value)
    path isa Expr && path.head == :. || return ""
    parts = String[]
    for part in path.args
        part == Symbol(".") && continue
        name = _import_provider_name(part)
        isempty(name) || push!(parts, name)
    end
    return join(parts, ".")
end

"""Return the imported symbol name represented by an import selector expression."""
function _import_symbol_name(selector)
    selector isa Symbol && return string(selector)
    selector isa QuoteNode && return _import_symbol_name(selector.value)
    selector isa Expr && selector.head == :. || return ""
    isempty(selector.args) && return ""
    return _import_symbol_name(last(selector.args))
end

"""
Return exact direct-import records for one component root.

Each provider record distinguishes a module binding (`import Foo`/`using Foo`)
from named symbol imports (`import Foo: bar`).  Comments and strings are
ignored before parsing, so the result is a source contract rather than a
formatting convention.
"""
function direct_import_records(source::AbstractString)
    mutable_records =
        Dict{String, NamedTuple{(:module_binding, :symbols), Tuple{Bool, Set{String}}}}()
    function record!(provider::String; module_binding::Bool = false, symbols = String[])
        isempty(provider) && return
        current = get!(mutable_records, provider, (module_binding = false, symbols = Set{String}()))
        mutable_records[provider] =
            (module_binding = current.module_binding || module_binding, symbols = current.symbols)
        union!(current.symbols, symbols)
        return nothing
    end
    function visit(expression)
        expression isa Expr || return
        if expression.head in (:using, :import)
            for argument in expression.args
                if argument isa Expr && argument.head == :(:)
                    provider = _import_provider_name(first(argument.args))
                    symbols =
                        String[_import_symbol_name(selector) for selector in argument.args[2:end]]
                    any(isempty, symbols) && continue
                    record!(provider; symbols = symbols)
                else
                    record!(_import_provider_name(argument); module_binding = true)
                end
            end
        end
        foreach(visit, expression.args)
    end
    visit(Meta.parseall(_code_only(source)))
    return Dict(
        provider =>
            (module_binding = record.module_binding, symbols = sort!(collect(record.symbols))) for
        (provider, record) in mutable_records
    )
end

"""Return symbols bound by direct imports or top-level declarations."""
function declared_imported_symbols(source::AbstractString)
    symbols = Set{String}()
    for record in values(direct_import_records(source))
        union!(symbols, record.symbols)
    end
    function binding_name(expression)
        expression isa Symbol && return String(expression)
        expression isa Expr || return nothing
        expression.head in (:where, :call, :(::), :curly, :(<:)) || return nothing
        isempty(expression.args) && return nothing
        return binding_name(first(expression.args))
    end
    function visit(expression, top_level::Bool)
        expression isa Expr || return
        if top_level && expression.head == :function
            name = binding_name(first(expression.args))
            name === nothing || push!(symbols, name)
        elseif top_level && expression.head == :(=)
            name = binding_name(first(expression.args))
            name === nothing || push!(symbols, name)
        elseif top_level && expression.head == :const
            foreach(argument -> visit(argument, true), expression.args)
            return
        elseif top_level && expression.head == :struct
            length(expression.args) >= 2 || return
            name = binding_name(expression.args[2])
            name === nothing || push!(symbols, name)
        elseif top_level && expression.head in (:abstract, :primitive)
            name = binding_name(first(expression.args))
            name === nothing || push!(symbols, name)
        end
        # A component root wraps its declarations in `module ... end`, while the
        # owned include sources are appended for static contract validation.
        # Treat a direct module body as a declaration scope; otherwise every
        # root-level API alias is incorrectly reported as undefined.
        child_top_level = top_level && expression.head in (:toplevel, :block, :macrocall, :module)
        foreach(argument -> visit(argument, child_top_level), expression.args)
    end
    # Parse the real Julia source here.  Replacing string literals with blanks
    # is appropriate for lexical import scans, but it can turn valid constructs
    # such as `"key" => value` into a parse error and hide every declaration
    # that follows.  Strings and comments are inert AST leaves for this walk.
    visit(Meta.parseall(source), true)
    return sort!(collect(symbols))
end

"""Parse one literal `Dict{Symbol,Module}` ownership table from an extension root."""
function entrypoint_owner_map(
    source::AbstractString,
    constant_name::AbstractString = "ENTRYPOINT_OWNERS",
)
    occursin(r"^[A-Z_]+$", constant_name) ||
        throw(ArgumentError("invalid ownership constant name $(repr(constant_name))"))
    code = _code_only(source)
    pattern = Regex("(?ms)const\\s+" * constant_name * "\\s*=\\s*Dict[^\\(]*\\((.*?)\\n\\)")
    matched = match(pattern, code)
    matched === nothing && return Dict{Symbol, Symbol}()
    return Dict(
        Symbol(pair.captures[1]) => Symbol(pair.captures[2]) for pair in eachmatch(
            r":([A-Za-z_][A-Za-z0-9_]*(?:!)?)\s*=>\s*([A-Za-z_][A-Za-z0-9_]*)",
            matched.captures[1],
        )
    )
end

"""Return literal symbols routed through the parent Wannierization extension bridge."""
function wannierization_bridge_symbols(source::AbstractString)
    symbols = Symbol[]
    function visit(expression)
        expression isa Expr || return
        if expression.head == :call &&
           !isempty(expression.args) &&
           first(expression.args) == :_call_wannierization_extension &&
           length(expression.args) >= 2
            arguments = [
                argument for argument in expression.args[2:end] if
                !(argument isa Expr && argument.head == :parameters)
            ]
            isempty(arguments) && return
            argument = first(arguments)
            name = argument isa QuoteNode ? argument.value : argument
            name isa Symbol || return
            push!(symbols, name)
        end
        foreach(visit, expression.args)
    end
    visit(Meta.parseall(source))
    return sort!(symbols; by = string)
end

"""Return the direct provider modules named at a component root."""
direct_import_providers(source::AbstractString) =
    sort!(collect(keys(direct_import_records(source))))

"""Return provider names introduced by any `using` statement in one source."""
function direct_using_providers(source::AbstractString)
    providers = Set{String}()
    function visit(expression)
        expression isa Expr || return
        if expression.head == :using
            for argument in expression.args
                provider =
                    argument isa Expr && argument.head == :(:) ?
                    _import_provider_name(first(argument.args)) : _import_provider_name(argument)
                isempty(provider) || push!(providers, provider)
            end
        end
        foreach(visit, expression.args)
    end
    visit(Meta.parseall(_code_only(source)))
    return sort!(collect(providers))
end

"""Reject uses of the root package binding outside an explicit call allowlist."""
function root_module_usage_violations(source::AbstractString; allowed_functions = ("pkgversion",))
    violations = String[]
    allowed = Set(String.(allowed_functions))
    function is_allowed_callee(expression)
        expression isa Symbol && return String(expression) in allowed
        expression isa Expr && expression.head == :. || return false
        return _import_symbol_name(expression) in allowed
    end
    function visit(expression; allow_root::Bool = false)
        if expression isa Symbol
            expression == :WannierNLQG && !allow_root && push!(violations, "WannierNLQG")
            return
        end
        expression isa Expr || return
        expression.head in (:using, :import) && return
        if expression.head == :call &&
           !isempty(expression.args) &&
           is_allowed_callee(first(expression.args))
            visit(first(expression.args))
            for argument in expression.args[2:end]
                visit(argument; allow_root = argument == :WannierNLQG)
            end
            return
        end
        foreach(argument -> visit(argument; allow_root), expression.args)
    end
    visit(Meta.parseall(source))
    return violations
end

"""Return typed SAWF methods that still read a grouped-config leaf at the top level."""
function typed_sawf_flat_config_reads(sources::AbstractDict, leaf_fields)
    leaves = Set(Symbol.(leaf_fields))
    violations = String[]
    function annotation_terminal_name(annotation)
        annotation isa Symbol && return annotation
        annotation isa QuoteNode && return annotation_terminal_name(annotation.value)
        annotation isa Expr || return nothing
        annotation.head == :. && return annotation_terminal_name(last(annotation.args))
        annotation.head in (:curly, :where) || return nothing
        return annotation_terminal_name(first(annotation.args))
    end
    function sawf_type_aliases(expression)
        aliases = Set((:SymmetryAdaptedWannierizationConfig,))
        changed = true
        while changed
            changed = false
            function collect_alias(candidate)
                candidate isa Expr || return
                if candidate.head == :const
                    foreach(collect_alias, candidate.args)
                    return
                end
                if candidate.head == :(=) && candidate.args[1] isa Symbol
                    terminal = annotation_terminal_name(candidate.args[2])
                    if terminal in aliases && !(candidate.args[1] in aliases)
                        push!(aliases, candidate.args[1])
                        changed = true
                    end
                end
                foreach(collect_alias, candidate.args)
            end
            collect_alias(expression)
        end
        return aliases
    end
    function typed_sawf_arguments(signature, aliases)
        variables = Set{Symbol}()
        signature isa Expr || return variables
        call_signature = signature.head == :where ? first(signature.args) : signature
        call_signature isa Expr && call_signature.head == :call || return variables
        arguments = call_signature.args[2:end]
        for argument in arguments
            argument isa Expr && argument.head == :(::) || continue
            length(argument.args) == 2 || continue
            variable, annotation = argument.args
            variable isa Symbol || continue
            annotation_terminal_name(annotation) in aliases && push!(variables, variable)
        end
        return variables
    end
    function visit(expression, variables, aliases, path)
        expression isa Expr || return
        if expression.head == :function
            typed = typed_sawf_arguments(expression.args[1], aliases)
            visit(expression.args[end], isempty(typed) ? variables : typed, aliases, path)
            return
        elseif expression.head == :(=) && expression.args[1] isa Expr
            typed = typed_sawf_arguments(expression.args[1], aliases)
            visit(expression.args[end], isempty(typed) ? variables : typed, aliases, path)
            return
        elseif expression.head in (:block, :toplevel)
            scoped = copy(variables)
            for argument in expression.args
                visit(argument, scoped, aliases, path)
                argument isa Expr && argument.head == :(=) || continue
                left, right = argument.args
                left isa Symbol || continue
                if right isa Symbol && right in scoped
                    push!(scoped, left)
                elseif right isa Expr &&
                       right.head == :call &&
                       !isempty(right.args) &&
                       annotation_terminal_name(first(right.args)) in aliases
                    push!(scoped, left)
                end
            end
            return
        elseif expression.head == :. &&
               length(expression.args) == 2 &&
               expression.args[1] isa Symbol
            field = expression.args[2] isa QuoteNode ? expression.args[2].value : nothing
            expression.args[1] in variables &&
                field in leaves &&
                push!(violations, "$(path): $(expression.args[1]).$(field)")
        elseif expression.head == :call &&
               expression.args[1] == :getproperty &&
               length(expression.args) >= 3 &&
               expression.args[2] isa Symbol
            field = expression.args[3] isa QuoteNode ? expression.args[3].value : nothing
            expression.args[2] in variables &&
                field in leaves &&
                push!(violations, "$(path): getproperty($(expression.args[2]), $(field))")
        end
        foreach(argument -> visit(argument, variables, aliases, path), expression.args)
    end
    for path in sort!(collect(keys(sources)))
        parsed = Meta.parseall(sources[path])
        visit(parsed, Set{Symbol}(), sawf_type_aliases(parsed), path)
    end
    return sort!(unique!(violations))
end

"""Report both missing and unexpected members of one exact allowlist."""
function exact_allowlist_violations(label::AbstractString, actual, expected)
    actual_set = Set(actual)
    expected_set = Set(expected)
    violations = String[]
    for value in sort!(collect(setdiff(expected_set, actual_set)); by = string)
        push!(violations, "$(label): missing $(value)")
    end
    for value in sort!(collect(setdiff(actual_set, expected_set)); by = string)
        push!(violations, "$(label): unexpected $(value)")
    end
    return violations
end

"""Compare exact provider, module-binding, and symbol-import contract records."""
function import_record_violations(
    label::AbstractString,
    actual::AbstractDict,
    expected::AbstractDict,
)
    violations = exact_allowlist_violations("$(label) providers", keys(actual), keys(expected))
    for provider in sort!(collect(intersect(keys(actual), keys(expected))))
        actual_record = actual[provider]
        expected_record = expected[provider]
        actual_record.module_binding == expected_record.module_binding || push!(
            violations,
            "$(label) $(provider): module_binding expected $(expected_record.module_binding), got $(actual_record.module_binding)",
        )
        append!(
            violations,
            exact_allowlist_violations(
                "$(label) $(provider) symbols",
                actual_record.symbols,
                expected_record.symbols,
            ),
        )
    end
    return sort!(unique!(violations))
end

"""Validate one declared integration API, including duplicates and definitions."""
function integration_api_violations(label::AbstractString, actual, expected, available)
    actual_names = String.(actual)
    violations = exact_allowlist_violations(label, actual_names, String.(expected))
    length(actual_names) == length(unique(actual_names)) ||
        push!(violations, "$(label): duplicate entries")
    available_names = Set(String.(available))
    for name in sort!(unique(actual_names))
        name in available_names || push!(violations, "$(label): undefined $(name)")
        startswith(name, "_") && push!(violations, "$(label): private $(name)")
    end
    return sort!(unique!(violations))
end

"""Validate one private white-box API, including exactness and definitions."""
function test_api_violations(label::AbstractString, actual, expected, available)
    actual_names = String.(actual)
    violations = exact_allowlist_violations(label, actual_names, String.(expected))
    length(actual_names) == length(unique(actual_names)) ||
        push!(violations, "$(label): duplicate entries")
    available_names = Set(String.(available))
    for name in sort!(unique(actual_names))
        name in available_names || push!(violations, "$(label): undefined $(name)")
        startswith(name, "_") || push!(violations, "$(label): non-private $(name)")
    end
    return sort!(unique!(violations))
end

"""Validate complete, kind-correct ownership of parent extension bridge symbols."""
function bridge_ownership_violations(
    label::AbstractString,
    bridge_symbols,
    public_owners::AbstractDict,
    test_owners::AbstractDict,
)
    bridges = Symbol.(bridge_symbols)
    violations = String[]
    length(bridges) == length(unique(bridges)) ||
        push!(violations, "$(label): duplicate bridge calls")
    public_bridges = Set(name for name in bridges if !startswith(String(name), "_"))
    test_bridges = Set(name for name in bridges if startswith(String(name), "_"))
    append!(
        violations,
        exact_allowlist_violations(
            "$(label) test bridge entrypoints",
            keys(test_owners),
            test_bridges,
        ),
    )
    for name in sort!(collect(public_bridges); by = string)
        haskey(public_owners, name) || push!(violations, "$(label): unowned public bridge $(name)")
        haskey(test_owners, name) &&
            push!(violations, "$(label): public bridge $(name) in test map")
    end
    for name in sort!(collect(test_bridges); by = string)
        haskey(public_owners, name) &&
            push!(violations, "$(label): private bridge $(name) in public map")
    end
    for name in sort!(collect(intersect(keys(public_owners), keys(test_owners))); by = string)
        push!(violations, "$(label): overlapping public/test owner $(name)")
    end
    return sort!(unique!(violations))
end

"""Compare an exact facade-entrypoint to owning-component map."""
function entrypoint_owner_violations(
    label::AbstractString,
    actual::AbstractDict,
    expected::AbstractDict,
)
    violations = exact_allowlist_violations("$(label) entrypoints", keys(actual), keys(expected))
    for name in sort!(collect(intersect(keys(actual), keys(expected))); by = string)
        actual[name] == expected[name] || push!(
            violations,
            "$(label) $(name): expected owner $(expected[name]), got $(actual[name])",
        )
    end
    return sort!(unique!(violations))
end

"""Extract direct sibling-module dependencies from one nested module root."""
function relative_module_dependencies(source::AbstractString)
    code = _code_only(source)
    dependencies = Symbol[]
    pattern = r"(?m)^\s*(?:using|import)\s+\.\.([A-Za-z][A-Za-z0-9_]*)"
    for matched in eachmatch(pattern, code)
        push!(dependencies, Symbol(matched.captures[1]))
    end
    return sort!(unique!(dependencies); by = string)
end

"""Report directed cycles in a component dependency graph."""
function dependency_cycle_violations(graph::AbstractDict)
    state = Dict{Any, Symbol}(node => :unvisited for node in keys(graph))
    stack = Any[]
    violations = String[]
    function visit(node)
        get(state, node, :unvisited) == :complete && return
        if get(state, node, :unvisited) == :active
            first_index = findfirst(==(node), stack)
            cycle = [stack[first_index:end]..., node]
            push!(violations, join(string.(cycle), " -> "))
            return
        end
        state[node] = :active
        push!(stack, node)
        for dependency in sort!(collect(get(graph, node, Set())); by = string)
            haskey(graph, dependency) && visit(dependency)
        end
        pop!(stack)
        state[node] = :complete
        return
    end
    for node in sort!(collect(keys(graph)); by = string)
        visit(node)
    end
    return sort!(unique!(violations))
end

"""Compare exact per-component file ownership and reject duplicate owners."""
function component_file_ownership_violations(actual::AbstractDict, expected::AbstractDict)
    violations = String[]
    for component in sort!(collect(union(keys(actual), keys(expected))); by = string)
        append!(
            violations,
            exact_allowlist_violations(
                "$(component) files",
                get(actual, component, String[]),
                get(expected, component, String[]),
            ),
        )
    end
    owners = Dict{String, Vector{String}}()
    for (component, files) in actual, file in files
        push!(get!(owners, String(file), String[]), String(component))
    end
    for (file, file_owners) in owners
        length(file_owners) == 1 ||
            push!(violations, "$(file): duplicate owners $(join(sort!(file_owners), ", "))")
    end
    return sort!(violations)
end

"""Reject lexical calls to another component's underscored implementation names."""
function component_private_reference_violations(sources::AbstractDict)
    declaration_pattern =
        r"(?m)^\s*(?:@[A-Za-z_][A-Za-z0-9_.]*\s+)*(?:function|const|struct|mutable\s+struct|abstract\s+type)\s+(_[A-Za-z][A-Za-z0-9_!]*)"
    assignment_pattern = r"(?m)^\s*(_[A-Za-z][A-Za-z0-9_!]*)\s*\([^\n=]*\)\s*="
    definitions = Dict{Any, Set{Symbol}}()
    for (component, source) in sources
        code = _code_only(source)
        declared =
            Set(Symbol(matched.captures[1]) for matched in eachmatch(declaration_pattern, code))
        union!(
            declared,
            Set(Symbol(matched.captures[1]) for matched in eachmatch(assignment_pattern, code)),
        )
        definitions[component] = declared
    end
    violations = String[]
    for (consumer, source) in sources
        tokens = Set(
            Symbol(matched.match) for
            matched in eachmatch(r"\b_[A-Za-z][A-Za-z0-9_!]*", _code_only(source))
        )
        for (provider, private_names) in definitions
            provider == consumer && continue
            for name in sort!(collect(intersect(tokens, private_names)); by = string)
                push!(violations, "$(consumer) calls $(provider).$(name)")
            end
        end
    end
    return sort!(unique!(violations))
end

"""
Return cross-component qualified references such as `Provider.symbol`.

Component implementations consume sibling APIs through the exact symbols
declared by their root imports. A qualified sibling reference would require a
module binding and can silently survive an incomplete exact-import migration.
"""
function component_qualified_reference_violations(sources::AbstractDict)
    providers = sort!(collect(keys(sources)); by = string)
    violations = String[]
    for consumer in providers
        code = _code_only(sources[consumer])
        for provider in providers
            provider == consumer && continue
            provider_name = String(provider)
            pattern = Regex("\\b" * provider_name * "\\s*\\.\\s*([A-Za-z_][A-Za-z0-9_]*(?:!)?)")
            for matched in eachmatch(pattern, code)
                push!(violations, "$(consumer) qualifies $(provider_name).$(matched.captures[1])")
            end
        end
    end
    return sort!(unique!(violations))
end

# Collect exported symbols from parsed Julia syntax rather than line formatting.
function exported_symbols(source::AbstractString)
    parsed = Meta.parseall(source)
    result = Symbol[]
    function visit(expression)
        expression isa Expr || return
        if expression.head == :export
            append!(result, Symbol.(expression.args))
        else
            foreach(visit, expression.args)
        end
    end
    visit(parsed)
    return sort!(unique!(result); by = string)
end

# Return production Spglib references that occur outside the declared owner roots.
function production_spglib_violations(
    sources::AbstractDict{<:AbstractString, <:AbstractString};
    allowed_prefixes = ("ext/WannierNLQGSymmetryFoundationExt/",),
)
    violations = String[]
    patterns = (
        r"\b(?:using|import)\s+Spglib\b",
        r"\bSpglib\s*\.",
        r"\b(?:Base\s*\.\s*)?pkgversion\s*\(\s*Spglib\s*\)",
        r"\bfunction\s+detect_(?:magnetic_symmetry_inventory|symmetry_operations)\b",
    )
    for path in sort!(collect(keys(sources)))
        any(prefix -> startswith(path, prefix), allowed_prefixes) && continue
        code = _code_only(sources[path])
        for pattern in patterns
            occursin(pattern, code) && push!(violations, "$(path): $(pattern)")
        end
    end
    return violations
end

# Extract imported names from one multiline qualified import block.
function _qualified_private_imports(code::AbstractString, module_name::AbstractString)
    escaped = replace(module_name, "." => "\\.")
    pattern = Regex(
        "(?ms)^\\s*(?:using|import)\\s+(?:WannierNLQG\\.|\\.\\.)?" *
        escaped *
        "\\s*:\\s*(.*?)(?=^\\S|\\z)",
    )
    names = String[]
    for matched in eachmatch(pattern, code)
        append!(
            names,
            match.match for match in eachmatch(r"\b_[A-Za-z][A-Za-z0-9_!]*\b", matched.captures[1])
        )
    end
    return names
end

# Return cross-owner references to underscored symbols for declared module owners.
function private_module_boundary_violations(
    sources::AbstractDict{<:AbstractString, <:AbstractString};
    owner_prefixes = Dict(
        "SymmetryFoundation" =>
            ("src/SymmetryFoundation/", "ext/WannierNLQGSymmetryFoundationExt/"),
        "WannierProjection" => ("src/WannierProjection/",),
        "MatrixElements" => ("src/MatrixElements/",),
        "Symmetrization" => ("src/Symmetrization/", "ext/WannierNLQGSymmetrizationExt/"),
        "Wannierization" => ("src/Wannierization/", "ext/WannierNLQGWannierizationExt/"),
    ),
)
    violations = String[]
    for path in sort!(collect(keys(sources)))
        code = _code_only(sources[path])
        for module_name in sort!(collect(keys(owner_prefixes)))
            any(prefix -> startswith(path, prefix), owner_prefixes[module_name]) && continue
            qualified = Regex("\\b" * module_name * "\\s*\\.\\s*_[A-Za-z]")
            occursin(qualified, code) &&
                push!(violations, "$(path): qualified $(module_name) private symbol")
            for name in _qualified_private_imports(code, module_name)
                push!(violations, "$(path): imports $(module_name).$(name)")
            end
        end
    end
    return violations
end

# Preserve the stricter all-tree check for the two foundational shared layers.
function private_shared_boundary_violations(
    sources::AbstractDict{<:AbstractString, <:AbstractString};
    owner_prefixes = Dict(
        "SymmetryFoundation" =>
            ("src/SymmetryFoundation/", "ext/WannierNLQGSymmetryFoundationExt/"),
        "WannierProjection" => ("src/WannierProjection/",),
    ),
)
    return private_module_boundary_violations(sources; owner_prefixes)
end

# Reject public/integration overlap, duplicate entries, private names, and multi-owner entries.
function integration_allowlist_violations(public_symbols::AbstractDict, allowlists::AbstractDict)
    violations = String[]
    owners_by_symbol = Dict{Symbol, Vector{String}}()
    for module_name in sort!(collect(keys(allowlists)))
        entries = Symbol.(allowlists[module_name])
        length(entries) == length(unique(entries)) ||
            push!(violations, "$(module_name): duplicate integration entry")
        public = Set(Symbol.(public_symbols[module_name]))
        for name in entries
            startswith(String(name), "_") &&
                push!(violations, "$(module_name).$(name): private integration name")
            name in public && push!(violations, "$(module_name).$(name): public and integration")
            push!(get!(owners_by_symbol, name, String[]), String(module_name))
        end
    end
    for (name, owners) in owners_by_symbol
        length(owners) == 1 ||
            push!(violations, "$(name): mixed across $(join(sort!(owners), ", "))")
    end
    return sort!(violations)
end

# Reject duplicate semantic models, including retired aliases with different type names.
function semantic_duplicate_type_violations(
    sources::AbstractDict{<:AbstractString, <:AbstractString};
    owner_contract = Dict(
        "AbstractWavefunctionSource" => (
            prefixes = ("src/SymmetryFoundation/", "ext/WannierNLQGSymmetryFoundationExt/"),
            aliases = ("LegacyAbstractWavefunctionSource",),
        ),
        "VASPWavefunctionSource" => (
            prefixes = ("src/SymmetryFoundation/", "ext/WannierNLQGSymmetryFoundationExt/"),
            aliases = ("LegacyVASPWavefunctionSource",),
        ),
        "QuantumEspressoWavefunctionSource" => (
            prefixes = ("src/SymmetryFoundation/", "ext/WannierNLQGSymmetryFoundationExt/"),
            aliases = ("LegacyQuantumEspressoWavefunctionSource",),
        ),
        "BandRepresentation" => (
            prefixes = ("src/SymmetryFoundation/", "ext/WannierNLQGSymmetryFoundationExt/"),
            aliases = ("LegacyBandRepresentation",),
        ),
    ),
)
    violations = String[]
    declaration =
        r"(?m)^\s*(?:Base\.@kwdef\s+)?(?:abstract\s+type|mutable\s+struct|struct|@enum)\s+([A-Za-z_][A-Za-z0-9_]*)\b"
    for path in sort!(collect(keys(sources)))
        code = _code_only(sources[path])
        declared = Set(match.captures[1] for match in eachmatch(declaration, code))
        for (canonical, contract) in owner_contract
            canonical in declared &&
                !any(prefix -> startswith(path, prefix), contract.prefixes) &&
                push!(violations, "$(path): duplicate owner of $(canonical)")
            for alias in contract.aliases
                alias in declared && push!(violations, "$(path): $(alias) duplicates $(canonical)")
            end
        end
    end
    return sort!(violations)
end

# Extract every symbol named by a multiline qualified import block.
function _qualified_imports(code::AbstractString, module_name::AbstractString)
    escaped = replace(module_name, "." => "\\.")
    pattern = Regex(
        "(?ms)^\\s*(?:using|import)\\s+(?:WannierNLQG\\.|\\.\\.)?" *
        escaped *
        "\\s*:\\s*(.*?)(?=^\\S|\\z)",
    )
    names = Symbol[]
    for matched in eachmatch(pattern, code)
        for name in eachmatch(r"\b[A-Za-z_][A-Za-z0-9_]*(?:!)?", matched.captures[1])
            push!(names, Symbol(name.match))
        end
    end
    return names
end

# Return non-public shared-layer references absent from the explicit integration allowlists.
function shared_boundary_reference_violations(
    sources::AbstractDict{<:AbstractString, <:AbstractString},
    public_symbols::AbstractDict,
    integration_allowlists::AbstractDict;
    owner_prefixes = Dict(
        "SymmetryFoundation" =>
            ("src/SymmetryFoundation/", "ext/WannierNLQGSymmetryFoundationExt/"),
        "WannierProjection" => ("src/WannierProjection/",),
    ),
)
    violations = String[]
    for path in sort!(collect(keys(sources)))
        code = _code_only(sources[path])
        for module_name in sort!(collect(keys(owner_prefixes)))
            any(prefix -> startswith(path, prefix), owner_prefixes[module_name]) && continue
            referenced = Set(_qualified_imports(code, module_name))
            qualified = Regex("\\b" * module_name * "\\s*\\.\\s*([A-Za-z_][A-Za-z0-9_]*(?:!)?)")
            union!(referenced, Symbol(match.captures[1]) for match in eachmatch(qualified, code))
            public = Set(Symbol.(public_symbols[module_name]))
            allowed = Set(Symbol.(integration_allowlists[module_name]))
            for name in sort!(collect(referenced); by = string)
                name in public ||
                    name in allowed ||
                    push!(
                        violations,
                        "$(path): $(module_name).$(name) is neither public nor allowlisted",
                    )
            end
        end
    end
    return violations
end

# Return implementation paths absent from a machine-checked documentation inventory.
function missing_documented_paths(document::AbstractString, paths)
    return sort!(
        String[
            replace(String(path), '\\' => '/') for
            path in paths if !occursin(replace(String(path), '\\' => '/'), document)
        ],
    )
end

end
