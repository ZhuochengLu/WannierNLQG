# Original actual native reader input, no generator/write helper before the timer.
using Test, SHA
const NATIVE_INPUT=get(ENV, "FIRSTUSE_FROZEN_READER_INPUT", "")
const NATIVE_SHA=get(ENV, "FIRSTUSE_FROZEN_READER_SHA256", "")
isfile(NATIVE_INPUT) || error("immutable reader input missing")
bytes2hex(sha256(read(NATIVE_INPUT)))==NATIVE_SHA || error("reader input checksum changed")
Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)===nothing ||
    error("target backend active before first reader")
result=WannierNLQG.Wannierization.read_projection_representation_search_hdf5(NATIVE_INPUT)
@test result.complete
@test !isempty(result.solutions)
@test any(sol->any(x->x!=0, sol.coefficients), result.solutions)
@test all(sol->all(isfinite, sol.coefficients), result.solutions)
