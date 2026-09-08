"""Read one required artifact field or fail with contextual diagnostics."""
_report_required(mapping::AbstractDict, key::AbstractString, context::AbstractString) =
    haskey(mapping, key) ? mapping[key] : error("$(context).$(key) is required for group reporting")

"""Decode and validate one artifact matrix using the requested element type."""
function _report_matrix(value, ::Type{T}, context) where {T}
    value isa AbstractVector && length(value) == 3 || error("$(context) must have three rows")
    matrix = Matrix{T}(undef, 3, 3)
    for row in 1:3
        value[row] isa AbstractVector && length(value[row]) == 3 ||
            error("$(context) row $(row) must have three entries")
        matrix[row, :] .= T.(value[row])
    end
    return matrix
end

"""Decode and validate one length-three artifact vector."""
function _report_vector(value, ::Type{T}, context) where {T}
    value isa AbstractVector && length(value) == 3 || error("$(context) must have length three")
    return T.(value)
end

"""Decode one serialized symmetry operation for classification and closure checks."""
function _report_operation(operation::AbstractDict, index::Int)
    rotation = _report_matrix(
        _report_required(operation, "rotation_fractional", "operation[$(index)]"),
        Int,
        "operation[$(index)].rotation_fractional",
    )
    translation = _report_vector(
        get(operation, "translation_fractional", zeros(3)),
        Float64,
        "operation[$(index)].translation_fractional",
    )
    antiunitary = Bool(_report_required(operation, "antiunitary", "operation[$(index)]"))
    source_indices = get(operation, "source_space_group_indices", [index])
    source_index =
        source_indices isa AbstractVector && !isempty(source_indices) ? Int(first(source_indices)) :
        index
    return (
        rotation_fractional = rotation,
        translation_fractional = mod.(translation, 1.0),
        antiunitary,
        source_index,
    )
end

"""Convert one Spglib operation into the shared response-report representation."""
function _report_spglib_operation(rotation, translation, antiunitary, index)
    return (
        rotation_fractional = Matrix{Int}(rotation),
        translation_fractional = mod.(Vector{Float64}(translation), 1.0),
        antiunitary = Bool(antiunitary),
        source_index = Int(index),
    )
end

"""Remove translations and deduplicate a Seitz operation set into its point group."""
function _report_point_operations(operations)
    by_key = Dict{Tuple{Tuple, Bool}, Any}()
    for operation in operations
        key = (Tuple(vec(operation.rotation_fractional)), operation.antiunitary)
        haskey(by_key, key) ||
            (by_key[key] = merge(operation, (translation_fractional = zeros(3),)))
    end
    return collect(values(by_key))
end

"""Serialize the structural space-group labels returned by Spglib."""
function _report_space_group_dict(space_group_type)
    return Dict(
        "hermann_mauguin" => space_group_type.international_short,
        "international_number" => Int(space_group_type.number),
        "hall_symbol" => space_group_type.hall_symbol,
        "hall_number" => Int(space_group_type.hall_number),
        "setting" => isempty(space_group_type.choice) ? "standard" : space_group_type.choice,
        "point_group_hermann_mauguin" => space_group_type.pointgroup_international,
    )
end

"""Create an unresolved diagnostic object and record its warning."""
function _report_unresolved(reason, warnings)
    push!(warnings, reason)
    return Dict("status" => "UNRESOLVED", "reason" => reason)
end

"""Return a fractional-translation residual modulo the Bravais lattice."""
function _report_periodic_translation_residual(left, right)
    delta = left .- right
    delta .-= round.(delta)
    return maximum(abs, delta)
end

"""Compare two Seitz operation multisets including translations modulo the lattice."""
function _report_operation_sets_match(left, right, tolerance)
    length(left) == length(right) || return false
    used = falses(length(right))
    for operation in left
        match = findfirst(eachindex(right)) do index
            candidate = right[index]
            !used[index] &&
                candidate.antiunitary == operation.antiunitary &&
                candidate.rotation_fractional == operation.rotation_fractional &&
                _report_periodic_translation_residual(
                    candidate.translation_fractional,
                    operation.translation_fractional,
                ) <= tolerance
        end
        match === nothing && return false
        used[match] = true
    end
    return all(used)
end

"""Compare point-operation sets exactly by rotation and antiunitary parity only."""
function _report_point_operation_sets_match(left, right)
    length(left) == length(right) || return false
    left_keys = Set(
        (Tuple(vec(operation.rotation_fractional)), operation.antiunitary) for operation in left
    )
    right_keys = Set(
        (Tuple(vec(operation.rotation_fractional)), operation.antiunitary) for operation in right
    )
    return length(left_keys) == length(left) &&
           length(right_keys) == length(right) &&
           left_keys == right_keys
end

"""Return Spglib's ordinary point-group symbol and exact standardizing transform."""
function _report_spglib_point_group_basis(operations)
    rotations = [operation.rotation_fractional for operation in operations]
    keys = sort(unique(Tuple(vec(Matrix{Int}(rotation))) for rotation in rotations))
    isempty(keys) && error("cannot classify an empty point-operation set")
    raw = Array{Cint}(undef, 3, 3, length(keys))
    for (index, key) in enumerate(keys)
        raw[:, :, index] .= transpose(reshape(collect(key), 3, 3))
    end
    symbol = fill(Cchar(0), 6)
    raw_transform = zeros(Cint, 3, 3)
    operation_count = Cint(length(keys))
    number = @ccall Spglib.libsymspg.spg_get_pointgroup(
        symbol::Ptr{Cchar},
        raw_transform::Ptr{Cint},
        raw::Ptr{Cint},
        operation_count::Cint,
    )::Cint
    number == 0 && error("spg_get_pointgroup failed for the response operation set")
    hermann_mauguin = String(UInt8[byte for byte in symbol if byte != 0x00])
    standard_transform = Matrix{Int}(transpose(raw_transform))
    return Int(number), hermann_mauguin, standard_transform
end

"""Canonicalize an actual colored point-operation set through the qualified core contract."""
function _report_magnetic_point_group_identity(operations)
    point_operations = _report_point_operations(operations)
    ordinary_point_group_number, hermann_mauguin, standard_transform =
        _report_spglib_point_group_basis(point_operations)
    return WannierNLQG.SymmetryFoundation.magnetic_point_group_operation_identity(
        [operation.rotation_fractional for operation in point_operations],
        [operation.antiunitary for operation in point_operations],
        ordinary_point_group_number,
        hermann_mauguin,
        standard_transform,
    )
end

"""Serialize the stable magnetic-point-group identity fields for response summaries."""
function _report_magnetic_point_group_identity_dict(identity)
    basis_transform =
        Dict(string(key) => value for (key, value) in pairs(identity.basis_transform_to_input))
    return Dict(
        "magnetic_point_group_number" => identity.magnetic_point_group_number,
        "operation_digest" => identity.operation_digest,
        "operation_digest_contract" => identity.operation_digest_contract,
        "hermann_mauguin" => identity.hermann_mauguin,
        "symbol_convention" => identity.symbol_convention,
        "equivalent_axis_notation" => identity.equivalent_axis_notation,
        "basis_transform_to_input" => basis_transform,
    )
end

"""Require a reconstructed operation identity to agree with its generated UNI record."""
function _report_validate_catalog_identity(identity, entry, uni_number)
    for field in (:magnetic_point_group_number, :operation_digest, :operation_digest_contract)
        getproperty(identity, field) == getproperty(entry, field) ||
            error("reconstructed magnetic point-group $(field) disagrees with UNI $(uni_number)")
    end
    return nothing
end

"""Build verified group classification and deterministic generators from an artifact payload."""
function response_symmetry_group_report(payload::AbstractDict; strict::Bool = true)
    warnings = String[]
    provenance = get(payload, "provenance", nothing)
    structure_payload = get(payload, "structure", nothing)
    symmetry = get(payload, "symmetry", nothing)
    if !(
        provenance isa AbstractDict &&
        structure_payload isa AbstractDict &&
        symmetry isa AbstractDict
    )
        strict && error("complete response symmetry artifact lacks group-reporting records")
        return Dict(
            "status" => "UNRESOLVED",
            "warnings" => ["legacy artifact lacks complete group-reporting records"],
            "group_classification" => Dict("status" => "UNRESOLVED"),
            "active_constraint_group" => Dict("status" => "UNRESOLVED"),
            "generators" => Dict("status" => "UNRESOLVED"),
            "classification_source" => Dict("status" => "NOT_RECORDED"),
        )
    end
    required_keys = (
        "lattice_rows_angstrom",
        "elements",
        "positions_fractional_columns",
        "magnetic_moments_cartesian_columns",
    )
    missing = [key for key in required_keys if !haskey(structure_payload, key)]
    if !isempty(missing)
        strict && error(
            "complete response symmetry artifact lacks structure fields: $(join(missing, ", "))",
        )
        return Dict(
            "status" => "UNRESOLVED",
            "warnings" => ["group classification missing structure fields: $(join(missing, ", "))"],
            "group_classification" => Dict("status" => "UNRESOLVED"),
            "active_constraint_group" => Dict("status" => "UNRESOLVED"),
            "generators" => Dict("status" => "UNRESOLVED"),
            "classification_source" => Dict("status" => "NOT_RECORDED"),
        )
    end
    lattice = _report_matrix(
        structure_payload["lattice_rows_angstrom"],
        Float64,
        "structure.lattice_rows_angstrom",
    )
    positions_rows = structure_payload["positions_fractional_columns"]
    positions_rows isa AbstractVector || error("structure positions must be an array")
    positions = [Float64.(position) for position in positions_rows]
    elements = String.(structure_payload["elements"])
    atom_types = _species_type_numbers(elements)
    spglib_symprec = Float64(get(provenance, "spglib_symprec_angstrom", 1.0e-5))
    checks = get(symmetry, "checks", Dict())
    space_group_checks = get(checks, "space_group", Dict())
    seitz_tolerance = if haskey(space_group_checks, "translation_tolerance_fractional")
        Float64(space_group_checks["translation_tolerance_fractional"])
    elseif strict
        error("complete response symmetry artifact lacks fractional Seitz tolerance")
    else
        push!(warnings, "fractional Seitz tolerance is NOT_RECORDED; using diagnostic fallback 1.0e-8")
        1.0e-8
    end
    isfinite(spglib_symprec) && spglib_symprec > 0 ||
        error("Spglib symprec must be positive and finite")
    isfinite(seitz_tolerance) && seitz_tolerance > 0 ||
        error("fractional Seitz tolerance must be positive and finite")
    cell = Spglib.Cell(transpose(lattice), positions, atom_types)
    structural_dataset = Spglib.get_dataset(cell, spglib_symprec)
    structural_dataset === nothing && error("Spglib could not classify the stored structure")
    structural_type = Spglib.get_spacegroup_type(structural_dataset.hall_number)
    structural_operations = [
        _report_spglib_operation(rotation, translation, false, index) for
        (index, (rotation, translation)) in
        enumerate(zip(structural_dataset.rotations, structural_dataset.translations))
    ]
    structural_space_generators =
        response_group_generators(structural_operations; seitz = true, tolerance = seitz_tolerance)
    structural_point_generators = response_group_generators(
        _report_point_operations(structural_operations);
        seitz = false,
        tolerance = seitz_tolerance,
    )

    point_payload = get(symmetry, "point_group_operations", nothing)
    space_payload = get(symmetry, "space_group_operations", nothing)
    point_payload isa AbstractVector && !isempty(point_payload) ||
        error("symmetry.point_group_operations is required for group reporting")
    space_payload isa AbstractVector && !isempty(space_payload) ||
        error("symmetry.space_group_operations is required for group reporting")
    active_point_operations =
        [_report_operation(operation, index) for (index, operation) in enumerate(point_payload)]
    active_space_operations =
        [_report_operation(operation, index) for (index, operation) in enumerate(space_payload)]
    active_point_generators = response_group_generators(
        active_point_operations;
        seitz = false,
        tolerance = seitz_tolerance,
    )
    active_space_generators = response_group_generators(
        active_space_operations;
        seitz = true,
        tolerance = seitz_tolerance,
    )
    include_time_reversal = Bool(get(provenance, "include_time_reversal", false))
    magnetic = Bool(get(symmetry, "magnetic", false))
    msg_type = get(symmetry, "msg_type", nothing)
    uni_number = get(symmetry, "uni_number", nothing)
    recorded_hall = get(symmetry, "hall_number", nothing)

    full_magnetic_operations = Any[]
    magnetic_space_group = Dict{String, Any}()
    full_magnetic_point_identity = nothing
    if magnetic
        moments_rows = structure_payload["magnetic_moments_cartesian_columns"]
        moments_rows isa AbstractVector || error("magnetic artifact lacks stored magnetic moments")
        moments = [Float64.(moment) for moment in moments_rows]
        magnetic_cell = Spglib.Cell(transpose(lattice), positions, atom_types, moments)
        magnetic_dataset = Spglib.get_magnetic_dataset(magnetic_cell, spglib_symprec)
        magnetic_dataset === nothing &&
            error("Spglib could not reclassify the stored magnetic structure")
        Int(magnetic_dataset.uni_number) == Int(uni_number) ||
            error("stored UNI number disagrees with the reconstructed magnetic structure")
        Int(magnetic_dataset.msg_type) == Int(msg_type) ||
            error("stored MSG type disagrees with the reconstructed magnetic structure")
        Int(magnetic_dataset.hall_number) == Int(recorded_hall) ||
            error("stored Hall number disagrees with the reconstructed magnetic structure")
        msg = Spglib.get_magnetic_spacegroup_type(Int(uni_number))
        Int(msg.type) == Int(msg_type) || error("UNI catalog MSG type mismatch")
        point_entry = magnetic_point_group_catalog_entry(Int(uni_number))
        full_magnetic_operations = [
            _report_spglib_operation(rotation, translation, antiunitary, index) for
            (index, (rotation, translation, antiunitary)) in enumerate(
                zip(
                    magnetic_dataset.rotations,
                    magnetic_dataset.translations,
                    magnetic_dataset.time_reversals,
                ),
            )
        ]
        full_magnetic_point_identity =
            _report_magnetic_point_group_identity(full_magnetic_operations)
        _report_validate_catalog_identity(full_magnetic_point_identity, point_entry, uni_number)
        magnetic_space_group = Dict(
            "status" => "RESOLVED",
            "type" => "Type $(Int(msg.type))",
            "uni_number" => Int(msg.uni_number),
            "litvin_number" => Int(msg.litvin_number),
            "bns_number" => msg.bns_number,
            "og_number" => msg.og_number,
            "parent_space_group_number" => Int(msg.number),
            "magnetic_point_group_hermann_mauguin" =>
                full_magnetic_point_identity.hermann_mauguin,
            "magnetic_point_group_symbol_convention" =>
                full_magnetic_point_identity.symbol_convention,
            "magnetic_point_group_number" =>
                full_magnetic_point_identity.magnetic_point_group_number,
            "magnetic_point_group_operation_digest" =>
                full_magnetic_point_identity.operation_digest,
        )
    else
        Int(msg_type) == (include_time_reversal ? 2 : 1) ||
            error("stored nonmagnetic MSG type disagrees with include_time_reversal")
        Int(recorded_hall) == Int(structural_dataset.hall_number) ||
            error("stored Hall number disagrees with the reconstructed structure")
        zero_moments = [zeros(3) for _ in positions]
        gray_cell = Spglib.Cell(transpose(lattice), positions, atom_types, zero_moments)
        gray_dataset = Spglib.get_magnetic_dataset(gray_cell, spglib_symprec)
        gray_dataset === nothing && error("Spglib could not classify the nonmagnetic gray group")
        Int(gray_dataset.msg_type) == 2 ||
            error("zero-moment structure did not reconstruct a Type II magnetic space group")
        Int(gray_dataset.hall_number) == Int(recorded_hall) ||
            error("gray-group Hall number disagrees with the stored structural Hall number")
        msg = Spglib.get_magnetic_spacegroup_type(Int(gray_dataset.uni_number))
        point_entry = magnetic_point_group_catalog_entry(Int(gray_dataset.uni_number))
        full_magnetic_operations = [
            _report_spglib_operation(rotation, translation, antiunitary, index) for
            (index, (rotation, translation, antiunitary)) in enumerate(
                zip(gray_dataset.rotations, gray_dataset.translations, gray_dataset.time_reversals),
            )
        ]
        full_magnetic_point_identity =
            _report_magnetic_point_group_identity(full_magnetic_operations)
        _report_validate_catalog_identity(
            full_magnetic_point_identity,
            point_entry,
            gray_dataset.uni_number,
        )
        magnetic_space_group = Dict(
            "status" => "RESOLVED",
            "type" => "Type II (nonmagnetic gray group)",
            "uni_number" => Int(msg.uni_number),
            "litvin_number" => Int(msg.litvin_number),
            "bns_number" => msg.bns_number,
            "og_number" => msg.og_number,
            "parent_space_group_number" => Int(msg.number),
            "magnetic_point_group_hermann_mauguin" =>
                full_magnetic_point_identity.hermann_mauguin,
            "magnetic_point_group_symbol_convention" =>
                full_magnetic_point_identity.symbol_convention,
            "magnetic_point_group_number" =>
                full_magnetic_point_identity.magnetic_point_group_number,
            "magnetic_point_group_operation_digest" =>
                full_magnetic_point_identity.operation_digest,
        )
    end
    !include_time_reversal &&
        any(operation -> operation.antiunitary, active_space_operations) &&
        error("active operation set contains antiunitary operations with time reversal disabled")
    expected_active_operations =
        include_time_reversal ? full_magnetic_operations :
        filter(operation -> !operation.antiunitary, full_magnetic_operations)
    _report_operation_sets_match(
        active_space_operations,
        expected_active_operations,
        seitz_tolerance,
    ) || error("stored active Seitz operation set disagrees with reconstructed classification")
    expected_active_point_operations = _report_point_operations(expected_active_operations)
    _report_point_operation_sets_match(active_point_operations, expected_active_point_operations) ||
        error(
            "stored active point-operation set is not the deduplicated reconstructed Seitz point group",
        )
    full_magnetic_space_generators = response_group_generators(
        full_magnetic_operations;
        seitz = true,
        tolerance = seitz_tolerance,
    )
    full_magnetic_point_generators = response_group_generators(
        _report_point_operations(full_magnetic_operations);
        seitz = false,
        tolerance = seitz_tolerance,
    )
    active_identity = _report_magnetic_point_group_identity(active_point_operations)
    expected_unitary = Int(get(symmetry, "unitary_operation_count", -1))
    expected_antiunitary = Int(get(symmetry, "antiunitary_operation_count", -1))
    expected_unitary == active_space_generators["unitary_operation_count"] ||
        error("stored unitary operation count disagrees with active operation set")
    expected_antiunitary == active_space_generators["antiunitary_operation_count"] ||
        error("stored antiunitary operation count disagrees with active operation set")
    stability = get(checks, "tolerance_stability", Dict())
    stability_status =
        get(stability, "status", get(stability, "pass", false) === true ? "PASS" : "UNRESOLVED")
    catalog_provenance = magnetic_point_group_catalog_provenance()
    return Dict(
        "status" => isempty(warnings) ? "RESOLVED" : "RESOLVED_WITH_WARNINGS",
        "warnings" => warnings,
        "group_classification" => Dict(
            "structural_space_group" => _report_space_group_dict(structural_type),
            "structural_point_group" =>
                Dict("hermann_mauguin" => structural_type.pointgroup_international),
            "magnetic_space_group" => magnetic_space_group,
            "full_magnetic_point_group" => merge(
                _report_magnetic_point_group_identity_dict(full_magnetic_point_identity),
                Dict("group_order" => full_magnetic_point_generators["group_order"]),
            ),
        ),
        "active_constraint_group" => merge(
            _report_magnetic_point_group_identity_dict(active_identity),
            Dict(
                "include_time_reversal" => include_time_reversal,
                "uses_unitary_subgroup_only" => !include_time_reversal,
                "group_order" => active_point_generators["group_order"],
                "unitary_operation_count" => active_point_generators["unitary_operation_count"],
                "antiunitary_operation_count" =>
                    active_point_generators["antiunitary_operation_count"],
                "spglib_version" => string(get(provenance, "spglib_version", "NOT_RECORDED")),
                "classifier_spglib_version" => string(Base.pkgversion(Spglib)),
                "symprec_angstrom" => spglib_symprec,
                "seitz_translation_tolerance_fractional" => seitz_tolerance,
                "tolerance_stability" => string(stability_status),
            ),
        ),
        "generators" => Dict(
            "structural_space_group" => structural_space_generators,
            "structural_point_group" => structural_point_generators,
            "magnetic_space_group" => full_magnetic_space_generators,
            "magnetic_point_group" => full_magnetic_point_generators,
            "active_space_group" => active_space_generators,
            "active_point_group" => active_point_generators,
        ),
        "classification_source" => Dict(
            "artifact_spglib" => string(get(provenance, "spglib_version", "NOT_RECORDED")),
            "classifier_spglib" => string(Base.pkgversion(Spglib)),
            "magnetic_point_group_catalog" =>
                Dict(string(key) => value for (key, value) in pairs(catalog_provenance)),
            "qualification_effect" => "interpretive_only_no_qualification_upgrade",
        ),
    )
end
