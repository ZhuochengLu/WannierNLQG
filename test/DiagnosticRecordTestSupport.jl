module DiagnosticRecordTestSupport

"""Retain every original diagnostic value, including info/PASS and unavailable fields."""
function diagnostic_records(diagnostics, code::AbstractString)
    return [
        (
            code = String(record.code),
            severity = String(record.severity),
            message = record.message,
            context = copy(record.context),
        ) for record in diagnostics if String(record.code) == code
    ]
end

function require_diagnostic_records(diagnostics, code::AbstractString)
    records = diagnostic_records(diagnostics, code)
    isempty(records) &&
        throw(ArgumentError("fixture lacks the expected original diagnostic: " * code))
    return records
end

end
