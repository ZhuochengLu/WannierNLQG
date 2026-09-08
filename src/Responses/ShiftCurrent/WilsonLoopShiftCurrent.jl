# Wilson-loop shift-current response assembled from the shared cache.

"""
For `(a,b,c)`, form the antisymmetrized product of the cached Wilson-transported
derivatives and central optical connections. The explicit `1/i=-i` factor is
stored inside `response_kernel[n,m,a,b,c]`; Runtime subsequently applies
occupations, broadening, physical prefactors, and k-point normalization. Cache
ownership, degenerate-block transport, pair order, and the central-difference
stencil are unchanged.
"""
function compute_wilson_loop_shift_current_from_cache!(
    response_kernel::Array{ComplexF64, 5},
    ws::WilsonLoopResponseWorkspace,
    band_start::Int64,
    band_end::Int64,
    finite_difference_step::Float64,
    spatial_dimension::Int64,
    ;
    active_pair_mask::Union{Nothing, AbstractMatrix{Bool}} = nothing,
    tensor_indices::Union{Nothing, AbstractVector{<:Integer}} = nothing,
)
    central_data = ws.central_data
    _clear_response_kernel!(response_kernel, tensor_indices)
    derivative_axes = tensor_indices === nothing ? (1:spatial_dimension) : (tensor_indices[1],)
    @inbounds for a in derivative_axes
        for n in band_start:band_end
            for m in band_start:band_end
                active_pair_mask !== nothing && !active_pair_mask[n, m] && continue
                response_pairs =
                    tensor_indices === nothing ?
                    Iterators.product(1:spatial_dimension, 1:spatial_dimension) :
                    ((tensor_indices[2], tensor_indices[3]),)
                for (b, c) in response_pairs
                    prepare_wilson_transported_derivative_block!(
                        ws,
                        a,
                        n,
                        m,
                        (c,),
                        finite_difference_step,
                    )
                    term_nm = wilson_loop_derivative_product_from_cache(ws, n, m, c, b)
                    prepare_wilson_transported_derivative_block!(
                        ws,
                        a,
                        m,
                        n,
                        (b,),
                        finite_difference_step,
                    )
                    term_mn = wilson_loop_derivative_product_from_cache(ws, m, n, b, c)
                    # Store the Wilson-loop manuscript integrand with
                    # the explicit 1/i = -i factor inside response_kernel[n,m]:
                    # \mathcal{Q}_{nm}^{abc} =
                    # -i[(D_a^W r^c_nm)r^b_mn -
                    #    (D_a^W r^b_mn)r^c_nm].
                    response_kernel[n, m, a, b, c] = -1.0im * (term_nm - term_mn)
                end
            end
        end
    end
    return response_kernel
end
