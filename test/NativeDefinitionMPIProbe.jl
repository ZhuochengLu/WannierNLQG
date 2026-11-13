using MPI, JSON3, WannierNLQG, LinearAlgebra
const R = WannierNLQG.Runtime
const C = WannierNLQG.Core
const IOLayer = WannierNLQG.IO

MPI.Init()
R.bundle_mpi_initialize()
const COMM = R.bundle_mpi_comm_world()
const RANK = R.bundle_mpi_comm_rank(COMM)
const RANKS = R.bundle_mpi_comm_size(COMM)
const DESTINATION = abspath(only(ARGS))
const CASES = [
    "real_space_equal",
    "analytic_equal",
    "localized_equal",
    "one_ulp_difference",
    "late_parameter_difference",
    "definition_length_difference",
    "unsupported_parameter",
    "retired_owner",
    "recovery_equal",
]

"""Return a finite constant analytic Hamiltonian; no executable code crosses ranks."""
probe_hamiltonian(k, parameters) = ComplexF64[0.4 0.2; 0.2 -0.4]

"""Construct exact same data or one deliberately different declared input on the last rank."""
function probe_input(name)
    values = ones(10_000)
    changed = RANKS > 1 && RANK == RANKS - 1
    name == "late_parameter_difference" && changed && (values[9000] = 2.0)
    name == "definition_length_difference" && changed && push!(values, 1.0)
    parameters =
        name == "unsupported_parameter" && RANK == RANKS - 1 ? Ref(1) : (; control_data = values)
    lattice = Matrix{Float64}(I, 3, 3)
    hopping = reshape(ComplexF64[0.4, 0.2, 0.2, -0.4], 2, 2, 1)
    name == "one_ulp_difference" && changed && (hopping[1, 1, 1] = nextfloat(0.4))
    if name == "analytic_equal"
        return AnalyticKInput(;
            hamiltonian = probe_hamiltonian,
            num_orbitals = 2,
            lattice,
            basis = :fixed_orthonormal,
            source_file = @__FILE__,
            parameters,
        )
    elseif name == "localized_equal"
        model = C.NonorthogonalLocalizedModel(;
            lattice,
            r_vectors = zeros(Int, 3, 1),
            hamiltonian_r = hopping,
            overlap_r = reshape(Matrix{ComplexF64}(I, 2, 2), 2, 2, 1),
            position_r = zeros(ComplexF64, 2, 2, 3, 1),
        )
        return C.NonorthogonalLocalizedInput(model; parameters)
    end
    return RealSpaceTBInput(;
        lattice,
        r_vectors = zeros(Int, 3, 1),
        hamiltonian_r = hopping,
        orbital_positions = zeros(3, 2),
        position_model = :point_orbitals,
        parameters,
    )
end

"""Use the normal public configuration adoption and native task compilation."""
function probe_config(input, directory)
    task = TaskSpec(
        id = "agreement",
        quantity = "SC",
        method = "Conventional",
        physics = OpticalParameters(photon_energies = [0.2], fermi_energy = 0.0, temperature = 0.0),
        numerics = Numerics(broadening = 0.04),
        observable = FullTensor(),
    )
    return only(
        R.compile_task_configs(
            TaskConfig(;
                model = input,
                sampling = BZMesh(k_mesh = (1, 1, 1), spatial_dimension = 3),
                tasks = [task],
                execution = ExecutionOptions(fourier_backend = "direct"),
                output = OutputOptions(
                    output_root = directory,
                    system_name = "native_agreement",
                    progress_enabled = false,
                ),
            ),
        ),
    )
end

rows = Any[]
try
    @assert RANKS in (1, 2, 3)
    @assert Threads.nthreads() == 1
    BLAS.set_num_threads(1)
    for name in CASES
        cfg = probe_config(probe_input(name), joinpath(DESTINATION, name))
        specs = R.validate_config(cfg)
        generations = [
            R.bundle_mpi_bcast(
                RANK == owner ? C.scientific_data_generation(cfg.native_model_input) : nothing,
                owner,
                COMM,
            ) for owner in 0:(RANKS - 1)
        ]
        distinct_owners = length(unique(generations)) == RANKS
        name == "retired_owner" &&
            RANK == RANKS - 1 &&
            C.invalidate_scientific_data!(cfg.native_model_input)
        rejected = false
        message = ""
        metadata_binding_valid = false
        loaded_same_owner = false
        try
            context = R.prepare_run_context(cfg, specs)
            metadata_binding_valid = context.model_identity == generations[1]
            R.load_native_runtime_sources(context, cfg)
            loaded_same_owner =
                context.native_admission.owner === R._native_input_owner(cfg.native_model_input)
        catch exception
            rejected = true
            message = sprint(showerror, exception)
        end
        expected_rejection =
            name in ("unsupported_parameter", "retired_owner") ||
            RANKS > 1 && name in
            ("one_ulp_difference", "late_parameter_difference", "definition_length_difference")
        # All ranks enter the same post-failure collectives; a recovery case follows.
        outcomes = [
            R.bundle_mpi_bcast(RANK == owner ? rejected : nothing, owner, COMM) for
            owner in 0:(RANKS - 1)
        ]
        R.bundle_mpi_barrier(COMM)
        no_output_created = !isdir(cfg.output_root)
        okay =
            all(value == expected_rejection for value in outcomes) &&
            distinct_owners &&
            (
                expected_rejection ? rejected && !isempty(message) && no_output_created :
                !rejected && metadata_binding_valid && loaded_same_owner
            )
        push!(
            rows,
            (;
                name,
                passed = okay,
                expected_rejection,
                rejected,
                metadata_binding_valid,
                loaded_same_owner,
                distinct_owners,
                no_output_created,
                message,
            ),
        )
        RANK == 0 && println("NATIVE_DEFINITION_MPI_CASE ", name, " passed=", okay)
        flush(stdout)
    end
    payload = (;
        schema = "wanniernlqg.native-definition-mpi-rank/2",
        source_root = Base.pkgdir(WannierNLQG),
        rank = RANK,
        ranks = RANKS,
        pid = getpid(),
        julia_version = string(VERSION),
        mpi_library = MPI.Get_library_version(),
        rows,
        passed = all(row.passed for row in rows),
        rank_actual_exit = "NOT_OBSERVED_BY_CORE",
        kernel_containment = "UNKNOWN",
    )
    open(joinpath(DESTINATION, "rank-$(RANK).json"), "w") do stream
        JSON3.write(stream, payload)
    end
    R.bundle_mpi_barrier(COMM)
    @assert payload.passed
finally
    MPI.Initialized() && !MPI.Finalized() && MPI.Finalize()
end
