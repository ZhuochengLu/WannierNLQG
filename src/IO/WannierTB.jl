"""Read only the orbital count from a Wannier90 `_tb.dat` header."""
function read_wannier_tb_num_orbitals(filename::AbstractString)
    open(filename, "r") do file
        readline(file)
        for _ in 1:3
            readline(file)
        end
        return parse(Int, readline(file))
    end
end

# Advance past the two matrix indices while preserving the lazy token iterator.
@inline function _tb_after_matrix_indices(tokens)
    first_token = iterate(tokens)
    first_token === nothing && error("Incomplete Wannier TB matrix record")
    second_token = iterate(tokens, first_token[2])
    second_token === nothing && error("Incomplete Wannier TB matrix record")
    return second_token[2]
end

# Parse one numeric token and return the state for the next matrix component.
@inline function _tb_next_float(tokens, state)
    token = iterate(tokens, state)
    token === nothing && error("Incomplete Wannier TB matrix record")
    return parse(Float64, token[1]), token[2]
end

"""
Read Wannier90 real-space Hamiltonian and position blocks into a validated `TightBindingModel`.

Retain row lattice vectors, R degeneracies, orbital numbering, Hamiltonian eV and position/lattice length units; malformed dimensions or block records raise errors.

Read wannier tb from its configured input.
"""
function read_wannier_tb(filename::AbstractString)
    open(filename, "r") do file
        readline(file)

        lattice = zeros(Float64, 3, 3)
        for index in 1:3
            lattice[index, :] = parse.(Float64, split(readline(file)))
        end

        num_orbitals = parse(Int, readline(file))
        num_r_vectors = parse(Int, readline(file))

        r_degeneracies = Int[]
        for _ in 1:ceil(Int, num_r_vectors / 15)
            append!(r_degeneracies, parse.(Int, split(readline(file))))
        end

        r_vectors = zeros(Int, 3, num_r_vectors)
        hamiltonian_r = zeros(ComplexF64, num_orbitals, num_orbitals, num_r_vectors)
        position_r = zeros(ComplexF64, num_orbitals, num_orbitals, 3, num_r_vectors)

        for r_index in 1:num_r_vectors
            readline(file)
            r_vectors[:, r_index] = parse.(Int, split(readline(file)))
            for column in 1:num_orbitals
                for row_index in 1:num_orbitals
                    values = eachsplit(readline(file))
                    state = _tb_after_matrix_indices(values)
                    real_part, state = _tb_next_float(values, state)
                    imaginary_part, state = _tb_next_float(values, state)
                    hamiltonian_r[row_index, column, r_index] =
                        ComplexF64(real_part, imaginary_part)
                end
            end
        end

        for r_index in 1:num_r_vectors
            readline(file)
            readline(file)
            for column in 1:num_orbitals
                for row_index in 1:num_orbitals
                    values = eachsplit(readline(file))
                    state = _tb_after_matrix_indices(values)
                    position_1_real, state = _tb_next_float(values, state)
                    position_1_imaginary, state = _tb_next_float(values, state)
                    position_2_real, state = _tb_next_float(values, state)
                    position_2_imaginary, state = _tb_next_float(values, state)
                    position_3_real, state = _tb_next_float(values, state)
                    position_3_imaginary, state = _tb_next_float(values, state)
                    position_r[row_index, column, 1, r_index] =
                        ComplexF64(position_1_real, position_1_imaginary)
                    position_r[row_index, column, 2, r_index] =
                        ComplexF64(position_2_real, position_2_imaginary)
                    position_r[row_index, column, 3, r_index] =
                        ComplexF64(position_3_real, position_3_imaginary)
                end
            end
        end

        return TightBindingModel(
            lattice,
            num_orbitals,
            num_r_vectors,
            r_degeneracies,
            r_vectors,
            hamiltonian_r,
            position_r,
        )
    end
end

"""Read only the home-cell diagonal position entries needed by run metadata."""
function _read_wannier_tb_centers(filename::AbstractString)
    open(filename, "r") do file
        readline(file)
        for _ in 1:3
            readline(file)
        end
        num_orbitals = parse(Int, readline(file))
        num_r_vectors = parse(Int, readline(file))
        for _ in 1:cld(num_r_vectors, 15)
            readline(file)
        end

        home_index = 0
        for r_index in 1:num_r_vectors
            readline(file)
            r_vector = parse.(Int, split(readline(file)))
            if home_index == 0 && length(r_vector) == 3 && all(iszero, r_vector)
                home_index = r_index
            end
            for _ in 1:(num_orbitals * num_orbitals)
                readline(file)
            end
        end
        home_index == 0 && error("Could not find home-cell position matrix in model data.")

        centers = zeros(Float64, 3, num_orbitals)
        for r_index in 1:home_index
            readline(file)
            readline(file)
            for column in 1:num_orbitals
                for row_index in 1:num_orbitals
                    line = readline(file)
                    if r_index == home_index && row_index == column
                        values = eachsplit(line)
                        state = _tb_after_matrix_indices(values)
                        center_1, state = _tb_next_float(values, state)
                        _, state = _tb_next_float(values, state)
                        center_2, state = _tb_next_float(values, state)
                        _, state = _tb_next_float(values, state)
                        center_3, state = _tb_next_float(values, state)
                        _, state = _tb_next_float(values, state)
                        centers[1, column] = center_1
                        centers[2, column] = center_2
                        centers[3, column] = center_3
                    end
                end
            end
        end
        return centers
    end
end
