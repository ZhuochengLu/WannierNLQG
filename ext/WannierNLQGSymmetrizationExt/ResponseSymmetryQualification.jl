const RESPONSE_W90_QUALIFICATION_SCHEMA = "wanniernlqg.response-symmetry-qualification/1.0"

# Convert a JSON number matrix without accepting ragged or non-finite input.
function _response_qualification_matrix(value, ::Type{T}, name::AbstractString) where {T}
    value isa AbstractVector && length(value) == 3 ||
        throw(ArgumentError("$(name) must have three rows"))
    output = Matrix{T}(undef, 3, 3)
    for row in 1:3
        value[row] isa AbstractVector && length(value[row]) == 3 ||
            throw(ArgumentError("$(name) row $(row) must have three entries"))
        for column in 1:3
            output[row, column] = convert(T, value[row][column])
        end
    end
    all(isfinite, output) || throw(ArgumentError("$(name) contains non-finite values"))
    return output
end

# Recover the full Seitz inventory, not only its deduplicated point group.
function _response_qualification_operations(payload::AbstractDict)
    symmetry = get(payload, "symmetry", nothing)
    symmetry isa AbstractDict || throw(ArgumentError("artifact has no symmetry object"))
    encoded = get(symmetry, "space_group_operations", nothing)
    encoded isa AbstractVector && !isempty(encoded) ||
        throw(ArgumentError("artifact has no full Seitz operation inventory"))
    operations = SymmetryOperation[]
    for (index, item) in enumerate(encoded)
        item isa AbstractDict || throw(ArgumentError("operation $(index) is not an object"))
        rotation = _response_qualification_matrix(
            get(item, "rotation_fractional", nothing),
            Int,
            "operation $(index) rotation_fractional",
        )
        cartesian = _response_qualification_matrix(
            get(item, "rotation_cartesian_effective", nothing),
            Float64,
            "operation $(index) rotation_cartesian_effective",
        )
        translation = Float64.(get(item, "translation_fractional", Float64[]))
        length(translation) == 3 ||
            throw(ArgumentError("operation $(index) translation must have three entries"))
        all(isfinite, translation) ||
            throw(ArgumentError("operation $(index) translation is non-finite"))
        antiunitary = get(item, "antiunitary", nothing)
        antiunitary isa Bool ||
            throw(ArgumentError("operation $(index) antiunitary flag is invalid"))
        push!(operations, SymmetryOperation(rotation, translation, cartesian, antiunitary))
    end
    return operations
end

# Match every transformed CHK k point to exactly one periodic mesh point.
function _response_qualification_kpoint_map(
    kpoints::Matrix{Float64},
    operations::Vector{SymmetryOperation};
    tolerance::Float64,
)
    num_operations = length(operations)
    kpoint_count = size(kpoints, 1)
    mapping = Matrix{Int}(undef, num_operations, kpoint_count)
    for (operation_index, operation) in enumerate(operations)
        reciprocal_rotation = transpose(inv(operation.rotation_fractional))
        sign = operation.antiunitary ? -1.0 : 1.0
        used = falses(kpoint_count)
        for source in 1:kpoint_count
            transformed = sign .* (reciprocal_rotation * @view(kpoints[source, :]))
            matches = Int[]
            for target in 1:kpoint_count
                difference = transformed - @view(kpoints[target, :])
                maximum(abs, difference - round.(difference)) <= tolerance && push!(matches, target)
            end
            length(matches) == 1 || throw(
                ArgumentError(
                    "operation $(operation_index), k point $(source) has $(length(matches)) periodic matches",
                ),
            )
            target = only(matches)
            used[target] && throw(
                ArgumentError("operation $(operation_index) k-point mapping is not a bijection"),
            )
            used[target] = true
            mapping[operation_index, source] = target
        end
        all(used) || throw(ArgumentError("operation $(operation_index) misses a k point"))
    end
    return mapping
end

# Evaluate the projection-basis action at one source/target mesh pair.
function _response_trial_action(
    plan::WannierSymmetryPlan,
    operation_index::Int,
    target_kpoint::AbstractVector,
)
    action = Matrix(@view plan.representation_matrices[:, :, operation_index])
    for source_wannier in axes(action, 2)
        shift = @view plan.wannier_shifts[:, source_wannier, operation_index]
        action[:, source_wannier] .*= cis(-2.0pi * dot(target_kpoint, shift))
    end
    return action
end

# Return a stable finite relative residual for matrices.
function _response_relative_matrix_residual(left, right)
    return opnorm(left - right) / max(opnorm(left), opnorm(right), eps(Float64))
end

# Derive physical sewing matrices directly from AMN and CHK without polar repair.
function _response_build_actual_sewing(
    amn,
    chk,
    plan::WannierSymmetryPlan,
    operations::Vector{SymmetryOperation},
    kpoint_map::Matrix{Int};
    chk_semiunitarity_tolerance::Float64,
    amn_minimum_singular_value::Float64,
    amn_maximum_condition_number::Float64,
)
    band_count = amn.num_bands
    wannier_count = amn.num_wannier
    band_count == wannier_count || throw(
        ArgumentError(
            "AMN-derived inverse sewing currently requires num_bands=num_wannier; got $(band_count) and $(wannier_count)",
        ),
    )
    identity_wannier = Matrix{ComplexF64}(I, wannier_count, wannier_count)
    maximum_chk_semiunitarity = 0.0
    worst_chk_kpoint = 0
    minimum_amn_singular_value = Inf
    maximum_amn_condition_number = 0.0
    worst_amn_kpoint = 0
    for kpoint in 1:chk.num_kpts
        gauge = Matrix(@view chk.v_matrix[:, :, kpoint])
        residual = opnorm(gauge' * gauge - identity_wannier)
        if residual > maximum_chk_semiunitarity
            maximum_chk_semiunitarity = residual
            worst_chk_kpoint = kpoint
        end
        singular_values = svdvals(Matrix(@view amn.data[:, :, kpoint]))
        local_minimum = minimum(singular_values)
        local_condition = maximum(singular_values) / max(local_minimum, eps(Float64))
        if local_minimum < minimum_amn_singular_value
            minimum_amn_singular_value = local_minimum
            worst_amn_kpoint = kpoint
        end
        maximum_amn_condition_number = max(maximum_amn_condition_number, local_condition)
    end
    input_pass =
        maximum_chk_semiunitarity <= chk_semiunitarity_tolerance &&
        minimum_amn_singular_value >= amn_minimum_singular_value &&
        maximum_amn_condition_number <= amn_maximum_condition_number

    num_operations = length(operations)
    kpoint_count = chk.num_kpts
    band_sewing = Array{ComplexF64, 4}(undef, band_count, band_count, num_operations, kpoint_count)
    wannier_sewing =
        Array{ComplexF64, 4}(undef, wannier_count, wannier_count, num_operations, kpoint_count)
    maximum_subspace_closure = 0.0
    maximum_wannier_unitarity = 0.0
    worst_closure = Dict{String, Any}()
    worst_unitarity = Dict{String, Any}()
    for source in 1:kpoint_count, operation_index in 1:num_operations
        operation = operations[operation_index]
        target = kpoint_map[operation_index, source]
        trial_action = _response_trial_action(plan, operation_index, @view(chk.kpt_red[target, :]))
        source_amn = Matrix(@view amn.data[:, :, source])
        right_amn = operation.antiunitary ? conj(source_amn) : source_amn
        target_amn = Matrix(@view amn.data[:, :, target])
        # This is the physical formula. Right division performs the declared
        # inverse; no SVD truncation or polar projection is permitted here.
        d_matrix = target_amn * trial_action / right_amn
        band_sewing[:, :, operation_index, source] .= d_matrix

        source_gauge = Matrix(@view chk.v_matrix[:, :, source])
        right_gauge = operation.antiunitary ? conj(source_gauge) : source_gauge
        target_gauge = Matrix(@view chk.v_matrix[:, :, target])
        transformed = d_matrix * right_gauge
        closure = transformed - target_gauge * (target_gauge' * transformed)
        closure_residual = opnorm(closure)
        if closure_residual > maximum_subspace_closure
            maximum_subspace_closure = closure_residual
            worst_closure = Dict(
                "operation" => operation_index,
                "source_kpoint" => source,
                "target_kpoint" => target,
            )
        end
        sewing = target_gauge' * transformed
        wannier_sewing[:, :, operation_index, source] .= sewing
        unitarity = max(
            opnorm(sewing' * sewing - identity_wannier),
            opnorm(sewing * sewing' - identity_wannier),
        )
        if unitarity > maximum_wannier_unitarity
            maximum_wannier_unitarity = unitarity
            worst_unitarity = Dict(
                "operation" => operation_index,
                "source_kpoint" => source,
                "target_kpoint" => target,
            )
        end
    end
    return (
        band_sewing = band_sewing,
        wannier_sewing = wannier_sewing,
        input_pass = input_pass,
        maximum_chk_semiunitarity = maximum_chk_semiunitarity,
        minimum_amn_singular_value = minimum_amn_singular_value,
        maximum_amn_condition_number = maximum_amn_condition_number,
        maximum_subspace_closure = maximum_subspace_closure,
        maximum_wannier_unitarity = maximum_wannier_unitarity,
        worst_chk_kpoint = worst_chk_kpoint,
        worst_amn_kpoint = worst_amn_kpoint,
        worst_closure = worst_closure,
        worst_unitarity = worst_unitarity,
    )
end

# Evaluate the antiunitary-aware sewing group law on the complete native mesh.
function _response_sewing_group_law(
    sewing::Array{ComplexF64, 4},
    chk,
    operations::Vector{SymmetryOperation},
    kpoint_map::Matrix{Int};
    seitz_tolerance::Float64,
    spinor::Bool,
)
    table = build_band_product_table(operations, spinor; tolerance = seitz_tolerance)
    maximum_residual = 0.0
    worst = Dict{String, Any}()
    for source in 1:chk.num_kpts, left in eachindex(operations), right in eachindex(operations)
        product = table.product_indices[left, right]
        intermediate = kpoint_map[right, source]
        right_matrix = Matrix(@view sewing[:, :, right, source])
        operations[left].antiunitary && (right_matrix = conj(right_matrix))
        target = kpoint_map[product, source]
        factor =
            table.spinor_factors[left, right] * cis(
                -2.0pi * dot(
                    @view(chk.kpt_red[target, :]),
                    @view(table.translation_differences[:, left, right]),
                ),
            )
        residual = opnorm(
            @view(sewing[:, :, left, intermediate]) * right_matrix -
            factor .* @view(sewing[:, :, product, source]),
        )
        if residual > maximum_residual
            maximum_residual = residual
            worst = Dict(
                "left_operation" => left,
                "right_operation" => right,
                "product_operation" => product,
                "source_kpoint" => source,
            )
        end
    end
    return maximum_residual, worst
end

# Check the raw TB Hamiltonian against the unmodified AMN-derived sewing.
function _response_hamiltonian_covariance(
    model,
    chk,
    sewing::Array{ComplexF64, 4},
    operations::Vector{SymmetryOperation},
    kpoint_map::Matrix{Int};
    absolute_tolerance::Float64,
    relative_tolerance::Float64,
)
    hamiltonian =
        _gauge_aware_r_to_q(model.hamiltonian_r, model.r_vectors, model.r_degeneracies, chk.kpt_red)
    maximum_absolute = 0.0
    maximum_mixed_ratio = 0.0
    spectral_square_sum = 0.0
    spectral_count = 0
    maximum_spectral = 0.0
    worst = Dict{String, Any}()
    for source in 1:chk.num_kpts, operation_index in eachindex(operations)
        target = kpoint_map[operation_index, source]
        source_hamiltonian = Matrix(@view hamiltonian[:, :, source])
        operations[operation_index].antiunitary && (source_hamiltonian = conj(source_hamiltonian))
        action = @view sewing[:, :, operation_index, source]
        predicted = action * source_hamiltonian * action'
        observed = @view hamiltonian[:, :, target]
        delta = observed - predicted
        local_absolute = maximum(abs, delta)
        local_scale = max.(abs.(observed), abs.(predicted))
        local_mixed =
            maximum(abs.(delta) ./ (absolute_tolerance .+ relative_tolerance .* local_scale))
        if local_mixed > maximum_mixed_ratio
            maximum_mixed_ratio = local_mixed
            maximum_absolute = local_absolute
            location =
                argmax(abs.(delta) ./ (absolute_tolerance .+ relative_tolerance .* local_scale))
            worst = Dict(
                "operation" => operation_index,
                "source_kpoint" => source,
                "target_kpoint" => target,
                "row" => location[1],
                "column" => location[2],
            )
        else
            maximum_absolute = max(maximum_absolute, local_absolute)
        end
        source_energies = eigvals(Hermitian((@view hamiltonian[:, :, source]), :U))
        target_energies = eigvals(Hermitian(observed, :U))
        spectral_delta = target_energies - source_energies
        maximum_spectral = max(maximum_spectral, maximum(abs, spectral_delta))
        spectral_square_sum += sum(abs2, spectral_delta)
        spectral_count += length(spectral_delta)
    end
    return Dict(
        "status" => maximum_mixed_ratio <= 1.0 ? "PASS" : "FAIL",
        "absolute_tolerance_ev" => absolute_tolerance,
        "relative_tolerance" => relative_tolerance,
        "maximum_absolute_residual_ev" => maximum_absolute,
        "maximum_mixed_gate_ratio" => maximum_mixed_ratio,
        "kstar_spectrum_maximum_error_ev" => maximum_spectral,
        "kstar_spectrum_rms_error_ev" => sqrt(spectral_square_sum / spectral_count),
        "worst" => worst,
        "input_tb_was_symmetrized" => false,
    )
end

# Check raw DFT-gauge MMN overlaps, including antiunitary conjugation.
function _response_mmn_covariance(
    mmn,
    chk,
    band_sewing::Array{ComplexF64, 4},
    operations::Vector{SymmetryOperation},
    kpoint_map::Matrix{Int};
    tolerance::Float64,
)
    edge_map = _gauge_aware_edge_map(chk, mmn, kpoint_map, operations; tolerance = 1.0e-8)
    maximum_absolute = 0.0
    maximum_relative = 0.0
    worst = Dict{String, Any}()
    for source in 1:chk.num_kpts,
        neighbor in 1:mmn.num_neighbors,
        operation_index in eachindex(operations)

        endpoint = mmn.neighbors[neighbor, source]
        target_source = kpoint_map[operation_index, source]
        target_neighbor = edge_map[neighbor, source, operation_index]
        source_overlap = Matrix(@view mmn.data[:, :, neighbor, source])
        operations[operation_index].antiunitary && (source_overlap = conj(source_overlap))
        predicted =
            @view(band_sewing[:, :, operation_index, source]) *
            source_overlap *
            @view(band_sewing[:, :, operation_index, endpoint])'
        observed = @view mmn.data[:, :, target_neighbor, target_source]
        local_absolute = maximum(abs, observed - predicted)
        local_relative = _response_relative_matrix_residual(observed, predicted)
        maximum_absolute = max(maximum_absolute, local_absolute)
        if local_relative > maximum_relative
            maximum_relative = local_relative
            worst = Dict(
                "operation" => operation_index,
                "source_kpoint" => source,
                "source_neighbor" => neighbor,
                "target_kpoint" => target_source,
                "target_neighbor" => target_neighbor,
            )
        end
    end
    return Dict(
        "status" => maximum_relative <= tolerance ? "PASS" : "FAIL",
        "tolerance" => tolerance,
        "maximum_absolute_residual" => maximum_absolute,
        "maximum_relative_residual" => maximum_relative,
        "worst" => worst,
    )
end

# Hash one qualification input without loading it into the result payload.
function _response_qualification_sha256(path::AbstractString)
    return open(path, "r") do io
        bytes2hex(SHA.sha256(io))
    end
end

# Validate and normalize one externally supplied SHA-256 string.
function _response_qualification_sha256_string(value, context::AbstractString)
    normalized = lowercase(strip(String(value)))
    length(normalized) == 64 &&
    all(character -> character in ('0':'9') || character in ('a':'f'), normalized) ||
        throw(ArgumentError("$(context) must be a 64-character hexadecimal SHA-256 digest"))
    return normalized
end

# Atomically write one qualification payload with an explicit overwrite contract.
function _write_response_qualification_json(path::AbstractString, payload; overwrite::Bool)
    output = abspath(path)
    ispath(output) &&
        !overwrite &&
        throw(ArgumentError("qualification output already exists: $(output)"))
    mkpath(dirname(output))
    temporary, io = mktemp(dirname(output); cleanup = false)
    try
        JSON3.pretty(io, payload)
        write(io, '\n')
        close(io)
        mv(temporary, output; force = overwrite)
    catch
        isopen(io) && close(io)
        isfile(temporary) && rm(temporary; force = true)
        rethrow()
    end
    return output
end

# Recompute the structural gate from detailed complete-contract checks; never trust a summary flag alone.
function _response_qualification_structure_pass(payload::AbstractDict)
    symmetry = get(payload, "symmetry", nothing)
    symmetry isa AbstractDict || return false
    checks = get(symmetry, "checks", nothing)
    checks isa AbstractDict || return false
    all(get(checks, name, false) === true for name in ("identity", "inverse", "closure")) ||
        return false
    for name in ("space_group", "point_group", "tolerance_stability")
        check = get(checks, name, nothing)
        check isa AbstractDict && get(check, "pass", false) === true || return false
    end
    atom_mapping = get(checks, "atom_mapping", nothing)
    atom_mapping isa AbstractDict &&
    get(atom_mapping, "pass", false) === true &&
    get(atom_mapping, "bijection", false) === true || return false
    cartesian = get(checks, "cartesian_rotation", nothing)
    cartesian isa AbstractDict && get(cartesian, "production_pass", false) === true || return false
    return true
end

# Normalize externally supplied validator output before it can enter a formal gate.
function _response_qualification_validation_evidence(
    evidence,
    name::AbstractString,
    input_hash_key::AbstractString,
)
    evidence isa AbstractDict || throw(ArgumentError("$(name) evidence must be an object"))
    normalized = Dict{String, Any}(String(key) => value for (key, value) in evidence)
    status = uppercase(strip(String(get(normalized, "status", ""))))
    status in ("PASS", "FAIL") ||
        throw(ArgumentError("$(name) evidence status must be PASS or FAIL"))
    pass_value = get(normalized, "pass", status == "PASS")
    pass_value isa Bool || throw(ArgumentError("$(name) evidence pass field must be Boolean"))
    pass_value == (status == "PASS") ||
        throw(ArgumentError("$(name) evidence status and pass fields disagree"))
    normalized["status"] = status
    normalized["pass"] = pass_value
    if status == "PASS"
        digest = get(normalized, input_hash_key, nothing)
        digest isa AbstractString ||
            throw(ArgumentError("PASS $(name) evidence requires $(input_hash_key)"))
        normalized[input_hash_key] =
            _response_qualification_sha256_string(digest, "$(name) evidence $(input_hash_key)")
    end
    normalized["evidence_sha256"] = bytes2hex(SHA.sha256(JSON3.write(normalized)))
    return normalized
end

# Attach integrand and full-grid evidence without allowing a downstream PASS to bypass an upstream FAIL.
function _response_qualification_apply_downstream_evidence!(
    formal_gates::Dict{String, Any},
    diagnostic_lane::Dict{String, Any},
    upstream_pass::Bool,
    integrand_covariance_evidence,
    full_grid_consistency_evidence;
    diagnostic_continue::Bool,
)
    integrand =
        integrand_covariance_evidence === nothing ? nothing :
        _response_qualification_validation_evidence(
            integrand_covariance_evidence,
            "integrand covariance",
            "input_sha256",
        )
    full_grid =
        full_grid_consistency_evidence === nothing ? nothing :
        _response_qualification_validation_evidence(
            full_grid_consistency_evidence,
            "full-grid consistency",
            "same_input_sha256",
        )
    full_grid !== nothing &&
        integrand === nothing &&
        throw(
            ArgumentError("full-grid consistency evidence requires integrand covariance evidence"),
        )

    if !upstream_pass
        if diagnostic_continue
            integrand === nothing || (
                diagnostic_lane["integrand_covariance"] =
                    merge(integrand, Dict("qualification" => "INDICATIVE_ONLY"))
            )
            full_grid === nothing || (
                diagnostic_lane["full_grid_consistency"] =
                    merge(full_grid, Dict("qualification" => "INDICATIVE_ONLY"))
            )
        end
        return nothing
    end

    if integrand === nothing
        formal_gates["integrand_covariance"] = Dict(
            "status" => "NOT_RUN",
            "reason" => "AWAITING_STREAMED_INTEGRAND_COVARIANCE_EVIDENCE",
        )
        return nothing
    end
    formal_gates["integrand_covariance"] = integrand
    if integrand["status"] != "PASS"
        formal_gates["full_grid_consistency"] = Dict("status" => "NOT_RUN_DOWNSTREAM_BLOCKED")
        return nothing
    end
    formal_gates["full_grid_consistency"] =
        full_grid === nothing ?
        Dict(
            "status" => "NOT_RUN",
            "reason" => "AWAITING_SAME_INPUT_FULL_GRID_COMPARISON_EVIDENCE",
        ) : full_grid
    return nothing
end

"""
Qualify one complete-contract artifact against the declared Wannier90 gauge chain.

The AMN band sewing is exactly
`A(gk) * D_g(k) / A(k)^(*)`; the final Wannier sewing is
`V(gk)' * d_g(k) * V(k)^(*)`. No polar projection, Hamiltonian projection, or
TB symmetrization is applied. Formal downstream gates stop after the first
failure; optional diagnostic continuation is kept in a separate lane.
"""
function qualify_response_symmetry_wannier90(
    artifact_file::AbstractString;
    win_file::AbstractString,
    amn_file::AbstractString,
    chk_file::AbstractString,
    mmn_file::AbstractString,
    tb_file::AbstractString,
    output_file::Union{Nothing, AbstractString} = nothing,
    qualified_artifact_file::Union{Nothing, AbstractString} = nothing,
    diagnostic_continue::Bool = false,
    integrand_covariance_evidence = nothing,
    full_grid_consistency_evidence = nothing,
    representation_tolerance::Real = 1.0e-5,
    kpoint_tolerance::Real = 1.0e-8,
    seitz_translation_tolerance::Real = 1.0e-5,
    chk_semiunitarity_tolerance::Real = 1.0e-10,
    amn_minimum_singular_value::Real = 1.0e-5,
    amn_maximum_condition_number::Real = 1.0e8,
    sewing_tolerance::Real = 1.0e-6,
    group_law_tolerance::Real = 1.0e-5,
    mmn_covariance_tolerance::Real = 1.0e-6,
    hamiltonian_absolute_tolerance_ev::Real = 1.0e-10,
    hamiltonian_relative_tolerance::Real = 1.0e-8,
    overwrite::Bool = false,
)
    artifact_path = abspath(artifact_file)
    paths = Dict(
        "win" => abspath(win_file),
        "amn" => abspath(amn_file),
        "chk" => abspath(chk_file),
        "mmn" => abspath(mmn_file),
        "tb" => abspath(tb_file),
    )
    isfile(artifact_path) || throw(ArgumentError("artifact does not exist: $(artifact_path)"))
    for (name, path) in paths
        isfile(path) || throw(ArgumentError("$(name) input does not exist: $(path)"))
    end
    thresholds = Dict(
        "representation_tolerance" => Float64(representation_tolerance),
        "kpoint_tolerance" => Float64(kpoint_tolerance),
        "seitz_translation_tolerance" => Float64(seitz_translation_tolerance),
        "chk_semiunitarity" => Float64(chk_semiunitarity_tolerance),
        "amn_minimum_singular_value" => Float64(amn_minimum_singular_value),
        "amn_maximum_condition_number" => Float64(amn_maximum_condition_number),
        "sewing_unitarity_and_closure" => Float64(sewing_tolerance),
        "sewing_group_law" => Float64(group_law_tolerance),
        "mmn_covariance" => Float64(mmn_covariance_tolerance),
        "hamiltonian_absolute_ev" => Float64(hamiltonian_absolute_tolerance_ev),
        "hamiltonian_relative" => Float64(hamiltonian_relative_tolerance),
    )
    all(value -> isfinite(value) && value > 0.0, values(thresholds)) ||
        throw(ArgumentError("all response qualification thresholds must be positive and finite"))

    payload = JSON3.read(read(artifact_path, String), Dict{String, Any})
    get(payload, "schema", nothing) in
    (RESPONSE_SYMMETRY_ARTIFACT_SCHEMA, "wanniernlqg.response-symmetry/1.1") || throw(
        ArgumentError("Wannier90 qualification requires a complete-contract response artifact"),
    )
    artifact = read_response_symmetry_artifact(artifact_path)
    artifact.cartesian_rotation_policy == "group_invariant_metric" ||
        throw(ArgumentError("Wannier90 qualification requires group-invariant effective rotations"))
    structure_pass = _response_qualification_structure_pass(payload)
    operations = _response_qualification_operations(payload)
    win = read_wannier_win(paths["win"])
    amn = read_wannier_amn(paths["amn"])
    chk = read_wannier_chk(paths["chk"])
    mmn = read_wannier_mmn(paths["mmn"])
    model = read_wannier_tb(paths["tb"])

    dimensions = Dict(
        "num_bands" => chk.num_bands,
        "num_wannier" => chk.num_orbitals,
        "num_kpoints" => chk.num_kpts,
        "mp_grid" => collect(chk.mp_grid),
        "mmn_num_neighbors" => mmn.num_neighbors,
        "tb_num_r_vectors" => model.num_r_vectors,
        "spinor" => win.spinors,
    )
    dimension_pass =
        win.num_bands == amn.num_bands == chk.num_bands == mmn.num_bands &&
        win.num_wannier == amn.num_wannier == chk.num_orbitals == model.num_orbitals &&
        win.mp_grid == chk.mp_grid &&
        amn.num_kpts == chk.num_kpts == mmn.num_kpts &&
        maximum(abs, win.lattice - chk.real_lattice) <= 1.0e-8 &&
        maximum(abs, model.lattice - chk.real_lattice) <= 1.0e-8
    dimensions["status"] = dimension_pass ? "PASS" : "FAIL"

    input_hashes = Dict(
        name =>
            Dict("path" => basename(path), "sha256" => _response_qualification_sha256(path)) for
        (name, path) in paths
    )
    formal_gates = Dict{String, Any}(
        "structure_magnetic_symmetry" => Dict("status" => structure_pass ? "PASS" : "FAIL"),
        "wannier90_gauge" => Dict(
            "status" =>
                structure_pass ? (dimension_pass ? "PENDING" : "FAIL") :
                "NOT_RUN_DOWNSTREAM_BLOCKED",
        ),
        "hamiltonian_covariance" => Dict("status" => "NOT_RUN_DOWNSTREAM_BLOCKED"),
        "mmn_covariance" => Dict("status" => "NOT_RUN_DOWNSTREAM_BLOCKED"),
        "integrand_covariance" => Dict("status" => "NOT_RUN_DOWNSTREAM_BLOCKED"),
        "full_grid_consistency" => Dict("status" => "NOT_RUN_DOWNSTREAM_BLOCKED"),
    )
    diagnostic_lane = Dict{String, Any}()
    sewing_evidence = Dict{String, Any}()
    hamiltonian_evidence = Dict{String, Any}("status" => "NOT_RUN_DOWNSTREAM_BLOCKED")
    mmn_evidence = Dict{String, Any}("status" => "NOT_RUN_DOWNSTREAM_BLOCKED")

    if structure_pass && dimension_pass
        basis =
            build_wannier_projection_basis(win; tolerance = thresholds["representation_tolerance"])
        plan = build_wannier_symmetry_plan(
            basis,
            operations;
            tolerance = thresholds["representation_tolerance"],
        )
        kpoint_map = _response_qualification_kpoint_map(
            chk.kpt_red,
            operations;
            tolerance = thresholds["kpoint_tolerance"],
        )
        actual = _response_build_actual_sewing(
            amn,
            chk,
            plan,
            operations,
            kpoint_map;
            chk_semiunitarity_tolerance = thresholds["chk_semiunitarity"],
            amn_minimum_singular_value = thresholds["amn_minimum_singular_value"],
            amn_maximum_condition_number = thresholds["amn_maximum_condition_number"],
        )
        group_law, worst_group = _response_sewing_group_law(
            actual.wannier_sewing,
            chk,
            operations,
            kpoint_map;
            seitz_tolerance = thresholds["seitz_translation_tolerance"],
            spinor = win.spinors,
        )
        sewing_pass =
            actual.input_pass &&
            actual.maximum_subspace_closure <= thresholds["sewing_unitarity_and_closure"] &&
            actual.maximum_wannier_unitarity <= thresholds["sewing_unitarity_and_closure"] &&
            group_law <= thresholds["sewing_group_law"]
        sewing_evidence = Dict(
            "status" => sewing_pass ? "PASS" : "FAIL",
            "formula" => "d=A(gk)D_g(k)[A(k)^(*)]^-1; U=V(gk)^dagger d V(k)^(*)",
            "polar_repair_applied" => false,
            "chk_semiunitarity_opnorm" => actual.maximum_chk_semiunitarity,
            "amn_minimum_singular_value" => actual.minimum_amn_singular_value,
            "amn_maximum_condition_number" => actual.maximum_amn_condition_number,
            "subspace_closure_opnorm" => actual.maximum_subspace_closure,
            "wannier_sewing_unitarity_opnorm" => actual.maximum_wannier_unitarity,
            "wannier_sewing_group_law_opnorm" => group_law,
            "worst_chk_kpoint" => actual.worst_chk_kpoint,
            "worst_amn_kpoint" => actual.worst_amn_kpoint,
            "worst_closure" => actual.worst_closure,
            "worst_unitarity" => actual.worst_unitarity,
            "worst_group_law" => worst_group,
        )
        formal_gates["wannier90_gauge"] = sewing_evidence

        if sewing_pass
            hamiltonian_evidence = _response_hamiltonian_covariance(
                model,
                chk,
                actual.wannier_sewing,
                operations,
                kpoint_map;
                absolute_tolerance = thresholds["hamiltonian_absolute_ev"],
                relative_tolerance = thresholds["hamiltonian_relative"],
            )
            formal_gates["hamiltonian_covariance"] = hamiltonian_evidence
            if hamiltonian_evidence["status"] == "PASS"
                mmn_evidence = _response_mmn_covariance(
                    mmn,
                    chk,
                    actual.band_sewing,
                    operations,
                    kpoint_map;
                    tolerance = thresholds["mmn_covariance"],
                )
                formal_gates["mmn_covariance"] = mmn_evidence
            elseif diagnostic_continue
                mmn_evidence = _response_mmn_covariance(
                    mmn,
                    chk,
                    actual.band_sewing,
                    operations,
                    kpoint_map;
                    tolerance = thresholds["mmn_covariance"],
                )
                diagnostic_lane["mmn_covariance"] =
                    merge(mmn_evidence, Dict("qualification" => "INDICATIVE_ONLY"))
            end
        elseif diagnostic_continue
            hamiltonian_evidence = _response_hamiltonian_covariance(
                model,
                chk,
                actual.wannier_sewing,
                operations,
                kpoint_map;
                absolute_tolerance = thresholds["hamiltonian_absolute_ev"],
                relative_tolerance = thresholds["hamiltonian_relative"],
            )
            mmn_evidence = _response_mmn_covariance(
                mmn,
                chk,
                actual.band_sewing,
                operations,
                kpoint_map;
                tolerance = thresholds["mmn_covariance"],
            )
            diagnostic_lane["hamiltonian_covariance"] =
                merge(hamiltonian_evidence, Dict("qualification" => "INDICATIVE_ONLY"))
            diagnostic_lane["mmn_covariance"] =
                merge(mmn_evidence, Dict("qualification" => "INDICATIVE_ONLY"))
        end
    end

    upstream_downstream_pass = get(formal_gates["mmn_covariance"], "status", "") == "PASS"
    _response_qualification_apply_downstream_evidence!(
        formal_gates,
        diagnostic_lane,
        upstream_downstream_pass,
        integrand_covariance_evidence,
        full_grid_consistency_evidence;
        diagnostic_continue,
    )
    required_gate_names = (
        "structure_magnetic_symmetry",
        "wannier90_gauge",
        "hamiltonian_covariance",
        "mmn_covariance",
        "integrand_covariance",
        "full_grid_consistency",
    )
    production_eligible =
        all(get(formal_gates[name], "status", "") == "PASS" for name in required_gate_names)
    overall_status =
        !structure_pass ? "STRUCTURE_FAIL" : production_eligible ? "PASS" : "PHYSICS_HOLD"
    source_artifact_sha256 = _response_qualification_sha256(artifact_path)
    seal_evidence_sha256 = bytes2hex(
        SHA.sha256(
            JSON3.write(
                Dict(
                    "source_artifact_sha256" => source_artifact_sha256,
                    "input_hashes" => input_hashes,
                    "formal_gates" => formal_gates,
                ),
            ),
        ),
    )

    result = Dict{String, Any}(
        "schema" => RESPONSE_W90_QUALIFICATION_SCHEMA,
        "generated_at_utc" =>
            Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ"),
        "artifact" => Dict(
            "path" => basename(artifact_path),
            "sha256" => source_artifact_sha256,
            "schema" => artifact.schema,
        ),
        "inputs" => input_hashes,
        "dimensions" => dimensions,
        "num_operations" => length(operations),
        "unitary_operation_count" => count(operation -> !operation.antiunitary, operations),
        "antiunitary_operation_count" => count(operation -> operation.antiunitary, operations),
        "thresholds" => thresholds,
        "formal_gates" => formal_gates,
        "wannier90_gauge" => sewing_evidence,
        "hamiltonian_covariance" => hamiltonian_evidence,
        "mmn_covariance" => mmn_evidence,
        "diagnostic_continue" => diagnostic_continue,
        "diagnostic_lane" => diagnostic_lane,
        "production_eligible" => production_eligible,
        "overall_status" => overall_status,
        "seal_evidence_sha256" => seal_evidence_sha256,
        "downstream_integrand_status" => formal_gates["integrand_covariance"]["status"],
        "downstream_full_grid_status" => formal_gates["full_grid_consistency"]["status"],
    )
    output_file === nothing || _write_response_qualification_json(output_file, result; overwrite)
    if qualified_artifact_file !== nothing
        qualified_payload = deepcopy(payload)
        qualified_provenance = qualified_payload["provenance"]
        qualified_provenance["wannier90_inputs"] = input_hashes
        qualification = qualified_payload["qualification"]
        qualification["status"] = overall_status
        qualification["engineering_status"] = "QUALIFICATION_EXECUTED"
        qualification["production_eligible"] = production_eligible
        qualification["gates"] = formal_gates
        qualification["wannier90_gauge"] = sewing_evidence
        qualification["diagnostic_lane"] = diagnostic_lane
        integrand_payload = Dict{String, Any}(deepcopy(formal_gates["integrand_covariance"]))
        get!(integrand_payload, "maximum_relative_residual", nothing)
        get!(
            integrand_payload,
            "tolerance",
            qualified_payload["qualification"]["integrand_covariance"]["tolerance"],
        )
        qualification["integrand_covariance"] = integrand_payload
        qualification["seal"] = Dict(
            "sealed" => production_eligible,
            "status" => production_eligible ? "SEALED" : "UNSEALED",
            "production_eligible" => production_eligible,
            "reason" =>
                production_eligible ? "ALL_FORMAL_GATES_PASSED" :
                "FORMAL_PHYSICAL_QUALIFICATION_DID_NOT_COMPLETE",
            "evidence_sha256" => seal_evidence_sha256,
        )
        _write_response_qualification_json(qualified_artifact_file, qualified_payload; overwrite)
        result["qualified_artifact"] = Dict(
            "path" => basename(qualified_artifact_file),
            "sha256" => _response_qualification_sha256(abspath(qualified_artifact_file)),
        )
        output_file === nothing ||
            _write_response_qualification_json(output_file, result; overwrite = true)
    end
    return result
end
