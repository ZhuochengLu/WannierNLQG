using WannierNLQG

# This is 2e7 times tighter than the default symmetry tolerance while removing
# platform BLAS/libm last-bit differences from the frozen inventory identity.
const TB_DETECTION_INVENTORY_FLOAT_QUANTUM = 1.0e-12

# Resolve the Foundation-owned frozen TB detector.
function detector_contract()
    owner = WannierNLQG.SymmetryFoundation
    return owner, owner.detect_tb_compatibility_symmetry_operations
end

# Build fixed structures spanning Types I--IV and representative labels.
function detection_fixtures(owner)
    structure = getproperty(owner, :CrystalStructure)
    return [
        "triclinic" => structure(
            [1.0 0.0 0.0; 0.2 1.3 0.0; 0.1 0.3 1.7],
            ["X"],
            zeros(3, 1);
            magnetic_moments_cartesian = reshape([0.31, 0.47, 0.83], 3, 1),
        ),
        "GaAs" => structure(
            5.65 / 2 .* [0.0 1 1; 1 0 1; 1 1 0],
            ["Ga", "As"],
            [0.0 0.25; 0.0 0.25; 0.0 0.25],
        ),
        "Fe" => structure(
            2.87 / 2 .* [-1.0 1 1; 1 -1 1; 1 1 -1],
            ["Fe"],
            zeros(3, 1);
            magnetic_moments_cartesian = reshape([0.0, 0.0, 1.0], 3, 1),
        ),
        "NiO" => structure(
            4.2 .* [1.0 0.5 0.5; 0.5 1 0.5; 0.5 0.5 1],
            ["Ni", "Ni", "O", "O"],
            [0.0 0.5 0.25 0.75; 0.0 0.5 0.25 0.75; 0.0 0.5 0.25 0.75];
            magnetic_moments_cartesian = [0.0 0 0 0; 0 0 0 0; 1 -1 0 0],
        ),
        "GeS" => structure(
            [4.30 0.0 0.0; 0.0 3.65 0.0; 0.0 0.0 10.48],
            ["Ge", "Ge", "S", "S"],
            [0.0 0.5 0.0 0.5; 0.12 0.62 0.38 0.88; 0.25 0.75 0.25 0.75],
        ),
        "Cr" => structure(
            2.88 / 2 .* [-1.0 1 1; 1 -1 1; 1 1 -1],
            ["Cr"],
            zeros(3, 1);
            magnetic_moments_cartesian = reshape([0.0, 0.0, 1.0], 3, 1),
        ),
    ]
end

"""Write finite floating values as deterministic signed quantization indices."""
function write_inventory_floats(io::IO, values)
    for value in values
        isfinite(value) || error("TB detection inventory contains a non-finite value")
        write(io, round(Int64, value / TB_DETECTION_INVENTORY_FLOAT_QUANTUM))
    end
    return io
end

# Write a module-neutral byte stream of every scientific operation field.
function write_inventory(io::IO, owner, detector)
    write(io, codeunits("wanniernlqg.tb-detection-inventory/1.0\n"))
    for (label, structure) in detection_fixtures(owner)
        operations = Base.invokelatest(detector, structure; include_time_reversal = true)
        label_bytes = collect(codeunits(label))
        write(io, UInt8(length(label_bytes)))
        write(io, label_bytes)
        write(io, Int64(length(operations)))
        for operation in operations
            write(io, Matrix{Int64}(operation.rotation_fractional))
            write_inventory_floats(io, operation.translation_fractional)
            write_inventory_floats(io, operation.rotation_cartesian)
            write(io, UInt8(operation.antiunitary))
        end
    end
    return io
end
