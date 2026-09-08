# Remove Wannier90/Fortran inline comments before parsing one mesh line.
function _strip_wannierization_win_comment(line::AbstractString)
    return strip(first(split(first(split(String(line), '!'; limit = 2)), '#'; limit = 2)))
end

# Parse the full-BZ mesh geometry required by symmetry-free Wannierization.
function _read_wannierization_win_mesh(filename::AbstractString)
    isfile(filename) || throw(ArgumentError("WIN file does not exist: $(filename)"))
    lines = readlines(filename)
    mp_grid = nothing
    lattice_lines = String[]
    kpoint_lines = String[]
    active_block = nothing
    for raw_line in lines
        line = _strip_wannierization_win_comment(raw_line)
        isempty(line) && continue
        begin_match = match(r"(?i)^begin\s+([A-Za-z0-9_]+)\s*$", line)
        if begin_match !== nothing
            active_block === nothing || throw(ArgumentError("nested WIN blocks are not supported"))
            active_block = lowercase(begin_match.captures[1])
            continue
        end
        end_match = match(r"(?i)^end\s+([A-Za-z0-9_]+)\s*$", line)
        if end_match !== nothing
            active_block == lowercase(end_match.captures[1]) ||
                throw(ArgumentError("WIN block end does not match its begin line"))
            active_block = nothing
            continue
        end
        if active_block == "unit_cell_cart"
            push!(lattice_lines, line)
        elseif active_block == "kpoints"
            push!(kpoint_lines, line)
        elseif active_block === nothing && occursin('=', line)
            key, value = split(line, '='; limit = 2)
            lowercase(strip(key)) == "mp_grid" || continue
            mp_grid === nothing || throw(ArgumentError("WIN file defines mp_grid more than once"))
            tokens = split(replace(strip(value), ',' => ' '))
            length(tokens) == 3 || throw(ArgumentError("mp_grid must contain three integers"))
            values = Tuple(parse.(Int, tokens))
            all(>(0), values) || throw(ArgumentError("mp_grid entries must be positive"))
            mp_grid = (values[1], values[2], values[3])
        end
    end
    active_block === nothing || throw(ArgumentError("WIN file contains an unterminated block"))
    mp_grid === nothing && throw(ArgumentError("WIN file must define mp_grid"))

    length(lattice_lines) in (3, 4) ||
        throw(ArgumentError("unit_cell_cart must contain three vectors and an optional unit line"))
    length_factor = 1.0
    if length(lattice_lines) == 4
        unit = lowercase(strip(first(lattice_lines)))
        length_factor =
            unit in ("ang", "angstrom", "angstroms", "a") ? 1.0 :
            unit in ("bohr", "bohrs", "au", "a.u.") ? 0.529177210903 :
            throw(ArgumentError("unsupported unit_cell_cart unit $(repr(unit))"))
        lattice_lines = lattice_lines[2:end]
    end
    lattice = zeros(Float64, 3, 3)
    for row in 1:3
        tokens = split(lattice_lines[row])
        length(tokens) == 3 || throw(ArgumentError("unit_cell_cart row $(row) is invalid"))
        values = parse.(Float64, replace.(tokens, 'D' => 'E', 'd' => 'e'))
        all(isfinite, values) || throw(ArgumentError("unit_cell_cart contains non-finite data"))
        lattice[row, :] .= length_factor .* values
    end
    abs(det(lattice)) > 1.0e-12 || throw(ArgumentError("WIN lattice is singular"))

    isempty(kpoint_lines) && throw(ArgumentError("WIN file must contain begin kpoints"))
    kpoints = zeros(Float64, length(kpoint_lines), 3)
    for (index, line) in enumerate(kpoint_lines)
        tokens = split(line)
        length(tokens) == 3 || throw(ArgumentError("k-point row $(index) is invalid"))
        values = parse.(Float64, replace.(tokens, 'D' => 'E', 'd' => 'e'))
        all(isfinite, values) || throw(ArgumentError("WIN k-points contain non-finite data"))
        kpoints[index, :] .= values
    end
    prod(something(mp_grid)) == size(kpoints, 1) ||
        throw(ArgumentError("WIN k-point count does not match mp_grid"))
    return (
        lattice = lattice,
        reciprocal_lattice = 2.0 * pi * inv(lattice)',
        mp_grid = something(mp_grid),
        kpoints_fractional = kpoints,
    )
end

# Build the identity-only structural representation used by symmetry-free runs.
function _identity_band_representation(
    config::Union{SymmetryAdaptedWannierizationConfig, BandRepresentationPreparationConfig},
    basis::WannierProjectionBasis,
    eig::WannierEIG,
)
    input = config isa SymmetryAdaptedWannierizationConfig ? config.input : config
    geometry = _read_wannierization_win_mesh(input.win_file)
    eig.num_kpts == size(geometry.kpoints_fractional, 1) ||
        throw(ArgumentError("EIG and WIN k-point counts disagree"))
    num_bands = eig.num_bands
    num_kpoints = eig.num_kpts
    identity_operation =
        SymmetryOperation(Matrix{Int}(I, 3, 3), zeros(Float64, 3), Matrix{Float64}(I, 3, 3), false)
    sewing = zeros(ComplexF64, num_bands, num_bands, 1, num_kpoints)
    for kpoint in 1:num_kpoints
        sewing[:, :, 1, kpoint] .= Matrix{ComplexF64}(I, num_bands, num_bands)
    end
    labels = repeat(reshape(collect(1:num_bands), :, 1), 1, num_kpoints)
    backend_key = band_sewing_backend_key(input.sewing_backend)
    augmentation_metric = input.sewing_backend isa AugmentationAwareSewing
    return BandRepresentation(
        "1.16",
        :wannier90_ordinary,
        basis.spinor,
        geometry.lattice,
        geometry.reciprocal_lattice,
        geometry.mp_grid,
        geometry.kpoints_fractional,
        eig.data,
        [identity_operation],
        reshape(collect(1:num_kpoints), 1, num_kpoints),
        zeros(Int, 3, 1, num_kpoints),
        sewing,
        labels,
        collect(1:num_kpoints),
        collect(1:num_kpoints),
        ones(Int, num_kpoints);
        conventions = Dict(
            "requested_wannierization_mode" => String(input.wannierization_mode),
            "effective_wannierization_mode" => "ordinary",
            "representation_source" => "identity",
            "symmetry_constraints_applied" => "false",
            "kpoint_authority" => "WIN_full_BZ",
            "band_block_policy" => "singleton",
            "sewing_backend" => backend_key,
            "sewing_metric" => augmentation_metric ? "paw_s_identity_operation" : "identity",
            "sewing_role" => "identity_only_no_symmetry",
            "augmentation_metric_role" =>
                augmentation_metric ? "ordinary_wannierization_input_metric" : "not_applicable",
            "physical_overlap_available" => "false",
            "symmetry_tolerance" => string(input.symmetry_tolerance),
            "symmetry_tolerance_status" => "NOT_APPLICABLE",
        ),
    )
end

"""Reject a supplied no-symmetry artifact unless it is the canonical full-BZ identity."""
function _validate_no_symmetry_identity_representation(
    representation::BandRepresentation,
    tolerance::Float64,
)
    representation.schema_version == "1.0" &&
        validate_unified_representation_mode_contract(representation)
    representation.schema_version in (
        "1.0",
        "1.4",
        "1.5",
        "1.6",
        "1.7",
        "1.8",
        "1.9",
        "1.10",
        "1.11",
        "1.12",
        "1.13",
        "1.14",
        "1.15",
        "1.16",
        "1.17",
    ) || throw(
        ArgumentError(
            "wannierization_mode=:ordinary requires a supported sealed identity representation",
        ),
    )
    length(representation.operations) == 1 || throw(
        ArgumentError("no-symmetry identity representation must contain exactly one operation"),
    )
    operation = only(representation.operations)
    !operation.antiunitary || throw(ArgumentError("no-symmetry identity operation must be unitary"))
    operation.rotation_fractional == Matrix{Int}(I, 3, 3) ||
        throw(ArgumentError("no-symmetry fractional operation must be identity"))
    maximum(abs, operation.translation_fractional; init = 0.0) <= tolerance ||
        throw(ArgumentError("no-symmetry identity operation must have zero translation"))
    maximum(abs, operation.rotation_cartesian - Matrix{Float64}(I, 3, 3); init = 0.0) <=
    tolerance || throw(ArgumentError("no-symmetry Cartesian operation must be identity"))
    num_bands, num_kpoints = size(representation.energies_ev)
    representation.kpoint_map == reshape(collect(1:num_kpoints), 1, num_kpoints) ||
        throw(ArgumentError("no-symmetry k-point action must map every full-BZ point to itself"))
    all(iszero, representation.reciprocal_shifts) ||
        throw(ArgumentError("no-symmetry identity action must have zero reciprocal shifts"))
    representation.irreducible_indices == collect(1:num_kpoints) &&
    representation.full_to_irreducible == collect(1:num_kpoints) &&
    representation.full_to_operation == ones(Int, num_kpoints) ||
        throw(ArgumentError("no-symmetry identity representation must retain the complete full BZ"))
    expected_labels = repeat(reshape(collect(1:num_bands), :, 1), 1, num_kpoints)
    representation.band_block_labels == expected_labels ||
        throw(ArgumentError("no-symmetry identity representation must use singleton band blocks"))
    identity_bands = Matrix{ComplexF64}(I, num_bands, num_bands)
    for kpoint in 1:num_kpoints
        residual = maximum(
            abs,
            @view(representation.sewing_matrices[:, :, 1, kpoint]) - identity_bands;
            init = 0.0,
        )
        residual <= tolerance || throw(
            ArgumentError(
                "no-symmetry identity sewing failed at k-point $(kpoint): residual=$(residual)",
            ),
        )
    end
    return nothing
end

# Construct the dimension-only identity target plan without orbital symmetry data.
function _identity_wannier_plan(num_wannier::Int, operation::SymmetryOperation)
    matrices = zeros(ComplexF64, num_wannier, num_wannier, 1)
    matrices[:, :, 1] .= Matrix{ComplexF64}(I, num_wannier, num_wannier)
    return WannierSymmetryPlan([operation], matrices, zeros(Int, 3, num_wannier, 1))
end

# Supply solver bookkeeping without evaluating representation compatibility.
function _no_symmetry_compatibility_contract(representation::BandRepresentation, tolerance::Float64)
    product_table = build_representation_product_table(
        representation.operations,
        representation.spinor;
        tolerance,
    )
    diagnostics = [
        WannierizationDiagnostic(
            :SYMMETRY_CONSTRAINTS_DISABLED,
            :info,
            "space-group, magnetic-group, and antiunitary constraints are not applied",
        ),
    ]
    zeros4 = (0.0, 0.0, 0.0, 0.0)
    return RepresentationCompatibilityReport(
        "1.3",
        true,
        true,
        tolerance,
        product_table,
        zeros4,
        zeros4,
        zeros4,
        empty_group_law_worst_cases(),
        empty_group_law_worst_cases(),
        0.0,
        0.0,
        0.0,
        representation_static_sha256(representation),
        diagnostics,
        :not_applicable,
        GATE_NOT_EVALUATED,
        REPRESENTATION_UNDETERMINED,
        NaN,
        nothing,
        nothing,
        :analytic,
    )
end
