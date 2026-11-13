"""Expose the complete current representation input without copies.

The original representation byte inventory is retained as actual values.
Source-file audits remain in
the original qualification records, rather than becoming numerical equality.
"""
function _restart_representation_input_values(representation::BandRepresentation)
    arrays=(
        :real_lattice,
        :reciprocal_lattice,
        :kpoints_fractional,
        :energies_ev,
        :kpoint_map,
        :reciprocal_shifts,
        :sewing_matrices,
        :band_block_labels,
        :irreducible_indices,
        :full_to_irreducible,
        :full_to_operation,
    )
    return (
        schema = "wanniernlqg.wannierization-representation-input/1",
        source_code = representation.source_code,
        spinor = representation.spinor,
        mp_grid = representation.mp_grid,
        arrays = NamedTuple{arrays}(Tuple(getfield(representation, name) for name in arrays)),
        operations = [
            (
                rotation_fractional = operation.rotation_fractional,
                translation_fractional = operation.translation_fractional,
                rotation_cartesian = operation.rotation_cartesian,
                antiunitary = operation.antiunitary,
            ) for operation in representation.operations
        ],
        conventions = representation.conventions,
    )
end

"""Expose all overlap matrices and neighbour topology, with no source-path identity."""
function _restart_overlap_input_values(mmn::WannierMMN)
    return (
        schema = "wanniernlqg.wannierization-overlap-input/1",
        num_bands = mmn.num_bands,
        num_kpts = mmn.num_kpts,
        num_neighbors = mmn.num_neighbors,
        data = mmn.data,
        neighbors = mmn.neighbors,
        reciprocal_shifts = mmn.reciprocal_shifts,
    )
end

"""Check the source representation separately from the accepted output state."""
function _validate_restart_input_representation(
    definition::WannierizationRestartInputDefinition,
    representation::BandRepresentation,
)
    validate_scientific_input_definition_bytes(
        definition.representation;
        mismatch_error = "RESTART_REPRESENTATION_MISMATCH",
    ) do stream
        write_native_definition_value(stream, _restart_representation_input_values(representation))
    end
    return nothing
end

"""Compare the complete representation and overlaps with an accepted input record."""
function validate_restart_scientific_inputs(
    definition::WannierizationRestartInputDefinition,
    representation::BandRepresentation,
    mmn::WannierMMN,
    ;
    allow_new_operator_profile_sources::Bool = false,
)
    old_names = Set(keys(definition.auxiliary_sources))
    new_names = Set(keys(representation.input_definitions))
    expected_new_names =
        allow_new_operator_profile_sources ? union(old_names, Set(["operator_profile_sources"])) :
        old_names
    new_names == expected_new_names ||
        throw(ArgumentError("RESTART_COMPLETE_AUXILIARY_SOURCE_REQUIRED"))
    for (name, reference) in representation.input_definitions
        allow_new_operator_profile_sources &&
            name == "operator_profile_sources" &&
            !haskey(definition.auxiliary_sources, name) &&
            continue
        validate_scientific_input_definitions_equal(
            reference,
            definition.auxiliary_sources[name];
            mismatch_error = "RESTART_AUXILIARY_SOURCE_MISMATCH: " * name,
        )
    end
    _validate_restart_input_representation(definition, representation)
    validate_scientific_input_definition_bytes(
        definition.overlaps;
        mismatch_error = "RESTART_MMN_MISMATCH",
    ) do stream
        write_native_definition_value(stream, _restart_overlap_input_values(mmn))
    end
    return nothing
end

"""Observe the complete retained initializer when continuation explicitly reuses it."""
function _validate_reused_restart_initializer(definition::ScientificInputDefinition)
    with_scientific_input_definition_bytes(definition) do source
        count=0
        while !eof(source)
            count=Base.Checked.checked_add(count, length(read(source, 65536)))
        end
        count==definition.byte_count || throw(ArgumentError("RESTART_AMN_MISMATCH"))
    end
    return definition
end

"""Adopt fresh inputs once or compare all current values before solver continuation.

No input label/digest is a positive equality proof. A missing AMN on continuation
means explicit reuse of the accepted initializer; its complete retained bytes
remain observed. Original source/qualification and optimizer checks still apply.
"""
function _restart_input_definition(
    config,
    representation,
    mmn,
    amn,
    effective_algorithms,
    apply_symmetry;
    expected = nothing,
    require_expected = false,
    share_fresh = true,
    allow_new_operator_profile_sources = false,
)
    require_expected &&
        expected===nothing &&
        throw(
            ArgumentError(
                "RESTART_INPUT_DEFINITION_REQUIRED: explicit archived conversion with original inputs is required",
            ),
        )
    if expected === nothing &&
       share_fresh &&
       config.solver.parallel == :mpi &&
       get(task_local_storage(), :wannier_native_input_shared_fresh_definition, false)
        # Input adoption is distinct from optimizer continuation. The root writes
        # one original-format definition; every rank compares its complete actual
        # config, basis, representation, overlaps, AMN and auxiliary values below.
        comm = MPI.COMM_WORLD
        rank = MPI.Comm_rank(comm)
        definition = nothing
        packet = if rank == 0
            try
                definition = _restart_input_definition(
                    config,
                    representation,
                    mmn,
                    amn,
                    effective_algorithms,
                    apply_symmetry;
                    share_fresh = false,
                )
                (; ok = true, error = "")
            catch exception
                (; ok = false, error = sprint(showerror, exception))
            end
        else
            nothing
        end
        packet = MPI.bcast(packet, 0, comm)
        packet.ok || throw(ArgumentError("SHARED_FRESH_INPUT_PUBLICATION_FAILED: $(packet.error)"))
        definition = MPI.bcast(definition, 0, comm)
        packet = try
            _restart_input_definition(
                config,
                representation,
                mmn,
                amn,
                effective_algorithms,
                apply_symmetry;
                expected = definition,
                share_fresh = false,
            )
            (; ok = true, error = "")
        catch exception
            (; ok = false, error = sprint(showerror, exception))
        end
        for owner in 0:(MPI.Comm_size(comm) - 1)
            observed = MPI.bcast(rank == owner ? packet : nothing, owner, comm)
            observed.ok || throw(
                ArgumentError(
                    "SHARED_FRESH_INPUT_VALIDATION_FAILED rank=$owner: $(observed.error)",
                ),
            )
        end
        return definition
    end
    configuration="wanniernlqg.wannierization-config-input/1\n" * _restart_config_repr(
        config,
        effective_algorithms,
        apply_symmetry;
        complete_basis = true,
    )
    basis="wanniernlqg.projection-basis-input/1\n" *
          repr(projection_basis_input_values(something(config.input.projection_basis)))
    if expected!==nothing
        configuration==expected.configuration || throw(ArgumentError("RESTART_CONFIG_MISMATCH"))
        basis==expected.projection_basis ||
            throw(ArgumentError("RESTART_PROJECTION_BASIS_MISMATCH"))
        validate_restart_scientific_inputs(
            expected,
            representation,
            mmn;
            allow_new_operator_profile_sources,
        )
        if amn===nothing
            _validate_reused_restart_initializer(expected.initialization)
        else
            validate_scientific_input_definition_bytes(
                expected.initialization;
                mismatch_error = "RESTART_AMN_MISMATCH",
            ) do stream
                write_native_definition_value(
                    stream,
                    ("wanniernlqg.wannierization-initializer/1", amn),
                )
            end
        end
        if allow_new_operator_profile_sources
            # Preserve every accepted mathematical input byte and append only the
            # freshly generated, independently preflighted operator source set.
            new_sources = copy(expected.auxiliary_sources)
            reference = representation.input_definitions["operator_profile_sources"]
            reference_root = config.checkpoint.reference_root
            new_sources["operator_profile_sources"] =
                reference_root === nothing ? reference :
                scientific_input_definition_reference(reference, reference_root)
            return WannierizationRestartInputDefinition(
                expected.configuration,
                expected.projection_basis,
                expected.representation,
                expected.overlaps,
                expected.initialization,
                new_sources,
            )
        end
        return expected
    end
    reference_root=config.checkpoint.reference_root
    directory=something(reference_root, tempdir())
    representation_input=scientific_input_definition_bytes(; reference_root, directory) do stream
        write_native_definition_value(stream, _restart_representation_input_values(representation))
    end
    overlaps=scientific_input_definition_bytes(; reference_root, directory) do stream
        write_native_definition_value(stream, _restart_overlap_input_values(mmn))
    end
    initialization=scientific_input_definition_bytes(; reference_root, directory) do stream
        write_native_definition_value(stream, ("wanniernlqg.wannierization-initializer/1", amn))
    end
    return WannierizationRestartInputDefinition(
        configuration,
        basis,
        representation_input,
        overlaps,
        initialization,
        Dict(
            name => (
                reference_root === nothing ? definition :
                scientific_input_definition_reference(definition, reference_root)
            ) for (name, definition) in representation.input_definitions
        ),
    )
end

"""Write a complete input reference with fixed framing and bounded byte copies."""
function _write_restart_reference_bytes(stream, definition::ScientificInputDefinition)
    write_native_definition_value(stream, definition.byte_count)
    if stream isa ScientificReferenceBuilder
        append_scientific_input_reference!(stream, definition)
        return nothing
    end
    with_scientific_input_definition_bytes(definition) do source
        remaining=definition.byte_count
        while remaining>0
            bytes=read(source, min(65536, remaining))
            isempty(bytes) && throw(ArgumentError("INCOMPLETE_RESTART_INPUT_REFERENCE"))
            write(stream, bytes)==length(bytes) ||
                throw(ArgumentError("INCOMPLETE_RESTART_INPUT_REFERENCE"))
            remaining-=length(bytes)
        end
        eof(source) || throw(ArgumentError("RESTART_INPUT_REFERENCE_EXTENT_MISMATCH"))
    end
    return nothing
end

"""Serialize only actual input bytes; local reference paths/states are absent."""
function _write_restart_input_definition(stream, definition)
    write_native_definition_value(stream, "wanniernlqg.wannierization-restart-input/1")
    if definition===nothing
        write_native_definition_value(stream, nothing)
        return nothing
    end
    write_native_definition_value(stream, (definition.configuration, definition.projection_basis))
    _write_restart_reference_bytes(stream, definition.representation)
    _write_restart_reference_bytes(stream, definition.overlaps)
    _write_restart_reference_bytes(stream, definition.initialization)
    if !isempty(definition.auxiliary_sources)
        write_native_definition_value(stream, "complete-auxiliary-sources/1")
        for name in sort!(collect(keys(definition.auxiliary_sources)))
            write_native_definition_value(stream, name)
            _write_restart_reference_bytes(stream, definition.auxiliary_sources[name])
        end
    end
    return nothing
end

"""Report current continuation-input availability without changing physical qualification."""
function _restart_input_definition_status(state)
    state===nothing && return "NO_RESTART_STATE"
    return state.input_definition===nothing ? "NOT_RECORDED" : "COMPLETE"
end

"""Require actual branch membership before any retained RCG/L-BFGS history is reused."""
function _validate_current_u_branch_history(optimizer::WannierizationOptimizerState)
    definition=optimizer.u_active_orbit_definition
    has_history=!isempty(optimizer.previous_u_gradient) ||
                !isempty(optimizer.previous_u_direction) ||
                !isempty(Float64[])
    isempty(definition) &&
        has_history &&
        throw(ArgumentError("RESTART_U_BRANCH_DEFINITION_REQUIRED"))
    _validate_u_branch_definition(definition)
    return nothing
end
