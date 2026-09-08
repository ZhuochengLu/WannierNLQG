const EXACT_WANNIER_OPERATOR_BUNDLE_ALGORITHM_VERSION = "raw-same-gauge-schema-6.3-v1"

"""Resolve and validate the exact-bundle input and output paths."""
function _exact_bundle_paths(config::ExactWannierOperatorBundleConfig)
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
                "refusing to overwrite exact operator bundle: $(values["output_bundle_file"])",
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
function _exact_bundle_uiu_provenance(paths)
    payload = JSON3.read(read(paths["uiu_provenance_json"], String))
    String(payload.schema) == WANNIER_UIU_GENERATION_SCHEMA || throw(
        ArgumentError("PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: uIu provenance schema differs"),
    )
    String(payload.schema_version) in ("1.0", "1.2") || throw(
        ArgumentError("PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: uIu provenance version differs"),
    )
    # Distinguish the frame-aware public layout from earlier incomplete 1.0
    # payloads. Historical 1.2 retains its original checks below; this layout
    # discriminator does not introduce a new frame-qualification algorithm.
    if String(payload.schema_version) == "1.0"
        required = (
            :source_band_gauge,
            :target_band_gauge,
            :band_frame_transform_sha256,
            :band_frame_contract_sha256,
            :band_frame_contract,
            :gauge_artifact_sha256,
        )
        all(name -> hasproperty(payload, name), required) || throw(
            ArgumentError(
                "PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: incomplete current uIu contract",
            ),
        )
    end
    Bool(payload.passed) && Bool(payload.physical_overlap_available) ||
        throw(ArgumentError("PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: uIu qualification failed"))
    uiu_sha256 = sha256_file(paths["uiu_file"])
    String(payload.output_sha256) == uiu_sha256 || throw(
        ArgumentError("PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: uIu hash differs from sidecar"),
    )
    input_hashes = Dict{String, String}(
        String(name) => String(value) for (name, value) in pairs(payload.input_sha256)
    )
    mmn_sha256 = sha256_file(paths["mmn_file"])
    get(input_hashes, "ORACLE_MMN", "MISSING") == mmn_sha256 || throw(
        ArgumentError(
            "PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: MMN is not the qualified same-source oracle",
        ),
    )
    return payload, uiu_sha256
end

"""Extract home-cell Wannier centers from the position operator."""
function _exact_bundle_position_centers(model::TightBindingModel)
    home =
        only(findall(index -> all(iszero, @view(model.r_vectors[:, index])), 1:model.num_r_vectors))
    centers = zeros(Float64, model.num_orbitals, 3)
    for orbital in 1:model.num_orbitals, direction in 1:3
        value = model.position_r[orbital, orbital, direction, home] / model.r_degeneracies[home]
        abs(imag(value)) <= 1.0e-10 || throw(
            ArgumentError("exact bundle position centers have non-negligible imaginary parts"),
        )
        centers[orbital, direction] = real(value)
    end
    return centers
end

"""Require TB and CHK centers to agree modulo lattice translations."""
function _exact_bundle_center_gate(model::TightBindingModel, chk::WannierCHK)
    model.num_orbitals == chk.num_orbitals ||
        throw(ArgumentError("exact bundle TB and CHK Wannier dimensions differ"))
    isapprox(model.lattice, chk.real_lattice; atol = 1.0e-8, rtol = 0.0) ||
        throw(ArgumentError("exact bundle TB and CHK real lattices differ"))
    final_cartesian = _exact_bundle_position_centers(model)
    inverse_lattice = inv(model.lattice)
    raw_fractional = chk.wannier_centers_cart * inverse_lattice
    final_fractional = final_cartesian * inverse_lattice
    delta = raw_fractional .- final_fractional
    reduced = delta .- round.(delta)
    maximum(abs, reduced; init = 0.0) <= 1.0e-7 ||
        throw(ArgumentError("exact bundle TB and CHK Wannier centers differ modulo lattice"))
    shifts = round.(Int, delta)
    return (
        raw_cartesian = copy(chk.wannier_centers_cart),
        raw_fractional,
        final_cartesian,
        final_fractional,
        shifts,
    )
end

"""Hash the real-space support and replica degeneracies used by the bundle."""
function _exact_bundle_replica_digest(model::TightBindingModel)
    buffer = IOBuffer()
    write(buffer, reinterpret(UInt8, vec(Int64.(model.r_vectors))))
    write(buffer, reinterpret(UInt8, Int64.(model.r_degeneracies)))
    return bytes2hex(SHA.sha256(take!(buffer)))
end

"""Restore serialized degeneracy weighting for a derivative operator."""
function _exact_bundle_serialized_derivative(values, degeneracies)
    output = copy(values)
    length(degeneracies) == size(output, ndims(output)) ||
        throw(ArgumentError("exact derivative operator and TB R support differ"))
    for r_index in eachindex(degeneracies)
        selectdim(output, ndims(output), r_index) .*= degeneracies[r_index]
    end
    return output
end

"""Build the symmetry metadata for every exact-bundle operator."""
function _exact_bundle_operator_specs()
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
    prepare_exact_wannier_operator_bundle(config)

Build and atomically validate a same-gauge operator bundle with full uIu derivatives.
"""
function prepare_exact_wannier_operator_bundle(config::ExactWannierOperatorBundleConfig)
    paths = _exact_bundle_paths(config)
    uiu_provenance, uiu_sha256 = _exact_bundle_uiu_provenance(paths)
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
        throw(ArgumentError("exact bundle EIG dimensions differ from CHK"))
    mmn.num_bands == chk.num_bands && mmn.num_kpts == chk.num_kpts ||
        throw(ArgumentError("exact bundle MMN dimensions differ from CHK"))
    centers = _exact_bundle_center_gate(model, chk)
    derivative_set = _construct_exact_wannier_derivative_operators(
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
        throw(ArgumentError("exact derivative operators do not share TB R support"))
    specs = _exact_bundle_operator_specs()
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
            _exact_bundle_serialized_derivative(values, model.r_degeneracies),
        )
    end
    input_sha256 = Dict(
        name => sha256_file(paths[name]) for name in
        ("tb_file", "chk_file", "eig_file", "mmn_file", "uiu_file", "uiu_provenance_json")
    )
    input_evidence = Dict(
        name => Dict(
            "status" => "provided",
            "path" => paths[name],
            "size_bytes" => filesize(paths[name]),
            "sha256" => input_sha256[name],
        ) for name in keys(input_sha256)
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
        "replica_mapping_sha256" => _exact_bundle_replica_digest(model),
    )
    provenance = Dict(
        "wanniernlqg_version" => string(pkgversion(WannierNLQG)),
        "julia_version" => string(VERSION),
        "input_files" => input_evidence,
        "operator_construction" => EXACT_WANNIER_OPERATOR_BUNDLE_ALGORITHM_VERSION,
        "symmetrization" => "not_applied",
        "tb_gauge" => "preserved",
        "derivative_overlap_source" => "wannier90_uIu",
        "derivative_overlap_completeness" => "full_hilbert_space",
        "derivative_overlap_source_sha256" => uiu_sha256,
        "derivative_overlap_algorithm_version" => IO.FULL_DERIVATIVE_OVERLAP_ALGORITHM_VERSION,
        "uiu_generation_provenance_sha256" => input_sha256["uiu_provenance_json"],
        "uiu_generation_algorithm_version" => String(uiu_provenance.algorithm_version),
        "uiu_generation_input_fingerprint_sha256" =>
            String(uiu_provenance.input_fingerprint_sha256),
    )
    symmetry = Dict("symmetrization_status" => "not_provided", "selected_operation_count" => 0)
    IO.write_real_space_operator_bundle(
        paths["output_bundle_file"],
        model.lattice,
        model.r_degeneracies,
        operators;
        profile = :derivative,
        overwrite = config.overwrite,
        paired_tb_sha256 = input_sha256["tb_file"],
        provenance,
        symmetry,
        geometry,
        diagnostics = Dict(
            "exact_derivative_overlap" => true,
            "uiu_generation_status" => String(uiu_provenance.status),
        ),
    )
    roundtrip = IO.read_real_space_operator_bundle(paths["output_bundle_file"])
    roundtrip.manifest.profile == :derivative ||
        throw(ArgumentError("exact operator-bundle profile roundtrip failed"))
    roundtrip.manifest.derivative_overlap_completeness == "full_hilbert_space" ||
        throw(ArgumentError("exact operator-bundle provenance roundtrip failed"))
    for (kind, operator) in operators
        roundtrip.operators[kind].data == operator.data ||
            throw(ArgumentError("exact operator-bundle bit-exact roundtrip failed for $(kind)"))
    end
    return ExactWannierOperatorBundleResult(
        paths["output_bundle_file"],
        sha256_file(paths["output_bundle_file"]),
        roundtrip.manifest.scientific_content_sha256,
        input_sha256,
        true,
    )
end
