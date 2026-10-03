using JSON3, SHA, Test
length(ARGS)==3 || error("usage provenance_file receipt expected_package")
const TARGET=:read_qe_paw_spn_provenance
include(Main.FirstUsePortableSupport.input("fixtures/support_3.jl"))
import_started=time_ns()
import_measure=@timed Core.eval(Main, :(using WannierNLQG, MPI))
import_wall=(time_ns()-import_started)/1e9
@test samefile(pkgdir(WannierNLQG), ARGS[3])
@test !MPI.Initialized()
@test !isdefined(WannierNLQG.Wannierization, TARGET)
before=Dict(
    string(n)=>Base.get_extension(WannierNLQG, n)!==nothing for n in (
        :WannierNLQGWannierizationExt,
        :WannierNLQGSymmetryFoundationExt,
        :WannierNLQGWannierizationPrecompileExt,
    )
)
@test !before["WannierNLQGWannierizationExt"]
filename=abspath(ARGS[1])
expr=quote
    let extension=first(WannierNLQG.Wannierization._load_wannierization_extension!())
        Base.invokelatest(getproperty(extension, :read_qe_paw_spn_provenance), $filename)
    end
end
started=time_ns()
first_timed=@timed Core.eval(Main, expr)
first_wall=(time_ns()-started)/1e9
@test first_timed.value.num_bands==1
@test first_timed.value.num_kpoints==3
@test !MPI.Initialized()
summary=FirstUseExpertProbe.numeric_summary(first_timed.value)
@test summary.all_finite
later=@timed Core.eval(Main, expr)
@test FirstUseExpertProbe.numeric_summary(later.value).leaves==summary.leaves
write(
    ARGS[2],
    JSON3.write((
        scope = "extension-exported expert only; required activation INSIDE timer; root facade absent, no invented API",
        source = pkgdir(WannierNLQG),
        gc_on = true,
        extension_before = before,
        import_wall_seconds = import_wall,
        import_compile_seconds = import_measure.compile_time,
        first_wall_seconds = first_wall,
        time = first_timed.time,
        compile_time = first_timed.compile_time,
        recompile_time = first_timed.recompile_time,
        gc_time = first_timed.gctime,
        allocated_bytes = first_timed.bytes,
        return_summary = summary,
        later_time = later.time,
        later_compile_time = later.compile_time,
        root_facade_available = false,
        verify_spn = true,
        mpi_initialized = MPI.Initialized(),
    )),
)
println("QE_EXTENSION_COLD_READER_PASS compile=", first_timed.compile_time)
