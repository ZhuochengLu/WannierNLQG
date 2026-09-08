"""Read VASP coefficients for the coefficient-sewing representation boundary."""
function read_native_source(source::VASPWavefunctionSource; purpose::Symbol = :band_representation)
    purpose == :band_representation || throw(
        ArgumentError(
            "VASP_PAW_AMN_REQUIRED: VASP pseudo coefficients do not provide a physical-overlap " *
            "backend",
        ),
    )
    return read_vasp_wavefunctions(source)
end

"""Read QE coefficients under the explicit representation or overlap purpose contract."""
function read_native_source(
    source::QuantumEspressoWavefunctionSource;
    purpose::Symbol = :band_representation,
)
    return _read_qe_wavefunctions(source; purpose)
end
