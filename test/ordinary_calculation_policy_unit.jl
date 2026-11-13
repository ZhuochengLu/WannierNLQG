module OrdinaryCalculationPolicyUnit
using Test, LinearAlgebra, SHA, WannierNLQG
const CoreLayer = WannierNLQG.Core
const MatrixLayer = WannierNLQG.MatrixElements
const IOLayer = WannierNLQG.IO
const Foundation = WannierNLQG.SymmetryFoundation

include(joinpath(@__DIR__, "NativeDefinitionTestSupport.jl"))
using .NativeDefinitionTestSupport: native_definition_bytes

@testset "Retained compiler captures remain inactive for the new source" begin
    @test WannierNLQG.FIRST_USE_TRACE_COMPATIBLE === false
end

@testset "Removed strict construction is an invalid parameter" begin
    @test CoreLayer.validate_ordinary_construction_policy(:standard) === nothing
    exception = try
        CoreLayer.validate_ordinary_construction_policy(:strict)
        nothing
    catch error
        error
    end
    @test exception isa ArgumentError
    @test occursin("invalid parameter", sprint(showerror, exception))
    @test occursin("Remove construction_policy", sprint(showerror, exception))
    @test_throws ArgumentError CoreLayer.validate_ordinary_construction_policy(:unknown)
end

@testset "Declared input digest lifetime and real changes" begin
    mktempdir() do directory
        input = joinpath(directory, "input.dat")
        output = joinpath(directory, "output.dat")
        write(input, "declared input")
        write(output, "first output")
        hashes = Ref(0)
        hasher(path) = (hashes[] += 1; open(io -> bytes2hex(SHA.sha256(io)), path, "r"))
        expected = hasher(input)
        hashes[] = 0
        IOLayer.with_verified_file_digests([input]; file_hasher = hasher) do
            @test IOLayer.sha256_file(input) == expected
            @test Foundation.sha256_file(input) == expected
            @test WannierNLQG.Runtime.checksum_file(input) == expected
            @test hashes[] == 1
            Foundation.with_verified_file_digests([input]) do
                @test IOLayer.sha256_file(input) == expected
            end
            @test hashes[] == 1
            previous = IOLayer.sha256_file(output)
            write(output, "second longer generated output")
            @test IOLayer.sha256_file(output) != previous
            write(input, "changed declared input content and size")
            @test_throws ArgumentError IOLayer.sha256_file(input)
        end
        @test get(task_local_storage(), :wannier_verified_file_digests, nothing) === nothing
        @test IOLayer.sha256_file(input) != expected
        @test_throws ErrorException IOLayer.with_verified_file_digests([input]) do
            error("callback failed")
        end
        @test get(task_local_storage(), :wannier_verified_file_digests, nothing) === nothing
    end
end

@testset "Finite raw defects use one retained effective model" begin
    lattice = Matrix{Float64}(I, 3, 3)
    vectors = reshape([0, 0, 0], 3, 1)
    h = reshape(ComplexF64[-1 3e-8; 0 1], 2, 2, 1)
    s = reshape(ComplexF64[1 8e-9; 0 1], 2, 2, 1)
    r = zeros(ComplexF64, 2, 2, 3, 1)
    r[1, 2, 1, 1] = 2e-5
    model = @test_logs (:warn, r"Localized input defects") CoreLayer.NonorthogonalLocalizedModel(
        lattice = lattice,
        r_vectors = vectors,
        hamiltonian_r = h,
        overlap_r = s,
        position_r = r,
    )
    @test model.raw_hamiltonian_r == h
    @test model.raw_overlap_r == s
    @test model.raw_position_r == r
    @test model.hamiltonian_r[:, :, 1] == (h[:, :, 1] + h[:, :, 1]') / 2
    @test model.overlap_r[:, :, 1] == (s[:, :, 1] + s[:, :, 1]') / 2
    @test model.position_r[:, :, 1, 1] == (r[:, :, 1, 1] + r[:, :, 1, 1]') / 2
    @test model.representation_diagnostics.raw.position_translation_max_entry_angstrom == 2e-5
    @test model.representation_diagnostics.effective.position_translation_max_entry_angstrom == 0
    @test model.representation_diagnostics.adjustment.position_max_entry_angstrom == 1e-5
    @test model.representation_diagnostics.raw_file_modified === false
    plan = MatrixLayer.compile_matrix_plan(
        MatrixLayer.MatrixElementRequest(MatrixLayer.SPECTRUM);
        source_gauge_required = false,
    )
    workspace = MatrixLayer.MatrixElementWorkspace(model, plan)
    spectrum = MatrixLayer.compute_spectrum!(workspace, model, [0.0, 0.0, 0.0])
    diagnostics = MatrixLayer.nonorthogonal_metric_diagnostics(workspace)
    @test all(isfinite, spectrum.energies)
    @test diagnostics.normalized_eigen_residual < 1e-13
    @test diagnostics.metric_normalization_residual < 1e-13
    @test diagnostics.original_metric_normalization_residual > 1e-10
    @test diagnostics.original_normalized_eigen_residual > 1e-10
    MatrixLayer.compute_spectrum!(workspace, model, [0.1, 0.2, 0.3])
    mesh = MatrixLayer.nonorthogonal_metric_diagnostics(workspace; scope = :workspace)
    @test mesh.measurements[:spectrum_evaluations] == 2
    @test mesh.measurements[:original_normalized_eigen_residual] >=
          diagnostics.original_normalized_eigen_residual
    MatrixLayer.compute_spectrum!(workspace, model, [0.1, 0.2, 0.3])
    @test MatrixLayer.nonorthogonal_metric_diagnostics(workspace; scope = :workspace).measurements[:spectrum_evaluations] ==
          2
    snapshot = copy(mesh.measurements)
    empty!(mesh.measurements)
    @test MatrixLayer.nonorthogonal_metric_diagnostics(workspace; scope = :workspace).measurements ==
          snapshot
    @test_throws ArgumentError MatrixLayer.nonorthogonal_metric_diagnostics(
        workspace;
        scope = :unknown,
    )
    merged = WannierNLQG.Runtime.progress_localized_run_diagnostics!([workspace], nothing)
    @test merged.measurements == snapshot
    # Constructor and solving must not mutate caller-owned raw arrays.
    @test h[1, 2, 1] == 3e-8
    @test s[1, 2, 1] == 8e-9
    @test r[1, 2, 1, 1] == 2e-5
    bad_s = copy(s);
    bad_s[1, 1, 1] = NaN
    @test_throws ArgumentError CoreLayer.NonorthogonalLocalizedModel(
        lattice = lattice,
        r_vectors = vectors,
        hamiltonian_r = h,
        overlap_r = bad_s,
        position_r = r,
    )
    negative = CoreLayer.NonorthogonalLocalizedModel(
        lattice = lattice,
        r_vectors = vectors,
        hamiltonian_r = model.hamiltonian_r,
        overlap_r = reshape(ComplexF64[-1 0; 0 -1], 2, 2, 1),
        position_r = nothing,
    )
    negative_workspace = MatrixLayer.MatrixElementWorkspace(negative, plan)
    @test_throws ArgumentError MatrixLayer.compute_spectrum!(negative_workspace, negative, zeros(3))
end

@testset "Parsed native source and array identities remain independent" begin
    mktempdir() do directory
        source = joinpath(directory, "source.dat")
        write(source, "original parsed source")
        model = CoreLayer.NonorthogonalLocalizedModel(
            lattice = Matrix{Float64}(I, 3, 3),
            r_vectors = zeros(Int, 3, 1),
            hamiltonian_r = reshape(ComplexF64[-1 0; 0 1], 2, 2, 1),
            overlap_r = reshape(Matrix{ComplexF64}(I, 2, 2), 2, 2, 1),
            position_r = nothing,
        )
        input = CoreLayer.NonorthogonalLocalizedInput(
            model;
            source_file = source,
            parameters = (file_identity = IOLayer.scientific_file_identity(source),),
        )
        legacy = CoreLayer.NonorthogonalLocalizedInput(
            model;
            source_file = source,
            parameters = (file_sha256 = repeat("0", 64),),
        )
        @test_throws ArgumentError("NATIVE_SOURCE_LEGACY_CHECKSUM_BINDING_UNSUPPORTED") native_definition_bytes(
            legacy,
        )
        effective = WannierNLQG.Runtime.EffectiveTaskConfig(
            native_model_input = input,
            fourier_backend = "direct",
        )
        @test isempty(WannierNLQG.Runtime.runtime_input_source_paths(effective, nothing))
        @test IOLayer.native_source_file_identity(input) == input.parameters.file_identity
        baseline = native_definition_bytes(input)
        IOLayer.with_verified_file_digests([source]) do
            @test native_definition_bytes(input) == baseline
            # The wrapper now owns an independent model. This negative fixture
            # modifies the adopted payload, not the detached caller's original.
            input.model.hamiltonian_r[1, 1, 1] -= 0.1
            @test native_definition_bytes(input) != baseline
            input.model.hamiltonian_r[1, 1, 1] += 0.1
            @test native_definition_bytes(input) == baseline
        end
        write(source, "different source after parsing")
        exception = try
            native_definition_bytes(input)
            nothing
        catch error
            error
        end
        @test exception isa ArgumentError
        @test occursin("NATIVE_SOURCE_FILE_IDENTITY_MISMATCH", sprint(showerror, exception))
    end
end

@testset "Ordinary Band reports a finite Hermiticity warning" begin
    file = joinpath(
        @__DIR__,
        "..",
        "examples",
        "symmetrization",
        "fixture",
        "inputs",
        "synthetic_tb.dat",
    )
    model = IOLayer.read_wannier_tb(file)
    model.hamiltonian_r[1, 1, 1] += 1e-7im
    plan = MatrixLayer.compile_matrix_plan(
        MatrixLayer.MatrixElementRequest(MatrixLayer.SPECTRUM);
        source_gauge_required = false,
    )
    workspace = MatrixLayer.MatrixElementWorkspace(model, plan)
    measured = MatrixLayer.compute_checked_spectrum!(
        workspace,
        model,
        zeros(3);
        hermiticity_tolerance = 1e-12,
    )
    @test all(isfinite, measured.spectrum.energies)
    @test measured.hermiticity_residual > 1e-12
    @test measured.hermiticity_exceeds_tolerance
    @test_throws ArgumentError MatrixLayer.compute_checked_spectrum!(
        workspace,
        model,
        zeros(3);
        hermiticity_tolerance = NaN,
    )
end

"""Write a synthetic result group with a deliberately different historical producer."""
function write_policy_transport_fixture(directory; legacy = false)
    axis = [-0.1, 0.2]
    source_key = legacy ? "release_tree_sha256" : "producer_package_version"
    schema =
        legacy ? "wanniernlqg.linear-transport-vector/2.0" :
        "wanniernlqg.linear-transport-vector/6.0"
    headers = Pair{String, String}[
        "schema" => schema,
        "quantity" => "linear_transport",
        "method" => "conventional",
        "temperature_K" => "300.0",
        "fermi_energies_count" => "2",
        "fermi_energies_definition" => CoreLayer.fermi_energy_axis_definition(axis),
        source_key => (legacy ? repeat("0", 64) : "0.9.0"),
        "model_identity" => repeat("a", 64),
        "input_identity" => repeat("b", 64),
        "gamma_intra_ev" => "0.04",
        "gamma_inter_ev" => "0.05",
        "fs_kind" => "gaussian",
        "eta_fs_ev" => "0.02",
        "mpi_size" => "1",
        "julia_threads_per_rank" => "1",
        "qualification_status" => (legacy ? "DIAGNOSTIC_ONLY" : "COMPUTATION_READY"),
        "input_semantics" => "effective_position_operator_model",
        "operator_inventory" => "NOT_APPLICABLE_DEFINED_FINITE_MODEL",
        "operator_model_schema" => "NOT_APPLICABLE_DEFINED_FINITE_MODEL",
        "content_authentication" => "NOT_PERFORMED",
    ]
    push!(headers, "task_definition" => IOLayer.spectral_task_definition(headers))
    labels = [string(a, b) for a in "xyz" for b in "xyz"]
    for term in ("drude", "quantum_metric", "berry_curvature", "total")
        IOLayer.write_spectral_response_table(
            joinpath(directory, "linear_transport_"*term*".dat"),
            reshape(axis, :, 1),
            ["mu_eV"],
            zeros(ComplexF64, 2, 9),
            labels;
            units = "S/m",
            headers = vcat(headers, ["term"=>term]),
        )
    end
    IOLayer.write_spectral_response_metadata(
        joinpath(directory, "spectral_response_metadata.txt"),
        Dict(headers),
    )
    return axis
end

@testset "Historical producer identity is independent of this installation" begin
    mktempdir() do directory
        for legacy in (false, true)
            path = joinpath(directory, legacy ? "legacy" : "ordinary")
            expected = write_policy_transport_fixture(path; legacy)
            if legacy
                @test_throws ErrorException("VECTOR_RESPONSE_SCHEMA_MISMATCH") IOLayer.read_linear_transport_result(
                    path,
                )
                continue
            end
            result = IOLayer.read_linear_transport_result(path)
            @test result.fermi_energies == expected
            @test all(iszero, result.tensors[:total])
            @test result.metadata[legacy ? "release_tree_sha256" : "producer_package_version"] ==
                  (legacy ? repeat("0", 64) : "0.9.0")
            # Historical status is preserved; the reader does not manufacture new qualification.
            @test result.metadata["qualification_status"] ==
                  (legacy ? "DIAGNOSTIC_ONLY" : "COMPUTATION_READY")
            total = joinpath(path, "linear_transport_total.dat")
            text = read(total, String)
            write(
                total,
                replace(
                    text,
                    "# model_identity="*repeat("a", 64)=>"# model_identity="*repeat("c", 64);
                    count = 1,
                ),
            )
            @test_throws ErrorException IOLayer.read_linear_transport_result(path)
            write(total, text)
            write(total, replace(text, "# units=S/m"=>"# units=unregistered"; count = 1))
            @test_throws ErrorException IOLayer.read_linear_transport_result(path)
        end
    end
end
@testset "Ordinary typed readiness does not inherit source qualification" begin
    runtime = WannierNLQG.Runtime
    for historical_production in (false, true)
        result = runtime._finalize_response_qualification(
            historical_production,
            false,
            String["input.structure"],
            String[],
            String[],
            String[],
            Dict{String, Any}(),
        )
        @test result.execution_eligible
        @test result.qualification_status == "COMPUTATION_READY"
        @test !result.production_eligible
        @test !result.quality_review_recommended
    end
    @test_throws runtime.ResponseQualificationError runtime._finalize_response_qualification(
        false,
        false,
        String[],
        String[],
        String["input.identity"],
        String[],
        Dict{String, Any}(),
    )
end

@testset "Aggregate readiness preserves ordinary and historical meanings" begin
    runtime = WannierNLQG.Runtime
    record(status; ready = true, production = false, review = false) =
        runtime.ResponseQualificationResult(
            ready,
            status,
            production,
            review,
            String[],
            String[],
            String[],
            String[],
            Dict{String, Any}(),
        )
    combine = runtime.aggregate_response_qualifications
    ordinary = combine([record("COMPUTATION_READY"), record("COMPUTATION_READY")])
    @test ordinary.execution_eligible
    @test ordinary.qualification_status == "COMPUTATION_READY"
    @test !ordinary.production_eligible
    @test !ordinary.quality_review_recommended
    @test combine([record("COMPUTATION_READY"; review = true)]).quality_review_recommended
    historical = combine([record("PASS"; production = true), record("PASS"; production = true)])
    @test historical.qualification_status == "PASS"
    @test historical.production_eligible
    @test combine([record("DIAGNOSTIC_ONLY"; review = true)]).qualification_status ==
          "DIAGNOSTIC_ONLY"
    @test combine([record("COMPUTATION_READY"), record("DIAGNOSTIC_ONLY")]).qualification_status ==
          "DIAGNOSTIC_ONLY"
    @test !combine([record("COMPUTATION_READY"), record("DIAGNOSTIC_ONLY"; ready = false)]).execution_eligible
    @test combine([runtime.not_evaluated_response_qualification()]).qualification_status ==
          "NOT_EVALUATED"
    @test combine(runtime.ResponseQualificationResult[]).qualification_status == "NOT_EVALUATED"
end

@testset "Finite quality diagnostics preserve structural failures" begin
    extension = first(WannierNLQG.Wannierization._load_wannierization_extension!())
    solver = extension.SolverCheckpoint
    W = WannierNLQG.Wannierization
    diagnostic(code, context) =
        W.WannierizationDiagnostic(code, :error, "controlled residual"; context)
    for code in (
        :ANTIUNITARY_PROJECTOR_COVARIANCE_FAILED,
        :TARGET_REPRESENTATION_GROUP_LAW_FAILED,
        :REQUIRED_BLOCK_UNITARITY_FAILED,
        :ANTIUNITARY_GROUP_LAW_FAILED,
        :THETA_SQUARED_FAILED,
    )
        @test solver._construction_compatibility_quality_failure(
            diagnostic(code, Dict("maximum_error"=>"0.01", "tolerance"=>"1e-8")),
        )
        @test !solver._construction_compatibility_quality_failure(
            diagnostic(code, Dict("maximum_error"=>"NaN", "tolerance"=>"1e-8")),
        )
        @test !solver._construction_compatibility_quality_failure(
            diagnostic(code, Dict("maximum_error"=>"Inf", "tolerance"=>"1e-8")),
        )
        @test !solver._construction_compatibility_quality_failure(
            diagnostic(code, Dict("band_count"=>"2", "target_count"=>"3")),
        )
    end
    @test !solver._construction_compatibility_quality_failure(
        diagnostic(
            :SEWING_BLOCK_RANK_DEFICIENT,
            Dict(
                "maximum_error"=>"1.0",
                "tolerance"=>"1e-8",
                "required_rank"=>"2",
                "numerical_rank"=>"1",
            ),
        ),
    )
    summary = Dict{String, String}()
    solver._record_terminal_state!(
        summary,
        W.MAX_ITERATIONS,
        W.WannierizationDiagnostic[],
        W.WannierizationIteration[],
        1,
        0,
    )
    @test summary["solver_convergence"] == "MAX_ITERATIONS"
    @test summary["quality_review_recommended"] == "true"
    @test summary["model_qualification"] == "COMPUTATION_READY"
end

@testset "Versioned construction records retain historical seals" begin
    extension = Base.get_extension(WannierNLQG, :WannierNLQGOperatorBundleExt)
    @test extension !== nothing
    @test extension._standard_operator_qualification(
        Dict("ordinary_calculation_policy_version"=>"1.0"),
    )
    @test !extension._standard_operator_qualification(Dict{String, Any}())
    @test_throws ArgumentError extension._standard_operator_qualification(
        Dict("ordinary_calculation_policy_version"=>"unknown"),
    )
    values = Dict{String, Any}(
        "schema"=>"wanniernlqg.construction-evidence",
        "schema_version"=>"1.1",
        "construction_policy"=>"standard",
        "construction_gate_records_json"=>"[]",
        "quality_review_recommended"=>false,
        "construction_quality_failed"=>false,
        "model_availability"=>"AVAILABLE",
        "production_eligible"=>false,
    )
    @test extension._validated_construction_evidence(values) === values
    historical = merge(values, Dict("schema_version"=>"1.0", "quality_review_recommended"=>true))
    @test extension._validated_construction_evidence(historical) === historical
    @test historical["schema_version"] == "1.0"
    @test_throws ArgumentError extension._validated_construction_evidence(
        merge(historical, Dict("quality_review_recommended"=>false)),
    )
    @test_throws ArgumentError extension._validated_construction_evidence(
        merge(values, Dict("production_eligible"=>true)),
    )
    warning = merge(
        values,
        Dict(
            "construction_quality_failed"=>true,
            "model_availability"=>"AVAILABLE_WITH_QUALITY_WARNINGS",
        ),
    )
    @test_throws ArgumentError extension._validated_construction_evidence(warning)
    warning["quality_review_recommended"] = true
    @test extension._validated_construction_evidence(warning) === warning
    @test_throws ArgumentError extension._validated_construction_evidence(
        merge(warning, Dict("model_availability"=>"AVAILABLE")),
    )
    @test_throws ArgumentError extension._validated_construction_evidence(
        merge(values, Dict("schema_version"=>"unknown")),
    )
end

@testset "Streaming file observations never certify scientific contents" begin
    mktempdir() do directory
        path = joinpath(directory, "owned-input")
        write(path, "0123456789")
        observed = IOLayer.with_scientific_source(path) do filename
            read(filename, String)
        end
        @test observed.value == "0123456789"
        @test IOLayer.observe_scientific_source(path) == observed.state
        record = IOLayer.scientific_file_record(observed.state)
        @test record["schema"] == "wanniernlqg.local-file-publication/1"
        @test IOLayer.validate_scientific_file_record(record, observed.state) === nothing
        @test IOLayer.with_scientific_source(read, path; expected_record = record).value ==
              codeunits("0123456789")
        wrong = merge(record, Dict("bytes" => true))
        @test_throws ArgumentError IOLayer.with_scientific_source(
            read,
            path;
            expected_record = wrong,
        )
        @test_throws ArgumentError IOLayer.with_scientific_source(
            read,
            path;
            expected_record = merge(record, Dict("waiver" => true)),
        )
        @test_throws ArgumentError IOLayer.with_scientific_source(path) do filename
            value = read(filename)
            open(filename, "a") do stream
                write(stream, UInt8(0))
            end
            value
        end
        @test_throws ArgumentError IOLayer.with_scientific_source(
            read,
            path;
            expected_record = record,
        )
    end
end

@testset "Native declaration setup observes files without enrolling checksum inputs" begin
    runtime = WannierNLQG.Runtime
    mktempdir() do directory
        model = CoreLayer.NonorthogonalLocalizedModel(;
            lattice = Matrix{Float64}(I, 3, 3),
            r_vectors = zeros(Int, 3, 1),
            hamiltonian_r = reshape(ComplexF64[0.2], 1, 1, 1),
            overlap_r = reshape(ComplexF64[1], 1, 1, 1),
            position_r = nothing,
        )
        declaration = joinpath(directory, "declaration")
        write(declaration, "adopted later by the native symmetry reader")
        cfg = runtime.EffectiveTaskConfig(;
            native_model_input = CoreLayer.NonorthogonalLocalizedInput(model),
            response_symmetry_file = declaration,
            fourier_backend = "direct",
        )
        @test isempty(runtime.runtime_input_source_paths(cfg, nothing))
        entered = Ref(false)
        runtime.with_runtime_input_sources([cfg], [nothing]) do
            entered[] = true
        end
        @test entered[]
        rm(declaration)
        entered[] = false
        @test_throws ErrorException runtime.with_runtime_input_sources([cfg], [nothing]) do
            entered[] = true
        end
        @test !entered[]
    end
end

@testset "Ordinary Runtime admits and closes actual source lifetimes" begin
    runtime=WannierNLQG.Runtime
    mktempdir() do directory
        path=joinpath(directory, "model.dat")
        cp(
            joinpath(
                @__DIR__,
                "..",
                "examples",
                "fixtures",
                "synthetic_runtime",
                "synthetic_tb.dat",
            ),
            path,
        )
        cfg=runtime.EffectiveTaskConfig(;
            model_file = path,
            output_root = joinpath(directory, "out"),
            fourier_backend = "direct",
        )
        specs=runtime.validate_config(cfg)
        state=IOLayer.observe_scientific_source(path)
        @test IOLayer.validate_scientific_source_state(state)===nothing
        context=runtime.prepare_run_context(cfg, specs)
        @test startswith(context.model_identity, "wanniernlqg.file-state/1:")
        @test context.model_identity==IOLayer.scientific_file_identity(state)
        @test runtime.with_runtime_input_sources([cfg], [specs]) do
            @test get(task_local_storage(), :wannier_verified_file_digests, nothing)===nothing
            7
        end == 7
        changed=Ref(false)
        @test_throws ErrorException runtime.with_runtime_input_sources([cfg], [specs]) do
            changed[]=true
            open(path, "a") do stream
                write(stream, "\n")
            end
            :completed_callback
        end
        @test changed[]
        @test_throws ArgumentError IOLayer.validate_scientific_source_state(state)
        replacement=IOLayer.observe_scientific_source(path)
        @test IOLayer.validate_scientific_source_state(replacement)===nothing
        rm(path)
        entered=Ref(false)
        @test_throws ErrorException runtime.with_runtime_input_sources([cfg], [specs]) do
            entered[]=true
        end
        @test !entered[]
        @test get(task_local_storage(), :wannier_verified_file_digests, nothing)===nothing
    end
end

end
