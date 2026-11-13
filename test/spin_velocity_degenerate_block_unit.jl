module SpinVelocityDegenerateBlockTests

using Test, LinearAlgebra, WannierNLQG
const ME = WannierNLQG.MatrixElements
const C = WannierNLQG.Core
const RESP = WannierNLQG.Responses
maxabs(x) = maximum(abs, x; init = 0.0)
# Build actual spin matrix sources and their compiled consumer workspace.
function spin_velocity_block_workspace(model, s, sh, sr, shr)
    spin=ME.SpinRealSpaceData(s; copy_data = false)
    velocity=ME.SpinVelocityRealSpaceData(spin, sh, sr, shr, nothing)
    sources=ME.MatrixElementSources(spin = spin, spin_velocity = velocity)
    request=ME.MatrixElementRequest(
        ME.BERRY_CONNECTION,
        ME.WANNIER_CURVATURE,
        ME.INTERNAL_CONNECTION_DERIVATIVES,
        ME.HAMILTONIAN_SECOND_DERIVATIVES,
        ME.VELOCITY_VERTICES,
        ME.SPIN_VELOCITY;
        spatial_dimension = 3,
        denominator_regularization = 0.001,
        degeneracy_threshold = 0.002,
    )
    matrix=ME.MatrixElementWorkspace(
        model,
        ME.compile_matrix_plan(request; source_gauge_required = false),
        sources,
    )
    ME.prepare_real_space!(matrix, model)
    shift=RESP.make_shift_spin_current_conventional_workspace(
        Int64(32),
        Int64(model.num_r_vectors),
        Int64(3),
        Int64(1);
        matrix_elements = matrix,
    )
    return (matrix = matrix, shift = shift)
end

# Closed-basis Fourier model with a controlled degenerate-block derivative.
function spin_velocity_block_fixture(rotation; degenerate = true)
    n=32;
    U=Matrix{ComplexF64}(I, n, n)
    if rotation
        for (ids, t) in [(1:2, 0.21), (3:4, 0.37)]
            ;
            U[ids, ids]=[cos(t) -sin(t); sin(t) cos(t)];
        end
    end
    E=Float64[i<=2 ? -4.0 : i<=4 ? -2.0 : 10.0+i for i in 1:n]
    if !degenerate
        ;
        E[2]=-3.0;
        E[4]=-1.0;
    end
    h0=U'*Diagonal(E)*U;
    V=zeros(ComplexF64, n, n);
    V[1:2, 1:2]=[0.2 0.7; 0.7 -0.1];
    V[3:4, 3:4]=[0.6 -0.4; -0.4 0.3];
    V=U'*V*U
    S=zeros(ComplexF64, n, n);
    S[1:2, 1:2]=[0.6 0.8; 0.8 -0.6];
    S[3:4, 3:4]=[0.8 0.6; 0.6 -0.8];
    S=U'*S*U
    R=Int[0 0 0; 0 1 -1; 0 0 0];
    H=zeros(ComplexF64, n, n, 3);
    H[:, :, 1]=h0;
    H[:, :, 2]=-0.5im .* V;
    H[:, :, 3]=0.5im .* V
    spin=zeros(ComplexF64, n, n, 3, 3);
    spin[:, :, 2, 1]=S;
    SH=similar(spin);
    fill!(SH, 0)
    for j in 1:3
        ;
        SH[:, :, 2, j]=S*H[:, :, j];
    end
    m=C.TightBindingModel(
        Matrix{Float64}(I, 3, 3),
        32,
        3,
        ones(Int, 3),
        R,
        H,
        zeros(ComplexF64, n, n, 3, 3),
    );
    w=spin_velocity_block_workspace(
        m,
        spin,
        SH,
        zeros(ComplexF64, n, n, 3, 3, 3),
        zeros(ComplexF64, n, n, 3, 3, 3),
    )
    ME.compute_spectrum!(w.matrix, m, zeros(3));
    ME.compute_remaining!(w.matrix, m);
    d=w.matrix.data;
    basis=d.spectrum.eigenvectors
    oldJ=basis*d.spin_velocity.hamiltonian_gauge[:, :, 2, 2]*basis';
    correction=zeros(ComplexF64, n, n);
    newJ=copy(oldJ)
    exact=(S*V+V*S)/2
    return (; oldJ, newJ, exact, U, delta = maxabs(correction))
end

@testset "Spin velocity retains the degenerate-block derivative" begin
    a = spin_velocity_block_fixture(false)
    b = spin_velocity_block_fixture(true)
    c = spin_velocity_block_fixture(false; degenerate = false)
    @test maxabs(a.newJ - a.exact) <= 2e-12
    @test maxabs(b.newJ - b.exact) <= 2e-12
    @test maxabs(b.newJ - b.U' * a.newJ * b.U) <= 2e-12
    @test maxabs(c.newJ - c.exact) <= 2e-12
    @test all(isfinite, a.newJ)
end

# Build a complete finite basis or a controlled nonzero (T-S*E) residual.
function smooth_spin_fixture(;
    eta = 0.001,
    gap = 0.0,
    rotation = Matrix{ComplexF64}(I, 3, 3),
    residual = false,
    raw_spin = false,
)
    energies=[0.0, gap, 1.0]
    h0=rotation'*Diagonal(energies)*rotation
    g=ComplexF64[0.2 0.3+0.1im -0.2im; 0.3-0.1im -0.4 0.2; 0.2im 0.2 0.6]
    s=ComplexF64[0.7 0.2im 0.1; -0.2im -0.3 0.4; 0.1 0.4 -0.4]
    raw_spin && (s[1, 2]+=0.03im)
    g=rotation'*g*rotation;
    s=rotation'*s*rotation
    h=zeros(ComplexF64, 3, 3, 3);
    h[:, :, 1]=h0;
    h[:, :, 2]=-0.5im*g;
    h[:, :, 3]=0.5im*g
    spin=zeros(ComplexF64, 3, 3, 3, 3);
    spin[:, :, 1, 1]=s
    sh=zeros(ComplexF64, 3, 3, 3, 3)
    for j in 1:3
        ;
        sh[:, :, 1, j]=s*h[:, :, j];
    end
    residual &&
        (sh[:, :, 1, 1] .+= ComplexF64[0.01 0.02im 0.03; 0.04 0.02 0.01im; -0.01im 0.02 0.03])
    model=C.TightBindingModel(
        Matrix{Float64}(I, 3, 3),
        3,
        3,
        ones(Int, 3),
        Int[0 1 -1; 0 0 0; 0 0 0],
        h,
        zeros(ComplexF64, 3, 3, 3, 3),
    )
    sources=ME.MatrixElementSources(
        spin = ME.SpinRealSpaceData(spin; copy_data = false),
        spin_velocity = ME.SpinVelocityRealSpaceData(
            ME.SpinRealSpaceData(spin; copy_data = false),
            sh,
            zeros(ComplexF64, 3, 3, 3, 3, 3),
            zeros(ComplexF64, 3, 3, 3, 3, 3),
            nothing,
        ),
    )
    plan=ME.compile_matrix_plan(
        ME.MatrixElementRequest(ME.SPIN_VELOCITY; denominator_regularization = eta);
        source_gauge_required = false,
    )
    workspace=ME.MatrixElementWorkspace(model, plan, sources)
    ME.prepare_real_space!(workspace, model)
    return (; model, workspace, s, g)
end

# Evaluate the real producer and return its one active Cartesian/spin channel.
function evaluate_smooth_spin!(fixture)
    ME.compute_spectrum!(fixture.workspace, fixture.model, zeros(3))
    ME.compute_remaining!(fixture.workspace, fixture.model)
    return copy(fixture.workspace.data.spin_velocity.hamiltonian_gauge[:, :, 1, 1])
end

@testset "Smooth shared spin-current prescription" begin
    for eta in (1e-6, 0.001, 0.2), gap in (0.0, 0.0005, 0.001, 0.01)
        fixture=smooth_spin_fixture(; eta, gap)
        actual=evaluate_smooth_spin!(fixture)
        u=fixture.workspace.data.spectrum.eigenvectors
        expected=u'*(fixture.s*fixture.g+fixture.g*fixture.s)/2*u
        @test actual ≈ expected atol=2e-12 rtol=2e-12
        @test all(isfinite, actual)
        @test fixture.workspace.data.spin_velocity.gauge_correction ==
              fixture.workspace.data.position.gauge_correction
    end
    unitary=ComplexF64[cos(0.3) im*sin(0.3) 0; im*sin(0.3) cos(0.3) 0; 0 0 1]
    rotated=smooth_spin_fixture(rotation = unitary)
    actual=evaluate_smooth_spin!(rotated);
    u=rotated.workspace.data.spectrum.eigenvectors
    @test u*actual*u' ≈ (rotated.s*rotated.g+rotated.g*rotated.s)/2 atol=2e-12 rtol=2e-12
    for eta in (0.0003, 0.01)
        fixture=smooth_spin_fixture(; eta, gap = 0.001, residual = true)
        actual=evaluate_smooth_spin!(fixture);
        d=fixture.workspace.data;
        u=d.spectrum.eigenvectors
        s=u'*fixture.s*u;
        g=d.hamiltonian.derivatives[:, :, 1];
        e=Diagonal(d.spectrum.energies)
        t=d.spin_velocity.spin_times_hamiltonian[:, :, 1]
        correction=[-g[l, n]*(e[l, l]-e[n, n])/((e[l, l]-e[n, n])^2+eta^2) for l in 1:3, n in 1:3]
        literal=s*g-(t-s*e)*correction
        @test actual ≈ (literal+literal')/2 atol=2e-12 rtol=2e-12
    end
    for eta in (0.0, -0.001, NaN, Inf)
        @test_throws ArgumentError ME.compile_matrix_plan(
            ME.MatrixElementRequest(ME.SPIN_VELOCITY; denominator_regularization = eta),
        )
    end
    @test ME.compile_matrix_plan(
        ME.MatrixElementRequest(ME.SPIN; denominator_regularization = 0.0),
    ) isa ME.MatrixElementPlan
    for (delta, eta) in ((0.0, 1e-200), (1e-200, 1e-200), (1e200, 1e200))
        @test isfinite(ME.regularized_energy_inverse(delta, eta))
        @test isfinite(ME.regularized_energy_weight(delta, eta))
    end
end

@testset "Same-point eta changes and worker-local borrowing" begin
    cache=ME.SharedInterpolationCache()
    ME.begin_shared_interpolation!(cache)
    fixture=smooth_spin_fixture(gap = 0.001, residual = true, raw_spin = true)
    previous=nothing
    ME.with_shared_interpolation(cache) do
        for eta in (0.001, 0.01, 0.001)
            fresh=smooth_spin_fixture(; eta, gap = 0.001, residual = true, raw_spin = true)
            expected=evaluate_smooth_spin!(fresh)
            fixture.workspace.plan=fresh.workspace.plan
            actual=evaluate_smooth_spin!(fixture)
            @test actual == expected
            if previous !== nothing
                @test maxabs(actual-previous)>1e-8
            end
            previous=actual
            # A second task slot borrows raw Fourier/spectrum data, not a vertex at another eta.
            borrowed_workspace=ME.MatrixElementWorkspace(
                fixture.model,
                fresh.workspace.plan,
                fixture.workspace.sources,
            )
            ME.prepare_real_space!(borrowed_workspace, fixture.model)
            borrowed=(; model = fixture.model, workspace = borrowed_workspace)
            @test evaluate_smooth_spin!(borrowed)==expected
        end
    end
    @test cache.fourier_hits>0
end

@testset "Task-scoped spin threshold migration" begin
    rt=WannierNLQG.Runtime
    for quantity in (:shift_spin_current, :injection_spin_current)
        task=WannierNLQG.TaskSpec(
            id = "spin",
            quantity = String(quantity),
            method = "Conventional",
            physics = WannierNLQG.OpticalParameters(
                photon_energies = [1.0],
                fermi_energy = 0.0,
                temperature = 0.0,
            ),
            numerics = WannierNLQG.Numerics(degeneracy_threshold = 0.002),
        )
        caught=try
            ;
            rt.resolved_numerical_values(task, quantity);
            nothing;
        catch err
            ;
            err;
        end
        @test caught isa ArgumentError
        message=sprint(showerror, caught)
        @test occursin("SPIN_CURRENT_DEGENERACY_THRESHOLD_REMOVED", message)
        @test !occursin("denominator_regularization", message)
        task=WannierNLQG.TaskSpec(
            id = "spin_default",
            quantity = String(quantity),
            method = "Conventional",
            physics = WannierNLQG.OpticalParameters(
                photon_energies = [1.0],
                fermi_energy = 0.0,
                temperature = 0.0,
            ),
        )
        values=rt.resolved_numerical_values(task, quantity)
        @test values.denominator_regularization==0.001
        @test values.degeneracy_threshold==0.0
    end
    other=WannierNLQG.TaskSpec(
        id = "other",
        quantity = "Shift_Current",
        method = "Projector",
        physics = WannierNLQG.OpticalParameters(
            photon_energies = [1.0],
            fermi_energy = 0.0,
            temperature = 0.0,
        ),
        numerics = WannierNLQG.Numerics(degeneracy_threshold = 0.002),
    )
    @test rt.resolved_numerical_values(other, :shift_current).degeneracy_threshold==0.002
end

end # module SpinVelocityDegenerateBlockTests
