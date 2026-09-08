# Validate that two ordered center sources agree modulo lattice translations.
function validate_wannier_center_sources(
    model::TightBindingModel,
    checkpoint::WannierCHK;
    tolerance_angstrom::Float64 = 1.0e-6,
)
    checkpoint.num_orbitals == model.num_orbitals || error(
        "Wannier-center source mismatch: TB has $(model.num_orbitals) orbitals but CHK has " *
        "$(checkpoint.num_orbitals).",
    )
    maximum(abs, checkpoint.real_lattice .- model.lattice) <= tolerance_angstrom || error(
        "Wannier-center source mismatch: TB and CHK real-space lattices differ by more than " *
        "$(tolerance_angstrom) Angstrom.",
    )
    tb_centers = extract_wannier_centers(model)
    all(isfinite, tb_centers) || error("TB Wannier centers contain non-finite values.")
    all(isfinite, checkpoint.wannier_centers_cart) ||
        error("CHK Wannier centers contain non-finite values.")
    for orbital in 1:model.num_orbitals
        difference =
            @view(tb_centers[:, orbital]) .- @view(checkpoint.wannier_centers_cart[orbital, :])
        fractional = real_space_cartesian_to_fractional(difference, model.lattice)
        fractional .-= round.(fractional)
        residual = transpose(model.lattice) * fractional
        error_angstrom = norm(residual)
        error_angstrom <= tolerance_angstrom || error(
            "Wannier-center source mismatch at ordered orbital $(orbital): modulo-lattice " *
            "error=$(error_angstrom) Angstrom exceeds $(tolerance_angstrom) Angstrom.",
        )
    end
    return nothing
end

"""
Read SPN and CHK inputs, validate ordered Wannier centers, rotate spin into Wannier gauge and transform it to R space.

Enforce Hermiticity/roundtrip checks and preserve upstream spin units; missing files or mismatched geometry raise errors.

Load spin real space.
"""
function load_spin_real_space(
    model::TightBindingModel,
    spin_file::AbstractString,
    checkpoint_file::AbstractString;
    spin_file_formatted::Bool = false,
)
    isfile(spin_file) || error("Spin file does not exist: $(spin_file)")
    isfile(checkpoint_file) || error("Checkpoint file does not exist: $(checkpoint_file)")

    runtime_notice("read spin file: $(spin_file)")
    spin_input = read_wannier_spn(spin_file; formatted = spin_file_formatted)
    runtime_notice("read checkpoint file: $(checkpoint_file)")
    checkpoint = read_wannier_chk(checkpoint_file)
    validate_wannier_center_sources(model, checkpoint)
    gauge = spn_to_wannier_gauge_q_diagnostics(spin_input, checkpoint)
    runtime_notice(
        "generated spin in Wannier gauge: input_herm=$(gauge.diagnostics.max_input_hermiticity_error), " *
        "output_herm=$(gauge.diagnostics.max_output_hermiticity_error)",
    )
    transformed = spin_q_to_r_diagnostics(gauge.spin_q, checkpoint, model)
    runtime_notice(
        "generated spin real-space data: roundtrip_error=$(transformed.diagnostics.max_roundtrip_error)",
    )
    return transformed.real_space
end

"""
Load legacy spin input only when spin is enabled; otherwise return nothing without reading files.
"""
function maybe_load_spin_from_config(model::TightBindingModel, config::EffectiveTaskConfig)
    config.spin_enabled || return nothing
    isempty(config.spin_file) && error("spin_enabled=true requires EffectiveTaskConfig.spin_file.")
    isempty(config.checkpoint_file) &&
        error("spin_enabled=true requires EffectiveTaskConfig.checkpoint_file.")

    case_root = resolve_case_root(config.case_root)
    spin_file =
        isabspath(config.spin_file) ? normpath(config.spin_file) :
        normpath(joinpath(case_root, config.spin_file))
    checkpoint_file =
        isabspath(config.checkpoint_file) ? normpath(config.checkpoint_file) :
        normpath(joinpath(case_root, config.checkpoint_file))
    return load_spin_real_space(
        model,
        spin_file,
        checkpoint_file;
        spin_file_formatted = config.spin_file_formatted,
    )
end

"""
Read SPN, CHK and EIG inputs, validate ordered centers, then stream MMN overlaps to construct spin-weighted R-space operators.

Pass supported numerical options to the streaming builder; preserve upstream spin units and reject input contract mismatches.

Load spin velocity real space.
"""
function load_spin_velocity_real_space(
    model::TightBindingModel,
    spin_file::AbstractString,
    checkpoint_file::AbstractString,
    eigenvalue_file::AbstractString,
    overlap_file::AbstractString;
    spin_file_formatted::Bool = false,
    kwargs...,
)
    spin_input = read_wannier_spn(spin_file; formatted = spin_file_formatted)
    checkpoint = read_wannier_chk(checkpoint_file)
    validate_wannier_center_sources(model, checkpoint)
    eigenvalues = read_wannier_eig(eigenvalue_file)
    return compute_spin_velocity_real_space_streaming(
        model,
        spin_input,
        checkpoint,
        eigenvalues,
        overlap_file;
        kwargs...,
    )
end

"""
Load spin-velocity sources only when the validated task bundle demands them, using resolved context paths.
"""
function maybe_load_spin_velocity_from_context(
    model::TightBindingModel,
    ctx::RunContext,
    config::EffectiveTaskConfig,
)
    ctx.seed_inputs === nothing && return nothing
    seed = ctx.seed_inputs
    runtime_notice("read spin-velocity seed inputs: $(seed.seed_prefix)")
    real_space = load_spin_velocity_real_space(
        model,
        seed.spin_file,
        seed.checkpoint_file,
        seed.eigenvalue_file,
        seed.overlap_file;
        spin_file_formatted = false,
    )
    return real_space
end
