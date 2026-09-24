const WANNIER_UIU_GENERATION_SCHEMA = "WannierNLQG.wannier_uiu_generation"
const WANNIER_UIU_GENERATION_SCHEMA_VERSION = "1.1"
const WANNIER_UIU_ALGORITHM_VERSION = "paw-neighbor-neighbor-v4-frame-contract-bound"

"""Validated topology shared by MMN- and NNKP-authoritative uIu generation."""
struct WannierNeighborTopology
    num_bands::Int
    num_kpts::Int
    num_neighbors::Int
    neighbors::Matrix{Int}
    reciprocal_shifts::Array{Int, 3}
    kpoints_fractional::Union{Nothing, Matrix{Float64}}
    real_lattice::Union{Nothing, Matrix{Float64}}
    reciprocal_lattice::Union{Nothing, Matrix{Float64}}
    source_kind::Symbol
    source_sha256::String
end

"""Publish one JSON payload by same-filesystem atomic replacement."""
function _uiu_atomic_json(filename::AbstractString, payload)
    path = abspath(filename)
    mkpath(dirname(path))
    temporary, stream = mktemp(dirname(path); cleanup = false)
    completed = false
    try
        JSON3.write(stream, payload)
        write(stream, '\n')
        close(stream)
        mv(temporary, path; force = true)
        completed = true
    finally
        isopen(stream) && close(stream)
        !completed && isfile(temporary) && rm(temporary; force = true)
    end
    return path
end

"""Write one Fortran-unformatted record with 32-bit byte-count markers."""
function _uiu_write_fortran_record(io::Base.IO, bytes::AbstractVector{UInt8})
    length(bytes) <= typemax(Int32) || throw(ArgumentError("uIu record exceeds Int32 markers"))
    marker = Int32(length(bytes))
    write(io, marker)
    write(io, bytes)
    write(io, marker)
    return nothing
end

"""Encode integer values using the uIu Int32 header representation."""
_uiu_int32_bytes(values) = collect(reinterpret(UInt8, collect(Int32, values)))

"""Encode a complex matrix in Wannier90 uIu record order."""
function _uiu_matrix_bytes(matrix::AbstractMatrix{<:Complex})
    serialized = vec(copy(transpose(ComplexF64.(matrix))))
    return collect(reinterpret(UInt8, serialized))
end

"""Return the number of bands in an eager native-wavefunction dataset."""
_uiu_num_bands(native::NativeWavefunctionData) = native_point_metadata(native, 1).num_bands
"""Return the number of k-points in an eager native-wavefunction dataset."""
_uiu_num_kpoints(native::NativeWavefunctionData) = length(native.kpoints)
"""Return one eager native-wavefunction k-point in fractional coordinates."""
_uiu_kpoint_fractional(native::NativeWavefunctionData, index::Int) =
    native_point_metadata(native, index).k_fractional

"""Read and validate the MMN- or NNKP-authoritative neighbor topology."""
function _uiu_topology(filename::AbstractString, native)
    path = abspath(filename)
    isfile(path) || throw(ArgumentError("UIU_TOPOLOGY_MISSING: $(path)"))
    extension = lowercase(splitext(path)[2])
    bands = _uiu_num_bands(native)
    topology = if extension == ".mmn"
        mmn = read_wannier_mmn_topology(path)
        WannierNeighborTopology(
            mmn.num_bands,
            mmn.num_kpts,
            mmn.num_neighbors,
            copy(mmn.neighbors),
            copy(mmn.reciprocal_shifts),
            nothing,
            nothing,
            nothing,
            :mmn,
            sha256_file(path),
        )
    elseif extension == ".nnkp"
        nnkp = read_wannier_nnkp(path)
        WannierNeighborTopology(
            bands,
            size(nnkp.kpoints_fractional, 1),
            size(nnkp.neighbors, 1),
            copy(nnkp.neighbors),
            copy(nnkp.reciprocal_shifts),
            copy(nnkp.kpoints_fractional),
            copy(nnkp.real_lattice),
            copy(nnkp.reciprocal_lattice),
            :nnkp,
            nnkp.source_sha256,
        )
    else
        throw(ArgumentError("topology_file must use .mmn or .nnkp"))
    end
    topology.num_bands == bands || throw(
        ArgumentError(
            "UIU_TOPOLOGY_BAND_MISMATCH: topology=$(topology.num_bands), native=$(bands)",
        ),
    )
    topology.num_kpts == _uiu_num_kpoints(native) ||
        throw(ArgumentError("UIU_TOPOLOGY_KPOINT_COUNT_MISMATCH"))
    if topology.kpoints_fractional !== nothing
        isapprox(
            something(topology.real_lattice),
            native.structure.lattice;
            atol = 2.0e-6,
            rtol = 0.0,
        ) || throw(ArgumentError("UIU_TOPOLOGY_REAL_LATTICE_MISMATCH"))
        isapprox(
            something(topology.reciprocal_lattice),
            native.reciprocal_lattice;
            atol = 2.0e-6,
            rtol = 0.0,
        ) || throw(ArgumentError("UIU_TOPOLOGY_RECIPROCAL_LATTICE_MISMATCH"))
        for index in 1:_uiu_num_kpoints(native)
            delta =
                _uiu_kpoint_fractional(native, index) .-
                @view(something(topology.kpoints_fractional)[index, :])
            delta .-= round.(delta)
            maximum(abs, delta) <= 1.0e-8 ||
                throw(ArgumentError("UIU_TOPOLOGY_KPOINT_ORDER_MISMATCH: kpoint=$(index)"))
        end
    end
    for kpoint in 1:topology.num_kpts
        physical = [
            (
                topology.neighbors[neighbor, kpoint],
                Tuple(topology.reciprocal_shifts[:, neighbor, kpoint]),
            ) for neighbor in 1:topology.num_neighbors
        ]
        length(unique(physical)) == length(physical) ||
            throw(ArgumentError("UIU_TOPOLOGY_DUPLICATE_NEIGHBOR: kpoint=$(kpoint)"))
    end
    return topology
end

"""Fail before wavefunction I/O unless topology and oracle use the authoritative MMN."""
function _validate_authoritative_mmn_binding(
    topology_file::AbstractString,
    authoritative_mmn_file::Union{Nothing, AbstractString};
    oracle_mmn_file::Union{Nothing, AbstractString} = nothing,
)
    authoritative_mmn_file === nothing && return nothing
    authoritative_path = abspath(something(authoritative_mmn_file))
    isfile(authoritative_path) ||
        throw(ArgumentError("AUTHORITATIVE_MMN_MISSING: $(authoritative_path)"))
    authoritative_sha256 = sha256_file(authoritative_path)
    oracle_mmn_file === nothing || begin
        oracle_path = abspath(something(oracle_mmn_file))
        isfile(oracle_path) || throw(ArgumentError("UIU_MMN_ORACLE_REQUIRED"))
        sha256_file(oracle_path) == authoritative_sha256 ||
            throw(ArgumentError("AUTHORITATIVE_MMN_MISMATCH: oracle MMN digest differs"))
    end
    topology_path = abspath(topology_file)
    isfile(topology_path) || throw(ArgumentError("UIU_TOPOLOGY_MISSING: $(topology_path)"))
    extension = lowercase(splitext(topology_path)[2])
    if extension == ".mmn"
        sha256_file(topology_path) == authoritative_sha256 ||
            throw(ArgumentError("AUTHORITATIVE_MMN_MISMATCH: topology MMN digest differs"))
    elseif extension == ".nnkp"
        authoritative = read_wannier_mmn_topology(authoritative_path)
        topology = read_wannier_nnkp(topology_path)
        size(topology.neighbors) == size(authoritative.neighbors) &&
        topology.neighbors == authoritative.neighbors &&
        topology.reciprocal_shifts == authoritative.reciprocal_shifts ||
            throw(ArgumentError("AUTHORITATIVE_MMN_MISMATCH: NNKP neighbor topology differs"))
    else
        throw(ArgumentError("topology_file must use .mmn or .nnkp"))
    end
    return authoritative_sha256
end

"""Validate the immutable part of a target contract before source-wavefunction I/O."""
function _validate_operator_target_contract_files(contract::WannierOperatorTargetContract)
    contract.operator_oracle_mmn_file == abspath(contract.operator_oracle_mmn_file) ||
        throw(ArgumentError("OPERATOR_TARGET_CONTRACT_MISMATCH: oracle MMN path is not absolute"))
    contract.solver_mmn_file == abspath(contract.solver_mmn_file) ||
        throw(ArgumentError("OPERATOR_TARGET_CONTRACT_MISMATCH: solver MMN path is not absolute"))
    expected_contract_sha256 = if contract.parent_audit_policy == "audit_only"
        wannier_operator_target_contract_sha256(
            contract.operator_oracle_mmn_file,
            contract.operator_oracle_mmn_sha256,
            contract.solver_mmn_file,
            contract.solver_mmn_sha256,
            contract.source_band_gauge,
            contract.target_band_gauge,
            contract.band_frame_transform_sha256,
            contract.band_frame_contract_sha256,
            contract.gauge_artifact_sha256,
            contract.authoritative_hamiltonian,
            contract.authoritative_hamiltonian_digest,
            contract.num_bands,
            contract.num_kpoints,
            contract.num_neighbors,
            contract.qualification_scope.outer_mask_sha256,
            contract.qualification_scope.frozen_mask_sha256,
            contract.target_authority,
            contract.parent_audit_policy,
        )
    else
        wannier_operator_target_contract_sha256(
            contract.operator_oracle_mmn_file,
            contract.operator_oracle_mmn_sha256,
            contract.solver_mmn_file,
            contract.solver_mmn_sha256,
            contract.source_band_gauge,
            contract.target_band_gauge,
            contract.band_frame_transform_sha256,
            contract.band_frame_contract_sha256,
            contract.gauge_artifact_sha256,
            contract.authoritative_hamiltonian,
            contract.authoritative_hamiltonian_digest,
            contract.num_bands,
            contract.num_kpoints,
            contract.num_neighbors,
        )
    end
    contract.contract_sha256 == expected_contract_sha256 ||
        throw(ArgumentError("OPERATOR_TARGET_CONTRACT_MISMATCH: contract digest differs"))
    for (role, path, expected) in (
        ("operator oracle", contract.operator_oracle_mmn_file, contract.operator_oracle_mmn_sha256),
        ("solver", contract.solver_mmn_file, contract.solver_mmn_sha256),
    )
        isfile(path) ||
            throw(ArgumentError("OPERATOR_TARGET_CONTRACT_MISSING: $(role) MMN $(path)"))
        sha256_file(path) == expected ||
            throw(ArgumentError("OPERATOR_TARGET_CONTRACT_MISMATCH: $(role) MMN digest differs"))
    end
    return nothing
end

"""Validate target authority and gauge identity before native-source I/O."""
function _validate_operator_target_contract_config(
    contract::WannierOperatorTargetContract,
    authority,
    gauge_hdf5::Union{Nothing, AbstractString},
)
    expected_authority = authoritative_hamiltonian_key(authority)
    contract.authoritative_hamiltonian == expected_authority ||
        throw(ArgumentError("OPERATOR_TARGET_CONTRACT_MISMATCH: Hamiltonian authority differs"))
    contract.source_band_gauge == NATIVE_DFT_BAND_GAUGE ||
        throw(ArgumentError("OPERATOR_TARGET_CONTRACT_MISMATCH: source band gauge differs"))
    if gauge_hdf5 === nothing
        authority isa NativeDFTHamiltonian || throw(
            ArgumentError(
                "OPERATOR_TARGET_CONTRACT_MISMATCH: target Hamiltonian gauge artifact is missing",
            ),
        )
        contract.gauge_artifact_sha256 == "NOT_APPLICABLE" || throw(
            ArgumentError(
                "OPERATOR_TARGET_CONTRACT_MISMATCH: gauge artifact is required by target contract",
            ),
        )
        contract.target_band_gauge == NATIVE_DFT_BAND_GAUGE ||
            throw(ArgumentError("OPERATOR_TARGET_CONTRACT_MISMATCH: target band gauge differs"))
        return nothing
    end
    path = abspath(something(gauge_hdf5))
    isfile(path) || throw(ArgumentError("OPERATOR_TARGET_CONTRACT_MISSING: gauge artifact $(path)"))
    contract.gauge_artifact_sha256 != "NOT_APPLICABLE" || throw(
        ArgumentError(
            "OPERATOR_TARGET_CONTRACT_MISMATCH: gauge artifact is not applicable in target contract",
        ),
    )
    sha256_file(path) == contract.gauge_artifact_sha256 ||
        throw(ArgumentError("OPERATOR_TARGET_CONTRACT_MISMATCH: gauge artifact digest differs"))
    expected_target_gauge =
        authority isa SymmetrizedDFTHamiltonian ? SYMMETRIZED_DFT_BAND_GAUGE :
        authority isa NativeDFTHamiltonian ? SAWF_COMPLETED_NATIVE_DFT_BAND_GAUGE :
        throw(ArgumentError("unsupported authoritative Hamiltonian backend"))
    contract.target_band_gauge == expected_target_gauge ||
        throw(ArgumentError("OPERATOR_TARGET_CONTRACT_MISMATCH: target band gauge differs"))
    return nothing
end

"""Resolve the authoritative raw operator oracle without conflating it with solver MMN."""
function _operator_target_oracle_mmn_file(
    authoritative_mmn_file::Union{Nothing, AbstractString},
    target_contract::Union{Nothing, WannierOperatorTargetContract},
)
    target_contract === nothing && return authoritative_mmn_file
    contract = something(target_contract)
    _validate_operator_target_contract_files(contract)
    if authoritative_mmn_file !== nothing
        abspath(something(authoritative_mmn_file)) == contract.operator_oracle_mmn_file || throw(
            ArgumentError(
                "OPERATOR_TARGET_CONTRACT_MISMATCH: authoritative_mmn_file conflicts with operator oracle",
            ),
        )
    end
    return contract.operator_oracle_mmn_file
end

"""Resolve the MMN oracle used by both early validation and numerical parity."""
function _effective_uiu_oracle_mmn_file(config::WannierUIUGenerationConfig)
    contract = config.target_contract
    target_oracle = contract === nothing ? nothing : something(contract).operator_oracle_mmn_file
    if config.oracle_mmn_file !== nothing && target_oracle !== nothing
        abspath(something(config.oracle_mmn_file)) == target_oracle || throw(
            ArgumentError(
                "OPERATOR_TARGET_CONTRACT_MISMATCH: oracle_mmn_file conflicts with operator oracle",
            ),
        )
    end
    effective = config.oracle_mmn_file === nothing ? target_oracle : config.oracle_mmn_file
    if effective === nothing
        config.require_mmn_oracle && throw(ArgumentError("UIU_MMN_ORACLE_REQUIRED"))
        return nothing
    end
    path = abspath(something(effective))
    isfile(path) || throw(ArgumentError("UIU_MMN_ORACLE_REQUIRED: $(path)"))
    return path
end

"""Return whether two existing or normalized generation paths name the same object."""
_generation_paths_alias(first::AbstractString, second::AbstractString) =
    first == second || (ispath(first) && ispath(second) && samefile(first, second))

"""Resolve a possibly nonexistent path through the real path of its nearest existing ancestor."""
function _generation_resolved_path(path::AbstractString)
    absolute = abspath(path)
    ancestor = absolute
    suffix = String[]
    while !ispath(ancestor)
        parent = dirname(ancestor)
        parent == ancestor && return absolute
        pushfirst!(suffix, basename(ancestor))
        ancestor = parent
    end
    resolved_ancestor = realpath(ancestor)
    return isempty(suffix) ? resolved_ancestor : joinpath(resolved_ancestor, suffix...)
end

"""Reject every output path that aliases a protected scientific input."""
function _validate_generation_output_paths(outputs, protected_inputs)
    output_paths = Pair{String, String}[
        String(label) => abspath(String(path)) for (label, path) in pairs(outputs)
    ]
    protected = [
        abspath(String(path)) for
        path in protected_inputs if path !== nothing && !isempty(strip(String(path)))
    ]
    for first_index in eachindex(output_paths), second_index in 1:(first_index - 1)
        _generation_paths_alias(
            output_paths[first_index].second,
            output_paths[second_index].second,
        ) && throw(ArgumentError("GENERATOR_OUTPUT_PATH_COLLISION: output paths must be distinct"))
    end
    for (label, path) in output_paths
        for input_path in protected
            _generation_paths_alias(path, input_path) && throw(
                ArgumentError(
                    "GENERATOR_PROTECTED_INPUT_COLLISION: $(label) aliases $(input_path)",
                ),
            )
        end
    end
    return nothing
end

"""Return every on-disk wavefunction source root that generation must never replace."""
_generation_source_protected_paths(source::VASPWavefunctionSource) = (
    source.poscar_file,
    source.wavecar_file,
    source.potcar_file,
    source.incar_file,
    source.outcar_file,
)
"""Protect a QE save directory as the single source root for every XML, UPF, and WFC input."""
_generation_source_protected_paths(source::QuantumEspressoWavefunctionSource) =
    (source.save_directory,)

"""Reject output aliases of explicit inputs or native wavefunction-source roots."""
function _validate_generation_output_paths(outputs, protected_inputs, source)
    output_paths = Pair{String, String}[
        String(label) => abspath(String(path)) for (label, path) in pairs(outputs)
    ]
    source_paths = _generation_source_protected_paths(source)
    _validate_generation_output_paths(outputs, (protected_inputs..., source_paths...))
    source_directories = Set(
        realpath(String(path)) for path in source_paths if path !== nothing && isdir(String(path))
    )
    for (label, path) in output_paths, directory in source_directories
        resolved_path = _generation_resolved_path(path)
        (resolved_path == directory || startswith(resolved_path, directory * "/")) && throw(
            ArgumentError(
                "GENERATOR_PROTECTED_INPUT_COLLISION: $(label) lies within source directory $(directory)",
            ),
        )
    end
    return nothing
end

"""Bind a generator's realized gauge and topology to its immutable target contract."""
function _validate_operator_target_contract_frame(
    contract::WannierOperatorTargetContract,
    gauge_contract,
    authoritative_hamiltonian::AbstractString,
    num_bands::Integer,
    num_kpoints::Integer,
    num_neighbors::Integer;
    authoritative_hamiltonian_digest::Union{Nothing, AbstractString} = nothing,
)
    contract.source_band_gauge == gauge_contract.source_band_gauge &&
    contract.target_band_gauge == gauge_contract.target_band_gauge &&
    contract.band_frame_transform_sha256 == gauge_contract.transform_sha256 &&
    contract.band_frame_contract_sha256 == gauge_contract.contract_sha256 &&
    contract.gauge_artifact_sha256 ==
    something(gauge_contract.gauge_artifact_sha256, "NOT_APPLICABLE") ||
        throw(ArgumentError("OPERATOR_TARGET_CONTRACT_MISMATCH: band-frame contract differs"))
    contract.authoritative_hamiltonian == authoritative_hamiltonian ||
        throw(ArgumentError("OPERATOR_TARGET_CONTRACT_MISMATCH: Hamiltonian authority differs"))
    authoritative_hamiltonian_digest === nothing ||
        contract.authoritative_hamiltonian_digest == authoritative_hamiltonian_digest ||
        throw(ArgumentError("OPERATOR_TARGET_CONTRACT_MISMATCH: Hamiltonian digest differs"))
    (contract.num_bands, contract.num_kpoints, contract.num_neighbors) ==
    (num_bands, num_kpoints, num_neighbors) ||
        throw(ArgumentError("OPERATOR_TARGET_CONTRACT_MISMATCH: topology dimensions differ"))
    return nothing
end

"""Resolve a neighbor-neighbor overlap pair and its reciprocal displacement."""
function _uiu_overlap_geometry(
    native,
    topology::WannierNeighborTopology,
    center::Int,
    first::Int,
    second::Int,
)
    left_index = topology.neighbors[first, center]
    right_index = topology.neighbors[second, center]
    left_shift = @view topology.reciprocal_shifts[:, first, center]
    right_shift = @view topology.reciprocal_shifts[:, second, center]
    left_offset = _uiu_native_frame_offset(native, topology, left_index)
    right_offset = _uiu_native_frame_offset(native, topology, right_index)
    relative_shift = Tuple(Int.(right_shift .- left_shift .- right_offset .+ left_offset))
    b_fractional =
        _uiu_kpoint_fractional(native, right_index) .+ collect(relative_shift) .-
        _uiu_kpoint_fractional(native, left_index)
    return left_index, right_index, relative_shift, Vector{Float64}(b_fractional)
end

"""Resolve the reciprocal-lattice frame offset of one native k-point."""
function _uiu_native_frame_offset(native, topology::WannierNeighborTopology, index::Int)
    topology.kpoints_fractional === nothing && return zeros(Int, 3)
    delta =
        _uiu_kpoint_fractional(native, index) .-
        @view(something(topology.kpoints_fractional)[index, :])
    offset = round.(Int, delta)
    maximum(abs, delta .- offset) <= 1.0e-8 ||
        throw(ArgumentError("UIU_TOPOLOGY_KPOINT_FRAME_OFFSET_MISMATCH: kpoint=$(index)"))
    return offset
end

"""Prepare the validated VASP PAW overlap state used for streamed uIu generation."""
function _uiu_vasp_state(source::VASPWavefunctionSource, topology_file::AbstractString)
    source.potcar_file === nothing &&
        throw(ArgumentError("VASP_PAW_DATA_REQUIRED: uIu generation requires POTCAR"))
    source.representation_cutoff_ev === nothing ||
        throw(ArgumentError("VASP_PAW_RAW_COEFFICIENTS_REQUIRED: uIu requires the full cutoff"))
    native = read_vasp_wavefunctions(
        source;
        point_provider = native_vasp_point_provider,
        normalize_coefficients = false,
        # An explicit basis is already available and must carry the same
        # provenance marker as SPN. Scalar overlaps without it remain supported.
        require_spin_basis = source.spin_basis_saxis !== nothing,
    )
    get(native.source_metadata, "coefficient_normalization", "") == "vasp_raw" ||
        throw(ArgumentError("VASP_PAW_RAW_COEFFICIENTS_REQUIRED"))
    topology = _uiu_topology(topology_file, native)
    prepared = _vasp_operator_paw_context(source, native)
    (;
        paw,
        radial_q_maximum,
        radial_q_worst,
        projectors,
        generalized_norm,
        generalized_norm_worst,
    ) = prepared
    input_sha256 = merge(
        _vasp_operator_input_sha256(source, native),
        Dict("TOPOLOGY" => topology.source_sha256),
    )
    preparation_identity = _vasp_raw_context_identity(source, native, input_sha256)
    finite_b_cache = Dict{Tuple{String, NTuple{3, Float64}}, Matrix{ComplexF64}}()
    function overlap(left_index, right_index, shift, b_fractional)
        identity = () -> preparation_identity * repr((left_index, right_index, shift, b_fractional))
        return cached_preparation_artifact("vasp-overlap", identity; unit = left_index) do
            pseudo = _paw_pseudo_mmn_block(
                native.kpoints[left_index],
                native.kpoints[right_index],
                shift,
            )
            b_cartesian = transpose(native.reciprocal_lattice) * b_fractional
            augmentation = _paw_mmn_augmentation_block(
                projectors[left_index],
                projectors[right_index],
                paw,
                shift,
                b_cartesian,
                finite_b_cache,
            )
            return pseudo .+ augmentation
        end
    end
    diagnostics = String[
        "radial_q_worst=$(radial_q_worst)",
        "generalized_norm_worst=$(generalized_norm_worst)",
        "spinor_scalar_overlap_basis=not_required",
    ]
    return (;
        native,
        topology,
        overlap,
        generalized_norm,
        radial_q_maximum,
        input_sha256,
        diagnostics,
        wavefunction_cache = nothing,
    )
end

"""Lightweight QE metadata whose wavefunctions are loaded through the bounded cache."""
struct QEUIULazyNative
    source_code::Symbol
    structure::CrystalStructure
    reciprocal_lattice::Matrix{Float64}
    mp_grid::NTuple{3, Int}
    spinor::Bool
    kpoints_fractional::Matrix{Float64}
    selected_bands::Vector{Int}
    input_sha256::Dict{String, String}
    source_metadata::Dict{String, String}
end

"""Return the selected QE band count."""
_uiu_num_bands(native::QEUIULazyNative) = length(native.selected_bands)
"""Return the QE k-point count without loading wavefunctions."""
_uiu_num_kpoints(native::QEUIULazyNative) = size(native.kpoints_fractional, 1)
"""Return one lazy QE k-point in fractional coordinates."""
_uiu_kpoint_fractional(native::QEUIULazyNative, index::Int) =
    @view native.kpoints_fractional[index, :]

"""Cached QE wavefunction and its beta-projector overlaps."""
struct QEUIUCacheEntry
    point::PlaneWaveKPoint
    beta_overlap::Array{ComplexF64, 3}
end

"""Byte-bounded beta overlaps survive eviction of much larger wavefunction coefficients."""
mutable struct QEBetaOverlapCache
    budget_bytes::Int
    resident_bytes::Int
    entries::Dict{Int, Array{ComplexF64, 3}}
    recency::Vector{Int}
    builds::Int
    hits::Int
end

"""Construct a worker-private compact cache with an explicit byte limit."""
function QEBetaOverlapCache(budget_bytes::Int)
    budget_bytes >= 0 || throw(ArgumentError("QE_BETA_CACHE_NEGATIVE_BUDGET"))
    return QEBetaOverlapCache(budget_bytes, 0, Dict{Int, Array{ComplexF64, 3}}(), Int[], 0, 0)
end

"""Reuse a beta contraction without changing its original arithmetic or array."""
function _qe_cached_beta_overlap!(builder::F, cache::QEBetaOverlapCache, index::Int) where {F}
    if haskey(cache.entries, index)
        cache.hits += 1
        deleteat!(cache.recency, something(findfirst(==(index), cache.recency)))
        push!(cache.recency, index)
        return cache.entries[index]
    end
    value = builder()
    all(isfinite, value) || throw(ArgumentError("QE_BETA_CACHE_NONFINITE"))
    cache.builds += 1
    bytes = Base.summarysize(value)
    bytes > cache.budget_bytes && return value
    while cache.resident_bytes + bytes > cache.budget_bytes
        evicted = popfirst!(cache.recency)
        cache.resident_bytes -= Base.summarysize(pop!(cache.entries, evicted))
    end
    cache.entries[index] = value
    push!(cache.recency, index)
    cache.resident_bytes += bytes
    return value
end

"""Deterministic bounded LRU cache for streamed QE uIu generation."""
mutable struct QEUIUWavefunctionCache
    max_entries::Int
    loader::Function
    entries::Dict{Int, QEUIUCacheEntry}
    recency::Vector{Int}
    load_counts::Dict{Int, Int}
    hits::Int
    misses::Int
    evictions::Int
    reloads::Int
    peak_entries::Int
    peak_resident_bytes::Int
    max_bytes::Int
    estimate_bytes::Function
    entry_bytes::Dict{Int, Int}
    resident_bytes::Int
end

"""Bound cached coefficients by both entry count and scientific payload bytes."""
function QEUIUWavefunctionCache(
    max_entries::Int,
    loader::Function;
    max_bytes::Int = typemax(Int),
    estimate_bytes::Function = _ -> 0,
)
    max_entries >= 2 ||
        throw(ArgumentError("QE_UIU_CACHE_TOO_SMALL: at least two k-points are required"))
    max_bytes > 0 || throw(ArgumentError("QE_UIU_CACHE_BYTE_BUDGET_MUST_BE_POSITIVE"))
    return QEUIUWavefunctionCache(
        max_entries,
        loader,
        Dict{Int, QEUIUCacheEntry}(),
        Int[],
        Dict{Int, Int}(),
        0,
        0,
        0,
        0,
        0,
        0,
        max_bytes,
        estimate_bytes,
        Dict{Int, Int}(),
        0,
    )
end

"""Measure a payload once when it enters the cache."""
_qe_uiu_entry_bytes(entry::QEUIUCacheEntry) =
    Base.summarysize(entry.point.k_fractional) +
    Base.summarysize(entry.point.g_vectors) +
    Base.summarysize(entry.point.coefficients) +
    Base.summarysize(entry.point.energies_ev) +
    Base.summarysize(entry.beta_overlap)

"""Read incremental accounting without traversing every cached array."""
_qe_uiu_cache_resident_bytes(cache::QEUIUWavefunctionCache) = cache.resident_bytes

"""Release the oldest entry and update its exact resident-byte accounting."""
function _qe_uiu_evict_oldest!(cache::QEUIUWavefunctionCache)
    index = popfirst!(cache.recency)
    delete!(cache.entries, index)
    cache.resident_bytes -= pop!(cache.entry_bytes, index)
    cache.evictions += 1
    nothing
end

"""Fetch one QE entry with deterministic LRU eviction before coefficient loading."""
function _qe_uiu_cache_entry!(cache::QEUIUWavefunctionCache, index::Int)
    if haskey(cache.entries, index)
        cache.hits += 1
        position = findfirst(==(index), cache.recency)
        position === nothing || deleteat!(cache.recency, position)
        push!(cache.recency, index)
        return cache.entries[index]
    end
    cache.misses += 1
    previous_loads = get(cache.load_counts, index, 0)
    previous_loads > 0 && (cache.reloads += 1)
    estimated = cache.estimate_bytes(index)
    estimated >= 0 || throw(ArgumentError("QE_UIU_CACHE_NEGATIVE_SIZE_ESTIMATE"))
    while !isempty(cache.entries) && (
        length(cache.entries) >= cache.max_entries ||
        estimated > cache.max_bytes - cache.resident_bytes
    )
        _qe_uiu_evict_oldest!(cache)
    end
    entry = cache.loader(index)
    cache.load_counts[index] = previous_loads + 1
    bytes = _qe_uiu_entry_bytes(entry)
    while !isempty(cache.entries) && bytes > cache.max_bytes - cache.resident_bytes
        _qe_uiu_evict_oldest!(cache)
    end
    # A point larger than the cache allowance remains a transient work item;
    # the preparation process budget still governs that work item separately.
    bytes > cache.max_bytes && return entry
    cache.entries[index] = entry
    cache.entry_bytes[index] = bytes
    cache.resident_bytes += bytes
    push!(cache.recency, index)
    cache.peak_entries = max(cache.peak_entries, length(cache.entries))
    cache.peak_resident_bytes = max(cache.peak_resident_bytes, cache.resident_bytes)
    return entry
end

"""Derive the QE selected-band authority from NNKP exclusions or MMN dimensions."""
function _qe_uiu_selected_bands(total_bands::Int, topology_path::AbstractString)
    extension = lowercase(splitext(topology_path)[2])
    if extension == ".nnkp"
        nnkp = read_wannier_nnkp(topology_path)
        all(index -> 1 <= index <= total_bands, nnkp.excluded_bands) ||
            throw(ArgumentError("QE_NNKP_BAND_AUTHORITY_REQUIRED: excluded band is out of range"))
        excluded = Set(nnkp.excluded_bands)
        selected = [band for band in 1:total_bands if !(band in excluded)]
        isempty(selected) &&
            throw(ArgumentError("QE_NNKP_BAND_AUTHORITY_REQUIRED: every band is excluded"))
        length(selected) >= length(nnkp.projections) || throw(
            ArgumentError(
                "QE_NNKP_BAND_AUTHORITY_REQUIRED: $(length(selected)) selected bands cannot " *
                "span $(length(nnkp.projections)) trial projections",
            ),
        )
        return selected
    elseif extension == ".mmn"
        mmn = read_wannier_mmn_topology(topology_path)
        mmn.num_bands == total_bands || throw(
            ArgumentError(
                "QE_MMN_BAND_AUTHORITY_MISMATCH: MMN=$(mmn.num_bands), wavefunction=$(total_bands)",
            ),
        )
        return collect(1:total_bands)
    end
    throw(ArgumentError("topology_file must use .mmn or .nnkp"))
end

"""Reserve one quarter of the usable preparation budget for cached coefficients."""
function _qe_coefficient_cache_budget()
    execution = get(task_local_storage(), :wannier_preparation_execution, nothing)
    budget = execution === nothing ? 24 * 1024^3 : execution.memory_budget_bytes
    budget > 0 || throw(ArgumentError("preparation memory budget must be positive"))
    max(1, (budget ÷ 4) * 3 ÷ 4)
end

"""Identify a shared state without confusing topology roles or source settings."""
_qe_operator_state_key(source, topology_file, cache_size) =
    (repr(source), realpath(topology_file), cache_size)

"""Reuse only the owner task's explicitly prepared QE state."""
function _uiu_qe_state(source::QuantumEspressoWavefunctionSource, topology_file, cache_size)
    prepared = get(task_local_storage(), :wannier_qe_operator_preparation, nothing)
    if prepared !== nothing
        prepared.owner === current_task() ||
            throw(ArgumentError("QE_OPERATOR_STATE_REQUIRES_PRIVATE_WORKER_CONTEXT"))
        prepared.key == _qe_operator_state_key(source, topology_file, cache_size) ||
            throw(ArgumentError("QE_OPERATOR_PREPARATION_CONTEXT_MISMATCH"))
        # Registry lookups check input identity without repeating their content hashes.
        foreach(sha256_file, prepared.paths)
        state = prepared.state[]
        if state === nothing
            state = _build_uiu_qe_state(source, topology_file, cache_size)
            prepared.state[] = state
        end
        cache = state.wavefunction_cache
        cache.max_bytes = min(cache.max_bytes, _qe_coefficient_cache_budget())
        while cache.resident_bytes > cache.max_bytes
            _qe_uiu_evict_oldest!(cache)
        end
        # Operators append their own provenance keys. Share expensive native
        # caches, but keep stage metadata independent of execution order.
        if !get(task_local_storage(), :wannier_qe_defer_norm, false)
            state = _qe_state_with_completed_norm(state)
        end
        return merge(
            state,
            (input_sha256 = copy(state.input_sha256), diagnostics = copy(state.diagnostics)),
        )
    end
    return _build_uiu_qe_state(source, topology_file, cache_size)
end

"""Share validated native inputs and PAW state across sequential operator stages.

Each worker must create its own scope. All mutable coefficient and radial caches
belong to that scope; no process-global state or shared mutable worker cache exists.
"""
function _with_qe_operator_preparation(
    f::F,
    source::QuantumEspressoWavefunctionSource,
    topology_file,
    cache_size::Int;
    checkpoint_directory::Union{Nothing, String} = nothing,
    implementation_contract::String = "",
    additional_inputs = String[],
) where {F}
    checkpoint_directory !== nothing &&
        isempty(implementation_contract) &&
        throw(ArgumentError("OPERATOR_PREPARATION_IMPLEMENTATION_CONTRACT_REQUIRED"))
    existing = get(task_local_storage(), :wannier_qe_operator_preparation, nothing)
    if existing !== nothing &&
       existing.owner === current_task() &&
       existing.key == _qe_operator_state_key(source, topology_file, cache_size)
        # Recheck inherited identities and new dependencies, but do not parse XML
        # or replace the already validated native state for a nested stage.
        return with_verified_file_digests(vcat(existing.paths, additional_inputs)) do
            _with_spn_provenance_reuse(f)
        end
    end
    metadata = read_qe_xml(source)
    paths = String[metadata.xml_file, abspath(topology_file)]
    append!(paths, values(metadata.upf_files))
    append!(
        paths,
        [qe_wavefunction_file(source, index) for index in eachindex(metadata.kpoint_nodes)],
    )
    native_paths = copy(paths)
    append!(paths, additional_inputs)
    return with_verified_file_digests(paths) do
        run = function ()
            # Target verification and completed-stage reuse need no coefficient
            # replay. Materialize native state only for a missing operator block.
            state = Ref{Any}(nothing)
            prepared = (
                key = _qe_operator_state_key(source, topology_file, cache_size),
                state = state,
                owner = current_task(),
                paths = paths,
            )
            task_local_storage(
                () -> _with_spn_provenance_reuse(f),
                :wannier_qe_operator_preparation,
                prepared,
            )
        end
        checkpoint_directory === nothing && return run()
        inputs = sort!([(realpath(path), sha256_file(path)) for path in unique(native_paths)])
        contract = bytes2hex(SHA.sha256(implementation_contract * repr((source, inputs))))
        with_preparation_artifact_cache(run, checkpoint_directory, contract)
    end
end

"""Share native QE preparation across standalone operator calls without stage-dependent namespaces."""
function _with_qe_operator_artifacts(
    f,
    source,
    topology_file,
    output_directory,
    cache_size;
    execution = nothing,
    additional_inputs = String[],
)
    selected =
        execution === nothing ? get(task_local_storage(), :wannier_preparation_execution, nothing) :
        execution
    if selected !== nothing && (!selected.resume || selected.mode == :dense_reference)
        return task_local_storage(:wannier_preparation_artifact_cache, nothing) do
            task_local_storage(f, :wannier_qe_operator_preparation, nothing)
        end
    end
    root, implementation = _preparation_implementation_paths()
    return with_verified_file_digests(implementation) do
        contract = bytes2hex(
            SHA.sha256(repr([(relpath(path, root), sha256_file(path)) for path in implementation])),
        )
        directory =
            selected === nothing || selected.checkpoint_directory === nothing ?
            joinpath(output_directory, ".wannier_preparation", "qe") :
            joinpath(selected.checkpoint_directory, "shared-qe-native")
        return task_local_storage(:wannier_preparation_execution, selected) do
            _with_qe_operator_preparation(
                f,
                source,
                topology_file,
                cache_size;
                checkpoint_directory = directory,
                implementation_contract = contract,
                additional_inputs = additional_inputs,
            )
        end
    end
end

"""Prepare the validated lazy QE PAW state used for bounded-memory uIu generation."""
function _build_uiu_qe_state(
    source::QuantumEspressoWavefunctionSource,
    topology_file::AbstractString,
    max_cached_wavefunction_kpoints::Int,
)
    source.band_range === nothing ||
        throw(ArgumentError("QE_NNKP_BAND_AUTHORITY_REQUIRED: source.band_range must be nothing"))
    source.representation_cutoff_ev === nothing ||
        throw(ArgumentError("QE_PAW_RAW_COEFFICIENTS_REQUIRED: uIu requires the full cutoff"))
    max_cached_wavefunction_kpoints >= 2 ||
        throw(ArgumentError("QE_UIU_CACHE_TOO_SMALL: at least two k-points are required"))
    metadata = read_qe_xml(source)
    topology_path = abspath(topology_file)
    spin_components = metadata.noncollinear ? 2 : 1
    wavefunction_files = String[]
    headers = NamedTuple[]
    input_sha256 = Dict("data-file-schema.xml" => sha256_file(metadata.xml_file))
    for label in sort!(collect(keys(metadata.upf_files)))
        upf_file = metadata.upf_files[label]
        input_sha256["UPF:$(label):$(basename(upf_file))"] = sha256_file(upf_file)
    end
    for index in eachindex(metadata.kpoint_nodes)
        wavefunction_file = qe_wavefunction_file(source, index)
        push!(wavefunction_files, wavefunction_file)
        push!(headers, read_qe_wavefunction_header(wavefunction_file, spin_components))
        input_sha256[basename(wavefunction_file)] = sha256_file(wavefunction_file)
    end
    isempty(headers) && throw(ArgumentError("QE source contains no wavefunction files"))
    total_bands = first(headers).num_bands
    all(header -> header.num_bands == total_bands, headers) ||
        throw(ArgumentError("QE wavefunction files do not share one band count"))
    total_bands == metadata.num_bands || throw(
        ArgumentError(
            "QE_XML_WAVEFUNCTION_BAND_MISMATCH: XML=$(metadata.num_bands), wavefunction=$(total_bands)",
        ),
    )
    selected_bands = _qe_uiu_selected_bands(total_bands, topology_path)
    kpoints_fractional = Matrix{Float64}(undef, length(headers), 3)
    for (index, header) in enumerate(headers)
        kpoints_fractional[index, :] .= header.k_fractional
    end
    native = QEUIULazyNative(
        :qe,
        metadata.structure,
        metadata.reciprocal_lattice,
        infer_mp_grid(kpoints_fractional),
        metadata.noncollinear,
        kpoints_fractional,
        selected_bands,
        input_sha256,
        Dict(
            "coefficient_normalization" => "qe_raw",
            "nnkp_selected_bands" => join(selected_bands, ','),
        ),
    )
    topology = _uiu_topology(topology_path, native)
    if lowercase(splitext(topology_path)[2]) == ".nnkp"
        nnkp = read_wannier_nnkp(topology_path)
        native.spinor == nnkp.spinor ||
            throw(ArgumentError("QE_NNKP_SPIN_MISMATCH: native and NNKP spinor conventions differ"))
    end
    preparation_identity = bytes2hex(
        SHA.sha256(
            repr((
                sort!(collect(input_sha256); by = first),
                topology.source_sha256,
                selected_bands,
            )),
        ),
    )
    upf_data = cached_preparation_artifact("qe-upf", () -> preparation_identity) do
        Dict(
            label => read_qe_upf_data(path) for
            (label, path) in sort!(collect(metadata.upf_files); by = first)
        )
    end
    plan = cached_preparation_artifact("qe-projector-plan", () -> preparation_identity) do
        build_qe_projector_plan(metadata, upf_data)
    end
    metadata.spinorbit &&
        !native.spinor &&
        throw(ArgumentError("QE_UPF_DATA_REQUIRED: spin-orbit calculation has scalar coefficients"))
    energies = Vector{Vector{Float64}}(undef, length(metadata.kpoint_nodes))
    for (index, node) in enumerate(metadata.kpoint_nodes)
        values =
            HARTREE_TO_EV .*
            qe_xml_numbers(qe_xml_required(node, "./*[local-name()='eigenvalues']"))
        length(values) == total_bands ||
            throw(ArgumentError("QE XML band count mismatch at k-point $(index)"))
        energies[index] = values
    end
    radial_cache = Dict{Tuple{String, Int, Int}, Float64}()
    beta_cache = QEBetaOverlapCache(256 * 1024^2)
    beta_contractions = Ref(0)
    normalization_points = Ref(0)
    function load_entry(index::Int)
        point = read_qe_wavefunction_kpoint(
            wavefunction_files[index],
            selected_bands,
            energies[index],
            spin_components,
            nothing,
            metadata.reciprocal_lattice,
            false,
        )
        beta_overlap = _qe_cached_beta_overlap!(beta_cache, index) do
            cached_preparation_artifact(
                "qe-beta",
                () -> preparation_identity * ":" * string(index);
                unit = index,
            ) do
                beta_contractions[] += 1
                first(_qe_beta_overlap(point, native, upf_data, plan, radial_cache))
            end
        end
        return QEUIUCacheEntry(point, beta_overlap)
    end
    estimate_bytes =
        index -> begin
            plane_waves = headers[index].plane_wave_count
            bands = length(selected_bands)
            16 * bands * spin_components * (plane_waves + plan.num_channels) +
            24 * plane_waves +
            8 * bands +
            24 +
            5 * 128
        end
    wavefunction_cache = QEUIUWavefunctionCache(
        max_cached_wavefunction_kpoints,
        load_entry;
        max_bytes = _qe_coefficient_cache_budget(),
        estimate_bytes,
    )
    deferred_norm = get(task_local_storage(), :wannier_qe_defer_norm, false)
    norm_result = Ref{Any}(nothing)
    norm_points = Dict{Int, Any}()
    norm_cache = Dict{Tuple{String, NTuple{3, Float64}, Int, Bool}, Array{ComplexF64, 4}}()
    function norm_point(entry, cache)
        _qe_generalized_norm_residual_point(
            entry.point,
            entry.beta_overlap,
            upf_data,
            plan,
            metadata.spinorbit,
            cache,
        )
    end
    function accept_norm(index, value)
        value === nothing || (norm_points[index] = value)
        nothing
    end
    function finish_norm()
        if norm_result[] === nothing
            norm_result[] =
                cached_preparation_artifact("qe-generalized-norm", () -> preparation_identity) do
                    maximum_value = 0.0
                    worst = (0, 0, 0)
                    for index in 1:_uiu_num_kpoints(native)
                        value, local_index = if haskey(norm_points, index)
                            norm_points[index]
                        else
                            normalization_points[] += 1
                            norm_point(_qe_uiu_cache_entry!(wavefunction_cache, index), norm_cache)
                        end
                        if value > maximum_value
                            maximum_value = value
                            worst = (index, local_index[1], local_index[2])
                        end
                    end
                    (maximum_value, worst)
                end
            empty!(norm_points)
        end
        norm_result[]
    end
    if deferred_norm
        norm_result[] = cached_preparation_artifact(
            () -> nothing,
            "qe-generalized-norm",
            () -> preparation_identity;
            build_missing = false,
        )
    else
        finish_norm()
    end
    generalized_norm = norm_result[] === nothing ? nothing : norm_result[][1]
    generalized_norm_worst = norm_result[] === nothing ? nothing : norm_result[][2]
    finite_b_cache = Dict{Tuple{String, NTuple{3, Float64}, Int, Bool}, Array{ComplexF64, 4}}()
    overlap_contractions = Ref(0)
    function overlap(left_index, right_index, shift, b_fractional)
        identity = () -> preparation_identity * repr((left_index, right_index, shift, b_fractional))
        return cached_preparation_artifact("qe-overlap", identity; unit = left_index) do
            overlap_contractions[] += 1
            left = _qe_uiu_cache_entry!(wavefunction_cache, left_index)
            right = _qe_uiu_cache_entry!(wavefunction_cache, right_index)
            pseudo = _paw_pseudo_mmn_block(
                left.point,
                right.point,
                shift;
                threaded_spin = Threads.nthreads() > 1,
            )
            b_cartesian_bohr_inverse =
                BOHR_TO_ANGSTROM .* (transpose(native.reciprocal_lattice) * b_fractional)
            augmentation = _qe_augmentation_block(
                left.beta_overlap,
                right.beta_overlap,
                upf_data,
                plan,
                Vector{Float64}(b_fractional),
                b_cartesian_bohr_inverse,
                metadata.spinorbit,
                finite_b_cache,
            )
            return pseudo .+ augmentation
        end
    end
    q0_by_atom = [
        _qe_q0_scalar_matrix(upf_data[atom.atomic_type_label], atom.channels) for atom in plan.atoms
    ]
    pauli_matrices = _vasp_paw_cartesian_pauli_matrices()
    function spn_evaluate(entry::QEUIUCacheEntry)
        point = entry.point
        bands = size(point.coefficients, 1)
        pseudo = zeros(ComplexF64, bands, bands, 3)
        augmentation = zeros(ComplexF64, bands, bands, 3)
        for (component, pauli) in enumerate(pauli_matrices)
            for left_spin in 1:2, right_spin in 1:2
                factor = pauli[left_spin, right_spin]
                iszero(factor) && continue
                left_coefficients = @view point.coefficients[:, :, left_spin]
                right_coefficients = @view point.coefficients[:, :, right_spin]
                pseudo[:, :, component] .+=
                    factor .* (conj(left_coefficients) * transpose(right_coefficients))
                for (atom_index, atom) in pairs(plan.atoms)
                    dataset = upf_data[atom.atomic_type_label]
                    dataset.metric_kind == :norm_conserving && continue
                    left = @view entry.beta_overlap[:, atom.channel_range, left_spin]
                    right = @view entry.beta_overlap[:, atom.channel_range, right_spin]
                    augmentation[:, :, component] .+=
                        factor .* (conj(left) * q0_by_atom[atom_index] * transpose(right))
                end
            end
        end
        all(isfinite, pseudo) && all(isfinite, augmentation) ||
            throw(ArgumentError("QE_PAW_SPN_NONFINITE: pseudo or augmentation block is non-finite"))
        return pseudo .+ augmentation, pseudo, augmentation
    end
    spn_input = function (index)
        norm_result[] === nothing && (normalization_points[] += 1)
        _qe_uiu_cache_entry!(wavefunction_cache, index)
    end
    spn_block = index -> spn_evaluate(spn_input(index))
    function spn_evaluate_with_norm(entry)
        spin = spn_evaluate(entry)
        local_norm =
            norm_result[] === nothing ?
            norm_point(
                entry,
                Dict{Tuple{String, NTuple{3, Float64}, Int, Bool}, Array{ComplexF64, 4}}(),
            ) : nothing
        (spin..., local_norm)
    end
    input_sha256["TOPOLOGY"] = topology.source_sha256
    diagnostics = String[
        "generalized_norm_worst=$(generalized_norm_worst)",
        "qe_metric_kinds=$(join(metadata.metric_kinds, ','))",
    ]
    return (;
        native,
        topology,
        overlap,
        generalized_norm,
        radial_q_maximum = 0.0,
        input_sha256,
        diagnostics,
        wavefunction_cache,
        beta_cache,
        beta_contractions,
        normalization_points,
        overlap_contractions,
        spn_block,
        spn_input,
        spn_evaluate,
        spn_evaluate_with_norm,
        accept_norm,
        finish_norm,
    )
end

"""Expose completed normalization only after its ordered reduction is available."""
function _qe_state_with_completed_norm(state)
    value, worst = state.finish_norm()
    diagnostics = filter(item -> !startswith(item, "generalized_norm_worst="), state.diagnostics)
    pushfirst!(diagnostics, "generalized_norm_worst=$(worst)")
    merge(state, (generalized_norm = value, diagnostics = diagnostics))
end

"""Dispatch uIu state construction for a VASP wavefunction source."""
_uiu_source_state(source::VASPWavefunctionSource, topology_file, _) =
    _uiu_vasp_state(source, topology_file)
"""Dispatch uIu state construction for a QE wavefunction source."""
_uiu_source_state(source::QuantumEspressoWavefunctionSource, topology_file, cache_size) =
    _uiu_qe_state(source, topology_file, cache_size)

"""Attach target-hard and parent-audit generalized-norm evidence to one uIu state."""
function _uiu_state_with_qualification_scope(state, target_contract)
    if target_contract === nothing
        return merge(
            state,
            (
                parent_generalized_norm = state.generalized_norm,
                target_generalized_norm_worst = (0, 0, 0),
                parent_generalized_norm_worst = (0, 0, 0),
                target_authority = "full_parent",
                parent_audit_policy = "legacy_hard_gate",
                outer_mask_sha256 = "LEGACY_NOT_RECORDED",
                frozen_mask_sha256 = "LEGACY_NOT_RECORDED",
            ),
        )
    end
    contract = something(target_contract)
    if contract.parent_audit_policy == "legacy_hard_gate"
        return merge(
            state,
            (
                parent_generalized_norm = state.generalized_norm,
                target_generalized_norm_worst = (0, 0, 0),
                parent_generalized_norm_worst = (0, 0, 0),
                target_authority = "full_parent",
                parent_audit_policy = "legacy_hard_gate",
                outer_mask_sha256 = contract.qualification_scope.outer_mask_sha256,
                frozen_mask_sha256 = contract.qualification_scope.frozen_mask_sha256,
            ),
        )
    end
    contract.target_authority == "outer_window" ||
        throw(ArgumentError("UIU_TARGET_AUTHORITY_MISMATCH"))
    contract.parent_audit_policy == "audit_only" ||
        throw(ArgumentError("UIU_PARENT_AUDIT_POLICY_MISMATCH"))
    scope = contract.qualification_scope
    size(scope.outer_mask) == (state.topology.num_bands, state.topology.num_kpts) ||
        throw(ArgumentError("UIU_QUALIFICATION_SCOPE_DIMENSION_MISMATCH"))
    _operator_qualification_mask_sha256(scope.outer_mask) == scope.outer_mask_sha256 ||
        throw(ArgumentError("UIU_OUTER_MASK_DIGEST_MISMATCH"))
    _operator_qualification_mask_sha256(scope.frozen_mask) == scope.frozen_mask_sha256 ||
        throw(ArgumentError("UIU_FROZEN_MASK_DIGEST_MISMATCH"))
    target_maximum = 0.0
    target_worst = (0, 0, 0)
    for kpoint in 1:state.topology.num_kpts
        overlap = state.overlap(kpoint, kpoint, (0, 0, 0), zeros(3))
        all(isfinite, overlap) || throw(ArgumentError("FATAL_INTEGRITY: nonfinite uIu q=0 metric"))
        selected = BitVector(@view scope.outer_mask[:, kpoint])
        isempty(findall(selected)) && throw(ArgumentError("UIU_EMPTY_TARGET_SCOPE"))
        value, local_index = _paw_scoped_identity_residual(overlap, selected)
        if value > target_maximum
            target_maximum = value
            target_worst = (kpoint, local_index[1], local_index[2])
        end
    end
    diagnostics = filter(item -> !startswith(item, "generalized_norm_worst="), state.diagnostics)
    append!(
        diagnostics,
        (
            "target_generalized_norm_worst=$(target_worst)",
            "parent_generalized_norm_max_absolute=$(state.generalized_norm)",
        ),
    )
    return merge(
        state,
        (
            generalized_norm = target_maximum,
            parent_generalized_norm = state.generalized_norm,
            target_generalized_norm_worst = target_worst,
            parent_generalized_norm_worst = (0, 0, 0),
            target_authority = "outer_window",
            parent_audit_policy = "audit_only",
            outer_mask_sha256 = scope.outer_mask_sha256,
            frozen_mask_sha256 = scope.frozen_mask_sha256,
            diagnostics,
        ),
    )
end

"""Compute one center-to-neighbor physical-overlap block."""
function _uiu_center_neighbor_block(state, center::Int, neighbor::Int)
    right_index = state.topology.neighbors[neighbor, center]
    topology_shift = @view state.topology.reciprocal_shifts[:, neighbor, center]
    center_offset = _uiu_native_frame_offset(state.native, state.topology, center)
    right_offset = _uiu_native_frame_offset(state.native, state.topology, right_index)
    shift = Tuple(Int.(topology_shift .- right_offset .+ center_offset))
    b_fractional =
        _uiu_kpoint_fractional(state.native, right_index) .+ collect(shift) .-
        _uiu_kpoint_fractional(state.native, center)
    return state.overlap(center, right_index, shift, Vector{Float64}(b_fractional))
end

"""Compare generated center-neighbor overlaps with a streamed MMN oracle."""
function _uiu_mmn_parity(state, oracle_file::AbstractString)
    topology = state.topology
    maximum_value = -Inf
    worst = Int[]
    sum_squared = 0.0
    oracle_squared = 0.0
    count = 0
    finite = true
    neighbor_counter = zeros(Int, topology.num_kpts)
    foreach_wannier_mmn_block(
        oracle_file;
        expected_num_bands = topology.num_bands,
        expected_num_kpoints = topology.num_kpts,
    ) do center, right_index, shift, oracle
        neighbor_counter[center] += 1
        neighbor = neighbor_counter[center]
        neighbor <= topology.num_neighbors ||
            throw(ArgumentError("UIU_MMN_ORACLE_NEIGHBOR_COUNT_MISMATCH"))
        right_index == topology.neighbors[neighbor, center] &&
        shift == Tuple(topology.reciprocal_shifts[:, neighbor, center]) ||
            throw(ArgumentError("UIU_MMN_ORACLE_TOPOLOGY_MISMATCH"))
        generated = _uiu_center_neighbor_block(state, center, neighbor)
        for index in CartesianIndices(generated)
            residual = generated[index] - oracle[index]
            absolute = abs(residual)
            finite &= isfinite(absolute)
            sum_squared += abs2(residual)
            oracle_squared += abs2(oracle[index])
            count += 1
            if absolute > maximum_value
                maximum_value = absolute
                worst = [index[1], index[2], neighbor, center]
            end
        end
        neighbor == topology.num_neighbors &&
            (center == 1 || center % 10 == 0 || center == topology.num_kpts) &&
            @info "uIu MMN oracle progress" center topology.num_kpts
    end
    all(==(topology.num_neighbors), neighbor_counter) ||
        throw(ArgumentError("UIU_MMN_ORACLE_NEIGHBOR_COUNT_MISMATCH"))
    return WannierUIUParityMetrics(
        maximum_value,
        sqrt(sum_squared / count),
        sqrt(sum_squared / max(oracle_squared, eps(Float64))),
        worst,
        finite,
    )
end

"""Evaluate all configured MMN parity thresholds."""
function _uiu_mmn_passes(metric::WannierUIUParityMetrics, thresholds)
    return metric.finite &&
           metric.max_absolute <= thresholds.mmn_max_absolute &&
           metric.root_mean_square <= thresholds.mmn_rms &&
           metric.relative_l2 <= thresholds.mmn_relative_l2
end

"""Hash the complete input, policy, and topology identity used by restart validation."""
function _uiu_input_fingerprint(
    input_sha256::Dict{String, String},
    topology,
    construction_policy::Symbol,
)
    buffer = IOBuffer()
    for (name, digest) in sort!(collect(input_sha256); by = first)
        write(buffer, name, '=', digest, '\n')
    end
    write(
        buffer,
        WANNIER_UIU_ALGORITHM_VERSION,
        '\n',
        string(topology.num_bands),
        ' ',
        string(topology.num_kpts),
        ' ',
        string(topology.num_neighbors),
        '\n',
        String(construction_policy),
        '\n',
    )
    return bytes2hex(SHA.sha256(take!(buffer)))
end

"""Resolve output, provenance, scratch, partial, and checkpoint paths."""
function _uiu_partial_paths(config::WannierUIUGenerationConfig)
    output = abspath(config.output_file)
    provenance =
        config.provenance_json === nothing ? output * ".provenance.json" :
        abspath(something(config.provenance_json))
    scratch =
        config.scratch_directory === nothing ? dirname(output) :
        abspath(something(config.scratch_directory))
    partial = joinpath(scratch, basename(output) * ".partial")
    checkpoint = partial * ".json"
    return (; output, provenance, scratch, partial, checkpoint)
end

"""Create validated uIu output directories only after all early input gates pass."""
function _materialize_uiu_output_directories(paths)
    mkpath(dirname(paths.output))
    mkpath(dirname(paths.provenance))
    mkpath(paths.scratch)
    stat(dirname(paths.output)).device == stat(paths.scratch).device ||
        throw(ArgumentError("UIU_ATOMIC_SCRATCH_FILESYSTEM_MISMATCH"))
    return nothing
end

"""Write the uIu comment and dimension records and return the data offset."""
function _uiu_header!(io::Base.IO, topology::WannierNeighborTopology)
    comment = Vector{UInt8}(codeunits("Generated by WannierNLQG $(WANNIER_UIU_ALGORITHM_VERSION)"))
    _uiu_write_fortran_record(io, comment)
    _uiu_write_fortran_record(
        io,
        _uiu_int32_bytes((topology.num_bands, topology.num_kpts, topology.num_neighbors)),
    )
    return position(io)
end

"""Validate a partial uIu header and return the data offset."""
function _uiu_read_header!(io::Base.IO, topology::WannierNeighborTopology)
    _ = String(read_fortran_record(io))
    dimension_bytes = read_fortran_record(io)
    length(dimension_bytes) == 3sizeof(Int32) ||
        throw(ArgumentError("UIU_PARTIAL_HEADER_DIMENSION_MISMATCH"))
    dimensions = Int.(collect(reinterpret(Int32, dimension_bytes)))
    dimensions == [topology.num_bands, topology.num_kpts, topology.num_neighbors] ||
        throw(ArgumentError("UIU_PARTIAL_HEADER_MISMATCH"))
    return position(io)
end

"""Scan, validate, and safely truncate a partial uIu stream at record boundaries."""
function _uiu_scan_partial(
    partial::AbstractString,
    topology::WannierNeighborTopology;
    repair_truncated::Bool = true,
)
    isfile(partial) || return (0, String[], 0.0, 0.0)
    completed = 0
    checksums = String[]
    diagonal_maximum = 0.0
    hermiticity_maximum = 0.0
    truncate_at = nothing
    open(partial, "r") do io
        _uiu_read_header!(io, topology)
        for center in 1:topology.num_kpts
            kpoint_start = position(io)
            blocks =
                Matrix{Matrix{ComplexF64}}(undef, topology.num_neighbors, topology.num_neighbors)
            digest_buffer = IOBuffer()
            complete_center = true
            for second in 1:topology.num_neighbors, first in 1:topology.num_neighbors
                expected_record_bytes = topology.num_bands^2 * sizeof(ComplexF64) + 8
                if filesize(partial) - position(io) < expected_record_bytes
                    complete_center = false
                    break
                end
                bytes = try
                    read_fortran_record(io)
                catch error
                    message = sprint(showerror, error)
                    if occursin("Unexpected end", message) || occursin("Truncated", message)
                        complete_center = false
                        break
                    end
                    rethrow()
                end
                length(bytes) == topology.num_bands^2 * sizeof(ComplexF64) ||
                    throw(ArgumentError("UIU_PARTIAL_BLOCK_SIZE_MISMATCH"))
                write(digest_buffer, bytes)
                raw = reshape(
                    collect(reinterpret(ComplexF64, bytes)),
                    topology.num_bands,
                    topology.num_bands,
                )
                blocks[first, second] = copy(transpose(raw))
            end
            if !complete_center
                truncate_at = kpoint_start
                break
            end
            for first in 1:topology.num_neighbors
                identity_residual = blocks[first, first] - I
                diagonal_maximum = max(diagonal_maximum, maximum(abs, identity_residual))
                for second in 1:topology.num_neighbors
                    hermiticity_maximum = max(
                        hermiticity_maximum,
                        maximum(abs, blocks[first, second] - blocks[second, first]'),
                    )
                end
            end
            push!(checksums, bytes2hex(SHA.sha256(take!(digest_buffer))))
            completed = center
        end
        if truncate_at === nothing && !eof(io)
            throw(ArgumentError("UIU_PARTIAL_TRAILING_BYTES"))
        end
    end
    if truncate_at !== nothing
        repair_truncated || throw(ArgumentError("UIU_UNCOMMITTED_OUTPUT_TRUNCATED"))
        open(partial, "r+") do io
            truncate(io, something(truncate_at))
        end
    end
    return completed, checksums, diagonal_maximum, hermiticity_maximum
end

"""Recover an interrupted final rename only after read-only payload verification."""
function _uiu_recover_publication!(paths, topology, fingerprint, execution_contract)
    isfile(paths.output) &&
    isfile(paths.checkpoint) &&
    !ispath(paths.provenance) &&
    !ispath(paths.partial) || throw(ArgumentError("UIU_PUBLICATION_RECOVERY_STATE_MISMATCH"))
    completed, checksums, diagonal, hermiticity =
        _uiu_scan_partial(paths.output, topology; repair_truncated = false)
    all(isfinite, (diagonal, hermiticity)) ||
        throw(ArgumentError("UIU_UNCOMMITTED_OUTPUT_NONFINITE"))
    completed == topology.num_kpts || throw(ArgumentError("UIU_UNCOMMITTED_OUTPUT_INCOMPLETE"))
    _uiu_validate_checkpoint(
        paths.checkpoint,
        fingerprint,
        completed,
        checksums,
        execution_contract,
    )
    checkpoint = JSON3.read(read(paths.checkpoint, String))
    Int(checkpoint.completed_kpoints) == completed ||
        throw(ArgumentError("UIU_PUBLICATION_CHECKPOINT_INCOMPLETE"))
    mv(paths.output, paths.partial; force = false)
    return completed
end

"""Return the restart-sensitive execution contract for the selected source state."""
function _uiu_execution_contract(state)
    block_order =
        state.wavefunction_cache === nothing ? "wannier_record_cartesian" :
        "directed_euler_cache_aware"
    return join(
        (
            WANNIER_UIU_ALGORITHM_VERSION,
            String(state.native.source_code),
            block_order,
            "julia_threads=$(Threads.nthreads())",
        ),
        '|',
    )
end

"""Build the atomic checkpoint payload for a partial uIu stream."""
function _uiu_checkpoint_payload(fingerprint, topology, completed, checksums, execution_contract)
    return Dict(
        "schema" => WANNIER_UIU_GENERATION_SCHEMA * ".partial",
        "schema_version" => WANNIER_UIU_GENERATION_SCHEMA_VERSION,
        "algorithm_version" => WANNIER_UIU_ALGORITHM_VERSION,
        "execution_contract" => execution_contract,
        "input_fingerprint_sha256" => fingerprint,
        "num_bands" => topology.num_bands,
        "num_kpts" => topology.num_kpts,
        "num_neighbors" => topology.num_neighbors,
        "completed_kpoints" => completed,
        "kpoint_payload_sha256" => checksums,
    )
end

"""Validate a checkpoint against the scanned partial stream and execution contract."""
function _uiu_validate_checkpoint(checkpoint, fingerprint, completed, checksums, execution_contract)
    isfile(checkpoint) || return nothing
    payload = JSON3.read(read(checkpoint, String))
    String(payload.input_fingerprint_sha256) == fingerprint ||
        throw(ArgumentError("UIU_RESUME_INPUT_FINGERPRINT_MISMATCH"))
    hasproperty(payload, :execution_contract) &&
    String(payload.execution_contract) == execution_contract ||
        throw(ArgumentError("UIU_RESUME_EXECUTION_CONTRACT_MISMATCH"))
    recorded = Int(payload.completed_kpoints)
    recorded <= completed || throw(ArgumentError("UIU_RESUME_CHECKPOINT_AHEAD_OF_PARTIAL"))
    recorded_checksums = String.(payload.kpoint_payload_sha256)
    recorded_checksums == checksums[1:recorded] ||
        throw(ArgumentError("UIU_RESUME_RECORD_CHECKSUM_MISMATCH"))
    return nothing
end

"""Construct a deterministic Euler traversal containing each directed neighbor pair once."""
function _uiu_directed_euler_pair_order(count::Int)
    count > 0 || throw(ArgumentError("UIU_NEIGHBOR_COUNT_MUST_BE_POSITIVE"))
    next_target = ones(Int, count)
    stack = Int[1]
    circuit = Int[]
    while !isempty(stack)
        source = last(stack)
        if next_target[source] <= count
            target = next_target[source]
            next_target[source] += 1
            push!(stack, target)
        else
            push!(circuit, pop!(stack))
        end
    end
    reverse!(circuit)
    pairs = [(circuit[index], circuit[index + 1]) for index in 1:(length(circuit) - 1)]
    length(pairs) == count^2 || error("UIU_DIRECTED_EULER_ORDER_LENGTH_MISMATCH")
    length(unique(pairs)) == count^2 || error("UIU_DIRECTED_EULER_ORDER_DUPLICATE")
    return pairs
end

"""Select the cache-stable evaluation order for one center's neighbor pairs."""
function _uiu_center_pair_order(state, count::Int)
    cache = state.wavefunction_cache
    # Use one deterministic block-evaluation order for every streamed QE cache
    # size.  The record writer below still emits Wannier90's ik->nn2->nn1
    # order; this only fixes the order in which the cached wavefunctions enter
    # BLAS.  Keeping that order cache-size independent is required for the
    # cache=2/cache=8 bit-exact oracle on real spinor wavefunctions.
    if cache !== nothing
        return _uiu_directed_euler_pair_order(count)
    end
    return [(first, second) for second in 1:count for first in 1:count]
end

"""Compute every neighbor-neighbor block for one center k-point."""
function _uiu_compute_center_blocks(state, center::Int, gauge_contract = nothing)
    count = state.topology.num_neighbors
    blocks = Matrix{Matrix{ComplexF64}}(undef, count, count)
    for (first, second) in _uiu_center_pair_order(state, count)
        left_index, right_index, shift, b_fractional =
            _uiu_overlap_geometry(state.native, state.topology, center, first, second)
        native_block = state.overlap(left_index, right_index, shift, b_fractional)
        blocks[first, second] =
            gauge_contract === nothing ? native_block :
            _rotate_generation_link(native_block, gauge_contract, left_index, right_index)
    end
    return blocks
end

"""Append one center's blocks in Wannier90 record order and return its checksum."""
function _uiu_write_center!(io, blocks, topology)
    digest_buffer = IOBuffer()
    for second in 1:topology.num_neighbors, first in 1:topology.num_neighbors
        bytes = _uiu_matrix_bytes(blocks[first, second])
        _uiu_write_fortran_record(io, bytes)
        write(digest_buffer, bytes)
    end
    return bytes2hex(SHA.sha256(take!(digest_buffer)))
end

"""Measure diagonal-identity and exchange-Hermiticity residuals for one center."""
function _uiu_block_diagnostics(blocks, topology)
    diagonal = 0.0
    hermiticity = 0.0
    for first in 1:topology.num_neighbors
        diagonal = max(diagonal, maximum(abs, blocks[first, first] - I))
        for second in 1:topology.num_neighbors
            hermiticity =
                max(hermiticity, maximum(abs, blocks[first, second] - blocks[second, first]'))
        end
    end
    return diagonal, hermiticity
end

"""Serialize bounded-cache statistics for the uIu provenance sidecar."""
_uiu_cache_payload(state) =
    state.wavefunction_cache === nothing ? nothing :
    Dict(
        "max_cached_wavefunction_kpoints" => state.wavefunction_cache.max_entries,
        "hits" => state.wavefunction_cache.hits,
        "misses" => state.wavefunction_cache.misses,
        "evictions" => state.wavefunction_cache.evictions,
        "reloads" => state.wavefunction_cache.reloads,
        "distinct_kpoints_loaded" => length(state.wavefunction_cache.load_counts),
        "total_kpoint_reads" => sum(values(state.wavefunction_cache.load_counts)),
        "peak_cached_kpoints" => state.wavefunction_cache.peak_entries,
        "peak_cache_resident_bytes" => state.wavefunction_cache.peak_resident_bytes,
        "policy" => "deterministic_lru",
        "block_evaluation_order" => "directed_euler_cache_aware",
        "entry_contract" => "one_kpoint_full_coefficients_plus_beta_overlap",
    )

"""Format bounded-cache counters as stable diagnostic strings."""
function _uiu_cache_diagnostics(state)
    state.wavefunction_cache === nothing && return String[]
    cache = state.wavefunction_cache
    return [
        "qe_uiu_cache_max_entries=$(cache.max_entries)",
        "qe_uiu_cache_hits=$(cache.hits)",
        "qe_uiu_cache_misses=$(cache.misses)",
        "qe_uiu_cache_evictions=$(cache.evictions)",
        "qe_uiu_cache_reloads=$(cache.reloads)",
        "qe_uiu_cache_peak_resident_bytes=$(cache.peak_resident_bytes)",
    ]
end

"""Assemble the complete uIu qualification and provenance payload."""
function _uiu_provenance_payload(
    config,
    state,
    gauge_contract,
    paths,
    fingerprint,
    mmn_parity,
    diagonal,
    hermiticity,
    passed,
    resumed,
    checksums,
    peak_memory,
    diagnostics,
)
    json_number(value) = isfinite(value) ? value : nothing
    output_hash = isfile(paths.output) ? sha256_file(paths.output) : "NOT_PUBLISHED"
    published_warning =
        !passed &&
        config.construction_policy == :standard &&
        "UIU_GENERATION_NUMERICAL_WARNING" in diagnostics
    published = passed || published_warning
    return Dict(
        "schema" => WANNIER_UIU_GENERATION_SCHEMA,
        "schema_version" => WANNIER_UIU_GENERATION_SCHEMA_VERSION,
        "algorithm_version" => WANNIER_UIU_ALGORITHM_VERSION,
        "source_code" => String(state.native.source_code),
        "source_band_gauge" => gauge_contract.source_band_gauge,
        "target_band_gauge" => gauge_contract.target_band_gauge,
        "band_frame_transform_sha256" => gauge_contract.transform_sha256,
        "band_frame_contract_sha256" => gauge_contract.contract_sha256,
        "band_frame_contract" => band_frame_contract_summary(gauge_contract),
        "band_gauge_rotation_sha256" => gauge_contract.transform_sha256,
        "band_gauge_rotation_semantics" => "legacy_alias_of_band_frame_transform_sha256",
        "gauge_artifact_sha256" =>
            something(gauge_contract.gauge_artifact_sha256, "NOT_APPLICABLE"),
        "authoritative_hamiltonian" =>
            authoritative_hamiltonian_key(config.authoritative_hamiltonian),
        "construction_policy" => String(config.construction_policy),
        "model_qualification" =>
            config.construction_policy == :standard ? "STANDARD" : passed ? "PASS" : "FAILED_GATE",
        "quality_review_recommended" => config.construction_policy == :standard,
        "production_eligible" => config.construction_policy == :strict && passed,
        "status" => passed ? "PASS" : published_warning ? "EXPORTED_WITH_WARNING" : "FAILED_GATE",
        "physical_overlap_available" => published,
        "passed" => passed,
        "num_bands" => state.topology.num_bands,
        "num_kpts" => state.topology.num_kpts,
        "num_neighbors" => state.topology.num_neighbors,
        "record_order" => "ik->nn2->nn1",
        "complex_storage" => "ComplexF64 Fortran-unformatted 32-bit record markers",
        "relative_reciprocal_shift" => "G2-G1",
        "paw_metric" => "pseudo_plus_finite_b_augmentation",
        "generalized_normalization_max_absolute" => state.generalized_norm,
        "target_generalized_normalization_max_absolute" => state.generalized_norm,
        "parent_generalized_normalization_max_absolute" => state.parent_generalized_norm,
        "target_authority" => state.target_authority,
        "parent_audit_policy" => state.parent_audit_policy,
        "parent_audit_status" =>
            state.parent_generalized_norm <= config.thresholds.generalized_norm_max_absolute &&
            diagonal <= config.thresholds.diagonal_identity_max_absolute ? "PASS" :
            "AUDIT_EXCEEDED",
        "outer_mask_sha256" => state.outer_mask_sha256,
        "frozen_mask_sha256" => state.frozen_mask_sha256,
        "operator_target_contract_sha256" =>
            config.target_contract === nothing ? "LEGACY_NOT_RECORDED" :
            config.target_contract.contract_sha256,
        "radial_q_max_absolute" => state.radial_q_maximum,
        "mmn_parity" =>
            mmn_parity === nothing ? nothing :
            Dict(
                "max_absolute" => mmn_parity.max_absolute,
                "root_mean_square" => mmn_parity.root_mean_square,
                "relative_l2" => mmn_parity.relative_l2,
                "worst_index" => mmn_parity.worst_index,
                "finite" => mmn_parity.finite,
            ),
        "diagonal_identity_max_absolute" => json_number(diagonal),
        "exchange_hermiticity_max_absolute" => json_number(hermiticity),
        "thresholds" => Dict(
            String(field) => getfield(config.thresholds, field) for
            field in fieldnames(WannierUIUGenerationThresholds)
        ),
        "input_fingerprint_sha256" => fingerprint,
        "input_sha256" => state.input_sha256,
        "output_file" => paths.output,
        "output_sha256" => output_hash,
        "resumed_from_kpoint" => resumed,
        "kpoint_payload_sha256" => checksums,
        "peak_memory_bytes" => peak_memory,
        "wavefunction_cache" => _uiu_cache_payload(state),
        "julia_version" => string(VERSION),
        "julia_threads" => Threads.nthreads(),
        "diagnostics" => diagnostics,
    )
end

"""Publish fail-closed provenance without publishing an unqualified uIu artifact."""
function _uiu_failed_result(
    config,
    state,
    gauge_contract,
    paths,
    fingerprint,
    mmn_parity,
    diagnostics,
)
    peak_memory = try
        Int(Sys.maxrss())
    catch
        0
    end
    payload = _uiu_provenance_payload(
        config,
        state,
        gauge_contract,
        paths,
        fingerprint,
        mmn_parity,
        NaN,
        NaN,
        false,
        0,
        String[],
        peak_memory,
        diagnostics,
    )
    _uiu_atomic_json(paths.provenance, payload)
    artifacts = Dict("provenance_json" => paths.provenance)
    return WannierUIUGenerationResult(
        state.native.source_code,
        state.topology.num_bands,
        state.topology.num_kpts,
        state.topology.num_neighbors,
        state.generalized_norm,
        mmn_parity,
        NaN,
        NaN,
        false,
        0,
        peak_memory,
        artifacts,
        state.input_sha256,
        diagnostics,
    )
end

"""
    generate_wannier_uiu(config)

Generate, qualify, checkpoint, and atomically publish a native PAW Wannier90 uIu file.
"""
function generate_wannier_uiu(config::WannierUIUGenerationConfig)
    execution =
        config.execution === nothing ?
        get(task_local_storage(), :wannier_preparation_execution, nothing) : config.execution
    if !(config.source isa Union{QuantumEspressoWavefunctionSource, VASPWavefunctionSource}) ||
       !config.resume ||
       (execution !== nothing && (!execution.resume || execution.mode == :dense_reference))
        return _generate_wannier_uiu_scoped(config)
    end
    if config.source isa VASPWavefunctionSource && config.source.potcar_file === nothing
        return _generate_wannier_uiu_scoped(config)
    end
    config.construction_policy in (:standard, :strict) ||
        throw(ArgumentError("construction_policy must be :standard or :strict"))
    config.max_cached_wavefunction_kpoints >= 2 ||
        throw(ArgumentError("max_cached_wavefunction_kpoints must be at least two"))
    oracle = _effective_uiu_oracle_mmn_file(config)
    authority_mmn =
        _operator_target_oracle_mmn_file(config.authoritative_mmn_file, config.target_contract)
    authority_mmn === nothing && (authority_mmn = oracle)
    paths = _uiu_partial_paths(config)
    inputs = String[config.topology_file]
    for path in (oracle, authority_mmn, config.wavefunction_gauge_hdf5)
        path === nothing || push!(inputs, path)
    end
    if config.target_contract !== nothing
        push!(
            inputs,
            config.target_contract.operator_oracle_mmn_file,
            config.target_contract.solver_mmn_file,
        )
    end
    _validate_generation_output_paths(paths, inputs, config.source)
    return with_verified_file_digests(inputs) do
        _validate_authoritative_mmn_binding(
            config.topology_file,
            authority_mmn;
            oracle_mmn_file = oracle,
        )
        config.target_contract === nothing || _validate_operator_target_contract_config(
            something(config.target_contract),
            config.authoritative_hamiltonian,
            config.wavefunction_gauge_hdf5,
        )
        _with_operator_publication_receipt(
            () -> _generate_wannier_uiu_scoped(config),
            config,
            :uIu,
            paths,
            inputs;
            execution = execution,
            published = result -> haskey(result.artifacts, "uiu_sha256"),
        )
    end
end

"""Prepare a missing uIu publication inside the configured native-data scope."""
function _generate_wannier_uiu_scoped(config::WannierUIUGenerationConfig)
    if !(config.source isa VASPWavefunctionSource) && config.execution === nothing
        return _generate_wannier_uiu_impl(config)
    end
    config.construction_policy in (:standard, :strict) ||
        throw(ArgumentError("construction_policy must be :standard or :strict"))
    config.max_cached_wavefunction_kpoints >= 2 ||
        throw(ArgumentError("max_cached_wavefunction_kpoints must be at least two"))
    paths = _uiu_partial_paths(config)
    inputs = String[config.topology_file]
    for path in
        (config.oracle_mmn_file, config.authoritative_mmn_file, config.wavefunction_gauge_hdf5)
        path === nothing || push!(inputs, path)
    end
    if config.target_contract !== nothing
        push!(
            inputs,
            config.target_contract.operator_oracle_mmn_file,
            config.target_contract.solver_mmn_file,
        )
    end
    _validate_generation_output_paths(
        (;
            output = paths.output,
            provenance = paths.provenance,
            scratch = paths.scratch,
            partial = paths.partial,
            checkpoint = paths.checkpoint,
        ),
        inputs,
        config.source,
    )
    recover =
        config.resume &&
        isfile(paths.output) &&
        isfile(paths.checkpoint) &&
        !ispath(paths.provenance) &&
        !ispath(paths.partial)
    ispath(paths.output) &&
        !config.overwrite &&
        !recover &&
        throw(ArgumentError("refusing to overwrite uIu output: $(paths.output)"))
    ispath(paths.provenance) &&
        !config.overwrite &&
        throw(ArgumentError("refusing to overwrite uIu provenance: $(paths.provenance)"))
    if config.source isa QuantumEspressoWavefunctionSource
        execution = something(config.execution)
        reuse = execution.resume && execution.mode != :dense_reference
        root, implementation = _preparation_implementation_paths()
        return with_verified_file_digests(implementation) do
            contract = bytes2hex(
                SHA.sha256(
                    repr([(relpath(path, root), sha256_file(path)) for path in implementation]),
                ),
            )
            directory =
                reuse ?
                joinpath(
                    something(execution.checkpoint_directory, dirname(paths.output)),
                    "shared-qe-native",
                ) : nothing
            run =
                () -> _with_qe_operator_preparation(
                    () -> _generate_wannier_uiu_impl(config),
                    config.source,
                    config.topology_file,
                    config.max_cached_wavefunction_kpoints;
                    checkpoint_directory = directory,
                    implementation_contract = contract,
                    additional_inputs = inputs,
                )
            task_local_storage(:wannier_preparation_execution, execution) do
                reuse && return run()
                task_local_storage(:wannier_preparation_artifact_cache, nothing) do
                    task_local_storage(run, :wannier_qe_operator_preparation, nothing)
                end
            end
        end
    end
    config.source.potcar_file === nothing &&
        throw(ArgumentError("VASP_PAW_DATA_REQUIRED: uIu generation requires POTCAR"))
    return _with_vasp_operator_artifacts(
        config.source,
        dirname(paths.output);
        execution = config.execution,
        additional_inputs = inputs,
    ) do
        _generate_wannier_uiu_impl(config)
    end
end

"""Execute the existing uIu validation, scientific kernels and publication within its scope."""
function _generate_wannier_uiu_impl(config::WannierUIUGenerationConfig)
    config.construction_policy in (:standard, :strict) ||
        throw(ArgumentError("construction_policy must be :standard or :strict"))
    config.max_cached_wavefunction_kpoints >= 2 ||
        throw(ArgumentError("max_cached_wavefunction_kpoints must be at least two"))
    effective_oracle_mmn_file = _effective_uiu_oracle_mmn_file(config)
    authoritative_mmn_file =
        _operator_target_oracle_mmn_file(config.authoritative_mmn_file, config.target_contract)
    authoritative_mmn_file === nothing && (authoritative_mmn_file = effective_oracle_mmn_file)
    authoritative_mmn_sha256 = _validate_authoritative_mmn_binding(
        config.topology_file,
        authoritative_mmn_file;
        oracle_mmn_file = effective_oracle_mmn_file,
    )
    config.target_contract === nothing || _validate_operator_target_contract_config(
        something(config.target_contract),
        config.authoritative_hamiltonian,
        config.wavefunction_gauge_hdf5,
    )
    paths = _uiu_partial_paths(config)
    target = config.target_contract
    _validate_generation_output_paths(
        (
            output = paths.output,
            provenance = paths.provenance,
            scratch = paths.scratch,
            partial = paths.partial,
            checkpoint = paths.checkpoint,
        ),
        (
            config.topology_file,
            effective_oracle_mmn_file,
            authoritative_mmn_file,
            config.wavefunction_gauge_hdf5,
            target === nothing ? nothing : something(target).operator_oracle_mmn_file,
            target === nothing ? nothing : something(target).solver_mmn_file,
        ),
        config.source,
    )
    recover_publication =
        config.resume &&
        isfile(paths.output) &&
        isfile(paths.checkpoint) &&
        !ispath(paths.provenance) &&
        !ispath(paths.partial)
    ispath(paths.output) &&
        !config.overwrite &&
        !recover_publication &&
        throw(ArgumentError("refusing to overwrite uIu output: $(paths.output)"))
    ispath(paths.provenance) &&
        !config.overwrite &&
        throw(ArgumentError("refusing to overwrite uIu provenance: $(paths.provenance)"))
    _materialize_uiu_output_directories(paths)
    state = _uiu_source_state(
        config.source,
        config.topology_file,
        config.max_cached_wavefunction_kpoints,
    )
    state = _uiu_state_with_qualification_scope(state, config.target_contract)
    gauge_contract = _generation_band_gauge_contract(
        config.source,
        config.authoritative_hamiltonian,
        config.wavefunction_gauge_hdf5,
        state.topology.num_bands,
        state.topology.num_kpts,
        construction_policy = config.construction_policy,
    )
    config.target_contract === nothing || _validate_operator_target_contract_frame(
        something(config.target_contract),
        gauge_contract,
        authoritative_hamiltonian_key(config.authoritative_hamiltonian),
        state.topology.num_bands,
        state.topology.num_kpts,
        state.topology.num_neighbors,
    )
    state.input_sha256["BAND_FRAME_TRANSFORM"] = gauge_contract.transform_sha256
    state.input_sha256["BAND_FRAME_CONTRACT"] = gauge_contract.contract_sha256
    gauge_contract.gauge_artifact_sha256 === nothing || (
        state.input_sha256["WAVEFUNCTION_GAUGE_HDF5"] =
            something(gauge_contract.gauge_artifact_sha256)
    )
    @info "uIu native source loaded" source = state.native.source_code bands =
        state.topology.num_bands kpoints = state.topology.num_kpts neighbors =
        state.topology.num_neighbors
    oracle_available = effective_oracle_mmn_file !== nothing
    if oracle_available
        state.input_sha256["ORACLE_MMN"] = sha256_file(something(effective_oracle_mmn_file))
    end
    authoritative_mmn_sha256 === nothing ||
        (state.input_sha256["AUTHORITATIVE_MMN"] = authoritative_mmn_sha256)
    config.target_contract === nothing ||
        (state.input_sha256["OPERATOR_TARGET_CONTRACT"] = config.target_contract.contract_sha256)
    fingerprint =
        _uiu_input_fingerprint(state.input_sha256, state.topology, config.construction_policy)
    execution_contract = _uiu_execution_contract(state)
    mmn_parity =
        oracle_available ? _uiu_mmn_parity(state, something(effective_oracle_mmn_file)) : nothing
    @info "uIu preflight evaluated" generalized_norm = state.generalized_norm radial_q =
        state.radial_q_maximum mmn_max = (mmn_parity === nothing ? NaN : mmn_parity.max_absolute) mmn_rms =
        (mmn_parity === nothing ? NaN : mmn_parity.root_mean_square) mmn_relative_l2 =
        (mmn_parity === nothing ? NaN : mmn_parity.relative_l2)
    if config.construction_policy == :standard
        all(isfinite, (state.generalized_norm, state.radial_q_maximum)) ||
            throw(ArgumentError("FATAL_INTEGRITY: nonfinite uIu native metric residual"))
        if mmn_parity !== nothing
            mmn_parity.finite && all(
                isfinite,
                (mmn_parity.max_absolute, mmn_parity.root_mean_square, mmn_parity.relative_l2),
            ) || throw(ArgumentError("FATAL_INTEGRITY: nonfinite uIu MMN parity residual"))
        end
    end
    preflight_pass =
        state.generalized_norm <= config.thresholds.generalized_norm_max_absolute &&
        state.radial_q_maximum <= config.thresholds.radial_q_max_absolute &&
        (!config.require_mmn_oracle || _uiu_mmn_passes(something(mmn_parity), config.thresholds))
    if !preflight_pass &&
       (config.target_contract !== nothing || config.construction_policy != :standard)
        diagnostics =
            vcat(state.diagnostics, _uiu_cache_diagnostics(state), ["UIU_PREFLIGHT_GATE_FAILED"])
        return _uiu_failed_result(
            config,
            state,
            gauge_contract,
            paths,
            fingerprint,
            mmn_parity,
            diagnostics,
        )
    end

    if recover_publication
        _uiu_recover_publication!(paths, state.topology, fingerprint, execution_contract)
    end

    if !config.resume && (isfile(paths.partial) || isfile(paths.checkpoint))
        config.overwrite || throw(ArgumentError("UIU_PARTIAL_EXISTS_AND_RESUME_DISABLED"))
        isfile(paths.partial) && rm(paths.partial; force = true)
        isfile(paths.checkpoint) && rm(paths.checkpoint; force = true)
    end
    if !isfile(paths.partial)
        open(paths.partial, "w") do io
            _uiu_header!(io, state.topology)
            flush(io)
        end
    end
    completed, checksums, diagonal, hermiticity = _uiu_scan_partial(paths.partial, state.topology)
    _uiu_validate_checkpoint(
        paths.checkpoint,
        fingerprint,
        completed,
        checksums,
        execution_contract,
    )
    resumed_from = completed
    open(paths.partial, "a") do io
        for center in (completed + 1):state.topology.num_kpts
            blocks = _uiu_compute_center_blocks(state, center, gauge_contract)
            local_diagonal, local_hermiticity = _uiu_block_diagnostics(blocks, state.topology)
            diagonal = max(diagonal, local_diagonal)
            hermiticity = max(hermiticity, local_hermiticity)
            push!(checksums, _uiu_write_center!(io, blocks, state.topology))
            flush(io)
            _uiu_atomic_json(
                paths.checkpoint,
                _uiu_checkpoint_payload(
                    fingerprint,
                    state.topology,
                    center,
                    checksums,
                    execution_contract,
                ),
            )
            @info "uIu generation progress" center state.topology.num_kpts diagonal hermiticity
        end
    end
    completed_after, verified_checksums, verified_diagonal, verified_hermiticity =
        _uiu_scan_partial(paths.partial, state.topology)
    completed_after == state.topology.num_kpts ||
        throw(ArgumentError("UIU_WRITE_INCOMPLETE_AFTER_FINALIZATION"))
    verified_checksums == checksums || throw(ArgumentError("UIU_WRITE_CHECKSUM_READBACK_FAILED"))
    diagonal = max(diagonal, verified_diagonal)
    hermiticity = max(hermiticity, verified_hermiticity)
    # The diagonal uIu block is the same q=0 PAW metric qualified above.
    # Its outer-window residual is the hard gate; the complete-parent maximum
    # remains a required audit, but must not disqualify excluded high bands.
    output_pass =
        state.generalized_norm <= config.thresholds.diagonal_identity_max_absolute &&
        hermiticity <= config.thresholds.exchange_hermiticity_max_absolute
    if !output_pass && config.construction_policy != :standard
        diagnostics =
            vcat(state.diagnostics, _uiu_cache_diagnostics(state), ["UIU_OUTPUT_GATE_FAILED"])
        return _uiu_failed_result(
            config,
            state,
            gauge_contract,
            paths,
            fingerprint,
            mmn_parity,
            diagnostics,
        )
    end
    mv(paths.partial, paths.output; force = config.overwrite)
    count = Ref(0)
    foreach_wannier_uiu_block(
        paths.output;
        expected_num_bands = state.topology.num_bands,
        expected_num_kpts = state.topology.num_kpts,
        expected_num_neighbors = state.topology.num_neighbors,
    ) do _, _, _, _, _
        count[] += 1
    end
    count[] == state.topology.num_kpts * state.topology.num_neighbors^2 ||
        throw(ArgumentError("UIU_FINAL_READBACK_RECORD_COUNT_MISMATCH"))
    peak_memory = try
        Int(Sys.maxrss())
    catch
        0
    end
    quality_pass = preflight_pass && output_pass
    diagnostics = vcat(
        state.diagnostics,
        _uiu_cache_diagnostics(state),
        [quality_pass ? "UIU_GENERATION_PASS" : "UIU_GENERATION_NUMERICAL_WARNING"],
    )
    preflight_pass || push!(diagnostics, "NUMERICAL_WARNING:UIU_PREFLIGHT_GATE_FAILED")
    diagonal > config.thresholds.diagonal_identity_max_absolute &&
        push!(diagnostics, "PARENT_AUDIT_EXCEEDED:UIU_DIAGONAL_IDENTITY")
    if !output_pass
        # Retain the schema-1.0 warning token for readers while declaring the
        # target-scoped meaning explicitly in schema-1.1 provenance.
        push!(diagnostics, "NUMERICAL_WARNING:UIU_OUTPUT_GATE_FAILED")
        push!(diagnostics, "UIU_TARGET_OUTPUT_GATE_FAILED")
    end
    payload = _uiu_provenance_payload(
        config,
        state,
        gauge_contract,
        paths,
        fingerprint,
        mmn_parity,
        diagonal,
        hermiticity,
        quality_pass,
        resumed_from,
        checksums,
        peak_memory,
        diagnostics,
    )
    _uiu_atomic_json(paths.provenance, payload)
    isfile(paths.checkpoint) && rm(paths.checkpoint; force = true)
    artifacts = Dict(
        "uiu" => paths.output,
        "provenance_json" => paths.provenance,
        "uiu_sha256" => sha256_file(paths.output),
        "provenance_sha256" => sha256_file(paths.provenance),
    )
    return WannierUIUGenerationResult(
        state.native.source_code,
        state.topology.num_bands,
        state.topology.num_kpts,
        state.topology.num_neighbors,
        state.generalized_norm,
        mmn_parity,
        diagonal,
        hermiticity,
        quality_pass,
        resumed_from,
        peak_memory,
        artifacts,
        state.input_sha256,
        diagnostics,
    )
end
