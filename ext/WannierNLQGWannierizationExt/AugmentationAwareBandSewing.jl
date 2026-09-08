# Strict PAW/USPP band sewing. This file is included only after both native
# QE and VASP projector/Q backends, so it can reuse their qualified primitives.

const TARGET_LEAKAGE_WEIGHT_SEMANTICS = "physical_paw_s_leakage_weight_v1"
const TARGET_LEAKAGE_WEIGHT_FORMULAS =
    "W_state=max_i(R' S R)_ii;W_reconstruction=lambda_max(R' S R);" *
    "W_T_to_C=opnorm(B_CT,2)^2;W_C_to_T=opnorm(B_TC,2)^2;" *
    "rows=target;columns=source"
const TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256 =
    bytes2hex(sha256(codeunits(TARGET_LEAKAGE_WEIGHT_FORMULAS)))

"""Private marker for one native augmentation-aware q=0 sewing metric."""
abstract type _AbstractStrictSewingMetric end

# Cache the complete QE q=0 metric and projector basis at every native k point.
struct _QEStrictSewingMetric <: _AbstractStrictSewingMetric
    upf_data::Dict{String, QEUPFData}
    plan::QEProjectorPlan
    projectors::Vector{Array{ComplexF64, 3}}
    projector_bases::Vector{Matrix{ComplexF64}}
    spinorbit::Bool
    finite_b_cache::Dict{Tuple{String, NTuple{3, Float64}, Int, Bool}, Array{ComplexF64, 4}}
    metric_kind::String
end

# Cache the complete VASP q=0 PAW metric and projector basis at every k point.
struct _VASPStrictSewingMetric <: _AbstractStrictSewingMetric
    paw::VASPPawSystem
    projectors::Vector{Array{ComplexF64, 3}}
    projector_bases::Vector{Matrix{ComplexF64}}
end

# Read unnormalized, untruncated coefficients for one strict QE sewing build.
function _read_augmentation_aware_native_source(source::QuantumEspressoWavefunctionSource)
    source.representation_cutoff_ev === nothing || throw(
        ArgumentError(
            "PAW_SEWING_FULL_CUTOFF_REQUIRED: QE representation_cutoff_ev must be nothing",
        ),
    )
    metadata = read_qe_xml(source)
    native = read_qe_wavefunctions(
        source;
        purpose = :band_representation,
        retain_all_plane_waves = true,
        normalize_coefficients = false,
        metadata,
        native_paw_construction = true,
    )
    get(native.source_metadata, "coefficient_normalization", "") == "qe_raw" || throw(
        ArgumentError("QE_PAW_RAW_COEFFICIENTS_REQUIRED: strict sewing received normalized data"),
    )
    return native
end

# Read unnormalized, untruncated coefficients for one strict VASP sewing build.
function _read_augmentation_aware_native_source(source::VASPWavefunctionSource)
    source.representation_cutoff_ev === nothing || throw(
        ArgumentError(
            "PAW_SEWING_FULL_CUTOFF_REQUIRED: VASP representation_cutoff_ev must be nothing",
        ),
    )
    source.potcar_file === nothing &&
        throw(ArgumentError("VASP_PAW_DATA_REQUIRED: strict sewing requires POTCAR"))
    native = read_vasp_wavefunctions(source; normalize_coefficients = false)
    get(native.source_metadata, "coefficient_normalization", "") == "vasp_raw" || throw(
        ArgumentError("VASP_PAW_RAW_COEFFICIENTS_REQUIRED: strict sewing received normalized data"),
    )
    return native
end

# Fail explicitly for future native sources until they provide projector/Q data.
function _read_augmentation_aware_native_source(source::AbstractWavefunctionSource)
    throw(
        ArgumentError(
            "PAW_SEWING_BACKEND_UNAVAILABLE: no augmentation-aware reader for $(typeof(source))",
        ),
    )
end

# Build the complete QE projector/Q context and its mandatory native norm gate.
function _strict_sewing_metric(
    source::QuantumEspressoWavefunctionSource,
    native::NativeWavefunctionData,
)
    metadata = read_qe_xml(source)
    upf_data = Dict(
        label => read_qe_upf_data(path) for
        (label, path) in sort!(collect(metadata.upf_files); by = first)
    )
    plan = build_qe_projector_plan(metadata, upf_data)
    metadata.spinorbit &&
        !native.spinor &&
        throw(
            ArgumentError(
                "QE_UPF_DATA_REQUIRED: spin-orbit augmentation requires spinor coefficients",
            ),
        )
    projectors, bases = _qe_beta_overlaps(native, upf_data, plan)
    residual, worst =
        _qe_generalized_norm_residual(native, projectors, upf_data, plan, metadata.spinorbit)
    metric = _QEStrictSewingMetric(
        upf_data,
        plan,
        projectors,
        bases,
        metadata.spinorbit,
        Dict{Tuple{String, NTuple{3, Float64}, Int, Bool}, Array{ComplexF64, 4}}(),
        qe_metric_kind_label(metadata.metric_kinds),
    )
    return metric, residual, worst
end

# Build the complete VASP projector/Q context and its mandatory native norm gate.
function _strict_sewing_metric(source::VASPWavefunctionSource, native::NativeWavefunctionData)
    paw = read_vasp_paw_system(something(source.potcar_file), native.structure)
    projectors = _paw_projectors(native, paw)
    bases = [_paw_projector_basis(point, native, paw) for point in native.kpoints]
    residual, worst = _paw_generalized_norm_residuals(native, paw, projectors)
    return _VASPStrictSewingMetric(paw, projectors, bases), residual, worst
end

# Re-evaluate generalized normalization using an already parsed strict metric.
function _strict_generalized_norm_from_metric(
    metric::_AbstractStrictSewingMetric,
    native::NativeWavefunctionData,
)
    maximum_residual = 0.0
    worst = (kpoint = 0, target_band = 0, source_band = 0)
    for (kpoint, point) in enumerate(native.kpoints)
        overlap, _, _ = _strict_metric_overlap(
            metric,
            point.coefficients,
            point.coefficients,
            metric.projectors[kpoint],
            metric.projectors[kpoint],
        )
        residual = abs.(overlap - I)
        index = argmax(residual)
        value = residual[index]
        if value > maximum_residual
            maximum_residual = value
            worst = (kpoint = kpoint, target_band = index[1], source_band = index[2])
        end
    end
    return maximum_residual, worst
end

# Apply the exact canonical real-space operation in the target plane-wave basis.
function _strict_transform_plane_wave_coefficients(
    source::PlaneWaveKPoint,
    target::PlaneWaveKPoint,
    operation::SymmetryOperation,
    reciprocal_shift::AbstractVector{<:Integer},
)
    all(isfinite, source.coefficients) && all(isfinite, target.coefficients) ||
        throw(ArgumentError("NONFINITE_COEFFICIENT_BLOCK: strict sewing input is non-finite"))
    size(source.coefficients, 1) == size(target.coefficients, 1) ||
        throw(ArgumentError("PAW_SEWING_BAND_COUNT_MISMATCH: source and target bands disagree"))
    spin_components = size(source.coefficients, 3)
    size(target.coefficients, 3) == spin_components || throw(
        ArgumentError("PAW_SEWING_SPIN_MISMATCH: source and target spin conventions disagree"),
    )
    target_index = Dict(Tuple(target.g_vectors[row, :]) => row for row in axes(target.g_vectors, 1))
    length(target_index) == size(target.g_vectors, 1) || throw(
        ArgumentError("PAW_SEWING_G_VECTOR_DUPLICATE: target plane-wave indices are not unique"),
    )
    transformed =
        zeros(ComplexF64, size(source.coefficients, 1), size(target.g_vectors, 1), spin_components)
    reciprocal_action = transpose(inv(operation.rotation_fractional))
    spin_matrix = spin_action_matrix(operation, spin_components == 2)
    sign = operation.antiunitary ? -1.0 : 1.0
    hits = falses(size(target.g_vectors, 1))
    for source_g in axes(source.g_vectors, 1)
        source_wavevector = source.k_fractional .+ @view(source.g_vectors[source_g, :])
        target_wavevector = sign .* (reciprocal_action * source_wavevector)
        mapped_source_g = sign .* (reciprocal_action * @view(source.g_vectors[source_g, :]))
        maximum(abs, mapped_source_g .- round.(mapped_source_g)) <= 1.0e-8 ||
            throw(ArgumentError("INVALID_SYMMETRY_ACTION: noninteger mapped plane-wave index"))
        target_g = Int.(reciprocal_shift) .+ round.(Int, mapped_source_g)
        maximum(abs, target_wavevector .- target.k_fractional .- target_g) <= 1.0e-8 || throw(
            ArgumentError(
                "INVALID_SYMMETRY_ACTION: reciprocal shift contradicts plane-wave action",
            ),
        )
        target_row = get(target_index, Tuple(target_g), 0)
        target_row != 0 || throw(
            ArgumentError(
                "PAW_SEWING_PLANE_WAVE_MAPPING_INCOMPLETE: full-cutoff target omits mapped G=$(target_g)",
            ),
        )
        hits[target_row] && throw(
            ArgumentError("PAW_SEWING_PLANE_WAVE_MAPPING_NONBIJECTIVE: target G was mapped twice"),
        )
        hits[target_row] = true
        phase = cis(-2.0 * pi * dot(target_wavevector, operation.translation_fractional))
        for band in axes(source.coefficients, 1), output_spin in 1:spin_components
            value = 0.0 + 0.0im
            for input_spin in 1:spin_components
                coefficient = source.coefficients[band, source_g, input_spin]
                operation.antiunitary && (coefficient = conj(coefficient))
                value += spin_matrix[output_spin, input_spin] * coefficient
            end
            transformed[band, target_row, output_spin] = phase * value
        end
    end
    all(hits) || throw(
        ArgumentError(
            "PAW_SEWING_PLANE_WAVE_MAPPING_INCOMPLETE: source/target full-cutoff bases differ",
        ),
    )
    return transformed
end

# Contract the pseudo coefficient part in target-row/source-column convention.
function _strict_pseudo_overlap(
    target_coefficients::Array{ComplexF64, 3},
    transformed_coefficients::Array{ComplexF64, 3},
)
    size(target_coefficients, 2) == size(transformed_coefficients, 2) || throw(
        ArgumentError("PAW_SEWING_PLANE_WAVE_MAPPING_INCOMPLETE: coefficient widths disagree"),
    )
    size(target_coefficients, 3) == size(transformed_coefficients, 3) ||
        throw(ArgumentError("PAW_SEWING_SPIN_MISMATCH: coefficient spin dimensions disagree"))
    output = zeros(ComplexF64, size(target_coefficients, 1), size(transformed_coefficients, 1))
    for spin in axes(target_coefficients, 3)
        output .+=
            conj(@view(target_coefficients[:, :, spin])) *
            transpose(@view(transformed_coefficients[:, :, spin]))
    end
    return output
end

# Scalar-Q₀ contraction used by VASP and synthetic non-SOC test oracles.
function _strict_scalar_q0_overlap(
    target_projectors::Array{ComplexF64, 3},
    transformed_projectors::Array{ComplexF64, 3},
    q0::AbstractMatrix{<:Real},
)
    size(target_projectors, 2) == size(q0, 1) == size(q0, 2) ||
        throw(ArgumentError("PAW_SEWING_PROJECTOR_DIMENSION_MISMATCH: Q₀ dimensions disagree"))
    size(target_projectors, 3) == size(transformed_projectors, 3) ||
        throw(ArgumentError("PAW_SEWING_SPIN_MISMATCH: projector spin dimensions disagree"))
    output = zeros(ComplexF64, size(target_projectors, 1), size(transformed_projectors, 1))
    for spin in axes(target_projectors, 3)
        output .+=
            conj(@view(target_projectors[:, :, spin])) *
            q0 *
            transpose(@view(transformed_projectors[:, :, spin]))
    end
    return output
end

# Complex Neumaier summation used by the cancellation audit without changing production order.
function _strict_compensated_complex_sum(terms::Vector{ComplexF64})
    total = 0.0 + 0.0im
    correction = 0.0 + 0.0im
    for term in terms
        updated = total + term
        correction += abs(total) >= abs(term) ? (total - updated) + term : (term - updated) + total
        total = updated
    end
    return total + correction
end

# Accumulate the same Float64 scalar terms at a frozen arbitrary precision.
function _strict_bigfloat_complex_sum(terms::Vector{ComplexF64}, precision_bits::Int)
    return setprecision(BigFloat, precision_bits) do
        total = Complex{BigFloat}(0, 0)
        for term in terms
            total += Complex{BigFloat}(BigFloat(real(term)), BigFloat(imag(term)))
        end
        ComplexF64(total)
    end
end

# Expand one pseudo-overlap matrix element into its deterministic G/spin scalar terms.
function _strict_pseudo_overlap_terms(
    target_coefficients::Array{ComplexF64, 3},
    transformed_coefficients::Array{ComplexF64, 3},
    target_band::Int,
    source_band::Int,
)
    terms = ComplexF64[]
    sizehint!(terms, size(target_coefficients, 2) * size(target_coefficients, 3))
    for spin in axes(target_coefficients, 3), plane_wave in axes(target_coefficients, 2)
        push!(
            terms,
            conj(target_coefficients[target_band, plane_wave, spin]) *
            transformed_coefficients[source_band, plane_wave, spin],
        )
    end
    return terms
end

# Expand one QE augmentation element into deterministic atom/spin/channel scalar terms.
function _strict_augmentation_overlap_terms(
    metric::_QEStrictSewingMetric,
    target_projectors::Array{ComplexF64, 3},
    transformed_projectors::Array{ComplexF64, 3},
    target_band::Int,
    source_band::Int,
)
    terms = ComplexF64[]
    spin_components = size(target_projectors, 3)
    rounded_zero = (0.0, 0.0, 0.0)
    for atom in metric.plan.atoms
        dataset = metric.upf_data[atom.atomic_type_label]
        dataset.metric_kind == :norm_conserving && continue
        q0 = get!(
            metric.finite_b_cache,
            (atom.atomic_type_label, rounded_zero, spin_components, metric.spinorbit),
        ) do
            scalar = _qe_finite_b_scalar_matrix(dataset, atom.channels, zeros(3))
            _qe_spin_augmentation_matrix(
                scalar,
                dataset,
                atom.channels,
                spin_components,
                metric.spinorbit,
            )
        end
        for spin_left in 1:spin_components,
            spin_right in 1:spin_components,
            local_left in axes(q0, 1),
            local_right in axes(q0, 2)

            global_left = first(atom.channel_range) + local_left - 1
            global_right = first(atom.channel_range) + local_right - 1
            push!(
                terms,
                conj(target_projectors[target_band, global_left, spin_left]) *
                q0[local_left, local_right, spin_left, spin_right] *
                transformed_projectors[source_band, global_right, spin_right],
            )
        end
    end
    return terms
end

# Expand one VASP augmentation element into deterministic spin/channel scalar terms.
function _strict_augmentation_overlap_terms(
    metric::_VASPStrictSewingMetric,
    target_projectors::Array{ComplexF64, 3},
    transformed_projectors::Array{ComplexF64, 3},
    target_band::Int,
    source_band::Int,
)
    terms = ComplexF64[]
    q0 = metric.paw.q0_augmentation
    for spin in axes(target_projectors, 3), left in axes(q0, 1), right in axes(q0, 2)
        push!(
            terms,
            conj(target_projectors[target_band, left, spin]) *
            q0[left, right] *
            transformed_projectors[source_band, right, spin],
        )
    end
    return terms
end

"""Recompute one pseudo plus augmentation element using independent accumulation orders."""
function _strict_metric_overlap_element_stability(
    metric::_AbstractStrictSewingMetric,
    target_coefficients::Array{ComplexF64, 3},
    transformed_coefficients::Array{ComplexF64, 3},
    target_projectors::Array{ComplexF64, 3},
    transformed_projectors::Array{ComplexF64, 3},
    target_band::Int,
    source_band::Int;
    precision_bits::Int = 256,
)
    pseudo_terms = _strict_pseudo_overlap_terms(
        target_coefficients,
        transformed_coefficients,
        target_band,
        source_band,
    )
    augmentation_terms = _strict_augmentation_overlap_terms(
        metric,
        target_projectors,
        transformed_projectors,
        target_band,
        source_band,
    )
    production_pseudo = sum(pseudo_terms)
    production_augmentation = sum(augmentation_terms)
    reverse_pseudo = sum(Iterators.reverse(pseudo_terms))
    reverse_augmentation = sum(Iterators.reverse(augmentation_terms))
    compensated_pseudo = _strict_compensated_complex_sum(pseudo_terms)
    compensated_augmentation = _strict_compensated_complex_sum(augmentation_terms)
    reference_pseudo = _strict_bigfloat_complex_sum(pseudo_terms, precision_bits)
    reference_augmentation = _strict_bigfloat_complex_sum(augmentation_terms, precision_bits)
    production_total = production_pseudo + production_augmentation
    reverse_total = reverse_pseudo + reverse_augmentation
    compensated_total = compensated_pseudo + compensated_augmentation
    reference_total = reference_pseudo + reference_augmentation
    return (
        production_pseudo = production_pseudo,
        production_augmentation = production_augmentation,
        production_total = production_total,
        reverse_total = reverse_total,
        compensated_total = compensated_total,
        reference_pseudo = reference_pseudo,
        reference_augmentation = reference_augmentation,
        reference_total = reference_total,
        production_absolute_difference = abs(production_total - reference_total),
        reverse_absolute_difference = abs(reverse_total - reference_total),
        compensated_absolute_difference = abs(compensated_total - reference_total),
        pseudo_absolute_difference = abs(production_pseudo - reference_pseudo),
        augmentation_absolute_difference = abs(production_augmentation - reference_augmentation),
        cancellation_condition = (abs(reference_pseudo) + abs(reference_augmentation)) /
                                 max(abs(reference_total), eps(Float64)),
    )
end

# Reproject one transformed QE state set in the authoritative target-k basis.
function _strict_transformed_projectors(
    metric::_QEStrictSewingMetric,
    target_kpoint::Int,
    transformed::Array{ComplexF64, 3},
)
    basis = metric.projector_bases[target_kpoint]
    values = zeros(ComplexF64, size(transformed, 1), metric.plan.num_channels, size(transformed, 3))
    for spin in axes(transformed, 3)
        values[:, :, spin] .= @view(transformed[:, :, spin]) * conj(basis)
    end
    return values
end

# Reproject one transformed VASP state set in the authoritative target-k basis.
function _strict_transformed_projectors(
    metric::_VASPStrictSewingMetric,
    target_kpoint::Int,
    transformed::Array{ComplexF64, 3},
)
    basis = metric.projector_bases[target_kpoint]
    values = zeros(ComplexF64, size(transformed, 1), metric.paw.num_channels, size(transformed, 3))
    for spin in axes(transformed, 3)
        values[:, :, spin] .= @view(transformed[:, :, spin]) * transpose(basis)
    end
    return values
end

# Contract the complete QE physical q=0 metric, including SOC augmentation.
function _strict_metric_overlap(
    metric::_QEStrictSewingMetric,
    left_coefficients::Array{ComplexF64, 3},
    right_coefficients::Array{ComplexF64, 3},
    left_projectors::Array{ComplexF64, 3},
    right_projectors::Array{ComplexF64, 3},
)
    pseudo = _strict_pseudo_overlap(left_coefficients, right_coefficients)
    zero_b = zeros(3)
    augmentation = _qe_augmentation_block(
        left_projectors,
        right_projectors,
        metric.upf_data,
        metric.plan,
        zero_b,
        zero_b,
        metric.spinorbit,
        metric.finite_b_cache,
    )
    return pseudo + augmentation, pseudo, augmentation
end

# Contract the complete VASP physical q=0 metric.
function _strict_metric_overlap(
    metric::_VASPStrictSewingMetric,
    left_coefficients::Array{ComplexF64, 3},
    right_coefficients::Array{ComplexF64, 3},
    left_projectors::Array{ComplexF64, 3},
    right_projectors::Array{ComplexF64, 3},
)
    pseudo = _strict_pseudo_overlap(left_coefficients, right_coefficients)
    augmentation =
        _strict_scalar_q0_overlap(left_projectors, right_projectors, metric.paw.q0_augmentation)
    return pseudo + augmentation, pseudo, augmentation
end

"""Evaluate PAW-S residual weights for one supplied target-basis coefficient map."""
function _strict_reconstruction_residual_diagnostics(
    metric::_AbstractStrictSewingMetric,
    target_coefficients::Array{ComplexF64, 3},
    transformed_coefficients::Array{ComplexF64, 3},
    target_projectors::Array{ComplexF64, 3},
    transformed_projectors::Array{ComplexF64, 3},
    expansion::Matrix{ComplexF64},
    ;
    enforce_metric::Bool = true,
)
    residual_coefficients = similar(transformed_coefficients)
    residual_projectors = similar(transformed_projectors)
    for spin in axes(transformed_coefficients, 3)
        residual_coefficients[:, :, spin] .=
            @view(transformed_coefficients[:, :, spin]) .-
            transpose(expansion) * @view(target_coefficients[:, :, spin])
        residual_projectors[:, :, spin] .=
            @view(transformed_projectors[:, :, spin]) .-
            transpose(expansion) * @view(target_projectors[:, :, spin])
    end
    overlap, _, _ = _strict_metric_overlap(
        metric,
        residual_coefficients,
        residual_coefficients,
        residual_projectors,
        residual_projectors,
    )
    hermitian_overlap = Hermitian(0.5 .* (overlap + overlap'))
    eigenvalues = eigvals(hermitian_overlap)
    diagonal = real.(diag(hermitian_overlap))
    minimum_eigenvalue = minimum(eigenvalues)
    if minimum_eigenvalue < -1.0e-10
        enforce_metric &&
            throw(ArgumentError("PAW_SEWING_METRIC_INDEFINITE: reconstruction has negative S norm"))
        return (
            reconstruction_leakage_weight = Inf,
            state_leakage_weight = Inf,
            reconstruction_leakage_amplitude_audit = Inf,
            state_leakage_amplitude_audit = Inf,
            minimum_residual_gram_eigenvalue = minimum_eigenvalue,
        )
    end
    reconstruction_weight = max(maximum(eigenvalues), 0.0)
    state_weight = max(maximum(diagonal), 0.0)
    state_weight <= reconstruction_weight + 64 * eps(max(reconstruction_weight, 1.0)) || throw(
        ArgumentError(
            "PAW_SEWING_WEIGHT_ORDER_HOLD: state leakage weight exceeds reconstruction weight",
        ),
    )
    return (
        reconstruction_leakage_weight = reconstruction_weight,
        state_leakage_weight = state_weight,
        reconstruction_leakage_amplitude_audit = sqrt(reconstruction_weight),
        state_leakage_amplitude_audit = sqrt(state_weight),
        minimum_residual_gram_eigenvalue = minimum_eigenvalue,
    )
end

"""
Return Gram-aware physical residual norms for `g psi - target * C`.

With target states stored by row and `B = <target|S|g psi>`, the qualified
coefficient map is `C = G_target^-1 B`, not `B` itself unless the target frame
is exactly PAW-S orthonormal.  The positive-definite solve makes the result
basis covariant without hiding rank loss behind a pseudoinverse.
"""
function _strict_reconstruction_diagnostics(
    metric::_AbstractStrictSewingMetric,
    target_coefficients::Array{ComplexF64, 3},
    transformed_coefficients::Array{ComplexF64, 3},
    target_projectors::Array{ComplexF64, 3},
    transformed_projectors::Array{ComplexF64, 3},
    raw::Matrix{ComplexF64},
    ;
    enforce_metric::Bool = true,
)
    target_gram, _, _ = _strict_metric_overlap(
        metric,
        target_coefficients,
        target_coefficients,
        target_projectors,
        target_projectors,
    )
    all(isfinite, target_gram) ||
        throw(ArgumentError("NONFINITE_TARGET_GRAM: reconstruction target metric is non-finite"))
    hermitian_target_gram = Hermitian(0.5 .* (target_gram + target_gram'))
    decomposition = eigen(hermitian_target_gram)
    maximum_eigenvalue = maximum(decomposition.values)
    rank_threshold = max(size(target_gram)...) * eps(Float64) * max(maximum_eigenvalue, 1.0)
    if minimum(decomposition.values) <= rank_threshold
        enforce_metric && throw(
            ArgumentError(
                "PAW_SEWING_TARGET_GRAM_RANK_FAILED: reconstruction target Gram is not " *
                "positive definite at threshold $(rank_threshold)",
            ),
        )
        return (
            reconstruction_leakage_weight = Inf,
            state_leakage_weight = Inf,
            reconstruction_leakage_amplitude_audit = Inf,
            state_leakage_amplitude_audit = Inf,
            minimum_residual_gram_eigenvalue = -Inf,
        )
    end
    expansion = cholesky(hermitian_target_gram) \ raw
    return _strict_reconstruction_residual_diagnostics(
        metric,
        target_coefficients,
        transformed_coefficients,
        target_projectors,
        transformed_projectors,
        expansion;
        enforce_metric,
    )
end

# Retain the former direct-B diagnostic as report-only audit evidence.
function _strict_raw_direct_reconstruction_diagnostics(
    metric::_AbstractStrictSewingMetric,
    target_coefficients::Array{ComplexF64, 3},
    transformed_coefficients::Array{ComplexF64, 3},
    target_projectors::Array{ComplexF64, 3},
    transformed_projectors::Array{ComplexF64, 3},
    raw::Matrix{ComplexF64},
    ;
    enforce_metric::Bool = true,
)
    return _strict_reconstruction_residual_diagnostics(
        metric,
        target_coefficients,
        transformed_coefficients,
        target_projectors,
        transformed_projectors,
        raw;
        enforce_metric,
    )
end

# Restrict one raw PAW diagnostic to the ragged authority subspace.  The
# selected source and target ranks may vary with k, but symmetry closure
# requires them to agree for every mapped pair.
function _strict_scoped_reconstruction_diagnostics(
    metric::_AbstractStrictSewingMetric,
    target_coefficients::Array{ComplexF64, 3},
    transformed_coefficients::Array{ComplexF64, 3},
    target_projectors::Array{ComplexF64, 3},
    transformed_projectors::Array{ComplexF64, 3},
    raw::Matrix{ComplexF64},
    target_indices::Vector{Int},
    source_indices::Vector{Int},
)
    isempty(source_indices) &&
        throw(ArgumentError("TARGET_SUBSPACE_EMPTY: outer-window authority cannot be empty"))
    length(target_indices) == length(source_indices) || throw(
        ArgumentError(
            "PAW_SEWING_TARGET_SUBSPACE_NOT_CLOSED: mapped outer ranks disagree " *
            "($(length(source_indices))) -> ($(length(target_indices)))",
        ),
    )
    return _strict_reconstruction_diagnostics(
        metric,
        Array{ComplexF64, 3}(target_coefficients[target_indices, :, :]),
        Array{ComplexF64, 3}(transformed_coefficients[source_indices, :, :]),
        Array{ComplexF64, 3}(target_projectors[target_indices, :, :]),
        Array{ComplexF64, 3}(transformed_projectors[source_indices, :, :]),
        Matrix{ComplexF64}(@view raw[target_indices, source_indices]),
        enforce_metric = true,
    )
end

# Restrict the legacy direct-B reconstruction audit to one ragged authority block.
function _strict_scoped_raw_direct_reconstruction_diagnostics(
    metric::_AbstractStrictSewingMetric,
    target_coefficients::Array{ComplexF64, 3},
    transformed_coefficients::Array{ComplexF64, 3},
    target_projectors::Array{ComplexF64, 3},
    transformed_projectors::Array{ComplexF64, 3},
    raw::Matrix{ComplexF64},
    target_indices::Vector{Int},
    source_indices::Vector{Int},
)
    isempty(source_indices) &&
        throw(ArgumentError("TARGET_SUBSPACE_EMPTY: outer-window authority cannot be empty"))
    length(target_indices) == length(source_indices) || throw(
        ArgumentError(
            "PAW_SEWING_TARGET_SUBSPACE_NOT_CLOSED: mapped outer ranks disagree " *
            "($(length(source_indices))) -> ($(length(target_indices)))",
        ),
    )
    return _strict_raw_direct_reconstruction_diagnostics(
        metric,
        Array{ComplexF64, 3}(target_coefficients[target_indices, :, :]),
        Array{ComplexF64, 3}(transformed_coefficients[source_indices, :, :]),
        Array{ComplexF64, 3}(target_projectors[target_indices, :, :]),
        Array{ComplexF64, 3}(transformed_projectors[source_indices, :, :]),
        Matrix{ComplexF64}(@view raw[target_indices, source_indices]),
        enforce_metric = false,
    )
end

# Measure the physical S-unitarity of the native states only in the authority
# masks.  The same full-cutoff metric is used; only the band scope changes.
function _strict_scoped_generalized_norm(
    metric::_AbstractStrictSewingMetric,
    native::NativeWavefunctionData,
    masks::Vector{BitVector},
)
    length(masks) == length(native.kpoints) ||
        throw(ArgumentError("TARGET_SUBSPACE_MASK_KPOINT_MISMATCH"))
    maximum_residual = 0.0
    worst = (kpoint = 0, target_band = 0, source_band = 0)
    for (kpoint, point) in enumerate(native.kpoints)
        indices = findall(masks[kpoint])
        isempty(indices) &&
            throw(ArgumentError("TARGET_SUBSPACE_EMPTY: outer mask is empty at k-point $(kpoint)"))
        coefficients = Array{ComplexF64, 3}(point.coefficients[indices, :, :])
        projectors = Array{ComplexF64, 3}(metric.projectors[kpoint][indices, :, :])
        overlap, _, _ =
            _strict_metric_overlap(metric, coefficients, coefficients, projectors, projectors)
        residual = abs.(overlap - I)
        index = argmax(residual)
        value = residual[index]
        if value > maximum_residual
            maximum_residual = value
            worst =
                (kpoint = kpoint, target_band = indices[index[1]], source_band = indices[index[2]])
        end
    end
    return maximum_residual, worst
end

# Return the explicit two-way target/complement weights requested by the
# authority contract.  Squared spectral norms are used so the dimensionless
# probability-weight gate is basis invariant inside either subspace.
function _strict_bidirectional_target_complement_leakage(
    raw::Matrix{ComplexF64},
    target_outer::BitVector,
    source_outer::BitVector,
)
    target_indices = findall(target_outer)
    source_indices = findall(source_outer)
    target_complement = findall(.!target_outer)
    source_complement = findall(.!source_outer)
    target_to_complement_amplitude =
        isempty(target_complement) || isempty(source_indices) ? 0.0 :
        opnorm(Matrix{ComplexF64}(@view raw[target_complement, source_indices]), 2)
    complement_to_target_amplitude =
        isempty(target_indices) || isempty(source_complement) ? 0.0 :
        opnorm(Matrix{ComplexF64}(@view raw[target_indices, source_complement]), 2)
    target_to_complement_weight = abs2(target_to_complement_amplitude)
    complement_to_target_weight = abs2(complement_to_target_amplitude)
    return (
        target_to_complement_leakage_weight = target_to_complement_weight,
        complement_to_target_leakage_weight = complement_to_target_weight,
        maximum_leakage_weight = max(target_to_complement_weight, complement_to_target_weight),
        target_to_complement_leakage_amplitude_audit = target_to_complement_amplitude,
        complement_to_target_leakage_amplitude_audit = complement_to_target_amplitude,
    )
end

# Fail closed on a required scoped PAW block before any polar repair.  Keeping
# rank and both isometry directions explicit prevents a rectangular or
# one-sided near-isometry from being promoted as a target representation.
function _strict_required_square_block_diagnostics(
    raw::Matrix{ComplexF64},
    target_indices::Vector{Int},
    source_indices::Vector{Int},
    scope::Symbol,
)
    length(target_indices) == length(source_indices) || throw(
        ArgumentError("PAW_SEWING_TARGET_SUBSPACE_NOT_CLOSED: $(scope) mapped ranks disagree"),
    )
    isempty(source_indices) && return (
        required_rank = 0,
        numerical_rank = 0,
        rank_threshold = 0.0,
        sigma_min = 0.0,
        sigma_max = 0.0,
        left_unitarity_residual = 0.0,
        right_unitarity_residual = 0.0,
    )
    block = Matrix{ComplexF64}(@view raw[target_indices, source_indices])
    singular_values = svdvals(block)
    sigma_max = maximum(singular_values)
    sigma_min = minimum(singular_values)
    rank_threshold = max(size(block)...) * eps(Float64) * max(sigma_max, 1.0)
    numerical_rank = count(>(rank_threshold), singular_values)
    required_rank = length(source_indices)
    numerical_rank == required_rank || throw(
        ArgumentError(
            "PAW_SEWING_TARGET_SUBSPACE_RANK_FAILED: $(scope) numerical rank " *
            "$(numerical_rank) differs from $(required_rank)",
        ),
    )
    identity_matrix = Matrix{ComplexF64}(I, required_rank, required_rank)
    return (
        required_rank,
        numerical_rank,
        rank_threshold,
        sigma_min,
        sigma_max,
        left_unitarity_residual = maximum(abs, block * block' - identity_matrix),
        right_unitarity_residual = maximum(abs, block' * block - identity_matrix),
    )
end

# Validate the ragged authority masks and distinguish target closure from the
# complete-parent energy audit.  Parent mismatch is deliberately returned as
# evidence and never raised here.
function _strict_validate_target_subspace_contract(
    outer_masks::Vector{BitVector},
    frozen_masks::Vector{BitVector},
    energies_ev::Matrix{Float64},
    mapping::Matrix{Int},
    tolerance_ev::Float64;
    enforce_thresholds::Bool = true,
)
    nb, nk = size(energies_ev)
    length(outer_masks) == nk == length(frozen_masks) ||
        throw(ArgumentError("TARGET_SUBSPACE_MASK_KPOINT_MISMATCH"))
    all(isfinite, energies_ev) || throw(ArgumentError("NONFINITE_TARGET_SUBSPACE_ENERGIES"))
    target_energy_residual = 0.0
    frozen_energy_residual = 0.0
    parent_energy_residual = 0.0
    target_worst = (operation = 0, source_kpoint = 0, target_kpoint = 0)
    frozen_worst = target_worst
    parent_worst = target_worst
    for kpoint in 1:nk
        length(outer_masks[kpoint]) == nb == length(frozen_masks[kpoint]) ||
            throw(ArgumentError("TARGET_SUBSPACE_MASK_BAND_MISMATCH"))
        any(outer_masks[kpoint]) ||
            throw(ArgumentError("TARGET_SUBSPACE_EMPTY: outer mask is empty at k-point $(kpoint)"))
        all((.!frozen_masks[kpoint]) .| outer_masks[kpoint]) || throw(
            ArgumentError(
                "TARGET_SUBSPACE_FROZEN_NOT_CONTAINED: frozen mask escapes outer at k-point $(kpoint)",
            ),
        )
    end
    for source_kpoint in 1:nk, operation_index in axes(mapping, 1)
        target_kpoint = mapping[operation_index, source_kpoint]
        source_outer = findall(outer_masks[source_kpoint])
        target_outer = findall(outer_masks[target_kpoint])
        length(source_outer) == length(target_outer) || throw(
            ArgumentError(
                "PAW_SEWING_TARGET_SUBSPACE_NOT_CLOSED: outer rank $(length(source_outer)) " *
                "maps to $(length(target_outer)); operation=$(operation_index), " *
                "source_kpoint=$(source_kpoint), target_kpoint=$(target_kpoint)",
            ),
        )
        source_frozen = findall(frozen_masks[source_kpoint])
        target_frozen = findall(frozen_masks[target_kpoint])
        length(source_frozen) == length(target_frozen) || throw(
            ArgumentError(
                "PAW_SEWING_FROZEN_SUBSPACE_NOT_CLOSED: frozen rank $(length(source_frozen)) " *
                "maps to $(length(target_frozen))",
            ),
        )
        frozen_local =
            isempty(source_frozen) ? 0.0 :
            maximum(
                abs,
                sort(energies_ev[source_frozen, source_kpoint]) .-
                sort(energies_ev[target_frozen, target_kpoint]),
            )
        if frozen_local > frozen_energy_residual
            frozen_energy_residual = frozen_local
            frozen_worst = (
                operation = operation_index,
                source_kpoint = source_kpoint,
                target_kpoint = target_kpoint,
            )
        end
        target_local = maximum(
            abs,
            sort(energies_ev[source_outer, source_kpoint]) .-
            sort(energies_ev[target_outer, target_kpoint]),
        )
        if target_local > target_energy_residual
            target_energy_residual = target_local
            target_worst = (
                operation = operation_index,
                source_kpoint = source_kpoint,
                target_kpoint = target_kpoint,
            )
        end
        parent_local = maximum(
            abs,
            sort(@view(energies_ev[:, source_kpoint])) .-
            sort(@view(energies_ev[:, target_kpoint])),
        )
        if parent_local > parent_energy_residual
            parent_energy_residual = parent_local
            parent_worst = (
                operation = operation_index,
                source_kpoint = source_kpoint,
                target_kpoint = target_kpoint,
            )
        end
    end
    !enforce_thresholds ||
        target_energy_residual <= tolerance_ev ||
        throw(
            ArgumentError(
                "PAW_SEWING_TARGET_SUBSPACE_NOT_CLOSED: target energy-set residual " *
                "$(target_energy_residual) exceeds $(tolerance_ev); worst=$(repr(target_worst))",
            ),
        )
    !enforce_thresholds ||
        frozen_energy_residual <= tolerance_ev ||
        throw(
            ArgumentError(
                "PAW_SEWING_FROZEN_SUBSPACE_NOT_CLOSED: frozen energy-set residual " *
                "$(frozen_energy_residual) exceeds $(tolerance_ev); worst=$(repr(frozen_worst))",
            ),
        )
    return (
        target_energy_residual = target_energy_residual,
        target_energy_worst = target_worst,
        frozen_energy_residual = frozen_energy_residual,
        frozen_energy_worst = frozen_worst,
        parent_energy_residual = parent_energy_residual,
        parent_energy_worst = parent_worst,
        parent_energy_status = parent_energy_residual <= tolerance_ev ? :AUDIT_PASS :
                               :AUDIT_EXCEEDED,
    )
end

# Append one canonical scoped raw diagnostic from a physical pre-polar matrix.
function _strict_scoped_diagnostics!(raw_diagnostics, raw::Matrix{ComplexF64}, scopes)
    for scoped in scopes
        source_indices = Int[scoped.source_indices...]
        target_indices = Int[scoped.target_indices...]
        required_rank = min(length(source_indices), length(target_indices))
        if isempty(source_indices) || isempty(target_indices)
            push!(
                raw_diagnostics,
                Dict{String, Any}(
                    "kind" => scoped.scope == :full ? "full" : "qualification_scope",
                    "scope" => String(scoped.scope),
                    "source_band_count" => length(source_indices),
                    "target_band_count" => length(target_indices),
                    "required_rank" => required_rank,
                    "numerical_rank" => 0,
                    "rank_threshold" => 0.0,
                    "sigma_min" => 0.0,
                    "sigma_max" => 0.0,
                    "condition_estimate" => Inf,
                    "left_unitarity_residual" => 0.0,
                    "right_unitarity_residual" => 0.0,
                    "unitarity_residual" => 0.0,
                    "status" => "EMPTY_SCOPE",
                ),
            )
            continue
        end
        block = Matrix{ComplexF64}(@view raw[target_indices, source_indices])
        singular_values = svdvals(block)
        sigma_max = maximum(singular_values)
        sigma_min = minimum(singular_values)
        rank_threshold = max(size(block)...) * eps(Float64) * max(sigma_max, 1.0)
        left_identity = Matrix{ComplexF64}(I, size(block, 1), size(block, 1))
        right_identity = Matrix{ComplexF64}(I, size(block, 2), size(block, 2))
        left_residual = maximum(abs, block * block' - left_identity)
        right_residual = maximum(abs, block' * block - right_identity)
        push!(
            raw_diagnostics,
            Dict{String, Any}(
                "kind" => scoped.scope == :full ? "full" : "qualification_scope",
                "scope" => String(scoped.scope),
                "source_band_count" => length(source_indices),
                "target_band_count" => length(target_indices),
                "required_rank" => required_rank,
                "numerical_rank" => count(>(rank_threshold), singular_values),
                "rank_threshold" => rank_threshold,
                "sigma_min" => sigma_min,
                "sigma_max" => sigma_max,
                "condition_estimate" => sigma_min > 0.0 ? sigma_max / sigma_min : Inf,
                "left_unitarity_residual" => left_residual,
                "right_unitarity_residual" => right_residual,
                "unitarity_residual" => max(left_residual, right_residual),
                "status" =>
                    length(source_indices) == length(target_indices) ? "REPORT_ONLY" :
                    "DIMENSION_MISMATCH",
            ),
        )
    end
    return nothing
end

# Convert one scalar failed strict gate into the public fail-stop classification.
function _strict_sewing_gate(
    metric::AbstractString,
    value::Real,
    threshold::Real;
    context::AbstractString = "NOT_RECORDED",
)
    isfinite(value) && value <= threshold || throw(
        ArgumentError(
            "PAW_SEWING_HOLD: $(metric)=$(value) exceeds frozen threshold $(threshold); " *
            "worst_context=$(context)",
        ),
    )
    return nothing
end

"""Retain a quality check and its action while keeping nonfinite measurements fatal."""
function _paw_sewing_quality_gate!(
    records,
    enforce_thresholds,
    metric,
    value,
    threshold;
    context::AbstractString = "NOT_RECORDED",
)
    isfinite(value) || _strict_sewing_gate(metric, value, threshold; context)
    passed = value <= threshold
    push!(
        records,
        Dict{String, Any}(
            "code" => "PAW_SEWING_QUALITY_CHECK",
            "severity" => passed ? "info" : "error",
            "message" => "Original PAW sewing quality check retained.",
            "context" => Dict{String, String}(
                "stage" => "representation_preparation",
                "metric" => String(metric),
                "value" => string(value),
                "threshold" => string(threshold),
                "gate_result" => passed ? "PASS" : "FAIL",
                "action" =>
                    passed ? "CONTINUE" : enforce_thresholds ? "STOP" : "CONTINUE_DIAGNOSTIC",
                "construction_policy" => enforce_thresholds ? "strict" : "diagnostic",
                "worst_context" => context,
            ),
        ),
    )
    enforce_thresholds && _strict_sewing_gate(metric, value, threshold; context)
    return nothing
end

"""Reject a necessary polar block with insufficient rank, reusing its computed singular values."""
function _paw_sewing_required_polar_rank(values, dimension)
    all(isfinite, values) ||
        throw(ArgumentError("NONFINITE_SEWING_BLOCK: polar spectrum is nonfinite"))
    threshold = dimension * eps(Float64) * max(maximum(values), 1.0)
    count(>(threshold), values) == dimension || throw(
        ArgumentError(
            "PAW_SEWING_TARGET_SUBSPACE_RANK_FAILED: necessary polar block is rank deficient",
        ),
    )
    return nothing
end

# Apply the frozen group-law tolerance to the numerically reconstructed
# reciprocal-shift cocycle. Floating-point roundoff is not a structural hold.
function _strict_reciprocal_shift_cocycle_gate(
    value::Real,
    threshold::Real;
    root_cause::AbstractString = "PAW_SEWING_HOLD",
    context::AbstractString = "NOT_RECORDED",
)
    isfinite(value) && 0.0 <= value <= threshold || throw(
        ArgumentError(
            "$(root_cause): reciprocal-shift cocycle residual $(value) exceeds frozen " *
            "threshold $(threshold); worst_context=$(context)",
        ),
    )
    return nothing
end

# Retain the exact operation/k-point context whenever one strict maximum changes.
function _strict_update_maximum!(maxima, contexts, key::AbstractString, value::Real, context)
    numeric = Float64(value)
    if !haskey(contexts, key) || numeric > maxima[key]
        maxima[key] = numeric
        contexts[key] = repr(context)
    end
    return nothing
end

"""
Separate projective closure from the prescribed translation/spin cocycle.

The common group-law validator below remains the absolute gate. This audit
additionally fits only one unit-modulus scalar to each product, reports the
remaining matrix residual, and compares that scalar with the exact cocycle.
"""
function _strict_raw_projective_diagnostics(
    representation::BandRepresentation,
    product_table,
    validation_masks::Union{Nothing, Vector{BitVector}} = nothing,
)
    projective_residuals = zeros(Float64, 4)
    cocycle_residuals = zeros(Float64, 4)
    worst_contexts = [Dict{String, String}() for _ in 1:4]
    for source_kpoint in axes(representation.kpoint_map, 2),
        left_index in eachindex(representation.operations),
        right_index in eachindex(representation.operations)

        product_index = product_table.product_indices[left_index, right_index]
        intermediate_kpoint = representation.kpoint_map[right_index, source_kpoint]
        product_kpoint = representation.kpoint_map[product_index, source_kpoint]
        source_indices =
            validation_masks === nothing ? axes(representation.sewing_matrices, 2) :
            findall(validation_masks[source_kpoint])
        intermediate_indices =
            validation_masks === nothing ? axes(representation.sewing_matrices, 2) :
            findall(validation_masks[intermediate_kpoint])
        target_indices =
            validation_masks === nothing ? axes(representation.sewing_matrices, 1) :
            findall(validation_masks[product_kpoint])
        (isempty(source_indices) || isempty(intermediate_indices) || isempty(target_indices)) &&
            continue
        left = Matrix(
            @view representation.sewing_matrices[
                target_indices,
                intermediate_indices,
                left_index,
                intermediate_kpoint,
            ]
        )
        right = Matrix(
            @view representation.sewing_matrices[
                intermediate_indices,
                source_indices,
                right_index,
                source_kpoint,
            ]
        )
        representation.operations[left_index].antiunitary && (right = conj(right))
        canonical = Matrix(
            @view representation.sewing_matrices[
                target_indices,
                source_indices,
                product_index,
                source_kpoint,
            ]
        )
        composed = left * right
        canonical_norm = sum(abs2, canonical)
        fitted_overlap =
            canonical_norm > 0.0 ? dot(vec(canonical), vec(composed)) / canonical_norm : 0.0 + 0.0im
        fitted_phase =
            abs(fitted_overlap) > eps(Float64) ? fitted_overlap / abs(fitted_overlap) : 0.0 + 0.0im
        translation = @view product_table.translation_differences[:, left_index, right_index]
        product_k = @view representation.kpoints_fractional[product_kpoint, :]
        expected_phase =
            product_table.spinor_factors[left_index, right_index] *
            cis(-2.0 * pi * dot(product_k, translation))
        projective_residual =
            fitted_phase == 0.0 ? Inf : maximum(abs, composed - fitted_phase .* canonical)
        cocycle_residual = fitted_phase == 0.0 ? Inf : abs(fitted_phase - expected_phase)
        channel = group_law_combination_index(
            representation.operations[left_index].antiunitary,
            representation.operations[right_index].antiunitary,
        )
        if max(projective_residual, cocycle_residual) >
           max(projective_residuals[channel], cocycle_residuals[channel])
            worst_contexts[channel] = Dict(
                "left_operation" => string(left_index),
                "right_operation" => string(right_index),
                "product_operation" => string(product_index),
                "source_kpoint" => string(source_kpoint),
                "intermediate_kpoint" => string(intermediate_kpoint),
                "product_kpoint" => string(product_kpoint),
                "projective_residual" => string(projective_residual),
                "cocycle_phase_residual" => string(cocycle_residual),
                "fitted_phase" => string(fitted_phase),
                "expected_phase" => string(expected_phase),
            )
        end
        projective_residuals[channel] = max(projective_residuals[channel], projective_residual)
        cocycle_residuals[channel] = max(cocycle_residuals[channel], cocycle_residual)
    end
    return Tuple(projective_residuals), Tuple(cocycle_residuals), Tuple(worst_contexts)
end

# Format complex spectral fingerprints without locale- or display-mode drift.
_strict_spectrum_value(value::Complex) = @sprintf("%.17e%+.17ei", real(value), imag(value))

"""
Serialize raw little-group eigenvalue/corepresentation-square fingerprints.

For a unitary little-group operation the energy-block eigenvalues are stored.
For an antiunitary operation, whose eigenvalues are not gauge invariants, the
eigenvalues of `B*conj(B)` are stored instead. The identity is omitted because
it contains only block dimensions already present in the representation.
"""
function _strict_little_group_spectrum_records(representation::BandRepresentation, product_table)
    records = String[]
    for representative in representation.irreducible_indices,
        operation_index in eachindex(representation.operations)

        operation_index == product_table.identity_index && continue
        representation.kpoint_map[operation_index, representative] == representative || continue
        operation = representation.operations[operation_index]
        labels = @view representation.band_block_labels[:, representative]
        for label in sort!(unique(Vector(labels)))
            indices = findall(==(label), labels)
            block = Matrix(
                @view representation.sewing_matrices[
                    indices,
                    indices,
                    operation_index,
                    representative,
                ]
            )
            spectral_matrix = operation.antiunitary ? block * conj(block) : block
            values = ComplexF64.(eigvals(spectral_matrix))
            all(isfinite, values) || throw(
                ArgumentError("NONFINITE_LITTLE_GROUP_SPECTRUM: raw sewing spectrum is non-finite"),
            )
            sort!(values; by = value -> (angle(value), real(value), imag(value)))
            kind = operation.antiunitary ? "antiunitary_square" : "unitary"
            push!(
                records,
                join(
                    (
                        "k=$(representative)",
                        "operation=$(operation_index)",
                        "operation_key=$(canonical_band_operation_key(operation))",
                        "block=$(first(indices)):$(last(indices))",
                        "kind=$(kind)",
                        "trace=$(_strict_spectrum_value(ComplexF64(tr(spectral_matrix))))",
                        "eigenvalues=$(join(_strict_spectrum_value.(values), ','))",
                    ),
                    ';',
                ),
            )
        end
    end
    return records
end

"""Add strict-backend source files not owned by the generic native reader."""
function _strict_input_hashes(source::AbstractWavefunctionSource, native::NativeWavefunctionData)
    return Dict{String, String}(native.input_sha256)
end

"""Extend strict VASP provenance with mandatory POTCAR and optional OUTCAR."""
function _strict_input_hashes(source::VASPWavefunctionSource, native::NativeWavefunctionData)
    hashes = Dict{String, String}(native.input_sha256)
    hashes["POTCAR"] = sha256_file(something(source.potcar_file))
    source.outcar_file === nothing ||
        (hashes["OUTCAR"] = sha256_file(something(source.outcar_file)))
    return hashes
end

"""
Construct `B = <psi(gk)|T†(gk) g T(k)|psi(k)>` before block polar projection.

The transformed pseudo state is reprojected in the target-k projector basis;
this incorporates atom permutation, fractional translation, orbital rotation,
spinor rotation, and antiunitary conjugation without a pseudo-only fallback.
"""
function build_augmentation_aware_band_representation(
    source::AbstractWavefunctionSource,
    native::NativeWavefunctionData,
    energies_ev::Matrix{Float64},
    operations::Vector{SymmetryOperation},
    degeneracy_tolerance_ev::Float64,
    backend::AugmentationAwareSewing;
    symmetry_inventory = nothing,
    plane_wave_convention::Symbol = :canonical,
    diagnostic_outer_masks = nothing,
    diagnostic_frozen_masks = nothing,
    strict_metric::Union{Nothing, _AbstractStrictSewingMetric} = nothing,
    block_partition_policy::Union{Nothing, AbstractPAWBlockPartitionPolicy} = nothing,
    enforce_thresholds::Bool = true,
)
    plane_wave_convention == :canonical ||
        throw(ArgumentError("PAW_SEWING_CONVENTION_UNSUPPORTED: strict sewing requires :canonical"))
    isempty(operations) && throw(ArgumentError("INVALID_SYMMETRY_ACTION: operation list is empty"))
    validate_canonical_antiunitary_channel(native, operations)
    get(native.source_metadata, "coefficient_normalization", "") in ("qe_raw", "vasp_raw") ||
        throw(ArgumentError("PAW_SEWING_RAW_COEFFICIENTS_REQUIRED: input was normalized"))
    nk = length(native.kpoints)
    nb = size(first(native.kpoints).coefficients, 1)
    size(energies_ev) == (nb, nk) || throw(
        ArgumentError("PAW_SEWING_SOURCE_IDENTITY_FAILED: EIG/native band dimensions disagree"),
    )
    native_energies = reduce(hcat, (point.energies_ev for point in native.kpoints))
    maximum(abs, native_energies - energies_ev) <= 1.0e-5 || throw(
        ArgumentError(
            "PAW_SEWING_SOURCE_IDENTITY_FAILED: EIG differs from native eigenvalues by more than 1e-5 eV",
        ),
    )
    (diagnostic_outer_masks === nothing) == (diagnostic_frozen_masks === nothing) ||
        throw(ArgumentError("raw diagnostic outer and frozen masks must be supplied together"))
    if diagnostic_outer_masks !== nothing
        length(diagnostic_outer_masks) == nk == length(diagnostic_frozen_masks) ||
            throw(ArgumentError("raw diagnostic masks disagree with the k-point count"))
    end

    kpoints = Matrix{Float64}(undef, nk, 3)
    for (kpoint_index, point) in enumerate(native.kpoints)
        kpoints[kpoint_index, :] .= point.k_fractional
    end
    mapping, shifts = build_canonical_kpoint_action(operations, kpoints; tolerance = 1.0e-8)
    irreducible, full_to_irreducible, full_to_operation = canonical_irreducible_star_plan(mapping)
    labels = canonical_band_block_labels(energies_ev, degeneracy_tolerance_ev)
    quality_records = Dict{String, Any}[]
    quality_gate(args...; kwargs...) =
        _paw_sewing_quality_gate!(quality_records, enforce_thresholds, args...; kwargs...)
    target_scope_active = diagnostic_outer_masks !== nothing
    target_contract = if target_scope_active
        _strict_validate_target_subspace_contract(
            diagnostic_outer_masks,
            diagnostic_frozen_masks,
            energies_ev,
            mapping,
            degeneracy_tolerance_ev;
            enforce_thresholds,
        )
    else
        nothing
    end
    if target_scope_active
        quality_gate(
            "target_energy_set",
            target_contract.target_energy_residual,
            degeneracy_tolerance_ev;
            context = repr(target_contract.target_energy_worst),
        )
        quality_gate(
            "frozen_energy_set",
            target_contract.frozen_energy_residual,
            degeneracy_tolerance_ev;
            context = repr(target_contract.frozen_energy_worst),
        )
    end
    metric, native_norm_residual, native_norm_worst = if strict_metric === nothing
        _strict_sewing_metric(source, native)
    else
        supplied_metric = something(strict_metric)
        length(supplied_metric.projectors) == nk || throw(
            ArgumentError("PAW_GAUGE_ARTIFACT_TAMPERED: strict metric k-point count differs"),
        )
        residual, worst = _strict_generalized_norm_from_metric(supplied_metric, native)
        supplied_metric, residual, worst
    end
    target_norm_residual, target_norm_worst =
        target_scope_active ?
        _strict_scoped_generalized_norm(metric, native, diagnostic_outer_masks) :
        (native_norm_residual, native_norm_worst)
    raw_sewing = Array{ComplexF64, 4}(undef, nb, nb, length(operations), nk)
    sewing = zeros(ComplexF64, nb, nb, length(operations), nk)
    raw_diagnostics = Any[]
    maxima = Dict(
        "transformed_generalized_norm_residual" => 0.0,
        "reconstruction_leakage_amplitude_audit" => 0.0,
        "state_leakage_amplitude_audit" => 0.0,
        "audit_raw_direct_reconstruction_leakage_amplitude" => 0.0,
        "audit_raw_direct_state_leakage_amplitude" => 0.0,
        "target_to_complement_leakage_weight" => 0.0,
        "complement_to_target_leakage_weight" => 0.0,
        "maximum_bidirectional_leakage_weight" => 0.0,
        "target_to_complement_leakage_amplitude_audit" => 0.0,
        "complement_to_target_leakage_amplitude_audit" => 0.0,
        "target_reconstruction_leakage_weight" => 0.0,
        "target_state_leakage_weight" => 0.0,
        "audit_target_raw_direct_reconstruction_leakage_amplitude" => 0.0,
        "audit_target_raw_direct_state_leakage_amplitude" => 0.0,
        "target_generalized_norm_residual" => target_norm_residual,
        "target_raw_left_unitarity_residual" => 0.0,
        "target_raw_right_unitarity_residual" => 0.0,
        "frozen_raw_left_unitarity_residual" => 0.0,
        "frozen_raw_right_unitarity_residual" => 0.0,
        "target_normalized_polar_correction" => 0.0,
        "parent_complement_normalized_polar_correction" => 0.0,
        "nondegenerate_block_leakage" => 0.0,
        "near_block_leakage" => 0.0,
        "far_band_coupling" => 0.0,
        "raw_left_unitarity_residual" => 0.0,
        "raw_right_unitarity_residual" => 0.0,
        "normalized_polar_correction" => 0.0,
        "pseudo_component_maximum" => 0.0,
        "augmentation_component_maximum" => 0.0,
    )
    maximum_contexts = Dict{String, String}()
    identity_matrix = Matrix{ComplexF64}(I, nb, nb)
    weighted_partition = block_partition_policy isa HamiltonianWeightedPAWBlockPartition
    near_gap_ev =
        weighted_partition ?
        (block_partition_policy::HamiltonianWeightedPAWBlockPartition).near_gap_ev : Inf

    for source_kpoint in 1:nk, operation_index in eachindex(operations)
        target_kpoint = mapping[operation_index, source_kpoint]
        if !target_scope_active
            quality_gate(
                "symmetry_related_energy_set",
                maximum(abs, energies_ev[:, source_kpoint] - energies_ev[:, target_kpoint]),
                degeneracy_tolerance_ev;
                context = repr((operation = operation_index, source_kpoint, target_kpoint)),
            )
        end
        transformed = _strict_transform_plane_wave_coefficients(
            native.kpoints[source_kpoint],
            native.kpoints[target_kpoint],
            operations[operation_index],
            @view(shifts[:, operation_index, source_kpoint]),
        )
        transformed_projectors = _strict_transformed_projectors(metric, target_kpoint, transformed)
        target_projectors = metric.projectors[target_kpoint]
        raw, pseudo, augmentation = _strict_metric_overlap(
            metric,
            native.kpoints[target_kpoint].coefficients,
            transformed,
            target_projectors,
            transformed_projectors,
        )
        all(isfinite, raw) ||
            throw(ArgumentError("NONFINITE_SEWING_BLOCK: augmentation-aware sewing is non-finite"))
        raw_sewing[:, :, operation_index, source_kpoint] .= raw

        transformed_norm, _, _ = _strict_metric_overlap(
            metric,
            transformed,
            transformed,
            transformed_projectors,
            transformed_projectors,
        )
        transformed_norm_residual = maximum(abs, transformed_norm - identity_matrix)
        reconstruction = _strict_reconstruction_diagnostics(
            metric,
            native.kpoints[target_kpoint].coefficients,
            transformed,
            target_projectors,
            transformed_projectors,
            raw,
            enforce_metric = !target_scope_active,
        )
        raw_direct_reconstruction = _strict_raw_direct_reconstruction_diagnostics(
            metric,
            native.kpoints[target_kpoint].coefficients,
            transformed,
            target_projectors,
            transformed_projectors,
            raw,
            enforce_metric = false,
        )
        source_outer = target_scope_active ? diagnostic_outer_masks[source_kpoint] : trues(nb)
        target_outer = target_scope_active ? diagnostic_outer_masks[target_kpoint] : trues(nb)
        source_outer_indices = findall(source_outer)
        target_outer_indices = findall(target_outer)
        target_reconstruction =
            target_scope_active ?
            _strict_scoped_reconstruction_diagnostics(
                metric,
                native.kpoints[target_kpoint].coefficients,
                transformed,
                target_projectors,
                transformed_projectors,
                raw,
                target_outer_indices,
                source_outer_indices,
            ) : reconstruction
        target_raw_direct_reconstruction =
            target_scope_active ?
            _strict_scoped_raw_direct_reconstruction_diagnostics(
                metric,
                native.kpoints[target_kpoint].coefficients,
                transformed,
                target_projectors,
                transformed_projectors,
                raw,
                target_outer_indices,
                source_outer_indices,
            ) : raw_direct_reconstruction
        target_transformed_coefficients =
            Array{ComplexF64, 3}(transformed[source_outer_indices, :, :])
        target_transformed_projectors =
            Array{ComplexF64, 3}(transformed_projectors[source_outer_indices, :, :])
        target_transformed_norm, _, _ = _strict_metric_overlap(
            metric,
            target_transformed_coefficients,
            target_transformed_coefficients,
            target_transformed_projectors,
            target_transformed_projectors,
        )
        target_identity =
            Matrix{ComplexF64}(I, length(source_outer_indices), length(source_outer_indices))
        target_transformed_norm_residual = maximum(abs, target_transformed_norm - target_identity)
        target_block_diagnostics = _strict_required_square_block_diagnostics(
            raw,
            target_outer_indices,
            source_outer_indices,
            :outer,
        )
        source_frozen = target_scope_active ? diagnostic_frozen_masks[source_kpoint] : falses(nb)
        target_frozen = target_scope_active ? diagnostic_frozen_masks[target_kpoint] : falses(nb)
        source_frozen_indices = findall(source_frozen)
        target_frozen_indices = findall(target_frozen)
        frozen_block_diagnostics = _strict_required_square_block_diagnostics(
            raw,
            target_frozen_indices,
            source_frozen_indices,
            :frozen,
        )
        target_left_residual = target_block_diagnostics.left_unitarity_residual
        target_right_residual = target_block_diagnostics.right_unitarity_residual
        frozen_left_residual = frozen_block_diagnostics.left_unitarity_residual
        frozen_right_residual = frozen_block_diagnostics.right_unitarity_residual
        bidirectional_leakage =
            _strict_bidirectional_target_complement_leakage(raw, target_outer, source_outer)
        left_residual = maximum(abs, raw * raw' - identity_matrix)
        right_residual = maximum(abs, raw' * raw - identity_matrix)
        block_leakage = 0.0
        block_leakage_pair = (target_band = 0, source_band = 0)
        near_block_leakage = 0.0
        near_block_leakage_pair = (target_band = 0, source_band = 0)
        far_band_coupling = 0.0
        far_band_coupling_pair = (target_band = 0, source_band = 0)
        for target_band in 1:nb, source_band in 1:nb
            labels[target_band, target_kpoint] == labels[source_band, source_kpoint] && continue
            value = abs(raw[target_band, source_band])
            if value > block_leakage
                block_leakage = value
                block_leakage_pair = (target_band = target_band, source_band = source_band)
            end
            gap_ev = abs(
                energies_ev[target_band, target_kpoint] - energies_ev[source_band, source_kpoint],
            )
            if gap_ev <= near_gap_ev
                if value > near_block_leakage
                    near_block_leakage = value
                    near_block_leakage_pair = (target_band = target_band, source_band = source_band)
                end
            elseif value > far_band_coupling
                far_band_coupling = value
                far_band_coupling_pair = (target_band = target_band, source_band = source_band)
            end
        end
        operation_context = (
            operation = operation_index,
            source_kpoint = source_kpoint,
            target_kpoint = target_kpoint,
            antiunitary = operations[operation_index].antiunitary,
            translation_fractional = Tuple(operations[operation_index].translation_fractional),
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "transformed_generalized_norm_residual",
            transformed_norm_residual,
            operation_context,
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "reconstruction_leakage_amplitude_audit",
            reconstruction.reconstruction_leakage_amplitude_audit,
            operation_context,
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "state_leakage_amplitude_audit",
            reconstruction.state_leakage_amplitude_audit,
            operation_context,
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "audit_raw_direct_reconstruction_leakage_amplitude",
            raw_direct_reconstruction.reconstruction_leakage_amplitude_audit,
            operation_context,
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "audit_raw_direct_state_leakage_amplitude",
            raw_direct_reconstruction.state_leakage_amplitude_audit,
            operation_context,
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "target_reconstruction_leakage_weight",
            target_reconstruction.reconstruction_leakage_weight,
            operation_context,
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "target_state_leakage_weight",
            target_reconstruction.state_leakage_weight,
            operation_context,
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "audit_target_raw_direct_reconstruction_leakage_amplitude",
            target_raw_direct_reconstruction.reconstruction_leakage_amplitude_audit,
            operation_context,
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "audit_target_raw_direct_state_leakage_amplitude",
            target_raw_direct_reconstruction.state_leakage_amplitude_audit,
            operation_context,
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "target_generalized_norm_residual",
            target_transformed_norm_residual,
            operation_context,
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "target_raw_left_unitarity_residual",
            target_left_residual,
            operation_context,
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "target_raw_right_unitarity_residual",
            target_right_residual,
            operation_context,
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "frozen_raw_left_unitarity_residual",
            frozen_left_residual,
            operation_context,
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "frozen_raw_right_unitarity_residual",
            frozen_right_residual,
            operation_context,
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "target_to_complement_leakage_weight",
            bidirectional_leakage.target_to_complement_leakage_weight,
            operation_context,
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "complement_to_target_leakage_weight",
            bidirectional_leakage.complement_to_target_leakage_weight,
            operation_context,
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "maximum_bidirectional_leakage_weight",
            bidirectional_leakage.maximum_leakage_weight,
            operation_context,
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "target_to_complement_leakage_amplitude_audit",
            bidirectional_leakage.target_to_complement_leakage_amplitude_audit,
            operation_context,
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "complement_to_target_leakage_amplitude_audit",
            bidirectional_leakage.complement_to_target_leakage_amplitude_audit,
            operation_context,
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "nondegenerate_block_leakage",
            block_leakage,
            merge(operation_context, block_leakage_pair),
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "near_block_leakage",
            near_block_leakage,
            merge(operation_context, near_block_leakage_pair),
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "far_band_coupling",
            far_band_coupling,
            merge(operation_context, far_band_coupling_pair),
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "raw_left_unitarity_residual",
            left_residual,
            operation_context,
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "raw_right_unitarity_residual",
            right_residual,
            operation_context,
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "pseudo_component_maximum",
            maximum(abs, pseudo),
            operation_context,
        )
        _strict_update_maximum!(
            maxima,
            maximum_contexts,
            "augmentation_component_maximum",
            maximum(abs, augmentation),
            operation_context,
        )

        scopes =
            diagnostic_outer_masks === nothing ?
            ((scope = :full, source_indices = 1:nb, target_indices = 1:nb),) :
            (
                (scope = :full, source_indices = 1:nb, target_indices = 1:nb),
                (
                    scope = :outer,
                    source_indices = findall(diagnostic_outer_masks[source_kpoint]),
                    target_indices = findall(diagnostic_outer_masks[target_kpoint]),
                ),
                (
                    scope = :frozen,
                    source_indices = findall(diagnostic_frozen_masks[source_kpoint]),
                    target_indices = findall(diagnostic_frozen_masks[target_kpoint]),
                ),
                (
                    scope = :outside,
                    source_indices = findall(.!diagnostic_outer_masks[source_kpoint]),
                    target_indices = findall(.!diagnostic_outer_masks[target_kpoint]),
                ),
            )
        first_diagnostic = length(raw_diagnostics) + 1
        _strict_scoped_diagnostics!(raw_diagnostics, raw, scopes)

        if target_scope_active
            target_blocks = (
                (
                    scope = :frozen,
                    source = source_frozen_indices,
                    target = target_frozen_indices,
                    maximum_key = "target_normalized_polar_correction",
                ),
                (
                    scope = :outer_unfrozen,
                    source = findall(source_outer .& .!source_frozen),
                    target = findall(target_outer .& .!target_frozen),
                    maximum_key = "target_normalized_polar_correction",
                ),
                (
                    scope = :parent_complement,
                    source = findall(.!source_outer),
                    target = findall(.!target_outer),
                    maximum_key = "parent_complement_normalized_polar_correction",
                ),
            )
            for scoped_block in target_blocks
                isempty(scoped_block.source) && isempty(scoped_block.target) && continue
                length(scoped_block.source) == length(scoped_block.target) || throw(
                    ArgumentError(
                        "PAW_SEWING_TARGET_SUBSPACE_NOT_CLOSED: $(scoped_block.scope) " *
                        "dimensions disagree",
                    ),
                )
                raw_block = Matrix{ComplexF64}(@view raw[scoped_block.target, scoped_block.source])
                decomposition = svd(raw_block)
                scoped_block.scope in (:frozen, :outer_unfrozen) &&
                    _paw_sewing_required_polar_rank(decomposition.S, length(scoped_block.source))
                polar = decomposition.U * decomposition.Vt
                correction = norm(polar - raw_block) / sqrt(length(scoped_block.source))
                _strict_update_maximum!(
                    maxima,
                    maximum_contexts,
                    scoped_block.maximum_key,
                    correction,
                    merge(operation_context, (scope = scoped_block.scope,)),
                )
                scoped_block.scope in (:frozen, :outer_unfrozen) && _strict_update_maximum!(
                    maxima,
                    maximum_contexts,
                    "normalized_polar_correction",
                    correction,
                    merge(operation_context, (scope = scoped_block.scope,)),
                )
                sewing[scoped_block.target, scoped_block.source, operation_index, source_kpoint] .=
                    polar
                block_identity =
                    Matrix{ComplexF64}(I, length(scoped_block.source), length(scoped_block.source))
                push!(
                    raw_diagnostics,
                    Dict{String, Any}(
                        "kind" => "target_contract_block",
                        "block_scope" => String(scoped_block.scope),
                        "source_band_count" => length(scoped_block.source),
                        "target_band_count" => length(scoped_block.target),
                        "sigma_min" => minimum(decomposition.S),
                        "sigma_max" => maximum(decomposition.S),
                        "condition_estimate" => maximum(decomposition.S) / minimum(decomposition.S),
                        "unitarity_residual" => max(
                            maximum(abs, raw_block' * raw_block - block_identity),
                            maximum(abs, raw_block * raw_block' - block_identity),
                        ),
                        "normalized_polar_correction" => correction,
                    ),
                )
            end
        else
            for label in sort(unique(@view(labels[:, source_kpoint])))
                source_block = findall(==(label), @view(labels[:, source_kpoint]))
                target_block = findall(==(label), @view(labels[:, target_kpoint]))
                length(source_block) == length(target_block) || throw(
                    ArgumentError(
                        "PAW_SEWING_TARGET_SUBSPACE_NOT_CLOSED: energy-block dimensions disagree",
                    ),
                )
                raw_block = Matrix{ComplexF64}(@view raw[target_block, source_block])
                decomposition = svd(raw_block)
                _paw_sewing_required_polar_rank(decomposition.S, length(source_block))
                polar = decomposition.U * decomposition.Vt
                correction = norm(polar - raw_block) / sqrt(length(source_block))
                _strict_update_maximum!(
                    maxima,
                    maximum_contexts,
                    "normalized_polar_correction",
                    correction,
                    merge(
                        operation_context,
                        (
                            block_label = label,
                            block_start = first(source_block),
                            block_stop = last(source_block),
                        ),
                    ),
                )
                sewing[target_block, source_block, operation_index, source_kpoint] .= polar
                block_identity = Matrix{ComplexF64}(I, length(source_block), length(source_block))
                push!(
                    raw_diagnostics,
                    Dict{String, Any}(
                        "kind" => "energy_block",
                        "block_start" => first(source_block),
                        "block_stop" => last(source_block),
                        "sigma_min" => minimum(decomposition.S),
                        "sigma_max" => maximum(decomposition.S),
                        "condition_estimate" => maximum(decomposition.S) / minimum(decomposition.S),
                        "unitarity_residual" => max(
                            maximum(abs, raw_block' * raw_block - block_identity),
                            maximum(abs, raw_block * raw_block' - block_identity),
                        ),
                        "normalized_polar_correction" => correction,
                    ),
                )
            end
        end
        push!(
            raw_diagnostics,
            Dict{String, Any}(
                "kind" => "augmentation_aware_operation",
                "source_kpoint" => source_kpoint,
                "target_kpoint" => target_kpoint,
                "operation" => operation_index,
                "operation_key" => canonical_band_operation_key(operations[operation_index]),
                "pseudo_component_maximum" => maximum(abs, pseudo),
                "augmentation_component_maximum" => maximum(abs, augmentation),
                "transformed_generalized_norm_residual" => transformed_norm_residual,
                "reconstruction_leakage_amplitude_audit" =>
                    reconstruction.reconstruction_leakage_amplitude_audit,
                "state_leakage_amplitude_audit" => reconstruction.state_leakage_amplitude_audit,
                "target_reconstruction_leakage_weight" =>
                    target_reconstruction.reconstruction_leakage_weight,
                "target_state_leakage_weight" => target_reconstruction.state_leakage_weight,
                "target_generalized_norm_residual" => target_transformed_norm_residual,
                "target_raw_left_unitarity_residual" => target_left_residual,
                "target_raw_right_unitarity_residual" => target_right_residual,
                "target_required_rank" => target_block_diagnostics.required_rank,
                "target_numerical_rank" => target_block_diagnostics.numerical_rank,
                "target_rank_threshold" => target_block_diagnostics.rank_threshold,
                "target_sigma_min" => target_block_diagnostics.sigma_min,
                "target_sigma_max" => target_block_diagnostics.sigma_max,
                "frozen_required_rank" => frozen_block_diagnostics.required_rank,
                "frozen_numerical_rank" => frozen_block_diagnostics.numerical_rank,
                "frozen_rank_threshold" => frozen_block_diagnostics.rank_threshold,
                "frozen_sigma_min" => frozen_block_diagnostics.sigma_min,
                "frozen_sigma_max" => frozen_block_diagnostics.sigma_max,
                "frozen_raw_left_unitarity_residual" => frozen_left_residual,
                "frozen_raw_right_unitarity_residual" => frozen_right_residual,
                "target_to_complement_leakage_weight" =>
                    bidirectional_leakage.target_to_complement_leakage_weight,
                "complement_to_target_leakage_weight" =>
                    bidirectional_leakage.complement_to_target_leakage_weight,
                "maximum_bidirectional_leakage_weight" =>
                    bidirectional_leakage.maximum_leakage_weight,
                "target_to_complement_leakage_amplitude_audit" =>
                    bidirectional_leakage.target_to_complement_leakage_amplitude_audit,
                "complement_to_target_leakage_amplitude_audit" =>
                    bidirectional_leakage.complement_to_target_leakage_amplitude_audit,
                "nondegenerate_block_leakage" => block_leakage,
                "near_block_leakage" => near_block_leakage,
                "far_band_coupling" => far_band_coupling,
                "raw_left_unitarity_residual" => left_residual,
                "raw_right_unitarity_residual" => right_residual,
            ),
        )
        for diagnostic in @view(raw_diagnostics[first_diagnostic:end])
            haskey(diagnostic, "source_kpoint") && continue
            diagnostic["source_kpoint"] = source_kpoint
            diagnostic["target_kpoint"] = target_kpoint
            diagnostic["operation"] = operation_index
            diagnostic["operation_key"] = canonical_band_operation_key(operations[operation_index])
        end
    end

    raw_representation = BandRepresentation(
        "1.5",
        native.source_code,
        native.spinor,
        native.structure.lattice,
        native.reciprocal_lattice,
        native.mp_grid,
        kpoints,
        energies_ev,
        operations,
        mapping,
        shifts,
        raw_sewing,
        labels,
        irreducible,
        full_to_irreducible,
        full_to_operation;
        conventions = Dict("sewing_backend" => band_sewing_backend_key(backend)),
        input_sha256 = _strict_input_hashes(source, native),
    )
    product_table =
        build_representation_product_table(operations, native.spinor; tolerance = 1.0e-10)
    all_masks = [trues(nb) for _ in 1:nk]
    authority_masks = target_scope_active ? diagnostic_outer_masks : all_masks
    group_residuals, reciprocal_cocycle_residual, _, _, group_worst_cases = validate_band_group_law(
        raw_representation,
        product_table,
        authority_masks,
        backend.thresholds.group_law;
        enforce_absolute_group_law = true,
    )
    projective_group_residuals, cocycle_phase_residuals, projective_worst_cases =
        _strict_raw_projective_diagnostics(raw_representation, product_table, authority_masks)
    frozen_group_residuals, _, _, _, frozen_group_worst_cases =
        target_scope_active ?
        validate_band_group_law(
            raw_representation,
            product_table,
            diagnostic_frozen_masks,
            backend.thresholds.group_law;
            enforce_absolute_group_law = true,
        ) : (group_residuals, 0.0, 0.0, WannierizationDiagnostic[], group_worst_cases)
    frozen_projective_group_residuals,
    frozen_cocycle_phase_residuals,
    frozen_projective_worst_cases =
        target_scope_active ?
        _strict_raw_projective_diagnostics(
            raw_representation,
            product_table,
            diagnostic_frozen_masks,
        ) : (projective_group_residuals, cocycle_phase_residuals, projective_worst_cases)
    parent_group_residuals, parent_reciprocal_cocycle_residual, _, _, parent_group_worst_cases =
        target_scope_active ?
        validate_band_group_law(
            raw_representation,
            product_table,
            all_masks,
            backend.thresholds.group_law;
            enforce_absolute_group_law = false,
        ) :
        (
            group_residuals,
            reciprocal_cocycle_residual,
            0.0,
            WannierizationDiagnostic[],
            group_worst_cases,
        )
    parent_projective_group_residuals,
    parent_cocycle_phase_residuals,
    parent_projective_worst_cases =
        target_scope_active ?
        _strict_raw_projective_diagnostics(raw_representation, product_table, all_masks) :
        (projective_group_residuals, cocycle_phase_residuals, projective_worst_cases)
    little_group_spectra = _strict_little_group_spectrum_records(raw_representation, product_table)
    _strict_reciprocal_shift_cocycle_gate(
        reciprocal_cocycle_residual,
        backend.thresholds.group_law;
        context = repr(group_worst_cases),
    )

    thresholds = backend.thresholds
    begin
        quality_gate(
            target_scope_active ? "target_generalized_norm" : "generalized_norm",
            target_scope_active ? target_norm_residual : native_norm_residual,
            thresholds.generalized_norm,
            context = repr(target_scope_active ? target_norm_worst : native_norm_worst),
        )
        quality_gate(
            target_scope_active ? "target_transformed_generalized_norm" :
            "transformed_generalized_norm",
            target_scope_active ? maxima["target_generalized_norm_residual"] :
            maxima["transformed_generalized_norm_residual"],
            thresholds.generalized_norm,
            context = get(
                maximum_contexts,
                target_scope_active ? "target_generalized_norm_residual" :
                "transformed_generalized_norm_residual",
                "NOT_RECORDED",
            ),
        )
        quality_gate(
            target_scope_active ? "target_s_reconstruction" : "s_reconstruction",
            target_scope_active ? maxima["target_reconstruction_leakage_weight"] :
            maxima["reconstruction_leakage_amplitude_audit"],
            target_scope_active ? thresholds.target_leakage_weight : thresholds.reconstruction,
            context = get(
                maximum_contexts,
                target_scope_active ? "target_reconstruction_leakage_weight" :
                "reconstruction_leakage_amplitude_audit",
                "NOT_RECORDED",
            ),
        )
        if target_scope_active
            for name in (
                "target_state_leakage_weight",
                "target_to_complement_leakage_weight",
                "complement_to_target_leakage_weight",
            )
                quality_gate(
                    name,
                    maxima[name],
                    thresholds.target_leakage_weight,
                    context = get(maximum_contexts, name, "NOT_RECORDED"),
                )
            end
            quality_gate(
                "frozen_raw_unitarity",
                max(
                    maxima["frozen_raw_left_unitarity_residual"],
                    maxima["frozen_raw_right_unitarity_residual"],
                ),
                thresholds.raw_unitarity,
                context = get(
                    maximum_contexts,
                    maxima["frozen_raw_left_unitarity_residual"] >=
                    maxima["frozen_raw_right_unitarity_residual"] ?
                    "frozen_raw_left_unitarity_residual" : "frozen_raw_right_unitarity_residual",
                    "NOT_RECORDED",
                ),
            )
        else
            quality_gate(
                "state_leakage_amplitude",
                maxima["state_leakage_amplitude_audit"],
                thresholds.state_leakage_amplitude,
                context = get(maximum_contexts, "state_leakage_amplitude_audit", "NOT_RECORDED"),
            )
            block_leakage_key =
                weighted_partition ? "near_block_leakage" : "nondegenerate_block_leakage"
            quality_gate(
                block_leakage_key,
                maxima[block_leakage_key],
                thresholds.nondegenerate_block_leakage,
                context = get(maximum_contexts, block_leakage_key, "NOT_RECORDED"),
            )
        end
        quality_gate(
            target_scope_active ? "target_raw_unitarity" : "raw_unitarity",
            target_scope_active ?
            max(
                maxima["target_raw_left_unitarity_residual"],
                maxima["target_raw_right_unitarity_residual"],
            ) : max(maxima["raw_left_unitarity_residual"], maxima["raw_right_unitarity_residual"]),
            thresholds.raw_unitarity,
            context = get(
                maximum_contexts,
                target_scope_active ?
                (
                    maxima["target_raw_left_unitarity_residual"] >=
                    maxima["target_raw_right_unitarity_residual"] ?
                    "target_raw_left_unitarity_residual" : "target_raw_right_unitarity_residual"
                ) :
                (
                    maxima["raw_left_unitarity_residual"] >=
                    maxima["raw_right_unitarity_residual"] ? "raw_left_unitarity_residual" :
                    "raw_right_unitarity_residual"
                ),
                "NOT_RECORDED",
            ),
        )
        quality_gate(
            "normalized_polar_correction",
            maxima["normalized_polar_correction"],
            thresholds.normalized_polar_correction,
            context = get(maximum_contexts, "normalized_polar_correction", "NOT_RECORDED"),
        )
        quality_gate(
            "raw_group_law",
            max(maximum(group_residuals), maximum(frozen_group_residuals)),
            thresholds.group_law,
        )
        quality_gate(
            "raw_cocycle",
            max(maximum(cocycle_phase_residuals), maximum(frozen_cocycle_phase_residuals)),
            thresholds.cocycle,
        )
    end

    parent_audit_values = Float64[
        native_norm_residual,
        maxima["transformed_generalized_norm_residual"],
        maxima["reconstruction_leakage_amplitude_audit"],
        max(maxima["raw_left_unitarity_residual"], maxima["raw_right_unitarity_residual"]),
        maxima["parent_complement_normalized_polar_correction"],
        maximum(parent_group_residuals),
        maximum(parent_cocycle_phase_residuals),
    ]
    parent_audit_limits = Float64[
        thresholds.generalized_norm,
        thresholds.generalized_norm,
        thresholds.reconstruction,
        thresholds.raw_unitarity,
        thresholds.normalized_polar_correction,
        thresholds.group_law,
        thresholds.cocycle,
    ]
    parent_audit_exceeded =
        target_scope_active && (
            target_contract.parent_energy_status == :AUDIT_EXCEEDED ||
            !all(isfinite, parent_audit_values) ||
            any(parent_audit_values .> parent_audit_limits)
        )
    append!(raw_diagnostics, quality_records)
    conventions = Dict{String, String}(native.source_metadata)
    conventions["paw_sewing_gate_records_json"] = String(JSON3.write(quality_records))
    conventions["paw_sewing_construction_policy"] = enforce_thresholds ? "strict" : "diagnostic"
    conventions["paw_sewing_quality_failed"] =
        string(any(record -> record["context"]["gate_result"] == "FAIL", quality_records))
    merge!(
        conventions,
        Dict(
            "bloch_phase" => "exp(+i(k+G).r)",
            "center_phase" => "exp(-2pi*i*k.T)",
            "fourier" => "H(k)=sum_R exp(+2pi*i*k.R) H(R)",
            "lattice" => "cartesian row vectors in Angstrom",
            "kpoints" => "fractional row vectors",
            "sewing" => "rows target bands, columns source bands",
            "sewing_definition" => "<psi_m(k_g)|Tdagger(k_g) g T(k)|psi_n(k)>",
            "sewing_backend" => band_sewing_backend_key(backend),
            "sewing_metric" => "Cdagger_C_plus_Pdagger_Q0_P",
            "sewing_construction" => "augmentation_aware_matrix_element",
            "reconstruction_coefficient_map" => "positive_definite_target_gram_solve",
            "raw_direct_reconstruction_qualification" => "AUDIT_ONLY_NO_HARD_GATE",
            "physical_overlap_available" => "true",
            "coefficient_normalization" =>
                get(native.source_metadata, "coefficient_normalization", "raw"),
            "representation_cutoff" => "full_native_wavefunction_cutoff",
            "transformed_projector_overlap" => "recomputed_in_target_k_basis",
            "atom_mapping_contract" => "implicit_in_target_basis_reprojection",
            "generalized_norm_maximum_residual" => string(native_norm_residual),
            "generalized_norm_worst" => repr(native_norm_worst),
            "target_contract_active" => string(target_scope_active),
            "target_authority_scope" =>
                target_scope_active ? "outer_window_ragged" : "full_parent_legacy",
            "target_contract_status" => enforce_thresholds ? "PASS" : "NOT_ENFORCED_DIAGNOSTIC",
            "parent_audit_policy" =>
                target_scope_active ? "REPORT_ONLY_NO_PHYSICS_HARD_GATE" : "LEGACY_HARD_GATE",
            "parent_audit_status" =>
                !target_scope_active ? "NOT_APPLICABLE" :
                parent_audit_exceeded ? "AUDIT_EXCEEDED" : "AUDIT_PASS",
            "target_generalized_norm_maximum_residual" => string(target_norm_residual),
            "target_generalized_norm_worst" => repr(target_norm_worst),
            "target_energy_set_residual_ev" =>
                target_scope_active ? string(target_contract.target_energy_residual) : "0.0",
            "target_energy_set_worst" =>
                target_scope_active ? repr(target_contract.target_energy_worst) : "NOT_APPLICABLE",
            "frozen_energy_set_residual_ev" =>
                target_scope_active ? string(target_contract.frozen_energy_residual) : "0.0",
            "frozen_energy_set_worst" =>
                target_scope_active ? repr(target_contract.frozen_energy_worst) : "NOT_APPLICABLE",
            "parent_energy_set_audit_residual_ev" =>
                target_scope_active ? string(target_contract.parent_energy_residual) : "0.0",
            "parent_energy_set_audit_worst" =>
                target_scope_active ? repr(target_contract.parent_energy_worst) : "NOT_APPLICABLE",
            "parent_energy_set_audit_status" =>
                target_scope_active ? string(target_contract.parent_energy_status) :
                "NOT_APPLICABLE",
            "raw_group_law_UU_UA_AU_AA" => join(group_residuals, ","),
            "block_leakage_gate" =>
                target_scope_active ? "four_independent_target_leakage_weights" :
                weighted_partition ? "near_block_leakage" : "nondegenerate_block_leakage",
            "target_leakage_semantics" => TARGET_LEAKAGE_WEIGHT_SEMANTICS,
            "target_leakage_formula_sha256" => TARGET_LEAKAGE_WEIGHT_FORMULA_SHA256,
            "target_leakage_threshold" => string(thresholds.target_leakage_weight),
            "far_band_coupling_qualification" =>
                weighted_partition ? "report_only_post_gauge_covariance_authoritative" : "legacy",
            "raw_group_law_worst_cases" => repr(group_worst_cases),
            "raw_projective_group_law_UU_UA_AU_AA" => join(projective_group_residuals, ","),
            "raw_cocycle_phase_UU_UA_AU_AA" => join(cocycle_phase_residuals, ","),
            "raw_projective_group_law_worst_cases" => repr(projective_worst_cases),
            "frozen_raw_group_law_UU_UA_AU_AA" => join(frozen_group_residuals, ","),
            "frozen_raw_group_law_worst_cases" => repr(frozen_group_worst_cases),
            "frozen_raw_projective_group_law_UU_UA_AU_AA" =>
                join(frozen_projective_group_residuals, ","),
            "frozen_raw_cocycle_phase_UU_UA_AU_AA" => join(frozen_cocycle_phase_residuals, ","),
            "frozen_raw_projective_group_law_worst_cases" => repr(frozen_projective_worst_cases),
            "raw_reciprocal_cocycle_residual" => string(reciprocal_cocycle_residual),
            "parent_audit_raw_group_law_UU_UA_AU_AA" => join(parent_group_residuals, ","),
            "parent_audit_raw_group_law_worst_cases" => repr(parent_group_worst_cases),
            "parent_audit_raw_projective_group_law_UU_UA_AU_AA" =>
                join(parent_projective_group_residuals, ","),
            "parent_audit_raw_cocycle_phase_UU_UA_AU_AA" =>
                join(parent_cocycle_phase_residuals, ","),
            "parent_audit_raw_projective_group_law_worst_cases" =>
                repr(parent_projective_worst_cases),
            "parent_audit_raw_reciprocal_cocycle_residual" =>
                string(parent_reciprocal_cocycle_residual),
            "raw_little_group_spectrum_convention" => "unitary eigvals(B); antiunitary eigvals(B*conj(B)); raw pre-polar energy blocks",
            "raw_little_group_spectrum_record_count" => string(length(little_group_spectra)),
            "raw_little_group_spectrum_sha256" =>
                bytes2hex(sha256(codeunits(join(little_group_spectra, '\n')))),
            "paw_sewing_thresholds" => repr(thresholds),
        ),
    )
    for (index, record) in enumerate(little_group_spectra)
        conventions[@sprintf("raw_little_group_spectrum_%06d", index)] = record
    end
    for (key, value) in maxima
        conventions["strict_$(key)_maximum"] = string(value)
    end
    for (key, context) in maximum_contexts
        conventions["strict_$(key)_worst_context"] = context
    end
    if metric isa _QEStrictSewingMetric
        conventions["augmentation_backend"] = "native_qe_upf_beta_q0"
        conventions["qe_metric_kind"] = metric.metric_kind
    else
        conventions["augmentation_backend"] = "native_vasp_potcar_projector_q0"
    end
    if symmetry_inventory !== nothing
        conventions["magnetic_structure"] = string(symmetry_inventory.magnetic)
        conventions["msg_type"] = string(symmetry_inventory.msg_type)
        conventions["msg_uni_number"] =
            symmetry_inventory.uni_number === nothing ? "unavailable" :
            string(symmetry_inventory.uni_number)
        conventions["msg_hall_number"] = string(symmetry_inventory.hall_number)
        conventions["msg_unitary_operation_count"] =
            string(symmetry_inventory.unitary_operation_count)
        conventions["msg_antiunitary_operation_count"] =
            string(symmetry_inventory.antiunitary_operation_count)
        conventions["magnetic_symmetry_tolerance"] = string(symmetry_inventory.symmetry_tolerance)
    end
    representation = BandRepresentation(
        "1.5",
        native.source_code,
        native.spinor,
        native.structure.lattice,
        native.reciprocal_lattice,
        native.mp_grid,
        kpoints,
        energies_ev,
        operations,
        mapping,
        shifts,
        sewing,
        labels,
        irreducible,
        full_to_irreducible,
        full_to_operation;
        conventions,
        input_sha256 = _strict_input_hashes(source, native),
    )
    return (representation = representation, construction_diagnostics = raw_diagnostics)
end
