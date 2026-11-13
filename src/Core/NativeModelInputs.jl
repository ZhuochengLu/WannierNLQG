"""A programmatic model definition independent of file formats and execution policy."""
abstract type AbstractNativeModelInput end

"""Validate optional local Pauli-normalized spin in a fixed point-orbital basis."""
function validate_point_orbital_operators(operators, centers)
    operators isa NamedTuple || throw(ArgumentError("operators must be a NamedTuple"))
    all(key -> key == :spin, keys(operators)) || throw(
        ArgumentError(
            "point-orbital inputs accept only operators.spin; position, overlaps and weighted operators are derived",
        ),
    )
    haskey(operators, :spin) || return nothing
    spin = operators.spin
    n = size(centers, 2)
    spin isa AbstractArray && size(spin) == (n, n, 3) ||
        throw(ArgumentError("operators.spin must be a constant N x N x 3 array"))
    all(isfinite, spin) || throw(ArgumentError("spin must be finite"))
    for a in 1:3
        matrix = spin[:, :, a]
        isapprox(matrix, matrix'; atol = 1e-11, rtol = 0) ||
            throw(ArgumentError("spin must be Hermitian"))
        for b in 1:3
            position = Diagonal(centers[b, :])
            maximum(abs, matrix * position - position * matrix) <= 1e-11 ||
                throw(ArgumentError("local spin must commute with every point-orbital position"))
        end
    end
    return nothing
end

"""
Validated native real-space input in the Convention-II, R-only Bloch representation.

Lattice rows and orbital positions use Angstrom, Hamiltonians use eV. All R blocks,
including Hermitian partners and the home cell, must be supplied. Arrays are copied.
Only `position_model=:point_orbitals` is supported. Centers define the diagonal
position operator; optional local spin is supplied as a constant array.

A new physical 1x1/2x2 lattice selects the standard x/xy model profile. Supply
physical rows of R and centers only; each auxiliary reference direction is one
Angstrom and adds no physical momentum axis. Existing 3x3 inputs stay unchanged.
"""
struct RealSpaceTBInput{M, O, P} <: AbstractNativeModelInput
    model::M
    operators::O
    parameters::P
    source_file::String
    position_model::Symbol
    wannier_center_convention::String
    physical_dimension::Int
end

# Retain the original positional wrapper constructor for existing 3D inputs.
RealSpaceTBInput(model, operators, parameters, source_file, position_model, convention) =
    RealSpaceTBInput(model, operators, parameters, source_file, position_model, convention, 3)

# Keep explicitly parameterized old positional construction on its original 3D profile.
RealSpaceTBInput{M, O, P}(
    model,
    operators,
    parameters,
    source_file,
    position_model,
    convention,
) where {M, O, P} = RealSpaceTBInput{M, O, P}(
    model,
    operators,
    parameters,
    source_file,
    position_model,
    convention,
    3,
)

"""Reject nonfinite data and inconsistent R/-R adjoints without modifying the input."""
function validate_native_real_space(values, vectors; tolerance = 1e-11)
    all(isfinite, values) || throw(ArgumentError("native operator contains nonfinite values"))
    lookup = Dict(Tuple(vectors[:, i]) => i for i in axes(vectors, 2))
    length(lookup) == size(vectors, 2) || throw(ArgumentError("duplicate R vectors"))
    haskey(lookup, (0, 0, 0)) || throw(ArgumentError("home-cell R block is required"))
    for (r, i) in lookup
        j = get(lookup, map(-, r), 0)
        j > 0 || throw(ArgumentError("missing Hermitian partner for R=$r"))
        a = selectdim(values, ndims(values), i)
        b = selectdim(values, ndims(values), j)
        perm = (2, 1, ntuple(k -> k + 2, ndims(a) - 2)...)
        isapprox(a, conj.(permutedims(b, perm)); atol = tolerance, rtol = 0) ||
            throw(ArgumentError("R/-R Hermiticity mismatch at R=$r"))
    end
    return nothing
end

"""Construct a finite orthogonal hopping model with explicit position semantics."""
function RealSpaceTBInput(;
    lattice,
    r_vectors,
    hamiltonian_r,
    orbital_positions = nothing,
    position_r = nothing,
    position_model::Symbol = :point_orbitals,
    operators = NamedTuple(),
    parameters = NamedTuple(),
    source_file = "",
    wannier_center_convention = "Convention_II",
)
    lat, physical_dimension = complete_native_reference_lattice(lattice)
    physical_rv = Matrix{Int}(r_vectors)
    rv =
        pad_native_physical_rows(physical_rv, physical_dimension, size(physical_rv, 2), "r_vectors")
    h = Array{ComplexF64, 3}(hamiltonian_r)
    n = size(h, 1);
    nr = size(rv, 2)
    size(h) == (n, n, nr) && n > 0 || throw(DimensionMismatch("Hamiltonian shape"))
    position_model == :point_orbitals ||
        throw(ArgumentError("v1.2 supports only fixed orthogonal point orbitals"))
    tau =
        orbital_positions === nothing ? nothing :
        pad_native_physical_rows(
            Matrix{Float64}(orbital_positions),
            physical_dimension,
            n,
            "orbital_positions",
        )
    tau === nothing ||
        (size(tau) == (3, n) && all(isfinite, tau)) ||
        throw(DimensionMismatch("orbital_positions must be finite 3 x num_orbitals"))
    validate_native_real_space(h, rv)
    position_r === nothing || throw(ArgumentError("point_orbitals cannot override position_r"))
    tau === nothing && throw(ArgumentError("point_orbitals requires explicit orbital_positions"))
    validate_point_orbital_operators(operators, tau)
    pos = zeros(ComplexF64, n, n, 3, nr)
    home = only(findall(i -> all(iszero, rv[:, i]), 1:nr))
    for a in 1:3, i in 1:n
        pos[i, i, a, home] = tau[a, i]
    end
    validate_native_real_space(pos, rv)
    wannier_center_convention in ("Convention_I", "Convention_II") ||
        throw(ArgumentError("invalid Wannier center convention"))
    # H was copied from the caller and r was created here. Transfer these private
    # arrays to the model instead of making a second full scientific payload copy.
    model = TightBindingModel(
        lat,
        n,
        nr,
        ones(Int, nr),
        rv,
        h,
        pos;
        copy_data = false,
        _position_model = :point_orbitals,
    )
    return RealSpaceTBInput(
        model,
        deepcopy(operators),
        deepcopy(parameters),
        String(source_file),
        position_model,
        String(wannier_center_convention),
        physical_dimension,
    )
end

"""
Analytic Hamiltonian and operator callbacks in a fixed orthogonal finite basis.

Callbacks accept `(k_cartesian, parameters)` and return matrices with orbital axes
first. k is in inverse Angstrom; H is in eV. Position and spin trailing axes are
Cartesian. Derivative callbacks have one additional trailing Cartesian axis per
order. Callbacks must be pure and accept generic real input for automatic differentiation.
`basis=:point_orbitals` requires explicit centers. `basis=:fixed_orthonormal`
declares one k-independent orthonormal finite basis (including a fixed plane-wave
expansion): its basis connection is zero and its cross-point basis overlap is
identity. It has no orbital-position claim and uses Convention II only. Neither
basis permits arbitrary position/overlap callbacks. `basis=:explicit` instead
declares the supplied smooth position connection; it is not inferred from orbital
centers. Its derivative callbacks may be supplied through third order. This local
connection declaration does not provide a cross-point overlap or qualify loop
observables. Optional spin is constant.

For a new 1x1/2x2 physical lattice, callbacks receive only d Cartesian coordinates
and supplied Cartesian derivative/connection slots have length d. The typed
adapter completes reference axes at one Angstrom without extra sampling. Old
3x3 callbacks continue to receive three coordinates. Spin keeps three components.
"""
struct AnalyticKInput{H, D, O, P} <: AbstractNativeModelInput
    hamiltonian::H
    derivatives::D
    operators::O
    parameters::P
    lattice::Matrix{Float64}
    orbital_positions::Union{Nothing, Matrix{Float64}}
    num_orbitals::Int
    periodic::Bool
    basis::Symbol
    derivative_method::Symbol
    finite_difference_step::Float64
    evaluation_bounds::Union{
        Nothing,
        Tuple{NTuple{1, Float64}, NTuple{1, Float64}},
        Tuple{NTuple{2, Float64}, NTuple{2, Float64}},
        Tuple{NTuple{3, Float64}, NTuple{3, Float64}},
    }
    source_file::String
    wannier_center_convention::String
    data_owner::ScientificDataOwner
    physical_dimension::Int
end

# Retain the existing complete positional construction as a three-coordinate input.
AnalyticKInput(
    h,
    derivatives,
    operators,
    parameters,
    lattice,
    centers,
    n,
    periodic,
    basis,
    method,
    step,
    bounds,
    source_file,
    convention,
    owner,
) = AnalyticKInput(
    h,
    derivatives,
    operators,
    parameters,
    lattice,
    centers,
    n,
    periodic,
    basis,
    method,
    step,
    bounds,
    source_file,
    convention,
    owner,
    3,
)

# Preserve the original explicitly parameterized complete constructor as well.
AnalyticKInput{H, D, O, P}(
    h,
    derivatives,
    operators,
    parameters,
    lattice,
    centers,
    n,
    periodic,
    basis,
    method,
    step,
    bounds,
    source_file,
    convention,
    owner,
) where {H, D, O, P} = AnalyticKInput{H, D, O, P}(
    h,
    derivatives,
    operators,
    parameters,
    lattice,
    centers,
    n,
    periodic,
    basis,
    method,
    step,
    bounds,
    source_file,
    convention,
    owner,
    3,
)

# Only the fixed orthonormal basis permits omitted centers. A private marker
# preserves the required-keyword error for the existing point-orbital API while
# distinguishing omission from an explicitly invalid `nothing` value.
struct UnspecifiedOrbitalPositions end
const UNSPECIFIED_ORBITAL_POSITIONS = UnspecifiedOrbitalPositions()

"""Validate an analytic model declaration without differentiating or reading source files."""
function AnalyticKInput(;
    hamiltonian,
    num_orbitals::Integer,
    lattice,
    orbital_positions = UNSPECIFIED_ORBITAL_POSITIONS,
    derivatives = (nothing, nothing, nothing),
    operators = NamedTuple(),
    parameters = NamedTuple(),
    periodic::Bool = true,
    basis::Symbol = :point_orbitals,
    derivative_method::Symbol = :automatic,
    finite_difference_step::Real = 1e-3,
    evaluation_bounds = nothing,
    source_file = "",
    wannier_center_convention = "Convention_II",
)
    if orbital_positions === UNSPECIFIED_ORBITAL_POSITIONS
        basis == :point_orbitals && throw(UndefKeywordError(:orbital_positions))
        orbital_positions = nothing
    end
    num_orbitals isa Bool && throw(ArgumentError("num_orbitals must be a positive integer"))
    n=Int(num_orbitals)
    n>0 || throw(ArgumentError("num_orbitals must be positive"))
    lat, physical_dimension = complete_native_reference_lattice(lattice)
    tau=orbital_positions === nothing ? nothing :
        pad_native_physical_rows(
        Matrix{Float64}(orbital_positions),
        physical_dimension,
        n,
        "orbital_positions",
    )
    basis in (:point_orbitals, :fixed_orthonormal, :explicit) || throw(
        ArgumentError(
            "supported analytic bases are point_orbitals, fixed_orthonormal and explicit",
        ),
    )
    if basis == :point_orbitals
        tau !== nothing && size(tau)==(3, n) && all(isfinite, tau) ||
            throw(ArgumentError("point_orbitals requires finite 3 x num_orbitals positions"))
        validate_point_orbital_operators(operators, tau)
    elseif basis == :fixed_orthonormal
        tau === nothing ||
            throw(ArgumentError("fixed_orthonormal does not declare orbital positions"))
        wannier_center_convention == "Convention_II" || throw(
            ArgumentError(
                "fixed_orthonormal requires the center-free Convention_II representation",
            ),
        )
        # The connection is identically zero by this explicit basis contract.
        validate_point_orbital_operators(operators, zeros(3, n))
    else
        operators isa NamedTuple || throw(ArgumentError("operators must be a NamedTuple"))
        allowed = (
            :position,
            :position_derivative,
            :position_second_derivative,
            :position_third_derivative,
            :overlap,
            :derivative_overlap,
            :spin,
        )
        all(key -> key in allowed, keys(operators)) ||
            throw(ArgumentError("unsupported explicit-basis operator"))
        haskey(operators, :position) ||
            throw(ArgumentError("explicit connection requires an actual position callback"))
        tau === nothing ||
            (size(tau) == (3, n) && all(isfinite, tau)) ||
            throw(ArgumentError("invalid explicit-basis orbital positions"))
        wannier_center_convention == "Convention_I" &&
            tau === nothing &&
            throw(ArgumentError("Convention_I explicit basis requires declared orbital positions"))
        if haskey(operators, :spin)
            spin = operators.spin
            spin isa AbstractArray && size(spin) == (n, n, 3) && all(isfinite, spin) || throw(
                ArgumentError("explicit-basis spin must be a finite constant N x N x 3 array"),
            )
            all(
                isapprox(spin[:, :, axis], spin[:, :, axis]'; atol = 1e-11, rtol = 0) for
                axis in 1:3
            ) || throw(ArgumentError("explicit-basis spin must be Hermitian"))
        end
    end
    length(derivatives)==3 || throw(ArgumentError("provide three derivative slots"))
    derivative_method in (:automatic, :finite_difference, :explicit) ||
        throw(ArgumentError("unsupported derivative_method"))
    isfinite(finite_difference_step) && finite_difference_step>0 ||
        throw(ArgumentError("invalid difference step"))
    bounds =
        evaluation_bounds === nothing ? nothing :
        (Tuple(Float64.(evaluation_bounds[1])), Tuple(Float64.(evaluation_bounds[2])))
    if bounds !== nothing
        length(bounds[1])==length(bounds[2])==physical_dimension ||
            throw(ArgumentError("evaluation_bounds must have $physical_dimension physical axes"))
        all(isfinite, bounds[1]) && all(isfinite, bounds[2]) && all(bounds[1] .< bounds[2]) ||
            throw(ArgumentError("invalid evaluation bounds"))
    end
    periodic &&
        bounds !== nothing &&
        throw(ArgumentError("periodic models do not use evaluation_bounds"))
    wannier_center_convention in ("Convention_I", "Convention_II") ||
        throw(ArgumentError("invalid convention"))
    return AnalyticKInput(
        deepcopy(physical_analytic_callback(hamiltonian, Val(physical_dimension), Val(0))),
        deepcopy(
            Tuple(
                value === nothing ? nothing :
                physical_analytic_callback(value, Val(physical_dimension), Val(order)) for
                (order, value) in enumerate(derivatives)
            ),
        ),
        deepcopy(physical_analytic_operators(operators, Val(physical_dimension))),
        deepcopy(parameters),
        lat,
        tau,
        n,
        periodic,
        basis,
        derivative_method,
        Float64(finite_difference_step),
        bounds,
        String(source_file),
        String(wannier_center_convention),
        ScientificDataOwner(),
        physical_dimension,
    )
end

"""Runtime analytic model; zero real-space blocks means no Fourier representation exists."""
struct AnalyticKModel{I, D} <: AbstractResponseModel
    input::I
    lattice::Matrix{Float64}
    num_orbitals::Int
    num_r_vectors::Int
    evaluation_diagnostics::D
end

"""Use the analytic input's lifetime; callback evaluation does not fingerprint data."""
scientific_data_generation(model::AnalyticKModel) = scientific_data_generation(model.input)

"""Observe an adopted analytic definition and its private callback captures."""
scientific_data_generation(input::AnalyticKInput) = scientific_data_generation(input.data_owner)

"""Retire analytic parameters and callback captures before replacing the definition."""
invalidate_scientific_data!(input::AnalyticKInput) = invalidate_scientific_data!(input.data_owner)

"""Use the owning real-space model lifetime for its native input wrapper."""
scientific_data_generation(input::RealSpaceTBInput) = scientific_data_generation(input.model)

"""Retire a real-space input and the model shared by its derived plans."""
invalidate_scientific_data!(input::RealSpaceTBInput) = invalidate_scientific_data!(input.model)

# Physical dimension is constructor-derived only for the new direct model inputs.
native_physical_dimension(input) = 3
"""Read only constructor-derived physical dimension, independently of sampling."""
native_physical_dimension(input::Union{RealSpaceTBInput, AnalyticKInput}) = input.physical_dimension

"""Build an analytic runtime model without discretizing its Hamiltonian."""
AnalyticKModel(input::AnalyticKInput; evaluation_diagnostics = nothing) =
# A shared runtime specialization keeps user callback types at evaluation.
# Explicit parameterized and positional construction remain available.
    AnalyticKModel{AnalyticKInput, typeof(evaluation_diagnostics)}(
        input,
        copy(input.lattice),
        input.num_orbitals,
        0,
        evaluation_diagnostics,
    )
