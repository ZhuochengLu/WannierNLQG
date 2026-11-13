module GaugeRemovalReference290
using LinearAlgebra
using WannierNLQG.IO: WannierCHK, WannierMMN
using WannierNLQG.SymmetryFoundation: SymmetryOperation
# Shared response qualification kernels retained during removal of the gauge-aware workflow.
# Bodies and summation order are unchanged from candidate289.

function _reference_r_to_q(
    values_r::Array{ComplexF64, N},
    r_vectors::Matrix{Int},
    degeneracies::Vector{Int},
    kpoints::Matrix{Float64},
) where {N}
    size(values_r, N) == size(r_vectors, 2) == length(degeneracies) ||
        throw(ArgumentError("R-space field dimensions disagree"))
    output = zeros(ComplexF64, Base.front(size(values_r))..., size(kpoints, 1))
    output_matrix = reshape(output, :, size(kpoints, 1))
    input_matrix = reshape(values_r, :, size(r_vectors, 2))
    for kpoint in axes(kpoints, 1), r_index in axes(r_vectors, 2)
        phase = cis(2.0pi * dot(@view(kpoints[kpoint, :]), @view(r_vectors[:, r_index])))
        @views output_matrix[:, kpoint] .+=
            phase .* input_matrix[:, r_index] ./ degeneracies[r_index]
    end
    return output
end

function _reference_mmn_displacement(chk::WannierCHK, mmn::WannierMMN, neighbor::Int, source::Int)
    target = mmn.neighbors[neighbor, source]
    return Vector{Float64}(
        @view(chk.kpt_red[target, :]) .+ @view(mmn.reciprocal_shifts[:, neighbor, source]) .-
        @view(chk.kpt_red[source, :]),
    )
end

function _reference_edge_map(
    chk::WannierCHK,
    mmn::WannierMMN,
    operation_map::Matrix{Int},
    operations::Vector{SymmetryOperation};
    tolerance::Float64 = 1.0e-8,
)
    mapping = Array{Int, 3}(undef, mmn.num_neighbors, chk.num_kpts, length(operations))
    for operation_index in eachindex(operations), source in 1:chk.num_kpts
        operation = operations[operation_index]
        sign = operation.antiunitary ? -1.0 : 1.0
        target_source = operation_map[operation_index, source]
        for neighbor in 1:mmn.num_neighbors
            endpoint = mmn.neighbors[neighbor, source]
            target_endpoint = operation_map[operation_index, endpoint]
            displacement = _reference_mmn_displacement(chk, mmn, neighbor, source)
            transformed = sign .* (transpose(inv(operation.rotation_fractional)) * displacement)
            matches = Int[]
            for candidate in 1:mmn.num_neighbors
                mmn.neighbors[candidate, target_source] == target_endpoint || continue
                candidate_displacement =
                    _reference_mmn_displacement(chk, mmn, candidate, target_source)
                maximum(abs, transformed - candidate_displacement) <= tolerance &&
                    push!(matches, candidate)
            end
            length(matches) == 1 ||
                throw(ArgumentError("MMN edge has $(length(matches)) symmetry images"))
            mapping[neighbor, source, operation_index] = only(matches)
        end
    end
    return mapping
end

end
