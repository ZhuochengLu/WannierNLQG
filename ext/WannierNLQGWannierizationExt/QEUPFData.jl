"""One parsed UPF dataset used only inside the native QE augmentation backend."""
struct QEUPFData
    filename::String
    element::String
    metric_kind::Symbol
    has_so::Bool
    fully_relativistic::Bool
    radial_grid_bohr::Vector{Float64}
    radial_weights_bohr::Vector{Float64}
    beta_radial::Matrix{Float64}
    beta_angular_momenta::Vector{Int}
    beta_integration_cutoff_index::Int
    beta_total_angular_momenta::Vector{Float64}
    dij::Matrix{Float64}
    q_integrals::Matrix{Float64}
    q_with_l::Bool
    q_radial_by_multipole::Dict{NTuple{3, Int}, Vector{Float64}}
    qfcoef::Array{Float64, 4}
    rinner_bohr::Vector{Float64}
    nqlc::Int
    augmentation_cutoff_index::Int
    augmentation_cutoff_radius_bohr::Float64
end

"""Expanded scalar projector channel in QE's real-harmonic row convention."""
struct QEProjectorChannel
    radial_index::Int
    angular_momentum::Int
    harmonic_row::Int
end

"""One atom and its contiguous native QE beta-projector channel range."""
struct QEProjectorAtomPlan
    atomic_type_label::String
    element::String
    position_fractional::NTuple{3, Float64}
    channels::Vector{QEProjectorChannel}
    channel_range::UnitRange{Int}
end

"""Deterministic atom/projector expansion derived from XML and UPF metadata."""
struct QEProjectorPlan
    atoms::Vector{QEProjectorAtomPlan}
    num_channels::Int
    has_augmentation::Bool
    fully_relativistic::Bool
end

# Parse a UPF boolean attribute in all spellings accepted by QE input files.
_qe_upf_truth(value::AbstractString) =
    lowercase(strip(value)) in ("t", "true", ".true.", "1", "yes")

# Read one XML attribute with an explicit missing-field diagnostic.
function _qe_upf_attribute(node, name::AbstractString; required::Bool = true, default = "")
    value = try
        String(node[String(name)])
    catch
        ""
    end
    if required && isempty(strip(value))
        throw(ArgumentError("QE_UPF_DATA_REQUIRED: UPF node $(EzXML.nodename(node)) omits $(name)"))
    end
    return isempty(strip(value)) ? String(default) : strip(value)
end

# Parse one whitespace-delimited UPF numeric payload with Fortran exponents.
function _qe_upf_numbers(node)
    tokens = split(strip(EzXML.nodecontent(node)))
    values = parse.(Float64, replace.(tokens, 'D' => 'E', 'd' => 'e'))
    all(isfinite, values) ||
        throw(ArgumentError("QE_UPF_DATA_REQUIRED: UPF numeric payload contains NaN or Inf"))
    return values
end

# Return exactly one XML node selected independently of namespace prefixes.
function _qe_upf_required(root, xpath::AbstractString, label::AbstractString)
    nodes = EzXML.findall(xpath, root)
    length(nodes) == 1 || throw(
        ArgumentError("QE_UPF_DATA_REQUIRED: expected one $(label) node, found $(length(nodes))"),
    )
    return only(nodes)
end

# Parse an integer-like XML attribute that is occasionally formatted as a real.
function _qe_upf_integer_attribute(
    node,
    name::AbstractString;
    default::Union{Nothing, Int} = nothing,
)
    text = _qe_upf_attribute(
        node,
        name;
        required = default === nothing,
        default = default === nothing ? "" : string(something(default)),
    )
    value = parse(Float64, replace(text, 'D' => 'E', 'd' => 'e'))
    isfinite(value) && abs(value - round(value)) <= 1.0e-8 ||
        throw(ArgumentError("QE_UPF_DATA_REQUIRED: $(name) is not integer-valued"))
    return round(Int, value)
end

# QE stops after the first complete UPF root, while strict libxml rejects a
# small class of archived PSL files with a duplicated, rootless numeric suffix.
# Accept only that narrow shape: one valid first root, no second opening root,
# and exactly one trailing closing root.  Every other XML error remains fatal.
function _qe_upf_xml_document(filename::AbstractString)
    try
        return EzXML.readxml(filename)
    catch parse_error
        message = sprint(showerror, parse_error)
        occursin("Extra content at the end of the document", message) || rethrow()
        contents = read(filename, String)
        first_close = findfirst("</UPF>", contents)
        first_close === nothing && rethrow()
        root_text = contents[firstindex(contents):last(first_close)]
        trailer_start = nextind(contents, last(first_close))
        trailer = trailer_start > lastindex(contents) ? "" : contents[trailer_start:end]
        root_openings = length(collect(eachmatch(r"<UPF\b", root_text)))
        trailer_openings = length(collect(eachmatch(r"<UPF\b", trailer)))
        trailer_closings = length(collect(eachmatch(r"</UPF>", trailer)))
        root_openings == 1 &&
        trailer_openings == 0 &&
        trailer_closings == 1 &&
        endswith(strip(trailer), "</UPF>") || rethrow()
        document = try
            EzXML.parsexml(root_text)
        catch
            rethrow(parse_error)
        end
        EzXML.nodename(EzXML.root(document)) == "UPF" || rethrow(parse_error)
        @warn "QE_UPF_TRAILING_DUPLICATE_IGNORED" filename = abspath(filename) trailing_bytes =
            ncodeunits(trailer) trailing_sha256 = bytes2hex(SHA.sha256(codeunits(trailer)))
        return document
    end
end

# Parse and index PP_BETA.N records in authoritative numeric order.
function _qe_upf_beta_nodes(root)
    indexed = Pair{Int, Any}[]
    for node in EzXML.findall(".//*", root)
        matched = match(r"^PP_BETA\.(\d+)$"i, EzXML.nodename(node))
        matched === nothing && continue
        push!(indexed, parse(Int, matched.captures[1]) => node)
    end
    sort!(indexed; by = first)
    isempty(indexed) && throw(ArgumentError("QE_UPF_DATA_REQUIRED: UPF contains no PP_BETA nodes"))
    first.(indexed) == collect(1:length(indexed)) ||
        throw(ArgumentError("QE_UPF_DATA_REQUIRED: PP_BETA indices are incomplete"))
    return last.(indexed)
end

# Parse PP_RELBETA.N total angular momenta, falling back to PP_BETA attributes.
function _qe_upf_relativistic_j(root, beta_nodes, has_so::Bool)
    count = length(beta_nodes)
    # NaN is an explicit non-relativistic sentinel and never enters SOC algebra.
    has_so || return fill(NaN, count)
    values = fill(NaN, count)
    for node in EzXML.findall(".//*", root)
        matched = match(r"^PP_RELBETA\.(\d+)$"i, EzXML.nodename(node))
        matched === nothing && continue
        index = parse(Int, matched.captures[1])
        1 <= index <= count ||
            throw(ArgumentError("QE_UPF_DATA_REQUIRED: PP_RELBETA index is out of range"))
        values[index] =
            parse(Float64, replace(_qe_upf_attribute(node, "jjj"), 'D' => 'E', 'd' => 'e'))
    end
    for index in eachindex(values)
        isfinite(values[index]) && continue
        text = _qe_upf_attribute(beta_nodes[index], "tot_ang_mom"; required = false, default = "")
        isempty(text) || (values[index] = parse(Float64, replace(text, 'D' => 'E', 'd' => 'e')))
    end
    all(isfinite, values) || throw(
        ArgumentError("QE_UPF_DATA_REQUIRED: fully relativistic UPF omits beta-channel j values"),
    )
    return values
end

# Apply the QE small-radius PP_QFCOEF polynomial to expanded PP_QIJ multipoles.
function _qe_upf_apply_qfcoef!(
    output::Dict{NTuple{3, Int}, Vector{Float64}},
    original_qij::Dict{Tuple{Int, Int}, Vector{Float64}},
    radial_grid::Vector{Float64},
    angular_momenta::Vector{Int},
    qfcoef::Array{Float64, 4},
    rinner::Vector{Float64},
)
    for ((left, right), original) in original_qij
        left_l = angular_momenta[left]
        right_l = angular_momenta[right]
        for degree in abs(left_l - right_l):2:(left_l + right_l)
            values = copy(original)
            if size(qfcoef, 1) > 0 && degree + 1 <= length(rinner) && rinner[degree + 1] > 0.0
                coefficients = @view qfcoef[:, degree + 1, left, right]
                for radial_index in eachindex(values)
                    radial_grid[radial_index] < rinner[degree + 1] || continue
                    radius = radial_grid[radial_index]
                    values[radial_index] = sum(
                        coefficients[coefficient_index] * radius^(2 * coefficient_index + degree) for
                        coefficient_index in eachindex(coefficients)
                    )
                end
            end
            output[(left, right, degree)] = values
            output[(right, left, degree)] = values
        end
    end
    return output
end

"""Parse one UPF v2 dataset without importing QE implementation control flow."""
function _read_qe_upf_data(filename::AbstractString)
    isfile(filename) ||
        throw(ArgumentError("QE_UPF_DATA_REQUIRED: UPF does not exist: $(filename)"))
    document = try
        _qe_upf_xml_document(filename)
    catch error
        throw(
            ArgumentError(
                "QE_UPF_DATA_REQUIRED: cannot parse $(filename): $(sprint(showerror, error))",
            ),
        )
    end
    root = EzXML.root(document)
    header = _qe_upf_required(root, ".//*[local-name()='PP_HEADER']", "PP_HEADER")
    element = strip(_qe_upf_attribute(header, "element"))
    metric_kind = _qe_upf_metric_kind(filename)
    has_so = _qe_upf_truth(_qe_upf_attribute(header, "has_so"; required = false, default = "false"))
    relativistic =
        lowercase(_qe_upf_attribute(header, "relativistic"; required = false, default = "scalar"))
    fully_relativistic = has_so && relativistic in ("full", "fully_relativistic")

    radial_grid = _qe_upf_numbers(_qe_upf_required(root, ".//*[local-name()='PP_R']", "PP_R"))
    radial_weights =
        _qe_upf_numbers(_qe_upf_required(root, ".//*[local-name()='PP_RAB']", "PP_RAB"))
    length(radial_grid) == length(radial_weights) && length(radial_grid) >= 3 ||
        throw(ArgumentError("QE_UPF_DATA_REQUIRED: PP_R and PP_RAB dimensions disagree"))
    all(>=(0.0), radial_grid) && issorted(radial_grid) ||
        throw(ArgumentError("QE_UPF_DATA_REQUIRED: PP_R must be sorted and nonnegative"))

    beta_nodes = _qe_upf_beta_nodes(root)
    num_beta = length(beta_nodes)
    beta_radial = Matrix{Float64}(undef, length(radial_grid), num_beta)
    angular_momenta = Vector{Int}(undef, num_beta)
    beta_cutoff_indices = Vector{Int}(undef, num_beta)
    for (index, node) in enumerate(beta_nodes)
        values = _qe_upf_numbers(node)
        length(values) == length(radial_grid) ||
            throw(ArgumentError("QE_UPF_DATA_REQUIRED: PP_BETA.$(index) has the wrong mesh"))
        beta_radial[:, index] .= values
        angular_momenta[index] = _qe_upf_integer_attribute(node, "angular_momentum")
        angular_momenta[index] >= 0 ||
            throw(ArgumentError("QE_UPF_DATA_REQUIRED: beta angular momentum is negative"))
        beta_cutoff_indices[index] =
            _qe_upf_integer_attribute(node, "cutoff_radius_index"; default = length(radial_grid))
        3 <= beta_cutoff_indices[index] <= length(radial_grid) || throw(
            ArgumentError("QE_UPF_DATA_REQUIRED: beta cutoff index is outside the radial mesh"),
        )
    end
    total_angular_momenta = _qe_upf_relativistic_j(root, beta_nodes, has_so)

    dij_node = _qe_upf_required(root, ".//*[local-name()='PP_DIJ']", "PP_DIJ")
    dij_values = _qe_upf_numbers(dij_node)
    length(dij_values) == num_beta^2 ||
        throw(ArgumentError("QE_UPF_DATA_REQUIRED: PP_DIJ dimensions disagree with PP_BETA"))
    dij = reshape(dij_values, num_beta, num_beta)

    augmentation_nodes = EzXML.findall(".//*[local-name()='PP_AUGMENTATION']", root)
    has_augmentation = metric_kind != :norm_conserving
    has_augmentation == !isempty(augmentation_nodes) || throw(
        ArgumentError(
            "QE_UPF_DATA_REQUIRED: UPF metric header and PP_AUGMENTATION presence disagree",
        ),
    )
    if !has_augmentation
        return QEUPFData(
            abspath(filename),
            element,
            metric_kind,
            has_so,
            fully_relativistic,
            radial_grid,
            radial_weights,
            beta_radial,
            angular_momenta,
            maximum(beta_cutoff_indices),
            total_angular_momenta,
            dij,
            zeros(Float64, num_beta, num_beta),
            true,
            Dict{NTuple{3, Int}, Vector{Float64}}(),
            zeros(Float64, 0, 0, 0, 0),
            Float64[],
            0,
            length(radial_grid),
            last(radial_grid),
        )
    end

    augmentation = only(augmentation_nodes)
    q_with_l = _qe_upf_truth(
        _qe_upf_attribute(augmentation, "q_with_l"; required = false, default = "false"),
    )
    nqlc =
        _qe_upf_integer_attribute(augmentation, "nqlc"; default = 2 * maximum(angular_momenta) + 1)
    nqf = _qe_upf_integer_attribute(augmentation, "nqf"; default = 0)
    cutoff_index =
        _qe_upf_integer_attribute(augmentation, "cutoff_r_index"; default = length(radial_grid))
    1 <= cutoff_index <= length(radial_grid) ||
        throw(ArgumentError("QE_UPF_DATA_REQUIRED: PAW cutoff index is out of range"))
    cutoff_radius = parse(
        Float64,
        replace(
            _qe_upf_attribute(
                augmentation,
                "cutoff_r";
                required = false,
                default = string(radial_grid[cutoff_index]),
            ),
            'D' => 'E',
            'd' => 'e',
        ),
    )
    isfinite(cutoff_radius) ||
        throw(ArgumentError("QE_UPF_DATA_REQUIRED: PAW cutoff radius is non-finite"))
    beta_integration_cutoff = maximum(beta_cutoff_indices)
    metric_kind == :paw && (beta_integration_cutoff = max(beta_integration_cutoff, cutoff_index))

    q_node = _qe_upf_required(root, ".//*[local-name()='PP_Q']", "PP_Q")
    q_values = _qe_upf_numbers(q_node)
    length(q_values) == num_beta^2 ||
        throw(ArgumentError("QE_UPF_DATA_REQUIRED: PP_Q dimensions disagree with PP_BETA"))
    q_integrals = reshape(q_values, num_beta, num_beta)

    qfcoef = zeros(Float64, 0, 0, 0, 0)
    rinner = Float64[]
    if nqf > 0
        qfcoef_node = _qe_upf_required(root, ".//*[local-name()='PP_QFCOEF']", "PP_QFCOEF")
        coefficient_values = _qe_upf_numbers(qfcoef_node)
        length(coefficient_values) == nqf * nqlc * num_beta^2 ||
            throw(ArgumentError("QE_UPF_DATA_REQUIRED: PP_QFCOEF dimensions are inconsistent"))
        qfcoef = reshape(coefficient_values, nqf, nqlc, num_beta, num_beta)
        rinner =
            _qe_upf_numbers(_qe_upf_required(root, ".//*[local-name()='PP_RINNER']", "PP_RINNER"))
        length(rinner) == nqlc ||
            throw(ArgumentError("QE_UPF_DATA_REQUIRED: PP_RINNER dimensions are inconsistent"))
    end

    multipoles = Dict{NTuple{3, Int}, Vector{Float64}}()
    legacy_qij = Dict{Tuple{Int, Int}, Vector{Float64}}()
    for node in EzXML.findall(".//*", root)
        name = EzXML.nodename(node)
        qijl_match = match(r"^PP_QIJL\.(\d+)\.(\d+)\.(\d+)$"i, name)
        qij_match = match(r"^PP_QIJ\.(\d+)\.(\d+)$"i, name)
        if qijl_match !== nothing
            left, right, degree = parse.(Int, qijl_match.captures)
            1 <= left <= right <= num_beta ||
                throw(ArgumentError("QE_UPF_DATA_REQUIRED: PP_QIJL indices are invalid"))
            values = _qe_upf_numbers(node)
            length(values) == length(radial_grid) ||
                throw(ArgumentError("QE_UPF_DATA_REQUIRED: PP_QIJL mesh is inconsistent"))
            values[(cutoff_index + 1):end] .= 0.0
            multipoles[(left, right, degree)] = values
            multipoles[(right, left, degree)] = values
        elseif qij_match !== nothing
            left, right = parse.(Int, qij_match.captures)
            1 <= left <= right <= num_beta ||
                throw(ArgumentError("QE_UPF_DATA_REQUIRED: PP_QIJ indices are invalid"))
            values = _qe_upf_numbers(node)
            length(values) == length(radial_grid) ||
                throw(ArgumentError("QE_UPF_DATA_REQUIRED: PP_QIJ mesh is inconsistent"))
            legacy_qij[(left, right)] = values
            legacy_qij[(right, left)] = values
        end
    end
    if q_with_l
        isempty(multipoles) &&
            throw(ArgumentError("QE_UPF_DATA_REQUIRED: q_with_l UPF contains no PP_QIJL data"))
    else
        isempty(legacy_qij) &&
            throw(ArgumentError("QE_UPF_DATA_REQUIRED: legacy UPF contains no PP_QIJ data"))
        _qe_upf_apply_qfcoef!(multipoles, legacy_qij, radial_grid, angular_momenta, qfcoef, rinner)
    end
    return QEUPFData(
        abspath(filename),
        element,
        metric_kind,
        has_so,
        fully_relativistic,
        radial_grid,
        radial_weights,
        beta_radial,
        angular_momenta,
        beta_integration_cutoff,
        total_angular_momenta,
        dij,
        q_integrals,
        q_with_l,
        multipoles,
        qfcoef,
        rinner,
        nqlc,
        cutoff_index,
        cutoff_radius,
    )
end

# Expand per-atom radial beta channels in deterministic XML type/atom order.
function _build_qe_projector_plan(metadata, upf_data::Dict{String, QEUPFData})
    length(metadata.atomic_type_labels) == length(metadata.structure.species) ||
        throw(ArgumentError("QE_UPF_DATA_REQUIRED: XML atom/type dimensions disagree"))
    type_order = unique(metadata.atomic_type_labels)
    atoms = QEProjectorAtomPlan[]
    next_channel = 1
    for label in type_order
        haskey(upf_data, label) ||
            throw(ArgumentError("QE_UPF_DATA_REQUIRED: no parsed UPF for atomic type $(label)"))
        dataset = upf_data[label]
        channels = QEProjectorChannel[]
        for radial_index in eachindex(dataset.beta_angular_momenta)
            degree = dataset.beta_angular_momenta[radial_index]
            for harmonic_row in 1:(2 * degree + 1)
                push!(channels, QEProjectorChannel(radial_index, degree, harmonic_row))
            end
        end
        for atom_index in eachindex(metadata.atomic_type_labels)
            metadata.atomic_type_labels[atom_index] == label || continue
            channel_range = next_channel:(next_channel + length(channels) - 1)
            push!(
                atoms,
                QEProjectorAtomPlan(
                    label,
                    dataset.element,
                    Tuple(metadata.structure.positions_fractional[:, atom_index]),
                    copy(channels),
                    channel_range,
                ),
            )
            next_channel += length(channels)
        end
    end
    has_augmentation = any(dataset.metric_kind != :norm_conserving for dataset in values(upf_data))
    fully_relativistic = any(dataset.fully_relativistic for dataset in values(upf_data))
    return QEProjectorPlan(atoms, next_channel - 1, has_augmentation, fully_relativistic)
end
