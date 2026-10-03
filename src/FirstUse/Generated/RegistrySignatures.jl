# Actual serial registry and 12-rank GeS specializations. These declarations
# compile signatures only: no communicator, output file, or scientific task is created.
@compile_workload begin
    precompile(
        Tuple{
            Base.Iterators.var"#5#6"{
                Tuple{
                    Array{String, 1},
                    Array{WannierNLQG.Runtime.EffectiveTaskConfig, 1},
                    Array{Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1}, 1},
                },
            },
            Int64,
        },
    )
    precompile(
        Tuple{
            Base.Iterators.var"#5#6"{
                Tuple{
                    Array{WannierNLQG.Runtime.EffectiveTaskConfig, 1},
                    Array{Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1}, 1},
                },
            },
            Int64,
        },
    )
    false
    false
    false
    precompile(
        Tuple{
            Base.var"##mapfoldl#335",
            UInt64,
            typeof(Base.mapfoldl),
            Function,
            Function,
            NTuple{4, WannierNLQG.MatrixElements.MatrixElementKind},
        },
    )
    precompile(
        Tuple{
            Base.var"##mapfoldl#335",
            UInt64,
            typeof(Base.mapfoldl),
            Function,
            Function,
            Tuple{WannierNLQG.MatrixElements.MatrixElementKind},
        },
    )
    precompile(
        Tuple{
            Base.var"##open#463",
            Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
            typeof(Base.open),
            WannierNLQG.IO.var"#150#153"{
                Float64,
                Array{Float64, 1},
                Array{Base.Complex{Float64}, 4},
                Array{String, 1},
                Array{Int64, 1},
                Int64,
                Int64,
                Printf.Format{
                    Base.CodeUnits{UInt8, String},
                    Tuple{Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}}},
                },
            },
            String,
            Vararg{String},
        },
    )
    precompile(
        Tuple{
            Base.var"##open#463",
            Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
            typeof(Base.open),
            WannierNLQG.IO.var"#201#202"{
                NamedTuple{
                    (
                        :quantity,
                        :formula_identity,
                        :source_sha256,
                        :method,
                        :scope,
                        :terms,
                        :contribution_contract,
                        :schema,
                        :fermi_energies_ev,
                        :fermi_energies_sha256,
                        :fermi_energies_count,
                        :task_sha256,
                        :release_tree_sha256,
                        :temperature_K,
                        :model_sha256,
                        :input_identity_sha256,
                        :fermi_energy_ev,
                        :gamma_intra_ev,
                        :gamma_inter_ev,
                        :fs_kind,
                        :eta_fs_ev,
                        :photon_energies_ev,
                        :undefined_zero_frequency,
                        :dielectric_zero_frequency_status,
                        :dielectric_background,
                        :thermal_definition,
                        :input_semantics,
                        :contact_definition,
                        :spatial_dimension,
                        :cell_volume_m3,
                        :state_multiplicity,
                        :spectral_gap_tolerance_ev,
                        :model_content_sha256,
                        :mpi_size,
                        :julia_threads_per_rank,
                        :chemical_potential_count,
                        :mu_independent_geometry_evaluations,
                        :orbital_completion_evaluations,
                        :matrix_workspace_count_per_rank,
                        :vector_accumulator_shape,
                        :operator_inventory,
                        :target_contract_sha256,
                        :authoritative_hamiltonian_sha256,
                        :band_frame_contract_sha256,
                        :operator_selection_sha256,
                        :operator_qualification,
                        :scientific_content_sha256,
                        :finite_band_galerkin_qualification,
                        :execution_eligible,
                        :qualification_status,
                        :production_eligible,
                        :quality_review_recommended,
                        :qualification_reasons,
                        :verified_contracts,
                        :unverified_contracts,
                        :conflicting_contracts,
                        :input_qualification,
                    ),
                    Tuple{
                        String,
                        String,
                        String,
                        String,
                        String,
                        NTuple{4, String},
                        String,
                        String,
                        Array{Float64, 1},
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        String,
                        Float64,
                        Float64,
                        Float64,
                        String,
                        Float64,
                        Array{Float64, 1},
                        Array{Int64, 1},
                        String,
                        String,
                        String,
                        String,
                        String,
                        Int64,
                        Float64,
                        String,
                        Float64,
                        String,
                        String,
                        String,
                        Int64,
                        String,
                        String,
                        Int64,
                        Array{Int64, 1},
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
                        Bool,
                        Bool,
                        Array{String, 1},
                        Array{String, 1},
                        Array{String, 1},
                        Array{String, 1},
                        Base.Dict{String, Any},
                    },
                },
            },
            String,
            Vararg{String},
        },
    )
    precompile(
        Tuple{
            Base.var"##open#463",
            Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
            typeof(Base.open),
            WannierNLQG.IO.var"#201#202"{
                NamedTuple{
                    (
                        :quantity,
                        :formula_identity,
                        :source_sha256,
                        :method,
                        :scope,
                        :terms,
                        :contribution_contract,
                        :schema,
                        :fermi_energies_ev,
                        :fermi_energies_sha256,
                        :fermi_energies_count,
                        :task_sha256,
                        :release_tree_sha256,
                        :temperature_K,
                        :model_sha256,
                        :input_identity_sha256,
                        :fermi_energy_ev,
                        :gamma_intra_ev,
                        :gamma_inter_ev,
                        :fs_kind,
                        :eta_fs_ev,
                        :photon_energies_ev,
                        :undefined_zero_frequency,
                        :dielectric_zero_frequency_status,
                        :dielectric_background,
                        :thermal_definition,
                        :input_semantics,
                        :contact_definition,
                        :spatial_dimension,
                        :cell_volume_m3,
                        :state_multiplicity,
                        :spectral_gap_tolerance_ev,
                        :model_content_sha256,
                        :mpi_size,
                        :julia_threads_per_rank,
                        :chemical_potential_count,
                        :mu_independent_geometry_evaluations,
                        :orbital_completion_evaluations,
                        :matrix_workspace_count_per_rank,
                        :vector_accumulator_shape,
                        :operator_inventory,
                        :target_contract_sha256,
                        :authoritative_hamiltonian_sha256,
                        :band_frame_contract_sha256,
                        :operator_selection_sha256,
                        :operator_qualification,
                        :scientific_content_sha256,
                        :finite_band_galerkin_qualification,
                        :execution_eligible,
                        :qualification_status,
                        :production_eligible,
                        :quality_review_recommended,
                        :qualification_reasons,
                        :verified_contracts,
                        :unverified_contracts,
                        :conflicting_contracts,
                        :input_qualification,
                    ),
                    Tuple{
                        String,
                        String,
                        String,
                        String,
                        String,
                        NTuple{4, String},
                        String,
                        String,
                        Array{Float64, 1},
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
                        Array{Float64, 1},
                        Array{Int64, 1},
                        String,
                        String,
                        String,
                        String,
                        String,
                        Int64,
                        Float64,
                        String,
                        Float64,
                        String,
                        String,
                        String,
                        Int64,
                        Int64,
                        String,
                        Int64,
                        Array{Int64, 1},
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
                        Bool,
                        Bool,
                        Array{String, 1},
                        Array{String, 1},
                        Array{String, 1},
                        Array{String, 1},
                        Base.Dict{String, Any},
                    },
                },
            },
            String,
            Vararg{String},
        },
    )
    precompile(
        Tuple{
            Base.var"##open#463",
            Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
            typeof(Base.open),
            WannierNLQG.IO.var"#201#202"{
                NamedTuple{
                    (
                        :quantity,
                        :formula_identity,
                        :source_sha256,
                        :method,
                        :scope,
                        :terms,
                        :contribution_contract,
                        :schema,
                        :fermi_energies_ev,
                        :fermi_energies_sha256,
                        :fermi_energies_count,
                        :task_sha256,
                        :release_tree_sha256,
                        :temperature_K,
                        :model_sha256,
                        :input_identity_sha256,
                        :fermi_energy_ev,
                        :gamma_intra_ev,
                        :gamma_inter_ev,
                        :fs_kind,
                        :eta_fs_ev,
                        :photon_energies_ev,
                        :undefined_zero_frequency,
                        :dielectric_zero_frequency_status,
                        :dielectric_background,
                        :thermal_definition,
                        :input_semantics,
                        :contact_definition,
                        :spatial_dimension,
                        :cell_volume_m3,
                        :state_multiplicity,
                        :spectral_gap_tolerance_ev,
                        :model_content_sha256,
                        :mpi_size,
                        :julia_threads_per_rank,
                        :chemical_potential_count,
                        :mu_independent_geometry_evaluations,
                        :orbital_completion_evaluations,
                        :matrix_workspace_count_per_rank,
                        :vector_accumulator_shape,
                        :operator_inventory,
                        :target_contract_sha256,
                        :authoritative_hamiltonian_sha256,
                        :band_frame_contract_sha256,
                        :operator_selection_sha256,
                        :operator_qualification,
                        :scientific_content_sha256,
                        :finite_band_galerkin_qualification,
                        :execution_eligible,
                        :qualification_status,
                        :production_eligible,
                        :quality_review_recommended,
                        :qualification_reasons,
                        :verified_contracts,
                        :unverified_contracts,
                        :conflicting_contracts,
                        :input_qualification,
                    ),
                    Tuple{
                        String,
                        String,
                        String,
                        String,
                        String,
                        Tuple{String, String, String},
                        String,
                        String,
                        Array{Float64, 1},
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
                        Array{Float64, 1},
                        Array{Int64, 1},
                        String,
                        String,
                        String,
                        String,
                        String,
                        Int64,
                        Float64,
                        String,
                        Float64,
                        String,
                        String,
                        String,
                        Int64,
                        Int64,
                        Int64,
                        Int64,
                        Array{Int64, 1},
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
                        Bool,
                        Bool,
                        Array{String, 1},
                        Array{String, 1},
                        Array{String, 1},
                        Array{String, 1},
                        Base.Dict{String, Any},
                    },
                },
            },
            String,
            Vararg{String},
        },
    )
    false
    false
    precompile(
        Tuple{
            Base.var"##open#463",
            Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
            typeof(Base.open),
            WannierNLQG.Runtime.var"#831#832"{
                String,
                Array{String, 1},
                Array{WannierNLQG.Runtime.RunResult, 1},
                NamedTuple{
                    (:rank, :workers, :model_loads, :fourier_counter_unit, :worker_statistics),
                    Tuple{
                        Int64,
                        Int64,
                        Int64,
                        String,
                        Array{
                            NamedTuple{
                                (
                                    :reuse_enabled,
                                    :generations,
                                    :fourier_evaluations,
                                    :diagonalizations,
                                    :fourier_hits,
                                    :spectrum_hits,
                                    :entries,
                                    :peak_entries,
                                ),
                                Tuple{Bool, Vararg{Int64, 7}},
                            },
                            1,
                        },
                    },
                },
                NamedTuple{
                    (
                        :execution_eligible,
                        :qualification_status,
                        :production_eligible,
                        :quality_review_recommended,
                        :reasons,
                        :verified_contracts,
                        :unverified_contracts,
                        :conflicting_contracts,
                        :input_qualification,
                    ),
                    Tuple{
                        Bool,
                        String,
                        Bool,
                        Bool,
                        Array{String, 1},
                        Array{String, 1},
                        Array{String, 1},
                        Array{String, 1},
                        Base.Dict{String, Any},
                    },
                },
            },
            String,
            Vararg{String},
        },
    )
    precompile(
        Tuple{
            Base.var"##open#463",
            Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
            typeof(Base.open),
            WannierNLQG.Runtime.var"#840#850"{
                NamedTuple{
                    (
                        :id,
                        :quantity,
                        :method,
                        :calculation,
                        :physics,
                        :numerics,
                        :observable,
                        :output_root,
                    ),
                    Tuple{
                        String,
                        String,
                        String,
                        String,
                        NamedTuple{
                            (
                                :fermi_energies,
                                :fermi_energies_sha256,
                                :fermi_energy,
                                :temperature,
                                :photon_energies,
                                :gamma_intra_ev,
                                :gamma_inter_ev,
                            ),
                            Tuple{
                                Array{Float64, 1},
                                String,
                                Float64,
                                Float64,
                                Array{Float64, 1},
                                Float64,
                                Float64,
                            },
                        },
                        NamedTuple{
                            (
                                :spectral_gap_tolerance,
                                :denominator_regularization,
                                :degeneracy_threshold,
                            ),
                            Tuple{Float64, Float64, Float64},
                        },
                        NamedTuple{
                            (:kind, :component, :bands),
                            Tuple{
                                String,
                                Tuple{Int64, Int64},
                                NamedTuple{(:kind, :include_occupied_sum), Tuple{String, Bool}},
                            },
                        },
                        String,
                    },
                },
            },
            String,
            Vararg{String},
        },
    )
    precompile(
        Tuple{
            Base.var"##open#463",
            Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
            typeof(Base.open),
            WannierNLQG.Runtime.var"#840#850"{
                NamedTuple{
                    (
                        :id,
                        :quantity,
                        :method,
                        :calculation,
                        :physics,
                        :numerics,
                        :observable,
                        :output_root,
                    ),
                    Tuple{
                        String,
                        String,
                        String,
                        String,
                        NamedTuple{
                            (
                                :fermi_energies,
                                :fermi_energies_sha256,
                                :fermi_energy,
                                :temperature,
                                :photon_energies,
                                :gamma_intra_ev,
                                :gamma_inter_ev,
                            ),
                            Tuple{
                                Array{Float64, 1},
                                String,
                                Float64,
                                Float64,
                                Array{Float64, 1},
                                Float64,
                                Float64,
                            },
                        },
                        NamedTuple{
                            (
                                :spectral_gap_tolerance,
                                :denominator_regularization,
                                :degeneracy_threshold,
                            ),
                            Tuple{Float64, Float64, Float64},
                        },
                        NamedTuple{(:kind,), Tuple{String}},
                        String,
                    },
                },
            },
            String,
            Vararg{String},
        },
    )
    precompile(
        Tuple{
            Base.var"##open#463",
            Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
            typeof(Base.open),
            WannierNLQG.Runtime.var"#840#850"{
                NamedTuple{
                    (
                        :id,
                        :quantity,
                        :method,
                        :calculation,
                        :physics,
                        :numerics,
                        :observable,
                        :output_root,
                    ),
                    Tuple{
                        String,
                        String,
                        String,
                        String,
                        NamedTuple{
                            (
                                :fermi_energies,
                                :fermi_energies_sha256,
                                :temperature,
                                :photon_energies,
                                :orbital_input_semantics,
                            ),
                            Tuple{Array{Float64, 1}, String, Float64, Array{Float64, 1}, Symbol},
                        },
                        NamedTuple{
                            (
                                :spectral_gap_tolerance,
                                :denominator_regularization,
                                :degeneracy_threshold,
                            ),
                            Tuple{Float64, Float64, Float64},
                        },
                        NamedTuple{
                            (:kind, :component, :bands),
                            Tuple{
                                String,
                                Tuple{Int64},
                                NamedTuple{(:kind, :include_occupied_sum), Tuple{String, Bool}},
                            },
                        },
                        String,
                    },
                },
            },
            String,
            Vararg{String},
        },
    )
    precompile(
        Tuple{
            Base.var"##open#463",
            Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
            typeof(Base.open),
            WannierNLQG.Runtime.var"#840#850"{
                NamedTuple{
                    (
                        :id,
                        :quantity,
                        :method,
                        :calculation,
                        :physics,
                        :numerics,
                        :observable,
                        :output_root,
                    ),
                    Tuple{
                        String,
                        String,
                        String,
                        String,
                        NamedTuple{
                            (
                                :fermi_energies,
                                :fermi_energies_sha256,
                                :temperature,
                                :photon_energies,
                                :orbital_input_semantics,
                            ),
                            Tuple{Array{Float64, 1}, String, Float64, Array{Float64, 1}, Symbol},
                        },
                        NamedTuple{
                            (
                                :spectral_gap_tolerance,
                                :denominator_regularization,
                                :degeneracy_threshold,
                            ),
                            Tuple{Float64, Float64, Float64},
                        },
                        NamedTuple{(:kind,), Tuple{String}},
                        String,
                    },
                },
            },
            String,
            Vararg{String},
        },
    )
    precompile(
        Tuple{
            Base.var"##open#463",
            Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
            typeof(Base.open),
            WannierNLQG.Runtime.var"#840#850"{
                NamedTuple{
                    (
                        :id,
                        :quantity,
                        :method,
                        :calculation,
                        :physics,
                        :numerics,
                        :observable,
                        :output_root,
                    ),
                    Tuple{
                        String,
                        String,
                        String,
                        String,
                        NamedTuple{(:fermi_energy,), Tuple{Float64}},
                        NamedTuple{(:hermiticity_tolerance,), Tuple{Float64}},
                        NamedTuple{(:kind,), Tuple{String}},
                        String,
                    },
                },
            },
            String,
            Vararg{String},
        },
    )
    precompile(
        Tuple{
            Base.var"##open#463",
            Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
            typeof(Base.open),
            WannierNLQG.Runtime.var"#840#850"{
                NamedTuple{
                    (
                        :id,
                        :quantity,
                        :method,
                        :calculation,
                        :physics,
                        :numerics,
                        :observable,
                        :output_root,
                    ),
                    Tuple{
                        String,
                        String,
                        String,
                        String,
                        NamedTuple{
                            (:photon_energies, :fermi_energy, :temperature),
                            Tuple{Array{Float64, 1}, Float64, Float64},
                        },
                        NamedTuple{
                            (
                                :denominator_regularization,
                                :broadening,
                                :broadening_type,
                                :transition_window_factor,
                                :band_window_size,
                            ),
                            Tuple{Float64, Float64, String, Float64, Int64},
                        },
                        NamedTuple{(:kind,), Tuple{String}},
                        String,
                    },
                },
            },
            String,
            Vararg{String},
        },
    )
    precompile(
        Tuple{
            Base.var"#274#275"{
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
                    var"#s373",
                } where var"#s373" <: Tuple{
                    WannierNLQG.Core.TightBindingModel{
                        H,
                        P,
                    } where {
                        P <: AbstractArray{Base.Complex{Float64}, 4},
                    } where H <: AbstractArray{Base.Complex{Float64}, 3},
                    Union{
                        Nothing,
                        WannierNLQG.MatrixElements.SpinRealSpaceData{
                            S,
                        } where S <: AbstractArray{Base.Complex{Float64}, 4},
                    },
                    Union{
                        Nothing,
                        WannierNLQG.MatrixElements.SpinVelocityRealSpaceData{
                            S,
                            H,
                            R,
                            HR,
                        } where {HR} where {R} where {H} where S,
                    },
                    Union{
                        Nothing,
                        WannierNLQG.MatrixElements.OrbitalRealSpaceSources{
                            B,
                            F,
                            C,
                        } where {C} where {F} where B,
                    },
                    Union{
                        Nothing,
                        WannierNLQG.MatrixElements.DerivativeOverlapRealSpaceData{
                            D,
                        } where D <: AbstractArray{Base.Complex{Float64}, 5},
                    },
                    Any,
                    Symbol,
                    Union{Nothing, String},
                    Any,
                    WannierNLQG.Runtime.RuntimeReplicaSummary,
                },
            },
            Int64,
        },
    )
    precompile(
        Tuple{
            Type{
                Base.Dict{
                    WannierNLQG.MatrixElements.KPointOffset,
                    WannierNLQG.MatrixElements.KPointMatrixData{
                        WannierNLQG.MatrixElements.HamiltonianMatrixData{
                            Array{Float64, 2},
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 4},
                            Array{Base.Complex{Float64}, 3},
                        },
                        WannierNLQG.MatrixElements.PositionMatrixData{
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 4},
                            Array{Base.Complex{Float64}, 4},
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
                        Nothing,
                        Nothing,
                    },
                },
            },
        },
    )
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            WannierNLQG.IO.var"#172#176"{
                Printf.Format{
                    Base.CodeUnits{UInt8, String},
                    Tuple{Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}}},
                },
            },
            Array{Float64, 1},
        },
    )
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            WannierNLQG.Runtime.var"#153#155",
            Tuple{Int64, Int64},
        },
    )
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            WannierNLQG.Runtime.var"#153#155",
            Tuple{Int64},
        },
    )
    false
    false
    false
    false
    false
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            WannierNLQG.Runtime.var"#466#469"{NTuple{4, Int64}},
            Base.UnitRange{Int64},
        },
    )
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            WannierNLQG.Runtime.var"#541#546",
            Base.UnitRange{Int64},
        },
    )
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            WannierNLQG.Runtime.var"#543#548",
            Base.UnitRange{Int64},
        },
    )
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            WannierNLQG.Runtime.var"#608#618",
            Base.UnitRange{Int64},
        },
    )
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            WannierNLQG.Runtime.var"#610#619",
            Base.UnitRange{Int64},
        },
    )
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            WannierNLQG.Runtime.var"#611#621"{
                NTuple{4, Symbol},
                Array{Float64, 1},
                Array{Tuple{Int64, Int64}, 1},
                Int64,
                Bool,
            },
            Base.UnitRange{Int64},
        },
    )
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            WannierNLQG.Runtime.var"#611#621"{
                Tuple{Symbol, Symbol, Symbol},
                Array{Float64, 1},
                Array{Tuple{Int64}, 1},
                Int64,
                Bool,
            },
            Base.UnitRange{Int64},
        },
    )
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            WannierNLQG.Runtime.var"#638#661",
            Array{
                WannierNLQG.MatrixElements.KPointBatchWorkspace{
                    WannierNLQG.FIRST_USE_WORKSPACE_TYPES[2],
                    WannierNLQG.MatrixElements.KPointMatrixData{
                        WannierNLQG.MatrixElements.HamiltonianMatrixData{
                            Array{Float64, 2},
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 4},
                            Array{Base.Complex{Float64}, 3},
                        },
                        WannierNLQG.MatrixElements.PositionMatrixData{
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 4},
                            Array{Base.Complex{Float64}, 4},
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
                        Nothing,
                        Nothing,
                    },
                },
                1,
            },
        },
    )
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            WannierNLQG.Runtime.var"#639#662",
            Array{
                WannierNLQG.MatrixElements.KPointBatchWorkspace{
                    WannierNLQG.FIRST_USE_WORKSPACE_TYPES[2],
                    WannierNLQG.MatrixElements.KPointMatrixData{
                        WannierNLQG.MatrixElements.HamiltonianMatrixData{
                            Array{Float64, 2},
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 4},
                            Array{Base.Complex{Float64}, 3},
                        },
                        WannierNLQG.MatrixElements.PositionMatrixData{
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 4},
                            Array{Base.Complex{Float64}, 4},
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
                        Nothing,
                        Nothing,
                    },
                },
                1,
            },
        },
    )
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            WannierNLQG.Runtime.var"#640#663"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                WannierNLQG.Runtime.RunContext,
                Int64,
                Int64,
                Nothing,
            },
            Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1},
        },
    )
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            WannierNLQG.Runtime.var"#641#664"{
                Array{
                    WannierNLQG.MatrixElements.KPointMatrixData{
                        WannierNLQG.MatrixElements.HamiltonianMatrixData{
                            Array{Float64, 2},
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 4},
                            Array{Base.Complex{Float64}, 3},
                        },
                        WannierNLQG.MatrixElements.PositionMatrixData{
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 4},
                            Array{Base.Complex{Float64}, 4},
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
                        Nothing,
                        Nothing,
                    },
                    1,
                },
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[2], 1},
                Int64,
                Int64,
                Int64,
            },
            Base.UnitRange{Int64},
        },
    )
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            WannierNLQG.Runtime.var"#643#666"{
                Array{
                    WannierNLQG.MatrixElements.KPointMatrixData{
                        WannierNLQG.MatrixElements.HamiltonianMatrixData{
                            Array{Float64, 2},
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 4},
                            Array{Base.Complex{Float64}, 3},
                        },
                        WannierNLQG.MatrixElements.PositionMatrixData{
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 4},
                            Array{Base.Complex{Float64}, 4},
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
                        Nothing,
                        Nothing,
                    },
                    1,
                },
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[2], 1},
                Int64,
                Int64,
                Int64,
                Int64,
            },
            Base.UnitRange{Int64},
        },
    )
    false
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            WannierNLQG.Runtime.var"#756#757",
            Base.UnitRange{Int64},
        },
    )
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            WannierNLQG.Runtime.var"#834#844"{WannierNLQG.Runtime.RunContext},
            Array{WannierNLQG.Runtime.RunContext, 1},
        },
    )
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            WannierNLQG.Runtime.var"#839#849",
            Array{WannierNLQG.Runtime.BandStructureBundlePlan, 1},
        },
    )
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            WannierNLQG.Runtime.var"#839#849",
            Array{WannierNLQG.Runtime.IntegralBundlePlan, 1},
        },
    )
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            WannierNLQG.Runtime.var"#839#849",
            Array{WannierNLQG.Runtime.KSliceBundlePlan, 1},
        },
    )
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            typeof(Base.identity),
            Base.Iterators.Filter{
                WannierNLQG.Runtime.var"#803#807"{Int64, Int64},
                Base.UnitRange{Int64},
            },
        },
    )
    false
    precompile(
        Tuple{
            Type{Base.Iterators.Filter{F, I} where {I} where F},
            WannierNLQG.Runtime.var"#803#807"{Int64, Int64},
            Base.UnitRange{Int64},
        },
    )
    false
    precompile(
        Tuple{
            Type{Base.Iterators.Flatten{I} where I},
            Base.Generator{Base.UnitRange{Int64}, WannierNLQG.Runtime.var"#541#546"},
        },
    )
    precompile(
        Tuple{
            Type{Base.Iterators.Flatten{I} where I},
            Base.Generator{Base.UnitRange{Int64}, WannierNLQG.Runtime.var"#543#548"},
        },
    )
    precompile(
        Tuple{
            Type{Base.Iterators.Flatten{I} where I},
            Base.Generator{Base.UnitRange{Int64}, WannierNLQG.Runtime.var"#610#619"},
        },
    )
    precompile(
        Tuple{
            Type{Base.Iterators.Flatten{I} where I},
            Base.Generator{Base.UnitRange{Int64}, WannierNLQG.Runtime.var"#756#757"},
        },
    )
    precompile(
        Tuple{
            Type{Base.Iterators.Zip{Is} where Is <: Tuple},
            Tuple{
                Array{WannierNLQG.Runtime.EffectiveTaskConfig, 1},
                Array{WannierNLQG.Runtime.RunContext, 1},
                Array{Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1}, 1},
                Array{WannierNLQG.Runtime.BandStructureBundlePlan, 1},
            },
        },
    )
    precompile(
        Tuple{
            Type{Base.Iterators.Zip{Is} where Is <: Tuple},
            Tuple{
                Array{WannierNLQG.Runtime.EffectiveTaskConfig, 1},
                Array{WannierNLQG.Runtime.RunContext, 1},
                Array{Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1}, 1},
                Array{WannierNLQG.Runtime.IntegralBundlePlan, 1},
            },
        },
    )
    precompile(
        Tuple{
            Type{Base.Iterators.Zip{Is} where Is <: Tuple},
            Tuple{
                Array{WannierNLQG.Runtime.EffectiveTaskConfig, 1},
                Array{WannierNLQG.Runtime.RunContext, 1},
                Array{Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1}, 1},
                Array{WannierNLQG.Runtime.KSliceBundlePlan, 1},
            },
        },
    )
    precompile(
        Tuple{
            Type{Base.Iterators.Zip{Is} where Is <: Tuple},
            Tuple{
                Array{
                    WannierNLQG.Runtime.PreparedResponseTask{E, F, C} where {C} where {F} where E,
                    1,
                },
                Array{String, 1},
                Array{WannierNLQG.Runtime.EffectiveTaskConfig, 1},
                Array{WannierNLQG.Runtime.RunContext, 1},
                Array{Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1}, 1},
            },
        },
    )
    false
    false
    precompile(Tuple{Type{Int64}, WannierNLQG.Core.RealSpaceOperatorKind})
    false
    precompile(
        Tuple{
            Type{NamedTuple{(:id, :quantity, :physics, :numerics), T} where T <: Tuple},
            Tuple{
                String,
                String,
                WannierNLQG.Runtime.BandParameters,
                WannierNLQG.Runtime.BandNumerics,
            },
        },
    )
    false
    precompile(
        Tuple{
            Type{
                NamedTuple{
                    (:source_gauge_required, :wannier_center_convention),
                    T,
                } where T <: Tuple,
            },
            Tuple{Bool, WannierNLQG.Core.WannierCenterConvention},
        },
    )
    precompile(
        Tuple{
            Type{
                NamedTuple{
                    (
                        :value,
                        :time,
                        :bytes,
                        :gctime,
                        :gcstats,
                        :lock_conflicts,
                        :compile_time,
                        :recompile_time,
                    ),
                    T,
                } where T <: Tuple,
            },
            Tuple{
                WannierNLQG.Runtime.RunResult,
                Float64,
                Int64,
                Float64,
                Base.GC_Diff,
                Int64,
                Float64,
                Float64,
            },
        },
    )
    precompile(
        Tuple{
            Type{WannierNLQG.IO.PackedCartesianOperator{1, 4, Array{Base.Complex{Float64}, 3}}},
            Array{Array{Base.Complex{Float64}, 3}, 1},
            Base.BitArray{1},
            NTuple{4, Int64},
        },
    )
    precompile(
        Tuple{Type{WannierNLQG.MatrixElements.KPointOffset}, Tuple{Int64, Int64, Int64}, Int64},
    )
    false
    precompile(
        Tuple{
            Type{WannierNLQG.MatrixElements.SpinVelocityRealSpaceDiagnostics},
            Vararg{Float64, 4},
        },
    )
    precompile(
        Tuple{
            Type{WannierNLQG.Runtime.FusedBundleRunResult},
            Array{String, 1},
            Array{String, 1},
            Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
            NamedTuple{
                (
                    :backend,
                    :NKdiv,
                    :NKFFT,
                    :factor_source,
                    :estimated_memory_bytes,
                    :memory_limit_bytes,
                    :path_kpoint_count,
                    :mpi_size,
                    :julia_threads,
                ),
                Tuple{Symbol, Nothing, Nothing, Symbol, Vararg{Int64, 5}},
            },
            NamedTuple{(), Tuple{}},
            NamedTuple{
                (
                    :schema,
                    :total_kpoints,
                    :node_count,
                    :segment_count,
                    :E_ref_eV,
                    :energy_unit,
                    :distance_unit,
                    :energy_convention,
                    :fourier_phase,
                    :reciprocal_lattice,
                    :maximum_hermiticity_residual,
                    :hermiticity_tolerance,
                    :requested_replica_policy,
                    :effective_replica_policy,
                    :replica_source,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :replica_mapping_sha256,
                    :replica_mapping_digest_scheme,
                    :wsvec_file,
                    :wsvec_sha256,
                    :input_minimum_distance_materialized,
                    :output_minimum_distance_materialized,
                    :replica_transformed_this_run,
                    :input_num_r_vectors,
                    :effective_num_r_vectors,
                    :lattice_A,
                    :reciprocal_lattice_A_inverse,
                    :r_vector_support_minimum,
                    :r_vector_support_maximum,
                    :r_vector_support_sha256,
                    :degeneracy_count,
                    :degeneracy_minimum,
                    :degeneracy_maximum,
                    :degeneracy_sum,
                    :degeneracy_sha256,
                    :wannier90_degeneracy_applied,
                    :model_num_orbitals,
                    :qualification,
                    :production_eligible,
                    :qualification_note,
                    :manifest_schema,
                    :manifest_scientific_sha256,
                    :manifest_geometry_sha256,
                    :manifest_file_sha256,
                    :manifest_paired_tb_sha256,
                    :manifest_hamiltonian_component_sha256,
                    :manifest_quality_review_recommended,
                    :manifest_physics_qualification,
                    :manifest_tb_usability,
                    :manifest_final_physics_qualification,
                    :manifest_final_production_eligible,
                    :kpath_json,
                ),
                Tuple{
                    String,
                    Int64,
                    Int64,
                    Int64,
                    Float64,
                    String,
                    String,
                    String,
                    String,
                    String,
                    Float64,
                    Float64,
                    Symbol,
                    Symbol,
                    Symbol,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    String,
                    String,
                    String,
                    String,
                    Bool,
                    Bool,
                    Bool,
                    Int64,
                    Int64,
                    Array{Float64, 2},
                    Array{Float64, 2},
                    Tuple{Int64, Int64, Int64},
                    Tuple{Int64, Int64, Int64},
                    String,
                    Int64,
                    Int64,
                    Int64,
                    Int64,
                    String,
                    Bool,
                    Int64,
                    String,
                    Bool,
                    String,
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
                    String,
                },
            },
            NamedTuple{
                (
                    :schema,
                    :requested_policy,
                    :effective_policy,
                    :source,
                    :mapping_sha256,
                    :mapping_digest_scheme,
                    :wsvec_file,
                    :wsvec_sha256,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :input_minimum_distance_materialized,
                    :output_minimum_distance_materialized,
                    :replica_transformed_this_run,
                    :input_num_r_vectors,
                    :effective_num_r_vectors,
                    :scalar_degeneracy_applied,
                    :pair_degeneracy_applied,
                ),
                Tuple{
                    String,
                    Symbol,
                    Symbol,
                    Symbol,
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    Bool,
                    Bool,
                    Bool,
                    Int64,
                    Int64,
                    Bool,
                    Bool,
                },
            },
            WannierNLQG.Runtime.ResponseQualificationResult,
        },
    )
    false
    precompile(
        Tuple{
            Type{WannierNLQG.Runtime.IntegralTaskAccumulator{N} where N},
            WannierNLQG.Runtime.NormalizedTaskSpec,
            Array{String, 1},
            Array{Array{Base.Complex{Float64}, 4}, 1},
            Array{Base.Complex{Float64}, 4},
            Array{Base.Complex{Float64}, 4},
            Vararg{Nothing, 5},
        },
    )
    precompile(
        Tuple{
            Type{WannierNLQG.Runtime.ModelInput},
            String,
            Nothing,
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
        },
    )
    false
    precompile(
        Tuple{
            Type{WannierNLQG.Runtime.PreparedResponseTask{E, F, C} where {C} where {F} where E},
            Array{Tuple{Int64, Int64, Int64}, 1},
            WannierNLQG.Runtime.var"#execute_point!#623"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                Bool,
                Base.Val{:linear_optical_response},
                WannierNLQG.MatrixElements.OrbitalCompletion,
                Array{Array{Float64, 1}, 1},
                Array{Array{Base.Complex{Float64}, 4}, 1},
                NTuple{4, Symbol},
                Array{Float64, 1},
                Array{Tuple{Int64, Int64}, 1},
                WannierNLQG.Runtime.FourierExecutionPlan,
                WannierNLQG.Core.IntegralKGrid,
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Bool,
                Bool,
            },
            WannierNLQG.Runtime.var"#finish!#624"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                WannierNLQG.Runtime.RunContext,
                Array{Array{Base.Complex{Float64}, 4}, 1},
                NTuple{4, Symbol},
                Array{Tuple{Int64, Int64}, 1},
                WannierNLQG.Runtime.FourierExecutionPlan,
                Int64,
                WannierNLQG.Core.IntegralKGrid,
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                Int64,
                Nothing,
                WannierNLQG.Runtime.ResponseQualificationResult,
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Bool,
                Bool,
                WannierNLQG.Runtime.NormalizedTaskSpec,
            },
            WannierNLQG.Runtime.var"#cleanup!#625"{
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
            },
            Nothing,
        },
    )
    precompile(
        Tuple{
            Type{WannierNLQG.Runtime.PreparedResponseTask{E, F, C} where {C} where {F} where E},
            Array{Tuple{Int64, Int64, Int64}, 1},
            WannierNLQG.Runtime.var"#execute_point!#623"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                Bool,
                Base.Val{:linear_optical_response},
                WannierNLQG.MatrixElements.OrbitalCompletion,
                Array{Array{Float64, 1}, 1},
                Array{Array{Base.Complex{Float64}, 4}, 1},
                NTuple{4, Symbol},
                Array{Float64, 1},
                Array{Tuple{Int64, Int64}, 1},
                WannierNLQG.Runtime.FourierExecutionPlan,
                WannierNLQG.Core.KSliceGrid2D,
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Bool,
                Bool,
            },
            WannierNLQG.Runtime.var"#finish!#624"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                WannierNLQG.Runtime.RunContext,
                Array{Array{Base.Complex{Float64}, 4}, 1},
                NTuple{4, Symbol},
                Array{Tuple{Int64, Int64}, 1},
                WannierNLQG.Runtime.FourierExecutionPlan,
                Int64,
                WannierNLQG.Core.KSliceGrid2D,
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                Int64,
                Nothing,
                WannierNLQG.Runtime.ResponseQualificationResult,
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Bool,
                Bool,
                WannierNLQG.Runtime.NormalizedTaskSpec,
            },
            WannierNLQG.Runtime.var"#cleanup!#625"{
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
            },
            Nothing,
        },
    )
    precompile(
        Tuple{
            Type{WannierNLQG.Runtime.PreparedResponseTask{E, F, C} where {C} where {F} where E},
            Array{Tuple{Int64, Int64, Int64}, 1},
            WannierNLQG.Runtime.var"#execute_point!#623"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                Bool,
                Base.Val{:linear_transport},
                WannierNLQG.MatrixElements.OrbitalCompletion,
                Array{Array{Float64, 1}, 1},
                Array{Array{Base.Complex{Float64}, 4}, 1},
                NTuple{4, Symbol},
                Array{Float64, 1},
                Array{Tuple{Int64, Int64}, 1},
                WannierNLQG.Runtime.FourierExecutionPlan,
                WannierNLQG.Core.IntegralKGrid,
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Bool,
                Bool,
            },
            WannierNLQG.Runtime.var"#finish!#624"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                WannierNLQG.Runtime.RunContext,
                Array{Array{Base.Complex{Float64}, 4}, 1},
                NTuple{4, Symbol},
                Array{Tuple{Int64, Int64}, 1},
                WannierNLQG.Runtime.FourierExecutionPlan,
                Int64,
                WannierNLQG.Core.IntegralKGrid,
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                Int64,
                Nothing,
                WannierNLQG.Runtime.ResponseQualificationResult,
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Bool,
                Bool,
                WannierNLQG.Runtime.NormalizedTaskSpec,
            },
            WannierNLQG.Runtime.var"#cleanup!#625"{
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
            },
            Nothing,
        },
    )
    precompile(
        Tuple{
            Type{WannierNLQG.Runtime.PreparedResponseTask{E, F, C} where {C} where {F} where E},
            Array{Tuple{Int64, Int64, Int64}, 1},
            WannierNLQG.Runtime.var"#execute_point!#623"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                Bool,
                Base.Val{:linear_transport},
                WannierNLQG.MatrixElements.OrbitalCompletion,
                Array{Array{Float64, 1}, 1},
                Array{Array{Base.Complex{Float64}, 4}, 1},
                NTuple{4, Symbol},
                Array{Float64, 1},
                Array{Tuple{Int64, Int64}, 1},
                WannierNLQG.Runtime.FourierExecutionPlan,
                WannierNLQG.Core.KSliceGrid2D,
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Bool,
                Bool,
            },
            WannierNLQG.Runtime.var"#finish!#624"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                WannierNLQG.Runtime.RunContext,
                Array{Array{Base.Complex{Float64}, 4}, 1},
                NTuple{4, Symbol},
                Array{Tuple{Int64, Int64}, 1},
                WannierNLQG.Runtime.FourierExecutionPlan,
                Int64,
                WannierNLQG.Core.KSliceGrid2D,
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                Int64,
                Nothing,
                WannierNLQG.Runtime.ResponseQualificationResult,
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Bool,
                Bool,
                WannierNLQG.Runtime.NormalizedTaskSpec,
            },
            WannierNLQG.Runtime.var"#cleanup!#625"{
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
            },
            Nothing,
        },
    )
    precompile(
        Tuple{
            Type{WannierNLQG.Runtime.PreparedResponseTask{E, F, C} where {C} where {F} where E},
            Array{Tuple{Int64, Int64, Int64}, 1},
            WannierNLQG.Runtime.var"#execute_point!#623"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                Bool,
                Base.Val{:orbital_magnetization},
                WannierNLQG.MatrixElements.OrbitalCompletion,
                Array{Array{Float64, 1}, 1},
                Array{Array{Base.Complex{Float64}, 4}, 1},
                Tuple{Symbol, Symbol, Symbol},
                Array{Float64, 1},
                Array{Tuple{Int64}, 1},
                WannierNLQG.Runtime.FourierExecutionPlan,
                WannierNLQG.Core.IntegralKGrid,
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Bool,
                Bool,
            },
            WannierNLQG.Runtime.var"#finish!#624"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                WannierNLQG.Runtime.RunContext,
                Array{Array{Base.Complex{Float64}, 4}, 1},
                Tuple{Symbol, Symbol, Symbol},
                Array{Tuple{Int64}, 1},
                WannierNLQG.Runtime.FourierExecutionPlan,
                Int64,
                WannierNLQG.Core.IntegralKGrid,
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                Int64,
                Nothing,
                WannierNLQG.Runtime.ResponseQualificationResult,
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Bool,
                Bool,
                WannierNLQG.Runtime.NormalizedTaskSpec,
            },
            WannierNLQG.Runtime.var"#cleanup!#625"{
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
            },
            Nothing,
        },
    )
    precompile(
        Tuple{
            Type{WannierNLQG.Runtime.PreparedResponseTask{E, F, C} where {C} where {F} where E},
            Array{Tuple{Int64, Int64, Int64}, 1},
            WannierNLQG.Runtime.var"#execute_point!#623"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                Bool,
                Base.Val{:orbital_magnetization},
                WannierNLQG.MatrixElements.OrbitalCompletion,
                Array{Array{Float64, 1}, 1},
                Array{Array{Base.Complex{Float64}, 4}, 1},
                Tuple{Symbol, Symbol, Symbol},
                Array{Float64, 1},
                Array{Tuple{Int64}, 1},
                WannierNLQG.Runtime.FourierExecutionPlan,
                WannierNLQG.Core.KSliceGrid2D,
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Bool,
                Bool,
            },
            WannierNLQG.Runtime.var"#finish!#624"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                WannierNLQG.Runtime.RunContext,
                Array{Array{Base.Complex{Float64}, 4}, 1},
                Tuple{Symbol, Symbol, Symbol},
                Array{Tuple{Int64}, 1},
                WannierNLQG.Runtime.FourierExecutionPlan,
                Int64,
                WannierNLQG.Core.KSliceGrid2D,
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                Int64,
                Nothing,
                WannierNLQG.Runtime.ResponseQualificationResult,
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Bool,
                Bool,
                WannierNLQG.Runtime.NormalizedTaskSpec,
            },
            WannierNLQG.Runtime.var"#cleanup!#625"{
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
            },
            Nothing,
        },
    )
    false
    precompile(
        Tuple{
            Type{WannierNLQG.Runtime.RunContext},
            Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1},
            String,
            String,
            String,
            Symbol,
            Nothing,
            Nothing,
            Int64,
            WannierNLQG.Runtime.OperatorDemandPlan,
            String,
            String,
            String,
            String,
            Nothing,
        },
    )
    precompile(
        Tuple{
            Type{WannierNLQG.Runtime.RunResult},
            Array{Tuple{String, String, String}, 1},
            Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1},
            String,
            Array{String, 1},
            String,
            String,
            String,
            Array{String, 1},
            Array{WannierNLQG.Runtime.RunResult, 1},
            NamedTuple{(), Tuple{}},
            WannierNLQG.Runtime.ResponseQualificationResult,
        },
    )
    precompile(
        Tuple{
            Type{WannierNLQG.Runtime.RunResult},
            Array{Tuple{String, String, String}, 1},
            Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1},
            String,
            Array{String, 1},
            String,
            String,
            String,
            Array{String, 1},
            Array{WannierNLQG.Runtime.RunResult, 1},
            NamedTuple{
                (:rank, :workers, :model_loads, :fourier_counter_unit, :worker_statistics),
                Tuple{
                    Int64,
                    Int64,
                    Int64,
                    String,
                    Array{
                        NamedTuple{
                            (
                                :reuse_enabled,
                                :generations,
                                :fourier_evaluations,
                                :diagonalizations,
                                :fourier_hits,
                                :spectrum_hits,
                                :entries,
                                :peak_entries,
                            ),
                            Tuple{Bool, Vararg{Int64, 7}},
                        },
                        1,
                    },
                },
            },
            WannierNLQG.Runtime.ResponseQualificationResult,
        },
    )
    precompile(
        Tuple{
            Type{WannierNLQG.Runtime.RunResult},
            Array{Tuple{String, String, String}, 1},
            Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1},
            String,
            Array{String, 1},
            String,
            String,
            String,
            WannierNLQG.Runtime.ResponseQualificationResult,
        },
    )
    false
    precompile(
        Tuple{
            Type{WannierNLQG.Runtime.TaskSpec},
            String,
            String,
            Nothing,
            WannierNLQG.Runtime.BandParameters,
            WannierNLQG.Runtime.BandNumerics,
            Nothing,
        },
    )
    precompile(
        Tuple{WannierNLQG.Runtime.var"##AllBands#145", Bool, Type{WannierNLQG.Runtime.AllBands}},
    )
    false
    false
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"##ModelInput#113",
            String,
            Nothing,
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
            Type{WannierNLQG.Runtime.ModelInput},
        },
    )
    false
    false
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"##bundle_mpi_root_call#179",
            Int64,
            MPI.Comm,
            typeof(WannierNLQG.Runtime.bundle_mpi_root_call),
            WannierNLQG.Runtime.var"#392#399"{String},
        },
    )
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"##bundle_mpi_root_call#179",
            Int64,
            MPI.Comm,
            typeof(WannierNLQG.Runtime.bundle_mpi_root_call),
            WannierNLQG.Runtime.var"#393#400"{String},
        },
    )
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"##bundle_mpi_root_call#179",
            Int64,
            MPI.Comm,
            typeof(WannierNLQG.Runtime.bundle_mpi_root_call),
            WannierNLQG.Runtime.var"#836#846"{String, String},
        },
    )
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"##bundle_mpi_root_call#179",
            Int64,
            Nothing,
            typeof(WannierNLQG.Runtime.bundle_mpi_root_call),
            WannierNLQG.Runtime.var"#392#399"{String},
        },
    )
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"##bundle_mpi_root_call#179",
            Int64,
            Nothing,
            typeof(WannierNLQG.Runtime.bundle_mpi_root_call),
            WannierNLQG.Runtime.var"#393#400"{String},
        },
    )
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"##bundle_mpi_root_call#179",
            Int64,
            Nothing,
            typeof(WannierNLQG.Runtime.bundle_mpi_root_call),
            WannierNLQG.Runtime.var"#813#816"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                String,
                String,
                Array{Float64, 2},
                WannierNLQG.Runtime.KPathPlan,
            },
        },
    )
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"##bundle_mpi_root_call#179",
            Int64,
            Nothing,
            typeof(WannierNLQG.Runtime.bundle_mpi_root_call),
            WannierNLQG.Runtime.var"#836#846"{String, String},
        },
    )
    precompile(Tuple{WannierNLQG.Runtime.var"#173#174"{Symbol}})
    precompile(Tuple{WannierNLQG.Runtime.var"#183#184", Tuple{Symbol, Array{Float64, 1}}})
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"#183#184",
            Tuple{
                Symbol,
                Array{
                    NamedTuple{
                        (
                            :label,
                            :fractional_coordinates,
                            :point_index_one_based,
                            :cumulative_distance_A_inverse,
                        ),
                        Tuple{String, Array{Float64, 1}, Int64, Float64},
                    },
                    1,
                },
            },
        },
    )
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"#183#184",
            Tuple{
                Symbol,
                Array{
                    NamedTuple{
                        (
                            :segment_index_one_based,
                            :start_node_index_one_based,
                            :end_node_index_one_based,
                            :start_point_index_one_based,
                            :end_point_index_one_based,
                            :kpoints_including_endpoints,
                        ),
                        NTuple{6, Int64},
                    },
                    1,
                },
            },
        },
    )
    false
    false
    precompile(Tuple{WannierNLQG.Runtime.var"#183#184", Tuple{Symbol, Bool}})
    precompile(Tuple{WannierNLQG.Runtime.var"#183#184", Tuple{Symbol, Float64}})
    precompile(Tuple{WannierNLQG.Runtime.var"#183#184", Tuple{Symbol, Int64}})
    false
    false
    false
    false
    false
    false
    precompile(Tuple{WannierNLQG.Runtime.var"#514#526", Nothing})
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"#561#567",
            WannierNLQG.Runtime.PreparedResponseTask{
                WannierNLQG.Runtime.var"#execute_point!#623"{
                    WannierNLQG.Runtime.EffectiveTaskConfig,
                    Bool,
                    Base.Val{:linear_optical_response},
                    WannierNLQG.MatrixElements.OrbitalCompletion,
                    Array{Array{Float64, 1}, 1},
                    Array{Array{Base.Complex{Float64}, 4}, 1},
                    NTuple{4, Symbol},
                    Array{Float64, 1},
                    Array{Tuple{Int64, Int64}, 1},
                    WannierNLQG.Runtime.FourierExecutionPlan,
                    WannierNLQG.Core.IntegralKGrid,
                    Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                    WannierNLQG.Core.TightBindingModel{
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                    },
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                    Bool,
                    Bool,
                },
                WannierNLQG.Runtime.var"#finish!#624"{
                    WannierNLQG.Runtime.EffectiveTaskConfig,
                    WannierNLQG.Runtime.RunContext,
                    Array{Array{Base.Complex{Float64}, 4}, 1},
                    NTuple{4, Symbol},
                    Array{Tuple{Int64, Int64}, 1},
                    WannierNLQG.Runtime.FourierExecutionPlan,
                    Int64,
                    WannierNLQG.Core.IntegralKGrid,
                    Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                    Int64,
                    Nothing,
                    WannierNLQG.Runtime.ResponseQualificationResult,
                    WannierNLQG.Core.TightBindingModel{
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                    },
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                    Bool,
                    Bool,
                    WannierNLQG.Runtime.NormalizedTaskSpec,
                },
                WannierNLQG.Runtime.var"#cleanup!#625"{
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                    Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                },
            },
        },
    )
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"#561#567",
            WannierNLQG.Runtime.PreparedResponseTask{
                WannierNLQG.Runtime.var"#execute_point!#623"{
                    WannierNLQG.Runtime.EffectiveTaskConfig,
                    Bool,
                    Base.Val{:linear_optical_response},
                    WannierNLQG.MatrixElements.OrbitalCompletion,
                    Array{Array{Float64, 1}, 1},
                    Array{Array{Base.Complex{Float64}, 4}, 1},
                    NTuple{4, Symbol},
                    Array{Float64, 1},
                    Array{Tuple{Int64, Int64}, 1},
                    WannierNLQG.Runtime.FourierExecutionPlan,
                    WannierNLQG.Core.KSliceGrid2D,
                    Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                    WannierNLQG.Core.TightBindingModel{
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                    },
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                    Bool,
                    Bool,
                },
                WannierNLQG.Runtime.var"#finish!#624"{
                    WannierNLQG.Runtime.EffectiveTaskConfig,
                    WannierNLQG.Runtime.RunContext,
                    Array{Array{Base.Complex{Float64}, 4}, 1},
                    NTuple{4, Symbol},
                    Array{Tuple{Int64, Int64}, 1},
                    WannierNLQG.Runtime.FourierExecutionPlan,
                    Int64,
                    WannierNLQG.Core.KSliceGrid2D,
                    Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                    Int64,
                    Nothing,
                    WannierNLQG.Runtime.ResponseQualificationResult,
                    WannierNLQG.Core.TightBindingModel{
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                    },
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                    Bool,
                    Bool,
                    WannierNLQG.Runtime.NormalizedTaskSpec,
                },
                WannierNLQG.Runtime.var"#cleanup!#625"{
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                    Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                },
            },
        },
    )
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"#561#567",
            WannierNLQG.Runtime.PreparedResponseTask{
                WannierNLQG.Runtime.var"#execute_point!#623"{
                    WannierNLQG.Runtime.EffectiveTaskConfig,
                    Bool,
                    Base.Val{:linear_transport},
                    WannierNLQG.MatrixElements.OrbitalCompletion,
                    Array{Array{Float64, 1}, 1},
                    Array{Array{Base.Complex{Float64}, 4}, 1},
                    NTuple{4, Symbol},
                    Array{Float64, 1},
                    Array{Tuple{Int64, Int64}, 1},
                    WannierNLQG.Runtime.FourierExecutionPlan,
                    WannierNLQG.Core.IntegralKGrid,
                    Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                    WannierNLQG.Core.TightBindingModel{
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                    },
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                    Bool,
                    Bool,
                },
                WannierNLQG.Runtime.var"#finish!#624"{
                    WannierNLQG.Runtime.EffectiveTaskConfig,
                    WannierNLQG.Runtime.RunContext,
                    Array{Array{Base.Complex{Float64}, 4}, 1},
                    NTuple{4, Symbol},
                    Array{Tuple{Int64, Int64}, 1},
                    WannierNLQG.Runtime.FourierExecutionPlan,
                    Int64,
                    WannierNLQG.Core.IntegralKGrid,
                    Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                    Int64,
                    Nothing,
                    WannierNLQG.Runtime.ResponseQualificationResult,
                    WannierNLQG.Core.TightBindingModel{
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                    },
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                    Bool,
                    Bool,
                    WannierNLQG.Runtime.NormalizedTaskSpec,
                },
                WannierNLQG.Runtime.var"#cleanup!#625"{
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                    Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                },
            },
        },
    )
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"#561#567",
            WannierNLQG.Runtime.PreparedResponseTask{
                WannierNLQG.Runtime.var"#execute_point!#623"{
                    WannierNLQG.Runtime.EffectiveTaskConfig,
                    Bool,
                    Base.Val{:linear_transport},
                    WannierNLQG.MatrixElements.OrbitalCompletion,
                    Array{Array{Float64, 1}, 1},
                    Array{Array{Base.Complex{Float64}, 4}, 1},
                    NTuple{4, Symbol},
                    Array{Float64, 1},
                    Array{Tuple{Int64, Int64}, 1},
                    WannierNLQG.Runtime.FourierExecutionPlan,
                    WannierNLQG.Core.KSliceGrid2D,
                    Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                    WannierNLQG.Core.TightBindingModel{
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                    },
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                    Bool,
                    Bool,
                },
                WannierNLQG.Runtime.var"#finish!#624"{
                    WannierNLQG.Runtime.EffectiveTaskConfig,
                    WannierNLQG.Runtime.RunContext,
                    Array{Array{Base.Complex{Float64}, 4}, 1},
                    NTuple{4, Symbol},
                    Array{Tuple{Int64, Int64}, 1},
                    WannierNLQG.Runtime.FourierExecutionPlan,
                    Int64,
                    WannierNLQG.Core.KSliceGrid2D,
                    Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                    Int64,
                    Nothing,
                    WannierNLQG.Runtime.ResponseQualificationResult,
                    WannierNLQG.Core.TightBindingModel{
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                    },
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                    Bool,
                    Bool,
                    WannierNLQG.Runtime.NormalizedTaskSpec,
                },
                WannierNLQG.Runtime.var"#cleanup!#625"{
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                    Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                },
            },
        },
    )
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"#561#567",
            WannierNLQG.Runtime.PreparedResponseTask{
                WannierNLQG.Runtime.var"#execute_point!#623"{
                    WannierNLQG.Runtime.EffectiveTaskConfig,
                    Bool,
                    Base.Val{:orbital_magnetization},
                    WannierNLQG.MatrixElements.OrbitalCompletion,
                    Array{Array{Float64, 1}, 1},
                    Array{Array{Base.Complex{Float64}, 4}, 1},
                    Tuple{Symbol, Symbol, Symbol},
                    Array{Float64, 1},
                    Array{Tuple{Int64}, 1},
                    WannierNLQG.Runtime.FourierExecutionPlan,
                    WannierNLQG.Core.IntegralKGrid,
                    Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                    WannierNLQG.Core.TightBindingModel{
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                    },
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                    Bool,
                    Bool,
                },
                WannierNLQG.Runtime.var"#finish!#624"{
                    WannierNLQG.Runtime.EffectiveTaskConfig,
                    WannierNLQG.Runtime.RunContext,
                    Array{Array{Base.Complex{Float64}, 4}, 1},
                    Tuple{Symbol, Symbol, Symbol},
                    Array{Tuple{Int64}, 1},
                    WannierNLQG.Runtime.FourierExecutionPlan,
                    Int64,
                    WannierNLQG.Core.IntegralKGrid,
                    Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                    Int64,
                    Nothing,
                    WannierNLQG.Runtime.ResponseQualificationResult,
                    WannierNLQG.Core.TightBindingModel{
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                    },
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                    Bool,
                    Bool,
                    WannierNLQG.Runtime.NormalizedTaskSpec,
                },
                WannierNLQG.Runtime.var"#cleanup!#625"{
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                    Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                },
            },
        },
    )
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"#561#567",
            WannierNLQG.Runtime.PreparedResponseTask{
                WannierNLQG.Runtime.var"#execute_point!#623"{
                    WannierNLQG.Runtime.EffectiveTaskConfig,
                    Bool,
                    Base.Val{:orbital_magnetization},
                    WannierNLQG.MatrixElements.OrbitalCompletion,
                    Array{Array{Float64, 1}, 1},
                    Array{Array{Base.Complex{Float64}, 4}, 1},
                    Tuple{Symbol, Symbol, Symbol},
                    Array{Float64, 1},
                    Array{Tuple{Int64}, 1},
                    WannierNLQG.Runtime.FourierExecutionPlan,
                    WannierNLQG.Core.KSliceGrid2D,
                    Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                    WannierNLQG.Core.TightBindingModel{
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                    },
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                    Bool,
                    Bool,
                },
                WannierNLQG.Runtime.var"#finish!#624"{
                    WannierNLQG.Runtime.EffectiveTaskConfig,
                    WannierNLQG.Runtime.RunContext,
                    Array{Array{Base.Complex{Float64}, 4}, 1},
                    Tuple{Symbol, Symbol, Symbol},
                    Array{Tuple{Int64}, 1},
                    WannierNLQG.Runtime.FourierExecutionPlan,
                    Int64,
                    WannierNLQG.Core.KSliceGrid2D,
                    Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                    Int64,
                    Nothing,
                    WannierNLQG.Runtime.ResponseQualificationResult,
                    WannierNLQG.Core.TightBindingModel{
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                    },
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                    Bool,
                    Bool,
                    WannierNLQG.Runtime.NormalizedTaskSpec,
                },
                WannierNLQG.Runtime.var"#cleanup!#625"{
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                    Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                },
            },
        },
    )
    false
    false
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"#cleanup!#625"{
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
            },
        },
    )
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"#execute_point!#623"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                Bool,
                Base.Val{:linear_optical_response},
                WannierNLQG.MatrixElements.OrbitalCompletion,
                Array{Array{Float64, 1}, 1},
                Array{Array{Base.Complex{Float64}, 4}, 1},
                NTuple{4, Symbol},
                Array{Float64, 1},
                Array{Tuple{Int64, Int64}, 1},
                WannierNLQG.Runtime.FourierExecutionPlan,
                WannierNLQG.Core.IntegralKGrid,
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Bool,
                Bool,
            },
            Int64,
            Int64,
            Int64,
        },
    )
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"#execute_point!#623"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                Bool,
                Base.Val{:linear_optical_response},
                WannierNLQG.MatrixElements.OrbitalCompletion,
                Array{Array{Float64, 1}, 1},
                Array{Array{Base.Complex{Float64}, 4}, 1},
                NTuple{4, Symbol},
                Array{Float64, 1},
                Array{Tuple{Int64, Int64}, 1},
                WannierNLQG.Runtime.FourierExecutionPlan,
                WannierNLQG.Core.KSliceGrid2D,
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Bool,
                Bool,
            },
            Int64,
            Int64,
            Int64,
        },
    )
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"#execute_point!#623"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                Bool,
                Base.Val{:linear_transport},
                WannierNLQG.MatrixElements.OrbitalCompletion,
                Array{Array{Float64, 1}, 1},
                Array{Array{Base.Complex{Float64}, 4}, 1},
                NTuple{4, Symbol},
                Array{Float64, 1},
                Array{Tuple{Int64, Int64}, 1},
                WannierNLQG.Runtime.FourierExecutionPlan,
                WannierNLQG.Core.IntegralKGrid,
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Bool,
                Bool,
            },
            Int64,
            Int64,
            Int64,
        },
    )
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"#execute_point!#623"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                Bool,
                Base.Val{:linear_transport},
                WannierNLQG.MatrixElements.OrbitalCompletion,
                Array{Array{Float64, 1}, 1},
                Array{Array{Base.Complex{Float64}, 4}, 1},
                NTuple{4, Symbol},
                Array{Float64, 1},
                Array{Tuple{Int64, Int64}, 1},
                WannierNLQG.Runtime.FourierExecutionPlan,
                WannierNLQG.Core.KSliceGrid2D,
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Bool,
                Bool,
            },
            Int64,
            Int64,
            Int64,
        },
    )
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"#execute_point!#623"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                Bool,
                Base.Val{:orbital_magnetization},
                WannierNLQG.MatrixElements.OrbitalCompletion,
                Array{Array{Float64, 1}, 1},
                Array{Array{Base.Complex{Float64}, 4}, 1},
                Tuple{Symbol, Symbol, Symbol},
                Array{Float64, 1},
                Array{Tuple{Int64}, 1},
                WannierNLQG.Runtime.FourierExecutionPlan,
                WannierNLQG.Core.IntegralKGrid,
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Bool,
                Bool,
            },
            Int64,
            Int64,
            Int64,
        },
    )
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"#execute_point!#623"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                Bool,
                Base.Val{:orbital_magnetization},
                WannierNLQG.MatrixElements.OrbitalCompletion,
                Array{Array{Float64, 1}, 1},
                Array{Array{Base.Complex{Float64}, 4}, 1},
                Tuple{Symbol, Symbol, Symbol},
                Array{Float64, 1},
                Array{Tuple{Int64}, 1},
                WannierNLQG.Runtime.FourierExecutionPlan,
                WannierNLQG.Core.KSliceGrid2D,
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Bool,
                Bool,
            },
            Int64,
            Int64,
            Int64,
        },
    )
    false
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"#finish!#624"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                WannierNLQG.Runtime.RunContext,
                Array{Array{Base.Complex{Float64}, 4}, 1},
                NTuple{4, Symbol},
                Array{Tuple{Int64, Int64}, 1},
                WannierNLQG.Runtime.FourierExecutionPlan,
                Int64,
                WannierNLQG.Core.IntegralKGrid,
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                Int64,
                Nothing,
                WannierNLQG.Runtime.ResponseQualificationResult,
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Bool,
                Bool,
                WannierNLQG.Runtime.NormalizedTaskSpec,
            },
        },
    )
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"#finish!#624"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                WannierNLQG.Runtime.RunContext,
                Array{Array{Base.Complex{Float64}, 4}, 1},
                NTuple{4, Symbol},
                Array{Tuple{Int64, Int64}, 1},
                WannierNLQG.Runtime.FourierExecutionPlan,
                Int64,
                WannierNLQG.Core.KSliceGrid2D,
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                Int64,
                Nothing,
                WannierNLQG.Runtime.ResponseQualificationResult,
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Bool,
                Bool,
                WannierNLQG.Runtime.NormalizedTaskSpec,
            },
        },
    )
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"#finish!#624"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                WannierNLQG.Runtime.RunContext,
                Array{Array{Base.Complex{Float64}, 4}, 1},
                Tuple{Symbol, Symbol, Symbol},
                Array{Tuple{Int64}, 1},
                WannierNLQG.Runtime.FourierExecutionPlan,
                Int64,
                WannierNLQG.Core.IntegralKGrid,
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                Int64,
                Nothing,
                WannierNLQG.Runtime.ResponseQualificationResult,
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Bool,
                Bool,
                WannierNLQG.Runtime.NormalizedTaskSpec,
            },
        },
    )
    precompile(
        Tuple{
            WannierNLQG.Runtime.var"#finish!#624"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                WannierNLQG.Runtime.RunContext,
                Array{Array{Base.Complex{Float64}, 4}, 1},
                Tuple{Symbol, Symbol, Symbol},
                Array{Tuple{Int64}, 1},
                WannierNLQG.Runtime.FourierExecutionPlan,
                Int64,
                WannierNLQG.Core.KSliceGrid2D,
                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                Int64,
                Nothing,
                WannierNLQG.Runtime.ResponseQualificationResult,
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
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
                            Array{Base.Complex{Float64}, 4},
                        },
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                        Symbol,
                        Nothing,
                        Nothing,
                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                    },
                },
                Bool,
                Bool,
                WannierNLQG.Runtime.NormalizedTaskSpec,
            },
        },
    )
    false
    false
    precompile(Tuple{WannierNLQG.Runtime.var"#order#566"{Nothing}, Int64})
    precompile(
        Tuple{
            typeof(Base.:(==)),
            WannierNLQG.Core.RealSpaceOperatorKind,
            WannierNLQG.Core.RealSpaceOperatorKind,
        },
    )
    false
    false
    false
    precompile(
        Tuple{
            typeof(Base.Broadcast.materialize),
            Base.Broadcast.Broadcasted{
                Base.Broadcast.DefaultArrayStyle{1},
                Nothing,
                typeof(WannierNLQG.Runtime.progress_json_value),
                Tuple{
                    Array{
                        NamedTuple{
                            (
                                :label,
                                :fractional_coordinates,
                                :point_index_one_based,
                                :cumulative_distance_A_inverse,
                            ),
                            Tuple{String, Array{Float64, 1}, Int64, Float64},
                        },
                        1,
                    },
                },
            },
        },
    )
    false
    precompile(
        Tuple{
            typeof(Base.Iterators._zip_iterate_all),
            Tuple{
                Array{WannierNLQG.Runtime.EffectiveTaskConfig, 1},
                Array{WannierNLQG.Runtime.RunContext, 1},
                Array{Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1}, 1},
                Array{WannierNLQG.Runtime.BandStructureBundlePlan, 1},
            },
            NTuple{4, Tuple{Int64}},
        },
    )
    precompile(
        Tuple{
            typeof(Base.Iterators._zip_iterate_all),
            Tuple{
                Array{WannierNLQG.Runtime.EffectiveTaskConfig, 1},
                Array{WannierNLQG.Runtime.RunContext, 1},
                Array{Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1}, 1},
                Array{WannierNLQG.Runtime.BandStructureBundlePlan, 1},
            },
            NTuple{4, Tuple{}},
        },
    )
    precompile(
        Tuple{
            typeof(Base.Iterators._zip_iterate_all),
            Tuple{
                Array{WannierNLQG.Runtime.EffectiveTaskConfig, 1},
                Array{WannierNLQG.Runtime.RunContext, 1},
                Array{Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1}, 1},
                Array{WannierNLQG.Runtime.IntegralBundlePlan, 1},
            },
            NTuple{4, Tuple{Int64}},
        },
    )
    precompile(
        Tuple{
            typeof(Base.Iterators._zip_iterate_all),
            Tuple{
                Array{WannierNLQG.Runtime.EffectiveTaskConfig, 1},
                Array{WannierNLQG.Runtime.RunContext, 1},
                Array{Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1}, 1},
                Array{WannierNLQG.Runtime.IntegralBundlePlan, 1},
            },
            NTuple{4, Tuple{}},
        },
    )
    precompile(
        Tuple{
            typeof(Base.Iterators._zip_iterate_all),
            Tuple{
                Array{WannierNLQG.Runtime.EffectiveTaskConfig, 1},
                Array{WannierNLQG.Runtime.RunContext, 1},
                Array{Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1}, 1},
                Array{WannierNLQG.Runtime.KSliceBundlePlan, 1},
            },
            NTuple{4, Tuple{Int64}},
        },
    )
    precompile(
        Tuple{
            typeof(Base.Iterators._zip_iterate_all),
            Tuple{
                Array{WannierNLQG.Runtime.EffectiveTaskConfig, 1},
                Array{WannierNLQG.Runtime.RunContext, 1},
                Array{Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1}, 1},
                Array{WannierNLQG.Runtime.KSliceBundlePlan, 1},
            },
            NTuple{4, Tuple{}},
        },
    )
    precompile(
        Tuple{
            typeof(Base.Iterators._zip_iterate_all),
            Tuple{
                Array{
                    WannierNLQG.Runtime.PreparedResponseTask{E, F, C} where {C} where {F} where E,
                    1,
                },
                Array{String, 1},
                Array{WannierNLQG.Runtime.EffectiveTaskConfig, 1},
                Array{WannierNLQG.Runtime.RunContext, 1},
                Array{Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1}, 1},
            },
            NTuple{5, Tuple{Int64}},
        },
    )
    precompile(
        Tuple{
            typeof(Base.Iterators._zip_iterate_all),
            Tuple{
                Array{
                    WannierNLQG.Runtime.PreparedResponseTask{E, F, C} where {C} where {F} where E,
                    1,
                },
                Array{String, 1},
                Array{WannierNLQG.Runtime.EffectiveTaskConfig, 1},
                Array{WannierNLQG.Runtime.RunContext, 1},
                Array{Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1}, 1},
            },
            NTuple{5, Tuple{}},
        },
    )
    precompile(
        Tuple{
            typeof(Base.Iterators.enumerate),
            Base.Iterators.Zip{
                Tuple{
                    Array{WannierNLQG.Runtime.EffectiveTaskConfig, 1},
                    Array{WannierNLQG.Runtime.RunContext, 1},
                    Array{Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1}, 1},
                    Array{WannierNLQG.Runtime.IntegralBundlePlan, 1},
                },
            },
        },
    )
    precompile(
        Tuple{
            typeof(Base.Iterators.enumerate),
            Base.Iterators.Zip{
                Tuple{
                    Array{WannierNLQG.Runtime.EffectiveTaskConfig, 1},
                    Array{WannierNLQG.Runtime.RunContext, 1},
                    Array{Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1}, 1},
                    Array{WannierNLQG.Runtime.KSliceBundlePlan, 1},
                },
            },
        },
    )
    precompile(
        Tuple{
            typeof(Base.Iterators.rest),
            Base.Generator{Tuple{Int64, Int64}, WannierNLQG.Runtime.var"#153#155"},
        },
    )
    precompile(
        Tuple{
            typeof(Base.Iterators.rest),
            Base.Generator{Tuple{Int64}, WannierNLQG.Runtime.var"#153#155"},
        },
    )
    false
    precompile(
        Tuple{
            typeof(Base.Sort._sort!),
            Array{Int64, 1},
            Base.Sort.SubArrayOptimization{
                Base.Sort.MissingOptimization{
                    Base.Sort.BoolOptimization{
                        Base.Sort.Small{
                            10,
                            Base.Sort.InsertionSortAlg,
                            Base.Sort.IEEEFloatOptimization{
                                Base.Sort.IsUIntMappable{
                                    Base.Sort.Small{
                                        40,
                                        Base.Sort.InsertionSortAlg,
                                        Base.Sort.CheckSorted{
                                            Base.Sort.ComputeExtrema{
                                                Base.Sort.ConsiderCountingSort{
                                                    Base.Sort.CountingSort,
                                                    Base.Sort.ConsiderRadixSort{
                                                        Base.Sort.RadixSort,
                                                        Base.Sort.Small{
                                                            80,
                                                            Base.Sort.InsertionSortAlg,
                                                            Base.Sort.ScratchQuickSort{
                                                                Base.Missing,
                                                                Base.Missing,
                                                                Base.Sort.InsertionSortAlg,
                                                            },
                                                        },
                                                    },
                                                },
                                            },
                                        },
                                    },
                                    Base.Sort.StableCheckSorted{
                                        Base.Sort.ScratchQuickSort{
                                            Base.Missing,
                                            Base.Missing,
                                            Base.Sort.InsertionSortAlg,
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
            },
            Base.Order.By{WannierNLQG.Runtime.var"#order#566"{Nothing}, Base.Order.ForwardOrdering},
            NamedTuple{(:scratch,), Tuple{Nothing}},
        },
    )
    false
    precompile(
        Tuple{typeof(Base._all), WannierNLQG.Runtime.var"#131#133", Array{Float64, 1}, Base.Colon},
    )
    precompile(
        Tuple{
            typeof(Base._all),
            WannierNLQG.Runtime.var"#132#134",
            Tuple{Float64, Float64},
            Base.Colon,
        },
    )
    precompile(
        Tuple{
            typeof(Base._all),
            WannierNLQG.Runtime.var"#152#154",
            Tuple{Int64, Int64},
            Base.Colon,
        },
    )
    precompile(
        Tuple{typeof(Base._all), WannierNLQG.Runtime.var"#152#154", Tuple{Int64}, Base.Colon},
    )
    precompile(
        Tuple{
            typeof(Base._array_for),
            Type{
                WannierNLQG.MatrixElements.KPointBatchWorkspace{
                    WannierNLQG.FIRST_USE_WORKSPACE_TYPES[2],
                    WannierNLQG.MatrixElements.KPointMatrixData{
                        WannierNLQG.MatrixElements.HamiltonianMatrixData{
                            Array{Float64, 2},
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 4},
                            Array{Base.Complex{Float64}, 3},
                        },
                        WannierNLQG.MatrixElements.PositionMatrixData{
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 4},
                            Array{Base.Complex{Float64}, 4},
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
                        Nothing,
                        Nothing,
                    },
                },
            },
            Base.HasShape{1},
            Tuple{Base.OneTo{Int64}},
        },
    )
    precompile(
        Tuple{
            typeof(Base._array_for),
            Type{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[1]},
            Base.HasShape{1},
            Tuple{Base.OneTo{Int64}},
        },
    )
    precompile(
        Tuple{
            typeof(Base._array_for),
            Type{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3]},
            Base.HasShape{1},
            Tuple{Base.OneTo{Int64}},
        },
    )
    precompile(
        Tuple{
            typeof(Base._array_for),
            Type{WannierNLQG.Runtime.IntegralTaskAccumulator{4}},
            Base.HasShape{1},
            Tuple{Base.OneTo{Int64}},
        },
    )
    precompile(
        Tuple{
            typeof(Base._similar_shape),
            Base.Generator{Base.UnitRange{Int64}, WannierNLQG.Runtime.var"#608#618"},
            Base.HasShape{1},
        },
    )
    false
    precompile(
        Tuple{
            typeof(Base._unique_from),
            Base.Generator{
                Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1},
                WannierNLQG.Runtime.var"#109#110"{WannierNLQG.Runtime.EffectiveTaskConfig},
            },
            Array{Tuple{Int64, Int64, Int64}, 1},
            Base.Set{Tuple{Int64, Int64, Int64}},
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base._unique_from),
            Base.Generator{
                Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1},
                WannierNLQG.Runtime.var"#109#110"{WannierNLQG.Runtime.EffectiveTaskConfig},
            },
            Array{Tuple{Int64, Int64}, 1},
            Base.Set{Tuple{Int64, Int64}},
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base._unique_from),
            Base.Generator{
                Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1},
                WannierNLQG.Runtime.var"#109#110"{WannierNLQG.Runtime.EffectiveTaskConfig},
            },
            Array{Tuple{Int64}, 1},
            Base.Set{Tuple{Int64}},
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base._unique_from),
            Base.Generator{
                Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1},
                WannierNLQG.Runtime.var"#462#463"{WannierNLQG.Runtime.EffectiveTaskConfig},
            },
            Array{Tuple{Int64, Int64, Int64}, 1},
            Base.Set{Tuple{Int64, Int64, Int64}},
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base._unique_from),
            Base.Generator{
                Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1},
                WannierNLQG.Runtime.var"#462#463"{WannierNLQG.Runtime.EffectiveTaskConfig},
            },
            Array{Tuple{Int64, Int64}, 1},
            Base.Set{Tuple{Int64, Int64}},
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base._unique_from),
            Base.Generator{
                Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1},
                WannierNLQG.Runtime.var"#462#463"{WannierNLQG.Runtime.EffectiveTaskConfig},
            },
            Array{Tuple{Int64}, 1},
            Base.Set{Tuple{Int64}},
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect),
            Base.Generator{
                Array{
                    WannierNLQG.MatrixElements.KPointBatchWorkspace{
                        WannierNLQG.FIRST_USE_WORKSPACE_TYPES[2],
                        WannierNLQG.MatrixElements.KPointMatrixData{
                            WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                Array{Float64, 2},
                                Array{Base.Complex{Float64}, 3},
                                Array{Base.Complex{Float64}, 4},
                                Array{Base.Complex{Float64}, 3},
                            },
                            WannierNLQG.MatrixElements.PositionMatrixData{
                                Array{Base.Complex{Float64}, 3},
                                Array{Base.Complex{Float64}, 3},
                                Array{Base.Complex{Float64}, 4},
                                Array{Base.Complex{Float64}, 4},
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
                            Nothing,
                            Nothing,
                        },
                    },
                    1,
                },
                WannierNLQG.Runtime.var"#638#661",
            },
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect),
            Base.Generator{
                Array{
                    WannierNLQG.MatrixElements.KPointBatchWorkspace{
                        WannierNLQG.FIRST_USE_WORKSPACE_TYPES[2],
                        WannierNLQG.MatrixElements.KPointMatrixData{
                            WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                Array{Float64, 2},
                                Array{Base.Complex{Float64}, 3},
                                Array{Base.Complex{Float64}, 4},
                                Array{Base.Complex{Float64}, 3},
                            },
                            WannierNLQG.MatrixElements.PositionMatrixData{
                                Array{Base.Complex{Float64}, 3},
                                Array{Base.Complex{Float64}, 3},
                                Array{Base.Complex{Float64}, 4},
                                Array{Base.Complex{Float64}, 4},
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
                            Nothing,
                            Nothing,
                        },
                    },
                    1,
                },
                WannierNLQG.Runtime.var"#639#662",
            },
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect),
            Base.Generator{
                Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1},
                WannierNLQG.Runtime.var"#640#663"{
                    WannierNLQG.Runtime.EffectiveTaskConfig,
                    WannierNLQG.Runtime.RunContext,
                    Int64,
                    Int64,
                    Nothing,
                },
            },
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect),
            Base.Generator{
                Array{WannierNLQG.Runtime.RunContext, 1},
                WannierNLQG.Runtime.var"#834#844"{WannierNLQG.Runtime.RunContext},
            },
        },
    )
    false
    false
    false
    precompile(
        Tuple{
            typeof(Base.collect),
            Base.Generator{
                Base.UnitRange{Int64},
                WannierNLQG.Runtime.var"#466#469"{NTuple{4, Int64}},
            },
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect),
            Base.Generator{
                Base.UnitRange{Int64},
                WannierNLQG.Runtime.var"#611#621"{
                    NTuple{4, Symbol},
                    Array{Float64, 1},
                    Array{Tuple{Int64, Int64}, 1},
                    Int64,
                    Bool,
                },
            },
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect),
            Base.Generator{
                Base.UnitRange{Int64},
                WannierNLQG.Runtime.var"#611#621"{
                    Tuple{Symbol, Symbol, Symbol},
                    Array{Float64, 1},
                    Array{Tuple{Int64}, 1},
                    Int64,
                    Bool,
                },
            },
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect),
            Base.Generator{
                Base.UnitRange{Int64},
                WannierNLQG.Runtime.var"#641#664"{
                    Array{
                        WannierNLQG.MatrixElements.KPointMatrixData{
                            WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                Array{Float64, 2},
                                Array{Base.Complex{Float64}, 3},
                                Array{Base.Complex{Float64}, 4},
                                Array{Base.Complex{Float64}, 3},
                            },
                            WannierNLQG.MatrixElements.PositionMatrixData{
                                Array{Base.Complex{Float64}, 3},
                                Array{Base.Complex{Float64}, 3},
                                Array{Base.Complex{Float64}, 4},
                                Array{Base.Complex{Float64}, 4},
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
                            Nothing,
                            Nothing,
                        },
                        1,
                    },
                    Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[2], 1},
                    Int64,
                    Int64,
                    Int64,
                },
            },
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect),
            Base.Generator{
                Base.UnitRange{Int64},
                WannierNLQG.Runtime.var"#643#666"{
                    Array{
                        WannierNLQG.MatrixElements.KPointMatrixData{
                            WannierNLQG.MatrixElements.HamiltonianMatrixData{
                                Array{Float64, 2},
                                Array{Base.Complex{Float64}, 3},
                                Array{Base.Complex{Float64}, 4},
                                Array{Base.Complex{Float64}, 3},
                            },
                            WannierNLQG.MatrixElements.PositionMatrixData{
                                Array{Base.Complex{Float64}, 3},
                                Array{Base.Complex{Float64}, 3},
                                Array{Base.Complex{Float64}, 4},
                                Array{Base.Complex{Float64}, 4},
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
                            Nothing,
                            Nothing,
                        },
                        1,
                    },
                    Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[2], 1},
                    Int64,
                    Int64,
                    Int64,
                    Int64,
                },
            },
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect),
            Tuple{WannierNLQG.Core.RealSpaceOperatorKind, WannierNLQG.Core.RealSpaceOperatorKind},
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect),
            Type{Int64},
            Base.Generator{
                Base.Iterators.Filter{
                    WannierNLQG.Runtime.var"#803#807"{Int64, Int64},
                    Base.UnitRange{Int64},
                },
                typeof(Base.identity),
            },
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect_similar),
            Array{WannierNLQG.Runtime.BandStructureBundlePlan, 1},
            Base.Generator{
                Array{WannierNLQG.Runtime.BandStructureBundlePlan, 1},
                WannierNLQG.Runtime.var"#839#849",
            },
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect_similar),
            Array{WannierNLQG.Runtime.IntegralBundlePlan, 1},
            Base.Generator{
                Array{WannierNLQG.Runtime.IntegralBundlePlan, 1},
                WannierNLQG.Runtime.var"#839#849",
            },
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect_similar),
            Array{WannierNLQG.Runtime.KSliceBundlePlan, 1},
            Base.Generator{
                Array{WannierNLQG.Runtime.KSliceBundlePlan, 1},
                WannierNLQG.Runtime.var"#839#849",
            },
        },
    )
    false
    false
    false
    false
    precompile(
        Tuple{
            typeof(Base.collect_to_with_first!),
            Array{Array{Tuple{String, String, String}, 1}, 1},
            Array{Tuple{String, String, String}, 1},
            Base.Generator{
                Array{WannierNLQG.Runtime.EffectiveTaskConfig, 1},
                WannierNLQG.Runtime.var"#842#852",
            },
            Int64,
        },
    )
    false
    false
    false
    false
    false
    false
    false
    precompile(
        Tuple{
            typeof(Base.collect_to_with_first!),
            Array{
                WannierNLQG.MatrixElements.KPointBatchWorkspace{
                    WannierNLQG.FIRST_USE_WORKSPACE_TYPES[2],
                    WannierNLQG.MatrixElements.KPointMatrixData{
                        WannierNLQG.MatrixElements.HamiltonianMatrixData{
                            Array{Float64, 2},
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 4},
                            Array{Base.Complex{Float64}, 3},
                        },
                        WannierNLQG.MatrixElements.PositionMatrixData{
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 4},
                            Array{Base.Complex{Float64}, 4},
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
                        Nothing,
                        Nothing,
                    },
                },
                1,
            },
            WannierNLQG.MatrixElements.KPointBatchWorkspace{
                WannierNLQG.FIRST_USE_WORKSPACE_TYPES[2],
                WannierNLQG.MatrixElements.KPointMatrixData{
                    WannierNLQG.MatrixElements.HamiltonianMatrixData{
                        Array{Float64, 2},
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                        Array{Base.Complex{Float64}, 3},
                    },
                    WannierNLQG.MatrixElements.PositionMatrixData{
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                        Array{Base.Complex{Float64}, 4},
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
                    Nothing,
                    Nothing,
                },
            },
            Base.Generator{
                Base.UnitRange{Int64},
                WannierNLQG.Runtime.var"#637#660"{
                    WannierNLQG.MatrixElements.MatrixElementSources{Nothing, Nothing, Nothing},
                    WannierNLQG.MatrixElements.MatrixElementPlan,
                    WannierNLQG.Core.TightBindingModel{
                        Array{Base.Complex{Float64}, 3},
                        WannierNLQG.IO.PackedCartesianOperator{
                            1,
                            4,
                            Array{Base.Complex{Float64}, 3},
                        },
                    },
                },
            },
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect_to_with_first!),
            Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[1], 1},
            WannierNLQG.FIRST_USE_WORKSPACE_TYPES[1],
            Base.Generator{
                Base.UnitRange{Int64},
                WannierNLQG.Runtime.var"#804#808"{
                    WannierNLQG.Runtime.BandStructureKPathKernel,
                    WannierNLQG.Core.TightBindingModel{
                        Array{Base.Complex{Float64}, 3},
                        WannierNLQG.IO.PackedCartesianOperator{
                            1,
                            4,
                            Array{Base.Complex{Float64}, 3},
                        },
                    },
                },
            },
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect_to_with_first!),
            Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
            WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3],
            Base.Generator{
                Base.UnitRange{Int64},
                WannierNLQG.Runtime.var"#605#615"{
                    WannierNLQG.MatrixElements.MatrixElementPlan,
                    WannierNLQG.Core.TightBindingModel{
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                    },
                },
            },
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect_to_with_first!),
            Array{WannierNLQG.Runtime.BandStructureBundlePlan, 1},
            WannierNLQG.Runtime.BandStructureBundlePlan,
            Base.Generator{
                Base.Iterators.Zip{
                    Tuple{
                        Array{WannierNLQG.Runtime.EffectiveTaskConfig, 1},
                        Array{Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1}, 1},
                    },
                },
                WannierNLQG.Runtime.var"#838#848",
            },
            Tuple{Int64, Int64},
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect_to_with_first!),
            Array{WannierNLQG.Runtime.IntegralBundlePlan, 1},
            WannierNLQG.Runtime.IntegralBundlePlan,
            Base.Generator{
                Base.Iterators.Zip{
                    Tuple{
                        Array{WannierNLQG.Runtime.EffectiveTaskConfig, 1},
                        Array{Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1}, 1},
                    },
                },
                WannierNLQG.Runtime.var"#838#848",
            },
            Tuple{Int64, Int64},
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect_to_with_first!),
            Array{WannierNLQG.Runtime.IntegralTaskAccumulator{4}, 1},
            WannierNLQG.Runtime.IntegralTaskAccumulator{4},
            Base.Generator{
                Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1},
                WannierNLQG.Runtime.var"#640#663"{
                    WannierNLQG.Runtime.EffectiveTaskConfig,
                    WannierNLQG.Runtime.RunContext,
                    Int64,
                    Int64,
                    Nothing,
                },
            },
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect_to_with_first!),
            Array{WannierNLQG.Runtime.KSliceBundlePlan, 1},
            WannierNLQG.Runtime.KSliceBundlePlan,
            Base.Generator{
                Base.Iterators.Zip{
                    Tuple{
                        Array{WannierNLQG.Runtime.EffectiveTaskConfig, 1},
                        Array{Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1}, 1},
                    },
                },
                WannierNLQG.Runtime.var"#838#848",
            },
            Tuple{Int64, Int64},
        },
    )
    precompile(Tuple{typeof(Base.first), Array{WannierNLQG.Runtime.RunContext, 1}})
    precompile(
        Tuple{typeof(Base.getindex), Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[2], 1}, Int64},
    )
    precompile(
        Tuple{typeof(Base.getindex), Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1}, Int64},
    )
    precompile(
        Tuple{
            typeof(Base.getindex),
            Array{
                WannierNLQG.Responses.ShiftCurrentConventionalWorkspace{
                    WannierNLQG.FIRST_USE_WORKSPACE_TYPES[2],
                    WannierNLQG.MatrixElements.KPointMatrixData{
                        WannierNLQG.MatrixElements.HamiltonianMatrixData{
                            Array{Float64, 2},
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 4},
                            Array{Base.Complex{Float64}, 3},
                        },
                        WannierNLQG.MatrixElements.PositionMatrixData{
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 3},
                            Array{Base.Complex{Float64}, 4},
                            Array{Base.Complex{Float64}, 4},
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
                        Nothing,
                        Nothing,
                    },
                },
                1,
            },
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getindex),
            Type{WannierNLQG.Core.RealSpaceOperatorKind},
            WannierNLQG.Core.RealSpaceOperatorKind,
            WannierNLQG.Core.RealSpaceOperatorKind,
        },
    )
    false
    false
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.Generator{Base.UnitRange{Int64}, WannierNLQG.Runtime.var"#608#618"},
            Symbol,
        },
    )
    false
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.Generator{Tuple{Int64, Int64}, WannierNLQG.Runtime.var"#153#155"},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.Generator{Tuple{Int64}, WannierNLQG.Runtime.var"#153#155"},
            Symbol,
        },
    )
    false
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.Iterators.Flatten{
                Base.Generator{Base.UnitRange{Int64}, WannierNLQG.Runtime.var"#756#757"},
            },
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.MappingRF{WannierNLQG.Runtime.var"#10#20", Base.BottomRF{typeof(Base.vcat)}},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.MappingRF{WannierNLQG.Runtime.var"#401#402", Base.BottomRF{typeof(Base.max)}},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.MappingRF{WannierNLQG.Runtime.var"#515#527", Base.BottomRF{typeof(Base.max)}},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.MappingRF{WannierNLQG.Runtime.var"#516#528", Base.BottomRF{typeof(Base.max)}},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.MappingRF{WannierNLQG.Runtime.var"#517#529", Base.BottomRF{typeof(Base.add_sum)}},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.MappingRF{WannierNLQG.Runtime.var"#518#530", Base.BottomRF{typeof(Base.add_sum)}},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.MappingRF{WannierNLQG.Runtime.var"#519#531", Base.BottomRF{typeof(Base.add_sum)}},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.MappingRF{WannierNLQG.Runtime.var"#520#532", Base.BottomRF{typeof(Base.add_sum)}},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.MappingRF{WannierNLQG.Runtime.var"#521#533", Base.BottomRF{typeof(Base.add_sum)}},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.MappingRF{WannierNLQG.Runtime.var"#522#534", Base.BottomRF{typeof(Base.add_sum)}},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.MappingRF{WannierNLQG.Runtime.var"#523#535", Base.BottomRF{typeof(Base.add_sum)}},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.MappingRF{WannierNLQG.Runtime.var"#524#536", Base.BottomRF{typeof(Base.add_sum)}},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.MappingRF{WannierNLQG.Runtime.var"#7#17", Base.BottomRF{typeof(Base.vcat)}},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.MappingRF{WannierNLQG.Runtime.var"#8#18", Base.BottomRF{typeof(Base.vcat)}},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.MappingRF{WannierNLQG.Runtime.var"#9#19", Base.BottomRF{typeof(Base.vcat)}},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.Order.By{WannierNLQG.Runtime.var"#185#187", Base.Order.ForwardOrdering},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.Order.By{WannierNLQG.Runtime.var"#order#566"{Nothing}, Base.Order.ForwardOrdering},
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.Order.Lt{
                Base.Sort.var"#30#31"{
                    Base.Order.By{WannierNLQG.Runtime.var"#185#187", Base.Order.ForwardOrdering},
                },
            },
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            Base.Order.Lt{
                Base.Sort.var"#30#31"{
                    Base.Order.By{
                        WannierNLQG.Runtime.var"#order#566"{Nothing},
                        Base.Order.ForwardOrdering,
                    },
                },
            },
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            NamedTuple{
                (:kind, :component_indices, :length_elements, :logical_shape),
                Tuple{
                    WannierNLQG.Core.RealSpaceOperatorKind,
                    Tuple{Int8, Int8},
                    Int64,
                    Tuple{Int64, Int64, Int64},
                },
            },
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            NamedTuple{
                (:ok, :metadata, :entries, :replica_summary, :error),
                Tuple{
                    Bool,
                    NamedTuple{
                        (
                            :lattice,
                            :num_orbitals,
                            :r_vectors,
                            :degeneracies,
                            :has_spin,
                            :has_spin_velocity,
                            :diagnostics,
                        ),
                        Tuple{
                            Array{Float64, 2},
                            Int64,
                            Array{Int64, 2},
                            Array{Int64, 1},
                            Bool,
                            Bool,
                            Nothing,
                        },
                    },
                    Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                    WannierNLQG.Runtime.RuntimeReplicaSummary,
                    String,
                },
            },
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            NamedTuple{
                (
                    :value,
                    :time,
                    :bytes,
                    :gctime,
                    :gcstats,
                    :lock_conflicts,
                    :compile_time,
                    :recompile_time,
                ),
                Tuple{
                    WannierNLQG.Runtime.RunResult,
                    Float64,
                    Int64,
                    Float64,
                    Base.GC_Diff,
                    Int64,
                    Float64,
                    Float64,
                },
            },
            Symbol,
        },
    )
    false
    false
    precompile(
        Tuple{
            typeof(Base.getproperty),
            WannierNLQG.MatrixElements.SharedInterpolationCache,
            Symbol,
        },
    )
    precompile(
        Tuple{
            typeof(Base.getproperty),
            WannierNLQG.Responses.ShiftCurrentConventionalWorkspace{
                WannierNLQG.FIRST_USE_WORKSPACE_TYPES[2],
                WannierNLQG.MatrixElements.KPointMatrixData{
                    WannierNLQG.MatrixElements.HamiltonianMatrixData{
                        Array{Float64, 2},
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                        Array{Base.Complex{Float64}, 3},
                    },
                    WannierNLQG.MatrixElements.PositionMatrixData{
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                        Array{Base.Complex{Float64}, 4},
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
                    Nothing,
                    Nothing,
                },
            },
            Symbol,
        },
    )
    precompile(Tuple{typeof(Base.getproperty), WannierNLQG.Runtime.FusedBundleRunResult, Symbol})
    false
    precompile(Tuple{typeof(Base.getproperty), WannierNLQG.Runtime.RunContext, Symbol})
    precompile(Tuple{typeof(Base.getproperty), WannierNLQG.Runtime.RunResult, Symbol})
    precompile(Tuple{typeof(Base.getproperty), WannierNLQG.Runtime.SeparateRelaxation, Symbol})
    false
    false
    precompile(
        Tuple{
            typeof(Base.grow_to!),
            Array{Int64, 1},
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
                            WannierNLQG.Runtime.var"#execute_point!#623"{
                                WannierNLQG.Runtime.EffectiveTaskConfig,
                                Bool,
                                Base.Val{:linear_optical_response},
                                WannierNLQG.MatrixElements.OrbitalCompletion,
                                Array{Array{Float64, 1}, 1},
                                Array{Array{Base.Complex{Float64}, 4}, 1},
                                NTuple{4, Symbol},
                                Array{Float64, 1},
                                Array{Tuple{Int64, Int64}, 1},
                                WannierNLQG.Runtime.FourierExecutionPlan,
                                WannierNLQG.Core.IntegralKGrid,
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Bool,
                                Bool,
                            },
                            WannierNLQG.Runtime.var"#finish!#624"{
                                WannierNLQG.Runtime.EffectiveTaskConfig,
                                WannierNLQG.Runtime.RunContext,
                                Array{Array{Base.Complex{Float64}, 4}, 1},
                                NTuple{4, Symbol},
                                Array{Tuple{Int64, Int64}, 1},
                                WannierNLQG.Runtime.FourierExecutionPlan,
                                Int64,
                                WannierNLQG.Core.IntegralKGrid,
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                                Int64,
                                Nothing,
                                WannierNLQG.Runtime.ResponseQualificationResult,
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Bool,
                                Bool,
                                WannierNLQG.Runtime.NormalizedTaskSpec,
                            },
                            WannierNLQG.Runtime.var"#cleanup!#625"{
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
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
            typeof(Base.grow_to!),
            Array{Int64, 1},
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
                            WannierNLQG.Runtime.var"#execute_point!#623"{
                                WannierNLQG.Runtime.EffectiveTaskConfig,
                                Bool,
                                Base.Val{:linear_optical_response},
                                WannierNLQG.MatrixElements.OrbitalCompletion,
                                Array{Array{Float64, 1}, 1},
                                Array{Array{Base.Complex{Float64}, 4}, 1},
                                NTuple{4, Symbol},
                                Array{Float64, 1},
                                Array{Tuple{Int64, Int64}, 1},
                                WannierNLQG.Runtime.FourierExecutionPlan,
                                WannierNLQG.Core.KSliceGrid2D,
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Bool,
                                Bool,
                            },
                            WannierNLQG.Runtime.var"#finish!#624"{
                                WannierNLQG.Runtime.EffectiveTaskConfig,
                                WannierNLQG.Runtime.RunContext,
                                Array{Array{Base.Complex{Float64}, 4}, 1},
                                NTuple{4, Symbol},
                                Array{Tuple{Int64, Int64}, 1},
                                WannierNLQG.Runtime.FourierExecutionPlan,
                                Int64,
                                WannierNLQG.Core.KSliceGrid2D,
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                                Int64,
                                Nothing,
                                WannierNLQG.Runtime.ResponseQualificationResult,
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Bool,
                                Bool,
                                WannierNLQG.Runtime.NormalizedTaskSpec,
                            },
                            WannierNLQG.Runtime.var"#cleanup!#625"{
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
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
            typeof(Base.grow_to!),
            Array{Int64, 1},
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
                            WannierNLQG.Runtime.var"#execute_point!#623"{
                                WannierNLQG.Runtime.EffectiveTaskConfig,
                                Bool,
                                Base.Val{:linear_transport},
                                WannierNLQG.MatrixElements.OrbitalCompletion,
                                Array{Array{Float64, 1}, 1},
                                Array{Array{Base.Complex{Float64}, 4}, 1},
                                NTuple{4, Symbol},
                                Array{Float64, 1},
                                Array{Tuple{Int64, Int64}, 1},
                                WannierNLQG.Runtime.FourierExecutionPlan,
                                WannierNLQG.Core.IntegralKGrid,
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Bool,
                                Bool,
                            },
                            WannierNLQG.Runtime.var"#finish!#624"{
                                WannierNLQG.Runtime.EffectiveTaskConfig,
                                WannierNLQG.Runtime.RunContext,
                                Array{Array{Base.Complex{Float64}, 4}, 1},
                                NTuple{4, Symbol},
                                Array{Tuple{Int64, Int64}, 1},
                                WannierNLQG.Runtime.FourierExecutionPlan,
                                Int64,
                                WannierNLQG.Core.IntegralKGrid,
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                                Int64,
                                Nothing,
                                WannierNLQG.Runtime.ResponseQualificationResult,
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Bool,
                                Bool,
                                WannierNLQG.Runtime.NormalizedTaskSpec,
                            },
                            WannierNLQG.Runtime.var"#cleanup!#625"{
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
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
            typeof(Base.grow_to!),
            Array{Int64, 1},
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
                            WannierNLQG.Runtime.var"#execute_point!#623"{
                                WannierNLQG.Runtime.EffectiveTaskConfig,
                                Bool,
                                Base.Val{:linear_transport},
                                WannierNLQG.MatrixElements.OrbitalCompletion,
                                Array{Array{Float64, 1}, 1},
                                Array{Array{Base.Complex{Float64}, 4}, 1},
                                NTuple{4, Symbol},
                                Array{Float64, 1},
                                Array{Tuple{Int64, Int64}, 1},
                                WannierNLQG.Runtime.FourierExecutionPlan,
                                WannierNLQG.Core.KSliceGrid2D,
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Bool,
                                Bool,
                            },
                            WannierNLQG.Runtime.var"#finish!#624"{
                                WannierNLQG.Runtime.EffectiveTaskConfig,
                                WannierNLQG.Runtime.RunContext,
                                Array{Array{Base.Complex{Float64}, 4}, 1},
                                NTuple{4, Symbol},
                                Array{Tuple{Int64, Int64}, 1},
                                WannierNLQG.Runtime.FourierExecutionPlan,
                                Int64,
                                WannierNLQG.Core.KSliceGrid2D,
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                                Int64,
                                Nothing,
                                WannierNLQG.Runtime.ResponseQualificationResult,
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Bool,
                                Bool,
                                WannierNLQG.Runtime.NormalizedTaskSpec,
                            },
                            WannierNLQG.Runtime.var"#cleanup!#625"{
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
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
            typeof(Base.grow_to!),
            Array{Int64, 1},
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
                            WannierNLQG.Runtime.var"#execute_point!#623"{
                                WannierNLQG.Runtime.EffectiveTaskConfig,
                                Bool,
                                Base.Val{:orbital_magnetization},
                                WannierNLQG.MatrixElements.OrbitalCompletion,
                                Array{Array{Float64, 1}, 1},
                                Array{Array{Base.Complex{Float64}, 4}, 1},
                                Tuple{Symbol, Symbol, Symbol},
                                Array{Float64, 1},
                                Array{Tuple{Int64}, 1},
                                WannierNLQG.Runtime.FourierExecutionPlan,
                                WannierNLQG.Core.IntegralKGrid,
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Bool,
                                Bool,
                            },
                            WannierNLQG.Runtime.var"#finish!#624"{
                                WannierNLQG.Runtime.EffectiveTaskConfig,
                                WannierNLQG.Runtime.RunContext,
                                Array{Array{Base.Complex{Float64}, 4}, 1},
                                Tuple{Symbol, Symbol, Symbol},
                                Array{Tuple{Int64}, 1},
                                WannierNLQG.Runtime.FourierExecutionPlan,
                                Int64,
                                WannierNLQG.Core.IntegralKGrid,
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                                Int64,
                                Nothing,
                                WannierNLQG.Runtime.ResponseQualificationResult,
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Bool,
                                Bool,
                                WannierNLQG.Runtime.NormalizedTaskSpec,
                            },
                            WannierNLQG.Runtime.var"#cleanup!#625"{
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
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
            typeof(Base.grow_to!),
            Array{Int64, 1},
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
                            WannierNLQG.Runtime.var"#execute_point!#623"{
                                WannierNLQG.Runtime.EffectiveTaskConfig,
                                Bool,
                                Base.Val{:orbital_magnetization},
                                WannierNLQG.MatrixElements.OrbitalCompletion,
                                Array{Array{Float64, 1}, 1},
                                Array{Array{Base.Complex{Float64}, 4}, 1},
                                Tuple{Symbol, Symbol, Symbol},
                                Array{Float64, 1},
                                Array{Tuple{Int64}, 1},
                                WannierNLQG.Runtime.FourierExecutionPlan,
                                WannierNLQG.Core.KSliceGrid2D,
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Bool,
                                Bool,
                            },
                            WannierNLQG.Runtime.var"#finish!#624"{
                                WannierNLQG.Runtime.EffectiveTaskConfig,
                                WannierNLQG.Runtime.RunContext,
                                Array{Array{Base.Complex{Float64}, 4}, 1},
                                Tuple{Symbol, Symbol, Symbol},
                                Array{Tuple{Int64}, 1},
                                WannierNLQG.Runtime.FourierExecutionPlan,
                                Int64,
                                WannierNLQG.Core.KSliceGrid2D,
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                                Int64,
                                Nothing,
                                WannierNLQG.Runtime.ResponseQualificationResult,
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Bool,
                                Bool,
                                WannierNLQG.Runtime.NormalizedTaskSpec,
                            },
                            WannierNLQG.Runtime.var"#cleanup!#625"{
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                            },
                        },
                    },
                },
                Int64,
            },
        },
    )
    false
    false
    precompile(
        Tuple{
            typeof(Base.haskey),
            Base.Dict{
                WannierNLQG.MatrixElements.KPointOffset,
                WannierNLQG.MatrixElements.KPointMatrixData{
                    WannierNLQG.MatrixElements.HamiltonianMatrixData{
                        Array{Float64, 2},
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                        Array{Base.Complex{Float64}, 3},
                    },
                    WannierNLQG.MatrixElements.PositionMatrixData{
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                        Array{Base.Complex{Float64}, 4},
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
                    Nothing,
                    Nothing,
                },
            },
            WannierNLQG.MatrixElements.KPointOffset,
        },
    )
    false
    false
    false
    false
    false
    false
    precompile(
        Tuple{
            typeof(Base.indexed_iterate),
            Pair{
                Symbol,
                Tuple{
                    WannierNLQG.Core.RealSpaceOperatorKind,
                    Vararg{WannierNLQG.Core.RealSpaceOperatorKind},
                },
            },
            Int64,
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.indexed_iterate),
            Pair{
                Symbol,
                Tuple{
                    WannierNLQG.Core.RealSpaceOperatorKind,
                    Vararg{WannierNLQG.Core.RealSpaceOperatorKind},
                },
            },
            Int64,
        },
    )
    false
    false
    precompile(
        Tuple{
            typeof(Base.indexed_iterate),
            Tuple{Symbol, WannierNLQG.MatrixElements.MatrixElementKind},
            Int64,
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.indexed_iterate),
            Tuple{Symbol, WannierNLQG.MatrixElements.MatrixElementKind},
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.indexed_iterate),
            Tuple{
                WannierNLQG.Core.RealSpaceOperatorKind,
                WannierNLQG.MatrixElements.MatrixElementKind,
                Int64,
            },
            Int64,
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.indexed_iterate),
            Tuple{
                WannierNLQG.Core.RealSpaceOperatorKind,
                WannierNLQG.MatrixElements.MatrixElementKind,
                Int64,
            },
            Int64,
        },
    )
    precompile(Tuple{typeof(Base.iterate), Array{WannierNLQG.Runtime.RunContext, 1}, Int64})
    precompile(Tuple{typeof(Base.iterate), Array{WannierNLQG.Runtime.RunContext, 1}})
    precompile(
        Tuple{
            typeof(Base.iterate),
            Base.Generator{Base.UnitRange{Int64}, WannierNLQG.Runtime.var"#608#618"},
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.iterate),
            Base.Generator{Base.UnitRange{Int64}, WannierNLQG.Runtime.var"#608#618"},
        },
    )
    precompile(
        Tuple{
            typeof(Base.iterate),
            Base.Generator{Base.UnitRange{Int64}, WannierNLQG.Runtime.var"#755#758"{Int64}},
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.iterate),
            Base.Generator{Base.UnitRange{Int64}, WannierNLQG.Runtime.var"#755#758"{Int64}},
        },
    )
    precompile(
        Tuple{
            typeof(Base.iterate),
            Base.Generator{Base.UnitRange{Int64}, WannierNLQG.Runtime.var"#756#757"},
        },
    )
    false
    false
    precompile(
        Tuple{
            typeof(Base.iterate),
            Base.Generator{Tuple{Int64, Int64}, WannierNLQG.Runtime.var"#153#155"},
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.iterate),
            Base.Generator{Tuple{Int64, Int64}, WannierNLQG.Runtime.var"#153#155"},
        },
    )
    precompile(
        Tuple{
            typeof(Base.iterate),
            Base.Generator{Tuple{Int64}, WannierNLQG.Runtime.var"#153#155"},
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.iterate),
            Base.Generator{Tuple{Int64}, WannierNLQG.Runtime.var"#153#155"},
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
                            WannierNLQG.Runtime.var"#execute_point!#623"{
                                WannierNLQG.Runtime.EffectiveTaskConfig,
                                Bool,
                                Base.Val{:linear_optical_response},
                                WannierNLQG.MatrixElements.OrbitalCompletion,
                                Array{Array{Float64, 1}, 1},
                                Array{Array{Base.Complex{Float64}, 4}, 1},
                                NTuple{4, Symbol},
                                Array{Float64, 1},
                                Array{Tuple{Int64, Int64}, 1},
                                WannierNLQG.Runtime.FourierExecutionPlan,
                                WannierNLQG.Core.IntegralKGrid,
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Bool,
                                Bool,
                            },
                            WannierNLQG.Runtime.var"#finish!#624"{
                                WannierNLQG.Runtime.EffectiveTaskConfig,
                                WannierNLQG.Runtime.RunContext,
                                Array{Array{Base.Complex{Float64}, 4}, 1},
                                NTuple{4, Symbol},
                                Array{Tuple{Int64, Int64}, 1},
                                WannierNLQG.Runtime.FourierExecutionPlan,
                                Int64,
                                WannierNLQG.Core.IntegralKGrid,
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                                Int64,
                                Nothing,
                                WannierNLQG.Runtime.ResponseQualificationResult,
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Bool,
                                Bool,
                                WannierNLQG.Runtime.NormalizedTaskSpec,
                            },
                            WannierNLQG.Runtime.var"#cleanup!#625"{
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
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
                            WannierNLQG.Runtime.var"#execute_point!#623"{
                                WannierNLQG.Runtime.EffectiveTaskConfig,
                                Bool,
                                Base.Val{:linear_optical_response},
                                WannierNLQG.MatrixElements.OrbitalCompletion,
                                Array{Array{Float64, 1}, 1},
                                Array{Array{Base.Complex{Float64}, 4}, 1},
                                NTuple{4, Symbol},
                                Array{Float64, 1},
                                Array{Tuple{Int64, Int64}, 1},
                                WannierNLQG.Runtime.FourierExecutionPlan,
                                WannierNLQG.Core.KSliceGrid2D,
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Bool,
                                Bool,
                            },
                            WannierNLQG.Runtime.var"#finish!#624"{
                                WannierNLQG.Runtime.EffectiveTaskConfig,
                                WannierNLQG.Runtime.RunContext,
                                Array{Array{Base.Complex{Float64}, 4}, 1},
                                NTuple{4, Symbol},
                                Array{Tuple{Int64, Int64}, 1},
                                WannierNLQG.Runtime.FourierExecutionPlan,
                                Int64,
                                WannierNLQG.Core.KSliceGrid2D,
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                                Int64,
                                Nothing,
                                WannierNLQG.Runtime.ResponseQualificationResult,
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Bool,
                                Bool,
                                WannierNLQG.Runtime.NormalizedTaskSpec,
                            },
                            WannierNLQG.Runtime.var"#cleanup!#625"{
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
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
                            WannierNLQG.Runtime.var"#execute_point!#623"{
                                WannierNLQG.Runtime.EffectiveTaskConfig,
                                Bool,
                                Base.Val{:linear_transport},
                                WannierNLQG.MatrixElements.OrbitalCompletion,
                                Array{Array{Float64, 1}, 1},
                                Array{Array{Base.Complex{Float64}, 4}, 1},
                                NTuple{4, Symbol},
                                Array{Float64, 1},
                                Array{Tuple{Int64, Int64}, 1},
                                WannierNLQG.Runtime.FourierExecutionPlan,
                                WannierNLQG.Core.IntegralKGrid,
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Bool,
                                Bool,
                            },
                            WannierNLQG.Runtime.var"#finish!#624"{
                                WannierNLQG.Runtime.EffectiveTaskConfig,
                                WannierNLQG.Runtime.RunContext,
                                Array{Array{Base.Complex{Float64}, 4}, 1},
                                NTuple{4, Symbol},
                                Array{Tuple{Int64, Int64}, 1},
                                WannierNLQG.Runtime.FourierExecutionPlan,
                                Int64,
                                WannierNLQG.Core.IntegralKGrid,
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                                Int64,
                                Nothing,
                                WannierNLQG.Runtime.ResponseQualificationResult,
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Bool,
                                Bool,
                                WannierNLQG.Runtime.NormalizedTaskSpec,
                            },
                            WannierNLQG.Runtime.var"#cleanup!#625"{
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
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
                            WannierNLQG.Runtime.var"#execute_point!#623"{
                                WannierNLQG.Runtime.EffectiveTaskConfig,
                                Bool,
                                Base.Val{:linear_transport},
                                WannierNLQG.MatrixElements.OrbitalCompletion,
                                Array{Array{Float64, 1}, 1},
                                Array{Array{Base.Complex{Float64}, 4}, 1},
                                NTuple{4, Symbol},
                                Array{Float64, 1},
                                Array{Tuple{Int64, Int64}, 1},
                                WannierNLQG.Runtime.FourierExecutionPlan,
                                WannierNLQG.Core.KSliceGrid2D,
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Bool,
                                Bool,
                            },
                            WannierNLQG.Runtime.var"#finish!#624"{
                                WannierNLQG.Runtime.EffectiveTaskConfig,
                                WannierNLQG.Runtime.RunContext,
                                Array{Array{Base.Complex{Float64}, 4}, 1},
                                NTuple{4, Symbol},
                                Array{Tuple{Int64, Int64}, 1},
                                WannierNLQG.Runtime.FourierExecutionPlan,
                                Int64,
                                WannierNLQG.Core.KSliceGrid2D,
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                                Int64,
                                Nothing,
                                WannierNLQG.Runtime.ResponseQualificationResult,
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Bool,
                                Bool,
                                WannierNLQG.Runtime.NormalizedTaskSpec,
                            },
                            WannierNLQG.Runtime.var"#cleanup!#625"{
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
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
                            WannierNLQG.Runtime.var"#execute_point!#623"{
                                WannierNLQG.Runtime.EffectiveTaskConfig,
                                Bool,
                                Base.Val{:orbital_magnetization},
                                WannierNLQG.MatrixElements.OrbitalCompletion,
                                Array{Array{Float64, 1}, 1},
                                Array{Array{Base.Complex{Float64}, 4}, 1},
                                Tuple{Symbol, Symbol, Symbol},
                                Array{Float64, 1},
                                Array{Tuple{Int64}, 1},
                                WannierNLQG.Runtime.FourierExecutionPlan,
                                WannierNLQG.Core.IntegralKGrid,
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Bool,
                                Bool,
                            },
                            WannierNLQG.Runtime.var"#finish!#624"{
                                WannierNLQG.Runtime.EffectiveTaskConfig,
                                WannierNLQG.Runtime.RunContext,
                                Array{Array{Base.Complex{Float64}, 4}, 1},
                                Tuple{Symbol, Symbol, Symbol},
                                Array{Tuple{Int64}, 1},
                                WannierNLQG.Runtime.FourierExecutionPlan,
                                Int64,
                                WannierNLQG.Core.IntegralKGrid,
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                                Int64,
                                Nothing,
                                WannierNLQG.Runtime.ResponseQualificationResult,
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Bool,
                                Bool,
                                WannierNLQG.Runtime.NormalizedTaskSpec,
                            },
                            WannierNLQG.Runtime.var"#cleanup!#625"{
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
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
                            WannierNLQG.Runtime.var"#execute_point!#623"{
                                WannierNLQG.Runtime.EffectiveTaskConfig,
                                Bool,
                                Base.Val{:orbital_magnetization},
                                WannierNLQG.MatrixElements.OrbitalCompletion,
                                Array{Array{Float64, 1}, 1},
                                Array{Array{Base.Complex{Float64}, 4}, 1},
                                Tuple{Symbol, Symbol, Symbol},
                                Array{Float64, 1},
                                Array{Tuple{Int64}, 1},
                                WannierNLQG.Runtime.FourierExecutionPlan,
                                WannierNLQG.Core.KSliceGrid2D,
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Bool,
                                Bool,
                            },
                            WannierNLQG.Runtime.var"#finish!#624"{
                                WannierNLQG.Runtime.EffectiveTaskConfig,
                                WannierNLQG.Runtime.RunContext,
                                Array{Array{Base.Complex{Float64}, 4}, 1},
                                Tuple{Symbol, Symbol, Symbol},
                                Array{Tuple{Int64}, 1},
                                WannierNLQG.Runtime.FourierExecutionPlan,
                                Int64,
                                WannierNLQG.Core.KSliceGrid2D,
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
                                Int64,
                                Nothing,
                                WannierNLQG.Runtime.ResponseQualificationResult,
                                WannierNLQG.Core.TightBindingModel{
                                    Array{Base.Complex{Float64}, 3},
                                    Array{Base.Complex{Float64}, 4},
                                },
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Bool,
                                Bool,
                                WannierNLQG.Runtime.NormalizedTaskSpec,
                            },
                            WannierNLQG.Runtime.var"#cleanup!#625"{
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                                Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
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
                                            Array{Base.Complex{Float64}, 4},
                                        },
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Nothing,
                                        Symbol,
                                        Nothing,
                                        Nothing,
                                        WannierNLQG.Runtime.RuntimeReplicaSummary,
                                    },
                                },
                            },
                        },
                    },
                },
                Int64,
            },
        },
    )
    false
    precompile(
        Tuple{
            typeof(Base.iterate),
            Base.Pairs{
                Symbol,
                Tuple{
                    WannierNLQG.Core.RealSpaceOperatorKind,
                    Vararg{WannierNLQG.Core.RealSpaceOperatorKind},
                },
                Tuple{Symbol, Symbol, Symbol},
                NamedTuple{
                    (:internal_connection, :gauge_correction, :berry_connection),
                    Tuple{
                        Tuple{
                            WannierNLQG.Core.RealSpaceOperatorKind,
                            WannierNLQG.Core.RealSpaceOperatorKind,
                        },
                        Tuple{WannierNLQG.Core.RealSpaceOperatorKind},
                        Tuple{
                            WannierNLQG.Core.RealSpaceOperatorKind,
                            WannierNLQG.Core.RealSpaceOperatorKind,
                        },
                    },
                },
            },
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.iterate),
            Base.Pairs{
                Symbol,
                Tuple{
                    WannierNLQG.Core.RealSpaceOperatorKind,
                    Vararg{WannierNLQG.Core.RealSpaceOperatorKind},
                },
                Tuple{Symbol, Symbol, Symbol},
                NamedTuple{
                    (:internal_connection, :gauge_correction, :berry_connection),
                    Tuple{
                        Tuple{
                            WannierNLQG.Core.RealSpaceOperatorKind,
                            WannierNLQG.Core.RealSpaceOperatorKind,
                        },
                        Tuple{WannierNLQG.Core.RealSpaceOperatorKind},
                        Tuple{
                            WannierNLQG.Core.RealSpaceOperatorKind,
                            WannierNLQG.Core.RealSpaceOperatorKind,
                        },
                    },
                },
            },
        },
    )
    precompile(
        Tuple{
            typeof(Base.join),
            Base.Generator{
                Array{Float64, 1},
                WannierNLQG.IO.var"#172#176"{
                    Printf.Format{
                        Base.CodeUnits{UInt8, String},
                        Tuple{Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}}},
                    },
                },
            },
            String,
        },
    )
    false
    false
    false
    false
    false
    precompile(
        Tuple{typeof(Base.map), Function, Array{WannierNLQG.Runtime.BandStructureBundlePlan, 1}},
    )
    precompile(Tuple{typeof(Base.map), Function, Array{WannierNLQG.Runtime.IntegralBundlePlan, 1}})
    precompile(Tuple{typeof(Base.map), Function, Array{WannierNLQG.Runtime.KSliceBundlePlan, 1}})
    false
    false
    false
    false
    precompile(
        Tuple{
            typeof(Base.pairs),
            NamedTuple{
                (:internal_connection, :gauge_correction, :berry_connection),
                Tuple{
                    Tuple{
                        WannierNLQG.Core.RealSpaceOperatorKind,
                        WannierNLQG.Core.RealSpaceOperatorKind,
                    },
                    Tuple{WannierNLQG.Core.RealSpaceOperatorKind},
                    Tuple{
                        WannierNLQG.Core.RealSpaceOperatorKind,
                        WannierNLQG.Core.RealSpaceOperatorKind,
                    },
                },
            },
        },
    )
    precompile(
        Tuple{
            typeof(Base.push!),
            Array{
                WannierNLQG.MatrixElements.MatrixElementWorkspace{
                    D,
                    S,
                    I,
                } where {I} where {S} where D,
                1,
            },
            WannierNLQG.FIRST_USE_WORKSPACE_TYPES[2],
        },
    )
    false
    precompile(
        Tuple{
            typeof(Base.setindex!),
            Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
            NamedTuple{
                (:kind, :component_indices, :length_elements, :logical_shape),
                Tuple{
                    WannierNLQG.Core.RealSpaceOperatorKind,
                    Tuple{Int8, Int8},
                    Int64,
                    Tuple{Int64, Int64, Int64},
                },
            },
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.setindex!),
            Base.Dict{
                WannierNLQG.MatrixElements.KPointOffset,
                WannierNLQG.MatrixElements.KPointMatrixData{
                    WannierNLQG.MatrixElements.HamiltonianMatrixData{
                        Array{Float64, 2},
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                        Array{Base.Complex{Float64}, 3},
                    },
                    WannierNLQG.MatrixElements.PositionMatrixData{
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 3},
                        Array{Base.Complex{Float64}, 4},
                        Array{Base.Complex{Float64}, 4},
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
                    Nothing,
                    Nothing,
                },
            },
            WannierNLQG.MatrixElements.KPointMatrixData{
                WannierNLQG.MatrixElements.HamiltonianMatrixData{
                    Array{Float64, 2},
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                    Array{Base.Complex{Float64}, 3},
                },
                WannierNLQG.MatrixElements.PositionMatrixData{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                    Array{Base.Complex{Float64}, 4},
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
                Nothing,
                Nothing,
            },
            WannierNLQG.MatrixElements.KPointOffset,
        },
    )
    false
    false
    false
    false
    precompile(
        Tuple{
            typeof(Base.setindex_widen_up_to),
            Array{WannierNLQG.Runtime.ModelInput, 1},
            WannierNLQG.Runtime.BZMesh,
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.setindex_widen_up_to),
            Array{WannierNLQG.Runtime.ModelInput, 1},
            WannierNLQG.Runtime.KPath,
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.setindex_widen_up_to),
            Array{WannierNLQG.Runtime.ModelInput, 1},
            WannierNLQG.Runtime.KSlice,
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.setproperty!),
            WannierNLQG.MatrixElements.SharedInterpolationCache,
            Symbol,
            Int64,
        },
    )
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    precompile(
        Tuple{
            typeof(Base.tail),
            Tuple{
                Int64,
                Base.Generator{Base.UnitRange{Int64}, WannierNLQG.Runtime.var"#755#758"{Int64}},
                Int64,
            },
        },
    )
    precompile(
        Tuple{
            typeof(Base.unique_from),
            Base.Generator{
                Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1},
                WannierNLQG.Runtime.var"#109#110"{WannierNLQG.Runtime.EffectiveTaskConfig},
            },
            Array{Tuple{Int64, Int64, Int64}, 1},
            Base.Set{Tuple{Int64, Int64, Int64}},
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.unique_from),
            Base.Generator{
                Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1},
                WannierNLQG.Runtime.var"#462#463"{WannierNLQG.Runtime.EffectiveTaskConfig},
            },
            Array{Tuple{Int64, Int64, Int64}, 1},
            Base.Set{Tuple{Int64, Int64, Int64}},
            Int64,
        },
    )
    false
    false
    false
    false
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{
                (
                    :case_root,
                    :model_file,
                    :real_space_replica_policy,
                    :wsvec_file,
                    :mp_grid,
                    :wigner_seitz_tolerance,
                    :wigner_seitz_search_size,
                    :wannier_center_convention,
                ),
                Tuple{
                    String,
                    String,
                    String,
                    String,
                    Tuple{Int64, Int64, Int64},
                    Float64,
                    Int64,
                    String,
                },
            },
            Type{WannierNLQG.Runtime.ModelInput},
        },
    )
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{(:comm,), Tuple{MPI.Comm}},
            typeof(WannierNLQG.Runtime.bundle_mpi_root_call),
            Function,
        },
    )
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{(:comm,), Tuple{Nothing}},
            typeof(WannierNLQG.Runtime.bundle_mpi_root_call),
            Function,
        },
    )
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{(:copy_data,), Tuple{Bool}},
            Type{
                WannierNLQG.Core.TightBindingModel{
                    H,
                    P,
                } where {
                    P <: AbstractArray{Base.Complex{Float64}, 4},
                } where H <: AbstractArray{Base.Complex{Float64}, 3},
            },
            Array{Float64, 2},
            Int64,
            Int64,
            Array{Int64, 1},
            Array{Int64, 2},
            Array{Base.Complex{Float64}, 3},
            WannierNLQG.IO.PackedCartesianOperator{1, 4, Array{Base.Complex{Float64}, 3}},
        },
    )
    false
    false
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{(:fermi_energy,), Tuple{Float64}},
            Type{WannierNLQG.Runtime.BandParameters},
        },
    )
    false
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{(:gamma_intra_ev, :gamma_inter_ev), Tuple{Float64, Float64}},
            Type{WannierNLQG.Runtime.SeparateRelaxation},
        },
    )
    false
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{(:hermiticity_tolerance,), Tuple{Float64}},
            Type{WannierNLQG.Runtime.BandNumerics},
        },
    )
    false
    false
    false
    false
    false
    false
    false
    false
    false
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{(:init,), Tuple{UInt64}},
            typeof(Base.foldl),
            Function,
            NTuple{4, WannierNLQG.MatrixElements.MatrixElementKind},
        },
    )
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{(:init,), Tuple{UInt64}},
            typeof(Base.foldl),
            Function,
            Tuple{WannierNLQG.MatrixElements.MatrixElementKind},
        },
    )
    false
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{
                (
                    :matrix_families,
                    :family_counts,
                    :fourier_summary,
                    :band_summary,
                    :replica_summary,
                    :qualification_summary,
                ),
                Tuple{
                    Array{String, 1},
                    Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                    NamedTuple{
                        (
                            :backend,
                            :NKdiv,
                            :NKFFT,
                            :factor_source,
                            :estimated_memory_bytes,
                            :memory_limit_bytes,
                            :path_kpoint_count,
                            :mpi_size,
                            :julia_threads,
                        ),
                        Tuple{Symbol, Nothing, Nothing, Symbol, Vararg{Int64, 5}},
                    },
                    NamedTuple{
                        (
                            :schema,
                            :total_kpoints,
                            :node_count,
                            :segment_count,
                            :E_ref_eV,
                            :energy_unit,
                            :distance_unit,
                            :energy_convention,
                            :fourier_phase,
                            :reciprocal_lattice,
                            :maximum_hermiticity_residual,
                            :hermiticity_tolerance,
                            :requested_replica_policy,
                            :effective_replica_policy,
                            :replica_source,
                            :mp_grid,
                            :wigner_seitz_tolerance,
                            :wigner_seitz_search_size,
                            :replica_mapping_sha256,
                            :replica_mapping_digest_scheme,
                            :wsvec_file,
                            :wsvec_sha256,
                            :input_minimum_distance_materialized,
                            :output_minimum_distance_materialized,
                            :replica_transformed_this_run,
                            :input_num_r_vectors,
                            :effective_num_r_vectors,
                            :lattice_A,
                            :reciprocal_lattice_A_inverse,
                            :r_vector_support_minimum,
                            :r_vector_support_maximum,
                            :r_vector_support_sha256,
                            :degeneracy_count,
                            :degeneracy_minimum,
                            :degeneracy_maximum,
                            :degeneracy_sum,
                            :degeneracy_sha256,
                            :wannier90_degeneracy_applied,
                            :model_num_orbitals,
                            :qualification,
                            :production_eligible,
                            :qualification_note,
                            :manifest_schema,
                            :manifest_scientific_sha256,
                            :manifest_geometry_sha256,
                            :manifest_file_sha256,
                            :manifest_paired_tb_sha256,
                            :manifest_hamiltonian_component_sha256,
                            :manifest_quality_review_recommended,
                            :manifest_physics_qualification,
                            :manifest_tb_usability,
                            :manifest_final_physics_qualification,
                            :manifest_final_production_eligible,
                            :kpath_json,
                        ),
                        Tuple{
                            String,
                            Int64,
                            Int64,
                            Int64,
                            Float64,
                            String,
                            String,
                            String,
                            String,
                            String,
                            Float64,
                            Float64,
                            Symbol,
                            Symbol,
                            Symbol,
                            Tuple{Int64, Int64, Int64},
                            Float64,
                            Int64,
                            String,
                            String,
                            String,
                            String,
                            Bool,
                            Bool,
                            Bool,
                            Int64,
                            Int64,
                            Array{Float64, 2},
                            Array{Float64, 2},
                            Tuple{Int64, Int64, Int64},
                            Tuple{Int64, Int64, Int64},
                            String,
                            Int64,
                            Int64,
                            Int64,
                            Int64,
                            String,
                            Bool,
                            Int64,
                            String,
                            Bool,
                            String,
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
                            String,
                        },
                    },
                    NamedTuple{
                        (
                            :schema,
                            :requested_policy,
                            :effective_policy,
                            :source,
                            :mapping_sha256,
                            :mapping_digest_scheme,
                            :wsvec_file,
                            :wsvec_sha256,
                            :mp_grid,
                            :wigner_seitz_tolerance,
                            :wigner_seitz_search_size,
                            :input_minimum_distance_materialized,
                            :output_minimum_distance_materialized,
                            :replica_transformed_this_run,
                            :input_num_r_vectors,
                            :effective_num_r_vectors,
                            :scalar_degeneracy_applied,
                            :pair_degeneracy_applied,
                        ),
                        Tuple{
                            String,
                            Symbol,
                            Symbol,
                            Symbol,
                            String,
                            String,
                            String,
                            String,
                            Tuple{Int64, Int64, Int64},
                            Float64,
                            Int64,
                            Bool,
                            Bool,
                            Bool,
                            Int64,
                            Int64,
                            Bool,
                            Bool,
                        },
                    },
                    NamedTuple{
                        (
                            :execution_eligible,
                            :qualification_status,
                            :production_eligible,
                            :quality_review_recommended,
                            :reasons,
                            :verified_contracts,
                            :unverified_contracts,
                            :conflicting_contracts,
                            :input_qualification,
                        ),
                        Tuple{
                            Bool,
                            String,
                            Bool,
                            Bool,
                            Array{String, 1},
                            Array{String, 1},
                            Array{String, 1},
                            Array{String, 1},
                            Base.Dict{String, Any},
                        },
                    },
                },
            },
            typeof(WannierNLQG.Runtime.write_metadata),
            WannierNLQG.Runtime.EffectiveTaskConfig,
            WannierNLQG.Runtime.RunContext,
            Array{String, 1},
            String,
        },
    )
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{
                (
                    :matrix_families,
                    :family_counts,
                    :fourier_summary,
                    :response_symmetry_summary,
                    :replica_summary,
                    :qualification_summary,
                    :metadata_centers,
                ),
                Tuple{
                    Array{String, 1},
                    Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                    NamedTuple{
                        (
                            :backend,
                            :NKdiv,
                            :NKFFT,
                            :factor_source,
                            :estimated_memory_bytes,
                            :memory_limit_bytes,
                            :load_imbalance,
                            :blocks_per_rank,
                            :kpoints_per_rank,
                            :task_signatures,
                            :union_capabilities,
                            :union_fourier_groups,
                            :union_offset_signatures,
                            :union_group_offset_counts,
                            :groups,
                            :offset_count,
                            :cache_entries,
                            :allocated_bytes,
                            :allocated_memory_limit_bytes,
                            :pack_seconds,
                            :fft_seconds,
                            :extract_seconds,
                            :fft_calls,
                            :cache_hits,
                            :evictions,
                        ),
                        Tuple{
                            Symbol,
                            Nothing,
                            Nothing,
                            Symbol,
                            Int64,
                            Int64,
                            Float64,
                            Array{Int64, 1},
                            Array{Int64, 1},
                            Array{String, 1},
                            Array{Symbol, 1},
                            Array{Symbol, 1},
                            Array{String, 1},
                            Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                            Array{String, 1},
                            Int64,
                            Int64,
                            Int64,
                            Int64,
                            Float64,
                            Float64,
                            Float64,
                            Int64,
                            Int64,
                            Int64,
                        },
                    },
                    NamedTuple{(), Tuple{}},
                    NamedTuple{
                        (
                            :schema,
                            :requested_policy,
                            :effective_policy,
                            :source,
                            :mapping_sha256,
                            :mapping_digest_scheme,
                            :wsvec_file,
                            :wsvec_sha256,
                            :mp_grid,
                            :wigner_seitz_tolerance,
                            :wigner_seitz_search_size,
                            :input_minimum_distance_materialized,
                            :output_minimum_distance_materialized,
                            :replica_transformed_this_run,
                            :input_num_r_vectors,
                            :effective_num_r_vectors,
                            :scalar_degeneracy_applied,
                            :pair_degeneracy_applied,
                        ),
                        Tuple{
                            String,
                            Symbol,
                            Symbol,
                            Symbol,
                            String,
                            String,
                            Nothing,
                            Nothing,
                            Nothing,
                            Float64,
                            Int64,
                            Bool,
                            Bool,
                            Bool,
                            Int64,
                            Int64,
                            Bool,
                            Bool,
                        },
                    },
                    NamedTuple{
                        (
                            :execution_eligible,
                            :qualification_status,
                            :production_eligible,
                            :quality_review_recommended,
                            :reasons,
                            :verified_contracts,
                            :unverified_contracts,
                            :conflicting_contracts,
                            :input_qualification,
                        ),
                        Tuple{
                            Bool,
                            String,
                            Bool,
                            Bool,
                            Array{String, 1},
                            Array{String, 1},
                            Array{String, 1},
                            Array{String, 1},
                            Base.Dict{String, Any},
                        },
                    },
                    Nothing,
                },
            },
            typeof(WannierNLQG.Runtime.write_metadata),
            WannierNLQG.Runtime.EffectiveTaskConfig,
            WannierNLQG.Runtime.RunContext,
            Array{String, 1},
            String,
        },
    )
    false
    false
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{
                (:model, :sampling, :tasks, :execution, :output),
                Tuple{
                    WannierNLQG.Runtime.ModelInput,
                    WannierNLQG.Runtime.BZMesh,
                    Array{WannierNLQG.Runtime.TaskSpec, 1},
                    WannierNLQG.Runtime.ExecutionOptions,
                    WannierNLQG.Runtime.OutputOptions,
                },
            },
            Type{WannierNLQG.Runtime.TaskConfig},
        },
    )
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{
                (:model, :sampling, :tasks, :execution, :output),
                Tuple{
                    WannierNLQG.Runtime.ModelInput,
                    WannierNLQG.Runtime.KPath,
                    Array{WannierNLQG.Runtime.TaskSpec, 1},
                    WannierNLQG.Runtime.ExecutionOptions,
                    WannierNLQG.Runtime.OutputOptions,
                },
            },
            Type{WannierNLQG.Runtime.TaskConfig},
        },
    )
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{
                (:model, :sampling, :tasks, :execution, :output),
                Tuple{
                    WannierNLQG.Runtime.ModelInput,
                    WannierNLQG.Runtime.KSlice,
                    Array{WannierNLQG.Runtime.TaskSpec, 1},
                    WannierNLQG.Runtime.ExecutionOptions,
                    WannierNLQG.Runtime.OutputOptions,
                },
            },
            Type{WannierNLQG.Runtime.TaskConfig},
        },
    )
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
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
                    :fermi_energies,
                    :fermi_energies_sha256,
                    :fermi_energy,
                    :temperature,
                    :photon_energies,
                    :gamma_intra_ev,
                    :gamma_inter_ev,
                    :spectral_gap_tolerance,
                    :denominator_regularization,
                    :degeneracy_threshold,
                    :tasks,
                ),
                Tuple{
                    String,
                    Nothing,
                    String,
                    String,
                    String,
                    String,
                    Nothing,
                    Nothing,
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                    Tuple{Int64, Int64},
                    Int64,
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
                    Nothing,
                    String,
                    Tuple{Int64, Int64},
                    Int64,
                    Bool,
                    Array{Float64, 1},
                    String,
                    Float64,
                    Float64,
                    Array{Float64, 1},
                    Float64,
                    Float64,
                    Float64,
                    Float64,
                    Float64,
                    Array{Tuple{String, String, String}, 1},
                },
            },
            Type{WannierNLQG.Runtime.EffectiveTaskConfig},
        },
    )
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
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
                    :fermi_energies,
                    :fermi_energies_sha256,
                    :temperature,
                    :photon_energies,
                    :orbital_input_semantics,
                    :spectral_gap_tolerance,
                    :denominator_regularization,
                    :degeneracy_threshold,
                    :tasks,
                ),
                Tuple{
                    String,
                    Nothing,
                    String,
                    String,
                    String,
                    String,
                    Nothing,
                    Nothing,
                    Float64,
                    Int64,
                    Bool,
                    String,
                    String,
                    Bool,
                    Tuple{Int64, Int64},
                    Int64,
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
                    Nothing,
                    String,
                    Tuple{Int64},
                    Int64,
                    Bool,
                    Array{Float64, 1},
                    String,
                    Float64,
                    Array{Float64, 1},
                    Symbol,
                    Float64,
                    Float64,
                    Float64,
                    Array{Tuple{String, String, String}, 1},
                },
            },
            Type{WannierNLQG.Runtime.EffectiveTaskConfig},
        },
    )
    false
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
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
                    :kpath_nodes,
                    :kpoints_per_segment,
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
                    :fermi_energy,
                    :photon_energies,
                    :band_hermiticity_tolerance,
                    :tasks,
                ),
                Tuple{
                    String,
                    Nothing,
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
                    Tuple{Int64, Int64, Int64},
                    Int64,
                    Array{Tuple{String, Tuple{Float64, Float64, Float64}}, 1},
                    Array{Int64, 1},
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
                    Nothing,
                    String,
                    Tuple{},
                    Int64,
                    Bool,
                    Float64,
                    Array{Float64, 1},
                    Float64,
                    Array{Tuple{String, String, String}, 1},
                },
            },
            Type{WannierNLQG.Runtime.EffectiveTaskConfig},
        },
    )
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
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
                    :fermi_energies,
                    :fermi_energies_sha256,
                    :fermi_energy,
                    :temperature,
                    :photon_energies,
                    :gamma_intra_ev,
                    :gamma_inter_ev,
                    :spectral_gap_tolerance,
                    :denominator_regularization,
                    :degeneracy_threshold,
                    :tasks,
                ),
                Tuple{
                    String,
                    Nothing,
                    String,
                    String,
                    String,
                    String,
                    Nothing,
                    Nothing,
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
                    Nothing,
                    String,
                    Tuple{Int64, Int64},
                    Int64,
                    Bool,
                    Array{Float64, 1},
                    String,
                    Float64,
                    Float64,
                    Array{Float64, 1},
                    Float64,
                    Float64,
                    Float64,
                    Float64,
                    Float64,
                    Array{Tuple{String, String, String}, 1},
                },
            },
            Type{WannierNLQG.Runtime.EffectiveTaskConfig},
        },
    )
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
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
                    :fermi_energies,
                    :fermi_energies_sha256,
                    :temperature,
                    :photon_energies,
                    :orbital_input_semantics,
                    :spectral_gap_tolerance,
                    :denominator_regularization,
                    :degeneracy_threshold,
                    :tasks,
                ),
                Tuple{
                    String,
                    Nothing,
                    String,
                    String,
                    String,
                    String,
                    Nothing,
                    Nothing,
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
                    Nothing,
                    String,
                    Tuple{Int64},
                    Int64,
                    Bool,
                    Array{Float64, 1},
                    String,
                    Float64,
                    Array{Float64, 1},
                    Symbol,
                    Float64,
                    Float64,
                    Float64,
                    Array{Tuple{String, String, String}, 1},
                },
            },
            Type{WannierNLQG.Runtime.EffectiveTaskConfig},
        },
    )
    false
    false
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{
                (
                    :output_root,
                    :system_name,
                    :response_output_digits,
                    :progress_enabled,
                    :progress_percent_interval,
                    :progress_verbosity,
                ),
                Tuple{String, String, Int64, Bool, Nothing, String},
            },
            Type{WannierNLQG.Runtime.OutputOptions},
        },
    )
    false
    false
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{
                (
                    :prepare_only,
                    :block_local_order,
                    :progress_owner,
                    :shared_sources,
                    :mixed_memory_limit_bytes,
                ),
                Tuple{
                    Bool,
                    Bool,
                    Bool,
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                    Int64,
                },
            },
            typeof(WannierNLQG.Runtime._run_integral_bundle_fused!),
            WannierNLQG.Runtime.EffectiveTaskConfig,
            WannierNLQG.Runtime.RunContext,
            Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1},
            WannierNLQG.Runtime.NormalizedRunControls,
        },
    )
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{
                (
                    :prepare_only,
                    :block_local_order,
                    :progress_owner,
                    :shared_sources,
                    :mixed_memory_limit_bytes,
                ),
                Tuple{
                    Bool,
                    Bool,
                    Bool,
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
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            WannierNLQG.Runtime.MPISharedOperatorStorage,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                    Int64,
                },
            },
            typeof(WannierNLQG.Runtime._run_integral_bundle_fused!),
            WannierNLQG.Runtime.EffectiveTaskConfig,
            WannierNLQG.Runtime.RunContext,
            Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1},
            WannierNLQG.Runtime.NormalizedRunControls,
        },
    )
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{
                (:prepare_only, :progress_owner, :shared_sources, :mixed_memory_limit_bytes),
                Tuple{
                    Bool,
                    Bool,
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
                                Array{Base.Complex{Float64}, 4},
                            },
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Nothing,
                            Symbol,
                            Nothing,
                            Nothing,
                            WannierNLQG.Runtime.RuntimeReplicaSummary,
                        },
                    },
                    Int64,
                },
            },
            typeof(WannierNLQG.Runtime._run_kslice_bundle_fused!),
            WannierNLQG.Runtime.EffectiveTaskConfig,
            WannierNLQG.Runtime.RunContext,
            Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1},
        },
    )
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{(:rank_memory_limit_bytes,), Tuple{Int64}},
            typeof(WannierNLQG.Runtime.build_fourier_execution_plan),
            WannierNLQG.Runtime.EffectiveTaskConfig,
            Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1},
            WannierNLQG.Core.TightBindingModel{
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 4},
            },
            WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3],
            Int64,
            Int64,
            WannierNLQG.Runtime.var"#606#616"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
            },
        },
    )
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{(:rank_memory_limit_bytes,), Tuple{Int64}},
            typeof(WannierNLQG.Runtime.build_fourier_execution_plan),
            WannierNLQG.Runtime.EffectiveTaskConfig,
            Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1},
            WannierNLQG.Core.TightBindingModel{
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 4},
            },
            WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3],
            Int64,
            Int64,
            WannierNLQG.Runtime.var"#607#617"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    Array{Base.Complex{Float64}, 4},
                },
            },
        },
    )
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{(:rank_memory_limit_bytes,), Tuple{Int64}},
            typeof(WannierNLQG.Runtime.build_fourier_execution_plan),
            WannierNLQG.Runtime.EffectiveTaskConfig,
            Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1},
            WannierNLQG.Core.TightBindingModel{
                Array{Base.Complex{Float64}, 3},
                WannierNLQG.IO.PackedCartesianOperator{1, 4, Array{Base.Complex{Float64}, 3}},
            },
            WannierNLQG.FIRST_USE_WORKSPACE_TYPES[2],
            Int64,
            Int64,
            WannierNLQG.Runtime.var"#652#675"{
                WannierNLQG.Runtime.EffectiveTaskConfig,
                WannierNLQG.Core.TightBindingModel{
                    Array{Base.Complex{Float64}, 3},
                    WannierNLQG.IO.PackedCartesianOperator{1, 4, Array{Base.Complex{Float64}, 3}},
                },
            },
        },
    )
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{
                (:read_mode, :fallback_reason, :storage_owner),
                Tuple{Symbol, Nothing, Nothing},
            },
            typeof(WannierNLQG.Runtime._runtime_sources_from_legacy_components),
            Base.Dict{
                WannierNLQG.Core.RealSpaceOperatorKind,
                Base.Dict{Tuple{Int8, Int8}, AbstractArray{Base.Complex{Float64}, 3}},
            },
            NamedTuple{
                (:ok, :metadata, :entries, :replica_summary, :error),
                Tuple{
                    Bool,
                    NamedTuple{
                        (
                            :lattice,
                            :num_orbitals,
                            :r_vectors,
                            :degeneracies,
                            :has_spin,
                            :has_spin_velocity,
                            :diagnostics,
                        ),
                        Tuple{
                            Array{Float64, 2},
                            Int64,
                            Array{Int64, 2},
                            Array{Int64, 1},
                            Bool,
                            Bool,
                            Nothing,
                        },
                    },
                    Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                    WannierNLQG.Runtime.RuntimeReplicaSummary,
                    String,
                },
            },
        },
    )
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{
                (:read_mode, :fallback_reason, :storage_owner),
                Tuple{Symbol, Nothing, WannierNLQG.Runtime.MPISharedOperatorStorage},
            },
            typeof(WannierNLQG.Runtime._runtime_sources_from_legacy_components),
            Base.Dict{
                WannierNLQG.Core.RealSpaceOperatorKind,
                Base.Dict{Tuple{Int8, Int8}, AbstractArray{Base.Complex{Float64}, 3}},
            },
            NamedTuple{
                (:ok, :metadata, :entries, :replica_summary, :error),
                Tuple{
                    Bool,
                    NamedTuple{
                        (
                            :lattice,
                            :num_orbitals,
                            :r_vectors,
                            :degeneracies,
                            :has_spin,
                            :has_spin_velocity,
                            :diagnostics,
                        ),
                        Tuple{
                            Array{Float64, 2},
                            Int64,
                            Array{Int64, 2},
                            Array{Int64, 1},
                            Bool,
                            Bool,
                            Nothing,
                        },
                    },
                    Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                    WannierNLQG.Runtime.RuntimeReplicaSummary,
                    String,
                },
            },
        },
    )
    false
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{
                (:spatial_dimension, :denominator_regularization, :degeneracy_threshold),
                Tuple{Int64, Float64, Float64},
            },
            Type{WannierNLQG.MatrixElements.MatrixElementRequest},
            WannierNLQG.MatrixElements.MatrixElementKind,
            Vararg{WannierNLQG.MatrixElements.MatrixElementKind},
        },
    )
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{
                (:spatial_dimension, :denominator_regularization, :degeneracy_threshold),
                Tuple{Int64, Float64, Float64},
            },
            Type{WannierNLQG.MatrixElements.MatrixElementRequest},
            WannierNLQG.MatrixElements.MatrixElementKind,
        },
    )
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    precompile(
        Tuple{
            typeof(MPI.bcast),
            NamedTuple{
                (:ok, :metadata, :entries, :replica_summary, :error),
                Tuple{
                    Bool,
                    NamedTuple{
                        (
                            :lattice,
                            :num_orbitals,
                            :r_vectors,
                            :degeneracies,
                            :has_spin,
                            :has_spin_velocity,
                            :diagnostics,
                        ),
                        Tuple{
                            Array{Float64, 2},
                            Int64,
                            Array{Int64, 2},
                            Array{Int64, 1},
                            Bool,
                            Bool,
                            Nothing,
                        },
                    },
                    Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                    WannierNLQG.Runtime.RuntimeReplicaSummary,
                    String,
                },
            },
            Int64,
            MPI.Comm,
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Core._operator_selection_digest),
            Tuple{Tuple{Symbol, Symbol}},
            Tuple{WannierNLQG.Core.RealSpaceOperatorKind, WannierNLQG.Core.RealSpaceOperatorKind},
            NTuple{4, Symbol},
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Core.normalize_cartesian_indices),
            Tuple{Int64, Int64, Int64},
            Array{Int64, 1},
            String,
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Core.normalize_cartesian_indices),
            Tuple{Int64, Int64},
            Array{Int64, 1},
            String,
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Core.normalize_cartesian_indices),
            Tuple{Int64},
            Array{Int64, 1},
            String,
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.MatrixElements.disable_fourier_timing!),
            WannierNLQG.FIRST_USE_WORKSPACE_TYPES[2],
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.MatrixElements.disable_mixed_fourier!),
            WannierNLQG.FIRST_USE_WORKSPACE_TYPES[2],
        },
    )
    false
    precompile(
        Tuple{
            typeof(WannierNLQG.MatrixElements.prepare_real_space!),
            WannierNLQG.FIRST_USE_WORKSPACE_TYPES[1],
            WannierNLQG.Core.TightBindingModel{
                Array{Base.Complex{Float64}, 3},
                WannierNLQG.IO.PackedCartesianOperator{1, 4, Array{Base.Complex{Float64}, 3}},
            },
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.MatrixElements.prepare_real_space!),
            WannierNLQG.FIRST_USE_WORKSPACE_TYPES[2],
            WannierNLQG.Core.TightBindingModel{
                Array{Base.Complex{Float64}, 3},
                WannierNLQG.IO.PackedCartesianOperator{1, 4, Array{Base.Complex{Float64}, 3}},
            },
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.MatrixElements.prepare_real_space!),
            WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3],
            WannierNLQG.Core.TightBindingModel{
                Array{Base.Complex{Float64}, 3},
                Array{Base.Complex{Float64}, 4},
            },
        },
    )
    false
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime._find_integral_state),
            Array{WannierNLQG.Runtime.IntegralTaskAccumulator{4}, 1},
            Symbol,
            Symbol,
            Base.Val{4},
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime._find_integral_state),
            Array{WannierNLQG.Runtime.IntegralTaskAccumulator{4}, 1},
            Symbol,
            Symbol,
            Base.Val{5},
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime._mpi_allocate_locked_shared_window),
            Type,
            Int64,
            MPI.Comm,
        },
    )
    precompile(Tuple{typeof(WannierNLQG.Runtime._mpi_publish_shared_window!), MPI.Win, MPI.Comm})
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime._public_task_identity),
            WannierNLQG.Runtime.TaskSpec,
            WannierNLQG.Runtime.BZMesh,
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime._public_task_identity),
            WannierNLQG.Runtime.TaskSpec,
            WannierNLQG.Runtime.KPath,
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime._public_task_identity),
            WannierNLQG.Runtime.TaskSpec,
            WannierNLQG.Runtime.KSlice,
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime._task_physics),
            WannierNLQG.Runtime.TaskSpec,
            Symbol,
            Symbol,
            WannierNLQG.Runtime.TaskDefinition,
            NamedTuple{
                (:tensor_indices, :band_selection, :include_occupied_sum),
                Tuple{Tuple{Int64, Int64, Int64}, Int64, Bool},
            },
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime._task_physics),
            WannierNLQG.Runtime.TaskSpec,
            Symbol,
            Symbol,
            WannierNLQG.Runtime.TaskDefinition,
            NamedTuple{
                (:tensor_indices, :band_selection, :include_occupied_sum),
                Tuple{Tuple{Int64, Int64}, Int64, Bool},
            },
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime._task_physics),
            WannierNLQG.Runtime.TaskSpec,
            Symbol,
            Symbol,
            WannierNLQG.Runtime.TaskDefinition,
            NamedTuple{
                (:tensor_indices, :band_selection, :include_occupied_sum),
                Tuple{Tuple{Int64}, Int64, Bool},
            },
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime._task_physics),
            WannierNLQG.Runtime.TaskSpec,
            Symbol,
            Symbol,
            WannierNLQG.Runtime.TaskDefinition,
            NamedTuple{
                (:tensor_indices, :band_selection, :include_occupied_sum),
                Tuple{Tuple{}, Int64, Bool},
            },
        },
    )
    precompile(Tuple{typeof(WannierNLQG.Runtime._validate_occupation_values), Float64, Float64})
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.assess_response_qualification),
            Nothing,
            WannierNLQG.Runtime.RunContext,
            WannierNLQG.Runtime.EffectiveTaskConfig,
            Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1},
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.bundle_mpi_bcast),
            NamedTuple{
                (:ok, :error, :indices, :values, :residuals),
                Tuple{Bool, String, Array{Int64, 1}, Array{Float64, 2}, Array{Float64, 1}},
            },
            Int64,
            Nothing,
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.bundle_mpi_bcast),
            NamedTuple{
                (:ok, :metadata, :entries, :replica_summary, :error),
                Tuple{
                    Bool,
                    NamedTuple{
                        (
                            :lattice,
                            :num_orbitals,
                            :r_vectors,
                            :degeneracies,
                            :has_spin,
                            :has_spin_velocity,
                            :diagnostics,
                        ),
                        Tuple{
                            Array{Float64, 2},
                            Int64,
                            Array{Int64, 2},
                            Array{Int64, 1},
                            Bool,
                            Bool,
                            Nothing,
                        },
                    },
                    Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                    WannierNLQG.Runtime.RuntimeReplicaSummary,
                    String,
                },
            },
            Int64,
            MPI.Comm,
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.bundle_mpi_bcast),
            NamedTuple{(:ok, :value, :error), Tuple{Bool, Array{String, 1}, String}},
            Int64,
            Nothing,
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.bundle_mpi_bcast),
            NamedTuple{(:ok, :value, :error), Tuple{Bool, Int64, String}},
            Int64,
            MPI.Comm,
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.bundle_mpi_bcast),
            NamedTuple{(:ok, :value, :error), Tuple{Bool, Int64, String}},
            Int64,
            Nothing,
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.bundle_mpi_bcast),
            NamedTuple{(:ok, :value, :error), Tuple{Bool, Nothing, String}},
            Int64,
            MPI.Comm,
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.bundle_mpi_bcast),
            NamedTuple{(:ok, :value, :error), Tuple{Bool, Nothing, String}},
            Int64,
            Nothing,
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.bundle_mpi_bcast),
            NamedTuple{(:ok, :value, :error), Tuple{Bool, String, String}},
            Int64,
            MPI.Comm,
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.bundle_mpi_bcast),
            NamedTuple{(:ok, :value, :error), Tuple{Bool, String, String}},
            Int64,
            Nothing,
        },
    )
    precompile(Tuple{typeof(WannierNLQG.Runtime.bundle_mpi_bcast), Nothing, Int64, MPI.Comm})
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.execute_kpath_driver),
            WannierNLQG.Runtime.BandStructureKPathKernel,
            WannierNLQG.Runtime.KPathPlan,
            WannierNLQG.Core.TightBindingModel{
                Array{Base.Complex{Float64}, 3},
                WannierNLQG.IO.PackedCartesianOperator{1, 4, Array{Base.Complex{Float64}, 3}},
            },
            Nothing,
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.fourier_execution_summary),
            WannierNLQG.Runtime.EffectiveTaskConfig,
            WannierNLQG.Runtime.FourierExecutionPlan,
            Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[2], 1},
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.fourier_execution_summary),
            WannierNLQG.Runtime.EffectiveTaskConfig,
            WannierNLQG.Runtime.FourierExecutionPlan,
            Array{WannierNLQG.FIRST_USE_WORKSPACE_TYPES[3], 1},
        },
    )
    precompile(Tuple{typeof(WannierNLQG.Runtime.metadata_value), Array{Int64, 1}})
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.metadata_value),
            Array{
                NamedTuple{
                    (
                        :reuse_enabled,
                        :generations,
                        :fourier_evaluations,
                        :diagonalizations,
                        :fourier_hits,
                        :spectrum_hits,
                        :entries,
                        :peak_entries,
                    ),
                    Tuple{Bool, Vararg{Int64, 7}},
                },
                1,
            },
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.metadata_value),
            Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
        },
    )
    precompile(Tuple{typeof(WannierNLQG.Runtime.metadata_value), Array{String, 1}})
    precompile(Tuple{typeof(WannierNLQG.Runtime.metadata_value), Array{Symbol, 1}})
    precompile(Tuple{typeof(WannierNLQG.Runtime.metadata_value), Base.Dict{String, Any}})
    precompile(Tuple{typeof(WannierNLQG.Runtime.metadata_value), Bool})
    precompile(Tuple{typeof(WannierNLQG.Runtime.metadata_value), Int64})
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.metadata_value),
            NamedTuple{
                (
                    :denominator_regularization,
                    :broadening,
                    :broadening_type,
                    :transition_window_factor,
                    :band_window_size,
                ),
                Tuple{Float64, Float64, String, Float64, Int64},
            },
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.metadata_value),
            NamedTuple{
                (
                    :fermi_energies,
                    :fermi_energies_sha256,
                    :fermi_energy,
                    :temperature,
                    :photon_energies,
                    :gamma_intra_ev,
                    :gamma_inter_ev,
                ),
                Tuple{
                    Array{Float64, 1},
                    String,
                    Float64,
                    Float64,
                    Array{Float64, 1},
                    Float64,
                    Float64,
                },
            },
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.metadata_value),
            NamedTuple{
                (
                    :fermi_energies,
                    :fermi_energies_sha256,
                    :temperature,
                    :photon_energies,
                    :orbital_input_semantics,
                ),
                Tuple{Array{Float64, 1}, String, Float64, Array{Float64, 1}, Symbol},
            },
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.metadata_value),
            NamedTuple{(:fermi_energy,), Tuple{Float64}},
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.metadata_value),
            NamedTuple{(:hermiticity_tolerance,), Tuple{Float64}},
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.metadata_value),
            NamedTuple{
                (:kind, :component, :bands),
                Tuple{
                    String,
                    Tuple{Int64, Int64},
                    NamedTuple{(:kind, :include_occupied_sum), Tuple{String, Bool}},
                },
            },
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.metadata_value),
            NamedTuple{
                (:kind, :component, :bands),
                Tuple{
                    String,
                    Tuple{Int64},
                    NamedTuple{(:kind, :include_occupied_sum), Tuple{String, Bool}},
                },
            },
        },
    )
    precompile(
        Tuple{typeof(WannierNLQG.Runtime.metadata_value), NamedTuple{(:kind,), Tuple{String}}},
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.metadata_value),
            NamedTuple{
                (:photon_energies, :fermi_energy, :temperature),
                Tuple{Array{Float64, 1}, Float64, Float64},
            },
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.metadata_value),
            NamedTuple{
                (:spectral_gap_tolerance, :denominator_regularization, :degeneracy_threshold),
                Tuple{Float64, Float64, Float64},
            },
        },
    )
    precompile(Tuple{typeof(WannierNLQG.Runtime.metadata_value), String})
    precompile(Tuple{typeof(WannierNLQG.Runtime.metadata_value), Tuple{Int64, Int64, Int64}})
    precompile(Tuple{typeof(WannierNLQG.Runtime.metadata_value), Tuple{Int64, Int64}})
    precompile(Tuple{typeof(WannierNLQG.Runtime.metadata_value), Tuple{Int64}})
    precompile(Tuple{typeof(WannierNLQG.Runtime.metadata_value), Tuple{String, String, String}})
    false
    false
    false
    false
    precompile(
        Tuple{typeof(WannierNLQG.Runtime.mpi_ranked_debug_log), Base.ReentrantLock, String, Int64},
    )
    precompile(Tuple{typeof(WannierNLQG.Runtime.normalize_calculation), String})
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.normalize_requested_task_tuple),
            Tuple{String, String, String},
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.prepare_response_symmetry_execution_plan),
            WannierNLQG.Runtime.EffectiveTaskConfig,
            WannierNLQG.Runtime.RunContext,
            Array{WannierNLQG.Runtime.NormalizedTaskSpec, 1},
            MPI.Comm,
        },
    )
    false
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.progress_fourier_backend!),
            NamedTuple{
                (
                    :backend,
                    :NKdiv,
                    :NKFFT,
                    :factor_source,
                    :estimated_memory_bytes,
                    :memory_limit_bytes,
                    :load_imbalance,
                    :blocks_per_rank,
                    :kpoints_per_rank,
                    :task_signatures,
                    :union_capabilities,
                    :union_fourier_groups,
                    :union_offset_signatures,
                    :union_group_offset_counts,
                    :groups,
                    :offset_count,
                    :cache_entries,
                    :allocated_bytes,
                    :allocated_memory_limit_bytes,
                    :pack_seconds,
                    :fft_seconds,
                    :extract_seconds,
                    :fft_calls,
                    :cache_hits,
                    :evictions,
                ),
                Tuple{
                    Symbol,
                    Nothing,
                    Nothing,
                    Symbol,
                    Int64,
                    Int64,
                    Float64,
                    Array{Int64, 1},
                    Array{Int64, 1},
                    Array{String, 1},
                    Array{Symbol, 1},
                    Array{Symbol, 1},
                    Array{String, 1},
                    Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                    Array{String, 1},
                    Int64,
                    Int64,
                    Int64,
                    Int64,
                    Float64,
                    Float64,
                    Float64,
                    Int64,
                    Int64,
                    Int64,
                },
            },
        },
    )
    false
    false
    false
    false
    false
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.progress_json_value),
            Array{
                NamedTuple{
                    (
                        :label,
                        :fractional_coordinates,
                        :point_index_one_based,
                        :cumulative_distance_A_inverse,
                    ),
                    Tuple{String, Array{Float64, 1}, Int64, Float64},
                },
                1,
            },
        },
    )
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    false
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.progress_system_summary!),
            WannierNLQG.Core.TightBindingModel{
                Array{Base.Complex{Float64}, 3},
                WannierNLQG.IO.PackedCartesianOperator{1, 4, Array{Base.Complex{Float64}, 3}},
            },
        },
    )
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.release_runtime_storage!),
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
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Nothing,
                    Symbol,
                    Nothing,
                    WannierNLQG.Runtime.MPISharedOperatorStorage,
                    WannierNLQG.Runtime.RuntimeReplicaSummary,
                },
            },
        },
    )
    precompile(Tuple{typeof(WannierNLQG.Runtime.run), WannierNLQG.Runtime.TaskConfig})
    precompile(
        Tuple{
            typeof(WannierNLQG.Runtime.run_task_bundle_fused!),
            WannierNLQG.Runtime.EffectiveTaskConfig,
            WannierNLQG.Runtime.RunContext,
            WannierNLQG.Runtime.BandStructureBundlePlan,
        },
    )
end

"""Anchor observed foreign specializations in this package; compiled only, never called by a workload."""
function _first_use_foreign_call(function_value::F, arguments::Vararg{Any, N}) where {F, N}
    return Base.@noinline function_value(arguments...)
end
