"""Detect a structural reference band path; no Hamiltonian symmetry is inferred.

3D uses the Brillouin HPKOT catalogue and Spglib's actual standardized cell.
2D uses the explicit periodic plane and Brillouin's geometric 2D catalogue,
not a three-dimensional space group inferred from the vacuum direction.
Magnetic inventories describe the supplied axial moments, including SOC.
Catalogue paths are reference paths, not a claim of magnetic irreducibility.
"""
function high_symmetry_band_path(
    structure::CrystalStructure;
    periodic_axes = (1, 2, 3),
    time_reversal::Union{Nothing, Bool} = nothing,
    spglib_symprec_angstrom::Real = 1.0e-5,
)
    all(axis -> axis isa Integer && !(axis isa Bool), periodic_axes) ||
        throw(ArgumentError("periodic_axes requires explicit integer lattice-axis indices"))
    axes = Tuple(Int.(periodic_axes))
    length(axes) in (2, 3) &&
    length(unique(axes)) == length(axes) &&
    all(axis -> axis in 1:3, axes) ||
        throw(ArgumentError("automatic band paths require two or three distinct periodic axes"))
    tolerance = Float64(spglib_symprec_angstrom)
    !(spglib_symprec_angstrom isa Bool) && isfinite(tolerance) && tolerance > 0 ||
        throw(ArgumentError("symmetry tolerance must be positive"))
    # The geometry workload lives in the lazy symmetry extension image. Keep
    # its implementation opaque until that image is loaded, so an outer TOML
    # resolver does not infer it before the saved specializations are available.
    band_geometry = _load_band_geometry!()
    _load_symmetry_foundation_extension!()
    return Base.invokelatest(
        _high_symmetry_band_path_loaded,
        band_geometry,
        structure,
        axes,
        time_reversal,
        tolerance,
    )
end

"""Compute the validated reference path after the symmetry cache is available."""
function _high_symmetry_band_path_loaded(band_geometry, structure, axes, time_reversal, tolerance)
    standardization = _call_symmetry_foundation_extension(
        :standardize_crystal_band_cell,
        structure;
        spglib_symprec_angstrom = tolerance,
    )
    inventory = detect_magnetic_symmetry_inventory(structure; spglib_symprec_angstrom = tolerance)
    inversion = any(
        operation ->
            !operation.antiunitary && operation.rotation_fractional == -Matrix{Int}(I, 3, 3),
        inventory.operations,
    )
    nonzero_moments =
        structure.magnetic_moments_cartesian !== nothing &&
        any(!iszero, structure.magnetic_moments_cartesian)
    time_reversal === true &&
        nonzero_moments &&
        throw(ArgumentError("pure time reversal conflicts with nonzero supplied magnetic moments"))
    reciprocal = 2pi * inv(structure.lattice)'
    details = Dict{String, Any}(
        "generator" => "Brillouin",
        "generator_version" => string(Base.pkgversion(band_geometry)),
        "symmetry_backend" => "Spglib",
        "symmetry_backend_version" => symmetry_detection_backend_provenance().version,
        "spglib_symprec_angstrom" => tolerance,
        "periodic_axes" => collect(axes),
        "input_lattice_angstrom" => [collect(row) for row in eachrow(structure.lattice)],
        "atomic_species" => copy(structure.species),
        "atomic_positions_fractional" =>
            [collect(position) for position in eachcol(structure.positions_fractional)],
        "magnetic_moments_cartesian" =>
            structure.magnetic_moments_cartesian === nothing ? nothing :
            [collect(moment) for moment in eachcol(structure.magnetic_moments_cartesian)],
        "time_reversal" => time_reversal === nothing ? "UNKNOWN" : time_reversal,
        "unitary_inversion_in_supplied_structure" => inversion,
        "magnetic_space_group_type" => inventory.msg_type,
        "magnetic_uni_number" => inventory.uni_number,
        "unitary_operation_count" => inventory.unitary_operation_count,
        "antiunitary_operation_count" => inventory.antiunitary_operation_count,
        "symmetry_scope" => "SUPPLIED_STRUCTURE_AND_MOMENTS_NOT_HAMILTONIAN_VALIDATION",
        "path_scope" => "STRUCTURAL_REFERENCE_NOT_MAGNETIC_IRREDUCIBLE_PATH",
    )
    branches = Vector{Vector{Tuple{String, NTuple{3, Float64}}}}()
    if length(axes) == 3
        standard = standardization.standard_lattice_vectors_angstrom
        catalogue = band_geometry.irrfbz_path(standardization.space_group_number, standard)
        cartesian = band_geometry.cartesianize(catalogue)
        rotation = standardization.standard_rotation_matrix
        transform = transpose(reciprocal) \ transpose(rotation)
        for labels in band_geometry.paths(catalogue)
            push!(
                branches,
                [
                    (string(label), Tuple(transform * band_geometry.points(cartesian)[label])) for
                    label in labels
                ],
            )
        end
        primitive = standardization.primitive_lattice
        details["convention"] = "HPKOT/SeeK-path"
        details["structural_space_group_number"] = standardization.space_group_number
        details["standard_lattice_angstrom"] = standard
        details["standard_rotation_matrix"] = [collect(row) for row in eachrow(rotation)]
        details["standard_cartesian_to_input_fractional"] =
            [collect(row) for row in eachrow(transform)]
        details["supercell_volume_ratio"] = abs(det(structure.lattice)) / abs(det(primitive))
        details["supercell_path_semantics"] = "PRIMITIVE_REFERENCE_EXPRESSED_IN_INPUT_RECIPROCAL_BASIS_WITH_FOLDED_SPECTRUM"
    else
        basis_fractional = _band_plane_primitive_basis(structure, axes, tolerance)
        plane_vectors = transpose(structure.lattice[collect(axes), :]) * basis_fractional
        plane_vectors, basis_fractional = _reduce_band_plane_basis(plane_vectors, basis_fractional)
        first_vector, second_vector = eachcol(plane_vectors)
        first_length, second_length = norm(first_vector), norm(second_vector)
        cosine = dot(first_vector, second_vector) / (first_length * second_length)
        metric_tolerance = tolerance / min(first_length, second_length)
        equal_lengths = abs(first_length - second_length) <= tolerance
        catalogue_index, bravais = if equal_lengths && abs(cosine + 0.5) <= metric_tolerance
            (17, "hexagonal")
        elseif abs(cosine) <= metric_tolerance
            equal_lengths ? (11, "square") : (6, "rectangular")
        elseif equal_lengths
            # The conventional centered rectangle is a+b, a-b.
            conversion = [1.0 1.0; 1.0 -1.0]
            plane_vectors = plane_vectors * conversion
            basis_fractional = basis_fractional * conversion
            (9, "centered_rectangular")
        else
            (2, "oblique")
        end
        first_vector = plane_vectors[:, 1]
        plane_x = first_vector / norm(first_vector)
        normal = normalize(cross(plane_vectors[:, 1], plane_vectors[:, 2]))
        plane_y = cross(normal, plane_x)
        embedding = hcat(plane_x, plane_y)
        plane_direct = transpose(embedding) * plane_vectors
        catalogue = band_geometry.irrfbz_path(
            catalogue_index,
            [collect(v) for v in eachcol(plane_direct)],
            Val(2),
        )
        cartesian = band_geometry.cartesianize(catalogue)
        transform = transpose(reciprocal) \ embedding
        for labels in band_geometry.paths(catalogue)
            push!(
                branches,
                [
                    (string(label), Tuple(transform * band_geometry.points(cartesian)[label])) for
                    label in labels
                ],
            )
        end
        details["convention"] = "Brillouin_2D_geometric_catalogue"
        details["plane_bravais_type"] = bravais
        details["catalogue_index_not_detected_plane_group"] = catalogue_index
        details["plane_conventional_basis_in_input_fractional"] =
            [collect(row) for row in eachrow(basis_fractional)]
        details["plane_normal_cartesian"] = collect(normal)
        details["plane_cartesian_to_input_fractional"] =
            [collect(row) for row in eachrow(transform)]
        details["plane_group_number"] = "NOT_CLASSIFIED"
    end
    # Unknown T is conservative. SOC alone is neither proof nor disproof of T.
    add_inverted = time_reversal !== true && !inversion
    if add_inverted
        for branch in copy(branches)
            push!(
                branches,
                [
                    (label == "Γ" ? label : "-" * label, Tuple(-collect(coordinate))) for
                    (label, coordinate) in branch
                ],
            )
        end
    end
    details["inverted_branches_added"] = add_inverted
    return (; branches, provenance = details)
end

# Actual species-preserving translations establish the plane primitive lattice.
# Fractional z is not wrapped: vacuum copies must not become 2D translations.
function _band_plane_translation(structure, axes, shift, tolerance)
    displacement = zeros(3)
    displacement[collect(axes)] .= shift
    for atom in eachindex(structure.species)
        found = any(eachindex(structure.species)) do other
            structure.species[atom] == structure.species[other] || return false
            delta =
                structure.positions_fractional[:, atom] + displacement -
                structure.positions_fractional[:, other]
            delta[collect(axes)] .-= round.(delta[collect(axes)])
            return norm(transpose(structure.lattice) * delta) <= tolerance
        end
        found || return false
    end
    return true
end

# Find a species-consistent primitive translation basis without folding the vacuum axis.
function _band_plane_primitive_basis(structure, axes, tolerance)
    translations = Vector{Vector{Float64}}([[1.0, 0.0], [0.0, 1.0]])
    remaining = only(setdiff(1:3, axes))
    for atom in eachindex(structure.species)
        structure.species[atom] == first(structure.species) || continue
        delta = structure.positions_fractional[:, atom] - structure.positions_fractional[:, 1]
        abs(delta[remaining]) * norm(structure.lattice[remaining, :]) <= tolerance || continue
        shift = mod.(delta[collect(axes)], 1.0)
        norm(shift) > eps(Float64) &&
            _band_plane_translation(structure, axes, shift, tolerance) &&
            push!(translations, shift)
    end
    candidates = [translation + [i, j] for translation in translations for i in -1:1 for j in -1:1]
    best = Matrix{Float64}(I, 2, 2)
    area = 1.0
    for first_vector in candidates, second_vector in candidates
        proposed = hcat(first_vector, second_vector)
        determinant = abs(det(proposed))
        determinant > 1.0e-10 && determinant < area - 1.0e-10 || continue
        coefficients = proposed \ hcat([1.0, 0.0], [0.0, 1.0], translations...)
        maximum(abs, coefficients - round.(coefficients)) <= 1.0e-8 || continue
        best, area = proposed, determinant
    end
    return best
end

# Gauss reduction changes only the primitive basis, retaining its input mapping.
function _reduce_band_plane_basis(vectors, fractional)
    vectors, fractional = copy(vectors), copy(fractional)
    converged = false
    for _ in 1:100
        if norm(vectors[:, 1]) > norm(vectors[:, 2])
            vectors = vectors[:, [2, 1]]
            fractional = fractional[:, [2, 1]]
        end
        multiple = round(Int, dot(vectors[:, 1], vectors[:, 2]) / sum(abs2, vectors[:, 1]))
        if multiple == 0
            converged = true
            break
        end
        vectors[:, 2] .-= multiple .* vectors[:, 1]
        fractional[:, 2] .-= multiple .* fractional[:, 1]
    end
    converged || throw(ArgumentError("periodic plane basis reduction did not converge"))
    if dot(vectors[:, 1], vectors[:, 2]) > 0
        vectors[:, 2] .*= -1
        fractional[:, 2] .*= -1
    end
    return vectors, fractional
end
