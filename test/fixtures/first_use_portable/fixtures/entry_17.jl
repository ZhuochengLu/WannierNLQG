# Actual user pipeline: its validation result type belongs to the extension,
# so a writer cannot receive that object while the extension is absent.
# Measure the first validation and first writer separately; no helper backend load.
using JSON3, SHA, Test, LinearAlgebra
length(ARGS)==2 || error("usage: expected_package output")
expected, output=ARGS
import_started=time_ns()
import_stats=@timed Core.eval(Main, :(using WannierNLQG))
import_wall=(time_ns()-import_started)/1e9
samefile(pkgdir(WannierNLQG), expected) || error("source mismatch")
mkpath(output)
Base.get_extension(WannierNLQG, :WannierNLQGSymmetryFoundationExt)===nothing ||
    error("target backend active on import")
fixture_started=time_ns()
include(joinpath(pkgdir(WannierNLQG), "test", "BandPublicSchemaTestSupport.jl"))
const RAW=BandPublicSchemaTestSupport.raw_time_reversal_representation_fixture()
maximum(abs, RAW.sewing_matrices)>0 && all(isfinite, RAW.sewing_matrices) ||
    error("invalid zero/nonfinite fixture")
any(op->op.antiunitary, RAW.operations) || error("antiunitary path not present")
const S=WannierNLQG.SymmetryFoundation
fixture_wall=(time_ns()-fixture_started)/1e9
Base.get_extension(WannierNLQG, :WannierNLQGSymmetryFoundationExt)===nothing ||
    error("fixture prematurely activated backend")
validation_before=Base.get_extension(WannierNLQG, :WannierNLQGSymmetryFoundationExt)!==nothing
@test !validation_before
validation_started=time_ns()
validation_stats=@timed Core.eval(
    Main,
    :(S.validate_band_representation(
        RAW;
        absolute_tolerance = 1e-8,
        oracle_excess_tolerance = 1e-8,
        require_oracle = false,
    )),
)
validation_wall=(time_ns()-validation_started)/1e9
const VALIDATION=validation_stats.value
@test VALIDATION.passed
@test all(isfinite, VALIDATION.maximum_group_law_residuals)
const FILENAME=joinpath(output, "band_summary.json")
writer_before=Base.get_extension(WannierNLQG, :WannierNLQGSymmetryFoundationExt)!==nothing
@test writer_before
writer_started=time_ns()
writer_stats=@timed Core.eval(
    Main,
    :(S.write_band_representation_summary(FILENAME, RAW, VALIDATION; overwrite = false)),
)
writer_wall=(time_ns()-writer_started)/1e9
@test isfile(writer_stats.value)
payload=JSON3.read(read(writer_stats.value, String), Dict{String, Any})
@test payload["passed"]===true &&
      payload["num_bands"]==2 &&
      payload["num_kpoints"]==2 &&
      payload["num_operations"]==2
fields=Dict{String, Any}()
for name in fieldnames(typeof(VALIDATION))
    value=getfield(VALIDATION, name)
    if value isa Number
        fields[string(
            name,
        )]=(type = string(typeof(value)), bits = bytes2hex(reinterpret(UInt8, [value])))
    elseif value isa Tuple && all(x->x isa Number, value)
        fields[string(
            name,
        )]=[(type = string(typeof(x)), bits = bytes2hex(reinterpret(UInt8, [x]))) for x in value]
    else
        fields[string(name)]=value
    end
end
stats(
    s,
    w,
)=(
    wall_seconds = w,
    time = s.time,
    compile_time = s.compile_time,
    recompile_time = s.recompile_time,
    gc_time = s.gctime,
    allocated_bytes = s.bytes,
)
record=(
    package_root = pkgdir(WannierNLQG),
    julia = string(VERSION),
    threads = Threads.nthreads(),
    import_phase = stats(import_stats, import_wall),
    fixture_setup_seconds = fixture_wall,
    validation = stats(validation_stats, validation_wall),
    writer = stats(writer_stats, writer_wall),
    validation_before_backend = validation_before,
    writer_before_backend = writer_before,
    writer_prerequisite = "Actual measured public validate_band_representation creates the extension-owned validation object; no private loader/setup preactivation",
    validation_type = string(typeof(VALIDATION)),
    validation_type_owner = string(parentmodule(typeof(VALIDATION))),
    validation_native_fields = fields,
    sewing_native_sha256 = bytes2hex(sha256(reinterpret(UInt8, vec(RAW.sewing_matrices)))),
    native_output_sha256 = bytes2hex(sha256(read(FILENAME))),
    native_payload = payload,
    qualification = "first real validation and writer calls only; not whole-expert or physics qualification",
)
write(joinpath(output, "receipt.json"), JSON3.write(record));
println("REAL_VALIDATION_WRITER_PIPELINE_OK")
