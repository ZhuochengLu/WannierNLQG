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

    leaves = (:win_file, :outer_min_ev)
    @test isempty(
        typed_sawf_flat_config_reads(
            Dict(
                "grouped.jl" => "f(config::W.SymmetryAdaptedWannierizationConfig) = config.input.win_file\n",
            ),
            leaves,
        ),
    )
    @test !isempty(
        typed_sawf_flat_config_reads(
            Dict(
                "qualified.jl" => "f(config::W.SymmetryAdaptedWannierizationConfig) = config.win_file\n",
            ),
            leaves,
        ),
    )
    @test !isempty(
        typed_sawf_flat_config_reads(
            Dict(
                "alias.jl" =>
                    "const SAWConfig = W.SymmetryAdaptedWannierizationConfig\n" *
                    "function f(config::SAWConfig)\n local_config = config\n local_config.outer_min_ev\n end\n",
            ),
            leaves,
        ),
    )
    @test !isempty(
        typed_sawf_flat_config_reads(
            Dict(
                "constructed.jl" => "config = W.SymmetryAdaptedWannierizationConfig()\nconfig.win_file\n",
            ),
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
