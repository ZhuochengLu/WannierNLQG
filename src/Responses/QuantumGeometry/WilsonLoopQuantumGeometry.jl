"""
Length-gauge q=0 Wilson-loop quantum Hermitian connection kernel.
"""
function compute_wilson_loop_quantum_hermitian_connection_from_cache!(
    response_kernel::Array{ComplexF64, 5},
    ws::WilsonLoopResponseWorkspace,
    band_selection::Tuple{Vector{Int}, Vector{Int}},
    finite_difference_step::Float64,
    spatial_dimension::Int64,
    ;
    tensor_indices::Union{Nothing, AbstractVector{<:Integer}} = nothing,
)
    central_data = ws.central_data
    band_start, band_end = band_selection_window(band_selection)
    band_start, band_end = expand_band_window_for_groups(band_start, band_end, central_data)
    _clear_response_kernel!(response_kernel, tensor_indices)

    derivative_axes = tensor_indices === nothing ? (1:spatial_dimension) : (tensor_indices[1],)
    @inbounds for a in derivative_axes
        response_pairs =
            tensor_indices === nothing ?
            Iterators.product(1:spatial_dimension, 1:spatial_dimension) :
            ((tensor_indices[2], tensor_indices[3]),)
        for n in band_start:band_end
            for m in band_start:band_end
                for (b, c) in response_pairs
                    prepare_wilson_transported_derivative_block!(
                        ws,
                        a,
                        m,
                        n,
                        (b,),
                        finite_difference_step,
                    )
                    response_kernel[n, m, a, b, c] =
                        wilson_loop_derivative_product_from_cache(ws, m, n, b, c)
                end
            end
        end
    end
    return response_kernel
end
