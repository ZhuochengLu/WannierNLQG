# Reduce globally stable lane buffers in lane order across MPI and reconstruct symmetry-projected tensors on the root rank.
function _reduce_integral_states!(
    states::AbstractVector{<:IntegralTaskAccumulator},
    root::Int,
    rank::Int,
    comm,
)
    for state in states
        if state.tensor_symmetry_plan !== nothing
            local_coefficients = something(state.local_coefficients)
            global_coefficients = something(state.global_coefficients)
            fill!(local_coefficients, COMPLEX_ZERO)
            for lane_coefficients in something(state.worker_coefficients)
                reduced_lane = bundle_mpi_reduce_sum(lane_coefficients, root, comm)
                if rank == root
                    local_coefficients .+= reduced_lane
                end
            end
            if rank == root
                global_coefficients .= local_coefficients
                reconstruct_integral_symmetry_tensor!(state)
            end
            continue
        end
        fill!(state.local_data, COMPLEX_ZERO)
        for lane_data in state.worker_data
            reduced_lane = bundle_mpi_reduce_sum(lane_data, root, comm)
            if rank == root
                state.local_data .+= reduced_lane
            end
        end
        if rank == root
            state.global_data .= state.local_data
        end
    end
    return nothing
end

# Sum worker slice matrices in worker order, reduce across MPI, and write the root's global slice data.
function _reduce_kslice_states!(states::Vector{KSliceTaskAccumulator}, root::Int, rank::Int, comm)
    for state in states
        fill!(state.local_data, COMPLEX_ZERO)
        for worker_data in state.worker_data
            state.local_data .+= worker_data
        end
        reduced = bundle_mpi_reduce_sum(state.local_data, root, comm)
        if rank == root
            state.global_data .= reduced
        end
    end
    return nothing
end
