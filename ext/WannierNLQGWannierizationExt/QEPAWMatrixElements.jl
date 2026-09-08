const QE_PAW_MATRIX_ELEMENT_SCHEMA = "WannierNLQG.qe_paw_matrix_elements"
const QE_PAW_MATRIX_ELEMENT_SCHEMA_VERSION = "1.0"
const QE_PAW_ORACLE_PROVENANCE_SCHEMA = "WannierNLQG.qe_paw_oracle_provenance"
const QE_PAW_ORACLE_PROVENANCE_SCHEMA_VERSION = "1.0"
const QE_UPF_RECIPROCAL_GRID_STEP = 0.01

# Four-point cubic interpolation on QE's nonnegative reciprocal radial grid.
function _qe_upf_cubic_interpolation(value_at_grid_index::Function, momentum::Float64)
    momentum >= 0.0 || throw(ArgumentError("QE reciprocal radial momentum must be nonnegative"))
    coordinate = momentum / QE_UPF_RECIPROCAL_GRID_STEP
    lower = floor(Int, coordinate)
    fraction = coordinate - lower
    u = 1.0 - fraction
    v = 2.0 - fraction
    w = 3.0 - fraction
    return value_at_grid_index(lower) * u * v * w / 6.0 +
           value_at_grid_index(lower + 1) * fraction * v * w / 2.0 -
           value_at_grid_index(lower + 2) * fraction * u * w / 2.0 +
           value_at_grid_index(lower + 3) * fraction * u * v / 6.0
end

# QE ylmr2 order is m=0, cos(m=1), sin(m=1), ... for every l. Its
# Condon--Shortley phase remains in the real rows.
function _qe_real_spherical_harmonics(degree::Int, cartesian_vectors::AbstractMatrix{<:Real})
    degree >= 0 || throw(ArgumentError("QE spherical-harmonic degree must be nonnegative"))
    size(cartesian_vectors, 2) == 3 ||
        throw(ArgumentError("QE Cartesian vectors must have three columns"))
    output = zeros(Float64, 2 * degree + 1, size(cartesian_vectors, 1))
    for vector_index in axes(cartesian_vectors, 1)
        x, y, z = Float64.(cartesian_vectors[vector_index, :])
        radius = sqrt(x * x + y * y + z * z)
        polar = radius <= 1.0e-14 ? pi / 2.0 : atan(sqrt(x * x + y * y), z)
        azimuth = atan(y, x)
        output[1, vector_index] =
            real(_paw_positive_complex_spherical_harmonic(0, degree, azimuth, polar))
        for order in 1:degree
            value = _paw_positive_complex_spherical_harmonic(order, degree, azimuth, polar)
            factor = sqrt(2.0)
            output[2 * order, vector_index] = factor * real(value)
            output[2 * order + 1, vector_index] = factor * imag(value)
        end
    end
    return output
end

# Wannier90 trial orbitals use the same row order but cancel the
# Condon--Shortley phase. Keep this convention separate from QE beta/Q rows.
function _qe_wannier90_real_spherical_harmonics(
    degree::Int,
    cartesian_vectors::AbstractMatrix{<:Real},
)
    degree >= 0 || throw(ArgumentError("Wannier90 spherical-harmonic degree must be nonnegative"))
    size(cartesian_vectors, 2) == 3 ||
        throw(ArgumentError("Wannier90 Cartesian vectors must have three columns"))
    output = zeros(Float64, 2 * degree + 1, size(cartesian_vectors, 1))
    for vector_index in axes(cartesian_vectors, 1)
        x, y, z = Float64.(cartesian_vectors[vector_index, :])
        radius = sqrt(x * x + y * y + z * z)
        polar = radius <= 1.0e-14 ? pi / 2.0 : atan(sqrt(x * x + y * y), z)
        azimuth = atan(y, x)
        output[1, vector_index] =
            real(_paw_positive_complex_spherical_harmonic(0, degree, azimuth, polar))
        for order in 1:degree
            value = _paw_positive_complex_spherical_harmonic(order, degree, azimuth, polar)
            factor = sqrt(2.0) * (-1.0)^order
            output[2 * order, vector_index] = factor * real(value)
            output[2 * order + 1, vector_index] = factor * imag(value)
        end
    end
    return output
end

# Evaluate one real spherical harmonic in QE's documented row order.
function _qe_real_harmonic_value(degree::Int, row::Int, azimuth::Float64, polar::Float64)
    1 <= row <= 2 * degree + 1 || throw(ArgumentError("QE real-harmonic row is out of range"))
    row == 1 && return real(_paw_positive_complex_spherical_harmonic(0, degree, azimuth, polar))
    order = fld(row, 2)
    value = _paw_positive_complex_spherical_harmonic(order, degree, azimuth, polar)
    factor = sqrt(2.0)
    return iseven(row) ? factor * real(value) : factor * imag(value)
end

const _QE_REAL_GAUNT_CACHE = Dict{NTuple{6, Int}, Float64}()
const _QE_REAL_GAUNT_LOCK = ReentrantLock()

# Independent quadrature of the triple-real-harmonic integral in QE row order.
function _qe_real_gaunt(
    left_degree::Int,
    left_row::Int,
    middle_degree::Int,
    middle_row::Int,
    right_degree::Int,
    right_row::Int,
)
    key = (left_degree, left_row, middle_degree, middle_row, right_degree, right_row)
    lock(_QE_REAL_GAUNT_LOCK) do
        haskey(_QE_REAL_GAUNT_CACHE, key) && return _QE_REAL_GAUNT_CACHE[key]
    end
    nodes, weights = _paw_gauss_legendre(32)
    azimuth_count = 64
    value = 0.0
    for azimuth_index in 0:(azimuth_count - 1)
        azimuth = 2.0 * pi * azimuth_index / azimuth_count
        for node_index in eachindex(nodes)
            polar = acos(clamp(nodes[node_index], -1.0, 1.0))
            value +=
                weights[node_index] *
                _qe_real_harmonic_value(left_degree, left_row, azimuth, polar) *
                _qe_real_harmonic_value(middle_degree, middle_row, azimuth, polar) *
                _qe_real_harmonic_value(right_degree, right_row, azimuth, polar) *
                (2.0 * pi / azimuth_count)
        end
    end
    abs(value) < 5.0e-14 && (value = 0.0)
    lock(_QE_REAL_GAUNT_LOCK) do
        _QE_REAL_GAUNT_CACHE[key] = value
    end
    return value
end

# Simpson integration on the UPF R/RAB mesh, including QE's even-mesh endpoint rule.
function _qe_upf_simpson(values::AbstractVector{<:Real}, radial_weights::AbstractVector{<:Real})
    length(values) == length(radial_weights) && length(values) >= 3 ||
        throw(ArgumentError("QE radial integrand and PP_RAB dimensions disagree"))
    total = 0.0
    for index in 2:(length(values) - 1)
        factor = iseven(index) ? 4.0 : 2.0
        total += factor * Float64(values[index]) * radial_weights[index]
    end
    if isodd(length(values))
        total += Float64(first(values)) * first(radial_weights)
        total += Float64(last(values)) * last(radial_weights)
    else
        total += Float64(first(values)) * first(radial_weights)
        total -= Float64(values[end - 1]) * radial_weights[end - 1]
    end
    return total / 3.0
end

# Validate that NNKP owns the complete native topology and trial-function contract.
function _qe_validate_nnkp_contract(native::NativeWavefunctionData, nnkp::WannierNNKP)
    length(native.kpoints) == size(nnkp.kpoints_fractional, 1) ||
        throw(ArgumentError("QE_NNKP_TOPOLOGY_MISMATCH: native and NNKP k-point counts differ"))
    native.spinor == nnkp.spinor ||
        throw(ArgumentError("QE_NNKP_SPIN_MISMATCH: native and NNKP spinor conventions differ"))
    isapprox(native.structure.lattice, nnkp.real_lattice; atol = 2.0e-6, rtol = 0.0) ||
        throw(ArgumentError("QE_NNKP_LATTICE_MISMATCH: real lattices differ"))
    isapprox(native.reciprocal_lattice, nnkp.reciprocal_lattice; atol = 2.0e-6, rtol = 0.0) ||
        throw(ArgumentError("QE_NNKP_LATTICE_MISMATCH: reciprocal lattices differ"))
    for (index, point) in enumerate(native.kpoints)
        delta = point.k_fractional .- @view(nnkp.kpoints_fractional[index, :])
        delta .-= round.(delta)
        maximum(abs, delta) <= 1.0e-8 ||
            throw(ArgumentError("QE_NNKP_KPOINT_ORDER_MISMATCH: k-point $(index) differs"))
    end
    total_bands = size(first(native.kpoints).coefficients, 1)
    all(index -> index <= total_bands, nnkp.excluded_bands) ||
        throw(ArgumentError("QE_NNKP_BAND_AUTHORITY_REQUIRED: excluded band is out of range"))
    length(nnkp.excluded_bands) < total_bands ||
        throw(ArgumentError("QE_NNKP_BAND_AUTHORITY_REQUIRED: every band is excluded"))
    selected_bands = total_bands - length(nnkp.excluded_bands)
    selected_bands >= length(nnkp.projections) || throw(
        ArgumentError(
            "QE_NNKP_BAND_AUTHORITY_REQUIRED: $(selected_bands) selected bands cannot span " *
            "$(length(nnkp.projections)) trial projections",
        ),
    )
    return nothing
end

# Apply only the NNKP excluded-band mask after the raw files have been read in full.
function _qe_select_nnkp_bands(native::NativeWavefunctionData, nnkp::WannierNNKP)
    total_bands = size(first(native.kpoints).coefficients, 1)
    excluded = Set(nnkp.excluded_bands)
    selected = [band for band in 1:total_bands if !(band in excluded)]
    points = PlaneWaveKPoint[]
    for point in native.kpoints
        push!(
            points,
            PlaneWaveKPoint(
                point.k_fractional,
                point.g_vectors,
                point.coefficients[selected, :, :],
                point.energies_ev[selected];
                normalize_coefficients = false,
            ),
        )
    end
    return NativeWavefunctionData(
        native.source_code,
        native.structure,
        native.reciprocal_lattice,
        native.mp_grid,
        native.spinor,
        points,
        native.input_sha256,
        merge(native.source_metadata, Dict("nnkp_selected_bands" => join(selected, ","))),
    )
end

# One beta radial Fourier-Bessel transform, in QE's atomic-unit normalization.
function _qe_beta_radial_transform(
    dataset::QEUPFData,
    radial_index::Int,
    momentum_bohr_inverse::Float64,
    volume_bohr3::Float64,
)
    degree = dataset.beta_angular_momenta[radial_index]
    cutoff = dataset.beta_integration_cutoff_index
    integrand = Vector{Float64}(undef, cutoff)
    for index in 1:cutoff
        integrand[index] =
            dataset.beta_radial[index, radial_index] *
            _paw_spherical_bessel(degree, momentum_bohr_inverse * dataset.radial_grid_bohr[index]) *
            dataset.radial_grid_bohr[index]
    end
    return 4.0 * pi / sqrt(volume_bohr3) *
           _qe_upf_simpson(integrand, @view(dataset.radial_weights_bohr[1:cutoff]))
end

# Interpolate one cached beta transform on QE's fixed reciprocal radial grid.
function _qe_interpolated_beta_radial_transform(
    dataset::QEUPFData,
    atomic_type_label::String,
    radial_index::Int,
    momentum_bohr_inverse::Float64,
    volume_bohr3::Float64,
    radial_cache::Dict{Tuple{String, Int, Int}, Float64},
)
    return _qe_upf_cubic_interpolation(momentum_bohr_inverse) do grid_index
        get!(radial_cache, (atomic_type_label, radial_index, grid_index)) do
            _qe_beta_radial_transform(
                dataset,
                radial_index,
                grid_index * QE_UPF_RECIPROCAL_GRID_STEP,
                volume_bohr3,
            )
        end
    end
end

# Construct <G|beta_i,k> in deterministic QE type/atom/channel order.
function _qe_projector_basis(
    point::PlaneWaveKPoint,
    native,
    upf_data::Dict{String, QEUPFData},
    plan::QEProjectorPlan,
    radial_cache::Dict{Tuple{String, Int, Int}, Float64},
)
    fractional = Float64.(point.g_vectors) .+ reshape(point.k_fractional, 1, 3)
    cartesian_angstrom_inverse = fractional * native.reciprocal_lattice
    cartesian_bohr_inverse = BOHR_TO_ANGSTROM .* cartesian_angstrom_inverse
    magnitudes = vec(sqrt.(sum(abs2, cartesian_bohr_inverse; dims = 2)))
    maximum_degree =
        maximum(channel.angular_momentum for atom in plan.atoms for channel in atom.channels)
    harmonics = Dict(
        degree => _qe_real_spherical_harmonics(degree, cartesian_bohr_inverse) for
        degree in 0:maximum_degree
    )
    volume_bohr3 = abs(det(native.structure.lattice)) / BOHR_TO_ANGSTROM^3
    basis = zeros(ComplexF64, size(point.g_vectors, 1), plan.num_channels)
    for atom in plan.atoms
        dataset = upf_data[atom.atomic_type_label]
        for (local_channel, channel) in enumerate(atom.channels)
            global_channel = first(atom.channel_range) + local_channel - 1
            for plane_wave in eachindex(magnitudes)
                radial = _qe_interpolated_beta_radial_transform(
                    dataset,
                    atom.atomic_type_label,
                    channel.radial_index,
                    magnitudes[plane_wave],
                    volume_bohr3,
                    radial_cache,
                )
                phase =
                    cis(-2.0 * pi * dot(@view(fractional[plane_wave, :]), atom.position_fractional))
                basis[plane_wave, global_channel] =
                    radial *
                    harmonics[channel.angular_momentum][channel.harmonic_row, plane_wave] *
                    ((-im)^channel.angular_momentum) *
                    phase
            end
        end
    end
    return basis
end

# Construct one cacheable beta-overlap entry without retaining the much larger
# plane-wave projector basis.
function _qe_beta_overlap(
    point::PlaneWaveKPoint,
    native,
    upf_data::Dict{String, QEUPFData},
    plan::QEProjectorPlan,
    radial_cache::Dict{Tuple{String, Int, Int}, Float64},
)
    basis = _qe_projector_basis(point, native, upf_data, plan, radial_cache)
    values = zeros(
        ComplexF64,
        size(point.coefficients, 1),
        plan.num_channels,
        size(point.coefficients, 3),
    )
    for spin in axes(point.coefficients, 3)
        values[:, :, spin] .= @view(point.coefficients[:, :, spin]) * conj(basis)
    end
    return values, basis
end

# Store <beta_i,k|psi_n,k> as (band, expanded channel, spin component).
function _qe_beta_overlaps(
    native::NativeWavefunctionData,
    upf_data::Dict{String, QEUPFData},
    plan::QEProjectorPlan,
)
    radial_cache = Dict{Tuple{String, Int, Int}, Float64}()
    overlaps = Vector{Array{ComplexF64, 3}}(undef, length(native.kpoints))
    bases = Vector{Matrix{ComplexF64}}(undef, length(native.kpoints))
    for (kpoint, point) in enumerate(native.kpoints)
        values, basis = _qe_beta_overlap(point, native, upf_data, plan, radial_cache)
        bases[kpoint] = basis
        overlaps[kpoint] = values
    end
    return overlaps, bases
end

# Validate the assembled physical Gram matrix without changing its residual arithmetic.
function _qe_require_positive_band_metric(metric::AbstractMatrix)
    size(metric, 1) == size(metric, 2) && all(isfinite, metric) ||
        throw(ArgumentError("QE_PAW_METRIC_INVALID: band metric is nonsquare or nonfinite"))
    isapprox(metric, metric'; rtol = 128eps(Float64), atol = 128eps(Float64)) ||
        throw(ArgumentError("QE_PAW_METRIC_INVALID: band metric is not Hermitian"))
    all(>(0.0), eigvals(Hermitian(metric))) || throw(
        ArgumentError("QE_PAW_METRIC_NOT_POSITIVE: target band metric is not positive definite"),
    )
    return nothing
end

# Measure the unchanged identity residual after validating the physical metric.
function _qe_generalized_norm_residual_point(
    point::PlaneWaveKPoint,
    beta_overlap::Array{ComplexF64, 3},
    upf_data::Dict{String, QEUPFData},
    plan::QEProjectorPlan,
    spinorbit::Bool,
    cache,
)
    bands = size(point.coefficients, 1)
    overlap = zeros(ComplexF64, bands, bands)
    for spin in axes(point.coefficients, 3)
        coefficients = @view point.coefficients[:, :, spin]
        overlap .+= conj(coefficients) * transpose(coefficients)
    end
    zero_b = zeros(3)
    overlap .+= _qe_augmentation_block(
        beta_overlap,
        beta_overlap,
        upf_data,
        plan,
        zero_b,
        zero_b,
        spinorbit,
        cache,
    )
    _qe_require_positive_band_metric(overlap)
    overlap .-= Matrix{ComplexF64}(I, bands, bands)
    local_index = argmax(abs.(overlap))
    return abs(overlap[local_index]), local_index
end

# Scalar expanded-channel Q at q=0, using the UPF's authoritative PP_Q integrals.
function _qe_q0_scalar_matrix(dataset::QEUPFData, channels::Vector{QEProjectorChannel})
    output = zeros(ComplexF64, length(channels), length(channels))
    dataset.metric_kind == :norm_conserving && return output
    for (left, left_channel) in enumerate(channels), (right, right_channel) in enumerate(channels)
        left_channel.angular_momentum == right_channel.angular_momentum || continue
        left_channel.harmonic_row == right_channel.harmonic_row || continue
        output[left, right] =
            dataset.q_integrals[left_channel.radial_index, right_channel.radial_index]
    end
    return output
end

# Finite-b scalar Q in QE real-harmonic rows; PP_QIJL owns the radial functions.
function _qe_finite_b_scalar_matrix(
    dataset::QEUPFData,
    channels::Vector{QEProjectorChannel},
    b_cartesian_bohr_inverse::Vector{Float64},
)
    dataset.metric_kind == :norm_conserving &&
        return zeros(ComplexF64, length(channels), length(channels))
    magnitude = norm(b_cartesian_bohr_inverse)
    magnitude <= 1.0e-14 && return _qe_q0_scalar_matrix(dataset, channels)
    direction = reshape(b_cartesian_bohr_inverse ./ magnitude, 1, 3)
    maximum_degree = maximum(channel.angular_momentum for channel in channels)
    harmonics = Dict(
        degree => _qe_real_spherical_harmonics(degree, direction)[:, 1] for
        degree in 0:(2 * maximum_degree)
    )
    radial_cache = Dict{NTuple{4, Int}, Float64}()
    output = zeros(ComplexF64, length(channels), length(channels))
    for (left, left_channel) in enumerate(channels), (right, right_channel) in enumerate(channels)
        left_degree = left_channel.angular_momentum
        right_degree = right_channel.angular_momentum
        for degree in abs(left_degree - right_degree):(left_degree + right_degree)
            iseven(degree + left_degree + right_degree) || continue
            radial_key = (left_channel.radial_index, right_channel.radial_index, degree)
            haskey(dataset.q_radial_by_multipole, radial_key) || throw(
                ArgumentError(
                    "QE_UPF_DATA_REQUIRED: $(dataset.element) omits PP_QIJL $(radial_key)",
                ),
            )
            radial = _qe_upf_cubic_interpolation(magnitude) do grid_index
                cache_key = (radial_key..., grid_index)
                get!(radial_cache, cache_key) do
                    grid_momentum = grid_index * QE_UPF_RECIPROCAL_GRID_STEP
                    values = dataset.q_radial_by_multipole[radial_key]
                    integrand = similar(values)
                    for radial_index in eachindex(values)
                        integrand[radial_index] =
                            values[radial_index] * _paw_spherical_bessel(
                                degree,
                                grid_momentum * dataset.radial_grid_bohr[radial_index],
                            )
                    end
                    _qe_upf_simpson(integrand, dataset.radial_weights_bohr)
                end
            end
            for middle_row in 1:(2 * degree + 1)
                gaunt = _qe_real_gaunt(
                    left_degree,
                    left_channel.harmonic_row,
                    degree,
                    middle_row,
                    right_degree,
                    right_channel.harmonic_row,
                )
                gaunt == 0.0 && continue
                output[left, right] +=
                    4.0 * pi * ((-im)^degree) * harmonics[degree][middle_row] * gaunt * radial
            end
        end
    end
    return output
end

# Clebsch--Gordan coefficient used by the independent fully-relativistic transform.
function _qe_spinor_coefficient(degree::Int, total_j::Float64, m::Int, spin::Int)
    spin in (1, 2) || throw(ArgumentError("QE spinor index must be one or two"))
    -degree - 1 <= m <= degree || return 0.0
    denominator = inv(2.0 * degree + 1.0)
    if abs(total_j - degree - 0.5) < 1.0e-8
        return spin == 1 ? sqrt((degree + m + 1.0) * denominator) : sqrt((degree - m) * denominator)
    elseif abs(total_j - degree + 0.5) < 1.0e-8
        m < -degree + 1 && return 0.0
        return spin == 1 ? sqrt((degree - m + 1.0) * denominator) :
               -sqrt((degree + m) * denominator)
    end
    throw(ArgumentError("QE_UPF_DATA_REQUIRED: beta-channel j and l are incompatible"))
end

# Map a spinor channel to the scalar spherical-harmonic index used by the SOC transform.
function _qe_spherical_index(degree::Int, total_j::Float64, m::Int, spin::Int)
    value = if abs(total_j - degree - 0.5) < 1.0e-8
        spin == 1 ? m : m + 1
    elseif abs(total_j - degree + 0.5) < 1.0e-8
        m < -degree + 1 ? 0 : spin == 1 ? m - 1 : m
    else
        throw(ArgumentError("QE_UPF_DATA_REQUIRED: beta-channel j and l are incompatible"))
    end
    return -degree <= value <= degree ? value : 0
end

# Matrix element from one QE real harmonic row to one complex m harmonic.
function _qe_real_to_complex_rotation(degree::Int, complex_m::Int, real_row::Int)
    real_row == 1 && return complex_m == 0 ? 1.0 + 0.0im : 0.0 + 0.0im
    order = fld(real_row, 2)
    abs(complex_m) == order || return 0.0 + 0.0im
    if iseven(real_row)
        return complex_m < 0 ? (-1.0)^order / sqrt(2.0) : inv(sqrt(2.0))
    end
    return complex_m < 0 ? -im * (-1.0)^order / sqrt(2.0) : im / sqrt(2.0)
end

# Build the fcoef tensor from UPF j,l and QE's real-to-complex harmonic rotation.
function _qe_soc_fcoef(dataset::QEUPFData, channels::Vector{QEProjectorChannel})
    count = length(channels)
    output = zeros(ComplexF64, count, count, 2, 2)
    for (left, left_channel) in enumerate(channels), (right, right_channel) in enumerate(channels)
        left_channel.radial_index == right_channel.radial_index || continue
        degree = left_channel.angular_momentum
        degree == right_channel.angular_momentum || continue
        total_j = dataset.beta_total_angular_momenta[left_channel.radial_index]
        right_j = dataset.beta_total_angular_momenta[right_channel.radial_index]
        abs(total_j - right_j) < 1.0e-8 || continue
        for spin_left in 1:2, spin_right in 1:2
            coefficient = 0.0 + 0.0im
            for m in (-degree - 1):degree
                first_index = _qe_spherical_index(degree, total_j, m, spin_left)
                second_index = _qe_spherical_index(degree, total_j, m, spin_right)
                coefficient +=
                    _qe_real_to_complex_rotation(degree, first_index, left_channel.harmonic_row) *
                    _qe_spinor_coefficient(degree, total_j, m, spin_left) *
                    conj(
                        _qe_real_to_complex_rotation(
                            degree,
                            second_index,
                            right_channel.harmonic_row,
                        ),
                    ) *
                    _qe_spinor_coefficient(degree, total_j, m, spin_right)
            end
            output[left, right, spin_left, spin_right] = coefficient
        end
    end
    return output
end

# Transform one scalar expanded-channel Q matrix to explicit spin channels.
function _qe_spin_augmentation_matrix(
    scalar::Matrix{ComplexF64},
    dataset::QEUPFData,
    channels::Vector{QEProjectorChannel},
    spin_components::Int,
    spinorbit::Bool,
)
    output = zeros(ComplexF64, size(scalar, 1), size(scalar, 2), spin_components, spin_components)
    spin_components == 1 && return begin
        output[:, :, 1, 1] .= scalar
        output
    end
    if spinorbit && dataset.has_so
        fcoef = _qe_soc_fcoef(dataset, channels)
        for spin_left in 1:2, spin_right in 1:2, intermediate_spin in 1:2
            output[:, :, spin_left, spin_right] .+=
                @view(fcoef[:, :, spin_left, intermediate_spin]) *
                scalar *
                @view(fcoef[:, :, intermediate_spin, spin_right])
        end
    else
        output[:, :, 1, 1] .= scalar
        output[:, :, 2, 2] .= scalar
    end
    return output
end

# Contract beta overlaps against a q-dependent atomic augmentation metric.
function _qe_augmentation_block(
    left_overlaps::Array{ComplexF64, 3},
    right_overlaps::Array{ComplexF64, 3},
    upf_data::Dict{String, QEUPFData},
    plan::QEProjectorPlan,
    b_fractional::Vector{Float64},
    b_cartesian_bohr_inverse::Vector{Float64},
    spinorbit::Bool,
    finite_b_cache::Dict{Tuple{String, NTuple{3, Float64}, Int, Bool}, Array{ComplexF64, 4}},
)
    left_states = size(left_overlaps, 1)
    right_states = size(right_overlaps, 1)
    spin_components = size(left_overlaps, 3)
    size(right_overlaps, 3) == spin_components ||
        throw(ArgumentError("QE augmentation spin dimensions disagree"))
    output = zeros(ComplexF64, left_states, right_states)
    rounded_b = Tuple(round.(b_cartesian_bohr_inverse; digits = 13))
    for atom in plan.atoms
        dataset = upf_data[atom.atomic_type_label]
        dataset.metric_kind == :norm_conserving && continue
        metric =
            get!(finite_b_cache, (atom.atomic_type_label, rounded_b, spin_components, spinorbit)) do
                scalar =
                    _qe_finite_b_scalar_matrix(dataset, atom.channels, b_cartesian_bohr_inverse)
                _qe_spin_augmentation_matrix(
                    scalar,
                    dataset,
                    atom.channels,
                    spin_components,
                    spinorbit,
                )
            end
        phase = cis(-2.0 * pi * dot(b_fractional, atom.position_fractional))
        for spin_left in 1:spin_components, spin_right in 1:spin_components
            left = @view left_overlaps[:, atom.channel_range, spin_left]
            right = @view right_overlaps[:, atom.channel_range, spin_right]
            output .+=
                phase .*
                (conj(left) * @view(metric[:, :, spin_left, spin_right]) * transpose(right))
        end
    end
    return output
end

# First mandatory numerical gate: <psi|S(q=0)|psi> must be the identity.
function _qe_generalized_norm_residual(
    native::NativeWavefunctionData,
    overlaps::Vector{Array{ComplexF64, 3}},
    upf_data::Dict{String, QEUPFData},
    plan::QEProjectorPlan,
    spinorbit::Bool,
)
    maximum_residual = 0.0
    worst = (0, 0, 0)
    zero_b = zeros(3)
    cache = Dict{Tuple{String, NTuple{3, Float64}, Int, Bool}, Array{ComplexF64, 4}}()
    for (kpoint, point) in enumerate(native.kpoints)
        value, local_index = _qe_generalized_norm_residual_point(
            point,
            overlaps[kpoint],
            upf_data,
            plan,
            spinorbit,
            cache,
        )
        if value > maximum_residual
            maximum_residual = value
            worst = (kpoint, local_index[1], local_index[2])
        end
    end
    return maximum_residual, worst
end

# Complete pseudo plus finite-b augmentation MMN in NNKP order.
function _qe_generate_mmn(
    native::NativeWavefunctionData,
    nnkp::WannierNNKP,
    overlaps::Vector{Array{ComplexF64, 3}},
    upf_data::Dict{String, QEUPFData},
    plan::QEProjectorPlan,
    spinorbit::Bool,
)
    bands = size(first(native.kpoints).coefficients, 1)
    num_kpoints = length(native.kpoints)
    num_neighbors = size(nnkp.neighbors, 1)
    data = zeros(ComplexF64, bands, bands, num_neighbors, num_kpoints)
    finite_b_cache = Dict{Tuple{String, NTuple{3, Float64}, Int, Bool}, Array{ComplexF64, 4}}()
    pseudo_maximum = 0.0
    augmentation_maximum = 0.0
    for kpoint in 1:num_kpoints, neighbor_index in 1:num_neighbors
        right_index = nnkp.neighbors[neighbor_index, kpoint]
        shift = Tuple(nnkp.reciprocal_shifts[:, neighbor_index, kpoint])
        left = native.kpoints[kpoint]
        right = native.kpoints[right_index]
        b_fractional = right.k_fractional .+ collect(shift) .- left.k_fractional
        b_cartesian_bohr_inverse =
            BOHR_TO_ANGSTROM .* (transpose(native.reciprocal_lattice) * b_fractional)
        pseudo = _paw_pseudo_mmn_block(left, right, shift)
        augmentation = _qe_augmentation_block(
            overlaps[kpoint],
            overlaps[right_index],
            upf_data,
            plan,
            b_fractional,
            b_cartesian_bohr_inverse,
            spinorbit,
            finite_b_cache,
        )
        data[:, :, neighbor_index, kpoint] .= pseudo .+ augmentation
        pseudo_maximum = max(pseudo_maximum, maximum(abs, pseudo))
        augmentation_maximum = max(augmentation_maximum, maximum(abs, augmentation))
    end
    return WannierMMN(
        bands,
        num_kpoints,
        num_neighbors,
        data,
        copy(nnkp.neighbors),
        copy(nnkp.reciprocal_shifts),
    ),
    Dict(
        "pseudo_max_absolute" => pseudo_maximum,
        "augmentation_max_absolute" => augmentation_maximum,
    )
end

# Ordered base-orbital expansion for every Wannier90 NNKP angular code.
function _qe_nnkp_orbital_terms(code::Int, index::Int)
    s = (0, 1)
    pz, px, py = (1, 1), (1, 2), (1, 3)
    dz2, dx2my2 = (2, 1), (2, 4)
    root2, root3, root6, root12 = sqrt.((2.0, 3.0, 6.0, 12.0))
    code >= 0 && return [(code, index, 1.0)]
    tables = Dict{Int, Vector{Vector{Tuple{Int, Int, Float64}}}}(
        -1 => [
            [(s..., inv(root2)), (px..., inv(root2))],
            [(s..., inv(root2)), (px..., -inv(root2))],
        ],
        -2 => [
            [(s..., inv(root3)), (px..., -inv(root6)), (py..., inv(root2))],
            [(s..., inv(root3)), (px..., -inv(root6)), (py..., -inv(root2))],
            [(s..., inv(root3)), (px..., 2.0 / root6)],
        ],
        -3 => [
            [(s..., 0.5), (px..., 0.5), (py..., 0.5), (pz..., 0.5)],
            [(s..., 0.5), (px..., 0.5), (py..., -0.5), (pz..., -0.5)],
            [(s..., 0.5), (px..., -0.5), (py..., 0.5), (pz..., -0.5)],
            [(s..., 0.5), (px..., -0.5), (py..., -0.5), (pz..., 0.5)],
        ],
        -4 => [
            [(s..., inv(root3)), (px..., -inv(root6)), (py..., inv(root2))],
            [(s..., inv(root3)), (px..., -inv(root6)), (py..., -inv(root2))],
            [(s..., inv(root3)), (px..., 2.0 / root6)],
            [(pz..., inv(root2)), (dz2..., inv(root2))],
            [(pz..., -inv(root2)), (dz2..., inv(root2))],
        ],
        -5 => [
            [(s..., inv(root6)), (px..., -inv(root2)), (dz2..., -inv(root12)), (dx2my2..., 0.5)],
            [(s..., inv(root6)), (px..., inv(root2)), (dz2..., -inv(root12)), (dx2my2..., 0.5)],
            [(s..., inv(root6)), (py..., -inv(root2)), (dz2..., -inv(root12)), (dx2my2..., -0.5)],
            [(s..., inv(root6)), (py..., inv(root2)), (dz2..., -inv(root12)), (dx2my2..., -0.5)],
            [(s..., inv(root6)), (pz..., -inv(root2)), (dz2..., inv(root3))],
            [(s..., inv(root6)), (pz..., inv(root2)), (dz2..., inv(root3))],
        ],
    )
    haskey(tables, code) ||
        throw(ArgumentError("QE_NNKP_PROJECTION_UNSUPPORTED: angular code $(code)"))
    return tables[code][index]
end

# QE/Wannier90 hydrogenic radial transform, with no per-k trial normalization.
function _qe_trial_radial_transform(
    radial_index::Int,
    alpha_bohr_inverse::Float64,
    degree::Int,
    momentum_bohr_inverse::Float64,
    volume_bohr3::Float64,
)
    xmin = -6.0
    step = 0.025
    radial_maximum = 10.0
    count = round(Int, (log(radial_maximum) - xmin) / step + 1.0)
    radial_grid = [exp(xmin + (index - 1) * step) / alpha_bohr_inverse for index in 1:count]
    weights = step .* radial_grid
    radial = if radial_index == 1
        2.0 .* alpha_bohr_inverse^(3.0 / 2.0) .* exp.(-alpha_bohr_inverse .* radial_grid)
    elseif radial_index == 2
        inv(sqrt(8.0)) .* alpha_bohr_inverse^(3.0 / 2.0) .* (2.0 .- alpha_bohr_inverse .* radial_grid) .*
        exp.(-0.5 .* alpha_bohr_inverse .* radial_grid)
    elseif radial_index == 3
        sqrt(4.0 / 27.0) .* alpha_bohr_inverse^(3.0 / 2.0) .* (
            1.0 .- (2.0 / 3.0) .* alpha_bohr_inverse .* radial_grid .+
            (2.0 / 27.0) .* (alpha_bohr_inverse .* radial_grid) .^ 2
        ) .* exp.(-(alpha_bohr_inverse / 3.0) .* radial_grid)
    else
        throw(ArgumentError("QE_NNKP_PROJECTION_UNSUPPORTED: radial index $(radial_index)"))
    end
    integrand = similar(radial)
    for index in eachindex(integrand)
        integrand[index] =
            radial[index] *
            _paw_spherical_bessel(degree, momentum_bohr_inverse * radial_grid[index]) *
            radial_grid[index]^2
    end
    return 4.0 * pi / sqrt(volume_bohr3) * _qe_upf_simpson(integrand, weights)
end

# Normalized Pauli eigenspinor in the Cartesian-z basis.
function _qe_trial_spinor(projection)
    projection.spin_eigenvalue === nothing && return ComplexF64[1.0]
    axis = collect(something(projection.spin_axis_cartesian))
    axis ./= norm(axis)
    azimuth = atan(axis[2], axis[1])
    polar = acos(clamp(axis[3], -1.0, 1.0))
    if something(projection.spin_eigenvalue) == 1
        return ComplexF64[cos(polar / 2.0), cis(azimuth) * sin(polar / 2.0)]
    end
    return ComplexF64[-cis(-azimuth) * sin(polar / 2.0), cos(polar / 2.0)]
end

# Guiding functions from NNKP centers, axes, order, radial index, and spin axis.
function _qe_trial_matrix(
    point::PlaneWaveKPoint,
    native::NativeWavefunctionData,
    nnkp::WannierNNKP,
    radial_cache::Dict{Tuple{Int, UInt64, Int, UInt64}, Float64},
)
    fractional = Float64.(point.g_vectors) .+ reshape(point.k_fractional, 1, 3)
    cartesian_bohr_inverse = BOHR_TO_ANGSTROM .* (fractional * native.reciprocal_lattice)
    magnitudes = vec(sqrt.(sum(abs2, cartesian_bohr_inverse; dims = 2)))
    volume_bohr3 = abs(det(native.structure.lattice)) / BOHR_TO_ANGSTROM^3
    spin_components = size(point.coefficients, 3)
    trials = zeros(ComplexF64, size(point.g_vectors, 1), length(nnkp.projections), spin_components)
    for (wannier, projection) in enumerate(nnkp.projections)
        x_axis = collect(projection.x_axis_cartesian)
        z_axis = collect(projection.z_axis_cartesian)
        y_axis = cross(z_axis, x_axis)
        local_basis = reduce(vcat, (transpose(x_axis), transpose(y_axis), transpose(z_axis)))
        local_vectors = cartesian_bohr_inverse * transpose(local_basis)
        degrees = unique(
            first(term) for
            term in _qe_nnkp_orbital_terms(projection.angular_code, projection.angular_index)
        )
        harmonics = Dict(
            degree => _qe_wannier90_real_spherical_harmonics(degree, local_vectors) for
            degree in degrees
        )
        spinor = _qe_trial_spinor(projection)
        length(spinor) == spin_components ||
            throw(ArgumentError("QE_NNKP_SPIN_MISMATCH: projection spinor dimension differs"))
        for plane_wave in eachindex(magnitudes)
            orbital = 0.0 + 0.0im
            for (degree, row, coefficient) in
                _qe_nnkp_orbital_terms(projection.angular_code, projection.angular_index)
                key = (
                    projection.radial_index,
                    reinterpret(UInt64, projection.radial_scale),
                    degree,
                    reinterpret(UInt64, round(magnitudes[plane_wave]; digits = 13)),
                )
                radial = get!(radial_cache, key) do
                    _qe_trial_radial_transform(
                        projection.radial_index,
                        projection.radial_scale,
                        degree,
                        magnitudes[plane_wave],
                        volume_bohr3,
                    )
                end
                orbital +=
                    coefficient * harmonics[degree][row, plane_wave] * radial * ((-im)^degree)
            end
            phase =
                cis(-2.0 * pi * dot(@view(fractional[plane_wave, :]), projection.center_fractional))
            for spin in 1:spin_components
                trials[plane_wave, wannier, spin] = orbital * phase * spinor[spin]
            end
        end
    end
    return trials
end

# PAW/USPP-aware A_mn=<psi_m|S|g_n>, retaining NNKP's raw guiding-function scale.
function _qe_generate_amn(
    native::NativeWavefunctionData,
    nnkp::WannierNNKP,
    overlaps::Vector{Array{ComplexF64, 3}},
    projector_bases::Vector{Matrix{ComplexF64}},
    upf_data::Dict{String, QEUPFData},
    plan::QEProjectorPlan,
    spinorbit::Bool,
)
    bands = size(first(native.kpoints).coefficients, 1)
    num_wannier = length(nnkp.projections)
    data = zeros(ComplexF64, bands, num_wannier, length(native.kpoints))
    radial_cache = Dict{Tuple{Int, UInt64, Int, UInt64}, Float64}()
    pseudo_maximum = 0.0
    augmentation_maximum = 0.0
    zero_b = zeros(3)
    metric_cache = Dict{Tuple{String, NTuple{3, Float64}, Int, Bool}, Array{ComplexF64, 4}}()
    for (kpoint, point) in enumerate(native.kpoints)
        trials = _qe_trial_matrix(point, native, nnkp, radial_cache)
        pseudo = zeros(ComplexF64, bands, num_wannier)
        for spin in axes(point.coefficients, 3)
            pseudo .+= conj(@view(point.coefficients[:, :, spin])) * @view(trials[:, :, spin])
        end
        trial_overlaps =
            zeros(ComplexF64, num_wannier, plan.num_channels, size(point.coefficients, 3))
        basis = projector_bases[kpoint]
        for spin in axes(point.coefficients, 3)
            trial_overlaps[:, :, spin] .= transpose(@view(trials[:, :, spin])) * conj(basis)
        end
        augmentation = _qe_augmentation_block(
            overlaps[kpoint],
            trial_overlaps,
            upf_data,
            plan,
            zero_b,
            zero_b,
            spinorbit,
            metric_cache,
        )
        data[:, :, kpoint] .= pseudo .+ augmentation
        pseudo_maximum = max(pseudo_maximum, maximum(abs, pseudo))
        augmentation_maximum = max(augmentation_maximum, maximum(abs, augmentation))
    end
    return WannierAMN(bands, length(native.kpoints), num_wannier, data),
    Dict(
        "pseudo_max_absolute" => pseudo_maximum,
        "augmentation_max_absolute" => augmentation_maximum,
        "per_k_trial_normalization" => 0.0,
    )
end

# Convert the established array comparator to the public QE metric type.
function _qe_array_parity(generated::AbstractArray, oracle::AbstractArray)
    raw = _paw_array_parity(generated, oracle)
    return QEPAWArrayParityMetrics(
        raw.max_absolute,
        raw.root_mean_square,
        raw.relative_l2,
        raw.worst_index,
        raw.finite,
    )
end

# Compare a generated MMN against the formatted oracle without retaining a second array.
function _qe_mmn_streaming_parity(mmn::WannierMMN, oracle_file::AbstractString)
    raw = _paw_mmn_streaming_parity(mmn, oracle_file)
    return QEPAWArrayParityMetrics(
        raw.max_absolute,
        raw.root_mean_square,
        raw.relative_l2,
        raw.worst_index,
        raw.finite,
    )
end

# Apply the complete predeclared max, RMS, and relative-L2 parity contract.
function _qe_metric_passes(
    metric::QEPAWArrayParityMetrics,
    maximum_absolute::Float64,
    root_mean_square::Float64,
    relative_l2::Float64,
)
    return metric.finite &&
           metric.max_absolute <= maximum_absolute &&
           metric.root_mean_square <= root_mean_square &&
           metric.relative_l2 <= relative_l2
end

# Discover one explicit companion that binds black-box oracle files to source hashes.
function _qe_oracle_provenance_file(
    oracle_mmn_file::Union{Nothing, AbstractString},
    oracle_amn_file::Union{Nothing, AbstractString},
)
    supplied = String[]
    oracle_mmn_file === nothing || push!(supplied, abspath(something(oracle_mmn_file)))
    oracle_amn_file === nothing || push!(supplied, abspath(something(oracle_amn_file)))
    isempty(supplied) && return nothing
    length(unique(dirname.(supplied))) == 1 || return nothing
    candidates = String[joinpath(dirname(first(supplied)), "oracle_qe_paw.provenance.h5")]
    append!(candidates, splitext(filename)[1] * ".provenance.h5" for filename in supplied)
    unique!(candidates)
    existing = filter(isfile, candidates)
    return isempty(existing) ? nothing : first(existing)
end

# Verify every source hash recorded by the generator against the oracle companion.
function _qe_validate_oracle_provenance(
    filename::Union{Nothing, AbstractString},
    expected_hashes::Dict{String, String},
)
    filename === nothing && return false, "QE_ORACLE_PROVENANCE_MISSING"
    return try
        observed = HDF5.h5open(something(filename), "r") do handle
            attributes = HDF5.attributes(handle)
            schema = String(read(attributes["schema"]))
            version = String(read(attributes["schema_version"]))
            schema == QE_PAW_ORACLE_PROVENANCE_SCHEMA ||
                throw(ArgumentError("oracle provenance schema is $(schema)"))
            version == QE_PAW_ORACLE_PROVENANCE_SCHEMA_VERSION ||
                throw(ArgumentError("oracle provenance version is $(version)"))
            haskey(handle, "input_sha256") ||
                throw(ArgumentError("oracle provenance omits input_sha256"))
            read_string_dictionary(handle["input_sha256"])
        end
        for key in sort!(collect(keys(expected_hashes)))
            get(observed, key, "MISSING") == expected_hashes[key] ||
                return false, "QE_ORACLE_INPUT_HASH_MISMATCH:$(key)"
        end
        true, "PASS"
    catch error
        false, "QE_ORACLE_PROVENANCE_INVALID:$(sprint(showerror, error))"
    end
end

# Persist source, thresholds, formulas, components, and qualification evidence.
function _write_qe_paw_provenance(
    filename::AbstractString,
    result::QEPAWMatrixElementResult,
    thresholds::QEPAWParityThresholds,
    metadata,
    nnkp::WannierNNKP,
    upf_data::Dict{String, QEUPFData},
    plan::QEProjectorPlan,
    mmn_component_norms::Dict{String, Float64},
    amn_component_norms::Dict{String, Float64},
    oracle_provenance::Union{Nothing, AbstractString},
    require_oracle::Bool,
)
    HDF5.enable_complex_support()
    return atomic_hdf5_write(filename) do temporary
        HDF5.h5open(temporary, "w") do handle
            attributes = HDF5.attributes(handle)
            attributes["schema"] = QE_PAW_MATRIX_ELEMENT_SCHEMA
            attributes["schema_version"] = QE_PAW_MATRIX_ELEMENT_SCHEMA_VERSION
            attributes["passed"] = result.passed
            attributes["physical_overlap_available"] = result.physical_overlap_available
            attributes["oracle_required"] = require_oracle
            attributes["qualification_status"] = result.passed ? "PASS" : "FAIL"
            attributes["coefficient_normalization"] = "qe_raw"
            attributes["nnkp_authority"] = "k topology; reciprocal shifts; excluded bands; ordered projections; spin axis"
            attributes["beta_formula"] = "4pi/sqrt(Omega)*int beta_i(r) j_l(qr) r dr * Y_lm(qhat)*(-i)^l*exp(-i(k+G).tau)"
            attributes["finite_b_formula"] = "4pi*sum_LM (-i)^L Y_LM(bhat) Gaunt * int Q_ij^L(r) j_L(br) dr"
            attributes["soc_formula"] = "independent fcoef contraction equivalent to transform_qq_so"
            attributes["trial_normalization"] = "none_per_k"
            attributes["generalized_norm_max_absolute"] = result.generalized_norm_max_absolute
            attributes["amn_max_principal_angle_rad"] = result.amn_max_principal_angle_rad
            attributes["amn_projector_max_absolute"] = result.amn_projector_max_absolute
            attributes["qe_convention_reference"] = "https://gitlab.com/QEF/q-e/-/blob/ca08e747430dca8f4bf4e83abfc4d1391ffcb642/PP/src/pw2wannier90.f90"
            attributes["upflib_reference"] = "https://gitlab.com/QEF/q-e/-/blob/develop/upflib/README.md"
            attributes["qe_license_reference"] = "https://gitlab.com/QEF/q-e/-/blob/develop/License"
            attributes["oracle_provenance"] =
                oracle_provenance === nothing ? "NOT_PROVIDED" :
                abspath(something(oracle_provenance))
            input_group = HDF5.create_group(handle, "input_sha256")
            write_string_dictionary(input_group, result.input_sha256)
            threshold_group = HDF5.create_group(handle, "thresholds")
            for field in fieldnames(QEPAWParityThresholds)
                HDF5.attributes(threshold_group)[String(field)] = getfield(thresholds, field)
            end
            qualification_group = HDF5.create_group(handle, "qualification")
            function write_metric(name, value, threshold, applicable, reason)
                group = HDF5.create_group(qualification_group, name)
                metric_attributes = HDF5.attributes(group)
                metric_attributes["value"] = value
                metric_attributes["threshold"] = threshold
                metric_attributes["applicability"] = applicable
                metric_attributes["reason"] = reason
                metric_attributes["status"] =
                    !applicable ? "NOT_RUN" :
                    isfinite(value) && value <= threshold ? "PASS" : "FAIL"
                return nothing
            end
            write_metric(
                "generalized_norm_max_absolute",
                result.generalized_norm_max_absolute,
                thresholds.generalized_norm_max_absolute,
                true,
                "Q_ZERO_GENERALIZED_ORTHONORMALITY",
            )
            for (prefix, metric, maximum_threshold, rms_threshold, relative_threshold) in (
                (
                    "mmn",
                    result.mmn_parity,
                    thresholds.mmn_max_absolute,
                    thresholds.mmn_rms,
                    thresholds.mmn_relative_l2,
                ),
                (
                    "amn",
                    result.amn_parity,
                    thresholds.amn_max_absolute,
                    thresholds.amn_rms,
                    thresholds.amn_relative_l2,
                ),
            )
                applicable = metric !== nothing
                reason = applicable ? "ORACLE_PARITY" : "ORACLE_NOT_AVAILABLE"
                write_metric(
                    "$(prefix)_max_absolute",
                    applicable ? something(metric).max_absolute : NaN,
                    maximum_threshold,
                    applicable,
                    reason,
                )
                write_metric(
                    "$(prefix)_rms",
                    applicable ? something(metric).root_mean_square : NaN,
                    rms_threshold,
                    applicable,
                    reason,
                )
                write_metric(
                    "$(prefix)_relative_l2",
                    applicable ? something(metric).relative_l2 : NaN,
                    relative_threshold,
                    applicable,
                    reason,
                )
            end
            amn_subspace_applicable = result.amn_parity !== nothing
            write_metric(
                "amn_max_principal_angle_rad",
                result.amn_max_principal_angle_rad,
                thresholds.amn_max_principal_angle_rad,
                amn_subspace_applicable,
                amn_subspace_applicable ? "ORACLE_SUBSPACE" : "ORACLE_NOT_AVAILABLE",
            )
            write_metric(
                "amn_projector_max_absolute",
                result.amn_projector_max_absolute,
                thresholds.amn_projector_max_absolute,
                amn_subspace_applicable,
                amn_subspace_applicable ? "ORACLE_SUBSPACE" : "ORACLE_NOT_AVAILABLE",
            )
            topology_group = HDF5.create_group(handle, "nnkp")
            HDF5.attributes(topology_group)["source_sha256"] = nnkp.source_sha256
            HDF5.attributes(topology_group)["num_kpoints"] = size(nnkp.kpoints_fractional, 1)
            HDF5.attributes(topology_group)["num_neighbors"] = size(nnkp.neighbors, 1)
            HDF5.attributes(topology_group)["num_projections"] = length(nnkp.projections)
            topology_group["neighbors"] = nnkp.neighbors
            topology_group["reciprocal_shifts"] = nnkp.reciprocal_shifts
            topology_group["excluded_bands"] = nnkp.excluded_bands
            component_group = HDF5.create_group(handle, "component_norms")
            for (name, values) in (("mmn", mmn_component_norms), ("amn", amn_component_norms))
                group = HDF5.create_group(component_group, name)
                for key in sort!(collect(keys(values)))
                    HDF5.attributes(group)[key] = values[key]
                end
            end
            upf_group = HDF5.create_group(handle, "upf_contract")
            for label in sort!(collect(keys(upf_data)))
                dataset = upf_data[label]
                group = HDF5.create_group(upf_group, label)
                group_attributes = HDF5.attributes(group)
                group_attributes["element"] = dataset.element
                group_attributes["metric_kind"] = String(dataset.metric_kind)
                group_attributes["has_so"] = dataset.has_so
                group_attributes["fully_relativistic"] = dataset.fully_relativistic
                group_attributes["q_with_l"] = dataset.q_with_l
                group_attributes["beta_integration_cutoff_index"] =
                    dataset.beta_integration_cutoff_index
                group_attributes["augmentation_cutoff_index"] = dataset.augmentation_cutoff_index
            end
            channel_group = HDF5.create_group(handle, "projector_plan")
            HDF5.attributes(channel_group)["num_channels"] = plan.num_channels
            HDF5.attributes(channel_group)["has_augmentation"] = plan.has_augmentation
            HDF5.attributes(channel_group)["fully_relativistic"] = plan.fully_relativistic
            metric_group = HDF5.create_group(handle, "parity_metrics")
            for (name, metric) in (("mmn", result.mmn_parity), ("amn", result.amn_parity))
                metric === nothing && continue
                group = HDF5.create_group(metric_group, name)
                HDF5.attributes(group)["max_absolute"] = metric.max_absolute
                HDF5.attributes(group)["root_mean_square"] = metric.root_mean_square
                HDF5.attributes(group)["relative_l2"] = metric.relative_l2
                HDF5.attributes(group)["finite"] = metric.finite
                group["worst_index"] = metric.worst_index
            end
            handle["diagnostics"] = result.diagnostics
            HDF5.attributes(handle)["spinorbit"] = metadata.spinorbit
        end
    end
end

"""
Generate deterministic, augmentation-aware QE MMN and AMN matrices.

The NNKP file is the sole topology, band-exclusion, and projection authority.
Oracle matrices enter only after native construction and write/readback. A
missing or failed required oracle returns diagnostic artifacts with
`passed=false`; it never exposes a physical overlap to SAWF.
"""
function generate_qe_paw_matrix_elements(
    source::QuantumEspressoWavefunctionSource,
    nnkp_file::AbstractString;
    artifact_dir::AbstractString,
    oracle_mmn_file::Union{Nothing, AbstractString} = nothing,
    oracle_amn_file::Union{Nothing, AbstractString} = nothing,
    require_oracle::Bool = true,
    thresholds::QEPAWParityThresholds = QEPAWParityThresholds(),
)
    source.band_range === nothing ||
        throw(ArgumentError("QE_NNKP_BAND_AUTHORITY_REQUIRED: source.band_range must be nothing"))
    source.representation_cutoff_ev === nothing ||
        throw(ArgumentError("QE_PAW_RAW_COEFFICIENTS_REQUIRED: full cutoff is mandatory"))
    mkpath(artifact_dir)
    output_mmn = joinpath(artifact_dir, "native_qe_paw.mmn")
    output_amn = joinpath(artifact_dir, "native_qe_paw.amn")
    provenance_hdf5 = joinpath(artifact_dir, "native_qe_paw.provenance.h5")

    nnkp = read_wannier_nnkp(nnkp_file)
    metadata = read_qe_xml(source)
    raw_native = read_qe_raw_wavefunctions(source, metadata)
    _qe_validate_nnkp_contract(raw_native, nnkp)
    native = _qe_select_nnkp_bands(raw_native, nnkp)
    upf_data = Dict(
        label => read_qe_upf_data(path) for
        (label, path) in sort!(collect(metadata.upf_files); by = first)
    )
    plan = build_qe_projector_plan(metadata, upf_data)
    metadata.spinorbit &&
        !native.spinor &&
        throw(ArgumentError("QE_UPF_DATA_REQUIRED: spin-orbit calculation has scalar coefficients"))

    beta_overlaps, projector_bases = _qe_beta_overlaps(native, upf_data, plan)
    generalized_norm, generalized_norm_worst =
        _qe_generalized_norm_residual(native, beta_overlaps, upf_data, plan, metadata.spinorbit)
    amn, amn_components = _qe_generate_amn(
        native,
        nnkp,
        beta_overlaps,
        projector_bases,
        upf_data,
        plan,
        metadata.spinorbit,
    )
    mmn, mmn_components =
        _qe_generate_mmn(native, nnkp, beta_overlaps, upf_data, plan, metadata.spinorbit)

    mmn_path = write_wannier_mmn(
        output_mmn,
        mmn;
        comment = "Generated deterministically by WannierNLQG native QE PAW/USPP backend",
    )
    amn_path = write_wannier_amn(
        output_amn,
        amn;
        comment = "Generated deterministically by WannierNLQG native QE PAW/USPP backend",
    )
    restored_mmn = read_wannier_mmn(mmn_path)
    restored_amn = read_wannier_amn(amn_path)
    restored_mmn.neighbors == mmn.neighbors &&
    restored_mmn.reciprocal_shifts == mmn.reciprocal_shifts &&
    restored_mmn.data == mmn.data ||
        throw(ArgumentError("QE_NATIVE_WRITE_READBACK_FAILED: MMN differs after readback"))
    restored_amn.data == amn.data ||
        throw(ArgumentError("QE_NATIVE_WRITE_READBACK_FAILED: AMN differs after readback"))

    oracle_mmn_available = oracle_mmn_file !== nothing && isfile(something(oracle_mmn_file))
    oracle_amn_available = oracle_amn_file !== nothing && isfile(something(oracle_amn_file))
    input_hashes = merge(
        native.input_sha256,
        Dict(
            "NNKP" => nnkp.source_sha256,
            "ORACLE_MMN" =>
                oracle_mmn_file === nothing ? "NOT_PROVIDED" :
                oracle_mmn_available ? sha256_file(something(oracle_mmn_file)) : "MISSING",
            "ORACLE_AMN" =>
                oracle_amn_file === nothing ? "NOT_PROVIDED" :
                oracle_amn_available ? sha256_file(something(oracle_amn_file)) : "MISSING",
        ),
    )
    source_hashes = merge(native.input_sha256, Dict("NNKP" => nnkp.source_sha256))
    oracle_provenance = _qe_oracle_provenance_file(oracle_mmn_file, oracle_amn_file)
    provenance_pass, provenance_reason =
        _qe_validate_oracle_provenance(oracle_provenance, source_hashes)
    mmn_parity, mmn_oracle_reason = if oracle_mmn_file === nothing
        nothing, "NOT_PROVIDED"
    elseif !oracle_mmn_available
        nothing, "QE_ORACLE_MMN_MISSING"
    else
        try
            _qe_mmn_streaming_parity(mmn, something(oracle_mmn_file)), "PASS"
        catch error
            nothing, "QE_ORACLE_MMN_INVALID:$(sprint(showerror, error))"
        end
    end
    oracle_amn, amn_parity, amn_oracle_reason = if oracle_amn_file === nothing
        nothing, nothing, "NOT_PROVIDED"
    elseif !oracle_amn_available
        nothing, nothing, "QE_ORACLE_AMN_MISSING"
    else
        try
            restored_oracle = read_wannier_amn(something(oracle_amn_file))
            restored_oracle, _qe_array_parity(amn.data, restored_oracle.data), "PASS"
        catch error
            nothing, nothing, "QE_ORACLE_AMN_INVALID:$(sprint(showerror, error))"
        end
    end
    maximum_angle, maximum_projector, minimum_rank, worst_condition =
        oracle_amn === nothing ? (NaN, NaN, 0, NaN) : _paw_amn_subspace_metrics(amn, oracle_amn)

    norm_pass = generalized_norm <= thresholds.generalized_norm_max_absolute
    mmn_pass =
        mmn_parity !== nothing && _qe_metric_passes(
            something(mmn_parity),
            thresholds.mmn_max_absolute,
            thresholds.mmn_rms,
            thresholds.mmn_relative_l2,
        )
    amn_raw_pass =
        amn_parity !== nothing && _qe_metric_passes(
            something(amn_parity),
            thresholds.amn_max_absolute,
            thresholds.amn_rms,
            thresholds.amn_relative_l2,
        )
    amn_subspace_pass =
        isfinite(maximum_angle) &&
        isfinite(maximum_projector) &&
        maximum_angle <= thresholds.amn_max_principal_angle_rad &&
        maximum_projector <= thresholds.amn_projector_max_absolute &&
        minimum_rank == amn.num_wannier
    if !require_oracle
        provenance_pass =
            oracle_mmn_file === nothing && oracle_amn_file === nothing ? true : provenance_pass
        mmn_pass = oracle_mmn_file === nothing || mmn_pass
        amn_raw_pass = oracle_amn_file === nothing || amn_raw_pass
        amn_subspace_pass = oracle_amn_file === nothing || amn_subspace_pass
    end

    diagnostics = String[
        "generalized_norm_worst=$(generalized_norm_worst)",
        "amn_minimum_rank=$(minimum_rank)",
        "amn_worst_condition=$(worst_condition)",
        "oracle_provenance=$(provenance_reason)",
        "oracle_mmn=$(mmn_oracle_reason)",
        "oracle_amn=$(amn_oracle_reason)",
        "construction_order=q0_norm_then_amn_then_finite_b_mmn_then_oracle",
    ]
    norm_pass || push!(diagnostics, "QE_GENERALIZED_NORM_FAILED")
    provenance_pass || push!(diagnostics, "QE_ORACLE_INPUT_HASH_MISMATCH")
    require_oracle && oracle_mmn_file === nothing && push!(diagnostics, "QE_ORACLE_MMN_REQUIRED")
    require_oracle && oracle_amn_file === nothing && push!(diagnostics, "QE_ORACLE_AMN_REQUIRED")
    mmn_oracle_reason in ("PASS", "NOT_PROVIDED") || push!(diagnostics, mmn_oracle_reason)
    amn_oracle_reason in ("PASS", "NOT_PROVIDED") || push!(diagnostics, amn_oracle_reason)
    mmn_pass || push!(diagnostics, "QE_PAW_MMN_PARITY_FAILED")
    (amn_raw_pass && amn_subspace_pass) || push!(diagnostics, "QE_PAW_AMN_PARITY_FAILED")
    passed = norm_pass && provenance_pass && mmn_pass && amn_raw_pass && amn_subspace_pass
    artifacts = Dict(
        "mmn" => abspath(mmn_path),
        "amn" => abspath(amn_path),
        "provenance_hdf5" => abspath(provenance_hdf5),
    )
    oracle_provenance === nothing ||
        (artifacts["oracle_provenance_hdf5"] = abspath(something(oracle_provenance)))
    result = QEPAWMatrixElementResult(
        mmn,
        amn,
        mmn_parity,
        amn_parity,
        maximum_angle,
        maximum_projector,
        generalized_norm,
        passed,
        passed,
        diagnostics,
        artifacts,
        input_hashes,
    )
    _write_qe_paw_provenance(
        provenance_hdf5,
        result,
        thresholds,
        metadata,
        nnkp,
        upf_data,
        plan,
        mmn_components,
        amn_components,
        oracle_provenance,
        require_oracle,
    )
    return result
end
