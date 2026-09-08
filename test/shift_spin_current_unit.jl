using Test
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

@testset "Shift Spin Current public contract and aliases" begin
    @test SSC_RUNTIME.normalize_quantity("SSC") == :shift_spin_current
    @test SSC_RUNTIME.normalize_quantity("Shift_Spin_Current") == :shift_spin_current
    @test SSC_RUNTIME.normalize_quantity("ISC") == :injection_spin_current
    @test SSC_RUNTIME.normalize_quantity("Injection_Spin_Current") == :injection_spin_current
    @test_throws Exception SSC_RUNTIME.normalize_quantity("SIC")
    @test_throws Exception SSC_RUNTIME.normalize_quantity("SIC_con")

    cfg = WannierNLQG.Runtime.EffectiveTaskConfig(
        fourier_backend = "direct",
        tasks = [("SSCK", "Conventional", "K-slice")],
        k_mesh = (2, 2),
        photon_energies = [0.1],
        spatial_dimension = 2,
        tensor_indices = (1, 3, 2, 1),
        seedname = "wannier90",
    )
    spec = only(SSC_RUNTIME.validate_config(cfg))
    @test spec.quantity == :shift_spin_current
    @test spec.task == :shift_spin_current_kslice
    @test SSC_RUNTIME.result_filename("X", :shift_spin_current, :conventional, :integral) ==
          "X_ssc_conv.dat"
    @test SSC_RUNTIME.result_filename(
        "X",
        :shift_spin_current,
        :conventional,
        :kslice;
        part = :r,
    ) == "X_ssck_r_conv.dat"
    @test_throws Exception SSC_RUNTIME.validate_config(
        WannierNLQG.Runtime.EffectiveTaskConfig(
            fourier_backend = "direct",
            tasks = [
                ("SSC", "Conventional", "Integral"),
                ("Shift_Spin_Current", "Conventional", "Integral"),
            ],
            photon_energies = [0.1],
            spatial_dimension = 2,
            tensor_indices = (1, 1, 1, 1),
            seedname = "wannier90",
        ),
    )
    zero_energy_cfg = WannierNLQG.Runtime.EffectiveTaskConfig(
        fourier_backend = "direct",
        tasks = [("SSC", "Conventional", "Integral")],
        photon_energies = [0.0],
        denominator_regularization = 1.0e-3,
        spatial_dimension = 2,
        tensor_indices = (1, 1, 1, 1),
        seedname = "wannier90",
    )
    @test only(SSC_RUNTIME.validate_config(zero_energy_cfg)).task == :shift_spin_current_integral
    @test_throws Exception SSC_RUNTIME.validate_config(
        WannierNLQG.Runtime.EffectiveTaskConfig(
            fourier_backend = "direct",
            tasks = [("SSC", "Conventional", "Integral")],
            photon_energies = [0.0],
            denominator_regularization = 0.0,
            spatial_dimension = 2,
            tensor_indices = (1, 1, 1, 1),
            seedname = "wannier90",
        ),
    )

    mktempdir() do root
        seed = joinpath(root, "wannier90")
        write(seed * "_tb.dat", "minimal test header\n1.0 0.0 0.0\n0.0 1.0 0.0\n0.0 0.0 1.0\n1\n")
        for suffix in (".spn", ".chk", ".eig", ".mmn")
            touch(seed * suffix)
        end
        metadata_cfg = WannierNLQG.Runtime.EffectiveTaskConfig(
            fourier_backend = "direct",
            tasks = [("SSC", "Conventional", "Integral")],
            k_mesh = (1, 1),
            photon_energies = [0.1],
            denominator_regularization = 1.0e-3,
            spatial_dimension = 2,
            tensor_indices = (1, 1, 1, 1),
            seedname = "wannier90",
            case_root = root,
            output_root = joinpath(root, "out"),
        )
        metadata_specs = SSC_RUNTIME.validate_config(metadata_cfg)
        metadata_ctx = SSC_RUNTIME.prepare_run_context(metadata_cfg, metadata_specs)
        SSC_RUNTIME.write_metadata(metadata_cfg, metadata_ctx, String[])
        metadata = read(metadata_ctx.metadata_path, String)
        normalized_metadata = replace(metadata, r"\s+" => " ")
        @test occursin(
            "shift_spin_current.prefactor = +i*hbar_eVs*pi*e^2/(2*hbar_Js^2*N_k*V)",
            normalized_metadata,
        )
        @test occursin(
            "shift_spin_current.identity_spin_relation = (-e)*SSC[S=I](a,b,c)=SC(a,b,c) (nondegenerate resonant eta->0)",
            normalized_metadata,
        )
    end

    bundle_cfg = WannierNLQG.Runtime.EffectiveTaskConfig(
        fourier_backend = "direct",
        tasks = [
            ("SC", "Conventional", "Integral"),
            ("ISC", "Conventional", "Integral"),
            ("SSC", "Conventional", "Integral"),
        ],
        k_mesh = (2, 2, 2),
        spatial_dimension = 3,
        tensor_indices = (1, 1, 1, 1),
    )
    bundle_plan =
        SSC_RUNTIME.bundle_matrix_element_plan(SSC_RUNTIME.validate_config(bundle_cfg), bundle_cfg)
    @test count_ones(bundle_plan.requested_mask) == 6
    for kind in (
        SSC_MATRIX_ELEMENTS.SPIN_VELOCITY,
        SSC_MATRIX_ELEMENTS.INTERNAL_CONNECTION,
        SSC_MATRIX_ELEMENTS.INTERNAL_CONNECTION_DERIVATIVES,
        SSC_MATRIX_ELEMENTS.HAMILTONIAN_SECOND_DERIVATIVES,
    )
        @test SSC_MATRIX_ELEMENTS.has_capability(bundle_plan, kind)
    end
end

@testset "Shift Spin Current vertices and explicit Eq. (5)" begin
    workspace = make_synthetic_ssc_workspace()
    eta = 1.0e-3
    SSC_RESPONSES.compute_shift_spin_current_vertices!(workspace, eta, 2)
    data = workspace.data

    for a in 1:2, b in 1:2
        mass = workspace.effective_mass_vertex[:, :, a, b]
        @test maximum(abs, mass - mass') < 1.0e-12
        @test mass == workspace.effective_mass_vertex[:, :, b, a]
        @test mass == data.hamiltonian_second_derivatives[:, :, a, b]
        @test workspace.spin_two_photon_vertex[:, :, 1, a, b] ≈ mass atol = 1.0e-14
    end

    energies = data.spectrum.energies
    for a in 1:2, b in 1:2, m in 1:3, n in 1:3
        reference = data.hamiltonian_second_derivatives[m, n, a, b]
        for p in 1:3
            inverse_mp = (energies[m] - energies[p]) / ((energies[m] - energies[p])^2 + eta^2)
            inverse_np = (energies[n] - energies[p]) / ((energies[n] - energies[p])^2 + eta^2)
            reference +=
                data.spin_velocity.hamiltonian_gauge[m, p, a, 1] *
                workspace.velocity_vertex[p, n, b] *
                inverse_mp
            reference +=
                workspace.velocity_vertex[m, p, b] *
                data.spin_velocity.hamiltonian_gauge[p, n, a, 1] *
                inverse_np
        end
        @test workspace.generalized_spin_derivative[m, n, 1, b, a] ≈ reference atol = 1.0e-13
    end

    SSC_RESPONSES.compute_shift_spin_current_kernel!(workspace, 1, 3, 2)
    @test all(isfinite, workspace.response_kernel)
end

@testset "Shift Spin Current kernel is the negative optical-slot transpose" begin
    reference_workspace = make_synthetic_ssc_workspace()
    derivative = reference_workspace.generalized_spin_derivative
    velocity = reference_workspace.velocity_vertex
    for n in 1:3, m in 1:3, s in 1:3, b in 1:2, a in 1:2
        derivative[n, m, s, b, a] = ComplexF64(100n + 10m + 3s + 2b + a, 7n - 5m + 2s - b + a)
    end
    for n in 1:3, m in 1:3, c in 1:2
        velocity[n, m, c] = ComplexF64(11n - 4m + c, 3n + 2m - 5c)
    end
    old_kernel = similar(reference_workspace.response_kernel)
    for n in 1:3, m in 1:3, a in 1:2, s in 1:3, b in 1:2, c in 1:2
        old_kernel[n, m, a, s, b, c] =
            derivative[n, m, s, b, a] * velocity[m, n, c] -
            derivative[m, n, s, c, a] * velocity[n, m, b]
    end

    dense_full = deepcopy(reference_workspace)
    SSC_RESPONSES.compute_shift_spin_current_kernel!(dense_full, 1, 3, 2)
    for n in 1:3, m in 1:3, a in 1:2, s in 1:3, b in 1:2, c in 1:2
        @test dense_full.response_kernel[n, m, a, s, b, c] == -old_kernel[n, m, a, s, c, b]
    end

    selected = [2, 3, 1, 2]
    dense_component = deepcopy(reference_workspace)
    SSC_RESPONSES.compute_shift_spin_current_kernel!(
        dense_component,
        1,
        3,
        2;
        tensor_indices = selected,
    )
    for n in 1:3, m in 1:3
        @test dense_component.response_kernel[n, m, selected...] ==
              -old_kernel[n, m, selected[1], selected[2], selected[4], selected[3]]
    end

    active_pairs = [(1, 2), (3, 1)]
    active_full = deepcopy(reference_workspace)
    SSC_RESPONSES.compute_shift_spin_current_kernel!(
        active_full,
        1,
        3,
        2;
        active_pairs_nmajor = active_pairs,
        active_pair_count = length(active_pairs),
    )
    for (n, m) in active_pairs, a in 1:2, s in 1:3, b in 1:2, c in 1:2
        @test active_full.response_kernel[n, m, a, s, b, c] == -old_kernel[n, m, a, s, c, b]
    end

    active_component = deepcopy(reference_workspace)
    SSC_RESPONSES.compute_shift_spin_current_kernel!(
        active_component,
        1,
        3,
        2;
        active_pairs_nmajor = active_pairs,
        active_pair_count = length(active_pairs),
        tensor_indices = selected,
    )
    for (n, m) in active_pairs
        @test active_component.response_kernel[n, m, selected...] ==
              -old_kernel[n, m, selected[1], selected[2], selected[4], selected[3]]
    end
end

@testset "Shift Spin Current 3D component keeps off-diagonal Hermitian closure" begin
    workspace = make_synthetic_ssc_workspace(; spatial_dimension = 3)
    data = workspace.data
    data.internal_connection_derivatives[:, :, 1, 3] .=
        reshape(ComplexF64.(1:9) .+ 0.1im .* ComplexF64.(9:-1:1), 3, 3)
    data.internal_connection_derivatives[:, :, 3, 1] .=
        reshape(ComplexF64.(11:19) .- 0.2im .* ComplexF64.(1:9), 3, 3)
    data.hamiltonian_second_derivatives[:, :, 1, 3] .=
        reshape(ComplexF64.(21:29) .+ 0.3im .* ComplexF64.(1:9), 3, 3)
    data.hamiltonian_second_derivatives[:, :, 3, 1] .=
        reshape(ComplexF64.(31:39) .- 0.4im .* ComplexF64.(9:-1:1), 3, 3)

    full = deepcopy(workspace)
    component = deepcopy(workspace)
    SSC_RESPONSES.compute_shift_spin_current_vertices!(full, 1.0e-3, 3)
    SSC_RESPONSES.compute_shift_spin_current_vertices!(
        component,
        1.0e-3,
        3;
        tensor_indices = [3, 1, 1, 2],
    )

    @test component.effective_mass_vertex[:, :, 3, 1] == full.effective_mass_vertex[:, :, 3, 1]
    @test component.effective_mass_vertex[:, :, 1, 3] == full.effective_mass_vertex[:, :, 1, 3]
    @test component.generalized_spin_derivative[:, :, 1, 1, 3] ==
          full.generalized_spin_derivative[:, :, 1, 1, 3]
end

@testset "Shift Spin Current regularized interband energy weight" begin
    count = 3
    spatial_dimension = 2
    denominator_regularization = 0.2
    energy_differences = Float64[
        0.0 -0.9 0.4
        0.9 0.0 1.3
        -0.4 -1.3 0.0
    ]
    occupation_differences = Float64[
        1.0 -0.5 0.75
        0.25 1.0 -0.8
        -0.6 0.4 1.0
    ]
    delta = zeros(Float64, 1, count, count)
    response_kernel =
        zeros(ComplexF64, count, count, spatial_dimension, 3, spatial_dimension, spatial_dimension)
    for n in 1:count, m in 1:count
        delta[1, n, m] = 0.2 + 0.1n + 0.05m
        response_kernel[n, m, 1, 2, 2, 1] = ComplexF64(n - 2m, n + m)
    end
    prefactor = 0.25 + 0.5im
    integral_response =
        zeros(ComplexF64, 1, spatial_dimension, 3, spatial_dimension, spatial_dimension)
    SSC_RESPONSES.accumulate_shift_spin_current_response!(
        integral_response,
        response_kernel,
        occupation_differences,
        delta,
        energy_differences,
        denominator_regularization,
        prefactor,
        1,
        count,
        spatial_dimension,
    )

    expected = zero(ComplexF64)
    for n in 1:count, m in 1:count
        weight =
            occupation_differences[n, m] * delta[1, n, m] * energy_differences[n, m]^2 /
            (energy_differences[n, m]^2 + denominator_regularization^2)^2
        expected += prefactor * weight * response_kernel[n, m, 1, 2, 2, 1]
    end
    @test integral_response[1, 1, 2, 2, 1] ≈ expected atol = 1.0e-14 rtol = 1.0e-14
    @test SSC_RESPONSES.shift_spin_current_energy_weight(0.0, denominator_regularization) == 0.0
    @test SSC_RESPONSES.shift_spin_current_energy_weight(-0.9, denominator_regularization) ==
          SSC_RESPONSES.shift_spin_current_energy_weight(0.9, denominator_regularization)

    kslice_value = SSC_RESPONSES.shift_spin_current_component(
        response_kernel,
        occupation_differences,
        copy(dropdims(delta; dims = 1)),
        energy_differences,
        denominator_regularization,
        prefactor,
        [1, 2, 2, 1],
        1,
        count,
    )
    @test kslice_value ≈ expected atol = 1.0e-14 rtol = 1.0e-14
end

@testset "Shift Spin Current formal identity channel" begin
    workspace = make_synthetic_ssc_workspace()
    data = workspace.data
    energies = data.spectrum.energies
    eta = 1.0e-8
    data.hamiltonian.energy_differences .= energies .- transpose(energies)
    data.position.inverse_energy_differences .=
        data.hamiltonian.energy_differences ./ (data.hamiltonian.energy_differences .^ 2 .+ eta^2)
    for a in 1:2
        data.position.gauge_correction[:, :, a] .=
            -data.hamiltonian_derivatives[:, :, a] .* data.position.inverse_energy_differences
        data.position.berry_connection[:, :, a] .= 1.0im .* data.position.gauge_correction[:, :, a]
    end
    SSC_RESPONSES.compute_shift_spin_current_vertices!(workspace, eta, 2)
    SSC_RESPONSES.compute_shift_spin_current_kernel!(workspace, 1, 3, 2)
    charge_workspace = SSC_RESPONSES.ShiftCurrentConventionalWorkspace(
        nothing,
        data,
        zeros(ComplexF64, 3, 3, 2, 2),
        zeros(ComplexF64, 3, 3, 2, 2, 2),
        zeros(ComplexF64, 1, 2, 2, 2),
        zeros(Float64, 1),
    )
    SSC_RESPONSES.compute_conventional_shift_current_kernel!(
        charge_workspace.response_kernel,
        charge_workspace.generalized_position_derivative,
        data,
        1,
        3,
        3,
        2,
    )
    for n in 1:3, m in 1:3, a in 1:2, b in 1:2, c in 1:2
        transition_energy = energies[m] - energies[n]
        abs(transition_energy) > 1.0e-6 || continue
        @test workspace.response_kernel[n, m, a, 1, b, c] / transition_energy^2 ≈
              -1.0im * charge_workspace.response_kernel[n, m, a, b, c] atol = 1.0e-12
    end

    occupations = zeros(Float64, 3, 3)
    resonant_delta = zeros(Float64, 1, 3, 3)
    occupations[1, 2] = 1.0
    resonant_delta[1, 1, 2] = 1.0
    denominator_regularization = 0.2
    transition_energy = energies[2] - energies[1]
    charge_response = zeros(ComplexF64, 1, 2, 2, 2)
    spin_response = zeros(ComplexF64, 1, 2, 3, 2, 2)
    SSC_RESPONSES.accumulate_conventional_response!(
        charge_response,
        charge_workspace.response_kernel,
        occupations,
        resonant_delta,
        -0.5,
        1,
        3,
        2,
    )
    SSC_RESPONSES.accumulate_shift_spin_current_response!(
        spin_response,
        workspace.response_kernel,
        occupations,
        resonant_delta,
        data.energy_differences,
        denominator_regularization,
        0.5im,
        1,
        3,
        2,
    )
    for a in 1:2, b in 1:2, c in 1:2
        # The charged identity channel now compares the same ordered (a,b,c) component.
        identity_weight =
            transition_energy^4 / (transition_energy^2 + denominator_regularization^2)^2
        @test -spin_response[1, a, 1, b, c] ≈ identity_weight * charge_response[1, a, b, c] atol =
            1.0e-12
    end
end

@testset "Hamiltonian Hessian analytic Fourier and finite difference" begin
    hopping = 0.7
    model = WannierNLQG.Core.TightBindingModel(
        Matrix{Float64}(I, 3, 3),
        1,
        3,
        ones(Int, 3),
        [-1 0 1; 0 0 0; 0 0 0],
        reshape(ComplexF64[hopping, 0.0, hopping], 1, 1, 3),
        zeros(ComplexF64, 1, 1, 3, 3),
    )
    plan = SSC_MATRIX_ELEMENTS.compile_matrix_plan(
        SSC_MATRIX_ELEMENTS.MatrixElementRequest(
            SSC_MATRIX_ELEMENTS.HAMILTONIAN_SECOND_DERIVATIVES;
            spatial_dimension = 3,
        ),
    )
    workspace = SSC_MATRIX_ELEMENTS.MatrixElementWorkspace(model, plan)
    SSC_MATRIX_ELEMENTS.prepare_real_space!(workspace, model)
    k_cart = 0.37
    kpoint = [k_cart / (2pi), 0.0, 0.0]
    SSC_MATRIX_ELEMENTS.compute_kpoint!(workspace, model, kpoint)
    analytic_energy = 2hopping * cos(k_cart)
    analytic_hessian = -2hopping * cos(k_cart)
    @test workspace.data.spectrum.energies[1] ≈ analytic_energy atol = 1.0e-14
    @test workspace.data.hamiltonian_second_derivatives[1, 1, 1, 1] ≈ analytic_hessian atol =
        1.0e-14

    step = 1.0e-4
    energies = Float64[]
    for offset in (-step, 0.0, step)
        SSC_MATRIX_ELEMENTS.compute_kpoint!(workspace, model, [(k_cart + offset) / (2pi), 0.0, 0.0])
        push!(energies, workspace.data.spectrum.energies[1])
    end
    finite_difference = (energies[3] - 2energies[2] + energies[1]) / step^2
    @test finite_difference ≈ analytic_hessian rtol = 5.0e-8 atol = 5.0e-8
end
