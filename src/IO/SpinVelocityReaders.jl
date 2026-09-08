# Spin-velocity input readers for Wannier EIG/MMN data.

using LinearAlgebra

"""
Band energies in eV as `data[band,kpoint]` from a Wannier90 EIG file.

Construction requires positive counts and the exact declared matrix shape; the supplied array is retained without copying.
"""
struct WannierEIG
    num_bands::Int
    num_kpts::Int
    data::Matrix{Float64}

    function WannierEIG(num_bands::Int, num_kpts::Int, data::Matrix{Float64})
        num_bands > 0 || error("EIG num_bands must be positive, got $(num_bands).")
        num_kpts > 0 || error("EIG num_kpts must be positive, got $(num_kpts).")
        size(data) == (num_bands, num_kpts) ||
            error("EIG data has size $(size(data)); expected ($(num_bands), $(num_kpts)).")
        return new(num_bands, num_kpts, data)
    end
end

"""
Dimensionless neighboring Bloch-state overlaps in `(band,band,neighbor,kpoint)` order, with neighbor indices and integer reciprocal shifts.

Construction validates positive dimensions and array shapes and retains the supplied arrays in their original gauge.
"""
struct WannierMMN
    num_bands::Int
    num_kpts::Int
    num_neighbors::Int
    data::Array{ComplexF64, 4}
    neighbors::Matrix{Int}
    reciprocal_shifts::Array{Int, 3}

    function WannierMMN(
        num_bands::Int,
        num_kpts::Int,
        num_neighbors::Int,
        data::Array{ComplexF64, 4},
        neighbors::Matrix{Int},
        reciprocal_shifts::Array{Int, 3},
    )
        num_bands > 0 || error("MMN num_bands must be positive, got $(num_bands).")
        num_kpts > 0 || error("MMN num_kpts must be positive, got $(num_kpts).")
        num_neighbors > 0 || error("MMN num_neighbors must be positive, got $(num_neighbors).")
        size(data) == (num_bands, num_bands, num_neighbors, num_kpts) || error(
            "MMN data has size $(size(data)); expected " *
            "($(num_bands), $(num_bands), $(num_neighbors), $(num_kpts)).",
        )
        size(neighbors) == (num_neighbors, num_kpts) || error(
            "MMN neighbors has size $(size(neighbors)); expected ($(num_neighbors), $(num_kpts)).",
        )
        size(reciprocal_shifts) == (3, num_neighbors, num_kpts) ||
            error("MMN reciprocal shifts have incompatible dimensions.")
        return new(num_bands, num_kpts, num_neighbors, data, neighbors, reciprocal_shifts)
    end
end

"""
Neighbour topology from a formatted Wannier90 MMN file without matrix values.

This type is the only MMN input admitted by the native VASP PAW generator.
Keeping it distinct from `WannierMMN` makes it impossible for oracle matrix
values to enter the construction path accidentally.
"""
struct WannierMMNTopology
    num_bands::Int
    num_kpts::Int
    num_neighbors::Int
    neighbors::Matrix{Int}
    reciprocal_shifts::Array{Int, 3}

    function WannierMMNTopology(
        num_bands::Int,
        num_kpts::Int,
        num_neighbors::Int,
        neighbors::Matrix{Int},
        reciprocal_shifts::Array{Int, 3},
    )
        num_bands > 0 || throw(ArgumentError("MMN topology band count must be positive"))
        num_kpts > 0 || throw(ArgumentError("MMN topology k-point count must be positive"))
        num_neighbors > 0 || throw(ArgumentError("MMN topology neighbour count must be positive"))
        size(neighbors) == (num_neighbors, num_kpts) ||
            throw(ArgumentError("MMN topology neighbour dimensions disagree"))
        size(reciprocal_shifts) == (3, num_neighbors, num_kpts) ||
            throw(ArgumentError("MMN topology reciprocal-shift dimensions disagree"))
        return new(num_bands, num_kpts, num_neighbors, neighbors, reciprocal_shifts)
    end
end

"""
Parse indexed Wannier90 band energies in eV into a `(band,kpoint)` matrix.

Reject missing, duplicate or malformed rows and preserve the file's one-based band/k-point numbering.

Read wannier eig from its configured input.
"""
function read_wannier_eig(filename::AbstractString)::WannierEIG
    isfile(filename) || error("EIG file does not exist: $(filename)")
    rows = Tuple{Int, Int, Float64}[]
    max_band = 0
    max_kpt = 0
    open(filename, "r") do io
        for (lineno, line) in enumerate(eachline(io))
            stripped = strip(line)
            isempty(stripped) && continue
            parts = split(stripped)
            length(parts) >= 3 || error("Malformed EIG row at line $(lineno) in $(filename).")
            ib = parse(Int, parts[1])
            kpoint_index = parse(Int, parts[2])
            energy = parse(Float64, parts[3])
            ib > 0 && kpoint_index > 0 || error("EIG indices must be positive at line $(lineno).")
            max_band = max(max_band, ib)
            max_kpt = max(max_kpt, kpoint_index)
            push!(rows, (ib, kpoint_index, energy))
        end
    end
    isempty(rows) && error("EIG file $(filename) contains no data rows.")
    data = zeros(Float64, max_band, max_kpt)
    filled = falses(max_band, max_kpt)
    for (ib, kpoint_index, energy) in rows
        filled[ib, kpoint_index] &&
            error("Duplicate EIG row for band=$(ib), k-point=$(kpoint_index).")
        data[ib, kpoint_index] = energy
        filled[ib, kpoint_index] = true
    end
    all(filled) || error("EIG file $(filename) is incomplete; expected $(max_band * max_kpt) rows.")
    return WannierEIG(max_band, max_kpt, data)
end

"""
Write one formatted Wannier90 EIG file in band-major, k-point-minor order.

The supplied matrix uses `data[band,kpoint]`. Publication is atomic and the
returned path is absolute; no energy shift or unit conversion is applied.
"""
function write_wannier_eig(filename::AbstractString, eig::WannierEIG)
    path = abspath(filename)
    mkpath(dirname(path))
    temporary, stream = mktemp(dirname(path); cleanup = false)
    completed = false
    try
        for kpoint in 1:eig.num_kpts, band in 1:eig.num_bands
            @printf(stream, "%5d %5d %22.14f\n", band, kpoint, eig.data[band, kpoint])
        end
        close(stream)
        mv(temporary, path; force = true)
        completed = true
    finally
        isopen(stream) && close(stream)
        !completed && isfile(temporary) && rm(temporary; force = true)
    end
    return path
end

"""
Read formatted neighboring Bloch overlaps and integer reciprocal shifts into `WannierMMN`.

Preserve dimensionless input-gauge matrix entries and neighbor order; reject malformed or inconsistent dimensions/topology.

Read wannier mmn from its configured input.
"""
function read_wannier_mmn(filename::AbstractString)::WannierMMN
    isfile(filename) || error("MMN file does not exist: $(filename)")
    open(filename, "r") do io
        _ = readline(io)
        dims = split(strip(readline(io)))
        length(dims) >= 3 || error("MMN file $(filename) has malformed dimension line.")
        nb = parse(Int, dims[1])
        num_kpoints = parse(Int, dims[2])
        num_neighbors = parse(Int, dims[3])
        data_path, data_io = mktemp(; cleanup = true)
        data_size = sizeof(ComplexF64) * nb * nb * num_neighbors * num_kpoints
        truncate(data_io, data_size)
        data = Mmap.mmap(data_io, Array{ComplexF64, 4}, (nb, nb, num_neighbors, num_kpoints))
        close(data_io)
        neighbors = Matrix{Int}(undef, num_neighbors, num_kpoints)
        reciprocal_shifts = Array{Int, 3}(undef, 3, num_neighbors, num_kpoints)
        for kpoint_index in 1:num_kpoints
            for ib in 1:num_neighbors
                eof(io) && error(
                    "MMN file ended before header for kpoint_index=$(kpoint_index), ib=$(ib).",
                )
                header = split(strip(readline(io)))
                length(header) >= 5 || error(
                    "Malformed MMN neighbour header at kpoint_index=$(kpoint_index), ib=$(ib).",
                )
                file_ik = parse(Int, header[1])
                file_ik == kpoint_index ||
                    error("MMN header kpoint_index=$(file_ik) but expected $(kpoint_index).")
                neighbors[ib, kpoint_index] = parse(Int, header[2])
                reciprocal_shifts[1, ib, kpoint_index] = parse(Int, header[3])
                reciprocal_shifts[2, ib, kpoint_index] = parse(Int, header[4])
                reciprocal_shifts[3, ib, kpoint_index] = parse(Int, header[5])
                for m in 1:nb
                    for n in 1:nb
                        eof(io) && error(
                            "MMN file ended inside block kpoint_index=$(kpoint_index), ib=$(ib).",
                        )
                        row = split(strip(readline(io)))
                        length(row) >= 2 || error(
                            "Malformed MMN matrix row at kpoint_index=$(kpoint_index), ib=$(ib), m=$(m), n=$(n).",
                        )
                        data[n, m, ib, kpoint_index] =
                            ComplexF64(parse(Float64, row[1]), parse(Float64, row[2]))
                    end
                end
            end
        end
        return WannierMMN(nb, num_kpoints, num_neighbors, data, neighbors, reciprocal_shifts)
    end
end

"""
    read_wannier_mmn_topology(filename) -> WannierMMNTopology

Read only neighbour indices and reciprocal shifts from formatted MMN. Matrix
rows are consumed as opaque lines and never parsed as floating-point values.
"""
function read_wannier_mmn_topology(filename::AbstractString)::WannierMMNTopology
    isfile(filename) || throw(ArgumentError("MMN file does not exist: $(filename)"))
    return open(filename, "r") do io
        eof(io) && throw(ArgumentError("MMN file is empty: $(filename)"))
        _ = readline(io)
        eof(io) && throw(ArgumentError("MMN dimension line is missing: $(filename)"))
        dimensions = split(strip(readline(io)))
        length(dimensions) >= 3 ||
            throw(ArgumentError("MMN file $(filename) has malformed dimensions"))
        num_bands, num_kpoints, num_neighbors = parse.(Int, dimensions[1:3])
        neighbors = Matrix{Int}(undef, num_neighbors, num_kpoints)
        reciprocal_shifts = Array{Int, 3}(undef, 3, num_neighbors, num_kpoints)
        matrix_rows = num_bands * num_bands
        for kpoint in 1:num_kpoints, neighbor_index in 1:num_neighbors
            eof(io) && throw(
                ArgumentError(
                    "MMN topology ended before k-point $(kpoint), neighbour $(neighbor_index)",
                ),
            )
            header = split(strip(readline(io)))
            length(header) >= 5 || throw(ArgumentError("MMN neighbour header is malformed"))
            file_kpoint = parse(Int, header[1])
            file_kpoint == kpoint ||
                throw(ArgumentError("MMN topology k-point $(file_kpoint), expected $(kpoint)"))
            neighbors[neighbor_index, kpoint] = parse(Int, header[2])
            reciprocal_shifts[:, neighbor_index, kpoint] .= parse.(Int, header[3:5])
            for _ in 1:matrix_rows
                eof(io) && throw(ArgumentError("MMN topology matrix block is truncated"))
                readline(io)
            end
        end
        return WannierMMNTopology(
            num_bands,
            num_kpoints,
            num_neighbors,
            neighbors,
            reciprocal_shifts,
        )
    end
end

"""
Stream formatted MMN overlaps to the callback in file order, validating band dimensions and neighbor topology.

Each block represents dimensionless Bloch overlaps in the input gauge; the reader does not rotate or normalize them.
"""
function foreach_wannier_mmn_block(
    callback::Function,
    filename::AbstractString;
    expected_num_bands::Union{Nothing, Int} = nothing,
    expected_num_kpoints::Union{Nothing, Int} = nothing,
)
    isfile(filename) || error("MMN file does not exist: $(filename)")
    open(filename, "r") do io
        _ = readline(io)
        dims = split(strip(readline(io)))
        length(dims) >= 3 || error("MMN file $(filename) has malformed dimension line.")
        nb = parse(Int, dims[1])
        num_kpoints = parse(Int, dims[2])
        num_neighbors = parse(Int, dims[3])
        isnothing(expected_num_bands) ||
            nb == expected_num_bands ||
            error("MMN num_bands=$(nb) does not match expected $(expected_num_bands).")
        isnothing(expected_num_kpoints) ||
            num_kpoints == expected_num_kpoints ||
            error("MMN num_kpts=$(num_kpoints) does not match expected $(expected_num_kpoints).")
        overlap_matrix = zeros(ComplexF64, nb, nb)
        for kpoint_index in 1:num_kpoints, _ in 1:num_neighbors
            header = split(strip(readline(io)))
            length(header) >= 5 ||
                error("Malformed MMN neighbour header at kpoint_index=$(kpoint_index).")
            file_ik = parse(Int, header[1])
            file_ik == kpoint_index ||
                error("MMN header kpoint_index=$(file_ik) but expected $(kpoint_index).")
            iknb = parse(Int, header[2])
            shift = (parse(Int, header[3]), parse(Int, header[4]), parse(Int, header[5]))
            for m in 1:nb, n in 1:nb
                row = split(strip(readline(io)))
                overlap_matrix[n, m] = ComplexF64(parse(Float64, row[1]), parse(Float64, row[2]))
            end
            callback(kpoint_index, iknb, shift, overlap_matrix)
        end
    end
    return nothing
end
