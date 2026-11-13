module NonorthogonalIORuntimeUnit
using Test, LinearAlgebra, WannierNLQG
const C = WannierNLQG.Core
const M = WannierNLQG.MatrixElements
const IOLayer = WannierNLQG.IO

"""Write caller-owned synthetic OpenMX records, including an explicitly declared byte order."""
function write_synthetic_localized_file(
    path;
    byte_order = :little,
    spin = 0,
    binary_version = 0,
    moment_order = 1,
    append_coordinates = true,
    binary_position = [0.2, 0.6, 1.2],
    printed_fractional_position = [0.1, 0.2, 0.3],
    position_defect = 0.0,
)
    write_values(stream, values) =
        if byte_order == :little
            write(stream, values)
        elseif eltype(values) == Float64
            write(stream, bswap.(reinterpret(UInt64, vec(values))))
        else
            write(stream, bswap.(vec(values)))
        end
    lattice = Diagonal([2.0, 3.0, 4.0])
    overlap = [1.0 0.1; 0.1 1.2]
    hopping = [0.02 0.01; 0.01 -0.03]
    open(path, "w") do stream
        header = Int32[1, spin + 4binary_version, 0, 0, 0, 0]
        binary_version != 0 && push!(header, moment_order)
        write_values(stream, header)
        write_values(stream, zeros(Float64, 4))
        write_values(stream, zeros(Int32, 4))
        write_values(stream, Int32[2, 0, 1, 0])
        write_values(stream, vcat(zeros(1, 3), Matrix(lattice)))
        write_values(stream, vcat(zeros(1, 3), Matrix(2pi * inv(lattice))))
        write_values(stream, vcat(0.0, binary_position))
        for matrix in (hopping, overlap)
            write_values(stream, Matrix(transpose(matrix)))
        end
        for axis in 1:3, order in 1:moment_order
            matrix = axis == 1 && order == 1 ? Matrix(Diagonal([0.05, 0.1])) : zeros(2, 2)
            axis == 1 && order == 1 && (matrix[1, 2] += position_defect)
            write_values(stream, Matrix(transpose(matrix)))
        end
        remaining_blocks = binary_version == 0 ? 1 : 6 # Momentum(3), density(1), imaginary density(2).
        for block in 1:remaining_blocks
            write_values(stream, zeros(2, 2))
        end
        if binary_version != 0
            write_values(stream, Int32[2]) # Solver identifier.
            write_values(stream, [-0.25, 300.0])
            write_values(stream, zeros(Float64, 8))
            write_values(stream, Int32[1])
            write(stream, zeros(UInt8, 256))
        end
        if append_coordinates
            write(
                stream,
                "\nFractional coordinates of the final structure\n***********************************************************\n***********************************************************\n\n1 X " *
                join(printed_fractional_position, " ") *
                "\n",
            )
        end
    end
    return overlap, hopping
end

include(joinpath(@__DIR__, "NativeDefinitionTestSupport.jl"))
using .NativeDefinitionTestSupport: native_definition_bytes

@testset "Explicit OpenMX binary version 3 and unwrapped coordinates" begin
    directory = mktempdir(; cleanup = false)
    for byte_order in (:little, :big), moment_order in (1, 2)
        file = joinpath(directory, "synthetic-v3-$(byte_order)-$(moment_order).scfout")
        overlap, hopping = write_synthetic_localized_file(
            file;
            byte_order = byte_order,
            binary_version = 3,
            moment_order = moment_order,
            append_coordinates = false,
            binary_position = [-0.2, 0.6, 1.2],
        )
        input = IOLayer.read_openmx_localized_input(
            file;
            format_version = "scfout_v3",
            byte_order = byte_order,
        )
        @test input.model.overlap_r[:, :, 1] == overlap
        @test input.model.hamiltonian_r[:, :, 1] ≈ hopping * 27.211399 atol = 1e-15
        @test input.model.position_r[:, :, 1, 1] ≈
              (Diagonal([0.05, 0.1]) - 0.2overlap) * 0.529177249 atol = 1e-15
        @test input.parameters.binary_version == 3
        @test input.parameters.position_moment_order == moment_order
        @test input.parameters.position_origin == :binary_cartesian
        @test input.parameters.fractional_atom_positions[:, 1] ≈ [-0.1, 0.2, 0.3]
        @test input.parameters.chemical_potential_hartree == -0.25
        @test input.parameters.electronic_temperature_record_unit == "UNINTERPRETED_UPSTREAM_E_TEMP"
        @test_throws ArgumentError IOLayer.read_openmx_localized_input(
            file;
            format_version = "scfout_v3",
            byte_order = byte_order,
            position_source = :appended_final_fractional,
        )
    end
    file = joinpath(directory, "wrapped-output-v3.scfout")
    overlap, _ = write_synthetic_localized_file(
        file;
        binary_version = 3,
        binary_position = [-0.2, 0.6, 1.2],
        printed_fractional_position = [0.9, 0.2, 0.3],
    )
    unwrapped = IOLayer.read_openmx_localized_input(
        file;
        format_version = "scfout_v3",
        byte_order = :little,
    )
    wrapped = IOLayer.read_openmx_localized_input(
        file;
        format_version = "scfout_v3",
        byte_order = :little,
        position_source = :appended_final_fractional,
    )
    @test wrapped.model.position_r[:, :, 1, 1] - unwrapped.model.position_r[:, :, 1, 1] ≈
          2overlap * 0.529177249
    @test native_definition_bytes(unwrapped) != native_definition_bytes(wrapped)
    limited = IOLayer.read_openmx_localized_input(
        file;
        format_version = "scfout_v3",
        byte_order = :little,
        operator_scope = :hamiltonian_overlap,
    )
    @test limited.model.position_r === nothing
    @test limited.parameters.admitted_operators == (:hamiltonian, :overlap)
    @test !limited.parameters.position_operator_admitted
    @test native_definition_bytes(limited) != native_definition_bytes(unwrapped)
    @test M.nonorthogonal_operator_matrices(limited.model, [0.0, 0.0, 0.0]).position === nothing
    @test_throws ArgumentError Main.NonorthogonalLocalizedUnit.geometry_workspace(limited.model)
    spectrum_plan =
        M.compile_matrix_plan(M.MatrixElementRequest(M.SPECTRUM); source_gauge_required = false)
    workspace = M.MatrixElementWorkspace(limited.model, spectrum_plan)
    @test all(isfinite, M.compute_spectrum!(workspace, limited.model, [0.0, 0.0, 0.0]).energies)
    defective_file = joinpath(directory, "defective-position-v3.scfout")
    write_synthetic_localized_file(defective_file; binary_version = 3, position_defect = 1e-4)
    projected = IOLayer.read_openmx_localized_input(
        defective_file;
        format_version = "scfout_v3",
        byte_order = :little,
    )
    @test projected.parameters.raw_position_translation_defect_angstrom ≈ 1e-4*0.529177249
    @test projected.model.raw_position_r != projected.model.position_r
    projected_matrices=M.nonorthogonal_operator_matrices(projected.model, [0.173, 0.0, 0.0])
    @test projected_matrices.position+im*projected_matrices.overlap_derivatives ≈
          permutedims(conj(projected_matrices.position), (2, 1, 3)) atol=1e-13
    limited = IOLayer.read_openmx_localized_input(
        defective_file;
        format_version = "scfout_v3",
        byte_order = :little,
        operator_scope = :hamiltonian_overlap,
    )
    @test limited.parameters.raw_position_translation_defect_angstrom ≈ 1e-4 * 0.529177249
    @test limited.model.position_r === nothing
    for (name, kwargs) in (
        ("bad-version", (binary_version = 2,)),
        ("bad-spin", (binary_version = 3, spin = 1)),
        ("bad-moment", (binary_version = 3, moment_order = 9)),
    )
        file = joinpath(directory, name * ".scfout")
        write_synthetic_localized_file(file; kwargs...)
        @test_throws ArgumentError IOLayer.read_openmx_localized_input(
            file;
            format_version = "scfout_v3",
            byte_order = :little,
        )
    end
end

@testset "Explicit OpenMX 3.8 spinless boundary" begin
    directory = mktempdir(; cleanup = false)
    for byte_order in (:little, :big)
        file = joinpath(directory, "synthetic-$(byte_order).scfout")
        overlap, hopping = write_synthetic_localized_file(file; byte_order = byte_order)
        input = IOLayer.read_openmx_localized_input(
            file;
            format_version = "3.8",
            byte_order = byte_order,
        )
        @test input.model.lattice ≈ Diagonal([2.0, 3.0, 4.0]) * 0.529177249 atol = 1e-15
        @test input.model.overlap_r[:, :, 1] == overlap
        @test input.model.hamiltonian_r[:, :, 1] ≈ hopping * 27.211399 atol = 1e-15
        @test input.model.position_r[:, :, 1, 1] ≈
              (Diagonal([0.05, 0.1]) + 0.2overlap) * 0.529177249 atol = 1e-15
        @test input.model.position_r[:, :, 2, 1] ≈ 0.6overlap * 0.529177249 atol = 1e-15
        @test input.parameters.byte_order == byte_order
        @test input.parameters.orbital_order == :persisted_atom_major
        @test input.parameters.source_provenance_schema == "wanniernlqg.native-source-lifetime/2"
        @test input.parameters.file_identity == IOLayer.scientific_file_identity(file)
        @test !haskey(input.parameters, :file_sha256)
        @test !isempty(native_definition_bytes(input))
        @test_throws ArgumentError IOLayer.read_openmx_localized_input(
            file;
            format_version = "3.9",
            byte_order = byte_order,
        )
        @test_throws ArgumentError IOLayer.read_openmx_localized_input(
            file;
            format_version = "3.8",
            byte_order = :guess,
        )
        @test_throws ArgumentError IOLayer.read_openmx_localized_input(
            file;
            format_version = "3.8",
            byte_order = byte_order,
            max_model_bytes = 1,
        )
        adopted_h = copy(input.model.hamiltonian_r)
        open(file, "a") do stream
            write(stream, UInt8(0))
        end
        @test input.model.hamiltonian_r == adopted_h
        @test_throws ArgumentError native_definition_bytes(input)
    end
    spin_file = joinpath(directory, "unsupported-spin.scfout")
    write_synthetic_localized_file(spin_file; spin = 3)
    @test_throws ArgumentError IOLayer.read_openmx_localized_input(
        spin_file;
        format_version = "3.8",
        byte_order = :little,
    )
    missing_file = joinpath(directory, "missing-positions.scfout")
    write_synthetic_localized_file(missing_file)
    bytes = read(missing_file)
    marker = findfirst(==(UInt8('\n')), bytes)
    # A separately truncated header is an actual EOF error, never an empty successful model.
    write(missing_file, bytes[1:12])
    @test_throws EOFError IOLayer.read_openmx_localized_input(
        missing_file;
        format_version = "3.8",
        byte_order = :little,
    )
    # Tiny payloads must reject enormous claimed array counts before allocating.
    payload = IOBuffer(UInt8[0x01, 0x02])
    @test_throws EOFError IOLayer._read_localized_binary_values(
        payload,
        Float64,
        typemax(Int),
        :little,
    )
    @test position(payload) == 0
end

@testset "Native metric backend dispatch and early rejection" begin
    model = Main.NonorthogonalLocalizedUnit.localized_chain()
    input = C.NonorthogonalLocalizedInput(model; parameters = (fixture = "embedded_chain",))
    output_root = mktempdir(; cleanup = false)
    band = TaskConfig(
        model = input,
        sampling = KPath(
            nodes = [("A", (0.037, 0.0, 0.0)), ("B", (0.219, 0.0, 0.0))],
            kpoints_per_segment = [3],
            spatial_dimension = 3,
        ),
        tasks = [
            TaskSpec(
                id = "metric_band",
                quantity = "Band",
                physics = BandParameters(fermi_energy = 0.0),
            ),
        ],
        execution = ExecutionOptions(fourier_backend = "direct"),
        output = OutputOptions(
            output_root = joinpath(output_root, "band"),
            progress_enabled = false,
        ),
    )
    result = WannierNLQG.run(band)
    @test !isempty(result.outputs)
    @test any(path -> endswith(path, ".dat"), result.outputs)
    @test occursin("nonorthogonal_localized", read(only(result.task_results).metadata_path, String))
    physical =
        OpticalParameters(photon_energies = [0.8, 1.1, 2.0], fermi_energy = 0.0, temperature = 0.0)
    task = TaskSpec(
        id = "metric_sc",
        quantity = "SC",
        method = "Conventional",
        physics = physical,
        numerics = Numerics(denominator_regularization = 0.0, broadening = 0.12),
        observable = FullTensor(),
    )
    config = TaskConfig(
        model = input,
        sampling = BZMesh(k_mesh = (3, 3), spatial_dimension = 3),
        tasks = [task],
        execution = ExecutionOptions(fourier_backend = "direct"),
        output = OutputOptions(output_root = joinpath(output_root, "sc"), progress_enabled = false),
    )
    @test WannierNLQG.Runtime.resolved_numerical_values(
        task,
        :shift_current;
        nonorthogonal = true,
    ).denominator_regularization==0.0
    @test_throws ArgumentError WannierNLQG.Runtime.resolved_numerical_values(
        task,
        :shift_current;
        nonorthogonal = false,
    )
    @test WannierNLQG.Runtime.compile_native_task_config(config, task).denominator_regularization==0.0
    result = WannierNLQG.run(config)
    native_metadata = read(only(result.task_results).metadata_path, String)
    @test occursin("native_model_source_identity", native_metadata)
    @test !occursin("native_model_source_sha256", native_metadata)
    @test !isempty(filter(path -> endswith(path, ".dat"), result.outputs))
    @test occursin(
        "METRIC_AWARE_ANALYTIC_FOURIER",
        read(only(result.task_results).metadata_path, String),
    )
    injection_task=TaskSpec(
        id = "metric_ic",
        quantity = "IC",
        method = "Conventional",
        physics = physical,
        numerics = Numerics(denominator_regularization = 0.001, broadening = 0.12),
        observable = FullTensor(),
    )
    injection_config=TaskConfig(
        model = input,
        sampling = config.sampling,
        tasks = [injection_task],
        execution = config.execution,
        output = OutputOptions(output_root = joinpath(output_root, "ic"), progress_enabled = false),
    )
    injection_result=WannierNLQG.run(injection_config)
    @test injection_result.qualification.qualification_status == "COMPUTATION_READY"
    @test all(isfile, injection_result.outputs)
    @test any(path -> endswith(path, ".dat"), injection_result.outputs)
    shg_task=TaskSpec(
        id = "metric_shg",
        quantity = "SHG",
        method = "Conventional",
        physics = SHGParameters(
            photon_energies = [0.2, 0.73],
            fermi_energy = 0.0,
            temperature = 300.0,
            output = :both,
        ),
        numerics = Numerics(),
        observable = FullTensor(),
    )
    shg_config=TaskConfig(
        model = input,
        sampling = config.sampling,
        tasks = [shg_task],
        execution = config.execution,
        output = OutputOptions(
            output_root = joinpath(output_root, "shg"),
            progress_enabled = false,
        ),
    )
    lowered=WannierNLQG.Runtime.compile_native_task_config(shg_config, shg_task)
    @test lowered.denominator_regularization == 0.001
    @test lowered.shg_intermediate_regularization == 0.001
    @test !lowered.shg_eta_correction
    shg_result=WannierNLQG.run(shg_config)
    @test shg_result.qualification.qualification_status == "COMPUTATION_READY"
    @test all(isfile, shg_result.outputs)
    corrected_task=TaskSpec(
        id = "unsupported_shg_correction",
        quantity = "SHG",
        method = "Conventional",
        physics = shg_task.physics,
        numerics = Numerics(eta_correction = true),
        observable = FullTensor(),
    )
    @test_throws ArgumentError WannierNLQG.Runtime.compile_native_task_config(
        shg_config,
        corrected_task,
    )
    slice=KSlice(
        k_mesh = (2, 2),
        spatial_dimension = 3,
        origin = (0.1, 0.2, 0.0),
        vector_1 = (1.0, 0.0, 0.0),
        vector_2 = (0.0, 1.0, 0.0),
    )
    for (quantity, bands) in (
        ("Interband_Quantum_Metric", InterbandGroups(first = [1], second = [2])),
        ("Interband_Berry_Curvature", InterbandGroups(first = [1], second = [2])),
        ("Berry_Curvature", AllBands()),
    )
        geometry_task=TaskSpec(
            id = lowercase(quantity),
            quantity = quantity,
            method = "Conventional",
            physics = GeometryParameters(),
            numerics = Numerics(denominator_regularization = 0.001),
            observable = KSliceSelection(component = TensorComponent(1, 2), bands = bands),
        )
        geometry_config=TaskConfig(
            model = input,
            sampling = slice,
            tasks = [geometry_task],
            execution = config.execution,
            output = OutputOptions(
                output_root = joinpath(output_root, "geometry", lowercase(quantity)),
                progress_enabled = false,
            ),
        )
        geometry_result=WannierNLQG.run(geometry_config)
        @test geometry_result.qualification.qualification_status == "COMPUTATION_READY"
        @test all(isfile, geometry_result.outputs)
    end
    for quantity in ("SC", "IC", "SHG")
        physics=quantity=="SHG" ?
                SHGParameters(photon_energies = [0.73], fermi_energy = 0.0, temperature = 300.0) :
                OpticalParameters(photon_energies = [0.73], fermi_energy = 0.0, temperature = 0.0)
        bands=quantity=="SHG" ? AllBands() : Transition(conduction = [2], valence = [1])
        task_slice=TaskSpec(
            id = "metric_slice_"*lowercase(quantity),
            quantity = quantity=="SHG" ? "SHG" : quantity*"K",
            method = "Conventional",
            physics = physics,
            numerics = Numerics(denominator_regularization = 0.001),
            observable = KSliceSelection(component = TensorComponent(1, 1, 1), bands = bands),
        )
        config_slice=TaskConfig(
            model = input,
            sampling = slice,
            tasks = [task_slice],
            execution = config.execution,
            output = OutputOptions(
                output_root = joinpath(output_root, "current_slice", quantity),
                progress_enabled = false,
            ),
        )
        result_slice=WannierNLQG.run(config_slice)
        @test result_slice.qualification.qualification_status == "COMPUTATION_READY"
        @test all(isfile, result_slice.outputs)
    end
    finite_input=C.NonorthogonalLocalizedInput(
        Main.NonorthogonalLocalizedUnit.localized_dirac_plane();
        parameters = (fixture = "finite-dirac",),
    )
    orbital_task=TaskSpec(
        id = "metric_orbital",
        quantity = "Orbital_Magnetization",
        method = "Conventional",
        physics = OrbitalMagnetizationParameters(
            fermi_energies = [0.4],
            temperature = 0.0,
            input_semantics = :defined_finite_model,
        ),
        numerics = Numerics(denominator_regularization = 0.001),
        observable = FullTensor(),
    )
    orbital_config=TaskConfig(
        model = finite_input,
        sampling = BZMesh(k_mesh = (2, 2, 1), spatial_dimension = 3),
        tasks = [orbital_task],
        execution = config.execution,
        output = OutputOptions(
            output_root = joinpath(output_root, "orbital"),
            progress_enabled = false,
        ),
    )
    orbital_result=WannierNLQG.run(orbital_config)
    @test orbital_result.qualification.qualification_status == "COMPUTATION_READY"
    @test all(isfile, orbital_result.outputs)
    @test_throws ArgumentError WannierNLQG.Runtime.compile_native_task_config(
        orbital_config,
        TaskSpec(
            id = "metric_orbital_projector",
            quantity = "Orbital_Magnetization",
            method = "Projector",
            physics = orbital_task.physics,
            numerics = Numerics(),
            observable = FullTensor(),
        ),
    )
    unsupported_task = TaskSpec(
        id = "unsupported",
        quantity = "SC",
        method = "Projector",
        physics = physical,
        numerics = Numerics(denominator_regularization = 0.0),
        observable = FullTensor(),
    )
    forbidden = joinpath(output_root, "forbidden")
    unsupported = TaskConfig(
        model = input,
        sampling = config.sampling,
        tasks = [unsupported_task],
        execution = config.execution,
        output = OutputOptions(output_root = forbidden, progress_enabled = false),
    )
    @test_throws ArgumentError WannierNLQG.run(unsupported)
    @test !ispath(forbidden)
    limited_model = C.NonorthogonalLocalizedModel(
        lattice = model.lattice,
        r_vectors = model.r_vectors,
        hamiltonian_r = model.hamiltonian_r,
        overlap_r = model.overlap_r,
        position_r = nothing,
    )
    limited = C.NonorthogonalLocalizedInput(
        limited_model;
        parameters = (operator_scope = :hamiltonian_overlap,),
    )
    excluded_position = TaskConfig(
        model = limited,
        sampling = config.sampling,
        tasks = [task],
        execution = config.execution,
        output = OutputOptions(output_root = forbidden, progress_enabled = false),
    )
    @test_throws ErrorException WannierNLQG.run(excluded_position)
    @test !ispath(forbidden)
    regularized_task = TaskSpec(
        id = "regularized",
        quantity = "SC",
        method = "Conventional",
        physics = physical,
        numerics = Numerics(denominator_regularization = 0.001),
        observable = FullTensor(),
    )
    regularized = TaskConfig(
        model = input,
        sampling = config.sampling,
        tasks = [regularized_task],
        execution = config.execution,
        output = OutputOptions(
            output_root = joinpath(output_root, "regularized"),
            progress_enabled = false,
        ),
    )
    regularized_result = WannierNLQG.run(regularized)
    @test regularized_result.qualification.qualification_status == "COMPUTATION_READY"
    @test all(isfile, regularized_result.outputs)
    @test !ispath(forbidden)
    fft = TaskConfig(
        model = input,
        sampling = config.sampling,
        tasks = [task],
        execution = ExecutionOptions(fourier_backend = "mixed"),
        output = OutputOptions(output_root = forbidden, progress_enabled = false),
    )
    # Uniform localized Mixed is admitted; missing factors remain a pre-output error.
    @test_throws ErrorException WannierNLQG.run(fft)
    @test !ispath(forbidden)
end

@testset "Public nonorthogonal Mixed layout and Runtime offset graph" begin
    fixture = Main.NonorthogonalLocalizedUnit.localized_chain()
    model = C.NonorthogonalLocalizedModel(
        lattice = fixture.lattice,
        r_vectors = fixture.r_vectors,
        hamiltonian_r = fixture.hamiltonian_r,
        overlap_r = fixture.overlap_r,
        position_r = fixture.position_r,
        orbital_centers_cartesian = [0.1 0.35; 0.0 0.0; 0.0 0.0],
    )
    limited = C.NonorthogonalLocalizedModel(
        lattice = model.lattice,
        r_vectors = model.r_vectors,
        hamiltonian_r = model.hamiltonian_r,
        overlap_r = model.overlap_r,
        position_r = nothing,
    )
    spectrum_plan = M.compile_matrix_plan(M.MatrixElementRequest(M.SPECTRUM))
    for value in (model, limited)
        layout = M.MixedFourierLayout(spectrum_plan, value)
        @test layout.groups == [:H, :S]
        @test layout.channel_count == 2
    end
    derivative_plan = M.compile_matrix_plan(M.MatrixElementRequest(M.HAMILTONIAN_DERIVATIVES))
    @test M.MixedFourierLayout(derivative_plan, limited).groups ==
          [:H, :S, :nao_dH, :nao_dS, :nao_ddH, :nao_ddS]
    @test M.MixedFourierLayout(derivative_plan, limited).channel_count == 26
    expected_groups = [:H, :S, :nao_dH, :nao_dS, :nao_ddH, :nao_ddS, :nao_r, :nao_dr]
    runtime = WannierNLQG.Runtime
    mktempdir() do output
        for convention in ("Convention_I", "Convention_II"),
            dimension in 1:3,
            quantity in ("SC", "IC", "SHG")

            physics =
                quantity == "SHG" ?
                SHGParameters(photon_energies = [0.8], fermi_energy = 0.4, temperature = 300.0) :
                OpticalParameters(photon_energies = [0.8], fermi_energy = 0.4, temperature = 300.0)
            task = TaskSpec(
                id = lowercase(quantity),
                quantity = quantity,
                method = "Conventional",
                physics = physics,
                numerics = Numerics(denominator_regularization = 0.001, broadening = 0.2),
                observable = FullTensor(),
            )
            config = TaskConfig(
                model = C.NonorthogonalLocalizedInput(
                    model;
                    wannier_center_convention = convention,
                ),
                sampling = BZMesh(k_mesh = ntuple(_ -> 2, dimension), spatial_dimension = 3),
                tasks = [task],
                execution = ExecutionOptions(
                    fourier_backend = "mixed",
                    NKdiv = ntuple(_ -> 1, dimension),
                    NKFFT = ntuple(_ -> 2, dimension),
                ),
                output = OutputOptions(
                    output_root = joinpath(output, "unwritten"),
                    progress_enabled = false,
                ),
            )
            effective = only(runtime.compile_task_configs(config))
            spec = only(runtime.validate_config(effective))
            plan = runtime.bundle_matrix_element_plan([spec], effective)
            layout = M.MixedFourierLayout(plan, model)
            @test layout.groups == expected_groups
            @test layout.channel_count == 38
            graph = runtime.fourier_task_offset_graph(effective, spec, plan)
            @test !isempty(graph)
            @test all(groups == expected_groups for groups in values(graph))
            @test all(groups !== layout.groups for groups in values(graph))
            @test !ispath(config.output.output_root)
        end
    end
end
end
