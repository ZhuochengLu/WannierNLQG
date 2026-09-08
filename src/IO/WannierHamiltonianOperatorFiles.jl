"""Dimensions and header of a Wannier90 `.uHu` file."""
struct WannierUHUHeader
    comment::String
    num_bands::Int
    num_kpts::Int
    num_neighbors::Int

    function WannierUHUHeader(comment, num_bands, num_kpts, num_neighbors)
        num_bands > 0 || throw(ArgumentError("uHu num_bands must be positive"))
        num_kpts > 0 || throw(ArgumentError("uHu num_kpts must be positive"))
        num_neighbors > 0 || throw(ArgumentError("uHu num_neighbors must be positive"))
        return new(String(comment), Int(num_bands), Int(num_kpts), Int(num_neighbors))
    end
end

"""Dimensions and header of a Wannier90 `.sHu` file."""
struct WannierSHUHeader
    comment::String
    num_bands::Int
    num_kpts::Int
    num_neighbors::Int

    function WannierSHUHeader(comment, num_bands, num_kpts, num_neighbors)
        num_bands > 0 || throw(ArgumentError("sHu num_bands must be positive"))
        num_kpts > 0 || throw(ArgumentError("sHu num_kpts must be positive"))
        num_neighbors > 0 || throw(ArgumentError("sHu num_neighbors must be positive"))
        return new(String(comment), Int(num_bands), Int(num_kpts), Int(num_neighbors))
    end
end

"""Dimensions and header of a Wannier90 `.sIu` file."""
struct WannierSIUHeader
    comment::String
    num_bands::Int
    num_kpts::Int
    num_neighbors::Int

    function WannierSIUHeader(comment, num_bands, num_kpts, num_neighbors)
        num_bands > 0 || throw(ArgumentError("sIu num_bands must be positive"))
        num_kpts > 0 || throw(ArgumentError("sIu num_kpts must be positive"))
        num_neighbors > 0 || throw(ArgumentError("sIu num_neighbors must be positive"))
        return new(String(comment), Int(num_bands), Int(num_kpts), Int(num_neighbors))
    end
end

"""Read one formatted or unformatted uHu/sHu/sIu header from an open stream."""
function _read_wannier_operator_header(
    io::Base.IO,
    filename::AbstractString,
    label::AbstractString,
    header_type;
    formatted::Bool,
)
    if formatted
        comment, dimensions = _read_wannier_formatted_header(io, filename, label)
        return header_type(comment, dimensions...), :formatted
    end
    comment_bytes, comment_endian = _read_fortran_record_with_endian(io)
    dimension_bytes, dimension_endian = _read_fortran_record_with_endian(io)
    comment_endian == dimension_endian ||
        throw(ArgumentError("$(label) file $(filename) changes endianness between header records"))
    dimensions = _record_as_int32(dimension_bytes, dimension_endian)
    length(dimensions) == 3 ||
        throw(ArgumentError("$(label) dimension record must contain exactly 3 Int32 values"))
    comment = rstrip(String(comment_bytes), ['\0', ' '])
    return header_type(comment, dimensions...), comment_endian
end

"""Open a uHu/sHu/sIu file and return only its validated header."""
function _read_wannier_operator_header_file(
    filename::AbstractString,
    label::AbstractString,
    header_type;
    formatted::Bool,
)
    isfile(filename) || throw(ArgumentError("$(label) file does not exist: $(filename)"))
    return open(filename, "r") do io
        header, _ = _read_wannier_operator_header(io, filename, label, header_type; formatted)
        return header
    end
end

"""Check optional expected dimensions against a parsed operator header."""
function _validate_wannier_operator_expected_dimensions(
    header,
    label::AbstractString;
    expected_num_bands::Union{Nothing, Int},
    expected_num_kpts::Union{Nothing, Int},
    expected_num_neighbors::Union{Nothing, Int},
)
    for (name, observed, expected) in (
        ("num_bands", header.num_bands, expected_num_bands),
        ("num_kpts", header.num_kpts, expected_num_kpts),
        ("num_neighbors", header.num_neighbors, expected_num_neighbors),
    )
        expected === nothing ||
            observed == expected ||
            throw(ArgumentError("$(label) $(name)=$(observed) does not match expected $(expected)"))
    end
    return nothing
end

"""Read and validate one dense matrix from an operator payload record."""
function _read_wannier_operator_matrix(
    io::Base.IO,
    header,
    endian::Symbol,
    filename::AbstractString,
    label::AbstractString,
    formatted::Bool,
)
    values = if formatted
        _read_wannier_formatted_complex_block(io, header.num_bands, filename, label)
    else
        bytes, block_endian = _read_fortran_record_with_endian(io)
        block_endian == endian ||
            throw(ArgumentError("$(label) file $(filename) changes endianness in its payload"))
        _record_as_complex128(bytes, block_endian)
    end
    length(values) == header.num_bands^2 || throw(
        ArgumentError(
            "$(label) matrix has $(length(values)) values; expected $(header.num_bands^2)",
        ),
    )
    all(isfinite, values) || throw(ArgumentError("$(label) matrix contains NaN or Inf"))
    raw = reshape(values, header.num_bands, header.num_bands)
    return copy(transpose(raw))
end

"""Stream a two-neighbor operator in `ik -> nn2 -> nn1` order."""
function _foreach_wannier_two_neighbor_block(
    callback,
    filename::AbstractString,
    label::AbstractString,
    header_type;
    formatted::Bool,
    expected_num_bands::Union{Nothing, Int},
    expected_num_kpts::Union{Nothing, Int},
    expected_num_neighbors::Union{Nothing, Int},
)
    isfile(filename) || throw(ArgumentError("$(label) file does not exist: $(filename)"))
    return open(filename, "r") do io
        header, endian = _read_wannier_operator_header(io, filename, label, header_type; formatted)
        _validate_wannier_operator_expected_dimensions(
            header,
            label;
            expected_num_bands,
            expected_num_kpts,
            expected_num_neighbors,
        )
        for ik in 1:header.num_kpts, nn2 in 1:header.num_neighbors, nn1 in 1:header.num_neighbors
            block = _read_wannier_operator_matrix(io, header, endian, filename, label, formatted)
            callback(block, ik, nn2, nn1, header)
        end
        eof(io) || throw(ArgumentError("$(label) file $(filename) contains trailing data"))
        return header
    end
end

"""Stream a spin-neighbor operator in `ik -> nn -> ispol` order."""
function _foreach_wannier_spin_neighbor_block(
    callback,
    filename::AbstractString,
    label::AbstractString,
    header_type;
    formatted::Bool,
    expected_num_bands::Union{Nothing, Int},
    expected_num_kpts::Union{Nothing, Int},
    expected_num_neighbors::Union{Nothing, Int},
)
    isfile(filename) || throw(ArgumentError("$(label) file does not exist: $(filename)"))
    return open(filename, "r") do io
        header, endian = _read_wannier_operator_header(io, filename, label, header_type; formatted)
        _validate_wannier_operator_expected_dimensions(
            header,
            label;
            expected_num_bands,
            expected_num_kpts,
            expected_num_neighbors,
        )
        for ik in 1:header.num_kpts, nn in 1:header.num_neighbors, ispol in 1:3
            block = _read_wannier_operator_matrix(io, header, endian, filename, label, formatted)
            callback(block, ik, nn, ispol, header)
        end
        eof(io) || throw(ArgumentError("$(label) file $(filename) contains trailing data"))
        return header
    end
end

"""Read only the `.uHu` header and dimensions."""
read_wannier_uhu_header(filename::AbstractString; formatted::Bool = false) =
    _read_wannier_operator_header_file(filename, "uHu", WannierUHUHeader; formatted)

"""Read only the `.sHu` header and dimensions."""
read_wannier_shu_header(filename::AbstractString; formatted::Bool = false) =
    _read_wannier_operator_header_file(filename, "sHu", WannierSHUHeader; formatted)

"""Read only the `.sIu` header and dimensions."""
read_wannier_siu_header(filename::AbstractString; formatted::Bool = false) =
    _read_wannier_operator_header_file(filename, "sIu", WannierSIUHeader; formatted)

"""Stream `.uHu` matrices in upstream `ik -> nn2 -> nn1` order."""
function foreach_wannier_uhu_block(
    callback,
    filename::AbstractString;
    formatted::Bool = false,
    expected_num_bands::Union{Nothing, Int} = nothing,
    expected_num_kpts::Union{Nothing, Int} = nothing,
    expected_num_neighbors::Union{Nothing, Int} = nothing,
)
    return _foreach_wannier_two_neighbor_block(
        callback,
        filename,
        "uHu",
        WannierUHUHeader;
        formatted,
        expected_num_bands,
        expected_num_kpts,
        expected_num_neighbors,
    )
end

"""Stream `.sHu` matrices in upstream `ik -> nn -> ispol` order."""
function foreach_wannier_shu_block(
    callback,
    filename::AbstractString;
    formatted::Bool = false,
    expected_num_bands::Union{Nothing, Int} = nothing,
    expected_num_kpts::Union{Nothing, Int} = nothing,
    expected_num_neighbors::Union{Nothing, Int} = nothing,
)
    return _foreach_wannier_spin_neighbor_block(
        callback,
        filename,
        "sHu",
        WannierSHUHeader;
        formatted,
        expected_num_bands,
        expected_num_kpts,
        expected_num_neighbors,
    )
end

"""Stream `.sIu` matrices in upstream `ik -> nn -> ispol` order."""
function foreach_wannier_siu_block(
    callback,
    filename::AbstractString;
    formatted::Bool = false,
    expected_num_bands::Union{Nothing, Int} = nothing,
    expected_num_kpts::Union{Nothing, Int} = nothing,
    expected_num_neighbors::Union{Nothing, Int} = nothing,
)
    return _foreach_wannier_spin_neighbor_block(
        callback,
        filename,
        "sIu",
        WannierSIUHeader;
        formatted,
        expected_num_bands,
        expected_num_kpts,
        expected_num_neighbors,
    )
end

"""Atomically write every block of a two-neighbor operator."""
function _write_wannier_two_neighbor_operator(
    filename::AbstractString,
    header,
    block_provider,
    label::AbstractString;
    formatted::Bool,
)
    return _atomic_wannier_operator_write(filename) do io
        _write_wannier_operator_header(io, header, formatted, label)
        for ik in 1:header.num_kpts, nn2 in 1:header.num_neighbors, nn1 in 1:header.num_neighbors
            block = _validate_wannier_operator_block(
                block_provider(ik, nn2, nn1, header),
                header,
                label,
                (ik, nn2, nn1),
            )
            _write_wannier_operator_block(io, block, formatted)
        end
    end
end

"""Atomically write every block of a spin-neighbor operator."""
function _write_wannier_spin_neighbor_operator(
    filename::AbstractString,
    header,
    block_provider,
    label::AbstractString;
    formatted::Bool,
)
    return _atomic_wannier_operator_write(filename) do io
        _write_wannier_operator_header(io, header, formatted, label)
        for ik in 1:header.num_kpts, nn in 1:header.num_neighbors, ispol in 1:3
            block = _validate_wannier_operator_block(
                block_provider(ik, nn, ispol, header),
                header,
                label,
                (ik, nn, ispol),
            )
            _write_wannier_operator_block(io, block, formatted)
        end
    end
end

"""Atomically write a `.uHu` file in upstream record order and eV units."""
write_wannier_uhu(filename, header::WannierUHUHeader, block_provider; formatted::Bool = false) =
    _write_wannier_two_neighbor_operator(filename, header, block_provider, "uHu"; formatted)

"""Atomically write a `.sHu` file in upstream record order and eV units."""
write_wannier_shu(filename, header::WannierSHUHeader, block_provider; formatted::Bool = false) =
    _write_wannier_spin_neighbor_operator(filename, header, block_provider, "sHu"; formatted)

"""Atomically write a `.sIu` file in upstream record order with dimensionless spin."""
write_wannier_siu(filename, header::WannierSIUHeader, block_provider; formatted::Bool = false) =
    _write_wannier_spin_neighbor_operator(filename, header, block_provider, "sIu"; formatted)

"""Do-block overload of `write_wannier_uhu`."""
write_wannier_uhu(
    block_provider,
    filename::AbstractString,
    header::WannierUHUHeader;
    formatted::Bool = false,
) = write_wannier_uhu(filename, header, block_provider; formatted)

"""Do-block overload of `write_wannier_shu`."""
write_wannier_shu(
    block_provider,
    filename::AbstractString,
    header::WannierSHUHeader;
    formatted::Bool = false,
) = write_wannier_shu(filename, header, block_provider; formatted)

"""Do-block overload of `write_wannier_siu`."""
write_wannier_siu(
    block_provider,
    filename::AbstractString,
    header::WannierSIUHeader;
    formatted::Bool = false,
) = write_wannier_siu(filename, header, block_provider; formatted)
