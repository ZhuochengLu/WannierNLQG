isdefined(@__MODULE__, :tbq_fixture) ||
    include(joinpath(@__DIR__, "TBSymmetryQualificationTestSupport.jl"))

@testset "Explicit TB symmetry checks preserve scientific oracles without model labels" begin
    parent=first(TBQ_W._load_wannierization_extension!())
    mktempdir() do directory
        fixtures=[
            tbq_fixture(directory),
            tbq_fixture(directory; target_subspace = true),
            tbq_fixture(directory; symmetrized = true),
            tbq_fixture(directory; antiunitary = true),
        ]
        for fixture in fixtures
            before=TBQ_IO.scientific_file_state(fixture.bundle)
            check=TBQ_W.qualify_exported_wannierization_tb(
                fixture.bundle,
                fixture.representation,
                fixture.plan;
                hamiltonian_covariance_threshold = 1.0e-10,
            )
            @test check.overall=="PASS" # Same two-operation physical toy, original thresholds.
            @test check.schema_version==TBQ_W.TB_SYMMETRY_QUALIFICATION_SCHEMA_VERSION
            @test all(m->m.status=="PASS", check.metrics)
            @test !check.global_production_eligible && !check.scoped_production_eligible
            @test TBQ_IO.scientific_file_state(fixture.bundle)==before
            HDF5.h5open(fixture.bundle, "r") do h
                @test !haskey(h, "tb_symmetry_qualification")
            end
            @test_throws ArgumentError TBQ_W.qualify_exported_wannierization_tb(
                fixture.bundle,
                fixture.representation,
                fixture.plan;
                hamiltonian_covariance_threshold = 1.0e-10,
                persist_hdf5 = true,
            )
            @test_throws ArgumentError TBQ_W.qualify_exported_wannierization_tb(
                fixture.bundle,
                fixture.representation,
                fixture.plan;
                hamiltonian_covariance_threshold = 1.0e-10,
                json_file = joinpath(directory, "validation.json"),
            )
        end
        exact=first(fixtures)
        for (kwargs, metric) in (
            ((break_hopping = true,), "hamiltonian_covariance_relative_max"),
            ((break_position = true,), "centerless_position_covariance_relative_max"),
        )
            broken=tbq_fixture(directory; kwargs...)
            check=TBQ_W.qualify_exported_wannierization_tb(
                broken.bundle,
                broken.representation,
                broken.plan;
                hamiltonian_covariance_threshold = 1.0e-10,
            )
            @test check.overall=="FAIL"
            measurements=Dict(m.name=>m for m in check.metrics)
            @test measurements[metric].status=="FAIL"
            @test measurements[metric].value>measurements[metric].threshold
        end
        missing_rep=TBQ_W.qualify_exported_wannierization_tb(
            exact.bundle,
            nothing,
            exact.plan;
            hamiltonian_covariance_threshold = 1.0e-10,
        )
        @test missing_rep.overall=="INCOMPLETE"
        @test only(
            filter(m->m.name=="kstar_spectral_residual_ev", missing_rep.metrics),
        ).status=="NOT_APPLICABLE"
        missing_plan=TBQ_W.qualify_exported_wannierization_tb(
            exact.bundle,
            exact.representation,
            nothing;
            hamiltonian_covariance_threshold = 1.0e-10,
        )
        @test missing_plan.overall=="INCOMPLETE"
        @test any(m->m.reason=="WANNIER_SYMMETRY_PLAN_NOT_AVAILABLE", missing_plan.metrics)
        no_model=TBQ_W.qualify_exported_wannierization_tb(
            joinpath(directory, "absent.h5"),
            nothing,
            nothing;
            hamiltonian_covariance_threshold = 1.0e-10,
        )
        @test no_model.overall=="NOT_RUN"
        @test all(m->m.status=="NOT_RUN", no_model.metrics)
        target=fixtures[2]
        @test_throws ArgumentError TBQ_W.qualify_exported_wannierization_tb(
            target.bundle,
            exact.representation,
            target.plan;
            hamiltonian_covariance_threshold = 1.0e-10,
        )
        for threshold in (NaN, Inf, -1.0)
            @test_throws ArgumentError TBQ_W.qualify_exported_wannierization_tb(
                exact.bundle,
                exact.representation,
                exact.plan;
                hamiltonian_covariance_threshold = threshold,
            )
        end
        # A symmetry-property result cannot turn a nonconverged solver into convergence.
        check=TBQ_W.qualify_exported_wannierization_tb(
            exact.bundle,
            exact.representation,
            exact.plan;
            hamiltonian_covariance_threshold = 1.0e-10,
        )
        result=tbq_result(TBQ_W.MAX_ITERATIONS, check, exact.bundle)
        cfg=TBQ_W.WannierizationConfig(
            input = TBQ_W.WannierizationInputConfig(eig_file = "test.eig", mmn_file = "test.mmn"),
            output = TBQ_W.WannierizationOutputConfig(final_tb_symmetry_report_enabled = true),
        )
        report=Base.invokelatest(
            parent.OperatorExport._wannier_model_report,
            result,
            cfg;
            wall_time = 0.0,
            allocated_bytes = 0,
            gc_time = 0.0,
            peak_rss_bytes = 0,
        )
        @test report["final"]["converged"]===false
        @test report["final"]["solver_status"]=="MAX_ITERATIONS"
        @test any(w->w["code"]=="MAX_ITERATIONS_REACHED", report["validation"]["warnings"])
        for version in ("1.4", "1.6", "1.7")
            @test_throws ArgumentError TBQ_W.TBSymmetryQualification(
                "NOT_RUN",
                "old schema",
                TBQ_W.TBSymmetryMetric[];
                schema_version = version,
            )
        end
    end
end

@testset "Human model summaries preserve full structured validation" begin
    exporter=first(TBQ_W._load_wannierization_extension!()).OperatorExport
    warning=Dict(
        "code"=>"PROJECTION_CENTER_RESIDUAL",
        "message"=>"Recorded center residual exceeds its limit.",
        "context"=>Dict("value"=>"5.936487923463574e-8"),
    )
    report=Dict(
        "validation"=>Dict(
            "checks"=>[
                Dict("name"=>"ISOMETRY", "value"=>1.0e-14, "threshold"=>1.0e-8, "result"=>"PASS"),
                Dict(
                    "name"=>"PROJECTION_CENTER_RESIDUAL",
                    "value"=>5.936487923463574e-8,
                    "threshold"=>1.0e-8,
                    "result"=>"FAIL",
                ),
                Dict(
                    "name"=>"NATIVE_PAW_QUALITY_CHECK",
                    "value"=>"NOT_AVAILABLE",
                    "threshold"=>1.0e-5,
                    "result"=>"NOT_AVAILABLE",
                ),
            ],
            "warnings"=>[warning, deepcopy(warning)],
            "errors"=>[
                Dict(
                    "code"=>"READ_ERROR",
                    "message"=>"Read failed.",
                    "context"=>Dict("detail"=>"first cause\nfull trace"),
                ),
                Dict(
                    "code"=>"READ_ERROR",
                    "message"=>"Read failed.",
                    "context"=>Dict("detail"=>"second cause"),
                ),
            ],
        ),
    )
    before=JSON3.write(report)
    stream=IOBuffer()
    Base.invokelatest(
        exporter._write_model_validation_summary,
        stream,
        report,
        "/tmp/actual-model.json",
    )
    text=String(take!(stream))
    @test JSON3.write(report)==before
    @test occursin("1 PASS; 1 FAIL; 1 NOT_AVAILABLE", text)
    @test occursin("FAIL (1): Projection Center Residual", text)
    @test occursin("NOT_AVAILABLE (1): Native PAW Quality Check", text)
    @test length(findall(warning["message"], text))==1
    @test occursin("WARNING (2)", text)
    @test occursin("first cause", text) && occursin("second cause", text)
    @test occursin("actual-model.json -> validation", text)
    @test all(textwidth(line)<=104 for line in split(text, '\n'))
    empty_report=Dict("validation"=>Dict("checks"=>[], "warnings"=>[], "errors"=>[]))
    stream=IOBuffer()
    Base.invokelatest(exporter._write_model_validation_summary, stream, empty_report, nothing)
    @test occursin("No checks recorded", String(take!(stream)))
    long_key=repeat("long_field_", 15)
    stream=IOBuffer()
    Base.invokelatest(exporter._write_model_report_field, stream, long_key, 42)
    text=String(take!(stream))
    @test all(textwidth(line)<=104 for line in split(text, '\n'))
    @test occursin(long_key*":", replace(text, r"\s+"=>""))
    @test occursin("42", text)
    stream=IOBuffer()
    unicode_text=repeat(String(Char.([0x53c2, 0x6570, 0x6587, 0x4ef6, 0x8def, 0x5f84])), 30)
    Base.invokelatest(exporter._model_write_text, stream, unicode_text)
    text=String(take!(stream))
    @test all(textwidth(line)<=104 for line in split(text, '\n'))
    @test replace(text, r"\s+"=>"")==unicode_text
    @test Base.invokelatest(
        exporter._model_tb_display_reason,
        "FAILED_METRICS:a,b",
    )=="2 symmetry checks exceed their limits; marked FAIL below."
    @test Base.invokelatest(exporter._model_tb_display_reason, "NOT_REQUESTED")=="NOT_REQUESTED"
end

@testset "Compact symmetry rows keep status and numeric columns aligned" begin
    exporter=first(TBQ_W._load_wannierization_extension!()).OperatorExport
    unknown=repeat("unknown_metric_", 8)
    metrics=[
        TBQ_W.TBSymmetryMetric(
            "hamiltonian_covariance_relative_max",
            7.01714999978643e-7,
            1e-8,
            "FAIL",
            "APPLICABLE",
            "EXCEEDS_PREDECLARED_THRESHOLD",
            "relative covariance",
        ),
        TBQ_W.TBSymmetryMetric(
            "centerless_position_projection_idempotence_max_angstrom",
            2.220446049250313e-16,
            1e-9,
            "PASS",
            "APPLICABLE",
            "WITHIN_PREDECLARED_THRESHOLD",
            "projection idempotence",
        ),
        TBQ_W.TBSymmetryMetric(
            "kstar_spectral_residual_ev",
            nothing,
            1e-8,
            "NOT_RUN",
            "NOT_APPLICABLE",
            "NO_DATA",
            "spectral residual",
        ),
        TBQ_W.TBSymmetryMetric(
            unknown,
            2.0,
            1.0,
            "FAIL",
            "APPLICABLE",
            "EXCEEDS_PREDECLARED_THRESHOLD",
            "future metric",
        ),
    ]
    before=JSON3.write(metrics)
    stream=IOBuffer()
    Base.invokelatest(exporter._write_tb_report, stream, (metrics = metrics,); compact = true)
    text=String(take!(stream));
    lines=split(text, '\n')
    @test JSON3.write(metrics)==before
    @test occursin("Projection idempotence", text)
    @test !occursin("centerless_position_projection_idempotence_max_angstrom", text)
    @test occursin("N/A", text) && occursin("NOT_RUN", text)
    @test all(textwidth(line)<=104 for line in lines)
    for (category, status) in
        (("Hamiltonian", "FAIL"), ("Position", "PASS"), ("Spectral", "NOT_RUN"))
        line=only(filter(line->startswith(line, category), lines))
        @test strip(String(collect(line)[70:end]))==status
    end
    continued=filter(
        line->startswith(line, "Other") ||
              (length(line)>=13 && all(isspace, line[1:13]) && !isempty(strip(line))),
        lines,
    )
    @test join(strip(String(collect(line)[14:37])) for line in continued)==unknown
    stream=IOBuffer()
    Base.invokelatest(exporter._write_tb_report, stream, (metrics = metrics[1:2], overall = "FAIL"))
    legacy=String(take!(stream))
    @test occursin("Result: FAIL", legacy) && occursin("Definitions:", legacy)
end
