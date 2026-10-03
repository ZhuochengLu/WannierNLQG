using WannierNLQG, JSON3, Test, SHA
const S=WannierNLQG.Symmetrization
root=joinpath(dirname(Main.RECEIPT), "fixture_output")
@test !ispath(root)
mkpath(root)
win=Main.FirstUsePortableSupport.input("assets/additional_43/synthetic.win")
tb=Main.FirstUsePortableSupport.input("assets/additional_44/synthetic_tb.dat")
@test bytes2hex(
    sha256(read(win)),
)=="ec61fc9f657a4477ea27e41362cac23a607fb7aca99e536ef69a190ff45e29df"
@test bytes2hex(
    sha256(read(tb)),
)=="3aa398044263c2f3fa94b05ec60f3652349de275981e0d5f57273726fa36b5a6"
@test Base.get_extension(WannierNLQG, :WannierNLQGSymmetrizationExt)===nothing
config=S.SymmetrizationConfig(
    win_file = win,
    tb_file = tb,
    output_tb_file = joinpath(root, "synthetic_sym_tb.dat"),
    output_real_space_operator_bundle_file = joinpath(root, "wannierNLQG_tb.h5"),
    report_json_file = joinpath(root, "symmetrization.json"),
    include_time_reversal = true,
    symmetry_tolerance = 1e-5,
    projection_tolerance = 1e-7,
    representation_tolerance = 1e-7,
    covariance_tolerance = 1e-8,
    idempotence_tolerance = 1e-9,
    check_idempotence = true,
    real_space_replica_policy = :input,
    overwrite = true,
)
@test Base.get_extension(WannierNLQG, :WannierNLQGSymmetrizationExt)===nothing
result=S.symmetrize_wannier_operators(config)
@test result.operator_profile==:hamiltonian_position
@test all(isfile, (result.output_tb, result.real_space_operator_bundle, result.report_json))
@test all(summary -> all(isfinite, summary), values(result.validation))
report=JSON3.read(read(result.report_json, String))
@test String(report.status)=="PASS"
manifest=WannierNLQG.IO.read_real_space_operator_bundle_manifest(result.real_space_operator_bundle)
@test manifest.schema_version=="1.1"
model=WannierNLQG.IO.read_wannier_tb(result.output_tb)
@test all(isfinite, model.hamiltonian_r) && maximum(abs, model.hamiltonian_r)>0
native=Main.FirstUseExpertProbe.native_writer_readback(
    :write_band_representation_hdf5,
    result.real_space_operator_bundle,
)
write(joinpath(dirname(Main.RECEIPT), "native_symmetrized_bundle.json"), JSON3.write(native))
write(
    joinpath(dirname(Main.RECEIPT), "native_symmetrized_tb_bits.json"),
    JSON3.write(Main.FirstUseExpertProbe.numeric_summary(model)),
)
@test bytes2hex(
    sha256(read(win)),
)=="ec61fc9f657a4477ea27e41362cac23a607fb7aca99e536ef69a190ff45e29df"
@test bytes2hex(
    sha256(read(tb)),
)=="3aa398044263c2f3fa94b05ec60f3652349de275981e0d5f57273726fa36b5a6"
