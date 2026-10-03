# Generated only from identity-proved original cold expert traces, Julia 1.11.2.
# Compile-only: no model execution, file writes, MPI initialization or runtime handles.
@compile_workload begin
    if workload_enabled(parentmodule(SymmetrizationConfig))
        _record_symmetrization(
            Tuple{
                typeof(Symmetrization.symmetrize_existing_wannier_model),
                Symmetrization.GaugeAwareSymmetrizationConfig,
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(HDF5.generic_read),
                HDF5.Attribute,
                HDF5.Datatype,
                Type{HDF5.FixedString{1059, 0}},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Printf.format),
                Base.IOStream,
                Printf.Format{
                    Base.CodeUnits{UInt8, String},
                    Tuple{
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}},
                    },
                },
                Int64,
                Int64,
                Vararg{Any},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Printf.format),
                Array{UInt8, 1},
                Int64,
                Printf.Format{
                    Base.CodeUnits{UInt8, String},
                    Tuple{
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}},
                        Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}},
                    },
                },
                Int64,
                Vararg{Any},
            },
        )
        _record_symmetrization(
            Tuple{
                typeof(Dates.format),
                Dates.DateTime,
                Dates.DateFormat{
                    :var"yyyy-mm-ddTHH:MM:SS",
                    Tuple{
                        Dates.DatePart{reinterpret(Char, UInt32(0x79000000))},
                        Dates.Delim{Char, 1},
                        Dates.DatePart{reinterpret(Char, UInt32(0x6d000000))},
                        Dates.Delim{Char, 1},
                        Dates.DatePart{reinterpret(Char, UInt32(0x64000000))},
                        Dates.Delim{Char, 1},
                        Dates.DatePart{reinterpret(Char, UInt32(0x48000000))},
                        Dates.Delim{Char, 1},
                        Dates.DatePart{reinterpret(Char, UInt32(0x4d000000))},
                        Dates.Delim{Char, 1},
                        Dates.DatePart{reinterpret(Char, UInt32(0x53000000))},
                    },
                },
            },
        )
        # MPI state is checked by the independent lifecycle gate after activation.
    end
end
