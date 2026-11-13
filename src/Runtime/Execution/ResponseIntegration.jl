import HCubature

"""Select coordinates independently of response kernels and algorithm controls."""
function response_integration_domain(cfg)
    cfg.integration_affine_region === nothing || throw(
        ArgumentError(
            "affine KRegion uses its uniform parameter grid, not a Cartesian box cubature domain",
        ),
    )
    cfg.integration_bounds===nothing && return IntegrationDomain{length(cfg.k_mesh)}()
    lo, hi=cfg.integration_bounds
    dimension=integration_dimension(cfg)
    return IntegrationDomain(
        lower = lo[1:dimension],
        upper = hi[1:dimension],
        coordinates = :cartesian,
    )
end

"""Convert a declared domain node to the common three-axis fractional k evaluator."""
function response_integration_kpoint!(point, node, domain, model)
    coordinates=zeros(3)
    coordinates[1:length(domain.lower)] .= node
    point .=
        domain.coordinates==:fractional ? coordinates :
        reciprocal_cartesian_to_fractional(coordinates, model.lattice)
    return point
end

"""Persist the estimate and termination without claiming a rigorous bound or qualification."""
function write_response_integration_diagnostics(directory, result, algorithm, cfg)
    records=(
        integration_algorithm_summary(algorithm),
        integration_domain_metadata(cfg),
        (;
            embedded_estimate = result.embedded_estimate,
            evaluations = result.evaluations,
            termination = result.termination,
            estimate_converged = result.estimate_converged,
            normalization = result.normalization,
            domain_measure = result.domain_measure,
            norm_prescription = result.norm_prescription,
            numerical_estimate_is_strict_bound = false,
            requested_fourier_backend = cfg.fourier_backend,
            effective_fourier_backend = "direct",
            fourier_reason = "arbitrary adaptive nodes; no regular-grid FFT provider",
            execution_parallelism = bundle_mpi_comm_size(bundle_mpi_comm_world())==1 ?
                                    "serial adaptive tree; one existing scheduler lane, rank count=1" :
                                    "root-owned global adaptive tree; concurrent rule nodes with canonical replay, rank count=$(bundle_mpi_comm_size(bundle_mpi_comm_world()))",
            symmetry_strategy = "full supplied domain; no symmetry node reduction",
        ),
    )
    return write_integration_diagnostics(directory, records)
end

"""Maximum absolute complex entry for a scalar or multidimensional numeric tensor."""
_integration_norm(value::Number)=abs(value)
"""Use one explicitly declared coupled tensor norm, preserving all frequency entries."""
_integration_norm(value::AbstractArray)=maximum(abs, value)

"""Reject nonfinite/shape-changing evaluators and own any mutable returned tensor."""
function _owned_integration_value(evaluator, node, shape)
    value=evaluator(node)
    value isa Number ||
        value isa AbstractArray{<:Number} ||
        throw(ArgumentError("numeric scalar/tensor integrand required"))
    finite=value isa Number ? isfinite(value) : !isempty(value) && all(isfinite, value)
    finite || throw(ArgumentError("nonfinite or empty integration value"))
    signature=value isa Number ? (:scalar,) : (:tensor, size(value))
    shape[]===nothing ? (shape[]=signature) :
    shape[]==signature || throw(DimensionMismatch("integrand shape changed"))
    return value isa Number ? value : copy(value)
end

"""Resolve integral versus domain average once; node weights never imply symmetry multiplicity."""
function _integration_normalization(domain, normalization)
    length(domain.lower) in 1:3 ||
        throw(ArgumentError("integration dimension must be one, two or three"))
    normalization in (:integral, :domain_average) ||
        throw(ArgumentError("unknown integration normalization"))
    all(isfinite, (domain.lower..., domain.upper...)) && all(domain.lower .< domain.upper) ||
        throw(ArgumentError("finite ordered integration domain required"))
    measure=integration_domain_measure(domain)
    isfinite(measure) && measure>0 ||
        throw(ArgumentError("integration measure must be positive and representable"))
    scale=normalization==:domain_average ? inv(measure) : 1.0
    isfinite(scale) && scale>0 ||
        throw(ArgumentError("integration normalization must be representable in Float64"))
    return measure, scale
end

"""
Integrate a complex tensor using the mature h-adaptive backend and an explicit coordinate measure.

Budget exhaustion retains the estimate/value and emits a numerical warning.
Nonfinite or malformed evaluators remain errors. The backend allocates only
its finite-budget region estimates; evaluators need not retain arbitrary nodes.
Symmetry reduction is not implemented for this first backend.
"""
function integrate_response(
    evaluator,
    domain::IntegrationDomain,
    algorithm::HAdaptiveCubature;
    normalization = :domain_average,
    symmetry_action::AbstractIntegrationSymmetryAction = NoIntegrationSymmetry(),
    quadrature_buffer = nothing,
    batch_evaluator = nothing,
)
    symmetry_action isa NoIntegrationSymmetry ||
        throw(ArgumentError("adaptive symmetry action is not implemented"))
    validate_integration_budget(domain, algorithm)
    measure, scale=_integration_normalization(domain, normalization);
    shape=Ref{Any}(nothing)
    owned=node->scale*_owned_integration_value(evaluator, node, shape)
    value, estimate, count = if batch_evaluator === nothing
        HCubature.hcubature_count(
            owned,
            domain.lower,
            domain.upper;
            norm = _integration_norm,
            atol = algorithm.atol,
            rtol = algorithm.rtol,
            maxevals = algorithm.max_evaluations,
            initdiv = algorithm.initial_divisions,
            buffer = quadrature_buffer,
        )
    else
        own_value = value -> scale * _owned_integration_value(identity, value, shape)
        _response_cubature_count(
            batch_evaluator,
            own_value,
            domain,
            algorithm;
            norm = _integration_norm,
            buffer = quadrature_buffer,
        )
    end
    isfinite(estimate) && isfinite(_integration_norm(value)) ||
        throw(ArgumentError("nonfinite cubature result"))
    converged=estimate<=max(algorithm.atol, algorithm.rtol*_integration_norm(value))
    termination=converged ? :estimated_tolerance : :evaluation_budget
    converged ||
        @warn "Adaptive integral stopped before its embedded estimate met the requested tolerance; result retained" embedded_estimate=estimate evaluations=count max_evaluations=algorithm.max_evaluations
    return ResponseIntegralResult(
        value,
        Float64(estimate),
        count,
        termination,
        converged,
        measure,
        normalization,
        :maximum_absolute_complex_entry,
        algorithm.max_evaluations,
    )
end

"""Deterministic uniform quadrature for the explicit finite domain/evaluator interface."""
function integrate_response(
    evaluator,
    domain::IntegrationDomain,
    algorithm::UniformIntegration;
    normalization = :domain_average,
    k_mesh = ntuple(_->16, length(domain.lower)),
    symmetry_action::AbstractIntegrationSymmetryAction = NoIntegrationSymmetry(),
)
    symmetry_action isa NoIntegrationSymmetry ||
        throw(ArgumentError("generic uniform symmetry action is not implemented"))
    dimension=length(domain.lower)
    length(k_mesh)==dimension && all(x->x isa Integer && x>0, k_mesh) ||
        throw(ArgumentError("positive midpoint counts matching domain dimension required"))
    measure, scale=_integration_normalization(domain, normalization);
    shape=Ref{Any}(nothing);
    total=nothing
    for index in CartesianIndices(Tuple(k_mesh))
        node=ntuple(
            a->algorithm.region_quadrature == :left_endpoint ?
               domain.lower[a]+((index[a]-1)/k_mesh[a])*(domain.upper[a]-domain.lower[a]) :
               domain.lower[a]+(index[a]-0.5)*(domain.upper[a]-domain.lower[a])/k_mesh[a],
            dimension,
        )
        value=_owned_integration_value(evaluator, node, shape)
        total=total===nothing ? value : total+value
    end
    value=total*(measure*scale/prod(k_mesh))
    isfinite(_integration_norm(value)) ||
        throw(ArgumentError("nonfinite uniform integration result"))
    return ResponseIntegralResult(
        value,
        nothing,
        prod(k_mesh),
        :fixed_rule,
        nothing,
        measure,
        normalization,
        :not_estimated,
        nothing,
    )
end

"""
Run the unchanged global adaptive tree on rank zero with deterministic node owners.

The mature backend alone owns weights, summation order, error estimate and budget.
Nodes of each complete numerical rule may execute concurrently. Stable global
node IDs retain round-robin ownership and rule values are replayed in the original
arithmetic order. All ranks receive the final result or
an evaluator failure before returning; no per-rank tolerance/budget is introduced.
The one-rank route invokes the original serial implementation directly.
"""
function integrate_response_mpi(
    evaluator,
    domain::IntegrationDomain,
    algorithm::HAdaptiveCubature;
    normalization = :domain_average,
    symmetry_action::AbstractIntegrationSymmetryAction = NoIntegrationSymmetry(),
    quadrature_buffer = nothing,
    comm = bundle_mpi_comm_world(),
    pending_memory_limit_bytes = 1024^3,
)
    ranks=bundle_mpi_comm_size(comm)
    ranks==1 && return integrate_response(
        evaluator,
        domain,
        algorithm;
        normalization,
        symmetry_action,
        quadrature_buffer,
    )
    rank=bundle_mpi_comm_rank(comm)
    # Collective preflight prevents a local invalid request from stranding peers.
    local_contract=try
        Threads.nthreads()==1 ||
            throw(ArgumentError("adaptive MPI currently requires one Julia thread per rank"))
        symmetry_action isa NoIntegrationSymmetry ||
            throw(ArgumentError("adaptive symmetry action is not implemented"))
        Base.pkgversion(HCubature) == v"1.8.0" || throw(
            ArgumentError(
                "concurrent adaptive MPI requires the qualified HCubature 1.8.0 controller",
            ),
        )
        pending_memory_limit_bytes isa Integer && pending_memory_limit_bytes > 0 ||
            throw(ArgumentError("positive adaptive pending-memory limit required"))
        validate_integration_budget(domain, algorithm)
        _integration_normalization(domain, normalization)
        (
            ok = true,
            value = (
                domain.lower,
                domain.upper,
                domain.coordinates,
                algorithm.atol,
                algorithm.rtol,
                algorithm.max_evaluations,
                algorithm.initial_divisions,
                normalization,
                pending_memory_limit_bytes,
            ),
            error = "",
        )
    catch exception
        (ok = false, value = nothing, error = sprint(showerror, exception))
    end
    contracts=[
        bundle_mpi_bcast(rank==owner ? local_contract : nothing, owner, comm) for
        owner in 0:(ranks - 1)
    ]
    all(packet->packet.ok, contracts) || throw(
        ArgumentError(
            "adaptive MPI collective preflight failed: "*join(
                [packet.error for packet in contracts if !packet.ok],
                "; ",
            ),
        ),
    )
    all(packet->packet.value==contracts[1].value, contracts) ||
        throw(ArgumentError("adaptive MPI ranks supplied different global contracts"))
    shape=Ref{Any}(nothing)
    function evaluate_packet(command)
        values = Any[]
        failure = ""
        for ordinal in eachindex(command.nodes)
            owner = mod(command.first_sequence + ordinal - 2, ranks)
            owner == rank || continue
            try
                value = _owned_integration_value(evaluator, command.nodes[ordinal], shape)
                push!(values, (ordinal = ordinal, value = value))
            catch exception
                failure = sprint(showerror, exception)
                break
            end
        end
        packet = (ok = isempty(failure), rank = rank, values = values, error = failure)
        return bundle_mpi_gather(packet, 0, comm)
    end
    if rank==0
        sequence=Ref(0)
        value_bytes=Ref(0)
        function distributed_batch(nodes)
            cached_values = Any[]
            cached_first = 1
            next_ordinal = 1
            function read_value!(ordinal)
                ordinal == next_ordinal || error("adaptive rule values must be read in order")
                if ordinal >= cached_first + length(cached_values)
                    # Drop the preceding packet before fetching the next. The
                    # original rule retains its own arithmetic intermediates;
                    # this transport retains only one bounded packet, not the
                    # full rule's tensor values.
                    empty!(cached_values)
                    cached_first = ordinal
                    capacity =
                        value_bytes[] == 0 ? 1 :
                        WorkspacePlanning.batch_capacity(
                            length(nodes),
                            value_bytes[],
                            0,
                            pending_memory_limit_bytes,
                        )
                    capacity > 0 ||
                        throw(ArgumentError("adaptive node result exceeds pending-memory limit"))
                    last = min(length(nodes), ordinal + capacity - 1)
                    command = (
                        operation = :evaluate_batch,
                        nodes = nodes[ordinal:last],
                        first_sequence = sequence[] + 1,
                    )
                    bundle_mpi_bcast(command, 0, comm)
                    packets = evaluate_packet(command)
                    failures = [packet for packet in packets if !packet.ok]
                    isempty(failures) || error(
                        "adaptive MPI evaluator failed: " * join(
                            ["rank $(packet.rank): $(packet.error)" for packet in failures],
                            "; ",
                        ),
                    )
                    resize!(cached_values, last - ordinal + 1)
                    seen = falses(length(cached_values))
                    for packet in packets, entry in packet.values
                        1 <= entry.ordinal <= length(seen) && !seen[entry.ordinal] ||
                            error("adaptive node ownership mismatch")
                        cached_values[entry.ordinal] = entry.value
                        seen[entry.ordinal] = true
                    end
                    all(seen) || error("incomplete adaptive node values")
                    sequence[] += length(cached_values)
                    if value_bytes[] == 0
                        # Estimate retained values and serialized send/receive
                        # scratch. The external RSS guard also covers model,
                        # workspace, dependency and tree allocations.
                        value_bytes[] = Base.checked_mul(4, Base.summarysize(first(cached_values)))
                    end
                end
                next_ordinal += 1
                return cached_values[ordinal - cached_first + 1]
            end
            return ResponseRuleValues(length(nodes), read_value!)
        end
        terminal=try
            result=integrate_response(
                evaluator,
                domain,
                algorithm;
                normalization,
                symmetry_action,
                quadrature_buffer,
                batch_evaluator = distributed_batch,
            )
            (operation = :finish, ok = true, value = result, error = "")
        catch exception
            (operation = :finish, ok = false, value = nothing, error = sprint(showerror, exception))
        end
        bundle_mpi_bcast(terminal, 0, comm)
    else
        terminal=nothing
        while true
            command=bundle_mpi_bcast(nothing, 0, comm)
            if command.operation==:finish
                terminal=command
                break
            end
            command.operation==:evaluate_batch || error("invalid adaptive MPI operation")
            evaluate_packet(command)
        end
    end
    terminal.ok || error(terminal.error)
    return terminal.value
end
