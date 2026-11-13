module BerryMultipolePeriodicUnit
using Test, LinearAlgebra, ForwardDiff, WannierNLQG
const F=Main.OrthogonalGeometryAnalyticUnit
const KB=8.617333262145e-5
const MU=-1.3
const TEMP=800.0
const IDENT=Matrix{ComplexF64}(I, 2, 2)
d(k)=[sin(k[1]), sin(k[2]), 1.3+0.3cos(k[1])+0.2cos(k[2])]
energy(k, sign)=0.2sin(k[1])+0.1cos(k[2])+sign*norm(d(k))
function curvature(k, sign)
    v=d(k);
    j=ForwardDiff.jacobian(d, k)
    -sign*dot(v, cross(j[:, 1], j[:, 2]))/(2norm(v)^3)
end
function native_input(; inversion = false, time_reversal = false)
    vectors=[0 1 -1 0 0; 0 0 0 1 -1; 0 0 0 0 0]
    h=zeros(ComplexF64, 2, 2, 5)
    h[:, :, 1]=1.3 * F.SZ
    h[:, :, 2]=0.15 * F.SZ+(F.SX+(inversion ? 0.0 : 0.2)*IDENT)/(2im);
    h[:, :, 3]=h[:, :, 2]'
    h[:, :, 4]=0.1 * F.SZ+0.05IDENT+F.SY/(2im);
    h[:, :, 5]=h[:, :, 4]'
    if time_reversal
        h[:, :, 1]=0.4 * F.SX+F.SZ
        h[:, :, 2]=0.1 * F.SX+0.3 * F.SY/(2im);
        h[:, :, 3]=h[:, :, 2]'
        h[:, :, 4]=0.1 * F.SZ+0.4 * F.SY/(2im);
        h[:, :, 5]=h[:, :, 4]'
    end
    RealSpaceTBInput(
        lattice = Matrix{Float64}(I, 3, 3),
        r_vectors = vectors,
        hamiltonian_r = h,
        orbital_positions = zeros(3, 2),
        source_file = @__FILE__
    )
end

function oracle(mesh, rank)
    sea=0.0;
    surface=0.0;
    twice=0.0
    for i in 0:(mesh - 1), j in 0:(mesh - 1), sign in (-1, 1)
        k=[2pi*i/mesh, 2pi*j/mesh, 0.0]
        e=energy(k, sign);
        f=1/(1+exp((e-MU)/(KB*TEMP)))
        minus_fprime=f*(1-f)/(KB*TEMP)
        omega=curvature(k, sign)
        g=ForwardDiff.gradient(x->energy(x, sign), k)[1]
        D=ForwardDiff.gradient(x->curvature(x, sign), k)[1]
        if rank==3
            sea+=f*D;
            surface+=minus_fprime*omega*g
        else
            Q=ForwardDiff.hessian(x->curvature(x, sign), k)[1, 1]
            h=ForwardDiff.hessian(x->energy(x, sign), k)[1, 1]
            fsecond=f*(1-f)*(1-2f)/(KB*TEMP)^2
            sea+=f*Q;
            surface+=minus_fprime*g*D
            twice+=omega*(fsecond*g*g-minus_fprime*h)
        end
    end
    # Unit real-space cell area: the fractional BZ average equals integral[dk].
    (sea = sea/mesh^2, surface = surface/mesh^2, twice = twice/mesh^2)
end

function public_moment(quantity, form, mesh; input = native_input())
    component=quantity=="BCDC" ? TensorComponent(2, 1, 1) : TensorComponent(2, 1, 1, 1)
    cfg=TaskConfig(
        model = input,
        sampling = BZMesh(k_mesh = (mesh, mesh), spatial_dimension = 3),
        tasks = [
            TaskSpec(
                id = "periodic",
                quantity = quantity,
                method = "Conventional",
                physics = BerryMultipoleParameters(
                    fermi_energies = [MU],
                    temperature = TEMP,
                    relaxation_time_fs = 7.0,
                    integral_form = form,
                ),
                observable = TensorComponents(component),
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
    file=only(filter(path->endswith(path, "_moments.dat"), result.outputs))
    rows=Main.BerryMultipoleRuntimeUnit.numeric_rows(file)
    key=quantity=="BCDC" ? [1.0, 2.0, 1.0] : [1.0, 2.0, 1.0, 1.0]
    row=only(filter(r->r[3:(end - 1)]==key, rows))
    @test occursin("not applicable (complete periodic grid)", read(file, String))
    last(row)
end

@testset "periodic magnetic nonzero BCQ and sea/once/twice-IBP convergence" begin
    for (quantity, rank) in (("BCDC", 3), ("BCQC", 4))
        coarse=oracle(32, rank);
        fine=oracle(64, rank)
        @test abs(fine.sea)>1e-6
        @test fine.sea ≈ fine.surface atol=3e-6 rtol=3e-4
        @test abs(fine.sea-fine.surface)<=abs(coarse.sea-coarse.surface)+1e-12
        if rank==4
            @test fine.sea ≈ fine.twice atol=3e-6 rtol=3e-4
            @test abs(fine.sea-fine.twice)<=abs(coarse.sea-coarse.twice)+1e-12
        end
        for form in (:fermi_sea, :fermi_surface)
            actual=public_moment(quantity, form, 32)
            expected=form==:fermi_sea ? coarse.sea : coarse.surface
            @test actual ≈ expected atol=2e-10 rtol=2e-8
        end
    end
end

@testset "whole-BZ inversion BCD and spinless time-reversal BCQ zeros" begin
    function raw(input, k)
        model=input.model
        sum(
            model.hamiltonian_r[:, :, r]*exp(im*dot(model.r_vectors[:, r], k)) for
            r in 1:model.num_r_vectors
        )
    end
    k=[0.31, 0.72, 0.0]
    inverse=native_input(inversion = true)
    @test raw(inverse, k) ≈ F.SZ*raw(inverse, -k)*F.SZ atol=1e-14
    reversal=native_input(time_reversal = true)
    @test raw(reversal, k) ≈ conj(raw(reversal, -k)) atol=1e-14
    for form in (:fermi_sea, :fermi_surface)
        @test abs(public_moment("BCDC", form, 32; input = inverse))<1e-12
        @test abs(public_moment("BCQC", form, 32; input = reversal))<1e-12
    end
end
end
