using Test

thresholds = WannierNLQG.Wannierization.SMVFletcherReevesTwoStageAuditThresholds()
actual = WannierNLQG.Wannierization.smv_fletcher_reeves_two_stage_audit_contract_sha256(thresholds)
@test occursin(r"^[0-9a-f]{64}$", actual)
@test actual != repeat("0", 64)
println("SMV_FR_CONTRACT_SHA256_VALID ", actual)
