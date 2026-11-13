"""Keep direct low-dimensional operations on physical axes without auxiliary translations.

The existing three-axis Cartesian action, orbital representation and spin checks
remain unchanged. Missing reference directions are not a new translation group.
Complete 3x3 inputs keep their original operation contract.
"""
function validate_native_physical_symmetry(input, operations)
    d = native_physical_dimension(input)
    d == 3 && return nothing
    for operation in operations
        rotation = operation.rotation_fractional
        all(iszero, rotation[1:d, (d + 1):3]) && all(iszero, rotation[(d + 1):3, 1:d]) ||
            throw(ArgumentError("symmetry operation mixes physical and auxiliary directions"))
        all(iszero, operation.translation_fractional[(d + 1):3]) || throw(
            ArgumentError(
                "direct low-dimensional symmetry cannot translate along auxiliary directions",
            ),
        )
    end
    return nothing
end

"""Write a native operation declaration after validating its fixed-orbital group representation."""
function write_native_response_symmetry(
    path::AbstractString,
    input::AbstractNativeModelInput,
    operations,
)
    validate_native_physical_symmetry(input, operations)
    input isa AnalyticKInput &&
        !input.periodic &&
        throw(ArgumentError("native symmetry requires a periodic model"))
    validate_point_orbital_group(input, operations)
    return write_native_symmetry_artifact(path, input, operations)
end

"""Construct a hard-validated model-specific symmetry plan, without material qualification."""
function build_native_response_symmetry_plan(cfg, ctx, specs, path)
    input=cfg.native_model_input
    input isa AnalyticKInput &&
        !input.periodic &&
        throw(ArgumentError("nonperiodic symmetry reduction is unsupported"))
    artifact=read_native_response_symmetry(path)
    _validate_native_input_admission(input, ctx.native_admission)
    validate_native_response_symmetry_model(artifact, input)
    validate_native_physical_symmetry(input, artifact.operations)
    geometries=validate_point_orbital_group(input, artifact.operations)
    operations=ResponseSymmetryOperation[
        ResponseSymmetryOperation(
            op.rotation_fractional,
            op.translation_fractional,
            geometry.rotation,
            op.antiunitary,
        ) for (op, geometry) in zip(artifact.operations, geometries)
    ]
    _validate_response_point_group(
        operations;
        cartesian_tolerance = 1e-10,
        fail_on_cartesian_residual = true,
    )
    mode=_response_symmetry_kmesh_mode(cfg.response_symmetry_kmesh_mode)
    calculation=only(unique(spec.calculation for spec in specs))
    explanation=calculation==:kslice || mode==:full
    lattice, _=point_orbital_geometry(input)
    reciprocal=reciprocal_lattice(lattice)
    points=Vector{Float64}[]
    if calculation==:kslice
        counts=Int[x for x in cfg.k_mesh]
        axes=validate_kslice_input(
            counts,
            collect(cfg.kslice_origin),
            collect(cfg.kslice_vector_1),
            collect(cfg.kslice_vector_2),
            collect(cfg.tensor_indices),
            tensor_axis_limits(first(specs), cfg.spatial_dimension),
        )
        grid,
        _,
        _=make_kslice_grid(
            counts,
            axes,
            collect(cfg.kslice_origin),
            collect(cfg.kslice_vector_1),
            collect(cfg.kslice_vector_2),
        )
        for index in 1:length(grid)
            fractional=zeros(3);
            kslice_kpoint!(fractional, grid, index)
            push!(points, transpose(reciprocal)*fractional)
        end
    else
        grid=_integral_k_grid(cfg.k_mesh)
        for index in 1:length(grid)
            fractional=zeros(3);
            integral_kpoint!(fractional, grid, index)
            push!(points, transpose(reciprocal)*fractional)
        end
    end
    base_point_count=length(points)
    offsets=sort!(collect(union((fourier_task_offset_signatures(cfg, spec) for spec in specs)...)))
    validation_points=[
        point .+ cfg.finite_difference_step .* collect(offset[1]) for point in points for
        offset in offsets
    ]
    # The current symmetry task registry needs H derivatives through second order.
    # Validate on all actual points on every run; no stale qualification cache is reused.
    plan=bundle_matrix_element_plan(specs, cfg, collect(cfg.tensor_indices))
    order=has_capability(plan, HAMILTONIAN_SECOND_DERIVATIVES) ? 2 :
          has_capability(plan, HAMILTONIAN_DERIVATIVES) ? 1 : 0
    covariance=validate_point_orbital_covariance(
        input,
        artifact.operations,
        validation_points;
        max_order = order,
    )
    _validate_native_input_admission(input, ctx.native_admission)
    validate_native_response_symmetry_source(artifact)
    orbits=explanation ?
           (
        representatives = collect(1:length(points)),
        multiplicities = ones(Int, length(points)),
        full_kpoint_count = length(points),
    ) : response_symmetry_kmesh_orbits(cfg.k_mesh, operations)
    tensors=ResponseTensorSymmetryPlan[
        _response_tensor_symmetry_plan(
            quantity,
            cfg.spatial_dimension,
            operations;
            numerical_reduction = !explanation,
        ) for quantity in unique(spec.quantity for spec in specs)
    ]
    report=Dict{String, Any}(
        "status"=>"NATIVE_MODEL_VALIDATED",
        "basis"=>"fixed_orthogonal_point_orbitals",
        "covariance_max_absolute_residual"=>covariance.maximum_absolute_residual,
        "validated_point_count"=>length(validation_points),
        "base_point_count"=>base_point_count,
        "material_production_eligible"=>false,
        "qualification_cache"=>"DISABLED_REVALIDATE_EVERY_RUN",
        "native_binding"=>Dict(
            "artifact_source_identity"=>scientific_file_identity(artifact.source_state),
            "model_definition_source_identity"=>scientific_file_identity(artifact.definition_state),
            "model_binding"=>"complete_definition_byte_comparison/1",
        ),
    )
    return ResponseSymmetryExecutionPlan(
        artifact.source_path,
        "", # Legacy checksum slot is unused for native schema2; report uses native_binding.
        NATIVE_RESPONSE_SYMMETRY_SCHEMA,
        false,
        false,
        "", # Model equality was established by complete bytes above.
        "NOT_APPLICABLE",
        _response_symmetry_policy(cfg.response_symmetry_policy),
        mode,
        explanation,
        :COMPUTATION_READY,
        "PASS",
        nothing,
        1e-8,
        String[],
        operations,
        orbits.representatives,
        orbits.multiplicities,
        orbits.full_kpoint_count,
        tensors,
        report,
    )
end
