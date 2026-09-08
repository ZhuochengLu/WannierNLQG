const HAMILTONIAN_SYMMETRY_SPEC = RealSpaceOperatorSymmetrySpec(REAL_SPACE_HAMILTONIAN, 0, 1, 1)
const POSITION_SYMMETRY_SPEC = RealSpaceOperatorSymmetrySpec(REAL_SPACE_POSITION, 1, -1, 1)
const SPIN_SYMMETRY_SPEC = RealSpaceOperatorSymmetrySpec(REAL_SPACE_SPIN, 1, 1, -1)
const SPIN_HAMILTONIAN_SYMMETRY_SPEC =
    RealSpaceOperatorSymmetrySpec(REAL_SPACE_SPIN_TIMES_HAMILTONIAN, 1, 1, -1)
const SPIN_POSITION_SYMMETRY_SPEC =
    RealSpaceOperatorSymmetrySpec(REAL_SPACE_SPIN_TIMES_POSITION, 2, -1, -1)
const SPIN_HAMILTONIAN_POSITION_SYMMETRY_SPEC =
    RealSpaceOperatorSymmetrySpec(REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION, 2, -1, -1)
const HAMILTONIAN_WEIGHTED_CONNECTION_SYMMETRY_SPEC =
    RealSpaceOperatorSymmetrySpec(REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION, 1, -1, 1)
const HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP_SYMMETRY_SPEC = RealSpaceOperatorSymmetrySpec(
    REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP,
    1,
    1,
    -1,
)
const DERIVATIVE_OVERLAP_TENSOR_SYMMETRY_SPEC =
    RealSpaceOperatorSymmetrySpec(REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR, 2, 1, 1)
const AXIAL_DERIVATIVE_OVERLAP_SYMMETRY_SPEC =
    RealSpaceOperatorSymmetrySpec(REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP, 1, 1, -1)
const SYMMETRIC_DERIVATIVE_OVERLAP_SYMMETRY_SPEC =
    RealSpaceOperatorSymmetrySpec(REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP, 2, 1, 1)

const WANNIER_DERIVATIVE_SYMMETRY_SPECS = Dict(
    REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION => HAMILTONIAN_WEIGHTED_CONNECTION_SYMMETRY_SPEC,
    REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP =>
        HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP_SYMMETRY_SPEC,
    REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR => DERIVATIVE_OVERLAP_TENSOR_SYMMETRY_SPEC,
    REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP => AXIAL_DERIVATIVE_OVERLAP_SYMMETRY_SPEC,
    REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP => SYMMETRIC_DERIVATIVE_OVERLAP_SYMMETRY_SPEC,
)

const SPIN_FAMILY_SYMMETRY_SPECS = Dict(
    REAL_SPACE_SPIN => SPIN_SYMMETRY_SPEC,
    REAL_SPACE_SPIN_TIMES_HAMILTONIAN => SPIN_HAMILTONIAN_SYMMETRY_SPEC,
    REAL_SPACE_SPIN_TIMES_POSITION => SPIN_POSITION_SYMMETRY_SPEC,
    REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION => SPIN_HAMILTONIAN_POSITION_SYMMETRY_SPEC,
)

const SYMMETRIZATION_OPERATOR_PROFILE_ASSEMBLY_ALGORITHM_VERSION = "WannierNLQG.symmetrization_operator_profile/1.0"
const SYMMETRIZATION_PAIR_WIGNER_SEITZ_STORAGE_POLICY = "PAIR_DEPENDENT_MINIMUM_DISTANCE_UNIT_DEGENERACY"

const SPIN_VELOCITY_OPERATOR_KINDS = (
    REAL_SPACE_SPIN,
    REAL_SPACE_SPIN_TIMES_HAMILTONIAN,
    REAL_SPACE_SPIN_TIMES_POSITION,
    REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION,
)

# Normalize one required Julia path at workflow entry.
function _required_workflow_path(path::AbstractString, field::AbstractString)
    isempty(strip(path)) && throw(ArgumentError("$(field) must not be empty"))
    return normpath(abspath(path))
end

# Normalize one optional Julia path at workflow entry.
function _optional_workflow_path(path::Union{Nothing, AbstractString}, field::AbstractString)
    path === nothing && return nothing
    return _required_workflow_path(path, field)
end

# Require one finite strictly positive tolerance.
function _positive_tolerance(value::Float64, field::AbstractString)
    isfinite(value) && value > 0.0 || throw(ArgumentError("$(field) must be finite and positive"))
    return value
end

# Require one finite nonnegative tolerance.
function _nonnegative_tolerance(value::Float64, field::AbstractString)
    isfinite(value) && value >= 0.0 ||
        throw(ArgumentError("$(field) must be finite and nonnegative"))
    return value
end

# Validate configured operation indices before reading scientific inputs.
function _validate_configured_operation_indices(configured::Union{Nothing, Vector{Int}})
    configured === nothing && return nothing
    isempty(configured) && throw(ArgumentError("operation_indices must not be empty"))
    length(unique(configured)) == length(configured) ||
        throw(ArgumentError("operation_indices contains duplicates"))
    all(index -> index >= 1, configured) ||
        throw(ArgumentError("operation_indices uses one-based Julia indices"))
    return nothing
end

# Validate selected indices against the detected operation count.
function _selected_operation_indices(
    configured::Union{Nothing, Vector{Int}},
    num_operations::Int;
    prevalidated::Bool = false,
)
    prevalidated || _validate_configured_operation_indices(configured)
    selected_operation_indices =
        configured === nothing ? collect(1:num_operations) : copy(configured)
    all(index -> 1 <= index <= num_operations, selected_operation_indices) ||
        throw(ArgumentError("operation_indices uses one-based Julia indices and is out of range"))
    return selected_operation_indices
end

# Validate exactly one explicitly selected magnetic-moment provider.
function _validate_magnetic_config(magnetic::Union{Nothing, MagneticMomentConfig})
    magnetic === nothing && return nothing
    _positive_tolerance(magnetic.mapping_tolerance, "magnetic.mapping_tolerance")
    if magnetic.source in (:qe, :vasp)
        magnetic.file === nothing &&
            throw(ArgumentError("magnetic source=$(magnetic.source) requires file"))
        _required_workflow_path(magnetic.file, "magnetic.file")
        magnetic.moments_cartesian === nothing || throw(
            ArgumentError("magnetic source=$(magnetic.source) does not accept moments_cartesian"),
        )
    elseif magnetic.source == :cartesian
        magnetic.file === nothing ||
            throw(ArgumentError("magnetic source=:cartesian does not accept file"))
        magnetic.collinear_axis_cartesian === nothing || throw(
            ArgumentError("magnetic source=:cartesian does not accept collinear_axis_cartesian"),
        )
        magnetic.moments_cartesian === nothing &&
            throw(ArgumentError("magnetic source=:cartesian requires moments_cartesian"))
        size(magnetic.moments_cartesian, 1) == 3 ||
            throw(ArgumentError("moments_cartesian must have size (3, num_atoms)"))
        all(isfinite, magnetic.moments_cartesian) ||
            throw(ArgumentError("moments_cartesian contains non-finite values"))
    else
        throw(ArgumentError("magnetic.source must be :qe, :vasp, or :cartesian"))
    end
    return nothing
end

# Load exactly one explicitly selected magnetic-moment provider.
function _configured_magnetic_moments(
    magnetic::Union{Nothing, MagneticMomentConfig},
    input::WannierWinData,
)
    magnetic === nothing && return nothing
    axis =
        magnetic.collinear_axis_cartesian === nothing ? nothing :
        collect(magnetic.collinear_axis_cartesian)
    moments = if magnetic.source == :qe
        path = _required_workflow_path(something(magnetic.file), "magnetic.file")
        read_qe_magnetic_moments(
            path,
            input;
            collinear_axis_cartesian = axis,
            tolerance = magnetic.mapping_tolerance,
        )
    elseif magnetic.source == :vasp
        path = _required_workflow_path(something(magnetic.file), "magnetic.file")
        read_vasp_magnetic_moments(path, input; collinear_axis_cartesian = axis)
    else
        read_config_magnetic_moments(something(magnetic.moments_cartesian), input)
    end
    maximum(abs, moments) > 0.0 || throw(
        ArgumentError("explicit magnetic source contains only zero moments; omit magnetic instead"),
    )
    return moments
end

# Infer one complete operator profile from explicitly supplied auxiliary inputs.
function _configured_operator_families(config::SymmetrizationConfig)
    has_checkpoint = config.chk_file !== nothing
    has_eigenvalues = config.eig_file !== nothing
    has_overlaps = config.mmn_file !== nothing
    has_spin = config.spn_file !== nothing
    has_eigenvalues == has_overlaps ||
        throw(ArgumentError("eig_file and mmn_file must be provided together"))
    (has_eigenvalues || has_spin) &&
        !has_checkpoint &&
        throw(ArgumentError("derivative or spin inputs require chk_file"))
    has_checkpoint &&
        !(has_eigenvalues || has_spin) &&
        throw(ArgumentError("chk_file alone does not define a complete operator profile"))
    has_eigenvalues &&
        has_spin &&
        throw(
            ArgumentError(
                "LEGACY_FULL_PROFILE_REMOVED: schema-6 :full requires formal uIu/uHu/sIu/sHu " *
                "generators and provenance; use the Wannierization profile=:full workflow",
            ),
        )
    profile = if !has_checkpoint
        :hamiltonian_position
    elseif has_eigenvalues
        :derivative
    else
        :hamiltonian_position_spin
    end
    selected_operator_kinds = collect(OPERATOR_PROFILE_INVENTORIES[profile])
    derivative_operator_kinds =
        [kind for kind in WANNIER_DERIVATIVE_OPERATOR_KINDS if kind in selected_operator_kinds]
    spin_operator_kinds =
        [kind for kind in SPIN_VELOCITY_OPERATOR_KINDS if kind in selected_operator_kinds]
    velocity_requested = any(kind -> kind != REAL_SPACE_SPIN, spin_operator_kinds)
    return (
        profile = profile,
        selected_operator_kinds = selected_operator_kinds,
        derivative = derivative_operator_kinds,
        spin = spin_operator_kinds,
        spin_velocity = velocity_requested,
    )
end

# Reject output collisions and existing outputs before scientific input is read.
function _validate_output_paths(config::SymmetrizationConfig, input_paths, output_paths)
    normalized_outputs = [path for path in output_paths if path !== nothing]
    length(unique(normalized_outputs)) == length(normalized_outputs) ||
        throw(ArgumentError("configured output paths must be distinct"))
    any(path -> path in input_paths, normalized_outputs) &&
        throw(ArgumentError("an output path must not overwrite a scientific input"))
    if !config.overwrite
        for path in normalized_outputs
            ispath(path) && throw(ArgumentError("refusing to overwrite output: $(path)"))
        end
    end
    return nothing
end

# Validate the complete unified workflow before reading scientific input files.
function _validate_symmetrization_config(config::SymmetrizationConfig)
    families = _configured_operator_families(config)
    _positive_tolerance(config.symmetry_tolerance, "symmetry_tolerance")
    _positive_tolerance(config.projection_tolerance, "projection_tolerance")
    _positive_tolerance(config.representation_tolerance, "representation_tolerance")
    _nonnegative_tolerance(config.support_tolerance, "support_tolerance")
    _positive_tolerance(config.wigner_seitz_tolerance, "wigner_seitz_tolerance")
    config.wigner_seitz_search_size >= 1 ||
        throw(ArgumentError("wigner_seitz_search_size must be positive"))
    config.wannier_center_policy in (:symmetrize, :validate, :keep_input) ||
        throw(ArgumentError("wannier_center_policy must be :symmetrize, :validate, or :keep_input"))
    _positive_tolerance(config.wannier_center_tolerance, "wannier_center_tolerance")
    config.real_space_replica_policy in (:input, :minimum_distance) ||
        throw(ArgumentError("real_space_replica_policy must be :input or :minimum_distance"))
    _positive_tolerance(config.roundtrip_tolerance, "roundtrip_tolerance")
    _nonnegative_tolerance(config.covariance_tolerance, "covariance_tolerance")
    _nonnegative_tolerance(config.idempotence_tolerance, "idempotence_tolerance")
    config.cutoff === nothing || _nonnegative_tolerance(config.cutoff, "cutoff")
    _validate_configured_operation_indices(config.operation_indices)
    _validate_magnetic_config(config.magnetic)

    win_path = _required_workflow_path(config.win_file, "win_file")
    tb_path = _required_workflow_path(config.tb_file, "tb_file")
    isfile(win_path) || throw(ArgumentError("win_file does not exist: $(win_path)"))
    isfile(tb_path) || throw(ArgumentError("tb_file does not exist: $(tb_path)"))
    output_tb = _required_workflow_path(config.output_tb_file, "output_tb_file")
    bundle_path = _required_workflow_path(
        config.output_real_space_operator_bundle_file,
        "output_real_space_operator_bundle_file",
    )
    report = if config.report_json_file === nothing
        joinpath(dirname(bundle_path), "wannier90_symmetrization.json")
    else
        _required_workflow_path(config.report_json_file, "report_json_file")
    end
    checksums = joinpath(dirname(bundle_path), "SHA256SUMS")
    needs_checkpoint = !isempty(families.derivative) || !isempty(families.spin)
    needs_eigenvalues_and_overlaps = !isempty(families.derivative) || families.spin_velocity
    chk_path = if needs_checkpoint
        config.chk_file === nothing && throw(ArgumentError("chk_file is required"))
        _required_workflow_path(config.chk_file, "chk_file")
    else
        config.chk_file === nothing ||
            throw(ArgumentError("chk_file requires derivative or spin operators"))
        nothing
    end
    eig_path, mmn_path = if needs_eigenvalues_and_overlaps
        config.eig_file === nothing && throw(ArgumentError("eig_file is required"))
        config.mmn_file === nothing && throw(ArgumentError("mmn_file is required"))
        (
            _required_workflow_path(config.eig_file, "eig_file"),
            _required_workflow_path(config.mmn_file, "mmn_file"),
        )
    else
        config.eig_file === nothing ||
            throw(ArgumentError("eig_file requires derivative or spin-velocity operators"))
        config.mmn_file === nothing ||
            throw(ArgumentError("mmn_file requires derivative or spin-velocity operators"))
        (nothing, nothing)
    end
    spn_path = if isempty(families.spin)
        config.spn_file === nothing ||
            throw(ArgumentError("spn_file requires a selected spin operator"))
        nothing
    else
        config.spn_file === nothing && throw(ArgumentError("spin operators require spn_file"))
        _required_workflow_path(config.spn_file, "spn_file")
    end
    magnetic_input =
        config.magnetic === nothing ? nothing :
        _optional_workflow_path(config.magnetic.file, "magnetic.file")
    input_paths = [win_path, tb_path]
    chk_path === nothing || push!(input_paths, chk_path)
    eig_path === nothing || push!(input_paths, eig_path)
    mmn_path === nothing || push!(input_paths, mmn_path)
    spn_path === nothing || push!(input_paths, spn_path)
    magnetic_input === nothing || push!(input_paths, magnetic_input)
    for path in input_paths
        isfile(path) || throw(ArgumentError("configured scientific input does not exist: $(path)"))
    end
    output_paths = (output_tb, bundle_path, report, checksums)
    _validate_output_paths(config, input_paths, output_paths)
    return (
        families = families,
        win = win_path,
        tb = tb_path,
        chk = chk_path,
        eig = eig_path,
        mmn = mmn_path,
        spn = spn_path,
        output_tb = output_tb,
        operator_bundle = bundle_path,
        report = report,
        checksums = checksums,
    )
end

# Verify that the TB model agrees with the WIN-authoritative structure.
function _validate_tb_against_win(
    model::TightBindingModel,
    input::WannierWinData;
    tolerance::Float64,
)
    model.num_orbitals == input.num_wannier ||
        throw(ArgumentError("TB num_orbitals does not match WIN num_wann"))
    isapprox(model.lattice, input.lattice; atol = tolerance, rtol = 0.0) ||
        throw(ArgumentError("TB lattice does not match the WIN-authoritative lattice"))
    return nothing
end

# Build WIN, model, operations, basis, and representation once for one config.
function _build_symmetrization_context(config::SymmetrizationConfig, paths)
    input = read_wannier_win(paths.win)
    input.mp_grid === nothing && throw(ArgumentError("WIN input must define mp_grid"))
    model = read_wannier_tb(paths.tb)
    _validate_tb_against_win(model, input; tolerance = config.projection_tolerance)
    magnetic_moments = _configured_magnetic_moments(config.magnetic, input)
    structure = crystal_structure(input; magnetic_moments_cartesian = magnetic_moments)
    operations = detect_tb_compatibility_symmetry_operations(
        structure;
        include_time_reversal = config.include_time_reversal,
        symmetry_tolerance = config.symmetry_tolerance,
    )
    selected_operation_indices = _selected_operation_indices(
        config.operation_indices,
        length(operations);
        prevalidated = true,
    )
    basis = build_wannier_projection_basis(input; tolerance = config.projection_tolerance)
    plan = build_wannier_symmetry_plan(
        basis,
        operations;
        operation_indices = selected_operation_indices,
        tolerance = config.representation_tolerance,
    )
    projection = RealSpaceProjectionContext(plan)
    return (
        input = input,
        model = model,
        operations = operations,
        basis = basis,
        plan = plan,
        projection = projection,
    )
end
