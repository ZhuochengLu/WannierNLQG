"""Dimensions and free-form header of a standard Wannier90 unformatted `.uIu` file."""
struct WannierUIUHeader
    comment::String
    num_bands::Int
    num_kpts::Int
    num_neighbors::Int

    function WannierUIUHeader(comment, num_bands, num_kpts, num_neighbors)
        num_bands > 0 || throw(ArgumentError("uIu num_bands must be positive"))
        num_kpts > 0 || throw(ArgumentError("uIu num_kpts must be positive"))
        num_neighbors > 0 || throw(ArgumentError("uIu num_neighbors must be positive"))
        return new(String(comment), Int(num_bands), Int(num_kpts), Int(num_neighbors))
    end
end

# Read and validate the two leading records of a standard unformatted uIu file.
function _read_wannier_uiu_header(io::Base.IO, filename::AbstractString)
    comment_bytes, comment_endian = _read_fortran_record_with_endian(io)
    dimension_bytes, dimension_endian = _read_fortran_record_with_endian(io)
    comment_endian == dimension_endian ||
        throw(ArgumentError("uIu file $(filename) changes endianness between header records"))
    comment = rstrip(String(comment_bytes), ['\0', ' '])
    dimensions = _record_as_int32(dimension_bytes, dimension_endian)
    length(dimensions) == 3 || throw(
        ArgumentError(
            "uIu file $(filename) dimension record has $(length(dimensions)) integers; expected 3",
        ),
    )
    return WannierUIUHeader(comment, dimensions[1], dimensions[2], dimensions[3]), comment_endian
end

"""Read a strict two-line formatted Wannier operator header."""
function _read_wannier_formatted_header(
    io::Base.IO,
    filename::AbstractString,
    label::AbstractString,
)
    eof(io) && throw(ArgumentError("$(label) file $(filename) is empty"))
    comment = strip(readline(io))
    isempty(comment) && throw(ArgumentError("$(label) file $(filename) has an empty header"))
    eof(io) && throw(ArgumentError("$(label) file $(filename) is missing dimensions"))
    fields = split(strip(readline(io)))
    length(fields) == 3 ||
        throw(ArgumentError("$(label) formatted dimension row must contain exactly 3 integers"))
    dimensions = try
        parse.(Int, fields)
    catch
        throw(ArgumentError("$(label) formatted dimension row contains a non-integer field"))
    end
    return comment, dimensions
end

"""Read only the header and dimensions of a standard Fortran-unformatted `.uIu` file."""
function read_wannier_uiu_header(filename::AbstractString; formatted::Bool = false)
    isfile(filename) || throw(ArgumentError("uIu file does not exist: $(filename)"))
    return open(filename, "r") do io
        if formatted
            comment, dimensions = _read_wannier_formatted_header(io, filename, "uIu")
            return WannierUIUHeader(comment, dimensions...)
        end
        header, _ = _read_wannier_uiu_header(io, filename)
        return header
    end
end

"""Parse one finite Wannier90 decimal, including Fortran D exponents."""
function _parse_wannier_float(token::AbstractString, context::AbstractString)
    value = try
        parse(Float64, replace(token, r"[dD]" => "E"))
    catch
        throw(ArgumentError("$(context) contains an invalid floating-point value $(repr(token))"))
    end
    isfinite(value) || throw(ArgumentError("$(context) contains NaN or Inf"))
    return value
end

"""Read one dense complex block from a formatted Wannier operator file."""
function _read_wannier_formatted_complex_block(
    io::Base.IO,
    num_bands::Int,
    filename::AbstractString,
    label::AbstractString,
)
    values = Vector{ComplexF64}(undef, num_bands^2)
    for index in eachindex(values)
        eof(io) &&
            throw(ArgumentError("$(label) file $(filename) is truncated in complex block $(index)"))
        fields = split(strip(readline(io)))
        length(fields) == 2 || throw(
            ArgumentError(
                "$(label) formatted complex row must contain exactly real and imaginary fields",
            ),
        )
        context = "$(label) file $(filename) complex row $(index)"
        values[index] = ComplexF64(
            _parse_wannier_float(fields[1], context),
            _parse_wannier_float(fields[2], context),
        )
    end
    return values
end

"""Validate and normalize one generated dense Wannier operator block."""
function _validate_wannier_operator_block(
    block::AbstractMatrix,
    header,
    label::AbstractString,
    indices,
)
    size(block) == (header.num_bands, header.num_bands) || throw(
        ArgumentError(
            "$(label) block $(indices) has size $(size(block)); expected " *
            "($(header.num_bands), $(header.num_bands))",
        ),
    )
    all(isfinite, block) || throw(ArgumentError("$(label) block $(indices) contains NaN or Inf"))
    return ComplexF64.(block)
end

"""Write a formatted or sequential-unformatted Wannier operator header."""
function _write_wannier_operator_header(io::Base.IO, header, formatted::Bool, label::AbstractString)
    comment = String(header.comment)
    isempty(strip(comment)) && throw(ArgumentError("$(label) comment must not be empty"))
    if formatted
        println(io, comment)
        @printf(io, "%d %d %d\n", header.num_bands, header.num_kpts, header.num_neighbors)
    else
        all(isascii, comment) ||
            throw(ArgumentError("unformatted $(label) comment must contain only ASCII characters"))
        _write_fortran_record_32(
            io,
            collect(codeunits(rpad(first(comment, min(60, length(comment))), 60))),
        )
        _write_fortran_record_32(
            io,
            _spn_record_bytes(Int32[header.num_bands, header.num_kpts, header.num_neighbors]),
        )
    end
    return nothing
end

"""Serialize one operator matrix in upstream row/column record order."""
function _write_wannier_operator_block(io::Base.IO, block::AbstractMatrix, formatted::Bool)
    serialized = vec(copy(transpose(ComplexF64.(block))))
    if formatted
        for value in serialized
            @printf(io, "% .17e % .17e\n", real(value), imag(value))
        end
    else
        _write_fortran_record_32(io, _spn_record_bytes(serialized))
    end
    return nothing
end

"""Publish a generated operator only after its complete temporary write succeeds."""
function _atomic_wannier_operator_write(filename::AbstractString, writer)
    path = abspath(filename)
    mkpath(dirname(path))
    temporary, io = mktemp(dirname(path); cleanup = false)
    published = false
    try
        writer(io)
        flush(io)
        close(io)
        mv(temporary, path; force = true)
        published = true
    finally
        isopen(io) && close(io)
        !published && isfile(temporary) && rm(temporary; force = true)
    end
    return path
end

"""Do-block overload for atomic Wannier operator publication."""
_atomic_wannier_operator_write(writer, filename::AbstractString) =
    _atomic_wannier_operator_write(filename, writer)

"""
    foreach_wannier_uiu_block(callback, filename; expected_num_bands=nothing,
                              expected_num_kpts=nothing, expected_num_neighbors=nothing)

Stream the direct overlaps in Wannier90's `ik, nn2, nn1` record order without
materializing the complete five-dimensional file. `callback(block, ik, nn2,
nn1, header)` receives the transposed `num_bands x num_bands` matrix used by
Wannier90 `get_FF_R`, i.e. the direct overlap
`<u_{q+b1}|u_{q+b2}>`. Record markers, dimensions, record count, and trailing
bytes are validated before returning.
"""
function foreach_wannier_uiu_block(
    callback,
    filename::AbstractString;
    expected_num_bands::Union{Nothing, Int} = nothing,
    expected_num_kpts::Union{Nothing, Int} = nothing,
    expected_num_neighbors::Union{Nothing, Int} = nothing,
    formatted::Bool = false,
)
    isfile(filename) || throw(ArgumentError("uIu file does not exist: $(filename)"))
    return open(filename, "r") do io
        header, endian = if formatted
            comment, dimensions = _read_wannier_formatted_header(io, filename, "uIu")
            WannierUIUHeader(comment, dimensions...), :formatted
        else
            _read_wannier_uiu_header(io, filename)
        end
        expected_num_bands === nothing ||
            header.num_bands == expected_num_bands ||
            throw(
                ArgumentError(
                    "uIu num_bands=$(header.num_bands) does not match expected $(expected_num_bands)",
                ),
            )
        expected_num_kpts === nothing ||
            header.num_kpts == expected_num_kpts ||
            throw(
                ArgumentError(
                    "uIu num_kpts=$(header.num_kpts) does not match expected $(expected_num_kpts)",
                ),
            )
        expected_num_neighbors === nothing ||
            header.num_neighbors == expected_num_neighbors ||
            throw(
                ArgumentError(
                    "uIu num_neighbors=$(header.num_neighbors) does not match expected " *
                    "$(expected_num_neighbors)",
                ),
            )
        block_length = header.num_bands^2
        for ik in 1:header.num_kpts, nn2 in 1:header.num_neighbors, nn1 in 1:header.num_neighbors
            values = if formatted
                _read_wannier_formatted_complex_block(io, header.num_bands, filename, "uIu")
            else
                bytes, block_endian = _read_fortran_record_with_endian(io)
                block_endian == endian || throw(
                    ArgumentError("uIu file $(filename) changes endianness in its payload"),
                )
                _record_as_complex128(bytes, block_endian)
            end
            length(values) == block_length || throw(
                ArgumentError(
                    "uIu block (ik=$(ik), nn2=$(nn2), nn1=$(nn1)) has " *
                    "$(length(values)) complex values; expected $(block_length)",
                ),
            )
            raw = reshape(values, header.num_bands, header.num_bands)
            callback(copy(transpose(raw)), ik, nn2, nn1, header)
        end
        eof(io) || throw(ArgumentError("uIu file $(filename) contains trailing records or bytes"))
        return header
    end
end

"""
    write_wannier_uiu(filename, header, block_provider; formatted=false)

Atomically stream a Wannier90 uIu file. `block_provider(ik, nn2, nn1, header)`
returns the physical matrix `<u_{q+b1}|u_{q+b2}>` with bra and ket as row and
column indices. The serialized order is exactly `ik -> nn2 -> nn1`.
"""
function write_wannier_uiu(
    filename::AbstractString,
    header::WannierUIUHeader,
    block_provider;
    formatted::Bool = false,
)
    return _atomic_wannier_operator_write(filename) do io
        _write_wannier_operator_header(io, header, formatted, "uIu")
        for ik in 1:header.num_kpts, nn2 in 1:header.num_neighbors, nn1 in 1:header.num_neighbors
            block = _validate_wannier_operator_block(
                block_provider(ik, nn2, nn1, header),
                header,
                "uIu",
                (ik, nn2, nn1),
            )
            _write_wannier_operator_block(io, block, formatted)
        end
    end
end

"""Do-block overload of `write_wannier_uiu` with upstream record ordering."""
write_wannier_uiu(
    block_provider,
    filename::AbstractString,
    header::WannierUIUHeader;
    formatted::Bool = false,
) = write_wannier_uiu(filename, header, block_provider; formatted)
