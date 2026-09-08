using Test
using WannierNLQG

const ZEEMAN_CORE = WannierNLQG.Core
const ZEEMAN_MATRIX_ELEMENTS = WannierNLQG.MatrixElements
const ZEEMAN_RESPONSES = WannierNLQG.Responses
const ZEEMAN_RUNTIME = WannierNLQG.Runtime

function synthetic_zeeman_data()
    plan = ZEEMAN_MATRIX_ELEMENTS.compile_matrix_plan(
        ZEEMAN_MATRIX_ELEMENTS.MatrixElementRequest(
            ZEEMAN_MATRIX_ELEMENTS.BERRY_CONNECTION,
            ZEEMAN_MATRIX_ELEMENTS.SPIN;
            spatial_dimension = 2,
        ),
    )
    data = ZEEMAN_MATRIX_ELEMENTS.KPointMatrixData(4, 0, plan)
    berry = data.berry_connection
    spin = data.spin.hamiltonian_gauge
    pair_values = (
        (1, 3, 0.7 + 0.2im, -0.4 + 0.3im),
        (2, 3, -0.1 + 0.5im, 0.6 + 0.2im),
        (1, 4, 0.2 - 0.8im, 0.3 + 0.4im),
        (2, 4, -0.5 - 0.1im, -0.2 + 0.7im),
    )
    for (n, m, r_nm, sigma_mn) in pair_values
        berry[n, m, 1] = r_nm
        berry[m, n, 1] = conj(r_nm)
        spin[m, n, 3] = sigma_mn
        spin[n, m, 3] = conj(sigma_mn)
    end
    return data
end

@testset "Zeeman interband response formulas" begin
    data = synthetic_zeeman_data()
    band_selection = (Int[3, 4], Int[1, 2])
    tensor_indices = Int[1, 3]
    components = ZEEMAN_RESPONSES.zeeman_interband_quantum_geometry_components(
        data,
        band_selection,
        tensor_indices,
    )

    A_total = 0.0 + 0.0im
    Q_total = 0.0 + 0.0im
    Z_total = 0.0 + 0.0im
    for m in band_selection[1], n in band_selection[2]
        A_nm = data.berry_connection[n, m, 1] * data.spin.hamiltonian_gauge[m, n, 3]
        B_nm = data.berry_connection[m, n, 1] * data.spin.hamiltonian_gauge[n, m, 3]
        A_total += A_nm
        Q_total += 0.5 * (A_nm + B_nm)
        Z_total += 1.0im * (A_nm - B_nm)
    end
    pair_count = length(band_selection[1]) * length(band_selection[2])
    A_average = A_total / pair_count
    @test components.quantum_metric == ComplexF64(real(Q_total) / pair_count, 0.0)
    @test components.berry_curvature == ComplexF64(real(Z_total) / pair_count, 0.0)
    @test components.quantum_metric - 0.5im * components.berry_curvature ≈ A_average
    @test ZEEMAN_RESPONSES.zeeman_interband_quantum_metric_component(
        data,
        band_selection,
        tensor_indices,
    ) == components.quantum_metric
    @test ZEEMAN_RESPONSES.zeeman_interband_berry_curvature_component(
        data,
        band_selection,
        tensor_indices,
    ) == components.berry_curvature

    singleton = (Int[3], Int[1])
    singleton_components = ZEEMAN_RESPONSES.zeeman_interband_quantum_geometry_components(
        data,
        singleton,
        tensor_indices,
    )
    A_nm = data.berry_connection[1, 3, 1] * data.spin.hamiltonian_gauge[3, 1, 3]
    @test singleton_components.quantum_metric - 0.5im * singleton_components.berry_curvature ≈ A_nm
end

@testset "Zeeman interband runtime contract" begin
    @test ZEEMAN_RUNTIME.normalize_quantity("ZIBCK") == :zeeman_interband_berry_curvature
    @test ZEEMAN_RUNTIME.normalize_quantity("ZIQMK") == :zeeman_interband_quantum_metric
    @test ZEEMAN_RUNTIME.normalize_quantity("Zeeman_Interband_Berry_Curvature") ==
          :zeeman_interband_berry_curvature
    @test ZEEMAN_RUNTIME.result_filename(
        "X",
        :zeeman_interband_berry_curvature,
        :conventional,
        :kslice,
    ) == "X_zibck_conv.dat"
    @test ZEEMAN_RUNTIME.result_filename(
        "X",
        :zeeman_interband_quantum_metric,
        :conventional,
        :kslice,
    ) == "X_ziqmk_conv.dat"

    cfg = WannierNLQG.Runtime.EffectiveTaskConfig(
        fourier_backend = "direct",
        tasks = [("ZIBCK", "K-slice"), ("ZIQMK", "K-slice")],
        tensor_indices = (1, 3),
        band_selection = ([3, 4], [1, 2]),
        spin_enabled = true,
        spin_file = "synthetic.spn",
        checkpoint_file = "synthetic.chk",
    )
    specs = ZEEMAN_RUNTIME.validate_config(cfg)
    @test [spec.task for spec in specs] == [:zeeman_interband_berry_curvature_kslice, :zeeman_interband_quantum_metric_kslice]
    @test ZEEMAN_RUNTIME.tensor_axis_limits(first(specs), 2) == [2, 3]

    @test_throws ErrorException ZEEMAN_RUNTIME.validate_config(
        WannierNLQG.Runtime.EffectiveTaskConfig(
            fourier_backend = "direct",
            tasks = [("ZIBCK", "K-slice")],
            tensor_indices = (1, 3),
            band_selection = (3, 1),
        ),
    )
    @test_throws ErrorException ZEEMAN_RUNTIME.validate_config(
        WannierNLQG.Runtime.EffectiveTaskConfig(
            fourier_backend = "direct",
            tasks = [("ZIQMK", "Integral")],
            tensor_indices = (1, 3),
            spin_enabled = true,
            spin_file = "synthetic.spn",
            checkpoint_file = "synthetic.chk",
        ),
    )
    @test_throws ErrorException ZEEMAN_RUNTIME.validate_config(
        WannierNLQG.Runtime.EffectiveTaskConfig(
            fourier_backend = "direct",
            tasks = [("ZIBCK", "K-slice")],
            tensor_indices = (1, 4),
            spin_enabled = true,
            spin_file = "synthetic.spn",
            checkpoint_file = "synthetic.chk",
        ),
    )

    @test ZEEMAN_CORE.validate_interband_band_selection(([3, 4], [1, 2]), 4) ==
          (Int[3, 4], Int[1, 2])
    @test_throws ErrorException ZEEMAN_CORE.validate_interband_band_selection(([2, 3], [1, 2]), 4)
    @test_throws ErrorException ZEEMAN_CORE.validate_interband_band_selection(([3, 3], [1, 2]), 4)
    @test_throws ErrorException ZEEMAN_CORE.validate_interband_band_selection((Int[], [1, 2]), 4)
    @test_throws ErrorException ZEEMAN_CORE.validate_interband_band_selection(([3, 5], [1, 2]), 4)
end
