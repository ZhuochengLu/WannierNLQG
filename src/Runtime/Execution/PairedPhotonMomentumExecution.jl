"""One bounded frequency block with its immutable config, physical q and original-row views."""
struct PairedPhotonMomentumBlock{S, I}
    config::EffectiveTaskConfig
    fractional_momentum::Vector{Float64}
    shift_state::S
    injection_state::I
end

# Bind group rows directly to each existing lane so band-pair summation order is unchanged.
function _paired_momentum_state_view(state::IntegralTaskAccumulator{4}, rows)
    state.tensor_symmetry_plan === nothing ||
        error("paired momentum does not support symmetry projection")
    return IntegralTaskAccumulator(
        state.spec,
        state.outputs,
        [view(data,rows,:,:,:) for data in state.worker_data],
        view(state.local_data,rows,:,:,:),
        view(state.global_data,rows,:,:,:),
        nothing,
        nothing,
        nothing,
        nothing,
        nothing,
    )
end

# Bind frequency rows of the worker's point tensor without creating output/sum state.
function _paired_momentum_state_view(state::ResponseIntegralPointBuffers{4}, rows)
    state.tensor_symmetry_plan === nothing ||
        error("paired momentum does not support symmetry projection")
    return ResponseIntegralPointBuffers(
        state.spec,
        [view(data,rows,:,:,:) for data in state.worker_data],
        nothing,
    )
end

# An absent response remains absent in every paired block.
_paired_momentum_state_view(::Nothing, rows) = nothing

"""Prepare only O(N) lightweight blocks; matrix/screen storage belongs to one reusable worker."""
function make_paired_photon_momentum_blocks(
    cfg::EffectiveTaskConfig,
    model,
    shift_state,
    injection_state,
)
    path = something(cfg.photon_momentum_path)
    block_size = env_int("WANNIERNLQG_PHOTON_PATH_BLOCK_SIZE", 32)
    1 <= block_size <= 32 || throw(ArgumentError("photon path block size must lie in 1:32"))
    fields = _configuration_fields(cfg)
    return [
        let rows = group.row_indices[start:min(start + block_size - 1, length(group.row_indices))]
            group_config = EffectiveTaskConfig(;
                merge(
                    fields,
                    (
                        photon_energies = cfg.photon_energies[rows],
                        photon_momentum = group.photon_momentum,
                        photon_momentum_path = nothing,
                    ),
                )...,
            )
            PairedPhotonMomentumBlock(
                group_config,
                reciprocal_cartesian_to_fractional(collect(group.photon_momentum), model.lattice),
                _paired_momentum_state_view(shift_state, rows),
                _paired_momentum_state_view(injection_state, rows),
            )
        end for group in path.groups for start in 1:block_size:length(group.row_indices)
    ]
end

# Freeze caller-owned native arrays before any paired cache can observe them.
freeze_paired_runtime_sources(sources) = merge(sources, (; model = deepcopy(sources.model)))

"""
Evaluate exact paired groups through the unchanged finite-q response families.

Each group has its own energies, occupation/screen refresh and ordered vertices.
Only raw matrices/eigensystems at identical physical endpoints are shared by the
bounded scheduler cache. Original-row views retain each row's old k/band sums.
"""
function execute_paired_photon_momentum_point!(
    blocks,
    kpoint,
    screen,
    lane,
    model,
    geometric_workspace,
    injection_workspace,
    finite_difference_vectors,
    wannier_centers_fractional,
    tensor_indices,
    num_kpoints,
    cell_volume,
    num_orbitals,
    spatial_dimension,
    band_window_size,
    geometric_counter,
    injection_counter,
)
    active = false
    for block in blocks
        cfg = block.config
        q = block.fractional_momentum
        count = length(cfg.photon_energies)
        _prepare_photon_drag_transition_screen!(screen, kpoint, q, cfg, model, num_orbitals)
        delta = view(screen.delta,(1:count),:,:)
        if block.shift_state !== nothing
            active |= _run_integral_geometric_loop_shift_current_family!(
                kpoint,
                lane,
                model,
                geometric_workspace,
                q,
                finite_difference_vectors,
                wannier_centers_fractional,
                block.shift_state,
                tensor_indices,
                cfg,
                num_kpoints,
                cell_volume,
                num_orbitals,
                spatial_dimension,
                band_window_size,
                geometric_counter;
                photon_drag_transition_screen = screen,
                photon_drag_delta = delta,
            )
        end
        if block.injection_state !== nothing
            active |= _run_integral_photon_drag_injection_current_family!(
                kpoint,
                screen,
                lane,
                model,
                injection_workspace,
                q,
                wannier_centers_fractional,
                block.injection_state,
                tensor_indices,
                cfg,
                num_kpoints,
                cell_volume,
                num_orbitals,
                spatial_dimension,
                injection_counter;
                delta,
            )
        end
    end
    return active
end

# Bound the per-worker request by one shared rank cache allowance; workspace RSS is separate.
function paired_photon_interpolation_limits(workers::Int = Threads.nthreads())
    workers > 0 || throw(ArgumentError("photon path worker count must be positive"))
    bytes = env_int("WANNIERNLQG_PHOTON_PATH_CACHE_BYTES", 16 * 1024^2)
    0 <= bytes <= 256 * 1024^2 ||
        throw(ArgumentError("photon path cache bytes must lie in 0:268435456"))
    return (128, min(bytes, div(256 * 1024^2, workers)))
end
