# Return complete noncentered MP residue vectors in deterministic order.
function _mp_residue_vectors(mp_grid::NTuple{3, Int})
    residues =
        [(i, j, k) for i in 0:(mp_grid[1] - 1), j in 0:(mp_grid[2] - 1), k in 0:(mp_grid[3] - 1)]
    return reshape(reduce(hcat, collect(residue) for residue in residues), 3, :)
end

# Canonicalize a CHK/MMN edge to its exact integer MP-grid displacement.
function _tight_binding_mmn_displacement(
    chk::WannierCHK,
    mmn::WannierMMN,
    neighbor::Int,
    kpoint::Int,
)
    target = mmn.neighbors[neighbor, kpoint]
    displacement =
        @view(chk.kpt_red[target, :]) .+ @view(mmn.reciprocal_shifts[:, neighbor, kpoint]) .-
        @view(chk.kpt_red[kpoint, :])
    mesh = Float64[chk.mp_grid...]
    mesh_coordinates = displacement .* mesh
    integer_coordinates = round.(mesh_coordinates)
    maximum(abs, mesh_coordinates - integer_coordinates) <= 1.0e-8 ||
        throw(ArgumentError("MMN neighbour displacement is not an integer MP-grid edge"))
    return integer_coordinates ./ mesh
end

# Derive shell-equal finite-difference weights directly from CHK/MMN geometry.
function _tight_binding_mmn_weights(chk::WannierCHK, mmn::WannierMMN)
    vectors = Matrix{Float64}(undef, mmn.num_neighbors, 3)
    for neighbor in 1:mmn.num_neighbors
        displacement = _tight_binding_mmn_displacement(chk, mmn, neighbor, 1)
        vectors[neighbor, :] .= transpose(chk.recip_lattice) * displacement
    end
    rank(vectors; atol = 1.0e-8) == 3 || throw(
        ArgumentError("MMN neighbour vectors do not form a complete three-dimensional stencil"),
    )
    shell_norms = Float64[]
    shells = Vector{Vector{Int}}()
    for neighbor in axes(vectors, 1)
        length_value = norm(@view vectors[neighbor, :])
        shell = findfirst(value -> abs(value - length_value) <= 1.0e-8, shell_norms)
        if shell === nothing
            push!(shell_norms, length_value)
            push!(shells, [neighbor])
        else
            push!(shells[shell], neighbor)
        end
    end
    target = Matrix{Float64}(I, 3, 3)
    system = Matrix{Float64}(undef, 9, length(shells))
    for shell in eachindex(shells)
        moment = zeros(Float64, 3, 3)
        for neighbor in shells[shell]
            vector = @view vectors[neighbor, :]
            moment .+= vector * vector'
        end
        system[:, shell] .= vec(moment)
    end
    shell_weights = system \ vec(target)
    norm(system * shell_weights - vec(target)) <= 1.0e-10 || throw(
        ArgumentError(
            "MMN neighbour shells do not form a complete three-dimensional finite-difference stencil",
        ),
    )
    weights = zeros(Float64, mmn.num_neighbors)
    for shell in eachindex(shells), neighbor in shells[shell]
        weights[neighbor] = shell_weights[shell]
    end
    return weights
end

# Validate saved weights against every edge, allowing equal-weight direction permutations.
function _tight_binding_saved_stencil_weights(chk::WannierCHK, mmn::WannierMMN, stencil)
    length(stencil.weights) == mmn.num_neighbors ||
        throw(ArgumentError("TB_STENCIL_IDENTITY_MISMATCH: neighbor count differs"))
    all(isfinite, stencil.weights) || throw(ArgumentError("TB_STENCIL_NONFINITE"))
    for kpoint in 1:chk.num_kpts
        matched = falses(mmn.num_neighbors)
        for neighbor in 1:mmn.num_neighbors
            displacement = _tight_binding_mmn_displacement(chk, mmn, neighbor, kpoint)
            vector = transpose(chk.recip_lattice) * displacement
            # MMN orders equal-length directions independently at each k point.
            # The solver uses index weights and each edge's actual displacement.
            reference = findfirst(1:mmn.num_neighbors) do index
                !matched[index] &&
                    stencil.weights[index] == stencil.weights[neighbor] &&
                    maximum(abs, vector - stencil.vectors_cartesian[index, :]) <= 1.0e-10
            end
            reference === nothing && throw(
                ArgumentError("TB_STENCIL_IDENTITY_MISMATCH: neighbor support or weight differs"),
            )
            matched[reference] = true
        end
    end
    return stencil.weights
end

# Inverse-transform one k-last matrix field onto the complete MP residue grid.
function _inverse_mp_fourier(values::Array{ComplexF64, N}, chk::WannierCHK) where {N}
    size(values, N) == chk.num_kpts ||
        throw(ArgumentError("k-last matrix field has incompatible k-point count"))
    r_vectors = _mp_residue_vectors(chk.mp_grid)
    output = zeros(ComplexF64, Base.front(size(values))..., size(r_vectors, 2))
    output_matrix = reshape(output, :, size(r_vectors, 2))
    input_matrix = reshape(values, :, chk.num_kpts)
    for r_index in axes(r_vectors, 2), kpoint in 1:chk.num_kpts
        phase = cis(-2.0 * pi * dot(@view(chk.kpt_red[kpoint, :]), @view(r_vectors[:, r_index])))
        @views output_matrix[:, r_index] .+= phase .* input_matrix[:, kpoint] ./ chk.num_kpts
    end
    return r_vectors, output
end

# Collect the finite union of pair-dependent nearest supercell images needed by
# the shared center-aware Wigner-Seitz transform.
function _pair_wigner_seitz_support(
    chk::WannierCHK;
    wigner_seitz_tolerance::Float64,
    search_size::Int,
)
    centers_fractional = chk.wannier_centers_cart * inv(chk.real_lattice)
    digits = ceil(Int, -log10(wigner_seitz_tolerance)) + 1
    images = Set{NTuple{3, Int}}()
    for left in 1:chk.num_orbitals, right in 1:chk.num_orbitals
        center_shift =
            round.(-centers_fractional[left, :] .+ centers_fractional[right, :]; digits = digits)
        for residue_column in eachcol(_mp_residue_vectors(chk.mp_grid))
            residue = Tuple(residue_column)
            union!(
                images,
                nearest_wigner_seitz_images(
                    residue,
                    center_shift,
                    chk.real_lattice,
                    chk.mp_grid;
                    tolerance = wigner_seitz_tolerance,
                    search_size = search_size,
                ),
            )
        end
    end
    ordered_images = sort!(collect(images))
    isempty(ordered_images) && error("center-aware Wigner-Seitz support is empty")
    return reshape(reduce(hcat, collect(image) for image in ordered_images), 3, :)
end

# Reuse the Symmetrization extension's center-aware transform for a q-last
# operator. This keeps the Wannier-center convention and tied-image weights
# identical across SAWF construction and downstream operator workflows.
function _inverse_pair_wigner_seitz_fourier(
    values::Array{ComplexF64, N},
    chk::WannierCHK;
    wigner_seitz_tolerance::Float64,
    search_size::Int,
    audit::Union{Nothing, AbstractDict} = nothing,
    label::AbstractString = "SAWF operator",
) where {N}
    r_vectors = _pair_wigner_seitz_support(
        chk;
        wigner_seitz_tolerance = wigner_seitz_tolerance,
        search_size = search_size,
    )
    plan = WannierPairWignerSeitzTransformPlan(
        chk,
        r_vectors;
        wigner_seitz_tolerance = wigner_seitz_tolerance,
        search_size = search_size,
        image_policy = :minimum_distance,
    )
    output = wannier_q_to_pair_wigner_seitz(
        values,
        chk,
        plan;
        support_tolerance = 0.0,
        label = "SAWF operator",
    )
    roundtrip_error = unit_degeneracy_roundtrip_error(values, output, chk, plan)
    roundtrip_error <= 1.0e-10 || error(
        "center-aware Wigner-Seitz $(label) transform round-trip error " *
        "$(roundtrip_error) exceeds 1.0e-10",
    )
    audit === nothing || (audit[String(label)] = roundtrip_error)
    return r_vectors, output
end

"""
Build a tight-binding model from a completed SAWF result and its explicit
Hamiltonian authority.

By default the builder reuses the Symmetrization extension's center-aware
minimum-distance Wigner-Seitz transform. `real_space_replica_policy=:mp_grid`
retains the complete noncentered MP residue grid for exact grid diagnostics.
The finite-difference position matrix is projected onto
`A(R) = A(-R)'` after the real-space transform, matching WannierBerri's
`set_R_mat(..., Hermitian=true)` construction. This is the physical
Hermiticity closure of the position operator, not a space-group projection.
Finite-difference overlaps first receive the Convention-I right-center phase;
the home-cell diagonal is then set to the exact checkpoint centers to serialize
the Convention-II position operator, including nonperiodic axes and without
retaining finite-stencil center drift.
Subsequent real-space symmetry projection remains an explicit downstream step.
"""
function build_wannier_tight_binding_model(
    result::WannierizationResult,
    band_hamiltonian::AuthoritativeBandHamiltonian,
    mmn::WannierMMN;
    real_space_replica_policy::Symbol = :minimum_distance,
    wigner_seitz_tolerance::Float64 = 1.0e-5,
    wigner_seitz_search_size::Int = 3,
    construction_diagnostics::Union{Nothing, AbstractDict} = nothing,
    allow_legacy_diagnostic_export::Bool = false,
)
    result.wannier_chk === nothing &&
        throw(ArgumentError("tight-binding construction requires a result with WannierCHK data"))
    result.status != IN_PROGRESS_CHECKPOINT ||
        throw(ArgumentError("tight-binding construction rejects an in-progress checkpoint"))
    legacy_diagnostic_read_only =
        get(result.input_summary, "restart_continuation_semantics", "") ==
        "LEGACY_DIAGNOSTIC_READ_ONLY"
    result.restart_state !== nothing ||
        (allow_legacy_diagnostic_export && legacy_diagnostic_read_only) ||
        throw(ArgumentError("tight-binding construction requires a finite accepted restart state"))
    real_space_replica_policy in (:mp_grid, :minimum_distance) ||
        throw(ArgumentError("real_space_replica_policy must be :mp_grid or :minimum_distance"))
    wigner_seitz_tolerance > 0.0 || throw(ArgumentError("wigner_seitz_tolerance must be positive"))
    wigner_seitz_search_size > 0 ||
        throw(ArgumentError("wigner_seitz_search_size must be positive"))
    chk = result.wannier_chk
    size(band_hamiltonian.matrices_ev) == (chk.num_bands, chk.num_bands, chk.num_kpts) || throw(
        ArgumentError("authoritative Hamiltonian dimensions do not match the SAWF checkpoint"),
    )
    band_hamiltonian.qualified ||
        throw(ArgumentError("authoritative Hamiltonian is not qualified for TB construction"))
    mmn.num_bands == chk.num_bands && mmn.num_kpts == chk.num_kpts ||
        throw(ArgumentError("MMN dimensions do not match the SAWF checkpoint"))
    hamiltonian_q = zeros(ComplexF64, chk.num_orbitals, chk.num_orbitals, chk.num_kpts)
    for kpoint in 1:chk.num_kpts
        gauge = @view chk.v_matrix[:, :, kpoint]
        hamiltonian_q[:, :, kpoint] .=
            gauge' * (@view band_hamiltonian.matrices_ev[:, :, kpoint]) * gauge
    end
    weights = if result.restart_state === nothing
        _tight_binding_mmn_weights(chk, mmn)
    else
        _tight_binding_saved_stencil_weights(chk, mmn, result.restart_state.stencil)
    end
    position_q = zeros(ComplexF64, chk.num_orbitals, chk.num_orbitals, 3, chk.num_kpts)
    for kpoint in 1:chk.num_kpts, neighbor in 1:mmn.num_neighbors
        target = mmn.neighbors[neighbor, kpoint]
        overlap =
            @view(chk.v_matrix[:, :, kpoint])' *
            @view(mmn.data[:, :, neighbor, kpoint]) *
            @view(chk.v_matrix[:, :, target])
        displacement = _tight_binding_mmn_displacement(chk, mmn, neighbor, kpoint)
        b_cartesian = transpose(chk.recip_lattice) * displacement
        overlap .*= transpose(cis.(chk.wannier_centers_cart * b_cartesian))
        for direction in 1:3
            @views position_q[:, :, direction, kpoint] .+=
                1.0im * weights[neighbor] * b_cartesian[direction] .* overlap
        end
    end
    transform_audit = Dict{String, Float64}()
    transform = if real_space_replica_policy == :mp_grid
        (values, _label) -> _inverse_mp_fourier(values, chk)
    else
        (values, label) -> _inverse_pair_wigner_seitz_fourier(
            values,
            chk;
            wigner_seitz_tolerance = wigner_seitz_tolerance,
            search_size = wigner_seitz_search_size,
            audit = transform_audit,
            label,
        )
    end
    r_vectors, hamiltonian_r = transform(hamiltonian_q, "hamiltonian")
    position_r_vectors, position_r = transform(position_q, "position")
    r_vectors == position_r_vectors || error("internal Fourier support mismatch")
    if real_space_replica_policy == :minimum_distance
        position_r = hermitianize_real_space_pairs(position_r, r_vectors)
    end
    home_index = only(findall(index -> all(iszero, @view(r_vectors[:, index])), axes(r_vectors, 2)))
    for wannier in 1:chk.num_orbitals, direction in 1:3
        position_r[wannier, wannier, direction, home_index] =
            chk.wannier_centers_cart[wannier, direction]
    end
    if construction_diagnostics !== nothing
        construction_diagnostics["real_space_replica_policy"] = String(real_space_replica_policy)
        construction_diagnostics["fourier_roundtrip_gate_tolerance"] = 1.0e-10
        construction_diagnostics["hamiltonian_fourier_roundtrip_residual"] =
            get(transform_audit, "hamiltonian", NaN)
        construction_diagnostics["position_fourier_roundtrip_residual"] =
            get(transform_audit, "position", NaN)
        construction_diagnostics["authoritative_hamiltonian"] = band_hamiltonian.authority
        construction_diagnostics["authoritative_band_hamiltonian_digest"] = band_hamiltonian.digest
        construction_diagnostics["authoritative_band_hamiltonian_algorithm_version"] =
            band_hamiltonian.algorithm_version
    end
    return TightBindingModel(
        chk.real_lattice,
        chk.num_orbitals,
        size(r_vectors, 2),
        ones(Int, size(r_vectors, 2)),
        r_vectors,
        hamiltonian_r,
        position_r,
    )
end

"""Build a native-EIG tight-binding model through the authoritative-Hamiltonian path."""
function build_wannier_tight_binding_model(
    result::WannierizationResult,
    eig::WannierEIG,
    mmn::WannierMMN;
    kwargs...,
)
    native = _native_authoritative_band_hamiltonian(eig)
    return build_wannier_tight_binding_model(result, native, mmn; kwargs...)
end
