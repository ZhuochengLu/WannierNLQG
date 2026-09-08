const VASP_PAW_NUMBER_PATTERN = r"[-+]?(?:(?:\d+\.\d*)|(?:\.\d+)|(?:\d+))(?:[EeDd][-+]?\d+)?"

"""One-dimensional cubic spline used by tabulated VASP reciprocal projectors."""
struct VASPPawCubicSpline
    x::Vector{Float64}
    a::Vector{Float64}
    b::Vector{Float64}
    c::Vector{Float64}
    d::Vector{Float64}
end

"""
Parsed PAW radial and projector data for one POTCAR element block.

Radial wave arrays are VASP's `u(r)=rR(r)` values on the POTCAR grid in
Angstrom. This unit is fixed by finite-b parity against VASP MMN, not inferred
from the dimensionless q=0 integral alone.
`angular_momenta` and all projector arrays use the POTCAR radial-channel order.
No all-electron real-space wavefunction is assembled by this type.
"""
struct VASPPawDataset
    element::String
    radial_grid_angstrom::Vector{Float64}
    pseudo_partial_waves::Vector{Vector{Float64}}
    all_electron_partial_waves::Vector{Vector{Float64}}
    reciprocal_projectors::Vector{Vector{Float64}}
    reciprocal_projector_splines::Vector{VASPPawCubicSpline}
    real_projectors::Vector{Vector{Float64}}
    angular_momenta::Vector{Int}
    q0_augmentation_radial::Matrix{Float64}
    reciprocal_grid_maximum::Float64
end

"""One expanded `(radial channel,l,real-harmonic row)` PAW channel."""
struct VASPPawChannel
    radial_channel::Int
    angular_momentum::Int
    harmonic_row::Int
end

"""PAW channel layout and fractional position for one POSCAR atom."""
struct VASPPawAtomLayout
    species::String
    position_fractional::NTuple{3, Float64}
    channel_range::UnitRange{Int}
    channels::Vector{VASPPawChannel}
end

"""
Complete per-structure PAW projector contract.

`q0_augmentation` is block diagonal in atom channels. It contains the
POTCAR-provided radial augmentation values only for equal `l` and equal real
spherical-harmonic rows, matching the standalone `vasp2spn` convention.
"""
struct VASPPawSystem
    datasets::Dict{String, VASPPawDataset}
    dataset_order::Vector{String}
    atoms::Vector{VASPPawAtomLayout}
    num_channels::Int
    q0_augmentation::Matrix{Float64}
    cell_volume_angstrom3::Float64
end

# Split one mandatory POTCAR section delimiter.
function _paw_split_once(text::AbstractString, delimiter::AbstractString)
    parts = split(text, delimiter; limit = 2)
    length(parts) == 2 ||
        throw(ArgumentError("VASP_PAW_DATA_REQUIRED: missing POTCAR section $(delimiter)"))
    return String(parts[1]), String(parts[2])
end

# Extract Fortran-notation real numbers from one POTCAR text region.
function _paw_numbers(text::AbstractString)
    return [
        parse(Float64, replace(item.match, 'D' => 'E', 'd' => 'e')) for
        item in eachmatch(VASP_PAW_NUMBER_PATTERN, text)
    ]
end

# Restore row-major numeric text into a Julia matrix without transposition ambiguity.
function _paw_row_major_matrix(values::AbstractVector{<:Real}, rows::Int, columns::Int)
    length(values) == rows * columns || throw(
        ArgumentError("POTCAR matrix has $(length(values)) values; expected $(rows * columns)"),
    )
    output = Matrix{Float64}(undef, rows, columns)
    for row in 1:rows, column in 1:columns
        output[row, column] = Float64(values[(row - 1) * columns + column])
    end
    return output
end

# Construct the same natural/clamped cubic spline used by the standalone oracle.
function _paw_cubic_spline(
    x::Vector{Float64},
    y::Vector{Float64};
    left_boundary::Tuple{Symbol, Float64} = (:second, 0.0),
    right_boundary::Tuple{Symbol, Float64} = (:second, 0.0),
)
    length(x) == length(y) || throw(ArgumentError("PAW spline x/y lengths disagree"))
    length(x) >= 2 || throw(ArgumentError("PAW spline requires at least two points"))
    spacing = diff(x)
    all(>(0.0), spacing) || throw(ArgumentError("PAW spline grid must increase"))
    count = length(x)
    system = zeros(Float64, count, count)
    right_hand_side = zeros(Float64, count)
    if left_boundary[1] == :second
        system[1, 1] = 1.0
        right_hand_side[1] = left_boundary[2] / 2.0
    elseif left_boundary[1] == :first
        system[1, 1] = 2.0 * spacing[1]
        system[1, 2] = spacing[1]
        right_hand_side[1] = 3.0 * ((y[2] - y[1]) / spacing[1] - left_boundary[2])
    else
        throw(ArgumentError("unsupported PAW spline left boundary"))
    end
    for index in 2:(count - 1)
        system[index, index - 1] = spacing[index - 1]
        system[index, index] = 2.0 * (spacing[index - 1] + spacing[index])
        system[index, index + 1] = spacing[index]
        right_hand_side[index] =
            3.0 * (
                (y[index + 1] - y[index]) / spacing[index] -
                (y[index] - y[index - 1]) / spacing[index - 1]
            )
    end
    if right_boundary[1] == :second
        system[count, count] = 1.0
        right_hand_side[count] = right_boundary[2] / 2.0
    elseif right_boundary[1] == :first
        system[count, count - 1] = spacing[end]
        system[count, count] = 2.0 * spacing[end]
        right_hand_side[count] = 3.0 * (right_boundary[2] - (y[end] - y[end - 1]) / spacing[end])
    else
        throw(ArgumentError("unsupported PAW spline right boundary"))
    end
    curvature = system \ right_hand_side
    linear = Vector{Float64}(undef, count - 1)
    cubic = Vector{Float64}(undef, count - 1)
    for index in 1:(count - 1)
        linear[index] =
            (y[index + 1] - y[index]) / spacing[index] -
            spacing[index] * (2.0 * curvature[index] + curvature[index + 1]) / 3.0
        cubic[index] = (curvature[index + 1] - curvature[index]) / (3.0 * spacing[index])
    end
    return VASPPawCubicSpline(copy(x), copy(y[1:(end - 1)]), linear, curvature, cubic)
end

# Evaluate a projector spline and return NaN outside its tabulated domain.
function (spline::VASPPawCubicSpline)(value::Real)
    coordinate = Float64(value)
    coordinate < first(spline.x) && return NaN
    coordinate > last(spline.x) && return NaN
    interval = clamp(searchsortedlast(spline.x, coordinate), 1, length(spline.x) - 1)
    displacement = coordinate - spline.x[interval]
    return spline.a[interval] +
           spline.b[interval] * displacement +
           spline.c[interval] * displacement^2 +
           spline.d[interval] * displacement^3
end

# Parse one element label from the leading PAW dataset title.
function _paw_dataset_element(text::AbstractString)
    first_line = first(split(strip(text), '\n'; limit = 2))
    tokens = split(strip(first_line))
    length(tokens) >= 2 || throw(ArgumentError("POTCAR dataset title is malformed"))
    return String(first(split(tokens[2], '_'; limit = 2)))
end

"""
    _parse_vasp_paw_dataset(text) -> VASPPawDataset

Parse exactly the POTCAR radial/projector fields consumed by PAW MMN/AMN.
The literal misspelling `non sperical` is part of the VASP dataset protocol.
"""
function _parse_vasp_paw_dataset(text::AbstractString)
    element = _paw_dataset_element(text)
    nonradial, radial = _paw_split_once(text, "PAW radial sets")
    partial_terms = split(radial, "pseudo wavefunction")
    length(partial_terms) >= 2 ||
        throw(ArgumentError("VASP_PAW_DATA_REQUIRED: no pseudo partial waves for $(element)"))
    grid_text = String(first(partial_terms))
    partial_wave_texts = String.(partial_terms[2:end])
    augmentation_and_core, grid_text = _paw_split_once(grid_text, "grid")
    grid_text, _ = _paw_split_once(grid_text, "aepotential")
    radial_grid = _paw_numbers(grid_text)
    length(radial_grid) >= 3 || throw(ArgumentError("POTCAR radial grid is truncated"))
    augmentation_text, _ = _paw_split_once(augmentation_and_core, "uccopancies in atom")
    _, augmentation_text = _paw_split_once(augmentation_text, "augmentation charges (non sperical)")
    augmentation_values = _paw_numbers(augmentation_text)

    pseudo_partial_waves = Vector{Vector{Float64}}()
    all_electron_partial_waves = Vector{Vector{Float64}}()
    for partial_wave_text in partial_wave_texts
        pseudo_text, all_electron_text = _paw_split_once(partial_wave_text, "ae wavefunction")
        push!(pseudo_partial_waves, _paw_numbers(pseudo_text))
        push!(all_electron_partial_waves, _paw_numbers(all_electron_text))
    end

    projector_terms = split(nonradial, "Non local Part")
    top_text = String(first(projector_terms))
    projector_texts = String.(projector_terms[2:end])
    isempty(projector_texts) &&
        throw(ArgumentError("VASP_PAW_DATA_REQUIRED: no projector blocks for $(element)"))
    reciprocal_grid_maximum = parse(Float64, split(top_text)[end - 1])
    reciprocal_projectors = Vector{Vector{Float64}}()
    real_projectors = Vector{Vector{Float64}}()
    angular_momenta = Int[]
    for projector_text in projector_texts
        pieces = split(projector_text, "Reciprocal Space Part")
        length(pieces) >= 2 || throw(ArgumentError("POTCAR projector block is malformed"))
        nonlocal_values = _paw_numbers(String(first(pieces)))
        length(nonlocal_values) >= 3 ||
            throw(ArgumentError("POTCAR nonlocal projector header is malformed"))
        angular_momentum = Int(floor(first(nonlocal_values)))
        for projector_part in pieces[2:end]
            reciprocal_text, real_text = _paw_split_once(String(projector_part), "Real Space Part")
            tabulated = _paw_numbers(reciprocal_text)
            length(tabulated) == 100 || throw(
                ArgumentError(
                    "POTCAR reciprocal projector has $(length(tabulated)) values, expected 100",
                ),
            )
            reciprocal = zeros(Float64, 101)
            reciprocal[2:end] .= tabulated
            reciprocal[1] = iseven(angular_momentum) ? reciprocal[3] : -reciprocal[3]
            push!(reciprocal_projectors, reciprocal)
            push!(real_projectors, _paw_numbers(real_text))
            push!(angular_momenta, angular_momentum)
        end
    end

    channel_count = length(angular_momenta)
    length(pseudo_partial_waves) == channel_count || throw(
        ArgumentError("POTCAR pseudo partial-wave and projector counts disagree for $(element)"),
    )
    length(all_electron_partial_waves) == channel_count || throw(
        ArgumentError(
            "POTCAR all-electron partial-wave and projector counts disagree for $(element)",
        ),
    )
    all(length(wave) == length(radial_grid) for wave in pseudo_partial_waves) ||
        throw(ArgumentError("POTCAR pseudo partial-wave grid lengths disagree"))
    all(length(wave) == length(radial_grid) for wave in all_electron_partial_waves) ||
        throw(ArgumentError("POTCAR all-electron partial-wave grid lengths disagree"))
    q0 = _paw_row_major_matrix(augmentation_values, channel_count, channel_count)
    reciprocal_grid = collect(-1:99) .* reciprocal_grid_maximum ./ 100.0
    splines = [_paw_cubic_spline(reciprocal_grid, values) for values in reciprocal_projectors]
    return VASPPawDataset(
        element,
        radial_grid,
        pseudo_partial_waves,
        all_electron_partial_waves,
        reciprocal_projectors,
        splines,
        real_projectors,
        angular_momenta,
        q0,
        reciprocal_grid_maximum,
    )
end

"""
    _read_vasp_paw_system(potcar_file, structure) -> VASPPawSystem

Parse concatenated POTCAR datasets, require exact POSCAR/POTCAR element order,
and expand radial channels into per-atom real-harmonic channel ranges.
"""
function _read_vasp_paw_system(potcar_file::AbstractString, structure::CrystalStructure)
    isfile(potcar_file) ||
        throw(ArgumentError("VASP_PAW_DATA_REQUIRED: POTCAR does not exist: $(potcar_file)"))
    blocks = [
        String(block) for block in split(strip(read(potcar_file, String)), "End of Dataset") if
        !isempty(strip(block))
    ]
    isempty(blocks) && throw(ArgumentError("VASP_PAW_DATA_REQUIRED: POTCAR has no datasets"))
    parsed = [_parse_vasp_paw_dataset(block) for block in blocks]
    dataset_order = [dataset.element for dataset in parsed]
    structure_order = unique(structure.species)
    dataset_order == structure_order || throw(
        ArgumentError(
            "VASP_PAW_ELEMENT_ORDER_MISMATCH: POTCAR $(dataset_order) versus POSCAR $(structure_order)",
        ),
    )
    datasets = Dict(dataset.element => dataset for dataset in parsed)
    atoms = VASPPawAtomLayout[]
    next_channel = 1
    for atom_index in eachindex(structure.species)
        species = structure.species[atom_index]
        dataset = datasets[species]
        channels = VASPPawChannel[]
        for radial_channel in eachindex(dataset.angular_momenta)
            angular_momentum = dataset.angular_momenta[radial_channel]
            for harmonic_row in 1:(2 * angular_momentum + 1)
                push!(channels, VASPPawChannel(radial_channel, angular_momentum, harmonic_row))
            end
        end
        channel_range = next_channel:(next_channel + length(channels) - 1)
        position = Tuple(Float64.(structure.positions_fractional[:, atom_index]))
        push!(atoms, VASPPawAtomLayout(species, position, channel_range, channels))
        next_channel += length(channels)
    end
    num_channels = next_channel - 1
    q0 = zeros(Float64, num_channels, num_channels)
    for atom in atoms
        dataset = datasets[atom.species]
        for (left_local, left_channel) in enumerate(atom.channels)
            for (right_local, right_channel) in enumerate(atom.channels)
                left_channel.angular_momentum == right_channel.angular_momentum || continue
                left_channel.harmonic_row == right_channel.harmonic_row || continue
                q0[
                    first(atom.channel_range) + left_local - 1,
                    first(atom.channel_range) + right_local - 1,
                ] = dataset.q0_augmentation_radial[
                    left_channel.radial_channel,
                    right_channel.radial_channel,
                ]
            end
        end
    end
    return VASPPawSystem(
        datasets,
        dataset_order,
        atoms,
        num_channels,
        q0,
        abs(det(structure.lattice)),
    )
end

# Integrate a radial function on the logarithmic POTCAR grid with composite Simpson weights.
function _paw_logarithmic_simpson(grid::Vector{Float64}, values::Vector{Float64})
    length(grid) == length(values) || throw(ArgumentError("radial integrand size mismatch"))
    length(grid) >= 3 || throw(ArgumentError("radial integral needs at least three points"))
    log_grid = log.(grid)
    spacing = (last(log_grid) - first(log_grid)) / (length(log_grid) - 1)
    maximum(abs.(diff(log_grid) .- spacing)) <= 1.0e-8 * max(1.0, abs(spacing)) ||
        throw(ArgumentError("POTCAR radial grid is not logarithmically uniform"))
    transformed = values .* grid
    last_simpson = isodd(length(grid)) ? length(grid) : length(grid) - 1
    total = transformed[1] + transformed[last_simpson]
    for index in 2:(last_simpson - 1)
        total += (iseven(index) ? 4.0 : 2.0) * transformed[index]
    end
    integral = spacing * total / 3.0
    if last_simpson < length(grid)
        integral +=
            (log_grid[end] - log_grid[end - 1]) * (transformed[end - 1] + transformed[end]) / 2.0
    end
    return integral
end

# Compute independent radial q=0 augmentation integrals from AE and pseudo partial waves.
function _paw_radial_q0(dataset::VASPPawDataset)
    count = length(dataset.angular_momenta)
    values = zeros(Float64, count, count)
    for left in 1:count, right in 1:count
        integrand =
            dataset.all_electron_partial_waves[left] .* dataset.all_electron_partial_waves[right] .-
            dataset.pseudo_partial_waves[left] .* dataset.pseudo_partial_waves[right]
        values[left, right] = _paw_logarithmic_simpson(dataset.radial_grid_angstrom, integrand)
    end
    return values
end
