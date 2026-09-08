# Identify the supported nonmagnetic grey-group inventory without magnetic classification.
function _is_nonmagnetic_grey_group(operations::Vector{SymmetryOperation}; tolerance::Float64)
    unitary_indices = findall(operation -> !operation.antiunitary, operations)
    antiunitary_indices = findall(operation -> operation.antiunitary, operations)
    isempty(antiunitary_indices) && return true
    length(unitary_indices) == length(antiunitary_indices) || return false
    for unitary_index in unitary_indices
        unitary = operations[unitary_index]
        matches = count(antiunitary_indices) do antiunitary_index
            antiunitary = operations[antiunitary_index]
            unitary.rotation_fractional == antiunitary.rotation_fractional &&
                maximum(
                    abs,
                    _periodic_translation_residual(
                        unitary.translation_fractional,
                        antiunitary.translation_fractional,
                    ),
                ) <= tolerance &&
                maximum(abs, unitary.rotation_cartesian - antiunitary.rotation_cartesian) <=
                tolerance
        end
        matches == 1 || return false
    end
    return true
end

# Match the target operation inventory by canonical operation identity, not index.
function _validate_target_operation_inventory(
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    tolerance::Float64,
)
    diagnostics = WannierizationDiagnostic[]
    mapping = zeros(Int, length(representation.operations))
    if length(representation.operations) != length(plan.operations)
        push!(
            diagnostics,
            _representation_diagnostic(
                :TARGET_REPRESENTATION_GROUP_LAW_FAILED,
                :error,
                "band and target representations use different operation counts";
                context = Dict(
                    "band_count" => length(representation.operations),
                    "target_count" => length(plan.operations),
                ),
            ),
        )
        return mapping, diagnostics
    end
    for operation_index in eachindex(representation.operations)
        matches = findall(eachindex(plan.operations)) do plan_index
            _operations_equivalent(
                representation.operations[operation_index],
                plan.operations[plan_index];
                tolerance,
            )
        end
        if length(matches) == 1
            mapping[operation_index] = only(matches)
        else
            push!(
                diagnostics,
                _representation_diagnostic(
                    :TARGET_REPRESENTATION_GROUP_LAW_FAILED,
                    :error,
                    "band operation does not have one unique target-operation match";
                    context = Dict(
                        "operation" => operation_index,
                        "operation_key" =>
                            _canonical_operation_key(representation.operations[operation_index]),
                        "match_count" => length(matches),
                    ),
                ),
            )
        end
    end
    all(>(0), mapping) && length(unique(mapping)) == length(mapping) || push!(
        diagnostics,
        _representation_diagnostic(
            :TARGET_REPRESENTATION_GROUP_LAW_FAILED,
            :error,
            "band-to-target operation matching is not one-to-one",
        ),
    )
    return mapping, diagnostics
end

# Measure the k-dependent Wannier target representation group law.
function _validate_target_group_law(
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    product_table::RepresentationProductTable,
    tolerance::Float64,
)
    operation_mapping, diagnostics =
        _validate_target_operation_inventory(representation, plan, tolerance)
    isempty(diagnostics) || return (zeros(Float64, 4), diagnostics, empty_group_law_worst_cases())
    maximum_residuals = zeros(Float64, 4)
    maximum_context = [Dict{String, String}() for _ in 1:4]
    for source_kpoint in axes(representation.kpoint_map, 2),
        left_index in eachindex(representation.operations),
        right_index in eachindex(representation.operations)

        product_index = product_table.product_indices[left_index, right_index]
        product_index == 0 && continue
        intermediate_kpoint = representation.kpoint_map[right_index, source_kpoint]
        product_kpoint = representation.kpoint_map[product_index, source_kpoint]
        left_target = target_representation(
            plan,
            representation,
            left_index,
            intermediate_kpoint,
            operation_mapping[left_index],
        )
        right_target = target_representation(
            plan,
            representation,
            right_index,
            source_kpoint,
            operation_mapping[right_index],
        )
        representation.operations[left_index].antiunitary && (right_target = conj(right_target))
        product_target = target_representation(
            plan,
            representation,
            product_index,
            source_kpoint,
            operation_mapping[product_index],
        )
        lattice_translation =
            @view product_table.translation_differences[:, left_index, right_index]
        product_k = @view representation.kpoints_fractional[product_kpoint, :]
        phase = cis(-2.0 * pi * dot(product_k, lattice_translation))
        factor = product_table.spinor_factors[left_index, right_index] * phase
        residual_matrix = left_target * right_target - factor .* product_target
        residual = maximum(abs, residual_matrix)
        combination = _group_law_combination_index(
            representation.operations[left_index].antiunitary,
            representation.operations[right_index].antiunitary,
        )
        if residual > maximum_residuals[combination]
            maximum_residuals[combination] = residual
            maximum_context[combination] = _group_law_worst_case_context(
                representation,
                product_table,
                left_index,
                right_index,
                product_index,
                source_kpoint,
                intermediate_kpoint,
                product_kpoint,
                left_target,
                right_target,
                product_target,
                phase,
                factor,
                residual_matrix,
            )
        end
    end
    for combination in 1:4
        maximum_residuals[combination] <= tolerance && continue
        push!(
            diagnostics,
            _representation_diagnostic(
                :TARGET_REPRESENTATION_GROUP_LAW_FAILED,
                :error,
                "k-dependent Wannier target matrices fail the operation group law";
                context = merge(
                    maximum_context[combination],
                    Dict(
                        "maximum_error" => string(maximum_residuals[combination]),
                        "tolerance" => string(tolerance),
                    ),
                ),
            ),
        )
    end
    return maximum_residuals, diagnostics, Tuple(maximum_context)
end

# Require the target (co)representation to occur with sufficient multiplicity
# in every selected little-group band space.  Separate group-law checks only
# prove that the band and target matrices are representations of the same
# operation group; they do not prove that an injective intertwiner exists.
function _validate_target_corepresentation_multiplicity(
    representation::BandRepresentation,
    plan::WannierSymmetryPlan,
    masks::Vector{BitVector},
    tolerance::Float64;
    probe_count::Int = 4,
)
    operation_mapping, inventory_diagnostics =
        _validate_target_operation_inventory(representation, plan, tolerance)
    isempty(inventory_diagnostics) || return WannierizationDiagnostic[]
    target_rank = size(plan.representation_matrices, 1)
    diagnostics = WannierizationDiagnostic[]
    for representative in representation.irreducible_indices
        selected = findall(masks[representative])
        best_minimum_singular_value = 0.0
        if length(selected) >= target_rank
            for probe_index in 1:probe_count
                rng = MersenneTwister(
                    UInt64(0x6d61676e65746963) + UInt64(257 * representative + probe_index),
                )
                probe =
                    randn(rng, length(selected), target_rank) .+
                    1.0im .* randn(rng, length(selected), target_rank)
                projected = zeros(ComplexF64, size(probe))
                little_group_count = 0
                for operation_index in eachindex(representation.operations)
                    representation.kpoint_map[operation_index, representative] == representative ||
                        continue
                    sewing = Matrix(
                        @view representation.sewing_matrices[
                            selected,
                            selected,
                            operation_index,
                            representative,
                        ]
                    )
                    target = target_representation(
                        plan,
                        representation,
                        operation_index,
                        representative,
                        operation_mapping[operation_index],
                    )
                    acted_probe =
                        representation.operations[operation_index].antiunitary ? conj(probe) : probe
                    projected .+= sewing * acted_probe * target'
                    little_group_count += 1
                end
                little_group_count > 0 || continue
                projected ./= little_group_count
                singular_values = svdvals(projected)
                isempty(singular_values) || (
                    best_minimum_singular_value =
                        max(best_minimum_singular_value, minimum(singular_values))
                )
            end
        end
        best_minimum_singular_value > tolerance || push!(
            diagnostics,
            _representation_diagnostic(
                :TARGET_COREPRESENTATION_MULTIPLICITY_MISMATCH,
                :error,
                "selected band space does not contain the complete target corepresentation multiplicity";
                context = Dict(
                    "kpoint" => representative,
                    "selected_rank" => length(selected),
                    "target_rank" => target_rank,
                    "best_minimum_singular_value" => best_minimum_singular_value,
                    "probe_count" => probe_count,
                    "tolerance" => tolerance,
                ),
            ),
        )
    end
    return diagnostics
end

# Return projector covariance residuals under every antiunitary operation.
function _antiunitary_projector_covariance_residual(
    projectors_or_frames,
    representation::BandRepresentation,
)
    length(projectors_or_frames) == size(representation.kpoint_map, 2) ||
        throw(ArgumentError("selected projector count must equal num_kpoints"))
    projectors = map(projectors_or_frames) do matrix
        value = Matrix{ComplexF64}(matrix)
        size(value, 1) == size(representation.energies_ev, 1) ||
            throw(ArgumentError("selected projector has an incompatible band dimension"))
        size(value, 1) == size(value, 2) ? value : value * value'
    end
    maximum_residual = 0.0
    maximum_context = Dict{String, String}()
    for source_kpoint in eachindex(projectors),
        operation_index in eachindex(representation.operations)

        operation = representation.operations[operation_index]
        operation.antiunitary || continue
        target_kpoint = representation.kpoint_map[operation_index, source_kpoint]
        sewing = @view representation.sewing_matrices[:, :, operation_index, source_kpoint]
        transformed = sewing * conj(projectors[source_kpoint]) * sewing'
        residual = maximum(abs, transformed - projectors[target_kpoint])
        if residual > maximum_residual
            maximum_residual = residual
            maximum_context = Dict(
                "operation" => string(operation_index),
                "source_kpoint" => string(source_kpoint),
                "target_kpoint" => string(target_kpoint),
            )
        end
    end
    return maximum_residual, maximum_context
end

# Require even selected-projector rank at every pure-time-reversal invariant k-point.
function _validate_selected_kramers_ranks(
    projectors_or_frames,
    representation::BandRepresentation,
    theta_index::Union{Nothing, Int},
    tolerance::Float64,
)
    theta_index === nothing && return WannierizationDiagnostic[]
    diagnostics = WannierizationDiagnostic[]
    for kpoint in eachindex(projectors_or_frames)
        representation.kpoint_map[theta_index, kpoint] == kpoint || continue
        matrix = Matrix{ComplexF64}(projectors_or_frames[kpoint])
        selected_rank = if size(matrix, 1) == size(matrix, 2)
            count(>(tolerance), eigvals(Hermitian((matrix + matrix') ./ 2)))
        else
            size(matrix, 2)
        end
        iseven(selected_rank) || push!(
            diagnostics,
            _representation_diagnostic(
                :KRAMERS_BLOCK_NOT_CLOSED,
                :error,
                "selected projector has odd rank at a time-reversal invariant k-point";
                context = Dict(
                    "source_kpoint" => kpoint,
                    "selected_rank" => selected_rank,
                    "tolerance" => tolerance,
                ),
            ),
        )
    end
    return diagnostics
end

# Check one band mask family under pure time reversal and at every TRIM.
function _validate_kramers_masks(
    name::String,
    masks::Vector{BitVector},
    representation::BandRepresentation,
    theta_index::Int,
    tolerance::Float64,
    ;
    enforce_covariance_residual::Bool = true,
)
    diagnostics = WannierizationDiagnostic[]
    maximum_residual = 0.0
    for source_kpoint in eachindex(masks)
        target_kpoint = representation.kpoint_map[theta_index, source_kpoint]
        source_projector = Diagonal(ComplexF64.(masks[source_kpoint]))
        target_projector = Diagonal(ComplexF64.(masks[target_kpoint]))
        sewing = @view representation.sewing_matrices[:, :, theta_index, source_kpoint]
        residual = maximum(abs, sewing * conj(source_projector) * sewing' - target_projector)
        maximum_residual = max(maximum_residual, residual)
        counts_match = count(masks[source_kpoint]) == count(masks[target_kpoint])
        trim_even = target_kpoint != source_kpoint || iseven(count(masks[source_kpoint]))
        if (enforce_covariance_residual && residual > tolerance) || !counts_match || !trim_even
            push!(
                diagnostics,
                _representation_diagnostic(
                    :KRAMERS_BLOCK_NOT_CLOSED,
                    :error,
                    "$(name) band mask is not closed under time reversal";
                    context = Dict(
                        "mask" => name,
                        "source_kpoint" => source_kpoint,
                        "target_kpoint" => target_kpoint,
                        "source_rank" => count(masks[source_kpoint]),
                        "target_rank" => count(masks[target_kpoint]),
                        "maximum_error" => residual,
                        "tolerance" => tolerance,
                    ),
                ),
            )
        end
    end
    return maximum_residual, diagnostics
end

# Require a selected band window to be a complete representation/corepresentation block.
function _validate_corepresentation_masks(
    name::String,
    masks::Vector{BitVector},
    representation::BandRepresentation,
    tolerance::Float64,
)
    diagnostics = WannierizationDiagnostic[]
    maximum_residual = 0.0
    maximum_context = Dict{String, String}()
    for source_kpoint in eachindex(masks), operation_index in eachindex(representation.operations)
        target_kpoint = representation.kpoint_map[operation_index, source_kpoint]
        source_indices = findall(masks[source_kpoint])
        target_indices = findall(masks[target_kpoint])
        if length(source_indices) != length(target_indices)
            residual = Inf
        elseif isempty(source_indices)
            residual = 0.0
        else
            sewing = Matrix(
                @view representation.sewing_matrices[
                    target_indices,
                    source_indices,
                    operation_index,
                    source_kpoint,
                ]
            )
            identity_matrix = Matrix{ComplexF64}(I, length(source_indices), length(source_indices))
            residual = max(
                maximum(abs, sewing' * sewing - identity_matrix),
                maximum(abs, sewing * sewing' - identity_matrix),
            )
        end
        if residual > maximum_residual
            maximum_residual = residual
            maximum_context = Dict(
                "mask" => name,
                "operation" => operation_index,
                "antiunitary" => representation.operations[operation_index].antiunitary,
                "source_kpoint" => source_kpoint,
                "target_kpoint" => target_kpoint,
                "source_rank" => length(source_indices),
                "target_rank" => length(target_indices),
            )
        end
    end
    maximum_residual <= tolerance || push!(
        diagnostics,
        _representation_diagnostic(
            :COREPRESENTATION_BLOCK_NOT_CLOSED,
            :error,
            "$(name) band mask truncates a symmetry representation or magnetic corepresentation block";
            context = merge(
                maximum_context,
                Dict("maximum_error" => maximum_residual, "tolerance" => tolerance),
            ),
        ),
    )
    return maximum_residual, diagnostics
end

# Check Theta squared and TRIM skew symmetry in band and target representations.
function _validate_theta_squared(
    representation::BandRepresentation,
    plan::Union{Nothing, WannierSymmetryPlan},
    product_table::RepresentationProductTable,
    validation_masks::Vector{BitVector},
    tolerance::Float64,
    ;
    enforce_band_residual::Bool = true,
)
    theta_index = product_table.theta_index
    theta_index === nothing && return 0.0, WannierizationDiagnostic[]
    expected_sign = representation.spinor ? -1.0 : 1.0
    diagnostics = WannierizationDiagnostic[]
    maximum_residual = maximum(
        abs,
        @view(product_table.spin_actions[:, :, theta_index]) *
        conj(@view(product_table.spin_actions[:, :, theta_index])) -
        expected_sign .* Matrix{ComplexF64}(
            I,
            size(product_table.spin_actions, 1),
            size(product_table.spin_actions, 1),
        ),
    )
    maximum_context = Dict("domain" => "spin_action")
    maximum_analytic_residual = maximum_residual
    maximum_analytic_context = copy(maximum_context)
    operation_mapping = Int[]
    target_inventory_valid = plan === nothing
    if plan !== nothing
        operation_mapping, operation_diagnostics =
            _validate_target_operation_inventory(representation, plan, tolerance)
        append!(diagnostics, operation_diagnostics)
        target_inventory_valid = isempty(operation_diagnostics)
    end
    for source_kpoint in axes(representation.kpoint_map, 2)
        intermediate_kpoint = representation.kpoint_map[theta_index, source_kpoint]
        final_kpoint = representation.kpoint_map[theta_index, intermediate_kpoint]
        final_kpoint == source_kpoint || begin
            push!(
                diagnostics,
                _representation_diagnostic(
                    :THETA_SQUARED_FAILED,
                    :error,
                    "pure time reversal does not map k back after two applications";
                    context = Dict(
                        "source_kpoint" => source_kpoint,
                        "intermediate_kpoint" => intermediate_kpoint,
                        "final_kpoint" => final_kpoint,
                    ),
                ),
            )
            continue
        end
        source_indices = findall(validation_masks[source_kpoint])
        intermediate_indices = findall(validation_masks[intermediate_kpoint])
        isempty(source_indices) && continue
        first_theta = Matrix(
            @view representation.sewing_matrices[
                intermediate_indices,
                source_indices,
                theta_index,
                source_kpoint,
            ]
        )
        second_theta = Matrix(
            @view representation.sewing_matrices[
                source_indices,
                intermediate_indices,
                theta_index,
                intermediate_kpoint,
            ]
        )
        identity_matrix = Matrix{ComplexF64}(I, length(source_indices), length(source_indices))
        residual = maximum(abs, second_theta * conj(first_theta) - expected_sign .* identity_matrix)
        if residual > maximum_residual
            maximum_residual = residual
            maximum_context = Dict(
                "domain" => "band",
                "source_kpoint" => string(source_kpoint),
                "intermediate_kpoint" => string(intermediate_kpoint),
            )
        end
        if representation.spinor && intermediate_kpoint == source_kpoint
            skew_residual = maximum(abs, first_theta + transpose(first_theta))
            if skew_residual > maximum_residual
                maximum_residual = skew_residual
                maximum_context =
                    Dict("domain" => "band_trim_skew", "source_kpoint" => string(source_kpoint))
            end
        end
        plan === nothing && continue
        target_inventory_valid || continue
        first_target = target_representation(
            plan,
            representation,
            theta_index,
            source_kpoint,
            operation_mapping[theta_index],
        )
        second_target = target_representation(
            plan,
            representation,
            theta_index,
            intermediate_kpoint,
            operation_mapping[theta_index],
        )
        target_identity = Matrix{ComplexF64}(I, size(first_target, 1), size(first_target, 1))
        target_residual =
            maximum(abs, second_target * conj(first_target) - expected_sign .* target_identity)
        if target_residual > maximum_residual
            maximum_residual = target_residual
            maximum_context = Dict(
                "domain" => "wannier_target",
                "source_kpoint" => string(source_kpoint),
                "intermediate_kpoint" => string(intermediate_kpoint),
            )
        end
        if target_residual > maximum_analytic_residual
            maximum_analytic_residual = target_residual
            maximum_analytic_context = Dict(
                "domain" => "wannier_target",
                "source_kpoint" => string(source_kpoint),
                "intermediate_kpoint" => string(intermediate_kpoint),
            )
        end
        if representation.spinor && intermediate_kpoint == source_kpoint
            target_skew_residual = maximum(abs, first_target + transpose(first_target))
            if target_skew_residual > maximum_residual
                maximum_residual = target_skew_residual
                maximum_context = Dict(
                    "domain" => "wannier_target_trim_skew",
                    "source_kpoint" => string(source_kpoint),
                )
            end
            if target_skew_residual > maximum_analytic_residual
                maximum_analytic_residual = target_skew_residual
                maximum_analytic_context = Dict(
                    "domain" => "wannier_target_trim_skew",
                    "source_kpoint" => string(source_kpoint),
                )
            end
        end
    end
    failure_residual = enforce_band_residual ? maximum_residual : maximum_analytic_residual
    failure_context = enforce_band_residual ? maximum_context : maximum_analytic_context
    if failure_residual > tolerance
        code =
            startswith(get(failure_context, "domain", ""), "wannier_target") ?
            :TARGET_REPRESENTATION_GROUP_LAW_FAILED : :THETA_SQUARED_FAILED
        push!(
            diagnostics,
            _representation_diagnostic(
                code,
                :error,
                "time-reversal representation does not satisfy the configured square/skew contract";
                context = merge(
                    failure_context,
                    Dict(
                        "maximum_error" => string(failure_residual),
                        "tolerance" => string(tolerance),
                    ),
                ),
            ),
        )
    end
    return maximum_residual, diagnostics
end

"""
    validate_band_representation_compatibility(representation, plan; ...)

Validate scalar, unitary, and Type-I--IV magnetic band/Wannier representations.
Sewing matrices use target rows and source columns. For
antiunitary operations source matrices are conjugated, reciprocal/nonsymmorphic
phases and spin double-group signs are included, and `Theta^2=-I` is enforced
for spinors whenever pure time reversal is present. Every outer/frozen mask must
be a complete representation/corepresentation block under all operations. Under
Bloch gauge changes, unitary sewing transforms as
`U(k_g)'*B_g*U(k)` and antiunitary sewing as
`U(k_g)'*B_g*conj(U(k))`. IrRep is never called by this validator.
"""
function validate_band_representation_compatibility(
    representation::BandRepresentation,
    plan::Union{Nothing, WannierSymmetryPlan} = nothing;
    outer_mask = nothing,
    frozen_mask = nothing,
    selected_projectors = nothing,
    tolerance::Real = 1.0e-8,
    metadata_origin::Symbol = :computed,
    validation_profile::Symbol = representation.source_code in (:vasp, :qe) ? :empirical :
                                 :analytic,
    oracle_excess_group_law_residuals = nothing,
    qualification_sha256::Union{Nothing, AbstractString} = nothing,
)
    tolerance_value = Float64(tolerance)
    isfinite(tolerance_value) && tolerance_value > 0.0 ||
        throw(ArgumentError("compatibility tolerance must be positive and finite"))
    validation_profile in (:analytic, :empirical) ||
        throw(ArgumentError("validation_profile must be :analytic or :empirical"))
    excess_values =
        oracle_excess_group_law_residuals === nothing ? nothing :
        Float64.(collect(oracle_excess_group_law_residuals))
    excess_values === nothing ||
        length(excess_values) == 4 ||
        throw(ArgumentError("oracle excess group-law residuals must have four entries"))
    excess_residuals =
        excess_values === nothing ? nothing :
        (excess_values[1], excess_values[2], excess_values[3], excess_values[4])
    qualification = qualification_sha256 === nothing ? nothing : String(qualification_sha256)
    qualification === nothing ||
        length(qualification) == 64 ||
        throw(ArgumentError("qualification_sha256 must be a 64-character SHA-256"))
    diagnostics = WannierizationDiagnostic[]
    product_table = try
        _build_representation_product_table(
            representation.operations,
            representation.spinor;
            tolerance = tolerance_value,
        )
    catch exception
        message = sprint(showerror, exception)
        code =
            occursin("spin", lowercase(message)) ? :SPIN_DOUBLE_GROUP_INCONSISTENT :
            :OPERATION_GROUP_NOT_CLOSED
        push!(diagnostics, _representation_diagnostic(code, :error, message))
        _empty_representation_product_table(representation.operations, representation.spinor)
    end
    supported_contract = true
    num_bands, num_kpoints = size(representation.energies_ev)
    outer_masks = _normalize_validation_masks(outer_mask, num_bands, num_kpoints)
    maximum_group_residuals = zeros(Float64, 4)
    band_group_residuals = zeros(Float64, 4)
    target_group_residuals = zeros(Float64, 4)
    band_worst_cases = empty_group_law_worst_cases()
    target_worst_cases = empty_group_law_worst_cases()
    maximum_shift_residual = 0.0
    maximum_unitarity_residual = 0.0
    if product_table.identity_index != 0
        band_residuals,
        maximum_shift_residual,
        maximum_unitarity_residual,
        band_diagnostics,
        band_worst_cases = _validate_band_group_law(
            representation,
            product_table,
            outer_masks,
            tolerance_value;
            enforce_absolute_group_law = validation_profile == :analytic,
        )
        band_group_residuals .= band_residuals
        maximum_group_residuals .= band_residuals
        append!(diagnostics, band_diagnostics)
        if plan !== nothing
            target_residuals, target_diagnostics, target_worst_cases =
                _validate_target_group_law(representation, plan, product_table, tolerance_value)
            target_group_residuals .= target_residuals
            maximum_group_residuals .= max.(maximum_group_residuals, target_residuals)
            append!(diagnostics, target_diagnostics)
            isempty(target_diagnostics) && append!(
                diagnostics,
                _validate_target_corepresentation_multiplicity(
                    representation,
                    plan,
                    outer_masks,
                    tolerance_value,
                ),
            )
        end
    end
    if validation_profile == :empirical && maximum(maximum_group_residuals) >= 1.0
        push!(
            diagnostics,
            _representation_diagnostic(
                :EMPIRICAL_COVARIANCE_BUDGET_VACUOUS,
                :error,
                "finite-cutoff group-law floor would make the projector covariance gate vacuous";
                context = Dict(
                    "maximum_group_law_residual" => maximum(maximum_group_residuals),
                    "strict_upper_bound" => 1.0,
                ),
            ),
        )
    end
    outer_corepresentation_residual, outer_corepresentation_diagnostics =
        _validate_corepresentation_masks("outer", outer_masks, representation, tolerance_value)
    maximum_unitarity_residual = max(maximum_unitarity_residual, outer_corepresentation_residual)
    append!(diagnostics, outer_corepresentation_diagnostics)
    if frozen_mask !== nothing
        frozen_masks =
            _normalize_validation_masks(frozen_mask, num_bands, num_kpoints; default_all = false)
        frozen_corepresentation_residual, frozen_corepresentation_diagnostics =
            _validate_corepresentation_masks(
                "frozen",
                frozen_masks,
                representation,
                tolerance_value,
            )
        maximum_unitarity_residual =
            max(maximum_unitarity_residual, frozen_corepresentation_residual)
        append!(diagnostics, frozen_corepresentation_diagnostics)
    end
    if validation_profile == :empirical
        if excess_residuals === nothing || qualification === nothing
            push!(
                diagnostics,
                _representation_diagnostic(
                    :ORACLE_REFERENCE_UNAVAILABLE,
                    :info,
                    "paired-oracle evidence is unavailable; internal representation checks remain authoritative";
                    context = Dict(
                        "absolute_group_law_residuals" => join(maximum_group_residuals, ","),
                        "absolute_residual_role" => "report_only",
                        "oracle_role" => "reference_diagnostic",
                    ),
                ),
            )
        else
            for combination in eachindex(excess_residuals)
                excess_residuals[combination] <= tolerance_value && continue
                push!(
                    diagnostics,
                    _representation_diagnostic(
                        :ORACLE_REFERENCE_DIFFERENCE,
                        :warning,
                        "candidate group-law residual differs from the aligned oracle reference";
                        context = Dict(
                            "combination" => GROUP_LAW_COMBINATION_LABELS[combination],
                            "maximum_error" => excess_residuals[combination],
                            "tolerance" => tolerance_value,
                            "qualification_sha256" => qualification,
                            "oracle_role" => "reference_diagnostic",
                        ),
                    ),
                )
            end
        end
    end
    theta_squared_residual = 0.0
    maximum_kramers_residual = 0.0
    if product_table.theta_index !== nothing
        theta_squared_residual, theta_diagnostics = _validate_theta_squared(
            representation,
            plan,
            product_table,
            outer_masks,
            tolerance_value;
            enforce_band_residual = validation_profile == :analytic,
        )
        maximum_kramers_residual = max(maximum_kramers_residual, theta_squared_residual)
        append!(diagnostics, theta_diagnostics)
        outer_residual, outer_diagnostics = _validate_kramers_masks(
            "outer",
            outer_masks,
            representation,
            product_table.theta_index,
            tolerance_value;
            enforce_covariance_residual = validation_profile == :analytic,
        )
        maximum_kramers_residual = max(maximum_kramers_residual, outer_residual)
        append!(diagnostics, outer_diagnostics)
        if frozen_mask !== nothing
            frozen_residual, frozen_diagnostics = _validate_kramers_masks(
                "frozen",
                frozen_masks,
                representation,
                product_table.theta_index,
                tolerance_value;
                enforce_covariance_residual = validation_profile == :analytic,
            )
            maximum_kramers_residual = max(maximum_kramers_residual, frozen_residual)
            append!(diagnostics, frozen_diagnostics)
        end
    end
    if selected_projectors !== nothing &&
       any(operation -> operation.antiunitary, representation.operations)
        projector_residual, projector_context =
            _antiunitary_projector_covariance_residual(selected_projectors, representation)
        maximum_kramers_residual = max(maximum_kramers_residual, projector_residual)
        projector_residual <= tolerance_value || push!(
            diagnostics,
            _representation_diagnostic(
                :ANTIUNITARY_PROJECTOR_COVARIANCE_FAILED,
                :error,
                "selected projector is not covariant under the antiunitary k-star action";
                context = merge(
                    projector_context,
                    Dict(
                        "maximum_error" => string(projector_residual),
                        "tolerance" => string(tolerance_value),
                    ),
                ),
            ),
        )
        rank_diagnostics = _validate_selected_kramers_ranks(
            selected_projectors,
            representation,
            product_table.theta_index,
            tolerance_value,
        )
        append!(diagnostics, rank_diagnostics)
    end
    representation_sha256 = _representation_static_sha256(representation)
    diagnostics = [
        WannierizationDiagnostic(
            diagnostic.code,
            diagnostic.severity,
            diagnostic.message;
            context = merge(diagnostic.context, Dict("input_sha256" => representation_sha256)),
        ) for diagnostic in diagnostics
    ]
    gate_definition_status = GATE_VALID
    assessment_status = if supported_contract && !_has_representation_error(diagnostics)
        REPRESENTATION_COMPATIBLE
    else
        REPRESENTATION_INCOMPATIBLE_ASSESSMENT
    end
    passed = gate_definition_status == GATE_VALID && assessment_status == REPRESENTATION_COMPATIBLE
    return RepresentationCompatibilityReport(
        "1.3",
        supported_contract,
        passed,
        tolerance_value,
        product_table,
        Tuple(maximum_group_residuals),
        Tuple(band_group_residuals),
        Tuple(target_group_residuals),
        band_worst_cases,
        target_worst_cases,
        maximum_shift_residual,
        theta_squared_residual,
        maximum_kramers_residual,
        representation_sha256,
        diagnostics,
        metadata_origin,
        gate_definition_status,
        assessment_status,
        maximum_unitarity_residual,
        excess_residuals,
        qualification,
        validation_profile,
    )
end
