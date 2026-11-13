"""One worker's arbitrary-k response evaluator and its unchanged value contract.

The callback consumes a three-axis fractional k point. It returns borrowed worker
scratch in the declared layout and units, without quadrature weights, global
reduction or output. Physical prefactors remain at their original route boundary.
An owning consumer copies the value before the next visit to this worker.
"""
struct ResponsePointEvaluator{F, C}
    evaluate!::F
    worker::Int
    value_contract::C
    interpolation_cache::MatrixElements.SharedInterpolationCache
end

"""Bind a concrete point callback to one exclusively owned worker and cache."""
function ResponsePointEvaluator(evaluate!, worker::Int, value_contract)
    worker > 0 || throw(ArgumentError("positive response worker required"))
    return ResponsePointEvaluator(
        evaluate!,
        worker,
        value_contract,
        MatrixElements.SharedInterpolationCache(reuse = false),
    )
end

"""Evaluate a borrowed point value within this worker's interpolation generation."""
function evaluate_response_point!(evaluator::ResponsePointEvaluator, point)
    evaluator.value_contract.arbitrary_k ||
        throw(ArgumentError("this response provider requires its declared regular-grid request"))
    MatrixElements.begin_shared_interpolation!(evaluator.interpolation_cache)
    return MatrixElements.with_shared_interpolation(evaluator.interpolation_cache) do
        evaluator.evaluate!(evaluator.worker, point)
    end
end

"""Evaluate within an already owned regular-grid point and cache generation.

The sampling consumer prepares the Fourier request before this call. It retains
its existing shared cache across response visits; this entry neither starts a new
interpolation generation nor changes the original accumulation order. Arbitrary
point consumers use the two-argument entry and its capability check instead.
"""
function evaluate_response_point!(evaluator::ResponsePointEvaluator, point, ::Val{:scheduled})
    return evaluator.evaluate!(evaluator.worker, point)
end

"""Map integration coordinates independently of the physical response callback."""
struct ResponseNodeEvaluator{E, D, M, T}
    response::E
    domain::D
    model::M
    point::Vector{Float64}
    transform!::T
end

"""Allocate only the coordinate scratch owned by one integration consumer."""
ResponseNodeEvaluator(response, domain, model; transform! = identity) =
    ResponseNodeEvaluator(response, domain, model, zeros(3), transform!)

"""Return the unchanged point density at one mapped integration node."""
function (evaluator::ResponseNodeEvaluator)(node)
    response_integration_kpoint!(evaluator.point, node, evaluator.domain, evaluator.model)
    return evaluator.transform!(evaluate_response_point!(evaluator.response, evaluator.point))
end

"""Collect arbitrary point values without integration weights or output formatting.

This map consumer owns every returned tensor. The same point plan can therefore
serve a slice/point collector and an integration consumer without retaining a
worker's mutable scratch. Worker execution policy remains outside the point kernel.
"""
function collect_response_points(evaluator::ResponsePointEvaluator, points)
    shape = Ref{Any}(nothing)
    return [
        _owned_integration_value(point -> evaluate_response_point!(evaluator, point), point, shape)
        for point in points
    ]
end

"""A regular-grid consumer with independent location, Fourier request and sink.

The point provider receives only fractional coordinates. This consumer owns the
regular-grid index, prepared cache generation and destination lane or slice row.
The supplied sink retains each response's existing units, order and normalization.
"""
struct ResponseGridConsumer{E, G, P, L, R, S}
    responses::E
    grid::G
    points::P
    locate!::L
    request!::R
    consume!::S
end

"""Run one already-owned grid visit without starting a second cache generation."""
function (consumer::ResponseGridConsumer)(worker, index, lane)
    point = consumer.points[worker]
    consumer.locate!(point, consumer.grid, index)
    consumer.request!(worker, point, index)
    value = evaluate_response_point!(consumer.responses[worker], point, Val(:scheduled))
    consumer.consume!(worker, index, lane, value)
    return nothing
end

"""Prepare the original regular-grid Fourier point before invoking a provider."""
function response_grid_request(workspaces, fourier_grid, grid, slice::Bool)
    return function (worker, point, index)
        if fourier_grid !== nothing
            if slice
                u, v = kslice_indices(grid, index)
                begin_mixed_kpoint!(workspaces[worker], point, (u - 1, v - 1, 0))
            else
                begin_mixed_kpoint!(workspaces[worker], point)
            end
        end
        return nothing
    end
end

"""Worker-owned local observation channels, independent of slice grids and output.

The original band/group selection and metric decomposition identify the physical
observable. Each worker reuses one scalar buffer; no lane, mesh or file lives here.
"""
struct ResponseSlicePointBuffers
    spec::NormalizedTaskSpec
    band_label::Union{Nothing, Int, Symbol, String}
    band_group::Union{Nothing, Vector{Int}}
    worker_data::Vector{Matrix{ComplexF64}}
    metric_contribution::Symbol
end

"""Worker-owned response tensors with the original selected-component policy.

These buffers contain a single point's physical values. Integration coefficients,
reduction lanes, local/global sums and output paths belong to the consumer.
"""
struct ResponseIntegralPointBuffers{N, A <: AbstractArray{ComplexF64, N}}
    spec::NormalizedTaskSpec
    worker_data::Vector{A}
    tensor_symmetry_plan::Union{Nothing, ResponseTensorSymmetryPlan}
end

"""Allocate only scalar point channels for the existing band/component observations."""
function response_point_state(state::KSliceTaskAccumulator, workers::Int)
    buffers = [zeros(ComplexF64, 1, 1) for _ in 1:workers]
    return ResponseSlicePointBuffers(
        state.spec,
        state.band_label,
        state.band_group,
        buffers,
        state.metric_contribution,
    )
end

"""Allocate worker-private point tensors without lanes, output paths or reductions."""
function response_point_state(state::IntegralTaskAccumulator, workers::Int)
    buffers = [zeros(ComplexF64, size(state.local_data)) for _ in 1:workers]
    return ResponseIntegralPointBuffers(state.spec, buffers, state.tensor_symmetry_plan)
end

# Resolve point channels once, retaining concrete tensor rank and worker storage.
function _find_integral_point_state(states, quantity::Symbol, method::Symbol, ::Val{N}) where {N}
    state = _find_state(states, quantity, method)
    state === nothing && return nothing
    return state::ResponseIntegralPointBuffers{N, Array{ComplexF64, N}}
end

# Point production always targets its worker; lane ownership belongs to integration.
function integral_accumulator_target(
    state::ResponseIntegralPointBuffers,
    lane_id::Int,
    scratch_worker_id::Int,
)
    return state.worker_data[scratch_worker_id]
end

# Reuse the original compact-component plan without an integration accumulator.
function integral_symmetry_component_vectors(state::ResponseIntegralPointBuffers)
    return _integral_symmetry_component_vectors(
        state.spec,
        state.tensor_symmetry_plan,
        size(first(state.worker_data), 2),
    )
end
