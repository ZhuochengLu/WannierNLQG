# Forward validated numerical controls and active Cartesian/band requirements into the response-level Projector cache builder.
function _prepare_projector_response_cache!(
    workspace::ProjectorResponseWorkspace,
    kpoint::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    config::EffectiveTaskConfig,
    model::TightBindingModel,
    num_orbitals::Int,
    spatial_dimension::Int,
    ;
    axes::AbstractVector{<:Integer} = collect(1:spatial_dimension),
    axis_pairs::AbstractVector{<:Tuple{Int64, Int64}} = Responses.projector_response_axis_pairs(
        spatial_dimension,
    ),
    active_bands::Union{Nothing, AbstractVector{Bool}} = nothing,
    required_bands::Union{Nothing, AbstractVector{Bool}} = nothing,
)
    return Responses.prepare_projector_response_cache!(
        workspace,
        kpoint,
        finite_difference_vectors,
        model,
        num_orbitals,
        spatial_dimension;
        denominator_regularization = config.denominator_regularization,
        degeneracy_threshold = config.degeneracy_threshold,
        finite_difference_step = config.finite_difference_step,
        axes,
        axis_pairs,
        active_bands,
        required_bands,
    )
end

# Forward validated denominator/degeneracy controls, fractional centers and selected axes into the Wilson cache builder.
function _prepare_wilson_loop_response_cache!(
    workspace::WilsonLoopResponseWorkspace,
    kpoint::Vector{Float64},
    finite_difference_vectors::Matrix{Float64},
    wannier_centers_fractional::Matrix{Float64},
    config::EffectiveTaskConfig,
    model::TightBindingModel,
    spatial_dimension::Int,
    ;
    axes::AbstractVector{<:Integer} = collect(1:spatial_dimension),
)
    return Responses.prepare_wilson_loop_response_cache!(
        workspace,
        kpoint,
        finite_difference_vectors,
        wannier_centers_fractional,
        model,
        spatial_dimension;
        denominator_regularization = config.denominator_regularization,
        degeneracy_threshold = config.degeneracy_threshold,
        axes,
    )
end
