using ..Core: validate_native_real_space

"""Require a complete localized H/S/r closure; additional operator contracts are unsupported."""
function native_matrix_sources(input::NonorthogonalLocalizedInput, demand)
    all(kind -> kind in (REAL_SPACE_HAMILTONIAN, REAL_SPACE_POSITION), demand.required_operators) ||
        throw(ArgumentError("nonorthogonal input supports only localized H/S/r scalar tasks"))
    (input.model.position_r !== nothing || !(REAL_SPACE_POSITION in demand.required_operators)) ||
        throw(
            ArgumentError(
                "nonorthogonal task requires a position operator excluded by its declared input scope",
            ),
        )
    return MatrixElementSources()
end

"""An explicitly supplied analytic operator; callbacks remain concrete in model storage."""
struct AnalyticOperatorSource{I}
    input::I
end

"""Validate operator availability for the shared demand registry before numerical execution."""
function native_matrix_sources(input::RealSpaceTBInput, demand)
    m=input.model;
    n=m.num_orbitals;
    nr=m.num_r_vectors;
    ops=input.operators
    home=only(findall(i->all(iszero, m.r_vectors[:, i]), 1:nr))
    spin=nothing;
    velocity=nothing;
    overlap=nothing
    spin_requested=REAL_SPACE_SPIN in demand.required_operators
    if spin_requested
        if haskey(ops, :spin_r)
            s=Array{ComplexF64, 4}(ops.spin_r)
        elseif haskey(ops, :spin)
            size(ops.spin)==(n, n, 3) || throw(DimensionMismatch("onsite spin shape"))
            s=zeros(ComplexF64, n, n, 3, nr);
            s[:, :, :, home].=ops.spin
        else
            throw(ArgumentError("native spin response requires spin or spin_r"))
        end
        size(s)==(n, n, 3, nr) || throw(DimensionMismatch("spin_r shape"))
        validate_native_real_space(s, m.r_vectors)
        spin=SpinRealSpaceData(s)
    end
    needs_velocity=any(
        k->k in demand.required_operators,
        (
            REAL_SPACE_SPIN_TIMES_HAMILTONIAN,
            REAL_SPACE_SPIN_TIMES_POSITION,
            REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION,
        ),
    )
    if needs_velocity
        if all(
            k->haskey(ops, k),
            (:spin_hamiltonian_r, :spin_position_r, :spin_hamiltonian_position_r),
        )
            sh=Array{ComplexF64, 4}(ops.spin_hamiltonian_r)
            sr=Array{ComplexF64, 5}(ops.spin_position_r)
            shr=Array{ComplexF64, 5}(ops.spin_hamiltonian_position_r)
        elseif input.position_model==:point_orbitals && haskey(ops, :spin) && !haskey(ops, :spin_r)
            sh=zeros(ComplexF64, n, n, 3, nr);
            sr=zeros(ComplexF64, n, n, 3, 3, nr);
            shr=similar(sr)
            for r in 1:nr, a in 1:3
                sh[:, :, a, r].=ops.spin[:, :, a]*m.hamiltonian_r[:, :, r]
                for b in 1:3
                    t=m.position_r[:, :, b, home]
                    sr[:, :, b, a, r].=r==home ? ops.spin[:, :, a]*t : zeros(ComplexF64, n, n)
                    shr[:, :, b, a, r].=sh[:, :, a, r]*t
                end
            end
        else
            throw(ArgumentError("spin-weighted operators must be explicit for general embeddings"))
        end
        size(sh)==(n, n, 3, nr) && size(sr)==size(shr)==(n, n, 3, 3, nr) ||
            throw(DimensionMismatch("spin-weighted operator shape"))
        all(isfinite, sh) && all(isfinite, sr) && all(isfinite, shr) ||
            throw(ArgumentError("nonfinite spin-weighted operator"))
        velocity=SpinVelocityRealSpaceData(spin, sh, sr, shr, nothing)
    end
    if REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR in demand.required_operators
        if haskey(ops, :derivative_overlap_r)
            d=Array{ComplexF64, 5}(ops.derivative_overlap_r)
        elseif input.position_model==:point_orbitals
            d=zeros(ComplexF64, n, n, 3, 3, nr)
            for a in 1:3, b in 1:3
                d[:, :, a, b, home].=m.position_r[:, :, a, home]*m.position_r[:, :, b, home]
            end
        else
            throw(ArgumentError("explicit embedding requires derivative_overlap_r"))
        end
        size(d)==(n, n, 3, 3, nr) && all(isfinite, d) ||
            throw(ArgumentError("invalid derivative_overlap_r"))
        overlap=DerivativeOverlapRealSpaceData(d)
    end
    return MatrixElementSources(spin, velocity, overlap)
end

"""Validate analytic source closure, including cross-point data for general embeddings."""
function native_matrix_sources(input::AnalyticKInput, demand)
    validate_analytic_model(input)
    ops=input.operators
    if input.basis==:explicit
        haskey(ops, :position) ||
            throw(ArgumentError("explicit embedding requires position callback"))
        # Local curvature jets consume H/A only. A cross-point overlap is not
        # inferred or fabricated here; Runtime admits this new declaration only
        # to the explicitly supported BCD/BCQ ports.
    end
    spin=REAL_SPACE_SPIN in demand.required_operators
    spin && !haskey(ops, :spin) && throw(ArgumentError("analytic spin callback is required"))
    velocity=any(
        k->k in demand.required_operators,
        (
            REAL_SPACE_SPIN_TIMES_HAMILTONIAN,
            REAL_SPACE_SPIN_TIMES_POSITION,
            REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION,
        ),
    )
    overlap=REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR in demand.required_operators
    overlap &&
        input.basis == :fixed_orthonormal &&
        !haskey(ops, :derivative_overlap) &&
        throw(
            ArgumentError(
                "FULL_DERIVATIVE_OVERLAP_REQUIRED: fixed-basis declaration does not supply qualified full-F operators",
            ),
        )
    overlap &&
        input.basis==:explicit &&
        !haskey(ops, :derivative_overlap) &&
        throw(ArgumentError("explicit embedding requires derivative_overlap callback"))
    marker=AnalyticOperatorSource(input)
    return MatrixElementSources(
        spin ? marker : nothing,
        velocity ? marker : nothing,
        overlap ? marker : nothing,
    )
end
