"""Private resolved third-order options; distinct physical and numerical controls are retained."""
struct ThirdOrderSettings
    formulation::Symbol
    response::Symbol
    output::Symbol
    projection::Symbol
    components::Tuple{Vararg{NTuple{4, Int}}}
    frequency_policy::HarmonicFrequencyPolicy
    eta_correction::Bool
    exact_occupations::Bool
end
