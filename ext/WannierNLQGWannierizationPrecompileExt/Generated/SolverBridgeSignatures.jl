@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        PRECOMPILE_CONTEXT["hdf5_mpi_extension_loaded"] =
            Base.get_extension(HDF5, :MPIExt) !== nothing
        PRECOMPILE_CONTEXT["mpi_initialized"] = WannierNLQG.MPI.Initialized()
        PRECOMPILE_CONTEXT["generating_output"] = ccall(:jl_generating_output, Cint, ())
        PRECOMPILE_CONTEXT["loaded_modules"] =
            sort!(unique(string(nameof(m)) for m in Base.loaded_modules_array()))
        @assert WannierNLQGWannierizationExt !== nothing
        @assert WannierNLQGOperatorBundleExt !== nothing
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQG.Wannierization.construct_symmetry_adapted_wannier_functions),
                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core._checked_mul_dims),
                Int64,
                Int64,
                Int64,
                Vararg{Int64},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.memoryref),
                GenericMemory{:not_atomic, Base.Complex{Float64}, Core.AddrSpace{Core}(0x00)},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.indexed_iterate),
                Tuple{String, String},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.indexed_iterate),
                Tuple{String, String},
                Int64,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.indexed_iterate),
                Tuple{String, String, String},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.indexed_iterate),
                Tuple{String, String, String},
                Int64,
                Int64,
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), Type{UndefKeywordError}, Symbol},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{NamedTuple{(:normalize_coefficients,), T} where T <: Tuple},
                Tuple{Bool},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{NamedTuple{(:required, :default), T} where T <: Tuple},
                Tuple{Bool, String},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.memoryref),
                GenericMemory{:not_atomic, Float64, Core.AddrSpace{Core}(0x00)},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{NamedTuple{(:default,), T} where T <: Tuple},
                Tuple{Int64},
            },
        )
        _record_precompile(Tuple{typeof(_first_solve_compile_call), typeof(Base.:(==)), Bool, Bool})
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{NamedTuple{(:comment,), T} where T <: Tuple},
                Tuple{String},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.indexed_iterate),
                Tuple{Nothing, String},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.indexed_iterate),
                Tuple{Nothing, String},
                Int64,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.in),
                String,
                Tuple{String, String},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{NamedTuple{(:point_provider, :normalize_coefficients), T} where T <: Tuple},
                Tuple{
                    typeof(
                        WannierNLQGWannierizationExt.RepresentationPreparation.native_vasp_point_provider,
                    ),
                    Bool,
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.indexed_iterate),
                Tuple{String, Int64},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.indexed_iterate),
                Tuple{String, Int64},
                Int64,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.indexed_iterate),
                Tuple{Int64, Nothing},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.indexed_iterate),
                Tuple{Int64, Nothing},
                Int64,
                Int64,
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), Type{Base.Complex{Float64}}, Bool},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{NamedTuple{(:require_oracle,), T} where T <: Tuple},
                Tuple{Bool},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{NamedTuple{(:change_error,), T} where T <: Tuple},
                Tuple{String},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.memoryref),
                GenericMemory{:not_atomic, Tuple{Symbol, Any}, Core.AddrSpace{Core}(0x00)},
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.:(==)), Nothing, Symbol},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{NamedTuple{(:tolerance,), T} where T <: Tuple},
                Tuple{Float64},
            },
        )
        false
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Pair{A, B} where {B} where A},
                String,
                Float64,
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.:(&)), Bool, Base.Missing},
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.in), Int64, Base.UnitRange{Int64}},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{NamedTuple{(:enforce_metric,), T} where T <: Tuple},
                Tuple{Bool},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{NamedTuple{(:target_band, :source_band), T} where T <: Tuple},
                Tuple{Int64, Int64},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{NamedTuple{(:enforce_absolute_group_law,), T} where T <: Tuple},
                Tuple{Bool},
            },
        )
        _record_precompile(Tuple{typeof(_first_solve_compile_call), Base.var"#58#59", Type})
        _record_precompile(Tuple{typeof(_first_solve_compile_call), Type{MethodError}, Any, Any})
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.:(!=)), UInt64, UInt64},
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.:(|)), UInt64, UInt64},
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.:(*)), UInt64, UInt64},
        )
        _record_precompile(Tuple{typeof(_first_solve_compile_call), typeof(Base.signed), UInt64})
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.:(>)), UInt64, UInt64},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{NamedTuple{(:jsonlines, :numbertype), T} where T <: Tuple},
                Tuple{Bool, Nothing},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{NamedTuple{(:jsonlines,), T} where T <: Tuple},
                Tuple{Bool},
            },
        )
        false
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Pair{A, B} where {B} where A},
                String,
                Nothing,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{NamedTuple{(:allow_inf,), T} where T <: Tuple},
                Tuple{Bool},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    Array{Array{Base.Complex{Float64}, 2}, 1},
                    Core.AddrSpace{Core}(0x00),
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{
                    NamedTuple{
                        (:success, :code, :message, :kpoint, :invariant_residual),
                        T,
                    } where T <: Tuple,
                },
                Tuple{Bool, Symbol, String, Int64, Float64},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{NamedTuple{(:success, :code, :frame, :gap, :backend), T} where T <: Tuple},
                Tuple{Bool, Symbol, Nothing, Float64, Symbol},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.convert),
                Type{Base.Complex{Float64}},
                Float64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    Array{Base.Complex{Float64}, 1},
                    Core.AddrSpace{Core}(0x00),
                },
            },
        )
        _record_precompile(Tuple{typeof(_first_solve_compile_call), Type{Float16}, Float32})
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.min), Float16, Float16},
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.convert), Type{Int64}, Float16},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{NamedTuple{(:init,), T} where T <: Tuple},
                Tuple{Float64},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{NamedTuple{(:success, :code, :message, :kpoint), T} where T <: Tuple},
                Tuple{Bool, Symbol, String, Int64},
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.min), Float64, Float64},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Core.Compiler.var"#464#465"{
                    Core.Compiler.NativeInterpreter,
                    Nothing,
                    Core.Compiler.IRInterpretationState,
                },
                Any,
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.:(*)), Int64, Float64},
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.:(/)), Float64, Int64},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{
                    NamedTuple{
                        (
                            :raw_amn_alignment_applied,
                            :raw_amn_alignment_minimum_singular_value,
                            :raw_amn_alignment_maximum_condition,
                            :raw_amn_alignment_projector_drift,
                            :raw_amn_alignment_completion_count,
                            :localization_initial_frames,
                        ),
                        T,
                    } where T <: Tuple,
                },
                Tuple{Bool, Float64, Float64, Float64, Int64, Nothing},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{NamedTuple{(:construction_policy,), T} where T <: Tuple},
                Tuple{Symbol},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.memoryref),
                GenericMemory{:not_atomic, Array{Float64, 1}, Core.AddrSpace{Core}(0x00)},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{NamedTuple{(:retained_disentanglement_nonconverged,), T} where T <: Tuple},
                Tuple{Bool},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.indexed_iterate),
                Tuple{Pair{String, String}, Int64},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.indexed_iterate),
                Tuple{Pair{String, String}, Int64},
                Int64,
                Int64,
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.iterate), Pair{String, String}},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.iterate),
                Pair{String, String},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Pair{A, B} where {B} where A},
                String,
                Bool,
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.Broadcast.broadcastable), Int64},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getproperty),
                Pair{Symbol, String},
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Pair{A, B} where {B} where A},
                WannierNLQG.Core.RealSpaceOperatorKind,
                Nothing,
            },
        )
        _record_precompile(Tuple{typeof(_first_solve_compile_call), typeof(Base.sizeof), Symbol})
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(HDF5.API.try_close_finalizer),
                HDF5.StringCreateProperties,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(HDF5.API.try_close_finalizer),
                HDF5.ObjectCreateProperties,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(HDF5.API.try_close_finalizer),
                HDF5.ObjectCopyProperties,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(HDF5.API.try_close_finalizer),
                HDF5.GroupAccessProperties,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(HDF5.API.try_close_finalizer),
                HDF5.FileMountProperties,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(HDF5.API.try_close_finalizer),
                HDF5.DatatypeCreateProperties,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(HDF5.API.try_close_finalizer),
                HDF5.DatatypeAccessProperties,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(
                    WannierNLQGWannierizationExt.WorkflowOrchestration.construct_symmetry_adapted_wannier_functions,
                ),
                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.unique), Tuple{Symbol, Symbol}},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.Broadcast.broadcasted),
                Type{String},
                Tuple{Symbol, Symbol},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.Style{Tuple},
                    Nothing,
                    Type{String},
                    Tuple{Tuple{Symbol, Symbol}},
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.Broadcast.instantiate),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.Style{Tuple},
                    Nothing,
                    Type{String},
                    Tuple{Tuple{Symbol, Symbol}},
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.copy),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.Style{Tuple},
                    Nothing,
                    Type{String},
                    Tuple{Tuple{Symbol, Symbol}},
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.ntuple),
                Base.Broadcast.var"#17#18"{
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.Style{Tuple},
                        Nothing,
                        Type{String},
                        Tuple{Tuple{Symbol, Symbol}},
                    },
                },
                Base.Val{2},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.Broadcast._broadcast_getindex),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.Style{Tuple},
                    Nothing,
                    Type{String},
                    Tuple{Tuple{Symbol, Symbol}},
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getproperty),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.Style{Tuple},
                    Nothing,
                    Type{String},
                    Tuple{Tuple{Symbol, Symbol}},
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.Broadcast._getindex),
                Tuple{Tuple{Symbol, Symbol}},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.Broadcast._broadcast_getindex_evalf),
                Type{String},
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQG.IO.resolve_operator_selection),
                Symbol,
                Tuple{},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQG.IO.operator_inventory_source_closure),
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    Tuple{Int64, Int64, Float64},
                    Core.AddrSpace{Core}(0x00),
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.setindex!),
                Array{Float64, 2},
                Float64,
                Int64,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.collect_to!),
                Array{Union{Nothing, Symbol}, 1},
                Base.Generator{
                    NTuple{28, Symbol},
                    WannierNLQG.Wannierization.var"#101#102"{
                        WannierNLQG.Wannierization.WannierizationInputConfig,
                    },
                },
                Int64,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.collect_to!),
                Array{Any, 1},
                Base.Generator{
                    NTuple{28, Symbol},
                    WannierNLQG.Wannierization.var"#101#102"{
                        WannierNLQG.Wannierization.WannierizationInputConfig,
                    },
                },
                Int64,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :construction_policy,
                        :wannierization_mode,
                        :source,
                        :sewing_backend,
                        :wavefunction_gauge_backend,
                        :authoritative_hamiltonian,
                        :wavefunction_gauge_hdf5,
                        :win_file,
                        :eig_file,
                        :mmn_file,
                        :amn_file,
                        :matrix_elements,
                        :projection_basis,
                        :band_representation,
                        :band_representation_hdf5,
                        :outer_min_ev,
                        :outer_max_ev,
                        :frozen_min_ev,
                        :frozen_max_ev,
                        :frozen_states,
                        :num_wannier,
                        :symmetry_tolerance,
                        :degeneracy_tolerance_ev,
                        :representation_tolerance,
                        :empirical_covariance_budget,
                        :target_center_matching_tolerance,
                        :compatibility_policy,
                        :preparation_execution,
                    ),
                    Tuple{
                        Symbol,
                        Symbol,
                        Nothing,
                        WannierNLQG.Wannierization.CoefficientMappingSewing,
                        WannierNLQG.Wannierization.NativeEigenstateGauge,
                        WannierNLQG.Wannierization.NativeDFTHamiltonian,
                        Nothing,
                        String,
                        String,
                        String,
                        Nothing,
                        Nothing,
                        WannierNLQG.WannierProjection.WannierProjectionBasis,
                        Nothing,
                        String,
                        Float64,
                        Float64,
                        Float64,
                        Float64,
                        Array{Tuple{Int64, Int64}, 1},
                        Int64,
                        Float64,
                        Float64,
                        Float64,
                        Nothing,
                        Float64,
                        Symbol,
                        WannierNLQG.Wannierization.WavefunctionPreparationExecutionConfig,
                    },
                },
                Type{WannierNLQG.Wannierization.WannierizationInputConfig},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.collect_to!),
                Array{Any, 1},
                Base.Generator{
                    NTuple{20, Symbol},
                    WannierNLQG.Wannierization.var"#101#102"{
                        WannierNLQG.Wannierization.WannierizationSolverConfig,
                    },
                },
                Int64,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :algorithm_profile,
                        :smv_fletcher_reeves_two_stage_audit_thresholds,
                        :smv_fletcher_reeves_two_stage_audit_manifest,
                        :initialization,
                        :z_mix_ratio,
                        :u_mix_ratio,
                        :acceleration,
                        :numerical_thresholds,
                        :initialization_backend,
                        :paw_scdm_input_hdf5,
                        :multi_start,
                        :max_iterations,
                        :convergence_tolerance,
                        :convergence_window,
                        :little_group_tolerance,
                        :little_group_max_iterations,
                        :localize,
                        :symmetrize_z,
                        :parallel,
                        :random_seed,
                    ),
                    Tuple{
                        Symbol,
                        WannierNLQG.Wannierization.SMVFletcherReevesTwoStageAuditThresholds,
                        Nothing,
                        Symbol,
                        Float64,
                        Float64,
                        WannierNLQG.Wannierization.WannierizationAccelerationConfig,
                        WannierNLQG.Wannierization.WannierizationNumericalThresholds,
                        WannierNLQG.Wannierization.AMNExactFrozenInitialization,
                        Nothing,
                        WannierNLQG.Wannierization.WannierizationMultiStartConfig,
                        Int64,
                        Float64,
                        Int64,
                        Float64,
                        Int64,
                        Bool,
                        Bool,
                        Symbol,
                        UInt64,
                    },
                },
                Type{WannierNLQG.Wannierization.WannierizationSolverConfig},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.collect_to_with_first!),
                Array{Nothing, 1},
                Nothing,
                Base.Generator{
                    NTuple{4, Symbol},
                    WannierNLQG.Wannierization.var"#101#102"{
                        WannierNLQG.Wannierization.WannierizationCheckpointConfig,
                    },
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.collect_to!),
                Array{Nothing, 1},
                Base.Generator{
                    NTuple{4, Symbol},
                    WannierNLQG.Wannierization.var"#101#102"{
                        WannierNLQG.Wannierization.WannierizationCheckpointConfig,
                    },
                },
                Int64,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.collect_to!),
                Array{Union{Nothing, String}, 1},
                Base.Generator{
                    NTuple{4, Symbol},
                    WannierNLQG.Wannierization.var"#101#102"{
                        WannierNLQG.Wannierization.WannierizationCheckpointConfig,
                    },
                },
                Int64,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{
                    (:restart_hdf5, :fixed_subspace_hdf5, :checkpoint_hdf5, :checkpoint_interval),
                    Tuple{Nothing, Nothing, String, Int64},
                },
                Type{WannierNLQG.Wannierization.WannierizationCheckpointConfig},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.setindex_widen_up_to),
                Array{Int64, 1},
                Nothing,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.collect_to!),
                Array{Union{Nothing, Int64}, 1},
                Base.Generator{
                    Tuple{Symbol, Symbol},
                    WannierNLQG.Wannierization.var"#101#102"{
                        WannierNLQG.Wannierization.WannierizationRuntimeConfig,
                    },
                },
                Int64,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{(:progress_interval, :iteration_observer), Tuple{Int64, Nothing}},
                Type{WannierNLQG.Wannierization.WannierizationRuntimeConfig},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.collect_to_with_first!),
                Array{Nothing, 1},
                Nothing,
                Base.Generator{
                    NTuple{21, Symbol},
                    WannierNLQG.Wannierization.var"#101#102"{
                        WannierNLQG.Wannierization.WannierizationOutputConfig,
                    },
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.setindex_widen_up_to),
                Array{Nothing, 1},
                Tuple{Symbol, Symbol},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.collect_to!),
                Array{Union{Nothing, Tuple{Symbol, Symbol}}, 1},
                Base.Generator{
                    NTuple{21, Symbol},
                    WannierNLQG.Wannierization.var"#101#102"{
                        WannierNLQG.Wannierization.WannierizationOutputConfig,
                    },
                },
                Int64,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.collect_to!),
                Array{Any, 1},
                Base.Generator{
                    NTuple{21, Symbol},
                    WannierNLQG.Wannierization.var"#101#102"{
                        WannierNLQG.Wannierization.WannierizationOutputConfig,
                    },
                },
                Int64,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :band_representation_output_hdf5,
                        :tb_output_formats,
                        :write_wannier90_tb,
                        :profile,
                        :operator_tasks,
                        :spn_file,
                        :spn_provenance_file,
                        :uiu_file,
                        :uhu_file,
                        :siu_file,
                        :shu_file,
                        :uiu_provenance_json,
                        :uhu_provenance_json,
                        :siu_provenance_json,
                        :shu_provenance_json,
                        :spn_formatted,
                        :operator_files_formatted,
                        :operator_closure_tolerance,
                        :spin_family_covariance_tolerance,
                        :spin_family_idempotence_tolerance,
                        :final_tb_symmetry_report_enabled,
                    ),
                    Tuple{
                        Nothing,
                        Tuple{Symbol, Symbol},
                        Bool,
                        Symbol,
                        Tuple{},
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Bool,
                        Bool,
                        Float64,
                        Float64,
                        Float64,
                        Nothing,
                    },
                },
                Type{WannierNLQG.Wannierization.WannierizationOutputConfig},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{(:accepted_result,), Tuple{Nothing}},
                typeof(
                    WannierNLQGWannierizationExt.WorkflowOrchestration._resolve_wannier_matrix_elements,
                ),
                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                WannierNLQG.WannierProjection.WannierProjectionBasis,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(
                    WannierNLQGWannierizationExt.WorkflowOrchestration._operator_oracle_mmn_file,
                ),
                NamedTuple{
                    (
                        :mmn,
                        :amn,
                        :mmn_file,
                        :amn_file,
                        :raw_amn_file,
                        :source_kind,
                        :paw_result,
                        :gauge_sha256,
                        :gauge_provenance_file,
                    ),
                    Tuple{
                        WannierNLQG.IO.WannierMMN,
                        Nothing,
                        String,
                        Nothing,
                        Nothing,
                        String,
                        Nothing,
                        String,
                        Nothing,
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getproperty),
                NamedTuple{
                    (
                        :mmn,
                        :amn,
                        :mmn_file,
                        :amn_file,
                        :raw_amn_file,
                        :source_kind,
                        :paw_result,
                        :gauge_sha256,
                        :gauge_provenance_file,
                    ),
                    Tuple{
                        WannierNLQG.IO.WannierMMN,
                        Nothing,
                        String,
                        Nothing,
                        Nothing,
                        String,
                        Nothing,
                        String,
                        Nothing,
                    },
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.WannierizationInputConfig,
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.WannierizationOutputConfig,
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :construction_policy,
                        :wannierization_mode,
                        :source,
                        :sewing_backend,
                        :wavefunction_gauge_backend,
                        :wavefunction_gauge_hdf5,
                        :authoritative_hamiltonian,
                        :win_file,
                        :eig_file,
                        :projection_basis,
                        :band_representation,
                        :band_representation_hdf5,
                        :output_hdf5,
                        :outer_min_ev,
                        :outer_max_ev,
                        :frozen_min_ev,
                        :frozen_max_ev,
                        :frozen_states,
                        :num_wannier,
                        :symmetry_tolerance,
                        :degeneracy_tolerance_ev,
                        :representation_tolerance,
                        :target_center_matching_tolerance,
                        :compatibility_policy,
                    ),
                    Tuple{
                        Symbol,
                        Symbol,
                        Nothing,
                        WannierNLQG.Wannierization.CoefficientMappingSewing,
                        WannierNLQG.Wannierization.NativeEigenstateGauge,
                        Nothing,
                        WannierNLQG.Wannierization.NativeDFTHamiltonian,
                        String,
                        String,
                        WannierNLQG.WannierProjection.WannierProjectionBasis,
                        Nothing,
                        String,
                        Nothing,
                        Float64,
                        Float64,
                        Float64,
                        Float64,
                        Array{Tuple{Int64, Int64}, 1},
                        Int64,
                        Float64,
                        Float64,
                        Float64,
                        Float64,
                        Symbol,
                    },
                },
                Type{WannierNLQG.Wannierization.BandRepresentationPreparationConfig},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :construction_policy,
                        :wannierization_mode,
                        :source,
                        :sewing_backend,
                        :wavefunction_gauge_backend,
                        :authoritative_hamiltonian,
                        :wavefunction_gauge_hdf5,
                        :win_file,
                        :eig_file,
                        :projection_basis,
                        :band_representation,
                        :band_representation_hdf5,
                        :output_hdf5,
                        :outer_min_ev,
                        :outer_max_ev,
                        :frozen_min_ev,
                        :frozen_max_ev,
                        :frozen_states,
                        :num_wannier,
                        :symmetry_tolerance,
                        :degeneracy_tolerance_ev,
                        :representation_tolerance,
                        :target_center_matching_tolerance,
                        :compatibility_policy,
                    ),
                    Tuple{
                        Symbol,
                        Symbol,
                        Nothing,
                        WannierNLQG.Wannierization.CoefficientMappingSewing,
                        WannierNLQG.Wannierization.NativeEigenstateGauge,
                        WannierNLQG.Wannierization.NativeDFTHamiltonian,
                        Nothing,
                        String,
                        String,
                        WannierNLQG.WannierProjection.WannierProjectionBasis,
                        Nothing,
                        String,
                        Nothing,
                        Float64,
                        Float64,
                        Float64,
                        Float64,
                        Array{Tuple{Int64, Int64}, 1},
                        Int64,
                        Float64,
                        Float64,
                        Float64,
                        Float64,
                        Symbol,
                    },
                },
                Type{WannierNLQG.Wannierization.BandRepresentationPreparationConfig},
            },
        )

        # Foundation-owned coverage is compiled in its owning extension.

        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getproperty),
                NamedTuple{
                    (
                        :inventory,
                        :raw_diagnostics,
                        :qualification_scope,
                        :requested_policy,
                        :effective_policy,
                        :symmetry_tolerance_status,
                        :preparation_digest,
                    ),
                    Tuple{
                        Nothing,
                        Array{WannierNLQG.SymmetryFoundation.RepresentationRawDiagnostic, 1},
                        WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope,
                        Symbol,
                        Symbol,
                        Symbol,
                        String,
                    },
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(
                    WannierNLQGWannierizationExt.WorkflowOrchestration._requalified_stored_raw_diagnostics,
                ),
                NamedTuple{
                    (
                        :inventory,
                        :raw_diagnostics,
                        :qualification_scope,
                        :requested_policy,
                        :effective_policy,
                        :symmetry_tolerance_status,
                        :preparation_digest,
                    ),
                    Tuple{
                        Nothing,
                        Array{WannierNLQG.SymmetryFoundation.RepresentationRawDiagnostic, 1},
                        WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope,
                        Symbol,
                        Symbol,
                        Symbol,
                        String,
                    },
                },
                WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{WannierNLQG.Wannierization.BandRepresentationPreparationResult},
                Symbol,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
                Nothing,
                Array{WannierNLQG.SymmetryFoundation.RepresentationRawDiagnostic, 1},
                WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope,
                WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                Symbol,
                Symbol,
                Symbol,
                Nothing,
                Nothing,
                Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport.operator_output_requires_target_contract,
                ),
                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.WannierizationSolverConfig,
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.WannierizationAccelerationConfig,
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(
                    WannierNLQGWannierizationExt.RepresentationPreparation._effective_wannierization_mode,
                ),
                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{(:tolerance, :construction_policy), Tuple{Float64, Symbol}},
                typeof(WannierNLQG.WannierProjection.build_wannier_symmetry_plan),
                WannierNLQG.WannierProjection.WannierProjectionBasis,
                Array{WannierNLQG.SymmetryFoundation.SymmetryOperation, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{
                    (:compatibility, :restart),
                    Tuple{WannierNLQG.Wannierization.RepresentationCompatibilityReport, Bool},
                },
                typeof(WannierNLQGWannierizationExt.OperatorExport._open_wannierization_log),
                String,
                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Base.Filesystem.var"#_walkdir#35"{Bool, Bool, typeof(throw)},
                Base.Channel{Tuple{String, Array{String, 1}, Array{String, 1}}},
                String,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.repr),
                Tuple{
                    Symbol,
                    Symbol,
                    Symbol,
                    Bool,
                    Float64,
                    Float64,
                    Float64,
                    Float64,
                    Array{Tuple{Int64, Int64}, 1},
                    Int64,
                    Symbol,
                    Float64,
                    Float64,
                    WannierNLQG.Wannierization.WannierizationAccelerationConfig,
                    Float64,
                    Int64,
                    Float64,
                    Int64,
                    Float64,
                    Float64,
                    Nothing,
                    Float64,
                    Symbol,
                    Bool,
                    Bool,
                    Symbol,
                    UInt64,
                    String,
                    String,
                    Symbol,
                    Symbol,
                    Symbol,
                    NamedTuple{
                        (:disentanglement, :localization, :profile, :default_selection_reason),
                        Tuple{Symbol, Symbol, Symbol, String},
                    },
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    WannierNLQG.Wannierization.WannierizationNumericalThresholds,
                    DataType,
                    Bool,
                    Int64,
                    Int64,
                    String,
                    String,
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.show),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{
                    Symbol,
                    Symbol,
                    Symbol,
                    Bool,
                    Float64,
                    Float64,
                    Float64,
                    Float64,
                    Array{Tuple{Int64, Int64}, 1},
                    Int64,
                    Symbol,
                    Float64,
                    Float64,
                    WannierNLQG.Wannierization.WannierizationAccelerationConfig,
                    Float64,
                    Int64,
                    Float64,
                    Int64,
                    Float64,
                    Float64,
                    Nothing,
                    Float64,
                    Symbol,
                    Bool,
                    Bool,
                    Symbol,
                    UInt64,
                    String,
                    String,
                    Symbol,
                    Symbol,
                    Symbol,
                    NamedTuple{
                        (:disentanglement, :localization, :profile, :default_selection_reason),
                        Tuple{Symbol, Symbol, Symbol, String},
                    },
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    String,
                    WannierNLQG.Wannierization.WannierizationNumericalThresholds,
                    DataType,
                    Bool,
                    Int64,
                    Int64,
                    String,
                    String,
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                },
                Bool,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                },
                Array{Tuple{Int64, Int64}, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                },
                Any,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                },
                Tuple{Float64, Float64},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                },
                Nothing,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                },
                UInt64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                },
                NamedTuple{
                    (:disentanglement, :localization, :profile, :default_selection_reason),
                    Tuple{Symbol, Symbol, Symbol, String},
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQG.Wannierization.WannierizationIteration,
                    Core.AddrSpace{Core}(0x00),
                },
            },
        )
        _record_precompile(Tuple{typeof(_first_solve_compile_call), typeof(Base.something), String})
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :amn,
                        :restart,
                        :restart_state,
                        :restart_history,
                        :restart_input_summary,
                        :fixed_subspace,
                        :observer,
                        :compatibility_report,
                        :initialization_amn_sha256,
                        :paw_scdm_input,
                    ),
                    Tuple{
                        Nothing,
                        Nothing,
                        Nothing,
                        Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                        Base.Dict{String, String},
                        Nothing,
                        WannierNLQGWannierizationExt.WorkflowOrchestration.var"#109#115"{
                            Base.RefValue{String},
                            Base.RefValue{String},
                            Base.RefValue{String},
                            WannierNLQGWannierizationExt.OperatorExport.var"#253#254"{
                                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                                WannierNLQG.SymmetryFoundation.BandRepresentation,
                                NamedTuple{
                                    (
                                        :checkpoint,
                                        :validated,
                                        :log,
                                        :packed,
                                        :wannier90,
                                        :tb_symmetry_json,
                                    ),
                                    NTuple{6, String},
                                },
                                Base.IOStream,
                                Base.Dict{String, String},
                            },
                            Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        },
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        String,
                        Nothing,
                    },
                },
                typeof(
                    WannierNLQGWannierizationExt.SolverCheckpoint._solve_symmetry_adapted_wannierization,
                ),
                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
                WannierNLQG.IO.WannierEIG,
                WannierNLQG.IO.WannierMMN,
                WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._prepare_solver_input_summary),
                NamedTuple{
                    (
                        :amn,
                        :compatibility_report,
                        :config,
                        :eig,
                        :fixed_subspace,
                        :initialization_amn_sha256,
                        :mmn,
                        :observer,
                        :paw_scdm_input,
                        :plan,
                        :representation,
                        :restart,
                        :restart_history,
                        :restart_input_summary,
                        :restart_state,
                    ),
                    Tuple{
                        Nothing,
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                        WannierNLQG.IO.WannierEIG,
                        Nothing,
                        String,
                        WannierNLQG.IO.WannierMMN,
                        WannierNLQGWannierizationExt.WorkflowOrchestration.var"#109#115"{
                            Base.RefValue{String},
                            Base.RefValue{String},
                            Base.RefValue{String},
                            WannierNLQGWannierizationExt.OperatorExport.var"#253#254"{
                                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                                WannierNLQG.SymmetryFoundation.BandRepresentation,
                                NamedTuple{
                                    (
                                        :checkpoint,
                                        :validated,
                                        :log,
                                        :packed,
                                        :wannier90,
                                        :tb_symmetry_json,
                                    ),
                                    NTuple{6, String},
                                },
                                Base.IOStream,
                                Base.Dict{String, String},
                            },
                            Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        },
                        Nothing,
                        WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        Nothing,
                        Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                        Base.Dict{String, String},
                        Nothing,
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._qualify_solver_inputs),
                NamedTuple{
                    (
                        :amn,
                        :amn_sha256,
                        :apply_symmetry,
                        :basis_sha256,
                        :compatibility_report,
                        :config,
                        :diagnostics,
                        :effective_algorithms,
                        :effective_compatibility_policy,
                        :fixed_subspace,
                        :full_constraint_scope,
                        :input_summary,
                        :mmn,
                        :nb,
                        :nk,
                        :observer,
                        :paw_scdm_input,
                        :plan,
                        :representation,
                        :restart,
                        :restart_history,
                        :restart_input_summary,
                        :restart_state,
                        :spectrum_audit,
                        :target_subspace_authority,
                    ),
                    Tuple{
                        Nothing,
                        String,
                        Bool,
                        String,
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                        Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        NamedTuple{
                            (:disentanglement, :localization, :profile, :default_selection_reason),
                            Tuple{Symbol, Symbol, Symbol, String},
                        },
                        Symbol,
                        Nothing,
                        Bool,
                        Base.Dict{String, String},
                        WannierNLQG.IO.WannierMMN,
                        Int64,
                        Int64,
                        WannierNLQGWannierizationExt.WorkflowOrchestration.var"#109#115"{
                            Base.RefValue{String},
                            Base.RefValue{String},
                            Base.RefValue{String},
                            WannierNLQGWannierizationExt.OperatorExport.var"#253#254"{
                                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                                WannierNLQG.SymmetryFoundation.BandRepresentation,
                                NamedTuple{
                                    (
                                        :checkpoint,
                                        :validated,
                                        :log,
                                        :packed,
                                        :wannier90,
                                        :tb_symmetry_json,
                                    ),
                                    NTuple{6, String},
                                },
                                Base.IOStream,
                                Base.Dict{String, String},
                            },
                            Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        },
                        Nothing,
                        WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        Nothing,
                        Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                        Base.Dict{String, String},
                        Nothing,
                        WannierNLQGWannierizationExt.SolverCheckpoint.HermitianSpectrumAudit,
                        Bool,
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.join),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Base.OneTo{Int64},
                Char,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(LinearAlgebra.generic_trimatdiv!),
                Base.SubArray{
                    Float64,
                    2,
                    Array{Float64, 2},
                    Tuple{Base.UnitRange{Int64}, Base.Slice{Base.OneTo{Int64}}},
                    false,
                },
                Char,
                Char,
                Function,
                Base.SubArray{
                    Float64,
                    2,
                    Array{Float64, 2},
                    Tuple{Base.UnitRange{Int64}, Base.UnitRange{Int64}},
                    false,
                },
                Base.SubArray{
                    Float64,
                    2,
                    Array{Float64, 2},
                    Tuple{Base.UnitRange{Int64}, Base.Slice{Base.OneTo{Int64}}},
                    false,
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._initialize_solver_frames),
                NamedTuple{
                    (
                        :amn,
                        :amn_sha256,
                        :apply_symmetry,
                        :basis_sha256,
                        :compatibility,
                        :config,
                        :config_sha256,
                        :diagnostics,
                        :effective_algorithms,
                        :effective_compatibility_policy,
                        :fixed_subspace,
                        :frozen_indices,
                        :frozen_masks,
                        :full_constraint_scope,
                        :input_summary,
                        :mmn,
                        :nb,
                        :nk,
                        :num_wannier,
                        :observer,
                        :outer_indices,
                        :outer_masks,
                        :paw_scdm_input,
                        :plan,
                        :projector_covariance_tolerance,
                        :representation,
                        :restart,
                        :restart_history,
                        :restart_state,
                        :spectrum_audit,
                        :stencil,
                        :tangent_plans,
                        :weights,
                    ),
                    Tuple{
                        Nothing,
                        String,
                        Bool,
                        String,
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                        String,
                        Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        NamedTuple{
                            (:disentanglement, :localization, :profile, :default_selection_reason),
                            Tuple{Symbol, Symbol, Symbol, String},
                        },
                        Symbol,
                        Nothing,
                        Array{Array{Int64, 1}, 1},
                        Array{Base.BitArray{1}, 1},
                        Bool,
                        Base.Dict{String, String},
                        WannierNLQG.IO.WannierMMN,
                        Int64,
                        Int64,
                        Int64,
                        WannierNLQGWannierizationExt.WorkflowOrchestration.var"#109#115"{
                            Base.RefValue{String},
                            Base.RefValue{String},
                            Base.RefValue{String},
                            WannierNLQGWannierizationExt.OperatorExport.var"#253#254"{
                                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                                WannierNLQG.SymmetryFoundation.BandRepresentation,
                                NamedTuple{
                                    (
                                        :checkpoint,
                                        :validated,
                                        :log,
                                        :packed,
                                        :wannier90,
                                        :tb_symmetry_json,
                                    ),
                                    NTuple{6, String},
                                },
                                Base.IOStream,
                                Base.Dict{String, String},
                            },
                            Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        },
                        Array{Array{Int64, 1}, 1},
                        Array{Base.BitArray{1}, 1},
                        Nothing,
                        WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                        Float64,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        Nothing,
                        Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                        Nothing,
                        WannierNLQGWannierizationExt.SolverCheckpoint.HermitianSpectrumAudit,
                        WannierNLQG.Wannierization.WannierizationFiniteDifferenceStencil,
                        Array{
                            Union{
                                Nothing,
                                WannierNLQGWannierizationExt.SolverCheckpoint.TargetSymmetryTangentPlan,
                            },
                            1,
                        },
                        Array{Float64, 1},
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{GenericMemory{:not_atomic, Base.BitArray{1}, Core.AddrSpace{Core}(0x00)}},
                UndefInitializer,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.copy),
                GenericMemory{:not_atomic, UInt64, Core.AddrSpace{Core}(0x00)},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._initialize_solver_optimizer),
                NamedTuple{
                    (
                        :amn_sha256,
                        :apply_symmetry,
                        :basis_sha256,
                        :compatibility,
                        :config,
                        :config_sha256,
                        :diagnostics,
                        :effective_algorithms,
                        :effective_compatibility_policy,
                        :fixed_mode,
                        :fixed_source_qualified,
                        :fixed_subspace,
                        :frames,
                        :frozen_indices,
                        :full_constraint_scope,
                        :included_bands,
                        :initialization_report,
                        :input_summary,
                        :mmn,
                        :nb,
                        :nk,
                        :num_wannier,
                        :observer,
                        :outer_indices,
                        :plan,
                        :projector_covariance_tolerance,
                        :raw_amn_reference_frames,
                        :representation,
                        :restart_history,
                        :restart_state,
                        :spectrum_audit,
                        :stencil,
                        :tangent_plans,
                        :weights,
                        :z_previous,
                    ),
                    Tuple{
                        String,
                        Bool,
                        String,
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                        String,
                        Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        NamedTuple{
                            (:disentanglement, :localization, :profile, :default_selection_reason),
                            Tuple{Symbol, Symbol, Symbol, String},
                        },
                        Symbol,
                        Bool,
                        Bool,
                        Nothing,
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Array{Int64, 1}, 1},
                        Bool,
                        Array{Base.BitArray{1}, 1},
                        Nothing,
                        Base.Dict{String, String},
                        WannierNLQG.IO.WannierMMN,
                        Int64,
                        Int64,
                        Int64,
                        WannierNLQGWannierizationExt.WorkflowOrchestration.var"#109#115"{
                            Base.RefValue{String},
                            Base.RefValue{String},
                            Base.RefValue{String},
                            WannierNLQGWannierizationExt.OperatorExport.var"#253#254"{
                                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                                WannierNLQG.SymmetryFoundation.BandRepresentation,
                                NamedTuple{
                                    (
                                        :checkpoint,
                                        :validated,
                                        :log,
                                        :packed,
                                        :wannier90,
                                        :tb_symmetry_json,
                                    ),
                                    NTuple{6, String},
                                },
                                Base.IOStream,
                                Base.Dict{String, String},
                            },
                            Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        },
                        Array{Array{Int64, 1}, 1},
                        WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                        Float64,
                        Nothing,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                        Nothing,
                        WannierNLQGWannierizationExt.SolverCheckpoint.HermitianSpectrumAudit,
                        WannierNLQG.Wannierization.WannierizationFiniteDifferenceStencil,
                        Array{
                            Union{
                                Nothing,
                                WannierNLQGWannierizationExt.SolverCheckpoint.TargetSymmetryTangentPlan,
                            },
                            1,
                        },
                        Array{Float64, 1},
                        Nothing,
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getindex),
                Type{WannierNLQG.Wannierization.WannierizationIteration},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{WannierNLQG.Wannierization.WannierizationOptimizerState},
                Symbol,
                Float64,
                Float64,
                Int64,
                Int64,
                NTuple{4, Float64},
                Float64,
                Array{Float64, 2},
                Array{Float64, 2},
                Symbol,
                Int64,
                Int64,
                Int64,
                Int64,
                Int64,
                Float64,
                Bool,
                Int64,
                Array{Base.Complex{Float64}, 3},
                Array{Float64, 2},
                Array{Float64, 1},
                Float64,
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Int64, 1},
                Array{Int64, 1},
                Array{Bool, 1},
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 3},
                Int64,
                Int64,
                Float64,
                Symbol,
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{WannierNLQG.Wannierization.WannierizationOptimizerState},
                Symbol,
                Float64,
                Float64,
                Int64,
                Int64,
                NTuple{4, Float64},
                Float64,
                Array{Float64, 2},
                Array{Float64, 2},
                Symbol,
                Int64,
                Int64,
                Int64,
                Int64,
                Int64,
                Float64,
                Bool,
                Int64,
                Array{Base.Complex{Float64}, 3},
                Array{Float64, 2},
                Array{Float64, 1},
                Float64,
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Int64, 1},
                Array{Int64, 1},
                Base.BitArray{1},
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 3},
                Int64,
                Int64,
                Float64,
                Symbol,
                Symbol,
                String,
                String,
                Int64,
                Float64,
                Array{Base.Complex{Float64}, 4},
                Array{Base.Complex{Float64}, 4},
                Array{Float64, 1},
                Int64,
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{WannierNLQG.Wannierization.WannierizationOptimizerState},
                Symbol,
                Float64,
                Float64,
                Int64,
                Int64,
                NTuple{4, Float64},
                Float64,
                Array{Float64, 2},
                Array{Float64, 2},
                Symbol,
                Int64,
                Int64,
                Int64,
                Int64,
                Int64,
                Float64,
                Bool,
                Int64,
                Array{Base.Complex{Float64}, 3},
                Array{Float64, 2},
                Array{Float64, 1},
                Float64,
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Float64, 1},
                Array{Int64, 1},
                Array{Int64, 1},
                Base.BitArray{1},
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 3},
                Int64,
                Int64,
                Float64,
                Symbol,
                Symbol,
                String,
                String,
                Int64,
                Float64,
                Array{Base.Complex{Float64}, 4},
                Array{Base.Complex{Float64}, 4},
                Array{Float64, 1},
                Int64,
                Symbol,
                Array{Base.Complex{Float64}, 4},
                Array{Base.Complex{Float64}, 3},
                Float64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{
                    GenericMemory{
                        :not_atomic,
                        Array{Base.Complex{Float64}, 2},
                        Core.AddrSpace{Core}(0x00),
                    },
                },
                UndefInitializer,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.copy),
                GenericMemory{:not_atomic, Base.Complex{Float64}, Core.AddrSpace{Core}(0x00)},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.sym_in),
                Symbol,
                NTuple{111, Symbol},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.sym_in),
                Symbol,
                NTuple{70, Symbol},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._run_solver_iterations),
                NamedTuple{
                    (
                        :actual_u_mix_ratio,
                        :actual_z_mix_ratio,
                        :amn_sha256,
                        :anderson_residual_history,
                        :anderson_z_history,
                        :apply_symmetry,
                        :basis_sha256,
                        :best_polar_centers,
                        :best_polar_frames,
                        :best_polar_objective,
                        :best_polar_spreads,
                        :centers,
                        :compatibility,
                        :config,
                        :config_sha256,
                        :convergence_values,
                        :retained_disentanglement_nonconverged,
                        :diagnostics,
                        :disentanglement_objective_history,
                        :effective_algorithms,
                        :effective_compatibility_policy,
                        :epoch,
                        :fixed_complete,
                        :fixed_mode,
                        :fixed_source_qualified,
                        :fixed_stability_count,
                        :fixed_stationary,
                        :fixed_stationary_count,
                        :frames,
                        :frozen_indices,
                        :full_constraint_scope,
                        :gradient_fallback_active,
                        :gradient_steps,
                        :grassmann_actual_decrease_history,
                        :grassmann_gradient_history,
                        :grassmann_predicted_decrease_history,
                        :grassmann_projector_change_history,
                        :grassmann_radius_history,
                        :grassmann_ratio_history,
                        :grassmann_trust_radius,
                        :history,
                        :improvement_streak,
                        :included_bands,
                        :initialization_report,
                        :input_summary,
                        :last_accepted_u_step_scale,
                        :last_anderson_reason,
                        :last_cg_beta,
                        :last_cg_restart_reason,
                        :last_u_optimizer_restart_reason,
                        :latest_restart_state,
                        :localization_initial_frames,
                        :localization_objective_history,
                        :localization_projector_drift_history,
                        :localization_reference_frames,
                        :localization_trial_accepted,
                        :localization_trial_actual_changes,
                        :localization_trial_directional_derivatives,
                        :localization_trial_iterations,
                        :localization_trial_objectives,
                        :localization_trial_required_changes,
                        :localization_trial_step_scales,
                        :localization_trial_sweeps,
                        :minimum_localization_diagonal_phase_margin,
                        :mmn,
                        :nb,
                        :nk,
                        :num_wannier,
                        :observer,
                        :optimizer_phase,
                        :outer_indices,
                        :phase_branch_backtracking_extension_count,
                        :plan,
                        :previous_merit,
                        :previous_u_direction,
                        :previous_u_gradient,
                        :prior_elapsed,
                        :projector_covariance_tolerance,
                        :rejected_steps,
                        :representation,
                        :residual_reference,
                        :sealed_subspace_frames,
                        :sealed_subspace_projectors,
                        :spectrum_audit,
                        :spreads,
                        :stage_stop_reason,
                        :start_iteration,
                        :started_ns,
                        :stencil,
                        :tangent_plans,
                        :trajectory_previous_frames,
                        :trajectory_two_step_frames,
                        :two_stage_complete,
                        :u_active_orbit_count,
                        :u_branch_signature,
                        :u_cg_iteration,
                        :u_cg_restart_count,
                        :u_generalized_gradient_rms,
                        :u_lbfgs_restart_count,
                        :u_lbfgs_rho_history,
                        :u_lbfgs_s_history,
                        :u_lbfgs_y_history,
                        :u_stability_count,
                        :u_steps,
                        :wannier90_reference_omega_i,
                        :wannier90_reference_overlaps,
                        :wannier90_reference_unitaries,
                        :weights,
                        :z_previous,
                        :z_stability_count,
                        :z_steps,
                    ),
                    Tuple{
                        Float64,
                        Float64,
                        String,
                        Array{Float64, 2},
                        Array{Float64, 2},
                        Bool,
                        String,
                        Array{Float64, 2},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Float64,
                        Array{Float64, 1},
                        Array{Float64, 2},
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                        String,
                        Array{Array{Float64, 1}, 1},
                        Bool,
                        Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        Array{Float64, 1},
                        NamedTuple{
                            (:disentanglement, :localization, :profile, :default_selection_reason),
                            Tuple{Symbol, Symbol, Symbol, String},
                        },
                        Symbol,
                        Int64,
                        Bool,
                        Bool,
                        Bool,
                        Int64,
                        Bool,
                        Int64,
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Array{Int64, 1}, 1},
                        Bool,
                        Bool,
                        Int64,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Float64,
                        Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                        Int64,
                        Array{Base.BitArray{1}, 1},
                        Nothing,
                        Base.Dict{String, String},
                        Float64,
                        Symbol,
                        Float64,
                        Symbol,
                        Symbol,
                        WannierNLQG.Wannierization.WannierizationRestartState,
                        Nothing,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Bool, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Float64,
                        WannierNLQG.IO.WannierMMN,
                        Int64,
                        Int64,
                        Int64,
                        WannierNLQGWannierizationExt.WorkflowOrchestration.var"#109#115"{
                            Base.RefValue{String},
                            Base.RefValue{String},
                            Base.RefValue{String},
                            WannierNLQGWannierizationExt.OperatorExport.var"#253#254"{
                                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                                WannierNLQG.SymmetryFoundation.BandRepresentation,
                                NamedTuple{
                                    (
                                        :checkpoint,
                                        :validated,
                                        :log,
                                        :packed,
                                        :wannier90,
                                        :tb_symmetry_json,
                                    ),
                                    NTuple{6, String},
                                },
                                Base.IOStream,
                                Base.Dict{String, String},
                            },
                            Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        },
                        Symbol,
                        Array{Array{Int64, 1}, 1},
                        Int64,
                        WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                        Float64,
                        Nothing,
                        Nothing,
                        Float64,
                        Float64,
                        Int64,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        NTuple{4, Float64},
                        Nothing,
                        Nothing,
                        WannierNLQGWannierizationExt.SolverCheckpoint.HermitianSpectrumAudit,
                        Array{Float64, 1},
                        Nothing,
                        Int64,
                        UInt64,
                        WannierNLQG.Wannierization.WannierizationFiniteDifferenceStencil,
                        Array{
                            Union{
                                Nothing,
                                WannierNLQGWannierizationExt.SolverCheckpoint.TargetSymmetryTangentPlan,
                            },
                            1,
                        },
                        Nothing,
                        Nothing,
                        Bool,
                        Int64,
                        String,
                        Int64,
                        Int64,
                        Float64,
                        Int64,
                        Array{Float64, 1},
                        Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                        Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                        Int64,
                        Int64,
                        Nothing,
                        Nothing,
                        Nothing,
                        Array{Float64, 1},
                        Nothing,
                        Int64,
                        Int64,
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._propose_solver_iteration),
                NamedTuple{
                    (
                        :actual_u_mix_ratio,
                        :actual_z_mix_ratio,
                        :amn_sha256,
                        :anderson_residual_history,
                        :anderson_z_history,
                        :apply_symmetry,
                        :basis_sha256,
                        :best_polar_centers,
                        :best_polar_frames,
                        :best_polar_objective,
                        :best_polar_spreads,
                        :centers,
                        :compatibility,
                        :config,
                        :config_sha256,
                        :convergence_values,
                        :retained_disentanglement_nonconverged,
                        :diagnostics,
                        :disentanglement_objective_history,
                        :effective_algorithms,
                        :effective_compatibility_policy,
                        :epoch,
                        :fixed_complete,
                        :fixed_mode,
                        :fixed_source_qualified,
                        :fixed_stability_count,
                        :fixed_stationary,
                        :fixed_stationary_count,
                        :frames,
                        :frozen_indices,
                        :full_constraint_scope,
                        :gradient_fallback_active,
                        :gradient_steps,
                        :grassmann_actual_decrease_history,
                        :grassmann_gradient_history,
                        :grassmann_predicted_decrease_history,
                        :grassmann_projector_change_history,
                        :grassmann_radius_history,
                        :grassmann_ratio_history,
                        :grassmann_trust_radius,
                        :history,
                        :improvement_streak,
                        :included_bands,
                        :initialization_report,
                        :input_summary,
                        :last_accepted_u_step_scale,
                        :last_anderson_reason,
                        :last_cg_beta,
                        :last_cg_restart_reason,
                        :last_u_optimizer_restart_reason,
                        :latest_restart_state,
                        :localization_initial_frames,
                        :localization_objective_history,
                        :localization_projector_drift_history,
                        :localization_reference_frames,
                        :localization_trial_accepted,
                        :localization_trial_actual_changes,
                        :localization_trial_directional_derivatives,
                        :localization_trial_iterations,
                        :localization_trial_objectives,
                        :localization_trial_required_changes,
                        :localization_trial_step_scales,
                        :localization_trial_sweeps,
                        :minimum_localization_diagonal_phase_margin,
                        :mmn,
                        :nb,
                        :nk,
                        :num_wannier,
                        :observer,
                        :optimizer_phase,
                        :outer_indices,
                        :phase_branch_backtracking_extension_count,
                        :plan,
                        :previous_merit,
                        :previous_u_direction,
                        :previous_u_gradient,
                        :prior_elapsed,
                        :projector_covariance_tolerance,
                        :rejected_steps,
                        :representation,
                        :residual_reference,
                        :sealed_subspace_frames,
                        :sealed_subspace_projectors,
                        :spectrum_audit,
                        :spreads,
                        :stage_stop_reason,
                        :start_iteration,
                        :started_ns,
                        :stencil,
                        :tangent_plans,
                        :trajectory_previous_frames,
                        :trajectory_two_step_frames,
                        :two_stage_complete,
                        :u_active_orbit_count,
                        :u_branch_signature,
                        :u_cg_iteration,
                        :u_cg_restart_count,
                        :u_generalized_gradient_rms,
                        :u_lbfgs_restart_count,
                        :u_lbfgs_rho_history,
                        :u_lbfgs_s_history,
                        :u_lbfgs_y_history,
                        :u_stability_count,
                        :u_steps,
                        :wannier90_reference_omega_i,
                        :wannier90_reference_overlaps,
                        :wannier90_reference_unitaries,
                        :weights,
                        :z_previous,
                        :z_stability_count,
                        :z_steps,
                        :iteration,
                    ),
                    Tuple{
                        Float64,
                        Float64,
                        String,
                        Array{Float64, 2},
                        Array{Float64, 2},
                        Bool,
                        String,
                        Array{Float64, 2},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Float64,
                        Array{Float64, 1},
                        Array{Float64, 2},
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                        String,
                        Array{Array{Float64, 1}, 1},
                        Bool,
                        Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        Array{Float64, 1},
                        NamedTuple{
                            (:disentanglement, :localization, :profile, :default_selection_reason),
                            Tuple{Symbol, Symbol, Symbol, String},
                        },
                        Symbol,
                        Int64,
                        Bool,
                        Bool,
                        Bool,
                        Int64,
                        Bool,
                        Int64,
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Array{Int64, 1}, 1},
                        Bool,
                        Bool,
                        Int64,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Float64,
                        Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                        Int64,
                        Array{Base.BitArray{1}, 1},
                        Nothing,
                        Base.Dict{String, String},
                        Float64,
                        Symbol,
                        Float64,
                        Symbol,
                        Symbol,
                        WannierNLQG.Wannierization.WannierizationRestartState,
                        Nothing,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Bool, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Float64,
                        WannierNLQG.IO.WannierMMN,
                        Int64,
                        Int64,
                        Int64,
                        WannierNLQGWannierizationExt.WorkflowOrchestration.var"#109#115"{
                            Base.RefValue{String},
                            Base.RefValue{String},
                            Base.RefValue{String},
                            WannierNLQGWannierizationExt.OperatorExport.var"#253#254"{
                                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                                WannierNLQG.SymmetryFoundation.BandRepresentation,
                                NamedTuple{
                                    (
                                        :checkpoint,
                                        :validated,
                                        :log,
                                        :packed,
                                        :wannier90,
                                        :tb_symmetry_json,
                                    ),
                                    NTuple{6, String},
                                },
                                Base.IOStream,
                                Base.Dict{String, String},
                            },
                            Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        },
                        Symbol,
                        Array{Array{Int64, 1}, 1},
                        Int64,
                        WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                        Float64,
                        Nothing,
                        Nothing,
                        Float64,
                        Float64,
                        Int64,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        NTuple{4, Float64},
                        Nothing,
                        Nothing,
                        WannierNLQGWannierizationExt.SolverCheckpoint.HermitianSpectrumAudit,
                        Array{Float64, 1},
                        Nothing,
                        Int64,
                        UInt64,
                        WannierNLQG.Wannierization.WannierizationFiniteDifferenceStencil,
                        Array{
                            Union{
                                Nothing,
                                WannierNLQGWannierizationExt.SolverCheckpoint.TargetSymmetryTangentPlan,
                            },
                            1,
                        },
                        Nothing,
                        Nothing,
                        Bool,
                        Int64,
                        String,
                        Int64,
                        Int64,
                        Float64,
                        Int64,
                        Array{Float64, 1},
                        Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                        Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                        Int64,
                        Int64,
                        Nothing,
                        Nothing,
                        Nothing,
                        Array{Float64, 1},
                        Nothing,
                        Int64,
                        Int64,
                        Int64,
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                WannierNLQGWannierizationExt.SolverCheckpoint.var"#306#310"{
                    Bool,
                    WannierNLQG.IO.WannierMMN,
                    Array{Float64, 1},
                    Array{Array{Int64, 1}, 1},
                    Array{Array{Base.Complex{Float64}, 2}, 1},
                    Nothing,
                    Array{Array{Base.Complex{Float64}, 2}, 1},
                    Symbol,
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base._maximum),
                Function,
                Array{Array{Base.Complex{Float64}, 2}, 1},
                Base.Colon,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base._mapreduce_dim),
                Function,
                Function,
                Base._InitialValue,
                Array{Array{Base.Complex{Float64}, 2}, 1},
                Base.Colon,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base._mapreduce),
                typeof(LinearAlgebra.norm),
                typeof(Base.max),
                Base.IndexLinear,
                Array{Array{Base.Complex{Float64}, 2}, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.axes),
                Array{Base.Complex{Float64}, 2},
                Int64,
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.sum), Array{Float64, 1}},
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.vect), Array{Float64, 1}},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getindex),
                Array{Array{Float64, 1}, 1},
                Base.UnitRange{Int64},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.last),
                Array{Array{Float64, 1}, 1},
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.eachindex), Array{Float64, 1}},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.SolverCheckpoint.var"#389#395"{
                    Array{Array{Float64, 1}, 1},
                },
                Base.OneTo{Int64},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.maximum),
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.SolverCheckpoint.var"#389#395"{
                        Array{Array{Float64, 1}, 1},
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.maximum),
                Function,
                Array{Float64, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base._mapreduce_dim),
                Function,
                Function,
                Base._InitialValue,
                Array{Float64, 1},
                Base.Colon,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.ntuple),
                WannierNLQGWannierizationExt.SolverCheckpoint.var"#391#397"{
                    NTuple{4, Float64},
                    NTuple{4, Float64},
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.SolverCheckpoint.var"#392#398"{
                    NTuple{4, Float64},
                    NTuple{4, Float64},
                },
                Base.UnitRange{Int64},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.maximum),
                Base.Generator{
                    Base.UnitRange{Int64},
                    WannierNLQGWannierizationExt.SolverCheckpoint.var"#392#398"{
                        NTuple{4, Float64},
                        NTuple{4, Float64},
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.sym_in),
                Symbol,
                NTuple{82, Symbol},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.merge),
                NamedTuple{
                    (
                        :success,
                        :code,
                        :frames,
                        :centers,
                        :spreads,
                        :directional,
                        :u_residual,
                        :gradient_rms,
                        :projection_converged,
                        :projection_iterations,
                        :projection_residual,
                        :completed_sweeps,
                        :accepted_step_scale,
                        :backtracking_steps,
                        :trial_objective,
                        :accepted_objective,
                        :localization_spectra,
                        :localization_ranks,
                        :localization_conditions,
                        :raw_eigenphases,
                        :aligned_eigenphases,
                        :raw_geodesic_distances,
                        :aligned_geodesic_distances,
                        :block_permutations,
                        :block_phases,
                        :polar_fallback_triggered,
                        :active_localization_algorithm,
                        :base_objective,
                        :trial_zero_objective,
                        :trial_zero_frame_residual,
                        :attempted_step_scales,
                        :attempted_objectives,
                        :attempted_required_changes,
                        :attempted_actual_changes,
                        :attempted_directional_derivatives,
                        :attempted_sweeps,
                        :attempted_accepted,
                        :directional_derivative,
                        :fixed_projector_drift,
                        :accepted_required_change,
                        :accepted_actual_change,
                        :minimum_diagonal_phase_margin,
                        :minimum_phase_kpoint,
                        :minimum_phase_neighbor,
                        :minimum_phase_wannier,
                        :minimum_phase_value,
                        :branch_safe_backtracking_triggered,
                        :previous_u_gradient,
                        :previous_u_direction,
                        :u_cg_iteration,
                        :u_cg_restart_count,
                        :cg_beta,
                        :cg_restarted,
                        :cg_restart_reason,
                        :cg_descent_cosine,
                        :kstar_gradient_rms,
                        :maximum_kstar_gradient_rms,
                        :maximum_kstar_gradient_index,
                        :transport_minimum_singular_value,
                        :transport_maximum_condition,
                        :transported_omega_i,
                        :u_phase_contract,
                        :u_active_orbit_sha256,
                        :u_active_orbit_count,
                        :generalized_gradient_rms,
                        :u_lbfgs_s_history,
                        :u_lbfgs_y_history,
                        :u_lbfgs_rho_history,
                        :u_lbfgs_restart_count,
                        :u_optimizer_restart_reason,
                        :subspaces,
                        :raw_amn_alignment_applied,
                        :raw_amn_alignment_minimum_singular_value,
                        :raw_amn_alignment_maximum_condition,
                        :raw_amn_alignment_projector_drift,
                        :raw_amn_alignment_completion_count,
                        :localization_initial_frames,
                        :corepresentation_transport_applied,
                        :corepresentation_transport_minimum_singular_value,
                        :corepresentation_transport_maximum_condition,
                        :corepresentation_transport_projector_drift,
                        :corepresentation_transport_target_symmetry,
                    ),
                    Tuple{
                        Bool,
                        Symbol,
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Float64, 2},
                        Array{Float64, 1},
                        Nothing,
                        Float64,
                        Float64,
                        Bool,
                        Int64,
                        Float64,
                        Int64,
                        Float64,
                        Int64,
                        Float64,
                        Float64,
                        Array{Array{Float64, 1}, 1},
                        Array{Int64, 1},
                        Array{Float64, 1},
                        Array{Array{Float64, 1}, 1},
                        Array{Array{Float64, 1}, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Array{Int64, 1}, 1},
                        Array{Array{Float64, 1}, 1},
                        Bool,
                        Symbol,
                        Float64,
                        Float64,
                        Float64,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Array{Bool, 1},
                        Float64,
                        Float64,
                        Float64,
                        Float64,
                        Float64,
                        Int64,
                        Int64,
                        Int64,
                        Float64,
                        Bool,
                        Nothing,
                        Nothing,
                        Int64,
                        Int64,
                        Float64,
                        Bool,
                        Symbol,
                        Float64,
                        Array{Float64, 1},
                        Float64,
                        Int64,
                        Float64,
                        Float64,
                        Float64,
                        String,
                        String,
                        Int64,
                        Float64,
                        Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                        Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                        Array{Float64, 1},
                        Int64,
                        Symbol,
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Bool,
                        Float64,
                        Float64,
                        Float64,
                        Int64,
                        Nothing,
                        Bool,
                        Vararg{Float64, 4},
                    },
                },
                NamedTuple{
                    (
                        :spread_total,
                        :spread_std,
                        :covariance_error,
                        :projector_residual,
                        :wcc_step,
                        :spread_step,
                        :z_boundary_gap,
                    ),
                    NTuple{7, Float64},
                },
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.in), Symbol, NTuple{89, Symbol}},
        )
        false
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Integer},
                WannierNLQG.Wannierization.WannierizationStatus,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{NamedTuple{(:heading,), T} where T <: Tuple},
                Tuple{String},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._accept_solver_iteration),
                NamedTuple{
                    (
                        :accepted,
                        :accepted_anderson_context,
                        :accepted_anderson_fallback,
                        :accepted_anderson_reason,
                        :accepted_anderson_used,
                        :accepted_joint_reason,
                        :accepted_joint_transport_maximum_condition,
                        :accepted_joint_transport_minimum_singular_value,
                        :accepted_joint_z_backtracking_steps,
                        :accepted_merit,
                        :accepted_reference,
                        :accepted_residual_history,
                        :accepted_z,
                        :accepted_z_history,
                        :actual_u_mix_ratio,
                        :actual_z_mix_ratio,
                        :amn_sha256,
                        :apply_symmetry,
                        :basis_sha256,
                        :best_polar_centers,
                        :best_polar_frames,
                        :best_polar_objective,
                        :best_polar_spreads,
                        :compatibility,
                        :config,
                        :config_sha256,
                        :convergence_values,
                        :retained_disentanglement_nonconverged,
                        :diagnostics,
                        :disentanglement_objective_history,
                        :effective_algorithms,
                        :effective_compatibility_policy,
                        :epoch,
                        :fixed_complete,
                        :fixed_mode,
                        :fixed_source_qualified,
                        :fixed_stability_count,
                        :fixed_stationary,
                        :fixed_stationary_count,
                        :frozen_indices,
                        :full_constraint_scope,
                        :gradient_fallback_active,
                        :gradient_steps,
                        :grassmann_actual_decrease_history,
                        :grassmann_gradient_history,
                        :grassmann_predicted_decrease_history,
                        :grassmann_projector_change_history,
                        :grassmann_radius_history,
                        :grassmann_ratio_history,
                        :grassmann_trust_radius,
                        :history,
                        :improvement_streak,
                        :included_bands,
                        :initialization_report,
                        :input_summary,
                        :irreducible,
                        :iteration,
                        :iteration_phase,
                        :joint_mode,
                        :last_accepted_u_step_scale,
                        :latest_restart_state,
                        :localization_initial_frames,
                        :localization_objective_history,
                        :localization_projector_drift_history,
                        :localization_reference_frames,
                        :localization_trial_accepted,
                        :localization_trial_actual_changes,
                        :localization_trial_directional_derivatives,
                        :localization_trial_iterations,
                        :localization_trial_objectives,
                        :localization_trial_required_changes,
                        :localization_trial_step_scales,
                        :localization_trial_sweeps,
                        :minimum_localization_diagonal_phase_margin,
                        :mmn,
                        :nb,
                        :nk,
                        :num_wannier,
                        :observer,
                        :optimizer_phase,
                        :outer_indices,
                        :phase_branch_backtracking_extension_count,
                        :plan,
                        :prior_elapsed,
                        :projector_covariance_tolerance,
                        :proposal_z_mix_ratio,
                        :rejected_steps,
                        :representation,
                        :sealed_subspace_frames,
                        :sealed_subspace_projectors,
                        :spectrum_audit,
                        :stage_stop_reason,
                        :start_iteration,
                        :started_ns,
                        :stencil,
                        :tangent_plans,
                        :trajectory_previous_frames,
                        :trajectory_two_step_frames,
                        :two_stage_complete,
                        :u_stability_count,
                        :u_steps,
                        :wannier90_reference_omega_i,
                        :wannier90_reference_overlaps,
                        :wannier90_reference_unitaries,
                        :weights,
                        :z_residual,
                        :z_stability_count,
                        :z_steps,
                    ),
                    Tuple{
                        NamedTuple{
                            (
                                :success,
                                :code,
                                :frames,
                                :centers,
                                :spreads,
                                :directional,
                                :u_residual,
                                :gradient_rms,
                                :projection_converged,
                                :projection_iterations,
                                :projection_residual,
                                :completed_sweeps,
                                :accepted_step_scale,
                                :backtracking_steps,
                                :trial_objective,
                                :accepted_objective,
                                :localization_spectra,
                                :localization_ranks,
                                :localization_conditions,
                                :raw_eigenphases,
                                :aligned_eigenphases,
                                :raw_geodesic_distances,
                                :aligned_geodesic_distances,
                                :block_permutations,
                                :block_phases,
                                :polar_fallback_triggered,
                                :active_localization_algorithm,
                                :base_objective,
                                :trial_zero_objective,
                                :trial_zero_frame_residual,
                                :attempted_step_scales,
                                :attempted_objectives,
                                :attempted_required_changes,
                                :attempted_actual_changes,
                                :attempted_directional_derivatives,
                                :attempted_sweeps,
                                :attempted_accepted,
                                :directional_derivative,
                                :fixed_projector_drift,
                                :accepted_required_change,
                                :accepted_actual_change,
                                :minimum_diagonal_phase_margin,
                                :minimum_phase_kpoint,
                                :minimum_phase_neighbor,
                                :minimum_phase_wannier,
                                :minimum_phase_value,
                                :branch_safe_backtracking_triggered,
                                :previous_u_gradient,
                                :previous_u_direction,
                                :u_cg_iteration,
                                :u_cg_restart_count,
                                :cg_beta,
                                :cg_restarted,
                                :cg_restart_reason,
                                :cg_descent_cosine,
                                :kstar_gradient_rms,
                                :maximum_kstar_gradient_rms,
                                :maximum_kstar_gradient_index,
                                :transport_minimum_singular_value,
                                :transport_maximum_condition,
                                :transported_omega_i,
                                :u_phase_contract,
                                :u_active_orbit_sha256,
                                :u_active_orbit_count,
                                :generalized_gradient_rms,
                                :u_lbfgs_s_history,
                                :u_lbfgs_y_history,
                                :u_lbfgs_rho_history,
                                :u_lbfgs_restart_count,
                                :u_optimizer_restart_reason,
                                :subspaces,
                                :raw_amn_alignment_applied,
                                :raw_amn_alignment_minimum_singular_value,
                                :raw_amn_alignment_maximum_condition,
                                :raw_amn_alignment_projector_drift,
                                :raw_amn_alignment_completion_count,
                                :localization_initial_frames,
                                :corepresentation_transport_applied,
                                :corepresentation_transport_minimum_singular_value,
                                :corepresentation_transport_maximum_condition,
                                :corepresentation_transport_projector_drift,
                                :corepresentation_transport_target_symmetry,
                                :spread_total,
                                :spread_std,
                                :covariance_error,
                                :projector_residual,
                                :wcc_step,
                                :spread_step,
                                :z_boundary_gap,
                            ),
                            Tuple{
                                Bool,
                                Symbol,
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Array{Float64, 2},
                                Array{Float64, 1},
                                Nothing,
                                Float64,
                                Float64,
                                Bool,
                                Int64,
                                Float64,
                                Int64,
                                Float64,
                                Int64,
                                Float64,
                                Float64,
                                Array{Array{Float64, 1}, 1},
                                Array{Int64, 1},
                                Array{Float64, 1},
                                Array{Array{Float64, 1}, 1},
                                Array{Array{Float64, 1}, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Array{Int64, 1}, 1},
                                Array{Array{Float64, 1}, 1},
                                Bool,
                                Symbol,
                                Float64,
                                Float64,
                                Float64,
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Int64, 1},
                                Array{Bool, 1},
                                Float64,
                                Float64,
                                Float64,
                                Float64,
                                Float64,
                                Int64,
                                Int64,
                                Int64,
                                Float64,
                                Bool,
                                Nothing,
                                Nothing,
                                Int64,
                                Int64,
                                Float64,
                                Bool,
                                Symbol,
                                Float64,
                                Array{Float64, 1},
                                Float64,
                                Int64,
                                Float64,
                                Float64,
                                Float64,
                                String,
                                String,
                                Int64,
                                Float64,
                                Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                                Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                                Array{Float64, 1},
                                Int64,
                                Symbol,
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Bool,
                                Float64,
                                Float64,
                                Float64,
                                Int64,
                                Nothing,
                                Bool,
                                Vararg{Float64, 11},
                            },
                        },
                        Base.Dict{String, String},
                        Bool,
                        Symbol,
                        Bool,
                        Symbol,
                        Float64,
                        Float64,
                        Int64,
                        Float64,
                        NTuple{4, Float64},
                        Array{Float64, 2},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Float64, 2},
                        Float64,
                        Float64,
                        String,
                        Bool,
                        String,
                        Array{Float64, 2},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Float64,
                        Array{Float64, 1},
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                        String,
                        Array{Array{Float64, 1}, 1},
                        Bool,
                        Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        Array{Float64, 1},
                        NamedTuple{
                            (:disentanglement, :localization, :profile, :default_selection_reason),
                            Tuple{Symbol, Symbol, Symbol, String},
                        },
                        Symbol,
                        Int64,
                        Bool,
                        Bool,
                        Bool,
                        Int64,
                        Bool,
                        Int64,
                        Array{Array{Int64, 1}, 1},
                        Bool,
                        Bool,
                        Int64,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Float64,
                        Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                        Int64,
                        Array{Base.BitArray{1}, 1},
                        Nothing,
                        Base.Dict{String, String},
                        Array{Int64, 1},
                        Int64,
                        Symbol,
                        Bool,
                        Float64,
                        WannierNLQG.Wannierization.WannierizationRestartState,
                        Nothing,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Bool, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Float64,
                        WannierNLQG.IO.WannierMMN,
                        Int64,
                        Int64,
                        Int64,
                        WannierNLQGWannierizationExt.WorkflowOrchestration.var"#109#115"{
                            Base.RefValue{String},
                            Base.RefValue{String},
                            Base.RefValue{String},
                            WannierNLQGWannierizationExt.OperatorExport.var"#253#254"{
                                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                                WannierNLQG.SymmetryFoundation.BandRepresentation,
                                NamedTuple{
                                    (
                                        :checkpoint,
                                        :validated,
                                        :log,
                                        :packed,
                                        :wannier90,
                                        :tb_symmetry_json,
                                    ),
                                    NTuple{6, String},
                                },
                                Base.IOStream,
                                Base.Dict{String, String},
                            },
                            Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        },
                        Symbol,
                        Array{Array{Int64, 1}, 1},
                        Int64,
                        WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                        Float64,
                        Float64,
                        Float64,
                        Int64,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        Nothing,
                        Nothing,
                        WannierNLQGWannierizationExt.SolverCheckpoint.HermitianSpectrumAudit,
                        Nothing,
                        Int64,
                        UInt64,
                        WannierNLQG.Wannierization.WannierizationFiniteDifferenceStencil,
                        Array{
                            Union{
                                Nothing,
                                WannierNLQGWannierizationExt.SolverCheckpoint.TargetSymmetryTangentPlan,
                            },
                            1,
                        },
                        Nothing,
                        Nothing,
                        Bool,
                        Int64,
                        Int64,
                        Nothing,
                        Nothing,
                        Nothing,
                        Array{Float64, 1},
                        Float64,
                        Int64,
                        Int64,
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :fixed_subspace_projectors,
                        :fixed_subspace_frames,
                        :localization_initial_frames,
                    ),
                    Tuple{Nothing, Nothing, Nothing},
                },
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._restart_state),
                Int64,
                Array{Array{Base.Complex{Float64}, 2}, 1},
                Array{Array{Base.Complex{Float64}, 2}, 1},
                Array{Float64, 2},
                Array{Float64, 1},
                Array{Array{Float64, 1}, 1},
                Array{Base.BitArray{1}, 1},
                Float64,
                String,
                String,
                WannierNLQG.Wannierization.WannierizationFiniteDifferenceStencil,
                String,
                String,
                WannierNLQG.Wannierization.WannierizationOptimizerState,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.in),
                Tuple{
                    Symbol,
                    Symbol,
                    String,
                    Tuple{Pair{String, String}, Pair{String, String}, Pair{String, String}},
                },
                Base.Set{Tuple{Symbol, Symbol, String, Tuple}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.push!),
                Base.Set{Tuple{Symbol, Symbol, String, Tuple}},
                Tuple{
                    Symbol,
                    Symbol,
                    String,
                    Tuple{Pair{String, String}, Pair{String, String}, Pair{String, String}},
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.WannierizationRuntimeConfig,
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._finish_solver_iteration),
                NamedTuple{
                    (
                        :actual_u_mix_ratio,
                        :actual_z_mix_ratio,
                        :amn_sha256,
                        :anderson_residual_history,
                        :anderson_z_history,
                        :apply_symmetry,
                        :basis_sha256,
                        :best_polar_centers,
                        :best_polar_frames,
                        :best_polar_objective,
                        :best_polar_spreads,
                        :centers,
                        :compatibility,
                        :config,
                        :config_sha256,
                        :convergence_values,
                        :retained_disentanglement_nonconverged,
                        :diagnostics,
                        :disentanglement_objective_history,
                        :effective_algorithms,
                        :effective_compatibility_policy,
                        :epoch,
                        :fixed_complete,
                        :fixed_mode,
                        :fixed_source_qualified,
                        :fixed_stability_count,
                        :fixed_stationary,
                        :fixed_stationary_count,
                        :frames,
                        :frozen_indices,
                        :full_constraint_scope,
                        :gradient_fallback_active,
                        :gradient_steps,
                        :grassmann_actual_decrease_history,
                        :grassmann_gradient_history,
                        :grassmann_predicted_decrease_history,
                        :grassmann_projector_change_history,
                        :grassmann_radius_history,
                        :grassmann_ratio_history,
                        :grassmann_trust_radius,
                        :history,
                        :improvement_streak,
                        :included_bands,
                        :initialization_report,
                        :input_summary,
                        :iteration,
                        :last_accepted_u_step_scale,
                        :last_anderson_reason,
                        :last_cg_beta,
                        :last_cg_restart_reason,
                        :last_u_optimizer_restart_reason,
                        :latest_restart_state,
                        :localization_initial_frames,
                        :localization_objective_history,
                        :localization_projector_drift_history,
                        :localization_reference_frames,
                        :localization_trial_accepted,
                        :localization_trial_actual_changes,
                        :localization_trial_directional_derivatives,
                        :localization_trial_iterations,
                        :localization_trial_objectives,
                        :localization_trial_required_changes,
                        :localization_trial_step_scales,
                        :localization_trial_sweeps,
                        :minimum_localization_diagonal_phase_margin,
                        :mmn,
                        :nb,
                        :nk,
                        :num_wannier,
                        :observer,
                        :optimizer_phase,
                        :outer_indices,
                        :phase_branch_backtracking_extension_count,
                        :plan,
                        :previous_merit,
                        :previous_u_direction,
                        :previous_u_gradient,
                        :prior_elapsed,
                        :projector_covariance_tolerance,
                        :rejected_steps,
                        :representation,
                        :residual_reference,
                        :result,
                        :sealed_subspace_frames,
                        :sealed_subspace_projectors,
                        :spectrum_audit,
                        :spreads,
                        :stage_stop_reason,
                        :start_iteration,
                        :started_ns,
                        :stencil,
                        :tangent_plans,
                        :total_spread_window_std,
                        :trajectory_previous_frames,
                        :trajectory_two_step_frames,
                        :two_stage_complete,
                        :u_active_orbit_count,
                        :u_branch_signature,
                        :u_cg_iteration,
                        :u_cg_restart_count,
                        :u_generalized_gradient_rms,
                        :u_lbfgs_restart_count,
                        :u_lbfgs_rho_history,
                        :u_lbfgs_s_history,
                        :u_lbfgs_y_history,
                        :u_stability_count,
                        :u_steps,
                        :wannier90_reference_omega_i,
                        :wannier90_reference_overlaps,
                        :wannier90_reference_unitaries,
                        :weights,
                        :z_previous,
                        :z_stability_count,
                        :z_steps,
                    ),
                    Tuple{
                        Float64,
                        Float64,
                        String,
                        Array{Float64, 2},
                        Array{Float64, 2},
                        Bool,
                        String,
                        Array{Float64, 2},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Float64,
                        Array{Float64, 1},
                        Array{Float64, 2},
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                        String,
                        Array{Array{Float64, 1}, 1},
                        Bool,
                        Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        Array{Float64, 1},
                        NamedTuple{
                            (:disentanglement, :localization, :profile, :default_selection_reason),
                            Tuple{Symbol, Symbol, Symbol, String},
                        },
                        Symbol,
                        Int64,
                        Bool,
                        Bool,
                        Bool,
                        Int64,
                        Bool,
                        Int64,
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Array{Int64, 1}, 1},
                        Bool,
                        Bool,
                        Int64,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Float64,
                        Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                        Int64,
                        Array{Base.BitArray{1}, 1},
                        Nothing,
                        Base.Dict{String, String},
                        Int64,
                        Float64,
                        Symbol,
                        Float64,
                        Symbol,
                        Symbol,
                        WannierNLQG.Wannierization.WannierizationRestartState,
                        Nothing,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Bool, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Float64,
                        WannierNLQG.IO.WannierMMN,
                        Int64,
                        Int64,
                        Int64,
                        WannierNLQGWannierizationExt.WorkflowOrchestration.var"#109#115"{
                            Base.RefValue{String},
                            Base.RefValue{String},
                            Base.RefValue{String},
                            WannierNLQGWannierizationExt.OperatorExport.var"#253#254"{
                                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                                WannierNLQG.SymmetryFoundation.BandRepresentation,
                                NamedTuple{
                                    (
                                        :checkpoint,
                                        :validated,
                                        :log,
                                        :packed,
                                        :wannier90,
                                        :tb_symmetry_json,
                                    ),
                                    NTuple{6, String},
                                },
                                Base.IOStream,
                                Base.Dict{String, String},
                            },
                            Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        },
                        Symbol,
                        Array{Array{Int64, 1}, 1},
                        Int64,
                        WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                        Float64,
                        Nothing,
                        Nothing,
                        Float64,
                        Float64,
                        Int64,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        NTuple{4, Float64},
                        NamedTuple{
                            (
                                :success,
                                :code,
                                :frames,
                                :centers,
                                :spreads,
                                :directional,
                                :u_residual,
                                :gradient_rms,
                                :projection_converged,
                                :projection_iterations,
                                :projection_residual,
                                :completed_sweeps,
                                :accepted_step_scale,
                                :backtracking_steps,
                                :trial_objective,
                                :accepted_objective,
                                :localization_spectra,
                                :localization_ranks,
                                :localization_conditions,
                                :raw_eigenphases,
                                :aligned_eigenphases,
                                :raw_geodesic_distances,
                                :aligned_geodesic_distances,
                                :block_permutations,
                                :block_phases,
                                :polar_fallback_triggered,
                                :active_localization_algorithm,
                                :base_objective,
                                :trial_zero_objective,
                                :trial_zero_frame_residual,
                                :attempted_step_scales,
                                :attempted_objectives,
                                :attempted_required_changes,
                                :attempted_actual_changes,
                                :attempted_directional_derivatives,
                                :attempted_sweeps,
                                :attempted_accepted,
                                :directional_derivative,
                                :fixed_projector_drift,
                                :accepted_required_change,
                                :accepted_actual_change,
                                :minimum_diagonal_phase_margin,
                                :minimum_phase_kpoint,
                                :minimum_phase_neighbor,
                                :minimum_phase_wannier,
                                :minimum_phase_value,
                                :branch_safe_backtracking_triggered,
                                :previous_u_gradient,
                                :previous_u_direction,
                                :u_cg_iteration,
                                :u_cg_restart_count,
                                :cg_beta,
                                :cg_restarted,
                                :cg_restart_reason,
                                :cg_descent_cosine,
                                :kstar_gradient_rms,
                                :maximum_kstar_gradient_rms,
                                :maximum_kstar_gradient_index,
                                :transport_minimum_singular_value,
                                :transport_maximum_condition,
                                :transported_omega_i,
                                :u_phase_contract,
                                :u_active_orbit_sha256,
                                :u_active_orbit_count,
                                :generalized_gradient_rms,
                                :u_lbfgs_s_history,
                                :u_lbfgs_y_history,
                                :u_lbfgs_rho_history,
                                :u_lbfgs_restart_count,
                                :u_optimizer_restart_reason,
                                :subspaces,
                                :raw_amn_alignment_applied,
                                :raw_amn_alignment_minimum_singular_value,
                                :raw_amn_alignment_maximum_condition,
                                :raw_amn_alignment_projector_drift,
                                :raw_amn_alignment_completion_count,
                                :localization_initial_frames,
                                :corepresentation_transport_applied,
                                :corepresentation_transport_minimum_singular_value,
                                :corepresentation_transport_maximum_condition,
                                :corepresentation_transport_projector_drift,
                                :corepresentation_transport_target_symmetry,
                                :spread_total,
                                :spread_std,
                                :covariance_error,
                                :projector_residual,
                                :wcc_step,
                                :spread_step,
                                :z_boundary_gap,
                            ),
                            Tuple{
                                Bool,
                                Symbol,
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Array{Float64, 2},
                                Array{Float64, 1},
                                Nothing,
                                Float64,
                                Float64,
                                Bool,
                                Int64,
                                Float64,
                                Int64,
                                Float64,
                                Int64,
                                Float64,
                                Float64,
                                Array{Array{Float64, 1}, 1},
                                Array{Int64, 1},
                                Array{Float64, 1},
                                Array{Array{Float64, 1}, 1},
                                Array{Array{Float64, 1}, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Array{Int64, 1}, 1},
                                Array{Array{Float64, 1}, 1},
                                Bool,
                                Symbol,
                                Float64,
                                Float64,
                                Float64,
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Int64, 1},
                                Array{Bool, 1},
                                Float64,
                                Float64,
                                Float64,
                                Float64,
                                Float64,
                                Int64,
                                Int64,
                                Int64,
                                Float64,
                                Bool,
                                Nothing,
                                Nothing,
                                Int64,
                                Int64,
                                Float64,
                                Bool,
                                Symbol,
                                Float64,
                                Array{Float64, 1},
                                Float64,
                                Int64,
                                Float64,
                                Float64,
                                Float64,
                                String,
                                String,
                                Int64,
                                Float64,
                                Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                                Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                                Array{Float64, 1},
                                Int64,
                                Symbol,
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Bool,
                                Float64,
                                Float64,
                                Float64,
                                Int64,
                                Nothing,
                                Bool,
                                Vararg{Float64, 11},
                            },
                        },
                        Nothing,
                        Nothing,
                        WannierNLQGWannierizationExt.SolverCheckpoint.HermitianSpectrumAudit,
                        Array{Float64, 1},
                        Nothing,
                        Int64,
                        UInt64,
                        WannierNLQG.Wannierization.WannierizationFiniteDifferenceStencil,
                        Array{
                            Union{
                                Nothing,
                                WannierNLQGWannierizationExt.SolverCheckpoint.TargetSymmetryTangentPlan,
                            },
                            1,
                        },
                        Float64,
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Nothing,
                        Bool,
                        Int64,
                        String,
                        Int64,
                        Int64,
                        Float64,
                        Int64,
                        Array{Float64, 1},
                        Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                        Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                        Int64,
                        Int64,
                        Nothing,
                        Nothing,
                        Nothing,
                        Array{Float64, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Int64,
                        Int64,
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._propose_solver_iteration),
                NamedTuple{
                    (
                        :actual_u_mix_ratio,
                        :actual_z_mix_ratio,
                        :amn_sha256,
                        :anderson_residual_history,
                        :anderson_z_history,
                        :apply_symmetry,
                        :basis_sha256,
                        :best_polar_centers,
                        :best_polar_frames,
                        :best_polar_objective,
                        :best_polar_spreads,
                        :centers,
                        :compatibility,
                        :config,
                        :config_sha256,
                        :convergence_values,
                        :retained_disentanglement_nonconverged,
                        :diagnostics,
                        :disentanglement_objective_history,
                        :effective_algorithms,
                        :effective_compatibility_policy,
                        :epoch,
                        :fixed_complete,
                        :fixed_mode,
                        :fixed_source_qualified,
                        :fixed_stability_count,
                        :fixed_stationary,
                        :fixed_stationary_count,
                        :frames,
                        :frozen_indices,
                        :full_constraint_scope,
                        :gradient_fallback_active,
                        :gradient_steps,
                        :grassmann_actual_decrease_history,
                        :grassmann_gradient_history,
                        :grassmann_predicted_decrease_history,
                        :grassmann_projector_change_history,
                        :grassmann_radius_history,
                        :grassmann_ratio_history,
                        :grassmann_trust_radius,
                        :history,
                        :improvement_streak,
                        :included_bands,
                        :initialization_report,
                        :input_summary,
                        :last_accepted_u_step_scale,
                        :last_anderson_reason,
                        :last_cg_beta,
                        :last_cg_restart_reason,
                        :last_u_optimizer_restart_reason,
                        :latest_restart_state,
                        :localization_initial_frames,
                        :localization_objective_history,
                        :localization_projector_drift_history,
                        :localization_reference_frames,
                        :localization_trial_accepted,
                        :localization_trial_actual_changes,
                        :localization_trial_directional_derivatives,
                        :localization_trial_iterations,
                        :localization_trial_objectives,
                        :localization_trial_required_changes,
                        :localization_trial_step_scales,
                        :localization_trial_sweeps,
                        :minimum_localization_diagonal_phase_margin,
                        :mmn,
                        :nb,
                        :nk,
                        :num_wannier,
                        :observer,
                        :optimizer_phase,
                        :outer_indices,
                        :phase_branch_backtracking_extension_count,
                        :plan,
                        :previous_merit,
                        :previous_u_direction,
                        :previous_u_gradient,
                        :prior_elapsed,
                        :projector_covariance_tolerance,
                        :rejected_steps,
                        :representation,
                        :residual_reference,
                        :sealed_subspace_frames,
                        :sealed_subspace_projectors,
                        :spectrum_audit,
                        :spreads,
                        :stage_stop_reason,
                        :start_iteration,
                        :started_ns,
                        :stencil,
                        :tangent_plans,
                        :trajectory_previous_frames,
                        :trajectory_two_step_frames,
                        :two_stage_complete,
                        :u_active_orbit_count,
                        :u_branch_signature,
                        :u_cg_iteration,
                        :u_cg_restart_count,
                        :u_generalized_gradient_rms,
                        :u_lbfgs_restart_count,
                        :u_lbfgs_rho_history,
                        :u_lbfgs_s_history,
                        :u_lbfgs_y_history,
                        :u_stability_count,
                        :u_steps,
                        :wannier90_reference_omega_i,
                        :wannier90_reference_overlaps,
                        :wannier90_reference_unitaries,
                        :weights,
                        :z_previous,
                        :z_stability_count,
                        :z_steps,
                        :iteration,
                    ),
                    Tuple{
                        Float64,
                        Float64,
                        String,
                        Array{Float64, 2},
                        Array{Float64, 2},
                        Bool,
                        String,
                        Array{Float64, 2},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Float64,
                        Array{Float64, 1},
                        Array{Float64, 2},
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                        String,
                        Array{Array{Float64, 1}, 1},
                        Bool,
                        Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        Array{Float64, 1},
                        NamedTuple{
                            (:disentanglement, :localization, :profile, :default_selection_reason),
                            Tuple{Symbol, Symbol, Symbol, String},
                        },
                        Symbol,
                        Int64,
                        Bool,
                        Bool,
                        Bool,
                        Int64,
                        Bool,
                        Int64,
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Array{Int64, 1}, 1},
                        Bool,
                        Bool,
                        Int64,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Float64,
                        Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                        Int64,
                        Array{Base.BitArray{1}, 1},
                        Nothing,
                        Base.Dict{String, String},
                        Float64,
                        Symbol,
                        Float64,
                        Symbol,
                        Symbol,
                        WannierNLQG.Wannierization.WannierizationRestartState,
                        Nothing,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Bool, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Float64,
                        WannierNLQG.IO.WannierMMN,
                        Int64,
                        Int64,
                        Int64,
                        WannierNLQGWannierizationExt.WorkflowOrchestration.var"#109#115"{
                            Base.RefValue{String},
                            Base.RefValue{String},
                            Base.RefValue{String},
                            WannierNLQGWannierizationExt.OperatorExport.var"#253#254"{
                                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                                WannierNLQG.SymmetryFoundation.BandRepresentation,
                                NamedTuple{
                                    (
                                        :checkpoint,
                                        :validated,
                                        :log,
                                        :packed,
                                        :wannier90,
                                        :tb_symmetry_json,
                                    ),
                                    NTuple{6, String},
                                },
                                Base.IOStream,
                                Base.Dict{String, String},
                            },
                            Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        },
                        Symbol,
                        Array{Array{Int64, 1}, 1},
                        Int64,
                        WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                        Float64,
                        Nothing,
                        Nothing,
                        Float64,
                        Float64,
                        Int64,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        NTuple{4, Float64},
                        Nothing,
                        Nothing,
                        WannierNLQGWannierizationExt.SolverCheckpoint.HermitianSpectrumAudit,
                        Array{Float64, 1},
                        Nothing,
                        Int64,
                        UInt64,
                        WannierNLQG.Wannierization.WannierizationFiniteDifferenceStencil,
                        Array{
                            Union{
                                Nothing,
                                WannierNLQGWannierizationExt.SolverCheckpoint.TargetSymmetryTangentPlan,
                            },
                            1,
                        },
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Nothing,
                        Bool,
                        Int64,
                        String,
                        Int64,
                        Int64,
                        Float64,
                        Int64,
                        Array{Float64, 1},
                        Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                        Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                        Int64,
                        Int64,
                        Nothing,
                        Nothing,
                        Nothing,
                        Array{Float64, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Int64,
                        Int64,
                        Int64,
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.SolverCheckpoint.var"#387#393"{
                    Array{Array{Base.Complex{Float64}, 2}, 1},
                    Array{Array{Base.Complex{Float64}, 2}, 1},
                },
                Array{Int64, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.maximum),
                Base.Generator{
                    Array{Int64, 1},
                    WannierNLQGWannierizationExt.SolverCheckpoint.var"#387#393"{
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._accept_solver_iteration),
                NamedTuple{
                    (
                        :accepted,
                        :accepted_anderson_context,
                        :accepted_anderson_fallback,
                        :accepted_anderson_reason,
                        :accepted_anderson_used,
                        :accepted_joint_reason,
                        :accepted_joint_transport_maximum_condition,
                        :accepted_joint_transport_minimum_singular_value,
                        :accepted_joint_z_backtracking_steps,
                        :accepted_merit,
                        :accepted_reference,
                        :accepted_residual_history,
                        :accepted_z,
                        :accepted_z_history,
                        :actual_u_mix_ratio,
                        :actual_z_mix_ratio,
                        :amn_sha256,
                        :apply_symmetry,
                        :basis_sha256,
                        :best_polar_centers,
                        :best_polar_frames,
                        :best_polar_objective,
                        :best_polar_spreads,
                        :compatibility,
                        :config,
                        :config_sha256,
                        :convergence_values,
                        :retained_disentanglement_nonconverged,
                        :diagnostics,
                        :disentanglement_objective_history,
                        :effective_algorithms,
                        :effective_compatibility_policy,
                        :epoch,
                        :fixed_complete,
                        :fixed_mode,
                        :fixed_source_qualified,
                        :fixed_stability_count,
                        :fixed_stationary,
                        :fixed_stationary_count,
                        :frozen_indices,
                        :full_constraint_scope,
                        :gradient_fallback_active,
                        :gradient_steps,
                        :grassmann_actual_decrease_history,
                        :grassmann_gradient_history,
                        :grassmann_predicted_decrease_history,
                        :grassmann_projector_change_history,
                        :grassmann_radius_history,
                        :grassmann_ratio_history,
                        :grassmann_trust_radius,
                        :history,
                        :improvement_streak,
                        :included_bands,
                        :initialization_report,
                        :input_summary,
                        :irreducible,
                        :iteration,
                        :iteration_phase,
                        :joint_mode,
                        :last_accepted_u_step_scale,
                        :latest_restart_state,
                        :localization_initial_frames,
                        :localization_objective_history,
                        :localization_projector_drift_history,
                        :localization_reference_frames,
                        :localization_trial_accepted,
                        :localization_trial_actual_changes,
                        :localization_trial_directional_derivatives,
                        :localization_trial_iterations,
                        :localization_trial_objectives,
                        :localization_trial_required_changes,
                        :localization_trial_step_scales,
                        :localization_trial_sweeps,
                        :minimum_localization_diagonal_phase_margin,
                        :mmn,
                        :nb,
                        :nk,
                        :num_wannier,
                        :observer,
                        :optimizer_phase,
                        :outer_indices,
                        :phase_branch_backtracking_extension_count,
                        :plan,
                        :prior_elapsed,
                        :projector_covariance_tolerance,
                        :proposal_z_mix_ratio,
                        :rejected_steps,
                        :representation,
                        :sealed_subspace_frames,
                        :sealed_subspace_projectors,
                        :spectrum_audit,
                        :stage_stop_reason,
                        :start_iteration,
                        :started_ns,
                        :stencil,
                        :tangent_plans,
                        :trajectory_previous_frames,
                        :trajectory_two_step_frames,
                        :two_stage_complete,
                        :u_stability_count,
                        :u_steps,
                        :wannier90_reference_omega_i,
                        :wannier90_reference_overlaps,
                        :wannier90_reference_unitaries,
                        :weights,
                        :z_residual,
                        :z_stability_count,
                        :z_steps,
                    ),
                    Tuple{
                        NamedTuple{
                            (
                                :success,
                                :code,
                                :frames,
                                :centers,
                                :spreads,
                                :directional,
                                :u_residual,
                                :gradient_rms,
                                :projection_converged,
                                :projection_iterations,
                                :projection_residual,
                                :completed_sweeps,
                                :accepted_step_scale,
                                :backtracking_steps,
                                :trial_objective,
                                :accepted_objective,
                                :localization_spectra,
                                :localization_ranks,
                                :localization_conditions,
                                :raw_eigenphases,
                                :aligned_eigenphases,
                                :raw_geodesic_distances,
                                :aligned_geodesic_distances,
                                :block_permutations,
                                :block_phases,
                                :polar_fallback_triggered,
                                :active_localization_algorithm,
                                :base_objective,
                                :trial_zero_objective,
                                :trial_zero_frame_residual,
                                :attempted_step_scales,
                                :attempted_objectives,
                                :attempted_required_changes,
                                :attempted_actual_changes,
                                :attempted_directional_derivatives,
                                :attempted_sweeps,
                                :attempted_accepted,
                                :directional_derivative,
                                :fixed_projector_drift,
                                :accepted_required_change,
                                :accepted_actual_change,
                                :minimum_diagonal_phase_margin,
                                :minimum_phase_kpoint,
                                :minimum_phase_neighbor,
                                :minimum_phase_wannier,
                                :minimum_phase_value,
                                :branch_safe_backtracking_triggered,
                                :previous_u_gradient,
                                :previous_u_direction,
                                :u_cg_iteration,
                                :u_cg_restart_count,
                                :cg_beta,
                                :cg_restarted,
                                :cg_restart_reason,
                                :cg_descent_cosine,
                                :kstar_gradient_rms,
                                :maximum_kstar_gradient_rms,
                                :maximum_kstar_gradient_index,
                                :transport_minimum_singular_value,
                                :transport_maximum_condition,
                                :transported_omega_i,
                                :u_phase_contract,
                                :u_active_orbit_sha256,
                                :u_active_orbit_count,
                                :generalized_gradient_rms,
                                :u_lbfgs_s_history,
                                :u_lbfgs_y_history,
                                :u_lbfgs_rho_history,
                                :u_lbfgs_restart_count,
                                :u_optimizer_restart_reason,
                                :subspaces,
                                :raw_amn_alignment_applied,
                                :raw_amn_alignment_minimum_singular_value,
                                :raw_amn_alignment_maximum_condition,
                                :raw_amn_alignment_projector_drift,
                                :raw_amn_alignment_completion_count,
                                :localization_initial_frames,
                                :corepresentation_transport_applied,
                                :corepresentation_transport_minimum_singular_value,
                                :corepresentation_transport_maximum_condition,
                                :corepresentation_transport_projector_drift,
                                :corepresentation_transport_target_symmetry,
                                :spread_total,
                                :spread_std,
                                :covariance_error,
                                :projector_residual,
                                :wcc_step,
                                :spread_step,
                                :z_boundary_gap,
                            ),
                            Tuple{
                                Bool,
                                Symbol,
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Array{Float64, 2},
                                Array{Float64, 1},
                                Nothing,
                                Float64,
                                Float64,
                                Bool,
                                Int64,
                                Float64,
                                Int64,
                                Float64,
                                Int64,
                                Float64,
                                Float64,
                                Array{Array{Float64, 1}, 1},
                                Array{Int64, 1},
                                Array{Float64, 1},
                                Array{Array{Float64, 1}, 1},
                                Array{Array{Float64, 1}, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Array{Int64, 1}, 1},
                                Array{Array{Float64, 1}, 1},
                                Bool,
                                Symbol,
                                Float64,
                                Float64,
                                Float64,
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Int64, 1},
                                Array{Bool, 1},
                                Float64,
                                Float64,
                                Float64,
                                Float64,
                                Float64,
                                Int64,
                                Int64,
                                Int64,
                                Float64,
                                Bool,
                                Nothing,
                                Nothing,
                                Int64,
                                Int64,
                                Float64,
                                Bool,
                                Symbol,
                                Float64,
                                Array{Float64, 1},
                                Float64,
                                Int64,
                                Float64,
                                Float64,
                                Float64,
                                String,
                                String,
                                Int64,
                                Float64,
                                Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                                Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                                Array{Float64, 1},
                                Int64,
                                Symbol,
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Bool,
                                Float64,
                                Float64,
                                Float64,
                                Int64,
                                Nothing,
                                Bool,
                                Vararg{Float64, 11},
                            },
                        },
                        Base.Dict{String, String},
                        Bool,
                        Symbol,
                        Bool,
                        Symbol,
                        Float64,
                        Float64,
                        Int64,
                        Float64,
                        NTuple{4, Float64},
                        Array{Float64, 2},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Float64, 2},
                        Float64,
                        Float64,
                        String,
                        Bool,
                        String,
                        Array{Float64, 2},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Float64,
                        Array{Float64, 1},
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                        String,
                        Array{Array{Float64, 1}, 1},
                        Bool,
                        Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        Array{Float64, 1},
                        NamedTuple{
                            (:disentanglement, :localization, :profile, :default_selection_reason),
                            Tuple{Symbol, Symbol, Symbol, String},
                        },
                        Symbol,
                        Int64,
                        Bool,
                        Bool,
                        Bool,
                        Int64,
                        Bool,
                        Int64,
                        Array{Array{Int64, 1}, 1},
                        Bool,
                        Bool,
                        Int64,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Float64,
                        Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                        Int64,
                        Array{Base.BitArray{1}, 1},
                        Nothing,
                        Base.Dict{String, String},
                        Array{Int64, 1},
                        Int64,
                        Symbol,
                        Bool,
                        Float64,
                        WannierNLQG.Wannierization.WannierizationRestartState,
                        Nothing,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Bool, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Float64,
                        WannierNLQG.IO.WannierMMN,
                        Int64,
                        Int64,
                        Int64,
                        WannierNLQGWannierizationExt.WorkflowOrchestration.var"#109#115"{
                            Base.RefValue{String},
                            Base.RefValue{String},
                            Base.RefValue{String},
                            WannierNLQGWannierizationExt.OperatorExport.var"#253#254"{
                                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                                WannierNLQG.SymmetryFoundation.BandRepresentation,
                                NamedTuple{
                                    (
                                        :checkpoint,
                                        :validated,
                                        :log,
                                        :packed,
                                        :wannier90,
                                        :tb_symmetry_json,
                                    ),
                                    NTuple{6, String},
                                },
                                Base.IOStream,
                                Base.Dict{String, String},
                            },
                            Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        },
                        Symbol,
                        Array{Array{Int64, 1}, 1},
                        Int64,
                        WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                        Float64,
                        Float64,
                        Float64,
                        Int64,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        Nothing,
                        Nothing,
                        WannierNLQGWannierizationExt.SolverCheckpoint.HermitianSpectrumAudit,
                        Nothing,
                        Int64,
                        UInt64,
                        WannierNLQG.Wannierization.WannierizationFiniteDifferenceStencil,
                        Array{
                            Union{
                                Nothing,
                                WannierNLQGWannierizationExt.SolverCheckpoint.TargetSymmetryTangentPlan,
                            },
                            1,
                        },
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Nothing,
                        Bool,
                        Int64,
                        Int64,
                        Nothing,
                        Nothing,
                        Nothing,
                        Array{Float64, 1},
                        Float64,
                        Int64,
                        Int64,
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGWannierizationExt.SolverCheckpoint.var"#399#401",
                Array{Array{Base.Complex{Float64}, 2}, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.collect),
                Base.Generator{
                    Array{Array{Base.Complex{Float64}, 2}, 1},
                    WannierNLQGWannierizationExt.SolverCheckpoint.var"#399#401",
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getindex),
                Type{Int64},
                Int64,
                Int64,
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.getindex), Type{Int64}, Int64},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getindex),
                Array{Array{Base.Complex{Float64}, 2}, 1},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :fixed_subspace_projectors,
                        :fixed_subspace_frames,
                        :localization_initial_frames,
                    ),
                    Tuple{
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Nothing,
                    },
                },
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._restart_state),
                Int64,
                Array{Array{Base.Complex{Float64}, 2}, 1},
                Array{Array{Base.Complex{Float64}, 2}, 1},
                Array{Float64, 2},
                Array{Float64, 1},
                Array{Array{Float64, 1}, 1},
                Array{Base.BitArray{1}, 1},
                Float64,
                String,
                String,
                WannierNLQG.Wannierization.WannierizationFiniteDifferenceStencil,
                String,
                String,
                WannierNLQG.Wannierization.WannierizationOptimizerState,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGWannierizationExt.SolverCheckpoint._finish_solver_iteration),
                NamedTuple{
                    (
                        :actual_u_mix_ratio,
                        :actual_z_mix_ratio,
                        :amn_sha256,
                        :anderson_residual_history,
                        :anderson_z_history,
                        :apply_symmetry,
                        :basis_sha256,
                        :best_polar_centers,
                        :best_polar_frames,
                        :best_polar_objective,
                        :best_polar_spreads,
                        :centers,
                        :compatibility,
                        :config,
                        :config_sha256,
                        :convergence_values,
                        :retained_disentanglement_nonconverged,
                        :diagnostics,
                        :disentanglement_objective_history,
                        :effective_algorithms,
                        :effective_compatibility_policy,
                        :epoch,
                        :fixed_complete,
                        :fixed_mode,
                        :fixed_source_qualified,
                        :fixed_stability_count,
                        :fixed_stationary,
                        :fixed_stationary_count,
                        :frames,
                        :frozen_indices,
                        :full_constraint_scope,
                        :gradient_fallback_active,
                        :gradient_steps,
                        :grassmann_actual_decrease_history,
                        :grassmann_gradient_history,
                        :grassmann_predicted_decrease_history,
                        :grassmann_projector_change_history,
                        :grassmann_radius_history,
                        :grassmann_ratio_history,
                        :grassmann_trust_radius,
                        :history,
                        :improvement_streak,
                        :included_bands,
                        :initialization_report,
                        :input_summary,
                        :iteration,
                        :last_accepted_u_step_scale,
                        :last_anderson_reason,
                        :last_cg_beta,
                        :last_cg_restart_reason,
                        :last_u_optimizer_restart_reason,
                        :latest_restart_state,
                        :localization_initial_frames,
                        :localization_objective_history,
                        :localization_projector_drift_history,
                        :localization_reference_frames,
                        :localization_trial_accepted,
                        :localization_trial_actual_changes,
                        :localization_trial_directional_derivatives,
                        :localization_trial_iterations,
                        :localization_trial_objectives,
                        :localization_trial_required_changes,
                        :localization_trial_step_scales,
                        :localization_trial_sweeps,
                        :minimum_localization_diagonal_phase_margin,
                        :mmn,
                        :nb,
                        :nk,
                        :num_wannier,
                        :observer,
                        :optimizer_phase,
                        :outer_indices,
                        :phase_branch_backtracking_extension_count,
                        :plan,
                        :previous_merit,
                        :previous_u_direction,
                        :previous_u_gradient,
                        :prior_elapsed,
                        :projector_covariance_tolerance,
                        :rejected_steps,
                        :representation,
                        :residual_reference,
                        :result,
                        :sealed_subspace_frames,
                        :sealed_subspace_projectors,
                        :spectrum_audit,
                        :spreads,
                        :stage_stop_reason,
                        :start_iteration,
                        :started_ns,
                        :stencil,
                        :tangent_plans,
                        :total_spread_window_std,
                        :trajectory_previous_frames,
                        :trajectory_two_step_frames,
                        :two_stage_complete,
                        :u_active_orbit_count,
                        :u_branch_signature,
                        :u_cg_iteration,
                        :u_cg_restart_count,
                        :u_generalized_gradient_rms,
                        :u_lbfgs_restart_count,
                        :u_lbfgs_rho_history,
                        :u_lbfgs_s_history,
                        :u_lbfgs_y_history,
                        :u_stability_count,
                        :u_steps,
                        :wannier90_reference_omega_i,
                        :wannier90_reference_overlaps,
                        :wannier90_reference_unitaries,
                        :weights,
                        :z_previous,
                        :z_stability_count,
                        :z_steps,
                    ),
                    Tuple{
                        Float64,
                        Float64,
                        String,
                        Array{Float64, 2},
                        Array{Float64, 2},
                        Bool,
                        String,
                        Array{Float64, 2},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Float64,
                        Array{Float64, 1},
                        Array{Float64, 2},
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                        String,
                        Array{Array{Float64, 1}, 1},
                        Bool,
                        Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        Array{Float64, 1},
                        NamedTuple{
                            (:disentanglement, :localization, :profile, :default_selection_reason),
                            Tuple{Symbol, Symbol, Symbol, String},
                        },
                        Symbol,
                        Int64,
                        Bool,
                        Bool,
                        Bool,
                        Int64,
                        Bool,
                        Int64,
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Array{Int64, 1}, 1},
                        Bool,
                        Bool,
                        Int64,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Float64,
                        Array{WannierNLQG.Wannierization.WannierizationIteration, 1},
                        Int64,
                        Array{Base.BitArray{1}, 1},
                        Nothing,
                        Base.Dict{String, String},
                        Int64,
                        Float64,
                        Symbol,
                        Float64,
                        Symbol,
                        Symbol,
                        WannierNLQG.Wannierization.WannierizationRestartState,
                        Nothing,
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Bool, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Float64, 1},
                        Array{Int64, 1},
                        Float64,
                        WannierNLQG.IO.WannierMMN,
                        Int64,
                        Int64,
                        Int64,
                        WannierNLQGWannierizationExt.WorkflowOrchestration.var"#109#115"{
                            Base.RefValue{String},
                            Base.RefValue{String},
                            Base.RefValue{String},
                            WannierNLQGWannierizationExt.OperatorExport.var"#253#254"{
                                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                                WannierNLQG.SymmetryFoundation.BandRepresentation,
                                NamedTuple{
                                    (
                                        :checkpoint,
                                        :validated,
                                        :log,
                                        :packed,
                                        :wannier90,
                                        :tb_symmetry_json,
                                    ),
                                    NTuple{6, String},
                                },
                                Base.IOStream,
                                Base.Dict{String, String},
                            },
                            Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        },
                        Symbol,
                        Array{Array{Int64, 1}, 1},
                        Int64,
                        WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
                        Float64,
                        Nothing,
                        Nothing,
                        Float64,
                        Float64,
                        Int64,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        NTuple{4, Float64},
                        NamedTuple{
                            (
                                :success,
                                :code,
                                :frames,
                                :centers,
                                :spreads,
                                :directional,
                                :u_residual,
                                :gradient_rms,
                                :projection_converged,
                                :projection_iterations,
                                :projection_residual,
                                :completed_sweeps,
                                :accepted_step_scale,
                                :backtracking_steps,
                                :trial_objective,
                                :accepted_objective,
                                :localization_spectra,
                                :localization_ranks,
                                :localization_conditions,
                                :raw_eigenphases,
                                :aligned_eigenphases,
                                :raw_geodesic_distances,
                                :aligned_geodesic_distances,
                                :block_permutations,
                                :block_phases,
                                :polar_fallback_triggered,
                                :active_localization_algorithm,
                                :base_objective,
                                :trial_zero_objective,
                                :trial_zero_frame_residual,
                                :attempted_step_scales,
                                :attempted_objectives,
                                :attempted_required_changes,
                                :attempted_actual_changes,
                                :attempted_directional_derivatives,
                                :attempted_sweeps,
                                :attempted_accepted,
                                :directional_derivative,
                                :fixed_projector_drift,
                                :accepted_required_change,
                                :accepted_actual_change,
                                :minimum_diagonal_phase_margin,
                                :minimum_phase_kpoint,
                                :minimum_phase_neighbor,
                                :minimum_phase_wannier,
                                :minimum_phase_value,
                                :branch_safe_backtracking_triggered,
                                :previous_u_gradient,
                                :previous_u_direction,
                                :u_cg_iteration,
                                :u_cg_restart_count,
                                :cg_beta,
                                :cg_restarted,
                                :cg_restart_reason,
                                :cg_descent_cosine,
                                :kstar_gradient_rms,
                                :maximum_kstar_gradient_rms,
                                :maximum_kstar_gradient_index,
                                :transport_minimum_singular_value,
                                :transport_maximum_condition,
                                :transported_omega_i,
                                :u_phase_contract,
                                :u_active_orbit_sha256,
                                :u_active_orbit_count,
                                :generalized_gradient_rms,
                                :u_lbfgs_s_history,
                                :u_lbfgs_y_history,
                                :u_lbfgs_rho_history,
                                :u_lbfgs_restart_count,
                                :u_optimizer_restart_reason,
                                :subspaces,
                                :raw_amn_alignment_applied,
                                :raw_amn_alignment_minimum_singular_value,
                                :raw_amn_alignment_maximum_condition,
                                :raw_amn_alignment_projector_drift,
                                :raw_amn_alignment_completion_count,
                                :localization_initial_frames,
                                :corepresentation_transport_applied,
                                :corepresentation_transport_minimum_singular_value,
                                :corepresentation_transport_maximum_condition,
                                :corepresentation_transport_projector_drift,
                                :corepresentation_transport_target_symmetry,
                                :spread_total,
                                :spread_std,
                                :covariance_error,
                                :projector_residual,
                                :wcc_step,
                                :spread_step,
                                :z_boundary_gap,
                            ),
                            Tuple{
                                Bool,
                                Symbol,
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Array{Float64, 2},
                                Array{Float64, 1},
                                Nothing,
                                Float64,
                                Float64,
                                Bool,
                                Int64,
                                Float64,
                                Int64,
                                Float64,
                                Int64,
                                Float64,
                                Float64,
                                Array{Array{Float64, 1}, 1},
                                Array{Int64, 1},
                                Array{Float64, 1},
                                Array{Array{Float64, 1}, 1},
                                Array{Array{Float64, 1}, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Array{Int64, 1}, 1},
                                Array{Array{Float64, 1}, 1},
                                Bool,
                                Symbol,
                                Float64,
                                Float64,
                                Float64,
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Float64, 1},
                                Array{Int64, 1},
                                Array{Bool, 1},
                                Float64,
                                Float64,
                                Float64,
                                Float64,
                                Float64,
                                Int64,
                                Int64,
                                Int64,
                                Float64,
                                Bool,
                                Nothing,
                                Nothing,
                                Int64,
                                Int64,
                                Float64,
                                Bool,
                                Symbol,
                                Float64,
                                Array{Float64, 1},
                                Float64,
                                Int64,
                                Float64,
                                Float64,
                                Float64,
                                String,
                                String,
                                Int64,
                                Float64,
                                Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                                Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                                Array{Float64, 1},
                                Int64,
                                Symbol,
                                Array{Array{Base.Complex{Float64}, 2}, 1},
                                Bool,
                                Float64,
                                Float64,
                                Float64,
                                Int64,
                                Nothing,
                                Bool,
                                Vararg{Float64, 11},
                            },
                        },
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        WannierNLQGWannierizationExt.SolverCheckpoint.HermitianSpectrumAudit,
                        Array{Float64, 1},
                        Nothing,
                        Int64,
                        UInt64,
                        WannierNLQG.Wannierization.WannierizationFiniteDifferenceStencil,
                        Array{
                            Union{
                                Nothing,
                                WannierNLQGWannierizationExt.SolverCheckpoint.TargetSymmetryTangentPlan,
                            },
                            1,
                        },
                        Float64,
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Bool,
                        Int64,
                        String,
                        Int64,
                        Int64,
                        Float64,
                        Int64,
                        Array{Float64, 1},
                        Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                        Array{Array{Array{Base.Complex{Float64}, 2}, 1}, 1},
                        Int64,
                        Int64,
                        Nothing,
                        Nothing,
                        Nothing,
                        Array{Float64, 1},
                        Array{Array{Base.Complex{Float64}, 2}, 1},
                        Int64,
                        Int64,
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQG.Wannierization.TBSymmetryMetric,
                    Core.AddrSpace{Core}(0x00),
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getindex),
                Type{WannierNLQG.Wannierization.TBSymmetryMetric},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.hasproperty),
                NamedTuple{
                    (
                        :mmn,
                        :amn,
                        :mmn_file,
                        :amn_file,
                        :raw_amn_file,
                        :source_kind,
                        :paw_result,
                        :gauge_sha256,
                        :gauge_provenance_file,
                    ),
                    Tuple{
                        WannierNLQG.IO.WannierMMN,
                        Nothing,
                        String,
                        Nothing,
                        Nothing,
                        String,
                        Nothing,
                        String,
                        Nothing,
                    },
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.join),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Array{Int64, 1},
                Char,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getindex),
                Type{WannierNLQG.Wannierization.WannierizationDiagnostic},
                WannierNLQG.Wannierization.WannierizationDiagnostic,
                WannierNLQG.Wannierization.WannierizationDiagnostic,
                WannierNLQG.Wannierization.WannierizationDiagnostic,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.size),
                Array{Base.Complex{Float64}, 3},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base._all),
                typeof(Base.isfinite),
                Array{Base.Complex{Float64}, 3},
                Base.Colon,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.view),
                Array{Base.Complex{Float64}, 3},
                Function,
                Function,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(LinearAlgebra.norm),
                Array{Base.Complex{Float64}, 2},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.show),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{Symbol, Float64, Float64, Int64, Int64, NTuple{4, Float64}, Float64},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                },
                NTuple{4, Float64},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.show),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{Symbol, Int64, Int64, Int64, Int64, Int64, Float64, Bool, Int64, Float64},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.show),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{Int64, Int64, Float64, Symbol, Symbol},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.show),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{
                    Symbol,
                    Float64,
                    Int64,
                    Int64,
                    Int64,
                    Float64,
                    Bool,
                    Symbol,
                    Float64,
                    Float64,
                    Int64,
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.show),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{Float64, Float64, Int64, Int64, Float64, Float64, Symbol},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.show),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{String, String, Int64, Float64, Array{Float64, 1}, Int64, Symbol},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)},
                    },
                },
                Array{Float64, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.show),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{Symbol, Symbol, String},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.show),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Tuple{String, String},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{(:operator_target_contract,), Tuple{Nothing}},
                typeof(WannierNLQGWannierizationExt.OperatorExport._export_wannierization_tb),
                WannierNLQG.Wannierization.WannierizationResult,
                WannierNLQG.IO.WannierEIG,
                WannierNLQG.IO.WannierMMN,
                WannierNLQG.Wannierization.SymmetryAdaptedWannierizationConfig,
                NamedTuple{
                    (:checkpoint, :validated, :log, :packed, :wannier90, :tb_symmetry_json),
                    NTuple{6, String},
                },
                WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getproperty),
                WannierNLQGWannierizationExt.OperatorExport.AuthoritativeBandHamiltonian,
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                WannierNLQGWannierizationExt.OperatorExport.var"#120#123"{
                    Float64,
                    Int64,
                    Symbol,
                    Base.Dict{String, Float64},
                    WannierNLQG.IO.WannierCHK,
                },
                Array{Base.Complex{Float64}, 3},
                String,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Pair{A, B} where {B} where A},
                Tuple{Int64, Int64, Int64},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.empty),
                Base.Dict{Any, Any},
                Type{Tuple{Int64, Int64, Int64}},
                Type{Int64},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                WannierNLQGWannierizationExt.OperatorExport.var"#120#123"{
                    Float64,
                    Int64,
                    Symbol,
                    Base.Dict{String, Float64},
                    WannierNLQG.IO.WannierCHK,
                },
                Array{Base.Complex{Float64}, 4},
                String,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.get),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Tuple{Int64, Int64, Int64},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.view),
                Array{Base.Complex{Float64}, 4},
                Function,
                Function,
                Function,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.conj),
                Base.SubArray{
                    Base.Complex{Float64},
                    3,
                    Array{Base.Complex{Float64}, 4},
                    Tuple{
                        Base.Slice{Base.OneTo{Int64}},
                        Base.Slice{Base.OneTo{Int64}},
                        Base.Slice{Base.OneTo{Int64}},
                        Int64,
                    },
                    true,
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(*)),
                Float64,
                Array{Base.Complex{Float64}, 3},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(+)),
                Base.SubArray{
                    Base.Complex{Float64},
                    3,
                    Array{Base.Complex{Float64}, 4},
                    Tuple{
                        Base.Slice{Base.OneTo{Int64}},
                        Base.Slice{Base.OneTo{Int64}},
                        Base.Slice{Base.OneTo{Int64}},
                        Int64,
                    },
                    true,
                },
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{3},
                    Nothing,
                    typeof(Base.:(*)),
                    Tuple{Float64, Array{Base.Complex{Float64}, 3}},
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.Broadcast.materialize!),
                Base.SubArray{
                    Base.Complex{Float64},
                    3,
                    Array{Base.Complex{Float64}, 4},
                    Tuple{
                        Base.Slice{Base.OneTo{Int64}},
                        Base.Slice{Base.OneTo{Int64}},
                        Base.Slice{Base.OneTo{Int64}},
                        Int64,
                    },
                    true,
                },
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{3},
                    Nothing,
                    typeof(Base.:(+)),
                    Tuple{
                        Base.SubArray{
                            Base.Complex{Float64},
                            3,
                            Array{Base.Complex{Float64}, 4},
                            Tuple{
                                Base.Slice{Base.OneTo{Int64}},
                                Base.Slice{Base.OneTo{Int64}},
                                Base.Slice{Base.OneTo{Int64}},
                                Int64,
                            },
                            true,
                        },
                        Base.Broadcast.Broadcasted{
                            Base.Broadcast.DefaultArrayStyle{3},
                            Nothing,
                            typeof(Base.:(*)),
                            Tuple{Float64, Array{Base.Complex{Float64}, 3}},
                        },
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.grow_to!),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.OperatorExport.var"#258#259"{Array{Int64, 2}},
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.get),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Tuple{Int64, Int64, Int64},
                Nothing,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.adjoint),
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 3},
                    Tuple{Base.Slice{Base.OneTo{Int64}}, Base.Slice{Base.OneTo{Int64}}, Int64},
                    true,
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.maximum),
                Function,
                Array{Base.Complex{Float64}, 2},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base._mapreduce_dim),
                Function,
                Function,
                Base._InitialValue,
                Array{Base.Complex{Float64}, 2},
                Base.Colon,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.view),
                Array{Base.Complex{Float64}, 4},
                Function,
                Function,
                Int64,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.adjoint),
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 4},
                    Tuple{
                        Base.Slice{Base.OneTo{Int64}},
                        Base.Slice{Base.OneTo{Int64}},
                        Int64,
                        Int64,
                    },
                    true,
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.:(-)),
                Base.SubArray{
                    Base.Complex{Float64},
                    2,
                    Array{Base.Complex{Float64}, 4},
                    Tuple{
                        Base.Slice{Base.OneTo{Int64}},
                        Base.Slice{Base.OneTo{Int64}},
                        Int64,
                        Int64,
                    },
                    true,
                },
                LinearAlgebra.Adjoint{
                    Base.Complex{Float64},
                    Base.SubArray{
                        Base.Complex{Float64},
                        2,
                        Array{Base.Complex{Float64}, 4},
                        Tuple{
                            Base.Slice{Base.OneTo{Int64}},
                            Base.Slice{Base.OneTo{Int64}},
                            Int64,
                            Int64,
                        },
                        true,
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(JSON3.defaultminimum),
                Base.Dict{String, String},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Base.MappingRF{typeof(JSON3.defaultminimum), Base.BottomRF{typeof(Base.add_sum)}},
                Int64,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(JSON3.write),
                StructTypes.DictType,
                Array{UInt8, 1},
                Int64,
                Int64,
                Base.Dict{String, String},
            },
        )
        _record_precompile(Tuple{typeof(_first_solve_compile_call), Type{String}, Array{UInt8, 1}})
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.print),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                WannierNLQG.Wannierization.WannierizationStatus,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.join),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Array{Base.SubString{String}, 1},
                Char,
            },
        )
        false
        false
        false
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Printf.computelen),
                Array{Base.UnitRange{Int64}, 1},
                Tuple{
                    Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                    Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                    Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}},
                    Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}},
                },
                Tuple{Int64, Int64, Float64, Float64},
            },
        )
        false
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Printf.fmt),
                Array{UInt8, 1},
                Int64,
                Tuple{Int64, Int64, Float64, Float64},
                Int64,
                Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}}},
                Bool,
                Bool,
                Bool,
                Bool,
                Bool,
                Int64,
                Int64,
                Bool,
                Bool,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Printf.fmt),
                Array{UInt8, 1},
                Int64,
                Float64,
                Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(JSON3.read),
                String,
                Type{Array{Base.Dict{String, Any}, 1}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.empty),
                Base.Dict{String, String},
                Type{String},
                Type{Any},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.grow_to!),
                Base.Dict{String, Any},
                Tuple{
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, Bool},
                    Pair{String, Bool},
                    Pair{String, Array{Int64, 1}},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Int64},
                    Pair{String, Array{Float64, 2}},
                    Pair{String, Array{Float64, 2}},
                    Pair{String, Array{Float64, 2}},
                    Pair{String, Array{Float64, 2}},
                    Pair{String, Array{Int64, 2}},
                    Pair{String, String},
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Base.Dict{K, V} where {V} where K},
                Tuple{
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Bool},
                    Vararg{Pair{String, Float64}, 7},
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.grow_to!),
                Base.Dict{String, Any},
                Tuple{
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, Int64},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Float64},
                    Pair{String, Bool},
                    Vararg{Pair{String, Float64}, 7},
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.in!),
                Tuple{Int64, Int64, Int64},
                Base.Set{Tuple{Int64, Int64, Int64}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.push!),
                Array{Tuple{Int64, Int64, Int64}, 1},
                Tuple{Int64, Int64, Int64},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.length),
                Array{Tuple{Int64, Int64, Int64}, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGWannierizationExt.OperatorExport._authoritative_array_sha256),
                Array{Base.Complex{Float64}, 3},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.join),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                NTuple{5, String},
                Char,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Pair{A, B} where {B} where A},
                String,
                Base.Dict{String, Any},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Pair{A, B} where {B} where A},
                String,
                Base.Dict{String, String},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._profile_qualification_digest_value!,
                ),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                String,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._profile_qualification_digest_value!,
                ),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Base.Dict{String, String},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._profile_qualification_digest_value!,
                ),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Float64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._profile_qualification_digest_value!,
                ),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                Bool,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGWannierizationExt.OperatorExport._authoritative_array_sha256),
                Array{Base.Complex{Float64}, 4},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._profile_export_numerical_checks!,
                ),
                Array{Base.Dict{String, Any}, 1},
                Symbol,
                Base.Dict{String, String},
                String,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._profile_export_numerical_checks!,
                ),
                Array{Base.Dict{String, Any}, 1},
                Symbol,
                Base.Dict{String, Base.Dict{String, Any}},
                String,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.merge),
                Base.Dict{String, String},
                Base.Dict{String, String},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Base.Dict{K, V} where {V} where K},
                Tuple{
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Base.Dict{String, String}},
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.merge),
                Base.Dict{String, Any},
                Base.Dict{String, Any},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :profile,
                        :operator_tasks,
                        :overwrite,
                        :paired_tb_sha256,
                        :provenance,
                        :geometry,
                        :diagnostics,
                        :eligibility,
                    ),
                    Tuple{Symbol, Tuple{}, Bool, String, Vararg{Base.Dict{String, Any}, 4}},
                },
                typeof(WannierNLQG.IO.write_real_space_operator_bundle),
                String,
                Array{Float64, 2},
                Array{Int64, 1},
                Base.Dict{
                    WannierNLQG.Core.RealSpaceOperatorKind,
                    WannierNLQG.Core.RealSpaceOperator{N} where N,
                },
            },
        )
        _record_precompile(Tuple{typeof(_first_solve_compile_call), typeof(Base.:(==)), Int64})
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQG.Core.RealSpaceOperatorKind,
                    Core.AddrSpace{Core}(0x00),
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.indexed_iterate),
                Pair{String, Bool},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.indexed_iterate),
                Pair{String, Bool},
                Int64,
                Int64,
            },
        )
        _record_precompile(Tuple{typeof(_first_solve_compile_call), Type{UInt8}, Bool})
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{NamedTuple{(:read, :write, :append, :truncate), T} where T <: Tuple},
                Tuple{Bool, Bool, Nothing, Nothing},
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), Dates.var"##s53#31", Vararg{Any, 5}},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :profile,
                        :operator_tasks,
                        :overwrite,
                        :paired_tb_sha256,
                        :provenance,
                        :symmetry,
                        :geometry,
                        :diagnostics,
                        :eligibility,
                    ),
                    Tuple{Symbol, Tuple{}, Bool, String, Vararg{Base.Dict{String, Any}, 5}},
                },
                typeof(WannierNLQGOperatorBundleExt.write_real_space_operator_bundle),
                String,
                Array{Float64, 2},
                Array{Int64, 1},
                Base.Dict{
                    WannierNLQG.Core.RealSpaceOperatorKind,
                    WannierNLQG.Core.RealSpaceOperator{N} where N,
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.iterate),
                Base.KeySet{
                    WannierNLQG.Core.RealSpaceOperatorKind,
                    Base.Dict{
                        WannierNLQG.Core.RealSpaceOperatorKind,
                        WannierNLQG.Core.RealSpaceOperator{N} where N,
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.iterate),
                Base.KeySet{
                    WannierNLQG.Core.RealSpaceOperatorKind,
                    Base.Dict{
                        WannierNLQG.Core.RealSpaceOperatorKind,
                        WannierNLQG.Core.RealSpaceOperator{N} where N,
                    },
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.in),
                WannierNLQG.Core.RealSpaceOperatorKind,
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{(:standard, :numerical_audit), Tuple{Bool, Base.RefValue{Float64}}},
                typeof(WannierNLQGOperatorBundleExt._bundle_wannier_centers),
                Base.Dict{
                    WannierNLQG.Core.RealSpaceOperatorKind,
                    WannierNLQG.Core.RealSpaceOperator{N} where N,
                },
                Array{Int64, 2},
                Array{Int64, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getindex),
                Array{Base.Complex{Float64}, 4},
                Vararg{Int64, 4},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.:(/)),
                Base.Complex{Float64},
                Int64,
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.real), Base.Complex{Float64}},
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.imag), Base.Complex{Float64}},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.setindex!),
                Base.RefValue{Float64},
                Float64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGOperatorBundleExt._validated_geometry_metadata),
                Base.Dict{String, Any},
                Int64,
                Array{Float64, 2},
                Array{Float64, 2},
                Array{Float64, 2},
                Array{Int64, 1},
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.length), Array{Int64, 1}},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base._all),
                Base.Fix2{typeof(Base.:(>)), Int64},
                Array{Int64, 1},
                Base.Colon,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.Broadcast.broadcasted),
                typeof(Base.:(-)),
                Array{Float64, 2},
                Array{Float64, 2},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.:(-)),
                    Tuple{Array{Float64, 2}, Array{Float64, 2}},
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.mapfoldl_impl),
                typeof(Base.abs),
                typeof(Base.max),
                Float64,
                Array{Float64, 2},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.memoryref),
                GenericMemory{
                    :not_atomic,
                    WannierNLQG.IO.OperatorBundleIndexEntry,
                    Core.AddrSpace{Core}(0x00),
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.iterate),
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.haskey),
                Base.Dict{
                    WannierNLQG.Core.RealSpaceOperatorKind,
                    WannierNLQG.Core.RealSpaceOperator{N} where N,
                },
                WannierNLQG.Core.RealSpaceOperatorKind,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGOperatorBundleExt._component_values),
                WannierNLQG.Core.RealSpaceOperator{3},
                Tuple{Int8, Int8},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.append!),
                Array{Base.Complex{Float64}, 1},
                Array{Base.Complex{Float64}, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.length),
                Array{Base.Complex{Float64}, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.iterate),
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGOperatorBundleExt._component_values),
                WannierNLQG.Core.RealSpaceOperator{4},
                Tuple{Int8, Int8},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.setindex!),
                Array{String, 1},
                String,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.Broadcast.copyto_nonleaf!),
                Array{String, 1},
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Tuple{Base.OneTo{Int64}},
                    typeof(getfield),
                    Tuple{
                        Base.Broadcast.Extruded{
                            Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1},
                            Tuple{Bool},
                            Tuple{Int64},
                        },
                        Base.RefValue{Symbol},
                    },
                },
                Base.OneTo{Int64},
                Int64,
                Int64,
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.occursin), Base.Regex, String},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGOperatorBundleExt._bind_pair_wigner_seitz_qualification),
                Base.Dict{String, Any},
                Base.Dict{String, Any},
                Symbol,
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGOperatorBundleExt._mutable_qualification_tree),
                Base.Dict{String, Base.Dict{String, Any}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGOperatorBundleExt._mutable_qualification_tree),
                String,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGOperatorBundleExt._mutable_qualification_tree),
                Bool,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGOperatorBundleExt._mutable_qualification_tree),
                Float64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGOperatorBundleExt._mutable_qualification_tree),
                Base.Dict{String, Any},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGOperatorBundleExt._mutable_qualification_tree),
                Base.Dict{String, String},
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.in), String, NTuple{5, String}},
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.keys), Base.Dict{String, Any}},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.collect),
                Base.KeySet{String, Base.Dict{String, Any}},
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.pairs), Base.Dict{String, Any}},
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.isempty), Base.Dict{String, Any}},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.indexed_iterate),
                Pair{String, Any},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.indexed_iterate),
                Pair{String, Any},
                Int64,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.iterate),
                Base.Dict{String, Any},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{
                    (:standard, :inventory),
                    Tuple{Bool, Array{WannierNLQG.Core.RealSpaceOperatorKind, 1}},
                },
                typeof(WannierNLQGOperatorBundleExt._bundle_band_frame_contract),
                Base.Dict{String, Any},
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base._any),
                WannierNLQGOperatorBundleExt.var"#62#77",
                Base.ValueIterator{Base.Dict{String, Any}},
                Base.Colon,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                WannierNLQGOperatorBundleExt.var"#62#77",
                Base.Dict{String, Any},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.get),
                Base.Dict{String, Any},
                String,
                Base.Dict{String, Any},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.get),
                Base.Dict{String, Any},
                String,
                String,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGOperatorBundleExt._construction_evidence_for_write),
                Base.Dict{String, Any},
                Base.Dict{String, Any},
            },
        )
        _record_precompile(Tuple{typeof(_first_solve_compile_call), typeof(JSON3.read), String})
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.iterate),
                JSON3.Array{
                    JSON3.Object{
                        S,
                        TT,
                    } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                    Base.CodeUnits{UInt8, String},
                    Array{UInt64, 1},
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base._all),
                WannierNLQGOperatorBundleExt.var"#12#14"{
                    JSON3.Object{
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                },
                NTuple{4, String},
                Base.Colon,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base._all),
                WannierNLQGOperatorBundleExt.var"#13#15"{
                    JSON3.Object{
                        Base.CodeUnits{UInt8, String},
                        Base.SubArray{
                            UInt64,
                            1,
                            Array{UInt64, 1},
                            Tuple{Base.UnitRange{Int64}},
                            true,
                        },
                    },
                },
                Tuple{String, String, String},
                Base.Colon,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getindex),
                JSON3.Object{
                    Base.CodeUnits{UInt8, String},
                    Base.SubArray{UInt64, 1, Array{UInt64, 1}, Tuple{Base.UnitRange{Int64}}, true},
                },
                String,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.get),
                JSON3.Object{
                    Base.CodeUnits{UInt8, String},
                    Base.SubArray{UInt64, 1, Array{UInt64, 1}, Tuple{Base.UnitRange{Int64}}, true},
                },
                String,
                String,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.iterate),
                JSON3.Array{
                    JSON3.Object{
                        S,
                        TT,
                    } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                    Base.CodeUnits{UInt8, String},
                    Array{UInt64, 1},
                },
                Tuple{Int64, Int64},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getproperty),
                NamedTuple{
                    (
                        :wannier_center_policy,
                        :real_space_replica_policy,
                        :production_eligible,
                        :minimum_distance_materialized,
                        :mp_grid,
                        :raw_centers_cartesian,
                        :raw_centers_fractional,
                        :final_centers_cartesian,
                        :final_centers_fractional,
                        :geometry_content_sha256,
                    ),
                    Tuple{
                        Symbol,
                        Symbol,
                        Bool,
                        Bool,
                        Tuple{Int64, Int64, Int64},
                        Array{Float64, 2},
                        Array{Float64, 2},
                        Array{Float64, 2},
                        Array{Float64, 2},
                        String,
                    },
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{(:task_selection,), Tuple{Nothing}},
                typeof(WannierNLQGOperatorBundleExt._scientific_content_digest),
                Symbol,
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
                Array{Float64, 2},
                Array{Int64, 2},
                Array{Int64, 1},
                Array{String, 1},
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                Bool,
                String,
                String,
                String,
                String,
                String,
                String,
                Float64,
                Vararg{String, 8},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGOperatorBundleExt.var"#68#83",
                    Base.BottomRF{typeof(Base.hcat)},
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getproperty),
                Base.MappingRF{
                    WannierNLQGOperatorBundleExt.var"#69#84",
                    Base.BottomRF{typeof(Base.hcat)},
                },
                Symbol,
            },
        )
        false
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.length),
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.setindex!),
                HDF5.Attributes,
                Int64,
                String,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.Broadcast.broadcasted),
                typeof(WannierNLQG.Core.real_space_operator_name),
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{1},
                    Nothing,
                    typeof(WannierNLQG.Core.real_space_operator_name),
                    Tuple{Array{WannierNLQG.Core.RealSpaceOperatorKind, 1}},
                },
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.join), Array{String, 1}, String},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.setindex!),
                HDF5.Attributes,
                Bool,
                String,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{UInt8},
                WannierNLQG.Core.RealSpaceOperatorKind,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.setindex!),
                HDF5.Attributes,
                UInt8,
                String,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Base.Iterators.Filter{F, I} where {I} where F},
                WannierNLQGOperatorBundleExt.var"#71#86"{WannierNLQG.Core.RealSpaceOperatorKind},
                Base.Pairs{
                    Int64,
                    WannierNLQG.IO.OperatorBundleIndexEntry,
                    Base.LinearIndices{1, Tuple{Base.OneTo{Int64}}},
                    Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1},
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGOperatorBundleExt.var"#70#85",
                Base.Iterators.Filter{
                    WannierNLQGOperatorBundleExt.var"#71#86"{
                        WannierNLQG.Core.RealSpaceOperatorKind,
                    },
                    Base.Pairs{
                        Int64,
                        WannierNLQG.IO.OperatorBundleIndexEntry,
                        Base.LinearIndices{1, Tuple{Base.OneTo{Int64}}},
                        Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1},
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.collect),
                Type{UInt64},
                Base.Generator{
                    Base.Iterators.Filter{
                        WannierNLQGOperatorBundleExt.var"#71#86"{
                            WannierNLQG.Core.RealSpaceOperatorKind,
                        },
                        Base.Pairs{
                            Int64,
                            WannierNLQG.IO.OperatorBundleIndexEntry,
                            Base.LinearIndices{1, Tuple{Base.OneTo{Int64}}},
                            Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1},
                        },
                    },
                    WannierNLQGOperatorBundleExt.var"#70#85",
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                HDF5.Group,
                String,
                String,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                HDF5.Group,
                String,
                Array{Int64, 2},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                HDF5.Group,
                String,
                Array{Float64, 2},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                HDF5.Group,
                String,
                Bool,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                HDF5.Group,
                String,
                Array{Int64, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                HDF5.Group,
                String,
                Float64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                HDF5.Group,
                String,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                HDF5.Group,
                String,
                Base.Dict{String, String},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                HDF5.Group,
                String,
                Base.Dict{String, Any},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGOperatorBundleExt._write_metadata_value),
                HDF5.Group,
                String,
                Base.Dict{String, Base.Dict{String, Any}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{NamedTuple{(:prefer_mmap,), T} where T <: Tuple},
                Tuple{Bool},
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.in), String, NTuple{11, String}},
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.in), String, NTuple{8, String}},
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.in), String, NTuple{6, String}},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{NamedTuple{(:skip_payload_sha256,), T} where T <: Tuple},
                Tuple{Bool},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{(:verify_digests,), Tuple{Bool}},
                typeof(WannierNLQGOperatorBundleExt.read_real_space_operator_bundle),
                String,
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), Type{Array{Int64, 1}}, Array{Int64, 1}},
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.size), Array{Int64, 2}, Int64},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.reinterpret),
                Type{UInt8},
                Array{Float64, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGOperatorBundleExt._read_v5_geometry),
                HDF5.File,
                Int64,
                Array{Float64, 2},
                Array{Float64, 2},
                Array{Float64, 2},
                Array{Int64, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Array{Float64, N} where N},
                UndefInitializer,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getindex),
                Array{Float64, 1},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Array{Int8, N} where N},
                UndefInitializer,
                Int64,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Array{UInt64, N} where N},
                UndefInitializer,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Array{UInt64, N} where N},
                UndefInitializer,
                Int64,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getindex),
                Array{UInt64, 1},
                Int64,
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.:(==)), UInt64, UInt64},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.:(==)),
                Tuple{Int64, Int64, Int64},
                Tuple{Int64, Int64, Int64},
            },
        )
        _record_precompile(Tuple{typeof(_first_solve_compile_call), Type{UInt8}, UInt8})
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.setindex!),
                Array{Tuple{Int8, Int8}, 1},
                Tuple{Int8, Int8},
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.:(==)),
                Array{UInt64, 1},
                Array{UInt64, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{51, 0}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{35, 0}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{2158, 0}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{7, 0}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{WannierNLQG.IO.OperatorBundleManifest},
                String,
                Symbol,
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
                Int64,
                Array{Float64, 2},
                Array{Int64, 2},
                Array{Int64, 1},
                Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1},
                Int64,
                String,
                String,
                String,
                Array{Float64, 2},
                Array{Float64, 2},
                Array{Float64, 2},
                Array{Float64, 2},
                Symbol,
                Symbol,
                Bool,
                Bool,
                Tuple{Int64, Int64, Int64},
                Float64,
                Int64,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                Bool,
                Bool,
                String,
                String,
                String,
                Int64,
                Int64,
                Int64,
                Int64,
                Float64,
                Float64,
                String,
                String,
                String,
                Nothing,
                String,
                String,
                String,
                Float64,
                Float64,
                Float64,
                Bool,
                Float64,
                Float64,
                Bool,
                Float64,
                Float64,
                Float64,
                Float64,
                Bool,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Bool,
                String,
                String,
                Nothing,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                Bool,
                Bool,
                Bool,
                String,
                String,
                String,
                String,
                String,
                String,
                String,
                Float64,
                String,
                String,
                Nothing,
                String,
                Base.Dict{String, Any},
                String,
                String,
                String,
                Bool,
                String,
                String,
                Bool,
                String,
                String,
                String,
                String,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                String,
                Array{String, 1},
                String,
                String,
                String,
                String,
                String,
                Nothing,
                Nothing,
            },
        )
        false
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base._all),
                typeof(Base.isfinite),
                Array{Base.Complex{Float64}, 4},
                Base.Colon,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getproperty),
                NamedTuple{
                    (:manifest, :lattice, :degeneracies, :operators, :read_mode, :fallback_reason),
                    Tuple{
                        WannierNLQG.IO.OperatorBundleManifest,
                        Array{Float64, 2},
                        Array{Int64, 1},
                        Base.Dict{
                            WannierNLQG.Core.RealSpaceOperatorKind,
                            WannierNLQG.Core.RealSpaceOperator{N} where N,
                        },
                        Symbol,
                        Nothing,
                    },
                },
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.:(==)),
                Array{Int64, 1},
                Array{Int64, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.:(==)),
                Array{Int64, 2},
                Array{Int64, 2},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getproperty),
                WannierNLQG.Core.RealSpaceOperator{3},
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.:(==)),
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 3},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getproperty),
                WannierNLQG.Core.RealSpaceOperator{4},
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.:(==)),
                Array{Base.Complex{Float64}, 4},
                Array{Base.Complex{Float64}, 4},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Pair{A, B} where {B} where A},
                String,
                JSON3.Array{
                    JSON3.Object{
                        S,
                        TT,
                    } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                    Base.CodeUnits{UInt8, String},
                    Array{UInt64, 1},
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Base.Dict{K, V} where {V} where K},
                Tuple{
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{
                        String,
                        JSON3.Array{
                            JSON3.Object{
                                S,
                                TT,
                            } where {
                                TT <: AbstractArray{UInt64, 1},
                            } where S <: AbstractArray{UInt8, 1},
                            Base.CodeUnits{UInt8, String},
                            Array{UInt64, 1},
                        },
                    },
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._write_construction_metadata_sidecar,
                ),
                String,
                String,
                Base.Dict{String, Any},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.merge),
                Base.Dict{String, Any},
                Base.Dict{String, String},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(JSON3.write),
                Base.IOStream,
                Base.Dict{String, Any},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(JSON3.defaultminimum),
                JSON3.Array{
                    JSON3.Object{
                        S,
                        TT,
                    } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                    Base.CodeUnits{UInt8, String},
                    Array{UInt64, 1},
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Base.MappingRF{
                    JSON3.var"#59#60"{
                        JSON3.Array{
                            JSON3.Object{
                                S,
                                TT,
                            } where {
                                TT <: AbstractArray{UInt64, 1},
                            } where S <: AbstractArray{UInt8, 1},
                            Base.CodeUnits{UInt8, String},
                            Array{UInt64, 1},
                        },
                    },
                    Base.MappingRF{
                        typeof(JSON3.defaultminimum),
                        Base.BottomRF{typeof(Base.add_sum)},
                    },
                },
                Base._InitialValue,
                Int64,
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.add_sum), UInt64, UInt64},
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Base.MappingRF{
                    JSON3.var"#59#60"{
                        JSON3.Array{
                            JSON3.Object{
                                S,
                                TT,
                            } where {
                                TT <: AbstractArray{UInt64, 1},
                            } where S <: AbstractArray{UInt8, 1},
                            Base.CodeUnits{UInt8, String},
                            Array{UInt64, 1},
                        },
                    },
                    Base.MappingRF{
                        typeof(JSON3.defaultminimum),
                        Base.BottomRF{typeof(Base.add_sum)},
                    },
                },
                Int64,
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(JSON3.write),
                StructTypes.ArrayType,
                Array{UInt8, 1},
                Int64,
                Int64,
                JSON3.Array{
                    JSON3.Object{
                        S,
                        TT,
                    } where {TT <: AbstractArray{UInt64, 1}} where S <: AbstractArray{UInt8, 1},
                    Base.CodeUnits{UInt8, String},
                    Array{UInt64, 1},
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getproperty),
                JSON3.Object{Base.CodeUnits{UInt8, String}, Array{UInt64, 1}},
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.iterate),
                Base.Dict{String, String},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Base.Dict{String, String}},
                NTuple{17, Pair{String, String}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{
                    (:hamiltonian_covariance_threshold, :persist_hdf5),
                    Tuple{Float64, Bool},
                },
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport.qualify_exported_wannierization_tb,
                ),
                String,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
                WannierNLQG.SymmetryFoundation.WannierSymmetryPlan,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGWannierizationExt.OperatorExport._tb_authority_identity),
                WannierNLQG.IO.OperatorBundleManifest,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGWannierizationExt.OperatorExport._normalized_tb_operator),
                WannierNLQG.Core.RealSpaceOperator{3},
                Array{Int64, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGWannierizationExt.OperatorExport._normalized_tb_operator),
                WannierNLQG.Core.RealSpaceOperator{4},
                Array{Int64, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGWannierizationExt.OperatorExport._centerless_tb_position),
                WannierNLQG.Core.RealSpaceOperator{4},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._qualification_hermiticity_metric,
                ),
                String,
                WannierNLQG.Core.RealSpaceOperator{3},
                Float64,
                String,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.grow_to!),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.OperatorExport.var"#317#318"{
                        WannierNLQG.Core.RealSpaceOperator{3},
                    },
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{(:init,), Tuple{Float64}},
                typeof(Base.maximum),
                Function,
                Array{Base.Complex{Float64}, 2},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base._mapreduce_dim),
                Function,
                Function,
                Float64,
                Array{Base.Complex{Float64}, 2},
                Base.Colon,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.mapfoldl_impl),
                typeof(Base.abs),
                typeof(Base.max),
                Float64,
                Array{Base.Complex{Float64}, 2},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGWannierizationExt.OperatorExport._tb_symmetry_metric),
                String,
                Float64,
                Float64,
                String,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(
                    WannierNLQGWannierizationExt.OperatorExport._qualification_hermiticity_metric,
                ),
                String,
                WannierNLQG.Core.RealSpaceOperator{4},
                Float64,
                String,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.grow_to!),
                Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGWannierizationExt.OperatorExport.var"#317#318"{
                        WannierNLQG.Core.RealSpaceOperator{4},
                    },
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(WannierNLQGWannierizationExt.OperatorExport._qualification_kstar_residual),
                WannierNLQG.Core.RealSpaceOperator{3},
                Array{Int64, 1},
                WannierNLQG.SymmetryFoundation.BandRepresentation,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :authoritative_hamiltonian,
                        :authoritative_hamiltonian_sha256,
                        :energy_shift_qualification,
                        :maximum_energy_shift_audit_reference_ev,
                        :rms_energy_shift_audit_reference_ev,
                        :target_energy_shift_audit_status,
                        :symmetrized_parent_energy_shift_audit_status,
                        :residual_gate_phase,
                        :raw_preflight_diagnostic_status,
                        :native_difference_qualification,
                        :native_difference_audit_status,
                        :qualification_scope,
                        :target_anchor,
                        :target_complement_completion,
                        :target_complement_max_element_ev,
                        :auxiliary_parent_qualification,
                        :symmetrized_target_subspace_status,
                        :auxiliary_parent_audit_status,
                        :target_scope_production_eligible,
                        :target_leakage_semantics,
                        :target_leakage_formula_sha256,
                        :target_leakage_threshold,
                        :scoped_production_eligible,
                        :global_production_eligible,
                    ),
                    Tuple{
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        Bool,
                        String,
                        String,
                        Float64,
                        Bool,
                        Bool,
                    },
                },
                Type{WannierNLQG.Wannierization.TBSymmetryQualification},
                String,
                String,
                Array{WannierNLQG.Wannierization.TBSymmetryMetric, 1},
            },
        )
        false
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.unique), Array{String, 1}},
        )
        false
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.grow_to!),
                Base.Dict{String, Nothing},
                Tuple{
                    Pair{String, Nothing},
                    Pair{String, Float64},
                    Vararg{Pair{String, String}, 4},
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.grow_to!),
                Base.Dict{String, Union{Nothing, Float64}},
                Tuple{
                    Pair{String, Nothing},
                    Pair{String, Float64},
                    Vararg{Pair{String, String}, 4},
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.grow_to!),
                Base.Dict{String, Any},
                Tuple{
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Base.Dict{String, Any}},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Bool},
                    Pair{String, String},
                    Pair{String, String},
                    Pair{String, Float64},
                    Pair{String, Bool},
                    Pair{String, Bool},
                },
                Int64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.getproperty),
                WannierNLQG.Wannierization.TBSymmetryQualification,
                Symbol,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{
                    (:input_summary, :tb_symmetry_qualification),
                    Tuple{
                        Base.Dict{String, String},
                        WannierNLQG.Wannierization.TBSymmetryQualification,
                    },
                },
                typeof(
                    WannierNLQGWannierizationExt.WannierizationInternalSupport.updated_wannierization_result,
                ),
                WannierNLQG.Wannierization.WannierizationResult,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{38, 0}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{89, 0}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{66, 0}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{63, 0}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{56, 0}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{54, 0}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{75, 0}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{74, 0}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{92, 0}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{239, 0}},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(
                    WannierNLQGWannierizationExt.WannierizationInternalSupport.required_attribute,
                ),
                HDF5.Group,
                String,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(
                    WannierNLQGWannierizationExt.WannierizationInternalSupport.validate_persisted_authority_key,
                ),
                String,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Core.kwcall),
                NamedTuple{
                    (
                        :schema_version,
                        :payload_sha256,
                        :authoritative_hamiltonian,
                        :authoritative_hamiltonian_sha256,
                        :energy_shift_qualification,
                        :maximum_energy_shift_audit_reference_ev,
                        :rms_energy_shift_audit_reference_ev,
                        :target_energy_shift_audit_status,
                        :symmetrized_parent_energy_shift_audit_status,
                        :residual_gate_phase,
                        :raw_preflight_diagnostic_status,
                        :native_difference_qualification,
                        :native_difference_audit_status,
                        :qualification_scope,
                        :target_anchor,
                        :target_complement_completion,
                        :target_complement_max_element_ev,
                        :auxiliary_parent_qualification,
                        :symmetrized_target_subspace_status,
                        :auxiliary_parent_audit_status,
                        :target_scope_production_eligible,
                        :target_leakage_semantics,
                        :target_leakage_formula_sha256,
                        :target_leakage_threshold,
                        :scoped_production_eligible,
                        :global_production_eligible,
                    ),
                    Tuple{
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        Bool,
                        String,
                        String,
                        Float64,
                        Bool,
                        Bool,
                    },
                },
                Type{WannierNLQG.Wannierization.TBSymmetryQualification},
                String,
                String,
                Array{WannierNLQG.Wannierization.TBSymmetryMetric, 1},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{NamedTuple{(:missing_reason,), T} where T <: Tuple},
                Tuple{String},
            },
        )
        false
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.Order.lt),
                Base.Order.ForwardOrdering,
                Tuple{Int64, String},
                Tuple{Int64, String},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Base.Iterators.Filter{F, I} where {I} where F},
                WannierNLQGWannierizationExt.OperatorExport.var"#225#230",
                Tuple{Int64},
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                Type{Base.Generator{I, F} where {F} where I},
                typeof(Base.identity),
                Base.Iterators.Filter{
                    WannierNLQGWannierizationExt.OperatorExport.var"#225#230",
                    Tuple{Int64},
                },
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.grow_to!),
                Array{Int64, 1},
                Base.Iterators.Flatten{
                    Base.Generator{
                        Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                        WannierNLQGWannierizationExt.OperatorExport.var"#226#229",
                    },
                },
                Tuple{
                    Int64,
                    Base.Generator{
                        Base.Iterators.Filter{
                            WannierNLQGWannierizationExt.OperatorExport.var"#225#230",
                            Tuple{Int64},
                        },
                        typeof(Base.identity),
                    },
                    Int64,
                },
            },
        )
        _record_precompile(
            Tuple{typeof(_first_solve_compile_call), typeof(Base.print), Base.IOStream, Symbol},
        )
        false
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(Base.print),
                Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
                UInt64,
            },
        )
        _record_precompile(
            Tuple{
                typeof(_first_solve_compile_call),
                typeof(JSON3.defaultminimum),
                NamedTuple{
                    (:record, :severity, :code, :message, :context),
                    Tuple{Int64, String, String, String, Base.Dict{String, String}},
                },
            },
        )
    end
end
