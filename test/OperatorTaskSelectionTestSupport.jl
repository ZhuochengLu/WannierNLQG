using Test, WannierNLQG, HDF5, JSON3, SHA, LinearAlgebra, Random
isdefined(@__MODULE__, :standard_export_fixture) ||
    include(joinpath(@__DIR__, "WannierStandardExportTestSupport.jl"))
isdefined(@__MODULE__, :_profile_modified_config) ||
    include(joinpath(@__DIR__, "WannierOperatorProfileTestSupport.jl"))

# Fresh probes need the same current-publication negative-fixture helper.
isdefined(@__MODULE__, :with_republished_bundle_fixture) ||
    include(joinpath(@__DIR__, "OperatorBundleTestSupport.jl"))

isdefined(@__MODULE__, :fresh_response_command) ||
    include(joinpath(@__DIR__, "FreshResponseProcessSupport.jl"))

const OTS_C = WannierNLQG.Core
const OTS_IO = WannierNLQG.IO
const OTS_R = WannierNLQG.Runtime
const OTS_W = WannierNLQG.Wannierization

# Compile required BCD/BCQ task physics through the public path; no model is read or solved.
function ots_runtime_demand_configuration(
    definition;
    tensor_indices = ntuple(_ -> 1, Int(definition.tensor_rank)),
    wannier_center_convention = "Convention_II",
    integral_form = :fermi_surface,
    full_tensor = false,
)
    quantity = OTS_R.quantity_symbol(definition.quantity)
    method = OTS_R.method_symbol(definition.method)
    calculation = OTS_R.calculation_symbol(definition.calculation)
    if !(
        quantity in
        (:berry_curvature_dipole_conductivity, :berry_curvature_quadrupole_conductivity)
    )
        return OTS_R.EffectiveTaskConfig(
            tasks = [(String(quantity), String(method), String(calculation))],
            fourier_backend = "direct",
            spatial_dimension = 3,
            tensor_indices = tensor_indices,
            wannier_center_convention = wannier_center_convention,
            # This registry-closure fixture explicitly exercises the total metric.
            include_external = quantity in OTS_R.EXTERNAL_METRIC_QUANTITIES,
        )
    end
    task = TaskSpec(
        id = "operator_demand",
        quantity = String(quantity),
        method = String(method),
        physics = BerryMultipoleParameters(
            fermi_energies = [0.13],
            temperature = 300.0,
            relaxation_time_fs = 7.0,
            integral_form = integral_form,
        ),
        observable = full_tensor ? FullTensor() :
                     TensorComponents(TensorComponent(tensor_indices...)),
    )
    config = TaskConfig(
        model = ModelInput(
            model_file = joinpath(
                @__DIR__,
                "..",
                "examples",
                "fixtures",
                "spectral_response",
                "closed_tb.dat",
            ),
            wannier_center_convention = wannier_center_convention,
        ),
        sampling = BZMesh(k_mesh = (2, 2, 2), spatial_dimension = 3),
        tasks = [task],
        execution = ExecutionOptions(fourier_backend = "direct"),
        output = OutputOptions(output_root = tempdir(), progress_enabled = false),
    )
    return OTS_R.compile_task_config(config, task)
end

function ots_fixture(directory; nonzero_neighbors = false, neighbor_permutation = :identity)
    nonzero_neighbors && throw(
        ArgumentError(
            "use frozen_gram_fixture for independent Gram algebra; never overwrite native-generated operator files",
        ),
    )
    fixture = standard_export_fixture()
    stencil = WannierNLQG.MatrixElements.build_finite_difference_stencil(
        something(fixture.result.wannier_chk),
    )
    data = zeros(ComplexF64, 2, 2, length(stencil.weights), 2)
    for k in 1:2, b in eachindex(stencil.weights)
        data[:, :, b, k] .= Matrix{ComplexF64}(I, 2, 2)
    end
    mmn = OTS_IO.WannierMMN(
        2,
        2,
        length(stencil.weights),
        data,
        copy(stencil.neighbors),
        copy(stencil.reciprocal_shifts),
    )
    source_to_internal = repeat(reshape(collect(1:mmn.num_neighbors), :, 1), 1, mmn.num_kpts)
    if neighbor_permutation == :per_k
        # The saved solver stencil keeps index weights across k points. Permute
        # within equal-weight shells; arbitrary unequal-weight maps are covered
        # independently by NeighborOrderRegressionTestSupport.
        for weight in unique(stencil.weights)
            shell = findall(==(weight), stencil.weights)
            for k in 1:mmn.num_kpts
                source_to_internal[shell, k] .= circshift(shell, k)
            end
        end
        @test source_to_internal[:, 1] != source_to_internal[:, 2]
        @test all(
            stencil.weights[source_to_internal[:, k]] == stencil.weights for k in 1:mmn.num_kpts
        )
    elseif neighbor_permutation != :identity
        throw(ArgumentError("unsupported fixture neighbor permutation"))
    end
    reordered_data, reordered_neighbors, reordered_shifts =
        similar(mmn.data), similar(mmn.neighbors), similar(mmn.reciprocal_shifts)
    for k in 1:mmn.num_kpts, source in 1:mmn.num_neighbors
        internal = source_to_internal[source, k]
        reordered_data[:, :, source, k] .= mmn.data[:, :, internal, k]
        reordered_neighbors[source, k] = mmn.neighbors[internal, k]
        reordered_shifts[:, source, k] .= mmn.reciprocal_shifts[:, internal, k]
    end
    mmn = OTS_IO.WannierMMN(
        mmn.num_bands,
        mmn.num_kpts,
        mmn.num_neighbors,
        reordered_data,
        reordered_neighbors,
        reordered_shifts,
    )
    parent = first(OTS_W._load_wannierization_extension!())
    extension = parent.OperatorExport
    authority = Base.invokelatest(extension._native_authoritative_band_hamiltonian, fixture.eig)
    gauge = _profile_gauge_contract(parent, :ordinary, 2, 2)
    inputs = Base.invokelatest(
        _profile_write_inputs,
        directory,
        mmn,
        authority,
        gauge,
        parent;
        eig = fixture.eig,
        target_config = fixture.config,
    )
    mmn = inputs.target_mmn
    native = parent.PAWMatrixElements._read_augmentation_aware_native_source(inputs.links.source)
    center = reshape(_profile_plane_wave_packet(1).center, 3, 1)
    fixture = standard_export_fixture(;
        mmn_override = mmn,
        real_lattice_override = native.structure.lattice,
        centers_override = permutedims(transpose(native.structure.lattice) * center),
    )
    r = fixture.result
    # This is an algebraically specified accepted-frame fixture, not a solver run.
    # Its specified native frame contains the frozen first band; export measures its isometry.
    eligible = parent.WannierizationInternalSupport.updated_wannierization_result(
        r;
        input_summary = merge(r.input_summary, Dict("hard_gate_frozen" => "0.0")),
    )
    # Synthetic accepted state exercises export assembly, not a convergence claim.
    prepared, quality, _, _, _ =
        Base.invokelatest(extension._prepare_wannierization_tb_state, eligible, fixture.config)
    model = Base.invokelatest(extension.build_wannier_tight_binding_model, prepared, authority, mmn)
    target = inputs.target_contract
    # Generator output and sidecars remain untouched: their actual source and
    # target definitions are produced together through the public generation path.
    # Physically remove unneeded sources: assembly cannot accidentally rely on them.
    for path in (
        inputs.spn_file,
        inputs.spn_provenance,
        inputs.siu_file,
        inputs.shu_file,
        inputs.siu_provenance,
        inputs.shu_provenance,
    )
        rm(path)
    end
    tasks = (OTS_C.OperatorTask(quantity = :orbital_magnetization),)
    config = _profile_modified_config(
        fixture.config;
        profile = nothing,
        operator_tasks = tasks,
        authoritative_hamiltonian = OTS_W.NativeDFTHamiltonian(),
        mmn_file = inputs.mmn_file,
        uiu_file = inputs.uiu_file,
        uhu_file = inputs.uhu_file,
        uiu_provenance_json = inputs.uiu_provenance,
        uhu_provenance_json = inputs.uhu_provenance,
    )
    assemble() = Base.invokelatest(
        extension._assemble_wannierization_operator_profile_from_qualified_sources,
        model,
        prepared,
        mmn,
        config,
        authority,
        nothing,
        gauge,
        nothing,
        0.0,
        target,
    )
    operators, provenance = assemble()
    output = joinpath(directory, "oam.h5")
    geometry = _profile_geometry(model)
    geometry["production_eligible"] = false
    eligibility = merge(
        _profile_model_semantics(authority),
        Dict("production_eligible"=>false, "scoped_production_eligible"=>false),
    )
    OTS_IO.write_real_space_operator_bundle(
        output,
        model.lattice,
        model.r_degeneracies,
        operators;
        provenance = merge(
            Dict(
                "authoritative_hamiltonian"=>authority.authority,
                "authoritative_hamiltonian_definition"=>authority.definition,
            ),
            provenance,
        ),
        geometry,
        eligibility,
    )
    geometry_tasks = (OTS_C.OperatorTask(quantity = :berry_curvature),)
    geometry_config = _profile_modified_config(config; operator_tasks = geometry_tasks)
    geometry_operators, geometry_provenance = Base.invokelatest(
        extension._assemble_wannierization_operator_profile,
        model,
        prepared,
        mmn,
        geometry_config,
        authority,
    )
    @test geometry_provenance["authoritative_hamiltonian_input_definitions"] ==
          provenance["authoritative_hamiltonian_input_definitions"]
    geometry_output = joinpath(directory, "geometry.h5")
    OTS_IO.write_real_space_operator_bundle(
        geometry_output,
        model.lattice,
        model.r_degeneracies,
        geometry_operators;
        provenance = geometry_provenance,
        geometry,
        eligibility,
    )
    return (;
        output,
        operators,
        provenance,
        target,
        gauge,
        inputs,
        assemble,
        model,
        tasks,
        geometry,
        eligibility,
        geometry_output,
    )
end

function ots_capture(f)
    try
        f()
        return nothing
    catch exception
        return exception
    end
end

function ots_table(path)
    rows = [
        parse.(Float64, split(line)) for
        line in eachline(path) if !isempty(strip(line)) && !startswith(strip(line), "#")
    ]
    return reduce(vcat, permutedims.(rows))
end

function ots_response_config(bundle, output, method)
    return TaskConfig(
        model = ModelInput(real_space_operator_bundle_file = bundle),
        sampling = BZMesh(k_mesh = (2, 2, 2)),
        execution = ExecutionOptions(fourier_backend = "Direct"),
        output = OutputOptions(output_root = output, progress_enabled = false),
        tasks = [
            TaskSpec(
                id = "oam",
                quantity = "orbital_magnetization",
                method = method,
                physics = OrbitalMagnetizationParameters(
                    fermi_energies = Float64[0.13],
                    temperature = 300.0,
                    input_semantics = :direct_energy_overlap,
                ),
                observable = FullTensor(),
            ),
        ],
    )
end

function ots_rejects(f, pattern)
    error = ots_capture(f)
    @test error isa ArgumentError || error isa OTS_C.OperatorSelectionError
    @test occursin(pattern, sprint(showerror, error))
    return nothing
end

# Select response columns by the actual table header; coordinates are never summed.
function ots_response_columns(path)
    header =
        only(line for line in eachline(path) if startswith(line, "# ") && occursin("_real", line))
    labels = split(header[3:end])
    return findall(label -> endswith(label, "_real") || endswith(label, "_imag"), labels)
end
