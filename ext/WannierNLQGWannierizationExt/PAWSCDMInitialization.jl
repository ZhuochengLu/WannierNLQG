const PAW_SCDM_INPUT_SCHEMA = "WannierNLQG.paw_scdm_input"
const PAW_SCDM_INPUT_SCHEMA_VERSION = "1.0"

# Bind the complete numerical payload independently of HDF5 byte layout.
function _paw_scdm_payload_sha256(
    frames,
    projectors,
    selected_grid_indices,
    sampling_grid,
    singular_values,
    ranks,
    conditions,
    generalized_norm_residuals,
    paw_s_orthogonality_residuals,
    euclidean_orthogonality_residuals,
    kpoints_fractional,
    mp_grid,
    spinor,
    source_gauge_sha256,
    strict_representation_sha256,
    authoritative_hamiltonian,
    authoritative_hamiltonian_sha256,
    metric_sha256,
    source_identity,
)
    buffer = IOBuffer()
    for text in (
        PAW_SCDM_INPUT_SCHEMA,
        PAW_SCDM_INPUT_SCHEMA_VERSION,
        join(sampling_grid, ","),
        join(mp_grid, ","),
        string(spinor),
        source_gauge_sha256,
        strict_representation_sha256,
        authoritative_hamiltonian,
        authoritative_hamiltonian_sha256,
        metric_sha256,
    )
        write(buffer, text, '\0')
    end
    for array in (
        frames,
        projectors,
        selected_grid_indices,
        singular_values,
        ranks,
        conditions,
        generalized_norm_residuals,
        paw_s_orthogonality_residuals,
        euclidean_orthogonality_residuals,
        kpoints_fractional,
    )
        write(buffer, string(eltype(array)), ':', join(size(array), ','), ':')
        write(buffer, reinterpret(UInt8, vec(array)))
    end
    for key in sort!(collect(keys(source_identity)))
        write(buffer, key, '=', source_identity[key], '\n')
    end
    return bytes2hex(SHA.sha256(take!(buffer)))
end

# Require the exact source identities needed to reproduce projector/Q overlaps.
function _paw_scdm_source_identity(payload, gauge_sha256, representation_sha256)
    native = payload.native
    metadata = native.source_metadata
    coefficient_normalization = get(metadata, "coefficient_normalization", "")
    coefficient_normalization in ("qe_raw", "vasp_raw") || throw(
        ArgumentError(
            "SCDM_INPUT_PRECONDITION: completed WFC coefficients are not full-cutoff raw coefficients",
        ),
    )
    native.source_code == :qe &&
        get(metadata, "qe_reader_purpose", "") != "native_paw_matrix_construction_raw" &&
        throw(
            ArgumentError(
                "SCDM_INPUT_PRECONDITION: QE WFC provenance does not certify native PAW construction",
            ),
        )
    metric = payload.metric
    if metric isa _QEStrictSewingMetric
        metric.plan.num_channels > 0 ||
            throw(ArgumentError("SCDM_INPUT_PRECONDITION: QE projector plan is empty"))
        metric.metric_kind == "nc" ||
            metric.plan.has_augmentation ||
            throw(ArgumentError("SCDM_INPUT_PRECONDITION: PAW/USPP Q augmentation is absent"))
    elseif metric isa _VASPStrictSewingMetric
        metric.paw.num_channels > 0 ||
            throw(ArgumentError("SCDM_INPUT_PRECONDITION: VASP projector plan is empty"))
        size(metric.paw.q0_augmentation) == (metric.paw.num_channels, metric.paw.num_channels) ||
            throw(ArgumentError("SCDM_INPUT_PRECONDITION: VASP Q dimensions differ"))
    else
        throw(ArgumentError("SCDM_INPUT_PRECONDITION: unsupported PAW metric"))
    end
    wfc_keys = filter(key -> occursin(r"^wfc[0-9]+\.hdf5$", key), keys(payload.input_sha256))
    native.source_code == :qe &&
        length(wfc_keys) != length(native.kpoints) &&
        throw(
            ArgumentError(
                "SCDM_INPUT_PRECONDITION: WFC digest inventory does not cover every k point",
            ),
        )
    return Dict(
        "source_code" => String(native.source_code),
        "coefficient_normalization" => coefficient_normalization,
        "cutoff_contract" => "complete_native_g_vector_inventory_no_representation_truncation",
        "kpoint_count" => string(length(native.kpoints)),
        "band_count" => string(size(first(native.kpoints).coefficients, 1)),
        "spin_components" => string(size(first(native.kpoints).coefficients, 3)),
        "spinor" => string(native.spinor),
        "metric_kind" => metric isa _QEStrictSewingMetric ? metric.metric_kind : "paw",
        "metric_sha256" => _star_metric_sha256(metric),
        "input_identity_sha256" => _star_input_identity_sha256(payload.input_sha256),
        "source_gauge_sha256" => gauge_sha256,
        "strict_representation_sha256" => representation_sha256,
        "authoritative_hamiltonian" =>
            get(payload.source_metadata, "authoritative_hamiltonian", "native_dft"),
        "authoritative_hamiltonian_sha256" =>
            get(payload.input_sha256, "AUTHORITATIVE_HAMILTONIAN_SHA256", "MISSING"),
        "projector_overlap_source" => "recomputed_from_completed_wfc_and_parsed_paw_metric",
        "augmentation_source" => "parsed_upf_or_potcar_q0_not_mmn_amn",
        "sampling_contract" => "pseudo_coordinate_columns_after_paw_s_lowdin_whitening",
    )
end

# Minimal alias-free odd FFT grid enclosing every stored G vector.
function _paw_scdm_sampling_grid(native)
    maxima = zeros(Int, 3)
    for point in native.kpoints
        size(point.g_vectors, 2) == 3 ||
            throw(ArgumentError("SCDM_INPUT_PRECONDITION: G-vector dimensions differ"))
        length(unique(Tuple.(eachrow(point.g_vectors)))) == size(point.g_vectors, 1) ||
            throw(ArgumentError("SCDM_INPUT_PRECONDITION: duplicate G vectors"))
        maxima .= max.(maxima, vec(maximum(abs, point.g_vectors; dims = 1)))
    end
    return Tuple(2 .* maxima .+ 1)
end

# Construct the positive PAW-S overlap and its symmetric Lowdin inverse square root.
function _paw_scdm_lowdin(metric, kpoint, point)
    overlap, _, _ = _strict_metric_overlap(
        metric,
        point.coefficients,
        point.coefficients,
        metric.projectors[kpoint],
        metric.projectors[kpoint],
    )
    all(isfinite, overlap) ||
        throw(ArgumentError("SCDM_INPUT_PRECONDITION: nonfinite PAW-S overlap"))
    decomposition = eigen(Hermitian(0.5 .* (overlap + overlap')))
    minimum(decomposition.values) > 1.0e-10 ||
        throw(ArgumentError("SCDM_INPUT_PRECONDITION: PAW-S metric is rank deficient"))
    lowdin =
        decomposition.vectors * Diagonal(inv.(sqrt.(decomposition.values))) * decomposition.vectors'
    return overlap, lowdin
end

# Evaluate PAW-S-whitened pseudo-coordinate columns on the alias-free grid.
function _paw_scdm_anchor_samples(point, lowdin, sampling_grid)
    coefficients = _star_rotate_rows(point.coefficients, lowdin)
    nbands, _, nspin = size(coefficients)
    ngrid = prod(sampling_grid)
    samples = zeros(ComplexF64, nbands, ngrid * nspin)
    for spin in 1:nspin, band in 1:nbands
        buffer = zeros(ComplexF64, sampling_grid)
        for grow in axes(point.g_vectors, 1)
            index = ntuple(axis -> mod(point.g_vectors[grow, axis], sampling_grid[axis]) + 1, 3)
            buffer[index...] = coefficients[band, grow, spin]
        end
        values = FFTW.ifft(buffer)
        @views samples[band, ((spin - 1) * ngrid + 1):(spin * ngrid)] .= vec(values)
    end
    return samples
end

# Decode selected column identifiers into grid coordinates and spin rows.
function _paw_scdm_selected_coordinates(selected, sampling_grid)
    ngrid = prod(sampling_grid)
    indices = zeros(Int, 4, length(selected))
    coordinates = zeros(Float64, 3, length(selected))
    cartesian = CartesianIndices(sampling_grid)
    for (column, selected_column) in enumerate(selected)
        spin = fld(selected_column - 1, ngrid) + 1
        linear = mod(selected_column - 1, ngrid) + 1
        grid_index = Tuple(cartesian[linear])
        indices[1:3, column] .= grid_index
        indices[4, column] = spin
        coordinates[:, column] .=
            (Float64.(collect(grid_index)) .- 1.0) ./ Float64.(collect(sampling_grid))
    end
    return indices, coordinates
end

# Build and audit one deterministic PAW-S SCDM frame at a completed k point.
function _paw_scdm_frame_at_kpoint(point, metric, kpoint, coordinates, selected_spin)
    overlap, lowdin = _paw_scdm_lowdin(metric, kpoint, point)
    phases = exp.(2im * pi .* (point.g_vectors * coordinates))
    values = zeros(ComplexF64, size(point.coefficients, 1), size(coordinates, 2))
    for column in axes(coordinates, 2)
        spin = selected_spin[column]
        @views values[:, column] .= point.coefficients[:, :, spin] * phases[:, column]
    end
    whitened_values = transpose(lowdin) * values
    seed = conj.(whitened_values)
    decomposition = svd(seed)
    singular_values = decomposition.S
    threshold = max(1.0e-12, maximum(singular_values) * 1.0e-10)
    rank_value = count(value -> value > threshold, singular_values)
    rank_value == size(seed, 2) || throw(
        ArgumentError(
            "SCDM_INPUT_PRECONDITION: PAW-S SCDM selected-column rank $(rank_value) is smaller than $(size(seed, 2)) at k=$(kpoint)",
        ),
    )
    whitened_frame = decomposition.U[:, 1:size(seed, 2)] * decomposition.Vt
    physical_frame = lowdin * whitened_frame
    euclidean = svd(physical_frame)
    frame = euclidean.U[:, 1:size(seed, 2)] * euclidean.Vt
    generalized_residual = maximum(abs, overlap - I)
    paw_s_residual = maximum(abs, frame' * overlap * frame - I)
    euclidean_residual = maximum(abs, frame' * frame - I)
    condition = maximum(singular_values) / minimum(singular_values)
    return (
        frame = frame,
        singular_values = singular_values,
        rank = rank_value,
        condition = condition,
        generalized_residual = generalized_residual,
        paw_s_residual = paw_s_residual,
        euclidean_residual = euclidean_residual,
    )
end

# Atomically persist the self-contained PAW-S SCDM initialization artifact.
function _paw_scdm_write(filename, artifact::PAWSCDMInputArtifact)
    return atomic_hdf5_write(filename) do temporary
        HDF5.enable_complex_support()
        HDF5.h5open(temporary, "w") do handle
            attributes = HDF5.attributes(handle)
            attributes["schema"] = PAW_SCDM_INPUT_SCHEMA
            attributes["schema_version"] = PAW_SCDM_INPUT_SCHEMA_VERSION
            attributes["status"] = "PASS"
            attributes["metric"] = "paw_s_full_augmentation"
            attributes["sampling_contract"] = "pseudo_coordinate_columns_after_paw_s_lowdin_whitening"
            attributes["payload_sha256"] = artifact.payload_sha256
            attributes["source_gauge_sha256"] = artifact.source_gauge_sha256
            attributes["strict_representation_sha256"] = artifact.strict_representation_sha256
            attributes["authoritative_hamiltonian"] = artifact.authoritative_hamiltonian
            attributes["authoritative_hamiltonian_sha256"] =
                artifact.authoritative_hamiltonian_sha256
            attributes["metric_sha256"] = artifact.metric_sha256
            attributes["spinor"] = artifact.spinor
            handle["frames"] = artifact.frames
            handle["projectors"] = artifact.projectors
            handle["selected_grid_indices"] = artifact.selected_grid_indices
            handle["sampling_grid"] = collect(artifact.sampling_grid)
            handle["singular_values"] = artifact.singular_values
            handle["ranks"] = artifact.ranks
            handle["conditions"] = artifact.conditions
            handle["generalized_norm_residuals"] = artifact.generalized_norm_residuals
            handle["paw_s_orthogonality_residuals"] = artifact.paw_s_orthogonality_residuals
            handle["euclidean_orthogonality_residuals"] = artifact.euclidean_orthogonality_residuals
            handle["kpoints_fractional"] = artifact.kpoints_fractional
            handle["mp_grid"] = collect(artifact.mp_grid)
            identity_group = HDF5.create_group(handle, "source_identity")
            write_string_dictionary(identity_group, artifact.source_identity)
        end
    end
end

# Bridge a strict gauge and representation into one validated PAW-S SCDM artifact.
function prepare_paw_scdm_input_artifact(
    gauge_hdf5::AbstractString,
    representation_hdf5::AbstractString,
    output_hdf5::AbstractString;
    num_wannier::Int,
    construction_policy::Symbol = :diagnostic,
)
    isfile(gauge_hdf5) || throw(ArgumentError("SCDM_INPUT_PRECONDITION: gauge HDF5 does not exist"))
    isfile(representation_hdf5) ||
        throw(ArgumentError("SCDM_INPUT_PRECONDITION: representation HDF5 does not exist"))
    gauge_sha256 = sha256_file(gauge_hdf5)
    representation_sha256 = sha256_file(representation_hdf5)
    readback = _read_star_covariant_paw_gauge_hdf5(gauge_hdf5; construction_policy)
    payload = readback.payload
    representation = read_band_representation_hdf5(representation_hdf5)
    native = payload.native
    nbands = size(first(native.kpoints).coefficients, 1)
    nkpoints = length(native.kpoints)
    0 < num_wannier <= nbands ||
        throw(ArgumentError("SCDM_INPUT_PRECONDITION: invalid SCDM target dimension"))
    size(representation.energies_ev) == (nbands, nkpoints) ||
        throw(ArgumentError("SCDM_INPUT_PRECONDITION: representation band/k dimensions differ"))
    representation.spinor == native.spinor ||
        throw(ArgumentError("SCDM_INPUT_PRECONDITION: spinor identity differs"))
    representation.mp_grid == native.mp_grid ||
        throw(ArgumentError("SCDM_INPUT_PRECONDITION: MP grid identity differs"))
    maximum(
        abs,
        representation.kpoints_fractional -
        reduce(vcat, transpose.(getfield.(native.kpoints, :k_fractional))),
    ) <= 1.0e-10 || throw(ArgumentError("SCDM_INPUT_PRECONDITION: k-point identity differs"))
    get(representation.conventions, "wavefunction_gauge_hdf5_sha256", "MISSING") == gauge_sha256 ||
        throw(ArgumentError("SCDM_INPUT_PRECONDITION: gauge digest differs"))
    authority = get(payload.source_metadata, "authoritative_hamiltonian", "native_dft")
    authority_sha256 = get(payload.input_sha256, "AUTHORITATIVE_HAMILTONIAN_SHA256", "MISSING")
    get(representation.conventions, "authoritative_hamiltonian", "MISSING") == authority ||
        throw(ArgumentError("SCDM_INPUT_PRECONDITION: Hamiltonian authority differs"))
    get(representation.conventions, "authoritative_hamiltonian_sha256", "MISSING") ==
    authority_sha256 || throw(ArgumentError("SCDM_INPUT_PRECONDITION: authority digest differs"))
    for key in intersect(keys(payload.input_sha256), keys(representation.input_sha256))
        payload.input_sha256[key] == representation.input_sha256[key] ||
            throw(ArgumentError("SCDM_INPUT_PRECONDITION: source digest differs for $(key)"))
    end
    source_identity = _paw_scdm_source_identity(payload, gauge_sha256, representation_sha256)
    source_identity["construction_policy"] = String(construction_policy)
    source_identity["gauge_quality_status"] = String(readback.status)
    metric_sha256 = _star_metric_sha256(payload.metric)
    sampling_grid = _paw_scdm_sampling_grid(native)
    _, anchor_lowdin = _paw_scdm_lowdin(payload.metric, 1, native.kpoints[1])
    anchor_samples = _paw_scdm_anchor_samples(native.kpoints[1], anchor_lowdin, sampling_grid)
    pivoted = qr(anchor_samples, ColumnNorm())
    selected = Vector(pivoted.p)[1:num_wannier]
    selected_grid_indices, coordinates = _paw_scdm_selected_coordinates(selected, sampling_grid)
    frames = zeros(ComplexF64, nbands, num_wannier, nkpoints)
    projectors = zeros(ComplexF64, nbands, nbands, nkpoints)
    singular_values = zeros(Float64, num_wannier, nkpoints)
    ranks = zeros(Int, nkpoints)
    conditions = zeros(Float64, nkpoints)
    generalized = zeros(Float64, nkpoints)
    paw_s_residuals = zeros(Float64, nkpoints)
    euclidean_residuals = zeros(Float64, nkpoints)
    selected_spin = vec(selected_grid_indices[4, :])
    for kpoint in eachindex(native.kpoints)
        result = _paw_scdm_frame_at_kpoint(
            native.kpoints[kpoint],
            payload.metric,
            kpoint,
            coordinates,
            selected_spin,
        )
        frames[:, :, kpoint] .= result.frame
        projectors[:, :, kpoint] .= result.frame * result.frame'
        singular_values[:, kpoint] .= result.singular_values
        ranks[kpoint] = result.rank
        conditions[kpoint] = result.condition
        generalized[kpoint] = result.generalized_residual
        paw_s_residuals[kpoint] = result.paw_s_residual
        euclidean_residuals[kpoint] = result.euclidean_residual
    end
    kpoints = reduce(vcat, transpose.(getfield.(native.kpoints, :k_fractional)))
    digest = _paw_scdm_payload_sha256(
        frames,
        projectors,
        selected_grid_indices,
        sampling_grid,
        singular_values,
        ranks,
        conditions,
        generalized,
        paw_s_residuals,
        euclidean_residuals,
        kpoints,
        native.mp_grid,
        native.spinor,
        gauge_sha256,
        representation_sha256,
        authority,
        authority_sha256,
        metric_sha256,
        source_identity,
    )
    artifact = PAWSCDMInputArtifact(
        PAW_SCDM_INPUT_SCHEMA_VERSION,
        frames,
        projectors,
        selected_grid_indices,
        sampling_grid,
        singular_values,
        ranks,
        conditions,
        generalized,
        paw_s_residuals,
        euclidean_residuals,
        kpoints,
        native.mp_grid,
        native.spinor,
        gauge_sha256,
        representation_sha256,
        authority,
        authority_sha256,
        metric_sha256,
        source_identity,
        digest,
    )
    _paw_scdm_write(output_hdf5, artifact)
    return read_paw_scdm_input_artifact(output_hdf5)
end

# Read, structurally validate, and digest-check a PAW-S SCDM artifact.
function read_paw_scdm_input_artifact(filename::AbstractString)
    isfile(filename) ||
        throw(ArgumentError("SCDM_INPUT_PRECONDITION: SCDM input HDF5 does not exist"))
    HDF5.enable_complex_support()
    artifact = HDF5.h5open(filename, "r") do handle
        attributes = HDF5.attributes(handle)
        String(read(attributes["schema"])) == PAW_SCDM_INPUT_SCHEMA ||
            throw(ArgumentError("SCDM_INPUT_PRECONDITION: unsupported SCDM schema"))
        String(read(attributes["schema_version"])) == PAW_SCDM_INPUT_SCHEMA_VERSION ||
            throw(ArgumentError("SCDM_INPUT_PRECONDITION: unsupported SCDM schema version"))
        String(read(attributes["status"])) == "PASS" ||
            throw(ArgumentError("SCDM_INPUT_PRECONDITION: SCDM input status is not PASS"))
        sampling_values = Int.(read(handle["sampling_grid"]))
        mp_values = Int.(read(handle["mp_grid"]))
        frames = ComplexF64.(read(handle["frames"]))
        projectors = ComplexF64.(read(handle["projectors"]))
        selected = Int.(read(handle["selected_grid_indices"]))
        singular_values = Float64.(read(handle["singular_values"]))
        ranks = Int.(read(handle["ranks"]))
        conditions = Float64.(read(handle["conditions"]))
        generalized = Float64.(read(handle["generalized_norm_residuals"]))
        paw_s_residuals = Float64.(read(handle["paw_s_orthogonality_residuals"]))
        euclidean_residuals = Float64.(read(handle["euclidean_orthogonality_residuals"]))
        kpoints = Float64.(read(handle["kpoints_fractional"]))
        source_identity = read_string_dictionary(handle["source_identity"])
        artifact = PAWSCDMInputArtifact(
            PAW_SCDM_INPUT_SCHEMA_VERSION,
            frames,
            projectors,
            selected,
            Tuple(sampling_values),
            singular_values,
            ranks,
            conditions,
            generalized,
            paw_s_residuals,
            euclidean_residuals,
            kpoints,
            Tuple(mp_values),
            Bool(read(attributes["spinor"])),
            String(read(attributes["source_gauge_sha256"])),
            String(read(attributes["strict_representation_sha256"])),
            String(read(attributes["authoritative_hamiltonian"])),
            String(read(attributes["authoritative_hamiltonian_sha256"])),
            String(read(attributes["metric_sha256"])),
            source_identity,
            String(read(attributes["payload_sha256"])),
        )
        artifact
    end
    nbands, num_wannier, nkpoints = size(artifact.frames)
    size(artifact.projectors) == (nbands, nbands, nkpoints) ||
        throw(ArgumentError("SCDM_INPUT_PRECONDITION: projector dimensions differ"))
    size(artifact.singular_values) == (num_wannier, nkpoints) ||
        throw(ArgumentError("SCDM_INPUT_PRECONDITION: singular-value dimensions differ"))
    length(artifact.ranks) == length(artifact.conditions) == nkpoints ||
        throw(ArgumentError("SCDM_INPUT_PRECONDITION: diagnostic dimensions differ"))
    all(isfinite, artifact.frames) &&
    all(isfinite, artifact.projectors) &&
    all(isfinite, artifact.singular_values) &&
    all(isfinite, artifact.conditions) ||
        throw(ArgumentError("SCDM_INPUT_PRECONDITION: nonfinite SCDM payload"))
    all(==(num_wannier), artifact.ranks) ||
        throw(ArgumentError("SCDM_INPUT_PRECONDITION: SCDM payload is rank deficient"))
    digest = _paw_scdm_payload_sha256(
        artifact.frames,
        artifact.projectors,
        artifact.selected_grid_indices,
        artifact.sampling_grid,
        artifact.singular_values,
        artifact.ranks,
        artifact.conditions,
        artifact.generalized_norm_residuals,
        artifact.paw_s_orthogonality_residuals,
        artifact.euclidean_orthogonality_residuals,
        artifact.kpoints_fractional,
        artifact.mp_grid,
        artifact.spinor,
        artifact.source_gauge_sha256,
        artifact.strict_representation_sha256,
        artifact.authoritative_hamiltonian,
        artifact.authoritative_hamiltonian_sha256,
        artifact.metric_sha256,
        artifact.source_identity,
    )
    digest == artifact.payload_sha256 ||
        throw(ArgumentError("SCDM_INPUT_PRECONDITION: SCDM payload digest differs"))
    return artifact
end
