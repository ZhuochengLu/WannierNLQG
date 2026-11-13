"""Band-gauge localized geometry plus the off-diagonal covariant position derivative."""
struct NonorthogonalPositionMatrixData{P, O}
    base::P
    generalized_derivatives::Array{ComplexF64, 4}
    energy_derivatives::Matrix{Float64}
    energy_second_derivatives::Array{Float64, 3}
    denominator_regularization_ev::Float64
    optical_cutoff::O
end

# Preserve the existing expert constructor without requesting optional optical work.
NonorthogonalPositionMatrixData(base, derivative, gradient, hessian, eta) =
    NonorthogonalPositionMatrixData(base, derivative, gradient, hessian, eta, nothing)

"""Expose ordinary position channels through the shared k-point data interface."""
function Base.getproperty(data::NonorthogonalPositionMatrixData, name::Symbol)
    name in (
        :base,
        :optical_cutoff,
        :generalized_derivatives,
        :energy_derivatives,
        :energy_second_derivatives,
        :denominator_regularization_ev,
    ) && return getfield(data, name)
    return getproperty(getfield(data, :base), name)
end

"""Slot-owned metric diagnostics and Fourier phases; no global model cache exists."""
mutable struct NonorthogonalMatrixScratch
    fourier_factors::Vector{ComplexF64}
    metric_diagnostics::IdDict{Any, NamedTuple}
    mesh_diagnostics::Dict{Symbol, Float64}
end

"""Reject an orthogonal model paired with metric-specific storage before any numerical work."""
function prepare_real_space!(
    workspace::MatrixElementWorkspace{D, NonorthogonalMatrixScratch, I},
    model::Union{TightBindingModel, AnalyticKModel},
) where {D, I}
    throw(ArgumentError("metric-aware workspace cannot evaluate an orthogonal model"))
end

"""Reject cross-backend spectrum evaluation instead of falling through to ordinary diagonalization."""
function compute_spectrum!(
    workspace::MatrixElementWorkspace{D, NonorthogonalMatrixScratch, I},
    model::Union{TightBindingModel, AnalyticKModel},
    kpoint::AbstractVector{<:Real},
) where {D, I}
    throw(ArgumentError("metric-aware workspace cannot evaluate an orthogonal model"))
end

"""Allocate the common eigensystem owner with an explicit nonorthogonal position payload."""
function _nonorthogonal_kpoint_data(model::NonorthogonalLocalizedModel, plan)
    data = KPointMatrixData(model.num_orbitals, model.num_r_vectors, plan)
    data.position === nothing && return data
    position = NonorthogonalPositionMatrixData(
        data.position,
        zeros(
            ComplexF64,
            model.num_orbitals,
            model.num_orbitals,
            plan.spatial_dimension,
            plan.spatial_dimension,
        ),
        zeros(Float64, model.num_orbitals, plan.spatial_dimension),
        zeros(Float64, model.num_orbitals, plan.spatial_dimension, plan.spatial_dimension),
        plan.denominator_regularization,
        has_capability(plan, OPTICAL_CUTOFF_VERTICES) ?
        NonorthogonalOpticalCutoffData(data.spectrum, plan.wannier_center_convention) : nothing,
    )
    return KPointMatrixData(
        data.spectrum,
        data.fourier_factors,
        data.hamiltonian,
        position,
        data.spin,
        data.spin_velocity,
        data.computed_mask,
        data.generation,
        data.kpoint,
        data.subspace_position,
        data.spectral_gap_tolerance,
        data.position_regularization_ev,
        data.spin_degeneracy_threshold_ev,
        data.metric_external,
        data.metric_external_generation,
        data.metric_completion_required,
    )
end

"""Validate supported scalar capabilities and the shared D_eta parameter in eV."""
function _validate_nonorthogonal_plan(plan::MatrixElementPlan)
    supported = (
        SPECTRUM,
        ENERGY_DIFFERENCES,
        HAMILTONIAN_DERIVATIVES,
        HAMILTONIAN_SECOND_DERIVATIVES,
        WANNIER_POSITION,
        INTERNAL_CONNECTION,
        INTERNAL_CONNECTION_DERIVATIVES,
        GAUGE_CORRECTION,
        BERRY_CONNECTION,
        VELOCITY_VERTICES,
        WANNIER_CURVATURE,
        OPTICAL_CUTOFF_VERTICES,
    )
    all(kind -> !has_capability(plan, kind) || kind in supported, _ALL_MATRIX_ELEMENT_KINDS) ||
        throw(
            ArgumentError("nonorthogonal backend does not support the requested matrix capability"),
        )
    isfinite(plan.denominator_regularization) && plan.denominator_regularization >= 0 || throw(
        ArgumentError(
            "nonorthogonal denominator_regularization must be finite and nonnegative, in eV",
        ),
    )
    plan.source_gauge_required &&
        throw(ArgumentError("nonorthogonal source-gauge conversion is not supported"))
    return plan
end

"""Admit position capabilities only when the model carries a validated position operator."""
function _validate_nonorthogonal_operators(model::NonorthogonalLocalizedModel, plan)
    plan.wannier_center_convention != CONVENTION_I ||
        model.orbital_centers_cartesian !== nothing ||
        throw(ArgumentError("Convention I requires explicit localized orbital centers"))
    (
        model.position_r !== nothing ||
        !any(
            kind -> has_capability(plan, kind),
            (
                WANNIER_POSITION,
                INTERNAL_CONNECTION,
                INTERNAL_CONNECTION_DERIVATIVES,
                GAUGE_CORRECTION,
                BERRY_CONNECTION,
                VELOCITY_VERTICES,
                WANNIER_CURVATURE,
            ),
        )
    ) || throw(
        ArgumentError("nonorthogonal position capability requires an admitted position operator"),
    )
    return model
end

"""Build metric-aware work storage while preserving the common matrix and batch interfaces."""
function MatrixElementWorkspace(
    model::NonorthogonalLocalizedModel,
    plan::MatrixElementPlan,
    sources::MatrixElementSources = MatrixElementSources(),
)
    _validate_nonorthogonal_plan(plan)
    _validate_nonorthogonal_operators(model, plan)
    all(x -> x === nothing, (sources.spin, sources.spin_velocity, sources.derivative_overlap)) ||
        throw(ArgumentError("nonorthogonal scalar backend accepts only localized H/S/r"))
    data = _nonorthogonal_kpoint_data(model, plan)
    scratch = NonorthogonalMatrixScratch(
        data.fourier_factors,
        IdDict{Any, NamedTuple}(),
        Dict{Symbol, Float64}(),
    )
    return MatrixElementWorkspace(
        plan,
        sources,
        data,
        scratch,
        false,
        MatrixElementEvaluationCounts(),
    )
end

"""Allocate every offset with the same metric-aware payload; spectrum ownership remains unique."""
function KPointBatchWorkspace(
    model::NonorthogonalLocalizedModel,
    plan::MatrixElementPlan,
    offsets::AbstractVector{KPointOffset} = KPointOffset[KPointOffset()],
    sources::MatrixElementSources = MatrixElementSources();
    spectral_gap_tolerance::Real = 1e-10,
    metric_completion_required::Bool = false,
)
    metric_completion_required &&
        throw(ArgumentError("nonorthogonal projector metric completion is unavailable"))
    workspace = MatrixElementWorkspace(model, plan, sources)
    workspace.data.spectral_gap_tolerance = spectral_gap_tolerance
    slots = Dict{KPointOffset, typeof(workspace.data)}(KPointOffset() => workspace.data)
    for offset in offsets
        haskey(slots, offset) || (slots[offset] = _nonorthogonal_kpoint_data(model, plan))
        slots[offset].spectral_gap_tolerance = spectral_gap_tolerance
    end
    return KPointBatchWorkspace(workspace, slots)
end

"""Forbid lazy unplanned offsets until a complete localized cross-point contract exists."""
function matrix_data!(
    batch::KPointBatchWorkspace{W},
    offset::KPointOffset,
) where {D, I, W <: MatrixElementWorkspace{D, NonorthogonalMatrixScratch, I}}
    haskey(batch.slots, offset) || throw(ArgumentError("nonorthogonal offset was not preallocated"))
    return batch.slots[offset]
end

"""Validate model/workspace pairing before preparation; no orthogonal scratch is reused."""
function prepare_real_space!(workspace::MatrixElementWorkspace, model::NonorthogonalLocalizedModel)
    scientific_data_generation(model)
    workspace.scratch isa NonorthogonalMatrixScratch ||
        throw(ArgumentError("nonorthogonal model requires a metric-aware workspace"))
    _validate_nonorthogonal_plan(workspace.plan)
    _validate_nonorthogonal_operators(model, workspace.plan)
    length(workspace.data.spectrum.energies) == model.num_orbitals &&
    length(workspace.data.fourier_factors) == model.num_r_vectors ||
        throw(DimensionMismatch("nonorthogonal workspace/model dimensions differ"))
    workspace.prepared = true
    return workspace
end

"""
Fourier H/S/r and Cartesian derivatives through second order at fractional k.

Phases are exp(+2pi*i*k_fractional.R); Cartesian derivatives multiply by i*R_cart,
where R_cart=lattice'*R in Angstrom. B=r+i*dS equals r' by the translation identity.
These source-basis arrays are independent of any eigensolver gauge.
"""
function nonorthogonal_operator_matrices(
    model::NonorthogonalLocalizedModel,
    kpoint::AbstractVector{<:Real};
    convention::WannierCenterConvention = CONVENTION_II,
)
    length(kpoint) == 3 && all(isfinite, kpoint) ||
        throw(ArgumentError("fractional k point must have three finite components"))
    convention == CONVENTION_I && return _localized_convention_i_matrices(model, kpoint)
    n = model.num_orbitals
    h = zeros(ComplexF64, n, n);
    s = similar(h);
    fill!(s, 0)
    r = model.position_r === nothing ? nothing : zeros(ComplexF64, n, n, 3)
    dh = zeros(ComplexF64, n, n, 3);
    ds = similar(dh);
    fill!(ds, 0)
    d2h = zeros(ComplexF64, n, n, 3, 3);
    d2s = similar(d2h);
    fill!(d2s, 0)
    dr = r === nothing ? nothing : zeros(ComplexF64, n, n, 3, 3)
    for index in 1:model.num_r_vectors
        phase = cis(2pi * dot(kpoint, view(model.r_vectors, :, index)))
        displacement = model.lattice' * view(model.r_vectors, :, index)
        @views h .+= phase .* model.hamiltonian_r[:, :, index]
        @views s .+= phase .* model.overlap_r[:, :, index]
        for a in 1:3
            if r !== nothing
                @views r[:, :, a] .+= phase .* model.position_r[:, :, a, index]
            end
            coefficient = im * displacement[a] * phase
            @views dh[:, :, a] .+= coefficient .* model.hamiltonian_r[:, :, index]
            @views ds[:, :, a] .+= coefficient .* model.overlap_r[:, :, index]
            for b in 1:3
                second = -displacement[a] * displacement[b] * phase
                @views d2h[:, :, a, b] .+= second .* model.hamiltonian_r[:, :, index]
                @views d2s[:, :, a, b] .+= second .* model.overlap_r[:, :, index]
                if dr !== nothing
                    @views dr[:, :, a, b] .+=
                        im * displacement[b] * phase .* model.position_r[:, :, a, index]
                end
            end
        end
    end
    return (
        hamiltonian = h,
        overlap = s,
        position = r,
        hamiltonian_derivatives = dh,
        overlap_derivatives = ds,
        hamiltonian_second_derivatives = d2h,
        overlap_second_derivatives = d2s,
        position_derivatives = dr,
    )
end

"""
Evaluate native Convention I source operators and Cartesian jets before D_eta.

Each (bra,ket,R) term has displacement R_cart+tau_ket-tau_bra and its own
phase. Its position coefficient is r_R-tau_bra*S_R. This is the affine basis
law, not transport of an already regularized Convention II band connection.
"""
function _localized_convention_i_matrices(model, kpoint)
    centers = model.orbital_centers_cartesian
    centers === nothing &&
        throw(ArgumentError("Convention I requires explicit localized orbital centers"))
    n = model.num_orbitals
    h = zeros(ComplexF64, n, n);
    s = similar(h);
    fill!(s, 0)
    dh = zeros(ComplexF64, n, n, 3);
    ds = similar(dh);
    fill!(ds, 0)
    d2h = zeros(ComplexF64, n, n, 3, 3);
    d2s = similar(d2h);
    fill!(d2s, 0)
    r = model.position_r === nothing ? nothing : zeros(ComplexF64, n, n, 3)
    dr = r === nothing ? nothing : zeros(ComplexF64, n, n, 3, 3)
    kcart = 2pi * (model.lattice \ kpoint)
    for index in 1:model.num_r_vectors
        translation = model.lattice' * view(model.r_vectors, :, index)
        for ket in 1:n, bra in 1:n
            displacement = translation + centers[:, ket] - centers[:, bra]
            phase = cis(dot(kcart, displacement))
            hv = phase * model.hamiltonian_r[bra, ket, index]
            sv = phase * model.overlap_r[bra, ket, index]
            h[bra, ket] += hv;
            s[bra, ket] += sv
            for a in 1:3
                dh[bra, ket, a] += im * displacement[a] * hv
                ds[bra, ket, a] += im * displacement[a] * sv
                rv =
                    r === nothing ? nothing :
                    phase * (
                        model.position_r[bra, ket, a, index] -
                        centers[a, bra] * model.overlap_r[bra, ket, index]
                    )
                r === nothing || (r[bra, ket, a] += rv)
                for b in 1:3
                    d2h[bra, ket, a, b] -= displacement[a] * displacement[b] * hv
                    d2s[bra, ket, a, b] -= displacement[a] * displacement[b] * sv
                    dr === nothing || (dr[bra, ket, a, b] += im * displacement[b] * rv)
                end
            end
        end
    end
    return (
        hamiltonian = h,
        overlap = s,
        position = r,
        hamiltonian_derivatives = dh,
        overlap_derivatives = ds,
        hamiltonian_second_derivatives = d2h,
        overlap_second_derivatives = d2s,
        position_derivatives = dr,
    )
end

"""Measure finite effective matrices before their roundoff Hermitian representation."""
function _check_localized_hermiticity(matrix, tolerance, name)
    all(isfinite, matrix) || throw(ArgumentError("$name contains nonfinite values"))
    residual = maximum(abs, matrix - matrix')
    return Float64(residual)
end

"""Solve H*C=S*C*E with positive metric, then verify metric normalization and residual."""
function compute_spectrum!(
    workspace::MatrixElementWorkspace,
    model::NonorthogonalLocalizedModel,
    kpoint::AbstractVector{<:Real},
)
    prepare_real_space!(workspace, model)
    length(kpoint) == 3 && all(isfinite, kpoint) ||
        throw(ArgumentError("invalid fractional k point"))
    data = workspace.data
    if _has_capability(data.computed_mask, SPECTRUM) && all(data.kpoint .== kpoint)
        return data.spectrum
    end
    _start_spectrum_generation!(data, kpoint)
    convention = workspace.plan.wannier_center_convention
    matrices = _workspace_nonorthogonal_operators(workspace, model, kpoint; full = false)
    h, s = matrices.hamiltonian, matrices.overlap
    h_residual = _check_localized_hermiticity(
        h,
        model.hamiltonian_representation_tolerance_ev * model.num_r_vectors,
        "H(k), eV",
    )
    s_residual = _check_localized_hermiticity(
        s,
        model.overlap_representation_tolerance * model.num_r_vectors,
        "S(k), dimensionless",
    )
    effective_metric = Matrix(Hermitian(s, :U))
    effective_hamiltonian = Matrix(Hermitian(h, :U))
    metric_eigenvalues = DenseSpectra.hermitian_eigenvalues(s; uplo = :U)
    lower, upper = extrema(metric_eigenvalues)
    isfinite(lower) && isfinite(upper) && upper > 0 && lower > 0 ||
        throw(ArgumentError("effective S(k) is not positive definite"))
    solution = _localized_generalized_eigensystem(model, h, s)
    # Validate unpublished local storage. A rejected solve must leave neither a
    # SPECTRUM bit nor a partially overwritten accepted eigensystem to cache.
    energies, vectors = solution.values, copy(solution.vectors)
    canonicalize_eigenvectors!(vectors)
    all(isfinite, energies) && all(isfinite, vectors) ||
        throw(ArgumentError("nonfinite generalized eigensystem"))
    raw_h = zeros(ComplexF64, model.num_orbitals, model.num_orbitals)
    raw_s = similar(raw_h)
    fill!(raw_s, 0)
    for index in 1:model.num_r_vectors
        phase = cis(2pi * dot(kpoint, view(model.r_vectors, :, index)))
        @views raw_h .+= phase .* model.raw_hamiltonian_r[:, :, index]
        @views raw_s .+= phase .* model.raw_overlap_r[:, :, index]
    end
    if convention == CONVENTION_I
        kcart = 2pi * (model.lattice \ kpoint)
        phase = Diagonal(cis.(vec(kcart' * model.orbital_centers_cartesian)))
        raw_h = phase' * raw_h * phase
        raw_s = phase' * raw_s * phase
    end
    raw_residual =
        DenseSpectra.generalized_eigen_residual(raw_h, raw_s, energies, vectors, Val(:operators))
    raw_normalization = DenseSpectra.metric_orthogonality(raw_s, vectors, Val(:frobenius))
    raw_metric_effect = norm(vectors' * (raw_s - effective_metric) * vectors)
    effective_residual = DenseSpectra.generalized_eigen_residual(
        effective_hamiltonian,
        effective_metric,
        energies,
        vectors,
        Val(:operators),
    )
    effective_normalization =
        DenseSpectra.metric_orthogonality(effective_metric, vectors, Val(:frobenius))
    accepted = isfinite(effective_residual) && isfinite(effective_normalization)
    warning =
        effective_residual > 1e-11 ||
        effective_normalization > 1e-10 ||
        lower / upper < model.metric_relative_floor
    workspace.scratch.metric_diagnostics[data.spectrum] = (
        status = accepted ? :evaluated : :rejected,
        generation = data.generation,
        kpoint = copy(data.kpoint),
        minimum_metric_eigenvalue = lower,
        maximum_metric_eigenvalue = upper,
        condition_number = upper / lower,
        normalized_eigen_residual = effective_residual,
        metric_normalization_residual = effective_normalization,
        effective_normalized_eigen_residual = effective_residual,
        effective_metric_normalization_residual = effective_normalization,
        original_normalized_eigen_residual = raw_residual,
        original_metric_normalization_residual = raw_normalization,
        original_metric_projection_effect = raw_metric_effect,
        original_metric_triangle_effect = raw_metric_effect,
        hermitian_wrapper_triangle = :upper,
        solver_representation = :pair_projected_effective_operators,
        numerical_warning = warning,
        eigen_residual_reporting_tolerance = 1e-11,
        metric_normalization_reporting_tolerance = 1e-10,
        metric_relative_reporting_floor = model.metric_relative_floor,
        hamiltonian_hermiticity_residual = h_residual,
        overlap_hermiticity_residual = s_residual,
        input_representation = model.representation_diagnostics,
    )
    if accepted
        record = workspace.scratch.metric_diagnostics[data.spectrum]
        aggregate = workspace.scratch.mesh_diagnostics
        aggregate[:spectrum_evaluations] = get(aggregate, :spectrum_evaluations, 0.0)+1
        aggregate[:numerical_warning_evaluations] =
            get(aggregate, :numerical_warning_evaluations, 0.0)+Int(warning)
        aggregate[:minimum_metric_eigenvalue] =
            min(get(aggregate, :minimum_metric_eigenvalue, Inf), lower)
        for key in (
            :maximum_metric_eigenvalue,
            :condition_number,
            :effective_normalized_eigen_residual,
            :effective_metric_normalization_residual,
            :original_normalized_eigen_residual,
            :original_metric_normalization_residual,
            :original_metric_projection_effect,
            :hamiltonian_hermiticity_residual,
            :overlap_hermiticity_residual,
        )
            aggregate[key] = max(get(aggregate, key, 0.0), getproperty(record, key))
        end
    end
    if !accepted
        workspace.counts.fourier_transforms += 1
        workspace.counts.diagonalizations += 1
        throw(
            ArgumentError(
                "effective generalized eigensystem residual or normalization is nonfinite",
            ),
        )
    end
    _store_spectrum_eigensystem!(workspace, solution)
    return data.spectrum
end

"""Solve declared collinear spin blocks independently and merge their actual spectra once."""
function _localized_generalized_eigensystem(model, h, s)
    model.spin_representation == :collinear ||
        return DenseSpectra.generalized_hermitian_spectrum(h, s; uplo = :U)
    n = model.num_orbitals
    up, down = _localized_spin_indices(n, model.spin_ordering)
    values = Float64[]
    vectors = zeros(ComplexF64, n, n)
    offset = 0
    for indices in (up, down)
        block = DenseSpectra.generalized_hermitian_spectrum(
            h[indices, indices],
            s[indices, indices];
            uplo = :U,
        )
        append!(values, block.values)
        vectors[indices, (offset + 1):(offset + length(indices))] = block.vectors
        offset += length(indices)
    end
    order = sortperm(values; alg = MergeSort)
    return (values = values[order], vectors = vectors[:, order])
end

"""Return diagnostics bound to this spectrum slot and generation, including cached batch visits."""
function nonorthogonal_metric_diagnostics(
    workspace::MatrixElementWorkspace{D, NonorthogonalMatrixScratch};
    scope::Symbol = :point,
) where {D}
    scope == :point && return nonorthogonal_metric_diagnostics(workspace.data, workspace)
    scope == :workspace || throw(ArgumentError("unknown nonorthogonal diagnostic scope"))
    isempty(workspace.scratch.mesh_diagnostics) && return (status = :not_evaluated,)
    return (
        status = :evaluated,
        scope = :workspace,
        measurements = copy(workspace.scratch.mesh_diagnostics),
    )
end

"""Read the diagnostics of an explicitly supplied batch slot without changing workspace ownership."""
function nonorthogonal_metric_diagnostics(
    data::KPointMatrixData,
    workspace::MatrixElementWorkspace{D, NonorthogonalMatrixScratch},
) where {D}
    value = get(workspace.scratch.metric_diagnostics, data.spectrum, nothing)
    (value !== nothing && value.generation == data.generation && value.kpoint == data.kpoint) ||
        return (status = :not_evaluated,)
    return value
end

"""Supply the Band check with both H and S validation before generalized diagonalization."""
function compute_checked_spectrum!(
    workspace::MatrixElementWorkspace,
    model::NonorthogonalLocalizedModel,
    kpoint::AbstractVector{<:Real};
    hermiticity_tolerance::Real,
)
    isfinite(hermiticity_tolerance) && hermiticity_tolerance >= 0 ||
        throw(ArgumentError("invalid Hermiticity tolerance"))
    matrices = _workspace_nonorthogonal_operators(workspace, model, kpoint; full = false)
    residual = max(
        _check_localized_hermiticity(matrices.hamiltonian, hermiticity_tolerance, "H(k)"),
        _check_localized_hermiticity(matrices.overlap, hermiticity_tolerance, "S(k)"),
    )
    spectrum = compute_spectrum!(workspace, model, kpoint)
    return (
        spectrum = spectrum,
        hermiticity_residual = residual,
        hermiticity_exceeds_tolerance = residual > hermiticity_tolerance,
    )
end

"""
Evaluate scalar metric geometry with one fixed D_eta prescription.

For B=C'*(r+i*S_a)*C, G=C'*S_a*C and Delta=E_m-E_n,
D_eta=-G/2+N*Delta/(Delta^2+eta^2), N=h_a-(E_n+E_m)*G/2.
The diagonal selects a parallel gauge at this point only. Finite eta is an
approximate tangent, not an exact eigenvector derivative or a block projector.
All transformed derivatives below use that same tangent and differentiated f.
"""
function _nonorthogonal_geometry(
    model,
    kpoint,
    spectrum,
    gap_tolerance;
    denominator_regularization::Real = 0.0,
    convention::WannierCenterConvention = CONVENTION_II,
    source_matrices = nothing,
)
    eta = Float64(denominator_regularization)
    isfinite(eta) && eta >= 0 ||
        throw(ArgumentError("nonorthogonal eta must be finite and nonnegative, in eV"))
    matrices =
        source_matrices === nothing ? nonorthogonal_operator_matrices(model, kpoint; convention) :
        source_matrices
    energies, vectors = spectrum.energies, spectrum.eigenvectors
    n = length(energies)
    minimum_gap =
        n < 2 ? Inf : minimum(abs(energies[m]-energies[l]) for l in 1:n for m in 1:n if l != m)
    exact_degenerate_pairs =
        count(iszero(energies[m]-energies[l]) for l in 1:n for m in 1:n if l != m)
    eta == 0 &&
        exact_degenerate_pairs > 0 &&
        throw(
            ArgumentError(
                "NONORTHOGONAL_SCALAR_DERIVATIVE_UNDEFINED: eta=0 and an exactly zero interband gap",
            ),
        )
    dh = zeros(ComplexF64, n, n, 3);
    ds = similar(dh);
    connection = similar(dh)
    derivative_vectors = similar(dh);
    numerator = similar(dh)
    energy_derivatives = zeros(Float64, n, 3)
    source_connection = matrices.position .+ im .* matrices.overlap_derivatives
    ward_residual = 0.0
    # Borrow read-only axis slices; retain ordered products and owned return arrays.
    @views for a in 1:3
        ward_residual =
            max(ward_residual, maximum(abs, source_connection[:, :, a]-matrices.position[:, :, a]'))
        dh[:, :, a] = vectors'*matrices.hamiltonian_derivatives[:, :, a]*vectors
        ds[:, :, a] = vectors'*matrices.overlap_derivatives[:, :, a]*vectors
        connection[:, :, a] = vectors'*source_connection[:, :, a]*vectors
        for l in 1:n, m in 1:n
            gap = energies[m]-energies[l]
            numerator[l, m, a] = dh[l, m, a]-(energies[l]+energies[m])*ds[l, m, a]/2
            derivative_vectors[l, m, a] = if l == m
                -ds[l, l, a]/2+im*real(connection[l, l, a])
            else
                f = eta == 0 ? inv(gap) : gap/(gap^2+eta^2)
                -ds[l, m, a]/2+numerator[l, m, a]*f
            end
        end
        for l in 1:n
            energy_derivatives[l, a] = real(dh[l, l, a]-energies[l]*ds[l, l, a])
        end
    end
    berry = im*derivative_vectors+connection
    generalized = zeros(ComplexF64, n, n, 3, 3)
    connection_derivatives = similar(generalized)
    tangent_derivatives = similar(generalized);
    fill!(tangent_derivatives, 0)
    energy_second_derivatives = zeros(Float64, n, 3, 3)
    velocity = zeros(ComplexF64, n, n, 3)
    maximum_commutator_defect = 0.0
    maximum_regularization_suppression = 0.0
    # Native ComplexF64 operands use private, fully overwritten products; preserve other promotions.
    hd_scratch_supported =
        vectors isa StridedMatrix{ComplexF64} &&
        matrices.hamiltonian_second_derivatives isa StridedArray{ComplexF64, 4}
    hd_scratch = hd_scratch_supported ? Matrix{ComplexF64}(undef, n, n) : nothing
    hd_product = hd_scratch_supported ? Matrix{ComplexF64}(undef, n, n) : nothing
    hd_last_buffer = hd_scratch_supported ? Matrix{ComplexF64}(undef, n, n) : nothing
    # Keep overlap products private while the completed Hamiltonian product remains live.
    sd_scratch_supported =
        vectors isa StridedMatrix{ComplexF64} &&
        matrices.overlap_second_derivatives isa StridedArray{ComplexF64, 4}
    sd_scratch = sd_scratch_supported ? Matrix{ComplexF64}(undef, n, n) : nothing
    sd_product = sd_scratch_supported ? Matrix{ComplexF64}(undef, n, n) : nothing
    sd_last_buffer = sd_scratch_supported ? Matrix{ComplexF64}(undef, n, n) : nothing
    # Keep connection products distinct from both live Hamiltonian and overlap products.
    bd_scratch_supported =
        vectors isa StridedMatrix{ComplexF64} &&
        matrices.position_derivatives isa StridedArray{ComplexF64, 4} &&
        matrices.overlap_second_derivatives isa StridedArray{ComplexF64, 4}
    bd_scratch = bd_scratch_supported ? Matrix{ComplexF64}(undef, n, n) : nothing
    bd_product = bd_scratch_supported ? Matrix{ComplexF64}(undef, n, n) : nothing
    bd_last_buffer = bd_scratch_supported ? Matrix{ComplexF64}(undef, n, n) : nothing
    @views for a in 1:3
        for l in 1:n, m in 1:n
            # B includes i*S_a, so the metric term uses the column energy E_m.
            velocity[l, m, a] =
                dh[l, m, a]-energies[m]*ds[l, m, a]+im*(energies[l]-energies[m])*connection[l, m, a]
            l == m && (velocity[l, l, a] = energy_derivatives[l, a])
            if l != m
                gap = energies[m]-energies[l]
                suppression = eta == 0 ? 0.0 : eta^2/(gap^2+eta^2)
                maximum_regularization_suppression =
                    max(maximum_regularization_suppression, suppression)
                maximum_commutator_defect = max(
                    maximum_commutator_defect,
                    abs(im*(energies[l]-energies[m])*berry[l, m, a]-velocity[l, m, a]),
                )
            end
        end
        for b in 1:3
            d = derivative_vectors[:, :, b]
            hd = if hd_scratch_supported
                mul!(hd_scratch, d', dh[:, :, a])
                mul!(hd_product, dh[:, :, a], d)
                hd_scratch .+= hd_product
                mul!(hd_product, vectors', matrices.hamiltonian_second_derivatives[:, :, a, b])
                mul!(hd_last_buffer, hd_product, vectors)
                hd_scratch .+= hd_last_buffer
                hd_scratch
            else
                d'*dh[:, :, a]+dh[:, :, a]*d+vectors'*matrices.hamiltonian_second_derivatives[
                    :,
                    :,
                    a,
                    b,
                ]*vectors
            end
            sd = if sd_scratch_supported
                mul!(sd_scratch, d', ds[:, :, a])
                mul!(sd_product, ds[:, :, a], d)
                sd_scratch .+= sd_product
                mul!(sd_product, vectors', matrices.overlap_second_derivatives[:, :, a, b])
                mul!(sd_last_buffer, sd_product, vectors)
                sd_scratch .+= sd_last_buffer
                sd_scratch
            else
                d'*ds[:, :, a]+ds[:, :, a]*d+vectors'*matrices.overlap_second_derivatives[:, :, a, b]*vectors
            end
            bd = if bd_scratch_supported
                mul!(bd_scratch, d', connection[:, :, a])
                mul!(bd_product, connection[:, :, a], d)
                bd_scratch .+= bd_product
                mul!(
                    bd_product,
                    vectors',
                    matrices.position_derivatives[
                        :,
                        :,
                        a,
                        b,
                    ]+im*matrices.overlap_second_derivatives[:, :, a, b],
                )
                mul!(bd_last_buffer, bd_product, vectors)
                bd_scratch .+= bd_last_buffer
                bd_scratch
            else
                d'*connection[:, :, a]+connection[:, :, a]*d+vectors'*(
                    matrices.position_derivatives[
                        :,
                        :,
                        a,
                        b,
                    ]+im*matrices.overlap_second_derivatives[:, :, a, b]
                )*vectors
            end
            connection_derivatives[:, :, a, b] = bd
            for l in 1:n
                energy_second_derivatives[l, a, b] =
                    real(hd[l, l]-energies[l]*sd[l, l]-energy_derivatives[l, b]*ds[l, l, a])
            end
            for l in 1:n, m in 1:n
                # No diagonal connection derivative is supplied by this point gauge.
                l == m && continue
                gap = energies[m]-energies[l]
                f = eta == 0 ? inv(gap) : gap/(gap^2+eta^2)
                fp = eta == 0 ? -inv(gap)^2 : (eta^2-gap^2)/(gap^2+eta^2)^2
                nd =
                    hd[
                        l,
                        m,
                    ]-(
                        energies[l]+energies[m]
                    )*sd[l, m]/2-(energy_derivatives[l, b]+energy_derivatives[m, b])*ds[l, m, a]/2
                dd =
                    -sd[l, m]/2+nd*f+numerator[l, m, a]*fp*(
                        energy_derivatives[m, b]-energy_derivatives[l, b]
                    )
                tangent_derivatives[l, m, a, b] = dd
                generalized[l, m, a, b] =
                    im*dd+bd[l, m]-im*(berry[l, l, b]-berry[m, m, b])*berry[l, m, a]
            end
        end
    end
    all(
        x -> all(isfinite, x),
        (
            dh,
            ds,
            connection,
            derivative_vectors,
            berry,
            generalized,
            connection_derivatives,
            tangent_derivatives,
            velocity,
            energy_derivatives,
            energy_second_derivatives,
        ),
    ) || throw(ArgumentError("nonfinite nonorthogonal scalar geometry"))
    diagnostics = (
        prescription = :metric_D_eta,
        denominator_regularization_ev = eta,
        approximation = eta == 0 ? :isolated_band_exact_tangent : :finite_eta_scalar_tangent,
        degenerate_frame_prescription = :metric_normalized_solver_frame_Rayleigh_slopes,
        exact_degenerate_ordered_pairs = exact_degenerate_pairs,
        minimum_gap_ev = minimum_gap,
        near_gap_reporting_threshold_ev = Float64(gap_tolerance),
        ward_residual_angstrom = ward_residual,
        berry_hermiticity_residual_angstrom = maximum(
            norm(berry[:, :, a]-berry[:, :, a]') for a in 1:3
        ),
        tangent_metric_normalization_residual_angstrom = maximum(
            norm(derivative_vectors[:, :, a]+derivative_vectors[:, :, a]'+ds[:, :, a]) for a in 1:3
        ),
        physical_velocity_hermiticity_residual_ev_angstrom = maximum(
            norm(velocity[:, :, a]-velocity[:, :, a]') for a in 1:3
        ),
        velocity_commutator_defect_ev_angstrom = maximum_commutator_defect,
        maximum_regularization_suppression = maximum_regularization_suppression,
        energy_hessian_antisymmetry_ev_angstrom2 = maximum(
            abs,
            energy_second_derivatives-permutedims(energy_second_derivatives, (1, 3, 2)),
        ),
        diagonal_connection_derivatives = :not_supplied,
        diagonal_tangent_derivatives = :not_supplied,
        optical_broadening_semantics = :independent_of_D_eta,
    )
    return (
        source = matrices,
        localized_connection = source_connection,
        hamiltonian_derivatives = dh,
        overlap_derivatives = ds,
        band_connection = connection,
        eigenvector_derivatives = derivative_vectors,
        offdiagonal_tangent_derivatives = tangent_derivatives,
        connection_derivatives = connection_derivatives,
        berry_connection = berry,
        generalized_derivatives = generalized,
        velocity_vertices = velocity,
        energy_derivatives = energy_derivatives,
        energy_second_derivatives = energy_second_derivatives,
        minimum_gap = minimum_gap,
        diagnostics = diagnostics,
    )
end

"""Lower the metric connection curvature before transformation to the band frame.

beta_a=S^-1 B_a, B_a=r_a+i*S_a. For Cartesian derivative b,
beta_a;b=S^-1(B_a;b-S_b beta_a). The lower-index curvature is
S*(beta_b;a-beta_a;b-i[beta_a,beta_b]), in Angstrom squared.
This is the declared localized connection curvature, independently of D_eta.
"""
function _nonorthogonal_ambient_curvature(matrices, vectors)
    metric=Hermitian(matrices.overlap, :U)
    connection=matrices.position+im*matrices.overlap_derivatives
    beta=similar(connection)
    derivative=zeros(ComplexF64, size(connection, 1), size(connection, 2), 3, 3)
    for a in 1:3
        beta[:, :, a]=metric\connection[:, :, a]
        for b in 1:3
            derivative[
                :,
                :,
                a,
                b,
            ]=metric\(
                matrices.position_derivatives[
                    :,
                    :,
                    a,
                    b,
                ]+im*matrices.overlap_second_derivatives[
                    :,
                    :,
                    a,
                    b,
                ]-matrices.overlap_derivatives[:, :, b]*beta[:, :, a]
            )
        end
    end
    lower=similar(derivative);
    band=similar(derivative)
    for a in 1:3, b in 1:3
        lower[
            :,
            :,
            a,
            b,
        ]=metric*(
            derivative[
                :,
                :,
                b,
                a,
            ]-derivative[:, :, a, b]-im*(beta[:, :, a]*beta[:, :, b]-beta[:, :, b]*beta[:, :, a])
        )
        band[:, :, a, b]=vectors'*lower[:, :, a, b]*vectors
    end
    all(isfinite, lower) && all(isfinite, band) ||
        throw(ArgumentError("nonfinite localized metric connection curvature"))
    return (
        lower = lower,
        band = band,
        hermiticity_residual_angstrom2 = maximum(
            norm(band[:, :, a, b]-band[:, :, a, b]') for a in 1:3 for b in 1:3
        ),
        antisymmetry_residual_angstrom2 = maximum(
            norm(band[:, :, a, b]+band[:, :, b, a]) for a in 1:3 for b in 1:3
        ),
    )
end

"""Populate shared capability channels without using orthogonal gauge-derivative formulas."""
function compute_remaining!(workspace::MatrixElementWorkspace, model::NonorthogonalLocalizedModel)
    prepare_real_space!(workspace, model)
    data, plan = workspace.data, workspace.plan
    _has_capability(data.computed_mask, SPECTRUM) || error("compute_spectrum! must run first")
    _invalidate_numerical_capabilities!(data, plan)
    energies = data.spectrum.energies
    if data.hamiltonian !== nothing && data.hamiltonian.energy_differences !== nothing
        for l in eachindex(energies), m in eachindex(energies)
            data.hamiltonian.energy_differences[l, m] = energies[l] - energies[m]
        end
    end
    geometry_required = any(
        kind -> has_capability(plan, kind),
        (
            INTERNAL_CONNECTION,
            INTERNAL_CONNECTION_DERIVATIVES,
            GAUGE_CORRECTION,
            BERRY_CONNECTION,
            VELOCITY_VERTICES,
        ),
    )
    geometry =
        geometry_required ?
        _nonorthogonal_geometry(
            model,
            data.kpoint,
            data.spectrum,
            plan.degeneracy_threshold;
            denominator_regularization = plan.denominator_regularization,
            convention = plan.wannier_center_convention,
            source_matrices = _workspace_nonorthogonal_operators(workspace, model, data.kpoint),
        ) : nothing
    matrices =
        geometry === nothing ? _workspace_nonorthogonal_operators(workspace, model, data.kpoint) :
        geometry.source
    vectors = data.spectrum.eigenvectors
    if geometry !== nothing
        record = workspace.scratch.metric_diagnostics[data.spectrum]
        workspace.scratch.metric_diagnostics[data.spectrum] =
            merge(record, (scalar_geometry = geometry.diagnostics,))
        metrics = workspace.scratch.mesh_diagnostics
        isfinite(geometry.minimum_gap) && (
            metrics[:minimum_band_gap_ev] =
                min(get(metrics, :minimum_band_gap_ev, Inf), geometry.minimum_gap)
        )
        for key in (
            :denominator_regularization_ev,
            :ward_residual_angstrom,
            :berry_hermiticity_residual_angstrom,
            :tangent_metric_normalization_residual_angstrom,
            :physical_velocity_hermiticity_residual_ev_angstrom,
            :velocity_commutator_defect_ev_angstrom,
            :maximum_regularization_suppression,
            :energy_hessian_antisymmetry_ev_angstrom2,
            :exact_degenerate_ordered_pairs,
        )
            metrics[key] = max(get(metrics, key, 0.0), getproperty(geometry.diagnostics, key))
        end
        data.position.energy_derivatives .= geometry.energy_derivatives[:, 1:plan.spatial_dimension]
        data.position.energy_second_derivatives .= geometry.energy_second_derivatives[
            :,
            1:plan.spatial_dimension,
            1:plan.spatial_dimension,
        ]
    end
    if has_capability(plan, WANNIER_CURVATURE)
        curvature=_nonorthogonal_ambient_curvature(matrices, vectors)
        position=data.position
        position.wannier_curvature .=
            curvature.lower[:, :, 1:plan.spatial_dimension, 1:plan.spatial_dimension]
        position.hamiltonian_curvature .=
            curvature.band[:, :, 1:plan.spatial_dimension, 1:plan.spatial_dimension]
        record=workspace.scratch.metric_diagnostics[data.spectrum]
        workspace.scratch.metric_diagnostics[data.spectrum]=merge(
            record,
            (
                ambient_curvature = (
                    hermiticity_residual_angstrom2 = curvature.hermiticity_residual_angstrom2,
                    antisymmetry_residual_angstrom2 = curvature.antisymmetry_residual_angstrom2,
                    convention = :lower_metric_connection_curvature,
                ),
            ),
        )
        for key in (:hermiticity_residual_angstrom2, :antisymmetry_residual_angstrom2)
            outkey=Symbol("ambient_curvature_", key)
            workspace.scratch.mesh_diagnostics[outkey]=max(
                get(workspace.scratch.mesh_diagnostics, outkey, 0.0),
                getproperty(curvature, key),
            )
        end
    end
    for a in 1:plan.spatial_dimension
        if data.hamiltonian !== nothing && data.hamiltonian.derivatives !== nothing
            data.hamiltonian.derivatives[:, :, a] =
                vectors' * matrices.hamiltonian_derivatives[:, :, a] * vectors
        end
        for b in 1:plan.spatial_dimension
            if data.hamiltonian !== nothing && data.hamiltonian.second_derivatives !== nothing
                data.hamiltonian.second_derivatives[:, :, a, b] =
                    vectors' * matrices.hamiltonian_second_derivatives[:, :, a, b] * vectors
            end
        end
        if data.position !== nothing
            position = data.position
            position.wannier_gauge === nothing || (
                position.wannier_gauge[:, :, a] =
                    matrices.position[:, :, a] + im * matrices.overlap_derivatives[:, :, a]
            )
            if position.wannier_connection_derivatives !== nothing
                for b in 1:plan.spatial_dimension
                    position.wannier_connection_derivatives[:, :, a, b] =
                        matrices.position_derivatives[:, :, a, b] +
                        im * matrices.overlap_second_derivatives[:, :, a, b]
                end
            end
            if geometry !== nothing
                position.internal_connection === nothing ||
                    (position.internal_connection[:, :, a] = geometry.band_connection[:, :, a])
                position.gauge_correction === nothing ||
                    (position.gauge_correction[:, :, a] = geometry.eigenvector_derivatives[:, :, a])
                position.berry_connection === nothing ||
                    (position.berry_connection[:, :, a] = geometry.berry_connection[:, :, a])
                position.velocity_vertices === nothing ||
                    (position.velocity_vertices[:, :, a] = geometry.velocity_vertices[:, :, a])
                for b in 1:plan.spatial_dimension
                    position.generalized_derivatives[:, :, a, b] =
                        geometry.generalized_derivatives[:, :, a, b]
                    position.internal_connection_derivatives === nothing || (
                        position.internal_connection_derivatives[:, :, a, b] =
                            geometry.connection_derivatives[:, :, a, b]
                    )
                end
            end
        end
    end
    if data.position !== nothing && data.position.inverse_energy_differences !== nothing
        for l in eachindex(energies), m in eachindex(energies)
            data.position.inverse_energy_differences[l, m] =
                l == m ? 0.0 :
                plan.denominator_regularization == 0 ? inv(energies[m]-energies[l]) :
                (
                    energies[m]-energies[l]
                )/((energies[m]-energies[l])^2+plan.denominator_regularization^2)
        end
    end
    if has_capability(plan, OPTICAL_CUTOFF_VERTICES)
        _prepare_nonorthogonal_optical_cutoff!(
            data.position.optical_cutoff,
            matrices,
            data.spectrum,
            data.generation,
            plan.denominator_regularization,
            plan.wannier_center_convention,
        )
    end
    for kind in _ALL_MATRIX_ELEMENT_KINDS
        has_capability(plan, kind) || continue
        if !_has_capability(data.computed_mask, kind)
            workspace.counts.capability_computations[kind] += 1
            data.computed_mask |= _capability_bit(kind)
        end
    end
    _record_numerical_parameters!(data, plan)
    return data
end

"""Return the retained D_eta dipoles and differentiated tangent for metric expert consumers.

This existing expert interface retains its original aliases and differentiated
D_eta prescription. It does not select the optional cutoff optical capability.
SHG uses cutoff_optical_position_vertices instead; other consumers are unchanged.

The independent intermediate width weights energy sums only. The orthogonal
Eq.19 correction is unavailable for this prescription and is never silently ignored.
"""
function optical_position_vertices(
    data::KPointMatrixData{H, P},
    eta,
    eta_correction;
    active_pairs = nothing,
) where {H, P <: NonorthogonalPositionMatrixData}
    isfinite(eta) && eta>0 ||
        throw(ArgumentError("SHG intermediate_regularization must be finite and positive in eV"))
    geometric_eta=data.position.denominator_regularization_ev
    isfinite(geometric_eta) && geometric_eta>0 || throw(
        ArgumentError(
            "NONORTHOGONAL_SHG_POSITIVE_GEOMETRY_REQUIRED: planned denominator_regularization must be finite and positive in eV",
        ),
    )
    eta_correction && throw(ArgumentError("NONORTHOGONAL_SHG_ETA_CORRECTION_UNSUPPORTED"))
    return data.berry_connection,
    data.berry_connection,
    data.position.generalized_derivatives,
    data.gauge_correction
end

"""Return optional metric r0/r_eta/Gcut/D0 in the anchored normalized source frame.

Only OPTICAL_CUTOFF_VERTICES prepares this capability. Its slot-owned source
jet retains the raw diagonal connection; the old parallel-gauge point diagonal
must not substitute for it. Geometry eta controls vertices and Gcut; the supplied
positive eta is the independent response energy-sum width, not a new geometry key.
No occupation, tensor selection, charge, volume or BZ weight is inserted here.
The intermediate r_eta aliases the existing slot-owned scalar dipole (including
its point-gauge diagonal). Only its off-diagonal entries enter SHG. The source
Abar diagonal used inside Gcut is retained independently. Other outputs are newly
allocated; active_pairs limits G only, not intermediate sums.
"""
function cutoff_optical_position_vertices(
    data::KPointMatrixData{H, P},
    eta,
    eta_correction;
    active_pairs = nothing,
) where {H, P <: NonorthogonalPositionMatrixData}
    isfinite(eta) && eta>0 ||
        throw(ArgumentError("SHG intermediate_regularization must be finite and positive in eV"))
    eta_correction && throw(ArgumentError("NONORTHOGONAL_SHG_ETA_CORRECTION_UNSUPPORTED"))
    cutoff=data.position.optical_cutoff
    cutoff !== nothing &&
    _has_capability(data.computed_mask, OPTICAL_CUTOFF_VERTICES) &&
    cutoff.generation==data.generation || throw(
        ArgumentError(
            "OPTICAL_CUTOFF_VERTICES must be requested and prepared for this k-point generation",
        ),
    )
    eta_g=cutoff.geometric_regularization_ev
    isfinite(eta_g) && eta_g>0 ||
        throw(ArgumentError("NONORTHOGONAL_SHG_POSITIVE_GEOMETRY_REQUIRED"))
    count=length(data.spectrum.energies)
    bare=zeros(ComplexF64, count, count, 3)
    regular=similar(bare)
    dipole=similar(bare)
    derivative=zeros(ComplexF64, count, count, 3, 3)
    commutator_a=zeros(ComplexF64, count, count)
    commutator_h=similar(commutator_a)
    optical_position_vertices!(
        bare,
        regular,
        dipole,
        nothing,
        derivative,
        commutator_a,
        commutator_h,
        cutoff.source,
        eta_g,
        false;
        active_pairs,
    )
    return dipole, data.berry_connection, derivative, bare
end

"""Return the isolated-band bare curvature in Angstrom squared for a metric endpoint.

The caller selects an isolated band; this does not define degenerate-block response
or prepare a global eta=0 scalar tangent. B=C'*(r+i*S_a)*C obeys B-B'=i*G,
so G is recovered from the prepared connection without dividing by a small gap.
For each ordered pair r0=(B+B')/2+i*(h-(E_n+E_m)*G/2)*I0(E_m-E_n).
I0 is the existing bare cutoff: the finite connection remains when I0=0.
The ambient metric curvature and both ordered position factors are retained.
No occupation, response threshold, width, charge or BZ factor is inserted.
"""
function isolated_band_curvature(
    data::KPointMatrixData{H, P},
    band::Int,
) where {H, P <: NonorthogonalPositionMatrixData}
    energies=data.spectrum.energies
    connection=data.internal_connection
    derivatives=data.hamiltonian_derivatives
    count=length(energies);
    dimension=size(connection, 3)
    row=zeros(ComplexF64, count, dimension);
    column=similar(row)
    for m in 1:count
        m==band && continue
        inverse=bare_energy_inverse(energies[m]-energies[band])
        reverse_inverse=bare_energy_inverse(energies[band]-energies[m])
        average=(energies[band]+energies[m])/2
        for a in 1:dimension
            forward=connection[band, m, a];
            reverse=connection[m, band, a]
            metric_forward=-im*(forward-conj(reverse))
            metric_reverse=-im*(reverse-conj(forward))
            finite_forward=(forward+conj(reverse))/2
            finite_reverse=(reverse+conj(forward))/2
            numerator_forward=derivatives[band, m, a]-average*metric_forward
            numerator_reverse=derivatives[m, band, a]-average*metric_reverse
            row[m, a]=iszero(inverse) ? finite_forward : finite_forward+im*numerator_forward*inverse
            column[
                m,
                a,
            ]=iszero(reverse_inverse) ? finite_reverse :
              finite_reverse+im*numerator_reverse*reverse_inverse
        end
    end
    curvature=zeros(Float64, dimension, dimension)
    for a in 1:dimension, b in 1:dimension
        a==b && continue
        value=real(data.hamiltonian_curvature[band, band, a, b])
        for m in 1:count
            m==band && continue
            value-=2imag(row[m, a]*column[m, b])
        end
        curvature[a, b]=value
    end
    return curvature
end
