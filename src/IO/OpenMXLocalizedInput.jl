"""Read bounded OpenMX scalar arrays with explicit file byte order, independent of host endianness."""
function _read_localized_binary_values(
    stream,
    ::Type{T},
    count::Integer,
    byte_order::Symbol,
) where {T <: Union{Int32, Float64}}
    count >= 0 || throw(ArgumentError("negative binary array length"))
    # Validate available file bytes before allocating from untrusted counts.
    # Plausible atom/cell products can still claim huge neighbor arrays in a
    # tiny truncated file; the file budget must bound these allocations too.
    offset = position(stream)
    seekend(stream)
    remaining = position(stream) - offset
    seek(stream, offset)
    count <= remaining ÷ sizeof(T) || throw(EOFError())
    values = Vector{T}(undef, count)
    read!(stream, values)
    native_little = ENDIAN_BOM == 0x04030201
    if native_little != (byte_order == :little)
        if T == Float64
            return copy(reinterpret(Float64, bswap.(reinterpret(UInt64, values))))
        end
        return bswap.(values)
    end
    return values
end

"""Locate the appended coordinate marker by bytes before decoding its ASCII text."""
function _localized_coordinate_marker(bytes::Vector{UInt8})
    marker = collect(codeunits("Fractional coordinates of the final structure"))
    for index in 1:(length(bytes) - length(marker) + 1)
        bytes[index] == marker[1] || continue
        view(bytes, index:(index + length(marker) - 1)) == marker && return index
    end
    throw(ArgumentError("OpenMX 3.8 input requires appended final fractional coordinates"))
end

"""Read appended atom coordinates in persisted atom order, rejecting missing or duplicate rows."""
function _read_localized_atom_coordinates(stream, atom_count)
    tail = read(stream)
    start = _localized_coordinate_marker(tail)
    text_bytes = tail[start:min(length(tail), start + 4095 + 200 * atom_count)]
    all(byte -> byte < 0x80, text_bytes) ||
        throw(ArgumentError("appended coordinate section must be ASCII"))
    pattern =
        r"^\s*(\d+)\s+([A-Za-z][A-Za-z0-9]*)\s+([+\-.0-9Ee]+)\s+([+\-.0-9Ee]+)\s+([+\-.0-9Ee]+)\s*$"
    positions = zeros(Float64, 3, atom_count)
    labels = String[]
    for line in split(String(text_bytes), '\n')
        parsed = match(pattern, line)
        parsed === nothing && continue
        expected = length(labels) + 1
        parse(Int, parsed[1]) == expected ||
            throw(ArgumentError("appended atom coordinate order mismatch"))
        expected <= atom_count || break
        positions[:, expected] = parse.(Float64, parsed.captures[3:5])
        push!(labels, parsed[2])
        length(labels) == atom_count && break
    end
    length(labels) == atom_count && all(isfinite, positions) ||
        throw(ArgumentError("incomplete or nonfinite appended atom coordinates"))
    return positions, labels
end

"""
Read scalar OpenMX 3.8 or scalar/collinear/spinor binary-version-3 scfout records.

The caller declares `format_version="3.8"` or `"scfout_v3"` and the file byte order.
The latter is the binary contract emitted by the supported 3.9/4.0 interface;
the software release is not inferred from the binary header. Spinful legacy 3.8
is not qualified and is rejected. Version 3 flags 1/3 require explicit
`magnetic_state` and `spin_orbit_coupling`; flag 3 cannot infer either from its
header. Four real and three imaginary H records are consumed for flag 3,
including imaginary mixing when SOC is off. The down/up block at R is the
adjoint up/down block at -R. Spinful ordering is blocked, with atom-major spatial
orbitals repeated in up then down order. S/r are spin identities. Orbitals retain atom-major order
and each atom's persisted orbital order. Lattice columns in Bohr become rows in
Angstrom. Position blocks receive the bra atom's Cartesian position times S before
conversion. Version 3 defaults to binary Cartesian Gxyz in Bohr, preserving
unwrapped cluster coordinates. Version 3.8 retains the explicitly appended final
fractional-coordinate convention. `position_source=:binary_cartesian` is also
available there. Wrapped printed coordinates must not replace Gxyz for clusters.
The explicit `:legacy_openmx` convention uses 27.211399 eV/Hartree and
0.529177249 Angstrom/Bohr, matching the historical OpenMX postprocessing interface.
These values are provenance, not a hidden rescaling to modern physical constants.
No overlap clipping, omitted band or inferred spin factor occurs. Raw arrays and
file bytes remain unchanged. The model explicitly constructs consistent effective
H/S/r by partner projection and records raw/effective defects and adjustment size.
Raw material data and its redistribution rights remain caller-owned.
The default `operator_scope=:hamiltonian_overlap_position` admits finite H/S/r
with complete shapes and translation partners; representation tolerances report
warnings. Explicit `:hamiltonian_overlap` retains H/S and raw position diagnostics
without admitting position; requests needing position then fail before execution.
"""
function read_openmx_localized_input(
    path::AbstractString;
    format_version::AbstractString,
    byte_order::Symbol,
    position_source::Symbol = format_version == "3.8" ? :appended_final_fractional :
                              :binary_cartesian,
    operator_scope::Symbol = :hamiltonian_overlap_position,
    unit_convention::Symbol = :legacy_openmx,
    metric_relative_floor::Real = 1e-10,
    representation_tolerance::Real = 1e-8,
    hamiltonian_representation_tolerance_ev::Real = representation_tolerance,
    overlap_representation_tolerance::Real = representation_tolerance,
    position_translation_tolerance_angstrom::Real = representation_tolerance,
    magnetic_state::Union{Nothing, Symbol} = nothing,
    spin_orbit_coupling::Union{Nothing, Bool} = nothing,
    wannier_center_convention::AbstractString = "Convention_II",
    max_file_bytes::Integer = 32 * 2^20,
    max_model_bytes::Integer = 512 * 2^20,
)
    format_version in ("3.8", "scfout_v3") ||
        throw(ArgumentError("unsupported declared OpenMX binary format"))
    position_source in (:binary_cartesian, :appended_final_fractional) ||
        throw(ArgumentError("unsupported atomic position source"))
    operator_scope in (:hamiltonian_overlap, :hamiltonian_overlap_position) ||
        throw(ArgumentError("unsupported imported operator scope"))
    byte_order in (:little, :big) || throw(ArgumentError("byte_order must be :little or :big"))
    unit_convention == :legacy_openmx || throw(ArgumentError("unsupported OpenMX unit convention"))
    max_file_bytes > 0 && max_model_bytes > 0 ||
        throw(ArgumentError("import limits must be positive"))
    filename = abspath(path)
    filesize(filename) <= max_file_bytes ||
        throw(ArgumentError("OpenMX input exceeds declared file budget"))
    bohr_to_angstrom = 0.529177249
    hartree_to_ev = 27.211399
    source_identity = scientific_file_state(filename)
    return open(filename, "r") do stream
        read_values(type, count) = _read_localized_binary_values(stream, type, count, byte_order)
        header = Int.(read_values(Int32, format_version == "3.8" ? 6 : 7))
        atom_count, spin_encoded, _, _, _, translated_cells = header[1:6]
        binary_version = format_version == "3.8" ? 0 : spin_encoded >> 2
        format_version == "3.8" ||
            binary_version == 3 ||
            throw(ArgumentError("scfout binary version is not 3"))
        spin_mode = format_version == "3.8" ? spin_encoded : spin_encoded & 3
        moment_order = format_version == "3.8" ? 1 : header[7]
        1 <= moment_order <= 8 || throw(ArgumentError("unsupported OpenMX position moment order"))
        1 <= atom_count <= 10_000 && 0 <= translated_cells <= 100_000 ||
            throw(ArgumentError("invalid OpenMX atom/cell counts or byte order"))
        spin_mode in (0, 1, 3) || throw(ArgumentError("unsupported OpenMX spin flag"))
        format_version != "3.8" ||
            spin_mode == 0 ||
            throw(ArgumentError("spinful legacy OpenMX 3.8 format is not qualified"))
        spin_mode == 0 ||
            (magnetic_state !== nothing && spin_orbit_coupling !== nothing) ||
            throw(
                ArgumentError(
                    "spinful OpenMX input requires explicit magnetic_state and spin_orbit_coupling",
                ),
            )
        magnetic = magnetic_state === nothing ? :nonmagnetic : magnetic_state
        soc = spin_orbit_coupling === nothing ? false : spin_orbit_coupling
        representation = spin_mode == 0 ? :spinless : spin_mode == 1 ? :collinear : :spinor
        spin_mode != 1 ||
            !soc ||
            throw(ArgumentError("OpenMX SOC requires the noncollinear spinor format"))
        cell_count = translated_cells + 1
        translations_cartesian = reshape(read_values(Float64, 4cell_count), 4, cell_count)[2:4, :]
        translations = Int.(reshape(read_values(Int32, 4cell_count), 4, cell_count)[2:4, :])
        orbital_counts = Int.(read_values(Int32, atom_count))
        all(count -> 1 <= count <= 512, orbital_counts) && sum(orbital_counts) <= 4096 ||
            throw(ArgumentError("invalid OpenMX orbital counts"))
        neighbor_counts = Int.(read_values(Int32, atom_count)) .+ 1
        all(count -> 1 <= count <= cell_count * atom_count, neighbor_counts) ||
            throw(ArgumentError("invalid OpenMX neighbor counts"))
        neighbor_atoms = [Int.(read_values(Int32, count)) for count in neighbor_counts]
        neighbor_cells = [Int.(read_values(Int32, count)) .+ 1 for count in neighbor_counts]
        all(row -> all(index -> 1 <= index <= atom_count, row), neighbor_atoms) ||
            throw(ArgumentError("OpenMX neighbor atom index out of range"))
        all(row -> all(index -> 1 <= index <= cell_count, row), neighbor_cells) ||
            throw(ArgumentError("OpenMX neighbor cell index out of range"))
        lattice_columns = reshape(read_values(Float64, 12), 4, 3)[2:4, :]
        reciprocal_columns = reshape(read_values(Float64, 12), 4, 3)[2:4, :]
        atom_cartesian_header = reshape(read_values(Float64, 4atom_count), 4, atom_count)[2:4, :]
        all(isfinite, lattice_columns) &&
        all(isfinite, reciprocal_columns) &&
        all(isfinite, atom_cartesian_header) &&
        all(isfinite, translations_cartesian) || throw(ArgumentError("nonfinite OpenMX geometry"))
        maximum(abs, translations_cartesian - lattice_columns * translations) <= 1e-8 ||
            throw(ArgumentError("OpenMX integer/Cartesian cell translations disagree"))
        active_cells =
            sort!(unique(vcat(neighbor_cells...)); by = index -> Tuple(translations[:, index]))
        r_vectors = translations[:, active_cells]
        n, nr = sum(orbital_counts), length(active_cells)
        # Include imported, raw and effective copies and spinor expansion, not
        # only the five final operator arrays. This is a bounded allocation cap.
        estimated_bytes = big(n) * n * nr * (spin_mode == 0 ? 20 : 80) * sizeof(ComplexF64)
        estimated_bytes <= max_model_bytes ||
            throw(ArgumentError("localized arrays exceed declared model budget"))
        cell_lookup = Dict(index => slot for (slot, index) in enumerate(active_cells))
        orbital_offsets = cumsum(vcat(0, orbital_counts))[1:(end - 1)]
        function read_blocks()
            blocks = zeros(Float64, n, n, nr)
            seen = Set{Tuple{Int, Int, Int}}()
            for atom in 1:atom_count, neighbor in 1:neighbor_counts[atom]
                other = neighbor_atoms[atom][neighbor]
                slot = cell_lookup[neighbor_cells[atom][neighbor]]
                key = (atom, other, slot)
                key in seen && throw(ArgumentError("duplicate OpenMX atom-pair/cell block"))
                push!(seen, key)
                rows = orbital_offsets[atom] .+ (1:orbital_counts[atom])
                columns = orbital_offsets[other] .+ (1:orbital_counts[other])
                # Persisted C row-major bra/ket is read into Julia (ket,bra), then transposed.
                values = reshape(
                    read_values(Float64, length(rows) * length(columns)),
                    length(columns),
                    length(rows),
                )
                all(isfinite, values) || throw(ArgumentError("nonfinite OpenMX matrix block"))
                blocks[rows, columns, slot] = transpose(values)
            end
            return blocks
        end
        real_hamiltonian = [read_blocks() for _ in 0:spin_mode]
        imaginary_hamiltonian = spin_mode == 3 ? [read_blocks() for _ in 1:3] : nothing
        overlap = read_blocks()
        position = zeros(Float64, n, n, 3, nr)
        for axis in 1:3
            for order in 1:moment_order
                values = read_blocks()
                order == 1 && (position[:, :, axis, :] = values)
            end
        end
        if format_version == "scfout_v3"
            for axis in 1:3
                read_blocks() # Momentum is outside this H/S/r import contract.
            end
        end
        # Density is outside this postprocessing contract, but its bytes locate the appended text.
        for _ in 0:spin_mode
            read_blocks()
        end
        chemical_potential = nothing
        electronic_temperature = nothing
        if format_version == "scfout_v3"
            read_blocks();
            read_blocks() # Persisted imaginary density records.
            solver = only(read_values(Int32, 1))
            chemical_potential, electronic_temperature = read_values(Float64, 2)
            all(isfinite, (chemical_potential, electronic_temperature)) ||
                throw(ArgumentError("nonfinite OpenMX thermodynamic metadata"))
            read_values(Float64, 8) # Two dipoles, valence electron count and total spin.
            dummy_blocks = Int(only(read_values(Int32, 1)))
            0 <= dummy_blocks <= filesize(filename) ÷ 256 ||
                throw(ArgumentError("invalid OpenMX trailing record count"))
            read!(stream, Vector{UInt8}(undef, 256dummy_blocks))
        end
        if position_source == :binary_cartesian
            atom_positions = atom_cartesian_header
            fractional_positions = lattice_columns \ atom_positions
            labels = fill("UNRECORDED", atom_count)
        else
            fractional_positions, labels = _read_localized_atom_coordinates(stream, atom_count)
            atom_positions = lattice_columns * fractional_positions
        end
        for atom in 1:atom_count
            rows = orbital_offsets[atom] .+ (1:orbital_counts[atom])
            for axis in 1:3
                @views position[rows, :, axis, :] .+=
                    atom_positions[axis, atom] .* overlap[rows, :, :]
            end
        end
        translated_position = position * bohr_to_angstrom
        cell_partners = Dict(Tuple(r_vectors[:, i]) => i for i in 1:nr)
        raw_position_defect = 0.0
        for i in 1:nr
            partner = get(cell_partners, Tuple(-r_vectors[:, i]), nothing)
            partner === nothing &&
                throw(ArgumentError("OpenMX active cell has no negative partner"))
            displacement = bohr_to_angstrom * lattice_columns * r_vectors[:, i]
            for axis in 1:3
                residual =
                    translated_position[:, :, axis, i] - translated_position[:, :, axis, partner]' -
                    displacement[axis] * overlap[:, :, i]
                raw_position_defect = max(raw_position_defect, maximum(abs, residual))
            end
        end
        spatial_centers = zeros(Float64, 3, n)
        for atom in 1:atom_count
            rows = orbital_offsets[atom] .+ (1:orbital_counts[atom])
            spatial_centers[:, rows] .= atom_positions[:, atom] .* bohr_to_angstrom
        end
        if spin_mode == 0
            hamiltonian = real_hamiltonian[1]
            centers = spatial_centers
        else
            hamiltonian = zeros(ComplexF64, 2n, 2n, nr)
            hamiltonian[1:n, 1:n, :] = real_hamiltonian[1]
            hamiltonian[(n + 1):2n, (n + 1):2n, :] = real_hamiltonian[2]
            if spin_mode == 3
                hamiltonian[1:n, 1:n, :] .+= im .* imaginary_hamiltonian[1]
                hamiltonian[(n + 1):2n, (n + 1):2n, :] .+= im .* imaginary_hamiltonian[2]
                mixing =
                    real_hamiltonian[3] + im .* (real_hamiltonian[4] + imaginary_hamiltonian[3])
                hamiltonian[1:n, (n + 1):2n, :] = mixing
                for index in 1:nr
                    partner = cell_partners[Tuple(-r_vectors[:, index])]
                    hamiltonian[(n + 1):2n, 1:n, index] = mixing[:, :, partner]'
                end
            end
            spin_overlap = zeros(ComplexF64, 2n, 2n, nr)
            spin_position = zeros(ComplexF64, 2n, 2n, 3, nr)
            for indices in (1:n, (n + 1):2n)
                spin_overlap[indices, indices, :] = overlap
                spin_position[indices, indices, :, :] = translated_position
            end
            overlap = spin_overlap
            translated_position = spin_position
            centers = hcat(spatial_centers, spatial_centers)
        end
        model = NonorthogonalLocalizedModel(
            lattice = transpose(lattice_columns) * bohr_to_angstrom,
            r_vectors = r_vectors,
            hamiltonian_r = hamiltonian * hartree_to_ev,
            overlap_r = overlap,
            position_r = operator_scope == :hamiltonian_overlap_position ? translated_position :
                         nothing,
            metric_relative_floor = metric_relative_floor,
            representation_tolerance = representation_tolerance,
            hamiltonian_representation_tolerance_ev = hamiltonian_representation_tolerance_ev,
            overlap_representation_tolerance = overlap_representation_tolerance,
            position_translation_tolerance_angstrom = position_translation_tolerance_angstrom,
            spin_representation = representation,
            magnetic_state = magnetic,
            spin_orbit_coupling = soc,
            spin_ordering = spin_mode == 0 ? :scalar : :blocked,
            orbital_centers_cartesian = centers,
        )
        provenance = (
            format = "OpenMX",
            format_version = String(format_version),
            byte_order = byte_order,
            unit_convention = unit_convention,
            binary_version = binary_version,
            position_moment_order = moment_order,
            hartree_to_ev = hartree_to_ev,
            bohr_to_angstrom = bohr_to_angstrom,
            spin_mode = representation,
            openmx_spin_flag = spin_mode,
            magnetic_state = magnetic,
            spin_orbit_coupling = soc,
            spin_ordering = model.spin_ordering,
            explicit_state_multiplicity = 1,
            spatial_orbital_count = n,
            wannier_center_convention = String(wannier_center_convention),
            orbital_order = :persisted_atom_major,
            atom_labels = labels,
            orbital_counts = orbital_counts,
            fractional_atom_positions = fractional_positions,
            position_origin = position_source,
            admitted_operators = operator_scope == :hamiltonian_overlap_position ?
                                 (:hamiltonian, :overlap, :position) : (:hamiltonian, :overlap),
            raw_position_translation_defect_angstrom = raw_position_defect,
            position_operator_admitted = operator_scope == :hamiltonian_overlap_position,
            hamiltonian_partner_norm = :absolute_frobenius_ev,
            overlap_partner_norm = :absolute_frobenius_dimensionless,
            position_translation_norm = :absolute_max_entry_angstrom,
            hamiltonian_representation_tolerance_ev = model.hamiltonian_representation_tolerance_ev,
            overlap_representation_tolerance = model.overlap_representation_tolerance,
            position_translation_tolerance_angstrom = model.position_translation_tolerance_angstrom,
            chemical_potential_hartree = chemical_potential,
            electronic_temperature_record = electronic_temperature,
            electronic_temperature_record_unit = "UNINTERPRETED_UPSTREAM_E_TEMP",
            source_provenance_schema = "wanniernlqg.native-source-lifetime/2",
            file_identity = scientific_file_identity(source_identity),
        )
        isequal(scientific_file_state(filename), source_identity) ||
            throw(ArgumentError("LOCALIZED_INPUT_CHANGED_DURING_IMPORT"))
        return NonorthogonalLocalizedInput(
            model;
            copy_data = false,
            parameters = provenance,
            source_file = filename,
            wannier_center_convention,
        )
    end
end
