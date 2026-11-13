
# Prepare Wilson transported derivatives and write the selected quantum-Hermitian connection component at one slice point.
function _run_kslice_wilson_loop_qhc_family!(
    kpoint::Vector{Float64},
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    model::AbstractResponseModel,
    ws::WilsonLoopResponseWorkspace,
    finite_difference_vectors::Matrix{Float64},
    wannier_centers_fractional::Matrix{Float64},
    state,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    _prepare_wilson_loop_response_cache!(
        ws,
        kpoint,
        finite_difference_vectors,
        wannier_centers_fractional,
        cfg,
        model,
        spatial_dimension,
    )
    return _accumulate_kslice_wilson_loop_qhc_from_cache!(
        u_index,
        v_index,
        worker_id,
        ws,
        state,
        band_selection,
        tensor_indices,
        cfg,
        spatial_dimension,
        counter,
    )
end

# Accumulate kslice wilson loop qhc from cache into caller-owned storage.
function _accumulate_kslice_wilson_loop_qhc_from_cache!(
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::WilsonLoopResponseWorkspace,
    state,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    compute_wilson_loop_quantum_hermitian_connection_from_cache!(
        ws.qhc_response_kernel,
        ws,
        band_selection,
        cfg.finite_difference_step,
        spatial_dimension,
        tensor_indices = tensor_indices,
    )
    state.worker_data[worker_id][u_index, v_index] = quantum_hermitian_connection_component(
        ws.qhc_response_kernel,
        band_selection,
        tensor_indices,
    )
    Threads.atomic_add!(counter.active, 1)
    return true
end
