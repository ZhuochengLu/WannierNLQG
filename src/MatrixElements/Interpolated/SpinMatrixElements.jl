"""
Maximum input/output Hermiticity residuals and input diagonal imaginary magnitude during SPN-to-Wannier rotation, in upstream spin units.
"""
struct SpinGaugeDiagnostics
    max_input_hermiticity_error::Float64
    max_output_hermiticity_error::Float64
    max_diagonal_imag_part::Float64
end

"""
Maximum absolute spin q-to-R-to-q reconstruction residual in the unconverted upstream spin unit.
"""
struct SpinTransformDiagnostics
    max_roundtrip_error::Float64
end

# Return the largest absolute entry of `mat - mat'`, without symmetrizing the input.
_max_hermiticity_error(matrix::AbstractMatrix{ComplexF64}) = maximum(abs, matrix .- matrix')

# Scan all spin components and k points for maximum Hermiticity and diagonal-imaginary residuals without modifying SPN data.
function _spn_input_diagnostics(spn::WannierSPN)
    max_herm = 0.0
    max_diag_imag = 0.0
    for kpoint_index in 1:spn.num_kpts, alpha in 1:3
        mat = @view spn.data[:, :, alpha, kpoint_index]
        max_herm = max(max_herm, _max_hermiticity_error(mat))
        @inbounds for n in 1:spn.num_bands
            max_diag_imag = max(max_diag_imag, abs(imag(mat[n, n])))
        end
    end
    return max_herm, max_diag_imag
end

"""
Rotate SPN matrices as `V' * S * V` using the CHK gauge; return `spin_q` and Hermiticity diagnostics.

Require matching band/k-point counts, optionally Hermitize outputs, and reject input/output residuals above `atol`. Upstream spin units are unchanged.
"""
function spn_to_wannier_gauge_q_diagnostics(
    spn::WannierSPN,
    chk::WannierCHK;
    hermitize::Bool = true,
    atol::Float64 = 1e-10,
)
    spn.num_bands == chk.num_bands ||
        error("SPN num_bands=$(spn.num_bands) does not match CHK num_bands=$(chk.num_bands).")
    spn.num_kpts == chk.num_kpts ||
        error("SPN num_kpts=$(spn.num_kpts) does not match CHK num_kpts=$(chk.num_kpts).")

    spin_q = zeros(ComplexF64, chk.num_orbitals, chk.num_orbitals, 3, chk.num_kpts)
    max_output_herm = 0.0
    @inbounds for kpoint_index in 1:chk.num_kpts
        gauge_matrix = @view chk.v_matrix[:, :, kpoint_index]
        for alpha in 1:3
            spin_matrix = @view spn.data[:, :, alpha, kpoint_index]
            output = @view spin_q[:, :, alpha, kpoint_index]
            mul!(output, gauge_matrix', spin_matrix * gauge_matrix)
            if hermitize
                output .= 0.5 .* (output .+ output')
            end
            max_output_herm = max(max_output_herm, _max_hermiticity_error(output))
        end
    end
    max_input_herm, max_diag_imag = _spn_input_diagnostics(spn)
    max_input_herm <= atol ||
        error("Input SPN Hermiticity error $(max_input_herm) exceeds atol=$(atol).")
    max_output_herm <= atol ||
        error("Wannier-gauge spin Hermiticity error $(max_output_herm) exceeds atol=$(atol).")
    return (
        spin_q = spin_q,
        diagnostics = SpinGaugeDiagnostics(max_input_herm, max_output_herm, max_diag_imag),
    )
end

"""
Return Wannier-gauge spin matrices `(wannier,wannier,Cartesian,kpoint)` after CHK rotation and Hermiticity checks.

Delegate to `spn_to_wannier_gauge_q_diagnostics`, retaining its optional Hermitization and absolute tolerance in upstream spin units.
"""
function spn_to_wannier_gauge_q(
    spn::WannierSPN,
    chk::WannierCHK;
    hermitize::Bool = true,
    atol::Float64 = 1e-10,
)
    return spn_to_wannier_gauge_q_diagnostics(spn, chk; hermitize = hermitize, atol = atol).spin_q
end

"""
Fourier-transform Wannier-gauge spin with `exp(-2pi*i*R.k)/Nk`; return real-space data and roundtrip residual.

Validate orbital/mesh dimensions and, when enabled, reject reconstruction error above `atol`; reconstruction includes R-degeneracy weights. Spin units are unchanged.
"""
function spin_q_to_r_diagnostics(
    spin_q::Array{ComplexF64, 4},
    chk::WannierCHK,
    model::TightBindingModel;
    atol::Float64 = 1e-8,
    check_roundtrip::Bool = true,
)
    size(spin_q) == (chk.num_orbitals, chk.num_orbitals, 3, chk.num_kpts) || error(
        "spin_q has size $(size(spin_q)); expected ($(chk.num_orbitals), $(chk.num_orbitals), 3, $(chk.num_kpts)).",
    )
    chk.num_orbitals == model.num_orbitals || error(
        "CHK num_orbitals=$(chk.num_orbitals) does not match TB num_orbitals=$(model.num_orbitals).",
    )
    chk.num_kpts == prod(chk.mp_grid) ||
        error("CHK k mesh is incomplete: num_kpts=$(chk.num_kpts), mp_grid=$(chk.mp_grid).")

    spin_r = zeros(ComplexF64, model.num_orbitals, model.num_orbitals, 3, model.num_r_vectors)
    scale = 1.0 / chk.num_kpts
    @inbounds for r_vector_index in 1:model.num_r_vectors
        r_vector = @view model.r_vectors[:, r_vector_index]
        for kpoint_index in 1:chk.num_kpts
            kpoint = @view chk.kpt_red[kpoint_index, :]
            weighted_phase = scale * cis(-2.0 * pi * dot(r_vector, kpoint))
            for alpha in 1:3, n in 1:model.num_orbitals, m in 1:model.num_orbitals
                spin_r[n, m, alpha, r_vector_index] +=
                    weighted_phase * spin_q[n, m, alpha, kpoint_index]
            end
        end
    end

    real_space = SpinRealSpaceData(spin_r)
    max_roundtrip_error = 0.0
    if check_roundtrip
        spin_wannier = zeros(ComplexF64, model.num_orbitals, model.num_orbitals, 3)
        fourier_factors = zeros(ComplexF64, model.num_r_vectors)
        for kpoint_index in 1:chk.num_kpts
            kpoint = @view chk.kpt_red[kpoint_index, :]
            spin_r_to_wannier_gauge!(spin_wannier, real_space, model, kpoint, fourier_factors)
            reference_spin = @view spin_q[:, :, :, kpoint_index]
            max_roundtrip_error =
                max(max_roundtrip_error, maximum(abs, spin_wannier .- reference_spin))
        end
        max_roundtrip_error <= atol || error(
            "spin q->R->q round-trip error $(max_roundtrip_error) exceeds atol=$(atol). " *
            "The TB R-list/r_degeneracies may not be compatible with CHK mp_grid in this first implementation.",
        )
    end
    return (real_space = real_space, diagnostics = SpinTransformDiagnostics(max_roundtrip_error))
end

"""
Return only the real-space spin object from the normalized q-to-R transform.

Retain dimension checks and the optional absolute roundtrip gate from `spin_q_to_r_diagnostics`; upstream spin units are unchanged.
"""
function spin_q_to_r(
    spin_q::Array{ComplexF64, 4},
    chk::WannierCHK,
    model::TightBindingModel;
    atol::Float64 = 1e-8,
    check_roundtrip::Bool = true,
)
    return spin_q_to_r_diagnostics(
        spin_q,
        chk,
        model;
        atol = atol,
        check_roundtrip = check_roundtrip,
    ).real_space
end

# Sum selected real-space spin channels against weighted Fourier factors, optionally Hermitizing each output channel.
function _fourier_spin!(
    output::Array{ComplexF64, 3},
    real_space::SpinRealSpaceData,
    model::TightBindingModel,
    fourier_factors::Vector{ComplexF64},
    ;
    hermitize::Bool = true,
    plan::Union{Nothing, MatrixElementPlan} = nothing,
)
    spin_real_space = real_space.spin_r
    expected_size = (model.num_orbitals, model.num_orbitals, 3, model.num_r_vectors)
    size(spin_real_space) == expected_size || error(
        "spin_r size $(size(spin_real_space)) is incompatible with expected $(expected_size).",
    )
    for spin_direction in 1:3
        plan === nothing || _axis_required(plan, SPIN, spin_direction) || continue
        channel = plan === nothing ? spin_direction : _axis_channel(plan, SPIN, spin_direction)
        fill!(@view(output[:, :, channel]), COMPLEX_ZERO)
    end
    @inbounds for r_vector_index in 1:model.num_r_vectors
        fourier_factor = fourier_factors[r_vector_index]
        for spin_direction in 1:3
            plan === nothing || _axis_required(plan, SPIN, spin_direction) || continue
            channel = plan === nothing ? spin_direction : _axis_channel(plan, SPIN, spin_direction)
            for orbital_column in 1:model.num_orbitals
                for orbital_row in 1:model.num_orbitals
                    output[orbital_row, orbital_column, channel] +=
                        fourier_factor *
                        spin_real_space[orbital_row, orbital_column, spin_direction, r_vector_index]
                end
            end
        end
    end
    if hermitize
        _hermitize_spin!(output, plan; compact = plan !== nothing)
    end
    return output
end

# Replace each selected spin matrix by half its sum with its adjoint, respecting dense or compact channel indexing.
function _hermitize_spin!(
    spin::Array{ComplexF64, 3},
    plan::Union{Nothing, MatrixElementPlan} = nothing,
    ;
    compact::Bool = false,
)
    for spin_direction in 1:3
        plan === nothing || _axis_required(plan, SPIN, spin_direction) || continue
        channel = compact ? _axis_channel(plan, SPIN, spin_direction) : spin_direction
        @views spin[:, :, channel] .= 0.5 .* (spin[:, :, channel] .+ spin[:, :, channel]')
    end
    return spin
end

"""
Fill and return Wannier-gauge spin at fractional `kpoint` from R blocks, reusing `fourier_factors`.

Require one factor per R vector; include R degeneracies in the Fourier factors and Hermitize the resulting spin matrices without changing units.
"""
function spin_r_to_wannier_gauge!(
    output::Array{ComplexF64, 3},
    real_space::SpinRealSpaceData,
    model::TightBindingModel,
    kpoint::AbstractVector{<:Real},
    fourier_factors::Vector{ComplexF64},
)
    length(fourier_factors) == model.num_r_vectors || error(
        "fourier_factors length $(length(fourier_factors)) != num_r_vectors=$(model.num_r_vectors).",
    )
    _prepare_fourier_factors!(fourier_factors, model, kpoint)
    return _fourier_spin!(output, real_space, model, fourier_factors)
end

"""
Fill missing spin channels in Wannier and Hamiltonian gauges and update the SPIN cache mask/count.

Use the plan's Cartesian selection and center convention; defer Hermitization when spin velocity also requires the unmodified intermediate.
"""
function compute_spin_capabilities!(workspace::MatrixElementWorkspace, model::TightBindingModel)
    plan = workspace.plan
    has_capability(plan, SPIN) || return workspace.data
    data = workspace.data
    _has_capability(data.computed_mask, SPIN) && return data
    spin_data = data.spin
    spin_scratch = workspace.scratch.spin
    spin_velocity_requested = has_capability(plan, SPIN_VELOCITY)
    used_mixed =
        _shared_or_mixed_copy!(spin_scratch.wannier_gauge, workspace, model, Val(:SS), data.kpoint)
    if !used_mixed
        fourier_t0 = time_ns()
        _fourier_spin!(
            spin_scratch.wannier_gauge,
            workspace.sources.spin,
            model,
            workspace.scratch.fourier_factors,
            ;
            hermitize = false,
            plan = plan,
        )
        _record_direct_fourier!(workspace, (time_ns() - fourier_t0) * 1e-9)
    end
    _store_shared_fourier!(spin_scratch.wannier_gauge, workspace, model, :SS, data.kpoint)
    spin_velocity_requested || _hermitize_spin!(spin_scratch.wannier_gauge, plan; compact = true)
    for channel in axes(spin_scratch.wannier_gauge, 3)
        @views _apply_wannier_center_similarity!(
            spin_scratch.wannier_gauge[:, :, channel],
            workspace.scratch,
            plan,
        )
    end
    for spin_direction in 1:3
        _axis_required(plan, SPIN, spin_direction) || continue
        channel = _axis_channel(plan, SPIN, spin_direction)
        @views spin_data.wannier_gauge[:, :, spin_direction] .=
            spin_scratch.wannier_gauge[:, :, channel]
        @views transform_to_hamiltonian_gauge!(
            spin_data.hamiltonian_gauge[:, :, spin_direction],
            data.spectrum,
            spin_scratch.wannier_gauge[:, :, channel],
            workspace.scratch.matrix_temporary,
        )
    end
    if !spin_velocity_requested
        _hermitize_spin!(spin_data.hamiltonian_gauge, plan)
    end
    data.computed_mask |= _capability_bit(SPIN)
    workspace.counts.capability_computations[SPIN] += 1
    return data
end
