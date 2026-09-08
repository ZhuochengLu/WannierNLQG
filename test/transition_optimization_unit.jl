using LinearAlgebra
using Random

@testset "in-place Fermi-Dirac occupations" begin
    core = WannierNLQG.Core
    energies = Float64[-100.0, -0.25, 0.0, 0.125, 0.5, 100.0]
    output = similar(energies)
    for temperature in (0.0, 300.0)
        expected = core.fermi_dirac(energies, 0.125, temperature)
        returned = core.fermi_dirac!(output, energies, 0.125, temperature)
        @test returned === output
        @test reinterpret(UInt64, output) == reinterpret(UInt64, expected)
    end
    @test_throws DimensionMismatch core.fermi_dirac!(zeros(2), energies, 0.0, 300.0)
end

@testset "real transition-screen prepare calls" begin
    core = WannierNLQG.Core
    matrix_elements = WannierNLQG.MatrixElements
    runtime = WannierNLQG.Runtime
    hamiltonian_r = zeros(ComplexF64, 2, 2, 1)
    hamiltonian_r[1, 1, 1] = -0.5
    hamiltonian_r[2, 2, 1] = 0.5
    model = core.TightBindingModel(
        Matrix{Float64}(I, 3, 3),
        2,
        1,
        Int[1],
        zeros(Int, 3, 1),
        hamiltonian_r,
        zeros(ComplexF64, 2, 2, 3, 1),
    )
    cfg = WannierNLQG.Runtime.EffectiveTaskConfig(
        fourier_backend = "direct",
        photon_energies = Float64[1.0],
        fermi_energy = 0.0,
        temperature = 0.0,
        broadening = 0.1,
        broadening_type = "Gaussian",
        transition_window_factor = 5.0,
        band_window_size = -1,
    )

    screen = runtime.make_transition_screen_workspace(2, 1, 1)
    matrix_elements.prepare_real_space!(screen.matrix_elements, model)
    runtime._prepare_transition_screen!(screen, zeros(3), cfg, model, 2)
    @test screen.data.spectrum.energies == Float64[-0.5, 0.5]
    @test screen.active
    @test screen.active_pair_mask[1, 2]
    @test !hasproperty(screen, :delta_arg)

    photon_drag = runtime.make_photon_drag_transition_screen_workspace(2, 1, 1)
    matrix_elements.prepare_real_space!(photon_drag.matrix_elements, model)
    runtime._prepare_photon_drag_transition_screen!(
        photon_drag,
        zeros(3),
        Float64[0.1, 0.0, 0.0],
        cfg,
        model,
        2,
    )
    @test photon_drag.valence_data.spectrum.energies == Float64[-0.5, 0.5]
    @test photon_drag.conduction_data.spectrum.energies == Float64[-0.5, 0.5]
    @test photon_drag.active
    @test photon_drag.active_pair_mask[1, 2]
    @test !hasproperty(photon_drag, :delta_arg)
end

@testset "fused exact q=0 transition screening" begin
    runtime = WannierNLQG.Runtime
    core = WannierNLQG.Core
    photon_energies = Float64[-0.25, 0.15, 1.2]
    broadening = 0.07
    transition_window_factor = 3.0
    for num_orbitals in (1, 2, 16), broadening_type in ("Gaussian", "Lorentzian")
        energies =
            num_orbitals == 1 ? Float64[-0.8] : collect(range(-0.8, 0.9; length = num_orbitals))
        screen = runtime.make_transition_screen_workspace(
            Int64(num_orbitals),
            Int64(1),
            Int64(length(photon_energies)),
        )
        screen.has_bands = true
        screen.band_start = num_orbitals == 16 ? 3 : 1
        screen.band_end = num_orbitals == 16 ? 14 : num_orbitals
        core.fermi_dirac!(screen.occupations, energies, 0.05, 300.0)

        expected_occupation_differences = zeros(Float64, num_orbitals, num_orbitals)
        expected_delta_arg = zeros(Float64, length(photon_energies), num_orbitals, num_orbitals)
        expected_delta = similar(expected_delta_arg)
        expected_mask = falses(num_orbitals, num_orbitals)
        cutoff = broadening * sqrt(200.0)
        @inbounds for n in 1:num_orbitals
            for m in 1:num_orbitals
                occupation_difference = screen.occupations[n] - screen.occupations[m]
                expected_occupation_differences[n, m] = occupation_difference
                transition_energy = energies[m] - energies[n]
                occupation_active = abs(occupation_difference) > 1.0e-10
                pair_active = occupation_active && broadening_type == "Lorentzian"
                for energy_index in eachindex(photon_energies)
                    delta_arg = transition_energy - photon_energies[energy_index]
                    expected_delta_arg[energy_index, n, m] = delta_arg
                    pair_active |=
                        occupation_active &&
                        broadening_type == "Gaussian" &&
                        abs(delta_arg) < cutoff
                end
                expected_mask[n, m] = pair_active
            end
        end
        runtime._smearing!(expected_delta, expected_delta_arg, broadening_type, broadening)
        transition_threshold = transition_window_factor * broadening
        expected_active = false
        @inbounds for n in screen.band_start:screen.band_end
            for m in screen.band_start:screen.band_end
                abs(expected_occupation_differences[n, m]) <= 1.0e-10 && continue
                for energy_index in eachindex(photon_energies)
                    if abs(expected_delta_arg[energy_index, n, m]) < transition_threshold
                        expected_active = true
                    end
                end
            end
        end

        runtime._fill_transition_screen!(
            screen,
            energies,
            photon_energies,
            broadening_type,
            broadening,
            transition_window_factor,
        )
        @test reinterpret(UInt64, screen.occupation_differences) ==
              reinterpret(UInt64, expected_occupation_differences)
        @test reinterpret(UInt64, screen.delta) == reinterpret(UInt64, expected_delta)
        @test screen.active_pair_mask == expected_mask
        @test screen.active == expected_active

        expected_nmajor = NTuple{2, Int}[]
        expected_mmajor = NTuple{2, Int}[]
        expected_derivative_pairs = NTuple{2, Int}[]
        expected_eligible_pair_count = 0
        @inbounds for n in screen.band_start:screen.band_end
            for m in screen.band_start:screen.band_end
                if abs(expected_occupation_differences[n, m]) > 1.0e-10
                    expected_eligible_pair_count += 1
                end
                expected_mask[n, m] && push!(expected_nmajor, (n, m))
                (expected_mask[n, m] || expected_mask[m, n]) &&
                    push!(expected_derivative_pairs, (n, m))
            end
        end
        @inbounds for m in screen.band_start:screen.band_end
            for n in screen.band_start:screen.band_end
                expected_mask[n, m] && push!(expected_mmajor, (n, m))
            end
        end
        @test screen.active_pairs_nmajor[1:screen.active_pairs_nmajor_length] == expected_nmajor
        @test screen.active_pairs_mmajor[1:screen.active_pairs_mmajor_length] == expected_mmajor
        @test screen.derivative_required_pairs_nmajor[1:screen.derivative_required_pairs_nmajor_length] ==
              expected_derivative_pairs
        @test screen.eligible_pair_count == expected_eligible_pair_count
        @test screen.use_active_pair_list ==
              (2 * length(expected_nmajor) < expected_eligible_pair_count)
        if broadening_type == "Lorentzian"
            @test length(expected_nmajor) == expected_eligible_pair_count
            @test !screen.use_active_pair_list
        end
    end

    broadening = 0.1
    cutoff = broadening * sqrt(200.0)
    boundary_energies = Float64[0.0, prevfloat(cutoff), cutoff, nextfloat(cutoff)]
    boundary_screen = runtime.make_transition_screen_workspace(4, 1, 1)
    boundary_screen.has_bands = true
    boundary_screen.band_start = 1
    boundary_screen.band_end = 4
    boundary_screen.occupations .= Float64[1.0, 0.0, 0.0, 0.0]
    runtime._fill_transition_screen!(
        boundary_screen,
        boundary_energies,
        Float64[0.0],
        "Gaussian",
        broadening,
        5.0,
    )
    @test boundary_screen.active_pair_mask[1, 2]
    @test !boundary_screen.active_pair_mask[1, 3]
    @test !boundary_screen.active_pair_mask[1, 4]
    @test boundary_screen.delta[1, 1, 2] != 0.0
    @test boundary_screen.delta[1, 1, 3] == 0.0
    @test boundary_screen.delta[1, 1, 4] == 0.0

    threshold_screen = runtime.make_transition_screen_workspace(2, 1, 1)
    threshold_screen.has_bands = true
    threshold_screen.band_start = 1
    threshold_screen.band_end = 2
    threshold_screen.occupations .= Float64[1.0, 0.0]
    runtime._fill_transition_screen!(
        threshold_screen,
        Float64[0.0, 0.5],
        Float64[0.0],
        "Gaussian",
        0.1,
        5.0,
    )
    @test threshold_screen.active_pair_mask[1, 2]
    @test !threshold_screen.active
    runtime._fill_transition_screen!(
        threshold_screen,
        Float64[0.0, 0.5],
        Float64[0.0],
        "Gaussian",
        0.1,
        6.0,
    )
    @test threshold_screen.active

    runtime._fill_transition_screen!(
        threshold_screen,
        Float64[0.0, 0.5],
        Float64[100.0],
        "Gaussian",
        0.1,
        0.0,
    )
    @test threshold_screen.active
    @test !any(threshold_screen.active_pair_mask)

    threshold_screen.occupations .= Float64[1.0e-10, 0.0]
    runtime._fill_transition_screen!(
        threshold_screen,
        Float64[0.0, 0.5],
        Float64[0.5],
        "Lorentzian",
        0.1,
        0.0,
    )
    @test !threshold_screen.active
    @test !any(threshold_screen.active_pair_mask)
    threshold_screen.occupations[1] = nextfloat(1.0e-10)
    runtime._fill_transition_screen!(
        threshold_screen,
        Float64[0.0, 0.5],
        Float64[0.5],
        "Lorentzian",
        0.1,
        0.0,
    )
    @test threshold_screen.active
    @test threshold_screen.active_pair_mask[1, 2]
    threshold_screen.occupations .= Float64[1.0, 0.0]

    runtime._fill_transition_screen!(
        threshold_screen,
        Float64[0.0, 1.0e6],
        Float64[0.0],
        "Lorentzian",
        0.1,
        1.0,
    )
    @test threshold_screen.active_pair_mask[1, 2]
    @test threshold_screen.active_pair_mask[2, 1]
    @test threshold_screen.delta[1, 1, 2] != 0.0
    @test !threshold_screen.use_active_pair_list

    threshold_screen.has_bands = false
    threshold_screen.band_start = 1
    threshold_screen.band_end = 0
    runtime._fill_transition_screen!(
        threshold_screen,
        Float64[0.0, 0.5],
        Float64[0.0],
        "Gaussian",
        0.1,
        6.0,
    )
    @test !threshold_screen.active
    @test !any(threshold_screen.active_pair_mask)
    @test threshold_screen.active_pairs_nmajor_length == 0
    @test threshold_screen.eligible_pair_count == 0
end

@testset "fused exact Photon Drag transition screening" begin
    runtime = WannierNLQG.Runtime
    core = WannierNLQG.Core
    valence_energies = Float64[-0.8, -0.2, 0.3, 0.9]
    conduction_energies = Float64[-0.65, -0.05, 0.55, 1.1]
    photon_energies = Float64[0.2, 0.75]
    for broadening_type in ("Gaussian", "Lorentzian")
        screen = runtime.make_photon_drag_transition_screen_workspace(4, 1, 2)
        screen.has_bands = true
        screen.valence_band_start = 1
        screen.valence_band_end = 2
        screen.conduction_band_start = 3
        screen.conduction_band_end = 4
        core.fermi_dirac!(screen.valence_occupations, valence_energies, 0.0, 300.0)
        core.fermi_dirac!(screen.conduction_occupations, conduction_energies, 0.0, 300.0)

        expected_occupation_differences = zeros(Float64, 4, 4)
        expected_transition_energies = zeros(Float64, 4, 4)
        expected_delta_arg = zeros(Float64, 2, 4, 4)
        expected_delta = similar(expected_delta_arg)
        expected_mask = falses(4, 4)
        broadening = 0.08
        cutoff = broadening * sqrt(200.0)
        @inbounds for n in 1:4
            for m in 1:4
                occupation_difference =
                    screen.valence_occupations[n] - screen.conduction_occupations[m]
                expected_occupation_differences[n, m] = occupation_difference
                transition_energy = conduction_energies[m] - valence_energies[n]
                expected_transition_energies[n, m] = transition_energy
                occupation_active = abs(occupation_difference) > 1.0e-10
                pair_active = occupation_active && broadening_type == "Lorentzian"
                for energy_index in eachindex(photon_energies)
                    delta_arg = transition_energy - photon_energies[energy_index]
                    expected_delta_arg[energy_index, n, m] = delta_arg
                    pair_active |=
                        occupation_active &&
                        broadening_type == "Gaussian" &&
                        abs(delta_arg) < cutoff
                end
                expected_mask[n, m] = pair_active
            end
        end
        runtime._smearing!(expected_delta, expected_delta_arg, broadening_type, broadening)
        runtime._fill_photon_drag_transition_screen!(
            screen,
            valence_energies,
            conduction_energies,
            photon_energies,
            broadening_type,
            broadening,
            3.0,
        )

        @test reinterpret(UInt64, screen.occupation_differences) ==
              reinterpret(UInt64, expected_occupation_differences)
        @test reinterpret(UInt64, screen.transition_energies) ==
              reinterpret(UInt64, expected_transition_energies)
        @test reinterpret(UInt64, screen.delta) == reinterpret(UInt64, expected_delta)
        @test screen.active_pair_mask == expected_mask

        expected_nmajor = NTuple{2, Int}[]
        expected_mmajor = NTuple{2, Int}[]
        expected_eligible_pair_count = 0
        for n in screen.valence_band_start:screen.valence_band_end
            for m in screen.conduction_band_start:screen.conduction_band_end
                if abs(expected_occupation_differences[n, m]) > 1.0e-10
                    expected_eligible_pair_count += 1
                end
                expected_mask[n, m] && push!(expected_nmajor, (n, m))
            end
        end
        for m in screen.conduction_band_start:screen.conduction_band_end
            for n in screen.valence_band_start:screen.valence_band_end
                expected_mask[n, m] && push!(expected_mmajor, (n, m))
            end
        end
        @test screen.active_pairs_nmajor[1:screen.active_pairs_nmajor_length] == expected_nmajor
        @test screen.active_pairs_mmajor[1:screen.active_pairs_mmajor_length] == expected_mmajor
        @test screen.eligible_pair_count == expected_eligible_pair_count
        @test screen.use_active_pair_list ==
              (2 * length(expected_nmajor) < expected_eligible_pair_count)
        if broadening_type == "Lorentzian"
            @test length(expected_nmajor) == expected_eligible_pair_count
            @test !screen.use_active_pair_list
        end
    end
end

@testset "response component planning" begin
    yyy = WannierNLQG.Runtime.make_response_component_plan(Int[2, 2, 2])
    @test yyy.derivative_axes == [2]
    @test yyy.projector_axes == [2]
    @test isempty(yyy.projector_axis_pairs)

    xyz = WannierNLQG.Runtime.make_response_component_plan(Int[1, 2, 3])
    @test xyz.derivative_axes == [1]
    @test xyz.projector_axes == [1, 2, 3]
    @test xyz.projector_axis_pairs == [(1, 2), (1, 3)]

    xyy = WannierNLQG.Runtime.make_response_component_plan(Int[1, 2, 2])
    @test xyy.projector_axes == [1, 2]
    @test xyy.projector_axis_pairs == [(1, 2)]
end

@testset "exact active transition masks" begin
    runtime = WannierNLQG.Runtime
    screen = runtime.make_transition_screen_workspace(4, 1, 2)
    screen.has_bands = true
    screen.band_start = 2
    screen.band_end = 3
    fill!(screen.occupation_differences, 0.0)
    fill!(screen.delta, 0.0)
    screen.occupation_differences[2, 3] = 1.0
    screen.delta[2, 2, 3] = 0.25
    screen.occupation_differences[1, 4] = 1.0
    screen.delta[1, 1, 4] = 0.5
    runtime._update_active_transition_pairs!(screen)
    @test screen.active_pair_mask[2, 3]
    @test screen.active_pair_mask[1, 4]
    @test screen.active_bands == BitVector([false, true, true, false])
    @test screen.active_pairs_nmajor[1:screen.active_pairs_nmajor_length] == [(2, 3)]
    @test screen.active_pairs_mmajor[1:screen.active_pairs_mmajor_length] == [(2, 3)]
    @test screen.derivative_required_pairs_nmajor[1:screen.derivative_required_pairs_nmajor_length] ==
          [(2, 3), (3, 2)]
    @test screen.eligible_pair_count == 1
    @test !screen.use_active_pair_list

    fill!(screen.delta, 0.0)
    runtime._update_active_transition_pairs!(screen)
    @test !any(screen.active_pair_mask)
    @test !any(screen.active_bands)
    @test screen.active_pairs_nmajor_length == 0
    @test screen.active_pairs_mmajor_length == 0
    @test screen.derivative_required_pairs_nmajor_length == 0

    photon_drag = runtime.make_photon_drag_transition_screen_workspace(4, 1, 2)
    photon_drag.has_bands = true
    photon_drag.valence_band_start = 1
    photon_drag.valence_band_end = 2
    photon_drag.conduction_band_start = 3
    photon_drag.conduction_band_end = 4
    fill!(photon_drag.occupation_differences, 0.0)
    fill!(photon_drag.delta, 0.0)
    photon_drag.occupation_differences[2, 3] = 1.0
    photon_drag.delta[1, 2, 3] = 0.75
    runtime._update_active_transition_pairs!(photon_drag)
    @test photon_drag.active_pair_mask[2, 3]
    @test photon_drag.active_valence_bands == BitVector([false, true, false, false])
    @test photon_drag.active_conduction_bands == BitVector([false, false, true, false])
    @test photon_drag.active_pairs_nmajor[1:photon_drag.active_pairs_nmajor_length] == [(2, 3)]
    @test photon_drag.active_pairs_mmajor[1:photon_drag.active_pairs_mmajor_length] == [(2, 3)]
    @test photon_drag.eligible_pair_count == 1
    @test !photon_drag.use_active_pair_list

    ordered = runtime.make_transition_screen_workspace(4, 1, 1)
    ordered.has_bands = true
    ordered.band_start = 1
    ordered.band_end = 4
    fill!(ordered.occupation_differences, 0.0)
    fill!(ordered.delta, 0.0)
    for (n, m) in ((1, 4), (2, 3))
        ordered.occupation_differences[n, m] = 1.0
        ordered.delta[1, n, m] = 1.0
    end
    runtime._update_active_transition_pairs!(ordered)
    @test ordered.active_pairs_nmajor[1:ordered.active_pairs_nmajor_length] == [(1, 4), (2, 3)]
    @test ordered.active_pairs_mmajor[1:ordered.active_pairs_mmajor_length] == [(2, 3), (1, 4)]
    @test ordered.derivative_required_pairs_nmajor[1:ordered.derivative_required_pairs_nmajor_length] ==
          [(1, 4), (2, 3), (3, 2), (4, 1)]
end

@testset "low-rank projector traces" begin
    Random.seed!(20260715)
    responses = WannierNLQG.Responses
    count = 32
    eigenvectors = Matrix(qr(randn(ComplexF64, count, count)).Q)
    A = randn(ComplexF64, count, count)
    B = randn(ComplexF64, count, count)
    C = randn(ComplexF64, count, count)
    temporary_1 = zeros(ComplexF64, count, count)
    temporary_2 = similar(temporary_1)
    temporary_3 = similar(temporary_1)
    for group_size in (1, 2, 4)
        basis = @view eigenvectors[:, 1:group_size]
        projector = basis * basis'
        dense_three = responses.projector_trace_three!(temporary_1, projector, A, B)
        low_rank_three = responses.projector_trace_three_low_rank!(
            temporary_1,
            temporary_2,
            eigenvectors,
            1,
            group_size,
            A,
            B,
        )
        @test low_rank_three ≈ dense_three rtol = 1.0e-12 atol = 1.0e-12

        dense_four = responses.projector_trace_four!(temporary_1, temporary_2, projector, A, B, C)
        low_rank_four = responses.projector_trace_four_low_rank!(
            temporary_1,
            temporary_2,
            temporary_3,
            eigenvectors,
            1,
            group_size,
            A,
            B,
            C,
        )
        @test low_rank_four ≈ dense_four rtol = 1.0e-12 atol = 1.0e-12
    end
end
