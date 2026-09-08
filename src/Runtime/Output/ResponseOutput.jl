# Write each root-reduced integral tensor using its registered output layout and collect the created paths.
function _write_integral_states!(
    cfg::EffectiveTaskConfig,
    ctx::RunContext,
    states::AbstractVector{<:IntegralTaskAccumulator},
    debug_lock::ReentrantLock,
)
    outputs = String[]
    photon_energies = Float64[x for x in cfg.photon_energies]
    spatial_dimension = Int64(cfg.spatial_dimension)
    for state in states
        filename =
            result_filename(ctx.system_name, state.spec.quantity, state.spec.method, :integral)
        output_path = joinpath(ctx.run_dir, filename)
        write_t0 = time()
        bundle_debug_log(debug_lock, "[write] start output_path=$(output_path)")
        write_response_tensor(
            cfg.fermi_energy,
            photon_energies,
            state.global_data,
            spatial_dimension,
            ctx.run_dir,
            filename,
            digits = cfg.response_output_digits,
        )
        bundle_debug_log(
            debug_lock,
            "[write] end output_path=$(output_path) elapsed=$(format_seconds(time() - write_t0))s",
        )
        append!(outputs, state.outputs)
    end
    return outputs
end

# Write root-reduced real-only or separate real/imaginary slice matrices according to each task's output contract.
function _write_kslice_states!(
    cfg::EffectiveTaskConfig,
    ctx::RunContext,
    states::Vector{KSliceTaskAccumulator},
    debug_lock::ReentrantLock,
)
    outputs = String[]
    k_mesh = Int[x for x in cfg.k_mesh]
    for state in states
        if is_real_only_kslice_quantity(state.spec.quantity)
            filename = result_filename(
                ctx.system_name,
                state.spec.quantity,
                state.spec.method,
                :kslice;
                band = state.band_label,
            )
            output_path = joinpath(ctx.run_dir, filename)
            write_t0 = time()
            bundle_debug_log(debug_lock, "[write] start output_path=$(output_path)")
            write_kslice(real(state.global_data), k_mesh, ctx.run_dir, filename)
            bundle_debug_log(
                debug_lock,
                "[write] end output_path=$(output_path) elapsed=$(format_seconds(time() - write_t0))s",
            )
            append!(outputs, state.outputs)
            continue
        end
        filename_r = result_filename(
            ctx.system_name,
            state.spec.quantity,
            state.spec.method,
            :kslice;
            part = :r,
            band = state.band_label,
        )
        filename_i = result_filename(
            ctx.system_name,
            state.spec.quantity,
            state.spec.method,
            :kslice;
            part = :i,
            band = state.band_label,
        )
        output_path_r = joinpath(ctx.run_dir, filename_r)
        output_path_i = joinpath(ctx.run_dir, filename_i)
        write_r_t0 = time()
        bundle_debug_log(debug_lock, "[write] start output_path=$(output_path_r)")
        write_kslice(real(state.global_data), k_mesh, ctx.run_dir, filename_r)
        bundle_debug_log(
            debug_lock,
            "[write] end output_path=$(output_path_r) elapsed=$(format_seconds(time() - write_r_t0))s",
        )
        write_i_t0 = time()
        bundle_debug_log(debug_lock, "[write] start output_path=$(output_path_i)")
        write_kslice(imag(state.global_data), k_mesh, ctx.run_dir, filename_i)
        bundle_debug_log(
            debug_lock,
            "[write] end output_path=$(output_path_i) elapsed=$(format_seconds(time() - write_i_t0))s",
        )
        append!(outputs, state.outputs)
    end
    return outputs
end
