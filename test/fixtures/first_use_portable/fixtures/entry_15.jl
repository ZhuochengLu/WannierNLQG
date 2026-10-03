using Test
using LinearAlgebra
using JSON3
using Serialization

const PUBLIC_S = WannierNLQG.SymmetryFoundation
const PUBLIC_IO = WannierNLQG.IO
const PUBLIC_TARGET = Main.TARGET
# Frozen dependency metadata is input data, not early backend activation.
const FROZEN_SPGLIB_VERSION = "1.2.0"

include(joinpath(pkgdir(WannierNLQG), "test", "BandPublicSchemaTestSupport.jl"))

function prepared_public_fixture()
    directory = joinpath(dirname(Main.RECEIPT), "prepared_public_fixture")
    mkpath(directory)
    path, preparation = BandPublicSchemaTestSupport.write_prepared_time_reversal_fixture(directory)
    @test preparation !== nothing
    representation = PUBLIC_S.read_band_representation_hdf5(path)
    @test representation.schema_version == "1.0"
    @test maximum(abs, representation.sewing_matrices) > 0
    return path, representation
end

function p1_group_payload()
    identity_operation = Dict(
        "rotation_fractional" => [[1, 0, 0], [0, 1, 0], [0, 0, 1]],
        "translation_fractional" => [0.0, 0.0, 0.0],
        "antiunitary" => false,
        "source_space_group_indices" => [1],
    )
    return Dict{String, Any}(
        "provenance" => Dict(
            "include_time_reversal" => false,
            "spglib_version" => FROZEN_SPGLIB_VERSION,
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
end

const FROZEN_PREPARATION_ARGUMENTS = Main.FirstUsePortableSupport.input("arguments/fixture_1.jls")
const FROZEN_PREPARATION_INPUT =
    Main.FirstUsePortableSupport.input("assets/additional_2/frozen_reader_input.h5")

# Reuse independently captured native reader inputs, never call public preparation
# or a reader to populate arguments in this first-use process.
function frozen_completed_public_fixture()
    arguments = Main.FirstUsePortableSupport.deserialize_input(FROZEN_PREPARATION_ARGUMENTS)
    representation = only(arguments.remaining_arguments)
    Base.get_extension(WannierNLQG, :WannierNLQGSymmetryFoundationExt) === nothing ||
        error("fixture deserialization activated the target Foundation backend")
    representation isa PUBLIC_S.BandRepresentation || error("unexpected frozen representation type")
    maximum(abs, representation.sewing_matrices) > 0 || error("invalid zero fixture")
    return FROZEN_PREPARATION_INPUT, representation
end
Base.get_extension(WannierNLQG, :WannierNLQGSymmetryFoundationExt) === nothing ||
    error("fixture support prematurely activated target Foundation backend")

if PUBLIC_TARGET == :band_representation_schema_version
    actual = PUBLIC_S.band_representation_schema_version()
    @test actual == "1.0"
elseif PUBLIC_TARGET == :symmetry_detection_backend_provenance
    actual = PUBLIC_S.symmetry_detection_backend_provenance()
    @test actual.package == "Spglib"
    @test actual.version == FROZEN_SPGLIB_VERSION
elseif PUBLIC_TARGET == :build_band_product_table
    raw = BandPublicSchemaTestSupport.raw_time_reversal_representation_fixture()
    actual = PUBLIC_S.build_band_product_table(raw.operations, raw.spinor)
    @test actual !== nothing
    @test maximum(abs, raw.sewing_matrices) > 0
elseif PUBLIC_TARGET == :configure_band_qualification_window!
    raw = BandPublicSchemaTestSupport.raw_time_reversal_representation_fixture()
    actual = PUBLIC_S.configure_band_qualification_window!(raw, (-0.5, 0.5))
    @test actual === raw
    @test actual.conventions["qualification_window_min_ev"] == "-0.5"
    @test actual.conventions["qualification_window_max_ev"] == "0.5"
elseif PUBLIC_TARGET == :validate_band_representation
    raw = BandPublicSchemaTestSupport.raw_time_reversal_representation_fixture()
    actual = PUBLIC_S.validate_band_representation(
        raw;
        absolute_tolerance = 1.0e-8,
        oracle_excess_tolerance = 1.0e-8,
        require_oracle = false,
    )
    @test actual.passed
    @test all(isfinite, actual.maximum_group_law_residuals)
    @test maximum(abs, raw.sewing_matrices) > 0
elseif PUBLIC_TARGET == :read_band_representation_preparation_hdf5
    path, representation = frozen_completed_public_fixture()
    actual = PUBLIC_S.read_band_representation_preparation_hdf5(path, representation)
    @test actual !== nothing
    @test maximum(abs, representation.sewing_matrices) > 0
elseif PUBLIC_TARGET == :validate_public_band_representation_contract
    _, representation = frozen_completed_public_fixture()
    actual = PUBLIC_S.validate_public_band_representation_contract(representation)
    @test actual === nothing
    @test representation.schema_version == "1.0"
elseif PUBLIC_TARGET == :validate_unified_representation_mode_contract
    _, representation = frozen_completed_public_fixture()
    actual = PUBLIC_S.validate_unified_representation_mode_contract(representation)
    @test actual === nothing
    @test representation.conventions["effective_wannierization_mode"] == "symmetry_adapted"
elseif PUBLIC_TARGET == :write_band_representation_summary
    raw = BandPublicSchemaTestSupport.raw_time_reversal_representation_fixture()
    validation = PUBLIC_S.validate_band_representation(
        raw;
        absolute_tolerance = 1.0e-8,
        oracle_excess_tolerance = 1.0e-8,
        require_oracle = false,
    )
    @test validation.passed
    path = joinpath(dirname(Main.RECEIPT), "band_summary.json")
    actual = PUBLIC_S.write_band_representation_summary(path, raw, validation; overwrite = false)
    @test isfile(path)
    content = JSON3.read(read(path, String))
    @test content["passed"] === true
    @test content["num_bands"] == 2
    @test content["num_kpoints"] == 2
elseif PUBLIC_TARGET == :detect_tb_compatibility_symmetry_operations
    include(joinpath(pkgdir(WannierNLQG), "test", "support", "TBDetectionInventorySupport.jl"))
    fixtures = detection_fixtures(PUBLIC_S)
    structure = only(last.(filter(pair -> first(pair) == "GeS", fixtures)))
    actual = PUBLIC_S.detect_tb_compatibility_symmetry_operations(
        structure;
        include_time_reversal = true,
    )
    @test length(actual) >= 2
    @test any(op -> op.antiunitary, actual)
elseif PUBLIC_TARGET == :response_symmetry_group_report
    actual = PUBLIC_S.response_symmetry_group_report(p1_group_payload(); strict = true)
    @test actual["status"] == "RESOLVED"
    @test actual["group_classification"]["structural_space_group"]["international_number"] == 1
    @test actual["active_constraint_group"]["group_order"] == 1
else
    error("PUBLIC_FACADE_FIXTURE_NOT_REGISTERED: $(PUBLIC_TARGET)")
end

println("PUBLIC_FACADE_VALID ", PUBLIC_TARGET)
