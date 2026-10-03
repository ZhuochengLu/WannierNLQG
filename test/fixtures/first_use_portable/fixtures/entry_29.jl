using Test, LinearAlgebra, JSON3
const COLD_MAG_SF=WannierNLQG.SymmetryFoundation
structure=COLD_MAG_SF.CrystalStructure(
    [1.0 0.0 0.0; 0.2 1.3 0.0; 0.1 0.3 1.7],
    ["X", "Y"],
    [0.13 0.61; 0.27 0.19; 0.39 0.82];
    magnetic_moments_cartesian = [0.31 -0.22; 0.47 0.73; 0.83 0.16],
)
@test maximum(abs, structure.magnetic_moments_cartesian)>0
Base.get_extension(WannierNLQG, :WannierNLQGSymmetryFoundationExt)===nothing ||
    error("MAGNETIC_BACKEND_PREACTIVATED")
inventory=COLD_MAG_SF.detect_magnetic_symmetry_inventory(structure; include_time_reversal = true)
@test inventory.magnetic
@test inventory.msg_type==1
@test !isempty(inventory.operations)
@test inventory.unitary_operation_count>0
@test inventory.antiunitary_operation_count==0
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
