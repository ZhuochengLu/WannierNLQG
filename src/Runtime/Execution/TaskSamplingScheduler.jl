"""
Prepared response instance with its original point/lane ownership and private state.

Each work unit is `(global_point, local_evaluation, deterministic_lane)`. The point
callback consumes one worker slot; finalization performs the unchanged reduction.
The cleanup callback detaches registrations and owned input storage idempotently.
"""
struct PreparedResponseTask{E, F, C}
    units::Vector{NTuple{3, Int}}
    execute_point!::E
    finish!::F
    cleanup!::C
end

"""Find a scheduling component without changing its deterministic root."""
function sampling_component_root!(parents::Vector{Int}, index::Int)
    while parents[index] != index
        parents[index] = parents[parents[index]]
        index = parents[index]
    end
    return index
end

"""
Partition shared points without splitting any task's deterministic reduction lane.

Connected components unite points belonging to one task lane. Components may run
on separate workers, while points within a component follow the original monotone
mesh order. Task-specific MPI ownership is already encoded by each unit list.
"""
function sampling_components(prepared)
    points = sort!(unique([unit[1] for task in prepared for unit in task.units]))
    positions = Dict(point => index for (index, point) in enumerate(points))
    parents = collect(eachindex(points))
    visits = [Tuple{Int, Int, Int}[] for _ in points]
    for (task_index, task) in enumerate(prepared)
        lane_roots = Dict{Int, Int}()
        previous_by_lane = Dict{Int, Int}()
        for (point, evaluation, lane) in task.units
            point > get(previous_by_lane, lane, 0) ||
                error("Task lane must preserve increasing mesh indices")
            previous_by_lane[lane] = point
            position = positions[point]
            push!(visits[position], (task_index, evaluation, lane))
            if haskey(lane_roots, lane)
                first_root = sampling_component_root!(parents, lane_roots[lane])
                second_root = sampling_component_root!(parents, position)
                parents[max(first_root, second_root)] = min(first_root, second_root)
            else
                lane_roots[lane] = position
            end
        end
    end
    grouped = Dict{Int, Vector{Int}}()
    for position in eachindex(points)
        root = sampling_component_root!(parents, position)
        push!(get!(grouped, root, Int[]), position)
    end
    components = [grouped[root] for root in sort!(collect(keys(grouped)))]
    return components, visits
end

"""
Evaluate all instances through a shared point scheduler and worker-local caches.

No response state or reduction lane is shared between workers. Cache generations
end at each central mesh point, bounding storage independently of mesh size.
"""
function execute_prepared_tasks!(prepared)
    components, visits = sampling_components(prepared)
    workers = Threads.nthreads()
    caches =
        [MatrixElements.SharedInterpolationCache(reuse = length(prepared) > 1) for _ in 1:workers]
    Threads.@threads :static for worker in 1:workers
        for component_index in worker:workers:length(components)
            for position in components[component_index]
                cache = caches[worker]
                MatrixElements.begin_shared_interpolation!(cache)
                MatrixElements.with_shared_interpolation(cache) do
                    for (task_index, evaluation, lane) in visits[position]
                        prepared[task_index].execute_point!(worker, evaluation, lane)
                    end
                end
            end
        end
    end
    stats = MatrixElements.shared_interpolation_stats.(caches)
    return stats
end
