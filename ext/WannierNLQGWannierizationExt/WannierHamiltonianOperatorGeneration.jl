const WANNIER_HAMILTONIAN_OPERATOR_GENERATION_SCHEMA = "WannierNLQG.wannier_hamiltonian_operator_generation"
const WANNIER_HAMILTONIAN_OPERATOR_GENERATION_SCHEMA_VERSION = "1.0"
const WANNIER_HAMILTONIAN_OPERATOR_GENERATION_ALGORITHM_VERSION = "finite-band-paw-metric-galerkin-v5-structural-source-generation-with-audited-truncation"
const WANNIER_HAMILTONIAN_OPERATOR_CLOSURE_SEMANTICS = "dimensionless_probability_weight"
const WANNIER_HAMILTONIAN_OPERATOR_CLOSURE_FORMULA = "max_endpoint_lambda_max(V_dagger*(I-M_dagger_M_or_I-M_M_dagger)*V)"
const WANNIER_HAMILTONIAN_OPERATOR_ACTUAL_ERROR_STATUS = "NOT_AVAILABLE_WITHOUT_COMPLEMENT_HAMILTONIAN_OR_NBANDS_REFERENCE"
const WANNIER_HAMILTONIAN_OPERATOR_NBANDS_CONVERGENCE_STATUS = "NOT_ESTABLISHED"

"""Validate and resolve protected atomic paths for a Hamiltonian-operator generator."""
function _hamiltonian_operator_paths(
    config::WannierHamiltonianOperatorGenerationConfig;
    authoritative_mmn_file = nothing,
)
    config.construction_policy in (:diagnostic, :strict) ||
        throw(ArgumentError("construction_policy must be :diagnostic or :strict"))
    output = abspath(config.output_file)
    provenance = abspath(config.provenance_json)
    target = config.target_contract
    validate_generation_output_paths(
        (; output, provenance),
        (
            config.topology_file,
            config.eig_file,
            config.spn_file,
            config.spn_provenance_file,
            config.wavefunction_gauge_hdf5,
            authoritative_mmn_file,
            target === nothing ? nothing : something(target).operator_oracle_mmn_file,
            target === nothing ? nothing : something(target).solver_mmn_file,
        ),
        config.source,
    )
    for (label, path) in (("topology_file", config.topology_file), ("eig_file", config.eig_file))
        isempty(strip(path)) && throw(ArgumentError("$(label) must not be empty"))
        isfile(path) || throw(ArgumentError("$(label) does not exist: $(abspath(path))"))
    end
    ispath(output) &&
        !config.overwrite &&
        throw(ArgumentError("refusing to overwrite operator file: $(output)"))
    ispath(provenance) &&
        !config.overwrite &&
        throw(ArgumentError("refusing to overwrite operator provenance: $(provenance)"))
    isfinite(config.closure_tolerance) && config.closure_tolerance > 0.0 ||
        throw(ArgumentError("closure_tolerance must be positive and finite"))
    config.max_cached_wavefunction_kpoints >= 2 ||
        throw(ArgumentError("max_cached_wavefunction_kpoints must be at least two"))
    return (; output, provenance)
end

"""Construct the configured Hamiltonian authority for uHu, sHu, or sIu."""
function _generation_authoritative_hamiltonian(config::WannierHamiltonianOperatorGenerationConfig)
    eig = IO.read_wannier_eig(config.eig_file)
    if config.authoritative_hamiltonian isa NativeDFTHamiltonian
        if config.wavefunction_gauge_hdf5 === nothing
            return _native_authoritative_band_hamiltonian(eig; eig_file = config.eig_file)
        end
        return _native_completed_authoritative_band_hamiltonian(
            config.source,
            something(config.wavefunction_gauge_hdf5),
            eig;
            eig_file = config.eig_file,
            construction_policy = config.construction_policy,
        )
    elseif config.authoritative_hamiltonian isa SymmetrizedDFTHamiltonian
        config.wavefunction_gauge_hdf5 === nothing && throw(
            ArgumentError(
                "SYMMETRIZED_HAMILTONIAN_ARTIFACT_REQUIRED: wavefunction_gauge_hdf5 is missing",
            ),
        )
        return _symmetrized_authoritative_band_hamiltonian(
            config.source,
            something(config.wavefunction_gauge_hdf5),
            config.authoritative_hamiltonian,
            construction_policy = config.construction_policy,
        )
    end
    throw(ArgumentError("unsupported authoritative Hamiltonian backend"))
end

"""Load the complete spinor physical-metric state used by formal generators."""
function _hamiltonian_operator_overlap_state(config::WannierHamiltonianOperatorGenerationConfig)
    state = uiu_source_state(
        config.source,
        config.topology_file,
        config.max_cached_wavefunction_kpoints,
    )
    state.native.spinor || throw(
        ArgumentError(
            "SPINOR_WAVEFUNCTION_REQUIRED: uHu/sHu/sIu formal generators require a spinor-native source",
        ),
    )
    return state
end

"""Digest the target-scope identity bound to topology and the band-frame contract."""
function _hamiltonian_operator_closure_scope_sha256(
    authority,
    parent_audit_policy,
    artifact_sha256,
    frame_contract_sha256,
    topology_sha256,
    outer_mask_sha256,
    frozen_mask_sha256,
    num_bands,
    num_kpoints,
)
    buffer = IOBuffer()
    for value in (
        "WannierNLQG.operator_closure_scope/1.0",
        authority,
        parent_audit_policy,
        artifact_sha256,
        frame_contract_sha256,
        topology_sha256,
        outer_mask_sha256,
        frozen_mask_sha256,
        num_bands,
        num_kpoints,
        WANNIER_HAMILTONIAN_OPERATOR_CLOSURE_SEMANTICS,
        WANNIER_HAMILTONIAN_OPERATOR_CLOSURE_FORMULA,
    )
        write(buffer, string(value), '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

"""Validate topology dimensions and directed endpoint indices for the closure gate."""
function _validate_hamiltonian_operator_closure_topology(topology)
    topology.num_bands > 0 && topology.num_kpts > 0 && topology.num_neighbors > 0 ||
        throw(ArgumentError("CLOSURE_TOPOLOGY_INVALID: dimensions must be positive"))
    size(topology.neighbors) == (topology.num_neighbors, topology.num_kpts) ||
        throw(ArgumentError("CLOSURE_TOPOLOGY_INVALID: neighbor dimensions differ"))
    size(topology.reciprocal_shifts) == (3, topology.num_neighbors, topology.num_kpts) ||
        throw(ArgumentError("CLOSURE_TOPOLOGY_INVALID: reciprocal-shift dimensions differ"))
    all(index -> 1 <= index <= topology.num_kpts, topology.neighbors) ||
        throw(ArgumentError("CLOSURE_TOPOLOGY_INVALID: neighbor index is out of range"))
    isempty(topology.source_sha256) &&
        throw(ArgumentError("CLOSURE_TOPOLOGY_INVALID: source digest is empty"))
    return nothing
end

"""Build the explicit full-parent scope retained for ordinary native generation."""
function _hamiltonian_operator_native_identity_scope(gauge_contract, topology)
    gauge_contract.gauge_artifact_sha256 === nothing || throw(
        ArgumentError("CLOSURE_SCOPE_ARTIFACT_MISMATCH: native identity scope has an artifact"),
    )
    gauge_contract.transforms === nothing || throw(
        ArgumentError(
            "CLOSURE_QUALIFICATION_SCOPE_REQUIRED: nonidentity frame requires a schema-1.11 outer-window scope",
        ),
    )
    gauge_contract.status == "PASS" || throw(ArgumentError("BAND_FRAME_CONTRACT_NOT_QUALIFIED"))
    outer_mask = trues(topology.num_bands, topology.num_kpts)
    frozen_mask = falses(topology.num_bands, topology.num_kpts)
    outer_mask_sha256 = qualification_mask_sha256(outer_mask)
    frozen_mask_sha256 = qualification_mask_sha256(frozen_mask)
    authority = "full_parent_native_identity"
    parent_audit_policy = "audit_only"
    artifact_sha256 = "NOT_APPLICABLE"
    contract_sha256 = _hamiltonian_operator_closure_scope_sha256(
        authority,
        parent_audit_policy,
        artifact_sha256,
        gauge_contract.contract_sha256,
        topology.source_sha256,
        outer_mask_sha256,
        frozen_mask_sha256,
        topology.num_bands,
        topology.num_kpts,
    )
    return (;
        authority,
        parent_audit_policy,
        artifact_sha256,
        outer_mask = BitMatrix(outer_mask),
        frozen_mask = BitMatrix(frozen_mask),
        outer_mask_sha256,
        frozen_mask_sha256,
        outer_rank_minimum = topology.num_bands,
        outer_rank_maximum = topology.num_bands,
        frozen_rank_minimum = 0,
        frozen_rank_maximum = 0,
        contract_sha256,
    )
end

"""Read and independently verify a schema-1.11 outer-window closure scope."""
function _hamiltonian_operator_closure_scope(
    gauge_hdf5,
    gauge_contract,
    topology;
    construction_policy::Symbol = :strict,
)
    construction_policy in (:diagnostic, :strict) ||
        throw(ArgumentError("construction_policy must be :diagnostic or :strict"))
    _validate_hamiltonian_operator_closure_topology(topology)
    gauge_hdf5 === nothing &&
        return _hamiltonian_operator_native_identity_scope(gauge_contract, topology)

    path = abspath(something(gauge_hdf5))
    isfile(path) || throw(ArgumentError("CLOSURE_SCOPE_ARTIFACT_MISSING: $(path)"))
    artifact_sha256 = sha256_file(path)
    artifact_sha256 == gauge_contract.gauge_artifact_sha256 ||
        throw(ArgumentError("CLOSURE_SCOPE_ARTIFACT_DIGEST_MISMATCH"))
    gauge_contract.status == "PASS" && !gauge_contract.legacy ||
        throw(ArgumentError("CLOSURE_SCOPE_FRAME_CONTRACT_NOT_FORMALLY_QUALIFIED"))

    authority = ""
    parent_audit_policy = ""
    outer_mask = BitMatrix(undef, 0, 0)
    frozen_mask = BitMatrix(undef, 0, 0)
    outer_mask_sha256 = ""
    frozen_mask_sha256 = ""
    HDF5.h5open(path, "r") do handle
        root_attributes = HDF5.attributes(handle)
        for key in ("schema", "schema_version", "status")
            haskey(root_attributes, key) ||
                throw(ArgumentError("CLOSURE_SCOPE_ARTIFACT_INVALID: missing $(key)"))
        end
        String(read(root_attributes["schema"])) == STAR_COVARIANT_PAW_GAUGE_SCHEMA ||
            throw(ArgumentError("CLOSURE_SCOPE_ARTIFACT_INVALID: schema differs"))
        String(read(root_attributes["schema_version"])) in ("1.0", "1.11") || throw(
            ArgumentError(
                "CLOSURE_QUALIFICATION_SCOPE_REQUIRED: formal nonidentity generation requires schema-1.11",
            ),
        )
        artifact_status = String(read(root_attributes["status"]))
        artifact_status == "PASS" ||
            (construction_policy == :diagnostic && artifact_status == "DIAGNOSTIC_ONLY") ||
            throw(ArgumentError("CLOSURE_SCOPE_ARTIFACT_NOT_QUALIFIED"))
        haskey(handle, "qualification_scope") || throw(
            ArgumentError(
                "CLOSURE_QUALIFICATION_SCOPE_REQUIRED: schema-1.11 artifact has no qualification_scope",
            ),
        )
        group = handle["qualification_scope"]
        group_attributes = HDF5.attributes(group)
        for key in ("authority", "parent_audit_policy", "outer_mask_sha256", "frozen_mask_sha256")
            haskey(group_attributes, key) ||
                throw(ArgumentError("CLOSURE_SCOPE_ARTIFACT_INVALID: missing $(key)"))
        end
        haskey(group, "outer_mask") && haskey(group, "frozen_mask") ||
            throw(ArgumentError("CLOSURE_QUALIFICATION_SCOPE_REQUIRED: mask datasets are missing"))
        authority = String(read(group_attributes["authority"]))
        parent_audit_policy = String(read(group_attributes["parent_audit_policy"]))
        authority == "outer_window" || throw(ArgumentError("CLOSURE_SCOPE_AUTHORITY_MISMATCH"))
        parent_audit_policy == "audit_only" ||
            throw(ArgumentError("CLOSURE_SCOPE_PARENT_POLICY_MISMATCH"))
        raw_outer = read(group["outer_mask"])
        raw_frozen = read(group["frozen_mask"])
        all(value -> value in (0, 1), raw_outer) && all(value -> value in (0, 1), raw_frozen) ||
            throw(ArgumentError("CLOSURE_SCOPE_MASK_INVALID: masks must be binary"))
        outer_mask = BitMatrix(Bool.(raw_outer))
        frozen_mask = BitMatrix(Bool.(raw_frozen))
        size(outer_mask) == (topology.num_bands, topology.num_kpts) &&
        size(frozen_mask) == size(outer_mask) ||
            throw(ArgumentError("CLOSURE_SCOPE_MASK_DIMENSION_MISMATCH"))
        all((.!frozen_mask) .| outer_mask) ||
            throw(ArgumentError("CLOSURE_SCOPE_MASK_INVALID: frozen mask exceeds outer mask"))
        outer_mask_sha256 = String(read(group_attributes["outer_mask_sha256"]))
        frozen_mask_sha256 = String(read(group_attributes["frozen_mask_sha256"]))
        outer_mask_sha256 == qualification_mask_sha256(outer_mask) &&
        frozen_mask_sha256 == qualification_mask_sha256(frozen_mask) ||
            throw(ArgumentError("CLOSURE_SCOPE_MASK_DIGEST_MISMATCH"))
    end

    outer_ranks = [count(@view outer_mask[:, kpoint]) for kpoint in 1:topology.num_kpts]
    frozen_ranks = [count(@view frozen_mask[:, kpoint]) for kpoint in 1:topology.num_kpts]
    minimum(outer_ranks) > 0 ||
        throw(ArgumentError("CLOSURE_SCOPE_MASK_RANK_FAILED: outer scope is empty"))
    contract_sha256 = _hamiltonian_operator_closure_scope_sha256(
        authority,
        parent_audit_policy,
        artifact_sha256,
        gauge_contract.contract_sha256,
        topology.source_sha256,
        outer_mask_sha256,
        frozen_mask_sha256,
        topology.num_bands,
        topology.num_kpts,
    )
    return (;
        authority,
        parent_audit_policy,
        artifact_sha256,
        outer_mask,
        frozen_mask,
        outer_mask_sha256,
        frozen_mask_sha256,
        outer_rank_minimum = minimum(outer_ranks),
        outer_rank_maximum = maximum(outer_ranks),
        frozen_rank_minimum = minimum(frozen_ranks),
        frozen_rank_maximum = maximum(frozen_ranks),
        contract_sha256,
    )
end

"""Return the evidence-scaled tolerance used only for contraction/PSD roundoff."""
function _hamiltonian_operator_overlap_numerical_tolerance(gauge_contract, num_bands::Int)
    evidence =
        max(abs(gauge_contract.physical_isometry_maximum), abs(gauge_contract.replay_maximum))
    isfinite(evidence) || throw(ArgumentError("BAND_FRAME_CONTRACT_NONFINITE"))
    return max(1.0e-12, 8 * evidence, 256 * eps(Float64) * num_bands)
end

"""Evaluate one endpoint-scoped probability defect without completing the parent basis."""
function _hamiltonian_operator_endpoint_probability_defect(matrix, indices, side::Symbol)
    rank = length(indices)
    rank > 0 || throw(ArgumentError("CLOSURE_SCOPE_MASK_RANK_FAILED"))
    gram = if side == :left
        selected = @view matrix[indices, :]
        selected * selected'
    elseif side == :right
        selected = @view matrix[:, indices]
        selected' * selected
    else
        throw(ArgumentError("unsupported closure endpoint $(side)"))
    end
    defect = Hermitian(Matrix{ComplexF64}(I, rank, rank) - gram)
    eigenvalues = eigvals(defect)
    all(isfinite, eigenvalues) || throw(ArgumentError("PHYSICAL_OVERLAP_DEFECT_NONFINITE"))
    return max(0.0, maximum(eigenvalues)), max(0.0, -minimum(eigenvalues))
end

"""Audit finite-parent loss without treating cross-k overlaps as unitary matrices."""
function _hamiltonian_operator_closure_metrics(
    overlaps,
    topology,
    scope;
    numerical_tolerance::Float64,
)
    _validate_hamiltonian_operator_closure_topology(topology)
    isfinite(numerical_tolerance) && numerical_tolerance > 0.0 ||
        throw(ArgumentError("closure numerical tolerance must be positive and finite"))
    size(overlaps) ==
    (topology.num_bands, topology.num_bands, topology.num_neighbors, topology.num_kpts) ||
        throw(ArgumentError("CLOSURE_OVERLAP_DIMENSION_MISMATCH"))
    size(scope.outer_mask) == (topology.num_bands, topology.num_kpts) ||
        throw(ArgumentError("CLOSURE_SCOPE_MASK_DIMENSION_MISMATCH"))
    frozen_mask =
        hasproperty(scope, :frozen_mask) ? scope.frozen_mask : falses(size(scope.outer_mask))
    size(frozen_mask) == size(scope.outer_mask) ||
        throw(ArgumentError("CLOSURE_SCOPE_MASK_DIMENSION_MISMATCH"))

    outer_maximum = 0.0
    frozen_maximum = 0.0
    frozen_applicable = any(frozen_mask)
    parent_maximum = 0.0
    parent_contraction_maximum = 0.0
    outer_contraction_maximum = 0.0
    frozen_contraction_maximum = 0.0
    outer_context = (center = 0, neighbor = 0, endpoint = "NONE", kpoint = 0, rank = 0)
    frozen_context = (center = 0, neighbor = 0, endpoint = "NONE", kpoint = 0, rank = 0)
    parent_context = (center = 0, neighbor = 0, right = 0)
    for center in 1:topology.num_kpts, neighbor in 1:topology.num_neighbors
        right = topology.neighbors[neighbor, center]
        matrix = @view overlaps[:, :, neighbor, center]
        all(isfinite, matrix) || throw(
            ArgumentError("PHYSICAL_OVERLAP_NONFINITE: center=$(center), neighbor=$(neighbor)"),
        )
        singular_values = svdvals(matrix)
        all(isfinite, singular_values) ||
            throw(ArgumentError("PHYSICAL_OVERLAP_NONFINITE: singular values are non-finite"))
        minimum_squared = abs2(minimum(singular_values))
        maximum_squared = abs2(maximum(singular_values))
        contraction_excess = max(0.0, maximum_squared - 1.0)
        parent_contraction_maximum = max(parent_contraction_maximum, contraction_excess)
        parent_audit = max(abs(1.0 - minimum_squared), abs(1.0 - maximum_squared))
        if parent_audit > parent_maximum
            parent_maximum = parent_audit
            parent_context = (; center, neighbor, right)
        end

        for (scope_name, mask) in ((:outer, scope.outer_mask), (:frozen, frozen_mask))
            left_indices = findall(@view mask[:, center])
            right_indices = findall(@view mask[:, right])
            for (side, endpoint, indices) in
                ((:left, center, left_indices), (:right, right, right_indices))
                isempty(indices) && continue
                leakage, contraction =
                    _hamiltonian_operator_endpoint_probability_defect(matrix, indices, side)
                context = (;
                    center,
                    neighbor,
                    endpoint = String(side),
                    kpoint = endpoint,
                    rank = length(indices),
                )
                if scope_name == :outer
                    outer_contraction_maximum = max(outer_contraction_maximum, contraction)
                    if leakage > outer_maximum
                        outer_maximum = leakage
                        outer_context = context
                    end
                else
                    frozen_contraction_maximum = max(frozen_contraction_maximum, contraction)
                    if leakage > frozen_maximum
                        frozen_maximum = leakage
                        frozen_context = context
                    end
                end
            end
        end
    end
    return (;
        # Compatibility aliases retained for schema-1.2 readers.  In schema 1.3
        # these are audits, not finite-band closure qualifications.
        target_probability_leakage_maximum = outer_maximum,
        parent_mutual_containment_audit_maximum = parent_maximum,
        contraction_excess_maximum = parent_contraction_maximum,
        defect_psd_violation_maximum = outer_contraction_maximum,
        outer_probability_leakage_audit_maximum = outer_maximum,
        frozen_probability_leakage_audit_maximum = frozen_applicable ? frozen_maximum : nothing,
        parent_overlap_contraction_excess_audit_maximum = parent_contraction_maximum,
        outer_overlap_contraction_excess_audit_maximum = outer_contraction_maximum,
        frozen_overlap_contraction_excess_audit_maximum = frozen_applicable ?
                                                          frozen_contraction_maximum : nothing,
        numerical_tolerance,
        target_worst_context = outer_context,
        outer_worst_context = outer_context,
        frozen_worst_context = frozen_applicable ? frozen_context : nothing,
        parent_worst_context = parent_context,
    )
end

"""Retain the legacy accessor: finite leakage no longer fails source generation."""
function _hamiltonian_operator_closure_failure_reasons(metrics, closure_tolerance::Float64)
    isfinite(closure_tolerance) && closure_tolerance > 0.0 ||
        throw(ArgumentError("diagnostic closure reference must be positive and finite"))
    return String[]
end

"""Classify one finite audit value against its non-vetoing diagnostic reference."""
_hamiltonian_operator_reference_status(value, reference) =
    value === nothing ? "NOT_APPLICABLE" :
    value <= reference ? "WITHIN_REFERENCE" : "ABOVE_REFERENCE"

"""Return explicit audit findings without converting them into generation failures."""
function _hamiltonian_operator_closure_audit_findings(metrics, diagnostic_reference::Float64)
    findings = String[]
    metrics.outer_probability_leakage_audit_maximum <= diagnostic_reference ||
        push!(findings, "OUTER_LEAKAGE_ABOVE_DIAGNOSTIC_REFERENCE")
    metrics.frozen_probability_leakage_audit_maximum === nothing ||
        metrics.frozen_probability_leakage_audit_maximum <= diagnostic_reference ||
        push!(findings, "FROZEN_LEAKAGE_ABOVE_DIAGNOSTIC_REFERENCE")
    metrics.parent_mutual_containment_audit_maximum <= diagnostic_reference ||
        push!(findings, "PARENT_LEAKAGE_ABOVE_DIAGNOSTIC_REFERENCE")
    metrics.parent_overlap_contraction_excess_audit_maximum <= metrics.numerical_tolerance ||
        push!(findings, "PARENT_CONTRACTION_EXCESS_AUDIT")
    metrics.outer_overlap_contraction_excess_audit_maximum <= metrics.numerical_tolerance ||
        push!(findings, "OUTER_CONTRACTION_EXCESS_AUDIT")
    metrics.frozen_overlap_contraction_excess_audit_maximum === nothing ||
        metrics.frozen_overlap_contraction_excess_audit_maximum <= metrics.numerical_tolerance ||
        push!(findings, "FROZEN_CONTRACTION_EXCESS_AUDIT")
    return findings
end

"""Materialize neighbor overlaps before target-scoped finite-band qualification."""
function _hamiltonian_operator_neighbor_overlaps(state, gauge_contract)
    topology = state.topology
    overlaps = Array{ComplexF64, 4}(
        undef,
        topology.num_bands,
        topology.num_bands,
        topology.num_neighbors,
        topology.num_kpts,
    )
    for center in 1:topology.num_kpts, neighbor in 1:topology.num_neighbors
        native_matrix = uiu_center_neighbor_block(state, center, neighbor)
        right_index = topology.neighbors[neighbor, center]
        matrix = rotate_generation_link(native_matrix, gauge_contract, center, right_index)
        all(isfinite, matrix) ||
            throw(ArgumentError("physical-metric neighbor overlap contains NaN or Inf"))
        overlaps[:, :, neighbor, center] .= matrix
    end
    return overlaps
end

"""Accumulate finite Galerkin block norms and structural exchange-Hermiticity evidence."""
mutable struct _HamiltonianOperatorGalerkinBlockAudit
    block_count::Int
    maximum_frobenius_norm::Float64
    maximum_frobenius_product_bound::Float64
    minimum_block_to_bound_ratio::Float64
    maximum_frobenius_product_bound_slack_fraction::Float64
    exchange_hermiticity_maximum::Float64
    exchange_hermiticity_tolerance::Float64
end

"""Construct an empty finite Galerkin block audit accumulator."""
_HamiltonianOperatorGalerkinBlockAudit() =
    _HamiltonianOperatorGalerkinBlockAudit(0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0)

"""Record a cheap, rigorous Frobenius product bound without claiming actual error."""
function _record_hamiltonian_operator_galerkin_block!(
    audit::_HamiltonianOperatorGalerkinBlockAudit,
    block,
    product_bound::Float64;
    numerical_tolerance::Float64,
)
    all(isfinite, block) || throw(ArgumentError("GALERKIN_OPERATOR_BLOCK_NONFINITE"))
    isfinite(product_bound) && product_bound >= 0.0 ||
        throw(ArgumentError("GALERKIN_OPERATOR_PRODUCT_BOUND_INVALID"))
    block_norm = norm(block)
    isfinite(block_norm) || throw(ArgumentError("GALERKIN_OPERATOR_BLOCK_NONFINITE"))
    block_norm <= product_bound + numerical_tolerance * max(1.0, product_bound) || throw(
        ArgumentError(
            "GALERKIN_OPERATOR_PRODUCT_BOUND_FAILED: block norm $(block_norm) exceeds $(product_bound)",
        ),
    )
    ratio = product_bound == 0.0 ? 1.0 : clamp(block_norm / product_bound, 0.0, 1.0)
    audit.block_count += 1
    audit.maximum_frobenius_norm = max(audit.maximum_frobenius_norm, block_norm)
    audit.maximum_frobenius_product_bound =
        max(audit.maximum_frobenius_product_bound, product_bound)
    audit.minimum_block_to_bound_ratio = min(audit.minimum_block_to_bound_ratio, ratio)
    audit.maximum_frobenius_product_bound_slack_fraction =
        max(audit.maximum_frobenius_product_bound_slack_fraction, 1.0 - ratio)
    return nothing
end

"""Hard-check A(b1,b2)=A(b2,b1)^dagger for one center-k uHu block table."""
function _hamiltonian_operator_uhu_exchange_hermiticity(blocks, numerical_tolerance::Float64)
    size(blocks, 1) == size(blocks, 2) ||
        throw(ArgumentError("UHU_EXCHANGE_HERMITICITY_DIMENSION_MISMATCH"))
    maximum_residual = 0.0
    maximum_scale = 1.0
    for first in axes(blocks, 1), second in axes(blocks, 2)
        forward = blocks[first, second]
        reverse = blocks[second, first]
        size(forward) == size(reverse) ||
            throw(ArgumentError("UHU_EXCHANGE_HERMITICITY_DIMENSION_MISMATCH"))
        all(isfinite, forward) && all(isfinite, reverse) ||
            throw(ArgumentError("GALERKIN_OPERATOR_BLOCK_NONFINITE"))
        maximum_residual = max(maximum_residual, maximum(abs, forward - reverse'; init = 0.0))
        maximum_scale =
            max(maximum_scale, maximum(abs, forward; init = 0.0), maximum(abs, reverse; init = 0.0))
    end
    matrix_size = isempty(blocks) ? 1 : size(first(blocks), 1)
    tolerance = max(numerical_tolerance, 512 * eps(Float64) * max(1, matrix_size) * maximum_scale)
    return (;
        maximum_residual,
        tolerance,
        status = maximum_residual <= tolerance ? "PASS" : "FAILED",
    )
end

"""Serialize the retained-contribution Galerkin block audit without an error claim."""
function _hamiltonian_operator_galerkin_audit_payload(
    audit::_HamiltonianOperatorGalerkinBlockAudit,
    operator::Symbol,
)
    return Dict(
        "status" => audit.block_count > 0 ? "RECORDED" : "NOT_RUN",
        "block_count" => audit.block_count,
        "norm_kind" => "frobenius",
        "maximum_frobenius_norm" => audit.maximum_frobenius_norm,
        "maximum_frobenius_product_bound" => audit.maximum_frobenius_product_bound,
        "minimum_block_to_bound_ratio" => audit.minimum_block_to_bound_ratio,
        "maximum_frobenius_product_bound_slack_fraction" =>
            audit.maximum_frobenius_product_bound_slack_fraction,
        "exchange_hermiticity_max_absolute_ev" =>
            operator == :uHu ? audit.exchange_hermiticity_maximum : nothing,
        "exchange_hermiticity_tolerance_ev" =>
            operator == :uHu ? audit.exchange_hermiticity_tolerance : nothing,
        "exchange_hermiticity_status" =>
            operator == :uHu ?
            (
                audit.exchange_hermiticity_maximum <= audit.exchange_hermiticity_tolerance ?
                "PASS" : "FAILED"
            ) : "NOT_APPLICABLE",
    )
end

"""Record that cancellation is deferred until the final Wannier finite-difference stencil."""
function _hamiltonian_operator_cancellation_audit_payload(
    audit::_HamiltonianOperatorGalerkinBlockAudit,
)
    return Dict(
        "status" => "NOT_AVAILABLE_BEFORE_FINAL_WANNIER_PROFILE_ASSEMBLY",
        "policy" => "DEFER_TO_FINITE_DIFFERENCE_PROFILE_CONTRACTION",
        "semantics" => "requires_absolute_sum_and_final_combination_in_the_actual_wannier_finite_difference_stencil",
        "absolute_sum" => nothing,
        "final_combination" => nothing,
        "cancellation_ratio" => nothing,
    )
end

"""Read and dimension-check the same-gauge SPN input for spin operators."""
function _generation_spn(config, state, gauge_contract)
    config.spn_file === nothing && throw(
        ArgumentError(
            "SPN_FILE_REQUIRED: sHu/sIu generation requires a same-gauge Wannier90 SPN file",
        ),
    )
    path = abspath(something(config.spn_file))
    isfile(path) || throw(ArgumentError("SPN file does not exist: $(path)"))
    config.spn_provenance_file === nothing && throw(
        ArgumentError(
            "SPN_PROVENANCE_REQUIRED: sHu/sIu generation requires a schema-1.2 provenance file",
        ),
    )
    provenance_path = abspath(something(config.spn_provenance_file))
    isfile(provenance_path) ||
        throw(ArgumentError("SPN provenance file does not exist: $(provenance_path)"))
    spn = IO.read_wannier_spn(path; formatted = config.spn_formatted)
    spn.num_bands == state.topology.num_bands && spn.num_kpts == state.topology.num_kpts ||
        throw(ArgumentError("SPN dimensions differ from the physical-metric topology"))
    gauge_artifact_sha256 =
        config.wavefunction_gauge_hdf5 === nothing ? nothing :
        sha256_file(something(config.wavefunction_gauge_hdf5))
    provenance = read_and_validate_spn_provenance(
        provenance_path,
        path;
        expected_num_bands = state.topology.num_bands,
        expected_num_kpoints = state.topology.num_kpts,
        target_authority = config.authoritative_hamiltonian,
        gauge_artifact_sha256,
        band_frame_transform_sha256 = gauge_contract.transform_sha256,
        band_frame_contract_sha256 = gauge_contract.contract_sha256,
    )
    validate_generation_spn_provenance(provenance, path, state)
    return spn, path, provenance_path, provenance
end

"""Build the fail-closed provenance payload for one generated operator."""
function _hamiltonian_operator_provenance(
    config,
    operator,
    state,
    authority,
    gauge_contract,
    spn_provenance,
    closure_metrics,
    closure_scope,
    source_generation_qualified,
    structural_failure_reasons,
    block_audit,
    output_path,
    input_sha256,
    diagnostics,
)
    artifact_published = source_generation_qualified && output_path !== nothing
    status = artifact_published ? "PASS" : "STRUCTURE_FAILED"
    diagnostic_reference_status = _hamiltonian_operator_reference_status(
        closure_metrics.outer_probability_leakage_audit_maximum,
        config.closure_tolerance,
    )
    return Dict(
        "schema" => WANNIER_HAMILTONIAN_OPERATOR_GENERATION_SCHEMA,
        "schema_version" => WANNIER_HAMILTONIAN_OPERATOR_GENERATION_SCHEMA_VERSION,
        "algorithm_version" => WANNIER_HAMILTONIAN_OPERATOR_GENERATION_ALGORITHM_VERSION,
        "operator" => String(operator),
        "qualification_stage" => "SOURCE_OPERATOR_GENERATION",
        "construction_policy" => String(config.construction_policy),
        "model_qualification" =>
            config.construction_policy == :diagnostic ? "DIAGNOSTIC_ONLY" : status,
        "manual_review_required" => config.construction_policy == :diagnostic,
        "production_eligible" => config.construction_policy == :strict && artifact_published,
        "status" => status,
        "passed" => source_generation_qualified,
        "source_generation_qualified" => source_generation_qualified,
        "artifact_published" => artifact_published,
        "failure_reasons" => structural_failure_reasons,
        "physical_overlap_available" => true,
        "finite_band_galerkin" => true,
        "physical_metric" => "PAW/USPP generalized overlap",
        "num_bands" => state.topology.num_bands,
        "num_kpoints" => state.topology.num_kpts,
        "num_neighbors" => state.topology.num_neighbors,
        "record_order" => operator == :uHu ? "ik->nn2->nn1" : "ik->nn->ispol",
        "formatted" => config.formatted,
        # Compatibility aliases: schema-1.2 consumers read these names.  They
        # are explicitly audit-only in schema 1.3.
        "closure_residual" => closure_metrics.target_probability_leakage_maximum,
        "closure_tolerance" => config.closure_tolerance,
        "closure_tolerance_semantics" => "legacy_alias_of_diagnostic_reference_audit_only",
        "closure_value_semantics" => WANNIER_HAMILTONIAN_OPERATOR_CLOSURE_SEMANTICS,
        "closure_formula" => WANNIER_HAMILTONIAN_OPERATOR_CLOSURE_FORMULA,
        "diagnostic_reference" => config.closure_tolerance,
        "diagnostic_reference_status" => diagnostic_reference_status,
        "diagnostic_reference_policy" => "AUDIT_ONLY_NOT_AN_ACTUAL_OPERATOR_ERROR_BOUND",
        "actual_operator_error_status" => WANNIER_HAMILTONIAN_OPERATOR_ACTUAL_ERROR_STATUS,
        "nbands_convergence_status" => WANNIER_HAMILTONIAN_OPERATOR_NBANDS_CONVERGENCE_STATUS,
        "target_probability_leakage_maximum" => closure_metrics.target_probability_leakage_maximum,
        "target_worst_context" => closure_metrics.target_worst_context,
        "outer_probability_leakage_audit_maximum" =>
            closure_metrics.outer_probability_leakage_audit_maximum,
        "outer_probability_leakage_audit_status" => _hamiltonian_operator_reference_status(
            closure_metrics.outer_probability_leakage_audit_maximum,
            config.closure_tolerance,
        ),
        "outer_worst_context" => closure_metrics.outer_worst_context,
        "frozen_probability_leakage_audit_maximum" =>
            closure_metrics.frozen_probability_leakage_audit_maximum,
        "frozen_probability_leakage_audit_status" => _hamiltonian_operator_reference_status(
            closure_metrics.frozen_probability_leakage_audit_maximum,
            config.closure_tolerance,
        ),
        "frozen_worst_context" => closure_metrics.frozen_worst_context,
        "parent_mutual_containment_audit_maximum" =>
            closure_metrics.parent_mutual_containment_audit_maximum,
        "parent_mutual_containment_audit_status" => _hamiltonian_operator_reference_status(
            closure_metrics.parent_mutual_containment_audit_maximum,
            config.closure_tolerance,
        ),
        "parent_worst_context" => closure_metrics.parent_worst_context,
        "parent_mutual_containment_policy" => closure_scope.parent_audit_policy,
        "parent_overlap_contraction_excess_audit_maximum" =>
            closure_metrics.parent_overlap_contraction_excess_audit_maximum,
        "outer_overlap_contraction_excess_audit_maximum" =>
            closure_metrics.outer_overlap_contraction_excess_audit_maximum,
        "frozen_overlap_contraction_excess_audit_maximum" =>
            closure_metrics.frozen_overlap_contraction_excess_audit_maximum,
        "parent_overlap_contraction_policy" => "audit_only",
        "physical_overlap_defect_psd_violation_maximum" =>
            closure_metrics.defect_psd_violation_maximum,
        "target_overlap_contraction_status" =>
            closure_metrics.defect_psd_violation_maximum <= closure_metrics.numerical_tolerance ?
            "WITHIN_NUMERICAL_REFERENCE" : "ABOVE_NUMERICAL_REFERENCE",
        "finite_overlap_contraction_policy" => "AUDIT_ONLY",
        "physical_overlap_numerical_tolerance" => closure_metrics.numerical_tolerance,
        "directed_link_policy" => "each_link_both_endpoint_scoped_one_sided_defects",
        "qualification_scope" => Dict(
            "schema" => "WannierNLQG.operator_closure_scope",
            "schema_version" => "1.0",
            "authority" => closure_scope.authority,
            "contract_sha256" => closure_scope.contract_sha256,
            "artifact_sha256" => closure_scope.artifact_sha256,
            "outer_mask_sha256" => closure_scope.outer_mask_sha256,
            "frozen_mask_sha256" => closure_scope.frozen_mask_sha256,
            "outer_rank_minimum" => closure_scope.outer_rank_minimum,
            "outer_rank_maximum" => closure_scope.outer_rank_maximum,
            "frozen_rank_minimum" => closure_scope.frozen_rank_minimum,
            "frozen_rank_maximum" => closure_scope.frozen_rank_maximum,
            "parent_audit_policy" => closure_scope.parent_audit_policy,
        ),
        "suggested_minimum_nbands" => nothing,
        "suggested_minimum_nbands_semantics" => "NOT_AVAILABLE_WITHOUT_AN_EXPLICIT_NBANDS_CONVERGENCE_SERIES",
        "galerkin_block_audit" =>
            _hamiltonian_operator_galerkin_audit_payload(block_audit, operator),
        "galerkin_cancellation_audit" =>
            _hamiltonian_operator_cancellation_audit_payload(block_audit),
        "authoritative_hamiltonian" => authority.authority,
        "authoritative_hamiltonian_digest" => authority.digest,
        "authoritative_hamiltonian_algorithm_version" => authority.algorithm_version,
        "source_band_gauge" => gauge_contract.source_band_gauge,
        "target_band_gauge" => gauge_contract.target_band_gauge,
        "band_frame_transform_sha256" => gauge_contract.transform_sha256,
        "band_frame_contract_sha256" => gauge_contract.contract_sha256,
        "band_frame_contract" => band_frame_contract_summary(gauge_contract),
        "band_gauge_rotation_sha256" => gauge_contract.transform_sha256,
        "band_gauge_rotation_semantics" => "legacy_alias_of_band_frame_transform_sha256",
        "native_hamiltonian_gauge_covariance_max_absolute_ev" =>
            native_hamiltonian_gauge_covariance_residual(authority, gauge_contract),
        "gauge_artifact_sha256" =>
            something(gauge_contract.gauge_artifact_sha256, "NOT_APPLICABLE"),
        "spn_provenance_sha256" =>
            spn_provenance === nothing ? "NOT_APPLICABLE" : spn_provenance.provenance_sha256,
        "spn_source_sha256" =>
            spn_provenance === nothing ? "NOT_APPLICABLE" : spn_provenance.spn_sha256,
        "output_file" => output_path,
        "output_sha256" => artifact_published ? sha256_file(something(output_path)) : nothing,
        "input_sha256" => input_sha256,
        "diagnostics" => diagnostics,
    )
end

"""Verify that Hamiltonian data and operator matrices share one sealed band frame."""
function _validate_hamiltonian_authority_frame_binding(authority, gauge_contract)
    if authority.authority == SYMMETRIZED_DFT_BAND_GAUGE
        authority.gauge_artifact_sha256 == gauge_contract.gauge_artifact_sha256 || throw(
            ArgumentError(
                "HAMILTONIAN_REFERENCE_MISMATCH: authority and operator gauge artifacts differ",
            ),
        )
        get(authority.input_sha256, "BAND_FRAME_TRANSFORM", "") ==
        gauge_contract.transform_sha256 || throw(
            ArgumentError(
                "HAMILTONIAN_REFERENCE_MISMATCH: authority and operator frame transforms differ",
            ),
        )
        get(authority.input_sha256, "BAND_FRAME_CONTRACT", "") == gauge_contract.contract_sha256 ||
            throw(
                ArgumentError(
                    "HAMILTONIAN_REFERENCE_MISMATCH: authority and operator frame contracts differ",
                ),
            )
    else
        native_hamiltonian_gauge_covariance_residual(authority, gauge_contract)
    end
    return nothing
end

"""Generate, roundtrip-check, and atomically qualify uHu, sHu, or sIu."""
function _generate_hamiltonian_operator(
    config::WannierHamiltonianOperatorGenerationConfig,
    operator::Symbol,
)
    operator in (:uHu, :sHu, :sIu) || throw(ArgumentError("unsupported operator $(operator)"))
    authoritative_mmn_file =
        operator_target_oracle_mmn_file(config.authoritative_mmn_file, config.target_contract)
    config.target_contract === nothing || validate_operator_target_contract_config(
        something(config.target_contract),
        config.authoritative_hamiltonian,
        config.wavefunction_gauge_hdf5,
    )
    paths = _hamiltonian_operator_paths(config; authoritative_mmn_file)
    if operator in (:sHu, :sIu)
        for (label, path) in (
            ("SPN_FILE_REQUIRED", config.spn_file),
            ("SPN_PROVENANCE_REQUIRED", config.spn_provenance_file),
        )
            path === nothing && throw(ArgumentError("$(label): sHu/sIu generation input missing"))
            isfile(something(path)) || throw(ArgumentError("$(label): $(abspath(something(path)))"))
        end
    end
    authoritative_mmn_sha256 =
        validate_authoritative_mmn_binding(config.topology_file, authoritative_mmn_file)
    state = _hamiltonian_operator_overlap_state(config)
    authority = _generation_authoritative_hamiltonian(config)
    size(authority.matrices_ev) ==
    (state.topology.num_bands, state.topology.num_bands, state.topology.num_kpts) ||
        throw(ArgumentError("authoritative Hamiltonian dimensions differ from topology"))
    gauge_contract = generation_band_gauge_contract(
        config.source,
        config.authoritative_hamiltonian,
        config.wavefunction_gauge_hdf5,
        state.topology.num_bands,
        state.topology.num_kpts,
        construction_policy = config.construction_policy,
    )
    _validate_hamiltonian_authority_frame_binding(authority, gauge_contract)
    config.target_contract === nothing || validate_operator_target_contract_frame(
        something(config.target_contract),
        gauge_contract,
        authority.authority,
        state.topology.num_bands,
        state.topology.num_kpts,
        state.topology.num_neighbors;
        authoritative_hamiltonian_digest = authority.digest,
    )
    spin_input = operator in (:sHu, :sIu) ? _generation_spn(config, state, gauge_contract) : nothing
    closure_scope = _hamiltonian_operator_closure_scope(
        config.wavefunction_gauge_hdf5,
        gauge_contract,
        state.topology,
        construction_policy = config.construction_policy,
    )
    overlaps = _hamiltonian_operator_neighbor_overlaps(state, gauge_contract)
    closure_metrics = _hamiltonian_operator_closure_metrics(
        overlaps,
        state.topology,
        closure_scope;
        numerical_tolerance = _hamiltonian_operator_overlap_numerical_tolerance(
            gauge_contract,
            state.topology.num_bands,
        ),
    )
    closure_residual = closure_metrics.target_probability_leakage_maximum
    audit_findings =
        _hamiltonian_operator_closure_audit_findings(closure_metrics, config.closure_tolerance)
    input_sha256 = copy(state.input_sha256)
    input_sha256["EIG"] = sha256_file(config.eig_file)
    input_sha256["TOPOLOGY"] = state.topology.source_sha256
    authoritative_mmn_sha256 === nothing ||
        (input_sha256["AUTHORITATIVE_MMN"] = authoritative_mmn_sha256)
    config.target_contract === nothing ||
        (input_sha256["OPERATOR_TARGET_CONTRACT"] = config.target_contract.contract_sha256)
    authority.gauge_artifact_sha256 === nothing ||
        (input_sha256["WAVEFUNCTION_GAUGE_HDF5"] = something(authority.gauge_artifact_sha256))
    spn = nothing
    spn_provenance = nothing
    if spin_input !== nothing
        spn_value, spn_path, spn_provenance_path, spn_provenance_value = something(spin_input)
        spn = spn_value
        spn_provenance = spn_provenance_value
        input_sha256["SPN"] = sha256_file(spn_path)
        input_sha256["SPN_PROVENANCE"] = sha256_file(spn_provenance_path)
    end
    input_sha256["BAND_FRAME_TRANSFORM"] = gauge_contract.transform_sha256
    input_sha256["BAND_FRAME_CONTRACT"] = gauge_contract.contract_sha256
    input_sha256["OPERATOR_CLOSURE_SCOPE"] = closure_scope.contract_sha256
    input_sha256["OPERATOR_CLOSURE_OUTER_MASK"] = closure_scope.outer_mask_sha256
    input_sha256["OPERATOR_CLOSURE_FROZEN_MASK"] = closure_scope.frozen_mask_sha256
    diagnostics = copy(state.diagnostics)
    append!(diagnostics, audit_findings)
    push!(diagnostics, "FINITE_BAND_TRUNCATION_AUDIT_ONLY")
    push!(diagnostics, "ACTUAL_OPERATOR_ERROR_NOT_ESTABLISHED")
    push!(diagnostics, "NBANDS_CONVERGENCE_NOT_RUN")

    topology = state.topology
    numerical_tolerance = closure_metrics.numerical_tolerance
    block_audit = _HamiltonianOperatorGalerkinBlockAudit()
    if operator == :uHu
        header = IO.WannierUHUHeader(
            "Generated by WannierNLQG finite-band Galerkin uHu",
            topology.num_bands,
            topology.num_kpts,
            topology.num_neighbors,
        )
        overlap_frobenius = [
            norm(@view(overlaps[:, :, neighbor, center])) for
            neighbor in 1:topology.num_neighbors, center in 1:topology.num_kpts
        ]
        hamiltonian_frobenius =
            [norm(@view(authority.matrices_ev[:, :, center])) for center in 1:topology.num_kpts]
        all(isfinite, hamiltonian_frobenius) ||
            throw(ArgumentError("AUTHORITATIVE_HAMILTONIAN_NONFINITE"))
        cached_center = Ref(0)
        cached_blocks = [
            Matrix{ComplexF64}(undef, 0, 0) for
            _ in 1:topology.num_neighbors, _ in 1:topology.num_neighbors
        ]
        function populate_center!(center)
            hamiltonian = @view authority.matrices_ev[:, :, center]
            for first in 1:topology.num_neighbors, second in 1:topology.num_neighbors
                left = @view overlaps[:, :, first, center]
                right = @view overlaps[:, :, second, center]
                block = left' * hamiltonian * right
                bound =
                    overlap_frobenius[first, center] *
                    hamiltonian_frobenius[center] *
                    overlap_frobenius[second, center]
                _record_hamiltonian_operator_galerkin_block!(
                    block_audit,
                    block,
                    bound;
                    numerical_tolerance,
                )
                cached_blocks[first, second] = block
            end
            exchange =
                _hamiltonian_operator_uhu_exchange_hermiticity(cached_blocks, numerical_tolerance)
            block_audit.exchange_hermiticity_maximum =
                max(block_audit.exchange_hermiticity_maximum, exchange.maximum_residual)
            block_audit.exchange_hermiticity_tolerance =
                max(block_audit.exchange_hermiticity_tolerance, exchange.tolerance)
            exchange.status == "PASS" || throw(
                ArgumentError(
                    "UHU_EXCHANGE_HERMITICITY_FAILED: residual $(exchange.maximum_residual) exceeds $(exchange.tolerance)",
                ),
            )
            cached_center[] = center
            return nothing
        end
        IO.write_wannier_uhu(
            paths.output,
            header;
            formatted = config.formatted,
        ) do center, second, first, _header
            cached_center[] == center || populate_center!(center)
            return cached_blocks[first, second]
        end
        count = Ref(0)
        IO.foreach_wannier_uhu_block(
            paths.output;
            formatted = config.formatted,
            expected_num_bands = topology.num_bands,
            expected_num_kpts = topology.num_kpts,
            expected_num_neighbors = topology.num_neighbors,
        ) do args...
            count[] += 1
        end
        count[] == topology.num_kpts * topology.num_neighbors^2 ||
            error("uHu record-count roundtrip failed")
    else
        header_type = operator == :sHu ? IO.WannierSHUHeader : IO.WannierSIUHeader
        writer = operator == :sHu ? IO.write_wannier_shu : IO.write_wannier_siu
        reader = operator == :sHu ? IO.foreach_wannier_shu_block : IO.foreach_wannier_siu_block
        header = header_type(
            "Generated by WannierNLQG finite-band Galerkin $(operator)",
            topology.num_bands,
            topology.num_kpts,
            topology.num_neighbors,
        )
        overlap_frobenius = [
            norm(@view(overlaps[:, :, neighbor, center])) for
            neighbor in 1:topology.num_neighbors, center in 1:topology.num_kpts
        ]
        hamiltonian_frobenius =
            [norm(@view(authority.matrices_ev[:, :, center])) for center in 1:topology.num_kpts]
        writer(paths.output, header; formatted = config.formatted) do center, neighbor, ispol, _
            native_spin_matrix = @view something(spn).data[:, :, ispol, center]
            spin_matrix = rotate_generation_single(native_spin_matrix, gauge_contract, center)
            overlap = @view overlaps[:, :, neighbor, center]
            block =
                operator == :sHu ?
                spin_matrix * (@view authority.matrices_ev[:, :, center]) * overlap :
                spin_matrix * overlap
            bound = if operator == :sHu
                norm(spin_matrix) * hamiltonian_frobenius[center] * overlap_frobenius[neighbor, center]
            else
                norm(spin_matrix) * overlap_frobenius[neighbor, center]
            end
            _record_hamiltonian_operator_galerkin_block!(
                block_audit,
                block,
                bound;
                numerical_tolerance,
            )
            return block
        end
        count = Ref(0)
        reader(
            paths.output;
            formatted = config.formatted,
            expected_num_bands = topology.num_bands,
            expected_num_kpts = topology.num_kpts,
            expected_num_neighbors = topology.num_neighbors,
        ) do args...
            count[] += 1
        end
        count[] == topology.num_kpts * topology.num_neighbors * 3 ||
            error("$(operator) record-count roundtrip failed")
    end
    push!(diagnostics, "SOURCE_OPERATOR_STRUCTURE_PASS")
    push!(diagnostics, "ARTIFACT_PUBLISHED")
    payload = _hamiltonian_operator_provenance(
        config,
        operator,
        state,
        authority,
        gauge_contract,
        spn_provenance,
        closure_metrics,
        closure_scope,
        true,
        String[],
        block_audit,
        paths.output,
        input_sha256,
        diagnostics,
    )
    uiu_atomic_json(paths.provenance, payload)
    return WannierHamiltonianOperatorGenerationResult(
        operator,
        true,
        true,
        true,
        paths.output,
        paths.provenance,
        closure_residual,
        config.closure_tolerance,
        config.closure_tolerance,
        _hamiltonian_operator_reference_status(closure_residual, config.closure_tolerance),
        WANNIER_HAMILTONIAN_OPERATOR_ACTUAL_ERROR_STATUS,
        WANNIER_HAMILTONIAN_OPERATOR_NBANDS_CONVERGENCE_STATUS,
        authority.authority,
        authority.digest,
        input_sha256,
        diagnostics,
    )
end

"""Generate a formally qualified finite-band Galerkin `.uHu` file."""
generate_wannier_uhu(config::WannierHamiltonianOperatorGenerationConfig) =
    _generate_hamiltonian_operator(config, :uHu)
"""Generate a formally qualified finite-band Galerkin `.sHu` file."""
generate_wannier_shu(config::WannierHamiltonianOperatorGenerationConfig) =
    _generate_hamiltonian_operator(config, :sHu)
"""Generate a formally qualified physical-metric `.sIu` file."""
generate_wannier_siu(config::WannierHamiltonianOperatorGenerationConfig) =
    _generate_hamiltonian_operator(config, :sIu)
