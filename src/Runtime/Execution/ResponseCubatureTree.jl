# The controller below is adapted from HCubature.jl 1.8.0 hcubature_. Its heap
# operations, split orientation, arithmetic and stopping order are retained.
# Copyright (c) 2017 Steven G. Johnson. MIT permission and warranty notice are
# retained in THIRD_PARTY_NOTICE.md. Numerical rules remain in HCubature.jl.

"""Read one rule's owned values in order without retaining the entire rule payload."""
struct ResponseRuleValues{F}
    count::Int
    read!::F
end

"""Return the complete numerical rule's node count, independent of packet size."""
Base.length(values::ResponseRuleValues) = values.count
"""Consume the next owned node value in the original numerical rule's order."""
Base.getindex(values::ResponseRuleValues, ordinal::Int) = values.read!(ordinal)

"""Execute the reference adaptive tree with an independently supplied box rule.

Only rule-node execution is replaceable. The original HCubature Box/heap, error
updates, complete-rule budget and final re-sum order remain unchanged. This
adapter is explicitly bound to HCubature 1.8.0; the ordinary serial entry remains
the dependency implementation and is the exact differential reference.
"""
function _response_cubature_tree(
    rule,
    domain::IntegrationDomain{D},
    algorithm;
    norm = _integration_norm,
    buffer = nothing,
) where {D}
    Base.pkgversion(HCubature) == v"1.8.0" || throw(
        ArgumentError(
            "concurrent rule execution requires the qualified HCubature 1.8.0 controller",
        ),
    )
    a = HCubature.SVector{D, Float64}(domain.lower)
    b = HCubature.SVector{D, Float64}(domain.upper)
    atol = algorithm.atol
    rtol = algorithm.rtol == 0 == atol ? sqrt(eps(Float64)) : algorithm.rtol
    maxevals, initdiv = algorithm.max_evaluations, algorithm.initial_divisions
    (rtol < 0 || atol < 0) && throw(ArgumentError("invalid negative tolerance"))
    maxevals < 0 && throw(ArgumentError("invalid negative maxevals"))
    initdiv < 1 && throw(ArgumentError("initdiv must be positive"))
    numevals = evals_per_box = integration_rule_nodes(domain)
    Δ = (b-a) / initdiv
    b1 = initdiv == 1 ? b : a+Δ
    I, E, kdiv = rule(a, b1)
    iszero(prod(Δ)) && return I, E
    firstbox = HCubature.Box(a, b1, I, E, kdiv)
    boxes =
        buffer === nothing ? HCubature.DataStructures.BinaryMaxHeap{typeof(firstbox)}() :
        (empty!(buffer.valtree); buffer)
    push!(boxes, firstbox)
    ma = Base.copymutable(a)
    mb = Base.copymutable(b)
    if initdiv > 1
        skip = true
        @inbounds for c in CartesianIndices(ntuple(i -> Base.OneTo(initdiv), Val{D}()))
            if skip
                skip = false
                continue
            end
            for i in 1:D
                ma[i] = a[i]+(c[i]-1)*Δ[i]
                mb[i] = c[i] == initdiv ? b[i] : a[i]+c[i]*Δ[i]
            end
            x = HCubature.SVector(ma)
            y = HCubature.SVector(mb)
            box = HCubature.Box(x, y, rule(x, y)...)
            I += box.I
            E += box.E
            numevals += evals_per_box
            push!(boxes, box)
        end
    end
    (E ≤ max(rtol*norm(I), atol) || numevals ≥ maxevals) && return I, E
    @inbounds while true
        box = pop!(boxes)
        w = (box.b[box.kdiv] - box.a[box.kdiv]) * Float64(0.5)
        ma[:] = box.a
        ma[box.kdiv] += w
        a′ = HCubature.SVector(ma)
        mb[:] = box.b
        mb[box.kdiv] -= w
        b′ = HCubature.SVector(mb)
        box1 = HCubature.Box(a′, box.b, rule(a′, box.b)...)
        box2 = HCubature.Box(box.a, b′, rule(box.a, b′)...)
        push!(boxes, box1)
        push!(boxes, box2)
        I += box1.I + box2.I - box.I
        E += box1.E + box2.E - box.E
        numevals += 2*evals_per_box
        Inorm = norm(I)
        (E ≤ max(rtol*Inorm, atol) || numevals ≥ maxevals || !isfinite(Inorm)) && break
    end
    I = zero(I)
    E = zero(E)
    for i in 1:length(boxes.valtree)
        I += boxes.valtree[i].I
        E += boxes.valtree[i].E
    end
    return I, E
end

"""Batch only the nodes of one unchanged HCubature numerical rule.

The dependency rule first enumerates its value-independent nodes using dummy
scalars. Actual values are then evaluated concurrently and replayed in exactly
the dependency's original node and arithmetic order. Enumeration never invokes
the physical evaluator or consumes its evaluation budget.
"""
function _response_cubature_count(
    batch_evaluator,
    own_value,
    domain::IntegrationDomain{D},
    algorithm;
    norm = _integration_norm,
    buffer = nothing,
) where {D}
    numerical_rule = HCubature.cubrule(Val{D}(), Float64)
    count = Ref(0)
    function box_rule(lower, upper)
        nodes = HCubature.SVector{D, Float64}[]
        numerical_rule(lower, upper, norm) do node
            push!(nodes, node)
            0.0
        end
        length(nodes) == integration_rule_nodes(domain) || error("cubature node inventory changed")
        values = batch_evaluator(nodes)
        length(values) == length(nodes) || error("incomplete cubature node batch")
        ordinal = Ref(0)
        result = numerical_rule(lower, upper, norm) do node
            ordinal[] += 1
            node == nodes[ordinal[]] || error("cubature rule replay changed node order")
            count[] += 1
            own_value(values[ordinal[]])
        end
        ordinal[] == length(nodes) || error("incomplete cubature rule replay")
        return result
    end
    value, estimate = _response_cubature_tree(box_rule, domain, algorithm; norm, buffer)
    return value, estimate, count[]
end
