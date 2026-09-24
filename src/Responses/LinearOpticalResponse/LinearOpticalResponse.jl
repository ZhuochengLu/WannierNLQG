module LinearOpticalResponse

using LinearAlgebra
using ...MatrixElements
using ..Responses:
    RESPONSE_CHARGE_C,
    RESPONSE_HBAR_JS,
    RESPONSE_HBAR_EVS,
    RESPONSE_KB_EV,
    RESPONSE_EPSILON0,
    RESPONSE_BOHR_MAGNETON,
    response_occupation,
    response_fermi_derivative,
    response_thermal_weight

include("LinearOpticalResponseKernels.jl")
export linear_optical_response, model_dielectric_response

end
