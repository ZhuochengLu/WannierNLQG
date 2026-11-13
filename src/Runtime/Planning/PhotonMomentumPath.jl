"""One exact Cartesian photon momentum and its original, ordered response rows."""
struct PhotonMomentumGroup
    photon_momentum::NTuple{3, Float64}
    row_indices::Vector{Int}
end

"""
Owned paired photon-energy/momentum axis, with stable exact momentum groups.

Momenta use Cartesian A^-1. Dict `isequal` distinguishes signed zeros; no
tolerance, reciprocal wrapping or physical response symmetry merges rows.
The original momentum values and row order remain authoritative for output.
"""
struct PhotonMomentumPath
    photon_momenta::Vector{NTuple{3, Float64}}
    groups::Vector{PhotonMomentumGroup}
end

# Validate finite, non-Boolean energy values before copying into the public axis.
function _copy_photon_path_energies(values)
    values isa Union{AbstractVector, Tuple} ||
        throw(ArgumentError("photon_energies requires a nonempty sequence of real eV values"))
    isempty(values) && throw(ArgumentError("photon_energies must not be empty"))
    all(x -> x isa Real && !(x isa Bool) && isfinite(x), values) ||
        throw(ArgumentError("photon_energies must contain finite non-Boolean real values"))
    energies = Float64[x for x in values]
    all(isfinite, energies) || throw(ArgumentError("photon_energies must be finite in Float64"))
    return energies
end

# Validate one Cartesian momentum without accepting Boolean or nonfinite components.
function _copy_photon_path_momentum(value)
    value isa Union{AbstractVector, Tuple} && length(value) == 3 ||
        throw(ArgumentError("each photon momentum requires exactly three Cartesian components"))
    all(x -> x isa Real && !(x isa Bool) && isfinite(x), value) ||
        throw(ArgumentError("photon momentum requires finite non-Boolean real components"))
    momentum = Tuple(Float64.(value))
    all(isfinite, momentum) || throw(ArgumentError("photon momentum must be finite in Float64"))
    return momentum::NTuple{3, Float64}
end

"""Copy and group an explicitly zipped axis; unequal lengths never broadcast."""
function make_photon_momentum_path(photon_energies, photon_momenta)
    photon_momenta isa Union{AbstractVector, Tuple} ||
        throw(ArgumentError("photon_momenta requires a sequence of Cartesian three-vectors"))
    length(photon_momenta) == length(photon_energies) && !isempty(photon_momenta) ||
        throw(ArgumentError("photon_momenta and photon_energies require equal nonzero lengths"))
    momenta = NTuple{3, Float64}[_copy_photon_path_momentum(q) for q in photon_momenta]
    groups = PhotonMomentumGroup[]
    positions = Dict{NTuple{3, Float64}, Int}()
    for (row, momentum) in pairs(momenta)
        index = get(positions, momentum, 0)
        if index == 0
            push!(groups, PhotonMomentumGroup(momentum, Int[]))
            index = length(groups)
            positions[momentum] = index
        end
        push!(groups[index].row_indices, row)
    end
    return PhotonMomentumPath(momenta, groups)
end
