using Test, LinearAlgebra, JSON3
const COLD_MAG_SF=WannierNLQG.SymmetryFoundation
structure=COLD_MAG_SF.CrystalStructure(
    2.87/2 .* [-1.0 1 1; 1 -1 1; 1 1 -1],
    ["Fe"],
    zeros(3, 1);
    magnetic_moments_cartesian = reshape([0.0, 0.0, 1.0], 3, 1),
)
@test maximum(abs, structure.magnetic_moments_cartesian)>0
Base.get_extension(WannierNLQG, :WannierNLQGSymmetryFoundationExt)===nothing ||
    error("MAGNETIC_BACKEND_PREACTIVATED")
inventory=COLD_MAG_SF.detect_magnetic_symmetry_inventory(structure; include_time_reversal = true)
@test inventory.magnetic
@test inventory.msg_type==3
@test !isempty(inventory.operations)
@test inventory.unitary_operation_count>0
@test inventory.antiunitary_operation_count>0
for op in inventory.operations
    @test all(isfinite, op.rotation_cartesian)
    @test all(isfinite, op.translation_fractional)
end
write(
    joinpath(dirname(Main.RECEIPT), "native_magnetic_inventory.json"),
    JSON3.write((
        msg_type = inventory.msg_type,
        uni_number = inventory.uni_number,
        unitary_operation_count = inventory.unitary_operation_count,
        antiunitary_operation_count = inventory.antiunitary_operation_count,
        rotations = [op.rotation_fractional for op in inventory.operations],
        translations = [op.translation_fractional for op in inventory.operations],
        antiunitary = [op.antiunitary for op in inventory.operations],
    )),
)
