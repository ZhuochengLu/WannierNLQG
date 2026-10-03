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
if Main.TARGET==:validate_public_band_representation_contract
    actual=WannierNLQG.SymmetryFoundation.validate_public_band_representation_contract(
        representation,
    )
elseif Main.TARGET==:validate_unified_representation_mode_contract
    actual=WannierNLQG.SymmetryFoundation.validate_unified_representation_mode_contract(
        representation,
    )
else
    error("unknown data-only validator target")
end
@test actual===nothing
@test bytes2hex(
    sha256(reinterpret(UInt8, vec(representation.sewing_matrices))),
)==identity.sewing_bits_sha256
