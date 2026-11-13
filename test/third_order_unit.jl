isdefined(@__MODULE__, :ThirdHarmonicLiteralReference) ||
    include(joinpath(@__DIR__, "support", "ThirdHarmonicLiteralReference.jl"))

using Test, LinearAlgebra, WannierNLQG

@testset "Third-order physical and numerical contracts" begin
    response=WannierNLQG.Responses
    matrices=WannierNLQG.MatrixElements
    runtime=WannierNLQG.Runtime
    root=dirname(@__DIR__)
    model_path=joinpath(root, "examples/fixtures/synthetic_runtime/synthetic_tb.dat")
    make(
        q,
        physics,
        numerics = Numerics();
        observable = FullTensor(),
        sampling = BZMesh(k_mesh = (2, 2, 2), spatial_dimension = 3),
    ) = TaskConfig(
        model = ModelInput(model_file = model_path),
        sampling = sampling,
        tasks = [
            TaskSpec(
                id = "third_order",
                quantity = q,
                physics = physics,
                numerics = numerics,
                observable = observable,
            ),
        ],
        execution = ExecutionOptions(fourier_backend = "direct"),
    )
    lower(cfg)=runtime.compile_task_config(cfg, only(cfg.tasks))
    jp=JerkParameters(photon_energies = [0.73], fermi_energy = 0.0, temperature = 0.0)
    tp=THGParameters(photon_energies = [0.73], fermi_energy = 0.0, temperature = 0.0)
    for q in ("JC", "jerk_current")
        cfg=lower(make(q, jp))
        @test cfg.broadening==0.04
        @test cfg.denominator_regularization==0.001
        @test cfg.third_order.projection==:ordered
    end
    for q in ("THG", "third_harmonic_generation")
        cfg=lower(make(q, tp))
        @test cfg.broadening==0.025
        @test cfg.third_order.frequency_policy.low_width==0.025
        @test cfg.denominator_regularization==0.001
        @test cfg.third_order.formulation==:regrouped
    end
    for (q, physics) in (("JC", jp), ("THG", tp))
        @test lower(
            make(q, physics, Numerics(broadening_type = SubString("Gaussian", 1, 8))),
        ).broadening_type=="Gaussian"
        @test lower(make(q, physics, Numerics(broadening_type = SubString("Gaussian", 1, 8)))).broadening_type isa
              String
    end
    @test_throws ArgumentError TensorComponents()
    # The shared selector also serves rank-three BCD tasks. Third-order
    # applicability is rejected at the concrete task boundary, not here.
    rank_three=TensorComponents(TensorComponent(1, 1, 1))
    @test rank_three.components==((1, 1, 1),)
    for (q, physics) in (("JC", jp), ("THG", tp))
        @test_throws ArgumentError lower(make(q, physics; observable = rank_three))
    end
    @test_throws ArgumentError TensorComponents(
        TensorComponent(1, 1, 1, 1),
        TensorComponent(1, 1, 1, 1),
    )
    for bad in (
        Numerics(denominator_regularization = 0),
        Numerics(low_frequency_broadening = 0.01),
        Numerics(finite_difference_step = 1e-4),
        Numerics(broadening = nothing),
    )
        @test_throws ArgumentError lower(make("JC", jp, bad))
    end
    for bad in (
        Numerics(prescription = :causal),
        Numerics(denominator_regularization = 0.01),
        Numerics(eta_correction = 1),
        Numerics(intermediate_regularization = 0),
    )
        @test_throws ArgumentError lower(make("THG", tp, bad))
    end
    causal=Numerics(
        prescription = :causal,
        broadening = 0.06,
        low_frequency_broadening = 0.06,
        intermediate_regularization = 0.0,
        eta_correction = false,
        occupation_derivative_mode = :fermi_dirac,
    )
    @test_throws ArgumentError lower(make("THG", tp, causal))
    @test_throws ArgumentError lower(make("THG", tp, Numerics(prescription = :shg_compatible)))
    @test_throws ArgumentError lower(
        make("THG", tp, Numerics(; causal.values..., broadening_type = "Gaussian")),
    )
    @test TensorComponents([(1, 2, 3, 1)]).components==TensorComponents(TensorComponent(1, 2, 3, 1)).components
    @test lower(
        make("JC", JerkParameters(photon_energies = [0.0], fermi_energy = 0.0, temperature = 0.0)),
    ).photon_energies==[0.0]
    @test_throws ArgumentError lower(
        make(
            "JC",
            JerkParameters(photon_energies = [-1e-9], fermi_energy = 0.0, temperature = 0.0),
        ),
    )
    @test_throws ArgumentError lower(
        make(
            "THG",
            THGParameters(
                photon_energies = [0.1],
                fermi_energy = 0.0,
                temperature = 0.0,
                response_measure = :effective_bulk,
            ),
        ),
    )
    @test length(response.JERK_CURRENT_COMPONENTS)==81
    @test length(response.THIRD_HARMONIC_COMPONENTS)==30
    model=WannierNLQG.IO.read_wannier_tb(model_path)
    plan=matrices.compile_matrix_plan(
        matrices.MatrixElementRequest(
            matrices.BERRY_CONNECTION,
            matrices.INTERNAL_CONNECTION_DERIVATIVES,
            matrices.HAMILTONIAN_SECOND_DERIVATIVES,
        ),
    )
    workspace=matrices.MatrixElementWorkspace(model, plan)
    matrices.prepare_real_space!(workspace, model)
    point=[0.17, 0.23, 0.31]
    data=matrices.compute_kpoint!(workspace, model, point)
    geometry=matrices.ThirdOrderGeometry(model.num_orbitals)
    for eta in (0.001, 0.01, 0.04)
        matrices.prepare_third_order_geometry!(geometry, data; jerk = true, regularization = eta)
        for n in 1:model.num_orbitals, a in 1:3, d in 1:3
            ref=real(data.hamiltonian_second_derivatives[n, n, a, d])
            for l in 1:model.num_orbitals
                l==n && continue
                gap=data.spectrum.energies[n]-data.spectrum.energies[l]
                # Evaluate the regularized inverse gap before the contraction;
                # retain the exact comparison without multiplication/division reassociation.
                ref+=2real(
                    data.hamiltonian_derivatives[n, l, a]*data.hamiltonian_derivatives[l, n, d],
                )*(gap/(gap^2+eta^2))
            end
            @test geometry.hessians[n, a, d]==ref
        end
    end
    # The synthetic file is a runtime fixture; finite-difference physics uses Hermitian H(k).
    periodic_h(k, p)=[1.2+cos(k[1]) sin(k[1])-im*sin(k[2]); sin(k[1])+im*sin(k[2]) -1.2-cos(k[1])]
    physical_model=WannierNLQG.Core.AnalyticKModel(
        AnalyticKInput(
            hamiltonian = periodic_h,
            num_orbitals = 2,
            lattice = Matrix{Float64}(I, 3, 3),
            orbital_positions = zeros(3, 2),
        ),
    )
    physical_workspace=matrices.MatrixElementWorkspace(physical_model, plan)
    matrices.prepare_real_space!(physical_workspace, physical_model)
    physical_data=matrices.compute_kpoint!(physical_workspace, physical_model, point)
    physical_geometry=matrices.ThirdOrderGeometry(2)
    matrices.prepare_third_order_geometry!(
        physical_geometry,
        physical_data;
        jerk = true,
        eta_correction = false,
        regularization = 1.0e-9,
    )
    # Independent band-curvature FD limit with positive matrix regularization.
    naked=copy(physical_geometry.hessians)
    energies=copy(physical_data.spectrum.energies)
    h=1e-4
    for a in 1:3
        delta=zeros(3);
        delta[a]=h/(2pi)
        plus=copy(
            matrices.compute_kpoint!(physical_workspace, physical_model, point+delta).spectrum.energies,
        )
        minus=copy(
            matrices.compute_kpoint!(physical_workspace, physical_model, point-delta).spectrum.energies,
        )
        @test isapprox((plus+minus-2energies)/h^2, naked[:, a, a]; atol = 2e-6, rtol = 2e-5)
    end
    data=matrices.compute_kpoint!(workspace, model, point)
    # The new allocation-free vertex follows the unchanged SHG helper.
    matrices.prepare_third_order_geometry!(geometry, data; regularization = 0.04)
    old=matrices.optical_position_vertices(data, 0.04, true)
    @test isapprox(geometry.dipoles, old[1]; atol = 1e-13, rtol = 1e-13)
    @test isapprox(geometry.dipole_derivatives, old[3]; atol = 1e-13, rtol = 1e-13)
    for gaussian in (true, false)
        policy=response.HarmonicFrequencyPolicy(gaussian, 0.025, 0.025, 0.04)
        value, derivative=response.harmonic_resolvent(policy, 0.37, 0.75, 2)
        finite=(
            first(
                response.harmonic_resolvent(policy, 0.37, 0.7500001, 2),
            )-first(response.harmonic_resolvent(policy, 0.37, 0.7499999, 2))
        )/2e-7
        @test isapprox(derivative, finite; rtol = 1e-7)
        gaussian && @test !isapprox(derivative, value^2; rtol = 1e-3)
    end
    options=lower(make("JC", jp)).third_order
    factors=runtime.third_order_si_factors(model, true)
    @test only(factors)==2pi*1.602176634e-19^4/1.054571817e-34^3*1e-10/abs(det(model.lattice))
end

# HISTORICAL_ONLY: the removed causal three-band benchmark and its original
# reference values/tolerances are retained verbatim in
# fixtures/third_order/retired_causal_three_band_benchmark.jl.txt.
# It does not qualify the current distribution-broadening prescription.

@testset "Frozen independent ordered jerk fixture" begin
    matrices=WannierNLQG.MatrixElements
    response=WannierNLQG.Responses
    fixture=joinpath(@__DIR__, "fixtures", "third_order")
    readcomplex(
        path,
    )=[
        complex(parse(Float64, split(line)[1]), parse(Float64, split(line)[2])) for
        line in eachline(path)
    ]
    input=readcomplex(joinpath(fixture, "jerk_input.dat"))
    b=reshape(input[1:48], 4, 4, 3)
    a=reshape(input[49:96], 4, 4, 3)
    c=reshape(input[97:240], 4, 4, 3, 3)
    data=(
        spectrum = (energies = [-1.5, -0.4, 0.7, 1.8],),
        hamiltonian_derivatives = b,
        internal_connection = a,
        hamiltonian_second_derivatives = c,
        internal_connection_derivatives = zeros(ComplexF64, 4, 4, 3, 3),
    )
    geometry=matrices.ThirdOrderGeometry(4)
    occupations=zeros(4)
    output=zeros(ComplexF64, 3, 81)
    options=(
        fermi_energy = 0.0,
        temperature = 0.0,
        broadening = 0.04,
        gaussian = true,
        regularization = 0.001,
        transition_window_factor = 5.0,
        band_window_size = -1,
    )
    response.jerk_current_response!(
        output,
        geometry,
        occupations,
        data,
        [1.1, 2.2, 3.3],
        response.JERK_CURRENT_COMPONENTS;
        options...,
    )
    reference=reshape(readcomplex(joinpath(fixture, "jerk_reference.dat")), 3, 81)
    @test isapprox(output, reference; atol = 1e-12, rtol = 4e-15)
    @test maximum(abs, imag.(output))>0.01
    symmetric=similar(output);
    antisymmetric=similar(output)
    response.jerk_current_response!(
        symmetric,
        geometry,
        occupations,
        data,
        [1.1, 2.2, 3.3],
        response.JERK_CURRENT_COMPONENTS;
        options...,
        projection = :symmetric,
    )
    response.jerk_current_response!(
        antisymmetric,
        geometry,
        occupations,
        data,
        [1.1, 2.2, 3.3],
        response.JERK_CURRENT_COMPONENTS;
        options...,
        projection = :antisymmetric,
    )
    @test isapprox(symmetric+antisymmetric, output; atol = 1e-12, rtol = 4e-15)
    phases=cis.([0.3, -0.7, 0.9, 1.2]);
    rotation=conj.(phases)*transpose(phases)
    changed=merge(
        data,
        (
            hamiltonian_derivatives = b .* rotation,
            internal_connection = a .* rotation,
            hamiltonian_second_derivatives = c .* rotation,
        ),
    )
    phased=similar(output)
    response.jerk_current_response!(
        phased,
        geometry,
        occupations,
        changed,
        [1.1, 2.2, 3.3],
        response.JERK_CURRENT_COMPONENTS;
        options...,
    )
    @test isapprox(phased, output; atol = 1e-12, rtol = 4e-15)
    # THG's phase test uses every component and both independent formulations.
    thg=zeros(ComplexF64, 1, 81, 4, 2, 2);
    phase_thg=similar(thg)
    workspace=response.ThirdHarmonicWorkspace(4)
    policy=response.HarmonicFrequencyPolicy(true, 0.025, 0.025, 0.04)
    thg_options=(
        fermi_energy = 0.0,
        temperature = 300.0,
        policy,
        eta_correction = true,
        exact_occupations = false,
        formulation = :both,
    )
    response.third_harmonic_response!(
        thg,
        workspace,
        data,
        [0.37],
        response.JERK_CURRENT_COMPONENTS;
        thg_options...,
    )
    response.third_harmonic_response!(
        phase_thg,
        workspace,
        changed,
        [0.37],
        response.JERK_CURRENT_COMPONENTS;
        thg_options...,
    )
    @test isapprox(thg, phase_thg; atol = 1e-12, rtol = 3e-13)
    degenerate=merge(data, (spectrum = (energies = [-1.5, -1.5, 0.7, 1.8],),))
    matrices.prepare_third_order_geometry!(geometry, degenerate)
    @test all(isfinite, geometry.dipoles) && all(isfinite, geometry.dipole_derivatives)
    @test geometry.bare[1, 2, 1]==0
    @test geometry.dipoles[1, 2, 1]==degenerate.internal_connection[1, 2, 1]
    matrices.prepare_third_order_geometry!(geometry, degenerate; jerk = true)
    @test geometry.diagnostics[1]>0
    @test all(isfinite, geometry.hessians)
end

@testset "THG quadratic-pole BCQ positive-width limit" begin
    M=WannierNLQG.MatrixElements;
    R=WannierNLQG.Responses
    sx=ComplexF64[0 1; 1 0];
    sy=ComplexF64[0 -im; im 0];
    sz=ComplexF64[1 0; 0 -1]
    h(k, p)=sin(k[1])*sx+sin(k[2])*sy+(1.5+cos(k[1])+cos(k[2]))*sz
    function d1(k, p)
        out=zeros(ComplexF64, 2, 2, 3);
        out[:, :, 1]=cos(k[1])*sx-sin(k[1])*sz;
        out[:, :, 2]=cos(k[2])*sy-sin(k[2])*sz;
        out
    end
    function d2(k, p)
        out=zeros(ComplexF64, 2, 2, 3, 3);
        out[:, :, 1, 1]=-sin(k[1])*sx-cos(k[1])*sz;
        out[:, :, 2, 2]=-sin(k[2])*sy-cos(k[2])*sz;
        out
    end
    model=WannierNLQG.Core.AnalyticKModel(
        AnalyticKInput(
            hamiltonian = h,
            derivatives = (d1, d2, nothing),
            num_orbitals = 2,
            lattice = Matrix{Float64}(I, 3, 3),
            orbital_positions = zeros(3, 2),
        ),
    )
    plan=M.compile_matrix_plan(
        M.MatrixElementRequest(
            M.BERRY_CONNECTION,
            M.INTERNAL_CONNECTION_DERIVATIVES,
            M.HAMILTONIAN_SECOND_DERIVATIVES,
        ),
    )
    w=M.MatrixElementWorkspace(model, plan);
    M.prepare_real_space!(w, model);
    ws=R.ThirdHarmonicWorkspace(2);
    policy=R.HarmonicFrequencyPolicy(false, 0.06, 0.06, 1.0e-8)
    function run_bcq(N)
        s=0im;
        coefficient=0im
        for x in 0:(N - 1), y in 0:(N - 1)
            data=M.compute_kpoint!(w, model, [x/N, y/N, 0.0]);
            e=data.spectrum.energies
            M.prepare_third_order_band_geometry!(ws.geometry, data; regularization = 1.0e-8)
            R.harmonic_occupations!(
                ws.occupations,
                ws.geometry,
                e,
                1.0,
                0.15/8.617333262145e-5,
                true,
            )
            M.prepare_third_order_combined_geometry!(
                ws.geometry,
                data;
                regularization = 1.0e-8,
                eta_correction = false,
            )
            for n in 1:2, m in 1:2
                m==n && continue
                s+=ws.geometry.velocities[
                    n,
                    m,
                    2,
                ]*ws.geometry.velocities[
                    m,
                    n,
                    1,
                ]/(e[m]-e[n])^2*(ws.occupations.second[n, 1, 1]-ws.occupations.second[m, 1, 1])/N^2
            end
            R.third_harmonic_vertices!(ws, policy, 0.37, (2, 1, 1, 1), e)
            R.third_harmonic_regrouped!(ws, policy, 0.37, (2, 1, 1, 1), e)
            coefficient+=ws.coefficients[3, 3, 2]/N^2
        end
        println(N, " S=", s, " coefficient=", coefficient, " diff=", abs(coefficient-0.5im*s))
        @test isapprox(s, -0.06117291445002825im; atol = 2e-7, rtol = 2e-7)
        @test isapprox(coefficient, 0.5im*s; atol = 1e-13, rtol = 1e-12)
    end
    run_bcq(64)
end

@testset "Third-order reference-volume factors and retired measure inputs" begin
    runtime=WannierNLQG.Runtime
    root=dirname(@__DIR__)
    lattice=[3.0 0.2 1.0; 0.5 4.0 0.7; 0.6 0.8 9.0]
    cfg(
        physics,
    )=TaskConfig(
        model = ModelInput(
            model_file = joinpath(root, "examples/fixtures/synthetic_runtime/synthetic_tb.dat"),
        ),
        sampling = BZMesh(k_mesh = (2, 2, 2), spatial_dimension = 3),
        execution = ExecutionOptions(fourier_backend = "direct"),
        tasks = [TaskSpec(id = "measure", quantity = "JC", physics = physics)],
    )
    setting(physics)=let config=cfg(physics)
        runtime.compile_task_config(config, only(config.tasks)).third_order
    end
    base=(photon_energies = [0.7], fermi_energy = 0.0, temperature = 0.0)
    @test setting(JerkParameters(; base...)).projection == :ordered
    model=(lattice = lattice,)
    for jerk in (true, false)
        bf=runtime.third_order_si_factors(model, jerk)
        @test isapprox(
            collect(runtime.third_order_si_factors((lattice = 2lattice,), jerk)),
            collect(bf) ./ 8;
            rtol = 2e-15,
            atol = 0,
        )
    end
    for constructor in (JerkParameters, THGParameters),
        retired in (
            (response_measure = :bulk,),
            (response_measure = :sheet,),
            (sheet_axes = (1, 2),),
            (effective_thickness_angstrom = 2.0,),
        )

        @test_throws ArgumentError constructor(; base..., retired...)
    end
end

@testset "Decoupled duplicated states and active degenerate derivatives" begin
    response=WannierNLQG.Responses
    matrices=WannierNLQG.MatrixElements
    readcomplex(
        path,
    )=[
        complex(parse(Float64, split(line)[1]), parse(Float64, split(line)[2])) for
        line in eachline(path)
    ]
    input=readcomplex(joinpath(@__DIR__, "fixtures", "third_order", "jerk_input.dat"))
    selected=[1, 3]
    b=reshape(input[1:48], 4, 4, 3)[selected, selected, :]
    a=reshape(input[49:96], 4, 4, 3)[selected, selected, :]
    c=reshape(input[97:240], 4, 4, 3, 3)[selected, selected, :, :]
    function blockcopy(array)
        shape=size(array);
        out=zeros(eltype(array), 4, 4, shape[3:end]...)
        for indices in CartesianIndices(shape[3:end])
            trailing=Tuple(indices)
            out[1:2, 1:2, trailing...]=array[:, :, trailing...]
            out[3:4, 3:4, trailing...]=array[:, :, trailing...]
        end
        return out
    end
    data=(
        spectrum = (energies = [-1.5, 0.7],),
        hamiltonian_derivatives = b,
        internal_connection = a,
        hamiltonian_second_derivatives = c,
        internal_connection_derivatives = zeros(ComplexF64, 2, 2, 3, 3),
    )
    doubled=(
        spectrum = (energies = [-1.5, 0.7, -1.5, 0.7],),
        hamiltonian_derivatives = blockcopy(b),
        internal_connection = blockcopy(a),
        hamiltonian_second_derivatives = blockcopy(c),
        internal_connection_derivatives = zeros(ComplexF64, 4, 4, 3, 3),
    )
    first=zeros(ComplexF64, 1, 1, 4, 2, 2);
    second=similar(first)
    policy=response.HarmonicFrequencyPolicy(true, 0.025, 0.025, 0.04)
    options=(
        fermi_energy = 0.0,
        temperature = 300.0,
        policy,
        eta_correction = true,
        exact_occupations = false,
        formulation = :both,
    )
    response.third_harmonic_response!(
        first,
        response.ThirdHarmonicWorkspace(2),
        data,
        [0.37],
        [(1, 2, 3, 1)];
        options...,
    )
    response.third_harmonic_response!(
        second,
        response.ThirdHarmonicWorkspace(4),
        doubled,
        [0.37],
        [(1, 2, 3, 1)];
        options...,
    )
    @test isapprox(second, 2first; atol = 1e-12, rtol = 3e-13)
    active_c=zeros(ComplexF64, 2, 2, 3, 3);
    active_c[1, 2, 1, 1]=active_c[2, 1, 1, 1]=1
    active=(
        spectrum = (energies = [0.0, 0.0],),
        hamiltonian_derivatives = zeros(ComplexF64, 2, 2, 3),
        internal_connection = zeros(ComplexF64, 2, 2, 3),
        hamiltonian_second_derivatives = active_c,
        internal_connection_derivatives = zeros(ComplexF64, 2, 2, 3, 3),
    )
    active_geometry=matrices.ThirdOrderGeometry(2)
    matrices.prepare_third_order_geometry!(active_geometry, active)
    @test all(isfinite, active_geometry.dipoles)
    @test all(iszero, active_geometry.dipole_derivatives)
    @test active_geometry.diagnostics[1]>0
end

@testset "Current THG uncontracted A4 and formulation selection" begin
    M=WannierNLQG.MatrixElements
    R=WannierNLQG.Responses
    fixture=joinpath(@__DIR__, "fixtures", "third_order", "jerk_input.dat")
    input=[
        complex(parse(Float64, split(line)[1]), parse(Float64, split(line)[2])) for
        line in eachline(fixture)
    ]
    data=(
        spectrum = (energies = [-1.5, -0.4, 0.7, 1.8],),
        hamiltonian_derivatives = reshape(input[1:48], 4, 4, 3),
        internal_connection = reshape(input[49:96], 4, 4, 3),
        hamiltonian_second_derivatives = reshape(input[97:240], 4, 4, 3, 3),
        internal_connection_derivatives = zeros(ComplexF64, 4, 4, 3, 3),
    )
    energies=[0.37, 0.73]
    components=[(1, 1, 1, 1), (1, 2, 3, 1)]
    both=zeros(ComplexF64, 2, 2, 4, 2, 2)
    selected=similar(both)
    for gaussian in (false, true), eta in (0.001, 0.04), exact in (false, true)
        policy=R.HarmonicFrequencyPolicy(gaussian, 0.025, 0.025, eta)
        workspace=R.ThirdHarmonicWorkspace(4)
        options=(
            fermi_energy = 0.0,
            temperature = 3000.0,
            policy,
            eta_correction = true,
            exact_occupations = exact,
        )
        R.third_harmonic_response!(
            both,
            workspace,
            data,
            energies,
            components;
            options...,
            formulation = :both,
        )
        geometry=workspace.geometry
        occupation=workspace.occupations
        literal_geometry=M.ThirdOrderGeometry(4)
        M.prepare_third_order_geometry!(
            literal_geometry,
            data;
            regularization = eta,
            eta_correction = true,
        )
        @test geometry.dipole_derivatives === nothing && geometry.ratio_derivatives === nothing
        @test geometry.gradients == literal_geometry.gradients &&
              geometry.hessians == literal_geometry.hessians
        theta=8.617333262145e-5*3000.0
        for n in 1:4
            offset=data.spectrum.energies[n]
            f=1/(1+exp(offset/theta))
            first=exact ? -f*(1-f)/theta :
                  abs(offset)<=5theta ? -exp(-0.5*(offset/theta)^2)/(theta*sqrt(2pi)) : 0.0
            second=exact ? f*(1-f)*(1-2f)/theta^2 : -offset/theta^2*first
            @test occupation.values[n] ≈ f atol=1e-15 rtol=1e-15
            for a in 1:3, b in 1:3
                @test occupation.second[n, a, b] ≈
                      second*geometry.gradients[n, a]*geometry.gradients[
                    n,
                    b,
                ]+first*geometry.hessians[n, a, b] atol=1e-13 rtol=1e-13
            end
        end
        for (i, energy) in enumerate(energies), (j, (phi, c, b, a)) in enumerate(components)
            expected=zeros(ComplexF64, 4, 2)
            for triple in ((c, b, a), (c, a, b), (b, c, a), (b, a, c), (a, c, b), (a, b, c))
                coefficients=ThirdHarmonicLiteralReference.coefficients(
                    literal_geometry,
                    occupation,
                    data.spectrum.energies,
                    energy,
                    (phi, triple...),
                    0.025,
                    gaussian,
                )
                expected .+=
                    ThirdHarmonicLiteralReference.lower(coefficients, energy, 0.025, gaussian) ./ 6
            end
            @test both[i, j, :, :, 1] ≈ expected atol=3e-11 rtol=3e-10
        end
        for (form, slot) in ((:unregrouped, 1), (:regrouped, 2))
            R.third_harmonic_response!(
                selected,
                workspace,
                data,
                energies,
                components;
                options...,
                formulation = form,
            )
            @test reinterpret(UInt64, vec(selected[:, :, :, :, slot])) ==
                  reinterpret(UInt64, vec(both[:, :, :, :, slot]))
            @test all(iszero, selected[:, :, :, :, 3 - slot])
        end
        @test all(isfinite, both)
        # Finite-width pole identities are not imposed as a cross-formulation gate.
        @info "Current THG formulation difference" gaussian eta exact maximum(
            abs,
            sum(both[:, :, :, 1, 1]; dims = 3)-sum(both[:, :, :, 1, 2]; dims = 3),
        )
    end
    fill!(selected, ComplexF64(9, 2))
    @test_throws ArgumentError R.third_harmonic_response!(
        selected,
        R.ThirdHarmonicWorkspace(4),
        data,
        energies,
        components;
        fermi_energy = 0.0,
        temperature = 3000.0,
        policy = R.HarmonicFrequencyPolicy(true, 0.025, 0.025, 0.001),
        eta_correction = true,
        exact_occupations = false,
        formulation = :unsupported,
    )
    @test all(==(ComplexF64(9, 2)), selected)
end

@testset "Scalar-band THG Boltzmann coefficient and independent pole lowering" begin
    R=WannierNLQG.Responses
    # Local scalar dispersion E(k)=E0+v*k+(q/2)*k^2; A4d follows from three
    # integrations by parts of the scalar Boltzmann expression, including 1/6.
    h=zeros(ComplexF64, 1, 1, 3);
    h[1, 1, 1]=0.3
    hh=zeros(ComplexF64, 1, 1, 3, 3);
    hh[1, 1, 1, 1]=1.2
    data=(
        spectrum = (energies = [0.02],),
        hamiltonian_derivatives = h,
        hamiltonian_second_derivatives = hh,
        internal_connection = zeros(ComplexF64, 1, 1, 3),
        internal_connection_derivatives = zeros(ComplexF64, 1, 1, 3, 3),
    )
    temperature=700.0;
    theta=8.617333262145e-5*temperature
    f=1/(1+exp(0.02/theta))
    first=-f*(1-f)/theta
    second=f*(1-f)*(1-2f)/theta^2
    fab=second*0.3^2+first*1.2
    coefficient=-im*1.2*fab/6
    output=zeros(ComplexF64, 1, 1, 4, 2, 2)
    for gaussian in (false, true), energy in (0.0, 0.013, 0.37)
        width=0.025
        policy=R.HarmonicFrequencyPolicy(gaussian, width, width, 0.001)
        R.third_harmonic_response!(
            output,
            R.ThirdHarmonicWorkspace(1),
            data,
            [energy],
            [(1, 1, 1, 1)];
            fermi_energy = 0.0,
            temperature,
            policy,
            eta_correction = true,
            exact_occupations = true,
            formulation = :both,
        )
        principal=energy/(energy^2+width^2)
        delta=gaussian ? exp(-(energy/width)^2)/(sqrt(pi)*width) : width/(pi*(energy^2+width^2))
        @test all(iszero, output[:, :, 1:3, :, :])
        for form in 1:2
            @test output[1, 1, 4, 1, form] ≈ coefficient*complex(principal, -delta)*principal^2 atol=3e-13 rtol=3e-12
            @test output[1, 1, 4, 2, form] ≈
                  coefficient*(im/3)*complex(principal, -delta)*principal^3 atol=3e-13 rtol=3e-12
        end
    end
end

@testset "Direct R-Q combinations retain cutoff masks and finite connection" begin
    M=WannierNLQG.MatrixElements
    R=WannierNLQG.Responses
    eta=0.001
    for gap in (0.0, .5e-7, 1e-7, 2e-7)
        h=zeros(ComplexF64, 2, 2, 3)
        hh=zeros(ComplexF64, 2, 2, 3, 3);
        hh[1, 2, 1, 1]=hh[2, 1, 1, 1]=1
        a=zeros(ComplexF64, 2, 2, 3);
        a[:, :, 1] .= [0.2 0.3im; -0.3im -0.4]
        da=zeros(ComplexF64, 2, 2, 3, 3);
        da[1, 2, 1, 1]=0.17+0.03im;
        da[2, 1, 1, 1]=0.17-0.03im
        data=(
            spectrum = (energies = [0.0, gap],),
            hamiltonian_derivatives = h,
            hamiltonian_second_derivatives = hh,
            internal_connection = a,
            internal_connection_derivatives = da,
        )
        band=(
            spectrum = data.spectrum,
            hamiltonian_derivatives = h,
            hamiltonian_second_derivatives = hh,
        )
        workspace=R.ThirdHarmonicWorkspace(2)
        geometry=workspace.geometry
        fill!(geometry.dipoles, ComplexF64(9, 2))
        @test M.prepare_third_order_band_geometry!(geometry, band; regularization = eta) ===
              geometry
        @test all(==(ComplexF64(9, 2)), geometry.dipoles) # No A/G read before occupations.
        M.prepare_third_order_combined_geometry!(
            geometry,
            data;
            regularization = eta,
            eta_correction = true,
        )
        @test geometry.dipole_derivatives === nothing && geometry.ratio_derivatives === nothing
        @test geometry.dipoles == a
        finite=da[1, 2, 1, 1]-im*a[1, 2, 1]*(a[1, 1, 1]-a[2, 2, 1])
        @test geometry.finite_literature_derivatives[1, 2, 1, 1] == finite
        @test geometry.literature_derivative_numerators[1, 2, 1, 1] == im
        cutoff=gap<1e-7
        inverse=cutoff ? 0.0 : 1/gap
        principal=gap/(gap^2+eta^2)
        expected_dg=cutoff ? gap*finite : gap*finite+im
        @test geometry.velocity_derivatives[1, 2, 1, 1] ≈ -im*expected_dg atol=1e-15 rtol=1e-15
        @test M.optical_derivative_combination(finite, im, inverse, gap) ≈ expected_dg atol=1e-15 rtol=1e-15
        expected_pg=cutoff ? principal*finite : principal*finite+im/(gap^2+eta^2)
        @test M.optical_derivative_combination(finite, im, inverse, principal) ≈ expected_pg atol=1e-13 rtol=1e-13
        @test M.optical_derivative_combination(finite, im, inverse, -1.0) ==
              (cutoff ? -finite : -finite-inverse*im)
        factors=R._harmonic_gap_factors!(
            workspace.gap_factors,
            R.HarmonicFrequencyPolicy(true, 0.025, 0.025, eta),
            data.spectrum.energies,
        )
        @test factors.bare_position_inverse[1, 2]==inverse
        @test factors.static_gap_principal[1, 2]==-principal # Opposite declared gap orientation.
        @test factors.bare_position_inverse[2, 1]==-inverse
        @test factors.static_gap_principal[2, 1]==principal
    end
    finite=0.35+0.03im
    @test M.optical_derivative_combination(finite, ComplexF64(Inf, Inf), 0.0, 0.7)==0.7*finite
    @test M.optical_derivative_combination(finite, ComplexF64(Inf, Inf), 1e7, 0.0)==0
end

@testset "THG scalar-cache cycles agree with fresh task contexts" begin
    M=WannierNLQG.MatrixElements
    R=WannierNLQG.Responses
    values=[
        complex(parse(Float64, split(line)[1]), parse(Float64, split(line)[2])) for
        line in eachline(joinpath(@__DIR__, "fixtures", "third_order", "jerk_input.dat"))
    ]
    base=(
        spectrum = (energies = [-1.5, -0.4, 0.7, 1.8],),
        hamiltonian_derivatives = reshape(values[1:48], 4, 4, 3),
        internal_connection = reshape(values[49:96], 4, 4, 3),
        hamiltonian_second_derivatives = reshape(values[97:240], 4, 4, 3, 3),
        internal_connection_derivatives = zeros(ComplexF64, 4, 4, 3, 3),
    )
    workspace=R.ThirdHarmonicWorkspace(4)
    @test isconcretetype(fieldtype(typeof(workspace), :geometry))
    literal=M.ThirdOrderGeometry(4)
    combined=workspace.geometry
    @test sizeof(combined.finite_literature_derivatives)+sizeof(
        combined.literature_derivative_numerators,
    )+sizeof(combined.velocity_derivatives) ==
          sizeof(literal.dipole_derivatives)+sizeof(literal.ratio_derivatives)+sizeof(
        literal.velocity_derivatives,
    )
    reused=zeros(ComplexF64, 2, 1, 4, 2, 2);
    fresh=similar(reused)
    for (iteration, (eta, gaussian, resonance, mu, temp)) in enumerate((
        (0.001, true, 0.025, 0.0, 3000.0),
        (0.001, false, 0.04, 0.1, 1500.0),
        (0.04, false, 0.04, 0.1, 1500.0),
        (0.04, true, 0.025, -0.1, 3000.0),
        (0.001, true, 0.025, 0.0, 3000.0),
    ))
        # Change the ordered spectrum and later restore it; matrix context also varies.
        energy=iteration==3 ? [-1.5, -0.39, 0.7, 1.8] : copy(base.spectrum.energies)
        data=merge(
            base,
            (
                spectrum = (energies = energy,),
                hamiltonian_derivatives = base.hamiltonian_derivatives .*
                                          (iteration==4 ? 1.1 : 1.0),
            ),
        )
        policy=R.HarmonicFrequencyPolicy(gaussian, resonance, 0.025, eta)
        options=(
            fermi_energy = mu,
            temperature = temp,
            policy,
            eta_correction = true,
            exact_occupations = true,
            formulation = :both,
        )
        R.third_harmonic_response!(
            reused,
            workspace,
            data,
            [0.37, 0.73],
            [(1, 2, 3, 1)];
            options...,
        )
        R.third_harmonic_response!(
            fresh,
            R.ThirdHarmonicWorkspace(4),
            data,
            [0.37, 0.73],
            [(1, 2, 3, 1)];
            options...,
        )
        @test reinterpret(UInt64, vec(reused))==reinterpret(UInt64, vec(fresh))
        @test workspace.gap_factors.width==eta && workspace.gap_factors.energies==energy
        for bra in 1:4, ket in 1:4
            d=energy[ket]-energy[bra]
            @test workspace.gap_factors.bare_position_inverse[bra, ket] == (abs(d)<1e-7 ? 0.0 : 1/d)
            @test workspace.gap_factors.static_gap_principal[bra, ket] == -d/(d^2+eta^2)
        end
    end
end

@testset "Orthogonal nonlinear plan prepares raw geometry only" begin
    E=WannierNLQG.MatrixElements
    R=WannierNLQG.Runtime
    root=dirname(@__DIR__)
    model_path=joinpath(root, "examples/fixtures/synthetic_runtime/synthetic_tb.dat")
    model=WannierNLQG.IO.read_wannier_tb(model_path)
    for (quantity, physics) in (
        ("SHG", SHGParameters(photon_energies = [0.73], fermi_energy = 0.0, temperature = 0.0)),
        ("JC", JerkParameters(photon_energies = [0.73], fermi_energy = 0.0, temperature = 0.0)),
        ("THG", THGParameters(photon_energies = [0.73], fermi_energy = 0.0, temperature = 0.0)),
    )
        task=TaskSpec(
            id = "nonlinear_demand",
            quantity = quantity,
            method = "Conventional",
            physics = physics,
            observable = FullTensor(),
        )
        input=TaskConfig(
            model = ModelInput(model_file = model_path),
            sampling = BZMesh(k_mesh = (2, 2, 2), spatial_dimension = 3),
            tasks = [task],
            execution = ExecutionOptions(fourier_backend = "Direct"),
        )
        cfg=R.compile_task_config(input, task)
        plan=R.bundle_matrix_element_plan(R.normalize_task_specs(cfg), cfg)
        for kind in (
            E.HAMILTONIAN_DERIVATIVES,
            E.INTERNAL_CONNECTION,
            E.INTERNAL_CONNECTION_DERIVATIVES,
            E.HAMILTONIAN_SECOND_DERIVATIVES,
        )
            @test E.has_capability(plan, kind)
        end
        for kind in (E.BERRY_CONNECTION, E.GAUGE_CORRECTION, E.VELOCITY_VERTICES)
            @test !E.has_capability(plan, kind)
        end
        oldplan=E.compile_matrix_plan(
            E.MatrixElementRequest(
                E.BERRY_CONNECTION,
                E.INTERNAL_CONNECTION_DERIVATIVES,
                E.HAMILTONIAN_SECOND_DERIVATIVES;
                spatial_dimension = 3,
                denominator_regularization = cfg.denominator_regularization,
            ),
        )
        ws=E.MatrixElementWorkspace(model, plan);
        old=E.MatrixElementWorkspace(model, oldplan)
        E.prepare_real_space!(ws, model);
        E.prepare_real_space!(old, model)
        for point in ([0.17, 0.23, 0.31], [0.0, 0.0, 0.0])
            data=E.compute_kpoint!(ws, model, point);
            reference=E.compute_kpoint!(old, model, point)
            for name in (
                :hamiltonian_derivatives,
                :internal_connection,
                :internal_connection_derivatives,
                :hamiltonian_second_derivatives,
            )
                @test reinterpret(
                    UInt64,
                    vec(getproperty(data, name)),
                )==reinterpret(UInt64, vec(getproperty(reference, name)))
            end
            @test data.spectrum.energies==reference.spectrum.energies
            @test !E._has_capability(data.computed_mask, E.GAUGE_CORRECTION)
            @test !E._has_capability(data.computed_mask, E.BERRY_CONNECTION)
        end
    end
end

@testset "Positive position widths retain representable squared limits" begin
    E=WannierNLQG.MatrixElements
    for eta in (0.001, 0.04, 1.0, 1e-100), difference in (0.0, -1.0, 0.2, -0.5eta, eta, 2eta)
        original=difference/(difference^2+eta^2)
        weight=eta^2/(difference^2+eta^2)
        @test isequal(E.regularized_energy_inverse(difference, eta), original)
        @test isequal(E.regularized_energy_weight(difference, eta), weight)
    end
    for eta in (1e-200, 1e200), scale in (0.0, -0.5, 1.0, 2.0)
        difference=scale*eta
        inverse, weight=setprecision(256) do
            d=BigFloat(difference);
            e=BigFloat(eta)
            Float64(d/(d^2+e^2)), Float64(e^2/(d^2+e^2))
        end
        @test E.regularized_energy_inverse(difference, eta) ≈ inverse rtol=3eps() atol=0
        @test E.regularized_energy_weight(difference, eta) ≈ weight rtol=3eps() atol=0
    end
    @test E.regularized_energy_weight(1e-100, 1e-200) ≈ 1e-200 rtol=3eps() atol=0
    for eta in (1e-200, 1e200)
        energies=[0.0, 0.0, eta]
        h=ones(ComplexF64, 3, 3, 3)
        a=fill(0.2+0.1im, 3, 3, 3)
        hh=zeros(ComplexF64, 3, 3, 3, 3);
        da=fill(0.17+0.03im, 3, 3, 3, 3)
        output=zeros(ComplexF64, 3, 3, 3)
        E.eigenvector_corrections!(output, energies, h, Val(:regularized), eta)
        @test all(isfinite, output)
        @test all(iszero, output[1:2, 1:2, :])
        r=similar(output);
        E.position_vertices!(r, a, output)
        @test r[1:2, 1:2, :]==a[1:2, 1:2, :]
        # C is assembled only once before the external I0; this all-degenerate
        # endpoint keeps finite raw R while intermediate C weights remain defined.
        zero_data=(
            spectrum = (energies = zeros(3),),
            hamiltonian_derivatives = h,
            internal_connection = a,
            internal_connection_derivatives = da,
            hamiltonian_second_derivatives = hh,
        )
        r0, reta, G, D0=E.optical_position_vertices(zero_data, eta, true)
        @test all(isfinite, G) && all(isfinite, reta) && all(isfinite, r0)
        @test all(iszero, D0)
    end
    model=WannierNLQG.IO.read_wannier_tb(
        joinpath(dirname(@__DIR__), "examples/fixtures/synthetic_runtime/synthetic_tb.dat"),
    )
    for eta in (0.001, 1e-200, 1e200)
        plan=E.compile_matrix_plan(
            E.MatrixElementRequest(
                E.GAUGE_CORRECTION,
                E.INTERNAL_CONNECTION;
                spatial_dimension = 3,
                denominator_regularization = eta,
            ),
        )
        ws=E.MatrixElementWorkspace(model, plan);
        E.prepare_real_space!(ws, model)
        data=E.compute_kpoint!(ws, model, [0.17, 0.23, 0.31])
        @test all(isfinite, data.position.inverse_energy_differences)
        actual=similar(data.gauge_correction)
        E.eigenvector_corrections!(actual, ws, Val(:regularized))
        @test actual==data.gauge_correction
        @test all(isfinite, actual)
    end
    for eta in (0.0, -1.0, NaN, Inf)
        @test_throws ArgumentError E.eigenvector_corrections!(
            zeros(ComplexF64, 2, 2, 1),
            [0.0, 1.0],
            ones(ComplexF64, 2, 2, 1),
            Val(:regularized),
            eta,
        )
    end
end

@testset "Compact Jerk workers preserve literal responses and band fields" begin
    E=WannierNLQG.MatrixElements
    R=WannierNLQG.Responses
    raw=[
        complex(parse(Float64, split(line)[1]), parse(Float64, split(line)[2])) for
        line in eachline(joinpath(@__DIR__, "fixtures/third_order/jerk_input.dat"))
    ]
    data=(
        spectrum = (energies = [-1.5, -0.4, 0.7, 1.8],),
        hamiltonian_derivatives = reshape(raw[1:48], 4, 4, 3),
        internal_connection = reshape(raw[49:96], 4, 4, 3),
        hamiltonian_second_derivatives = reshape(raw[97:240], 4, 4, 3, 3),
    )
    compact=E.JerkCurrentGeometry(4);
    literal=E.ThirdOrderGeometry(4)
    actual=zeros(ComplexF64, 3, length(R.JERK_CURRENT_COMPONENTS));
    reference=similar(actual)
    occupation=zeros(4);
    old_occupation=similar(occupation)
    for eta in (0.001, 0.04),
        temperature in (0.0, 3000.0),
        gaussian in (false, true),
        projection in (:ordered, :symmetric, :antisymmetric),
        window in (-1, 1)

        options=(
            fermi_energy = 0.0,
            temperature,
            broadening = 0.06,
            gaussian,
            regularization = eta,
            transition_window_factor = 0.0,
            band_window_size = window,
            projection,
        )
        R.jerk_current_response!(
            actual,
            compact,
            occupation,
            data,
            [0.37, 0.73, 1.1],
            R.JERK_CURRENT_COMPONENTS;
            options...,
        )
        R.jerk_current_response!(
            reference,
            literal,
            old_occupation,
            data,
            [0.37, 0.73, 1.1],
            R.JERK_CURRENT_COMPONENTS;
            options...,
        )
        @test reinterpret(UInt64, vec(actual))==reinterpret(UInt64, vec(reference))
        @test reinterpret(UInt64, vec(compact.dipoles))==reinterpret(UInt64, vec(literal.dipoles))
        @test reinterpret(UInt64, vec(compact.hessians))==reinterpret(UInt64, vec(literal.hessians))
        @test reinterpret(
            UInt64,
            vec(compact.gradients),
        )==reinterpret(UInt64, vec(literal.gradients))
        @test compact.diagnostics==literal.diagnostics &&
              compact.gap_diagnostics==literal.gap_diagnostics
        @test occupation==old_occupation
    end
    for count in (16, 32)
        E.JerkCurrentGeometry(count);
        E.ThirdOrderGeometry(count)
        GC.gc()
        compact_bytes=@allocated E.JerkCurrentGeometry(count)
        literal_bytes=@allocated E.ThirdOrderGeometry(count)
        compact_payload=Base.summarysize(E.JerkCurrentGeometry(count))
        literal_payload=Base.summarysize(E.ThirdOrderGeometry(count))
        @test compact_bytes<literal_bytes/5
        @test compact_payload<literal_payload/5
        @info "Jerk constructor memory only" count compact_bytes literal_bytes compact_payload literal_payload
    end
end

module JerkInjectionOccupationTests
using Test, LinearAlgebra, WannierNLQG
const C=WannierNLQG.Core
const M=WannierNLQG.MatrixElements
const R=WannierNLQG.Responses
function occupation_data(energies)
    n=length(energies)
    h=zeros(ComplexF64, n, n, 3);
    c=zeros(ComplexF64, n, n, 3, 3)
    if n==2
        h[:, :, 1]=ComplexF64[0.1 0.3+0.2im; 0.3-0.2im -0.2]
        c[:, :, 1, 1]=Diagonal([0.2, 0.4])
    end
    (;
        spectrum = (energies = energies,),
        hamiltonian_derivatives = h,
        hamiltonian_second_derivatives = c,
        internal_connection = zeros(ComplexF64, n, n, 3),
    )
end
function jerk_value!(occupations, data, temperature)
    out=zeros(ComplexF64, 1, 1)
    R.jerk_current_response!(
        out,
        M.JerkCurrentGeometry(length(data.spectrum.energies)),
        occupations,
        data,
        [0.73],
        [(1, 1, 1, 1)];
        fermi_energy = 0.0,
        temperature,
        broadening = 0.04,
        gaussian = false,
        regularization = 0.001,
        transition_window_factor = 0.0,
        band_window_size = -1,
    )
    out
end
@testset "Jerk reuses exact ordinary IC occupation contract" begin
    for temperature in (0.0, nextfloat(0.0), 1e-315, 1e-8, 1e-7, nextfloat(1e-7), 300.0, 3000.0)
        theta=C.BOLTZMANN_CONSTANT_EV_K*temperature
        data=occupation_data([-1.0, -theta, 0.0, theta, 1.0]);
        actual=fill(NaN, 5);
        expected=similar(actual)
        C.fermi_dirac!(expected, data.spectrum.energies, 0.0, temperature)
        result=jerk_value!(actual, data, temperature)
        @test reinterpret(UInt64, actual)==reinterpret(UInt64, expected)
        @test all(isfinite, actual)&&all(isfinite, result)
        @test actual[3]==(iszero(theta) ? 1.0 : 0.5)
        if theta>0
            @test actual[2]≈1/(1+exp(-1.0)) atol=1e-15 rtol=1e-15
            @test actual[4]≈1/(1+exp(1.0)) atol=1e-15 rtol=1e-15
        end
    end
    # A two-band single absorption pair isolates the occupation weight independently
    # of optical/Hessian evaluation: every response must scale with f_lower-f_upper.
    data=occupation_data([0.0, 1.0]);
    occupations=zeros(2)
    zero=jerk_value!(occupations, data, 0.0)
    @test norm(zero)>1e-8
    for temperature in (1e-8, 1e-7, 300.0, 3000.0, 0.0, 1e-8)
        value=jerk_value!(occupations, data, temperature)
        weight=temperature==0 ? 1.0 :
               temperature<=1e-7 ? 0.5 :
               Float64(
            BigFloat(
                0.5,
            )-inv(1+exp(BigFloat(1)/(BigFloat(C.BOLTZMANN_CONSTANT_EV_K)*BigFloat(temperature)))),
        )
        @test value≈zero*weight atol=2e-14 rtol=2e-14
    end
    @test_throws DimensionMismatch jerk_value!(zeros(1), data, 300.0)
    # The SHG/THG helper intentionally retains its separate legacy switch.
    @test R.second_harmonic_occupation(0.0, 0.0, 1e-8)==1.0
    @test C.fermi_dirac([0.0], 0.0, 1e-8)==[0.5]
end
end
