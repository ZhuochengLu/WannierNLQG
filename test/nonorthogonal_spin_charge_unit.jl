module NonorthogonalSpinChargeUnit
using Test, LinearAlgebra, WannierNLQG
const C = WannierNLQG.Core
const M = WannierNLQG.MatrixElements
const R = WannierNLQG.Responses

"""Build the shared scalar jet in the explicitly requested native convention."""
function charge_data(model, k, convention; eta = 0.001)
    request = M.MatrixElementRequest(
        M.SPECTRUM,
        M.BERRY_CONNECTION,
        M.INTERNAL_CONNECTION_DERIVATIVES,
        M.HAMILTONIAN_SECOND_DERIVATIVES,
        M.VELOCITY_VERTICES,
        M.WANNIER_CURVATURE,
        M.OPTICAL_CUTOFF_VERTICES;
        spatial_dimension = 3,
        denominator_regularization = eta,
    )
    plan = M.compile_matrix_plan(
        request;
        source_gauge_required = false,
        wannier_center_convention = convention,
    )
    return M.compute_kpoint!(M.MatrixElementWorkspace(model, plan), model, k)
end

"""Charge brackets with actual occupations at one mu; common prefactors are omitted explicitly."""
function charge_brackets(data, photons, mu)
    n = length(data.spectrum.energies)
    energies = data.spectrum.energies
    occupations = C.fermi_dirac(energies, mu, 300.0)
    differences = [occupations[a] - occupations[b] for a in 1:n, b in 1:n]
    delta = C.gaussian_broadening(
        [frequency - (energies[b] - energies[a]) for frequency in photons, a in 1:n, b in 1:n],
        0.08,
    )
    kernel = zeros(ComplexF64, n, n, 3, 3, 3)
    derivative = zeros(ComplexF64, n, n, 3, 3)
    sc = zeros(ComplexF64, length(photons), 3, 3, 3)
    R.compute_conventional_shift_current_kernel!(kernel, derivative, data, 1, n, n, 3)
    R.accumulate_conventional_response!(sc, kernel, differences, delta, 1.0, 1, n, 3)
    ic = similar(sc);
    fill!(ic, 0)
    R.compute_injection_current_kernel!(kernel, data, 1, n, 3)
    R.accumulate_injection_current_response!(ic, kernel, differences, delta, 1.0, 1, n, 3)
    components = [(a, b, c) for a in 1:3 for b in 1:3 for c in 1:3]
    shg = zeros(ComplexF64, length(photons), length(components), 7, 2)
    R.second_harmonic_response!(
        shg,
        data,
        photons,
        components;
        fermi_energy = mu,
        temperature = 300.0,
        broadening = 0.08,
        low_frequency_broadening = 0.08,
        gaussian = true,
        intermediate_regularization = 0.04,
        eta_correction = false,
        degeneracy_threshold = 1e-4,
    )
    return (sc = sc, ic = ic, shg = shg, occupations = occupations)
end

@testset "All charge tensor components sum actual collinear blocks at one physical mu" begin
    base = Main.NonorthogonalLocalizedUnit.localized_chain()
    centers = [0.1 0.35; 0.0 0.0; 0.0 0.0]
    scalar(shift) = C.NonorthogonalLocalizedModel(
        lattice = base.lattice,
        r_vectors = base.r_vectors,
        hamiltonian_r = base.hamiltonian_r + shift * base.overlap_r,
        overlap_r = base.overlap_r,
        position_r = base.position_r,
        orbital_centers_cartesian = centers,
    )
    k = [0.219, 0.0, 0.0]
    models = (scalar(0.2), scalar(-0.3))
    for ordering in (:blocked, :interleaved), convention in (C.CONVENTION_I, C.CONVENTION_II)
        collinear = Main.NonorthogonalSpinConventionUnit.spin_chain(; ordering)
        data = charge_data(collinear, k, convention)
        mu = minimum(data.spectrum.energies) + 0.15
        photons = [0.73, data.spectrum.energies[end] - data.spectrum.energies[2]]
        actual = charge_brackets(data, photons, mu)
        blocks =
            [charge_brackets(charge_data(model, k, convention), photons, mu) for model in models]
        @test sort(actual.occupations) ≈ sort(vcat(blocks[1].occupations, blocks[2].occupations)) atol =
            2e-13
        @test maximum(actual.occupations) - minimum(actual.occupations) > 0.9
        for quantity in (:sc, :ic, :shg)
            combined = getproperty(blocks[1], quantity) + getproperty(blocks[2], quantity)
            @test getproperty(actual, quantity) ≈ combined atol = 2e-10 rtol = 2e-10
            @test norm(combined) > 1e-10
        end
        spinor = Main.NonorthogonalSpinConventionUnit.with_metadata(
            collinear;
            spin_representation = :spinor,
            magnetic_state = :collinear,
            spin_ordering = ordering,
            orbital_centers_cartesian = collinear.orbital_centers_cartesian,
        )
        spinor_actual = charge_brackets(charge_data(spinor, k, convention), photons, mu)
        for quantity in (:sc, :ic, :shg)
            @test getproperty(spinor_actual, quantity) ≈ getproperty(actual, quantity) atol = 2e-10 rtol =
                2e-10
        end
    end
end

@testset "Spin identity inherits metric/Berry slices and existing flat finite-model OM" begin
    base = Main.NonorthogonalLocalizedUnit.localized_dirac_plane(; moving = true)
    centers = [0.1 0.35; -0.2 0.05; 0.0 0.0]
    models = [
        C.NonorthogonalLocalizedModel(
            lattice = base.lattice,
            r_vectors = base.r_vectors,
            hamiltonian_r = base.hamiltonian_r + shift * base.overlap_r,
            overlap_r = base.overlap_r,
            position_r = base.position_r,
            orbital_centers_cartesian = centers,
        ) for shift in (0.2, -0.3)
    ]
    nr = base.num_r_vectors
    h = zeros(ComplexF64, 4, 4, nr);
    s = similar(h);
    fill!(s, 0)
    position = zeros(ComplexF64, 4, 4, 3, nr)
    for (index, states) in enumerate((1:2, 3:4))
        h[states, states, :] = models[index].hamiltonian_r
        s[states, states, :] = base.overlap_r
        position[states, states, :, :] = base.position_r
    end
    for representation in (:collinear, :spinor), convention in (C.CONVENTION_I, C.CONVENTION_II)
        model = C.NonorthogonalLocalizedModel(
            lattice = base.lattice,
            r_vectors = base.r_vectors,
            hamiltonian_r = h,
            overlap_r = s,
            position_r = position,
            spin_representation = representation,
            magnetic_state = :collinear,
            orbital_centers_cartesian = hcat(centers, centers),
        )
        data = charge_data(model, [0.19, 0.31, 0.0], convention)
        blocks = [charge_data(block, [0.19, 0.31, 0.0], convention) for block in models]
        for a in 1:3, b in 1:3
            metric = R.interband_quantum_metric_group_sum_component(data, [1, 2], [a, b], Int64(4))
            expected = sum(
                R.interband_quantum_metric_group_sum_component(block, [1], [a, b], Int64(2)) for
                block in blocks
            )
            @test metric ≈ expected atol = 2e-12 rtol = 2e-12
            berry = R.berry_curvature_group_sum_component(data, [1, 2], [a, b], Int64(4))
            expected = sum(
                R.berry_curvature_group_sum_component(block, [1], [a, b], Int64(2)) for
                block in blocks
            )
            @test berry ≈ expected atol = 2e-12 rtol = 2e-12
        end
        geometry = M.spectral_response_geometry(data)
        @test maximum(abs, geometry.curvature) < 1e-10
        actual = R.orbital_magnetization_response(
            geometry,
            M.finite_model_orbital_completion(4);
            fermi_energies = [0.4],
            temperature = 300.0,
        )
        expected = sum(
            R.orbital_magnetization_response(
                M.spectral_response_geometry(block),
                M.finite_model_orbital_completion(2);
                fermi_energies = [0.4],
                temperature = 300.0,
            ) for block in blocks
        )
        @test actual ≈ expected atol = 2e-10 rtol = 2e-10
        @test norm(expected) > 1e-10
    end
end
end
