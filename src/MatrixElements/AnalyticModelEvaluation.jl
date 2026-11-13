"""Validate the Cartesian evaluation domain without periodic folding."""
function validate_analytic_kpoint(input::AnalyticKInput, k)
    length(k)==3 && all(isfinite, k) ||
        throw(ArgumentError("k must be a finite Cartesian 3-vector"))
    bounds=input.evaluation_bounds
    bounds === nothing ||
        all(bounds[1][i] <= k[i] <= bounds[2][i] for i in 1:input.physical_dimension) ||
        throw(DomainError(collect(k), "analytic evaluation outside declared bounds"))
    return k
end

"""Evaluate H in the declared fixed basis and reject invalid matrices before diagonalization."""
function analytic_hamiltonian(input::AnalyticKInput, k)
    validate_analytic_kpoint(input, k)
    h=input.hamiltonian(k, input.parameters)
    size(h)==(input.num_orbitals, input.num_orbitals) ||
        throw(DimensionMismatch("analytic H shape"))
    all(isfinite, h) || throw(ArgumentError("analytic H contains nonfinite values"))
    isapprox(h, h'; atol = 1e-11, rtol = 0) || throw(ArgumentError("analytic H is not Hermitian"))
    return h
end

"""Differentiate real and imaginary matrix components, retaining all Cartesian derivative axes."""
function analytic_automatic_derivative(callback, k, order)
    order==0 && return callback(k)
    sample=callback(k);
    shape=size(sample);
    count=length(sample)
    split(x)=vcat(vec(real.(callback(x))), vec(imag.(callback(x))))
    function jet(x, n)
        n==0 && return split(x)
        return ForwardDiff.jacobian(y -> vec(jet(y, n-1)), x)
    end
    raw=reshape(jet(collect(k), order), (2count, ntuple(_->3, order)...))
    return reshape(
        complex.(selectdim(raw, 1, 1:count), selectdim(raw, 1, (count + 1):(2count))),
        (shape..., ntuple(_->3, order)...),
    )
end

"""Central finite differences with recursively ordered Cartesian axes and domain checks."""
function analytic_central_derivative(callback, k, order, step)
    order==0 && return callback(k)
    parts=map(1:3) do a
        delta=zeros(3);
        delta[a]=step
        (
            analytic_central_derivative(callback, k .+ delta, order-1, step) .-
            analytic_central_derivative(callback, k .- delta, order-1, step)
        ) ./ (2step)
    end
    return cat(parts...; dims = ndims(first(parts))+1)
end

"""
Evaluate a Hamiltonian derivative of order 0:3 in Cartesian coordinates.

Supplied derivatives take precedence. Automatic differentiation never falls back
silently. Explicit finite differences must pass the h,h/2,h/4 consistency check.
"""
function analytic_hamiltonian_derivative(
    input::AnalyticKInput,
    k,
    order::Integer;
    diagnostics = nothing,
)
    order in 0:3 || throw(ArgumentError("Hamiltonian derivative order must be 0:3"))
    order==0 && return analytic_hamiltonian(input, k)
    validate_analytic_kpoint(input, k)
    supplied=input.derivatives[order]
    source=supplied !== nothing ? "EXPLICIT" :
           input.derivative_method == :automatic ? "FORWARDDIFF" : "FINITE_DIFFERENCE"
    value = if supplied !== nothing
        supplied(k, input.parameters)
    elseif input.derivative_method == :automatic
        analytic_automatic_derivative(x->analytic_hamiltonian(input, x), k, order)
    elseif input.derivative_method == :finite_difference
        callback=x->analytic_hamiltonian(input, x)
        coarse=analytic_central_derivative(callback, k, order, input.finite_difference_step)
        medium=analytic_central_derivative(callback, k, order, input.finite_difference_step/2)
        fine=analytic_central_derivative(callback, k, order, input.finite_difference_step/4)
        e1=maximum(abs, coarse .- medium);
        e2=maximum(abs, medium .- fine)
        tolerance=1e-8+1e-5*maximum(abs, fine)
        passed=e2 <= tolerance && (e2 <= 0.6e1 || e1 <= tolerance)
        record_analytic_derivative!(
            diagnostics,
            order,
            source,
            k,
            (e1, e2),
            input.finite_difference_step,
            passed,
        )
        passed || throw(ArgumentError("finite difference has not converged: errors=($e1,$e2)"))
        fine
    else
        throw(ArgumentError("missing explicit derivative of order $order"))
    end
    size(value)==(input.num_orbitals, input.num_orbitals, ntuple(_->3, order)...) ||
        throw(DimensionMismatch("analytic derivative shape"))
    all(isfinite, value) || throw(ArgumentError("analytic derivative is nonfinite"))
    for index in CartesianIndices(ntuple(_->3, order))
        a=view(value,:,:,(Tuple(index)...))
        isapprox(a, a'; atol = 1e-10, rtol = 1e-10) ||
            throw(ArgumentError("non-Hermitian analytic derivative"))
    end
    source == "FINITE_DIFFERENCE" ||
        record_analytic_derivative!(diagnostics, order, source, k, (0.0, 0.0), 0.0, true)
    return value
end

"""Stable validation callback; the original input and Hamiltonian evaluation are preserved."""
struct AnalyticValidationCallback
    input::AnalyticKInput
end
"""Evaluate the validation Hamiltonian using the original analytic input."""
(callback::AnalyticValidationCallback)(k) = analytic_hamiltonian(callback.input, k)

"""Check periodicity and supplied derivative consistency at a deterministic interior point."""
Base.@nospecializeinfer function validate_analytic_model(input::AnalyticKInput; max_order = 0)
    @nospecialize input
    k = zeros(3)
    d = input.physical_dimension
    k[1:d] .=
        input.evaluation_bounds === nothing ? [0.17, 0.23, 0.31][1:d] :
        (collect(input.evaluation_bounds[1]) .+ collect(input.evaluation_bounds[2])) ./ 2
    h=analytic_hamiltonian(input, k)
    if input.periodic
        reciprocal=reciprocal_lattice(input.lattice)
        for axis in 1:d
            shifted=analytic_hamiltonian(input, k .+ reciprocal[axis, :])
            isapprox(h, shifted; atol = 1e-10, rtol = 1e-9) || throw(
                ArgumentError("Hamiltonian conflicts with declared Convention-II periodicity"),
            )
        end
    end
    step=input.evaluation_bounds === nothing ? 1e-4 :
         min(
        1e-4,
        minimum(collect(input.evaluation_bounds[2]) .- collect(input.evaluation_bounds[1]))/100,
    )
    for order in 1:max_order
        input.derivatives[order] === nothing && continue
        declared=analytic_hamiltonian_derivative(input, k, order)
        reference=analytic_central_derivative(AnalyticValidationCallback(input), k, order, step)
        isapprox(declared, reference; atol = 1e-6, rtol = 1e-5) ||
            throw(ArgumentError("supplied Hamiltonian derivative order $order is inconsistent"))
    end
    return nothing
end
