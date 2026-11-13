"""Return an existing orthogonal model's physical basis contract, never inferred from A values."""
optical_momentum_basis(model::TightBindingModel) = model.position_model

# Native analytic inputs already distinguish exact point orbitals and a zero-connection fixed basis.
function optical_momentum_basis(model::AnalyticKModel)
    model.input.basis in (:fixed_orthonormal, :point_orbitals) || throw(
        ArgumentError("OPTICAL_MOMENTUM_EXPLICIT_CONNECTION_HAS_NO_QUALIFIED_CROSS_POINT_LINK"),
    )
    return model.input.basis
end

# This provider is not an extension of the nonorthogonal finite-q domain.
optical_momentum_basis(model::AbstractResponseModel) =
    throw(ArgumentError("OPTICAL_MOMENTUM_ORTHOGONAL_BASIS_CONTRACT_REQUIRED"))

"""
Build the physical optical link U_left' F(k,q) U_right in caller-owned storage.

Here q is k_left-k_right, in Cartesian inverse Angstrom; k is their midpoint.
For Wannier H/A inputs the R-only orbital link is I+i*q[d]*A_R[d](k).
A is the raw orbital connection, never a band Berry connection. Convention I is
obtained by exact endpoint basis transforms from this R-only first-order link;
its raw centered A is first restored by the affine +tau rule. No exponential
of A, polar normalization, gap inverse, response prefactor or response truncation
is applied. Point-orbital/fixed inputs retain their explicit exact basis contract.
The two matrix buffers must be mutually disjoint and disjoint from input/output.
Only this optical q-link changes; auxiliary geometric transport retains its owner.
"""
function compute_optical_momentum_overlap!(
    output::AbstractMatrix{ComplexF64},
    left::KPointMatrixData,
    right::KPointMatrixData,
    center::KPointMatrixData,
    model::AbstractResponseModel,
    plan::MatrixElementPlan,
    centers::AbstractMatrix{<:Real},
    q_cartesian::Union{AbstractVector{<:Real}, NTuple{3, <:Real}},
    orbital_link::AbstractMatrix{ComplexF64},
    temporary::AbstractMatrix{ComplexF64},
)
    n = length(left.spectrum.energies)
    size(output) == size(orbital_link) == size(temporary) == (n, n) ||
        throw(DimensionMismatch("optical link matrix shape"))
    for data in (left, right, center)
        length(data.spectrum.energies) == n ||
            throw(DimensionMismatch("optical link spectrum sizes"))
        _has_capability(data.computed_mask, SPECTRUM) ||
            throw(ArgumentError("OPTICAL_MOMENTUM_SPECTRUM_NOT_COMPUTED"))
    end
    size(centers) == (3, n) && length(q_cartesian) == 3 ||
        throw(DimensionMismatch("optical link centers/momentum shape"))
    all(isfinite, q_cartesian) || throw(ArgumentError("nonfinite optical momentum"))
    for a in (output, orbital_link, temporary),
        b in (left.spectrum.source_eigenvectors, right.spectrum.source_eigenvectors)

        Base.mightalias(a, b) && throw(ArgumentError("optical link input alias"))
    end
    (
        Base.mightalias(output, orbital_link) ||
        Base.mightalias(output, temporary) ||
        Base.mightalias(orbital_link, temporary)
    ) && throw(ArgumentError("optical link scratch alias"))
    # This is a coordinate roundoff check, not a small-q cutoff or a material gate.
    expected_fractional = model.lattice * collect(q_cartesian) / (2pi)
    endpoint_delta = left.kpoint - right.kpoint
    coordinate_scale =
        max(1.0, norm(left.kpoint, Inf), norm(right.kpoint, Inf), norm(expected_fractional, Inf))
    norm(endpoint_delta - expected_fractional, Inf) <= 64eps(Float64)*coordinate_scale ||
        throw(ArgumentError("OPTICAL_MOMENTUM_ENDPOINT_DIRECTION_MISMATCH"))
    norm(center.kpoint - (left.kpoint + right.kpoint)/2, Inf) <= 64eps(Float64)*coordinate_scale ||
        throw(ArgumentError("OPTICAL_MOMENTUM_CENTER_MISMATCH"))
    basis = optical_momentum_basis(model)
    if all(iszero, q_cartesian)
        return mul!(
            output,
            left.spectrum.source_eigenvectors_adjoint,
            right.spectrum.source_eigenvectors,
        )
    end
    convention = plan.wannier_center_convention
    centered = convention == CONVENTION_I
    convention in (CONVENTION_I, CONVENTION_II) || error("unsupported optical convention")
    raw = nothing
    if basis == :wannier
        _has_capability(center.computed_mask, INTERNAL_CONNECTION) ||
            throw(ArgumentError("OPTICAL_MOMENTUM_RAW_CONNECTION_NOT_COMPUTED"))
        center.position isa PositionMatrixData ||
            throw(ArgumentError("OPTICAL_MOMENTUM_RAW_ORTHOGONAL_CONNECTION_REQUIRED"))
        raw = center.position.wannier_gauge
        raw === nothing && throw(ArgumentError("OPTICAL_MOMENTUM_RAW_CONNECTION_NOT_PREPARED"))
        for buffer in (output, orbital_link, temporary)
            Base.mightalias(buffer, raw) && throw(ArgumentError("optical link raw input alias"))
        end
        for d in 1:3
            iszero(q_cartesian[d]) && continue
            d <= size(raw, 3) || throw(ArgumentError("OPTICAL_MOMENTUM_RAW_DIRECTION_NOT_PREPARED"))
            _axis_required(plan, INTERNAL_CONNECTION, d) ||
                throw(ArgumentError("OPTICAL_MOMENTUM_RAW_DIRECTION_NOT_REQUESTED"))
        end
    end
    fill!(orbital_link, COMPLEX_ZERO)
    @inbounds for column in 1:n, row in 1:n
        value = row == column ? (1.0 + 0.0im) : COMPLEX_ZERO
        if basis == :wannier
            connection = COMPLEX_ZERO
            for d in 1:3
                iszero(q_cartesian[d]) && continue
                a = raw[row, column, d]
                if centered && row == column
                    a += sum(model.lattice[j, d]*centers[j, row] for j in 1:3)
                end
                connection += q_cartesian[d]*a
            end
            if centered
                connection *=
                    cis(2pi*sum(center.kpoint[d]*(centers[d, row]-centers[d, column]) for d in 1:3))
            end
            value += 1im*connection
            if centered
                value *= cis(
                    2pi*sum(
                        right.kpoint[d]*centers[d, column]-left.kpoint[d]*centers[d, row] for
                        d in 1:3
                    ),
                )
            end
        elseif basis == :point_orbitals && !centered && row == column
            value = cis(2pi*sum((left.kpoint[d]-right.kpoint[d])*centers[d, row] for d in 1:3))
        end
        orbital_link[row, column] = value
    end
    mul!(temporary, orbital_link, right.spectrum.source_eigenvectors)
    mul!(output, left.spectrum.source_eigenvectors_adjoint, temporary)
    return output
end
