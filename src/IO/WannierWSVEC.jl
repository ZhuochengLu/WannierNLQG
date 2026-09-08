"""Strictly parsed Wannier90 pair-dependent Wigner-Seitz translations."""
struct WannierWSVEC
    path::String
    translations::Array{Vector{NTuple{3, Int}}, 3}
    file_sha256::String
end

# Parse one whitespace-delimited integer record without accepting extra fields.
function _parse_wsvec_integer_record(line::AbstractString, count::Int, label::AbstractString)
    fields = split(strip(line))
    length(fields) == count ||
        throw(ArgumentError("$(label) must contain exactly $(count) integers"))
    try
        return parse.(Int, fields)
    catch exception
        exception isa ArgumentError || rethrow()
        throw(ArgumentError("$(label) contains a non-integer value"))
    end
end

"""
Read a Wannier90 `wsvec.dat` file and bind every record to the supplied TB R order.

The file must declare `use_ws_distance=.true.`, contain exactly one ordered record
for every `(R,m,n)`, use one-based orbital indices, list a positive number of
unique translations, and contain no trailing nonblank records. Returned entries
are supercell translations `T`; the physical Fourier image is `R + T`.
"""
function read_wannier_wsvec(
    filename::AbstractString,
    num_orbitals::Integer,
    r_vectors::AbstractMatrix{<:Integer},
)
    path = normpath(abspath(filename))
    isfile(path) || throw(ArgumentError("Wannier90 wsvec file does not exist: $(path)"))
    orbital_count = Int(num_orbitals)
    orbital_count > 0 || throw(ArgumentError("num_orbitals must be positive"))
    size(r_vectors, 1) == 3 || throw(ArgumentError("r_vectors must have three rows"))
    lines = readlines(path)
    isempty(lines) && throw(ArgumentError("Wannier90 wsvec file is empty"))
    occursin(r"use_ws_distance\s*=\s*\.true\."i, lines[1]) ||
        throw(ArgumentError("Wannier90 wsvec header must declare use_ws_distance=.true."))
    translations =
        Array{Vector{NTuple{3, Int}}, 3}(undef, orbital_count, orbital_count, size(r_vectors, 2))
    cursor = 2
    for r_index in axes(r_vectors, 2), left in 1:orbital_count, right in 1:orbital_count
        cursor <= length(lines) || throw(
            ArgumentError("Wannier90 wsvec is truncated before record $(r_index),$(left),$(right)"),
        )
        key = _parse_wsvec_integer_record(lines[cursor], 5, "Wannier90 wsvec key")
        cursor += 1
        key[1:3] == collect(@view(r_vectors[:, r_index])) || throw(
            ArgumentError(
                "Wannier90 wsvec R-vector order disagrees with the model at index $(r_index)",
            ),
        )
        (key[4], key[5]) == (left, right) || throw(
            ArgumentError("Wannier90 wsvec orbital-pair order is invalid at R index $(r_index)"),
        )
        cursor <= length(lines) ||
            throw(ArgumentError("Wannier90 wsvec is truncated before its image count"))
        count_values = _parse_wsvec_integer_record(lines[cursor], 1, "Wannier90 wsvec image count")
        cursor += 1
        image_count = only(count_values)
        image_count > 0 || throw(ArgumentError("Wannier90 wsvec image count must be positive"))
        images = Vector{NTuple{3, Int}}(undef, image_count)
        for image_index in 1:image_count
            cursor <= length(lines) ||
                throw(ArgumentError("Wannier90 wsvec is truncated inside an image list"))
            image = _parse_wsvec_integer_record(lines[cursor], 3, "Wannier90 wsvec translation")
            cursor += 1
            images[image_index] = Tuple(image)
        end
        length(unique(images)) == length(images) || throw(
            ArgumentError("Wannier90 wsvec contains duplicate translations for one orbital pair"),
        )
        translations[left, right, r_index] = images
    end
    cursor <= length(lines) &&
        any(!isempty(strip(line)) for line in lines[cursor:end]) &&
        throw(ArgumentError("Wannier90 wsvec contains trailing records"))
    file_sha256 = open(path, "r") do io
        bytes2hex(SHA.sha256(io))
    end
    return WannierWSVEC(path, translations, file_sha256)
end

"""Read `wsvec.dat` against the orbital and R support of one TB model."""
read_wannier_wsvec(filename::AbstractString, model::TightBindingModel) =
    read_wannier_wsvec(filename, model.num_orbitals, model.r_vectors)
