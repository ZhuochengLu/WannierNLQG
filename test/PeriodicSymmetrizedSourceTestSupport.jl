# Engineering data for the interval-checkpoint test.  These are explicitly
# constructed NC wavefunctions, not a DFT/material oracle.  Unlike the retired
# text identity sentinel, all gauge, sewing and MMN values come from these data.
using LinearAlgebra, HDF5, JSON3
isdefined(@__MODULE__, :QEPAWMatrixElementsTestSupport) ||
    include(joinpath(@__DIR__, "QEPAWMatrixElementsTestSupport.jl"))

function periodic_symmetrized_basis(; warning = false)
    p = reshape([0.37, 0.61, 0.83] ./ 4, 3, 1)
    warning && (p[1, 1] += 1.0e-7)
    block = WannierNLQG.WannierProjection.WannierProjectionBlock(
        "X",
        "s",
        p,
        reshape([1], 1, 1),
        reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1),
        false,
    )
    return WannierNLQG.WannierProjection.WannierProjectionBasis([block], 1, false)
end

function periodic_symmetrized_source(directory)
    return WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource(
        joinpath(directory, "periodic-source", "fixture.save");
        band_range = 1:2,
        include_time_reversal = false,
    )
end

function prepare_periodic_symmetrized_inputs(directory)
    w = WannierNLQG.Wannierization
    io = WannierNLQG.IO
    sf = WannierNLQG.SymmetryFoundation
    fixture = QEPAWMatrixElementsTestSupport.write_qe_paw_fixture(
        joinpath(directory, "periodic-source");
        num_kpoints = 2,
    )
    xml = joinpath(fixture.save_directory, "data-file-schema.xml")
    energies = [-1.0 -1.0; 1.0 1.0]
    source_text = replace(
        read(xml, String),
        "<nbnd>1</nbnd>" => "<nbnd>2</nbnd>",
        "<atom name=\"X\">0.0 0.0 0.0</atom>" => "<atom name=\"X\">0.0 0.0 0.0</atom><atom name=\"X\">0.37 0.61 0.83</atom>",
        "<eigenvalues>-0.25</eigenvalues>" => "<eigenvalues>$(join(energies[:, 1] ./ sf.HARTREE_TO_EV, ' '))</eigenvalues>",
    )
    write(xml, source_text)
    center = vec(periodic_symmetrized_basis().blocks[1].positions_fractional)
    for kpoint in 1:2
        k = [(kpoint - 1) / 2, 0.0, 0.0]
        # Same finite kinetic-energy sphere as the existing native profile
        # fixture.  Inversion at kx=1/2 maps Gx to -Gx-1.
        vectors = [
            Int[x, y, z] for x in -3:3 for y in -3:3 for
            z in -3:3 if sum(abs2, [x + k[1], y, z]) <= 40 / pi^2
        ]
        g = hcat(vectors...)
        radius2 = [sum(abs2, k .+ v) for v in vectors]
        first = exp.(-radius2 ./ 2)
        first ./= norm(first)
        second = radius2 .* first
        second .-= dot(first, second) .* first
        second ./= norm(second)
        phase = [cis(-2pi * dot(k .+ v, center)) for v in vectors]
        rotation = [cos(0.37) -sin(0.37); sin(0.37) cos(0.37)]
        coefficients = phase .* (hcat(first, second) * rotation)
        isapprox(
            coefficients' * coefficients,
            Matrix{ComplexF64}(I, 2, 2);
            atol = 1e-14,
            rtol = 0,
        ) || error("PERIODIC_SOURCE_NOT_ORTHONORMAL")
        HDF5.h5open(joinpath(fixture.save_directory, "wfc$(kpoint).hdf5"), "w") do h
            a = HDF5.attributes(h)
            a["igwx"] = length(vectors)
            a["nbnd"] = 2
            a["npol"] = 1
            a["xk"] = k
            a["scale_factor"] = 1.0
            h["MillerIndices"] = g
            ma = HDF5.attributes(h["MillerIndices"])
            for axis in 1:3
                ma["bg$(axis)"] = Matrix{Float64}(I, 3, 3)[axis, :]
            end
            packed = zeros(Float64, 2length(vectors), 2)
            packed[1:2:end, :] .= real.(coefficients)
            packed[2:2:end, :] .= imag.(coefficients)
            h["evc"] = packed
        end
    end
    source = periodic_symmetrized_source(directory)
    gauge_file = joinpath(directory, "periodic-gauge.h5")
    scope = sf.BandRepresentationQualificationScope(
        trues(2, 2),
        falses(2, 2);
        content_authentication = false,
    )
    authority = w.SymmetrizedDFTHamiltonian()
    backend = w.StarCovariantPAWGauge(
        buffer_policy = w.ClosureDrivenBandBuffer(max_extra_bands = 0),
        block_partition_policy = w.HamiltonianWeightedPAWBlockPartition(),
        hamiltonian_correction = w.FarBandCovarianceCorrection(),
    )
    # Finite empty-window witness selects exactly the original unfrozen case.
    @assert all(.!((-2.0 .<= energies) .& (energies .<= -1.5)))
    contract = w.TargetSubspaceQualificationContract(
        scope;
        outer_min_ev = -2.0,
        outer_max_ev = 2.0,
        frozen_min_ev = -2.0,
        frozen_max_ev = -1.5,
        num_wannier = 1,
        scoped_paw_thresholds = backend.thresholds,
        target_complement_maximum_element_ev = authority.completion.target_complement_max_element_ev,
    )
    gauge = w.prepare_symmetry_covariant_wavefunctions(
        w.SymmetryCovariantWavefunctionPreparationConfig(
            source = source,
            authoritative_hamiltonian = authority,
            wavefunction_gauge_backend = backend,
            target_subspace_contract = contract,
            target_band_count = 2,
            output_hdf5 = gauge_file,
        ),
    )
    gauge.status in (:PASS, :STANDARD) ||
        error("PERIODIC_GAUGE_PREPARATION_FAILED: $(gauge.root_cause); $(gauge.diagnostics)")
    gauge_file = something(gauge.output_hdf5)
    isfile(gauge_file) || error("PERIODIC_GAUGE_ARTIFACT_MISSING")
    isfile(splitext(gauge_file)[1] * ".eig") || error("PERIODIC_GAUGE_EIG_ARTIFACT_MISSING")
    template = synthetic_wannierization_fixture().mmn
    rows = [
        join((k, template.neighbors[b, k], template.reciprocal_shifts[:, b, k]...), " ") for
        k in 1:2 for b in 1:6
    ]
    topology = joinpath(directory, "periodic.nnkp")
    topology_text = replace(
        read(fixture.nnkp_file, String),
        r"(?s)begin nnkpts.*?end nnkpts" =>
            "begin nnkpts\n6\n" * join(rows, "\n") * "\nend nnkpts",
    )
    # The producer's actual s projection must use the same physical center as
    # the explicit solver basis, even though random initialization needs no AMN.
    projection_row = "0.0 0.0 0.0 0 1 1"
    count(projection_row, topology_text) == 1 || error("PERIODIC_PROJECTION_ROW_MISMATCH")
    topology_text = replace(topology_text, projection_row => join(center, " ") * " 0 1 1")
    write(topology, topology_text)
    matrices = w.generate_symmetry_completed_qe_paw_matrix_elements(
        source,
        something(gauge.output_hdf5),
        topology;
        artifact_dir = joinpath(directory, "periodic-matrices"),
    )
    matrices.passed || error("PERIODIC_NATIVE_MATRICES_FAILED: $(matrices.diagnostics)")
    cp(matrices.artifacts["mmn"], joinpath(directory, "model.mmn"))
    cp(splitext(gauge_file)[1] * ".eig", joinpath(directory, "model.eig"))
    actual_eig = io.read_wannier_eig(joinpath(directory, "model.eig"))
    size(actual_eig.data) == (2, 2) || error("PERIODIC_EIG_SHAPE_MISMATCH")
    isapprox(actual_eig.data, energies; atol = 1e-12, rtol = 0) ||
        error("PERIODIC_SYMMETRIZED_ENERGY_MISMATCH")
    actual_mmn = io.read_wannier_mmn(joinpath(directory, "model.mmn"))
    actual_mmn.neighbors == template.neighbors || error("PERIODIC_NEIGHBOR_MISMATCH")
    actual_mmn.reciprocal_shifts == template.reciprocal_shifts || error("PERIODIC_SHIFT_MISMATCH")
    all(isfinite, actual_mmn.data) || error("PERIODIC_MMN_NONFINITE")
    write(joinpath(directory, "model.win"), "num_wann = 1\nmp_grid = 2 1 1\n")
    prepared = w.prepare_band_representation(
        w.BandRepresentationPreparationConfig(
            source = source,
            wannierization_mode = :symmetry_adapted,
            sewing_backend = w.AugmentationAwareSewing(),
            wavefunction_gauge_backend = backend,
            authoritative_hamiltonian = authority,
            wavefunction_gauge_hdf5 = gauge_file,
            win_file = joinpath(directory, "model.win"),
            eig_file = joinpath(directory, "model.eig"),
            projection_basis = periodic_symmetrized_basis(),
            output_hdf5 = joinpath(directory, "periodic-representation.h5"),
            outer_min_ev = -2.0,
            outer_max_ev = 2.0,
            frozen_min_ev = -2.0,
            frozen_max_ev = -1.5,
            num_wannier = 1,
            compatibility_policy = :strict,
        ),
    )
    prepared.status in (:PASS, :PASS_WITH_WARNINGS) ||
        error("PERIODIC_REPRESENTATION_PREPARATION_FAILED: $(prepared.diagnostics)")
    representation_file = something(prepared.output_hdf5)
    isfile(representation_file) || error("PERIODIC_REPRESENTATION_ARTIFACT_MISSING")
    write(
        joinpath(directory, "periodic-inputs.json"),
        JSON3.write(Dict("gauge_file" => gauge_file, "representation_file" => representation_file)),
    )
    return prepared
end
