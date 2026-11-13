"""Partition numerically equal eigenvalues without merging physically split levels.

The gap tolerance is an error threshold, never a smoothing scale. Energies are in eV.
"""
function spectral_subspace_blocks(energies; gap_tolerance::Real = 1e-10)
    isempty(energies) && throw(ArgumentError("Empty spectrum"))
    issorted(energies) && all(isfinite, energies) || throw(ArgumentError("Invalid spectrum"))
    isfinite(gap_tolerance) && gap_tolerance >= 0 ||
        throw(ArgumentError("Invalid spectral gap tolerance"))
    exact = 32eps(Float64) * max(1.0, maximum(abs, energies))
    blocks = UnitRange{Int}[]
    start = 1
    for n in 2:length(energies)
        gap = energies[n] - energies[start]
        if gap > exact
            adjacent_gap = energies[n] - energies[n - 1]
            adjacent_gap > gap_tolerance ||
                error("SPECTRAL_CROSS_BLOCK_GAP_UNRESOLVED: gap=$(adjacent_gap) eV")
            push!(blocks, start:(n - 1))
            start = n
        end
    end
    push!(blocks, start:length(energies))
    return blocks
end

"""Solve H_B r_BA - r_BA H_A = -i V_BA in the energy eigenframe.

Only disjoint complete spectral blocks are solved. Block interiors retain the supplied
connection; no pseudo-inverse, energy averaging, occupation, or response weight is used.
"""
function solve_subspace_position!(
    output,
    energies,
    covariant_hamiltonian,
    blocks;
    gap_tolerance::Real = 1e-10,
)
    size(output) == size(covariant_hamiltonian) ||
        throw(DimensionMismatch("position/vertex shapes"))
    nband = length(energies)
    size(output, 1) == size(output, 2) == nband ||
        throw(DimensionMismatch("spectrum/position shapes"))
    # Composite subspaces may join spectral blocks, but cannot split an equal-energy block.
    spectral = spectral_subspace_blocks(energies; gap_tolerance = gap_tolerance)
    labels = zeros(Int, nband)
    for (label, block) in enumerate(blocks)
        isempty(block) && throw(ArgumentError("Empty subspace block"))
        for n in block
            1 <= n <= nband || throw(ArgumentError("Subspace index out of range"))
            labels[n] == 0 || throw(ArgumentError("Overlapping subspace blocks"))
            labels[n] = label
        end
    end
    all(>(0), labels) || throw(ArgumentError("Incomplete subspace partition"))
    for block in spectral
        all(n -> labels[n] == labels[first(block)], block) ||
            throw(ArgumentError("A subspace boundary splits a numerically degenerate level"))
    end
    for left in blocks, right in blocks
        left == right && continue
        for a in axes(output, 3), m in right, n in left
            gap = energies[n] - energies[m]
            iszero(gap) && error("SPECTRAL_CROSS_BLOCK_GAP_UNRESOLVED")
            output[n, m, a] = -im * covariant_hamiltonian[n, m, a] / gap
        end
    end
    return output
end

"""Slot-owned bare position buffers, filled lazily and reused across generations.

The fixed I0 position rule is independent of eta and spectral partition guards.
A validity mask distinguishes working/source D0, r0 and optical commutators;
no exact projector derivative or physical transition denominator is cached here.
"""
mutable struct SubspacePositionCache
    generation::UInt64
    valid_mask::UInt8
    connection::Union{Nothing, Array{ComplexF64, 3}}
    source_connection::Union{Nothing, Array{ComplexF64, 3}}
    inverse_energy_differences::Union{Nothing, Matrix{Float64}}
    gauge_correction::Union{Nothing, Array{ComplexF64, 3}}
    source_gauge_correction::Union{Nothing, Array{ComplexF64, 3}}
    velocity_vertices::Union{Nothing, Array{ComplexF64, 3}}
    source_velocity_vertices::Union{Nothing, Array{ComplexF64, 3}}
    source_rotation_scratch::Union{Nothing, Matrix{ComplexF64}}
end

const _POSITION_WORKING_D0 = UInt8(1)
const _POSITION_SOURCE_D0 = UInt8(2)
const _POSITION_WORKING_R0 = UInt8(4)
const _POSITION_SOURCE_R0 = UInt8(8)
const _POSITION_BARE_INVERSE = UInt8(16)
const _POSITION_WORKING_OPTICAL = UInt8(32)
const _POSITION_SOURCE_OPTICAL = UInt8(64)
