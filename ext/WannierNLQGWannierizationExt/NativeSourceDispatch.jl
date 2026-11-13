"""Select bounded VASP coefficient storage; retain the explicit dense reference mode."""
function native_vasp_point_provider(loader, count)
    execution = get(task_local_storage(), :wannier_preparation_execution, nothing)
    if execution !== nothing && execution.mode == :dense_reference
        return PlaneWaveKPoint[loader(index) for index in 1:count]
    end
    return preparation_source_vector(loader, PlaneWaveKPoint, count)
end

"""Read VASP coefficients for the coefficient-sewing representation boundary."""
function read_native_source(source::VASPWavefunctionSource; purpose::Symbol = :band_representation)
    purpose == :band_representation || throw(
        ArgumentError(
            "VASP_PAW_AMN_REQUIRED: VASP pseudo coefficients do not provide a physical-overlap " *
            "backend",
        ),
    )
    return read_vasp_wavefunctions(
        source;
        content_authentication = false,
        point_provider = native_vasp_point_provider,
    )
end

"""Read QE coefficients under the explicit representation or overlap purpose contract."""
function read_native_source(
    source::QuantumEspressoWavefunctionSource;
    purpose::Symbol = :band_representation,
)
    execution = get(task_local_storage(), :wannier_preparation_execution, nothing)
    storage =
        execution !== nothing && execution.mode == :dense_reference ? nothing : :bounded_source
    return _read_qe_wavefunctions(source; purpose, point_storage = storage)
end

"""Read VASP geometry and selected-band metadata through the bounded native reader.

Retain its lattice, spin-basis and magnetic-source checks without accessing
coefficient payloads. This metadata does not qualify PAW matrix generation.
"""
function native_vasp_wannier_metadata(source::VASPWavefunctionSource)
    native = read_vasp_wavefunctions(
        source;
        content_authentication = false,
        normalize_coefficients = false,
        point_provider = native_vasp_point_provider,
    )
    points = Matrix{Float64}(undef, length(native.kpoints), 3)
    for k in axes(points, 1)
        points[k, :] .= SymmetryFoundation.native_point_metadata(native, k).k_fractional
    end
    energies = reduce(
        hcat,
        (SymmetryFoundation.native_point_metadata(native, k).energies_ev for k in axes(points, 1)),
    )
    all(isfinite, energies) || throw(ArgumentError("VASP_NATIVE_EIG_NONFINITE"))
    return (
        structure = native.structure,
        kpoints_fractional = points,
        spinor = native.spinor,
        energies_ev = energies,
        input_sha256 = copy(native.input_sha256),
        source_definition = native.source_definition,
    )
end
