# Native-code gaps confirmed in the cold solver LLVM trace; stdlib-only signatures.
@compile_workload begin
    if FIRST_USE_WORKLOAD_ENABLED
        precompile(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    Type{Int64},
                    Tuple{Array{Int64, 2}},
                },
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    Type{Int64},
                    Tuple{Array{Int64, 2}},
                },
            },
        )
        precompile(
            Tuple{
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.:(<)),
                    Tuple{
                        Base.Broadcast.Broadcasted{
                            Base.Broadcast.DefaultArrayStyle{2},
                            Nothing,
                            typeof(Base.abs),
                            Tuple{Array{Float64, 2}},
                        },
                        Float64,
                    },
                },
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.Broadcast.materialize),
                Base.Broadcast.Broadcasted{
                    Base.Broadcast.DefaultArrayStyle{2},
                    Nothing,
                    typeof(Base.:(<)),
                    Tuple{
                        Base.Broadcast.Broadcasted{
                            Base.Broadcast.DefaultArrayStyle{2},
                            Nothing,
                            typeof(Base.abs),
                            Tuple{Array{Float64, 2}},
                        },
                        Float64,
                    },
                },
            },
        )
        precompile(Tuple{typeof(Base.maybeview), Array{Float64, 2}, Base.BitArray{2}})
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Base.maybeview),
                Array{Float64, 2},
                Base.BitArray{2},
            },
        )
        precompile(Tuple{typeof(Base.repeat), Char, Int64})
        precompile(Tuple{typeof(_first_use_foreign_call), typeof(Base.repeat), Char, Int64})
        precompile(
            Tuple{
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
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
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
        precompile(
            Tuple{
                typeof(Printf.fmt),
                Array{UInt8, 1},
                Int64,
                Float64,
                Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}},
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Printf.fmt),
                Array{UInt8, 1},
                Int64,
                Float64,
                Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x65000000))}},
            },
        )
        precompile(
            Tuple{
                typeof(Printf.fmt),
                Array{UInt8, 1},
                Int64,
                Tuple{Int64, Int64, Float64, Float64},
                Int64,
                Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
            },
        )
        precompile(
            Tuple{
                typeof(_first_use_foreign_call),
                typeof(Printf.fmt),
                Array{UInt8, 1},
                Int64,
                Tuple{Int64, Int64, Float64, Float64},
                Int64,
                Printf.Spec{Base.Val{reinterpret(Char, UInt32(0x64000000))}},
            },
        )
        @assert !MPI.Initialized()
    end
end
