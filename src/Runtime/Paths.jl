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
    open(path, "r") do io
        return bytes2hex(sha256(io))
    end
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

"""
Prepare run context.
"""
function prepare_run_context(cfg::EffectiveTaskConfig, specs::Vector{NormalizedTaskSpec})
    comm = bundle_mpi_comm_world()
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
            seed_prefix * ".spn",
            seed_prefix * ".chk",
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
    paired_tb_validation_file = if model_input_mode == :packed_hdf5 && !isempty(cfg.model_file)
        resolved = resolve_path(cfg.model_file, cfg.model_file; base = case_root)
        isfile(resolved) || error("Paired TB validation file does not exist: $(resolved)")
        resolved
    else
        nothing
    end
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
    demand = operator_demand_plan(specs, cfg)
    model_input_mode == :legacy &&
        demand.requires_full_projector_geometry &&
        error(
            "PROJECTOR_FULL_DERIVATIVE_OVERLAP_REQUIRED: Projector shift-current/QHC requires " *
            "a schema-6 Packed HDF5 bundle generated from exact .uIu input",
        )
    num_orbitals = if model_input_mode == :packed_hdf5
        manifest = bundle_mpi_root_call(
            () -> read_real_space_operator_bundle_manifest(model_file);
            comm,
        )
        validate_operator_demand(manifest, demand)
        if paired_tb_validation_file !== nothing
            manifest.paired_tb_sha256 === nothing &&
                error("Bundle does not embed a paired TB SHA-256.")
            paired_digest =
                bundle_mpi_root_call(() -> checksum_file(paired_tb_validation_file); comm)
            paired_digest == manifest.paired_tb_sha256 ||
                error("Provided TB SHA-256 does not match the bundle paired TB digest.")
        end
        manifest.num_orbitals
    else
        bundle_mpi_root_call(() -> read_wannier_tb_num_orbitals(model_file); comm)
    end
    model_sha256 = bundle_mpi_root_call(() -> checksum_file(model_file); comm)

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
        model_sha256,
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
        "spatial_dimension" => metadata_value(cfg.spatial_dimension),
        "band_window_size" => metadata_value(cfg.band_window_size),
        "response_output_digits" => metadata_value(cfg.response_output_digits),
        "response_symmetry_report_enabled" => metadata_value(cfg.response_symmetry_report_enabled),
        "tensor_indices" => metadata_value(cfg.tensor_indices),
        "band_selection" => metadata_value(cfg.band_selection),
    ]
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
    append!(
        entries,
        Pair{String, String}[
            "kslice_origin" => metadata_value(cfg.kslice_origin),
            "kslice_vector_1" => metadata_value(cfg.kslice_vector_1),
            "kslice_vector_2" => metadata_value(cfg.kslice_vector_2),
            "photon_momentum" => metadata_value(cfg.photon_momentum),
            "finite_difference_step" => metadata_value(cfg.finite_difference_step),
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
        "model_sha256" => ctx.model_sha256,
        "model_input_mode" => String(ctx.model_input_mode),
        "operator_demand" => join(
            real_space_operator_name.(ctx.operator_demand.required_operators),
            ",",
        ),
        "bloch_phase_convention_storage" => "Convention_II_R_only",
        "bloch_phase_convention_runtime" => wannier_center_convention_name(
            normalize_wannier_center_convention(cfg.wannier_center_convention),
        ),
        "wannier_center_source" => "tb_position_R0_diagonal",
        "spin_enabled" => metadata_value(cfg.spin_enabled),
    ]
    if ctx.model_input_mode == :legacy
        try
            model = read_wannier_tb(ctx.model_file)
            centers = extract_wannier_centers(model)
            all(isfinite, centers) || error("TB Wannier centers contain non-finite values.")
            center_bytes = reinterpret(UInt8, vec(centers))
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
                "wannier_center_cartesian_sha256" => bytes2hex(SHA.sha256(center_bytes)),
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
        metadata_section(io, "Tasks", task_entries)
        metadata_section(io, "Numerics", metadata_numerics_entries(cfg, ctx))
        if !isempty(keys(replica_summary))
            metadata_section(
                io,
                "Replica",
                Pair{String, String}[
                    string(key) => metadata_value(getproperty(replica_summary, key)) for
                    key in keys(replica_summary)
                ],
            )
        end
        if !isempty(keys(fourier_summary))
            metadata_section(
                io,
                "Fourier",
                Pair{String, String}[
                    string(key) => metadata_value(getproperty(fourier_summary, key)) for
                    key in keys(fourier_summary)
                ],
            )
        end
        if !isempty(keys(response_symmetry_summary))
            metadata_section(
                io,
                "ResponseSymmetry",
                Pair{String, String}[
                    string(key) => metadata_value(getproperty(response_symmetry_summary, key)) for
                    key in keys(response_symmetry_summary)
                ],
            )
        end
        if !isempty(keys(band_summary))
            metadata_section(
                io,
                "Band",
                Pair{String, String}[
                    string(key) => metadata_value(getproperty(band_summary, key)) for
                    key in keys(band_summary)
                ],
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
