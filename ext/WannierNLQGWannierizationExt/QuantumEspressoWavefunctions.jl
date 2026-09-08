# Return one required XML node selected without depending on the QE namespace prefix.
function _qe_xml_required(node, local_path::AbstractString)
    selected = EzXML.findfirst(local_path, node)
    selected === nothing && throw(ArgumentError("QE XML is missing $(local_path)"))
    return selected
end

# Parse whitespace-delimited numeric XML content.
function _qe_xml_numbers(node)
    return parse.(Float64, split(strip(EzXML.nodecontent(node))))
end

# Read the chemical element from the authoritative UPF PP_HEADER attribute.
function _qe_upf_element(filename::AbstractString)
    isfile(filename) || throw(ArgumentError("QE UPF does not exist: $(filename)"))
    contents = read(filename, String)
    matches = collect(
        eachmatch(r"<PP_HEADER\b[^>]*\belement\s*=\s*[\"']\s*([A-Za-z]{1,3})\s*[\"']"s, contents),
    )
    elements = unique(uppercasefirst(lowercase(strip(match.captures[1]))) for match in matches)
    length(elements) == 1 || throw(
        ArgumentError(
            "QE UPF PP_HEADER element is missing or conflicting in $(filename): " *
            "$(join(elements, ','))",
        ),
    )
    return only(elements)
end

# Classify the overlap metric declared by one UPF header.
function _qe_upf_metric_kind(filename::AbstractString)
    contents = read(filename, String)
    header = match(r"<PP_HEADER\b[^>]*>"s, contents)
    header === nothing && throw(ArgumentError("QE UPF has no PP_HEADER: $(filename)"))
    attribute(name) = begin
        matched =
            match(Regex("\\b$(name)\\s*=\\s*[\\\"']\\s*([^\\\"']+?)[\\\"']", "i"), header.match)
        matched === nothing ? "" : uppercase(strip(matched.captures[1]))
    end
    truth(value) = value in ("T", "TRUE", ".TRUE.")
    truth(attribute("is_paw")) && return :paw
    truth(attribute("is_ultrasoft")) && return :ultrasoft
    return :norm_conserving
end

# Validate the private QE reader purpose before touching source files.
function _qe_validate_reader_purpose(purpose::Symbol)
    purpose in (:band_representation, :physical_overlap) || throw(
        ArgumentError(
            "unsupported QE wavefunction reader purpose $(purpose); expected " *
            ":band_representation or :physical_overlap",
        ),
    )
    return purpose
end

# Summarize all UPF metric kinds in a stable provenance order.
function _qe_metric_kind_label(metric_kinds)
    present = Set(Symbol.(values(metric_kinds)))
    isempty(present) && throw(ArgumentError("QE source contains no UPF metric declarations"))
    order = (:norm_conserving, :paw, :ultrasoft)
    ordered = [kind for kind in order if kind in present]
    length(ordered) == length(present) || throw(
        ArgumentError(
            "QE source contains unsupported UPF metric kinds: " *
            join(sort!(string.(collect(setdiff(present, Set(order))))), ','),
        ),
    )
    return length(ordered) == 1 ? string(only(ordered)) : "mixed:" * join(string.(ordered), ',')
end

# Resolve the coefficient-gauge and physical-overlap capabilities of one QE source.
function _qe_reader_metric_contract(metric_kinds)
    metric_kind = _qe_metric_kind_label(metric_kinds)
    physical_overlap_available = all(==(:norm_conserving), values(metric_kinds))
    return (
        metric_kind,
        physical_overlap_available,
        coefficient_normalization = physical_overlap_available ? "euclidean_per_band" :
                                    "euclidean_per_band_pseudo_gauge",
        augmentation_backend = physical_overlap_available ? "not_required" : "unavailable",
        qualification = physical_overlap_available ? "standard" : "experimental",
    )
end

# Fail closed when a physical-overlap operation lacks QE beta/Q augmentation data.
function _qe_require_physical_overlap_backend(contract, purpose::Symbol)
    purpose == :physical_overlap &&
        !contract.physical_overlap_available &&
        throw(
            ArgumentError(
                "QE_AUGMENTATION_METRIC_REQUIRED: QE $(contract.metric_kind) wavefunctions " *
                "requested for purpose=physical_overlap require k-dependent beta-projector/Q " *
                "augmentation data; Euclidean pseudo-coefficient normalization is only a " *
                "coefficient gauge and is not the physical overlap metric",
            ),
        )
    return nothing
end

"""
    _qe_generalized_overlap(c_left, c_right, beta_left, beta_right, augmentation)

Evaluate the PAW/USPP overlap contract in band-row convention,
`C_l*C_r† + B_l*Q*B_r†`. This source-independent kernel is used by
synthetic augmentation tests; production QE PAW data must additionally provide
the k-dependent beta projections parsed from the save directory.
"""
function _qe_generalized_overlap(
    coefficients_left::AbstractMatrix,
    coefficients_right::AbstractMatrix,
    beta_left::AbstractMatrix,
    beta_right::AbstractMatrix,
    augmentation::AbstractMatrix,
)
    size(coefficients_left, 2) == size(coefficients_right, 2) ||
        throw(ArgumentError("plane-wave overlap dimensions disagree"))
    size(beta_left, 2) == size(augmentation, 1) ||
        throw(ArgumentError("left beta-projector and augmentation dimensions disagree"))
    size(beta_right, 2) == size(augmentation, 2) ||
        throw(ArgumentError("right beta-projector and augmentation dimensions disagree"))
    overlap = coefficients_left * coefficients_right' + beta_left * augmentation * beta_right'
    all(isfinite, overlap) || throw(ArgumentError("generalized overlap is non-finite"))
    return Matrix{ComplexF64}(overlap)
end

# Map QE atomic-type labels to real elements through the UPFs copied into .save.
function _qe_atomic_type_elements(input_node, save_directory::AbstractString)
    species_nodes =
        EzXML.findall(".//*[local-name()='atomic_species']/*[local-name()='species']", input_node)
    isempty(species_nodes) && throw(ArgumentError("QE XML contains no atomic_species entries"))
    elements = Dict{String, String}()
    upf_files = Dict{String, String}()
    for species_node in species_nodes
        label = strip(String(species_node["name"]))
        isempty(label) && throw(ArgumentError("QE atomic-type label is empty"))
        haskey(elements, label) &&
            throw(ArgumentError("QE atomic-type label appears more than once: $(label)"))
        pseudo_node = _qe_xml_required(species_node, "./*[local-name()='pseudo_file']")
        pseudo_name = strip(EzXML.nodecontent(pseudo_node))
        isempty(pseudo_name) &&
            throw(ArgumentError("QE atomic type $(label) has an empty pseudo_file"))
        upf_file = joinpath(save_directory, basename(pseudo_name))
        element = _qe_upf_element(upf_file)
        label_match = match(r"^([A-Z][a-z]?)(?:[0-9_].*)?$", label)
        if label_match !== nothing && label_match.captures[1] != element
            throw(
                ArgumentError(
                    "QE atomic-type label $(label) conflicts with UPF PP_HEADER element " *
                    "$(element); chemical identity must come from the UPF",
                ),
            )
        end
        elements[label] = element
        upf_files[label] = upf_file
    end
    return elements, upf_files
end

# Parse the structure and band metadata needed before binary wavefunction reads.
function _read_qe_xml(source::QuantumEspressoWavefunctionSource)
    xml_file = joinpath(source.save_directory, "data-file-schema.xml")
    isfile(xml_file) || throw(ArgumentError("QE XML does not exist: $(xml_file)"))
    document = EzXML.readxml(xml_file)
    root_node = EzXML.root(document)
    input_node = _qe_xml_required(root_node, "//*[local-name()='input']")
    type_elements, upf_files = _qe_atomic_type_elements(input_node, source.save_directory)
    metric_kinds = Dict(label => _qe_upf_metric_kind(path) for (label, path) in upf_files)
    structure_node = _qe_xml_required(input_node, ".//*[local-name()='atomic_structure']")
    cell_node = _qe_xml_required(structure_node, "./*[local-name()='cell']")
    lattice = Matrix{Float64}(undef, 3, 3)
    for row in 1:3
        values = _qe_xml_numbers(_qe_xml_required(cell_node, "./*[local-name()='a$(row)']"))
        length(values) == 3 || throw(ArgumentError("QE lattice row $(row) is malformed"))
        lattice[row, :] .= BOHR_TO_ANGSTROM .* values
    end
    position_nodes =
        EzXML.findall("./*[local-name()='atomic_positions']/*[local-name()='atom']", structure_node)
    isempty(position_nodes) && throw(ArgumentError("QE XML contains no atoms"))
    positions_cartesian = Matrix{Float64}(undef, 3, length(position_nodes))
    species = String[]
    atomic_type_labels = String[]
    for (atom, position_node) in enumerate(position_nodes)
        values = _qe_xml_numbers(position_node)
        length(values) == 3 || throw(ArgumentError("QE atom $(atom) position is malformed"))
        positions_cartesian[:, atom] .= BOHR_TO_ANGSTROM .* values
        atomic_type_label = strip(String(position_node["name"]))
        haskey(type_elements, atomic_type_label) || throw(
            ArgumentError(
                "QE atom type $(atomic_type_label) has no unambiguous UPF element mapping",
            ),
        )
        push!(atomic_type_labels, atomic_type_label)
        push!(species, type_elements[atomic_type_label])
    end
    positions_fractional = transpose(inv(lattice)) * positions_cartesian
    structure = CrystalStructure(
        lattice,
        species,
        positions_fractional;
        magnetic_moments_cartesian = source.magnetic_moments_cartesian,
    )
    band_node =
        _qe_xml_required(root_node, "//*[local-name()='output']/*[local-name()='band_structure']")
    noncollinear =
        lowercase(
            strip(EzXML.nodecontent(_qe_xml_required(band_node, "./*[local-name()='noncolin']"))),
        ) == "true"
    spinorbit_node = EzXML.findfirst("./*[local-name()='spinorbit']", band_node)
    spinorbit =
        spinorbit_node === nothing ? false :
        lowercase(strip(EzXML.nodecontent(spinorbit_node))) == "true"
    lsda =
        lowercase(
            strip(EzXML.nodecontent(_qe_xml_required(band_node, "./*[local-name()='lsda']"))),
        ) == "true"
    noncollinear &&
        lsda &&
        throw(ArgumentError("QE XML cannot be both noncollinear and collinear spin-polarized"))
    if lsda && source.spin_channel == :none
        throw(ArgumentError("collinear QE input requires spin_channel=:up or :down"))
    elseif !lsda && source.spin_channel != :none
        throw(ArgumentError("non-spin-polarized QE input requires spin_channel=:none"))
    end
    band_tag = if lsda
        source.spin_channel == :up ? "nbnd_up" : "nbnd_dw"
    else
        "nbnd"
    end
    num_bands = parse(
        Int,
        strip(EzXML.nodecontent(_qe_xml_required(band_node, "./*[local-name()='$(band_tag)']"))),
    )
    cutoff_hartree = parse(
        Float64,
        strip(
            EzXML.nodecontent(
                _qe_xml_required(
                    input_node,
                    ".//*[local-name()='basis']/*[local-name()='ecutwfc']",
                ),
            ),
        ),
    )
    kpoint_nodes = EzXML.findall("./*[local-name()='ks_energies']", band_node)
    isempty(kpoint_nodes) && throw(ArgumentError("QE XML contains no ks_energies blocks"))
    return (
        xml_file = xml_file,
        structure = structure,
        reciprocal_lattice = 2.0 * pi * inv(lattice)',
        noncollinear = noncollinear,
        spinorbit = spinorbit,
        collinear = lsda,
        num_bands = num_bands,
        cutoff_ev = cutoff_hartree * HARTREE_TO_EV,
        kpoint_nodes = kpoint_nodes,
        atomic_type_labels = atomic_type_labels,
        type_elements = type_elements,
        upf_files = upf_files,
        metric_kinds = metric_kinds,
    )
end

# Reinterpret one native-endian Fortran record as a validated scalar type.
function _qe_record_values(bytes::Vector{UInt8}, ::Type{T}) where {T}
    rem(length(bytes), sizeof(T)) == 0 ||
        throw(ArgumentError("QE Fortran record byte count is not divisible by $(sizeof(T))"))
    return collect(reinterpret(T, bytes))
end

# Resolve one QE wavefunction file without disguising HDF5 as Fortran data.
function _qe_wavefunction_file(source::QuantumEspressoWavefunctionSource, kpoint::Int)
    channel = source.spin_channel == :none ? "" : source.spin_channel == :up ? "up" : "dw"
    stem = "wfc$(channel)$(kpoint)"
    for candidate in (
        joinpath(source.save_directory, lowercase(stem) * ".dat"),
        joinpath(source.save_directory, uppercase(stem) * ".DAT"),
        joinpath(source.save_directory, lowercase(stem) * ".hdf5"),
        joinpath(source.save_directory, uppercase(stem) * ".HDF5"),
    )
        isfile(candidate) && return candidate
    end
    throw(
        ArgumentError(
            "QE wavefunction file is missing for k-point $(kpoint): $(stem).dat or $(stem).hdf5",
        ),
    )
end

# Parse one QE wfc*.dat Fortran-unformatted file with strict record validation.
function _read_qe_kpoint(
    filename::AbstractString,
    selected_bands::AbstractVector{Int},
    xml_energies::Vector{Float64},
    expected_spin_components::Int,
    representation_cutoff_ev::Union{Nothing, Float64},
    reciprocal_lattice::Matrix{Float64},
    normalize_coefficients::Bool,
)
    return open(filename, "r") do io
        first_record = read_fortran_record(io)
        first_io = IOBuffer(first_record)
        _ = read(first_io, Int32)
        k_cartesian = [read(first_io, Float64) for _ in 1:3]
        _ = read(first_io, Int32)
        _ = read(first_io, Int32)
        _ = read(first_io, Float64)
        eof(first_io) || throw(ArgumentError("QE first wavefunction record has trailing bytes"))
        dimensions = _qe_record_values(read_fortran_record(io), Int32)
        length(dimensions) == 4 ||
            throw(ArgumentError("QE dimension record must contain four Int32 values"))
        _, plane_wave_count, spin_components, num_bands = Int.(dimensions)
        spin_components == expected_spin_components ||
            throw(ArgumentError("QE binary/XML spin-component mismatch"))
        !isempty(selected_bands) && maximum(selected_bands) <= num_bands ||
            throw(ArgumentError("selected band range exceeds QE binary nbnd"))
        reciprocal_record = _qe_record_values(read_fortran_record(io), Float64)
        length(reciprocal_record) == 9 ||
            throw(ArgumentError("QE reciprocal-lattice record must contain nine Float64 values"))
        binary_reciprocal = row_major_matrix(reciprocal_record, 3, 3)
        k_fractional = transpose(binary_reciprocal) \ k_cartesian
        g_record = _qe_record_values(read_fortran_record(io), Int32)
        length(g_record) == 3 * plane_wave_count ||
            throw(ArgumentError("QE Miller-index record has incompatible size"))
        g_vectors = row_major_matrix(g_record, plane_wave_count, 3)
        g_vectors_int = round.(Int, g_vectors)
        retained = if representation_cutoff_ev === nothing
            collect(1:plane_wave_count)
        else
            [
                plane_wave for plane_wave in 1:plane_wave_count if plane_wave_energy_ev(
                    @view(g_vectors_int[plane_wave, :]) .+ k_fractional,
                    reciprocal_lattice,
                ) < something(representation_cutoff_ev)
            ]
        end
        coefficients = zeros(ComplexF64, length(selected_bands), length(retained), spin_components)
        output_band = Dict(band => index for (index, band) in enumerate(selected_bands))
        for band in 1:num_bands
            raw = _qe_record_values(read_fortran_record(io), Float64)
            length(raw) == 2 * plane_wave_count * spin_components ||
                throw(ArgumentError("QE coefficient record $(band) has incompatible size"))
            haskey(output_band, band) || continue
            complex_values = ComplexF64.(raw[1:2:end], raw[2:2:end])
            reshaped = reshape(complex_values, plane_wave_count, spin_components)
            coefficients[output_band[band], :, :] .= reshaped[retained, :]
        end
        eof(io) || throw(ArgumentError("QE wavefunction file contains unexpected trailing records"))
        return PlaneWaveKPoint(
            k_fractional,
            g_vectors_int[retained, :],
            coefficients,
            xml_energies[selected_bands],
            ;
            normalize_coefficients,
        )
    end
end

# Read one QE HDF5 wavefunction using its explicit root and dataset contracts.
function _read_qe_hdf5_kpoint(
    filename::AbstractString,
    selected_bands::AbstractVector{Int},
    xml_energies::Vector{Float64},
    expected_spin_components::Int,
    representation_cutoff_ev::Union{Nothing, Float64},
    reciprocal_lattice::Matrix{Float64},
    normalize_coefficients::Bool,
)
    return HDF5.h5open(filename, "r") do handle
        root_attributes = HDF5.attributes(handle)
        for attribute in ("igwx", "nbnd", "npol", "xk", "scale_factor")
            haskey(root_attributes, attribute) ||
                throw(ArgumentError("QE HDF5 wavefunction omits root attribute $(attribute)"))
        end
        plane_wave_count = Int(read(root_attributes["igwx"]))
        num_bands = Int(read(root_attributes["nbnd"]))
        spin_components = Int(read(root_attributes["npol"]))
        spin_components == expected_spin_components ||
            throw(ArgumentError("QE HDF5/XML spin-component mismatch"))
        !isempty(selected_bands) && maximum(selected_bands) <= num_bands ||
            throw(ArgumentError("selected band range exceeds QE HDF5 nbnd"))
        haskey(handle, "MillerIndices") ||
            throw(ArgumentError("QE HDF5 wavefunction omits MillerIndices"))
        miller_dataset = handle["MillerIndices"]
        miller_values = read(miller_dataset)
        size(miller_values) == (3, plane_wave_count) ||
            throw(ArgumentError("QE HDF5 MillerIndices has incompatible dimensions"))
        g_vectors = Matrix{Int}(transpose(miller_values))
        miller_attributes = HDF5.attributes(miller_dataset)
        all(name -> haskey(miller_attributes, name), ("bg1", "bg2", "bg3")) ||
            throw(ArgumentError("QE HDF5 MillerIndices omits reciprocal-basis attributes"))
        binary_reciprocal = reduce(
            vcat,
            transpose(Float64.(read(miller_attributes["bg$(index)"]))) for index in 1:3
        )
        k_cartesian = Float64.(read(root_attributes["xk"]))
        length(k_cartesian) == 3 ||
            throw(ArgumentError("QE HDF5 xk attribute must contain three values"))
        k_fractional = transpose(binary_reciprocal) \ k_cartesian
        retained = if representation_cutoff_ev === nothing
            collect(1:plane_wave_count)
        else
            [
                plane_wave for plane_wave in 1:plane_wave_count if plane_wave_energy_ev(
                    @view(g_vectors[plane_wave, :]) .+ k_fractional,
                    reciprocal_lattice,
                ) < something(representation_cutoff_ev)
            ]
        end
        haskey(handle, "evc") || throw(ArgumentError("QE HDF5 wavefunction omits evc"))
        raw_coefficients = read(handle["evc"])
        size(raw_coefficients) == (2 * plane_wave_count * spin_components, num_bands) ||
            throw(ArgumentError("QE HDF5 evc has incompatible dimensions"))
        scale_factor = Float64(read(root_attributes["scale_factor"]))
        isfinite(scale_factor) || throw(ArgumentError("QE HDF5 scale_factor is not finite"))
        coefficients = zeros(ComplexF64, length(selected_bands), length(retained), spin_components)
        for (output_band, band) in enumerate(selected_bands)
            raw = @view raw_coefficients[:, band]
            complex_values = scale_factor .* ComplexF64.(raw[1:2:end], raw[2:2:end])
            reshaped = reshape(complex_values, plane_wave_count, spin_components)
            coefficients[output_band, :, :] .= reshaped[retained, :]
        end
        return PlaneWaveKPoint(
            k_fractional,
            g_vectors[retained, :],
            coefficients,
            xml_energies[selected_bands],
            ;
            normalize_coefficients,
        )
    end
end

# Dispatch the native QE wavefunction reader by the actual on-disk format.
function _read_qe_wavefunction_kpoint(
    filename::AbstractString,
    selected_bands::AbstractVector{Int},
    xml_energies::Vector{Float64},
    expected_spin_components::Int,
    representation_cutoff_ev::Union{Nothing, Float64},
    reciprocal_lattice::Matrix{Float64},
    normalize_coefficients::Bool,
)
    if lowercase(splitext(filename)[2]) == ".hdf5"
        return _read_qe_hdf5_kpoint(
            filename,
            selected_bands,
            xml_energies,
            expected_spin_components,
            representation_cutoff_ev,
            reciprocal_lattice,
            normalize_coefficients,
        )
    end
    return _read_qe_kpoint(
        filename,
        selected_bands,
        xml_energies,
        expected_spin_components,
        representation_cutoff_ev,
        reciprocal_lattice,
        normalize_coefficients,
    )
end

# Read only the k-point, band-count, and spin metadata needed to construct a
# bounded uIu wavefunction cache. Coefficient datasets/records are untouched.
function _read_qe_wavefunction_header(filename::AbstractString, expected_spin_components::Int)
    if lowercase(splitext(filename)[2]) == ".hdf5"
        return HDF5.h5open(filename, "r") do handle
            root_attributes = HDF5.attributes(handle)
            for attribute in ("nbnd", "npol", "xk")
                haskey(root_attributes, attribute) ||
                    throw(ArgumentError("QE HDF5 wavefunction omits root attribute $(attribute)"))
            end
            spin_components = Int(read(root_attributes["npol"]))
            spin_components == expected_spin_components ||
                throw(ArgumentError("QE HDF5/XML spin-component mismatch"))
            haskey(handle, "MillerIndices") ||
                throw(ArgumentError("QE HDF5 wavefunction omits MillerIndices"))
            miller_attributes = HDF5.attributes(handle["MillerIndices"])
            all(name -> haskey(miller_attributes, name), ("bg1", "bg2", "bg3")) ||
                throw(ArgumentError("QE HDF5 MillerIndices omits reciprocal-basis attributes"))
            binary_reciprocal = reduce(
                vcat,
                transpose(Float64.(read(miller_attributes["bg$(index)"]))) for index in 1:3
            )
            k_cartesian = Float64.(read(root_attributes["xk"]))
            length(k_cartesian) == 3 ||
                throw(ArgumentError("QE HDF5 xk attribute must contain three values"))
            return (
                k_fractional = Vector{Float64}(transpose(binary_reciprocal) \ k_cartesian),
                num_bands = Int(read(root_attributes["nbnd"])),
                spin_components,
            )
        end
    end
    return open(filename, "r") do io
        first_io = IOBuffer(read_fortran_record(io))
        _ = read(first_io, Int32)
        k_cartesian = [read(first_io, Float64) for _ in 1:3]
        _ = read(first_io, Int32)
        _ = read(first_io, Int32)
        _ = read(first_io, Float64)
        eof(first_io) || throw(ArgumentError("QE first wavefunction record has trailing bytes"))
        dimensions = _qe_record_values(read_fortran_record(io), Int32)
        length(dimensions) == 4 ||
            throw(ArgumentError("QE dimension record must contain four Int32 values"))
        _, _, spin_components, num_bands = Int.(dimensions)
        spin_components == expected_spin_components ||
            throw(ArgumentError("QE binary/XML spin-component mismatch"))
        reciprocal_record = _qe_record_values(read_fortran_record(io), Float64)
        length(reciprocal_record) == 9 ||
            throw(ArgumentError("QE reciprocal-lattice record must contain nine Float64 values"))
        binary_reciprocal = row_major_matrix(reciprocal_record, 3, 3)
        return (
            k_fractional = Vector{Float64}(transpose(binary_reciprocal) \ k_cartesian),
            num_bands,
            spin_components,
        )
    end
end

# Read QE coefficients for either coefficient sewing or a physical-overlap operation.
function _read_qe_wavefunctions(
    source::QuantumEspressoWavefunctionSource;
    purpose::Symbol = :band_representation,
    retain_all_plane_waves::Bool = false,
    normalize_coefficients::Bool = true,
    metadata = nothing,
    native_paw_construction::Bool = false,
)
    _qe_validate_reader_purpose(purpose)
    metadata_value = metadata === nothing ? _read_qe_xml(source) : metadata
    metric_contract = _qe_reader_metric_contract(metadata_value.metric_kinds)
    _qe_require_physical_overlap_backend(metric_contract, purpose)
    native_paw_construction &&
        purpose != :band_representation &&
        throw(
            ArgumentError(
                "raw native QE PAW construction must retain the coefficient-sewing purpose",
            ),
        )
    native_paw_construction &&
        normalize_coefficients &&
        throw(
            ArgumentError(
                "QE_PAW_RAW_COEFFICIENTS_REQUIRED: raw construction cannot normalize bands",
            ),
        )
    selected_bands = selected_band_range(source.band_range, metadata_value.num_bands)
    cutoff = if retain_all_plane_waves
        source.representation_cutoff_ev === nothing || throw(
            ArgumentError(
                "QE_PAW_RAW_COEFFICIENTS_REQUIRED: full plane-wave retention forbids a representation cutoff",
            ),
        )
        nothing
    else
        source.representation_cutoff_ev === nothing ? metadata_value.cutoff_ev :
        source.representation_cutoff_ev
    end
    cutoff === nothing ||
        cutoff <= metadata_value.cutoff_ev + 1.0e-10 ||
        throw(ArgumentError("representation cutoff exceeds the QE wavefunction cutoff"))
    spin_components = metadata_value.noncollinear ? 2 : 1
    points = PlaneWaveKPoint[]
    hashes = Dict("data-file-schema.xml" => sha256_file(metadata_value.xml_file))
    for label in sort!(collect(keys(metadata_value.upf_files)))
        upf_file = metadata_value.upf_files[label]
        hashes["UPF:$(label):$(basename(upf_file))"] = sha256_file(upf_file)
    end
    for (kpoint_index, xml_kpoint) in enumerate(metadata_value.kpoint_nodes)
        energies =
            HARTREE_TO_EV .*
            _qe_xml_numbers(_qe_xml_required(xml_kpoint, "./*[local-name()='eigenvalues']"))
        length(energies) == metadata_value.num_bands ||
            throw(ArgumentError("QE XML band count mismatch at k-point $(kpoint_index)"))
        wavefunction_file = _qe_wavefunction_file(source, kpoint_index)
        point = _read_qe_wavefunction_kpoint(
            wavefunction_file,
            selected_bands,
            energies,
            spin_components,
            cutoff,
            metadata_value.reciprocal_lattice,
            normalize_coefficients,
        )
        push!(points, point)
        hashes[basename(wavefunction_file)] = sha256_file(wavefunction_file)
    end
    kpoints = Matrix{Float64}(undef, length(points), 3)
    for (index, point) in enumerate(points)
        kpoints[index, :] .= point.k_fractional
    end
    return NativeWavefunctionData(
        :qe,
        metadata_value.structure,
        metadata_value.reciprocal_lattice,
        infer_mp_grid(kpoints),
        metadata_value.noncollinear,
        points,
        hashes,
        Dict(
            "qe_atomic_type_labels" => join(metadata_value.atomic_type_labels, ","),
            "qe_atomic_type_to_element" => join(
                [
                    "$(label)=>$(metadata_value.type_elements[label])" for
                    label in sort!(collect(keys(metadata_value.type_elements)))
                ],
                ";",
            ),
            "qe_element_authority" => "UPF PP_HEADER element",
            "qe_reader_purpose" =>
                native_paw_construction ? "native_paw_matrix_construction_raw" : string(purpose),
            "qe_metric_kind" => metric_contract.metric_kind,
            "coefficient_normalization" =>
                normalize_coefficients ? metric_contract.coefficient_normalization : "qe_raw",
            "sewing_construction" => "coefficient_mapping",
            "physical_overlap_available" => string(
                native_paw_construction ? false : metric_contract.physical_overlap_available,
            ),
            "augmentation_backend" =>
                native_paw_construction ? "native_qe_paw_pending_qualification" :
                metric_contract.augmentation_backend,
            "qualification" =>
                native_paw_construction ? "diagnostic_pending_oracle" :
                metric_contract.qualification,
            "spin_mode" =>
                metadata_value.collinear ? "collinear_single_channel" :
                metadata_value.noncollinear ? "noncollinear_spinor" : "scalar",
            "spinorbit" => string(metadata_value.spinorbit),
            "spin_channel" => string(source.spin_channel),
        ),
    )
end

# Read untruncated, unnormalized QE coefficients without claiming a physical metric.
function _read_qe_raw_wavefunctions(source::QuantumEspressoWavefunctionSource, metadata = nothing)
    source.band_range === nothing || throw(
        ArgumentError(
            "QE_NNKP_BAND_AUTHORITY_REQUIRED: raw QE matrix generation selects bands from NNKP",
        ),
    )
    source.representation_cutoff_ev === nothing || throw(
        ArgumentError(
            "QE_PAW_RAW_COEFFICIENTS_REQUIRED: native QE matrices require the full wavefunction cutoff",
        ),
    )
    return _read_qe_wavefunctions(
        source;
        purpose = :band_representation,
        retain_all_plane_waves = true,
        normalize_coefficients = false,
        metadata,
        native_paw_construction = true,
    )
end
