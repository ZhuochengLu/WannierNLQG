using Test

include(joinpath(@__DIR__, "..", "scripts", "ArchitectureContracts.jl"))
using .ArchitectureContracts

@testset "architecture gate rejects formerly invisible decay" begin
    duplicate_detector = Dict(
        "ext/WannierNLQGSymmetrizationExt/Duplicate.jl" => "using Spglib\nfunction detect_symmetry_operations(x)\nSpglib.get_dataset(x)\nend\n",
    )
    @test !isempty(production_spglib_violations(duplicate_detector))

    private_call = Dict(
        "src/Wannierization/Bad.jl" =>
            "import WannierNLQG.SymmetryFoundation: _hidden_contract\n" *
            "value = SymmetryFoundation._other_hidden_contract(x)\n",
    )
    @test length(private_shared_boundary_violations(private_call)) == 2

    private_matrix_elements_call = Dict(
        "ext/WannierNLQGSymmetrizationExt/Bad.jl" => "import WannierNLQG.MatrixElements: _private_helper\n",
    )
    @test length(private_module_boundary_violations(private_matrix_elements_call)) == 1

    facade = "module Wannierization\nexport Config, Result, run, accidental\nend\n"
    @test Set(exported_symbols(facade)) != Set((:Config, :Result, :run))

    documented = "src/SymmetryFoundation/SymmetryFoundation.jl\n"
    required = ("src/SymmetryFoundation/SymmetryFoundation.jl", "src/SymmetryFoundation/Missing.jl")
    @test missing_documented_paths(documented, required) == ["src/SymmetryFoundation/Missing.jl"]

    unallowlisted = Dict(
        "src/Wannierization/BadIntegration.jl" => "import WannierNLQG.SymmetryFoundation: undocumented_integration\n",
    )
    @test !isempty(
        shared_boundary_reference_violations(
            unallowlisted,
            Dict(
                "SymmetryFoundation" => Symbol[],
                "WannierProjection" => Symbol[],
                "MatrixElements" => Symbol[],
            ),
            Dict(
                "SymmetryFoundation" => Symbol[],
                "WannierProjection" => Symbol[],
                "MatrixElements" => Symbol[],
            ),
        ),
    )
end

@testset "Symmetrization extension exact dependency contract" begin
    expected_imports = Dict(
        "HDF5" => (module_binding = true, symbols = String[]),
        "WannierNLQG.Core" => (module_binding = false, symbols = ["RealSpaceOperator"]),
    )
    exact_source = "import HDF5\nimport WannierNLQG.Core: RealSpaceOperator\n"
    exact_imports = direct_import_records(exact_source)
    @test isempty(
        import_record_violations("Symmetrization imports", exact_imports, expected_imports),
    )

    added_provider = direct_import_records(exact_source * "import Printf\n")
    @test any(
        contains("unexpected Printf"),
        import_record_violations("Symmetrization imports", added_provider, expected_imports),
    )
    removed_provider = direct_import_records("import HDF5\n")
    @test any(
        contains("missing WannierNLQG.Core"),
        import_record_violations("Symmetrization imports", removed_provider, expected_imports),
    )
    broad_provider = direct_import_records("import HDF5\nusing WannierNLQG.Core\n")
    @test any(
        contains("module_binding expected false, got true"),
        import_record_violations("Symmetrization imports", broad_provider, expected_imports),
    )
    @test direct_using_providers("using WannierNLQG.Core\n") == ["WannierNLQG.Core"]

    added_symbol = direct_import_records(
        "import HDF5\nimport WannierNLQG.Core: RealSpaceOperator, accidental\n",
    )
    @test any(
        contains("unexpected accidental"),
        import_record_violations("Symmetrization imports", added_symbol, expected_imports),
    )
    removed_symbol = direct_import_records("import HDF5\nimport WannierNLQG.Core\n")
    @test any(
        contains("missing RealSpaceOperator"),
        import_record_violations("Symmetrization imports", removed_symbol, expected_imports),
    )

    @test !isempty(direct_import_records("import WannierNLQG.IO: read_wannier_tb\n"))
    @test !isempty(
        root_module_usage_violations(
            "value = WannierNLQG.IO.read_wannier_tb(path)\n";
            allowed_functions = ("pkgversion", "pkgdir"),
        ),
    )
    @test isempty(
        root_module_usage_violations(
            "root = pkgdir(WannierNLQG)\nversion = Base.pkgversion(WannierNLQG)\n";
            allowed_functions = ("pkgversion", "pkgdir"),
        ),
    )
    @test !isempty(
        private_module_boundary_violations(
            Dict(
                "ext/WannierNLQGSymmetrizationExt/Bad.jl" => "import WannierNLQG.MatrixElements: _private_helper\n",
            ),
        ),
    )

    expected_files = ["Root.jl", "components/ValidationComponent.jl"]
    @test any(
        contains("unexpected components/AccidentalComponent.jl"),
        exact_allowlist_violations(
            "Symmetrization files",
            [expected_files..., "components/AccidentalComponent.jl"],
            expected_files,
        ),
    )
    @test any(
        contains("missing components/ValidationComponent.jl"),
        exact_allowlist_violations("Symmetrization files", ["Root.jl"], expected_files),
    )

    expected_api = ["screen_wannier_mesh", "symmetrize_wannier_operators"]
    available_api = Set([expected_api..., "accidental"])
    @test any(
        contains("unexpected accidental"),
        integration_api_violations(
            "Symmetrization API",
            [expected_api..., "accidental"],
            expected_api,
            available_api,
        ),
    )
    @test any(
        contains("missing symmetrize_wannier_operators"),
        integration_api_violations(
            "Symmetrization API",
            ["screen_wannier_mesh"],
            expected_api,
            available_api,
        ),
    )
end

@testset "exact component contracts reject additions and removals" begin
    imports = direct_import_records(
        "import Provider\nimport Provider: exported\nimport ..Sibling: bridge\n",
    )
    @test imports["Provider"] == (module_binding = true, symbols = ["exported"])
    @test imports["Sibling"] == (module_binding = false, symbols = ["bridge"])
    expected_imports = Dict(
        "Provider" => (module_binding = true, symbols = ["exported"]),
        "Sibling" => (module_binding = false, symbols = ["bridge"]),
    )
    @test isempty(import_record_violations("imports", imports, expected_imports))
    @test any(
        value -> contains(value, "unexpected Extra"),
        import_record_violations(
            "imports",
            merge(imports, Dict("Extra" => (module_binding = true, symbols = String[]))),
            expected_imports,
        ),
    )
    @test any(
        value -> contains(value, "missing Sibling"),
        import_record_violations(
            "imports",
            Dict("Provider" => imports["Provider"]),
            expected_imports,
        ),
    )
    @test any(
        value -> contains(value, "module_binding expected true, got false"),
        import_record_violations(
            "imports",
            merge(imports, Dict("Provider" => (module_binding = false, symbols = ["exported"]))),
            expected_imports,
        ),
    )
    @test any(
        value -> contains(value, "unexpected accidental"),
        import_record_violations(
            "imports",
            merge(
                imports,
                Dict("Provider" => (module_binding = true, symbols = ["accidental", "exported"])),
            ),
            expected_imports,
        ),
    )
    @test any(
        value -> contains(value, "missing exported"),
        import_record_violations(
            "imports",
            merge(imports, Dict("Provider" => (module_binding = true, symbols = String[]))),
            expected_imports,
        ),
    )

    parent_catch_all = direct_import_records("using ..Sibling\n")
    @test any(
        value -> contains(value, "module_binding expected false, got true"),
        import_record_violations(
            "imports",
            parent_catch_all,
            Dict("Sibling" => (module_binding = false, symbols = String[])),
        ),
    )
    @test direct_using_providers("import HDF5\nusing ..Sibling: value\n") == ["Sibling"]

    @test isempty(root_module_usage_violations("value = Base.pkgversion(WannierNLQG)\n"))
    @test isempty(root_module_usage_violations("value = pkgversion(WannierNLQG)\n"))
    @test !isempty(root_module_usage_violations("value = WannierNLQG.IO.read_model(path)\n"))
    @test !isempty(root_module_usage_violations("value = identity(WannierNLQG)\n"))

    declared_io = ("WannierNLQG.IO",)
    @test isempty(
        root_module_usage_violations(
            "value = WannierNLQG.IO.read_model(path)\n";
            allowed_module_paths = declared_io,
        ),
    )
    for source in (
        "value = WannierNLQG.Core.other(path)\n",
        "value = WannierNLQG.IOExtra.other(path)\n",
        "value = WannierNLQG.IO.read_model(WannierNLQG)\n",
        "value = WannierNLQG.other(path)\n",
    )
        @test !isempty(root_module_usage_violations(source; allowed_module_paths = declared_io))
    end
    @test_throws ArgumentError root_module_usage_violations(
        "";
        allowed_module_paths = ("WannierNLQG",),
    )

    guard = "WannierNLQG.FIRST_USE_TRACE_COMPATIBLE"
    guarded_include = "if $guard\n    include(\"coverage.jl\")\nend\n"
    @test !isempty(root_module_usage_violations(guarded_include))
    @test isempty(root_module_usage_violations(guarded_include; allowed_guards = (guard,)))
    for source in (
        "value = $guard\n",
        "if WannierNLQG.OTHER_FLAG\n    include(\"coverage.jl\")\nend\n",
        "if $guard && true\n    include(\"coverage.jl\")\nend\n",
        "if $guard\n    WannierNLQG.IO.read_model(path)\nend\n",
        "if $guard\n    include(\"coverage.jl\")\nelse\n    identity(WannierNLQG)\nend\n",
    )
        @test !isempty(root_module_usage_violations(source; allowed_guards = (guard,)))
    end

    leaves = (:win_file, :outer_min_ev)
    @test isempty(
        typed_sawf_flat_config_reads(
            Dict("grouped.jl" => "f(config::W.WannierizationConfig) = config.input.win_file\n"),
            leaves,
        ),
    )
    @test !isempty(
        typed_sawf_flat_config_reads(
            Dict("qualified.jl" => "f(config::W.WannierizationConfig) = config.win_file\n"),
            leaves,
        ),
    )
    @test !isempty(
        typed_sawf_flat_config_reads(
            Dict(
                "alias.jl" =>
                    "const SAWConfig = W.WannierizationConfig\n" *
                    "function f(config::SAWConfig)\n local_config = config\n local_config.outer_min_ev\n end\n",
            ),
            leaves,
        ),
    )
    @test !isempty(
        typed_sawf_flat_config_reads(
            Dict("constructed.jl" => "config = W.WannierizationConfig()\nconfig.win_file\n"),
            leaves,
        ),
    )

    expected_dependencies = Set((:InternalSupport, :RepresentationPreparation))
    @test isempty(
        exact_allowlist_violations(
            "ProjectionSearch dependencies",
            copy(expected_dependencies),
            expected_dependencies,
        ),
    )
    @test any(
        value -> occursin("unexpected WorkflowOrchestration", value),
        exact_allowlist_violations(
            "ProjectionSearch dependencies",
            union(expected_dependencies, Set((:WorkflowOrchestration,))),
            expected_dependencies,
        ),
    )
    @test any(
        value -> occursin("missing RepresentationPreparation", value),
        exact_allowlist_violations(
            "ProjectionSearch dependencies",
            Set((:InternalSupport,)),
            expected_dependencies,
        ),
    )

    expected_files = Dict(:ProjectionSearch => ["Search.jl", "Persistence.jl"])
    @test isempty(component_file_ownership_violations(expected_files, expected_files))
    @test !isempty(
        component_file_ownership_violations(
            Dict(:ProjectionSearch => ["Search.jl"]),
            expected_files,
        ),
    )
    @test !isempty(
        component_file_ownership_violations(
            Dict(
                :ProjectionSearch => ["Search.jl", "Persistence.jl"],
                :OperatorExport => ["Persistence.jl"],
            ),
            merge(expected_files, Dict(:OperatorExport => String[])),
        ),
    )

    acyclic = Dict(:A => Set{Symbol}(), :B => Set((:A,)), :C => Set((:B,)))
    @test isempty(dependency_cycle_violations(acyclic))
    cyclic = merge(acyclic, Dict(:A => Set((:C,))))
    @test !isempty(dependency_cycle_violations(cyclic))
    include_cycle = Dict("Root.jl" => Set(("Child.jl",)), "Child.jl" => Set(("Root.jl",)))
    @test !isempty(dependency_cycle_violations(include_cycle))

    clean_sources = Dict(
        :RepresentationPreparation => "function _prepare(x)\n x\nend\nprepare = _prepare\n",
        :ProjectionSearch => "value = prepare(input)\n",
    )
    @test isempty(component_private_reference_violations(clean_sources))
    bad_sources = merge(clean_sources, Dict(:ProjectionSearch => "value = _prepare(input)\n"))
    @test !isempty(component_private_reference_violations(bad_sources))

    @test isempty(component_qualified_reference_violations(clean_sources))
    qualified_sources = merge(
        clean_sources,
        Dict(:ProjectionSearch => "value = RepresentationPreparation.prepare(input)\n"),
    )
    @test component_qualified_reference_violations(qualified_sources) ==
          ["ProjectionSearch qualifies RepresentationPreparation.prepare"]

    @test relative_module_dependencies(
        "module X\nusing ..InternalSupport\nimport ..RepresentationPreparation: build\nend\n",
    ) == [:InternalSupport, :RepresentationPreparation]

    expected_api = ["build", "read"]
    available_api = Set(("build", "read", "helper"))
    @test isempty(integration_api_violations("api", expected_api, expected_api, available_api))
    @test any(
        contains("unexpected helper"),
        integration_api_violations("api", [expected_api..., "helper"], expected_api, available_api),
    )
    @test any(
        contains("missing read"),
        integration_api_violations("api", ["build"], expected_api, available_api),
    )
    @test any(
        contains("duplicate entries"),
        integration_api_violations("api", ["build", "read", "read"], expected_api, available_api),
    )
    @test any(
        contains("undefined missing_definition"),
        integration_api_violations(
            "api",
            ["build", "read", "missing_definition"],
            ["build", "read", "missing_definition"],
            available_api,
        ),
    )

    expected_test_api = ["_build", "_read"]
    available_test_api = Set(("_build", "_read", "_helper", "public_name"))
    @test isempty(
        test_api_violations("test api", expected_test_api, expected_test_api, available_test_api),
    )
    @test any(
        contains("unexpected _helper"),
        test_api_violations(
            "test api",
            [expected_test_api..., "_helper"],
            expected_test_api,
            available_test_api,
        ),
    )
    @test any(
        contains("missing _read"),
        test_api_violations("test api", ["_build"], expected_test_api, available_test_api),
    )
    @test any(
        contains("duplicate entries"),
        test_api_violations(
            "test api",
            ["_build", "_read", "_read"],
            expected_test_api,
            available_test_api,
        ),
    )
    @test any(
        contains("undefined _missing"),
        test_api_violations(
            "test api",
            ["_build", "_read", "_missing"],
            ["_build", "_read", "_missing"],
            available_test_api,
        ),
    )
    @test any(
        contains("non-private public_name"),
        test_api_violations("test api", ["public_name"], ["public_name"], available_test_api),
    )

    expected_owners = Dict(:build => :Builder, :read => :Reader)
    @test isempty(entrypoint_owner_violations("facade", expected_owners, expected_owners))
    @test any(
        contains("expected owner Reader, got Builder"),
        entrypoint_owner_violations(
            "facade",
            Dict(:build => :Builder, :read => :Builder),
            expected_owners,
        ),
    )
    @test any(
        contains("unexpected accidental"),
        entrypoint_owner_violations(
            "facade",
            merge(expected_owners, Dict(:accidental => :Builder)),
            expected_owners,
        ),
    )

    ownership_source = """
    const ENTRYPOINT_OWNERS = Dict{Symbol, Module}(
        :build => Builder,
    )
    const TEST_ENTRYPOINT_OWNERS = Dict{Symbol, Module}(
        :_read => Reader,
    )
    """
    @test entrypoint_owner_map(ownership_source) == Dict(:build => :Builder)
    @test entrypoint_owner_map(ownership_source, "TEST_ENTRYPOINT_OWNERS") ==
          Dict(:_read => :Reader)
    @test_throws ArgumentError entrypoint_owner_map(ownership_source, "bad-name")

    bridge_source = """
    public_call(x) = _call_wannierization_extension(:build, x)
    private_call(x) = _call_wannierization_extension(
        :_read,
        x,
    )
    """
    bridge_symbols = wannierization_bridge_symbols(bridge_source)
    @test bridge_symbols == [:_read, :build]
    public_owners = Dict(:build => :Builder)
    test_owners = Dict(:_read => :Reader)
    @test isempty(bridge_ownership_violations("bridge", bridge_symbols, public_owners, test_owners))
    @test any(
        contains("unowned public bridge build"),
        bridge_ownership_violations("bridge", bridge_symbols, Dict{Symbol, Symbol}(), test_owners),
    )
    @test any(
        contains("missing _read"),
        bridge_ownership_violations(
            "bridge",
            bridge_symbols,
            public_owners,
            Dict{Symbol, Symbol}(),
        ),
    )
    @test any(
        contains("unexpected _extra"),
        bridge_ownership_violations(
            "bridge",
            bridge_symbols,
            public_owners,
            merge(test_owners, Dict(:_extra => :Reader)),
        ),
    )
    @test any(
        contains("private bridge _read in public map"),
        bridge_ownership_violations(
            "bridge",
            bridge_symbols,
            merge(public_owners, Dict(:_read => :Builder)),
            test_owners,
        ),
    )
    @test any(
        contains("expected owner Reader, got Builder"),
        entrypoint_owner_violations(
            "test bridge",
            Dict(:_read => :Builder),
            Dict(:_read => :Reader),
        ),
    )
end

@testset "architecture gate rejects final boundary regressions" begin
    semantic_duplicate = Dict(
        "src/Wannierization/LegacyModels.jl" => "struct LegacyBandRepresentation\nvalue::Int\nend\n",
    )
    @test !isempty(semantic_duplicate_type_violations(semantic_duplicate))

    private_wannierization_call = Dict(
        "ext/WannierNLQGOperatorBundleExt/Bad.jl" => "value = Wannierization._hidden_authority_contract(x)\n",
    )
    @test !isempty(private_module_boundary_violations(private_wannierization_call))

    public = Dict("Foundation" => [:shared], "Projection" => Symbol[])
    mixed = Dict("Foundation" => [:shared, :_private], "Projection" => [:shared])
    violations = integration_allowlist_violations(public, mixed)
    @test any(value -> occursin("public and integration", value), violations)
    @test any(value -> occursin("private integration name", value), violations)
    @test any(value -> occursin("mixed across", value), violations)
end

@testset "architecture scanner ignores comments and provenance strings" begin
    source = "# Spglib.get_dataset(x)\nlabel = \"SymmetryFoundation._legacy_name\"\n"
    inputs = Dict("src/Wannierization/AllowedText.jl" => source)
    @test isempty(production_spglib_violations(inputs))
    @test isempty(private_shared_boundary_violations(inputs))
end

@testset "aliased imports retain their source contract" begin
    records = direct_import_records("import Library: load as local_load, save\n")
    @test records["Library"].symbols == ["load", "save"]
end

@testset "compiler Type operands preserve runtime owner boundaries" begin
    public_symbols = Dict("SymmetryFoundation" => Symbol[], "WannierProjection" => Symbol[])
    integration = Dict("SymmetryFoundation" => Symbol[], "WannierProjection" => Symbol[])
    verified = Dict("SymmetryFoundation" => Set([:IndexedPlaneWavePoints, Symbol("#3#4")]))
    function violations(source)
        shared_boundary_reference_violations(
            Dict("ext/CompilerFixture/Requests.jl" => source),
            public_symbols,
            integration;
            compiler_type_symbols = verified,
        )
    end
    literal = "@compile_workload begin\n_record_precompile(Tuple{Array{SymmetryFoundation.IndexedPlaneWavePoints, 1}, SymmetryFoundation.var\"#3#4\"})\nend\n"
    @test isempty(violations(literal))
    @test !isempty(
        shared_boundary_reference_violations(
            Dict("ext/CompilerFixture/Requests.jl" => literal),
            public_symbols,
            integration,
        ),
    )
    for source in (
        "value = SymmetryFoundation.IndexedPlaneWavePoints()\n",
        "@compile_workload begin\nlet SymmetryFoundation = unverified_provider\n_record_precompile(Tuple{SymmetryFoundation.IndexedPlaneWavePoints})\nend\nend\n",
        "value = SymmetryFoundation.var\"#3#4\"()\n",
        "import WannierNLQG.SymmetryFoundation: IndexedPlaneWavePoints\n",
        "import WannierNLQG.SymmetryFoundation: _hidden\n",
        "@compile_workload begin\n_record_unknown(Tuple{SymmetryFoundation.IndexedPlaneWavePoints})\nend\n",
        "_record_precompile(Tuple{SymmetryFoundation.IndexedPlaneWavePoints})\n",
        "@compile_workload begin\n_record_precompile(Tuple{typeof(SymmetryFoundation.IndexedPlaneWavePoints())})\nend\n",
        "@compile_workload begin\n_record_precompile(Tuple{identity(SymmetryFoundation.IndexedPlaneWavePoints)})\nend\n",
        "@compile_workload begin\n_record_precompile(Tuple{typeof(SymmetryFoundation._hidden)})\nend\n",
        "@compile_workload begin\n_record_precompile(Tuple{SymmetryFoundation.UnverifiedType})\nend\n",
        "@compile_workload begin\nfunction escaped()\n_record_precompile(Tuple{SymmetryFoundation.IndexedPlaneWavePoints})\nend\nend\n",
    )
        @test !isempty(violations(source))
    end
end

@testset "captured compiler types stay confined to their verified source" begin
    path = "ext/CompilerFixture/Guarded.jl"
    other = "ext/CompilerFixture/Other.jl"
    symbols = Dict("SymmetryFoundation" => Symbol[], "WannierProjection" => Symbol[])
    verified = Dict("SymmetryFoundation" => Set([Symbol("#3#4")]))
    literal = "@compile_workload begin\n_record_precompile(Tuple{SymmetryFoundation.var\"#3#4\"})\nend\n"
    check(sources) = shared_boundary_reference_violations(
        sources,
        symbols,
        symbols;
        compiler_type_symbols_by_source = Dict(path => verified),
    )
    @test isempty(check(Dict(path => literal)))
    @test !isempty(check(Dict(other => literal)))
    @test !isempty(check(Dict(path => "value = SymmetryFoundation.var\"#3#4\"()\n")))
    @test !isempty(check(Dict(path => "import WannierNLQG.SymmetryFoundation: var\"#3#4\"\n")))
    @test !isempty(check(Dict(path => replace(literal, "#3#4" => "#5#6"))))
end

@testset "intact import syntax preserves pairs and adjoints" begin
    source = """
    module Owner
    import HDF5
    const metadata = Dict("key" => "import Pretend")
    const transpose = vector'
    # using CommentOnly
    import ..Sibling: value
    using LinearAlgebra
    end
    """
    expected = Dict(
        "HDF5" => (module_binding = true, symbols = String[]),
        "Sibling" => (module_binding = false, symbols = ["value"]),
        "LinearAlgebra" => (module_binding = true, symbols = String[]),
    )
    @test direct_import_records(source) == expected
    @test direct_using_providers(source) == ["LinearAlgebra"]
    @test isempty(direct_import_records("\"import Pretend\"\n# import CommentOnly\n"))
    @test isempty(direct_using_providers("\"using Pretend\"\n# using CommentOnly\n"))
    @test_throws ArgumentError direct_import_records("module Incomplete\nimport HDF5\n")
    @test_throws ArgumentError direct_using_providers("module Incomplete\nusing HDF5\n")
end

@testset "independent boundary errors are reported together" begin
    sources=Dict(
        "src/Runtime/BoundaryProbe.jl"=>"Wannierization._hidden(x)\nSymmetryFoundation._hidden(x)\nSpglib.get_dataset(x)\nstruct LegacyBandRepresentation\nvalue::Int\nend\n",
    )
    errors=independent_architecture_boundary_violations(
        sources,
        sources,
        Set([:win_file]),
        Set(["test/expected_negative.jl: ordinary_default.win_file"]),
    )
    for category in (
        "typed SAWF top-level leaf reads",
        "Spglib ownership violations remain",
        "shared-layer private references remain",
        "production module-private cross-owner references remain",
        "semantic duplicate types remain",
    )
        @test any(message->startswith(message, category*": "), errors)
    end
    @test isempty(
        independent_architecture_boundary_violations(
            Dict{String, String}(),
            Dict{String, String}(),
            Set{Symbol}(),
            Set{String}(),
        ),
    )
end

@testset "Julia AST and mixed-language lexical boundaries stay separate" begin
    mixed=Dict(
        "scripts/python_probe.py"=>"import json\nvalue = {'enabled': True}\nSymmetryFoundation._hidden(value)\n",
        "src/Runtime/JuliaProbe.jl"=>"value = SymmetryFoundation.hidden(x)\n",
    )
    selected=julia_boundary_source_inventory(mixed)
    @test Set(keys(selected))==Set(["src/Runtime/JuliaProbe.jl"])
    public=Dict("SymmetryFoundation"=>Symbol[], "WannierProjection"=>Symbol[])
    integration=Dict("SymmetryFoundation"=>Symbol[], "WannierProjection"=>Symbol[])
    violations=shared_boundary_reference_violations(selected, public, integration)
    @test any(
        message->occursin("SymmetryFoundation.hidden is neither public nor allowlisted", message),
        violations,
    )
    @test any(
        message->occursin("scripts/python_probe.py", message),
        private_shared_boundary_violations(mixed),
    )
    malformed=Dict("src/Runtime/Invalid.jl"=>"function broken(\n")
    @test_throws ArgumentError shared_boundary_reference_violations(
        julia_boundary_source_inventory(malformed),
        public,
        integration,
    )
    @test_throws ArgumentError direct_import_records(mixed["scripts/python_probe.py"])
end

@testset "test imports require direct Pkg.test dependencies" begin
    sources = Dict(
        "first.jl" => "using Test, LinearAlgebra\nimport ESKernel\n",
        "second.jl" => "import MissingProvider: value\nusing ..LocalFixture\nusing Base.Threads\n",
        "literals.jl" => "# import CommentOnly\n\"import StringOnly\"\nraw\"\"\"import PythonOnly\"\"\"\n",
    )
    errors = test_dependency_violations(sources, ["Test", "LinearAlgebra"])
    @test errors == [
        "first.jl imports undeclared test dependency ESKernel",
        "second.jl imports undeclared test dependency MissingProvider",
    ]
    @test isempty(
        test_dependency_violations(
            sources,
            ["Test", "LinearAlgebra", "ESKernel", "MissingProvider"],
        ),
    )
    @test test_dependency_violations(Dict("alias.jl" => "import ESKernel as Kernel\n"), String[]) ==
          ["alias.jl imports undeclared test dependency ESKernel"]
    @test_throws ArgumentError test_dependency_violations(
        Dict("bad.jl" => "module Incomplete\n"),
        String[],
    )
end
