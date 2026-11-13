"""Local orthogonal curvature derivative contractions.

These dense six-partition ports retain the research formula and D2 correction,
while using r73 raw operator jets and its existing spectrum. They are reference
contractions for independent validation; they carry no occupations, integration
weights, lifetimes, SI prefactors, file access, distributed execution or finite-difference fallback.
"""
const ORTHOGONAL_BCD_PARTITIONS = (
    :omega_derivative,
    :second_derivative,
    :first_derivative,
    :omega_transport,
    :mixed_products,
    :pure_D,
)
const ORTHOGONAL_BCQ_PARTITIONS = (
    :derivative_partitions,
    :omega_transport,
    :mixed_transport,
    :left_delta,
    :right_delta,
    :pure_Dprime,
)

# Evaluate the existing three-index analytic BCD matrix partitions from a current band-derivative workspace.
function orthogonal_bcd_partition_matrices!(
    workspace::MatrixElements.OrthogonalBandDerivativeWorkspace,
    tensor_indices::NTuple{3, Int},
)
    MatrixElements.validate_orthogonal_band_derivatives(workspace)
    alpha, beta, gamma = tensor_indices

    Aa = MatrixElements.geometry_position_channel(workspace.jets, alpha, (0, 0, 0))
    Ab = MatrixElements.geometry_position_channel(workspace.jets, beta, (0, 0, 0))
    Aag = MatrixElements.geometry_position_channel(
        workspace.jets,
        alpha,
        MatrixElements.geometry_derivative_order(gamma),
    )
    Abg = MatrixElements.geometry_position_channel(
        workspace.jets,
        beta,
        MatrixElements.geometry_derivative_order(gamma),
    )

    Omega =
        MatrixElements.geometry_position_channel(
            workspace.jets,
            beta,
            MatrixElements.geometry_derivative_order(alpha),
        ) - MatrixElements.geometry_position_channel(
            workspace.jets,
            alpha,
            MatrixElements.geometry_derivative_order(beta),
        )
    Omega_g =
        MatrixElements.geometry_position_channel(
            workspace.jets,
            beta,
            MatrixElements.geometry_derivative_order(alpha, gamma),
        ) - MatrixElements.geometry_position_channel(
            workspace.jets,
            alpha,
            MatrixElements.geometry_derivative_order(beta, gamma),
        )

    Da = MatrixElements.orthogonal_band_first_derivative!(workspace, alpha)
    Db = MatrixElements.orthogonal_band_first_derivative!(workspace, beta)
    Dg = MatrixElements.orthogonal_band_first_derivative!(workspace, gamma)
    Dag = MatrixElements.orthogonal_band_second_derivative!(workspace, alpha, gamma)
    Dbg = MatrixElements.orthogonal_band_second_derivative!(workspace, beta, gamma)

    # Preserve the donor six-partition multiplication order; independent
    # physical qualification is required before Runtime admission.
    # Every derivative of S is identically zero in the orthogonal branch.
    omega_derivative = Omega_g

    second_derivative =
        -Dg * Db * Aa + Dbg * Aa - Db * Dg * Aa - Aag * Db + Dg * Da * Ab - Dag * Ab +
        Da * Dg * Ab +
        Abg * Da

    first_derivative = Db * Aag - Aa * Dbg - Da * Abg + Ab * Dag

    omega_transport = -Dg * Omega + Omega * Dg

    mixed_products = Dg * Aa * Db - Dg * Ab * Da + Db * Aa * Dg - Da * Ab * Dg

    pure_D =
        -im * Da * Dbg - im * Dag * Db +
        im * Dg * Da * Db +
        im * Da * Dg * Db +
        im * Db * Dag +
        im * Dbg * Da - im * Dg * Db * Da - im * Db * Dg * Da

    return (
        omega_derivative = omega_derivative,
        second_derivative = second_derivative,
        first_derivative = first_derivative,
        omega_transport = omega_transport,
        mixed_products = mixed_products,
        pure_D = pure_D,
    )
end

# Evaluate the existing four-index analytic BCQ matrix partitions from a current band-derivative workspace.
function orthogonal_bcq_partition_matrices!(
    workspace::MatrixElements.OrthogonalBandDerivativeWorkspace,
    tensor_indices::NTuple{4, Int},
)
    MatrixElements.validate_orthogonal_band_derivatives(workspace)
    alpha, beta, gamma, delta = tensor_indices

    Aa = MatrixElements.geometry_position_channel(workspace.jets, alpha, (0, 0, 0))
    Ab = MatrixElements.geometry_position_channel(workspace.jets, beta, (0, 0, 0))
    Aag = MatrixElements.geometry_position_channel(
        workspace.jets,
        alpha,
        MatrixElements.geometry_derivative_order(gamma),
    )
    Abg = MatrixElements.geometry_position_channel(
        workspace.jets,
        beta,
        MatrixElements.geometry_derivative_order(gamma),
    )
    Aad = MatrixElements.geometry_position_channel(
        workspace.jets,
        alpha,
        MatrixElements.geometry_derivative_order(delta),
    )
    Abd = MatrixElements.geometry_position_channel(
        workspace.jets,
        beta,
        MatrixElements.geometry_derivative_order(delta),
    )
    Aagd = MatrixElements.geometry_position_channel(
        workspace.jets,
        alpha,
        MatrixElements.geometry_derivative_order(gamma, delta),
    )
    Abgd = MatrixElements.geometry_position_channel(
        workspace.jets,
        beta,
        MatrixElements.geometry_derivative_order(gamma, delta),
    )

    Omega =
        MatrixElements.geometry_position_channel(
            workspace.jets,
            beta,
            MatrixElements.geometry_derivative_order(alpha),
        ) - MatrixElements.geometry_position_channel(
            workspace.jets,
            alpha,
            MatrixElements.geometry_derivative_order(beta),
        )
    Omega_d =
        MatrixElements.geometry_position_channel(
            workspace.jets,
            beta,
            MatrixElements.geometry_derivative_order(alpha, delta),
        ) - MatrixElements.geometry_position_channel(
            workspace.jets,
            alpha,
            MatrixElements.geometry_derivative_order(beta, delta),
        )
    Omega_g =
        MatrixElements.geometry_position_channel(
            workspace.jets,
            beta,
            MatrixElements.geometry_derivative_order(alpha, gamma),
        ) - MatrixElements.geometry_position_channel(
            workspace.jets,
            alpha,
            MatrixElements.geometry_derivative_order(beta, gamma),
        )
    Omega_gd =
        MatrixElements.geometry_position_channel(
            workspace.jets,
            beta,
            MatrixElements.geometry_derivative_order(alpha, gamma, delta),
        ) - MatrixElements.geometry_position_channel(
            workspace.jets,
            alpha,
            MatrixElements.geometry_derivative_order(beta, gamma, delta),
        )

    Da = MatrixElements.orthogonal_band_first_derivative!(workspace, alpha)
    Db = MatrixElements.orthogonal_band_first_derivative!(workspace, beta)
    Dg = MatrixElements.orthogonal_band_first_derivative!(workspace, gamma)
    Dd = MatrixElements.orthogonal_band_first_derivative!(workspace, delta)
    Dag = MatrixElements.orthogonal_band_second_derivative!(workspace, alpha, gamma)
    Dad = MatrixElements.orthogonal_band_second_derivative!(workspace, alpha, delta)
    Dbg = MatrixElements.orthogonal_band_second_derivative!(workspace, beta, gamma)
    Dbd = MatrixElements.orthogonal_band_second_derivative!(workspace, beta, delta)
    Dgd = MatrixElements.orthogonal_band_second_derivative!(workspace, gamma, delta)
    Dagd = MatrixElements.orthogonal_band_third_derivative!(workspace, alpha, gamma, delta)
    Dbgd = MatrixElements.orthogonal_band_third_derivative!(workspace, beta, gamma, delta)

    # Six corrected-prime donor partitions. Terms
    # containing derivatives of S are identically zero in the orthogonal branch.
    derivative_partitions =
        Omega_gd - Dbgd' * Aa - Aagd * Db + Dagd' * Ab + Abgd * Da - Dbg' * Aad - Aag * Dbd +
        Dag' * Abd +
        Abg * Dad - Dbd' * Aag - Aad * Dbg +
        Dad' * Abg +
        Abd * Dag - Db' * Aagd - Aa * Dbgd +
        Da' * Abgd +
        Ab * Dagd

    omega_transport = Dgd' * Omega + Omega_d * Dg + Dg' * Omega_d + Omega * Dgd

    mixed_transport =
        -Dgd' * Aa * Db + Dgd' * Ab * Da + Dg * Aad * Db - Dg * Abd * Da + Dg * Aa * Dbd -
        Dg * Ab * Dad - Dbd' * Aa * Dg +
        Dad' * Ab * Dg +
        Db * Aad * Dg - Da * Abd * Dg + Db * Aa * Dgd - Da * Ab * Dgd

    left_delta = -Dd * (Omega_g - Aag * Db + Abg * Da - Aa * Dbg + Ab * Dag + Omega * Dg)

    right_delta = (Omega_g - Dbg' * Aa + Dag' * Ab + Db * Aag - Da * Abg - Dg * Omega) * Dd

    pure_Dprime =
        im * Da' * Dbgd + im * Dad' * Dbg + im * Dagd' * Db + im * Dag' * Dbd - im * Dbgd' * Da -
        im * Db' * Dagd - im * Dbg' * Dad - im * Dbd' * Dag

    return (
        derivative_partitions = derivative_partitions,
        omega_transport = omega_transport,
        mixed_transport = mixed_transport,
        left_delta = left_delta,
        right_delta = right_delta,
        pure_Dprime = pure_Dprime,
    )
end
"""Extract a singleton target diagonal while retaining all intermediate bands.

The partition matrices remain a validation oracle. Neither degeneracy groups nor
an incomplete intermediate-state cutoff are accepted by this local port.
"""
function orthogonal_geometry_partition_diagonal(partitions::NamedTuple, band::Integer)
    n=size(first(Base.values(partitions)), 1)
    1<=band<=n || throw(BoundsError(1:n, band))
    length(partitions)==6 || throw(ArgumentError("six geometry partitions required"))
    diagonal_values=ntuple(index->real(partitions[index][band, band]), 6)
    all(isfinite, diagonal_values) || throw(ArgumentError("nonfinite local geometry partition"))
    total=0.0
    for value in diagonal_values
        total+=value
    end
    return (partitions = diagonal_values, total = total)
end

"""Central-k singleton BCD/BCQ port; no shifted-k or finite-difference calls.

The runtime admits the derivative and Fourier backends before constructing this
workspace. Only the existing worker computes the central spectrum. Rejection is
pointwise and fail-closed; an inadmissible spectrum cannot be skipped or replaced
with a zero contribution.
"""
function analytic_berry_curvature_derivative_component!(
    workspace::ConventionalQuantumGeometryWorkspace,
    model::AbstractResponseModel,
    kpoint::Vector{Float64},
    band_group::Vector{Int},
    tensor_indices::Vector{Int},
    gap_tolerance::Float64,
    spatial_dimension::Int,
)
    length(band_group) == 1 ||
        throw(ArgumentError("analytic BCD/BCQ requires an isolated singleton target"))
    model isa Union{TightBindingModel, AnalyticKModel} ||
        throw(ArgumentError("analytic BCD/BCQ requires an orthogonal model"))
    length(tensor_indices) in (3, 4) && all(axis -> axis in 1:spatial_dimension, tensor_indices) ||
        throw(ArgumentError("invalid analytic BCD/BCQ component"))
    derivatives = workspace.analytic_geometry
    derivatives === nothing &&
        throw(ArgumentError("analytic geometry requirements were not planned"))
    _bind_conventional_offset!(workspace, KPointOffset())
    previous_data = workspace.scratch.data
    workspace.scratch.data = workspace.data
    try
        compute_kpoint!(workspace.scratch, model, kpoint; denominator_regularization = 0.0)
        MatrixElements.prepare_orthogonal_geometry_jets!(derivatives.jets, workspace.scratch, model)
        MatrixElements.prepare_orthogonal_band_derivatives!(
            derivatives,
            workspace.data.spectrum;
            gap_tolerance,
        )
    finally
        workspace.scratch.data = previous_data
    end
    component = Tuple(tensor_indices)
    partitions =
        length(component) == 3 ? orthogonal_bcd_partition_matrices!(derivatives, component) :
        orthogonal_bcq_partition_matrices!(derivatives, component)
    return orthogonal_geometry_partition_diagonal(partitions, only(band_group)).total
end
