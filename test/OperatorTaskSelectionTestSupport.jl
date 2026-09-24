using Test, WannierNLQG, HDF5, JSON3, SHA, LinearAlgebra, Random
isdefined(@__MODULE__, :standard_export_fixture) ||
    include(joinpath(@__DIR__, "WannierStandardExportTestSupport.jl"))
isdefined(@__MODULE__, :_profile_modified_config) ||
    include(joinpath(@__DIR__, "WannierOperatorProfileTestSupport.jl"))

const OTS_C = WannierNLQG.Core
const OTS_IO = WannierNLQG.IO
const OTS_R = WannierNLQG.Runtime
const OTS_W = WannierNLQG.Wannierization

function ots_fixture(directory; nonzero_neighbors = false, neighbor_permutation = :identity)
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
    fixture = standard_export_fixture(; mmn_override = mmn)
    r = fixture.result
    eligible = OTS_W.WannierizationResult(
        OTS_W.COMPLETED,
        r.v_matrix,
        r.wannier_centers_cartesian,
        r.spreads_angstrom2,
        r.history,
        OTS_W.WannierizationDiagnostic[],
        merge(
            r.input_summary,
            Dict(
                "hard_gate_frozen"=>"0.0",
                "solver_convergence"=>"CONVERGED",
                "stopping_reason"=>"CONVERGED",
            ),
        ),
        r.wannier_chk,
        nothing,
        r.restart_state,
        r.artifacts,
        r.initialization_report,
    )
    parent = first(OTS_W._load_wannierization_extension!())
    extension = parent.OperatorExport
    prepared, quality, _, _, _ =
        Base.invokelatest(extension._prepare_wannierization_tb_state, eligible, fixture.config)
    @test quality == "PASS"
    authority = Base.invokelatest(extension._native_authoritative_band_hamiltonian, fixture.eig)
    gauge = _profile_gauge_contract(parent, :ordinary, 2, 2)
    model = Base.invokelatest(extension.build_wannier_tight_binding_model, prepared, authority, mmn)
    inputs = Base.invokelatest(_profile_write_inputs, directory, mmn, authority, gauge, parent)
    if nonzero_neighbors
        rng = Random.MersenneTwister(928)
        x = [randn(rng, ComplexF64, 4, 2) for neighbor in 1:mmn.num_neighbors, k in 1:mmn.num_kpts]
        energy = [Matrix(Hermitian(randn(rng, ComplexF64, 4, 4))) for k in 1:mmn.num_kpts]
        OTS_IO.write_wannier_uiu(
            inputs.uiu_file,
            OTS_IO.WannierUIUHeader("nonzero Gram regression", 2, 2, mmn.num_neighbors),
            (k, b, a, h)->x[source_to_internal[a, k], k]'*x[source_to_internal[b, k], k],
        )
        OTS_IO.write_wannier_uhu(
            inputs.uhu_file,
            OTS_IO.WannierUHUHeader("nonzero energy regression", 2, 2, mmn.num_neighbors),
            (k, b, a, h)->x[source_to_internal[a, k], k]'*energy[k]*x[source_to_internal[b, k], k],
        )
        for (artifact, sidecar) in
            ((inputs.uiu_file, inputs.uiu_provenance), (inputs.uhu_file, inputs.uhu_provenance))
            payload=JSON3.read(read(sidecar, String), Dict{String, Any})
            payload["output_sha256"]=bytes2hex(sha256(read(artifact)))
            write(sidecar, JSON3.write(payload))
        end
    end
    target = OTS_W.WannierOperatorTargetContract(
        abspath(inputs.mmn_file),
        bytes2hex(sha256(read(inputs.mmn_file))),
        abspath(inputs.mmn_file),
        bytes2hex(sha256(read(inputs.mmn_file))),
        gauge.source_band_gauge,
        gauge.target_band_gauge,
        gauge.transform_sha256,
        gauge.contract_sha256,
        something(gauge.gauge_artifact_sha256, "NOT_APPLICABLE"),
        authority.authority,
        authority.digest,
        mmn.num_bands,
        mmn.num_kpts,
        mmn.num_neighbors,
    )
    for sidecar in (inputs.uiu_provenance, inputs.uhu_provenance)
        payload = JSON3.read(read(sidecar, String), Dict{String, Any})
        payload["input_sha256"]["OPERATOR_TARGET_CONTRACT"] = target.contract_sha256
        write(sidecar, JSON3.write(payload))
    end
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
        _profile_eligibility(authority),
        Dict("production_eligible"=>false, "scoped_production_eligible"=>false),
    )
    OTS_IO.write_real_space_operator_bundle(
        output,
        model.lattice,
        model.r_degeneracies,
        operators;
        profile = nothing,
        operator_tasks = tasks,
        provenance = merge(
            Dict(
                "authoritative_hamiltonian"=>authority.authority,
                "authoritative_hamiltonian_digest"=>authority.digest,
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
    @test geometry_provenance["authoritative_hamiltonian_input_sha256"] ==
          provenance["authoritative_hamiltonian_input_sha256"]
    geometry_output = joinpath(directory, "geometry.h5")
    OTS_IO.write_real_space_operator_bundle(
        geometry_output,
        model.lattice,
        model.r_degeneracies,
        geometry_operators;
        profile = nothing,
        operator_tasks = geometry_tasks,
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
