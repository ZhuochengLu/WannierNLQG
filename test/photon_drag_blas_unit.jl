using Test
using Random
using LinearAlgebra
using WannierNLQG

const PDIC_BLAS_RESPONSES = WannierNLQG.Responses
const PDIC_BLAS_MATRIX_ELEMENTS = WannierNLQG.MatrixElements

function pdic_nonfinite_signature(values)
    components = reinterpret(Float64, vec(values))
    return (
        nan = count(isnan, components),
        positive_inf = count(==(Inf), components),
        negative_inf = count(==(-Inf), components),
    )
end

function pdic_l2_relative(candidate, reference)
    reference_norm = norm(reference)
    return reference_norm == 0.0 ? norm(candidate - reference) :
           norm(candidate - reference) / reference_norm
end

function make_pdic_blas_data(num_orbitals::Int, spatial_dimension::Int, seed::Integer)
    plan = PDIC_BLAS_MATRIX_ELEMENTS.compile_matrix_plan(
        PDIC_BLAS_MATRIX_ELEMENTS.MatrixElementRequest(
            PDIC_BLAS_MATRIX_ELEMENTS.SPECTRUM,
            PDIC_BLAS_MATRIX_ELEMENTS.HAMILTONIAN_DERIVATIVES,
            PDIC_BLAS_MATRIX_ELEMENTS.VELOCITY_VERTICES;
            spatial_dimension = spatial_dimension,
        ),
    )
    valence_data = PDIC_BLAS_MATRIX_ELEMENTS.KPointMatrixData(num_orbitals, 1, plan)
    conduction_data = PDIC_BLAS_MATRIX_ELEMENTS.KPointMatrixData(num_orbitals, 1, plan)
    rng = MersenneTwister(seed)
    for data in (valence_data, conduction_data)
        eigenvectors = Matrix(qr(randn(rng, ComplexF64, num_orbitals, num_orbitals)).Q)
        data.spectrum.source_eigenvectors .= eigenvectors
        data.spectrum.source_eigenvectors_adjoint .= adjoint(eigenvectors)
        data.source_gauge_hamiltonian_derivatives .=
            randn(rng, ComplexF64, num_orbitals, num_orbitals, spatial_dimension)
        data.source_gauge_velocity_vertices .=
            randn(rng, ComplexF64, num_orbitals, num_orbitals, spatial_dimension)
    end
    centers = randn(rng, 3, num_orbitals)
    return valence_data, conduction_data, centers
end

function run_pdic_matrix_kernel!(
    response_kernel,
    forward_vertex,
    backward_vertex,
    overlap_1,
    overlap_2,
    matrix_scratch_1,
    matrix_scratch_2,
    valence_data,
    conduction_data,
    valence_kpoint,
    conduction_kpoint,
    centers,
    basis_correction_enabled,
    active_pairs,
    active_pair_count,
    spatial_dimension,
    strategy,
)
    return PDIC_BLAS_RESPONSES.compute_photon_drag_injection_current_kernel!(
        response_kernel,
        forward_vertex,
        backward_vertex,
        overlap_1,
        overlap_2,
        valence_data,
        conduction_data,
        valence_kpoint,
        conduction_kpoint,
        centers,
        basis_correction_enabled,
        1,
        size(response_kernel, 1),
        1,
        size(response_kernel, 2),
        size(response_kernel, 1),
        spatial_dimension,
        active_pairs_nmajor = active_pairs,
        active_pair_count = active_pair_count,
        _matrix_scratch_1 = matrix_scratch_1,
        _matrix_scratch_2 = matrix_scratch_2,
        _pdic_matrix_strategy = strategy,
    )
end

@testset "PDIC overlap and velocity BLAS scalar oracle" begin
    for num_orbitals in (2, 8, 16)
        spatial_dimension = 2
        valence_data, conduction_data, centers =
            make_pdic_blas_data(num_orbitals, spatial_dimension, 0x7d10 + num_orbitals)
        valence_kpoint = Float64[-0.013, 0.021, -0.005]
        conduction_kpoint = Float64[0.017, -0.009, 0.011]
        dense_pairs = NTuple{2, Int}[(n, m) for n in 1:num_orbitals for m in 1:num_orbitals]
        sparse_count = max(1, fld(length(dense_pairs), 10))
        density_cases =
            (empty = NTuple{2, Int}[], sparse = dense_pairs[1:sparse_count], dense = dense_pairs)
        for basis_correction_enabled in (false, true)
            for (density, pairs) in pairs(density_cases)
                scalar_kernel = zeros(
                    ComplexF64,
                    num_orbitals,
                    num_orbitals,
                    spatial_dimension,
                    spatial_dimension,
                    spatial_dimension,
                )
                blas_kernel = similar(scalar_kernel)
                scalar_forward = zeros(ComplexF64, num_orbitals, num_orbitals, spatial_dimension)
                scalar_backward = similar(scalar_forward)
                blas_forward = similar(scalar_forward)
                blas_backward = similar(scalar_forward)
                scalar_overlap_1 = zeros(ComplexF64, num_orbitals, num_orbitals)
                scalar_overlap_2 = similar(scalar_overlap_1)
                blas_overlap_1 = similar(scalar_overlap_1)
                blas_overlap_2 = similar(scalar_overlap_1)
                matrix_scratch_1 = similar(scalar_overlap_1)
                matrix_scratch_2 = similar(scalar_overlap_1)
                run_pdic_matrix_kernel!(
                    scalar_kernel,
                    scalar_forward,
                    scalar_backward,
                    scalar_overlap_1,
                    scalar_overlap_2,
                    matrix_scratch_1,
                    matrix_scratch_2,
                    valence_data,
                    conduction_data,
                    valence_kpoint,
                    conduction_kpoint,
                    centers,
                    basis_correction_enabled,
                    pairs,
                    length(pairs),
                    spatial_dimension,
                    :scalar,
                )
                run_pdic_matrix_kernel!(
                    blas_kernel,
                    blas_forward,
                    blas_backward,
                    blas_overlap_1,
                    blas_overlap_2,
                    matrix_scratch_1,
                    matrix_scratch_2,
                    valence_data,
                    conduction_data,
                    valence_kpoint,
                    conduction_kpoint,
                    centers,
                    basis_correction_enabled,
                    pairs,
                    length(pairs),
                    spatial_dimension,
                    :blas,
                )
                @test isapprox(blas_overlap_1, scalar_overlap_1; atol = 1.0e-10, rtol = 1.0e-8)
                @test isapprox(blas_overlap_2, scalar_overlap_2; atol = 1.0e-10, rtol = 1.0e-8)
                @test isapprox(blas_kernel, scalar_kernel; atol = 1.0e-10, rtol = 1.0e-8)
                @test pdic_l2_relative(blas_overlap_1, scalar_overlap_1) <= 1.0e-9
                @test pdic_l2_relative(blas_overlap_2, scalar_overlap_2) <= 1.0e-9
                @test pdic_l2_relative(blas_kernel, scalar_kernel) <= 1.0e-9
                @test pdic_nonfinite_signature(blas_overlap_1) ==
                      pdic_nonfinite_signature(scalar_overlap_1)
                @test pdic_nonfinite_signature(blas_overlap_2) ==
                      pdic_nonfinite_signature(scalar_overlap_2)
                @test pdic_nonfinite_signature(blas_kernel) ==
                      pdic_nonfinite_signature(scalar_kernel)
                if density === :dense
                    @test isapprox(blas_forward, scalar_forward; atol = 1.0e-10, rtol = 1.0e-8)
                    @test isapprox(blas_backward, scalar_backward; atol = 1.0e-10, rtol = 1.0e-8)
                else
                    for (n, m) in pairs
                        @test isapprox(
                            blas_forward[n, m, :],
                            scalar_forward[n, m, :];
                            atol = 1.0e-10,
                            rtol = 1.0e-8,
                        )
                        @test isapprox(
                            blas_backward[m, n, :],
                            scalar_backward[m, n, :];
                            atol = 1.0e-10,
                            rtol = 1.0e-8,
                        )
                    end
                end
            end
        end
    end
end

@testset "PDIC basis correction q-to-zero continuity" begin
    num_orbitals = 8
    spatial_dimension = 2
    valence_data, conduction_data, centers =
        make_pdic_blas_data(num_orbitals, spatial_dimension, 0x7d40)
    zero_kpoint = zeros(Float64, 3)
    epsilon_kpoint = Float64[1.0e-10, -2.0e-10, 0.5e-10]
    zero_overlap_1 = zeros(ComplexF64, num_orbitals, num_orbitals)
    zero_overlap_2 = similar(zero_overlap_1)
    corrected_zero_overlap_1 = similar(zero_overlap_1)
    corrected_zero_overlap_2 = similar(zero_overlap_1)
    epsilon_overlap_1 = similar(zero_overlap_1)
    epsilon_overlap_2 = similar(zero_overlap_1)
    scratch_1 = similar(zero_overlap_1)
    scratch_2 = similar(zero_overlap_1)
    PDIC_BLAS_RESPONSES._photon_drag_compute_overlaps_blas!(
        zero_overlap_1,
        zero_overlap_2,
        scratch_1,
        scratch_2,
        valence_data,
        conduction_data,
        zero_kpoint,
        zero_kpoint,
        centers,
        false,
        num_orbitals,
    )
    PDIC_BLAS_RESPONSES._photon_drag_compute_overlaps_blas!(
        corrected_zero_overlap_1,
        corrected_zero_overlap_2,
        scratch_1,
        scratch_2,
        valence_data,
        conduction_data,
        zero_kpoint,
        zero_kpoint,
        centers,
        true,
        num_orbitals,
    )
    PDIC_BLAS_RESPONSES._photon_drag_compute_overlaps_blas!(
        epsilon_overlap_1,
        epsilon_overlap_2,
        scratch_1,
        scratch_2,
        valence_data,
        conduction_data,
        zero_kpoint,
        epsilon_kpoint,
        centers,
        true,
        num_orbitals,
    )
    @test isapprox(corrected_zero_overlap_1, zero_overlap_1; atol = 1.0e-13, rtol = 1.0e-13)
    @test isapprox(corrected_zero_overlap_2, zero_overlap_2; atol = 1.0e-13, rtol = 1.0e-13)
    @test norm(epsilon_overlap_1 - corrected_zero_overlap_1) <= 1.0e-7
    @test norm(epsilon_overlap_2 - corrected_zero_overlap_2) <= 1.0e-7
end

@testset "PDIC BLAS strategy selection" begin
    @test PDIC_BLAS_RESPONSES._select_photon_drag_injection_current_matrix_strategy(
        :auto,
        128,
        false,
        true,
        nothing,
        nothing,
        zeros(ComplexF64, 1, 1),
        zeros(ComplexF64, 1, 1),
    ) === :blas
    @test PDIC_BLAS_RESPONSES._select_photon_drag_injection_current_matrix_strategy(
        :auto,
        32,
        false,
        true,
        nothing,
        nothing,
        zeros(ComplexF64, 1, 1),
        zeros(ComplexF64, 1, 1),
    ) === :scalar
    @test PDIC_BLAS_RESPONSES._select_photon_drag_injection_current_matrix_strategy(
        :auto,
        16,
        true,
        true,
        nothing,
        nothing,
        zeros(ComplexF64, 1, 1),
        zeros(ComplexF64, 1, 1),
    ) === :blas
    @test PDIC_BLAS_RESPONSES._select_photon_drag_injection_current_matrix_strategy(
        :auto,
        128,
        true,
        false,
        NTuple{2, Int}[(1, 1)],
        nothing,
        zeros(ComplexF64, 1, 1),
        zeros(ComplexF64, 1, 1),
    ) === :scalar
    @test PDIC_BLAS_RESPONSES._select_photon_drag_injection_current_matrix_strategy(
        :auto,
        128,
        true,
        false,
        nothing,
        Int[1, 1, 1],
        zeros(ComplexF64, 1, 1),
        zeros(ComplexF64, 1, 1),
    ) === :scalar
    @test_throws ArgumentError PDIC_BLAS_RESPONSES._select_photon_drag_injection_current_matrix_strategy(
        :invalid,
        16,
        false,
        true,
        nothing,
        nothing,
        nothing,
        nothing,
    )
end
