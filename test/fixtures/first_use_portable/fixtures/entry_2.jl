using Test

one_step = vcat(fill(NaN, 2), ones(48))
two_step = vcat(fill(NaN, 2), ones(38), fill(1.0e-3, 10))
aligned = copy(one_step)
actual =
    WannierNLQG.Wannierization.classify_wannierization_u_periodicity(one_step, two_step, aligned)
@test actual === :PERIOD_2_CONFIRMED
println("PERIODICITY_CLASSIFICATION_VALID ", actual)
