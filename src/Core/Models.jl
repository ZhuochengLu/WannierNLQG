"""
Real-space tight-binding data in the Wannier representation.

The model contains only Hamiltonian and position data. Optional observables such as
spin and spin velocity are represented by peer real-space data objects in
`WannierNLQG.MatrixElements`.
"""
struct TightBindingModel{H <: AbstractArray{ComplexF64, 3}, P <: AbstractArray{ComplexF64, 4}}
    lattice::Matrix{Float64}
    num_orbitals::Int
    num_r_vectors::Int
    r_degeneracies::Vector{Int}
    r_vectors::Matrix{Int}
    hamiltonian_r::H
    position_r::P

    function TightBindingModel(
        lattice,
        num_orbitals,
        num_r_vectors,
        r_degeneracies,
        r_vectors,
        hamiltonian_r,
        position_r;
        copy_data::Bool = true,
    )
        orbital_count = Int(num_orbitals)
        r_vector_count = Int(num_r_vectors)
        orbital_count > 0 || throw(ArgumentError("num_orbitals must be positive"))
        r_vector_count > 0 || throw(ArgumentError("num_r_vectors must be positive"))

        lattice_matrix = Matrix{Float64}(lattice)
        degeneracies = Vector{Int}(r_degeneracies)
        vectors = Matrix{Int}(r_vectors)
        hamiltonian = copy_data ? Array{ComplexF64, 3}(hamiltonian_r) : hamiltonian_r
        position = copy_data ? Array{ComplexF64, 4}(position_r) : position_r
        hamiltonian isa AbstractArray{ComplexF64, 3} ||
            throw(ArgumentError("hamiltonian_r must be a rank-three ComplexF64 array"))
        position isa AbstractArray{ComplexF64, 4} ||
            throw(ArgumentError("position_r must be a rank-four ComplexF64 array"))

        size(lattice_matrix) == (3, 3) ||
            throw(ArgumentError("lattice must have size (3, 3), got $(size(lattice_matrix))"))
        length(degeneracies) == r_vector_count ||
            throw(ArgumentError("r_degeneracies length must equal num_r_vectors"))
        all(>(0), degeneracies) || throw(ArgumentError("r_degeneracies entries must be positive"))
        size(vectors) == (3, r_vector_count) ||
            throw(ArgumentError("r_vectors must have size (3, num_r_vectors)"))
        size(hamiltonian) == (orbital_count, orbital_count, r_vector_count) ||
            throw(ArgumentError("hamiltonian_r has incompatible dimensions"))
        size(position) == (orbital_count, orbital_count, 3, r_vector_count) ||
            throw(ArgumentError("position_r has incompatible dimensions"))

        return new{typeof(hamiltonian), typeof(position)}(
            lattice_matrix,
            orbital_count,
            r_vector_count,
            degeneracies,
            vectors,
            hamiltonian,
            position,
        )
    end
end

"""Shared eigensystem data composed into every k-point matrix-element object."""
mutable struct KPointSpectrum
    energies::Vector{Float64}
    eigenvectors::Matrix{ComplexF64}
    eigenvectors_adjoint::Matrix{ComplexF64}
    source_eigenvectors::Matrix{ComplexF64}
    source_eigenvectors_adjoint::Matrix{ComplexF64}
end

# Allocate zeroed energy and source/Hamiltonian-gauge eigenvector buffers for a positive orbital count; reject nonpositive counts.
function KPointSpectrum(num_orbitals::Integer)
    count = Int(num_orbitals)
    count > 0 || throw(ArgumentError("num_orbitals must be positive"))
    return KPointSpectrum(
        zeros(Float64, count),
        zeros(ComplexF64, count, count),
        zeros(ComplexF64, count, count),
        zeros(ComplexF64, count, count),
        zeros(ComplexF64, count, count),
    )
end
