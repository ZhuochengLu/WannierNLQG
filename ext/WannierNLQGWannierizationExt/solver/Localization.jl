"""
Compute every U-localization k-point/neighbor edge on exactly one MPI rank.

The reduced buffer is a dense edge inventory rather than a partial sum.  Each
matrix element therefore has one nonzero owner, and every rank reconstructs
objective and gradient sums later in the canonical serial edge order.  This
keeps the scientific reduction deterministic while distributing the expensive
`F_k' M_{k,b} F_{k+b}` contractions.
"""
function _mpi_localization_edge_overlaps(
    frames::Vector{Matrix{ComplexF64}},
    mmn::WannierMMN,
    parallel::Symbol,
)
    parallel == :mpi || return nothing
    MPI.Initialized() || MPI.Init()
    communicator = MPI.COMM_WORLD
    rank = MPI.Comm_rank(communicator)
    size_value = MPI.Comm_size(communicator)
    nk = length(frames)
    num_wannier = size(first(frames), 2)
    overlaps = zeros(ComplexF64, num_wannier, num_wannier, mmn.num_neighbors, nk)
    for kpoint in 1:nk, neighbor in 1:mmn.num_neighbors
        edge = (kpoint - 1) * mmn.num_neighbors + neighbor
        mod(edge - 1, size_value) == rank || continue
        target = mmn.neighbors[neighbor, kpoint]
        @views overlaps[:, :, neighbor, kpoint] .=
            frames[kpoint]' * mmn.data[:, :, neighbor, kpoint] * frames[target]
    end
    MPI.Allreduce!(overlaps, +, communicator)
    return overlaps
end

"""Use rank zero as the unique floating-point authority for a matrix field.

Wannier90-reference initialization deliberately reproduces LAPACK and scalar
arithmetic order.  Separate processes can nevertheless return last-bit
different singular/eigenvector gauges at the Z-to-U boundary.  A subsequent
rank-local acceptance decision would then desynchronise MPI collectives.  The
scientific state at this boundary is a single sealed subspace, so broadcasting
the root frame is both the deterministic definition and the cheapest place to
remove that process-local gauge ambiguity.
"""
function _mpi_root_canonical_matrix_field!(
    field::Vector{<:AbstractMatrix{ComplexF64}},
    parallel::Symbol,
)
    parallel == :mpi || return field
    MPI.Initialized() || MPI.Init()
    communicator = MPI.COMM_WORLD
    dimensions = Int64[length(field)]
    for matrix in field
        append!(dimensions, (size(matrix, 1), size(matrix, 2)))
    end
    minimum_dimensions = copy(dimensions)
    maximum_dimensions = copy(dimensions)
    MPI.Allreduce!(minimum_dimensions, min, communicator)
    MPI.Allreduce!(maximum_dimensions, max, communicator)
    minimum_dimensions == maximum_dimensions ||
        throw(ArgumentError("MPI_MATRIX_FIELD_SHAPE_MISMATCH: ranks disagree on field inventory"))
    isempty(field) && return field
    common_size = size(first(field))
    if all(matrix -> size(matrix) == common_size, field)
        # Production k-point fields are rectangular and uniform.  Pack them so
        # a 1000-point mesh needs one payload broadcast rather than thousands
        # of latency-dominated matrix collectives at every U call boundary.
        packed = cat(field...; dims = 3)
        MPI.Bcast!(packed, 0, communicator)
        for (index, matrix) in enumerate(field)
            @views matrix .= packed[:, :, index]
        end
    else
        # Variable-row synthetic and expert fields retain the same scientific
        # contract with one already-audited broadcast per matrix.
        for matrix in field
            MPI.Bcast!(matrix, 0, communicator)
        end
    end
    return field
end

"""Broadcast an optional complex matrix field from rank zero.

The presence check is collective and precedes every payload broadcast.  A
rank-local `nothing`/field disagreement is therefore reported as a structural
MPI state error instead of letting the ranks enter different localization
branches and eventually deadlock in unrelated collectives.
"""
function _mpi_root_canonical_optional_matrix_field(
    field::Union{Nothing, Vector{Matrix{ComplexF64}}},
    parallel::Symbol,
)
    parallel == :mpi || return field
    MPI.Initialized() || MPI.Init()
    communicator = MPI.COMM_WORLD
    presence = Int64[field === nothing ? 0 : 1]
    minimum_presence = copy(presence)
    maximum_presence = copy(presence)
    MPI.Allreduce!(minimum_presence, min, communicator)
    MPI.Allreduce!(maximum_presence, max, communicator)
    minimum_presence == maximum_presence ||
        throw(ArgumentError("MPI_OPTIONAL_MATRIX_FIELD_PRESENCE_MISMATCH"))
    iszero(only(presence)) && return nothing
    canonical = deepcopy(something(field))
    _mpi_root_canonical_matrix_field!(canonical, parallel)
    return canonical
end

"""Broadcast one dense numerical array from rank zero after a shape audit."""
function _mpi_root_canonical_array!(array::Array{T}, parallel::Symbol) where {T <: Number}
    parallel == :mpi || return array
    MPI.Initialized() || MPI.Init()
    communicator = MPI.COMM_WORLD
    dimensions = Int64[ndims(array); collect(size(array))]
    minimum_dimensions = copy(dimensions)
    maximum_dimensions = copy(dimensions)
    MPI.Allreduce!(minimum_dimensions, min, communicator)
    MPI.Allreduce!(maximum_dimensions, max, communicator)
    minimum_dimensions == maximum_dimensions || throw(ArgumentError("MPI_ARRAY_SHAPE_MISMATCH"))
    MPI.Bcast!(array, 0, communicator)
    return array
end

"""Broadcast an optional dense numerical array from rank zero."""
function _mpi_root_canonical_optional_array(
    array::Union{Nothing, Array{T, N}},
    parallel::Symbol,
) where {T <: Number, N}
    parallel == :mpi || return array
    MPI.Initialized() || MPI.Init()
    communicator = MPI.COMM_WORLD
    presence = Int64[array === nothing ? 0 : 1]
    minimum_presence = copy(presence)
    maximum_presence = copy(presence)
    MPI.Allreduce!(minimum_presence, min, communicator)
    MPI.Allreduce!(maximum_presence, max, communicator)
    minimum_presence == maximum_presence ||
        throw(ArgumentError("MPI_OPTIONAL_ARRAY_PRESENCE_MISMATCH"))
    iszero(only(presence)) && return nothing
    canonical = copy(something(array))
    _mpi_root_canonical_array!(canonical, parallel)
    return canonical
end

"""Return rank zero's scalar value on every MPI rank."""
function _mpi_root_canonical_scalar(value::T, parallel::Symbol) where {T <: Number}
    parallel == :mpi || return value
    MPI.Initialized() || MPI.Init()
    buffer = T[value]
    MPI.Bcast!(buffer, 0, MPI.COMM_WORLD)
    return only(buffer)
end

"""Use rank zero's Boolean branch decision on every MPI rank.

The Wannier90 parabolic step contains comparisons whose inputs may differ by a
last bit after process-local BLAS/LAPACK calls.  The distributed edge
contractions remain collective, but the reference algorithm has one scalar
control flow.  Broadcasting that decision prevents one rank from entering a
second trial while another rank enters terminal persistence.
"""
function _mpi_root_canonical_flag(value::Bool, parallel::Symbol)
    return !iszero(_mpi_root_canonical_scalar(Int64(value), parallel))
end

"""Return rank zero's UTF-8 string on every MPI rank."""
function _mpi_root_canonical_string(value::AbstractString, parallel::Symbol)
    parallel == :mpi || return String(value)
    MPI.Initialized() || MPI.Init()
    communicator = MPI.COMM_WORLD
    rank = MPI.Comm_rank(communicator)
    bytes = rank == 0 ? collect(codeunits(value)) : UInt8[]
    length_buffer = Int64[length(bytes)]
    MPI.Bcast!(length_buffer, 0, communicator)
    resize!(bytes, only(length_buffer))
    MPI.Bcast!(bytes, 0, communicator)
    return String(bytes)
end

"""Return whether every MPI rank reported the same successful candidate state."""
function _mpi_all_ranks_success(value::Bool, parallel::Symbol)
    parallel == :mpi || return value
    MPI.Initialized() || MPI.Init()
    buffer = Int64[value]
    MPI.Allreduce!(buffer, min, MPI.COMM_WORLD)
    return !iszero(only(buffer))
end

"""Return rank zero's optional scalar after a collective presence audit."""
function _mpi_root_canonical_optional_scalar(
    value::Union{Nothing, T},
    parallel::Symbol,
) where {T <: Number}
    parallel == :mpi || return value
    MPI.Initialized() || MPI.Init()
    communicator = MPI.COMM_WORLD
    presence = Int64[value === nothing ? 0 : 1]
    minimum_presence = copy(presence)
    maximum_presence = copy(presence)
    MPI.Allreduce!(minimum_presence, min, communicator)
    MPI.Allreduce!(maximum_presence, max, communicator)
    minimum_presence == maximum_presence ||
        throw(ArgumentError("MPI_OPTIONAL_SCALAR_PRESENCE_MISMATCH"))
    iszero(only(presence)) && return nothing
    return _mpi_root_canonical_scalar(something(value), parallel)
end

"""Construct the complete localized link-overlap state in canonical edge order."""
function _localized_overlap_state(
    frames::Vector{Matrix{ComplexF64}},
    mmn::WannierMMN,
    parallel::Symbol,
)
    distributed = _mpi_localization_edge_overlaps(frames, mmn, parallel)
    distributed === nothing || return distributed
    nk = length(frames)
    num_wannier = size(first(frames), 2)
    overlaps = zeros(ComplexF64, num_wannier, num_wannier, mmn.num_neighbors, nk)
    for kpoint in 1:nk, neighbor in 1:mmn.num_neighbors
        target = mmn.neighbors[neighbor, kpoint]
        @views overlaps[:, :, neighbor, kpoint] .=
            frames[kpoint]' * mmn.data[:, :, neighbor, kpoint] * frames[target]
    end
    return overlaps
end

"""Construct the initial localized M state with Wannier90's two ZGEMMs.

The generic path is mathematically identical but may dispatch through a
different BLAS ABI.  The one-ULP difference it leaves in the first U gradient
is amplified by the second parabolic step, so the explicit reference profile
uses the same LP64 ZGEMM contract as all recursive M updates.
"""
function _wannier90_reference_localized_overlap_state(
    frames::Vector{Matrix{ComplexF64}},
    mmn::WannierMMN,
    parallel::Symbol,
)
    parallel == :mpi && !MPI.Initialized() && MPI.Init()
    communicator = parallel == :mpi ? MPI.COMM_WORLD : nothing
    rank = parallel == :mpi ? MPI.Comm_rank(something(communicator)) : 0
    size_value = parallel == :mpi ? MPI.Comm_size(something(communicator)) : 1
    nk = length(frames)
    num_wannier = size(first(frames), 2)
    overlaps = zeros(ComplexF64, num_wannier, num_wannier, mmn.num_neighbors, nk)
    for kpoint in 1:nk, neighbor in 1:mmn.num_neighbors
        edge = (kpoint - 1) * mmn.num_neighbors + neighbor
        mod(edge - 1, size_value) == rank || continue
        target = mmn.neighbors[neighbor, kpoint]
        left = _wannier90_reference_zgemm(
            frames[kpoint],
            'C',
            @view(mmn.data[:, :, neighbor, kpoint]),
            'N',
        )
        @views overlaps[:, :, neighbor, kpoint] .=
            _wannier90_reference_zgemm(left, 'N', frames[target], 'N')
    end
    parallel == :mpi && MPI.Allreduce!(overlaps, +, something(communicator))
    return overlaps
end

"""Construct Wannier90's Z-to-U M state in its two algebraic stages.

The reference program first contracts the raw band overlaps with `U_opt` and
only afterwards rotates that slim overlap with the square localization `U`.
Collapsing both stages into a completed frame `V = U_opt*U` is mathematically
equivalent, but not floating-point equivalent; the resulting one-ULP M drift
is amplified by the later parabolic FR steps.  Active window rows are compacted
in their declared band order while all BLAS leading dimensions remain those of
the parent arrays used by Wannier90 4.0.1.
"""
function _wannier90_reference_initial_slim_overlap_state(
    subspace_frames::Vector{Matrix{ComplexF64}},
    localization_unitaries::Vector{Matrix{ComplexF64}},
    outer_indices::Vector{Vector{Int}},
    mmn::WannierMMN,
    parallel::Symbol,
)
    length(subspace_frames) == length(localization_unitaries) == length(outer_indices) ||
        throw(DimensionMismatch("Wannier90-reference Z-to-U state lengths disagree"))
    parallel == :mpi && !MPI.Initialized() && MPI.Init()
    communicator = parallel == :mpi ? MPI.COMM_WORLD : nothing
    rank = parallel == :mpi ? MPI.Comm_rank(something(communicator)) : 0
    size_value = parallel == :mpi ? MPI.Comm_size(something(communicator)) : 1
    nk = length(subspace_frames)
    num_bands, num_wannier = size(first(subspace_frames))
    overlaps = zeros(ComplexF64, num_wannier, num_wannier, mmn.num_neighbors, nk)

    for kpoint in 1:nk, neighbor in 1:mmn.num_neighbors
        edge = (kpoint - 1) * mmn.num_neighbors + neighbor
        mod(edge - 1, size_value) == rank || continue
        target = mmn.neighbors[neighbor, kpoint]
        source_outer = outer_indices[kpoint]
        target_outer = outer_indices[target]
        source_count = length(source_outer)
        target_count = length(target_outer)
        source_count >= num_wannier && target_count >= num_wannier ||
            throw(DimensionMismatch("outer window is smaller than num_wannier"))

        source_uopt = zeros(ComplexF64, num_bands, num_wannier)
        target_uopt = zeros(ComplexF64, num_bands, num_wannier)
        source_uopt[1:source_count, :] .= @view subspace_frames[kpoint][source_outer, :]
        target_uopt[1:target_count, :] .= @view subspace_frames[target][target_outer, :]
        raw_storage = zeros(ComplexF64, num_bands, num_bands)
        raw_storage[1:source_count, 1:target_count] .=
            @view mmn.data[source_outer, target_outer, neighbor, kpoint]

        # dis_main: CWB = Uopt(k)^H M(k,b), then CWW = CWB Uopt(k+b).
        cwb = zeros(ComplexF64, num_wannier, num_bands)
        cww = zeros(ComplexF64, num_wannier, num_wannier)
        _wannier90_reference_zgemm_storage!(
            cwb,
            source_uopt,
            'C',
            raw_storage,
            'N',
            num_wannier,
            target_count,
            source_count,
        )
        _wannier90_reference_zgemm_storage!(
            cww,
            cwb,
            'N',
            target_uopt,
            'N',
            num_wannier,
            num_wannier,
            target_count,
        )

        # setup_m_loc: M = U(k)^H CWW U(k+b).  CWW occupies the leading
        # num_wannier block of the parent-leading-dimension overlap storage.
        slim_storage = zeros(ComplexF64, num_bands, num_bands)
        slim_storage[1:num_wannier, 1:num_wannier] .= cww
        rotated_left = zeros(ComplexF64, num_wannier, num_bands)
        final_overlap = zeros(ComplexF64, num_wannier, num_wannier)
        _wannier90_reference_zgemm_storage!(
            rotated_left,
            localization_unitaries[kpoint],
            'C',
            slim_storage,
            'N',
            num_wannier,
            num_wannier,
            num_wannier,
        )
        _wannier90_reference_zgemm_storage!(
            final_overlap,
            rotated_left,
            'N',
            localization_unitaries[target],
            'N',
            num_wannier,
            num_wannier,
            num_wannier,
        )
        @views overlaps[:, :, neighbor, kpoint] .= final_overlap
    end
    parallel == :mpi && MPI.Allreduce!(overlaps, +, something(communicator))
    return overlaps
end

"""Apply the Wannier90 recursive `R_k' * M_kb * R_k+b` link update."""
function _rotate_localized_overlap_state(
    overlaps::Array{ComplexF64, 4},
    rotations::Vector{Matrix{ComplexF64}},
    mmn::WannierMMN,
)
    size(overlaps, 3) == mmn.num_neighbors ||
        throw(DimensionMismatch("localized overlap neighbor count disagrees"))
    size(overlaps, 4) == length(rotations) ||
        throw(DimensionMismatch("localized overlap k mesh disagrees"))
    updated = similar(overlaps)
    for kpoint in eachindex(rotations), neighbor in 1:mmn.num_neighbors
        target = mmn.neighbors[neighbor, kpoint]
        @views begin
            left = _wannier90_reference_zgemm(
                rotations[kpoint],
                'C',
                overlaps[:, :, neighbor, kpoint],
                'N',
            )
            updated[:, :, neighbor, kpoint] .=
                _wannier90_reference_zgemm(left, 'N', rotations[target], 'N')
        end
    end
    return updated
end

"""Evaluate Wannier90 4.0.1's invariant spread in its scalar loop order."""
function _wannier90_reference_invariant_spread(
    overlaps::Array{ComplexF64, 4},
    weights::Vector{Float64},
)
    num_wannier = size(overlaps, 1)
    nk = size(overlaps, 4)
    total = 0.0
    for kpoint in 1:nk, neighbor in axes(overlaps, 3)
        link_norm = 0.0
        for m in 1:num_wannier, n in 1:num_wannier
            value = overlaps[n, m, neighbor, kpoint]
            link_norm += _wannier90_reference_gfortran_magnitude_squared(value)
        end
        total += weights[neighbor] * (num_wannier - link_norm)
    end
    return total / nk
end

"""Evaluate Wannier90 4.0.1 `om_i + om_d + om_od` without reassociation."""
function _wannier90_reference_total_spread(
    overlaps::Array{ComplexF64, 4},
    centered_phases::Array{Float64, 3},
    centers::Matrix{Float64},
    representation::BandRepresentation,
    mmn::WannierMMN,
    weights::Vector{Float64},
    omega_invariant::Float64,
)
    num_wannier = size(overlaps, 1)
    nk = size(overlaps, 4)
    omega_od = 0.0
    for kpoint in 1:nk, neighbor in axes(overlaps, 3)
        for m in 1:num_wannier, n in 1:num_wannier
            if m != n
                value = overlaps[n, m, neighbor, kpoint]
                omega_od = fma(
                    weights[neighbor],
                    _wannier90_reference_gfortran_scalar_magnitude_squared(value),
                    omega_od,
                )
            end
        end
    end
    omega_od /= nk
    omega_d = 0.0
    for kpoint in 1:nk, neighbor in axes(overlaps, 3), n in 1:num_wannier
        b_cartesian = _wannier90_reference_edge_b_cartesian(representation, mmn, neighbor, kpoint)
        brn = 0.0
        for direction in 1:3
            brn += b_cartesian[direction] * centers[n, direction]
        end
        phase = centered_phases[n, neighbor, kpoint]
        # The locked gfortran -O3 Wannier90 4.0.1 build contracts the
        # `om_d = om_d + wb * (ln_tmp + brn)^2` assignment.  The uncontracted
        # Julia expression first differs at Cr U17 by one ULP and the
        # parabolic step amplifies that bit into a different FR trajectory.
        # Make the reference backend's scalar assignment explicit; other
        # localization algorithms keep their established arithmetic.
        omega_d = _wannier90_reference_omega_d_accumulate(omega_d, weights[neighbor], phase + brn)
    end
    omega_d /= nk
    total = omega_invariant + omega_d + omega_od
    if lowercase(strip(get(ENV, "WANNIERNLQG_W90_REFERENCE_DEBUG_COMPONENTS", "0"))) in
       ("1", "true", "yes")
        println(
            stderr,
            "W90REF_SPREAD_COMPONENTS omega_i=$(repr(omega_invariant)) omega_d=$(repr(omega_d)) " *
            "omega_od=$(repr(omega_od)) total=$(repr(total))",
        )
    end
    return total
end

"""
Evaluate the MV objective in the same centered full-mesh phase chart used by
the production gradient.

The previous centers select a local lattice image.  Every diagonal link uses
`Arg(M_nn*exp(i*b*r_old))`; the resulting center increment is left unwrapped.
Unlike the legacy IBZ shortcut, this full-mesh sum remains paired with the
full-mesh gradient when a finite-cutoff Type-IV orbit straddles the principal
phase cut.  Magnetic symmetrization is applied only after the complete sum, so
principal-branch selection never occurs after star averaging.
"""
function _mv_centered_full_mesh_centers_spreads_and_directions(
    frames::Vector{Matrix{ComplexF64}},
    phase_reference_centers::Matrix{Float64},
    representation::BandRepresentation,
    mmn::WannierMMN,
    weights::Vector{Float64},
    plan::WannierSymmetryPlan,
    ;
    return_link_components::Bool = false,
    parallel::Symbol = :serial,
    compensated::Bool = true,
    localized_overlaps::Union{Nothing, Array{ComplexF64, 4}} = nothing,
)
    nk = length(frames)
    num_wannier = size(first(frames), 2)
    center_delta = zeros(Float64, num_wannier, 3)
    center_compensation = zeros(Float64, num_wannier, 3)
    r_squared = zeros(Float64, num_wannier)
    r_squared_compensation = zeros(Float64, num_wannier)
    r_squared_directional = zeros(Float64, num_wannier, 3)
    directional_compensation = zeros(Float64, num_wannier, 3)
    retain_reference_links = return_link_components || !compensated
    centered_phases =
        retain_reference_links ? zeros(Float64, num_wannier, mmn.num_neighbors, nk) : nothing
    diagonal_norms_squared =
        retain_reference_links ? zeros(Float64, num_wannier, mmn.num_neighbors, nk) : nothing
    reference_b_cartesian =
        !compensated ? Array{Vector{Float64}}(undef, mmn.num_neighbors, nk) : nothing
    mpi_overlaps =
        localized_overlaps === nothing ? _mpi_localization_edge_overlaps(frames, mmn, parallel) :
        localized_overlaps
    for kpoint in eachindex(frames)
        for neighbor in 1:mmn.num_neighbors
            target = mmn.neighbors[neighbor, kpoint]
            overlap =
                mpi_overlaps === nothing ?
                frames[kpoint]' * @view(mmn.data[:, :, neighbor, kpoint]) * frames[target] :
                @view(mpi_overlaps[:, :, neighbor, kpoint])
            displacement = _mesh_neighbor_displacement(representation, mmn, neighbor, kpoint)
            b_cartesian =
                compensated ? transpose(representation.reciprocal_lattice) * displacement :
                _wannier90_reference_edge_b_cartesian(representation, mmn, neighbor, kpoint)
            compensated ||
                (something(reference_b_cartesian)[neighbor, kpoint] = Vector(b_cartesian))
            direction_norm = sum(abs2, b_cartesian)
            prefactor = weights[neighbor] / nk
            for wannier in 1:num_wannier
                diagonal = overlap[wannier, wannier]
                phased_diagonal =
                    diagonal * cis(dot(@view(phase_reference_centers[wannier, :]), b_cartesian))
                centered_phase =
                    compensated ? angle(phased_diagonal) :
                    _wannier90_reference_phase(phased_diagonal)
                if retain_reference_links
                    something(centered_phases)[wannier, neighbor, kpoint] = centered_phase
                    something(diagonal_norms_squared)[wannier, neighbor, kpoint] = abs2(diagonal)
                end
                if compensated
                    for direction in 1:3
                        increment = -prefactor * centered_phase * b_cartesian[direction]
                        corrected = increment - center_compensation[wannier, direction]
                        updated = center_delta[wannier, direction] + corrected
                        center_compensation[wannier, direction] =
                            (updated - center_delta[wannier, direction]) - corrected
                        center_delta[wannier, direction] = updated
                    end
                    scalar_contribution = prefactor * (1.0 - abs2(diagonal) + centered_phase^2)
                    corrected_scalar = scalar_contribution - r_squared_compensation[wannier]
                    updated_scalar = r_squared[wannier] + corrected_scalar
                    r_squared_compensation[wannier] =
                        (updated_scalar - r_squared[wannier]) - corrected_scalar
                    r_squared[wannier] = updated_scalar
                    if direction_norm > eps(Float64)
                        for direction in 1:3
                            increment =
                                scalar_contribution * abs2(b_cartesian[direction]) / direction_norm
                            corrected = increment - directional_compensation[wannier, direction]
                            updated = r_squared_directional[wannier, direction] + corrected
                            directional_compensation[wannier, direction] =
                                (updated - r_squared_directional[wannier, direction]) - corrected
                            r_squared_directional[wannier, direction] = updated
                        end
                    end
                end
            end
        end
    end
    if !compensated
        # Wannier90 4.0.1 `wann_omega` deliberately uses different loop nests
        # for r_n and <r^2>_n.  Preserve those scalar assignment sequences:
        # the resulting last-bit differences otherwise perturb the parabolic
        # step and are amplified by the subsequent Fletcher--Reeves history.
        for wannier in 1:num_wannier, direction in 1:3
            for kpoint in 1:nk, neighbor in 1:mmn.num_neighbors
                # gfortran -O3 contracts the `wann_omega` assignment as
                # `(weight * b) * phase + accumulator`.  `wann_domega` uses a
                # distinct grouping reconstructed below; sharing either center
                # would perturb the Fletcher--Reeves trajectory.
                center_delta[wannier, direction] = _wannier90_reference_objective_center_accumulate(
                    center_delta[wannier, direction],
                    weights[neighbor],
                    something(reference_b_cartesian)[neighbor, kpoint][direction],
                    something(centered_phases)[wannier, neighbor, kpoint],
                )
            end
            center_delta[wannier, direction] = -center_delta[wannier, direction] / nk
        end
        for wannier in 1:num_wannier
            for kpoint in 1:nk, neighbor in 1:mmn.num_neighbors
                phase = something(centered_phases)[wannier, neighbor, kpoint]
                scalar_contribution =
                    weights[neighbor] *
                    (1.0 - something(diagonal_norms_squared)[wannier, neighbor, kpoint] + phase^2)
                r_squared[wannier] += scalar_contribution
                b_cartesian = something(reference_b_cartesian)[neighbor, kpoint]
                direction_norm = sum(abs2, b_cartesian)
                if direction_norm > eps(Float64)
                    for direction in 1:3
                        r_squared_directional[wannier, direction] +=
                            scalar_contribution * abs2(b_cartesian[direction]) / direction_norm
                    end
                end
            end
            r_squared[wannier] /= nk
            @views r_squared_directional[wannier, :] ./= nk
        end
    end
    # The Wannier90 reference branch is ordinary no-symmetry localization.
    # Sending its Cartesian `rave` through the generic symmetry helper performs
    # an unnecessary Cartesian -> fractional -> Cartesian round trip even for
    # the identity operation.  That round trip is absent from `wann_omega` and
    # perturbs `rnkb` enough to change the FR parabola after a few steps.
    centers =
        !compensated ? phase_reference_centers + center_delta :
        _symmetrize_wannier_property(phase_reference_centers + center_delta, representation, plan)
    center_delta = centers - phase_reference_centers
    raw_spreads = r_squared - vec(sum(abs2, center_delta; dims = 2))
    spreads =
        !compensated ? raw_spreads : _symmetrize_wannier_property(raw_spreads, representation, plan)
    directional = vec(sum(r_squared_directional .- abs2.(center_delta); dims = 1))
    directional_tuple = (directional[1], directional[2], directional[3])
    ordinary = (centers, spreads, directional_tuple)
    return return_link_components ?
           (
        centers = centers,
        spreads = spreads,
        directional = directional_tuple,
        centered_phases = something(centered_phases),
        diagonal_norms_squared = something(diagonal_norms_squared),
    ) : ordinary
end

"""
Reconstruct the distinct `wann_domega` center increment used by the gradient.

Wannier90 intentionally evaluates the spread center in `wann_omega` and the
gradient center in `wann_domega` with different multiplication grouping.  A
single shared center is algebraically equivalent but not Float64 trajectory
equivalent after the Fletcher--Reeves parabola amplifies the final bits.
"""
function _wannier90_reference_gradient_center_delta(
    centered_phases::Array{Float64, 3},
    representation::BandRepresentation,
    mmn::WannierMMN,
    weights::Vector{Float64},
)
    num_wannier, num_neighbors, nk = size(centered_phases)
    num_neighbors == mmn.num_neighbors ||
        throw(DimensionMismatch("gradient-center neighbor count disagrees"))
    nk == mmn.num_kpts || throw(DimensionMismatch("gradient-center k mesh disagrees"))
    length(weights) == num_neighbors || throw(DimensionMismatch("gradient-center weights disagree"))
    center_delta = zeros(Float64, num_wannier, 3)
    for wannier in 1:num_wannier, direction in 1:3
        for kpoint in 1:nk, neighbor in 1:num_neighbors
            b_cartesian =
                _wannier90_reference_edge_b_cartesian(representation, mmn, neighbor, kpoint)
            weighted_phase = weights[neighbor] * centered_phases[wannier, neighbor, kpoint]
            center_delta[wannier, direction] = _wannier90_reference_gradient_center_accumulate(
                center_delta[wannier, direction],
                b_cartesian[direction],
                weighted_phase,
            )
        end
        center_delta[wannier, direction] = -center_delta[wannier, direction] / nk
    end
    return center_delta
end

# Evaluate one solver iterate with either the SAWF or ordinary full-BZ contract.
function _solver_centers_spreads_and_directions(
    config::SymmetryAdaptedWannierizationConfig,
    frames::Vector{Matrix{ComplexF64}},
    previous_centers::Matrix{Float64},
    representation::BandRepresentation,
    mmn::WannierMMN,
    weights::Vector{Float64},
    plan::WannierSymmetryPlan,
    localized_overlaps::Union{Nothing, Array{ComplexF64, 4}} = nothing,
)
    return !symmetry_constraints_applied(config, representation) ?
           _evaluate_full_mesh_centers_spreads_and_directions(
        frames,
        previous_centers,
        representation,
        mmn,
        weights,
        localized_overlaps,
    ) :
           _centers_spreads_and_directions(
        frames,
        previous_centers,
        representation,
        mmn,
        weights,
        plan,
    )
end

"""
    evaluate_full_3d_wannier_spreads(v_matrix, centers, representation, mmn, plan)

Independently rebuild the complete `I₃` stencil and evaluate WCCs, per-Wannier
quadratic spreads, and Cartesian directional totals from the complete BZ in one
supplied gauge. Input centers only select the equivalent lattice image returned
for each WCC; neither target-representation symmetrization nor solver state is
used. Directional totals must reconstruct the full total within
`1e-10 Angstrom^2`.
"""
function evaluate_full_3d_wannier_spreads(
    v_matrix::Array{ComplexF64, 3},
    centers_cartesian::AbstractMatrix{<:Real},
    representation::BandRepresentation,
    mmn::WannierMMN,
    plan::WannierSymmetryPlan;
    stencil::Union{Nothing, WannierizationFiniteDifferenceStencil} = nothing,
)
    size(v_matrix, 1) == size(representation.energies_ev, 1) ||
        throw(ArgumentError("v_matrix band dimension disagrees with representation"))
    size(v_matrix, 3) == size(representation.energies_ev, 2) ||
        throw(ArgumentError("v_matrix k-point dimension disagrees with representation"))
    centers = Matrix{Float64}(centers_cartesian)
    size(centers) == (size(v_matrix, 2), 3) ||
        throw(ArgumentError("centers must have size (num_wannier, 3)"))
    size(plan.representation_matrices, 1) == size(v_matrix, 2) ||
        throw(ArgumentError("Wannier symmetry plan dimension disagrees with v_matrix"))
    stencil = stencil === nothing ? _finite_difference_weights(representation, mmn) : stencil
    length(stencil.weights) == mmn.num_neighbors ||
        throw(DimensionMismatch("retained stencil neighbor count differs"))
    all(isfinite, stencil.weights) || throw(ArgumentError("retained stencil is nonfinite"))
    frames = [Matrix{ComplexF64}(@view v_matrix[:, :, kpoint]) for kpoint in axes(v_matrix, 3)]
    evaluated_centers, spreads, directional = _evaluate_full_mesh_centers_spreads_and_directions(
        frames,
        centers,
        representation,
        mmn,
        stencil.weights,
    )
    total = sum(spreads)
    abs(sum(directional) - total) <= 1.0e-10 ||
        throw(ArgumentError("directional spread components do not reconstruct the full-3D total"))
    return (
        centers_cartesian = evaluated_centers,
        spreads_angstrom2 = spreads,
        omega_directional = directional,
        omega_total = total,
        stencil = stencil,
    )
end

"""Evaluate the complete full-3D spread contract from a retained SAWF result."""
function evaluate_full_3d_wannier_spreads(
    result::WannierizationResult,
    representation::BandRepresentation,
    mmn::WannierMMN,
    plan::WannierSymmetryPlan,
)
    return evaluate_full_3d_wannier_spreads(
        result.v_matrix,
        result.wannier_centers_cartesian,
        representation,
        mmn,
        plan;
        stencil = result.restart_state === nothing ? nothing :
                  something(result.restart_state).stencil,
    )
end

# Maximum Frobenius projector change over the complete mesh.
function _maximum_projector_step(
    old_frames::Vector{Matrix{ComplexF64}},
    new_frames::Vector{Matrix{ComplexF64}},
)
    return maximum(
        norm(new_frames[k] * new_frames[k]' - old_frames[k] * old_frames[k]') for
        k in eachindex(old_frames)
    )
end

# Measure drift from the immutable two-stage boundary projectors.
function _maximum_projector_drift(
    frames::Vector{Matrix{ComplexF64}},
    reference_projectors::Vector{Matrix{ComplexF64}},
)
    length(frames) == length(reference_projectors) || return Inf
    return maximum(
        norm(frames[kpoint] * frames[kpoint]' - reference_projectors[kpoint]) for
        kpoint in eachindex(frames)
    )
end

# Maximum geodesic U change measured in a fixed selected subspace.
function _maximum_unitary_step(
    subspaces::Vector{Matrix{ComplexF64}},
    old_frames::Vector{Matrix{ComplexF64}},
    new_frames::Vector{Matrix{ComplexF64}},
    tolerance::Float64,
)
    maximum_step = 0.0
    for kpoint in eachindex(subspaces)
        old_u = _orthonormalize_columns(subspaces[kpoint]' * old_frames[kpoint], tolerance)
        new_u = _orthonormalize_columns(subspaces[kpoint]' * new_frames[kpoint], tolerance)
        (old_u === nothing || new_u === nothing) && return Inf
        change = _orthonormalize_columns(old_u' * new_u, tolerance)
        change === nothing && return Inf
        maximum_step = max(maximum_step, norm(angle.(eigvals(change))))
    end
    return maximum_step
end

# Minimum-image Cartesian center step, preserving the declared row lattice.
function _maximum_wcc_step(
    old_centers::Matrix{Float64},
    new_centers::Matrix{Float64},
    real_lattice::Matrix{Float64},
)
    fractional = (new_centers - old_centers) * inv(real_lattice)
    fractional .-= round.(fractional)
    cartesian = fractional * real_lattice
    return maximum(norm(@view cartesian[row, :]) for row in axes(cartesian, 1))
end

# Smallest selected/unselected Z eigenvalue gap on the irreducible mesh.
function _minimum_z_boundary_gap(
    z_field::Vector{Matrix{ComplexF64}},
    outer_indices::Vector{Vector{Int}},
    irreducible_indices::Vector{Int},
    num_wannier::Int,
    ;
    tolerance::Float64 = 1.0e-10,
    audit::Union{Nothing, HermitianSpectrumAudit} = nothing,
)
    minimum_gap = Inf
    for kpoint in irreducible_indices
        outer = outer_indices[kpoint]
        length(outer) > num_wannier || continue
        block = Matrix{ComplexF64}(@view z_field[kpoint][outer, outer])
        decomposition = _validated_hermitian_spectrum(
            block;
            tolerance,
            context = "z_boundary_gap:kpoint=$(kpoint)",
            audit,
        )
        decomposition.success || throw(
            ArgumentError(
                "HERMITIAN_SPECTRAL_DECOMPOSITION_FAILED at Z-boundary k-point $(kpoint)",
            ),
        )
        values = sort!(copy(decomposition.values); rev = true)
        length(values) > num_wannier || throw(
            DimensionMismatch(
                "Z boundary spectrum is too short at k-point $(kpoint): " *
                "matrix=$(size(z_field[kpoint])) outer=$(length(outer)) " *
                "eigenvalues=$(length(values)) num_wannier=$(num_wannier)",
            ),
        )
        minimum_gap = min(minimum_gap, values[num_wannier] - values[num_wannier + 1])
    end
    return minimum_gap
end

# Return a population standard deviation without loading Statistics in the facade.
function _population_standard_deviation(values::AbstractVector{<:Real})
    mean_value = sum(values) / length(values)
    return sqrt(sum((value - mean_value)^2 for value in values) / length(values))
end

"""Cached real-linear little-group tangent for one IBZ representative."""
struct TargetSymmetryTangentPlan
    dimension::Int
    basis::Matrix{Float64}
    constraint_rank::Int
    maximum_basis_residual::Float64
end

"""Pack a complex matrix into the real coordinate vector used by commutant constraints."""
_pack_complex_real(matrix::AbstractMatrix{<:Complex}) = vcat(vec(real.(matrix)), vec(imag.(matrix)))

"""Recover a complex square matrix from its packed real coordinate vector."""
function _unpack_complex_real(values::AbstractVector{<:Real}, dimension::Int)
    count = dimension^2
    length(values) == 2count || throw(DimensionMismatch("complex real-vector size disagrees"))
    return reshape(values[1:count], dimension, dimension) .+
           1.0im .* reshape(values[(count + 1):(2count)], dimension, dimension)
end

# Direct SVD polar factor for the localization fixed point.  This is
# algebraically equivalent to orthonormalizing inv(M)' when M is regular, but
# it never forms an inverse and has explicit rank/condition fail-stop gates.
function _localization_svd_polar(
    matrix::AbstractMatrix{<:Complex},
    relative_tolerance::Float64,
    maximum_condition::Float64,
)
    size(matrix, 1) == size(matrix, 2) || return (
        success = false,
        code = :LOCALIZATION_POLAR_RANK_DEFICIENT,
        unitary = zeros(ComplexF64, size(matrix)...),
        singular_values = Float64[],
        rank = 0,
        condition = Inf,
    )
    all(isfinite, matrix) || return (
        success = false,
        code = :LOCALIZATION_POLAR_RANK_DEFICIENT,
        unitary = zeros(ComplexF64, size(matrix)...),
        singular_values = Float64[],
        rank = 0,
        condition = Inf,
    )
    decomposition = svd(Matrix{ComplexF64}(matrix))
    singular_values = Float64.(decomposition.S)
    sigma_max = isempty(singular_values) ? 0.0 : maximum(singular_values)
    rank =
        sigma_max == 0.0 ? 0 :
        count(value -> value / sigma_max >= relative_tolerance, singular_values)
    condition = rank == size(matrix, 1) ? sigma_max / minimum(singular_values) : Inf
    if rank != size(matrix, 1)
        return (
            success = false,
            code = :LOCALIZATION_POLAR_RANK_DEFICIENT,
            unitary = zeros(ComplexF64, size(matrix)...),
            singular_values = singular_values,
            rank = rank,
            condition = condition,
        )
    elseif !isfinite(condition) || condition > maximum_condition
        return (
            success = false,
            code = :LOCALIZATION_POLAR_ILL_CONDITIONED,
            unitary = zeros(ComplexF64, size(matrix)...),
            singular_values = singular_values,
            rank = rank,
            condition = condition,
        )
    end
    unitary = Matrix{ComplexF64}(decomposition.U * decomposition.Vt)
    return (
        success = true,
        code = :OK,
        unitary = unitary,
        singular_values = singular_values,
        rank = rank,
        condition = condition,
    )
end

# Preserve every right singular vector while omitting unused tall-matrix left vectors.
# Wide constraints need full V to retain the structural right nullspace.
_target_tangent_constraint_svd(constraints::AbstractMatrix) =
    svd(constraints; full = size(constraints, 1) < size(constraints, 2))

# Construct the exact real-linear Type-I/II/III/IV little-group tangent.
# Antiunitary conditions are real-linear because the tangent is conjugated.
# Frozen bands do not enter this target-space plan: they constrain the selected
# band subspace, not rotations within that subspace.
function _target_symmetry_tangent_plan(
    matrices::Vector{Matrix{ComplexF64}},
    antiunitary::Vector{Bool};
    tolerance::Float64 = 1.0e-10,
    construction_policy::Symbol = :strict,
)
    length(matrices) == length(antiunitary) ||
        throw(DimensionMismatch("target tangent operation inventory disagrees"))
    isempty(matrices) && throw(ArgumentError("target tangent operation inventory is empty"))
    dimension = size(first(matrices), 1)
    all(matrix -> size(matrix) == (dimension, dimension), matrices) ||
        throw(DimensionMismatch("target tangent matrices disagree in dimension"))
    variable_count = 2dimension^2
    residual_count = 2dimension^2 * length(matrices)
    constraints = Matrix{Float64}(undef, residual_count, variable_count)
    for coordinate in 1:variable_count
        values = zeros(Float64, variable_count)
        values[coordinate] = 1.0
        q = _unpack_complex_real(values, dimension)
        residuals = Float64[]
        for (matrix, is_antiunitary) in zip(matrices, antiunitary)
            transformed = is_antiunitary ? matrix * conj(q) - q * matrix : matrix * q - q * matrix
            append!(residuals, _pack_complex_real(transformed))
        end
        constraints[:, coordinate] .= residuals
    end
    decomposition = _target_tangent_constraint_svd(constraints)
    sigma_max = isempty(decomposition.S) ? 0.0 : maximum(decomposition.S)
    rank = sigma_max == 0.0 ? 0 : count(value -> value / sigma_max >= tolerance, decomposition.S)
    basis = Matrix{Float64}(decomposition.V[:, (rank + 1):end])
    isempty(basis) && throw(ArgumentError("target symmetry tangent nullspace is empty"))
    maximum_residual = maximum(abs, constraints * basis)
    isfinite(maximum_residual) || throw(ArgumentError("target symmetry tangent is nonfinite"))
    construction_policy == :diagnostic ||
        maximum_residual <= 64tolerance ||
        throw(
            ArgumentError("target symmetry tangent residual $(maximum_residual) exceeds tolerance"),
        )
    return TargetSymmetryTangentPlan(dimension, basis, rank, maximum_residual)
end

"""Orthogonally project a target-space matrix onto a cached real-linear tangent."""
function _project_target_symmetry_tangent(
    plan::TargetSymmetryTangentPlan,
    matrix::AbstractMatrix{<:Complex},
)
    size(matrix) == (plan.dimension, plan.dimension) ||
        throw(DimensionMismatch("target tangent projection dimension disagrees"))
    packed = _pack_complex_real(matrix)
    return _unpack_complex_real(plan.basis * (plan.basis' * packed), plan.dimension)
end

"""Build one little-group tangent plan per IBZ representative."""
function _build_target_symmetry_tangent_plans(
    representation::BandRepresentation,
    plan::WannierSymmetryPlan;
    tolerance::Float64 = 1.0e-10,
    construction_policy::Symbol = :strict,
)
    operation_mapping, inventory_diagnostics =
        validate_target_operation_inventory(representation, plan, tolerance)
    isempty(inventory_diagnostics) ||
        throw(ArgumentError("cannot build target tangent from mismatched operation inventories"))
    output = Vector{Union{Nothing, TargetSymmetryTangentPlan}}(
        undef,
        size(representation.energies_ev, 2),
    )
    fill!(output, nothing)
    for representative in representation.irreducible_indices
        matrices = Matrix{ComplexF64}[]
        antiunitary = Bool[]
        for operation_index in eachindex(representation.operations)
            representation.kpoint_map[operation_index, representative] == representative || continue
            push!(
                matrices,
                target_representation(
                    plan,
                    representation,
                    operation_index,
                    representative,
                    operation_mapping[operation_index],
                ),
            )
            push!(antiunitary, representation.operations[operation_index].antiunitary)
        end
        isempty(matrices) && throw(ArgumentError("IBZ representative has an empty little group"))
        output[representative] =
            _target_symmetry_tangent_plan(matrices, antiunitary; tolerance, construction_policy)
    end
    return output
end

# Branch-safe unitary geodesic based on a complex Schur decomposition.  The
# returned phases define one continuous generator; points too close to -1 fail
# closed because the principal logarithm has no deterministic branch there.
function _unitary_geodesic_plan(
    old_unitary::Matrix{ComplexF64},
    new_unitary::Matrix{ComplexF64},
    tolerance::Float64,
)
    change_polar = _localization_svd_polar(old_unitary' * new_unitary, tolerance, 1.0e10)
    change_polar.success || return (
        success = false,
        code = :SINGULAR_U_MIXING,
        vectors = zeros(ComplexF64, size(old_unitary)...),
        phases = Float64[],
        distance = Inf,
        maximum_phase = Inf,
    )
    decomposition = schur(change_polar.unitary)
    values = diag(decomposition.T)
    phases = angle.(values)
    branch_margin = max(1.0e-8, 10tolerance)
    if any(
        index -> real(values[index]) < 0.0 && abs(imag(values[index])) <= branch_margin,
        eachindex(values),
    )
        return (
            success = false,
            code = :U_GEODESIC_BRANCH_AMBIGUOUS,
            vectors = Matrix{ComplexF64}(decomposition.Z),
            phases = Float64.(phases),
            distance = norm(phases),
            maximum_phase = maximum(abs, phases),
        )
    end
    return (
        success = true,
        code = :OK,
        vectors = Matrix{ComplexF64}(decomposition.Z),
        phases = Float64.(phases),
        distance = norm(phases),
        maximum_phase = isempty(phases) ? 0.0 : maximum(abs, phases),
    )
end

"""Retract one scaled branch-safe geodesic step to the unitary manifold."""
function _unitary_geodesic_step(
    old_unitary::Matrix{ComplexF64},
    geodesic,
    scale::Float64,
    tolerance::Float64,
)
    mixed =
        old_unitary *
        geodesic.vectors *
        Diagonal(cis.(scale .* geodesic.phases)) *
        geodesic.vectors'
    polar = _localization_svd_polar(mixed, tolerance, 1.0e10)
    return polar.success ? polar.unitary : nothing
end

"""Measure the physical frame rotation without continuous gauge alignment."""
function _frame_geodesic_distance(
    old_frame::Matrix{ComplexF64},
    new_frame::Matrix{ComplexF64},
    tolerance::Float64;
)
    overlap = _localization_svd_polar(old_frame' * new_frame, tolerance, 1.0e10)
    overlap.success || return Inf
    return norm(angle.(eigvals(overlap.unitary)))
end

"""Record deterministic equivalent-block assignment and matched overlap phases."""
function _permutation_phase_diagnostic(
    old_unitary::Matrix{ComplexF64},
    aligned_unitary::Matrix{ComplexF64},
)
    overlap = old_unitary' * aligned_unitary
    permutation = hungarian_maximum_assignment(abs.(overlap))
    phases = [angle(overlap[row, permutation[row]]) for row in eachindex(permutation)]
    return permutation, phases
end

"""
Diagnose one k-independent orbital permutation and one global phase per orbital.

This is deliberately read-only: the returned transformation is never applied
to solver frames, objectives, gradients, or convergence tests.
"""
function _global_permutation_phase_diagnostic(
    old_frames::Vector{Matrix{ComplexF64}},
    new_frames::Vector{Matrix{ComplexF64}},
)
    length(old_frames) == length(new_frames) ||
        throw(DimensionMismatch("global permutation diagnostic mesh disagrees"))
    dimension = size(first(old_frames), 2)
    accumulated = zeros(ComplexF64, dimension, dimension)
    weights = zeros(Float64, dimension, dimension)
    for (old_frame, new_frame) in zip(old_frames, new_frames)
        overlap = old_frame' * new_frame
        accumulated .+= overlap
        weights .+= abs.(overlap)
    end
    permutation = hungarian_maximum_assignment(weights)
    phases = [angle(accumulated[row, permutation[row]]) for row in 1:dimension]
    return permutation, phases
end

"""Classify a 50-step U trajectory using the frozen protocol thresholds."""
function classify_wannierization_u_periodicity(
    one_step_distance::AbstractVector{<:Real},
    two_step_distance::AbstractVector{<:Real},
    aligned_one_step_distance::AbstractVector{<:Real},
)
    minimum((
        length(one_step_distance),
        length(two_step_distance),
        length(aligned_one_step_distance),
    )) >= 50 || return :PERIOD_UNDETERMINED
    indices = 41:50
    period_two = count(
        index ->
            one_step_distance[index] >= 1.0e-6 &&
            two_step_distance[index] <= 1.0e-2 * one_step_distance[index],
        indices,
    )
    return period_two >= 8 ? :PERIOD_2_CONFIRMED : :PERIOD_2_NOT_CONFIRMED
end

# Gauge-dependent Marzari-Vanderbilt spread gradient (A[R]-S[T]), evaluated
# on the complete mesh before restricting the update to the IBZ.
"""
    _mv_localization_phase(diagonal, center, b_cartesian)

Return the Marzari--Vanderbilt localization phase
`arg(diagonal) + b_cartesian⋅center`.  `arg(diagonal)` uses the principal
branch selected by `angle`; the subsequent addition of the already unwrapped
Wannier center is not wrapped again.  Branch-safe line search therefore tracks
only the principal-log branch of the diagonal overlap.
"""
function _mv_localization_phase(
    diagonal::Complex,
    center::AbstractVector{<:Real},
    b_cartesian::AbstractVector{<:Real},
)
    return angle(diagonal) + dot(center, b_cartesian)
end

# Evaluate the gauge-dependent MV descent field on the complete mesh before
# restricting a symmetry-constrained update to the IBZ.
function _mv_spread_gradient(
    frames::Vector{Matrix{ComplexF64}},
    centers::Matrix{Float64},
    representation::BandRepresentation,
    mmn::WannierMMN,
    weights::Vector{Float64},
    tolerance::Float64,
)
    nk = length(frames)
    num_wannier = size(frames[1], 2)
    gradients = [zeros(ComplexF64, num_wannier, num_wannier) for _ in 1:nk]
    for kpoint in eachindex(frames)
        gradient = gradients[kpoint]
        for neighbor in 1:mmn.num_neighbors
            target = mmn.neighbors[neighbor, kpoint]
            overlap = frames[kpoint]' * @view(mmn.data[:, :, neighbor, kpoint]) * frames[target]
            displacement = _mesh_neighbor_displacement(representation, mmn, neighbor, kpoint)
            b_cartesian = transpose(representation.reciprocal_lattice) * displacement
            cr = zeros(ComplexF64, num_wannier, num_wannier)
            crt = zeros(ComplexF64, num_wannier, num_wannier)
            q = zeros(Float64, num_wannier)
            for wannier in 1:num_wannier
                diagonal = overlap[wannier, wannier]
                abs(diagonal) > tolerance || return (
                    success = false,
                    code = :SPREAD_GRADIENT_DIAGONAL_OVERLAP_SINGULAR,
                    gradients = gradients,
                    kpoint = kpoint,
                    neighbor = neighbor,
                    wannier = wannier,
                    minimum_diagonal_overlap = abs(diagonal),
                )
                cr[:, wannier] .= overlap[:, wannier] .* conj(diagonal)
                crt[:, wannier] .= overlap[:, wannier] ./ diagonal
                q[wannier] =
                    weights[neighbor] *
                    _mv_localization_phase(diagonal, @view(centers[wannier, :]), b_cartesian)
            end
            gradient .+= weights[neighbor] .* (cr - cr') ./ 2
            t_matrix = crt * Diagonal(q)
            gradient .+= (1.0im / 2) .* (t_matrix + t_matrix')
        end
        gradient .*= 4.0 / nk
        gradient .= (gradient - gradient') ./ 2
    end
    return (
        success = true,
        code = :OK,
        gradients = gradients,
        kpoint = 0,
        neighbor = 0,
        wannier = 0,
        minimum_diagonal_overlap = Inf,
    )
end

"""
Pull a target-space tangent from a full-mesh star member to its IBZ representative.

Frames obey `F_t = B_g K(F_r) D_g†`; therefore their right-acting tangent obeys
`A_t = D_g K(A_r) D_g†` and is pulled back by the inverse relation below.
"""
function _pull_target_tangent_to_representative(
    tangent::Matrix{ComplexF64},
    target::Matrix{ComplexF64},
    antiunitary::Bool,
)
    pulled = target' * tangent * target
    return antiunitary ? conj(pulled) : pulled
end

"""Expand one IBZ target-space tangent deterministically to the complete k star."""
function _expand_ibz_target_tangents(
    tangents::Vector{Matrix{ComplexF64}},
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
)
    operation_mapping, inventory_diagnostics =
        validate_target_operation_inventory(representation, plan, 1.0e-10)
    isempty(inventory_diagnostics) ||
        throw(ArgumentError("cannot expand tangents from mismatched operation inventories"))
    expanded = deepcopy(tangents)
    for target_kpoint in eachindex(tangents)
        ibz_index = representation.full_to_irreducible[target_kpoint]
        representative = representation.irreducible_indices[ibz_index]
        operation_index = representation.full_to_operation[target_kpoint]
        representation.kpoint_map[operation_index, representative] == target_kpoint ||
            throw(ArgumentError("stored k-star operation does not reach its tangent target"))
        target = target_representation(
            plan,
            representation,
            operation_index,
            representative,
            operation_mapping[operation_index],
        )
        source = tangents[representative]
        action = representation.operations[operation_index].antiunitary ? conj(source) : source
        expanded[target_kpoint] = target * action * target'
    end
    return expanded
end

"""
Project the complete-mesh MV descent field onto the magnetic-symmetry tangent.

The full-star field is first pulled back and averaged at each IBZ representative,
then little-group projected and anti-Hermitianized.  No frozen-Wannier projector
or new/old-frame alignment enters this operation.
"""
function _symmetry_projected_spread_gradient(
    raw_gradients::Vector{Matrix{ComplexF64}},
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    tangent_plans::Vector{Union{Nothing, TargetSymmetryTangentPlan}},
)
    length(raw_gradients) == size(representation.energies_ev, 2) ||
        throw(DimensionMismatch("gradient mesh disagrees with the representation"))
    operation_mapping, inventory_diagnostics =
        validate_target_operation_inventory(representation, plan, 1.0e-10)
    isempty(inventory_diagnostics) ||
        throw(ArgumentError("cannot project gradients from mismatched operation inventories"))
    dimension = size(first(raw_gradients), 1)
    representative_gradients =
        [zeros(ComplexF64, dimension, dimension) for _ in eachindex(raw_gradients)]
    star_counts = zeros(Int, length(raw_gradients))
    for target_kpoint in eachindex(raw_gradients)
        ibz_index = representation.full_to_irreducible[target_kpoint]
        representative = representation.irreducible_indices[ibz_index]
        operation_index = representation.full_to_operation[target_kpoint]
        target = target_representation(
            plan,
            representation,
            operation_index,
            representative,
            operation_mapping[operation_index],
        )
        representative_gradients[representative] .+= _pull_target_tangent_to_representative(
            raw_gradients[target_kpoint],
            target,
            representation.operations[operation_index].antiunitary,
        )
        star_counts[representative] += 1
    end
    for representative in representation.irreducible_indices
        star_counts[representative] > 0 ||
            throw(ArgumentError("IBZ representative has an empty full-mesh star"))
        star_average = representative_gradients[representative] ./ star_counts[representative]
        tangent_plan = tangent_plans[representative]
        tangent_plan === nothing && error("missing target symmetry tangent plan")
        projected = _project_target_symmetry_tangent(something(tangent_plan), star_average)
        projected = (projected - projected') ./ 2
        projected = _project_target_symmetry_tangent(something(tangent_plan), projected)
        representative_gradients[representative] = (projected - projected') ./ 2
    end
    full_gradients = _expand_ibz_target_tangents(representative_gradients, representation, plan)
    norm_squared = sum(sum(abs2, gradient) for gradient in full_gradients)
    rms = sqrt(norm_squared / (length(full_gradients) * dimension^2))
    return (
        representative_gradients = representative_gradients,
        full_gradients = full_gradients,
        norm_squared = norm_squared,
        rms = rms,
    )
end

"""One diagonal MMN link whose centered phase lies in the active cut layer."""
struct MVPhaseBranchLink
    kpoint::Int
    neighbor::Int
    wannier::Int
    phase::Float64
    margin::Float64
    alternative_phase_jump::Float64
end

"""
Single-source evaluation of the MV localization objective and descent field.

`phase_reference_centers` is immutable during one line search.  The centered
principal residual and the unwrapped center increment therefore use one chart:
`phi=Arg(M_nn*exp(i*b*r_old))`, `q=w*(phi+b*Delta_r)`.  The latter sum is never
wrapped.  `representative_gradients` is the minimum-norm Clarke descent field
when one or more Type-IV cut orbits are active and the ordinary smooth descent
field otherwise.
"""
struct MVLocalizationEvaluation
    centers::Matrix{Float64}
    spreads::Vector{Float64}
    directional::Union{Nothing, NTuple{3, Float64}}
    objective::Float64
    centered_phases::Array{Float64, 3}
    diagonal_norms_squared::Array{Float64, 3}
    raw_gradients::Vector{Matrix{ComplexF64}}
    principal_representative_gradients::Vector{Matrix{ComplexF64}}
    principal_full_gradients::Vector{Matrix{ComplexF64}}
    representative_gradients::Vector{Matrix{ComplexF64}}
    full_gradients::Vector{Matrix{ComplexF64}}
    gradient_norm_squared::Float64
    gradient_rms::Float64
    active_links::Vector{MVPhaseBranchLink}
    branch_jump_representatives::Vector{Vector{Matrix{ComplexF64}}}
    branch_jump_full::Vector{Vector{Matrix{ComplexF64}}}
    clarke_coefficients::Vector{Float64}
    active_orbit_digests::Vector{String}
    minimum_phase_margin::Float64
    minimum_phase_kpoint::Int
    minimum_phase_neighbor::Int
    minimum_phase_wannier::Int
    minimum_phase_value::Float64
end

"""Cancellation-safe objective change between evaluations in one center chart."""
function _mv_centered_objective_change(
    base::MVLocalizationEvaluation,
    trial::MVLocalizationEvaluation,
    phase_reference_centers::Matrix{Float64},
    weights::Vector{Float64},
)
    size(base.centered_phases) == size(trial.centered_phases) ||
        throw(DimensionMismatch("centered phase meshes disagree"))
    size(base.diagonal_norms_squared) == size(trial.diagonal_norms_squared) ||
        throw(DimensionMismatch("diagonal-norm meshes disagree"))
    num_wannier, num_neighbors, nk = size(base.centered_phases)
    length(weights) == num_neighbors || throw(DimensionMismatch("neighbor weights disagree"))
    difference = 0.0
    compensation = 0.0
    for kpoint in 1:nk, neighbor in 1:num_neighbors, wannier in 1:num_wannier
        base_phase = base.centered_phases[wannier, neighbor, kpoint]
        trial_phase = trial.centered_phases[wannier, neighbor, kpoint]
        contribution =
            (weights[neighbor] / nk) * (
                base.diagonal_norms_squared[wannier, neighbor, kpoint] -
                trial.diagonal_norms_squared[wannier, neighbor, kpoint] +
                (trial_phase - base_phase) * (trial_phase + base_phase)
            )
        corrected = contribution - compensation
        updated = difference + corrected
        compensation = (updated - difference) - corrected
        difference = updated
    end
    for wannier in 1:num_wannier, direction in 1:3
        base_delta = base.centers[wannier, direction] - phase_reference_centers[wannier, direction]
        trial_delta =
            trial.centers[wannier, direction] - phase_reference_centers[wannier, direction]
        contribution = -(trial_delta - base_delta) * (trial_delta + base_delta)
        corrected = contribution - compensation
        updated = difference + corrected
        compensation = (updated - difference) - corrected
        difference = updated
    end
    return Float64(difference)
end

"""Project a full-mesh descent field with or without magnetic constraints."""
function _project_mv_descent_field(
    raw_gradients::Vector{Matrix{ComplexF64}},
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    tangent_plans::Vector{Union{Nothing, TargetSymmetryTangentPlan}},
    apply_symmetry::Bool,
)
    if apply_symmetry
        return _symmetry_projected_spread_gradient(
            raw_gradients,
            representation,
            plan,
            tangent_plans,
        )
    end
    dimension = size(first(raw_gradients), 1)
    projected = [(value - value') ./ 2 for value in raw_gradients]
    norm_squared = sum(sum(abs2, value) for value in projected)
    return (
        representative_gradients = projected,
        full_gradients = projected,
        norm_squared,
        rms = sqrt(norm_squared / (length(projected) * dimension^2)),
    )
end

"""Real full-mesh inner product used by Clarke and line-search contracts."""
function _full_tangent_inner(left::Vector{Matrix{ComplexF64}}, right::Vector{Matrix{ComplexF64}})
    length(left) == length(right) || throw(DimensionMismatch("tangent meshes disagree"))
    return sum(real(dot(a, b)) for (a, b) in zip(left, right))
end

"""
Stable digest for the discrete link membership of one Type-IV branch orbit.

The projected jump field changes continuously with the accepted frame and must
not define active-set identity: hashing it would reset RCG/L-BFGS history after
every accepted step even when exactly the same cut orbit remains active.  The
identity is therefore the sorted set of `(kpoint, neighbor, wannier, side)`
labels, where `side` records the signed `2pi` alternative branch.
"""
function _mv_branch_orbit_digest(links::Vector{MVPhaseBranchLink})
    buffer = IOBuffer()
    ordered = sort(
        links;
        by = link -> (
            link.kpoint,
            link.neighbor,
            link.wannier,
            signbit(link.alternative_phase_jump) ? -1 : 1,
        ),
    )
    for link in ordered
        side = signbit(link.alternative_phase_jump) ? -1 : 1
        write(buffer, "$(link.kpoint),$(link.neighbor),$(link.wannier),$(side)\n")
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

"""Minimum-norm point in `base + sum(alpha_j*jump_j)`, `0 <= alpha_j <= 1`."""
function _minimum_norm_clarke_combination(
    base::Vector{Matrix{ComplexF64}},
    jumps::Vector{Vector{Matrix{ComplexF64}}},
)
    count = length(jumps)
    count == 0 && return (
        success = true,
        coefficients = Float64[],
        field = deepcopy(base),
        kkt_residual = 0.0,
        iterations = 0,
    )
    gram = zeros(Float64, count, count)
    linear = zeros(Float64, count)
    for row in 1:count
        linear[row] = _full_tangent_inner(base, jumps[row])
        for column in 1:row
            value = _full_tangent_inner(jumps[row], jumps[column])
            gram[row, column] = value
            gram[column, row] = value
        end
    end
    coefficients = zeros(Float64, count)
    scale = max(1.0, maximum(abs, linear), maximum(abs, gram))
    kkt_residual = Inf
    iterations = 0
    for iteration in 1:4096
        iterations = iteration
        maximum_change = 0.0
        for index in 1:count
            denominator = gram[index, index]
            denominator <= eps(Float64) && continue
            residual = linear[index]
            for other in 1:count
                other == index && continue
                residual += gram[index, other] * coefficients[other]
            end
            updated = clamp(-residual / denominator, 0.0, 1.0)
            maximum_change = max(maximum_change, abs(updated - coefficients[index]))
            coefficients[index] = updated
        end
        gradient = linear + gram * coefficients
        kkt_residual =
            maximum(
                index ->
                    coefficients[index] <= 32eps(Float64) ? max(0.0, -gradient[index]) :
                    coefficients[index] >= 1.0 - 32eps(Float64) ? max(0.0, gradient[index]) :
                    abs(gradient[index]),
                eachindex(coefficients),
            ) / scale
        kkt_residual <= 1.0e-12 && break
        maximum_change <= eps(Float64) && break
    end
    field = deepcopy(base)
    for (coefficient, jump) in zip(coefficients, jumps), kpoint in eachindex(field)
        field[kpoint] .+= coefficient .* jump[kpoint]
    end
    return (
        success = kkt_residual <= 1.0e-10,
        coefficients = coefficients,
        field = field,
        kkt_residual,
        iterations,
    )
end

"""Construct the chart-consistent raw MV descent field and branch jumps."""
function _mv_centered_gradient_data(
    frames::Vector{Matrix{ComplexF64}},
    phase_reference_centers::Matrix{Float64},
    center_delta::Matrix{Float64},
    representation::BandRepresentation,
    mmn::WannierMMN,
    weights::Vector{Float64},
    tolerance::Float64,
    branch_tolerance::Float64,
    ;
    parallel::Symbol = :serial,
    localized_overlaps::Union{Nothing, Array{ComplexF64, 4}} = nothing,
    wannier90_arithmetic::Bool = false,
)
    nk = length(frames)
    num_wannier = size(frames[1], 2)
    gradients = [zeros(ComplexF64, num_wannier, num_wannier) for _ in 1:nk]
    active_links = MVPhaseBranchLink[]
    raw_jumps = Vector{Vector{Matrix{ComplexF64}}}()
    crt_cache = Array{Matrix{ComplexF64}}(undef, mmn.num_neighbors, nk)
    b_cartesian_cache = Array{Vector{Float64}}(undef, mmn.num_neighbors, nk)
    minimum_margin = Inf
    minimum_context = (kpoint = 0, neighbor = 0, wannier = 0, phase = NaN)
    mpi_overlaps =
        localized_overlaps === nothing ? _mpi_localization_edge_overlaps(frames, mmn, parallel) :
        localized_overlaps
    for kpoint in eachindex(frames)
        gradient = gradients[kpoint]
        for neighbor in 1:mmn.num_neighbors
            target = mmn.neighbors[neighbor, kpoint]
            overlap =
                mpi_overlaps === nothing ?
                frames[kpoint]' * @view(mmn.data[:, :, neighbor, kpoint]) * frames[target] :
                @view(mpi_overlaps[:, :, neighbor, kpoint])
            displacement = _mesh_neighbor_displacement(representation, mmn, neighbor, kpoint)
            b_cartesian =
                wannier90_arithmetic ?
                _wannier90_reference_edge_b_cartesian(representation, mmn, neighbor, kpoint) :
                transpose(representation.reciprocal_lattice) * displacement
            cr = zeros(ComplexF64, num_wannier, num_wannier)
            crt = zeros(ComplexF64, num_wannier, num_wannier)
            q = zeros(Float64, num_wannier)
            centered_phase_values = zeros(Float64, num_wannier)
            for wannier in 1:num_wannier
                diagonal = overlap[wannier, wannier]
                abs(diagonal) > tolerance || return (
                    success = false,
                    code = :SPREAD_GRADIENT_DIAGONAL_OVERLAP_SINGULAR,
                    kpoint,
                    neighbor,
                    wannier,
                    minimum_diagonal_overlap = abs(diagonal),
                )
                if wannier90_arithmetic
                    # gfortran 16 vectorizes the full-column assignments in
                    # `wann_domega` before entering the scalar (n,m) gradient
                    # loop.  On arm64 the paired SIMD lanes use a different
                    # multiply/add association than Julia's generic complex
                    # `*` and `/`.  Preserve that local numerical contract;
                    # the physical formula and subsequent loop order remain
                    # unchanged.
                    paired_rows = num_wannier - num_wannier % 2
                    for row in 1:paired_rows
                        value = ComplexF64(overlap[row, wannier])
                        cr[row, wannier] =
                            _wannier90_reference_gfortran_column_conjugate_product(value, diagonal)
                        crt[row, wannier] =
                            _wannier90_reference_gfortran_column_division(value, diagonal)
                    end
                    if isodd(num_wannier)
                        # The registered Cr and Wannier90 parity lanes are
                        # even-dimensional.  Retain the language scalar
                        # semantics for the unpaired general-size tail.
                        value = ComplexF64(overlap[end, wannier])
                        cr[end, wannier] = value * conj(diagonal)
                        crt[end, wannier] = value / diagonal
                    end
                else
                    cr[:, wannier] .= overlap[:, wannier] .* conj(diagonal)
                    crt[:, wannier] .= overlap[:, wannier] ./ diagonal
                end
                phased_diagonal =
                    diagonal * cis(dot(@view(phase_reference_centers[wannier, :]), b_cartesian))
                centered_phase =
                    wannier90_arithmetic ? _wannier90_reference_phase(phased_diagonal) :
                    angle(phased_diagonal)
                margin = pi - abs(centered_phase)
                if margin < minimum_margin
                    minimum_margin = margin
                    minimum_context = (
                        kpoint = kpoint,
                        neighbor = neighbor,
                        wannier = wannier,
                        phase = centered_phase,
                    )
                end
                q[wannier] =
                    weights[neighbor] *
                    (centered_phase + dot(@view(center_delta[wannier, :]), b_cartesian))
                centered_phase_values[wannier] = centered_phase
                if margin <= branch_tolerance
                    phase_jump = centered_phase < 0.0 ? 2pi : -2pi
                    push!(
                        active_links,
                        MVPhaseBranchLink(
                            kpoint,
                            neighbor,
                            wannier,
                            centered_phase,
                            margin,
                            phase_jump,
                        ),
                    )
                    jump_field = [zeros(ComplexF64, num_wannier, num_wannier) for _ in 1:nk]
                    jump_t = zeros(ComplexF64, num_wannier, num_wannier)
                    jump_t[:, wannier] .= crt[:, wannier] .* (weights[neighbor] * phase_jump)
                    jump = (1.0im / 2) .* (jump_t + jump_t')
                    jump .*= 4.0 / nk
                    jump_field[kpoint] .= (jump - jump') ./ 2
                    push!(raw_jumps, jump_field)
                end
            end
            if wannier90_arithmetic
                # Preserve the scalar assignment sequence in Wannier90 4.0.1
                # `wann_domega`.  Algebraically fusing these terms into BLAS
                # matrix operations changes the first gradient in its last
                # bits, which nonlinearly changes later FR steps.
                for n in 1:num_wannier, m in 1:num_wannier
                    gradient[m, n] += weights[neighbor] * 0.5 * (cr[m, n] - conj(cr[n, m]))
                    ln_n = weights[neighbor] * centered_phase_values[n]
                    ln_m = weights[neighbor] * centered_phase_values[m]
                    gradient[m, n] -=
                        (crt[m, n] * ln_n + conj(crt[n, m] * ln_m)) * ComplexF64(0.0, -0.5)
                    rn_n = 0.0
                    rn_m = 0.0
                    for direction in 1:3
                        rn_n = muladd(b_cartesian[direction], center_delta[n, direction], rn_n)
                        rn_m = muladd(b_cartesian[direction], center_delta[m, direction], rn_m)
                    end
                    gradient[m, n] -=
                        weights[neighbor] *
                        (crt[m, n] * rn_n + conj(crt[n, m] * rn_m)) *
                        ComplexF64(0.0, -0.5)
                end
            else
                gradient .+= weights[neighbor] .* (cr - cr') ./ 2
                t_matrix = crt * Diagonal(q)
                gradient .+= (1.0im / 2) .* (t_matrix + t_matrix')
            end
            crt_cache[neighbor, kpoint] = crt
            b_cartesian_cache[neighbor, kpoint] = Vector{Float64}(b_cartesian)
        end
        if wannier90_arithmetic
            gradient ./= nk
            gradient .*= 4.0
        else
            gradient .*= 4.0 / nk
            gradient .= (gradient - gradient') ./ 2
        end
    end
    return (
        success = true,
        code = :OK,
        gradients,
        active_links,
        raw_jumps,
        crt_cache,
        b_cartesian_cache,
        minimum_margin,
        minimum_context,
    )
end

"""
Complete one branch-orbit gradient jump, including the induced center feedback.

Changing a centered principal phase by `+-2pi` changes both that link's direct
`q` contribution and the symmetrized Wannier-center increment.  The latter
enters every link through `b*Delta_r`; omitting it produces a Clarke interval
that need not contain the true one-sided derivative.
"""
function _mv_complete_branch_orbit_raw_jump(
    direct_jump::Vector{Matrix{ComplexF64}},
    members::Vector{MVPhaseBranchLink},
    representation::BandRepresentation,
    mmn::WannierMMN,
    weights::Vector{Float64},
    plan::WannierSymmetryPlan,
    crt_cache::Array{Matrix{ComplexF64}, 2},
    b_cartesian_cache::Array{Vector{Float64}, 2},
)
    nk = length(direct_jump)
    num_wannier = size(first(direct_jump), 1)
    raw_center_jump = zeros(Float64, num_wannier, 3)
    for link in members
        b_cartesian = b_cartesian_cache[link.neighbor, link.kpoint]
        @views raw_center_jump[link.wannier, :] .-=
            (weights[link.neighbor] * link.alternative_phase_jump / nk) .* b_cartesian
    end
    zero_centers = zeros(Float64, num_wannier, 3)
    center_jump =
        _symmetrize_wannier_property(raw_center_jump, representation, plan) -
        _symmetrize_wannier_property(zero_centers, representation, plan)
    completed = deepcopy(direct_jump)
    for kpoint in eachindex(completed), neighbor in 1:mmn.num_neighbors
        b_cartesian = b_cartesian_cache[neighbor, kpoint]
        delta_q = weights[neighbor] .* (center_jump * b_cartesian)
        t_matrix = crt_cache[neighbor, kpoint] * Diagonal(delta_q)
        contribution = (1.0im / 2) .* (t_matrix + t_matrix')
        contribution .*= 4.0 / nk
        completed[kpoint] .+= (contribution - contribution') ./ 2
    end
    return completed
end

"""Evaluate one MV objective/gradient chart and its Type-IV Clarke active set."""
function _evaluate_mv_localization(
    config::SymmetryAdaptedWannierizationConfig,
    frames::Vector{Matrix{ComplexF64}},
    phase_reference_centers::Matrix{Float64},
    representation::BandRepresentation,
    mmn::WannierMMN,
    weights::Vector{Float64},
    plan::WannierSymmetryPlan,
    tangent_plans::Vector{Union{Nothing, TargetSymmetryTangentPlan}},
    localized_overlaps::Union{Nothing, Array{ComplexF64, 4}} = nothing,
    wannier90_reference_omega_i::Union{Nothing, Float64} = nothing,
)
    reference_arithmetic =
        effective_wannierization_algorithms(config, representation).localization ==
        :smv_fletcher_reeves_two_stage
    if reference_arithmetic && localized_overlaps === nothing
        localized_overlaps = _localized_overlap_state(frames, mmn, config.solver.parallel)
    end
    if reference_arithmetic && wannier90_reference_omega_i === nothing
        wannier90_reference_omega_i =
            _wannier90_reference_invariant_spread(something(localized_overlaps), weights)
    end
    objective_components = _mv_centered_full_mesh_centers_spreads_and_directions(
        frames,
        phase_reference_centers,
        representation,
        mmn,
        weights,
        plan,
        return_link_components = true,
        parallel = config.solver.parallel,
        compensated = !reference_arithmetic,
        localized_overlaps = localized_overlaps,
    )
    centers = objective_components.centers
    spreads = objective_components.spreads
    directional = objective_components.directional
    gradient_center_delta =
        reference_arithmetic ?
        _wannier90_reference_gradient_center_delta(
            objective_components.centered_phases,
            representation,
            mmn,
            weights,
        ) : centers - phase_reference_centers
    gradient_data = _mv_centered_gradient_data(
        frames,
        phase_reference_centers,
        gradient_center_delta,
        representation,
        mmn,
        weights,
        config.input.representation_tolerance,
        config.solver.acceleration.u_phase_branch_tolerance,
        parallel = config.solver.parallel,
        localized_overlaps = localized_overlaps,
        wannier90_arithmetic = reference_arithmetic,
    )
    gradient_data.success || return gradient_data
    if reference_arithmetic &&
       lowercase(strip(get(ENV, "WANNIERNLQG_W90_REFERENCE_DEBUG_GRADIENT", "0"))) in
       ("1", "true", "yes")
        println(
            stderr,
            "W90REF_EVALUATED_GRADIENT_SHA256=" * _complex_field_sha256(gradient_data.gradients),
        )
    end
    apply_symmetry = symmetry_constraints_applied(config, representation)
    principal = if reference_arithmetic
        # `wann_domega` constructs the anti-Hermitian field entry by entry and
        # Wannier90 consumes that array directly.  Applying (G-G')/2 again is
        # algebraically redundant but changes its last bits and therefore the
        # FR/parabolic trajectory.
        norm_squared = _full_tangent_inner(gradient_data.gradients, gradient_data.gradients)
        (
            representative_gradients = gradient_data.gradients,
            full_gradients = gradient_data.gradients,
            norm_squared,
            rms = sqrt(
                norm_squared /
                (length(gradient_data.gradients) * size(first(gradient_data.gradients), 1)^2),
            ),
        )
    else
        _project_mv_descent_field(
            gradient_data.gradients,
            representation,
            plan,
            tangent_plans,
            apply_symmetry,
        )
    end

    if reference_arithmetic
        apply_symmetry && throw(
            ArgumentError(
                "WANNIER90_REFERENCE_MODE_MISMATCH: exact principal-sheet gradient is no-symmetry only",
            ),
        )
        norm_squared = principal.norm_squared
        dimension = size(first(frames), 2)
        reference_overlaps = something(localized_overlaps)
        reference_omega_i = something(wannier90_reference_omega_i)
        reference_objective = _wannier90_reference_total_spread(
            reference_overlaps,
            objective_components.centered_phases,
            centers,
            representation,
            mmn,
            weights,
            reference_omega_i,
        )
        evaluation = MVLocalizationEvaluation(
            centers,
            spreads,
            directional,
            reference_objective,
            objective_components.centered_phases,
            objective_components.diagonal_norms_squared,
            gradient_data.gradients,
            principal.representative_gradients,
            principal.full_gradients,
            principal.representative_gradients,
            principal.full_gradients,
            norm_squared,
            sqrt(norm_squared / (length(frames) * dimension^2)),
            MVPhaseBranchLink[],
            Vector{Vector{Matrix{ComplexF64}}}(),
            Vector{Vector{Matrix{ComplexF64}}}(),
            Float64[],
            String[],
            gradient_data.minimum_margin,
            gradient_data.minimum_context.kpoint,
            gradient_data.minimum_context.neighbor,
            gradient_data.minimum_context.wannier,
            gradient_data.minimum_context.phase,
        )
        return (success = true, code = :OK, evaluation)
    end

    # Project each raw cut jump. Collinear, positively oriented projections are
    # the same Type-IV branch orbit and must be summed, not independently chosen.
    branch_representatives = Vector{Vector{Matrix{ComplexF64}}}()
    branch_full = Vector{Vector{Matrix{ComplexF64}}}()
    branch_members = Vector{Vector{MVPhaseBranchLink}}()
    for (raw_jump, active_link) in zip(gradient_data.raw_jumps, gradient_data.active_links)
        completed_raw = _mv_complete_branch_orbit_raw_jump(
            raw_jump,
            MVPhaseBranchLink[active_link],
            representation,
            mmn,
            weights,
            plan,
            gradient_data.crt_cache,
            gradient_data.b_cartesian_cache,
        )
        projected_jump = _project_mv_descent_field(
            completed_raw,
            representation,
            plan,
            tangent_plans,
            apply_symmetry,
        )
        projected_jump.norm_squared <= eps(Float64) && continue
        matched = 0
        for index in eachindex(branch_full)
            cosine =
                _full_tangent_inner(branch_full[index], projected_jump.full_gradients) / sqrt(
                    _full_tangent_inner(branch_full[index], branch_full[index]) *
                    projected_jump.norm_squared,
                )
            if isfinite(cosine) && cosine >= 1.0 - 1.0e-8
                matched = index
                break
            end
        end
        if matched == 0
            push!(branch_representatives, deepcopy(projected_jump.representative_gradients))
            push!(branch_full, deepcopy(projected_jump.full_gradients))
            push!(branch_members, MVPhaseBranchLink[active_link])
        else
            for kpoint in eachindex(branch_full[matched])
                branch_representatives[matched][kpoint] .+=
                    projected_jump.representative_gradients[kpoint]
                branch_full[matched][kpoint] .+= projected_jump.full_gradients[kpoint]
            end
            push!(branch_members[matched], active_link)
        end
    end
    length(branch_members) <= config.solver.acceleration.u_branch_active_set_max_orbits || return (
        success = false,
        code = :U_BRANCH_ACTIVE_SET_LIMIT,
        active_orbit_count = length(branch_members),
        active_link_count = length(gradient_data.active_links),
    )
    clarke = _minimum_norm_clarke_combination(principal.full_gradients, branch_full)
    clarke.success || return (
        success = false,
        code = :U_BRANCH_CLARKE_SOLVE_FAILED,
        active_orbit_count = length(branch_full),
        active_link_count = length(gradient_data.active_links),
        kkt_residual = clarke.kkt_residual,
        iterations = clarke.iterations,
    )
    representative = deepcopy(principal.representative_gradients)
    for (coefficient, jump) in zip(clarke.coefficients, branch_representatives),
        kpoint in eachindex(representative)

        representative[kpoint] .+= coefficient .* jump[kpoint]
    end
    norm_squared = _full_tangent_inner(clarke.field, clarke.field)
    dimension = size(first(frames), 2)
    evaluation = MVLocalizationEvaluation(
        centers,
        spreads,
        directional,
        sum(spreads),
        objective_components.centered_phases,
        objective_components.diagonal_norms_squared,
        gradient_data.gradients,
        principal.representative_gradients,
        principal.full_gradients,
        representative,
        clarke.field,
        norm_squared,
        sqrt(norm_squared / (length(frames) * dimension^2)),
        gradient_data.active_links,
        branch_representatives,
        branch_full,
        clarke.coefficients,
        sort([_mv_branch_orbit_digest(members) for members in branch_members]),
        gradient_data.minimum_margin,
        gradient_data.minimum_context.kpoint,
        gradient_data.minimum_context.neighbor,
        gradient_data.minimum_context.wannier,
        gradient_data.minimum_context.phase,
    )
    return (success = true, code = :OK, evaluation)
end

"""Clarke directional-derivative interval for one branch-aware evaluation."""
function _mv_generalized_directional_derivative_interval(
    evaluation::MVLocalizationEvaluation,
    direction::Vector{Matrix{ComplexF64}},
)
    lower = -_full_tangent_inner(evaluation.principal_full_gradients, direction)
    upper = lower
    for jump in evaluation.branch_jump_full
        alternative = -_full_tangent_inner(jump, direction)
        lower += min(0.0, alternative)
        upper += max(0.0, alternative)
    end
    return (lower = Float64(lower), upper = Float64(upper))
end

"""Upper Clarke directional derivative for one branch-aware evaluation."""
function _mv_generalized_directional_derivative(
    evaluation::MVLocalizationEvaluation,
    direction::Vector{Matrix{ComplexF64}},
)
    return _mv_generalized_directional_derivative_interval(evaluation, direction).upper
end

"""Directional derivative for the right-acting MV descent field."""
function _localization_directional_derivative(
    objective_gradients::Vector{Matrix{ComplexF64}},
    descent_directions::Vector{Matrix{ComplexF64}},
)
    length(objective_gradients) == length(descent_directions) ||
        throw(DimensionMismatch("localization gradient and direction meshes disagree"))
    derivative =
        -sum(
            real(dot(gradient, direction)) for
            (gradient, direction) in zip(objective_gradients, descent_directions)
        )
    return Float64(derivative)
end

"""Apply a tangent proposal and return its rank-gated polar retraction."""
function _polar_retracted_tangent_step(
    old_unitary::Matrix{ComplexF64},
    tangent::Matrix{ComplexF64},
    scale::Float64,
    tolerance::Float64,
    maximum_condition::Float64,
)
    trial = old_unitary * (Matrix{ComplexF64}(I, size(tangent)...) + scale .* tangent)
    return _localization_svd_polar(trial, tolerance, maximum_condition)
end

"""Right-trivialized velocity of `polar(I + scale*A)` for anti-Hermitian `A`."""
function _polar_retraction_curve_velocity(tangent::Matrix{ComplexF64}, scale::Float64)
    dimension = size(tangent, 1)
    size(tangent, 2) == dimension || throw(DimensionMismatch("U tangent must be square"))
    denominator = Matrix{ComplexF64}(I, dimension, dimension) - scale^2 .* (tangent * tangent)
    velocity = tangent / denominator
    return (velocity - velocity') ./ 2
end

"""Branch-safe logarithmic displacement between two accepted unitary frames."""
function _accepted_unitary_displacement(
    old_unitary::Matrix{ComplexF64},
    new_unitary::Matrix{ComplexF64},
    tolerance::Float64,
)
    geodesic = _unitary_geodesic_plan(old_unitary, new_unitary, tolerance)
    geodesic.success || return (
        success = false,
        code = geodesic.code,
        tangent = zeros(ComplexF64, size(old_unitary)),
    )
    tangent = geodesic.vectors * Diagonal(1.0im .* geodesic.phases) * geodesic.vectors'
    tangent = (tangent - tangent') ./ 2
    return (success = true, code = :OK, tangent)
end

"""Return the deterministic global step scale for one backtracking index."""
_backtracking_step_scale(initial::Float64, factor::Float64, step::Int) = initial * factor^step

"""Return the non-polar reduction budget for the active acceptance contract.

Armijo and strong-Wolfe are localization line searches and use the expert
`u_line_search_max_trials` budget. The legacy `u_backtracking_max_steps`
budget remains reserved for polar and monotone fallbacks. In particular, a
generalized-Armijo phase-cut step must not stop after the shorter polar budget.
"""
function _localization_backtracking_limit(
    acceleration::WannierizationAccelerationConfig,
    mode::Symbol,
)
    mode == :polar && return acceleration.u_backtracking_max_steps
    acceleration.u_acceptance in (:armijo, :strong_wolfe) &&
        return acceleration.u_line_search_max_trials - 1
    return acceleration.u_backtracking_max_steps
end

"""Return the closest diagonal-link phase and its deterministic mesh context."""
function _minimum_diagonal_phase_context(frames::Vector{Matrix{ComplexF64}}, mmn::WannierMMN)
    minimum_margin = Inf
    minimum_kpoint = 0
    minimum_neighbor = 0
    minimum_wannier = 0
    minimum_phase = NaN
    for kpoint in eachindex(frames), neighbor in 1:mmn.num_neighbors
        target = mmn.neighbors[neighbor, kpoint]
        overlap = frames[kpoint]' * @view(mmn.data[:, :, neighbor, kpoint]) * frames[target]
        for wannier in axes(overlap, 1)
            phase = angle(overlap[wannier, wannier])
            margin = pi - abs(phase)
            if margin < minimum_margin
                minimum_margin = margin
                minimum_kpoint = kpoint
                minimum_neighbor = neighbor
                minimum_wannier = wannier
                minimum_phase = phase
            end
        end
    end
    return (
        margin = minimum_margin,
        kpoint = minimum_kpoint,
        neighbor = minimum_neighbor,
        wannier = minimum_wannier,
        phase = minimum_phase,
    )
end

"""Compatibility wrapper for callers that only require the scalar margin."""
_minimum_diagonal_phase_margin(frames::Vector{Matrix{ComplexF64}}, mmn::WannierMMN) =
    _minimum_diagonal_phase_context(frames, mmn).margin

"""Evaluate one localization trial against the same declared base point."""
function _localization_objective_accepts(
    algorithm::Symbol,
    acceptance::Symbol,
    old_objective::Float64,
    trial_objective::Float64,
    objective_tolerance::Float64,
    step_scale::Float64,
    directional_derivative::Float64,
    armijo_c1::Float64,
    ;
    trial_directional_derivative::Float64 = NaN,
    wolfe_c2::Float64 = 0.9,
    branch_active::Bool = false,
)
    algorithm in (
        :symmetry_projected_gradient,
        :polar_then_gradient,
        :riemannian_cg,
        :riemannian_lbfgs,
        :smv_fletcher_reeves_two_stage,
        :symmetry_projected_smv_fletcher_reeves_two_stage,
    ) || throw(ArgumentError("unsupported localization algorithm $(algorithm)"))
    acceptance == :invariant_only && return isfinite(trial_objective)
    acceptance == :monotone && return isfinite(trial_objective) && trial_objective <= old_objective
    armijo =
        isfinite(directional_derivative) &&
        directional_derivative < 0.0 &&
        isfinite(trial_objective) &&
        trial_objective <= old_objective &&
        trial_objective <= old_objective + armijo_c1 * step_scale * directional_derivative
    acceptance == :armijo && return armijo
    acceptance == :strong_wolfe && return armijo && (
        branch_active || (
            isfinite(trial_directional_derivative) &&
            abs(trial_directional_derivative) <= wolfe_c2 * abs(directional_derivative)
        )
    )
    throw(ArgumentError("unsupported U acceptance mode $(acceptance)"))
end

"""Retain the best structurally valid finite descent inside an FR restart search.

A forced Fletcher--Reeves restart deliberately evaluates the steepest direction
under the internal gradient mode. The trial still belongs to the FR state
machine and therefore shares its existing finite-descent fallback after the
strong-Wolfe trial budget is exhausted.
"""
function _best_fletcher_reeves_finite_descent(
    best,
    candidate,
    localization_algorithm::Symbol,
    invariant_failure,
    old_objective::Float64,
)
    _is_fletcher_reeves_localization(localization_algorithm) || return best
    invariant_failure === nothing || return best
    isfinite(candidate.objective) && candidate.objective < old_objective || return best
    best === nothing || candidate.objective < best.objective || return best
    return candidate
end
