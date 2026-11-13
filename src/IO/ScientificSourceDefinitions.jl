"""Own an exact source-byte definition in private sequential scratch.

This preserves strict persisted source pairing, including the original raw TB
before replica materialization. Full byte comparison includes all encoded model
values and their order; no owner label or digest proves equality. Only64KiB is
buffered while copying. The caller closes the returned definition stream and
retains failed comparison evidence under the existing lifecycle.
"""
function scientific_source_definition_stream(path::AbstractString; expected_state = nothing)
    isfile(path) || throw(ArgumentError("ScientificSourceDefinitionInputMissing: $path"))
    before=scientific_file_state(realpath(path))
    expected_state===nothing ||
        isequal(before, expected_state) ||
        throw(ArgumentError("ScientificSourceDefinitionInputChanged"))
    definition = nothing
    try
        observed = with_scientific_source(
            path;
            resolve_links = true,
            expected_record = scientific_file_record(before),
        ) do filename
            definition = scientific_definition_stream() do output
                open(filename, "r") do input
                    remaining=before.bytes
                    while remaining>0
                        count=min(65536, remaining)
                        bytes = read(input, count)
                        length(bytes)==count ||
                            error("IncompleteScientificSourceDefinitionRead")
                        write(output, bytes) == length(bytes) ||
                            error("IncompleteScientificSourceDefinitionWrite")
                        remaining-=count
                    end
                    eof(input) || error("ScientificSourceDefinitionGrewDuringRead")
                end
            end
        end
        return observed.value
    catch
        definition === nothing || close(definition; retain = true)
        rethrow()
    end
end
