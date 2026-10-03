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
@test SOLVED.status==COLD_W.MAX_ITERATIONS
@test !isempty(SOLVED.history)
@test last(SOLVED.history).iteration==3
model=COLD_W.build_wannier_tight_binding_model(FROZEN.positional...; FROZEN.keyword...)
@test size(model.hamiltonian_r, 1)==1
@test all(isfinite, model.hamiltonian_r)
@test maximum(abs, model.hamiltonian_r)>0
