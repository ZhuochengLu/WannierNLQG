using WannierNLQG
import WannierNLQG.Wannierization as W

length(ARGS) == 1 || error("usage: VASPPawSPNProvenanceFreshReadProbe.jl PROVENANCE.h5")
result = W.read_vasp_paw_spn_provenance(only(ARGS))
result.content_authentication == "NOT_PERFORMED" ||
    error("unexpected provenance authentication mode")
println("VASP_PAW_SPN_FRESH_READ_PASS")
