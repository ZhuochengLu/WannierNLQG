module ParameterCompatibilityClosureTests
using Test, LinearAlgebra, WannierNLQG, HDF5
const R = WannierNLQG.Runtime
const C = WannierNLQG.Core
const F = WannierNLQG.IO
const W = WannierNLQG.Wannierization
const WP = WannierNLQG.WannierProjection
const RESULTS = NamedTuple[]
include(joinpath(@__DIR__, "TestCountCompatibilitySupport.jl"))
include(joinpath(@__DIR__, "WannierizationFixtureSupport.jl"))
include(joinpath(@__DIR__, "OperatorBundleTestSupport.jl"))
function case!(f, label)
    result = @testset "$label" begin
        f()
    end
    c = test_result_totals(result)
    push!(RESULTS, (; label, passed = c.passed, failed = c.failed, errored = c.errored))
end

case!("radial_actual_capability_boundary") do
    table=Dict("projections"=>["X:s"], "radial_transform"=>Dict("method"=>"mixed_grid_cubic"))
    error=try
        R._workflow_wannier_basis(nothing, table);
        nothing
    catch e
        ;
        e
    end
    @test error isa ArgumentError
    @test occursin("not consumed", sprint(showerror, error))
    @test WP.ProjectionRadialTransformConfig().method == :gauss_laguerre_high_precision
    @test WP.ProjectionRadialTransformConfig(method = :mixed_grid_cubic).method == :mixed_grid_cubic
    @test WP.ProjectionRadialTransformConfig(gauss_laguerre_order = 32).gauss_laguerre_order == 32
end

case!("inventory_writer_and_keyword_retirement") do
    lattice=Matrix{Float64}(I, 3, 3);
    vectors=zeros(Int, 3, 1)
    h=reshape(ComplexF64[-1 0; 0 1], 2, 2, 1);
    p=zeros(ComplexF64, 2, 2, 3, 1)
    operators=Dict(
        C.REAL_SPACE_HAMILTONIAN=>C.RealSpaceOperator(
            C.RealSpaceOperatorSymmetrySpec(C.REAL_SPACE_HAMILTONIAN, 0, 1, 1),
            vectors,
            h,
        ),
        C.REAL_SPACE_POSITION=>C.RealSpaceOperator(
            C.RealSpaceOperatorSymmetrySpec(C.REAL_SPACE_POSITION, 1, -1, 1),
            vectors,
            p,
        ),
    )
    geometry=test_operator_bundle_geometry(lattice, [1], operators)
    mktempdir() do directory
        for custom in (false, true)
            current=copy(operators)
            if custom
                kind=C.REAL_SPACE_SPIN_TIMES_HAMILTONIAN
                current[kind]=C.RealSpaceOperator(
                    C.RealSpaceOperatorSymmetrySpec(kind, 1, 1, -1),
                    vectors,
                    zeros(ComplexF64, 2, 2, 3, 1),
                )
                @test_throws ArgumentError F.infer_operator_profile(keys(current))
            end
            path=joinpath(directory, custom ? "custom.h5" : "hr.h5")
            F.write_real_space_operator_bundle(path, lattice, [1], current; geometry)
            loaded=F.read_real_space_operator_bundle(path)
            @test loaded.manifest.profile == (custom ? :custom : :hamiltonian_position)
            @test Set(loaded.manifest.inventory)==Set(keys(current))
            for (kind, operator) in current
                @test loaded.operators[kind].data==operator.data
            end
        end
        for key in (:profile, :operator_tasks, :symmetry, :diagnostics)
            @test_throws MethodError F.write_real_space_operator_bundle(
                joinpath(directory, "bad-$key.h5"),
                lattice,
                [1],
                operators;
                geometry,
                key=>nothing,
            )
            @test !ispath(joinpath(directory, "bad-$key.h5"))
        end
        @test_throws ArgumentError F.write_real_space_operator_bundle(
            joinpath(directory, "missing.h5"),
            lattice,
            [1],
            Dict(C.REAL_SPACE_HAMILTONIAN=>operators[C.REAL_SPACE_HAMILTONIAN]);
            geometry,
        )
        invalid=copy(operators);
        invalid[C.REAL_SPACE_HAMILTONIAN]=C.RealSpaceOperator(
            C.RealSpaceOperatorSymmetrySpec(C.REAL_SPACE_HAMILTONIAN, 0, 1, 1),
            vectors,
            copy(h),
        )
        invalid[C.REAL_SPACE_HAMILTONIAN].data[1]=ComplexF64(NaN)
        @test_throws ArgumentError F.write_real_space_operator_bundle(
            joinpath(directory, "nonfinite.h5"),
            lattice,
            [1],
            invalid;
            geometry,
        )
    end
end

case!("historical_identity_and_inert_integer") do
    @test_throws ArgumentError W.ProjectionRepresentationSearchThresholds(integer = 1e-5)
    t=W.ProjectionRepresentationSearchThresholds(
        position = 2e-8,
        representation = 3e-8,
        group_law = 4e-8,
    )
    @test (t.position, t.representation, t.group_law)==(2e-8, 3e-8, 4e-8)
    @test t.integer==1e-6
    fixture=synthetic_wannierization_fixture()
    a=W.PAWGaugeThresholds();
    b=W.PAWGaugeThresholds(final_s_reconstruction = 1e-5)
    @test a.final_s_reconstruction==5e-6
    @test b.final_s_reconstruction==1e-5
    first_config=modified_wannierization_config(
        fixture.config;
        wavefunction_gauge_backend = W.StarCovariantPAWGauge(thresholds = a),
    )
    second_config=modified_wannierization_config(
        fixture.config;
        wavefunction_gauge_backend = W.StarCovariantPAWGauge(thresholds = b),
    )
    @test Base.invokelatest(
        W._restart_config_repr,
        first_config,
    )!=Base.invokelatest(W._restart_config_repr, second_config)
    # This shipped portable asset explicitly disallows optimizer continuation.
    # It must not acquire qualification as a side effect of parameter cleanup.
    path=joinpath(
        @__DIR__,
        "fixtures",
        "current_checkpoint_workload",
        "synthetic.wannierization.h5",
    )
    @test_throws ArgumentError W.read_wannierization_checkpoint_hdf5(path)
end

case!("fresh_selector_and_high_level_mode") do
    provider=W.SymmetryCompletedQEPAWMatrices(
        "topology.nnkp",
        "gauge.h5";
        artifact_dir = "artifacts",
    )
    @test provider.qualification_mode==:standard
    @test W.SymmetryCompletedQEPAWMatrices(
        "topology.nnkp",
        "gauge.h5";
        artifact_dir = "artifacts",
        qualification_mode = :standard,
    ).qualification_mode==:standard
    @test_throws ArgumentError W.SymmetryCompletedQEPAWMatrices(
        "topology.nnkp",
        "gauge.h5";
        artifact_dir = "artifacts",
        qualification_mode = :strict,
    )
    fixture=synthetic_wannierization_fixture()
    config=modified_wannierization_config(
        fixture.config;
        initialization = :random,
        initialization_backend = W.PAWSCDMInitialization(),
    )
    outer=[Int[1, 2], Int[1, 2]];
    frozen=[Int[], Int[]]
    error=try
        Base.invokelatest(
            W._initial_frames_with_diagnostics,
            config,
            fixture.representation,
            outer,
            frozen,
            1,
            nothing,
            nothing;
            plan = fixture.plan,
        );
        nothing
    catch e
        ;
        e
    end
    @test error isa ArgumentError
    @test occursin("INITIALIZATION_SELECTOR_CONFLICT", sprint(showerror, error))
    # A supplied legacy frame must retain its existing backend checks, rather
    # than being rejected by the new fresh-only selector guard.
    legacy=reshape(ComplexF64[1, 0, 1, 0], 2, 1, 2)
    previous=try
        Base.invokelatest(
            W._initial_frames_with_diagnostics,
            config,
            fixture.representation,
            outer,
            frozen,
            1,
            nothing,
            legacy;
            plan = fixture.plan,
        );
        nothing
    catch e
        ;
        e
    end
    @test previous isa ArgumentError
    @test occursin("SCDM_INPUT_PRECONDITION", sprint(showerror, previous))
    @test !occursin("SELECTOR_CONFLICT", sprint(showerror, previous))
end

case!("common_band_api_policy") do
    @test isdefined(WannierNLQG, :BandSelection)
    for name in (
        :BandTargets,
        :Subspace,
        :Subspaces,
        :OccupiedBands,
        :AllBands,
        :Transition,
        :InterbandGroups,
        :TripleGroups,
    )
        @test !isdefined(WannierNLQG, name)
    end
    pair=BandSelection(groups = [[1], [2]])
    single=BandSelection(groups = [[1]])
    for quantity in
        (:shift_current, :injection_current, :shift_spin_current, :injection_spin_current)
        definition=first(
            filter(
                d->R.quantity_symbol(d.quantity)==quantity &&
                   R.calculation_symbol(d.calculation)==:integral,
                R.TASK_DEFINITIONS,
            ),
        )
        @test R._task_group_observation(pair, definition, "pair").band_selection==([2], [1])
        @test R._task_group_observation(BandSelection(), definition, "total").band_selection == -1
        @test_throws ArgumentError R._task_group_observation(single, definition, "invalid")
    end
    for quantity in (:intrinsic_ahc, :orbital_magnetization)
        definition=first(
            filter(
                d->R.quantity_symbol(d.quantity)==quantity &&
                   R.calculation_symbol(d.calculation)==:integral,
                R.TASK_DEFINITIONS,
            ),
        )
        @test R._task_group_observation(single, definition, "group").band_selection != -1
        @test_throws ArgumentError R._task_group_observation(pair, definition, "pair")
    end
    for quantity in (
        :linear_transport,
        :linear_optical_response,
        :second_harmonic_generation,
        :third_harmonic_generation,
    )
        definition=first(
            filter(
                d->R.quantity_symbol(d.quantity)==quantity &&
                   R.calculation_symbol(d.calculation)==:integral,
                R.TASK_DEFINITIONS,
            ),
        )
        @test R._task_group_observation(BandSelection(), definition, "total").band_selection == -1
        @test_throws ArgumentError R._task_group_observation(single, definition, "group")
        @test_throws ArgumentError R._task_group_observation(pair, definition, "pair")
    end
end
end
