module BerryMultipoleDCUnit
using Test, LinearAlgebra, WannierNLQG
const R=WannierNLQG.Responses
@testset "independent DC occupation and broadening controls" begin
    @test_throws ArgumentError R.BerryMultipoleDCParameters(
        relaxation_time_fs = 1,
        temperature_k = 0,
    )
    @test_throws ArgumentError R.BerryMultipoleDCParameters(
        relaxation_time_fs = 0,
        temperature_k = 300,
    )
    @test_throws ArgumentError R.BerryMultipoleDCParameters(
        relaxation_time_fs = Inf,
        temperature_k = 300,
    )
    @test_throws ArgumentError R.BerryMultipoleDCParameters(
        relaxation_time_fs = 1,
        temperature_k = -1,
    )
    @test_throws ArgumentError R.BerryMultipoleDCParameters(
        relaxation_time_fs = 1,
        temperature_k = 300,
        eta_fs_ev = 0.01,
    )
    @test_throws ArgumentError R.BerryMultipoleDCParameters(
        relaxation_time_fs = 1,
        temperature_k = 0,
        eta_fs_ev = 0.01,
        fs_kind = :lorentzian,
    )
    @test_throws ArgumentError R.BerryMultipoleDCParameters(
        relaxation_time_fs = 1,
        temperature_k = 0,
        eta_fs_ev = 0.01,
        integral_form = :fermi_sea,
    )
    fs=R.BerryMultipoleDCParameters(relaxation_time_fs = 2, temperature_k = 0, eta_fs_ev = 0.02)
    @test R.berry_multipole_surface_weight(fs, 0.0, 0.0) ≈ 1/(sqrt(pi)*0.02)
    # No value floor is allowed in the finite-width Gaussian tail.
    @test 0 < R.berry_multipole_surface_weight(fs, 0.16, 0.0) < 1e-14
    thermal=R.BerryMultipoleDCParameters(relaxation_time_fs = 2, temperature_k = 300)
    @test R.berry_multipole_surface_weight(thermal, 0.0, 0.0) ≈ 1/(4*8.617333262145e-5*300)
    sea=R.BerryMultipoleDCParameters(
        relaxation_time_fs = 2,
        temperature_k = 0,
        integral_form = :fermi_sea,
    )
    @test R.berry_multipole_sea_weight(sea, -1.0, 0.0)==1
    @test R.berry_multipole_sea_weight(sea, 0.0, 0.0)==0.5
    @test R.berry_multipole_sea_weight(sea, 1.0, 0.0)==0
    @test_throws ArgumentError R.berry_multipole_sea_weight(fs, 0.0, 0.0)
    @test_throws ArgumentError R.berry_multipole_surface_weight(sea, 0.0, 0.0)
end
@testset "SI tensor maps, lifetime powers and Hall transversality" begin
    dipole=[(a-b)*sin(c+0.2a+0.2b) for a in 1:3, b in 1:3, c in 1:3]
    quadrupole=[(a-b)*cos(c+d+0.2a+0.2b) for a in 1:3, b in 1:3, c in 1:3, d in 1:3]
    parameters=R.BerryMultipoleDCParameters(relaxation_time_fs = 7, temperature_k = 300)
    doubled=R.BerryMultipoleDCParameters(relaxation_time_fs = 14, temperature_k = 300)
    sigma2=R.berry_dipole_dc_conductivity(dipole, parameters; spatial_dimension = 3)
    sigma3=R.berry_quadrupole_dc_conductivity(quadrupole, parameters; spatial_dimension = 3)
    @test maximum(abs, sigma2)>0
    @test maximum(abs, sigma3)>0
    @test R.berry_dipole_dc_conductivity(dipole, doubled; spatial_dimension = 3)==2sigma2
    @test R.berry_quadrupole_dc_conductivity(quadrupole, doubled; spatial_dimension = 3)==4sigma3
    @test R.berry_dipole_dc_conductivity(dipole, parameters; spatial_dimension = 2) ≈ 1e-10sigma2
    @test R.berry_quadrupole_dc_conductivity(quadrupole, parameters; spatial_dimension = 2) ≈
          1e-10sigma3
    @test sigma2 ≈ permutedims(sigma2, (2, 1, 3))
    @test sigma3 ≈ permutedims(sigma3, (2, 1, 3, 4))
    @test sigma3 ≈ permutedims(sigma3, (3, 2, 1, 4))
    field=[0.31, -0.73, 0.57]
    longitudinal2=sum(field[a]*field[b]*field[c]*sigma2[b, c, a] for a in 1:3, b in 1:3, c in 1:3)
    longitudinal3=sum(
        field[a]*field[b]*field[c]*field[d]*sigma3[b, c, d, a] for
        a in 1:3, b in 1:3, c in 1:3, d in 1:3
    )
    @test abs(longitudinal2)<=1e-13maximum(abs, sigma2)
    @test abs(longitudinal3)<=1e-13maximum(abs, sigma3)
    # A single independent geometric component anchors sign and the SI prefactor.
    d=zeros(3, 3, 3);
    d[1, 2, 3]=1;
    d[2, 1, 3]=-1
    q=zeros(3, 3, 3, 3);
    q[1, 2, 3, 3]=1;
    q[2, 1, 3, 3]=-1
    e=1.602176634e-19;
    hbar=1.054571817e-34;
    tau=7e-15
    @test R.berry_dipole_dc_conductivity(d, parameters; spatial_dimension = 3)[2, 3, 1] ≈
          e^3*tau/(2hbar^2)
    @test R.berry_quadrupole_dc_conductivity(q, parameters; spatial_dimension = 3)[2, 3, 3, 1] ≈
          -e^4*tau^2*1e-10/(3hbar^3)
    @test R.berry_quadrupole_surface_estimator(2.0, 3.0, 5.0, 7.0)==14.5
    @test_throws DimensionMismatch R.berry_dipole_dc_conductivity(
        zeros(2, 2, 2),
        parameters;
        spatial_dimension = 2,
    )
    @test_throws ArgumentError R.berry_dipole_dc_conductivity(d, parameters; spatial_dimension = 1)
    @test_throws ArgumentError R.berry_quadrupole_dc_conductivity(
        fill(NaN, 3, 3, 3, 3),
        parameters;
        spatial_dimension = 3,
    )
end

@testset "compact requested channels preserve dense tensor contractions" begin
    parameters=R.BerryMultipoleDCParameters(relaxation_time_fs = 7, temperature_k = 300)
    for (rank, dense_map) in
        ((3, R.berry_dipole_dc_conductivity), (4, R.berry_quadrupole_dc_conductivity))
        shape=ntuple(_->3, rank)
        moment=reshape(sin.(collect(1:prod(shape))), shape)
        components=rank==3 ? [(2, 3, 1), (3, 3, 1), (1, 1, 2)] :
                   [(2, 3, 3, 1), (3, 3, 3, 1), (1, 2, 3, 2)]
        plan=R.BerryMultipoleTensorPlan(components)
        compact=reshape([moment[key...] for key in plan.moment_components], 1, :)
        for dimension in (2, 3)
            expected=dense_map(moment, parameters; spatial_dimension = dimension)
            actual=R.berry_multipole_dc_components(
                compact,
                plan,
                parameters;
                spatial_dimension = dimension,
            )
            @test vec(actual) ≈ [expected[key...] for key in components]
        end
        @test length(plan.moment_components) < prod(shape)
        @test all(
            key -> key in plan.moment_components,
            R.berry_multipole_local_components(plan, rank-2),
        )
        @test_throws DimensionMismatch R.berry_multipole_dc_components(
            zeros(1, 0),
            plan,
            parameters;
            spatial_dimension = 3,
        )
        @test_throws ArgumentError R.BerryMultipoleTensorPlan(vcat(components, components[1:1]))
    end
    @test_throws ArgumentError R.BerryMultipoleDCParameters(
        relaxation_time_fs = true,
        temperature_k = 300,
    )
    @test_throws ArgumentError R.BerryMultipoleDCParameters(
        relaxation_time_fs = 1,
        temperature_k = true,
    )
end
end
