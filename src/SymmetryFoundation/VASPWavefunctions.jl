"""Validated fixed-record metadata from a VASP WAVECAR header."""
struct VASPWavecarHeader
    record_length::Int
    spin_channels::Int
    precision_tag::Int
    num_kpoints::Int
    num_bands::Int
    cutoff_ev::Float64
    real_lattice::Matrix{Float64}
    reciprocal_lattice::Matrix{Float64}
    fermi_energy_ev::Float64
    coefficient_type::DataType
end

"""
Parse a row-major numeric matrix used in VASP text and binary metadata.
"""
function row_major_matrix(values::AbstractVector{<:Real}, rows::Int, columns::Int)
    length(values) == rows * columns ||
        throw(ArgumentError("expected $(rows * columns) matrix values"))
    output = Matrix{Float64}(undef, rows, columns)
    for row in 1:rows, column in 1:columns
        output[row, column] = Float64(values[(row - 1) * columns + column])
    end
    return output
end

# Read fixed-count native values from one byte offset and reject truncation.
function read_values_at(io::Base.IO, ::Type{T}, offset::Integer, count::Int) where {T}
    seek(io, Int64(offset))
    values = Vector{T}(undef, count)
    readbytes = readbytes!(io, reinterpret(UInt8, values), sizeof(T) * count)
    readbytes == sizeof(T) * count ||
        throw(ArgumentError("truncated fixed WAVECAR record at byte $(offset)"))
    return values
end

# Parse VASP5-style POSCAR structure data without modifying the file.
function read_poscar_structure(filename::AbstractString; magnetic_moments_cartesian = nothing)
    isfile(filename) || throw(ArgumentError("POSCAR does not exist: $(filename)"))
    lines = readlines(filename)
    length(lines) >= 8 || throw(ArgumentError("POSCAR is truncated"))
    scale = parse(Float64, split(strip(lines[2]))[1])
    scale > 0.0 || throw(ArgumentError("negative-volume POSCAR scaling is not supported"))
    lattice = Matrix{Float64}(undef, 3, 3)
    for row in 1:3
        values = parse.(Float64, split(strip(lines[2 + row])))
        length(values) >= 3 || throw(ArgumentError("POSCAR lattice row $(row) is malformed"))
        lattice[row, :] .= scale .* values[1:3]
    end
    species = split(strip(lines[6]))
    counts = parse.(Int, split(strip(lines[7])))
    length(species) == length(counts) || throw(ArgumentError("POSCAR species/count rows disagree"))
    coordinate_line = 8
    if startswith(lowercase(strip(lines[coordinate_line])), "s")
        coordinate_line += 1
    end
    mode = lowercase(strip(lines[coordinate_line]))
    coordinate_line += 1
    atom_count = sum(counts)
    length(lines) >= coordinate_line + atom_count - 1 ||
        throw(ArgumentError("POSCAR coordinate block is truncated"))
    positions = Matrix{Float64}(undef, 3, atom_count)
    labels = String[]
    atom = 1
    for (label, count) in zip(species, counts)
        for _ in 1:count
            values = parse.(Float64, split(strip(lines[coordinate_line + atom - 1]))[1:3])
            positions[:, atom] .= values
            push!(labels, label)
            atom += 1
        end
    end
    if startswith(mode, "c") || startswith(mode, "k")
        positions .= transpose(inv(lattice)) * (scale .* positions)
    elseif !startswith(mode, "d")
        throw(ArgumentError("POSCAR coordinate mode must be Direct or Cartesian"))
    end
    return CrystalStructure(lattice, labels, positions; magnetic_moments_cartesian)
end

"""
Parse the two global WAVECAR header records.
"""
function read_vasp_wavecar_header(filename::AbstractString)
    isfile(filename) || throw(ArgumentError("WAVECAR does not exist: $(filename)"))
    return open(filename, "r") do io
        first_record = read_values_at(io, Float64, 0, 3)
        record_length, spin_channels, precision_tag = Int.(floor.(first_record))
        record_length > 0 || throw(ArgumentError("WAVECAR record length is invalid"))
        precision_tag in (45200, 45210) ||
            throw(ArgumentError("unsupported WAVECAR precision tag $(precision_tag)"))
        second_record = read_values_at(io, Float64, record_length, 13)
        num_kpoints, num_bands = Int.(floor.(second_record[1:2]))
        cutoff_ev = second_record[3]
        lattice = row_major_matrix(second_record[4:12], 3, 3)
        reciprocal = 2.0 * pi * inv(lattice)'
        coefficient_type = precision_tag == 45200 ? ComplexF32 : ComplexF64
        VASPWavecarHeader(
            record_length,
            spin_channels,
            precision_tag,
            num_kpoints,
            num_bands,
            cutoff_ev,
            lattice,
            reciprocal,
            second_record[13],
            coefficient_type,
        )
    end
end

# Return conservative reciprocal grid bounds for one WAVECAR cutoff sphere.
function _vasp_grid_bounds(reciprocal::Matrix{Float64}, cutoff_ev::Float64)
    magnitudes = vec(norm.(eachrow(reciprocal)))
    bounds = zeros(Int, 3, 3)
    angle12 = acos(dot(reciprocal[1, :], reciprocal[2, :]) / magnitudes[1] / magnitudes[2])
    cross12 = cross(reciprocal[1, :], reciprocal[2, :])
    sine123 = dot(reciprocal[3, :], cross12) / magnitudes[3] / norm(cross12)
    bounds[1, 1] =
        floor(
            Int,
            sqrt(cutoff_ev * NATIVE_WAVECAR_ENERGY_FACTOR) / abs(sin(angle12)) / magnitudes[1],
        ) + 1
    bounds[1, 2] =
        floor(
            Int,
            sqrt(cutoff_ev * NATIVE_WAVECAR_ENERGY_FACTOR) / abs(sin(angle12)) / magnitudes[2],
        ) + 1
    bounds[1, 3] =
        floor(Int, sqrt(cutoff_ev * NATIVE_WAVECAR_ENERGY_FACTOR) / abs(sine123) / magnitudes[3]) +
        1
    angle13 = acos(dot(reciprocal[1, :], reciprocal[3, :]) / magnitudes[1] / magnitudes[3])
    cross13 = cross(reciprocal[1, :], reciprocal[3, :])
    sine123 = dot(reciprocal[2, :], cross13) / magnitudes[2] / norm(cross13)
    bounds[2, 1] =
        floor(
            Int,
            sqrt(cutoff_ev * NATIVE_WAVECAR_ENERGY_FACTOR) / abs(sin(angle13)) / magnitudes[1],
        ) + 1
    bounds[2, 2] =
        floor(Int, sqrt(cutoff_ev * NATIVE_WAVECAR_ENERGY_FACTOR) / abs(sine123) / magnitudes[2]) +
        1
    bounds[2, 3] =
        floor(
            Int,
            sqrt(cutoff_ev * NATIVE_WAVECAR_ENERGY_FACTOR) / abs(sin(angle13)) / magnitudes[3],
        ) + 1
    angle23 = acos(dot(reciprocal[2, :], reciprocal[3, :]) / magnitudes[2] / magnitudes[3])
    cross23 = cross(reciprocal[2, :], reciprocal[3, :])
    sine123 = dot(reciprocal[1, :], cross23) / magnitudes[1] / norm(cross23)
    bounds[3, 1] =
        floor(Int, sqrt(cutoff_ev * NATIVE_WAVECAR_ENERGY_FACTOR) / abs(sine123) / magnitudes[1]) +
        1
    bounds[3, 2] =
        floor(
            Int,
            sqrt(cutoff_ev * NATIVE_WAVECAR_ENERGY_FACTOR) / abs(sin(angle23)) / magnitudes[2],
        ) + 1
    bounds[3, 3] =
        floor(
            Int,
            sqrt(cutoff_ev * NATIVE_WAVECAR_ENERGY_FACTOR) / abs(sin(angle23)) / magnitudes[3],
        ) + 1
    return vec(maximum(bounds; dims = 1))
end

# Return one FFT-style integer axis in VASP plane-wave storage order.
function _vasp_grid_axis(bound::Int)
    return [value <= bound ? value : value - 2 * bound - 1 for value in 0:(2 * bound)]
end

# Materialize VASP's x-fastest plane-wave grid ordering.
function _vasp_g_grid(bounds::Vector{Int})
    x, y, z = (_vasp_grid_axis(bounds[index]) for index in 1:3)
    output = Matrix{Int}(undef, length(x) * length(y) * length(z), 3)
    row = 1
    for zvalue in z, yvalue in y, xvalue in x
        output[row, :] .= (xvalue, yvalue, zvalue)
        row += 1
    end
    return output
end

# Select full-cutoff WAVECAR G rows for one k-point.
function _vasp_cutoff_rows(
    grid::Matrix{Int},
    kpoint::AbstractVector{<:Real},
    reciprocal::Matrix{Float64},
    cutoff_ev::Float64,
)
    return [
        row for row in axes(grid, 1) if
        plane_wave_energy_ev(@view(grid[row, :]) .+ kpoint, reciprocal) < cutoff_ev
    ]
end

"""
Read selected VASP bands and plane waves into the native representation boundary.
"""
function read_vasp_wavefunctions(
    source::VASPWavefunctionSource;
    normalize_coefficients::Bool = true,
    require_spin_basis::Bool = true,
)
    header = read_vasp_wavecar_header(source.wavecar_file)
    saxis = _read_vasp_saxis(source)
    spin_transform = saxis === nothing ? nothing : _vasp_saxis_spin_transform(saxis)
    source.spin_channel <= header.spin_channels ||
        throw(ArgumentError("requested VASP spin channel exceeds WAVECAR nspin"))
    structure = read_poscar_structure(
        source.poscar_file;
        magnetic_moments_cartesian = source.magnetic_moments_cartesian,
    )
    moment_source_status = validate_vasp_magnetic_moment_sources(source, length(structure.species))
    isapprox(structure.lattice, header.real_lattice; atol = 1.0e-7, rtol = 0.0) ||
        throw(ArgumentError("POSCAR and WAVECAR lattices disagree"))
    cutoff =
        source.representation_cutoff_ev === nothing ? header.cutoff_ev :
        source.representation_cutoff_ev
    cutoff <= header.cutoff_ev + 1.0e-10 ||
        throw(ArgumentError("representation cutoff exceeds the WAVECAR cutoff"))
    bands = selected_band_range(source.band_range, header.num_bands)
    bounds = _vasp_grid_bounds(header.reciprocal_lattice, header.cutoff_ev)
    grid = _vasp_g_grid(bounds)
    points = PlaneWaveKPoint[]
    kpoint_matrix = zeros(Float64, header.num_kpoints, 3)
    detected_spinor = false
    open(source.wavecar_file, "r") do io
        for kpoint_index in 1:header.num_kpoints
            header_record_index =
                2 +
                (source.spin_channel - 1) * header.num_kpoints * (header.num_bands + 1) +
                (kpoint_index - 1) * (header.num_bands + 1)
            record = read_values_at(
                io,
                Float64,
                header.record_length * header_record_index,
                4 + 3 * header.num_bands,
            )
            stored_count = Int(floor(record[1]))
            kpoint = record[2:4]
            kpoint_matrix[kpoint_index, :] .= kpoint
            band_table = row_major_matrix(record[5:end], header.num_bands, 3)
            full_rows = _vasp_cutoff_rows(grid, kpoint, header.reciprocal_lattice, header.cutoff_ev)
            spin_components = stored_count == length(full_rows) ? 1 : 2
            stored_count == spin_components * length(full_rows) || throw(
                ArgumentError(
                    "WAVECAR plane-wave count $(stored_count) is neither scalar nor spinor " *
                    "for reconstructed count $(length(full_rows)) at k-point $(kpoint_index)",
                ),
            )
            detected_spinor |= spin_components == 2
            spin_components == 2 &&
                require_spin_basis &&
                spin_transform === nothing &&
                throw(
                    ArgumentError(
                        "magnetic spinor WAVECAR requires explicit INCAR SAXIS or spin_basis_saxis",
                    ),
                )
            source.spinor === nothing ||
                source.spinor == (spin_components == 2) ||
                throw(ArgumentError("configured VASP spinor convention disagrees with WAVECAR"))
            retained_positions = [
                position for
                (position, grid_row) in enumerate(full_rows) if plane_wave_energy_ev(
                    @view(grid[grid_row, :]) .+ kpoint,
                    header.reciprocal_lattice,
                ) < cutoff
            ]
            retained_g = grid[full_rows[retained_positions], :]
            coefficients =
                zeros(ComplexF64, length(bands), length(retained_positions), spin_components)
            for (output_band, band) in enumerate(bands)
                band_record_index = header_record_index + band
                raw = read_values_at(
                    io,
                    header.coefficient_type,
                    header.record_length * band_record_index,
                    stored_count,
                )
                reshaped = reshape(raw, length(full_rows), spin_components)
                coefficients[output_band, :, :] .= reshaped[retained_positions, :]
            end
            if spin_components == 2 && spin_transform !== nothing
                for band in axes(coefficients, 1), g_index in axes(coefficients, 2)
                    coefficients[band, g_index, :] .=
                        something(spin_transform) * @view(coefficients[band, g_index, :])
                end
            end
            push!(
                points,
                PlaneWaveKPoint(
                    kpoint,
                    retained_g,
                    coefficients,
                    band_table[bands, 1];
                    normalize_coefficients,
                ),
            )
        end
    end
    all(point -> size(point.coefficients, 3) == (detected_spinor ? 2 : 1), points) ||
        throw(ArgumentError("WAVECAR spinor convention changes across k-points"))
    return NativeWavefunctionData(
        :vasp,
        structure,
        header.reciprocal_lattice,
        infer_mp_grid(kpoint_matrix),
        detected_spinor,
        points,
        merge(
            Dict(
                "POSCAR" => sha256_file(source.poscar_file),
                "WAVECAR" => sha256_file(source.wavecar_file),
                "INCAR" =>
                    source.incar_file === nothing ?
                    require_spin_basis ? "EXPLICIT_SPIN_BASIS" : "SCALAR_OVERLAP_NOT_REQUIRED" :
                    sha256_file(something(source.incar_file)),
            ),
            source.magnetic_moments_cartesian === nothing ? Dict{String, String}() :
            Dict(
                "MAGNETIC_MOMENTS_CARTESIAN" =>
                    magnetic_moments_sha256(something(source.magnetic_moments_cartesian)),
            ),
        ),
        merge(
            Dict(
                "spin_mode" =>
                    header.spin_channels > 1 && !detected_spinor ? "collinear_single_channel" :
                    detected_spinor ? "noncollinear_spinor" : "scalar",
                "spin_channel" => string(source.spin_channel),
                "spin_basis_input" => source.incar_file === nothing ? "explicit" : "INCAR:SAXIS",
                "saxis" => saxis === nothing ? "not_applicable" : join(saxis, ","),
                "spin_basis" => "Cartesian-z Pauli basis",
                "coefficient_normalization" =>
                    normalize_coefficients ? "euclidean_per_band" : "vasp_raw",
            ),
            source.magnetic_moments_cartesian === nothing ? Dict{String, String}() :
            Dict(
                "magnetic_moments_sha256" =>
                    magnetic_moments_sha256(something(source.magnetic_moments_cartesian)),
                "magnetic_moments_coordinate_system" => "cartesian",
                "magnetic_moments_vector_kind" => "axial",
                "magnetic_moments_secondary_source" => String(moment_source_status),
            ),
        ),
    )
end
