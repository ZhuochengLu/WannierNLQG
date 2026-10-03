using PrecompileTools: @compile_workload, workload_enabled

# Compile expert entry signatures without executing file writes or MPI initialization.
@compile_workload begin
    if workload_enabled(parentmodule(BandRepresentation))
        false
    end
end

# Owned symmetry backend declarations; compilation only, no resource initialization.
_foundation_compile_call(f::F, args::Vararg{Any, N}) where {F, N} = Base.@noinline f(args...)
const FIRST_USE_FOUNDATION_RESULTS = Tuple{Bool, Bool}[]
# Record compilation coverage for signatures owned by the symmetry backend.
function _record_foundation(@nospecialize(signature))
    push!(
        FIRST_USE_FOUNDATION_RESULTS,
        (
            precompile(signature),
            precompile(Tuple{typeof(_foundation_compile_call), signature.parameters...}),
        ),
    )
    nothing
end
@compile_workload begin
    if workload_enabled(parentmodule(BandRepresentation))
        let CrystallographyCore=parentmodule(Spglib.Lattice),
            StaticArraysCore=parentmodule(Spglib.SVector),
            StaticArrays=Base.loaded_modules[Base.PkgId(
                Base.UUID("90137ffa-7385-5640-81b9-e52037218182"),
                "StaticArrays",
            )]

            _record_foundation(Tuple{StaticArrays.var"##s26#85", Vararg{Any, 4}})
            _record_foundation(Tuple{StaticArraysCore.var"##s4#1", Vararg{Any, 9}})
            _record_foundation(
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
            _record_foundation(
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
            _record_foundation(
                Tuple{
                    Type{Base.Generator{I, F} where {F} where I},
                    Base.ComposedFunction{
                        Type{CrystallographyCore.ReducedCoordinates{Float64}},
                        typeof(Base.collect),
                    },
                    Array{Array{Float64, 1}, 1},
                },
            )
            _record_foundation(
                Tuple{
                    Type{Base.Generator{I, F} where {F} where I},
                    StaticArrays.var"#86#87",
                    Base.UnitRange{Int64},
                },
            )
            _record_foundation(
                Tuple{
                    Type{CrystallographyCore.Lattice{T} where T},
                    StaticArraysCore.SArray{Tuple{3, 3}, Float64, 2, 9},
                },
            )
            _record_foundation(
                Tuple{
                    Type{Pair{A, B} where {B} where A},
                    Symbol,
                    Tuple{StaticArrays.SOneTo{3}, StaticArrays.SOneTo{3}},
                },
            )
            _record_foundation(
                Tuple{Type{Pair{A, B} where {B} where A}, Symbol, Tuple{StaticArrays.SOneTo{3}}},
            )
            _record_foundation(
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
            _record_foundation(
                Tuple{
                    Type{Spglib.SpglibCell{Float64, Float64, Int64, Array{Float64, 1}}},
                    CrystallographyCore.Lattice{Float64},
                    Array{CrystallographyCore.ReducedCoordinates{Float64}, 1},
                    Array{Int64, 1},
                    Array{Array{Float64, 1}, 1},
                },
            )
            _record_foundation(
                Tuple{
                    typeof(Base._all),
                    StaticArraysCore.var"#2#3",
                    Base.Core.SimpleVector,
                    Base.Colon,
                },
            )
            _record_foundation(
                Tuple{
                    typeof(Base._array_for),
                    Type{StaticArraysCore.SArray{Tuple{3, 3}, Int32, 2, 9}},
                    Base.HasShape{1},
                    Tuple{Base.OneTo{Int64}},
                },
            )
            _record_foundation(
                Tuple{typeof(Base._prechecked_iterate), StaticArrays.SOneTo{3}, Int64},
            )
            _record_foundation(
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
            _record_foundation(
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
            _record_foundation(
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
            _record_foundation(
                Tuple{
                    typeof(Base.getproperty),
                    Base.LinearIndices{1, Tuple{StaticArrays.SOneTo{3}}},
                    Symbol,
                },
            )
            _record_foundation(
                Tuple{
                    typeof(Base.getproperty),
                    Base.LinearIndices{2, Tuple{StaticArrays.SOneTo{3}, StaticArrays.SOneTo{3}}},
                    Symbol,
                },
            )
            _record_foundation(
                Tuple{
                    typeof(Base.iterate),
                    Base.Generator{Base.UnitRange{Int64}, StaticArrays.var"#86#87"},
                    Int64,
                },
            )
            _record_foundation(
                Tuple{
                    typeof(Base.iterate),
                    Base.Generator{Base.UnitRange{Int64}, StaticArrays.var"#86#87"},
                },
            )
            _record_foundation(
                Tuple{
                    typeof(Base.iterate),
                    Base.LinearIndices{1, Tuple{StaticArrays.SOneTo{3}}},
                    Int64,
                },
            )
            _record_foundation(
                Tuple{
                    typeof(Base.iterate),
                    Base.LinearIndices{2, Tuple{StaticArrays.SOneTo{3}, StaticArrays.SOneTo{3}}},
                    Int64,
                },
            )
            _record_foundation(
                Tuple{
                    typeof(Spglib.get_magnetic_dataset),
                    Spglib.SpglibCell{Float64, Float64, Int64, Array{Float64, 1}},
                    Float64,
                },
            )
            _record_foundation(Tuple{typeof(StaticArrays._Length), Int64, Vararg{Int64}})
            _record_foundation(
                Tuple{
                    typeof(WannierNLQG.SymmetryFoundation._maximum_abs_operator_element),
                    Array{Base.Complex{Float64}, 1},
                },
            )
            _record_foundation(
                Tuple{
                    typeof(WannierNLQG.SymmetryFoundation._maximum_abs_operator_element),
                    Base.Complex{Float64},
                },
            )
            _record_foundation(
                Tuple{
                    typeof(WannierNLQG.SymmetryFoundation._retained_r_indices),
                    Array{Base.Complex{Float64}, 3},
                    Array{Tuple{Int64, Int64, Int64}, 1},
                    Base.Set{Tuple{Int64, Int64, Int64}},
                },
            )
            _record_foundation(
                Tuple{
                    typeof(WannierNLQG.SymmetryFoundation._retained_r_indices),
                    Array{Base.Complex{Float64}, 4},
                    Array{Tuple{Int64, Int64, Int64}, 1},
                    Base.Set{Tuple{Int64, Int64, Int64}},
                },
            )
            _record_foundation(
                Tuple{
                    typeof(WannierNLQG.SymmetryFoundation._set_operator_element!),
                    Array{Base.Complex{Float64}, 3},
                    Base.Complex{Float64},
                    WannierNLQG.Core.RealSpaceOperatorSymmetrySpec,
                    Int64,
                    Int64,
                    Int64,
                },
            )
            _record_foundation(
                Tuple{
                    typeof(WannierNLQG.SymmetryFoundation._set_operator_element!),
                    Array{Base.Complex{Float64}, 4},
                    Array{Base.Complex{Float64}, 1},
                    WannierNLQG.Core.RealSpaceOperatorSymmetrySpec,
                    Int64,
                    Int64,
                    Int64,
                },
            )
            false
        end
    end
end

include("BandPublicFirstUseCoverage.jl")

include("FoundationOwnerFirstUseCoverage.jl")

# R16: native symmetry library signatures stay in the owning backend extension.
@compile_workload let
    if workload_enabled(parentmodule(BandRepresentation))
        CrystallographyCore = parentmodule(Spglib.Lattice)
        StaticArraysCore = parentmodule(Spglib.SVector)
        _record_foundation(
            Tuple{
                Type{Spglib.SpglibCell{Float64, Float64, Int64, Float64}},
                CrystallographyCore.Lattice{Float64},
                Array{CrystallographyCore.ReducedCoordinates{Float64}, 1},
                Array{Int64, 1},
                Array{Float64, 1},
            },
        )
        _record_foundation(
            Tuple{
                typeof(Spglib.get_dataset),
                Spglib.SpglibCell{Float64, Float64, Int64, Float64},
                Float64,
            },
        )
        _record_foundation(
            Tuple{
                typeof(Base.collect_to_with_first!),
                Array{StaticArraysCore.SArray{Tuple{3, 3}, Int32, 2, 9}, 1},
                StaticArraysCore.SArray{Tuple{3, 3}, Int32, 2, 9},
                Base.Generator{Base.OneTo{Int32}, Spglib.var"#7#12"{Spglib.SpglibDataset}},
                Int32,
            },
        )
        _record_foundation(
            Tuple{
                Type{Spglib.Dataset},
                Int32,
                Int32,
                String,
                String,
                String,
                StaticArraysCore.SArray{Tuple{3, 3}, Float64, 2, 9},
                Tuple{Float64, Float64, Float64},
                Int32,
                Array{StaticArraysCore.SArray{Tuple{3, 3}, Int32, 2, 9}, 1},
                Array{StaticArraysCore.SArray{Tuple{3}, Float64, 1, 3}, 1},
                Int32,
                Array{Char, 1},
                Array{String, 1},
                Array{Int64, 1},
                Array{Int64, 1},
                CrystallographyCore.Lattice{Float64},
                Array{Int64, 1},
                Int32,
                CrystallographyCore.Lattice{Float64},
                Array{Int32, 1},
                Array{StaticArraysCore.SArray{Tuple{3}, Float64, 1, 3}, 1},
                StaticArraysCore.SArray{Tuple{3, 3}, Float64, 2, 9},
                Array{Int64, 1},
                String,
            },
        )
    end
end

include("ResponseGroupFirstUseCoverage.jl")

include("Generated/VASPBandFirstUseSignatures.jl")
