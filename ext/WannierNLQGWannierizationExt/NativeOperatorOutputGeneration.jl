"""Compare an external EIG with the selected raw VASP WAVECAR eigenvalues.

The file-topology path deliberately does not claim to own or regenerate EIG.
Only its numerical identity with the raw coefficient source permits the same
source operator generators to run.  WAVECAR metadata records are read without
loading coefficient arrays.
"""
function _validate_file_topology_vasp_eig(config, resolved_matrices)
    provider = config.input.matrix_elements
    provider isa NativeVASPPAWMatrices && provider.topology_mmn_file !== nothing || return nothing
    source = config.input.source
    source isa VASPWavefunctionSource ||
        throw(ArgumentError("NATIVE_OPERATOR_VASP_SOURCE_REQUIRED"))
    eig = IO.read_wannier_eig(config.input.eig_file)
    header = SymmetryFoundation.read_vasp_wavecar_header(source.wavecar_file)
    source.spin_channel <= header.spin_channels ||
        throw(ArgumentError("NATIVE_OPERATOR_VASP_SPIN_CHANNEL_MISMATCH"))
    bands = SymmetryFoundation.selected_band_range(source.band_range, header.num_bands)
    eig.num_bands == length(bands) == resolved_matrices.mmn.num_bands &&
    eig.num_kpts == header.num_kpoints == resolved_matrices.mmn.num_kpts ||
        throw(ArgumentError("NATIVE_OPERATOR_VASP_EIG_DIMENSION_MISMATCH"))
    tolerance_ev = 1.0e-10
    open(source.wavecar_file, "r") do stream
        for kpoint in 1:header.num_kpoints
            record_index =
                2 +
                (source.spin_channel - 1) * header.num_kpoints * (header.num_bands + 1) +
                (kpoint - 1) * (header.num_bands + 1)
            values = SymmetryFoundation.read_values_at(
                stream,
                Float64,
                header.record_length * record_index,
                4 + 3 * header.num_bands,
            )
            table = SymmetryFoundation.row_major_matrix(values[5:end], header.num_bands, 3)
            for (local_band, source_band) in enumerate(bands)
                raw_ev = table[source_band, 1]
                external_ev = eig.data[local_band, kpoint]
                isfinite(raw_ev) &&
                isfinite(external_ev) &&
                abs(raw_ev - external_ev) <= tolerance_ev || throw(
                    ArgumentError(
                        "NATIVE_OPERATOR_VASP_EIG_SOURCE_MISMATCH: " *
                        "kpoint=$kpoint band=$local_band",
                    ),
                )
            end
        end
    end
    return nothing
end

"""Permit only an authenticated uIu continuation in a fresh publication workspace."""
function _validate_native_restart_output_directory(directory, paths, resume)
    ispath(directory) || return :empty
    isdir(directory) && !islink(directory) && realpath(directory) == directory ||
        throw(ArgumentError("NATIVE_RESTART_OPERATOR_OUTPUT_NOT_CANONICAL"))
    entries = Set(readdir(directory))
    isempty(entries) && return :empty
    complete = Set{String}()
    for key in (
        :spn_file,
        :spn_provenance_file,
        :uiu_file,
        :uhu_file,
        :siu_file,
        :shu_file,
        :uiu_provenance_json,
        :uhu_provenance_json,
        :siu_provenance_json,
        :shu_provenance_json,
    )
        haskey(paths, key) || continue
        push!(complete, basename(paths[key]))
        endswith(String(key), "provenance_json") &&
            push!(complete, basename(paths[key]) * ".references.h5")
    end
    if resume &&
       length(complete) == 14 &&
       entries == complete &&
       all(name -> isfile(joinpath(directory, name)) && !islink(joinpath(directory, name)), entries)
        return :completed_all
    end
    pair = Set{String}()
    for key in (:uiu_file, :uhu_file, :uiu_provenance_json, :uhu_provenance_json)
        haskey(paths, key) || continue
        push!(pair, basename(paths[key]))
        endswith(String(key), "provenance_json") &&
            push!(pair, basename(paths[key]) * ".references.h5")
    end
    pair_spn = copy(pair)
    for key in (:spn_file, :spn_provenance_file)
        haskey(paths, key) && push!(pair_spn, basename(paths[key]))
    end
    if resume &&
       length(pair_spn) == 8 &&
       entries == pair_spn &&
       all(name -> isfile(joinpath(directory, name)) && !islink(joinpath(directory, name)), entries)
        return :completed_pair_spn
    end
    if resume &&
       length(pair) == 6 &&
       entries == pair &&
       all(name -> isfile(joinpath(directory, name)) && !islink(joinpath(directory, name)), entries)
        return :completed_pair
    end
    # The uIu generator subsequently validates the actual source references,
    # execution contract, completed blocks and checksums before appending.
    uiu = get(paths, :uiu_file, nothing)
    provenance = get(paths, :uiu_provenance_json, nothing)
    allowed =
        uiu === nothing || provenance === nothing ? Set{String}() :
        Set((
            basename(uiu) * ".partial",
            basename(uiu) * ".partial.json",
            basename(provenance) * ".references.h5",
        ))
    (
        resume &&
        entries == allowed &&
        all(
            name -> isfile(joinpath(directory, name)) && !islink(joinpath(directory, name)),
            entries,
        )
    ) || throw(ArgumentError("NATIVE_RESTART_OPERATOR_OUTPUT_NOT_FRESH"))
    return :partial
end

"""Generate the demanded same-source operators once through existing public generators.

All numerical qualification and publication/recovery remain in their original
owners. No output, convergence or physical qualification is upgraded here.
"""
function generate_native_operator_outputs(
    config,
    resolved_matrices,
    target;
    accepted_result = nothing,
    eig = nothing,
)
    paths = Wannierization.validate_native_operator_artifact_paths(config)
    isempty(paths) && return nothing
    _validate_file_topology_vasp_eig(config, resolved_matrices)
    completed_pair = false
    completed_spn = false
    completed_all_summary = nothing
    if accepted_result !== nothing
        state=accepted_result.restart_state
        state===nothing && throw(ArgumentError("NATIVE_RESTART_OPERATOR_REFERENCE_REQUIRED"))
        definition=state.input_definition
        definition===nothing && throw(ArgumentError("NATIVE_RESTART_OPERATOR_REFERENCE_REQUIRED"))
        reference=get(definition.auxiliary_sources, "operator_profile_sources", nothing)
        if reference !== nothing
            IO.validate_scientific_source_collection(
                operator_profile_source_files(config),
                reference,
            )
            # The caller still performs the original target/gauge/authority preflight.
            return nothing
        end
        # An H/r-only checkpoint contains a valid optimizer state but no complete
        # operator sources. The caller has validated its native acceptance record;
        # generate the missing raw sources into the new model's isolated output
        # workspace. The old checkpoint and accepted matrix directory stay read-only.
        isolated_directory =
            joinpath(dirname(abspath(config.output.model_file)), "native-operators")
        directory = dirname(abspath(first(values(paths))))
        all(path -> dirname(abspath(path)) == directory, values(paths)) ||
            throw(ArgumentError("NATIVE_RESTART_COMPLETE_OPERATOR_OUTPUT_NOT_ISOLATED"))
        parent = dirname(directory)
        isdir(parent) && realpath(parent) == parent ||
            throw(ArgumentError("NATIVE_RESTART_OPERATOR_OUTPUT_PARENT_NOT_CANONICAL"))
        mode = _validate_native_restart_output_directory(
            directory,
            paths,
            config.input.preparation_execution.resume,
        )
        # External paths are read-only: only a fully published set may be
        # admitted. Partial or pair-only paths can trigger generators and must
        # remain in this new model's isolated workspace.
        directory != isolated_directory &&
            mode != :completed_all &&
            throw(ArgumentError("NATIVE_RESTART_COMPLETE_OPERATOR_OUTPUT_NOT_ISOLATED"))
        if mode in (:completed_pair, :completed_pair_spn)
            eig === nothing && throw(ArgumentError("COMPLETED_OPERATOR_EIG_REQUIRED"))
            completed_spn = mode == :completed_pair_spn
            validate_completed_operator_pair(
                config,
                eig,
                resolved_matrices.mmn,
                target,
                native_preparation_source_files(config.input.source);
                reuse_spn = completed_spn,
            )
            completed_pair = true
        elseif mode == :completed_all
            eig === nothing && throw(ArgumentError("COMPLETED_OPERATOR_EIG_REQUIRED"))
            completed_all_summary = validate_completed_operator_set(
                config,
                eig,
                resolved_matrices.mmn,
                target,
                native_preparation_source_files(config.input.source),
            )
            completed_pair = true
        end
        native_root = realpath(config.input.matrix_elements.artifact_dir)
        (
            directory == native_root ||
            startswith(directory, native_root * Base.Filesystem.path_separator)
        ) && throw(ArgumentError("NATIVE_RESTART_OPERATOR_OUTPUT_OVERLAPS_ACCEPTED_INPUT"))
    end
    directory = dirname(first(values(paths)))
    mkpath(directory)
    source = config.input.source
    # Full-profile two-neighbour files are already atomically published.  A
    # second complete per-centre copy of each file would exhaust bounded local
    # storage on a production mesh.  Keep the solver's own checkpoint contract
    # unchanged; a failed operator publication must be retried in a new output
    # workspace rather than claiming a partially written source as complete.
    operator_checkpoint_directory =
        config.solver.parallel == :mpi && config.output.profile == :full ? nothing :
        joinpath(directory, "preparation")
    execution = Wannierization.WavefunctionPreparationExecutionConfig(;
        (
            field=>getfield(config.input.preparation_execution, field) for
            field in fieldnames(Wannierization.WavefunctionPreparationExecutionConfig) if
            field != :checkpoint_directory
        )...,
        checkpoint_directory = operator_checkpoint_directory,
    )
    topology = resolved_matrices.mmn_file
    if haskey(paths, :spn_file) && completed_all_summary === nothing && !completed_spn
        result = if source isa VASPWavefunctionSource
            # The existing SPN API requires an explicit selected band interval.
            # Resolve the all-band case from the already-generated authoritative EIG.
            spin_source =
                source.band_range === nothing ?
                VASPWavefunctionSource(
                    source.poscar_file,
                    source.wavecar_file;
                    (
                        field=>getfield(source, field) for
                        field in fieldnames(typeof(source)) if
                        field ∉ (:poscar_file, :wavecar_file, :band_range)
                    )...,
                    band_range = 1:resolved_matrices.mmn.num_bands,
                ) : source
            Wannierization.generate_vasp_paw_spn(
                spin_source;
                output_spn_file = paths[:spn_file],
                provenance_hdf5 = paths[:spn_provenance_file],
                spin_channel = source.spin_channel,
                execution,
                target_contract = target,
            )
        else
            Wannierization.generate_qe_paw_spn(
                source,
                topology;
                output_spn_file = paths[:spn_file],
                provenance_json = paths[:spn_provenance_file],
                execution,
            )
        end
        result.passed || throw(ArgumentError("NATIVE_OPERATOR_GENERATION_FAILED: SPN"))
    end
    if haskey(paths, :uiu_file) && !completed_pair
        result = Wannierization.generate_wannier_uiu(
            Wannierization.WannierUIUGenerationConfig(
                source = source,
                topology_file = topology,
                output_file = paths[:uiu_file],
                provenance_json = paths[:uiu_provenance_json],
                oracle_mmn_file = topology,
                authoritative_mmn_file = topology,
                target_contract = target,
                authoritative_hamiltonian = config.input.authoritative_hamiltonian,
                wavefunction_gauge_hdf5 = config.input.wavefunction_gauge_hdf5,
                execution = execution,
                source_reference_root = config.checkpoint.reference_root,
            ),
        )
        result.passed || throw(ArgumentError("NATIVE_OPERATOR_GENERATION_FAILED: uIu"))
    end
    for (kind, generator) in (
        (:uhu, Wannierization.generate_wannier_uhu),
        (:siu, Wannierization.generate_wannier_siu),
        (:shu, Wannierization.generate_wannier_shu),
    )
        completed_all_summary === nothing || continue
        kind == :uhu && completed_pair && continue
        field=Symbol(kind, "_file")
        haskey(paths, field) || continue
        result=generator(
            Wannierization.WannierHamiltonianOperatorGenerationConfig(
                source = source,
                topology_file = topology,
                eig_file = config.input.eig_file,
                output_file = paths[field],
                provenance_json = paths[Symbol(kind, "_provenance_json")],
                authoritative_mmn_file = topology,
                target_contract = target,
                spn_file = kind==:uhu ? nothing : get(paths, :spn_file, nothing),
                spn_provenance_file = kind==:uhu ? nothing :
                                      get(paths, :spn_provenance_file, nothing),
                authoritative_hamiltonian = config.input.authoritative_hamiltonian,
                wavefunction_gauge_hdf5 = config.input.wavefunction_gauge_hdf5,
                execution = execution,
                source_reference_root = config.checkpoint.reference_root,
            ),
        )
        result.passed || throw(ArgumentError("NATIVE_OPERATOR_GENERATION_FAILED: $kind"))
    end
    return completed_all_summary
end
