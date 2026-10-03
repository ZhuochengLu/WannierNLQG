using Test, Serialization, SHA, JSON3
const INPUT_ROOT=Main.FirstUsePortableSupport.input("public_band")
identity=JSON3.read(read(joinpath(INPUT_ROOT, "identity.json"), String))
input=joinpath(INPUT_ROOT, "prepared_representation.jls")
@test bytes2hex(sha256(read(input)))==identity.binary_sha256
representation=Main.FirstUsePortableSupport.deserialize_input(input)
@test representation.schema_version=="1.0"
@test any(op->op.antiunitary, representation.operations)
@test maximum(abs, representation.sewing_matrices)>0
@test all(isfinite, representation.sewing_matrices)
@test bytes2hex(
    sha256(reinterpret(UInt8, vec(representation.sewing_matrices))),
)==identity.sewing_bits_sha256
output = joinpath(dirname(Main.RECEIPT), "band_frozen_writer.h5")
actual = WannierNLQG.SymmetryFoundation.write_band_representation_hdf5(output, representation)
@test actual==abspath(output)
@test isfile(output)
@test bytes2hex(
    sha256(reinterpret(UInt8, vec(representation.sewing_matrices))),
)==identity.sewing_bits_sha256
# Readback is performed by the probe strictly after the measured writer call.
println("FROZEN_NONZERO_ANTIUNITARY_BAND_WRITE_VALID")
