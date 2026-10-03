using Test, SHA
const INPUT=get(ENV, "FIRSTUSE_FROZEN_READER_INPUT", "")
const INPUT_SHA=get(ENV, "FIRSTUSE_FROZEN_READER_SHA256", "")
@test isfile(INPUT)
@test bytes2hex(sha256(read(INPUT)))==INPUT_SHA
@test Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)===nothing
actual=WannierNLQG.Wannierization.read_vasp_paw_spn_provenance(INPUT; verify_spn = true)
@test actual.schema_version=="1.2"
@test actual.source_code==:vasp
@test actual.num_bands==2 && actual.num_kpoints==2
@test actual.spinor
@test actual.passed
@test all(isfinite, actual.kpoints_fractional)
@test maximum(abs, actual.kpoints_fractional)>0
@test actual.target_generalized_norm_max_absolute==0.0
@test actual.parent_generalized_norm_max_absolute==0.0
@test isfile(actual.artifacts["spn"])
@test bytes2hex(sha256(read(actual.artifacts["spn"])))==actual.artifacts["spn_sha256"]
# Post-target verification of the actual nonzero native SPN; not part of this
# metadata reader's compile gate and not setup/implicit preactivation.
spin=WannierNLQG.IO.read_wannier_spn(actual.artifacts["spn"])
@test all(isfinite, spin.data)
@test size(spin.data)==(2, 2, 3, 2)
@test maximum(abs, spin.data)==1.0
