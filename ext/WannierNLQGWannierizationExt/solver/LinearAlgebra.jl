# Version the formula used by every localization-gradient and restart path.
const LOCALIZATION_GRADIENT_CONTRACT = "mv_centered_residual_unwrapped_delta_v2"
const JOINT_UPDATE_CONTRACT = "type_iv_block_gauss_seidel_v1"
const SYMMETRY_PROJECTED_SMV_FR_CONTRACT = "full_bz_smv_ibz_corepresentation_fletcher_reeves_v1"
const _LOCALIZATION_SWEEP_ENTRY_COUNT = Threads.Atomic{Int}(0)

"""Return whether one backend is the symmetry-projected SMV--FR localization route."""
@inline _is_symmetry_projected_smv_fr(algorithm::Symbol) =
    algorithm == :symmetry_projected_smv_fletcher_reeves_two_stage

"""Return whether one backend carries Fletcher--Reeves tangent history."""
@inline _is_fletcher_reeves_localization(algorithm::Symbol) =
    algorithm in (:smv_fletcher_reeves_two_stage, :symmetry_projected_smv_fletcher_reeves_two_stage)

"""Return whether one Z backend uses the relative SMV objective seal."""
@inline _is_smv_fletcher_reeves_disentanglement(algorithm::Symbol) =
    algorithm in (:smv_fletcher_reeves_two_stage, :symmetry_projected_smv_fletcher_reeves_two_stage)
const _WANNIER90_REFERENCE_LP64_LAPACK = let
    configured = strip(get(ENV, "WANNIERNLQG_W90_REFERENCE_LP64_LAPACK", ""))
    candidates =
        isempty(configured) ? ["/opt/homebrew/opt/openblas/lib/libopenblas.0.dylib"] : [configured]
    found = findfirst(isfile, candidates)
    found === nothing ? nothing : candidates[something(found)]
end

"""Return the LAPACK ABI used by the strict Wannier90-reference eigensolvers."""
_wannier90_reference_lapack_backend() =
    _WANNIER90_REFERENCE_LP64_LAPACK === nothing ? "LIBBLASTRAMPOLINE_ILP64_FALLBACK" :
    "EXTERNAL_LP64:" * something(_WANNIER90_REFERENCE_LP64_LAPACK)

"""Return the digest of the selected external LP64 LAPACK library."""
_wannier90_reference_lapack_sha256() =
    _WANNIER90_REFERENCE_LP64_LAPACK === nothing ? "NOT_APPLICABLE_FALLBACK" :
    open(something(_WANNIER90_REFERENCE_LP64_LAPACK), "r") do io
        bytes2hex(SHA.sha256(io))
    end

# gfortran's `aimag(log(z))` is evaluated by the platform libm `atan2`.
# Julia's `atan` and complex `log` use libopenlibm and differ by a few ulps for
# the frozen Cr links; the parabolic FR step amplifies that harmless local
# difference into a failed five-step parity audit.
const _WANNIER90_REFERENCE_SYSTEM_LIBM =
    Sys.isapple() ? "/usr/lib/libSystem.B.dylib" :
    Sys.islinux() ? "libm.so.6" : Sys.iswindows() ? "msvcrt.dll" : Base.Math.libm

"""Evaluate gfortran's complex phase through the platform `atan2`."""
_wannier90_reference_phase(value::Complex) = ccall(
    (:atan2, _WANNIER90_REFERENCE_SYSTEM_LIBM),
    Cdouble,
    (Cdouble, Cdouble),
    imag(value),
    real(value),
)

"""Evaluate gfortran's complex `exp` through the same platform libm."""
_wannier90_reference_complex_exponential(value::ComplexF64) =
    ccall((:cexp, _WANNIER90_REFERENCE_SYSTEM_LIBM), ComplexF64, (ComplexF64,), value)

"""Return Wannier90's ordered `wbtot` accumulation for the reference path."""
function _wannier90_reference_weight_total(weights::Vector{Float64})
    isempty(weights) && throw(ArgumentError("Wannier90 neighbor weights are empty"))
    # Preserve the scalar left-to-right contract. `sum` may use a different
    # reduction tree and change the later parabolic-step trajectory.
    weight_total = 0.0
    for weight in weights
        weight_total += weight
    end
    isfinite(weight_total) && weight_total > 0.0 ||
        throw(ArgumentError("Wannier90 neighbor weight total is invalid"))
    return weight_total
end

"""Internal test hook proving that a Z-only step never enters localization."""
_localization_sweep_entry_count() = _LOCALIZATION_SWEEP_ENTRY_COUNT[]

# Return frozen band indices after window and explicit-state completion.
function _frozen_indices_from_values(
    frozen_min_ev::Float64,
    frozen_max_ev::Float64,
    frozen_states::Vector{Tuple{Int, Int}},
    representation::BandRepresentation,
    kpoint::Int,
)
    labels = @view representation.band_block_labels[:, kpoint]
    energies = @view representation.energies_ev[:, kpoint]
    selected_labels = Set{Int}()
    if frozen_min_ev <= frozen_max_ev
        for band in eachindex(energies)
            frozen_min_ev <= energies[band] <= frozen_max_ev && push!(selected_labels, labels[band])
        end
    end
    for (explicit_kpoint, band) in frozen_states
        explicit_kpoint == kpoint || continue
        1 <= band <= length(labels) || throw(
            ArgumentError("explicit frozen band $(band) is out of range at k-point $(kpoint)"),
        )
        push!(selected_labels, labels[band])
    end
    return findall(label -> label in selected_labels, labels)
end

"""Resolve frozen indices from the grouped solver input contract."""
@inline function _frozen_indices(
    config::SymmetryAdaptedWannierizationConfig,
    representation::BandRepresentation,
    kpoint::Int,
)
    input = config.input
    return _frozen_indices_from_values(
        input.frozen_min_ev,
        input.frozen_max_ev,
        input.frozen_states,
        representation,
        kpoint,
    )
end

"""Resolve frozen indices from the representation-preparation contract."""
@inline function _frozen_indices(
    config::BandRepresentationPreparationConfig,
    representation::BandRepresentation,
    kpoint::Int,
)
    return _frozen_indices_from_values(
        config.frozen_min_ev,
        config.frozen_max_ev,
        config.frozen_states,
        representation,
        kpoint,
    )
end

"""Mutable audit for the single validated Hermitian spectral-decomposition path."""
mutable struct HermitianSpectrumAudit
    decomposition_count::Int
    fallback_count::Int
    failure_count::Int
    worst_residual::Float64
    worst_orthogonality::Float64
    worst_context::String
    minimum_gap::Float64
    minimum_gap_context::String
end

# Construct an empty audit before the first validated spectral decomposition.
HermitianSpectrumAudit() = HermitianSpectrumAudit(0, 0, 0, 0.0, 0.0, "", Inf, "")

# Persist aggregate Hermitian-spectrum evidence in the solver summary.
function _record_hermitian_spectrum_audit!(
    summary::Dict{String, String},
    audit::HermitianSpectrumAudit,
)
    summary["hermitian_spectrum_decomposition_count"] = string(audit.decomposition_count)
    summary["hermitian_spectrum_fallback_count"] = string(audit.fallback_count)
    summary["hermitian_spectrum_failure_count"] = string(audit.failure_count)
    summary["hermitian_spectrum_worst_residual"] = string(audit.worst_residual)
    summary["hermitian_spectrum_worst_orthogonality"] = string(audit.worst_orthogonality)
    summary["hermitian_spectrum_worst_context"] =
        isempty(audit.worst_context) ? "NOT_APPLICABLE" : audit.worst_context
    summary["hermitian_spectrum_minimum_selection_gap"] =
        isfinite(audit.minimum_gap) ? string(audit.minimum_gap) : "NOT_APPLICABLE"
    summary["hermitian_spectrum_minimum_gap_context"] =
        isempty(audit.minimum_gap_context) ? "NOT_APPLICABLE" : audit.minimum_gap_context
    return summary
end

# Hash a k-resolved complex field in deterministic matrix order.
function _complex_field_sha256(field::Vector{Matrix{ComplexF64}})
    buffer = IOBuffer()
    for matrix in field
        write(buffer, reinterpret(UInt8, Int64[size(matrix)...]))
        write(buffer, reinterpret(UInt8, vec(matrix)))
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

# Bind the complete sealed Z-stage authority independently of the later U gauge.
function _disentanglement_state_sha256(state::DisentanglementState)
    buffer = IOBuffer()
    for values in (
        state.projectors,
        state.frames,
        state.z_field,
        state.outer_mask,
        state.frozen_mask,
        state.objective_history,
    )
        write(buffer, reinterpret(UInt8, Int64[size(values)...]))
        if values isa BitArray
            write(buffer, UInt8.(vec(values)))
        else
            write(buffer, reinterpret(UInt8, vec(values)))
        end
    end
    write(
        buffer,
        reinterpret(UInt8, [state.omega_i, state.projector_residual, Float64(state.converged)]),
    )
    return bytes2hex(SHA.sha256(take!(buffer)))
end

# Accumulate one validated Hermitian decomposition in the shared audit.
function _record_hermitian_spectrum_result!(
    audit::Union{Nothing, HermitianSpectrumAudit},
    result,
    context::AbstractString,
)
    audit === nothing && return result
    audit.decomposition_count += 1
    result.backend == :complex_schur && (audit.fallback_count += 1)
    result.success || (audit.failure_count += 1)
    if isfinite(result.residual) && result.residual >= audit.worst_residual
        audit.worst_residual = result.residual
        audit.worst_context = String(context)
    end
    isfinite(result.orthogonality) &&
        (audit.worst_orthogonality = max(audit.worst_orthogonality, result.orthogonality))
    return result
end

# Validate dimensions, finiteness, orthogonality, and the eigensystem residual.
function _validate_hermitian_eigensystem(
    matrix::Matrix{ComplexF64},
    values,
    vectors;
    tolerance::Float64,
)
    dimension = size(matrix, 1)
    length(values) == dimension || return (
        success = false,
        values = Float64[],
        vectors = zeros(ComplexF64, dimension, 0),
        residual = Inf,
        orthogonality = Inf,
        reason = :DIMENSION_MISMATCH,
    )
    size(vectors) == (dimension, dimension) || return (
        success = false,
        values = Float64[],
        vectors = zeros(ComplexF64, dimension, 0),
        residual = Inf,
        orthogonality = Inf,
        reason = :DIMENSION_MISMATCH,
    )
    all(isfinite, values) && all(isfinite, vectors) || return (
        success = false,
        values = Float64[],
        vectors = zeros(ComplexF64, dimension, 0),
        residual = Inf,
        orthogonality = Inf,
        reason = :NONFINITE_SPECTRUM,
    )
    complex_values = ComplexF64.(values)
    spectral_scale = maximum(abs, complex_values; init = 0.0)
    imaginary_residual = maximum(abs, imag.(complex_values); init = 0.0)
    validation_tolerance = max(10.0 * tolerance, 512.0 * eps(Float64) * max(1, dimension))
    imaginary_residual <= validation_tolerance * max(1.0, spectral_scale) || return (
        success = false,
        values = Float64[],
        vectors = zeros(ComplexF64, dimension, 0),
        residual = Inf,
        orthogonality = Inf,
        reason = :NONREAL_HERMITIAN_SPECTRUM,
    )
    real_values = real.(complex_values)
    eigenvectors = Matrix{ComplexF64}(vectors)
    identity_matrix = Matrix{ComplexF64}(I, dimension, dimension)
    orthogonality = norm(eigenvectors' * eigenvectors - identity_matrix)
    residual =
        norm(matrix * eigenvectors - eigenvectors * Diagonal(real_values)) / max(1.0, norm(matrix))
    success = residual <= validation_tolerance && orthogonality <= validation_tolerance
    return (
        success,
        values = real_values,
        vectors = eigenvectors,
        residual,
        orthogonality,
        reason = success ? :OK : :RESIDUAL_GATE_FAILED,
    )
end

"""
Return a validated full eigensystem for one finite Hermitian matrix.

The LAPACK Hermitian driver is primary. An independently driven dense complex
Schur decomposition is used when the primary path throws, returns an empty or
dimensionally invalid spectrum, or fails the residual/isometry gates.
"""
function _validated_hermitian_spectrum(
    input::AbstractMatrix{<:Complex};
    tolerance::Float64,
    context::AbstractString = "unspecified",
    audit::Union{Nothing, HermitianSpectrumAudit} = nothing,
    force_fallback::Bool = false,
)
    rows, columns = size(input)
    if rows == 0 || rows != columns
        return _record_hermitian_spectrum_result!(
            audit,
            (
                success = false,
                code = :HERMITIAN_SPECTRAL_DECOMPOSITION_FAILED,
                values = Float64[],
                vectors = zeros(ComplexF64, rows, 0),
                backend = :none,
                residual = Inf,
                orthogonality = Inf,
                primary_failure = :INVALID_DIMENSION,
                fallback_failure = :NOT_ATTEMPTED,
            ),
            context,
        )
    end
    raw = Matrix{ComplexF64}(input)
    if !all(isfinite, raw)
        return _record_hermitian_spectrum_result!(
            audit,
            (
                success = false,
                code = :HERMITIAN_SPECTRAL_DECOMPOSITION_FAILED,
                values = Float64[],
                vectors = zeros(ComplexF64, rows, 0),
                backend = :none,
                residual = Inf,
                orthogonality = Inf,
                primary_failure = :NONFINITE_INPUT,
                fallback_failure = :NOT_ATTEMPTED,
            ),
            context,
        )
    end
    scale = max(1.0, norm(raw))
    hermiticity = norm(raw - raw') / scale
    hermiticity_tolerance = max(10.0 * tolerance, 512.0 * eps(Float64) * rows)
    if !isfinite(hermiticity) || hermiticity > hermiticity_tolerance
        return _record_hermitian_spectrum_result!(
            audit,
            (
                success = false,
                code = :HERMITIAN_SPECTRAL_DECOMPOSITION_FAILED,
                values = Float64[],
                vectors = zeros(ComplexF64, rows, 0),
                backend = :none,
                residual = hermiticity,
                orthogonality = Inf,
                primary_failure = :NONHERMITIAN_INPUT,
                fallback_failure = :NOT_ATTEMPTED,
            ),
            context,
        )
    end
    matrix = Matrix{ComplexF64}(Hermitian(raw))
    primary_failure = force_fallback ? :FORCED_FALLBACK : :NOT_ATTEMPTED
    if !force_fallback
        try
            factorization = eigen(Hermitian(matrix))
            validation = _validate_hermitian_eigensystem(
                matrix,
                factorization.values,
                factorization.vectors;
                tolerance,
            )
            if validation.success
                return _record_hermitian_spectrum_result!(
                    audit,
                    merge(
                        validation,
                        (
                            code = :OK,
                            backend = :hermitian_eigen,
                            primary_failure = :NONE,
                            fallback_failure = :NOT_ATTEMPTED,
                        ),
                    ),
                    context,
                )
            end
            primary_failure = validation.reason
        catch
            primary_failure = :PRIMARY_EXCEPTION
        end
    end
    fallback_failure = :NOT_ATTEMPTED
    try
        factorization = schur(matrix)
        validation = _validate_hermitian_eigensystem(
            matrix,
            factorization.values,
            factorization.Z;
            tolerance,
        )
        if validation.success
            return _record_hermitian_spectrum_result!(
                audit,
                merge(
                    validation,
                    (
                        code = :OK,
                        backend = :complex_schur,
                        primary_failure,
                        fallback_failure = :NONE,
                    ),
                ),
                context,
            )
        end
        fallback_failure = validation.reason
    catch
        fallback_failure = :FALLBACK_EXCEPTION
    end
    return _record_hermitian_spectrum_result!(
        audit,
        (
            success = false,
            code = :HERMITIAN_SPECTRAL_DECOMPOSITION_FAILED,
            values = Float64[],
            vectors = zeros(ComplexF64, rows, 0),
            backend = :none,
            residual = Inf,
            orthogonality = Inf,
            primary_failure,
            fallback_failure,
        ),
        context,
    )
end

# Symmetrically orthonormalize columns through the validated spectrum entry.
function _orthonormalize_columns_result(
    matrix::AbstractMatrix{<:Complex},
    tolerance::Float64;
    audit::Union{Nothing, HermitianSpectrumAudit} = nothing,
    context::AbstractString = "gram_orthonormalization",
)
    gram = Matrix{ComplexF64}(matrix' * matrix)
    factorization = _validated_hermitian_spectrum(gram; tolerance, context, audit)
    factorization.success || return (
        success = false,
        code = factorization.code,
        matrix = nothing,
        minimum_gram_eigenvalue = NaN,
        backend = factorization.backend,
    )
    minimum(factorization.values) > tolerance || return (
        success = false,
        code = :SUBSPACE_RANK_DEFICIENT,
        matrix = nothing,
        minimum_gram_eigenvalue = minimum(factorization.values),
        backend = factorization.backend,
    )
    inverse_square_root =
        factorization.vectors * Diagonal(inv.(sqrt.(factorization.values))) * factorization.vectors'
    result = Matrix{ComplexF64}(matrix * inverse_square_root)
    all(isfinite, real.(result)) && all(isfinite, imag.(result)) || return (
        success = false,
        code = :NONFINITE_ORTHONORMALIZATION,
        matrix = nothing,
        minimum_gram_eigenvalue = minimum(factorization.values),
        backend = factorization.backend,
    )
    return (
        success = true,
        code = :OK,
        matrix = result,
        minimum_gram_eigenvalue = minimum(factorization.values),
        backend = factorization.backend,
    )
end

# Compatibility wrapper returning `nothing` when Gram orthonormalization fails.
function _orthonormalize_columns(arguments...; keywords...)
    result = _orthonormalize_columns_result(arguments...; keywords...)
    return result.success ? result.matrix : nothing
end

"""Wannier90 4.0.1 packed-Hermitian `ZHPEVX` eigensystem.

The SMV reference path diagonalizes the upper packed triangle with
`JOBZ='V'`, `RANGE='A'`, and `ABSTOL=-1`.  Replacing that call by a different
Hermitian driver produces measurably different projectors after many Cr Z
iterations even when Omega_I agrees to nearly machine precision.
"""
function _wannier90_reference_zhpevx(
    matrix::AbstractMatrix{<:Complex};
    leading_dimension::Int = size(matrix, 1),
)
    dimension = size(matrix, 1)
    size(matrix, 2) == dimension || return (
        success = false,
        code = :HERMITIAN_SPECTRAL_DECOMPOSITION_FAILED,
        values = Float64[],
        vectors = zeros(ComplexF64, size(matrix)),
        info = -1,
    )
    leading_dimension >= max(1, dimension) || return (
        success = false,
        code = :HERMITIAN_SPECTRAL_DECOMPOSITION_FAILED,
        values = Float64[],
        vectors = zeros(ComplexF64, size(matrix)),
        info = -2,
    )
    dimension == 0 && return (
        success = true,
        code = :OK,
        values = Float64[],
        vectors = zeros(ComplexF64, 0, 0),
        info = 0,
    )
    packed = Vector{ComplexF64}(undef, dimension * (dimension + 1) ÷ 2)
    offset = 1
    for column in 1:dimension, row in 1:column
        packed[offset] = matrix[row, column]
        offset += 1
    end
    use_external_lp64 = _WANNIER90_REFERENCE_LP64_LAPACK !== nothing
    integer_type = use_external_lp64 ? Cint : LinearAlgebra.BlasInt
    blas_dimension = integer_type(dimension)
    value_lower = 0.0
    value_upper = 0.0
    index_lower = integer_type(0)
    index_upper = integer_type(0)
    absolute_tolerance = -1.0
    found = Ref{integer_type}(0)
    # Wannier90 allocates every ZHPEVX work/output array at num_bands even
    # when the active packed matrix is only ndimwin/ndimk.  Preserve that
    # leading dimension and workspace contract: changing only the storage
    # stride can select a different vector in a nearly degenerate boundary.
    values_storage = zeros(Float64, leading_dimension)
    vectors_storage = zeros(ComplexF64, leading_dimension, leading_dimension)
    work = zeros(ComplexF64, 2leading_dimension)
    real_work = zeros(Float64, 7leading_dimension)
    integer_work = zeros(integer_type, 5leading_dimension)
    failed = zeros(integer_type, leading_dimension)
    info = Ref{integer_type}(0)
    job = UInt8('V')
    range = UInt8('A')
    upper = UInt8('U')
    if use_external_lp64
        ccall(
            (:zhpevx_, _WANNIER90_REFERENCE_LP64_LAPACK),
            Cvoid,
            (
                Ref{UInt8},
                Ref{UInt8},
                Ref{UInt8},
                Ref{Cint},
                Ptr{ComplexF64},
                Ref{Float64},
                Ref{Float64},
                Ref{Cint},
                Ref{Cint},
                Ref{Float64},
                Ref{Cint},
                Ptr{Float64},
                Ptr{ComplexF64},
                Ref{Cint},
                Ptr{ComplexF64},
                Ptr{Float64},
                Ptr{Cint},
                Ptr{Cint},
                Ref{Cint},
            ),
            job,
            range,
            upper,
            blas_dimension,
            packed,
            value_lower,
            value_upper,
            index_lower,
            index_upper,
            absolute_tolerance,
            found,
            values_storage,
            vectors_storage,
            Cint(leading_dimension),
            work,
            real_work,
            integer_work,
            failed,
            info,
        )
    else
        ccall(
            (LinearAlgebra.BLAS.@blasfunc(zhpevx_), LinearAlgebra.BLAS.libblastrampoline),
            Cvoid,
            (
                Ref{UInt8},
                Ref{UInt8},
                Ref{UInt8},
                Ref{LinearAlgebra.BlasInt},
                Ptr{ComplexF64},
                Ref{Float64},
                Ref{Float64},
                Ref{LinearAlgebra.BlasInt},
                Ref{LinearAlgebra.BlasInt},
                Ref{Float64},
                Ref{LinearAlgebra.BlasInt},
                Ptr{Float64},
                Ptr{ComplexF64},
                Ref{LinearAlgebra.BlasInt},
                Ptr{ComplexF64},
                Ptr{Float64},
                Ptr{LinearAlgebra.BlasInt},
                Ptr{LinearAlgebra.BlasInt},
                Ref{LinearAlgebra.BlasInt},
            ),
            job,
            range,
            upper,
            blas_dimension,
            packed,
            value_lower,
            value_upper,
            index_lower,
            index_upper,
            absolute_tolerance,
            found,
            values_storage,
            vectors_storage,
            LinearAlgebra.BlasInt(leading_dimension),
            work,
            real_work,
            integer_work,
            failed,
            info,
        )
    end
    successful = info[] == 0 && found[] == blas_dimension
    values = values_storage[1:dimension]
    vectors = Matrix{ComplexF64}(@view vectors_storage[1:dimension, 1:dimension])
    return (
        success = successful,
        code = successful ? :OK : :HERMITIAN_SPECTRAL_DECOMPOSITION_FAILED,
        values,
        vectors,
        info = Int(info[]),
    )
end

"""Wannier90 4.0.1 `ZHEEV('V','U')` for localization rotations.

The reference optimizer exponentiates each anti-Hermitian search direction by
diagonalizing `im * cdq` with this exact driver and workspace length.  Julia's
generic `eigen(Hermitian(...))` may choose a different LAPACK ABI/driver; that
difference is small after one step but compounds through Fletcher--Reeves.
"""
function _wannier90_reference_zheev(matrix::AbstractMatrix{<:Complex})
    dimension = size(matrix, 1)
    size(matrix, 2) == dimension || return (
        success = false,
        values = Float64[],
        vectors = zeros(ComplexF64, size(matrix)),
        info = -1,
    )
    dimension == 0 &&
        return (success = true, values = Float64[], vectors = zeros(ComplexF64, 0, 0), info = 0)
    vectors = Matrix{ComplexF64}(matrix)
    values = zeros(Float64, dimension)
    work = zeros(ComplexF64, 4dimension)
    real_work = zeros(Float64, max(1, 3dimension - 2))
    use_external_lp64 = _WANNIER90_REFERENCE_LP64_LAPACK !== nothing
    integer_type = use_external_lp64 ? Cint : LinearAlgebra.BlasInt
    n = integer_type(dimension)
    lwork = integer_type(length(work))
    info = Ref{integer_type}(0)
    vectors_requested = UInt8('V')
    upper = UInt8('U')
    if use_external_lp64
        ccall(
            (:zheev_, _WANNIER90_REFERENCE_LP64_LAPACK),
            Cvoid,
            (
                Ref{UInt8},
                Ref{UInt8},
                Ref{Cint},
                Ptr{ComplexF64},
                Ref{Cint},
                Ptr{Float64},
                Ptr{ComplexF64},
                Ref{Cint},
                Ptr{Float64},
                Ref{Cint},
            ),
            vectors_requested,
            upper,
            n,
            vectors,
            n,
            values,
            work,
            lwork,
            real_work,
            info,
        )
    else
        ccall(
            (LinearAlgebra.BLAS.@blasfunc(zheev_), LinearAlgebra.BLAS.libblastrampoline),
            Cvoid,
            (
                Ref{UInt8},
                Ref{UInt8},
                Ref{LinearAlgebra.BlasInt},
                Ptr{ComplexF64},
                Ref{LinearAlgebra.BlasInt},
                Ptr{Float64},
                Ptr{ComplexF64},
                Ref{LinearAlgebra.BlasInt},
                Ptr{Float64},
                Ref{LinearAlgebra.BlasInt},
            ),
            vectors_requested,
            upper,
            n,
            vectors,
            n,
            values,
            work,
            lwork,
            real_work,
            info,
        )
    end
    return (success = info[] == 0, values, vectors, info = Int(info[]))
end

"""Wannier90-linked LP64 `ZGEMM` used by the recursive U/M reference state."""
function _wannier90_reference_zgemm(
    left::AbstractMatrix{<:Complex},
    trans_left::Char,
    right::AbstractMatrix{<:Complex},
    trans_right::Char,
)
    trans_left in ('N', 'C') || throw(ArgumentError("unsupported left ZGEMM transpose"))
    trans_right in ('N', 'C') || throw(ArgumentError("unsupported right ZGEMM transpose"))
    left_matrix = Matrix{ComplexF64}(left)
    right_matrix = Matrix{ComplexF64}(right)
    left_rows = trans_left == 'N' ? size(left_matrix, 1) : size(left_matrix, 2)
    inner_left = trans_left == 'N' ? size(left_matrix, 2) : size(left_matrix, 1)
    inner_right = trans_right == 'N' ? size(right_matrix, 1) : size(right_matrix, 2)
    right_columns = trans_right == 'N' ? size(right_matrix, 2) : size(right_matrix, 1)
    inner_left == inner_right || throw(DimensionMismatch("ZGEMM inner dimensions disagree"))
    result = zeros(ComplexF64, left_rows, right_columns)
    if _WANNIER90_REFERENCE_LP64_LAPACK === nothing
        op_left = trans_left == 'N' ? left_matrix : left_matrix'
        op_right = trans_right == 'N' ? right_matrix : right_matrix'
        mul!(result, op_left, op_right)
        return result
    end
    transa = UInt8(trans_left)
    transb = UInt8(trans_right)
    m = Cint(left_rows)
    n = Cint(right_columns)
    k = Cint(inner_left)
    lda = Cint(max(1, size(left_matrix, 1)))
    ldb = Cint(max(1, size(right_matrix, 1)))
    ldc = Cint(max(1, size(result, 1)))
    alpha = ComplexF64(1.0, 0.0)
    beta = ComplexF64(0.0, 0.0)
    ccall(
        (:zgemm_, _WANNIER90_REFERENCE_LP64_LAPACK),
        Cvoid,
        (
            Ref{UInt8},
            Ref{UInt8},
            Ref{Cint},
            Ref{Cint},
            Ref{Cint},
            Ref{ComplexF64},
            Ptr{ComplexF64},
            Ref{Cint},
            Ptr{ComplexF64},
            Ref{Cint},
            Ref{ComplexF64},
            Ptr{ComplexF64},
            Ref{Cint},
        ),
        transa,
        transb,
        m,
        n,
        k,
        alpha,
        left_matrix,
        lda,
        right_matrix,
        ldb,
        beta,
        result,
        ldc,
    )
    return result
end

"""Execute an LP64 ZGEMM with explicit logical dimensions and physical LDs."""
function _wannier90_reference_zgemm_storage!(
    result::Matrix{ComplexF64},
    left::Matrix{ComplexF64},
    trans_left::Char,
    right::Matrix{ComplexF64},
    trans_right::Char,
    logical_m::Int,
    logical_n::Int,
    logical_k::Int,
)
    trans_left in ('N', 'C') || throw(ArgumentError("unsupported left ZGEMM transpose"))
    trans_right in ('N', 'C') || throw(ArgumentError("unsupported right ZGEMM transpose"))
    logical_m >= 0 && logical_n >= 0 && logical_k >= 0 ||
        throw(ArgumentError("negative logical ZGEMM dimension"))
    size(result, 1) >= max(1, logical_m) && size(result, 2) >= logical_n ||
        throw(DimensionMismatch("ZGEMM result storage is too small"))
    left_rows = trans_left == 'N' ? logical_m : logical_k
    left_columns = trans_left == 'N' ? logical_k : logical_m
    right_rows = trans_right == 'N' ? logical_k : logical_n
    right_columns = trans_right == 'N' ? logical_n : logical_k
    size(left, 1) >= left_rows && size(left, 2) >= left_columns ||
        throw(DimensionMismatch("left ZGEMM storage is too small"))
    size(right, 1) >= right_rows && size(right, 2) >= right_columns ||
        throw(DimensionMismatch("right ZGEMM storage is too small"))

    fill!(result, 0.0 + 0.0im)
    (logical_m == 0 || logical_n == 0) && return result
    if _WANNIER90_REFERENCE_LP64_LAPACK === nothing
        left_view = @view left[1:left_rows, 1:left_columns]
        right_view = @view right[1:right_rows, 1:right_columns]
        op_left = trans_left == 'N' ? left_view : adjoint(left_view)
        op_right = trans_right == 'N' ? right_view : adjoint(right_view)
        mul!(@view(result[1:logical_m, 1:logical_n]), op_left, op_right)
        return result
    end

    transa = UInt8(trans_left)
    transb = UInt8(trans_right)
    m = Cint(logical_m)
    n = Cint(logical_n)
    k = Cint(logical_k)
    lda = Cint(max(1, size(left, 1)))
    ldb = Cint(max(1, size(right, 1)))
    ldc = Cint(max(1, size(result, 1)))
    alpha = ComplexF64(1.0, 0.0)
    beta = ComplexF64(0.0, 0.0)
    ccall(
        (:zgemm_, _WANNIER90_REFERENCE_LP64_LAPACK),
        Cvoid,
        (
            Ref{UInt8},
            Ref{UInt8},
            Ref{Cint},
            Ref{Cint},
            Ref{Cint},
            Ref{ComplexF64},
            Ptr{ComplexF64},
            Ref{Cint},
            Ptr{ComplexF64},
            Ref{Cint},
            Ref{ComplexF64},
            Ptr{ComplexF64},
            Ref{Cint},
        ),
        transa,
        transb,
        m,
        n,
        k,
        alpha,
        left,
        lda,
        right,
        ldb,
        beta,
        result,
        ldc,
    )
    return result
end

"""Form Wannier90's logical-window `C_AA = U_opt^H A` product.

`internal_find_u` compacts the active outer-window rows at the top of arrays
whose physical leading dimension remains `num_bands`, then calls LP64 ZGEMM
with the *logical* contraction dimension `ndimwin`.  Multiplying the full
zero-padded parent matrices is algebraically equivalent, but changes the BLAS
blocking and the last bits of the Z-to-U initializer.  This helper preserves
the registered 4.0.1 storage and arithmetic contract without importing any
observer state.
"""
function _wannier90_reference_logical_window_caa(
    subspace_frame::AbstractMatrix{<:Complex},
    reference_frame::AbstractMatrix{<:Complex},
    outer_indices::AbstractVector{<:Integer},
)
    size(subspace_frame) == size(reference_frame) ||
        throw(DimensionMismatch("logical-window C_AA frames disagree"))
    num_bands, num_wannier = size(subspace_frame)
    num_outer = length(outer_indices)
    num_outer >= num_wannier ||
        throw(DimensionMismatch("logical outer window is smaller than num_wannier"))
    all(index -> 1 <= index <= num_bands, outer_indices) ||
        throw(BoundsError(subspace_frame, outer_indices))
    length(unique(outer_indices)) == num_outer ||
        throw(ArgumentError("logical outer-window indices are not unique"))

    left_storage = zeros(ComplexF64, num_bands, num_wannier)
    right_storage = zeros(ComplexF64, num_bands, num_wannier)
    left_storage[1:num_outer, :] .= @view subspace_frame[outer_indices, :]
    right_storage[1:num_outer, :] .= @view reference_frame[outer_indices, :]
    result = zeros(ComplexF64, num_wannier, num_wannier)
    if _WANNIER90_REFERENCE_LP64_LAPACK === nothing
        mul!(
            result,
            adjoint(@view(left_storage[1:num_outer, :])),
            @view(right_storage[1:num_outer, :]),
        )
        return result
    end

    transa = UInt8('C')
    transb = UInt8('N')
    m = Cint(num_wannier)
    n = Cint(num_wannier)
    k = Cint(num_outer)
    lda = Cint(num_bands)
    ldb = Cint(num_bands)
    ldc = Cint(num_wannier)
    alpha = ComplexF64(1.0, 0.0)
    beta = ComplexF64(0.0, 0.0)
    ccall(
        (:zgemm_, _WANNIER90_REFERENCE_LP64_LAPACK),
        Cvoid,
        (
            Ref{UInt8},
            Ref{UInt8},
            Ref{Cint},
            Ref{Cint},
            Ref{Cint},
            Ref{ComplexF64},
            Ptr{ComplexF64},
            Ref{Cint},
            Ptr{ComplexF64},
            Ref{Cint},
            Ref{ComplexF64},
            Ptr{ComplexF64},
            Ref{Cint},
        ),
        transa,
        transb,
        m,
        n,
        k,
        alpha,
        left_storage,
        lda,
        right_storage,
        ldb,
        beta,
        result,
        ldc,
    )
    return result
end

"""Wannier90-linked LP64 norm/dot reduction in flattened Fortran mesh order."""
function _wannier90_reference_zdot(
    left::Vector{Matrix{ComplexF64}},
    right::Vector{Matrix{ComplexF64}},
)
    length(left) == length(right) || throw(DimensionMismatch("tangent meshes disagree"))
    left_flat = reduce(vcat, vec.(left); init = ComplexF64[])
    right_flat = reduce(vcat, vec.(right); init = ComplexF64[])
    length(left_flat) == length(right_flat) || throw(DimensionMismatch("tangent sizes disagree"))
    isempty(left_flat) && return 0.0
    if _WANNIER90_REFERENCE_LP64_LAPACK === nothing
        return real(dot(left_flat, right_flat))
    end
    m = Cint(length(left_flat))
    one = Cint(1)
    result = Ref{ComplexF64}(0.0 + 0.0im)
    alpha = ComplexF64(1.0, 0.0)
    beta = ComplexF64(0.0, 0.0)
    ccall(
        (:zgemv_, _WANNIER90_REFERENCE_LP64_LAPACK),
        Cvoid,
        (
            Ref{UInt8},
            Ref{Cint},
            Ref{Cint},
            Ref{ComplexF64},
            Ptr{ComplexF64},
            Ref{Cint},
            Ptr{ComplexF64},
            Ref{Cint},
            Ref{ComplexF64},
            Ref{ComplexF64},
            Ref{Cint},
        ),
        UInt8('C'),
        m,
        one,
        alpha,
        left_flat,
        m,
        right_flat,
        one,
        beta,
        result,
        one,
    )
    return real(result[])
end

"""Select the exact Wannier90 SMV frozen-plus-leading Z eigenspace."""
function _wannier90_reference_maximum_subspace_result(
    z_matrix::Matrix{ComplexF64},
    outer_indices::Vector{Int},
    frozen_indices::Vector{Int},
    num_wannier::Int;
    context::AbstractString = "wannier90_reference_maximum_subspace",
    audit::Union{Nothing, HermitianSpectrumAudit} = nothing,
)
    nb = size(z_matrix, 1)
    outer_position = Dict(index => position for (position, index) in enumerate(outer_indices))
    length(outer_indices) >= num_wannier &&
    length(frozen_indices) <= num_wannier &&
    all(index -> haskey(outer_position, index), frozen_indices) || return (
        success = false,
        code = :SUBSPACE_RANK_DEFICIENT,
        frame = nothing,
        gap = NaN,
        backend = :wannier90_zhpevx,
    )
    frozen_local = [outer_position[index] for index in frozen_indices]
    frozen_set = Set(frozen_local)
    free_local = [index for index in eachindex(outer_indices) if index ∉ frozen_set]
    needed = num_wannier - length(frozen_indices)
    needed <= length(free_local) || return (
        success = false,
        code = :SUBSPACE_RANK_DEFICIENT,
        frame = nothing,
        gap = NaN,
        backend = :wannier90_zhpevx,
    )
    local_z = @view z_matrix[outer_indices[free_local], outer_indices[free_local]]
    eigensystem = _wannier90_reference_zhpevx(local_z; leading_dimension = nb)
    eigensystem.success || return (
        success = false,
        code = eigensystem.code,
        frame = nothing,
        gap = NaN,
        backend = :wannier90_zhpevx,
    )
    selected = zeros(ComplexF64, length(outer_indices), num_wannier)
    column = 1
    for index in frozen_local
        selected[index, column] = 1.0
        column += 1
    end
    first_selected = length(free_local) - needed + 1
    for eigen_index in first_selected:length(free_local)
        selected[free_local, column] .= @view eigensystem.vectors[:, eigen_index]
        column += 1
    end
    column == num_wannier + 1 || return (
        success = false,
        code = :SUBSPACE_RANK_DEFICIENT,
        frame = nothing,
        gap = NaN,
        backend = :wannier90_zhpevx,
    )
    all(isfinite, selected) || return (
        success = false,
        code = :NONFINITE_ORTHONORMALIZATION,
        frame = nothing,
        gap = NaN,
        backend = :wannier90_zhpevx,
    )
    output = zeros(ComplexF64, nb, num_wannier)
    output[outer_indices, :] .= selected
    gap = if needed == 0 || needed == length(free_local)
        Inf
    else
        eigensystem.values[first_selected] - eigensystem.values[first_selected - 1]
    end
    if audit !== nothing
        audit.decomposition_count += 1
        if gap < audit.minimum_gap
            audit.minimum_gap = gap
            audit.minimum_gap_context = String(context)
        end
    end
    return (
        success = true,
        code = :OK,
        frame = output,
        gap,
        backend = :wannier90_zhpevx,
        selection_method = :wannier90_leading_eigenspace,
        boundary_cluster_size = needed == 0 ? 0 : 1,
        reference_overlap_minimum_singular_value = NaN,
        reference_overlap_condition = NaN,
    )
end

"""Apply Wannier90 4.0.1's post-SMV Hamiltonian gauge.

After the last disentanglement iteration, `dis_extract` diagonalizes the
diagonal band Hamiltonian inside every selected subspace and replaces
`u_matrix_opt` by those energy-ordered eigenvectors before `internal_find_u`.
This operation leaves the Z projector unchanged, but omitting it changes the
floating-point SVD path at the Z-to-U boundary and eventually changes the FR
step sequence.  It is therefore part of the reference state machine, not an
optional localization gauge repair.
"""
function _wannier90_reference_post_smv_hamiltonian_gauge(
    frames::Vector{Matrix{ComplexF64}},
    energies_ev::AbstractMatrix{<:Real},
    outer_indices::Vector{Vector{Int}},
)
    length(frames) == size(energies_ev, 2) == length(outer_indices) || return (
        success = false,
        code = :WANNIER90_REFERENCE_POST_SMV_DIMENSION_MISMATCH,
        frames = deepcopy(frames),
        energies = Vector{Vector{Float64}}(),
        maximum_projector_drift = Inf,
        maximum_eigen_residual_ev = Inf,
        kpoint = 0,
    )
    output = deepcopy(frames)
    selected_energies = Vector{Vector{Float64}}(undef, length(frames))
    maximum_projector_drift = 0.0
    maximum_eigen_residual_ev = 0.0
    worst_kpoint = 0
    for kpoint in eachindex(frames)
        frame = frames[kpoint]
        outer = outer_indices[kpoint]
        num_bands, num_wannier = size(frame)
        size(energies_ev, 1) == num_bands && length(outer) >= num_wannier || return (
            success = false,
            code = :WANNIER90_REFERENCE_POST_SMV_DIMENSION_MISMATCH,
            frames = output,
            energies = selected_energies[1:(kpoint - 1)],
            maximum_projector_drift,
            maximum_eigen_residual_ev,
            kpoint,
        )
        hamiltonian = zeros(ComplexF64, num_wannier, num_wannier)
        # Match the i,j,l scalar loops used to build CHAM.  Only the active
        # outer-window rows participate in Wannier90's slim band frame.
        for column in 1:num_wannier, row in 1:num_wannier
            hamiltonian[row, column] = _wannier90_reference_gfortran_weighted_conjugate_dot(
                @view(frame[outer, row]),
                @view(frame[outer, column]),
                @view(energies_ev[outer, kpoint]),
            )
        end
        eigensystem = _wannier90_reference_zhpevx(hamiltonian; leading_dimension = num_bands)
        eigensystem.success || return (
            success = false,
            code = eigensystem.code,
            frames = output,
            energies = selected_energies[1:(kpoint - 1)],
            maximum_projector_drift,
            maximum_eigen_residual_ev,
            kpoint,
        )
        rotated = zeros(ComplexF64, num_bands, num_wannier)
        # Match `ceamp(i,j) += cz(l,j)*u_matrix_opt(i,l)` exactly.  This is
        # intentionally not expressed as a generic matrix multiplication.
        for column in 1:num_wannier, band in outer, inner in 1:num_wannier
            rotated[band, column] += _wannier90_reference_gfortran_complex_product(
                eigensystem.vectors[inner, column],
                frame[band, inner],
            )
        end
        projector_drift = opnorm(rotated * rotated' - frame * frame')
        residual = maximum(
            abs,
            hamiltonian * eigensystem.vectors - eigensystem.vectors * Diagonal(eigensystem.values);
            init = 0.0,
        )
        if max(projector_drift, residual) > max(maximum_projector_drift, maximum_eigen_residual_ev)
            worst_kpoint = kpoint
        end
        maximum_projector_drift = max(maximum_projector_drift, projector_drift)
        maximum_eigen_residual_ev = max(maximum_eigen_residual_ev, residual)
        output[kpoint] = rotated
        selected_energies[kpoint] = eigensystem.values
    end
    return (
        success = true,
        code = :OK,
        frames = output,
        energies = selected_energies,
        maximum_projector_drift,
        maximum_eigen_residual_ev,
        kpoint = worst_kpoint,
    )
end

# Choose the largest Hermitian eigenspace while retaining every frozen band state.
function _maximum_subspace_result(
    z_matrix::Matrix{ComplexF64},
    outer_indices::Vector{Int},
    frozen_indices::Vector{Int},
    num_wannier::Int,
    tolerance::Float64,
    ;
    audit::Union{Nothing, HermitianSpectrumAudit} = nothing,
    context::AbstractString = "maximum_subspace",
    reference_frame::Union{Nothing, AbstractMatrix{<:Complex}} = nothing,
    maximum_reference_condition::Float64 = 1.0e10,
    numerical_thresholds::WannierizationNumericalThresholds = WannierizationNumericalThresholds(),
)
    nb = size(z_matrix, 1)
    length(outer_indices) >= num_wannier || return (
        success = false,
        code = :SUBSPACE_RANK_DEFICIENT,
        frame = nothing,
        gap = NaN,
        backend = :none,
    )
    length(frozen_indices) <= num_wannier || return (
        success = false,
        code = :SUBSPACE_RANK_DEFICIENT,
        frame = nothing,
        gap = NaN,
        backend = :none,
    )
    outer_position = Dict(index => position for (position, index) in enumerate(outer_indices))
    all(index -> haskey(outer_position, index), frozen_indices) || return (
        success = false,
        code = :SUBSPACE_RANK_DEFICIENT,
        frame = nothing,
        gap = NaN,
        backend = :none,
    )
    frozen_local = [outer_position[index] for index in frozen_indices]
    dimension = length(outer_indices)
    frozen_projector = zeros(ComplexF64, dimension, dimension)
    for index in frozen_local
        frozen_projector[index, index] = 1.0
    end
    complement = Matrix{ComplexF64}(I, dimension, dimension) - frozen_projector
    local_z = Hermitian(@view(z_matrix[outer_indices, outer_indices]))
    projected = Matrix{ComplexF64}(complement * Matrix(local_z) * complement)
    eigensystem = _validated_hermitian_spectrum(
        projected;
        tolerance = numerical_thresholds.hermitian_residual_rtol,
        context,
        audit,
    )
    eigensystem.success || return (
        success = false,
        code = eigensystem.code,
        frame = nothing,
        gap = NaN,
        backend = eigensystem.backend,
    )
    order = sortperm(eigensystem.values; rev = true)
    needed = num_wannier - length(frozen_indices)
    selected = Matrix{ComplexF64}(undef, dimension, num_wannier)
    column = 1
    for index in frozen_local
        selected[:, column] .= 0.0
        selected[index, column] = 1.0
        column += 1
    end
    eligible_values = Float64[]
    eligible_vectors = Vector{Vector{ComplexF64}}()
    for eigen_index in order
        vector = complement * eigensystem.vectors[:, eigen_index]
        norm(vector) > numerical_thresholds.frame_transport_atol || continue
        push!(eligible_values, eigensystem.values[eigen_index])
        push!(eligible_vectors, vector)
    end
    length(eligible_vectors) >= needed || return (
        success = false,
        code = :SUBSPACE_RANK_DEFICIENT,
        frame = nothing,
        gap = NaN,
        backend = eigensystem.backend,
    )
    selected_positions = collect(1:needed)
    selection_method = :maximum_eigenspace
    boundary_cluster_size = needed == 0 ? 0 : 1
    reference_overlap_minimum_singular_value = NaN
    reference_overlap_condition = NaN
    free_selected =
        needed == 0 ? zeros(ComplexF64, dimension, 0) :
        hcat(eligible_vectors[selected_positions]...)
    if reference_frame !== nothing && needed > 0
        reference = something(reference_frame)
        size(reference) == (nb, num_wannier) || return (
            success = false,
            code = :SUBSPACE_REFERENCE_DIMENSION_MISMATCH,
            frame = nothing,
            gap = NaN,
            backend = eigensystem.backend,
        )
        reference_free = complement * Matrix{ComplexF64}(@view reference[outer_indices, :])
        boundary_value = eligible_values[needed]
        cluster_tolerance =
            numerical_thresholds.subspace_cluster_atol +
            numerical_thresholds.subspace_cluster_rtol * max(1.0, abs(boundary_value))
        cluster_start = needed
        while cluster_start > 1 &&
            abs(eligible_values[cluster_start - 1] - boundary_value) <= cluster_tolerance
            cluster_start -= 1
        end
        cluster_stop = needed
        while cluster_stop < length(eligible_values) &&
            abs(eligible_values[cluster_stop + 1] - boundary_value) <= cluster_tolerance
            cluster_stop += 1
        end
        boundary_cluster_size = cluster_stop - cluster_start + 1
        cluster_slots = needed - cluster_start + 1
        if boundary_cluster_size > cluster_slots
            prefix =
                cluster_start == 1 ? zeros(ComplexF64, dimension, 0) :
                hcat(eligible_vectors[1:(cluster_start - 1)]...)
            cluster = hcat(eligible_vectors[cluster_start:cluster_stop]...)
            reference_residual = reference_free
            !isempty(prefix) && (reference_residual .-= prefix * (prefix' * reference_residual))
            decomposition = svd(reference_residual)
            sigma_max = maximum(decomposition.S; init = 0.0)
            rank_threshold = max(
                numerical_thresholds.frame_transport_atol,
                numerical_thresholds.frame_transport_rtol * sigma_max,
            )
            reference_rank = count(>=(rank_threshold), decomposition.S)
            if reference_rank >= cluster_slots
                reference_basis = Matrix{ComplexF64}(decomposition.U[:, 1:cluster_slots])
                overlap = cluster' * reference_basis
                overlap_svd = svd(overlap)
                overlap_sigma_max = maximum(overlap_svd.S; init = 0.0)
                overlap_threshold = max(
                    numerical_thresholds.frame_transport_atol,
                    numerical_thresholds.frame_transport_rtol * overlap_sigma_max,
                )
                overlap_rank = count(>=(overlap_threshold), overlap_svd.S)
                condition =
                    overlap_rank < cluster_slots ? Inf :
                    overlap_sigma_max / minimum(overlap_svd.S[1:cluster_slots])
                if overlap_rank >= cluster_slots &&
                   isfinite(condition) &&
                   condition <= maximum_reference_condition
                    cluster_selected = cluster * overlap_svd.U[:, 1:cluster_slots]
                    free_selected = hcat(prefix, cluster_selected)
                    selection_method = :boundary_cluster_procrustes
                else
                    free_selected = hcat(prefix, cluster[:, 1:cluster_slots])
                    selection_method = :boundary_cluster_deterministic_pivot
                end
            else
                free_selected = hcat(prefix, cluster[:, 1:cluster_slots])
                selection_method = :boundary_cluster_deterministic_pivot
            end
        end
    end
    for free_column in axes(free_selected, 2)
        vector = copy(@view free_selected[:, free_column])
        pivot = argmax(abs.(vector))
        abs(vector[pivot]) > 0.0 && (vector .*= cis(-angle(vector[pivot])))
        selected[:, column] .= vector
        column += 1
    end
    column == num_wannier + 1 || return (
        success = false,
        code = :SUBSPACE_RANK_DEFICIENT,
        frame = nothing,
        gap = NaN,
        backend = eigensystem.backend,
    )
    orthonormalized = _orthonormalize_columns_result(
        selected,
        numerical_thresholds.frame_transport_atol;
        audit,
        context = "$(context):selected_gram",
    )
    orthonormalized.success || return (
        success = false,
        code = orthonormalized.code,
        frame = nothing,
        gap = NaN,
        backend = orthonormalized.backend,
    )
    selected = something(orthonormalized.matrix)
    output = zeros(ComplexF64, nb, num_wannier)
    output[outer_indices, :] .= selected
    gap = if needed == 0 || needed == length(eligible_values)
        Inf
    else
        eligible_values[needed] - eligible_values[needed + 1]
    end
    if reference_frame !== nothing
        overlap_singular_values = svdvals(output' * something(reference_frame))
        sigma_max = maximum(overlap_singular_values; init = 0.0)
        rank_threshold = max(
            numerical_thresholds.frame_transport_atol,
            numerical_thresholds.frame_transport_rtol * sigma_max,
        )
        overlap_rank = sigma_max == 0.0 ? 0 : count(>=(rank_threshold), overlap_singular_values)
        reference_overlap_minimum_singular_value =
            isempty(overlap_singular_values) ? 0.0 : minimum(overlap_singular_values)
        reference_overlap_condition =
            overlap_rank == num_wannier ? sigma_max / reference_overlap_minimum_singular_value : Inf
    end
    if audit !== nothing && gap < audit.minimum_gap
        audit.minimum_gap = gap
        audit.minimum_gap_context = String(context)
    end
    return (
        success = true,
        code = :OK,
        frame = output,
        gap,
        backend = eigensystem.backend,
        selection_method,
        boundary_cluster_size,
        reference_overlap_minimum_singular_value,
        reference_overlap_condition,
        eligible_values,
        eligible_vectors,
    )
end

# Compatibility wrapper returning `nothing` when subspace selection fails.
function _maximum_subspace(arguments...; keywords...)
    result = _maximum_subspace_result(arguments...; keywords...)
    return result.success ? result.frame : nothing
end
