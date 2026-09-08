using Test
using LinearAlgebra
using HDF5
using WannierNLQG

const CoreModule = WannierNLQG.Core
const SymmetryFoundationModule = WannierNLQG.SymmetryFoundation
const WannierProjectionModule = WannierNLQG.WannierProjection
const IOModule = WannierNLQG.IO
const MatrixElementModule = WannierNLQG.MatrixElements
const SymmetrizationModule = WannierNLQG.Symmetrization
const WannierizationModule = WannierNLQG.Wannierization

@testset "facade and expert namespaces" begin
    @test Set(names(WannierNLQG; all = false, imported = false)) == Set([
        :WannierNLQG,
        :TaskConfig,
        :TaskSpec,
        :RunResult,
        :run,
        :ModelInput,
        :BZMesh,
        :KSlice,
        :KPath,
        :ExecutionOptions,
        :OutputOptions,
        :OpticalParameters,
        :FiniteQOpticalParameters,
        :GeometryParameters,
        :BandParameters,
        :OpticalNumerics,
        :GeometryNumerics,
        :BandNumerics,
        :BandTargets,
        :Subspace,
        :Subspaces,
        :OccupiedBands,
        :AllBands,
        :Transition,
        :InterbandGroups,
        :TripleGroups,
        :TensorComponent,
        :FullTensor,
        :KSliceSelection,
    ])
    @test isdefined(WannierNLQG, :Core)
    @test isdefined(WannierNLQG, :SymmetryFoundation)
    @test isdefined(WannierNLQG, :WannierProjection)
    @test isdefined(WannierNLQG, :IO)
    @test isdefined(WannierNLQG, :MatrixElements)
    @test isdefined(WannierNLQG, :Symmetrization)
    @test isdefined(WannierNLQG, :Wannierization)
    @test isdefined(WannierNLQG, :Responses)
    @test isdefined(WannierNLQG, :Runtime)
end

@testset "shared-layer qualified integration contracts" begin
    for name in SymmetryFoundationModule.SYMMETRY_FOUNDATION_INTEGRATION_API
        @test isdefined(SymmetryFoundationModule, name)
        @test !startswith(String(name), "_")
    end
    for name in WannierProjectionModule.WANNIER_PROJECTION_INTEGRATION_API
        @test isdefined(WannierProjectionModule, name)
        @test !startswith(String(name), "_")
    end
    @test :response_symmetry_group_report in
          SymmetryFoundationModule.SYMMETRY_FOUNDATION_INTEGRATION_API
    @test !(
        :response_symmetry_group_report in
        names(SymmetryFoundationModule; all = false, imported = false)
    )
    @test :magnetic_point_group_operation_identity in
          SymmetryFoundationModule.SYMMETRY_FOUNDATION_INTEGRATION_API
    @test !(
        :magnetic_point_group_operation_identity in
        names(SymmetryFoundationModule; all = false, imported = false)
    )
    @test Set(names(WannierizationModule; all = false, imported = false)) == Set((
        :Wannierization,
        :SymmetryAdaptedWannierizationConfig,
        :WannierizationResult,
        :construct_symmetry_adapted_wannier_functions,
    ))
end

@testset "IO-owned Packed HDF5 schema-6 bundle" begin
    model = CoreModule.TightBindingModel(
        Matrix{Float64}(I, 3, 3),
        2,
        1,
        ones(Int, 1),
        reshape(Int[0, 0, 0], 3, 1),
        zeros(ComplexF64, 2, 2, 1),
        zeros(ComplexF64, 2, 2, 3, 1),
    )
    operators = Dict{CoreModule.RealSpaceOperatorKind, CoreModule.RealSpaceOperator}(
        CoreModule.REAL_SPACE_HAMILTONIAN => CoreModule.RealSpaceOperator(
            CoreModule.RealSpaceOperatorSymmetrySpec(CoreModule.REAL_SPACE_HAMILTONIAN, 0, 1, 1),
            model.r_vectors,
            model.hamiltonian_r,
        ),
        CoreModule.REAL_SPACE_POSITION => CoreModule.RealSpaceOperator(
            CoreModule.RealSpaceOperatorSymmetrySpec(CoreModule.REAL_SPACE_POSITION, 1, -1, 1),
            model.r_vectors,
            model.position_r,
        ),
    )
    mktempdir() do directory
        bundle_file = joinpath(directory, "wannierNLQG_tb.h5")
        @test IOModule.write_real_space_operator_bundle(
            bundle_file,
            model.lattice,
            model.r_degeneracies,
            operators;
            profile = :hamiltonian_position,
            paired_tb_sha256 = repeat("a", 64),
            geometry = test_operator_bundle_geometry(
                model.lattice,
                model.r_degeneracies,
                operators,
            ),
        ) == bundle_file
        manifest = IOModule.read_real_space_operator_bundle_manifest(bundle_file)
        @test manifest.profile == :hamiltonian_position
        @test manifest.inventory ==
              [CoreModule.REAL_SPACE_HAMILTONIAN, CoreModule.REAL_SPACE_POSITION]
        @test getfield.(manifest.entries, :offset_elements) == UInt64[0, 4, 8, 12]
        roundtrip = IOModule.read_real_space_operator_bundle(bundle_file)
        @test roundtrip.operators[CoreModule.REAL_SPACE_HAMILTONIAN].data == model.hamiltonian_r
        @test roundtrip.operators[CoreModule.REAL_SPACE_POSITION].data == model.position_r
        mapped = IOModule.read_operator_bundle_payload(bundle_file)
        @test mapped.read_mode == :mmap
        @test mapped.payload[1] == model.hamiltonian_r[1]
        HDF5.h5open(bundle_file, "r") do handle
            @test HDF5.iscontiguous(handle["payload/complex128"])
            @test read(HDF5.attributes(handle)["symmetrization_status"]) == "not_provided"
        end

        schema_two = joinpath(directory, "schema_two.h5")
        cp(bundle_file, schema_two)
        HDF5.h5open(schema_two, "r+") do handle
            write(HDF5.attributes(handle)["schema_version"], "2.0")
        end
        @test_throws ArgumentError IOModule.read_real_space_operator_bundle_manifest(schema_two)

        tampered_payload = joinpath(directory, "tampered_payload.h5")
        cp(bundle_file, tampered_payload)
        HDF5.h5open(tampered_payload, "r+") do handle
            dataset = handle["payload/complex128"]
            dataset[1] = 1.0 + 2.0im
        end
        requested = Dict(CoreModule.REAL_SPACE_HAMILTONIAN => [(Int8(0), Int8(0))])
        @test_throws ArgumentError IOModule.read_operator_bundle_components(
            tampered_payload,
            requested,
        )

        tampered_index = joinpath(directory, "tampered_index.h5")
        cp(bundle_file, tampered_index)
        HDF5.h5open(tampered_index, "r+") do handle
            offsets = read(handle["index/offset_elements"])
            offsets[2] += 1
            handle["index/offset_elements"][:] = offsets
        end
        @test_throws ArgumentError IOModule.read_real_space_operator_bundle_manifest(tampered_index)
        @test_throws ArgumentError IOModule.write_real_space_operator_bundle(
            bundle_file,
            model.lattice,
            model.r_degeneracies,
            operators;
            profile = :hamiltonian_position,
            geometry = test_operator_bundle_geometry(
                model.lattice,
                model.r_degeneracies,
                operators,
            ),
        )
    end
    @test !isdefined(IOModule, :read_spin_real_space_cache)
    @test !isdefined(IOModule, :write_spin_velocity_real_space_cache)
end

@testset "tight-binding model invariants" begin
    model_path = TEST_MODEL_FILE
    model = IOModule.read_wannier_tb(model_path)
    @test IOModule.read_wannier_tb_num_orbitals(model_path) == model.num_orbitals
    @test model isa CoreModule.TightBindingModel
    @test size(model.lattice) == (3, 3)
    @test length(model.r_degeneracies) == model.num_r_vectors
    @test size(model.hamiltonian_r) == (model.num_orbitals, model.num_orbitals, model.num_r_vectors)
    @test !hasfield(CoreModule.TightBindingModel, :spin_r)

    @test_throws ArgumentError CoreModule.TightBindingModel(
        zeros(3, 3),
        0,
        1,
        [1],
        zeros(Int, 3, 1),
        zeros(ComplexF64, 0, 0, 1),
        zeros(ComplexF64, 0, 0, 3, 1),
    )
    mktemp() do path, file
        write(file, "malformed\n")
        close(file)
        @test_throws Exception IOModule.read_wannier_tb(path)
    end
end

@testset "shared k-point spectrum" begin
    spectrum = CoreModule.KPointSpectrum(3)
    @test size(spectrum.energies) == (3,)
    @test size(spectrum.eigenvectors) == (3, 3)
    @test size(spectrum.eigenvectors_adjoint) == (3, 3)

    request = MatrixElementModule.MatrixElementRequest(
        MatrixElementModule.BERRY_CONNECTION;
        spatial_dimension = 2,
    )
    plan = MatrixElementModule.compile_matrix_plan(request)
    common = MatrixElementModule.KPointMatrixData(3, 0, plan)
    projector = MatrixElementModule.ProjectorMatrixData(common, 2)
    geometric_loop = MatrixElementModule.GeometricLoopMatrixData(common)
    @test common.spectrum === projector.spectrum
    @test common.spectrum === geometric_loop.spectrum
    @test !hasfield(typeof(projector), :spectrum)
    @test !hasfield(typeof(geometric_loop), :spectrum)
    @test !isdefined(MatrixElementModule, :ConventionalKPointData)
    @test !isdefined(MatrixElementModule, :SpinKPointData)
    @test !isdefined(MatrixElementModule, :SpinVelocityKPointData)
end

@testset "capability closure and interpolated matrix construction" begin
    model = IOModule.read_wannier_tb(TEST_MODEL_FILE)
    request = MatrixElementModule.MatrixElementRequest(
        MatrixElementModule.BERRY_CONNECTION;
        spatial_dimension = 2,
        denominator_regularization = 0.001,
    )
    plan = MatrixElementModule.compile_matrix_plan(request)
    @test MatrixElementModule.has_capability(plan, MatrixElementModule.SPECTRUM)
    @test MatrixElementModule.has_capability(plan, MatrixElementModule.HAMILTONIAN_DERIVATIVES)
    @test MatrixElementModule.has_capability(plan, MatrixElementModule.INTERNAL_CONNECTION)
    @test !MatrixElementModule.has_capability(
        plan,
        MatrixElementModule.HAMILTONIAN_SECOND_DERIVATIVES,
    )

    workspace = MatrixElementModule.MatrixElementWorkspace(model, plan)
    @test workspace.data.spin === nothing
    @test workspace.data.spin_velocity === nothing
    @test workspace.data.hamiltonian.second_derivatives === nothing
    MatrixElementModule.prepare_real_space!(workspace, model)
    MatrixElementModule.compute_kpoint!(workspace, model, zeros(3))
    @test maximum(
        abs,
        workspace.scratch.hamiltonian_wannier - workspace.scratch.hamiltonian_wannier',
    ) < 1.0e-12
    @test all(isfinite, workspace.data.spectrum.energies)
    @test workspace.data.spectrum.eigenvectors_adjoint == workspace.data.spectrum.eigenvectors'
    @test size(MatrixElementModule.matrix(workspace, MatrixElementModule.BERRY_CONNECTION)) ==
          (model.num_orbitals, model.num_orbitals, 2)
    @test_throws Exception MatrixElementModule.matrix(
        workspace,
        MatrixElementModule.HAMILTONIAN_SECOND_DERIVATIVES,
    )

    for column in axes(workspace.data.spectrum.eigenvectors, 2)
        eigenvector = @view workspace.data.spectrum.eigenvectors[:, column]
        pivot = argmax(abs.(eigenvector))
        @test abs(imag(eigenvector[pivot])) < 1.0e-12
        @test real(eigenvector[pivot]) >= 0.0
    end

    tied_vectors = ComplexF64[0.0 + 1.0im 1.0 + 0.0im; 1.0 + 0.0im 0.0 - 1.0im]
    MatrixElementModule.canonicalize_eigenvectors!(tied_vectors)
    @test tied_vectors[1, 1] == 1.0 + 0.0im
    @test tied_vectors[1, 2] == 1.0 + 0.0im
end

@testset "spin matrix construction through the shared interface" begin
    model = IOModule.read_wannier_tb(TEST_MODEL_FILE)
    real_space = MatrixElementModule.SpinRealSpaceData(
        zeros(ComplexF64, model.num_orbitals, model.num_orbitals, 3, model.num_r_vectors),
    )
    request = MatrixElementModule.MatrixElementRequest(MatrixElementModule.SPIN)
    plan = MatrixElementModule.compile_matrix_plan(request)
    sources = MatrixElementModule.MatrixElementSources(spin = real_space)
    workspace = MatrixElementModule.MatrixElementWorkspace(model, plan, sources)
    MatrixElementModule.prepare_real_space!(workspace, model)
    MatrixElementModule.compute_kpoint!(workspace, model, zeros(3))
    @test iszero(maximum(abs, MatrixElementModule.matrix(workspace, MatrixElementModule.SPIN)))
    @test all(isfinite, workspace.data.spectrum.energies)
    @test workspace.counts.diagonalizations == 1
    @test workspace.counts.capability_computations[MatrixElementModule.SPIN] == 1

    missing_sources_workspace = MatrixElementModule.MatrixElementWorkspace
    @test_throws Exception missing_sources_workspace(model, plan)

    other_real_space = MatrixElementModule.SpinRealSpaceData(
        zeros(ComplexF64, model.num_orbitals, model.num_orbitals, 3, model.num_r_vectors),
    )
    spin_velocity_real_space = MatrixElementModule.SpinVelocityRealSpaceData(
        real_space,
        zeros(ComplexF64, model.num_orbitals, model.num_orbitals, 3, model.num_r_vectors),
        zeros(ComplexF64, model.num_orbitals, model.num_orbitals, 3, 3, model.num_r_vectors),
        zeros(ComplexF64, model.num_orbitals, model.num_orbitals, 3, 3, model.num_r_vectors),
        MatrixElementModule.SpinVelocityRealSpaceDiagnostics(0.0, 0.0, 0.0, 0.0),
    )
    @test_throws Exception MatrixElementModule.MatrixElementSources(
        spin = other_real_space,
        spin_velocity = spin_velocity_real_space,
    )
end

@testset "structured k-point cache deduplicates capabilities" begin
    model = IOModule.read_wannier_tb(TEST_MODEL_FILE)
    request = MatrixElementModule.MatrixElementRequest(
        MatrixElementModule.VELOCITY_VERTICES;
        spatial_dimension = 2,
    )
    plan = MatrixElementModule.compile_matrix_plan(request)
    batch = MatrixElementModule.KPointBatchWorkspace(model, plan)
    MatrixElementModule.prepare_real_space!(batch.matrix_elements, model)

    central = MatrixElementModule.matrix_data!(batch, MatrixElementModule.KPointOffset())
    MatrixElementModule.compute_kpoint!(central, batch.matrix_elements, model, zeros(3))
    MatrixElementModule.compute_kpoint!(central, batch.matrix_elements, model, zeros(3))
    @test batch.matrix_elements.counts.diagonalizations == 1

    offset = MatrixElementModule.KPointOffset((1, 0, 0), 0)
    projector_data = MatrixElementModule.ProjectorMatrixData(central, 2)
    projector_workspace = MatrixElementModule.ProjectorMatrixWorkspace(batch.matrix_elements, batch)
    geometric_data = MatrixElementModule.GeometricLoopMatrixData(central)
    geometric_workspace =
        MatrixElementModule.GeometricLoopMatrixWorkspace(batch.matrix_elements, batch)
    MatrixElementModule.bind_kpoint_offset!(projector_data, projector_workspace, offset)
    MatrixElementModule.bind_kpoint_offset!(geometric_data, geometric_workspace, offset)
    @test projector_data.common === geometric_data.common
    @test projector_data.common !== central

    @test MatrixElementModule.KPointOffset((1, 0, 0), -1) !=
          MatrixElementModule.KPointOffset((1, 0, 0), 1)
end

@testset "two-stage screening retains slot-local Fourier factors" begin
    model = IOModule.read_wannier_tb(TEST_MODEL_FILE)
    request = MatrixElementModule.MatrixElementRequest(
        MatrixElementModule.VELOCITY_VERTICES;
        spatial_dimension = 2,
    )
    plan = MatrixElementModule.compile_matrix_plan(request)
    batch = MatrixElementModule.KPointBatchWorkspace(model, plan)
    workspace = batch.matrix_elements
    MatrixElementModule.prepare_real_space!(workspace, model)

    valence =
        MatrixElementModule.matrix_data!(batch, MatrixElementModule.KPointOffset((0, 0, 0), -1))
    conduction =
        MatrixElementModule.matrix_data!(batch, MatrixElementModule.KPointOffset((0, 0, 0), 1))
    valence_kpoint = [-0.01, 0.0, 0.0]
    conduction_kpoint = [0.01, 0.0, 0.0]
    MatrixElementModule.compute_spectrum!(valence, workspace, model, valence_kpoint)
    valence_factors = copy(valence.fourier_factors)
    MatrixElementModule.compute_spectrum!(conduction, workspace, model, conduction_kpoint)
    @test workspace.scratch.fourier_factors === conduction.fourier_factors
    @test valence.fourier_factors == valence_factors

    MatrixElementModule.compute_kpoint!(valence, workspace, model, valence_kpoint)
    @test workspace.scratch.fourier_factors === valence.fourier_factors
    @test valence.fourier_factors == valence_factors
    @test all(isfinite, valence.velocity_vertices)
    @test workspace.counts.diagonalizations == 2
end

@testset "response families share center and shifted matrix slots" begin
    model = IOModule.read_wannier_tb(TEST_MODEL_FILE)
    request = MatrixElementModule.MatrixElementRequest(
        MatrixElementModule.BERRY_CONNECTION,
        MatrixElementModule.HAMILTONIAN_SECOND_DERIVATIVES,
        MatrixElementModule.INTERNAL_CONNECTION_DERIVATIVES,
        MatrixElementModule.VELOCITY_VERTICES;
        spatial_dimension = 2,
    )
    plan = MatrixElementModule.compile_matrix_plan(request)
    batch = MatrixElementModule.KPointBatchWorkspace(model, plan)
    matrix_workspace = batch.matrix_elements
    MatrixElementModule.prepare_real_space!(matrix_workspace, model)
    central = MatrixElementModule.matrix_data!(batch, MatrixElementModule.KPointOffset())

    conventional = WannierNLQG.Responses.make_conventional_quantum_geometry_workspace(
        model.num_orbitals,
        model.num_r_vectors,
        2,
        1;
        matrix_elements = matrix_workspace,
        central_data = central,
        matrix_batch = batch,
    )
    projector = WannierNLQG.Responses.make_projector_response_workspace(
        model.num_orbitals,
        model.num_r_vectors,
        2,
        1;
        matrix_elements = matrix_workspace,
        matrix_batch = batch,
        central_common = central,
    )
    geometric_loop = WannierNLQG.Responses.make_geometric_loop_response_workspace(
        model.num_orbitals,
        model.num_r_vectors,
        2,
        1;
        matrix_elements = matrix_workspace,
        matrix_batch = batch,
        valence_central_common = central,
        conduction_central_common = central,
    )
    @test conventional.data === projector.central_data.common
    @test conventional.data === geometric_loop.valence_central_data.common
    @test conventional.data === geometric_loop.conduction_central_data.common

    finite_difference_vectors = CoreModule.finite_difference_step_matrix(model, 0.005)
    WannierNLQG.Responses.quantum_metric_dipole_component!(
        conventional,
        model,
        zeros(3),
        finite_difference_vectors,
        [1],
        [1, 1, 1],
        0.005,
        0.001,
        model.num_orbitals,
        2,
    )
    @test matrix_workspace.counts.diagonalizations == 2
    @test conventional.data === central

    positive_offset = MatrixElementModule.KPointOffset((1, 0, 0), 0)
    positive_kpoint = finite_difference_vectors[:, 1]
    MatrixElementModule.bind_kpoint_offset!(
        projector.central_data,
        projector.scratch,
        positive_offset,
    )
    MatrixElementModule.compute_kpoint!(
        projector.central_data,
        projector.scratch,
        model,
        positive_kpoint;
        denominator_regularization = 0.001,
        spatial_dimension = 2,
    )
    MatrixElementModule.bind_kpoint_offset!(
        geometric_loop.valence_central_data,
        geometric_loop.scratch,
        positive_offset,
    )
    MatrixElementModule.compute_kpoint!(
        geometric_loop.valence_central_data,
        geometric_loop.scratch,
        model,
        positive_kpoint;
        denominator_regularization = 0.001,
        spatial_dimension = 2,
    )
    @test projector.central_data.common === geometric_loop.valence_central_data.common
    @test matrix_workspace.counts.diagonalizations == 2
end
