module BerryMultipoleDiracUnit
using Test, LinearAlgebra, WannierNLQG
const F=Main.OrthogonalGeometryAnalyticUnit
const MASS=0.5
const TILT=0.15
const MU=0.9
const IDENT=Matrix{ComplexF64}(I, 2, 2)
hamiltonian(k, p)=TILT*k[1]*IDENT+k[1]*F.SX+k[2]*F.SY+MASS*F.SZ

# Independent Fermi ellipse angular integral. Radial delta integration uses the
# positive exact conduction-band root. No eigenvectors, AD, FD or WN integrand.
function angular_dipole(mu; nodes = 2048, form = :surface)
    mu>MASS || return 0.0
    value=0.0
    for j in 0:(nodes - 1)
        c=cos(2pi*j/nodes)
        a=1-TILT^2*c^2
        radius=(-mu*TILT*c+sqrt(mu^2*TILT^2*c^2+a*(mu^2-MASS^2)))/a
        energy=mu-TILT*radius*c
        if form==:surface
            omega=-MASS/(2energy^3)
            gx=TILT+radius*c/energy
            radial=TILT*c+radius/energy
            value+=radius*omega*gx/radial
        else
            # Exact radial primitive of f*partial_x Omega for this ellipse.
            value+=c*radius^3/(2MASS*energy^3)
        end
    end
    value/(2pi*nodes)
end

function gaussian_reference(width)
    # At these widths the omitted below-mass pocket weighs below exp(-25);
    # +/-8 widths truncates the Gaussian tail below 2e-29. These are oracle
    # integration bounds, not production contribution floors.
    lower=max(MASS, MU-8width);
    upper=MU+8width;
    steps=512
    value=0.0
    for j in 0:steps
        energy=lower+(upper-lower)*j/steps
        weight=exp(-((energy-MU)/width)^2)/(sqrt(pi)*width)
        value+=(j in (0, steps) ? 0.5 : 1.0)*weight*angular_dipole(energy)
    end
    value*(upper-lower)/steps
end

function actual_dipole(mesh, width)
    input=AnalyticKInput(
        hamiltonian = hamiltonian,
        num_orbitals = 2,
        lattice = Matrix{Float64}(I, 3, 3),
        basis = :point_orbitals,
        orbital_positions = zeros(3, 2),
        periodic = false,
        derivative_method = :automatic,
        source_file = @__FILE__
    )
    cfg=TaskConfig(
        model = input,
        sampling = KRegion(lower = (-2.0, -2.0), upper = (2.0, 2.0), k_mesh = (mesh, mesh)),
        tasks = [
            TaskSpec(
                id = "dirac",
                quantity = "BCDC",
                method = "Conventional",
                physics = BerryMultipoleParameters(
                    fermi_energies = [MU],
                    temperature = 0.0,
                    relaxation_time_fs = 7.0,
                ),
                numerics = Numerics(fs_kind = :gaussian, eta_fs_ev = width),
                observable = TensorComponents(TensorComponent(2, 1, 1)),
            ),
        ],
        execution = ExecutionOptions(fourier_backend = "direct"),
        output = OutputOptions(
            output_root = mktempdir(),
            progress_enabled = false,
            response_output_digits = 16,
        ),
    )
    result=Base.invokelatest(WannierNLQG.run, cfg)
    path=only(filter(x->endswith(x, "_moments.dat"), result.outputs))
    rows=Main.BerryMultipoleRuntimeUnit.numeric_rows(path)
    @test occursin("\u672a\u5305\u542b\u8fb9\u754c\u4fee\u6b63", read(path, String))
    last(only(filter(r->r[3:(end - 1)]==[1.0, 2.0, 1.0], rows)))
end

@testset "tilted gapped Dirac BCD: independent ellipse and finite-width convergence" begin
    exact=angular_dipole(MU)
    @test abs(exact)>1e-4
    @test exact ≈ angular_dipole(MU; form = :sea) atol=1e-13 rtol=1e-12
    errors=Float64[]
    for (mesh, width) in ((96, 0.08), (192, 0.04))
        reference=gaussian_reference(width)
        actual=actual_dipole(mesh, width)
        @test actual ≈ reference atol=2e-7 rtol=2e-4
        push!(errors, abs(actual-exact))
    end
    @test errors[2]<0.4errors[1]
end
end
