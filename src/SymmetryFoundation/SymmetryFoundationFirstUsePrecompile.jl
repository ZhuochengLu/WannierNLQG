# Compile observed private closure signatures in their owning module.
# No public task, backend activation, external resource, or scientific update runs here.
import PrecompileTools
if parentmodule(@__MODULE__).FIRST_USE_TRACE_COMPATIBLE &&
   ccall(:jl_generating_output, Cint, ()) == 1 &&
   PrecompileTools.workload_enabled(parentmodule(@__MODULE__))
    precompile(
        Tuple{
            Type{Base.Dict{K, V} where {V} where K},
            Base.Generator{
                Base.Iterators.Enumerate{Array{Tuple{Int64, Int64, Int64}, 1}},
                var"#180#183",
            },
        },
    )
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            var"#180#183",
            Base.Iterators.Enumerate{Array{Tuple{Int64, Int64, Int64}, 1}},
        },
    )
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            typeof(Base.identity),
            Base.Iterators.Filter{
                var"#168#172"{Base.Set{Tuple{Int64, Int64, Int64}}},
                Array{Tuple{Int64, Int64, Int64}, 1},
            },
        },
    )
    precompile(
        Tuple{
            Type{Base.Generator{I, F} where {F} where I},
            typeof(Base.identity),
            Base.Iterators.Filter{
                var"#181#184"{Base.Set{Tuple{Int64, Int64, Int64}}},
                Array{Tuple{Int64, Int64, Int64}, 1},
            },
        },
    )
    precompile(
        Tuple{
            Type{Base.Iterators.Filter{F, I} where {I} where F},
            var"#168#172"{Base.Set{Tuple{Int64, Int64, Int64}}},
            Array{Tuple{Int64, Int64, Int64}, 1},
        },
    )
    precompile(
        Tuple{
            Type{Base.Iterators.Filter{F, I} where {I} where F},
            var"#181#184"{Base.Set{Tuple{Int64, Int64, Int64}}},
            Array{Tuple{Int64, Int64, Int64}, 1},
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect),
            Base.Generator{
                Base.Iterators.Filter{
                    var"#168#172"{Base.Set{Tuple{Int64, Int64, Int64}}},
                    Array{Tuple{Int64, Int64, Int64}, 1},
                },
                typeof(Base.identity),
            },
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect),
            Base.Generator{
                Base.Iterators.Filter{
                    var"#181#184"{Base.Set{Tuple{Int64, Int64, Int64}}},
                    Array{Tuple{Int64, Int64, Int64}, 1},
                },
                typeof(Base.identity),
            },
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect_to_with_first!),
            Array{Tuple{Int64, Int64, Int64}, 1},
            Tuple{Int64, Int64, Int64},
            Base.Generator{Base.OneTo{Int64}, var"#165#169"{RealSpaceOperator{3}}},
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect_to_with_first!),
            Array{Tuple{Int64, Int64, Int64}, 1},
            Tuple{Int64, Int64, Int64},
            Base.Generator{Base.OneTo{Int64}, var"#165#169"{RealSpaceOperator{4}}},
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.grow_to!),
            Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
            Base.Generator{Base.OneTo{Int64}, var"#179#182"{RealSpaceOperator{3}}},
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.grow_to!),
            Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
            Base.Generator{Base.OneTo{Int64}, var"#179#182"{RealSpaceOperator{4}}},
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.grow_to!),
            Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
            Base.Generator{Base.OneTo{Int64}, var"#185#186"{RealSpaceOperator{3}}},
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.grow_to!),
            Base.Dict{Tuple{Int64, Int64, Int64}, Int64},
            Base.Generator{Base.OneTo{Int64}, var"#185#186"{RealSpaceOperator{4}}},
            Int64,
        },
    )

    false

    # Native coefficient-reader signatures stay in the owning Foundation module.
    precompile(
        Tuple{
            Type{Array{Tuple{Symbol, VASPWavefunctionSource}, 1}},
            UndefInitializer,
            Tuple{Int64},
        },
    )
    precompile(
        Tuple{
            Base.var"##open#463",
            Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},
            typeof(Base.open),
            var"#120#128"{
                Bool,
                VASPWavefunctionSource,
                Array{Float64, 2},
                Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                Array{Int64, 2},
                Base.UnitRange{Int64},
                Float64,
                Array{Base.Complex{Float64}, 2},
                VASPWavecarHeader,
            },
            String,
            Vararg{String},
        },
    )
    precompile(
        Tuple{
            var"#123#131",
            NamedTuple{
                (
                    :header_record_index,
                    :stored_count,
                    :kpoint,
                    :retained_g,
                    :retained_positions,
                    :full_count,
                    :spin_components,
                    :energies,
                ),
                Tuple{
                    Int64,
                    Int64,
                    Array{Float64, 1},
                    Array{Int64, 2},
                    Array{Int64, 1},
                    Int64,
                    Int64,
                    Array{Float64, 1},
                },
            },
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect_to_with_first!),
            Array{Array{Float64, 1}, 1},
            Array{Float64, 1},
            Base.Generator{
                Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                var"#126#134",
            },
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.collect_to_with_first!),
            Array{Array{Float64, 1}, 1},
            Array{Float64, 1},
            Base.Generator{
                Array{NamedTuple{names, T} where {T <: Tuple} where names, 1},
                var"#127#135",
            },
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(Base.Core.kwcall),
            NamedTuple{(:normalize_coefficients,), Tuple{Bool}},
            typeof(_read_vasp_coefficient_record),
            String,
            VASPWavecarHeader,
            Base.UnitRange{Int64},
            NamedTuple{
                (
                    :header_record_index,
                    :stored_count,
                    :kpoint,
                    :retained_g,
                    :retained_positions,
                    :full_count,
                    :spin_components,
                    :energies,
                ),
                Tuple{
                    Int64,
                    Int64,
                    Array{Float64, 1},
                    Array{Int64, 2},
                    Array{Int64, 1},
                    Int64,
                    Int64,
                    Array{Float64, 1},
                },
            },
            Array{Base.Complex{Float64}, 2},
        },
    )
    # Public scalar/vector/tensor projection and covariance signatures; no task executes.
    false
    precompile(
        Tuple{typeof(symmetrize_real_space_operator), RealSpaceOperator{3}, WannierSymmetryPlan},
    )
    false
    precompile(
        Tuple{
            typeof(maximum_real_space_covariance_error),
            RealSpaceOperator{3},
            WannierSymmetryPlan,
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
    # Eager native VASP reader signatures; compilation never opens a source file.
    false
    false
    # The observed grow_to! closure belongs to this module.
    precompile(
        Tuple{
            typeof(Base.grow_to!),
            Base.Dict{NTuple{9, Int64}, Int64},
            Base.Generator{Base.Iterators.Enumerate{Array{Array{Int64, 2}, 1}}, var"#3#4"},
            Tuple{Int64, Int64},
        },
    )
    # R15: qualification private helpers remain in their owning module.
    precompile(Tuple{typeof(_maximum_abs_operator_element), Base.Complex{Float64}})
    precompile(Tuple{typeof(_maximum_abs_operator_element), Array{Base.Complex{Float64}, 1}})
    precompile(
        Tuple{
            typeof(_set_operator_element!),
            Array{Base.Complex{Float64}, 3},
            Base.Complex{Float64},
            RealSpaceOperatorSymmetrySpec,
            Int64,
            Int64,
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(_retained_r_indices),
            Array{Base.Complex{Float64}, 3},
            Array{Tuple{Int64, Int64, Int64}, 1},
            Base.Set{Tuple{Int64, Int64, Int64}},
        },
    )
    precompile(
        Tuple{
            typeof(_set_operator_element!),
            Array{Base.Complex{Float64}, 4},
            Array{Base.Complex{Float64}, 1},
            RealSpaceOperatorSymmetrySpec,
            Int64,
            Int64,
            Int64,
        },
    )
    precompile(
        Tuple{
            typeof(_retained_r_indices),
            Array{Base.Complex{Float64}, 4},
            Array{Tuple{Int64, Int64, Int64}, 1},
            Base.Set{Tuple{Int64, Int64, Int64}},
        },
    )
end
