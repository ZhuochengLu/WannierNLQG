const STREAMED_NEIGHBOR_ORDER_ALGORITHM = "source-to-internal-per-k-both-indices-v1"

"""Validate and invert internal-to-source neighbor order separately at each k point."""
function _validated_source_to_internal_neighbor_order(stencil, num_kpts::Int)
    count = length(stencil.weights)
    order = stencil.overlap_order
    size(order) == (count, num_kpts) ||
        throw(ArgumentError("OPERATOR_NEIGHBOR_ORDER_MISMATCH: overlap_order dimensions differ"))
    size(stencil.neighbors) == (count, num_kpts) ||
        throw(ArgumentError("OPERATOR_NEIGHBOR_ORDER_MISMATCH: neighbor dimensions differ"))
    count > 0 && num_kpts > 0 ||
        throw(ArgumentError("OPERATOR_NEIGHBOR_ORDER_MISMATCH: empty topology"))
    inverse = zeros(Int, count, num_kpts)
    for kpoint in 1:num_kpts, internal in 1:count
        source = order[internal, kpoint]
        source isa Integer && !(source isa Bool) && 1 <= source <= count || throw(
            ArgumentError("OPERATOR_NEIGHBOR_ORDER_MISMATCH: invalid source slot at k=$(kpoint)"),
        )
        iszero(inverse[source, kpoint]) || throw(
            ArgumentError("OPERATOR_NEIGHBOR_ORDER_MISMATCH: duplicate source slot at k=$(kpoint)"),
        )
        inverse[source, kpoint] = internal
    end
    return inverse
end

"""Record the exact validated neighbor-order map used for streamed F/C assembly."""
function _streamed_neighbor_order_contract(stencil, num_kpts::Int)
    inverse = _validated_source_to_internal_neighbor_order(stencil, num_kpts)
    # Text serialization makes the provenance digest independent of host endianness.
    serialized = string(size(inverse, 1), ",", num_kpts, ";", join(vec(inverse), ","))
    return Dict{String, Any}(
        "algorithm" => STREAMED_NEIGHBOR_ORDER_ALGORITHM,
        "source_to_internal_sha256" => bytes2hex(SHA.sha256(serialized)),
        "source_to_internal" => vec(copy(inverse)),
        "axis_order" => "source_neighbor,kpoint;column_major",
        "num_neighbors" => size(inverse, 1),
        "num_kpoints" => num_kpts,
    )
end

"""
Construct the full derivative-overlap q tensor from direct Wannier90 uIu blocks.

The accumulation order matches the qualified Projector implementation: only
`alpha <= beta` is accumulated from direct overlaps and the exchanged component
is then supplied by Hermitian conjugation. CHK owns the composite Wannier gauge
and the supplied centers own the centered phase convention.
"""
function _construct_exact_full_derivative_overlap_tensor_q(
    chk::WannierCHK,
    stencil,
    wannier_centers_cartesian::Matrix{Float64},
    uiu_file::AbstractString,
    ;
    formatted::Bool = false,
)
    neighbor_count = length(stencil.weights)
    source_to_internal = _validated_source_to_internal_neighbor_order(stencil, chk.num_kpts)
    output = zeros(ComplexF64, chk.num_orbitals, chk.num_orbitals, 3, 3, chk.num_kpts)
    foreach_wannier_uiu_block(
        uiu_file;
        formatted,
        expected_num_bands = chk.num_bands,
        expected_num_kpts = chk.num_kpts,
        expected_num_neighbors = neighbor_count,
    ) do direct_overlap, kpoint, source_second, source_first, _
        first = source_to_internal[source_first, kpoint]
        second = source_to_internal[source_second, kpoint]
        target_first = stencil.neighbors[first, kpoint]
        target_second = stencil.neighbors[second, kpoint]
        wannier =
            chk.v_matrix[:, :, target_first]' * direct_overlap * chk.v_matrix[:, :, target_second]
        first_vector = @view stencil.displacement_cartesian[first, :]
        second_vector = @view stencil.displacement_cartesian[second, :]
        apply_wannier_center_phases!(
            wannier,
            wannier_centers_cartesian,
            first_vector,
            second_vector,
        )
        weight = stencil.weights[first] * stencil.weights[second]
        for beta in 1:3, alpha in 1:beta
            @views output[:, :, alpha, beta, kpoint] .+=
                weight * first_vector[alpha] * second_vector[beta] .* wannier
        end
    end
    for kpoint in 1:chk.num_kpts, beta in 1:3, alpha in 1:beta
        @views output[:, :, beta, alpha, kpoint] .= copy(adjoint(output[:, :, alpha, beta, kpoint]))
    end
    return output
end

"""
Construct the exact uIu-backed derivative set without extending TB symmetrization.

The lower MatrixElements constructor supplies the two Hamiltonian-weighted
MMN/EIG operators. This Wannierization-owned boundary adds
the full uIu tensor and its axial/symmetric decompositions using the same
pair-Wigner--Seitz transform contract as the qualified Projector implementation.
"""
function _construct_exact_wannier_derivative_operators(
    model::TightBindingModel,
    chk::WannierCHK,
    eig::WannierEIG,
    mmn::WannierMMN,
    uiu_file::AbstractString;
    support_tolerance::Float64,
    wigner_seitz_tolerance::Float64,
    search_size::Int,
    wannier_centers_cartesian::Matrix{Float64},
)
    hamiltonian_weighted_kinds = (
        REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION,
        REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP,
    )
    derivative_set = construct_wannier_derivative_operators(
        model,
        chk,
        eig,
        mmn;
        requested = hamiltonian_weighted_kinds,
        support_tolerance,
        wigner_seitz_tolerance,
        search_size,
        wannier_centers_cartesian,
    )
    stencil = match_finite_difference_stencil_to_mmn(build_finite_difference_stencil(chk), chk, mmn)
    full_q = _construct_exact_full_derivative_overlap_tensor_q(
        chk,
        stencil,
        wannier_centers_cartesian,
        uiu_file,
    )
    transform_plan = WannierPairWignerSeitzTransformPlan(
        chk,
        model.r_vectors;
        wigner_seitz_tolerance,
        search_size,
    )
    full_r = wannier_q_to_pair_wigner_seitz(
        full_q,
        chk,
        transform_plan;
        support_tolerance,
        label = operator_storage_name(REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR),
    )
    axial_r, symmetric_r = derive_axial_and_symmetric_derivative_overlaps(full_r)
    matrices = copy(derivative_set.matrices)
    matrices[REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR] = full_r
    matrices[REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP] = axial_r
    matrices[REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP] = symmetric_r
    return WannierDerivativeOperatorSet(model.r_vectors, matrices)
end
