const QE_PAW_SPN_SCHEMA = "wanniernlqg.qe-paw-spn"
const QE_PAW_SPN_SCHEMA_VERSION = "1.1"
const QE_PAW_SPN_ALGORITHM_VERSION = "pw2wannier90-compute-spin-paw-q0-v3-frame-contract-bound"

"""Measure Hermiticity and diagonal-imaginary residuals of a QE SPN tensor."""
function _qe_paw_spn_diagnostics(data)
    hermiticity = 0.0
    diagonal_imaginary = 0.0
    for kpoint in axes(data, 4), component in axes(data, 3)
        matrix = @view data[:, :, component, kpoint]
        hermiticity = max(hermiticity, maximum(abs, matrix - matrix'; init = 0.0))
        diagonal_imaginary = max(diagonal_imaginary, maximum(abs, imag.(diag(matrix)); init = 0.0))
    end
    return hermiticity, diagonal_imaginary
end

"""
Generate a QE PAW/USPP-aware Wannier90 SPN file from the same full-cutoff
spinor coefficients and q=0 augmentation metric used by the native MMN/uIu
backend.  The contraction follows QE `pw2wannier90::compute_spin`; an optional
upstream SPN is validation-only and never supplies matrix elements.
"""
function generate_qe_paw_spn(
    source::QuantumEspressoWavefunctionSource,
    topology_file::AbstractString;
    output_spn_file::AbstractString,
    provenance_json::AbstractString = output_spn_file * ".provenance.json",
    oracle_spn_file::Union{Nothing, AbstractString} = nothing,
    thresholds::VASPPAWSPNThresholds = VASPPAWSPNThresholds(),
    require_oracle::Bool = false,
    formatted::Bool = false,
    overwrite::Bool = false,
    max_cached_wavefunction_kpoints::Int = 8,
    execution = nothing,
    target_contract = nothing,
)
    isempty(strip(output_spn_file)) && throw(ArgumentError("output_spn_file must not be empty"))
    isempty(strip(provenance_json)) && throw(ArgumentError("provenance_json must not be empty"))
    source.band_range === nothing ||
        throw(ArgumentError("QE_NNKP_BAND_AUTHORITY_REQUIRED: source.band_range must be nothing"))
    source.representation_cutoff_ev === nothing || throw(
        ArgumentError("QE_PAW_SPN_FULL_CUTOFF_REQUIRED: representation_cutoff_ev must be nothing"),
    )
    require_oracle &&
        oracle_spn_file === nothing &&
        throw(ArgumentError("QE_PAW_SPN_ORACLE_REQUIRED: oracle_spn_file is required"))
    output = abspath(output_spn_file)
    provenance = abspath(provenance_json)
    output == provenance && throw(ArgumentError("SPN output and provenance paths must differ"))
    _validate_generation_output_paths(
        (; output, provenance),
        (topology_file, oracle_spn_file),
        source,
    )
    config = (;
        source,
        topology_file = String(topology_file),
        oracle_spn_file,
        thresholds,
        require_oracle,
        formatted,
        max_cached_wavefunction_kpoints,
        target_contract,
    )
    inputs = String[topology_file]
    oracle_spn_file === nothing || push!(inputs, String(oracle_spn_file))
    return _with_spn_publication_receipt(
        config,
        (; output, provenance),
        inputs;
        execution,
    ) do block_execution
        _generate_qe_paw_spn_impl(
            source,
            topology_file;
            output_spn_file,
            provenance_json,
            oracle_spn_file,
            thresholds,
            require_oracle,
            formatted,
            overwrite,
            max_cached_wavefunction_kpoints,
            target_contract,
            execution = block_execution,
        )
    end
end

"""Compute missing QE spin blocks and retain the original publication and diagnostic kernels."""
function _generate_qe_paw_spn_impl(
    source::QuantumEspressoWavefunctionSource,
    topology_file::AbstractString;
    output_spn_file::AbstractString,
    provenance_json::AbstractString = output_spn_file * ".provenance.json",
    oracle_spn_file::Union{Nothing, AbstractString} = nothing,
    thresholds::VASPPAWSPNThresholds = VASPPAWSPNThresholds(),
    require_oracle::Bool = false,
    formatted::Bool = false,
    overwrite::Bool = false,
    max_cached_wavefunction_kpoints::Int = 8,
    execution = nothing,
    target_contract = nothing,
)
    output = abspath(output_spn_file)
    provenance = abspath(provenance_json)
    recover_publication =
        !overwrite &&
        isfile(output) &&
        !ispath(provenance) &&
        execution !== nothing &&
        execution.resume &&
        execution.checkpoint_directory !== nothing
    ispath(output) &&
        !overwrite &&
        !recover_publication &&
        throw(ArgumentError("refusing to overwrite SPN: $(output)"))
    ispath(provenance) &&
        !overwrite &&
        throw(ArgumentError("refusing to overwrite SPN provenance: $(provenance)"))

    state = task_local_storage(:wannier_qe_defer_norm, true) do
        _uiu_qe_state(source, topology_file, max_cached_wavefunction_kpoints)
    end
    state.native.spinor || throw(
        ArgumentError("QE_PAW_SPN_SPINOR_REQUIRED: noncollinear spinor coefficients are required"),
    )
    num_bands = state.topology.num_bands
    num_kpts = state.topology.num_kpts
    total = zeros(ComplexF64, num_bands, num_bands, 3, num_kpts)
    pseudo_maximum = 0.0
    augmentation_maximum = 0.0
    block_contract = bytes2hex(
        SHA.sha256(
            join(
                [
                    QE_PAW_SPN_ALGORITHM_VERSION,
                    sha256_file(@__FILE__),
                    sha256_file(joinpath(@__DIR__, "WannierUIUGeneration.jl")),
                    repr(sort!(collect(state.input_sha256); by = first)),
                ],
                "\n",
            ),
        ),
    )
    consume = function (kpoint, result)
        block, pseudo, augmentation = result
        state.accept_norm(kpoint, result[4])
        size(block) == (num_bands, num_bands, 3) ||
            throw(ArgumentError("QE_SPN_CHECKPOINT_DIMENSION_MISMATCH"))
        all(isfinite, block) && all(isfinite, pseudo) && all(isfinite, augmentation) ||
            throw(ArgumentError("QE_SPN_CHECKPOINT_NONFINITE"))
        total[:, :, :, kpoint] .= block
        pseudo_maximum = max(pseudo_maximum, maximum(abs, pseudo; init = 0.0))
        augmentation_maximum = max(augmentation_maximum, maximum(abs, augmentation; init = 0.0))
    end
    task_local_storage(:wannier_preparation_execution, execution) do
        foreach_preparation_block(
            (_, entry) -> state.spn_evaluate_with_norm(entry),
            state.spn_input,
            consume,
            num_kpts;
            contract = block_contract,
            label = "qe-spn",
            fingerprint_index = string,
        )
    end
    state = _qe_state_with_completed_norm(state)
    state = _uiu_state_with_qualification_scope(state, target_contract)
    _record_spn_publication_blocks(:qe, execution, "qe-spn", block_contract, num_kpts)
    hermiticity, diagonal_imaginary = _qe_paw_spn_diagnostics(total)
    spn = WannierSPN(num_bands, num_kpts, total)
    oracle =
        oracle_spn_file === nothing ? nothing :
        read_wannier_spn(something(oracle_spn_file); formatted)
    oracle === nothing ||
        size(oracle.data) == size(total) ||
        throw(ArgumentError("QE_PAW_SPN_ORACLE_MISMATCH: SPN dimensions differ"))
    oracle_parity =
        oracle === nothing ? nothing :
        target_contract === nothing ? _paw_array_parity(total, oracle.data) :
        _vasp_paw_spn_scoped_parity(
            total,
            oracle.data,
            target_contract.qualification_scope.outer_mask,
        )
    oracle_pass =
        oracle_parity !== nothing && _paw_metric_passes(
            something(oracle_parity),
            thresholds.oracle_max_absolute,
            thresholds.oracle_rms,
            thresholds.oracle_relative_l2,
        )
    passed =
        state.generalized_norm <= thresholds.generalized_norm_max_absolute &&
        hermiticity <= thresholds.hermiticity_max_absolute &&
        diagonal_imaginary <= thresholds.diagonal_imaginary_max_absolute &&
        (!require_oracle || oracle_pass) &&
        (oracle_parity === nothing || oracle_pass)
    oracle_status = oracle_parity === nothing ? "NOT_PROVIDED" : oracle_pass ? "PASS" : "FAIL"
    parent_audit_status =
        state.parent_generalized_norm <= thresholds.generalized_norm_max_absolute ? "PASS" :
        "AUDIT_EXCEEDED"
    diagnostics = vcat(
        state.diagnostics,
        [
            "parent_generalized_norm_max_absolute=$(state.parent_generalized_norm)",
            "parent_audit_status=$(parent_audit_status)",
            "oracle_status=$(oracle_status)",
            "upstream_oracle=QE pw2wannier90 compute_spin",
        ],
    )
    artifacts = Dict{String, String}("provenance_json" => provenance)
    if passed
        write_path = recover_publication ? operator_publication_candidate(output) : output
        written = write_wannier_spn(
            write_path,
            spn;
            formatted,
            comment = "Generated by WannierNLQG QE PAW-SPN",
        )
        if recover_publication
            written = verify_operator_publication_candidate(written, output)
        end
        artifacts["spn"] = written
        artifacts["spn_sha256"] = sha256_file(written)
    elseif isfile(output) && overwrite
        rm(output; force = true)
    end
    oracle_spn_file === nothing || begin
        artifacts["oracle_spn"] = abspath(something(oracle_spn_file))
        artifacts["oracle_spn_sha256"] = sha256_file(something(oracle_spn_file))
    end
    input_sha256 = copy(state.input_sha256)
    target_contract === nothing ||
        (input_sha256["OPERATOR_TARGET_CONTRACT"] = target_contract.contract_sha256)
    kpoints_fractional = reduce(
        vcat,
        transpose(_uiu_kpoint_fractional(state.native, kpoint)) for kpoint in 1:num_kpts
    )
    frame_contract = _generation_band_gauge_contract(
        source,
        NativeDFTHamiltonian(),
        nothing,
        num_bands,
        num_kpts,
    )
    payload = Dict(
        "schema" => QE_PAW_SPN_SCHEMA,
        "schema_version" => QE_PAW_SPN_SCHEMA_VERSION,
        "algorithm_version" => QE_PAW_SPN_ALGORITHM_VERSION,
        "source_code" => "qe",
        "status" => passed ? "PASS" : "FAIL",
        "passed" => passed,
        "physical_metric" => "QE PAW/USPP q=0 pseudo plus augmentation",
        "spinor" => state.native.spinor,
        "num_bands" => num_bands,
        "num_kpoints" => num_kpts,
        "source_band_gauge" => NATIVE_DFT_BAND_GAUGE,
        "target_band_gauge" => NATIVE_DFT_BAND_GAUGE,
        "gauge_artifact_sha256" => "NOT_APPLICABLE",
        "band_frame_transform_sha256" => frame_contract.transform_sha256,
        "band_frame_contract_sha256" => frame_contract.contract_sha256,
        "band_frame_contract" => band_frame_contract_summary(frame_contract),
        "band_gauge_rotation_sha256" => frame_contract.transform_sha256,
        "band_gauge_rotation_semantics" => "legacy_alias_of_band_frame_transform_sha256",
        "kpoints_fractional" =>
            [collect(@view(kpoints_fractional[kpoint, :])) for kpoint in 1:num_kpts],
        "spin_components" => ["x", "y", "z"],
        "formatted" => formatted,
        "generalized_norm_max_absolute" => state.generalized_norm,
        "target_generalized_norm_max_absolute" => state.generalized_norm,
        "parent_generalized_norm_max_absolute" => state.parent_generalized_norm,
        "target_authority" => state.target_authority,
        "parent_audit_policy" => state.parent_audit_policy,
        "parent_audit_status" =>
            state.parent_generalized_norm <= thresholds.generalized_norm_max_absolute ? "PASS" :
            "AUDIT_EXCEEDED",
        "outer_mask_sha256" => state.outer_mask_sha256,
        "frozen_mask_sha256" => state.frozen_mask_sha256,
        "operator_target_contract_sha256" =>
            target_contract === nothing ? "LEGACY_NOT_RECORDED" : target_contract.contract_sha256,
        "hermiticity_max_absolute" => hermiticity,
        "diagonal_imaginary_max_absolute" => diagonal_imaginary,
        "pseudo_max_absolute" => pseudo_maximum,
        "augmentation_max_absolute" => augmentation_maximum,
        "thresholds" => Dict(
            "generalized_norm_max_absolute" => thresholds.generalized_norm_max_absolute,
            "hermiticity_max_absolute" => thresholds.hermiticity_max_absolute,
            "diagonal_imaginary_max_absolute" => thresholds.diagonal_imaginary_max_absolute,
            "oracle_max_absolute" => thresholds.oracle_max_absolute,
            "oracle_rms" => thresholds.oracle_rms,
            "oracle_relative_l2" => thresholds.oracle_relative_l2,
        ),
        "oracle_parity" =>
            oracle_parity === nothing ? nothing :
            Dict(
                "max_absolute" => something(oracle_parity).max_absolute,
                "root_mean_square" => something(oracle_parity).root_mean_square,
                "relative_l2" => something(oracle_parity).relative_l2,
                "worst_index" => something(oracle_parity).worst_index,
                "finite" => something(oracle_parity).finite,
            ),
        "artifacts" => artifacts,
        "input_sha256" => input_sha256,
        "diagnostics" => diagnostics,
    )
    payload["contract_sha256"] = _spn_provenance_contract_sha256(
        payload["schema"],
        payload["schema_version"],
        payload["source_code"],
        payload["passed"],
        payload["source_band_gauge"],
        payload["target_band_gauge"],
        payload["band_frame_transform_sha256"],
        payload["band_frame_contract_sha256"],
        payload["num_bands"],
        payload["num_kpoints"],
        payload["physical_metric"],
        payload["spinor"],
        get(artifacts, "spn_sha256", "NOT_PUBLISHED"),
        input_sha256,
        kpoints_fractional,
    )
    payload["payload_sha256"] = _qe_spn_payload_sha256(payload)
    _uiu_atomic_json(provenance, payload)
    return QEPAWSPNResult(
        passed ? spn : nothing,
        oracle_parity,
        state.generalized_norm,
        hermiticity,
        diagonal_imaginary,
        passed,
        provenance,
        artifacts,
        input_sha256,
        diagnostics,
    )
end
