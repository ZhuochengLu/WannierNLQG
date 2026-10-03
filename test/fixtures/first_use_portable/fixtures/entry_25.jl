using WannierNLQG, Serialization, SHA, HDF5, JSON3, Test
const W = WannierNLQG.Wannierization
root = joinpath(dirname(Main.RECEIPT), "fixture_output")
@test !ispath(root)
mkpath(root)
@test Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt) === nothing
input_file = Main.FirstUsePortableSupport.input("assets/additional_5/frozen_reader_input.h5")
@test bytes2hex(sha256(read(input_file))) ==
      "0e437d462f6798051c45d78cb38c6155d06d4b508f741d5192fadc6eb76bb95e"
# Native HDF5 input preparation only. Do not call a package reader to activate the writer backend.
fixed_subspace = HDF5.h5open(input_file, "r") do h
    hashes =
        Dict(String(k) => String(read(h["source_sha256"][k])) for k in keys(h["source_sha256"]))
    residuals = Dict(
        String(k) => Float64(read(HDF5.attributes(h["invariant_residuals"])[k])) for
        k in keys(HDF5.attributes(h["invariant_residuals"]))
    )
    W.WannierizationFixedSubspace(
        read(h["projectors"]),
        read(h["initial_frames"]),
        Int.(read(h["irreducible_indices"])),
        Bool.(read(h["frozen_mask"]));
        source_sha256 = hashes,
        invariant_residuals = residuals,
    )
end
@test all(isfinite, fixed_subspace.projectors) && all(isfinite, fixed_subspace.frames)
@test maximum(abs, fixed_subspace.projectors) > 0 && maximum(abs, fixed_subspace.frames) > 0
@test Base.get_extension(WannierNLQG, :WannierNLQGWannierizationExt) === nothing
output_file = joinpath(root, "actual.fixed-subspace.h5")
written = W.write_wannierization_fixed_subspace_hdf5(output_file, fixed_subspace)
@test isfile(written)
restored = W.read_wannierization_fixed_subspace_hdf5(written)
@test isequal(restored.projectors, fixed_subspace.projectors)
@test isequal(restored.frames, fixed_subspace.frames)
@test restored.source_sha256 == fixed_subspace.source_sha256
@test bytes2hex(sha256(read(input_file))) ==
      "0e437d462f6798051c45d78cb38c6155d06d4b508f741d5192fadc6eb76bb95e"
