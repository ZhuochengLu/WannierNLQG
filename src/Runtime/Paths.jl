using SHA
using Printf

"""
Return the normalized package source directory relative to this Runtime file.
"""
unified_root() = normpath(joinpath(@__DIR__, ".."))
"""
Return the normalized current working directory used as the default case root.
"""
default_case_root() = normpath(pwd())
"""
Use the resolved case root itself as the default output parent.
"""
default_output_root(case_root::AbstractString) = case_root
"""
Return the default `inputs/GeS_tb.dat` path below a case root without checking its existence.
"""
default_model_file(case_root::AbstractString) = joinpath(case_root, "inputs", "GeS_tb.dat")

"""
Resolve a configured path or its default against `base`, preserving absolute paths and normalizing path components.

This helper does not require the target to exist.

Resolve path.
"""
function resolve_path(
    path::AbstractString,
    default_path::AbstractString;
    base::AbstractString = unified_root(),
)
    resolved = isempty(path) ? default_path : path
    return isabspath(resolved) ? normpath(resolved) : normpath(joinpath(base, resolved))
end

"""
Resolve an empty case root to the current directory and relative roots against the current directory; normalize the result.

Resolve case root.
"""
function resolve_case_root(path::AbstractString)
    return isempty(path) ? default_case_root() :
           (isabspath(path) ? normpath(path) : normpath(joinpath(pwd(), path)))
end

"""
Read a file and return its lowercase hexadecimal SHA-256; file access errors propagate.
"""
function checksum_file(path::AbstractString)
    return sha256_file(path)
end

"""
Join the validated run directory with the quantity/method-specific result filename.

Forward real/imaginary part and band labels to the filename validator; this helper does not write the file.
"""
function result_output_path(
    ctx::RunContext,
    quantity::Symbol,
    method::Symbol,
    calculation::Symbol;
    part::Union{Nothing, Symbol} = nothing,
    band::Union{Nothing, Int, Symbol, AbstractString} = nothing,
)
    return joinpath(
        ctx.run_dir,
        result_filename(ctx.system_name, quantity, method, calculation; part = part, band = band),
    )
end

"""
Return the legacy default system label `GeS` after checking that each requested task has a supported filename rule.
"""
function default_system_name(cfg::EffectiveTaskConfig, specs::Vector{NormalizedTaskSpec})
    for spec in specs
        if spec.calculation == :kslice
            if is_real_only_kslice_quantity(spec.quantity)
                result_filename("GeS", spec.quantity, spec.method, spec.calculation)
            else
                result_filename("GeS", spec.quantity, spec.method, spec.calculation; part = :r)
            end
        else
            result_filename("GeS", spec.quantity, spec.method, spec.calculation)
        end
    end
    return "GeS"
end

"""Resolve and validate declared file inputs without hashing or creating outputs.

Use this same resolution for run-scoped source observations and context setup so
relative paths, seed inputs and paired-bundle contracts cannot drift.
"""
function resolve_runtime_model_inputs(cfg::EffectiveTaskConfig, specs)
    case_root = resolve_case_root(cfg.case_root)
    bundle_file =
        if cfg.real_space_operator_bundle_file === nothing ||
           isempty(strip(something(cfg.real_space_operator_bundle_file, "")))
            nothing
        else
            configured = something(cfg.real_space_operator_bundle_file)
            isabspath(configured) ? normpath(configured) : normpath(joinpath(case_root, configured))
        end
    bundle_file === nothing ||
        isfile(bundle_file) ||
        error("Real-space operator bundle does not exist: $(bundle_file)")
    model_input_mode = bundle_file === nothing ? :legacy : :packed_hdf5
    if model_input_mode == :packed_hdf5
        cfg.spin_enabled &&
            error("HDF5 model input cannot be combined with EffectiveTaskConfig.spin_enabled=true.")
        isempty(strip(cfg.seedname)) ||
            error("HDF5 model input cannot be combined with EffectiveTaskConfig.seedname.")
        isempty(strip(cfg.spin_file)) ||
            error("HDF5 model input cannot be combined with EffectiveTaskConfig.spin_file.")
        isempty(strip(cfg.checkpoint_file)) ||
            error("HDF5 model input cannot be combined with EffectiveTaskConfig.checkpoint_file.")
        cfg.spin_file_formatted &&
            error("HDF5 model input cannot be combined with spin_file_formatted=true.")
    end
    needs_seed =
        model_input_mode == :legacy &&
        any(spec -> spec.quantity in (:injection_spin_current, :shift_spin_current), specs)
    seed_inputs = if needs_seed
        isempty(strip(cfg.seedname)) &&
            error("Spin-current responses require EffectiveTaskConfig.seedname.")
        seed_prefix =
            isabspath(cfg.seedname) ? normpath(cfg.seedname) :
            normpath(joinpath(case_root, cfg.seedname))
        SeedInputPaths(
            seed_prefix,
            seed_prefix * "_tb.dat",
            resolve_path(cfg.spin_file, seed_prefix * ".spn"; base = case_root),
            resolve_path(cfg.checkpoint_file, seed_prefix * ".chk"; base = case_root),
            seed_prefix * ".eig",
            seed_prefix * ".mmn",
        )
    else
        nothing
    end
    legacy_model_file = if seed_inputs === nothing
        resolve_path(cfg.model_file, default_model_file(case_root); base = case_root)
    else
        if !isempty(cfg.model_file)
            explicit_model = resolve_path(cfg.model_file, cfg.model_file; base = case_root)
            explicit_model == seed_inputs.model_file || error(
                "Spin-current responses use seed-derived model_file=$(seed_inputs.model_file); conflicting explicit model_file=$(explicit_model).",
            )
        end
        seed_inputs.model_file
    end
    # Packed H/r are authoritative; a redundant text path is not an input
    # identity dependency of the current model reader.
    paired_tb_validation_file = nothing
    model_file = model_input_mode == :packed_hdf5 ? something(bundle_file) : legacy_model_file
    if seed_inputs !== nothing
        required = Pair{String, String}[
            "tb" => seed_inputs.model_file,
            "spn" => seed_inputs.spin_file,
            "chk" => seed_inputs.checkpoint_file,
            "eig" => seed_inputs.eigenvalue_file,
            "mmn" => seed_inputs.overlap_file,
        ]
        missing = ["$(label): $(path)" for (label, path) in required if !isfile(path)]
        isempty(missing) || error(
            "Injection_Spin_Current seed inputs are incomplete. Missing files:\n  " *
            join(missing, "\n  "),
        )
    end
    if !isfile(model_file)
        error("Model input file does not exist: $(model_file)")
    end
    return (;
        case_root,
        bundle_file,
        model_input_mode,
        seed_inputs,
        model_file,
        paired_tb_validation_file,
    )
end

"""List scientific files observed across one ordinary run.

Native imports retain their separate collective admission. WSVEC is admitted by
its own decoded replica-policy boundary; undeclared outputs are not enrolled.
No numerical contents are read by this path inventory.
"""
function runtime_input_source_paths(cfg::EffectiveTaskConfig, specs)
    # Native declarations are observed in setup and adopted by their schema2 reader.
    cfg.native_model_input === nothing || return String[]
    paths = if cfg.native_model_input === nothing
        resolved = resolve_runtime_model_inputs(cfg, specs)
        result = String[resolved.model_file]
        resolved.paired_tb_validation_file === nothing ||
            push!(result, resolved.paired_tb_validation_file)
        if resolved.seed_inputs !== nothing
            seed = resolved.seed_inputs
            append!(
                result,
                (seed.spin_file, seed.checkpoint_file, seed.eigenvalue_file, seed.overlap_file),
            )
        elseif cfg.spin_enabled
            case_root = resolved.case_root
            for configured in (cfg.spin_file, cfg.checkpoint_file)
                isempty(configured) ||
                    push!(result, resolve_path(configured, configured; base = case_root))
            end
        end
        result
    else
        # Native source files use their observed import lifetime in the native
        # collective preflight; do not enroll them in ordinary file observation.
        String[]
    end
    for configured in (cfg.response_symmetry_file,)
        configured === nothing && continue
        isempty(strip(configured)) && continue
        push!(paths, resolve_path(configured, configured; base = resolve_case_root(cfg.case_root)))
    end
    return unique(paths)
end

"""
Prepare run context.
"""
function prepare_run_context(cfg::EffectiveTaskConfig, specs::Vector{NormalizedTaskSpec})
    cfg.native_model_input === nothing || return prepare_native_run_context(cfg, specs)
    comm = bundle_mpi_comm_world()
    (;
        case_root,
        bundle_file,
        model_input_mode,
        seed_inputs,
        model_file,
        paired_tb_validation_file,
    ) = resolve_runtime_model_inputs(cfg, specs)
    demand = operator_demand_plan(specs, cfg)
    model_input_mode == :legacy &&
        demand.requires_full_projector_geometry &&
        error(
            "FULL_DERIVATIVE_OVERLAP_REQUIRED: this geometry task requires " *
            "a schema-6 Packed HDF5 bundle generated from a full .uIu source",
        )
    num_orbitals = if model_input_mode == :packed_hdf5
        manifest = bundle_mpi_root_call(
            () -> read_real_space_operator_bundle_manifest(model_file);
            comm,
        )
        validate_operator_demand(manifest, demand)
        # Current HDF5 contains the actual H/r payload used below. A redundant
        # text path supplies no additional data and requires no identity scan.
        manifest.num_orbitals
    else
        bundle_mpi_root_call(() -> read_wannier_tb_num_orbitals(model_file); comm)
    end
    model_identity = bundle_mpi_root_call(
        () -> scientific_file_identity(observe_scientific_source(realpath(model_file)));
        comm,
    )

    run_dir = resolve_path(cfg.output_root, default_output_root(case_root); base = case_root)

    if mpi_is_root_process()
        mkpath(run_dir)
    end

    system_name = isnothing(cfg.system_name) ? default_system_name(cfg, specs) : cfg.system_name
    metadata_path = joinpath(run_dir, "metadata.txt")
    progress_out_path = cfg.progress_enabled ? joinpath(run_dir, "WannierNLQG.out") : ""
    progress_jsonl_path = cfg.progress_enabled ? joinpath(run_dir, "progress.jsonl") : ""

    return RunContext(
        specs,
        run_dir,
        model_file,
        model_identity,
        model_input_mode,
        bundle_file,
        paired_tb_validation_file,
        num_orbitals,
        demand,
        system_name,
        metadata_path,
        progress_out_path,
        progress_jsonl_path,
        seed_inputs,
        nothing,
    )
end

"""
Convert a metadata value to display text; string vectors use a bracketed comma-separated representation.
"""
metadata_value(value) = string(value)
"""
Convert a metadata value to display text; string vectors use a bracketed comma-separated representation.
"""
metadata_value(value::Symbol) = string(value)
"""
Convert a metadata value to display text; string vectors use a bracketed comma-separated representation.
"""
metadata_value(values::AbstractVector{String}) = "[" * join(values, ", ") * "]"

# Display-only tuple adapter. Keep immutable support records and their ownership
# intact while avoiding one compiled Base.show tree per material-sized NTuple.
struct MetadataSupportTupleDisplay
    values::Tuple
end

# Count immutable support entries without materializing another container.
Base.length(values::MetadataSupportTupleDisplay) = nfields(values.values)
# Yield the borrowed tuple field and its next index without copying support values.
function Base.iterate(values::MetadataSupportTupleDisplay, index::Int = 1)
    index > nfields(values.values) && return nothing
    return (getfield(values.values, index), index + 1)
end
# Preserve Base tuple punctuation and element display for the borrowed support fields.
function Base.show(io::Base.IO, values::MetadataSupportTupleDisplay)
    return Base.show_delim_array(io, values, '(', ',', ')', true)
end

# Preserve canonical support text while bounding tuple-length display specialization.
Base.@nospecializeinfer @noinline function metadata_value(
    @nospecialize(value::NamedTuple{(:schema, :num_orbitals, :r_vectors, :scalar_degeneracies)}),
)
    # Base.show prints an explicit type for abstract declared field types.
    # Preserve that fallback instead of wrapping a superficially similar record.
    for index in 1:nfields(value)
        typeof(getfield(value, index)) === fieldtype(typeof(value), index) || return string(value)
    end
    r_vectors = value.r_vectors
    degeneracies = value.scalar_degeneracies
    if value.schema isa String &&
       value.num_orbitals isa Int &&
       r_vectors isa Tuple{Vararg{NTuple{3, Int}}} &&
       degeneracies isa Tuple{Vararg{Int}}
        return string((
            schema = value.schema,
            num_orbitals = value.num_orbitals,
            r_vectors = MetadataSupportTupleDisplay(r_vectors),
            scalar_degeneracies = MetadataSupportTupleDisplay(degeneracies),
        ))
    end
    return string(value)
end

"""
Write an aligned titled key/value section to the supplied stream, indenting multiline values.

Preserve entry order and return nothing; this helper performs no metadata computation.
"""
function metadata_section(io, title::AbstractString, entries::Vector{Pair{String, String}})
    println(io, "[$(title)]")
    width = maximum(length(entry.first) for entry in entries; init = 0)
    for entry in entries
        key = entry.first
        value = entry.second
        padded = rpad(key, width)
        if occursin('\n', value)
            println(io, padded, " =")
            for line in split(value, '\n'; keepempty = true)
                println(io, "    ", line)
            end
        else
            println(io, padded, " = ", value)
        end
    end
    println(io)
    return nothing
end

"""
Format photon energies into fixed-width rows with the requested column count, or `(empty)` when absent.
"""
function metadata_photon_energy_values(photon_energies::Vector{Float64}; columns::Int = 6)
    isempty(photon_energies) && return "(empty)"
    lines = String[]
    for start in 1:columns:length(photon_energies)
        stop = min(start + columns - 1, length(photon_energies))
        push!(lines, join([@sprintf("%18.12f", photon_energies[idx]) for idx in start:stop], ""))
    end
    return join(lines, "\n")
end

"""
Display paths inside the base directory relatively and retain the supplied path for external locations.
"""
function metadata_display_path(path::AbstractString, base::AbstractString)
    isempty(path) && return ""
    abs_path = abspath(path)
    abs_base = abspath(base)
    rel = try
        relpath(abs_path, abs_base)
    catch
        String(path)
    end
    return startswith(rel, "..") ? String(path) : (isempty(rel) ? "." : rel)
end

"""
Return ordered numerical-control metadata fields for the validated band or response run.

Values reflect the effective configuration and input mode; no numerical results are recomputed.
"""
function metadata_numerics_entries(cfg::EffectiveTaskConfig, ctx::RunContext)
    definition =
        task_definition(ctx.specs[1].quantity, ctx.specs[1].method, ctx.specs[1].calculation)
    if definition !== nothing && _is_band_structure(definition)
        return Pair{String, String}[
            "fourier_backend" => cfg.fourier_backend,
            "energy_reference_E_ref_eV" => metadata_value(cfg.fermi_energy),
            "kpath_nodes" => metadata_value(cfg.kpath_nodes),
            "kpoints_per_segment" => metadata_value(cfg.kpoints_per_segment),
            "kpath_branches" => metadata_value([
                [first(range), last(range)] for range in cfg.kpath_branches
            ]),
            "kpath_provenance" => metadata_value(cfg.kpath_provenance),
            "real_space_replica_policy" => cfg.real_space_replica_policy,
            "wsvec_file" => metadata_value(cfg.wsvec_file),
            "mp_grid" => metadata_value(cfg.mp_grid),
            "wigner_seitz_tolerance" => metadata_value(cfg.wigner_seitz_tolerance),
            "wigner_seitz_search_size" => metadata_value(cfg.wigner_seitz_search_size),
            "band_hermiticity_tolerance" => metadata_value(cfg.band_hermiticity_tolerance),
            "fractional_coordinates_folded" => "false",
            "segment_endpoint_convention" => "counts include both endpoints; shared endpoint written once",
        ]
    end
    entries = Pair{String, String}[
        "k_mesh" => metadata_value(cfg.k_mesh),
        "fourier_backend" => metadata_value(cfg.fourier_backend),
        "real_space_replica_policy" => cfg.real_space_replica_policy,
        "wsvec_file" => metadata_value(cfg.wsvec_file),
        "mp_grid" => metadata_value(cfg.mp_grid),
        "wigner_seitz_tolerance" => metadata_value(cfg.wigner_seitz_tolerance),
        "wigner_seitz_search_size" => metadata_value(cfg.wigner_seitz_search_size),
        "NKdiv" => metadata_value(cfg.NKdiv),
        "NKFFT" => metadata_value(cfg.NKFFT),
        "fermi_energy" => metadata_value(cfg.fermi_energy),
        "temperature" => metadata_value(cfg.temperature),
        "broadening" => metadata_value(cfg.broadening),
        "broadening_type" => cfg.broadening_type,
        "transition_window_factor" => metadata_value(cfg.transition_window_factor),
        "denominator_regularization" => metadata_value(cfg.denominator_regularization),
        "denominator_regularization_source" => (cfg.denominator_regularization_was_explicit ?
                                                "USER" : "DEFAULT"),
        "include_external" => string(cfg.include_external),
        "spatial_dimension" => metadata_value(cfg.spatial_dimension),
        "band_window_size" => metadata_value(cfg.band_window_size),
        "response_output_digits" => metadata_value(
            let
                values = [
                    resolved_response_output_digits(cfg, response_output_family_default(spec))
                    for spec in ctx.specs
                ]
                length(unique(values)) == 1 ? first(values) :
                Dict(spec.label => digits for (spec, digits) in zip(ctx.specs, values))
            end,
        ),
        "response_output_digits_requested" => metadata_value(cfg.response_output_digits),
        "response_symmetry_report_enabled" => metadata_value(cfg.response_symmetry_report_enabled),
        "tensor_indices" => metadata_value(cfg.tensor_indices),
        "band_selection" => metadata_value(cfg.band_selection),
    ]
    if any(
        spec->spec.quantity in
              (:linear_transport, :linear_optical_response, :orbital_magnetization),
        ctx.specs,
    )
        filter!(
            entry->!(
                first(entry) in (
                    "broadening",
                    "broadening_type",
                    "transition_window_factor",
                    "denominator_regularization",
                    "band_window_size",
                )
            ),
            entries,
        )
        append!(
            entries,
            [
                "spectral_gap_tolerance_ev"=>(
                    all(s -> s.quantity==:orbital_magnetization, ctx.specs) ? "NOT_APPLICABLE" :
                    string(cfg.spectral_gap_tolerance)
                ),
                "response_semantics"=>"see spectral_response_metadata.txt",
            ],
        )
        if any(spec -> spec.quantity in (:linear_transport, :orbital_magnetization), ctx.specs)
            filter!(entry -> first(entry) != "fermi_energy", entries)
            append!(
                entries,
                [
                    "fermi_energies" => metadata_value(cfg.fermi_energies),
                    "fermi_energies_definition" => cfg.fermi_energies_definition,
                ],
            )
        end
    end
    if any(spec -> spec.quantity == :second_harmonic_generation, ctx.specs)
        append!(
            entries,
            Pair{String, String}[
                "shg_low_frequency_broadening" => metadata_value(cfg.shg_low_frequency_broadening),
                "shg_intermediate_regularization" => metadata_value(
                    cfg.shg_intermediate_regularization,
                ),
                "shg_eta_correction" => metadata_value(cfg.shg_eta_correction),
                "shg_geometry_prescription" => cfg.native_model_input isa NonorthogonalLocalizedInput ?
                                               "metric_optical_r0_r_eta_Gcut; eta_g=denominator_regularization; eta_sum=intermediate_regularization; retained_metric_BCD_and_Hessian" :
                                               "orthogonal_existing",
                "shg_output" => string(cfg.shg_output),
                "shg_response" => string(cfg.shg_response),
                "shg_zero_temperature_policy" => "temperature <= 1e-7 K: step occupations; omit one-band terms",
                "shg_state_multiplicity" => "one electron per explicit model state",
                "shg_kslice_definition" => "BZ-integrated-form density; no k weight; full-BZ mean recovers integral",
            ],
        )
    end
    if cfg.response_symmetry_file !== nothing
        push!(entries, "response_symmetry_file" => metadata_value(cfg.response_symmetry_file))
        push!(entries, "response_symmetry_policy" => metadata_value(cfg.response_symmetry_policy))
        push!(
            entries,
            "response_symmetry_kmesh_mode" => metadata_value(cfg.response_symmetry_kmesh_mode),
        )
    end
    if any(spec -> spec.quantity == :injection_spin_current, ctx.specs)
        push!(entries, "injection_spin_current.tensor_indices" => "(a,s,b,c)")
        push!(
            entries,
            "injection_spin_current.axis_sizes" => metadata_value((
                cfg.spatial_dimension,
                3,
                cfg.spatial_dimension,
                cfg.spatial_dimension,
            )),
        )
        push!(entries, "injection_spin_current.spin_axis" => "s=1,2,3 (x,y,z)")
        push!(entries, "injection_spin_current.operator" => "J^(a,s)=0.5*{v^a,S^s}")
        push!(entries, "injection_spin_current.kernel" => "(J_mm^(a,s)-J_nn^(a,s))*A_nm^c*A_mn^b")
        push!(entries, "injection_spin_current.prefactor" => "+pi*e^2/(hbar^2*N_k*V)")
        push!(entries, "injection_spin_current.identity_spin_relation" => "(-e)*ISC[S=I]=IC")
    end
    if any(spec -> spec.quantity == :shift_spin_current, ctx.specs)
        push!(entries, "shift_spin_current.tensor_indices" => "(a,s,b,c)")
        push!(
            entries,
            "shift_spin_current.axis_sizes" => metadata_value((
                cfg.spatial_dimension,
                3,
                cfg.spatial_dimension,
                cfg.spatial_dimension,
            )),
        )
        push!(entries, "shift_spin_current.spin_operator" => "Pauli; eigenvalues +/-1")
        push!(entries, "shift_spin_current.one_photon_vertex" => "Qiao interpolated J_sigma")
        push!(entries, "shift_spin_current.prefactor" => "+i*hbar_eVs*pi*e^2/(2*hbar_Js^2*N_k*V)")
        push!(
            entries,
            "shift_spin_current.denominator_regularization" =>
                metadata_value(cfg.denominator_regularization),
        )
        push!(
            entries,
            "shift_spin_current.energy_weight" => "Delta_nm^2/(Delta_nm^2+sc_eta^2)^2; Delta_nm=epsilon_n-epsilon_m",
        )
        push!(
            entries,
            "shift_spin_current.identity_spin_relation" => "(-e)*SSC[S=I](a,b,c)=SC(a,b,c) (nondegenerate resonant eta->0)",
        )
        push!(entries, "shift_spin_current.finite_window" => "Wannier effective-theory window")
    end
    if any(spec -> spec.quantity == :berry_curvature, ctx.specs)
        num_orbitals = ctx.num_orbitals
        berry_groups = normalize_berry_band_selection(cfg.band_selection, num_orbitals)
        berry_outputs = String[
            result_filename(
                ctx.system_name,
                :berry_curvature,
                :conventional,
                :kslice;
                band = band_group_output_label(group),
            ) for group in berry_groups
        ]
        if cfg.include_occupied_sum &&
           (isempty(berry_groups) || real_kslice_band_groups_include_sum(berry_groups))
            push!(
                berry_outputs,
                result_filename(
                    ctx.system_name,
                    :berry_curvature,
                    :conventional,
                    :kslice;
                    band = :sum,
                ),
            )
        end
        push!(entries, "berry_band_selection_expanded" => metadata_value(berry_groups))
        push!(entries, "berry_outputs" => metadata_value(berry_outputs))
    end
    if any(spec -> spec.quantity == :hermitian_curvature_tensor, ctx.specs)
        num_orbitals = ctx.num_orbitals
        hct_band_selection = validate_interband_band_selection(cfg.band_selection, num_orbitals)
        push!(entries, "hermitian_curvature_tensor.tensor_indices" => "(b,a,d,c)")
        push!(
            entries,
            "hermitian_curvature_tensor.band_selection_expanded" =>
                metadata_value(hct_band_selection),
        )
        push!(
            entries,
            "hermitian_curvature_tensor.trace_normalization" => "ordinary trace; no dimension average",
        )
        push!(
            entries,
            "hermitian_curvature_tensor_output_r" => result_filename(
                ctx.system_name,
                :hermitian_curvature_tensor,
                :conventional,
                :kslice;
                part = :r,
            ),
        )
        push!(
            entries,
            "hermitian_curvature_tensor_output_i" => result_filename(
                ctx.system_name,
                :hermitian_curvature_tensor,
                :conventional,
                :kslice;
                part = :i,
            ),
        )
    end
    spectral_quantities = (:linear_transport, :linear_optical_response, :orbital_magnetization)
    if any(spec -> spec.quantity in spectral_quantities, ctx.specs)
        push!(entries, "spectral_position_contract" => "common_regularized_r_eta")
        push!(
            entries,
            "spectral_position_regularization_ev" => string(cfg.denominator_regularization),
        )
        if any(
            spec -> spec.quantity == :orbital_magnetization && spec.method == :projector,
            ctx.specs,
        )
            push!(
                entries,
                "orbital_projector_derivative_contract" => "exact_full_velocity_over_physical_gap",
            )
        end
    end
    if any(
        spec ->
            !(spec.quantity in spectral_quantities) &&
            spec.method in (:wilson_loop, :geometric_loop),
        ctx.specs,
    )
        push!(entries, "position_vertex_contract" => "bare_r0_A_plus_i_h_I0")
        push!(entries, "position_bare_inverse_cutoff_ev" => "1e-7")
        push!(entries, "position_bare_regularization_ev" => "not_applicable")
    end
    if any(spec -> !(spec.quantity in spectral_quantities) && spec.method == :projector, ctx.specs)
        push!(
            entries,
            "projector_derivative_contract" => "covariant_finite_difference_of_projectors",
        )
    end
    if any(
        spec ->
            spec.quantity in ZERO_REGULARIZATION_GEOMETRY_QUANTITIES ||
            spec.quantity in BERRY_MULTIPOLE_QUANTITIES,
        ctx.specs,
    )
        has_derivative =
            any(spec -> spec.quantity in FINITE_DIFFERENCE_GEOMETRY_QUANTITIES, ctx.specs) ||
            (cfg.berry_multipole !== nothing && cfg.berry_multipole.local_derivative_order > 0)
        route = has_derivative ? string(cfg.derivative_backend) : "static_geometry"
        reason =
            !has_derivative ? "no outer geometric derivative" :
            cfg.derivative_backend_was_explicit ? "explicit applicable backend" :
            cfg.denominator_regularization > 0 ?
            "supplied positive width selects regularized finite differences" :
            "zero width with the supported task default backend"
        push!(entries, "geometry_derivative_route"=>route)
        push!(entries, "geometry_derivative_route_reason"=>reason)
        push!(entries, "geometry_zero_gap_threshold_ev"=>string(cfg.spectral_gap_tolerance))
        push!(
            entries,
            "geometry_zero_domain"=>"full eigenframe isolated at every consumed point; no implicit degenerate-band assignment",
        )
    end
    if any(
        spec -> spec.quantity in (
            :quantum_metric,
            :quantum_metric_dipole,
            :quantum_metric_quadrupole,
            :quantum_christoffel_symbol,
        ),
        ctx.specs,
    )
        push!(
            entries,
            "metric_contributions" =>
                (cfg.include_external ? "total,internal,external" : "internal"),
        )
        push!(
            entries,
            "metric_overlap_requirement" =>
                (cfg.include_external ? "full_derivative_overlap" : "not_required"),
        )
        push!(
            entries,
            "metric_geometry_contract" =>
                (cfg.denominator_regularization == 0 ? "unregularized" : "regularized"),
        )
        push!(
            entries,
            "metric_denominator_regularization_ev" => string(cfg.denominator_regularization),
        )
        push!(entries, "metric_derivative_step" => string(cfg.finite_difference_step))
        push!(
            entries,
            "metric_component_filename_rule" => (
                cfg.include_external ?
                "insert _internal or _external before extension; primary is total" :
                "primary is internal; no external file"
            ),
        )
    end
    if any(spec -> spec.quantity == :quantum_metric, ctx.specs)
        num_orbitals = ctx.num_orbitals
        metric_groups = normalize_quantum_metric_band_selection(cfg.band_selection, num_orbitals)
        metric_outputs = String[
            result_filename(
                ctx.system_name,
                :quantum_metric,
                :conventional,
                :kslice;
                band = band_group_output_label(group),
            ) for group in metric_groups
        ]
        if cfg.include_occupied_sum &&
           (isempty(metric_groups) || real_kslice_band_groups_include_sum(metric_groups))
            push!(
                metric_outputs,
                result_filename(
                    ctx.system_name,
                    :quantum_metric,
                    :conventional,
                    :kslice;
                    band = :sum,
                ),
            )
        end
        push!(entries, "quantum_metric_band_selection_expanded" => metadata_value(metric_groups))
        push!(entries, "quantum_metric_outputs" => metadata_value(metric_outputs))
    end
    if any(spec -> spec.quantity == :berry_curvature_dipole, ctx.specs)
        num_orbitals = ctx.num_orbitals
        bcd_band_groups =
            validate_berry_curvature_dipole_band_selection(cfg.band_selection, num_orbitals)
        bcd_outputs = String[
            result_filename(
                ctx.system_name,
                :berry_curvature_dipole,
                :conventional,
                :kslice;
                band = band_group_output_label(group),
            ) for group in bcd_band_groups
        ]
        push!(
            entries,
            "berry_curvature_dipole_band_selection_expanded" => metadata_value(bcd_band_groups),
        )
        push!(entries, "berry_curvature_dipole_outputs" => metadata_value(bcd_outputs))
    end
    if any(spec -> spec.quantity == :berry_curvature_quadrupole, ctx.specs)
        num_orbitals = ctx.num_orbitals
        bcq_band_groups =
            validate_berry_curvature_quadrupole_band_selection(cfg.band_selection, num_orbitals)
        bcq_outputs = String[
            result_filename(
                ctx.system_name,
                :berry_curvature_quadrupole,
                :conventional,
                :kslice;
                band = band_group_output_label(group),
            ) for group in bcq_band_groups
        ]
        push!(
            entries,
            "berry_curvature_quadrupole_band_selection_expanded" => metadata_value(bcq_band_groups),
        )
        push!(entries, "berry_curvature_quadrupole_outputs" => metadata_value(bcq_outputs))
    end
    if any(spec -> is_interband_quantum_geometry_quantity(spec.quantity), ctx.specs)
        num_orbitals = ctx.num_orbitals
        interband_band_selection =
            validate_interband_band_selection(cfg.band_selection, num_orbitals)
        push!(
            entries,
            "interband_band_selection_expanded" => metadata_value(interband_band_selection),
        )
    end
    if any(spec -> spec.quantity == :shift_vector, ctx.specs)
        num_orbitals = ctx.num_orbitals
        shift_vector_band_selection =
            validate_interband_band_selection(cfg.band_selection, num_orbitals)
        push!(
            entries,
            "shift_vector_band_selection_expanded" => metadata_value(shift_vector_band_selection),
        )
    end
    if any(spec -> spec.quantity == :triple_phase_product, ctx.specs)
        num_orbitals = ctx.num_orbitals
        tpp_band_selection =
            validate_triple_phase_product_band_selection(cfg.band_selection, num_orbitals)
        push!(
            entries,
            "triple_phase_product_band_selection_expanded" => metadata_value(tpp_band_selection),
        )
        push!(
            entries,
            "triple_phase_product_output_r" => result_filename(
                ctx.system_name,
                :triple_phase_product,
                :conventional,
                :kslice;
                part = :r,
            ),
        )
        push!(
            entries,
            "triple_phase_product_output_i" => result_filename(
                ctx.system_name,
                :triple_phase_product,
                :conventional,
                :kslice;
                part = :i,
            ),
        )
    end
    if any(spec -> spec.quantity == :interband_berry_curvature, ctx.specs)
        push!(
            entries,
            "interband_berry_curvature_output" => result_filename(
                ctx.system_name,
                :interband_berry_curvature,
                :conventional,
                :kslice,
            ),
        )
    end
    if any(spec -> spec.quantity == :interband_quantum_metric, ctx.specs)
        push!(
            entries,
            "interband_quantum_metric_output" =>
                result_filename(ctx.system_name, :interband_quantum_metric, :conventional, :kslice),
        )
    end
    if any(spec -> spec.quantity == :zeeman_interband_berry_curvature, ctx.specs)
        push!(entries, "zeeman_interband_berry_curvature.tensor_indices" => "(alpha,beta)")
        push!(entries, "zeeman_interband_berry_curvature.spin_axis" => "beta=1,2,3 (x,y,z)")
        push!(
            entries,
            "zeeman_interband_berry_curvature.spin_normalization" => "SPN matrix as read",
        )
        push!(
            entries,
            "zeeman_interband_berry_curvature_output" => result_filename(
                ctx.system_name,
                :zeeman_interband_berry_curvature,
                :conventional,
                :kslice,
            ),
        )
    end
    if any(spec -> spec.quantity == :zeeman_interband_quantum_metric, ctx.specs)
        push!(entries, "zeeman_interband_quantum_metric.tensor_indices" => "(alpha,beta)")
        push!(entries, "zeeman_interband_quantum_metric.spin_axis" => "beta=1,2,3 (x,y,z)")
        push!(entries, "zeeman_interband_quantum_metric.spin_normalization" => "SPN matrix as read")
        push!(
            entries,
            "zeeman_interband_quantum_metric_output" => result_filename(
                ctx.system_name,
                :zeeman_interband_quantum_metric,
                :conventional,
                :kslice,
            ),
        )
    end
    if any(spec -> spec.quantity == :quantum_metric_dipole, ctx.specs)
        num_orbitals = ctx.num_orbitals
        qmd_band_groups =
            validate_quantum_metric_dipole_band_selection(cfg.band_selection, num_orbitals)
        qmd_outputs = String[
            result_filename(
                ctx.system_name,
                :quantum_metric_dipole,
                :conventional,
                :kslice;
                band = band_group_output_label(group),
            ) for group in qmd_band_groups
        ]
        push!(
            entries,
            "quantum_metric_dipole_band_selection_expanded" => metadata_value(qmd_band_groups),
        )
        push!(entries, "quantum_metric_dipole_outputs" => metadata_value(qmd_outputs))
    end
    if any(spec -> spec.quantity == :quantum_metric_quadrupole, ctx.specs)
        num_orbitals = ctx.num_orbitals
        qmq_band_groups =
            validate_quantum_metric_quadrupole_band_selection(cfg.band_selection, num_orbitals)
        qmq_outputs = String[
            result_filename(
                ctx.system_name,
                :quantum_metric_quadrupole,
                :conventional,
                :kslice;
                band = band_group_output_label(group),
            ) for group in qmq_band_groups
        ]
        push!(
            entries,
            "quantum_metric_quadrupole_band_selection_expanded" => metadata_value(qmq_band_groups),
        )
        push!(entries, "quantum_metric_quadrupole_outputs" => metadata_value(qmq_outputs))
    end
    if any(spec -> spec.quantity == :quantum_christoffel_symbol, ctx.specs)
        num_orbitals = ctx.num_orbitals
        qcs_band_groups =
            validate_quantum_christoffel_band_selection(cfg.band_selection, num_orbitals)
        qcs_outputs = String[
            result_filename(
                ctx.system_name,
                :quantum_christoffel_symbol,
                :conventional,
                :kslice;
                band = band_group_output_label(group),
            ) for group in qcs_band_groups
        ]
        push!(
            entries,
            "quantum_christoffel_band_selection_expanded" => metadata_value(qcs_band_groups),
        )
        push!(entries, "quantum_christoffel_outputs" => metadata_value(qcs_outputs))
    end
    for spec in ctx.specs
        if spec.quantity == :shift_vector
            push!(
                entries,
                "shift_vector_output_r_$(canonical_method_name(spec.method))" => result_filename(
                    ctx.system_name,
                    :shift_vector,
                    spec.method,
                    :kslice;
                    part = :r,
                ),
            )
            push!(
                entries,
                "shift_vector_output_i_$(canonical_method_name(spec.method))" => result_filename(
                    ctx.system_name,
                    :shift_vector,
                    spec.method,
                    :kslice;
                    part = :i,
                ),
            )
        end
    end
    if any(
        spec -> spec.quantity in (:berry_curvature_dipole, :berry_curvature_quadrupole),
        ctx.specs,
    )
        push!(
            entries,
            "derivative_backend_requested" => (
                cfg.derivative_backend_was_explicit ? string(cfg.derivative_backend) :
                "not specified"
            ),
        )
        push!(entries, "derivative_backend_effective" => string(cfg.derivative_backend))
        if cfg.derivative_backend == :analytic
            maximum_order =
                any(spec -> spec.quantity == :berry_curvature_quadrupole, ctx.specs) ? 3 : 2
            input = cfg.native_model_input
            for order in 1:maximum_order
                h_source =
                    input isa AnalyticKInput ?
                    MatrixElements.geometry_hamiltonian_derivative_source(input, order) :
                    :direct_fourier
                a_source =
                    input isa AnalyticKInput ?
                    MatrixElements.geometry_position_derivative_source(input, order) :
                    :direct_fourier
                push!(entries, "analytic_H_derivative_source_order_$order" => string(h_source))
                push!(entries, "analytic_A_derivative_source_order_$order" => string(a_source))
            end
            push!(
                entries,
                "analytic_geometry_scope" => "orthogonal smooth isolated-band eigenframe; zero denominator regularization; complete intermediate-band sums",
            )
        end
    end
    append!(
        entries,
        Pair{String, String}[
            "kslice_origin" => metadata_value(cfg.kslice_origin),
            "kslice_vector_1" => metadata_value(cfg.kslice_vector_1),
            "kslice_vector_2" => metadata_value(cfg.kslice_vector_2),
            "photon_momentum" => cfg.photon_momentum_path === nothing ?
                                 metadata_value(cfg.photon_momentum) : "PAIRED_CARTESIAN_AXIS",
            "finite_difference_step" => cfg.derivative_backend == :analytic ?
                                        "not applicable (analytic derivative backend)" :
                                        cfg.derivative_backend == :not_applicable ?
                                        "not applicable (no response derivative)" :
                                        metadata_value(cfg.finite_difference_step),
            "wannier_center_convention_requested" => cfg.wannier_center_convention,
            "wannier_center_convention_resolved" => wannier_center_convention_name(
                normalize_wannier_center_convention(cfg.wannier_center_convention),
            ),
            "projector_algorithm" => "Native",
            "projector_common_source_transport" => "false",
            "geometric_loop_algorithm" => "BlockProjectedSubspaceCovariantSplit",
            "geometric_loop_link_definition" => "U_left_dagger_B_frame_U_right",
            "geometric_loop_frame_connector" => "Convention_I_identity_Convention_II_Dleft_Dright_dagger",
            "geometric_loop_derivative_definition" => "block_transported_partial_minus_i_aVV_JVC_plus_i_JVC_aCC",
            "geometric_loop_external_connection" => "SourceBerryPlusIHsourceNAligned",
            "geometric_loop_transport_scope" => "central_degeneracy_block_endpoints",
            "geometric_loop_connection_scope" => "central_valence_and_conduction_blocks_only",
            "geometric_loop_cache_key" => "valence_group_start_conduction_group_start_derivative_axis_insertion_direction",
            "geometric_loop_q0_wilson_reference" => "CovariantWilson_SubspaceCovariantSplit",
            "geometric_loop_shift_vector_algorithm" => "CovariantLogLoop",
            "geometric_loop_polar_normalization" => "false",
            "wilson_derivative_algorithm" => "SubspaceCovariantSplit",
            "wilson_derivative_definition" => "transported_partial_minus_i_AintV_X_plus_i_X_AintC",
            "wilson_loop_link_definition" => "U_left_dagger_B_frame_U_right",
            "wilson_frame_connector" => "Convention_I_identity_Convention_II_Dleft_Dright_dagger",
            "wilson_polar_normalization" => "false",
            "wilson_shift_vector_algorithm" => "CovariantLogLoop",
            "external_terms_enabled" => "true",
            "degeneracy_threshold" => metadata_value(cfg.degeneracy_threshold),
        ],
    )
    if any(spec -> spec.quantity == :jerk_current, ctx.specs)
        push!(entries, "jerk_current.occupation_policy" => "core-fermi-dirac/1")
        push!(entries, "jerk_current.zero_thermal_energy_occupation" => "E<=mu:1;E>mu:0")
    end
    if all(spec -> spec.quantity == :intrinsic_ahc, ctx.specs)
        filter!(entry -> first(entry) != "degeneracy_threshold", entries)
    end
    if all(spec -> spec.quantity in (:jerk_current, :third_harmonic_generation), ctx.specs)
        filter!(entry -> first(entry) != "degeneracy_threshold", entries)
    end
    if any(spec -> spec.quantity in (:shift_spin_current, :injection_spin_current), ctx.specs)
        push!(entries, "spin_current.connection_prescription" => "positive_eta_smooth_D")
        push!(
            entries,
            "spin_current.compensation" => "eta_squared_over_gap_squared_plus_eta_squared",
        )
        push!(
            entries,
            "spin_current.regularization_ev" => metadata_value(cfg.denominator_regularization),
        )
        push!(entries, "spin_current.degeneracy_threshold" => "not applicable")
        all(spec -> spec.quantity in (:shift_spin_current, :injection_spin_current), ctx.specs) &&
            filter!(entry -> first(entry) != "degeneracy_threshold", entries)
    end
    if cfg.photon_momentum_path !== nothing
        append!(
            entries,
            Pair{String, String}[
                "photon_momentum_pairing" => "zip; original row order",
                "photon_momenta_A_inverse" => metadata_value(
                    cfg.photon_momentum_path.photon_momenta,
                ),
                "photon_momentum_grouping" => "exact isequal, signed zeros distinct",
            ],
        )
    end
    return entries
end

# Render one cold summary through the existing value formatter, preserving key order.
Base.@nospecializeinfer Base.@noinline function metadata_summary_entries(
    @nospecialize(summary::NamedTuple),
)
    entries = Pair{String, String}[]
    for key in keys(summary)
        push!(entries, string(key) => metadata_value(getproperty(summary, key)))
    end
    return entries
end

"""
Write the completed run's configuration, model identity, output paths and execution summaries to the context metadata file.

Preserve stable section ordering and return the file path; numerical/physics qualification is reported from supplied evidence, not inferred here.
"""
function write_metadata(
    cfg::EffectiveTaskConfig,
    ctx::RunContext,
    outputs::Vector{String},
    execution_mode::AbstractString = "fused_kloop";
    matrix_families::Vector{String} = String[],
    family_counts::Vector{<:Any} = Any[],
    fourier_summary::NamedTuple = NamedTuple(),
    response_symmetry_summary::NamedTuple = NamedTuple(),
    band_summary::NamedTuple = NamedTuple(),
    replica_summary::NamedTuple = NamedTuple(),
    qualification_summary::NamedTuple = NamedTuple(),
    metadata_centers::Union{Nothing, Matrix{Float64}} = nothing,
    model_geometry::NamedTuple = NamedTuple(),
)
    # Private per-call holders retain the same values without specializing the large
    # writer/open callback on material-sized payload types. They never escape.
    metadata_summaries = (
        qualification_summary = Ref{NamedTuple}(qualification_summary),
        replica_summary = Ref{NamedTuple}(replica_summary),
        fourier_summary = Ref{NamedTuple}(fourier_summary),
        response_symmetry_summary = Ref{NamedTuple}(response_symmetry_summary),
        band_summary = Ref{NamedTuple}(band_summary),
    )
    return _write_metadata(
        cfg,
        ctx,
        outputs,
        execution_mode;
        matrix_families,
        family_counts,
        metadata_summaries,
        metadata_centers,
        model_geometry,
    )
end

# Emit ordinary metadata using fixed summary holders; formatting stays at each section.
function _write_metadata(
    cfg::EffectiveTaskConfig,
    ctx::RunContext,
    outputs::Vector{String},
    execution_mode::AbstractString = "fused_kloop";
    matrix_families::Vector{String} = String[],
    family_counts::Vector{<:Any} = Any[],
    metadata_summaries::NamedTuple,
    metadata_centers::Union{Nothing, Matrix{Float64}} = nothing,
    model_geometry::NamedTuple = NamedTuple(),
)
    _ = family_counts
    single_task = length(ctx.specs) == 1
    first_spec = ctx.specs[1]
    case_root = resolve_case_root(cfg.case_root)
    run_entries = Pair{String, String}[
        "execution_mode" => String(execution_mode),
        "system_name" => ctx.system_name,
        "calculation" => string(first_spec.calculation),
        "tasks.count" => string(length(ctx.specs)),
    ]
    if single_task
        push!(run_entries, "quantity" => string(first_spec.quantity))
        push!(run_entries, "method" => string(first_spec.method))
        push!(run_entries, "task" => string(first_spec.task))
        push!(run_entries, "normalized_quantity" => string(first_spec.quantity))
        push!(run_entries, "normalized_method" => string(first_spec.method))
        push!(run_entries, "normalized_calculation" => string(first_spec.calculation))
    end

    task_entries = Pair{String, String}["matrix_families" => metadata_value(matrix_families),]
    for (idx, spec) in enumerate(ctx.specs)
        prefix = "task.$(idx)"
        push!(task_entries, "$(prefix).requested" => metadata_value(cfg.tasks[idx]))
        push!(
            task_entries,
            "$(prefix).normalized" =>
                metadata_value((spec.quantity, spec.method, spec.calculation, spec.task)),
        )
        push!(task_entries, "$(prefix).label" => spec.label)
        if idx <= length(outputs)
            push!(
                task_entries,
                "$(prefix).output" => metadata_display_path(outputs[idx], ctx.run_dir),
            )
        end
    end

    photon_energies = Float64[x for x in cfg.photon_energies]
    input_entries = Pair{String, String}[
        "case_root" => case_root,
        "run_dir" => metadata_display_path(ctx.run_dir, case_root),
        "model_file" => metadata_display_path(ctx.model_file, case_root),
        "model_identity" => ctx.model_identity,
        "model_input_mode" => String(ctx.model_input_mode),
        "operator_demand" => join(
            real_space_operator_name.(ctx.operator_demand.required_operators),
            ",",
        ),
        "bloch_phase_convention_storage" => (cfg.native_model_input isa AnalyticKInput && cfg.native_model_input.basis == :fixed_orthonormal ?
                                             "fixed_orthonormal_k_basis; no real-space representation" :
                                             cfg.native_model_input isa AnalyticKInput && cfg.native_model_input.basis == :explicit ?
                                             "declared_smooth_k_connection; no real-space representation or inferred cross-point overlap" :
                                             "Convention_II_R_only"),
        "bloch_phase_convention_runtime" => wannier_center_convention_name(
            normalize_wannier_center_convention(cfg.wannier_center_convention),
        ),
        "wannier_center_source" => (cfg.native_model_input isa NonorthogonalLocalizedInput ?
                                    (cfg.native_model_input.model.orbital_centers_cartesian === nothing ?
                                     "localized_explicit_centers_absent" :
                                     "declared_localized_orbital_centers_cartesian") :
                                    cfg.native_model_input isa AnalyticKInput ?
                                    (cfg.native_model_input.orbital_positions === nothing ?
                                     (cfg.native_model_input.basis == :explicit ?
                                      "not declared; inactive workspace centers are not orbital positions" :
                                      "not_applicable_fixed_orthonormal_basis") :
                                     "declared_native_orbital_positions") :
                                    "tb_position_R0_diagonal"),
        "spin_enabled" => metadata_value(cfg.spin_enabled),
    ]
    if any(
        spec -> spec.quantity in (:photon_drag_shift_current, :photon_drag_injection_current),
        ctx.specs,
    )
        producer_root = Base.pkgdir(parentmodule(@__MODULE__))
        producer_manifest = joinpath(producer_root, "SOURCE_MANIFEST.tsv")
        optical_provider_source =
            joinpath(producer_root, "src", "MatrixElements", "OpticalMomentumOverlap.jl")
        append!(
            input_entries,
            [
                "producer_package_version" => string(Base.pkgversion(parentmodule(@__MODULE__))),
                "producer_source_root" => producer_root,
                "producer_source_manifest_sha256_declared" =>
                    (isfile(producer_manifest) ? sha256_file(producer_manifest) : "NOT_RECORDED"),
                "producer_source_identity_scope" => "declared control manifest; full installation audit is separate",
                "photon_drag_optical_provider_sha256" => (
                    isfile(optical_provider_source) ? sha256_file(optical_provider_source) :
                    "NOT_RECORDED"
                ),
                "photon_drag_response_band_scope" => "all finite-model bands",
                "photon_drag_intermediate_band_scope" => "all finite-model bands",
                "photon_drag_injection_degenerate_current" => "full exact-spectral-subspace current trace; external pair weights",
                "photon_drag_denominator_formula" => "[DeltaE/(DeltaE^2+gamma^2)]^2",
                "photon_drag_transition_gap" => "epsilon_m(k+q/2)-epsilon_n(k-q/2); eV",
                "photon_drag_gamma_eV" => metadata_value(cfg.denominator_regularization),
                "photon_drag_weight_derivative_scope" => "outside geometric finite-difference kernel",
                "photon_drag_optical_overlap_strategy" => (
                    cfg.native_model_input isa NonorthogonalLocalizedInput ?
                    "NOT_SUPPORTED_NONORTHOGONAL_FINITE_Q" :
                    cfg.native_model_input isa AnalyticKInput ?
                    (
                        cfg.native_model_input.basis == :fixed_orthonormal ?
                        "exact_fixed_basis_identity" : "exact_declared_point_orbital_link"
                    ) :
                    cfg.native_model_input isa RealSpaceTBInput ?
                    "exact_declared_point_orbital_link" :
                    "wannier_raw_A_first_order_R_only_with_endpoint_convention_transform"
                ),
                "photon_drag_optical_overlap_orientation" => "q=k_left-k_right Cartesian inverse Angstrom; A at endpoint midpoint",
                "photon_drag_optical_overlap_response_order" => "full existing finite-q response retained; higher-order microscopic accuracy not implied",
                "photon_drag_pdsc_auxiliary_transport" => "original p-links and explicit residual connection retained",
                "photon_drag_velocity_source" => (
                    cfg.native_model_input isa AnalyticKInput &&
                    cfg.native_model_input.basis == :fixed_orthonormal ?
                    "full dH/dk in the fixed basis, including diagonal entries" :
                    "full dH+i[H,A] endpoint physical velocity in source gauge; intraband retained"
                ),
            ],
        )
    end
    if cfg.native_model_input !== nothing
        native = cfg.native_model_input
        parameter_metadata =
            native isa AnalyticKInput && native.basis == :fixed_orthonormal ?
            native_parameters_metadata(native.parameters) : native.parameters
        push!(input_entries, "native_model_parameters" => repr(parameter_metadata))
        push!(
            input_entries,
            "native_model_basis" => (
                native isa NonorthogonalLocalizedInput ? "nonorthogonal_localized" :
                native isa AnalyticKInput ? String(native.basis) : String(native.position_model)
            ),
        )
        push!(
            input_entries,
            "native_model_source_identity" => (
                isempty(native.source_file) ? "NOT_RECORDED" : native_source_file_identity(native)
            ),
        )
        push!(input_entries, "native_spin_roundtrip_status" => "NOT_EVALUATED")
        native isa RealSpaceTBInput &&
            push!(input_entries, "native_derivative_method" => "ANALYTIC_FOURIER")
        if native isa NonorthogonalLocalizedInput
            append!(
                input_entries,
                [
                    "localized_spin_representation" => String(native.model.spin_representation),
                    "localized_magnetic_state" => String(native.model.magnetic_state),
                    "localized_spin_orbit_coupling" =>
                        metadata_value(native.model.spin_orbit_coupling),
                    "localized_spin_ordering" => String(native.model.spin_ordering),
                    "localized_spatial_orbital_count" =>
                        metadata_value(native.model.num_spatial_orbitals),
                    "localized_explicit_state_multiplicity" => "1",
                ],
            )
            representation = native.model.representation_diagnostics
            append!(
                input_entries,
                Pair{String, String}[
                    "native_effective_construction_scheme" => representation.scheme,
                    "native_raw_operator_defects" => repr(representation.raw),
                    "native_effective_operator_defects" => repr(representation.effective),
                    "native_operator_adjustment" => repr(representation.adjustment),
                    "native_representation_reporting_warning" => string(
                        representation.exceeds_reporting_tolerance,
                    ),
                    "native_raw_file_modified" => string(representation.raw_file_modified),
                    "native_metric_floor_semantics" => "condition warning; positive definiteness remains required",
                ],
            )
            push!(input_entries, "native_derivative_method" => "METRIC_AWARE_ANALYTIC_FOURIER")
            push!(
                input_entries,
                "native_metric_relative_floor" => string(native.model.metric_relative_floor),
            )
            push!(
                input_entries,
                "native_hamiltonian_representation_tolerance_ev" =>
                    string(native.model.hamiltonian_representation_tolerance_ev),
            )
            push!(
                input_entries,
                "native_overlap_representation_tolerance" =>
                    string(native.model.overlap_representation_tolerance),
            )
            push!(
                input_entries,
                "native_position_translation_tolerance_angstrom" =>
                    string(native.model.position_translation_tolerance_angstrom),
            )
            push!(
                input_entries,
                "native_representation_norms" => "H_FROBENIUS_EV;S_FROBENIUS_DIMENSIONLESS;r_MAX_ENTRY_ANGSTROM",
            )
            push!(
                input_entries,
                "native_hermitian_solver_triangle" => "PAIR_PROJECTED_EFFECTIVE_OPERATORS; UPPER_FOR_ROUNDOFF; RAW_DIAGNOSTICS_SEPARATE",
            )
            push!(
                input_entries,
                "native_scalar_minimum_gap_ev" => string(max(1e-4, cfg.degeneracy_threshold)),
            )
            push!(input_entries, "native_scope" => "SPINLESS_SCALAR_SEPARATED_BANDS")
        end
        if native isa AnalyticKInput
            push!(
                input_entries,
                "native_derivative_evidence" => "native_derivatives.tsv (shared run root; actual evaluated orders)",
            )
            push!(input_entries, "native_derivative_method" => String(native.derivative_method))
            push!(
                input_entries,
                "native_finite_difference_step_A_inverse" => string(native.finite_difference_step),
            )
            push!(input_entries, "native_periodic" => string(native.periodic))
            push!(
                input_entries,
                "native_evaluation_bounds_A_inverse" => repr(native.evaluation_bounds),
            )
        end
        if cfg.integration_bounds !== nothing
            lower, upper = cfg.integration_bounds
            dimension = integration_dimension(cfg)
            push!(
                input_entries,
                "integration_domain_cartesian_A_inverse" => repr(cfg.integration_bounds),
            )
            push!(input_entries, "integration_dimension" => string(dimension))
            push!(input_entries, "integration_measure" => "d^$(dimension)k/(2pi)^$(dimension)")
            push!(
                input_entries,
                "integration_cutoff_qualification" => "USER_DOMAIN_CUTOFF_DEPENDENT",
            )
            push!(
                input_entries,
                "response_unit_relative_to_bulk" => "multiply bulk unit by m^$(3-dimension)",
            )
        end
    end
    for (key, value) in pairs(integration_affine_region_metadata(cfg))
        push!(input_entries, string(key) => repr(value))
    end
    if cfg.integration_bounds !== nothing &&
       cfg.integration_algorithm isa UniformIntegration &&
       cfg.integration_algorithm.region_quadrature == :left_endpoint
        push!(input_entries, "integration_region_quadrature" => "left_endpoint")
    end
    if ctx.model_input_mode == :legacy
        try
            centers =
                metadata_centers === nothing ? _read_wannier_tb_centers(ctx.model_file) :
                metadata_centers
            all(isfinite, centers) || error("TB Wannier centers contain non-finite values.")
            push!(input_entries, "wannier_center_count" => string(size(centers, 2)))
            push!(
                input_entries,
                "wannier_center_cartesian_min_A" => @sprintf("%.12e", minimum(centers)),
            )
            push!(
                input_entries,
                "wannier_center_cartesian_max_A" => @sprintf("%.12e", maximum(centers)),
            )
            push!(
                input_entries,
                "wannier_centers_cartesian_definition_A" =>
                    repr(Tuple(Tuple(centers[:, index]) for index in axes(centers, 2))),
            )
        catch err
            push!(
                input_entries,
                "wannier_center_summary" => "unavailable: $(sprint(showerror, err))",
            )
        end
    end
    if ctx.seed_inputs !== nothing
        seed = ctx.seed_inputs
        push!(input_entries, "seedname" => cfg.seedname)
        push!(input_entries, "seed_prefix" => metadata_display_path(seed.seed_prefix, case_root))
        push!(input_entries, "seed_tb_file" => metadata_display_path(seed.model_file, case_root))
        push!(input_entries, "seed_spn_file" => metadata_display_path(seed.spin_file, case_root))
        push!(
            input_entries,
            "seed_chk_file" => metadata_display_path(seed.checkpoint_file, case_root),
        )
        push!(
            input_entries,
            "seed_eig_file" => metadata_display_path(seed.eigenvalue_file, case_root),
        )
        push!(input_entries, "seed_mmn_file" => metadata_display_path(seed.overlap_file, case_root))
        push!(input_entries, "spin_velocity_source" => "seed-derived binary .spn/.chk/.eig/.mmn")
        push!(input_entries, "spin_velocity_local_wannier_center_phase" => "disabled")
    end
    if cfg.spin_enabled && ctx.model_input_mode == :legacy
        spin_file =
            isabspath(cfg.spin_file) ? normpath(cfg.spin_file) :
            normpath(joinpath(case_root, cfg.spin_file))
        checkpoint_file =
            isabspath(cfg.checkpoint_file) ? normpath(cfg.checkpoint_file) :
            normpath(joinpath(case_root, cfg.checkpoint_file))
        push!(input_entries, "spin_file" => metadata_display_path(spin_file, case_root))
        push!(input_entries, "checkpoint_file" => metadata_display_path(checkpoint_file, case_root))
        push!(input_entries, "spin_file_formatted" => metadata_value(cfg.spin_file_formatted))
    end
    open(ctx.metadata_path, "w") do io
        metadata_section(io, "Run", run_entries)
        metadata_section(io, "Input", input_entries)
        if !isempty(keys(model_geometry))
            metadata_section(
                io,
                "Geometry",
                Pair{String, String}[
                    "schema" => model_geometry.schema,
                    "lattice_convention" => model_geometry.lattice_convention,
                    [
                        "lattice_row.$(i)_angstrom" => metadata_value(
                            model_geometry.lattice_rows_angstrom[i],
                        ) for i in 1:3
                    ]...,
                ],
            )
        end
        if !isempty(keys(metadata_summaries.qualification_summary[]))
            metadata_section(
                io,
                "Qualification",
                metadata_summary_entries(metadata_summaries.qualification_summary[]),
            )
        end
        metadata_section(io, "Tasks", task_entries)
        metadata_section(io, "Numerics", metadata_numerics_entries(cfg, ctx))
        if native_direct_low_dimensional(cfg)
            d = native_physical_dimension(cfg.native_model_input)
            metadata_section(
                io,
                "NativePhysicalGeometry",
                Pair{String, String}[
                    "physical_dimension" => string(d),
                    "dimension_origin" => "physical lattice input shape; not inferred from sampling",
                    "physical_axes" => join(("x", "y", "z")[1:d], ","),
                    "auxiliary_length_angstrom" => "1.0 per missing direction",
                    "auxiliary_periodicity" => "none; actual model periodicity applies only to physical axes",
                    "auxiliary_integration" => "none; rule and budget use physical dimension",
                    "coefficient_normalization" => "three-dimensional reference-cell volume; sheet/line conversion is postprocessing",
                    "local_observables" => "original response-specific units; spin has three components and orbital moments retain their axial components",
                ],
            )
        end
        if all(spec -> spec.calculation == :kslice, ctx.specs)
            metadata_section(
                io,
                "KSliceNormalization",
                Pair{String, String}[
                    "value_kind" => "local k-space observable or response density",
                    "quadrature_weights" => "not applied; mesh counts select sample locations only",
                    "legacy_current_migration" => "SC/IC/ISC/SSC/PDSC/PDIC no longer contain 1/(N_u*N_v); physical prefactors and cell convention retained",
                    "conductivity_measure" => "retain the response-specific fractional-BZ density or Cartesian-SI integrand and declared output units",
                    "geometry_and_moment" => "native local geometry or muB moment; no conductivity coefficient is inferred",
                    "reconstruction" => "requires matching complete domain, band/component/term selections and the response-specific integration measure; one arbitrary plane is not a 3D BZ integral",
                ],
            )
        end
        if !isempty(keys(metadata_summaries.replica_summary[]))
            metadata_section(
                io,
                "Replica",
                metadata_summary_entries(metadata_summaries.replica_summary[]),
            )
        end
        if !isempty(keys(metadata_summaries.fourier_summary[]))
            metadata_section(
                io,
                "Fourier",
                metadata_summary_entries(metadata_summaries.fourier_summary[]),
            )
        end
        if !isempty(keys(metadata_summaries.response_symmetry_summary[]))
            metadata_section(
                io,
                "ResponseSymmetry",
                metadata_summary_entries(metadata_summaries.response_symmetry_summary[]),
            )
        end
        if !isempty(keys(metadata_summaries.band_summary[]))
            metadata_section(
                io,
                "Band",
                metadata_summary_entries(metadata_summaries.band_summary[]),
            )
        end
        first_definition =
            task_definition(first_spec.quantity, first_spec.method, first_spec.calculation)
        if first_definition === nothing || !_is_band_structure(first_definition)
            metadata_section(
                io,
                "PhotonEnergies",
                Pair{String, String}[
                    "photon_energies.count" => string(length(photon_energies)),
                    "photon_energies.min_eV" => isempty(photon_energies) ? "n/a" :
                                                @sprintf("%.12f", minimum(photon_energies)),
                    "photon_energies.max_eV" => isempty(photon_energies) ? "n/a" :
                                                @sprintf("%.12f", maximum(photon_energies)),
                    "photon_energies.values_eV" => metadata_photon_energy_values(photon_energies),
                ],
            )
        end
        metadata_section(
            io,
            "Progress",
            Pair{String, String}[
                "progress_enabled" => metadata_value(cfg.progress_enabled),
                "progress_percent_interval" => metadata_value(cfg.progress_percent_interval),
                "progress_verbosity" => cfg.progress_verbosity,
                "progress_out_path" => metadata_display_path(ctx.progress_out_path, ctx.run_dir),
                "progress_jsonl_path" => metadata_display_path(
                    ctx.progress_jsonl_path,
                    ctx.run_dir,
                ),
            ],
        )
        output_entries = Pair{String, String}["outputs.count" => string(length(outputs))]
        for (idx, output) in enumerate(outputs)
            push!(output_entries, "output.$(idx)" => metadata_display_path(output, ctx.run_dir))
        end
        metadata_section(io, "Outputs", output_entries)
    end
    return ctx.metadata_path
end
