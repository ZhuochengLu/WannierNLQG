# Test-only numerical oracle. This fixture is NOT a generated physical-source bundle.
# No sidecars, native source references, or target qualification are produced.
using Test, WannierNLQG, JSON3, LinearAlgebra
# Load once at the test module boundary, before defining fixture methods.
# A fresh process must not discover extension methods mid-fixture.
const FG_PARENT = first(WannierNLQG.Wannierization._load_wannierization_extension!())
const FG_EXPORT = FG_PARENT.OperatorExport
const FG_INTERNAL = FG_PARENT.WannierizationInternalSupport
isdefined(@__MODULE__, :standard_export_fixture) ||
    include(joinpath(@__DIR__, "WannierStandardExportTestSupport.jl"))

const FG_IO = WannierNLQG.IO
const FG_W = WannierNLQG.Wannierization
const FG_C = WannierNLQG.Core

"""
    frozen_gram_operator_fixture(directory; neighbor_permutation=:identity, frozen_json=...)

Replay the original frozen Gram/energy oracle through the production numerical
contraction kernels, without asserting that these matrices came from a DFT source.
The caller supplies an empty test directory (created if absent). Returned arrays
and model files are numerical-test inputs, not qualified physical-source artifacts. No
response test is implied until the consumers execute.
"""
function frozen_gram_operator_fixture(
    directory;
    neighbor_permutation = :identity,
    frozen_json = joinpath(@__DIR__, "fixtures", "ots_nonzero_neighbors_v1.11_seed928.json"),
)
    mkpath(directory)
    isempty(readdir(directory)) ||
        throw(ArgumentError("frozen Gram fixture directory must be empty"))
    fixture = standard_export_fixture()
    stencil = WannierNLQG.MatrixElements.build_finite_difference_stencil(
        something(fixture.result.wannier_chk),
    )
    data = zeros(ComplexF64, 2, 2, length(stencil.weights), 2)
    for k in 1:2, b in eachindex(stencil.weights)
        data[:, :, b, k] .= Matrix{ComplexF64}(I, 2, 2)
    end
    mmn = FG_IO.WannierMMN(
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
    mmn = FG_IO.WannierMMN(
        mmn.num_bands,
        mmn.num_kpts,
        mmn.num_neighbors,
        reordered_data,
        reordered_neighbors,
        reordered_shifts,
    )
    fixture = standard_export_fixture(; mmn_override = mmn)
    r = fixture.result
    parent = FG_PARENT
    extension = FG_EXPORT
    eligible = FG_INTERNAL.updated_wannierization_result(
        r;
        input_summary = merge(r.input_summary, Dict("hard_gate_frozen" => "0.0")),
    )
    prepared, quality, _, _, _ =
        Base.invokelatest(extension._prepare_wannierization_tb_state, eligible, fixture.config)
    @test quality == "PASS"
    authority = Base.invokelatest(extension._native_authoritative_band_hamiltonian, fixture.eig)
    model = Base.invokelatest(extension.build_wannier_tight_binding_model, prepared, authority, mmn)
    uiu_file = joinpath(directory, "frozen_gram.uIu")
    uhu_file = joinpath(directory, "frozen_energy.uHu")
    frozen = JSON3.read(read(frozen_json, String))
    frozen.schema == "wanniernlqg.test.nonzero-neighbor-operators.v1" ||
        error("unexpected nonzero-neighbor test fixture schema")
    (mmn.num_neighbors, mmn.num_kpts) == (8, 2) || error(
        "unexpected nonzero-neighbor test fixture shape: $(mmn.num_neighbors), $(mmn.num_kpts)",
    )
    x = reshape(
        [reshape(ComplexF64[complex(pair[1], pair[2]) for pair in row], 4, 2) for row in frozen.x],
        8,
        2,
    )
    energy = [
        reshape(ComplexF64[complex(pair[1], pair[2]) for pair in row], 4, 4) for
        row in frozen.energy
    ]
    FG_IO.write_wannier_uiu(
        uiu_file,
        FG_IO.WannierUIUHeader("nonzero Gram regression", 2, 2, mmn.num_neighbors),
        (k, b, a, h)->x[source_to_internal[a, k], k]'*x[source_to_internal[b, k], k],
    )
    FG_IO.write_wannier_uhu(
        uhu_file,
        FG_IO.WannierUHUHeader("nonzero energy regression", 2, 2, mmn.num_neighbors),
        (k, b, a, h)->x[source_to_internal[a, k], k]'*energy[k]*x[source_to_internal[b, k], k],
    )

    # Same numerical order as OperatorProfileAssembly, with ordinary (no symmetry)
    # operator inventory. The fixture specifies an accepted frame; it does not claim solver
    # convergence or production qualification.
    chk = something(prepared.wannier_chk)
    matched_stencil = Base.invokelatest(
        extension.match_finite_difference_stencil_to_mmn,
        Base.invokelatest(extension.build_finite_difference_stencil, chk),
        chk,
        mmn,
    )
    centers = Base.invokelatest(extension._tb_centers, model)
    plan = Base.invokelatest(extension._profile_transform_plan, chk, model)
    full_q = Base.invokelatest(
        extension._construct_full_uiu_derivative_overlap_tensor_q,
        chk,
        matched_stencil,
        centers,
        uiu_file;
        formatted = false,
    )
    full_r, full_roundtrip =
        Base.invokelatest(extension._profile_q_to_r, full_q, chk, plan, "derivative_overlap_tensor")
    axial_r, symmetric_r =
        Base.invokelatest(extension.derive_axial_and_symmetric_derivative_overlaps, full_r)
    weighted_connection_q = Base.invokelatest(
        extension._authoritative_hamiltonian_weighted_connection_q,
        chk,
        mmn,
        matched_stencil,
        centers,
        authority,
    )
    weighted_connection_r, connection_roundtrip = Base.invokelatest(
        extension._profile_q_to_r,
        weighted_connection_q,
        chk,
        plan,
        "hamiltonian_weighted_connection",
    )
    weighted_tensor_q, cancellation = Base.invokelatest(
        extension._authoritative_weighted_tensor_q,
        chk,
        matched_stencil,
        centers,
        uhu_file;
        formatted = false,
    )
    weighted_tensor_r, weighted_roundtrip = Base.invokelatest(
        extension._profile_q_to_r,
        weighted_tensor_q,
        chk,
        plan,
        "hamiltonian_weighted_derivative_overlap_tensor",
    )
    weighted_axial_r, _ = Base.invokelatest(
        extension.derive_axial_and_symmetric_derivative_overlaps,
        weighted_tensor_r,
    )
    weighted_axial_r = Base.invokelatest(
        extension.hermitianize_real_space_pairs,
        weighted_axial_r,
        model.r_vectors,
    )
    operators = Base.invokelatest(extension._tb_operators, model)
    specs = Base.invokelatest(extension._operator_profile_specs)
    for (kind, array) in (
        (FG_C.REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION, weighted_connection_r),
        (FG_C.REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR, full_r),
        (FG_C.REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP, weighted_axial_r),
    )
        operators[kind] = FG_C.RealSpaceOperator(specs[kind], model.r_vectors, array)
    end
    # Mathematical format v2 serializes actual arrays, not historical source
    # qualification. "source" is an explicit synthetic-oracle description.
    geometry = Dict{String, Any}(
        "wannier_center_policy" => "keep_input",
        "real_space_replica_policy" => "input",
        "minimum_distance_materialized" => false,
        "mp_grid" => [2, 1, 1],
        "wigner_seitz_tolerance" => 1.0e-5,
        "wigner_seitz_search_size" => 3,
        "replica_mapping_reference" => "synthetic_oracle_input_R_support",
    )
    provenance = Dict{String, Any}(
        "source" => "synthetic_frozen_Gram_energy_numerical_oracle",
        "input_semantics" => "direct_energy_overlap",
    )
    tasks = (FG_C.OperatorTask(quantity = :orbital_magnetization, method = :conventional),)
    output = joinpath(directory, "oam.h5")
    FG_IO.write_real_space_operator_bundle(
        output,
        model.lattice,
        model.r_degeneracies,
        operators;
        profile = nothing,
        operator_tasks = tasks,
        provenance = provenance,
        geometry = geometry,
    )
    geometry_output = joinpath(directory, "geometry.h5")
    FG_IO.write_real_space_operator_bundle(
        geometry_output,
        model.lattice,
        model.r_degeneracies,
        Base.invokelatest(extension._tb_operators, model);
        profile = nothing,
        operator_tasks = (FG_C.OperatorTask(quantity = :berry_curvature),),
        provenance = provenance,
        geometry = geometry,
    )
    return (;
        model,
        prepared,
        chk,
        mmn,
        authority,
        operators,
        source_to_internal,
        output,
        geometry_output,
        geometry,
        provenance,
        tasks,
        stencil = matched_stencil,
        arrays = (;
            full_r,
            axial_r,
            symmetric_r,
            weighted_connection_r,
            weighted_tensor_r,
            weighted_axial_r,
        ),
        roundtrip = (;
            full = full_roundtrip,
            connection = connection_roundtrip,
            weighted = weighted_roundtrip,
        ),
        cancellation,
        uiu_file,
        uhu_file,
        fixture_role = :frozen_numerical_oracle,
        physical_source_qualification = :not_applicable,
    )
end
