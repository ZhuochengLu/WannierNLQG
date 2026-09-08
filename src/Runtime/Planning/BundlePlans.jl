# Validated task specifications, typed task policies and shared controls for one integrated-response k loop.
struct IntegralBundlePlan
    specs::Vector{NormalizedTaskSpec}
    tasks::Vector{NormalizedTaskPlan}
    controls::NormalizedRunControls
end

# Validated task specifications, typed task policies and shared controls for one planar k-resolved calculation.
struct KSliceBundlePlan
    specs::Vector{NormalizedTaskSpec}
    tasks::Vector{NormalizedTaskPlan}
    controls::NormalizedRunControls
end

"""Store spectrum tasks selected by the registry's dedicated band-structure executor."""
struct BandStructureBundlePlan
    specs::Vector{NormalizedTaskSpec}
end

# Build typed task plans from validated specs; leave tensor tuples zeroed only for the allowed mixed-rank integral bundle.
function _normalized_task_plans(specs::Vector{NormalizedTaskSpec}, controls::NormalizedRunControls)
    if isempty(controls.tensor_indices)
        plans = NormalizedTaskPlan[]
        sizehint!(plans, length(specs))
        for spec in specs
            definition = task_definition(spec.quantity, spec.method, spec.calculation)
            definition === nothing && error("Missing TaskDefinition for $(spec.label).")
            push!(
                plans,
                NormalizedTaskPlan(
                    definition,
                    (0, 0, 0, 0),
                    definition.tensor_rank,
                    definition.band_policy,
                    definition.output_policy,
                    definition.fourier_policy,
                ),
            )
        end
        return plans
    end
    return NormalizedTaskPlan[normalized_task_plan(spec, controls.tensor_indices) for spec in specs]
end

# Construct bundle plan.
function make_bundle_plan(cfg::EffectiveTaskConfig, specs::Vector{NormalizedTaskSpec})
    calculation = calculation_id(specs[1].calculation)
    definitions = map(specs) do spec
        definition = task_definition(spec.quantity, spec.method, spec.calculation)
        definition === nothing && error("Missing TaskDefinition for $(spec.label).")
        definition
    end
    all(definition -> definition.executor == EXECUTOR_BAND_STRUCTURE, definitions) &&
        return BandStructureBundlePlan(specs)
    calculation == CALCULATION_KPATH && error(
        "No K-path executor bundle is registered for $(join((spec.label for spec in specs), ", ")).",
    )
    controls = _normalized_run_controls(cfg, specs)
    tasks = _normalized_task_plans(specs, controls)
    if calculation == CALCULATION_INTEGRAL
        return IntegralBundlePlan(specs, tasks, controls)
    elseif calculation == CALCULATION_KSLICE
        return KSliceBundlePlan(specs, tasks, controls)
    end
    error("Internal error: no bundle-plan type for calculation=$(specs[1].calculation).")
end
