# Store magnetic-moment source configuration.
Base.@kwdef struct MagneticMomentConfig
    # Select and parameterize one explicit magnetic-moment provider.
    source::Symbol
    file::Union{Nothing, String} = nothing
    moments_cartesian::Union{Nothing, Matrix{Float64}} = nothing
    collinear_axis_cartesian::Union{Nothing, NTuple{3, Float64}} = nothing
    mapping_tolerance::Float64 = 1.0e-7
end

@doc """
    MagneticMomentConfig(; source, file=nothing, moments_cartesian=nothing, ...)

Describe a `:qe`, `:vasp`, or direct `:cartesian` magnetic-moment source. Axes
and moments are Cartesian and direct moments follow WIN atom order.
""" MagneticMomentConfig

# Store WIN-authoritative mesh-screening configuration.
Base.@kwdef struct MeshScreenConfig
    # Supply the WIN path and deterministic mesh-search policy.
    win_file::String
    include_time_reversal::Bool = true
    symmetry_tolerance::Float64 = 1.0e-5
    operation_indices::Union{Nothing, Vector{Int}} = nothing
    dimension::Int = 3
    density_target::Float64 = 55.0
    search_radius::Int = 10
end

@doc """
    MeshScreenConfig(; win_file, ...)

Configure deterministic symmetry screening of the WIN-authoritative `mp_grid`.
`dimension` is `2` or `3`; the two-dimensional route retains the WIN third
mesh entry.
""" MeshScreenConfig

"""
    SymmetrizationConfig(; win_file, tb_file, output_tb_file,
                         output_real_space_operator_bundle_file, ...)

Configure deterministic group projection of the complete operator family implied
by the explicitly supplied auxiliary input fields. WIN and TB are mandatory;
CHK/SPN selects spin, CHK/EIG/MMN selects derivatives, and providing all four
selects the full inventory. Incomplete auxiliary combinations are rejected.
Wannier-center and real-space replica policies are model-generation contracts;
they are stored in Packed HDF5 and are not runtime response switches.
"""
Base.@kwdef struct SymmetrizationConfig
    # Store mandatory input and paired model-package output paths.
    win_file::String
    tb_file::String
    output_tb_file::String
    output_real_space_operator_bundle_file::String

    chk_file::Union{Nothing, String} = nothing
    eig_file::Union{Nothing, String} = nothing
    mmn_file::Union{Nothing, String} = nothing
    spn_file::Union{Nothing, String} = nothing

    report_json_file::Union{Nothing, String} = nothing

    include_time_reversal::Bool = true
    symmetry_tolerance::Float64 = 1.0e-5
    projection_tolerance::Float64 = 1.0e-7
    representation_tolerance::Float64 = 1.0e-7
    operation_indices::Union{Nothing, Vector{Int}} = nothing
    magnetic::Union{Nothing, MagneticMomentConfig} = nothing

    support_tolerance::Float64 = 1.0e-12
    wigner_seitz_tolerance::Float64 = 1.0e-5
    wigner_seitz_search_size::Int = 3

    wannier_center_policy::Symbol = :symmetrize
    wannier_center_tolerance::Float64 = 1.0e-8
    real_space_replica_policy::Symbol = :minimum_distance

    check_roundtrip::Bool = true
    roundtrip_tolerance::Float64 = 1.0e-8

    cutoff::Union{Nothing, Float64} = nothing
    covariance_tolerance::Float64 = 1.0e-8
    idempotence_tolerance::Float64 = 1.0e-9
    check_idempotence::Bool = true
    overwrite::Bool = false
end

"""Durable outputs and validation evidence from one complete symmetrization run."""
struct SymmetrizationResult
    output_tb::String
    real_space_operator_bundle::String
    report_json::String
    operator_profile::Symbol
    operator_inventory::Vector{RealSpaceOperatorKind}
    validation::Dict{RealSpaceOperatorKind, OperatorValidationSummary}
end
