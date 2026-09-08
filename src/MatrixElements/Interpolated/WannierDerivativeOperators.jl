# Shared by Symmetrization and Wannierization through MatrixElements.
const WANNIER_DERIVATIVE_OPERATOR_KINDS = (
    REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION,
    REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP,
    REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR,
    REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP,
    REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP,
)
const AXIAL_CARTESIAN_PAIRS = ((2, 3), (3, 1), (1, 2))

@enum OverlapWeightingKind::UInt8 begin
    IDENTITY_WEIGHTED_OVERLAP
    HAMILTONIAN_WEIGHTED_OVERLAP
end

"""
Constructed orbital-family matrices in R-last Wannier storage.

Every value has leading Wannier indices, zero, one, or two Cartesian indices,
and a final real-space index. `r_vectors` uses integer lattice columns. The
constructor owns reciprocal-to-real normalization and center-aware Wigner-Seitz
distribution; response prefactors and symmetry projection are external.
"""
struct WannierDerivativeOperatorSet
    r_vectors::Matrix{Int}
    matrices::Dict{RealSpaceOperatorKind, Array{ComplexF64}}

    function WannierDerivativeOperatorSet(r_vectors, matrices)
        vectors = Matrix{Int}(r_vectors)
        size(vectors, 1) == 3 || throw(ArgumentError("r_vectors must have size (3, num_r_vectors)"))
        values = Dict{RealSpaceOperatorKind, Array{ComplexF64}}()
        for (kind, matrix) in pairs(matrices)
            kind in WANNIER_DERIVATIVE_OPERATOR_KINDS ||
                throw(ArgumentError("unsupported Wannier derivative operator $(kind)"))
            array = Array{ComplexF64}(matrix)
            size(array, ndims(array)) == size(vectors, 2) ||
                throw(ArgumentError("$(kind) real-space dimension does not match r_vectors"))
            values[kind] = array
        end
        isempty(values) &&
            throw(ArgumentError("at least one Wannier derivative operator is required"))
        return new(vectors, values)
    end
end

# Validate shared CHK/EIG/MMN dimensions for orbital construction.
function _validate_wannier_derivative_inputs(chk::WannierCHK, eig::WannierEIG, mmn::WannierMMN)
    eig.num_bands == chk.num_bands && eig.num_kpts == chk.num_kpts ||
        throw(ArgumentError("EIG dimensions do not match CHK"))
    mmn.num_bands == chk.num_bands && mmn.num_kpts == chk.num_kpts ||
        throw(ArgumentError("MMN dimensions do not match CHK"))
    return nothing
end

# Apply the Wannier-center phases used by the centered orbital convention.
function _apply_wannier_center_phases!(
    matrix::Matrix{ComplexF64},
    centers_cartesian::Matrix{Float64},
    left_vector::AbstractVector{<:Real},
    right_vector::AbstractVector{<:Real},
)
    left_phase = cis.(-centers_cartesian * left_vector)
    right_phase = cis.(centers_cartesian * right_vector)
    matrix .*= left_phase .* transpose(right_phase)
    return matrix
end

# Construct the Hamiltonian-weighted connection in q-last storage.
function _construct_hamiltonian_weighted_connection_q(
    chk::WannierCHK,
    eig::WannierEIG,
    mmn::WannierMMN,
    stencil::FiniteDifferenceStencil,
    wannier_centers_cartesian::Matrix{Float64},
)
    output = zeros(ComplexF64, chk.num_orbitals, chk.num_orbitals, 3, chk.num_kpts)
    for kpoint in 1:chk.num_kpts, neighbour in eachindex(stencil.weights)
        overlap_index = stencil.overlap_order[neighbour, kpoint]
        neighbor_kpoint_index = stencil.neighbors[neighbour, kpoint]
        overlap_matrix = @view mmn.data[:, :, overlap_index, kpoint]
        weighted_overlap_matrix = eig.data[:, kpoint] .* overlap_matrix
        wannier_gauge_matrix =
            chk.v_matrix[:, :, kpoint]' *
            weighted_overlap_matrix *
            chk.v_matrix[:, :, neighbor_kpoint_index]
        displacement_cartesian = @view stencil.displacement_cartesian[neighbour, :]
        _apply_wannier_center_phases!(
            wannier_gauge_matrix,
            wannier_centers_cartesian,
            zeros(3),
            displacement_cartesian,
        )
        for cartesian in 1:3
            @views output[:, :, cartesian, kpoint] .+=
                1.0im * stencil.weights[neighbour] * displacement_cartesian[cartesian] .*
                wannier_gauge_matrix
        end
    end
    return output
end

# Return one derived weighted-overlap block in the upstream band gauge.
function _derived_weighted_overlap_block(
    weighting::OverlapWeightingKind,
    eig::WannierEIG,
    mmn::WannierMMN,
    stencil::FiniteDifferenceStencil,
    kpoint::Int,
    first::Int,
    second::Int,
)
    first_source = stencil.overlap_order[first, kpoint]
    second_source = stencil.overlap_order[second, kpoint]
    first_overlap = @view mmn.data[:, :, first_source, kpoint]
    second_overlap = @view mmn.data[:, :, second_source, kpoint]
    weighting == IDENTITY_WEIGHTED_OVERLAP && return first_overlap' * second_overlap
    weighting == HAMILTONIAN_WEIGHTED_OVERLAP &&
        return first_overlap' * (eig.data[:, kpoint] .* second_overlap)
    error("unreachable overlap weighting $(weighting)")
end

# Construct the Hamiltonian-weighted axial derivative overlap in q-last storage.
function _construct_hamiltonian_weighted_axial_derivative_overlap_q(
    chk::WannierCHK,
    eig::WannierEIG,
    mmn::WannierMMN,
    stencil::FiniteDifferenceStencil,
    wannier_centers_cartesian::Matrix{Float64},
)
    output = zeros(ComplexF64, chk.num_orbitals, chk.num_orbitals, 3, chk.num_kpts)
    for kpoint in 1:chk.num_kpts,
        first in eachindex(stencil.weights),
        second in eachindex(stencil.weights)

        target_first = stencil.neighbors[first, kpoint]
        target_second = stencil.neighbors[second, kpoint]
        block = _derived_weighted_overlap_block(
            HAMILTONIAN_WEIGHTED_OVERLAP,
            eig,
            mmn,
            stencil,
            kpoint,
            first,
            second,
        )
        wannier = chk.v_matrix[:, :, target_first]' * block * chk.v_matrix[:, :, target_second]
        first_vector = @view stencil.displacement_cartesian[first, :]
        second_vector = @view stencil.displacement_cartesian[second, :]
        _apply_wannier_center_phases!(
            wannier,
            wannier_centers_cartesian,
            first_vector,
            second_vector,
        )
        weight = 1.0im * stencil.weights[first] * stencil.weights[second]
        for (axial, (alpha, beta)) in enumerate(AXIAL_CARTESIAN_PAIRS)
            antisymmetric =
                first_vector[alpha] * second_vector[beta] -
                first_vector[beta] * second_vector[alpha]
            @views output[:, :, axial, kpoint] .+= weight * antisymmetric .* wannier
        end
    end
    return output
end

# Construct the full Cartesian derivative-overlap tensor in q-last storage.
function _construct_derivative_overlap_tensor_q(
    chk::WannierCHK,
    eig::WannierEIG,
    mmn::WannierMMN,
    stencil::FiniteDifferenceStencil,
    wannier_centers_cartesian::Matrix{Float64},
)
    output = zeros(ComplexF64, chk.num_orbitals, chk.num_orbitals, 3, 3, chk.num_kpts)
    for kpoint in 1:chk.num_kpts,
        first in eachindex(stencil.weights),
        second in eachindex(stencil.weights)

        target_first = stencil.neighbors[first, kpoint]
        target_second = stencil.neighbors[second, kpoint]
        block = _derived_weighted_overlap_block(
            IDENTITY_WEIGHTED_OVERLAP,
            eig,
            mmn,
            stencil,
            kpoint,
            first,
            second,
        )
        wannier = chk.v_matrix[:, :, target_first]' * block * chk.v_matrix[:, :, target_second]
        first_vector = @view stencil.displacement_cartesian[first, :]
        second_vector = @view stencil.displacement_cartesian[second, :]
        _apply_wannier_center_phases!(
            wannier,
            wannier_centers_cartesian,
            first_vector,
            second_vector,
        )
        weight = stencil.weights[first] * stencil.weights[second]
        for alpha in 1:3, beta in 1:3
            @views output[:, :, alpha, beta, kpoint] .+=
                weight * first_vector[alpha] * second_vector[beta] .* wannier
        end
    end
    return output
end

# Apply the established R/-R Hermiticity projection to paired real-space blocks.
function _hermitianize_real_space_pairs(values::Array{ComplexF64}, r_vectors::Matrix{Int})
    result = copy(values)
    index = Dict(Tuple(r_vectors[:, i]) => i for i in axes(r_vectors, 2))
    tensor_colons = ntuple(_ -> Colon(), ndims(values) - 3)
    for position in axes(r_vectors, 2)
        key = Tuple(r_vectors[:, position])
        partner = get(index, Tuple(-collect(key)), 0)
        destination = view(result,:,:,(tensor_colons...),position)
        destination .= 0.5 .* view(values,:,:,(tensor_colons...),position)
        if partner != 0
            source = view(values,:,:,(tensor_colons...),partner)
            destination .+= 0.5 .* permutedims(conj(source), (2, 1, 3))
        end
    end
    return result
end

# Derive axial and symmetric operators from the full derivative-overlap tensor.
function _derive_axial_and_symmetric_derivative_overlaps(
    derivative_overlap_tensor::Array{ComplexF64, 5},
)
    num_wannier = size(derivative_overlap_tensor, 1)
    num_r_vectors = size(derivative_overlap_tensor, 5)
    axial_overlap = zeros(ComplexF64, num_wannier, num_wannier, 3, num_r_vectors)
    symmetric_overlap = similar(derivative_overlap_tensor)
    for (axial, (alpha, beta)) in enumerate(AXIAL_CARTESIAN_PAIRS)
        @views axial_overlap[:, :, axial, :] .=
            1.0im .* (
                derivative_overlap_tensor[:, :, alpha, beta, :] .-
                derivative_overlap_tensor[:, :, beta, alpha, :]
            )
    end
    for alpha in 1:3, beta in 1:3
        @views symmetric_overlap[:, :, alpha, beta, :] .=
            0.5 .* (
                derivative_overlap_tensor[:, :, alpha, beta, :] .+
                derivative_overlap_tensor[:, :, beta, alpha, :]
            )
    end
    return axial_overlap, symmetric_overlap
end

# Normalize a typed Wannier-derivative selection without reconstructing enum values.
function _normalized_wannier_derivative_operator_kinds(requested)
    all(kind -> kind isa RealSpaceOperatorKind, requested) ||
        throw(ArgumentError("requested operators must use RealSpaceOperatorKind values"))
    normalized = unique!(RealSpaceOperatorKind[kind for kind in requested])
    all(kind -> kind in WANNIER_DERIVATIVE_OPERATOR_KINDS, normalized) ||
        throw(ArgumentError("requested Wannier derivative operator is unsupported"))
    return normalized
end

"""
Construct any supported Wannier derivative-operator subset from CHK/EIG/MMN data.

The method follows the centered Wannier convention: finite-difference neighbor
matrices are transformed with the CHK gauge, center phases are applied once,
and `exp(-2pi*i*q·R)/Nq` is distributed over center-aware Wigner-Seitz images.
Arrays use R-last storage and are aligned to `model.r_vectors`; the model and
inputs are not modified. Weighted overlaps are derived from MMN and, when
Hamiltonian weighted, EIG, so
no SCF mesh or electronic-structure input file is consumed.
"""
function construct_wannier_derivative_operators(
    model::TightBindingModel,
    chk::WannierCHK,
    eig::WannierEIG,
    mmn::WannierMMN;
    requested = WANNIER_DERIVATIVE_OPERATOR_KINDS,
    support_tolerance::Float64 = 1.0e-12,
    wigner_seitz_tolerance::Float64 = 1.0e-5,
    search_size::Int = 3,
    transform_plan::Union{Nothing, WannierPairWignerSeitzTransformPlan} = nothing,
    wannier_centers_cartesian::Matrix{Float64} = chk.wannier_centers_cart,
)
    _validate_wannier_derivative_inputs(chk, eig, mmn)
    chk.num_orbitals == model.num_orbitals ||
        throw(ArgumentError("CHK and TB Wannier dimensions differ"))
    normalized = _normalized_wannier_derivative_operator_kinds(requested)
    support_tolerance >= 0.0 || throw(ArgumentError("support_tolerance must be nonnegative"))
    wigner_seitz_tolerance > 0.0 || throw(ArgumentError("wigner_seitz_tolerance must be positive"))
    search_size > 0 || throw(ArgumentError("search_size must be positive"))
    size(wannier_centers_cartesian) == (chk.num_orbitals, 3) ||
        throw(ArgumentError("wannier_centers_cartesian has incompatible dimensions"))
    all(isfinite, wannier_centers_cartesian) ||
        throw(ArgumentError("wannier_centers_cartesian contains non-finite values"))
    stencil = match_finite_difference_stencil_to_mmn(build_finite_difference_stencil(chk), chk, mmn)
    matrices = Dict{RealSpaceOperatorKind, Array{ComplexF64}}()
    needs_derivative_overlap_tensor = any(
        kind -> kind in (
            REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR,
            REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP,
            REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP,
        ),
        normalized,
    )
    q_values = Dict{RealSpaceOperatorKind, Array{ComplexF64}}()
    if REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION in normalized
        q_values[REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION] =
            _construct_hamiltonian_weighted_connection_q(
                chk,
                eig,
                mmn,
                stencil,
                wannier_centers_cartesian,
            )
    end
    if REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP in normalized
        q_values[REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP] =
            _construct_hamiltonian_weighted_axial_derivative_overlap_q(
                chk,
                eig,
                mmn,
                stencil,
                wannier_centers_cartesian,
            )
    end
    if needs_derivative_overlap_tensor
        q_values[REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR] = _construct_derivative_overlap_tensor_q(
            chk,
            eig,
            mmn,
            stencil,
            wannier_centers_cartesian,
        )
    end
    plan = if transform_plan === nothing
        WannierPairWignerSeitzTransformPlan(
            chk,
            model.r_vectors;
            wigner_seitz_tolerance = wigner_seitz_tolerance,
            search_size = search_size,
        )
    else
        transform_plan.target_r_vectors == model.r_vectors ||
            throw(ArgumentError("transform plan and TB model use different R support"))
        transform_plan
    end
    for (kind, values_q) in q_values
        matrices[kind] = _wannier_q_to_pair_wigner_seitz(
            values_q,
            chk,
            plan;
            support_tolerance = support_tolerance,
            label = operator_storage_name(kind),
        )
    end
    if REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP in keys(matrices)
        kind = REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP
        matrices[kind] = _hermitianize_real_space_pairs(matrices[kind], model.r_vectors)
    end
    if needs_derivative_overlap_tensor
        axial_overlap, symmetric_overlap = _derive_axial_and_symmetric_derivative_overlaps(
            matrices[REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR],
        )
        REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP in normalized &&
            (matrices[REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP] = axial_overlap)
        REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP in normalized &&
            (matrices[REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP] = symmetric_overlap)
        REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR in normalized ||
            delete!(matrices, REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR)
    end
    return WannierDerivativeOperatorSet(model.r_vectors, matrices)
end
