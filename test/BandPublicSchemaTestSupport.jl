module BandPublicSchemaTestSupport

using WannierNLQG
using LinearAlgebra

# One scalar s orbital, or its two spin components, at the origin.
function single_site_s_basis(; spinor::Bool = false)
    block = WannierNLQG.WannierProjection.WannierProjectionBlock(
        "X",
        "s",
        zeros(3, 1),
        reshape(collect(1:(spinor ? 2 : 1)), spinor ? 2 : 1, 1),
        reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1),
        spinor,
    )
    return WannierNLQG.WannierProjection.WannierProjectionBasis([block], spinor ? 2 : 1, spinor)
end

# Raw two-k-point spinor input used by both original and current preparation workflows.
function raw_time_reversal_representation_fixture(;
    trim::Bool = false,
    corrupt_second::Bool = false,
)
    identity_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
    )
    theta_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
        Matrix{Int}(I, 3, 3),
        zeros(3),
        Matrix{Float64}(I, 3, 3),
        true,
    )
    kpoints = trim ? zeros(1, 3) : [0.25 0.0 0.0; 0.75 0.0 0.0]
    num_kpoints = size(kpoints, 1)
    kpoint_map = trim ? ones(Int, 2, 1) : [1 2; 2 1]
    shifts = zeros(Int, 3, 2, num_kpoints)
    trim || (shifts[1, 2, :] .= -1)
    theta = ComplexF64[0 1; -1 0]
    sewing = zeros(ComplexF64, 2, 2, 2, num_kpoints)
    for kpoint in 1:num_kpoints
        sewing[:, :, 1, kpoint] .= Matrix{ComplexF64}(I, 2, 2)
        sewing[:, :, 2, kpoint] .= theta
    end
    corrupt_second && num_kpoints == 2 && (sewing[:, :, 2, 2] .*= -1)
    representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
        "1.1",
        :synthetic,
        true,
        Matrix{Float64}(I, 3, 3),
        2.0pi .* Matrix{Float64}(I, 3, 3),
        trim ? (1, 1, 1) : (2, 1, 1),
        kpoints,
        zeros(2, num_kpoints),
        [identity_operation, theta_operation],
        kpoint_map,
        shifts,
        sewing,
        ones(Int, 2, num_kpoints),
        [1],
        ones(Int, num_kpoints),
        trim ? [1] : [1, 2];
        conventions = Dict(
            "sewing" => "rows target bands, columns source bands",
            "antiunitary_gauge_transform" => "B'=U_target'*B*conj(U_source)",
        ),
        input_sha256 = Dict("fixture" => repeat("1", 64)),
    )
    return representation
end

# Prepare complete public storage metadata through the production workflow while
# retaining the supplied scientific representation and its actual validation state.
function prepare_public_band_fixture(
    representation;
    directory::AbstractString,
    projection_basis,
    eig_file = nothing,
    output_hdf5 = nothing,
    construction_policy = :diagnostic,
    sewing_backend = WannierNLQG.Wannierization.CoefficientMappingSewing(),
)
    mkpath(directory)
    win_file = joinpath(directory, "public-schema-fixture.win")
    write(win_file, "begin projections\nX:s\nend projections\n")
    energy_file = if eig_file === nothing
        path = joinpath(directory, "public-schema-fixture.eig")
        open(path, "w") do io
            for kpoint in axes(representation.energies_ev, 2),
                band in axes(representation.energies_ev, 1)

                println(io, band, " ", kpoint, " ", repr(representation.energies_ev[band, kpoint]))
            end
        end
        path
    else
        String(eig_file)
    end
    config = WannierNLQG.Wannierization.BandRepresentationPreparationConfig(
        wannierization_mode = :symmetry_adapted,
        win_file = win_file,
        eig_file = energy_file,
        projection_basis = projection_basis,
        band_representation = representation,
        sewing_backend = sewing_backend,
        compatibility_policy = :warn,
        construction_policy = construction_policy,
        output_hdf5 = output_hdf5,
    )
    return WannierNLQG.Wannierization.prepare_band_representation(config)
end

# Persist only through normal preparation: this helper never edits a stored schema header.
function write_prepared_time_reversal_fixture(directory::AbstractString)
    output = joinpath(directory, "normal-prepared-band.h5")
    prepared = prepare_public_band_fixture(
        raw_time_reversal_representation_fixture();
        directory,
        projection_basis = single_site_s_basis(spinor = true),
        output_hdf5 = output,
        construction_policy = :strict,
    )
    return output, prepared
end

end
