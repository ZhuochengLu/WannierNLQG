# Preserve the established unconstrained initialization for random/restart and
# for AMN inputs without frozen bands.
function _legacy_initial_frames(
    config::SymmetryAdaptedWannierizationConfig,
    representation::BandRepresentation,
    outer_indices::Vector{Vector{Int}},
    frozen_indices::Vector{Vector{Int}},
    num_wannier::Int,
    amn::Union{Nothing, Array{ComplexF64, 3}},
    restart::Union{Nothing, Array{ComplexF64, 3}},
    ;
    spectrum_audit::Union{Nothing, HermitianSpectrumAudit} = nothing,
)
    nb, nk = size(representation.energies_ev)
    frames = Vector{Matrix{ComplexF64}}(undef, nk)
    for kpoint in 1:nk
        source = if config.solver.initialization == :amn
            amn === nothing && throw(ArgumentError("AMN initialization data are missing"))
            Matrix{ComplexF64}(@view amn[:, :, kpoint])
        elseif config.solver.initialization == :restart
            restart === nothing && throw(ArgumentError("restart initialization data are missing"))
            Matrix{ComplexF64}(@view restart[:, :, kpoint])
        else
            rng = MersenneTwister(config.solver.random_seed + UInt64(kpoint))
            randn(rng, nb, num_wannier) .+ 1.0im .* randn(rng, nb, num_wannier)
        end
        size(source) == (nb, num_wannier) ||
            throw(ArgumentError("initial frame has incompatible dimensions at k-point $(kpoint)"))
        outer = outer_indices[kpoint]
        frozen = frozen_indices[kpoint]
        free = setdiff(outer, frozen)
        free_dimension = num_wannier - length(frozen)
        length(free) >= free_dimension ||
            throw(ArgumentError("free outer subspace is too small at k-point $(kpoint)"))
        free_amplitudes = @view source[free, :]
        free_projector = Matrix{ComplexF64}(free_amplitudes * free_amplitudes')
        decomposition = _validated_hermitian_spectrum(
            free_projector;
            tolerance = config.input.representation_tolerance,
            context = "legacy_initial_free_complement:kpoint=$(kpoint)",
            audit = spectrum_audit,
        )
        decomposition.success || throw(
            ArgumentError("HERMITIAN_SPECTRAL_DECOMPOSITION_FAILED at initial k-point $(kpoint)"),
        )
        order = sortperm(decomposition.values; rev = true)
        free_frame = Matrix{ComplexF64}(decomposition.vectors[:, order[1:free_dimension]])
        frame = zeros(ComplexF64, nb, num_wannier)
        for (column, band) in enumerate(frozen)
            frame[band, column] = 1.0
        end
        free_dimension > 0 && (frame[free, (length(frozen) + 1):end] .= free_frame)
        selected = sort!(union(frozen, free))
        alignment = _orthonormalize_columns(
            @view(frame[selected, :])' * @view(source[selected, :]),
            config.input.representation_tolerance;
            audit = spectrum_audit,
            context = "legacy_initial_alignment:kpoint=$(kpoint)",
        )
        alignment === nothing && throw(
            ArgumentError("initial projection alignment is rank deficient at k-point $(kpoint)"),
        )
        frame[selected, :] .= @view(frame[selected, :]) * alignment
        frames[kpoint] = frame
    end
    return frames
end

# Use the independent projectability threshold for every SVD reported by the
# no-symmetry exact-frozen initializer. Representation/group-law accuracy does
# not define numerical rank in the AMN projection map.
function _initialization_spectrum_rank(
    matrix::AbstractMatrix{<:Complex},
    projectability_minimum_singular_value::Float64,
)
    singular_values = Float64.(svdvals(Matrix{ComplexF64}(matrix)))
    sigma_max = isempty(singular_values) ? 0.0 : maximum(singular_values)
    threshold = max(
        projectability_minimum_singular_value,
        maximum(size(matrix); init = 0) * eps(Float64) * sigma_max,
    )
    numerical_rank = count(value -> value > threshold, singular_values)
    return singular_values, numerical_rank, threshold
end

# Return the maximum residual for inclusion of coordinate frozen states in the
# frame projector. This is the invariant required by disentanglement, not an
# alignment or projectability proxy.
function _initialization_frozen_residual(frame::AbstractMatrix{<:Complex}, frozen::Vector{Int})
    isempty(frozen) && return 0.0
    projector = Matrix{ComplexF64}(frame * frame')
    residual = 0.0
    for band in frozen
        column = Vector{ComplexF64}(@view projector[:, band])
        column[band] -= 1.0
        residual = max(residual, norm(column))
    end
    return residual
end

"""gfortran-16 `-O3` scalar complex product used by the W90 4.0.1 oracle."""
@inline function _wannier90_reference_gfortran_complex_product(left::ComplexF64, right::ComplexF64)
    left_real, left_imaginary = reim(left)
    right_real, right_imaginary = reim(right)
    return ComplexF64(
        fma(right_real, left_real, -(left_imaginary * right_imaginary)),
        fma(right_imaginary, left_real, right_real * left_imaginary),
    )
end

"""gfortran-16 `-O3` paired-lane `M(:,n)*conjg(M_nn)` assignment."""
@inline function _wannier90_reference_gfortran_column_conjugate_product(
    value::ComplexF64,
    diagonal::ComplexF64,
)
    value_real, value_imaginary = reim(value)
    diagonal_real, diagonal_imaginary = reim(diagonal)
    return ComplexF64(
        fma(diagonal_imaginary, value_imaginary, value_real * diagonal_real),
        fma(-diagonal_imaginary, value_real, value_imaginary * diagonal_real),
    )
end

@static if Sys.ARCH === :aarch64
    # ARM64 `FCMLA` product used by the locked gfortran-16 Wannier90 oracle.
    # The monolithic Wannier90 4.0.1 build lowers the phase-column assignment to
    # two `FCMLA` instructions. Scalar `fma` expressions implement the same
    # complex product but do not reproduce the instruction's rounding. Keeping
    # the instruction inside the Julia method avoids importing observer state or
    # calling an external Wannier90 numerical kernel.
    @inline function _wannier90_reference_aarch64_fcmla_product(
        value::ComplexF64,
        phase::ComplexF64,
    )
        value_vector = (VecElement(real(value)), VecElement(imag(value)))
        phase_vector = (VecElement(real(phase)), VecElement(imag(phase)))
        result = Base.llvmcall(
            raw"""
            %result = call <2 x double> asm sideeffect "movi $0.2d, #0\0Afcmla $0.2d, $1.2d, $2.2d, #0\0Afcmla $0.2d, $1.2d, $2.2d, #90", "=&w,w,w"(<2 x double> %0, <2 x double> %1)
            ret <2 x double> %result
            """,
            NTuple{2, VecElement{Float64}},
            Tuple{NTuple{2, VecElement{Float64}}, NTuple{2, VecElement{Float64}}},
            value_vector,
            phase_vector,
        )
        return ComplexF64(result[1].value, result[2].value)
    end
end

"""gfortran-16 `-O3` column assignment `tmp_cdq(:,i)*exp(-i*evals(i))`.

The locked Apple-arm64 oracle uses `FCMLA`; other architectures retain the
portable scalar operation order and require their own platform qualification.
"""
@inline function _wannier90_reference_gfortran_phase_column_product(
    value::ComplexF64,
    phase::ComplexF64,
)
    @static if Sys.ARCH === :aarch64
        return _wannier90_reference_aarch64_fcmla_product(value, phase)
    else
        return _wannier90_reference_gfortran_column_conjugate_product(value, conj(phase))
    end
end

"""gfortran-16 `-O3` real part of `z*conjg(z)` used by `wann_omega`."""
@inline function _wannier90_reference_gfortran_magnitude_squared(value::ComplexF64)
    value_real, value_imaginary = reim(value)
    return fma(value_imaginary, value_imaginary, value_real * value_real)
end

"""gfortran-16 `-O3` scalar `real(z*conjg(z))` used by `omega_od`."""
@inline function _wannier90_reference_gfortran_scalar_magnitude_squared(value::ComplexF64)
    value_real, value_imaginary = reim(value)
    return fma(value_real, value_real, value_imaginary * value_imaginary)
end

"""`wann_omega`: `rave += (wb*b)*ln_tmp`, with the final product fused."""
@inline _wannier90_reference_objective_center_accumulate(accumulator, weight, b_cartesian, phase) =
    fma(weight * b_cartesian, phase, accumulator)

"""`wann_domega`: `ln_tmp=wb*phase`; then `rave += b*ln_tmp`."""
@inline _wannier90_reference_gradient_center_accumulate(accumulator, b_cartesian, weighted_phase) =
    muladd(b_cartesian, weighted_phase, accumulator)

"""Locked gfortran-16 `-O3` accumulation of Wannier90's diagonal spread."""
@inline _wannier90_reference_omega_d_accumulate(accumulator, weight, shifted_phase) =
    fma(weight, shifted_phase^2, accumulator)

"""gfortran-16 `-O3` paired-lane `M(:,n)/M_nn` assignment."""
@inline function _wannier90_reference_gfortran_column_division(
    value::ComplexF64,
    diagonal::ComplexF64,
)
    value_real, value_imaginary = reim(value)
    diagonal_real, diagonal_imaginary = reim(diagonal)
    if abs(diagonal_real) < abs(diagonal_imaginary)
        ratio = diagonal_real / diagonal_imaginary
        denominator = fma(ratio, diagonal_real, diagonal_imaginary)
        return ComplexF64(
            (value_real * ratio + value_imaginary) / denominator,
            (value_imaginary * ratio - value_real) / denominator,
        )
    end
    ratio = diagonal_imaginary / diagonal_real
    denominator = fma(ratio, diagonal_imaginary, diagonal_real)
    return ComplexF64(
        fma(ratio, value_imaginary, value_real) / denominator,
        fma(-ratio, value_real, value_imaginary) / denominator,
    )
end

"""gfortran-16 `-O3` reduction used by post-SMV `dis_extract`.

The arm64 oracle vectorizes two window bands at a time, evaluates the
conjugate product in two SIMD lanes, and then adds lane zero followed by lane
one.  Expressing the same formula as a scalar complex dot product changes the
last bit of the projected Hamiltonian and, through ZHPEVX, the later FR step
trajectory.  This helper records that numerical contract without calling an
external Wannier90 or probe kernel.
"""
function _wannier90_reference_gfortran_weighted_conjugate_dot(
    left::AbstractVector{<:Complex},
    right::AbstractVector{<:Complex},
    weights::AbstractVector{<:Real},
)
    length(left) == length(right) == length(weights) ||
        throw(DimensionMismatch("weighted conjugate-dot inputs disagree"))
    accumulator_real = 0.0
    accumulator_imaginary = 0.0
    paired = length(left) - length(left) % 2
    for first_index in 1:2:paired
        for lane in 0:1
            index = first_index + lane
            ar, ai = reim(ComplexF64(left[index]))
            br, bi = reim(ComplexF64(right[index]))
            weight = Float64(weights[index])
            product_real = fma(bi, ai, br * ar)
            product_imaginary = fma(-ai, br, bi * ar)
            accumulator_real += product_real * weight
            accumulator_imaginary += product_imaginary * weight
        end
    end
    if isodd(length(left))
        index = length(left)
        ar, ai = reim(ComplexF64(left[index]))
        br, bi = reim(ComplexF64(right[index]))
        weight = Float64(weights[index])
        product = _wannier90_reference_gfortran_complex_product(
            conj(ComplexF64(left[index])),
            ComplexF64(right[index]),
        )
        accumulator_real += real(product) * weight
        accumulator_imaginary += imag(product) * weight
    end
    return ComplexF64(accumulator_real, accumulator_imaginary)
end

"""Wannier90 4.0.1 `dis_project` full-SVD polar factor.

The reference implementation calls `ZGESVD('A','A')` and forms the product of
the first `num_wann` left singular vectors with the complete right singular
frame.  This dedicated path avoids the QR/rank-completion conventions used by
the general exact-frozen initializer; those conventions are physically
equivalent but can select a measurably different vector in a nearly degenerate
Cr Z boundary cluster.
"""
function _wannier90_reference_dis_project(
    source::AbstractMatrix{<:Complex};
    parent_dimension::Int = size(source, 1),
)
    num_outer, num_wannier = size(source)
    num_outer >= num_wannier && parent_dimension >= num_outer || return (
        success = false,
        frame = zeros(ComplexF64, num_outer, num_wannier),
        reconstructed = zeros(ComplexF64, num_outer, num_wannier),
        singular_values = Float64[],
        info = -1,
    )
    # dis_project keeps num_bands as the leading dimension after moving the
    # active outer-window rows to the top of A.  Reproduce that storage and
    # workspace contract instead of calling SVD on a compact Julia matrix.
    matrix = zeros(ComplexF64, parent_dimension, num_wannier)
    matrix[1:num_outer, :] .= source
    singular_values = zeros(Float64, parent_dimension)
    left = zeros(ComplexF64, parent_dimension, parent_dimension)
    right_adjoint = zeros(ComplexF64, parent_dimension, parent_dimension)
    work = zeros(ComplexF64, 4parent_dimension)
    real_work = zeros(Float64, 5parent_dimension)
    use_external_lp64 = _WANNIER90_REFERENCE_LP64_LAPACK !== nothing
    integer_type = use_external_lp64 ? Cint : LinearAlgebra.BlasInt
    m = integer_type(num_outer)
    n = integer_type(num_wannier)
    lda = integer_type(parent_dimension)
    ldu = integer_type(parent_dimension)
    ldvt = integer_type(parent_dimension)
    lwork = integer_type(length(work))
    info = Ref{integer_type}(0)
    all_vectors = UInt8('A')
    if use_external_lp64
        ccall(
            (:zgesvd_, _WANNIER90_REFERENCE_LP64_LAPACK),
            Cvoid,
            (
                Ref{UInt8},
                Ref{UInt8},
                Ref{Cint},
                Ref{Cint},
                Ptr{ComplexF64},
                Ref{Cint},
                Ptr{Float64},
                Ptr{ComplexF64},
                Ref{Cint},
                Ptr{ComplexF64},
                Ref{Cint},
                Ptr{ComplexF64},
                Ref{Cint},
                Ptr{Float64},
                Ref{Cint},
            ),
            all_vectors,
            all_vectors,
            m,
            n,
            matrix,
            lda,
            singular_values,
            left,
            ldu,
            right_adjoint,
            ldvt,
            work,
            lwork,
            real_work,
            info,
        )
    else
        ccall(
            (LinearAlgebra.BLAS.@blasfunc(zgesvd_), LinearAlgebra.BLAS.libblastrampoline),
            Cvoid,
            (
                Ref{UInt8},
                Ref{UInt8},
                Ref{LinearAlgebra.BlasInt},
                Ref{LinearAlgebra.BlasInt},
                Ptr{ComplexF64},
                Ref{LinearAlgebra.BlasInt},
                Ptr{Float64},
                Ptr{ComplexF64},
                Ref{LinearAlgebra.BlasInt},
                Ptr{ComplexF64},
                Ref{LinearAlgebra.BlasInt},
                Ptr{ComplexF64},
                Ref{LinearAlgebra.BlasInt},
                Ptr{Float64},
                Ref{LinearAlgebra.BlasInt},
            ),
            all_vectors,
            all_vectors,
            m,
            n,
            matrix,
            lda,
            singular_values,
            left,
            ldu,
            right_adjoint,
            ldvt,
            work,
            lwork,
            real_work,
            info,
        )
    end
    successful = info[] == 0
    frame = zeros(ComplexF64, num_outer, num_wannier)
    reconstructed = zeros(ComplexF64, num_outer, num_wannier)
    if successful
        # Match the explicit j,i,l loops and the gfortran-16 -O3 complex
        # contraction used by the registered Wannier90 4.0.1 oracle.  The
        # compiler forms each complex product with one rounded cross product
        # followed by one fused operation.  Julia's generic Complex `*` is
        # algebraically identical, but its two-ULP reconstruction drift is
        # amplified by the frozen QPQ eigenproblem and changes the Cr Z
        # projector above the preregistered 1e-8 gate.
        for column in 1:num_wannier, row in 1:num_outer, inner in 1:num_wannier
            left_real, left_imaginary = reim(left[row, inner])
            right_real, right_imaginary = reim(right_adjoint[inner, column])
            product = _wannier90_reference_gfortran_complex_product(
                left[row, inner],
                right_adjoint[inner, column],
            )
            singular_value = singular_values[inner]
            scaled_real = singular_value * left_real
            scaled_imaginary = left_imaginary * singular_value
            reconstructed_product = ComplexF64(
                fma(scaled_real, right_real, -(right_imaginary * scaled_imaginary)),
                fma(right_real, scaled_imaginary, scaled_real * right_imaginary),
            )
            frame[row, column] += product
            reconstructed[row, column] += reconstructed_product
        end
    end
    return (
        success = successful,
        frame,
        reconstructed,
        singular_values = singular_values[1:min(num_outer, num_wannier)],
        left_vectors = left,
        right_adjoint,
        info = Int(info[]),
    )
end

"""Reproduce Wannier90 4.0.1 `dis_project` followed by `dis_proj_froz`."""
function _wannier90_reference_frozen_amn_initial_frames(
    config::SymmetryAdaptedWannierizationConfig,
    representation::BandRepresentation,
    outer_indices::Vector{Vector{Int}},
    frozen_indices::Vector{Vector{Int}},
    num_wannier::Int,
    amn::Array{ComplexF64, 3},
)
    num_bands, num_kpoints = size(representation.energies_ev)
    size(amn) == (num_bands, num_wannier, num_kpoints) ||
        throw(DimensionMismatch("AMN dimensions disagree with the Wannier90 initializer"))
    frames = Vector{Matrix{ComplexF64}}(undef, num_kpoints)
    diagnostics = WannierInitializationKPointDiagnostic[]
    maximum_isometry = 0.0
    maximum_frozen_residual = 0.0
    for kpoint in 1:num_kpoints
        outer = sort!(unique(Int.(outer_indices[kpoint])))
        frozen = sort!(unique(Int.(frozen_indices[kpoint])))
        all(band -> band in outer, frozen) || throw(
            ArgumentError("frozen bands are not a subset of outer bands at k-point $(kpoint)"),
        )
        length(outer) >= num_wannier ||
            throw(ArgumentError("outer subspace is too small at k-point $(kpoint)"))
        length(frozen) <= num_wannier ||
            throw(ArgumentError("frozen subspace exceeds num_wannier at k-point $(kpoint)"))
        source = Matrix{ComplexF64}(@view amn[outer, :, kpoint])
        all(isfinite, source) ||
            throw(ArgumentError("AMN contains NaN or Inf at k-point $(kpoint)"))
        projected = _wannier90_reference_dis_project(source; parent_dimension = num_bands)
        projected.success || throw(
            ArgumentError(
                "WANNIER90_REFERENCE_ZGESVD_FAILED at k-point $(kpoint), info=$(projected.info)",
            ),
        )
        initial = projected.frame
        outer_position = Dict(index => position for (position, index) in enumerate(outer))
        frozen_local = [outer_position[index] for index in frozen]
        frozen_set = Set(frozen_local)
        free_local = [index for index in eachindex(outer) if index ∉ frozen_set]
        needed = num_wannier - length(frozen)
        selected_outer = zeros(ComplexF64, length(outer), num_wannier)
        if needed > 0
            dimension = length(outer)
            projected_subspace = zeros(ComplexF64, num_bands, num_bands)
            frozen_complement = zeros(ComplexF64, num_bands, num_bands)
            projected_times_complement = zeros(ComplexF64, num_bands, num_bands)
            qpq_storage = zeros(ComplexF64, num_bands, num_bands)
            # Exact dis_proj_froz loop order: cp_s(m,n) sums over projected
            # columns, followed by the two explicit Q multiplications.  The
            # diagonal Q could be applied as a mask, but that would skip the
            # registered accumulation sequence used by Wannier90 4.0.1.
            for column in 1:dimension
                for row in 1:dimension
                    for inner in 1:num_wannier
                        projected_subspace[row, column] +=
                            _wannier90_reference_gfortran_complex_product(
                                initial[row, inner],
                                conj(initial[column, inner]),
                            )
                    end
                end
                column in frozen_local || (frozen_complement[column, column] = 1.0)
            end
            for column in 1:dimension, row in 1:dimension, inner in 1:dimension
                projected_times_complement[row, column] +=
                    _wannier90_reference_gfortran_complex_product(
                        projected_subspace[row, inner],
                        frozen_complement[inner, column],
                    )
            end
            for column in 1:dimension, row in 1:dimension, inner in 1:dimension
                qpq_storage[row, column] += _wannier90_reference_gfortran_complex_product(
                    frozen_complement[row, inner],
                    projected_times_complement[inner, column],
                )
            end
            qpq = Matrix{ComplexF64}(@view qpq_storage[1:dimension, 1:dimension])
            eigensystem = _wannier90_reference_zhpevx(qpq; leading_dimension = num_bands)
            eigensystem.success || throw(
                ArgumentError(
                    "WANNIER90_REFERENCE_FROZEN_ZHPEVX_FAILED at k-point $(kpoint), info=$(eigensystem.info)",
                ),
            )
            first_selected = dimension - needed + 1
            selected_indices = collect(first_selected:dimension)
            zero_count = 0
            good_count = 0
            for index in dimension:-1:first_selected
                if eigensystem.values[index] < 1.0e-8
                    zero_count += 1
                else
                    good_count += 1
                end
            end
            if zero_count > 0
                selected_indices = zeros(Int, needed)
                counter = 1
                for index in dimension:-1:(dimension - good_count + 1)
                    selected_indices[counter] = index
                    counter += 1
                end
                for zero_index in 1:zero_count
                    for eigen_index in dimension:-1:1
                        eigen_index in selected_indices && continue
                        take = true
                        for frozen_column in 1:length(frozen)
                            overlap = zero(ComplexF64)
                            for row in 1:dimension
                                overlap +=
                                    conj(initial[row, frozen_column]) *
                                    eigensystem.vectors[row, eigen_index]
                            end
                            if abs(overlap) > 1.0e-8
                                take = false
                            end
                        end
                        if take
                            selected_indices[good_count + zero_index] = eigen_index
                            break
                        end
                    end
                end
                all(!iszero, selected_indices) || throw(
                    ArgumentError(
                        "WANNIER90_REFERENCE_FROZEN_ORTHO_FIX_FAILED at k-point $(kpoint)",
                    ),
                )
            end
            for (offset, index) in enumerate(selected_indices)
                selected_outer[:, length(frozen) + offset] .= @view eigensystem.vectors[:, index]
            end
        end
        for (column, index) in enumerate(frozen_local)
            selected_outer[index, column] = 1.0
        end
        frame = zeros(ComplexF64, num_bands, num_wannier)
        frame[outer, :] .= selected_outer
        isometry = maximum(
            abs,
            frame' * frame - Matrix{ComplexF64}(I, num_wannier, num_wannier);
            init = 0.0,
        )
        frozen_residual = _initialization_frozen_residual(frame, frozen)
        isometry <= 1.0e-8 || throw(
            ArgumentError(
                "Wannier90 initial frame isometry residual $(isometry) exceeds 1e-8 at k-point $(kpoint)",
            ),
        )
        frozen_residual <= 1.0e-8 || throw(
            ArgumentError(
                "Wannier90 initial frozen residual $(frozen_residual) exceeds 1e-8 at k-point $(kpoint)",
            ),
        )
        maximum_isometry = max(maximum_isometry, isometry)
        maximum_frozen_residual = max(maximum_frozen_residual, frozen_residual)
        rank_tolerance = config.solver.numerical_thresholds.projectability_minimum_singular_value
        full_spectrum, full_rank, full_threshold =
            _initialization_spectrum_rank(@view(amn[:, :, kpoint]), rank_tolerance)
        outer_spectrum, outer_rank, outer_threshold =
            _initialization_spectrum_rank(source, rank_tolerance)
        frozen_source = Matrix{ComplexF64}(@view source[frozen_local, :])
        frozen_spectrum, frozen_rank, frozen_threshold =
            _initialization_spectrum_rank(frozen_source, rank_tolerance)
        projected_free = Matrix{ComplexF64}(@view initial[free_local, :])
        projected_spectrum, projected_rank, projected_threshold =
            _initialization_spectrum_rank(projected_free, rank_tolerance)
        alignment_spectrum = Float64.(svdvals(frame[outer, :]' * source))
        alignment_condition =
            isempty(alignment_spectrum) ? 1.0 :
            minimum(alignment_spectrum) > 0.0 ?
            maximum(alignment_spectrum) / minimum(alignment_spectrum) : Inf
        push!(
            diagnostics,
            WannierInitializationKPointDiagnostic(
                kpoint,
                full_spectrum,
                outer_spectrum,
                frozen_spectrum,
                projected_spectrum,
                alignment_spectrum,
                full_rank,
                outer_rank,
                frozen_rank,
                projected_rank,
                0,
                0,
                full_threshold,
                outer_threshold,
                frozen_threshold,
                projected_threshold,
                alignment_condition,
                isometry,
                isometry,
                frozen_residual,
                frozen_residual,
            ),
        )
        frames[kpoint] = frame
    end
    report = WannierInitializationReport(
        :wannier90_reference_amn_frozen_projection,
        "wannier90-4.0.1-dis_project-dis_proj_froz-v1",
        :COMPLETED,
        diagnostics,
    )
    invariants = (; maximum_isometry, maximum_frozen_residual)
    return frames, diagnostics, invariants, report
end

# Construct an ordinary full-BZ AMN frame with exact frozen-band inclusion.
# Rank deficiency of either AMN factor is diagnostic: missing directions are
# completed deterministically in the target or outer-free band complement.
function _no_symmetry_exact_frozen_amn_initial_frames(
    config::SymmetryAdaptedWannierizationConfig,
    representation::BandRepresentation,
    outer_indices::Vector{Vector{Int}},
    frozen_indices::Vector{Vector{Int}},
    num_wannier::Int,
    amn::Array{ComplexF64, 3},
)
    num_bands, num_kpoints = size(representation.energies_ev)
    size(amn) == (num_bands, num_wannier, num_kpoints) ||
        throw(DimensionMismatch("AMN dimensions disagree with the no-symmetry initializer"))
    frames = Vector{Matrix{ComplexF64}}(undef, num_kpoints)
    kpoint_diagnostics = WannierInitializationKPointDiagnostic[]
    warning_present = false
    tolerance = config.solver.numerical_thresholds.projectability_minimum_singular_value
    identity_target = Matrix{ComplexF64}(I, num_wannier, num_wannier)

    for kpoint in 1:num_kpoints
        source = Matrix{ComplexF64}(@view amn[:, :, kpoint])
        all(isfinite, source) ||
            throw(ArgumentError("AMN contains NaN or Inf at k-point $(kpoint)"))
        outer = sort!(unique(Int.(outer_indices[kpoint])))
        frozen = sort!(unique(Int.(frozen_indices[kpoint])))
        all(band -> band in outer, frozen) || throw(
            ArgumentError("frozen bands are not a subset of outer bands at k-point $(kpoint)"),
        )
        frozen_count = length(frozen)
        frozen_count <= num_wannier || throw(
            ArgumentError(
                "frozen band count $(frozen_count) exceeds num_wannier $(num_wannier) at k-point $(kpoint)",
            ),
        )
        length(outer) >= num_wannier ||
            throw(ArgumentError("outer subspace is too small at k-point $(kpoint)"))
        free = setdiff(outer, frozen)
        free_count = num_wannier - frozen_count
        length(free) >= free_count ||
            throw(ArgumentError("outer-free subspace is too small at k-point $(kpoint)"))

        full_spectrum, full_rank, full_threshold = _initialization_spectrum_rank(source, tolerance)
        outer_source = Matrix{ComplexF64}(@view source[outer, :])
        outer_spectrum, outer_rank, outer_threshold =
            _initialization_spectrum_rank(outer_source, tolerance)
        frozen_source = Matrix{ComplexF64}(@view source[frozen, :])
        frozen_spectrum, frozen_rank, frozen_threshold =
            _initialization_spectrum_rank(frozen_source, tolerance)

        frozen_target_projector = zeros(ComplexF64, num_wannier, num_wannier)
        if frozen_rank > 0
            frozen_factorization = svd(frozen_source; full = false)
            supported = Matrix{ComplexF64}(
                frozen_factorization.V[:, 1:frozen_rank] *
                frozen_factorization.V[:, 1:frozen_rank]',
            )
            frozen_target_projector .= supported
        end
        frozen_target_basis = _deterministic_projector_basis(
            frozen_target_projector,
            frozen_rank,
            max(tolerance, 100 * eps(Float64)),
        )
        frozen_target_basis === nothing &&
            throw(ArgumentError("failed to recover frozen AMN row space at k-point $(kpoint)"))
        frozen_target_basis = something(frozen_target_basis)
        target_completion_count = frozen_count - frozen_rank
        if target_completion_count > 0
            complement_projector = identity_target - frozen_target_basis * frozen_target_basis'
            completion = _deterministic_projector_basis(
                complement_projector,
                target_completion_count,
                max(tolerance, 100 * eps(Float64)),
            )
            completion === nothing &&
                throw(ArgumentError("failed to complete frozen target space at k-point $(kpoint)"))
            frozen_target_basis = hcat(frozen_target_basis, something(completion))
            warning_present = true
        end
        frozen_target_projector = frozen_target_basis * frozen_target_basis'
        target_complement_basis = _deterministic_projector_basis(
            identity_target - frozen_target_projector,
            free_count,
            max(tolerance, 100 * eps(Float64)),
        )
        target_complement_basis === nothing &&
            throw(ArgumentError("failed to construct target complement at k-point $(kpoint)"))
        target_complement_basis = something(target_complement_basis)

        projected_free = Matrix{ComplexF64}(@view source[free, :]) * target_complement_basis
        projected_spectrum, projected_rank, projected_threshold =
            _initialization_spectrum_rank(projected_free, tolerance)
        free_band_projector = zeros(ComplexF64, length(free), length(free))
        if projected_rank > 0
            free_factorization = svd(projected_free; full = false)
            free_band_projector .=
                free_factorization.U[:, 1:projected_rank] *
                free_factorization.U[:, 1:projected_rank]'
        end
        free_band_basis = _deterministic_projector_basis(
            free_band_projector,
            projected_rank,
            max(tolerance, 100 * eps(Float64)),
        )
        free_band_basis === nothing &&
            throw(ArgumentError("failed to recover projected-free AMN range at k-point $(kpoint)"))
        free_band_basis = something(free_band_basis)
        band_completion_count = free_count - projected_rank
        if band_completion_count > 0
            free_identity = Matrix{ComplexF64}(I, length(free), length(free))
            completion = _deterministic_projector_basis(
                free_identity - free_band_basis * free_band_basis',
                band_completion_count,
                max(tolerance, 100 * eps(Float64)),
            )
            completion === nothing && throw(
                ArgumentError("failed to complete outer-free band space at k-point $(kpoint)"),
            )
            free_band_basis = hcat(free_band_basis, something(completion))
            warning_present = true
        end

        frozen_band_basis = zeros(ComplexF64, num_bands, frozen_count)
        for (column, band) in enumerate(frozen)
            frozen_band_basis[band, column] = 1.0
        end
        embedded_free_basis = zeros(ComplexF64, num_bands, free_count)
        free_count > 0 && (embedded_free_basis[free, :] .= free_band_basis)
        raw_frame =
            frozen_band_basis * frozen_target_basis' +
            embedded_free_basis * target_complement_basis'
        all(isfinite, raw_frame) ||
            throw(ArgumentError("initial frame is nonfinite at k-point $(kpoint)"))
        isometry_before = maximum(abs, raw_frame' * raw_frame - identity_target; init = 0.0)
        frozen_residual_before = _initialization_frozen_residual(raw_frame, frozen)
        retraction = _orthonormalize_columns(raw_frame, tolerance)
        retraction === nothing &&
            throw(ArgumentError("initial frame cannot be orthogonalized at k-point $(kpoint)"))
        frame = Matrix{ComplexF64}(something(retraction))
        all(isfinite, frame) ||
            throw(ArgumentError("retracted initial frame is nonfinite at k-point $(kpoint)"))
        isometry_after = maximum(abs, frame' * frame - identity_target; init = 0.0)
        frozen_residual_after = _initialization_frozen_residual(frame, frozen)
        isometry_after <= tolerance || throw(
            ArgumentError(
                "initial frame isometry residual $(isometry_after) exceeds $(tolerance) at k-point $(kpoint)",
            ),
        )
        frozen_residual_after <= tolerance || throw(
            ArgumentError(
                "initial frozen residual $(frozen_residual_after) exceeds $(tolerance) at k-point $(kpoint)",
            ),
        )
        alignment_spectrum = Float64.(svdvals(frame[outer, :]' * outer_source))
        alignment_condition = if isempty(alignment_spectrum)
            1.0
        elseif minimum(alignment_spectrum) > 0.0
            maximum(alignment_spectrum) / minimum(alignment_spectrum)
        else
            Inf
        end
        warning_present |= !isfinite(alignment_condition) || alignment_condition > 1.0e8
        push!(
            kpoint_diagnostics,
            WannierInitializationKPointDiagnostic(
                kpoint,
                full_spectrum,
                outer_spectrum,
                frozen_spectrum,
                projected_spectrum,
                alignment_spectrum,
                full_rank,
                outer_rank,
                frozen_rank,
                projected_rank,
                target_completion_count,
                band_completion_count,
                full_threshold,
                outer_threshold,
                frozen_threshold,
                projected_threshold,
                alignment_condition,
                isometry_before,
                isometry_after,
                frozen_residual_before,
                frozen_residual_after,
            ),
        )
        frames[kpoint] = frame
    end
    report = WannierInitializationReport(
        :amn_full_bz_exact_frozen_embedding,
        "nosym_exact_frozen_rowspace_v2",
        warning_present ? :COMPLETED_WITH_WARNING : :COMPLETED,
        kpoint_diagnostics,
    )
    invariants = (
        maximum_isometry = maximum(diagnostic.isometry_after for diagnostic in kpoint_diagnostics),
        maximum_frozen_residual = maximum(
            diagnostic.frozen_residual_after for diagnostic in kpoint_diagnostics
        ),
    )
    return frames, kpoint_diagnostics, invariants, report
end

# Construct an exact frozen-band embedding and fill its free complement from AMN.
# A rank-deficient AMN projection is retained as incompatibility evidence and
# never replaced by deterministic target-only probes.
function _repair_expanded_frozen_frame(
    frame::Matrix{ComplexF64},
    outer::Vector{Int},
    frozen::Vector{Int},
    tolerance::Float64,
)
    num_bands, num_wannier = size(frame)
    frozen_count = length(frozen)
    free_count = num_wannier - frozen_count
    frozen_count <= num_wannier || return nothing
    frozen_target = if frozen_count == 0
        zeros(ComplexF64, num_wannier, 0)
    else
        result = _orthonormalize_columns(Matrix{ComplexF64}(@view(frame[frozen, :])'), tolerance)
        result === nothing && return nothing
        Matrix{ComplexF64}(something(result))
    end
    target_complement =
        Matrix{ComplexF64}(I, num_wannier, num_wannier) - frozen_target * frozen_target'
    target_complement_basis =
        _deterministic_projector_basis(target_complement, free_count, tolerance)
    target_complement_basis === nothing && return nothing
    outer_free = setdiff(outer, frozen)
    length(outer_free) >= free_count || return nothing
    free_band_basis = if free_count == 0
        zeros(ComplexF64, num_bands, 0)
    else
        free_seed =
            Matrix{ComplexF64}(@view(frame[outer_free, :])) * something(target_complement_basis)
        result = _orthonormalize_columns(free_seed, tolerance)
        result === nothing && return nothing
        embedded = zeros(ComplexF64, num_bands, free_count)
        embedded[outer_free, :] .= something(result)
        embedded
    end
    frozen_band_basis = zeros(ComplexF64, num_bands, frozen_count)
    for (column, band) in enumerate(frozen)
        frozen_band_basis[band, column] = 1.0
    end
    return frozen_band_basis * frozen_target' +
           free_band_basis * something(target_complement_basis)'
end

# Construct an exact frozen-band embedding and fill its free complement from AMN.
# A rank-deficient AMN projection is retained as incompatibility evidence and
# never replaced by deterministic target-only probes.
function _constrained_frozen_initial_frames(
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    outer_indices::Vector{Vector{Int}},
    frozen_indices::Vector{Vector{Int}},
    amn::Array{ComplexF64, 3};
    minimum_singular_value::Float64 = 1.0e-5,
    maximum_condition::Float64 = 1.0e8,
    invariant_tolerance::Float64 = 1.0e-10,
    covariance_tolerance::Float64 = 1.0e-3,
    repair_expanded_invariants::Bool = false,
    construction_policy::Symbol = :strict,
)
    num_bands, num_kpoints = size(representation.energies_ev)
    num_wannier = size(plan.representation_matrices, 1)
    size(amn) == (num_bands, num_wannier, num_kpoints) ||
        throw(DimensionMismatch("AMN dimensions disagree with the frozen initializer"))
    operation_mapping, inventory_diagnostics =
        validate_target_operation_inventory(representation, plan, invariant_tolerance)
    isempty(inventory_diagnostics) || throw(
        FrozenCorepresentationInitializationError(
            :FROZEN_TARGET_COREPRESENTATION_MISMATCH,
            "band and target operation inventories cannot be matched",
            Dict(
                "diagnostic_codes" =>
                    join(string.(getproperty.(inventory_diagnostics, :code)), ","),
            ),
        ),
    )
    frames = [zeros(ComplexF64, num_bands, num_wannier) for _ in 1:num_kpoints]
    diagnostics = NamedTuple[]
    for representative in representation.irreducible_indices
        outer = outer_indices[representative]
        frozen = frozen_indices[representative]
        frozen_count = length(frozen)
        free_count = num_wannier - frozen_count
        frozen_count <= num_wannier || throw(
            FrozenCorepresentationInitializationError(
                :FROZEN_TARGET_COREPRESENTATION_MISMATCH,
                "frozen band rank exceeds the target dimension",
                Dict(
                    "kpoint" => string(representative),
                    "frozen_rank" => string(frozen_count),
                    "target_rank" => string(num_wannier),
                ),
            ),
        )
        length(setdiff(outer, frozen)) >= free_count || throw(
            FrozenCorepresentationInitializationError(
                :FROZEN_FREE_COMPLEMENT_RANK_DEFICIENT,
                "outer-free band space is smaller than the target complement",
                Dict(
                    "kpoint" => string(representative),
                    "outer_free_rank" => string(length(setdiff(outer, frozen))),
                    "target_free_rank" => string(free_count),
                ),
            ),
        )

        frozen_seed = Matrix{ComplexF64}(@view amn[frozen, :, representative])'
        projected_frozen = _frozen_target_embedding(
            representation,
            plan,
            representative,
            frozen,
            operation_mapping,
            frozen_seed,
        )
        frozen_embedding, frozen_spectrum, frozen_condition =
            _rank_gated_polar_columns(projected_frozen; minimum_singular_value, maximum_condition)
        frozen_embedding === nothing && throw(
            FrozenCorepresentationInitializationError(
                :FROZEN_TARGET_COREPRESENTATION_MISMATCH,
                "AMN-seeded frozen corepresentation projection is rank deficient",
                Dict(
                    "kpoint" => string(representative),
                    "singular_values" => repr(frozen_spectrum),
                    "condition" => string(frozen_condition),
                    "minimum_singular_value_gate" => string(minimum_singular_value),
                    "maximum_condition_gate" => string(maximum_condition),
                    "seed" => "AMN",
                ),
            ),
        )
        frozen_embedding = something(frozen_embedding)
        frozen_band_basis = zeros(ComplexF64, num_bands, frozen_count)
        for (column, band) in enumerate(frozen)
            frozen_band_basis[band, column] = 1.0
        end
        frozen_band_projector = frozen_band_basis * frozen_band_basis'
        frozen_target_projector = frozen_embedding * frozen_embedding'
        frozen_frame = frozen_band_basis * frozen_embedding'

        target_complement_projector =
            Matrix{ComplexF64}(I, num_wannier, num_wannier) - frozen_target_projector
        target_complement_basis = _deterministic_projector_basis(
            target_complement_projector,
            free_count,
            minimum_singular_value,
        )
        target_complement_basis === nothing && throw(
            FrozenCorepresentationInitializationError(
                :FROZEN_FREE_COMPLEMENT_RANK_DEFICIENT,
                "target complement basis is rank deficient",
                Dict("kpoint" => string(representative), "target_free_rank" => string(free_count)),
            ),
        )

        free_seed = Matrix{ComplexF64}(@view amn[:, :, representative])
        projected_free = _free_complement_embedding(
            representation,
            plan,
            representative,
            outer,
            frozen_band_projector,
            target_complement_projector,
            operation_mapping,
            free_seed,
        )
        free_columns = projected_free * something(target_complement_basis)
        free_embedding, free_spectrum, free_condition =
            _rank_gated_polar_columns(free_columns; minimum_singular_value, maximum_condition)
        free_embedding === nothing && throw(
            FrozenCorepresentationInitializationError(
                :FROZEN_FREE_COMPLEMENT_RANK_DEFICIENT,
                "AMN-seeded free corepresentation projection is rank deficient",
                Dict(
                    "kpoint" => string(representative),
                    "singular_values" => repr(free_spectrum),
                    "condition" => string(free_condition),
                    "minimum_singular_value_gate" => string(minimum_singular_value),
                    "maximum_condition_gate" => string(maximum_condition),
                    "seed" => "AMN",
                ),
            ),
        )
        free_frame = something(free_embedding) * something(target_complement_basis)'
        frames[representative] = frozen_frame + free_frame
        seed_projection_residual =
            norm(
                (
                    Matrix{ComplexF64}(I, num_bands, num_bands) -
                    frames[representative] * frames[representative]'
                ) * free_seed,
            ) / max(norm(free_seed), eps(Float64))
        push!(
            diagnostics,
            (
                kpoint = representative,
                frozen_rank = frozen_count,
                free_rank = free_count,
                frozen_singular_values = frozen_spectrum,
                frozen_condition = frozen_condition,
                free_singular_values = free_spectrum,
                free_condition = free_condition,
                amn_projection_residual = seed_projection_residual,
            ),
        )
    end
    frames = _expand_ibz_frames(frames, representation, plan)
    if repair_expanded_invariants || construction_policy == :diagnostic
        for kpoint in eachindex(frames)
            # Keep exact qualified input arithmetic unchanged. Diagnostic repair
            # is needed only when approximate sewing broke a hard frame invariant.
            if !repair_expanded_invariants
                frame = frames[kpoint]
                isometry =
                    maximum(abs, frame' * frame - Matrix{ComplexF64}(I, num_wannier, num_wannier))
                frozen = _initialization_frozen_residual(frame, frozen_indices[kpoint])
                max(isometry, frozen) <= invariant_tolerance && continue
            end
            repaired = _repair_expanded_frozen_frame(
                frames[kpoint],
                outer_indices[kpoint],
                frozen_indices[kpoint],
                invariant_tolerance,
            )
            repaired === nothing && throw(
                FrozenCorepresentationInitializationError(
                    :FROZEN_COREPRESENTATION_INITIALIZATION_FAILED,
                    "expanded SCDM frame cannot be repaired without changing the frozen target",
                    Dict("kpoint" => string(kpoint)),
                ),
            )
            frames[kpoint] = something(repaired)
        end
    end
    isometry = maximum(
        maximum(abs, frame' * frame - Matrix{ComplexF64}(I, num_wannier, num_wannier)) for
        frame in frames
    )
    frozen_residual = 0.0
    for kpoint in eachindex(frames), band in frozen_indices[kpoint]
        projector_column = frames[kpoint] * conj.(@view frames[kpoint][band, :])
        expected = zeros(ComplexF64, num_bands)
        expected[band] = 1.0
        frozen_residual = max(frozen_residual, norm(projector_column - expected))
    end
    covariance = _maximum_projector_covariance_error(frames, representation)
    if isometry > invariant_tolerance ||
       frozen_residual > invariant_tolerance ||
       !isfinite(covariance) ||
       (construction_policy == :strict && covariance > covariance_tolerance)
        throw(
            FrozenCorepresentationInitializationError(
                :FROZEN_COREPRESENTATION_INITIALIZATION_FAILED,
                "constructed frozen frame violates a post-construction invariant",
                Dict(
                    "isometry_residual" => string(isometry),
                    "frozen_projector_residual" => string(frozen_residual),
                    "covariance_residual" => string(covariance),
                    "invariant_tolerance" => string(invariant_tolerance),
                    "covariance_tolerance" => string(covariance_tolerance),
                ),
            ),
        )
    end
    maximum_amn_projection_residual =
        isempty(diagnostics) ? 0.0 : maximum(entry.amn_projection_residual for entry in diagnostics)
    return frames,
    diagnostics,
    (
        isometry_residual = isometry,
        frozen_projector_residual = frozen_residual,
        covariance_residual = covariance,
        amn_projection_residual = maximum_amn_projection_residual,
    )
end

"""
Construct one deterministic symmetry-adapted gauge inside a sealed Bloch subspace.

This is an initialization-only operation.  Frozen bands constrain the supplied
projector and the initial embedding; the returned frame may subsequently rotate
by an arbitrary symmetry-allowed `U(k)` without retaining a frozen target block.
"""
function _fixed_subspace_initial_frames(
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    projectors::Vector{Matrix{ComplexF64}},
    amn::Array{ComplexF64, 3},
    frozen_indices::Vector{Vector{Int}};
    minimum_singular_value::Float64 = 1.0e-5,
    maximum_condition::Float64 = 1.0e8,
    probe_count::Int = 8,
    invariant_tolerance::Float64 = 1.0e-10,
    covariance_tolerance::Float64 = 1.0e-3,
)
    num_bands, num_kpoints = size(representation.energies_ev)
    num_wannier = size(plan.representation_matrices, 1)
    length(projectors) == num_kpoints ||
        throw(DimensionMismatch("fixed projector mesh disagrees with the representation"))
    size(amn) == (num_bands, num_wannier, num_kpoints) ||
        throw(DimensionMismatch("fixed-subspace AMN dimensions disagree"))
    operation_mapping, inventory_diagnostics =
        validate_target_operation_inventory(representation, plan, invariant_tolerance)
    isempty(inventory_diagnostics) || throw(
        FrozenCorepresentationInitializationError(
            :FROZEN_TARGET_COREPRESENTATION_MISMATCH,
            "band and target operation inventories cannot be matched",
            Dict{String, String}(),
        ),
    )
    frames = [zeros(ComplexF64, num_bands, num_wannier) for _ in 1:num_kpoints]
    diagnostics = NamedTuple[]
    for representative in representation.irreducible_indices
        fixed_projector = projectors[representative]
        size(fixed_projector) == (num_bands, num_bands) ||
            throw(DimensionMismatch("fixed projector dimension disagrees at k=$(representative)"))
        frozen = frozen_indices[representative]
        frozen_count = length(frozen)
        free_count = num_wannier - frozen_count
        best_frozen = nothing
        best_frozen_spectrum = Float64[]
        best_frozen_condition = Inf
        best_frozen_score = -Inf
        for probe_index in 1:probe_count
            projected = _frozen_target_embedding(
                representation,
                plan,
                representative,
                frozen,
                operation_mapping,
                probe_index,
            )
            embedding, spectrum, condition =
                _rank_gated_polar_columns(projected; minimum_singular_value, maximum_condition)
            score = embedding === nothing || isempty(spectrum) ? -Inf : minimum(spectrum)
            if score > best_frozen_score
                best_frozen = embedding
                best_frozen_spectrum = spectrum
                best_frozen_condition = condition
                best_frozen_score = score
            end
        end
        best_frozen === nothing && throw(
            FrozenCorepresentationInitializationError(
                :FROZEN_TARGET_COREPRESENTATION_MISMATCH,
                "fixed-subspace frozen embedding lost rank",
                Dict(
                    "kpoint" => string(representative),
                    "singular_values" => repr(best_frozen_spectrum),
                    "condition" => string(best_frozen_condition),
                ),
            ),
        )
        frozen_embedding = something(best_frozen)
        frozen_band_basis = zeros(ComplexF64, num_bands, frozen_count)
        for (column, band) in enumerate(frozen)
            frozen_band_basis[band, column] = 1.0
        end
        frozen_band_projector = frozen_band_basis * frozen_band_basis'
        frozen_target_projector = frozen_embedding * frozen_embedding'
        target_complement_projector =
            Matrix{ComplexF64}(I, num_wannier, num_wannier) - frozen_target_projector
        target_complement_basis = _deterministic_projector_basis(
            target_complement_projector,
            free_count,
            minimum_singular_value,
        )
        target_complement_basis === nothing && throw(
            FrozenCorepresentationInitializationError(
                :FROZEN_FREE_COMPLEMENT_RANK_DEFICIENT,
                "fixed-subspace target complement lost rank",
                Dict("kpoint" => string(representative)),
            ),
        )
        best_free = nothing
        best_free_spectrum = Float64[]
        best_free_condition = Inf
        best_free_score = -Inf
        for probe_index in 1:probe_count
            probe = if probe_index == 1
                Matrix{ComplexF64}(@view amn[:, :, representative])
            else
                rng = MersenneTwister(
                    UInt64(0x66697865642d7a) + UInt64(8191 * representative + probe_index),
                )
                randn(rng, num_bands, num_wannier) .+ 1.0im .* randn(rng, num_bands, num_wannier)
            end
            projected = zeros(ComplexF64, num_bands, num_wannier)
            count = 0
            for operation_index in eachindex(representation.operations)
                representation.kpoint_map[operation_index, representative] == representative ||
                    continue
                sewing = @view representation.sewing_matrices[:, :, operation_index, representative]
                target = target_representation(
                    plan,
                    representation,
                    operation_index,
                    representative,
                    operation_mapping[operation_index],
                )
                projected .+=
                    sewing *
                    _operation_action(representation.operations[operation_index], probe) *
                    target'
                count += 1
            end
            count > 0 || throw(ArgumentError("IBZ representative has an empty little group"))
            projected ./= count
            projected =
                fixed_projector *
                (Matrix{ComplexF64}(I, num_bands, num_bands) - frozen_band_projector) *
                projected *
                target_complement_projector
            columns = projected * something(target_complement_basis)
            free_frame, spectrum, condition =
                _rank_gated_polar_columns(columns; minimum_singular_value, maximum_condition)
            score = free_frame === nothing || isempty(spectrum) ? -Inf : minimum(spectrum)
            if score > best_free_score
                best_free = free_frame
                best_free_spectrum = spectrum
                best_free_condition = condition
                best_free_score = score
            end
        end
        best_free === nothing && throw(
            FrozenCorepresentationInitializationError(
                :FROZEN_FREE_COMPLEMENT_RANK_DEFICIENT,
                "fixed-subspace free complement lost rank",
                Dict(
                    "kpoint" => string(representative),
                    "singular_values" => repr(best_free_spectrum),
                    "condition" => string(best_free_condition),
                ),
            ),
        )
        frames[representative] =
            frozen_band_basis * frozen_embedding' +
            something(best_free) * something(target_complement_basis)'
        push!(
            diagnostics,
            (
                kpoint = representative,
                frozen_singular_values = best_frozen_spectrum,
                frozen_condition = best_frozen_condition,
                free_singular_values = best_free_spectrum,
                free_condition = best_free_condition,
            ),
        )
    end
    frames = _expand_ibz_frames(frames, representation, plan)
    residuals = _candidate_invariant_residuals(frames, frozen_indices, representation)
    projector_residual = maximum(
        maximum(abs, frames[kpoint] * frames[kpoint]' - projectors[kpoint]) for
        kpoint in eachindex(frames)
    )
    target_symmetry = _maximum_target_frame_symmetry_error(frames, representation, plan)
    maximum((residuals.isometry, residuals.frozen, projector_residual)) <= invariant_tolerance ||
        throw(
            FrozenCorepresentationInitializationError(
                :FROZEN_COREPRESENTATION_INITIALIZATION_FAILED,
                "fixed-subspace initial frame violates a hard invariant",
                Dict(
                    "isometry_residual" => string(residuals.isometry),
                    "frozen_projector_residual" => string(residuals.frozen),
                    "fixed_projector_residual" => string(projector_residual),
                    "target_symmetry_residual" => string(target_symmetry),
                ),
            ),
        )
    residuals.covariance <= covariance_tolerance || throw(
        FrozenCorepresentationInitializationError(
            :FROZEN_COREPRESENTATION_INITIALIZATION_FAILED,
            "fixed-subspace covariance exceeds the empirical budget",
            Dict("covariance_residual" => string(residuals.covariance)),
        ),
    )
    target_symmetry <= covariance_tolerance || throw(
        FrozenCorepresentationInitializationError(
            :FROZEN_COREPRESENTATION_INITIALIZATION_FAILED,
            "fixed-subspace target-frame covariance exceeds the empirical budget",
            Dict("target_symmetry_residual" => string(target_symmetry)),
        ),
    )
    return frames,
    diagnostics,
    merge(residuals, (fixed_projector = projector_residual, target_symmetry = target_symmetry))
end

# Diagnose one AMN/target candidate with exactly the rank, conditioning, and
# constrained-initializer gates used by the magnetic campaign qualifier.
function _amn_target_qualification_metrics(
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    amn::Array{ComplexF64, 3},
    outer_indices::Vector{Vector{Int}},
    frozen_indices::Vector{Vector{Int}};
    algebra_tolerance::Float64 = 1.0e-10,
    covariance_tolerance::Float64 = 1.0e-3,
    minimum_singular_value::Float64 = 1.0e-5,
    maximum_condition::Float64 = 1.0e8,
)
    num_bands, num_kpoints = size(representation.energies_ev)
    num_wannier = size(plan.representation_matrices, 1)
    size(amn) == (num_bands, num_wannier, num_kpoints) ||
        throw(ArgumentError("AMN dimensions disagree with the band and target representations"))
    operation_mapping, inventory_diagnostics =
        validate_target_operation_inventory(representation, plan, algebra_tolerance)
    isempty(inventory_diagnostics) ||
        throw(ArgumentError("band and target operation inventories cannot be matched"))
    covariance_residuals = Dict(:unitary => 0.0, :antiunitary => 0.0)
    covariance_contexts =
        Dict(:unitary => Dict{String, String}(), :antiunitary => Dict{String, String}())
    for source_kpoint in 1:num_kpoints, operation_index in eachindex(representation.operations)
        target_kpoint = representation.kpoint_map[operation_index, source_kpoint]
        sewing = @view representation.sewing_matrices[:, :, operation_index, source_kpoint]
        target = target_representation(
            plan,
            representation,
            operation_index,
            source_kpoint,
            operation_mapping[operation_index],
        )
        transformed =
            sewing *
            _operation_action(
                representation.operations[operation_index],
                @view(amn[:, :, source_kpoint])
            ) *
            target'
        residual = maximum(abs, transformed - @view(amn[:, :, target_kpoint]))
        channel = representation.operations[operation_index].antiunitary ? :antiunitary : :unitary
        if residual > covariance_residuals[channel]
            covariance_residuals[channel] = residual
            covariance_contexts[channel] = Dict(
                "operation" => string(operation_index),
                "source_kpoint" => string(source_kpoint),
                "target_kpoint" => string(target_kpoint),
                "maximum_error" => string(residual),
            )
        end
    end

    projection_diagnostics = NamedTuple[]
    projection_pass = true
    worst_projected_minimum = Inf
    worst_projected_condition = 0.0
    for representative in representation.irreducible_indices
        source = zeros(ComplexF64, num_bands, num_wannier)
        source[outer_indices[representative], :] .=
            @view amn[outer_indices[representative], :, representative]
        projected = zeros(ComplexF64, size(source))
        little_group_count = 0
        for operation_index in eachindex(representation.operations)
            representation.kpoint_map[operation_index, representative] == representative || continue
            sewing = @view representation.sewing_matrices[:, :, operation_index, representative]
            target = target_representation(
                plan,
                representation,
                operation_index,
                representative,
                operation_mapping[operation_index],
            )
            projected .+=
                sewing *
                _operation_action(representation.operations[operation_index], source) *
                target'
            little_group_count += 1
        end
        little_group_count > 0 ||
            throw(ArgumentError("IBZ representative has an empty little group"))
        projected ./= little_group_count
        singular_values = svdvals(@view projected[outer_indices[representative], :])
        rank = count(>=(minimum_singular_value), singular_values)
        smallest = isempty(singular_values) ? 0.0 : minimum(singular_values)
        largest = isempty(singular_values) ? 0.0 : maximum(singular_values)
        condition = smallest > 0.0 ? largest / smallest : Inf
        passed =
            rank == num_wannier &&
            smallest >= minimum_singular_value &&
            condition <= maximum_condition
        projection_pass &= passed
        worst_projected_minimum = min(worst_projected_minimum, smallest)
        worst_projected_condition = max(worst_projected_condition, condition)
        push!(
            projection_diagnostics,
            (;
                kpoint = representative,
                rank,
                target_rank = num_wannier,
                minimum_singular_value = smallest,
                condition,
                passed,
            ),
        )
    end

    embedding_pass = true
    embedding_failure = ""
    embedding_diagnostics = NamedTuple[]
    initializer_invariants = nothing
    try
        _, embedding_diagnostics, initializer_invariants = _constrained_frozen_initial_frames(
            representation,
            plan,
            outer_indices,
            frozen_indices,
            amn;
            minimum_singular_value,
            maximum_condition,
            invariant_tolerance = algebra_tolerance,
            covariance_tolerance,
        )
    catch exception
        if exception isa FrozenCorepresentationInitializationError
            embedding_pass = false
            embedding_failure = String(exception.code)
        else
            rethrow()
        end
    end
    amn_covariance_pass = maximum(values(covariance_residuals)) <= covariance_tolerance
    failure = if !amn_covariance_pass
        "AMN_TARGET_COVARIANCE_FAILED"
    elseif !projection_pass
        "AMN_LITTLE_GROUP_PROJECTION_RANK_DEFICIENT"
    elseif !embedding_pass
        embedding_failure
    else
        ""
    end
    global_minimum_singular_value =
        minimum(minimum(svdvals(Matrix(@view amn[:, :, kpoint]))) for kpoint in axes(amn, 3))
    average_projectability = sum(abs2, amn) / (num_wannier * num_kpoints)
    coverage = sum(length, frozen_indices) / (num_kpoints * num_wannier)
    return (;
        passed = isempty(failure),
        failure,
        amn_unitary_covariance_residual = covariance_residuals[:unitary],
        amn_antiunitary_covariance_residual = covariance_residuals[:antiunitary],
        amn_unitary_worst_case = covariance_contexts[:unitary],
        amn_antiunitary_worst_case = covariance_contexts[:antiunitary],
        projected_minimum_singular_value = worst_projected_minimum,
        projected_maximum_condition = worst_projected_condition,
        projection_diagnostics,
        embedding_diagnostics,
        initializer_invariants,
        global_minimum_singular_value,
        average_projectability,
        coverage,
    )
end

# Construct one deterministic initial frame at every k-point. Symmetry-constrained
# frozen runs project the numerical AMN seed; symmetry-free runs use the ordinary
# full-BZ AMN/frozen embedding without a target corepresentation.
function _initial_frames_with_diagnostics(
    config::SymmetryAdaptedWannierizationConfig,
    representation::BandRepresentation,
    outer_indices::Vector{Vector{Int}},
    frozen_indices::Vector{Vector{Int}},
    num_wannier::Int,
    amn::Union{Nothing, Array{ComplexF64, 3}},
    restart::Union{Nothing, Array{ComplexF64, 3}};
    plan::Union{Nothing, WannierSymmetryPlan} = nothing,
    spectrum_audit::Union{Nothing, HermitianSpectrumAudit} = nothing,
    paw_scdm_input::Union{Nothing, PAWSCDMInputArtifact} = nothing,
)
    apply_symmetry = symmetry_constraints_applied(config, representation)
    if config.solver.initialization_backend isa PAWSCDMInitialization
        paw_scdm_input === nothing &&
            throw(ArgumentError("SCDM_INPUT_PRECONDITION: PAW-S SCDM payload is missing"))
        seed = something(paw_scdm_input).frames
        if !apply_symmetry && any(indices -> !isempty(indices), frozen_indices)
            frames, diagnostics, invariants, report = _no_symmetry_exact_frozen_amn_initial_frames(
                config,
                representation,
                outer_indices,
                frozen_indices,
                num_wannier,
                seed,
            )
            scdm_report = WannierInitializationReport(
                :paw_s_scdm_then_exact_frozen_embedding,
                "paw_s_scdm_metric_bridge_v1",
                report.status,
                report.kpoints,
            )
            return frames, diagnostics, invariants, scdm_report
        elseif apply_symmetry && any(indices -> !isempty(indices), frozen_indices)
            plan === nothing && throw(
                ArgumentError(
                    "SCDM_INPUT_PRECONDITION: symmetry-constrained SCDM requires a target plan",
                ),
            )
            frames, diagnostics, invariants = _constrained_frozen_initial_frames(
                representation,
                something(plan),
                outer_indices,
                frozen_indices,
                seed,
                repair_expanded_invariants = true,
                construction_policy = config.input.construction_policy,
            )
            return frames, diagnostics, invariants, nothing
        end
        frames = [Matrix{ComplexF64}(@view seed[:, :, kpoint]) for kpoint in axes(seed, 3)]
        return frames, NamedTuple[], nothing, nothing
    end
    if !apply_symmetry &&
       config.solver.initialization == :amn &&
       any(indices -> !isempty(indices), frozen_indices)
        amn === nothing && throw(ArgumentError("frozen AMN initialization data are missing"))
        if effective_wannierization_algorithms(config, representation).disentanglement ==
           :smv_fletcher_reeves_two_stage
            return _wannier90_reference_frozen_amn_initial_frames(
                config,
                representation,
                outer_indices,
                frozen_indices,
                num_wannier,
                something(amn),
            )
        end
        return _no_symmetry_exact_frozen_amn_initial_frames(
            config,
            representation,
            outer_indices,
            frozen_indices,
            num_wannier,
            something(amn),
        )
    end
    if apply_symmetry &&
       config.solver.initialization == :amn &&
       any(indices -> !isempty(indices), frozen_indices)
        plan === nothing && throw(ArgumentError("frozen AMN initialization requires a target plan"))
        amn === nothing && throw(ArgumentError("frozen AMN initialization data are missing"))
        size(something(plan).representation_matrices, 1) == num_wannier ||
            throw(ArgumentError("target plan dimension disagrees with num_wannier"))
        frames, diagnostics, invariants = _constrained_frozen_initial_frames(
            representation,
            something(plan),
            outer_indices,
            frozen_indices,
            something(amn);
            construction_policy = config.input.construction_policy,
        )
        return frames, diagnostics, invariants, nothing
    end
    frames = _legacy_initial_frames(
        config,
        representation,
        outer_indices,
        frozen_indices,
        num_wannier,
        amn,
        restart,
        spectrum_audit = spectrum_audit,
    )
    return frames, NamedTuple[], nothing, nothing
end

"""Return only frames from the diagnostic-rich initialization implementation."""
function _initial_frames(arguments...; keywords...)
    frames, _, _, _ = _initial_frames_with_diagnostics(arguments...; keywords...)
    return frames
end

# Return projection centers in Wannier order as Cartesian row vectors.
function _initial_wannier_centers(
    config::SymmetryAdaptedWannierizationConfig,
    representation::BandRepresentation,
)
    basis = something(config.input.projection_basis)
    centers = zeros(Float64, basis.num_wannier, 3)
    for block in basis.blocks, center in axes(block.positions_fractional, 2)
        cartesian =
            transpose(@view(block.positions_fractional[:, center])) * representation.real_lattice
        for wannier in @view block.indices[:, center]
            centers[wannier, :] .= vec(cartesian)
        end
    end
    return centers
end

# Symmetrize a per-Wannier scalar or Cartesian-center property.
function _symmetrize_wannier_property(
    values::AbstractArray{<:Real},
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
)
    num_wannier = size(plan.representation_matrices, 1)
    if ndims(values) == 1
        output = zeros(Float64, num_wannier)
        for operation_index in eachindex(representation.operations)
            matrix = @view plan.representation_matrices[:, :, operation_index]
            output .+= abs2.(matrix) * values
        end
        return output ./ length(representation.operations)
    end
    size(values) == (num_wannier, 3) ||
        throw(ArgumentError("Wannier center array has incompatible dimensions"))
    fractional = Matrix{Float64}(values * inv(representation.real_lattice))
    output = zeros(Float64, num_wannier, 3)
    for (operation_index, operation) in enumerate(representation.operations)
        matrix = @view plan.representation_matrices[:, :, operation_index]
        for source in 1:num_wannier
            transformed =
                operation.rotation_fractional * @view(fractional[source, :]) .+
                operation.translation_fractional .-
                @view(plan.wannier_shifts[:, source, operation_index])
            for target in 1:num_wannier
                weight = abs2(matrix[target, source])
                @views output[target, :] .+= weight .* transformed
            end
        end
    end
    return output * representation.real_lattice ./ length(representation.operations)
end

# Update centers, total spreads, and a Cartesian trace decomposition.
function _centers_spreads_and_directions(
    frames::Vector{Matrix{ComplexF64}},
    previous_centers::Matrix{Float64},
    representation::BandRepresentation,
    mmn::WannierMMN,
    weights::Vector{Float64},
    plan::WannierSymmetryPlan,
)
    nk = length(frames)
    num_wannier = size(frames[1], 2)
    center_change = zeros(Float64, num_wannier, 3)
    r_squared = zeros(Float64, num_wannier)
    r_squared_directional = zeros(Float64, num_wannier, 3)
    for kpoint in representation.irreducible_indices
        star_weight = length(unique(@view representation.kpoint_map[:, kpoint])) / nk
        for neighbor in 1:mmn.num_neighbors
            target = mmn.neighbors[neighbor, kpoint]
            overlap = frames[kpoint]' * @view(mmn.data[:, :, neighbor, kpoint]) * frames[target]
            displacement = _mesh_neighbor_displacement(representation, mmn, neighbor, kpoint)
            b_cartesian = transpose(representation.reciprocal_lattice) * displacement
            for wannier in 1:num_wannier
                phased_diagonal =
                    overlap[wannier, wannier] *
                    cis(dot(@view(previous_centers[wannier, :]), b_cartesian))
                phase = angle(phased_diagonal)
                center_change[wannier, :] .-= star_weight * weights[neighbor] * phase .* b_cartesian
                r_squared[wannier] +=
                    star_weight * weights[neighbor] * (1.0 - abs2(phased_diagonal) + phase^2)
                direction_norm = sum(abs2, b_cartesian)
                if direction_norm > eps(Float64)
                    scalar_contribution =
                        star_weight * weights[neighbor] * (1.0 - abs2(phased_diagonal) + phase^2)
                    for direction in 1:3
                        r_squared_directional[wannier, direction] +=
                            scalar_contribution * abs2(b_cartesian[direction]) / direction_norm
                    end
                end
            end
        end
    end
    centers = _symmetrize_wannier_property(previous_centers + center_change, representation, plan)
    displacement = centers - previous_centers
    spreads = _symmetrize_wannier_property(
        r_squared - vec(sum(abs2, displacement; dims = 2)),
        representation,
        plan,
    )
    directional = vec(sum(r_squared_directional .- abs2.(displacement); dims = 1))
    return centers, spreads, (directional[1], directional[2], directional[3])
end

# Preserve the established two-result internal boundary.
function _centers_and_spreads(arguments...)
    centers, spreads, _ = _centers_spreads_and_directions(arguments...)
    return centers, spreads
end

# Evaluate a retained gauge on the complete mesh without applying the target
# representation.  This is deliberately separate from
# `_centers_spreads_and_directions`: the latter advances one symmetry-adapted
# solver iterate and therefore depends on the previous centers, the IBZ star
# weights, and the target-Wannier ordering.  A checkpoint evaluator must instead
# reproduce the translationally invariant Wannier90 formula directly from its
# own gauge.
function _evaluate_full_mesh_centers_spreads_and_directions(
    frames::Vector{Matrix{ComplexF64}},
    center_images::Matrix{Float64},
    representation::BandRepresentation,
    mmn::WannierMMN,
    weights::Vector{Float64},
    localized_overlaps::Union{Nothing, Array{ComplexF64, 4}} = nothing,
)
    nk = length(frames)
    num_wannier = size(frames[1], 2)
    centers = zeros(Float64, num_wannier, 3)
    r_squared = zeros(Float64, num_wannier)
    r_squared_directional = zeros(Float64, num_wannier, 3)
    for kpoint in eachindex(frames)
        for neighbor in 1:mmn.num_neighbors
            target = mmn.neighbors[neighbor, kpoint]
            overlap =
                localized_overlaps === nothing ?
                frames[kpoint]' * @view(mmn.data[:, :, neighbor, kpoint]) * frames[target] :
                @view(localized_overlaps[:, :, neighbor, kpoint])
            displacement = _mesh_neighbor_displacement(representation, mmn, neighbor, kpoint)
            b_cartesian = transpose(representation.reciprocal_lattice) * displacement
            direction_norm = sum(abs2, b_cartesian)
            for wannier in 1:num_wannier
                diagonal = overlap[wannier, wannier]
                phase = angle(diagonal)
                prefactor = weights[neighbor] / nk
                centers[wannier, :] .-= prefactor * phase .* b_cartesian
                scalar_contribution = prefactor * (1.0 - abs2(diagonal) + phase^2)
                r_squared[wannier] += scalar_contribution
                if direction_norm > eps(Float64)
                    for direction in 1:3
                        r_squared_directional[wannier, direction] +=
                            scalar_contribution * abs2(b_cartesian[direction]) / direction_norm
                    end
                end
            end
        end
    end
    spreads = r_squared - vec(sum(abs2, centers; dims = 2))
    directional = vec(sum(r_squared_directional .- abs2.(centers); dims = 1))

    # Return the equivalent lattice image nearest the checkpoint-provided
    # center, while retaining the spread evaluated from the gauge itself.
    fractional_offset = (center_images - centers) * inv(representation.real_lattice)
    centers .+= round.(fractional_offset) * representation.real_lattice
    return centers, spreads, (directional[1], directional[2], directional[3])
end
