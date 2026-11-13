"""
Write complex third-order spectra/densities, preserving named source terms and total.

Normalization belongs to Runtime. Both THG formulations retain their own total;
residuals are diagnostics of the finite-width realization, not acceptance claims.
"""
function write_third_order(
    directory,
    coordinates,
    values,
    components;
    jerk = false,
    projection = :ordered,
    formulation = :regrouped,
    response = :both,
    output = :both,
    digits = 16,
    slice = false,
    diagnostics = NamedTuple(),
    domain_metadata = nothing,
    effective_dimension = 3,
)
    paths=String[]
    forms=jerk ? (1,) : formulation==:both ? (1, 2) : formulation==:unregrouped ? (1,) : (2,)
    observables=jerk ? (1,) : response==:both ? (1, 2) : response==:conductivity ? (1,) : (2,)
    for form in forms, observable in observables, (index, component) in enumerate(components)
        label=join("xyz"[axis] for axis in component)
        formname=form==1 ? "unregrouped" : "regrouped"
        name=jerk ? "G_$(projection)" : observable==1 ? "sigma" : "chi"
        prefix=jerk ? "jc_$(name)" : "thg_$(formname)_$(name)"
        path=joinpath(directory, "$(prefix)_$(label).dat")
        terms=jerk ? ("G_$(projection)",) :
              form==1 ? ("eee", "iee_group", "iie_group", "iii") :
              ("regular", "linear_pole", "quadratic_pole", "cubic_pole")
        unit=jerk ? "A*m/(V^3*s^2)" : observable==1 ? "A*m/V^3" : "m^2/V^2"
        effective_dimension==2 &&
            (unit=jerk ? "A*m^2/(V^3*s^2)" : observable==1 ? "A*m^2/V^3" : "m^3/V^2")
        effective_dimension==1 &&
            (unit=jerk ? "A*m^3/(V^3*s^2)" : observable==1 ? "A*m^3/V^3" : "m^4/V^2")
        open(path, "w") do stream
            println(
                stream,
                "# ",
                jerk ? "JC" : "THG",
                " ",
                name,
                " component=",
                label,
                " units=",
                unit,
                " measure=",
                "bulk",
            )
            println(
                stream,
                slice ? "# fractional-k density" :
                "# response integrated over the declared domain; one count per explicit model state",
            )
            if domain_metadata!==nothing
                for (key, value) in pairs(domain_metadata)
                    println(stream, "# ", key, "=", value)
                end
            end
            jerk && println(
                stream,
                "# material coefficient excludes lifetimes; ordered optical slots b:+omega,c:-omega,d:0; degeneracies diagnostic",
            )
            !jerk && println(
                stream,
                "# pole labels inherited from conductivity; finite-width formulation residual is diagnostic",
            )
            labels=slice ? ["kx", "ky", "kz", "energy_eV"] : ["energy_eV"]
            (jerk || output!=:terms) && append!(labels, ["total_re", "total_im"])
            !jerk &&
                output!=:total &&
                append!(labels, [term*suffix for term in terms for suffix in ("_re", "_im")])
            println(stream, "# ", join(labels, " "))
            format=Printf.Format("%."*string(digits)*"e")
            for row in axes(values, 1)
                numbers=collect(coordinates[row, :])
                if jerk || output!=:terms
                    total=sum(@view values[row, index, :, observable, form])
                    append!(numbers, (real(total), imag(total)))
                end
                if !jerk && output!=:total
                    for term in eachindex(terms)
                        value=values[row, index, term, observable, form]
                        append!(numbers, (real(value), imag(value)))
                    end
                end
                println(stream, join((Printf.format(format, x) for x in numbers), " "))
            end
        end
        push!(paths, path)
    end
    diagnostic_path=joinpath(
        directory,
        jerk ? "jc_numerical_diagnostics.txt" : "thg_numerical_diagnostics.txt",
    )
    open(diagnostic_path, "w") do stream
        for (key, value) in pairs(diagnostics)
            println(stream, key, "=", value)
        end
        println(stream, "convergence_status=NOT_ESTABLISHED_BY_SINGLE_CALCULATION")
    end
    push!(paths, diagnostic_path)
    if !jerk && formulation==:both
        path=joinpath(directory, "thg_formulation_residual.dat")
        open(path, "w") do stream
            println(stream, "# raw difference of SI normalized totals; diagnostic at finite widths")
            println(stream, "# row component observable abs_difference normalized_residual")
            for row in axes(values, 1), component in axes(values, 2), observable in observables
                left=sum(@view values[row, component, :, observable, 1])
                right=sum(@view values[row, component, :, observable, 2])
                difference=abs(left-right)
                scale=max(abs(left), abs(right))
                println(
                    stream,
                    join(
                        (row, component, observable, difference, scale==0 ? 0.0 : difference/scale),
                        " ",
                    ),
                )
            end
        end
        push!(paths, path)
    end
    return paths
end
