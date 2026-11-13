using HDF5
using LinearAlgebra
using MPI
using SHA
using TOML
using WannierNLQG

const W = WannierNLQG.Wannierization
const S = WannierNLQG.Symmetrization

length(ARGS) in (1, 2) || error("usage: WannierizationWorkflowMpiProbe.jl OUTPUT_ROOT [serial|mpi]")
parallel = length(ARGS) == 2 ? Symbol(ARGS[2]) : :mpi
parallel in (:serial, :mpi) || error("unsupported probe executor")
parallel == :mpi && MPI.Init()
rank = parallel == :mpi ? MPI.Comm_rank(MPI.COMM_WORLD) : 0
root = abspath(first(ARGS))

# Record exact numeric bytes and terminal states; paths, digests, and elapsed time
# belong to artifact identity rather than serial/MPI numerical equivalence.
function record_workflow_payload!(records, prefix, value)
    if value isa WannierNLQG.IO.ScientificInputDefinition
        # Local path/inode/times protect this reader lifetime; complete input
        # bytes, rather than the descriptor's local publication, define equality.
        bytes = WannierNLQG.IO.with_scientific_input_definition_bytes(value) do stream
            read(stream)
        end
        length(bytes) == value.byte_count || error("Incomplete workflow input reference")
        record_workflow_payload!(records, "$(prefix).reference_bytes", bytes)
        record_workflow_payload!(records, "$(prefix).byte_count", value.byte_count)
    elseif value isa Number
        records[prefix] = string(typeof(value), ':', bytes2hex(reinterpret(UInt8, [value])))
    elseif value isa AbstractArray && isbitstype(eltype(value)) && eltype(value) <: Number
        records[prefix] = string(
            eltype(value),
            ':',
            size(value),
            ':',
            bytes2hex(reinterpret(UInt8, vec(Array(value)))),
        )
    elseif value isa AbstractArray
        for index in eachindex(value)
            record_workflow_payload!(records, "$(prefix)[$(index)]", value[index])
        end
    elseif value isa Enum || value isa Symbol
        records[prefix] = string(value)
    elseif value !== nothing && !(value isa AbstractString) && !(value isa AbstractDict)
        for name in fieldnames(typeof(value))
            name in (:elapsed_seconds, :input_summary) && continue
            record_workflow_payload!(records, "$(prefix).$(name)", getfield(value, name))
        end
    end
    return records
end
# Small fixture controls qualify the changed recorder, not the solver.
if rank == 0
    let
        make_definition(bytes) =
            WannierNLQG.IO.scientific_input_definition_bytes() do stream
                write(stream, bytes)
            end
        first_definition = make_definition(UInt8[0x01, 0x02, 0x03])
        independent_definition = make_definition(UInt8[0x01, 0x02, 0x03])
        changed_definition = make_definition(UInt8[0x01, 0x02, 0x04])
        first_definition.state != independent_definition.state ||
            error("Independent fixture lifetime missing")
        encode(value) = record_workflow_payload!(Dict{String, String}(), "fixture", value)
        encode(first_definition) == encode(independent_definition) ||
            error("Equal complete references differ")
        encode(first_definition) != encode(changed_definition) ||
            error("Changed reference bytes ignored")
        encode(1.0) != encode(2.0) || error("Changed scalar bytes ignored")
        encode(ComplexF64[1 + 2im]) != encode(ComplexF64[1 + 3im]) ||
            error("Changed frame bytes ignored")
        open(first_definition.path, "a") do stream
            write(stream, UInt8(0x05))
        end
        stale_rejected = false
        try
            encode(first_definition)
        catch exception
            exception isa ArgumentError || rethrow()
            stale_rejected = true
        end
        stale_rejected || error("Stale input publication was accepted")
        println("WANNIERIZATION_INPUT_REFERENCE_VALUE_ORACLE_CONTROLS=5")
    end
end
win_file = joinpath(root, "synthetic.win")
eig_file = joinpath(root, "synthetic.eig")
mmn_file = joinpath(root, "synthetic.mmn")
representation_file = joinpath(root, "synthetic.band-representation.h5")
checkpoint_file = joinpath(root, "synthetic.wannierization.h5")

energies = [-1.0 -1.0; 1.0 1.0]
neighbors = [2 1; 2 1; 1 2; 1 2; 1 2; 1 2]
shifts = zeros(Int, 3, 6, 2)
shifts[1, 2, 1] = -1
shifts[1, 1, 2] = 1
shifts[2, 3, :] .= 1
shifts[2, 4, :] .= -1
shifts[3, 5, :] .= 1
shifts[3, 6, :] .= -1
identity_operation = WannierNLQG.SymmetryFoundation.SymmetryOperation(
    Matrix{Int}(I, 3, 3),
    zeros(3),
    Matrix{Float64}(I, 3, 3),
)
representation = WannierNLQG.SymmetryFoundation.BandRepresentation(
    "1.4",
    :synthetic,
    false,
    Matrix{Float64}(I, 3, 3),
    2.0pi .* Matrix{Float64}(I, 3, 3),
    (2, 1, 1),
    [0.0 0.0 0.0; 0.5 0.0 0.0],
    energies,
    [identity_operation],
    reshape([1, 2], 1, 2),
    zeros(Int, 3, 1, 2),
    reshape(repeat(Matrix{ComplexF64}(I, 2, 2), 1, 1, 2), 2, 2, 1, 2),
    [1 1; 2 2],
    [1, 2],
    [1, 2],
    [1, 1];
    conventions = Dict("magnetic_structure" => "false"),
    input_sha256 = Dict("fixture" => repeat("0", 64)),
)
block = WannierNLQG.WannierProjection.WannierProjectionBlock(
    "X",
    "s",
    zeros(3, 1),
    reshape([1], 1, 1),
    reshape(Matrix{Float64}(I, 3, 3), 3, 3, 1),
    false,
)
basis = WannierNLQG.WannierProjection.WannierProjectionBasis([block], 1, false)

if rank == 0
    mkpath(root)
    open(win_file, "w") do io
        println(io, "num_wann = 1")
    end
    open(eig_file, "w") do io
        for kpoint in 1:2, band in 1:2
            println(io, "$(band) $(kpoint) $(energies[band, kpoint])")
        end
    end
    open(mmn_file, "w") do io
        println(io, "Created by WannierNLQG MPI workflow probe")
        println(io, "2 2 6")
        for kpoint in 1:2, neighbor in 1:6
            println(
                io,
                "$(kpoint) $(neighbors[neighbor, kpoint]) " *
                "$(shifts[1, neighbor, kpoint]) $(shifts[2, neighbor, kpoint]) " *
                "$(shifts[3, neighbor, kpoint])",
            )
            for source_band in 1:2, target_band in 1:2
                value = source_band == target_band ? 1.0 : 0.0
                println(io, "$(value) 0.0")
            end
        end
    end
    prepared = W.prepare_band_representation(
        W.BandRepresentationPreparationConfig(
            wannierization_mode = :symmetry_adapted,
            win_file = win_file,
            eig_file = eig_file,
            projection_basis = basis,
            band_representation = representation,
            output_hdf5 = representation_file,
            outer_min_ev = -2.0,
            outer_max_ev = 2.0,
            frozen_min_ev = -2.0,
            frozen_max_ev = -0.5,
            num_wannier = 1,
        ),
    )
    prepared.status in (:PASS, :PASS_WITH_WARNINGS) || error("representation preparation failed")
end
parallel == :mpi && MPI.Barrier(MPI.COMM_WORLD)

result = W.construct_wannier_functions(
    W.WannierizationConfig(
        input = W.WannierizationInputConfig(
            wannierization_mode = :symmetry_adapted,
            win_file = win_file,
            eig_file = eig_file,
            mmn_file = mmn_file,
            projection_basis = basis,
            band_representation_hdf5 = representation_file,
            outer_min_ev = -2.0,
            outer_max_ev = 2.0,
            frozen_min_ev = -2.0,
            frozen_max_ev = -0.5,
            num_wannier = 1,
        ),
        solver = W.WannierizationSolverConfig(
            initialization = :random,
            # Root-only MPI persistence of an explicit Z-only trajectory.
            acceleration = W.WannierizationAccelerationConfig(
                schedule = :two_stage,
                z_stability_window = 1,
                disentanglement_objective_tolerance = 1.0e-8,
                z_projector_tolerance = 1.0e-8,
            ),
            parallel = parallel,
            stage_controls = W.WannierizationStageControls(
                dis_num_iter = 8,
                num_iter = 0,
                dis_conv_tol = 1e-8,
                dis_conv_window = 1,
            ),
            random_seed = 0x1234,
        ),
        checkpoint = W.WannierizationCheckpointConfig(
            checkpoint_hdf5 = checkpoint_file,
            num_dump_cycles = 0,
        ),
        runtime = W.WannierizationRuntimeConfig(num_print_cycles = 0),
        output = W.WannierizationOutputConfig(tb_output_formats = ()),
    ),
)
parallel == :mpi && MPI.Barrier(MPI.COMM_WORLD)
if rank == 0
    result.status in (W.COMPLETED, W.COMPLETED_WITH_WARNINGS) ||
        error("MPI workflow returned $(result.status)")
    isfile(checkpoint_file) || error("root-only checkpoint was not written")
    restored = W.read_wannierization_checkpoint_hdf5(checkpoint_file)
    restored.v_matrix == result.v_matrix || error("checkpoint readback changed the frames")
    records = record_workflow_payload!(Dict{String, String}(), "result", result)
    record_workflow_payload!(records, "restored", restored)
    open(joinpath(root, "numerical-payload.toml"), "w") do io
        TOML.print(io, records; sorted = true)
    end
    digest = open(checkpoint_file, "r") do io
        bytes2hex(SHA.sha256(io))
    end
    println("WANNIERIZATION_MPI_WORKFLOW_ROOT_CHECKPOINT=$(digest)")
end
parallel == :mpi && MPI.Barrier(MPI.COMM_WORLD)
parallel == :mpi && MPI.Finalize()
