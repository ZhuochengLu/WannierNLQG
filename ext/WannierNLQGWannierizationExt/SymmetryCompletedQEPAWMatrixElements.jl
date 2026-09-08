const SYMMETRY_COMPLETED_QE_PAW_SCHEMA = "WannierNLQG.symmetry_completed_qe_paw_matrices"
const SYMMETRY_COMPLETED_QE_PAW_SCHEMA_VERSION = "1.0"

# Retain NNKP topology and trial projections while explicitly discarding its
# excluded-band mask: the completed gauge capsule is the band authority.
function _qe_topology_only_nnkp(nnkp::WannierNNKP)
    return WannierNNKP(
        nnkp.real_lattice,
        nnkp.reciprocal_lattice,
        nnkp.kpoints_fractional,
        nnkp.neighbors,
        nnkp.reciprocal_shifts,
        Int[],
        nnkp.projections,
        nnkp.spinor,
        nnkp.source_sha256,
    )
end

# Apply A'_k=U_k^dagger A_k to one parent-space AMN oracle.
function _star_rotate_parent_amn(parent::WannierAMN, rotations::Array{ComplexF64, 3})
    parent.num_bands == size(rotations, 1) ||
        throw(ArgumentError("PAW_PROPAGATION_IMPLEMENTATION_HOLD: AMN parent rank differs"))
    parent.num_kpts == size(rotations, 3) ||
        throw(ArgumentError("PAW_PROPAGATION_IMPLEMENTATION_HOLD: AMN k-point count differs"))
    target_count = size(rotations, 2)
    data = zeros(ComplexF64, target_count, parent.num_wannier, parent.num_kpts)
    for kpoint in 1:parent.num_kpts
        data[:, :, kpoint] .= @view(rotations[:, :, kpoint])' * @view(parent.data[:, :, kpoint])
    end
    return WannierAMN(target_count, parent.num_kpts, parent.num_wannier, data)
end

# Apply M'_{k,b}=U_k^dagger M_{k,b}U_{k+b} to one parent-space MMN oracle.
function _star_rotate_parent_mmn(parent::WannierMMN, rotations::Array{ComplexF64, 3})
    parent.num_bands == size(rotations, 1) ||
        throw(ArgumentError("PAW_PROPAGATION_IMPLEMENTATION_HOLD: MMN parent rank differs"))
    parent.num_kpts == size(rotations, 3) ||
        throw(ArgumentError("PAW_PROPAGATION_IMPLEMENTATION_HOLD: MMN k-point count differs"))
    target_count = size(rotations, 2)
    data = zeros(ComplexF64, target_count, target_count, parent.num_neighbors, parent.num_kpts)
    for kpoint in 1:parent.num_kpts, neighbor in 1:parent.num_neighbors
        target_kpoint = parent.neighbors[neighbor, kpoint]
        data[:, :, neighbor, kpoint] .=
            @view(rotations[:, :, kpoint])' *
            @view(parent.data[:, :, neighbor, kpoint]) *
            @view(rotations[:, :, target_kpoint])
    end
    return WannierMMN(
        target_count,
        parent.num_kpts,
        parent.num_neighbors,
        data,
        copy(parent.neighbors),
        copy(parent.reciprocal_shifts),
    )
end

"""Compare generated and oracle AMN values inside the ragged outer-window scope."""
function _star_scoped_qe_amn_parity(
    generated::WannierAMN,
    oracle::WannierAMN,
    outer_mask::AbstractMatrix{Bool},
)
    size(generated.data) == size(oracle.data) ||
        throw(ArgumentError("PAW_PROPAGATION_IMPLEMENTATION_HOLD: scoped AMN dimensions differ"))
    size(outer_mask) == (generated.num_bands, generated.num_kpts) ||
        throw(ArgumentError("TARGET_MASK_DIMENSION_HOLD: scoped AMN mask dimensions differ"))
    generated_values = ComplexF64[]
    oracle_values = ComplexF64[]
    for kpoint in 1:generated.num_kpts
        indices = findall(@view(outer_mask[:, kpoint]))
        length(indices) >= generated.num_wannier ||
            throw(ArgumentError("TARGET_MASK_RANK_HOLD: scoped AMN rank is below num_wannier"))
        append!(generated_values, vec(@view(generated.data[indices, :, kpoint])))
        append!(oracle_values, vec(@view(oracle.data[indices, :, kpoint])))
    end
    return _qe_array_parity(generated_values, oracle_values)
end

"""Compare generated and oracle MMN values inside the ragged outer-window scope."""
function _star_scoped_qe_mmn_parity(
    generated::WannierMMN,
    oracle::WannierMMN,
    outer_mask::AbstractMatrix{Bool},
)
    size(generated.data) == size(oracle.data) ||
        throw(ArgumentError("PAW_PROPAGATION_IMPLEMENTATION_HOLD: scoped MMN dimensions differ"))
    size(outer_mask) == (generated.num_bands, generated.num_kpts) ||
        throw(ArgumentError("TARGET_MASK_DIMENSION_HOLD: scoped MMN mask dimensions differ"))
    generated_values = ComplexF64[]
    oracle_values = ComplexF64[]
    for kpoint in 1:generated.num_kpts, neighbor in 1:generated.num_neighbors
        target_kpoint = generated.neighbors[neighbor, kpoint]
        source_indices = findall(@view(outer_mask[:, kpoint]))
        target_indices = findall(@view(outer_mask[:, target_kpoint]))
        (isempty(source_indices) || isempty(target_indices)) &&
            throw(ArgumentError("TARGET_MASK_RANK_HOLD: scoped MMN target is empty"))
        append!(
            generated_values,
            vec(@view(generated.data[source_indices, target_indices, neighbor, kpoint])),
        )
        append!(
            oracle_values,
            vec(@view(oracle.data[source_indices, target_indices, neighbor, kpoint])),
        )
    end
    return _qe_array_parity(generated_values, oracle_values)
end

"""Measure outer-window AMN subspace angles, projector error, rank, and conditioning."""
function _star_scoped_amn_subspace_metrics(
    generated::WannierAMN,
    oracle::WannierAMN,
    outer_mask::AbstractMatrix{Bool},
)
    size(generated.data) == size(oracle.data) ||
        throw(ArgumentError("PAW_PROPAGATION_IMPLEMENTATION_HOLD: scoped AMN dimensions differ"))
    size(outer_mask) == (generated.num_bands, generated.num_kpts) ||
        throw(ArgumentError("TARGET_MASK_DIMENSION_HOLD: scoped AMN mask dimensions differ"))
    maximum_angle = 0.0
    maximum_projector = 0.0
    worst_condition = 0.0
    minimum_rank = generated.num_wannier
    for kpoint in 1:generated.num_kpts
        indices = findall(@view(outer_mask[:, kpoint]))
        length(indices) >= generated.num_wannier ||
            throw(ArgumentError("TARGET_MASK_RANK_HOLD: scoped AMN rank is below num_wannier"))
        generated_matrix = Matrix(@view(generated.data[indices, :, kpoint]))
        oracle_matrix = Matrix(@view(oracle.data[indices, :, kpoint]))
        generated_singular = svdvals(generated_matrix)
        oracle_singular = svdvals(oracle_matrix)
        generated_rank = count(>(maximum(generated_singular) * 1.0e-12), generated_singular)
        oracle_rank = count(>(maximum(oracle_singular) * 1.0e-12), oracle_singular)
        minimum_rank = min(minimum_rank, generated_rank, oracle_rank)
        worst_condition = max(
            worst_condition,
            maximum(generated_singular) / max(minimum(generated_singular), eps(Float64)),
        )
        generated_q = Matrix(qr(generated_matrix).Q[:, 1:generated.num_wannier])
        oracle_q = Matrix(qr(oracle_matrix).Q[:, 1:oracle.num_wannier])
        singular = svdvals(generated_q' * oracle_q)
        maximum_angle = max(maximum_angle, acos(clamp(minimum(singular), -1.0, 1.0)))
        maximum_projector =
            max(maximum_projector, maximum(abs, generated_q * generated_q' - oracle_q * oracle_q'))
    end
    return maximum_angle, maximum_projector, minimum_rank, worst_condition
end

# Persist the direct-versus-rotation identity test independently from any
# historical external Wannier90 matrices.
function _write_symmetry_completed_qe_paw_provenance(
    filename::AbstractString,
    result::QEPAWMatrixElementResult,
    thresholds::QEPAWParityThresholds,
    gauge_hdf5::AbstractString,
    nnkp::WannierNNKP,
    qualification_mode::Symbol,
    ;
    target_scope_active::Bool,
    parent_mmn_parity::Union{Nothing, QEPAWArrayParityMetrics} = nothing,
    parent_amn_parity::Union{Nothing, QEPAWArrayParityMetrics} = nothing,
    parent_generalized_norm_max_absolute::Union{Nothing, Float64} = nothing,
    completed_parent_generalized_norm_max_absolute::Union{Nothing, Float64} = nothing,
)
    HDF5.enable_complex_support()
    return atomic_hdf5_write(filename) do temporary
        HDF5.h5open(temporary, "w") do handle
            attributes = HDF5.attributes(handle)
            attributes["schema"] = SYMMETRY_COMPLETED_QE_PAW_SCHEMA
            attributes["schema_version"] = SYMMETRY_COMPLETED_QE_PAW_SCHEMA_VERSION
            attributes["passed"] = result.passed
            attributes["qualification_mode"] = String(qualification_mode)
            attributes["production_eligible"] = qualification_mode == :strict && result.passed
            attributes["diagnostic_only"] = qualification_mode == :diagnostic_only
            attributes["physical_overlap_available"] = result.physical_overlap_available
            attributes["gauge_hdf5"] = abspath(gauge_hdf5)
            attributes["gauge_hdf5_sha256"] = sha256_file(gauge_hdf5)
            attributes["nnkp_sha256"] = nnkp.source_sha256
            attributes["band_authority"] = "star_covariant_paw_gauge_hdf5"
            attributes["nnkp_authority"] = "neighbor topology and ordered trial projections only"
            attributes["amn_transform"] = "A_prime=U_k_dagger*A_parent"
            attributes["mmn_transform"] = "M_prime=U_k_dagger*M_parent*U_neighbor"
            attributes["direct_path"] = "completed_WFC_plus_PAW_augmentation"
            attributes["oracle_path"] = "raw_parent_MMN_AMN_then_rectangular_rotation"
            attributes["qualification_scope"] =
                target_scope_active ? "target_subspace" : "full_parent"
            attributes["parent_qualification"] = target_scope_active ? "audit_only" : "hard_gate"
            attributes["parent_audit_status"] =
                target_scope_active &&
                any(startswith(item, "PARENT_AUDIT_EXCEEDED") for item in result.diagnostics) ?
                "AUDIT_REFERENCE_EXCEEDED" : "WITHIN_AUDIT_REFERENCE"
            input_group = HDF5.create_group(handle, "input_sha256")
            write_string_dictionary(input_group, result.input_sha256)
            threshold_group = HDF5.create_group(handle, "thresholds")
            for field in fieldnames(QEPAWParityThresholds)
                HDF5.attributes(threshold_group)[String(field)] = getfield(thresholds, field)
            end
            metric_group = HDF5.create_group(handle, "direct_vs_rotation")
            for (name, metric) in (
                ("mmn", result.mmn_parity),
                ("amn", result.amn_parity),
                ("parent_mmn", parent_mmn_parity),
                ("parent_amn", parent_amn_parity),
            )
                metric === nothing && continue
                group = HDF5.create_group(metric_group, name)
                metric_attributes = HDF5.attributes(group)
                metric_attributes["max_absolute"] = metric.max_absolute
                metric_attributes["root_mean_square"] = metric.root_mean_square
                metric_attributes["relative_l2"] = metric.relative_l2
                metric_attributes["finite"] = metric.finite
                group["worst_index"] = metric.worst_index
            end
            attributes["amn_max_principal_angle_rad"] = result.amn_max_principal_angle_rad
            attributes["amn_projector_max_absolute"] = result.amn_projector_max_absolute
            attributes["generalized_norm_max_absolute"] = result.generalized_norm_max_absolute
            parent_generalized_norm_max_absolute === nothing || (
                attributes["parent_generalized_norm_max_absolute"] =
                    something(parent_generalized_norm_max_absolute)
            )
            completed_parent_generalized_norm_max_absolute === nothing || (
                attributes["completed_parent_generalized_norm_max_absolute"] =
                    something(completed_parent_generalized_norm_max_absolute)
            )
            handle["diagnostics"] = result.diagnostics
        end
    end
end

# Reconstruct the completed 64-band parent from the sealed full-parent rotation.
# This is used only by the target-subspace authority to qualify TT/TC/CT/CC
# propagation independently of the rectangular target matrix path.
function _star_completed_parent_native(
    parent_native::NativeWavefunctionData,
    audit::_SymmetrizedDFTHamiltonianAuditPayload,
)
    parent_count = size(first(parent_native.kpoints).coefficients, 1)
    nk = length(parent_native.kpoints)
    size(audit.native_to_symmetrized_rotations) == (parent_count, parent_count, nk) ||
        throw(ArgumentError("PAW_PROPAGATION_IMPLEMENTATION_HOLD: parent rotation shape differs"))
    size(audit.symmetrized_energies_ev) == (parent_count, nk) ||
        throw(ArgumentError("PAW_PROPAGATION_IMPLEMENTATION_HOLD: parent energy shape differs"))
    points = PlaneWaveKPoint[]
    for kpoint in 1:nk
        native_point = parent_native.kpoints[kpoint]
        rotation = @view audit.native_to_symmetrized_rotations[:, :, kpoint]
        coefficients = _star_rotate_rows(native_point.coefficients, rotation)
        push!(
            points,
            PlaneWaveKPoint(
                native_point.k_fractional,
                native_point.g_vectors,
                coefficients,
                @view(audit.symmetrized_energies_ev[:, kpoint]);
                normalize_coefficients = false,
            ),
        )
    end
    return NativeWavefunctionData(
        parent_native.source_code,
        parent_native.structure,
        parent_native.reciprocal_lattice,
        parent_native.mp_grid,
        parent_native.spinor,
        points,
        parent_native.input_sha256,
        merge(
            parent_native.source_metadata,
            Dict("wavefunction_gauge_preparation" => "completed_symmetrized_parent"),
        ),
    )
end

"""
Generate authoritative completed-state QE PAW MMN/AMN and compare them against
an independently rotated raw-parent construction.

The `.nnkp` file supplies neighbor topology and trial projections only. Its
excluded-band mask never changes the completed gauge capsule's target rank.
"""
function generate_symmetry_completed_qe_paw_matrix_elements(
    source::QuantumEspressoWavefunctionSource,
    gauge_hdf5::AbstractString,
    nnkp_file::AbstractString;
    artifact_dir::AbstractString,
    thresholds::QEPAWParityThresholds = QEPAWParityThresholds(),
    qualification_mode::Symbol = :strict,
)
    qualification_mode in (:strict, :diagnostic_only) ||
        throw(ArgumentError("qualification_mode must be :strict or :diagnostic_only"))
    source.representation_cutoff_ev === nothing ||
        throw(ArgumentError("QE_PAW_RAW_COEFFICIENTS_REQUIRED: full cutoff is mandatory"))
    source.band_range === nothing &&
        throw(ArgumentError("PAW_GAUGE_TARGET_BANDS_REQUIRED: source.band_range is mandatory"))
    restored = _read_star_covariant_paw_gauge_hdf5(
        gauge_hdf5;
        construction_policy = qualification_mode == :strict ? :strict : :diagnostic,
        source,
    )
    qualification_mode == :strict &&
        restored.status != :PASS &&
        throw(ArgumentError("PAW_SEWING_HOLD: strict matrix propagation requires PASS gauge"))
    qualification_mode == :diagnostic_only &&
        !(restored.status in (:PASS, :DIAGNOSTIC_ONLY)) &&
        throw(
            ArgumentError(
                "WAVEFUNCTION_GAUGE_BACKEND_MISMATCH: diagnostic matrices require PASS or DIAGNOSTIC_ONLY gauge",
            ),
        )
    payload = restored.payload
    payload.native.source_code == :qe ||
        throw(ArgumentError("QE_AUGMENTATION_METRIC_REQUIRED: gauge artifact is not QE"))
    _validate_star_gauge_source_identity(source, payload)
    metric = payload.metric::_QEStrictSewingMetric
    nnkp = read_wannier_nnkp(nnkp_file)
    topology = _qe_topology_only_nnkp(nnkp)
    _qe_validate_nnkp_contract(payload.native, topology)

    direct_amn, _ = _qe_generate_amn(
        payload.native,
        topology,
        metric.projectors,
        metric.projector_bases,
        metric.upf_data,
        metric.plan,
        metric.spinorbit,
    )
    direct_mmn, _ = _qe_generate_mmn(
        payload.native,
        topology,
        metric.projectors,
        metric.upf_data,
        metric.plan,
        metric.spinorbit,
    )
    parent_completed_generalized_norm, parent_completed_generalized_norm_worst =
        _strict_generalized_norm_from_metric(metric, payload.native)

    parent_source = _star_source_with_band_range(source, payload.parent_band_range)
    parent_native = _read_augmentation_aware_native_source(parent_source)
    parent_metric, _, _ = _strict_sewing_metric(parent_source, parent_native)
    _qe_validate_nnkp_contract(parent_native, topology)
    parent_amn, _ = _qe_generate_amn(
        parent_native,
        topology,
        parent_metric.projectors,
        parent_metric.projector_bases,
        parent_metric.upf_data,
        parent_metric.plan,
        parent_metric.spinorbit,
    )
    parent_mmn, _ = _qe_generate_mmn(
        parent_native,
        topology,
        parent_metric.projectors,
        parent_metric.upf_data,
        parent_metric.plan,
        parent_metric.spinorbit,
    )
    rotated_amn = _star_rotate_parent_amn(parent_amn, payload.rotations)
    rotated_mmn = _star_rotate_parent_mmn(parent_mmn, payload.rotations)

    authoritative_hamiltonian = validate_authoritative_hamiltonian_key(
        get(payload.source_metadata, "authoritative_hamiltonian", ""),
    )
    target_scoped =
        payload.qualification_scope !== nothing &&
        get(payload.source_metadata, "qualification_scope", "") == "target_subspace"
    parent_mmn_parity = nothing
    parent_amn_parity = nothing
    parent_generalized_norm = nothing
    parent_norm_worst = nothing
    if target_scoped
        if authoritative_hamiltonian == "symmetrized_dft_hamiltonian"
            audit = payload.symmetrized_hamiltonian_audit
            audit === nothing && throw(
                ArgumentError(
                    "HAMILTONIAN_REFERENCE_MISMATCH: symmetrized target authority lacks the parent audit payload",
                ),
            )
            completed_parent = _star_completed_parent_native(parent_native, something(audit))
            completed_parent_metric, _, _ = _strict_sewing_metric(parent_source, completed_parent)
            direct_parent_amn, _ = _qe_generate_amn(
                completed_parent,
                topology,
                completed_parent_metric.projectors,
                completed_parent_metric.projector_bases,
                completed_parent_metric.upf_data,
                completed_parent_metric.plan,
                completed_parent_metric.spinorbit,
            )
            direct_parent_mmn, _ = _qe_generate_mmn(
                completed_parent,
                topology,
                completed_parent_metric.projectors,
                completed_parent_metric.upf_data,
                completed_parent_metric.plan,
                completed_parent_metric.spinorbit,
            )
            rotated_parent_amn = _star_rotate_parent_amn(
                parent_amn,
                something(audit).native_to_symmetrized_rotations,
            )
            rotated_parent_mmn = _star_rotate_parent_mmn(
                parent_mmn,
                something(audit).native_to_symmetrized_rotations,
            )
            parent_mmn_parity = _qe_array_parity(direct_parent_mmn.data, rotated_parent_mmn.data)
            parent_amn_parity = _qe_array_parity(direct_parent_amn.data, rotated_parent_amn.data)
            parent_generalized_norm, parent_norm_worst =
                _strict_generalized_norm_from_metric(completed_parent_metric, completed_parent)
        else
            # Native target qualification uses the identical direct/rotation
            # arrays, but their full-parent parity is audit-only.  Only the
            # outer-mask metrics below determine `passed`.
            parent_mmn_parity = _qe_array_parity(direct_mmn.data, rotated_mmn.data)
            parent_amn_parity = _qe_array_parity(direct_amn.data, rotated_amn.data)
            parent_generalized_norm = parent_completed_generalized_norm
            parent_norm_worst = parent_completed_generalized_norm_worst
        end
    end

    outer_mask =
        target_scoped ? something(payload.qualification_scope).outer_mask :
        trues(direct_amn.num_bands, direct_amn.num_kpts)
    generalized_norm, generalized_norm_worst =
        target_scoped ?
        _star_scoped_generalized_norm_from_metric(metric, payload.native, outer_mask) :
        (parent_completed_generalized_norm, parent_completed_generalized_norm_worst)
    mmn_parity =
        target_scoped ? _star_scoped_qe_mmn_parity(direct_mmn, rotated_mmn, outer_mask) :
        _qe_array_parity(direct_mmn.data, rotated_mmn.data)
    amn_parity =
        target_scoped ? _star_scoped_qe_amn_parity(direct_amn, rotated_amn, outer_mask) :
        _qe_array_parity(direct_amn.data, rotated_amn.data)
    maximum_angle, maximum_projector, minimum_rank, worst_condition =
        target_scoped ? _star_scoped_amn_subspace_metrics(direct_amn, rotated_amn, outer_mask) :
        _paw_amn_subspace_metrics(direct_amn, rotated_amn)
    norm_pass = generalized_norm <= thresholds.generalized_norm_max_absolute
    mmn_pass = _qe_metric_passes(
        mmn_parity,
        thresholds.mmn_max_absolute,
        thresholds.mmn_rms,
        thresholds.mmn_relative_l2,
    )
    amn_pass =
        _qe_metric_passes(
            amn_parity,
            thresholds.amn_max_absolute,
            thresholds.amn_rms,
            thresholds.amn_relative_l2,
        ) &&
        maximum_angle <= thresholds.amn_max_principal_angle_rad &&
        maximum_projector <= thresholds.amn_projector_max_absolute &&
        minimum_rank == direct_amn.num_wannier
    parent_norm_pass =
        parent_generalized_norm === nothing ||
        something(parent_generalized_norm) <= thresholds.generalized_norm_max_absolute
    parent_mmn_pass =
        parent_mmn_parity === nothing || _qe_metric_passes(
            something(parent_mmn_parity),
            thresholds.mmn_max_absolute,
            thresholds.mmn_rms,
            thresholds.mmn_relative_l2,
        )
    parent_amn_pass =
        parent_amn_parity === nothing || _qe_metric_passes(
            something(parent_amn_parity),
            thresholds.amn_max_absolute,
            thresholds.amn_rms,
            thresholds.amn_relative_l2,
        )
    passed = norm_pass && mmn_pass && amn_pass
    diagnostics = String[
        "generalized_norm_worst=$(generalized_norm_worst)",
        "amn_minimum_rank=$(minimum_rank)",
        "amn_worst_condition=$(worst_condition)",
        "matrix_identity=completed_WFC_direct_vs_raw_parent_rectangular_rotation",
    ]
    if target_scoped
        push!(
            diagnostics,
            "parent_completed_generalized_norm_worst=$(parent_completed_generalized_norm_worst)",
        )
        push!(diagnostics, "parent_generalized_norm_worst=$(parent_norm_worst)")
        push!(
            diagnostics,
            authoritative_hamiltonian == "symmetrized_dft_hamiltonian" ?
            "parent_matrix_identity=completed_parent_direct_vs_rotation_TT_TC_CT_CC" :
            "parent_matrix_identity=native_completed_direct_vs_full_parent_rotation",
        )
        push!(diagnostics, "parent_qualification=audit_only")
    end
    norm_pass || push!(diagnostics, "QE_GENERALIZED_NORM_FAILED")
    mmn_pass || push!(diagnostics, "PAW_PROPAGATION_IMPLEMENTATION_HOLD:MMN")
    amn_pass || push!(diagnostics, "PAW_PROPAGATION_IMPLEMENTATION_HOLD:AMN")
    parent_norm_pass || push!(diagnostics, "PARENT_AUDIT_EXCEEDED:NORM")
    parent_mmn_pass || push!(diagnostics, "PARENT_AUDIT_EXCEEDED:MMN")
    parent_amn_pass || push!(diagnostics, "PARENT_AUDIT_EXCEEDED:AMN")

    mkpath(artifact_dir)
    file_prefix =
        qualification_mode == :strict ? "symmetry_completed_qe_paw" :
        "DIAGNOSTIC_ONLY_symmetry_completed_qe_paw"
    oracle_prefix =
        qualification_mode == :strict ? "rotation_oracle_qe_paw" :
        "DIAGNOSTIC_ONLY_rotation_oracle_qe_paw"
    direct_mmn_file = write_wannier_mmn(
        joinpath(artifact_dir, file_prefix * ".mmn"),
        direct_mmn;
        comment = "WannierNLQG $(qualification_mode == :strict ? "production" : "DIAGNOSTIC_ONLY") symmetry-completed QE PAW direct path",
    )
    direct_amn_file = write_wannier_amn(
        joinpath(artifact_dir, file_prefix * ".amn"),
        direct_amn;
        comment = "WannierNLQG $(qualification_mode == :strict ? "production" : "DIAGNOSTIC_ONLY") symmetry-completed QE PAW direct path",
    )
    oracle_mmn_file = write_wannier_mmn(
        joinpath(artifact_dir, oracle_prefix * ".mmn"),
        rotated_mmn;
        comment = "WannierNLQG raw-parent rectangular-rotation oracle",
    )
    oracle_amn_file = write_wannier_amn(
        joinpath(artifact_dir, oracle_prefix * ".amn"),
        rotated_amn;
        comment = "WannierNLQG raw-parent rectangular-rotation oracle",
    )
    read_wannier_mmn(direct_mmn_file).data == direct_mmn.data ||
        throw(ArgumentError("QE_NATIVE_WRITE_READBACK_FAILED: completed MMN differs"))
    read_wannier_amn(direct_amn_file).data == direct_amn.data ||
        throw(ArgumentError("QE_NATIVE_WRITE_READBACK_FAILED: completed AMN differs"))

    provenance_hdf5 = joinpath(artifact_dir, file_prefix * ".provenance.h5")
    input_sha256 = merge(
        payload.input_sha256,
        Dict("GAUGE_HDF5" => sha256_file(gauge_hdf5), "NNKP" => nnkp.source_sha256),
    )
    artifacts = Dict(
        "mmn" => abspath(direct_mmn_file),
        "amn" => abspath(direct_amn_file),
        "rotation_oracle_mmn" => abspath(oracle_mmn_file),
        "rotation_oracle_amn" => abspath(oracle_amn_file),
        "provenance_hdf5" => abspath(provenance_hdf5),
    )
    result = QEPAWMatrixElementResult(
        direct_mmn,
        direct_amn,
        mmn_parity,
        amn_parity,
        maximum_angle,
        maximum_projector,
        generalized_norm,
        passed,
        passed,
        diagnostics,
        artifacts,
        input_sha256,
    )
    _write_symmetry_completed_qe_paw_provenance(
        provenance_hdf5,
        result,
        thresholds,
        gauge_hdf5,
        nnkp,
        qualification_mode,
        ;
        target_scope_active = target_scoped,
        parent_mmn_parity,
        parent_amn_parity,
        parent_generalized_norm_max_absolute = parent_generalized_norm,
        completed_parent_generalized_norm_max_absolute = target_scoped ?
                                                         parent_completed_generalized_norm :
                                                         nothing,
    )
    return result
end
