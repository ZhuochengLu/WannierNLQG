using LinearAlgebra
using Test

structure = WannierNLQG.SymmetryFoundation.CrystalStructure(
    Matrix(Diagonal([1.0, 2.0, 3.0])),
    ["X"],
    zeros(3, 1),
)
operations = WannierNLQG.SymmetryFoundation.detect_symmetry_operations(
    structure;
    include_time_reversal = false,
)
@test !isempty(operations)
@test all(operation -> !operation.antiunitary, operations)
@test any(operation -> operation.rotation_fractional == Matrix{Int}(I, 3, 3), operations)
@test length(operations) >= 4
println("SYMMETRY_DETECTION_VALID_OPERATIONS ", length(operations))
