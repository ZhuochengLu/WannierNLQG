module SourceDocumentationAudit

export DeclarationRecord, DocumentationAudit, audit_source_documentation, source_julia_files

struct DeclarationRecord
    path::String
    line::Int
    kind::Symbol
    name::String
    documented::Bool
    has_docstring::Bool
    explanation::String
end

# Preserve the compact record constructor used by external audit consumers.
DeclarationRecord(path, line, kind, name, documented) =
    DeclarationRecord(path, line, kind, name, documented, false, "")

struct DocumentationAudit
    declarations::Vector{DeclarationRecord}
    orphan_docstrings::Vector{Tuple{String, Int}}
    parse_failures::Vector{Tuple{String, String}}
    public_api_missing_docstrings::Vector{DeclarationRecord}
    filler_declarations::Vector{DeclarationRecord}
    applied_exceptions::Vector{Tuple{String, String, String}}
end

function source_julia_files(source_root::AbstractString)
    files = String[]
    for (directory, _, names) in walkdir(source_root)
        for name in names
            endswith(name, ".jl") && push!(files, joinpath(directory, name))
        end
    end
    return sort!(files)
end

# Collect Julia sources from multiple disjoint package roots.
function source_julia_files(source_roots::AbstractVector{<:AbstractString})
    files = reduce(vcat, source_julia_files(root) for root in source_roots if isdir(root))
    return sort!(unique!(files))
end

function _signature_name(signature)
    signature isa Symbol && return String(signature)
    signature isa QuoteNode && return string(signature.value)
    signature isa Expr || return string(signature)
    signature.head in (:where, :(::)) && return _signature_name(signature.args[1])
    signature.head == :call && return _signature_name(signature.args[1])
    return string(signature)
end

function _type_name(type_expression)
    type_expression isa Symbol && return String(type_expression)
    type_expression isa Expr || return string(type_expression)
    type_expression.head in (:<:, :curly) && return _type_name(type_expression.args[1])
    return string(type_expression)
end

function _declaration(expression)
    expression isa Expr || return nothing
    if expression.head == :function
        return (:function, _signature_name(expression.args[1]))
    elseif expression.head == :(=)
        lhs = expression.args[1]
        if lhs isa Expr && lhs.head in (:call, :where)
            return (:method, _signature_name(lhs))
        end
    elseif expression.head == :struct
        return (:type, _type_name(expression.args[2]))
    elseif expression.head == :abstract
        return (:type, _type_name(expression.args[1]))
    elseif expression.head == :primitive
        return (:type, _type_name(expression.args[1]))
    elseif expression.head == :macro
        return (:macro, _signature_name(expression.args[1]))
    elseif expression.head == :macrocall
        for argument in reverse(expression.args)
            declaration = _declaration(argument)
            declaration === nothing || return declaration
        end
    end
    return nothing
end

function _declaration_expression(expression)
    expression isa Expr || return nothing
    _declaration(expression) !== nothing && expression.head != :macrocall && return expression
    if expression.head == :macrocall
        for argument in reverse(expression.args)
            declaration = _declaration_expression(argument)
            declaration === nothing || return declaration
        end
    end
    return nothing
end

function _expression_line(expression, fallback::Int)
    expression isa LineNumberNode && return Int(expression.line)
    expression isa Expr || return fallback
    lines = Int[]
    function collect_lines(item)
        if item isa LineNumberNode
            push!(lines, Int(item.line))
        elseif item isa Expr
            foreach(collect_lines, item.args)
        end
    end
    collect_lines(expression)
    return isempty(lines) ? fallback : minimum(lines)
end

# Read only the declaration-adjacent comment block; Julia's AST determines docstrings.
function _adjacent_comment(lines::Vector{String}, declaration_line::Int)
    index = declaration_line - 1
    comments = String[]
    while index >= 1 && startswith(strip(lines[index]), "#")
        pushfirst!(comments, strip(replace(strip(lines[index]), r"^#\s?" => "")))
        index -= 1
    end
    return join(comments, "\n")
end

# Extract the text from Julia's documentation macro without treating arbitrary strings as docs.
function _docstring(expression)
    expression isa Expr || return ""
    if expression.head == :macrocall && (
        expression.args[1] == GlobalRef(Core, Symbol("@doc")) ||
        string(expression.args[1]) == "@doc"
    )
        length(expression.args) >= 3 && expression.args[3] isa String && return expression.args[3]
    end
    return ""
end

# These exact sentences are known historical templates, not a semantic quality metric.
const FILLER_PARAGRAPHS = (
    "This numerical primitive follows the package-wide unit and index conventions.",
    "This response-level routine preserves the established Hamiltonian-gauge, projector,",
    "The routine constructs or interprets Wannier- and Hamiltonian-gauge matrix data",
    "This I/O boundary owns the serialized format and shape validation.",
)

function _known_filler(record::DeclarationRecord)
    explanation = strip(record.explanation)
    any(fragment -> occursin(fragment, explanation), FILLER_PARAGRAPHS) && return true
    words =
        lowercase(replace(replace(record.name, r"([a-z0-9])([A-Z])" => s"\1 \2"), r"[_!]" => " "))
    words = strip(replace(words, r"\s+" => " "))
    first_line = lowercase(strip(first(split(explanation, '\n'))))
    local_words = replace(words, r"^.*\." => "")
    for (verb, suffix) in (
        ("read", " from its configured input."),
        ("write", " to its configured output."),
        ("normalize", " to its canonical representation."),
        ("prepare", " in place."),
        ("compute", " in place."),
        ("validate", "."),
        ("select", "."),
        ("resolve", "."),
        ("parse", "."),
        ("load", "."),
    )
        startswith(local_words, verb * " ") || continue
        first_line == local_words * suffix && return true
    end
    for verb in ("is", "has")
        startswith(local_words, verb * " ") || continue
        first_line == "return whether " * local_words[(length(verb) + 2):end] * "." && return true
    end
    first_line == "provide the $(local_words) overload for this argument shape." && return true
    return first_line in (
        "evaluate $(words).",
        "store $(words) state.",
        "construct $(words).",
        "provide the $(words) overload for this argument shape.",
    )
end

# Exceptions must name an individual generated/forwarding declaration and explain why.
# Keys are (path relative to one audited source root, declaration name).
const DOCUMENTATION_EXCEPTIONS =
    Dict{Tuple{String, String}, NamedTuple{(:kind, :reason), Tuple{Symbol, String}}}()

# Julia also permits `@doc "text" ExistingBinding` after a type declaration.
function _attached_docstring_names(parsed)
    names = Set{String}()
    function visit(expression)
        expression isa Expr || return
        if expression.head == :macrocall && !isempty(_docstring(expression))
            target = expression.args[end]
            target isa Symbol && push!(names, String(target))
        elseif expression.head in (:toplevel, :block, :module)
            foreach(visit, expression.args)
        end
    end
    visit(parsed)
    return names
end

function _exported_names(parsed)
    names = Set{String}()
    function visit(expression)
        expression isa Expr || return
        if expression.head == :export
            union!(names, string.(expression.args))
        elseif expression.head in (:toplevel, :block, :module)
            foreach(visit, expression.args)
        end
    end
    visit(parsed)
    return names
end

function _type_declaration_line(lines::Vector{String}, approximate_line::Int, name::String)
    base_name = first(split(name, '{'; limit = 2))
    for line in reverse(1:min(approximate_line, length(lines)))
        stripped = strip(lines[line])
        if (
            startswith(stripped, "struct ") ||
            startswith(stripped, "mutable struct ") ||
            startswith(stripped, "@kwdef struct ") ||
            startswith(stripped, "@kwdef mutable struct ") ||
            startswith(stripped, "Base.@kwdef struct ") ||
            startswith(stripped, "Base.@kwdef mutable struct ") ||
            startswith(stripped, "abstract type ") ||
            startswith(stripped, "primitive type ")
        ) && occursin(base_name, stripped)
            return line
        end
    end
    return approximate_line
end

function _declaration_line_after_inline_docstring(
    lines::Vector{String},
    approximate_line::Int,
    kind::Symbol,
)
    startswith(strip(lines[approximate_line]), "\"\"\"") || return approximate_line
    for line in (approximate_line + 1):min(approximate_line + 8, length(lines))
        stripped = strip(lines[line])
        if kind in (:function, :method) &&
           (startswith(stripped, "function ") || occursin(" function ", stripped))
            return line
        elseif kind == :type && (
            startswith(stripped, "struct ") ||
            startswith(stripped, "mutable struct ") ||
            startswith(stripped, "@kwdef struct ") ||
            startswith(stripped, "@kwdef mutable struct ") ||
            startswith(stripped, "Base.@kwdef struct ") ||
            startswith(stripped, "Base.@kwdef mutable struct ") ||
            startswith(stripped, "abstract type ") ||
            startswith(stripped, "primitive type ")
        )
            return line
        end
    end
    return approximate_line
end

function _top_level_items(parsed)
    if parsed isa Expr && parsed.head in (:toplevel, :block)
        return reduce(vcat, (_top_level_items(item) for item in parsed.args); init = Any[])
    elseif parsed isa Expr && parsed.head == :module
        return _top_level_items(parsed.args[end])
    elseif parsed isa Expr && parsed.head in (:error, :incomplete)
        throw(ArgumentError("Julia source contains a parser error: $(parsed)"))
    end
    return Any[parsed]
end

function _audit_file(path::AbstractString)
    text = read(path, String)
    lines = readlines(IOBuffer(text); keep = true)
    lines = String[chomp(line) for line in lines]
    parsed = Meta.parseall(text; filename = path)
    declarations = DeclarationRecord[]
    orphan_docstrings = Tuple{String, Int}[]
    current_line = 1
    for item in _top_level_items(parsed)
        if item isa LineNumberNode
            current_line = Int(item.line)
            continue
        end
        if item isa String
            push!(orphan_docstrings, (String(path), current_line))
            continue
        end
        declaration_expression = _declaration_expression(item)
        declaration_expression === nothing && continue
        declaration = _declaration(declaration_expression)
        item_line = _expression_line(declaration_expression, current_line)
        kind, name = declaration
        kind == :type && (item_line = _type_declaration_line(lines, item_line, name))
        item_line = _declaration_line_after_inline_docstring(lines, item_line, kind)
        push!(
            declarations,
            DeclarationRecord(
                String(path),
                item_line,
                kind,
                name,
                !isempty(_docstring(item)) || !isempty(_adjacent_comment(lines, item_line)),
                !isempty(_docstring(item)),
                isempty(_docstring(item)) ? _adjacent_comment(lines, item_line) : _docstring(item),
            ),
        )
    end
    return declarations, orphan_docstrings
end

function audit_source_documentation(
    source_roots::AbstractVector{<:AbstractString};
    exceptions = DOCUMENTATION_EXCEPTIONS,
)
    declarations = DeclarationRecord[]
    orphan_docstrings = Tuple{String, Int}[]
    parse_failures = Tuple{String, String}[]
    exported_names = Set{String}()
    attached_docs = Set{String}()
    for path in source_julia_files(source_roots)
        try
            parsed = Meta.parseall(read(path, String); filename = path)
            union!(exported_names, _exported_names(parsed))
            union!(attached_docs, _attached_docstring_names(parsed))
            file_declarations, file_orphans = _audit_file(path)
            append!(declarations, file_declarations)
            append!(orphan_docstrings, file_orphans)
        catch exception
            push!(parse_failures, (path, sprint(showerror, exception)))
        end
    end
    documented_names = Set(record.name for record in declarations if record.has_docstring)
    union!(documented_names, attached_docs)
    public_missing = DeclarationRecord[]
    filler = DeclarationRecord[]
    applied = Tuple{String, String, String}[]
    for record in declarations
        exception = nothing
        for root in source_roots
            key = (relpath(record.path, root), record.name)
            haskey(exceptions, key) && (exception = exceptions[key])
        end
        if exception !== nothing
            exception.kind in (:generated, :forwarding) ||
                throw(ArgumentError("Documentation exceptions must be generated or forwarding"))
            isempty(strip(exception.reason)) &&
                throw(ArgumentError("Documentation exceptions require a reason"))
            push!(applied, (record.path, record.name, exception.reason))
            continue
        end
        if record.name in exported_names && !(record.name in documented_names)
            push!(public_missing, record)
        end
        _known_filler(record) && push!(filler, record)
    end
    return DocumentationAudit(
        declarations,
        orphan_docstrings,
        parse_failures,
        public_missing,
        filler,
        applied,
    )
end

# Audit one source root through the shared multi-root implementation.
function audit_source_documentation(source_root::AbstractString; kwargs...)
    return audit_source_documentation([String(source_root)]; kwargs...)
end

end
