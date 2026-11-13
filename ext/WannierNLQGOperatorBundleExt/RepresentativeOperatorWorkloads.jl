using PrecompileTools: @setup_workload, @compile_workload

# Reuse the facade builders after operator-bundle extension activation.
_representative_operator_configs(root; kwargs...) =
    WannierNLQG._first_use_operator_configs(root; kwargs...)

# Construct the observed singleton public input shapes for compiler capture.
# JC keeps the existing three-Cartesian-axis contract; IC/ISC use two axes.
function _representative_singleton_operator_configs(configs, root)
    singletons = WannierNLQG.TaskConfig[]
    for (family, quantity) in ((:optical, "IC"), (:spin, "ISC"), (:optical, "JC"))
        shared = getproperty(configs, family)
        task = only(filter(task -> task.quantity == quantity, shared.tasks))
        numerics =
            quantity == "JC" ? WannierNLQG.Numerics() :
            WannierNLQG._first_use_optical_numerics(
                quantity,
                "Conventional";
                broadening_type = "Gaussian",
            )
        singleton = WannierNLQG.TaskSpec(
            id = task.id,
            quantity = task.quantity,
            method = task.method,
            physics = task.physics,
            numerics = numerics,
            observable = task.observable,
        )
        push!(
            singletons,
            WannierNLQG._first_use_config(
                shared.model,
                WannierNLQG.BZMesh(k_mesh = (2, 2), spatial_dimension = quantity == "JC" ? 3 : 2),
                [singleton],
                joinpath(root, "single_" * lowercase(quantity)),
            ),
        )
    end
    return singletons
end

# Preserve both supported geometry routes: omitted defaults are exact, while
# public examples explicitly request positive-eta finite differences. A shared
# four-task microcalculation covers their common workspace and selector ranks.
function _representative_regularized_geometry_config(configs, root)
    shared = configs.full_geometry
    tasks = WannierNLQG.TaskSpec[]
    for quantity in ("QMK", "QMDK", "QMQK", "QCSK")
        task = only(filter(task -> task.quantity == quantity, shared.tasks))
        numerics =
            quantity == "QMK" ? WannierNLQG.Numerics(denominator_regularization = 0.001) :
            WannierNLQG.Numerics(
                denominator_regularization = 0.001,
                finite_difference_step = 0.0001,
            )
        push!(
            tasks,
            WannierNLQG.TaskSpec(
                id = task.id,
                quantity = task.quantity,
                method = task.method,
                physics = task.physics,
                numerics = numerics,
                observable = task.observable,
            ),
        )
    end
    return WannierNLQG._first_use_config(
        shared.model,
        shared.sampling,
        tasks,
        joinpath(root, "regularized_geometry"),
    )
end

@setup_workload let
    WannierNLQG._first_use_require_serial()
    root = mktempdir()
    try
        # Published payloads remain immutable; receipts belong to these private copies.
        inputs = joinpath(root, "inputs")
        mkpath(inputs)
        sources = (
            ordinary = normpath(
                joinpath(
                    @__DIR__,
                    "..",
                    "..",
                    "examples",
                    "fixtures",
                    "synthetic_runtime",
                    "synthetic_operators.h5",
                ),
            ),
            zeeman = normpath(
                joinpath(
                    @__DIR__,
                    "..",
                    "..",
                    "test",
                    "fixtures",
                    "first_use_registered",
                    "pauli_bundle.h5",
                ),
            ),
        )
        files = (ordinary = joinpath(inputs, "operators.h5"), zeeman = joinpath(inputs, "pauli.h5"))
        for kind in keys(sources)
            cp(getproperty(sources, kind), getproperty(files, kind))
        end
        configs = _representative_operator_configs(root; operator_bundle_files = files)
        @compile_workload begin
            # First metadata reads must occur while runtime-dispatch capture is on.
            for file in values(files)
                adopt_real_space_operator_bundle(file)
            end
            for cfg in configs
                WannierNLQG.run(cfg)
            end
            # Shared batches do not establish each singleton preparation path.
            for cfg in _representative_singleton_operator_configs(configs, root)
                WannierNLQG.run(cfg)
            end
            WannierNLQG.run(_representative_regularized_geometry_config(configs, root))
            # The isolated spin path prepares a different concrete response
            # container than the shared ISC/SSC batch. Keep it in the operator
            # owner: sibling precompile images cannot lazy-load this extension.
            shared = configs.spin
            task = only(filter(task -> task.quantity == "SSC", shared.tasks))
            spin = WannierNLQG.TaskSpec(
                id = task.id,
                quantity = task.quantity,
                method = task.method,
                physics = task.physics,
                numerics = WannierNLQG._first_use_optical_numerics(
                    "SSC",
                    "Conventional";
                    broadening_type = "Gaussian",
                ),
                observable = task.observable,
            )
            WannierNLQG.run(
                WannierNLQG._first_use_config(
                    shared.model,
                    shared.sampling,
                    [spin],
                    joinpath(root, "spin_isolated"),
                ),
            )
            @assert !WannierNLQG.MPI.Initialized()
            @assert WannierNLQG.Runtime.ACTIVE_PROGRESS[] === nothing
        end
    finally
        rm(root; recursive = true, force = true)
    end
end
