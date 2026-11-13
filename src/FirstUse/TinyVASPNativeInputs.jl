module TinyVASPNativeInputs

# Pure miniature native input builders reused byte-for-byte from the shipped
# public qualification fixture. No parser, solver, network, or extension loading.
# Write actual fixed-record WAVECAR bytes with analytically small cutoff spheres.
function write_bounded_vasp_fixture(directory, spin_components, coefficient_type)
    poscar = joinpath(directory, "POSCAR")
    wavecar = joinpath(directory, "WAVECAR")
    write(poscar, "bounded fixture\n1.0\n5 0 0\n0 5 0\n0 0 5\nX\n1\nDirect\n0 0 0\n")
    expected = Array{ComplexF64, 3}[]
    open(wavecar, "w+") do io
        write(io, zeros(UInt8, 8*512))
        seek(io, 0)
        write(io, Float64[512, 1, coefficient_type == ComplexF32 ? 45200 : 45210])
        seek(io, 512)
        write(io, Float64[2, 2, 5, 5, 0, 0, 0, 5, 0, 0, 0, 5, 0])
        for kpoint in 1:2
            ng = kpoint
            header_record = 2 + (kpoint - 1)*3
            seek(io, 512*header_record)
            write(io, Float64[ng * spin_components, (kpoint - 1) / 2, 0, 0, -1, 0, 1, 1, 0, 0])
            values = zeros(ComplexF64, 2, ng, spin_components)
            for band in 1:2
                raw = coefficient_type[
                    complex(band + index/7, -kpoint - index/9) for index in 1:(ng * spin_components)
                ]
                seek(io, 512*(header_record + band))
                write(io, raw)
                values[band, :, :] .= reshape(raw, ng, spin_components)
            end
            push!(expected, values)
        end
    end
    return poscar, wavecar, expected
end

# Synthetic radial/projector data for bounded native integration fixtures.
function synthetic_potcar_block(element::AbstractString; q0::Float64 = 0.01)
    reciprocal = join(fill("0.1", 100), " ")
    return """
PAW_PBE $(element) 01Jan2000
2.0 tail
Non local Part
0 0 0
Reciprocal Space Part
$(reciprocal)
Real Space Part
0.1 0.1 0.1
PAW radial sets
augmentation charges (non sperical)
$(q0)
uccopancies in atom
grid
0.1 0.2 0.4
aepotential
pseudo wavefunction
0.10 0.20 0.30
ae wavefunction
0.12 0.22 0.32
End of Dataset
"""
end

# Shared tiny native bytes; creates no backend and changes no scientific reader.
function tiny_vasp_native_inputs(root)
    poscar, wavecar, _ = write_bounded_vasp_fixture(root, 2, ComplexF64)
    # Actual fixed-record WAVECAR with two orthonormal spinors. This
    # changes only synthetic workload inputs, never the native reader.
    open(wavecar, "r+") do stream
        for kpoint in 1:2, band in 1:2
            coefficients = zeros(ComplexF64, 2kpoint)
            coefficients[1 + (band - 1) * kpoint] = 1
            seek(stream, 512 * (2 + (kpoint - 1) * 3 + band))
            write(stream, coefficients)
        end
    end
    eig = joinpath(root, "tiny.eig")
    open(eig, "w") do stream
        for kpoint in 1:2, band in 1:2
            println(stream, "$(band) $(kpoint) $(band == 1 ? -1.0 : 1.0)")
        end
    end
    return (; poscar, wavecar, eig)
end

end
