const REAL_SPACE_REPLICA_MAP_REFERENCE_SCHEMA = "wanniernlqg.replica-map-publication/1"

"""One deterministic orbital-pair map from serialized R records to physical images."""
struct RealSpaceReplicaMap
    source::Symbol
    source_r_vectors::Matrix{Int}
    source_degeneracies::Vector{Int}
    target_r_vectors::Matrix{Int}
    images::Array{Vector{NTuple{3, Int}}, 3}
    mapping_reference::String
end

"""Marker for raw Wannier values that still carry scalar `N_R` weights."""
struct RawReplicaValues end

"""Marker for operators whose scalar `N_R` weights were divided before projection."""
struct PredividedReplicaValues end

"""Diagnostics and materialized operators from one shared real-space replica policy."""
struct RealSpaceReplicaPolicyResult
    policy::Symbol
    operators::Dict{RealSpaceOperatorKind, RealSpaceOperator}
    degeneracies::Vector{Int}
    original_num_r_vectors::Int
    output_num_r_vectors::Int
    total_assignment_count::Int
    changed_assignment_count::Int
    changed_pair_count::Int
    tied_assignment_count::Int
    pair_changed_counts::Matrix{Int}
    input_link_lengths_cartesian::Vector{Float64}
    output_link_lengths_cartesian::Vector{Float64}
    mapping_reference::String
    map::RealSpaceReplicaMap
end

"""Return the nonnegative Monkhorst-Pack residue of an integer real-space vector."""
function real_space_mp_residue(r_vector::AbstractVector{<:Integer}, mp_grid::NTuple{3, Int})
    return ntuple(direction -> mod(Int(r_vector[direction]), mp_grid[direction]), 3)
end

"""
Return every center-aware nearest supercell image of one MP residue.

The row-lattice displacement is `R + tau_right - tau_left`. Every image tied
within `tolerance` is retained so all real-space operators share one map.
"""
function nearest_wigner_seitz_images(
    residue::NTuple{3, Int},
    center_shift::AbstractVector{<:Real},
    lattice::AbstractMatrix{<:Real},
    mp_grid::NTuple{3, Int};
    tolerance::Real,
    search_size::Integer,
)
    isfinite(tolerance) && tolerance > 0.0 ||
        throw(ArgumentError("minimum-distance tolerance must be finite and positive"))
    search_size > 0 || throw(ArgumentError("minimum-distance search_size must be positive"))
    # Own only this invocation's displacement. Retain the original row-vector
    # multiplication and norm, including their rounding at tied-image boundaries.
    reuse =
        center_shift isa Vector{Float64} &&
        length(center_shift) == 3 &&
        lattice isa Matrix{Float64} &&
        size(lattice) == (3, 3)
    displacement = reuse ? Vector{Float64}(undef, 3) : nothing
    candidates = NTuple{3, Int}[]
    distances = Float64[]
    for i in (-search_size):search_size,
        j in (-search_size):search_size,
        k in (-search_size):search_size

        candidate =
            (residue[1] + i * mp_grid[1], residue[2] + j * mp_grid[2], residue[3] + k * mp_grid[3])
        push!(candidates, candidate)
        distance = if displacement === nothing
            norm((collect(candidate) .+ center_shift)' * lattice)
        else
            for axis in 1:3
                displacement[axis] = candidate[axis] + center_shift[axis]
            end
            norm(displacement' * lattice)
        end
        push!(distances, distance)
    end
    minimum_distance = minimum(distances)
    return [
        candidate for (candidate, distance) in zip(candidates, distances) if
        abs(distance - minimum_distance) <= tolerance
    ]
end

# Reuse search buffers across residues; retain the original candidate enumeration and norm.
function _nearest_wigner_seitz_images!(
    scratch,
    residue,
    center_shift,
    lattice,
    mp_grid;
    tolerance,
    search_size,
)
    candidates, distances, displacement, cartesian = scratch
    index = 0
    for i in (-search_size):search_size,
        j in (-search_size):search_size,
        k in (-search_size):search_size

        index += 1
        candidate =
            (residue[1] + i * mp_grid[1], residue[2] + j * mp_grid[2], residue[3] + k * mp_grid[3])
        candidates[index] = candidate
        for axis in 1:3
            displacement[axis] = candidate[axis] + center_shift[axis]
        end
        mul!(cartesian, transpose(lattice), displacement)
        distances[index] = norm(cartesian)
    end
    minimum_distance = minimum(distances)
    return [
        candidate for (candidate, distance) in zip(candidates, distances) if
        abs(distance - minimum_distance) <= tolerance
    ]
end

# Measure one center-aware real-space link in Cartesian coordinates.
function _replica_link_length(
    r_vector::NTuple{3, Int},
    center_shift_fractional::AbstractVector{<:Real},
    lattice::AbstractMatrix{<:Real},
)
    return norm((collect(r_vector) .+ center_shift_fractional)' * lattice)
end

# Materialize one operator with a shared orbital-pair replica map.
function _materialize_operator_replicas(
    operator::RealSpaceOperator,
    input_degeneracies::Vector{Int},
    map::RealSpaceReplicaMap,
    normalization::Union{RawReplicaValues, PredividedReplicaValues},
)
    operator.r_vectors == map.source_r_vectors ||
        throw(ArgumentError("replica operator R support does not match the map"))
    input_degeneracies == map.source_degeneracies ||
        throw(ArgumentError("replica operator degeneracies do not match the map"))
    dimensions = collect(size(operator.data))
    dimensions[end] = size(map.target_r_vectors, 2)
    output = zeros(ComplexF64, Tuple(dimensions))
    tensor_colons = ntuple(_ -> Colon(), ndims(operator.data) - 3)
    target_indices = Dict(
        Tuple(map.target_r_vectors[:, index]) => index for index in axes(map.target_r_vectors, 2)
    )
    for left in axes(operator.data, 1),
        right in axes(operator.data, 2),
        source_r_index in axes(operator.r_vectors, 2)

        source = view(operator.data, left, right, tensor_colons..., source_r_index)
        target_images = map.images[left, right, source_r_index]
        scalar_weight =
            normalization isa RawReplicaValues ? inv(input_degeneracies[source_r_index]) : 1.0
        weight = scalar_weight / length(target_images)
        for target_image in target_images
            target = view(output, left, right, tensor_colons..., target_indices[target_image])
            target .+= weight .* source
        end
    end
    return RealSpaceOperator(operator.spec, map.target_r_vectors, output)
end

"""Describe the complete ordered small input support without orbital-pair expansion."""
function input_real_space_support_definition(
    r_vectors::AbstractMatrix{<:Integer},
    degeneracies::AbstractVector{<:Integer},
    num_wannier::Integer,
)
    size(r_vectors, 1) == 3 ||
        throw(ArgumentError("replica-map source R vectors must have three rows"))
    length(degeneracies) == size(r_vectors, 2) ||
        throw(ArgumentError("replica-map degeneracies do not match source R support"))
    all(>(0), degeneracies) || throw(ArgumentError("replica-map degeneracies must be positive"))
    count = Int(num_wannier)
    count > 0 || throw(ArgumentError("num_wannier must be positive"))
    return (
        schema = "wanniernlqg.input-r-support/1",
        num_orbitals = count,
        r_vectors = Tuple(
            ntuple(axis -> Int(r_vectors[axis, index]), 3) for index in axes(r_vectors, 2)
        ),
        scalar_degeneracies = Tuple(Int(value) for value in degeneracies),
    )
end

"""Validate and own an actual complete replica map; its reference is descriptive."""
function _real_space_replica_map(
    source::Symbol,
    source_r_vectors::AbstractMatrix{<:Integer},
    source_degeneracies::AbstractVector{<:Integer},
    images::Array{Vector{NTuple{3, Int}}, 3},
)
    size(source_r_vectors, 1) == 3 ||
        throw(ArgumentError("replica-map source R vectors must have three rows"))
    size(images, 3) == size(source_r_vectors, 2) ||
        throw(ArgumentError("replica-map image count does not match source R support"))
    length(source_degeneracies) == size(source_r_vectors, 2) ||
        throw(ArgumentError("replica-map degeneracies do not match source R support"))
    all(>(0), source_degeneracies) ||
        throw(ArgumentError("replica-map degeneracies must be positive"))
    target_set = Set{NTuple{3, Int}}()
    for entry in images
        isempty(entry) && throw(ArgumentError("replica-map entries must not be empty"))
        length(unique(entry)) == length(entry) ||
            throw(ArgumentError("replica-map entries must not contain duplicate images"))
        union!(target_set, entry)
    end
    target_vectors = sort!(collect(target_set))
    target_r_vectors =
        reduce(hcat, (collect(vector) for vector in target_vectors); init = zeros(Int, 3, 0))
    source_vectors = Matrix{Int}(source_r_vectors)
    degeneracies = Vector{Int}(source_degeneracies)
    return RealSpaceReplicaMap(
        source,
        source_vectors,
        degeneracies,
        target_r_vectors,
        images,
        scientific_data_generation(ScientificDataOwner()),
    )
end

"""Construct the identity map used by the explicit input-support policy."""
function input_real_space_replica_map(
    r_vectors::AbstractMatrix{<:Integer},
    degeneracies::AbstractVector{<:Integer},
    num_wannier::Integer,
)
    count = Int(num_wannier)
    count > 0 || throw(ArgumentError("num_wannier must be positive"))
    images = Array{Vector{NTuple{3, Int}}, 3}(undef, count, count, size(r_vectors, 2))
    for left in 1:count, right in 1:count, r_index in axes(r_vectors, 2)
        images[left, right, r_index] = [Tuple(r_vectors[:, r_index])]
    end
    return _real_space_replica_map(:input, r_vectors, degeneracies, images)
end

"""Bind strict Wannier `wsvec.dat` translations to absolute physical images."""
function real_space_replica_map_from_wsvec(
    r_vectors::AbstractMatrix{<:Integer},
    degeneracies::AbstractVector{<:Integer},
    translations::Array{Vector{NTuple{3, Int}}, 3},
)
    size(translations, 3) == size(r_vectors, 2) ||
        throw(ArgumentError("wsvec translations do not match the source R support"))
    images = similar(translations)
    for index in CartesianIndices(translations)
        source_r = Tuple(r_vectors[:, index[3]])
        images[index] = sort!(
            unique!(
                NTuple{3, Int}[
                    ntuple(axis -> source_r[axis] + translation[axis], 3) for
                    translation in translations[index]
                ],
            ),
        )
        length(images[index]) == length(translations[index]) ||
            throw(ArgumentError("wsvec translations collapse to duplicate physical images"))
    end
    return _real_space_replica_map(:wsvec, r_vectors, degeneracies, images)
end

"""Construct one center-aware minimum-distance map for all demanded operators."""
function minimum_distance_real_space_replica_map(
    r_vectors::AbstractMatrix{<:Integer},
    degeneracies::AbstractVector{<:Integer},
    lattice::AbstractMatrix{<:Real},
    mp_grid::NTuple{3, Int},
    wannier_centers_fractional::AbstractMatrix{<:Real};
    tolerance::Real,
    search_size::Integer,
)
    all(>(0), mp_grid) || throw(ArgumentError("mp_grid entries must be positive"))
    size(lattice) == (3, 3) || throw(ArgumentError("lattice must have size (3, 3)"))
    size(r_vectors, 1) == 3 || throw(ArgumentError("r_vectors must have three rows"))
    num_wannier = size(wannier_centers_fractional, 1)
    size(wannier_centers_fractional, 2) == 3 ||
        throw(ArgumentError("Wannier centers must have three columns"))
    all(isfinite, wannier_centers_fractional) ||
        throw(ArgumentError("Wannier centers contain non-finite values"))
    isfinite(tolerance) && tolerance > 0.0 ||
        throw(ArgumentError("minimum-distance tolerance must be finite and positive"))
    search_size > 0 || throw(ArgumentError("minimum-distance search_size must be positive"))
    # Non-Float64 expert inputs retain the existing generic arithmetic path.
    scratch =
        eltype(lattice) === Float64 && eltype(wannier_centers_fractional) === Float64 ?
        (
            Vector{NTuple{3, Int}}(undef, (2 * search_size + 1)^3),
            zeros(Float64, (2 * search_size + 1)^3),
            zeros(Float64, 3),
            zeros(Float64, 3),
        ) : nothing
    images = Array{Vector{NTuple{3, Int}}, 3}(undef, num_wannier, num_wannier, size(r_vectors, 2))
    for left in 1:num_wannier, right in 1:num_wannier
        center_shift =
            @view(wannier_centers_fractional[right, :]) .-
            @view(wannier_centers_fractional[left, :])
        images_by_residue = Dict{NTuple{3, Int}, Vector{NTuple{3, Int}}}()
        for source_r_index in axes(r_vectors, 2)
            residue = real_space_mp_residue(@view(r_vectors[:, source_r_index]), mp_grid)
            target_images = get!(images_by_residue, residue) do
                selected = if scratch === nothing
                    nearest_wigner_seitz_images(
                        residue,
                        center_shift,
                        lattice,
                        mp_grid;
                        tolerance,
                        search_size,
                    )
                else
                    _nearest_wigner_seitz_images!(
                        scratch,
                        residue,
                        center_shift,
                        lattice,
                        mp_grid;
                        tolerance,
                        search_size,
                    )
                end
                sort!(selected)
                unique!(selected)
                isempty(selected) && error("Minimum distance produced no replica")
                selected
            end
            images[left, right, source_r_index] = copy(target_images)
        end
    end
    return _real_space_replica_map(:recomputed, r_vectors, degeneracies, images)
end

# Shared immutable lookup for all operator components in one preparation call.
_replica_target_indices(map::RealSpaceReplicaMap) =
    Dict(Tuple(map.target_r_vectors[:, index]) => index for index in axes(map.target_r_vectors, 2))

"""Materialize one selected Cartesian component through a shared replica map."""
function materialize_replica_component(
    source::AbstractArray{ComplexF64, 3},
    input_degeneracies::Vector{Int},
    map::RealSpaceReplicaMap,
    normalization::Union{RawReplicaValues, PredividedReplicaValues},
)
    return _materialize_replica_component(
        source,
        input_degeneracies,
        map,
        normalization,
        _replica_target_indices(map),
    )
end

# Accumulate one operator component using the caller-owned, typed target lookup.
function _materialize_replica_component(
    source::AbstractArray{ComplexF64, 3},
    input_degeneracies::Vector{Int},
    map::RealSpaceReplicaMap,
    normalization::Union{RawReplicaValues, PredividedReplicaValues},
    target_indices::Dict{NTuple{3, Int}, Int},
)
    size(source, 3) == size(map.source_r_vectors, 2) ||
        throw(ArgumentError("replica component does not match source R support"))
    length(input_degeneracies) == size(source, 3) ||
        throw(ArgumentError("replica component degeneracies do not match source R support"))
    all(>(0), input_degeneracies) ||
        throw(ArgumentError("replica component degeneracies must be positive"))
    input_degeneracies == map.source_degeneracies ||
        throw(ArgumentError("replica component degeneracies do not match the map"))
    size(source, 1) == size(source, 2) == size(map.images, 1) == size(map.images, 2) ||
        throw(ArgumentError("replica component orbital dimensions do not match the map"))
    output = zeros(ComplexF64, size(source, 1), size(source, 2), size(map.target_r_vectors, 2))
    for left in axes(source, 1), right in axes(source, 2), source_r_index in axes(source, 3)
        targets = map.images[left, right, source_r_index]
        scalar_weight =
            normalization isa RawReplicaValues ? inv(input_degeneracies[source_r_index]) : 1.0
        weight = scalar_weight / length(targets)
        for target in targets
            output[left, right, target_indices[target]] +=
                weight * source[left, right, source_r_index]
        end
    end
    return output
end

"""Return deterministic link-length summary statistics for metadata."""
function real_space_link_length_summary(values::AbstractVector{<:Real})
    isempty(values) &&
        return Dict("minimum" => 0.0, "median" => 0.0, "p95" => 0.0, "maximum" => 0.0)
    ordered = sort(Float64.(values))
    middle = length(ordered) ÷ 2
    median_value =
        isodd(length(ordered)) ? ordered[middle + 1] : 0.5 * (ordered[middle] + ordered[middle + 1])
    percentile_index = max(1, ceil(Int, 0.95 * length(ordered)))
    return Dict(
        "minimum" => first(ordered),
        "median" => median_value,
        "p95" => ordered[percentile_index],
        "maximum" => last(ordered),
    )
end

"""
Apply `:input` or center-aware `:minimum_distance` replica storage exactly once.

All operators share one orbital-pair map. Minimum distance distributes tied
images equally and returns unit degeneracies, preserving the established
Symmetrization convention for spectrum-only reuse.
"""
function apply_real_space_replica_policy(
    operators::AbstractDict{RealSpaceOperatorKind, <:RealSpaceOperator},
    input_degeneracies::Vector{Int},
    lattice::AbstractMatrix{<:Real},
    mp_grid::NTuple{3, Int},
    wannier_centers_fractional::AbstractMatrix{<:Real},
    policy::Symbol;
    tolerance::Real,
    search_size::Integer,
)
    return _apply_real_space_replica_policy(
        operators,
        input_degeneracies,
        lattice,
        mp_grid,
        wannier_centers_fractional,
        policy,
        PredividedReplicaValues();
        tolerance,
        search_size,
    )
end

"""
Apply a replica policy to raw serialized Wannier values.

For minimum-distance materialization each source contribution is divided by
`N_R * N_pair` before it is accumulated onto unit-degeneracy physical images.
"""
function apply_serialized_real_space_replica_policy(
    operators::AbstractDict{RealSpaceOperatorKind, <:RealSpaceOperator},
    input_degeneracies::Vector{Int},
    lattice::AbstractMatrix{<:Real},
    mp_grid::NTuple{3, Int},
    wannier_centers_fractional::AbstractMatrix{<:Real},
    policy::Symbol;
    tolerance::Real,
    search_size::Integer,
)
    return _apply_real_space_replica_policy(
        operators,
        input_degeneracies,
        lattice,
        mp_grid,
        wannier_centers_fractional,
        policy,
        RawReplicaValues();
        tolerance,
        search_size,
    )
end

# Apply one normalization-aware policy while sharing a single orbital-pair map.
function _apply_real_space_replica_policy(
    operators::AbstractDict{RealSpaceOperatorKind, <:RealSpaceOperator},
    input_degeneracies::Vector{Int},
    lattice::AbstractMatrix{<:Real},
    mp_grid::NTuple{3, Int},
    wannier_centers_fractional::AbstractMatrix{<:Real},
    policy::Symbol,
    normalization::Union{RawReplicaValues, PredividedReplicaValues};
    tolerance::Real,
    search_size::Integer,
)
    policy in (:input, :minimum_distance) ||
        throw(ArgumentError("real_space_replica_policy must be :input or :minimum_distance"))
    all(>(0), mp_grid) || throw(ArgumentError("mp_grid entries must be positive"))
    isempty(operators) && throw(ArgumentError("replica policy requires at least one operator"))
    first_operator = first(values(operators))
    r_vectors = first_operator.r_vectors
    all(operator -> operator.r_vectors == r_vectors, values(operators)) ||
        throw(ArgumentError("replica policy requires common input R support"))
    length(input_degeneracies) == size(r_vectors, 2) ||
        throw(ArgumentError("replica policy degeneracies do not match R support"))
    num_wannier = size(first_operator.data, 1)
    size(wannier_centers_fractional) == (num_wannier, 3) ||
        throw(ArgumentError("Wannier centers do not match operator dimensions"))
    all(isfinite, wannier_centers_fractional) ||
        throw(ArgumentError("Wannier centers contain non-finite values"))
    input_lengths = Float64[]
    for left in 1:num_wannier, right in 1:num_wannier, r_index in axes(r_vectors, 2)
        center_shift =
            @view(wannier_centers_fractional[right, :]) .-
            @view(wannier_centers_fractional[left, :])
        push!(
            input_lengths,
            _replica_link_length(Tuple(r_vectors[:, r_index]), center_shift, lattice),
        )
    end
    if policy == :input
        map = input_real_space_replica_map(r_vectors, input_degeneracies, num_wannier)
        return RealSpaceReplicaPolicyResult(
            policy,
            Dict{RealSpaceOperatorKind, RealSpaceOperator}(operators),
            copy(input_degeneracies),
            size(r_vectors, 2),
            size(r_vectors, 2),
            num_wannier * num_wannier * size(r_vectors, 2),
            0,
            0,
            0,
            zeros(Int, num_wannier, num_wannier),
            input_lengths,
            copy(input_lengths),
            map.mapping_reference,
            map,
        )
    end

    map = minimum_distance_real_space_replica_map(
        r_vectors,
        input_degeneracies,
        lattice,
        mp_grid,
        wannier_centers_fractional;
        tolerance,
        search_size,
    )
    images = map.images
    pair_changed_counts = zeros(Int, num_wannier, num_wannier)
    changed_assignment_count = 0
    tied_assignment_count = 0
    output_lengths = Float64[]
    for left in 1:num_wannier, right in 1:num_wannier
        center_shift =
            @view(wannier_centers_fractional[right, :]) .-
            @view(wannier_centers_fractional[left, :])
        for source_r_index in axes(r_vectors, 2)
            source_r_vector = Tuple(r_vectors[:, source_r_index])
            target_images = images[left, right, source_r_index]
            changed = length(target_images) != 1 || only(target_images) != source_r_vector
            if changed
                changed_assignment_count += 1
                pair_changed_counts[left, right] += 1
            end
            length(target_images) > 1 && (tied_assignment_count += 1)
            for target_image in target_images
                push!(output_lengths, _replica_link_length(target_image, center_shift, lattice))
            end
        end
    end
    output_operators = Dict{RealSpaceOperatorKind, RealSpaceOperator}()
    for (kind, operator) in operators
        output_operators[kind] =
            _materialize_operator_replicas(operator, input_degeneracies, map, normalization)
    end
    return RealSpaceReplicaPolicyResult(
        policy,
        output_operators,
        ones(Int, size(map.target_r_vectors, 2)),
        size(r_vectors, 2),
        size(map.target_r_vectors, 2),
        length(images),
        changed_assignment_count,
        count(>(0), pair_changed_counts),
        tied_assignment_count,
        pair_changed_counts,
        input_lengths,
        output_lengths,
        map.mapping_reference,
        map,
    )
end
