"""Prepare complete static geometry using the existing operator workspace.

No regularized Berry connection is borrowed. All returned geometry is owned;
workspace arrays may be reused at the next k point without changing the result.
"""
function prepare_intrinsic_hall_geometry!(workspace, model, kpoint)
    data = compute_kpoint!(workspace, model, kpoint)
    energies = data.spectrum.energies
    h = data.hamiltonian.derivatives
    a = data.position.internal_connection
    velocity = copy(h)
    for axis in 1:3, m in eachindex(energies), n in eachindex(energies)
        velocity[n, m, axis] += im*(energies[n]-energies[m])*a[n, m, axis]
    end
    return intrinsic_hall_geometry(
        energies,
        data.spectrum.eigenvectors,
        velocity,
        data.position.hamiltonian_curvature,
        ;
        orthonormal_basis = true,
    )
end

"""Use the admitted generalized spectrum and full metric jets directly.

Bypass the old finite-width scalar-tangent completion entirely; Mixed must
provide all planned H/S/r derivative groups without a silent Direct fallback.
"""
function prepare_intrinsic_hall_geometry!(workspace, model::NonorthogonalLocalizedModel, kpoint)
    spectrum = compute_spectrum!(workspace, model, kpoint)
    matrices = _workspace_nonorthogonal_operators(workspace, model, kpoint; full = true)
    return nonorthogonal_intrinsic_hall_geometry(matrices, spectrum)
end
