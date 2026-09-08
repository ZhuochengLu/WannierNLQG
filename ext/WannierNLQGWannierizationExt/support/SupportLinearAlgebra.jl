"""Return the deterministic maximum-weight square assignment."""
function hungarian_maximum_assignment(weights::AbstractMatrix{<:Real})
    n, m = size(weights)
    n == m || throw(DimensionMismatch("Hungarian diagnostic assignment must be square"))
    all(isfinite, weights) || throw(ArgumentError("Hungarian weights must be finite"))
    cost = maximum(weights) .- Float64.(weights)
    u = zeros(Float64, n + 1)
    v = zeros(Float64, n + 1)
    p = zeros(Int, n + 1)
    way = zeros(Int, n + 1)
    for i in 1:n
        p[1] = i
        j0 = 1
        minv = fill(Inf, n + 1)
        used = falses(n + 1)
        while true
            used[j0] = true
            i0 = p[j0]
            delta = Inf
            j1 = 0
            for j in 2:(n + 1)
                used[j] && continue
                current = cost[i0, j - 1] - u[i0 + 1] - v[j]
                if current < minv[j] - eps(Float64)
                    minv[j] = current
                    way[j] = j0
                end
                if minv[j] < delta - eps(Float64) ||
                   (abs(minv[j] - delta) <= eps(Float64) && (j1 == 0 || j < j1))
                    delta = minv[j]
                    j1 = j
                end
            end
            for j in 1:(n + 1)
                if used[j]
                    u[p[j] + 1] += delta
                    v[j] -= delta
                else
                    minv[j] -= delta
                end
            end
            j0 = j1
            p[j0] == 0 && break
        end
        while true
            j1 = way[j0]
            p[j0] = p[j1]
            j0 = j1
            j0 == 1 && break
        end
    end
    assignment = zeros(Int, n)
    for j in 2:(n + 1)
        p[j] == 0 || (assignment[p[j]] = j - 1)
    end
    return assignment
end

"""Return sorted full representation blocks selected by an energy predicate."""
function complete_window_indices(
    energies::AbstractVector{<:Real},
    labels::AbstractVector{<:Integer},
    lower::Float64,
    upper::Float64,
)
    selected_labels = Set{Int}()
    for band in eachindex(energies)
        lower <= energies[band] <= upper && push!(selected_labels, labels[band])
    end
    return findall(label -> label in selected_labels, labels)
end
