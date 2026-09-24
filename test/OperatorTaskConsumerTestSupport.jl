# Demand-only synthetic arrays test consumer access closure, not physical response qualification.
using WannierNLQG, LinearAlgebra

isdefined(@__MODULE__, :spectral_test_model) ||
    include(joinpath(@__DIR__, "SpectralResponseTestSupport.jl"))
function ots_sparse_consumer_tests()
    R=WannierNLQG.Runtime;
    C=WannierNLQG.Core;
    M=WannierNLQG.MatrixElements
    base=spectral_test_model();
    n=base.num_orbitals;
    nr=base.num_r_vectors;
    passed=0
    for def in R.TASK_DEFINITIONS, conv in ("Convention_I", "Convention_II")
        q=R.quantity_symbol(def.quantity);
        m=R.method_symbol(def.method);
        calc=R.calculation_symbol(def.calculation)
        axes=ntuple(i->mod1(i+1, 3), Int(def.tensor_rank))
        cfg=R.EffectiveTaskConfig(
            tasks = [(String(q), String(m), String(calc))],
            fourier_backend = "direct",
            spatial_dimension = 3,
            tensor_indices = axes,
            wannier_center_convention = conv,
        )
        specs=R.normalize_task_specs(cfg)
        @testset "$q/$m/$calc/$conv demanded components only" begin
            demand=R.operator_demand_plan(specs, cfg);
            plan=R.bundle_matrix_element_plan(specs, cfg, calc==:kslice ? collect(axes) : nothing)
            comps=Dict(
                k=>Dict(
                    c=>k==C.REAL_SPACE_HAMILTONIAN ? copy(base.hamiltonian_r) :
                       k==C.REAL_SPACE_POSITION ? copy(base.position_r[:, :, Int(c[1]), :]) :
                       fill(ComplexF64(0.03*Int(c[1])+0.01*Int(c[2])), n, n, nr) for
                    c in demand.required_components[k]
                ) for k in demand.required_operators
            )
            stub=(components = comps, manifest = (num_orbitals = n, r_vectors = base.r_vectors))
            packed(k, rank)=R._packed_operator(stub, k, rank)
            model=C.TightBindingModel(
                base.lattice,
                n,
                nr,
                base.r_degeneracies,
                base.r_vectors,
                base.hamiltonian_r,
                packed(C.REAL_SPACE_POSITION, 1);
                copy_data = false,
            )
            inv=demand.required_operators
            s=C.REAL_SPACE_SPIN in inv ?
              M.SpinRealSpaceData(packed(C.REAL_SPACE_SPIN, 1); copy_data = false) : nothing
            sv=C.REAL_SPACE_SPIN_TIMES_HAMILTONIAN in inv ?
               M.SpinVelocityRealSpaceData(
                s,
                packed(C.REAL_SPACE_SPIN_TIMES_HAMILTONIAN, 1),
                packed(C.REAL_SPACE_SPIN_TIMES_POSITION, 2),
                packed(C.REAL_SPACE_SPIN_TIMES_HAMILTONIAN_POSITION, 2),
                M.SpinVelocityRealSpaceDiagnostics(0.0, 0.0, 0.0, 0.0),
            ) : nothing
            ff=C.REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR in inv ?
               M.DerivativeOverlapRealSpaceData(
                packed(C.REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR, 2);
                copy_data = false,
            ) : nothing
            w=M.MatrixElementWorkspace(
                model,
                plan,
                M.MatrixElementSources(spin = s, spin_velocity = sv, derivative_overlap = ff),
            )
            M.prepare_real_space!(w, model);
            M.compute_kpoint!(w, model, [0.13, 0.21, 0.07])
            @test (w.data.computed_mask & plan.required_mask)==plan.required_mask
            if demand.requires_full_projector_geometry
                M.prepare_projector_covariant_geometry!(
                    M.ProjectorMatrixData(w.data, 3),
                    M.ProjectorMatrixWorkspace(w, nothing),
                    model,
                )
            end
            if q==:orbital_magnetization
                o=M.OrbitalRealSpaceSources(
                    packed(C.REAL_SPACE_HAMILTONIAN_WEIGHTED_CONNECTION, 1),
                    packed(C.REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR, 2),
                    packed(C.REAL_SPACE_HAMILTONIAN_WEIGHTED_AXIAL_DERIVATIVE_OVERLAP, 1),
                    Dict{String, Any}(),
                )
                M.orbital_completion(o, model, w)
            end
            passed+=1
        end
    end
    @test passed == 2 * length(R.TASK_DEFINITIONS)
    println("SPARSE_COMPONENT_CASES_COMPLETED=", passed)
    for method in (:conventional, :projector)
        sel=C.resolve_operator_requirements(
            [
                C.OperatorTask(quantity = :orbital_magnetization, method = method),
                C.OperatorTask(quantity = :shift_current, method = :projector),
            ];
            orbital_input_semantics = :defined_finite_model,
        )
        @test C.REAL_SPACE_DERIVATIVE_OVERLAP_TENSOR in sel.required_operators
    end
    println("FINITE_MODEL_EXCEPTION_IS_SCOPED=true")
end
