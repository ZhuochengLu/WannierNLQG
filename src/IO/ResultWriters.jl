using Printf

"""
Write photon-energy rows followed by real/imaginary Cartesian tensor components; return the created file path.

Energies are in eV and tensor units are supplied by the caller. Preserve rightmost-index-fastest columns, require supported axis shapes and `digits` in `7:17`, and create the output directory if needed.
"""
function write_response_tensor(
    fermi_energy::Float64,
    photon_energies::Vector{Float64},
    tensor::Array{ComplexF64},
    spatial_dimension::Int,
    directory::AbstractString,
    filename::AbstractString,
    ;
    digits::Int = 7,
)
    7 <= digits <= 17 ||
        throw(ArgumentError("response output digits must lie in 7:17; got $(digits)"))
    number_format = Printf.Format("%.$(digits)e")
    point_count = length(photon_energies)
    tensor_order = ndims(tensor) - 1
    axis_sizes = Int[size(tensor, axis + 1) for axis in 1:tensor_order]
    size(tensor, 1) == point_count || error(
        "Dimension mismatch: tensor has $(size(tensor, 1)) energy points, expected $(point_count).",
    )
    all(size == spatial_dimension for size in axis_sizes) ||
        tensor_order == 4 &&
        axis_sizes == [spatial_dimension, 3, spatial_dimension, spatial_dimension] ||
        error(
            "Unsupported response tensor axis sizes=$(Tuple(axis_sizes)) for spatial_dimension=$(spatial_dimension).",
        )
    coordinates = ["x", "y", "z"]

    isdir(directory) || mkpath(directory)
    filepath = joinpath(directory, filename)
    open(filepath, "w") do file
        println(file, "#### WannierNLQG response tensor")

        # Preserve the historical numerical-result header byte-for-byte. Public
        # configuration and metadata use descriptive names, but result columns
        # are an independent compatibility contract.
        header = "#    Efermi     Omega"
        total_components = prod(axis_sizes)
        for linear_index in 1:total_components
            remainder = linear_index - 1
            indices = zeros(Int, tensor_order)
            for rank_index in tensor_order:-1:1
                indices[rank_index] = remainder % axis_sizes[rank_index] + 1
                remainder ÷= axis_sizes[rank_index]
            end
            header *= "     " * join(coordinates[indices], "")
        end
        println(file, header)

        index_ranges = Tuple(1:size for size in axis_sizes)
        for energy_index in 1:point_count
            print(
                file,
                Printf.format(number_format, fermi_energy),
                "    ",
                Printf.format(number_format, photon_energies[energy_index]),
            )
            for reversed_indices in Iterators.product(reverse(index_ranges)...)
                indices = reverse(reversed_indices)
                tensor_index = CartesianIndex((energy_index, indices...))
                print(
                    file,
                    "    ",
                    Printf.format(number_format, real(tensor[tensor_index])),
                    "    ",
                    Printf.format(number_format, imag(tensor[tensor_index])),
                    "    ",
                )
            end
            println(file)
        end
    end
    return filepath
end

"""
Return the two integer slice dimensions from a mesh vector; reject mesh vectors whose length is not two.
"""
function kslice_output_size(k_mesh::AbstractVector{<:Integer})
    length(k_mesh) == 2 ||
        error("k-resolved output expects k_mesh with length 2, got length=$(length(k_mesh))")
    return (Int(k_mesh[1]), Int(k_mesh[2]))
end

"""
Write a real slice matrix row by row to a text file and return its path.

Require its shape to match the two mesh counts; create the output directory as needed. Values are serialized without unit conversion or normalization.
"""
function write_kslice(
    data::Matrix{Float64},
    k_mesh::AbstractVector{<:Integer},
    directory::AbstractString,
    filename::AbstractString,
)
    expected_size = kslice_output_size(k_mesh)
    size(data) == expected_size ||
        error("Dimension mismatch: data has size $(size(data)), expected $(expected_size).")

    isdir(directory) || mkpath(directory)
    filepath = joinpath(directory, filename)
    open(filepath, "w") do file
        for row_index in axes(data, 1)
            println(file, join(data[row_index, :], " "))
        end
    end
    return filepath
end
