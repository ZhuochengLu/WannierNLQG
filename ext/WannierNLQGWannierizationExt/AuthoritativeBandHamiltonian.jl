const AUTHORITATIVE_BAND_HAMILTONIAN_ALGORITHM_VERSION = "authoritative-band-hamiltonian-v3-physical-frame-transform"

"""Digest-bound Hamiltonian field in the exact band gauge used by SAWF."""
struct AuthoritativeBandHamiltonian
    matrices_ev::Array{ComplexF64, 3}
    authority::String
    digest::String
    input_sha256::Dict{String, String}
    algorithm_version::String
    gauge_artifact_sha256::Union{Nothing, String}
    qualified::Bool

    function AuthoritativeBandHamiltonian(
        matrices_ev,
        authority,
        digest,
        input_sha256,
        algorithm_version,
        gauge_artifact_sha256,
        qualified,
    )
        matrices = Array{ComplexF64, 3}(matrices_ev)
        size(matrices, 1) == size(matrices, 2) ||
            throw(ArgumentError("authoritative band Hamiltonian matrices must be square"))
        size(matrices, 3) > 0 ||
            throw(ArgumentError("authoritative band Hamiltonian has no k-points"))
        all(isfinite, matrices) ||
            throw(ArgumentError("authoritative band Hamiltonian contains NaN or Inf"))
        residual = maximum(
            norm(@view(matrices[:, :, kpoint]) - @view(matrices[:, :, kpoint])') for
            kpoint in axes(matrices, 3)
        )
        residual <= 1.0e-10 || throw(
            ArgumentError(
                "authoritative band Hamiltonian Hermiticity residual $(residual) exceeds 1e-10 eV",
            ),
        )
        authority_value = validate_authoritative_hamiltonian_key(authority)
        digest_value = String(digest)
        occursin(r"^[0-9a-f]{64}$", digest_value) ||
            throw(ArgumentError("authoritative band Hamiltonian digest must be SHA-256"))
        hashes = Dict{String, String}(input_sha256)
        all(occursin(r"^[0-9a-f]{64}$", value) for value in values(hashes)) ||
            throw(ArgumentError("authoritative band Hamiltonian input hashes must be SHA-256"))
        artifact_hash = gauge_artifact_sha256 === nothing ? nothing : String(gauge_artifact_sha256)
        artifact_hash === nothing ||
            occursin(r"^[0-9a-f]{64}$", artifact_hash) ||
            throw(ArgumentError("gauge artifact digest must be SHA-256"))
        return new(
            matrices,
            authority_value,
            digest_value,
            hashes,
            String(algorithm_version),
            artifact_hash,
            Bool(qualified),
        )
    end
end

"""Hash an authoritative Hamiltonian together with its authority and source hashes."""
function _authoritative_band_hamiltonian_digest(
    matrices::Array{ComplexF64, 3},
    authority::AbstractString,
    input_sha256::AbstractDict,
)
    stream = IOBuffer()
    write(stream, AUTHORITATIVE_BAND_HAMILTONIAN_ALGORITHM_VERSION)
    write(stream, '\0')
    write(stream, authority)
    write(stream, '\0')
    for key in sort!(String.(collect(keys(input_sha256))))
        write(stream, key)
        write(stream, '=')
        write(stream, String(input_sha256[key]))
        write(stream, '\0')
    end
    write(stream, reinterpret(UInt8, vec(matrices)))
    return bytes2hex(SHA.sha256(take!(stream)))
end

"""Materialize diagonal band-gauge Hamiltonians from an EIG energy table."""
function _diagonal_band_hamiltonian(energies_ev::AbstractMatrix{<:Real})
    num_bands, num_kpoints = size(energies_ev)
    matrices = zeros(ComplexF64, num_bands, num_bands, num_kpoints)
    for kpoint in 1:num_kpoints
        matrices[:, :, kpoint] .= Diagonal(@view(energies_ev[:, kpoint]))
    end
    return matrices
end

"""Return the byte-level SHA-256 of a dense Hamiltonian audit array."""
_authoritative_array_sha256(values) = bytes2hex(SHA.sha256(reinterpret(UInt8, vec(Array(values)))))

"""Validate the Reynolds-projected Hamiltonian audit and return its bound hashes."""
function _validate_reynolds_hamiltonian_audit(payload, audit)
    energies = audit.symmetrized_energies_ev
    rotations = audit.native_to_symmetrized_rotations
    representatives = audit.representative_symmetrized_hamiltonians_ev
    num_bands, num_kpoints = size(energies)
    size(rotations) == (num_bands, num_bands, num_kpoints) || throw(
        ArgumentError(
            "HAMILTONIAN_REFERENCE_MISMATCH: native-to-symmetrized rotation dimensions differ",
        ),
    )
    size(representatives) == (num_bands, num_bands, length(payload.star_representatives)) || throw(
        ArgumentError("HAMILTONIAN_REFERENCE_MISMATCH: Reynolds representative inventory differs"),
    )
    all(isfinite, rotations) && all(isfinite, representatives) ||
        throw(ArgumentError("HAMILTONIAN_REFERENCE_MISMATCH: Reynolds audit contains NaN or Inf"))
    maximum_residual = 0.0
    for (star_index, representative) in enumerate(payload.star_representatives)
        matrix = Matrix{ComplexF64}(@view representatives[:, :, star_index])
        hermiticity = norm(matrix - matrix')
        hermiticity <= 1.0e-10 || throw(
            ArgumentError(
                "HAMILTONIAN_REFERENCE_MISMATCH: Reynolds representative $(representative) Hermiticity residual $(hermiticity) exceeds 1e-10 eV",
            ),
        )
        values = sort!(real.(eigvals(Hermitian(matrix))))
        expected = sort!(collect(@view energies[:, representative]))
        maximum_residual = max(maximum_residual, maximum(abs, values - expected; init = 0.0))
    end
    maximum_residual <= 1.0e-10 || throw(
        ArgumentError(
            "HAMILTONIAN_REFERENCE_MISMATCH: Reynolds representative eigenspectrum residual $(maximum_residual) exceeds 1e-10 eV",
        ),
    )
    return Dict(
        "REYNOLDS_REPRESENTATIVE_HAMILTONIANS" => _authoritative_array_sha256(representatives),
        "NATIVE_TO_SYMMETRIZED_ROTATIONS" => _authoritative_array_sha256(rotations),
        "SYMMETRIZED_PARENT_ENERGIES" => _authoritative_array_sha256(energies),
    )
end

"""Construct native authority from the exact EIG payload used by the solver."""
function _native_authoritative_band_hamiltonian(
    eig::WannierEIG;
    eig_file::Union{Nothing, AbstractString} = nothing,
)
    input_sha256 = Dict{String, String}()
    if eig_file !== nothing
        path = abspath(String(eig_file))
        isfile(path) || throw(ArgumentError("authoritative EIG file does not exist: $(path)"))
        input_sha256["EIG"] = sha256_file(path)
    else
        input_sha256["EIG_ARRAY"] = bytes2hex(SHA.sha256(reinterpret(UInt8, vec(eig.data))))
    end
    matrices = _diagonal_band_hamiltonian(eig.data)
    authority = authoritative_hamiltonian_key(NativeDFTHamiltonian())
    digest = _authoritative_band_hamiltonian_digest(matrices, authority, input_sha256)
    return AuthoritativeBandHamiltonian(
        matrices,
        authority,
        digest,
        input_sha256,
        AUTHORITATIVE_BAND_HAMILTONIAN_ALGORITHM_VERSION,
        nothing,
        true,
    )
end

"""Apply the sealed physical frame transform to diagonal native EIG Hamiltonians."""
function _native_completed_frame_hamiltonian_matrices(eig::WannierEIG, contract)
    contract.transforms === nothing && throw(
        ArgumentError(
            "BAND_FRAME_TRANSFORM_REQUIRED: completed native-SAWF authority requires a nontrivial transform",
        ),
    )
    num_bands, num_kpoints = size(eig.data)
    size(contract.transforms) == (num_bands, num_bands, num_kpoints) ||
        throw(ArgumentError("BAND_FRAME_TRANSFORM_DIMENSION_MISMATCH"))
    native = _diagonal_band_hamiltonian(eig.data)
    matrices = similar(native)
    for kpoint in 1:num_kpoints
        transform = @view contract.transforms[:, :, kpoint]
        @views matrices[:, :, kpoint] .= transform' * native[:, :, kpoint] * transform
    end
    return matrices
end

"""
Construct native-DFT authority in the sealed completed-SAWF band frame.

The stored transformation maps the raw generalized PAW/USPP frame to the
physically orthonormal completed frame.  It is therefore applied by congruence,
`T† H_EIG T`; Euclidean invariance of the diagonal EIG matrix is neither
expected nor used as a qualification condition.
"""
function _native_completed_authoritative_band_hamiltonian(
    source::AbstractWavefunctionSource,
    gauge_hdf5::AbstractString,
    eig::WannierEIG;
    construction_policy::Symbol = :strict,
    eig_file::Union{Nothing, AbstractString} = nothing,
)
    num_bands, num_kpoints = size(eig.data)
    contract = generation_band_gauge_contract(
        source,
        NativeDFTHamiltonian(),
        gauge_hdf5,
        num_bands,
        num_kpoints;
        construction_policy,
    )
    contract.status == "PASS" || throw(
        ArgumentError(
            "BAND_FRAME_CONTRACT_NOT_QUALIFIED: completed native-SAWF authority requires a PASS frame contract",
        ),
    )
    matrices = _native_completed_frame_hamiltonian_matrices(eig, contract)
    input_sha256 = Dict{String, String}()
    if eig_file === nothing
        input_sha256["EIG_ARRAY"] = bytes2hex(SHA.sha256(reinterpret(UInt8, vec(eig.data))))
    else
        input_sha256["EIG"] = sha256_file(abspath(String(eig_file)))
    end
    input_sha256["WAVEFUNCTION_GAUGE_HDF5"] = something(contract.gauge_artifact_sha256)
    input_sha256["BAND_FRAME_TRANSFORM"] = contract.transform_sha256
    input_sha256["BAND_FRAME_CONTRACT"] = contract.contract_sha256
    authority = authoritative_hamiltonian_key(NativeDFTHamiltonian())
    digest = _authoritative_band_hamiltonian_digest(matrices, authority, input_sha256)
    return AuthoritativeBandHamiltonian(
        matrices,
        authority,
        digest,
        input_sha256,
        AUTHORITATIVE_BAND_HAMILTONIAN_ALGORITHM_VERSION,
        contract.gauge_artifact_sha256,
        true,
    )
end

"""
Load the actual Reynolds-projected eigenpairs from a qualified star-gauge
artifact. Metadata labels alone are never accepted as Hamiltonian data.
"""
function _bind_authority_band_frame!(input_sha256::AbstractDict, restored)
    restored.band_frame_contract === nothing && throw(
        ArgumentError(
            "LEGACY_BAND_FRAME_CONTRACT_NOT_RECORDED: symmetrized authority requires a schema-1.11 frame contract",
        ),
    )
    frame_contract = something(restored.band_frame_contract)
    frame_contract.status == "PASS" || throw(ArgumentError("BAND_FRAME_CONTRACT_NOT_QUALIFIED"))
    input_sha256["BAND_FRAME_TRANSFORM"] = frame_contract.transform_sha256
    input_sha256["BAND_FRAME_CONTRACT"] = frame_contract.contract_sha256
    return frame_contract
end

"""Load the digest-bound Reynolds-projected target-frame Hamiltonian authority."""
function _symmetrized_authoritative_band_hamiltonian(
    source::AbstractWavefunctionSource,
    gauge_hdf5::AbstractString,
    requested_authority::SymmetrizedDFTHamiltonian;
    construction_policy::Symbol = :strict,
)
    path = abspath(gauge_hdf5)
    restored = read_star_covariant_paw_gauge_hdf5(path; construction_policy, source)
    payload = restored.payload
    authority = get(payload.source_metadata, "authoritative_hamiltonian", "")
    authority == authoritative_hamiltonian_key(requested_authority) || throw(
        ArgumentError(
            "HAMILTONIAN_REFERENCE_MISMATCH: gauge artifact authority $(authority) differs from requested symmetrized authority",
        ),
    )
    audit = payload.symmetrized_hamiltonian_audit
    audit === nothing && throw(
        ArgumentError(
            "SYMMETRIZED_HAMILTONIAN_DATA_REQUIRED: gauge artifact has no Reynolds-projected audit payload",
        ),
    )
    audit_value = something(audit)
    energies = reduce(hcat, point.energies_ev for point in payload.native.kpoints)
    size(energies) == size(audit_value.symmetrized_energies_ev) ||
        throw(ArgumentError("HAMILTONIAN_REFERENCE_MISMATCH: symmetrized energy dimensions differ"))
    maximum(abs, energies - audit_value.symmetrized_energies_ev; init = 0.0) <= 1.0e-10 || throw(
        ArgumentError(
            "HAMILTONIAN_REFERENCE_MISMATCH: completed eigenvalues differ from Reynolds-projected Hamiltonian eigenvalues",
        ),
    )
    reynolds_hashes = _validate_reynolds_hamiltonian_audit(payload, audit_value)
    # The sealed completed wavefunctions are the eigen-gauge of the actual
    # Reynolds-projected matrices, so their Hamiltonian is diagonal in this
    # gauge.  The explicit hashes below keep the full Reynolds matrices and
    # native-to-symmetrized rotations in the authority digest; an energy-only
    # or metadata-only artifact can therefore never qualify.
    matrices = _diagonal_band_hamiltonian(energies)
    artifact_sha256 = sha256_file(path)
    input_sha256 = copy(payload.input_sha256)
    input_sha256["WAVEFUNCTION_GAUGE_HDF5"] = artifact_sha256
    _bind_authority_band_frame!(input_sha256, restored)
    merge!(input_sha256, reynolds_hashes)
    digest = _authoritative_band_hamiltonian_digest(matrices, authority, input_sha256)
    return AuthoritativeBandHamiltonian(
        matrices,
        authority,
        digest,
        input_sha256,
        AUTHORITATIVE_BAND_HAMILTONIAN_ALGORITHM_VERSION,
        artifact_sha256,
        true,
    )
end

"""Resolve the symmetrized Hamiltonian authority from a workflow configuration."""
function _symmetrized_authoritative_band_hamiltonian(config::SymmetryAdaptedWannierizationConfig)
    config.input.wavefunction_gauge_hdf5 === nothing && throw(
        ArgumentError(
            "SYMMETRIZED_HAMILTONIAN_ARTIFACT_REQUIRED: wavefunction_gauge_hdf5 is missing",
        ),
    )
    config.input.source === nothing && throw(
        ArgumentError("SYMMETRIZED_HAMILTONIAN_SOURCE_REQUIRED: native source replay is missing"),
    )
    authority = config.input.authoritative_hamiltonian
    authority isa SymmetrizedDFTHamiltonian ||
        throw(ArgumentError("symmetrized Hamiltonian backend was not requested"))
    return _symmetrized_authoritative_band_hamiltonian(
        something(config.input.source),
        something(config.input.wavefunction_gauge_hdf5),
        authority;
        construction_policy = config.input.construction_policy,
    )
end

"""Select and construct the configured native or symmetrized Hamiltonian authority."""
function authoritative_band_hamiltonian(
    config::SymmetryAdaptedWannierizationConfig,
    eig::WannierEIG,
)
    if config.input.authoritative_hamiltonian isa NativeDFTHamiltonian
        # Public workflows validate the EIG path before this point.  The
        # in-memory expert/export surface remains usable for sealed synthetic
        # tests by digesting the exact supplied EIG array when no file exists.
        eig_file = isfile(config.input.eig_file) ? config.input.eig_file : nothing
        if config.input.wavefunction_gauge_hdf5 === nothing
            return _native_authoritative_band_hamiltonian(eig; eig_file)
        end
        config.input.source === nothing && throw(
            ArgumentError(
                "BAND_FRAME_SOURCE_REQUIRED: native-SAWF authority requires native source replay",
            ),
        )
        return _native_completed_authoritative_band_hamiltonian(
            something(config.input.source),
            something(config.input.wavefunction_gauge_hdf5),
            eig;
            eig_file,
            construction_policy = config.input.construction_policy,
        )
    elseif config.input.authoritative_hamiltonian isa SymmetrizedDFTHamiltonian
        return _symmetrized_authoritative_band_hamiltonian(config)
    end
    throw(ArgumentError("unsupported authoritative Hamiltonian backend"))
end
