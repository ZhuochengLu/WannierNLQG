
using Test, LinearAlgebra, Random
using WannierNLQG

# Independent Liouville equation in a Hamiltonian eigenbasis, excluding intraband drive.
function spectral_liouville_oracle(energy, connection, photon, gamma, mu, temperature)
    kb=8.617333262145e-5
    occupation=[temperature==0 ? Float64(e<mu) : 1/(1+exp((e-mu)/(kb*temperature))) for e in energy]
    rho=zeros(ComplexF64, length(energy), length(energy), 3)
    for b in 1:3, m in eachindex(energy), n in eachindex(energy)
        n==m && continue
        source=im*(occupation[m]-occupation[n])*connection[n, m, b]
        rho[n, m, b]=source/(gamma+im*(energy[n]-energy[m]-photon))
    end
    result=zeros(ComplexF64, 3, 3)
    for b in 1:3, a in 1:3, m in eachindex(energy), n in eachindex(energy)
        velocity=im*(energy[m]-energy[n])*connection[m, n, a]
        result[a, b]+=velocity*rho[n, m, b]
    end
    return result
end

# Independent finite-temperature band-sum F2, in the same dimensionless geometry units.
function orbital_thermal_band_oracle(energy, connection, mu, temperature)
    result=zeros(3)
    kb=8.617333262145e-5
    for n in eachindex(energy)
        occupation=temperature==0 ? Float64(energy[n]<mu) :
                   1/(1+exp((energy[n]-mu)/(kb*temperature)))
        weight=temperature==0 ? max(mu-energy[n], 0) :
               kb*temperature*log1p(exp((mu-energy[n])/(kb*temperature)))
        for m in eachindex(energy)
            n==m && continue
            for (axis, (a, b)) in enumerate(((2, 3), (3, 1), (1, 2)))
                q=connection[n, m, a]*connection[m, n, b]-connection[n, m, b]*connection[m, n, a]
                result[axis]+=(occupation*(energy[m]-energy[n])-2weight)*imag(q)
            end
        end
    end
    return result
end

@testset "Linear and modern orbital response pure contracts" begin
    matrices=WannierNLQG.MatrixElements;
    response=WannierNLQG.Responses
    rng=MersenneTwister(20260915)
    energy=[-0.11, 0.03, 0.17, 0.31]
    u=Matrix(qr(randn(rng, ComplexF64, 4, 4)).Q)
    connection=zeros(ComplexF64, 4, 4, 3);
    dh=similar(connection)
    for a in 1:3
        connection[:, :, a]=Hermitian(randn(rng, ComplexF64, 4, 4))
        dh[:, :, a]=Hermitian(randn(rng, ComplexF64, 4, 4))
    end
    geometry=matrices.spectral_response_geometry(
        energy,
        u,
        dh,
        connection,
        zeros(ComplexF64, 4, 4, 3, 3),
    )
    linear_factor=response.RESPONSE_CHARGE_C^2/response.RESPONSE_HBAR_JS*1e-20
    magnetic_factor=response.RESPONSE_CHARGE_C^2*1e-20/(
        2response.RESPONSE_HBAR_JS*response.RESPONSE_BOHR_MAGNETON
    )
    completion=matrices.finite_model_orbital_completion(4)
    for temperature in (0.0, 200.0, 1500.0), fs in (:gaussian, :lorentzian)
        options=(;
            temperature,
            gamma_intra_ev = 0.021,
            gamma_inter_ev = 0.036,
            fs_kind = fs,
            eta_fs_ev = 0.009,
        )
        dc=response.linear_transport_response(geometry; options..., fermi_energies = Float64[0.01])[
            1,
            :,
            :,
            :,
        ]/linear_factor
        frequencies=[-0.21, 0.0, 0.21, 0.37]
        optical=response.linear_optical_response(
            geometry,
            frequencies;
            options...,
            fermi_energy = 0.01,
        )/linear_factor
        other=response.linear_optical_response(
            geometry,
            frequencies;
            options...,
            fermi_energy = 0.01,
            projector = true,
        )/linear_factor
        @test isapprox(optical, other; rtol = 2e-12, atol = 2e-11)
        @test isapprox(dc, optical[2, :, :, :]; rtol = 2e-12, atol = 2e-11)
        @test isapprox(optical[1, :, :, :], conj.(optical[3, :, :, :]); rtol = 2e-12, atol = 2e-11)
        for (i, photon) in enumerate(frequencies)
            oracle=spectral_liouville_oracle(
                energy,
                geometry.connection,
                photon,
                0.036,
                0.01,
                temperature,
            )
            @test isapprox(
                optical[i, :, :, 2]+optical[i, :, :, 3],
                oracle;
                rtol = 2e-12,
                atol = 2e-11,
            )
            @test isapprox(
                optical[i, :, :, 1],
                transpose(optical[i, :, :, 1]);
                rtol = 2e-12,
                atol = 2e-11,
            )
            @test isapprox(
                optical[i, :, :, 2],
                transpose(optical[i, :, :, 2]);
                rtol = 2e-12,
                atol = 2e-11,
            )
            @test isapprox(
                optical[i, :, :, 3],
                -transpose(optical[i, :, :, 3]);
                rtol = 2e-12,
                atol = 2e-11,
            )
        end
        conventional=response.orbital_magnetization_response(
            geometry,
            completion;
            fermi_energies = Float64[0.01],
            temperature,
        )[
            1,
            :,
            :,
        ]/magnetic_factor
        projector=response.orbital_magnetization_response(
            geometry,
            completion;
            fermi_energies = Float64[0.01],
            temperature,
            projector = true,
        )[
            1,
            :,
            :,
        ]/magnetic_factor
        @test isapprox(conventional, projector; rtol = 2e-12, atol = 2e-11)
        @test isapprox(
            conventional[:, 3],
            orbital_thermal_band_oracle(energy, geometry.connection, 0.01, temperature);
            rtol = 2e-12,
            atol = 2e-11,
        )
        @test conventional[:, 3]≈conventional[:, 1]+conventional[:, 2]
    end
    # Energy-zero invariance includes all energy-weighted completion objects.
    for shift in (-13.2, 4.7)
        shifted=matrices.spectral_response_geometry(
            energy .+ shift,
            u,
            dh,
            connection,
            zeros(ComplexF64, 4, 4, 3, 3),
        )
        a=response.orbital_magnetization_response(
            geometry,
            completion;
            fermi_energies = Float64[0.01],
            temperature = 200.0,
        )
        b=response.orbital_magnetization_response(
            shifted,
            completion;
            fermi_energies = Float64[0.01 + shift],
            temperature = 200.0,
        )
        @test isapprox(a/magnetic_factor, b/magnetic_factor; rtol = 2e-11, atol = 2e-10)
    end
    # Exact degeneracy has rank r, not r squared. Random U(r) rotations stay within blocks.
    doubled_energy=repeat(energy; inner = 2)
    doubled_dh=cat([kron(dh[:, :, a], Matrix{Float64}(I, 2, 2)) for a in 1:3]...; dims = 3)
    doubled_a=cat([kron(connection[:, :, a], Matrix{Float64}(I, 2, 2)) for a in 1:3]...; dims = 3)
    doubled=matrices.spectral_response_geometry(
        doubled_energy,
        Matrix{ComplexF64}(I, 8, 8),
        doubled_dh,
        doubled_a,
        zeros(ComplexF64, 8, 8, 3, 3),
    )
    options=(; temperature = 200.0, gamma_intra_ev = 0.021, gamma_inter_ev = 0.036)
    @test isapprox(
        response.linear_transport_response(
            doubled;
            options...,
            fermi_energies = Float64[0.01],
            projector = true,
        )/linear_factor,
        2response.linear_transport_response(
            geometry;
            options...,
            fermi_energies = Float64[0.01],
        )/linear_factor;
        rtol = 2e-12,
        atol = 2e-11,
    )
    @test_throws ErrorException matrices.spectral_response_geometry(
        [0.0, 1e-12],
        Matrix{ComplexF64}(I, 2, 2),
        zeros(ComplexF64, 2, 2, 3),
        zeros(ComplexF64, 2, 2, 3),
        zeros(ComplexF64, 2, 2, 3, 3),
    )
    # Ambient curvature enters the Berry-curvature/AHE channel as a frequency-independent contact summand.
    curvature=zeros(ComplexF64, 4, 4, 3, 3);
    curvature[:, :, 1, 2].=I(4);
    curvature[:, :, 2, 1].=-I(4)
    curved=matrices.spectral_response_geometry(energy, u, dh, connection, curvature)
    response_with_contact=response.linear_optical_response(
        curved,
        [0.0, 0.21];
        options...,
        fermi_energy = 0.01,
    )/linear_factor
    flat_response=response.linear_optical_response(
        geometry,
        [0.0, 0.21];
        options...,
        fermi_energy = 0.01,
    )/linear_factor
    @test response_with_contact[
        1,
        1,
        2,
        3,
    ]-flat_response[1, 1, 2, 3]≈-sum(response.response_occupation(e, 0.01, 200.0) for e in energy)
    @test response_with_contact[
        1,
        :,
        :,
        3,
    ]-flat_response[1, :, :, 3]≈response_with_contact[2, :, :, 3]-flat_response[2, :, :, 3]
    # Dielectric background is included once, only in the integrated total.
    sigma=response.linear_optical_response(geometry, [0.0, 0.21]; options..., fermi_energy = 0.01)
    dielectric=response.model_dielectric_response(sigma, [0.0, 0.21]; integrated = true)
    @test dielectric.indices==[2]
    @test dielectric.undefined_zero_frequency==[1]
    @test dielectric.total[1, :, :]≈I(3)+dielectric.increments[1, :, :, 4]
    @test response.model_dielectric_response(
        sigma,
        [0.0, 0.21];
        integrated = false,
    ).total==dielectric.increments[:, :, :, 4]
    @test response.response_fermi_derivative(1e6, 0.0, 300.0, :none, 0.0)==0
    @test response.response_thermal_weight(-1e6, 0.0, 300.0)≈1e6
end

@testset "Orbital external completion against a larger closed model" begin
    matrices=WannierNLQG.MatrixElements;
    response=WannierNLQG.Responses
    rng=MersenneTwister(813)
    energy=[-0.11, 0.03, 0.17, 0.31, 2.0, 3.0]
    a=zeros(ComplexF64, 6, 6, 3)
    for axis in 1:3
        a[:, :, axis]=Hermitian(randn(rng, ComplexF64, 6, 6))
    end
    full=matrices.spectral_response_geometry(
        energy,
        Matrix{ComplexF64}(I, 6, 6),
        zeros(ComplexF64, 6, 6, 3),
        a,
        zeros(ComplexF64, 6, 6, 3, 3),
    )
    reduced=matrices.spectral_response_geometry(
        energy[1:4],
        Matrix{ComplexF64}(I, 4, 4),
        zeros(ComplexF64, 4, 4, 3),
        a[1:4, 1:4, :],
        zeros(ComplexF64, 4, 4, 3, 3),
    )
    f=zeros(ComplexF64, 4, 4, 3, 3);
    c=similar(f)
    for y in 1:3, x in 1:3
        f[:, :, x, y]=a[1:4, 5:6, x]*a[5:6, 1:4, y]
        c[:, :, x, y]=a[1:4, 5:6, x]*Diagonal(energy[5:6])*a[5:6, 1:4, y]
    end
    completion=matrices.OrbitalCompletion(f, zeros(ComplexF64, 4, 4, 3), c)
    factor=response.RESPONSE_CHARGE_C^2*1e-20/(
        2response.RESPONSE_HBAR_JS*response.RESPONSE_BOHR_MAGNETON
    )
    for temperature in (0.0, 200.0)
        reference=response.orbital_magnetization_response(
            full,
            matrices.finite_model_orbital_completion(6);
            fermi_energies = Float64[0.01],
            temperature,
        )[
            1,
            :,
            :,
        ]/factor
        for projector in (false, true)
            value=response.orbital_magnetization_response(
                reduced,
                completion;
                fermi_energies = Float64[0.01],
                temperature,
                projector,
            )[
                1,
                :,
                :,
            ]/factor
            @test isapprox(value, reference; rtol = 2e-12, atol = 2e-11)
        end
        # A missing completion is measurably different, never equivalent to zero by default.
        incomplete=response.orbital_magnetization_response(
            reduced,
            matrices.finite_model_orbital_completion(4);
            fermi_energies = Float64[0.01],
            temperature,
        )[
            1,
            :,
            :,
        ]/factor
        @test maximum(abs, incomplete-reference)>0.01
    end
    # Nonzero energy-weighted cross completion has independently contracted signs.
    b=randn(rng, ComplexF64, 4, 4, 3)
    completion_with_cross=matrices.OrbitalCompletion(f, b, c)
    left=response.orbital_magnetization_response(
        reduced,
        completion_with_cross;
        fermi_energies = Float64[0.01],
        temperature = 200.0,
    )[
        1,
        :,
        :,
    ]/factor
    right=response.orbital_magnetization_response(
        reduced,
        completion_with_cross;
        fermi_energies = Float64[0.01],
        temperature = 200.0,
        projector = true,
    )[
        1,
        :,
        :,
    ]/factor
    @test isapprox(left, right; rtol = 2e-12, atol = 2e-11)
    missing_qualification=matrices.validate_orbital_sources(
        (; operator_qualification = Dict()),
        :direct_energy_overlap,
        0.0,
        300.0,
    )
    @test isempty(missing_qualification.conflicting_contracts)
    @test "orbital_response.qualification" in missing_qualification.unverified_contracts
    @test "ORBITAL_RESPONSE_QUALIFICATION_NOT_RECORDED" in missing_qualification.reasons
    @test "ORBITAL_COMMON_FRAME_UNVERIFIED" in missing_qualification.reasons
end

@testset "Independent finite-difference spectral projector" begin
    isdefined(@__MODULE__, :spectral_test_model) ||
        include(joinpath(@__DIR__, "SpectralResponseTestSupport.jl"))
    matrices=WannierNLQG.MatrixElements
    model=spectral_test_model()
    plan=matrices.compile_matrix_plan(
        matrices.MatrixElementRequest(
            matrices.HAMILTONIAN_DERIVATIVES,
            matrices.INTERNAL_CONNECTION,
            matrices.WANNIER_CURVATURE;
            spatial_dimension = 3,
            denominator_regularization = 0.0,
            degeneracy_threshold = 0.0,
        ),
    )
    workspace=matrices.MatrixElementWorkspace(model, plan);
    matrices.prepare_real_space!(workspace, model)
    center=[0.99, 0.21, 0.37]
    data=matrices.compute_kpoint!(workspace, model, center)
    geometry=matrices.spectral_response_geometry(data)
    u=copy(data.spectrum.eigenvectors);
    p=u[:, 1:1]*u[:, 1:1]';
    q=I(2)-p
    connection=copy(data.position.wannier_gauge)
    reference=matrices.conventional_spectral_pair(geometry, 1:1, 2:2)
    errors=Float64[]
    for step in (2e-3, 1e-3, 5e-4)
        derivatives=Matrix{ComplexF64}[]
        for a in 1:3
            cart=zeros(3);
            cart[a]=step
            fractional=WannierNLQG.Core.reciprocal_cartesian_to_fractional(cart, model.lattice)
            plus=matrices.compute_kpoint!(workspace, model, center+fractional).spectrum.eigenvectors[
                :,
                1:1,
            ]
            plus_projector=plus*plus'
            minus=matrices.compute_kpoint!(workspace, model, center-fractional).spectrum.eigenvectors[
                :,
                1:1,
            ]
            minus_projector=minus*minus'
            push!(
                derivatives,
                (
                    plus_projector-minus_projector
                )/(2step)-im*(connection[:, :, a]*p-p*connection[:, :, a]),
            )
        end
        numerical=ComplexF64[tr(p*derivatives[a]*q*derivatives[b]) for a in 1:3, b in 1:3]
        push!(errors, maximum(abs, numerical-reference))
    end
    @test errors[2]<0.3errors[1]
    @test errors[3]<0.3errors[2]
    @test errors[3]<1e-5
end

@testset "SI Drude conversion and degenerate block frame invariance" begin
    matrices=WannierNLQG.MatrixElements
    responses=WannierNLQG.Responses
    charge=1.602176634e-19
    hbar=1.054571817e-34
    kb=8.617333262145e-5
    derivative=reshape(ComplexF64[2.3, 0, 0], 1, 1, 3)
    single=matrices.spectral_response_geometry(
        [0.0],
        ones(ComplexF64, 1, 1),
        derivative,
        zeros(ComplexF64, 1, 1, 3),
        zeros(ComplexF64, 1, 1, 3, 3),
    )
    velocity=2.3*charge*1e-10/hbar
    lifetime=hbar/(0.04*charge)
    density_derivative_per_joule=1/(4kb*300charge)
    expected=charge^2*velocity^2*lifetime*density_derivative_per_joule
    for projector in (false, true)
        actual=responses.linear_transport_response(
            single;
            projector,
            fermi_energies = Float64[0.0],
            temperature = 300.0,
            gamma_intra_ev = 0.04,
            gamma_inter_ev = 0.05,
        )
        @test isapprox(actual[1, 1, 1, 1], expected; rtol = 1e-9, atol = 0)
    end
    rng=MersenneTwister(67349)
    energy=[-0.1, -0.1, 0.2, 0.2]
    u=Matrix(qr(randn(rng, ComplexF64, 4, 4)).Q)
    rotation=zeros(ComplexF64, 4, 4)
    rotation[1:2, 1:2]=Matrix(qr(randn(rng, ComplexF64, 2, 2)).Q)
    rotation[3:4, 3:4]=Matrix(qr(randn(rng, ComplexF64, 2, 2)).Q)
    dh=cat([Matrix(Hermitian(randn(rng, ComplexF64, 4, 4))) for a in 1:3]...; dims = 3)
    a=cat([Matrix(Hermitian(randn(rng, ComplexF64, 4, 4))) for a in 1:3]...; dims = 3)
    transform(x)=cat([rotation'*x[:, :, axis]*rotation for axis in 1:3]...; dims = 3)
    g1=matrices.spectral_response_geometry(energy, u, dh, a, zeros(ComplexF64, 4, 4, 3, 3))
    g2=matrices.spectral_response_geometry(
        energy,
        u*rotation,
        transform(dh),
        transform(a),
        zeros(ComplexF64, 4, 4, 3, 3),
    )
    options=(; temperature = 300.0, gamma_intra_ev = 0.04, gamma_inter_ev = 0.05)
    for projector in (false, true)
        dc1=responses.linear_transport_response(
            g1;
            projector,
            options...,
            fermi_energies = Float64[0.0],
        )
        dc2=responses.linear_transport_response(
            g2;
            projector,
            options...,
            fermi_energies = Float64[0.0],
        )
        @test isapprox(dc1, dc2; rtol = 1e-12, atol = 0)
        op1=responses.linear_optical_response(
            g1,
            [0.0, 0.3];
            projector,
            options...,
            fermi_energy = 0.0,
        )
        op2=responses.linear_optical_response(
            g2,
            [0.0, 0.3];
            projector,
            options...,
            fermi_energy = 0.0,
        )
        @test isapprox(op1, op2; rtol = 1e-12, atol = 0)
    end
end

@testset "Raw orbital completion frame and provenance" begin
    m=WannierNLQG.MatrixElements
    rng=MersenneTwister(19827)
    h=ComplexF64[-0.2 0; 0 0.3]
    a=cat([Matrix(Hermitian(randn(rng, ComplexF64, 2, 2))) for axis in 1:3]...; dims = 3)
    tb=randn(rng, ComplexF64, 2, 2, 3)
    tf=zeros(ComplexF64, 2, 2, 3, 3);
    tc=similar(tf)
    for y in 1:3, x in 1:y
        tf[:, :, x, y]=randn(rng, ComplexF64, 2, 2);
        tc[:, :, x, y]=randn(rng, ComplexF64, 2, 2)
        tf[:, :, y, x]=tf[:, :, x, y]';
        tc[:, :, y, x]=tc[:, :, x, y]'
    end
    b=cat([h*a[:, :, x]+tb[:, :, x] for x in 1:3]...; dims = 3)
    f=similar(tf);
    c=similar(tc)
    for y in 1:3, x in 1:3
        f[:, :, x, y]=tf[:, :, x, y]+a[:, :, x]*a[:, :, y]
        c[
            :,
            :,
            x,
            y,
        ]=tc[:, :, x, y]+a[:, :, x]*b[:, :, y]+b[:, :, x]'*a[:, :, y]-a[:, :, x]*h*a[:, :, y]
    end
    axial=cat(
        [im*(c[:, :, x, y]-c[:, :, y, x]) for (x, y) in ((2, 3), (3, 1), (1, 2))]...;
        dims = 3,
    )
    model=WannierNLQG.Core.TightBindingModel(
        Matrix{Float64}(I, 3, 3),
        2,
        1,
        [1],
        zeros(Int, 3, 1),
        reshape(h, 2, 2, 1),
        reshape(a, 2, 2, 3, 1),
    )
    sources=m.OrbitalRealSpaceSources(
        reshape(b, 2, 2, 3, 1),
        reshape(f, 2, 2, 3, 3, 1),
        reshape(axial, 2, 2, 3, 1),
        Dict{String, Any}(),
    )
    u=Matrix(qr(randn(rng, ComplexF64, 2, 2)).Q)
    phases=cis.([0.2, -0.4]);
    v=Diagonal(phases)*u
    workspace=(;
        data = (; fourier_factors = ComplexF64[1], spectrum = (; eigenvectors = u)),
        scratch = (; center_phase_factors = phases),
    )
    got=m.orbital_completion(sources, model, workspace)
    for x in 1:3
        @test got.energy_connection[:, :, x]≈v'*tb[:, :, x]*v
        for y in 1:3
            @test got.derivative_overlap[:, :, x, y]≈v'*tf[:, :, x, y]*v
            @test got.energy_overlap[
                :,
                :,
                x,
                y,
            ]-got.energy_overlap[:, :, y, x]≈v'*(tc[:, :, x, y]-tc[:, :, y, x])*v
        end
    end
    names=(
        "hamiltonian",
        "position",
        "hamiltonian_weighted_connection",
        "derivative_overlap_tensor",
        "hamiltonian_weighted_axial_derivative_overlap",
    )
    hashes=Dict(name=>repeat("a", 64) for name in names)
    record=Dict{String, Any}(
        "input_semantics"=>"direct_energy_overlap",
        "frame_status"=>"PASS",
        "derivative_frame"=>"uncentered_periodic_wannier",
        "window_status"=>"PASS",
        "validated_energy_window_ev"=>[-1.0, 1.0],
        "operator_source_sha256"=>hashes,
    )
    operators=Dict(
        name=>Dict(
            "source_status"=>"PASS",
            "gauge_status"=>"PASS",
            "target_band_gauge"=>"hamiltonian_eigenframe",
            "source_artifact_sha256"=>hashes[name],
        ) for name in names
    )
    manifest=(; operator_qualification = Dict("orbital_response"=>record, "operators"=>operators))
    complete=m.validate_orbital_sources(manifest, :direct_energy_overlap, 0.0, 300.0)
    @test complete.record==record
    @test isempty(complete.conflicting_contracts)
    @test isempty(complete.unverified_contracts)
    record["derivative_frame"]="centered"
    frame_conflict=m.validate_orbital_sources(manifest, :direct_energy_overlap, 0.0, 300.0)
    @test "orbital_response.derivative_frame" in frame_conflict.conflicting_contracts
    record["derivative_frame"]="uncentered_periodic_wannier"
    thermal_unverified=m.validate_orbital_sources(manifest, :direct_energy_overlap, 0.0, 1500.0)
    @test isempty(thermal_unverified.conflicting_contracts)
    @test "orbital.thermal_tail" in thermal_unverified.unverified_contracts
    @test "ORBITAL_THERMAL_TAIL_UNVERIFIED" in thermal_unverified.reasons

    optional_only_operators=deepcopy(operators)
    delete!(optional_only_operators["position"], "target_band_gauge")
    optional_only_manifest=(;
        operator_qualification = Dict(
            "orbital_response"=>record,
            "operators"=>optional_only_operators,
        ),
    )
    optional_only=m.validate_orbital_sources(
        optional_only_manifest,
        :direct_energy_overlap,
        0.0,
        300.0,
    )
    @test "orbital.common_frame" in optional_only.unverified_contracts
    @test "orbital_response.common_frame" in optional_only.unverified_contracts
    @test "ORBITAL_COMMON_FRAME_UNVERIFIED" in optional_only.reasons

    delete!(optional_only_operators["position"], "source_artifact_sha256")
    optional_hash_only=m.validate_orbital_sources(
        optional_only_manifest,
        :direct_energy_overlap,
        0.0,
        300.0,
    )
    @test "orbital_response.operator_source_sha256.position" in
          optional_hash_only.unverified_contracts
    @test "ORBITAL_OPERATOR_SOURCE_HASH_UNVERIFIED" in optional_hash_only.reasons

    record["operator_source_sha256"]["position"]=repeat("b", 64)
    hash_conflict=m.validate_orbital_sources(manifest, :direct_energy_overlap, 0.0, 300.0)
    @test "orbital_response.operator_source_sha256.position" in hash_conflict.conflicting_contracts
end
