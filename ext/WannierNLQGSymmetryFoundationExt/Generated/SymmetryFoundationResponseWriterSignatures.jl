# Generated from a true first-call response writer trace.
# See candidate_008_split_writer_generation_v1.json for every source line.
const RESPONSE_WRITER_FOUNDATION_RESULTS = Bool[]
# Record direct and owner-bridge compiler success for a Foundation writer specialization.
_record_response_writer_foundation(signature) =
    push!(RESPONSE_WRITER_FOUNDATION_RESULTS, precompile(signature))
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        let WannierNLQGSymmetryFoundationExt=@__MODULE__,
            StaticArrays=only(filter(m -> nameof(m) == :StaticArrays, Base.loaded_modules_array())),
            StaticArraysCore=only(
                filter(m -> nameof(m) == :StaticArraysCore, Base.loaded_modules_array()),
            ),
            CrystallographyCore=only(
                filter(m -> nameof(m) == :CrystallographyCore, Base.loaded_modules_array()),
            ),
            spglib_jll=only(filter(m -> nameof(m) == :spglib_jll, Base.loaded_modules_array()))

            _record_response_writer_foundation(Tuple{typeof(spglib_jll.find_artifact_dir)})

            _record_response_writer_foundation(
                Tuple{typeof(StaticArrays._Length), Int64, Vararg{Int64}},
            )
            _record_response_writer_foundation(Tuple{StaticArrays.var"##s26#85", Vararg{Any, 4}})
            _record_response_writer_foundation(
                Tuple{
                    Type{Base.Generator{I, F} where {F} where I},
                    StaticArrays.var"#86#87",
                    Base.UnitRange{Int64},
                },
            )
            _record_response_writer_foundation(
                Tuple{
                    typeof(Base.iterate),
                    Base.Generator{Base.UnitRange{Int64}, StaticArrays.var"#86#87"},
                },
            )
            _record_response_writer_foundation(
                Tuple{
                    typeof(Base.iterate),
                    Base.Generator{Base.UnitRange{Int64}, StaticArrays.var"#86#87"},
                    Int64,
                },
            )
            _record_response_writer_foundation(Tuple{StaticArraysCore.var"##s4#1", Vararg{Any, 9}})
            _record_response_writer_foundation(
                Tuple{
                    typeof(Base._all),
                    StaticArraysCore.var"#2#3",
                    Base.Core.SimpleVector,
                    Base.Colon,
                },
            )

            _record_response_writer_foundation(
                Tuple{
                    typeof(Base.getproperty),
                    Base.LinearIndices{1, Tuple{StaticArrays.SOneTo{3}}},
                    Symbol,
                },
            )
            _record_response_writer_foundation(
                Tuple{typeof(Base._prechecked_iterate), StaticArrays.SOneTo{3}, Int64},
            )
            _record_response_writer_foundation(
                Tuple{
                    Type{Pair{A, B} where {B} where A},
                    Symbol,
                    Tuple{StaticArrays.SOneTo{3}, StaticArrays.SOneTo{3}},
                },
            )
            _record_response_writer_foundation(
                Tuple{
                    typeof(Base.getproperty),
                    Base.LinearIndices{2, Tuple{StaticArrays.SOneTo{3}, StaticArrays.SOneTo{3}}},
                    Symbol,
                },
            )
            _record_response_writer_foundation(
                Tuple{
                    typeof(Base.iterate),
                    Base.LinearIndices{2, Tuple{StaticArrays.SOneTo{3}, StaticArrays.SOneTo{3}}},
                    Int64,
                },
            )
            _record_response_writer_foundation(
                Tuple{Type{Pair{A, B} where {B} where A}, Symbol, Tuple{StaticArrays.SOneTo{3}}},
            )
            _record_response_writer_foundation(
                Tuple{
                    typeof(Base.iterate),
                    Base.LinearIndices{1, Tuple{StaticArrays.SOneTo{3}}},
                    Int64,
                },
            )
            _record_response_writer_foundation(
                Tuple{
                    typeof(Base.Core.kwcall),
                    NamedTuple{
                        (
                            :include_time_reversal,
                            :spglib_symprec_angstrom,
                            :cartesian_rotation_policy,
                            :maximum_cartesian_rotation_correction,
                        ),
                        Tuple{Bool, Float64, Symbol, Float64},
                    },
                    typeof(WannierNLQGSymmetryFoundationExt.detect_magnetic_symmetry_inventory),
                    WannierNLQG.SymmetryFoundation.CrystalStructure,
                },
            )
            _record_response_writer_foundation(
                Tuple{
                    Type{Base.Generator{I, F} where {F} where I},
                    Base.ComposedFunction{
                        Type{CrystallographyCore.ReducedCoordinates{Float64}},
                        typeof(Base.collect),
                    },
                    Array{Array{Float64, 1}, 1},
                },
            )
            _record_response_writer_foundation(
                Tuple{
                    typeof(Base.collect_similar),
                    Array{Array{Float64, 1}, 1},
                    Base.Generator{
                        Array{Array{Float64, 1}, 1},
                        Base.ComposedFunction{
                            Type{CrystallographyCore.ReducedCoordinates{Float64}},
                            typeof(Base.collect),
                        },
                    },
                },
            )
            _record_response_writer_foundation(
                Tuple{
                    Type{Spglib.SpglibCell{Float64, Float64, Int64, Array{Float64, 1}}},
                    CrystallographyCore.Lattice{Float64},
                    Array{CrystallographyCore.ReducedCoordinates{Float64}, 1},
                    Array{Int64, 1},
                    Array{Array{Float64, 1}, 1},
                },
            )
            _record_response_writer_foundation(
                Tuple{
                    typeof(Spglib.get_magnetic_dataset),
                    Spglib.SpglibCell{Float64, Float64, Int64, Array{Float64, 1}},
                    Float64,
                },
            )
            _record_response_writer_foundation(
                Tuple{
                    typeof(Base._array_for),
                    Type{StaticArraysCore.SArray{Tuple{3, 3}, Int32, 2, 9}},
                    Base.HasShape{1},
                    Tuple{Base.OneTo{Int64}},
                },
            )
            _record_response_writer_foundation(
                Tuple{
                    typeof(Base.collect_to_with_first!),
                    Array{StaticArraysCore.SArray{Tuple{3, 3}, Int32, 2, 9}, 1},
                    StaticArraysCore.SArray{Tuple{3, 3}, Int32, 2, 9},
                    Base.Generator{
                        Base.OneTo{Int32},
                        Spglib.var"#20#23"{Spglib.SpglibMagneticDataset},
                    },
                    Int32,
                },
            )
            _record_response_writer_foundation(
                Tuple{
                    Type{
                        Base.Broadcast.Broadcasted{
                            Style,
                            Axes,
                            F,
                            Args,
                        } where {
                            Args <: Tuple,
                        } where {
                            F,
                        } where {Axes} where Style <: Union{Nothing, Base.Broadcast.BroadcastStyle},
                    },
                    Base.Broadcast.DefaultArrayStyle{1},
                    typeof(Base.transpose),
                    Tuple{Array{StaticArraysCore.SArray{Tuple{3, 3}, Int32, 2, 9}, 1}},
                },
            )
            _record_response_writer_foundation(
                Tuple{
                    Type{
                        Base.Broadcast.Broadcasted{
                            Style,
                            Axes,
                            F,
                            Args,
                        } where {
                            Args <: Tuple,
                        } where {
                            F,
                        } where {Axes} where Style <: Union{Nothing, Base.Broadcast.BroadcastStyle},
                    },
                    Base.Broadcast.DefaultArrayStyle{1},
                    typeof(Base.transpose),
                    Tuple{Array{StaticArraysCore.SArray{Tuple{3, 3}, Int32, 2, 9}, 1}},
                    Tuple{Base.OneTo{Int64}},
                },
            )
            _record_response_writer_foundation(
                Tuple{
                    typeof(Base.copy),
                    Base.Broadcast.Broadcasted{
                        Base.Broadcast.DefaultArrayStyle{1},
                        Tuple{Base.OneTo{Int64}},
                        typeof(Base.transpose),
                        Tuple{Array{StaticArraysCore.SArray{Tuple{3, 3}, Int32, 2, 9}, 1}},
                    },
                },
            )

            _record_response_writer_foundation(
                Tuple{
                    Type{CrystallographyCore.Lattice{T} where T},
                    StaticArraysCore.SArray{Tuple{3, 3}, Float64, 2, 9},
                },
            )
            _record_response_writer_foundation(
                Tuple{
                    Type{Spglib.MagneticDataset},
                    Int32,
                    Int32,
                    Int32,
                    Int32,
                    Int32,
                    Array{StaticArraysCore.SArray{Tuple{3, 3}, Int32, 2, 9}, 1},
                    Array{StaticArraysCore.SArray{Tuple{3}, Float64, 1, 3}, 1},
                    Base.BitArray{1},
                    Int32,
                    Array{Int64, 1},
                    StaticArraysCore.SArray{Tuple{3, 3}, Float64, 2, 9},
                    Tuple{Float64, Float64, Float64},
                    Int32,
                    CrystallographyCore.Lattice{Float64},
                    Array{Int32, 1},
                    Array{StaticArraysCore.SArray{Tuple{3}, Float64, 1, 3}, 1},
                    Array{StaticArraysCore.SArray{Tuple{3}, Float64, 1, 3}, 1},
                    StaticArraysCore.SArray{Tuple{3, 3}, Float64, 2, 9},
                    CrystallographyCore.Lattice{Float64},
                },
            )
            _record_response_writer_foundation(
                Tuple{
                    typeof(WannierNLQGSymmetryFoundationExt.symmetry_detection_backend_provenance),
                },
            )
        end
    end
end
