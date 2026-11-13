module WorkflowTaskInputUnit
using Test, WannierNLQG, LinearAlgebra, SHA, TOML
const R=WannierNLQG.Runtime
const out=mktempdir(; prefix = "wn-current-workflows-")
const spec=Dict("source"=>dirname(@__DIR__), "output"=>out)
# Current consumers replace obsolete nested-TOML/custom-optimizer execution;
# original assertions and input syntax remain archived, not passed or discarded.
include("WannierWorkflowDataRequirementsTests.jl")
include("DiagonalMeshScreeningTests.jl")
include("NativeGeometryMetadataTests.jl")
include("NormalizedWannierWorkflowTests.jl")
include("CurrentProjectionWorkflowTests.jl")
include("UnifiedTextInputChecks.jl")
@testset "Current source adapters retain physical metadata" begin
    source=R._workflow_input_source(
        Dict(
            "kind"=>"vasp",
            "poscar_file"=>"POSCAR",
            "wavecar_file"=>"WAVECAR",
            "magnetic_moments_cartesian"=>[[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]],
        ),
        "source",
        out,
    )
    @test source.magnetic_moments_cartesian==[1.0 4.0; 2.0 5.0; 3.0 6.0]
    @test R._workflow_input_source(
        Dict("kind"=>"qe", "save_directory"=>"seed.save", "spin_channel"=>"none"),
        "source",
        out,
    ).save_directory==joinpath(out, "seed.save")
    @test_throws ArgumentError R._workflow_input_source(
        Dict("kind"=>"vasp", "save_directory"=>"bad"),
        "source",
        out,
    )
    # The old nested schema is not automatically accepted by the current reader.
    @test_throws ArgumentError R.resolve_workflow_input(
        Dict("workflow"=>"wannierization", "wannierization"=>Dict());
        base_dir = out,
        check_paths = false,
    )
end
end
