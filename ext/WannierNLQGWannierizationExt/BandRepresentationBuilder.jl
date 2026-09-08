# Bind a stable backend identity while preserving every sewing-array element.
function _representation_with_sewing_backend(
    representation::BandRepresentation,
    backend::AbstractBandSewingBackend,
)
    conventions = Dict{String, String}(representation.conventions)
    conventions["sewing_backend"] = band_sewing_backend_key(backend)
    backend isa CoefficientMappingSewing &&
        (conventions["sewing_metric"] = "pseudo_coefficient_linear_map")
    return BandRepresentation(
        "1.5",
        representation.source_code,
        representation.spinor,
        representation.real_lattice,
        representation.reciprocal_lattice,
        representation.mp_grid,
        representation.kpoints_fractional,
        representation.energies_ev,
        representation.operations,
        representation.kpoint_map,
        representation.reciprocal_shifts,
        representation.sewing_matrices,
        representation.band_block_labels,
        representation.irreducible_indices,
        representation.full_to_irreducible,
        representation.full_to_operation;
        conventions,
        input_sha256 = representation.input_sha256,
    )
end

# Dispatch the expert backend without changing the legacy numerical path.
function _build_band_representation(
    native::NativeWavefunctionData,
    energies_ev::Matrix{Float64},
    operations::Vector{SymmetryOperation},
    degeneracy_tolerance_ev::Float64;
    symmetry_inventory = nothing,
    plane_wave_convention::Symbol = :canonical,
    diagnostic_outer_masks = nothing,
    diagnostic_frozen_masks = nothing,
    source::Union{Nothing, AbstractWavefunctionSource} = nothing,
    sewing_backend::AbstractBandSewingBackend = CoefficientMappingSewing(),
    strict_metric = nothing,
    return_diagnostics::Bool = false,
    construction_policy::Symbol = :diagnostic,
)
    construction_policy in (:strict, :diagnostic) ||
        throw(ArgumentError("unknown construction policy"))
    built = if sewing_backend isa CoefficientMappingSewing
        legacy = build_canonical_band_representation(
            native,
            energies_ev,
            operations,
            degeneracy_tolerance_ev;
            symmetry_inventory,
            plane_wave_convention,
            diagnostic_outer_masks,
            diagnostic_frozen_masks,
        )
        (
            representation = _representation_with_sewing_backend(
                legacy.representation,
                sewing_backend,
            ),
            construction_diagnostics = legacy.construction_diagnostics,
        )
    else
        source === nothing && throw(
            ArgumentError("PAW_SEWING_SOURCE_REQUIRED: strict sewing requires its native source"),
        )
        build_augmentation_aware_band_representation(
            source,
            native,
            energies_ev,
            operations,
            degeneracy_tolerance_ev,
            sewing_backend;
            symmetry_inventory,
            plane_wave_convention,
            diagnostic_outer_masks,
            diagnostic_frozen_masks,
            strict_metric,
            enforce_thresholds = construction_policy == :strict,
        )
    end
    return return_diagnostics ? built : built.representation
end

# Require an explicit physical-overlap capability before a native QE operation uses inner products.
function _require_native_physical_overlap(native::NativeWavefunctionData, operation::Symbol)
    native.source_code == :qe || return nothing
    available = get(native.source_metadata, "physical_overlap_available", "false")
    metric_kind = get(native.source_metadata, "qe_metric_kind", "unknown")
    available == "true" || throw(
        ArgumentError(
            "QE_AUGMENTATION_METRIC_REQUIRED: operation=$(operation) requires the physical " *
            "QE overlap metric, but the native source has no beta/Q augmentation backend " *
            "(qe_metric_kind=$(metric_kind))",
        ),
    )
    return nothing
end

# Generate physical AMN projections from native plane waves and the ordered projection basis.
function _generate_amn(native::NativeWavefunctionData, basis::WannierProjectionBasis)
    _require_native_physical_overlap(native, :generate_wannier_amn)
    nb = size(first(native.kpoints).coefficients, 1)
    nk = length(native.kpoints)
    amn = zeros(ComplexF64, nb, basis.num_wannier, nk)
    spin_components = native.spinor ? 2 : 1
    volume_normalization = inv(sqrt(abs(det(native.structure.lattice))))
    for (kpoint_index, point) in enumerate(native.kpoints)
        band_norms = [norm(@view point.coefficients[band, :, :]) for band in 1:nb]
        all(>(1.0e-14), band_norms) ||
            throw(ArgumentError("native wavefunction contains a zero-norm band"))
        trial_matrices = [
            zeros(ComplexF64, size(point.g_vectors, 1), basis.num_wannier) for
            _ in 1:spin_components
        ]
        for block in basis.blocks, center in axes(block.positions_fractional, 2)
            local_dimension = div(size(block.indices, 1), spin_components)
            for g_index in axes(point.g_vectors, 1)
                q_fractional = point.k_fractional .+ @view(point.g_vectors[g_index, :])
                q_cartesian = transpose(native.reciprocal_lattice) * q_fractional
                local_q = @view(block.local_bases[:, :, center]) * q_cartesian
                orbital_values = projection_orbital_values(
                    block,
                    local_q;
                    radial_transform = basis.radial_transform,
                )
                length(orbital_values) == local_dimension ||
                    throw(ArgumentError("projection orbital dimension is inconsistent"))
                phase =
                    cis(-2.0 * pi * dot(q_fractional, @view(block.positions_fractional[:, center])))
                for local_index in axes(block.indices, 1)
                    spin = spin_components == 1 ? 1 : mod(local_index - 1, 2) + 1
                    orbital = spin_components == 1 ? local_index : div(local_index - 1, 2) + 1
                    wannier = block.indices[local_index, center]
                    trial = volume_normalization * phase * orbital_values[orbital]
                    trial_matrices[spin][g_index, wannier] += trial
                end
            end
        end
        for spin in 1:spin_components
            normalized_conjugate = Matrix{ComplexF64}(undef, nb, size(point.g_vectors, 1))
            @inbounds for band in 1:nb, g_index in axes(point.g_vectors, 1)
                normalized_conjugate[band, g_index] =
                    conj(point.coefficients[band, g_index, spin]) / band_norms[band]
            end
            @views amn[:, :, kpoint_index] .+= normalized_conjugate * trial_matrices[spin]
        end
        for wannier in 1:basis.num_wannier
            norm_value = norm(@view amn[:, wannier, kpoint_index])
            norm_value > 1.0e-14 || throw(
                ArgumentError(
                    "native AMN projection $(wannier) vanished at k-point $(kpoint_index)",
                ),
            )
        end
    end
    return amn
end

# Preserve the internal array boundary while delegating format ownership to IO.
_read_wannier_amn(filename::AbstractString) = read_wannier_amn_file(filename).data

# Persist an audit-only AMN provenance companion without entering the solver path.
function _write_amn_provenance_hdf5(
    filename::AbstractString,
    amn::WannierAMN,
    basis::WannierProjectionBasis,
    native::NativeWavefunctionData;
    amn_sha256::AbstractString,
)
    HDF5.enable_complex_support()
    return atomic_hdf5_write(filename) do temporary
        HDF5.h5open(temporary, "w") do handle
            attributes = HDF5.attributes(handle)
            attributes["schema"] = "WannierNLQG.amn_provenance"
            attributes["schema_version"] = "1.0"
            attributes["amn_sha256"] = String(amn_sha256)
            attributes["basis_sha256"] = projection_basis_sha256(basis)
            attributes["source_code"] = String(native.source_code)
            attributes["spinor"] = basis.spinor
            attributes["num_bands"] = amn.num_bands
            attributes["num_kpoints"] = amn.num_kpts
            attributes["num_wannier"] = amn.num_wannier
            attributes["coordinate_convention"] = "fractional column centers; Cartesian row local bases"
            attributes["spin_convention"] =
                basis.spinor ? "interlaced orbital-up/orbital-down" : "scalar"
            radial_contract = projection_radial_transform_contract(basis.radial_transform)
            radial_group = HDF5.create_group(handle, "radial_transform")
            radial_attributes = HDF5.attributes(radial_group)
            for (key, value) in pairs(radial_contract)
                radial_attributes[String(key)] = value isa Symbol ? String(value) : value
            end
            radial_attributes["implementation_digest"] =
                bytes2hex(SHA.sha256(codeunits(repr(radial_contract))))
            expansion = HDF5.create_group(handle, "projection_expansion")
            for (block_index, block) in enumerate(basis.blocks)
                group = HDF5.create_group(expansion, lpad(string(block_index), 6, '0'))
                group_attributes = HDF5.attributes(group)
                group_attributes["selector"] = block.selector
                group_attributes["orbital_set"] = block.orbital_set
                group["positions_fractional"] = block.positions_fractional
                group["indices"] = block.indices
                group["local_bases"] = block.local_bases
            end
            input_hashes = HDF5.create_group(handle, "input_sha256")
            write_string_dictionary(input_hashes, native.input_sha256)
            environment = HDF5.create_group(handle, "environment")
            write_generation_environment(environment)
        end
    end
end

"""Generate native AMN data and optionally publish its formatted/provenance pair."""
function generate_wannier_amn(
    source::Union{VASPWavefunctionSource, QuantumEspressoWavefunctionSource},
    basis::WannierProjectionBasis;
    amn_file::Union{Nothing, AbstractString} = nothing,
    provenance_hdf5::Union{Nothing, AbstractString} = nothing,
)
    source isa VASPWavefunctionSource && throw(
        ArgumentError(
            "VASP_PAW_AMN_REQUIRED: native pseudo-only VASP AMN generation is disabled; " *
            "use an external VASP AMN or the qualified NativeVASPPAWMatrices backend",
        ),
    )
    provenance_hdf5 !== nothing &&
        amn_file === nothing &&
        throw(ArgumentError("provenance_hdf5 requires amn_file"))
    native = read_native_source(source; purpose = :physical_overlap)
    native.spinor == basis.spinor ||
        throw(ArgumentError("wavefunction and projection basis spin conventions disagree"))
    values = _generate_amn(native, basis)
    amn = WannierAMN(size(values, 1), size(values, 3), size(values, 2), values)
    if amn_file !== nothing
        output = write_wannier_amn(something(amn_file), amn)
        root, _ = splitext(output)
        companion =
            provenance_hdf5 === nothing ? root * ".amn-provenance.h5" :
            abspath(something(provenance_hdf5))
        _write_amn_provenance_hdf5(companion, amn, basis, native; amn_sha256 = sha256_file(output))
    end
    return amn
end
