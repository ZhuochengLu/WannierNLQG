"""Occupied-space Matrix curvature, retaining ambient and opposite-occupation links."""
function intrinsic_hall_matrix_curvature(geometry, occupied::Integer, connection)
    n = length(geometry.energies)
    result = zeros(Float64, 3, 3)
    for a in 1:3, b in 1:3
        value = 0.0
        for l in 1:occupied
            value += real(geometry.ambient_curvature[l, l, a, b])
            for m in (occupied + 1):n
                # Both ordered products retain the admitted connection convention.
                left = connection[l, m, a] * connection[m, l, b]
                right = connection[l, m, b] * connection[m, l, a]
                all(isfinite, (left, right, left-right)) ||
                    error("INTRINSIC_HALL_NONFINITE_PAIR_PRODUCT")
                value -= imag(left-right)
                isfinite(value) || error("INTRINSIC_HALL_NONFINITE_MATRIX_CONTRACTION")
            end
            isfinite(value) || error("INTRINSIC_HALL_NONFINITE_AMBIENT_SUM")
        end
        result[a, b] = value
    end
    return result
end

"""Orthogonal occupied projector tr(PF)+i tr(P[∇P,∇P]), using the same bare links."""
function intrinsic_hall_projector_curvature(geometry, occupied::Integer, connection)
    geometry.orthonormal_basis ||
        throw(ArgumentError("NONORTHOGONAL_PROJECTOR_RESPONSE_UNSUPPORTED"))
    vectors = geometry.eigenvectors
    n = length(geometry.energies)
    frame = @view vectors[:, 1:occupied]
    projector = frame * frame'
    derivative = zeros(ComplexF64, n, n, 3)
    for a in 1:3
        band_derivative = zeros(ComplexF64, n, n)
        for m in 1:n, l in 1:n
            delta = Int(m <= occupied) - Int(l <= occupied)
            band_derivative[l, m] = -im * delta * connection[l, m, a]
        end
        derivative[:, :, a] = vectors * band_derivative * vectors'
    end
    all(isfinite, projector) && all(isfinite, derivative) ||
        error("INTRINSIC_HALL_NONFINITE_PROJECTOR_DERIVATIVE")
    result = zeros(Float64, 3, 3)
    for a in 1:3, b in 1:3
        ambient = vectors * geometry.ambient_curvature[:, :, a, b] * vectors'
        all(isfinite, ambient) || error("INTRINSIC_HALL_NONFINITE_PROJECTOR_AMBIENT")
        da, db = derivative[:, :, a], derivative[:, :, b]
        ab, ba = da * db, db * da
        all(isfinite, ab) && all(isfinite, ba) && all(isfinite, ab-ba) ||
            error("INTRINSIC_HALL_NONFINITE_PROJECTOR_COMMUTATOR")
        pf, pc = projector * ambient, projector * (ab-ba)
        all(isfinite, pf) && all(isfinite, pc) ||
            error("INTRINSIC_HALL_NONFINITE_PROJECTOR_PRODUCT")
        value = tr(pf) + im * tr(pc)
        isfinite(value) || error("INTRINSIC_HALL_NONFINITE_PROJECTOR_CONTRACTION")
        result[a, b] = real(value)
    end
    return result
end
