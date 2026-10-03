# Generated from actual first run(cfg), effective nonzero Pauli input, MPI root.
# Julia 1.11.2; parent source: f96005337864e6e95656ead666fe9210cab0d0c0b7abd7bd7d3b3ce36feccd18
# Trace SHA256: de6061d42c9213b334adc7e828940240023d27ae160dd5d73ccd874ef71964a1
# Compilation only; no I/O, MPI initialization, task execution, or global runtime state.
@compile_workload begin
    if FIRST_USE_WORKLOAD_ENABLED
        precompile(
            Tuple{
                typeof(Base.merge),
                NamedTuple{
                    (
                        :model_file,
                        :real_space_operator_bundle_file,
                        :seedname,
                        :case_root,
                        :wannier_center_convention,
                        :real_space_replica_policy,
                        :wsvec_file,
                        :mp_grid,
                        :wigner_seitz_tolerance,
                        :wigner_seitz_search_size,
                        :spin_enabled,
                        :spin_file,
                        :checkpoint_file,
                        :spin_file_formatted,
                        :k_mesh,
                        :spatial_dimension,
                        :kslice_origin,
                        :kslice_vector_1,
                        :kslice_vector_2,
                        :fourier_backend,
                        :NKdiv,
                        :NKFFT,
                        :response_symmetry_file,
                        :response_symmetry_policy,
                        :response_symmetry_kmesh_mode,
                        :response_symmetry_report_enabled,
                    ),
                    Tuple{
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        Tuple{Int64, Int64, Int64},
                        Float64,
                        Int64,
                        Bool,
                        String,
                        String,
                        Bool,
                        Tuple{Int64, Int64},
                        Int64,
                        Tuple{Float64, Float64, Float64},
                        Tuple{Float64, Float64, Float64},
                        Tuple{Float64, Float64, Float64},
                        String,
                        Nothing,
                        Nothing,
                        Nothing,
                        String,
                        String,
                        Bool,
                    },
                },
                NamedTuple{
                    (
                        :output_root,
                        :system_name,
                        :response_output_digits,
                        :progress_enabled,
                        :progress_percent_interval,
                        :progress_verbosity,
                    ),
                    Tuple{String, String, Int64, Bool, Int64, String},
                },
                NamedTuple{
                    (:tensor_indices, :band_selection, :include_occupied_sum),
                    Tuple{Tuple{Int64, Int64}, Tuple{Array{Int64, 1}, Array{Int64, 1}}, Bool},
                },
                Vararg{(NamedTuple{names, T} where {T <: Tuple}) where names},
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.merge),
                NamedTuple{
                    (
                        :model_file,
                        :real_space_operator_bundle_file,
                        :seedname,
                        :case_root,
                        :wannier_center_convention,
                        :real_space_replica_policy,
                        :wsvec_file,
                        :mp_grid,
                        :wigner_seitz_tolerance,
                        :wigner_seitz_search_size,
                        :spin_enabled,
                        :spin_file,
                        :checkpoint_file,
                        :spin_file_formatted,
                        :k_mesh,
                        :spatial_dimension,
                        :kslice_origin,
                        :kslice_vector_1,
                        :kslice_vector_2,
                        :fourier_backend,
                        :NKdiv,
                        :NKFFT,
                        :response_symmetry_file,
                        :response_symmetry_policy,
                        :response_symmetry_kmesh_mode,
                        :response_symmetry_report_enabled,
                    ),
                    Tuple{
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        Tuple{Int64, Int64, Int64},
                        Float64,
                        Int64,
                        Bool,
                        String,
                        String,
                        Bool,
                        Tuple{Int64, Int64},
                        Int64,
                        Tuple{Float64, Float64, Float64},
                        Tuple{Float64, Float64, Float64},
                        Tuple{Float64, Float64, Float64},
                        String,
                        Nothing,
                        Nothing,
                        Nothing,
                        String,
                        String,
                        Bool,
                    },
                },
                NamedTuple{
                    (
                        :output_root,
                        :system_name,
                        :response_output_digits,
                        :progress_enabled,
                        :progress_percent_interval,
                        :progress_verbosity,
                    ),
                    Tuple{String, String, Int64, Bool, Int64, String},
                },
                NamedTuple{
                    (:tensor_indices, :band_selection, :include_occupied_sum),
                    Tuple{Tuple{Int64, Int64}, Tuple{Array{Int64, 1}, Array{Int64, 1}}, Bool},
                },
                Vararg{(NamedTuple{names, T} where {T <: Tuple}) where names},
            },
        )
        precompile(
            Tuple{
                typeof(Base.merge),
                NamedTuple{
                    (
                        :model_file,
                        :real_space_operator_bundle_file,
                        :seedname,
                        :case_root,
                        :wannier_center_convention,
                        :real_space_replica_policy,
                        :wsvec_file,
                        :mp_grid,
                        :wigner_seitz_tolerance,
                        :wigner_seitz_search_size,
                        :spin_enabled,
                        :spin_file,
                        :checkpoint_file,
                        :spin_file_formatted,
                        :k_mesh,
                        :spatial_dimension,
                        :kslice_origin,
                        :kslice_vector_1,
                        :kslice_vector_2,
                        :fourier_backend,
                        :NKdiv,
                        :NKFFT,
                        :response_symmetry_file,
                        :response_symmetry_policy,
                        :response_symmetry_kmesh_mode,
                        :response_symmetry_report_enabled,
                        :output_root,
                        :system_name,
                        :response_output_digits,
                        :progress_enabled,
                        :progress_percent_interval,
                        :progress_verbosity,
                    ),
                    Tuple{
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        Tuple{Int64, Int64, Int64},
                        Float64,
                        Int64,
                        Bool,
                        String,
                        String,
                        Bool,
                        Tuple{Int64, Int64},
                        Int64,
                        Tuple{Float64, Float64, Float64},
                        Tuple{Float64, Float64, Float64},
                        Tuple{Float64, Float64, Float64},
                        String,
                        Nothing,
                        Nothing,
                        Nothing,
                        String,
                        String,
                        Bool,
                        String,
                        String,
                        Int64,
                        Bool,
                        Int64,
                        String,
                    },
                },
                NamedTuple{
                    (:tensor_indices, :band_selection, :include_occupied_sum),
                    Tuple{Tuple{Int64, Int64}, Tuple{Array{Int64, 1}, Array{Int64, 1}}, Bool},
                },
                NamedTuple{
                    (:photon_energies, :fermi_energy, :temperature, :photon_momentum),
                    Tuple{Array{Float64, 1}, Float64, Float64, Tuple{Float64, Float64, Float64}},
                },
                Vararg{(NamedTuple{names, T} where {T <: Tuple}) where names},
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.merge),
                NamedTuple{
                    (
                        :model_file,
                        :real_space_operator_bundle_file,
                        :seedname,
                        :case_root,
                        :wannier_center_convention,
                        :real_space_replica_policy,
                        :wsvec_file,
                        :mp_grid,
                        :wigner_seitz_tolerance,
                        :wigner_seitz_search_size,
                        :spin_enabled,
                        :spin_file,
                        :checkpoint_file,
                        :spin_file_formatted,
                        :k_mesh,
                        :spatial_dimension,
                        :kslice_origin,
                        :kslice_vector_1,
                        :kslice_vector_2,
                        :fourier_backend,
                        :NKdiv,
                        :NKFFT,
                        :response_symmetry_file,
                        :response_symmetry_policy,
                        :response_symmetry_kmesh_mode,
                        :response_symmetry_report_enabled,
                        :output_root,
                        :system_name,
                        :response_output_digits,
                        :progress_enabled,
                        :progress_percent_interval,
                        :progress_verbosity,
                    ),
                    Tuple{
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        Tuple{Int64, Int64, Int64},
                        Float64,
                        Int64,
                        Bool,
                        String,
                        String,
                        Bool,
                        Tuple{Int64, Int64},
                        Int64,
                        Tuple{Float64, Float64, Float64},
                        Tuple{Float64, Float64, Float64},
                        Tuple{Float64, Float64, Float64},
                        String,
                        Nothing,
                        Nothing,
                        Nothing,
                        String,
                        String,
                        Bool,
                        String,
                        String,
                        Int64,
                        Bool,
                        Int64,
                        String,
                    },
                },
                NamedTuple{
                    (:tensor_indices, :band_selection, :include_occupied_sum),
                    Tuple{Tuple{Int64, Int64}, Tuple{Array{Int64, 1}, Array{Int64, 1}}, Bool},
                },
                NamedTuple{
                    (:photon_energies, :fermi_energy, :temperature, :photon_momentum),
                    Tuple{Array{Float64, 1}, Float64, Float64, Tuple{Float64, Float64, Float64}},
                },
                Vararg{(NamedTuple{names, T} where {T <: Tuple}) where names},
            },
        )
        precompile(
            Tuple{
                typeof(Base.merge),
                NamedTuple{
                    (
                        :model_file,
                        :real_space_operator_bundle_file,
                        :seedname,
                        :case_root,
                        :wannier_center_convention,
                        :real_space_replica_policy,
                        :wsvec_file,
                        :mp_grid,
                        :wigner_seitz_tolerance,
                        :wigner_seitz_search_size,
                        :spin_enabled,
                        :spin_file,
                        :checkpoint_file,
                        :spin_file_formatted,
                        :k_mesh,
                        :spatial_dimension,
                        :kslice_origin,
                        :kslice_vector_1,
                        :kslice_vector_2,
                        :fourier_backend,
                        :NKdiv,
                        :NKFFT,
                        :response_symmetry_file,
                        :response_symmetry_policy,
                        :response_symmetry_kmesh_mode,
                        :response_symmetry_report_enabled,
                        :output_root,
                        :system_name,
                        :response_output_digits,
                        :progress_enabled,
                        :progress_percent_interval,
                        :progress_verbosity,
                        :tensor_indices,
                        :band_selection,
                        :include_occupied_sum,
                    ),
                    Tuple{
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        Tuple{Int64, Int64, Int64},
                        Float64,
                        Int64,
                        Bool,
                        String,
                        String,
                        Bool,
                        Tuple{Int64, Int64},
                        Int64,
                        Tuple{Float64, Float64, Float64},
                        Tuple{Float64, Float64, Float64},
                        Tuple{Float64, Float64, Float64},
                        String,
                        Nothing,
                        Nothing,
                        Nothing,
                        String,
                        String,
                        Bool,
                        String,
                        String,
                        Int64,
                        Bool,
                        Int64,
                        String,
                        Tuple{Int64, Int64},
                        Tuple{Array{Int64, 1}, Array{Int64, 1}},
                        Bool,
                    },
                },
                NamedTuple{
                    (:photon_energies, :fermi_energy, :temperature, :photon_momentum),
                    Tuple{Array{Float64, 1}, Float64, Float64, Tuple{Float64, Float64, Float64}},
                },
                NamedTuple{
                    (
                        :denominator_regularization,
                        :degeneracy_threshold,
                        :finite_difference_step,
                        :band_window_size,
                    ),
                    Tuple{Float64, Float64, Float64, Int64},
                },
                Vararg{(NamedTuple{names, T} where {T <: Tuple}) where names},
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.merge),
                NamedTuple{
                    (
                        :model_file,
                        :real_space_operator_bundle_file,
                        :seedname,
                        :case_root,
                        :wannier_center_convention,
                        :real_space_replica_policy,
                        :wsvec_file,
                        :mp_grid,
                        :wigner_seitz_tolerance,
                        :wigner_seitz_search_size,
                        :spin_enabled,
                        :spin_file,
                        :checkpoint_file,
                        :spin_file_formatted,
                        :k_mesh,
                        :spatial_dimension,
                        :kslice_origin,
                        :kslice_vector_1,
                        :kslice_vector_2,
                        :fourier_backend,
                        :NKdiv,
                        :NKFFT,
                        :response_symmetry_file,
                        :response_symmetry_policy,
                        :response_symmetry_kmesh_mode,
                        :response_symmetry_report_enabled,
                        :output_root,
                        :system_name,
                        :response_output_digits,
                        :progress_enabled,
                        :progress_percent_interval,
                        :progress_verbosity,
                        :tensor_indices,
                        :band_selection,
                        :include_occupied_sum,
                    ),
                    Tuple{
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        Tuple{Int64, Int64, Int64},
                        Float64,
                        Int64,
                        Bool,
                        String,
                        String,
                        Bool,
                        Tuple{Int64, Int64},
                        Int64,
                        Tuple{Float64, Float64, Float64},
                        Tuple{Float64, Float64, Float64},
                        Tuple{Float64, Float64, Float64},
                        String,
                        Nothing,
                        Nothing,
                        Nothing,
                        String,
                        String,
                        Bool,
                        String,
                        String,
                        Int64,
                        Bool,
                        Int64,
                        String,
                        Tuple{Int64, Int64},
                        Tuple{Array{Int64, 1}, Array{Int64, 1}},
                        Bool,
                    },
                },
                NamedTuple{
                    (:photon_energies, :fermi_energy, :temperature, :photon_momentum),
                    Tuple{Array{Float64, 1}, Float64, Float64, Tuple{Float64, Float64, Float64}},
                },
                NamedTuple{
                    (
                        :denominator_regularization,
                        :degeneracy_threshold,
                        :finite_difference_step,
                        :band_window_size,
                    ),
                    Tuple{Float64, Float64, Float64, Int64},
                },
                Vararg{(NamedTuple{names, T} where {T <: Tuple}) where names},
            },
        )
        precompile(
            Tuple{
                typeof(Base.merge),
                NamedTuple{
                    (
                        :model_file,
                        :real_space_operator_bundle_file,
                        :seedname,
                        :case_root,
                        :wannier_center_convention,
                        :real_space_replica_policy,
                        :wsvec_file,
                        :mp_grid,
                        :wigner_seitz_tolerance,
                        :wigner_seitz_search_size,
                        :spin_enabled,
                        :spin_file,
                        :checkpoint_file,
                        :spin_file_formatted,
                        :k_mesh,
                        :spatial_dimension,
                        :kslice_origin,
                        :kslice_vector_1,
                        :kslice_vector_2,
                        :fourier_backend,
                        :NKdiv,
                        :NKFFT,
                        :response_symmetry_file,
                        :response_symmetry_policy,
                        :response_symmetry_kmesh_mode,
                        :response_symmetry_report_enabled,
                        :output_root,
                        :system_name,
                        :response_output_digits,
                        :progress_enabled,
                        :progress_percent_interval,
                        :progress_verbosity,
                        :tensor_indices,
                        :band_selection,
                        :include_occupied_sum,
                        :photon_energies,
                        :fermi_energy,
                        :temperature,
                        :photon_momentum,
                    ),
                    Tuple{
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        Tuple{Int64, Int64, Int64},
                        Float64,
                        Int64,
                        Bool,
                        String,
                        String,
                        Bool,
                        Tuple{Int64, Int64},
                        Int64,
                        Tuple{Float64, Float64, Float64},
                        Tuple{Float64, Float64, Float64},
                        Tuple{Float64, Float64, Float64},
                        String,
                        Nothing,
                        Nothing,
                        Nothing,
                        String,
                        String,
                        Bool,
                        String,
                        String,
                        Int64,
                        Bool,
                        Int64,
                        String,
                        Tuple{Int64, Int64},
                        Tuple{Array{Int64, 1}, Array{Int64, 1}},
                        Bool,
                        Array{Float64, 1},
                        Float64,
                        Float64,
                        Tuple{Float64, Float64, Float64},
                    },
                },
                NamedTuple{
                    (
                        :denominator_regularization,
                        :degeneracy_threshold,
                        :finite_difference_step,
                        :band_window_size,
                    ),
                    Tuple{Float64, Float64, Float64, Int64},
                },
                NamedTuple{
                    (:tasks, :output_root),
                    Tuple{Array{Tuple{String, String, String}, 1}, String},
                },
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.merge),
                NamedTuple{
                    (
                        :model_file,
                        :real_space_operator_bundle_file,
                        :seedname,
                        :case_root,
                        :wannier_center_convention,
                        :real_space_replica_policy,
                        :wsvec_file,
                        :mp_grid,
                        :wigner_seitz_tolerance,
                        :wigner_seitz_search_size,
                        :spin_enabled,
                        :spin_file,
                        :checkpoint_file,
                        :spin_file_formatted,
                        :k_mesh,
                        :spatial_dimension,
                        :kslice_origin,
                        :kslice_vector_1,
                        :kslice_vector_2,
                        :fourier_backend,
                        :NKdiv,
                        :NKFFT,
                        :response_symmetry_file,
                        :response_symmetry_policy,
                        :response_symmetry_kmesh_mode,
                        :response_symmetry_report_enabled,
                        :output_root,
                        :system_name,
                        :response_output_digits,
                        :progress_enabled,
                        :progress_percent_interval,
                        :progress_verbosity,
                        :tensor_indices,
                        :band_selection,
                        :include_occupied_sum,
                        :photon_energies,
                        :fermi_energy,
                        :temperature,
                        :photon_momentum,
                    ),
                    Tuple{
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        Tuple{Int64, Int64, Int64},
                        Float64,
                        Int64,
                        Bool,
                        String,
                        String,
                        Bool,
                        Tuple{Int64, Int64},
                        Int64,
                        Tuple{Float64, Float64, Float64},
                        Tuple{Float64, Float64, Float64},
                        Tuple{Float64, Float64, Float64},
                        String,
                        Nothing,
                        Nothing,
                        Nothing,
                        String,
                        String,
                        Bool,
                        String,
                        String,
                        Int64,
                        Bool,
                        Int64,
                        String,
                        Tuple{Int64, Int64},
                        Tuple{Array{Int64, 1}, Array{Int64, 1}},
                        Bool,
                        Array{Float64, 1},
                        Float64,
                        Float64,
                        Tuple{Float64, Float64, Float64},
                    },
                },
                NamedTuple{
                    (
                        :denominator_regularization,
                        :degeneracy_threshold,
                        :finite_difference_step,
                        :band_window_size,
                    ),
                    Tuple{Float64, Float64, Float64, Int64},
                },
                NamedTuple{
                    (:tasks, :output_root),
                    Tuple{Array{Tuple{String, String, String}, 1}, String},
                },
            },
        )

        precompile(
            Tuple{
                typeof(Serialization.serialize),
                Serialization.Serializer{
                    Base.GenericIOBuffer{
                        Base.GenericMemory{
                            :not_atomic,
                            UInt8,
                            Base.Core.AddrSpace{Base.Core}(0x00),
                        },
                    },
                },
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Serialization.serialize),
                Serialization.Serializer{
                    Base.GenericIOBuffer{
                        Base.GenericMemory{
                            :not_atomic,
                            UInt8,
                            Base.Core.AddrSpace{Base.Core}(0x00),
                        },
                    },
                },
                Array{WannierNLQG.Core.RealSpaceOperatorKind, 1},
            },
        )
        precompile(
            Tuple{
                typeof(Serialization.serialize),
                Serialization.Serializer{
                    Base.GenericIOBuffer{
                        Base.GenericMemory{
                            :not_atomic,
                            UInt8,
                            Base.Core.AddrSpace{Base.Core}(0x00),
                        },
                    },
                },
                Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1},
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Serialization.serialize),
                Serialization.Serializer{
                    Base.GenericIOBuffer{
                        Base.GenericMemory{
                            :not_atomic,
                            UInt8,
                            Base.Core.AddrSpace{Base.Core}(0x00),
                        },
                    },
                },
                Array{WannierNLQG.IO.OperatorBundleIndexEntry, 1},
            },
        )
        precompile(
            Tuple{
                typeof(Serialization.serialize),
                Serialization.Serializer{
                    Base.GenericIOBuffer{
                        Base.GenericMemory{
                            :not_atomic,
                            UInt8,
                            Base.Core.AddrSpace{Base.Core}(0x00),
                        },
                    },
                },
                UInt64,
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Serialization.serialize),
                Serialization.Serializer{
                    Base.GenericIOBuffer{
                        Base.GenericMemory{
                            :not_atomic,
                            UInt8,
                            Base.Core.AddrSpace{Base.Core}(0x00),
                        },
                    },
                },
                UInt64,
            },
        )
        precompile(
            Tuple{
                typeof(Serialization.serialize),
                Serialization.Serializer{
                    Base.GenericIOBuffer{
                        Base.GenericMemory{
                            :not_atomic,
                            UInt8,
                            Base.Core.AddrSpace{Base.Core}(0x00),
                        },
                    },
                },
                Base.Dict{String, Any},
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Serialization.serialize),
                Serialization.Serializer{
                    Base.GenericIOBuffer{
                        Base.GenericMemory{
                            :not_atomic,
                            UInt8,
                            Base.Core.AddrSpace{Base.Core}(0x00),
                        },
                    },
                },
                Base.Dict{String, Any},
            },
        )
        @assert !MPI.Initialized()
    end
end

# Exact remaining MPI-root iterator specialization from the successful public
# nonzero Zeeman quantum-metric diagnostic on source063. Compile only: no
# target call, file write, communicator construction, or MPI initialization.
@compile_workload begin
    if FIRST_USE_WORKLOAD_ENABLED
        precompile(
            Tuple{
                typeof(Base.iterate),
                Base.Iterators.Flatten{
                    Base.Generator{
                        Array{
                            WannierNLQG.Runtime.PreparedResponseTask{
                                E,
                                F,
                                C,
                            } where {C} where {F} where E,
                            1,
                        },
                        WannierNLQG.Runtime.var"#561#567",
                    },
                },
                Tuple{
                    Int64,
                    Base.Generator{
                        Array{Tuple{Int64, Int64, Int64}, 1},
                        WannierNLQG.Runtime.var"#560#568"{
                            WannierNLQG.Runtime.PreparedResponseTask{
                                WannierNLQG.Runtime.var"#execute_point!#752"{
                                    Bool,
                                    WannierNLQG.Runtime.EffectiveTaskConfig,
                                    Array{Array{Float64, 1}, 1},
                                    Float64,
                                    Base.Threads.Atomic{Int64},
                                    Base.Threads.Atomic{Int64},
                                    Base.Threads.Atomic{Int64},
                                    Base.Threads.Atomic{Int64},
                                    Int64,
                                    Array{Int64, 1},
                                    Nothing,
                                    Array{Float64, 1},
                                    Array{Float64, 2},
                                    Array{Float64, 1},
                                    Array{Float64, 1},
                                    Array{Float64, 2},
                                    Array{Float64, 2},
                                    Array{Float64, 2},
                                    Array{Float64, 2},
                                    Array{
                                        WannierNLQG.Responses.PhotonDragInjectionCurrentConventionalWorkspace{
                                            W,
                                            D,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.WilsonLoopResponseWorkspace{
                                            W,
                                            D,
                                            F,
                                        } where {
                                            F <:
                                            WannierNLQG.MatrixElements.ConventionFrameConnector,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.GeometricLoopResponseWorkspace{
                                            W,
                                            D,
                                            F,
                                        } where {
                                            F <:
                                            WannierNLQG.MatrixElements.ConventionFrameConnector,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.GeometricLoopResponseWorkspace{
                                            W,
                                            D,
                                            F,
                                        } where {
                                            F <:
                                            WannierNLQG.MatrixElements.ConventionFrameConnector,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.GeometricLoopResponseWorkspace{
                                            W,
                                            D,
                                            F,
                                        } where {
                                            F <:
                                            WannierNLQG.MatrixElements.ConventionFrameConnector,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.GeometricLoopResponseWorkspace{
                                            W,
                                            D,
                                            F,
                                        } where {
                                            F <:
                                            WannierNLQG.MatrixElements.ConventionFrameConnector,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.ProjectorResponseWorkspace{
                                            W,
                                            D,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.ConventionalQuantumGeometryWorkspace{
                                            WannierNLQG.MatrixElements.MatrixElementWorkspace{
                                                WannierNLQG.MatrixElements.KPointMatrixData{
                                                    WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                                        Array{Float64, 2},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Array{Base.Complex{Float64}, 3},
                                                    },
                                                    WannierNLQG.MatrixElements.PositionMatrixData{
                                                        Array{Base.Complex{Float64}, 3},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Nothing,
                                                        Array{Float64, 2},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Nothing,
                                                        Nothing,
                                                        Array{Base.Complex{Float64}, 3},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                    },
                                                    WannierNLQG.MatrixElements.SpinMatrixData,
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.MatrixElementScratch{
                                                    WannierNLQG.MatrixElements.HamiltonianMatrixScratch{
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Array{Base.Complex{Float64}, 4},
                                                        Nothing,
                                                    },
                                                    WannierNLQG.MatrixElements.PositionMatrixScratch{
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Nothing,
                                                        Array{Base.Complex{Float64}, 2},
                                                    },
                                                    WannierNLQG.MatrixElements.SpinMatrixScratch,
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.MatrixElementSources{
                                                    WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                        WannierNLQG.IO.PackedCartesianOperator{
                                                            1,
                                                            4,
                                                            Array{Base.Complex{Float64}, 3},
                                                        },
                                                    },
                                                    Nothing,
                                                    Nothing,
                                                },
                                            },
                                            WannierNLQG.MatrixElements.KPointMatrixData{
                                                WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                                    Array{Float64, 2},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                                WannierNLQG.MatrixElements.PositionMatrixData{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Array{Float64, 2},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.SpinMatrixData,
                                                Nothing,
                                            },
                                            WannierNLQG.MatrixElements.KPointBatchWorkspace{
                                                WannierNLQG.MatrixElements.MatrixElementWorkspace{
                                                    WannierNLQG.MatrixElements.KPointMatrixData{
                                                        WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                                            Array{Float64, 2},
                                                            Array{Base.Complex{Float64}, 3},
                                                            Nothing,
                                                            Array{Base.Complex{Float64}, 3},
                                                        },
                                                        WannierNLQG.MatrixElements.PositionMatrixData{
                                                            Array{Base.Complex{Float64}, 3},
                                                            Array{Base.Complex{Float64}, 3},
                                                            Nothing,
                                                            Nothing,
                                                            Array{Float64, 2},
                                                            Array{Base.Complex{Float64}, 3},
                                                            Array{Base.Complex{Float64}, 3},
                                                            Nothing,
                                                            Nothing,
                                                            Nothing,
                                                            Array{Base.Complex{Float64}, 3},
                                                            Array{Base.Complex{Float64}, 3},
                                                            Nothing,
                                                        },
                                                        WannierNLQG.MatrixElements.SpinMatrixData,
                                                        Nothing,
                                                    },
                                                    WannierNLQG.MatrixElements.MatrixElementScratch{
                                                        WannierNLQG.MatrixElements.HamiltonianMatrixScratch{
                                                            Array{Base.Complex{Float64}, 3},
                                                            Nothing,
                                                            Array{Base.Complex{Float64}, 4},
                                                            Nothing,
                                                        },
                                                        WannierNLQG.MatrixElements.PositionMatrixScratch{
                                                            Array{Base.Complex{Float64}, 3},
                                                            Nothing,
                                                            Nothing,
                                                            Array{Base.Complex{Float64}, 2},
                                                        },
                                                        WannierNLQG.MatrixElements.SpinMatrixScratch,
                                                        Nothing,
                                                    },
                                                    WannierNLQG.MatrixElements.MatrixElementSources{
                                                        WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                            WannierNLQG.IO.PackedCartesianOperator{
                                                                1,
                                                                4,
                                                                Array{Base.Complex{Float64}, 3},
                                                            },
                                                        },
                                                        Nothing,
                                                        Nothing,
                                                    },
                                                },
                                                WannierNLQG.MatrixElements.KPointMatrixData{
                                                    WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                                        Array{Float64, 2},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Array{Base.Complex{Float64}, 3},
                                                    },
                                                    WannierNLQG.MatrixElements.PositionMatrixData{
                                                        Array{Base.Complex{Float64}, 3},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Nothing,
                                                        Array{Float64, 2},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Nothing,
                                                        Nothing,
                                                        Array{Base.Complex{Float64}, 3},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                    },
                                                    WannierNLQG.MatrixElements.SpinMatrixData,
                                                    Nothing,
                                                },
                                            },
                                        },
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.ShiftSpinCurrentConventionalWorkspace{
                                            W,
                                            D,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{Array{Base.Complex{Float64}, 6}, 1},
                                    Array{Array{Base.Complex{Float64}, 5}, 1},
                                    Array{
                                        WannierNLQG.Responses.ShiftCurrentConventionalWorkspace{
                                            W,
                                            D,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Runtime.PhotonDragTransitionScreenWorkspace{
                                            W,
                                            D,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Runtime.TransitionScreenWorkspace{
                                            W,
                                            D,
                                        } where {D} where W,
                                        1,
                                    },
                                    WannierNLQG.Core.TightBindingModel{
                                        Array{Base.Complex{Float64}, 3},
                                        WannierNLQG.IO.PackedCartesianOperator{
                                            1,
                                            4,
                                            Array{Base.Complex{Float64}, 3},
                                        },
                                    },
                                    Int64,
                                    Int64,
                                    Tuple{Array{Int64, 1}, Array{Int64, 1}, Array{Int64, 1}},
                                    Tuple{Array{Int64, 1}, Array{Int64, 1}},
                                    Tuple{Array{Int64, 1}, Array{Int64, 1}},
                                    Tuple{Array{Int64, 1}, Array{Int64, 1}},
                                    Base.BitArray{1},
                                    Tuple{Array{Int64, 1}, Array{Int64, 1}},
                                    Int64,
                                    Int64,
                                    Int64,
                                    Nothing,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Nothing,
                                    Nothing,
                                    Nothing,
                                    Nothing,
                                    Nothing,
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    WannierNLQG.Runtime.KSliceTaskAccumulator,
                                    Nothing,
                                    Nothing,
                                    Nothing,
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
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
                                    Nothing,
                                    Nothing,
                                    Array{
                                        WannierNLQG.MatrixElements.MatrixElementWorkspace{
                                            WannierNLQG.MatrixElements.KPointMatrixData{
                                                WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                                    Array{Float64, 2},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                                WannierNLQG.MatrixElements.PositionMatrixData{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Array{Float64, 2},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.SpinMatrixData,
                                                Nothing,
                                            },
                                            WannierNLQG.MatrixElements.MatrixElementScratch{
                                                WannierNLQG.MatrixElements.HamiltonianMatrixScratch{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 4},
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.PositionMatrixScratch{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 2},
                                                },
                                                WannierNLQG.MatrixElements.SpinMatrixScratch,
                                                Nothing,
                                            },
                                            WannierNLQG.MatrixElements.MatrixElementSources{
                                                WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                    WannierNLQG.IO.PackedCartesianOperator{
                                                        1,
                                                        4,
                                                        Array{Base.Complex{Float64}, 3},
                                                    },
                                                },
                                                Nothing,
                                                Nothing,
                                            },
                                        },
                                        1,
                                    },
                                    Int64,
                                    WannierNLQG.Core.KSliceGrid2D,
                                    Int64,
                                    Int64,
                                    Float64,
                                    WannierNLQG.Core.TightBindingModel{
                                        Array{Base.Complex{Float64}, 3},
                                        WannierNLQG.IO.PackedCartesianOperator{
                                            1,
                                            4,
                                            Array{Base.Complex{Float64}, 3},
                                        },
                                    },
                                    Int64,
                                    Base.Dict{String, WannierNLQG.Runtime.BundleFamilyCounter},
                                    WannierNLQG.Runtime.NormalizedRunControls,
                                    Float64,
                                    Int64,
                                    Base.ReentrantLock,
                                },
                                WannierNLQG.Runtime.var"#finish!#753"{
                                    WannierNLQG.Runtime.var"#cleanup!#689"{
                                        NamedTuple{
                                            (
                                                :model,
                                                :spin,
                                                :spin_velocity,
                                                :orbital,
                                                :derivative_overlap,
                                                :manifest,
                                                :read_mode,
                                                :fallback_reason,
                                                :storage_owner,
                                                :replica_summary,
                                            ),
                                            Tuple{
                                                WannierNLQG.Core.TightBindingModel{
                                                    Array{Base.Complex{Float64}, 3},
                                                    WannierNLQG.IO.PackedCartesianOperator{
                                                        1,
                                                        4,
                                                        Array{Base.Complex{Float64}, 3},
                                                    },
                                                },
                                                WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                    WannierNLQG.IO.PackedCartesianOperator{
                                                        1,
                                                        4,
                                                        Array{Base.Complex{Float64}, 3},
                                                    },
                                                },
                                                Nothing,
                                                Nothing,
                                                Nothing,
                                                WannierNLQG.IO.OperatorBundleManifest,
                                                Symbol,
                                                Nothing,
                                                WannierNLQG.Runtime.MPISharedOperatorStorage,
                                                WannierNLQG.Runtime.RuntimeReplicaSummary,
                                            },
                                        },
                                        Base.RefValue{Bool},
                                        Base.RefValue{Any},
                                        Array{
                                            WannierNLQG.MatrixElements.MatrixElementWorkspace{
                                                D,
                                                S,
                                                I,
                                            } where {I} where {S} where D,
                                            1,
                                        },
                                    },
                                    Bool,
                                    WannierNLQG.Runtime.EffectiveTaskConfig,
                                    WannierNLQG.Runtime.RunContext,
                                    Float64,
                                    Base.Threads.Atomic{Int64},
                                    Base.Threads.Atomic{Int64},
                                    Base.Threads.Atomic{Int64},
                                    Int64,
                                    Nothing,
                                    WannierNLQG.Runtime.FourierExecutionPlan,
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Array{
                                        WannierNLQG.MatrixElements.MatrixElementWorkspace{
                                            WannierNLQG.MatrixElements.KPointMatrixData{
                                                WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                                    Array{Float64, 2},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                                WannierNLQG.MatrixElements.PositionMatrixData{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Array{Float64, 2},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.SpinMatrixData,
                                                Nothing,
                                            },
                                            WannierNLQG.MatrixElements.MatrixElementScratch{
                                                WannierNLQG.MatrixElements.HamiltonianMatrixScratch{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 4},
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.PositionMatrixScratch{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 2},
                                                },
                                                WannierNLQG.MatrixElements.SpinMatrixScratch,
                                                Nothing,
                                            },
                                            WannierNLQG.MatrixElements.MatrixElementSources{
                                                WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                    WannierNLQG.IO.PackedCartesianOperator{
                                                        1,
                                                        4,
                                                        Array{Base.Complex{Float64}, 3},
                                                    },
                                                },
                                                Nothing,
                                                Nothing,
                                            },
                                        },
                                        1,
                                    },
                                    Int64,
                                    Int64,
                                    WannierNLQG.Runtime.ResponseQualificationResult,
                                    NamedTuple{
                                        (
                                            :model,
                                            :spin,
                                            :spin_velocity,
                                            :orbital,
                                            :derivative_overlap,
                                            :manifest,
                                            :read_mode,
                                            :fallback_reason,
                                            :storage_owner,
                                            :replica_summary,
                                        ),
                                        Tuple{
                                            WannierNLQG.Core.TightBindingModel{
                                                Array{Base.Complex{Float64}, 3},
                                                WannierNLQG.IO.PackedCartesianOperator{
                                                    1,
                                                    4,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                            },
                                            WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                WannierNLQG.IO.PackedCartesianOperator{
                                                    1,
                                                    4,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                            },
                                            Nothing,
                                            Nothing,
                                            Nothing,
                                            WannierNLQG.IO.OperatorBundleManifest,
                                            Symbol,
                                            Nothing,
                                            WannierNLQG.Runtime.MPISharedOperatorStorage,
                                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                                        },
                                    },
                                    Base.Dict{Symbol, Any},
                                    Nothing,
                                    Int64,
                                    Int64,
                                    Int64,
                                    MPI.Comm,
                                    Base.Dict{String, WannierNLQG.Runtime.BundleFamilyCounter},
                                    Array{String, 1},
                                    Float64,
                                    Base.ReentrantLock,
                                },
                                WannierNLQG.Runtime.var"#cleanup!#689"{
                                    NamedTuple{
                                        (
                                            :model,
                                            :spin,
                                            :spin_velocity,
                                            :orbital,
                                            :derivative_overlap,
                                            :manifest,
                                            :read_mode,
                                            :fallback_reason,
                                            :storage_owner,
                                            :replica_summary,
                                        ),
                                        Tuple{
                                            WannierNLQG.Core.TightBindingModel{
                                                Array{Base.Complex{Float64}, 3},
                                                WannierNLQG.IO.PackedCartesianOperator{
                                                    1,
                                                    4,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                            },
                                            WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                WannierNLQG.IO.PackedCartesianOperator{
                                                    1,
                                                    4,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                            },
                                            Nothing,
                                            Nothing,
                                            Nothing,
                                            WannierNLQG.IO.OperatorBundleManifest,
                                            Symbol,
                                            Nothing,
                                            WannierNLQG.Runtime.MPISharedOperatorStorage,
                                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                                        },
                                    },
                                    Base.RefValue{Bool},
                                    Base.RefValue{Any},
                                    Array{
                                        WannierNLQG.MatrixElements.MatrixElementWorkspace{
                                            D,
                                            S,
                                            I,
                                        } where {I} where {S} where D,
                                        1,
                                    },
                                },
                            },
                        },
                    },
                    Int64,
                },
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.iterate),
                Base.Iterators.Flatten{
                    Base.Generator{
                        Array{
                            WannierNLQG.Runtime.PreparedResponseTask{
                                E,
                                F,
                                C,
                            } where {C} where {F} where E,
                            1,
                        },
                        WannierNLQG.Runtime.var"#561#567",
                    },
                },
                Tuple{
                    Int64,
                    Base.Generator{
                        Array{Tuple{Int64, Int64, Int64}, 1},
                        WannierNLQG.Runtime.var"#560#568"{
                            WannierNLQG.Runtime.PreparedResponseTask{
                                WannierNLQG.Runtime.var"#execute_point!#752"{
                                    Bool,
                                    WannierNLQG.Runtime.EffectiveTaskConfig,
                                    Array{Array{Float64, 1}, 1},
                                    Float64,
                                    Base.Threads.Atomic{Int64},
                                    Base.Threads.Atomic{Int64},
                                    Base.Threads.Atomic{Int64},
                                    Base.Threads.Atomic{Int64},
                                    Int64,
                                    Array{Int64, 1},
                                    Nothing,
                                    Array{Float64, 1},
                                    Array{Float64, 2},
                                    Array{Float64, 1},
                                    Array{Float64, 1},
                                    Array{Float64, 2},
                                    Array{Float64, 2},
                                    Array{Float64, 2},
                                    Array{Float64, 2},
                                    Array{
                                        WannierNLQG.Responses.PhotonDragInjectionCurrentConventionalWorkspace{
                                            W,
                                            D,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.WilsonLoopResponseWorkspace{
                                            W,
                                            D,
                                            F,
                                        } where {
                                            F <:
                                            WannierNLQG.MatrixElements.ConventionFrameConnector,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.GeometricLoopResponseWorkspace{
                                            W,
                                            D,
                                            F,
                                        } where {
                                            F <:
                                            WannierNLQG.MatrixElements.ConventionFrameConnector,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.GeometricLoopResponseWorkspace{
                                            W,
                                            D,
                                            F,
                                        } where {
                                            F <:
                                            WannierNLQG.MatrixElements.ConventionFrameConnector,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.GeometricLoopResponseWorkspace{
                                            W,
                                            D,
                                            F,
                                        } where {
                                            F <:
                                            WannierNLQG.MatrixElements.ConventionFrameConnector,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.GeometricLoopResponseWorkspace{
                                            W,
                                            D,
                                            F,
                                        } where {
                                            F <:
                                            WannierNLQG.MatrixElements.ConventionFrameConnector,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.ProjectorResponseWorkspace{
                                            W,
                                            D,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.ConventionalQuantumGeometryWorkspace{
                                            WannierNLQG.MatrixElements.MatrixElementWorkspace{
                                                WannierNLQG.MatrixElements.KPointMatrixData{
                                                    WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                                        Array{Float64, 2},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Array{Base.Complex{Float64}, 3},
                                                    },
                                                    WannierNLQG.MatrixElements.PositionMatrixData{
                                                        Array{Base.Complex{Float64}, 3},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Nothing,
                                                        Array{Float64, 2},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Nothing,
                                                        Nothing,
                                                        Array{Base.Complex{Float64}, 3},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                    },
                                                    WannierNLQG.MatrixElements.SpinMatrixData,
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.MatrixElementScratch{
                                                    WannierNLQG.MatrixElements.HamiltonianMatrixScratch{
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Array{Base.Complex{Float64}, 4},
                                                        Nothing,
                                                    },
                                                    WannierNLQG.MatrixElements.PositionMatrixScratch{
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Nothing,
                                                        Array{Base.Complex{Float64}, 2},
                                                    },
                                                    WannierNLQG.MatrixElements.SpinMatrixScratch,
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.MatrixElementSources{
                                                    WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                        WannierNLQG.IO.PackedCartesianOperator{
                                                            1,
                                                            4,
                                                            Array{Base.Complex{Float64}, 3},
                                                        },
                                                    },
                                                    Nothing,
                                                    Nothing,
                                                },
                                            },
                                            WannierNLQG.MatrixElements.KPointMatrixData{
                                                WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                                    Array{Float64, 2},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                                WannierNLQG.MatrixElements.PositionMatrixData{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Array{Float64, 2},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.SpinMatrixData,
                                                Nothing,
                                            },
                                            WannierNLQG.MatrixElements.KPointBatchWorkspace{
                                                WannierNLQG.MatrixElements.MatrixElementWorkspace{
                                                    WannierNLQG.MatrixElements.KPointMatrixData{
                                                        WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                                            Array{Float64, 2},
                                                            Array{Base.Complex{Float64}, 3},
                                                            Nothing,
                                                            Array{Base.Complex{Float64}, 3},
                                                        },
                                                        WannierNLQG.MatrixElements.PositionMatrixData{
                                                            Array{Base.Complex{Float64}, 3},
                                                            Array{Base.Complex{Float64}, 3},
                                                            Nothing,
                                                            Nothing,
                                                            Array{Float64, 2},
                                                            Array{Base.Complex{Float64}, 3},
                                                            Array{Base.Complex{Float64}, 3},
                                                            Nothing,
                                                            Nothing,
                                                            Nothing,
                                                            Array{Base.Complex{Float64}, 3},
                                                            Array{Base.Complex{Float64}, 3},
                                                            Nothing,
                                                        },
                                                        WannierNLQG.MatrixElements.SpinMatrixData,
                                                        Nothing,
                                                    },
                                                    WannierNLQG.MatrixElements.MatrixElementScratch{
                                                        WannierNLQG.MatrixElements.HamiltonianMatrixScratch{
                                                            Array{Base.Complex{Float64}, 3},
                                                            Nothing,
                                                            Array{Base.Complex{Float64}, 4},
                                                            Nothing,
                                                        },
                                                        WannierNLQG.MatrixElements.PositionMatrixScratch{
                                                            Array{Base.Complex{Float64}, 3},
                                                            Nothing,
                                                            Nothing,
                                                            Array{Base.Complex{Float64}, 2},
                                                        },
                                                        WannierNLQG.MatrixElements.SpinMatrixScratch,
                                                        Nothing,
                                                    },
                                                    WannierNLQG.MatrixElements.MatrixElementSources{
                                                        WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                            WannierNLQG.IO.PackedCartesianOperator{
                                                                1,
                                                                4,
                                                                Array{Base.Complex{Float64}, 3},
                                                            },
                                                        },
                                                        Nothing,
                                                        Nothing,
                                                    },
                                                },
                                                WannierNLQG.MatrixElements.KPointMatrixData{
                                                    WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                                        Array{Float64, 2},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Array{Base.Complex{Float64}, 3},
                                                    },
                                                    WannierNLQG.MatrixElements.PositionMatrixData{
                                                        Array{Base.Complex{Float64}, 3},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Nothing,
                                                        Array{Float64, 2},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Nothing,
                                                        Nothing,
                                                        Array{Base.Complex{Float64}, 3},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                    },
                                                    WannierNLQG.MatrixElements.SpinMatrixData,
                                                    Nothing,
                                                },
                                            },
                                        },
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.ShiftSpinCurrentConventionalWorkspace{
                                            W,
                                            D,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{Array{Base.Complex{Float64}, 6}, 1},
                                    Array{Array{Base.Complex{Float64}, 5}, 1},
                                    Array{
                                        WannierNLQG.Responses.ShiftCurrentConventionalWorkspace{
                                            W,
                                            D,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Runtime.PhotonDragTransitionScreenWorkspace{
                                            W,
                                            D,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Runtime.TransitionScreenWorkspace{
                                            W,
                                            D,
                                        } where {D} where W,
                                        1,
                                    },
                                    WannierNLQG.Core.TightBindingModel{
                                        Array{Base.Complex{Float64}, 3},
                                        WannierNLQG.IO.PackedCartesianOperator{
                                            1,
                                            4,
                                            Array{Base.Complex{Float64}, 3},
                                        },
                                    },
                                    Int64,
                                    Int64,
                                    Tuple{Array{Int64, 1}, Array{Int64, 1}, Array{Int64, 1}},
                                    Tuple{Array{Int64, 1}, Array{Int64, 1}},
                                    Tuple{Array{Int64, 1}, Array{Int64, 1}},
                                    Tuple{Array{Int64, 1}, Array{Int64, 1}},
                                    Base.BitArray{1},
                                    Tuple{Array{Int64, 1}, Array{Int64, 1}},
                                    Int64,
                                    Int64,
                                    Int64,
                                    Nothing,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Nothing,
                                    Nothing,
                                    Nothing,
                                    Nothing,
                                    Nothing,
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    WannierNLQG.Runtime.KSliceTaskAccumulator,
                                    Nothing,
                                    Nothing,
                                    Nothing,
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
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
                                    Nothing,
                                    Nothing,
                                    Array{
                                        WannierNLQG.MatrixElements.MatrixElementWorkspace{
                                            WannierNLQG.MatrixElements.KPointMatrixData{
                                                WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                                    Array{Float64, 2},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                                WannierNLQG.MatrixElements.PositionMatrixData{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Array{Float64, 2},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.SpinMatrixData,
                                                Nothing,
                                            },
                                            WannierNLQG.MatrixElements.MatrixElementScratch{
                                                WannierNLQG.MatrixElements.HamiltonianMatrixScratch{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 4},
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.PositionMatrixScratch{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 2},
                                                },
                                                WannierNLQG.MatrixElements.SpinMatrixScratch,
                                                Nothing,
                                            },
                                            WannierNLQG.MatrixElements.MatrixElementSources{
                                                WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                    WannierNLQG.IO.PackedCartesianOperator{
                                                        1,
                                                        4,
                                                        Array{Base.Complex{Float64}, 3},
                                                    },
                                                },
                                                Nothing,
                                                Nothing,
                                            },
                                        },
                                        1,
                                    },
                                    Int64,
                                    WannierNLQG.Core.KSliceGrid2D,
                                    Int64,
                                    Int64,
                                    Float64,
                                    WannierNLQG.Core.TightBindingModel{
                                        Array{Base.Complex{Float64}, 3},
                                        WannierNLQG.IO.PackedCartesianOperator{
                                            1,
                                            4,
                                            Array{Base.Complex{Float64}, 3},
                                        },
                                    },
                                    Int64,
                                    Base.Dict{String, WannierNLQG.Runtime.BundleFamilyCounter},
                                    WannierNLQG.Runtime.NormalizedRunControls,
                                    Float64,
                                    Int64,
                                    Base.ReentrantLock,
                                },
                                WannierNLQG.Runtime.var"#finish!#753"{
                                    WannierNLQG.Runtime.var"#cleanup!#689"{
                                        NamedTuple{
                                            (
                                                :model,
                                                :spin,
                                                :spin_velocity,
                                                :orbital,
                                                :derivative_overlap,
                                                :manifest,
                                                :read_mode,
                                                :fallback_reason,
                                                :storage_owner,
                                                :replica_summary,
                                            ),
                                            Tuple{
                                                WannierNLQG.Core.TightBindingModel{
                                                    Array{Base.Complex{Float64}, 3},
                                                    WannierNLQG.IO.PackedCartesianOperator{
                                                        1,
                                                        4,
                                                        Array{Base.Complex{Float64}, 3},
                                                    },
                                                },
                                                WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                    WannierNLQG.IO.PackedCartesianOperator{
                                                        1,
                                                        4,
                                                        Array{Base.Complex{Float64}, 3},
                                                    },
                                                },
                                                Nothing,
                                                Nothing,
                                                Nothing,
                                                WannierNLQG.IO.OperatorBundleManifest,
                                                Symbol,
                                                Nothing,
                                                WannierNLQG.Runtime.MPISharedOperatorStorage,
                                                WannierNLQG.Runtime.RuntimeReplicaSummary,
                                            },
                                        },
                                        Base.RefValue{Bool},
                                        Base.RefValue{Any},
                                        Array{
                                            WannierNLQG.MatrixElements.MatrixElementWorkspace{
                                                D,
                                                S,
                                                I,
                                            } where {I} where {S} where D,
                                            1,
                                        },
                                    },
                                    Bool,
                                    WannierNLQG.Runtime.EffectiveTaskConfig,
                                    WannierNLQG.Runtime.RunContext,
                                    Float64,
                                    Base.Threads.Atomic{Int64},
                                    Base.Threads.Atomic{Int64},
                                    Base.Threads.Atomic{Int64},
                                    Int64,
                                    Nothing,
                                    WannierNLQG.Runtime.FourierExecutionPlan,
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Array{
                                        WannierNLQG.MatrixElements.MatrixElementWorkspace{
                                            WannierNLQG.MatrixElements.KPointMatrixData{
                                                WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                                    Array{Float64, 2},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                                WannierNLQG.MatrixElements.PositionMatrixData{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Array{Float64, 2},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.SpinMatrixData,
                                                Nothing,
                                            },
                                            WannierNLQG.MatrixElements.MatrixElementScratch{
                                                WannierNLQG.MatrixElements.HamiltonianMatrixScratch{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 4},
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.PositionMatrixScratch{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 2},
                                                },
                                                WannierNLQG.MatrixElements.SpinMatrixScratch,
                                                Nothing,
                                            },
                                            WannierNLQG.MatrixElements.MatrixElementSources{
                                                WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                    WannierNLQG.IO.PackedCartesianOperator{
                                                        1,
                                                        4,
                                                        Array{Base.Complex{Float64}, 3},
                                                    },
                                                },
                                                Nothing,
                                                Nothing,
                                            },
                                        },
                                        1,
                                    },
                                    Int64,
                                    Int64,
                                    WannierNLQG.Runtime.ResponseQualificationResult,
                                    NamedTuple{
                                        (
                                            :model,
                                            :spin,
                                            :spin_velocity,
                                            :orbital,
                                            :derivative_overlap,
                                            :manifest,
                                            :read_mode,
                                            :fallback_reason,
                                            :storage_owner,
                                            :replica_summary,
                                        ),
                                        Tuple{
                                            WannierNLQG.Core.TightBindingModel{
                                                Array{Base.Complex{Float64}, 3},
                                                WannierNLQG.IO.PackedCartesianOperator{
                                                    1,
                                                    4,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                            },
                                            WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                WannierNLQG.IO.PackedCartesianOperator{
                                                    1,
                                                    4,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                            },
                                            Nothing,
                                            Nothing,
                                            Nothing,
                                            WannierNLQG.IO.OperatorBundleManifest,
                                            Symbol,
                                            Nothing,
                                            WannierNLQG.Runtime.MPISharedOperatorStorage,
                                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                                        },
                                    },
                                    Base.Dict{Symbol, Any},
                                    Nothing,
                                    Int64,
                                    Int64,
                                    Int64,
                                    MPI.Comm,
                                    Base.Dict{String, WannierNLQG.Runtime.BundleFamilyCounter},
                                    Array{String, 1},
                                    Float64,
                                    Base.ReentrantLock,
                                },
                                WannierNLQG.Runtime.var"#cleanup!#689"{
                                    NamedTuple{
                                        (
                                            :model,
                                            :spin,
                                            :spin_velocity,
                                            :orbital,
                                            :derivative_overlap,
                                            :manifest,
                                            :read_mode,
                                            :fallback_reason,
                                            :storage_owner,
                                            :replica_summary,
                                        ),
                                        Tuple{
                                            WannierNLQG.Core.TightBindingModel{
                                                Array{Base.Complex{Float64}, 3},
                                                WannierNLQG.IO.PackedCartesianOperator{
                                                    1,
                                                    4,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                            },
                                            WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                WannierNLQG.IO.PackedCartesianOperator{
                                                    1,
                                                    4,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                            },
                                            Nothing,
                                            Nothing,
                                            Nothing,
                                            WannierNLQG.IO.OperatorBundleManifest,
                                            Symbol,
                                            Nothing,
                                            WannierNLQG.Runtime.MPISharedOperatorStorage,
                                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                                        },
                                    },
                                    Base.RefValue{Bool},
                                    Base.RefValue{Any},
                                    Array{
                                        WannierNLQG.MatrixElements.MatrixElementWorkspace{
                                            D,
                                            S,
                                            I,
                                        } where {I} where {S} where D,
                                        1,
                                    },
                                },
                            },
                        },
                    },
                    Int64,
                },
            },
        )
    end
end

# Grouped exact residual requests from both legal nonzero Zeeman first calls.
# Compilation only through the existing owned bridge; no target execution,
# library initialization, MPI initialization, file writes, or saved handles.
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        precompile(
            Tuple{
                Base.Threads.var"#1#2"{
                    WannierNLQG.Runtime.var"#2304#threadsfor_fun#576"{
                        WannierNLQG.Runtime.var"#2304#threadsfor_fun#573#577"{
                            Array{
                                WannierNLQG.Runtime.PreparedResponseTask{
                                    E,
                                    F,
                                    C,
                                } where {C} where {F} where E,
                                1,
                            },
                            Array{WannierNLQG.MatrixElements.SharedInterpolationCache, 1},
                            Int64,
                            Array{Array{Tuple{Int64, Int64, Int64}, 1}, 1},
                            Array{Array{Int64, 1}, 1},
                            Base.UnitRange{Int64},
                        },
                    },
                    Int64,
                },
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Base.Threads.var"#1#2"{
                    WannierNLQG.Runtime.var"#2304#threadsfor_fun#576"{
                        WannierNLQG.Runtime.var"#2304#threadsfor_fun#573#577"{
                            Array{
                                WannierNLQG.Runtime.PreparedResponseTask{
                                    E,
                                    F,
                                    C,
                                } where {C} where {F} where E,
                                1,
                            },
                            Array{WannierNLQG.MatrixElements.SharedInterpolationCache, 1},
                            Int64,
                            Array{Array{Tuple{Int64, Int64, Int64}, 1}, 1},
                            Array{Array{Int64, 1}, 1},
                            Base.UnitRange{Int64},
                        },
                    },
                    Int64,
                },
            },
        )
        precompile(Tuple{Type{Array{Bool, N} where N}, UndefInitializer, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Array{Bool, N} where N},
                UndefInitializer,
                Int64,
            },
        )
        precompile(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Array{Float64, N} where N},
                UndefInitializer,
                Int64,
                Int64,
            },
        )
        precompile(Tuple{Type{Array{Float64, N} where N}, UndefInitializer, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Array{Float64, N} where N},
                UndefInitializer,
                Int64,
            },
        )
        precompile(Tuple{Type{Array{Int64, 1}}, Array{Int64, 1}})
        precompile(Tuple{typeof(_first_use_foreign_call), Type{Array{Int64, 1}}, Array{Int64, 1}})
        precompile(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Array{Int64, N} where N},
                UndefInitializer,
                Int64,
                Int64,
            },
        )
        precompile(Tuple{Type{Array{Int64, N} where N}, UndefInitializer, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Array{Int64, N} where N},
                UndefInitializer,
                Int64,
            },
        )
        precompile(Tuple{Type{Array{Int8, N} where N}, UndefInitializer, Int64, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Array{Int8, N} where N},
                UndefInitializer,
                Int64,
                Int64,
            },
        )
        precompile(Tuple{Type{Array{UInt64, N} where N}, UndefInitializer, Int64, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Array{UInt64, N} where N},
                UndefInitializer,
                Int64,
                Int64,
            },
        )
        precompile(Tuple{Type{Array{UInt64, N} where N}, UndefInitializer, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Array{UInt64, N} where N},
                UndefInitializer,
                Int64,
            },
        )
        precompile(Tuple{Type{Array{UInt8, N} where N}, UndefInitializer, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Array{UInt8, N} where N},
                UndefInitializer,
                Int64,
            },
        )
        precompile(Tuple{Type{Base.Set{Tuple{Int64, Int64}}}, Tuple{Tuple{Int64, Int64}}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Base.Set{Tuple{Int64, Int64}}},
                Tuple{Tuple{Int64, Int64}},
            },
        )
        precompile(Tuple{Type{Base.Set{T} where T}, Array{String, 1}})
        precompile(
            Tuple{typeof(_first_use_foreign_call), Type{Base.Set{T} where T}, Array{String, 1}},
        )
        precompile(Tuple{Type{Pair{A, B} where {B} where A}, String, Base.Dict{String, Any}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Pair{A, B} where {B} where A},
                String,
                Base.Dict{String, Any},
            },
        )
        precompile(Tuple{Type{Pair{A, B} where {B} where A}, String, Float64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Pair{A, B} where {B} where A},
                String,
                Float64,
            },
        )
        precompile(Tuple{Type{Pair{A, B} where {B} where A}, Tuple{Int64, Int64, Int64}, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                Type{Pair{A, B} where {B} where A},
                Tuple{Int64, Int64, Int64},
                Int64,
            },
        )
        precompile(Tuple{Type{UInt8}, UInt8})
        precompile(Tuple{typeof(_first_use_foreign_call), Type{UInt8}, UInt8})
        precompile(
            Tuple{
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
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Bool,
                Bool,
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
                Nothing,
                Nothing,
                Bool,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Bool,
                Nothing,
                Nothing,
                Bool,
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
                Nothing,
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
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
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
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Bool,
                Bool,
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
                Nothing,
                Nothing,
                Bool,
                Nothing,
                Nothing,
                Nothing,
                Nothing,
                Bool,
                Nothing,
                Nothing,
                Bool,
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
                Nothing,
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
        precompile(Tuple{typeof(Base.:(<=)), Float64, Float64})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.:(<=)), Float64, Float64})
        precompile(Tuple{typeof(Base.:(==)), Array{UInt64, 1}, Array{UInt64, 1}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.:(==)),
                Array{UInt64, 1},
                Array{UInt64, 1},
            },
        )
        precompile(Tuple{typeof(Base.:(==)), Bool, Bool})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.:(==)), Bool, Bool})
        precompile(
            Tuple{typeof(Base.:(==)), Tuple{Int64, Int64, Int64}, Tuple{Int64, Int64, Int64}},
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.:(==)),
                Tuple{Int64, Int64, Int64},
                Tuple{Int64, Int64, Int64},
            },
        )
        precompile(Tuple{typeof(Base.:(==)), Tuple{Int64, Int64}, Tuple{Int64, Int64}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.:(==)),
                Tuple{Int64, Int64},
                Tuple{Int64, Int64},
            },
        )
        precompile(Tuple{typeof(Base.:(==)), UInt64, UInt64})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.:(==)), UInt64, UInt64})
        precompile(Tuple{typeof(Base.:(>)), Float64, Float64})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.:(>)), Float64, Float64})
        precompile(Tuple{typeof(Base.:(>)), Float64, Int64})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.:(>)), Float64, Int64})
        precompile(Tuple{typeof(Base.:(>=)), Float64, Float64})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.:(>=)), Float64, Float64})
        precompile(Tuple{typeof(Base.Order.lt), Base.Order.ForwardOrdering, Int64, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.Order.lt),
                Base.Order.ForwardOrdering,
                Int64,
                Int64,
            },
        )
        precompile(
            Tuple{
                typeof(Base._all),
                Base.Fix2{typeof(Base.:(>)), Int64},
                Array{Int64, 1},
                Base.Colon,
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base._all),
                Base.Fix2{typeof(Base.:(>)), Int64},
                Array{Int64, 1},
                Base.Colon,
            },
        )
        precompile(Tuple{typeof(Base.all), Array{Bool, 1}})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.all), Array{Bool, 1}})
        precompile(Tuple{typeof(Base.collect), Base.KeySet{String, Base.Dict{String, Any}}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.collect),
                Base.KeySet{String, Base.Dict{String, Any}},
            },
        )
        precompile(Tuple{typeof(Base.collect), Tuple{Int64, Int64}})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.collect), Tuple{Int64, Int64}},
        )
        precompile(Tuple{typeof(Base.getindex), Array{Bool, 1}, Int64})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.getindex), Array{Bool, 1}, Int64},
        )
        precompile(Tuple{typeof(Base.getindex), Array{Float64, 1}, Int64})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.getindex), Array{Float64, 1}, Int64},
        )
        precompile(Tuple{typeof(Base.getindex), Array{Tuple{Int64, Int64}, 1}, Int64})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.getindex),
                Array{Tuple{Int64, Int64}, 1},
                Int64,
            },
        )
        precompile(Tuple{typeof(Base.getindex), Array{UInt64, 1}, Int64})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.getindex), Array{UInt64, 1}, Int64},
        )
        precompile(Tuple{typeof(Base.getindex), Array{UInt8, 1}, Int64})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.getindex), Array{UInt8, 1}, Int64},
        )
        precompile(Tuple{typeof(Base.getindex), Type{Tuple{Int64, Int64}}, Tuple{Int64, Int64}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.getindex),
                Type{Tuple{Int64, Int64}},
                Tuple{Int64, Int64},
            },
        )
        precompile(
            Tuple{
                typeof(Base.getindex),
                Type{WannierNLQG.Core.RealSpaceOperatorKind},
                WannierNLQG.Core.RealSpaceOperatorKind,
                WannierNLQG.Core.RealSpaceOperatorKind,
                WannierNLQG.Core.RealSpaceOperatorKind,
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.getindex),
                Type{WannierNLQG.Core.RealSpaceOperatorKind},
                WannierNLQG.Core.RealSpaceOperatorKind,
                WannierNLQG.Core.RealSpaceOperatorKind,
                WannierNLQG.Core.RealSpaceOperatorKind,
            },
        )
        precompile(
            Tuple{
                typeof(Base.getproperty),
                NamedTuple{
                    (
                        :denominator_regularization,
                        :degeneracy_threshold,
                        :finite_difference_step,
                        :band_window_size,
                    ),
                    Tuple{Float64, Float64, Nothing, Nothing},
                },
                Symbol,
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.getproperty),
                NamedTuple{
                    (
                        :denominator_regularization,
                        :degeneracy_threshold,
                        :finite_difference_step,
                        :band_window_size,
                    ),
                    Tuple{Float64, Float64, Nothing, Nothing},
                },
                Symbol,
            },
        )
        precompile(Tuple{typeof(Base.haskey), Base.Dict{Base.PkgId, Module}, Base.PkgId})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.haskey),
                Base.Dict{Base.PkgId, Module},
                Base.PkgId,
            },
        )
        precompile(Tuple{typeof(Base.in), String, NTuple{4, String}})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.in), String, NTuple{4, String}},
        )
        precompile(Tuple{typeof(Base.in), String, NTuple{5, String}})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.in), String, NTuple{5, String}},
        )
        precompile(Tuple{typeof(Base.in), String, Tuple{String, String, String}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.in),
                String,
                Tuple{String, String, String},
            },
        )
        precompile(Tuple{typeof(Base.isfinite), Float64})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.isfinite), Float64})
        precompile(
            Tuple{
                typeof(Base.issorted),
                Array{String, 1},
                Base.Order.ReverseOrdering{Base.Order.ForwardOrdering},
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.issorted),
                Array{String, 1},
                Base.Order.ReverseOrdering{Base.Order.ForwardOrdering},
            },
        )
        precompile(Tuple{typeof(Base.iterate), Array{Array{String, 1}, 1}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.iterate),
                Array{Array{String, 1}, 1},
            },
        )
        precompile(
            Tuple{
                typeof(Base.iterate),
                Base.Iterators.Flatten{
                    Base.Generator{
                        Array{
                            WannierNLQG.Runtime.PreparedResponseTask{
                                E,
                                F,
                                C,
                            } where {C} where {F} where E,
                            1,
                        },
                        WannierNLQG.Runtime.var"#561#567",
                    },
                },
                Tuple{
                    Int64,
                    Base.Generator{
                        Array{Tuple{Int64, Int64, Int64}, 1},
                        WannierNLQG.Runtime.var"#560#568"{
                            WannierNLQG.Runtime.PreparedResponseTask{
                                WannierNLQG.Runtime.var"#execute_point!#752"{
                                    Bool,
                                    WannierNLQG.Runtime.EffectiveTaskConfig,
                                    Array{Array{Float64, 1}, 1},
                                    Float64,
                                    Base.Threads.Atomic{Int64},
                                    Base.Threads.Atomic{Int64},
                                    Base.Threads.Atomic{Int64},
                                    Base.Threads.Atomic{Int64},
                                    Int64,
                                    Array{Int64, 1},
                                    Nothing,
                                    Array{Float64, 1},
                                    Array{Float64, 2},
                                    Array{Float64, 1},
                                    Array{Float64, 1},
                                    Array{Float64, 2},
                                    Array{Float64, 2},
                                    Array{Float64, 2},
                                    Array{Float64, 2},
                                    Array{
                                        WannierNLQG.Responses.PhotonDragInjectionCurrentConventionalWorkspace{
                                            W,
                                            D,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.WilsonLoopResponseWorkspace{
                                            W,
                                            D,
                                            F,
                                        } where {
                                            F <:
                                            WannierNLQG.MatrixElements.ConventionFrameConnector,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.GeometricLoopResponseWorkspace{
                                            W,
                                            D,
                                            F,
                                        } where {
                                            F <:
                                            WannierNLQG.MatrixElements.ConventionFrameConnector,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.GeometricLoopResponseWorkspace{
                                            W,
                                            D,
                                            F,
                                        } where {
                                            F <:
                                            WannierNLQG.MatrixElements.ConventionFrameConnector,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.GeometricLoopResponseWorkspace{
                                            W,
                                            D,
                                            F,
                                        } where {
                                            F <:
                                            WannierNLQG.MatrixElements.ConventionFrameConnector,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.GeometricLoopResponseWorkspace{
                                            W,
                                            D,
                                            F,
                                        } where {
                                            F <:
                                            WannierNLQG.MatrixElements.ConventionFrameConnector,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.ProjectorResponseWorkspace{
                                            W,
                                            D,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.ConventionalQuantumGeometryWorkspace{
                                            WannierNLQG.MatrixElements.MatrixElementWorkspace{
                                                WannierNLQG.MatrixElements.KPointMatrixData{
                                                    WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                                        Array{Float64, 2},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Array{Base.Complex{Float64}, 3},
                                                    },
                                                    WannierNLQG.MatrixElements.PositionMatrixData{
                                                        Array{Base.Complex{Float64}, 3},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Nothing,
                                                        Array{Float64, 2},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Nothing,
                                                        Nothing,
                                                        Array{Base.Complex{Float64}, 3},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                    },
                                                    WannierNLQG.MatrixElements.SpinMatrixData,
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.MatrixElementScratch{
                                                    WannierNLQG.MatrixElements.HamiltonianMatrixScratch{
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Array{Base.Complex{Float64}, 4},
                                                        Nothing,
                                                    },
                                                    WannierNLQG.MatrixElements.PositionMatrixScratch{
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Nothing,
                                                        Array{Base.Complex{Float64}, 2},
                                                    },
                                                    WannierNLQG.MatrixElements.SpinMatrixScratch,
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.MatrixElementSources{
                                                    WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                        WannierNLQG.IO.PackedCartesianOperator{
                                                            1,
                                                            4,
                                                            Array{Base.Complex{Float64}, 3},
                                                        },
                                                    },
                                                    Nothing,
                                                    Nothing,
                                                },
                                            },
                                            WannierNLQG.MatrixElements.KPointMatrixData{
                                                WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                                    Array{Float64, 2},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                                WannierNLQG.MatrixElements.PositionMatrixData{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Array{Float64, 2},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.SpinMatrixData,
                                                Nothing,
                                            },
                                            WannierNLQG.MatrixElements.KPointBatchWorkspace{
                                                WannierNLQG.MatrixElements.MatrixElementWorkspace{
                                                    WannierNLQG.MatrixElements.KPointMatrixData{
                                                        WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                                            Array{Float64, 2},
                                                            Array{Base.Complex{Float64}, 3},
                                                            Nothing,
                                                            Array{Base.Complex{Float64}, 3},
                                                        },
                                                        WannierNLQG.MatrixElements.PositionMatrixData{
                                                            Array{Base.Complex{Float64}, 3},
                                                            Array{Base.Complex{Float64}, 3},
                                                            Nothing,
                                                            Nothing,
                                                            Array{Float64, 2},
                                                            Array{Base.Complex{Float64}, 3},
                                                            Array{Base.Complex{Float64}, 3},
                                                            Nothing,
                                                            Nothing,
                                                            Nothing,
                                                            Array{Base.Complex{Float64}, 3},
                                                            Array{Base.Complex{Float64}, 3},
                                                            Nothing,
                                                        },
                                                        WannierNLQG.MatrixElements.SpinMatrixData,
                                                        Nothing,
                                                    },
                                                    WannierNLQG.MatrixElements.MatrixElementScratch{
                                                        WannierNLQG.MatrixElements.HamiltonianMatrixScratch{
                                                            Array{Base.Complex{Float64}, 3},
                                                            Nothing,
                                                            Array{Base.Complex{Float64}, 4},
                                                            Nothing,
                                                        },
                                                        WannierNLQG.MatrixElements.PositionMatrixScratch{
                                                            Array{Base.Complex{Float64}, 3},
                                                            Nothing,
                                                            Nothing,
                                                            Array{Base.Complex{Float64}, 2},
                                                        },
                                                        WannierNLQG.MatrixElements.SpinMatrixScratch,
                                                        Nothing,
                                                    },
                                                    WannierNLQG.MatrixElements.MatrixElementSources{
                                                        WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                            WannierNLQG.IO.PackedCartesianOperator{
                                                                1,
                                                                4,
                                                                Array{Base.Complex{Float64}, 3},
                                                            },
                                                        },
                                                        Nothing,
                                                        Nothing,
                                                    },
                                                },
                                                WannierNLQG.MatrixElements.KPointMatrixData{
                                                    WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                                        Array{Float64, 2},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Array{Base.Complex{Float64}, 3},
                                                    },
                                                    WannierNLQG.MatrixElements.PositionMatrixData{
                                                        Array{Base.Complex{Float64}, 3},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Nothing,
                                                        Array{Float64, 2},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Nothing,
                                                        Nothing,
                                                        Array{Base.Complex{Float64}, 3},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                    },
                                                    WannierNLQG.MatrixElements.SpinMatrixData,
                                                    Nothing,
                                                },
                                            },
                                        },
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.ShiftSpinCurrentConventionalWorkspace{
                                            W,
                                            D,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{Array{Base.Complex{Float64}, 6}, 1},
                                    Array{Array{Base.Complex{Float64}, 5}, 1},
                                    Array{
                                        WannierNLQG.Responses.ShiftCurrentConventionalWorkspace{
                                            W,
                                            D,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Runtime.PhotonDragTransitionScreenWorkspace{
                                            W,
                                            D,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Runtime.TransitionScreenWorkspace{
                                            W,
                                            D,
                                        } where {D} where W,
                                        1,
                                    },
                                    WannierNLQG.Core.TightBindingModel{
                                        Array{Base.Complex{Float64}, 3},
                                        WannierNLQG.IO.PackedCartesianOperator{
                                            1,
                                            4,
                                            Array{Base.Complex{Float64}, 3},
                                        },
                                    },
                                    Int64,
                                    Int64,
                                    Tuple{Array{Int64, 1}, Array{Int64, 1}, Array{Int64, 1}},
                                    Tuple{Array{Int64, 1}, Array{Int64, 1}},
                                    Tuple{Array{Int64, 1}, Array{Int64, 1}},
                                    Tuple{Array{Int64, 1}, Array{Int64, 1}},
                                    Base.BitArray{1},
                                    Tuple{Array{Int64, 1}, Array{Int64, 1}},
                                    Int64,
                                    Int64,
                                    Int64,
                                    Nothing,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Nothing,
                                    Nothing,
                                    Nothing,
                                    Nothing,
                                    Nothing,
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Nothing,
                                    WannierNLQG.Runtime.KSliceTaskAccumulator,
                                    Nothing,
                                    Nothing,
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
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
                                    Nothing,
                                    Nothing,
                                    Array{
                                        WannierNLQG.MatrixElements.MatrixElementWorkspace{
                                            WannierNLQG.MatrixElements.KPointMatrixData{
                                                WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                                    Array{Float64, 2},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                                WannierNLQG.MatrixElements.PositionMatrixData{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Array{Float64, 2},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.SpinMatrixData,
                                                Nothing,
                                            },
                                            WannierNLQG.MatrixElements.MatrixElementScratch{
                                                WannierNLQG.MatrixElements.HamiltonianMatrixScratch{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 4},
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.PositionMatrixScratch{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 2},
                                                },
                                                WannierNLQG.MatrixElements.SpinMatrixScratch,
                                                Nothing,
                                            },
                                            WannierNLQG.MatrixElements.MatrixElementSources{
                                                WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                    WannierNLQG.IO.PackedCartesianOperator{
                                                        1,
                                                        4,
                                                        Array{Base.Complex{Float64}, 3},
                                                    },
                                                },
                                                Nothing,
                                                Nothing,
                                            },
                                        },
                                        1,
                                    },
                                    Int64,
                                    WannierNLQG.Core.KSliceGrid2D,
                                    Int64,
                                    Int64,
                                    Float64,
                                    WannierNLQG.Core.TightBindingModel{
                                        Array{Base.Complex{Float64}, 3},
                                        WannierNLQG.IO.PackedCartesianOperator{
                                            1,
                                            4,
                                            Array{Base.Complex{Float64}, 3},
                                        },
                                    },
                                    Int64,
                                    Base.Dict{String, WannierNLQG.Runtime.BundleFamilyCounter},
                                    WannierNLQG.Runtime.NormalizedRunControls,
                                    Float64,
                                    Int64,
                                    Base.ReentrantLock,
                                },
                                WannierNLQG.Runtime.var"#finish!#753"{
                                    WannierNLQG.Runtime.var"#cleanup!#689"{
                                        NamedTuple{
                                            (
                                                :model,
                                                :spin,
                                                :spin_velocity,
                                                :orbital,
                                                :derivative_overlap,
                                                :manifest,
                                                :read_mode,
                                                :fallback_reason,
                                                :storage_owner,
                                                :replica_summary,
                                            ),
                                            Tuple{
                                                WannierNLQG.Core.TightBindingModel{
                                                    Array{Base.Complex{Float64}, 3},
                                                    WannierNLQG.IO.PackedCartesianOperator{
                                                        1,
                                                        4,
                                                        Array{Base.Complex{Float64}, 3},
                                                    },
                                                },
                                                WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                    WannierNLQG.IO.PackedCartesianOperator{
                                                        1,
                                                        4,
                                                        Array{Base.Complex{Float64}, 3},
                                                    },
                                                },
                                                Nothing,
                                                Nothing,
                                                Nothing,
                                                WannierNLQG.IO.OperatorBundleManifest,
                                                Symbol,
                                                Nothing,
                                                WannierNLQG.Runtime.MPISharedOperatorStorage,
                                                WannierNLQG.Runtime.RuntimeReplicaSummary,
                                            },
                                        },
                                        Base.RefValue{Bool},
                                        Base.RefValue{Any},
                                        Array{
                                            WannierNLQG.MatrixElements.MatrixElementWorkspace{
                                                D,
                                                S,
                                                I,
                                            } where {I} where {S} where D,
                                            1,
                                        },
                                    },
                                    Bool,
                                    WannierNLQG.Runtime.EffectiveTaskConfig,
                                    WannierNLQG.Runtime.RunContext,
                                    Float64,
                                    Base.Threads.Atomic{Int64},
                                    Base.Threads.Atomic{Int64},
                                    Base.Threads.Atomic{Int64},
                                    Int64,
                                    Nothing,
                                    WannierNLQG.Runtime.FourierExecutionPlan,
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Array{
                                        WannierNLQG.MatrixElements.MatrixElementWorkspace{
                                            WannierNLQG.MatrixElements.KPointMatrixData{
                                                WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                                    Array{Float64, 2},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                                WannierNLQG.MatrixElements.PositionMatrixData{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Array{Float64, 2},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.SpinMatrixData,
                                                Nothing,
                                            },
                                            WannierNLQG.MatrixElements.MatrixElementScratch{
                                                WannierNLQG.MatrixElements.HamiltonianMatrixScratch{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 4},
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.PositionMatrixScratch{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 2},
                                                },
                                                WannierNLQG.MatrixElements.SpinMatrixScratch,
                                                Nothing,
                                            },
                                            WannierNLQG.MatrixElements.MatrixElementSources{
                                                WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                    WannierNLQG.IO.PackedCartesianOperator{
                                                        1,
                                                        4,
                                                        Array{Base.Complex{Float64}, 3},
                                                    },
                                                },
                                                Nothing,
                                                Nothing,
                                            },
                                        },
                                        1,
                                    },
                                    Int64,
                                    Int64,
                                    WannierNLQG.Runtime.ResponseQualificationResult,
                                    NamedTuple{
                                        (
                                            :model,
                                            :spin,
                                            :spin_velocity,
                                            :orbital,
                                            :derivative_overlap,
                                            :manifest,
                                            :read_mode,
                                            :fallback_reason,
                                            :storage_owner,
                                            :replica_summary,
                                        ),
                                        Tuple{
                                            WannierNLQG.Core.TightBindingModel{
                                                Array{Base.Complex{Float64}, 3},
                                                WannierNLQG.IO.PackedCartesianOperator{
                                                    1,
                                                    4,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                            },
                                            WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                WannierNLQG.IO.PackedCartesianOperator{
                                                    1,
                                                    4,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                            },
                                            Nothing,
                                            Nothing,
                                            Nothing,
                                            WannierNLQG.IO.OperatorBundleManifest,
                                            Symbol,
                                            Nothing,
                                            WannierNLQG.Runtime.MPISharedOperatorStorage,
                                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                                        },
                                    },
                                    Base.Dict{Symbol, Any},
                                    Nothing,
                                    Int64,
                                    Int64,
                                    Int64,
                                    MPI.Comm,
                                    Base.Dict{String, WannierNLQG.Runtime.BundleFamilyCounter},
                                    Array{String, 1},
                                    Float64,
                                    Base.ReentrantLock,
                                },
                                WannierNLQG.Runtime.var"#cleanup!#689"{
                                    NamedTuple{
                                        (
                                            :model,
                                            :spin,
                                            :spin_velocity,
                                            :orbital,
                                            :derivative_overlap,
                                            :manifest,
                                            :read_mode,
                                            :fallback_reason,
                                            :storage_owner,
                                            :replica_summary,
                                        ),
                                        Tuple{
                                            WannierNLQG.Core.TightBindingModel{
                                                Array{Base.Complex{Float64}, 3},
                                                WannierNLQG.IO.PackedCartesianOperator{
                                                    1,
                                                    4,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                            },
                                            WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                WannierNLQG.IO.PackedCartesianOperator{
                                                    1,
                                                    4,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                            },
                                            Nothing,
                                            Nothing,
                                            Nothing,
                                            WannierNLQG.IO.OperatorBundleManifest,
                                            Symbol,
                                            Nothing,
                                            WannierNLQG.Runtime.MPISharedOperatorStorage,
                                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                                        },
                                    },
                                    Base.RefValue{Bool},
                                    Base.RefValue{Any},
                                    Array{
                                        WannierNLQG.MatrixElements.MatrixElementWorkspace{
                                            D,
                                            S,
                                            I,
                                        } where {I} where {S} where D,
                                        1,
                                    },
                                },
                            },
                        },
                    },
                    Int64,
                },
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.iterate),
                Base.Iterators.Flatten{
                    Base.Generator{
                        Array{
                            WannierNLQG.Runtime.PreparedResponseTask{
                                E,
                                F,
                                C,
                            } where {C} where {F} where E,
                            1,
                        },
                        WannierNLQG.Runtime.var"#561#567",
                    },
                },
                Tuple{
                    Int64,
                    Base.Generator{
                        Array{Tuple{Int64, Int64, Int64}, 1},
                        WannierNLQG.Runtime.var"#560#568"{
                            WannierNLQG.Runtime.PreparedResponseTask{
                                WannierNLQG.Runtime.var"#execute_point!#752"{
                                    Bool,
                                    WannierNLQG.Runtime.EffectiveTaskConfig,
                                    Array{Array{Float64, 1}, 1},
                                    Float64,
                                    Base.Threads.Atomic{Int64},
                                    Base.Threads.Atomic{Int64},
                                    Base.Threads.Atomic{Int64},
                                    Base.Threads.Atomic{Int64},
                                    Int64,
                                    Array{Int64, 1},
                                    Nothing,
                                    Array{Float64, 1},
                                    Array{Float64, 2},
                                    Array{Float64, 1},
                                    Array{Float64, 1},
                                    Array{Float64, 2},
                                    Array{Float64, 2},
                                    Array{Float64, 2},
                                    Array{Float64, 2},
                                    Array{
                                        WannierNLQG.Responses.PhotonDragInjectionCurrentConventionalWorkspace{
                                            W,
                                            D,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.WilsonLoopResponseWorkspace{
                                            W,
                                            D,
                                            F,
                                        } where {
                                            F <:
                                            WannierNLQG.MatrixElements.ConventionFrameConnector,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.GeometricLoopResponseWorkspace{
                                            W,
                                            D,
                                            F,
                                        } where {
                                            F <:
                                            WannierNLQG.MatrixElements.ConventionFrameConnector,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.GeometricLoopResponseWorkspace{
                                            W,
                                            D,
                                            F,
                                        } where {
                                            F <:
                                            WannierNLQG.MatrixElements.ConventionFrameConnector,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.GeometricLoopResponseWorkspace{
                                            W,
                                            D,
                                            F,
                                        } where {
                                            F <:
                                            WannierNLQG.MatrixElements.ConventionFrameConnector,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.GeometricLoopResponseWorkspace{
                                            W,
                                            D,
                                            F,
                                        } where {
                                            F <:
                                            WannierNLQG.MatrixElements.ConventionFrameConnector,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.ProjectorResponseWorkspace{
                                            W,
                                            D,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.ConventionalQuantumGeometryWorkspace{
                                            WannierNLQG.MatrixElements.MatrixElementWorkspace{
                                                WannierNLQG.MatrixElements.KPointMatrixData{
                                                    WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                                        Array{Float64, 2},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Array{Base.Complex{Float64}, 3},
                                                    },
                                                    WannierNLQG.MatrixElements.PositionMatrixData{
                                                        Array{Base.Complex{Float64}, 3},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Nothing,
                                                        Array{Float64, 2},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Nothing,
                                                        Nothing,
                                                        Array{Base.Complex{Float64}, 3},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                    },
                                                    WannierNLQG.MatrixElements.SpinMatrixData,
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.MatrixElementScratch{
                                                    WannierNLQG.MatrixElements.HamiltonianMatrixScratch{
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Array{Base.Complex{Float64}, 4},
                                                        Nothing,
                                                    },
                                                    WannierNLQG.MatrixElements.PositionMatrixScratch{
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Nothing,
                                                        Array{Base.Complex{Float64}, 2},
                                                    },
                                                    WannierNLQG.MatrixElements.SpinMatrixScratch,
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.MatrixElementSources{
                                                    WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                        WannierNLQG.IO.PackedCartesianOperator{
                                                            1,
                                                            4,
                                                            Array{Base.Complex{Float64}, 3},
                                                        },
                                                    },
                                                    Nothing,
                                                    Nothing,
                                                },
                                            },
                                            WannierNLQG.MatrixElements.KPointMatrixData{
                                                WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                                    Array{Float64, 2},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                                WannierNLQG.MatrixElements.PositionMatrixData{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Array{Float64, 2},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.SpinMatrixData,
                                                Nothing,
                                            },
                                            WannierNLQG.MatrixElements.KPointBatchWorkspace{
                                                WannierNLQG.MatrixElements.MatrixElementWorkspace{
                                                    WannierNLQG.MatrixElements.KPointMatrixData{
                                                        WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                                            Array{Float64, 2},
                                                            Array{Base.Complex{Float64}, 3},
                                                            Nothing,
                                                            Array{Base.Complex{Float64}, 3},
                                                        },
                                                        WannierNLQG.MatrixElements.PositionMatrixData{
                                                            Array{Base.Complex{Float64}, 3},
                                                            Array{Base.Complex{Float64}, 3},
                                                            Nothing,
                                                            Nothing,
                                                            Array{Float64, 2},
                                                            Array{Base.Complex{Float64}, 3},
                                                            Array{Base.Complex{Float64}, 3},
                                                            Nothing,
                                                            Nothing,
                                                            Nothing,
                                                            Array{Base.Complex{Float64}, 3},
                                                            Array{Base.Complex{Float64}, 3},
                                                            Nothing,
                                                        },
                                                        WannierNLQG.MatrixElements.SpinMatrixData,
                                                        Nothing,
                                                    },
                                                    WannierNLQG.MatrixElements.MatrixElementScratch{
                                                        WannierNLQG.MatrixElements.HamiltonianMatrixScratch{
                                                            Array{Base.Complex{Float64}, 3},
                                                            Nothing,
                                                            Array{Base.Complex{Float64}, 4},
                                                            Nothing,
                                                        },
                                                        WannierNLQG.MatrixElements.PositionMatrixScratch{
                                                            Array{Base.Complex{Float64}, 3},
                                                            Nothing,
                                                            Nothing,
                                                            Array{Base.Complex{Float64}, 2},
                                                        },
                                                        WannierNLQG.MatrixElements.SpinMatrixScratch,
                                                        Nothing,
                                                    },
                                                    WannierNLQG.MatrixElements.MatrixElementSources{
                                                        WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                            WannierNLQG.IO.PackedCartesianOperator{
                                                                1,
                                                                4,
                                                                Array{Base.Complex{Float64}, 3},
                                                            },
                                                        },
                                                        Nothing,
                                                        Nothing,
                                                    },
                                                },
                                                WannierNLQG.MatrixElements.KPointMatrixData{
                                                    WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                                        Array{Float64, 2},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Array{Base.Complex{Float64}, 3},
                                                    },
                                                    WannierNLQG.MatrixElements.PositionMatrixData{
                                                        Array{Base.Complex{Float64}, 3},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Nothing,
                                                        Array{Float64, 2},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                        Nothing,
                                                        Nothing,
                                                        Array{Base.Complex{Float64}, 3},
                                                        Array{Base.Complex{Float64}, 3},
                                                        Nothing,
                                                    },
                                                    WannierNLQG.MatrixElements.SpinMatrixData,
                                                    Nothing,
                                                },
                                            },
                                        },
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Responses.ShiftSpinCurrentConventionalWorkspace{
                                            W,
                                            D,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{Array{Base.Complex{Float64}, 6}, 1},
                                    Array{Array{Base.Complex{Float64}, 5}, 1},
                                    Array{
                                        WannierNLQG.Responses.ShiftCurrentConventionalWorkspace{
                                            W,
                                            D,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Runtime.PhotonDragTransitionScreenWorkspace{
                                            W,
                                            D,
                                        } where {D} where W,
                                        1,
                                    },
                                    Array{
                                        WannierNLQG.Runtime.TransitionScreenWorkspace{
                                            W,
                                            D,
                                        } where {D} where W,
                                        1,
                                    },
                                    WannierNLQG.Core.TightBindingModel{
                                        Array{Base.Complex{Float64}, 3},
                                        WannierNLQG.IO.PackedCartesianOperator{
                                            1,
                                            4,
                                            Array{Base.Complex{Float64}, 3},
                                        },
                                    },
                                    Int64,
                                    Int64,
                                    Tuple{Array{Int64, 1}, Array{Int64, 1}, Array{Int64, 1}},
                                    Tuple{Array{Int64, 1}, Array{Int64, 1}},
                                    Tuple{Array{Int64, 1}, Array{Int64, 1}},
                                    Tuple{Array{Int64, 1}, Array{Int64, 1}},
                                    Base.BitArray{1},
                                    Tuple{Array{Int64, 1}, Array{Int64, 1}},
                                    Int64,
                                    Int64,
                                    Int64,
                                    Nothing,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Bool,
                                    Nothing,
                                    Nothing,
                                    Nothing,
                                    Nothing,
                                    Nothing,
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Nothing,
                                    WannierNLQG.Runtime.KSliceTaskAccumulator,
                                    Nothing,
                                    Nothing,
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
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
                                    Nothing,
                                    Nothing,
                                    Array{
                                        WannierNLQG.MatrixElements.MatrixElementWorkspace{
                                            WannierNLQG.MatrixElements.KPointMatrixData{
                                                WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                                    Array{Float64, 2},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                                WannierNLQG.MatrixElements.PositionMatrixData{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Array{Float64, 2},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.SpinMatrixData,
                                                Nothing,
                                            },
                                            WannierNLQG.MatrixElements.MatrixElementScratch{
                                                WannierNLQG.MatrixElements.HamiltonianMatrixScratch{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 4},
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.PositionMatrixScratch{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 2},
                                                },
                                                WannierNLQG.MatrixElements.SpinMatrixScratch,
                                                Nothing,
                                            },
                                            WannierNLQG.MatrixElements.MatrixElementSources{
                                                WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                    WannierNLQG.IO.PackedCartesianOperator{
                                                        1,
                                                        4,
                                                        Array{Base.Complex{Float64}, 3},
                                                    },
                                                },
                                                Nothing,
                                                Nothing,
                                            },
                                        },
                                        1,
                                    },
                                    Int64,
                                    WannierNLQG.Core.KSliceGrid2D,
                                    Int64,
                                    Int64,
                                    Float64,
                                    WannierNLQG.Core.TightBindingModel{
                                        Array{Base.Complex{Float64}, 3},
                                        WannierNLQG.IO.PackedCartesianOperator{
                                            1,
                                            4,
                                            Array{Base.Complex{Float64}, 3},
                                        },
                                    },
                                    Int64,
                                    Base.Dict{String, WannierNLQG.Runtime.BundleFamilyCounter},
                                    WannierNLQG.Runtime.NormalizedRunControls,
                                    Float64,
                                    Int64,
                                    Base.ReentrantLock,
                                },
                                WannierNLQG.Runtime.var"#finish!#753"{
                                    WannierNLQG.Runtime.var"#cleanup!#689"{
                                        NamedTuple{
                                            (
                                                :model,
                                                :spin,
                                                :spin_velocity,
                                                :orbital,
                                                :derivative_overlap,
                                                :manifest,
                                                :read_mode,
                                                :fallback_reason,
                                                :storage_owner,
                                                :replica_summary,
                                            ),
                                            Tuple{
                                                WannierNLQG.Core.TightBindingModel{
                                                    Array{Base.Complex{Float64}, 3},
                                                    WannierNLQG.IO.PackedCartesianOperator{
                                                        1,
                                                        4,
                                                        Array{Base.Complex{Float64}, 3},
                                                    },
                                                },
                                                WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                    WannierNLQG.IO.PackedCartesianOperator{
                                                        1,
                                                        4,
                                                        Array{Base.Complex{Float64}, 3},
                                                    },
                                                },
                                                Nothing,
                                                Nothing,
                                                Nothing,
                                                WannierNLQG.IO.OperatorBundleManifest,
                                                Symbol,
                                                Nothing,
                                                WannierNLQG.Runtime.MPISharedOperatorStorage,
                                                WannierNLQG.Runtime.RuntimeReplicaSummary,
                                            },
                                        },
                                        Base.RefValue{Bool},
                                        Base.RefValue{Any},
                                        Array{
                                            WannierNLQG.MatrixElements.MatrixElementWorkspace{
                                                D,
                                                S,
                                                I,
                                            } where {I} where {S} where D,
                                            1,
                                        },
                                    },
                                    Bool,
                                    WannierNLQG.Runtime.EffectiveTaskConfig,
                                    WannierNLQG.Runtime.RunContext,
                                    Float64,
                                    Base.Threads.Atomic{Int64},
                                    Base.Threads.Atomic{Int64},
                                    Base.Threads.Atomic{Int64},
                                    Int64,
                                    Nothing,
                                    WannierNLQG.Runtime.FourierExecutionPlan,
                                    Array{WannierNLQG.Runtime.KSliceTaskAccumulator, 1},
                                    Array{
                                        WannierNLQG.MatrixElements.MatrixElementWorkspace{
                                            WannierNLQG.MatrixElements.KPointMatrixData{
                                                WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                                    Array{Float64, 2},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                                WannierNLQG.MatrixElements.PositionMatrixData{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Array{Float64, 2},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 3},
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.SpinMatrixData,
                                                Nothing,
                                            },
                                            WannierNLQG.MatrixElements.MatrixElementScratch{
                                                WannierNLQG.MatrixElements.HamiltonianMatrixScratch{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 4},
                                                    Nothing,
                                                },
                                                WannierNLQG.MatrixElements.PositionMatrixScratch{
                                                    Array{Base.Complex{Float64}, 3},
                                                    Nothing,
                                                    Nothing,
                                                    Array{Base.Complex{Float64}, 2},
                                                },
                                                WannierNLQG.MatrixElements.SpinMatrixScratch,
                                                Nothing,
                                            },
                                            WannierNLQG.MatrixElements.MatrixElementSources{
                                                WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                    WannierNLQG.IO.PackedCartesianOperator{
                                                        1,
                                                        4,
                                                        Array{Base.Complex{Float64}, 3},
                                                    },
                                                },
                                                Nothing,
                                                Nothing,
                                            },
                                        },
                                        1,
                                    },
                                    Int64,
                                    Int64,
                                    WannierNLQG.Runtime.ResponseQualificationResult,
                                    NamedTuple{
                                        (
                                            :model,
                                            :spin,
                                            :spin_velocity,
                                            :orbital,
                                            :derivative_overlap,
                                            :manifest,
                                            :read_mode,
                                            :fallback_reason,
                                            :storage_owner,
                                            :replica_summary,
                                        ),
                                        Tuple{
                                            WannierNLQG.Core.TightBindingModel{
                                                Array{Base.Complex{Float64}, 3},
                                                WannierNLQG.IO.PackedCartesianOperator{
                                                    1,
                                                    4,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                            },
                                            WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                WannierNLQG.IO.PackedCartesianOperator{
                                                    1,
                                                    4,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                            },
                                            Nothing,
                                            Nothing,
                                            Nothing,
                                            WannierNLQG.IO.OperatorBundleManifest,
                                            Symbol,
                                            Nothing,
                                            WannierNLQG.Runtime.MPISharedOperatorStorage,
                                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                                        },
                                    },
                                    Base.Dict{Symbol, Any},
                                    Nothing,
                                    Int64,
                                    Int64,
                                    Int64,
                                    MPI.Comm,
                                    Base.Dict{String, WannierNLQG.Runtime.BundleFamilyCounter},
                                    Array{String, 1},
                                    Float64,
                                    Base.ReentrantLock,
                                },
                                WannierNLQG.Runtime.var"#cleanup!#689"{
                                    NamedTuple{
                                        (
                                            :model,
                                            :spin,
                                            :spin_velocity,
                                            :orbital,
                                            :derivative_overlap,
                                            :manifest,
                                            :read_mode,
                                            :fallback_reason,
                                            :storage_owner,
                                            :replica_summary,
                                        ),
                                        Tuple{
                                            WannierNLQG.Core.TightBindingModel{
                                                Array{Base.Complex{Float64}, 3},
                                                WannierNLQG.IO.PackedCartesianOperator{
                                                    1,
                                                    4,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                            },
                                            WannierNLQG.MatrixElements.SpinRealSpaceData{
                                                WannierNLQG.IO.PackedCartesianOperator{
                                                    1,
                                                    4,
                                                    Array{Base.Complex{Float64}, 3},
                                                },
                                            },
                                            Nothing,
                                            Nothing,
                                            Nothing,
                                            WannierNLQG.IO.OperatorBundleManifest,
                                            Symbol,
                                            Nothing,
                                            WannierNLQG.Runtime.MPISharedOperatorStorage,
                                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                                        },
                                    },
                                    Base.RefValue{Bool},
                                    Base.RefValue{Any},
                                    Array{
                                        WannierNLQG.MatrixElements.MatrixElementWorkspace{
                                            D,
                                            S,
                                            I,
                                        } where {I} where {S} where D,
                                        1,
                                    },
                                },
                            },
                        },
                    },
                    Int64,
                },
            },
        )
        precompile(
            Tuple{
                typeof(Base.join),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Array{Float64, 1},
                String,
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.join),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Array{Float64, 1},
                String,
            },
        )
        precompile(
            Tuple{
                typeof(Base.join),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Tuple{Int64, Int64, Int64},
                Char,
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.join),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Tuple{Int64, Int64, Int64},
                Char,
            },
        )
        precompile(
            Tuple{
                typeof(Base.join),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Tuple{String, String, String},
                String,
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.join),
                Base.GenericIOBuffer{
                    GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                },
                Tuple{String, String, String},
                String,
            },
        )
        precompile(Tuple{typeof(Base.keys), Base.Dict{String, Any}})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.keys), Base.Dict{String, Any}},
        )
        precompile(Tuple{typeof(Base.length), Array{Int64, 1}})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.length), Array{Int64, 1}})
        precompile(Tuple{typeof(Base.length), Array{Tuple{Int64, Int64}, 1}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.length),
                Array{Tuple{Int64, Int64}, 1},
            },
        )
        precompile(Tuple{typeof(Base.length), Array{UInt8, 1}})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.length), Array{UInt8, 1}})
        precompile(Tuple{typeof(Base.occursin), Base.Regex, String})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.occursin), Base.Regex, String},
        )
        precompile(Tuple{typeof(Base.prod), Tuple{Int64}})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.prod), Tuple{Int64}})
        precompile(Tuple{typeof(Base.push!), Array{Symbol, 1}, Symbol})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.push!), Array{Symbol, 1}, Symbol},
        )
        precompile(Tuple{typeof(Base.repeat), Char, Int64})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.repeat), Char, Int64})
        precompile(
            Tuple{
                typeof(Base.setindex!),
                Array{Pair{String, String}, 1},
                Pair{String, String},
                Int64,
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.setindex!),
                Array{Pair{String, String}, 1},
                Pair{String, String},
                Int64,
            },
        )
        precompile(Tuple{typeof(Base.setindex!), Base.EnvDict, String, String})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.setindex!),
                Base.EnvDict,
                String,
                String,
            },
        )
        precompile(
            Tuple{
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                },
                Bool,
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                },
                Bool,
            },
        )
        precompile(
            Tuple{
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                },
                Int64,
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                },
                Int64,
            },
        )
        precompile(
            Tuple{
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                },
                NamedTuple{
                    (:kind, :first, :second),
                    Tuple{String, Array{Int64, 1}, Array{Int64, 1}},
                },
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.show),
                Base.IOContext{
                    Base.GenericIOBuffer{
                        GenericMemory{:not_atomic, UInt8, Base.Core.AddrSpace{Base.Core}(0x00)},
                    },
                },
                NamedTuple{
                    (:kind, :first, :second),
                    Tuple{String, Array{Int64, 1}, Array{Int64, 1}},
                },
            },
        )
        precompile(Tuple{typeof(Base.size), Array{Base.Complex{Float64}, 3}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.size),
                Array{Base.Complex{Float64}, 3},
            },
        )
        precompile(Tuple{typeof(Base.size), Array{Float64, 2}})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.size), Array{Float64, 2}})
        precompile(Tuple{typeof(Base.size), Array{Int64, 2}, Int64})
        precompile(
            Tuple{typeof(_first_use_foreign_call), typeof(Base.size), Array{Int64, 2}, Int64},
        )
        precompile(Tuple{typeof(Base.strip), String})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.strip), String})
        precompile(Tuple{typeof(Base.vect), Array{String, 1}, Vararg{Array{String, 1}}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.vect),
                Array{String, 1},
                Vararg{Array{String, 1}},
            },
        )
        precompile(Tuple{typeof(MPI.Finalized)})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(MPI.Finalized)})
        precompile(Tuple{typeof(MPI.Initialized)})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(MPI.Initialized)})
    end
end
