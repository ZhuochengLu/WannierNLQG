const VASP_PAW_MATRIX_ELEMENT_SCHEMA = "WannierNLQG.vasp_paw_matrix_elements"
const VASP_PAW_MATRIX_ELEMENT_SCHEMA_VERSION = "1.0"
const VASP_PROJECTION_BOHR_ANGSTROM = 0.529177249
const VASP_PROJECTION_RYDBERG_EV = 13.605826
const VASP_PROJECTION_HSQDTM_EV_ANGSTROM2 =
    VASP_PROJECTION_RYDBERG_EV * VASP_PROJECTION_BOHR_ANGSTROM^2
const VASP_PROJECTION_RADIAL_POINTS = 1000
const VASP_PROJECTION_RADIAL_START_ANGSTROM = 0.00002
const VASP_PROJECTION_RADIAL_END_ANGSTROM = 200.0
const VASP_PROJECTION_RADIAL_LOG_STEP = 0.025
const VASP_PROJECTION_PRINT_TOLERANCE = 5.1e-4

"""One ordered VASP LOCPROJ row resolved to its full-precision WIN trial."""
struct VASPProjectionEntry
    principal_quantum_number::Int
    angular_momentum::Int
    magnetic_index::Int
    radial_scale_inverse_angstrom::Float64
    center_fractional::NTuple{3, Float64}
    center_integer_translation::NTuple{3, Int}
    local_x_cartesian::NTuple{3, Float64}
    local_z_cartesian::NTuple{3, Float64}
    spin_index::Int
    spin_quantization_axis::NTuple{3, Float64}
    wannier_index::Int
end

"""
Typed VASP localized-projection contract for native PAW AMN construction.

The WIN file owns full-precision centers, local axes, orbital order, and the
Wannier column index. The same-run OUTCAR owns the VASP version, printed
LOCPROJ row order, radial selector, and spin quantization axis. Centers are
stored in VASP's `[-0.5,0.5)` image. The contract is read-only and never enters
finite-b MMN or band-sewing construction.
"""
struct VASPProjectionContract
    vasp_version::VersionNumber
    cutoff_ev::Float64
    radial_backend::Symbol
    entries::Vector{VASPProjectionEntry}
end

"""Per-trial PAW-metric normalization evidence indexed as `(wannier,kpoint)`."""
struct VASPTrialNormalizationDiagnostics
    factors::Matrix{Float64}
    pseudo_norms::Matrix{Float64}
    augmentation_norms::Matrix{Float64}
    normalized_residuals::Matrix{Float64}
end

"""Audit-only full-parent evidence retained beside authoritative target metrics."""
struct VASPPAWParentAudit
    generalized_norm_max_absolute::Float64
    generalized_norm_worst::NTuple{3, Int}
    mmn_parity::Union{Nothing, VASPPAWArrayParityMetrics}
    amn_parity::Union{Nothing, VASPPAWArrayParityMetrics}
    amn_max_principal_angle_rad::Float64
    amn_projector_max_absolute::Float64
    amn_minimum_rank::Int
    amn_worst_condition::Float64
    finite::Bool
    status::Symbol
end

"""Compact uniform-grid cubic spline matching VASP's `SPLCOF(...,Y1P=0)`."""
struct VASPProjectionRadialSpline
    grid::Vector{Float64}
    values::Vector{Float64}
    linear::Vector{Float64}
    quadratic::Vector{Float64}
    cubic::Vector{Float64}
end

const _VASP_PROJECTION_RADIAL_SPLINES =
    Dict{Tuple{Int, Int, UInt64, UInt64}, VASPProjectionRadialSpline}()
const _VASP_PROJECTION_RADIAL_SPLINE_LOCK = ReentrantLock()

# Reduce a WIN center to the exact periodic image used by VASP LOCPROJ.
function _vasp_projection_wrapped_center(center::AbstractVector{<:Real})
    length(center) == 3 || throw(ArgumentError("projection center must have length three"))
    wrapped = mod.(Float64.(center) .+ 0.5, 1.0) .- 0.5
    translation = round.(Int, wrapped .- Float64.(center))
    return Tuple(wrapped), Tuple(translation)
end

# Return VASP's Euler/SU(2) columns for local spin up/down along one axis.
function _vasp_projection_spinor_rotation(axis)
    values = Float64.(collect(axis))
    length(values) == 3 && all(isfinite, values) && norm(values) > 0.0 ||
        throw(ArgumentError("VASP_PAW_PROJECTION_CONTRACT_MISMATCH: invalid spin_qaxis"))
    values ./= norm(values)
    alpha = atan(values[2], values[1])
    beta = acos(clamp(values[3], -1.0, 1.0))
    cosine = cos(beta / 2.0)
    sine = sin(beta / 2.0)
    negative_phase = cis(-alpha / 2.0)
    positive_phase = cis(alpha / 2.0)
    return ComplexF64[
        cosine * negative_phase -sine * negative_phase
        sine * positive_phase cosine * positive_phase
    ]
end

# Reject rounded OUTCAR axes whose exact direction cannot be recovered safely.
function _vasp_projection_axis_is_exactly_recoverable(axis::AbstractVector{<:Real})
    maximum_component = maximum(abs, axis)
    maximum_component > 0.0 || return false
    ratios = Float64.(axis) ./ maximum_component
    return all(value -> abs(value - round(value)) <= 5.0e-7, ratios)
end

# Map one supported full shell to VASP's l and one-based real-harmonic row.
function _vasp_projection_shell_indices(orbital_set::AbstractString, orbital_index::Int)
    shell = lowercase(strip(orbital_set))
    dimensions = Dict("s" => 1, "p" => 3, "d" => 5)
    haskey(dimensions, shell) || throw(
        ArgumentError(
            "VASP_PAW_PROJECTION_RADIAL_UNSUPPORTED: native VASP PAW AMN currently supports full s/p/d shells",
        ),
    )
    1 <= orbital_index <= dimensions[shell] ||
        throw(ArgumentError("VASP_PAW_PROJECTION_CONTRACT_MISMATCH: orbital index is out of range"))
    return shell == "s" ? (0, 1) : (shell == "p" ? (1, orbital_index) : (2, orbital_index))
end

# Expand the projection basis into one metadata row per global Wannier column.
function _vasp_projection_basis_rows(basis::WannierProjectionBasis)
    spin_components = basis.spinor ? 2 : 1
    rows = Vector{NamedTuple}(undef, basis.num_wannier)
    for block in basis.blocks, center in axes(block.positions_fractional, 2)
        for local_index in axes(block.indices, 1)
            orbital = spin_components == 1 ? local_index : div(local_index - 1, 2) + 1
            spin = spin_components == 1 ? 1 : mod(local_index - 1, 2) + 1
            angular_momentum, magnetic_index =
                _vasp_projection_shell_indices(block.orbital_set, orbital)
            wannier = block.indices[local_index, center]
            wrapped, translation =
                _vasp_projection_wrapped_center(@view(block.positions_fractional[:, center]))
            rows[wannier] = (
                principal_quantum_number = 1,
                angular_momentum,
                magnetic_index,
                center_fractional = wrapped,
                center_integer_translation = translation,
                local_x_cartesian = Tuple(@view(block.local_bases[1, :, center])),
                local_z_cartesian = Tuple(@view(block.local_bases[3, :, center])),
                spin_index = spin,
                wannier_index = wannier,
            )
        end
    end
    all(isassigned(rows, index) for index in eachindex(rows)) || throw(
        ArgumentError("VASP_PAW_PROJECTION_CONTRACT_MISMATCH: projection indices are incomplete"),
    )
    return rows
end

# Parse the numeric LOCPROJ rows between the OUTCAR projection header and AMN stage.
function _vasp_outcar_projection_rows(outcar_text::AbstractString)
    rows = Vector{Vector{Float64}}()
    active = false
    for line in eachline(IOBuffer(outcar_text))
        occursin("LOCPROJ orbitals", line) && (active = true; continue)
        active || continue
        occursin("Computing AMN", line) && break
        tokens = split(strip(line))
        length(tokens) == 17 || continue
        values = try
            parse.(Float64, replace.(tokens, 'D' => 'E', 'd' => 'e'))
        catch
            continue
        end
        push!(rows, values)
    end
    isempty(rows) &&
        throw(ArgumentError("VASP_PAW_PROJECTION_CONTRACT_MISMATCH: OUTCAR has no LOCPROJ rows"))
    return rows
end

# Parse one required scalar using a contract-specific fail-stop message.
function _vasp_outcar_scalar(text::AbstractString, pattern::Regex, label::AbstractString)
    matched = match(pattern, text)
    matched === nothing &&
        throw(ArgumentError("VASP_PAW_PROJECTION_CONTRACT_MISMATCH: OUTCAR omits $(label)"))
    return parse(Float64, replace(only(matched.captures), 'D' => 'E', 'd' => 'e'))
end

# Validate OUTCAR lattice, k-point count, band count, and cutoff against WAVECAR data.
function _validate_vasp_projection_run_contract(
    outcar_text::AbstractString,
    native::NativeWavefunctionData,
)
    version_match = match(r"vasp\.([0-9]+\.[0-9]+\.[0-9]+)", outcar_text)
    version_match === nothing &&
        throw(ArgumentError("VASP_PAW_PROJECTION_CONTRACT_MISMATCH: OUTCAR omits the VASP version"))
    count_match = match(r"NKPTS\s*=\s*(\d+).*NBANDS\s*=\s*(\d+)", outcar_text)
    count_match === nothing &&
        throw(ArgumentError("VASP_PAW_PROJECTION_CONTRACT_MISMATCH: OUTCAR omits NKPTS/NBANDS"))
    parse(Int, count_match.captures[1]) == length(native.kpoints) || throw(
        ArgumentError(
            "VASP_PAW_PROJECTION_CONTRACT_MISMATCH: OUTCAR/WAVECAR k-point counts differ",
        ),
    )
    parse(Int, count_match.captures[2]) >= size(first(native.kpoints).coefficients, 1) ||
        throw(ArgumentError("VASP_PAW_PROJECTION_CONTRACT_MISMATCH: OUTCAR has too few bands"))
    cutoff = _vasp_outcar_scalar(outcar_text, r"ENCUT\s*=\s*([-+0-9.EeDd]+)", "ENCUT")
    lattice_lines = split(outcar_text, '\n')
    lattice_header = findfirst(line -> occursin("direct lattice vectors", line), lattice_lines)
    lattice_header === nothing && throw(
        ArgumentError("VASP_PAW_PROJECTION_CONTRACT_MISMATCH: OUTCAR omits direct lattice vectors"),
    )
    lattice = Matrix{Float64}(undef, 3, 3)
    for row in 1:3
        tokens = split(strip(lattice_lines[something(lattice_header) + row]))
        length(tokens) >= 3 || throw(
            ArgumentError("VASP_PAW_PROJECTION_CONTRACT_MISMATCH: OUTCAR lattice is truncated"),
        )
        lattice[row, :] .= parse.(Float64, tokens[1:3])
    end
    isapprox(lattice, native.structure.lattice; atol = 5.0e-7, rtol = 0.0) || throw(
        ArgumentError("VASP_PAW_PROJECTION_CONTRACT_MISMATCH: OUTCAR/WAVECAR lattices differ"),
    )
    return VersionNumber(version_match.captures[1]), cutoff
end

"""
Build and validate the complete same-run VASP PAW projection contract.

No OUTCAR value is used as a fitted phase or scale. Printed centers and local
axes validate the full-precision WIN values; only exactly recoverable
`spin_qaxis` directions are normalized and used. The returned contract applies
only to native AMN trial construction.
"""
function _build_vasp_projection_contract(
    source::VASPWavefunctionSource,
    native::NativeWavefunctionData,
    basis::WannierProjectionBasis,
)
    source.outcar_file === nothing && throw(
        ArgumentError("VASP_PAW_OUTCAR_REQUIRED: VASPWavefunctionSource.outcar_file is required"),
    )
    isfile(something(source.outcar_file)) || throw(
        ArgumentError("VASP_PAW_OUTCAR_REQUIRED: OUTCAR does not exist: $(source.outcar_file)"),
    )
    text = read(something(source.outcar_file), String)
    version, cutoff = _validate_vasp_projection_run_contract(text, native)
    printed = _vasp_outcar_projection_rows(text)
    expected = _vasp_projection_basis_rows(basis)
    length(printed) == length(expected) || throw(
        ArgumentError(
            "VASP_PAW_PROJECTION_CONTRACT_MISMATCH: OUTCAR has $(length(printed)) LOCPROJ rows; basis has $(length(expected))",
        ),
    )
    entries = VASPProjectionEntry[]
    expected_radial_scale = inv(VASP_PROJECTION_BOHR_ANGSTROM)
    for index in eachindex(expected)
        values = printed[index]
        row = expected[index]
        integers = round.(Int, values[[1, 2, 3, 14]])
        integers ==
        [row.principal_quantum_number, row.angular_momentum, row.magnetic_index, row.spin_index] ||
            throw(
                ArgumentError(
                    "VASP_PAW_PROJECTION_CONTRACT_MISMATCH: LOCPROJ row $(index) orbital/spin order differs from WIN",
                ),
            )
        abs(values[4] - expected_radial_scale) <= VASP_PROJECTION_PRINT_TOLERANCE || throw(
            ArgumentError(
                "VASP_PAW_PROJECTION_RADIAL_UNSUPPORTED: LOCPROJ row $(index) is not the default hydrogenic radial",
            ),
        )
        maximum(abs, values[5:7] .- collect(row.center_fractional)) <=
        VASP_PROJECTION_PRINT_TOLERANCE || throw(
            ArgumentError(
                "VASP_PAW_PROJECTION_CONTRACT_MISMATCH: LOCPROJ row $(index) center differs from WIN",
            ),
        )
        maximum(abs, values[8:10] .- collect(row.local_x_cartesian)) <=
        VASP_PROJECTION_PRINT_TOLERANCE || throw(
            ArgumentError(
                "VASP_PAW_PROJECTION_CONTRACT_MISMATCH: LOCPROJ row $(index) local x axis differs from WIN",
            ),
        )
        maximum(abs, values[11:13] .- collect(row.local_z_cartesian)) <=
        VASP_PROJECTION_PRINT_TOLERANCE || throw(
            ArgumentError(
                "VASP_PAW_PROJECTION_CONTRACT_MISMATCH: LOCPROJ row $(index) local z axis differs from WIN",
            ),
        )
        printed_axis = values[15:17]
        _vasp_projection_axis_is_exactly_recoverable(printed_axis) || throw(
            ArgumentError(
                "VASP_PAW_PROJECTION_AXIS_PRECISION_REQUIRED: spin_qaxis row $(index) is rounded ambiguously",
            ),
        )
        printed_axis ./= norm(printed_axis)
        push!(
            entries,
            VASPProjectionEntry(
                row.principal_quantum_number,
                row.angular_momentum,
                row.magnetic_index,
                expected_radial_scale,
                row.center_fractional,
                row.center_integer_translation,
                row.local_x_cartesian,
                row.local_z_cartesian,
                row.spin_index,
                Tuple(printed_axis),
                row.wannier_index,
            ),
        )
    end
    return VASPProjectionContract(version, cutoff, :vasp_log_simpson_spline, entries)
end

# Fail closed at the raw-VASP to solver-facing projection-gauge boundary.
function _vasp_paw_solver_gauge_error(message::AbstractString)
    throw(ArgumentError("VASP_PAW_SOLVER_GAUGE_ADAPTER_FAILED: $(message)"))
end

# Compare one stored projection row with the full-precision WIN-owned metadata.
function _validate_vasp_solver_gauge_entry(entry::VASPProjectionEntry, expected)
    entry.principal_quantum_number == expected.principal_quantum_number ||
        _vasp_paw_solver_gauge_error("principal quantum number differs from WIN")
    entry.angular_momentum == expected.angular_momentum ||
        _vasp_paw_solver_gauge_error("angular momentum differs from WIN")
    entry.magnetic_index == expected.magnetic_index ||
        _vasp_paw_solver_gauge_error("magnetic row differs from WIN")
    entry.center_integer_translation == expected.center_integer_translation ||
        _vasp_paw_solver_gauge_error("center integer translation differs from WIN")
    entry.spin_index == expected.spin_index ||
        _vasp_paw_solver_gauge_error("spin index differs from WIN")
    maximum(abs, collect(entry.center_fractional) .- collect(expected.center_fractional)) <=
    1.0e-12 || _vasp_paw_solver_gauge_error("wrapped center differs from WIN")
    maximum(abs, collect(entry.local_x_cartesian) .- collect(expected.local_x_cartesian)) <=
    1.0e-12 || _vasp_paw_solver_gauge_error("local x axis differs from WIN")
    maximum(abs, collect(entry.local_z_cartesian) .- collect(expected.local_z_cartesian)) <=
    1.0e-12 || _vasp_paw_solver_gauge_error("local z axis differs from WIN")
    return nothing
end

# Resolve contract rows by global Wannier index, independent of LOCPROJ row order.
function _vasp_solver_gauge_entries(basis::WannierProjectionBasis, contract::VASPProjectionContract)
    length(contract.entries) == basis.num_wannier ||
        _vasp_paw_solver_gauge_error("projection row count differs from num_wannier")
    entries = Vector{VASPProjectionEntry}(undef, basis.num_wannier)
    assigned = falses(basis.num_wannier)
    for entry in contract.entries
        1 <= entry.wannier_index <= basis.num_wannier ||
            _vasp_paw_solver_gauge_error("Wannier index is out of range")
        assigned[entry.wannier_index] &&
            _vasp_paw_solver_gauge_error("duplicate Wannier index $(entry.wannier_index)")
        entries[entry.wannier_index] = entry
        assigned[entry.wannier_index] = true
    end
    all(assigned) || _vasp_paw_solver_gauge_error("projection indices are incomplete")
    expected = _vasp_projection_basis_rows(basis)
    for wannier in eachindex(entries)
        _validate_vasp_solver_gauge_entry(entries[wannier], expected[wannier])
    end
    return entries
end

# Return ordered (spin-up,spin-down) Wannier pairs from the WIN projection basis.
function _vasp_solver_gauge_spinor_pairs(
    basis::WannierProjectionBasis,
    entries::Vector{VASPProjectionEntry},
)
    basis.spinor || return NTuple{2, Int}[]
    pairs = NTuple{2, Int}[]
    covered = falses(basis.num_wannier)
    for block in basis.blocks, center in axes(block.positions_fractional, 2)
        iseven(size(block.indices, 1)) ||
            _vasp_paw_solver_gauge_error("spinor projection block has odd dimension")
        for orbital in 1:div(size(block.indices, 1), 2)
            up = block.indices[2orbital - 1, center]
            down = block.indices[2orbital, center]
            up_entry = entries[up]
            down_entry = entries[down]
            up_entry.spin_index == 1 && down_entry.spin_index == 2 ||
                _vasp_paw_solver_gauge_error("spinor pair is not ordered as spin 1/2")
            up_entry.center_fractional == down_entry.center_fractional ||
                _vasp_paw_solver_gauge_error("spinor pair has different wrapped centers")
            up_entry.center_integer_translation == down_entry.center_integer_translation ||
                _vasp_paw_solver_gauge_error("spinor pair has different center translations")
            up_entry.principal_quantum_number == down_entry.principal_quantum_number &&
            up_entry.angular_momentum == down_entry.angular_momentum &&
            up_entry.magnetic_index == down_entry.magnetic_index ||
                _vasp_paw_solver_gauge_error("spinor pair has different orbital metadata")
            up_entry.local_x_cartesian == down_entry.local_x_cartesian &&
            up_entry.local_z_cartesian == down_entry.local_z_cartesian ||
                _vasp_paw_solver_gauge_error("spinor pair has different local axes")
            maximum(
                abs,
                collect(up_entry.spin_quantization_axis) .-
                collect(down_entry.spin_quantization_axis),
            ) <= 1.0e-12 || _vasp_paw_solver_gauge_error("spinor pair has different spin_qaxis")
            (covered[up] || covered[down]) &&
                _vasp_paw_solver_gauge_error("Wannier column occurs in multiple spinor pairs")
            covered[up] = true
            covered[down] = true
            push!(pairs, (up, down))
        end
    end
    all(covered) || _vasp_paw_solver_gauge_error("spinor pairing is incomplete")
    return pairs
end

# Hash AMN dimensions and column-major complex payload without relying on a file encoding.
function _vasp_paw_amn_array_sha256(amn::WannierAMN)
    buffer = IOBuffer()
    write(buffer, Int64(amn.num_bands), Int64(amn.num_kpts), Int64(amn.num_wannier))
    write(buffer, reinterpret(UInt8, vec(amn.data)))
    return bytes2hex(SHA.sha256(take!(buffer)))
end

"""
Transform raw VASP AMN columns into the WIN/SAWF target gauge.

For each k point the right-column adapter is `D_T(k) * U_q'`, where
`D_T[n,n] = exp(+2pi*im*k.T_n)`. Raw AMN is never mutated. Scalar projections
use only `D_T`; spinor projections additionally rotate VASP's `spin_qaxis`
columns back to the fixed Cartesian-z Pauli basis used by the SAWF target
representation.
"""
function _canonicalize_vasp_amn_for_wannierization(
    raw::WannierAMN,
    kpoints_fractional::AbstractMatrix{<:Real},
    basis::WannierProjectionBasis,
    contract::VASPProjectionContract,
)
    raw.num_wannier == basis.num_wannier ||
        _vasp_paw_solver_gauge_error("AMN num_wannier differs from the projection basis")
    size(kpoints_fractional) == (raw.num_kpts, 3) ||
        _vasp_paw_solver_gauge_error("k-point array must have size (num_kpts,3)")
    all(isfinite, kpoints_fractional) ||
        _vasp_paw_solver_gauge_error("k-point array contains NaN or Inf")
    entries = _vasp_solver_gauge_entries(basis, contract)
    pairs = _vasp_solver_gauge_spinor_pairs(basis, entries)
    basis.spinor ||
        all(entry -> entry.spin_index == 1, entries) ||
        _vasp_paw_solver_gauge_error("scalar projection contains a non-scalar spin index")

    solver_data = similar(raw.data)
    identity_wannier = Matrix{ComplexF64}(I, raw.num_wannier, raw.num_wannier)
    maximum_unitarity = 0.0
    maximum_roundtrip = 0.0
    maximum_projector = 0.0
    minimum_singular = Inf
    maximum_condition = 0.0
    maximum_raw_solver = 0.0
    nonzero_translations = count(entry -> entry.center_integer_translation != (0, 0, 0), entries)
    for kpoint in 1:raw.num_kpts
        k = @view kpoints_fractional[kpoint, :]
        phases =
            ComplexF64[cis(2.0pi * dot(k, entry.center_integer_translation)) for entry in entries]
        transform = Matrix(Diagonal(phases))
        for (up, down) in pairs
            rotation = _vasp_projection_spinor_rotation(entries[up].spin_quantization_axis)
            maximum(abs, rotation' * rotation - Matrix{ComplexF64}(I, 2, 2)) <= 1.0e-12 ||
                _vasp_paw_solver_gauge_error("spin_qaxis rotation is not unitary")
            indices = [up, down]
            transform[indices, indices] .= Diagonal(phases[indices]) * rotation'
        end
        maximum_unitarity =
            max(maximum_unitarity, maximum(abs, transform' * transform - identity_wannier))
        raw_matrix = @view raw.data[:, :, kpoint]
        solver_matrix = @view solver_data[:, :, kpoint]
        mul!(solver_matrix, raw_matrix, transform)
        maximum_roundtrip =
            max(maximum_roundtrip, maximum(abs, solver_matrix * transform' - raw_matrix))
        maximum_projector = max(
            maximum_projector,
            maximum(abs, solver_matrix * solver_matrix' - raw_matrix * raw_matrix'),
        )
        singular = svdvals(solver_matrix)
        minimum_singular = min(minimum_singular, minimum(singular))
        maximum_condition =
            max(maximum_condition, maximum(singular) / max(minimum(singular), eps(Float64)))
        maximum_raw_solver = max(maximum_raw_solver, maximum(abs, solver_matrix - raw_matrix))
    end
    maximum_unitarity <= 1.0e-11 ||
        _vasp_paw_solver_gauge_error("column transform failed its unitarity gate")
    maximum_roundtrip <= 1.0e-11 || _vasp_paw_solver_gauge_error("raw/solver AMN roundtrip failed")
    maximum_projector <= 1.0e-11 ||
        _vasp_paw_solver_gauge_error("AMN projector changed under the gauge adapter")
    solver = WannierAMN(raw.num_bands, raw.num_kpts, raw.num_wannier, solver_data)
    diagnostics = VASPPAWSolverGaugeDiagnostics(
        maximum_unitarity,
        maximum_roundtrip,
        maximum_projector,
        minimum_singular,
        maximum_condition,
        maximum_raw_solver,
        length(pairs),
        nonzero_translations,
    )
    return solver, diagnostics
end

# Construct VASP's odd-length logarithmic radial grid and composite Simpson weights.
function _vasp_projection_radial_grid()
    count = 1
    while VASP_PROJECTION_RADIAL_START_ANGSTROM *
          exp(VASP_PROJECTION_RADIAL_LOG_STEP * (count - 1)) < VASP_PROJECTION_RADIAL_END_ANGSTROM
        count += 1
    end
    count += mod(count, 2) + 1
    grid =
        VASP_PROJECTION_RADIAL_START_ANGSTROM .*
        exp.(VASP_PROJECTION_RADIAL_LOG_STEP .* collect(0:(count - 1)))
    weights = zeros(Float64, count)
    for index in count:-2:3
        weights[index] += grid[index] * VASP_PROJECTION_RADIAL_LOG_STEP / 3.0
        weights[index - 1] = 4.0 * grid[index - 1] * VASP_PROJECTION_RADIAL_LOG_STEP / 3.0
        weights[index - 2] = grid[index - 2] * VASP_PROJECTION_RADIAL_LOG_STEP / 3.0
    end
    return grid, weights
end

# Build VASP's clamped-left/natural-right cubic coefficients on a uniform q grid.
function _vasp_projection_cubic_spline(grid::Vector{Float64}, values::Vector{Float64})
    length(grid) == length(values) >= 2 || throw(ArgumentError("radial spline grid is invalid"))
    count = length(grid)
    temporary_quadratic = zeros(Float64, count)
    temporary_linear = zeros(Float64, count)
    temporary_quadratic[1] = -0.5
    temporary_linear[1] =
        3.0 / (grid[2] - grid[1]) * ((values[2] - values[1]) / (grid[2] - grid[1]))
    for index in 2:(count - 1)
        fraction = (grid[index] - grid[index - 1]) / (grid[index + 1] - grid[index - 1])
        denominator = fraction * temporary_quadratic[index - 1] + 2.0
        temporary_quadratic[index] = (fraction - 1.0) / denominator
        temporary_linear[index] =
            (
                6.0 * (
                    (values[index + 1] - values[index]) / (grid[index + 1] - grid[index]) -
                    (values[index] - values[index - 1]) / (grid[index] - grid[index - 1])
                ) / (grid[index + 1] - grid[index - 1]) - fraction * temporary_linear[index - 1]
            ) / denominator
    end
    temporary_quadratic[count] = 0.0
    temporary_linear[count] = 0.0
    for index in (count - 1):-1:1
        temporary_quadratic[index] =
            temporary_quadratic[index] * temporary_quadratic[index + 1] + temporary_linear[index]
    end
    linear = zeros(Float64, count - 1)
    quadratic = zeros(Float64, count - 1)
    cubic = zeros(Float64, count - 1)
    for index in 1:(count - 1)
        spacing = grid[index + 1] - grid[index]
        difference = (temporary_quadratic[index + 1] - temporary_quadratic[index]) / 6.0
        cubic[index] = difference / spacing
        quadratic[index] = temporary_quadratic[index] / 2.0
        linear[index] =
            (values[index + 1] - values[index]) / spacing -
            (quadratic[index] + difference) * spacing
    end
    return VASPProjectionRadialSpline(copy(grid), copy(values), linear, quadratic, cubic)
end

# Evaluate a VASP trial spline, returning zero at and above its tabulated q maximum.
function (spline::VASPProjectionRadialSpline)(momentum::Real)
    value = Float64(momentum)
    value >= last(spline.grid) && return 0.0
    interval = clamp(searchsortedlast(spline.grid, value), 1, length(spline.grid) - 1)
    displacement = value - spline.grid[interval]
    return spline.values[interval] +
           displacement * (
        spline.linear[interval] +
        displacement * (spline.quadratic[interval] + displacement * spline.cubic[interval])
    )
end

# Tabulate one normalized VASP hydrogenic Fourier-Bessel radial on its 1000-point q grid.
function _build_vasp_projection_radial_spline(
    angular_momentum::Int,
    principal_quantum_number::Int,
    radial_scale_inverse_angstrom::Float64,
    cutoff_ev::Float64,
)
    principal_quantum_number == 1 ||
        throw(ArgumentError("VASP_PAW_PROJECTION_RADIAL_UNSUPPORTED: only n=1 is implemented"))
    angular_momentum in (0, 1, 2) || throw(
        ArgumentError("VASP_PAW_PROJECTION_RADIAL_UNSUPPORTED: only s/p/d shells are implemented"),
    )
    grid, weights = _vasp_projection_radial_grid()
    radial =
        2.0 .* radial_scale_inverse_angstrom^(3.0 / 2.0) .*
        exp.(-radial_scale_inverse_angstrom .* grid)
    radial ./= sqrt(sum(weights .* abs2.(grid .* radial)))
    momentum_step =
        sqrt(2.0 * cutoff_ev / VASP_PROJECTION_HSQDTM_EV_ANGSTROM2) / VASP_PROJECTION_RADIAL_POINTS
    momentum_grid = momentum_step .* collect(0:(VASP_PROJECTION_RADIAL_POINTS - 1))
    transform = Vector{Float64}(undef, length(momentum_grid))
    for (momentum_index, momentum) in enumerate(momentum_grid)
        integral = 0.0
        for radial_index in eachindex(grid)
            integral +=
                weights[radial_index] *
                radial[radial_index] *
                _paw_spherical_bessel(angular_momentum, momentum * grid[radial_index]) *
                grid[radial_index]^2
        end
        transform[momentum_index] = 4.0 * pi * integral
    end
    return _vasp_projection_cubic_spline(momentum_grid, transform)
end

# Return one cached VASP-compatible trial radial spline.
function _vasp_projection_radial_spline(
    angular_momentum::Int,
    principal_quantum_number::Int,
    radial_scale_inverse_angstrom::Float64,
    cutoff_ev::Float64,
)
    key = (
        angular_momentum,
        principal_quantum_number,
        reinterpret(UInt64, radial_scale_inverse_angstrom),
        reinterpret(UInt64, cutoff_ev),
    )
    return lock(_VASP_PROJECTION_RADIAL_SPLINE_LOCK) do
        get!(_VASP_PROJECTION_RADIAL_SPLINES, key) do
            _build_vasp_projection_radial_spline(
                angular_momentum,
                principal_quantum_number,
                radial_scale_inverse_angstrom,
                cutoff_ev,
            )
        end
    end
end

# Evaluate ordered full s/p/d VASP trial functions in the local frame.
function _vasp_projection_orbital_values(
    block::WannierProjectionBlock,
    local_momentum::AbstractVector{<:Real},
    contract::VASPProjectionContract,
    representative_entry::VASPProjectionEntry,
)
    momentum = norm(local_momentum)
    radial = _vasp_projection_radial_spline(
        representative_entry.angular_momentum,
        representative_entry.principal_quantum_number,
        representative_entry.radial_scale_inverse_angstrom,
        contract.cutoff_ev,
    )(
        momentum,
    )
    if block.orbital_set == "s"
        return ComplexF64[radial / sqrt(4.0 * pi)]
    elseif block.orbital_set == "p"
        momentum > 1.0e-12 || return zeros(ComplexF64, 3)
        x, y, z = Float64.(local_momentum) ./ momentum
        angular = sqrt(3.0 / (4.0 * pi)) .* [z, x, y]
        return ComplexF64.((-im) .* radial .* angular)
    elseif block.orbital_set == "d"
        momentum > 1.0e-12 || return zeros(ComplexF64, 5)
        x, y, z = Float64.(local_momentum) ./ momentum
        # VASP/Wannier90 m=1:5: dz2, dxz, dyz, dx2-y2, dxy; Fourier phase (-im)^2.
        angular =
            sqrt(15.0 / (4.0 * pi)) .*
            [(3.0 * z^2 - 1.0) / sqrt(12.0), x * z, y * z, (x^2 - y^2) / 2.0, x * y]
        return ComplexF64.(-radial .* angular)
    end
    throw(
        ArgumentError(
            "VASP_PAW_PROJECTION_RADIAL_UNSUPPORTED: native VASP radial backend supports only s/p/d shells",
        ),
    )
end

# Condon--Shortley associated Legendre polynomial for m >= 0.
function _paw_associated_legendre(degree::Int, order::Int, coordinate::Float64)
    0 <= order <= degree || throw(ArgumentError("spherical-harmonic order is invalid"))
    diagonal = 1.0
    if order > 0
        root = sqrt(max(0.0, (1.0 - coordinate) * (1.0 + coordinate)))
        factor = 1.0
        for _ in 1:order
            diagonal *= -factor * root
            factor += 2.0
        end
    end
    degree == order && return diagonal
    next_value = coordinate * (2.0 * order + 1.0) * diagonal
    degree == order + 1 && return next_value
    previous_previous = diagonal
    previous = next_value
    result = 0.0
    for current_degree in (order + 2):degree
        result =
            (
                (2.0 * current_degree - 1.0) * coordinate * previous -
                (current_degree + order - 1.0) * previous_previous
            ) / (current_degree - order)
        previous_previous = previous
        previous = result
    end
    return result
end

# Return `(l-m)!/(l+m)!` without integer overflow.
function _paw_factorial_ratio(degree::Int, order::Int)
    ratio = 1.0
    for factor in (degree - order + 1):(degree + order)
        ratio /= factor
    end
    return ratio
end

# Evaluate one normalized positive-m complex spherical harmonic.
function _paw_positive_complex_spherical_harmonic(
    order::Int,
    degree::Int,
    azimuth::Float64,
    polar::Float64,
)
    normalization = sqrt((2.0 * degree + 1.0) / (4.0 * pi) * _paw_factorial_ratio(degree, order))
    return normalization *
           _paw_associated_legendre(degree, order, cos(polar)) *
           cis(order * azimuth)
end

"""
Real spherical harmonics in the exact row convention of `vasp2spn`.

Row one is m=0. Rows `m+1` and `2l+2-m` are respectively the cosine and sine
real harmonics for positive m, including the active `sqrt(2)(-1)^m` factor.
"""
function _paw_real_spherical_harmonics(degree::Int, cartesian_vectors::AbstractMatrix{<:Real})
    size(cartesian_vectors, 2) == 3 ||
        throw(ArgumentError("Cartesian vectors must have three columns"))
    count = size(cartesian_vectors, 1)
    output = zeros(Float64, 2 * degree + 1, count)
    root_two = sqrt(2.0)
    for vector_index in 1:count
        x, y, z = Float64.(cartesian_vectors[vector_index, :])
        radius = sqrt(x * x + y * y + z * z)
        polar = radius <= eps(Float64) ? 0.0 : atan(sqrt(x * x + y * y), z)
        azimuth = atan(y, x)
        for order in 0:degree
            value = _paw_positive_complex_spherical_harmonic(order, degree, azimuth, polar)
            if order == 0
                output[1, vector_index] = real(value)
            else
                factor = root_two * (-1.0)^order
                output[order + 1, vector_index] = factor * real(value)
                output[2 * degree + 2 - order, vector_index] = factor * imag(value)
            end
        end
    end
    return output
end

# One expanded projector basis <p_i|k+G> without wavefunction coefficients.
function _paw_projector_basis(
    point::PlaneWaveKPoint,
    native::NativeWavefunctionData,
    paw::VASPPawSystem,
)
    reciprocal_rows =
        (Float64.(point.g_vectors) .+ reshape(point.k_fractional, 1, 3)) * native.reciprocal_lattice
    magnitudes = vec(sqrt.(sum(abs2, reciprocal_rows; dims = 2)))
    maximum_degree =
        maximum(channel.angular_momentum for atom in paw.atoms for channel in atom.channels)
    harmonics = Dict(
        degree => _paw_real_spherical_harmonics(degree, reciprocal_rows) for
        degree in 0:maximum_degree
    )
    basis = zeros(ComplexF64, paw.num_channels, size(point.g_vectors, 1))
    volume_normalization = inv(sqrt(paw.cell_volume_angstrom3))
    for atom in paw.atoms
        dataset = paw.datasets[atom.species]
        phase = ComplexF64[
            cis(2.0 * pi * dot(@view(point.g_vectors[g_index, :]), atom.position_fractional))
            for g_index in axes(point.g_vectors, 1)
        ]
        for (local_channel, channel) in enumerate(atom.channels)
            row = first(atom.channel_range) + local_channel - 1
            radial_spline = dataset.reciprocal_projector_splines[channel.radial_channel]
            for g_index in eachindex(magnitudes)
                radial = radial_spline(magnitudes[g_index])
                isfinite(radial) || continue
                basis[row, g_index] =
                    volume_normalization *
                    (im^channel.angular_momentum) *
                    radial *
                    harmonics[channel.angular_momentum][channel.harmonic_row, g_index] *
                    phase[g_index]
            end
        end
    end
    return basis
end

# Shared PAW projector engine, stored as (band, expanded channel, spin).
function _paw_projectors(native::NativeWavefunctionData, paw::VASPPawSystem)
    normalization = get(native.source_metadata, "coefficient_normalization", "unknown")
    normalization == "vasp_raw" || throw(
        ArgumentError(
            "VASP_PAW_RAW_COEFFICIENTS_REQUIRED: received coefficient normalization $(normalization)",
        ),
    )
    projectors = Vector{Array{ComplexF64, 3}}(undef, length(native.kpoints))
    for (kpoint_index, point) in enumerate(native.kpoints)
        basis = _paw_projector_basis(point, native, paw)
        values = zeros(
            ComplexF64,
            size(point.coefficients, 1),
            paw.num_channels,
            size(point.coefficients, 3),
        )
        for spin in axes(point.coefficients, 3)
            values[:, :, spin] .= @view(point.coefficients[:, :, spin]) * transpose(basis)
        end
        projectors[kpoint_index] = values
    end
    return projectors
end

# Return the maximum residual from identity on one selected band subspace.
function _paw_scoped_identity_residual(overlap::AbstractMatrix, selected::AbstractVector{Bool})
    size(overlap, 1) == size(overlap, 2) == length(selected) ||
        throw(ArgumentError("VASP PAW norm scope dimensions disagree"))
    indices = findall(selected)
    isempty(indices) && throw(ArgumentError("VASP PAW norm scope is empty"))
    maximum_residual = 0.0
    worst = (0, 0)
    for left in indices, right in indices
        residual = abs(overlap[left, right] - (left == right))
        isfinite(residual) || return residual, (left, right)
        if residual > maximum_residual
            maximum_residual = residual
            worst = (left, right)
        end
    end
    return maximum_residual, worst
end

# Require a finite positive band-space PAW metric without changing its entries.
function _paw_require_positive_band_metric(overlap::AbstractMatrix)
    size(overlap, 1) == size(overlap, 2) ||
        throw(ArgumentError("VASP_PAW_METRIC_INVALID: band metric must be square"))
    all(isfinite, overlap) ||
        throw(ArgumentError("VASP_PAW_NONFINITE_METRIC: band metric is not finite"))
    minimum(eigvals(Hermitian(overlap))) > 0.0 || throw(
        ArgumentError("VASP_PAW_METRIC_NOT_POSITIVE_DEFINITE: band metric has no positive norm"),
    )
    return nothing
end

# Generalized q=0 overlap C^dagger C + P^dagger Q P on a selected band scope.
function _paw_generalized_norm_residuals(
    native::NativeWavefunctionData,
    paw::VASPPawSystem,
    projectors::Vector{Array{ComplexF64, 3}},
    outer_mask::Union{Nothing, AbstractMatrix{Bool}} = nothing,
)
    bands = size(first(native.kpoints).coefficients, 1)
    kpoints = length(native.kpoints)
    outer_mask === nothing ||
        size(outer_mask) == (bands, kpoints) ||
        throw(ArgumentError("VASP PAW norm scope dimensions disagree"))
    maximum_residual = 0.0
    worst = (0, 0, 0)
    for (kpoint_index, point) in enumerate(native.kpoints)
        size(point.coefficients, 1) == bands ||
            throw(ArgumentError("VASP PAW band count changes between k-points"))
        overlap = zeros(ComplexF64, bands, bands)
        for spin in axes(point.coefficients, 3)
            coefficients = @view point.coefficients[:, :, spin]
            projector = @view projectors[kpoint_index][:, :, spin]
            overlap .+= conj(coefficients) * transpose(coefficients)
            overlap .+= conj(projector) * paw.q0_augmentation * transpose(projector)
        end
        _paw_require_positive_band_metric(overlap)
        selected =
            outer_mask === nothing ? trues(bands) : BitVector(@view(outer_mask[:, kpoint_index]))
        local_value, local_index = _paw_scoped_identity_residual(overlap, selected)
        if local_value > maximum_residual
            maximum_residual = local_value
            worst = (kpoint_index, local_index[1], local_index[2])
        end
    end
    return maximum_residual, worst
end

# Stable low-order spherical Bessel functions used in finite-b PAW integrals.
function _paw_spherical_bessel(degree::Int, argument::Float64)
    degree >= 0 || throw(ArgumentError("spherical-Bessel degree must be nonnegative"))
    magnitude = abs(argument)
    if magnitude < 0.2
        double_factorial = prod(1:2:(2 * degree + 1); init = 1.0)
        leading = argument^degree / double_factorial
        denominator_one = 2.0 * (2.0 * degree + 3.0)
        denominator_two = 8.0 * (2.0 * degree + 3.0) * (2.0 * degree + 5.0)
        denominator_three =
            48.0 * (2.0 * degree + 3.0) * (2.0 * degree + 5.0) * (2.0 * degree + 7.0)
        return leading * (
            1.0 - argument^2 / denominator_one + argument^4 / denominator_two -
            argument^6 / denominator_three
        )
    end
    degree == 0 && return sin(argument) / argument
    previous_previous = sin(argument) / argument
    previous = sin(argument) / argument^2 - cos(argument) / argument
    degree == 1 && return previous
    for current_degree in 2:degree
        current = (2.0 * current_degree - 1.0) * previous / argument - previous_previous
        previous_previous = previous
        previous = current
    end
    return previous
end

const _VASP_PAW_GAUNT_CACHE = Dict{NTuple{6, Int}, Float64}()
const _VASP_PAW_GAUNT_LOCK = ReentrantLock()

# Deterministic Gauss-Legendre nodes and weights without an added dependency.
function _paw_gauss_legendre(order::Int)
    off_diagonal = [index / sqrt(4.0 * index^2 - 1.0) for index in 1:(order - 1)]
    decomposition = eigen(SymTridiagonal(zeros(Float64, order), off_diagonal))
    return decomposition.values, 2.0 .* abs2.(decomposition.vectors[1, :])
end

# Evaluate one row of the PAW real-spherical-harmonic convention.
function _paw_real_harmonic_value(degree::Int, row::Int, azimuth::Float64, polar::Float64)
    1 <= row <= 2 * degree + 1 || throw(ArgumentError("real-harmonic row is invalid"))
    row == 1 && return real(_paw_positive_complex_spherical_harmonic(0, degree, azimuth, polar))
    if row <= degree + 1
        order = row - 1
        return sqrt(2.0) *
               (-1.0)^order *
               real(_paw_positive_complex_spherical_harmonic(order, degree, azimuth, polar))
    end
    order = 2 * degree + 2 - row
    return sqrt(2.0) *
           (-1.0)^order *
           imag(_paw_positive_complex_spherical_harmonic(order, degree, azimuth, polar))
end

# Numerically exact-to-roundoff real Gaunt coefficient for PAW l <= 3 datasets.
function _paw_real_gaunt(
    left_degree::Int,
    left_row::Int,
    middle_degree::Int,
    middle_row::Int,
    right_degree::Int,
    right_row::Int,
)
    key = (left_degree, left_row, middle_degree, middle_row, right_degree, right_row)
    lock(_VASP_PAW_GAUNT_LOCK) do
        haskey(_VASP_PAW_GAUNT_CACHE, key) && return _VASP_PAW_GAUNT_CACHE[key]
    end
    nodes, weights = _paw_gauss_legendre(32)
    azimuth_count = 64
    value = 0.0
    for azimuth_index in 0:(azimuth_count - 1)
        azimuth = 2.0 * pi * azimuth_index / azimuth_count
        for node_index in eachindex(nodes)
            polar = acos(clamp(nodes[node_index], -1.0, 1.0))
            value +=
                weights[node_index] *
                _paw_real_harmonic_value(left_degree, left_row, azimuth, polar) *
                _paw_real_harmonic_value(middle_degree, middle_row, azimuth, polar) *
                _paw_real_harmonic_value(right_degree, right_row, azimuth, polar) *
                (2.0 * pi / azimuth_count)
        end
    end
    abs(value) < 5.0e-14 && (value = 0.0)
    lock(_VASP_PAW_GAUNT_LOCK) do
        _VASP_PAW_GAUNT_CACHE[key] = value
    end
    return value
end

# AE-minus-pseudo radial Fourier-Bessel integral in POTCAR radial-channel order.
function _paw_radial_delta(
    dataset::VASPPawDataset,
    left_channel::Int,
    right_channel::Int,
    degree::Int,
    b_magnitude_inverse_angstrom::Float64,
)
    radial_difference =
        dataset.all_electron_partial_waves[left_channel] .*
        dataset.all_electron_partial_waves[right_channel] .-
        dataset.pseudo_partial_waves[left_channel] .* dataset.pseudo_partial_waves[right_channel]
    arguments = b_magnitude_inverse_angstrom .* dataset.radial_grid_angstrom
    integrand = radial_difference .* [_paw_spherical_bessel(degree, value) for value in arguments]
    return paw_logarithmic_simpson(dataset.radial_grid_angstrom, integrand)
end

# One atomic finite-b augmentation matrix in expanded real-harmonic channels.
function _paw_finite_b_atomic_matrix(
    dataset::VASPPawDataset,
    channels::Vector{VASPPawChannel},
    b_cartesian::Vector{Float64},
)
    b_magnitude = norm(b_cartesian)
    b_magnitude <= 1.0e-14 && return begin
        output = zeros(ComplexF64, length(channels), length(channels))
        for (left, left_channel) in enumerate(channels),
            (right, right_channel) in enumerate(channels)

            left_channel.angular_momentum == right_channel.angular_momentum || continue
            left_channel.harmonic_row == right_channel.harmonic_row || continue
            output[left, right] = dataset.q0_augmentation_radial[
                left_channel.radial_channel,
                right_channel.radial_channel,
            ]
        end
        output
    end
    direction = reshape(b_cartesian ./ b_magnitude, 1, 3)
    maximum_degree = maximum(channel.angular_momentum for channel in channels)
    b_harmonics = Dict(
        degree => _paw_real_spherical_harmonics(degree, direction)[:, 1] for
        degree in 0:(2 * maximum_degree)
    )
    radial_cache = Dict{NTuple{3, Int}, Float64}()
    output = zeros(ComplexF64, length(channels), length(channels))
    for (left, left_channel) in enumerate(channels), (right, right_channel) in enumerate(channels)
        for degree in
            abs(
            left_channel.angular_momentum - right_channel.angular_momentum,
        ):(left_channel.angular_momentum + right_channel.angular_momentum)

            radial_key = (left_channel.radial_channel, right_channel.radial_channel, degree)
            radial = get!(radial_cache, radial_key) do
                _paw_radial_delta(
                    dataset,
                    left_channel.radial_channel,
                    right_channel.radial_channel,
                    degree,
                    b_magnitude,
                )
            end
            for middle_row in 1:(2 * degree + 1)
                gaunt = _paw_real_gaunt(
                    left_channel.angular_momentum,
                    left_channel.harmonic_row,
                    degree,
                    middle_row,
                    right_channel.angular_momentum,
                    right_channel.harmonic_row,
                )
                gaunt == 0.0 && continue
                output[left, right] +=
                    4.0 * pi * ((-im)^degree) * b_harmonics[degree][middle_row] * gaunt * radial
            end
        end
    end
    return output
end

# Pseudo periodic-part overlap using the topology reciprocal shift exactly once.
function _paw_pseudo_mmn_block(
    left::PlaneWaveKPoint,
    right::PlaneWaveKPoint,
    reciprocal_shift::NTuple{3, Int},
    ;
    threaded_spin::Bool = false,
)
    right_lookup = Dict(Tuple(right.g_vectors[row, :]) => row for row in axes(right.g_vectors, 1))
    left_rows = Int[]
    right_rows = Int[]
    for left_row in axes(left.g_vectors, 1)
        target = Tuple(
            left.g_vectors[left_row, direction] + reciprocal_shift[direction] for direction in 1:3
        )
        right_row = get(right_lookup, target, 0)
        right_row == 0 && continue
        push!(left_rows, left_row)
        push!(right_rows, right_row)
    end
    bands = size(left.coefficients, 1)
    output = zeros(ComplexF64, bands, bands)
    spins = collect(axes(left.coefficients, 3))
    if threaded_spin && Threads.nthreads() > 1 && length(spins) > 1
        contributions = Vector{Matrix{ComplexF64}}(undef, length(spins))
        Threads.@threads :static for spin_index in eachindex(spins)
            spin = spins[spin_index]
            contributions[spin_index] =
                conj(@view(left.coefficients[:, left_rows, spin])) *
                transpose(@view(right.coefficients[:, right_rows, spin]))
        end
        for contribution in contributions
            output .+= contribution
        end
    else
        for spin in spins
            output .+=
                conj(@view(left.coefficients[:, left_rows, spin])) *
                transpose(@view(right.coefficients[:, right_rows, spin]))
        end
    end
    return output
end

# Contract left/right PAW projectors with one finite-b atomic augmentation block.
function _paw_mmn_augmentation_block(
    left_projectors::Array{ComplexF64, 3},
    right_projectors::Array{ComplexF64, 3},
    paw::VASPPawSystem,
    reciprocal_shift::NTuple{3, Int},
    b_cartesian::Vector{Float64},
    finite_b_cache::Dict{Tuple{String, NTuple{3, Float64}}, Matrix{ComplexF64}},
)
    bands = size(left_projectors, 1)
    output = zeros(ComplexF64, bands, bands)
    rounded_b = Tuple(round.(b_cartesian; digits = 12))
    for atom in paw.atoms
        atomic = get!(finite_b_cache, (atom.species, rounded_b)) do
            _paw_finite_b_atomic_matrix(paw.datasets[atom.species], atom.channels, b_cartesian)
        end
        # `vasp2spn` projectors use exp(+i G.R), rather than exp(+i(k+G).R).
        # Their left/right product absorbs the k_right-k_left part of the
        # atomic Bloch phase. Only the integer reciprocal shift remains.
        phase = cis(-2.0 * pi * dot(reciprocal_shift, atom.position_fractional))
        for spin in axes(left_projectors, 3)
            left = @view left_projectors[:, atom.channel_range, spin]
            right = @view right_projectors[:, atom.channel_range, spin]
            output .+= phase .* (conj(left) * atomic * transpose(right))
        end
    end
    return output
end

# Generate complete pseudo-plus-augmentation MMN on the supplied topology.
function _paw_generate_mmn(
    native::NativeWavefunctionData,
    paw::VASPPawSystem,
    projectors::Vector{Array{ComplexF64, 3}},
    topology::WannierMMNTopology,
)
    bands = size(first(native.kpoints).coefficients, 1)
    topology.num_bands == bands || throw(
        ArgumentError(
            "VASP_PAW_DATA_REQUIRED: topology has $(topology.num_bands) bands, WAVECAR selection has $(bands)",
        ),
    )
    topology.num_kpts == length(native.kpoints) ||
        throw(ArgumentError("VASP_PAW_DATA_REQUIRED: topology and WAVECAR k-point counts disagree"))
    data = Array{ComplexF64, 4}(undef, bands, bands, topology.num_neighbors, topology.num_kpts)
    pseudo_maximum = 0.0
    augmentation_maximum = 0.0
    finite_b_cache = Dict{Tuple{String, NTuple{3, Float64}}, Matrix{ComplexF64}}()
    for kpoint in 1:topology.num_kpts, neighbor_index in 1:topology.num_neighbors
        right_index = topology.neighbors[neighbor_index, kpoint]
        1 <= right_index <= topology.num_kpts ||
            throw(ArgumentError("MMN topology contains an out-of-range neighbour"))
        shift = Tuple(topology.reciprocal_shifts[:, neighbor_index, kpoint])
        left = native.kpoints[kpoint]
        right = native.kpoints[right_index]
        b_fractional = right.k_fractional .+ collect(shift) .- left.k_fractional
        b_cartesian = transpose(native.reciprocal_lattice) * b_fractional
        pseudo = _paw_pseudo_mmn_block(left, right, shift)
        augmentation = _paw_mmn_augmentation_block(
            projectors[kpoint],
            projectors[right_index],
            paw,
            shift,
            b_cartesian,
            finite_b_cache,
        )
        pseudo_maximum = max(pseudo_maximum, maximum(abs, pseudo))
        augmentation_maximum = max(augmentation_maximum, maximum(abs, augmentation))
        # Match the established `WannierMMN.data` reader convention exactly.
        # The formatted protocol's nested m/n row order is restored by the IO
        # writer; the in-memory native block is not transposed here.
        data[:, :, neighbor_index, kpoint] .= pseudo .+ augmentation
    end
    return WannierMMN(
        bands,
        topology.num_kpts,
        topology.num_neighbors,
        data,
        copy(topology.neighbors),
        copy(topology.reciprocal_shifts),
    ),
    Dict(
        "pseudo_max_absolute" => pseudo_maximum,
        "augmentation_max_absolute" => augmentation_maximum,
    )
end

"""
Construct ordered trial plane-wave spinors in the configured diagnostic contract.

The production call supplies a `VASPProjectionContract`, uses VASP-wrapped
centers, rotates local spins into the Cartesian-z Pauli basis, and evaluates the
VASP-compatible radial spline. The independent keywords exist only for the
A0--A5 root-cause ablation and are not exposed by the public generator.
"""
function _paw_trial_matrices(
    point::PlaneWaveKPoint,
    native::NativeWavefunctionData,
    basis::WannierProjectionBasis,
    contract::Union{Nothing, VASPProjectionContract} = nothing;
    use_wrapped_centers::Bool = false,
    rotate_trial_spinors::Bool = false,
    radial_backend::Symbol = :basis,
)
    radial_backend in (:basis, :vasp_compatible) ||
        throw(ArgumentError("unsupported PAW trial radial backend $(radial_backend)"))
    (use_wrapped_centers || rotate_trial_spinors || radial_backend == :vasp_compatible) &&
        contract === nothing &&
        throw(
            ArgumentError(
                "VASP_PAW_PROJECTION_CONTRACT_MISMATCH: trial correction requires OUTCAR",
            ),
        )
    spin_components = native.spinor ? 2 : 1
    matrices =
        [zeros(ComplexF64, size(point.g_vectors, 1), basis.num_wannier) for _ in 1:spin_components]
    volume_normalization = inv(sqrt(abs(det(native.structure.lattice))))
    for block in basis.blocks, center in axes(block.positions_fractional, 2)
        local_dimension = div(size(block.indices, 1), spin_components)
        first_wannier = block.indices[1, center]
        representative_entry =
            contract === nothing ? nothing : something(contract).entries[first_wannier]
        center_fractional =
            use_wrapped_centers ? collect(something(representative_entry).center_fractional) :
            @view(block.positions_fractional[:, center])
        for g_index in axes(point.g_vectors, 1)
            q_fractional = point.k_fractional .+ @view(point.g_vectors[g_index, :])
            q_cartesian = transpose(native.reciprocal_lattice) * q_fractional
            local_q = @view(block.local_bases[:, :, center]) * q_cartesian
            orbital_values = if radial_backend == :vasp_compatible
                _vasp_projection_orbital_values(
                    block,
                    local_q,
                    something(contract),
                    something(representative_entry),
                )
            else
                projection_orbital_values(block, local_q; radial_transform = basis.radial_transform)
            end
            length(orbital_values) == local_dimension ||
                throw(ArgumentError("projection orbital dimension is inconsistent"))
            phase = cis(-2.0 * pi * dot(q_fractional, center_fractional))
            for local_index in axes(block.indices, 1)
                spin = spin_components == 1 ? 1 : mod(local_index - 1, 2) + 1
                orbital = spin_components == 1 ? local_index : div(local_index - 1, 2) + 1
                wannier = block.indices[local_index, center]
                scalar = volume_normalization * phase * orbital_values[orbital]
                if spin_components == 1 || !rotate_trial_spinors
                    matrices[spin][g_index, wannier] += scalar
                else
                    entry = something(contract).entries[wannier]
                    rotation = _vasp_projection_spinor_rotation(entry.spin_quantization_axis)
                    for cartesian_spin in 1:2
                        matrices[cartesian_spin][g_index, wannier] +=
                            rotation[cartesian_spin, spin] * scalar
                    end
                end
            end
        end
    end
    return matrices
end

"""
Normalize complete PAW trial orbitals with `g^dagger g + d^dagger Q d`.

`trials[spin]` and `trial_projectors[spin]` are scaled in place by the same
positive factor for each Wannier column. The returned values contain the raw
pseudo and augmentation norms plus the post-scaling residual; no oracle AMN is
consulted.
"""
function _paw_normalize_trial_orbitals!(
    trials::Vector{Matrix{ComplexF64}},
    trial_projectors::Vector{Matrix{ComplexF64}},
    q0_augmentation::Matrix{Float64},
)
    num_wannier = size(first(trials), 2)
    factors = Vector{Float64}(undef, num_wannier)
    pseudo_norms = zeros(Float64, num_wannier)
    augmentation_norms = zeros(Float64, num_wannier)
    residuals = Vector{Float64}(undef, num_wannier)
    for wannier in 1:num_wannier
        for spin in eachindex(trials)
            pseudo_norms[wannier] += sum(abs2, @view(trials[spin][:, wannier]))
            projected = @view trial_projectors[spin][wannier, :]
            augmentation_norms[wannier] += real(dot(projected, q0_augmentation * projected))
        end
        total = pseudo_norms[wannier] + augmentation_norms[wannier]
        isfinite(total) && total > 0.0 || throw(
            ArgumentError(
                "VASP_PAW_TRIAL_NORMALIZATION_FAILED: trial $(wannier) has invalid generalized norm $(total)",
            ),
        )
        factors[wannier] = inv(sqrt(total))
        for spin in eachindex(trials)
            @views trials[spin][:, wannier] .*= factors[wannier]
            @views trial_projectors[spin][wannier, :] .*= factors[wannier]
        end
        residuals[wannier] = abs(total * factors[wannier]^2 - 1.0)
    end
    return factors, pseudo_norms, augmentation_norms, residuals
end

# Expand partial-wave AE-minus-PS radial overlaps into the full atom/channel metric.
function _paw_integrated_q0_metric(paw::VASPPawSystem)
    metric = zeros(Float64, paw.num_channels, paw.num_channels)
    for atom in paw.atoms
        radial = paw_radial_q0(paw.datasets[atom.species])
        for (left_index, left) in enumerate(atom.channels),
            (right_index, right) in enumerate(atom.channels)

            left.angular_momentum == right.angular_momentum || continue
            left.harmonic_row == right.harmonic_row || continue
            global_left = first(atom.channel_range) + left_index - 1
            global_right = first(atom.channel_range) + right_index - 1
            metric[global_left, global_right] = radial[left.radial_channel, right.radial_channel]
        end
    end
    return metric
end

"""
Construct native PAW AMN as `A_tilde + P^dagger Q d` without an AE wavefunction.

The default keyword values reproduce the pre-fix A0 path for focused ablation.
Production supplies the validated OUTCAR contract and enables center wrapping,
spin rotation, PAW-metric trial normalization, and the VASP radial backend.
The function returns AMN, component maxima, and normalization diagnostics.
"""
function _paw_generate_amn(
    native::NativeWavefunctionData,
    paw::VASPPawSystem,
    projectors::Vector{Array{ComplexF64, 3}},
    basis::WannierProjectionBasis,
    contract::Union{Nothing, VASPProjectionContract} = nothing;
    use_wrapped_centers::Bool = false,
    rotate_trial_spinors::Bool = false,
    normalize_trials::Bool = false,
    radial_backend::Symbol = :basis,
    trial_metric::Matrix{Float64} = paw.q0_augmentation,
    augmentation_metric::Matrix{Float64} = paw.q0_augmentation,
)
    native.spinor == basis.spinor ||
        throw(ArgumentError("wavefunction and projection basis spin conventions disagree"))
    bands = size(first(native.kpoints).coefficients, 1)
    values = zeros(ComplexF64, bands, basis.num_wannier, length(native.kpoints))
    pseudo_maximum = 0.0
    augmentation_maximum = 0.0
    normalization_factors = ones(Float64, basis.num_wannier, length(native.kpoints))
    pseudo_norms = fill(NaN, basis.num_wannier, length(native.kpoints))
    augmentation_norms = fill(NaN, basis.num_wannier, length(native.kpoints))
    normalized_residuals = fill(NaN, basis.num_wannier, length(native.kpoints))
    for (kpoint_index, point) in enumerate(native.kpoints)
        projector_basis = _paw_projector_basis(point, native, paw)
        trials = _paw_trial_matrices(
            point,
            native,
            basis,
            contract;
            use_wrapped_centers,
            rotate_trial_spinors,
            radial_backend,
        )
        trial_projectors = [
            transpose(trials[spin]) * transpose(projector_basis) for
            spin in axes(point.coefficients, 3)
        ]
        if normalize_trials
            factors, local_pseudo_norms, local_augmentation_norms, residuals =
                _paw_normalize_trial_orbitals!(trials, trial_projectors, trial_metric)
            normalization_factors[:, kpoint_index] .= factors
            pseudo_norms[:, kpoint_index] .= local_pseudo_norms
            augmentation_norms[:, kpoint_index] .= local_augmentation_norms
            normalized_residuals[:, kpoint_index] .= residuals
            maximum(residuals) <= 5.0e-12 || throw(
                ArgumentError(
                    "VASP_PAW_TRIAL_NORMALIZATION_FAILED: maximum residual $(maximum(residuals)) exceeds 5e-12",
                ),
            )
        end
        for spin in axes(point.coefficients, 3)
            pseudo = conj(@view(point.coefficients[:, :, spin])) * trials[spin]
            augmentation =
                conj(@view(projectors[kpoint_index][:, :, spin])) *
                augmentation_metric *
                transpose(trial_projectors[spin])
            values[:, :, kpoint_index] .+= pseudo .+ augmentation
            pseudo_maximum = max(pseudo_maximum, maximum(abs, pseudo))
            augmentation_maximum = max(augmentation_maximum, maximum(abs, augmentation))
        end
        all(
            wannier -> norm(@view(values[:, wannier, kpoint_index])) > 1.0e-14,
            1:basis.num_wannier,
        ) || throw(ArgumentError("native PAW AMN contains a vanishing trial projection"))
    end
    return (
        WannierAMN(bands, length(native.kpoints), basis.num_wannier, values),
        Dict(
            "pseudo_max_absolute" => pseudo_maximum,
            "augmentation_max_absolute" => augmentation_maximum,
            "normalization_factor_minimum" => minimum(normalization_factors),
            "normalization_factor_maximum" => maximum(normalization_factors),
            "normalization_residual_maximum" =>
                normalize_trials ? maximum(normalized_residuals) : NaN,
        ),
        VASPTrialNormalizationDiagnostics(
            normalization_factors,
            pseudo_norms,
            augmentation_norms,
            normalized_residuals,
        ),
    )
end

# Compare same-shaped arrays without phase, scale, or degeneracy alignment.
function _paw_array_parity(generated::AbstractArray, oracle::AbstractArray)
    size(generated) == size(oracle) ||
        throw(ArgumentError("VASP PAW parity arrays have different dimensions"))
    maximum_value = -Inf
    worst_index = Int[]
    sum_squared = 0.0
    oracle_sum_squared = 0.0
    finite = true
    for index in CartesianIndices(generated)
        difference = generated[index] - oracle[index]
        absolute = abs(difference)
        finite &= isfinite(absolute)
        sum_squared += abs2(difference)
        oracle_sum_squared += abs2(oracle[index])
        if absolute > maximum_value
            maximum_value = absolute
            worst_index = collect(Tuple(index))
        end
    end
    count = length(generated)
    return VASPPAWArrayParityMetrics(
        maximum_value,
        sqrt(sum_squared / count),
        sqrt(sum_squared / max(oracle_sum_squared, eps(Float64))),
        worst_index,
        finite,
    )
end

# Compare AMN arrays only on the ragged outer rows at each k-point.
function _paw_amn_scoped_parity(
    generated::WannierAMN,
    oracle::WannierAMN,
    outer_mask::AbstractMatrix{Bool},
)
    size(generated.data) == size(oracle.data) ||
        throw(ArgumentError("VASP PAW AMN parity arrays have different dimensions"))
    size(outer_mask) == (generated.num_bands, generated.num_kpts) ||
        throw(ArgumentError("VASP PAW AMN parity scope dimensions disagree"))
    maximum_value = -Inf
    worst_index = Int[]
    sum_squared = 0.0
    oracle_sum_squared = 0.0
    finite = true
    count = 0
    for kpoint in 1:generated.num_kpts
        for wannier in 1:generated.num_wannier, band in findall(@view(outer_mask[:, kpoint]))
            difference = generated.data[band, wannier, kpoint] - oracle.data[band, wannier, kpoint]
            absolute = abs(difference)
            finite &= isfinite(absolute) && isfinite(abs(oracle.data[band, wannier, kpoint]))
            sum_squared += abs2(difference)
            oracle_sum_squared += abs2(oracle.data[band, wannier, kpoint])
            count += 1
            if absolute > maximum_value
                maximum_value = absolute
                worst_index = [band, wannier, kpoint]
            end
        end
    end
    count > 0 || throw(ArgumentError("VASP PAW AMN parity scope is empty"))
    return VASPPAWArrayParityMetrics(
        maximum_value,
        sqrt(sum_squared / count),
        sqrt(sum_squared / max(oracle_sum_squared, eps(Float64))),
        worst_index,
        finite,
    )
end

# Stream the formatted oracle MMN while retaining only one comparison block.
function _paw_mmn_streaming_parity(
    mmn::WannierMMN,
    oracle_file::AbstractString,
    outer_mask::Union{Nothing, AbstractMatrix{Bool}} = nothing,
)
    outer_mask === nothing ||
        size(outer_mask) == (mmn.num_bands, mmn.num_kpts) ||
        throw(ArgumentError("VASP PAW MMN parity scope dimensions disagree"))
    maximum_value = -Inf
    worst_index = Int[]
    sum_squared = 0.0
    oracle_sum_squared = 0.0
    finite = true
    block_counter = Ref(0)
    foreach_wannier_mmn_block(
        oracle_file;
        expected_num_bands = mmn.num_bands,
        expected_num_kpoints = mmn.num_kpts,
    ) do kpoint, neighbor, shift, oracle_block
        block_counter[] += 1
        neighbor_index = mod(block_counter[] - 1, mmn.num_neighbors) + 1
        mmn.neighbors[neighbor_index, kpoint] == neighbor ||
            throw(ArgumentError("VASP_PAW_DATA_REQUIRED: oracle MMN neighbour topology differs"))
        Tuple(mmn.reciprocal_shifts[:, neighbor_index, kpoint]) == shift ||
            throw(ArgumentError("VASP_PAW_DATA_REQUIRED: oracle MMN reciprocal shift differs"))
        generated = @view mmn.data[:, :, neighbor_index, kpoint]
        source_indices =
            outer_mask === nothing ? axes(generated, 1) : findall(@view(outer_mask[:, kpoint]))
        target_indices =
            outer_mask === nothing ? axes(generated, 2) : findall(@view(outer_mask[:, neighbor]))
        for source_band in source_indices, target_band in target_indices
            difference =
                generated[source_band, target_band] - oracle_block[source_band, target_band]
            absolute = abs(difference)
            finite &= isfinite(absolute) && isfinite(abs(oracle_block[source_band, target_band]))
            sum_squared += abs2(difference)
            oracle_sum_squared += abs2(oracle_block[source_band, target_band])
            if absolute > maximum_value
                maximum_value = absolute
                worst_index = [source_band, target_band, neighbor_index, kpoint]
            end
        end
    end
    expected_blocks = mmn.num_kpts * mmn.num_neighbors
    block_counter[] == expected_blocks ||
        throw(ArgumentError("VASP_PAW_DATA_REQUIRED: oracle MMN block count differs"))
    sample_count = if outer_mask === nothing
        mmn.num_bands^2 * expected_blocks
    else
        sum(
            count(@view(outer_mask[:, kpoint])) *
            count(@view(outer_mask[:, mmn.neighbors[neighbor_index, kpoint]])) for
            kpoint in 1:mmn.num_kpts, neighbor_index in 1:mmn.num_neighbors
        )
    end
    sample_count > 0 || throw(ArgumentError("VASP PAW MMN parity scope is empty"))
    return VASPPAWArrayParityMetrics(
        maximum_value,
        sqrt(sum_squared / sample_count),
        sqrt(sum_squared / max(oracle_sum_squared, eps(Float64))),
        worst_index,
        finite,
    )
end

# Measure AMN subspace angles, projector distance, rank, and conditioning.
function _paw_amn_subspace_metrics(
    generated::WannierAMN,
    oracle::WannierAMN,
    outer_mask::Union{Nothing, AbstractMatrix{Bool}} = nothing,
)
    size(generated.data) == size(oracle.data) ||
        throw(ArgumentError("VASP PAW AMN subspace arrays have different dimensions"))
    outer_mask === nothing ||
        size(outer_mask) == (generated.num_bands, generated.num_kpts) ||
        throw(ArgumentError("VASP PAW AMN subspace scope dimensions disagree"))
    maximum_angle = 0.0
    maximum_projector = 0.0
    worst_condition = 0.0
    minimum_rank = generated.num_wannier
    for kpoint in 1:generated.num_kpts
        indices =
            outer_mask === nothing ? axes(generated.data, 1) : findall(@view(outer_mask[:, kpoint]))
        generated_matrix = @view generated.data[indices, :, kpoint]
        oracle_matrix = @view oracle.data[indices, :, kpoint]
        generated_singular = svdvals(generated_matrix)
        oracle_singular = svdvals(oracle_matrix)
        generated_scale = isempty(generated_singular) ? 0.0 : maximum(generated_singular)
        oracle_scale = isempty(oracle_singular) ? 0.0 : maximum(oracle_singular)
        generated_rank = count(>(generated_scale * 1.0e-12), generated_singular)
        oracle_rank = count(>(oracle_scale * 1.0e-12), oracle_singular)
        minimum_rank = min(minimum_rank, generated_rank, oracle_rank)
        if generated_rank < generated.num_wannier || oracle_rank < oracle.num_wannier
            maximum_angle = Inf
            maximum_projector = Inf
            worst_condition = Inf
            continue
        end
        worst_condition =
            max(worst_condition, generated_scale / max(minimum(generated_singular), eps(Float64)))
        generated_q = Matrix(qr(generated_matrix).Q[:, 1:generated.num_wannier])
        oracle_q = Matrix(qr(oracle_matrix).Q[:, 1:oracle.num_wannier])
        singular = svdvals(generated_q' * oracle_q)
        maximum_angle = max(maximum_angle, acos(clamp(minimum(singular), -1.0, 1.0)))
        maximum_projector =
            max(maximum_projector, maximum(abs, generated_q * generated_q' - oracle_q * oracle_q'))
    end
    return maximum_angle, maximum_projector, minimum_rank, worst_condition
end

# Preserve dimension failures while treating non-finite full-parent SVD data as audit evidence.
function _paw_amn_parent_audit_metrics(generated::WannierAMN, oracle::WannierAMN)
    size(generated.data) == size(oracle.data) ||
        throw(ArgumentError("VASP PAW AMN subspace arrays have different dimensions"))
    (all(isfinite, generated.data) && all(isfinite, oracle.data)) || return (NaN, NaN, 0, NaN)
    return _paw_amn_subspace_metrics(generated, oracle)
end

# Check integrated AE-minus-PS radial overlaps against POTCAR q=0 values.
function _paw_radial_q_gate(paw::VASPPawSystem)
    maximum_residual = 0.0
    worst = ("", 0, 0)
    for species in paw.dataset_order
        dataset = paw.datasets[species]
        integrated = paw_radial_q0(dataset)
        for left in axes(integrated, 1), right in axes(integrated, 2)
            dataset.angular_momenta[left] == dataset.angular_momenta[right] || continue
            residual = abs(integrated[left, right] - dataset.q0_augmentation_radial[left, right])
            if residual > maximum_residual
                maximum_residual = residual
                worst = (species, left, right)
            end
        end
    end
    return maximum_residual, worst
end

# Apply one fixed max/RMS/relative-L2 raw parity gate.
function _paw_metric_passes(
    metric::VASPPAWArrayParityMetrics,
    maximum_threshold::Float64,
    rms_threshold::Float64,
    relative_threshold::Float64,
)
    return metric.finite &&
           metric.max_absolute <= maximum_threshold &&
           metric.root_mean_square <= rms_threshold &&
           metric.relative_l2 <= relative_threshold
end

# Validate one digest-bound ragged target scope before any metric is qualified.
function _validate_vasp_paw_qualification_scope(
    scope::BandRepresentationQualificationScope,
    bands::Int,
    kpoints::Int,
    num_wannier::Int,
)
    size(scope.outer_mask) == (bands, kpoints) || throw(
        ArgumentError("VASP_PAW_TARGET_SCOPE_DIMENSION_MISMATCH: outer mask dimensions disagree"),
    )
    size(scope.frozen_mask) == (bands, kpoints) || throw(
        ArgumentError("VASP_PAW_TARGET_SCOPE_DIMENSION_MISMATCH: frozen mask dimensions disagree"),
    )
    canonical = BandRepresentationQualificationScope(scope.outer_mask, scope.frozen_mask)
    canonical.outer_mask_sha256 == scope.outer_mask_sha256 ||
        throw(ArgumentError("VASP_PAW_TARGET_SCOPE_HASH_MISMATCH: outer mask digest differs"))
    canonical.frozen_mask_sha256 == scope.frozen_mask_sha256 ||
        throw(ArgumentError("VASP_PAW_TARGET_SCOPE_HASH_MISMATCH: frozen mask digest differs"))
    for kpoint in 1:kpoints
        count(@view(scope.outer_mask[:, kpoint])) >= num_wannier || throw(
            ArgumentError(
                "VASP_PAW_TARGET_SCOPE_RANK_FAILED: outer dimension at k-point $(kpoint) " *
                "is smaller than num_wannier=$(num_wannier)",
            ),
        )
    end
    return nothing
end

# Check MMN finiteness only on source-outer/neighbor-target-outer entries.
function _paw_mmn_target_finite(mmn::WannierMMN, outer_mask::AbstractMatrix{Bool})
    size(outer_mask) == (mmn.num_bands, mmn.num_kpts) ||
        throw(ArgumentError("VASP PAW MMN finite scope dimensions disagree"))
    for kpoint in 1:mmn.num_kpts, neighbor_index in 1:mmn.num_neighbors
        neighbor = mmn.neighbors[neighbor_index, kpoint]
        1 <= neighbor <= mmn.num_kpts ||
            throw(ArgumentError("VASP PAW MMN finite scope contains an out-of-range neighbour"))
        for source_band in findall(@view(outer_mask[:, kpoint])),
            target_band in findall(@view(outer_mask[:, neighbor]))

            isfinite(mmn.data[source_band, target_band, neighbor_index, kpoint]) || return false
        end
    end
    return true
end

# Check AMN finiteness only on outer band rows, retaining every Wannier column.
function _paw_amn_target_finite(amn::WannierAMN, outer_mask::AbstractMatrix{Bool})
    size(outer_mask) == (amn.num_bands, amn.num_kpts) ||
        throw(ArgumentError("VASP PAW AMN finite scope dimensions disagree"))
    for kpoint in 1:amn.num_kpts,
        wannier in 1:amn.num_wannier,
        band in findall(@view(outer_mask[:, kpoint]))

        isfinite(amn.data[band, wannier, kpoint]) || return false
    end
    return true
end

# Apply only target-scope physical gates plus global engineering/radial gates.
function _paw_target_qualification(
    radial_q_maximum::Float64,
    generalized_norm_maximum::Float64,
    mmn_parity::Union{Nothing, VASPPAWArrayParityMetrics},
    amn_parity::Union{Nothing, VASPPAWArrayParityMetrics},
    maximum_angle::Float64,
    maximum_projector::Float64,
    minimum_rank::Int,
    num_wannier::Int,
    target_finite_pass::Bool,
    thresholds::VASPPAWParityThresholds;
    require_oracle::Bool,
)
    radial_pass = radial_q_maximum <= thresholds.radial_q_max_absolute
    norm_pass = generalized_norm_maximum <= thresholds.generalized_norm_max_absolute
    mmn_pass =
        mmn_parity !== nothing && _paw_metric_passes(
            something(mmn_parity),
            thresholds.mmn_max_absolute,
            thresholds.mmn_rms,
            thresholds.mmn_relative_l2,
        )
    amn_raw_pass =
        amn_parity !== nothing && _paw_metric_passes(
            something(amn_parity),
            thresholds.amn_max_absolute,
            thresholds.amn_rms,
            thresholds.amn_relative_l2,
        )
    amn_subspace_pass =
        isfinite(maximum_angle) &&
        isfinite(maximum_projector) &&
        maximum_angle <= thresholds.amn_max_principal_angle_rad &&
        maximum_projector <= thresholds.amn_projector_max_absolute &&
        minimum_rank == num_wannier
    if !require_oracle
        mmn_pass = mmn_parity === nothing || mmn_pass
        amn_raw_pass = amn_parity === nothing || amn_raw_pass
        amn_subspace_pass = amn_parity === nothing || amn_subspace_pass
    end
    passed =
        target_finite_pass &&
        radial_pass &&
        norm_pass &&
        mmn_pass &&
        amn_raw_pass &&
        amn_subspace_pass
    return (;
        passed,
        target_finite_pass,
        radial_pass,
        norm_pass,
        mmn_pass,
        amn_raw_pass,
        amn_subspace_pass,
    )
end

# Classify the full parent without feeding its thresholds into target qualification.
function _paw_parent_audit_status(
    generalized_norm_maximum::Float64,
    mmn_parity::Union{Nothing, VASPPAWArrayParityMetrics},
    amn_parity::Union{Nothing, VASPPAWArrayParityMetrics},
    maximum_angle::Float64,
    maximum_projector::Float64,
    minimum_rank::Int,
    num_wannier::Int,
    parent_finite_audit::Bool,
    thresholds::VASPPAWParityThresholds,
)
    parent_finite_audit || return :AUDIT_EXCEEDED
    (mmn_parity === nothing || amn_parity === nothing) && return :AUDIT_NOT_AVAILABLE
    passed =
        generalized_norm_maximum <= thresholds.generalized_norm_max_absolute &&
        _paw_metric_passes(
            something(mmn_parity),
            thresholds.mmn_max_absolute,
            thresholds.mmn_rms,
            thresholds.mmn_relative_l2,
        ) &&
        _paw_metric_passes(
            something(amn_parity),
            thresholds.amn_max_absolute,
            thresholds.amn_rms,
            thresholds.amn_relative_l2,
        ) &&
        isfinite(maximum_angle) &&
        isfinite(maximum_projector) &&
        maximum_angle <= thresholds.amn_max_principal_angle_rad &&
        maximum_projector <= thresholds.amn_projector_max_absolute &&
        minimum_rank == num_wannier
    return passed ? :AUDIT_PASS : :AUDIT_EXCEEDED
end

# Atomically persist PAW inputs, numerical contracts, components, and parity evidence.
function _write_vasp_paw_provenance(
    filename::AbstractString,
    result::VASPPAWMatrixElementResult,
    paw::VASPPawSystem,
    thresholds::VASPPAWParityThresholds,
    mmn_component_norms::Dict{String, Float64},
    amn_component_norms::Dict{String, Float64},
    basis::WannierProjectionBasis,
    projection_contract::VASPProjectionContract,
    trial_normalization::VASPTrialNormalizationDiagnostics,
    qualification_scope::BandRepresentationQualificationScope,
    qualification_metadata::Dict{String, String},
    parent_audit::VASPPAWParentAudit,
)
    HDF5.enable_complex_support()
    return atomic_hdf5_write(filename) do temporary
        HDF5.h5open(temporary, "w") do handle
            attributes = HDF5.attributes(handle)
            attributes["schema"] = VASP_PAW_MATRIX_ELEMENT_SCHEMA
            attributes["schema_version"] = VASP_PAW_MATRIX_ELEMENT_SCHEMA_VERSION
            attributes["passed"] = result.passed
            attributes["construction"] = "operator-specific PAW matrix elements; no 3D AE wavefunction"
            attributes["coefficient_normalization"] = "vasp_raw"
            attributes["radial_grid_unit"] = "angstrom"
            attributes["atomic_phase_convention"] = "absorbed by exp(+i G.R) projector rephasing; no duplicate outer phase"
            attributes["reciprocal_vector_unit"] = "angstrom^-1"
            attributes["finite_b_expansion"] = "real spherical harmonics; spherical Bessel; real Gaunt"
            attributes["projection_basis_sha256"] = projection_basis_sha256(basis)
            attributes["vasp_version"] = string(projection_contract.vasp_version)
            attributes["projection_radial_backend"] = String(projection_contract.radial_backend)
            attributes["projection_cutoff_ev"] = projection_contract.cutoff_ev
            attributes["amn_q0_metric_backend"] = "integrated_ae_minus_ps_partial_waves"
            attributes["mmn_augmentation_backend"] = "potcar_tabulated_finite_b"
            attributes["amn_raw_array_sha256"] = _vasp_paw_amn_array_sha256(result.amn)
            attributes["amn_solver_array_sha256"] = _vasp_paw_amn_array_sha256(result.solver_amn)
            attributes["solver_gauge_formula"] = "A_wannierization(k)=A_raw(k)*D_T(k)*U_q^dagger"
            attributes["solver_center_phase_convention"] = "D_T[n,n]=exp(+i*2*pi*k_fractional dot T_n); T=wrapped-WIN"
            attributes["solver_spin_basis_convention"] = "right multiply VASP spin_qaxis pairs by U_q^dagger into Cartesian-z Pauli basis"
            haskey(result.artifacts, "amn") &&
                (attributes["amn_raw_file_sha256"] = sha256_file(result.artifacts["amn"]))
            haskey(result.artifacts, "solver_amn") &&
                (attributes["amn_solver_file_sha256"] = sha256_file(result.artifacts["solver_amn"]))
            attributes["radial_q_max_absolute"] = result.radial_q_max_absolute
            attributes["generalized_norm_max_absolute"] = result.generalized_norm_max_absolute
            attributes["amn_max_principal_angle_rad"] = result.amn_max_principal_angle_rad
            attributes["amn_projector_max_absolute"] = result.amn_projector_max_absolute
            attributes["qualification_authority"] =
                get(qualification_metadata, "target_authority", "full_parent")
            attributes["parent_audit_policy"] =
                get(qualification_metadata, "parent_audit_policy", "audit_only")
            input_group = HDF5.create_group(handle, "input_sha256")
            write_string_dictionary(input_group, result.input_sha256)
            threshold_group = HDF5.create_group(handle, "thresholds")
            for field in fieldnames(VASPPAWParityThresholds)
                HDF5.attributes(threshold_group)[String(field)] = getfield(thresholds, field)
            end
            scope_group = HDF5.create_group(handle, "qualification_scope")
            scope_attributes = HDF5.attributes(scope_group)
            scope_attributes["outer_mask_sha256"] = qualification_scope.outer_mask_sha256
            scope_attributes["frozen_mask_sha256"] = qualification_scope.frozen_mask_sha256
            scope_attributes["diagnostic_status"] = String(qualification_scope.diagnostic_status)
            for (key, value) in qualification_metadata
                scope_attributes[key] = value
            end
            scope_group["outer_mask"] = UInt8.(qualification_scope.outer_mask)
            scope_group["frozen_mask"] = UInt8.(qualification_scope.frozen_mask)
            component_group = HDF5.create_group(handle, "component_norms")
            mmn_group = HDF5.create_group(component_group, "mmn")
            amn_group = HDF5.create_group(component_group, "amn")
            for (key, value) in mmn_component_norms
                HDF5.attributes(mmn_group)[key] = value
            end
            for (key, value) in amn_component_norms
                HDF5.attributes(amn_group)[key] = value
            end
            projection_group = HDF5.create_group(handle, "projection_contract")
            entry_count = length(projection_contract.entries)
            centers = zeros(Float64, 3, entry_count)
            translations = zeros(Int, 3, entry_count)
            local_x = zeros(Float64, 3, entry_count)
            local_z = zeros(Float64, 3, entry_count)
            spin_axes = zeros(Float64, 3, entry_count)
            principal = zeros(Int, entry_count)
            angular = zeros(Int, entry_count)
            magnetic = zeros(Int, entry_count)
            spins = zeros(Int, entry_count)
            radial_scales = zeros(Float64, entry_count)
            wannier_indices = zeros(Int, entry_count)
            for (column, entry) in enumerate(projection_contract.entries)
                centers[:, column] .= entry.center_fractional
                translations[:, column] .= entry.center_integer_translation
                local_x[:, column] .= entry.local_x_cartesian
                local_z[:, column] .= entry.local_z_cartesian
                spin_axes[:, column] .= entry.spin_quantization_axis
                principal[column] = entry.principal_quantum_number
                angular[column] = entry.angular_momentum
                magnetic[column] = entry.magnetic_index
                spins[column] = entry.spin_index
                radial_scales[column] = entry.radial_scale_inverse_angstrom
                wannier_indices[column] = entry.wannier_index
            end
            projection_group["center_fractional_vasp_image"] = centers
            projection_group["center_integer_translation"] = translations
            projection_group["local_x_cartesian"] = local_x
            projection_group["local_z_cartesian"] = local_z
            projection_group["spin_qaxis_cartesian"] = spin_axes
            projection_group["principal_quantum_number"] = principal
            projection_group["angular_momentum"] = angular
            projection_group["magnetic_index"] = magnetic
            projection_group["spin_index"] = spins
            projection_group["radial_scale_inverse_angstrom"] = radial_scales
            projection_group["wannier_index"] = wannier_indices
            gauge_group = HDF5.create_group(handle, "solver_gauge_adapter")
            gauge_diagnostics = something(result.solver_gauge_diagnostics)
            for field in fieldnames(VASPPAWSolverGaugeDiagnostics)
                HDF5.attributes(gauge_group)[String(field)] = getfield(gauge_diagnostics, field)
            end
            normalization_group = HDF5.create_group(handle, "trial_normalization")
            normalization_group["factor"] = trial_normalization.factors
            normalization_group["pseudo_norm"] = trial_normalization.pseudo_norms
            normalization_group["augmentation_norm"] = trial_normalization.augmentation_norms
            normalization_group["normalized_residual"] = trial_normalization.normalized_residuals
            channel_group = HDF5.create_group(handle, "paw_channels")
            species = String[]
            atom_indices = Int[]
            radial_channels = Int[]
            angular_momenta = Int[]
            harmonic_rows = Int[]
            for (atom_index, atom) in enumerate(paw.atoms), channel in atom.channels
                push!(species, atom.species)
                push!(atom_indices, atom_index)
                push!(radial_channels, channel.radial_channel)
                push!(angular_momenta, channel.angular_momentum)
                push!(harmonic_rows, channel.harmonic_row)
            end
            channel_group["species"] = species
            channel_group["atom_index"] = atom_indices
            channel_group["radial_channel"] = radial_channels
            channel_group["angular_momentum"] = angular_momenta
            channel_group["real_harmonic_row"] = harmonic_rows
            metric_group = HDF5.create_group(handle, "parity_metrics")
            HDF5.attributes(metric_group)["scope"] = "target_outer"
            for (name, metric) in (("mmn", result.mmn_parity), ("amn", result.amn_parity))
                metric === nothing && continue
                group = HDF5.create_group(metric_group, name)
                HDF5.attributes(group)["max_absolute"] = metric.max_absolute
                HDF5.attributes(group)["root_mean_square"] = metric.root_mean_square
                HDF5.attributes(group)["relative_l2"] = metric.relative_l2
                HDF5.attributes(group)["finite"] = metric.finite
                group["worst_index"] = metric.worst_index
            end
            parent_group = HDF5.create_group(handle, "parent_audit")
            parent_attributes = HDF5.attributes(parent_group)
            parent_attributes["policy"] = "audit_only"
            parent_attributes["status"] = String(parent_audit.status)
            parent_attributes["finite"] = parent_audit.finite
            parent_attributes["generalized_norm_max_absolute"] =
                parent_audit.generalized_norm_max_absolute
            parent_group["generalized_norm_worst_index"] =
                collect(parent_audit.generalized_norm_worst)
            parent_attributes["amn_max_principal_angle_rad"] =
                parent_audit.amn_max_principal_angle_rad
            parent_attributes["amn_projector_max_absolute"] =
                parent_audit.amn_projector_max_absolute
            parent_attributes["amn_minimum_rank"] = parent_audit.amn_minimum_rank
            parent_attributes["amn_worst_condition"] = parent_audit.amn_worst_condition
            for (name, metric) in
                (("mmn", parent_audit.mmn_parity), ("amn", parent_audit.amn_parity))
                metric === nothing && continue
                group = HDF5.create_group(parent_group, name)
                HDF5.attributes(group)["max_absolute"] = metric.max_absolute
                HDF5.attributes(group)["root_mean_square"] = metric.root_mean_square
                HDF5.attributes(group)["relative_l2"] = metric.relative_l2
                HDF5.attributes(group)["finite"] = metric.finite
                group["worst_index"] = metric.worst_index
            end
            handle["diagnostics"] = result.diagnostics
        end
    end
end

"""
Generate complete operator-specific PAW MMN and AMN matrices from VASP files.

The topology MMN is read through `WannierMMNTopology`; its numerical rows are
never parsed. Optional oracle matrices enter only after both native arrays have
been generated and written. A failed gate returns `passed=false`; callers must
fail-stop before SAWF or TB construction.
"""
function _generate_vasp_paw_matrix_elements(
    source::VASPWavefunctionSource,
    basis::WannierProjectionBasis,
    topology_mmn_file::AbstractString;
    output_mmn_file::AbstractString,
    output_amn_file::AbstractString,
    provenance_hdf5::AbstractString,
    output_solver_amn_file::Union{Nothing, AbstractString} = nothing,
    oracle_mmn_file::Union{Nothing, AbstractString} = nothing,
    oracle_amn_file::Union{Nothing, AbstractString} = nothing,
    thresholds::VASPPAWParityThresholds = VASPPAWParityThresholds(),
    require_oracle::Bool = true,
    qualification_scope::Union{Nothing, BandRepresentationQualificationScope} = nothing,
    qualification_metadata::Dict{String, String} = Dict{String, String}(),
    qualification_input_sha256::Dict{String, String} = Dict{String, String}(),
)
    source.potcar_file === nothing && throw(
        ArgumentError("VASP_PAW_DATA_REQUIRED: VASPWavefunctionSource.potcar_file is required"),
    )
    source.outcar_file === nothing && throw(
        ArgumentError("VASP_PAW_OUTCAR_REQUIRED: VASPWavefunctionSource.outcar_file is required"),
    )
    source.representation_cutoff_ev === nothing || throw(
        ArgumentError(
            "VASP_PAW_RAW_COEFFICIENTS_REQUIRED: PAW matrices require the full WAVECAR cutoff",
        ),
    )
    require_oracle &&
        (oracle_mmn_file === nothing || oracle_amn_file === nothing) &&
        throw(ArgumentError("VASP_PAW_DATA_REQUIRED: both MMN and AMN oracle files are required"))
    topology = read_wannier_mmn_topology(topology_mmn_file)
    native = read_vasp_wavefunctions(source; normalize_coefficients = false)
    get(native.source_metadata, "coefficient_normalization", "") == "vasp_raw" || throw(
        ArgumentError("VASP_PAW_RAW_COEFFICIENTS_REQUIRED: WAVECAR coefficients were normalized"),
    )
    paw = read_vasp_paw_system(something(source.potcar_file), native.structure)
    projection_contract = _build_vasp_projection_contract(source, native, basis)
    radial_q_maximum, radial_worst = _paw_radial_q_gate(paw)
    projectors = _paw_projectors(native, paw)
    parent_generalized_norm_maximum, parent_generalized_norm_worst =
        _paw_generalized_norm_residuals(native, paw, projectors)
    bands = size(first(native.kpoints).coefficients, 1)
    kpoints = length(native.kpoints)
    effective_scope = if qualification_scope === nothing
        BandRepresentationQualificationScope(trues(bands, kpoints), falses(bands, kpoints))
    else
        qualification_scope
    end
    _validate_vasp_paw_qualification_scope(effective_scope, bands, kpoints, basis.num_wannier)
    for (key, digest) in qualification_input_sha256
        occursin(r"^[0-9a-f]{64}$", digest) ||
            throw(ArgumentError("VASP_PAW_TARGET_SCOPE_HASH_MISMATCH: invalid $(key) SHA-256"))
    end
    generalized_norm_maximum, generalized_norm_worst =
        _paw_generalized_norm_residuals(native, paw, projectors, effective_scope.outer_mask)
    mmn, mmn_component_norms = _paw_generate_mmn(native, paw, projectors, topology)
    amn_q0_metric = _paw_integrated_q0_metric(paw)
    amn, amn_component_norms, trial_normalization = _paw_generate_amn(
        native,
        paw,
        projectors,
        basis,
        projection_contract;
        use_wrapped_centers = true,
        rotate_trial_spinors = true,
        normalize_trials = true,
        radial_backend = :vasp_compatible,
        trial_metric = amn_q0_metric,
        augmentation_metric = amn_q0_metric,
    )
    amn_component_norms["q0_metric_tabulated_vs_integrated_max_absolute"] =
        maximum(abs, amn_q0_metric .- paw.q0_augmentation)
    kpoints_fractional = reduce(vcat, (transpose(point.k_fractional) for point in native.kpoints))
    solver_amn, solver_gauge_diagnostics = _canonicalize_vasp_amn_for_wannierization(
        amn,
        kpoints_fractional,
        basis,
        projection_contract,
    )
    mmn_path = write_wannier_mmn(output_mmn_file, mmn)
    amn_path = write_wannier_amn(output_amn_file, amn)
    solver_amn_path = if output_solver_amn_file === nothing
        nothing
    else
        abspath(output_solver_amn_file) == abspath(output_amn_file) &&
            _vasp_paw_solver_gauge_error("raw and solver AMN output paths must differ")
        write_wannier_amn(
            output_solver_amn_file,
            solver_amn;
            comment = "Generated by WannierNLQG in the solver-facing WIN/SAWF gauge",
        )
    end

    parent_mmn_parity =
        oracle_mmn_file === nothing ? nothing :
        _paw_mmn_streaming_parity(mmn, something(oracle_mmn_file))
    mmn_parity =
        oracle_mmn_file === nothing ? nothing :
        _paw_mmn_streaming_parity(mmn, something(oracle_mmn_file), effective_scope.outer_mask)
    oracle_amn =
        oracle_amn_file === nothing ? nothing : read_wannier_amn(something(oracle_amn_file))
    parent_amn_parity =
        oracle_amn === nothing ? nothing : _paw_array_parity(amn.data, oracle_amn.data)
    amn_parity =
        oracle_amn === nothing ? nothing :
        _paw_amn_scoped_parity(amn, oracle_amn, effective_scope.outer_mask)
    parent_maximum_angle, parent_maximum_projector, parent_minimum_rank, parent_worst_condition =
        oracle_amn === nothing ? (NaN, NaN, 0, NaN) : _paw_amn_parent_audit_metrics(amn, oracle_amn)
    maximum_angle, maximum_projector, minimum_rank, worst_condition =
        oracle_amn === nothing ? (NaN, NaN, 0, NaN) :
        _paw_amn_subspace_metrics(amn, oracle_amn, effective_scope.outer_mask)

    target_finite_pass =
        isfinite(radial_q_maximum) &&
        isfinite(generalized_norm_maximum) &&
        _paw_mmn_target_finite(mmn, effective_scope.outer_mask) &&
        _paw_amn_target_finite(amn, effective_scope.outer_mask) &&
        _paw_amn_target_finite(solver_amn, effective_scope.outer_mask) &&
        (mmn_parity === nothing || something(mmn_parity).finite) &&
        (amn_parity === nothing || something(amn_parity).finite)
    parent_finite_audit =
        isfinite(parent_generalized_norm_maximum) &&
        all(isfinite, mmn.data) &&
        all(isfinite, amn.data) &&
        all(isfinite, solver_amn.data) &&
        (parent_mmn_parity === nothing || something(parent_mmn_parity).finite) &&
        (parent_amn_parity === nothing || something(parent_amn_parity).finite) &&
        (
            oracle_amn === nothing || (
                isfinite(parent_maximum_angle) &&
                isfinite(parent_maximum_projector) &&
                isfinite(parent_worst_condition)
            )
        )
    qualification = _paw_target_qualification(
        radial_q_maximum,
        generalized_norm_maximum,
        mmn_parity,
        amn_parity,
        maximum_angle,
        maximum_projector,
        minimum_rank,
        amn.num_wannier,
        target_finite_pass,
        thresholds;
        require_oracle,
    )
    parent_status = _paw_parent_audit_status(
        parent_generalized_norm_maximum,
        parent_mmn_parity,
        parent_amn_parity,
        parent_maximum_angle,
        parent_maximum_projector,
        parent_minimum_rank,
        amn.num_wannier,
        parent_finite_audit,
        thresholds,
    )
    parent_audit = VASPPAWParentAudit(
        parent_generalized_norm_maximum,
        parent_generalized_norm_worst,
        parent_mmn_parity,
        parent_amn_parity,
        parent_maximum_angle,
        parent_maximum_projector,
        parent_minimum_rank,
        parent_worst_condition,
        parent_finite_audit,
        parent_status,
    )

    qualification_authority = get(qualification_metadata, "target_authority", "full_parent")
    diagnostics = String[
        "qualification_authority=$(qualification_authority)",
        "outer_mask_sha256=$(effective_scope.outer_mask_sha256)",
        "frozen_mask_sha256=$(effective_scope.frozen_mask_sha256)",
        "radial_q_worst=$(radial_worst)",
        "target_generalized_norm_worst=$(generalized_norm_worst)",
        "target_amn_minimum_rank=$(minimum_rank)",
        "target_amn_worst_condition=$(worst_condition)",
        "target_finite_pass=$(target_finite_pass)",
        "parent_audit_status=$(parent_status)",
        "parent_finite_audit=$(parent_finite_audit)",
        "parent_generalized_norm_max_absolute=$(parent_generalized_norm_maximum)",
        "parent_generalized_norm_worst=$(parent_generalized_norm_worst)",
        "parent_amn_minimum_rank=$(parent_minimum_rank)",
        "parent_amn_worst_condition=$(parent_worst_condition)",
        "solver_gauge_maximum_unitarity_residual=$(solver_gauge_diagnostics.maximum_unitarity_residual)",
        "solver_gauge_maximum_roundtrip_absolute=$(solver_gauge_diagnostics.maximum_roundtrip_absolute)",
        "solver_gauge_maximum_projector_absolute=$(solver_gauge_diagnostics.maximum_projector_absolute)",
    ]
    qualification.target_finite_pass ||
        push!(diagnostics, "VASP_PAW_DATA_REQUIRED: non-finite target data")
    qualification.radial_pass ||
        push!(diagnostics, "VASP_PAW_RADIAL_Q_QUALITY_FAILED: radial Q gate failed")
    qualification.norm_pass ||
        push!(diagnostics, "VASP_PAW_GENERALIZED_NORM_QUALITY_FAILED: generalized norm gate failed")
    qualification.mmn_pass || push!(diagnostics, "VASP_PAW_MMN_PARITY_FAILED")
    (qualification.amn_raw_pass && qualification.amn_subspace_pass) ||
        push!(diagnostics, "VASP_PAW_AMN_PARITY_FAILED")
    passed = qualification.passed
    input_hashes = merge(
        native.input_sha256,
        Dict(
            "POTCAR" => sha256_file(something(source.potcar_file)),
            "OUTCAR" => sha256_file(something(source.outcar_file)),
            "TOPOLOGY_MMN" => sha256_file(topology_mmn_file),
            "ORACLE_MMN" =>
                oracle_mmn_file === nothing ? "NOT_PROVIDED" :
                sha256_file(something(oracle_mmn_file)),
            "ORACLE_AMN" =>
                oracle_amn_file === nothing ? "NOT_PROVIDED" :
                sha256_file(something(oracle_amn_file)),
        ),
        Dict(
            "TARGET_SCOPE_$(uppercase(key))" => value for
            (key, value) in qualification_input_sha256
        ),
    )
    artifacts = Dict(
        "mmn" => abspath(mmn_path),
        "amn" => abspath(amn_path),
        "raw_amn" => abspath(amn_path),
        "provenance_hdf5" => abspath(provenance_hdf5),
    )
    solver_amn_path === nothing || (artifacts["solver_amn"] = abspath(something(solver_amn_path)))
    result = VASPPAWMatrixElementResult(
        mmn,
        amn,
        solver_amn,
        solver_gauge_diagnostics,
        mmn_parity,
        amn_parity,
        maximum_angle,
        maximum_projector,
        radial_q_maximum,
        generalized_norm_maximum,
        passed,
        diagnostics,
        artifacts,
        input_hashes,
    )
    _write_vasp_paw_provenance(
        provenance_hdf5,
        result,
        paw,
        thresholds,
        mmn_component_norms,
        amn_component_norms,
        basis,
        projection_contract,
        trial_normalization,
        effective_scope,
        qualification_metadata,
        parent_audit,
    )
    return result
end

"""
Generate complete operator-specific PAW MMN and AMN matrices from VASP files.

The public three-positional-argument façade intentionally exposes only the
historical keywords. Target-subspace qualification is injected solely by the
internal workflow resolver.
"""
function generate_vasp_paw_matrix_elements(
    source::VASPWavefunctionSource,
    basis::WannierProjectionBasis,
    topology_mmn_file::AbstractString;
    output_mmn_file::AbstractString,
    output_amn_file::AbstractString,
    provenance_hdf5::AbstractString,
    output_solver_amn_file::Union{Nothing, AbstractString} = nothing,
    oracle_mmn_file::Union{Nothing, AbstractString} = nothing,
    oracle_amn_file::Union{Nothing, AbstractString} = nothing,
    thresholds::VASPPAWParityThresholds = VASPPAWParityThresholds(),
    require_oracle::Bool = true,
)
    return _generate_vasp_paw_matrix_elements(
        source,
        basis,
        topology_mmn_file;
        output_mmn_file,
        output_amn_file,
        provenance_hdf5,
        output_solver_amn_file,
        oracle_mmn_file,
        oracle_amn_file,
        thresholds,
        require_oracle,
    )
end
