"""Write compact geometric moments and DC conductivities with explicit tensor axes.

Inputs are already physically normalized. IO does not perform a prefactor,
symmetrization, occupation, integral-expression substitution or qualification.
Only actually computed moment/component channels are written.
"""
function write_berry_multipole_dc(
    directory::AbstractString,
    stem::AbstractString,
    fermi_energies,
    temperature::Real,
    relaxation_time_fs::Real,
    moments::AbstractMatrix{<:Real},
    moment_components,
    conductivity::AbstractMatrix{<:Real},
    components;
    moment_unit::AbstractString,
    conductivity_unit::AbstractString,
    metadata::NamedTuple,
    digits::Int = 17,
)
    basename(stem) == stem && !(stem in ("", ".", "..")) ||
        throw(ArgumentError("invalid result stem"))
    7 <= digits <= 17 || throw(ArgumentError("response precision must be 7:17"))
    size(moments) == (length(fermi_energies), length(moment_components)) ||
        throw(DimensionMismatch("moment output axes"))
    size(conductivity) == (length(fermi_energies), length(components)) ||
        throw(DimensionMismatch("conductivity output axes"))
    all(isfinite, moments) &&
    all(isfinite, conductivity) &&
    all(isfinite, fermi_energies) &&
    isfinite(temperature) &&
    isfinite(relaxation_time_fs) || throw(ArgumentError("nonfinite BCD/BCQ result"))
    !isempty(components) && !isempty(moment_components) ||
        throw(ArgumentError("nonempty output channels required"))
    temperature >= 0 && relaxation_time_fs > 0 ||
        throw(ArgumentError("invalid temperature or lifetime"))
    rank = length(first(components))
    rank in (3, 4) &&
    all(c -> length(c) == rank, moment_components) &&
    all(c -> length(c) == rank, components) || throw(DimensionMismatch("tensor output rank"))
    all(c -> all(axis -> axis in 1:3, c), components) &&
    all(c -> all(axis -> axis in 1:3, c), moment_components) ||
        throw(ArgumentError("invalid Cartesian output component"))
    mkpath(directory)
    moment_path = joinpath(directory, stem * "_moments.dat")
    conductivity_path = joinpath(directory, stem * "_conductivity.dat")
    function header(io, unit, tensor_order)
        println(io, "# unit=", unit)
        println(io, "# tensor_order=", tensor_order)
        for (key, value) in pairs(metadata)
            println(io, "# ", key, "=", value)
        end
    end
    open(moment_path, "w") do io
        header(io, moment_unit, rank == 3 ? "D[a,b;c]" : "Q[a,b;c,d]")
        println(io, "# columns: mu_eV temperature_K ", rank == 3 ? "a b c" : "a b c d", " moment")
        for mu in eachindex(fermi_energies), (channel, component) in enumerate(moment_components)
            @printf(io, "%.*e %.*e", digits, fermi_energies[mu], digits, temperature)
            for axis in component
                print(io, ' ', axis)
            end
            @printf(io, " %.*e\n", digits, moments[mu, channel])
        end
    end
    open(conductivity_path, "w") do io
        header(io, conductivity_unit, rank == 3 ? "sigma[b,c;a]" : "sigma[b,c,d;a]")
        println(
            io,
            "# columns: mu_eV temperature_K relaxation_time_fs ",
            rank == 3 ? "b c a" : "b c d a",
            " conductivity",
        )
        for mu in eachindex(fermi_energies), (channel, component) in enumerate(components)
            @printf(
                io,
                "%.*e %.*e %.*e",
                digits,
                fermi_energies[mu],
                digits,
                temperature,
                digits,
                relaxation_time_fs
            )
            for axis in component
                print(io, ' ', axis)
            end
            @printf(io, " %.*e\n", digits, conductivity[mu, channel])
        end
    end
    return [moment_path, conductivity_path]
end

"""Write unweighted BCD/BCQ slice moments and SI conductivity densities.

Coordinates remain fractional reciprocal coordinates. The supplied local values
already include occupations and the selected FS/sea expression. IO adds no cell,
plane, quadrature, SI or symmetrization factor. Every chemical potential remains
explicit in the rows; conductivity and moment component orders are independent.
"""
function write_berry_multipole_kslice(
    directory::AbstractString,
    stem::AbstractString,
    coordinates::AbstractMatrix{<:Real},
    fermi_energies,
    temperature::Real,
    relaxation_time_fs::Real,
    moments::AbstractArray{<:Real, 3},
    moment_components,
    conductivity::AbstractArray{<:Real, 3},
    components;
    moment_unit::AbstractString,
    conductivity_unit::AbstractString,
    metadata::NamedTuple,
    digits::Int = 17,
)
    basename(stem) == stem && !(stem in ("", ".", "..")) ||
        throw(ArgumentError("invalid result stem"))
    7 <= digits <= 17 || throw(ArgumentError("response precision must be 7:17"))
    points = size(coordinates, 1)
    points > 0 && size(coordinates, 2) == 3 || throw(DimensionMismatch("slice coordinates"))
    size(moments) == (points, length(fermi_energies), length(moment_components)) ||
        throw(DimensionMismatch("slice moment axes"))
    size(conductivity) == (points, length(fermi_energies), length(components)) ||
        throw(DimensionMismatch("slice conductivity axes"))
    !isempty(components) && !isempty(moment_components) && !isempty(fermi_energies) ||
        throw(ArgumentError("nonempty slice axes required"))
    all(isfinite, coordinates) &&
    all(isfinite, fermi_energies) &&
    all(isfinite, moments) &&
    all(isfinite, conductivity) &&
    isfinite(temperature) &&
    temperature >= 0 &&
    isfinite(relaxation_time_fs) &&
    relaxation_time_fs > 0 || throw(ArgumentError("nonfinite or invalid slice result"))
    rank = length(first(components))
    rank in (3, 4) &&
    all(c -> length(c) == rank, moment_components) &&
    all(c -> length(c) == rank, components) || throw(DimensionMismatch("slice tensor rank"))
    all(c -> all(axis -> axis in 1:3, c), components) &&
    all(c -> all(axis -> axis in 1:3, c), moment_components) ||
        throw(ArgumentError("invalid slice Cartesian component"))
    mkpath(directory)
    outputs = String[]
    for (name, values, channels, unit, order) in (
        ("moments", moments, moment_components, moment_unit, rank == 3 ? "D[a,b;c]" : "Q[a,b;c,d]"),
        (
            "conductivity",
            conductivity,
            components,
            conductivity_unit,
            rank == 3 ? "sigma[b,c;a]" : "sigma[b,c,d;a]",
        ),
    )
        path = joinpath(directory, stem * "_" * name * ".dat")
        open(path, "w") do io
            println(io, "# schema=wanniernlqg.berry-multipole-kslice/1.0")
            println(io, "# unit=", unit)
            println(io, "# tensor_order=", order)
            for (key, value) in pairs(metadata)
                println(io, "# ", key, "=", value)
            end
            println(
                io,
                "# columns: kx ky kz mu_eV temperature_K relaxation_time_fs ",
                rank == 3 ? "axis1 axis2 axis3" : "axis1 axis2 axis3 axis4",
                " value",
            )
            for index in 1:points,
                mu in eachindex(fermi_energies),
                (channel, component) in enumerate(channels)

                for axis in 1:3
                    @printf(io, "%.*e ", digits, coordinates[index, axis])
                end
                @printf(
                    io,
                    "%.*e %.*e %.*e",
                    digits,
                    fermi_energies[mu],
                    digits,
                    temperature,
                    digits,
                    relaxation_time_fs
                )
                for axis in component
                    print(io, ' ', axis)
                end
                @printf(io, " %.*e\n", digits, values[index, mu, channel])
            end
        end
        push!(outputs, path)
    end
    return outputs
end
