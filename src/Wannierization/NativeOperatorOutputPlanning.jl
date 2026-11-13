"""Whether raw operator publication has an actual native wavefunction source.

File-topology VASP inputs retain an external EIG, but their PAW matrices and
operator generators still read the same raw VASP source.  EIG/source numerical
parity is checked before publication in the extension.
"""
function uses_native_operator_generation(input)
    uses_generated_native_eigenvalues(input) && return true
    return input.matrix_elements isa NativeVASPPAWMatrices &&
           input.matrix_elements.topology_mmn_file !== nothing &&
           input.source isa SymmetryFoundation.VASPWavefunctionSource
end

"""Return the demanded generated artifact paths for one native input.

Paths are outputs of the same source pipeline, not user-supplied provenance
records. Legacy external providers return no implicit generation plan.
"""
function native_operator_artifact_paths(input, profile, tasks)
    uses_native_operator_generation(input) || return Dict{Symbol, String}()
    sources = resolved_source_inventory(
        resolve_operator_selection(profile, tasks; content_authentication = false),
    )
    directory = joinpath(input.matrix_elements.artifact_dir, "operators")
    paths = Dict{Symbol, String}()
    if :spn in sources
        paths[:spn_file] = joinpath(directory, "native.spn")
        paths[:spn_provenance_file] = joinpath(
            directory,
            input.source isa SymmetryFoundation.VASPWavefunctionSource ? "native.spn.h5" :
            "native.spn.json",
        )
    end
    for (source, suffix) in ((:uiu, "uIu"), (:uhu, "uHu"), (:siu, "sIu"), (:shu, "sHu"))
        source in sources || continue
        paths[Symbol(source, "_file")] = joinpath(directory, "native."*suffix)
        paths[Symbol(source, "_provenance_json")] =
            joinpath(directory, "native."*suffix*".provenance.json")
    end
    return paths
end

"""Reject any generated path that is not the canonical same-input artifact."""
function validate_native_operator_artifact_paths(config)
    expected = native_operator_artifact_paths(
        config.input,
        config.output.profile,
        config.output.operator_tasks,
    )
    isempty(expected) && return expected
    actual_paths = Dict{Symbol, String}()
    for (field, path) in expected
        actual = getfield(config.output, field)
        actual !== nothing ||
            throw(ArgumentError("NATIVE_OPERATOR_OUTPUT_BINDING_MISMATCH: $field"))
        actual_paths[field] = abspath(actual)
    end
    if all(pair -> actual_paths[first(pair)] == abspath(last(pair)), expected)
        return expected
    end
    # A retained optimizer checkpoint binds the original native source directory.
    # New raw operator publications must use this new model's own output workspace,
    # not mutate the accepted matrix source or any sealed old artifact.
    output_model = config.output.model_file
    if config.solver.initialization == :restart &&
       config.checkpoint.restart_hdf5 !== nothing &&
       output_model !== nothing
        directory = joinpath(dirname(abspath(output_model)), "native-operators")
        if all(
            pair -> actual_paths[first(pair)] == joinpath(directory, basename(last(pair))),
            expected,
        )
            return actual_paths
        end
    end
    # A restart can read a complete prior publication in place. This is only
    # a path-level admission: generation must independently validate the
    # checkpoint's complete operator source reference before returning without
    # writing any of these files. Without such a reference the generator still
    # requires a fresh output workspace.
    if config.solver.initialization == :restart &&
       config.checkpoint.restart_hdf5 !== nothing &&
       config.input.preparation_execution.resume &&
       !isempty(actual_paths)
        directory = dirname(first(values(actual_paths)))
        complete_existing =
            isdir(directory) &&
            !islink(directory) &&
            realpath(directory) == directory &&
            all(
                pair ->
                    actual_paths[first(pair)] == joinpath(directory, basename(last(pair))) &&
                    isfile(actual_paths[first(pair)]) &&
                    !islink(actual_paths[first(pair)]),
                expected,
            )
        complete_existing && return actual_paths
    end
    throw(
        ArgumentError(
            "NATIVE_OPERATOR_OUTPUT_BINDING_MISMATCH: complete fresh-output binding required",
        ),
    )
end
