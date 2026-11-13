using LinearAlgebra: det

# Current mathematical model format. Legacy evidence parsing is migration-only.
const CURRENT_MODEL_FORMAT_VERSION = "3.0"
const MODEL_DEFINITION_KEYS = (
    "authoritative_hamiltonian",
    "authoritative_hamiltonian_policy_definition",
    "authoritative_hamiltonian_algorithm_version",
    "source_band_gauge",
    "target_band_gauge",
    "generation_source_band_gauge",
    "generation_target_band_gauge",
    "delivery_target_band_gauge",
    "pair_wigner_seitz_transform_algorithm",
    "pair_wigner_seitz_storage_policy",
    "derivative_overlap_source",
    "derivative_overlap_completeness",
    "derivative_overlap_algorithm_version",
    "derivative_frame",
    "operator_moment_frame_conversion",
    "source",
    "completeness",
    "algorithm_version",
    "input_semantics",
    "band_frame_transform_definition",
    "band_frame_contract_definition",
    "outer_mask",
    "frozen_mask",
    "source_metric",
    "band_frame_transforms",
)

# Missing legacy definitions remain missing; an explicit incompatible frame is not usable.
function _validate_model_derivative_frames(definitions)
    for (key, value) in definitions
        last(split(key, '.')) == "derivative_frame" || continue
        value isa AbstractString && value == "uncentered_periodic_wannier" ||
            throw(ArgumentError("UNSUPPORTED_MODEL_DERIVATIVE_FRAME: $(key)"))
    end
    return definitions
end

# Retain definitions actually consumed by algorithms, without qualification records.
function _model_definitions(provenance)
    definitions=Dict{String, Any}()
    for key in MODEL_DEFINITION_KEYS
        value=get(provenance, key, nothing)
        value===nothing || (definitions[key]=value)
    end
    qualification=get(provenance, "operator_qualification", Dict{String, Any}())
    records=get(qualification, "operators", Dict{String, Any}())
    for (name, record) in records
        for key in MODEL_DEFINITION_KEYS
            value=get(record, key, nothing)
            value===nothing || (definitions["$name.$key"]=value)
        end
    end
    imported=get(provenance, "imported_mathematical_definitions", nothing)
    if imported!==nothing
        for (key, value) in imported
            leaf=last(split(key, '.'))
            leaf in (
                MODEL_DEFINITION_KEYS...,
                "symmetry_scope",
                "target_anchor",
                "target_complement_completion",
                "target_leakage_semantics",
                "target_leakage_formula_definition",
                "target_leakage_threshold",
                "band_frame_transform_definition",
                "band_frame_contract_definition",
                "outer_mask",
                "frozen_mask",
                "source_metric",
                "band_frame_transforms",
            ) || throw(ArgumentError("unsupported imported mathematical definition: $key"))
            definitions[key]=value
        end
    end
    return _validate_model_derivative_frames(definitions)
end

# Derive a display profile from the actual mathematical inventory, not requested task identity.
function _model_inventory_profile(inventory)
    for profile in (:hamiltonian_position, :hamiltonian_position_spin, :derivative, :full)
        inventory==collect(OPERATOR_PROFILE_INVENTORIES[profile]) && return profile
    end
    return :custom
end

"""Write current physical operators and definitions atomically, without hashes or qualification groups."""
function write_real_space_operator_bundle(
    filename::AbstractString,
    lattice,
    degeneracies,
    operators::AbstractDict;
    profile::Union{Nothing, Symbol},
    operator_tasks = (),
    overwrite::Bool = false,
    paired_tb_file = nothing,
    paired_tb_expected_state = nothing,
    paired_tb_writer = nothing,
    return_receipt::Bool = false,
    content_authentication::Bool = false,
    provenance = Dict{String, Any}(),
    symmetry = Dict{String, Any}(),
    geometry,
    diagnostics = Dict{String, Any}(),
    eligibility = Dict{String, Any}(),
)
    content_authentication &&
        throw(ArgumentError("current model format does not support content certificates"))
    path=abspath(filename)
    ispath(path) && !overwrite && throw(ArgumentError("refusing to overwrite model: $path"))
    paired_tb_file===nothing ||
        isfile(paired_tb_file) ||
        throw(ArgumentError("paired text source does not exist"))
    paired_tb_file===nothing ||
        !(ispath(path) && realpath(path)==realpath(paired_tb_file)) ||
        throw(ArgumentError("model destination cannot replace its declared text source"))
    paired_tb_expected_state===nothing || validate_scientific_source_state(paired_tb_expected_state)
    lat=Matrix{Float64}(lattice)
    size(lat)==(3, 3) && all(isfinite, lat) && abs(det(lat))>eps(Float64) ||
        throw(ArgumentError("model lattice must be finite and nonsingular"))
    inventory=canonical_operator_inventory(collect(keys(operators)))
    all(k->k in inventory, (REAL_SPACE_HAMILTONIAN, REAL_SPACE_POSITION)) ||
        throw(ArgumentError("model requires Hamiltonian and position operators"))
    r_vectors=_operator_bundle_r_vectors(operators)
    size(r_vectors, 1)==3 && size(r_vectors, 2)>0 || throw(ArgumentError("invalid R support"))
    length(Set(Tuple(r_vectors[:, i]) for i in axes(r_vectors, 2)))==size(r_vectors, 2) ||
        throw(ArgumentError("duplicate R vectors"))
    weights=collect(Int, degeneracies)
    length(weights)==size(r_vectors, 2) && all(>(0), weights) ||
        throw(ArgumentError("invalid degeneracies"))
    n=size(operators[REAL_SPACE_HAMILTONIAN].data, 1)
    centers=_bundle_wannier_centers(operators, r_vectors, weights; standard = true)
    center_policy=Symbol(_geometry_entry(geometry, "wannier_center_policy"))
    center_policy in (:symmetrize, :validate, :keep_input) ||
        throw(ArgumentError("invalid Wannier center policy"))
    replica=Symbol(_geometry_entry(geometry, "real_space_replica_policy"))
    materialized=Bool(_geometry_entry(geometry, "minimum_distance_materialized"))
    materialized==(replica==:minimum_distance) ||
        throw(ArgumentError("replica materialization policy mismatch"))
    materialized &&
        !all(==(1), weights) &&
        throw(ArgumentError("materialized replicas require unit degeneracies"))
    grid=collect(Int, _geometry_entry(geometry, "mp_grid"))
    length(grid)==3 && all(>(0), grid) || throw(ArgumentError("invalid generation grid"))
    entries=OperatorBundleIndexEntry[];
    payload=ComplexF64[]
    for kind in inventory
        operator=operators[kind]
        operator.spec.kind==kind || throw(ArgumentError("operator kind mismatch"))
        size(
            operator.data,
        )==(n, n, ntuple(_->3, operator.spec.cartesian_rank)..., size(r_vectors, 2)) || throw(
            ArgumentError("operator dimensions disagree for $(real_space_operator_name(kind))"),
        )
        for component in _component_tuples(operator.spec.cartesian_rank)
            values=_component_values(operator, component)
            all(isfinite, values) || throw(ArgumentError("operator contains nonfinite values"))
            push!(
                entries,
                OperatorBundleIndexEntry(
                    kind,
                    UInt8(operator.spec.cartesian_rank),
                    component,
                    UInt64(length(payload)),
                    UInt64(length(values)),
                    (n, n, size(r_vectors, 2)),
                    operator_component_reference(kind, component),
                ),
            )
            append!(payload, values)
        end
    end
    definitions=_model_definitions(provenance)
    # A check's physical scope/formula are semantics, independent of its permission label.
    for (stored, legacy) in (
        ("symmetry_scope", "qualification_scope"),
        ("target_anchor", "target_anchor"),
        ("target_complement_completion", "target_complement_completion"),
        ("target_leakage_semantics", "target_leakage_semantics"),
        ("target_leakage_formula_definition", "target_leakage_formula_definition"),
        ("target_leakage_threshold", "target_leakage_threshold"),
    )
        value=get(eligibility, legacy, nothing)
        value===nothing && continue
        value isa String &&
            value in ("NOT_APPLICABLE", "NOT_RECORDED", "LEGACY_NOT_RECORDED", "") &&
            continue
        definitions[stored]=value
    end
    mkpath(dirname(path));
    temporary, stream=mktemp(dirname(path));
    close(stream)
    try
        HDF5.enable_complex_support()
        h5open(temporary, "w") do h
            a=attributes(h)
            for (key, value) in (
                ("schema", OPERATOR_BUNDLE_SCHEMA),
                ("schema_version", CURRENT_MODEL_FORMAT_VERSION),
                ("basis_metric", "orthonormal"),
                ("logical_convention", LOGICAL_CONVENTION),
                ("bloch_phase_convention", BLOCH_PHASE_CONVENTION),
                ("fourier_convention", FOURIER_CONVENTION),
                ("wannier_center_convention", "Convention_II"),
                ("energy_unit", "eV"),
                ("length_unit", "Angstrom"),
            )
                a[key]=value
            end
            m=create_group(h, "model");
            m["num_orbitals"]=Int64(n);
            m["lattice"]=lat
            m["r_vectors"]=Int64.(r_vectors);
            m["degeneracies"]=Int64.(weights)
            m["wannier_centers_cartesian"]=centers
            g=create_group(h, "geometry");
            ga=attributes(g)
            ga["real_space_replica_policy"]=String(replica);
            ga["minimum_distance_materialized"]=materialized
            ga["wannier_center_policy"]=String(_geometry_entry(geometry, "wannier_center_policy"))
            ga["wigner_seitz_tolerance"]=Float64(
                _geometry_entry(geometry, "wigner_seitz_tolerance"),
            )
            ga["wigner_seitz_search_size"]=Int(
                _geometry_entry(geometry, "wigner_seitz_search_size"),
            )
            ga["replica_mapping_reference"]=String(
                _geometry_entry(geometry, "replica_mapping_reference"),
            )
            g["mp_grid"]=grid
            p=create_group(h, "payload");
            p["complex128"]=payload
            index=create_group(h, "index")
            index["operator_kind_id"]=UInt8[UInt8(e.kind) for e in entries]
            index["component_rank"]=UInt8[e.component_rank for e in entries]
            index["component_indices"]=reduce(hcat, Int8[e.component_indices...] for e in entries)
            index["offset_elements"]=UInt64[e.offset_elements for e in entries]
            index["length_elements"]=UInt64[e.length_elements for e in entries]
            index["logical_shape"]=reduce(hcat, UInt64[e.logical_shape...] for e in entries)
            groups=create_group(h, "operators")
            for kind in inventory
                spec=operators[kind].spec;
                g=create_group(groups, real_space_operator_name(kind));
                a=attributes(g)
                a["cartesian_rank"]=spec.cartesian_rank;
                a["inversion_parity"]=spec.inversion_parity
                a["time_reversal_parity"]=spec.time_reversal_parity;
                a["rotate_cartesian"]=spec.rotate_cartesian
                a["units"]=_unit_contract(kind)
            end
            d=create_group(h, "definitions")
            for (key, value) in definitions
                value isa Union{AbstractString, Real, Bool, AbstractDict, AbstractArray, Tuple} ||
                    throw(ArgumentError("unsupported mathematical definition: $key"))
                if value isa Union{AbstractDict, AbstractArray, Tuple}
                    attributes(d)[key * "__json"]=JSON3.write(value)
                else
                    attributes(d)[key]=value
                end
            end
            flush(h)
        end
        # A separately requested text output still uses its original writer.
        paired_tb_writer===nothing || paired_tb_writer(nothing)
        WannierNLQG.IO.atomic_file_replace(temporary, path)
    finally
        isfile(temporary) && rm(temporary)
    end
    return return_receipt ?
           (;
        path,
        publication_identity = "",
        numerical_quality = String(get(eligibility, "numerical_quality", "")),
    ) : path
end

# The legacy manifest carrier stays internal; absent evidence is never constructed as PASS.
function _current_manifest_value(T)
    Nothing in Base.uniontypes(T) && return nothing
    T===String && return "NOT_RECORDED"
    T===Bool && return false
    T===Vector{String} && return String[]
    T===Dict{String, Any} && return Dict{String, Any}()
    throw(ArgumentError("missing required current model field of type $T"))
end

# Validate mathematical metadata and index extents without reading the numerical payload.
function _manifest_from_handle(path::String, h; legacy_migration::Bool = false)
    String(_required_attribute(h, "schema"))==OPERATOR_BUNDLE_SCHEMA ||
        throw(ArgumentError("unsupported model schema"))
    version=String(_required_attribute(h, "schema_version"))
    if legacy_migration
        version in ("1.1", "1.2", "1.3") ||
            throw(ArgumentError("unsupported legacy mathematical layout: $version"))
    else
        version==CURRENT_MODEL_FORMAT_VERSION || throw(
            ArgumentError("unsupported mathematical model format; current format 3.0 is required"),
        )
    end
    for (key, value) in (
        ("basis_metric", "orthonormal"),
        ("logical_convention", LOGICAL_CONVENTION),
        ("bloch_phase_convention", BLOCH_PHASE_CONVENTION),
        ("fourier_convention", FOURIER_CONVENTION),
        ("wannier_center_convention", "Convention_II"),
        ("energy_unit", "eV"),
        ("length_unit", "Angstrom"),
    )
        stored_key=legacy_migration &&
                   key=="wannier_center_convention" &&
                   !haskey(attributes(h), key) ? "storage_wannier_center_convention" : key
        # Packed1.x stores units per operator; that protocol defines an
        # orthonormal Wannier basis and Angstrom lattice. The unit contracts
        # of every actual operator are still validated below.
        legacy_migration &&
            !haskey(attributes(h), stored_key) &&
            key in ("basis_metric", "energy_unit", "length_unit") &&
            continue
        String(_required_attribute(h, stored_key))==value ||
            throw(ArgumentError("unsupported mathematical definition: $key"))
    end
    n=Int(read(h["model/num_orbitals"]));
    n>0 || throw(ArgumentError("invalid orbital count"))
    lattice=Matrix{Float64}(read(h["model/lattice"]))
    size(lattice)==(3, 3) && all(isfinite, lattice) && abs(det(lattice))>eps(Float64) ||
        throw(ArgumentError("invalid lattice"))
    r=Matrix{Int}(read(h["model/r_vectors"]));
    weights=Vector{Int}(read(h["model/degeneracies"]))
    size(r, 1)==3 && size(r, 2)>0 && length(weights)==size(r, 2) && all(>(0), weights) ||
        throw(ArgumentError("invalid support or degeneracies"))
    length(Set(Tuple(r[:, i]) for i in axes(r, 2)))==size(r, 2) ||
        throw(ArgumentError("duplicate R vectors"))
    centers=Matrix{Float64}(read(h["model/wannier_centers_cartesian"]))
    size(centers)==(n, 3) && all(isfinite, centers) || throw(ArgumentError("invalid centers"))
    fractional=reduce(
        vcat,
        permutedims(real_space_cartesian_to_fractional(@view(centers[i, :]), lattice)) for i in 1:n
    )
    ids=Vector{UInt8}(read(h["index/operator_kind_id"]));
    ranks=Vector{UInt8}(read(h["index/component_rank"]))
    components=Matrix{Int8}(read(h["index/component_indices"]));
    offsets=Vector{UInt64}(read(h["index/offset_elements"]))
    lengths=Vector{UInt64}(read(h["index/length_elements"]));
    shapes=Matrix{UInt64}(read(h["index/logical_shape"]))
    count=length(ids)
    count>0 &&
    length(ranks)==length(offsets)==length(lengths)==count &&
    size(components)==(2, count) &&
    size(shapes)==(3, count) || throw(ArgumentError("malformed component index"))
    payload_length=length(h["payload/complex128"]);
    cursor=UInt64(0);
    entries=OperatorBundleIndexEntry[]
    for i in eachindex(ids)
        kind=RealSpaceOperatorKind(ids[i]);
        kind in REAL_SPACE_OPERATOR_REGISTRY || throw(ArgumentError("unknown operator kind"))
        offsets[i]==cursor &&
        lengths[i]==UInt64(n)*UInt64(n)*UInt64(size(r, 2)) &&
        Tuple(Int.(shapes[:, i]))==(n, n, size(r, 2)) ||
            throw(ArgumentError("invalid component shape or extent"))
        lengths[i]<=UInt64(payload_length)-cursor ||
            throw(ArgumentError("component exceeds payload"))
        push!(
            entries,
            OperatorBundleIndexEntry(
                kind,
                ranks[i],
                Tuple(components[:, i]),
                offsets[i],
                lengths[i],
                (n, n, size(r, 2)),
                operator_component_reference(kind, Tuple(components[:, i])),
            ),
        )
        cursor+=lengths[i]
    end
    cursor==UInt64(payload_length) || throw(ArgumentError("unindexed payload elements"))
    inventory=canonical_operator_inventory(unique(getfield.(entries, :kind)))
    all(k->k in inventory, (REAL_SPACE_HAMILTONIAN, REAL_SPACE_POSITION)) ||
        throw(ArgumentError("model lacks H or position"))
    for kind in inventory
        group=h["operators/" * real_space_operator_name(kind)]
        unit_key=legacy_migration && !haskey(attributes(group), "units") ? "unit_contract" : "units"
        String(_required_attribute(group, unit_key))==_unit_contract(kind) ||
            throw(ArgumentError("operator unit definition mismatch"))
        if legacy_migration
            UInt8(_required_attribute(group, "operator_kind_id"))==UInt8(kind) &&
            String(_required_attribute(group, "canonical_name"))==real_space_operator_name(kind) ||
                throw(ArgumentError("legacy operator kind/name mismatch"))
        end
        spec=_operator_spec_from_handle(h, kind);
        selected=[e for e in entries if e.kind==kind]
        getfield.(selected, :component_indices)==_component_tuples(spec.cartesian_rank) &&
        all(e->Int(e.component_rank)==spec.cartesian_rank, selected) ||
            throw(ArgumentError("missing or inconsistent Cartesian components"))
    end
    geometry=h["geometry"]
    Symbol(_required_attribute(geometry, "wannier_center_policy")) in
    (:symmetrize, :validate, :keep_input) || throw(ArgumentError("invalid Wannier center policy"))
    replica=Symbol(_required_attribute(geometry, "real_space_replica_policy"))
    materialized=Bool(_required_attribute(geometry, "minimum_distance_materialized"))
    replica in (:input, :minimum_distance) && materialized==(replica==:minimum_distance) ||
        throw(ArgumentError("invalid replica semantics"))
    materialized &&
        !all(==(1), weights) &&
        throw(ArgumentError("materialized replicas require unit degeneracies"))
    grid=Int.(read(geometry["mp_grid"]));
    length(grid)==3 && all(>(0), grid) || throw(ArgumentError("invalid grid"))
    tolerance=Float64(_required_attribute(geometry, "wigner_seitz_tolerance"));
    search=Int(_required_attribute(geometry, "wigner_seitz_search_size"))
    isfinite(tolerance) && tolerance>0 && search>0 ||
        throw(ArgumentError("invalid replica controls"))
    if legacy_migration
        for key in ("final_wannier_centers_cartesian",)
            haskey(geometry, key) &&
                !isequal(Matrix{Float64}(read(geometry[key])), centers) &&
                throw(ArgumentError("legacy geometry/model centers disagree"))
        end
        if haskey(h, "model/wannier_centers_fractional")
            stored_fractional=Matrix{Float64}(read(h["model/wannier_centers_fractional"]))
            size(stored_fractional)==size(fractional) &&
            all(isfinite, stored_fractional) &&
            maximum(abs, stored_fractional .- fractional; init = 0.0)<=1e-12 ||
                throw(ArgumentError("legacy fractional center definition disagrees with lattice"))
        end
    end
    definitions = if legacy_migration
        _legacy_model_mathematical_definitions(h)
    else
        definitions=Dict{String, Any}(
            key=>WannierNLQG.IO.read_hdf5_attribute_value(attributes(h["definitions"])[key]) for
            key in keys(attributes(h["definitions"]))
        )
        for key in collect(keys(definitions))
            endswith(key, "__json") || continue
            definitions[key[1:(end - 6)]]=JSON3.read(pop!(definitions, key))
        end
        definitions
    end
    _validate_model_derivative_frames(definitions)
    records=Dict{String, Any}()
    for (key, value) in definitions
        occursin('.', key) || continue
        name, leaf=split(key, '.'; limit = 2);
        get!(()->Dict{String, Any}(), records, name)[leaf]=value
    end
    mathematical=Dict{String, Any}("mathematical_definitions"=>definitions, "operators"=>records)
    v=Dict{Symbol, Any}(
        :path=>path,
        :profile=>_model_inventory_profile(inventory),
        :inventory=>inventory,
        :num_orbitals=>n,
        :lattice=>lattice,
        :r_vectors=>r,
        :degeneracies=>weights,
        :entries=>entries,
        :payload_length=>payload_length,
        :publication_identity=>path,
        :schema_version=>version,
        :wannier_centers_cartesian=>centers,
        :wannier_centers_fractional=>fractional,
        :wannier_center_policy=>Symbol(_required_attribute(geometry, "wannier_center_policy")),
        :real_space_replica_policy=>replica,
        :minimum_distance_materialized=>materialized,
        :mp_grid=>Tuple(grid),
        :wigner_seitz_tolerance=>tolerance,
        :wigner_seitz_search_size=>search,
        :replica_mapping_reference=>haskey(attributes(geometry), "replica_mapping_reference") ?
                                    String(
            _required_attribute(geometry, "replica_mapping_reference"),
        ) :
                                    legacy_migration ?
                                    WannierNLQG.Core.scientific_data_generation(
            WannierNLQG.Core.ScientificDataOwner(),
        ) : throw(ArgumentError("missing replica mapping reference")),
        :operator_qualification=>mathematical,
        :operator_selection_mode=>"inventory",
        :derivative_overlap_source=>String(
            get(definitions, "derivative_overlap_source", "NOT_RECORDED"),
        ),
        :derivative_overlap_completeness=>String(
            get(definitions, "derivative_overlap_completeness", "NOT_RECORDED"),
        ),
        :derivative_overlap_algorithm_version=>String(
            get(definitions, "derivative_overlap_algorithm_version", "NOT_RECORDED"),
        ),
        :authoritative_hamiltonian=>String(
            get(definitions, "authoritative_hamiltonian", "NOT_RECORDED"),
        ),
        :authoritative_hamiltonian_sha256=>String(
            get(definitions, "authoritative_hamiltonian_definition", "NOT_RECORDED"),
        ),
    )
    for (field, key) in (
        (:qualification_scope, "symmetry_scope"),
        (:target_anchor, "target_anchor"),
        (:target_complement_completion, "target_complement_completion"),
        (:target_leakage_semantics, "target_leakage_semantics"),
        (:target_leakage_formula_sha256, "target_leakage_formula_definition"),
    )
        haskey(definitions, key) && (v[field]=String(definitions[key]))
    end
    threshold=get(definitions, "target_leakage_threshold", nothing)
    v[:target_leakage_threshold]=threshold isa Real ? Float64(threshold) :
                                 threshold isa String ? tryparse(Float64, threshold) : nothing
    return OperatorBundleManifest(
        (
            (
                haskey(v, name) ? v[name] :
                _current_manifest_value(fieldtype(OperatorBundleManifest, name))
            ) for name in fieldnames(OperatorBundleManifest)
        )...,
    )
end

# Legacy authentication and task/qualification labels never authorize mathematical
# import. This whitelist retains definitions consumed by the current model and
# actual frame/scope arrays when present; it never interprets a digest as values.
function _legacy_model_mathematical_definitions(h)
    provenance=haskey(h, "provenance") ? _read_metadata_tree(h["provenance"]) : Dict{String, Any}()
    definitions=_model_definitions(provenance)
    for (current, old) in (
        ("symmetry_scope", "qualification_scope"),
        ("target_anchor", "target_anchor"),
        ("target_complement_completion", "target_complement_completion"),
        ("target_leakage_semantics", "target_leakage_semantics"),
        ("target_leakage_formula_definition", "target_leakage_formula_definition"),
        ("target_leakage_threshold", "target_leakage_threshold"),
    )
        haskey(attributes(h), old) || continue
        value=_required_attribute(h, old)
        value isa String &&
            value in ("", "NOT_RECORDED", "NOT_APPLICABLE", "LEGACY_NOT_RECORDED") &&
            continue
        definitions[current]=value
    end
    return definitions
end
