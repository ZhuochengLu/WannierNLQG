include(joinpath(@__DIR__, "ProfileNativeLinkTestSupport.jl"))
using HDF5
using JSON3
using LinearAlgebra
using SHA

const PROFILE_W = WannierNLQG.Wannierization
const PROFILE_IO = WannierNLQG.IO
const PROFILE_CORE = WannierNLQG.Core

function _profile_modified_config(config; keywords...)
    replacements = NamedTuple(keywords)
    unknown = setdiff(keys(replacements), PROFILE_W.WANNIERIZATION_CONFIG_LEAF_FIELDS)
    isempty(unknown) || throw(ArgumentError("unknown Wannierization config fields: $(unknown)"))
    select(fields) = begin
        selected = Tuple(name for name in keys(replacements) if name in fields)
        NamedTuple{selected}(Tuple(getfield(replacements, name) for name in selected))
    end
    return PROFILE_W._replace_wannierization_config(
        config;
        input = select(PROFILE_W.WANNIERIZATION_INPUT_CONFIG_FIELDS),
        solver = select(PROFILE_W.WANNIERIZATION_SOLVER_CONFIG_FIELDS),
        checkpoint = select(PROFILE_W.WANNIERIZATION_CHECKPOINT_CONFIG_FIELDS),
        runtime = select(PROFILE_W.WANNIERIZATION_RUNTIME_CONFIG_FIELDS),
        output = select(PROFILE_W.WANNIERIZATION_OUTPUT_CONFIG_FIELDS),
    )
end

# Only tag an unsupported wire version; do not synthesize a legacy content seal.
function _profile_publication_for_unsupported_schema(manifest, schema_version)
    schema_version!=PROFILE_IO.OPERATOR_BUNDLE_SCHEMA_VERSION ||
        throw(ArgumentError("fixture requires an unsupported wire tag"))
    return manifest.publication_identity
end

function _profile_geometry(model)
    home = only(
        findall(index -> all(iszero, @view(model.r_vectors[:, index])), axes(model.r_vectors, 2)),
    )
    centers = zeros(Float64, model.num_orbitals, 3)
    for orbital in 1:model.num_orbitals, direction in 1:3
        centers[orbital, direction] =
            real(model.position_r[orbital, orbital, direction, home] / model.r_degeneracies[home])
    end
    return Dict(
        "wannier_center_policy" => "keep_input",
        "real_space_replica_policy" => "input",
        "production_eligible" => false,
        "minimum_distance_materialized" => false,
        "mp_grid" => [2, 1, 1],
        "wannier_center_tolerance" => 1.0e-8,
        "wigner_seitz_tolerance" => 1.0e-5,
        "wigner_seitz_search_size" => 3,
        "raw_wannier_centers_cartesian" => centers,
        "raw_wannier_centers_fractional" => centers * inv(model.lattice),
        "final_wannier_centers_cartesian" => centers,
        "final_wannier_centers_fractional" => centers * inv(model.lattice),
        "center_alignment_lattice_shifts" => zeros(Int, size(centers)),
        "replica_mapping_reference" => "INPUT_SUPPORT_UNMATERIALIZED",
    )
end

# Real native fixture: two orthogonal spinors at each of two k points.
# It is not a claim that an arbitrary legacy MMN/Gram oracle came from this source.
isdefined(@__MODULE__, :QEPAWMatrixElementsTestSupport) ||
    include(joinpath(@__DIR__, "QEPAWMatrixElementsTestSupport.jl"))

# Finite plane-wave basis for the existing 2-bohr cubic cell and 20-Ha cutoff.
# At kx=1/2 the inversion closure is Gx -> -Gx-1, not Gx -> -Gx.
# Use a kinetic-energy sphere about k, rather than appending only the last
# missing vector or using the same G box at every k point.
function _profile_plane_wave_packet(kpoint::Int)
    kpoint in 1:2 || throw(ArgumentError("profile fixture has exactly two k points"))
    k = [(kpoint - 1) / 2, 0.0, 0.0]
    cutoff_radius_squared = 40.0 / pi^2
    vectors = [
        Int[x, y, z] for x in -3:3 for y in -3:3 for
        z in -3:3 if sum(abs2, [x + k[1], y, z]) <= cutoff_radius_squared
    ]
    g = hcat(vectors...)
    # The two equal-species sites are exchanged by {-I | 2*center}.
    # This phase makes the spatial packet an inversion eigenvector, so the
    # two spin states form an exactly closed native band subspace.
    center = [0.37, 0.61, 0.83] ./ 4.0
    packet =
        ComplexF64[exp(-sum(abs2, k .+ v) / 2) * cis(-2pi * dot(k .+ v, center)) for v in vectors]
    packet ./= norm(packet)
    return (; k, g, packet, center, cutoff_radius_squared)
end

function _profile_native_source(directory, energies_ev)
    size(energies_ev) == (2, 2) || error("profile native fixture requires two bands/two k points")
    fixture = QEPAWMatrixElementsTestSupport.write_qe_paw_fixture(
        directory;
        spinor = true,
        num_kpoints = 2,
    )
    xml = joinpath(fixture.save_directory, "data-file-schema.xml")
    text = replace(read(xml, String), "<nbnd>1</nbnd>" => "<nbnd>2</nbnd>")
    # A cubic one-site structure has axis-permuting symmetries that do not
    # preserve this deliberately anisotropic 2x1x1 mesh. Two generic sites keep
    # the source's actual detected symmetry compatible with that mesh; do not
    # bypass the production k-point action or supply fabricated sewing matrices.
    text = replace(
        text,
        "<atom name=\"X\">0.0 0.0 0.0</atom>" => "<atom name=\"X\">0.0 0.0 0.0</atom><atom name=\"X\">0.37 0.61 0.83</atom>",
    )
    row = Ref(0)
    text = replace(
        text,
        r"<eigenvalues>[^<]*</eigenvalues>" =>
            _ -> begin
                row[] += 1
                values = energies_ev[:, row[]] ./ WannierNLQG.SymmetryFoundation.HARTREE_TO_EV
                "<eigenvalues>" * join(values, " ") * "</eigenvalues>"
            end,
    )
    write(xml, text)
    for kpoint in 1:2
        data = _profile_plane_wave_packet(kpoint)
        ng = size(data.g, 2)
        HDF5.h5open(joinpath(fixture.save_directory, "wfc$(kpoint).hdf5"), "r+") do h
            for (name, value) in (("nbnd", 2), ("igwx", ng))
                HDF5.delete_attribute(h, name)
                HDF5.attributes(h)[name] = value
            end
            HDF5.delete_object(h, "MillerIndices")
            h["MillerIndices"] = data.g
            attributes = HDF5.attributes(h["MillerIndices"])
            for axis in 1:3
                attributes["bg$(axis)"] = Matrix{Float64}(I, 3, 3)[axis, :]
            end
            packed = zeros(Float64, 4ng, 2)
            packed[1:2:2ng, 1] .= real.(data.packet)
            packed[2:2:2ng, 1] .= imag.(data.packet)
            packed[(2ng + 1):2:4ng, 2] .= real.(data.packet)
            packed[(2ng + 2):2:4ng, 2] .= imag.(data.packet)
            HDF5.delete_object(h, "evc")
            h["evc"] = packed
        end
    end
    source = WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
        fixture.save_directory;
        band_range = 1:2,
        include_time_reversal = false,
    )
    return (; source, fixture)
end

# Preserve the solver's actual selection, including explicit frozen states and
# degeneracy closure. The finite bounds below are only this fixture's existing
# preparation witness; they must select exactly the same states.
function _profile_preparation_scope(config, eig)
    parent = first(PROFILE_W._load_wannierization_extension!())
    scope = Base.invokelatest(parent.OperatorExport._operator_qualification_scope, config, eig)
    witness = _profile_modified_config(
        config;
        outer_min_ev = -2.0,
        outer_max_ev = 2.0,
        frozen_min_ev = -2.0,
        frozen_max_ev = 0.0,
        frozen_states = Tuple{Int, Int}[],
    )
    expected = Base.invokelatest(parent.OperatorExport._operator_qualification_scope, witness, eig)
    scope.outer_mask == expected.outer_mask && scope.frozen_mask == expected.frozen_mask ||
        throw(ArgumentError("PROFILE_PREPARATION_SELECTION_MISMATCH"))
    return scope
end

# Actual two-band/two-k target data for the symmetrized protocol fixture.
# This full-target case does not qualify a nonempty parent complement.
function _profile_symmetrized_gauge_config(source, eig, output_hdf5; target_config = nothing)
    size(eig.data) == (2, 2) || error("symmetrized profile fixture requires two bands/two k points")
    all(isfinite, eig.data) || error("symmetrized profile fixture requires finite energies")
    outer_min_ev, outer_max_ev = -2.0, 2.0
    frozen_min_ev, frozen_max_ev = -2.0, 0.0
    outer = (outer_min_ev .<= eig.data) .& (eig.data .<= outer_max_ev)
    frozen = (frozen_min_ev .<= eig.data) .& (eig.data .<= frozen_max_ev)
    # The fixture is intentionally closed in its full two-band space; reject
    # changes that would silently turn it into a different target/complement case.
    all(outer) ||
        error("symmetrized profile fixture energies must lie in its declared outer window")
    scope = WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope(
        outer,
        frozen;
        content_authentication = false,
    )
    target_config === nothing || (scope = _profile_preparation_scope(target_config, eig))
    thresholds = PROFILE_W.PAWGaugeThresholds()
    authority = PROFILE_W.SymmetrizedDFTHamiltonian()
    contract = PROFILE_W.TargetSubspaceQualificationContract(
        scope;
        outer_min_ev,
        outer_max_ev,
        frozen_min_ev,
        frozen_max_ev,
        num_wannier = target_config === nothing ? 2 : target_config.input.num_wannier,
        scoped_paw_thresholds = thresholds,
        target_complement_maximum_element_ev = authority.completion.target_complement_max_element_ev,
    )
    gauge = PROFILE_W.StarCovariantPAWGauge(
        buffer_policy = PROFILE_W.ClosureDrivenBandBuffer(max_extra_bands = 0),
        thresholds = thresholds,
        block_partition_policy = PROFILE_W.HamiltonianWeightedPAWBlockPartition(),
        hamiltonian_correction = PROFILE_W.FarBandCovarianceCorrection(
            qualification_mode = :standard,
        ),
    )
    return PROFILE_W.SymmetryCovariantWavefunctionPreparationConfig(
        source = source,
        authoritative_hamiltonian = authority,
        target_subspace_contract = contract,
        construction_policy = :standard,
        wavefunction_gauge_backend = gauge,
        target_band_count = 2,
        output_hdf5 = output_hdf5,
    )
end

function _profile_write_gauge(directory, route, eig; target_config = nothing)
    route == :ordinary && return nothing
    native = _profile_native_source(joinpath(directory, "gauge-source"), eig.data)
    if route == :symmetrized_sawf
        config = _profile_symmetrized_gauge_config(
            native.source,
            eig,
            joinpath(directory, "$(route)-gauge.h5");
            target_config,
        )
        result = PROFILE_W.prepare_symmetry_covariant_wavefunctions(config)
        result.output_hdf5 === nothing &&
            error("current symmetrized gauge preparation produced no HDF5: $(result.root_cause)")
        return something(result.output_hdf5)
    end
    authority = PROFILE_W.NativeDFTHamiltonian()
    thresholds = PROFILE_W.PAWGaugeThresholds()
    target =
        target_config === nothing ? nothing :
        PROFILE_W.TargetSubspaceQualificationContract(
            _profile_preparation_scope(target_config, eig);
            outer_min_ev = -2.0,
            outer_max_ev = 2.0,
            frozen_min_ev = -2.0,
            frozen_max_ev = 0.0,
            num_wannier = target_config.input.num_wannier,
            scoped_paw_thresholds = thresholds,
        )
    result = PROFILE_W.prepare_symmetry_covariant_wavefunctions(
        PROFILE_W.SymmetryCovariantWavefunctionPreparationConfig(
            source = native.source,
            authoritative_hamiltonian = authority,
            target_subspace_contract = target,
            construction_policy = :standard,
            target_band_count = 2,
            wavefunction_gauge_backend = PROFILE_W.StarCovariantPAWGauge(
                buffer_policy = PROFILE_W.ClosureDrivenBandBuffer(max_extra_bands = 0),
            ),
            output_hdf5 = joinpath(directory, "$(route)-gauge.h5"),
        ),
    )
    # A failed preparation is an error; never manufacture a successful capsule.
    result.output_hdf5 === nothing &&
        error("current toy gauge preparation produced no HDF5: $(result.root_cause)")
    return something(result.output_hdf5)
end

function _profile_gauge_contract(
    parent_extension,
    route,
    num_bands,
    num_kpoints;
    artifact_path = nothing,
    source = nothing,
)
    paw = parent_extension.PAWMatrixElements
    route == :ordinary &&
        return Base.invokelatest(paw._identity_band_frame_contract, num_bands, num_kpoints)
    artifact_path === nothing && error("SAWF fixture requires an actual gauge HDF5")
    authority =
        route == :symmetrized_sawf ? PROFILE_W.SymmetrizedDFTHamiltonian() :
        PROFILE_W.NativeDFTHamiltonian()
    return Base.invokelatest(
        paw._generation_band_gauge_contract,
        source,
        authority,
        artifact_path,
        num_bands,
        num_kpoints;
        construction_policy = :standard,
    )
end

function _profile_symmetry_plan(route, num_wannier; source, centers_fractional, spinors, parent)
    route == :ordinary && return nothing
    size(centers_fractional, 2) == num_wannier || error("profile center count mismatch")
    return profile_source_symmetry_plan(source, centers_fractional, spinors, parent)
end

function _profile_write_inputs(
    directory,
    mmn,
    authority,
    gauge_contract,
    parent_extension;
    gauge_hdf5 = nothing,
    eig = nothing,
    target_config,
)
    energies =
        eig === nothing ? hcat([real.(diag(authority.matrices_ev[:, :, k])) for k in 1:2]...) :
        eig.data
    links = profile_native_link_inputs(
        directory,
        mmn,
        PROFILE_IO.WannierEIG(2, 2, energies),
        gauge_contract,
        parent_extension;
        gauge_hdf5,
    )
    native = (; source = links.operator_source)
    mmn = links.target_mmn
    mmn_file = links.solver_file
    oracle_mmn_file = links.oracle_file
    topology = links.topology
    eig_file = joinpath(directory, "fixture.eig")
    PROFILE_IO.write_wannier_eig(eig_file, PROFILE_IO.WannierEIG(2, 2, energies))
    spn_file = joinpath(directory, "fixture.spn")
    spn_provenance = spn_file * ".json"
    spn = PROFILE_W.generate_qe_paw_spn(
        native.source,
        topology;
        output_spn_file = spn_file,
        provenance_json = spn_provenance,
        max_cached_wavefunction_kpoints = 2,
    )
    spn.passed || error("actual profile SPN generation failed")
    # Bind the same realized outer/frozen scope consumed by assembly. Do not use
    # constructor defaults (full_parent) for a scoped solver contract.
    scoped_config = _profile_modified_config(
        target_config;
        source = links.source,
        mmn_file = mmn_file,
        eig_file = eig_file,
        wavefunction_gauge_hdf5 = gauge_hdf5,
        authoritative_hamiltonian = authority.authority == "native_dft" ?
                                    PROFILE_W.NativeDFTHamiltonian() :
                                    PROFILE_W.SymmetrizedDFTHamiltonian(),
    )
    target = Base.invokelatest(
        parent_extension.OperatorExport._wannier_operator_target_contract,
        scoped_config,
        PROFILE_IO.WannierEIG(2, 2, energies),
        mmn,
        oracle_mmn_file,
        mmn_file,
    )
    backend =
        authority.authority == "native_dft" ? PROFILE_W.NativeDFTHamiltonian() :
        PROFILE_W.SymmetrizedDFTHamiltonian()
    uiu_file = joinpath(directory, "fixture.uIu")
    uiu_provenance = uiu_file * ".json"
    uiu = PROFILE_W.generate_wannier_uiu(
        PROFILE_W.WannierUIUGenerationConfig(
            source = native.source,
            topology_file = topology,
            output_file = uiu_file,
            provenance_json = uiu_provenance,
            oracle_mmn_file = oracle_mmn_file,
            target_contract = target,
            authoritative_hamiltonian = backend,
            wavefunction_gauge_hdf5 = gauge_hdf5,
            max_cached_wavefunction_kpoints = 2,
        ),
    )
    uiu.passed || error("actual profile uIu generation/MMN oracle failed")
    files = Dict{Symbol, String}()
    sidecars = Dict{Symbol, String}()
    for operator in (:uHu, :sIu, :sHu)
        path = joinpath(directory, "fixture.$operator")
        sidecar = path * ".json"
        config = PROFILE_W.WannierHamiltonianOperatorGenerationConfig(
            source = native.source,
            topology_file = topology,
            eig_file = eig_file,
            authoritative_mmn_file = oracle_mmn_file,
            target_contract = target,
            output_file = path,
            provenance_json = sidecar,
            spn_file = operator == :uHu ? nothing : spn_file,
            spn_provenance_file = operator == :uHu ? nothing : spn_provenance,
            authoritative_hamiltonian = backend,
            wavefunction_gauge_hdf5 = gauge_hdf5,
            max_cached_wavefunction_kpoints = 2,
        )
        result =
            getproperty(PROFILE_W, Symbol("generate_wannier_", lowercase(String(operator))))(config)
        result.artifact_published || error("actual profile $operator generation failed")
        files[operator] = path;
        sidecars[operator] = sidecar
    end
    spn_attestation = Base.invokelatest(
        parent_extension.PAWMatrixElements.read_and_validate_spn_provenance,
        spn_provenance,
        spn_file;
        expected_num_bands = mmn.num_bands,
        expected_num_kpoints = mmn.num_kpts,
        target_authority = backend,
        gauge_definition = gauge_contract.gauge_definition,
        band_frame_transform_definition = gauge_contract.transform_definition,
        band_frame_contract_definition = gauge_contract.contract_definition,
    )
    return (;
        mmn_file,
        oracle_mmn_file,
        target_mmn = mmn,
        target_contract = target,
        links,
        spn_file,
        spn_provenance,
        spn_attestation,
        uiu_file,
        uhu_file = files[:uHu],
        siu_file = files[:sIu],
        shu_file = files[:sHu],
        uiu_provenance,
        uhu_provenance = sidecars[:uHu],
        siu_provenance = sidecars[:sIu],
        shu_provenance = sidecars[:sHu],
    )
end

function _profile_model_semantics(authority)
    # Source/frame/scope information must come from actual assembly provenance.
    # Authority alone cannot establish target masks, convergence or production use.
    return Dict{String, Any}(
        "authoritative_hamiltonian" => authority.authority,
        "authoritative_hamiltonian_definition" => authority.definition,
    )
end

# Build the actual consumed-input snapshot for a synthetic accepted-state test.
# This records values; it does not grant source/physics/convergence qualification.
function _profile_snapshot_result(parent, result, fixture, config)
    solver = parent.SolverCheckpoint
    definition = Base.invokelatest(
        solver._restart_input_definition,
        config,
        fixture.representation,
        fixture.mmn,
        nothing,
        solver.effective_wannierization_algorithms(config, fixture.representation),
        solver.symmetry_constraints_applied(config, fixture.representation),
    )
    sources = Base.invokelatest(parent.OperatorExport.operator_profile_source_files, config)
    definition.auxiliary_sources["operator_profile_sources"] =
        PROFILE_IO.scientific_source_collection_definition(sources)
    old = something(result.restart_state)
    state = PROFILE_W.WannierizationRestartState(
        (
            name === :input_definition ? definition : getfield(old, name) for
            name in fieldnames(PROFILE_W.WannierizationRestartState)
        )...,
    )
    return parent.WannierizationInternalSupport.updated_wannierization_result(
        result;
        restart_state = state,
    )
end
