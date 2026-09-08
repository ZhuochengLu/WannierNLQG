# Standalone fixtures exercise classification independently of the package's current prose.
if !isdefined(@__MODULE__, :SourceDocumentationAudit)
    include(joinpath(@__DIR__, "..", "scripts", "SourceDocumentationAudit.jl"))
end

@testset "documentation presence is distinct from docstrings and known filler" begin
    mktempdir() do directory
        write(
            joinpath(directory, "Fixture.jl"),
            """
export public_comment, public_documented, overloaded
# Return the input offset by one.
public_comment(x) = x + 1
\"Return twice the input without mutating it.\"
public_documented(x) = 2x
# Evaluate filler.
filler(x) = x
\"\"\"
This numerical primitive follows the package-wide unit and index conventions.
It performs neither file I/O nor response accumulation.
\"\"\"
boilerplate(x) = x
# Return the identity.
overloaded(x) = x
\"Return the sum of two arguments.\"
overloaded(x, y) = x + y
undocumented(x) = x
""",
        )
        audit = SourceDocumentationAudit.audit_source_documentation(directory)
        @test isempty(audit.parse_failures)
        @test Set(r.name for r in audit.public_api_missing_docstrings) == Set(["public_comment"])
        @test Set(r.name for r in audit.filler_declarations) == Set(["filler", "boilerplate"])
        @test Set(r.name for r in audit.declarations if !r.documented) == Set(["undocumented"])
        @test count(r -> r.has_docstring, audit.declarations) == 3
        @test isempty(audit.applied_exceptions)
    end
end

@testset "documentation exceptions are explicit and bounded" begin
    mktempdir() do directory
        write(
            joinpath(directory, "Forwarders.jl"),
            """
export bridge
# Evaluate bridge.
bridge(x) = identity(x)
# Evaluate other.
other(x) = identity(x)
""",
        )
        exceptions = Dict(
            ("Forwarders.jl", "bridge") =>
                (kind = :forwarding, reason = "The generated adapter forwards to identity."),
        )
        audit = SourceDocumentationAudit.audit_source_documentation(directory; exceptions)
        @test isempty(audit.public_api_missing_docstrings)
        @test only(audit.filler_declarations).name == "other"
        @test length(audit.applied_exceptions) == 1
        @test_throws ArgumentError SourceDocumentationAudit.audit_source_documentation(
            directory;
            exceptions = Dict(("Forwarders.jl", "bridge") => (kind = :arbitrary, reason = "bad")),
        )
        @test_throws ArgumentError SourceDocumentationAudit.audit_source_documentation(
            directory;
            exceptions = Dict(("Forwarders.jl", "bridge") => (kind = :generated, reason = "")),
        )
    end
end

@testset "nested modules and detached type docstrings" begin
    mktempdir() do directory
        write(
            joinpath(directory, "Nested.jl"),
            """
module Nested
export Configuration
# Controls the enabled mode.
struct Configuration
    enabled::Bool
end
@doc \"Enable or disable the configured mode.\" Configuration
# Read values from its configured input.
read_values(x) = x
module Inner
hidden(x) = x
end
end
""",
        )
        audit = SourceDocumentationAudit.audit_source_documentation(directory)
        @test isempty(audit.public_api_missing_docstrings)
        @test Set(r.name for r in audit.declarations) ==
              Set(["Configuration", "read_values", "hidden"])
        @test only(filter(r -> !r.documented, audit.declarations)).name == "hidden"
        @test only(audit.filler_declarations).name == "read_values"
    end
end

@testset "malformed Julia is a parse failure" begin
    mktempdir() do directory
        write(joinpath(directory, "Malformed.jl"), "function broken(\n")
        audit = SourceDocumentationAudit.audit_source_documentation(directory)
        @test length(audit.parse_failures) == 1
    end
end
