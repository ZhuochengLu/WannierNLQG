"""
Write complex SHG spectra or k-resolved densities with explicit units and seven term names.

Values use (row,component,term,quantity); coordinates contain energy alone for
integrals or fractional k plus energy for slices. No physical normalization is
performed here. Each total is summed from the same seven stored contributions.
"""
function write_second_harmonic(
    directory,
    coordinates,
    values,
    components,
    terms;
    output = :total,
    response = :both,
    digits = 12,
    slice = false,
)
    paths = String[]
    for (quantity, name, unit) in ((1, "chi", "pm/V"), (2, "sigma", "A/V^2"))
        response == :susceptibility && quantity == 2 && continue
        response == :conductivity && quantity == 1 && continue
        for (index, component) in enumerate(components)
            label = join("xyz"[axis] for axis in component)
            path = joinpath(directory, "shg_$(name)_$(label).dat")
            open(path, "w") do stream
                println(stream, "# SHG ", name, " units=", unit, " component=", label)
                println(
                    stream,
                    slice ? "# k-fractional density; full-BZ arithmetic mean recovers integral" :
                    "# full-BZ normalized susceptibility/conductivity",
                )
                labels = slice ? ["kx", "ky", "kz", "energy_eV"] : ["energy_eV"]
                output != :terms && append!(labels, ["total_re", "total_im"])
                output != :total &&
                    append!(labels, [term * suffix for term in terms for suffix in ("_re", "_im")])
                println(stream, "# ", join(labels, " "))
                format = Printf.Format("%." * string(digits) * "e")
                for row in axes(values, 1)
                    numbers = collect(coordinates[row, :])
                    if output != :terms
                        total = sum(@view values[row, index, :, quantity])
                        append!(numbers, (real(total), imag(total)))
                    end
                    if output != :total
                        for term in eachindex(terms)
                            value = values[row, index, term, quantity]
                            append!(numbers, (real(value), imag(value)))
                        end
                    end
                    println(stream, join((Printf.format(format, value) for value in numbers), " "))
                end
            end
            push!(paths, path)
        end
    end
    return paths
end
