"""
Finite localized metric model with retained raw arrays and consistent effective H/S/r.

Lattice rows and position blocks use Angstrom; H uses eV and S is dimensionless.
R vectors are integer columns with explicit R/-R partners and a home cell.
Effective H/S use equal-weight Hermitian pair averages. For the fixed effective
S, position pairs are projected to r_R-r_-R'=(lattice'*R)S_R. These are explicit
in-memory model changes, not a rewrite of the original file or a joint weighted
least-squares fit. All Fourier matrices and their derivatives use these same
effective arrays. Raw/effective defects and adjustment norms remain available.
Absent position permits H/S-only work and never supplies zero positions.
Spin representation is explicit: `:spinless`, `:collinear` (two uncoupled
blocks), or `:spinor` (all states counted once, including spin mixing).
Spinful S/r must be a spin identity in the declared `:blocked` or `:interleaved`
ordering. No spin multiplicity is inferred from matrix size. Optional orbital
centers have shape (3,N) in Cartesian Angstrom in that same persisted ordering;
Convention I requires them and never infers them from position diagonals.
"""
struct NonorthogonalLocalizedModel <: AbstractResponseModel
    lattice::Matrix{Float64}
    num_orbitals::Int
    num_r_vectors::Int
    r_vectors::Matrix{Int}
    hamiltonian_r::Array{ComplexF64, 3}
    overlap_r::Array{ComplexF64, 3}
    position_r::Union{Nothing, Array{ComplexF64, 4}}
    metric_relative_floor::Float64
    hamiltonian_representation_tolerance_ev::Float64
    overlap_representation_tolerance::Float64
    position_translation_tolerance_angstrom::Float64
    raw_hamiltonian_r::Array{ComplexF64, 3}
    raw_overlap_r::Array{ComplexF64, 3}
    raw_position_r::Union{Nothing, Array{ComplexF64, 4}}
    representation_diagnostics::NamedTuple
    spin_representation::Symbol
    magnetic_state::Symbol
    spin_orbit_coupling::Bool
    spin_ordering::Symbol
    num_spatial_orbitals::Int
    orbital_centers_cartesian::Union{Nothing, Matrix{Float64}}
    data_owner::ScientificDataOwner
end

"""Return the two declared spin index lists without changing persisted orbital order."""
function _localized_spin_indices(n, ordering)
    ordering == :blocked && return (collect(1:(n ÷ 2)), collect((n ÷ 2 + 1):n))
    ordering == :interleaved && return (collect(1:2:n), collect(2:2:n))
    throw(ArgumentError("spinful localized ordering must be :blocked or :interleaved"))
end

"""Validate a declared representation; never discard spin mixing or supply a factor of two."""
function _validate_localized_spin(h, s, r, representation, magnetic_state, soc, ordering)
    representation in (:spinless, :collinear, :spinor) ||
        throw(ArgumentError("unsupported localized spin representation"))
    magnetic_state in (:nonmagnetic, :collinear, :noncollinear) ||
        throw(ArgumentError("unsupported declared magnetic state"))
    n = size(h, 1)
    if representation == :spinless
        magnetic_state == :nonmagnetic && !soc && ordering == :scalar || throw(
            ArgumentError("spinless representation requires nonmagnetic SOC-off scalar input"),
        )
        return n
    end
    iseven(n) || throw(DimensionMismatch("spinful localized states require two spin components"))
    up, down = _localized_spin_indices(n, ordering)
    for operator in (s, r)
        operator === nothing && continue
        # This is an operator-scope contract, not a residual quality gate. A
        # spin-dependent metric/position needs a future explicitly supported backend.
        tail = ntuple(_ -> Colon(), ndims(operator) - 2)
        all(iszero, operator[up, down, tail...]) &&
        all(iszero, operator[down, up, tail...]) &&
        operator[up, up, tail...] == operator[down, down, tail...] ||
            throw(ArgumentError("localized spinful S/r must be an explicit spin identity"))
    end
    if representation == :collinear
        magnetic_state in (:nonmagnetic, :collinear) && !soc || throw(
            ArgumentError("SOC or noncollinear magnetism requires a full spinor representation"),
        )
        all(iszero, h[up, down, :]) && all(iszero, h[down, up, :]) || throw(
            ArgumentError(
                "spin-mixing Hamiltonian requires :spinor; collinearity does not remove mixing",
            ),
        )
    end
    return n ÷ 2
end

"""Measure real-space partner defects using explicit operator units and norms."""
function _localized_partner_residuals(lattice, vectors, hamiltonian, overlap, position, lookup)
    h_frobenius = 0.0
    s_frobenius = 0.0
    h_maximum = 0.0
    s_maximum = 0.0
    r_maximum = position === nothing ? nothing : 0.0
    for (translation, index) in lookup
        partner = lookup[map(-, translation)]
        h_defect = hamiltonian[:, :, index] - hamiltonian[:, :, partner]'
        s_defect = overlap[:, :, index] - overlap[:, :, partner]'
        h_frobenius = max(h_frobenius, norm(h_defect))
        s_frobenius = max(s_frobenius, norm(s_defect))
        h_maximum = max(h_maximum, maximum(abs, h_defect))
        s_maximum = max(s_maximum, maximum(abs, s_defect))
        position === nothing && continue
        displacement = lattice' * vectors[:, index]
        for axis in 1:3
            defect =
                position[:, :, axis, index] - position[:, :, axis, partner]' -
                displacement[axis] * overlap[:, :, index]
            r_maximum = max(r_maximum, maximum(abs, defect))
        end
    end
    return (
        hamiltonian_frobenius_ev = h_frobenius,
        overlap_frobenius = s_frobenius,
        hamiltonian_max_entry_ev = h_maximum,
        overlap_max_entry = s_maximum,
        position_translation_max_entry_angstrom = r_maximum,
    )
end

"""Construct one consistent effective model, retaining raw input and measured changes."""
function NonorthogonalLocalizedModel(;
    lattice,
    r_vectors,
    hamiltonian_r,
    overlap_r,
    position_r,
    metric_relative_floor::Real = 1e-10,
    representation_tolerance::Real = 1e-10,
    hamiltonian_representation_tolerance_ev::Real = representation_tolerance,
    overlap_representation_tolerance::Real = representation_tolerance,
    position_translation_tolerance_angstrom::Real = representation_tolerance,
    spin_representation::Symbol = :spinless,
    magnetic_state::Symbol = :nonmagnetic,
    spin_orbit_coupling::Bool = false,
    spin_ordering::Symbol = spin_representation == :spinless ? :scalar : :blocked,
    orbital_centers_cartesian = nothing,
)
    lat = Matrix{Float64}(lattice)
    size(lat) == (3, 3) && all(isfinite, lat) && det(lat) > 0 || throw(
        ArgumentError("lattice must be finite, nonsingular and right handed with rows in Angstrom"),
    )
    rv = Matrix{Int}(r_vectors)
    size(rv, 1) == 3 || throw(DimensionMismatch("R vectors require three rows"))
    raw_h = copy(Array{ComplexF64, 3}(hamiltonian_r))
    raw_s = copy(Array{ComplexF64, 3}(overlap_r))
    raw_r = position_r === nothing ? nothing : copy(Array{ComplexF64, 4}(position_r))
    n, nr = size(raw_h, 1), size(rv, 2)
    n > 0 && nr > 0 && size(raw_h) == size(raw_s) == (n, n, nr) ||
        throw(DimensionMismatch("H and S must have shape (N,N,NR) with N,NR positive"))
    (raw_r === nothing || size(raw_r) == (n, n, 3, nr)) ||
        throw(DimensionMismatch("r must have shape (N,N,3,NR)"))
    all(isfinite, raw_h) && all(isfinite, raw_s) && (raw_r === nothing || all(isfinite, raw_r)) ||
        throw(ArgumentError("localized operators contain nonfinite values"))
    spatial_count = _validate_localized_spin(
        raw_h,
        raw_s,
        raw_r,
        spin_representation,
        magnetic_state,
        spin_orbit_coupling,
        spin_ordering,
    )
    centers =
        orbital_centers_cartesian === nothing ? nothing :
        copy(Matrix{Float64}(orbital_centers_cartesian))
    (centers === nothing || (size(centers) == (3, n) && all(isfinite, centers))) || throw(
        ArgumentError(
            "orbital_centers_cartesian must be finite Cartesian Angstrom with shape (3,N)",
        ),
    )
    if centers !== nothing && spin_representation != :spinless
        up, down = _localized_spin_indices(n, spin_ordering)
        centers[:, up] == centers[:, down] || throw(
            ArgumentError(
                "spin components of each localized spatial orbital require the same center",
            ),
        )
    end
    isfinite(metric_relative_floor) && 0 < metric_relative_floor < 1 ||
        throw(ArgumentError("metric_relative_floor must be finite and in (0,1)"))
    all(
        value -> isfinite(value) && value >= 0,
        (
            representation_tolerance,
            hamiltonian_representation_tolerance_ev,
            overlap_representation_tolerance,
            position_translation_tolerance_angstrom,
        ),
    ) || throw(ArgumentError("representation tolerances must be finite and nonnegative"))
    lookup = Dict(Tuple(rv[:, index]) => index for index in 1:nr)
    length(lookup) == nr || throw(ArgumentError("duplicate R vectors"))
    haskey(lookup, (0, 0, 0)) || throw(ArgumentError("home-cell R block is required"))
    all(haskey(lookup, map(-, translation)) for translation in keys(lookup)) ||
        throw(ArgumentError("missing R/-R partner"))
    h = copy(raw_h)
    s = copy(raw_s)
    pos = raw_r === nothing ? nothing : copy(raw_r)
    for (translation, index) in lookup
        partner = lookup[map(-, translation)]
        index <= partner || continue
        h_pair = raw_h[:, :, index] / 2 + raw_h[:, :, partner]' / 2
        s_pair = raw_s[:, :, index] / 2 + raw_s[:, :, partner]' / 2
        h[:, :, index] .= h_pair
        h[:, :, partner] .= h_pair'
        s[:, :, index] .= s_pair
        s[:, :, partner] .= s_pair'
        pos === nothing && continue
        displacement = lat' * rv[:, index]
        for axis in 1:3
            midpoint = raw_r[:, :, axis, index] / 2 + raw_r[:, :, axis, partner]' / 2
            shift = displacement[axis] / 2 * s_pair
            pos[:, :, axis, index] .= midpoint + shift
            pos[:, :, axis, partner] .= (midpoint - shift)'
        end
    end
    all(isfinite, h) && all(isfinite, s) && (pos === nothing || all(isfinite, pos)) ||
        throw(ArgumentError("effective operator construction overflowed"))
    raw_defects = _localized_partner_residuals(lat, rv, raw_h, raw_s, raw_r, lookup)
    effective_defects = _localized_partner_residuals(lat, rv, h, s, pos, lookup)
    h_tolerance = Float64(hamiltonian_representation_tolerance_ev)
    s_tolerance = Float64(overlap_representation_tolerance)
    r_tolerance = Float64(position_translation_tolerance_angstrom)
    adjustment = (
        hamiltonian_frobenius_ev = norm(h - raw_h),
        overlap_frobenius = norm(s - raw_s),
        position_frobenius_angstrom = pos === nothing ? nothing : norm(pos - raw_r),
        hamiltonian_max_entry_ev = maximum(abs, h - raw_h),
        overlap_max_entry = maximum(abs, s - raw_s),
        position_max_entry_angstrom = pos === nothing ? nothing : maximum(abs, pos - raw_r),
    )
    warning =
        raw_defects.hamiltonian_frobenius_ev > h_tolerance ||
        raw_defects.overlap_frobenius > s_tolerance ||
        (raw_r !== nothing && raw_defects.position_translation_max_entry_angstrom > r_tolerance)
    diagnostics = (
        scheme = "hermitian-pair-average; position equal-weight constrained projection for fixed effective overlap",
        raw = raw_defects,
        effective = effective_defects,
        adjustment,
        exceeds_reporting_tolerance = warning,
        raw_file_modified = false,
    )
    warning &&
        @warn "Localized input defects exceed reporting tolerances; calculations use the consistent effective operators and retain raw arrays" raw_defects adjustment
    return NonorthogonalLocalizedModel(
        lat,
        n,
        nr,
        rv,
        h,
        s,
        pos,
        Float64(metric_relative_floor),
        h_tolerance,
        s_tolerance,
        r_tolerance,
        raw_h,
        raw_s,
        raw_r,
        diagnostics,
        spin_representation,
        magnetic_state,
        spin_orbit_coupling,
        spin_ordering,
        spatial_count,
        centers,
        ScientificDataOwner(),
    )
end

"""Observe the lifetime shared by raw and adopted effective localized operators."""
scientific_data_generation(model::NonorthogonalLocalizedModel) =
    scientific_data_generation(model.data_owner)

"""Retire raw/effective operators together before constructing a replacement."""
invalidate_scientific_data!(model::NonorthogonalLocalizedModel) =
    invalidate_scientific_data!(model.data_owner)

"""
Programmatic nonorthogonal input with complete localized H/S/r and provenance.

Convention II is the compatibility default. Convention I requires explicit model
centers; both conventions use their native operators and the original D_eta.
Spin states are explicitly represented and counted once. Importers perform unit
and orbital-order conversion at the IO boundary, with declared upstream metadata.
"""
struct NonorthogonalLocalizedInput{P} <: AbstractNativeModelInput
    model::NonorthogonalLocalizedModel
    parameters::P
    operators::NamedTuple{(), Tuple{}}
    source_file::String
    wannier_center_convention::String
end

"""Use the lifetime of the adopted localized raw/effective model."""
scientific_data_generation(input::NonorthogonalLocalizedInput) =
    scientific_data_generation(input.model)

"""Retire the localized input before constructing a replacement."""
invalidate_scientific_data!(input::NonorthogonalLocalizedInput) =
    invalidate_scientific_data!(input.model)

"""Adopt an independent localized model without reprojecting its effective operators.

The default copies caller-owned model data once. An importer may transfer its
new private model with `copy_data=false`; that model must then remain read-only.
"""
function NonorthogonalLocalizedInput(
    model::NonorthogonalLocalizedModel;
    parameters = NamedTuple(),
    source_file = "",
    wannier_center_convention::AbstractString = "Convention_II",
    copy_data::Bool = true,
)
    scientific_data_generation(model)
    wannier_center_convention in ("Convention_I", "Convention_II") ||
        throw(ArgumentError("unsupported localized Bloch convention"))
    wannier_center_convention != "Convention_I" ||
        model.orbital_centers_cartesian !== nothing ||
        throw(ArgumentError("Convention I requires explicit localized orbital centers"))
    owned = if copy_data
        values = ntuple(i -> deepcopy(getfield(model, i)), fieldcount(NonorthogonalLocalizedModel) - 1)
        NonorthogonalLocalizedModel(values..., ScientificDataOwner())
    else
        model
    end
    return NonorthogonalLocalizedInput(
        owned,
        deepcopy(parameters),
        NamedTuple(),
        String(source_file),
        String(wannier_center_convention),
    )
end
