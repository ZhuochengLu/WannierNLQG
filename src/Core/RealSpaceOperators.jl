"""Canonical identities of real-space Wannier operators stored in model bundles."""
@enum RealSpaceOperatorKind::UInt8 begin
    REAL_SPACE_HAMILTONIAN
    REAL_SPACE_POSITION
    REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION
    REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP
    REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR
    REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP
    REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP
    REAL_SPACE_SPIN
    REAL_SPACE_SPIN_TIMES_HAMILTONIAN
    REAL_SPACE_SPIN_TIMES_POSITION
    REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION
end

const REAL_SPACE_OPERATOR_REGISTRY = (
    REAL_SPACE_HAMILTONIAN,
    REAL_SPACE_POSITION,
    REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION,
    REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP,
    REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR,
    REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP,
    REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP,
    REAL_SPACE_SPIN,
    REAL_SPACE_SPIN_TIMES_HAMILTONIAN,
    REAL_SPACE_SPIN_TIMES_POSITION,
    REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION,
)

const REAL_SPACE_OPERATOR_CANONICAL_NAMES = Dict(
    REAL_SPACE_HAMILTONIAN => "hamiltonian",
    REAL_SPACE_POSITION => "position",
    REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION => "hamiltonian_weighted_connection",
    REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP => "hamiltonian_weighted_axial_derivative_overlap",
    REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR => "derivative_overlap_tensor",
    REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP => "axial_derivative_overlap",
    REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP => "symmetric_derivative_overlap",
    REAL_SPACE_SPIN => "spin",
    REAL_SPACE_SPIN_TIMES_HAMILTONIAN => "spin_times_hamiltonian",
    REAL_SPACE_SPIN_TIMES_POSITION => "spin_times_position",
    REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION => "spin_times_hamiltonian_position",
)

"""Return the schema-stable canonical string for an operator identity."""
function real_space_operator_name(kind::RealSpaceOperatorKind)
    return REAL_SPACE_OPERATOR_CANONICAL_NAMES[kind]
end

"""
Tensor transformation metadata for a real-space Wannier operator.

Cartesian axes are the trailing operator axes immediately before the real-space
axis. `inversion_parity` and `time_reversal_parity` specify the signs applied
when transforming a target-frame matrix element back to its source frame and
must each be `+1` or `-1`.
"""
struct RealSpaceOperatorSymmetrySpec
    kind::RealSpaceOperatorKind
    cartesian_rank::Int
    inversion_parity::Int
    time_reversal_parity::Int
    rotate_cartesian::Bool

    function RealSpaceOperatorSymmetrySpec(
        kind::RealSpaceOperatorKind,
        cartesian_rank,
        inversion_parity,
        time_reversal_parity;
        rotate_cartesian = true,
    )
        rank = Int(cartesian_rank)
        inversion = Int(inversion_parity)
        time_reversal = Int(time_reversal_parity)
        rank >= 0 || throw(ArgumentError("cartesian_rank must be nonnegative"))
        inversion in (-1, 1) || throw(ArgumentError("inversion_parity must be +1 or -1"))
        time_reversal in (-1, 1) || throw(ArgumentError("time_reversal_parity must be +1 or -1"))
        return new(kind, rank, inversion, time_reversal, Bool(rotate_cartesian))
    end
end

"""
Real-space Wannier operator with Julia-native real-space-last storage.

The array shape is `(num_wannier, num_wannier, 3..., num_r_vectors)`, with one
Cartesian axis per `spec.cartesian_rank`. Values are stored in the input Wannier
basis and no Hermitianization or degeneracy normalization is implied.
"""
struct RealSpaceOperator{N}
    spec::RealSpaceOperatorSymmetrySpec
    r_vectors::Matrix{Int}
    data::Array{ComplexF64, N}

    function RealSpaceOperator(spec::RealSpaceOperatorSymmetrySpec, r_vectors, data)
        vectors = Matrix{Int}(r_vectors)
        values = Array{ComplexF64}(data)
        size(vectors, 1) == 3 || throw(ArgumentError("r_vectors must have size (3, num_r_vectors)"))
        ndims(values) == spec.cartesian_rank + 3 ||
            throw(ArgumentError("operator rank does not match its array dimensions"))
        size(values, 1) == size(values, 2) ||
            throw(ArgumentError("operator Wannier axes must be square"))
        size(values, ndims(values)) == size(vectors, 2) ||
            throw(ArgumentError("operator real-space axis does not match r_vectors"))
        for axis in 3:(2 + spec.cartesian_rank)
            size(values, axis) == 3 ||
                throw(ArgumentError("every Cartesian operator axis must have length three"))
        end
        length(unique(Tuple(vectors[:, index]) for index in axes(vectors, 2))) ==
        size(vectors, 2) || throw(ArgumentError("r_vectors contains duplicates"))
        all(isfinite, values) || throw(ArgumentError("operator contains non-finite values"))
        return new{ndims(values)}(spec, vectors, values)
    end
end
