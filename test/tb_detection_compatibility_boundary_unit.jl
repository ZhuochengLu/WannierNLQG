using SHA
using Test

include(joinpath(@__DIR__, "support", "TBDetectionInventorySupport.jl"))

@testset "Foundation-owned frozen TB detection inventory" begin
    owner, detector = detector_contract()
    @test owner === WannierNLQG.SymmetryFoundation
    @test detector === owner.detect_tb_compatibility_symmetry_operations

    buffer = IOBuffer()
    write_inventory(buffer, owner, detector)
    payload = take!(buffer)
    @test length(payload) == 18030
    @test bytes2hex(sha256(payload)) ==
          "9750f5c7af6c7dd8195e1765b34c05ad4ab0f5feb77b9cc6a5a1af5b07479168"

    exact = IOBuffer()
    adjacent = IOBuffer()
    changed = IOBuffer()
    write_inventory_floats(exact, [1.0])
    write_inventory_floats(adjacent, [nextfloat(1.0)])
    write_inventory_floats(changed, [1.0 + 2TB_DETECTION_INVENTORY_FLOAT_QUANTUM])
    @test take!(exact) == take!(adjacent)
    @test take!(changed) !=
          reinterpret(UInt8, [round(Int64, 1.0 / TB_DETECTION_INVENTORY_FLOAT_QUANTUM)])

    provenance = owner.symmetry_detection_backend_provenance()
    @test provenance == (package = "Spglib", version = "1.2.0")
end
