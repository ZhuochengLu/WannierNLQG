"""Each worker owns its records; models never share a mutable derivative workspace."""
make_analytic_derivative_diagnostics() = [Dict{Int, NamedTuple}() for _ in 1:Threads.maxthreadid()]

"""Record actual derivative use and a deterministic worst convergence estimate."""
function record_analytic_derivative!(diagnostics, order, source, k, errors, step, passed)
    diagnostics === nothing && return nothing
    records=diagnostics[Threads.threadid()]
    point=Tuple(Float64.(k))
    current=(
        source = source,
        count = 1,
        point = point,
        coarse_error = errors[1],
        fine_error = errors[2],
        step = step,
        passed = passed,
    )
    if haskey(records, order)
        previous=records[order]
        worst=current.fine_error>previous.fine_error ||
              (current.fine_error==previous.fine_error && current.point<previous.point) ? current :
              previous
        current=merge(worst, (count = previous.count+1, passed = previous.passed && passed))
    end
    records[order]=current
    return nothing
end

"""Merge thread/rank records using max error and lexicographic ties, without response reductions."""
function merge_analytic_derivative_diagnostics(collections)
    result=Dict{Int, NamedTuple}()
    for records in collections, (order, value) in records
        if haskey(result, order)
            previous=result[order]
            worst=value.fine_error>previous.fine_error ||
                  (value.fine_error==previous.fine_error && value.point<previous.point) ? value :
                  previous
            result[order]=merge(
                worst,
                (count = previous.count+value.count, passed = previous.passed && value.passed),
            )
        else
            result[order]=value
        end
    end
    return result
end
