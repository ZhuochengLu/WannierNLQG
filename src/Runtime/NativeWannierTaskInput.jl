# Native topology is derived from the actual ordered points, never a temporary WIN/NNKP.
# Explicit source geometry is verified against the same physical reader used later.
function _workflow_native_wannier_input(document, source; base_dir, artifact_dir, mode = :ordinary)
    is_qe = source isa SymmetryFoundation.QuantumEspressoWavefunctionSource
    metadata =
        is_qe ? Wannierization.native_qe_wannier_metadata(source) :
        Wannierization.native_vasp_wannier_metadata(source)
    structure =
        haskey(document, "structure") ? _mesh_input_structure(document["structure"]) :
        metadata.structure
    _workflow_same_native_structure(structure, metadata.structure)
    dimensions, points = _workflow_native_mesh(document, source, metadata; base_dir)
    geometry = Wannierization.WannierizationGeometry(structure, dimensions, points)
    basis_table = get(document, "basis", Dict())
    basis = _workflow_wannier_basis(geometry, basis_table)
    basis.spinor == metadata.spinor ||
        throw(ArgumentError("basis spinor convention differs from native wavefunctions"))
    topology = _workflow_native_trial_topology(geometry, basis)
    provider =
        is_qe ? Wannierization.NativeQEPAWMatrices(topology; artifact_dir, require_oracle = false) :
        Wannierization.NativeVASPPAWMatrices(topology; artifact_dir, require_oracle = false)
    prefix = is_qe ? "native_qe_paw" : "native_paw"
    windows_table = get(document, "windows", Dict())
    _task_input_keys(
        windows_table,
        ("outer_min_ev", "outer_max_ev", "frozen_min_ev", "frozen_max_ev"),
        "windows",
    )
    windows = Dict(
        Symbol(
            key,
        )=>_workflow_input_value(
            fieldtype(Wannierization.WannierizationInputConfig, Symbol(key)),
            value,
            "windows.$key",
            base_dir,
        ) for (key, value) in windows_table
    )
    return Wannierization.WannierizationInputConfig(;
        wannierization_mode = mode,
        geometry,
        projection_basis = basis,
        source,
        sewing_backend = mode == :symmetry_adapted ? Wannierization.AugmentationAwareSewing() :
                         Wannierization.CoefficientMappingSewing(),
        symmetry_tolerance = _workflow_native_symmetry_tolerance(document, mode),
        operation_indices = _workflow_native_operation_indices(document, mode),
        num_wannier = basis.num_wannier,
        matrix_elements = provider,
        eig_file = joinpath(artifact_dir, prefix*".eig"),
        mmn_file = joinpath(artifact_dir, prefix*".mmn"),
        amn_file = joinpath(artifact_dir, prefix*".amn"),
        windows...,
    )
end

# Reject an explicit structure that disagrees with native species, cell, positions or magnetic moments.
function _workflow_same_native_structure(structure, actual)
    structure.species == actual.species &&
    isapprox(structure.lattice, actual.lattice; atol = 1e-10, rtol = 0) &&
    isapprox(structure.positions_fractional, actual.positions_fractional; atol = 1e-10, rtol = 0) &&
    isequal(structure.magnetic_moments_cartesian, actual.magnetic_moments_cartesian) ||
        throw(ArgumentError("explicit structure differs from native physical source"))
    return nothing
end

# Build the trial NNKP projection topology from the explicit basis using the existing orbital ordering.
function _workflow_native_trial_topology(geometry, basis)
    projections = Vector{WannierNNKPProjection}(undef, basis.num_wannier)
    shells = ("s", "p", "d", "f")
    # Codes use the existing Wannier orbital convention. Hybrid coefficient
    # equality is tested separately; unsupported sets must never silently reorder.
    hybrid_codes = Dict("sp"=>-1, "sp2"=>-2, "sp3"=>-3, "sp3d2"=>-5)
    for block in basis.blocks
        labels = WannierProjection.projection_orbital_labels(block.orbital_set)
        for center in axes(block.positions_fractional, 2), orbital in eachindex(labels)
            label = labels[orbital]
            shell = findfirst(s -> label in WannierProjection.projection_orbital_labels(s), shells)
            code, angular =
                shell === nothing ? (hybrid_codes[block.orbital_set], orbital) :
                (
                    shell-1,
                    findfirst(
                        ==(label),
                        WannierProjection.projection_orbital_labels(shells[shell]),
                    ),
                )
            local_basis = block.local_bases[:, :, center]
            for spin in 1:(basis.spinor ? 2 : 1)
                row = basis.spinor ? 2orbital-2+spin : orbital
                index = block.indices[row, center]
                projections[index] = WannierNNKPProjection(
                    Tuple(block.positions_fractional[:, center]),
                    code,
                    angular,
                    1,
                    Tuple(local_basis[3, :]),
                    Tuple(local_basis[1, :]),
                    1.0,
                    basis.spinor ? (spin == 1 ? 1 : -1) : nothing,
                    basis.spinor ? (0.0, 0.0, 1.0) : nothing,
                )
            end
        end
    end
    lattice = geometry.structure.lattice
    reciprocal = 2pi * inv(transpose(lattice))
    stencil = MatrixElements.build_finite_difference_stencil(
        reciprocal,
        geometry.mp_grid,
        geometry.kpoints_fractional,
    )
    return owned_wannier_topology(
        lattice,
        reciprocal,
        geometry.kpoints_fractional,
        stencil.neighbors,
        stencil.reciprocal_shifts,
        Int[],
        projections,
        basis.spinor,
    )
end

# The normalized adapter retains the existing SAWF detector and full native metric.
# Do not interpret mesh-screening operation indices as a SAWF subgroup selector.
function _workflow_native_symmetry_source(document, source, mode)
    mode == :ordinary && return source
    symmetry = get(document, "symmetry", Dict())
    _task_input_keys(
        symmetry,
        ("include_time_reversal", "symmetry_tolerance", "operation_indices"),
        "symmetry",
    )
    result = Dict{String, Any}(source)
    if haskey(symmetry, "include_time_reversal")
        value = symmetry["include_time_reversal"]
        value isa Bool || throw(ArgumentError("symmetry.include_time_reversal must be boolean"))
        haskey(source, "include_time_reversal") &&
            source["include_time_reversal"] != value &&
            throw(ArgumentError("source and symmetry time-reversal settings conflict"))
        result["include_time_reversal"] = value
    end
    return result
end

# Use the ordinary default tolerance or validate the finite positive symmetry-mode override.
function _workflow_native_symmetry_tolerance(document, mode)
    mode == :ordinary && return 1.0e-5
    value = get(get(document, "symmetry", Dict()), "symmetry_tolerance", 1.0e-5)
    value isa Real && !(value isa Bool) && isfinite(value) && value > 0 ||
        throw(ArgumentError("symmetry.symmetry_tolerance must be finite and positive"))
    return Float64(value)
end

# Explicit parent-inventory numbering; no automatic subgroup completion.
function _workflow_native_operation_indices(document, mode)
    value = get(get(document, "symmetry", Dict()), "operation_indices", nothing)
    value === nothing && return nothing
    mode == :symmetry_adapted ||
        throw(ArgumentError("operation selection requires symmetry_adapted mode"))
    value isa AbstractVector &&
    !isempty(value) &&
    all(x -> x isa Integer && !(x isa Bool) && x > 0, value) ||
        throw(ArgumentError("symmetry.operation_indices must be nonempty positive integer indices"))
    indices = Int.(value)
    length(unique(indices)) == length(indices) ||
        throw(ArgumentError("duplicate symmetry operation indices"))
    return indices
end
