const BAND_REPRESENTATION_SCHEMA = "WannierNLQG.band_representation"
const BAND_REPRESENTATION_SCHEMA_VERSION = "1.0"

"""Return the current BandRepresentation writer schema version."""
band_representation_schema_version() = BAND_REPRESENTATION_SCHEMA_VERSION
const BAND_REPRESENTATION_READABLE_SCHEMA_VERSIONS = ("1.0",)

const _BAND_LEGACY_AUTHORITY_KEYS =
    ("symmetrized_hamiltonian_candidate", "symmetrized_target_subspace_candidate")
const _BAND_SUPPORTED_AUTHORITY_KEYS = ("native_dft", "symmetrized_dft_hamiltonian")

# Reject retired authority identities at every representation persistence boundary.
function _band_validate_authority_key(authority::AbstractString)
    value = String(authority)
    value in _BAND_LEGACY_AUTHORITY_KEYS && throw(
        ArgumentError(
            "UNSUPPORTED_LEGACY_AUTHORITY: authoritative Hamiltonian $(value) is retired",
        ),
    )
    value in _BAND_SUPPORTED_AUTHORITY_KEYS ||
        throw(ArgumentError("unsupported authoritative Hamiltonian key $(value)"))
    return value
end

# Validate the current outer-window authority contract stored in conventions.
function _band_validate_target_subspace_contract(conventions::Dict{String, String})
    authority =
        _band_validate_authority_key(get(conventions, "authoritative_hamiltonian", "native_dft"))
    get(conventions, "qualification_scope", "") == "target_subspace" || throw(
        ArgumentError(
            "TARGET_SUBSPACE_CONTRACT_MISMATCH: qualification_scope must be target_subspace",
        ),
    )
    get(conventions, "target_authority", "") == "outer_window" || throw(
        ArgumentError("TARGET_SUBSPACE_CONTRACT_MISMATCH: target_authority must be outer_window"),
    )
    get(conventions, "parent_audit_policy", "") == "audit_only" || throw(
        ArgumentError("TARGET_SUBSPACE_CONTRACT_MISMATCH: parent_audit_policy must be audit_only"),
    )
    contract_sha256 = get(conventions, "target_subspace_contract_sha256", "")
    occursin(r"^[0-9a-f]{64}$", contract_sha256) || throw(
        ArgumentError(
            "TARGET_SUBSPACE_CONTRACT_MISMATCH: target_subspace_contract_sha256 is invalid",
        ),
    )
    get(conventions, "target_leakage_semantics", "") == "physical_paw_s_leakage_weight_v1" || throw(
        ArgumentError(
            "UNSUPPORTED_LEGACY_TARGET_LEAKAGE_SEMANTICS: target representation lacks PAW-S weight semantics",
        ),
    )
    formula_sha256 = get(conventions, "target_leakage_formula_sha256", "")
    formula_sha256 == "bac0eb8b0df105c221d0e5a253be1890ac7933e51c776bf9aa760fb91362a3b7" || throw(
        ArgumentError(
            "TARGET_SUBSPACE_CONTRACT_MISMATCH: target leakage formula SHA-256 is unsupported",
        ),
    )
    threshold = tryparse(Float64, get(conventions, "target_leakage_threshold", ""))
    threshold !== nothing && isfinite(something(threshold)) && something(threshold) > 0.0 || throw(
        ArgumentError(
            "TARGET_SUBSPACE_CONTRACT_MISMATCH: target leakage weight threshold is invalid",
        ),
    )
    authority == "symmetrized_dft_hamiltonian" &&
        get(conventions, "auxiliary_parent_qualification", "") != "audit_only" &&
        throw(
            ArgumentError(
                "TARGET_SUBSPACE_CONTRACT_MISMATCH: symmetrized authority requires audit-only auxiliary parent",
            ),
        )
    return authority
end

"""Closed operation-product data used by the band group-law gate."""
struct BandRepresentationProductTable
    identity_index::Int
    theta_index::Union{Nothing, Int}
    canonical_keys::Vector{String}
    spin_actions::Array{ComplexF64, 3}
    product_indices::Matrix{Int}
    translation_differences::Array{Int, 3}
    spinor_factors::Matrix{Int}
end

"""Machine-readable validation evidence stored with a band representation."""
struct BandRepresentationValidation
    passed::Bool
    absolute_tolerance::Float64
    oracle_excess_tolerance::Float64
    maximum_group_law_residuals::NTuple{4, Float64}
    maximum_reciprocal_shift_residual::Float64
    maximum_unitarity_residual::Float64
    maximum_theta_residual::Float64
    oracle_excess_group_law_residuals::Union{Nothing, NTuple{4, Float64}}
    oracle_sha256::Union{Nothing, String}
    representation_sha256::String
    diagnostics::Vector{String}
end

# Reduce one fractional translation difference to its nearest periodic image.
function _band_periodic_translation_residual(left::AbstractVector, right::AbstractVector)
    difference = Vector{Float64}(left .- right)
    return difference .- round.(difference)
end

# Build the antiunitary-aware operation product and projective spin tables.
function build_band_product_table(
    operations::Vector{SymmetryOperation},
    spinor::Bool;
    tolerance::Real = 1.0e-10,
)
    tolerance_value = Float64(tolerance)
    num_operations = length(operations)
    num_operations > 0 || throw(ArgumentError("operation list must not be empty"))
    keys = canonical_band_operation_key.(operations)
    length(unique(keys)) == num_operations ||
        throw(ArgumentError("operation inventory contains duplicate canonical identities"))
    spin_dimension = spinor ? 2 : 1
    spin_actions = Array{ComplexF64, 3}(undef, spin_dimension, spin_dimension, num_operations)
    for operation_index in eachindex(operations)
        spin_actions[:, :, operation_index] .=
            spin_action_matrix(operations[operation_index], spinor)
    end
    identity_candidates = findall(eachindex(operations)) do operation_index
        operation = operations[operation_index]
        !operation.antiunitary &&
            operation.rotation_fractional == Matrix{Int}(I, 3, 3) &&
            maximum(
                abs,
                _band_periodic_translation_residual(operation.translation_fractional, zeros(3)),
            ) <= tolerance_value
    end
    length(identity_candidates) == 1 ||
        throw(ArgumentError("operation inventory must contain one unitary identity"))
    theta_candidates = findall(eachindex(operations)) do operation_index
        operation = operations[operation_index]
        operation.antiunitary &&
            operation.rotation_fractional == Matrix{Int}(I, 3, 3) &&
            maximum(
                abs,
                _band_periodic_translation_residual(operation.translation_fractional, zeros(3)),
            ) <= tolerance_value
    end
    length(theta_candidates) <= 1 ||
        throw(ArgumentError("operation inventory contains multiple pure time reversals"))
    product_indices = Matrix{Int}(undef, num_operations, num_operations)
    translations = Array{Int, 3}(undef, 3, num_operations, num_operations)
    factors = Matrix{Int}(undef, num_operations, num_operations)
    for left_index in eachindex(operations), right_index in eachindex(operations)
        left = operations[left_index]
        right = operations[right_index]
        product_rotation = left.rotation_fractional * right.rotation_fractional
        product_translation =
            left.translation_fractional + left.rotation_fractional * right.translation_fractional
        product_antiunitary = xor(left.antiunitary, right.antiunitary)
        matches = Int[]
        for candidate_index in eachindex(operations)
            candidate = operations[candidate_index]
            candidate.antiunitary == product_antiunitary || continue
            candidate.rotation_fractional == product_rotation || continue
            maximum(
                abs,
                _band_periodic_translation_residual(
                    product_translation,
                    candidate.translation_fractional,
                ),
            ) <= tolerance_value || continue
            push!(matches, candidate_index)
        end
        length(matches) == 1 ||
            throw(ArgumentError("operation product $(left_index) o $(right_index) is not unique"))
        product_index = only(matches)
        product_indices[left_index, right_index] = product_index
        difference = product_translation - operations[product_index].translation_fractional
        integer_difference = round.(Int, difference)
        maximum(abs, difference - integer_difference) <= tolerance_value ||
            throw(ArgumentError("operation product has a noninteger translation cocycle"))
        translations[:, left_index, right_index] .= integer_difference
        left_spin = @view spin_actions[:, :, left_index]
        right_spin = @view spin_actions[:, :, right_index]
        product_spin = left_spin * (left.antiunitary ? conj(right_spin) : right_spin)
        canonical_spin = @view spin_actions[:, :, product_index]
        overlap = tr(canonical_spin' * product_spin) / spin_dimension
        factor = real(overlap) >= 0.0 ? 1 : -1
        maximum(abs, product_spin - factor .* canonical_spin) <= 10tolerance_value ||
            throw(ArgumentError("spin action does not close up to a double-group sign"))
        factors[left_index, right_index] = factor
    end
    return BandRepresentationProductTable(
        only(identity_candidates),
        isempty(theta_candidates) ? nothing : only(theta_candidates),
        keys,
        spin_actions,
        product_indices,
        translations,
        factors,
    )
end

# Require the only public wire identity and the complete current layout. This
# is shared by all three read entry points; historical 1.0 gets no special path.
function _require_public_band_header(handle)
    String(_required_band_attribute(handle, "schema")) == BAND_REPRESENTATION_SCHEMA ||
        throw(ArgumentError("HDF5 file is not a WannierNLQG band representation"))
    version = String(_required_band_attribute(handle, "schema_version"))
    version == BAND_REPRESENTATION_SCHEMA_VERSION || throw(
        ArgumentError(
            "unsupported band-representation schema $(version); only public 1.0 is supported",
        ),
    )
    for key in ("source_code", "spinor", "preparation_digest")
        _required_band_attribute(handle, key)
    end
    for group in (
        "geometry",
        "bands",
        "operations",
        "action",
        "stars",
        "conventions",
        "input_sha256",
        "products",
        "compatibility",
        "inventory",
        "qualification_scope",
        "raw_diagnostics",
        "compatibility_policy",
        "sewing_backend",
        "wavefunction_gauge",
    )
        haskey(handle, group) ||
            throw(ArgumentError("public band representation is missing $(group)"))
    end
    return version
end

# Validate a completed in-memory representation without changing arrays, status,
# conventions, or its scientific identity. Intermediate versions are not writable.
function _band_validate_public_representation_contract(representation::BandRepresentation)
    representation.schema_version == BAND_REPRESENTATION_SCHEMA_VERSION || throw(
        ArgumentError(
            "public band-representation writer requires a completed schema-1.0 representation",
        ),
    )
    _validate_unified_representation_mode_contract(representation)
    authority = _band_validate_authority_key(
        get(representation.conventions, "authoritative_hamiltonian", "native_dft"),
    )
    scope = get(representation.conventions, "qualification_scope", "full_parent")
    if scope == "target_subspace"
        _band_validate_target_subspace_contract(representation.conventions)
    elseif authority == "symmetrized_dft_hamiltonian"
        throw(
            ArgumentError(
                "TARGET_SUBSPACE_CONTRACT_REQUIRED: SymmetrizedDFTHamiltonian representation lacks target scope",
            ),
        )
    end
    return nothing
end

# Serialize only scientific representation content into a deterministic digest.
function _band_representation_sha256(representation::BandRepresentation)
    io = IOBuffer()
    write(io, codeunits(String(representation.source_code)))
    write(io, UInt8(representation.spinor))
    for value in representation.mp_grid
        write(io, Int64(value))
    end
    for array in (
        representation.real_lattice,
        representation.reciprocal_lattice,
        representation.kpoints_fractional,
        representation.energies_ev,
        representation.kpoint_map,
        representation.reciprocal_shifts,
        representation.sewing_matrices,
        representation.band_block_labels,
        representation.irreducible_indices,
        representation.full_to_irreducible,
        representation.full_to_operation,
    )
        for dimension in size(array)
            write(io, Int64(dimension))
        end
        write(io, vec(array))
    end
    for operation in representation.operations
        write(io, vec(operation.rotation_fractional))
        write(io, operation.translation_fractional)
        write(io, vec(operation.rotation_cartesian))
        write(io, UInt8(operation.antiunitary))
    end
    for key in sort!(collect(keys(representation.conventions)))
        write(io, codeunits(key))
        write(io, UInt8(0))
        write(io, codeunits(representation.conventions[key]))
        write(io, UInt8(0))
    end
    return bytes2hex(sha256(take!(io)))
end

# Convert contiguous integer block labels into deterministic band ranges.
function _band_label_ranges(labels::AbstractVector{<:Integer})
    isempty(labels) && return UnitRange{Int}[]
    starts = Int[1]
    stops = Int[]
    for index in 2:length(labels)
        labels[index] == labels[index - 1] && continue
        push!(stops, index - 1)
        push!(starts, index)
    end
    push!(stops, length(labels))
    return UnitRange{Int}[first:last for (first, last) in zip(starts, stops)]
end

# Attach an explicit validation window without silently changing an existing one.
function configure_band_qualification_window!(
    representation::BandRepresentation,
    window::Union{Nothing, NTuple{2, Float64}},
)
    window === nothing && return representation
    lower, upper = something(window)
    isfinite(lower) && isfinite(upper) && lower < upper ||
        throw(ArgumentError("qualification_window_ev must be finite and increasing"))
    lower_key = "qualification_window_min_ev"
    upper_key = "qualification_window_max_ev"
    if haskey(representation.conventions, lower_key) ||
       haskey(representation.conventions, upper_key)
        stored_lower = parse(Float64, representation.conventions[lower_key])
        stored_upper = parse(Float64, representation.conventions[upper_key])
        (stored_lower, stored_upper) == (lower, upper) ||
            throw(ArgumentError("configured qualification window disagrees with representation"))
    else
        representation.conventions[lower_key] = string(lower)
        representation.conventions[upper_key] = string(upper)
    end
    return representation
end

# Select complete degeneracy blocks in the explicit qualification window.
function _qualified_band_indices(representation::BandRepresentation, kpoint::Int)
    lower_key = "qualification_window_min_ev"
    upper_key = "qualification_window_max_ev"
    has_window =
        haskey(representation.conventions, lower_key) &&
        haskey(representation.conventions, upper_key)
    has_window || return collect(axes(representation.energies_ev, 1))
    lower = parse(Float64, representation.conventions[lower_key])
    upper = parse(Float64, representation.conventions[upper_key])
    indices = Int[]
    energies = @view representation.energies_ev[:, kpoint]
    labels = @view representation.band_block_labels[:, kpoint]
    for block in _band_label_ranges(labels)
        any(energy -> lower <= energy <= upper, @view energies[block]) || continue
        append!(indices, block)
    end
    isempty(indices) && throw(ArgumentError("qualified outer window selected no bands"))
    return indices
end

# Expand a VASP qualification window to complete energy-degeneracy blocks.
function _vasp_representation_qualification_masks(
    energies::Matrix{Float64},
    degeneracy_tolerance_ev::Float64,
    qualification_window_ev,
)
    labels = canonical_band_block_labels(energies, degeneracy_tolerance_ev)
    outer = falses(size(energies))
    for kpoint in axes(energies, 2)
        if qualification_window_ev === nothing
            outer[:, kpoint] .= true
            continue
        end
        lower, upper = something(qualification_window_ev)
        selected_labels = Set{Int}()
        for band in axes(energies, 1)
            lower <= energies[band, kpoint] <= upper && push!(selected_labels, labels[band, kpoint])
        end
        outer[:, kpoint] .= map(label -> label in selected_labels, @view(labels[:, kpoint]))
    end
    return [BitVector(@view outer[:, kpoint]) for kpoint in axes(outer, 2)],
    [falses(size(energies, 1)) for _ in axes(energies, 2)]
end

# Measure k action, unitarity, group composition, and pure-TR square.
function _validate_band_representation_absolute(
    representation::BandRepresentation;
    absolute_tolerance::Float64,
)
    table = build_band_product_table(
        representation.operations,
        representation.spinor;
        tolerance = min(1.0e-8, absolute_tolerance),
    )
    num_operations = length(representation.operations)
    num_kpoints = size(representation.kpoint_map, 2)
    maximum_shift = 0.0
    maximum_unitarity = 0.0
    maximum_group = zeros(Float64, 4)
    for operation_index in 1:num_operations
        sort(Vector(@view representation.kpoint_map[operation_index, :])) ==
        collect(1:num_kpoints) ||
            throw(ArgumentError("operation $(operation_index) does not permute the k mesh"))
        operation = representation.operations[operation_index]
        sign = operation.antiunitary ? -1.0 : 1.0
        for source_kpoint in 1:num_kpoints
            target_kpoint = representation.kpoint_map[operation_index, source_kpoint]
            transformed =
                sign .* (
                    transpose(inv(operation.rotation_fractional)) *
                    @view(representation.kpoints_fractional[source_kpoint, :])
                )
            reconstructed =
                @view(representation.kpoints_fractional[target_kpoint, :]) .+
                @view(representation.reciprocal_shifts[:, operation_index, source_kpoint])
            maximum_shift = max(maximum_shift, maximum(abs, transformed - reconstructed))
            source_indices = _qualified_band_indices(representation, source_kpoint)
            target_indices = _qualified_band_indices(representation, target_kpoint)
            length(source_indices) == length(target_indices) ||
                throw(ArgumentError("qualified band-window rank changes under symmetry"))
            sewing = Matrix(
                @view representation.sewing_matrices[
                    target_indices,
                    source_indices,
                    operation_index,
                    source_kpoint,
                ]
            )
            identity_block = Matrix{ComplexF64}(I, length(source_indices), length(source_indices))
            maximum_unitarity = max(
                maximum_unitarity,
                maximum(abs, sewing' * sewing - identity_block),
                maximum(abs, sewing * sewing' - identity_block),
            )
        end
    end
    for source_kpoint in 1:num_kpoints,
        left_index in 1:num_operations,
        right_index in 1:num_operations

        product_index = table.product_indices[left_index, right_index]
        intermediate_kpoint = representation.kpoint_map[right_index, source_kpoint]
        product_kpoint = representation.kpoint_map[product_index, source_kpoint]
        factor =
            table.spinor_factors[left_index, right_index] * cis(
                -2.0pi * dot(
                    @view(representation.kpoints_fractional[product_kpoint, :]),
                    @view(table.translation_differences[:, left_index, right_index]),
                ),
            )
        combination =
            representation.operations[left_index].antiunitary ?
            (representation.operations[right_index].antiunitary ? 4 : 3) :
            (representation.operations[right_index].antiunitary ? 2 : 1)
        source_indices = _qualified_band_indices(representation, source_kpoint)
        intermediate_indices = _qualified_band_indices(representation, intermediate_kpoint)
        target_indices = _qualified_band_indices(representation, product_kpoint)
        right_sewing = Matrix(
            @view representation.sewing_matrices[
                intermediate_indices,
                source_indices,
                right_index,
                source_kpoint,
            ]
        )
        representation.operations[left_index].antiunitary && (right_sewing = conj(right_sewing))
        left_sewing = Matrix(
            @view representation.sewing_matrices[
                target_indices,
                intermediate_indices,
                left_index,
                intermediate_kpoint,
            ]
        )
        product_sewing = Matrix(
            @view representation.sewing_matrices[
                target_indices,
                source_indices,
                product_index,
                source_kpoint,
            ]
        )
        residual = left_sewing * right_sewing - factor .* product_sewing
        maximum_group[combination] = max(maximum_group[combination], maximum(abs, residual))
    end
    maximum_theta = 0.0
    if table.theta_index !== nothing
        theta = something(table.theta_index)
        expected = representation.spinor ? -1.0 : 1.0
        for source_kpoint in 1:num_kpoints
            target_kpoint = representation.kpoint_map[theta, source_kpoint]
            source_indices = _qualified_band_indices(representation, source_kpoint)
            target_indices = _qualified_band_indices(representation, target_kpoint)
            square =
                @view(
                    representation.sewing_matrices[
                        source_indices,
                        target_indices,
                        theta,
                        target_kpoint,
                    ]
                ) * conj(
                    @view(
                        representation.sewing_matrices[
                            target_indices,
                            source_indices,
                            theta,
                            source_kpoint,
                        ]
                    )
                )
            identity_block = Matrix{ComplexF64}(I, length(source_indices), length(source_indices))
            maximum_theta = max(maximum_theta, maximum(abs, square - expected .* identity_block))
        end
    end
    return (
        table,
        maximum_group_law_residuals = Tuple(maximum_group),
        maximum_reciprocal_shift_residual = maximum_shift,
        maximum_unitarity_residual = maximum_unitarity,
        maximum_theta_residual = maximum_theta,
    )
end

# Read frozen native-vs-IrRep parity evidence without importing Python at runtime.
function _read_frozen_oracle_evidence(filename::AbstractString)
    isfile(filename) || throw(ArgumentError("oracle evidence does not exist: $(filename)"))
    HDF5.enable_complex_support()
    return HDF5.h5open(filename, "r") do handle
        schema = String(read(HDF5.attributes(handle)["schema"]))
        schema == "WannierNLQG.representation_parity" ||
            throw(ArgumentError("oracle file must use WannierNLQG.representation_parity"))
        Bool(read(HDF5.attributes(handle)["passed"])) ||
            throw(ArgumentError("frozen native/IrRep parity artifact did not pass"))
        metrics = HDF5.attributes(handle["metrics"])
        combinations = ("U" * "U", "U" * "A", "A" * "U", "A" * "A")
        candidate = ntuple(
            index -> Float64(
                read(metrics["candidate_group_law_$(combinations[index])_absolute_max_abs"]),
            ),
            4,
        )
        excess = ntuple(
            index -> Float64(
                read(metrics["paired_group_law_$(combinations[index])_excess_max_abs"]),
            ),
            4,
        )
        return (
            candidate_group_law = candidate,
            oracle_excess = excess,
            block_aligned_sewing_max_abs = Float64(read(metrics["block_aligned_sewing_max_abs"])),
            reciprocal_shift_max_abs = Float64(read(metrics["reciprocal_shift_max_abs"])),
            operation_match_error = Float64(read(metrics["operation_match_error"])),
            kpoint_action_mismatch = Float64(read(metrics["kpoint_action_mismatch"])),
            sha256 = _band_source_sha256_file(filename),
        )
    end
end

# Apply the absolute and frozen-oracle gates to one native representation.
function validate_band_representation(
    representation::BandRepresentation;
    absolute_tolerance::Float64,
    oracle_excess_tolerance::Float64,
    oracle_hdf5_file::Union{Nothing, AbstractString} = nothing,
    require_oracle::Bool = true,
)
    absolute = _validate_band_representation_absolute(representation; absolute_tolerance)
    diagnostics = String[]
    oracle_excess = nothing
    oracle_sha256 = nothing
    oracle_ok = !require_oracle
    if oracle_hdf5_file !== nothing
        evidence = _read_frozen_oracle_evidence(String(oracle_hdf5_file))
        oracle_excess = evidence.oracle_excess
        oracle_sha256 = evidence.sha256
        oracle_ok =
            maximum(
                abs,
                collect(absolute.maximum_group_law_residuals) .-
                collect(evidence.candidate_group_law),
            ) <= oracle_excess_tolerance &&
            maximum(evidence.oracle_excess) <= oracle_excess_tolerance &&
            evidence.block_aligned_sewing_max_abs <= oracle_excess_tolerance &&
            evidence.reciprocal_shift_max_abs <= oracle_excess_tolerance &&
            evidence.operation_match_error <= oracle_excess_tolerance &&
            evidence.kpoint_action_mismatch == 0.0
        oracle_ok || push!(
            diagnostics,
            "current native representation disagrees with frozen IrRep parity evidence",
        )
    elseif require_oracle
        push!(diagnostics, "required frozen IrRep parity evidence is unavailable")
    end
    absolute_ok =
        maximum(absolute.maximum_group_law_residuals) <= absolute_tolerance &&
        absolute.maximum_reciprocal_shift_residual <= absolute_tolerance &&
        absolute.maximum_unitarity_residual <= absolute_tolerance &&
        absolute.maximum_theta_residual <= absolute_tolerance
    absolute_ok || push!(diagnostics, "absolute band-representation group gate failed")
    return BandRepresentationValidation(
        absolute_ok && oracle_ok,
        absolute_tolerance,
        oracle_excess_tolerance,
        absolute.maximum_group_law_residuals,
        absolute.maximum_reciprocal_shift_residual,
        absolute.maximum_unitarity_residual,
        absolute.maximum_theta_residual,
        oracle_excess,
        oracle_sha256,
        _band_representation_sha256(representation),
        diagnostics,
    )
end

# Replace a destination only after a complete temporary HDF5 close.
function _atomic_band_hdf5_write(writer::Function, filename::AbstractString; overwrite::Bool)
    path = abspath(filename)
    ispath(path) && !overwrite && throw(ArgumentError("refusing to overwrite $(path)"))
    mkpath(dirname(path))
    temporary, io = mktemp(dirname(path); cleanup = false)
    close(io)
    completed = false
    try
        writer(temporary)
        mv(temporary, path; force = true)
        completed = true
    finally
        !completed && isfile(temporary) && rm(temporary; force = true)
    end
    return path
end

# Persist one sorted string dictionary as HDF5 attributes.
function _write_band_string_dictionary(parent, values::Dict{String, String})
    for key in sort!(collect(keys(values)))
        HDF5.attributes(parent)[key] = values[key]
    end
    return nothing
end

# Read string-valued HDF5 attributes into a deterministic dictionary.
function _read_band_string_dictionary(parent)
    return Dict{String, String}(
        String(key) => String(read(HDF5.attributes(parent)[key])) for
        key in keys(HDF5.attributes(parent))
    )
end

# Attach the language-neutral axis contract to one dataset.
function _write_band_axis_order(dataset, order::AbstractString)
    HDF5.attributes(dataset)["axis_order"] = String(order)
    return dataset
end

# Read one mandatory HDF5 attribute.
function _required_band_attribute(parent, name::AbstractString)
    haskey(HDF5.attributes(parent), name) ||
        throw(ArgumentError("HDF5 object is missing attribute $(name)"))
    return read(HDF5.attributes(parent)[name])
end

# Validate one mandatory axis contract before permuting storage.
function _require_band_axis_order(dataset, expected::AbstractString)
    actual = String(_required_band_attribute(dataset, "axis_order"))
    actual == expected ||
        throw(ArgumentError("HDF5 axis_order $(actual) disagrees with $(expected)"))
    return nothing
end

# Reconstruct the default outer and empty frozen qualification masks.
function _band_v14_masks(representation::BandRepresentation)
    outer = falses(size(representation.energies_ev))
    for kpoint in axes(outer, 2)
        outer[_qualified_band_indices(representation, kpoint), kpoint] .= true
    end
    return BitMatrix(outer), falses(size(outer))
end

# Build compatibility fallback diagnostics from already constructed sewing matrices.
function _band_v14_raw_diagnostics(
    representation::BandRepresentation,
    outer::BitMatrix,
    frozen::BitMatrix,
)
    diagnostics = RepresentationRawDiagnostic[]
    nb, nk = size(representation.energies_ev)
    for source_kpoint in 1:nk, operation_index in eachindex(representation.operations)
        target_kpoint = representation.kpoint_map[operation_index, source_kpoint]
        for scope in (:full, :outer, :frozen, :outside)
            source_mask =
                scope == :full ? trues(nb) :
                scope == :outer ? outer[:, source_kpoint] :
                scope == :frozen ? frozen[:, source_kpoint] : .!outer[:, source_kpoint]
            target_mask =
                scope == :full ? trues(nb) :
                scope == :outer ? outer[:, target_kpoint] :
                scope == :frozen ? frozen[:, target_kpoint] : .!outer[:, target_kpoint]
            source_indices = findall(source_mask)
            target_indices = findall(target_mask)
            required_rank = min(length(source_indices), length(target_indices))
            if isempty(source_indices) || isempty(target_indices)
                push!(
                    diagnostics,
                    RepresentationRawDiagnostic(
                        scope,
                        operation_index,
                        source_kpoint,
                        target_kpoint,
                        representation.operations[operation_index].antiunitary,
                        length(source_indices),
                        length(target_indices),
                        required_rank,
                        0,
                        0.0,
                        0.0,
                        0.0,
                        Inf,
                        0.0,
                        0.0,
                        :EMPTY_SCOPE,
                    ),
                )
                continue
            end
            block = Matrix{ComplexF64}(
                @view representation.sewing_matrices[
                    target_indices,
                    source_indices,
                    operation_index,
                    source_kpoint,
                ]
            )
            singular_values = svdvals(block)
            sigma_max = maximum(singular_values)
            sigma_min = minimum(singular_values)
            rank_threshold = max(size(block)...) * eps(Float64) * max(sigma_max, 1.0)
            left_identity = Matrix{ComplexF64}(I, size(block, 1), size(block, 1))
            right_identity = Matrix{ComplexF64}(I, size(block, 2), size(block, 2))
            push!(
                diagnostics,
                RepresentationRawDiagnostic(
                    scope,
                    operation_index,
                    source_kpoint,
                    target_kpoint,
                    representation.operations[operation_index].antiunitary,
                    length(source_indices),
                    length(target_indices),
                    required_rank,
                    count(>(rank_threshold), singular_values),
                    rank_threshold,
                    sigma_min,
                    sigma_max,
                    sigma_min > 0.0 ? sigma_max / sigma_min : Inf,
                    maximum(abs, block * block' - left_identity),
                    maximum(abs, block' * block - right_identity),
                    length(source_indices) == length(target_indices) ? :REPORT_ONLY :
                    :DIMENSION_MISMATCH,
                ),
            )
        end
    end
    return diagnostics
end

# Convert canonical pre-polar construction diagnostics to schema-1.4 rows.
function _band_v14_construction_raw_diagnostics(construction_diagnostics, representation)
    scoped = filter(diagnostic -> haskey(diagnostic, "scope"), construction_diagnostics)
    expected = size(representation.energies_ev, 2) * length(representation.operations) * 4
    length(scoped) == expected || throw(
        ArgumentError(
            "canonical pre-polar raw diagnostic count $(length(scoped)) disagrees with $(expected)",
        ),
    )
    return RepresentationRawDiagnostic[
        RepresentationRawDiagnostic(
            Symbol(diagnostic["scope"]),
            diagnostic["operation"],
            diagnostic["source_kpoint"],
            diagnostic["target_kpoint"],
            representation.operations[diagnostic["operation"]].antiunitary,
            diagnostic["source_band_count"],
            diagnostic["target_band_count"],
            diagnostic["required_rank"],
            diagnostic["numerical_rank"],
            diagnostic["rank_threshold"],
            diagnostic["sigma_min"],
            diagnostic["sigma_max"],
            diagnostic["condition_estimate"],
            diagnostic["left_unitarity_residual"],
            diagnostic["right_unitarity_residual"],
            Symbol(diagnostic["status"]),
        ) for diagnostic in scoped
    ]
end

# Persist schema-1.4 inventory, qualification masks, diagnostics, and policies.
function _write_band_v14_preparation_metadata(
    handle,
    representation::BandRepresentation;
    inventory = nothing,
    qualification_scope = nothing,
    qualification_outer_mask = nothing,
    qualification_frozen_mask = nothing,
    raw_diagnostics = nothing,
    requested_policy::Symbol = :strict,
    effective_policy::Symbol = :strict,
    symmetry_tolerance_status::Symbol = :NOT_APPLICABLE,
)
    default_outer, default_frozen = _band_v14_masks(representation)
    outer =
        qualification_outer_mask === nothing ? default_outer : BitMatrix(qualification_outer_mask)
    frozen =
        qualification_frozen_mask === nothing ? default_frozen :
        BitMatrix(qualification_frozen_mask)
    size(outer) == size(representation.energies_ev) == size(frozen) ||
        throw(ArgumentError("qualification masks disagree with representation dimensions"))
    diagnostics = if raw_diagnostics === nothing
        _band_v14_raw_diagnostics(representation, outer, frozen)
    elseif isempty(raw_diagnostics) || first(raw_diagnostics) isa RepresentationRawDiagnostic
        RepresentationRawDiagnostic[raw_diagnostics...]
    else
        _band_v14_construction_raw_diagnostics(raw_diagnostics, representation)
    end
    outer_digest = qualification_mask_sha256(outer)
    frozen_digest = qualification_mask_sha256(frozen)
    inventory_group = HDF5.create_group(handle, "inventory")
    inventory_attributes = HDF5.attributes(inventory_group)
    inventory_attributes["status"] = inventory === nothing ? "UNAVAILABLE" : "AVAILABLE"
    if inventory !== nothing
        inventory_attributes["magnetic"] = inventory.magnetic
        inventory_attributes["msg_type"] = inventory.msg_type
        inventory_attributes["uni_number"] = something(inventory.uni_number, 0)
        inventory_attributes["hall_number"] = inventory.hall_number
        inventory_attributes["unitary_operation_count"] = inventory.unitary_operation_count
        inventory_attributes["antiunitary_operation_count"] = inventory.antiunitary_operation_count
        inventory_attributes["symmetry_tolerance"] = inventory.symmetry_tolerance
    end
    scope_group = HDF5.create_group(handle, "qualification_scope")
    HDF5.attributes(scope_group)["diagnostic_status"] = "AVAILABLE"
    HDF5.attributes(scope_group)["outer_mask_sha256"] = outer_digest
    HDF5.attributes(scope_group)["frozen_mask_sha256"] = frozen_digest
    scope_group["outer_mask"] = Matrix{UInt8}(outer)
    scope_group["frozen_mask"] = Matrix{UInt8}(frozen)
    _write_band_axis_order(scope_group["outer_mask"], "band,kpoint")
    _write_band_axis_order(scope_group["frozen_mask"], "band,kpoint")
    raw_group = HDF5.create_group(handle, "raw_diagnostics")
    HDF5.attributes(raw_group)["status"] = "AVAILABLE"
    HDF5.attributes(raw_group)["count"] = length(diagnostics)
    integers = zeros(Int, 8, length(diagnostics))
    values = zeros(Float64, 6, length(diagnostics))
    scopes = zeros(UInt8, length(diagnostics))
    statuses = zeros(UInt8, length(diagnostics))
    scope_codes = Dict(:full => 0x01, :outer => 0x02, :frozen => 0x03, :outside => 0x04)
    status_codes = Dict(:REPORT_ONLY => 0x01, :DIMENSION_MISMATCH => 0x02, :EMPTY_SCOPE => 0x03)
    for (index, diagnostic) in enumerate(diagnostics)
        integers[:, index] .= (
            diagnostic.operation_index,
            diagnostic.source_kpoint,
            diagnostic.target_kpoint,
            Int(diagnostic.antiunitary),
            diagnostic.source_band_count,
            diagnostic.target_band_count,
            diagnostic.required_rank,
            diagnostic.numerical_rank,
        )
        values[:, index] .= (
            diagnostic.rank_threshold,
            diagnostic.minimum_singular_value,
            diagnostic.maximum_singular_value,
            diagnostic.condition_estimate,
            diagnostic.left_unitarity_residual,
            diagnostic.right_unitarity_residual,
        )
        scopes[index] = scope_codes[diagnostic.scope]
        statuses[index] = status_codes[diagnostic.status]
    end
    raw_group["integer_values"] = integers
    raw_group["real_values"] = values
    raw_group["scope_code"] = scopes
    raw_group["status_code"] = statuses
    policy = HDF5.create_group(handle, "compatibility_policy")
    HDF5.attributes(policy)["requested"] = String(requested_policy)
    HDF5.attributes(policy)["effective"] = String(effective_policy)
    HDF5.attributes(policy)["symmetry_tolerance_status"] = String(symmetry_tolerance_status)
    HDF5.attributes(handle)["preparation_digest"] = _band_preparation_metadata_digest(
        inventory,
        diagnostics,
        outer_digest,
        frozen_digest,
        requested_policy,
        effective_policy,
        symmetry_tolerance_status,
    )
    return nothing
end

"""Atomically write the shared strict band-representation schema."""
function write_band_representation_hdf5(
    filename::AbstractString,
    representation::BandRepresentation;
    validation = nothing,
    overwrite::Bool = false,
    inventory = nothing,
    qualification_scope = nothing,
    qualification_outer_mask = nothing,
    qualification_frozen_mask = nothing,
    raw_diagnostics = nothing,
    requested_policy::Symbol = :strict,
    effective_policy::Symbol = :strict,
    symmetry_tolerance_status::Symbol = :NOT_APPLICABLE,
)
    _band_validate_public_representation_contract(representation)
    if qualification_scope !== nothing
        hasproperty(qualification_scope, :outer_mask) ||
            throw(ArgumentError("qualification_scope must provide outer_mask"))
        hasproperty(qualification_scope, :frozen_mask) ||
            throw(ArgumentError("qualification_scope must provide frozen_mask"))
        scoped_outer_mask = getproperty(qualification_scope, :outer_mask)
        scoped_frozen_mask = getproperty(qualification_scope, :frozen_mask)
        if qualification_outer_mask !== nothing && qualification_outer_mask != scoped_outer_mask
            throw(ArgumentError("qualification_outer_mask conflicts with qualification_scope"))
        end
        if qualification_frozen_mask !== nothing && qualification_frozen_mask != scoped_frozen_mask
            throw(ArgumentError("qualification_frozen_mask conflicts with qualification_scope"))
        end
        qualification_outer_mask = scoped_outer_mask
        qualification_frozen_mask = scoped_frozen_mask
    end
    output_filename = abspath(filename)
    split_band_residuals =
        validation !== nothing && hasproperty(validation, :band_group_law_residuals) ?
        Float64.(collect(getproperty(validation, :band_group_law_residuals))) : nothing
    split_target_residuals =
        validation !== nothing && hasproperty(validation, :target_group_law_residuals) ?
        Float64.(collect(getproperty(validation, :target_group_law_residuals))) : nothing
    band_worst_cases =
        validation !== nothing && hasproperty(validation, :band_group_law_worst_cases) ?
        getproperty(validation, :band_group_law_worst_cases) : nothing
    target_worst_cases =
        validation !== nothing && hasproperty(validation, :target_group_law_worst_cases) ?
        getproperty(validation, :target_group_law_worst_cases) : nothing
    if validation !== nothing && !(validation isa BandRepresentationValidation)
        if hasproperty(validation, :passed) && !Bool(getproperty(validation, :passed))
            root, extension = splitext(output_filename)
            assessment =
                hasproperty(validation, :assessment_status) ?
                string(getproperty(validation, :assessment_status)) : "INCOMPATIBLE"
            suffix = occursin("UNDETERMINED", assessment) ? ".undetermined" : ".incompatible"
            endswith(root, suffix) || (root *= suffix)
            output_filename = root * (isempty(extension) ? ".h5" : extension)
        end
        required = (
            :passed,
            :tolerance,
            :maximum_group_law_residuals,
            :maximum_reciprocal_shift_residual,
            :theta_squared_residual,
            :maximum_required_block_unitarity_residual,
            :representation_sha256,
        )
        all(field -> hasproperty(validation, field), required) ||
            throw(ArgumentError("unsupported band-representation validation object"))
        legacy_diagnostics =
            hasproperty(validation, :diagnostics) ?
            [sprint(show, diagnostic) for diagnostic in getproperty(validation, :diagnostics)] :
            String[]
        oracle_excess =
            hasproperty(validation, :oracle_excess_group_law_residuals) ?
            getproperty(validation, :oracle_excess_group_law_residuals) : nothing
        oracle_sha =
            hasproperty(validation, :qualification_sha256) ?
            getproperty(validation, :qualification_sha256) : nothing
        validation = BandRepresentationValidation(
            Bool(getproperty(validation, :passed)),
            Float64(getproperty(validation, :tolerance)),
            Float64(getproperty(validation, :tolerance)),
            Tuple(Float64.(collect(getproperty(validation, :maximum_group_law_residuals)))),
            Float64(getproperty(validation, :maximum_reciprocal_shift_residual)),
            Float64(getproperty(validation, :maximum_required_block_unitarity_residual)),
            Float64(getproperty(validation, :theta_squared_residual)),
            oracle_excess === nothing ? nothing : Tuple(Float64.(collect(oracle_excess))),
            oracle_sha === nothing ? nothing : String(oracle_sha),
            String(getproperty(validation, :representation_sha256)),
            legacy_diagnostics,
        )
    end
    if validation isa BandRepresentationValidation &&
       !validation.passed &&
       output_filename == abspath(filename)
        root, extension = splitext(output_filename)
        endswith(root, ".incompatible") || (root *= ".incompatible")
        output_filename = root * (isempty(extension) ? ".h5" : extension)
    end
    validation === nothing ||
        validation.representation_sha256 == _band_representation_sha256(representation) ||
        throw(ArgumentError("validation belongs to a different representation"))
    HDF5.enable_complex_support()
    table = build_band_product_table(representation.operations, representation.spinor)
    return _atomic_band_hdf5_write(output_filename; overwrite) do temporary
        HDF5.h5open(temporary, "w") do handle
            attributes = HDF5.attributes(handle)
            attributes["schema"] = BAND_REPRESENTATION_SCHEMA
            attributes["schema_version"] = BAND_REPRESENTATION_SCHEMA_VERSION
            attributes["source_code"] = String(representation.source_code)
            attributes["spinor"] = representation.spinor
            geometry = HDF5.create_group(handle, "geometry")
            geometry["real_lattice"] = Matrix(transpose(representation.real_lattice))
            _write_band_axis_order(geometry["real_lattice"], "cartesian_vector,xyz")
            geometry["reciprocal_lattice"] = Matrix(transpose(representation.reciprocal_lattice))
            _write_band_axis_order(geometry["reciprocal_lattice"], "cartesian_vector,xyz")
            geometry["mp_grid"] = collect(representation.mp_grid)
            geometry["kpoints_fractional"] = Matrix(transpose(representation.kpoints_fractional))
            _write_band_axis_order(geometry["kpoints_fractional"], "kpoint,xyz")
            bands = HDF5.create_group(handle, "bands")
            bands["energies_ev"] = representation.energies_ev
            _write_band_axis_order(bands["energies_ev"], "kpoint,band")
            bands["block_labels"] = representation.band_block_labels
            _write_band_axis_order(bands["block_labels"], "kpoint,band")
            operation_group = HDF5.create_group(handle, "operations")
            ng = length(representation.operations)
            fractional = Array{Int, 3}(undef, 3, 3, ng)
            translations = Matrix{Float64}(undef, 3, ng)
            cartesian = Array{Float64, 3}(undef, 3, 3, ng)
            antiunitary = Vector{UInt8}(undef, ng)
            for operation_index in 1:ng
                operation = representation.operations[operation_index]
                fractional[:, :, operation_index] .= operation.rotation_fractional
                translations[:, operation_index] .= operation.translation_fractional
                cartesian[:, :, operation_index] .= operation.rotation_cartesian
                antiunitary[operation_index] = operation.antiunitary
            end
            operation_group["rotation_fractional"] = permutedims(fractional, (2, 1, 3))
            _write_band_axis_order(
                operation_group["rotation_fractional"],
                "operation,target_xyz,source_xyz",
            )
            operation_group["translation_fractional"] = translations
            _write_band_axis_order(operation_group["translation_fractional"], "operation,xyz")
            operation_group["rotation_cartesian"] = permutedims(cartesian, (2, 1, 3))
            _write_band_axis_order(
                operation_group["rotation_cartesian"],
                "operation,target_xyz,source_xyz",
            )
            operation_group["antiunitary"] = antiunitary
            action = HDF5.create_group(handle, "action")
            action["kpoint_map"] = representation.kpoint_map
            _write_band_axis_order(action["kpoint_map"], "kpoint,operation")
            action["reciprocal_shifts"] = representation.reciprocal_shifts
            _write_band_axis_order(action["reciprocal_shifts"], "kpoint,operation,xyz")
            action["sewing_matrices"] = permutedims(representation.sewing_matrices, (2, 1, 3, 4))
            _write_band_axis_order(
                action["sewing_matrices"],
                "kpoint,operation,target_band,source_band",
            )
            stars = HDF5.create_group(handle, "stars")
            stars["irreducible_indices"] = representation.irreducible_indices
            stars["full_to_irreducible"] = representation.full_to_irreducible
            stars["full_to_operation"] = representation.full_to_operation
            _write_band_string_dictionary(
                HDF5.create_group(handle, "conventions"),
                representation.conventions,
            )
            backend_metadata = Dict(
                key => value for
                (key, value) in representation.conventions if key == "sewing_backend" ||
                key == "sewing_metric" ||
                key == "augmentation_backend" ||
                key == "physical_overlap_available" ||
                startswith(key, "strict_") ||
                startswith(key, "raw_group_law") ||
                startswith(key, "raw_reciprocal_cocycle") ||
                startswith(key, "generalized_norm") ||
                key == "paw_sewing_thresholds"
            )
            backend_metadata["sewing_backend"] =
                get(representation.conventions, "sewing_backend", "coefficient_mapping")
            _write_band_string_dictionary(
                HDF5.create_group(handle, "sewing_backend"),
                backend_metadata,
            )
            gauge_metadata = Dict(
                "wavefunction_gauge_backend" => get(
                    representation.conventions,
                    "wavefunction_gauge_backend",
                    "native_eigenstate",
                ),
                "wavefunction_gauge_hdf5_sha256" => get(
                    representation.conventions,
                    "wavefunction_gauge_hdf5_sha256",
                    "NOT_APPLICABLE",
                ),
            )
            merge!(
                gauge_metadata,
                Dict(
                    key => value for (key, value) in representation.conventions if
                    startswith(key, "block_partition_") ||
                        startswith(key, "controlled_symmetrization_") ||
                        startswith(key, "energy_shift_") ||
                        key in (
                            "maximum_energy_shift_audit_reference_ev",
                            "rms_energy_shift_audit_reference_ev",
                            "target_energy_shift_audit_status",
                            "symmetrized_parent_energy_shift_audit_status",
                            "residual_gate_phase",
                            "raw_preflight_diagnostic_status",
                            "native_difference_qualification",
                            "native_difference_audit_status",
                            "qualification_scope",
                            "target_authority",
                            "parent_audit_policy",
                            "target_subspace_contract_sha256",
                            "target_leakage_semantics",
                            "target_leakage_formula_sha256",
                            "target_leakage_threshold",
                            "target_anchor",
                            "target_complement_completion",
                            "target_complement_max_element_ev",
                            "auxiliary_parent_qualification",
                            "symmetrized_target_subspace_status",
                            "auxiliary_parent_audit_status",
                            "target_scope_production_eligible",
                        ) ||
                        key in (
                            "discrete_hamiltonian_correction",
                            "authoritative_hamiltonian",
                            "authoritative_hamiltonian_sha256",
                            "native_fidelity_status",
                            "symmetrized_hamiltonian_status",
                            "scoped_production_eligible",
                            "global_production_eligible",
                            "production_eligible",
                            "diagnostic_only",
                        )
                ),
            )
            _write_band_string_dictionary(
                HDF5.create_group(handle, "wavefunction_gauge"),
                gauge_metadata,
            )
            _write_band_string_dictionary(
                HDF5.create_group(handle, "input_sha256"),
                representation.input_sha256,
            )
            products = HDF5.create_group(handle, "products")
            HDF5.attributes(products)["identity_operation"] = table.identity_index
            HDF5.attributes(products)["theta_operation"] = something(table.theta_index, 0)
            _write_band_string_dictionary(
                HDF5.create_group(products, "canonical_identity"),
                Dict(
                    lpad(string(index), 6, '0') => key for
                    (index, key) in enumerate(table.canonical_keys)
                ),
            )
            products["product_index"] = Matrix(transpose(table.product_indices))
            _write_band_axis_order(products["product_index"], "left_operation,right_operation")
            products["translation_integer"] = permutedims(table.translation_differences, (1, 3, 2))
            _write_band_axis_order(
                products["translation_integer"],
                "left_operation,right_operation,xyz",
            )
            products["spinor_factor"] = Matrix(transpose(table.spinor_factors))
            _write_band_axis_order(products["spinor_factor"], "left_operation,right_operation")
            products["spin_action"] = permutedims(table.spin_actions, (2, 1, 3))
            _write_band_axis_order(products["spin_action"], "operation,target_spin,source_spin")
            compatibility = HDF5.create_group(handle, "compatibility")
            compatibility_attributes = HDF5.attributes(compatibility)
            compatibility_attributes["status"] =
                validation === nothing ? "NOT_EVALUATED" :
                validation.passed ? "COMPATIBLE" : "INCOMPATIBLE"
            compatibility_attributes["gate_definition_status"] =
                validation === nothing ? "GATE_NOT_EVALUATED" : "GATE_VALID"
            compatibility_attributes["assessment_status"] =
                validation === nothing ? "REPRESENTATION_UNDETERMINED" :
                validation.passed ? "REPRESENTATION_COMPATIBLE" :
                "REPRESENTATION_INCOMPATIBLE_ASSESSMENT"
            compatibility_attributes["supported_contract"] = true
            compatibility_attributes["tolerance"] =
                validation === nothing ? NaN : validation.absolute_tolerance
            compatibility_attributes["representation_sha256"] =
                _band_representation_sha256(representation)
            compatibility_attributes["metadata_origin"] = "computed_native_julia"
            compatibility_attributes["validation_profile"] = "empirical"
            compatibility_attributes["maximum_required_block_unitarity_residual"] =
                validation === nothing ? NaN : validation.maximum_unitarity_residual
            compatibility_attributes["qualification_sha256"] =
                validation === nothing || validation.oracle_sha256 === nothing ? "" :
                something(validation.oracle_sha256)
            compatibility_attributes["maximum_reciprocal_shift_residual"] =
                validation === nothing ? NaN : validation.maximum_reciprocal_shift_residual
            compatibility_attributes["theta_squared_residual"] =
                validation === nothing ? NaN : validation.maximum_theta_residual
            compatibility_attributes["maximum_kramers_residual"] =
                validation === nothing ? NaN : validation.maximum_theta_residual
            compatibility["maximum_group_law_residual"] =
                validation === nothing ? fill(NaN, 4) :
                collect(validation.maximum_group_law_residuals)
            _write_band_axis_order(
                compatibility["maximum_group_law_residual"],
                "combination_UU_UA_AU_AA",
            )
            compatibility["band_group_law_residual"] =
                split_band_residuals === nothing ?
                (
                    validation === nothing ? fill(NaN, 4) :
                    collect(validation.maximum_group_law_residuals)
                ) : split_band_residuals
            compatibility["target_group_law_residual"] =
                split_target_residuals === nothing ? fill(NaN, 4) : split_target_residuals
            _write_band_axis_order(
                compatibility["band_group_law_residual"],
                "combination_UU_UA_AU_AA",
            )
            _write_band_axis_order(
                compatibility["target_group_law_residual"],
                "combination_UU_UA_AU_AA",
            )
            worst_cases = HDF5.create_group(compatibility, "worst_cases")
            for (domain, contexts) in (("band", band_worst_cases), ("target", target_worst_cases))
                domain_group = HDF5.create_group(worst_cases, domain)
                for (index, channel) in enumerate(("UU", "UA", "AU", "A" * "A"))
                    channel_group = HDF5.create_group(domain_group, channel)
                    contexts === nothing || _write_band_string_dictionary(
                        channel_group,
                        Dict{String, String}(contexts[index]),
                    )
                end
            end
            compatibility["oracle_excess_group_law_residual"] =
                validation === nothing || validation.oracle_excess_group_law_residuals === nothing ?
                fill(NaN, 4) : collect(something(validation.oracle_excess_group_law_residuals))
            _write_band_axis_order(
                compatibility["oracle_excess_group_law_residual"],
                "combination_UU_UA_AU_AA",
            )
            _write_band_v14_preparation_metadata(
                handle,
                representation;
                inventory,
                qualification_outer_mask,
                qualification_frozen_mask,
                raw_diagnostics,
                requested_policy,
                effective_policy,
                symmetry_tolerance_status,
            )
            environment = HDF5.create_group(handle, "environment")
            environment_attributes = HDF5.attributes(environment)
            environment_attributes["generated_at_utc"] = string(now(UTC))
            environment_attributes["julia_version"] = string(VERSION)
            environment_attributes["wanniernlqg_version"] = string(Base.pkgversion(WannierNLQG))
            environment_attributes["hdf5_jl_version"] = string(Base.pkgversion(HDF5))
            environment_attributes["threads"] = Threads.nthreads()
        end
        checked = read_band_representation_hdf5(temporary)
        read_band_representation_preparation_hdf5(temporary, checked)
    end
end

"""Read and validate a strict shared band-representation HDF5 artifact."""
function read_band_representation_hdf5(filename::AbstractString)
    isfile(filename) || throw(ArgumentError("band representation does not exist: $(filename)"))
    HDF5.enable_complex_support()
    return HDF5.h5open(filename, "r") do handle
        version = _require_public_band_header(handle)
        geometry = handle["geometry"]
        begin
            _require_band_axis_order(geometry["real_lattice"], "cartesian_vector,xyz")
            _require_band_axis_order(geometry["reciprocal_lattice"], "cartesian_vector,xyz")
            _require_band_axis_order(geometry["kpoints_fractional"], "kpoint,xyz")
            _require_band_axis_order(handle["action/kpoint_map"], "kpoint,operation")
            _require_band_axis_order(handle["action/reciprocal_shifts"], "kpoint,operation,xyz")
            _require_band_axis_order(
                handle["action/sewing_matrices"],
                "kpoint,operation,target_band,source_band",
            )
        end
        operation_group = handle["operations"]
        fractional_raw = read(operation_group["rotation_fractional"])
        cartesian_raw = read(operation_group["rotation_cartesian"])
        fractional = permutedims(fractional_raw, (2, 1, 3))
        cartesian = permutedims(cartesian_raw, (2, 1, 3))
        translations = read(operation_group["translation_fractional"])
        antiunitary = read(operation_group["antiunitary"])
        operations = [
            SymmetryOperation(
                fractional[:, :, index],
                translations[:, index],
                cartesian[:, :, index],
                Bool(antiunitary[index]),
            ) for index in axes(fractional, 3)
        ]
        conventions = _read_band_string_dictionary(handle["conventions"])
        authority = _band_validate_authority_key(
            get(conventions, "authoritative_hamiltonian", "native_dft"),
        )
        representation = BandRepresentation(
            version,
            Symbol(String(_required_band_attribute(handle, "source_code"))),
            Bool(_required_band_attribute(handle, "spinor")),
            Matrix(transpose(read(geometry["real_lattice"]))),
            Matrix(transpose(read(geometry["reciprocal_lattice"]))),
            Tuple(Int.(read(geometry["mp_grid"]))),
            Matrix(transpose(read(geometry["kpoints_fractional"]))),
            read(handle["bands/energies_ev"]),
            operations,
            read(handle["action/kpoint_map"]),
            read(handle["action/reciprocal_shifts"]),
            permutedims(read(handle["action/sewing_matrices"]), (2, 1, 3, 4)),
            read(handle["bands/block_labels"]),
            read(handle["stars/irreducible_indices"]),
            read(handle["stars/full_to_irreducible"]),
            read(handle["stars/full_to_operation"]);
            conventions,
            input_sha256 = _read_band_string_dictionary(handle["input_sha256"]),
        )
        _band_validate_public_representation_contract(representation)
        begin
            products = handle["products"]
            _require_band_axis_order(products["product_index"], "left_operation,right_operation")
            _require_band_axis_order(
                products["translation_integer"],
                "left_operation,right_operation,xyz",
            )
            _require_band_axis_order(products["spinor_factor"], "left_operation,right_operation")
            _require_band_axis_order(products["spin_action"], "operation,target_spin,source_spin")
            derived = build_band_product_table(representation.operations, representation.spinor)
            stored_keys_dictionary = _read_band_string_dictionary(products["canonical_identity"])
            stored_keys = [
                stored_keys_dictionary[key] for key in sort!(collect(keys(stored_keys_dictionary)))
            ]
            stored_keys == derived.canonical_keys ||
                throw(ArgumentError("canonical operation identities contradict operations"))
            Int(_required_band_attribute(products, "identity_operation")) ==
            derived.identity_index ||
                throw(ArgumentError("identity operation contradicts product metadata"))
            Int(_required_band_attribute(products, "theta_operation")) ==
            something(derived.theta_index, 0) ||
                throw(ArgumentError("time-reversal operation contradicts product metadata"))
            transpose(read(products["product_index"])) == derived.product_indices ||
                throw(ArgumentError("product table contradicts operation metadata"))
            permutedims(read(products["translation_integer"]), (1, 3, 2)) ==
            derived.translation_differences ||
                throw(ArgumentError("translation cocycle contradicts operation metadata"))
            transpose(read(products["spinor_factor"])) == derived.spinor_factors ||
                throw(ArgumentError("spinor factors contradict operation metadata"))
            stored_spin = permutedims(read(products["spin_action"]), (2, 1, 3))
            maximum(abs, stored_spin - derived.spin_actions) <= 1.0e-7 ||
                throw(ArgumentError("spin actions contradict operation metadata"))
            stored_digest =
                String(_required_band_attribute(handle["compatibility"], "representation_sha256"))
            stored_digest == _band_representation_sha256(representation) ||
                throw(ArgumentError("band-representation SHA-256 mismatch"))
            begin
                compatibility = handle["compatibility"]
                _require_band_axis_order(
                    compatibility["oracle_excess_group_law_residual"],
                    "combination_UU_UA_AU_AA",
                )
                status = String(_required_band_attribute(compatibility, "status"))
                gate = String(_required_band_attribute(compatibility, "gate_definition_status"))
                assessment = String(_required_band_attribute(compatibility, "assessment_status"))
                status in ("NOT_EVALUATED", "COMPATIBLE", "UNDETERMINED", "INCOMPATIBLE") ||
                    throw(ArgumentError("schema-1.0 compatibility status is unknown"))
                gate in ("GATE_NOT_EVALUATED", "GATE_VALID", "GATE_DEFINITION_INVALID") ||
                    throw(ArgumentError("schema-1.0 gate-definition status is unknown"))
                assessment in (
                    "REPRESENTATION_UNDETERMINED",
                    "REPRESENTATION_COMPATIBLE",
                    "REPRESENTATION_INCOMPATIBLE_ASSESSMENT",
                ) || throw(ArgumentError("schema-1.0 assessment status is unknown"))
                expected =
                    assessment == "REPRESENTATION_COMPATIBLE" ? "COMPATIBLE" :
                    assessment == "REPRESENTATION_UNDETERMINED" ? "UNDETERMINED" : "INCOMPATIBLE"
                status == "NOT_EVALUATED" ||
                    status == expected ||
                    throw(ArgumentError("compatibility status contradicts assessment"))
                status == "COMPATIBLE" &&
                    gate != "GATE_VALID" &&
                    throw(ArgumentError("compatible result has an invalid gate"))
            end
        end
        begin
            for required_group in
                ("inventory", "qualification_scope", "raw_diagnostics", "compatibility_policy")
                haskey(handle, required_group) ||
                    throw(ArgumentError("schema-$(version) artifact is missing $(required_group)"))
            end
            _required_band_attribute(handle, "preparation_digest")
        end
        begin
            haskey(handle, "sewing_backend") ||
                throw(ArgumentError("schema-1.0 artifact is missing sewing_backend"))
            backend_metadata = _read_band_string_dictionary(handle["sewing_backend"])
            recorded = get(representation.conventions, "sewing_backend", "coefficient_mapping")
            get(backend_metadata, "sewing_backend", "") == recorded ||
                throw(ArgumentError("schema-1.0 sewing backend metadata contradicts conventions"))
        end
        begin
            haskey(handle, "wavefunction_gauge") ||
                throw(ArgumentError("schema-$(version) artifact is missing wavefunction_gauge"))
            gauge_metadata = _read_band_string_dictionary(handle["wavefunction_gauge"])
            recorded =
                get(representation.conventions, "wavefunction_gauge_backend", "native_eigenstate")
            get(gauge_metadata, "wavefunction_gauge_backend", "") == recorded || throw(
                ArgumentError(
                    "schema-$(version) wavefunction gauge metadata contradicts conventions",
                ),
            )
            recorded_sha =
                get(representation.conventions, "wavefunction_gauge_hdf5_sha256", "NOT_APPLICABLE")
            get(gauge_metadata, "wavefunction_gauge_hdf5_sha256", "") == recorded_sha || throw(
                ArgumentError(
                    "schema-$(version) wavefunction gauge artifact digest contradicts conventions",
                ),
            )
            if recorded == "star_covariant_paw"
                recorded_policy = get(representation.conventions, "block_partition_policy", "")
                isempty(recorded_policy) &&
                    throw(ArgumentError("modern artifact is missing block_partition_policy"))
                get(gauge_metadata, "block_partition_policy", "") == recorded_policy ||
                    throw(ArgumentError("block partition metadata contradicts conventions"))
                haskey(representation.input_sha256, "BLOCK_PARTITION_POLICY_SHA256") ||
                    throw(ArgumentError("modern artifact is missing block-policy input identity"))
                begin
                    recorded_correction =
                        get(representation.conventions, "discrete_hamiltonian_correction", "")
                    isempty(recorded_correction) && throw(
                        ArgumentError(
                            "schema-1.0 artifact is missing Hamiltonian correction identity",
                        ),
                    )
                    get(gauge_metadata, "discrete_hamiltonian_correction", "") ==
                    recorded_correction || throw(
                        ArgumentError("Hamiltonian correction metadata contradicts conventions"),
                    )
                    haskey(representation.input_sha256, "DISCRETE_HAMILTONIAN_CORRECTION_SHA256") ||
                        throw(
                            ArgumentError(
                                "schema-1.0 artifact is missing correction input identity",
                            ),
                        )
                    diagnostic = get(representation.conventions, "diagnostic_only", "false")
                    production = get(representation.conventions, "production_eligible", "true")
                    get(gauge_metadata, "diagnostic_only", "") == diagnostic || throw(
                        ArgumentError("diagnostic qualification metadata contradicts conventions"),
                    )
                    diagnostic == "true" &&
                        production != "false" &&
                        throw(
                            ArgumentError(
                                "DIAGNOSTIC_ONLY representation cannot be production eligible",
                            ),
                        )
                end
            end
            if get(representation.conventions, "qualification_scope", "full_parent") ==
               "target_subspace"
                for key in (
                    "authoritative_hamiltonian",
                    "authoritative_hamiltonian_sha256",
                    "qualification_scope",
                    "target_authority",
                    "parent_audit_policy",
                    "target_leakage_semantics",
                    "target_leakage_formula_sha256",
                    "target_leakage_threshold",
                )
                    value = get(representation.conventions, key, "")
                    isempty(value) && throw(ArgumentError("schema-1.0 artifact is missing $(key)"))
                    get(gauge_metadata, key, "") == value || throw(
                        ArgumentError(
                            "TARGET_SUBSPACE_CONTRACT_MISMATCH: schema-1.0 $(key) metadata differs",
                        ),
                    )
                end
                if haskey(representation.conventions, "target_subspace_contract_sha256")
                    get(gauge_metadata, "target_subspace_contract_sha256", "") ==
                    representation.conventions["target_subspace_contract_sha256"] || throw(
                        ArgumentError(
                            "TARGET_SUBSPACE_CONTRACT_MISMATCH: schema-1.0 target_subspace_contract_sha256 metadata differs",
                        ),
                    )
                end
                _band_validate_target_subspace_contract(representation.conventions)
                scope_group = handle["qualification_scope"]
                _require_band_axis_order(scope_group["outer_mask"], "band,kpoint")
                _require_band_axis_order(scope_group["frozen_mask"], "band,kpoint")
                outer_mask = Bool.(read(scope_group["outer_mask"]))
                frozen_mask = Bool.(read(scope_group["frozen_mask"]))
                size(outer_mask) == size(representation.energies_ev) == size(frozen_mask) || throw(
                    ArgumentError(
                        "TARGET_SUBSPACE_CONTRACT_MISMATCH: qualification-mask dimensions differ",
                    ),
                )
                all((.!frozen_mask) .| outer_mask) || throw(
                    ArgumentError(
                        "TARGET_SUBSPACE_CONTRACT_MISMATCH: frozen mask escapes outer mask",
                    ),
                )
                for (name, mask) in (("outer", outer_mask), ("frozen", frozen_mask))
                    stored = String(_required_band_attribute(scope_group, "$(name)_mask_sha256"))
                    stored == qualification_mask_sha256(mask) ||
                        throw(ArgumentError("schema-1.0 $(name)-mask SHA-256 mismatch"))
                end
            end
        end
        _read_band_representation_preparation_handle(handle, representation)
        return representation
    end
end

# Reconstruct and verify complete preparation metadata on an already open file.
# The main reader uses this helper; it never calls a public auxiliary reader.
function _read_band_representation_preparation_handle(handle, representation::BandRepresentation)
    _require_public_band_header(handle)
    _band_validate_public_representation_contract(representation)
    inventory_group = handle["inventory"]
    inventory_status = String(_required_band_attribute(inventory_group, "status"))
    inventory = if inventory_status == "AVAILABLE"
        uni_number = Int(_required_band_attribute(inventory_group, "uni_number"))
        MagneticSymmetryInventory(
            representation.operations,
            Bool(_required_band_attribute(inventory_group, "magnetic")),
            Int(_required_band_attribute(inventory_group, "msg_type")),
            iszero(uni_number) ? nothing : uni_number,
            Int(_required_band_attribute(inventory_group, "hall_number")),
            Float64(_required_band_attribute(inventory_group, "symmetry_tolerance")),
        )
    elseif inventory_status == "UNAVAILABLE"
        nothing
    else
        throw(ArgumentError("schema-1.4 inventory status is unknown"))
    end

    scope_group = handle["qualification_scope"]
    _require_band_axis_order(scope_group["outer_mask"], "band,kpoint")
    _require_band_axis_order(scope_group["frozen_mask"], "band,kpoint")
    qualification_scope = BandRepresentationQualificationScope(
        Bool.(read(scope_group["outer_mask"])),
        Bool.(read(scope_group["frozen_mask"]));
        outer_mask_sha256 = String(_required_band_attribute(scope_group, "outer_mask_sha256")),
        frozen_mask_sha256 = String(_required_band_attribute(scope_group, "frozen_mask_sha256")),
        diagnostic_status = Symbol(
            String(_required_band_attribute(scope_group, "diagnostic_status")),
        ),
    )
    qualification_scope.outer_mask_sha256 ==
    qualification_mask_sha256(qualification_scope.outer_mask) ||
        throw(ArgumentError("schema-1.4 outer-mask SHA-256 mismatch"))
    qualification_scope.frozen_mask_sha256 ==
    qualification_mask_sha256(qualification_scope.frozen_mask) ||
        throw(ArgumentError("schema-1.4 frozen-mask SHA-256 mismatch"))

    raw_group = handle["raw_diagnostics"]
    for name in ("integer_values", "real_values", "scope_code", "status_code")
        haskey(raw_group, name) ||
            throw(ArgumentError("public band preparation is missing raw_diagnostics/$(name)"))
    end
    integer_values = Int.(read(raw_group["integer_values"]))
    real_values = Float64.(read(raw_group["real_values"]))
    scope_codes = UInt8.(read(raw_group["scope_code"]))
    status_codes = UInt8.(read(raw_group["status_code"]))
    count = Int(_required_band_attribute(raw_group, "count"))
    size(integer_values) == (8, count) &&
    size(real_values) == (6, count) &&
    length(scope_codes) == count &&
    length(status_codes) == count ||
        throw(ArgumentError("schema-1.4 raw-diagnostic dimensions disagree"))
    scope_names = Dict(0x01 => :full, 0x02 => :outer, 0x03 => :frozen, 0x04 => :outside)
    status_names = Dict(0x01 => :REPORT_ONLY, 0x02 => :DIMENSION_MISMATCH, 0x03 => :EMPTY_SCOPE)
    raw_diagnostics = RepresentationRawDiagnostic[]
    for index in 1:count
        haskey(scope_names, scope_codes[index]) ||
            throw(ArgumentError("schema-1.4 raw diagnostic has an unknown scope code"))
        haskey(status_names, status_codes[index]) ||
            throw(ArgumentError("schema-1.4 raw diagnostic has an unknown status code"))
        push!(
            raw_diagnostics,
            RepresentationRawDiagnostic(
                scope_names[scope_codes[index]],
                integer_values[1, index],
                integer_values[2, index],
                integer_values[3, index],
                Bool(integer_values[4, index]),
                integer_values[5, index],
                integer_values[6, index],
                integer_values[7, index],
                integer_values[8, index],
                real_values[1, index],
                real_values[2, index],
                real_values[3, index],
                real_values[4, index],
                real_values[5, index],
                real_values[6, index],
                status_names[status_codes[index]],
            ),
        )
    end
    policy_group = handle["compatibility_policy"]
    requested_policy = Symbol(String(_required_band_attribute(policy_group, "requested")))
    effective_policy = Symbol(String(_required_band_attribute(policy_group, "effective")))
    tolerance_status =
        Symbol(String(_required_band_attribute(policy_group, "symmetry_tolerance_status")))
    stored_digest = String(_required_band_attribute(handle, "preparation_digest"))
    derived_digest = _band_preparation_metadata_digest(
        inventory,
        raw_diagnostics,
        qualification_scope.outer_mask_sha256,
        qualification_scope.frozen_mask_sha256,
        requested_policy,
        effective_policy,
        tolerance_status,
    )
    stored_digest == derived_digest ||
        throw(ArgumentError("schema-1.4 preparation digest mismatch"))
    return (
        inventory,
        raw_diagnostics,
        qualification_scope,
        requested_policy,
        effective_policy,
        symmetry_tolerance_status = tolerance_status,
        preparation_digest = stored_digest,
    )
end

"""Recover complete public schema-1.0 representation-preparation metadata."""
function read_band_representation_preparation_hdf5(
    filename::AbstractString,
    representation::BandRepresentation,
)
    read_band_representation_hdf5(filename)
    return HDF5.h5open(filename, "r") do handle
        _read_band_representation_preparation_handle(handle, representation)
    end
end

# Read public schema-1.0 qualification evidence for expert workflow preflight.
function _read_band_representation_qualification_hdf5(filename::AbstractString)
    # Validate the complete public payload before exposing any qualification evidence.
    read_band_representation_hdf5(filename)
    return HDF5.h5open(filename, "r") do handle
        _require_public_band_header(handle)
        compatibility = handle["compatibility"]
        profile = Symbol(String(_required_band_attribute(compatibility, "validation_profile")))
        qualification = String(_required_band_attribute(compatibility, "qualification_sha256"))
        excess = Float64.(read(compatibility["oracle_excess_group_law_residual"]))
        all(isfinite, excess) || return nothing
        isempty(qualification) && return nothing
        return (
            validation_profile = profile,
            qualification_sha256 = qualification,
            oracle_excess_group_law_residuals = (excess[1], excess[2], excess[3], excess[4]),
        )
    end
end

# Write a small deterministic JSON summary without placing arrays in JSON.
function write_band_representation_summary(
    filename::AbstractString,
    representation::BandRepresentation,
    validation::BandRepresentationValidation;
    overwrite::Bool,
)
    path = abspath(filename)
    ispath(path) && !overwrite && throw(ArgumentError("refusing to overwrite $(path)"))
    mkpath(dirname(path))
    payload = Dict(
        "schema" => "WannierNLQG.band_representation_summary",
        "schema_version" => "1.0",
        "passed" => validation.passed,
        "representation_sha256" => validation.representation_sha256,
        "input_sha256" => representation.input_sha256,
        "num_bands" => size(representation.energies_ev, 1),
        "num_kpoints" => size(representation.energies_ev, 2),
        "num_operations" => length(representation.operations),
        "mp_grid" => collect(representation.mp_grid),
        "maximum_group_law_residuals" => collect(validation.maximum_group_law_residuals),
        "maximum_reciprocal_shift_residual" => validation.maximum_reciprocal_shift_residual,
        "maximum_unitarity_residual" => validation.maximum_unitarity_residual,
        "maximum_theta_residual" => validation.maximum_theta_residual,
        "oracle_excess_group_law_residuals" =>
            validation.oracle_excess_group_law_residuals === nothing ? nothing :
            collect(something(validation.oracle_excess_group_law_residuals)),
        "oracle_sha256" => validation.oracle_sha256,
        "diagnostics" => validation.diagnostics,
    )
    temporary, io = mktemp(dirname(path); cleanup = false)
    completed = false
    try
        JSON3.pretty(io, payload)
        println(io)
        close(io)
        mv(temporary, path; force = true)
        completed = true
    finally
        isopen(io) && close(io)
        !completed && isfile(temporary) && rm(temporary; force = true)
    end
    return path
end

"""Generate, validate, and persist one native VASP band representation."""
function generate_vasp_band_representation(config::VASPBandRepresentationConfig)
    config.spin_channel > 0 || throw(ArgumentError("spin_channel must be positive"))
    config.representation_cutoff_ev > 0.0 ||
        throw(ArgumentError("representation_cutoff_ev must be positive"))
    config.degeneracy_tolerance_ev > 0.0 ||
        throw(ArgumentError("degeneracy_tolerance_ev must be positive"))
    config.symmetry_tolerance > 0.0 && isfinite(config.symmetry_tolerance) ||
        throw(ArgumentError("symmetry_tolerance must be positive and finite"))
    if config.magnetic_moments_cartesian !== nothing
        moments = something(config.magnetic_moments_cartesian)
        size(moments, 1) == 3 ||
            throw(ArgumentError("magnetic_moments_cartesian must have size (3, num_atoms)"))
        all(isfinite, moments) ||
            throw(ArgumentError("magnetic_moments_cartesian contains non-finite values"))
    end
    if config.qualification_window_ev !== nothing
        lower, upper = something(config.qualification_window_ev)
        isfinite(lower) && isfinite(upper) && lower < upper ||
            throw(ArgumentError("qualification_window_ev must be finite and increasing"))
    end
    source = VASPWavefunctionSource(
        config.poscar_file,
        config.wavecar_file;
        incar_file = config.incar_file,
        spin_basis_saxis = config.spin_basis_saxis,
        band_range = config.band_range,
        spin_channel = config.spin_channel,
        spinor = config.spinor,
        representation_cutoff_ev = config.representation_cutoff_ev,
        include_time_reversal = config.include_time_reversal,
        magnetic_moments_cartesian = config.magnetic_moments_cartesian,
    )
    native = read_vasp_wavefunctions(source)
    config.magnetic_moments_cartesian === nothing ||
        size(something(config.magnetic_moments_cartesian), 2) ==
        size(native.structure.positions_fractional, 2) ||
        throw(ArgumentError("magnetic_moments_cartesian atom count disagrees with POSCAR"))
    eig = read_wannier_eig(config.eig_file)
    eig.num_bands == size(first(native.kpoints).coefficients, 1) ||
        throw(ArgumentError("EIG and selected WAVECAR band counts disagree"))
    eig.num_kpts == length(native.kpoints) ||
        throw(ArgumentError("EIG and WAVECAR k-point counts disagree"))
    inventory = detect_magnetic_symmetry_inventory(
        native.structure;
        include_time_reversal = config.include_time_reversal,
        symmetry_tolerance = config.symmetry_tolerance,
    )
    diagnostic_outer_masks, diagnostic_frozen_masks = _vasp_representation_qualification_masks(
        eig.data,
        config.degeneracy_tolerance_ev,
        config.qualification_window_ev,
    )
    built = _build_band_representation(
        native,
        eig.data,
        inventory.operations,
        config.degeneracy_tolerance_ev;
        symmetry_inventory = inventory,
        diagnostic_outer_masks,
        diagnostic_frozen_masks,
        return_diagnostics = true,
    )
    representation = built.representation
    representation.input_sha256["EIG"] = _band_source_sha256_file(config.eig_file)
    configure_band_qualification_window!(representation, config.qualification_window_ev)
    validation = validate_band_representation(
        representation;
        absolute_tolerance = config.absolute_group_tolerance,
        oracle_excess_tolerance = config.oracle_excess_tolerance,
        oracle_hdf5_file = config.oracle_hdf5_file,
        require_oracle = config.require_oracle,
    )
    output_hdf5 = write_band_representation_hdf5(
        config.output_hdf5_file,
        representation;
        validation,
        overwrite = config.overwrite,
        inventory,
        qualification_outer_mask = BitMatrix(hcat(diagnostic_outer_masks...)),
        qualification_frozen_mask = BitMatrix(hcat(diagnostic_frozen_masks...)),
        raw_diagnostics = built.construction_diagnostics,
        requested_policy = :strict,
        effective_policy = :strict,
        symmetry_tolerance_status = :APPLIED,
    )
    output_json =
        config.output_json_file === nothing ? nothing :
        write_band_representation_summary(
            something(config.output_json_file),
            representation,
            validation;
            overwrite = config.overwrite,
        )
    return (representation, validation, output_hdf5, output_json)
end
