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
                    values = split(readline(file))
                    hamiltonian_r[row_index, column, r_index] =
                        ComplexF64(parse(Float64, values[3]), parse(Float64, values[4]))
                end
            end
        end

        for r_index in 1:num_r_vectors
            readline(file)
            readline(file)
            for column in 1:num_orbitals
                for row_index in 1:num_orbitals
                    values = split(readline(file))
                    position_r[row_index, column, 1, r_index] =
                        ComplexF64(parse(Float64, values[3]), parse(Float64, values[4]))
                    position_r[row_index, column, 2, r_index] =
                        ComplexF64(parse(Float64, values[5]), parse(Float64, values[6]))
                    position_r[row_index, column, 3, r_index] =
                        ComplexF64(parse(Float64, values[7]), parse(Float64, values[8]))
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
