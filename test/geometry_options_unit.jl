module GeometryOptionsUnit
using Test, LinearAlgebra, WannierNLQG
const R = WannierNLQG.Runtime
const M = WannierNLQG.MatrixElements
const C = WannierNLQG.Core
const G = WannierNLQG.Responses
const WIO = WannierNLQG.IO

# Two-band finite model with an independently known projected position metric.
function finite_models()
    lattice = Matrix{Float64}(I, 3, 3)
    rv = zeros(Int, 3, 1)
    h = reshape(ComplexF64[-1 0.3; 0.3 1], 2, 2, 1)
    tau = [0.0 0.5; 0.0 0.0; 0.0 0.0]
    orthogonal =
        RealSpaceTBInput(; lattice, r_vectors = rv, hamiltonian_r = h, orbital_positions = tau)
    x = ComplexF64[1.2 0.1im; 0.2 0.9]
    pos = zeros(ComplexF64, 2, 2, 3, 1)
    pos[:, :, 1, 1] = x'*Diagonal(tau[1, :])*x
    localized = C.NonorthogonalLocalizedModel(;
        lattice,
        r_vectors = rv,
        hamiltonian_r = reshape(x'*h[:, :, 1]*x, 2, 2, 1),
        overlap_r = reshape(x'*x, 2, 2, 1),
        position_r = pos,
    )
    return orthogonal, C.NonorthogonalLocalizedInput(localized)
end

# Keep each public run isolated and use the ordinary Direct K-slice entry.
function configuration(model; quantity = "QMK", eta = nothing, external = false)
    rank = quantity in ("QMDK", "QCSK", "BCDK") ? 3 : quantity in ("QMQK", "BCQK") ? 4 : 2
    numerics = eta === nothing ? Numerics() : Numerics(denominator_regularization = eta)
    TaskConfig(;
        model,
        sampling = KSlice(
            k_mesh = (1, 1),
            spatial_dimension = 3,
            origin = (0.07, 0.11, 0.0),
            vector_1 = (1.0, 0.0, 0.0),
            vector_2 = (0.0, 1.0, 0.0),
        ),
        execution = ExecutionOptions(fourier_backend = "direct"),
        output = OutputOptions(output_root = mktempdir(), progress_enabled = false),
        tasks = [
            TaskSpec(;
                id = "metric",
                quantity = quantity,
                physics = GeometryParameters(include_external = external),
                numerics,
                observable = KSliceSelection(
                    component = TensorComponent(ntuple(_->1, rank)...),
                    bands = quantity == "QMK" ? BandTargets([1]) : Subspace([1]),
                ),
            ),
        ],
    )
end

# Inspect actual numerical result rows, excluding textual headers.
function numerical_rows(path)
    rows = [
        parse.(Float64, split(line)) for
        line in eachline(path) if !isempty(strip(line)) && !startswith(strip(line), "#")
    ]
    return reduce(vcat, rows)
end

@testset "Geometry defaults, positive widths, and operator closure" begin
    orth, nonorth = finite_models()
    for model in (orth, nonorth), quantity in ("QMK", "QMDK", "QMQK", "QCSK")
        cfg=configuration(model; quantity)
        task=only(cfg.tasks)
        e=R.compile_task_config(cfg, task)
        @test e.denominator_regularization == 0.0
        @test !e.include_external
        @test !e.denominator_regularization_was_explicit
        demand=R.operator_demand_plan(R.normalize_task_specs(e), e)
        @test !demand.requires_full_projector_geometry
        @test !(C.REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR in demand.required_operators)
        @test R.task_parameter_summary(cfg, task).physics.include_external === false
    end
    for eta in (0.0, 0.001, 0.2)
        cfg=configuration(orth; eta)
        e=R.compile_task_config(cfg, only(cfg.tasks))
        @test e.denominator_regularization == eta
        @test e.denominator_regularization_was_explicit
    end
    for eta in (-1.0, NaN, Inf)
        cfg=configuration(orth; eta)
        @test_throws ArgumentError R.compile_task_config(cfg, only(cfg.tasks))
    end
    cfg=configuration(nonorth; external = true)
    @test_throws ArgumentError R.compile_task_config(cfg, only(cfg.tasks))
    for eta in (0.0, 0.001)
        request=(;
            id = "bcd",
            numerics = Numerics(denominator_regularization = eta),
            physics = GeometryParameters(),
        )
        @test R.resolved_numerical_values(request, :berry_curvature_dipole).denominator_regularization==eta
    end
    request=(;
        id = "bcd",
        numerics = Numerics(derivative_backend = :analytic, denominator_regularization = 0.001),
        physics = GeometryParameters(),
    )
    @test_throws ArgumentError R.resolved_numerical_values(request, :berry_curvature_dipole)
    @test_throws ArgumentError M.geometry_isolated_spectrum_minimum_gap([0.0, 0.0], 1e-10)
end

@testset "Public internal metric and derivatives need no external overlap" begin
    orth, nonorth = finite_models()
    eigenvectors=eigen(Hermitian(orth.model.hamiltonian_r[:, :, 1])).vectors
    connection=eigenvectors'*orth.model.position_r[:, :, 1, 1]*eigenvectors
    oracle=abs2(connection[1, 2])
    for (quantity, expected) in (("QMK", oracle), ("QMDK", 0.0), ("QMQK", 0.0), ("QCSK", 0.0))
        results = [WannierNLQG.run(configuration(model; quantity)) for model in (orth, nonorth)]
        for result in results
            @test length(result.outputs)==1
            @test isfile(only(result.outputs))
            row=numerical_rows(only(result.outputs))
            @test real(row[end]) ≈ expected atol=1e-10
            metadata=read(only(result.task_results).metadata_path, String)
            @test occursin("include_external", metadata)
            @test occursin("not_required", metadata)
        end
        @test numerical_rows(only(results[1].outputs)) ≈ numerical_rows(only(results[2].outputs)) atol=1e-10
    end
end

@testset "Mesh readers preserve declarations and reject false completeness" begin
    mktempdir() do directory
        kp=joinpath(directory, "KPOINTS")
        write(kp, "mesh\n0\nMonkhorst-Pack\n2 1 1\n0 0 0\n")
        mesh=WIO.read_vasp_kpoint_mesh(kp)
        @test mesh.dimensions==(2, 1, 1)
        @test mesh.offset==(-0.25, 0.0, 0.0)
        points=[0.25 0.0 0.0; 0.75 0.0 0.0]
        @test R._workflow_validate_mesh_declaration(mesh, (2, 1, 1), points)===nothing
        @test_throws ArgumentError R._workflow_validate_mesh_declaration(
            mesh,
            (2, 1, 1),
            [0.0 0.0 0.0; 0.5 0.0 0.0],
        )
        write(kp, "path\n20\nLine-mode\nreciprocal\n")
        @test_throws ArgumentError WIO.read_vasp_kpoint_mesh(kp)
        qe=joinpath(directory, "pw.in")
        write(qe, "&control\n/\nK_POINTS automatic\n2 1 1 1 0 0\n")
        mesh=WIO.read_qe_input_mesh(qe)
        @test mesh.dimensions==(2, 1, 1)
        @test mesh.offset==(0.25, 0.0, 0.0)
        save=joinpath(directory, "no-alat.save")
        mkpath(save)
        qe_xml=joinpath(save, "data-file-schema.xml")
        declaration_xml="""
        <qes:espresso xmlns:qes="http://www.quantum-espresso.org/ns/qes/qes-1.0">
          <input><k_points_IBZ><monkhorst_pack nk1="2" nk2="1" nk3="1" k1="1" k2="0" k3="0"/></k_points_IBZ></input>
          <output><atomic_structure><cell><a1>2 0 0</a1><a2>0 2 0</a2><a3>0 0 2</a3></cell><atomic_positions><atom name="Si">0 0 0</atom></atomic_positions></atomic_structure>
          <band_structure><ks_energies><k_point>0.25 0 0</k_point></ks_energies></band_structure></output>
        </qes:espresso>
        """
        write(qe_xml, declaration_xml)
        declaration=WIO.read_qe_mesh_declaration(qe_xml)
        @test declaration.dimensions==(2, 1, 1)
        @test declaration.offset==(0.25, 0.0, 0.0)
        @test declaration.points===nothing
        @test_throws ArgumentError WIO.read_qe_geometry_metadata(qe_xml)
        source=WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(save)
        native_metadata=(kpoints_fractional = points,)
        @test R._workflow_native_mesh(
            Dict(),
            source,
            native_metadata;
            base_dir = directory,
        )==((2, 1, 1), points)
        @test R._workflow_native_mesh(
            Dict("kmesh"=>Dict("dimensions"=>[2, 1, 1])),
            source,
            native_metadata;
            base_dir = directory,
        )==((2, 1, 1), points)
        @test_throws ArgumentError R._workflow_native_mesh(
            Dict("kmesh"=>Dict("dimensions"=>[1, 1, 1])),
            source,
            native_metadata;
            base_dir = directory,
        )
        @test_throws ArgumentError R._workflow_native_mesh(
            Dict(),
            source,
            (kpoints_fractional = [0.0 0 0; 0.5 0 0],);
            base_dir = directory,
        )
        write(qe_xml, replace(declaration_xml, "k1=\"1\""=>"k1=\"2\""))
        @test_throws ArgumentError WIO.read_qe_mesh_declaration(qe_xml)
        write(qe_xml, "<espresso/>")
        @test WIO.read_qe_mesh_declaration(qe_xml).dimensions===nothing
        @test R._workflow_native_mesh(
            Dict("kmesh"=>Dict("dimensions"=>[2, 1, 1])),
            source,
            native_metadata;
            base_dir = directory,
        )==((2, 1, 1), points)
        @test_throws ArgumentError R._workflow_native_mesh(
            Dict(),
            source,
            native_metadata;
            base_dir = directory,
        )
        xml=joinpath(directory, "vasprun.xml")
        write(
            xml,
            "<modeling><kpoints><generation param=\"Monkhorst-Pack\"><v name=\"divisions\">2 1 1</v><v name=\"usershift\">0 0 0</v></generation></kpoints></modeling>",
        )
        @test WIO.read_vasp_xml_mesh(xml).offset==(-0.25, 0.0, 0.0)
        structure=WannierNLQG.SymmetryFoundation.CrystalStructure(
            Matrix{Float64}(I, 3, 3),
            ["Si"],
            zeros(3, 1),
        )
        @test_throws ArgumentError WannierNLQG.Wannierization.WannierizationGeometry(
            structure,
            (2, 1, 1),
            points[1:1, :],
        )
        @test_throws ArgumentError WannierNLQG.Wannierization.WannierizationGeometry(
            structure,
            (2, 1, 1),
            repeat(points[1:1, :], 2, 1),
        )
    end
end
@testset "TOML effective settings, provenance, and explicit external admission" begin
    root=dirname(@__DIR__)
    document=Dict{String, Any}(
        "model"=>Dict(
            "source"=>"wannier",
            "model_file"=>joinpath(root, "examples/fixtures/synthetic_runtime/synthetic_tb.dat"),
        ),
        "response"=>Dict{String, Any}(
            "sampling"=>Dict(
                "kind"=>"k_slice",
                "k_mesh"=>[1, 1],
                "spatial_dimension"=>2,
                "origin"=>[0.0, 0.0, 0.0],
                "vector_1"=>[1.0, 0.0, 0.0],
                "vector_2"=>[0.0, 1.0, 0.0],
            ),
            "execution"=>Dict("fourier_backend"=>"direct"),
            "tasks"=>Dict(
                "metric"=>Dict{String, Any}(
                    "kind"=>"QMK",
                    "observable"=>Dict("kind"=>"band_targets", "component"=>[1, 1], "bands"=>[1]),
                ),
            ),
        ),
        "output"=>Dict("output_root"=>mktempdir(), "progress_enabled"=>false),
    )
    parsed=R.resolve_task_input(document)
    @test parsed.effective["response"]["tasks"]["metric"]["include_external"] === false
    @test parsed.effective["response"]["tasks"]["metric"]["numerics"]["denominator_regularization"] ==
          0.0
    @test parsed.provenance["response.tasks.metric.include_external"]["source"] == "DEFAULT"
    replay=R.resolve_task_input(parsed.effective)
    @test replay.metadata["task_metric_geometry_identity"] ==
          parsed.metadata["task_metric_geometry_identity"]
    @test R.compile_task_config(replay.config, only(replay.config.tasks)).include_external === false
    positive=deepcopy(document)
    positive["response"]["numerics"]=Dict("denominator_regularization"=>0.001)
    alternate=R.resolve_task_input(positive)
    @test alternate.metadata["task_metric_geometry_identity"] !=
          parsed.metadata["task_metric_geometry_identity"]
    @test alternate.provenance["response.tasks.metric.numerics.denominator_regularization"]["source"]=="USER"
    missing=deepcopy(document)
    missing["response"]["tasks"]["metric"]["include_external"]=true
    @test_throws ArgumentError R.resolve_task_input(missing)
    explicit=R.resolve_task_input(missing; check_paths = false)
    @test explicit.provenance["response.tasks.metric.include_external"]["origin"]=="response.tasks.metric.include_external"
    overridden=deepcopy(document)
    overridden["response"]["include_external"]=true
    overridden["response"]["tasks"]["metric"]["include_external"]=false
    @test !R.resolve_task_input(overridden).effective["response"]["tasks"]["metric"]["include_external"]
    malformed=deepcopy(document)
    malformed["response"]["tasks"]["metric"]["include_external"]="false"
    @test_throws ArgumentError R.resolve_task_input(malformed)
end

@testset "Native VASP discovery and external point-order validation" begin
    mktempdir() do directory
        wave=joinpath(directory, "WAVECAR")
        source=WannierNLQG.SymmetryFoundation.VASPWavefunctionSource(
            joinpath(directory, "POSCAR"),
            wave,
        )
        points=[0.5 0.0 0.0; 0.0 0.0 0.0]
        metadata=(; kpoints_fractional = points)
        kp=joinpath(directory, "KPOINTS")
        write(kp, "mesh\n0\nGamma\n2 1 1\n0 0 0\n")
        @test R._workflow_native_mesh(
            Dict(),
            source,
            metadata;
            base_dir = directory,
        )==((2, 1, 1), points)
        @test_throws ArgumentError R._workflow_native_mesh(
            Dict("kmesh"=>Dict("dimensions"=>[3, 1, 1])),
            source,
            metadata;
            base_dir = directory,
        )
        explicit=Dict(
            "kmesh"=>Dict(
                "dimensions"=>[2, 1, 1],
                "points_fractional"=>[[0.0, 0.0, 0.0], [0.5, 0.0, 0.0]],
            ),
        )
        @test_throws ArgumentError R._workflow_native_mesh(
            explicit,
            source,
            metadata;
            base_dir = directory,
        )
        explicit_dimensions=Dict("kmesh"=>Dict("dimensions"=>[2, 1, 1]))
        write(kp, "mesh\n0\nAutomatic\n20\n")
        @test_throws ArgumentError WIO.read_vasp_kpoint_mesh(kp)
        @test R._workflow_native_mesh(
            explicit_dimensions,
            source,
            metadata;
            base_dir = directory,
        )==((2, 1, 1), points)
        @test_throws ArgumentError R._workflow_native_mesh(
            Dict(),
            source,
            metadata;
            base_dir = directory,
        )
        write(kp, "mesh\n0\nAutomatic\n-1\n")
        @test_throws ArgumentError R._workflow_native_mesh(
            explicit_dimensions,
            source,
            metadata;
            base_dir = directory,
        )
        write(kp, "mesh\n0\nGamma\n0 1 1\n0 0 0\n")
        @test_throws ArgumentError R._workflow_native_mesh(
            explicit_dimensions,
            source,
            metadata;
            base_dir = directory,
        )
        write(kp, "mesh\n0\nGamma\n2 1 1\n0 0 0\n")
        xml=joinpath(directory, "vasprun.xml")
        write(
            xml,
            "<modeling><kpoints><generation param=\"Gamma\"><v name=\"divisions\">2 1 1</v></generation><varray name=\"kpointlist\"><v>0.5 0 0</v><v>0 0 0</v></varray></kpoints></modeling>",
        )
        data=WIO.read_vasp_xml_mesh(xml)
        @test data.points==points
        @test R._workflow_native_mesh(
            Dict(),
            source,
            metadata;
            base_dir = directory,
        )==((2, 1, 1), points)
        saved_points="<varray name=\"kpointlist\"><v>0.5 0 0</v><v>0 0 0</v></varray>"
        write(xml, "<modeling><kpoints>"*saved_points*"</kpoints></modeling>")
        @test_throws ArgumentError WIO.read_vasp_xml_mesh(xml)
        @test R._workflow_native_mesh(
            explicit_dimensions,
            source,
            metadata;
            base_dir = directory,
        )==((2, 1, 1), points)
        @test_throws ArgumentError R._workflow_native_mesh(
            Dict(),
            source,
            metadata;
            base_dir = directory,
        )
        write(
            xml,
            "<modeling><kpoints><generation param=\"Automatic\"/>"*saved_points*"</kpoints></modeling>",
        )
        @test R._workflow_native_mesh(
            explicit_dimensions,
            source,
            metadata;
            base_dir = directory,
        )==((2, 1, 1), points)
        @test_throws ArgumentError WIO.read_vasp_xml_mesh(xml)
        write(
            xml,
            "<modeling><kpoints><generation param=\"Gamma\"><v name=\"divisions\">2 1 1</v><v name=\"usershift\">0.5 0 0</v></generation>"*saved_points*"</kpoints></modeling>",
        )
        @test_throws ArgumentError R._workflow_native_mesh(
            explicit_dimensions,
            source,
            metadata;
            base_dir = directory,
        )
        write(
            xml,
            "<modeling><kpoints>"*replace(
                saved_points,
                "<v>0.5 0 0</v><v>0 0 0</v>"=>"<v>0 0 0</v><v>0.5 0 0</v>",
            )*"</kpoints></modeling>",
        )
        @test_throws ArgumentError R._workflow_native_mesh(
            explicit_dimensions,
            source,
            metadata;
            base_dir = directory,
        )
        write(
            xml,
            "<modeling><kpoints><generation param=\"Gamma\"><v name=\"divisions\">0 1 1</v></generation>"*saved_points*"</kpoints></modeling>",
        )
        @test_throws ArgumentError R._workflow_native_mesh(
            explicit_dimensions,
            source,
            metadata;
            base_dir = directory,
        )
    end
end

@testset "Zero geometry rejects unresolved eigenframes before publishing a result" begin
    orth, _ = finite_models()
    degenerate=RealSpaceTBInput(
        lattice = orth.model.lattice,
        r_vectors = orth.model.r_vectors,
        hamiltonian_r = reshape(Matrix{ComplexF64}(I, 2, 2), 2, 2, 1),
        orbital_positions = zeros(3, 2),
    )
    cfg=configuration(degenerate)
    error=try
        WannierNLQG.run(cfg)
        nothing
    catch exception
        exception
    end
    @test error !== nothing
    @test occursin("GEOMETRY_SINGLE_BAND_SPECTRUM_NOT_ISOLATED", sprint(showerror, error))
    @test isempty(
        filter(
            path->endswith(path, ".dat"),
            [
                joinpath(root, name) for (root, _, files) in walkdir(cfg.output.output_root) for
                name in files
            ],
        ),
    )
end

include("FrozenGramOperatorTestSupport.jl")

@testset "Internal metric keeps independent operator consumers intact" begin
    root=dirname(@__DIR__)
    model=ModelInput(
        model_file = joinpath(root, "examples/fixtures/synthetic_runtime/synthetic_tb.dat"),
    )
    template=configuration(model; eta = 0.001)
    metric=only(template.tasks)
    curvature=TaskSpec(
        id = "curvature",
        quantity = "berry_curvature",
        physics = GeometryParameters(),
        numerics = Numerics(denominator_regularization = 0.001),
        observable = KSliceSelection(component = TensorComponent(1, 2), bands = BandTargets([1])),
    )
    make_run(
        input,
        tasks,
    )=WannierNLQG.run(
        TaskConfig(
            model = input,
            sampling = template.sampling,
            execution = template.execution,
            output = OutputOptions(output_root = mktempdir(), progress_enabled = false),
            tasks = tasks,
        ),
    )
    metric_only=make_run(model, [metric])
    combined=make_run(model, [metric, curvature])
    @test length(combined.outputs)==2
    metric_name=basename(only(metric_only.outputs))
    @test read(
        only(path for path in combined.outputs if basename(path)==metric_name),
    )==read(only(metric_only.outputs))

    mktempdir() do directory
        fixture=frozen_gram_operator_fixture(joinpath(directory, "gram"))
        packed=ModelInput(real_space_operator_bundle_file = fixture.output)
        orbital=TaskSpec(
            id = "orbital",
            quantity = "orbital_magnetization",
            method = "Conventional",
            physics = OrbitalMagnetizationParameters(
                fermi_energies = Float64[0.13],
                temperature = 300.0,
                input_semantics = :direct_energy_overlap,
            ),
            numerics = Numerics(denominator_regularization = 0.001),
            observable = KSliceSelection(component = TensorComponent(3), bands = AllBands()),
        )
        metric_only=make_run(packed, [metric])
        orbital_only=make_run(packed, [orbital])
        together=make_run(packed, [metric, orbital])
        tables(result)=Dict(basename(path)=>read(path) for path in result.outputs)
        @test length(together.outputs)==length(metric_only.outputs)+length(orbital_only.outputs)
        @test tables(together)==merge(tables(metric_only), tables(orbital_only))
    end
end

end
