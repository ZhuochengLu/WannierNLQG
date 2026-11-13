"""Normalized local source derivatives for the optional optical cutoff prescription.

The spectrum is the existing complete generalized eigensystem. These source
arrays are not the scalar-frame D_eta geometry and must not replace its Hessian.
Cartesian derivative indices use eV and Angstrom; no response weights are stored.
"""
struct OpticalCutoffSourceJet{S}
    spectrum::S
    hamiltonian_derivatives::Array{ComplexF64, 3}
    hamiltonian_second_derivatives::Array{ComplexF64, 4}
    internal_connection::Array{ComplexF64, 3}
    internal_connection_derivatives::Array{ComplexF64, 4}
end

"""Slot-owned optional source jet and projection scratch, absent from ordinary plans."""
mutable struct NonorthogonalOpticalCutoffData{J}
    source::J
    hamiltonian_gradient::Array{ComplexF64, 3}
    overlap_gradient::Array{ComplexF64, 3}
    raw_connection::Array{ComplexF64, 3}
    projection::Matrix{ComplexF64}
    product::Matrix{ComplexF64}
    second_normalizer::Matrix{ComplexF64}
    convention::WannierCenterConvention
    generation::UInt64
    geometric_regularization_ev::Float64
end

"""Allocate complete Cartesian source jets only for OPTICAL_CUTOFF_VERTICES."""
function NonorthogonalOpticalCutoffData(spectrum, convention = CONVENTION_II)
    n=length(spectrum.energies)
    vector()=zeros(ComplexF64, n, n, 3)
    tensor()=zeros(ComplexF64, n, n, 3, 3)
    matrix()=zeros(ComplexF64, n, n)
    source=OpticalCutoffSourceJet(spectrum, vector(), tensor(), vector(), tensor())
    return NonorthogonalOpticalCutoffData(
        source,
        vector(),
        vector(),
        vector(),
        matrix(),
        matrix(),
        matrix(),
        convention,
        typemax(UInt64),
        NaN,
    )
end

"""Project one raw source channel with the fixed accepted C0, using owned scratch."""
function _project_optical_source!(output, raw, vectors, scratch)
    mul!(scratch, raw, vectors)
    mul!(output, vectors', scratch)
    return output
end

"""Prepare local normalized H/A source jets without another Fourier sum or eigensolve.

C0 is fixed at the evaluation point; M(k)=C0' S(k) C0 and P=M^(-1/2).
At that point P_a=-G_a/2 and P_ab=-G_ab/2+3{G_a,G_b}/8.
The connection is P B P+i P M P_a, B=C0'(r+i S_a)C0. In particular its
source diagonal is retained, rather than replaced by a point parallel gauge.
Raw source derivatives are used once; differentiating the already prepared
D_eta connection here would double count band-frame motion. Generation and eta
are stamped only after successful preparation. No public eta=0 mode is added.
"""
function _prepare_nonorthogonal_optical_cutoff!(
    cutoff,
    matrices,
    spectrum,
    generation,
    eta,
    convention,
)
    cutoff.convention==convention || throw(
        ArgumentError(
            "OPTICAL_CUTOFF_VERTICES requires a new workspace when changing Wannier-center convention",
        ),
    )
    cutoff.generation==generation && cutoff.geometric_regularization_ev==eta && return cutoff
    isfinite(eta) && eta>0 || throw(
        ArgumentError("OPTICAL_CUTOFF_VERTICES requires finite positive geometry regularization"),
    )
    source=cutoff.source
    vectors=spectrum.eigenvectors
    energies=spectrum.energies
    k=cutoff.hamiltonian_gradient
    g=cutoff.overlap_gradient
    raw=cutoff.raw_connection
    projection=cutoff.projection
    product=cutoff.product
    z=cutoff.second_normalizer
    n=length(energies)
    for a in 1:3
        @views _project_optical_source!(
            k[:, :, a],
            matrices.hamiltonian_derivatives[:, :, a],
            vectors,
            projection,
        )
        @views _project_optical_source!(
            g[:, :, a],
            matrices.overlap_derivatives[:, :, a],
            vectors,
            projection,
        )
        @views _project_optical_source!(
            raw[:, :, a],
            matrices.position[:, :, a],
            vectors,
            projection,
        )
        @views raw[:, :, a] .+= im .* g[:, :, a]
        for j in 1:n, i in 1:n
            source.hamiltonian_derivatives[
                i,
                j,
                a,
            ]=k[i, j, a]-(energies[i]+energies[j])*g[i, j, a]/2
            source.internal_connection[i, j, a]=raw[i, j, a]-im*g[i, j, a]/2
        end
    end
    for a in 1:3, b in 1:3
        @views begin
            _project_optical_source!(
                z,
                matrices.overlap_second_derivatives[:, :, a, b],
                vectors,
                projection,
            )
            z .*= -1/2
            mul!(product, g[:, :, a], g[:, :, b]);
            z .+= (3/8) .* product
            mul!(product, g[:, :, b], g[:, :, a]);
            z .+= (3/8) .* product
            h=source.hamiltonian_second_derivatives[:, :, a, b]
            _project_optical_source!(
                h,
                matrices.hamiltonian_second_derivatives[:, :, a, b],
                vectors,
                projection,
            )
            for (left, right) in (
                (g[:, :, a], k[:, :, b]),
                (k[:, :, b], g[:, :, a]),
                (g[:, :, b], k[:, :, a]),
                (k[:, :, a], g[:, :, b]),
            )
                mul!(product, left, right);
                h .-= product ./ 2
            end
            for (first, second) in ((a, b), (b, a))
                for j in 1:n, i in 1:n
                    projection[i, j]=energies[i]*g[i, j, second]
                end
                mul!(product, g[:, :, first], projection);
                h .+= product ./ 4
            end
            for j in 1:n, i in 1:n
                h[i, j]+=(energies[i]+energies[j])*z[i, j]
            end
            connection=source.internal_connection_derivatives[:, :, a, b]
            _project_optical_source!(
                connection,
                matrices.position_derivatives[:, :, a, b],
                vectors,
                projection,
            )
            _project_optical_source!(
                product,
                matrices.overlap_second_derivatives[:, :, a, b],
                vectors,
                projection,
            )
            connection .+= im .* product
            mul!(product, g[:, :, b], raw[:, :, a]);
            connection .-= product ./ 2
            mul!(product, raw[:, :, a], g[:, :, b]);
            connection .-= product ./ 2
            mul!(product, g[:, :, b], g[:, :, a])
            connection .+= im .* (z .- product ./ 4)
        end
    end
    cutoff.generation=generation
    cutoff.geometric_regularization_ev=eta
    return cutoff
end
