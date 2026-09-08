# Private cold-path configuration compiled from the layered public API for one response task.
#
# Energies and broadening use eV, temperature uses K, and Cartesian momentum uses the configured lattice convention. Construction stores settings; `run` validates combinations and reads inputs before computation.
struct EffectiveTaskConfig
    # Original task tuples are retained for validation and run provenance.
    tasks::Vector{<:Tuple}

    k_mesh::Union{NTuple{2, Int}, NTuple{3, Int}}
    fourier_backend::String
    NKdiv::Union{Nothing, NTuple{2, Int}, NTuple{3, Int}}
    NKFFT::Union{Nothing, NTuple{2, Int}, NTuple{3, Int}}
    photon_energies::Vector{Float64}
    fermi_energy::Float64
    temperature::Float64
    broadening::Float64
    broadening_type::String
    transition_window_factor::Float64
    denominator_regularization::Float64
    spatial_dimension::Int
    band_window_size::Int

    tensor_indices::Any
    band_selection::Any
    include_occupied_sum::Bool
    kslice_origin::NTuple{3, Float64}
    kslice_vector_1::NTuple{3, Float64}
    kslice_vector_2::NTuple{3, Float64}

    kpath_nodes::Vector{Tuple{String, NTuple{3, Float64}}}
    kpoints_per_segment::Vector{Int}
    real_space_replica_policy::String
    wsvec_file::Union{Nothing, String}
    mp_grid::Union{Nothing, NTuple{3, Int}}
    wigner_seitz_tolerance::Float64
    wigner_seitz_search_size::Int
    band_hermiticity_tolerance::Float64

    photon_momentum::NTuple{3, Float64}
    finite_difference_step::Float64
    wannier_center_convention::String
    degeneracy_threshold::Float64

    model_file::String
    real_space_operator_bundle_file::Union{Nothing, String}
    seedname::String
    case_root::String
    system_name::Union{Nothing, String}
    output_root::String

    spin_enabled::Bool
    spin_file::String
    checkpoint_file::String
    spin_file_formatted::Bool

    response_symmetry_file::Union{Nothing, String}
    response_symmetry_policy::String
    response_symmetry_kmesh_mode::String
    response_symmetry_report_enabled::Bool

    response_output_digits::Int

    progress_enabled::Bool
    progress_percent_interval::Union{Nothing, Int}
    progress_verbosity::String
end

"""Construct a task configuration and reject the retired basis-correction switch."""
function EffectiveTaskConfig(;
    tasks::Vector{<:Tuple} = [("SC", "Conventional", "Integral")],
    k_mesh = (2, 2),
    fourier_backend::String,
    NKdiv::Union{Nothing, NTuple{2, Int}, NTuple{3, Int}} = nothing,
    NKFFT::Union{Nothing, NTuple{2, Int}, NTuple{3, Int}} = nothing,
    photon_energies::Vector{Float64} = Float64[0.10],
    fermi_energy::Float64 = 0.0,
    temperature::Float64 = 0.0,
    broadening::Float64 = 0.040,
    broadening_type::String = "Gaussian",
    transition_window_factor::Float64 = 5.0,
    denominator_regularization::Float64 = 0.001,
    spatial_dimension::Int = 2,
    band_window_size::Int = -1,
    tensor_indices = (1, 1, 1),
    band_selection = (2, 1),
    include_occupied_sum::Bool = true,
    kslice_origin::NTuple{3, Float64} = (0.0, 0.0, 0.0),
    kslice_vector_1::NTuple{3, Float64} = (1.0, 0.0, 0.0),
    kslice_vector_2::NTuple{3, Float64} = (0.0, 1.0, 0.0),
    kpath_nodes = Tuple{String, NTuple{3, Float64}}[],
    kpoints_per_segment::Vector{Int} = Int[],
    real_space_replica_policy::String = "auto",
    wsvec_file::Union{Nothing, String} = nothing,
    mp_grid::Union{Nothing, NTuple{3, Int}} = nothing,
    wigner_seitz_tolerance::Float64 = 1.0e-5,
    wigner_seitz_search_size::Int = 3,
    band_hermiticity_tolerance::Float64 = 1.0e-10,
    photon_momentum::NTuple{3, Float64} = (0.0, 0.0, 0.0),
    finite_difference_step::Float64 = 0.0001,
    wannier_center_convention::String = "Convention_II",
    degeneracy_threshold::Float64 = 2.0e-3,
    model_file::String = "",
    real_space_operator_bundle_file::Union{Nothing, String} = nothing,
    seedname::String = "",
    case_root::String = "",
    system_name::Union{Nothing, String} = nothing,
    output_root::String = "",
    spin_enabled::Bool = false,
    spin_file::String = "",
    checkpoint_file::String = "",
    spin_file_formatted::Bool = false,
    response_symmetry_file::Union{Nothing, String} = nothing,
    response_symmetry_policy::String = "strict",
    response_symmetry_kmesh_mode::String = "reduced",
    response_symmetry_report_enabled::Bool = false,
    response_output_digits::Int = 7,
    progress_enabled::Bool = true,
    progress_percent_interval::Union{Nothing, Int} = nothing,
    progress_verbosity::String = "normal",
    kwargs...,
)
    k_mesh isa Union{NTuple{2, Int}, NTuple{3, Int}} ||
        error("cannot convert k_mesh=$(repr(k_mesh)) to NTuple{2,Int} or NTuple{3,Int}")
    if haskey(kwargs, :basis_correction_enabled)
        error(
            "basis_correction_enabled has been removed. Select " *
            "wannier_center_convention=\"Convention_I\" or \"Convention_II\"; " *
            "physical position and external terms are always enabled.",
        )
    end
    isempty(kwargs) || error(
        "unsupported keyword argument(s) for EffectiveTaskConfig: $(join(string.(keys(kwargs)), ", ")).",
    )
    return EffectiveTaskConfig(
        tasks,
        k_mesh,
        fourier_backend,
        NKdiv,
        NKFFT,
        photon_energies,
        fermi_energy,
        temperature,
        broadening,
        broadening_type,
        transition_window_factor,
        denominator_regularization,
        spatial_dimension,
        band_window_size,
        tensor_indices,
        band_selection,
        include_occupied_sum,
        kslice_origin,
        kslice_vector_1,
        kslice_vector_2,
        normalize_kpath_input(kpath_nodes),
        kpoints_per_segment,
        real_space_replica_policy,
        wsvec_file,
        mp_grid,
        wigner_seitz_tolerance,
        wigner_seitz_search_size,
        band_hermiticity_tolerance,
        photon_momentum,
        finite_difference_step,
        wannier_center_convention,
        degeneracy_threshold,
        model_file,
        real_space_operator_bundle_file,
        seedname,
        case_root,
        system_name,
        output_root,
        spin_enabled,
        spin_file,
        checkpoint_file,
        spin_file_formatted,
        response_symmetry_file,
        response_symmetry_policy,
        response_symmetry_kmesh_mode,
        response_symmetry_report_enabled,
        response_output_digits,
        progress_enabled,
        progress_percent_interval,
        progress_verbosity,
    )
end

"""Normalize public high-symmetry nodes without folding fractional coordinates."""
function normalize_kpath_input(nodes)
    nodes isa AbstractVector ||
        error("kpath_nodes must be a vector of (label, (k1, k2, k3)) nodes.")
    normalized = Tuple{String, NTuple{3, Float64}}[]
    sizehint!(normalized, length(nodes))
    for (index, node) in enumerate(nodes)
        node isa Tuple && length(node) == 2 ||
            error("kpath_nodes entry $(index) must be (label, (k1, k2, k3)); got $(repr(node)).")
        label, coordinate = node
        label isa AbstractString || error("kpath_nodes entry $(index) label must be a string.")
        coordinate isa Tuple && length(coordinate) == 3 ||
            error("kpath_nodes entry $(index) coordinate must be a three-entry tuple.")
        all(value -> value isa Real, coordinate) ||
            error("kpath_nodes entry $(index) coordinate entries must be real numbers.")
        push!(normalized, (String(label), ntuple(axis -> Float64(coordinate[axis]), 3)))
    end
    return normalized
end

"""
Resolved common seed prefix and TB, SPN, CHK, EIG and MMN file paths for legacy model loading.
"""
struct SeedInputPaths
    seed_prefix::String
    model_file::String
    spin_file::String
    checkpoint_file::String
    eigenvalue_file::String
    overlap_file::String
end

"""
Normalized quantity/method/calculation symbols, registered task key, original request tuple and display label.

Created by configuration validation; the requested tuple is retained for output provenance.
"""
struct NormalizedTaskSpec
    quantity::Symbol
    method::Symbol
    calculation::Symbol
    task::Symbol
    requested::Tuple
    label::String
end

"""Operator identities and Cartesian components required by one task bundle."""
struct OperatorDemandPlan
    required_operators::Vector{RealSpaceOperatorKind}
    required_components::Dict{RealSpaceOperatorKind, Vector{NTuple{2, Int8}}}
    requires_full_projector_geometry::Bool
end

"""
Validated task bundle, resolved input/output paths, model SHA-256, orbital count and operator-demand contract.

Optional packed-bundle and seed inputs identify the selected loading mode; creating the context may create a run directory.
"""
struct RunContext
    specs::Vector{NormalizedTaskSpec}
    run_dir::String
    model_file::String
    model_sha256::String
    model_input_mode::Symbol
    real_space_operator_bundle_file::Union{Nothing, String}
    paired_tb_validation_file::Union{Nothing, String}
    num_orbitals::Int
    operator_demand::OperatorDemandPlan
    system_name::String
    metadata_path::String
    progress_out_path::String
    progress_jsonl_path::String
    seed_inputs::Union{Nothing, SeedInputPaths}
end

"""
Completed task specifications and paths to numerical outputs, metadata and progress files.

Returned by `run`; numerical arrays reside in the output artifacts and the object does not itself certify physics qualification.
"""
struct RunResult
    tasks::Vector{<:Tuple}
    specs::Vector{NormalizedTaskSpec}
    run_dir::String
    outputs::Vector{String}
    metadata_path::String
    progress_out_path::String
    progress_jsonl_path::String
    task_ids::Vector{String}
    task_results::Vector{RunResult}
    sharing::NamedTuple
end

# Preserve the private single-bundle result constructor; the public run supplies instance metadata.
RunResult(tasks, specs, run_dir, outputs, metadata_path, progress_out_path, progress_jsonl_path) =
    RunResult(
        tasks,
        specs,
        run_dir,
        outputs,
        metadata_path,
        progress_out_path,
        progress_jsonl_path,
        String[],
        RunResult[],
        NamedTuple(),
    )

# Lowercase and trim a selector, collapse whitespace/hyphens and repeated underscores, then strip outer underscores.
function _canonical_key(value::AbstractString)
    key = lowercase(strip(value))
    key = replace(key, r"[\s\-]+" => "_")
    key = replace(key, r"_+" => "_")
    return strip(key, '_')
end

"""Normalize the public Wannier-center convention selector once on the cold path."""
function normalize_wannier_center_convention(value::AbstractString)
    key = _canonical_key(value)
    key in ("convention_i", "convention_1", "i", "1") && return CONVENTION_I
    key in ("convention_ii", "convention_2", "ii", "2") && return CONVENTION_II
    error(
        "Unsupported wannier_center_convention=$(repr(value)). " *
        "Use \"Convention_I\" or \"Convention_II\".",
    )
end

const LEGACY_KSLICE_SHORT_LABEL_REPLACEMENTS = (
    "qhc" => "QHCK",
    "hct" => "HCTK",
    "bcd" => "BCDK",
    "bcq" => "BCQK",
    "qm" => "QMK",
    "ibc" => "IBCK",
    "iqm" => "IQMK",
    "zibc" => "ZIBCK",
    "ziqm" => "ZIQMK",
    "qmd" => "QMDK",
    "qmq" => "QMQK",
    "qcs" => "QCSK",
    "tpp" => "TPPK",
)

# Find the current replacement for a former K-slice short label.
function legacy_kslice_short_label_replacement(value::AbstractString)
    key = replace(_canonical_key(value), "_" => "")
    for (legacy, replacement) in LEGACY_KSLICE_SHORT_LABEL_REPLACEMENTS
        key == legacy && return replacement
    end
    return nothing
end

"""
Resolve accepted quantity labels and aliases to their canonical symbols; reject unknown observable names.
"""
function normalize_quantity(value::AbstractString)
    key = _canonical_key(value)
    if key in ("shift_current", "shiftcurrent")
        return :shift_current
    elseif key in ("quantum_hermitian_connection", "quantumhermitianconnection")
        return :quantum_hermitian_connection
    elseif key in ("hermitian_curvature_tensor", "hermitiancurvaturetensor")
        return :hermitian_curvature_tensor
    elseif key == "photon_drag_shift_current"
        return :photon_drag_shift_current
    elseif key in ("shift_vector", "shiftvector")
        return :shift_vector
    elseif key == "injection_current"
        return :injection_current
    elseif key == "injection_spin_current"
        return :injection_spin_current
    elseif key in ("shift_spin_current", "shiftspincurrent")
        return :shift_spin_current
    elseif key == "photon_drag_injection_current"
        return :photon_drag_injection_current
    elseif key in ("berry_curvature", "berrycurvature")
        return :berry_curvature
    elseif key in ("berry_curvature_dipole", "berrycurvaturedipole")
        return :berry_curvature_dipole
    elseif key in ("berry_curvature_quadrupole", "berrycurvaturequadrupole")
        return :berry_curvature_quadrupole
    elseif key in ("quantum_metric", "quantummetric")
        return :quantum_metric
    elseif key in ("interband_berry_curvature", "interbandberrycurvature")
        return :interband_berry_curvature
    elseif key in ("interband_quantum_metric", "interbandquantummetric")
        return :interband_quantum_metric
    elseif key in ("zeeman_interband_berry_curvature", "zeemaninterbandberrycurvature")
        return :zeeman_interband_berry_curvature
    elseif key in ("zeeman_interband_quantum_metric", "zeemaninterbandquantummetric")
        return :zeeman_interband_quantum_metric
    elseif key in ("quantum_metric_dipole", "quantummetricdipole")
        return :quantum_metric_dipole
    elseif key in ("quantum_metric_quadrupole", "quantummetricquadrupole")
        return :quantum_metric_quadrupole
    elseif key in ("quantum_christoffel_symbol", "quantumchristoffelsymbol")
        return :quantum_christoffel_symbol
    elseif key in ("triple_phase_product", "triplephaseproduct")
        return :triple_phase_product
    elseif key in ("band", "bands", "band_structure", "bandstructure")
        return :band_structure
    end
    definition = quantity_short_label_definition(value)
    definition === nothing || return quantity_symbol(definition.quantity)

    replacement = legacy_kslice_short_label_replacement(value)
    replacement === nothing ||
        error("Unsupported K-slice quantity short label=\"$(value)\". Use \"$(replacement)\".")
    error(
        "Unsupported quantity=\"$(value)\". Use a canonical quantity name or one of the registered short labels: $(join((definition.label for definition in QUANTITY_SHORT_LABELS), ", ")).",
    )
end

"""
Resolve conventional, Projector, geometric-loop and Wilson-loop aliases to canonical method symbols; reject unsupported labels.
"""
function normalize_method(value::AbstractString)
    key = _canonical_key(value)
    if key == "conventional"
        return :conventional
    elseif key == "projector"
        return :projector
    elseif key in ("geometric_loop", "geometricloop")
        return :geometric_loop
    elseif key in ("wilson_loop", "wilsonloop", "wilson")
        return :wilson_loop
    end
    error(
        "Unsupported method=\"$(value)\". Use \"Conventional\", \"Projector\", \"Geometric_Loop\", or \"Wilson_Loop\".",
    )
end

"""
Resolve integral, k-slice and k-path names to canonical calculation symbols; reject retired Band calculation labels.
"""
function normalize_calculation(value::AbstractString)
    key = _canonical_key(value)
    if key in ("integral", "integration")
        return :integral
    elseif key in ("k_slice", "kslice", "kspace_slice", "k_space_slice")
        return :kslice
    elseif key in ("k_path", "kpath")
        return :kpath
    end
    error("Unsupported calculation=\"$(value)\". Use \"Integral\", \"K-slice\", or \"K-path\".")
end

"""
Join the canonical display names in `quantity/calculation/method` order into the task's human-readable label.
"""
function task_label(quantity::Symbol, method::Symbol, calculation::Symbol)
    return "$(canonical_quantity_name(quantity))/$(canonical_calculation_name(calculation))/$(canonical_method_name(method))"
end

"""
Return the public display name for a normalized quantity symbol, rejecting unsupported quantities.
"""
function canonical_quantity_name(q::Symbol)
    if q == :shift_current
        return "shift_current"
    elseif q == :quantum_hermitian_connection
        return "quantum_hermitian_connection"
    elseif q == :hermitian_curvature_tensor
        return "hermitian_curvature_tensor"
    elseif q == :photon_drag_shift_current
        return "photon_drag_shift_current"
    elseif q == :shift_vector
        return "shift_vector"
    elseif q == :injection_current
        return "injection_current"
    elseif q == :injection_spin_current
        return "injection_spin_current"
    elseif q == :shift_spin_current
        return "shift_spin_current"
    elseif q == :photon_drag_injection_current
        return "photon_drag_injection_current"
    elseif q == :berry_curvature
        return "berry_curvature"
    elseif q == :berry_curvature_dipole
        return "berry_curvature_dipole"
    elseif q == :berry_curvature_quadrupole
        return "berry_curvature_quadrupole"
    elseif q == :quantum_metric
        return "quantum_metric"
    elseif q == :interband_berry_curvature
        return "interband_berry_curvature"
    elseif q == :interband_quantum_metric
        return "interband_quantum_metric"
    elseif q == :zeeman_interband_berry_curvature
        return "zeeman_interband_berry_curvature"
    elseif q == :zeeman_interband_quantum_metric
        return "zeeman_interband_quantum_metric"
    elseif q == :quantum_metric_dipole
        return "quantum_metric_dipole"
    elseif q == :quantum_metric_quadrupole
        return "quantum_metric_quadrupole"
    elseif q == :quantum_christoffel_symbol
        return "quantum_christoffel_symbol"
    elseif q == :triple_phase_product
        return "triple_phase_product"
    elseif q == :band_structure
        return "band_structure"
    end
    error("No canonical quantity name for quantity=$(q).")
end
"""
Convert a normalized method symbol to its string form; this helper does not validate the method.
"""
canonical_method_name(m::Symbol) = string(m)
"""
Format `:kslice` as `k_slice` and other calculation symbols as their string form; validation belongs to the parser.
"""
canonical_calculation_name(c::Symbol) =
    c == :kslice ? "k_slice" : c == :kpath ? "k_path" : string(c)

"""
Test membership in Berry curvature or quantum metric, the real slice observables supporting per-band output.
"""
is_band_resolved_real_kslice_quantity(q::Symbol) = q in (:berry_curvature, :quantum_metric)
"""
Identify orbital interband metric/curvature quantities that use two disjoint band groups.
"""
is_orbital_interband_quantum_geometry_quantity(q::Symbol) =
    q in (:interband_berry_curvature, :interband_quantum_metric)
"""
Identify mixed Berry-connection/spin metric or curvature quantities with a separate spin axis.
"""
is_zeeman_interband_quantum_geometry_quantity(q::Symbol) =
    q in (:zeeman_interband_berry_curvature, :zeeman_interband_quantum_metric)
"""
Identify either orbital or Zeeman interband geometry quantities governed by the two-group output contract.
"""
is_interband_quantum_geometry_quantity(q::Symbol) =
    is_orbital_interband_quantum_geometry_quantity(q) ||
    is_zeeman_interband_quantum_geometry_quantity(q)
"""
Identify metric/curvature dipoles and the quantum Christoffel symbol, which use rank-three target-subspace output.
"""
is_rank3_target_group_real_kslice_quantity(q::Symbol) =
    q in (:berry_curvature_dipole, :quantum_metric_dipole, :quantum_christoffel_symbol)
"""
Identify metric and curvature quadrupoles, which require rank-four target-subspace output.
"""
is_rank4_target_group_real_kslice_quantity(q::Symbol) =
    q in (:berry_curvature_quadrupole, :quantum_metric_quadrupole)
"""
Identify rank-three or rank-four real target-subspace observables, excluding pair-selected interband geometry.
"""
is_target_group_real_kslice_quantity(q::Symbol) =
    is_rank3_target_group_real_kslice_quantity(q) || is_rank4_target_group_real_kslice_quantity(q)
"""
Identify real rank-two slice observables using per-band or interband-group output conventions.
"""
is_rank2_real_only_kslice_quantity(q::Symbol) =
    is_band_resolved_real_kslice_quantity(q) || is_interband_quantum_geometry_quantity(q)
"""
Identify slice observables whose outputs omit separate real/imaginary files under the declared band/subspace policy.
"""
is_real_only_kslice_quantity(q::Symbol) =
    is_rank2_real_only_kslice_quantity(q) || is_target_group_real_kslice_quantity(q)
