using WannierNLQG

quantity, directory, expected_definition = ARGS
result =
    quantity == "linear_transport" ? read_linear_transport_result(directory) :
    quantity == "orbital_magnetization" ? read_orbital_magnetization_result(directory) :
    error("unsupported quantity")
result.metadata["fermi_energies_definition"] == expected_definition ||
    error("probe axis definition mismatch")
println(
    "FERMI_VECTOR_FRESH_READBACK_PASS quantity=$(quantity) count=$(length(result.fermi_energies))",
)
