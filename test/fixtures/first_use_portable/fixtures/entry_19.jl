# Original actual native reader input, no generator/write helper before the timer.
using Test, SHA
const NATIVE_INPUT=get(ENV, "FIRSTUSE_FROZEN_READER_INPUT", "")
const NATIVE_SHA=get(ENV, "FIRSTUSE_FROZEN_READER_SHA256", "")
isfile(NATIVE_INPUT) || error("immutable reader input missing")
bytes2hex(sha256(read(NATIVE_INPUT)))==NATIVE_SHA || error("reader input checksum changed")
Base.get_extension(WannierNLQG, :WannierNLQGSymmetryFoundationExt)===nothing ||
    error("target backend active before first reader")
result=WannierNLQG.SymmetryFoundation.read_band_representation_hdf5(NATIVE_INPUT)
@test maximum(abs, result.sewing_matrices)>0
@test all(isfinite, result.sewing_matrices)
@test all(isfinite, result.energies_ev)
@test maximum(abs, result.energies_ev)>0
