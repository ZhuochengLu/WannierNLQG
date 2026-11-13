using LinearAlgebra

# Direct finite Fourier polynomial reference: no production connection/link provider is used.
function optical472_model()
    C = WannierNLQG.Core
    lattice = [3.0 0.2 0.1; 0.0 4.0 0.3; 0.1 0.0 5.0]
    centers = [0.13 -0.21 0.31; -0.17 0.09 0.24; 0.04 0.18 -0.12]
    rv = [0 1 -1; 0 0 0; 0 0 0]
    h = zeros(ComplexF64, 3, 3, 3)
    h[:, :, 1] = [-0.7 0.12+0.08im 0.03; 0.12-0.08im 0.4 -0.09im; 0.03 0.09im 1.3]
    h[:, :, 2] = [0.04 0.02im 0.015; 0.011 0.025 -0.007im; 0.003im 0.008 -0.02]
    h[:, :, 3] = h[:, :, 2]'
    ar = zeros(ComplexF64, 3, 3, 3, 3)
    for d in 1:3
        ar[:, :, d, 1] = Matrix(Diagonal((lattice' * centers)[d, :]))
        ar[1, 2, d, 1] = 0.03d + 0.017im
        ar[2, 1, d, 1] = conj(ar[1, 2, d, 1])
        ar[:, :, d, 2] =
            ComplexF64[0.002d 0.013im 0.007d; 0.005 0.003 0.004im; 0.009im 0.001 -0.002]
        ar[:, :, d, 3] = ar[:, :, d, 2]'
    end
    return C.TightBindingModel(lattice, 3, 3, ones(Int, 3), rv, h, ar), centers
end

function optical472_reference(model, k)
    h=zeros(ComplexF64, 3, 3);
    a=zeros(ComplexF64, 3, 3, 3);
    dh=similar(a);
    fill!(dh, 0)
    for r in 1:model.num_r_vectors
        phase=exp(2pi*im*dot(k, model.r_vectors[:, r])) / model.r_degeneracies[r]
        h += phase*model.hamiltonian_r[:, :, r]
        rc=model.lattice'*model.r_vectors[:, r]
        for d in 1:3
            a[:, :, d] += phase*model.position_r[:, :, d, r]
            dh[:, :, d] += im*rc[d]*phase*model.hamiltonian_r[:, :, r]
        end
    end
    return h, a, dh
end

# These references assemble the operator from the finite Fourier coefficients,
# not from production physical_velocity_vertices or the new optical provider.
function optical472_velocity_reference(model, centers, convention, data, axis)
    C=WannierNLQG.Core
    h, a, dh=optical472_reference(model, data.common.kpoint)
    d=convention==C.CONVENTION_I ? Diagonal(exp.(2pi*im*(centers'*data.common.kpoint))) : I
    v=dh[:, :, axis]+im*(h*a[:, :, axis]-a[:, :, axis]*h)
    u=data.spectrum.source_eigenvectors
    return u'*d'*v*d*u
end
function optical472_band_link_reference(model, centers, convention, left, right, center, q)
    a=optical472_reference(model, center)[2]
    f=Matrix{ComplexF64}(I, 3, 3)+im*sum(q[d]*a[:, :, d] for d in 1:3)
    if convention==WannierNLQG.Core.CONVENTION_I
        f=Diagonal(exp.(-2pi*im*(centers'*left.common.kpoint)))*f*Diagonal(
            exp.(2pi*im*(centers'*right.common.kpoint)),
        )
    end
    return left.spectrum.source_eigenvectors'*f*right.spectrum.source_eigenvectors
end
