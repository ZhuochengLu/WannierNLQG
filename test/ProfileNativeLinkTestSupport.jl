# Test-only production-input builder. Never treats caller-supplied synthetic
# overlap values as native-source data. No source seal or qualification is made.
function profile_native_link_inputs(
    directory,
    topology_template,
    eig,
    gauge,
    parent;
    gauge_hdf5 = nothing,
)
    sf = WannierNLQG.SymmetryFoundation
    paw = parent.PAWMatrixElements
    native = if gauge_hdf5 === nothing
        _profile_native_source(joinpath(directory, "operator-source"), eig.data)
    else
        root = joinpath(directory, "gauge-source")
        (;
            source = sf.QuantumEspressoWavefunctionSource(
                joinpath(root, "fixture.save");
                band_range = 1:2,
                include_time_reversal = false,
            ),
            fixture = (; nnkp_file = joinpath(root, "fixture.nnkp")),
        )
    end
    # Operator readers take band selection from NNKP, not the preparation source.
    operator_source = paw._star_source_with_band_range(native.source, nothing)
    topology = native.fixture.nnkp_file
    text = read(topology, String)
    rows = [
        join(
            (k, topology_template.neighbors[b, k], topology_template.reciprocal_shifts[:, b, k]...),
            " ",
        ) for k in 1:topology_template.num_kpts for b in 1:topology_template.num_neighbors
    ]
    text = replace(
        text,
        r"(?s)begin nnkpts.*?end nnkpts" =>
            "begin nnkpts\n$(topology_template.num_neighbors)\n" *
            join(rows, "\n") *
            "\nend nnkpts",
    )
    write(topology, text)
    native_mmn = paw._with_qe_operator_preparation(operator_source, topology, 2) do
        state = paw._uiu_qe_state(operator_source, topology, 2)
        t = state.topology
        (t.num_bands, t.num_kpts, t.num_neighbors) == (
            topology_template.num_bands,
            topology_template.num_kpts,
            topology_template.num_neighbors,
        ) || error("profile source/topology dimension mismatch")
        t.neighbors == topology_template.neighbors ||
            error("profile neighbor ordering mismatch")
        t.reciprocal_shifts == topology_template.reciprocal_shifts ||
            error("profile G-shift mismatch")
        data = Array{ComplexF64}(undef, t.num_bands, t.num_bands, t.num_neighbors, t.num_kpts)
        for k in 1:t.num_kpts, b in 1:t.num_neighbors
            data[:, :, b, k] .= paw._uiu_center_neighbor_block(state, k, b)
        end
        all(isfinite, data) || error("nonfinite native fixture overlaps")
        PROFILE_IO.WannierMMN(
            t.num_bands,
            t.num_kpts,
            t.num_neighbors,
            data,
            copy(t.neighbors),
            copy(t.reciprocal_shifts),
        )
    end
    target_data = similar(native_mmn.data)
    for k in 1:native_mmn.num_kpts, b in 1:native_mmn.num_neighbors
        right = native_mmn.neighbors[b, k]
        target_data[:, :, b, k] .=
            paw._transform_generation_link(native_mmn.data[:, :, b, k], gauge, k, right)
    end
    target_mmn = PROFILE_IO.WannierMMN(
        native_mmn.num_bands,
        native_mmn.num_kpts,
        native_mmn.num_neighbors,
        target_data,
        copy(native_mmn.neighbors),
        copy(native_mmn.reciprocal_shifts),
    )
    oracle_file = joinpath(directory, "native-oracle.mmn")
    solver_file = joinpath(directory, "target-solver.mmn")
    PROFILE_IO.write_wannier_mmn(oracle_file, native_mmn)
    PROFILE_IO.write_wannier_mmn(solver_file, target_mmn)
    return (;
        source = native.source,
        operator_source,
        topology,
        native_mmn,
        target_mmn,
        oracle_file,
        solver_file,
    )
end

# s-envelope spinor orbitals at actual centers. Use only for the known packet
# fixture; generic Wannier orbital representations require their own basis.
function profile_source_symmetry_plan(source, centers_fractional, spinors, parent)
    sf = WannierNLQG.SymmetryFoundation
    native = parent.PAWMatrixElements._read_augmentation_aware_native_source(source)
    inventory = sf.detect_magnetic_symmetry_inventory(
        native.structure;
        include_time_reversal = false,
        symmetry_tolerance = 1e-5,
    )
    operations = inventory.operations
    n = size(centers_fractional, 2)
    size(centers_fractional, 1) == 3 && size(spinors) == (2, n) ||
        error("profile orbital center/spinor shape mismatch")
    isapprox(spinors' * spinors, Matrix{ComplexF64}(I, n, n); atol = 1e-12, rtol = 0) ||
        error("profile spinors are not orthonormal")
    matrices = zeros(ComplexF64, n, n, length(operations))
    shifts = zeros(Int, 3, n, length(operations))
    for (g, operation) in enumerate(operations)
        operation.antiunitary && error("this fixture has no antiunitary orbital representation")
        rotated_spinors = sf.spin_action_matrix(operation, true) * spinors
        for column in 1:n
            moved =
                operation.rotation_fractional * centers_fractional[:, column] +
                operation.translation_fractional
            for row in 1:n
                delta = moved - centers_fractional[:, row]
                if maximum(abs, delta - round.(delta)) <= 1e-10
                    amplitude = dot(spinors[:, row], rotated_spinors[:, column])
                    if abs(amplitude) > 1e-12
                        matrices[row, column, g] = amplitude
                        shifts[:, column, g] .= round.(Int, delta)
                    end
                end
            end
            isapprox(sum(abs2, matrices[:, column, g]), 1.0; atol = 1e-12, rtol = 0) ||
                error("actual source operation does not close the fixture orbital basis")
        end
    end
    return sf.WannierSymmetryPlan(operations, matrices, shifts)
end

# Keep the same native packet/spin-up orbital when the band basis changes.
# This is a test coordinate conversion, not a repair/normalization or solver step.
function profile_packet_target_frames(gauge, nk)
    frames = zeros(ComplexF64, 2, 1, nk)
    native = ComplexF64[1, 0]
    for k in 1:nk
        if gauge.transforms === nothing
            frames[:, 1, k] .= native
        else
            transform = @view gauge.transforms[:, :, k]
            size(transform) == (2, 2) || error("packet fixture requires full two-band frame")
            frames[:, 1, k] .= transform \ native
            isapprox(transform * frames[:, 1, k], native; atol = 1e-12, rtol = 0) ||
                error("target coordinates do not reproduce the physical packet")
        end
        isapprox(sum(abs2, frames[:, 1, k]), 1.0; atol = 1e-12, rtol = 0) || error(
            "packet frame is not Euclidean-isometric; this fixture cannot represent the source",
        )
    end
    return frames
end
