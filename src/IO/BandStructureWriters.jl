"""Atomically write the deterministic tabular Band-task result."""
function write_band_structure(
    path::AbstractString,
    distances::AbstractVector{<:Real},
    kpoints::AbstractMatrix{<:Real},
    relative_energies::AbstractMatrix{<:Real},
    ;
    energy_reference_eV::Real,
)
    point_count = length(distances)
    size(kpoints) == (point_count, 3) ||
        throw(DimensionMismatch("band kpoints must have size ($(point_count), 3)"))
    size(relative_energies, 1) == point_count ||
        throw(DimensionMismatch("band energies must have $(point_count) rows"))
    all(isfinite, distances) || error("band distances contain non-finite values")
    all(isfinite, kpoints) || error("band fractional coordinates contain non-finite values")
    all(isfinite, relative_energies) || error("band energies contain non-finite values")
    isfinite(energy_reference_eV) || error("band energy reference must be finite")

    directory = dirname(path)
    isdir(directory) || mkpath(directory)
    temporary, stream = mktemp(directory; cleanup = false)
    try
        println(stream, "#### WannierNLQG band structure")
        println(stream, "# energy_reference_E_ref_eV = ", @sprintf("%.17e", energy_reference_eV))
        println(stream, "# energy_convention = ascending_eigenvalues_minus_E_ref")
        println(stream, "# energy_unit = eV")
        print(stream, "# distance_A^-1 k1_fractional k2_fractional k3_fractional")
        for band in axes(relative_energies, 2)
            print(stream, " band_$(band)_minus_E_ref_eV")
        end
        println(stream)
        for point in 1:point_count
            print(stream, @sprintf("%.15e", distances[point]))
            for axis in 1:3
                print(stream, ' ', @sprintf("%.15e", kpoints[point, axis]))
            end
            for band in axes(relative_energies, 2)
                print(stream, ' ', @sprintf("%.15e", relative_energies[point, band]))
            end
            println(stream)
        end
        close(stream)
        mv(temporary, path; force = true)
    catch
        isopen(stream) && close(stream)
        isfile(temporary) && rm(temporary; force = true)
        rethrow()
    end
    return String(path)
end
