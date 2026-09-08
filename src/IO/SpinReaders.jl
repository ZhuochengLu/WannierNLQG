"""
Wannier90 spin matrix read from `seedname.spn` or a formatted `.spn.fmt` file.

`data[m,n,alpha,kpoint_index]` stores `<u_{m,k}|S_alpha|u_{n,k}>` in the upstream
first-principles Hamiltonian/DFT gauge.  The spin unit is not changed here; it
is exactly the unit written by the upstream Wannier90/PW2Wannier90/VASP path.
"""
struct WannierSPN
    num_bands::Int
    num_kpts::Int
    data::Array{ComplexF64, 4}

    function WannierSPN(num_bands::Int, num_kpts::Int, data::Array{ComplexF64, 4})
        num_bands > 0 || error("SPN num_bands must be positive, got $(num_bands).")
        num_kpts > 0 || error("SPN num_kpts must be positive, got $(num_kpts).")
        size(data) == (num_bands, num_bands, 3, num_kpts) || error(
            "SPN data has size $(size(data)); expected ($(num_bands), $(num_bands), 3, $(num_kpts)).",
        )
        return new(num_bands, num_kpts, data)
    end
end

"""
Wannier90 checkpoint data needed for spin interpolation.

`v_matrix[band,wannier,kpoint_index]` is the final Wannier90 gauge matrix `V(k)` used as
`spin_wannier(k) = V(k)' * S_DFT(k) * V(k)`.  For disentangled calculations this is the
window-projected `u_matrix_opt * u_matrix`; otherwise it is `u_matrix`.
"""
struct WannierCHK
    num_bands::Int
    num_orbitals::Int
    num_kpts::Int
    mp_grid::NTuple{3, Int}
    kpt_red::Matrix{Float64}
    real_lattice::Matrix{Float64}
    recip_lattice::Matrix{Float64}
    wannier_centers_cart::Matrix{Float64}
    v_matrix::Array{ComplexF64, 3}

    function WannierCHK(
        num_bands::Int,
        num_orbitals::Int,
        num_kpts::Int,
        mp_grid::NTuple{3, Int},
        kpt_red::Matrix{Float64},
        real_lattice::Matrix{Float64},
        recip_lattice::Matrix{Float64},
        wannier_centers_cart::Matrix{Float64},
        v_matrix::Array{ComplexF64, 3},
    )
        num_bands > 0 || error("CHK num_bands must be positive, got $(num_bands).")
        num_orbitals > 0 || error("CHK num_orbitals must be positive, got $(num_orbitals).")
        num_kpts > 0 || error("CHK num_kpts must be positive, got $(num_kpts).")
        all(>(0), mp_grid) || error("CHK mp_grid entries must be positive, got $(mp_grid).")
        prod(mp_grid) == num_kpts ||
            error("CHK num_kpts=$(num_kpts) does not match prod(mp_grid)=$(prod(mp_grid)).")
        size(kpt_red) == (num_kpts, 3) ||
            error("CHK kpt_red has size $(size(kpt_red)); expected ($(num_kpts), 3).")
        size(real_lattice) == (3, 3) ||
            error("CHK real_lattice has size $(size(real_lattice)); expected (3, 3).")
        size(recip_lattice) == (3, 3) ||
            error("CHK recip_lattice has size $(size(recip_lattice)); expected (3, 3).")
        size(wannier_centers_cart) == (num_orbitals, 3) || error(
            "CHK wannier_centers_cart has size $(size(wannier_centers_cart)); expected ($(num_orbitals), 3).",
        )
        size(v_matrix) == (num_bands, num_orbitals, num_kpts) || error(
            "CHK v_matrix has size $(size(v_matrix)); expected ($(num_bands), $(num_orbitals), $(num_kpts)).",
        )
        return new(
            num_bands,
            num_orbitals,
            num_kpts,
            mp_grid,
            kpt_red,
            real_lattice,
            recip_lattice,
            wannier_centers_cart,
            v_matrix,
        )
    end
end

# Construct a checkpoint with zero Cartesian Wannier centers when the legacy argument list omits them; retain all gauge and dimension validation.
function WannierCHK(
    num_bands::Int,
    num_orbitals::Int,
    num_kpts::Int,
    mp_grid::NTuple{3, Int},
    kpt_red::Matrix{Float64},
    real_lattice::Matrix{Float64},
    recip_lattice::Matrix{Float64},
    v_matrix::Array{ComplexF64, 3},
)
    centers = zeros(Float64, num_orbitals, 3)
    return WannierCHK(
        num_bands,
        num_orbitals,
        num_kpts,
        mp_grid,
        kpt_red,
        real_lattice,
        recip_lattice,
        centers,
        v_matrix,
    )
end

# Decode exactly four bytes as a UInt32 in the requested little/big endian order; reject other lengths or endian symbols.
function _u32_from_bytes(bytes::AbstractVector{UInt8}, endian::Symbol)
    length(bytes) == 4 || error("Fortran record marker must have 4 bytes, got $(length(bytes)).")
    if endian == :little
        return UInt32(bytes[1]) | (UInt32(bytes[2]) << 8) | (UInt32(bytes[3]) << 16) |
               (UInt32(bytes[4]) << 24)
    elseif endian == :big
        return UInt32(bytes[4]) | (UInt32(bytes[3]) << 8) | (UInt32(bytes[2]) << 16) |
               (UInt32(bytes[1]) << 24)
    end
    error("Unsupported endian=$(endian).")
end

"""
Read one Fortran unformatted record with 32-bit record markers.

The reader validates the leading/trailing markers and auto-detects little vs
big endian markers.  It does not implement compiler-specific chained
sub-records; if such a file is encountered the error points at record-marker
or endian mismatch.
"""
function _read_fortran_record_with_endian(io::Base.IO)
    eof(io) && error("Unexpected end of file while reading a Fortran record marker.")
    start_pos = position(io)
    marker_bytes = read(io, 4)
    length(marker_bytes) == 4 || error("Truncated Fortran record marker at byte $(start_pos).")
    data_start = position(io)

    candidates = Tuple{Int, Symbol}[]
    for endian in (:little, :big)
        nbytes_u32 = _u32_from_bytes(marker_bytes, endian)
        nbytes_u32 <= typemax(Int) || continue
        nbytes = Int(nbytes_u32)
        nbytes < 0 && continue
        push!(candidates, (nbytes, endian))
    end

    chosen = nothing
    for (nbytes, endian) in candidates
        try
            seek(io, data_start + nbytes)
            tail_bytes = read(io, 4)
            if length(tail_bytes) == 4 && Int(_u32_from_bytes(tail_bytes, endian)) == nbytes
                chosen = (nbytes, endian)
                break
            end
        catch
        finally
            seek(io, data_start)
        end
    end
    isnothing(chosen) && error(
        "Invalid Fortran record marker at byte $(start_pos). " *
        "This reader expects 32-bit markers without chained sub-records; check endian/record-marker format.",
    )

    nbytes, endian = chosen
    data = read(io, nbytes)
    length(data) == nbytes || error("Truncated Fortran record payload at byte $(data_start).")
    tail_bytes = read(io, 4)
    length(tail_bytes) == 4 ||
        error("Truncated Fortran record trailer after byte $(data_start + nbytes).")
    Int(_u32_from_bytes(tail_bytes, endian)) == nbytes ||
        error("Fortran record marker mismatch at byte $(start_pos).")
    return data, endian
end

"""Read one strict 32-bit-marker Fortran sequential-unformatted record."""
function read_fortran_record(io::Base.IO)::Vector{UInt8}
    data, _ = _read_fortran_record_with_endian(io)
    return data
end

"""Return the host byte order used for decoded unformatted records."""
_native_endian() = Base.ENDIAN_BOM == 0x04030201 ? :little : :big

"""Decode unsigned words from a record while respecting its byte order."""
function _record_words(bytes::Vector{UInt8}, ::Type{T}, endian::Symbol) where {T <: Unsigned}
    length(bytes) % sizeof(T) == 0 ||
        error("Record length $(length(bytes)) is not a multiple of $(T) size.")
    words = collect(reinterpret(T, bytes))
    endian == _native_endian() || map!(bswap, words, words)
    return words
end

# Decode a complete sequence of endian-aware signed 32-bit words into native Julia integers; reject incomplete words.
function _record_as_int32(bytes::Vector{UInt8}, endian::Symbol = _native_endian())
    length(bytes) % sizeof(Int32) == 0 ||
        error("Record length $(length(bytes)) is not a multiple of Int32 size.")
    return Int.(reinterpret(Int32, _record_words(bytes, UInt32, endian)))
end

# Decode endian-aware 64-bit words as a fresh Float64 vector; reject byte lengths not divisible by eight.
function _record_as_float64(bytes::Vector{UInt8}, endian::Symbol = _native_endian())
    length(bytes) % sizeof(Float64) == 0 ||
        error("Record length $(length(bytes)) is not a multiple of Float64 size.")
    return collect(reinterpret(Float64, _record_words(bytes, UInt64, endian)))
end

# Decode pairs of endian-aware Float64 values as ComplexF64; require complete sixteen-byte complex entries.
function _record_as_complex128(bytes::Vector{UInt8}, endian::Symbol = _native_endian())
    length(bytes) % sizeof(ComplexF64) == 0 ||
        error("Record length $(length(bytes)) is not a multiple of ComplexF64 size.")
    return _complex_from_float_pairs(_record_as_float64(bytes, endian))
end

# Pair consecutive real and imaginary values into a new complex vector; reject an odd number of values.
function _complex_from_float_pairs(values::Vector{Float64})
    iseven(length(values)) ||
        error("Complex record has odd number of Float64 values: $(length(values)).")
    output = Vector{ComplexF64}(undef, length(values) ÷ 2)
    @inbounds for i in eachindex(output)
        output[i] = ComplexF64(values[2i - 1], values[2i])
    end
    return output
end

# Read one validated endian-aware Fortran record and decode successive real/imaginary Float64 pairs.
function _read_complex_float_record(io::Base.IO)
    bytes, endian = _read_fortran_record_with_endian(io)
    return _complex_from_float_pairs(_record_as_float64(bytes, endian))
end

# Return the largest absolute entry of `mat - mat'`, without symmetrizing the input.
function _max_hermiticity_error(mat::AbstractMatrix{ComplexF64})
    return maximum(abs, mat .- mat')
end

# Parse formatted SPN dimensions and packed Hermitian triangles; reject truncated or malformed records.
function _read_wannier_spn_formatted(filename::AbstractString)
    open(filename, "r") do io
        header = strip(readline(io))
        dims = split(strip(readline(io)))
        length(dims) >= 2 ||
            error("Formatted SPN file $(filename) is missing num_bands/num_kpts line.")
        nb = parse(Int, dims[1])
        num_kpoints = parse(Int, dims[2])
        nb > 0 || error("Formatted SPN num_bands must be positive, got $(nb).")
        num_kpoints > 0 || error("Formatted SPN num_kpts must be positive, got $(num_kpoints).")
        data = zeros(ComplexF64, nb, nb, 3, num_kpoints)
        tri = nb * (nb + 1) ÷ 2
        for kpoint_index in 1:num_kpoints
            values = Vector{ComplexF64}(undef, 3 * tri)
            for idx in eachindex(values)
                eof(io) && error(
                    "Formatted SPN file ended early at k-point $(kpoint_index), entry $(idx).",
                )
                row = split(strip(readline(io)))
                length(row) >= 2 ||
                    error("Malformed formatted SPN row at k-point $(kpoint_index), entry $(idx).")
                values[idx] = ComplexF64(parse(Float64, row[1]), parse(Float64, row[2]))
            end
            _fill_spn_kpoint!(data, values, kpoint_index, nb)
        end
        _ = header
        return WannierSPN(nb, num_kpoints, data)
    end
end

# Parse endian-consistent binary SPN records and reject invalid dimensions, payload sizes or trailing data.
function _read_wannier_spn_binary(filename::AbstractString)
    open(filename, "r") do io
        header_bytes, header_endian = _read_fortran_record_with_endian(io)
        dimension_bytes, dimension_endian = _read_fortran_record_with_endian(io)
        header_endian == dimension_endian || error("Binary SPN record endianness changed")
        header = String(header_bytes)
        dims = _record_as_int32(dimension_bytes, dimension_endian)
        length(dims) >= 2 || error("Binary SPN file $(filename) has malformed dimension record.")
        nb, num_kpoints = dims[1], dims[2]
        nb > 0 || error("Binary SPN num_bands must be positive, got $(nb).")
        num_kpoints > 0 || error("Binary SPN num_kpts must be positive, got $(num_kpoints).")
        data = zeros(ComplexF64, nb, nb, 3, num_kpoints)
        tri = nb * (nb + 1) ÷ 2
        for kpoint_index in 1:num_kpoints
            bytes, endian = _read_fortran_record_with_endian(io)
            endian == header_endian || error("Binary SPN record endianness changed")
            values = _record_as_complex128(bytes, endian)
            length(values) == 3 * tri || error(
                "SPN k-point $(kpoint_index) has $(length(values)) complex entries; expected $(3 * tri).",
            )
            _fill_spn_kpoint!(data, values, kpoint_index, nb)
        end
        eof(io) || error("Binary SPN file $(filename) contains trailing records or bytes")
        _ = header
        return WannierSPN(nb, num_kpoints, data)
    end
end

# Expand packed spin triangles into both Hermitian halves at one k point; reject imaginary diagonal entries above `1e-10`.
function _fill_spn_kpoint!(
    data::Array{ComplexF64, 4},
    values::Vector{ComplexF64},
    kpoint_index::Int,
    nb::Int,
)
    tri = nb * (nb + 1) ÷ 2
    idx = 1
    @inbounds for m in 1:nb
        for n in 1:m
            for alpha in 1:3
                value = values[alpha + (idx - 1) * 3]
                if n == m && abs(imag(value)) > 1e-10
                    error(
                        "SPN diagonal imaginary part at kpoint_index=$(kpoint_index), band=$(m), alpha=$(alpha) is $(imag(value)).",
                    )
                end
                data[n, m, alpha, kpoint_index] = n == m ? ComplexF64(real(value), 0.0) : value
                data[m, n, alpha, kpoint_index] =
                    n == m ? ComplexF64(real(value), 0.0) : conj(value)
            end
            idx += 1
        end
    end
    idx == tri + 1 || error("Internal SPN triangular unpacking error.")
    return data
end

"""
Read formatted or sequential-unformatted Wannier90 spin matrices into `(band,band,Cartesian,kpoint)` storage.

Validate dimensions and Hermitian triangle entries while preserving the upstream DFT gauge and spin units; missing or malformed input raises an error.

Read wannier spn from its configured input.
"""
function read_wannier_spn(filename::AbstractString; formatted::Bool = false)::WannierSPN
    isfile(filename) || error("SPN file does not exist: $(filename)")
    spn = formatted ? _read_wannier_spn_formatted(filename) : _read_wannier_spn_binary(filename)
    for kpoint_index in 1:spn.num_kpts, alpha in 1:3
        err = _max_hermiticity_error(@view spn.data[:, :, alpha, kpoint_index])
        err <= 1e-10 || error(
            "SPN Hermiticity check failed at kpoint_index=$(kpoint_index), alpha=$(alpha): max error=$(err).",
        )
    end
    return spn
end

# Validate one SPN payload before serializing the lower-triangular protocol.
function _validate_wannier_spn_for_write(spn::WannierSPN)
    all(isfinite, spn.data) || throw(ArgumentError("SPN data contains NaN or Inf"))
    for kpoint in 1:spn.num_kpts, alpha in 1:3
        matrix = @view spn.data[:, :, alpha, kpoint]
        residual = maximum(abs, matrix .- matrix'; init = 0.0)
        residual <= 1.0e-10 || throw(
            ArgumentError(
                "SPN Hermiticity check failed at kpoint=$(kpoint), component=$(alpha): residual=$(residual)",
            ),
        )
        diagonal_residual = maximum(abs, imag.(diag(matrix)); init = 0.0)
        diagonal_residual <= 1.0e-10 || throw(
            ArgumentError(
                "SPN diagonal is not real at kpoint=$(kpoint), component=$(alpha): residual=$(diagonal_residual)",
            ),
        )
    end
    return nothing
end

# Pack one SPN k-point in Wannier90's m-major lower-triangular component order.
function _pack_wannier_spn_kpoint(spn::WannierSPN, kpoint::Int)
    values = Vector{ComplexF64}(undef, 3 * spn.num_bands * (spn.num_bands + 1) ÷ 2)
    index = 1
    for m in 1:spn.num_bands, n in 1:m, alpha in 1:3
        value = spn.data[n, m, alpha, kpoint]
        values[index] = n == m ? ComplexF64(real(value), 0.0) : value
        index += 1
    end
    return values
end

# Write one little-endian-compatible Fortran record with Int32 byte markers.
function _write_fortran_record_32(io::Base.IO, values::AbstractVector{UInt8})
    length(values) <= typemax(Int32) || throw(ArgumentError("Fortran record exceeds Int32 size"))
    marker = Int32(length(values))
    write(io, htol(marker))
    write(io, values)
    write(io, htol(marker))
    return nothing
end

# Convert one supported numeric vector to the fixed little-endian SPN byte protocol.
function _spn_record_bytes(values::AbstractVector{T}) where {T}
    isbitstype(T) || throw(ArgumentError("SPN record values must be isbits"))
    buffer = IOBuffer()
    if T == Int32
        for value in values
            write(buffer, htol(value))
        end
    elseif T == ComplexF64
        for value in values
            write(buffer, htol(reinterpret(UInt64, real(value))))
            write(buffer, htol(reinterpret(UInt64, imag(value))))
        end
    else
        throw(ArgumentError("unsupported SPN record element type $(T)"))
    end
    return take!(buffer)
end

"""
    write_wannier_spn(filename, spn; formatted=false, comment="Generated by WannierNLQG")

Atomically write a Wannier90 SPN file. The payload stores dimensionless Pauli
matrix elements in Cartesian `x,y,z` order and preserves the input band gauge.
The binary form uses deterministic 60-byte header and Int32 Fortran record
markers; the formatted form emits the same lower-triangular complex ordering.
No normalization, spin-unit conversion, or gauge transformation occurs here.
"""
function write_wannier_spn(
    filename::AbstractString,
    spn::WannierSPN;
    formatted::Bool = false,
    comment::AbstractString = "Generated by WannierNLQG",
)
    _validate_wannier_spn_for_write(spn)
    path = abspath(filename)
    mkpath(dirname(path))
    temporary, io = mktemp(dirname(path); cleanup = false)
    published = false
    try
        if formatted
            println(io, String(comment))
            @printf(io, "%d %d\n", spn.num_bands, spn.num_kpts)
            for kpoint in 1:spn.num_kpts, value in _pack_wannier_spn_kpoint(spn, kpoint)
                @printf(io, "% .17g % .17g\n", real(value), imag(value))
            end
        else
            comment_text = String(comment)
            all(isascii, comment_text) ||
                throw(ArgumentError("binary SPN comment must contain only ASCII characters"))
            header = rpad(first(comment_text, min(60, length(comment_text))), 60)
            ncodeunits(header) == 60 || error("internal SPN header-width error")
            _write_fortran_record_32(io, collect(codeunits(header)))
            _write_fortran_record_32(io, _spn_record_bytes(Int32[spn.num_bands, spn.num_kpts]))
            for kpoint in 1:spn.num_kpts
                _write_fortran_record_32(
                    io,
                    _spn_record_bytes(_pack_wannier_spn_kpoint(spn, kpoint)),
                )
            end
        end
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

# Copy row-major floating values into a Julia matrix, validating the exact element count.
function _reshape_c_2d(values::Vector{Float64}, nrow::Int, ncol::Int)
    length(values) == nrow * ncol ||
        error("Cannot reshape $(length(values)) Float64 values to ($(nrow), $(ncol)).")
    output = Matrix{Float64}(undef, nrow, ncol)
    idx = 1
    @inbounds for i in 1:nrow
        for j in 1:ncol
            output[i, j] = values[idx]
            idx += 1
        end
    end
    return output
end

# Copy row-major integer values into a Julia matrix, validating the exact element count.
function _reshape_c_2d_int(values::Vector{Int}, nrow::Int, ncol::Int)
    length(values) == nrow * ncol ||
        error("Cannot reshape $(length(values)) Int values to ($(nrow), $(ncol)).")
    output = Matrix{Int}(undef, nrow, ncol)
    idx = 1
    @inbounds for i in 1:nrow
        for j in 1:ncol
            output[i, j] = values[idx]
            idx += 1
        end
    end
    return output
end

# Decode CHK entries into `(wannier,wannier,kpoint)` with row varying fastest; reject a wrong element count.
function _reshape_chk_u_matrix(values::Vector{ComplexF64}, num_kpoints::Int, num_orbitals::Int)
    length(values) == num_kpoints * num_orbitals * num_orbitals || error(
        "u_matrix record has $(length(values)) entries; " *
        "expected $(num_kpoints * num_orbitals * num_orbitals).",
    )
    output = Array{ComplexF64}(undef, num_orbitals, num_orbitals, num_kpoints)
    idx = 1
    @inbounds for kpoint_index in 1:num_kpoints
        for column in 1:num_orbitals
            for row in 1:num_orbitals
                output[row, column, kpoint_index] = values[idx]
                idx += 1
            end
        end
    end
    return output
end

# Decode disentanglement entries into `(band,wannier,kpoint)` with band varying fastest; reject a wrong element count.
function _reshape_chk_u_matrix_opt(
    values::Vector{ComplexF64},
    num_kpoints::Int,
    num_orbitals::Int,
    num_bands::Int,
)
    length(values) == num_kpoints * num_orbitals * num_bands || error(
        "u_matrix_opt record has $(length(values)) entries; " *
        "expected $(num_kpoints * num_orbitals * num_bands).",
    )
    output = zeros(ComplexF64, num_bands, num_orbitals, num_kpoints)
    idx = 1
    @inbounds for kpoint_index in 1:num_kpoints
        for orbital_index in 1:num_orbitals
            for band_index in 1:num_bands
                output[band_index, orbital_index, kpoint_index] = values[idx]
                idx += 1
            end
        end
    end
    return output
end

"""
Read Wannier90 CHK gauge, mesh, lattice and centers required for spin interpolation.

Construct the final band-to-Wannier gauge from optimization and unitary matrices when disentangled; reject inconsistent record counts and shapes. Preserve upstream energy/length and gauge conventions.

Read wannier chk from its configured input.
"""
function read_wannier_chk(filename::AbstractString)::WannierCHK
    isfile(filename) || error("CHK file does not exist: $(filename)")
    open(filename, "r") do io
        _ = String(read_fortran_record(io))
        num_bands = first(_record_as_int32(read_fortran_record(io)))
        num_exclude_bands = first(_record_as_int32(read_fortran_record(io)))
        exclude_bands = _record_as_int32(read_fortran_record(io))
        length(exclude_bands) == num_exclude_bands || error(
            "CHK exclude_bands length $(length(exclude_bands)) != num_exclude_bands $(num_exclude_bands).",
        )

        real_lattice = reshape(_record_as_float64(read_fortran_record(io)), 3, 3)
        recip_lattice = reshape(_record_as_float64(read_fortran_record(io)), 3, 3)
        lattice_err =
            norm(real_lattice * transpose(recip_lattice) / (2.0 * pi) - Matrix{Float64}(I, 3, 3))
        lattice_err <= 1e-8 ||
            error("CHK real/reciprocal lattice consistency error $(lattice_err).")

        num_kpts = first(_record_as_int32(read_fortran_record(io)))
        mp_vec = _record_as_int32(read_fortran_record(io))
        length(mp_vec) == 3 || error("CHK mp_grid has length $(length(mp_vec)); expected 3.")
        mp_grid = (mp_vec[1], mp_vec[2], mp_vec[3])
        num_kpts == prod(mp_grid) ||
            error("CHK num_kpts=$(num_kpts) does not match prod(mp_grid)=$(prod(mp_grid)).")
        kpt_red = _reshape_c_2d(_record_as_float64(read_fortran_record(io)), num_kpts, 3)
        nntot = first(_record_as_int32(read_fortran_record(io)))
        num_orbitals = first(_record_as_int32(read_fortran_record(io)))
        _ = String(read_fortran_record(io))
        have_disentangled = first(_record_as_int32(read_fortran_record(io))) != 0

        lwindow = falses(num_kpts, num_bands)
        ndimwin = zeros(Int, num_kpts)
        u_matrix_opt = Array{ComplexF64, 3}(undef, 0, 0, 0)
        if have_disentangled
            _ = _record_as_float64(read_fortran_record(io))
            lwindow .=
                _reshape_c_2d_int(_record_as_int32(read_fortran_record(io)), num_kpts, num_bands) .!=
                0
            ndimwin .= _record_as_int32(read_fortran_record(io))
            length(ndimwin) == num_kpts ||
                error("CHK ndimwin has length $(length(ndimwin)); expected $(num_kpts).")
            u_matrix_opt = _reshape_chk_u_matrix_opt(
                _read_complex_float_record(io),
                num_kpts,
                num_orbitals,
                num_bands,
            )
        end

        u_matrix = _reshape_chk_u_matrix(_read_complex_float_record(io), num_kpts, num_orbitals)
        _ = _read_complex_float_record(io)  # m_matrix, not needed for spin.

        v_matrix = zeros(ComplexF64, num_bands, num_orbitals, num_kpts)
        if have_disentangled
            for kpoint_index in 1:num_kpts
                selected = findall(lwindow[kpoint_index, :])
                length(selected) == ndimwin[kpoint_index] || error(
                    "CHK lwindow count $(length(selected)) != ndimwin $(ndimwin[kpoint_index]) at kpoint_index=$(kpoint_index).",
                )
                nd = ndimwin[kpoint_index]
                @views v_matrix[selected, :, kpoint_index] .=
                    u_matrix_opt[1:nd, :, kpoint_index] * u_matrix[:, :, kpoint_index]
            end
        else
            num_bands == num_orbitals || error(
                "CHK without disentanglement has num_bands=$(num_bands), num_orbitals=$(num_orbitals).",
            )
            v_matrix .= u_matrix
        end

        wannier_centers_cart =
            _reshape_c_2d(_record_as_float64(read_fortran_record(io)), num_orbitals, 3)
        _ = _record_as_float64(read_fortran_record(io))
        return WannierCHK(
            num_bands,
            num_orbitals,
            num_kpts,
            mp_grid,
            kpt_red,
            real_lattice,
            recip_lattice,
            wannier_centers_cart,
            v_matrix,
        )
    end
end
