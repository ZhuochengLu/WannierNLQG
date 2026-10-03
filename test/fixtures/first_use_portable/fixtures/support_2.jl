using LinearAlgebra

# Exact small fixture extracted from representation_compatibility_unit.jl.
function time_reversal_representation_fixture(; trim::Bool = false, corrupt_second::Bool = false)
    identity_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
    )
    theta_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
        true,
    )
    kpoints = trim ? zeros(1, 3) : [0.25 0.0 0.0; 0.75 0.0 0.0]
    num_kpoints = size(kpoints, 1)
    kpoint_map = trim ? ones(Int, 2, 1) : [1 2; 2 1]
    shifts = zeros(Int, 3, 2, num_kpoints)
    trim || (shifts[1, 2, :] .= -1)
    theta = ComplexF64[0 1; -1 0]
    sewing = zeros(ComplexF64, 2, 2, 2, num_kpoints)
    for kpoint in 1:num_kpoints
        sewing[:, :, 1, kpoint] .= Matrix{ComplexF64}(I, 2, 2)
        sewing[:, :, 2, kpoint] .= theta
    end
    corrupt_second && num_kpoints == 2 && (sewing[:, :, 2, 2] .*= -1)
    representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.1",
        :synthetic,
        true,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        trim ? (1, 1, 1) : (2, 1, 1),
        kpoints,
        zeros(2, num_kpoints),
        [identity_operation, theta_operation],
        kpoint_map,
        shifts,
        sewing,
        ones(Int, 2, num_kpoints),
        [1],
        ones(Int, num_kpoints),
        trim ? [1] : [1, 2];
        conventions = Dict(
            "sewing" => "rows target bands, columns source bands",
            "antiunitary_gauge_transform" => "B'=U_target'*B*conj(U_source)",
        ),
        input_sha256 = Dict("fixture" => repeat("1", 64)),
    )
    shuffled_operations = [theta_operation, identity_operation]
    target_matrices = zeros(ComplexF64, 2, 2, 2)
    target_matrices[:, :, 1] .= theta
    target_matrices[:, :, 2] .= Matrix{ComplexF64}(I, 2, 2)
    plan = WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
        shuffled_operations,
        target_matrices,
        zeros(Int, 3, 2, 2),
    )
    return (; representation, plan, identity_operation, theta_operation)
end
