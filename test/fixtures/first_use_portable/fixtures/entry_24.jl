using WannierNLQG, Serialization, SHA, HDF5, JSON3, Test
const W = WannierNLQG.Wannierization
root = joinpath(dirname(Main.RECEIPT), "fixture_output")
@test !ispath(root)
mkpath(root)
@test Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt) === nothing
input_file = Main.FirstUsePortableSupport.input("arguments/fixture_24.jls")
@test bytes2hex(sha256(read(input_file))) ==
      "4de0950667fd87609f3467dde301018a5922c6771e3abc0a70b1086784d5b227"
actual_inputs = Main.FirstUsePortableSupport.deserialize_input(input_file)
@test length(actual_inputs) == 2
@test actual_inputs[1] isa Tuple
result = actual_inputs[1][1]
@test size(result.v_matrix) == (2, 1, 2)
@test all(isfinite, result.v_matrix)
@test maximum(abs, result.v_matrix) > 0
@test result.restart_state !== nothing
@test Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt) === nothing
output_file = joinpath(root, "actual.wannierization.h5")
written = W.write_wannierization_checkpoint_hdf5(output_file, result)
@test isfile(written)
restored = W.read_wannierization_checkpoint_hdf5(written)
@test isequal(restored.v_matrix, result.v_matrix)
@test restored.status == result.status
@test isequal(restored.restart_state.z_previous, result.restart_state.z_previous)
@test bytes2hex(sha256(read(input_file))) ==
      "4de0950667fd87609f3467dde301018a5922c6771e3abc0a70b1086784d5b227"
