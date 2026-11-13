"""
Relabel an orthogonal H/r model by explicit integer Wannier cell shifts (3×N).

For the exp(+2πik·R) convention, R'=R+q_left-q_right and the home diagonal
position gains the Cartesian lattice translation q_left*L. All coefficients
are distributed with their original 1/d weights into a complete new support.
This is explicit reencoding, not a new WS interpolation or an inferred center.
"""
function relabel_wannier_cell_images(model::TightBindingModel, shifts::AbstractMatrix{<:Integer})
    count = model.num_orbitals
    size(shifts)==(3, count) || throw(ArgumentError("Wannier cell shifts must be3×N integers."))
    _home_cell_r_index(model)
    all(>(0), model.r_degeneracies) || throw(ArgumentError("Positive replica weights required."))
    vectors = Set{NTuple{3, Int}}([(0, 0, 0)])
    for r in 1:model.num_r_vectors, n in 1:count, m in 1:count
        if !iszero(model.hamiltonian_r[n, m, r]) ||
           any(!iszero, @view(model.position_r[n, m, :, r]))
            push!(vectors, ntuple(a -> model.r_vectors[a, r]+shifts[a, n]-shifts[a, m], 3))
        end
    end
    ordered = sort!(collect(vectors))
    index = Dict(v=>r for (r, v) in enumerate(ordered))
    support = hcat(collect.(ordered)...)
    hamiltonian = zeros(ComplexF64, count, count, length(ordered))
    position = zeros(ComplexF64, count, count, 3, length(ordered))
    for r in 1:model.num_r_vectors, n in 1:count, m in 1:count
        key = ntuple(a -> model.r_vectors[a, r]+shifts[a, n]-shifts[a, m], 3)
        haskey(index, key) || continue
        target = index[key];
        weight = model.r_degeneracies[r]
        hamiltonian[n, m, target] += model.hamiltonian_r[n, m, r]/weight
        for a in 1:3
            position[n, m, a, target] += model.position_r[n, m, a, r]/weight
        end
    end
    home = index[(0, 0, 0)]
    translations = transpose(model.lattice)*shifts
    for n in 1:count, a in 1:3
        position[n, n, a, home] += translations[a, n]
    end
    return TightBindingModel(
        copy(model.lattice),
        count,
        length(ordered),
        ones(Int, length(ordered)),
        support,
        hamiltonian,
        position,
    )
end

"""
Reinterpolate coherent H/r into a declared lattice WS support after explicit cell relabeling.

The actual CHK coordinates and existing ordered q→R helper remain authoritative.
Known home diagonal position constants are subtracted before Fourier mapping and
inserted analytically at R=0 with the target storage weight. Unknown homogeneous
position data retain the original Fourier algorithm. This intentionally changes
interpolation; it does not promise pair-WS/off-grid identity or material eligibility.
"""
function lattice_ws_reinterpolate_hr(
    model::TightBindingModel,
    chk::WannierCHK,
    target::TightBindingModel;
    cell_shifts::AbstractMatrix{<:Integer},
    roundtrip_atol::Float64 = 1e-8,
)
    model.num_orbitals==target.num_orbitals==chk.num_orbitals ||
        throw(ArgumentError("Inconsistent H/r/CHK orbital count."))
    maximum(abs, model.lattice-target.lattice)<1e-12 ||
        throw(ArgumentError("Lattice WS target uses a different lattice."))
    isfinite(roundtrip_atol) && roundtrip_atol>0 ||
        throw(ArgumentError("Invalid roundtrip tolerance."))
    length(unique(Tuple.(eachcol(target.r_vectors))))==target.num_r_vectors ||
        throw(ArgumentError("Duplicate target R vector."))
    target_home = _home_cell_r_index(target)
    common = relabel_wannier_cell_images(model, cell_shifts)
    for a in 1:3
        if all(iszero, @view(target.r_vectors[a, :])) && any(!iszero, @view(common.r_vectors[a, :]))
            throw(
                ArgumentError(
                    "Unresolved transverse cell-image support; do not flatten it through a coarse plane.",
                ),
            )
        end
    end
    count = common.num_orbitals;
    points = chk.num_kpts
    home = _home_cell_r_index(common)
    constant = zeros(ComplexF64, count, 3)
    homogeneous = copy(common.position_r)
    for n in 1:count, a in 1:3
        constant[n, a] = common.position_r[n, n, a, home]/common.r_degeneracies[home]
        homogeneous[n, n, a, home] = 0
    end
    phase = [
        cis(
            2pi*dot(@view(common.r_vectors[:, r]), @view(chk.kpt_red[k, :])),
        )/common.r_degeneracies[r] for r in 1:common.num_r_vectors, k in 1:points
    ]
    hq = reshape(reshape(common.hamiltonian_r, :, common.num_r_vectors)*phase, count, count, points)
    rq = reshape(reshape(homogeneous, :, common.num_r_vectors)*phase, count, count, 3, points)
    mapped_h = spin_velocity_q_to_r_diagnostics(
        hq,
        chk,
        target;
        atol = roundtrip_atol,
        label = "coherent_H",
    )
    mapped_r = spin_velocity_q_to_r_diagnostics(
        rq,
        chk,
        target;
        atol = roundtrip_atol,
        label = "homogeneous_r",
    )
    position = mapped_r.real_space_values
    for n in 1:count, a in 1:3
        position[n, n, a, target_home] += constant[n, a]*target.r_degeneracies[target_home]
    end
    output = TightBindingModel(
        copy(target.lattice),
        count,
        target.num_r_vectors,
        copy(target.r_degeneracies),
        copy(target.r_vectors),
        mapped_h.real_space_values,
        position,
    )
    return (
        model = output,
        cell_shifts = copy(cell_shifts),
        analytic_position_constant = constant,
        h_roundtrip = mapped_h.diagnostics,
        r_homogeneous_roundtrip = mapped_r.diagnostics,
        coordinates_replaced = false,
        interpolation_changed = true,
        production_eligible = false,
    )
end
