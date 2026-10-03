# Reconstruct observed workspace types through public constructors only.
# Temporary 2-orbital, one-R arrays are discarded; the cache retains only types.
const FIRST_USE_WORKSPACE_TYPES =
    if ccall(:jl_generating_output, Cint, ()) == 1 &&
       FIRST_USE_WORKLOAD_ENABLED &&
       FIRST_USE_TRACE_COMPATIBLE
        let shape = (2, 2, 1)
            one = IO.PackedCartesianOperator(
                1,
                Dict((a,) => fill(1.0 + 0.0im, shape) for a in 1:3),
                shape,
            )
            two = IO.PackedCartesianOperator(
                2,
                Dict((a, b) => fill(1.0 + 0.0im, shape) for a in 1:3 for b in 1:3),
                shape,
            )
            spin = MatrixElements.SpinRealSpaceData(one; copy_data = false)
            velocity = MatrixElements.SpinVelocityRealSpaceData(
                spin,
                one,
                two,
                two,
                MatrixElements.SpinVelocityRealSpaceDiagnostics(0.0, 0.0, 0.0, 0.0),
            )
            sources = (
                none = MatrixElements.MatrixElementSources(),
                spin = MatrixElements.MatrixElementSources(spin = spin),
                spin_velocity = MatrixElements.MatrixElementSources(spin_velocity = velocity),
                derivative = MatrixElements.MatrixElementSources(
                    derivative_overlap = MatrixElements.DerivativeOverlapRealSpaceData(
                        two;
                        copy_data = false,
                    ),
                ),
            )
            values = Any[nothing for _ in 1:11]
            plan = MatrixElements.compile_matrix_plan(
                MatrixElements.MatrixElementRequest(MatrixElements.SPECTRUM; spatial_dimension = 3);
                source_gauge_required = true,
            )
            values[1] = typeof(MatrixElements.MatrixElementWorkspace(2, 1, plan, sources.none))
            plan = MatrixElements.compile_matrix_plan(
                MatrixElements.MatrixElementRequest(
                    MatrixElements.SPECTRUM,
                    MatrixElements.HAMILTONIAN_SECOND_DERIVATIVES,
                    MatrixElements.INTERNAL_CONNECTION_DERIVATIVES,
                    MatrixElements.BERRY_CONNECTION;
                    spatial_dimension = 3,
                );
                source_gauge_required = false,
            )
            values[2] = typeof(MatrixElements.MatrixElementWorkspace(2, 1, plan, sources.none))
            plan = MatrixElements.compile_matrix_plan(
                MatrixElements.MatrixElementRequest(
                    MatrixElements.SPECTRUM,
                    MatrixElements.HAMILTONIAN_DERIVATIVES,
                    MatrixElements.INTERNAL_CONNECTION,
                    MatrixElements.WANNIER_CURVATURE;
                    spatial_dimension = 3,
                );
                source_gauge_required = false,
            )
            values[3] = typeof(MatrixElements.MatrixElementWorkspace(2, 1, plan, sources.none))
            plan = MatrixElements.compile_matrix_plan(
                MatrixElements.MatrixElementRequest(
                    MatrixElements.SPECTRUM,
                    MatrixElements.WANNIER_POSITION,
                    MatrixElements.INTERNAL_CONNECTION_DERIVATIVES;
                    spatial_dimension = 2,
                );
                source_gauge_required = false,
            )
            values[5] =
                typeof(MatrixElements.MatrixElementWorkspace(2, 1, plan, sources.derivative))
            plan = MatrixElements.compile_matrix_plan(
                MatrixElements.MatrixElementRequest(
                    MatrixElements.SPECTRUM,
                    MatrixElements.HAMILTONIAN_SECOND_DERIVATIVES,
                    MatrixElements.INTERNAL_CONNECTION,
                    MatrixElements.INTERNAL_CONNECTION_DERIVATIVES,
                    MatrixElements.SPIN_VELOCITY;
                    spatial_dimension = 2,
                );
                source_gauge_required = false,
            )
            values[6] =
                typeof(MatrixElements.MatrixElementWorkspace(2, 1, plan, sources.spin_velocity))
            plan = MatrixElements.compile_matrix_plan(
                MatrixElements.MatrixElementRequest(
                    MatrixElements.SPECTRUM,
                    MatrixElements.HAMILTONIAN_DERIVATIVES,
                    MatrixElements.VELOCITY_VERTICES;
                    spatial_dimension = 2,
                );
                source_gauge_required = true,
            )
            values[7] = typeof(MatrixElements.MatrixElementWorkspace(2, 1, plan, sources.none))
            plan = MatrixElements.compile_matrix_plan(
                MatrixElements.MatrixElementRequest(
                    MatrixElements.SPECTRUM,
                    MatrixElements.HAMILTONIAN_DERIVATIVES,
                    MatrixElements.BERRY_CONNECTION;
                    spatial_dimension = 2,
                );
                source_gauge_required = false,
            )
            values[8] = typeof(MatrixElements.MatrixElementWorkspace(2, 1, plan, sources.none))
            plan = MatrixElements.compile_matrix_plan(
                MatrixElements.MatrixElementRequest(
                    MatrixElements.SPECTRUM,
                    MatrixElements.BERRY_CONNECTION,
                    MatrixElements.SPIN_VELOCITY;
                    spatial_dimension = 2,
                );
                source_gauge_required = false,
            )
            values[9] =
                typeof(MatrixElements.MatrixElementWorkspace(2, 1, plan, sources.spin_velocity))
            plan = MatrixElements.compile_matrix_plan(
                MatrixElements.MatrixElementRequest(
                    MatrixElements.SPECTRUM,
                    MatrixElements.BERRY_CONNECTION,
                    MatrixElements.WANNIER_CURVATURE;
                    spatial_dimension = 2,
                );
                source_gauge_required = false,
            )
            values[10] = typeof(MatrixElements.MatrixElementWorkspace(2, 1, plan, sources.none))
            plan = MatrixElements.compile_matrix_plan(
                MatrixElements.MatrixElementRequest(
                    MatrixElements.SPECTRUM,
                    MatrixElements.BERRY_CONNECTION,
                    MatrixElements.SPIN;
                    spatial_dimension = 2,
                );
                source_gauge_required = false,
            )
            values[11] = typeof(MatrixElements.MatrixElementWorkspace(2, 1, plan, sources.spin))
            Tuple(values)
        end
    else
        nothing
    end
