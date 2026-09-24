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
    return read_vasp_wavefunctions(source; point_provider = native_vasp_point_provider)
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
