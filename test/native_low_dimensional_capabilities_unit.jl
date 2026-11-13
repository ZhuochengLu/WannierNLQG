module NativeLowDimensionalCapabilitiesUnit
using WannierNLQG, Test, LinearAlgebra, JSON3
const C = WannierNLQG.Core
const R = WannierNLQG.Runtime
const CALLS = Ref(0)
root_owner() = R.mpi_is_root_process()
compute(config) = (CALLS[] += 1; WannierNLQG.run(config))

# Real hoppings give spinless time reversal while unequal onsite energies break inversion.
function inputs(d)
    lattice = Matrix{Float64}(I, d, d) * 2
    vectors = zeros(Int, d, 1 + 2d)
    hopping = zeros(ComplexF64, 2, 2, 1 + 2d)
    hopping[:, :, 1] .= [0.5 1.0; 1.0 -0.5]
    for a in 1:d
        vectors[a, 2a] = 1
        vectors[a, 2a + 1] = -1
        hopping[:, :, 2a] .= [0.0 0.2/a; 0.0 0.0]
        hopping[:, :, 2a + 1] .= hopping[:, :, 2a]'
    end
    tb = RealSpaceTBInput(
        lattice = lattice,
        r_vectors = vectors,
        hamiltonian_r = hopping,
        orbital_positions = zeros(d, 2),
    )
    analytic = AnalyticKInput(
        hamiltonian = physical_h,
        num_orbitals = 2,
        lattice = lattice,
        orbital_positions = zeros(d, 2),
        parameters = (lattice = lattice, vectors = vectors, hopping = hopping),
        source_file = @__FILE__
    )
    return tb, analytic
end
function physical_h(k, p)
    result = zeros(promote_type(ComplexF64, eltype(k)), 2, 2)
    for index in axes(p.vectors, 2)
        result .+=
            exp(im * sum(k .* (transpose(p.lattice)*p.vectors[:, index]))) .* p.hopping[:, :, index]
    end
    return result
end
rows(path) = [
    parse.(Float64, split(line)) for
    line in eachline(path) if !isempty(strip(line)) && !startswith(strip(line), "#")
]
tables(result) = Dict(basename(p)=>rows(p) for p in result.outputs if endswith(p, ".dat"))
operations() = [
    PointOrbitalSymmetryOperation(
        rotation_fractional = Matrix{Int}(I, 3, 3),
        antiunitary = anti,
        representation = Matrix{ComplexF64}(I, 2, 2),
    ) for anti in (false, true)
]

function shift_config(model, d; artifact = nothing, mode = "full")
    return TaskConfig(
        model = model,
        sampling = BZMesh(k_mesh = ntuple(_->4, d)),
        tasks = [
            TaskSpec(
                id = "shift",
                quantity = "SC",
                method = "Conventional",
                physics = OpticalParameters(
                    photon_energies = [2.2],
                    fermi_energy = 0.0,
                    temperature = 300.0,
                ),
            ),
        ],
        execution = ExecutionOptions(
            fourier_backend = "direct",
            response_symmetry_file = artifact,
            response_symmetry_kmesh_mode = mode,
            response_symmetry_report_enabled = artifact!==nothing,
        ),
        output = OutputOptions(
            output_root = mktempdir(),
            progress_enabled = false,
            response_output_digits = 17,
        ),
    )
end

@testset "LowD native symmetry reuses full model/covariance/orbit validation" begin
    for d in (1, 2), model in inputs(d)
        directory=mktempdir()
        artifact=write_native_response_symmetry(
            joinpath(directory, "symmetry.json"),
            model,
            operations(),
        )
        adopted=WannierNLQG.IO.read_native_response_symmetry(artifact)
        @test WannierNLQG.IO.validate_native_response_symmetry_model(adopted, model) === nothing
        # Both routes execute; reduction only merges physical momenta, never reference axes.
        results=[
            compute(shift_config(model, d; artifact = setting[1], mode = setting[2])) for
            setting in ((nothing, "full"), (artifact, "full"), (artifact, "reduced"))
        ]
        if root_owner()
            original=tables(first(results))
            @test !isempty(original)
            @test any(any(abs.(row[2:end]) .> 1e-20) for table in values(original) for row in table)
            for result in results[2:end]
                actual=tables(result)
                @test keys(actual)==keys(original)
                for name in keys(original)
                    @test reduce(hcat, actual[name]) ≈ reduce(hcat, original[name]) atol=1e-10 rtol=1e-8
                end
                leaf=isempty(result.task_results) ? result : only(result.task_results)
                summary=JSON3.read(
                    read(joinpath(leaf.run_dir, "response_symmetry_summary.json"), String),
                )
                @test summary.k_mesh.full_kpoint_count==4^d
                @test summary.status=="COMPUTATION_READY"
                @test summary.model_binding=="complete_definition_byte_comparison/1"
                @test !summary.production_eligible
            end
        end
        mixed=Matrix{Int}(I, 3, 3);
        mixed[:, [1, 3]]=mixed[:, [3, 1]]
        bad=PointOrbitalSymmetryOperation(
            rotation_fractional = mixed,
            representation = Matrix{ComplexF64}(I, 2, 2),
        )
        @test_throws ArgumentError write_native_response_symmetry(
            joinpath(directory, "mix.json"),
            model,
            [bad],
        )
        translation=zeros(3);
        translation[3]=1.0
        shifted=PointOrbitalSymmetryOperation(
            rotation_fractional = Matrix{Int}(I, 3, 3),
            translation_fractional = translation,
            representation = Matrix{ComplexF64}(I, 2, 2),
        )
        @test_throws ArgumentError write_native_response_symmetry(
            joinpath(directory, "translate.json"),
            model,
            [shifted],
        )
        # A low-level artifact cannot bypass the runtime physical-subspace validation.
        unsafe=WannierNLQG.IO.write_native_symmetry_artifact(
            joinpath(directory, "unsafe.json"),
            model,
            [bad],
        )
        @test_throws ArgumentError R.validate_native_physical_symmetry(
            model,
            WannierNLQG.IO.read_native_response_symmetry(unsafe).operations,
        )
    end
end

@testset "Direct1D BCD and BCQ retain the kernel's zero Berry two-form" begin
    for model in inputs(1), quantity in ("BCDC", "BCQC"), adaptive in (false, true)
        component=quantity=="BCDC" ? TensorComponent(1, 2, 1) : TensorComponent(1, 2, 1, 1)
        config=TaskConfig(
            model = model,
            sampling = BZMesh(k_mesh = (3,)),
            tasks = [
                TaskSpec(
                    id = "dc",
                    quantity = quantity,
                    method = "Conventional",
                    physics = BerryMultipoleParameters(
                        fermi_energies = [0.0],
                        temperature = 300.0,
                        relaxation_time_fs = 7.0,
                        integral_form = :fermi_sea,
                    ),
                    observable = TensorComponents(component),
                ),
            ],
            execution = ExecutionOptions(
                fourier_backend = "direct",
                integration_algorithm = adaptive ?
                                        HAdaptiveCubature(
                    atol = 0.0,
                    rtol = 1e-12,
                    max_evaluations = 15,
                ) : UniformIntegration(),
            ),
            output = OutputOptions(
                output_root = mktempdir(),
                progress_enabled = false,
                response_output_digits = 17,
            ),
        )
        result=compute(config)
        if root_owner()
            path=only(filter(p->endswith(p, "_conductivity.dat"), result.outputs))
            @test all(iszero(last(row)) for row in rows(path))
        end
        effective=only(R.compile_task_configs(config))
        runtime_model=C.native_physical_dimension(model)==1 && model isa RealSpaceTBInput ?
                      model.model : C.AnalyticKModel(model)
        @test R.berry_multipole_integration_measure(effective, runtime_model)[1]==3
    end
    # Old complete3x3 with a one-count-axis mesh retains the existing rejection.
    legacy=RealSpaceTBInput(
        lattice = Matrix{Float64}(I, 3, 3),
        r_vectors = zeros(Int, 3, 1),
        hamiltonian_r = reshape(ComplexF64[1], 1, 1, 1),
        orbital_positions = zeros(3, 1),
    )
    cfg=TaskConfig(
        model = legacy,
        sampling = BZMesh(k_mesh = (2,)),
        tasks = [
            TaskSpec(
                id = "old",
                quantity = "BCDC",
                method = "Conventional",
                physics = BerryMultipoleParameters(
                    fermi_energies = [0.0],
                    temperature = 300.0,
                    relaxation_time_fs = 7.0,
                    integral_form = :fermi_sea,
                ),
            ),
        ],
        execution = ExecutionOptions(fourier_backend = "direct"),
    )
    @test_throws ArgumentError R.berry_multipole_integration_measure(
        only(R.compile_task_configs(cfg)),
        legacy.model,
    )
end

@testset "Direct physical Band paths do not sample auxiliary axes" begin
    for d in (1, 2)
        model=first(inputs(d))
        config=TaskConfig(
            model = model,
            sampling = KPath(
                nodes = [("G", ntuple(_->0.0, d)), ("X", ntuple(a->a==1 ? 0.25 : 0.0, d))],
                kpoints_per_segment = [3],
            ),
            tasks = [
                TaskSpec(
                    id = "bands",
                    quantity = "Band",
                    physics = BandParameters(fermi_energy = 0.0),
                ),
            ],
            execution = ExecutionOptions(fourier_backend = "direct"),
            output = OutputOptions(output_root = mktempdir(), progress_enabled = false),
        )
        result=compute(config)
        root_owner() && @test !isempty(result.outputs)
    end
end

# Same finite-domain polynomial and physical cell, with no inferred transverse sampling.
function continuum_h(k, p)
    return [
        one(k[1])+k[1]^2 k[1]+(length(k)==2 ? im*k[2] : zero(k[1]));
        k[1]-(length(k)==2 ? im*k[2] : zero(k[1])) -one(k[1])+k[1]^2
    ]
end
@testset "Nonperiodic direct JC/THG bulk coefficients retain physical-domain measure" begin
    for d in (1, 2), quantity in ("JC", "THG")
        lattice=Matrix{Float64}(I, d, d)*2
        fresh=AnalyticKInput(
            hamiltonian = continuum_h,
            num_orbitals = 2,
            lattice = lattice,
            basis = :fixed_orthonormal,
            periodic = false,
            source_file = @__FILE__
        )
        legacy=AnalyticKInput(
            hamiltonian = (k, p)->continuum_h(view(k, 1:d), p),
            num_orbitals = 2,
            lattice = fresh.lattice,
            basis = :fixed_orthonormal,
            periodic = false,
            source_file = @__FILE__
        )
        physics=quantity=="JC" ?
                JerkParameters(photon_energies = [2.2], fermi_energy = 0.0, temperature = 300.0) :
                THGParameters(
            photon_energies = [0.73],
            fermi_energy = 0.0,
            temperature = 300.0,
            formulation = :both,
        )
        results=[
            compute(
                TaskConfig(
                    model = model,
                    sampling = KRegion(
                        lower = ntuple(_->0.1, d),
                        upper = ntuple(_->0.2, d),
                        k_mesh = ntuple(_->2, d),
                    ),
                    tasks = [
                        TaskSpec(
                            id = "third",
                            quantity = quantity,
                            method = "Conventional",
                            physics = physics,
                            observable = TensorComponents(TensorComponent(1, 1, 1, 1)),
                        ),
                    ],
                    execution = ExecutionOptions(fourier_backend = "direct"),
                    output = OutputOptions(
                        output_root = mktempdir(),
                        progress_enabled = false,
                        response_output_digits = 17,
                    ),
                ),
            ) for model in (fresh, legacy)
        ]
        if root_owner()
            a, b=tables.(results)
            @test keys(a)==keys(b)
            for name in keys(a)
                if name == "thg_formulation_residual.dat"
                    # Row/component/observable labels and the dimensionless relative
                    # residual do not acquire response units. Only abs_difference scales.
                    @test [row[1:3] for row in a[name]] == [row[1:3] for row in b[name]]
                    @test getindex.(a[name], 4) ≈ getindex.(b[name], 4) .* 10.0^(10*(3-d)) rtol=2e-12 atol=1e-28
                    @test last.(a[name]) ≈ last.(b[name]) atol=2e-12 rtol=2e-12
                else
                    @test first.(a[name])==first.(b[name])
                    @test reduce(hcat, [row[2:end] for row in a[name]]) ≈ reduce(hcat, [row[2:end] for row in b[name]]) .* 10.0^(10*(3-d)) rtol=2e-12 atol=1e-28
                end
            end
        end
    end
end
end
