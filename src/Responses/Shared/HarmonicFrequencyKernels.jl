"""Independent harmonic frequency controls in eV; G26--G34 of the THG design."""
struct HarmonicFrequencyPolicy
    gaussian::Bool
    resonance_width::Float64
    low_width::Float64
    gap_width::Float64
    function HarmonicFrequencyPolicy(
        gaussian::Bool,
        resonance_width::Real,
        low_width::Real,
        gap_width::Real,
    )
        all(x -> isfinite(x) && x > 0, (resonance_width, low_width, gap_width)) ||
            throw(ArgumentError("harmonic frequency and matrix widths must be finite and positive"))
        new(gaussian, Float64(resonance_width), Float64(low_width), Float64(gap_width))
    end
end

# Same SHG-style resonance, with the actual derivative in the signed gap variable.
function harmonic_resolvent(policy::HarmonicFrequencyPolicy, energy, gap, harmonic)
    width=policy.resonance_width
    x=gap-harmonic*energy
    denominator=x^2+width^2
    delta=policy.gaussian ? exp(-(x/width)^2)/(sqrt(pi)*width) : width/(pi*denominator)
    derivative=policy.gaussian ? -2x*delta/width^2 : -2x*width/(pi*denominator^2)
    return complex(-x/denominator, -pi*delta), complex((x^2-width^2)/denominator^2, -pi*derivative)
end

# Canonical pure-frequency pole: integer harmonic factors are applied separately.
function harmonic_low_pole(policy::HarmonicFrequencyPolicy, energy, degree::Integer)
    degree==0 && return 1.0+0im
    width=policy.low_width
    principal=energy/(energy^2+width^2)
    delta=policy.gaussian ? exp(-(energy/width)^2)/(sqrt(pi)*width) : width/(pi*(energy^2+width^2))
    return complex(principal, -delta)*principal^(degree-1)
end

# Remaining static-gap inverse and its derivative; never replace Gaussian G' by G^2.
function harmonic_gap_inverse(policy::HarmonicFrequencyPolicy, gap)
    denominator=gap^2+policy.gap_width^2
    return gap/denominator, (policy.gap_width^2-gap^2)/denominator^2
end
