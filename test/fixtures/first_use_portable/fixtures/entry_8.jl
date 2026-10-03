using Test, SHA
const COLD_W = WannierNLQG.Wannierization
const FROZEN_CHECKPOINT =
    Main.FirstUsePortableSupport.input("assets/frozen_solver/synthetic.wannierization.h5")
bytes2hex(sha256(read(FROZEN_CHECKPOINT))) ==
"94cb21b92e1f99a09e45251799c6d0da90f9489675cca2d045c364e05386c2b6" ||
    error("FROZEN_CHECKPOINT_IDENTITY_CHANGED")
restored = COLD_W.read_wannierization_checkpoint_hdf5(FROZEN_CHECKPOINT)
@test size(restored.v_matrix)==(2, 1, 2)
@test maximum(abs, restored.v_matrix)>0
@test all(isfinite, restored.v_matrix)
@test restored.status in (COLD_W.COMPLETED, COLD_W.COMPLETED_WITH_WARNINGS)
println("COLD_CHECKPOINT_READ_VALID")
