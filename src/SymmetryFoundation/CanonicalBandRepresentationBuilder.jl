# Canonical, source-neutral plane-wave band-representation construction.
# Native VASP/QE adapters intentionally supply only normalized data through the
# field contract used below; they do not own symmetry or sewing mathematics.

"""
Serialize one symmetry operation into a deterministic canonical lookup key.
"""
function canonical_band_operation_key(operation::SymmetryOperation; digits::Int = 12)
    translation = mod.(operation.translation_fractional, 1.0)
    translation[abs.(translation .- 1.0) .< 10.0 ^ (-digits)] .= 0.0
    rotation = join(vec(transpose(operation.rotation_fractional)), ",")
    return "$(operation.antiunitary ? 'A' : 'U')|W=$(rotation)|tau=$(join(round.(translation; digits), ','))"
end

# Hash the scientific identity of structured representation-preparation metadata.
function _band_preparation_metadata_digest(
    inventory,
    diagnostics,
    outer_mask_sha256::AbstractString,
    frozen_mask_sha256::AbstractString,
    requested_policy::Symbol,
    effective_policy::Symbol,
    tolerance_status::Symbol,
)
    buffer = IOBuffer()
    for value in (
        outer_mask_sha256,
        frozen_mask_sha256,
        String(requested_policy),
        String(effective_policy),
        String(tolerance_status),
    )
        write(buffer, codeunits(String(value)))
        write(buffer, UInt8(0))
    end
    if inventory !== nothing
        write(
            buffer,
            codeunits(
                repr((
                    inventory.magnetic,
                    inventory.msg_type,
                    inventory.uni_number,
                    inventory.hall_number,
                    inventory.unitary_operation_count,
                    inventory.antiunitary_operation_count,
                    inventory.symmetry_tolerance,
                )),
            ),
        )
    end
    for diagnostic in diagnostics
        fields = (
            diagnostic.scope,
            diagnostic.operation_index,
            diagnostic.source_kpoint,
            diagnostic.target_kpoint,
            diagnostic.antiunitary,
            diagnostic.source_band_count,
            diagnostic.target_band_count,
            diagnostic.required_rank,
            diagnostic.numerical_rank,
            diagnostic.rank_threshold,
            diagnostic.minimum_singular_value,
            diagnostic.maximum_singular_value,
            diagnostic.condition_estimate,
            diagnostic.left_unitarity_residual,
            diagnostic.right_unitarity_residual,
            diagnostic.status,
        )
        write(buffer, codeunits(repr(fields)))
        write(buffer, UInt8(0))
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

# Resolve one transformed k point and its reciprocal-lattice shift uniquely.
function _canonical_match_kpoint(
    transformed::AbstractVector{<:Real},
    kpoints::AbstractMatrix{<:Real};
    tolerance::Float64,
)
    matches = Tuple{Int, Vector{Int}}[]
    for target in axes(kpoints, 1)
        difference = transformed .- @view(kpoints[target, :])
        shift = round.(Int, difference)
        maximum(abs, difference .- shift) <= tolerance && push!(matches, (target, shift))
    end
    length(matches) == 1 || throw(
        ArgumentError(
            "INVALID_SYMMETRY_ACTION: transformed k-point $(collect(transformed)) has " *
            "$(length(matches)) matches on the full mesh",
        ),
    )
    return only(matches)
end

"""
Build and validate every symmetry permutation on the full k mesh.
"""
function build_canonical_kpoint_action(
    operations::Vector{SymmetryOperation},
    kpoints::Matrix{Float64};
    tolerance::Float64,
)
    mapping = Matrix{Int}(undef, length(operations), size(kpoints, 1))
    shifts = Array{Int, 3}(undef, 3, length(operations), size(kpoints, 1))
    for (operation_index, operation) in enumerate(operations), source in axes(kpoints, 1)
        sign = operation.antiunitary ? -1.0 : 1.0
        transformed =
            sign .* (transpose(inv(operation.rotation_fractional)) * @view(kpoints[source, :]))
        target, shift = _canonical_match_kpoint(transformed, kpoints; tolerance)
        mapping[operation_index, source] = target
        shifts[:, operation_index, source] .= shift
    end
    for operation_index in axes(mapping, 1)
        sort(@view(mapping[operation_index, :])) == collect(axes(mapping, 2)) || throw(
            ArgumentError(
                "INVALID_SYMMETRY_ACTION: operation $(operation_index) is not a k-mesh permutation",
            ),
        )
    end
    return mapping, shifts
end

# Construct one sewing matrix and retain scoped diagnostics before polar projection.
function canonical_plane_wave_sewing_matrix(
    source,
    target,
    operation::SymmetryOperation,
    reciprocal_shift::AbstractVector{<:Integer},
    degeneracy_tolerance_ev::Float64;
    convention::Symbol = :canonical,
    raw_diagnostics::Union{Nothing, AbstractVector} = nothing,
    diagnostic_scopes = nothing,
)
    convention in (:canonical, :spin_adjoint, :band_adjoint, :spin_and_band_adjoint) ||
        throw(ArgumentError("unsupported plane-wave sewing convention $(convention)"))
    all(isfinite, source.coefficients) && all(isfinite, target.coefficients) || throw(
        ArgumentError("NONFINITE_COEFFICIENT_BLOCK: native coefficients contain non-finite values"),
    )
    size(source.coefficients, 1) == size(target.coefficients, 1) ||
        throw(ArgumentError("source and target band counts disagree"))
    spin_components = size(source.coefficients, 3)
    size(target.coefficients, 3) == spin_components ||
        throw(ArgumentError("source and target spin conventions disagree"))
    target_index = Dict(Tuple(target.g_vectors[row, :]) => row for row in axes(target.g_vectors, 1))
    transformed =
        zeros(ComplexF64, size(source.coefficients, 1), size(target.g_vectors, 1), spin_components)
    reciprocal_action = transpose(inv(operation.rotation_fractional))
    spin_matrix = spin_action_matrix(operation, spin_components == 2)
    convention in (:spin_adjoint, :spin_and_band_adjoint) && (spin_matrix = spin_matrix')
    sign = operation.antiunitary ? -1.0 : 1.0
    for source_g in axes(source.g_vectors, 1)
        source_wavevector = source.k_fractional .+ @view(source.g_vectors[source_g, :])
        target_wavevector = sign .* (reciprocal_action * source_wavevector)
        mapped_source_g = sign .* (reciprocal_action * @view(source.g_vectors[source_g, :]))
        maximum(abs, mapped_source_g .- round.(mapped_source_g)) <= 1.0e-8 ||
            throw(ArgumentError("INVALID_SYMMETRY_ACTION: noninteger mapped plane-wave index"))
        target_g = Int.(reciprocal_shift) .+ round.(Int, mapped_source_g)
        maximum(abs, target_wavevector .- target.k_fractional .- target_g) <= 1.0e-8 || throw(
            ArgumentError(
                "INVALID_SYMMETRY_ACTION: reciprocal shift contradicts plane-wave action",
            ),
        )
        target_row = get(target_index, Tuple(target_g), 0)
        target_row == 0 && continue
        phase = cis(-2.0 * pi * dot(target_wavevector, operation.translation_fractional))
        for band in axes(source.coefficients, 1), output_spin in 1:spin_components
            value = 0.0 + 0.0im
            for input_spin in 1:spin_components
                coefficient = source.coefficients[band, source_g, input_spin]
                operation.antiunitary && (coefficient = conj(coefficient))
                value += spin_matrix[output_spin, input_spin] * coefficient
            end
            transformed[band, target_row, output_spin] += phase * value
        end
    end
    target_coefficients = reshape(
        target.coefficients,
        size(target.coefficients, 1),
        size(target.coefficients, 2) * spin_components,
    )
    transformed_coefficients =
        reshape(transformed, size(transformed, 1), size(transformed, 2) * spin_components)

    if raw_diagnostics !== nothing
        scopes =
            diagnostic_scopes === nothing ?
            ((
                scope = :full,
                source_indices = collect(axes(source.coefficients, 1)),
                target_indices = collect(axes(target.coefficients, 1)),
            ),) : diagnostic_scopes
        for scoped in scopes
            source_indices = Int[scoped.source_indices...]
            target_indices = Int[scoped.target_indices...]
            required_rank = min(length(source_indices), length(target_indices))
            if isempty(source_indices) || isempty(target_indices)
                push!(
                    raw_diagnostics,
                    Dict{String, Any}(
                        "kind" => scoped.scope == :full ? "full" : "qualification_scope",
                        "scope" => String(scoped.scope),
                        "source_band_count" => length(source_indices),
                        "target_band_count" => length(target_indices),
                        "required_rank" => required_rank,
                        "numerical_rank" => 0,
                        "rank_threshold" => 0.0,
                        "sigma_min" => 0.0,
                        "sigma_max" => 0.0,
                        "condition_estimate" => Inf,
                        "left_unitarity_residual" => 0.0,
                        "right_unitarity_residual" => 0.0,
                        "unitarity_residual" => 0.0,
                        "status" => "EMPTY_SCOPE",
                    ),
                )
                continue
            end
            target_block = @view target_coefficients[target_indices, :]
            right_inverse = _conditioned_right_inverse(target_block)
            coefficient_map = @view(transformed_coefficients[source_indices, :]) * right_inverse
            raw =
                convention in (:band_adjoint, :spin_and_band_adjoint) ? adjoint(coefficient_map) :
                transpose(coefficient_map)
            all(isfinite, raw) || throw(
                ArgumentError("NONFINITE_SEWING_BLOCK: raw band representation is non-finite"),
            )
            singular_values = svdvals(raw)
            sigma_max = maximum(singular_values)
            sigma_min = minimum(singular_values)
            rank_threshold = max(size(raw)...) * eps(Float64) * max(sigma_max, 1.0)
            left_identity = Matrix{ComplexF64}(I, size(raw, 1), size(raw, 1))
            right_identity = Matrix{ComplexF64}(I, size(raw, 2), size(raw, 2))
            left_residual = maximum(abs, raw * raw' - left_identity)
            right_residual = maximum(abs, raw' * raw - right_identity)
            push!(
                raw_diagnostics,
                Dict{String, Any}(
                    "kind" => scoped.scope == :full ? "full" : "qualification_scope",
                    "scope" => String(scoped.scope),
                    "source_band_count" => length(source_indices),
                    "target_band_count" => length(target_indices),
                    "required_rank" => required_rank,
                    "numerical_rank" => count(>(rank_threshold), singular_values),
                    "rank_threshold" => rank_threshold,
                    "sigma_min" => sigma_min,
                    "sigma_max" => sigma_max,
                    "condition_estimate" => sigma_min > 0.0 ? sigma_max / sigma_min : Inf,
                    "left_unitarity_residual" => left_residual,
                    "right_unitarity_residual" => right_residual,
                    "unitarity_residual" => max(left_residual, right_residual),
                    "status" =>
                        length(source_indices) == length(target_indices) ? "REPORT_ONLY" :
                        "DIMENSION_MISMATCH",
                ),
            )
        end
    end

    result = zeros(ComplexF64, size(source.coefficients, 1), size(source.coefficients, 1))
    block_start = 1
    while block_start <= length(source.energies_ev)
        block_stop = block_start
        while block_stop < length(source.energies_ev) &&
            abs(source.energies_ev[block_stop + 1] - source.energies_ev[block_stop]) <=
            degeneracy_tolerance_ev
            block_stop += 1
        end
        block = block_start:block_stop
        right_inverse = _conditioned_right_inverse(@view target_coefficients[block, :])
        coefficient_map = @view(transformed_coefficients[block, :]) * right_inverse
        raw =
            convention in (:band_adjoint, :spin_and_band_adjoint) ? adjoint(coefficient_map) :
            transpose(coefficient_map)
        all(isfinite, raw) ||
            throw(ArgumentError("NONFINITE_SEWING_BLOCK: raw band representation is non-finite"))
        decomposition = svd(raw)
        if raw_diagnostics !== nothing
            singular_values = decomposition.S
            identity_matrix = Matrix{ComplexF64}(I, length(block), length(block))
            push!(
                raw_diagnostics,
                Dict{String, Any}(
                    "kind" => "energy_block",
                    "block_start" => first(block),
                    "block_stop" => last(block),
                    "sigma_min" => minimum(singular_values),
                    "sigma_max" => maximum(singular_values),
                    "condition_estimate" => maximum(singular_values) / minimum(singular_values),
                    "unitarity_residual" => max(
                        maximum(abs, raw' * raw - identity_matrix),
                        maximum(abs, raw * raw' - identity_matrix),
                    ),
                ),
            )
        end
        result[block, block] .= decomposition.U * decomposition.Vt
        block_start = block_stop + 1
    end
    return result
end

"""
Label contiguous energy-degeneracy blocks independently at every k point.
"""
function canonical_band_block_labels(energies::Matrix{Float64}, tolerance_ev::Float64)
    labels = Matrix{Int}(undef, size(energies))
    for kpoint in axes(energies, 2)
        label = 1
        labels[1, kpoint] = label
        for band in 2:size(energies, 1)
            abs(energies[band, kpoint] - energies[band - 1, kpoint]) > tolerance_ev && (label += 1)
            labels[band, kpoint] = label
        end
    end
    return labels
end

"""
Select deterministic irreducible representatives and their star mappings.
"""
function canonical_irreducible_star_plan(kpoint_map::Matrix{Int})
    nk = size(kpoint_map, 2)
    visited = falses(nk)
    irreducible = Int[]
    full_to_irreducible = zeros(Int, nk)
    full_to_operation = zeros(Int, nk)
    for representative in 1:nk
        visited[representative] && continue
        push!(irreducible, representative)
        ibz_index = length(irreducible)
        for target in sort(unique(kpoint_map[:, representative]))
            visited[target] = true
            full_to_irreducible[target] = ibz_index
            full_to_operation[target] =
                something(findfirst(==(target), @view(kpoint_map[:, representative])), 1)
        end
    end
    all(visited) || throw(ArgumentError("INVALID_SYMMETRY_ACTION: k-star plan is incomplete"))
    return irreducible, full_to_irreducible, full_to_operation
end

"""
Reject antiunitary inventories unsupported by a single collinear spin channel.
"""
function validate_canonical_antiunitary_channel(native, operations::Vector{SymmetryOperation})
    metadata =
        hasproperty(native, :source_metadata) ? native.source_metadata : Dict{String, String}()
    if get(metadata, "spin_mode", "") == "collinear_single_channel" &&
       any(operation.antiunitary for operation in operations)
        throw(
            ArgumentError(
                "ANTIUNITARY_CHANNEL_MIXING_UNSUPPORTED: a single collinear spin channel cannot " *
                "represent the requested antiunitary inventory",
            ),
        )
    end
    return nothing
end

"""
    build_canonical_band_representation(native, energies, operations, tolerance; ...)

Canonical source-neutral builder used by both VASP and QE adapters. Returns the
representation and pre-polar construction diagnostics as separate values.
"""
function build_canonical_band_representation(
    native,
    energies_ev::Matrix{Float64},
    operations::Vector{SymmetryOperation},
    degeneracy_tolerance_ev::Float64;
    symmetry_inventory = nothing,
    plane_wave_convention::Symbol = :canonical,
    diagnostic_outer_masks = nothing,
    diagnostic_frozen_masks = nothing,
)
    isempty(operations) && throw(ArgumentError("INVALID_SYMMETRY_ACTION: operation list is empty"))
    validate_canonical_antiunitary_channel(native, operations)
    nk = length(native.kpoints)
    nb = size(first(native.kpoints).coefficients, 1)
    size(energies_ev) == (nb, nk) ||
        throw(ArgumentError("EIG dimensions disagree with native wavefunction bands"))
    all(isfinite, energies_ev) || throw(ArgumentError("EIG contains non-finite values"))
    (diagnostic_outer_masks === nothing) == (diagnostic_frozen_masks === nothing) ||
        throw(ArgumentError("raw diagnostic outer and frozen masks must be supplied together"))
    if diagnostic_outer_masks !== nothing
        length(diagnostic_outer_masks) == nk == length(diagnostic_frozen_masks) ||
            throw(ArgumentError("raw diagnostic masks disagree with the k-point count"))
        all(mask -> length(mask) == nb, diagnostic_outer_masks) &&
        all(mask -> length(mask) == nb, diagnostic_frozen_masks) ||
            throw(ArgumentError("raw diagnostic masks disagree with the band count"))
    end
    kpoints = Matrix{Float64}(undef, nk, 3)
    for (kpoint_index, point) in enumerate(native.kpoints)
        kpoints[kpoint_index, :] .= point.k_fractional
    end
    mapping, shifts = build_canonical_kpoint_action(operations, kpoints; tolerance = 1.0e-8)
    sewing = Array{ComplexF64, 4}(undef, nb, nb, length(operations), nk)
    raw_diagnostics = Any[]
    for source_kpoint in 1:nk, operation_index in eachindex(operations)
        target_kpoint = mapping[operation_index, source_kpoint]
        diagnostic_scopes = if diagnostic_outer_masks === nothing
            nothing
        else
            (
                (scope = :full, source_indices = collect(1:nb), target_indices = collect(1:nb)),
                (
                    scope = :outer,
                    source_indices = findall(diagnostic_outer_masks[source_kpoint]),
                    target_indices = findall(diagnostic_outer_masks[target_kpoint]),
                ),
                (
                    scope = :frozen,
                    source_indices = findall(diagnostic_frozen_masks[source_kpoint]),
                    target_indices = findall(diagnostic_frozen_masks[target_kpoint]),
                ),
                (
                    scope = :outside,
                    source_indices = findall(.!diagnostic_outer_masks[source_kpoint]),
                    target_indices = findall(.!diagnostic_outer_masks[target_kpoint]),
                ),
            )
        end
        first_diagnostic = length(raw_diagnostics) + 1
        try
            sewing[:, :, operation_index, source_kpoint] .= canonical_plane_wave_sewing_matrix(
                native.kpoints[source_kpoint],
                native.kpoints[target_kpoint],
                operations[operation_index],
                @view(shifts[:, operation_index, source_kpoint]),
                degeneracy_tolerance_ev;
                convention = plane_wave_convention,
                raw_diagnostics,
                diagnostic_scopes,
            )
            for diagnostic in @view(raw_diagnostics[first_diagnostic:end])
                diagnostic["source_kpoint"] = source_kpoint
                diagnostic["target_kpoint"] = target_kpoint
                diagnostic["operation"] = operation_index
                diagnostic["operation_key"] =
                    canonical_band_operation_key(operations[operation_index])
            end
        catch exception
            throw(
                ArgumentError(
                    "band representation failed at source k-point $(source_kpoint), target " *
                    "k-point $(target_kpoint), operation $(operation_index): $(sprint(showerror, exception))",
                ),
            )
        end
    end
    irreducible, full_to_irreducible, full_to_operation = canonical_irreducible_star_plan(mapping)
    block_diagnostics = filter(diagnostic -> diagnostic["kind"] == "energy_block", raw_diagnostics)
    full_diagnostics = filter(diagnostic -> diagnostic["kind"] == "full", raw_diagnostics)
    conventions = Dict{String, String}(
        "bloch_phase" => "exp(+i(k+G).r)",
        "center_phase" => "exp(-2pi*i*k.T)",
        "fourier" => "H(k)=sum_R exp(+2pi*i*k.R) H(R)",
        "lattice" => "cartesian row vectors in Angstrom",
        "kpoints" => "fractional row vectors",
        "sewing" => "rows target bands, columns source bands",
        "sewing_definition" => "g|psi_n(k)>=sum_m |psi_m(k_g)> B_g(k)[m,n]",
        "k_action" => "s_g*W_g^(-T)*k=k_g+G_g(k), s_g=(-1)^a_g",
        "plane_wave_convention" => String(plane_wave_convention),
        "canonical_builder" => "SymmetryFoundation._canonical_build_band_representation/v1",
        "sewing_backend" => "coefficient_mapping",
        "sewing_metric" => "pseudo_coefficient_linear_map",
        "raw_sewing_minimum_singular_value" =>
            string(minimum(diagnostic["sigma_min"] for diagnostic in block_diagnostics)),
        "raw_sewing_maximum_condition_estimate" => string(
            maximum(diagnostic["condition_estimate"] for diagnostic in block_diagnostics),
        ),
        "raw_sewing_maximum_unitarity_residual" => string(
            maximum(diagnostic["unitarity_residual"] for diagnostic in block_diagnostics),
        ),
        "raw_full_sewing_maximum_unitarity_residual" => string(
            maximum(diagnostic["unitarity_residual"] for diagnostic in full_diagnostics),
        ),
    )
    metadata =
        hasproperty(native, :source_metadata) ? native.source_metadata : Dict{String, String}()
    merge!(conventions, metadata)
    if symmetry_inventory !== nothing
        conventions["magnetic_structure"] = string(symmetry_inventory.magnetic)
        conventions["msg_type"] = string(symmetry_inventory.msg_type)
        conventions["msg_uni_number"] =
            symmetry_inventory.uni_number === nothing ? "unavailable" :
            string(symmetry_inventory.uni_number)
        conventions["msg_hall_number"] = string(symmetry_inventory.hall_number)
        conventions["msg_unitary_operation_count"] =
            string(symmetry_inventory.unitary_operation_count)
        conventions["msg_antiunitary_operation_count"] =
            string(symmetry_inventory.antiunitary_operation_count)
        conventions["magnetic_symmetry_tolerance"] = string(symmetry_inventory.symmetry_tolerance)
    end
    representation = BandRepresentation(
        "1.5",
        native.source_code,
        native.spinor,
        native.structure.lattice,
        native.reciprocal_lattice,
        native.mp_grid,
        kpoints,
        energies_ev,
        operations,
        mapping,
        shifts,
        sewing,
        canonical_band_block_labels(energies_ev, degeneracy_tolerance_ev),
        irreducible,
        full_to_irreducible,
        full_to_operation;
        conventions,
        input_sha256 = native.input_sha256,
    )
    return (representation = representation, construction_diagnostics = raw_diagnostics)
end
