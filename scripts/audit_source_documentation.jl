#!/usr/bin/env julia

include(joinpath(@__DIR__, "SourceDocumentationAudit.jl"))
using .SourceDocumentationAudit

const ROOT = normpath(joinpath(@__DIR__, ".."))
const SOURCE_ROOTS = [joinpath(ROOT, "src"), joinpath(ROOT, "ext")]

function requested_output_path(arguments)
    for argument in arguments
        startswith(argument, "--output=") && return split(argument, '='; limit = 2)[2]
    end
    return ""
end

output_path = requested_output_path(ARGS)

audit = audit_source_documentation(SOURCE_ROOTS)
missing = filter(record -> !record.documented, audit.declarations)

if !isempty(output_path)
    output_path = abspath(output_path)
    mkpath(dirname(output_path))
    open(output_path, "w") do io
        println(io, "path\tline\tkind\tname\texplanation_present\thas_docstring")
        for record in audit.declarations
            println(
                io,
                join(
                    (
                        relpath(record.path, ROOT),
                        record.line,
                        record.kind,
                        replace(record.name, '\t' => ' '),
                        record.documented,
                        record.has_docstring,
                    ),
                    '\t',
                ),
            )
        end
    end
end

println(
    "source documentation audit: declarations=$(length(audit.declarations)) " *
    "explanation_present=$(length(audit.declarations) - length(missing)) missing=$(length(missing)) " *
    "public_api_missing_docstrings=$(length(audit.public_api_missing_docstrings)) " *
    "known_filler=$(length(audit.filler_declarations)) exceptions=$(length(audit.applied_exceptions)) " *
    "orphan_docstrings=$(length(audit.orphan_docstrings)) parse_failures=$(length(audit.parse_failures))",
)
println(
    "This syntax gate checks explanation presence and known templates; it does not certify semantic documentation quality.",
)
for record in missing
    println("MISSING\t$(relpath(record.path, ROOT)):$(record.line)\t$(record.kind)\t$(record.name)")
end
for (path, line) in audit.orphan_docstrings
    println("ORPHAN_DOCSTRING\t$(relpath(path, ROOT)):$(line)")
end
for (path, message) in audit.parse_failures
    println("PARSE_FAILURE\t$(relpath(path, ROOT))\t$(message)")
end

for record in audit.public_api_missing_docstrings
    println(
        "PUBLIC_API_DOCSTRING_MISSING\t$(relpath(record.path, ROOT)):$(record.line)\t$(record.name)",
    )
end
for record in audit.filler_declarations
    println("KNOWN_FILLER\t$(relpath(record.path, ROOT)):$(record.line)\t$(record.name)")
end
for (path, name, reason) in audit.applied_exceptions
    println("EXCEPTION\t$(relpath(path, ROOT))\t$(name)\t$(reason)")
end

exit(
    isempty(missing) &&
        isempty(audit.orphan_docstrings) &&
        isempty(audit.parse_failures) &&
        isempty(audit.public_api_missing_docstrings) &&
        isempty(audit.filler_declarations) ? 0 : 1,
)
