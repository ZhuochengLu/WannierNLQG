const FULL_UIU_OPERATOR_BUNDLE_ALGORITHM_VERSION = "raw-same-gauge-schema-6.3-v2-source-neighbor-order"

"""Resolve and validate the full-uIu bundle input and output paths."""
function _full_uiu_bundle_paths(config::FullUIUDerivativeOperatorBundleConfig)
    values = Dict(
        "tb_file" => abspath(config.tb_file),
        "chk_file" => abspath(config.chk_file),
        "eig_file" => abspath(config.eig_file),
        "mmn_file" => abspath(config.mmn_file),
        "uiu_file" => abspath(config.uiu_file),
        "uiu_provenance_json" => abspath(config.uiu_provenance_json),
        "output_bundle_file" => abspath(config.output_bundle_file),
    )
    for name in ("tb_file", "chk_file", "eig_file", "mmn_file", "uiu_file", "uiu_provenance_json")
        isfile(values[name]) || throw(ArgumentError("$(name) does not exist: $(values[name])"))
    end
    input_paths = [values[name] for name in keys(values) if name != "output_bundle_file"]
    values["output_bundle_file"] in input_paths &&
        throw(ArgumentError("operator-bundle output must not overwrite a scientific input"))
    ispath(values["output_bundle_file"]) &&
        !config.overwrite &&
        throw(
            ArgumentError(
                "refusing to overwrite full uIu operator bundle: $(values["output_bundle_file"])",
            ),
        )
    config.support_tolerance >= 0.0 || throw(ArgumentError("support_tolerance must be nonnegative"))
    config.wigner_seitz_tolerance > 0.0 ||
        throw(ArgumentError("wigner_seitz_tolerance must be positive"))
    config.wigner_seitz_search_size > 0 ||
        throw(ArgumentError("wigner_seitz_search_size must be positive"))
    return values
end

"""Validate the uIu provenance sidecar against the selected MMN and uIu files."""
function _full_uiu_bundle_uiu_provenance(paths)
    payload = JSON3.read(read(paths["uiu_provenance_json"], String))
    String(payload.schema) == WANNIER_UIU_GENERATION_SCHEMA || throw(
        ArgumentError("PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: uIu provenance schema differs"),
    )
    String(payload.schema_version) == WANNIER_UIU_GENERATION_SCHEMA_VERSION || throw(
        ArgumentError("PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: uIu provenance version differs"),
    )
    (
        hasproperty(payload, :band_gauge_rotation_sha256) ||
        hasproperty(payload, :band_gauge_rotation_semantics)
    ) && throw(ArgumentError("UIU_LEGACY_ROTATION_FIELDS_REQUIRE_MIGRATION"))
    required = (
        :source_band_gauge,
        :target_band_gauge,
        :band_frame_transform_definition,
        :band_frame_contract_definition,
        :band_frame_contract,
        :gauge_definition,
    )
    all(name -> hasproperty(payload, name), required) ||
        throw(ArgumentError("PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: incomplete uIu contract"))
    Bool(payload.passed) && Bool(payload.physical_overlap_available) ||
        throw(ArgumentError("PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: uIu qualification failed"))
    hasproperty(payload, :content_authentication) &&
    String(payload.content_authentication) == "NOT_PERFORMED" ||
        throw(ArgumentError("UIU_EXPLICIT_MIGRATION_REQUIRED"))
    reference_path = String(payload.references_hdf5)
    isfile(reference_path) || throw(ArgumentError("UIU_COMPLETE_SOURCE_REFERENCE_REQUIRED"))
    HDF5.h5open(reference_path, "r") do file
        haskey(file, "oracle_mmn_reference") ||
            throw(ArgumentError("UIU_COMPLETE_ORACLE_REFERENCE_REQUIRED"))
        IO.validate_scientific_source_collection(
            Dict("MMN" => paths["mmn_file"]),
            read_scientific_input_reference_hdf5(file, "oracle_mmn_reference"),
        )
    end
    header = IO.read_wannier_uiu_header(paths["uiu_file"])
    (header.num_bands, header.num_kpts, header.num_neighbors) ==
    (Int(payload.num_bands), Int(payload.num_kpts), Int(payload.num_neighbors)) ||
        throw(ArgumentError("UIU_PROVENANCE_DIMENSION_MISMATCH"))
    return payload
end

"""Extract home-cell Wannier centers from the position operator."""
function _full_uiu_bundle_position_centers(model::TightBindingModel)
    home =
        only(findall(index -> all(iszero, @view(model.r_vectors[:, index])), 1:model.num_r_vectors))
    centers = zeros(Float64, model.num_orbitals, 3)
    for orbital in 1:model.num_orbitals, direction in 1:3
        value = model.position_r[orbital, orbital, direction, home] / model.r_degeneracies[home]
        abs(imag(value)) <= 1.0e-10 || throw(
            ArgumentError("full uIu bundle position centers have non-negligible imaginary parts"),
        )
        centers[orbital, direction] = real(value)
    end
    return centers
end

"""Require TB and CHK centers to agree modulo lattice translations."""
function _full_uiu_bundle_center_gate(model::TightBindingModel, chk::WannierCHK)
    model.num_orbitals == chk.num_orbitals ||
        throw(ArgumentError("full uIu bundle TB and CHK Wannier dimensions differ"))
    isapprox(model.lattice, chk.real_lattice; atol = 1.0e-8, rtol = 0.0) ||
        throw(ArgumentError("full uIu bundle TB and CHK real lattices differ"))
    final_cartesian = _full_uiu_bundle_position_centers(model)
    inverse_lattice = inv(model.lattice)
    raw_fractional = chk.wannier_centers_cart * inverse_lattice
    final_fractional = final_cartesian * inverse_lattice
    delta = raw_fractional .- final_fractional
    reduced = delta .- round.(delta)
    maximum(abs, reduced; init = 0.0) <= 1.0e-7 ||
        throw(ArgumentError("full uIu bundle TB and CHK Wannier centers differ modulo lattice"))
    shifts = round.(Int, delta)
    return (
        raw_cartesian = copy(chk.wannier_centers_cart),
        raw_fractional,
        final_cartesian,
        final_fractional,
        shifts,
    )
end

"""Restore serialized degeneracy weighting for a derivative operator."""
function _full_uiu_bundle_serialized_derivative(values, degeneracies)
    output = copy(values)
    length(degeneracies) == size(output, ndims(output)) ||
        throw(ArgumentError("full uIu derivative operator and TB R support differ"))
    for r_index in eachindex(degeneracies)
        selectdim(output, ndims(output), r_index) .*= degeneracies[r_index]
    end
    return output
end

"""Build the symmetry metadata for every full-uIu bundle operator."""
function _full_uiu_bundle_operator_specs()
    return Dict(
        REAL_SPACE_HAMILTONIAN => RealSpaceOperatorSymmetrySpec(REAL_SPACE_HAMILTONIAN, 0, 1, 1),
        REAL_SPACE_POSITION => RealSpaceOperatorSymmetrySpec(REAL_SPACE_POSITION, 1, -1, 1),
        REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION =>
            RealSpaceOperatorSymmetrySpec(REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION, 1, -1, 1),
        REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP => RealSpaceOperatorSymmetrySpec(
            REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP,
            1,
            1,
            -1,
        ),
        REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR =>
            RealSpaceOperatorSymmetrySpec(REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR, 2, 1, 1),
        REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP =>
            RealSpaceOperatorSymmetrySpec(REAL_SPACE_AXIAL_DERIVATIVE_OVERLAP, 1, 1, -1),
        REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP =>
            RealSpaceOperatorSymmetrySpec(REAL_SPACE_SYMMETRIC_DERIVATIVE_OVERLAP, 2, 1, 1),
    )
end

"""
    prepare_full_uiu_derivative_operator_bundle(config)

Build and atomically validate a same-gauge operator bundle with full uIu derivatives.
"""
function prepare_full_uiu_derivative_operator_bundle(config::FullUIUDerivativeOperatorBundleConfig)
    paths = _full_uiu_bundle_paths(config)
    inputs = [path for (name, path) in paths if name != "output_bundle_file"]
    return with_native_source_lifetime(inputs) do
        _prepare_full_uiu_derivative_operator_bundle(config, paths)
    end
end

"""Construct the full uIu derivative payload inside its caller's verified input scope."""
function _prepare_full_uiu_derivative_operator_bundle(
    config::FullUIUDerivativeOperatorBundleConfig,
    paths,
)
    uiu_provenance = _full_uiu_bundle_uiu_provenance(paths)
    paired_tb_observation=IO.observe_scientific_source(realpath(paths["tb_file"]))
    model = IO.read_wannier_tb(paths["tb_file"])
    chk = IO.read_wannier_chk(paths["chk_file"])
    eig = IO.read_wannier_eig(paths["eig_file"])
    mmn = IO.read_wannier_mmn(paths["mmn_file"])
    header = IO.read_wannier_uiu_header(paths["uiu_file"])
    header.num_bands == chk.num_bands &&
    header.num_kpts == chk.num_kpts &&
    header.num_neighbors == mmn.num_neighbors ||
        throw(ArgumentError("PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: uIu dimensions differ"))
    eig.num_bands == chk.num_bands && eig.num_kpts == chk.num_kpts ||
        throw(ArgumentError("full uIu bundle EIG dimensions differ from CHK"))
    mmn.num_bands == chk.num_bands && mmn.num_kpts == chk.num_kpts ||
        throw(ArgumentError("full uIu bundle MMN dimensions differ from CHK"))
    centers = _full_uiu_bundle_center_gate(model, chk)
    derivative_set = _construct_full_uiu_wannier_derivative_operators(
        model,
        chk,
        eig,
        mmn,
        paths["uiu_file"];
        support_tolerance = config.support_tolerance,
        wigner_seitz_tolerance = config.wigner_seitz_tolerance,
        search_size = config.wigner_seitz_search_size,
        wannier_centers_cartesian = centers.final_cartesian,
    )
    derivative_set.r_vectors == model.r_vectors ||
        throw(ArgumentError("full uIu derivative operators do not share TB R support"))
    specs = _full_uiu_bundle_operator_specs()
    operators = Dict{RealSpaceOperatorKind, RealSpaceOperator}(
        REAL_SPACE_HAMILTONIAN => RealSpaceOperator(
            specs[REAL_SPACE_HAMILTONIAN],
            model.r_vectors,
            model.hamiltonian_r,
        ),
        REAL_SPACE_POSITION =>
            RealSpaceOperator(specs[REAL_SPACE_POSITION], model.r_vectors, model.position_r),
    )
    for (kind, values) in derivative_set.matrices
        operators[kind] = RealSpaceOperator(
            specs[kind],
            model.r_vectors,
            _full_uiu_bundle_serialized_derivative(values, model.r_degeneracies),
        )
    end
    input_evidence = Dict(
        name => Dict(
            "status" => "provided",
            "path" => paths[name],
            "size_bytes" => filesize(paths[name]),
        ) for name in
        ("tb_file", "chk_file", "eig_file", "mmn_file", "uiu_file", "uiu_provenance_json")
    )
    geometry = Dict(
        "wannier_center_policy" => "keep_input",
        "real_space_replica_policy" => "input",
        "production_eligible" => true,
        "minimum_distance_materialized" => false,
        "mp_grid" => collect(chk.mp_grid),
        "wannier_center_tolerance" => 1.0e-7,
        "wigner_seitz_tolerance" => config.wigner_seitz_tolerance,
        "wigner_seitz_search_size" => config.wigner_seitz_search_size,
        "raw_wannier_centers_cartesian" => centers.raw_cartesian,
        "raw_wannier_centers_fractional" => centers.raw_fractional,
        "final_wannier_centers_cartesian" => centers.final_cartesian,
        "final_wannier_centers_fractional" => centers.final_fractional,
        "center_alignment_lattice_shifts" => centers.shifts,
        "replica_mapping_reference" => "stored_r_vectors_and_degeneracies",
    )
    provenance = Dict(
        "wanniernlqg_version" => string(pkgversion(WannierNLQG)),
        "julia_version" => string(VERSION),
        "input_files" => input_evidence,
        "operator_construction" => FULL_UIU_OPERATOR_BUNDLE_ALGORITHM_VERSION,
        "source_neighbor_order_contract" => _streamed_neighbor_order_contract(
            match_finite_difference_stencil_to_mmn(build_finite_difference_stencil(chk), chk, mmn),
            chk.num_kpts,
        ),
        "symmetrization" => "not_applied",
        "tb_gauge" => "preserved",
        "derivative_overlap_source" => "neighbor_pair_overlap",
        "derivative_overlap_completeness" => "full_hilbert_space",
        "content_authentication" => "NOT_PERFORMED",
        "derivative_overlap_algorithm_version" => IO.FULL_DERIVATIVE_OVERLAP_ALGORITHM_VERSION,
        "uiu_generation_algorithm_version" => String(uiu_provenance.algorithm_version),
        "uiu_generation_input_definition" => String(uiu_provenance.input_definition),
    )
    symmetry = Dict("symmetrization_status" => "not_provided", "selected_operation_count" => 0)
    receipt = IO.write_real_space_operator_bundle(
        paths["output_bundle_file"],
        model.lattice,
        model.r_degeneracies,
        operators;
        profile = :derivative,
        content_authentication = false,
        return_receipt = true,
        overwrite = config.overwrite,
        paired_tb_file = paths["tb_file"],
        paired_tb_expected_state = paired_tb_observation,
        provenance,
        symmetry,
        geometry,
        diagnostics = Dict(
            "full_uiu_derivative_overlap" => true,
            "uiu_generation_status" => String(uiu_provenance.status),
        ),
    )
    return FullUIUDerivativeOperatorBundleResult(
        paths["output_bundle_file"],
        receipt.publication_identity,
        Dict(name => paths[name] for name in keys(input_evidence)),
        "NOT_PERFORMED",
    )
end
