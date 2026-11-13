using Test
isdefined(@__MODULE__, :tbq_fixture) ||
    include(joinpath(@__DIR__, "TBSymmetryQualificationTestSupport.jl"))
isdefined(@__MODULE__, :DiagnosticRecordTestSupport) ||
    include(joinpath(@__DIR__, "DiagnosticRecordTestSupport.jl"))

@testset "Final TB status requires complete measured evidence" begin
    extension = first(TBQ_W._load_wannierization_extension!())
    # TBSymmetryQualification.jl is included by OperatorExport, not a submodule.
    implementation = extension.OperatorExport
    names = collect(implementation.TB_SYMMETRY_REQUIRED_METRICS)
    metric(name; value = 0.0, threshold = 1e-10, status = "PASS", applicability = "APPLICABLE") =
        TBQ_W.TBSymmetryMetric(
            name,
            value,
            threshold,
            status,
            applicability,
            "contract fixture",
            "unchanged",
        )
    good = [metric(name) for name in names]
    overall(metrics) = first(implementation._final_tb_symmetry_overall(metrics))
    @test overall(good) == "PASS"
    @test overall(TBQ_W.TBSymmetryMetric[]) == "INCOMPLETE"
    @test overall(good[1:(end - 1)]) == "INCOMPLETE"
    @test_throws ArgumentError overall(vcat(good, [first(good)]))
    @test_throws ArgumentError overall([metric("unknown")])
    for replacement in (
        metric(names[1]; value = nothing),
        metric(names[1]; threshold = nothing),
        metric(names[1]; applicability = "NOT_APPLICABLE"),
        metric(names[1]; status = "NOT_RUN", value = nothing),
    )
        @test overall(vcat([replacement], good[2:end])) == "INCOMPLETE"
    end
    @test overall(vcat([metric(names[1]; value = 2e-10)], good[2:end])) == "FAIL"
    @test overall([metric(names[1]; status = "FAIL")]) == "FAIL"
    @test_throws ArgumentError metric(names[1]; value = NaN)
    mktempdir() do directory
        fixture=tbq_fixture(directory)
        exact=TBQ_W.qualify_exported_wannierization_tb(
            fixture.bundle,
            fixture.representation,
            fixture.plan;
            hamiltonian_covariance_threshold = 1e-10,
        )
        @test exact.overall == "PASS"
        @test length(exact.metrics) == 8
        # Geometry carriers may have zero stored band energies; the physical
        # spectrum comes from the nonempty Hamiltonian, not that carrier.
        bundle=TBQ_IO.read_real_space_operator_bundle(fixture.bundle)
        h=bundle.operators[TBQ_C.REAL_SPACE_HAMILTONIAN]
        rep=fixture.representation
        carrier=(;
            kpoints_fractional = rep.kpoints_fractional,
            kpoint_map = rep.kpoint_map,
            operations = rep.operations,
            energies = zeros(0, 2),
        )
        @test implementation._qualification_kstar_residual(h, ones(Int, 3), carrier)==0.0
        empty_h=(; data = zeros(ComplexF64, 0, 0, 1))
        @test_throws ArgumentError implementation._qualification_kstar_residual(
            empty_h,
            ones(Int, 1),
            carrier,
        )
        empty_mesh=(;
            kpoints_fractional = zeros(0, 3),
            kpoint_map = zeros(Int, 2, 0),
            operations = rep.operations,
        )
        @test_throws ArgumentError implementation._qualification_kstar_residual(
            h,
            ones(Int, 3),
            empty_mesh,
        )
        empty_action=(;
            kpoints_fractional = rep.kpoints_fractional,
            kpoint_map = zeros(Int, 0, 2),
            operations = [],
        )
        @test_throws ArgumentError implementation._qualification_kstar_residual(
            h,
            ones(Int, 3),
            empty_action,
        )
        identity_plan=WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
            [first(fixture.plan.operations)],
            ones(ComplexF64, 1, 1, 1),
            zeros(Int, 3, 1, 1),
        )
        @test TBQ_W.qualify_exported_wannierization_tb(
            fixture.bundle,
            rep,
            identity_plan;
            hamiltonian_covariance_threshold = 1e-10,
        ).overall=="INCOMPLETE"
        @test all(m->m.value !== nothing && m.applicability=="APPLICABLE", exact.metrics)
        for kwargs in ((break_hopping = true,), (break_position = true,))
            child=mktempdir(directory)
            broken=tbq_fixture(child; kwargs...)
            check=TBQ_W.qualify_exported_wannierization_tb(
                broken.bundle,
                broken.representation,
                broken.plan;
                hamiltonian_covariance_threshold = 1e-10,
            )
            @test check.overall == "FAIL"
            @test any(m->m.status=="FAIL" && m.value>m.threshold, check.metrics)
        end
        @test TBQ_W.qualify_exported_wannierization_tb(
            fixture.bundle,
            nothing,
            fixture.plan;
            hamiltonian_covariance_threshold = 1e-10,
        ).overall == "INCOMPLETE"
        absent=TBQ_W.qualify_exported_wannierization_tb(
            joinpath(directory, "absent.h5"),
            nothing,
            nothing;
            hamiltonian_covariance_threshold = 1e-10,
        )
        @test absent.overall == "NOT_RUN"
        @test all(m->m.value===nothing, absent.metrics)
    end
end

@testset "Source diagnostics preserve distinct measured and unavailable states" begin
    D=TBQ_W.WannierizationDiagnostic
    records=[
        D(
            :PAW_SEWING_QUALITY_CHECK,
            :info,
            "within threshold";
            context = Dict("gate_result"=>"PASS", "value"=>"0.0", "threshold"=>"1e-10"),
        ),
        D(
            :PAW_SEWING_QUALITY_CHECK,
            :warning,
            "above threshold";
            context = Dict("gate_result"=>"FAIL", "value"=>"2e-10", "threshold"=>"1e-10"),
        ),
        D(
            :PAW_SEWING_QUALITY_CHECK,
            :warning,
            "optional reference absent";
            context = Dict("gate_result"=>"NOT_AVAILABLE", "value"=>"NOT_AVAILABLE"),
        ),
    ]
    expected=DiagnosticRecordTestSupport.require_diagnostic_records(
        records,
        "PAW_SEWING_QUALITY_CHECK",
    )
    @test length(expected)==3
    @test expected==DiagnosticRecordTestSupport.diagnostic_records(
        deepcopy(records),
        "PAW_SEWING_QUALITY_CHECK",
    )
    @test expected!=DiagnosticRecordTestSupport.diagnostic_records(
        records[1:2],
        "PAW_SEWING_QUALITY_CHECK",
    )
    changed=copy(records)
    changed[1]=D(records[1].code, :warning, records[1].message; context = records[1].context)
    @test expected!=DiagnosticRecordTestSupport.diagnostic_records(
        changed,
        "PAW_SEWING_QUALITY_CHECK",
    )
    for field in ("gate_result", "value", "threshold")
        changed=deepcopy(records);
        changed[1].context[field]="altered"
        @test expected!=DiagnosticRecordTestSupport.diagnostic_records(
            changed,
            "PAW_SEWING_QUALITY_CHECK",
        )
    end
    @test_throws ArgumentError DiagnosticRecordTestSupport.require_diagnostic_records(
        records,
        "absent",
    )
end
