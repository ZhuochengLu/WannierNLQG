
# Prepare native-frame finite-loop links and write the selected quantum-Hermitian connection component at one slice point.
function _run_kslice_geometric_loop_qhc_family!(
    kpoint::Vector{Float64},
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    model::AbstractResponseModel,
    ws::GeometricLoopResponseWorkspace,
    photon_momentum_fractional::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    wannier_centers_fractional::Matrix{Float64},
    state,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    num_orbitals::Int,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    compute_geometric_loop_quantum_hermitian_connection_kernel!(
        ws,
        kpoint,
        photon_momentum_fractional,
        finite_difference_vectors,
        wannier_centers_fractional,
        cfg.denominator_regularization,
        cfg.finite_difference_step,
        spatial_dimension,
        model,
        band_selection,
        cfg.degeneracy_threshold,
        tensor_indices = tensor_indices,
    )
    state.worker_data[worker_id][u_index, v_index] =
        quantum_hermitian_connection_component(ws.response_kernel, band_selection, tensor_indices)
    Threads.atomic_add!(counter.active, 1)
    return true
end
