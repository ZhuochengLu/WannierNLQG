# Generated only from identity-proved original cold expert traces, Julia 1.11.2.
# Compile-only: no model execution, file writes, MPI initialization or runtime handles.
@compile_workload begin
    if WannierizationInternalSupport.WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        let WannierNLQGWannierizationExt=@__MODULE__
            precompile(
                Tuple{
                    typeof(Base.Core.kwcall),
                    NamedTuple{(:artifact_dir, :qualification_mode), Tuple{String, Symbol}},
                    typeof(
                        WannierNLQG.Wannierization.generate_symmetry_completed_qe_paw_matrix_elements,
                    ),
                    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                    String,
                    String,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Core.kwcall),
                    NamedTuple{(:artifact_dir, :qualification_mode), Tuple{String, Symbol}},
                    typeof(
                        WannierNLQG.Wannierization.generate_symmetry_completed_qe_paw_matrix_elements,
                    ),
                    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                    String,
                    String,
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Core.kwcall),
                    NamedTuple{
                        (:artifact_dir, :thresholds, :qualification_mode),
                        Tuple{String, WannierNLQG.Wannierization.QEPAWParityThresholds, Symbol},
                    },
                    typeof(
                        WannierNLQGWannierizationExt.PAWMatrixElements.generate_symmetry_completed_qe_paw_matrix_elements,
                    ),
                    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                    String,
                    String,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Core.kwcall),
                    NamedTuple{
                        (:artifact_dir, :thresholds, :qualification_mode),
                        Tuple{String, WannierNLQG.Wannierization.QEPAWParityThresholds, Symbol},
                    },
                    typeof(
                        WannierNLQGWannierizationExt.PAWMatrixElements.generate_symmetry_completed_qe_paw_matrix_elements,
                    ),
                    WannierNLQG.SymmetryFoundation.QuantumEspressoWavefunctionSource,
                    String,
                    String,
                },
            )
            precompile(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{287, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{287, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{36, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{36, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{116, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{116, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{150, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{150, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{166, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{166, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{96, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{96, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(WannierNLQG.Wannierization.prepare_exact_wannier_operator_bundle),
                    WannierNLQG.Wannierization.ExactWannierOperatorBundleConfig,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(WannierNLQG.Wannierization.prepare_exact_wannier_operator_bundle),
                    WannierNLQG.Wannierization.ExactWannierOperatorBundleConfig,
                },
            )
            precompile(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{178, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{178, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(Base.Core.kwcall),
                    NamedTuple{(:num_wannier,), Tuple{Int64}},
                    typeof(WannierNLQG.Wannierization.prepare_paw_scdm_input_artifact),
                    String,
                    String,
                    String,
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(Base.Core.kwcall),
                    NamedTuple{(:num_wannier,), Tuple{Int64}},
                    typeof(WannierNLQG.Wannierization.prepare_paw_scdm_input_artifact),
                    String,
                    String,
                    String,
                },
            )
            precompile(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{133, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{133, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{53, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{53, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{5282, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{5282, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{209, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{209, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{207, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{207, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{208, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{208, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{210, 0}},
                },
            )
            precompile(
                Tuple{
                    typeof(_wannierization_entry_compile_call),
                    typeof(HDF5.generic_read),
                    HDF5.Attribute,
                    HDF5.Datatype,
                    Type{HDF5.FixedString{210, 0}},
                },
            )
        end
        @assert !WannierNLQG.MPI.Initialized()
    end
end

# Compile-only residuals from actual-Type-proved cold public HDF5 readers.
# Julia 1.11.2 only, retain FIRST_USE_TRACE_COMPATIBLE include boundary.
# No fixture/model execution, file writes, backend preactivation, or sample changes.
@compile_workload begin
    if WannierizationInternalSupport.WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{59, 0}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{1, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{2, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{3, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{4, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{5, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{6, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{9, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{10, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{12, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{14, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{15, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{17, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{18, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{19, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{21, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{25, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{29, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{30, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{32, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{36, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{37, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{39, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{40, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{41, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{49, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{52, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{56, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
        let signature = Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{64, 1}},
            }
            precompile(signature)
            precompile(Tuple{typeof(_wannierization_entry_compile_call), signature.parameters...})
        end
    end
end
