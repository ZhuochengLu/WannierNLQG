
# Prepare projector derivative/trace data and write the selected quantum-Hermitian connection component at one slice point.
function _run_kslice_projector_response_qhc_family!(
    kpoint::Vector{Float64},
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    model::AbstractResponseModel,
    ws::ProjectorResponseWorkspace,
    finite_difference_vectors::Matrix{Float64},
    state,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    num_orbitals::Int,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    _prepare_projector_response_cache!(
        ws,
        kpoint,
        finite_difference_vectors,
        wannier_centers_fractional,
        cfg,
        model,
        num_orbitals,
        spatial_dimension,
    )
    return _accumulate_kslice_projector_response_qhc_from_cache!(
        u_index,
        v_index,
        worker_id,
        ws,
        state,
        band_selection,
        tensor_indices,
        counter,
    )
end

# Accumulate kslice projector response qhc from cache into caller-owned storage.
function _accumulate_kslice_projector_response_qhc_from_cache!(
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ProjectorResponseWorkspace,
    state,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    compute_projector_quantum_hermitian_connection_from_cache!(
        ws.qhc_response_kernel,
        ws.central_data,
        band_selection,
        tensor_indices,
        ws.kernel_tmp1,
        ws.kernel_tmp2,
        ws.kernel_tmp3,
        ws.kernel_tmp4,
        ws.kernel_tmp5,
        ws.kernel_tmp6,
    )
    state.worker_data[worker_id][u_index, v_index] = quantum_hermitian_connection_component(
        ws.qhc_response_kernel,
        band_selection,
        tensor_indices,
    )
    Threads.atomic_add!(counter.active, 1)
    return true
end
