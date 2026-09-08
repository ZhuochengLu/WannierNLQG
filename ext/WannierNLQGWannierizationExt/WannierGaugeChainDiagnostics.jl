const WANNIER_GAUGE_CHAIN_DIAGNOSTIC_SCHEMA = "WannierNLQG.wannier_gauge_chain_diagnostic"
const WANNIER_GAUGE_CHAIN_DIAGNOSTIC_SCHEMA_VERSION = "1.0"

"""Evaluate one R-space matrix field on arbitrary reduced k points."""
function _gauge_chain_forward_fourier(
    values_r::Array{ComplexF64, 3},
    r_vectors::Matrix{Int},
    kpoints_fractional::AbstractMatrix{<:Real},
)
    size(values_r, 3) == size(r_vectors, 2) ||
        throw(DimensionMismatch("R-space matrix/support dimensions disagree"))
    output = zeros(ComplexF64, size(values_r, 1), size(values_r, 2), size(kpoints_fractional, 1))
    for kpoint in axes(kpoints_fractional, 1), r_index in axes(r_vectors, 2)
        phase =
            cis(2.0 * pi * dot(@view(kpoints_fractional[kpoint, :]), @view(r_vectors[:, r_index])))
        @views output[:, :, kpoint] .+= phase .* values_r[:, :, r_index]
    end
    return output
end

"""Return maximum matrix and eigenvalue-set differences for two k fields."""
function _gauge_chain_field_residuals(
    reference::Array{ComplexF64, 3},
    candidate::Array{ComplexF64, 3},
)
    size(reference) == size(candidate) ||
        throw(DimensionMismatch("Hamiltonian field dimensions disagree"))
    matrix_residual = maximum(abs, reference - candidate; init = 0.0)
    spectral_residual = 0.0
    for kpoint in axes(reference, 3)
        reference_values = eigvals(Hermitian(@view reference[:, :, kpoint]))
        candidate_values = eigvals(Hermitian(@view candidate[:, :, kpoint]))
        spectral_residual =
            max(spectral_residual, maximum(abs, reference_values - candidate_values; init = 0.0))
    end
    return matrix_residual, spectral_residual
end

"""Compute direct H(k) in one supplied rectangular band-to-Wannier frame."""
function _gauge_chain_direct_hamiltonian(frames, eig::WannierEIG)
    size(frames, 1) == eig.num_bands && size(frames, 3) == eig.num_kpts ||
        throw(DimensionMismatch("frame and EIG dimensions disagree"))
    nw = size(frames, 2)
    output = zeros(ComplexF64, nw, nw, eig.num_kpts)
    for kpoint in 1:eig.num_kpts
        frame = @view frames[:, :, kpoint]
        output[:, :, kpoint] .= frame' * Diagonal(@view(eig.data[:, kpoint])) * frame
    end
    return output
end

"""Return pair-center distances and normalized Hamiltonian weight by R entry."""
function _gauge_chain_tail_metrics(
    hamiltonian_r::Array{ComplexF64, 3},
    r_vectors::Matrix{Int},
    chk::WannierCHK,
    tail_radius::Float64,
)
    centers_fractional = chk.wannier_centers_cart * inv(chk.real_lattice)
    nw = chk.num_orbitals
    distances = zeros(Float64, nw, nw, size(r_vectors, 2))
    weights = abs2.(hamiltonian_r)
    for r_index in axes(r_vectors, 2), left in 1:nw, right in 1:nw
        displacement =
            Float64.(@view(r_vectors[:, r_index])) .+ @view(centers_fractional[right, :]) .-
            @view(centers_fractional[left, :])
        distances[left, right, r_index] = norm(transpose(chk.real_lattice) * displacement)
    end
    total = sum(weights)
    total > 0.0 || throw(ArgumentError("Hamiltonian R-space weight is zero"))
    tail = sum(weights[distances .>= tail_radius]) / total
    ordering = sortperm(vec(distances))
    ordered_distances = vec(distances)[ordering]
    cumulative = cumsum(vec(weights)[ordering]) ./ total
    support = Dict{String, Float64}()
    for percentile in (0.90, 0.99, 0.999, 0.9999)
        index = findfirst(>=(percentile), cumulative)
        support[string(percentile)] = ordered_distances[something(index, length(cumulative))]
    end
    return distances, weights ./ total, tail, support
end

"""Gauge-dependent link fields used only to distinguish U roughness."""
function _gauge_chain_u_link_fields(frames, mmn::WannierMMN)
    _, nw, nk = size(frames)
    offdiagonal_fraction = zeros(Float64, mmn.num_neighbors, nk)
    phase_margin = fill(Inf, mmn.num_neighbors, nk)
    diagonal_modulus = fill(Inf, mmn.num_neighbors, nk)
    diagonal_mask = Matrix{Bool}(I, nw, nw)
    for kpoint in 1:nk, neighbor in 1:mmn.num_neighbors
        target = mmn.neighbors[neighbor, kpoint]
        link =
            @view(frames[:, :, kpoint])' *
            @view(mmn.data[:, :, neighbor, kpoint]) *
            @view(frames[:, :, target])
        norm_link = norm(link)
        offdiagonal_fraction[neighbor, kpoint] =
            norm_link > 0.0 ? norm(link[.!diagonal_mask]) / norm_link : 0.0
        diagonal = diag(link)
        diagonal_modulus[neighbor, kpoint] = minimum(abs, diagonal)
        phase_margin[neighbor, kpoint] = minimum(pi .- abs.(angle.(diagonal)))
    end
    return offdiagonal_fraction, phase_margin, diagonal_modulus
end

"""Write one JSON payload atomically without exposing a partial artifact."""
function _atomic_gauge_chain_json(filename::AbstractString, payload)
    path = abspath(filename)
    mkpath(dirname(path))
    temporary, io = mktemp(dirname(path); cleanup = false)
    completed = false
    try
        JSON3.write(io, payload)
        write(io, '\n')
        close(io)
        mv(temporary, path; force = true)
        completed = true
    finally
        isopen(io) && close(io)
        !completed && isfile(temporary) && rm(temporary; force = true)
    end
    return path
end

"""Write and numerically read back one diagnostic exchange TB."""
function _gauge_chain_write_tb_roundtrip(
    filename::AbstractString,
    model,
    label::AbstractString;
    tolerance::Float64 = 1.0e-12,
)
    comment = "WannierNLQG SCREENING_PROXY_TB / NOT_QUALIFIED; replica=$(label)"
    path = _atomic_wannier_tb(filename, model; comment)
    restored = IO.read_wannier_tb(path)
    discrete_identity =
        restored.r_vectors == model.r_vectors && restored.r_degeneracies == model.r_degeneracies
    lattice_residual = maximum(abs, restored.lattice - model.lattice; init = 0.0)
    hamiltonian_residual = maximum(abs, restored.hamiltonian_r - model.hamiltonian_r; init = 0.0)
    position_residual = maximum(abs, restored.position_r - model.position_r; init = 0.0)
    maximum_residual = maximum((lattice_residual, hamiltonian_residual, position_residual))
    discrete_identity || throw(ArgumentError("$(label) diagnostic TB discrete readback differs"))
    maximum_residual <= tolerance || throw(
        ArgumentError(
            "$(label) diagnostic TB readback residual $(maximum_residual) exceeds $(tolerance)",
        ),
    )
    return Dict(
        "basename" => basename(path),
        "sha256" => sha256_file(path),
        "in_process_numeric_roundtrip" => "PASS",
        "fresh_process_roundtrip" => "PENDING_SEPARATE_AUDIT",
        "roundtrip_tolerance" => string(tolerance),
        "lattice_roundtrip_residual" => string(lattice_residual),
        "hamiltonian_roundtrip_residual" => string(hamiltonian_residual),
        "position_roundtrip_residual" => string(position_residual),
    )
end

"""Execute the versioned, read-only gauge-chain diagnosis."""
function diagnose_wannier_gauge_chain(config::WannierGaugeChainDiagnosticConfig)
    inputs = Dict(
        "wannierization_checkpoint_hdf5" => config.wannierization_checkpoint_hdf5,
        "eig_file" => config.eig_file,
        "mmn_file" => config.mmn_file,
        "band_representation_hdf5" => config.band_representation_hdf5,
    )
    config.reference_chk_file === nothing ||
        (inputs["reference_chk_file"] = something(config.reference_chk_file))
    for (label, filename) in inputs
        isfile(filename) || throw(ArgumentError("$(label) does not exist: $(filename)"))
    end
    input_sha256 = Dict(label => sha256_file(filename) for (label, filename) in inputs)
    sawf = read_wannierization_checkpoint_hdf5(config.wannierization_checkpoint_hdf5)
    sawf.wannier_chk === nothing &&
        throw(ArgumentError("gauge-chain diagnosis requires checkpoint WannierCHK data"))
    sawf.restart_state === nothing &&
        throw(ArgumentError("gauge-chain diagnosis requires a sealed accepted state"))
    chk = something(sawf.wannier_chk)
    eig = IO.read_wannier_eig(config.eig_file)
    mmn = IO.read_wannier_mmn(config.mmn_file)
    representation = read_band_representation_hdf5(config.band_representation_hdf5)
    (eig.num_bands, eig.num_kpts) ==
    (mmn.num_bands, mmn.num_kpts) ==
    (chk.num_bands, chk.num_kpts) ||
        throw(ArgumentError("ACTIVE_BAND_IDENTITY_MISMATCH: EIG/MMN/checkpoint dimensions differ"))
    size(representation.energies_ev) == size(eig.data) ||
        throw(ArgumentError("ACTIVE_BAND_IDENTITY_MISMATCH: representation dimensions differ"))
    maximum(abs, representation.energies_ev - eig.data; init = 0.0) <= 1.0e-10 ||
        throw(ArgumentError("ACTIVE_BAND_IDENTITY_MISMATCH: representation/EIG energies differ"))
    chk.mp_grid == representation.mp_grid ||
        throw(ArgumentError("KPOINT_IDENTITY_MISMATCH: MP grids differ"))
    maximum(abs, chk.kpt_red - representation.kpoints_fractional; init = 0.0) <= 1.0e-10 ||
        throw(ArgumentError("KPOINT_IDENTITY_MISMATCH: ordered k points differ"))
    for (key, filename) in (("EIG", config.eig_file), ("MMN", config.mmn_file))
        expected = get(representation.input_sha256, key, "")
        isempty(expected) ||
            expected == sha256_file(filename) ||
            throw(ArgumentError("INPUT_IDENTITY_MISMATCH: representation $(key) digest differs"))
    end
    # Reuse the sealed solver stencil: rebuilding here changes the discretized
    # objective and may incorrectly reapply a strict quality gate after solving.
    saved_stencil = something(sawf.restart_state).stencil
    stencil =
        saved_stencil === nothing ? finite_difference_weights(representation, mmn) :
        something(saved_stencil)
    size(stencil.vectors_cartesian) == (mmn.num_neighbors, 3) &&
    length(stencil.weights) == mmn.num_neighbors &&
    all(isfinite, stencil.weights) &&
    all(isfinite, stencil.vectors_cartesian) || throw(
        ArgumentError("STENCIL_IDENTITY_MISMATCH: checkpoint stencil is incompatible with MMN"),
    )
    sawf_links = wannier_gauge_link_diagnostics(sawf.v_matrix, mmn, stencil.weights)
    sawf_offdiagonal, sawf_phase_margin, sawf_diagonal_modulus =
        _gauge_chain_u_link_fields(sawf.v_matrix, mmn)
    direct_hamiltonian = _gauge_chain_direct_hamiltonian(sawf.v_matrix, eig)
    mp_r_vectors, mp_hamiltonian_r = _inverse_mp_fourier(direct_hamiltonian, chk)
    mp_reconstructed = _gauge_chain_forward_fourier(mp_hamiltonian_r, mp_r_vectors, chk.kpt_red)
    mp_matrix_residual, mp_spectral_residual =
        _gauge_chain_field_residuals(direct_hamiltonian, mp_reconstructed)
    mp_construction_diagnostics = Dict{String, Any}()
    mp_exported = build_wannier_tight_binding_model(
        sawf,
        eig,
        mmn;
        real_space_replica_policy = :mp_grid,
        construction_diagnostics = mp_construction_diagnostics,
    )
    ws_r_vectors, ws_hamiltonian_r = _inverse_pair_wigner_seitz_fourier(
        direct_hamiltonian,
        chk;
        wigner_seitz_tolerance = 1.0e-5,
        search_size = 3,
        label = "gauge-chain Hamiltonian",
    )
    ws_reconstructed = _gauge_chain_forward_fourier(ws_hamiltonian_r, ws_r_vectors, chk.kpt_red)
    ws_matrix_residual, ws_spectral_residual =
        _gauge_chain_field_residuals(direct_hamiltonian, ws_reconstructed)
    minimum_distance_construction_diagnostics = Dict{String, Any}()
    exported = build_wannier_tight_binding_model(
        sawf,
        eig,
        mmn;
        real_space_replica_policy = :minimum_distance,
        construction_diagnostics = minimum_distance_construction_diagnostics,
    )
    exported_reconstructed =
        _gauge_chain_forward_fourier(exported.hamiltonian_r, exported.r_vectors, chk.kpt_red)
    exported_matrix_residual, exported_spectral_residual =
        _gauge_chain_field_residuals(direct_hamiltonian, exported_reconstructed)
    pair_distances, pair_weights, tail_weight, support_radii =
        _gauge_chain_tail_metrics(ws_hamiltonian_r, ws_r_vectors, chk, config.tail_radius_angstrom)
    tb_artifacts = Dict{String, Dict{String, String}}()
    if config.mp_grid_tb_file !== nothing
        tb_artifacts["mp_grid"] = _gauge_chain_write_tb_roundtrip(
            something(config.mp_grid_tb_file),
            mp_exported,
            "mp_grid",
        )
    end
    if config.minimum_distance_tb_file !== nothing
        tb_artifacts["minimum_distance"] = _gauge_chain_write_tb_roundtrip(
            something(config.minimum_distance_tb_file),
            exported,
            "minimum_distance",
        )
    end
    frozen_mask =
        config.frozen_min_ev <= config.frozen_max_ev ?
        BitMatrix((eig.data .>= config.frozen_min_ev) .& (eig.data .<= config.frozen_max_ev)) :
        falses(eig.num_bands, eig.num_kpts)
    reference = nothing
    projector_comparison = nothing
    reference_links = nothing
    if config.reference_chk_file !== nothing
        reference = IO.read_wannier_chk(something(config.reference_chk_file))
        (reference.num_bands, reference.num_kpts, reference.num_orbitals) ==
        (chk.num_bands, chk.num_kpts, chk.num_orbitals) || throw(
            ArgumentError("REFERENCE_ACTIVE_BAND_IDENTITY_MISMATCH: W90 CHK dimensions differ"),
        )
        reference.mp_grid == chk.mp_grid ||
            throw(ArgumentError("REFERENCE_KPOINT_IDENTITY_MISMATCH: MP grids differ"))
        maximum(abs, reference.kpt_red - chk.kpt_red; init = 0.0) <= 1.0e-10 ||
            throw(ArgumentError("REFERENCE_KPOINT_IDENTITY_MISMATCH: ordered k points differ"))
        projector_comparison =
            compare_wannier_projectors(sawf.v_matrix, reference.v_matrix; frozen_mask)
        reference_links = wannier_gauge_link_diagnostics(reference.v_matrix, mmn, stencil.weights)
    end
    fourier_maximum = maximum((
        mp_matrix_residual,
        mp_spectral_residual,
        ws_matrix_residual,
        ws_spectral_residual,
        exported_matrix_residual,
        exported_spectral_residual,
    ),)
    status =
        fourier_maximum <= config.roundtrip_tolerance ? :PASS_DIAGNOSTIC :
        :FOURIER_IMPLEMENTATION_HOLD
    summary = Dict(
        "schema" => WANNIER_GAUGE_CHAIN_DIAGNOSTIC_SCHEMA,
        "schema_version" => WANNIER_GAUGE_CHAIN_DIAGNOSTIC_SCHEMA_VERSION,
        "status" => String(status),
        "qualification" => "DIAGNOSTIC_ONLY",
        "construction_policy" => get(sawf.input_summary, "construction_policy", "strict"),
        "finite_difference_stencil_source" =>
            saved_stencil === nothing ? "legacy_reconstructed" : "checkpoint",
        "finite_difference_stencil_sha256" => stencil.digest,
        "finite_difference_completeness_residual" => string(stencil.completeness_residual),
        "sawf_minimum_link_singular_value" => string(sawf_links.minimum_singular_value),
        "sawf_maximum_invariant_defect" => string(sawf_links.maximum_invariant_defect),
        "sawf_top_one_percent_concentration" =>
            string(sawf_links.top_one_percent_concentration),
        "sawf_omega_i" => string(sawf_links.omega_i),
        "mp_matrix_roundtrip_residual" => string(mp_matrix_residual),
        "mp_spectral_roundtrip_residual_ev" => string(mp_spectral_residual),
        "wigner_seitz_matrix_roundtrip_residual" => string(ws_matrix_residual),
        "wigner_seitz_spectral_roundtrip_residual_ev" => string(ws_spectral_residual),
        "exported_matrix_roundtrip_residual" => string(exported_matrix_residual),
        "exported_spectral_roundtrip_residual_ev" => string(exported_spectral_residual),
        "fourier_roundtrip_tolerance" => string(config.roundtrip_tolerance),
        "tail_radius_angstrom" => string(config.tail_radius_angstrom),
        "tail_weight" => string(tail_weight),
        "input_identity" => "PASS",
    )
    for (percentile, radius) in support_radii
        summary["support_radius_$(percentile)_angstrom"] = string(radius)
    end
    for (policy, diagnostics) in (
            ("mp_grid", mp_construction_diagnostics),
            ("minimum_distance", minimum_distance_construction_diagnostics),
        ),
        (key, value) in diagnostics

        summary["$(policy)_construction_$(key)"] = string(value)
    end
    for (policy, artifact) in tb_artifacts, (key, value) in artifact
        summary["$(policy)_tb_$(key)"] = value
    end
    if projector_comparison !== nothing
        comparison = something(projector_comparison)
        reference_values = something(reference_links)
        summary["maximum_projector_frobenius"] = string(maximum(comparison.projector_frobenius))
        summary["maximum_principal_angle_rad"] =
            string(maximum(comparison.maximum_principal_angle_rad))
        summary["minimum_cross_singular_value"] =
            string(minimum(comparison.minimum_cross_singular_value))
        summary["reference_minimum_link_singular_value"] =
            string(reference_values.minimum_singular_value)
        summary["reference_omega_i"] = string(reference_values.omega_i)
    end
    hdf5_path = atomic_hdf5_write(config.output_hdf5) do temporary
        HDF5.h5open(temporary, "w") do handle
            attributes = HDF5.attributes(handle)
            attributes["schema"] = WANNIER_GAUGE_CHAIN_DIAGNOSTIC_SCHEMA
            attributes["schema_version"] = WANNIER_GAUGE_CHAIN_DIAGNOSTIC_SCHEMA_VERSION
            attributes["status"] = String(status)
            attributes["qualification"] = "DIAGNOSTIC_ONLY"
            input_group = HDF5.create_group(handle, "input_sha256")
            write_string_dictionary(input_group, input_sha256)
            summary_group = HDF5.create_group(handle, "summary")
            write_string_dictionary(summary_group, summary)
            sawf_group = HDF5.create_group(handle, "sawf")
            sawf_group["link_minimum_singular_values"] = sawf_links.minimum_singular_values
            sawf_group["link_invariant_defects"] = sawf_links.invariant_defects
            sawf_group["omega_i_contributions"] = sawf_links.omega_i_contributions
            sawf_group["offdiagonal_link_fraction"] = sawf_offdiagonal
            sawf_group["diagonal_phase_margin"] = sawf_phase_margin
            sawf_group["diagonal_modulus"] = sawf_diagonal_modulus
            sawf_group["direct_hamiltonian_k"] = direct_hamiltonian
            fourier_group = HDF5.create_group(handle, "fourier")
            mp_group = HDF5.create_group(fourier_group, "mp_grid")
            mp_group["r_vectors"] = mp_r_vectors
            mp_group["hamiltonian_r"] = mp_hamiltonian_r
            ws_group = HDF5.create_group(fourier_group, "minimum_distance")
            ws_group["r_vectors"] = ws_r_vectors
            ws_group["hamiltonian_r"] = ws_hamiltonian_r
            ws_group["pair_center_distances_angstrom"] = pair_distances
            ws_group["normalized_pair_weights"] = pair_weights
            exported_group = HDF5.create_group(fourier_group, "exported_tb")
            exported_group["r_vectors"] = exported.r_vectors
            exported_group["hamiltonian_r"] = exported.hamiltonian_r
            mp_exported_group = HDF5.create_group(fourier_group, "exported_mp_grid_tb")
            mp_exported_group["r_vectors"] = mp_exported.r_vectors
            mp_exported_group["hamiltonian_r"] = mp_exported.hamiltonian_r
            if projector_comparison !== nothing
                comparison_group = HDF5.create_group(handle, "reference_comparison")
                comparison = something(projector_comparison)
                comparison_group["projector_frobenius"] = comparison.projector_frobenius
                comparison_group["projector_spectral"] = comparison.projector_spectral
                comparison_group["maximum_principal_angle_rad"] =
                    comparison.maximum_principal_angle_rad
                comparison_group["minimum_cross_singular_value"] =
                    comparison.minimum_cross_singular_value
                comparison_group["band_weight_difference"] = comparison.band_weight_difference
                comparison_group["frozen_projector_frobenius"] =
                    comparison.frozen_projector_frobenius
                comparison_group["free_projector_frobenius"] =
                    comparison.free_projector_frobenius
                reference_group = HDF5.create_group(handle, "reference")
                reference_values = something(reference_links)
                reference_group["link_minimum_singular_values"] =
                    reference_values.minimum_singular_values
                reference_group["link_invariant_defects"] = reference_values.invariant_defects
                reference_group["omega_i_contributions"] =
                    reference_values.omega_i_contributions
            end
        end
    end
    json_payload = Dict(
        "schema" => WANNIER_GAUGE_CHAIN_DIAGNOSTIC_SCHEMA,
        "schema_version" => WANNIER_GAUGE_CHAIN_DIAGNOSTIC_SCHEMA_VERSION,
        "status" => String(status),
        "qualification" => "DIAGNOSTIC_ONLY",
        "input_sha256" => input_sha256,
        "summary" => summary,
        "hdf5_sha256" => sha256_file(hdf5_path),
    )
    json_path = _atomic_gauge_chain_json(config.output_json, json_payload)
    return WannierGaugeChainDiagnosticResult(status, json_path, hdf5_path, summary, String[])
end
