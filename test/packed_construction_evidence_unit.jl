module ModelConstructionReportContractUnit
using Test, WannierNLQG, HDF5, JSON3, LinearAlgebra
include("OperatorBundleTestSupport.jl")
const C=WannierNLQG.Core
const IOModel=WannierNLQG.IO
const W=WannierNLQG.Wannierization

@testset "Construction measurements stay truthful in reports, not model permission seals" begin
    r=zeros(Int, 3, 1);
    lattice=Matrix{Float64}(I, 3, 3)
    ops=Dict(
        C.REAL_SPACE_HAMILTONIAN=>C.RealSpaceOperator(
            C.RealSpaceOperatorSymmetrySpec(C.REAL_SPACE_HAMILTONIAN, 0, 1, 1),
            r,
            ones(ComplexF64, 1, 1, 1),
        ),
        C.REAL_SPACE_POSITION=>C.RealSpaceOperator(
            C.RealSpaceOperatorSymmetrySpec(C.REAL_SPACE_POSITION, 1, -1, 1),
            r,
            zeros(ComplexF64, 1, 1, 3, 1),
        ),
    )
    geometry=test_operator_bundle_geometry(lattice, [1], ops)
    # Same residuals/thresholds as the former HDF5 administrative evidence tests.
    checks=[
        ("TEST_QUALITY", 1e-7, 1e-10),
        ("PAIR_WS", 2e-8, 1e-8),
        ("COVARIANCE", 1e-7, 1e-8),
        ("FRAME_ISOMETRY", 2e-8, 1e-8),
        ("FRAME_REPLAY", 3e-8, 1e-8),
    ]
    records=[
        Dict(
            "code"=>name,
            "severity"=>"warning",
            "message"=>"Measured residual exceeds the declared threshold.",
            "context"=>Dict("value"=>value, "threshold"=>threshold, "gate_result"=>"FAIL"),
        ) for (name, value, threshold) in checks
    ]
    mktempdir() do directory
        file=joinpath(directory, "model.h5")
        IOModel.write_real_space_operator_bundle(
            file,
            lattice,
            [1],
            ops;
            profile = :hamiltonian_position,
            geometry,
            diagnostics = Dict("construction_gate_records_json"=>JSON3.write(records)),
            eligibility = Dict(
                "production_eligible"=>false,
                "physics_qualification"=>"PHYSICS_HOLD",
            ),
        )
        original=IOModel.read_real_space_operator_bundle(file)
        h5open(file, "r") do h
            @test !haskey(h, "construction_evidence") &&
                  !haskey(h, "diagnostics") &&
                  !haskey(h, "qualification")
            @test !haskey(attributes(h), "production_eligible")
        end
        # Stale/malformed administrative extras are not mathematical acceptance input.
        h5open(file, "r+") do h
            attributes(h)["physics_qualification"]="PHYSICS_HOLD"
            q=create_group(h, "qualification");
            attributes(q)["gate_json"]="{malformed"
        end
        actual=IOModel.read_real_space_operator_bundle(file)
        for kind in keys(ops)
            ;
            @test actual.operators[kind].data==original.operators[kind].data;
        end
        @test !actual.manifest.production_eligible
        extension=first(W._load_wannierization_extension!()).OperatorExport
        diagnostics=[
            W.WannierizationDiagnostic(
                Symbol(name),
                :warning,
                "Measured residual exceeds the declared threshold.";
                context = Dict("value"=>string(value), "threshold"=>string(threshold)),
            ) for (name, value, threshold) in checks
        ]
        result=W.WannierizationResult(
            W.MAX_ITERATIONS,
            ones(ComplexF64, 1, 1, 1),
            zeros(1, 3),
            [1.0],
            [W.WannierizationIteration(1, 1.0, 1e-7, 0.0)],
            diagnostics,
            Dict(
                "construction_gate_records_json"=>JSON3.write(records),
                "stopping_reason"=>"MAX_ITERATIONS_REACHED",
            ),
            nothing,
            nothing,
        )
        config=W.WannierizationConfig(
            input = W.WannierizationInputConfig(eig_file = "test.eig", mmn_file = "test.mmn"),
            output = W.WannierizationOutputConfig(model_file = file),
        )
        log=joinpath(directory, "model.out")
        open(log, "w") do stream
            Base.invokelatest(
                extension.write_wannierization_final,
                stream,
                result,
                config,
                W.WannierizationArtifacts(wannierization_log = log);
                wall_time = 0.0,
                allocated_bytes = 0,
                gc_time = 0.0,
                peak_rss_bytes = 0,
            )
        end
        report=JSON3.read(read(joinpath(directory, "model.json"), String))
        @test report.final.converged===false
        @test report.final.solver_status=="MAX_ITERATIONS"
        @test length(report.validation.checks)==length(checks)
        for ((name, value, threshold), entry) in zip(checks, report.validation.checks)
            @test entry.name==name && entry.value==value && entry.threshold==threshold
            @test entry.result=="FAIL"
        end
        @test any(w->w.code=="MAX_ITERATIONS_REACHED", report.validation.warnings)
        @test !occursin("PHYSICS_HOLD", read(log, String))
        @test !occursin("[FILES]", read(log, String))
    end
end
end
