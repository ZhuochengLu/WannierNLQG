# Decode geometry-only band sampling before the existing TaskSpec compiler.
function _task_input_band_structure(table, base_dir)
    haskey(table, "structure_file") &&
        haskey(table, "structure") &&
        throw(ArgumentError("supply structure_file or inline structure, not both"))
    moments = if haskey(table, "magnetic_moments_cartesian")
        rows = table["magnetic_moments_cartesian"]
        all(
            row ->
                length(row) == 3 && all(x -> x isa Real && !(x isa Bool) && isfinite(x), row),
            rows,
        ) || throw(
            ArgumentError(
                "magnetic_moments_cartesian requires one finite Cartesian axial vector per atom",
            ),
        )
        hcat((Float64.(row) for row in rows)...)
    else
        nothing
    end
    if haskey(table, "structure_file")
        path = abspath(base_dir, _task_input_string(table["structure_file"], "structure_file"))
        isfile(path) || throw(ArgumentError("band structure_file does not exist: $path"))
        observed=with_scientific_source(path; resolve_links = true) do filename
            read_poscar_structure(filename; magnetic_moments_cartesian = moments)
        end
        return observed.value,
        Dict{String, Any}(
            "structure_file" => path,
            "structure_source_identity" => scientific_file_identity(observed.state),
            "structure_format" => "POSCAR",
        )
    elseif haskey(table, "structure")
        value = table["structure"]
        _task_input_keys(
            value,
            ("lattice_angstrom", "species", "positions_fractional"),
            "sampling.structure",
        )
        all(key -> haskey(value, key), ("lattice_angstrom", "species", "positions_fractional")) ||
            throw(
                ArgumentError(
                    "inline structure requires lattice_angstrom, species and positions_fractional",
                ),
            )
        lattice = reduce(vcat, [permutedims(Float64.(row)) for row in value["lattice_angstrom"]])
        positions = hcat((Float64.(row) for row in value["positions_fractional"])...)
        structure = CrystalStructure(
            lattice,
            value["species"],
            positions;
            magnetic_moments_cartesian = moments,
        )
        return structure,
        Dict{String, Any}(
            "structure_format" => "EXPLICIT_INLINE_CRYSTAL",
            "structure_definition" => deepcopy(value),
        )
    end
    return nothing, Dict{String, Any}()
end

# Omitted counts use the model lattice without reading Hamiltonian blocks.
function _task_input_band_lattice(model)
    if model isa ModelInput
        bundle = model.real_space_operator_bundle_file
        if bundle !== nothing && !isempty(bundle)
            manifest = read_real_space_operator_bundle_manifest(bundle)
            return manifest.lattice
        end
        path = isempty(model.model_file) ? model.seedname * "_tb.dat" : model.model_file
        isfile(path) || throw(
            ArgumentError(
                "omitted band counts require a readable model_file or seedname TB header",
            ),
        )
        return read_wannier_tb_lattice(path)
    elseif model isa AnalyticKInput
        return model.lattice
    elseif model isa Union{RealSpaceTBInput, NonorthogonalLocalizedInput}
        return model.model.lattice
    end
    throw(ArgumentError("omitted band counts require the actual model lattice"))
end

# Resolve omission and override rules into the single canonical band sampling type.
function _task_input_band_sampling(table, records, pending, base_dir, model)
    _task_input_keys(
        table,
        (
            "kind",
            "spatial_dimension",
            "nodes",
            "branches",
            "kpoints_per_segment",
            "density",
            "periodic_axes",
            "structure_file",
            "structure",
            "magnetic_moments_cartesian",
            "time_reversal",
            "spglib_symprec_angstrom",
        ),
        "response.sampling",
    )
    dimension = get(table, "spatial_dimension", 3)
    dimension isa Integer && !(dimension isa Bool) && dimension in (2, 3) ||
        throw(ArgumentError("band spatial_dimension must be two or three"))
    haskey(table, "density") &&
        haskey(table, "kpoints_per_segment") &&
        throw(ArgumentError("explicit band counts and density are alternative sampling controls"))
    density = get(table, "density", 50.0)
    density isa Real && !(density isa Bool) && isfinite(density) && density > 0 ||
        throw(ArgumentError("band density must be a positive finite intervals-per-A^-1 value"))
    counts = get(table, "kpoints_per_segment", nothing)
    if counts !== nothing
        values = counts isa AbstractVector ? counts : (counts,)
        all(value -> value isa Integer && !(value isa Bool) && value >= 2, values) ||
            throw(ArgumentError("band point counts must be integers of at least two"))
    end
    structure, structure_provenance = _task_input_band_structure(table, base_dir)
    manual = haskey(table, "nodes")
    sampling = if manual
        raw = table["nodes"]
        raw isa AbstractDict || throw(
            ArgumentError(
                "old [[response.sampling.nodes]] arrays of tables are unsupported; use [response.sampling.nodes] label and fractional_coordinates columns",
            ),
        )
        _task_input_keys(raw, ("label", "fractional_coordinates"), "response.sampling.nodes")
        all(key -> haskey(raw, key), ("label", "fractional_coordinates")) || throw(
            ArgumentError("response.sampling.nodes requires label and fractional_coordinates"),
        )
        labels, coordinates = raw["label"], raw["fractional_coordinates"]
        labels isa AbstractVector &&
        coordinates isa AbstractVector &&
        length(labels) == length(coordinates) &&
        !isempty(labels) || throw(
            ArgumentError(
                "response.sampling.nodes columns must have equal nonzero lengths; old array-of-tables nodes are unsupported",
            ),
        )
        nodes = [
            (
                _task_input_string(label, "band node label"),
                _task_input_tuple(coordinate, "band node coordinates"; lengths = (1, 2, 3)),
            ) for (label, coordinate) in zip(labels, coordinates)
        ]
        ranges = if haskey(table, "branches")
            map(table["branches"]) do range
                endpoints = _task_input_tuple(
                    range,
                    "branch node range";
                    integers = true,
                    lengths = (2,),
                )
                endpoints[1]:endpoints[2]
            end
        else
            nothing
        end
        lattice = counts === nothing ? _task_input_band_lattice(model) : nothing
        KPath(;
            nodes,
            branches = ranges,
            kpoints_per_segment = counts,
            spatial_dimension = dimension,
            lattice,
            density,
            provenance = Dict{String, Any}("path_origin" => "EXPLICIT_MANUAL_PATH"),
        )
    else
        haskey(table, "branches") &&
            throw(ArgumentError("manual branch ranges require manual nodes"))
        if structure === nothing
            _task_input_missing!(
                pending,
                records,
                "response.sampling.structure_file";
                reason = "Automatic Band paths need actual atomic structure: supply POSCAR structure_file or inline structure; orbital centers do not establish a crystal space group.",
            )
            return nothing, deepcopy(table)
        end
        axes = get(table, "periodic_axes", dimension == 3 ? [1, 2, 3] : nothing)
        axes === nothing && throw(
            ArgumentError("2D automatic bands require explicit periodic_axes, for example [1,2]"),
        )
        axes = _task_input_tuple(axes, "periodic_axes"; integers = true, lengths = (dimension,))
        time_reversal = get(table, "time_reversal", nothing)
        time_reversal === nothing ||
            time_reversal isa Bool ||
            throw(ArgumentError("time_reversal must be a Boolean when the model symmetry is known"))
        path = automatic_kpath(
            structure;
            periodic_axes = axes,
            kpoints_per_segment = counts,
            density,
            time_reversal,
            spglib_symprec_angstrom = get(table, "spglib_symprec_angstrom", 1.0e-5),
            model_lattice = model === nothing ? structure.lattice : _task_input_band_lattice(model),
        )
        merge!(path.provenance, structure_provenance)
        path.provenance["path_origin"] = "AUTOMATIC_STRUCTURE_PATH"
        path
    end
    effective = Dict{String, Any}(
        "kind" => "k_path",
        "spatial_dimension" => dimension,
        "nodes" => Dict(
            "label" => [node[1] for node in sampling.nodes],
            "fractional_coordinates" => [collect(node[2]) for node in sampling.nodes],
        ),
        "branches" => [[first(range), last(range)] for range in sampling.branches],
        "kpoints_per_segment" => copy(sampling.kpoints_per_segment),
    )
    for key in ("nodes", "branches", "kpoints_per_segment")
        origin = haskey(table, key) ? "USER" : key == "kpoints_per_segment" ? "DEFAULT" : "DERIVED"
        _task_input_record!(
            records,
            "response.sampling.$key",
            effective[key],
            origin,
            manual ? "manual path and actual model lattice" :
            "actual crystal structure and Brillouin catalogue",
            key == "kpoints_per_segment" ?
            "Counts include endpoints; Cartesian length sets omitted counts." :
            "Connected branches remain separate; coordinates use the input model reciprocal basis.",
        )
    end
    return sampling, effective
end
