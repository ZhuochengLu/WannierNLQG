"""
    _spin_half_rotation_matrix(rotation_cartesian)

Construct the canonical spin-1/2 lift of a Cartesian polar-vector rotation.
Improper rotations are first converted to their proper axial-vector action
`det(R)R`. The returned matrix acts on column spinors in the fixed
`(up, down)` Pauli basis and is unitary with determinant one up to roundoff.
"""
function _spin_half_rotation_matrix(rotation_cartesian::AbstractMatrix{<:Real})
    polar_rotation = Matrix{Float64}(rotation_cartesian)
    size(polar_rotation) == (3, 3) ||
        throw(ArgumentError("rotation_cartesian must have size (3, 3)"))
    axial_rotation = det(polar_rotation) .* polar_rotation
    eigensystem = eigen(axial_rotation)
    axis_index = argmin(abs.(eigensystem.values .- 1.0))
    axis = real.(eigensystem.vectors[:, axis_index])
    norm(axis) > 1.0e-14 || throw(ArgumentError("rotation has no stable unit eigenvector"))
    axis ./= norm(axis)
    cosine = clamp((tr(axial_rotation) - 1.0) / 2.0, -1.0, 1.0)
    sine_axis =
        [
            axial_rotation[3, 2] - axial_rotation[2, 3],
            axial_rotation[1, 3] - axial_rotation[3, 1],
            axial_rotation[2, 1] - axial_rotation[1, 2],
        ] ./ 2
    angle = atan(dot(sine_axis, axis), cosine)
    if angle < 0.0
        angle = -angle
        axis = -axis
    end
    half_angle = angle / 2.0
    pauli_x = ComplexF64[0 1; 1 0]
    pauli_y = ComplexF64[0 -im; im 0]
    pauli_z = ComplexF64[1 0; 0 -1]
    result =
        cos(half_angle) .* Matrix{ComplexF64}(I, 2, 2) .-
        im * sin(half_angle) .* (axis[1] .* pauli_x .+ axis[2] .* pauli_y .+ axis[3] .* pauli_z)
    result[abs.(result) .< 1.0e-12] .= 0.0
    isapprox(result' * result, Matrix{ComplexF64}(I, 2, 2); atol = 1.0e-10, rtol = 0.0) ||
        throw(ArgumentError("spin-half rotation is not unitary"))
    return result
end

"""
    spin_action_matrix(operation, spinor=true)

Return the matrix part `Q_g` of a unitary or antiunitary spin action. For an
antiunitary operation the coefficient action is `Q_g * conj(c)` with
`Q_g = (i sigma_y) * conj(S_g)`. Scalar states use a one-dimensional identity.
"""
function spin_action_matrix(operation::SymmetryOperation, spinor::Bool = true)
    spinor || return ones(ComplexF64, 1, 1)
    spatial_spin = _spin_half_rotation_matrix(operation.rotation_cartesian)
    operation.antiunitary || return spatial_spin
    time_reversal_unitary = ComplexF64[0 1; -1 0]
    return time_reversal_unitary * conj(spatial_spin)
end
