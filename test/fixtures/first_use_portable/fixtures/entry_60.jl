# Actual immutable arguments from the original, valid solver fixture.
# The independent preparation process is not a first-call speed sample.
using Serialization, SHA, Test
const COLD_W = WannierNLQG.Wannierization
const ARGUMENTS_FILE=get(ENV, "FIRSTUSE_ACTUAL_ARGUMENTS_FILE", "")
const ARGUMENTS_SHA=get(ENV, "FIRSTUSE_ACTUAL_ARGUMENTS_SHA256", "")
isfile(ARGUMENTS_FILE) || error("frozen real solver input missing")
bytes2hex(sha256(read(ARGUMENTS_FILE)))==ARGUMENTS_SHA || error("real input hash mismatch")
Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)===nothing ||
    error("target backend active before input load")
const FROZEN=Main.FirstUsePortableSupport.deserialize_input(ARGUMENTS_FILE)
Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)===nothing ||
    error("input deserialization activated target backend")
const SOLVED=FROZEN.positional[1]
@test maximum(abs, SOLVED.v_matrix)>0
@test all(isfinite, SOLVED.v_matrix)
@test SOLVED.status==COLD_W.COMPLETED
@test SOLVED.wannier_chk!==nothing
const ORIGINAL_V_SHA=bytes2hex(sha256(reinterpret(UInt8, vec(SOLVED.v_matrix))))
actual=COLD_W.evaluate_full_3d_wannier_spreads(FROZEN.positional...; FROZEN.keyword...)
# The localize=false symmetry solver retains an inactive zero spread field.
# The public evaluator independently computes geometric spreads from V and MMN.
# Two x-links have |M_11|=cos(pi/10), each weight 1/(2*pi^2).
# Analytic oracle is for this additional fixture only; A/B science remains exact.
const ANALYTIC_OMEGA=sin(pi/10)^2/pi^2
@test all(iszero, SOLVED.spreads_angstrom2)
@test isapprox(actual.omega_total, ANALYTIC_OMEGA; atol = 1e-14, rtol = 0)
@test length(actual.spreads_angstrom2)==1
@test actual.spreads_angstrom2[1]==actual.omega_total
@test abs(actual.omega_directional[1]-ANALYTIC_OMEGA)<=1e-14
@test actual.omega_directional[2]==0.0
@test actual.omega_directional[3]==0.0
@test bytes2hex(sha256(reinterpret(UInt8, vec(SOLVED.v_matrix))))==ORIGINAL_V_SHA
@test isfinite(actual.omega_total)
@test actual.omega_total > 0
@test maximum(actual.spreads_angstrom2)>0
@test abs(sum(actual.omega_directional)-actual.omega_total)<=1e-10
