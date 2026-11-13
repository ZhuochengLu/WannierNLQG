"""Worker-local occupation values and Cartesian first/second derivatives."""
struct HarmonicOccupationWorkspace
    values::Vector{Float64}
    first::Matrix{Float64}
    second::Array{Float64, 3}
end

# Allocate once per worker; occupation derivatives are task-specific.
"""Allocate worker-private occupation values and first and second Cartesian derivatives for the band count."""
HarmonicOccupationWorkspace(
    count::Integer,
)=HarmonicOccupationWorkspace(zeros(count), zeros(count, 3), zeros(count, 3, 3))

"""
Fill G9/G10 occupation derivatives using exact FD or the explicit SHG Gaussian approximation.

At the SHG low-temperature threshold all derivatives vanish. Occupations retain
SHG's equality convention. Energies are eV, temperature K, derivatives Cartesian.
"""
function harmonic_occupations!(
    workspace::HarmonicOccupationWorkspace,
    geometry,
    energies,
    fermi,
    temperature,
    exact,
)
    theta=8.617333262145e-5*temperature
    for n in eachindex(energies)
        occupation=second_harmonic_occupation(energies[n], fermi, temperature)
        workspace.values[n]=occupation
        first=0.0;
        second=0.0
        if temperature>1e-7
            offset=energies[n]-fermi
            if exact
                first=-occupation*(1-occupation)/theta
                second=occupation*(1-occupation)*(1-2occupation)/theta^2
            elseif abs(offset)<=5theta
                first=-exp(-0.5*(offset/theta)^2)/(theta*sqrt(2pi))
                second=-offset/theta^2*first
            end
        end
        for a in 1:3
            workspace.first[n, a]=first*geometry.gradients[n, a]
            for b in 1:3
                workspace.second[
                    n,
                    a,
                    b,
                ]=second*geometry.gradients[n, a]*geometry.gradients[
                    n,
                    b,
                ]+first*geometry.hessians[n, a, b]
            end
        end
    end
    return workspace
end
