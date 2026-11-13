using Test, WannierNLQG, JSON3

isdefined(@__MODULE__, :spectral_test_model) ||
    include(joinpath(@__DIR__, "SpectralResponseTestSupport.jl"))
isdefined(@__MODULE__, :ots_fixture) ||
    include(joinpath(@__DIR__, "OperatorTaskSelectionTestSupport.jl"))

isdefined(@__MODULE__, :frozen_gram_operator_fixture) ||
    include(joinpath(@__DIR__, "FrozenGramOperatorTestSupport.jl"))

const FV_MUS = Float64[-0.10, 0.01, 0.20]
const FV_RATES = SeparateRelaxation(gamma_intra_ev = 0.04, gamma_inter_ev = 0.05)
const FV_BASELINE = JSON3.read(
    read(joinpath(@__DIR__, "fixtures", "scalar_linear_oam_baseline.json"), String),
    Dict{String, Any},
)

function fv_legacy_values(section, path, count)
    row = only(FV_BASELINE[section]["outputs"][path]["rows"])
    length(row) == 2count || error("legacy baseline shape mismatch: $path")
    return ComplexF64[row[2index - 1] + im * row[2index] for index in 1:count]
end

function fv_numerics(temperature; denominator_regularization = nothing)
    values=temperature == 0.0 ? (; fs_kind = :gaussian, eta_fs_ev = 0.02, gap_tolerance = 1.0e-10) :
           (;)
    if denominator_regularization === nothing
        return temperature == 0.0 ? Numerics(; values...) : nothing
    end
    return Numerics(; values..., denominator_regularization)
end

function fv_config(
    model,
    output,
    method,
    temperature;
    material = false,
    mus = FV_MUS,
    output_digits = 17,
    denominator_regularization = nothing,
)
    tasks = TaskSpec[]
    material || push!(
        tasks,
        TaskSpec(
            id = "lt",
            quantity = "linear_transport",
            method = method,
            physics = LinearTransportParameters(
                fermi_energies = mus,
                temperature = temperature,
                relaxation = FV_RATES,
            ),
            numerics = fv_numerics(temperature; denominator_regularization),
            observable = FullTensor(),
        ),
    )
    push!(
        tasks,
        TaskSpec(
            id = "oam",
            quantity = "orbital_magnetization",
            method = method,
            physics = OrbitalMagnetizationParameters(
                fermi_energies = mus,
                temperature = temperature,
                input_semantics = material ? :direct_energy_overlap : :defined_finite_model,
            ),
            numerics = denominator_regularization === nothing ? nothing :
                       Numerics(; denominator_regularization),
            observable = FullTensor(),
        ),
    )
    input =
        material ? ModelInput(real_space_operator_bundle_file = model) :
        ModelInput(model_file = model)
    return TaskConfig(
        model = input,
        sampling = BZMesh(k_mesh = (2, 2, 2)),
        execution = ExecutionOptions(fourier_backend = "Direct"),
        output = OutputOptions(
            output_root = output,
            progress_enabled = false,
            response_output_digits = output_digits,
        ),
        tasks = tasks,
    )
end

@testset "Canonical Fermi-energy vector contract" begin
    source = Float64[-0.2, 0.0, 0.4]
    transport = LinearTransportParameters(
        fermi_energies = source,
        temperature = 300.0,
        relaxation = FV_RATES,
    )
    orbital = OrbitalMagnetizationParameters(
        fermi_energies = source,
        temperature = 300.0,
        input_semantics = :defined_finite_model,
    )
    source[1] = -9.0
    @test transport.fermi_energies == [-0.2, 0.0, 0.4]
    @test orbital.fermi_energies == [-0.2, 0.0, 0.4]
    @test WannierNLQG.Core.fermi_energy_axis_definition(transport.fermi_energies) ==
          WannierNLQG.Core.fermi_energy_axis_definition(orbital.fermi_energies)
    for invalid in (Float64[], Float64[NaN], Float64[Inf], Float64[0.0, 0.0], Float64[0.1, 0.0])
        @test_throws ArgumentError LinearTransportParameters(
            fermi_energies = invalid,
            temperature = 300.0,
            relaxation = FV_RATES,
        )
        @test_throws ArgumentError OrbitalMagnetizationParameters(
            fermi_energies = invalid,
            temperature = 300.0,
            input_semantics = :defined_finite_model,
        )
    end
    @test_throws TypeError LinearTransportParameters(
        fermi_energies = [0, 1],
        temperature = 300.0,
        relaxation = FV_RATES,
    )
    @test_throws TypeError OrbitalMagnetizationParameters(
        fermi_energies = (-0.1, 0.2),
        temperature = 300.0,
        input_semantics = :defined_finite_model,
    )
    @test_throws UndefKeywordError LinearTransportParameters(
        fermi_energy = 0.0,
        temperature = 300.0,
        relaxation = FV_RATES,
    )
    @test_throws UndefKeywordError OrbitalMagnetizationParameters(
        fermi_energy = 0.0,
        temperature = 300.0,
        input_semantics = :defined_finite_model,
    )
end

@testset "Vector kernels agree with frozen scalar formal-tree baselines" begin
    root = mktempdir()
    model = joinpath(root, "model.dat")
    WannierNLQG.IO.write_wannier_tb(model, spectral_test_model())
    fixture = frozen_gram_operator_fixture(joinpath(root, "material-fixture"))
    # The historical scalar record uses unregularized spectral geometry.
    # Only the finite-model comparison approaches that limit with a positive
    # eta; material-reference/default/storage tests retain their original inputs.
    reference_eta=1.0e-7
    for method in ("Conventional", "Projector"), temperature in (0.0, 300.0)
        method_key = lowercase(method)
        temperature_key = Int(temperature)
        output = joinpath(root, "finite-$(method_key)-$(temperature_key)")
        WannierNLQG.run(
            fv_config(
                model,
                output,
                method,
                temperature;
                denominator_regularization = reference_eta,
            ),
        )
        transport = read_linear_transport_result(joinpath(output, "lt"))
        orbital = read_orbital_magnetization_result(joinpath(output, "oam"))
        @test transport.fermi_energies == FV_MUS
        @test orbital.fermi_energies == FV_MUS
        for (mu_index, _) in enumerate(FV_MUS), term in keys(transport.tensors)
            prefix = "linear_transport_$(method_key)_T$(temperature_key)_mu$(mu_index)/linear_transport_"
            expected = if term == :berry_curvature
                fv_legacy_values("finite_model", prefix * "contact.dat", 9) +
                fv_legacy_values("finite_model", prefix * "hall_interband.dat", 9)
            else
                legacy_term = term == :quantum_metric ? "metric" : string(term)
                fv_legacy_values("finite_model", prefix * legacy_term * ".dat", 9)
            end
            actual = ComplexF64[transport.tensors[term][mu_index, a, b] for a in 1:3 for b in 1:3]
            @test isapprox(actual, expected; atol = 1e-20, rtol = 2e-12)
        end
        for (mu_index, _) in enumerate(FV_MUS), term in keys(orbital.vectors)
            path = "orbital_magnetization_$(method_key)_T$(temperature_key)_mu$(mu_index)/orbital_magnetization_$(term).dat"
            expected = fv_legacy_values("finite_model", path, 3)
            @test isapprox(orbital.vectors[term][mu_index, :], expected; atol = 1e-20, rtol = 2e-12)
        end

        material_output = joinpath(root, "material-$(method_key)-$(temperature_key)")
        WannierNLQG.run(
            fv_config(fixture.output, material_output, method, temperature; material = true),
        )
        material = read_orbital_magnetization_result(joinpath(material_output, "oam"))
        @test occursin(
            "orbital_completion_evaluations = 8",
            read(joinpath(material_output, "oam", "spectral_response_metadata.txt"), String),
        )
        @test occursin("hamiltonian", material.metadata["operator_inventory"])
        # This oracle supplies mathematical operators, not a source certificate.
        oracle_manifest = WannierNLQG.IO.read_real_space_operator_bundle_manifest(fixture.output)
        @test oracle_manifest.schema_version == "3.0"
        @test oracle_manifest.operator_qualification["mathematical_definitions"]["source"] ==
              "synthetic_frozen_Gram_energy_numerical_oracle"
        for (mu_index, _) in enumerate(FV_MUS), term in keys(material.vectors)
            path = "orbital_magnetization_$(method_key)_T$(temperature_key)_mu$(mu_index)/orbital_magnetization_$(term).dat"
            expected = fv_legacy_values("five_operator", path, 3)
            @test isapprox(
                material.vectors[term][mu_index, :],
                expected;
                atol = 1e-20,
                rtol = 2e-12,
            )
        end
    end
end

@testset "Mu-independent execution counts and storage ownership" begin
    root = mktempdir()
    model = joinpath(root, "model.dat")
    WannierNLQG.IO.write_wannier_tb(model, spectral_test_model())
    single = WannierNLQG.run(
        fv_config(model, joinpath(root, "single"), "Conventional", 300.0; mus = Float64[0.01]),
    )
    vector = WannierNLQG.run(fv_config(model, joinpath(root, "vector"), "Conventional", 300.0))
    @test single.sharing.model_loads == vector.sharing.model_loads == 1
    @test single.sharing.workers == vector.sharing.workers == Threads.nthreads()
    @test single.sharing.worker_statistics == vector.sharing.worker_statistics
    for task in ("lt", "oam")
        metadata = read(joinpath(root, "vector", task, "spectral_response_metadata.txt"), String)
        @test occursin("chemical_potential_count = 3", metadata)
        @test occursin("mu_independent_geometry_evaluations = 8", metadata)
        @test occursin("matrix_workspace_count_per_rank = $(Threads.nthreads())", metadata)
    end
    oam_metadata = read(joinpath(root, "vector", "oam", "spectral_response_metadata.txt"), String)
    @test occursin("orbital_completion_evaluations = 0", oam_metadata)
end

@testset "KSlice single-mu contract and strict vector readback" begin
    root = mktempdir()
    model = joinpath(root, "model.dat")
    WannierNLQG.IO.write_wannier_tb(model, spectral_test_model())
    slice = KSlice(
        k_mesh = (2, 2),
        spatial_dimension = 3,
        origin = (0.0, 0.0, 0.0),
        vector_1 = (1.0, 0.0, 0.0),
        vector_2 = (0.0, 1.0, 0.0),
    )
    function slice_cfg(quantity, physics)
        return TaskConfig(
            model = ModelInput(model_file = model),
            sampling = slice,
            execution = ExecutionOptions(fourier_backend = "Direct"),
            tasks = [
                TaskSpec(
                    id = "slice",
                    quantity = quantity,
                    method = "Conventional",
                    physics = physics,
                    observable = KSliceSelection(
                        component = quantity == "orbital_magnetization" ? TensorComponent(3) :
                                    TensorComponent(1, 2),
                        bands = AllBands(),
                    ),
                ),
            ],
        )
    end
    for (quantity, physics, code) in (
        (
            "linear_transport",
            LinearTransportParameters(
                fermi_energies = Float64[-0.1, 0.2],
                temperature = 300.0,
                relaxation = FV_RATES,
            ),
            "LINEAR_TRANSPORT_KSLICE_REQUIRES_SINGLE_FERMI_ENERGY",
        ),
        (
            "orbital_magnetization",
            OrbitalMagnetizationParameters(
                fermi_energies = Float64[-0.1, 0.2],
                temperature = 300.0,
                input_semantics = :defined_finite_model,
            ),
            "ORBITAL_MAGNETIZATION_KSLICE_REQUIRES_SINGLE_FERMI_ENERGY",
        ),
    )
        exception = try
            WannierNLQG.Runtime.compile_task_configs(slice_cfg(quantity, physics))
            nothing
        catch error
            error
        end
        @test exception isa ArgumentError
        @test occursin(code, sprint(showerror, exception))
    end

    output = joinpath(root, "readback")
    WannierNLQG.run(fv_config(model, output, "Conventional", 300.0))
    clean = joinpath(output, "lt")
    clean_result = read_linear_transport_result(clean)
    @test clean_result.fermi_energies == FV_MUS
    fe_axis = Float64[5.7156 + offset / 100 for offset in -50:2:50]
    fe_axis_output = joinpath(root, "fe-axis-readback")
    WannierNLQG.run(
        fv_config(model, fe_axis_output, "Conventional", 0.0; mus = fe_axis, output_digits = 14),
    )
    @test read_linear_transport_result(joinpath(fe_axis_output, "lt")).fermi_energies == fe_axis
    @test read_orbital_magnetization_result(joinpath(fe_axis_output, "oam")).fermi_energies ==
          fe_axis
    project = dirname(@__DIR__)
    probe = joinpath(@__DIR__, "FermiVectorReadbackProbe.jl")
    for (quantity, directory) in
        (("linear_transport", clean), ("orbital_magnetization", joinpath(output, "oam")))
        command =
            `$(Base.julia_cmd()) --startup-file=no --project=$project $probe $quantity $directory $(clean_result.metadata["fermi_energies_definition"])`
        @test success(pipeline(command; stdout = devnull, stderr = stderr))
    end
    tamper = joinpath(root, "tamper")
    cp(clean, tamper; force = true)
    chmod(joinpath(tamper, "linear_transport_total.dat"), 0o600)
    path = joinpath(tamper, "linear_transport_total.dat")
    text = read(path, String)
    @test clean_result.metadata["schema"] == "wanniernlqg.linear-transport-vector/6.0"
    schema_header = "# schema=" * clean_result.metadata["schema"]
    @test occursin(schema_header, text)
    tampered_text = replace(text, schema_header => "# schema=tampered"; count = 1)
    @test tampered_text != text
    write(path, tampered_text)
    @test_throws ErrorException("VECTOR_RESPONSE_SCHEMA_MISMATCH") read_linear_transport_result(
        tamper,
    )

    # New readers reject the old persistence family; archived producers/readers
    # remain in the frozen rollback tree rather than being silently migrated.
    for (quantity, reader, schemas) in (
        (
            "lt",
            read_linear_transport_result,
            (
                "wanniernlqg.linear-transport-vector/2.0",
                "wanniernlqg.linear-transport-vector/3.0",
                "wanniernlqg.linear-transport-vector/4.0",
                "wanniernlqg.linear-transport-vector/5.0",
            ),
        ),
        (
            "oam",
            read_orbital_magnetization_result,
            (
                "wanniernlqg.orbital-magnetization-vector/1.0",
                "wanniernlqg.orbital-magnetization-vector/2.0",
                "wanniernlqg.orbital-magnetization-vector/3.0",
                "wanniernlqg.orbital-magnetization-vector/4.0",
            ),
        ),
    )
        for (index, old_schema) in enumerate(schemas)
            old_path = joinpath(root, quantity * "-old-schema-" * string(index))
            cp(joinpath(output, quantity), old_path; force = true)
            for file in readdir(old_path; join = true)
                endswith(file, ".dat") || continue
                original = read(file, String)
                write(
                    file,
                    replace(original, r"# schema=[^\n]+" => "# schema=" * old_schema; count = 1),
                )
            end
            @test_throws ErrorException("VECTOR_RESPONSE_SCHEMA_MISMATCH") reader(old_path)
        end
    end

    legacy = joinpath(root, "legacy-files")
    cp(clean, legacy; force = true)
    cp(
        joinpath(legacy, "linear_transport_berry_curvature.dat"),
        joinpath(legacy, "linear_transport_contact.dat"),
    )
    @test_throws ErrorException read_linear_transport_result(legacy)
    rm(joinpath(legacy, "linear_transport_berry_curvature.dat"))
    cp(
        joinpath(legacy, "linear_transport_contact.dat"),
        joinpath(legacy, "linear_transport_hall_interband.dat"),
    )
    @test_throws ErrorException read_linear_transport_result(legacy)

    axis_tamper = joinpath(root, "axis-tamper")
    cp(clean, axis_tamper; force = true)
    chmod(joinpath(axis_tamper, "linear_transport_total.dat"), 0o600)
    axis_path = joinpath(axis_tamper, "linear_transport_total.dat")
    axis_lines = readlines(axis_path)
    row = findfirst(line -> !isempty(strip(line)) && !startswith(strip(line), '#'), axis_lines)
    row === nothing && error("test fixture contains no vector-response data row")
    fields = split(axis_lines[row])
    fields[1] = "-1.10000000000000e-01"
    axis_lines[row] = join(fields, ' ')
    write(axis_path, join(axis_lines, '\n') * '\n')
    @test_throws ErrorException read_linear_transport_result(axis_tamper)

    definition_tamper = joinpath(root, "definition-tamper")
    cp(clean, definition_tamper; force = true)
    expected_definition = clean_result.metadata["task_definition"]
    for file in readdir(definition_tamper; join = true)
        original = read(file, String)
        write(
            file,
            replace(
                original,
                expected_definition => "invalid-task-definition",
                repr(expected_definition) => repr("invalid-task-definition"),
            ),
        )
    end
    @test_throws ErrorException read_linear_transport_result(definition_tamper)

    metadata_tamper = joinpath(root, "metadata-tamper")
    cp(clean, metadata_tamper; force = true)
    chmod(joinpath(metadata_tamper, "spectral_response_metadata.txt"), 0o600)
    metadata_path = joinpath(metadata_tamper, "spectral_response_metadata.txt")
    metadata_text = read(metadata_path, String)
    write(
        metadata_path,
        replace(
            metadata_text,
            "qualification_status = \"COMPUTATION_READY\"" => "qualification_status = \"PASS\"";
            count = 1,
        ),
    )
    @test_throws ErrorException read_linear_transport_result(metadata_tamper)
end

@testset "Current operator-model headers round-trip and reject retired wire labels" begin
    directory = mktempdir()
    fixture = frozen_gram_operator_fixture(joinpath(directory, "operators"))
    output = joinpath(directory, "response")
    WannierNLQG.run(
        fv_config(
            fixture.output,
            output,
            "Conventional",
            300.0;
            material = true,
            denominator_regularization = 1.0e-7,
        ),
    )
    current = joinpath(output, "oam")
    result = read_orbital_magnetization_result(current)
    @test result.metadata["operator_model_schema"] ==
          WannierNLQG.IO.OPERATOR_BUNDLE_SCHEMA_VERSION ==
          "3.0"
    for old in ("2.0", "1.3", "unsupported")
        copy_directory = joinpath(directory, "rejected-" * old)
        cp(current, copy_directory)
        changed = 0
        for file in readdir(copy_directory; join = true)
            endswith(file, ".dat") || continue
            before = read(file, String)
            after = replace(
                before,
                "# operator_model_schema=3.0" => "# operator_model_schema=" * old;
                count = 1,
            )
            @test before != after
            chmod(file, 0o600)
            write(file, after)
            changed += 1
        end
        @test changed == length(result.vectors)
        @test_throws ErrorException("VECTOR_RESPONSE_OPERATOR_MODEL_SCHEMA_INVALID") read_orbital_magnetization_result(
            copy_directory,
        )
    end
end

@testset "Material result inventory accepts canonical required supersets" begin
    io_module = WannierNLQG.IO
    core = WannierNLQG.Core
    required = [
        "hamiltonian",
        "position",
        "hamiltonian_weighted_connection",
        "derivative_overlap_tensor",
        "hamiltonian_weighted_axial_derivative_overlap",
    ]
    seven = vcat(required, ["axial_derivative_overlap", "symmetric_derivative_overlap"])
    canonical = core.real_space_operator_name.(collect(core.REAL_SPACE_OPERATOR_REGISTRY))
    for inventory in (required, seven, reverse(seven), canonical)
        @test io_module._validate_orbital_material_inventory(inventory) === nothing
    end
    for index in eachindex(required)
        @test_throws ErrorException("ORBITAL_MATERIAL_FIVE_OPERATOR_INVENTORY_REQUIRED") io_module._validate_orbital_material_inventory(
            required[setdiff(eachindex(required), [index])],
        )
    end
    @test_throws ErrorException("ORBITAL_MATERIAL_OPERATOR_INVENTORY_UNKNOWN") io_module._validate_orbital_material_inventory(
        vcat(required, ["not_a_registered_operator"]),
    )
    @test_throws ErrorException("ORBITAL_MATERIAL_OPERATOR_INVENTORY_DUPLICATE") io_module._validate_orbital_material_inventory(
        vcat(required, [first(required)]),
    )

    directory = mktempdir()
    fixture = frozen_gram_operator_fixture(joinpath(directory, "source"))
    operators = copy(fixture.operators)
    specs = Base.invokelatest(FG_EXPORT._operator_profile_specs)
    for (kind, array) in (
        (core.REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP, fixture.arrays.axial_r),
        (core.REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP, fixture.arrays.symmetric_r),
    )
        operators[kind] = core.RealSpaceOperator(specs[kind], fixture.model.r_vectors, array)
    end
    model = joinpath(directory, "seven.h5")
    io_module.write_real_space_operator_bundle(
        model,
        fixture.model.lattice,
        fixture.model.r_degeneracies,
        operators;
        profile = nothing,
        provenance = fixture.provenance,
        geometry = fixture.geometry,
    )
    manifest = io_module.read_real_space_operator_bundle_manifest(model)
    @test Set(core.real_space_operator_name.(manifest.inventory)) == Set(seven)
    for method in ("Conventional", "Projector")
        output = joinpath(directory, lowercase(method))
        WannierNLQG.run(
            fv_config(
                model,
                output,
                method,
                300.0;
                material = true,
                mus = Float64[0.01],
                denominator_regularization = 0.001,
            ),
        )
        result = read_orbital_magnetization_result(joinpath(output, "oam"))
        @test Set(split(result.metadata["operator_inventory"], ',')) == Set(seven)
        @test all(all(isfinite, vector) for vector in values(result.vectors))
        @test isapprox(
            result.vectors[:total],
            result.vectors[:srocc] + result.vectors[:cmocc];
            atol = 1e-20,
            rtol = 2e-12,
        )
    end
end

@testset "Metadata fragment checks match full-string oracle with bounded reading" begin
    directory = mktempdir()
    samples = (
        "",
        "schema = \"3.0\"\noperator_inventory = \"hamiltonian,position\"\n",
        "prefix\n" * repeat("payload=alpha-lambda;", 97) * "\nend = \"lambda\"\n",
        "prefix-λ-π-δ\n" * repeat("0123456789", 23) * "\nlast\n",
        String(UInt8[0xff, 0x61, 0x62, 0x63, 0x0a, 0xce, 0xbb]),
    )
    fragments = [
        "",
        "schema = \"3.0\"",
        "hamiltonian,position",
        "prefix-λ",
        "\nlast\n",
        "abc",
        "λ",
        "missing",
    ]
    for (index, sample) in enumerate(samples)
        path = joinpath(directory, "case-$(index).txt")
        write(path, sample)
        expected = [occursin(fragment, read(path, String)) for fragment in fragments]
        for chunk in (1, 2, 3, 7, 64, 65536)
            @test WannierNLQG.IO._spectral_metadata_contains_fragments(
                path,
                fragments;
                chunk_bytes = chunk,
            ) == expected
        end
        @test isempty(WannierNLQG.IO._spectral_metadata_contains_fragments(path, String[]))
    end
    @test_throws ArgumentError WannierNLQG.IO._spectral_metadata_contains_fragments(
        joinpath(directory, "case-1.txt"),
        ["x"];
        chunk_bytes = 0,
    )

    # A sparse tail models the descriptor-size failure without writing GiB of
    # data. The real reader only validates scalar fragments and preserves the
    # original descriptor; no timing or material qualification is inferred.
    large = joinpath(directory, "large-descriptor.txt")
    prefix = "schema = \"3.0\"\noperator_inventory = \"hamiltonian,position\"\n"
    open(large, "w") do stream
        write(stream, prefix)
        seek(stream, 1024^3)
        write(stream, UInt8(0x0a))
    end
    needles = ["schema = \"3.0\"", "operator_inventory = \"hamiltonian,position\""]
    @test all(WannierNLQG.IO._spectral_metadata_contains_fragments(large, needles))
    allocated = @allocated WannierNLQG.IO._spectral_metadata_contains_fragments(large, needles)
    @test allocated < 2 * 1024^2
    @test filesize(large) == 1024^3 + 1
end
