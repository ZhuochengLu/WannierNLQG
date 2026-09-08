const WANNIERIZATION_CHECKPOINT_SCHEMA = "WannierNLQG.wannierization_checkpoint"
# Public numbering changes the wire identity, not the complete legacy 2.28 contract.
const WANNIERIZATION_CHECKPOINT_SCHEMA_VERSION = "1.0"
const WANNIERIZATION_CHECKPOINT_READABLE_SCHEMA_VERSIONS = (
    "1.0",
    "2.0",
    "2.1",
    "2.2",
    "2.3",
    "2.4",
    "2.5",
    "2.6",
    "2.7",
    "2.8",
    "2.9",
    "2.10",
    "2.11",
    "2.12",
    "2.13",
    "2.14",
    "2.15",
    "2.16",
    "2.17",
    "2.18",
    "2.19",
    "2.20",
    "2.21",
    "2.22",
    "2.23",
    "2.24",
    "2.25",
    "2.26",
    "2.27",
    "2.28",
)
const WANNIERIZATION_U_CONVERGENCE_DIAGNOSTICS_SCHEMA = "wanniernlqg.wannierization-u-convergence-diagnostics"
# Public numbering retains every field of the former 1.5 diagnostic stream.
const WANNIERIZATION_U_CONVERGENCE_DIAGNOSTICS_SCHEMA_VERSION = "1.0"
const WANNIERIZATION_FIXED_SUBSPACE_SCHEMA = "wanniernlqg.wannierization-fixed-subspace"
const LEGACY_SAWF_FIXED_SUBSPACE_SCHEMA = "wanniernlqg.sawf-fixed-subspace"
# Public numbering retains the former 1.1 projector/frame and Z/U semantics.
const WANNIERIZATION_FIXED_SUBSPACE_SCHEMA_VERSION = "1.0"
const WANNIERIZATION_FIXED_SUBSPACE_READABLE_SCHEMA_VERSIONS = ("1.0", "1.1")

"""Atomically persist a sealed full-BZ projector field and deterministic frame."""
function write_wannierization_fixed_subspace_hdf5(
    filename::AbstractString,
    fixed_subspace::WannierizationFixedSubspace,
)
    HDF5.enable_complex_support()
    return atomic_hdf5_write(filename) do temporary
        HDF5.h5open(temporary, "w") do handle
            attributes = HDF5.attributes(handle)
            attributes["schema"] = WANNIERIZATION_FIXED_SUBSPACE_SCHEMA
            attributes["schema_version"] = WANNIERIZATION_FIXED_SUBSPACE_SCHEMA_VERSION
            attributes["z_u_stage_semantics"] = "disentanglement_localization_decoupled_v1"
            handle["projectors"] = fixed_subspace.projectors
            handle["initial_frames"] = fixed_subspace.frames
            handle["irreducible_indices"] = fixed_subspace.irreducible_indices
            handle["frozen_mask"] = UInt8.(fixed_subspace.frozen_mask)
            hashes = HDF5.create_group(handle, "source_sha256")
            write_string_dictionary(hashes, fixed_subspace.source_sha256)
            residuals = HDF5.create_group(handle, "invariant_residuals")
            for key in sort!(collect(keys(fixed_subspace.invariant_residuals)))
                HDF5.attributes(residuals)[key] = fixed_subspace.invariant_residuals[key]
            end
        end
    end
end

"""Read and validate a public or historical fixed-subspace HDF5 capsule."""
function read_wannierization_fixed_subspace_hdf5(filename::AbstractString)
    HDF5.enable_complex_support()
    return HDF5.h5open(filename, "r") do handle
        attributes = HDF5.attributes(handle)
        schema = String(read(attributes["schema"]))
        version = String(read(attributes["schema_version"]))
        schema in (WANNIERIZATION_FIXED_SUBSPACE_SCHEMA, LEGACY_SAWF_FIXED_SUBSPACE_SCHEMA) ||
            throw(
                ArgumentError(
                    "fixed-subspace HDF5 schema is $(schema), expected " *
                    "$(WANNIERIZATION_FIXED_SUBSPACE_SCHEMA) or historical " *
                    "$(LEGACY_SAWF_FIXED_SUBSPACE_SCHEMA)",
                ),
            )
        version in WANNIERIZATION_FIXED_SUBSPACE_READABLE_SCHEMA_VERSIONS ||
            throw(ArgumentError("unsupported fixed-subspace schema version $(version)"))
        # Historical 1.0 has the same array layout without this 1.1-era semantic
        # marker. A declared marker is always checked, never ignored after failure.
        if haskey(attributes, "z_u_stage_semantics")
            String(read(attributes["z_u_stage_semantics"])) ==
            "disentanglement_localization_decoupled_v1" ||
                throw(ArgumentError("fixed-subspace Z/U stage semantics differ"))
        elseif version == "1.1"
            throw(ArgumentError("fixed-subspace 1.1 capsule omits Z/U stage semantics"))
        end
        hashes = read_string_dictionary(handle["source_sha256"])
        residuals = Dict{String, Float64}()
        residual_group = handle["invariant_residuals"]
        for key in keys(HDF5.attributes(residual_group))
            residuals[String(key)] = Float64(read(HDF5.attributes(residual_group)[key]))
        end
        return WannierizationFixedSubspace(
            read(handle["projectors"]),
            read(handle["initial_frames"]),
            Int.(read(handle["irreducible_indices"])),
            Bool.(read(handle["frozen_mask"]));
            source_sha256 = hashes,
            invariant_residuals = residuals,
        )
    end
end

"""Read an optional diagnostic-record field without changing older callback records."""
_diagnostic_record_value(record, name::Symbol, default) =
    hasproperty(record, name) ? getproperty(record, name) : default

"""Atomically persist the independent per-step U-convergence diagnostic stream."""
function write_wannierization_u_convergence_diagnostics_hdf5(
    filename::AbstractString,
    records::AbstractVector,
    ibz_frame_snapshots::AbstractVector,
    irreducible_indices::AbstractVector{<:Integer};
    metadata::AbstractDict = Dict{String, String}(),
)
    length(records) == length(ibz_frame_snapshots) ||
        throw(DimensionMismatch("diagnostic records and frame snapshots disagree"))
    HDF5.enable_complex_support()
    return atomic_hdf5_write(filename) do temporary
        HDF5.h5open(temporary, "w") do handle
            attributes = HDF5.attributes(handle)
            attributes["schema"] = WANNIERIZATION_U_CONVERGENCE_DIAGNOSTICS_SCHEMA
            attributes["schema_version"] = WANNIERIZATION_U_CONVERGENCE_DIAGNOSTICS_SCHEMA_VERSION
            attributes["z_u_stage_semantics"] = "disentanglement_localization_decoupled_v1"
            attributes["record_count"] = length(records)
            attributes["ibz_kpoint_count"] = length(irreducible_indices)
            write_string_dictionary(handle, Dict{String, String}(metadata))
            handle["irreducible_indices"] = Int.(irreducible_indices)
            iterations = HDF5.create_group(handle, "iterations")
            for (record_index, record) in enumerate(records)
                iteration = Int(_diagnostic_record_value(record, :iteration, record_index))
                group = HDF5.create_group(iterations, lpad(string(iteration), 6, '0'))
                group_attributes = HDF5.attributes(group)
                for name in (
                    :spread_total,
                    :trial_objective,
                    :accepted_objective,
                    :accepted_u_step_scale,
                    :localization_backtracking_steps,
                    :directional_derivative,
                    :fixed_projector_drift,
                    :base_objective,
                    :accepted_required_change,
                    :accepted_actual_change,
                    :projector_residual,
                    :maximum_covariance_error,
                    :isometry_residual,
                    :frozen_projector_residual,
                    :z_recheck_drift,
                    :one_step_geodesic_distance,
                    :two_step_geodesic_distance,
                    :aligned_one_step_geodesic_distance,
                    :minimum_diagonal_phase_margin,
                    :minimum_phase_kpoint,
                    :minimum_phase_neighbor,
                    :minimum_phase_wannier,
                    :minimum_phase_value,
                    :cg_beta,
                    :cg_descent_cosine,
                    :u_cg_iteration,
                    :u_cg_restart_count,
                    :maximum_kstar_gradient_rms,
                    :maximum_kstar_gradient_index,
                )
                    group_attributes[String(name)] = _diagnostic_record_value(record, name, NaN)
                end
                group_attributes["optimizer_phase"] =
                    String(_diagnostic_record_value(record, :optimizer_phase, :joint))
                group_attributes["anderson_reason"] =
                    String(_diagnostic_record_value(record, :anderson_reason, :NOT_RECORDED))
                group_attributes["cg_restarted"] =
                    Bool(_diagnostic_record_value(record, :cg_restarted, false))
                group_attributes["cg_restart_reason"] =
                    String(_diagnostic_record_value(record, :cg_restart_reason, :NOT_RECORDED))
                group_attributes["branch_safe_backtracking_triggered"] = Bool(
                    _diagnostic_record_value(record, :branch_safe_backtracking_triggered, false),
                )
                group["kstar_gradient_rms"] =
                    Float64.(_diagnostic_record_value(record, :kstar_gradient_rms, Float64[]))
                group["raw_spreads"] = Float64.(
                    _diagnostic_record_value(
                        record,
                        :raw_spreads,
                        _diagnostic_record_value(record, :spreads, Float64[]),
                    ),
                )
                group["block_sorted_spreads"] = Float64.(
                    _diagnostic_record_value(
                        record,
                        :block_sorted_spreads,
                        sort(_diagnostic_record_value(record, :spreads, Float64[])),
                    ),
                )
                group["gauge_aligned_spreads"] = Float64.(
                    _diagnostic_record_value(
                        record,
                        :gauge_aligned_spreads,
                        _diagnostic_record_value(record, :spreads, Float64[]),
                    ),
                )
                per_kpoint = HDF5.create_group(group, "per_kpoint")
                spectra = _diagnostic_record_value(record, :localization_spectra, Any[])
                ranks = _diagnostic_record_value(record, :localization_ranks, Int[])
                conditions = _diagnostic_record_value(record, :localization_conditions, Float64[])
                raw_phases = _diagnostic_record_value(record, :raw_eigenphases, Any[])
                aligned_phases = _diagnostic_record_value(record, :aligned_eigenphases, Any[])
                raw_distances = _diagnostic_record_value(record, :raw_geodesic_distances, Float64[])
                aligned_distances =
                    _diagnostic_record_value(record, :aligned_geodesic_distances, Float64[])
                permutations = _diagnostic_record_value(record, :block_permutations, Any[])
                block_phases = _diagnostic_record_value(record, :block_phases, Any[])
                one_step_by_k =
                    _diagnostic_record_value(record, :one_step_geodesic_distances, Float64[])
                two_step_by_k =
                    _diagnostic_record_value(record, :two_step_geodesic_distances, Float64[])
                aligned_one_step_by_k = _diagnostic_record_value(
                    record,
                    :aligned_one_step_geodesic_distances,
                    Float64[],
                )
                for (local_index, kpoint) in enumerate(irreducible_indices)
                    kgroup = HDF5.create_group(per_kpoint, lpad(string(kpoint), 6, '0'))
                    kattrs = HDF5.attributes(kgroup)
                    kattrs["kpoint"] = Int(kpoint)
                    kattrs["rank"] = isempty(ranks) ? 0 : ranks[kpoint]
                    kattrs["condition"] = isempty(conditions) ? NaN : conditions[kpoint]
                    kattrs["raw_geodesic_distance"] =
                        isempty(raw_distances) ? NaN : raw_distances[kpoint]
                    kattrs["aligned_geodesic_distance"] =
                        isempty(aligned_distances) ? NaN : aligned_distances[kpoint]
                    kattrs["one_step_geodesic_distance"] =
                        isempty(one_step_by_k) ? NaN : one_step_by_k[local_index]
                    kattrs["two_step_geodesic_distance"] =
                        isempty(two_step_by_k) ? NaN : two_step_by_k[local_index]
                    kattrs["aligned_one_step_geodesic_distance"] =
                        isempty(aligned_one_step_by_k) ? NaN : aligned_one_step_by_k[local_index]
                    kgroup["localization_singular_values"] =
                        isempty(spectra) ? Float64[] : Float64.(spectra[kpoint])
                    kgroup["raw_eigenphases"] =
                        isempty(raw_phases) ? Float64[] : Float64.(raw_phases[kpoint])
                    kgroup["aligned_eigenphases"] =
                        isempty(aligned_phases) ? Float64[] : Float64.(aligned_phases[kpoint])
                    kgroup["block_permutation"] =
                        isempty(permutations) ? Int[] : Int.(permutations[kpoint])
                    kgroup["block_phases"] =
                        isempty(block_phases) ? Float64[] : Float64.(block_phases[kpoint])
                end
                group["ibz_frames"] = Array{ComplexF64, 3}(ibz_frame_snapshots[record_index])
                HDF5.attributes(group["ibz_frames"])["axis_order"] = "band,wannier,irreducible_kpoint"
            end
            environment = HDF5.create_group(handle, "environment")
            write_generation_environment(environment)
        end
    end
end
