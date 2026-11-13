"""Write current restart-input availability separately from legacy audit fields."""
function _write_restart_input_definition_hdf5(
    restart_group,
    state::WannierizationRestartState;
    reference_root = nothing,
)
    status=_restart_input_definition_status(state)
    HDF5.attributes(restart_group)["input_definition_status"]=status
    status=="COMPLETE" || return nothing
    definition=something(state.input_definition)
    startswith(definition.configuration, "wanniernlqg.wannierization-config-input/1\n") &&
    startswith(definition.projection_basis, "wanniernlqg.projection-basis-input/1\n") ||
        throw(ArgumentError("RESTART_INPUT_DEFINITION_FORMAT_MISMATCH"))
    group=HDF5.create_group(restart_group, "input_definition")
    try
        HDF5.attributes(group)["schema"]="wanniernlqg.wannierization-restart-input/2"
        group["configuration_utf8"]=collect(codeunits(definition.configuration))
        group["projection_basis_utf8"]=collect(codeunits(definition.projection_basis))
        auxiliary=HDF5.create_group(group, "auxiliary_sources")
        try
            for name in sort!(collect(keys(definition.auxiliary_sources)))
                occursin(r"^[A-Za-z0-9_-]+$", name) ||
                    throw(ArgumentError("INVALID_AUXILIARY_SOURCE_NAME"))
                write_scientific_input_reference_hdf5(
                    auxiliary,
                    name,
                    definition.auxiliary_sources[name];
                    reference_root,
                )
            end
        finally
            close(auxiliary)
        end
        for name in (:representation, :overlaps, :initialization)
            write_scientific_input_reference_hdf5(
                group,
                String(name),
                getfield(definition, name);
                reference_root,
            )
        end
    finally
        close(group)
    end
    return nothing
end

"""Read a complete small UTF-8 definition without interpreting it as executable code."""
function _read_restart_input_text_hdf5(group, name, prefix)
    bytes=read(group[name])
    bytes isa Vector{UInt8} || throw(ArgumentError("INVALID_RESTART_INPUT_TEXT"))
    text=String(bytes)
    isvalid(text) && startswith(text, prefix) ||
        throw(ArgumentError("RESTART_INPUT_DEFINITION_FORMAT_MISMATCH"))
    return text
end

"""Preserve explicit unqualified raw states; never infer missing original inputs."""
function _read_restart_input_definition_hdf5(restart_group; reference_root = nothing)
    status=String(required_attribute(restart_group, "input_definition_status"))
    if status=="NOT_RECORDED"
        !haskey(restart_group, "input_definition") ||
            throw(ArgumentError("RESTART_INPUT_DEFINITION_STATUS_MISMATCH"))
        return nothing
    end
    status=="COMPLETE" || throw(ArgumentError("RESTART_INPUT_DEFINITION_STATUS_MISMATCH"))
    group=restart_group["input_definition"]
    try
        schema=String(required_attribute(group, "schema"))
        schema in (
            "wanniernlqg.wannierization-restart-input/1",
            "wanniernlqg.wannierization-restart-input/2",
        ) &&
        Set(
            String.(keys(group)),
        )==Set(
            vcat(
                [
                    "configuration_utf8",
                    "projection_basis_utf8",
                    "representation",
                    "overlaps",
                    "initialization",
                ],
                schema=="wanniernlqg.wannierization-restart-input/2" ? ["auxiliary_sources"] :
                String[],
            ),
        ) || throw(ArgumentError("RESTART_INPUT_DEFINITION_FORMAT_MISMATCH"))
        configuration=_read_restart_input_text_hdf5(
            group,
            "configuration_utf8",
            "wanniernlqg.wannierization-config-input/1\n",
        )
        basis=_read_restart_input_text_hdf5(
            group,
            "projection_basis_utf8",
            "wanniernlqg.projection-basis-input/1\n",
        )
        return WannierizationRestartInputDefinition(
            configuration,
            basis,
            read_scientific_input_reference_hdf5(group, "representation"; reference_root),
            read_scientific_input_reference_hdf5(group, "overlaps"; reference_root),
            read_scientific_input_reference_hdf5(group, "initialization"; reference_root),
            haskey(group, "auxiliary_sources") ?
            Dict(
                String(
                    name,
                )=>read_scientific_input_reference_hdf5(
                    group["auxiliary_sources"],
                    String(name);
                    reference_root,
                ) for name in keys(group["auxiliary_sources"])
            ) : Dict{String, ScientificInputDefinition}(),
        )
    finally
        close(group)
    end
end

"""Persist complete branch membership without a content digest."""
function _write_restart_branch_definition_hdf5(group, optimizer; qualified = false)
    definition=optimizer.u_active_orbit_definition
    if qualified
        _validate_current_u_branch_history(optimizer)
    end
    group["u_active_orbit_definition_utf8"]=collect(codeunits(definition))
    return nothing
end

"""Restore current branch values; raw historical states remain explicitly unknown."""
function _read_restart_branch_definition_hdf5(group, optimizer; qualified = false)
    bytes=read(group["u_active_orbit_definition_utf8"])
    bytes isa Vector{UInt8} || throw(ArgumentError("INVALID_U_BRANCH_DEFINITION"))
    definition=String(bytes)
    isvalid(definition) || throw(ArgumentError("INVALID_U_BRANCH_DEFINITION"))
    # A caller may already hold the actual branch definition. Never silently
    # replace that value with a different, merely well-formed stored branch.
    # The initial checkpoint decoder has no definition until this dataset is read.
    expected = optimizer.u_active_orbit_definition
    isempty(expected) ||
        expected == definition ||
        throw(ArgumentError("U_BRANCH_DEFINITION_MISMATCH"))
    restored=WannierizationOptimizerState(
        (
            name===:u_active_orbit_definition ? definition : getfield(optimizer, name) for
            name in fieldnames(WannierizationOptimizerState)
        )...,
    )
    qualified && _validate_current_u_branch_history(restored)
    return restored
end
