using LinearAlgebra
using WannierNLQG

const SSC_RUNTIME = WannierNLQG.Runtime
const SSC_RESPONSES = WannierNLQG.Responses
const SSC_MATRIX_ELEMENTS = WannierNLQG.MatrixElements

function make_synthetic_ssc_workspace(; spatial_dimension = 2)
    count = 3
    plan = SSC_MATRIX_ELEMENTS.compile_matrix_plan(
        SSC_MATRIX_ELEMENTS.MatrixElementRequest(
            SSC_MATRIX_ELEMENTS.SPIN_VELOCITY,
            SSC_MATRIX_ELEMENTS.BERRY_CONNECTION,
            SSC_MATRIX_ELEMENTS.INTERNAL_CONNECTION_DERIVATIVES,
            SSC_MATRIX_ELEMENTS.HAMILTONIAN_SECOND_DERIVATIVES;
            spatial_dimension = spatial_dimension,
        ),
    )
    data = SSC_MATRIX_ELEMENTS.KPointMatrixData(count, 1, plan)
    data.spectrum.energies .= [-0.5, 0.4, 1.2]
    for a in 1:spatial_dimension
        base = ComplexF64[
            0.1a 0.02a+0.01im 0.03a-0.02im
            0.02a-0.01im 0.2a -0.04a+0.01im
            0.03a+0.02im -0.04a-0.01im 0.3a
        ]
        data.hamiltonian_derivatives[:, :, a] .= base
        data.spin_velocity.hamiltonian_gauge[:, :, a, 1] .= base
    end
    for a in 1:spatial_dimension, b in 1:spatial_dimension
        value = ComplexF64[
            0.2(a+b) 0.01(a+b)+0.02im 0.03(a+b)-0.01im
            0.01(a+b)-0.02im 0.3(a+b) -0.02(a+b)+0.03im
            0.03(a+b)+0.01im -0.02(a+b)-0.03im 0.4(a+b)
        ]
        data.hamiltonian_second_derivatives[:, :, a, b] .= value
    end
    data.spin.hamiltonian_gauge[:, :, 1] .= Matrix{ComplexF64}(I, count, count)
    z3 = zeros(ComplexF64, count, count, spatial_dimension)
    z4 = zeros(ComplexF64, count, count, spatial_dimension, spatial_dimension)
    z5 = zeros(ComplexF64, count, count, 3, spatial_dimension, spatial_dimension)
    z6 = zeros(ComplexF64, count, count, spatial_dimension, 3, spatial_dimension, spatial_dimension)
    workspace = SSC_RESPONSES.ShiftSpinCurrentConventionalWorkspace(
        nothing,
        data,
        zeros(ComplexF64, count, count, spatial_dimension),
        zeros(ComplexF64, count, count, spatial_dimension, spatial_dimension),
        z3,
        z4,
        z5,
        copy(z5),
        z6,
        zeros(Float64, count, count),
        zeros(ComplexF64, count, count),
        zeros(ComplexF64, count, count),
        zeros(ComplexF64, count, count),
        zeros(ComplexF64, count, count),
        zeros(Float64, 1),
        zeros(Float64, count, count),
        SSC_RESPONSES._FrequencyContractionScratch(
            1,
            3 * spatial_dimension^3;
            pair_block = count^2,
        ),
    )
    return workspace
end

const RESPONSE_TEST_SUPPORT_LOADED = true
