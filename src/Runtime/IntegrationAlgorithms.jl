"""Algorithm interface independent of model, response evaluator and integration domain."""
abstract type AbstractIntegrationAlgorithm end

"""
Uniform quadrature with `region_quadrature=:midpoint` by default.

Explicit finite regions also support `:left_endpoint`, with parameter nodes
`i/N`, `i=0:N-1`, on the original domain. This option does not change BZMesh grids.
"""
struct UniformIntegration <: AbstractIntegrationAlgorithm
    region_quadrature::Symbol

    function UniformIntegration(; region_quadrature = :midpoint)
        region_quadrature in (:midpoint, :left_endpoint) ||
            throw(ArgumentError("region_quadrature must be :midpoint or :left_endpoint"))
        return new(region_quadrature)
    end
end

"""
Deterministic one- to three-dimensional h-adaptive cubature via HCubature.jl.

The max-absolute norm couples all complex tensor entries. Tolerances apply to
raw evaluator units after the chosen normalization. `max_evaluations` is a
complete-rule budget: the last two-box refinement may exceed it by at most
29/33/65 nodes in 1D/2D/3D. Initial divisions must fit the domain-specific budget. Embedded estimates are numerical
estimates, never rigorous bounds or a scientific qualification. No automatic
Fermi/resonance probes, peak checks or mandatory repeat grids are performed.
"""
struct HAdaptiveCubature <: AbstractIntegrationAlgorithm
    atol::Float64
    rtol::Float64
    max_evaluations::Int
    initial_divisions::Int
end

"""Validate controls; the domain-specific initial rule is checked before evaluation."""
function HAdaptiveCubature(;
    atol = 1e-8,
    rtol = 1e-5,
    max_evaluations = 100_000,
    initial_divisions = 1,
)
    all(x->x isa Real && isfinite(x) && x>=0, (atol, rtol)) && (atol>0 || rtol>0) || throw(
        ArgumentError("finite nonnegative atol/rtol with at least one positive value required"),
    )
    initial_divisions isa Integer && !(initial_divisions isa Bool) && initial_divisions>0 ||
        throw(ArgumentError("initial_divisions must be positive"))
    max_evaluations isa Integer && !(max_evaluations isa Bool) && max_evaluations>0 ||
        throw(ArgumentError("max_evaluations must be positive"))
    converted=(Float64(atol), Float64(rtol))
    all(x->isfinite(x)&&x>=0, converted) && any(>(0), converted) ||
        throw(ArgumentError("integration tolerances must remain finite and positive in Float64"))
    return HAdaptiveCubature(converted..., Int(max_evaluations), Int(initial_divisions))
end

"""Finite one- to three-dimensional bounds in explicit integration coordinates."""
struct IntegrationDomain{D}
    lower::NTuple{D, Float64}
    upper::NTuple{D, Float64}
    coordinates::Symbol
end

"""Preserve the existing two-dimensional domain constructor and type alias."""
const IntegrationDomain2D = IntegrationDomain{2}

"""Construct finite fractional or inverse-Angstrom Cartesian bounds."""
function IntegrationDomain(; lower = (0.0, 0.0), upper = (1.0, 1.0), coordinates = :fractional)
    length(lower)==length(upper) || throw(DimensionMismatch("matching integration bounds required"))
    return IntegrationDomain{length(lower)}(; lower, upper, coordinates)
end

"""Validate the declared active dimension and representable coordinate measure."""
function IntegrationDomain{D}(;
    lower = ntuple(_->0.0, D),
    upper = ntuple(_->1.0, D),
    coordinates = :fractional,
) where {D}
    D in 1:3 || throw(ArgumentError("integration dimension must be one, two or three"))
    length(lower)==length(upper)==D ||
        throw(DimensionMismatch("bounds must match domain dimension"))
    all(x->x isa Real && isfinite(x), (lower..., upper...)) && all(lower .< upper) ||
        throw(ArgumentError("finite ordered integration bounds required"))
    coordinates in (:fractional, :cartesian) ||
        throw(ArgumentError("unknown integration coordinates"))
    lo=Tuple(Float64.(lower));
    hi=Tuple(Float64.(upper))
    all(isfinite, (lo..., hi...)) && all(lo .< hi) ||
        throw(ArgumentError("integration bounds must remain finite and ordered in Float64"))
    measure=prod(hi .- lo)
    isfinite(measure) && measure>0 ||
        throw(ArgumentError("integration measure must be positive and representable in Float64"))
    return IntegrationDomain{D}(lo, hi, coordinates)
end

"""Coordinate measure independent of lattice volume and response normalization."""
integration_domain_measure(domain::IntegrationDomain)=prod(domain.upper .- domain.lower)

"""HCubature 1.8 complete-rule nodes: 7/15 Gauss–Kronrod in 1D, Genz–Malik in 2D/3D."""
integration_rule_nodes(::IntegrationDomain{D}) where {D} = D==1 ? 15 : 1+4D+2D*(D-1)+2^D

"""Reject a budget smaller than the complete initial partition before calling the evaluator."""
function validate_integration_budget(
    domain::IntegrationDomain{D},
    algorithm::HAdaptiveCubature,
) where {D}
    nodes=big(integration_rule_nodes(domain))*big(algorithm.initial_divisions)^D
    nodes<=algorithm.max_evaluations || throw(
        ArgumentError(
            "cubature budget cannot cover the initial $D-dimensional divisions: at least $nodes nodes required",
        ),
    )
    return nothing
end

"""Future symmetry-action interface; first adaptive backend evaluates the full supplied domain."""
abstract type AbstractIntegrationSymmetryAction end

"""No node reduction or unverified multiplicity-to-area conversion."""
struct NoIntegrationSymmetry <: AbstractIntegrationSymmetryAction end

"""Result and numerical termination, without attaching scientific correctness labels."""
struct ResponseIntegralResult{T}
    value::T
    embedded_estimate::Union{Nothing, Float64}
    evaluations::Int
    termination::Symbol
    estimate_converged::Union{Nothing, Bool}
    domain_measure::Float64
    normalization::Symbol
    norm_prescription::Symbol
    max_evaluations::Union{Nothing, Int}
end

"""Stable user-facing description of the retained uniform algorithm."""
integration_algorithm_summary(a::UniformIntegration) =
    a.region_quadrature == :midpoint ? (algorithm = "uniform",) :
    (algorithm = "uniform", region_quadrature = String(a.region_quadrature))

"""Record algorithm tolerances and budget independently of response physics."""
integration_algorithm_summary(
    a::HAdaptiveCubature,
)=(
    algorithm = "h_adaptive_cubature",
    backend = "HCubature",
    atol = a.atol,
    rtol = a.rtol,
    max_evaluations = a.max_evaluations,
    initial_divisions = a.initial_divisions,
    norm = "maximum_absolute_complex_entry",
)
