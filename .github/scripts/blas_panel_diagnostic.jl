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
function reference_link_copy!(output, left, right, indices, temporary)
    E = WannierNLQG.MatrixElements
    n = size(output, 1)
    if !E._dense_column_panel_storage_eligible(output, indices, left, right)
        return mul!(output, left, right)
    end
    previous = 0
    for band in indices
        previous < band <= n || return mul!(output, left, right)
        previous = band
    end
    lo = 64 * div(first(indices)-1,64)+1
    hi = min(n,64*cld(last(indices),64))
    if 2*(hi-lo+1)>n || !all(isfinite,left) || !all(isfinite,right)
        return mul!(output,left,right)
    end
    mul!(temporary,left,right)
    @inbounds for col in lo:hi, row in 1:n
        output[row,col] = temporary[row,col]
    end
    return output
end

function reference_vertex_copy!(output,left,right,overlap,indices,temporary)
    E = WannierNLQG.MatrixElements
    n = size(output,1)
    if !E._dense_column_panel_storage_eligible(output,indices,left,right,overlap)
        return E.active_velocity_insertion_direction!(output,left,right,overlap)
    end
    previous_band=0; previous_panel=0; written=0
    for band in indices
        previous_band < band <= n || return E.active_velocity_insertion_direction!(output,left,right,overlap)
        lo=64*div(band-1,64)+1
        if lo!=previous_panel
            written+=min(64,n-lo+1)
            previous_panel=lo
        end
        previous_band=band
    end
    if 2*written>n || !all(isfinite,left) || !all(isfinite,right) || !all(isfinite,overlap)
        return E.active_velocity_insertion_direction!(output,left,right,overlap)
    end
    E.active_velocity_insertion_direction!(temporary,left,right,overlap)
    previous_panel=0
    for band in indices
        lo=64*div(band-1,64)+1
        lo==previous_panel && continue
        previous_panel=lo
        @inbounds for col in lo:min(n,lo+63), row in 1:n
            output[row,col]=temporary[row,col]
        end
    end
    return output
end

function measure_pair!(baseline::F,candidate::G,base_args,candidate_args) where {F,G}
    for _ in 1:3
        baseline(base_args...)
        candidate(candidate_args...)
    end
    old_alloc=@allocated baseline(base_args...)
    new_alloc=@allocated candidate(candidate_args...)
    old_times=Float64[]; new_times=Float64[]
    repetitions=30
    for sample in 1:5
        if isodd(sample)
            t=time_ns()
            for _ in 1:repetitions; baseline(base_args...); end
            push!(old_times,Float64(time_ns()-t)/repetitions)
            t=time_ns()
            for _ in 1:repetitions; candidate(candidate_args...); end
            push!(new_times,Float64(time_ns()-t)/repetitions)
        else
            t=time_ns()
            for _ in 1:repetitions; candidate(candidate_args...); end
            push!(new_times,Float64(time_ns()-t)/repetitions)
            t=time_ns()
            for _ in 1:repetitions; baseline(base_args...); end
            push!(old_times,Float64(time_ns()-t)/repetitions)
        end
    end
    old_median=sort(copy(old_times))[3]
    new_median=sort(copy(new_times))[3]
    return (;warmups=3,repetitions_per_sample=repetitions,samples=5,
        order="paired alternating baseline/candidate",baseline_allocated_bytes=old_alloc,
        candidate_allocated_bytes=new_alloc,baseline_nanoseconds_per_call=old_times,
        candidate_nanoseconds_per_call=new_times,baseline_median_nanoseconds=old_median,
        candidate_median_nanoseconds=new_median,median_ratio=new_median/old_median,
        scope="warm in-memory microbenchmark; not end-to-end material speed or statistical stability")
end

function shape_observations()
    rng=MersenneTwister(774)
    E=WannierNLQG.MatrixElements
    rows=NamedTuple[]
    cases=[(n,Int[2,63]) for n in (128,132,256,516)]
    append!(cases,[(516,collect(257:(256+count))) for count in (1,4,16)])
    push!(cases,(256,Int[2,130]))
    for (n,indices) in cases
        left=randn(rng,ComplexF64,n,n)
        right=randn(rng,ComplexF64,n,n)
        overlap=randn(rng,ComplexF64,n,n)
        operand_sha256=[bytes2hex(sha256(reinterpret(UInt8,vec(x)))) for x in (left,right,overlap)]
        sentinel=ComplexF64(-7.0,13.0)
        full_link=zeros(ComplexF64,n,n); full_vertex=similar(full_link)
        mul!(full_link,left,right)
        E.active_velocity_insertion_direction!(full_vertex,left,right,overlap)
        old_link=fill(sentinel,n,n); new_link=copy(old_link)
        old_vertex=copy(old_link); new_vertex=copy(old_link)
        scratch=similar(full_link)
        @assert all(x->!Base.mightalias(scratch,x),(left,right,overlap,old_link,new_link,old_vertex,new_vertex))
        E._compute_convention_link_columns!(old_link,left,right,indices)
        E.active_velocity_selected_columns!(old_vertex,left,right,overlap,indices)
        reference_link_copy!(new_link,left,right,indices,scratch)
        reference_vertex_copy!(new_vertex,left,right,overlap,indices,scratch)
        link_columns=falses(n); vertex_columns=falses(n)
        lo=64*div(first(indices)-1,64)+1; hi=min(n,64*cld(last(indices),64))
        if 2*(hi-lo+1)>n; link_columns.=true; else; link_columns[lo:hi].=true; end
        for band in indices
            a=64*div(band-1,64)+1
            vertex_columns[a:min(n,a+63)].=true
        end
        count(vertex_columns)*2>n && (vertex_columns.=true)
        link_untouched=findall(!,link_columns); vertex_untouched=findall(!,vertex_columns)
        link_expected=fill(sentinel,n,n); vertex_expected=copy(link_expected)
        link_expected[:,link_columns].=full_link[:,link_columns]
        vertex_expected[:,vertex_columns].=full_vertex[:,vertex_columns]
        selected_link=comparison(old_link[:,indices],full_link[:,indices])
        selected_vertex=comparison(old_vertex[:,indices],full_vertex[:,indices])
        copy_link=comparison(new_link,link_expected)
        copy_vertex=comparison(new_vertex,vertex_expected)
        link_cost=measure_pair!(E._compute_convention_link_columns!,reference_link_copy!,
            (old_link,left,right,indices),(new_link,left,right,indices,scratch))
        vertex_cost=measure_pair!(E.active_velocity_selected_columns!,reference_vertex_copy!,
            (old_vertex,left,right,overlap,indices),(new_vertex,left,right,overlap,indices,scratch))
        post_sha256=[bytes2hex(sha256(reinterpret(UInt8,vec(x)))) for x in (left,right,overlap)]
        push!(rows,(;n,mode="selected_"*join(indices,"_"),columns=[first(indices),last(indices)],indices,
            operand_alignment_mod64=[Int(UInt(pointer(x))%64) for x in (left,right,overlap)],operand_sha256,
            input_unchanged=(post_sha256==operand_sha256),scratch_bytes=16*n*n,
            link_written_columns=count(link_columns),vertex_written_columns=count(vertex_columns),
            link=selected_link,vertex=selected_vertex,
            candidate_link_entire_output=copy_link,candidate_vertex_entire_output=copy_vertex,
            baseline_candidate_entire_link=comparison(old_link,new_link),
            baseline_candidate_entire_vertex=comparison(old_vertex,new_vertex),
            unselected_link_preserved=all(z->isequal(z,sentinel),new_link[:,link_untouched]),
            unselected_vertex_preserved=all(z->isequal(z,sentinel),new_vertex[:,vertex_untouched]),
            link_cost,vertex_cost,
            note="Experimental diagnostic reference only; not installed production implementation or contract approval"))
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
panel_case!("contract_witness_and_cost") do
    @test length(observations)==8
    @test all(x->x.input_unchanged,observations)
    @test all(x->x.candidate_link_entire_output.bit_differences==0,observations)
    @test all(x->x.candidate_vertex_entire_output.bit_differences==0,observations)
    @test all(x->x.unselected_link_preserved && x.unselected_vertex_preserved,observations)
    @test all(x->x.link_cost.baseline_allocated_bytes==0 && x.vertex_cost.baseline_allocated_bytes==0,observations)
    @test all(x->x.link_cost.candidate_allocated_bytes==0 && x.vertex_cost.candidate_allocated_bytes==0,observations)
end
report=(;source=realpath(Base.pkgdir(WannierNLQG)),base_manifest_sha256=runtime.base_source_manifest_sha256,
    phase=contract["phase"],units=PANEL_ROWS,threads=Threads.nthreads(),blas_threads=BLAS.get_num_threads(),
    active_project=Base.active_project(),mpi_before=false,mpi_after=MPI.Initialized(),runtime,observations,
    scope="LINUX_CONTRACT_AND_WARM_COST_OBSERVATIONS_ONLY_NO_PRODUCTION_INSTALL_OR_APPROVAL",
    remote_root_cause="INTERPRET_WITH_ACTUAL_RUNTIME_AND_CONTROL_PROFILES")
write(joinpath(destination,"selection.json"),JSON3.write(report))
println("BAND_SELECTION_LOCAL_COMPLETED ",contract["phase"])
