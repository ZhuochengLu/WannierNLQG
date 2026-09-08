# Return CHK centers as fractional row coordinates in the CHK lattice.
function _wannier_centers_fractional(chk::WannierCHK)
    wannier_centers_fractional = chk.wannier_centers_cart * inv(chk.real_lattice)
    all(isfinite, wannier_centers_fractional) ||
        throw(ArgumentError("CHK Wannier centers are non-finite"))
    return wannier_centers_fractional
end

# Return the complete noncentered MP residue grid as integer row vectors.
function _mp_residue_grid(mp_grid::NTuple{3, Int})
    return [(i, j, k) for i in 0:(mp_grid[1] - 1), j in 0:(mp_grid[2] - 1), k in 0:(mp_grid[3] - 1)]
end

# Return every input-support replica belonging to one MP residue.
function _input_replica_images(
    residue::NTuple{3, Int},
    target_r_vectors::Matrix{Int},
    mp_grid::NTuple{3, Int},
)
    images = NTuple{3, Int}[]
    for target_index in axes(target_r_vectors, 2)
        candidate = Tuple(target_r_vectors[:, target_index])
        real_space_mp_residue(@view(target_r_vectors[:, target_index]), mp_grid) == residue ||
            continue
        push!(images, candidate)
    end
    sort!(images)
    return images
end

"""
Cache the pair-dependent Wannier-center geometry and Fourier phases shared by
derivative and spin operators in the unified Symmetrization workflow.

The plan uses `-tau_left + tau_right`, complete MP residues, all tied nearest
Wigner-Seitz images, and unit-degeneracy real-space operator values. It owns no
symmetry projection, physical prefactor, or cache serialization.
"""
struct WannierPairWignerSeitzTransformPlan
    image_policy::Symbol
    residues::Vector{NTuple{3, Int}}
    q_to_grid_phases::Matrix{ComplexF64}
    target_r_vectors::Matrix{Int}
    target_r_vector_indices::Dict{NTuple{3, Int}, Int}
    target_to_q_phases::Matrix{ComplexF64}
    wigner_seitz_images::Array{Vector{NTuple{3, Int}}, 3}
    retained_target_indices::Array{Vector{Int}, 3}
end

"""Build one reusable pair-dependent transform plan for a CHK and target R support."""
function WannierPairWignerSeitzTransformPlan(
    chk::WannierCHK,
    target_r_vectors::Matrix{Int};
    wigner_seitz_tolerance::Float64,
    search_size::Int,
    image_policy::Symbol = :minimum_distance,
    wannier_centers_fractional::Union{Nothing, Matrix{Float64}} = nothing,
)
    wigner_seitz_tolerance > 0.0 || throw(ArgumentError("wigner_seitz_tolerance must be positive"))
    search_size > 0 || throw(ArgumentError("search_size must be positive"))
    size(target_r_vectors, 1) == 3 ||
        throw(ArgumentError("target_r_vectors must have size (3, num_r_vectors)"))
    image_policy in (:input, :minimum_distance) ||
        throw(ArgumentError("image_policy must be :input or :minimum_distance"))

    residues = vec(_mp_residue_grid(chk.mp_grid))
    q_to_grid_phases = Matrix{ComplexF64}(undef, chk.num_kpts, length(residues))
    for (grid_index, residue) in enumerate(residues), kpoint in 1:chk.num_kpts
        q_to_grid_phases[kpoint, grid_index] =
            cis(-2.0 * pi * dot(chk.kpt_red[kpoint, :], collect(residue))) / chk.num_kpts
    end

    target_r_vector_indices =
        Dict(Tuple(target_r_vectors[:, index]) => index for index in axes(target_r_vectors, 2))
    length(target_r_vector_indices) == size(target_r_vectors, 2) ||
        throw(ArgumentError("target_r_vectors contain duplicate vectors"))
    target_to_q_phases = Matrix{ComplexF64}(undef, chk.num_kpts, size(target_r_vectors, 2))
    for target_index in axes(target_r_vectors, 2), kpoint in 1:chk.num_kpts
        target_to_q_phases[kpoint, target_index] =
            cis(2.0 * pi * dot(chk.kpt_red[kpoint, :], @view(target_r_vectors[:, target_index])))
    end

    image_dimensions = (chk.num_orbitals, chk.num_orbitals, length(residues))
    wigner_seitz_images = Array{Vector{NTuple{3, Int}}, 3}(undef, image_dimensions)
    retained_target_indices = Array{Vector{Int}, 3}(undef, image_dimensions)
    centers_fractional = if wannier_centers_fractional === nothing
        _wannier_centers_fractional(chk)
    else
        copy(wannier_centers_fractional)
    end
    size(centers_fractional) == (chk.num_orbitals, 3) ||
        throw(ArgumentError("wannier_centers_fractional has incompatible dimensions"))
    all(isfinite, centers_fractional) ||
        throw(ArgumentError("wannier_centers_fractional contains non-finite values"))
    digits = ceil(Int, -log10(wigner_seitz_tolerance)) + 1
    for left in 1:chk.num_orbitals, right in 1:chk.num_orbitals
        center_shift =
            round.(-centers_fractional[left, :] .+ centers_fractional[right, :]; digits = digits)
        for (grid_index, residue) in enumerate(residues)
            images = if image_policy == :minimum_distance
                nearest_wigner_seitz_images(
                    residue,
                    center_shift,
                    chk.real_lattice,
                    chk.mp_grid;
                    tolerance = wigner_seitz_tolerance,
                    search_size = search_size,
                )
            else
                _input_replica_images(residue, target_r_vectors, chk.mp_grid)
            end
            isempty(images) &&
                throw(ArgumentError("input R support does not contain MP residue $(residue)"))
            wigner_seitz_images[left, right, grid_index] = images
            retained_target_indices[left, right, grid_index] = [
                target_r_vector_indices[image] for
                image in images if haskey(target_r_vector_indices, image)
            ]
        end
    end
    return WannierPairWignerSeitzTransformPlan(
        image_policy,
        residues,
        q_to_grid_phases,
        copy(target_r_vectors),
        target_r_vector_indices,
        target_to_q_phases,
        wigner_seitz_images,
        retained_target_indices,
    )
end

# Fourier transform one q-last operator to the complete MP residue grid.
function _wannier_q_to_grid(
    values_q::Array{ComplexF64, N},
    chk::WannierCHK,
    plan::WannierPairWignerSeitzTransformPlan,
) where {N}
    N >= 3 || throw(ArgumentError("q-space operator must have at least three dimensions"))
    size(values_q, 1) == chk.num_orbitals && size(values_q, 2) == chk.num_orbitals ||
        throw(ArgumentError("q-space operator has incompatible Wannier dimensions"))
    size(values_q, N) == chk.num_kpts ||
        throw(ArgumentError("q-space operator has incompatible k-point count"))
    output = zeros(ComplexF64, Base.front(size(values_q))..., length(plan.residues))
    output_matrix = reshape(output, :, length(plan.residues))
    input_matrix = reshape(values_q, :, chk.num_kpts)
    for grid_index in eachindex(plan.residues), kpoint in 1:chk.num_kpts
        phase = plan.q_to_grid_phases[kpoint, grid_index]
        @views output_matrix[:, grid_index] .+= phase .* input_matrix[:, kpoint]
    end
    return output
end

# Distribute one MP-grid operator over pair-dependent nearest WS images.
function _wannier_grid_to_pair_wigner_seitz(
    grid_values::Array{ComplexF64, N},
    chk::WannierCHK,
    plan::WannierPairWignerSeitzTransformPlan;
    support_tolerance::Float64,
    label::AbstractString,
) where {N}
    support_tolerance >= 0.0 || throw(ArgumentError("support_tolerance must be nonnegative"))
    size(grid_values, N) == length(plan.residues) ||
        throw(ArgumentError("grid operator does not cover the complete MP residue grid"))
    output = zeros(ComplexF64, Base.front(size(grid_values))..., size(plan.target_r_vectors, 2))
    tensor_colons = ntuple(_ -> Colon(), N - 3)
    for left in 1:chk.num_orbitals, right in 1:chk.num_orbitals
        for grid_index in eachindex(plan.residues)
            images = plan.wigner_seitz_images[left, right, grid_index]
            grid_operator_block = view(grid_values, left, right, tensor_colons..., grid_index)
            missing_images =
                [image for image in images if !haskey(plan.target_r_vector_indices, image)]
            if !isempty(missing_images) &&
               maximum(abs, grid_operator_block; init = 0.0) > support_tolerance
                throw(
                    ArgumentError(
                        "nonzero $(label) block requires absent R image $(first(missing_images))",
                    ),
                )
            end
            retained_indices = plan.retained_target_indices[left, right, grid_index]
            isempty(retained_indices) && continue
            fraction = inv(length(images))
            for target_index in retained_indices
                destination = view(output, left, right, tensor_colons..., target_index)
                destination .+= fraction .* grid_operator_block
            end
        end
    end
    return output
end

# Transform q-last values into unit-degeneracy pair-dependent WS storage.
function _wannier_q_to_pair_wigner_seitz(
    values_q::Array{ComplexF64, N},
    chk::WannierCHK,
    plan::WannierPairWignerSeitzTransformPlan;
    support_tolerance::Float64,
    label::AbstractString,
) where {N}
    grid_values = _wannier_q_to_grid(values_q, chk, plan)
    return _wannier_grid_to_pair_wigner_seitz(
        grid_values,
        chk,
        plan;
        support_tolerance = support_tolerance,
        label = label,
    )
end

# Reconstruct q-space values from unit-degeneracy R-last storage.
function _unit_degeneracy_roundtrip_error(
    values_q::Array{ComplexF64, N},
    values_r::Array{ComplexF64, N},
    chk::WannierCHK,
    plan::WannierPairWignerSeitzTransformPlan,
) where {N}
    q_matrix = reshape(values_q, :, chk.num_kpts)
    r_matrix = reshape(values_r, :, size(plan.target_r_vectors, 2))
    recovered = zeros(ComplexF64, size(q_matrix, 1))
    maximum_error = 0.0
    for kpoint in 1:chk.num_kpts
        fill!(recovered, 0.0 + 0.0im)
        for target_index in axes(plan.target_r_vectors, 2)
            @views recovered .+=
                plan.target_to_q_phases[kpoint, target_index] .* r_matrix[:, target_index]
        end
        maximum_error =
            max(maximum_error, maximum(abs, recovered .- @view(q_matrix[:, kpoint]); init = 0.0))
    end
    return maximum_error
end

"""Store the cold-path pair-dependent spin transform policy for one workflow."""
struct PairWignerSeitzSpinQToRTransform
    chk::WannierCHK
    plan::WannierPairWignerSeitzTransformPlan
    support_tolerance::Float64
    roundtrip_tolerance::Float64
    check_roundtrip::Bool
end

# Apply the Symmetrization-only spin q-to-R policy through MatrixElements orchestration.
function _transform_spin_q_to_r(
    transform::PairWignerSeitzSpinQToRTransform,
    values_q::Array{ComplexF64, N},
    label::AbstractString,
) where {N}
    values_r = _wannier_q_to_pair_wigner_seitz(
        values_q,
        transform.chk,
        transform.plan;
        support_tolerance = transform.support_tolerance,
        label = label,
    )
    error = _unit_degeneracy_roundtrip_error(values_q, values_r, transform.chk, transform.plan)
    transform.check_roundtrip &&
        error > transform.roundtrip_tolerance &&
        throw(
            ArgumentError(
                "$(label) q->WS-R->q round-trip error $(error) exceeds " *
                "$(transform.roundtrip_tolerance)",
            ),
        )
    return (real_space_values = values_r, diagnostics = SpinVelocityTransformDiagnostics(error))
end
