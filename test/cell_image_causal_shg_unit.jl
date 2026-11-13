module CellImageCausalSHGTests

using Test, LinearAlgebra, WannierNLQG
const C=WannierNLQG.Core
const ME=WannierNLQG.MatrixElements
const R=WannierNLQG.Responses
const IOP=WannierNLQG.IO

"""Four-site finite molecule encoded with a nontrivial y lattice embedding."""
function molecule_model(delta)
    u=Matrix{ComplexF64}(I, 4, 4)
    for (i, j, t, p) in
        [(1, 2, 0.31, 0.23), (1, 3, 0.53, 0.17), (2, 4, 0.42, 0.37), (3, 4, 0.28, 0.12)]
        v=Matrix{ComplexF64}(I, 4, 4);
        v[i, i]=v[j, j]=cos(t);
        v[i, j]=sin(t)*cis(p);
        v[j, i]=-sin(t)*cis(-p);
        u=u*v
    end
    h=u*Diagonal([-1.0, -1+delta, 1.0, 1+delta])*u'
    p=[0, 0, 1, 1];
    support=Int[0 0 0; -1 0 1; 0 0 0]
    hr=zeros(ComplexF64, 4, 4, 3);
    rr=zeros(ComplexF64, 4, 4, 3, 3)
    for n in 1:4, m in 1:4
        ;
        hr[n, m, p[n] - p[m] + 2]=h[n, m];
    end
    for (n, z) in enumerate([0.0, 0.7, 2.3, -0.4])
        ;
        rr[n, n, 3, 2]=z;
    end
    C.TightBindingModel(Matrix(Diagonal([4.0, 4.0, 20.0])), 4, 3, ones(Int, 3), support, hr, rr), h
end

"""Independent orbital-basis sixteen-dimensional causal density solve."""
function molecular_reference(h, w, gamma)
    y=Matrix(Diagonal([0.0, 0.0, -4.0, -4.0]));
    z=Matrix(Diagonal([0.0, 0.7, 2.3, -0.4]))
    ev=eigen(Hermitian(h));
    f=ev.vectors[:, 1:2]*ev.vectors[:, 1:2]'
    id=Matrix{ComplexF64}(I, 4, 4);
    id16=Matrix{ComplexF64}(I, 16, 16)
    l=kron(id, h)-kron(transpose(h), id)
    rho1=reshape(((w+im*gamma)*id16-l)\vec(z*f-f*z), 4, 4)
    rho2=reshape(((2w+im*gamma)*id16-l)\vec(z*rho1-rho1*z), 4, 4)
    p=tr(y*rho2);
    j=tr(im*(h*y-y*h)*rho2)
    return p, j, -2im*w*p
end

"""Build only the complete raw derivative tensors consumed by the new kernel."""
function point_data(model, k, convention = C.CONVENTION_II)
    req=ME.MatrixElementRequest(
        ME.HAMILTONIAN_DERIVATIVES,
        ME.HAMILTONIAN_SECOND_DERIVATIVES,
        ME.INTERNAL_CONNECTION,
        ME.INTERNAL_CONNECTION_DERIVATIVES;
        spatial_dimension = 3,
    )
    ws=ME.MatrixElementWorkspace(
        model,
        ME.compile_matrix_plan(req; wannier_center_convention = convention),
    )
    ME.prepare_real_space!(ws, model);
    ME.compute_kpoint!(ws, model, k)
end

"""Evaluate the explicit research quantities without the old SHG term interface."""
function causal_values(model, k, frequencies, policy, convention = C.CONVENTION_II)
    data=point_data(model, k, convention);
    geometry=R.same_rate_lorentz_shg_geometry(data, policy)
    output=zeros(ComplexF64, length(frequencies), 1, 3)
    R.same_rate_lorentz_shg_response!(output, geometry, frequencies, [(2, 3, 3)], policy)
    data, output
end

"""Independently evaluate Fourier H/r in the input orbital frame."""
function raw_fourier(model, k)
    h=zeros(ComplexF64, model.num_orbitals, model.num_orbitals)
    r=zeros(ComplexF64, model.num_orbitals, model.num_orbitals, 3)
    for j in 1:model.num_r_vectors
        phase=cis(2pi*dot(k, model.r_vectors[:, j]))/model.r_degeneracies[j]
        h.+=phase .* model.hamiltonian_r[:, :, j];
        r.+=phase .* model.position_r[:, :, :, j]
    end
    h, r
end

@testset "Explicit equal-rate Lorentz SHG and independent molecular response" begin
    @test_throws ArgumentError R.SameRateLorentzSHGPolicy(0.0, 0.0, 2)
    @test_throws ArgumentError R.SameRateLorentzSHGPolicy(0.04, NaN, 2)
    policy=R.SameRateLorentzSHGPolicy(0.04, 0.0, 2)
    frequencies=[0.65, 0.98, 1.3, -0.98, 0.0]
    for delta in [0.2, 0.0], convention in [C.CONVENTION_I, C.CONVENTION_II]
        model, h=molecule_model(delta)
        data, out=causal_values(model, [0.11, 0.173, 0.037], frequencies, policy, convention)
        @test all(isfinite, out)
        for (i, w) in enumerate(frequencies)
            ref=molecular_reference(h, w, policy.width)
            @test vec(out[i, 1, :])≈collect(ref) atol=2e-12 rtol=2e-12
            @test out[i, 1, 2]≈(policy.width-2im*w)*out[i, 1, 1] atol=2e-12 rtol=2e-12
            @test out[i, 1, 3]≈-2im*w*out[i, 1, 1] atol=2e-12 rtol=2e-12
        end
        @test vec(out[4, 1, :])≈conj.(vec(out[2, 1, :])) atol=2e-12 rtol=2e-12
        shifts=Int[0 0 0 0; 0 0 0 0; 0 1 -1 2]
        translated=ME.relabel_wannier_cell_images(model, shifts)
        _, changed=causal_values(translated, [0.11, 0.173, 0.037], frequencies, policy, convention)
        @test out≈changed atol=2e-12 rtol=2e-12
        @test_throws ArgumentError R.same_rate_lorentz_shg_geometry(
            data,
            R.SameRateLorentzSHGPolicy(0.04, 0.0, 1),
        )
    end
end

@testset "Exact degenerate block mixing in raw tensors" begin
    model, _=molecule_model(0.0);
    policy=R.SameRateLorentzSHGPolicy(0.04, 0.0, 2)
    data, base=causal_values(model, [0.1, 0.173, 0.03], [0.65, 0.98, 1.3], policy)
    for (t, p) in [(0.37, 0.53), (1.17, -0.83), (0.08, 1.42)]
        u=zeros(ComplexF64, 4, 4)
        for (i, j, tt, pp) in [(1, 2, t, p), (3, 4, t+0.31, p-0.27)]
            u[i, i]=u[j, j]=cos(tt);
            u[i, j]=sin(tt)*cis(pp);
            u[j, i]=-sin(tt)*cis(-pp)
        end
        rotated=deepcopy(data)
        for field in [
            :hamiltonian_derivatives,
            :hamiltonian_second_derivatives,
            :internal_connection,
            :internal_connection_derivatives,
        ]
            a=getproperty(rotated, field);
            flat=reshape(a, 4, 4, :)
            for q in axes(flat, 3)
                ;
                flat[:, :, q].=u'*flat[:, :, q]*u;
            end
        end
        geometry=R.same_rate_lorentz_shg_geometry(rotated, policy);
        out=similar(base)
        R.same_rate_lorentz_shg_response!(out, geometry, [0.65, 0.98, 1.3], [(2, 3, 3)], policy)
        @test out≈base atol=2e-12 rtol=2e-12
    end
end

@testset "Integer cell images, transverse derivatives, and affine Fourier split" begin
    model, _=molecule_model(0.2);
    shifts=Int[0 0 0 0; 0 0 0 0; 0 1 -1 2]
    wrapped=ME.relabel_wannier_cell_images(model, shifts)
    back=ME.relabel_wannier_cell_images(wrapped, -shifts)
    k=[0.11, 0.173, 0.037];
    h, r=raw_fourier(model, k);
    hw, rw=raw_fourier(wrapped, k)
    phase=Diagonal(cis.(2pi .* vec(transpose(k)*shifts)))
    translations=transpose(model.lattice)*shifts
    @test hw≈phase*h*phase' atol=2e-12 rtol=2e-12
    for a in 1:3
        @test rw[:, :, a]≈phase*r[:, :, a]*phase'+Diagonal(translations[a, :]) atol=2e-12 rtol=2e-12
    end
    hb, rb=raw_fourier(back, k)
    @test h==hb
    @test r≈rb atol=2e-12 rtol=2e-12
    # Independent finite differences bound the derivative of the translated frame.
    step=1e-6;
    fractional_step=step*model.lattice[3, 3]/(2pi)
    plus, _=raw_fourier(wrapped, k+[0, 0, fractional_step]);
    minus, _=raw_fourier(wrapped, k-[0, 0, fractional_step])
    t=Diagonal(translations[3, :]);
    expected=im*(t*hw-hw*t)
    numerical=(plus-minus)/(2step)
    bound=step^2*maximum(abs, hw)*maximum(
        abs,
        translations[3, :],
    )^3*8/6+8eps(Float64)*maximum(abs, hw)/step
    @test maximum(abs, numerical-expected)<=bound
    count=4;
    points=4;
    support=Int[0 0 0 0 0; -2 -1 0 1 2; 0 0 0 0 0]
    target=C.TightBindingModel(
        model.lattice,
        count,
        5,
        [2, 1, 1, 1, 2],
        support,
        zeros(ComplexF64, 4, 4, 5),
        zeros(ComplexF64, 4, 4, 3, 5),
    )
    coordinates=hcat(zeros(4), collect(0:3) ./ 4, zeros(4))
    chk=IOP.WannierCHK(
        4,
        4,
        points,
        (1, 4, 1),
        coordinates,
        model.lattice,
        2pi*inv(model.lattice),
        zeros(4, 3),
        repeat(reshape(Matrix{ComplexF64}(I, 4, 4), 4, 4, 1), 1, 1, 4),
    )
    converted=ME.lattice_ws_reinterpolate_hr(wrapped, chk, target; cell_shifts = -shifts)
    hc, rc=raw_fourier(converted.model, k)
    @test h≈hc atol=2e-12 rtol=2e-12
    @test r≈rc atol=2e-12 rtol=2e-12
    @test converted.coordinates_replaced===false
    @test converted.production_eligible===false
    @test_throws ArgumentError ME.lattice_ws_reinterpolate_hr(
        wrapped,
        chk,
        target;
        cell_shifts = zeros(Int, 3, 4),
    )
    @test_throws ArgumentError ME.relabel_wannier_cell_images(model, zeros(Int, 2, 4))
end

end
