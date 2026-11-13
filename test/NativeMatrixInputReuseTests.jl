using Test, JSON3, MPI
include("NativeMatrixInputReuseTestSupport.jl")
include("NativeFullOperatorPosthocTests.jl")
const NativeReuseSupport = NativeMatrixInputReuseTestSupport

"""Compare transport fields by complete values, not immutable-record identity."""
function native_transport_values_equal(left, right)
    typeof(left) == typeof(right) || return false
    left isa Union{Number, Symbol, AbstractString, Nothing, AbstractArray, AbstractDict} &&
        return isequal(left, right)
    return all(
        name -> native_transport_values_equal(getfield(left, name), getfield(right, name)),
        fieldnames(typeof(left)),
    )
end

"""Exercise the public new-trajectory entry against the original native solve."""
function native_matrix_input_reuse_cases(f; parallel = :serial)
    w = WannierNLQG.Wannierization
    mpi_execution = parallel == :mpi
    rank = mpi_execution ? MPI.Comm_rank(MPI.COMM_WORLD) : 0
    same_reference = copy(f.reference)
    native_root = f.config.input.matrix_elements.artifact_dir
    before = NativeReuseSupport.inventory(native_root)
    source_before = NativeReuseSupport.inventory(joinpath(f.root, "source"))
    retained_before =
        Dict(path => read(path) for path in readdir(f.root; join = true) if isfile(path))
    prior_context = get(task_local_storage(), :wannier_preparation_storage, nothing)
    return @testset "Native accepted-input new trajectory" begin
        @testset "QE VASP fields and raw solver MMN aliases" begin
            extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)
            publish_views =
                extension.resolve_wannierization_entrypoint(:_publish_native_input_views)
            adopt_views = extension.resolve_wannierization_entrypoint(:_adopt_native_input_views)
            phase = extension.resolve_wannierization_entrypoint(:_native_input_reuse_phase)
            saved = WannierNLQG.IO.read_preparation_checkpoint(
                same_reference["path"],
                "native-matrix-acceptance/2",
            ).resolved
            raw = saved.paw_result.mmn
            distinct = WannierNLQG.IO.WannierMMN(
                raw.num_bands,
                raw.num_kpts,
                raw.num_neighbors,
                copy(raw.data),
                copy(raw.neighbors),
                copy(raw.reciprocal_shifts),
            )
            # This is a transport-only record, not a synthetic physical acceptance.
            vasp = w.VASPPAWMatrixElementResult(
                distinct,
                saved.paw_result.amn,
                deepcopy(saved.paw_result.amn),
                nothing,
                nothing,
                nothing,
                1.0,
                2.0,
                3.0,
                4.0,
                false,
                ["transport-only retained warning"],
                Dict("fixture" => "transport-only"),
                Dict{String, String}(),
            )
            for original in (saved, merge(saved, (; paw_result = vasp)))
                # Retain owned backing through the complete adoption test.
                directory = mktempdir(; cleanup = false)
                packed = phase(mpi_execution, "test_shared_transport_publication") do
                    rank == 0 ? publish_views(original, directory) : nothing
                end
                mpi_execution && (packed = MPI.bcast(packed, 0, MPI.COMM_WORLD))
                adopted = phase(mpi_execution, "test_shared_transport_adoption") do
                    adopt_views(packed)
                end
                @test isequal(adopted.mmn.data, original.mmn.data)
                @test (adopted.mmn.data === adopted.paw_result.mmn.data) ==
                      (original.mmn.data === original.paw_result.mmn.data)
                @test isequal(adopted.paw_result.mmn.data, original.paw_result.mmn.data)
                @test typeof(adopted.paw_result) == typeof(original.paw_result)
                @test all(
                    name ->
                        name == :mmn || native_transport_values_equal(
                            getfield(adopted.paw_result, name),
                            getfield(original.paw_result, name),
                        ),
                    fieldnames(typeof(original.paw_result)),
                )
                @test adopted.paw_result.passed == original.paw_result.passed
                changed =
                    (!mpi_execution || rank == 1) ?
                    merge(
                        packed,
                        (;
                            mmn = merge(
                                packed.mmn,
                                (;
                                    descriptor = merge(
                                        packed.mmn.descriptor,
                                        (; path = joinpath(directory, "missing.bin")),
                                    )
                                ),
                            )
                        ),
                    ) : packed
                error_value = try
                    phase(mpi_execution, "test_single_rank_shared_adoption") do
                        adopt_views(changed)
                    end
                    nothing
                catch exception
                    exception
                end
                @test error_value isa ArgumentError
                @test occursin("test_single_rank_shared_adoption", sprint(showerror, error_value))
            end
        end
        @testset "Immutable shared MMN layout and lifetime" begin
            mktempdir() do directory
                values = reshape(ComplexF64[complex(i, -i / 7) for i in 1:24], 2, 2, 2, 3)
                descriptor = WannierNLQG.IO.publish_preparation_shared_array(directory, values)
                first_view = WannierNLQG.IO.read_preparation_shared_array(descriptor)
                second_view = WannierNLQG.IO.read_preparation_shared_array(descriptor)
                @test first_view isa Array{ComplexF64, 4}
                @test isequal(first_view, values)
                @test isequal(second_view, values)
                for rank in 0:11
                    partition_view = WannierNLQG.IO.read_preparation_shared_array(
                        descriptor;
                        finite_partition = (rank, 12),
                    )
                    @test isequal(partition_view, values)
                end
                @test_throws ArgumentError WannierNLQG.IO.read_preparation_shared_array(
                    descriptor;
                    finite_partition = (12, 12),
                )
                @test stat(descriptor.path).mode & 0o222 == 0
                @test filesize(descriptor.path) == sizeof(values)
                @test_throws ArgumentError WannierNLQG.IO.read_preparation_shared_array(
                    merge(descriptor, (; dimensions = (2, 2, 2, 4))),
                )
                @test_throws ArgumentError WannierNLQG.IO.publish_preparation_shared_array(
                    directory,
                    fill(ComplexF64(NaN), 1, 1, 1, 1),
                )
                # Separate copies avoid truncating a file still mapped by this process.
                short_path = joinpath(directory, "short.bin")
                write(short_path, UInt8[0])
                @test_throws ArgumentError WannierNLQG.IO.read_preparation_shared_array(
                    merge(
                        descriptor,
                        (;
                            path = short_path,
                            state = WannierNLQG.IO.scientific_file_state(short_path),
                        ),
                    ),
                )
                invalid_path = joinpath(directory, "invalid.bin")
                write(invalid_path, fill(ComplexF64(NaN), size(values)))
                @test_throws ArgumentError WannierNLQG.IO.read_preparation_shared_array(
                    merge(
                        descriptor,
                        (;
                            path = invalid_path,
                            state = WannierNLQG.IO.scientific_file_state(invalid_path),
                        ),
                    ),
                )
                one_invalid = copy(values)
                one_invalid[19] = ComplexF64(NaN)
                one_invalid_path = joinpath(directory, "one-invalid.bin")
                write(one_invalid_path, one_invalid)
                one_invalid_descriptor = merge(
                    descriptor,
                    (;
                        path = one_invalid_path,
                        state = WannierNLQG.IO.scientific_file_state(one_invalid_path),
                    ),
                )
                failures = Int[]
                for rank in 0:11
                    try
                        WannierNLQG.IO.read_preparation_shared_array(
                            one_invalid_descriptor;
                            finite_partition = (rank, 12),
                        )
                    catch exception
                        exception isa ArgumentError || rethrow()
                        push!(failures, rank)
                    end
                end
                @test failures == [9]
                replaced = joinpath(directory, "replaced.bin")
                cp(descriptor.path, replaced)
                @test_throws ArgumentError WannierNLQG.IO.read_preparation_shared_array(
                    merge(descriptor, (; path = replaced)),
                )
            end
        end
        @testset "Original native values and dense streaming ownership" begin
            for mode in (:dense_reference, :streaming_serial)
                cfg = NativeReuseSupport.reuse_config(f, "$(parallel)-$(mode)"; parallel, mode)
                result = w.construct_wannier_functions_with_native_inputs(cfg, same_reference)
                @test result.restart_state !== nothing
                @test result.status == f.baseline.status
                @test isequal(result.v_matrix, f.baseline.v_matrix)
                @test isequal(result.spreads_angstrom2, f.baseline.spreads)
                @test isequal(result.wannier_centers_cartesian, f.baseline.centers)
                @test result.input_summary["native_matrix_input_origin"] ==
                      "VALIDATED_ACCEPTED_INPUT_REUSE_NEW_OPTIMIZER_TRAJECTORY"
                @test JSON3.read(
                    result.input_summary["native_matrix_acceptance_json"],
                    Dict{String, String},
                ) == same_reference
                @test result.input_summary["matrix_element_source"] == "native_qe_paw"
                @test get(task_local_storage(), :wannier_preparation_storage, nothing) ===
                      prior_context
                @test !get(
                    task_local_storage(),
                    :wannier_native_input_shared_fresh_definition,
                    false,
                )
                if mpi_execution
                    definition = result.restart_state.input_definition
                    local_records = map((
                        definition.representation,
                        definition.overlaps,
                        definition.initialization,
                    )) do value
                        (; path = value.path, state = value.state, byte_count = value.byte_count)
                    end
                    root_records = MPI.bcast(rank == 0 ? local_records : nothing, 0, MPI.COMM_WORLD)
                    @test local_records == root_records
                end
            end
            @test NativeReuseSupport.inventory(native_root) == before
        end
        @testset "Malformed reference and restart are collective failures" begin
            cfg = NativeReuseSupport.reuse_config(f, "bad-reference"; parallel)
            bad = copy(same_reference)
            (!mpi_execution || rank == 1) && (bad["schema"] = "unsupported")
            error_value = try
                w.construct_wannier_functions_with_native_inputs(cfg, bad)
                nothing
            catch exception
                exception
            end
            @test error_value isa ArgumentError
            @test occursin("NATIVE_INPUT_REUSE_PREPARATION_FAILED", sprint(showerror, error_value))
            @test !ispath(cfg.output.model_file)
            @test get(task_local_storage(), :wannier_preparation_storage, nothing) === prior_context
            restart_cfg = w._replace_wannierization_config(
                cfg;
                checkpoint = (; restart_hdf5 = joinpath(f.root, "baseline.wannierization.h5")),
            )
            @test_throws ArgumentError w.construct_wannier_functions_with_native_inputs(
                restart_cfg,
                same_reference,
            )
        end
        @testset "Accepted native periodic state resumes the optimizer" begin
            periodic = joinpath(f.root, "accepted-native-periodic-$(parallel).h5")
            first_capture = Ref(false)
            cfg = NativeReuseSupport.reuse_config(f, "periodic-source-$(parallel)"; parallel)
            observer = function (snapshot, args...)
                if !first_capture[] && snapshot.u_steps > 0 && rank == 0
                    cp(cfg.checkpoint.checkpoint_hdf5, periodic)
                    first_capture[] = true
                end
            end
            cfg = w._replace_wannierization_config(
                cfg;
                checkpoint = (; num_dump_cycles = 1),
                runtime = (; iteration_observer = observer),
            )
            original = w.construct_wannier_functions_with_native_inputs(cfg, same_reference)
            @test original.restart_state !== nothing
            mpi_execution && MPI.Barrier(MPI.COMM_WORLD)
            @test isfile(periodic)
            if rank == 0
                w.adopt_wannierization_checkpoint_hdf5(periodic)
            end
            mpi_execution && MPI.Barrier(MPI.COMM_WORLD)
            saved = w.read_wannierization_checkpoint_hdf5(periodic)
            @test saved.status == w.IN_PROGRESS_CHECKPOINT
            @test saved.restart_state.optimizer_state.u_steps > 0
            resume = NativeReuseSupport.reuse_config(f, "periodic-tail-$(parallel)"; parallel)
            resume = w._replace_wannierization_config(
                resume;
                solver = (; initialization = :restart),
                checkpoint = (; restart_hdf5 = periodic),
            )
            continued = w.construct_wannier_functions_with_native_inputs(resume, same_reference)
            @test continued.status == original.status
            @test isequal(continued.v_matrix, original.v_matrix)
            @test continued.restart_state.optimizer_state.u_steps >=
                  saved.restart_state.optimizer_state.u_steps
            @test continued.input_summary["native_matrix_input_origin"] ==
                  "VALIDATED_ACCEPTED_INPUT_REUSE_PERIODIC_OPTIMIZER_RESTART"
            terminal_hr =
                NativeReuseSupport.reuse_config(f, "terminal-hr-refusal-$(parallel)"; parallel)
            terminal_hr = w._replace_wannierization_config(
                terminal_hr;
                solver = (; initialization = :restart),
                checkpoint = (; restart_hdf5 = cfg.checkpoint.checkpoint_hdf5),
            )
            @test_throws ArgumentError w.construct_wannier_functions_with_native_inputs(
                terminal_hr,
                same_reference,
            )
            @test !ispath(terminal_hr.output.model_file)
            alternative = joinpath(f.root, "unrelated-accepted-$(parallel).bin")
            rank == 0 && cp(same_reference["path"], alternative)
            mpi_execution && MPI.Barrier(MPI.COMM_WORLD)
            wrong = copy(same_reference)
            wrong["path"] = realpath(alternative)
            @test_throws ArgumentError w.construct_wannier_functions_with_native_inputs(
                resume,
                wrong,
            )
        end
        @testset "Owned QE posthoc full operators from accepted H/r state" begin
            native_full_operator_posthoc_cases(f.root; parallel)
        end
        @testset "Single-rank unavailable input rejects before optimizer" begin
            cfg = NativeReuseSupport.reuse_config(f, "bad-input"; parallel)
            bad_cfg =
                (!mpi_execution || rank == 1) ?
                w._replace_wannierization_config(
                    cfg;
                    input = (; eig_file = joinpath(f.root, "missing.eig")),
                ) : cfg
            @test_throws ArgumentError w.construct_wannier_functions_with_native_inputs(
                bad_cfg,
                same_reference,
            )
            @test !ispath(cfg.output.model_file)
            @test NativeReuseSupport.inventory(native_root) == before
        end
        @testset "Distinct canonical reference records reject collectively" begin
            if mpi_execution
                alternative = joinpath(f.root, "same-native-values.bin")
                rank == 0 && cp(same_reference["path"], alternative)
                MPI.Barrier(MPI.COMM_WORLD)
                cfg = NativeReuseSupport.reuse_config(f, "different-record"; parallel)
                changed = copy(same_reference)
                rank == 1 && (changed["path"] = realpath(alternative))
                @test_throws ArgumentError w.construct_wannier_functions_with_native_inputs(
                    cfg,
                    changed,
                )
                @test !ispath(cfg.output.model_file)
                @test NativeReuseSupport.inventory(native_root) == before
            else
                @test isfile(same_reference["path"])
            end
        end
        @testset "Root output refusal propagates without entering solve" begin
            blocked = joinpath(f.root, "blocked-$(parallel)")
            if rank == 0
                mkpath(blocked)
                chmod(blocked, 0o555)
            end
            mpi_execution && MPI.Barrier(MPI.COMM_WORLD)
            cfg = NativeReuseSupport.reuse_config(f, "blocked-case"; parallel)
            cfg = w._replace_wannierization_config(
                cfg;
                checkpoint = (; checkpoint_hdf5 = joinpath(blocked, "state.h5")),
                output = (; model_file = joinpath(blocked, "model.h5")),
            )
            try
                result = w.construct_wannier_functions_with_native_inputs(cfg, same_reference)
                @test !(result.status in (w.COMPLETED, w.COMPLETED_WITH_WARNINGS, w.MAX_ITERATIONS))
                @test result.restart_state === nothing
                @test any(
                    d -> occursin("NATIVE_INPUT_REUSE_PREPARATION_FAILED", d.message),
                    result.diagnostics,
                )
            finally
                mpi_execution && MPI.Barrier(MPI.COMM_WORLD)
                rank == 0 && chmod(blocked, 0o755)
                mpi_execution && MPI.Barrier(MPI.COMM_WORLD)
            end
            @test get(task_local_storage(), :wannier_preparation_storage, nothing) === prior_context
            @test NativeReuseSupport.inventory(native_root) == before
        end
        @testset "Root backing lifecycle failure follows observer error protocol" begin
            if mpi_execution
                extension = Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)
                publish_views =
                    extension.resolve_wannierization_entrypoint(:_publish_native_input_views)
                validate_views = extension.resolve_wannierization_entrypoint(
                    :_validate_native_input_view_lifetimes,
                )
                saved = WannierNLQG.IO.read_preparation_checkpoint(
                    same_reference["path"],
                    "native-matrix-acceptance/2",
                ).resolved
                directory = mktempdir(; cleanup = false)
                watched = publish_views(saved, directory)
                reached = Ref(false)
                observer = function (summary, state, history, diagnostics)
                    rank == 0 || return nothing
                    reached[] = true
                    # A metadata-only change cannot SIGBUS a consumer. It must
                    # nevertheless invalidate the original backing observation.
                    chmod(watched.mmn.descriptor.path, 0o400)
                    validate_views(watched)
                end
                cfg = NativeReuseSupport.reuse_config(f, "observer-lifecycle"; parallel)
                cfg = w._replace_wannierization_config(
                    cfg;
                    runtime = (; iteration_observer = observer),
                )
                result = w.construct_wannier_functions_with_native_inputs(cfg, same_reference)
                root_reached = MPI.bcast(rank == 0 ? reached[] : nothing, 0, MPI.COMM_WORLD)
                @test root_reached
                @test rank == 0 ? reached[] : !reached[]
                @test result.status == w.IO_FAILURE
                @test any(
                    d -> occursin("ITERATION_OBSERVER_PERSISTENCE_FAILED", string(d.code)),
                    result.diagnostics,
                )
                @test !get(
                    task_local_storage(),
                    :wannier_native_input_shared_fresh_definition,
                    false,
                )
                @test !ispath(cfg.output.model_file)
            else
                @test !get(
                    task_local_storage(),
                    :wannier_native_input_shared_fresh_definition,
                    false,
                )
            end
        end
        @testset "Retained source and original checkpoint bytes remain unchanged" begin
            @test NativeReuseSupport.inventory(joinpath(f.root, "source")) == source_before
            @test all(path -> read(path) == retained_before[path], keys(retained_before))
        end
    end
end

# The MPI probe uses exactly this complete affected test body, not a second oracle.
if !isdefined(@__MODULE__, :NATIVE_REUSE_MPI_PROBE)
    mktempdir() do directory
        native_matrix_input_reuse_cases(NativeReuseSupport.fixture(directory))
    end
end
