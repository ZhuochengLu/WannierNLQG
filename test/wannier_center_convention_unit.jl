using LinearAlgebra
using Random
using Test

const WCC_CORE = WannierNLQG.Core
const WCC_IO = WannierNLQG.IO
const WCC_MATRIX = WannierNLQG.MatrixElements
const WCC_RUNTIME = WannierNLQG.Runtime
const WCC_RESPONSES = WannierNLQG.Responses

function wcc_synthetic_model()
    lattice = [2.0 0.0 0.0; 0.0 3.0 0.0; 0.0 0.0 4.0]
    r_vectors = Int[-1 0 1; 0 0 0; 0 0 0]
    hamiltonian = zeros(ComplexF64, 2, 2, 3)
    hamiltonian[:, :, 2] .= ComplexF64[-0.7 0.12+0.08im; 0.12-0.08im 0.9]
    hopping = ComplexF64[0.11+0.02im -0.03+0.05im; 0.04-0.01im -0.08+0.03im]
    hamiltonian[:, :, 3] .= hopping
    hamiltonian[:, :, 1] .= hopping'

    position = zeros(ComplexF64, 2, 2, 3, 3)
    centers = [0.23 -0.31; 0.41 0.17; -0.12 0.28]
    for direction in 1:3
        home = ComplexF64[
            centers[direction, 1] 0.02+0.01im
            0.02-0.01im centers[direction, 2]
        ]
        position[:, :, direction, 2] .= home
        forward = ComplexF64[
            0.01+0.02im 0.03-0.01im
            -0.02+0.04im 0.005-0.01im
        ] .* direction
        position[:, :, direction, 3] .= forward
        position[:, :, direction, 1] .= forward'
    end
    model =
        WCC_CORE.TightBindingModel(lattice, 2, 3, ones(Int, 3), r_vectors, hamiltonian, position)
    return model, centers
end

function centered_fourier_oracle(model, centers, kpoint)
    dimension = 2
    hamiltonian = zeros(ComplexF64, 2, 2)
    gradient = zeros(ComplexF64, 2, 2, dimension)
    hessian = zeros(ComplexF64, 2, 2, dimension, dimension)
    position = zeros(ComplexF64, 2, 2, dimension)
    position_gradient = zeros(ComplexF64, 2, 2, dimension, dimension)
    for r_index in 1:model.num_r_vectors
        r_cartesian = transpose(model.lattice) * model.r_vectors[:, r_index]
        home = all(iszero, @view(model.r_vectors[:, r_index]))
        for column in 1:model.num_orbitals, row in 1:model.num_orbitals
            phase = cis(
                2.0 *
                pi *
                (
                    dot(kpoint, @view(model.r_vectors[:, r_index])) + sum(
                        kpoint[direction] * (centers[direction, column] - centers[direction, row]) /
                        model.lattice[direction, direction] for direction in 1:3
                    )
                ),
            )
            hopping = model.hamiltonian_r[row, column, r_index]
            hamiltonian[row, column] += phase * hopping
            for first in 1:dimension
                displacement = r_cartesian[first] + centers[first, column] - centers[first, row]
                gradient[row, column, first] += phase * 1.0im * displacement * hopping
                for second in 1:dimension
                    displacement_second =
                        r_cartesian[second] + centers[second, column] - centers[second, row]
                    hessian[row, column, first, second] -=
                        phase * displacement * displacement_second * hopping
                end
            end
            for position_direction in 1:dimension
                value = model.position_r[row, column, position_direction, r_index]
                if home && row == column
                    value -= centers[position_direction, row]
                end
                position[row, column, position_direction] += phase * value
                for derivative_direction in 1:dimension
                    displacement =
                        r_cartesian[derivative_direction] + centers[derivative_direction, column] -
                        centers[derivative_direction, row]
                    position_gradient[row, column, position_direction, derivative_direction] +=
                        phase * 1.0im * displacement * value
                end
            end
        end
    end
    return (; hamiltonian, gradient, hessian, position, position_gradient)
end

function pack_pair_channels(values)
    packed = similar(values, size(values, 1), size(values, 2), 4)
    channel = 0
    for first in 1:2, second in 1:2
        channel += 1
        packed[:, :, channel] .= values[:, :, first, second]
    end
    return packed
end

@testset "Wannier-center convention configuration" begin
    @test WCC_RUNTIME.normalize_wannier_center_convention("Convention_1") == WCC_CORE.CONVENTION_I
    @test WCC_RUNTIME.normalize_wannier_center_convention("Convention II") == WCC_CORE.CONVENTION_II
    @test_throws ErrorException WCC_RUNTIME.normalize_wannier_center_convention("centered")
    @test WannierNLQG.Runtime.EffectiveTaskConfig(fourier_backend = "Direct").wannier_center_convention ==
          "Convention_II"
    @test WannierNLQG.Runtime.EffectiveTaskConfig(
        fourier_backend = "Direct",
        wannier_center_convention = "Convention_I",
    ).wannier_center_convention == "Convention_I"
    migration_error = try
        WannierNLQG.Runtime.EffectiveTaskConfig(
            fourier_backend = "Direct",
            wannier_center_convention = "Convention_I",
            basis_correction_enabled = true,
        )
        nothing
    catch err
        err
    end
    @test migration_error isa ErrorException
    @test occursin("has been removed", sprint(showerror, migration_error))
    @test occursin("wannier_center_convention", sprint(showerror, migration_error))
end

@testset "Projector operator demand includes complete geometry" begin
    for convention in ("Convention_I", "Convention_II")
        cfg = WannierNLQG.Runtime.EffectiveTaskConfig(
            tasks = [("SCK", "Projector", "K-slice")],
            fourier_backend = "Direct",
            tensor_indices = (2, 1, 2),
            wannier_center_convention = convention,
        )
        demand = WCC_RUNTIME.operator_demand_plan(WCC_RUNTIME.normalize_task_specs(cfg), cfg)
        @test demand.required_components[WCC_IO.REAL_SPACE_POSITION] ==
              [(Int8(1), Int8(0)), (Int8(2), Int8(0)), (Int8(3), Int8(0))]
        @test demand.requires_full_projector_geometry
        @test demand.required_components[WCC_IO.REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR] ==
              [(Int8(1), Int8(2)), (Int8(2), Int8(1)), (Int8(2), Int8(2))]
    end
end

@testset "Projector exact derivative overlap fails closed" begin
    model, _centers = wcc_synthetic_model()
    request = WCC_MATRIX.MatrixElementRequest(WCC_MATRIX.WANNIER_POSITION; spatial_dimension = 2)
    plan = WCC_MATRIX.compile_matrix_plan(request)
    matrix_workspace = WCC_MATRIX.MatrixElementWorkspace(model, plan)
    projector_workspace = WCC_MATRIX.ProjectorMatrixWorkspace(matrix_workspace)
    projector_data = WCC_MATRIX.ProjectorMatrixData(matrix_workspace.data, 2)
    caught = try
        WCC_MATRIX.prepare_projector_covariant_geometry!(projector_data, projector_workspace, model)
        nothing
    catch exception
        exception
    end
    @test caught isa ArgumentError
    @test occursin("PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED", sprint(showerror, caught))

    # Retain the superseded native-stencil oracle as non-executed historical test code.
    if false
        model, _centers = wcc_synthetic_model()
        request =
            WCC_MATRIX.MatrixElementRequest(WCC_MATRIX.WANNIER_POSITION; spatial_dimension = 2)
        kpoint = [0.173, 0.281, 0.0]
        step = 1.0e-4
        finite_difference_vectors = zeros(3, 2)
        for direction in 1:2
            cartesian = zeros(3)
            cartesian[direction] = step
            finite_difference_vectors[:, direction] .=
                WCC_CORE.reciprocal_cartesian_to_fractional(cartesian, model.lattice)
        end
        caches = map((WCC_CORE.CONVENTION_I, WCC_CORE.CONVENTION_II)) do convention
            plan = WCC_MATRIX.compile_matrix_plan(request; wannier_center_convention = convention)
            matrix_workspace = WCC_MATRIX.MatrixElementWorkspace(model, plan)
            cache = WCC_RESPONSES.make_projector_response_workspace(
                model.num_orbitals,
                model.num_r_vectors,
                2,
                1;
                matrix_elements = matrix_workspace,
            )
            WCC_MATRIX.prepare_real_space!(cache.scratch, model)
            WCC_RESPONSES.prepare_projector_response_cache!(
                cache,
                kpoint,
                finite_difference_vectors,
                model,
                model.num_orbitals,
                2;
                denominator_regularization = 1.0e-3,
                degeneracy_threshold = 1.0e-8,
                finite_difference_step = step,
            )
            cache
        end
        for cache in caches
            data = cache.central_data
            for band in 1:model.num_orbitals, axis in 1:2
                projector = @view data.projectors[band, :, :]
                forward = @view cache.forward_projectors[band, :, :, axis]
                backward = @view cache.backward_projectors[band, :, :, axis]
                connection = @view data.wannier_connection[:, :, axis]
                pure_first = (forward - backward) / (2 * step)
                first_oracle =
                    pure_first - im * connection * projector + im * projector * connection
                diagonal_second_oracle =
                    (forward + backward - 2 * projector) / step^2 -
                    2im * (connection * pure_first - pure_first * connection) +
                    2 * connection * projector * connection - connection * connection * projector -
                    projector * connection * connection
                @test data.projector_derivatives[band, :, :, axis] ≈ first_oracle rtol = 1.0e-10 atol =
                    1.0e-12
                @test data.projector_second_derivatives[band, :, :, axis, axis] ≈
                      diagonal_second_oracle rtol = 1.0e-10 atol = 1.0e-12
                @test norm(projector - projector') / max(norm(projector), 1.0) <= 1.0e-12
                @test norm(first_oracle - first_oracle') / max(norm(first_oracle), 1.0) <= 1.0e-12
            end

            for band in 1:model.num_orbitals
                projector = @view data.projectors[band, :, :]
                connection_1 = @view data.wannier_connection[:, :, 1]
                connection_2 = @view data.wannier_connection[:, :, 2]
                pure_1 = @view cache.pure_projector_derivatives[band, :, :, 1]
                pure_2 = @view cache.pure_projector_derivatives[band, :, :, 2]
                mixed_pure =
                    (
                        cache.second_forward_data.projectors[band, :, :] +
                        cache.second_backward_data.projectors[band, :, :] +
                        2 * projector - cache.forward_projectors[band, :, :, 1] -
                        cache.forward_projectors[band, :, :, 2] -
                        cache.backward_projectors[band, :, :, 1] -
                        cache.backward_projectors[band, :, :, 2]
                    ) / (2 * step^2)
                mixed_oracle =
                    mixed_pure -
                    im * (
                        connection_1 * pure_2 + connection_2 * pure_1 - pure_1 * connection_2 -
                        pure_2 * connection_1
                    ) +
                    connection_1 * projector * connection_2 +
                    connection_2 * projector * connection_1 -
                    projector * connection_1 * connection_2 -
                    connection_1 * connection_2 * projector
                @test data.projector_second_derivatives[band, :, :, 1, 2] ≈ mixed_oracle rtol =
                    1.0e-10 atol = 1.0e-12
                @test data.projector_second_derivatives[band, :, :, 2, 1] ≈ mixed_oracle rtol =
                    1.0e-10 atol = 1.0e-12
            end
        end
        @test maximum(abs, caches[1].central_data.projectors - caches[2].central_data.projectors) >
              1.0e-6
    end
end

@testset "Centered Fourier oracle" begin
    model, centers = wcc_synthetic_model()
    request = WCC_MATRIX.MatrixElementRequest(
        WCC_MATRIX.HAMILTONIAN_DERIVATIVES,
        WCC_MATRIX.HAMILTONIAN_SECOND_DERIVATIVES,
        WCC_MATRIX.INTERNAL_CONNECTION_DERIVATIVES;
        spatial_dimension = 2,
    )
    plan_i =
        WCC_MATRIX.compile_matrix_plan(request; wannier_center_convention = WCC_CORE.CONVENTION_I)
    workspace_i = WCC_MATRIX.MatrixElementWorkspace(model, plan_i)
    WCC_MATRIX.prepare_real_space!(workspace_i, model)
    kpoint = [0.173, 0.281, 0.0]
    WCC_MATRIX.compute_kpoint!(workspace_i, model, kpoint)
    oracle = centered_fourier_oracle(model, centers, kpoint)

    @test workspace_i.scratch.hamiltonian_wannier ≈ oracle.hamiltonian atol = 2.0e-14
    @test workspace_i.scratch.hamiltonian.gradient_wannier ≈ oracle.gradient atol = 2.0e-14
    @test workspace_i.scratch.hamiltonian.hessian_wannier ≈ pack_pair_channels(oracle.hessian) atol =
        2.0e-14
    @test workspace_i.scratch.position.wannier_gauge ≈ oracle.position atol = 2.0e-14
    @test workspace_i.scratch.position.gradient_wannier ≈
          pack_pair_channels(oracle.position_gradient) atol = 2.0e-14
    @test workspace_i.scratch.hamiltonian_wannier ≈ workspace_i.scratch.hamiltonian_wannier' atol =
        2.0e-14

    plan_ii =
        WCC_MATRIX.compile_matrix_plan(request; wannier_center_convention = WCC_CORE.CONVENTION_II)
    workspace_ii = WCC_MATRIX.MatrixElementWorkspace(model, plan_ii)
    WCC_MATRIX.prepare_real_space!(workspace_ii, model)
    WCC_MATRIX.compute_kpoint!(workspace_ii, model, kpoint)
    @test workspace_i.data.spectrum.energies ≈ workspace_ii.data.spectrum.energies atol = 2.0e-13

    step = 1.0e-6
    for direction in 1:2
        reciprocal_step = zeros(3)
        reciprocal_step[direction] = step
        fractional_step =
            WCC_CORE.reciprocal_cartesian_to_fractional(reciprocal_step, model.lattice)
        plus = centered_fourier_oracle(model, centers, kpoint .+ fractional_step).hamiltonian
        minus = centered_fourier_oracle(model, centers, kpoint .- fractional_step).hamiltonian
        finite_difference = (plus .- minus) ./ (2.0 * step)
        @test finite_difference ≈ oracle.gradient[:, :, direction] rtol = 2.0e-9 atol = 2.0e-10
    end
end

@testset "Convention-covariant Wilson and native Geometric links" begin
    rng = MersenneTwister(0x20260804)
    request = WCC_MATRIX.MatrixElementRequest(WCC_MATRIX.BERRY_CONNECTION; spatial_dimension = 2)
    centers_fractional = [0.13 -0.21 0.37; -0.19 0.31 0.08; 0.04 -0.07 0.22]
    kpoints = ([0.17, 0.29, 0.0], [0.23, 0.11, 0.0], [0.05, 0.37, 0.0])
    convention_ii_eigenvectors = [Matrix(qr(randn(rng, ComplexF64, 3, 3)).Q) for _ in 1:3]
    corrected_links = Dict{WCC_CORE.WannierCenterConvention, Vector{Matrix{ComplexF64}}}()
    point_sets = Dict{WCC_CORE.WannierCenterConvention, Any}()
    for convention in (WCC_CORE.CONVENTION_I, WCC_CORE.CONVENTION_II)
        plan = WCC_MATRIX.compile_matrix_plan(request; wannier_center_convention = convention)
        matrix_workspace = WCC_MATRIX.MatrixElementWorkspace(3, 0, plan)
        workspace = WCC_RESPONSES.make_wilson_loop_response_workspace(
            3,
            0,
            2,
            1;
            matrix_elements = matrix_workspace,
        )
        points = map(1:3) do point_index
            common = WCC_MATRIX.KPointMatrixData(3, 0, plan)
            common.kpoint .= kpoints[point_index]
            phases = cis.(2.0 * pi .* vec(transpose(kpoints[point_index]) * centers_fractional))
            eigenvectors =
                convention == WCC_CORE.CONVENTION_I ?
                Diagonal(conj.(phases)) * convention_ii_eigenvectors[point_index] :
                convention_ii_eigenvectors[point_index]
            common.spectrum.source_eigenvectors .= eigenvectors
            common.spectrum.source_eigenvectors_adjoint .= eigenvectors'
            WCC_MATRIX.GeometricLoopMatrixData(common)
        end
        links = Matrix{ComplexF64}[]
        for (left_index, right_index) in ((1, 2), (2, 3), (3, 1))
            output = zeros(ComplexF64, 3, 3)
            WCC_RESPONSES.wilson_loop_overlap!(
                output,
                points[left_index],
                points[right_index],
                workspace.frame_connector,
                centers_fractional,
                workspace.frame_phase_factors,
                workspace.frame_rotated_eigenvectors,
            )
            left_phases = cis.(2.0 * pi .* vec(transpose(kpoints[left_index]) * centers_fractional))
            right_phases =
                cis.(2.0 * pi .* vec(transpose(kpoints[right_index]) * centers_fractional))
            oracle =
                convention_ii_eigenvectors[left_index]' *
                Diagonal(left_phases .* conj.(right_phases)) *
                convention_ii_eigenvectors[right_index]
            @test output ≈ oracle rtol = 1.0e-10 atol = 1.0e-12
            push!(links, output)
        end
        closed_loop = links[1] * links[2] * links[3]
        identity_matrix = Matrix{ComplexF64}(I, 3, 3)
        @test norm(closed_loop - identity_matrix) / norm(identity_matrix) <= 1.0e-12
        corrected_links[convention] = links
        point_sets[convention] = points
    end
    for link_index in 1:3
        @test corrected_links[WCC_CORE.CONVENTION_I][link_index] ≈
              corrected_links[WCC_CORE.CONVENTION_II][link_index] rtol = 1.0e-10 atol = 1.0e-12
    end

    # Recompute every link after independent block-unitary rotations at the
    # three points.  This exercises the actual Wilson link primitive rather
    # than checking covariance only by post-multiplying a stored matrix.
    gauges = map(1:3) do _
        block = Matrix(qr(randn(rng, ComplexF64, 2, 2)).Q)
        [block zeros(ComplexF64, 2, 1); zeros(ComplexF64, 1, 2) cis(randn(rng))]
    end
    link_pairs = ((1, 2), (2, 3), (3, 1))
    for convention in (WCC_CORE.CONVENTION_I, WCC_CORE.CONVENTION_II)
        plan = WCC_MATRIX.compile_matrix_plan(request; wannier_center_convention = convention)
        matrix_workspace = WCC_MATRIX.MatrixElementWorkspace(3, 0, plan)
        workspace = WCC_RESPONSES.make_wilson_loop_response_workspace(
            3,
            0,
            2,
            1;
            matrix_elements = matrix_workspace,
        )
        gauged_points = map(1:3) do point_index
            original = point_sets[convention][point_index]
            common = WCC_MATRIX.KPointMatrixData(3, 0, plan)
            common.kpoint .= original.common.kpoint
            common.spectrum.source_eigenvectors .=
                original.spectrum.source_eigenvectors * gauges[point_index]
            common.spectrum.source_eigenvectors_adjoint .= common.spectrum.source_eigenvectors'
            WCC_MATRIX.GeometricLoopMatrixData(common)
        end
        gauged_links = map(link_pairs) do (left_index, right_index)
            output = zeros(ComplexF64, 3, 3)
            WCC_RESPONSES.wilson_loop_overlap!(
                output,
                gauged_points[left_index],
                gauged_points[right_index],
                workspace.frame_connector,
                centers_fractional,
                workspace.frame_phase_factors,
                workspace.frame_rotated_eigenvectors,
            )
            oracle =
                gauges[left_index]' *
                corrected_links[convention][findfirst(==((left_index, right_index)), link_pairs)] *
                gauges[right_index]
            @test output ≈ oracle rtol = 1.0e-10 atol = 1.0e-12
            output
        end
        closed_native =
            corrected_links[convention][1] *
            corrected_links[convention][2] *
            corrected_links[convention][3]
        closed_gauged = gauged_links[1] * gauged_links[2] * gauged_links[3]
        @test closed_gauged ≈ gauges[1]' * closed_native * gauges[1] rtol = 1.0e-10 atol = 1.0e-12
        @test tr(closed_gauged) ≈ tr(closed_native) rtol = 1.0e-10 atol = 1.0e-12
        @test det(closed_gauged) ≈ det(closed_native) rtol = 1.0e-10 atol = 1.0e-12

        # A V-C transported derivative and the trace contractions used by the
        # response families must transform only in the center-point blocks.
        x_center = randn(rng, ComplexF64, 2, 1)
        x_plus = randn(rng, ComplexF64, 2, 1)
        x_minus = randn(rng, ComplexF64, 2, 1)
        forward = corrected_links[convention][1]
        backward = adjoint(corrected_links[convention][3])
        transported =
            forward[1:2, 1:2] * x_plus * adjoint(forward[3:3, 3:3]) -
            backward[1:2, 1:2] * x_minus * adjoint(backward[3:3, 3:3])
        x_plus_gauged = gauges[2][1:2, 1:2]' * x_plus * gauges[2][3:3, 3:3]
        x_minus_gauged = gauges[3][1:2, 1:2]' * x_minus * gauges[3][3:3, 3:3]
        forward_gauged = gauged_links[1]
        backward_gauged = adjoint(gauged_links[3])
        transported_gauged =
            forward_gauged[1:2, 1:2] * x_plus_gauged * adjoint(forward_gauged[3:3, 3:3]) -
            backward_gauged[1:2, 1:2] * x_minus_gauged * adjoint(backward_gauged[3:3, 3:3])
        transported_oracle = gauges[1][1:2, 1:2]' * transported * gauges[1][3:3, 3:3]
        @test transported_gauged ≈ transported_oracle rtol = 1.0e-10 atol = 1.0e-12
        x_center_gauged = gauges[1][1:2, 1:2]' * x_center * gauges[1][3:3, 3:3]
        @test tr(x_center_gauged' * transported_gauged) ≈ tr(x_center' * transported) rtol = 1.0e-10 atol =
            1.0e-12
    end
end

@testset "Convention-covariant link edge cases" begin
    request = WCC_MATRIX.MatrixElementRequest(WCC_MATRIX.BERRY_CONNECTION; spatial_dimension = 2)
    plan =
        WCC_MATRIX.compile_matrix_plan(request; wannier_center_convention = WCC_CORE.CONVENTION_II)
    left_common = WCC_MATRIX.KPointMatrixData(1, 0, plan)
    right_common = WCC_MATRIX.KPointMatrixData(1, 0, plan)
    left_common.kpoint .= [0.17, 0.29, 0.0]
    right_common.kpoint .= [0.23, 0.11, 0.0]
    left_common.spectrum.source_eigenvectors .= ones(ComplexF64, 1, 1)
    left_common.spectrum.source_eigenvectors_adjoint .= ones(ComplexF64, 1, 1)
    right_common.spectrum.source_eigenvectors .= ones(ComplexF64, 1, 1)
    right_common.spectrum.source_eigenvectors_adjoint .= ones(ComplexF64, 1, 1)
    left = WCC_MATRIX.GeometricLoopMatrixData(left_common)
    right = WCC_MATRIX.GeometricLoopMatrixData(right_common)
    connector = WCC_MATRIX.make_convention_frame_connector(WCC_CORE.CONVENTION_II)
    phase = ones(ComplexF64, 1)
    rotated = zeros(ComplexF64, 1, 1)
    output = similar(rotated)
    reverse = similar(rotated)
    boundary_center = reshape([1.23, -0.41, 0.0], 3, 1)
    WCC_MATRIX.compute_convention_covariant_overlap!(
        output,
        left,
        right,
        connector,
        boundary_center,
        phase,
        rotated,
    )
    oracle = cis(2pi * dot(left_common.kpoint - right_common.kpoint, boundary_center[:, 1]))
    @test output[1, 1] ≈ oracle rtol = 1.0e-10 atol = 1.0e-12
    WCC_MATRIX.compute_convention_covariant_overlap!(
        reverse,
        right,
        left,
        connector,
        boundary_center,
        phase,
        rotated,
    )
    @test reverse ≈ output' rtol = 1.0e-10 atol = 1.0e-12

    zero_center = zeros(3, 1)
    WCC_MATRIX.compute_convention_covariant_overlap!(
        output,
        left,
        right,
        connector,
        zero_center,
        phase,
        rotated,
    )
    @test maximum(abs, output .- 1.0) <= 1.0e-12

    rng = MersenneTwister(0x0b17a1)
    plan_two =
        WCC_MATRIX.compile_matrix_plan(request; wannier_center_convention = WCC_CORE.CONVENTION_II)
    left_two = WCC_MATRIX.KPointMatrixData(2, 0, plan_two)
    right_two = WCC_MATRIX.KPointMatrixData(2, 0, plan_two)
    left_two.kpoint .= left_common.kpoint
    right_two.kpoint .= right_common.kpoint
    left_unitary = Matrix(qr(randn(rng, ComplexF64, 2, 2)).Q)
    right_unitary = Matrix(qr(randn(rng, ComplexF64, 2, 2)).Q)
    centers_two = [0.13 1.27; -0.22 0.31; 0.0 0.0]
    permutation = [0.0 1.0; 1.0 0.0]
    links = Matrix{ComplexF64}[]
    for reordered in (false, true)
        left_eigenvectors = reordered ? permutation * left_unitary : left_unitary
        right_eigenvectors = reordered ? permutation * right_unitary : right_unitary
        centers = reordered ? centers_two[:, [2, 1]] : centers_two
        left_two.spectrum.source_eigenvectors .= left_eigenvectors
        left_two.spectrum.source_eigenvectors_adjoint .= left_eigenvectors'
        right_two.spectrum.source_eigenvectors .= right_eigenvectors
        right_two.spectrum.source_eigenvectors_adjoint .= right_eigenvectors'
        link = zeros(ComplexF64, 2, 2)
        WCC_MATRIX.compute_convention_covariant_overlap!(
            link,
            WCC_MATRIX.GeometricLoopMatrixData(left_two),
            WCC_MATRIX.GeometricLoopMatrixData(right_two),
            connector,
            centers,
            ones(ComplexF64, 2),
            zeros(ComplexF64, 2, 2),
        )
        push!(links, link)
    end
    @test links[1] ≈ links[2] rtol = 1.0e-10 atol = 1.0e-12
end

@testset "Wilson split covariant derivative oracle" begin
    rng = MersenneTwister(0x51a17)
    request = WCC_MATRIX.MatrixElementRequest(WCC_MATRIX.BERRY_CONNECTION; spatial_dimension = 2)
    plan =
        WCC_MATRIX.compile_matrix_plan(request; wannier_center_convention = WCC_CORE.CONVENTION_I)
    matrix_workspace = WCC_MATRIX.MatrixElementWorkspace(4, 0, plan)
    ws = WCC_RESPONSES.make_wilson_loop_response_workspace(
        4,
        0,
        2,
        1;
        matrix_elements = matrix_workspace,
    )
    central = ws.central_data
    central.spectrum.energies .= [0.0, 0.0, 1.0, 1.0]
    WCC_MATRIX.mark_degenerate_groups!(central, 1.0e-8)

    generator_v = Hermitian(randn(rng, ComplexF64, 2, 2)) |> Matrix
    generator_c = Hermitian(randn(rng, ComplexF64, 2, 2)) |> Matrix
    internal_v = Hermitian(randn(rng, ComplexF64, 2, 2)) |> Matrix
    internal_c = Hermitian(randn(rng, ComplexF64, 2, 2)) |> Matrix
    x0 = randn(rng, ComplexF64, 2, 2)
    x1 = randn(rng, ComplexF64, 2, 2)
    k0 = 0.23
    x_fixed(k) = sin(k) .* x0 .+ cos(2k) .* x1
    dx_fixed(k) = cos(k) .* x0 .- 2sin(2k) .* x1
    qv(k) = exp(-1.0im * k .* generator_v)
    qc(k) = exp(-1.0im * k .* generator_c)
    block_unitary(k) = [qv(k) zeros(ComplexF64, 2, 2); zeros(ComplexF64, 2, 2) qc(k)]
    x_source(k) = qv(k)' * x_fixed(k) * qc(k)
    central_unitary = block_unitary(k0)
    central.spectrum.source_eigenvectors .= central_unitary
    central.spectrum.source_eigenvectors_adjoint .= central_unitary'
    central.berry_connection[:, :, 1] .= 0.0
    central.berry_connection[1:2, 3:4, 1] .= x_source(k0)
    ws.source_internal_connection[:, :, :] .= 0.0
    ws.source_internal_connection[1:2, 1:2, 1] .= qv(k0)' * internal_v * qv(k0)
    ws.source_internal_connection[3:4, 3:4, 1] .= qc(k0)' * internal_c * qc(k0)
    oracle =
        qv(k0)' *
        (dx_fixed(k0) - 1.0im * internal_v * x_fixed(k0) + 1.0im * x_fixed(k0) * internal_c) *
        qc(k0)

    errors = Float64[]
    for step in (2.0e-2, 1.0e-2, 5.0e-3)
        for (data, shifted_k) in ((ws.forward_data[1], k0 + step), (ws.backward_data[1], k0 - step))
            shifted_unitary = block_unitary(shifted_k)
            data.spectrum.source_eigenvectors .= shifted_unitary
            data.spectrum.source_eigenvectors_adjoint .= shifted_unitary'
            data.berry_connection[:, :, 1] .= 0.0
            data.berry_connection[1:2, 3:4, 1] .= x_source(shifted_k)
        end
        mul!(
            @view(ws.central_to_forward_overlap[:, :, 1]),
            central.spectrum.source_eigenvectors_adjoint,
            ws.forward_data[1].spectrum.source_eigenvectors,
        )
        copyto!(
            @view(ws.forward_to_central_overlap[:, :, 1]),
            adjoint(@view(ws.central_to_forward_overlap[:, :, 1])),
        )
        mul!(
            @view(ws.central_to_backward_overlap[:, :, 1]),
            central.spectrum.source_eigenvectors_adjoint,
            ws.backward_data[1].spectrum.source_eigenvectors,
        )
        copyto!(
            @view(ws.backward_to_central_overlap[:, :, 1]),
            adjoint(@view(ws.central_to_backward_overlap[:, :, 1])),
        )
        ws.transported_derivative_axis = 0
        fill!(ws.transported_derivative_valid, false)
        WCC_RESPONSES.prepare_wilson_transported_derivative_block!(ws, 1, 1, 3, (1,), step)
        derivative = @view ws.transported_connection_derivatives[1:2, 3:4, 1]
        push!(errors, norm(derivative - oracle))
    end
    observed_orders = log2.(errors[1:2] ./ errors[2:3])
    @test all(1.8 .<= observed_orders .<= 2.2)
    @test errors[3] < errors[1]
end

@testset "Geometric split covariant derivative oracle" begin
    rng = MersenneTwister(0x6e6f6d)
    valence_generator = Hermitian(randn(rng, ComplexF64, 2, 2)) |> Matrix
    conduction_generator = Hermitian(randn(rng, ComplexF64, 2, 2)) |> Matrix
    valence_external = Hermitian(randn(rng, ComplexF64, 2, 2)) |> Matrix
    conduction_external = Hermitian(randn(rng, ComplexF64, 2, 2)) |> Matrix
    insertion_0 = randn(rng, ComplexF64, 2, 2)
    insertion_1 = randn(rng, ComplexF64, 2, 2)
    k0 = 0.19
    fixed_insertion(k) = sin(k) .* insertion_0 .+ cos(2k) .* insertion_1
    fixed_derivative(k) = cos(k) .* insertion_0 .- 2sin(2k) .* insertion_1
    valence_gauge(k) = exp(-1.0im * k .* valence_generator)
    conduction_gauge(k) = exp(-1.0im * k .* conduction_generator)
    source_insertion(k) = valence_gauge(k)' * fixed_insertion(k) * conduction_gauge(k)

    central_valence_gauge = valence_gauge(k0)
    central_conduction_gauge = conduction_gauge(k0)
    central = source_insertion(k0)
    aligned_valence = central_valence_gauge' * valence_external * central_valence_gauge
    aligned_conduction = central_conduction_gauge' * conduction_external * central_conduction_gauge
    oracle =
        central_valence_gauge' *
        (
            fixed_derivative(k0) - 1.0im * valence_external * fixed_insertion(k0) +
            1.0im * fixed_insertion(k0) * conduction_external
        ) *
        central_conduction_gauge
    errors = Float64[]
    output = zeros(ComplexF64, 2, 2)
    temporary_left = similar(output)
    temporary_right = similar(output)
    for step in (2.0e-2, 1.0e-2, 5.0e-3)
        forward_valence_link = central_valence_gauge' * valence_gauge(k0 + step)
        forward_conduction_link = conduction_gauge(k0 + step)' * central_conduction_gauge
        backward_valence_link = central_valence_gauge' * valence_gauge(k0 - step)
        backward_conduction_link = conduction_gauge(k0 - step)' * central_conduction_gauge
        forward = forward_valence_link * source_insertion(k0 + step) * forward_conduction_link
        backward = backward_valence_link * source_insertion(k0 - step) * backward_conduction_link
        WCC_RESPONSES.compute_geometric_loop_covariant_insertion_derivative!(
            output,
            forward,
            backward,
            central,
            aligned_valence,
            aligned_conduction,
            temporary_left,
            temporary_right,
            step,
        )
        push!(errors, norm(output - oracle))
    end
    observed_orders = log2.(errors[1:2] ./ errors[2:3])
    @test all(1.8 .<= observed_orders .<= 2.2)
    @test errors[3] < errors[1]

    left_rotation = Matrix(qr(randn(rng, ComplexF64, 2, 2)).Q)
    right_rotation = Matrix(qr(randn(rng, ComplexF64, 2, 2)).Q)
    step = 1.0e-3
    forward = source_insertion(k0 + step)
    backward = source_insertion(k0 - step)
    WCC_RESPONSES.compute_geometric_loop_covariant_insertion_derivative!(
        output,
        forward,
        backward,
        central,
        aligned_valence,
        aligned_conduction,
        temporary_left,
        temporary_right,
        step,
    )
    reference = copy(output)
    WCC_RESPONSES.compute_geometric_loop_covariant_insertion_derivative!(
        output,
        left_rotation' * forward * right_rotation,
        left_rotation' * backward * right_rotation,
        left_rotation' * central * right_rotation,
        left_rotation' * aligned_valence * left_rotation,
        right_rotation' * aligned_conduction * right_rotation,
        temporary_left,
        temporary_right,
        step,
    )
    @test output ≈ left_rotation' * reference * right_rotation rtol = 1.0e-10 atol = 1.0e-12
    @test_throws ErrorException WCC_RESPONSES.compute_geometric_loop_covariant_insertion_derivative!(
        output,
        forward,
        backward,
        central,
        aligned_valence,
        aligned_conduction,
        temporary_left,
        temporary_right,
        NaN,
    )
end

@testset "Geometric block-projected covariant derivative" begin
    rng = MersenneTwister(0xb10c5)
    block_size = 2
    random_unitary() = Matrix(qr(randn(rng, ComplexF64, block_size, block_size)).Q)
    h = 7.0e-4

    forward_valence = randn(rng, ComplexF64, block_size, block_size)
    forward_insertion = randn(rng, ComplexF64, block_size, block_size)
    forward_conduction = randn(rng, ComplexF64, block_size, block_size)
    backward_valence = randn(rng, ComplexF64, block_size, block_size)
    backward_insertion = randn(rng, ComplexF64, block_size, block_size)
    backward_conduction = randn(rng, ComplexF64, block_size, block_size)
    central_insertion = randn(rng, ComplexF64, block_size, block_size)
    valence_connection = randn(rng, ComplexF64, block_size, block_size)
    conduction_connection = randn(rng, ComplexF64, block_size, block_size)

    function block_derivative(m_vf, j_f, m_fc, m_vb, j_b, m_bc, j_0, a_v, a_c)
        output = zeros(ComplexF64, size(j_0))
        forward_output = similar(output)
        backward_output = similar(output)
        temporary_left = similar(output)
        temporary_right = similar(output)
        WCC_RESPONSES.compute_geometric_loop_block_covariant_insertion_derivative!(
            output,
            m_vf,
            j_f,
            m_fc,
            m_vb,
            j_b,
            m_bc,
            j_0,
            a_v,
            a_c,
            forward_output,
            backward_output,
            temporary_left,
            temporary_right,
            h,
        )
        return output
    end

    reference = block_derivative(
        forward_valence,
        forward_insertion,
        forward_conduction,
        backward_valence,
        backward_insertion,
        backward_conduction,
        central_insertion,
        valence_connection,
        conduction_connection,
    )
    oracle =
        (
            forward_valence * forward_insertion * forward_conduction -
            backward_valence * backward_insertion * backward_conduction
        ) / (2h) - 1.0im * valence_connection * central_insertion +
        1.0im * central_insertion * conduction_connection
    @test reference ≈ oracle rtol = 1.0e-10 atol = 1.0e-12

    q_v0 = random_unitary()
    q_vp = random_unitary()
    q_vm = random_unitary()
    q_c0 = random_unitary()
    q_cp = random_unitary()
    q_cm = random_unitary()
    rotated = block_derivative(
        q_v0' * forward_valence * q_vp,
        q_vp' * forward_insertion * q_cp,
        q_cp' * forward_conduction * q_c0,
        q_v0' * backward_valence * q_vm,
        q_vm' * backward_insertion * q_cm,
        q_cm' * backward_conduction * q_c0,
        q_v0' * central_insertion * q_c0,
        q_v0' * valence_connection * q_v0,
        q_c0' * conduction_connection * q_c0,
    )
    @test rotated ≈ q_v0' * reference * q_c0 rtol = 1.0e-10 atol = 1.0e-12

    # A two-band (one V and one C) calculation must equal the same active pair
    # embedded in a six-band space whose spectator entries are NaN sentinels.
    scalar_arguments = ntuple(_ -> randn(rng, ComplexF64, 1, 1), 9)
    two_band_result = block_derivative(scalar_arguments...)
    embedded = ntuple(_ -> fill(ComplexF64(NaN, NaN), 6, 6), 9)
    valence_index = 2:2
    conduction_index = 4:4
    embedded[1][valence_index, valence_index] .= scalar_arguments[1]
    embedded[2][valence_index, conduction_index] .= scalar_arguments[2]
    embedded[3][conduction_index, conduction_index] .= scalar_arguments[3]
    embedded[4][valence_index, valence_index] .= scalar_arguments[4]
    embedded[5][valence_index, conduction_index] .= scalar_arguments[5]
    embedded[6][conduction_index, conduction_index] .= scalar_arguments[6]
    embedded[7][valence_index, conduction_index] .= scalar_arguments[7]
    embedded[8][valence_index, valence_index] .= scalar_arguments[8]
    embedded[9][conduction_index, conduction_index] .= scalar_arguments[9]
    embedded_result = block_derivative(
        @view(embedded[1][valence_index, valence_index]),
        @view(embedded[2][valence_index, conduction_index]),
        @view(embedded[3][conduction_index, conduction_index]),
        @view(embedded[4][valence_index, valence_index]),
        @view(embedded[5][valence_index, conduction_index]),
        @view(embedded[6][conduction_index, conduction_index]),
        @view(embedded[7][valence_index, conduction_index]),
        @view(embedded[8][valence_index, valence_index]),
        @view(embedded[9][conduction_index, conduction_index]),
    )
    @test embedded_result == two_band_result
    @test_throws ErrorException WCC_RESPONSES.compute_geometric_loop_block_covariant_insertion_derivative!(
        zeros(ComplexF64, 1, 1),
        scalar_arguments...,
        zeros(ComplexF64, 1, 1),
        zeros(ComplexF64, 1, 1),
        zeros(ComplexF64, 1, 1),
        zeros(ComplexF64, 1, 1),
        NaN,
    )
end

@testset "Geometric block workspace spectator sentinels" begin
    rng = MersenneTwister(0x5eec7a70)
    num_orbitals = 6
    spatial_dimension = 2
    lattice = Matrix{Float64}(I, 3, 3)
    r_vectors = zeros(Int, 3, 1)
    hamiltonian = zeros(ComplexF64, num_orbitals, num_orbitals, 1)
    hamiltonian[:, :, 1] .= Diagonal(collect(range(-2.0, 2.0; length = num_orbitals)))
    position = zeros(ComplexF64, num_orbitals, num_orbitals, 3, 1)
    model = WCC_CORE.TightBindingModel(
        lattice,
        num_orbitals,
        1,
        ones(Int, 1),
        r_vectors,
        hamiltonian,
        position,
    )
    request = WCC_MATRIX.MatrixElementRequest(WCC_MATRIX.BERRY_CONNECTION; spatial_dimension)
    plan =
        WCC_MATRIX.compile_matrix_plan(request; wannier_center_convention = WCC_CORE.CONVENTION_II)
    matrix_workspace = WCC_MATRIX.MatrixElementWorkspace(model, plan)
    ws = WCC_RESPONSES.make_geometric_loop_response_workspace(
        num_orbitals,
        model.num_r_vectors,
        spatial_dimension,
        1;
        matrix_elements = matrix_workspace,
    )
    valence_range = 2:3
    conduction_range = 4:5
    for data in (ws.valence_central_data, ws.conduction_central_data)
        data.degeneracy_group_starts .= 1:num_orbitals
        data.degeneracy_group_stops .= 1:num_orbitals
    end
    ws.valence_central_data.degeneracy_group_starts[valence_range] .= first(valence_range)
    ws.valence_central_data.degeneracy_group_stops[valence_range] .= last(valence_range)
    ws.conduction_central_data.degeneracy_group_starts[conduction_range] .= first(conduction_range)
    ws.conduction_central_data.degeneracy_group_stops[conduction_range] .= last(conduction_range)

    for matrix in
        (ws.forward_overlap_1, ws.forward_overlap_3, ws.backward_overlap_1, ws.backward_overlap_3)
        matrix .= randn(rng, ComplexF64, size(matrix))
    end
    for tensor in (
        ws.forward_third_insertions,
        ws.backward_third_insertions,
        ws.central_third_insertions,
        ws.valence_source_external_connection,
        ws.conduction_source_external_connection,
    )
        tensor .= randn(rng, ComplexF64, size(tensor))
    end
    sentinel = ComplexF64(NaN, NaN)
    fill!(ws.forward_transported_insertions, sentinel)
    fill!(ws.backward_transported_insertions, sentinel)
    fill!(ws.covariant_insertion_derivatives, sentinel)
    fill!(ws.transport_temporary_1, sentinel)
    fill!(ws.transport_temporary_2, sentinel)
    fill!(ws.covariant_derivative_valid, false)
    ws.covariant_derivative_axis = 1

    h = 4.0e-4
    @views oracle =
        (
            ws.forward_overlap_1[valence_range, valence_range] *
            ws.forward_third_insertions[valence_range, conduction_range, 1] *
            ws.forward_overlap_3[conduction_range, conduction_range] -
            ws.backward_overlap_1[valence_range, valence_range] *
            ws.backward_third_insertions[valence_range, conduction_range, 1] *
            ws.backward_overlap_3[conduction_range, conduction_range]
        ) / (2h) -
        1.0im *
        ws.valence_source_external_connection[valence_range, valence_range, 1] *
        ws.central_third_insertions[valence_range, conduction_range, 1] +
        1.0im *
        ws.central_third_insertions[valence_range, conduction_range, 1] *
        ws.conduction_source_external_connection[conduction_range, conduction_range, 1]
    WCC_RESPONSES.prepare_geometric_loop_covariant_derivative_block!(
        ws,
        1,
        first(valence_range),
        first(conduction_range),
        (1,),
        h,
    )
    result = copy(@view ws.covariant_insertion_derivatives[valence_range, conduction_range, 1])
    @test result ≈ oracle rtol = 1.0e-10 atol = 1.0e-12
    @test ws.covariant_derivative_valid[first(valence_range), first(conduction_range), 1]
    for column in 1:num_orbitals, row in 1:num_orbitals
        if !(row in valence_range && column in conduction_range)
            @test isnan(real(ws.covariant_insertion_derivatives[row, column, 1]))
        end
    end

    # Only spectator entries change; the cached block is recomputed and must be exact.
    for matrix in
        (ws.forward_overlap_1, ws.forward_overlap_3, ws.backward_overlap_1, ws.backward_overlap_3)
        for column in axes(matrix, 2), row in axes(matrix, 1)
            active =
                (matrix === ws.forward_overlap_1 || matrix === ws.backward_overlap_1) ?
                (row in valence_range && column in valence_range) :
                (row in conduction_range && column in conduction_range)
            active || (matrix[row, column] = randn(rng, ComplexF64))
        end
    end
    for (tensor, rows, columns) in (
        (ws.forward_third_insertions, valence_range, conduction_range),
        (ws.backward_third_insertions, valence_range, conduction_range),
        (ws.central_third_insertions, valence_range, conduction_range),
        (ws.valence_source_external_connection, valence_range, valence_range),
        (ws.conduction_source_external_connection, conduction_range, conduction_range),
    )
        for direction in axes(tensor, 3), column in axes(tensor, 2), row in axes(tensor, 1)
            (row in rows && column in columns) ||
                (tensor[row, column, direction] = randn(rng, ComplexF64))
        end
    end
    fill!(ws.covariant_derivative_valid, false)
    WCC_RESPONSES.prepare_geometric_loop_covariant_derivative_block!(
        ws,
        1,
        first(valence_range),
        first(conduction_range),
        (1,),
        h,
    )
    @test @view(ws.covariant_insertion_derivatives[valence_range, conduction_range, 1]) == result
end

@testset "q=0 Geometric to Wilson block reduction" begin
    base_model, base_centers = wcc_synthetic_model()

    function embedded_spectator_model(model, centers)
        num_orbitals = 6
        hamiltonian = zeros(ComplexF64, num_orbitals, num_orbitals, model.num_r_vectors)
        position = zeros(ComplexF64, num_orbitals, num_orbitals, 3, model.num_r_vectors)
        hamiltonian[3:4, 3:4, :] .= model.hamiltonian_r
        position[3:4, 3:4, :, :] .= model.position_r
        home =
            findfirst(index -> all(iszero, @view(model.r_vectors[:, index])), 1:model.num_r_vectors)
        spectator_energies = (-6.0, -5.0, 5.0, 6.0)
        spectator_orbitals = (1, 2, 5, 6)
        embedded_centers = zeros(Float64, 3, num_orbitals)
        embedded_centers[:, 3:4] .= centers
        embedded_centers[:, 1] .= (0.11, -0.07, 0.03)
        embedded_centers[:, 2] .= (-0.19, 0.13, -0.05)
        embedded_centers[:, 5] .= (0.29, -0.17, 0.09)
        embedded_centers[:, 6] .= (-0.31, 0.23, -0.11)
        for (orbital, energy) in zip(spectator_orbitals, spectator_energies)
            hamiltonian[orbital, orbital, home] = energy
        end
        for direction in 1:3, orbital in spectator_orbitals
            position[orbital, orbital, direction, home] = embedded_centers[direction, orbital]
        end
        embedded_model = WCC_CORE.TightBindingModel(
            model.lattice,
            num_orbitals,
            model.num_r_vectors,
            model.r_degeneracies,
            model.r_vectors,
            hamiltonian,
            position,
        )
        return embedded_model, embedded_centers
    end

    function reduction_terms(model, centers_cartesian, valence_band, conduction_band, h)
        centers_fractional = similar(centers_cartesian)
        for orbital in 1:model.num_orbitals
            centers_fractional[:, orbital] .= WCC_CORE.real_space_cartesian_to_fractional(
                @view(centers_cartesian[:, orbital]),
                model.lattice,
            )
        end
        kpoint = [0.173, 0.281, 0.0]
        finite_difference_vectors = WCC_CORE.finite_difference_step_matrix(model, h)[:, 1:2]
        component = Int[1, 1, 2]
        regularization = 1.0e-6
        degeneracy_threshold = 1.0e-10

        geometric_plan = WCC_MATRIX.compile_matrix_plan(
            WCC_MATRIX.MatrixElementRequest(WCC_MATRIX.VELOCITY_VERTICES; spatial_dimension = 2);
            wannier_center_convention = WCC_CORE.CONVENTION_II,
        )
        geometric = WCC_RESPONSES.make_geometric_loop_response_workspace(
            model.num_orbitals,
            model.num_r_vectors,
            2,
            1;
            matrix_elements = WCC_MATRIX.MatrixElementWorkspace(model, geometric_plan),
        )
        WCC_MATRIX.prepare_real_space!(geometric.scratch.matrix_elements, model)
        for data in (geometric.valence_central_data, geometric.conduction_central_data)
            WCC_MATRIX.compute_kpoint!(
                data,
                geometric.scratch,
                model,
                kpoint;
                denominator_regularization = regularization,
                spatial_dimension = 2,
            )
            WCC_MATRIX.mark_degenerate_groups!(data, degeneracy_threshold)
        end
        WCC_RESPONSES.compute_geometric_loop_shift_current_kernel!(
            geometric,
            kpoint,
            zeros(3),
            finite_difference_vectors,
            centers_fractional,
            regularization,
            h,
            2,
            model,
            1,
            model.num_orbitals;
            tensor_indices = component,
        )

        wilson_plan = WCC_MATRIX.compile_matrix_plan(
            WCC_MATRIX.MatrixElementRequest(WCC_MATRIX.BERRY_CONNECTION; spatial_dimension = 2);
            wannier_center_convention = WCC_CORE.CONVENTION_II,
        )
        wilson = WCC_RESPONSES.make_wilson_loop_response_workspace(
            model.num_orbitals,
            model.num_r_vectors,
            2,
            1;
            matrix_elements = WCC_MATRIX.MatrixElementWorkspace(model, wilson_plan),
        )
        WCC_MATRIX.prepare_real_space!(wilson.scratch.matrix_elements, model)
        WCC_RESPONSES.prepare_wilson_loop_response_cache!(
            wilson,
            kpoint,
            finite_difference_vectors,
            centers_fractional,
            model,
            2;
            denominator_regularization = regularization,
            degeneracy_threshold,
            axes = Int[1],
        )
        WCC_RESPONSES.compute_wilson_loop_shift_current_from_cache!(
            wilson.response_kernel,
            wilson,
            1,
            model.num_orbitals,
            h,
            2;
            tensor_indices = component,
        )
        delta =
            geometric.conduction_central_data.spectrum.energies[conduction_band] -
            geometric.valence_central_data.spectrum.energies[valence_band]
        geometric_kernel = geometric.response_kernel[valence_band, conduction_band, 1, 1, 2]
        wilson_kernel = wilson.response_kernel[valence_band, conduction_band, 1, 1, 2]
        # P_W / P_G = -1/2 after hbar_J = e*hbar_eV is inserted.
        lhs = geometric_kernel / delta^2
        rhs = -0.5 * wilson_kernel
        normalized_error = abs(lhs - rhs) / max(abs(rhs), eps(Float64))
        return (; lhs, rhs, normalized_error)
    end

    embedded_model, embedded_centers = embedded_spectator_model(base_model, base_centers)
    steps = (2.0e-2, 1.0e-2, 5.0e-3, 2.5e-3)
    for (model, centers, valence_band, conduction_band) in
        ((base_model, base_centers, 1, 2), (embedded_model, embedded_centers, 3, 4))
        results = [reduction_terms(model, centers, valence_band, conduction_band, h) for h in steps]
        errors = [result.normalized_error for result in results]
        observed_orders = log2.(errors[1:3] ./ errors[2:4])
        @test all(1.8 .<= observed_orders .<= 2.2)
        @test errors[end] <= 1.0e-5
    end
end

@testset "Geometric aligned external connection oracle" begin
    rng = MersenneTwister(0xa11e6ed)
    model, centers_cartesian = wcc_synthetic_model()
    centers_fractional = similar(centers_cartesian)
    for orbital in 1:model.num_orbitals
        centers_fractional[:, orbital] .= WCC_CORE.real_space_cartesian_to_fractional(
            @view(centers_cartesian[:, orbital]),
            model.lattice,
        )
    end
    request = WCC_MATRIX.MatrixElementRequest(WCC_MATRIX.BERRY_CONNECTION; spatial_dimension = 2)
    plan =
        WCC_MATRIX.compile_matrix_plan(request; wannier_center_convention = WCC_CORE.CONVENTION_II)
    matrix_workspace = WCC_MATRIX.MatrixElementWorkspace(model, plan)
    ws = WCC_RESPONSES.make_geometric_loop_response_workspace(
        model.num_orbitals,
        model.num_r_vectors,
        2,
        1;
        matrix_elements = matrix_workspace,
    )
    data = ws.valence_central_data
    unitary = Matrix(qr(randn(rng, ComplexF64, model.num_orbitals, model.num_orbitals)).Q)
    data.spectrum.source_eigenvectors .= unitary
    data.spectrum.source_eigenvectors_adjoint .= unitary'
    source_connection = randn(rng, ComplexF64, model.num_orbitals, model.num_orbitals, 2)
    source_hamiltonian_derivatives =
        randn(rng, ComplexF64, model.num_orbitals, model.num_orbitals, 2)
    inverse_energy_differences = randn(rng, model.num_orbitals, model.num_orbitals)
    data.source_gauge_berry_connection .= source_connection
    data.source_gauge_hamiltonian_derivatives .= source_hamiltonian_derivatives
    data.inverse_energy_differences .= inverse_energy_differences
    WCC_RESPONSES.prepare_geometric_source_external_connection!(
        ws.valence_source_external_connection,
        data,
        ws.frame_connector,
        centers_fractional,
        model,
        ws.frame_rotated_eigenvectors,
        ws.frame_generator_band,
        1:2,
    )
    for direction in 1:2
        center_cartesian =
            model.lattice[1, direction] .* centers_fractional[1, :] .+
            model.lattice[2, direction] .* centers_fractional[2, :] .+
            model.lattice[3, direction] .* centers_fractional[3, :]
        oracle =
            source_connection[:, :, direction] .+
            1.0im .* source_hamiltonian_derivatives[:, :, direction] .* inverse_energy_differences .-
            unitary' * Diagonal(center_cartesian) * unitary
        @test ws.valence_source_external_connection[:, :, direction] ≈ oracle rtol = 1.0e-10 atol =
            1.0e-12
    end
end

@testset "Full Geometric convention covariance at zero and finite q" begin
    model, centers_cartesian = wcc_synthetic_model()
    centers_fractional = similar(centers_cartesian)
    for orbital in 1:model.num_orbitals
        centers_fractional[:, orbital] .= WCC_CORE.real_space_cartesian_to_fractional(
            @view(centers_cartesian[:, orbital]),
            model.lattice,
        )
    end
    kpoint = [0.173, 0.281, 0.0]
    step = 1.0e-4
    finite_difference_vectors = WCC_CORE.finite_difference_step_matrix(model, step)[:, 1:2]
    request = WCC_MATRIX.MatrixElementRequest(WCC_MATRIX.VELOCITY_VERTICES; spatial_dimension = 2)

    for photon_momentum in ([0.0, 0.0, 0.0], [0.005, 0.0, 0.0], [0.0, 0.005, 0.0])
        kernels = map((WCC_CORE.CONVENTION_I, WCC_CORE.CONVENTION_II)) do convention
            plan = WCC_MATRIX.compile_matrix_plan(request; wannier_center_convention = convention)
            matrix_workspace = WCC_MATRIX.MatrixElementWorkspace(model, plan)
            ws = WCC_RESPONSES.make_geometric_loop_response_workspace(
                model.num_orbitals,
                model.num_r_vectors,
                2,
                1;
                matrix_elements = matrix_workspace,
            )
            WCC_MATRIX.prepare_real_space!(ws.scratch.matrix_elements, model)
            WCC_MATRIX.compute_kpoint!(
                ws.valence_central_data,
                ws.scratch,
                model,
                kpoint - 0.5 * photon_momentum;
                denominator_regularization = 1.0e-3,
                spatial_dimension = 2,
            )
            WCC_MATRIX.compute_kpoint!(
                ws.conduction_central_data,
                ws.scratch,
                model,
                kpoint + 0.5 * photon_momentum;
                denominator_regularization = 1.0e-3,
                spatial_dimension = 2,
            )
            WCC_MATRIX.mark_degenerate_groups!(ws.valence_central_data, 1.0e-8)
            WCC_MATRIX.mark_degenerate_groups!(ws.conduction_central_data, 1.0e-8)
            WCC_RESPONSES.compute_geometric_loop_shift_current_kernel!(
                ws,
                kpoint,
                photon_momentum,
                finite_difference_vectors,
                centers_fractional,
                1.0e-3,
                step,
                2,
                model,
                1,
                model.num_orbitals,
            )
            shift_current = copy(ws.response_kernel)
            WCC_RESPONSES.compute_geometric_loop_quantum_hermitian_connection_kernel!(
                ws,
                kpoint,
                photon_momentum,
                finite_difference_vectors,
                centers_fractional,
                1.0e-3,
                step,
                2,
                model,
                ([2], [1]),
                1.0e-8,
            )
            quantum_hermitian_connection = copy(ws.response_kernel)
            WCC_RESPONSES.compute_geometric_loop_shift_vector_kernel!(
                ws,
                kpoint,
                photon_momentum,
                finite_difference_vectors,
                centers_fractional,
                1.0e-3,
                step,
                2,
                model,
                1,
                model.num_orbitals,
            )
            shift_vector = copy(ws.response_kernel)
            (; shift_current, quantum_hermitian_connection, shift_vector)
        end
        @test kernels[1].shift_current ≈ kernels[2].shift_current rtol = 2.0e-6 atol = 1.0e-8
        @test kernels[1].quantum_hermitian_connection ≈ kernels[2].quantum_hermitian_connection rtol =
            2.0e-6 atol = 1.0e-8
        # Runtime consumes the selected conduction=2, valence=1 transition.
        # Diagonal loops are outside this observable and can sit on opposite
        # sides of the established principal-log branch cut.
        @test kernels[1].shift_vector[2, 1, :, :, :] ≈ kernels[2].shift_vector[2, 1, :, :, :] rtol =
            2.0e-6 atol = 1.0e-8
    end

    convention_i_plan =
        WCC_MATRIX.compile_matrix_plan(request; wannier_center_convention = WCC_CORE.CONVENTION_I)
    ws = WCC_RESPONSES.make_geometric_loop_response_workspace(
        model.num_orbitals,
        model.num_r_vectors,
        2,
        1;
        matrix_elements = WCC_MATRIX.MatrixElementWorkspace(model, convention_i_plan),
    )
    WCC_MATRIX.prepare_real_space!(ws.scratch.matrix_elements, model)
    WCC_MATRIX.compute_kpoint!(
        ws.valence_central_data,
        ws.scratch,
        model,
        kpoint;
        denominator_regularization = 1.0e-3,
        spatial_dimension = 2,
    )
    WCC_MATRIX.compute_kpoint!(
        ws.conduction_central_data,
        ws.scratch,
        model,
        kpoint;
        denominator_regularization = 1.0e-3,
        spatial_dimension = 2,
    )
    bad_centers = copy(centers_fractional)
    bad_centers[1, 1] = Inf
    @test_throws ErrorException WCC_RESPONSES.compute_geometric_loop_shift_current_kernel!(
        ws,
        kpoint,
        zeros(3),
        finite_difference_vectors,
        bad_centers,
        1.0e-3,
        step,
        2,
        model,
        1,
        model.num_orbitals,
    )
end

@testset "Wilson full-cache convention covariance" begin
    model, centers_cartesian = wcc_synthetic_model()
    centers_fractional = similar(centers_cartesian)
    for orbital in 1:model.num_orbitals
        centers_fractional[:, orbital] .= WCC_CORE.real_space_cartesian_to_fractional(
            @view(centers_cartesian[:, orbital]),
            model.lattice,
        )
    end
    step = 1.0e-4
    finite_difference_vectors = WCC_CORE.finite_difference_step_matrix(model, step)[:, 1:2]
    kernels = map((WCC_CORE.CONVENTION_I, WCC_CORE.CONVENTION_II)) do convention
        request =
            WCC_MATRIX.MatrixElementRequest(WCC_MATRIX.BERRY_CONNECTION; spatial_dimension = 2)
        plan = WCC_MATRIX.compile_matrix_plan(request; wannier_center_convention = convention)
        matrix_workspace = WCC_MATRIX.MatrixElementWorkspace(model, plan)
        ws = WCC_RESPONSES.make_wilson_loop_response_workspace(
            model.num_orbitals,
            model.num_r_vectors,
            2,
            1;
            matrix_elements = matrix_workspace,
        )
        WCC_MATRIX.prepare_real_space!(ws.scratch.matrix_elements, model)
        WCC_RESPONSES.prepare_wilson_loop_response_cache!(
            ws,
            [0.173, 0.281, 0.0],
            finite_difference_vectors,
            centers_fractional,
            model,
            2;
            denominator_regularization = 1.0e-3,
            degeneracy_threshold = 1.0e-8,
        )
        WCC_RESPONSES.compute_wilson_loop_shift_current_from_cache!(
            ws.response_kernel,
            ws,
            1,
            model.num_orbitals,
            step,
            2,
        )
        copy(ws.response_kernel)
    end
    # Full-cache data include two independent eigensolves and a 1/h subtraction.
    # Compare only the interband entries consumed by occupations; the paired-array
    # representation oracle above retains the strict 1e-10/1e-12 contract.
    for n in 1:model.num_orbitals, m in 1:model.num_orbitals
        n == m && continue
        @test kernels[1][n, m, :, :, :] ≈ kernels[2][n, m, :, :, :] rtol = 2.0e-6 atol = 1.0e-8
    end
end

@testset "Zero-center convention identity" begin
    model, _ = wcc_synthetic_model()
    zero_position = copy(model.position_r)
    home_index =
        findfirst(index -> all(iszero, @view(model.r_vectors[:, index])), 1:model.num_r_vectors)
    for direction in 1:3, orbital in 1:model.num_orbitals
        zero_position[orbital, orbital, direction, home_index] = 0.0 + 0.0im
    end
    zero_center_model = WCC_CORE.TightBindingModel(
        model.lattice,
        model.num_orbitals,
        model.num_r_vectors,
        model.r_degeneracies,
        model.r_vectors,
        model.hamiltonian_r,
        zero_position,
    )
    request = WCC_MATRIX.MatrixElementRequest(
        WCC_MATRIX.HAMILTONIAN_DERIVATIVES,
        WCC_MATRIX.HAMILTONIAN_SECOND_DERIVATIVES,
        WCC_MATRIX.INTERNAL_CONNECTION_DERIVATIVES;
        spatial_dimension = 2,
    )
    workspaces = map((WCC_CORE.CONVENTION_I, WCC_CORE.CONVENTION_II)) do convention
        plan = WCC_MATRIX.compile_matrix_plan(request; wannier_center_convention = convention)
        workspace = WCC_MATRIX.MatrixElementWorkspace(zero_center_model, plan)
        WCC_MATRIX.prepare_real_space!(workspace, zero_center_model)
        WCC_MATRIX.compute_kpoint!(workspace, zero_center_model, [0.173, 0.281, 0.0])
        workspace
    end
    @test maximum(
        abs,
        workspaces[1].scratch.hamiltonian_wannier - workspaces[2].scratch.hamiltonian_wannier,
    ) <= 1.0e-12
    @test maximum(
        abs,
        workspaces[1].scratch.hamiltonian.gradient_wannier -
        workspaces[2].scratch.hamiltonian.gradient_wannier,
    ) <= 1.0e-12
    @test maximum(
        abs,
        workspaces[1].scratch.position.wannier_gauge - workspaces[2].scratch.position.wannier_gauge,
    ) <= 1.0e-12
end

@testset "Wannier-center source failures" begin
    model, centers = wcc_synthetic_model()
    checkpoint = WCC_IO.WannierCHK(
        2,
        2,
        1,
        (1, 1, 1),
        zeros(1, 3),
        copy(model.lattice),
        2.0 * pi * inv(model.lattice),
        Matrix(transpose(centers)),
        reshape(Matrix{ComplexF64}(I, 2, 2), 2, 2, 1),
    )
    @test isnothing(WCC_RUNTIME.validate_wannier_center_sources(model, checkpoint))

    translated = copy(checkpoint.wannier_centers_cart)
    translated[1, :] .+= model.lattice[1, :]
    translated_checkpoint = WCC_IO.WannierCHK(
        2,
        2,
        1,
        (1, 1, 1),
        zeros(1, 3),
        copy(model.lattice),
        2.0 * pi * inv(model.lattice),
        translated,
        reshape(Matrix{ComplexF64}(I, 2, 2), 2, 2, 1),
    )
    @test isnothing(WCC_RUNTIME.validate_wannier_center_sources(model, translated_checkpoint))

    reordered = copy(checkpoint.wannier_centers_cart)
    reordered[[1, 2], :] .= reordered[[2, 1], :]
    reordered_checkpoint = WCC_IO.WannierCHK(
        2,
        2,
        1,
        (1, 1, 1),
        zeros(1, 3),
        copy(model.lattice),
        2.0 * pi * inv(model.lattice),
        reordered,
        reshape(Matrix{ComplexF64}(I, 2, 2), 2, 2, 1),
    )
    @test_throws ErrorException WCC_RUNTIME.validate_wannier_center_sources(
        model,
        reordered_checkpoint,
    )

    orbital_count_checkpoint = WCC_IO.WannierCHK(
        1,
        1,
        1,
        (1, 1, 1),
        zeros(1, 3),
        copy(model.lattice),
        2.0 * pi * inv(model.lattice),
        zeros(1, 3),
        ones(ComplexF64, 1, 1, 1),
    )
    @test_throws ErrorException WCC_RUNTIME.validate_wannier_center_sources(
        model,
        orbital_count_checkpoint,
    )

    bad_position = copy(model.position_r)
    bad_position[1, 1, 1, 2] = NaN + 0.0im
    bad_model = WCC_CORE.TightBindingModel(
        model.lattice,
        model.num_orbitals,
        model.num_r_vectors,
        model.r_degeneracies,
        model.r_vectors,
        model.hamiltonian_r,
        bad_position,
    )
    request = WCC_MATRIX.MatrixElementRequest(WCC_MATRIX.SPECTRUM; spatial_dimension = 2)
    plan =
        WCC_MATRIX.compile_matrix_plan(request; wannier_center_convention = WCC_CORE.CONVENTION_I)
    @test_throws ErrorException WCC_MATRIX.prepare_real_space!(
        WCC_MATRIX.MatrixElementWorkspace(bad_model, plan),
        bad_model,
    )

    missing_home_model = WCC_CORE.TightBindingModel(
        model.lattice,
        model.num_orbitals,
        model.num_r_vectors,
        model.r_degeneracies,
        Int[-1 2 1; 0 0 0; 0 0 0],
        model.hamiltonian_r,
        model.position_r,
    )
    @test_throws ErrorException WCC_MATRIX.prepare_real_space!(
        WCC_MATRIX.MatrixElementWorkspace(missing_home_model, plan),
        missing_home_model,
    )
end
