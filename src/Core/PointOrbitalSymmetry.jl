"""A space operation and its constant local-orbital representation in Convention II."""
struct PointOrbitalSymmetryOperation
    rotation_fractional::Matrix{Int}
    translation_fractional::Vector{Float64}
    antiunitary::Bool
    representation::Matrix{ComplexF64}
    function PointOrbitalSymmetryOperation(;
        rotation_fractional,
        translation_fractional = zeros(3),
        antiunitary = false,
        representation,
    )
        rotation=Matrix{Int}(rotation_fractional)
        translation=Vector{Float64}(translation_fractional)
        matrix=Matrix{ComplexF64}(representation)
        size(rotation)==(3, 3) && abs(round(Int, det(rotation)))==1 ||
            throw(ArgumentError("invalid lattice rotation"))
        length(translation)==3 && all(isfinite, translation) ||
            throw(ArgumentError("invalid fractional translation"))
        size(matrix, 1)==size(matrix, 2)>0 && all(isfinite, matrix) ||
            throw(ArgumentError("invalid orbital representation"))
        isapprox(
            matrix' * matrix,
            Matrix{ComplexF64}(I, size(matrix, 1), size(matrix, 1));
            atol = 1e-11,
            rtol = 1e-9,
        ) || throw(ArgumentError("orbital representation must be unitary"))
        new(rotation, translation, Bool(antiunitary), matrix)
    end
end
