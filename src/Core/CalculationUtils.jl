"""
Return Fermi occupations for energies and chemical potential in eV, temperature in K.

At zero temperature the Fermi-level state is occupied. Clamp exponential arguments to avoid overflow; input arrays are not modified.
"""
function fermi_dirac(energies::AbstractArray{<:Real}, fermi_energy::Real, temperature::Real)
    thermal_energy = BOLTZMANN_CONSTANT_EV_K * temperature
    if thermal_energy == 0
        return 1.0 * (energies .<= fermi_energy)
    end

    argument = clamp.((energies .- fermi_energy) / thermal_energy, -700.0, 700.0)
    return 1.0 ./ (exp.(argument) .+ 1)
end

"""
Write Fermi occupations into `output` and return it; energies and chemical potential are in eV and temperature in K.

Require identical input/output axes (`DimensionMismatch` otherwise). At zero temperature equality to the chemical potential gives occupation one.
"""
function fermi_dirac!(
    output::AbstractArray{Float64},
    energies::AbstractArray{<:Real},
    fermi_energy::Real,
    temperature::Real,
)
    axes(output) == axes(energies) || throw(
        DimensionMismatch(
            "fermi_dirac! output axes $(axes(output)) do not match energy axes $(axes(energies)).",
        ),
    )
    thermal_energy = BOLTZMANN_CONSTANT_EV_K * temperature
    if thermal_energy == 0
        @inbounds for index in eachindex(output, energies)
            output[index] = energies[index] <= fermi_energy ? 1.0 : 0.0
        end
        return output
    end

    @inbounds for index in eachindex(output, energies)
        argument = clamp((energies[index] - fermi_energy) / thermal_energy, -700.0, 700.0)
        output[index] = 1.0 / (exp(argument) + 1)
    end
    return output
end

"""
Return `exp(-(x/width)^2)/(sqrt(pi)*width)` inside the exponent cutoff of 100, zero outside.

`x` and positive `width` must use the same energy unit; the result has inverse-energy units. Width validity is the caller's responsibility.
"""
function gaussian_broadening(x::AbstractArray{<:Real}, width::Real)
    inds = abs.(x) .< width * sqrt(200.0)
    output = zeros(size(x))
    output[inds] .= 1.0 / (sqrt(pi) * width) .* exp.(-(x[inds] / width) .^ 2)
    return output
end

"""
Return the normalized Lorentzian `width/(pi*(x^2+width^2))` elementwise.

`x` and positive `width` use the same energy unit; output has inverse-energy units. This helper does not validate the width.
"""
lorentzian_broadening(x::AbstractArray{<:Real}, width::Real) = (width / pi) ./ (x .^ 2 .+ width^2)

"""
Return inclusive band bounds and an availability flag around the Fermi level in sorted eigenvalues.

`-1` or an oversized window selects all orbitals; an absent valence/conduction boundary returns `(1,0,false)`. Energies and Fermi level share one unit.
"""
function select_band_window(
    eigenvalues::AbstractVector{<:Real},
    fermi_energy::Real,
    band_window_size::Integer,
    num_orbitals::Integer,
)
    if band_window_size == -1 || 2 * band_window_size > num_orbitals
        return 1, num_orbitals, true
    end

    valence_band_index = searchsortedlast(eigenvalues, fermi_energy)
    if valence_band_index < 1 || valence_band_index >= num_orbitals
        return 1, 0, false
    end

    band_start = max(1, valence_band_index - band_window_size + 1)
    band_end = min(num_orbitals, valence_band_index + band_window_size)
    return band_start, band_end, true
end

"""
Test whether an occupied-to-empty band pair overlaps any requested photon energy within `transition_window_factor*broadening`.

Energies and broadening share one unit; occupations differ by more than `1e-10`. A nonpositive window disables the energy screen. The scalar overload tests one photon energy; `transition_sign` fixes the ordered energy difference.
"""
function has_active_transition(
    eigenvalues::AbstractVector{<:Real},
    occupations::AbstractVector{<:Real},
    photon_energies::AbstractVector{<:Real},
    broadening::Real,
    transition_window_factor::Real,
    band_start::Integer,
    band_end::Integer;
    transition_sign::Real = -1.0,
)
    threshold = transition_window_factor * broadening
    @inbounds for n in band_start:band_end
        for m in band_start:band_end
            occupation_difference = occupations[n] - occupations[m]
            if abs(occupation_difference) <= 1e-10
                continue
            end
            transition_energy = transition_sign * (eigenvalues[n] - eigenvalues[m])
            if threshold <= 0
                return true
            end
            for photon_energy in photon_energies
                if abs(transition_energy - photon_energy) < threshold
                    return true
                end
            end
        end
    end
    return false
end

# Test whether an occupied-to-empty band pair overlaps any requested photon energy within `transition_window_factor*broadening`.
#
# Energies and broadening share one unit; occupations differ by more than `1e-10`. A nonpositive window disables the energy screen. The scalar overload tests one photon energy; `transition_sign` fixes the ordered energy difference.
function has_active_transition(
    eigenvalues::AbstractVector{<:Real},
    occupations::AbstractVector{<:Real},
    photon_energy::Real,
    broadening::Real,
    transition_window_factor::Real,
    band_start::Integer,
    band_end::Integer;
    transition_sign::Real = -1.0,
)
    threshold = transition_window_factor * broadening
    @inbounds for n in band_start:band_end
        for m in band_start:band_end
            occupation_difference = occupations[n] - occupations[m]
            if abs(occupation_difference) <= 1e-10
                continue
            end
            transition_energy = transition_sign * (eigenvalues[n] - eigenvalues[m])
            if threshold <= 0 || abs(transition_energy - photon_energy) < threshold
                return true
            end
        end
    end
    return false
end

"""
Validate positive two-dimensional mesh counts, three-component slice vectors, and Cartesian tensor indices; return active mesh axes `[1,2]`.

Invalid shapes or index bounds raise an error. Axis limits may be uniform (`spatial_dimension`) or supplied separately for each tensor index.
"""
function validate_kslice_input(
    k_mesh::Vector{Int},
    kslice_origin::Vector{Float64},
    kslice_vector_1::Vector{Float64},
    kslice_vector_2::Vector{Float64},
    tensor_indices::Vector{Int},
    spatial_dimension::Int64,
)
    if length(k_mesh) != 2
        error("Invalid k_mesh=$(k_mesh); expected two entries (nk1,nk2)")
    end
    if any(n -> n <= 0, k_mesh)
        error("Invalid k_mesh=$(k_mesh); all entries must be positive")
    end
    if length(kslice_origin) != 3 || length(kslice_vector_1) != 3 || length(kslice_vector_2) != 3
        error("kslice_origin, kslice_vector_1, and kslice_vector_2 must each have length 3")
    end
    if isempty(tensor_indices) || any(i -> i < 1 || i > spatial_dimension, tensor_indices)
        error(
            "Invalid tensor_indices=$(tensor_indices); expected Cartesian indices in 1:$(spatial_dimension)",
        )
    end
    return Int[1, 2]
end

# Validate positive two-dimensional mesh counts, three-component slice vectors, and Cartesian tensor indices; return active mesh axes `[1,2]`.
#
# Invalid shapes or index bounds raise an error. Axis limits may be uniform (`spatial_dimension`) or supplied separately for each tensor index.
function validate_kslice_input(
    k_mesh::Vector{Int},
    kslice_origin::Vector{Float64},
    kslice_vector_1::Vector{Float64},
    kslice_vector_2::Vector{Float64},
    tensor_indices::Vector{Int},
    axis_limits::Vector{Int},
)
    active_axes =
        validate_kslice_input(k_mesh, kslice_origin, kslice_vector_1, kslice_vector_2, Int[1], 3)
    length(tensor_indices) == length(axis_limits) ||
        error("Invalid tensor_indices=$(tensor_indices); expected $(length(axis_limits)) indices.")
    for (axis, (index, limit)) in enumerate(zip(tensor_indices, axis_limits))
        1 <= index <= limit ||
            error("Invalid tensor_indices=$(tensor_indices); axis $(axis) must be in 1:$(limit).")
    end
    return active_axes
end

# Copy an integer tuple, vector, or range into an `Int` vector; reject noninteger collections with the supplied label.
function _index_collection_to_vector(value, label::AbstractString)
    if value isa AbstractVector{<:Integer} || value isa AbstractRange{<:Integer}
        return Int[Int(i) for i in value]
    elseif value isa Tuple && all(i -> i isa Integer, value)
        return Int[Int(i) for i in value]
    end
    error("Invalid $(label)=$(value); expected a tuple or vector of integer Cartesian indices.")
end

"""
Copy Cartesian indices into an `Int` vector, rejecting an incorrect rank or out-of-range axis.

Bounds are either uniform in `1:spatial_dimension` or supplied per tensor axis; no input collection is modified.
"""
function normalize_cartesian_indices(
    value,
    expected_rank::Int,
    spatial_dimension::Int,
    label::AbstractString,
)
    indices = _index_collection_to_vector(value, label)
    if length(indices) != expected_rank
        error(
            "Invalid $(label)=$(value); expected $(expected_rank) Cartesian indices in 1:$(spatial_dimension).",
        )
    end
    if any(i -> i < 1 || i > spatial_dimension, indices)
        error("Invalid $(label)=$(value); expected Cartesian indices in 1:$(spatial_dimension).")
    end
    return indices
end

# Copy Cartesian indices into an `Int` vector, rejecting an incorrect rank or out-of-range axis.
#
# Bounds are either uniform in `1:spatial_dimension` or supplied per tensor axis; no input collection is modified.
function normalize_cartesian_indices(
    value,
    axis_limits::AbstractVector{<:Integer},
    label::AbstractString,
)
    indices = _index_collection_to_vector(value, label)
    length(indices) == length(axis_limits) || error(
        "Invalid $(label)=$(value); expected $(length(axis_limits)) Cartesian indices with axis limits $(Tuple(axis_limits)).",
    )
    for (axis, (index, limit)) in enumerate(zip(indices, axis_limits))
        1 <= index <= limit ||
            error("Invalid $(label)=$(value); axis $(axis) must be in 1:$(limit).")
    end
    return indices
end

"""
Dimensions of a fractional reciprocal-space integration grid, with an optional fixed zero third coordinate.

Linear indexing advances the first reciprocal axis fastest; positive dimensions are required by the grid-building caller.
"""
struct IntegralKGrid
    num_k1_points::Int
    num_k2_points::Int
    num_k3_points::Int
    third_dimension_fixed_at_zero::Bool
end

# Return the number of logical k points represented by the grid's sample counts.
Base.length(grid::IntegralKGrid) = grid.num_k1_points * grid.num_k2_points * grid.num_k3_points

"""
Write the indexed fractional reciprocal point into the three-element `dest` and return it.

The first mesh axis varies fastest; invalid linear indices raise `BoundsError`. No Brillouin-zone weights are applied.
"""
function integral_kpoint!(dest::Vector{Float64}, grid::IntegralKGrid, kpoint_index::Int)
    @boundscheck 1 <= kpoint_index <= length(grid) || throw(BoundsError(grid, kpoint_index))
    ik0 = kpoint_index - 1
    ik1 = ik0 % grid.num_k1_points
    ik2 = (ik0 ÷ grid.num_k1_points) % grid.num_k2_points
    ik3 = ik0 ÷ (grid.num_k1_points * grid.num_k2_points)
    @inbounds begin
        dest[1] = ik1 / grid.num_k1_points
        dest[2] = ik2 / grid.num_k2_points
        dest[3] = grid.third_dimension_fixed_at_zero ? 0.0 : ik3 / grid.num_k3_points
    end
    return dest
end

"""
Sample counts, fractional reciprocal origin, and two spanning vectors for a half-open planar k mesh.

The u coordinate varies fastest and both sampling coordinates exclude their upper endpoint.
"""
struct KSliceGrid2D
    num_u_points::Int
    num_v_points::Int
    origin::Vector{Float64}
    vector_1::Vector{Float64}
    vector_2::Vector{Float64}
end

# Return the number of logical k points represented by the grid's sample counts.
Base.length(grid::KSliceGrid2D) = grid.num_u_points * grid.num_v_points

"""
Return one-based `(u_index,v_index)` for a linear slice index with u varying fastest.

Reject indices outside `1:length(grid)` with `BoundsError`.
"""
function kslice_indices(grid::KSliceGrid2D, kpoint_index::Int)
    @boundscheck 1 <= kpoint_index <= length(grid) || throw(BoundsError(grid, kpoint_index))
    ik0 = kpoint_index - 1
    u_index = ik0 % grid.num_u_points + 1
    v_index = ik0 ÷ grid.num_u_points + 1
    return u_index, v_index
end

"""
Fill `dest` with `origin + u*vector_1 + v*vector_2` in fractional reciprocal coordinates; return `(dest,u_index,v_index)`.

The mesh samples `[0,1)` on each axis and validates the linear point index.
"""
function kslice_kpoint!(dest::Vector{Float64}, grid::KSliceGrid2D, kpoint_index::Int)
    u_index, v_index = kslice_indices(grid, kpoint_index)
    u = (u_index - 1) / grid.num_u_points
    v = (v_index - 1) / grid.num_v_points
    @inbounds for a in 1:3
        dest[a] = grid.origin[a] + u * grid.vector_1[a] + v * grid.vector_2[a]
    end
    return dest, u_index, v_index
end

"""
Copy slice vectors into a `KSliceGrid2D`; return the grid and its two active mesh counts.

Inputs must already satisfy `validate_kslice_input`; geometry is in fractional reciprocal coordinates and input vectors remain unmodified.
"""
function make_kslice_grid(
    k_mesh::Vector{Int},
    active_axes::Vector{Int},
    kslice_origin::Vector{Float64},
    kslice_vector_1::Vector{Float64},
    kslice_vector_2::Vector{Float64},
)
    num_u_points = k_mesh[active_axes[1]]
    num_v_points = k_mesh[active_axes[2]]
    return KSliceGrid2D(
        num_u_points,
        num_v_points,
        copy(kslice_origin),
        copy(kslice_vector_1),
        copy(kslice_vector_2),
    ),
    num_u_points,
    num_v_points
end

"""
Materialize independent fractional reciprocal point vectors and one-based `(u,v)` coordinates from a validated slice mesh.

Return `(points,coordinates,num_u_points,num_v_points)` in u-fastest order; no integration weights are included.
"""
function make_kslice_points(
    k_mesh::Vector{Int},
    active_axes::Vector{Int},
    kslice_origin::Vector{Float64},
    kslice_vector_1::Vector{Float64},
    kslice_vector_2::Vector{Float64},
)
    grid, num_u_points, num_v_points =
        make_kslice_grid(k_mesh, active_axes, kslice_origin, kslice_vector_1, kslice_vector_2)
    num_kpoints = length(grid)
    k_list = Vector{Vector{Float64}}(undef, num_kpoints)
    k_coords = Vector{Tuple{Int64, Int64}}(undef, num_kpoints)
    kpoint = zeros(Float64, 3)

    for kpoint_index in 1:num_kpoints
        kslice_kpoint!(kpoint, grid, kpoint_index)
        k_list[kpoint_index] = copy(kpoint)
        k_coords[kpoint_index] = kslice_indices(grid, kpoint_index)
    end
    return k_list, k_coords, num_u_points, num_v_points
end

# Copy a singleton integer or integer vector/range into a band group; reject unsupported group syntax.
function _band_group_to_vector(group, group_name::AbstractString)
    if group isa Integer
        return Int[Int(group)]
    elseif group isa AbstractVector{<:Integer} || group isa AbstractRange{<:Integer}
        return Int[Int(i) for i in group]
    end
    error(
        "Invalid $(group_name) band group=$(group); expected an integer singleton or an integer vector/range subspace inside a tuple band_selection.",
    )
end

# Reject bare integer vectors/ranges at the selection boundary and explain the required outer tuple syntax.
function _top_level_tuple_band_selection_error(
    quantity_name::AbstractString,
    band_selection,
    examples::AbstractString,
)
    if band_selection isa AbstractVector{<:Integer} || band_selection isa AbstractRange{<:Integer}
        error(
            "Invalid $(quantity_name) band_selection=$(band_selection); bare vectors/ranges are no longer supported. Use tuple syntax such as $(examples). For a one-subspace target use the Julia one-tuple form, for example ([19,20],).",
        )
    end
    return nothing
end

"""
Return copied `(conduction,valence)` integer groups from a two-entry tuple.

Accept singleton indices or vector/range subspaces within the tuple; reject other outer shapes. Band bounds and duplicate indices are checked separately.
"""
function normalize_band_selection(band_selection)
    _top_level_tuple_band_selection_error(
        "response_kernel pair",
        band_selection,
        "(21,20) or ([21,22],[19,20])",
    )
    if !(band_selection isa Tuple) || length(band_selection) != 2
        error(
            "Invalid band_selection=$(band_selection); expected tuple syntax such as (21,20) or ([21,22],[19,20]).",
        )
    end
    conduction = _band_group_to_vector(band_selection[1], "conduction")
    valence = _band_group_to_vector(band_selection[2], "valence")
    return (conduction, valence)
end

"""
Concatenate conduction then valence band indices into a new vector, preserving their input order and repetitions.
"""
function band_selection_flattened(band_selection::Tuple{Vector{Int}, Vector{Int}})
    conduction, valence = band_selection
    return vcat(conduction, valence)
end

"""
Return the minimum and maximum index across both nonempty band groups.

The interval may contain bands outside the explicitly selected groups; empty selections are not supported.
"""
function band_selection_window(band_selection::Tuple{Vector{Int}, Vector{Int}})
    flat = band_selection_flattened(band_selection)
    return minimum(flat), maximum(flat)
end

"""
Validate nonempty conduction/valence groups with unique indices in `1:num_orbitals`; return the validated selection.

The general overload first normalizes tuple syntax. Overlap between the two groups is allowed here and rejected by the interband validator when required.
"""
function validate_band_selection(
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    num_orbitals::Int64,
)
    conduction, valence = band_selection
    if isempty(conduction) || isempty(valence)
        error("Invalid band_selection=$(band_selection); band groups must be non-empty.")
    end
    if length(unique(conduction)) != length(conduction)
        error(
            "Invalid band_selection=$(band_selection); conduction band group contains duplicate indices.",
        )
    end
    if length(unique(valence)) != length(valence)
        error(
            "Invalid band_selection=$(band_selection); valence band group contains duplicate indices.",
        )
    end
    flat = band_selection_flattened(band_selection)
    if any(i -> i < 1 || i > num_orbitals, flat)
        error(
            "Invalid band_selection=$(band_selection); expected band indices in 1:$(num_orbitals)",
        )
    end
    return band_selection
end

# Validate nonempty conduction/valence groups with unique indices in `1:num_orbitals`; return the validated selection.
#
# The general overload first normalizes tuple syntax. Overlap between the two groups is allowed here and rejected by the interband validator when required.
function validate_band_selection(band_selection, num_orbitals::Int64)
    normalized = normalize_band_selection(band_selection)
    validate_band_selection(normalized, num_orbitals)
    return normalized
end

"""
Return validated conduction/valence groups only if their index sets are disjoint.

Enforce nonempty groups, unique indices and orbital bounds; normalize external tuple syntax in the general overload.
"""
function validate_interband_band_selection(
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    num_orbitals::Int64,
)
    validate_band_selection(band_selection, num_orbitals)
    first_group, second_group = band_selection
    overlap = intersect(first_group, second_group)
    if !isempty(overlap)
        error(
            "Invalid interband band_selection=$(band_selection); band groups must not overlap, got overlap=$(overlap).",
        )
    end
    return band_selection
end

# Return validated conduction/valence groups only if their index sets are disjoint.
#
# Enforce nonempty groups, unique indices and orbital bounds; normalize external tuple syntax in the general overload.
function validate_interband_band_selection(band_selection, num_orbitals::Int64)
    normalized = normalize_band_selection(band_selection)
    return validate_interband_band_selection(normalized, num_orbitals)
end

"""
Copy three ordered band groups from a three-entry tuple for the cyclic phase product.

Reject other outer shapes; pairwise disjointness and orbital bounds belong to the corresponding validator.
"""
function normalize_triple_phase_product_band_selection(band_selection)
    _top_level_tuple_band_selection_error(
        "Triple_Phase_Product",
        band_selection,
        "(21,23,19) or ([21,22],[23,24],[19,20])",
    )
    if !(band_selection isa Tuple) || length(band_selection) != 3
        error(
            "Invalid Triple_Phase_Product band_selection=$(band_selection); expected three groups in tuple syntax such as (21,23,19) or ([21,22],[23,24],[19,20]).",
        )
    end
    first_group = _band_group_to_vector(band_selection[1], "first")
    second_group = _band_group_to_vector(band_selection[2], "second")
    third_group = _band_group_to_vector(band_selection[3], "third")
    return (first_group, second_group, third_group)
end

"""
Concatenate the three cyclic band groups into a fresh vector without sorting or deduplication.
"""
function triple_phase_product_band_selection_flattened(
    band_selection::Tuple{Vector{Int}, Vector{Int}, Vector{Int}},
)
    first_group, second_group, third_group = band_selection
    return vcat(first_group, second_group, third_group)
end

"""
Validate three nonempty, internally unique, pairwise disjoint groups within `1:num_orbitals`; return the selection.

The general overload normalizes the outer tuple first; invalid syntax, overlap or bounds raise an error.
"""
function validate_triple_phase_product_band_selection(
    band_selection::Tuple{Vector{Int}, Vector{Int}, Vector{Int}},
    num_orbitals::Int64,
)
    first_group, second_group, third_group = band_selection
    groups = (first_group, second_group, third_group)
    labels = ("first", "second", "third")
    for (label, group) in zip(labels, groups)
        isempty(group) && error(
            "Invalid Triple_Phase_Product band_selection=$(band_selection); $(label) band group must be non-empty.",
        )
        length(unique(group)) == length(group) || error(
            "Invalid Triple_Phase_Product band_selection=$(band_selection); $(label) band group contains duplicate indices.",
        )
    end
    flat = triple_phase_product_band_selection_flattened(band_selection)
    if any(i -> i < 1 || i > num_orbitals, flat)
        error(
            "Invalid Triple_Phase_Product band_selection=$(band_selection); expected band indices in 1:$(num_orbitals).",
        )
    end
    for i in 1:2
        for j in (i + 1):3
            overlap = intersect(groups[i], groups[j])
            if !isempty(overlap)
                error(
                    "Invalid Triple_Phase_Product band_selection=$(band_selection); band groups must be pairwise disjoint, got overlap=$(overlap).",
                )
            end
        end
    end
    return band_selection
end

# Validate three nonempty, internally unique, pairwise disjoint groups within `1:num_orbitals`; return the selection.
#
# The general overload normalizes the outer tuple first; invalid syntax, overlap or bounds raise an error.
function validate_triple_phase_product_band_selection(band_selection, num_orbitals::Int64)
    normalized = normalize_triple_phase_product_band_selection(band_selection)
    return validate_triple_phase_product_band_selection(normalized, num_orbitals)
end

"""
Extract a copied integer target group from a one-entry tuple; reject all other outer shapes.

A singleton band is written `(n,)`, and a subspace is written `([n,m],)`; bounds are validated separately.
"""
function normalize_target_band_group(band_selection, quantity_name::AbstractString)
    _top_level_tuple_band_selection_error(quantity_name, band_selection, "(19,) or ([19,20],)")
    if !(band_selection isa Tuple) || length(band_selection) != 1
        error(
            "Invalid $(quantity_name) band_selection=$(band_selection); expected one target group tuple such as (19,) or ([19,20],).",
        )
    end
    return _band_group_to_vector(band_selection[1], "target")
end

"""
Copy each singleton or subspace in a nonempty tuple into a vector of integer groups.

Preserve user order; reject bare vectors/ranges and unsupported group types before bounds validation.
"""
function normalize_target_band_groups(band_selection, quantity_name::AbstractString)
    _top_level_tuple_band_selection_error(quantity_name, band_selection, "(19,20) or ([19,20],)")
    if !(band_selection isa Tuple) || isempty(band_selection)
        error(
            "Invalid $(quantity_name) band_selection=$(band_selection); expected target group tuple syntax such as (19,20) or ([19,20],).",
        )
    end
    return [_band_group_to_vector(group, "target") for group in band_selection]
end

"""
Return a nonempty target group after rejecting duplicate or out-of-range one-based band indices.

`quantity_name` identifies the failing input; the group is not reordered or copied.
"""
function validate_target_band_group(
    band_selection::Vector{Int},
    num_orbitals::Int64,
    quantity_name::AbstractString,
)
    isempty(band_selection) && error(
        "Invalid $(quantity_name) band_selection=$(band_selection); target band group must be non-empty.",
    )
    length(unique(band_selection)) == length(band_selection) || error(
        "Invalid $(quantity_name) band_selection=$(band_selection); target band group contains duplicate indices.",
    )
    if any(i -> i < 1 || i > num_orbitals, band_selection)
        error(
            "Invalid $(quantity_name) band_selection=$(band_selection); expected band indices in 1:$(num_orbitals).",
        )
    end
    return band_selection
end

"""
Validate each target group and reject repeated band indices across groups; return the input groups.

Require at least one group and valid one-based bounds in `1:num_orbitals`.
"""
function validate_target_band_groups(
    band_groups::Vector{Vector{Int}},
    num_orbitals::Int64,
    quantity_name::AbstractString,
)
    isempty(band_groups) && error(
        "Invalid $(quantity_name) band_selection=$(band_groups); at least one target group is required.",
    )
    for group in band_groups
        validate_target_band_group(group, num_orbitals, quantity_name)
    end
    flat = reduce(vcat, band_groups; init = Int[])
    length(unique(flat)) == length(flat) || error(
        "Invalid $(quantity_name) band_selection=$(band_groups); target groups must not repeat band indices.",
    )
    return band_groups
end

"""
Return the integer band label for a singleton or `subspace_` followed by ordered indices for a multiband group.

Empty groups raise an error; this label does not change the group's numerical meaning.
"""
function band_group_output_label(group::Vector{Int})
    isempty(group) && error("Cannot build an output label for an empty band group.")
    if length(group) == 1
        return group[1]
    end
    return "subspace_" * join(group, "_")
end

"""
Return true only for a nonempty list consisting entirely of singleton groups, enabling the additional summed output.
"""
real_kslice_band_groups_include_sum(band_groups::Vector{Vector{Int}}) =
    !isempty(band_groups) && all(group -> length(group) == 1, band_groups)

"""
Copy the quantum Christoffel symbol target groups using the nonempty outer-tuple selection contract.

Singletons and integer subspaces preserve user order; invalid syntax raises a quantity-specific error.
"""
normalize_quantum_christoffel_band_selection(band_selection) =
    normalize_target_band_groups(band_selection, "Quantum_Christoffel_Symbol")

"""
Return quantum Christoffel symbol target groups after rejecting empty groups, repeated indices and bounds outside `1:num_orbitals`.

The general overload first normalizes tuple syntax; existing integer groups are not reordered.
"""
validate_quantum_christoffel_band_selection(
    band_selection::Vector{Vector{Int}},
    num_orbitals::Int64,
) = validate_target_band_groups(band_selection, num_orbitals, "Quantum_Christoffel_Symbol")

# Return quantum Christoffel symbol target groups after rejecting empty groups, repeated indices and bounds outside `1:num_orbitals`.
#
# The general overload first normalizes tuple syntax; existing integer groups are not reordered.
function validate_quantum_christoffel_band_selection(band_selection, num_orbitals::Int64)
    normalized = normalize_quantum_christoffel_band_selection(band_selection)
    return validate_quantum_christoffel_band_selection(normalized, num_orbitals)
end

"""
Copy the quantum metric dipole target groups using the nonempty outer-tuple selection contract.

Singletons and integer subspaces preserve user order; invalid syntax raises a quantity-specific error.
"""
normalize_quantum_metric_dipole_band_selection(band_selection) =
    normalize_target_band_groups(band_selection, "Quantum_Metric_Dipole")

"""
Return quantum metric dipole target groups after rejecting empty groups, repeated indices and bounds outside `1:num_orbitals`.

The general overload first normalizes tuple syntax; existing integer groups are not reordered.
"""
validate_quantum_metric_dipole_band_selection(
    band_selection::Vector{Vector{Int}},
    num_orbitals::Int64,
) = validate_target_band_groups(band_selection, num_orbitals, "Quantum_Metric_Dipole")

# Return quantum metric dipole target groups after rejecting empty groups, repeated indices and bounds outside `1:num_orbitals`.
#
# The general overload first normalizes tuple syntax; existing integer groups are not reordered.
function validate_quantum_metric_dipole_band_selection(band_selection, num_orbitals::Int64)
    normalized = normalize_quantum_metric_dipole_band_selection(band_selection)
    return validate_quantum_metric_dipole_band_selection(normalized, num_orbitals)
end

"""
Copy the quantum metric quadrupole target groups using the nonempty outer-tuple selection contract.

Singletons and integer subspaces preserve user order; invalid syntax raises a quantity-specific error.
"""
normalize_quantum_metric_quadrupole_band_selection(band_selection) =
    normalize_target_band_groups(band_selection, "Quantum_Metric_Quadrupole")

"""
Return quantum metric quadrupole target groups after rejecting empty groups, repeated indices and bounds outside `1:num_orbitals`.

The general overload first normalizes tuple syntax; existing integer groups are not reordered.
"""
validate_quantum_metric_quadrupole_band_selection(
    band_selection::Vector{Vector{Int}},
    num_orbitals::Int64,
) = validate_target_band_groups(band_selection, num_orbitals, "Quantum_Metric_Quadrupole")

# Return quantum metric quadrupole target groups after rejecting empty groups, repeated indices and bounds outside `1:num_orbitals`.
#
# The general overload first normalizes tuple syntax; existing integer groups are not reordered.
function validate_quantum_metric_quadrupole_band_selection(band_selection, num_orbitals::Int64)
    normalized = normalize_quantum_metric_quadrupole_band_selection(band_selection)
    return validate_quantum_metric_quadrupole_band_selection(normalized, num_orbitals)
end

"""
Copy the Berry curvature dipole target groups using the nonempty outer-tuple selection contract.

Singletons and integer subspaces preserve user order; invalid syntax raises a quantity-specific error.
"""
normalize_berry_curvature_dipole_band_selection(band_selection) =
    normalize_target_band_groups(band_selection, "Berry_Curvature_Dipole")

"""
Return Berry curvature dipole target groups after rejecting empty groups, repeated indices and bounds outside `1:num_orbitals`.

The general overload first normalizes tuple syntax; existing integer groups are not reordered.
"""
validate_berry_curvature_dipole_band_selection(
    band_selection::Vector{Vector{Int}},
    num_orbitals::Int64,
) = validate_target_band_groups(band_selection, num_orbitals, "Berry_Curvature_Dipole")

# Return Berry curvature dipole target groups after rejecting empty groups, repeated indices and bounds outside `1:num_orbitals`.
#
# The general overload first normalizes tuple syntax; existing integer groups are not reordered.
function validate_berry_curvature_dipole_band_selection(band_selection, num_orbitals::Int64)
    normalized = normalize_berry_curvature_dipole_band_selection(band_selection)
    return validate_berry_curvature_dipole_band_selection(normalized, num_orbitals)
end

"""
Copy the Berry curvature quadrupole target groups using the nonempty outer-tuple selection contract.

Singletons and integer subspaces preserve user order; invalid syntax raises a quantity-specific error.
"""
normalize_berry_curvature_quadrupole_band_selection(band_selection) =
    normalize_target_band_groups(band_selection, "Berry_Curvature_Quadrupole")

"""
Return Berry curvature quadrupole target groups after rejecting empty groups, repeated indices and bounds outside `1:num_orbitals`.

The general overload first normalizes tuple syntax; existing integer groups are not reordered.
"""
validate_berry_curvature_quadrupole_band_selection(
    band_selection::Vector{Vector{Int}},
    num_orbitals::Int64,
) = validate_target_band_groups(band_selection, num_orbitals, "Berry_Curvature_Quadrupole")

# Return Berry curvature quadrupole target groups after rejecting empty groups, repeated indices and bounds outside `1:num_orbitals`.
#
# The general overload first normalizes tuple syntax; existing integer groups are not reordered.
function validate_berry_curvature_quadrupole_band_selection(band_selection, num_orbitals::Int64)
    normalized = normalize_berry_curvature_quadrupole_band_selection(band_selection)
    return validate_berry_curvature_quadrupole_band_selection(normalized, num_orbitals)
end

"""
Resolve real-valued slice selections: `-1` expands all singleton bands, `0` requests summation only, and tuples specify disjoint target groups.

Return copied integer groups and reject invalid sentinels, duplicates or orbital bounds.
"""
function normalize_real_kslice_band_selection(
    band_selection,
    num_orbitals::Int64,
    quantity_name::AbstractString,
)
    if band_selection isa Integer
        if band_selection == -1
            return [Int[i] for i in 1:num_orbitals]
        elseif band_selection == 0
            return Vector{Int}[]
        end
        error(
            "Invalid $(quantity_name) band_selection=$(band_selection); use -1 for all singleton bands, 0 for summation only, or tuple syntax such as (1,2) or ([1,2],).",
        )
    end
    _top_level_tuple_band_selection_error(quantity_name, band_selection, "(1,2) or ([1,2],)")
    if !(band_selection isa Tuple)
        error(
            "Invalid $(quantity_name) band_selection=$(band_selection); expected -1, 0, or tuple syntax such as (1,2) or ([1,2],).",
        )
    end
    band_groups = [_band_group_to_vector(group, "target") for group in band_selection]
    validate_target_band_groups(band_groups, num_orbitals, quantity_name)
    flat = reduce(vcat, band_groups; init = Int[])
    if length(unique(flat)) != length(flat)
        error(
            "Invalid $(quantity_name) band_selection=$(band_selection); target groups must not repeat band indices.",
        )
    end
    return band_groups
end

"""
Resolve Berry-curvature slice bands using the shared `-1` all-bands, `0` sum-only, or explicit tuple policy.

Return disjoint one-based groups; validation errors retain the Berry-curvature quantity label.
"""
normalize_berry_band_selection(band_selection, num_orbitals::Int64) =
    normalize_real_kslice_band_selection(band_selection, num_orbitals, "Berry_Curvature")

"""
Resolve quantum-metric slice bands using the shared `-1` all-bands, `0` sum-only, or explicit tuple policy.

Return disjoint one-based groups; validation errors retain the quantum-metric quantity label.
"""
normalize_quantum_metric_band_selection(band_selection, num_orbitals::Int64) =
    normalize_real_kslice_band_selection(band_selection, num_orbitals, "Quantum_Metric")
