"""
Dispatch validated task specs or a typed bundle plan to the band, integral or slice execution driver.

Return output/evidence summaries after the shared computation and output stage; numerical errors propagate to `run` for lifecycle cleanup.
"""
function run_task_bundle_fused!(
    cfg::EffectiveTaskConfig,
    ctx::RunContext,
    specs::Vector{NormalizedTaskSpec},
)
    return run_task_bundle_fused!(cfg, ctx, make_bundle_plan(cfg, specs))
end

"""
Dispatch validated task specs or a typed bundle plan to the band, integral or slice execution driver.

Return output/evidence summaries after the shared computation and output stage; numerical errors propagate to `run` for lifecycle cleanup.
"""
function run_task_bundle_fused!(cfg::EffectiveTaskConfig, ctx::RunContext, plan::IntegralBundlePlan)
    return _run_integral_bundle_fused!(cfg, ctx, plan.specs, plan.controls)
end

"""
Dispatch validated task specs or a typed bundle plan to the band, integral or slice execution driver.

Return output/evidence summaries after the shared computation and output stage; numerical errors propagate to `run` for lifecycle cleanup.
"""
function run_task_bundle_fused!(cfg::EffectiveTaskConfig, ctx::RunContext, plan::KSliceBundlePlan)
    return _run_kslice_bundle_fused!(cfg, ctx, plan.specs)
end
