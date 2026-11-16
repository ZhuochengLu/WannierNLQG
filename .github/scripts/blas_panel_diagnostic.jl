# Bounded diagnostics of the unchanged released kernels; no source or tolerance mutation.
using WannierNLQG, Test, LinearAlgebra, Random, JSON3, SHA, Libdl
@assert VERSION == v"1.10.13"
import MPI
root, destination, contract_path = ARGS
contract = JSON3.read(read(contract_path, String), Dict{String, Any})
@assert realpath(Base.pkgdir(WannierNLQG)) == realpath(root)
@assert realpath(Base.active_project()) == realpath(joinpath(ENV["WANNIERNLQG_CI_PROJECT"], "Project.toml"))
@assert Threads.nthreads() == 1 && !MPI.Initialized()
BLAS.set_num_threads(1)
include(joinpath(root, "test", "TestCountCompatibilitySupport.jl"))
const PANEL_ROWS = NamedTuple[]
# Preserve the original tests and failure propagation; this is not a replacement oracle.
function panel_case!(body, label)
    result = @testset "$label" begin
        body()
    end
    counts = test_result_totals(result)
    push!(PANEL_ROWS, (; label, passed=counts.passed, failed=counts.failed, errored=counts.errored))
end
# Query only documented no-argument OpenBLAS identity functions from loaded libraries.
function openblas_runtime_identity()
    paths = sort!(unique(filter(p -> occursin("libopenblas", lowercase(basename(p))), Libdl.dllist())))
    result = NamedTuple[]
    for path in paths
        handle = Libdl.dlopen(path)
        values = Dict{String, Any}()
        for (key, symbols) in (("core", (:openblas_get_corename64_, :openblas_get_corename)),
                               ("config", (:openblas_get_config64_, :openblas_get_config)))
            values[key] = "SYMBOL_NOT_AVAILABLE"
            for symbol in symbols
                pointer = Libdl.dlsym_e(handle, symbol)
                if pointer != C_NULL
                    values[key] = unsafe_string(ccall(pointer, Cstring, ()))
                    values[key * "_symbol"] = string(symbol)
                    break
                end
            end
        end
        push!(result, (; path=realpath(path), library_sha256=bytes2hex(sha256(read(path))), values))
        Libdl.dlclose(handle)
    end
    return result
end
runtime = (; julia_version=string(VERSION), kernel=string(Sys.KERNEL), arch=string(Sys.ARCH),
    cpu_name=Sys.CPU_NAME, cpu_models=unique([x.model for x in Sys.cpu_info()]),
    julia_threads=Threads.nthreads(), blas_threads=BLAS.get_num_threads(),
    blas_config=string(BLAS.get_config()), openblas=openblas_runtime_identity(),
    base_source_manifest_sha256=bytes2hex(sha256(read(joinpath(root,"SOURCE_MANIFEST.tsv")))),
    remote_failure_commit="b4036fd4f04c5b7fd02716c5854531c81117391b",
    source_base_commit="b4036fd4f04c5b7fd02716c5854531c81117391b", diagnostic_commit=ENV["GITHUB_SHA"], requested_profile=get(ENV,"WANNIERNLQG_DIAG_PROFILE","default"),
    source_bridge="Isolated management branch; src/ext/test/Project/Manifest remain byteexact b403. This is a diagnostic, not a required-main-CI or release qualification")
println("PANEL_DIAGNOSTIC_RUNTIME ", JSON3.write(runtime))
flush(stdout)
panel_case!("runtime_environment") do
    @test runtime.julia_threads == 1
    @test runtime.blas_threads == 1
    @test !MPI.Initialized()
    @test !isempty(runtime.cpu_models)
end
# Ordered IEEE-bit distance is descriptive; it does not loosen any acceptance threshold.
function comparison(a, b)
    @assert size(a) == size(b)
    diff = finite_diff = signed_zero_diff = 0
    maximum_absolute = 0.0
    maximum_ulp = Int128(0)
    examples = NamedTuple[]
    for (i, (x, y)) in enumerate(zip(reinterpret(Float64, vec(copy(a))), reinterpret(Float64, vec(copy(b)))))
        u, v = reinterpret(UInt64, x), reinterpret(UInt64, y)
        u == v && continue
        diff += 1
        signed_zero_diff += Int(iszero(x) && iszero(y))
        if isfinite(x) && isfinite(y)
            finite_diff += 1
            ou = (u >> 63) == 1 ? ~u : u | 0x8000000000000000
            ov = (v >> 63) == 1 ? ~v : v | 0x8000000000000000
            ulp = abs(Int128(ou) - Int128(ov))
            maximum_ulp = max(maximum_ulp, ulp)
            maximum_absolute = max(maximum_absolute, abs(x-y))
            length(examples) < 6 && push!(examples, (; scalar_index=i, a=x, b=y,
                bits_a=string(u; base=16,pad=16), bits_b=string(v; base=16,pad=16), ulp=string(ulp)))
        end
    end
    return (; bit_differences=diff, finite_differences=finite_diff, signed_zero_differences=signed_zero_diff,
        nonfinite_differences=diff-finite_diff, maximum_absolute, maximum_ulp=string(maximum_ulp), examples)
end
# Compare the same operands with identical M,K/leading dimensions and only a changed N.
function shape_observations()
    rng = MersenneTwister(751)
    E = WannierNLQG.MatrixElements
    rows = NamedTuple[]
    for n in (64,128,132,256,260,516), mode in (:dense,:signedzero)
        left=randn(rng,ComplexF64,n,n);right=randn(rng,ComplexF64,n,n);overlap=randn(rng,ComplexF64,n,n)
        if mode === :signedzero
            left[1:5:end] .= ComplexF64(-0.0,0.0)
            right[1:5:end] .= ComplexF64(0.0,-0.0)
        end
        complete=zeros(ComplexF64,n,n);repeat=similar(complete)
        mul!(complete,left,overlap);mul!(repeat,left,overlap)
        first_insert=copy(complete)
        mul!(complete,overlap,right,1.0,1.0)
        for columns in unique([1:min(64,n), (64*div(n-1,64)+1):n])
            width=length(columns)
            panel=fill(ComplexF64(NaN,NaN),n,n)
            @views mul!(panel[:,columns],left,overlap[:,columns])
            prod_link=fill(ComplexF64(NaN,NaN),n,n)
            E._compute_convention_link_columns!(prod_link,left,overlap,[last(columns)])
            link_difference=comparison(@view(panel[:,columns]),@view(first_insert[:,columns]))
            link_dispatch=comparison(@view(panel[:,columns]),@view(prod_link[:,columns]))
            isolated=fill(ComplexF64(NaN,NaN),n,n)
            @views isolated[:,columns] .= first_insert[:,columns]
            @views mul!(isolated[:,columns],overlap,right[:,columns],1.0,1.0)
            @views mul!(panel[:,columns],overlap,right[:,columns],1.0,1.0)
            prod_vertex=fill(ComplexF64(NaN,NaN),n,n)
            E.active_velocity_selected_columns!(prod_vertex,left,right,overlap,[last(columns)])
            push!(rows,(; n,mode=string(mode),columns=[first(columns),last(columns)],
                full_mnk=[n,n,n],panel_mnk=[n,width,n],transposes="N,N",leading_dimensions=[n,n,n],
                operand_alignment_mod64=[Int(UInt(pointer(x))%64) for x in (left,right,overlap)],
                operand_sha256=[bytes2hex(sha256(reinterpret(UInt8, vec(x)))) for x in (left,right,overlap)],
                full_repeat=comparison(first_insert,repeat),link=link_difference,
                production_link_vs_raw_panel=link_dispatch,
                vertex=comparison(@view(panel[:,columns]),@view(complete[:,columns])),
                isolated_second_GEMM=comparison(@view(isolated[:,columns]),@view(complete[:,columns])),
                production_vertex_vs_raw_panel=comparison(@view(panel[:,columns]),@view(prod_vertex[:,columns]))))
        end
    end
    return rows
end
observations=shape_observations()
# Keep completed measurements even if a following diagnostic-consistency assertion fails.
partial=(; source=realpath(Base.pkgdir(WannierNLQG)),base_manifest_sha256=runtime.base_source_manifest_sha256,
    phase=contract["phase"],units=copy(PANEL_ROWS),threads=Threads.nthreads(),blas_threads=BLAS.get_num_threads(),
    active_project=Base.active_project(),mpi_before=false,mpi_after=MPI.Initialized(),runtime,observations,
    scope="PARTIAL_OBSERVATIONS_RETAINED_BEFORE_CONSISTENCY_ASSERTIONS_NOT_A_PASS")
write(joinpath(destination,"observations.partial.json"),JSON3.write(partial))
panel_case!("gemm_shape_observations") do
    @test length(observations)==22
    @test all(x->x.full_repeat.bit_differences==0,observations)
    @test all(x->x.production_link_vs_raw_panel.bit_differences==0,observations)
    @test all(x->x.production_vertex_vs_raw_panel.bit_differences==0,observations)
end
report=(;source=realpath(Base.pkgdir(WannierNLQG)),base_manifest_sha256=runtime.base_source_manifest_sha256,
    phase=contract["phase"],units=PANEL_ROWS,threads=Threads.nthreads(),blas_threads=BLAS.get_num_threads(),
    active_project=Base.active_project(),mpi_before=false,mpi_after=MPI.Initialized(),runtime,observations,
    scope="LINUX_SHAPE_OBSERVATION_ONLY_NO_FULL_ORIGINAL_TEST_CHANGE_OR_RELEASE_QUALIFICATION",
    remote_root_cause="INTERPRET_WITH_ACTUAL_RUNTIME_AND_CONTROL_PROFILES")
write(joinpath(destination,"selection.json"),JSON3.write(report))
println("BAND_SELECTION_LOCAL_COMPLETED ",contract["phase"])
