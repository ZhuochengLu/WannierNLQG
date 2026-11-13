
# Compute conventional quantum-Hermitian connection data for the selected groups/axes and store one worker-owned slice value.
function _run_kslice_conventional_geometry_qhc_family!(
    kpoint::Vector{Float64},
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    conventional_model::AbstractResponseModel,
    ws::ConventionalQuantumGeometryWorkspace,
    state,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    band_start::Int,
    band_end::Int,
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    num_orbitals::Int,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    compute_kpoint!(
        ws.data,
        ws.scratch,
        conventional_model,
        kpoint;
        denominator_regularization = cfg.denominator_regularization,
        spatial_dimension = spatial_dimension,
    )
    return _accumulate_kslice_conventional_geometry_qhc_family!(
        u_index,
        v_index,
        worker_id,
        ws,
        state,
        band_selection,
        band_start,
        band_end,
        tensor_indices,
        cfg,
        num_orbitals,
        spatial_dimension,
        counter,
    )
end

# Accumulate kslice conventional geometry qhc family into caller-owned storage.
function _accumulate_kslice_conventional_geometry_qhc_family!(
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ConventionalQuantumGeometryWorkspace,
    state,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    band_start::Int,
    band_end::Int,
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    num_orbitals::Int,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    state.worker_data[worker_id][u_index, v_index] =
        conventional_quantum_hermitian_connection_component(
            ws.data,
            band_selection,
            tensor_indices,
            num_orbitals,
        )
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Accumulate kslice conventional hermitian curvature tensor family into caller-owned storage.
function _accumulate_kslice_conventional_hermitian_curvature_tensor_family!(
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ConventionalQuantumGeometryWorkspace,
    state,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
    num_orbitals::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    state.worker_data[worker_id][u_index, v_index] =
        hermitian_curvature_tensor_component(ws.data, band_selection, tensor_indices, num_orbitals)
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Accumulate kslice conventional berry curvature family into caller-owned storage.
function _accumulate_kslice_conventional_berry_curvature_family!(
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ConventionalQuantumGeometryWorkspace,
    states::AbstractVector,
    tensor_indices::Vector{Int},
    num_orbitals::Int,
    occupations::AbstractVector{<:Real},
    counter::BundleFamilyCounter,
)
    isempty(states) && return false
    for state in states
        band = state.band_label
        if band === :sum
            state.worker_data[worker_id][u_index, v_index] = berry_curvature_occupied_sum_component(
                ws.data,
                tensor_indices,
                num_orbitals,
                occupations,
            )
        elseif state.band_group !== nothing
            state.worker_data[worker_id][u_index, v_index] = berry_curvature_group_sum_component(
                ws.data,
                state.band_group,
                tensor_indices,
                num_orbitals,
            )
        else
            error("Internal error: Berry_Curvature K-slice state is missing a valid band label.")
        end
    end
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Accumulate kslice conventional quantum metric family into caller-owned storage.
function _accumulate_kslice_conventional_quantum_metric_family!(
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ConventionalQuantumGeometryWorkspace,
    states::AbstractVector,
    tensor_indices::Vector{Int},
    num_orbitals::Int,
    occupations::AbstractVector{<:Real},
    counter::BundleFamilyCounter,
)
    isempty(states) && return false
    for state in states
        band = state.band_label
        if band === :sum
            state.worker_data[worker_id][u_index, v_index] = quantum_metric_band_sum_component(
                ws.data,
                tensor_indices,
                num_orbitals,
                occupations;
                contribution = state.metric_contribution,
            )
        elseif state.band_group !== nothing
            state.worker_data[worker_id][u_index, v_index] = quantum_metric_group_sum_component(
                ws.data,
                state.band_group,
                tensor_indices,
                num_orbitals;
                contribution = state.metric_contribution,
            )
        else
            error("Internal error: Quantum_Metric K-slice state is missing a valid band label.")
        end
    end
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Accumulate kslice conventional interband quantum geometry family into caller-owned storage.
function _accumulate_kslice_conventional_interband_quantum_geometry_family!(
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ConventionalQuantumGeometryWorkspace,
    berry_state,
    metric_state,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
    counter::BundleFamilyCounter,
)
    berry_state === nothing && metric_state === nothing && return false
    if berry_state !== nothing
        berry_state.worker_data[worker_id][u_index, v_index] =
            interband_berry_curvature_component(ws.data, band_selection, tensor_indices)
    end
    if metric_state !== nothing
        metric_state.worker_data[worker_id][u_index, v_index] =
            interband_quantum_metric_component(ws.data, band_selection, tensor_indices)
    end
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Accumulate kslice conventional zeeman interband quantum geometry family into caller-owned storage.
function _accumulate_kslice_conventional_zeeman_interband_quantum_geometry_family!(
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ConventionalQuantumGeometryWorkspace,
    berry_state,
    metric_state,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
    counter::BundleFamilyCounter,
)
    berry_state === nothing && metric_state === nothing && return false
    components =
        zeeman_interband_quantum_geometry_components(ws.data, band_selection, tensor_indices)
    if berry_state !== nothing
        berry_state.worker_data[worker_id][u_index, v_index] = components.berry_curvature
    end
    if metric_state !== nothing
        metric_state.worker_data[worker_id][u_index, v_index] = components.quantum_metric
    end
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Accumulate kslice conventional quantum christoffel family into caller-owned storage.
function _accumulate_kslice_conventional_quantum_christoffel_family!(
    kpoint::Vector{Float64},
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ConventionalQuantumGeometryWorkspace,
    conventional_model::AbstractResponseModel,
    finite_difference_vectors::Matrix{Float64},
    state,
    band_group::Vector{Int},
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    num_orbitals::Int,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    ws.metric_contribution = state.metric_contribution
    state.worker_data[worker_id][u_index, v_index] = quantum_christoffel_symbol_component!(
        ws,
        conventional_model,
        kpoint,
        finite_difference_vectors,
        band_group,
        tensor_indices,
        cfg.finite_difference_step,
        cfg.denominator_regularization,
        num_orbitals,
        spatial_dimension,
    )
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Accumulate kslice conventional quantum metric dipole family into caller-owned storage.
function _accumulate_kslice_conventional_quantum_metric_dipole_family!(
    kpoint::Vector{Float64},
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ConventionalQuantumGeometryWorkspace,
    conventional_model::AbstractResponseModel,
    finite_difference_vectors::Matrix{Float64},
    state,
    band_group::Vector{Int},
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    num_orbitals::Int,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    ws.metric_contribution = state.metric_contribution
    state.worker_data[worker_id][u_index, v_index] = quantum_metric_dipole_component!(
        ws,
        conventional_model,
        kpoint,
        finite_difference_vectors,
        band_group,
        tensor_indices,
        cfg.finite_difference_step,
        cfg.denominator_regularization,
        num_orbitals,
        spatial_dimension,
    )
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Accumulate kslice conventional berry curvature dipole family into caller-owned storage.
function _accumulate_kslice_conventional_berry_curvature_dipole_family!(
    kpoint::Vector{Float64},
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ConventionalQuantumGeometryWorkspace,
    conventional_model::AbstractResponseModel,
    finite_difference_vectors::Matrix{Float64},
    state,
    band_group::Vector{Int},
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    num_orbitals::Int,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    if cfg.derivative_backend == :analytic
        state.worker_data[worker_id][u_index, v_index] =
            Responses.analytic_berry_curvature_derivative_component!(
                ws,
                conventional_model,
                kpoint,
                band_group,
                tensor_indices,
                cfg.degeneracy_threshold,
                spatial_dimension,
            )
        Threads.atomic_add!(counter.active, 1)
        return true
    end
    state.worker_data[worker_id][u_index, v_index] = berry_curvature_dipole_component!(
        ws,
        conventional_model,
        kpoint,
        finite_difference_vectors,
        band_group,
        tensor_indices,
        cfg.finite_difference_step,
        cfg.denominator_regularization,
        num_orbitals,
        spatial_dimension,
    )
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Accumulate kslice conventional quantum metric quadrupole family into caller-owned storage.
function _accumulate_kslice_conventional_quantum_metric_quadrupole_family!(
    kpoint::Vector{Float64},
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ConventionalQuantumGeometryWorkspace,
    conventional_model::AbstractResponseModel,
    finite_difference_vectors::Matrix{Float64},
    state,
    band_group::Vector{Int},
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    num_orbitals::Int,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    ws.metric_contribution = state.metric_contribution
    state.worker_data[worker_id][u_index, v_index] = quantum_metric_quadrupole_component!(
        ws,
        conventional_model,
        kpoint,
        finite_difference_vectors,
        band_group,
        tensor_indices,
        cfg.finite_difference_step,
        cfg.denominator_regularization,
        num_orbitals,
        spatial_dimension,
    )
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Accumulate kslice conventional berry curvature quadrupole family into caller-owned storage.
function _accumulate_kslice_conventional_berry_curvature_quadrupole_family!(
    kpoint::Vector{Float64},
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ConventionalQuantumGeometryWorkspace,
    conventional_model::AbstractResponseModel,
    finite_difference_vectors::Matrix{Float64},
    state,
    band_group::Vector{Int},
    tensor_indices::Vector{Int},
    cfg::EffectiveTaskConfig,
    num_orbitals::Int,
    spatial_dimension::Int,
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    if cfg.derivative_backend == :analytic
        state.worker_data[worker_id][u_index, v_index] =
            Responses.analytic_berry_curvature_derivative_component!(
                ws,
                conventional_model,
                kpoint,
                band_group,
                tensor_indices,
                cfg.degeneracy_threshold,
                spatial_dimension,
            )
        Threads.atomic_add!(counter.active, 1)
        return true
    end
    state.worker_data[worker_id][u_index, v_index] = berry_curvature_quadrupole_component!(
        ws,
        conventional_model,
        kpoint,
        finite_difference_vectors,
        band_group,
        tensor_indices,
        cfg.finite_difference_step,
        cfg.denominator_regularization,
        num_orbitals,
        spatial_dimension,
    )
    Threads.atomic_add!(counter.active, 1)
    return true
end

# Accumulate kslice conventional triple phase product family into caller-owned storage.
function _accumulate_kslice_conventional_triple_phase_product_family!(
    u_index::Int,
    v_index::Int,
    worker_id::Int,
    ws::ConventionalQuantumGeometryWorkspace,
    state,
    band_selection::Tuple{Vector{Int}, Vector{Int}, Vector{Int}},
    tensor_indices::Vector{Int},
    counter::BundleFamilyCounter,
)
    state === nothing && return false
    state.worker_data[worker_id][u_index, v_index] =
        triple_phase_product_component(ws.data, band_selection, tensor_indices)
    Threads.atomic_add!(counter.active, 1)
    return true
end
