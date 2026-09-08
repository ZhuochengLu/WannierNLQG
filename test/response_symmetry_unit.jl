using Test
using LinearAlgebra
using SHA
import Spglib
import JSON3
import HDF5

const RESPONSE_SYMMETRY_RESPONSES = WannierNLQG.Responses
const RESPONSE_SYMMETRY_RUNTIME = WannierNLQG.Runtime
const RESPONSE_SYMMETRY_IO = WannierNLQG.IO
const RESPONSE_SYMMETRY_MODULE = WannierNLQG.Symmetrization
const RESPONSE_SYMMETRY_RUNTIME_PROBE = joinpath(@__DIR__, "ResponseSymmetryRuntimeProbe.jl")

function response_test_operation(rotation; antiunitary = false, translation = zeros(3))
    fractional = Matrix{Int}(rotation)
    cartesian = Matrix{Float64}(rotation)
    return RESPONSE_SYMMETRY_IO.ResponseSymmetryOperation(
        fractional,
        Vector{Float64}(translation),
        cartesian,
        antiunitary,
    )
end

function response_test_grey_mirror_group()
    identity = Matrix{Int}(I, 3, 3)
    mirror_x = Diagonal(Int[-1, 1, 1]) |> Matrix
    return RESPONSE_SYMMETRY_IO.ResponseSymmetryOperation[
        response_test_operation(identity),
        response_test_operation(mirror_x),
        response_test_operation(identity; antiunitary = true),
        response_test_operation(mirror_x; antiunitary = true),
    ]
end

function response_test_partition_from_permutations(permutations)
    point_count = length(first(permutations))
    visited = falses(point_count)
    partition = Set{Tuple}()
    for seed in 1:point_count
        visited[seed] && continue
        orbit = Int[]
        pending = [seed]
        visited[seed] = true
        while !isempty(pending)
            point = pop!(pending)
            push!(orbit, point)
            for permutation in permutations
                mapped = permutation[point]
                visited[mapped] && continue
                visited[mapped] = true
                push!(pending, mapped)
            end
        end
        push!(partition, Tuple(sort!(orbit)))
    end
    return partition
end

function response_test_spglib_partition(rotations, mesh; time_reversal)
    result = Spglib.get_stabilized_reciprocal_mesh(
        rotations,
        collect(mesh),
        [[0, 0, 0]];
        is_shift = falses(3),
        is_time_reversal = time_reversal,
    )
    groups = Dict{Int, Vector{Int}}()
    for source in eachindex(result.grid_address)
        coordinate = mod.(Tuple(result.grid_address[source]), mesh)
        encoded = coordinate[1] + mesh[1] * coordinate[2] + mesh[1] * mesh[2] * coordinate[3] + 1
        push!(get!(groups, result.ir_mapping_table[source], Int[]), encoded)
    end
    return Set(Tuple(sort!(group)) for group in values(groups))
end

@testset "response symmetry antiunitary final-tensor rules" begin
    identity = Matrix{Float64}(I, 3, 3)
    for (quantity, sign) in (
        (:shift_current, 1.0),
        (:injection_current, -1.0),
        (:shift_spin_current, -1.0),
        (:injection_spin_current, 1.0),
    )
        labels = RESPONSE_SYMMETRY_RESPONSES.response_component_labels(quantity, 2)
        label_to_index = Dict(label => index for (index, label) in enumerate(labels))
        action =
            RESPONSE_SYMMETRY_RESPONSES.response_symmetry_action_matrix(quantity, 2, identity, true)
        if quantity in (:shift_spin_current, :injection_spin_current)
            @test action[label_to_index["xzxy"], label_to_index["xzyx"]] == sign
        else
            @test action[label_to_index["xxy"], label_to_index["xyx"]] == sign
        end
        @test action * transpose(action) == Matrix{Float64}(I, size(action, 1), size(action, 1))
    end

    mirror_x = Diagonal(Float64[-1, 1, 1]) |> Matrix
    charge = RESPONSE_SYMMETRY_RESPONSES.response_symmetry_action_matrix(
        :shift_current,
        2,
        mirror_x,
        false,
    )
    spin = RESPONSE_SYMMETRY_RESPONSES.response_symmetry_action_matrix(
        :shift_spin_current,
        2,
        mirror_x,
        false,
    )
    charge_labels = RESPONSE_SYMMETRY_RESPONSES.response_component_labels(:shift_current, 2)
    spin_labels = RESPONSE_SYMMETRY_RESPONSES.response_component_labels(:shift_spin_current, 2)
    charge_index = findfirst(==("xyy"), charge_labels)
    spin_index = findfirst(==("xyyy"), spin_labels)
    @test charge[charge_index, charge_index] == -1.0
    @test spin[spin_index, spin_index] == 1.0
end

@testset "Real-part and Imaginary-part time-reversal channels" begin
    identity = Matrix{Int}(I, 3, 3)
    operations =
        [response_test_operation(identity), response_test_operation(identity; antiunitary = true)]
    expected = Dict(
        :shift_current => (:even, :odd),
        :injection_current => (:odd, :even),
        :shift_spin_current => (:odd, :even),
        :injection_spin_current => (:even, :odd),
    )
    for quantity in keys(expected)
        real_action = RESPONSE_SYMMETRY_RESPONSES.response_symmetry_action_matrix(
            quantity,
            2,
            Matrix{Float64}(I, 3, 3),
            true;
            component_part = :real,
        )
        imaginary_action = RESPONSE_SYMMETRY_RESPONSES.response_symmetry_action_matrix(
            quantity,
            2,
            Matrix{Float64}(I, 3, 3),
            true;
            component_part = :imaginary,
        )
        @test imaginary_action == real_action

        table = RESPONSE_SYMMETRY_RUNTIME._response_time_reversal_channel_table(quantity)
        @test (table.real_part, table.imaginary_part) == expected[quantity]
        plan = RESPONSE_SYMMETRY_RUNTIME._response_tensor_symmetry_plan(
            quantity,
            2,
            operations;
            numerical_reduction = false,
        )
        components = RESPONSE_SYMMETRY_RUNTIME._response_ordered_slot_report(plan)
        xy = first(component for component in components if endswith(component.slot, "xy"))
        xx = first(component for component in components if endswith(component.slot, "xx"))
        @test xy.real_part == (expected[quantity][1] == :even ? :allowed : :forbidden)
        @test xy.imaginary_part == (expected[quantity][2] == :even ? :allowed : :forbidden)
        @test xx.imaginary_part == :identically_zero
    end
end

@testset "full-grid explanation and K-slice calculated-component report" begin
    identity = Matrix{Int}(I, 3, 3)
    operations = [response_test_operation(identity)]
    tensor_plan = RESPONSE_SYMMETRY_RUNTIME._response_tensor_symmetry_plan(
        :shift_current,
        2,
        operations;
        numerical_reduction = false,
    )
    @test tensor_plan.accumulation_path == :full_kmesh_explanation_only
    @test tensor_plan.raw_component_indices == collect(eachindex(tensor_plan.component_labels))
    plan = RESPONSE_SYMMETRY_RUNTIME.ResponseSymmetryExecutionPlan(
        "fixture.json",
        repeat("a", 64),
        "wanniernlqg.response-symmetry/1.1",
        true,
        true,
        repeat("b", 64),
        repeat("c", 64),
        :strict,
        :full,
        true,
        :PASS,
        "PASS",
        0.0,
        1.0e-10,
        String[],
        operations,
        collect(1:4),
        ones(Int, 4),
        4,
        [tensor_plan],
    )
    original = reshape(ComplexF64.(collect(1:8)), 1, 2, 2, 2)
    state = (spec = (quantity = :shift_current,), global_data = copy(original))
    RESPONSE_SYMMETRY_RUNTIME.apply_response_symmetry!([state], plan)
    @test state.global_data == original
    metadata = RESPONSE_SYMMETRY_RUNTIME.response_symmetry_metadata(
        plan;
        calculated_components = Dict(:shift_current => (1, 1, 2)),
    )
    @test metadata.kmesh_mode == :full
    @test metadata.explanation_only
    @test !metadata.numerical_tensor_projection_applied
    summary = only(metadata.human_summaries)
    @test length(summary.real_imaginary_components) == 8
    @test summary.calculated_component.slot == "xxy"
    @test summary.calculated_component.component == "σ_xxy"
    @test hasproperty(summary.calculated_component, :real_part)
    @test hasproperty(summary.calculated_component, :imaginary_part)
end

@testset "response projector, deterministic basis, and relations" begin
    operations = response_test_grey_mirror_group()
    for quantity in
        (:shift_current, :injection_current, :shift_spin_current, :injection_spin_current)
        projector = RESPONSE_SYMMETRY_RESPONSES.response_symmetry_projector(quantity, 2, operations)
        @test projector * projector ≈ projector atol = 1.0e-13 rtol = 0.0
        basis_1 = RESPONSE_SYMMETRY_RESPONSES.response_symmetry_basis(projector)
        basis_2 = RESPONSE_SYMMETRY_RESPONSES.response_symmetry_basis(copy(projector))
        @test basis_1 == basis_2
        @test transpose(basis_1) * basis_1 ≈ Matrix{Float64}(I, size(basis_1, 2), size(basis_1, 2)) atol =
            1.0e-13 rtol = 0.0
        @test basis_1 * transpose(basis_1) ≈ projector atol = 1.0e-13 rtol = 0.0
        relations = RESPONSE_SYMMETRY_RESPONSES.response_symmetry_relations(quantity, 2, projector)
        @test size(relations.constraint_matrix) == size(projector)
        @test !isempty(relations.forbidden)
    end
    shift_projector =
        RESPONSE_SYMMETRY_RESPONSES.response_symmetry_projector(:shift_current, 2, operations)
    shift_relations =
        RESPONSE_SYMMETRY_RESPONSES.response_symmetry_relations(:shift_current, 2, shift_projector)
    @test Set(shift_relations.forbidden) == Set(["xxx", "xyy", "yxy", "yyx"])
    @test ("xxy", "xyx") in shift_relations.equal
end

@testset "compact component plan and validation-only dense oracle" begin
    operations = response_test_grey_mirror_group()
    compact =
        RESPONSE_SYMMETRY_RUNTIME._response_tensor_symmetry_plan(:shift_current, 2, operations)
    @test compact.accumulation_path == :selected_component_kernel_compact_coefficients
    @test compact.raw_component_indices == compact.basis_support_indices
    @test length(compact.raw_component_indices) == 4
    @test size(compact.basis, 2) == 3

    dense = withenv("WANNIERNLQG_RESPONSE_SYMMETRY_FORCE_DENSE" => "1") do
        RESPONSE_SYMMETRY_RUNTIME._response_tensor_symmetry_plan(:shift_current, 2, operations)
    end
    @test dense.accumulation_path == :dense_kernel_compact_coefficients
    @test dense.raw_component_indices == collect(eachindex(dense.component_labels))
    @test dense.projector == compact.projector
    @test dense.basis == compact.basis

    identity = [response_test_operation(Matrix{Int}(I, 3, 3))]
    identity_plan =
        RESPONSE_SYMMETRY_RUNTIME._response_tensor_symmetry_plan(:shift_current, 2, identity)
    @test identity_plan.accumulation_path == :dense_kernel_compact_coefficients
    @test length(identity_plan.raw_component_indices) == 8
end

@testset "runtime rejects malformed point groups and declared checks" begin
    identity = response_test_operation(Matrix{Int}(I, 3, 3))
    mirror_x = response_test_operation(Diagonal(Int[-1, 1, 1]) |> Matrix)
    @test_throws ErrorException RESPONSE_SYMMETRY_RUNTIME._validate_response_point_group([
        identity,
        identity,
    ],)
    @test_throws ErrorException RESPONSE_SYMMETRY_RUNTIME._validate_response_point_group([
        identity,
        mirror_x,
        response_test_operation(Matrix{Int}(I, 3, 3); antiunitary = true),
    ],)

    payload = Dict{String, Any}(
        "symmetry" => Dict{String, Any}(
            "checks" => Dict{String, Any}(
                "identity" => true,
                "inverse" => true,
                "closure" => false,
                "atom_mapping" => Dict("pass" => true),
            ),
        ),
    )
    artifact = RESPONSE_SYMMETRY_IO.ResponseSymmetryArtifact(
        "fixture.json",
        repeat("0", 64),
        repeat("1", 64),
        repeat("2", 64),
        [identity],
        "PASS",
        0.0,
        1.0e-10,
        payload,
    )
    @test_throws ErrorException RESPONSE_SYMMETRY_RUNTIME._validate_response_artifact_declared_checks(
        artifact,
    )
end

@testset "response symmetry residual checks warn but integrity checks remain fatal" begin
    identity = response_test_operation(Matrix{Int}(I, 3, 3))
    raw_rotation = Matrix{Float64}(I, 3, 3)
    raw_rotation[1, 1] += 2.0e-8
    residual_operation = RESPONSE_SYMMETRY_IO.ResponseSymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        raw_rotation,
        false,
    )
    @test_logs (:warn, r"orthogonality residual") RESPONSE_SYMMETRY_RESPONSES.response_symmetry_action_matrix(
        :shift_current,
        3,
        raw_rotation,
        false,
    )
    @test_logs (:warn, r"Cartesian closure residual") RESPONSE_SYMMETRY_RUNTIME._validate_response_point_group([
        residual_operation,
    ],)

    payload = Dict{String, Any}(
        "symmetry" => Dict{String, Any}(
            "checks" => Dict{String, Any}(
                "identity" => true,
                "inverse" => true,
                "closure" => true,
                "atom_mapping" => Dict("pass" => false),
                "cartesian_orthogonality" =>
                    Dict("pass" => false, "maximum_residual" => 2.0e-8),
            ),
        ),
    )
    artifact = RESPONSE_SYMMETRY_IO.ResponseSymmetryArtifact(
        "fixture.json",
        repeat("0", 64),
        repeat("1", 64),
        repeat("2", 64),
        [identity],
        "PASS",
        0.0,
        1.0e-10,
        payload,
    )
    warnings = @test_logs (:warn, r"atom_mapping.pass=false") (
        :warn,
        r"Cartesian rotation qualification warning",
    ) RESPONSE_SYMMETRY_RUNTIME._validate_response_artifact_declared_checks(artifact)
    @test length(warnings) == 2
end

@testset "exact Gamma-centred integer k-mesh orbits" begin
    operations = response_test_grey_mirror_group()
    odd = RESPONSE_SYMMETRY_RUNTIME.response_symmetry_kmesh_orbits((3, 3), operations)
    even = RESPONSE_SYMMETRY_RUNTIME.response_symmetry_kmesh_orbits((4, 4), operations)
    @test length(odd.representatives) == 4
    @test sort(odd.multiplicities) == [1, 2, 2, 4]
    @test sum(odd.multiplicities) == 9
    @test length(even.representatives) == 9
    @test sum(even.multiplicities) == 16

    inversion = response_test_operation(Diagonal(Int[-1, -1, -1]) |> Matrix)
    inversion_orbits = RESPONSE_SYMMETRY_RUNTIME.response_symmetry_kmesh_orbits(
        (3, 3, 3),
        [response_test_operation(Matrix{Int}(I, 3, 3)), inversion],
    )
    @test length(inversion_orbits.representatives) == 14
    @test sum(inversion_orbits.multiplicities) == 27

    rotation_90 = Int[0 -1 0; 1 0 0; 0 0 1]
    rotations = [response_test_operation(rotation_90^power) for power in 0:3]
    square = RESPONSE_SYMMETRY_RUNTIME.response_symmetry_kmesh_orbits((5, 5), rotations)
    @test sum(square.multiplicities) == 25
    @test length(square.representatives) == 7
    @test_throws ErrorException RESPONSE_SYMMETRY_RUNTIME.response_symmetry_kmesh_orbits(
        (2, 3),
        rotations,
    )

    rotate_xz = Float64[0 0 1; 0 1 0; 1 0 0]
    @test_throws ArgumentError RESPONSE_SYMMETRY_RESPONSES.response_symmetry_action_matrix(
        :shift_current,
        2,
        rotate_xz,
        false,
    )
end

@testset "integer orbit partition agrees with Spglib oracle" begin
    operations = response_test_grey_mirror_group()
    rotations = [Matrix{Int}(I, 3, 3), Diagonal(Int[-1, 1, 1]) |> Matrix]
    for mesh in ((5, 5, 1), (4, 6, 1))
        ours =
            RESPONSE_SYMMETRY_RUNTIME.response_symmetry_kmesh_orbits((mesh[1], mesh[2]), operations)
        @test response_test_partition_from_permutations(ours.permutations) ==
              response_test_spglib_partition(rotations, mesh; time_reversal = true)
    end
    inversion_operations = RESPONSE_SYMMETRY_IO.ResponseSymmetryOperation[
        response_test_operation(Matrix{Int}(I, 3, 3)),
        response_test_operation(Diagonal(Int[-1, -1, -1]) |> Matrix),
    ]
    inversion_rotations = [operation.rotation_fractional for operation in inversion_operations]
    ours = RESPONSE_SYMMETRY_RUNTIME.response_symmetry_kmesh_orbits((3, 4, 5), inversion_operations)
    @test response_test_partition_from_permutations(ours.permutations) ==
          response_test_spglib_partition(inversion_rotations, (3, 4, 5); time_reversal = false)
end

@testset "IBZ coefficient contraction equals independently projected full BZ" begin
    operations = response_test_grey_mirror_group()
    orbits = RESPONSE_SYMMETRY_RUNTIME.response_symmetry_kmesh_orbits((5, 5), operations)
    actions = [
        RESPONSE_SYMMETRY_RESPONSES.response_symmetry_action_matrix(
            :shift_current,
            2,
            operation.rotation_cartesian,
            operation.antiunitary,
        ) for operation in operations
    ]
    projector = sum(actions) / length(actions)
    basis = RESPONSE_SYMMETRY_RESPONSES.response_symmetry_basis(projector)
    component_count = size(projector, 1)
    raw = reshape(
        [sin(0.37 * point + 0.19 * component) for component in 1:component_count for point in 1:25],
        component_count,
        25,
    )
    covariant = zeros(Float64, size(raw))
    for (action, permutation) in zip(actions, orbits.permutations)
        inverse_permutation = invperm(permutation)
        covariant .+= action * raw[:, inverse_permutation]
    end
    covariant ./= length(actions)
    projected_full = basis * transpose(basis) * vec(sum(covariant; dims = 2)) / 25
    coefficients = zeros(Float64, size(basis, 2))
    for (representative, multiplicity) in zip(orbits.representatives, orbits.multiplicities)
        coefficients .+= multiplicity .* transpose(basis) * covariant[:, representative] ./ 25
    end
    reconstructed = basis * coefficients
    @test reconstructed ≈ projected_full atol = 1.0e-13 rtol = 0.0
end

function write_response_test_structures(directory::AbstractString)
    win = joinpath(directory, "simple.win")
    write(
        win,
        """
        num_wann = 1
        num_bands = 1
        mp_grid = 2 2 2
        begin unit_cell_cart
        ang
        3 0 0
        0 3 0
        0 0 3
        end unit_cell_cart
        begin atoms_frac
        Si 0 0 0
        end atoms_frac
        begin projections
        Si:s
        end projections
        """,
    )
    poscar = joinpath(directory, "POSCAR")
    write(
        poscar,
        """simple
        1.0
        3 0 0
        0 3 0
        0 0 3
        Si
        1
        Direct
        0 0 0
        """,
    )
    qe_xml = joinpath(directory, "data-file-schema.xml")
    write(
        qe_xml,
        """
        <espresso>
          <input>
            <atomic_species><species name="Si"><pseudo_file>Si.UPF</pseudo_file></species></atomic_species>
            <atomic_structure>
              <cell><a1>5.669 0 0</a1><a2>0 5.669 0</a2><a3>0 0 5.669</a3></cell>
              <atomic_positions><atom name="Si">0 0 0</atom></atomic_positions>
            </atomic_structure>
          </input>
        </espresso>
        """,
    )
    qe_input = joinpath(directory, "scf.in")
    write(
        qe_input,
        """
        &SYSTEM
          starting_magnetization(1) = 1.0
          angle1(1) = 90.0
          angle2(1) = 0.0
        /
        """,
    )
    return win, poscar, qe_xml, qe_input
end

function write_response_test_vasp_pair(directory::AbstractString)
    poscar = joinpath(directory, "POSCAR.vasp")
    write(
        poscar,
        """two-atom VASP response fixture
        1.0
        3 0 0
        0 3 0
        0 0 3
        X Y
        1 1
        Direct
        0 0 0
        0.5 0.5 0.5
        """,
    )
    return poscar
end

@testset "VASP INCAR MAGMOM parsing and SAXIS conversion" begin
    extension = Base.get_extension(WannierNLQG, :WannierNLQGSymmetrizationExt)
    extension === nothing && error("symmetrization extension is not active")
    mktempdir() do directory
        incar = joinpath(directory, "INCAR")

        write(incar, "MAGMOM = 2*1.0\nLNONCOLLINEAR = F\nLSORBIT = F\n")
        fm = extension._read_vasp_incar_magnetic_state(
            incar,
            2;
            collinear_axis_cartesian = [0.0, 0.0, 2.0],
        )
        @test fm.moments_cartesian == [0.0 0.0; 0.0 0.0; 1.0 1.0]
        @test fm.expanded_magmoms == [1.0, 1.0]
        @test fm.interpretation == "initial_magmoms_not_scf_local_moments"

        write(
            incar,
            "magmom = 1.0D0 -1.0d0 ! collinear AFM; ignored\n" *
            "lnoncollinear = .false. ; lsorbit = f # active values\n",
        )
        afm = extension._read_vasp_incar_magnetic_state(
            incar,
            2;
            collinear_axis_cartesian = [1.0, 0.0, 0.0],
        )
        @test afm.moments_cartesian == [1.0 -1.0; 0.0 0.0; 0.0 0.0]

        write(incar, "MAGMOM = 2*9 ; MAGMOM = 1 -1\nLSORBIT = F\n")
        last_assignment = extension._read_vasp_incar_magnetic_state(
            incar,
            2;
            collinear_axis_cartesian = [0.0, 1.0, 0.0],
        )
        @test last_assignment.moments_cartesian == [0.0 0.0; 1.0 -1.0; 0.0 0.0]

        write(incar, "LNONCOLLINEAR = T\nLSORBIT = T\nSAXIS = 1 0 0\nMAGMOM = 2*0 1 3*0\n")
        soc = extension._read_vasp_incar_magnetic_state(incar, 2)
        @test soc.moments_cartesian ≈ [1.0 0.0; 0.0 0.0; 0.0 0.0] atol = 1.0e-14
        @test soc.saxis_normalized == [1.0, 0.0, 0.0]
        @test soc.lnoncollinear && soc.lsorbit

        write(incar, "LSORBIT = T\nSAXIS = 0 1 0\nMAGMOM = 2*0 1 3*0\n")
        rotated = extension._read_vasp_incar_magnetic_state(incar, 2)
        @test rotated.moments_cartesian ≈ [0.0 0.0; 1.0 0.0; 0.0 0.0] atol = 1.0e-14

        write(incar, "LNONCOLLINEAR = F\nMAGMOM = 1 -1\n")
        @test_throws ArgumentError extension._read_vasp_incar_magnetic_state(incar, 2)
        write(incar, "LSORBIT = T\nMAGMOM = 3*0\n")
        @test_throws ArgumentError extension._read_vasp_incar_magnetic_state(incar, 2)
        write(incar, "LSORBIT = T\nSAXIS = 0 0 0\nMAGMOM = 6*0\n")
        @test_throws ArgumentError extension._read_vasp_incar_magnetic_state(incar, 2)
        write(incar, "LSORBIT = T\nSAXIS = 1 0\nMAGMOM = 6*0\n")
        @test_throws ArgumentError extension._read_vasp_incar_magnetic_state(incar, 2)
        write(incar, "LSORBIT = T\nMAGMOM = 5*0 bad\n")
        @test_throws ArgumentError extension._read_vasp_incar_magnetic_state(incar, 2)
        write(incar, "LSORBIT = T\nSAXIS = 0 0 1\n")
        @test_throws ArgumentError extension._read_vasp_incar_magnetic_state(incar, 2)
        write(incar, "LSORBIT = T\nMAGMOM = 0*1\n")
        @test_throws ArgumentError extension._read_vasp_incar_magnetic_state(incar, 2)
        write(incar, "LSORBIT = perhaps\nMAGMOM = 6*0\n")
        @test_throws ArgumentError extension._read_vasp_incar_magnetic_state(incar, 2)
    end
end

@testset "POSCAR authority and VASP INCAR response artifact provenance" begin
    mktempdir() do directory
        poscar = write_response_test_vasp_pair(directory)
        incar = joinpath(directory, "INCAR")
        model = joinpath(directory, "model.dat")
        write(model, "VASP response artifact model fixture\n")
        write(incar, "LNONCOLLINEAR = T\nLSORBIT = T\nSAXIS = 1 0 0\nMAGMOM = 2*0 1 3*0\n")
        explicit = [1.0 0.0; 0.0 0.0; 0.0 0.0]

        incar_artifact = joinpath(directory, "incar.json")
        explicit_artifact = joinpath(directory, "explicit.json")
        consistent_artifact = joinpath(directory, "consistent.json")
        RESPONSE_SYMMETRY_MODULE.write_response_symmetry_artifact(
            incar_artifact;
            structure_file = poscar,
            structure_format = :poscar,
            model_file = model,
            vasp_magnetic_input_file = incar,
        )
        RESPONSE_SYMMETRY_MODULE.write_response_symmetry_artifact(
            explicit_artifact;
            structure_file = poscar,
            structure_format = :poscar,
            model_file = model,
            magnetic_moments_cartesian = explicit,
        )
        RESPONSE_SYMMETRY_MODULE.write_response_symmetry_artifact(
            consistent_artifact;
            structure_file = poscar,
            structure_format = :poscar,
            model_file = model,
            magnetic_moments_cartesian = explicit,
            vasp_magnetic_input_file = incar,
        )
        payload = JSON3.read(read(consistent_artifact, String), Dict{String, Any})
        provenance = payload["provenance"]
        @test provenance["model"]["sha256"] == bytes2hex(SHA.sha256(read(model)))
        @test provenance["structure"]["sha256"] == bytes2hex(SHA.sha256(read(poscar)))
        @test provenance["vasp_magnetic_input"]["sha256"] == bytes2hex(SHA.sha256(read(incar)))
        @test provenance["magnetic_moment_source"] ==
              "explicit_cartesian_array_consistent_with_vasp_incar"
        @test provenance["magnetic_moment_semantics"] == "initial_magmoms_not_scf_local_moments"
        magnetism = provenance["vasp_incar_magnetism"]
        @test magnetism["LNONCOLLINEAR"] === true
        @test magnetism["LSORBIT"] === true
        @test magnetism["SAXIS_normalized"] == [1.0, 0.0, 0.0]
        @test payload["structure"]["elements"] == ["X", "Y"]
        @test payload["structure"]["positions_fractional_columns"] ==
              [[0.0, 0.0, 0.0], [0.5, 0.5, 0.5]]

        incar_runtime = RESPONSE_SYMMETRY_IO.read_response_symmetry_artifact(incar_artifact)
        explicit_runtime = RESPONSE_SYMMETRY_IO.read_response_symmetry_artifact(explicit_artifact)
        @test length(incar_runtime.operations) == length(explicit_runtime.operations)
        for (left, right) in zip(incar_runtime.operations, explicit_runtime.operations)
            @test left.rotation_fractional == right.rotation_fractional
            @test left.translation_fractional == right.translation_fractional
            @test left.rotation_cartesian == right.rotation_cartesian
            @test left.antiunitary == right.antiunitary
        end
        incar_orbits = RESPONSE_SYMMETRY_RUNTIME.response_symmetry_kmesh_orbits(
            (4, 4, 4),
            incar_runtime.operations,
        )
        explicit_orbits = RESPONSE_SYMMETRY_RUNTIME.response_symmetry_kmesh_orbits(
            (4, 4, 4),
            explicit_runtime.operations,
        )
        @test incar_orbits.representatives == explicit_orbits.representatives
        @test incar_orbits.multiplicities == explicit_orbits.multiplicities
        for quantity in RESPONSE_SYMMETRY_RESPONSES.RESPONSE_SYMMETRY_QUANTITIES
            left = RESPONSE_SYMMETRY_RESPONSES.response_symmetry_projector(
                quantity,
                3,
                incar_runtime.operations,
            )
            right = RESPONSE_SYMMETRY_RESPONSES.response_symmetry_projector(
                quantity,
                3,
                explicit_runtime.operations,
            )
            @test left == right
        end

        @test_throws ArgumentError RESPONSE_SYMMETRY_MODULE.write_response_symmetry_artifact(
            joinpath(directory, "conflict.json");
            structure_file = poscar,
            structure_format = :poscar,
            model_file = model,
            magnetic_moments_cartesian = -explicit,
            vasp_magnetic_input_file = incar,
        )
        @test_throws ArgumentError RESPONSE_SYMMETRY_MODULE.write_response_symmetry_artifact(
            joinpath(directory, "wrong_format.json");
            structure_file = poscar,
            structure_format = :win,
            model_file = model,
            vasp_magnetic_input_file = incar,
        )
    end
end

@testset "VASP INCAR and explicit Cartesian artifacts give identical q=0 response" begin
    mktempdir() do directory
        _, poscar, _, _ = write_response_test_structures(directory)
        incar = joinpath(directory, "INCAR")
        write(incar, "LNONCOLLINEAR = T\nLSORBIT = T\nSAXIS = 0 0 1\nMAGMOM = 3*0\n")
        incar_artifact = joinpath(directory, "incar.json")
        explicit_artifact = joinpath(directory, "explicit.json")
        RESPONSE_SYMMETRY_MODULE.write_response_symmetry_artifact(
            incar_artifact;
            structure_file = poscar,
            structure_format = :poscar,
            model_file = TEST_MODEL_FILE,
            vasp_magnetic_input_file = incar,
        )
        RESPONSE_SYMMETRY_MODULE.write_response_symmetry_artifact(
            explicit_artifact;
            structure_file = poscar,
            structure_format = :poscar,
            model_file = TEST_MODEL_FILE,
            magnetic_moments_cartesian = zeros(3, 1),
        )
        outputs = String[]
        for (label, artifact) in
            (("run_incar", incar_artifact), ("run_explicit", explicit_artifact))
            result = WannierNLQG.run(
                WannierNLQG.Runtime.EffectiveTaskConfig(
                    tasks = [("SC", "Conventional", "Integral")],
                    k_mesh = (2, 2, 2),
                    fourier_backend = "direct",
                    photon_energies = [0.1, 0.2],
                    spatial_dimension = 3,
                    model_file = TEST_MODEL_FILE,
                    output_root = joinpath(directory, label),
                    system_name = "source_equivalence",
                    response_symmetry_file = artifact,
                    response_symmetry_policy = "diagnostic",
                    progress_enabled = false,
                ),
            )
            push!(outputs, only(result.outputs))
        end
        @test read(outputs[1]) == read(outputs[2])
        read_values(path) = reduce(
            vcat,
            [
                permutedims(parse.(Float64, split(line))) for
                line in eachline(path) if !isempty(strip(line)) && !startswith(strip(line), "#")
            ],
        )
        first_values = read_values(outputs[1])
        second_values = read_values(outputs[2])
        difference = first_values[:, 2:end] - second_values[:, 2:end]
        @test maximum(abs, difference) == 0.0
        @test norm(difference) / max(norm(first_values[:, 2:end]), 1.0e-30) == 0.0
    end
end

@testset "response symmetry artifact WIN POSCAR and direct QE XML" begin
    mktempdir() do directory
        model = joinpath(directory, "model.dat")
        write(model, "response symmetry model hash fixture\n")
        win, poscar, qe_xml, qe_input = write_response_test_structures(directory)
        for (format, structure_file) in ((:win, win), (:poscar, poscar), (:qe_xml, qe_xml))
            output = joinpath(directory, "artifact_$(format).json")
            written = RESPONSE_SYMMETRY_MODULE.write_response_symmetry_artifact(
                output;
                structure_file,
                structure_format = format,
                model_file = model,
                include_time_reversal = true,
                integrand_covariance_status = "NOT_RUN",
            )
            @test written == output
            @test JSON3.read(read(output, String))["schema"] == "wanniernlqg.response-symmetry/1.0"
            artifact = RESPONSE_SYMMETRY_IO.read_response_symmetry_artifact(output)
            @test artifact.model_sha256 == bytes2hex(SHA.sha256(read(model)))
            @test artifact.qualification_status == "NOT_RUN"
            @test !isempty(artifact.operations)
            @test any(operation -> operation.antiunitary, artifact.operations)
        end

        magnetic_output = joinpath(directory, "artifact_qe_magnetic.json")
        @test RESPONSE_SYMMETRY_MODULE.write_response_symmetry_artifact(
            magnetic_output;
            structure_file = qe_xml,
            structure_format = :qe_xml,
            model_file = model,
            qe_magnetic_input_file = qe_input,
            include_time_reversal = true,
        ) == magnetic_output
        @test_throws ArgumentError RESPONSE_SYMMETRY_MODULE.write_response_symmetry_artifact(
            joinpath(directory, "invalid_qe_directory.json");
            structure_file = directory,
            structure_format = :qe_xml,
            model_file = model,
        )
        @test_throws ArgumentError RESPONSE_SYMMETRY_MODULE.write_response_symmetry_artifact(
            joinpath(directory, "invalid_moments.json");
            structure_file = poscar,
            structure_format = :poscar,
            model_file = model,
            magnetic_moments_cartesian = zeros(3, 2),
        )

        invalid_schema = joinpath(directory, "invalid_schema.json")
        write(invalid_schema, "{\"schema\":\"wrong/1.0\"}")
        @test_throws ArgumentError RESPONSE_SYMMETRY_IO.read_response_symmetry_artifact(
            invalid_schema,
        )

        valid_artifact = joinpath(directory, "artifact_win.json")
        malformed_hash = joinpath(directory, "invalid_hash.json")
        payload = read(valid_artifact, String)
        payload = replace(payload, bytes2hex(SHA.sha256(read(model))) => "not-a-sha256"; count = 1)
        write(malformed_hash, payload)
        @test_throws ArgumentError RESPONSE_SYMMETRY_IO.read_response_symmetry_artifact(
            malformed_hash,
        )
    end
end

@testset "response symmetry scope and policy validation" begin
    q0_kslice = WannierNLQG.Runtime.EffectiveTaskConfig(
        tasks = [("Shift_Current", "Conventional", "K-slice")],
        k_mesh = (2, 2),
        fourier_backend = "direct",
        response_symmetry_file = "artifact.json",
    )
    @test only(RESPONSE_SYMMETRY_RUNTIME.validate_config(q0_kslice)).calculation == :kslice
    @test_throws ErrorException RESPONSE_SYMMETRY_RUNTIME.validate_config(
        WannierNLQG.Runtime.EffectiveTaskConfig(
            tasks = [("Shift_Current", "Conventional", "K-slice")],
            k_mesh = (2, 2),
            fourier_backend = "direct",
            photon_momentum = (0.01, 0.0, 0.0),
            response_symmetry_file = "artifact.json",
        ),
    )
    @test_throws ErrorException RESPONSE_SYMMETRY_RUNTIME.validate_config(
        WannierNLQG.Runtime.EffectiveTaskConfig(
            tasks = [("PDSC", "Geometric_Loop", "Integral")],
            k_mesh = (2, 2),
            fourier_backend = "direct",
            photon_momentum = (0.01, 0.0, 0.0),
            response_symmetry_file = "artifact.json",
        ),
    )
    @test_throws ErrorException RESPONSE_SYMMETRY_RUNTIME.validate_config(
        WannierNLQG.Runtime.EffectiveTaskConfig(
            fourier_backend = "direct",
            response_symmetry_policy = "permissive",
        ),
    )
    @test_throws ErrorException RESPONSE_SYMMETRY_RUNTIME.validate_config(
        WannierNLQG.Runtime.EffectiveTaskConfig(
            fourier_backend = "direct",
            response_symmetry_kmesh_mode = "projected",
        ),
    )
    full_disabled = WannierNLQG.Runtime.EffectiveTaskConfig(
        tasks = [("Shift_Current", "Conventional", "Integral")],
        k_mesh = (2, 2),
        fourier_backend = "direct",
        response_symmetry_kmesh_mode = "full",
        response_symmetry_report_enabled = false,
    )
    @test only(RESPONSE_SYMMETRY_RUNTIME.validate_config(full_disabled)).calculation == :integral
    @test_throws ErrorException RESPONSE_SYMMETRY_RUNTIME.validate_config(
        WannierNLQG.Runtime.EffectiveTaskConfig(
            tasks = [("Shift_Current", "Conventional", "Integral")],
            k_mesh = (2, 2),
            fourier_backend = "direct",
            response_symmetry_file = "artifact.json",
            response_symmetry_kmesh_mode = "full",
            response_symmetry_report_enabled = false,
        ),
    )
    @test_throws ErrorException RESPONSE_SYMMETRY_RUNTIME.validate_config(
        WannierNLQG.Runtime.EffectiveTaskConfig(
            tasks = [("Shift_Current", "Conventional", "Integral")],
            k_mesh = (2, 2),
            fourier_backend = "direct",
            response_symmetry_kmesh_mode = "full",
            response_symmetry_report_enabled = true,
        ),
    )
    full_enabled = WannierNLQG.Runtime.EffectiveTaskConfig(
        tasks = [("Shift_Current", "Conventional", "Integral")],
        k_mesh = (2, 2),
        fourier_backend = "direct",
        response_symmetry_file = "artifact.json",
        response_symmetry_kmesh_mode = "full",
        response_symmetry_report_enabled = true,
    )
    @test only(RESPONSE_SYMMETRY_RUNTIME.validate_config(full_enabled)).calculation == :integral
end

@testset "full-grid disabled report needs only the TB input" begin
    mktempdir() do directory
        config = WannierNLQG.Runtime.EffectiveTaskConfig(
            tasks = [("Shift_Current", "Conventional", "Integral")],
            k_mesh = (1, 1),
            fourier_backend = "direct",
            photon_energies = [0.1],
            spatial_dimension = 2,
            model_file = TEST_MODEL_FILE,
            output_root = joinpath(directory, "output"),
            system_name = "full_grid_report_disabled",
            response_symmetry_kmesh_mode = "full",
            response_symmetry_report_enabled = false,
            progress_enabled = true,
        )
        result = WannierNLQG.run(config)
        report = read(result.progress_out_path, String)
        @test occursin("response symmetry report", report)
        @test occursin("DISABLED", report)
        @test !occursin("  Response symmetry", report)
        @test !occursin("CARTESIAN COMPONENTS", report)
        @test !occursin("SYMMETRY RELATIONS", report)
        @test !occursin("response_symmetry_summary.json", report)
        @test !isfile(joinpath(result.run_dir, "response_symmetry_summary.json"))
        @test all(isfile, result.outputs)
    end
end

@testset "q=0 K-slice out lists all slots before the calculated component" begin
    mktempdir() do directory
        _, poscar, _, _ = write_response_test_structures(directory)
        artifact = joinpath(directory, "response_symmetry.json")
        RESPONSE_SYMMETRY_MODULE.write_response_symmetry_artifact(
            artifact;
            structure_file = poscar,
            structure_format = :poscar,
            model_file = TEST_MODEL_FILE,
            magnetic_moments_cartesian = zeros(3, 1),
            integrand_covariance_status = "PASS",
            covariance_max_relative_residual = 0.0,
        )
        config = WannierNLQG.Runtime.EffectiveTaskConfig(
            tasks = [("Shift_Current", "Conventional", "K-slice")],
            k_mesh = (1, 1),
            fourier_backend = "direct",
            photon_energies = [0.1],
            spatial_dimension = 3,
            tensor_indices = (1, 1, 2),
            model_file = TEST_MODEL_FILE,
            case_root = directory,
            output_root = joinpath(directory, "output"),
            system_name = "kslice_symmetry_report",
            response_symmetry_file = artifact,
            response_symmetry_policy = "diagnostic",
            response_symmetry_kmesh_mode = "full",
            response_symmetry_report_enabled = true,
            progress_enabled = true,
        )
        result = WannierNLQG.run(config)
        report = read(result.progress_out_path, String)
        components = findfirst("CARTESIAN COMPONENTS", report)
        relations = findfirst("SYMMETRY RELATIONS", report)
        calculated = findfirst("CALCULATED COMPONENT", report)
        overview = findfirst("  OVERVIEW", report)
        classification = findfirst("  GROUP CLASSIFICATION", report)
        generators = findfirst("  POINT-GROUP GENERATORS", report)
        tensor_summary = findfirst("  SHIFT-CURRENT TENSOR SYMMETRY SUMMARY", report)
        @test components !== nothing
        @test relations !== nothing
        @test calculated !== nothing
        @test first(something(components)) <
              first(something(relations)) <
              first(something(calculated))
        @test overview !== nothing
        @test classification !== nothing
        @test generators !== nothing
        @test tensor_summary !== nothing
        @test first(something(overview)) <
              first(something(classification)) <
              first(something(generators)) <
              first(something(tensor_summary))
        for label in RESPONSE_SYMMETRY_RESPONSES.response_component_labels(:shift_current, 3)
            @test occursin("σ_$(label)", report)
        end
        @test !occursin("LINEAR / CIRCULAR", report)
        @test !occursin("linear/symmetric", report)
        @test !occursin("circular/antisymmetric", report)
        @test isnothing(match(r"(?i)\b(linear|circular)\b", report))
        @test !occursin("equal Re:", report)
        @test !occursin("opposite Im:", report)
        @test occursin("full magnetic point group H-M (display)", report)
        @test occursin("active constraint group H-M (display)", report)
        @test occursin("operation digest=", report)
        @test occursin("wanniernlqg.spglib-canonical/1.0", report)
        @test occursin("basis transform to input", report)
        summary = JSON3.read(
            read(joinpath(result.run_dir, "response_symmetry_summary.json"), String),
            Dict{String, Any},
        )
        response = only(values(summary["responses"]))
        @test summary["schema"] == "wanniernlqg.response-symmetry-summary/1.0"
        @test summary["group_classification"]["structural_space_group"]["international_number"] ==
              221
        @test summary["active_constraint_group"]["hermann_mauguin"] == "m-3m1'"
        for group in (
            summary["group_classification"]["full_magnetic_point_group"],
            summary["active_constraint_group"],
        )
            @test group["magnetic_point_group_number"] in 1:122
            @test length(group["operation_digest"]) == 64
            @test group["operation_digest_contract"] ==
                  "wanniernlqg.magnetic-point-group-operations/1.0"
            @test group["symbol_convention"] == "wanniernlqg.spglib-canonical/1.0"
            @test group["basis_transform_to_input"]["shape"] == [3, 3]
            @test !haskey(group, "catalog_sha256")
        end
        @test summary["generators"]["active_point_group"]["closure_verified"] === true
        @test haskey(summary, "classification_source")
        catalog_provenance = summary["classification_source"]["magnetic_point_group_catalog"]
        @test !haskey(catalog_provenance, "catalog_sha256")
        @test length(catalog_provenance["display_catalog_sha256"]) == 64
        @test length(response["real_imaginary_components"]) == 27
        @test response["calculated_component"]["slot"] == "xxy"
        @test haskey(response, "real_part")
        @test haskey(response, "imaginary_part")
        @test !haskey(response, "linear_circular_channels")
        @test summary["kmesh_mode"] == "full"
        @test summary["numerical_tensor_projection_applied"] === false
    end
end

@testset "complete-contract Angstrom tolerance and effective Cartesian rotations" begin
    foundation = WannierNLQG.SymmetryFoundation
    extension = Base.get_extension(WannierNLQG, :WannierNLQGSymmetryFoundationExt)
    extension === nothing && error("symmetry-foundation extension is not active")
    @test foundation.resolve_spglib_symprec_angstrom() == 1.0e-5
    @test foundation.resolve_spglib_symprec_angstrom(spglib_symprec_angstrom = 5.0e-5) == 5.0e-5
    @test foundation.resolve_spglib_symprec_angstrom(
        spglib_symprec_angstrom = 5.0e-5,
        symmetry_tolerance = 5.0e-5,
    ) == 5.0e-5
    @test_throws ArgumentError foundation.resolve_spglib_symprec_angstrom(
        spglib_symprec_angstrom = 5.0e-5,
        symmetry_tolerance = 1.0e-5,
    )

    identity = Matrix{Int}(I, 3, 3)
    c3 = [0 1 0; -1 -1 0; 0 0 1]
    c3_square = c3 * c3
    rotations = [identity, c3, c3_square]
    lattice = [1.0 0.0 0.0; -0.5000001 sqrt(3.0) / 2 0.0; 0.0 0.0 10.0]
    rotation_data = foundation.group_invariant_cartesian_rotation_data(rotations, lattice)
    @test rotation_data.maximum_effective_orthogonality <= 1.0e-12
    @test rotation_data.maximum_effective_closure <= 1.0e-12
    @test rotation_data.maximum_correction > 0.0
    @test_throws ArgumentError extension._build_symmetry_operations(
        rotations,
        [zeros(3) for _ in rotations],
        falses(length(rotations)),
        lattice;
        maximum_cartesian_rotation_correction = rotation_data.maximum_correction / 2,
    )
end

@testset "deterministic atom bijection and axial magnetic action" begin
    extension = Base.get_extension(WannierNLQG, :WannierNLQGSymmetrizationExt)
    skew_lattice_rows = [1.0 0.0 0.0; 0.9 0.1 0.0; 0.0 0.0 1.0]
    skew_lattice_columns = Matrix(transpose(skew_lattice_rows))
    skew_displacement = [0.49, 0.49, 0.0]
    componentwise_distance =
        norm(skew_lattice_columns * (skew_displacement - round.(skew_displacement)))
    exact_minimum_image = extension._response_minimum_image_cartesian_residual(
        skew_displacement,
        skew_lattice_columns,
    )
    @test exact_minimum_image < componentwise_distance
    @test isapprox(exact_minimum_image, norm([0.031, -0.051, 0.0]); atol = 1.0e-14)

    identity = Matrix{Int}(I, 3, 3)
    mirror = [0 1 0; 1 0 0; 0 0 1]
    mirror_cartesian = Matrix{Float64}(mirror)
    structure = WannierNLQG.SymmetryFoundation.CrystalStructure(
        Matrix{Float64}(I, 3, 3),
        ["X"],
        zeros(3, 1);
        magnetic_moments_cartesian = reshape([0.0, 0.0, 1.0], 3, 1),
    )
    anti_mirror =
        WannierNLQG.SymmetryFoundation.SymmetryOperation(mirror, zeros(3), mirror_cartesian, true)
    passing = extension._response_atom_mapping_check(
        structure,
        [anti_mirror],
        1.0e-5,
        1.0e-5,
        1.0e-8,
        1.0e-8,
    )
    @test passing["pass"]
    @test passing["bijection"]
    @test passing["maximum_magnetic_absolute_residual"] == 0.0

    anti_identity = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        identity,
        zeros(3),
        Matrix{Float64}(I, 3, 3),
        true,
    )
    failing = extension._response_atom_mapping_check(
        structure,
        [anti_identity],
        1.0e-5,
        1.0e-5,
        1.0e-8,
        1.0e-8,
    )
    @test !failing["pass"]
    @test failing["maximum_magnetic_absolute_residual"] == 2.0

    non_bijective_structure = WannierNLQG.SymmetryFoundation.CrystalStructure(
        Matrix{Float64}(I, 3, 3),
        ["X", "X"],
        [0.0 0.25; 0.0 0.0; 0.0 0.0],
    )
    @test_throws ArgumentError extension._response_atom_mapping_check(
        non_bijective_structure,
        [
            WannierNLQG.SymmetryFoundation.SymmetryOperation(
                identity,
                [0.25, 0.0, 0.0],
                Matrix{Float64}(I, 3, 3),
                false,
            ),
        ],
        1.0e-5,
        1.0e-5,
        1.0e-8,
        1.0e-8,
    )
end

@testset "response symmetry human relations and signed-cycle filtering" begin
    identity_operation = response_test_operation(Matrix{Int}(I, 3, 3))
    tensor = RESPONSE_SYMMETRY_RUNTIME._response_tensor_symmetry_plan(
        :shift_current,
        2,
        [identity_operation];
        numerical_reduction = false,
    )
    empty_plan = RESPONSE_SYMMETRY_RUNTIME.ResponseSymmetryExecutionPlan(
        "fixture.json",
        repeat("a", 64),
        "fixture",
        false,
        false,
        repeat("b", 64),
        repeat("c", 64),
        :diagnostic,
        :DIAGNOSTIC_ONLY,
        "NOT_RUN",
        nothing,
        1.0e-10,
        String[],
        RESPONSE_SYMMETRY_IO.ResponseSymmetryOperation[],
        [1],
        [1],
        1,
        [tensor],
    )
    summary = RESPONSE_SYMMETRY_RUNTIME.response_symmetry_human_summary(tensor, empty_plan)
    @test "Re σ_xxy = Re σ_xyx" in summary.real_symmetry_relations
    @test "Im σ_xxy = -Im σ_xyx" in summary.imaginary_symmetry_relations
    xxx = first(
        component for component in summary.real_imaginary_components if component.slot == "xxx"
    )
    @test xxx.imaginary_part == :identically_zero

    inconsistent = RESPONSE_SYMMETRY_RUNTIME._response_symmetry_signed_classes(
        ["xxx", "xxy", "xyx"],
        Matrix{Float64}(I, 3, 3),
        String[],
        [("xxx", "xxy"), ("xxy", "xyx")],
        [("xxx", "xyx")],
    )
    @test isempty(inconsistent.classes)
    @test inconsistent.inconsistent_indices == [1, 2, 3]
end

@testset "streamed integrand covariance records complete failure location" begin
    identity = response_test_operation(Matrix{Int}(I, 3, 3))
    constant_evaluator = (_, _) -> ones(27, 2)
    passing = RESPONSE_SYMMETRY_RUNTIME.validate_response_integrand_covariance(
        constant_evaluator,
        (2, 2, 1),
        [identity];
        photon_energies = [0.1, 0.2],
        input_sha256 = repeat("a", 64),
    )
    @test passing["status"] == "PASS"
    @test passing["comparison_count"] == 216
    @test passing["evaluator_call_count"] == 8
    @test passing["input_sha256"] == repeat("a", 64)
    @test_throws ArgumentError RESPONSE_SYMMETRY_RUNTIME.validate_response_integrand_covariance(
        constant_evaluator,
        (1, 1, 1),
        [identity];
        photon_energies = [0.1],
        input_sha256 = "invalid",
    )

    mirror = response_test_operation(Diagonal(Int[-1, 1, 1]) |> Matrix)
    failing = RESPONSE_SYMMETRY_RUNTIME.validate_response_integrand_covariance(
        constant_evaluator,
        (2, 2, 1),
        [mirror];
        photon_energies = [0.1, 0.2],
    )
    @test failing["status"] == "FAIL"
    @test failing["worst"]["operation_index"] == 1
    @test failing["worst"]["photon_energy"] in (0.1, 0.2)
    @test !isnothing(failing["worst"]["component_label"])
end

@testset "full-grid and reduced-grid same-input consistency gate" begin
    full = reshape(ComplexF64[0.0, 1.0, 2.0, 3.0], 2, 2)
    same = copy(full)
    digest = repeat("a", 64)
    passing = RESPONSE_SYMMETRY_RUNTIME.validate_response_full_grid_consistency(
        full,
        same;
        full_input_sha256 = digest,
        reduced_input_sha256 = digest,
    )
    @test passing["status"] == "PASS"
    @test passing["nonzero_l2_relative"] == 0.0

    changed = copy(full)
    changed[2, 2] += 1.0e-4
    failing = RESPONSE_SYMMETRY_RUNTIME.validate_response_full_grid_consistency(full, changed)
    @test failing["status"] == "FAIL"
    @test failing["worst_cartesian_index"] == [2, 2]
    @test_throws ArgumentError RESPONSE_SYMMETRY_RUNTIME.validate_response_full_grid_consistency(
        full,
        same;
        full_input_sha256 = repeat("a", 64),
        reduced_input_sha256 = repeat("b", 64),
    )
    @test_throws ArgumentError RESPONSE_SYMMETRY_RUNTIME.validate_response_full_grid_consistency(
        full,
        same;
        full_input_sha256 = repeat("a", 64),
    )
end

@testset "formal downstream evidence cannot bypass qualification order" begin
    extension = Base.get_extension(WannierNLQG, :WannierNLQGSymmetrizationExt)
    structural_payload = Dict(
        "symmetry" => Dict(
            "checks" => Dict(
                "identity" => true,
                "inverse" => true,
                "closure" => true,
                "space_group" => Dict("pass" => true),
                "point_group" => Dict("pass" => true),
                "tolerance_stability" => Dict("pass" => true),
                "atom_mapping" => Dict("pass" => true, "bijection" => true),
                "cartesian_rotation" => Dict("production_pass" => true),
            ),
        ),
    )
    @test extension._response_qualification_structure_pass(structural_payload)
    structural_payload["symmetry"]["checks"]["atom_mapping"]["pass"] = false
    @test !extension._response_qualification_structure_pass(structural_payload)

    digest = repeat("a", 64)
    integrand = Dict(
        "status" => "PASS",
        "pass" => true,
        "input_sha256" => digest,
        "maximum_relative_residual" => 0.0,
        "tolerance" => 1.0e-8,
    )
    full_grid = Dict(
        "status" => "PASS",
        "pass" => true,
        "same_input_sha256" => digest,
        "nonzero_l2_relative" => 0.0,
    )
    formal = Dict{String, Any}(
        "integrand_covariance" => Dict("status" => "NOT_RUN_DOWNSTREAM_BLOCKED"),
        "full_grid_consistency" => Dict("status" => "NOT_RUN_DOWNSTREAM_BLOCKED"),
    )
    diagnostic = Dict{String, Any}()
    extension._response_qualification_apply_downstream_evidence!(
        formal,
        diagnostic,
        true,
        integrand,
        full_grid;
        diagnostic_continue = false,
    )
    @test formal["integrand_covariance"]["status"] == "PASS"
    @test formal["full_grid_consistency"]["status"] == "PASS"
    @test length(formal["integrand_covariance"]["evidence_sha256"]) == 64
    @test isempty(diagnostic)

    blocked = Dict{String, Any}(
        "integrand_covariance" => Dict("status" => "NOT_RUN_DOWNSTREAM_BLOCKED"),
        "full_grid_consistency" => Dict("status" => "NOT_RUN_DOWNSTREAM_BLOCKED"),
    )
    blocked_diagnostic = Dict{String, Any}()
    extension._response_qualification_apply_downstream_evidence!(
        blocked,
        blocked_diagnostic,
        false,
        integrand,
        full_grid;
        diagnostic_continue = true,
    )
    @test blocked["integrand_covariance"]["status"] == "NOT_RUN_DOWNSTREAM_BLOCKED"
    @test blocked_diagnostic["integrand_covariance"]["qualification"] == "INDICATIVE_ONLY"
    @test blocked_diagnostic["full_grid_consistency"]["qualification"] == "INDICATIVE_ONLY"
    @test_throws ArgumentError extension._response_qualification_apply_downstream_evidence!(
        formal,
        diagnostic,
        true,
        nothing,
        full_grid;
        diagnostic_continue = false,
    )
end

@testset "AMN-derived physical sewing does not use polar repair" begin
    extension = Base.get_extension(WannierNLQG, :WannierNLQGSymmetrizationExt)
    operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
        false,
    )
    plan = WannierNLQG.SymmetryFoundation.WannierSymmetryPlan(
        [operation],
        ones(ComplexF64, 1, 1, 1),
        zeros(Int, 3, 1, 1),
    )
    amn = RESPONSE_SYMMETRY_IO.WannierAMN(1, 1, 1, ones(ComplexF64, 1, 1, 1))
    chk = RESPONSE_SYMMETRY_IO.WannierCHK(
        1,
        1,
        1,
        (1, 1, 1),
        zeros(1, 3),
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        zeros(1, 3),
        ones(ComplexF64, 1, 1, 1),
    )
    actual = extension._response_build_actual_sewing(
        amn,
        chk,
        plan,
        [operation],
        ones(Int, 1, 1);
        chk_semiunitarity_tolerance = 1.0e-10,
        amn_minimum_singular_value = 1.0e-5,
        amn_maximum_condition_number = 1.0e8,
    )
    @test actual.input_pass
    @test actual.maximum_chk_semiunitarity == 0.0
    @test actual.maximum_subspace_closure == 0.0
    @test actual.maximum_wannier_unitarity == 0.0
    group_law, _ = extension._response_sewing_group_law(
        actual.wannier_sewing,
        chk,
        [operation],
        ones(Int, 1, 1);
        seitz_tolerance = 1.0e-5,
        spinor = false,
    )
    @test group_law == 0.0
end

function response_symmetry_runtime_probe(mode::AbstractString, arguments = String[])
    return mktempdir() do depot
        depot_separator = Sys.iswindows() ? ';' : ':'
        isolated_depot = join((depot, Base.DEPOT_PATH...), depot_separator)
        command =
            `$(Base.julia_cmd()) --startup-file=no --compiled-modules=no --project=$(ROOT) $(RESPONSE_SYMMETRY_RUNTIME_PROBE) $(mode) $(arguments)`
        command = addenv(
            command,
            "JULIA_PROJECT" => ROOT,
            "JULIA_LOAD_PATH" => "@:@stdlib",
            "JULIA_DEPOT_PATH" => isolated_depot,
            "JULIA_PKG_PRECOMPILE_AUTO" => "0",
            "JULIA_NUM_THREADS" => "1",
            "OMP_NUM_THREADS" => "1",
            "OPENBLAS_NUM_THREADS" => "1",
            "VECLIB_MAXIMUM_THREADS" => "1",
        )
        return read(command, String)
    end
end

@testset "ordinary runtime keeps optional symmetry dependencies lazy until reporting" begin
    @test occursin("mode=off", response_symmetry_runtime_probe("off"))
    mktempdir() do directory
        artifact = joinpath(directory, "identity_response_symmetry.json")
        model_digest = open(TEST_MODEL_FILE, "r") do io
            bytes2hex(SHA.sha256(io))
        end
        write(
            artifact,
            """
            {
              "schema": "wanniernlqg.response-symmetry/1.0",
              "provenance": {
                "model": {"sha256": "$(model_digest)"},
                "structure": {"sha256": "$(repeat("0", 64))"}
              },
              "symmetry": {
                "point_group_operations": [{
                  "rotation_fractional": [[1,0,0],[0,1,0],[0,0,1]],
                  "translation_fractional": [0,0,0],
                  "rotation_cartesian": [[1,0,0],[0,1,0],[0,0,1]],
                  "antiunitary": false
                }],
                "checks": {
                  "identity": true,
                  "inverse": true,
                  "closure": true,
                  "atom_mapping": {"pass": true}
                }
              },
              "qualification": {
                "integrand_covariance": {
                  "status": "PASS",
                  "maximum_relative_residual": 0.0,
                  "tolerance": 1.0e-12
                }
              }
            }
            """,
        )
        output = joinpath(directory, "run")
        @test_throws ProcessFailedException response_symmetry_runtime_probe(
            "enabled",
            [artifact, TEST_MODEL_FILE, output, "strict"],
        )
        probe = response_symmetry_runtime_probe(
            "enabled",
            [artifact, TEST_MODEL_FILE, output, "diagnostic"],
        )
        @test occursin("mode=enabled json3=true spglib=true", probe)
    end
    mktempdir() do directory
        _, poscar, _, _ = write_response_test_structures(directory)
        incar = joinpath(directory, "INCAR")
        write(incar, "LNONCOLLINEAR = T\nLSORBIT = T\nMAGMOM = 3*0\n")
        artifact = joinpath(directory, "vasp_response_symmetry.json")
        RESPONSE_SYMMETRY_MODULE.write_response_symmetry_artifact(
            artifact;
            structure_file = poscar,
            structure_format = :poscar,
            model_file = TEST_MODEL_FILE,
            vasp_magnetic_input_file = incar,
            integrand_covariance_status = "PASS",
            covariance_max_relative_residual = 0.0,
        )
        rm(incar)
        output = joinpath(directory, "run_without_incar")
        @test_throws ProcessFailedException response_symmetry_runtime_probe(
            "enabled",
            [artifact, TEST_MODEL_FILE, output, "strict"],
        )
        probe = response_symmetry_runtime_probe(
            "enabled",
            [artifact, TEST_MODEL_FILE, output, "diagnostic"],
        )
        @test occursin("mode=enabled json3=true spglib=true", probe)
        @test !isfile(incar)
    end
end

@testset "response artifact public 1.0 preserves both historical contracts" begin
    fixture_root = joinpath(@__DIR__, "fixtures", "response_symmetry")
    historical = joinpath(fixture_root, "historical_complete_1_1.json")
    legacy_file = joinpath(fixture_root, "historical_diagnostic_1_0.json")
    @test bytes2hex(SHA.sha256(read(historical))) ==
          "7e6cfc2984e463ba6beecfa2e76287550d52056c026b8e988db924a1959fe69a"
    @test bytes2hex(SHA.sha256(read(legacy_file))) ==
          "798e8e6abaf45b1271c40faad67dae321615e0c4157394fef2d38bbc81059d8e"
    previous = RESPONSE_SYMMETRY_IO.read_response_symmetry_artifact(historical)
    legacy = RESPONSE_SYMMETRY_IO.read_response_symmetry_artifact(legacy_file)
    @test previous.schema == "wanniernlqg.response-symmetry/1.1"
    @test previous.cartesian_rotation_policy == "group_invariant_metric"
    @test legacy.diagnostic_only && !legacy.production_eligible && !legacy.sealed
    @test legacy.cartesian_rotation_policy == "legacy_raw_unspecified"
    mktempdir() do directory
        current = deepcopy(previous.payload)
        current["schema"] = "wanniernlqg.response-symmetry/1.0"
        path = joinpath(directory, "current.json")
        write(path, JSON3.write(current))
        restored = RESPONSE_SYMMETRY_IO.read_response_symmetry_artifact(path)
        @test restored.schema == "wanniernlqg.response-symmetry/1.0"
        @test restored.cartesian_rotation_policy == previous.cartesian_rotation_policy
        @test restored.qualification_status == previous.qualification_status
        @test restored.production_eligible == previous.production_eligible
        @test restored.artifact_sha256 == bytes2hex(SHA.sha256(read(path)))
        @test restored.artifact_sha256 != previous.artifact_sha256
        @test length(restored.operations) == length(previous.operations)
        for (a, b) in zip(restored.operations, previous.operations)
            @test a.rotation_fractional == b.rotation_fractional
            @test reinterpret(UInt8, vec(a.rotation_cartesian)) ==
                  reinterpret(UInt8, vec(b.rotation_cartesian))
            @test reinterpret(UInt8, a.translation_fractional) ==
                  reinterpret(UInt8, b.translation_fractional)
            @test a.antiunitary == b.antiunitary
        end
        @test RESPONSE_SYMMETRY_RUNTIME._validate_response_artifact_declared_checks(restored) ==
              RESPONSE_SYMMETRY_RUNTIME._validate_response_artifact_declared_checks(previous)
        # A surviving current-contract field pins parsing to the complete contract.
        for (group, field) in (
            ("provenance", "cartesian_rotation_policy"),
            ("qualification", "production_eligible"),
            ("qualification", "seal"),
            ("qualification", "gates"),
        )
            broken = deepcopy(current)
            delete!(broken[group], field)
            write(path, JSON3.write(broken))
            @test_throws ArgumentError RESPONSE_SYMMETRY_IO.read_response_symmetry_artifact(path)
        end
        for field in
            ("rotation_cartesian_raw", "rotation_cartesian_effective", "cartesian_rotation_use")
            broken = deepcopy(current)
            delete!(broken["symmetry"]["point_group_operations"][1], field)
            write(path, JSON3.write(broken))
            @test_throws ArgumentError RESPONSE_SYMMETRY_IO.read_response_symmetry_artifact(path)
        end
        for field in ("space_group", "point_group", "cartesian_rotation", "tolerance_stability")
            broken = deepcopy(current)
            delete!(broken["symmetry"]["checks"], field)
            write(path, JSON3.write(broken))
            @test_throws ArgumentError RESPONSE_SYMMETRY_IO.read_response_symmetry_artifact(path)
        end
        broken = deepcopy(current)
        broken["symmetry"]["point_group_operations"][1]["rotation_cartesian"][1][1] += 0.25
        write(path, JSON3.write(broken))
        @test_throws ArgumentError RESPONSE_SYMMETRY_IO.read_response_symmetry_artifact(path)
        for schema in ("wanniernlqg.response-symmetry/1.1", "wanniernlqg.response-symmetry/9.0")
            forged = deepcopy(legacy.payload)
            forged["schema"] = schema
            write(path, JSON3.write(forged))
            @test_throws ArgumentError RESPONSE_SYMMETRY_IO.read_response_symmetry_artifact(path)
        end
        mixed = deepcopy(legacy.payload)
        mixed["qualification"]["seal"] = Dict("sealed" => false)
        write(path, JSON3.write(mixed))
        @test_throws ArgumentError RESPONSE_SYMMETRY_IO.read_response_symmetry_artifact(path)
        # Provenance digests retain their original syntax validation under the new URI.
        broken = deepcopy(current)
        broken["provenance"]["model"]["sha256"] = "tampered"
        write(path, JSON3.write(broken))
        @test_throws ArgumentError RESPONSE_SYMMETRY_IO.read_response_symmetry_artifact(path)
    end
end
