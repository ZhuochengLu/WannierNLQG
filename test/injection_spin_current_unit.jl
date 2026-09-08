using Test
using WannierNLQG
using Random
using LinearAlgebra

const ISC_RUNTIME = WannierNLQG.Runtime
const ISC_RESPONSES = WannierNLQG.Responses
const ISC_MATRIX_ELEMENTS = WannierNLQG.MatrixElements
const ISC_IO = WannierNLQG.IO

injection_bitwise_equal(left, right) =
    reinterpret(UInt64, vec(left)) == reinterpret(UInt64, vec(right))

function accumulate_ic_compact_for_test!(output, kernel, occupations, delta, pairs, count, scratch)
    return ISC_RESPONSES.accumulate_injection_current_response!(
        output,
        kernel,
        occupations,
        delta,
        0.37,
        1,
        3,
        2,
        active_pairs_nmajor = pairs,
        active_pair_count = count,
        frequency_weight_scratch = scratch,
    )
end

function accumulate_isc_compact_for_test!(output, kernel, occupations, delta, pairs, count, scratch)
    return ISC_RESPONSES.accumulate_injection_spin_current_response!(
        output,
        kernel,
        occupations,
        delta,
        0.61,
        1,
        3,
        2,
        active_pairs_nmajor = pairs,
        active_pair_count = count,
        frequency_weight_scratch = scratch,
    )
end

function accumulate_pdic_compact_for_test!(
    output,
    kernel,
    occupations,
    delta,
    denominator_weights,
    pairs,
    count,
    scratch,
)
    return ISC_RESPONSES.accumulate_photon_drag_injection_current_response!(
        output,
        kernel,
        occupations,
        delta,
        denominator_weights,
        0.23,
        1,
        3,
        1,
        3,
        2,
        active_pairs_nmajor = pairs,
        active_pair_count = count,
        frequency_weight_scratch = scratch,
    )
end

function captured_error(f)
    try
        f()
    catch err
        return sprint(showerror, err)
    end
    return ""
end

@testset "Injection Spin Current public contract" begin
    cfg = WannierNLQG.Runtime.EffectiveTaskConfig(
        fourier_backend = "direct",
        tasks = [("ISCK", "Conventional", "K-slice")],
        k_mesh = (2, 2),
        photon_energies = [0.1],
        spatial_dimension = 2,
        tensor_indices = (1, 3, 2, 1),
        seedname = "wannier90",
    )
    specs = ISC_RUNTIME.validate_config(cfg)
    @test only(specs).quantity == :injection_spin_current
    @test only(specs).task == :injection_spin_current_kslice
    @test ISC_RUNTIME.result_filename("X", :injection_spin_current, :conventional, :integral) ==
          "X_isc_conv.dat"
    @test ISC_RUNTIME.result_filename(
        "X",
        :injection_spin_current,
        :conventional,
        :kslice;
        part = :r,
    ) == "X_isck_r_conv.dat"
    @test_throws Exception ISC_RUNTIME.normalize_quantity("SIC")
    @test_throws Exception ISC_RUNTIME.normalize_quantity("SIC_con")

    @test_throws Exception ISC_RUNTIME.validate_config(
        WannierNLQG.Runtime.EffectiveTaskConfig(
            fourier_backend = "direct",
            tasks = [("ISC", "Projector", "Integral")],
            photon_energies = [0.1],
            spatial_dimension = 2,
            tensor_indices = (1, 1, 1, 1),
            seedname = "wannier90",
        ),
    )
    @test_throws Exception ISC_RUNTIME.validate_config(
        WannierNLQG.Runtime.EffectiveTaskConfig(
            fourier_backend = "direct",
            tasks = [("ISCK", "Conventional", "K-slice")],
            k_mesh = (2, 2),
            photon_energies = [0.1, 0.2],
            spatial_dimension = 2,
            tensor_indices = (1, 1, 1, 1),
            seedname = "wannier90",
        ),
    )
    @test_throws Exception ISC_RUNTIME.validate_config(
        WannierNLQG.Runtime.EffectiveTaskConfig(
            fourier_backend = "direct",
            tasks = [("ISC", "Conventional", "Integral")],
            photon_energies = Float64[],
            spatial_dimension = 2,
            tensor_indices = (1, 1, 1, 1),
            seedname = "wannier90",
        ),
    )

    bad_axis_cfg = WannierNLQG.Runtime.EffectiveTaskConfig(
        fourier_backend = "direct",
        tasks = [("ISCK", "Conventional", "K-slice")],
        k_mesh = (2, 2),
        photon_energies = [0.1],
        spatial_dimension = 2,
        tensor_indices = (3, 1, 1, 1),
        seedname = "wannier90",
    )
    @test_throws Exception ISC_RUNTIME.validate_config(bad_axis_cfg)
end

@testset "Injection Spin Current identity-spin kernel" begin
    plan = ISC_MATRIX_ELEMENTS.compile_matrix_plan(
        ISC_MATRIX_ELEMENTS.MatrixElementRequest(
            ISC_MATRIX_ELEMENTS.SPECTRUM,
            ISC_MATRIX_ELEMENTS.HAMILTONIAN_DERIVATIVES,
            ISC_MATRIX_ELEMENTS.BERRY_CONNECTION,
            ISC_MATRIX_ELEMENTS.SPIN_VELOCITY;
            spatial_dimension = 2,
        ),
    )
    data = ISC_MATRIX_ELEMENTS.KPointMatrixData(2, 1, plan)
    data.hamiltonian_derivatives .= reshape(ComplexF64.(1:8) ./ 10, 2, 2, 2)
    data.berry_connection .= reshape(
        ComplexF64[0.0, -0.1 + 0.4im, 0.2 + 0.3im, 0.0, 0.0, 0.6 - 0.1im, -0.5 + 0.2im, 0.0],
        2,
        2,
        2,
    )
    for s in 1:3
        data.spin_velocity.hamiltonian_gauge[:, :, 1:2, s] .= data.hamiltonian_derivatives
    end

    ic_kernel = zeros(ComplexF64, 2, 2, 2, 2, 2)
    isc_kernel = zeros(ComplexF64, 2, 2, 2, 3, 2, 2)
    ISC_RESPONSES.compute_injection_current_kernel!(ic_kernel, data, 1, 2, 2)
    ISC_RESPONSES.compute_injection_spin_current_kernel!(isc_kernel, data, 1, 2, 2)
    for s in 1:3
        @test isc_kernel[:, :, :, s, :, :] == ic_kernel
    end

    occupation_differences = [0.0 1.0; -1.0 0.0]
    delta = reshape([0.0, 0.7, 0.4, 0.0], 1, 2, 2)
    ic = zeros(ComplexF64, 1, 2, 2, 2)
    isc = zeros(ComplexF64, 1, 2, 3, 2, 2)
    e = ISC_RUNTIME.ELEMENTARY_CHARGE_C
    ISC_RESPONSES.accumulate_injection_current_response!(
        ic,
        ic_kernel,
        occupation_differences,
        delta,
        -e,
        1,
        2,
        2,
    )
    ISC_RESPONSES.accumulate_injection_spin_current_response!(
        isc,
        isc_kernel,
        occupation_differences,
        delta,
        1.0,
        1,
        2,
        2,
    )
    for s in 1:3
        @test isapprox((-e) .* isc[:, :, s, :, :], ic; rtol = 2eps(), atol = 0.0)
    end
end

@testset "Injection compact-pair exact kernels" begin
    Random.seed!(20260717)
    plan = ISC_MATRIX_ELEMENTS.compile_matrix_plan(
        ISC_MATRIX_ELEMENTS.MatrixElementRequest(
            ISC_MATRIX_ELEMENTS.SPECTRUM,
            ISC_MATRIX_ELEMENTS.HAMILTONIAN_DERIVATIVES,
            ISC_MATRIX_ELEMENTS.BERRY_CONNECTION,
            ISC_MATRIX_ELEMENTS.SPIN_VELOCITY;
            spatial_dimension = 2,
        ),
    )
    data = ISC_MATRIX_ELEMENTS.KPointMatrixData(3, 1, plan)
    data.hamiltonian_derivatives .= randn(ComplexF64, 3, 3, 2)
    data.berry_connection .= randn(ComplexF64, 3, 3, 2)
    data.spin_velocity.hamiltonian_gauge .= randn(ComplexF64, 3, 3, 3, 3)

    pair_capacity = Vector{NTuple{2, Int}}(undef, 9)
    dense_pairs = NTuple{2, Int}[(n, m) for n in 1:3 for m in 1:3]
    sparse_pairs = NTuple{2, Int}[(1, 2), (2, 3), (3, 1)]
    for (mode, pairs) in
        ((:empty, NTuple{2, Int}[]), (:sparse, sparse_pairs), (:dense, dense_pairs))
        pair_count = length(pairs)
        pair_count > 0 && copyto!(pair_capacity, 1, pairs, 1, pair_count)
        active_pair_mask = falses(3, 3)
        for (n, m) in pairs
            active_pair_mask[n, m] = true
        end

        dense_ic = zeros(ComplexF64, 3, 3, 2, 2, 2)
        compact_ic = similar(dense_ic)
        ISC_RESPONSES.compute_injection_current_kernel!(
            dense_ic,
            data,
            1,
            3,
            2,
            active_pair_mask = active_pair_mask,
        )
        ISC_RESPONSES.compute_injection_current_kernel!(
            compact_ic,
            data,
            1,
            3,
            2,
            active_pairs_nmajor = pair_capacity,
            active_pair_count = pair_count,
        )
        @test injection_bitwise_equal(compact_ic, dense_ic)

        dense_isc = zeros(ComplexF64, 3, 3, 2, 3, 2, 2)
        compact_isc = similar(dense_isc)
        ISC_RESPONSES.compute_injection_spin_current_kernel!(
            dense_isc,
            data,
            1,
            3,
            2,
            active_pair_mask = active_pair_mask,
        )
        ISC_RESPONSES.compute_injection_spin_current_kernel!(
            compact_isc,
            data,
            1,
            3,
            2,
            active_pairs_nmajor = pair_capacity,
            active_pair_count = pair_count,
        )
        @test injection_bitwise_equal(compact_isc, dense_isc)

        tensor_ic_dense = zeros(ComplexF64, size(dense_ic))
        tensor_ic_compact = similar(tensor_ic_dense)
        fill!(tensor_ic_compact, 0)
        ISC_RESPONSES.compute_injection_current_kernel!(
            tensor_ic_dense,
            data,
            1,
            3,
            2,
            active_pair_mask = active_pair_mask,
            tensor_indices = Int[2, 1, 2],
        )
        ISC_RESPONSES.compute_injection_current_kernel!(
            tensor_ic_compact,
            data,
            1,
            3,
            2,
            active_pairs_nmajor = pair_capacity,
            active_pair_count = pair_count,
            tensor_indices = Int[2, 1, 2],
        )
        @test injection_bitwise_equal(tensor_ic_compact, tensor_ic_dense)

        tensor_isc_dense = zeros(ComplexF64, size(dense_isc))
        tensor_isc_compact = similar(tensor_isc_dense)
        fill!(tensor_isc_compact, 0)
        ISC_RESPONSES.compute_injection_spin_current_kernel!(
            tensor_isc_dense,
            data,
            1,
            3,
            2,
            active_pair_mask = active_pair_mask,
            tensor_indices = Int[2, 3, 1, 2],
        )
        ISC_RESPONSES.compute_injection_spin_current_kernel!(
            tensor_isc_compact,
            data,
            1,
            3,
            2,
            active_pairs_nmajor = pair_capacity,
            active_pair_count = pair_count,
            tensor_indices = Int[2, 3, 1, 2],
        )
        @test injection_bitwise_equal(tensor_isc_compact, tensor_isc_dense)

        delta_component = randn(3, 3)
        occupation_differences = randn(3, 3)
        dense_ic_component = ISC_RESPONSES.injection_current_component(
            dense_ic,
            occupation_differences,
            delta_component,
            0.37,
            Int[2, 1, 2],
            1,
            3,
        )
        compact_ic_component = ISC_RESPONSES.injection_current_component(
            compact_ic,
            occupation_differences,
            delta_component,
            0.37,
            Int[2, 1, 2],
            1,
            3,
            active_pairs_nmajor = pair_capacity,
            active_pair_count = pair_count,
        )
        @test reinterpret(UInt64, [compact_ic_component]) ==
              reinterpret(UInt64, [dense_ic_component])

        dense_isc_component = ISC_RESPONSES.injection_spin_current_component(
            dense_isc,
            occupation_differences,
            delta_component,
            0.61,
            Int[2, 3, 1, 2],
            1,
            3,
        )
        compact_isc_component = ISC_RESPONSES.injection_spin_current_component(
            compact_isc,
            occupation_differences,
            delta_component,
            0.61,
            Int[2, 3, 1, 2],
            1,
            3,
            active_pairs_nmajor = pair_capacity,
            active_pair_count = pair_count,
        )
        @test reinterpret(UInt64, [compact_isc_component]) ==
              reinterpret(UInt64, [dense_isc_component])
        @test mode in (:empty, :sparse, :dense)
    end
    @test_throws ArgumentError ISC_RESPONSES.compute_injection_current_kernel!(
        zeros(ComplexF64, 3, 3, 2, 2, 2),
        data,
        1,
        3,
        2,
        active_pairs_nmajor = pair_capacity,
        active_pair_count = 10,
    )
end

@testset "Injection compact-pair exact frequency layouts" begin
    Random.seed!(20260718)
    num_orbitals = 3
    spatial_dimension = 2
    pair_capacity = Vector{NTuple{2, Int}}(undef, num_orbitals^2)
    mode_pairs = (
        empty = NTuple{2, Int}[],
        sparse = NTuple{2, Int}[(1, 2), (2, 3), (3, 1)],
        dense = NTuple{2, Int}[(n, m) for n in 1:3 for m in 1:3],
    )
    ic_kernel = randn(ComplexF64, 3, 3, 2, 2, 2)
    isc_kernel = randn(ComplexF64, 3, 3, 2, 3, 2, 2)
    for frequency_count in (1, 200)
        for pairs in values(mode_pairs)
            pair_count = length(pairs)
            pair_count > 0 && copyto!(pair_capacity, 1, pairs, 1, pair_count)
            occupation_differences = zeros(Float64, 3, 3)
            delta = zeros(Float64, frequency_count, 3, 3)
            for (pair_index, (n, m)) in enumerate(pairs)
                occupation_differences[n, m] = (-1.0)^pair_index * (0.25 + pair_index)
                for energy_index in 1:frequency_count
                    delta[energy_index, n, m] =
                        (0.125 * pair_index + energy_index / (frequency_count + 3))
                end
            end
            scratch = zeros(Float64, frequency_count)

            dense_ic = randn(ComplexF64, frequency_count, 2, 2, 2)
            compact_ic = copy(dense_ic)
            ISC_RESPONSES.accumulate_injection_current_response!(
                dense_ic,
                ic_kernel,
                occupation_differences,
                delta,
                0.37,
                1,
                3,
                2,
            )
            ISC_RESPONSES.accumulate_injection_current_response!(
                compact_ic,
                ic_kernel,
                occupation_differences,
                delta,
                0.37,
                1,
                3,
                2,
                active_pairs_nmajor = pair_capacity,
                active_pair_count = pair_count,
                frequency_weight_scratch = scratch,
            )
            @test injection_bitwise_equal(compact_ic, dense_ic)

            dense_isc = randn(ComplexF64, frequency_count, 2, 3, 2, 2)
            compact_isc = copy(dense_isc)
            ISC_RESPONSES.accumulate_injection_spin_current_response!(
                dense_isc,
                isc_kernel,
                occupation_differences,
                delta,
                0.61,
                1,
                3,
                2,
            )
            ISC_RESPONSES.accumulate_injection_spin_current_response!(
                compact_isc,
                isc_kernel,
                occupation_differences,
                delta,
                0.61,
                1,
                3,
                2,
                active_pairs_nmajor = pair_capacity,
                active_pair_count = pair_count,
                frequency_weight_scratch = scratch,
            )
            @test injection_bitwise_equal(compact_isc, dense_isc)
        end
    end

    sparse_pairs = mode_pairs.sparse
    copyto!(pair_capacity, 1, sparse_pairs, 1, length(sparse_pairs))
    occupation_differences = randn(3, 3)
    delta = randn(200, 3, 3)
    scratch = zeros(200)
    ic_output = zeros(ComplexF64, 200, 2, 2, 2)
    isc_output = zeros(ComplexF64, 200, 2, 3, 2, 2)
    accumulate_ic_compact_for_test!(
        ic_output,
        ic_kernel,
        occupation_differences,
        delta,
        pair_capacity,
        length(sparse_pairs),
        scratch,
    )
    accumulate_isc_compact_for_test!(
        isc_output,
        isc_kernel,
        occupation_differences,
        delta,
        pair_capacity,
        length(sparse_pairs),
        scratch,
    )
    @test_throws ArgumentError ISC_RESPONSES.accumulate_injection_current_response!(
        ic_output,
        ic_kernel,
        occupation_differences,
        delta,
        0.37,
        1,
        3,
        2,
        active_pairs_nmajor = pair_capacity,
        active_pair_count = length(sparse_pairs),
        frequency_weight_scratch = zeros(199),
    )
end

@testset "Photon Drag injection compact-pair exact paths" begin
    Random.seed!(20260719)
    plan = ISC_MATRIX_ELEMENTS.compile_matrix_plan(
        ISC_MATRIX_ELEMENTS.MatrixElementRequest(
            ISC_MATRIX_ELEMENTS.SPECTRUM,
            ISC_MATRIX_ELEMENTS.HAMILTONIAN_DERIVATIVES,
            ISC_MATRIX_ELEMENTS.VELOCITY_VERTICES;
            spatial_dimension = 2,
        ),
    )
    valence_data = ISC_MATRIX_ELEMENTS.KPointMatrixData(3, 1, plan)
    conduction_data = ISC_MATRIX_ELEMENTS.KPointMatrixData(3, 1, plan)
    identity_matrix = Matrix{ComplexF64}(I, 3, 3)
    for data in (valence_data, conduction_data)
        data.spectrum.source_eigenvectors .= identity_matrix
        data.spectrum.source_eigenvectors_adjoint .= identity_matrix
        data.source_gauge_hamiltonian_derivatives .= randn(ComplexF64, 3, 3, 2)
        data.source_gauge_velocity_vertices .= randn(ComplexF64, 3, 3, 2)
    end
    valence_kpoint = Float64[-0.01, 0.0, 0.0]
    conduction_kpoint = Float64[0.01, 0.0, 0.0]
    wannier_centers = zeros(Float64, 3, 3)
    pair_capacity = Vector{NTuple{2, Int}}(undef, 9)
    mode_pairs = (
        empty = NTuple{2, Int}[],
        sparse = NTuple{2, Int}[(1, 2), (2, 3), (3, 1)],
        dense = NTuple{2, Int}[(n, m) for n in 1:3 for m in 1:3],
    )
    for pairs in values(mode_pairs)
        pair_count = length(pairs)
        pair_count > 0 && copyto!(pair_capacity, 1, pairs, 1, pair_count)
        active_pair_mask = falses(3, 3)
        for (n, m) in pairs
            active_pair_mask[n, m] = true
        end

        dense_kernel = zeros(ComplexF64, 3, 3, 2, 2, 2)
        dense_forward = zeros(ComplexF64, 3, 3, 2)
        dense_backward = zeros(ComplexF64, 3, 3, 2)
        dense_overlap_1 = zeros(ComplexF64, 3, 3)
        dense_overlap_2 = similar(dense_overlap_1)
        compact_kernel = similar(dense_kernel)
        compact_forward = similar(dense_forward)
        compact_backward = similar(dense_backward)
        compact_overlap_1 = similar(dense_overlap_1)
        compact_overlap_2 = similar(dense_overlap_2)
        ISC_RESPONSES.compute_photon_drag_injection_current_kernel!(
            dense_kernel,
            dense_forward,
            dense_backward,
            dense_overlap_1,
            dense_overlap_2,
            valence_data,
            conduction_data,
            valence_kpoint,
            conduction_kpoint,
            wannier_centers,
            false,
            1,
            3,
            1,
            3,
            3,
            2,
            active_pair_mask = active_pair_mask,
        )
        ISC_RESPONSES.compute_photon_drag_injection_current_kernel!(
            compact_kernel,
            compact_forward,
            compact_backward,
            compact_overlap_1,
            compact_overlap_2,
            valence_data,
            conduction_data,
            valence_kpoint,
            conduction_kpoint,
            wannier_centers,
            false,
            1,
            3,
            1,
            3,
            3,
            2,
            active_pairs_nmajor = pair_capacity,
            active_pair_count = pair_count,
        )
        @test injection_bitwise_equal(compact_kernel, dense_kernel)
        @test injection_bitwise_equal(compact_forward, dense_forward)
        @test injection_bitwise_equal(compact_backward, dense_backward)
        @test injection_bitwise_equal(compact_overlap_1, dense_overlap_1)
        @test injection_bitwise_equal(compact_overlap_2, dense_overlap_2)

        tensor_dense_kernel = zeros(ComplexF64, 3, 3, 2, 2, 2)
        tensor_dense_forward = zeros(ComplexF64, 3, 3, 2)
        tensor_dense_backward = zeros(ComplexF64, 3, 3, 2)
        tensor_compact_kernel = similar(tensor_dense_kernel)
        tensor_compact_forward = similar(tensor_dense_forward)
        tensor_compact_backward = similar(tensor_dense_backward)
        fill!(tensor_compact_kernel, 0)
        fill!(tensor_compact_forward, 0)
        fill!(tensor_compact_backward, 0)
        ISC_RESPONSES.compute_photon_drag_injection_current_kernel!(
            tensor_dense_kernel,
            tensor_dense_forward,
            tensor_dense_backward,
            similar(dense_overlap_1),
            similar(dense_overlap_2),
            valence_data,
            conduction_data,
            valence_kpoint,
            conduction_kpoint,
            wannier_centers,
            false,
            1,
            3,
            1,
            3,
            3,
            2,
            active_pair_mask = active_pair_mask,
            tensor_indices = Int[2, 1, 2],
        )
        ISC_RESPONSES.compute_photon_drag_injection_current_kernel!(
            tensor_compact_kernel,
            tensor_compact_forward,
            tensor_compact_backward,
            similar(dense_overlap_1),
            similar(dense_overlap_2),
            valence_data,
            conduction_data,
            valence_kpoint,
            conduction_kpoint,
            wannier_centers,
            false,
            1,
            3,
            1,
            3,
            3,
            2,
            active_pairs_nmajor = pair_capacity,
            active_pair_count = pair_count,
            tensor_indices = Int[2, 1, 2],
        )
        @test injection_bitwise_equal(tensor_compact_kernel, tensor_dense_kernel)
        @test injection_bitwise_equal(tensor_compact_forward, tensor_dense_forward)
        @test injection_bitwise_equal(tensor_compact_backward, tensor_dense_backward)

        component_delta = randn(3, 3)
        component_occupations = randn(3, 3)
        dense_component = ISC_RESPONSES.photon_drag_injection_current_component(
            dense_kernel,
            component_occupations,
            component_delta,
            0.41,
            0.23,
            Int[2, 1, 2],
            1,
            3,
            1,
            3,
        )
        compact_component = ISC_RESPONSES.photon_drag_injection_current_component(
            compact_kernel,
            component_occupations,
            component_delta,
            0.41,
            0.23,
            Int[2, 1, 2],
            1,
            3,
            1,
            3,
            active_pairs_nmajor = pair_capacity,
            active_pair_count = pair_count,
        )
        @test reinterpret(UInt64, [compact_component]) == reinterpret(UInt64, [dense_component])

        for frequency_count in (1, 200)
            occupation_differences = zeros(Float64, 3, 3)
            delta = zeros(Float64, frequency_count, 3, 3)
            for (pair_index, (n, m)) in enumerate(pairs)
                occupation_differences[n, m] = (-1.0)^pair_index * (0.5 + pair_index)
                for energy_index in 1:frequency_count
                    delta[energy_index, n, m] =
                        0.0625 * pair_index + energy_index / (frequency_count + 5)
                end
            end
            denominator_weights =
                frequency_count == 1 ? Float64[0.2] :
                collect(range(0.2, 0.8; length = frequency_count))
            scratch = zeros(Float64, frequency_count)
            dense_output = randn(ComplexF64, frequency_count, 2, 2, 2)
            compact_output = copy(dense_output)
            ISC_RESPONSES.accumulate_photon_drag_injection_current_response!(
                dense_output,
                dense_kernel,
                occupation_differences,
                delta,
                denominator_weights,
                0.23,
                1,
                3,
                1,
                3,
                2,
            )
            ISC_RESPONSES.accumulate_photon_drag_injection_current_response!(
                compact_output,
                compact_kernel,
                occupation_differences,
                delta,
                denominator_weights,
                0.23,
                1,
                3,
                1,
                3,
                2,
                active_pairs_nmajor = pair_capacity,
                active_pair_count = pair_count,
                frequency_weight_scratch = scratch,
            )
            @test injection_bitwise_equal(compact_output, dense_output)
        end
    end

    sparse_pairs = mode_pairs.sparse
    copyto!(pair_capacity, 1, sparse_pairs, 1, length(sparse_pairs))
    occupation_differences = randn(3, 3)
    delta = randn(200, 3, 3)
    denominator_weights = rand(200)
    scratch = zeros(200)
    output = zeros(ComplexF64, 200, 2, 2, 2)
    kernel = randn(ComplexF64, 3, 3, 2, 2, 2)
    accumulate_pdic_compact_for_test!(
        output,
        kernel,
        occupation_differences,
        delta,
        denominator_weights,
        pair_capacity,
        length(sparse_pairs),
        scratch,
    )
end

@testset "Spin velocity supports two-dimensional execution" begin
    model = ISC_IO.read_wannier_tb(TEST_MODEL_FILE)
    count = model.num_orbitals
    r_count = model.num_r_vectors
    spin_r = zeros(ComplexF64, count, count, 3, r_count)
    source = ISC_MATRIX_ELEMENTS.SpinVelocityRealSpaceData(
        ISC_MATRIX_ELEMENTS.SpinRealSpaceData(spin_r; copy_data = false),
        zeros(ComplexF64, count, count, 3, r_count),
        zeros(ComplexF64, count, count, 3, 3, r_count),
        zeros(ComplexF64, count, count, 3, 3, r_count),
        ISC_MATRIX_ELEMENTS.SpinVelocityRealSpaceDiagnostics(0.0, 0.0, 0.0, 0.0),
    )
    plan = ISC_MATRIX_ELEMENTS.compile_matrix_plan(
        ISC_MATRIX_ELEMENTS.MatrixElementRequest(
            ISC_MATRIX_ELEMENTS.SPIN_VELOCITY;
            spatial_dimension = 2,
        ),
    )
    workspace = ISC_MATRIX_ELEMENTS.MatrixElementWorkspace(
        model,
        plan,
        ISC_MATRIX_ELEMENTS.MatrixElementSources(spin_velocity = source),
    )
    ISC_MATRIX_ELEMENTS.prepare_real_space!(workspace, model)
    ISC_MATRIX_ELEMENTS.compute_kpoint!(workspace, model, [0.0, 0.0, 0.0])
    @test all(isfinite, @view workspace.data.spin_velocity.hamiltonian_gauge[:, :, 1:2, :])
end

@testset "Injection Spin Current seed validation and rank-4 writer" begin
    mktempdir() do root
        seed = joinpath(root, "wannier90")
        cfg = WannierNLQG.Runtime.EffectiveTaskConfig(
            fourier_backend = "direct",
            tasks = [("ISC", "Conventional", "Integral")],
            k_mesh = (1, 1),
            photon_energies = [0.1],
            spatial_dimension = 2,
            tensor_indices = (1, 3, 1, 1),
            seedname = "wannier90",
            case_root = root,
            output_root = joinpath(root, "out"),
        )
        specs = ISC_RUNTIME.validate_config(cfg)
        message = captured_error(() -> ISC_RUNTIME.prepare_run_context(cfg, specs))
        for suffix in ("_tb.dat", ".spn", ".chk", ".eig", ".mmn")
            @test occursin(seed * suffix, message)
        end

        write(seed * "_tb.dat", "minimal test header\n1.0 0.0 0.0\n0.0 1.0 0.0\n0.0 0.0 1.0\n1\n")
        for suffix in (".spn", ".chk", ".eig", ".mmn")
            touch(seed * suffix)
        end
        ctx = ISC_RUNTIME.prepare_run_context(cfg, specs)
        @test ctx.model_file == seed * "_tb.dat"
        @test ctx.seed_inputs.overlap_file == seed * ".mmn"
        ISC_RUNTIME.write_metadata(cfg, ctx, String[])
        metadata = read(ctx.metadata_path, String)
        normalized_metadata = replace(metadata, r"\s+" => " ")
        @test occursin("bloch_phase_convention", metadata)
        @test occursin("R_only", metadata)
        @test occursin("spin_velocity_local_wannier_center_phase", metadata)
        @test occursin("disabled", metadata)
        @test occursin(
            "injection_spin_current.prefactor = +pi*e^2/(hbar^2*N_k*V)",
            normalized_metadata,
        )
        @test occursin(
            "injection_spin_current.identity_spin_relation = (-e)*ISC[S=I]=IC",
            normalized_metadata,
        )

        conflicting = WannierNLQG.Runtime.EffectiveTaskConfig(
            fourier_backend = "direct",
            tasks = cfg.tasks,
            k_mesh = cfg.k_mesh,
            photon_energies = cfg.photon_energies,
            spatial_dimension = cfg.spatial_dimension,
            tensor_indices = cfg.tensor_indices,
            seedname = cfg.seedname,
            case_root = root,
            model_file = "other_tb.dat",
        )
        @test occursin(
            "conflicting explicit model_file",
            captured_error(
                () -> ISC_RUNTIME.prepare_run_context(
                    conflicting,
                    ISC_RUNTIME.validate_config(conflicting),
                ),
            ),
        )

        tensor = reshape(ComplexF64.(1:48), 2, 2, 3, 2, 2)
        path = ISC_IO.write_response_tensor(0.0, [0.1, 0.2], tensor, 2, root, "rank4.dat")
        lines = readlines(path)
        @test length(split(lines[2])) == 3 + 24
        @test length(split(lines[3])) == 2 + 2 * 24
        @test split(lines[2])[4:7] == ["xxxx", "xxxy", "xxyx", "xxyy"]
    end
end
