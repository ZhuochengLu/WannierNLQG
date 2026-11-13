module IntrinsicHallRealOccupationUnit
using Test, LinearAlgebra, Random, WannierNLQG
const M=WannierNLQG.MatrixElements
const R=WannierNLQG.Responses
function fixture(energy)
    n=length(energy);
    v=zeros(ComplexF64, n, n, 3);
    f=zeros(ComplexF64, n, n, 3, 3)
    for l in 1:n, m in (l + 1):n
        v[l, m, 1]=v[m, l, 1]=0.3+0.1l
        v[l, m, 2]=im*(0.2+0.05m);
        v[m, l, 2]=conj(v[l, m, 2])
    end
    for l in 1:n
        f[l, l, 1, 2]=0.07l;
        f[l, l, 2, 1]=-0.07l
    end
    return M.intrinsic_hall_geometry(
        energy,
        Matrix{ComplexF64}(I, n, n),
        v,
        f;
        orthonormal_basis = true,
    )
end
# Independent high-precision velocity-product sum, not a prepared-position oracle.
function oracle(g, mu)
    return setprecision(BigFloat, 256) do
        n=length(g.energies);
        out=zeros(BigFloat, 3, 3)
        for a in 1:3, b in 1:3, l in 1:n
            g.energies[l]<=mu || continue
            out[a, b]+=real(Complex{BigFloat}(g.ambient_curvature[l, l, a, b]))
            for m in 1:n
                g.energies[m]>mu || continue
                d=BigFloat(g.energies[l])-BigFloat(g.energies[m])
                # The reverse position denominator has opposite sign; (-i)^2
                # cancels that sign, leaving the ordered V products / d².
                va=Complex{BigFloat}(g.velocity[l, m, a]);
                vb=Complex{BigFloat}(g.velocity[l, m, b])
                wa=Complex{BigFloat}(g.velocity[m, l, a]);
                wb=Complex{BigFloat}(g.velocity[m, l, b])
                out[a, b]-=imag((va*wb-vb*wa)/(d*d))
            end
        end
        Float64.(out)
    end
end
@testset "AHC real levels, no occupation group and multiple mu" begin
    g=fixture([0.0, 0.04, 0.08]);
    mus=[0.03, 0.04, -1.0, 0.08, 0.03]
    matrix=R.intrinsic_hall_fermi_sea(g, mus)
    projector=R.intrinsic_hall_fermi_sea(g, mus; method = :Projector)
    @test matrix≈projector atol=2e-12 rtol=2e-12
    for (i, mu) in enumerate(mus)
        @test matrix[i, :, :]≈oracle(g, mu) atol=2e-12 rtol=2e-12
    end
    @test matrix[1, :, :]!=matrix[2, :, :]
    @test matrix[3, :, :]==zeros(3, 3)
    @test matrix[4, 1, 2]≈sum(real(g.ambient_curvature[l, l, 1, 2]) for l in 1:3)
    @test matrix[1, :, :]==matrix[5, :, :]
    @test !isdefined(R, :intrinsic_hall_occupation_blocks)
    @test_throws ArgumentError R.intrinsic_hall_fermi_sea(g, 0.0; temperature = 1.0)
    @test_throws ArgumentError R.intrinsic_hall_fermi_sea(g, NaN)
end
@testset "AHC nonzero ULP and subnormal ratios, explicit nonfinite" begin
    for delta in [eps(1.0), 8eps(1.0)]
        g=fixture([1.0, 1.0+delta, 2.0]);
        v=copy(g.velocity)
        v[1, 2, 1]=v[2, 1, 1]=delta
        v[1, 2, 2]=im*delta;
        v[2, 1, 2]=-im*delta
        g=M.intrinsic_hall_geometry(
            g.energies,
            g.eigenvectors,
            v,
            g.ambient_curvature;
            orthonormal_basis = true,
        )
        @test R.intrinsic_hall_fermi_sea(g, 1.0)[1, :, :]≈oracle(g, 1.0) atol=2e-12 rtol=2e-12
        @test R.intrinsic_hall_fermi_sea(
            g,
            1.0;
            method = :Projector,
        )≈R.intrinsic_hall_fermi_sea(g, 1.0) atol=2e-12 rtol=2e-12
    end
    d=nextfloat(0.0);
    v=zeros(ComplexF64, 2, 2, 3)
    v[1, 2, 1]=v[2, 1, 1]=d;
    v[1, 2, 2]=im*d;
    v[2, 1, 2]=-im*d
    g=M.intrinsic_hall_geometry(
        [0.0, d],
        Matrix{ComplexF64}(I, 2, 2),
        v,
        zeros(ComplexF64, 2, 2, 3, 3);
        orthonormal_basis = true,
    )
    @test isinf(1/d)
    @test R.intrinsic_hall_fermi_sea(g, 0.0)[1, 1, 2]==2.0
    @test R.intrinsic_hall_fermi_sea(g, 0.0; method = :Projector)[1, 1, 2]==2.0
    v[1, 2, 1]=1.0;
    bad=M.intrinsic_hall_geometry(
        [0.0, d],
        g.eigenvectors,
        v,
        g.ambient_curvature;
        orthonormal_basis = true,
    )
    @test_throws ErrorException R.intrinsic_hall_fermi_sea(bad, 0.0)
    @test R.intrinsic_hall_fermi_sea(bad, d)==zeros(1, 3, 3)
    wide=fixture([-floatmax(Float64), floatmax(Float64)])
    @test_throws ErrorException R.intrinsic_hall_fermi_sea(wide, 0.0)
    large=fixture([0.0, 1.0]);
    v=copy(large.velocity);
    v[1, 2, 1]=v[2, 1, 1]=floatmax(Float64);
    v[1, 2, 2]=im*floatmax(Float64);
    v[2, 1, 2]=-im*floatmax(Float64)
    overflow=M.intrinsic_hall_geometry(
        large.energies,
        large.eigenvectors,
        v,
        large.ambient_curvature;
        orthonormal_basis = true,
    )
    for method in [:Matrix, :Projector]
        @test_throws ErrorException R.intrinsic_hall_fermi_sea(overflow, 0.0; method)
    end
end
@testset "AHC equal levels, ambient and subspace rotation" begin
    g=fixture([0.0, 0.0, 1.0]);
    base=R.intrinsic_hall_fermi_sea(g, 0.0)
    @test base[1, :, :]≈oracle(g, 0.0) atol=2e-12
    q=Matrix{ComplexF64}(I, 3, 3);
    q[1:2, 1:2]=[cos(0.31) sin(0.31)*im; sin(0.31)*im cos(0.31)]
    v=similar(g.velocity);
    f=similar(g.ambient_curvature)
    for a in 1:3
        v[:, :, a]=q'*g.velocity[:, :, a]*q
        for b in 1:3
            ;
            f[:, :, a, b]=q'*g.ambient_curvature[:, :, a, b]*q;
        end
    end
    rotated=M.intrinsic_hall_geometry(g.energies, q, v, f; orthonormal_basis = true)
    for method in [:Matrix, :Projector]
        @test R.intrinsic_hall_fermi_sea(rotated, 0.0; method)≈base atol=2e-12 rtol=2e-12
    end
    # Singular within-occupied velocity never needs an internal position ratio.
    v[1, 2, :].=1e200;
    v[2, 1, :].=1e200
    occupied=M.intrinsic_hall_geometry(
        g.energies,
        g.eigenvectors,
        v,
        g.ambient_curvature;
        orthonormal_basis = true,
    )
    @test all(isfinite, R.intrinsic_hall_fermi_sea(occupied, 0.0))
    tasks=[
        Threads.@spawn R.intrinsic_hall_fermi_sea(g, [-1.0, 0.0, 1.0]; method) for
        method in [:Matrix, :Projector, :Matrix, :Projector]
    ]
    values=fetch.(tasks)
    @test values[1]==values[3]
    @test values[2]==values[4]
    @test values[1]≈values[2] atol=2e-12
end

@testset "AHC metric complete velocity, ambient and moving frame" begin
    energy=[0.0, 0.04, 0.08];
    n=3;
    identity=Matrix{ComplexF64}(I, n, n)
    a=zeros(ComplexF64, n, n, 3)
    a[:, :, 1]=[0.1 0.03 0.01im; 0.03 -0.04 0.02; -0.01im 0.02 0.05]
    a[:, :, 2]=[0.02 0.02im 0.01; -0.02im 0.03 0.04; 0.01 0.04 -0.01]
    h=fixture(energy).velocity
    f=zeros(ComplexF64, n, n, 3, 3)
    for axis in 1:3, m in 1:n, l in 1:n
        h[l, m, axis]-=im*(energy[l]-energy[m])*a[l, m, axis]
    end
    for x in 1:3, y in 1:3
        ;
        f[:, :, x, y]=-im*(a[:, :, x]*a[:, :, y]-a[:, :, y]*a[:, :, x]);
    end
    baseline=M.orthogonal_intrinsic_hall_geometry(energy, identity, h, a, f)
    @test norm(baseline.ambient_curvature)>0
    for moving in (false, true), metric in (false, true)
        t=metric ? ComplexF64[1.2 0.1 0; 0 0.8 0.04; 0.02 0 1.1] : identity
        jets=zeros(ComplexF64, n, n, 3)
        moving && (jets[:, :, 1]=[0.02 0.01im 0; 0.01 0 0.02; 0 -0.01 0.01])
        moving && (jets[:, :, 2]=[0 0.01 0.02im; 0.02 -0.01 0; 0.01 0 0.03])
        overlap=t'*t;
        sd=zeros(ComplexF64, n, n, 3);
        sdd=zeros(ComplexF64, n, n, 3, 3)
        hd=similar(sd);
        r=similar(sd);
        rd=similar(sdd);
        ham=Diagonal(energy)
        for x in 1:3
            tx=jets[:, :, x];
            sd[:, :, x]=tx'*t+t'*tx
            hd[:, :, x]=tx'*ham*t+t'*h[:, :, x]*t+t'*ham*tx
            r[:, :, x]=t'*a[:, :, x]*t-im*tx'*t
            for y in 1:3
                ty=jets[:, :, y];
                sdd[:, :, x, y]=tx'*ty+ty'*tx
                rd[:, :, x, y]=ty'*a[:, :, x]*t+t'*a[:, :, x]*ty-im*tx'*ty
            end
        end
        matrices=(
            overlap = overlap,
            overlap_derivatives = sd,
            overlap_second_derivatives = sdd,
            hamiltonian_derivatives = hd,
            position = r,
            position_derivatives = rd,
        )
        vectors=inv(t);
        @test vectors'*overlap*vectors≈identity atol=2e-13
        geometry=M.nonorthogonal_intrinsic_hall_geometry(
            matrices,
            (energies = energy, eigenvectors = vectors),
        )
        @test geometry.velocity≈baseline.velocity atol=2e-13 rtol=2e-13
        @test geometry.ambient_curvature≈baseline.ambient_curvature atol=2e-13 rtol=2e-13
        @test R.intrinsic_hall_fermi_sea(
            geometry,
            [0.0, 0.03, 0.04, 0.08],
        )≈R.intrinsic_hall_fermi_sea(baseline, [0.0, 0.03, 0.04, 0.08]) atol=2e-10 rtol=2e-12
        @test_throws ArgumentError R.intrinsic_hall_fermi_sea(geometry, 0.0; method = :Projector)
    end
end

include(joinpath(@__DIR__, "SpectralResponseTestSupport.jl"))
@testset "AHC ordinary runtime, independent numerics and metadata" begin
    root=mktempdir();
    path=joinpath(root, "model.dat")
    WannierNLQG.IO.write_wannier_tb(path, spectral_test_model())
    outputs=Dict()
    for backend in ("Direct", "Mixed"), method in ("Conventional", "Projector")
        config=TaskConfig(
            model = ModelInput(model_file = path),
            sampling = BZMesh(k_mesh = (2, 2, 2)),
            execution = ExecutionOptions(
                fourier_backend = backend,
                NKFFT = backend=="Mixed" ? (2, 2, 2) : nothing,
            ),
            output = OutputOptions(
                output_root = joinpath(root, backend*method),
                progress_enabled = false,
            ),
            tasks = [
                TaskSpec(
                    id = "hall",
                    quantity = "intrinsic_ahc",
                    method = method,
                    physics = IntrinsicHallParameters(fermi_energies = [-10.0, 0.0, 10.0]),
                    observable = FullTensor(),
                ),
            ],
        )
        @test !hasproperty(
            WannierNLQG.Runtime._spectral_task_numerics(only(config.tasks), :intrinsic_ahc),
            :degeneracy_threshold,
        )
        @test_throws ArgumentError WannierNLQG.Runtime.resolved_numerical_values(
            TaskSpec(
                id = "bad",
                quantity = "intrinsic_ahc",
                method = method,
                physics = IntrinsicHallParameters(fermi_energies = [0.0]),
                numerics = Numerics(degeneracy_threshold = 0.0),
            ),
            :intrinsic_ahc,
        )
        result=WannierNLQG.run(config)
        @test result.qualification.execution_eligible
        tables=Dict(
            basename(p)=>spectral_test_table(p) for p in result.outputs if endswith(p, ".dat")
        )
        @test !isempty(tables)
        @test all(all(isfinite, v) for v in values(tables))
        outputs[(backend, method)]=tables
        metadata=read(
            only(filter(p->endswith(p, "spectral_response_metadata.txt"), result.outputs)),
            String,
        )
        @test occursin("T0-real-energy-less-than-or-equal-mu", metadata)
        @test !occursin("occupation_group_threshold_ev", metadata)
    end
    baseline=outputs[("Direct", "Conventional")]
    for tables in values(outputs), name in keys(baseline)
        @test tables[name]≈baseline[name] atol=1e-28 rtol=2e-11
    end
    base=spectral_test_model()
    for transform in (Matrix{ComplexF64}(I, 2, 2), ComplexF64[1.2 0.13; 0 0.8]),
        backend in ("Direct", "Mixed")

        h=similar(base.hamiltonian_r);
        position=similar(base.position_r);
        overlap=zeros(ComplexF64, size(h))
        for index in 1:base.num_r_vectors
            h[:, :, index]=transform'*base.hamiltonian_r[:, :, index]*transform
            for axis in 1:3
                ;
                position[:, :, axis, index]=transform'*base.position_r[:, :, axis, index]*transform;
            end
            all(iszero, base.r_vectors[:, index]) && (overlap[:, :, index]=transform'*transform)
        end
        model=WannierNLQG.Core.NonorthogonalLocalizedModel(
            lattice = base.lattice,
            r_vectors = base.r_vectors,
            hamiltonian_r = h,
            overlap_r = overlap,
            position_r = position,
        )
        config=TaskConfig(
            model = WannierNLQG.Core.NonorthogonalLocalizedInput(model),
            sampling = BZMesh(k_mesh = (2, 2, 2)),
            execution = ExecutionOptions(
                fourier_backend = backend,
                NKFFT = backend=="Mixed" ? (2, 2, 2) : nothing,
            ),
            output = OutputOptions(output_root = mktempdir(), progress_enabled = false),
            tasks = [
                TaskSpec(
                    id = "hall",
                    quantity = "intrinsic_ahc",
                    method = "Conventional",
                    physics = IntrinsicHallParameters(fermi_energies = [-10.0, 0.0, 10.0]),
                    observable = FullTensor(),
                ),
            ],
        )
        result=WannierNLQG.run(config)
        tables=Dict(
            basename(p)=>spectral_test_table(p) for p in result.outputs if endswith(p, ".dat")
        )
        @test keys(tables)==keys(baseline)
        for name in keys(baseline)
            ;
            @test tables[name]≈baseline[name] atol=1e-28 rtol=2e-11;
        end
    end
end

@testset "AHC text input and mixed-task parameter ownership" begin
    root=mktempdir();
    path=joinpath(root, "model.dat")
    WannierNLQG.IO.write_wannier_tb(path, spectral_test_model())
    document=Dict{String, Any}(
        "model"=>Dict{String, Any}("source"=>"wannier", "model_file"=>path),
        "response"=>Dict{String, Any}(
            "energy_zero"=>"finite-model Hamiltonian reference",
            "temperature_k"=>0.0,
            "fermi_energies_ev"=>[-1.0, 0.0, 1.0],
            "sampling"=>Dict("kind"=>"bz_mesh", "k_mesh"=>[2, 2, 2], "spatial_dimension"=>3),
            "execution"=>Dict("fourier_backend"=>"direct"),
            "tasks"=>Dict{String, Any}(
                "hall"=>Dict{String, Any}("kind"=>"intrinsic_ahc", "method"=>"Conventional"),
            ),
        ),
        "output"=>Dict("output_root"=>root, "progress_enabled"=>false),
    )
    resolution=WannierNLQG.Runtime.resolve_task_input(deepcopy(document); base_dir = root)
    @test isempty(resolution.pending)
    @test resolution.config!==nothing
    @test !occursin("degeneracy_threshold", string(resolution.effective))
    for shared in (false, true)
        bad=deepcopy(document)
        target=shared ? bad["response"] : bad["response"]["tasks"]["hall"]
        target["numerics"]=Dict("degeneracy_threshold"=>0.0)
        @test_throws ArgumentError WannierNLQG.Runtime.resolve_task_input(bad; base_dir = root)
    end
    hall=only(resolution.config.tasks)
    shg=TaskSpec(
        id = "second",
        quantity = "second_harmonic_generation",
        method = "Conventional",
        physics = SHGParameters(fermi_energy = 0.0, temperature = 0.0, photon_energies = [0.5]),
        numerics = Numerics(degeneracy_threshold = 0.02),
    )
    @test !hasproperty(
        WannierNLQG.Runtime.resolved_numerical_values(hall, :intrinsic_ahc),
        :degeneracy_threshold,
    )
    @test WannierNLQG.Runtime.resolved_numerical_values(shg, :second_harmonic_generation).degeneracy_threshold==0.02
end
end
