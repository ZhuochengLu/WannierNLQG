const WANNIERIZATION_CHECKPOINT_SCHEMA = "WannierNLQG.wannierization_checkpoint"
# Schema1.4 retains all2.29 scientific fields and publication2, adding complete
# current continuation inputs. Old raw states retain their accepted arrays/history
# with explicit missing-input status; old wires require archived conversion.
const WANNIERIZATION_CHECKPOINT_SCHEMA_VERSION = "3.0"
const WANNIERIZATION_REFERENCED_CHECKPOINT_SCHEMA_VERSION = "3.1"
const WANNIERIZATION_CHECKPOINT_READABLE_SCHEMA_VERSIONS = ()
const WANNIERIZATION_U_CONVERGENCE_DIAGNOSTICS_SCHEMA = "wanniernlqg.wannierization-u-convergence-diagnostics"
# Public numbering retains every field of the former 1.5 diagnostic stream.
const WANNIERIZATION_U_CONVERGENCE_DIAGNOSTICS_SCHEMA_VERSION = "1.1"
const WANNIERIZATION_FIXED_SUBSPACE_SCHEMA = "wanniernlqg.wannierization-fixed-subspace"
const LEGACY_SAWF_FIXED_SUBSPACE_SCHEMA = "wanniernlqg.sawf-fixed-subspace"
# Public numbering retains the former 1.1 projector/frame and Z/U semantics.
const WANNIERIZATION_FIXED_SUBSPACE_SCHEMA_VERSION = "2.0"
const WANNIERIZATION_FIXED_SUBSPACE_READABLE_SCHEMA_VERSIONS = ("1.0", "1.1", "2.0")

"""Read and validate a public or historical fixed-subspace HDF5 capsule."""
function read_wannierization_fixed_subspace_hdf5(filename::AbstractString)
    HDF5.enable_complex_support()
    return HDF5.h5open(filename, "r") do handle
        attributes = HDF5.attributes(handle)
        schema = String(read_hdf5_attribute_value(attributes["schema"], HDF5))
        version = String(read_hdf5_attribute_value(attributes["schema_version"], HDF5))
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
            String(read_hdf5_attribute_value(attributes["z_u_stage_semantics"], HDF5)) ==
            "disentanglement_localization_decoupled_v1" ||
                throw(ArgumentError("fixed-subspace Z/U stage semantics differ"))
        elseif version in ("1.1", "2.0")
            throw(ArgumentError("fixed-subspace $(version) capsule omits Z/U stage semantics"))
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
                    :minimum_diagonal_phase_margin,
                    :minimum_phase_kpoint,
                    :minimum_phase_neighbor,
                    :minimum_phase_wannier,
                    :minimum_phase_value,
                    :cg_beta,
                    :cg_descent_cosine,
                    :u_cg_iteration,
                    :u_cg_restart_count,
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
                group["raw_spreads"] = Float64.(
                    _diagnostic_record_value(
                        record,
                        :raw_spreads,
                        _diagnostic_record_value(record, :spreads, Float64[]),
                    ),
                )
                group["ibz_frames"] = Array{ComplexF64, 3}(ibz_frame_snapshots[record_index])
                HDF5.attributes(group["ibz_frames"])["axis_order"] = "band,wannier,irreducible_kpoint"
            end
            environment = HDF5.create_group(handle, "environment")
            write_generation_environment(environment)
        end
    end
end
