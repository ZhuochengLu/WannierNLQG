"""
Consume metric-aware covariant position derivatives in the shared physical bracket.

Occupation, broadening, charge, quadrature, tensor symmetrization and output units
remain owned by the existing shared response and Runtime layers. The orthogonal
generalized-derivative implementation is not called for this payload.
"""
function compute_conventional_shift_current_kernel!(
    response_kernel::Array{ComplexF64, 5},
    generalized_position_derivative::Array{ComplexF64, 4},
    data::KPointMatrixData{H, P},
    band_start::Int64,
    band_end::Int64,
    num_orbitals::Int64,
    spatial_dimension::Int64;
    active_pair_mask::Union{Nothing, AbstractMatrix{Bool}} = nothing,
    active_pairs_nmajor::Union{Nothing, AbstractVector{NTuple{2, Int}}} = nothing,
    active_pair_count::Int = -1,
    derivative_required_pairs_nmajor::Union{Nothing, AbstractVector{NTuple{2, Int}}} = nothing,
    derivative_pair_count::Int = -1,
    tensor_indices::Union{Nothing, AbstractVector{<:Integer}} = nothing,
    _generalized_derivative_scratch::Union{Nothing, _ConventionalGeneralizedDerivativeScratch} = nothing,
    _generalized_derivative_strategy::Symbol = :auto,
) where {H, P <: NonorthogonalPositionMatrixData}
    num_orbitals == length(data.spectrum.energies) ||
        throw(DimensionMismatch("nonorthogonal band count"))
    size(generalized_position_derivative) == size(data.position.generalized_derivatives) ||
        throw(DimensionMismatch("nonorthogonal derivative scratch shape"))
    _generalized_derivative_strategy in _GENERALIZED_DERIVATIVE_STRATEGIES ||
        throw(ArgumentError("unknown generalized derivative strategy"))
    _clear_response_kernel!(response_kernel, tensor_indices)
    copyto!(generalized_position_derivative, data.position.generalized_derivatives)
    return _assemble_conventional_shift_current_kernel_from_derivative!(
        response_kernel,
        generalized_position_derivative,
        data,
        band_start,
        band_end,
        spatial_dimension;
        active_pair_mask = active_pair_mask,
        active_pairs_nmajor = active_pairs_nmajor,
        active_pair_count = active_pair_count,
        tensor_indices = tensor_indices,
    )
end
