using LinearAlgebra
using HDF5
using JSON3
using Test
using WannierNLQG

const SymmetryCore = WannierNLQG.Core
const SymmetryModule = WannierNLQG.Symmetrization

const EXPECTED_MATRIX_ELEMENTS_INTEGRATION_API = Set((
    :REAL_SPACE_REPLICA_MAP_DIGEST_SCHEME,
    :MatrixElementDirectionRequirements,
    :RealSpaceReplicaMap,
    :SerializedWannier90ReplicaValues,
    :SharedInterpolationCache,
    :begin_shared_interpolation!,
    :with_shared_interpolation,
    :shared_interpolation_stats,
    :apply_wannier_center_phases!,
    :compute_spin_velocity_real_space_streaming_with_transform,
    :compute_spin_velocity_real_space_with_transform,
    :compute_loop_overlap!,
    :derive_axial_and_symmetric_derivative_overlaps,
    :hermitianize_real_space_pairs,
    :input_real_space_replica_map,
    :input_real_space_replica_mapping_sha256,
    :matrix_element_axis_required,
    :matrix_element_pair_required,
    :materialize_replica_component,
    :minimum_distance_real_space_replica_map,
    :mp_residue_grid,
    :real_space_replica_map_from_wsvec,
    :require_matrix_element_axes,
    :require_matrix_element_pairs,
    :transform_pair_wigner_seitz_spin_q_to_r,
    :unit_degeneracy_roundtrip_error,
    :wannier_centers_fractional,
    :wannier_q_to_pair_wigner_seitz,
))

# Detect qualified or explicitly imported MatrixElements private names in one source string.
function matrix_elements_private_references(source::AbstractString)
    references = String[]
    for match in
        eachmatch(r"\b(?:WannierNLQG\.)?MatrixElements\s*\.\s*(_[A-Za-z][A-Za-z0-9_!]*)", source)
        push!(references, match.captures[1])
    end
    import_pattern =
        r"(?ms)^\s*(?:using|import)\s+(?:WannierNLQG\.|\.\.)MatrixElements\s*:\s*(.*?)(?=^\S|\z)"
    for import_match in eachmatch(import_pattern, source)
        for name in eachmatch(r"\b_[A-Za-z][A-Za-z0-9_!]*\b", import_match.captures[1])
            push!(references, name.match)
        end
    end
    return sort!(unique!(references))
end

# Return the activated implementation module for internal adapter characterization tests.
function symmetrization_extension()
    extension, _ = WannierNLQG.Symmetrization._load_symmetrization_extension!()
    return extension
end

# Return the Wannierization-owned implementation for exact uIu characterization.
function exact_wannierization_extension()
    extension, _ = WannierNLQG.Wannierization._load_wannierization_extension!()
    return extension.OperatorExport
end

function identity_symmetry_plan(; antiunitary = false)
    identity_rotation = Matrix{Int}(I, 3, 3)
    operations = [
        WannierNLQG.SymmetryFoundation.SymmetryOperation(
            identity_rotation,
            zeros(3),
            Matrix{Float64}(I, 3, 3),
            false,
        ),
    ]
    antiunitary && push!(
        operations,
        WannierNLQG.SymmetryFoundation.SymmetryOperation(
            identity_rotation,
            zeros(3),
            Matrix{Float64}(I, 3, 3),
            true,
        ),
    )
    representations = ones(ComplexF64, 1, 1, length(operations))
    shifts = zeros(Int, 3, 1, length(operations))
    return WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(operations, representations, shifts)
end

function symmetry_write_fortran_record(io, values)
    bytes =
        values isa AbstractString ? Vector{UInt8}(codeunits(values)) :
        collect(reinterpret(UInt8, vec(values)))
    marker = UInt32(length(bytes))
    write(io, marker)
    write(io, bytes)
    write(io, marker)
    return nothing
end

function symmetry_replace_manifest(manifest; replacements...)
    fields = fieldnames(typeof(manifest))
    values = map(fields) do field
        haskey(replacements, field) ? replacements[field] : getfield(manifest, field)
    end
    return typeof(manifest)(values...)
end

@testset "MatrixElements Symmetrization integration boundary" begin
    matrix_elements = WannierNLQG.MatrixElements
    @test Set(matrix_elements.MATRIX_ELEMENTS_INTEGRATION_API) ==
          EXPECTED_MATRIX_ELEMENTS_INTEGRATION_API
    for name in matrix_elements.MATRIX_ELEMENTS_INTEGRATION_API
        @test isdefined(matrix_elements, name)
        @test !startswith(String(name), "_")
        @test name ∉ names(matrix_elements; all = false, imported = false)
    end
    @test Set(matrix_elements.MATRIX_ELEMENTS_TEST_API) == Set((:_axis_channel,))
    @test isempty(
        intersect(
            Set(matrix_elements.MATRIX_ELEMENTS_INTEGRATION_API),
            Set(matrix_elements.MATRIX_ELEMENTS_TEST_API),
        ),
    )
    for name in matrix_elements.MATRIX_ELEMENTS_TEST_API
        @test isdefined(matrix_elements, name)
        @test startswith(String(name), "_")
    end

    consumer_roots = (
        joinpath(@__DIR__, "..", "ext", "WannierNLQGSymmetrizationExt"),
        joinpath(@__DIR__, "..", "ext", "WannierNLQGWannierizationExt"),
        joinpath(@__DIR__, "..", "src", "Runtime"),
    )
    for consumer_root in consumer_roots
        for (root, _, files) in walkdir(consumer_root), filename in sort(files)
            endswith(filename, ".jl") || continue
            path = joinpath(root, filename)
            @test isempty(matrix_elements_private_references(read(path, String)))
        end
    end
    @test matrix_elements_private_references(
        "value = WannierNLQG.MatrixElements._hidden_transform(input)\n",
    ) == ["_hidden_transform"]
    @test matrix_elements_private_references(
        "import WannierNLQG.MatrixElements: allowed_port, _hidden_transform\n",
    ) == ["_hidden_transform"]
    @test matrix_elements_private_references(
        "import ..MatrixElements: allowed_port, _hidden_transform\n",
    ) == ["_hidden_transform"]
end

@testset "typed operator validation summary" begin
    validation = Dict(
        SymmetryModule.REAL_SPACE_HAMILTONIAN =>
            (covariance_error = 1.25e-12, idempotence_error = 2.5e-13),
    )
    result = SymmetryModule.SymmetrizationResult(
        "out_tb.dat",
        "operators.h5",
        "report.json",
        :hamiltonian,
        [SymmetryModule.REAL_SPACE_HAMILTONIAN],
        validation,
    )
    @test fieldtype(SymmetryModule.SymmetrizationResult, :validation) ==
          Dict{SymmetryModule.RealSpaceOperatorKind, SymmetryModule.OperatorValidationSummary}
    @test result.validation[SymmetryModule.REAL_SPACE_HAMILTONIAN].covariance_error == 1.25e-12
    json_validation = symmetrization_extension()._json_validation(result.validation)
    restored = JSON3.read(JSON3.write(json_validation))
    @test restored.hamiltonian.covariance_error == 1.25e-12
    @test restored.hamiltonian.idempotence_error == 2.5e-13
    mktempdir() do directory
        config = SymmetryModule.SymmetrizationConfig(
            win_file = "unused.win",
            tb_file = "unused.dat",
            output_tb_file = "unused-output.dat",
            output_real_space_operator_bundle_file = "unused.h5",
        )
        report = joinpath(directory, "report.json")
        symmetrization_extension()._write_symmetrization_report(
            config,
            report,
            Dict("validation" => json_validation),
        )
        report_payload = JSON3.read(read(report, String))
        @test report_payload.schema_version == "1.0"
        @test report_payload.validation.hamiltonian.covariance_error == 1.25e-12
    end
end

@testset "real-space symmetry projection" begin
    r_origin = zeros(Int, 3, 1)
    complex_scalar = reshape(ComplexF64[2.0 + 3.0im], 1, 1, 1)
    time_even = SymmetryModule.RealSpaceOperator(
        SymmetryModule.RealSpaceOperatorSymmetrySpec(
            SymmetryModule.REAL_SPACE_HAMILTONIAN,
            0,
            1,
            1,
        ),
        r_origin,
        complex_scalar,
    )
    grey_plan = identity_symmetry_plan(; antiunitary = true)
    projected_even =
        WannierNLQG.SymmetryFoundation.symmetrize_real_space_operator(time_even, grey_plan)
    @test projected_even.operator.data[1, 1, 1] == 2.0 + 0.0im
    @test WannierNLQG.SymmetryFoundation.maximum_real_space_covariance_error(
        projected_even.operator,
        grey_plan,
    ) == 0.0
    repeated_even = WannierNLQG.SymmetryFoundation.symmetrize_real_space_operator(
        projected_even.operator,
        grey_plan,
    )
    @test repeated_even.operator.r_vectors == projected_even.operator.r_vectors
    @test repeated_even.operator.data == projected_even.operator.data
    projection_context = WannierNLQG.SymmetryFoundation.RealSpaceProjectionContext(grey_plan)
    @test length(projection_context.representation_support) == 2
    context_result =
        WannierNLQG.SymmetryFoundation.symmetrize_real_space_operator(time_even, projection_context)
    @test context_result.operator.data == projected_even.operator.data
    @test WannierNLQG.SymmetryFoundation.maximum_real_space_covariance_error(
        context_result.operator,
        projection_context,
    ) == 0.0

    time_odd = SymmetryModule.RealSpaceOperator(
        SymmetryModule.RealSpaceOperatorSymmetrySpec(SymmetryModule.REAL_SPACE_SPIN, 0, 1, -1),
        r_origin,
        complex_scalar,
    )
    projected_odd =
        WannierNLQG.SymmetryFoundation.symmetrize_real_space_operator(time_odd, grey_plan)
    @test projected_odd.operator.data[1, 1, 1] == 0.0 + 3.0im

    inversion = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        -Matrix{Int}(I, 3, 3),
        zeros(3),
        -Matrix{Float64}(I, 3, 3),
        false,
    )
    identity = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
        false,
    )
    inversion_plan = WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
        [identity, inversion],
        ones(ComplexF64, 1, 1, 2),
        zeros(Int, 3, 1, 2),
    )
    one_sided = SymmetryModule.RealSpaceOperator(
        SymmetryModule.RealSpaceOperatorSymmetrySpec(
            SymmetryModule.REAL_SPACE_HAMILTONIAN,
            0,
            1,
            1,
        ),
        reshape(Int[1, 0, 0], 3, 1),
        reshape(ComplexF64[4.0], 1, 1, 1),
    )
    inversion_result =
        WannierNLQG.SymmetryFoundation.symmetrize_real_space_operator(one_sided, inversion_plan)
    @test Set(
        Tuple(inversion_result.operator.r_vectors[:, index]) for
        index in axes(inversion_result.operator.r_vectors, 2)
    ) == Set([(1, 0, 0), (-1, 0, 0)])
    @test all(==(2.0 + 0.0im), inversion_result.operator.data)
    @test WannierNLQG.SymmetryFoundation.maximum_real_space_covariance_error(
        inversion_result.operator,
        inversion_plan,
    ) == 0.0
end

@testset "pair-dependent Wannier WS transform plan reuse" begin
    chk = WannierNLQG.IO.WannierCHK(
        1,
        1,
        1,
        (1, 1, 1),
        zeros(1, 3),
        Matrix{Float64}(I, 3, 3),
        2.0pi * Matrix{Float64}(I, 3, 3),
        zeros(1, 3),
        ones(ComplexF64, 1, 1, 1),
    )
    target_r_vectors = zeros(Int, 3, 1)
    transform_plan = WannierNLQG.MatrixElements.WannierPairWignerSeitzTransformPlan(
        chk,
        target_r_vectors;
        wigner_seitz_tolerance = 1.0e-5,
        search_size = 1,
    )
    vector_values = reshape(ComplexF64[1, 2, 3], 1, 1, 3, 1)
    tensor_values = reshape(ComplexF64.(1:9), 1, 1, 3, 3, 1)
    vector_output = WannierNLQG.MatrixElements.wannier_q_to_pair_wigner_seitz(
        vector_values,
        chk,
        transform_plan;
        support_tolerance = 0.0,
        label = "vector",
    )
    tensor_output = WannierNLQG.MatrixElements.wannier_q_to_pair_wigner_seitz(
        tensor_values,
        chk,
        transform_plan;
        support_tolerance = 0.0,
        label = "tensor",
    )
    @test vector_output == vector_values
    @test tensor_output == tensor_values
    @test transform_plan.wigner_seitz_images[1, 1, 1] == [(0, 0, 0)]
    @test transform_plan.retained_target_indices[1, 1, 1] == [1]
end

@testset "Wannier90 get_FF_R uIu construction oracle" begin
    wannierization_extension = exact_wannierization_extension()
    chk = WannierNLQG.IO.WannierCHK(
        2,
        2,
        1,
        (1, 1, 1),
        zeros(1, 3),
        Matrix{Float64}(I, 3, 3),
        2.0pi * Matrix{Float64}(I, 3, 3),
        zeros(2, 3),
        reshape(Matrix{ComplexF64}(I, 2, 2), 2, 2, 1),
    )
    weights = [0.75, 1.25]
    displacements = [1.0 0.0 0.0; 0.0 -2.0 0.5]
    stencil = WannierNLQG.MatrixElements.FiniteDifferenceStencil(
        weights,
        round.(Int, displacements),
        displacements,
        ones(Int, 2, 1),
        zeros(Int, 3, 2, 1),
        zeros(Int, 2, 1),
    )
    direct = Dict{Tuple{Int, Int}, Matrix{ComplexF64}}(
        (1, 1) => ComplexF64[1.0 0.3-0.1im; 0.3+0.1im 0.7],
        (2, 2) => ComplexF64[0.8 -0.4+0.05im; -0.4-0.05im 1.2],
    )
    direct[(1, 2)] = ComplexF64[0.2+0.3im -0.7+0.1im; 0.4-0.2im 0.6+0.05im]
    direct[(2, 1)] = direct[(1, 2)]'
    mktempdir() do directory
        path = joinpath(directory, "get-FF-R-oracle.uIu")
        open(path, "w") do io
            symmetry_write_fortran_record(io, rpad("get_FF_R oracle", 60))
            symmetry_write_fortran_record(io, Int32[2, 1, 2])
            for second in 1:2, first in 1:2
                # The standard file stores the pre-get_FF_R-transpose matrix.
                symmetry_write_fortran_record(io, transpose(direct[(second, first)]))
            end
        end
        actual = wannierization_extension._construct_exact_full_derivative_overlap_tensor_q(
            chk,
            stencil,
            chk.wannier_centers_cart,
            path,
        )
        expected = zeros(ComplexF64, 2, 2, 3, 3, 1)
        for second in 1:2, first in 1:2, beta in 1:3, alpha in 1:beta
            expected[:, :, alpha, beta, 1] .+=
                weights[first] *
                weights[second] *
                displacements[first, alpha] *
                displacements[second, beta] .* direct[(second, first)]
        end
        for beta in 1:3, alpha in 1:beta
            expected[:, :, beta, alpha, 1] .= copy(adjoint(expected[:, :, alpha, beta, 1]))
        end
        @test actual ≈ expected atol = 1.0e-14 rtol = 1.0e-14
        for alpha in 1:3, beta in 1:3
            @test actual[:, :, alpha, beta, 1]' ≈ actual[:, :, beta, alpha, 1] atol = 1.0e-14 rtol =
                1.0e-14
        end
    end
end

@testset "pair-dependent spin WS image assignment" begin
    kpoints = [0.0 0.0 0.0; 0.5 0.0 0.0]
    centers = [0.0 0.0 0.0; 0.4 0.0 0.0]
    v_matrix = zeros(ComplexF64, 2, 2, 2)
    for kpoint in 1:2
        v_matrix[:, :, kpoint] .= Matrix{ComplexF64}(I, 2, 2)
    end
    chk = WannierNLQG.IO.WannierCHK(
        2,
        2,
        2,
        (2, 1, 1),
        kpoints,
        Matrix{Float64}(I, 3, 3),
        2.0pi * Matrix{Float64}(I, 3, 3),
        centers,
        v_matrix,
    )
    target_r_vectors = [
        -1 0 1
        0 0 0
        0 0 0
    ]
    plan = WannierNLQG.MatrixElements.WannierPairWignerSeitzTransformPlan(
        chk,
        target_r_vectors;
        wigner_seitz_tolerance = 1.0e-5,
        search_size = 1,
    )
    @test plan.wigner_seitz_images[1, 2, 2] == [(-1, 0, 0)]
    @test plan.wigner_seitz_images[2, 1, 2] == [(1, 0, 0)]
    @test plan.wigner_seitz_images[1, 1, 2] == [(-1, 0, 0), (1, 0, 0)]

    spin_q = zeros(ComplexF64, 2, 2, 3, 2)
    spin_q[1, 2, 1, :] .= (1.0, -1.0)
    spin_q[2, 1, 1, :] .= (2.0, -2.0)
    spin_q[1, 1, 1, :] .= (3.0, -3.0)
    transform =
        WannierNLQG.MatrixElements.PairWignerSeitzSpinQToRTransform(chk, plan, 0.0, 1.0e-12, true)
    spin_result =
        WannierNLQG.MatrixElements.transform_pair_wigner_seitz_spin_q_to_r(transform, spin_q, "SS")
    spin_r = spin_result.real_space_values
    @test spin_r[1, 2, 1, :] ≈ ComplexF64[1.0, 0.0, 0.0] atol = 1.0e-15
    @test spin_r[2, 1, 1, :] ≈ ComplexF64[0.0, 0.0, 2.0] atol = 1.0e-15
    @test spin_r[1, 1, 1, :] ≈ ComplexF64[1.5, 0.0, 1.5] atol = 1.0e-15
    @test sum(spin_r[1, 1, 1, :]) ≈ 3.0 + 0.0im atol = 1.0e-15
    @test spin_result.diagnostics.max_roundtrip_error <= 1.0e-12

    tensor_q = zeros(ComplexF64, 2, 2, 3, 3, 2)
    tensor_q[1, 2, 2, 3, :] .= (4.0, -4.0)
    tensor_result = WannierNLQG.MatrixElements.transform_pair_wigner_seitz_spin_q_to_r(
        transform,
        tensor_q,
        "SR",
    )
    @test tensor_result.real_space_values[1, 2, 2, 3, :] ≈ ComplexF64[4.0, 0.0, 0.0] atol = 1.0e-15
    @test tensor_result.diagnostics.max_roundtrip_error <= 1.0e-12

    missing_plan = WannierNLQG.MatrixElements.WannierPairWignerSeitzTransformPlan(
        chk,
        zeros(Int, 3, 1);
        wigner_seitz_tolerance = 1.0e-5,
        search_size = 1,
    )
    @test_throws ArgumentError WannierNLQG.MatrixElements.wannier_q_to_pair_wigner_seitz(
        spin_q,
        chk,
        missing_plan;
        support_tolerance = 0.0,
        label = "SS",
    )
end

@testset "nonsymmorphic Wannier translation mapping" begin
    identity = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
        false,
    )
    half_translation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        [0.5, 0.0, 0.0],
        Matrix{Float64}(I, 3, 3),
        false,
    )
    representations = zeros(ComplexF64, 2, 2, 2)
    representations[:, :, 1] .= Matrix{ComplexF64}(I, 2, 2)
    representations[:, :, 2] .= ComplexF64[0 1; 1 0]
    shifts = zeros(Int, 3, 2, 2)
    shifts[1, 2, 2] = 1
    plan = WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
        [identity, half_translation],
        representations,
        shifts,
    )
    values = zeros(ComplexF64, 2, 2, 1)
    values[1, 2, 1] = 1.0
    input = SymmetryModule.RealSpaceOperator(
        SymmetryModule.RealSpaceOperatorSymmetrySpec(
            SymmetryModule.REAL_SPACE_HAMILTONIAN,
            0,
            1,
            1,
        ),
        zeros(Int, 3, 1),
        values,
    )
    result = WannierNLQG.SymmetryFoundation.symmetrize_real_space_operator(input, plan)
    @test WannierNLQG.SymmetryFoundation.maximum_real_space_covariance_error(
        result.operator,
        plan,
    ) <= 1.0e-14
    @test size(result.generated_r_vectors, 2) > 0
end

@testset "Wannier90 center-major multi-set projection ordering" begin
    input = WannierNLQG.WannierProjection.WannierWinData(
        "synthetic.win",
        16,
        16,
        true,
        (1, 1, 1),
        Matrix{Float64}(I, 3, 3),
        ["X", "X"],
        [0.25 0.75; 0.0 0.5; 0.0 0.0],
        ["X:l=0;l=1"],
    )
    basis = WannierNLQG.WannierProjection.build_wannier_projection_basis(input)
    @test length(basis.blocks) == 2
    @test basis.blocks[1].orbital_set == "s"
    @test basis.blocks[1].indices == [1 9; 2 10]
    @test basis.blocks[2].orbital_set == "p"
    @test basis.blocks[2].indices == [3 11; 4 12; 5 13; 6 14; 7 15; 8 16]
    @test sort(reduce(vcat, vec(block.indices) for block in basis.blocks)) == collect(1:16)

    structure = WannierNLQG.SymmetryFoundation.CrystalStructure(
        Matrix{Float64}(I, 3, 3),
        ["X", "X"],
        input.positions_fractional,
    )
    spec = WannierNLQG.WannierProjection.ProjectionSpec(; selector = "X", orbital_sets = ("s", "p"))
    public_basis = WannierNLQG.WannierProjection.WannierProjectionBasis(
        [spec];
        structure,
        spinor = true,
        num_wannier = 16,
    )
    @test public_basis.radial_transform.method == :gauss_laguerre_high_precision
    @test public_basis.radial_transform.gauss_laguerre_order == 64
    @test getfield.(public_basis.blocks, :orbital_set) == getfield.(basis.blocks, :orbital_set)
    @test getfield.(public_basis.blocks, :indices) == getfield.(basis.blocks, :indices)
    @test getfield.(public_basis.blocks, :positions_fractional) ==
          getfield.(basis.blocks, :positions_fractional)
    @test getfield.(public_basis.blocks, :local_bases) == getfield.(basis.blocks, :local_bases)
    test_momentum = [1.0, 2.0, 0.5]
    compatibility_transform = WannierNLQG.WannierProjection.ProjectionRadialTransformConfig(;
        method = :wannierberri_compatible,
    )
    @test WannierNLQG.WannierProjection.projection_orbital_values(
        basis.blocks[1],
        test_momentum;
        radial_transform = compatibility_transform,
    ) ≈ ComplexF64[0.8945817582555411] atol = 5.0e-14 rtol = 0.0
    @test WannierNLQG.WannierProjection.projection_orbital_values(
        basis.blocks[2],
        test_momentum;
        radial_transform = compatibility_transform,
    ) ≈ ComplexF64[-0.4099697643513522im, -0.8199395287027045im, -1.6398790574054087im] atol =
        5.0e-14 rtol = 0.0
    high_precision_transform = WannierNLQG.WannierProjection.ProjectionRadialTransformConfig(;
        method = :gauss_laguerre_high_precision,
        gauss_laguerre_order = 64,
    )
    compatibility_basis = WannierNLQG.WannierProjection.WannierProjectionBasis(
        [spec];
        structure,
        spinor = true,
        num_wannier = 16,
        radial_transform = compatibility_transform,
    )
    high_precision_s = only(
        WannierNLQG.WannierProjection.projection_orbital_values(
            public_basis.blocks[1],
            test_momentum;
            radial_transform = high_precision_transform,
        ),
    )
    bohr_radius = 0.529177210903
    scaled_momentum = norm(test_momentum) * bohr_radius
    analytic_s = 4.0pi * bohr_radius^(3 / 2) * 4.0 / (1.0 + scaled_momentum^2)^2 / (2.0 * sqrt(pi))
    @test high_precision_s ≈ analytic_s atol = 2.0e-13 rtol = 0.0
    @test abs(high_precision_s - 0.8945817582555411) > 5.0e-8
    @test WannierNLQG.Wannierization._projection_basis_sha256(public_basis) !=
          WannierNLQG.Wannierization._projection_basis_sha256(compatibility_basis)
    @test_throws ArgumentError WannierNLQG.WannierProjection.ProjectionRadialTransformConfig(;
        method = :bad,
    )
    @test_throws ArgumentError WannierNLQG.WannierProjection.ProjectionRadialTransformConfig(;
        method = :gauss_laguerre_high_precision,
        gauss_laguerre_order = 4,
    )

    rotated = [0.0 -1.0 0.0; 1.0 0.0 0.0; 0.0 0.0 1.0]
    local_bases = cat(Matrix{Float64}(I, 3, 3), rotated; dims = 3)
    explicit_indices = reshape(reverse(1:16), 8, 2)
    explicit = WannierNLQG.WannierProjection.ProjectionSpec(;
        selector = "manual",
        orbital_sets = ("s", "p"),
        positions = input.positions_fractional,
        local_bases,
        indices = explicit_indices,
    )
    explicit_basis = WannierNLQG.WannierProjection.WannierProjectionBasis(
        [explicit];
        spinor = true,
        num_wannier = 16,
    )
    @test reduce(vcat, (block.indices for block in explicit_basis.blocks)) == explicit_indices
    @test explicit_basis.blocks[1].local_bases == local_bases
    @test_throws ArgumentError WannierNLQG.WannierProjection.WannierProjectionBasis(
        [spec];
        spinor = true,
    )
    bad_indices = copy(explicit_indices)
    bad_indices[1] = bad_indices[2]
    @test_throws ArgumentError WannierNLQG.WannierProjection.WannierProjectionBasis(
        [
            WannierNLQG.WannierProjection.ProjectionSpec(;
                selector = "manual",
                orbital_sets = ("s", "p"),
                positions = input.positions_fractional,
                indices = bad_indices,
            ),
        ];
        spinor = true,
        num_wannier = 16,
    )
end

@testset "magnetic providers ignore QE K_POINTS" begin
    extension = symmetrization_extension()
    input = WannierNLQG.WannierProjection.WannierWinData(
        "synthetic.win",
        2,
        2,
        false,
        (2, 2, 1),
        Matrix{Float64}(I, 3, 3),
        ["X", "Y"],
        [0.0 0.5; 0.0 0.0; 0.0 0.0],
        ["X:s", "Y:s"],
    )
    mktempdir() do directory
        qe_prefix = """
        &SYSTEM
          noncolin = .false.,
          starting_magnetization(1) = 1.0,
          starting_magnetization(2) = 0.0,
        /
        ATOMIC_SPECIES
        X 1.0 X.upf
        Y 2.0 Y.upf
        ATOMIC_POSITIONS {crystal}
        X 0.0 0.0 0.0
        Y 0.5 0.0 0.0
        """
        qe_first = joinpath(directory, "first.in")
        qe_second = joinpath(directory, "second.in")
        write(qe_first, qe_prefix * "K_POINTS automatic\n2 2 1 0 0 0\n")
        write(qe_second, qe_prefix * "K_POINTS automatic\n17 19 1 1 1 0\n")
        first_moments = extension.read_qe_magnetic_moments(
            qe_first,
            input;
            collinear_axis_cartesian = [1.0, 0.0, 0.0],
        )
        second_moments = extension.read_qe_magnetic_moments(
            qe_second,
            input;
            collinear_axis_cartesian = [1.0, 0.0, 0.0],
        )
        @test first_moments == second_moments == [1.0 0.0; 0.0 0.0; 0.0 0.0]

        incar = joinpath(directory, "INCAR")
        write(incar, "LNONCOLLINEAR = T\nLSORBIT = T\nSAXIS = 1 0 0\nMAGMOM = 2*0 1 3*0\n")
        vasp_moments = extension.read_vasp_magnetic_moments(incar, input)
        config_moments = extension.read_config_magnetic_moments([1.0 0.0; 0.0 0.0; 0.0 0.0], input)
        @test vasp_moments ≈ config_moments atol = 1.0e-14
        @test_throws ArgumentError extension.read_qe_magnetic_moments(qe_first, input)
    end
end

@testset "QE K_POINTS do not change symmetrized TB bytes" begin
    mktempdir() do directory
        win_path = joinpath(directory, "model.win")
        write(
            win_path,
            """
            num_wann = 1
            mp_grid = 2 2 1
            begin unit_cell_cart
            1.0 0.0 0.0
            0.2 1.3 0.0
            0.1 0.3 1.7
            end unit_cell_cart
            begin atoms_frac
            X 0.0 0.0 0.0
            end atoms_frac
            begin projections
            X:s
            end projections
            """,
        )
        model = SymmetryCore.TightBindingModel(
            [1.0 0.0 0.0; 0.2 1.3 0.0; 0.1 0.3 1.7],
            1,
            1,
            [1],
            zeros(Int, 3, 1),
            reshape(ComplexF64[1.25], 1, 1, 1),
            zeros(ComplexF64, 1, 1, 3, 1),
        )
        tb_path = joinpath(directory, "model_tb.dat")
        WannierNLQG.IO.write_wannier_tb(tb_path, model)
        qe_prefix = """
        &SYSTEM
          noncolin = .false.,
          starting_magnetization(1) = 1.0,
        /
        ATOMIC_SPECIES
        X 1.0 X.upf
        ATOMIC_POSITIONS {crystal}
        X 0.0 0.0 0.0
        """
        for (label, mesh) in (("first", "2 2 1 0 0 0"), ("second", "17 19 1 1 1 0"))
            output_directory = joinpath(directory, label)
            mkpath(output_directory)
            qe_path = joinpath(directory, "$(label).in")
            write(qe_path, qe_prefix * "K_POINTS automatic\n$(mesh)\n")
            config = SymmetryModule.SymmetrizationConfig(
                win_file = win_path,
                tb_file = tb_path,
                magnetic = SymmetryModule.MagneticMomentConfig(
                    source = :qe,
                    file = qe_path,
                    collinear_axis_cartesian = (0.0, 0.0, 1.0),
                ),
                include_time_reversal = false,
                output_tb_file = joinpath(output_directory, "symmetrized_tb.dat"),
                output_real_space_operator_bundle_file = joinpath(
                    output_directory,
                    "wannierNLQG_tb.h5",
                ),
            )
            SymmetryModule.symmetrize_wannier_operators(config)
        end
        @test read(joinpath(directory, "first", "symmetrized_tb.dat")) ==
              read(joinpath(directory, "second", "symmetrized_tb.dat"))
    end
end

@testset "WIN mesh authority and legacy SCF rejection" begin
    mktempdir() do directory
        win_path = joinpath(directory, "model.win")
        write(
            win_path,
            """
            num_wann = 1
            mp_grid = 2 2 2
            begin unit_cell_cart
            1 0 0
            0 1 0
            0 0 1
            end unit_cell_cart
            begin atoms_frac
            X 0 0 0
            end atoms_frac
            begin projections
            X:s
            end projections
            begin kpoints
            0.123 0.234 0.345
            end kpoints
            """,
        )
        config = SymmetryModule.MeshScreenConfig(
            win_file = win_path,
            include_time_reversal = false,
            density_target = 2.0,
            search_radius = 1,
        )
        result = SymmetryModule.screen_wannier_mesh(config)
        @test result.original_mp_grid == (2, 2, 2)
        @test result.original_grid_is_symmetry_closed
        @test result.recommended_grid == (1, 1, 1)
        @test result.selected_operation_count == length(result.operation_indices)
        @test !hasmethod(SymmetryModule.screen_wannier_mesh, Tuple{String})
        @test_throws MethodError SymmetryModule.screen_wannier_mesh("legacy.toml")
    end
end

@testset "v2 input-driven symmetrization preflight" begin
    extension = symmetrization_extension()
    @test_throws MethodError SymmetryModule.symmetrize_wannier_operators("legacy.toml")
    @test !hasfield(SymmetryModule.SymmetrizationConfig, :operators_to_symmetrize)
    @test !hasfield(SymmetryModule.SymmetrizationConfig, :output_spin_cache_file)
    @test !hasfield(SymmetryModule.SymmetrizationConfig, :output_spin_velocity_cache_file)

    mktempdir() do directory
        input_paths = Dict(
            name => joinpath(directory, "input.$(name)") for
            name in ("win", "tb", "chk", "eig", "mmn", "spn")
        )
        for path in values(input_paths)
            write(path, "fixture")
        end
        function validation_config(; kwargs...)
            output_directory = joinpath(directory, string(gensym(:profile)))
            defaults = (
                win_file = input_paths["win"],
                tb_file = input_paths["tb"],
                output_tb_file = joinpath(output_directory, "symmetrized_tb.dat"),
                output_real_space_operator_bundle_file = joinpath(
                    output_directory,
                    "wannierNLQG_tb.h5",
                ),
            )
            return SymmetryModule.SymmetrizationConfig(; merge(defaults, (; kwargs...))...)
        end

        base = extension._validate_symmetrization_config(validation_config())
        @test base.families.profile == :hamiltonian_position
        @test base.families.selected_operator_kinds ==
              collect(WannierNLQG.IO.OPERATOR_PROFILE_INVENTORIES[:hamiltonian_position])
        spin = extension._validate_symmetrization_config(
            validation_config(chk_file = input_paths["chk"], spn_file = input_paths["spn"]),
        )
        @test spin.families.profile == :hamiltonian_position_spin
        derivative = extension._validate_symmetrization_config(
            validation_config(
                chk_file = input_paths["chk"],
                eig_file = input_paths["eig"],
                mmn_file = input_paths["mmn"],
            ),
        )
        @test derivative.families.profile == :derivative
        full_error = try
            extension._validate_symmetrization_config(
                validation_config(
                    chk_file = input_paths["chk"],
                    eig_file = input_paths["eig"],
                    mmn_file = input_paths["mmn"],
                    spn_file = input_paths["spn"],
                ),
            )
            nothing
        catch caught
            caught
        end
        @test full_error isa ArgumentError
        @test occursin("LEGACY_FULL_PROFILE_REMOVED", sprint(showerror, full_error))

        @test_throws ArgumentError extension._configured_operator_families(
            validation_config(chk_file = input_paths["chk"]),
        )
        @test_throws ArgumentError extension._configured_operator_families(
            validation_config(eig_file = input_paths["eig"]),
        )
        @test_throws ArgumentError extension._configured_operator_families(
            validation_config(chk_file = input_paths["chk"], eig_file = input_paths["eig"]),
        )
        @test_throws ArgumentError extension._configured_operator_families(
            validation_config(spn_file = input_paths["spn"]),
        )
        @test_throws ArgumentError extension._validate_symmetrization_config(
            validation_config(symmetry_tolerance = 0.0),
        )
        @test_throws ArgumentError extension._validate_symmetrization_config(
            validation_config(wannier_center_policy = :unsupported),
        )
        @test_throws ArgumentError extension._validate_symmetrization_config(
            validation_config(wannier_center_tolerance = 0.0),
        )
        @test_throws ArgumentError extension._validate_symmetrization_config(
            validation_config(real_space_replica_policy = :unsupported),
        )
        missing = validation_config(tb_file = joinpath(directory, "absent_tb.dat"))
        @test_throws ArgumentError extension._validate_symmetrization_config(missing)
    end
end

@testset "task TOML surface removed" begin
    package_root = normpath(joinpath(@__DIR__, ".."))
    project_text = read(joinpath(package_root, "Project.toml"), String)
    @test !occursin(r"(?m)^TOML\s*=", project_text)
    for directory in ("src", "ext")
        for (root, _, files) in walkdir(joinpath(package_root, directory))
            for file in files
                endswith(file, ".jl") || continue
                source = read(joinpath(root, file), String)
                @test !occursin("TOML.parsefile", source)
                @test !occursin(r"(?m)^using TOML$", source)
            end
        end
    end
    example_files = sort(
        filter(
            name -> endswith(name, ".jl"),
            readdir(joinpath(package_root, "examples", "symmetrization")),
        ),
    )
    @test example_files == [
        "SymmetrizationExampleSupport.jl",
        "mesh.jl",
        "run_all.jl",
        "symmetrize_combined.jl",
        "symmetrize_derivatives.jl",
        "symmetrize_spin_only.jl",
        "symmetrize_spin_velocity.jl",
        "symmetrize_tb.jl",
    ]
end

@testset "real-space operator HDF5 round-trip" begin
    r_vectors = [0 1; 0 0; 0 0]
    hamiltonian = reshape(ComplexF64.(1:8), 2, 2, 2)
    position = reshape(ComplexF64.(1:24), 2, 2, 3, 2)
    operators = Dict{SymmetryModule.RealSpaceOperatorKind, SymmetryModule.RealSpaceOperator}(
        SymmetryModule.REAL_SPACE_HAMILTONIAN => SymmetryModule.RealSpaceOperator(
            SymmetryModule.RealSpaceOperatorSymmetrySpec(
                SymmetryModule.REAL_SPACE_HAMILTONIAN,
                0,
                1,
                1,
            ),
            r_vectors,
            hamiltonian,
        ),
        SymmetryModule.REAL_SPACE_POSITION => SymmetryModule.RealSpaceOperator(
            SymmetryModule.RealSpaceOperatorSymmetrySpec(
                SymmetryModule.REAL_SPACE_POSITION,
                1,
                -1,
                1,
            ),
            r_vectors,
            position,
        ),
    )
    mktempdir() do directory
        path = joinpath(directory, "operators.h5")
        WannierNLQG.IO.write_real_space_operator_bundle(
            path,
            Matrix{Float64}(I, 3, 3),
            [1, 1],
            operators;
            profile = :hamiltonian_position,
            geometry = test_operator_bundle_geometry(Matrix{Float64}(I, 3, 3), [1, 1], operators),
        )
        roundtrip = WannierNLQG.IO.read_real_space_operator_bundle(path)
        bundle_extension = Base.get_extension(WannierNLQG, :WannierNLQGOperatorBundleExt)
        @test bundle_extension !== nothing
        @test roundtrip.manifest.profile == :hamiltonian_position
        @test roundtrip.operators[SymmetryModule.REAL_SPACE_HAMILTONIAN].data == hamiltonian
        @test roundtrip.operators[SymmetryModule.REAL_SPACE_POSITION].data == position

        exact_metadata_path = joinpath(directory, "operators-exact-uIu-provenance.h5")
        exact_source_sha256 = repeat("a", 64)
        WannierNLQG.IO.write_real_space_operator_bundle(
            exact_metadata_path,
            Matrix{Float64}(I, 3, 3),
            [1, 1],
            operators;
            profile = :hamiltonian_position,
            provenance = Dict(
                "derivative_overlap_source" => "wannier90_uIu",
                "derivative_overlap_completeness" => "full_hilbert_space",
                "derivative_overlap_source_sha256" => exact_source_sha256,
                "derivative_overlap_algorithm_version" =>
                    WannierNLQG.IO.FULL_DERIVATIVE_OVERLAP_ALGORITHM_VERSION,
            ),
            geometry = test_operator_bundle_geometry(Matrix{Float64}(I, 3, 3), [1, 1], operators),
        )
        exact_manifest =
            WannierNLQG.IO.read_real_space_operator_bundle_manifest(exact_metadata_path)
        @test exact_manifest.schema_version == WannierNLQG.IO.OPERATOR_BUNDLE_SCHEMA_VERSION
        @test exact_manifest.derivative_overlap_source == "wannier90_uIu"
        @test exact_manifest.derivative_overlap_completeness == "full_hilbert_space"
        @test exact_manifest.derivative_overlap_source_sha256 == exact_source_sha256
        @test exact_manifest.derivative_overlap_algorithm_version ==
              WannierNLQG.IO.FULL_DERIVATIVE_OVERLAP_ALGORITHM_VERSION

        projector_cfg = WannierNLQG.Runtime.EffectiveTaskConfig(
            tasks = [("SCK", "Projector", "K-slice")],
            fourier_backend = "Direct",
            tensor_indices = (2, 1, 2),
        )
        projector_demand = WannierNLQG.Runtime.operator_demand_plan(
            WannierNLQG.Runtime.normalize_task_specs(projector_cfg),
            projector_cfg,
        )
        for (replacement, expected_text) in (
            (
                (; derivative_overlap_source_sha256 = repeat("z", 64)),
                "SHA-256 is not lowercase hexadecimal",
            ),
            (
                (; derivative_overlap_algorithm_version = "unknown-get-FF-R"),
                "unsupported derivative-overlap algorithm",
            ),
        )
            bad_manifest = symmetry_replace_manifest(exact_manifest; replacement...)
            caught = try
                WannierNLQG.Runtime.validate_operator_demand(bad_manifest, projector_demand)
                nothing
            catch exception
                exception
            end
            @test caught isa ArgumentError
            @test occursin(expected_text, sprint(showerror, caught))
        end

        for (suffix, source_sha256, algorithm) in (
            ("bad-sha", repeat("z", 64), WannierNLQG.IO.FULL_DERIVATIVE_OVERLAP_ALGORITHM_VERSION),
            ("bad-algorithm", exact_source_sha256, "unknown-get-FF-R"),
        )
            @test_throws ArgumentError WannierNLQG.IO.write_real_space_operator_bundle(
                joinpath(directory, "operators-$(suffix).h5"),
                Matrix{Float64}(I, 3, 3),
                [1, 1],
                operators;
                profile = :hamiltonian_position,
                provenance = Dict(
                    "derivative_overlap_source" => "wannier90_uIu",
                    "derivative_overlap_completeness" => "full_hilbert_space",
                    "derivative_overlap_source_sha256" => source_sha256,
                    "derivative_overlap_algorithm_version" => algorithm,
                ),
                geometry = test_operator_bundle_geometry(
                    Matrix{Float64}(I, 3, 3),
                    [1, 1],
                    operators,
                ),
            )
        end

        v5_manifest = roundtrip.manifest
        component_hashes = getfield.(v5_manifest.entries, :component_sha256)
        for legacy_version in ("3.0", "4.0")
            legacy_compatible_path = joinpath(directory, "operators-v$(legacy_version).h5")
            cp(path, legacy_compatible_path)
            legacy_digest = bundle_extension._scientific_content_digest(
                v5_manifest.profile,
                v5_manifest.inventory,
                v5_manifest.lattice,
                v5_manifest.r_vectors,
                v5_manifest.degeneracies,
                component_hashes,
                v5_manifest.paired_tb_sha256,
                legacy_version,
                nothing,
            )
            HDF5.h5open(legacy_compatible_path, "r+") do handle
                root_attributes = HDF5.attributes(handle)
                for name in ("schema_version", "wanniernlqg_version", "scientific_content_sha256")
                    HDF5.delete_attribute(handle, name)
                end
                root_attributes["schema_version"] = legacy_version
                root_attributes["wanniernlqg_version"] = "2.0.0"
                root_attributes["scientific_content_sha256"] = legacy_digest
            end
            legacy_manifest =
                WannierNLQG.IO.read_real_space_operator_bundle_manifest(legacy_compatible_path)
            @test legacy_manifest.schema_version == legacy_version
            @test legacy_manifest.wannier_center_policy == :legacy
            @test legacy_manifest.real_space_replica_policy == :legacy
            @test legacy_manifest.geometry_content_sha256 === nothing
            if legacy_version == "3.0"
                @test legacy_manifest.wannier_centers_cartesian === nothing
            else
                @test legacy_manifest.wannier_centers_cartesian !== nothing
            end
        end
        @test_throws ArgumentError WannierNLQG.IO.write_real_space_operator_bundle(
            path,
            Matrix{Float64}(I, 3, 3),
            [1, 1],
            operators;
            profile = :hamiltonian_position,
            geometry = test_operator_bundle_geometry(Matrix{Float64}(I, 3, 3), [1, 1], operators),
        )

        legacy_path = joinpath(directory, "legacy-v1.h5")
        HDF5.h5open(legacy_path, "w") do handle
            HDF5.attributes(handle)["schema"] = "wanniernlqg.real-space-operators"
            HDF5.attributes(handle)["schema_version"] = "1.0"
        end
        @test_throws ArgumentError WannierNLQG.IO.read_real_space_operator_bundle(legacy_path)
    end
end

@testset "Symmetrization production naming gate" begin
    package_root = normpath(joinpath(@__DIR__, ".."))
    roots = (
        joinpath(package_root, "src", "Symmetrization"),
        joinpath(package_root, "ext", "WannierNLQGSymmetrizationExt"),
    )
    forbidden = (
        r"\bMatrixSymmetrySpec\b",
        r"\bSymmetrizeTBConfig\b",
        r"\bSymmetrizeSpinConfig\b",
        r"\bsymmetrize_tb\b",
        r"\bsymmetrize_spin_operators\b",
        r"\bWannierInputData\b",
        r"\bread_wannier_input\b",
        r"\bOrbitalOperatorSet\b",
        r"\bconstruct_orbital_operators\b",
        r"\brequested_operators\b",
        r"\boutput_operators_hdf5_file\b",
        r"\breal_space_covariance_error\b",
        r"\b_rotate_cartesian_backwards\b",
        r"\b_backward_operator_element\b",
        r"\b_operator_element_norm\b",
        r"\b_hermitianize_standard\b",
        r"\b_apply_center_phases!\b",
        r"\b_orbital_centers_fractional\b",
        r"\b_nearest_center_images\b",
        r"\b_density_centered_mesh\b",
        r"\b_make_projection_basis\b",
        r"\b_hybrid_basis_data\b",
        r"\btargets\b",
        r"\boperation_count\b",
        r"\bsymprec\b",
        r"\b[A-Za-z0-9_]+_cart\b",
        r"\bSymWann\b",
        r"\bcollinear_axis_cart\b",
        r"\b(BB|CC|FF|OO|GG|UIU|UHU|SS|SH|SR|SHR|AA)\b",
    )
    for root in roots, (directory, _, files) in walkdir(root), file in files
        endswith(file, ".jl") || continue
        source = read(joinpath(directory, file), String)
        for pattern in forbidden
            audited_source = if pattern == r"\b[A-Za-z0-9_]+_cart\b"
                replace(source, r"\b(wannier_centers_cart|unit_cell_cart|atoms_cart)\b" => "")
            else
                source
            end
            @test !occursin(pattern, audited_source)
        end
    end
end
