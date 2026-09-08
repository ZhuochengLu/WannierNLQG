using LinearAlgebra
using WannierNLQG

const FOUNDATION_EXTENSION_NAME = :WannierNLQGSymmetryFoundationExt
const SYMMETRIZATION_EXTENSION_NAME = :WannierNLQGSymmetrizationExt
const WANNIERIZATION_EXTENSION_NAME = :WannierNLQGWannierizationExt
const FOUNDATION_TRIGGER_NAMES = (:Spglib, :HDF5, :JSON3)
const SYMMETRIZATION_TRIGGER_NAMES = (:HDF5, :JSON3, :EzXML)
const WANNIERIZATION_TRIGGER_NAMES = (:HDF5, :JSON3, :EzXML)
const COLD_TRIGGER_NAMES = (:Spglib, :HDF5, :JSON3, :EzXML)

# Test whether one package module is present in the current process.
function dependency_loaded(name::Symbol)
    return any(module_value -> nameof(module_value) == name, Base.loaded_modules_array())
end

# Import one shared Symmetrization/Wannierization trigger without guessing package paths.
function import_shared_trigger(name::Symbol)
    expression = if name == :HDF5
        :(import HDF5)
    elseif name == :JSON3
        :(import JSON3)
    elseif name == :EzXML
        :(import EzXML)
    else
        error("unknown shared extension trigger $(name)")
    end
    Base.eval(@__MODULE__, expression)
    return nothing
end

function operation_signatures(operations)
    return [
        (
            operation.rotation_fractional,
            operation.translation_fractional,
            operation.rotation_cartesian,
            operation.antiunitary,
        ) for operation in operations
    ]
end

# Require the ordinary parent-package process to remain free of extension triggers.
function assert_cold_parent()
    Base.get_extension(WannierNLQG, FOUNDATION_EXTENSION_NAME) === nothing ||
        error("symmetry-foundation extension activated on the ordinary parent path")
    Base.get_extension(WannierNLQG, SYMMETRIZATION_EXTENSION_NAME) === nothing ||
        error("symmetrization extension activated on the ordinary parent path")
    Base.get_extension(WannierNLQG, WANNIERIZATION_EXTENSION_NAME) === nothing ||
        error("Wannierization extension activated on the ordinary parent path")
    for name in COLD_TRIGGER_NAMES
        dependency_loaded(name) && error("$(name) loaded on the ordinary parent path")
    end
    return nothing
end

# Write one minimal WIN-authoritative mesh-screening input.
function write_mesh_probe(directory::AbstractString)
    win_path = joinpath(directory, "model.win")
    write(
        win_path,
        """
        num_wann = 1
        mp_grid = 2 2 2
        begin unit_cell_cart
        1 0 0
        0 1 0
        0 0 1
        end unit_cell_cart
        begin atoms_frac
        X 0 0 0
        end atoms_frac
        begin projections
        X:s
        end projections
        """,
    )
    return WannierNLQG.Symmetrization.MeshScreenConfig(
        win_file = win_path,
        include_time_reversal = false,
        density_target = 2.0,
        search_radius = 1,
    )
end

# Execute one existing response task without touching the expert subsystem.
function probe_run_path(model_file::AbstractString)
    output_root = mktempdir()
    config = WannierNLQG.Runtime.EffectiveTaskConfig(
        fourier_backend = "direct",
        tasks = [("SC", "Conventional", "Integral")],
        model_file = abspath(model_file),
        case_root = dirname(abspath(model_file)),
        output_root = output_root,
        system_name = "extension_loading_probe",
        k_mesh = (2, 2),
        photon_energies = [0.1],
        fermi_energy = -2.5,
        temperature = 0.0,
        broadening = 0.06,
        broadening_type = "Gaussian",
        denominator_regularization = 0.001,
        spatial_dimension = 2,
        band_window_size = 2,
        tensor_indices = (2, 2, 2),
        progress_enabled = false,
    )
    WannierNLQG.run(config)
    assert_cold_parent()
    return nothing
end

# Activate the expert extension concurrently and check deterministic reuse.
function probe_symmetrization_concurrent_first_call()
    Threads.nthreads() == 4 || error("concurrent probe requires exactly four Julia threads")
    assert_cold_parent()
    mktempdir() do directory
        config = write_mesh_probe(directory)
        results = Vector{Any}(undef, 4)
        @sync for index in eachindex(results)
            Threads.@spawn begin
                results[index] = WannierNLQG.Symmetrization.screen_wannier_mesh(config)
            end
        end
        all(result -> result == first(results), results) ||
            error("concurrent first calls returned different results")
        extension = Base.get_extension(WannierNLQG, SYMMETRIZATION_EXTENSION_NAME)
        extension === nothing && error("symmetrization extension did not activate")
        all(dependency_loaded, FOUNDATION_TRIGGER_NAMES) ||
            error("real symmetry detection did not activate the Foundation trigger set")
        modules_before = Set(Base.loaded_modules_array())
        second = WannierNLQG.Symmetrization.screen_wannier_mesh(config)
        second == first(results) || error("second expert call changed the result")
        Set(Base.loaded_modules_array()) == modules_before ||
            error("second expert call loaded additional modules")
    end
    return nothing
end

# Activate only the Symmetrization extension and keep the detection backend cold.
function probe_symmetrization_partial_activation()
    assert_cold_parent()
    extension, _ = WannierNLQG.Symmetrization._load_symmetrization_extension!()
    nameof(extension) == SYMMETRIZATION_EXTENSION_NAME ||
        error("unexpected Symmetrization extension module")
    all(dependency_loaded, SYMMETRIZATION_TRIGGER_NAMES) ||
        error("Symmetrization trigger set is incomplete")
    dependency_loaded(:Spglib) && error("Symmetrization activation loaded Spglib")
    Base.get_extension(WannierNLQG, FOUNDATION_EXTENSION_NAME) === nothing ||
        error("Symmetrization activation loaded the Foundation extension")
    return nothing
end

# Activate only the Wannierization trigger set and keep the detection backend cold.
function probe_wannierization_partial_activation()
    assert_cold_parent()
    extension, _ = WannierNLQG.Wannierization._load_wannierization_extension!()
    nameof(extension) == WANNIERIZATION_EXTENSION_NAME ||
        error("unexpected Wannierization extension module")
    all(dependency_loaded, WANNIERIZATION_TRIGGER_NAMES) ||
        error("Wannierization trigger set is incomplete")
    dependency_loaded(:Spglib) && error("Wannierization activation loaded Spglib")
    Base.get_extension(WannierNLQG, FOUNDATION_EXTENSION_NAME) === nothing ||
        error("Wannierization activation loaded the Foundation extension")
    return nothing
end

# Activate the foundation-owned detection route concurrently and check reuse.
function probe_foundation_concurrent_first_call()
    Threads.nthreads() == 4 || error("concurrent probe requires exactly four Julia threads")
    assert_cold_parent()
    structure = WannierNLQG.SymmetryFoundation.CrystalStructure(
        Matrix{Float64}(I, 3, 3),
        ["X"],
        zeros(3, 1),
    )
    results = Vector{Any}(undef, 4)
    @sync for index in eachindex(results)
        Threads.@spawn begin
            results[index] = WannierNLQG.SymmetryFoundation.detect_symmetry_operations(
                structure;
                include_time_reversal = false,
            )
        end
    end
    signatures = operation_signatures.(results)
    all(signature -> signature == first(signatures), signatures) ||
        error("concurrent foundation calls returned different results")
    Base.get_extension(WannierNLQG, FOUNDATION_EXTENSION_NAME) === nothing &&
        error("symmetry-foundation extension did not activate")
    modules_before = Set(Base.loaded_modules_array())
    second = WannierNLQG.SymmetryFoundation.detect_symmetry_operations(
        structure;
        include_time_reversal = false,
    )
    operation_signatures(second) == first(signatures) ||
        error("second foundation call changed the result")
    Set(Base.loaded_modules_array()) == modules_before ||
        error("second foundation call loaded additional modules")
    return nothing
end

# Enter each facade with all weak-dependency triggers still cold in this calling frame.
function probe_operator_bundle_function_entry()
    assert_cold_parent()
    filename = joinpath(@__DIR__, "fixtures", "schema_compatibility", "packed_6_3.h5")
    first_manifest = WannierNLQG.IO.read_real_space_operator_bundle_manifest(filename)
    first_manifest.num_orbitals > 0 || error("operator facade did not read the fixture")
    second_manifest = WannierNLQG.IO.read_real_space_operator_bundle_manifest(filename)
    first_manifest.scientific_content_sha256 == second_manifest.scientific_content_sha256 ||
        error("same-frame operator manifest read changed content")
    return nothing
end

function probe_foundation_function_entry()
    assert_cold_parent()
    WannierNLQG.SymmetryFoundation.band_representation_schema_version() == "1.0" ||
        error("foundation facade returned the wrong public schema")
    WannierNLQG.SymmetryFoundation.band_representation_schema_version() == "1.0" ||
        error("same-frame foundation call changed schema")
    return nothing
end

function probe_symmetrization_function_entry()
    assert_cold_parent()
    config = WannierNLQG.Symmetrization.MeshScreenConfig(win_file = "unused.win", dimension = 4)
    # Reach the extension's own argument check without starting symmetry detection.
    for _ in 1:2
        failure = try
            WannierNLQG.Symmetrization.screen_wannier_mesh(config)
            nothing
        catch exception
            exception
        end
        failure isa ArgumentError &&
        occursin("dimension must be 2 or 3", sprint(showerror, failure)) ||
            error("symmetrization facade did not reach its argument contract: $(failure)")
    end
    return nothing
end

function probe_wannierization_function_entry()
    assert_cold_parent()
    mktempdir() do directory
        for index in 1:2
            filename = joinpath(directory, "empty-u-$(index).h5")
            WannierNLQG.Wannierization.write_wannierization_u_convergence_diagnostics_hdf5(
                filename,
                NamedTuple[],
                Array{ComplexF64, 3}[],
                [1],
            )
            isfile(filename) && filesize(filename) > 0 ||
                error("Wannierization facade did not write diagnostics")
        end
    end
    return nothing
end

function probe_response_json_function_entry()
    assert_cold_parent()
    filename = joinpath(@__DIR__, "fixtures", "response_symmetry", "historical_diagnostic_1_0.json")
    for _ in 1:2
        artifact = WannierNLQG.IO.read_response_symmetry_artifact(filename)
        artifact.schema == "wanniernlqg.response-symmetry/1.0" ||
            error("JSON facade read the wrong schema")
        artifact.diagnostic_only && !artifact.production_eligible ||
            error("JSON facade changed diagnostic eligibility")
    end
    return nothing
end

mode = only(ARGS[1:1])
if mode in ("operator_bundle_function_entry", "operator_bundle_cached_entry")
    probe_operator_bundle_function_entry()
elseif mode in ("foundation_function_entry", "foundation_cached_entry")
    probe_foundation_function_entry()
elseif mode == "symmetrization_function_entry"
    probe_symmetrization_function_entry()
elseif mode == "wannierization_function_entry"
    probe_wannierization_function_entry()
elseif mode == "response_json_function_entry"
    probe_response_json_function_entry()
elseif mode == "import"
    assert_cold_parent()
elseif mode == "run"
    length(ARGS) == 2 || error("run probe requires a model path")
    probe_run_path(ARGS[2])
elseif mode == "symmetrization_concurrent"
    probe_symmetrization_concurrent_first_call()
elseif mode == "foundation_concurrent"
    probe_foundation_concurrent_first_call()
elseif mode == "symmetrization_partial"
    probe_symmetrization_partial_activation()
elseif mode == "wannierization_partial"
    probe_wannierization_partial_activation()
elseif mode == "operator_trigger_order"
    length(ARGS) == 2 || error("operator_trigger_order requires a comma-separated order")
    assert_cold_parent()
    order = Symbol.(split(ARGS[2], ','))
    Set(order) == Set((:HDF5, :JSON3)) || error("invalid operator trigger order")
    import_shared_trigger(first(order))
    Base.get_extension(WannierNLQG, :WannierNLQGOperatorBundleExt) === nothing ||
        error("one trigger activated the two-trigger operator extension")
    import_shared_trigger(last(order))
    Base.get_extension(WannierNLQG, :WannierNLQGOperatorBundleExt) === nothing &&
        error("both operator triggers did not activate the extension")
    dependency_loaded(:Spglib) && error("operator activation loaded Spglib")
    dependency_loaded(:EzXML) && error("operator activation loaded EzXML")
elseif mode == "shared_two_triggers"
    assert_cold_parent()
    import_shared_trigger(:HDF5)
    import_shared_trigger(:JSON3)
    Base.get_extension(WannierNLQG, SYMMETRIZATION_EXTENSION_NAME) === nothing ||
        error("two shared triggers activated the Symmetrization extension")
    Base.get_extension(WannierNLQG, WANNIERIZATION_EXTENSION_NAME) === nothing ||
        error("two shared triggers activated the Wannierization extension")
elseif mode == "shared_trigger_order"
    length(ARGS) == 2 || error("shared_trigger_order requires a comma-separated order")
    assert_cold_parent()
    order = Symbol.(split(ARGS[2], ','))
    Set(order) == Set(SYMMETRIZATION_TRIGGER_NAMES) || error("invalid shared trigger order")
    foreach(import_shared_trigger, order)
    Base.get_extension(WannierNLQG, SYMMETRIZATION_EXTENSION_NAME) === nothing &&
        error("all shared triggers did not activate the Symmetrization extension")
    Base.get_extension(WannierNLQG, WANNIERIZATION_EXTENSION_NAME) === nothing &&
        error("all shared triggers did not activate the Wannierization extension")
elseif mode == "partial_foundation"
    assert_cold_parent()
    import Spglib
    Base.get_extension(WannierNLQG, FOUNDATION_EXTENSION_NAME) === nothing ||
        error("one trigger activated the three-trigger extension")
    structure = WannierNLQG.SymmetryFoundation.CrystalStructure(
        Matrix{Float64}(I, 3, 3),
        ["X"],
        zeros(3, 1),
    )
    WannierNLQG.SymmetryFoundation.detect_symmetry_operations(
        structure;
        include_time_reversal = false,
    )
    all(dependency_loaded, FOUNDATION_TRIGGER_NAMES) ||
        error("expert call did not complete trigger loading")
elseif mode == "all"
    assert_cold_parent()
    import Spglib
    import HDF5
    import JSON3
    Base.get_extension(WannierNLQG, FOUNDATION_EXTENSION_NAME) === nothing &&
        error("all triggers did not activate the symmetry-foundation extension")
else
    error("unknown extension lifecycle probe mode $(repr(mode))")
end

println("SYMMETRY_FOUNDATION_EXTENSION_LIFECYCLE_PASS mode=$(mode)")
