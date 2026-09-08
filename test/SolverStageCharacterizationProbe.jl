using WannierNLQG

# Reuse the small complete-stencil probe; its numerical digest also remains visible.
include(joinpath(pkgdir(WannierNLQG), "test", "WannierizationThreadDeterminismProbe.jl"))
using TOML

# Record every numeric leaf with its type and dimensions, excluding wall-clock data.
function record_solver_numeric_leaves!(records, prefix, value)
    if value isa Number
        records[prefix] = string(typeof(value), ':', bytes2hex(reinterpret(UInt8, [value])))
    elseif value isa AbstractArray && isbitstype(eltype(value)) && eltype(value) <: Number
        records[prefix] = string(
            eltype(value),
            ':',
            size(value),
            ':',
            bytes2hex(SHA.sha256(reinterpret(UInt8, vec(Array(value))))),
        )
    elseif value isa AbstractArray
        for index in eachindex(value)
            record_solver_numeric_leaves!(records, "$(prefix)[$(index)]", value[index])
        end
    elseif value isa Enum
        records[prefix] = string(value)
    elseif value isa Symbol
        records[prefix] = String(value)
    elseif value !== nothing && !(value isa AbstractString) && !(value isa AbstractDict)
        for name in fieldnames(typeof(value))
            name == :elapsed_seconds && continue
            name == :input_summary && continue
            record_solver_numeric_leaves!(records, "$(prefix).$(name)", getfield(value, name))
        end
    end
    return records
end

# Run one explicit synthetic route and retain all results for independent-process comparison.
function characterize_solver_stages(output_file)
    records = Dict{String, String}()
    retained = Dict{Symbol, W.WannierizationResult}()
    for mode in (:ordinary, :symmetry_adapted), schedule in (:joint, :two_stage)
        controls = W.WannierizationAccelerationConfig(
            schedule = schedule,
            localization_algorithm = :symmetry_projected_gradient,
            u_acceptance = :armijo,
            z_stability_window = 1,
            disentanglement_max_steps = 8,
            localization_max_steps = 8,
        )
        routed = W._replace_wannierization_config(
            config;
            input = (
                wannierization_mode = mode,
                band_representation = mode == :ordinary ? nothing : representation,
            ),
            solver = (algorithm_profile = :custom, acceleration = controls),
        )
        label = Symbol(mode, '_', schedule)
        solved = W._solve_symmetry_adapted_wannierization(routed, representation, eig, mmn, plan)
        retained[label] = solved
        unfrozen = W._replace_wannierization_config(
            routed;
            input = (frozen_min_ev = Inf, frozen_max_ev = -Inf),
        )
        unfrozen_result =
            W._solve_symmetry_adapted_wannierization(unfrozen, representation, eig, mmn, plan)
        unfrozen_result.status in (W.COMPLETED, W.COMPLETED_WITH_WARNINGS, W.MAX_ITERATIONS) ||
            error("unfrozen characterization did not retain a valid numerical trajectory")
        record_solver_numeric_leaves!(records, "$(label)_unfrozen", unfrozen_result)
        record_solver_numeric_leaves!(records, String(label), solved)
        limited = W._replace_wannierization_config(routed; solver = (max_iterations = 1,))
        record_solver_numeric_leaves!(
            records,
            "$(label)_limit",
            W._solve_symmetry_adapted_wannierization(limited, representation, eig, mmn, plan),
        )
        interrupted = W._solve_symmetry_adapted_wannierization(
            routed,
            representation,
            eig,
            mmn,
            plan;
            observer = (_, _, _, _) -> error("synthetic observer failure"),
        )
        record_solver_numeric_leaves!(records, "$(label)_observer", interrupted)
        persisted = something(interrupted.restart_state)
        resumed = W._solve_symmetry_adapted_wannierization(
            routed,
            representation,
            eig,
            mmn,
            plan;
            restart = persisted.frames,
            restart_state = persisted,
            restart_history = interrupted.history,
            restart_input_summary = interrupted.input_summary,
        )
        record_solver_numeric_leaves!(records, "$(label)_resumed", resumed)
    end
    # Both releases execute the same completed target case: baseline wire 1.17, public wire 1.0.
    workflow = first(W._load_wannierization_extension!()).WorkflowOrchestration
    completed_mode =
        Base.invokelatest(workflow._representation_with_mode_contract, representation, config)
    completed_scope = WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope(
        trues(2, 2),
        BitMatrix([true true; false false]),
    )
    completed_internal = Base.invokelatest(
        workflow._representation_with_target_subspace_contract,
        completed_mode,
        config,
        completed_scope,
    )
    has_public_completion = isdefined(workflow, :_completed_public_band_representation)
    completed_representation =
        has_public_completion ?
        Base.invokelatest(workflow._completed_public_band_representation, completed_internal) :
        completed_internal
    completed_representation.schema_version == (has_public_completion ? "1.0" : "1.17") ||
        error("characterization did not build the expected complete target contract")
    completed_config = W._replace_wannierization_config(
        config;
        input = (band_representation = completed_representation,),
    )
    completed_result = W._solve_symmetry_adapted_wannierization(
        completed_config,
        completed_representation,
        eig,
        mmn,
        plan,
    )
    record_solver_numeric_leaves!(records, "completed_target", completed_result)
    fixed_reference = retained[:symmetry_adapted_two_stage]
    projectors = zeros(ComplexF64, 2, 2, 2)
    for kpoint in 1:2
        frame = @view fixed_reference.v_matrix[:, :, kpoint]
        projectors[:, :, kpoint] .= frame * frame'
    end
    fixed_subspace = W.WannierizationFixedSubspace(
        projectors,
        fixed_reference.v_matrix,
        representation.irreducible_indices,
        BitMatrix([true true; false false]),
    )
    fixed_config = W._replace_wannierization_config(
        config;
        checkpoint = (fixed_subspace_hdf5 = "synthetic-fixed-subspace.h5",),
        solver = (
            algorithm_profile = :custom,
            initialization = :fixed_subspace,
            acceleration = W.WannierizationAccelerationConfig(schedule = :fixed_subspace),
        ),
    )
    record_solver_numeric_leaves!(
        records,
        "fixed_subspace",
        W._solve_symmetry_adapted_wannierization(
            fixed_config,
            representation,
            eig,
            mmn,
            plan;
            fixed_subspace,
        ),
    )
    singular_mmn = IOW.WannierMMN(
        mmn.num_bands,
        mmn.num_kpts,
        mmn.num_neighbors,
        zero(mmn.data),
        mmn.neighbors,
        mmn.reciprocal_shifts,
    )
    record_solver_numeric_leaves!(
        records,
        "singular",
        W._solve_symmetry_adapted_wannierization(config, representation, eig, singular_mmn, plan),
    )
    open(output_file, "w") do io
        TOML.print(io, records; sorted = true)
    end
    println("SOLVER_STAGE_NUMERICAL_LEAVES=", length(records))
end

characterize_solver_stages(only(ARGS))
