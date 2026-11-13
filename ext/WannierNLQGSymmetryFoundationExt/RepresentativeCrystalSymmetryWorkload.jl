using PrecompileTools: @setup_workload, @compile_workload

# Nonmagnetic operation detection and magnetic inventory use distinct Spglib
# branches. A one-atom orthorhombic cell and a one-atom magnetic primitive cell
# enter both through the public API without external files or MPI activation.
@setup_workload let
    @assert Base.get_extension(WannierNLQG, :WannierNLQGSymmetryFoundationExt) === @__MODULE__
    sf = WannierNLQG.SymmetryFoundation
    nonmagnetic = sf.CrystalStructure(Matrix(Diagonal([1.0, 2.0, 3.0])), ["X"], zeros(3, 1))
    magnetic = sf.CrystalStructure(
        2.87 / 2 .* [-1.0 1.0 1.0; 1.0 -1.0 1.0; 1.0 1.0 -1.0],
        ["Fe"],
        zeros(3, 1);
        magnetic_moments_cartesian = reshape([0.0, 0.0, 1.0], 3, 1),
    )
    hexagonal_plane =
        sf.CrystalStructure([1.0 0.0 0.0; -0.5 sqrt(3.0)/2 0.0; 0.0 0.0 10.0], ["X"], zeros(3, 1))
    # This three-site triclinic structure is an actual P1 input. The strict
    # public report checks/classifies its declared identity constraint group.
    identity_operation = Dict(
        "rotation_fractional" => [[1, 0, 0], [0, 1, 0], [0, 0, 1]],
        "translation_fractional" => zeros(3),
        "antiunitary" => false,
        "source_space_group_indices" => [1],
    )
    payload = Dict{String, Any}(
        "provenance" => Dict(
            "include_time_reversal" => false,
            "spglib_version" => string(Base.pkgversion(Spglib)),
            "spglib_symprec_angstrom" => 1.0e-5,
        ),
        "structure" => Dict(
            "lattice_rows_angstrom" => [[1.0, 0.0, 0.0], [0.2, 1.1, 0.0], [0.1, 0.3, 1.3]],
            "elements" => ["X", "Y", "Z"],
            "positions_fractional_columns" =>
                [[0.13, 0.27, 0.39], [0.22, 0.41, 0.58], [0.71, 0.17, 0.83]],
            "magnetic_moments_cartesian_columns" => [zeros(3) for _ in 1:3],
        ),
        "symmetry" => Dict(
            "magnetic" => false,
            "msg_type" => 1,
            "uni_number" => nothing,
            "hall_number" => 1,
            "unitary_operation_count" => 1,
            "antiunitary_operation_count" => 0,
            "space_group_operations" => [identity_operation],
            "point_group_operations" => [deepcopy(identity_operation)],
            "checks" => Dict(
                "space_group" => Dict("translation_tolerance_fractional" => 1.0e-8),
                "tolerance_stability" => Dict("status" => "PASS"),
            ),
        ),
    )
    @compile_workload begin
        operations = sf.detect_symmetry_operations(nonmagnetic; include_time_reversal = false)
        @assert !isempty(operations)
        inventory = sf.detect_magnetic_symmetry_inventory(magnetic; include_time_reversal = true)
        @assert inventory.magnetic && inventory.msg_type == 3
        @assert inventory.unitary_operation_count > 0 && inventory.antiunitary_operation_count > 0
        # These two planning trees feed the same real Band driver captured by
        # the ordinary public workload; no per-space-group signatures are kept.
        crystal_path = WannierNLQG.automatic_kpath(nonmagnetic; kpoints_per_segment = 2)
        plane_path = WannierNLQG.automatic_kpath(
            hexagonal_plane;
            periodic_axes = (1, 2),
            kpoints_per_segment = 2,
        )
        @assert !isempty(crystal_path.nodes) && length(plane_path.nodes) == 4
        report = sf.response_symmetry_group_report(payload; strict = true)
        @assert report["status"] == "RESOLVED"
        @assert report["group_classification"]["structural_space_group"]["international_number"] ==
                1
        @assert report["active_constraint_group"]["group_order"] == 1
    end
end
