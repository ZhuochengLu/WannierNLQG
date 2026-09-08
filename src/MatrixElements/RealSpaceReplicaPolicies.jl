const REAL_SPACE_REPLICA_MAP_DIGEST_SCHEME = "sha256:replica-map-v2/source-r/n-r/ordered-pair-absolute-images"

"""One deterministic orbital-pair map from serialized R records to physical images."""
struct RealSpaceReplicaMap
    source::Symbol
    source_r_vectors::Matrix{Int}
    source_degeneracies::Vector{Int}
    target_r_vectors::Matrix{Int}
    images::Array{Vector{NTuple{3, Int}}, 3}
    mapping_sha256::String
end

"""Marker for raw Wannier90 values that still carry scalar `N_R` weights."""
struct SerializedWannier90ReplicaValues end

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
    mapping_sha256::String
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
    candidates = NTuple{3, Int}[]
    distances = Float64[]
    for i in (-search_size):search_size,
        j in (-search_size):search_size,
        k in (-search_size):search_size

        candidate =
            (residue[1] + i * mp_grid[1], residue[2] + j * mp_grid[2], residue[3] + k * mp_grid[3])
        push!(candidates, candidate)
        push!(distances, norm((collect(candidate) .+ center_shift)' * lattice))
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
    normalization::Union{SerializedWannier90ReplicaValues, PredividedReplicaValues},
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
            normalization isa SerializedWannier90ReplicaValues ?
            inv(input_degeneracies[source_r_index]) : 1.0
        weight = scalar_weight / length(target_images)
        for target_image in target_images
            target = view(output, left, right, tensor_colons..., target_indices[target_image])
            target .+= weight .* source
        end
    end
    return RealSpaceOperator(operator.spec, map.target_r_vectors, output)
end

# Hash the complete canonical source and ordered orbital-pair image map.
function _replica_mapping_sha256(
    source_r_vectors::Matrix{Int},
    source_degeneracies::Vector{Int},
    images::Array{Vector{NTuple{3, Int}}, 3},
)
    buffer = IOBuffer()
    print(buffer, REAL_SPACE_REPLICA_MAP_DIGEST_SCHEME, '\n')
    print(buffer, "source_count=", string(size(source_r_vectors, 2)), '\n')
    for r_index in axes(source_r_vectors, 2)
        print(
            buffer,
            "R=",
            join(Tuple(source_r_vectors[:, r_index]), ','),
            ";N_R=",
            string(source_degeneracies[r_index]),
            '\n',
        )
    end
    for left in axes(images, 1), right in axes(images, 2), r_index in axes(images, 3)
        targets = sort(images[left, right, r_index])
        print(
            buffer,
            "left=",
            string(left),
            ";right=",
            string(right),
            ";source_index=",
            string(r_index),
            ";image_count=",
            string(length(targets)),
            '\n',
        )
        for target in targets
            print(buffer, "target=", join(target, ','), '\n')
        end
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

# Hold one bounded canonical-serialization buffer and reusable decimal workspace.
mutable struct _ReplicaDigestSink
    context::SHA.SHA2_256_CTX
    bytes::Vector{UInt8}
    position::Int
    digits::Vector{UInt8}
end

# Construct a fixed-size incremental SHA sink without per-entry heap objects.
_ReplicaDigestSink() = _ReplicaDigestSink(
    SHA.SHA2_256_CTX(),
    Vector{UInt8}(undef, 64 * 1024),
    0,
    Vector{UInt8}(undef, 24),
)

# Commit the occupied byte prefix while retaining the reusable storage.
@inline function _flush_replica_digest!(sink::_ReplicaDigestSink)
    iszero(sink.position) && return nothing
    SHA.update!(sink.context, @view(sink.bytes[1:sink.position]))
    sink.position = 0
    return nothing
end

# Append one canonical byte, flushing the bounded buffer only when full.
@inline function _feed_replica_digest_byte!(sink::_ReplicaDigestSink, byte::UInt8)
    sink.position == length(sink.bytes) && _flush_replica_digest!(sink)
    sink.position += 1
    @inbounds sink.bytes[sink.position] = byte
    return nothing
end

# Append a literal exactly as its UTF-8 code units appear in the legacy encoding.
@inline function _feed_replica_digest_literal!(sink::_ReplicaDigestSink, value::AbstractString)
    @inbounds for byte in codeunits(value)
        _feed_replica_digest_byte!(sink, byte)
    end
    return nothing
end

# Append one base-10 integer without allocating a temporary string.
@inline function _feed_replica_digest_integer!(sink::_ReplicaDigestSink, value::Integer)
    signed_value = Int(value)
    magnitude = if signed_value < 0
        _feed_replica_digest_byte!(sink, UInt8('-'))
        UInt(-(signed_value + 1)) + UInt(1)
    else
        UInt(signed_value)
    end
    if iszero(magnitude)
        _feed_replica_digest_byte!(sink, UInt8('0'))
        return nothing
    end
    cursor = length(sink.digits) + 1
    while !iszero(magnitude)
        cursor -= 1
        @inbounds sink.digits[cursor] = UInt8('0') + UInt8(rem(magnitude, UInt(10)))
        magnitude = div(magnitude, UInt(10))
    end
    @inbounds for index in cursor:length(sink.digits)
        _feed_replica_digest_byte!(sink, sink.digits[index])
    end
    return nothing
end

# Flush the last bytes and finalize the canonical lowercase hexadecimal digest.
function _finish_replica_digest!(sink::_ReplicaDigestSink)
    _flush_replica_digest!(sink)
    return bytes2hex(SHA.digest!(sink.context))
end

"""Return the canonical digest of an input-support identity map without materializing it."""
function input_real_space_replica_mapping_sha256(
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

    sink = _ReplicaDigestSink()
    _feed_replica_digest_literal!(sink, REAL_SPACE_REPLICA_MAP_DIGEST_SCHEME)
    _feed_replica_digest_byte!(sink, UInt8('\n'))
    _feed_replica_digest_literal!(sink, "source_count=")
    _feed_replica_digest_integer!(sink, size(r_vectors, 2))
    _feed_replica_digest_byte!(sink, UInt8('\n'))
    for r_index in axes(r_vectors, 2)
        _feed_replica_digest_literal!(sink, "R=")
        _feed_replica_digest_integer!(sink, r_vectors[1, r_index])
        _feed_replica_digest_byte!(sink, UInt8(','))
        _feed_replica_digest_integer!(sink, r_vectors[2, r_index])
        _feed_replica_digest_byte!(sink, UInt8(','))
        _feed_replica_digest_integer!(sink, r_vectors[3, r_index])
        _feed_replica_digest_literal!(sink, ";N_R=")
        _feed_replica_digest_integer!(sink, degeneracies[r_index])
        _feed_replica_digest_byte!(sink, UInt8('\n'))
    end
    for left in 1:count, right in 1:count, r_index in axes(r_vectors, 2)
        _feed_replica_digest_literal!(sink, "left=")
        _feed_replica_digest_integer!(sink, left)
        _feed_replica_digest_literal!(sink, ";right=")
        _feed_replica_digest_integer!(sink, right)
        _feed_replica_digest_literal!(sink, ";source_index=")
        _feed_replica_digest_integer!(sink, r_index)
        _feed_replica_digest_literal!(sink, ";image_count=1\ntarget=")
        _feed_replica_digest_integer!(sink, r_vectors[1, r_index])
        _feed_replica_digest_byte!(sink, UInt8(','))
        _feed_replica_digest_integer!(sink, r_vectors[2, r_index])
        _feed_replica_digest_byte!(sink, UInt8(','))
        _feed_replica_digest_integer!(sink, r_vectors[3, r_index])
        _feed_replica_digest_byte!(sink, UInt8('\n'))
    end
    return _finish_replica_digest!(sink)
end

# Build a validated map and canonical target support from absolute physical images.
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
        _replica_mapping_sha256(source_vectors, degeneracies, images),
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

"""Bind strict Wannier90 `wsvec.dat` translations to absolute physical images."""
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
    images = Array{Vector{NTuple{3, Int}}, 3}(undef, num_wannier, num_wannier, size(r_vectors, 2))
    for left in 1:num_wannier, right in 1:num_wannier
        center_shift =
            @view(wannier_centers_fractional[right, :]) .-
            @view(wannier_centers_fractional[left, :])
        for source_r_index in axes(r_vectors, 2)
            residue = real_space_mp_residue(@view(r_vectors[:, source_r_index]), mp_grid)
            target_images = nearest_wigner_seitz_images(
                residue,
                center_shift,
                lattice,
                mp_grid;
                tolerance,
                search_size,
            )
            sort!(target_images)
            unique!(target_images)
            isempty(target_images) && error("Minimum distance produced no replica")
            images[left, right, source_r_index] = target_images
        end
    end
    return _real_space_replica_map(:recomputed, r_vectors, degeneracies, images)
end

"""Materialize one selected Cartesian component through a shared replica map."""
function materialize_replica_component(
    source::AbstractArray{ComplexF64, 3},
    input_degeneracies::Vector{Int},
    map::RealSpaceReplicaMap,
    normalization::Union{SerializedWannier90ReplicaValues, PredividedReplicaValues},
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
    target_indices = Dict(
        Tuple(map.target_r_vectors[:, index]) => index for index in axes(map.target_r_vectors, 2)
    )
    for left in axes(source, 1), right in axes(source, 2), source_r_index in axes(source, 3)
        targets = map.images[left, right, source_r_index]
        scalar_weight =
            normalization isa SerializedWannier90ReplicaValues ?
            inv(input_degeneracies[source_r_index]) : 1.0
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
Apply a replica policy to raw serialized Wannier90 values.

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
        SerializedWannier90ReplicaValues();
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
    normalization::Union{SerializedWannier90ReplicaValues, PredividedReplicaValues};
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
            map.mapping_sha256,
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
        map.mapping_sha256,
        map,
    )
end
