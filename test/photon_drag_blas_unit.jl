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
        # This fixture has arbitrary synthetic frames, not a Wannier H/A input.
        # Retain the old scalar/BLAS arithmetic oracle as an explicit historical test.
        _historical_center_overlap_reference = true,
        _pdic_matrix_strategy = strategy,
        valence_velocity_vertices = valence_data.source_gauge_velocity_vertices,
        conduction_velocity_vertices = conduction_data.source_gauge_velocity_vertices,
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

@testset "Finite-q component plans retain complete endpoint velocity" begin
    E=WannierNLQG.MatrixElements
    R=WannierNLQG.Runtime
    response=WannierNLQG.Responses
    model_path=joinpath(dirname(@__DIR__), "examples/fixtures/synthetic_runtime/synthetic_tb.dat")
    model=WannierNLQG.IO.read_wannier_tb(model_path)
    centers=permutedims(R._runtime_wannier_centers_fractional(model))
    component=[2, 1, 3]
    n=model.num_orbitals
    @test size(centers)==(3, n)
    for (quantity, method) in (("PDICK", "Conventional"), ("PDSCK", "Geometric_Loop")),
        convention in ("Convention_I", "Convention_II")

        task=TaskSpec(
            id = "component_velocity",
            quantity = quantity,
            method = method,
            physics = FiniteQOpticalParameters(
                photon_energies = [0.73],
                fermi_energy = 0.0,
                temperature = 0.0,
                photon_momentum = (0.003, 0.001, 0.002),
            ),
            observable = KSliceSelection(
                component = TensorComponent(component...),
                bands = BandSelection(),
            ),
        )
        input=TaskConfig(
            model = ModelInput(model_file = model_path, wannier_center_convention = convention),
            sampling = KSlice(
                k_mesh = (2, 2),
                spatial_dimension = 3,
                origin = (0.0, 0.0, 0.0),
                vector_1 = (1.0, 0.0, 0.0),
                vector_2 = (0.0, 1.0, 0.0),
            ),
            tasks = [task],
            execution = ExecutionOptions(fourier_backend = "Direct"),
        )
        cfg=R.compile_task_config(input, task);
        specs=R.normalize_task_specs(cfg)
        plan=R.bundle_matrix_element_plan(specs, cfg, component)
        fullplan=R.bundle_matrix_element_plan(specs, cfg)
        for kind in (E.BERRY_CONNECTION, E.GAUGE_CORRECTION, E.VELOCITY_VERTICES)
            @test !E.has_capability(plan, kind)
        end
        @test E._axis_required(plan, E.INTERNAL_CONNECTION, 1) &&
              E._axis_required(plan, E.INTERNAL_CONNECTION, 3)
        # q_y is nonzero even though optical polarizations are x/z: raw A_y is mandatory.
        @test E._axis_required(plan, E.INTERNAL_CONNECTION, 2)
        @test Set(a for a in 1:3 if E._axis_required(plan, E.INTERNAL_CONNECTION, a)) ==
              Set((1, 2, 3))
        @test E._axis_required(plan, E.HAMILTONIAN_DERIVATIVES, 2)==(quantity=="PDICK")
        narrow=[E.MatrixElementWorkspace(model, plan) for _ in 1:2]
        full=[E.MatrixElementWorkspace(model, fullplan) for _ in 1:2]
        foreach(ws->E.prepare_real_space!(ws, model), vcat(narrow, full))
        for sign in (-1, 1)
            k=[0.17, 0.23, 0.31];
            q=sign*[0.003, 0.001, 0.002];
            points=(k-q/2, k+q/2)
            data=[E.compute_kpoint!(narrow[i], model, points[i]) for i in 1:2]
            reference=[E.compute_kpoint!(full[i], model, points[i]) for i in 1:2]
            for leg in 1:2
                @test any(x->!iszero(x), data[leg].position.wannier_gauge[:, :, [1, 3]])
                velocity=E.physical_velocity_vertices(data[leg]; source_gauge = true)
                retained=E.physical_velocity_vertices(reference[leg]; source_gauge = true)
                @test reinterpret(
                    UInt64,
                    vec(velocity[:, :, [1, 3]]),
                )==reinterpret(UInt64, vec(retained[:, :, [1, 3]]))
                if quantity=="PDICK"
                    @test reinterpret(
                        UInt64,
                        diag(data[leg].source_gauge_hamiltonian_derivatives[:, :, 2]),
                    )==reinterpret(
                        UInt64,
                        diag(reference[leg].source_gauge_hamiltonian_derivatives[:, :, 2]),
                    )
                end
                @test !E._has_capability(data[leg].computed_mask, E.GAUGE_CORRECTION)
            end
            overlap1=zeros(ComplexF64, n, n);
            overlap2=similar(overlap1)
            response.photon_drag_compute_overlaps!(
                overlap1,
                overlap2,
                data[1],
                data[2],
                points[1],
                points[2],
                centers,
                true,
                n,
            )
            phase_forward=Diagonal([cis(2pi*dot(points[1]-points[2], centers[:, i])) for i in 1:n])
            phase_backward=Diagonal([cis(2pi*dot(points[2]-points[1], centers[:, i])) for i in 1:n])
            Uv=data[1].spectrum.source_eigenvectors;
            Uc=data[2].spectrum.source_eigenvectors
            @test overlap1 ≈ Uv'*phase_forward*Uc atol=1e-13 rtol=1e-13
            @test overlap2 ≈ Uc'*phase_backward*Uv atol=1e-13 rtol=1e-13
            forward=zeros(ComplexF64, n, n, 3);
            backward=similar(forward);
            fullforward=similar(forward);
            fullbackward=similar(forward)
            scratch1=zeros(ComplexF64, n, n);
            scratch2=similar(scratch1)
            response._photon_drag_compute_velocity_vertices_blas!(
                forward,
                backward,
                scratch1,
                scratch2,
                overlap1,
                overlap2,
                data[1],
                data[2],
                3,
                component,
            )
            response._photon_drag_compute_velocity_vertices_blas!(
                fullforward,
                fullbackward,
                scratch1,
                scratch2,
                overlap1,
                overlap2,
                reference[1],
                reference[2],
                3,
                nothing,
            )
            @test reinterpret(
                UInt64,
                vec(forward[:, :, 3]),
            )==reinterpret(UInt64, vec(fullforward[:, :, 3]))
            @test reinterpret(
                UInt64,
                vec(backward[:, :, 1]),
            )==reinterpret(UInt64, vec(fullbackward[:, :, 1]))
            @test any(x->!iszero(x), forward[:, :, 3]) && any(x->!iszero(x), backward[:, :, 1])
        end
    end
end

include("phased_photon_overlaps_unit.jl")

include("active_photon_drag_insertions_unit.jl")

function dense_panel_storage_allocation(output, indices, factors::Vararg{Any, N}) where {N}
    return @allocated PDIC_BLAS_MATRIX_ELEMENTS._dense_column_panel_storage_eligible(
        output,
        indices,
        factors...,
    )
end

@testset "Two matrix readers share storage admission without merging column semantics" begin
    me = PDIC_BLAS_MATRIX_ELEMENTS
    rng = MersenneTwister(2641)
    for n in (128, 132, 256)
        left = randn(rng, ComplexF64, n, n)
        right = randn(rng, ComplexF64, n, n)
        overlap = randn(rng, ComplexF64, n, n)
        sentinel = ComplexF64(-7.0, 13.0)
        indices = Int[2, 63]
        actual = fill(sentinel, n, n);
        expected = copy(actual)
        @views mul!(expected[:, 1:64], left, right[:, 1:64])
        me._compute_convention_link_columns!(actual, left, right, indices)
        @test reinterpret(UInt64, vec(actual)) == reinterpret(UInt64, vec(expected))
        actual .= sentinel;
        expected .= sentinel
        @views mul!(expected[:, 1:64], left, overlap[:, 1:64])
        @views mul!(expected[:, 1:64], overlap, right[:, 1:64], 1.0, 1.0)
        me.active_velocity_selected_columns!(actual, left, right, overlap, indices)
        @test reinterpret(UInt64, vec(actual)) == reinterpret(UInt64, vec(expected))
        @test me._dense_column_panel_storage_eligible(actual, indices, left, right)
        @test me._dense_column_panel_storage_eligible(actual, indices, left, right, overlap)
        @test !me._dense_column_panel_storage_eligible(left, indices, left, right)
        @test !me._dense_column_panel_storage_eligible(actual, indices, left[:, 1:(end - 1)], right)
        @test !me._dense_column_panel_storage_eligible(actual, Int[], left, right)
        dense_panel_storage_allocation(actual, indices, left, right)
        dense_panel_storage_allocation(actual, indices, left, right, overlap)
        @test dense_panel_storage_allocation(actual, indices, left, right) == 0
        @test dense_panel_storage_allocation(actual, indices, left, right, overlap) == 0
        # Existing caller validation still rejects a duplicated, unsorted group.
        me._compute_convention_link_columns!(actual, left, right, Int[63, 2])
        mul!(expected, left, right)
        @test reinterpret(UInt64, vec(actual)) == reinterpret(UInt64, vec(expected))
    end
    n = 256
    left = randn(rng, ComplexF64, n, n);
    right = randn(rng, ComplexF64, n, n);
    overlap = randn(rng, ComplexF64, n, n)
    actual=fill(ComplexF64(-7, 13), n, n);
    expected=copy(actual);
    indices=Int[2, 130]
    # Link needs one continuous span of three panels and falls back to full output.
    mul!(expected, left, right);
    me._compute_convention_link_columns!(actual, left, right, indices)
    @test reinterpret(UInt64, vec(actual)) == reinterpret(UInt64, vec(expected))
    # Velocity insertion keeps two disjoint panels, not the link's span policy.
    actual .= ComplexF64(-7, 13);
    expected .= ComplexF64(-7, 13)
    for columns in (1:64, 129:192)
        @views mul!(expected[:, columns], left, overlap[:, columns])
        @views mul!(expected[:, columns], overlap, right[:, columns], 1.0, 1.0)
    end
    me.active_velocity_selected_columns!(actual, left, right, overlap, indices)
    @test reinterpret(UInt64, vec(actual)) == reinterpret(UInt64, vec(expected))
end

include("panel_gemm_comparison_unit.jl")
