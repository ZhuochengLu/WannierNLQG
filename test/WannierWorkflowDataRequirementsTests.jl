using Test
using WannierNLQG

@testset "Wannier workflow demand before readers" begin
    plan = WannierNLQG.Runtime.plan_wannier_workflow_data
    C = WannierNLQG.Core
    basic = (C.REAL_SPACE_HAMILTONIAN, C.REAL_SPACE_POSITION)
    for source in (:qe, :vasp)
        external =
            plan(:wannierization; mode = :ordinary, source_kind = source, external_matrices = true)
        @test external.matrix_route == :external_basic
        @test external.operators == basic
        @test external.kmesh && external.projection_basis
        @test !external.wavefunction_coefficients && !external.physical_metric
        for mode in (:ordinary, :symmetry_adapted)
            native = plan(:wannierization; mode, source_kind = source)
            @test native.matrix_route == :native
            @test native.wavefunction_coefficients && native.physical_metric
        end
        @test_throws ArgumentError plan(
            :wannierization;
            mode = :symmetry_adapted,
            source_kind = source,
            external_matrices = true,
        )
        @test_throws ArgumentError plan(
            :wannierization;
            mode = :ordinary,
            source_kind = source,
            profile = :full,
            external_matrices = true,
        )
        full = plan(:wannierization; mode = :ordinary, source_kind = source, profile = :full)
        @test full.operators == C.REAL_SPACE_OPERATOR_REGISTRY
        screening = plan(:mesh_screening; source_kind = source)
        @test screening.kmesh && isempty(screening.operators)
        @test !screening.wavefunction_coefficients &&
              !screening.physical_metric &&
              !screening.projection_basis
    end
    projection = plan(:symmetrization; explicit_structure = true, model_operators = reverse(basic))
    @test projection.mode == :projection
    @test projection.operators == basic
    @test projection.existing_model && !projection.kmesh && !projection.wavefunction_coefficients
    @test_throws ArgumentError plan(
        :symmetrization;
        explicit_structure = true,
        mode = :gauge_aware,
        model_operators = basic,
    )
    @test_throws ArgumentError plan(
        :symmetrization;
        explicit_structure = true,
        model_operators = (basic[1], basic[1]),
    )
    @test_throws ArgumentError plan(:mesh_screening; explicit_structure = true)
    @test !plan(:mesh_screening; explicit_structure = true, explicit_kmesh = true).existing_model
    @test_throws ArgumentError plan(
        :wannierization;
        mode = :ordinary,
        explicit_structure = true,
        explicit_kmesh = true,
    )
    @test plan(
        :wannierization;
        mode = :ordinary,
        explicit_structure = true,
        explicit_kmesh = true,
        external_matrices = true,
    ).matrix_route == :external_basic
    tasks = (C.OperatorTask(quantity = :orbital_magnetization),)
    request = plan(:wannierization; mode = :ordinary, source_kind = :qe, operator_tasks = tasks)
    @test request.operators == C.resolve_operator_requirements(tasks).required_operators
    @test request.wavefunction_coefficients
    @test_throws ArgumentError plan(
        :wannierization;
        mode = :ordinary,
        source_kind = :qe,
        operator_tasks = tasks,
        external_matrices = true,
    )
    @test_throws ArgumentError plan(
        :wannierization;
        mode = :ordinary,
        source_kind = :qe,
        operator_tasks = tasks,
        profile = :full,
    )
    @test_throws C.OperatorSelectionError plan(
        :wannierization;
        mode = :ordinary,
        source_kind = :qe,
        operator_tasks = (),
    )
    @test_throws ArgumentError plan(:wannierization; mode = :ordinary, source_kind = :unsupported)
end
