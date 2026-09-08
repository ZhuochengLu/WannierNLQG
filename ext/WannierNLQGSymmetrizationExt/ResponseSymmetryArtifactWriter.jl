const RESPONSE_SYMMETRY_ARTIFACT_SCHEMA = "wanniernlqg.response-symmetry/1.0"
const RESPONSE_ATOM_FRACTIONAL_TOLERANCE = 1.0e-5
const RESPONSE_MAGNETIC_MOMENT_ABSOLUTE_TOLERANCE = 1.0e-8
const RESPONSE_MAGNETIC_MOMENT_RELATIVE_TOLERANCE = 1.0e-8
const RESPONSE_SEITZ_TRANSLATION_TOLERANCE = 1.0e-5

# Hash one provenance input without retaining its bytes.
_response_artifact_sha256(path::AbstractString) =
    open(path, "r") do io
        bytes2hex(SHA.sha256(io))
    end

# Convert a Julia matrix to schema-stable JSON row arrays.
_response_artifact_matrix_rows(matrix::AbstractMatrix) =
    [[matrix[row, column] for column in axes(matrix, 2)] for row in axes(matrix, 1)]

# Select one required QE XML node with a field-specific error.
function _response_qe_xml_required(node, xpath::AbstractString)
    selected = EzXML.findfirst(xpath, node)
    selected === nothing && throw(ArgumentError("QE XML is missing $(xpath)"))
    return selected
end

# Parse a finite numeric vector from one QE XML node.
function _response_qe_xml_numbers(node)
    values = parse.(Float64, split(strip(EzXML.nodecontent(node))))
    all(isfinite, values) || throw(ArgumentError("QE XML contains non-finite numeric data"))
    return values
end

# Extract the chemical element from a QE atomic label.
function _response_qe_element(label::AbstractString)
    matched = match(r"^([A-Z][a-z]?)", strip(label))
    matched === nothing &&
        throw(ArgumentError("QE atomic type $(repr(label)) does not begin with an element symbol"))
    return String(matched.captures[1])
end

# Read a structure only from an explicit QE data-file-schema.xml path.
function _read_response_qe_structure(filename::AbstractString; magnetic_moments_cartesian = nothing)
    isfile(filename) || throw(ArgumentError("QE XML does not exist: $(filename)"))
    basename(filename) == "data-file-schema.xml" || throw(
        ArgumentError(
            "QE structure input must point directly to data-file-schema.xml; got $(filename)",
        ),
    )
    document = EzXML.readxml(filename)
    root = EzXML.root(document)
    input_node = _response_qe_xml_required(root, "//*[local-name()='input']")
    structure_node = _response_qe_xml_required(input_node, ".//*[local-name()='atomic_structure']")
    cell_node = _response_qe_xml_required(structure_node, "./*[local-name()='cell']")
    lattice = zeros(Float64, 3, 3)
    for row in 1:3
        values = _response_qe_xml_numbers(
            _response_qe_xml_required(cell_node, "./*[local-name()='a$(row)']"),
        )
        length(values) == 3 || throw(ArgumentError("QE lattice row $(row) is malformed"))
        lattice[row, :] .= BOHR_TO_ANGSTROM .* values
    end
    atom_nodes =
        EzXML.findall("./*[local-name()='atomic_positions']/*[local-name()='atom']", structure_node)
    isempty(atom_nodes) && throw(ArgumentError("QE XML contains no atoms"))
    cartesian = zeros(Float64, 3, length(atom_nodes))
    atomic_type_labels = String[]
    elements = String[]
    for (atom, node) in enumerate(atom_nodes)
        values = _response_qe_xml_numbers(node)
        length(values) == 3 || throw(ArgumentError("QE atom $(atom) position is malformed"))
        cartesian[:, atom] .= BOHR_TO_ANGSTROM .* values
        label = strip(String(node["name"]))
        isempty(label) && throw(ArgumentError("QE atom $(atom) has an empty type label"))
        push!(atomic_type_labels, label)
        push!(elements, _response_qe_element(label))
    end
    positions_fractional = transpose(inv(lattice)) * cartesian
    structure =
        CrystalStructure(lattice, elements, positions_fractional; magnetic_moments_cartesian)
    type_nodes =
        EzXML.findall(".//*[local-name()='atomic_species']/*[local-name()='species']", input_node)
    type_labels = [strip(String(node["name"])) for node in type_nodes]
    isempty(type_labels) && (type_labels = unique(atomic_type_labels))
    return structure, atomic_type_labels, type_labels
end

# Read one indexed assignment from an explicitly supplied QE input file.
function _qe_input_assignment(text::AbstractString, name::AbstractString, index::Int)
    pattern = Regex("(?im)^\\s*$(name)\\s*\\(\\s*$(index)\\s*\\)\\s*=\\s*" * "([-+0-9.eEdD]+)")
    matched = match(pattern, text)
    matched === nothing && return nothing
    value = parse(Float64, replace(matched.captures[1], 'D' => 'E', 'd' => 'e'))
    isfinite(value) || throw(ArgumentError("QE input $(name)($(index)) is non-finite"))
    return value
end

# Convert QE starting-magnetization angles into explicit Cartesian moments.
function _read_qe_input_magnetic_moments(
    filename::AbstractString,
    atomic_type_labels::AbstractVector{<:AbstractString},
    type_labels::AbstractVector{<:AbstractString},
)
    isfile(filename) || throw(ArgumentError("QE magnetic input does not exist: $(filename)"))
    text = read(filename, String)
    moments_by_type = Dict{String, Vector{Float64}}()
    found_any = false
    for (index, label) in enumerate(type_labels)
        magnitude = _qe_input_assignment(text, "starting_magnetization", index)
        magnitude === nothing && continue
        found_any = true
        theta = something(_qe_input_assignment(text, "angle1", index), 0.0)
        phi = something(_qe_input_assignment(text, "angle2", index), 0.0)
        theta_radians = deg2rad(theta)
        phi_radians = deg2rad(phi)
        moments_by_type[label] =
            magnitude .* Float64[
                sin(theta_radians) * cos(phi_radians),
                sin(theta_radians) * sin(phi_radians),
                cos(theta_radians),
            ]
    end
    found_any || throw(
        ArgumentError(
            "QE magnetic input contains no explicit starting_magnetization(i) assignments",
        ),
    )
    moments = zeros(Float64, 3, length(atomic_type_labels))
    for (atom, label) in enumerate(atomic_type_labels)
        haskey(moments_by_type, label) || throw(
            ArgumentError(
                "QE magnetic input has no starting_magnetization for atomic type $(label)",
            ),
        )
        moments[:, atom] .= moments_by_type[label]
    end
    return moments
end

# Normalize WIN, POSCAR, or QE XML input into one structure payload.
function _response_artifact_structure(
    structure_file::AbstractString,
    structure_format::Symbol,
    magnetic_moments_cartesian,
    qe_magnetic_input_file,
    vasp_magnetic_input_file,
    collinear_axis_cartesian,
)
    source = abspath(structure_file)
    isfile(source) || throw(ArgumentError("structure file does not exist: $(source)"))
    format = structure_format
    if format == :auto
        format =
            endswith(lowercase(source), ".win") ? :win :
            basename(source) == "data-file-schema.xml" ? :qe_xml : :poscar
    end
    format in (:win, :poscar, :qe_xml) ||
        throw(ArgumentError("structure_format must be :auto, :win, :poscar, or :qe_xml"))
    if qe_magnetic_input_file !== nothing && vasp_magnetic_input_file !== nothing
        throw(
            ArgumentError(
                "qe_magnetic_input_file and vasp_magnetic_input_file are mutually exclusive",
            ),
        )
    end
    if magnetic_moments_cartesian !== nothing && qe_magnetic_input_file !== nothing
        throw(
            ArgumentError(
                "provide either magnetic_moments_cartesian or qe_magnetic_input_file, not both",
            ),
        )
    end
    if format != :qe_xml && qe_magnetic_input_file !== nothing
        throw(ArgumentError("qe_magnetic_input_file is valid only with structure_format=:qe_xml"))
    end
    if format != :poscar && vasp_magnetic_input_file !== nothing
        throw(ArgumentError("vasp_magnetic_input_file is valid only with structure_format=:poscar"))
    end
    if collinear_axis_cartesian !== nothing && vasp_magnetic_input_file === nothing
        throw(ArgumentError("collinear_axis_cartesian requires vasp_magnetic_input_file"))
    end
    if format == :win
        input = read_wannier_win(source)
        return crystal_structure(input; magnetic_moments_cartesian), format, nothing, nothing
    elseif format == :poscar
        structural_poscar = read_poscar_structure(source)
        vasp_state = if vasp_magnetic_input_file === nothing
            nothing
        else
            _read_vasp_incar_magnetic_state(
                abspath(something(vasp_magnetic_input_file)),
                length(structural_poscar.species);
                collinear_axis_cartesian,
            )
        end
        moments = if vasp_state === nothing
            magnetic_moments_cartesian
        elseif magnetic_moments_cartesian === nothing
            vasp_state.moments_cartesian
        else
            _validate_vasp_cartesian_moment_agreement(
                magnetic_moments_cartesian,
                vasp_state.moments_cartesian,
            )
        end
        structure = CrystalStructure(
            structural_poscar.lattice,
            structural_poscar.species,
            structural_poscar.positions_fractional;
            magnetic_moments_cartesian = moments,
        )
        return structure, format, nothing, vasp_state
    end
    structure, atomic_type_labels, type_labels = _read_response_qe_structure(source)
    moments = if magnetic_moments_cartesian !== nothing
        Matrix{Float64}(magnetic_moments_cartesian)
    elseif qe_magnetic_input_file !== nothing
        _read_qe_input_magnetic_moments(
            abspath(something(qe_magnetic_input_file)),
            atomic_type_labels,
            type_labels,
        )
    else
        nothing
    end
    return CrystalStructure(
        structure.lattice,
        structure.species,
        structure.positions_fractional;
        magnetic_moments_cartesian = moments,
    ),
    format,
    atomic_type_labels,
    nothing
end

# Serialize one operation with literal-lattice and group-consistent Cartesian actions.
function _response_operation_payload(
    operation::SymmetryOperation,
    source_indices::Vector{Int},
    rotation_data,
    cartesian_rotation_policy::Symbol,
)
    key = Tuple(vec(operation.rotation_fractional))
    raw = rotation_data.raw_rotations[key]
    effective = rotation_data.effective_rotations[key]
    selected = operation.rotation_cartesian
    identity = Matrix{Float64}(I, 3, 3)
    return Dict(
        "rotation_fractional" => _response_artifact_matrix_rows(operation.rotation_fractional),
        "translation_fractional" => operation.translation_fractional,
        "rotation_cartesian" => _response_artifact_matrix_rows(selected),
        "rotation_cartesian_raw" => _response_artifact_matrix_rows(raw),
        "rotation_cartesian_effective" => _response_artifact_matrix_rows(effective),
        "cartesian_rotation_use" => string(cartesian_rotation_policy),
        "antiunitary" => operation.antiunitary,
        "source_space_group_indices" => source_indices,
        "raw_cartesian_orthogonality_residual" => maximum(abs, raw' * raw - identity),
        "effective_cartesian_orthogonality_residual" =>
            maximum(abs, effective' * effective - identity),
        "cartesian_matrix_correction_max_abs" => maximum(abs, effective - raw),
    )
end

# Deduplicate space-group operations by point action and antiunitary flag.
function _deduplicate_response_point_operations(operations::Vector{SymmetryOperation})
    point_operations = SymmetryOperation[]
    source_indices = Vector{Vector{Int}}()
    key_to_index = Dict{Tuple{Tuple, Bool}, Int}()
    for (source_index, operation) in enumerate(operations)
        key = (Tuple(vec(operation.rotation_fractional)), operation.antiunitary)
        if haskey(key_to_index, key)
            push!(source_indices[key_to_index[key]], source_index)
        else
            push!(point_operations, operation)
            push!(source_indices, [source_index])
            key_to_index[key] = length(point_operations)
        end
    end
    return point_operations, source_indices
end

# Compute exact fractional identity, inverse, and closure qualifications for a point group.
function _response_point_group_checks(operations::Vector{SymmetryOperation})
    keys = Set(
        (Tuple(vec(operation.rotation_fractional)), operation.antiunitary) for
        operation in operations
    )
    identity = (Tuple(vec(Matrix{Int}(I, 3, 3))), false) in keys
    closure = all(
        (
            Tuple(vec(left.rotation_fractional * right.rotation_fractional)),
            xor(left.antiunitary, right.antiunitary),
        ) in keys for left in operations for right in operations
    )
    inverses = all(
        (Tuple(vec(round.(Int, inv(operation.rotation_fractional)))), operation.antiunitary) in
        keys for operation in operations
    )
    return Dict(
        "identity" => identity,
        "inverse" => inverses,
        "closure" => closure,
        "pass" => identity && inverses && closure,
        "algebra" => "exact_integer_fractional_rotation_and_antiunitary_parity",
    )
end

# Return a periodic fractional translation residual.
function _response_periodic_translation_residual(left, right)
    difference = Vector{Float64}(left .- right)
    return difference .- round.(difference)
end

# Validate the complete Seitz inventory, including fractional translations.
function _response_seitz_group_checks(
    operations::Vector{SymmetryOperation},
    translation_tolerance::Float64,
)
    identity_rotation = Matrix{Int}(I, 3, 3)
    identity_indices = findall(eachindex(operations)) do index
        operation = operations[index]
        !operation.antiunitary &&
            operation.rotation_fractional == identity_rotation &&
            maximum(
                abs,
                _response_periodic_translation_residual(operation.translation_fractional, zeros(3)),
            ) <= translation_tolerance
    end
    inverse_missing = Int[]
    closure_missing = Tuple{Int, Int}[]
    maximum_translation_residual = 0.0
    worst_translation_context = "none"

    function match_operation(rotation, translation, antiunitary)
        best_index = 0
        best_residual = Inf
        for (candidate_index, candidate) in enumerate(operations)
            candidate.antiunitary == antiunitary || continue
            candidate.rotation_fractional == rotation || continue
            residual = maximum(
                abs,
                _response_periodic_translation_residual(
                    translation,
                    candidate.translation_fractional,
                ),
            )
            if residual < best_residual ||
               (residual == best_residual && candidate_index < best_index)
                best_index = candidate_index
                best_residual = residual
            end
        end
        return best_index, best_residual
    end

    for (index, operation) in enumerate(operations)
        inverse_rotation = round.(Int, inv(operation.rotation_fractional))
        operation.rotation_fractional * inverse_rotation == identity_rotation ||
            throw(ArgumentError("fractional rotation $(index) has no exact integer inverse"))
        inverse_translation = -inverse_rotation * operation.translation_fractional
        match, residual =
            match_operation(inverse_rotation, inverse_translation, operation.antiunitary)
        if match == 0 || residual > translation_tolerance
            push!(inverse_missing, index)
        elseif residual > maximum_translation_residual
            maximum_translation_residual = residual
            worst_translation_context = "inverse($(index))=$(match)"
        end
    end

    for (left_index, left) in enumerate(operations), (right_index, right) in enumerate(operations)
        rotation = left.rotation_fractional * right.rotation_fractional
        translation =
            left.translation_fractional + left.rotation_fractional * right.translation_fractional
        antiunitary = xor(left.antiunitary, right.antiunitary)
        match, residual = match_operation(rotation, translation, antiunitary)
        if match == 0 || residual > translation_tolerance
            push!(closure_missing, (left_index, right_index))
        elseif residual > maximum_translation_residual
            maximum_translation_residual = residual
            worst_translation_context = "closure($(left_index),$(right_index))=$(match)"
        end
    end
    identity = length(identity_indices) == 1
    inverses = isempty(inverse_missing)
    closure = isempty(closure_missing)
    return Dict(
        "identity" => identity,
        "identity_indices" => identity_indices,
        "inverse" => inverses,
        "inverse_missing_operation_indices" => inverse_missing,
        "closure" => closure,
        "closure_missing_pairs" => [collect(pair) for pair in closure_missing],
        "translation_tolerance_fractional" => translation_tolerance,
        "maximum_matched_translation_residual_fractional" => maximum_translation_residual,
        "worst_matched_translation_context" => worst_translation_context,
        "pass" => identity && inverses && closure,
    )
end

# Compute the exact Cartesian minimum-image norm in a possibly skew lattice.
function _response_minimum_image_cartesian_residual(
    displacement_fractional,
    lattice_columns::Matrix{Float64},
)
    displacement = Vector{Float64}(displacement_fractional)
    smallest_stretch = minimum(svdvals(lattice_columns))
    smallest_stretch > 0.0 || throw(ArgumentError("lattice is singular"))

    nearest_componentwise = round.(Int, displacement)
    best = norm(lattice_columns * (displacement - nearest_componentwise))
    # For every lattice image n, ||L(d-n)|| >= sigma_min(L)||d-n||.
    # Therefore no image outside this finite cube can improve the incumbent.
    fractional_radius = best / smallest_stretch + sqrt(eps(Float64)) * max(norm(displacement), 1.0)
    image_ranges = ntuple(
        axis ->
            ceil(
                Int,
                displacement[axis] - fractional_radius,
            ):floor(Int, displacement[axis] + fractional_radius),
        3,
    )
    for image_x in image_ranges[1], image_y in image_ranges[2], image_z in image_ranges[3]
        image = (image_x, image_y, image_z)
        residual = norm(lattice_columns * (displacement - collect(image)))
        best = min(best, residual)
    end
    return best
end

# Build a deterministic species-compatible atom bijection for one operation.
function _response_atom_bijection(
    structure::CrystalStructure,
    operation::SymmetryOperation,
    fractional_tolerance::Float64,
    cartesian_tolerance_angstrom::Float64,
)
    atom_count = length(structure.species)
    lattice_columns = Matrix{Float64}(transpose(structure.lattice))
    candidates = Vector{Vector{NamedTuple}}(undef, atom_count)
    for source in 1:atom_count
        transformed =
            operation.rotation_fractional * structure.positions_fractional[:, source] .+
            operation.translation_fractional
        source_candidates = NamedTuple[]
        for target in 1:atom_count
            structure.species[target] == structure.species[source] || continue
            displacement = transformed .- structure.positions_fractional[:, target]
            wrapped_displacement = displacement .- round.(displacement)
            fractional_residual = maximum(abs, wrapped_displacement)
            cartesian_residual_angstrom =
                _response_minimum_image_cartesian_residual(displacement, lattice_columns)
            fractional_residual <= fractional_tolerance || continue
            cartesian_residual_angstrom <= cartesian_tolerance_angstrom || continue
            push!(source_candidates, (; target, fractional_residual, cartesian_residual_angstrom))
        end
        isempty(source_candidates) && throw(
            ArgumentError(
                "symmetry atom mapping has no species-compatible target for source $(source)",
            ),
        )
        sort!(
            source_candidates;
            by = candidate -> (
                candidate.cartesian_residual_angstrom,
                candidate.fractional_residual,
                candidate.target,
            ),
        )
        candidates[source] = source_candidates
    end

    target_to_source = zeros(Int, atom_count)
    source_to_target = zeros(Int, atom_count)
    function assign_source(source::Int, visited::BitVector)
        for candidate in candidates[source]
            target = candidate.target
            visited[target] && continue
            visited[target] = true
            previous = target_to_source[target]
            if previous == 0 || assign_source(previous, visited)
                target_to_source[target] = source
                source_to_target[source] = target
                return true
            end
        end
        return false
    end
    for source in 1:atom_count
        assign_source(source, falses(atom_count)) ||
            throw(ArgumentError("species-compatible atom mapping is not a bijection"))
    end
    sort(source_to_target) == collect(1:atom_count) ||
        throw(ArgumentError("atom mapping is not a permutation"))

    selected = NamedTuple[]
    for source in 1:atom_count
        target = source_to_target[source]
        candidate_index = findfirst(candidate -> candidate.target == target, candidates[source])
        candidate_index === nothing && error("internal atom-bijection residual lookup failed")
        push!(selected, candidates[source][something(candidate_index)])
    end
    return source_to_target, selected
end

# Verify positions and Cartesian axial magnetic moments on deterministic bijections.
function _response_atom_mapping_check(
    structure::CrystalStructure,
    operations::Vector{SymmetryOperation},
    fractional_tolerance::Float64,
    cartesian_tolerance_angstrom::Float64,
    magnetic_absolute_tolerance::Float64,
    magnetic_relative_tolerance::Float64,
)
    maximum_fractional_residual = 0.0
    maximum_cartesian_residual = 0.0
    maximum_magnetic_absolute_residual = 0.0
    maximum_magnetic_relative_residual = 0.0
    operation_checks = Dict{String, Any}[]
    moments = structure.magnetic_moments_cartesian
    for (operation_index, operation) in enumerate(operations)
        mapping, selected = _response_atom_bijection(
            structure,
            operation,
            fractional_tolerance,
            cartesian_tolerance_angstrom,
        )
        operation_fractional = maximum(candidate.fractional_residual for candidate in selected)
        operation_cartesian =
            maximum(candidate.cartesian_residual_angstrom for candidate in selected)
        maximum_fractional_residual = max(maximum_fractional_residual, operation_fractional)
        maximum_cartesian_residual = max(maximum_cartesian_residual, operation_cartesian)

        operation_magnetic_absolute = 0.0
        operation_magnetic_relative = 0.0
        operation_magnetic_pass = true
        if moments !== nothing
            axial_action =
                (operation.antiunitary ? -1.0 : 1.0) * det(operation.rotation_cartesian) .*
                operation.rotation_cartesian
            for source in eachindex(mapping)
                target = mapping[source]
                transformed_moment = axial_action * @view(moments[:, source])
                target_moment = @view moments[:, target]
                absolute_residual = norm(transformed_moment - target_moment)
                scale = max(norm(transformed_moment), norm(target_moment))
                relative_residual = scale == 0.0 ? 0.0 : absolute_residual / scale
                operation_magnetic_absolute = max(operation_magnetic_absolute, absolute_residual)
                operation_magnetic_relative = max(operation_magnetic_relative, relative_residual)
                operation_magnetic_pass &=
                    absolute_residual <=
                    magnetic_absolute_tolerance + magnetic_relative_tolerance * scale
            end
        end
        maximum_magnetic_absolute_residual =
            max(maximum_magnetic_absolute_residual, operation_magnetic_absolute)
        maximum_magnetic_relative_residual =
            max(maximum_magnetic_relative_residual, operation_magnetic_relative)
        position_pass =
            operation_fractional <= fractional_tolerance &&
            operation_cartesian <= cartesian_tolerance_angstrom
        push!(
            operation_checks,
            Dict(
                "operation_index" => operation_index,
                "source_to_target_one_based" => mapping,
                "bijection" => true,
                "maximum_fractional_residual" => operation_fractional,
                "maximum_cartesian_residual_angstrom" => operation_cartesian,
                "position_pass" => position_pass,
                "maximum_magnetic_absolute_residual" =>
                    moments === nothing ? nothing : operation_magnetic_absolute,
                "maximum_magnetic_relative_residual" =>
                    moments === nothing ? nothing : operation_magnetic_relative,
                "magnetic_moment_pass" =>
                    moments === nothing ? "NOT_APPLICABLE" : operation_magnetic_pass,
                "pass" => position_pass && operation_magnetic_pass,
            ),
        )
    end
    position_pass =
        maximum_fractional_residual <= fractional_tolerance &&
        maximum_cartesian_residual <= cartesian_tolerance_angstrom
    magnetic_pass =
        moments === nothing ||
        all(check["magnetic_moment_pass"] === true for check in operation_checks)
    pass = position_pass && magnetic_pass
    return Dict(
        "pass" => pass,
        "status" => pass ? "PASS" : "FAIL",
        "bijection" => true,
        "position_pass" => position_pass,
        "magnetic_moment_pass" => moments === nothing ? "NOT_APPLICABLE" : magnetic_pass,
        "maximum_fractional_residual" => maximum_fractional_residual,
        "fractional_tolerance" => fractional_tolerance,
        "maximum_cartesian_residual_angstrom" => maximum_cartesian_residual,
        "cartesian_tolerance_angstrom" => cartesian_tolerance_angstrom,
        "maximum_magnetic_absolute_residual" =>
            moments === nothing ? nothing : maximum_magnetic_absolute_residual,
        "maximum_magnetic_relative_residual" =>
            moments === nothing ? nothing : maximum_magnetic_relative_residual,
        "magnetic_absolute_tolerance" => magnetic_absolute_tolerance,
        "magnetic_relative_tolerance" => magnetic_relative_tolerance,
        "magnetic_transform" => "(-1)^antiunitary * det(R_effective) * R_effective * m",
        "operations" => operation_checks,
    )
end

# Summarize the group-invariant Cartesian rotation construction.
function _response_cartesian_rotation_check(
    rotation_data,
    policy::Symbol,
    correction_limit::Float64,
)
    effective_pass =
        rotation_data.maximum_correction <= correction_limit &&
        rotation_data.maximum_effective_orthogonality <= EFFECTIVE_CARTESIAN_ROTATION_TOLERANCE &&
        rotation_data.maximum_effective_closure <= EFFECTIVE_CARTESIAN_ROTATION_TOLERANCE
    production_pass = policy == :group_invariant_metric && effective_pass
    return Dict(
        "pass" => effective_pass,
        "production_pass" => production_pass,
        "status" =>
            production_pass ? "PASS" :
            policy == :group_invariant_metric ? "FAIL" : "DIAGNOSTIC_ONLY_RAW_CARTESIAN",
        "policy" => string(policy),
        "input_metric" => _response_artifact_matrix_rows(rotation_data.metric),
        "symmetrized_metric" => _response_artifact_matrix_rows(rotation_data.symmetrized_metric),
        "effective_lattice_rows_angstrom" =>
            _response_artifact_matrix_rows(rotation_data.effective_lattice_rows),
        "relative_metric_change" => rotation_data.relative_metric_change,
        "maximum_cartesian_matrix_correction" => rotation_data.maximum_correction,
        "maximum_cartesian_matrix_correction_limit" => correction_limit,
        "maximum_raw_orthogonality_residual" => rotation_data.maximum_raw_orthogonality,
        "maximum_effective_orthogonality_residual" => rotation_data.maximum_effective_orthogonality,
        "maximum_effective_cartesian_closure_residual" => rotation_data.maximum_effective_closure,
        "worst_effective_cartesian_closure_pair" =>
            collect(rotation_data.worst_effective_closure_pair),
        "effective_residual_tolerance" => EFFECTIVE_CARTESIAN_ROTATION_TOLERANCE,
    )
end

# Compare magnetic operation sets across an explicit Spglib tolerance scan.
function _response_tolerance_stability_check(
    structure::CrystalStructure,
    central::MagneticSymmetryInventory,
    tolerances::Vector{Float64};
    include_time_reversal::Bool,
    cartesian_rotation_policy::Symbol,
    maximum_cartesian_rotation_correction::Float64,
)
    central_keys = sort(canonical_band_operation_key.(central.operations))
    rows = Dict{String, Any}[]
    stable = true
    for tolerance in tolerances
        inventory = if tolerance == central.symmetry_tolerance
            central
        else
            detect_magnetic_symmetry_inventory(
                structure;
                include_time_reversal,
                spglib_symprec_angstrom = tolerance,
                cartesian_rotation_policy,
                maximum_cartesian_rotation_correction,
            )
        end
        keys = sort(canonical_band_operation_key.(inventory.operations))
        matches =
            inventory.msg_type == central.msg_type &&
            inventory.uni_number == central.uni_number &&
            keys == central_keys
        stable &= matches
        push!(
            rows,
            Dict(
                "spglib_symprec_angstrom" => tolerance,
                "num_operations" => length(inventory.operations),
                "unitary_operation_count" => inventory.unitary_operation_count,
                "antiunitary_operation_count" => inventory.antiunitary_operation_count,
                "msg_type" => inventory.msg_type,
                "uni_number" => inventory.uni_number,
                "hall_number" => inventory.hall_number,
                "operation_set_sha256" => bytes2hex(SHA.sha256(join(keys, "\n"))),
                "matches_central" => matches,
            ),
        )
    end
    return Dict(
        "pass" => stable,
        "status" => stable ? "PASS" : "FAIL",
        "central_spglib_symprec_angstrom" => central.symmetry_tolerance,
        "operation_identity" => "full_Seitz_rotation_translation_antiunitary",
        "samples" => rows,
    )
end

"""
Write a public schema-1.0 response-symmetry artifact with the complete qualification contract without modifying its inputs.

Spglib distances are expressed in Angstrom. POSCAR remains authoritative for
lattice, species, atom positions, and atom ordering. INCAR MAGMOM values are
recorded as initial moments, never as self-consistent local moments. The writer
performs structural, magnetic, group, tolerance-stability, and Cartesian-action
checks only; a manual integrand status is retained as an external claim and
cannot make the unsealed artifact production eligible.
"""
function write_response_symmetry_artifact(
    output_file::AbstractString;
    structure_file::AbstractString,
    model_file::AbstractString,
    structure_format::Symbol = :auto,
    magnetic_moments_cartesian = nothing,
    qe_magnetic_input_file::Union{Nothing, AbstractString} = nothing,
    vasp_magnetic_input_file::Union{Nothing, AbstractString} = nothing,
    collinear_axis_cartesian = nothing,
    include_time_reversal::Bool = true,
    spglib_symprec_angstrom::Union{Nothing, Real} = nothing,
    symmetry_tolerance::Union{Nothing, Real} = nothing,
    spglib_stability_scan_angstrom = nothing,
    fractional_mapping_tolerance::Real = RESPONSE_ATOM_FRACTIONAL_TOLERANCE,
    seitz_translation_tolerance::Real = RESPONSE_SEITZ_TRANSLATION_TOLERANCE,
    magnetic_moment_absolute_tolerance::Real = RESPONSE_MAGNETIC_MOMENT_ABSOLUTE_TOLERANCE,
    magnetic_moment_relative_tolerance::Real = RESPONSE_MAGNETIC_MOMENT_RELATIVE_TOLERANCE,
    cartesian_rotation_policy::Symbol = :group_invariant_metric,
    maximum_cartesian_rotation_correction::Real = DEFAULT_MAXIMUM_CARTESIAN_ROTATION_CORRECTION,
    integrand_covariance_status::AbstractString = "NOT_RUN",
    covariance_max_relative_residual::Union{Nothing, Real} = nothing,
    covariance_tolerance::Real = 1.0e-10,
    overwrite::Bool = false,
)
    output = abspath(output_file)
    ispath(output) &&
        !overwrite &&
        throw(ArgumentError("response symmetry artifact already exists: $(output)"))
    model = abspath(model_file)
    isfile(model) || throw(ArgumentError("model file does not exist: $(model)"))

    tolerance = resolve_spglib_symprec_angstrom(; spglib_symprec_angstrom, symmetry_tolerance)
    fractional_threshold = Float64(fractional_mapping_tolerance)
    seitz_threshold = Float64(seitz_translation_tolerance)
    moment_absolute_threshold = Float64(magnetic_moment_absolute_tolerance)
    moment_relative_threshold = Float64(magnetic_moment_relative_tolerance)
    correction_limit = Float64(maximum_cartesian_rotation_correction)
    covariance_threshold = Float64(covariance_tolerance)
    for (name, value) in (
        ("fractional_mapping_tolerance", fractional_threshold),
        ("seitz_translation_tolerance", seitz_threshold),
        ("magnetic_moment_absolute_tolerance", moment_absolute_threshold),
        ("magnetic_moment_relative_tolerance", moment_relative_threshold),
        ("maximum_cartesian_rotation_correction", correction_limit),
        ("covariance_tolerance", covariance_threshold),
    )
        isfinite(value) && value > 0.0 ||
            throw(ArgumentError("$(name) must be positive and finite"))
    end
    policy = resolve_cartesian_rotation_policy(cartesian_rotation_policy, nothing)

    external_covariance_status = uppercase(strip(String(integrand_covariance_status)))
    external_covariance_status in ("PASS", "FAIL", "NOT_RUN") ||
        throw(ArgumentError("integrand_covariance_status must be PASS, FAIL, or NOT_RUN"))
    external_covariance_residual =
        covariance_max_relative_residual === nothing ? nothing :
        Float64(covariance_max_relative_residual)
    external_covariance_residual === nothing ||
        (isfinite(external_covariance_residual) && external_covariance_residual >= 0.0) ||
        throw(ArgumentError("covariance_max_relative_residual must be finite and non-negative"))
    external_covariance_status == "PASS" &&
        external_covariance_residual === nothing &&
        throw(ArgumentError("external integrand covariance PASS requires a residual"))

    structure, resolved_format, atomic_type_labels, vasp_state = _response_artifact_structure(
        structure_file,
        structure_format,
        magnetic_moments_cartesian,
        qe_magnetic_input_file,
        vasp_magnetic_input_file,
        collinear_axis_cartesian,
    )
    inventory = detect_magnetic_symmetry_inventory(
        structure;
        include_time_reversal,
        spglib_symprec_angstrom = tolerance,
        cartesian_rotation_policy = policy,
        maximum_cartesian_rotation_correction = correction_limit,
    )
    point_operations, point_sources = _deduplicate_response_point_operations(inventory.operations)
    space_group_checks = _response_seitz_group_checks(inventory.operations, seitz_threshold)
    point_group_checks = _response_point_group_checks(point_operations)
    space_group_checks["pass"] ||
        throw(ArgumentError("detected Seitz operation set failed identity/inverse/closure"))
    point_group_checks["pass"] ||
        throw(ArgumentError("deduplicated magnetic point group failed identity/inverse/closure"))

    rotation_data = group_invariant_cartesian_rotation_data(
        [operation.rotation_fractional for operation in inventory.operations],
        structure.lattice,
    )
    cartesian_rotation = _response_cartesian_rotation_check(rotation_data, policy, correction_limit)
    atom_mapping = _response_atom_mapping_check(
        structure,
        inventory.operations,
        fractional_threshold,
        tolerance,
        moment_absolute_threshold,
        moment_relative_threshold,
    )

    scan_values = if spglib_stability_scan_angstrom === nothing
        Float64[0.5tolerance, tolerance, 2.0tolerance]
    else
        Float64.(collect(spglib_stability_scan_angstrom))
    end
    all(value -> isfinite(value) && value > 0.0, scan_values) ||
        throw(ArgumentError("spglib_stability_scan_angstrom must contain positive finite values"))
    tolerance in scan_values || push!(scan_values, tolerance)
    sort!(unique!(scan_values))
    tolerance_stability = _response_tolerance_stability_check(
        structure,
        inventory,
        scan_values;
        include_time_reversal,
        cartesian_rotation_policy = policy,
        maximum_cartesian_rotation_correction = correction_limit,
    )

    warning_messages = String[]
    if !atom_mapping["pass"]
        push!(
            warning_messages,
            "detected operations failed deterministic atom or axial-moment mapping",
        )
    end
    if !tolerance_stability["pass"]
        push!(warning_messages, "Spglib operation inventory is not stable across the declared scan")
    end
    if policy != :group_invariant_metric
        push!(
            warning_messages,
            "raw Cartesian rotations are diagnostic-only and cannot receive production eligibility",
        )
    end
    if external_covariance_status == "PASS" && external_covariance_residual > covariance_threshold
        push!(
            warning_messages,
            "external integrand covariance PASS residual exceeds its declared tolerance",
        )
    end
    structural_pass =
        space_group_checks["pass"] &&
        point_group_checks["pass"] &&
        atom_mapping["pass"] &&
        tolerance_stability["pass"] &&
        cartesian_rotation["production_pass"]
    downstream_status = structural_pass ? "NOT_RUN" : "NOT_RUN_DOWNSTREAM_BLOCKED"

    structure_source = abspath(structure_file)
    magnetic_source = if magnetic_moments_cartesian !== nothing && vasp_state !== nothing
        "explicit_cartesian_array_consistent_with_vasp_incar"
    elseif magnetic_moments_cartesian !== nothing
        "explicit_cartesian_array"
    elseif vasp_state !== nothing
        "vasp_incar_initial_magmoms"
    elseif qe_magnetic_input_file !== nothing
        "qe_input_starting_magnetization"
    else
        "none"
    end
    operation_payloads = [
        _response_operation_payload(operation, [index], rotation_data, policy) for
        (index, operation) in enumerate(inventory.operations)
    ]
    point_operation_payloads = [
        _response_operation_payload(operation, point_sources[index], rotation_data, policy) for
        (index, operation) in enumerate(point_operations)
    ]

    external_claim = Dict(
        "status" => external_covariance_status,
        "maximum_relative_residual" => external_covariance_residual,
        "tolerance" => covariance_threshold,
        "authority" => "external_unverified_claim",
        "grants_production_eligibility" => false,
    )
    formal_integrand = Dict(
        "status" => downstream_status,
        "maximum_relative_residual" => nothing,
        "tolerance" => covariance_threshold,
        "contract" => "streamed_all_operations_kpoints_frequencies_components_no_extra_conjugation",
        "reason" =>
            structural_pass ? "WRITER_DOES_NOT_EXECUTE_INTEGRAND_GATE" :
            "UPSTREAM_STRUCTURAL_GATE_FAILED",
        "external_claim" => external_claim,
    )
    payload = Dict{String, Any}(
        "schema" => RESPONSE_SYMMETRY_ARTIFACT_SCHEMA,
        "generated_at_utc" =>
            Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ"),
        "provenance" => Dict(
            "model" => Dict(
                "path" => basename(model),
                "sha256" => _response_artifact_sha256(model),
            ),
            "structure" => Dict(
                "path" => basename(structure_source),
                "format" => string(resolved_format),
                "sha256" => _response_artifact_sha256(structure_source),
            ),
            "qe_magnetic_input" =>
                qe_magnetic_input_file === nothing ? nothing :
                Dict(
                    "path" => basename(something(qe_magnetic_input_file)),
                    "sha256" => _response_artifact_sha256(
                        abspath(something(qe_magnetic_input_file)),
                    ),
                ),
            "vasp_magnetic_input" =>
                vasp_magnetic_input_file === nothing ? nothing :
                Dict(
                    "path" => basename(something(vasp_magnetic_input_file)),
                    "sha256" => _response_artifact_sha256(
                        abspath(something(vasp_magnetic_input_file)),
                    ),
                ),
            "magnetic_moment_source" => magnetic_source,
            "magnetic_moment_semantics" =>
                vasp_state === nothing ? nothing : vasp_state.interpretation,
            "vasp_incar_magnetism" =>
                vasp_state === nothing ? nothing :
                Dict(
                    "LNONCOLLINEAR" => vasp_state.lnoncollinear,
                    "LSORBIT" => vasp_state.lsorbit,
                    "SAXIS_input" => vasp_state.saxis_input,
                    "SAXIS_normalized" => vasp_state.saxis_normalized,
                    "collinear_axis_cartesian" => vasp_state.collinear_axis_cartesian,
                    "expanded_MAGMOM_values" => vasp_state.expanded_magmoms,
                    "expanded_magnetic_moments_cartesian_columns" =>
                        _response_artifact_matrix_rows(transpose(vasp_state.moments_cartesian)),
                    "interpretation" => vasp_state.interpretation,
                ),
            "spglib_version" => symmetry_detection_backend_provenance().version,
            "spglib_symprec_angstrom" => tolerance,
            "spglib_symprec_unit" => "angstrom",
            "symmetry_tolerance_legacy_alias_angstrom" => tolerance,
            "fractional_mapping_tolerance" => fractional_threshold,
            "include_time_reversal" => include_time_reversal,
            "cartesian_rotation_policy" => string(policy),
        ),
        "structure" => Dict(
            "lattice_rows_angstrom" => _response_artifact_matrix_rows(structure.lattice),
            "elements" => structure.species,
            "atomic_type_labels" => atomic_type_labels,
            "positions_fractional_columns" =>
                _response_artifact_matrix_rows(transpose(structure.positions_fractional)),
            "magnetic_moments_cartesian_columns" =>
                structure.magnetic_moments_cartesian === nothing ? nothing :
                _response_artifact_matrix_rows(transpose(structure.magnetic_moments_cartesian)),
        ),
        "symmetry" => Dict(
            "magnetic" => inventory.magnetic,
            "msg_type" => inventory.msg_type,
            "uni_number" => inventory.uni_number,
            "hall_number" => inventory.hall_number,
            "unitary_operation_count" => inventory.unitary_operation_count,
            "antiunitary_operation_count" => inventory.antiunitary_operation_count,
            "space_group_operations" => operation_payloads,
            "point_group_operations" => point_operation_payloads,
            "checks" => Dict(
                "identity" => point_group_checks["identity"],
                "inverse" => point_group_checks["inverse"],
                "closure" => point_group_checks["closure"],
                "space_group" => space_group_checks,
                "point_group" => point_group_checks,
                "atom_mapping" => atom_mapping,
                "cartesian_rotation" => cartesian_rotation,
                "tolerance_stability" => tolerance_stability,
            ),
        ),
        "qualification" => Dict(
            "status" => structural_pass ? "PHYSICS_HOLD" : "STRUCTURE_FAIL",
            "engineering_status" => structural_pass ? "STRUCTURE_PASS" : "STRUCTURE_FAIL",
            "production_eligible" => false,
            "warnings" => warning_messages,
            "gates" => Dict(
                "structure_magnetic_symmetry" =>
                    Dict("status" => structural_pass ? "PASS" : "FAIL"),
                "wannier90_gauge" => Dict("status" => downstream_status),
                "hamiltonian_covariance" => Dict("status" => "NOT_RUN_DOWNSTREAM_BLOCKED"),
                "mmn_covariance" => Dict("status" => "NOT_RUN_DOWNSTREAM_BLOCKED"),
                "integrand_covariance" => formal_integrand,
                "full_grid_consistency" => Dict("status" => "NOT_RUN_DOWNSTREAM_BLOCKED"),
            ),
            "integrand_covariance" => formal_integrand,
            "external_claims" => Dict("integrand_covariance" => external_claim),
            "seal" => Dict(
                "sealed" => false,
                "status" => "UNSEALED",
                "production_eligible" => false,
                "reason" => "PHYSICAL_QUALIFICATION_NOT_COMPLETE",
            ),
        ),
    )
    mkpath(dirname(output))
    temporary, io = mktemp(dirname(output); cleanup = false)
    try
        JSON3.pretty(io, payload)
        write(io, '\n')
        close(io)
        mv(temporary, output; force = overwrite)
    catch
        isopen(io) && close(io)
        isfile(temporary) && rm(temporary; force = true)
        rethrow()
    end
    return output
end
