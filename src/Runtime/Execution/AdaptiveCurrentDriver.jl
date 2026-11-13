"""Retain the internal adaptive-current entry through the common Integral provider.

The ordinary response preparation owns all physical kernels and point channels.
This forwarding entry preserves the former internal call signature; no separate
adaptive current kernel, workspace or sampling loop is maintained here.
"""
function prepare_adaptive_current(
    cfg,
    ctx,
    specs;
    prepare_only = false,
    progress_owner = true,
    shared_sources = nothing,
    mixed_memory_limit_bytes = mixed_fourier_memory_limit(),
)
    spec = only(specs)
    spec.quantity in (:shift_current, :injection_current) && spec.method == :conventional ||
        throw(ArgumentError("unsupported adaptive current evaluator"))
    return _run_integral_bundle_fused!(
        cfg,
        ctx,
        specs,
        _normalized_run_controls(cfg, specs);
        prepare_only,
        progress_owner,
        shared_sources,
        mixed_memory_limit_bytes,
    )
end
