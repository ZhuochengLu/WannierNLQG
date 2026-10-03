# Original actual native reader input, no generator/write helper before the timer.
using Test, SHA
const NATIVE_INPUT=get(ENV, "FIRSTUSE_FROZEN_READER_INPUT", "")
const NATIVE_SHA=get(ENV, "FIRSTUSE_FROZEN_READER_SHA256", "")
isfile(NATIVE_INPUT) || error("immutable reader input missing")
bytes2hex(sha256(read(NATIVE_INPUT)))==NATIVE_SHA || error("reader input checksum changed")
Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt)===nothing ||
    error("target backend active before first reader")
result=WannierNLQG.Wannierization.read_wannierization_fixed_subspace_hdf5(NATIVE_INPUT)
@test size(result.frames)==(2, 1, 1)
@test all(isfinite, result.frames) && maximum(abs, result.frames)>0
@test all(isfinite, result.projectors) && maximum(abs, result.projectors)>0
