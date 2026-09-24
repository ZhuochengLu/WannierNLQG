
const RESPONSE_CHARGE_C = 1.602176634e-19
const RESPONSE_HBAR_JS = 1.054571817e-34
const RESPONSE_HBAR_EVS = RESPONSE_HBAR_JS / RESPONSE_CHARGE_C
const RESPONSE_KB_EV = 8.617333262145e-5
const RESPONSE_EPSILON0 = 8.8541878128e-12
const RESPONSE_BOHR_MAGNETON = 9.2740100783e-24

"""Stable Fermi occupation with a strict zero-temperature step (half at equality)."""
function response_occupation(energy, mu, temperature)
    temperature == 0 && return energy < mu ? 1.0 : energy > mu ? 0.0 : 0.5
    x=(energy-mu)/(RESPONSE_KB_EV*temperature)
    z=exp(-abs(x))
    return x >= 0 ? z/(1+z) : 1/(1+z)
end

"""Minus the Fermi derivative in inverse eV; FS width is independent of physical rates."""
function response_fermi_derivative(energy, mu, temperature, kind, eta)
    if temperature > 0
        scale=RESPONSE_KB_EV*temperature
        z=exp(-abs((energy-mu)/scale))
        return z/(scale*(1+z)^2)
    end
    eta > 0 || throw(ArgumentError("T=0 requires positive eta_fs_ev"))
    x=(energy-mu)/eta
    kind == :gaussian && return exp(-x*x)/(sqrt(pi)*eta)
    kind == :lorentzian && return 1/(pi*eta*(1+x*x))
    throw(ArgumentError("Explicit Gaussian or Lorentzian FS broadening required"))
end

"""Stable thermodynamic weight kBT log(1+exp((mu-E)/kBT)), in eV."""
function response_thermal_weight(energy, mu, temperature)
    temperature==0 && return max(mu-energy, 0.0)
    scale=RESPONSE_KB_EV*temperature
    x=(mu-energy)/scale
    return scale*(max(x, 0.0)+log1p(exp(-abs(x))))
end
