"""Shared model and real-space operator inputs; response parameters belong to each task."""
Base.@kwdef struct ModelInput
    model_file::String = ""
    real_space_operator_bundle_file::Union{Nothing, String} = nothing
    seedname::String = ""
    case_root::String = ""
    wannier_center_convention::String = "Convention_II"
    real_space_replica_policy::String = "auto"
    wsvec_file::Union{Nothing, String} = nothing
    mp_grid::Union{Nothing, NTuple{3, Int}} = nothing
    wigner_seitz_tolerance::Float64 = 1.0e-5
    wigner_seitz_search_size::Int = 3
    spin_enabled::Bool = false
    spin_file::String = ""
    checkpoint_file::String = ""
    spin_file_formatted::Bool = false
end

"""Common sampling geometry for a response run or a band path."""
abstract type AbstractSampling end

include("CartesianRegionSampling.jl")

"""Uniform Brillouin-zone mesh shared by all Integral task instances."""
struct BZMesh <: AbstractSampling
    k_mesh::Union{NTuple{1, Int}, NTuple{2, Int}, NTuple{3, Int}}
    spatial_dimension::Int
end
"""Copy the shared Integral mesh and record the number of physical Cartesian axes."""
BZMesh(; k_mesh, spatial_dimension::Integer = length(k_mesh)) =
    BZMesh(k_mesh, Int(spatial_dimension))

"""A common two-dimensional reciprocal-space slice, expressed in fractional coordinates."""
struct KSlice <: AbstractSampling
    k_mesh::NTuple{2, Int}
    spatial_dimension::Int
    origin::NTuple{3, Float64}
    vector_1::NTuple{3, Float64}
    vector_2::NTuple{3, Float64}
end
"""Copy an explicit fractional slice plane and its two sampling counts."""
function KSlice(; k_mesh, spatial_dimension::Integer, origin, vector_1, vector_2)
    d = length(origin)
    d in (2, 3) && length(vector_1) == length(vector_2) == d || throw(
        DimensionMismatch("slice origin and vectors require matching two or three coordinates"),
    )
    pad(value) = ntuple(i -> i <= d ? Float64(value[i]) : 0.0, 3)
    return KSlice(k_mesh, Int(spatial_dimension), pad(origin), pad(vector_1), pad(vector_2))
end

"""Reciprocal nodes partitioned into connected branches; counts include endpoints."""
struct KPath <: AbstractSampling
    nodes::Vector{Tuple{String, NTuple{3, Float64}}}
    kpoints_per_segment::Vector{Int}
    spatial_dimension::Int
    branches::Vector{UnitRange{Int}}
    provenance::Dict{String, Any}
end

"""Preserve explicit counts, or sample by Cartesian length when counts are omitted.

`branches` partitions the node list into disconnected connected chains. Default
sampling has 50 intervals per A^-1, at least two endpoints per segment.
"""
function KPath(;
    nodes,
    kpoints_per_segment = nothing,
    spatial_dimension::Integer = 3,
    branches = nothing,
    lattice = nothing,
    density::Real = 50.0,
    provenance = Dict{String, Any}(),
)
    normalized = normalize_kpath_input(nodes)
    ranges =
        branches === nothing ? [1:length(normalized)] :
        UnitRange{Int}[first(range):last(range) for range in branches]
    isempty(ranges) && throw(ArgumentError("KPath requires at least one connected branch"))
    all(range -> length(range) >= 2, ranges) &&
    reduce(vcat, collect.(ranges)) == collect(eachindex(normalized)) || throw(
        ArgumentError("branches must partition the node list into chains of at least two nodes"),
    )
    segment_count = sum(range -> length(range) - 1, ranges)
    details = Dict{String, Any}(provenance)
    counts = if kpoints_per_segment === nothing
        lattice === nothing &&
            throw(ArgumentError("omitted KPath counts require the actual model lattice"))
        isfinite(density) && density > 0 ||
            throw(ArgumentError("KPath density must be finite and positive"))
        reference =
            size(lattice) == (3, 3) ? lattice : first(complete_native_reference_lattice(lattice))
        reciprocal = reciprocal_lattice(reference)
        details["sampling_origin"] = "CARTESIAN_DENSITY"
        details["intervals_per_A_inverse"] = Float64(density)
        [
            max(
                2,
                ceil(
                    Int,
                    density * norm(
                        transpose(
                            collect(normalized[index + 1][2]) - collect(normalized[index][2]),
                        ) * reciprocal,
                    ),
                ) + 1,
            ) for range in ranges for index in first(range):(last(range) - 1)
        ]
    else
        details["sampling_origin"] = "EXPLICIT_COUNTS"
        kpoints_per_segment isa Integer ? fill(Int(kpoints_per_segment), segment_count) :
        Int.(kpoints_per_segment)
    end
    length(counts) == segment_count && all(>=(2), counts) ||
        throw(ArgumentError("one count of at least two is required per connected segment"))
    return KPath(normalized, counts, Int(spatial_dimension), ranges, details)
end

"""Generate a structural reference path in the input cell's reciprocal coordinates."""
function automatic_kpath(
    structure::CrystalStructure;
    periodic_axes = (1, 2, 3),
    kpoints_per_segment = nothing,
    density::Real = 50.0,
    time_reversal::Union{Nothing, Bool} = nothing,
    spglib_symprec_angstrom::Real = 1.0e-5,
    model_lattice = structure.lattice,
)
    generated =
        high_symmetry_band_path(structure; periodic_axes, time_reversal, spglib_symprec_angstrom)
    model_lattice = Matrix{Float64}(model_lattice)
    size(model_lattice) == (3, 3) &&
    all(isfinite, model_lattice) &&
    abs(det(model_lattice)) > eps(Float64) ||
        throw(ArgumentError("automatic path requires a finite nonsingular model lattice"))
    mismatch = maximum(abs, model_lattice - structure.lattice)
    mismatch <= spglib_symprec_angstrom || throw(
        ArgumentError(
            "structure and model cells differ beyond the declared symmetry tolerance; provide the structure in the model cell",
        ),
    )
    conversion =
        transpose(reciprocal_lattice(model_lattice)) \
        transpose(reciprocal_lattice(structure.lattice))
    nodes = [
        (label, Tuple(conversion * collect(coordinate))) for
        (label, coordinate) in reduce(vcat, generated.branches)
    ]
    generated.provenance["structure_lattice_angstrom"] =
        generated.provenance["input_lattice_angstrom"]
    generated.provenance["input_lattice_angstrom"] =
        [collect(row) for row in eachrow(model_lattice)]
    generated.provenance["structure_to_model_lattice_max_abs_angstrom"] = mismatch
    generated.provenance["structure_fractional_to_model_fractional"] =
        [collect(row) for row in eachrow(conversion)]
    ranges = UnitRange{Int}[]
    cursor = 1
    for branch in generated.branches
        push!(ranges, cursor:(cursor + length(branch) - 1))
        cursor += length(branch)
    end
    return KPath(;
        nodes,
        branches = ranges,
        kpoints_per_segment,
        spatial_dimension = length(periodic_axes),
        lattice = model_lattice,
        density,
        provenance = generated.provenance,
    )
end

"""Shared execution controls; the Fourier backend must be selected explicitly."""
Base.@kwdef struct ExecutionOptions
    fourier_backend::String
    integration_algorithm::AbstractIntegrationAlgorithm = UniformIntegration()
    NKdiv::Union{Nothing, NTuple{1, Int}, NTuple{2, Int}, NTuple{3, Int}} = nothing
    NKFFT::Union{Nothing, NTuple{1, Int}, NTuple{2, Int}, NTuple{3, Int}} = nothing
    response_symmetry_file::Union{Nothing, String} = nothing
    response_symmetry_policy::String = "strict"
    response_symmetry_kmesh_mode::String = "reduced"
    response_symmetry_report_enabled::Bool = false
end

"""Common output parent and formatting/progress controls; each task receives its own ID directory."""
Base.@kwdef struct OutputOptions
    output_root::String = ""
    system_name::Union{Nothing, String} = nothing
    response_output_digits::Int = 7
    progress_enabled::Bool = true
    progress_percent_interval::Union{Nothing, Int} = nothing
    progress_verbosity::String = "normal"
end

"""Physical parameters with quantity-specific applicability checked during compilation."""
abstract type AbstractTaskParameters end

"""Static BCD/BCQ Hall occupations, positive DC lifetime, and explicit integral expression.

The Fermi-energy scan is in eV, temperature in K and lifetime in femtoseconds.
No photon frequency, interband relaxation or boundary correction is implied.
"""
struct BerryMultipoleParameters <: AbstractTaskParameters
    fermi_energies::Vector{Float64}
    temperature::Float64
    relaxation_time_fs::Float64
    integral_form::Symbol
    function BerryMultipoleParameters(;
        fermi_energies,
        temperature::Real,
        relaxation_time_fs::Real,
        integral_form::Symbol = :fermi_surface,
    )
        temperature isa Bool && throw(ArgumentError("temperature must be a physical temperature"))
        relaxation_time_fs isa Bool &&
            throw(ArgumentError("relaxation_time_fs must be a physical lifetime"))
        isfinite(temperature) && temperature >= 0 || throw(ArgumentError("invalid temperature"))
        isfinite(relaxation_time_fs) && relaxation_time_fs > 0 ||
            throw(ArgumentError("positive finite relaxation_time_fs required"))
        integral_form in (:fermi_surface, :fermi_sea) ||
            throw(ArgumentError("integral_form must be fermi_surface or fermi_sea"))
        axis = fermi_energies isa Real ? [Float64(fermi_energies)] : Float64.(fermi_energies)
        return new(
            validate_fermi_energies(axis),
            Float64(temperature),
            Float64(relaxation_time_fs),
            integral_form,
        )
    end
end

"""Independent positive intraband and interband relaxation energies, in eV."""
Base.@kwdef struct SeparateRelaxation
    gamma_intra_ev::Float64
    gamma_inter_ev::Float64
end

"""Static intrinsic Berry Fermi-sea AHC. T0 only; no relaxation parameter."""
struct IntrinsicHallParameters <: AbstractTaskParameters
    fermi_energies::Vector{Float64}
    temperature::Float64
    function IntrinsicHallParameters(fermi_energies, temperature::Real)
        isfinite(temperature) && iszero(temperature) ||
            throw(ArgumentError("INTRINSIC_HALL_REQUIRES_ZERO_TEMPERATURE"))
        axis = fermi_energies isa Real ? [Float64(fermi_energies)] : Float64.(fermi_energies)
        new(validate_fermi_energies(axis), Float64(temperature))
    end
end
# Preserve the keyword Hall-parameter constructor and its zero-temperature default.
IntrinsicHallParameters(; fermi_energies, temperature::Real = 0.0) =
    IntrinsicHallParameters(fermi_energies, temperature)

"""Strict dc transport parameters; no photon energy axis."""
struct LinearTransportParameters <: AbstractTaskParameters
    fermi_energies::Vector{Float64}
    temperature::Float64
    relaxation::SeparateRelaxation
    function LinearTransportParameters(
        fermi_energies::Vector{Float64},
        temperature::Float64,
        relaxation::SeparateRelaxation,
    )
        new(validate_fermi_energies(fermi_energies), temperature, relaxation)
    end
end
"""Construct strict vector-axis dc transport parameters from public keywords."""
LinearTransportParameters(;
    fermi_energies::Vector{Float64},
    temperature::Real,
    relaxation::SeparateRelaxation,
) = LinearTransportParameters(fermi_energies, Float64(temperature), relaxation)

"""Complex linear optical response on an explicit photon-energy axis in eV."""
Base.@kwdef struct LinearOpticalResponseParameters <: AbstractTaskParameters
    photon_energies::Vector{Float64}
    fermi_energy::Float64
    temperature::Float64
    relaxation::SeparateRelaxation
end

"""Modern orbital magnetization with SRocc/CMocc decomposition, never wavepacket OAM.

input_semantics explicitly distinguishes a defined finite model from material
energy overlaps. Material input needs a qualified bundle and effective window.
"""
struct OrbitalMagnetizationParameters <: AbstractTaskParameters
    fermi_energies::Vector{Float64}
    temperature::Float64
    input_semantics::Symbol
    function OrbitalMagnetizationParameters(
        fermi_energies::Vector{Float64},
        temperature::Float64,
        input_semantics::Symbol,
    )
        new(validate_fermi_energies(fermi_energies), temperature, input_semantics)
    end
end
"""Construct strict vector-axis orbital-magnetization parameters from public keywords."""
OrbitalMagnetizationParameters(;
    fermi_energies::Vector{Float64},
    temperature::Real,
    input_semantics::Symbol,
) = OrbitalMagnetizationParameters(fermi_energies, Float64(temperature), input_semantics)

"""Optical energy axis in eV, Fermi energy in eV, and temperature in K; all are explicit."""
struct OpticalParameters <: AbstractTaskParameters
    photon_energies::Vector{Float64}
    fermi_energy::Float64
    temperature::Float64
end
"""Copy the explicit optical energy axis and occupation conditions in eV and K."""
OpticalParameters(; photon_energies, fermi_energy::Real, temperature::Real) = OpticalParameters(
    Float64[x for x in photon_energies],
    Float64(fermi_energy),
    Float64(temperature),
)

"""SHG energies in eV and temperature in K, with explicit output selection."""
struct SHGParameters <: AbstractTaskParameters
    photon_energies::Vector{Float64}
    fermi_energy::Float64
    temperature::Float64
    output::Symbol
    response::Symbol
end

"""Select total, terms or both; response selects susceptibility, conductivity or both."""
SHGParameters(; photon_energies, fermi_energy, temperature, output = :total, response = :both) =
    SHGParameters(
        Float64.(collect(photon_energies)),
        Float64(fermi_energy),
        Float64(temperature),
        Symbol(output),
        Symbol(response),
    )

"""Finite nonnegative photon energies and occupation controls for the ordered jerk material coefficient."""
struct JerkParameters <: AbstractTaskParameters
    photon_energies::Vector{Float64}
    fermi_energy::Float64
    temperature::Float64
    projection::Symbol
end

"""Fourier THG physical parameters; formulation and observable selections are explicit."""
struct THGParameters <: AbstractTaskParameters
    photon_energies::Vector{Float64}
    fermi_energy::Float64
    temperature::Float64
    formulation::Symbol
    response::Symbol
    output::Symbol
end

# Reject removed response-layer unit conversion controls at the input boundary.
function reject_removed_third_order_measure_keys(names, location)
    removed = filter(
        name ->
            (name isa Symbol || name isa AbstractString) &&
            Symbol(name) in (:response_measure, :sheet_axes, :effective_thickness_angstrom),
        names,
    )
    isempty(removed) || throw(
        ArgumentError(
            "$(location): unsupported removed JC/THG parameter(s) $(join(removed, ", ")). " *
            "Declare model geometry in the model input and perform sheet/line/effective-thickness conversions in postprocessing; these fields are not ignored.",
        ),
    )
    return nothing
end

"""Construct the ordered jerk coefficient without response-layer unit conversions."""
function JerkParameters(;
    photon_energies,
    fermi_energy,
    temperature,
    projection = :ordered,
    kwargs...,
)
    reject_removed_third_order_measure_keys(keys(kwargs), "JerkParameters")
    isempty(kwargs) ||
        throw(ArgumentError("Unsupported JerkParameters keyword(s): $(join(keys(kwargs), ", "))"))
    return JerkParameters(photon_energies, fermi_energy, temperature, projection)
end

"""Construct THG with the retained formulation, observable and output defaults."""
function THGParameters(;
    photon_energies,
    fermi_energy,
    temperature,
    formulation = :regrouped,
    response = :both,
    output = :both,
    kwargs...,
)
    reject_removed_third_order_measure_keys(keys(kwargs), "THGParameters")
    isempty(kwargs) ||
        throw(ArgumentError("Unsupported THGParameters keyword(s): $(join(keys(kwargs), ", "))"))
    return THGParameters(photon_energies, fermi_energy, temperature, formulation, response, output)
end

"""
Optical parameters with either one Cartesian q or an explicitly zipped q axis.

Energies use eV and momenta use A^-1. Exactly one of `photon_momentum` and
`photon_momenta` is required; inputs are copied and unequal lengths are rejected.
The paired path has no Cartesian-product or momentum-symmetry interpretation.
"""
struct FiniteQOpticalParameters <: AbstractTaskParameters
    photon_energies::Vector{Float64}
    fermi_energy::Float64
    temperature::Float64
    photon_momentum::Union{Nothing, NTuple{3, Float64}}
    photon_momenta::Union{Nothing, Vector{NTuple{3, Float64}}}
end
"""Copy optical inputs and select one explicit fixed or paired momentum axis."""
function FiniteQOpticalParameters(;
    photon_energies,
    fermi_energy::Real,
    temperature::Real,
    photon_momentum = nothing,
    photon_momenta = nothing,
)
    (photon_momentum === nothing) != (photon_momenta === nothing) ||
        throw(ArgumentError("specify exactly one of photon_momentum and photon_momenta"))
    energies = _copy_photon_path_energies(photon_energies)
    momentum = photon_momentum === nothing ? nothing : _copy_photon_path_momentum(photon_momentum)
    momenta =
        photon_momenta === nothing ? nothing :
        make_photon_momentum_path(energies, photon_momenta).photon_momenta
    return FiniteQOpticalParameters(
        energies,
        Float64(fermi_energy),
        Float64(temperature),
        momentum,
        momenta,
    )
end

# Preserve the valid four-argument fixed-q construction through the same owned inputs.
FiniteQOpticalParameters(energies, fermi_energy, temperature, momentum) = FiniteQOpticalParameters(;
    photon_energies = energies,
    fermi_energy,
    temperature,
    photon_momentum = momentum,
)

"""Geometric parameters; occupation values are required only for an explicit occupied sum."""
Base.@kwdef struct GeometryParameters <: AbstractTaskParameters
    fermi_energy::Union{Nothing, Float64} = nothing
    temperature::Union{Nothing, Float64} = nothing
    photon_momentum::Union{Nothing, NTuple{3, Float64}} = nothing
    include_external::Bool = false
end

"""Explicit reference energy in eV for band-spectrum output."""
struct BandParameters <: AbstractTaskParameters
    fermi_energy::Float64
end
"""Store the explicitly supplied band energy reference in eV."""
BandParameters(; fermi_energy::Real) = BandParameters(Float64(fermi_energy))

"""
Explicit numerical controls for one task. No response defaults are inserted here.

Quantity, method, sampling and physical parameters determine defaults and legality
when the task is compiled. Values are copied; `supplied` distinguishes an omitted
key from an explicit `nothing` or explicit default. Hot kernels consume resolved
concrete settings, never this public request object.
"""
struct Numerics{V <: NamedTuple}
    values::V
    supplied::Tuple{Vararg{Symbol}}
    function Numerics(; kwargs...)
        values = (; kwargs...)
        unknown = setdiff(keys(values), NUMERICS_PARAMETER_NAMES)
        isempty(unknown) ||
            throw(ArgumentError("Numerics: unknown parameters $(join(string.(unknown), ", "))."))
        copied = deepcopy(values)
        new{typeof(copied)}(copied, Tuple(keys(copied)))
    end
end

# All recognized public keys; applicability is checked against the actual task.
const NUMERICS_PARAMETER_NAMES = (
    :broadening,
    :broadening_type,
    :transition_window_factor,
    :denominator_regularization,
    :degeneracy_threshold,
    :finite_difference_step,
    :derivative_backend,
    :band_window_size,
    :low_frequency_broadening,
    :intermediate_regularization,
    :eta_correction,
    :hermiticity_tolerance,
    :gap_tolerance,
    :fs_kind,
    :eta_fs_ev,
    :prescription,
    :occupation_derivative_mode,
)

# Resolve quantity-specific defaults without mutating the user's explicit request.
function resolved_numerical_values(task, quantity; nonorthogonal::Bool = false)
    request = something(task.numerics, Numerics())
    if quantity in (:photon_drag_shift_current, :photon_drag_injection_current) &&
       :band_window_size in request.supplied &&
       get(request.values, :band_window_size, -1) != -1
        throw(
            ArgumentError(
                "photon-drag uses all finite-model bands; band_window_size must be omitted or -1",
            ),
        )
    end
    defaults = if quantity == :second_harmonic_generation
        (;
            broadening = 0.025,
            broadening_type = "Gaussian",
            low_frequency_broadening = 0.025,
            intermediate_regularization = 0.001,
            eta_correction = true,
            degeneracy_threshold = 1.0e-4,
        )
    elseif quantity == :third_harmonic_generation
        (;
            broadening = 0.025,
            broadening_type = "Gaussian",
            low_frequency_broadening = 0.025,
            intermediate_regularization = 0.001,
            eta_correction = true,
            prescription = :distribution_broadening,
            occupation_derivative_mode = :shg_gaussian,
        )
    elseif quantity == :band_structure
        (; hermiticity_tolerance = 1.0e-10)
    elseif quantity == :intrinsic_ahc
        NamedTuple()
    elseif quantity == :orbital_magnetization
        (; denominator_regularization = 0.001)
    elseif quantity in (:linear_transport, :linear_optical_response)
        nonorthogonal && quantity==:linear_transport ?
        (; gap_tolerance = 1.0e-10, fs_kind = nothing, eta_fs_ev = nothing) :
        (;
            gap_tolerance = 1.0e-10,
            fs_kind = nothing,
            eta_fs_ev = nothing,
            denominator_regularization = 0.001,
        )
    elseif quantity in BERRY_MULTIPOLE_QUANTITIES
        berry_multipole_numerical_defaults(task, quantity)
    elseif quantity in OPTICAL_TASK_QUANTITIES
        (;
            broadening = 0.040,
            broadening_type = "Gaussian",
            transition_window_factor = 5.0,
            denominator_regularization = 0.001,
            degeneracy_threshold = 0.002,
            finite_difference_step = nothing,
            band_window_size = -1,
        )
    elseif quantity in (:berry_curvature_dipole, :berry_curvature_quadrupole)
        (;
            derivative_backend = :finite_difference,
            denominator_regularization = get(
                request.values,
                :derivative_backend,
                :finite_difference,
            ) == :analytic ? 0.0 : 0.001,
            degeneracy_threshold = 0.002,
            finite_difference_step = nothing,
            band_window_size = nothing,
        )
    else
        (;
            denominator_regularization = 0.001,
            degeneracy_threshold = 0.002,
            finite_difference_step = nothing,
            band_window_size = nothing,
        )
    end
    if nonorthogonal && quantity == :second_harmonic_generation
        defaults=merge(defaults, (; denominator_regularization = 0.001, eta_correction = false))
    end
    if nonorthogonal && quantity == :orbital_magnetization
        defaults=merge(defaults, (; denominator_regularization = 0.001))
    end
    quantity in ZERO_REGULARIZATION_GEOMETRY_QUANTITIES &&
        (defaults = merge(defaults, (; denominator_regularization = 0.0)))
    # A positive supplied width chooses the existing finite-difference expression.
    if quantity in (:berry_curvature_dipole, :berry_curvature_quadrupole) &&
       get(request.values, :denominator_regularization, 0.0) isa Real &&
       get(request.values, :denominator_regularization, 0.0) > 0
        get(request.values, :derivative_backend, :finite_difference) == :analytic && throw(
            ArgumentError("positive denominator_regularization conflicts with analytic geometry"),
        )
        defaults = merge(defaults, (; derivative_backend = :finite_difference))
    end
    if quantity in (:shift_spin_current, :injection_spin_current)
        :degeneracy_threshold in request.supplied && throw(
            ArgumentError(
                "SPIN_CURRENT_DEGENERACY_THRESHOLD_REMOVED: task $(task.id) explicitly supplies degeneracy_threshold, which is no longer supported for spin-current tasks. Remove this parameter from this task's numerics.",
            ),
        )
        defaults = merge(defaults, (; degeneracy_threshold = 0.0))
    end
    if quantity == :orbital_magnetization && :gap_tolerance in request.supplied
        throw(
            ArgumentError(
                "OM_GAP_TOLERANCE_UNSUPPORTED: task $(task.id), orbital_magnetization does not support gap_tolerance.",
            ),
        )
    end
    if quantity in (:jerk_current, :third_harmonic_generation)
        :degeneracy_threshold in request.supplied && throw(
            ArgumentError(
                "THIRD_ORDER_DEGENERACY_THRESHOLD_UNSUPPORTED: task $(task.id), $quantity does not support degeneracy_threshold.",
            ),
        )
        defaults = (;
            (key => value for (key, value) in pairs(defaults) if key != :degeneracy_threshold)...
        )
    end
    # Normal metric optics uses the same positive finite-eta prescription as orthogonal optics.
    # This is a task admission rule, not a restriction on metric spectra or velocity operators.
    if nonorthogonal &&
       quantity==:linear_optical_response &&
       :denominator_regularization in request.supplied
        eta = get(request.values, :denominator_regularization, nothing)
        valid_eta = eta isa Real && !(eta isa Bool) && isfinite(eta) && eta>0
        valid_eta || throw(
            ArgumentError(
                "NONORTHOGONAL_LINEAR_OPTICAL_REGULARIZATION_REQUIRED: task $(task.id), denominator_regularization must be finite and positive in eV (default 0.001 eV).",
            ),
        )
    end
    unused = setdiff(request.supplied, keys(defaults))
    isempty(unused) || throw(
        ArgumentError(
            "Numerics parameters $(join(string.(unused), ", ")) do not apply to task $(task.id), quantity $quantity.",
        ),
    )
    for (name, value) in pairs(request.values)
        if value===nothing
            (defaults[name]===nothing || name==:band_window_size) || throw(
                ArgumentError(
                    "Numerics parameter $name cannot be nothing in task $(task.id), quantity $quantity",
                ),
            )
            continue
        end
        valid =
            name==:eta_correction ? value isa Bool :
            name==:broadening_type ? value isa AbstractString :
            name in (:fs_kind, :prescription, :occupation_derivative_mode, :derivative_backend) ?
            value isa Symbol : value isa Real && !(value isa Bool)
        if valid && value isa Real
            numeric_value=try
                Float64(value)
            catch
                NaN
            end
            valid=isfinite(numeric_value)
            if name==:band_window_size
                valid &=
                    isinteger(value) && typemin(Int)<=value<=typemax(Int) && (value==-1 || value>0)
            elseif name in (
                :broadening,
                :low_frequency_broadening,
                :eta_fs_ev,
                :hermiticity_tolerance,
                :finite_difference_step,
            )
                valid &= numeric_value>0
            elseif name in (
                :gap_tolerance,
                :degeneracy_threshold,
                :denominator_regularization,
                :intermediate_regularization,
            )
                valid &= numeric_value>=0
                # Retain the existing metric SC isolated-band eta=0 branch.
                # Other regularized roles stay positive; this introduces no bare SHG mode.
                metric_sc_isolated =
                    nonorthogonal && quantity==:shift_current && name==:denominator_regularization
                analytic_geometry_bare =
                    name == :denominator_regularization && (
                        (
                            quantity in (:berry_curvature_dipole, :berry_curvature_quadrupole) &&
                            get(request.values, :derivative_backend, :finite_difference) ==
                            :analytic
                        ) || (
                            quantity in BERRY_MULTIPOLE_QUANTITIES &&
                            defaults.denominator_regularization == 0
                        )
                    )
                positive_regularization =
                    name in (:denominator_regularization, :intermediate_regularization) &&
                    !metric_sc_isolated &&
                    !(
                        quantity in ZERO_REGULARIZATION_GEOMETRY_QUANTITIES ||
                        quantity in BERRY_MULTIPOLE_QUANTITIES
                    ) &&
                    !analytic_geometry_bare
                positive_regularization && (valid &= numeric_value>0)
            end
        elseif valid && name==:broadening_type
            valid=value in ("Gaussian", "Lorentzian")
        elseif valid && name==:fs_kind
            valid=value in (:gaussian, :lorentzian)
        elseif valid && name==:prescription
            value == :distribution_broadening || throw(
                ArgumentError(
                    "THG prescription must be distribution_broadening; causal was removed and shg_compatible requires explicit migration",
                ),
            )
            valid=true
        elseif valid && name==:occupation_derivative_mode
            valid=value in (:fermi_dirac, :shg_gaussian)
        elseif valid && name==:derivative_backend
            valid=value in (:analytic, :finite_difference)
        end
        valid || throw(
            ArgumentError(
                "Invalid value or type for Numerics parameter $name in task $(task.id), quantity $quantity",
            ),
        )
    end
    resolved = merge(defaults, request.values)
    if quantity in (:berry_curvature_dipole, :berry_curvature_quadrupole) &&
       resolved.derivative_backend == :analytic
        :finite_difference_step in request.supplied && throw(
            ArgumentError(
                "finite_difference_step does not apply to analytic task $(task.id); inherited explicit values must also be omitted",
            ),
        )
        resolved.denominator_regularization == 0 || throw(
            ArgumentError(
                "analytic BCD/BCQ requires zero denominator_regularization; regularized-curvature derivatives are not supported",
            ),
        )
        nonorthogonal && throw(
            ArgumentError(
                "analytic BCD/BCQ requires an orthogonal model; finite_difference remains available",
            ),
        )
    end
    return resolved
end

# Keep new response quantities separate from the historical optical-current family.
const SPECTRAL_RESPONSE_QUANTITIES=(
    :intrinsic_ahc,
    :linear_transport,
    :linear_optical_response,
    :orbital_magnetization,
)

# Validate explicit family inputs before file IO and preserve static versus optical axes.
function _spectral_task_physics(task, quantity, calculation = :integral)
    physics=task.physics
    if quantity == :intrinsic_ahc
        physics isa IntrinsicHallParameters ||
            throw(ArgumentError("intrinsic_ahc requires IntrinsicHallParameters"))
        calculation in (:integral, :kslice) ||
            throw(ArgumentError("intrinsic_ahc requires Integral or KSlice sampling"))
        iszero(physics.temperature) ||
            throw(ArgumentError("INTRINSIC_HALL_REQUIRES_ZERO_TEMPERATURE"))
        return (;
            fermi_energies = copy(physics.fermi_energies),
            fermi_energies_definition = fermi_energy_axis_definition(physics.fermi_energies),
            temperature = physics.temperature,
            photon_energies = Float64[],
        )
    end
    expected=quantity==:linear_transport ? LinearTransportParameters :
             quantity==:linear_optical_response ? LinearOpticalResponseParameters :
             OrbitalMagnetizationParameters
    physics isa expected || throw(ArgumentError("$quantity requires $expected"))
    if quantity in (:linear_transport, :orbital_magnetization)
        axis = validate_fermi_energies(physics.fermi_energies)
        _validate_occupation_values(first(axis), physics.temperature)
        if calculation == :kslice && length(axis) != 1
            code =
                quantity == :linear_transport ?
                "LINEAR_TRANSPORT_KSLICE_REQUIRES_SINGLE_FERMI_ENERGY" :
                "ORBITAL_MAGNETIZATION_KSLICE_REQUIRES_SINGLE_FERMI_ENERGY"
            throw(ArgumentError(code))
        end
    else
        _validate_occupation_values(physics.fermi_energy, physics.temperature)
    end
    energy=quantity==:linear_optical_response ? physics.photon_energies : Float64[]
    if quantity==:linear_optical_response
        !isempty(energy) && all(x->isfinite(x)&&x>=0, energy) ||
            throw(ArgumentError("Nonnegative finite photon_energies required"))
    end
    if quantity==:orbital_magnetization
        physics.input_semantics in
        (:defined_finite_model, :projected_energy_overlap, :direct_energy_overlap) ||
            throw(ArgumentError("Unknown orbital input semantics"))
        return (;
            fermi_energies = copy(physics.fermi_energies),
            fermi_energies_definition = fermi_energy_axis_definition(physics.fermi_energies),
            temperature = physics.temperature,
            photon_energies = energy,
            orbital_input_semantics = physics.input_semantics,
        )
    end
    rates=physics.relaxation
    all(x->isfinite(x)&&x>0, (rates.gamma_intra_ev, rates.gamma_inter_ev)) || throw(
        ArgumentError(
            "Positive finite relaxation energies required; singular clean spectra are unsupported",
        ),
    )
    return (;
        fermi_energies = quantity == :linear_transport ? copy(physics.fermi_energies) : Float64[],
        fermi_energies_definition = quantity == :linear_transport ?
                                    fermi_energy_axis_definition(physics.fermi_energies) :
                                    "NOT_APPLICABLE",
        fermi_energy = quantity == :linear_optical_response ? physics.fermi_energy : 0.0,
        temperature = physics.temperature,
        photon_energies = copy(energy),
        gamma_intra_ev = rates.gamma_intra_ev,
        gamma_inter_ev = rates.gamma_inter_ev,
    )
end

# Keep spectral-gap thresholds independent of physical relaxation and FS broadening.
function _spectral_task_numerics(task, quantity; nonorthogonal::Bool = false)
    numerics=resolved_numerical_values(task, quantity; nonorthogonal)
    if quantity == :intrinsic_ahc
        return NamedTuple()
    end
    if quantity == :orbital_magnetization
        return (; denominator_regularization = Float64(numerics.denominator_regularization))
    end
    isfinite(numerics.gap_tolerance)&&numerics.gap_tolerance>=0 ||
        throw(ArgumentError("Invalid spectral gap tolerance"))
    result=(;
        spectral_gap_tolerance = Float64(numerics.gap_tolerance),
        denominator_regularization = !nonorthogonal || quantity in
                                     (:orbital_magnetization, :linear_optical_response) ?
                                     Float64(numerics.denominator_regularization) : 0.0,
        degeneracy_threshold = 0.0,
    )
    if quantity!=:orbital_magnetization
        has_kind = numerics.fs_kind !== nothing
        has_width = numerics.eta_fs_ev !== nothing
        has_kind == has_width ||
            throw(ArgumentError("fs_kind and eta_fs_ev must be provided together"))
        has_fs = has_kind && has_width
        if task.physics.temperature==0
            has_fs || throw(ArgumentError("T=0 requires explicit fs_kind and eta_fs_ev"))
        elseif has_fs || any(
            key->key in (:fs_kind, :eta_fs_ev),
            something(task.numerics, Numerics()).supplied,
        )
            throw(ArgumentError("Finite T uses exact -f′; omit fs_kind and eta_fs_ev"))
        end
        if has_fs
            numerics.fs_kind in (:gaussian, :lorentzian) &&
            isfinite(numerics.eta_fs_ev) &&
            numerics.eta_fs_ev>0 || throw(ArgumentError("Invalid FS line shape/width"))
            result=merge(
                result,
                (; fs_kind = numerics.fs_kind, eta_fs_ev = Float64(numerics.eta_fs_ev)),
            )
        end
    end
    return result
end

"""Typed band observation; it never substitutes for the internal calculation band window."""
abstract type AbstractBandSelection end

# Copy positive one-based target indices and reject empty or repeated bands.
function _observation_bands(values, name::AbstractString)
    values isa AbstractVector ||
        throw(ArgumentError("$(name) requires a vector of positive band indices."))
    all(x -> x isa Integer && !(x isa Bool) && x > 0, values) ||
        throw(ArgumentError("$(name) requires positive integer band indices."))
    result = Int[x for x in values]
    isempty(result) && throw(ArgumentError("$(name) must not be empty."))
    length(unique(result)) == length(result) ||
        throw(ArgumentError("$(name) must not repeat band indices."))
    return result
end

"""Observe individual bands; an additional occupied sum must be requested explicitly."""
struct BandTargets <: AbstractBandSelection
    bands::Vector{Int}
    include_occupied_sum::Bool
    function BandTargets(bands; include_occupied_sum::Bool = false)
        new(_observation_bands(bands, "BandTargets"), include_occupied_sum)
    end
end

"""Observe a single explicit band subspace, including a one-band subspace."""
struct Subspace <: AbstractBandSelection
    bands::Vector{Int}
    Subspace(bands) = new(_observation_bands(bands, "Subspace"))
end

"""Observe several disjoint explicit subspaces, preserving their supplied order."""
struct Subspaces <: AbstractBandSelection
    groups::Vector{Vector{Int}}
    function Subspaces(groups)
        result = [_observation_bands(group, "Subspaces") for group in groups]
        isempty(result) && throw(ArgumentError("Subspaces must contain at least one group."))
        flat = reduce(vcat, result)
        length(unique(flat)) == length(flat) || throw(ArgumentError("Subspaces must be disjoint."))
        new(result)
    end
end

"""Observe the occupation-weighted sum over all bands."""
struct OccupiedBands <: AbstractBandSelection end

"""Observe every individual band, optionally also its occupation-weighted sum."""
Base.@kwdef struct AllBands <: AbstractBandSelection
    include_occupied_sum::Bool = false
end

"""An explicit conduction/valence band-pair channel."""
struct Transition <: AbstractBandSelection
    conduction::Vector{Int}
    valence::Vector{Int}
    function Transition(; conduction, valence)
        c = _observation_bands(conduction, "Transition conduction")
        v = _observation_bands(valence, "Transition valence")
        isempty(intersect(c, v)) || throw(ArgumentError("Transition band groups must be disjoint."))
        new(c, v)
    end
end

"""Two explicit non-overlapping band groups for interband geometry."""
struct InterbandGroups <: AbstractBandSelection
    first::Vector{Int}
    second::Vector{Int}
    function InterbandGroups(; first, second)
        a = _observation_bands(first, "InterbandGroups first")
        b = _observation_bands(second, "InterbandGroups second")
        isempty(intersect(a, b)) || throw(ArgumentError("InterbandGroups must be disjoint."))
        new(a, b)
    end
end

"""Three explicit, pairwise-disjoint ordered band groups for a triple-phase product."""
struct TripleGroups <: AbstractBandSelection
    first::Vector{Int}
    second::Vector{Int}
    third::Vector{Int}
    function TripleGroups(; first, second, third)
        a = _observation_bands(first, "TripleGroups first")
        b = _observation_bands(second, "TripleGroups second")
        c = _observation_bands(third, "TripleGroups third")
        length(unique(vcat(a, b, c))) == length(a) + length(b) + length(c) ||
            throw(ArgumentError("TripleGroups must be pairwise disjoint."))
        new(a, b, c)
    end
end

"""A single ordered Cartesian tensor component; rank and axis limits are task-specific."""
struct TensorComponent
    indices::Tuple{Vararg{Int}}
    function TensorComponent(indices::Integer...)
        all(x -> !(x isa Bool) && x > 0, indices) ||
            throw(ArgumentError("TensorComponent indices must be positive integers."))
        new(Tuple(Int(x) for x in indices))
    end
end

"""An ordered, nonempty list of unique Cartesian components; the task checks rank applicability."""
struct TensorComponents
    components::Tuple{Vararg{Union{NTuple{3, Int}, NTuple{4, Int}}}}
    function TensorComponents(components::TensorComponent...)
        isempty(components) && throw(ArgumentError("TensorComponents must be nonempty"))
        rank = length(first(components).indices)
        rank in (3, 4) && all(c->length(c.indices)==rank && all(i->i<=3, c.indices), components) ||
            throw(
                ArgumentError(
                    "TensorComponents requires one consistent rank, three or four Cartesian axes; the task registry checks applicability",
                ),
            )
        tuples=Tuple(c.indices for c in components)
        length(unique(tuples))==length(tuples) || throw(ArgumentError("Duplicate components"))
        new(tuples)
    end
end

"""Accept a collection of typed selectors or three-/four-axis integer tuples."""
function TensorComponents(components::Union{AbstractVector, Tuple})
    converted=map(components) do component
        component isa TensorComponent && return component
        component isa Tuple && length(component) in (3, 4) && all(i->i isa Integer, component) ||
            throw(
                ArgumentError(
                    "TensorComponents accepts TensorComponent or three-/four-axis integer tuples",
                ),
            )
        return TensorComponent(component...)
    end
    return TensorComponents(converted...)
end

"""The complete response tensor currently supported for Integral output."""
struct FullTensor end

"""An explicit component and band/subspace target for a K-slice task."""
Base.@kwdef struct KSliceSelection
    component::TensorComponent
    bands::AbstractBandSelection
end

"""A named response instance with its own physical, numerical, and observation parameters."""
struct TaskSpec
    id::String
    quantity::String
    method::Union{Nothing, String}
    physics::AbstractTaskParameters
    numerics::Union{Nothing, Numerics}
    observable::Union{Nothing, FullTensor, TensorComponents, KSliceSelection}
end

# Shared by the typed API, named text boundary and explicit migration tool.
function _validate_task_id(id::AbstractString)
    occursin(r"^[A-Za-z0-9][A-Za-z0-9_-]*$", id) || throw(
        ArgumentError(
            "Task id must contain only ASCII letters, digits, '-' and '_', and start with a letter or digit.",
        ),
    )
    return String(id)
end

"""Copy one named task and reject IDs that could escape its output directory."""
function TaskSpec(;
    id::AbstractString,
    quantity::AbstractString,
    method::Union{Nothing, AbstractString} = nothing,
    physics::AbstractTaskParameters,
    numerics::Union{Nothing, Numerics} = nothing,
    observable::Union{Nothing, FullTensor, TensorComponents, KSliceSelection} = nothing,
)
    _validate_task_id(id)
    isempty(strip(quantity)) && throw(ArgumentError("Task quantity must not be empty."))
    return TaskSpec(
        String(id),
        String(quantity),
        method === nothing ? nothing : String(method),
        deepcopy(physics),
        deepcopy(numerics),
        deepcopy(observable),
    )
end

"""Public run configuration: shared model/sampling/execution plus independently named tasks."""
struct TaskConfig
    model::Union{ModelInput, AbstractNativeModelInput}
    sampling::AbstractSampling
    tasks::Vector{TaskSpec}
    execution::ExecutionOptions
    output::OutputOptions
end

"""Copy the shared configuration and reject empty or case-colliding task identifiers."""
function TaskConfig(;
    model::Union{Nothing, ModelInput, AbstractNativeModelInput} = nothing,
    sampling::Union{Nothing, AbstractSampling} = nothing,
    tasks = nothing,
    execution::Union{Nothing, ExecutionOptions} = nothing,
    output::OutputOptions = OutputOptions(),
    kwargs...,
)
    if !isempty(kwargs) || (tasks !== nothing && !(tasks isa AbstractVector{TaskSpec}))
        throw(
            ArgumentError(
                "The flat TaskConfig interface has been removed. Use ModelInput, sampling, ExecutionOptions and named TaskSpec objects; see docs/PUBLIC_API.md. Unsupported keywords: $(join(string.(keys(kwargs)), ", ")).",
            ),
        )
    end
    model !== nothing && sampling !== nothing && execution !== nothing && tasks !== nothing ||
        throw(
            ArgumentError(
                "TaskConfig requires explicit model, sampling, execution and tasks groups; see docs/PUBLIC_API.md.",
            ),
        )
    isempty(tasks) && throw(ArgumentError("TaskConfig requires at least one TaskSpec."))
    ids = lowercase.([task.id for task in tasks])
    length(unique(ids)) == length(ids) ||
        throw(ArgumentError("Task ids must be unique, including on case-insensitive filesystems."))
    return TaskConfig(
        deepcopy(model),
        deepcopy(sampling),
        deepcopy(collect(tasks)),
        deepcopy(execution),
        deepcopy(output),
    )
end

# Cold-path named-field conversion keeps the effective compiler independent of field order.
_configuration_fields(value) =
    (; (name => getfield(value, name) for name in fieldnames(typeof(value)))...)
# Map the shared BZ mesh to the Integral executor category.
_sampling_calculation(::BZMesh) = :integral
# Map the shared slice geometry to the K-slice executor category.
_sampling_calculation(::KSlice) = :kslice
# Map the shared reciprocal-space path to the K-path calculation domain.
_sampling_calculation(::KPath) = :kpath
# Lower the common BZ mesh to the private execution configuration.
_sampling_fields(sampling::BZMesh) =
    (; k_mesh = sampling.k_mesh, spatial_dimension = sampling.spatial_dimension)
# Lower the explicit slice vectors and counts without altering reciprocal coordinates.
_sampling_fields(sampling::KSlice) = (;
    k_mesh = sampling.k_mesh,
    spatial_dimension = sampling.spatial_dimension,
    kslice_origin = sampling.origin,
    kslice_vector_1 = sampling.vector_1,
    kslice_vector_2 = sampling.vector_2,
)
# Lower path nodes and segment counts; the private mesh placeholder is unused by KPath.
_sampling_fields(sampling::KPath) = (;
    k_mesh = (1, 1, 1),
    spatial_dimension = sampling.spatial_dimension,
    kpath_nodes = sampling.nodes,
    kpoints_per_segment = sampling.kpoints_per_segment,
    kpath_branches = sampling.branches,
    kpath_provenance = sampling.provenance,
)

# Band structure is a registry-owned task semantic, not a property of KPath sampling.
_is_band_structure(definition::TaskDefinition) =
    definition.executor == EXECUTOR_BAND_STRUCTURE &&
    definition.output_policy == OUTPUT_BAND_STRUCTURE

# Explicit band and subspace targets do not request an occupation-weighted sum.
_occupied_sum_requested(::AbstractBandSelection) = false
# Recognize the dedicated occupation-weighted-sum observation.
_occupied_sum_requested(::OccupiedBands) = true
# Read the explicit optional sum flag on individual-band observations.
_occupied_sum_requested(selection::Union{BandTargets, AllBands}) = selection.include_occupied_sum
# Lower individual targets to the ordered singleton tuple expected by the numerical kernel.
_effective_band_selection(selection::BandTargets) = Tuple(selection.bands)
# Keep a single subspace grouped even when it contains only one band.
_effective_band_selection(selection::Subspace) = (copy(selection.bands),)
# Preserve each disjoint subspace as its own ordered target group.
_effective_band_selection(selection::Subspaces) = Tuple(copy.(selection.groups))
# Use the private sum-only sentinel for the explicit occupied observation.
_effective_band_selection(::OccupiedBands) = 0
# Use the private all-singletons sentinel while tracking sum output separately.
_effective_band_selection(::AllBands) = -1
# Lower the explicit conduction and valence channel without changing its order.
_effective_band_selection(selection::Transition) =
    (copy(selection.conduction), copy(selection.valence))
# Lower two disjoint geometry groups in their specified order.
_effective_band_selection(selection::InterbandGroups) =
    (copy(selection.first), copy(selection.second))
# Lower the three ordered phase-product groups to independent copied vectors.
_effective_band_selection(selection::TripleGroups) =
    (copy(selection.first), copy(selection.second), copy(selection.third))

# Resolve the task selector against the common sampling category and exact registry row.
function _public_task_identity(task::TaskSpec, sampling::AbstractSampling)
    calculation = _sampling_calculation(sampling)
    quantity = normalize_quantity(task.quantity)
    validate_quantity_short_label_calculation(task.quantity, quantity, calculation)
    method =
        task.method === nothing ? infer_single_supported_method(quantity, calculation) :
        normalize_method(task.method)
    definition = task_definition(quantity, method, calculation)
    definition === nothing && select_task(quantity, method, calculation)
    return quantity, method, calculation, definition
end

# Check the observable against the registered band policy and lower its tensor/band selection.
function _task_observation(task::TaskSpec, definition::TaskDefinition, calculation::Symbol)
    if _is_band_structure(definition)
        task.observable === nothing ||
            throw(ArgumentError("Band tasks do not accept response observables."))
        return (; tensor_indices = (), band_selection = -1, include_occupied_sum = false)
    elseif calculation == :integral
        if task.observable isa TensorComponents
            definition.quantity in (
                QUANTITY_JERK_CURRENT,
                QUANTITY_THIRD_HARMONIC_GENERATION,
                QUANTITY_BERRY_CURVATURE_DIPOLE_CONDUCTIVITY,
                QUANTITY_BERRY_CURVATURE_QUADRUPOLE_CONDUCTIVITY,
            ) || throw(ArgumentError("TensorComponents does not apply to this task"))
            all(
                component -> length(component) == Int(definition.tensor_rank),
                task.observable.components,
            ) || throw(
                ArgumentError(
                    "TensorComponents rank must match the registered task rank $(definition.tensor_rank)",
                ),
            )
            return (;
                tensor_indices = first(task.observable.components),
                band_selection = -1,
                include_occupied_sum = false,
            )
        end
        task.observable isa Union{Nothing, FullTensor} ||
            throw(ArgumentError("Integral tasks support only FullTensor()."))
        return (;
            tensor_indices = ntuple(_ -> 1, Int(definition.tensor_rank)),
            band_selection = -1,
            include_occupied_sum = false,
        )
    end
    observation = task.observable
    observation isa KSliceSelection || throw(
        ArgumentError(
            "K-slice task $(task.id) requires KSliceSelection with an explicit component and band target.",
        ),
    )
    bands = observation.bands
    policy = definition.band_policy
    accepted =
        if definition.quantity in (
            QUANTITY_SECOND_HARMONIC_GENERATION,
            QUANTITY_JERK_CURRENT,
            QUANTITY_THIRD_HARMONIC_GENERATION,
            QUANTITY_LINEAR_TRANSPORT,
            QUANTITY_LINEAR_OPTICAL_RESPONSE,
            QUANTITY_ORBITAL_MAGNETIZATION,
            QUANTITY_INTRINSIC_AHC,
            QUANTITY_BERRY_CURVATURE_DIPOLE_CONDUCTIVITY,
            QUANTITY_BERRY_CURVATURE_QUADRUPOLE_CONDUCTIVITY,
        )
            bands isa AllBands && !bands.include_occupied_sum
        elseif definition.quantity == QUANTITY_HERMITIAN_CURVATURE_TENSOR
            bands isa InterbandGroups
        elseif policy == BAND_PAIR
            bands isa Transition
        elseif policy == BAND_RESOLVED
            bands isa Union{BandTargets, Subspace, Subspaces, AllBands, OccupiedBands}
        elseif policy == BAND_TARGET_GROUP
            bands isa Union{BandTargets, Subspace, Subspaces}
        elseif policy == BAND_INTERBAND_GROUPS
            bands isa InterbandGroups
        elseif policy == BAND_TRIPLE_GROUPS
            bands isa TripleGroups
        else
            false
        end
    accepted ||
        throw(ArgumentError("Band observation $(typeof(bands)) does not apply to task $(task.id)."))
    policy in (BAND_RESOLVED, BAND_ALL) ||
        !_occupied_sum_requested(bands) ||
        throw(ArgumentError("Task $(task.id) does not support an occupied sum."))
    return (;
        tensor_indices = observation.component.indices,
        band_selection = _effective_band_selection(bands),
        include_occupied_sum = _occupied_sum_requested(bands),
    )
end

const OPTICAL_TASK_QUANTITIES = (
    :second_harmonic_generation,
    :jerk_current,
    :third_harmonic_generation,
    :shift_current,
    :injection_current,
    :injection_spin_current,
    :shift_spin_current,
    :photon_drag_shift_current,
    :photon_drag_injection_current,
)
# Only these Conventional scalar geometries adopt the unregularized default.
const ZERO_REGULARIZATION_GEOMETRY_QUANTITIES = (
    :berry_curvature,
    :interband_berry_curvature,
    :interband_quantum_metric,
    :quantum_metric,
    :berry_curvature_dipole,
    :berry_curvature_quadrupole,
    :quantum_metric_dipole,
    :quantum_metric_quadrupole,
    :quantum_christoffel_symbol,
)
const EXTERNAL_METRIC_QUANTITIES = (
    :quantum_metric,
    :quantum_metric_dipole,
    :quantum_metric_quadrupole,
    :quantum_christoffel_symbol,
)
const FINITE_DIFFERENCE_GEOMETRY_QUANTITIES = (
    :berry_curvature_dipole,
    :berry_curvature_quadrupole,
    :quantum_metric_dipole,
    :quantum_metric_quadrupole,
    :quantum_christoffel_symbol,
)

# Require a finite Fermi reference and a finite nonnegative absolute temperature.
function _validate_occupation_values(fermi_energy, temperature)
    isfinite(fermi_energy) || throw(ArgumentError("fermi_energy must be finite (eV)."))
    isfinite(temperature) && temperature >= 0 ||
        throw(ArgumentError("temperature must be finite and nonnegative (K)."))
end

# Require the physical inputs used by this response and reject inapplicable parameter groups.
function _task_physics(
    task::TaskSpec,
    quantity::Symbol,
    method::Symbol,
    definition::TaskDefinition,
    observation,
)
    quantity in BERRY_MULTIPOLE_QUANTITIES && return berry_multipole_task_physics(task)
    quantity in SPECTRAL_RESPONSE_QUANTITIES &&
        return _spectral_task_physics(task, quantity, calculation_symbol(definition.calculation))
    physics = task.physics
    calculation = calculation_symbol(definition.calculation)
    if _is_band_structure(definition)
        physics isa BandParameters ||
            throw(ArgumentError("Band task $(task.id) requires BandParameters."))
        isfinite(physics.fermi_energy) || throw(ArgumentError("Band fermi_energy must be finite."))
        return (; fermi_energy = physics.fermi_energy, photon_energies = Float64[])
    elseif quantity in OPTICAL_TASK_QUANTITIES
        finite_q = quantity in (:photon_drag_shift_current, :photon_drag_injection_current)
        expected =
            quantity == :jerk_current ? JerkParameters :
            quantity == :third_harmonic_generation ? THGParameters :
            quantity == :second_harmonic_generation ? SHGParameters :
            finite_q ? FiniteQOpticalParameters : OpticalParameters
        physics isa expected || throw(ArgumentError("Task $(task.id) requires $(expected)."))
        _validate_occupation_values(physics.fermi_energy, physics.temperature)
        isempty(physics.photon_energies) &&
            throw(ArgumentError("Optical photon_energies must not be empty."))
        all(isfinite, physics.photon_energies) ||
            throw(ArgumentError("photon_energies must be finite (eV)."))
        calculation == :kslice &&
            length(physics.photon_energies) != 1 &&
            throw(ArgumentError("Optical K-slice requires exactly one photon energy."))
        finite_q &&
            ((physics.photon_momentum === nothing) == (physics.photon_momenta === nothing)) &&
            throw(ArgumentError("specify exactly one fixed or paired photon momentum axis"))
        path =
            finite_q && physics.photon_momenta !== nothing ?
            make_photon_momentum_path(physics.photon_energies, physics.photon_momenta) : nothing
        finite_q &&
            path !== nothing &&
            physics.photon_momentum !== nothing &&
            throw(ArgumentError("fixed and paired photon momenta are mutually exclusive"))
        momentum = finite_q ? something(physics.photon_momentum, (0.0, 0.0, 0.0)) : (0.0, 0.0, 0.0)
        all(isfinite, momentum) || throw(ArgumentError("photon_momentum must be finite."))
        return (;
            photon_energies = copy(physics.photon_energies),
            fermi_energy = physics.fermi_energy,
            temperature = physics.temperature,
            photon_momentum = momentum,
            photon_momentum_path = path,
        )
    end
    physics isa GeometryParameters || throw(
        ArgumentError(
            "Geometry task $(task.id) requires GeometryParameters, without optical placeholders.",
        ),
    )
    if observation.include_occupied_sum
        physics.fermi_energy !== nothing && physics.temperature !== nothing || throw(
            ArgumentError(
                "Occupied sum task $(task.id) requires explicit fermi_energy and temperature.",
            ),
        )
        _validate_occupation_values(physics.fermi_energy, physics.temperature)
    elseif physics.fermi_energy !== nothing || physics.temperature !== nothing
        throw(
            ArgumentError(
                "Task $(task.id) has no occupied-sum observable; occupation parameters do not apply.",
            ),
        )
    end
    physics.include_external &&
        !(quantity in EXTERNAL_METRIC_QUANTITIES) &&
        throw(
            ArgumentError(
                "include_external applies only to ordinary Quantum Metric and its derivatives",
            ),
        )
    allows_q = method == :geometric_loop && quantity == :shift_vector
    physics.photon_momentum === nothing ||
        allows_q ||
        throw(ArgumentError("photon_momentum does not apply to task $(task.id)."))
    momentum = something(physics.photon_momentum, (0.0, 0.0, 0.0))
    all(isfinite, momentum) || throw(ArgumentError("photon_momentum must be finite."))
    return (;
        photon_energies = Float64[],
        fermi_energy = something(physics.fermi_energy, 0.0),
        temperature = something(physics.temperature, 0.0),
        photon_momentum = momentum,
        include_external = physics.include_external,
    )
end

# Apply numerical defaults only within the task family and reject unused explicit controls.
function _resolved_task_numerical_values(
    task::TaskSpec,
    quantity::Symbol,
    method::Symbol,
    definition::TaskDefinition,
    ;
    nonorthogonal::Bool = false,
)
    quantity in BERRY_MULTIPOLE_QUANTITIES &&
        return berry_multipole_task_numerics(task, quantity; nonorthogonal)
    quantity in SPECTRAL_RESPONSE_QUANTITIES &&
        return _spectral_task_numerics(task, quantity; nonorthogonal)
    calculation = calculation_symbol(definition.calculation)
    if _is_band_structure(definition)
        numerics = resolved_numerical_values(task, quantity)
        isfinite(numerics.hermiticity_tolerance) && numerics.hermiticity_tolerance > 0 ||
            throw(ArgumentError("Invalid hermiticity_tolerance"))
        return (; band_hermiticity_tolerance = Float64(numerics.hermiticity_tolerance))
    end
    if quantity in (:jerk_current, :third_harmonic_generation)
        return third_order_numerical_values(task, quantity, definition)
    end
    if quantity == :second_harmonic_generation
        numerics = resolved_numerical_values(task, quantity; nonorthogonal)
        nonorthogonal &&
            numerics.eta_correction &&
            throw(
                ArgumentError(
                    "NONORTHOGONAL_SHG_ETA_CORRECTION_UNSUPPORTED: metric cutoff optics has no eta correction",
                ),
            )
        numerics.eta_correction isa Bool || throw(ArgumentError("eta_correction must be Bool"))
        for value in (
            numerics.broadening,
            numerics.low_frequency_broadening,
            numerics.intermediate_regularization,
        )
            isfinite(value) && value > 0 ||
                throw(ArgumentError("SHG widths must be finite and positive"))
        end
        isfinite(numerics.degeneracy_threshold) && numerics.degeneracy_threshold >= 0 ||
            throw(ArgumentError("Invalid SHG degeneracy threshold"))
        numerics.broadening_type in ("Gaussian", "Lorentzian") ||
            throw(ArgumentError("Invalid SHG broadening type"))
        physics = task.physics::SHGParameters
        physics.output in (:total, :terms, :both) ||
            throw(ArgumentError("Invalid SHG output selection"))
        physics.response in (:susceptibility, :conductivity, :both) ||
            throw(ArgumentError("Invalid SHG response selection"))
        all(>=(0), physics.photon_energies) ||
            throw(ArgumentError("SHG energies must be nonnegative"))
        return (;
            broadening = Float64(numerics.broadening),
            broadening_type = String(numerics.broadening_type),
            denominator_regularization = nonorthogonal ?
                                         Float64(numerics.denominator_regularization) :
                                         Float64(numerics.intermediate_regularization),
            shg_intermediate_regularization = Float64(numerics.intermediate_regularization),
            degeneracy_threshold = Float64(numerics.degeneracy_threshold),
            shg_low_frequency_broadening = Float64(numerics.low_frequency_broadening),
            shg_eta_correction = numerics.eta_correction,
            shg_output = physics.output,
            shg_response = physics.response,
        )
    end
    optical = quantity in OPTICAL_TASK_QUANTITIES
    numerics = something(task.numerics, Numerics())
    values = resolved_numerical_values(task, quantity; nonorthogonal)
    analytic_geometry =
        quantity in (:berry_curvature_dipole, :berry_curvature_quadrupole) &&
        values.derivative_backend == :analytic
    uses_degeneracy =
        analytic_geometry ||
        method != :conventional ||
        definition.requires_spin ||
        definition.requires_finite_q
    !uses_degeneracy &&
        :degeneracy_threshold in numerics.supplied &&
        throw(ArgumentError("degeneracy_threshold does not apply to task $(task.id)."))
    uses_fd =
        !analytic_geometry &&
        (method != :conventional || quantity in FINITE_DIFFERENCE_GEOMETRY_QUANTITIES)
    !uses_fd &&
        :finite_difference_step in numerics.supplied &&
        throw(ArgumentError("finite_difference_step does not apply to task $(task.id)."))
    if !optical && :band_window_size in numerics.supplied
        throw(
            ArgumentError(
                "Geometry tasks use explicit band observations; band_window_size does not apply.",
            ),
        )
    end
    fd = something(values.finite_difference_step, 0.0001)
    isfinite(fd) && fd > 0 ||
        throw(ArgumentError("finite_difference_step must be finite and positive."))
    for name in (:denominator_regularization, :degeneracy_threshold)
        value = getfield(values, name)
        value isa Real && isfinite(value) && value >= 0 ||
            throw(ArgumentError("$(name) must be finite and nonnegative."))
    end
    result = (;
        denominator_regularization = Float64(values.denominator_regularization),
        degeneracy_threshold = Float64(values.degeneracy_threshold),
        finite_difference_step = Float64(fd),
        band_window_size = Int(something(values.band_window_size, -1)),
    )
    if quantity in (:berry_curvature_dipole, :berry_curvature_quadrupole)
        result = merge(result, (; derivative_backend = values.derivative_backend))
    end
    if optical
        values.broadening isa Real && isfinite(values.broadening) && values.broadening > 0 ||
            throw(ArgumentError("broadening must be finite and positive (eV)."))
        values.broadening_type in ("Gaussian", "Lorentzian") ||
            throw(ArgumentError("broadening_type must be Gaussian or Lorentzian."))
        values.transition_window_factor isa Real && isfinite(values.transition_window_factor) ||
            throw(ArgumentError("transition_window_factor must be finite."))
        return merge(
            result,
            (;
                broadening = Float64(values.broadening),
                broadening_type = String(values.broadening_type),
                transition_window_factor = Float64(values.transition_window_factor),
            ),
        )
    end
    return result
end

# Validate independent third-order controls and create a concrete internal execution policy.
function third_order_numerical_values(task, quantity, definition)
    values=resolved_numerical_values(task, quantity)
    physics=task.physics
    all(x->isfinite(x)&&x>=0, physics.photon_energies) ||
        throw(ArgumentError("Third-order photon energies must be finite and nonnegative (eV)."))
    components=task.observable isa TensorComponents ? task.observable.components : ()
    if quantity==:jerk_current
        physics.projection in (:ordered, :symmetric, :antisymmetric) ||
            throw(ArgumentError("Invalid jerk projection"))
        isfinite(values.denominator_regularization) && values.denominator_regularization>0 ||
            throw(ArgumentError("JC denominator_regularization must be positive"))
        :finite_difference_step in something(task.numerics, Numerics()).supplied && throw(
            ArgumentError("JC uses analytic derivatives; finite_difference_step does not apply"),
        )
        isfinite(values.broadening) && values.broadening>0 ||
            throw(ArgumentError("Invalid broadening"))
        values.broadening_type in ("Gaussian", "Lorentzian") ||
            throw(ArgumentError("Invalid broadening_type"))
        isfinite(values.transition_window_factor) ||
            throw(ArgumentError("Invalid transition_window_factor"))
        options=ThirdOrderSettings(
            :both,
            :conductivity,
            :total,
            physics.projection,
            components,
            HarmonicFrequencyPolicy(
                values.broadening_type=="Gaussian",
                values.broadening,
                values.broadening,
                values.denominator_regularization,
            ),
            false,
            false,
        )
        return (;
            broadening = Float64(values.broadening),
            broadening_type = String(values.broadening_type),
            denominator_regularization = Float64(values.denominator_regularization),
            transition_window_factor = Float64(values.transition_window_factor),
            band_window_size = Int(something(values.band_window_size, -1)),
            third_order = options,
        )
    end
    physics.formulation in (:unregrouped, :regrouped, :both) ||
        throw(ArgumentError("Invalid formulation"))
    physics.response in (:conductivity, :susceptibility, :both) ||
        throw(ArgumentError("Invalid response"))
    physics.output in (:total, :terms, :both) || throw(ArgumentError("Invalid output"))
    values.prescription == :distribution_broadening || throw(
        ArgumentError(
            "THG supports prescription=:distribution_broadening only; causal was removed and shg_compatible must be migrated explicitly",
        ),
    )
    values.occupation_derivative_mode in (:fermi_dirac, :shg_gaussian) ||
        throw(ArgumentError("Invalid occupation_derivative_mode"))
    values.eta_correction isa Bool || throw(ArgumentError("eta_correction must be Bool"))
    values.broadening_type in ("Gaussian", "Lorentzian") ||
        throw(ArgumentError("Invalid broadening_type"))
    all(x->isfinite(x)&&x>0, (values.broadening, values.low_frequency_broadening)) ||
        throw(ArgumentError("Positive frequency widths required"))
    isfinite(values.intermediate_regularization) && values.intermediate_regularization>0 ||
        throw(ArgumentError("Positive intermediate_regularization required"))
    options=ThirdOrderSettings(
        physics.formulation,
        physics.response,
        physics.output,
        :ordered,
        components,
        HarmonicFrequencyPolicy(
            values.broadening_type=="Gaussian",
            values.broadening,
            values.low_frequency_broadening,
            values.intermediate_regularization,
        ),
        values.eta_correction,
        values.occupation_derivative_mode==:fermi_dirac,
    )
    return (;
        broadening = Float64(values.broadening),
        broadening_type = String(values.broadening_type),
        denominator_regularization = Float64(values.intermediate_regularization),
        third_order = options,
    )
end

# Attach the user task identity to all numerical validation failures before IO.
function _task_numerical_values(
    task::TaskSpec,
    quantity::Symbol,
    method::Symbol,
    definition::TaskDefinition,
    ;
    nonorthogonal::Bool = false,
)
    try
        return _resolved_task_numerical_values(task, quantity, method, definition; nonorthogonal)
    catch exception
        exception isa InterruptException && rethrow()
        throw(
            ArgumentError(
                "Numerics for task $(task.id), quantity $quantity: $(sprint(showerror, exception))",
            ),
        )
    end
end

"""Compile and validate one named task without reading model files or creating directories."""
Base.@nospecializeinfer function compile_task_config(
    cfg::TaskConfig,
    task::TaskSpec;
    native_model_input = nothing,
)
    # Share task admission across user-defined analytic callback types.
    @nospecialize native_model_input
    cfg.model isa AbstractNativeModelInput && return compile_native_task_config(cfg, task)
    occursin(r"^[A-Za-z0-9][A-Za-z0-9_-]*$", task.id) ||
        throw(ArgumentError("Invalid task id $(repr(task.id))."))
    (
        !isempty(strip(cfg.model.model_file)) ||
        !isempty(strip(cfg.model.seedname)) ||
        (
            cfg.model.real_space_operator_bundle_file !== nothing &&
            !isempty(strip(cfg.model.real_space_operator_bundle_file))
        )
    ) || throw(
        ArgumentError(
            "ModelInput requires an explicit model_file, seedname, or real_space_operator_bundle_file.",
        ),
    )
    quantity, method, calculation, definition = _public_task_identity(task, cfg.sampling)
    if native_model_input isa AnalyticKInput &&
       native_model_input.basis == :explicit &&
       !(
           quantity in (
               :berry_curvature_dipole,
               :berry_curvature_quadrupole,
               :berry_curvature_dipole_conductivity,
               :berry_curvature_quadrupole_conductivity,
           )
       )
        throw(
            ArgumentError(
                "explicit analytic connection is currently admitted only for BCD/BCQ; no overlap, metric, optical or loop support is inferred",
            ),
        )
    end
    if quantity in (:jerk_current, :third_harmonic_generation)
        cfg.execution.response_symmetry_file === nothing ||
            cfg.execution.integration_algorithm isa HAdaptiveCubature ||
            cfg.sampling isa KRegion ||
            throw(ArgumentError("JC/THG automatic symmetry reduction is unsupported"))
        (
            cfg.sampling isa KRegion ||
            cfg.sampling.spatial_dimension==3 ||
            native_physical_dimension(native_model_input) < 3
        ) || throw(ArgumentError("JC/THG requires three Cartesian axes"))
    end
    observation = _task_observation(task, definition, calculation)
    physics = _task_physics(task, quantity, method, definition, observation)
    if hasproperty(physics, :photon_momentum_path) && physics.photon_momentum_path !== nothing
        cfg.sampling isa Union{BZMesh, KRegion} &&
        cfg.execution.integration_algorithm isa UniformIntegration || throw(
            ArgumentError("paired photon momenta require UniformIntegration on BZMesh or KRegion"),
        )
        lowercase(cfg.execution.fourier_backend) == "direct" ||
            throw(ArgumentError("paired photon momenta currently require explicit Direct Fourier"))
        native_model_input === nothing ||
            native_model_input isa RealSpaceTBInput ||
            (
                native_model_input isa AnalyticKInput &&
                native_model_input.basis in (:point_orbitals, :fixed_orthonormal)
            ) ||
            throw(
                ArgumentError(
                    "paired photon momenta require an orthogonal Wannier, real-space or fixed-basis analytic model",
                ),
            )
        cfg.execution.response_symmetry_file === nothing || throw(
            ArgumentError("paired photon momenta do not yet support response-symmetry reduction"),
        )
    end
    numerics = _task_numerical_values(
        task,
        quantity,
        method,
        definition;
        nonorthogonal = native_model_input isa NonorthogonalLocalizedInput,
    )
    if get(numerics, :derivative_backend, :finite_difference) == :analytic ||
       quantity in BERRY_MULTIPOLE_QUANTITIES
        lowercase(cfg.execution.fourier_backend) == "direct" || throw(
            ArgumentError(
                "analytic BCD/BCQ currently requires explicit Direct Fourier; no implicit backend switch",
            ),
        )
    end
    case_root = resolve_case_root(cfg.model.case_root)
    output_parent =
        resolve_path(cfg.output.output_root, default_output_root(case_root); base = case_root)
    model_fields = _configuration_fields(cfg.model)
    bundle_absent =
        cfg.model.real_space_operator_bundle_file === nothing ||
        isempty(strip(cfg.model.real_space_operator_bundle_file))
    if isempty(strip(cfg.model.model_file)) && bundle_absent && !isempty(strip(cfg.model.seedname))
        seed_prefix = resolve_path(cfg.model.seedname, cfg.model.seedname; base = case_root)
        model_fields = merge(model_fields, (; model_file = seed_prefix * "_tb.dat"))
    end
    sampling_fields = _sampling_fields(cfg.sampling)
    native_physical_dimension(native_model_input) < 3 &&
        (sampling_fields = merge(sampling_fields, (; spatial_dimension = 3)))
    quantity in BERRY_MULTIPOLE_QUANTITIES &&
        (sampling_fields = merge(sampling_fields, (; spatial_dimension = 3)))
    if cfg.sampling isa KRegion && quantity in (
        :second_harmonic_generation,
        :jerk_current,
        :third_harmonic_generation,
        :linear_transport,
        :linear_optical_response,
        :orbital_magnetization,
    )
        sampling_fields = merge(sampling_fields, (; spatial_dimension = 3))
    end
    options = merge(
        model_fields,
        sampling_fields,
        _configuration_fields(cfg.execution),
        _configuration_fields(cfg.output),
        observation,
        physics,
        numerics,
        (;
            tasks = [(
                canonical_quantity_name(quantity),
                canonical_method_name(method),
                canonical_calculation_name(calculation),
            )],
            output_root = joinpath(output_parent, task.id),
            denominator_regularization_was_explicit = :denominator_regularization in
                                                      something(task.numerics, Numerics()).supplied,
            derivative_backend_was_explicit = :derivative_backend in
                                              something(task.numerics, Numerics()).supplied,
        ),
    )
    effective = EffectiveTaskConfig(; options..., native_model_input)
    validate_config(effective)
    warn_integration_domain(effective)
    return effective
end

"""Compile every task before execution; preserve request order and isolate output paths by ID."""
function compile_task_configs(cfg::TaskConfig)
    isempty(cfg.tasks) && throw(ArgumentError("TaskConfig requires at least one task."))
    ids = lowercase.([task.id for task in cfg.tasks])
    length(unique(ids)) == length(ids) || throw(ArgumentError("Task ids must be unique."))
    return EffectiveTaskConfig[compile_task_config(cfg, task) for task in cfg.tasks]
end

"""Validate the public independent-task configuration and return its normalized task identities."""
validate_config(cfg::TaskConfig) =
    [only(normalize_task_specs(effective)) for effective in compile_task_configs(cfg)]

# Summarize an explicit observation without leaking private band sentinels or dummy tensor indices.
function _task_observation_summary(task::TaskSpec, definition::TaskDefinition)
    calculation = calculation_symbol(definition.calculation)
    _is_band_structure(definition) && return (; kind = "band_spectrum")
    if calculation == :integral
        return quantity_symbol(definition.quantity) in BERRY_MULTIPOLE_QUANTITIES &&
               task.observable isa TensorComponents ?
               (; kind = "tensor_components", components = task.observable.components) :
               (; kind = "full_tensor")
    end
    observation = task.observable::KSliceSelection
    bands = observation.bands
    band_summary = if bands isa BandTargets
        (;
            kind = "individual_bands",
            bands = copy(bands.bands),
            include_occupied_sum = bands.include_occupied_sum,
        )
    elseif bands isa Subspace
        (; kind = "subspace", bands = copy(bands.bands))
    elseif bands isa Subspaces
        (; kind = "subspaces", groups = deepcopy(bands.groups))
    elseif bands isa OccupiedBands
        (; kind = "occupied_sum")
    elseif bands isa AllBands
        (; kind = "all_individual_bands", include_occupied_sum = bands.include_occupied_sum)
    elseif bands isa Transition
        (; kind = "transition", conduction = copy(bands.conduction), valence = copy(bands.valence))
    elseif bands isa InterbandGroups
        (; kind = "interband_groups", first = copy(bands.first), second = copy(bands.second))
    else
        (;
            kind = "triple_groups",
            first = copy(bands.first),
            second = copy(bands.second),
            third = copy(bands.third),
        )
    end
    return (; kind = "kslice", component = observation.component.indices, bands = band_summary)
end

"""Return the validated effective public parameters, excluding private unused placeholders; perform no IO."""
function task_parameter_summary(cfg::TaskConfig, task::TaskSpec)
    effective = compile_task_config(cfg, task)
    quantity, method, calculation, definition = _public_task_identity(task, cfg.sampling)
    optical = quantity in OPTICAL_TASK_QUANTITIES
    physical = if quantity in BERRY_MULTIPOLE_QUANTITIES
        (;
            fermi_energies = copy(task.physics.fermi_energies),
            temperature = task.physics.temperature,
            relaxation_time_fs = task.physics.relaxation_time_fs,
            integral_form = task.physics.integral_form,
        )
    elseif quantity in SPECTRAL_RESPONSE_QUANTITIES
        _spectral_task_physics(task, quantity, calculation)
    elseif _is_band_structure(definition)
        (; fermi_energy = effective.fermi_energy)
    elseif quantity in (:jerk_current, :third_harmonic_generation)
        NamedTuple{fieldnames(typeof(task.physics))}(
            Tuple(deepcopy(getfield(task.physics, n)) for n in fieldnames(typeof(task.physics))),
        )
    elseif optical
        base = (;
            photon_energies = copy(effective.photon_energies),
            fermi_energy = effective.fermi_energy,
            temperature = effective.temperature,
        )
        task.physics isa SHGParameters ?
        merge(base, (; output = effective.shg_output, response = effective.shg_response)) :
        task.physics isa FiniteQOpticalParameters ?
        merge(
            base,
            effective.photon_momentum_path === nothing ?
            (; photon_momentum = effective.photon_momentum) :
            (;
                photon_momenta = copy(effective.photon_momentum_path.photon_momenta),
                momentum_pairing = "zip",
            ),
        ) : base
    else
        base =
            effective.include_occupied_sum ?
            (; fermi_energy = effective.fermi_energy, temperature = effective.temperature) :
            NamedTuple()
        quantity in EXTERNAL_METRIC_QUANTITIES &&
            (base = merge(base, (; include_external = effective.include_external)))
        method == :geometric_loop && quantity == :shift_vector ?
        merge(base, (; photon_momentum = effective.photon_momentum)) : base
    end
    numerical = if quantity in BERRY_MULTIPOLE_QUANTITIES
        resolved_numerical_values(task, quantity)
    elseif quantity in (:jerk_current, :third_harmonic_generation)
        resolved_numerical_values(task, quantity)
    elseif quantity in SPECTRAL_RESPONSE_QUANTITIES
        _spectral_task_numerics(
            task,
            quantity;
            nonorthogonal = effective.native_model_input isa NonorthogonalLocalizedInput,
        )
    elseif quantity == :second_harmonic_generation
        merge(
            (;
                broadening = effective.broadening,
                broadening_type = effective.broadening_type,
                low_frequency_broadening = effective.shg_low_frequency_broadening,
                intermediate_regularization = effective.shg_intermediate_regularization,
                eta_correction = effective.shg_eta_correction,
                degeneracy_threshold = effective.degeneracy_threshold,
            ),
            effective.native_model_input isa NonorthogonalLocalizedInput ?
            (; denominator_regularization = effective.denominator_regularization) :
            NamedTuple(),
        )
    elseif _is_band_structure(definition)
        (; hermiticity_tolerance = effective.band_hermiticity_tolerance)
    else
        base = (; denominator_regularization = effective.denominator_regularization)
        analytic_geometry =
            quantity in (:berry_curvature_dipole, :berry_curvature_quadrupole) &&
            effective.derivative_backend == :analytic
        if analytic_geometry ||
           method != :conventional ||
           (
               definition.requires_spin &&
               !(quantity in (:shift_spin_current, :injection_spin_current))
           ) ||
           definition.requires_finite_q
            base = merge(base, (; degeneracy_threshold = effective.degeneracy_threshold))
        end
        if !analytic_geometry &&
           (method != :conventional || quantity in FINITE_DIFFERENCE_GEOMETRY_QUANTITIES)
            base = merge(base, (; finite_difference_step = effective.finite_difference_step))
        end
        if quantity in (:berry_curvature_dipole, :berry_curvature_quadrupole)
            base = merge(base, (; derivative_backend = effective.derivative_backend))
        end
        if optical
            base = merge(
                base,
                (;
                    broadening = effective.broadening,
                    broadening_type = effective.broadening_type,
                    transition_window_factor = effective.transition_window_factor,
                    band_window_size = effective.band_window_size,
                ),
            )
        end
        base
    end
    return (;
        id = task.id,
        quantity = canonical_quantity_name(quantity),
        method = canonical_method_name(method),
        calculation = canonical_calculation_name(calculation),
        physics = physical,
        numerics = numerical,
        explicit_numerics = something(task.numerics, Numerics()).values,
        observable = _task_observation_summary(task, definition),
        output_root = effective.output_root,
    )
end

"""Return the effective public parameter summary for a task at its original request index."""
task_parameter_summary(cfg::TaskConfig, index::Integer) =
    task_parameter_summary(cfg, cfg.tasks[index])
