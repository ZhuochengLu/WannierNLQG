# Foundation-owned signatures moved from the combined solver precompile extension.
# Compilation only: no runtime backend activation, user I/O, or MPI initialization.
_foundation_owner_call(f::F, args::Vararg{Any, N}) where {F, N} = Base.@noinline f(args...)
"""Compile a provider signature and its owned bridge without executing it."""
function _foundation_owner_sequence(@nospecialize(signature))
    precompile(signature)
    precompile(Tuple{typeof(_foundation_owner_call), signature.parameters...})
    return nothing
end
@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        false

        precompile(
            Tuple{
                typeof(WannierNLQGSymmetryFoundationExt.read_band_representation_preparation_hdf5),
                String,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
            },
        )

        _foundation_owner_sequence(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (
                        :validation,
                        :inventory,
                        :raw_diagnostics,
                        :qualification_scope,
                        :requested_policy,
                        :effective_policy,
                        :symmetry_tolerance_status,
                    ),
                    Tuple{
                        WannierNLQG.Wannierization.RepresentationCompatibilityReport,
                        Nothing,
                        Array{WannierNLQG.SymmetryFoundation.RepresentationRawDiagnostic, 1},
                        WannierNLQG.SymmetryFoundation.BandRepresentationQualificationScope,
                        Symbol,
                        Symbol,
                        Symbol,
                    },
                },
                typeof(WannierNLQGSymmetryFoundationExt.write_band_representation_hdf5),
                String,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
            },
        )

        _foundation_owner_sequence(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGSymmetryFoundationExt.var"#84#93",
                Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
            },
        )

        _foundation_owner_sequence(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    Array{WannierNLQG.Wannierization.WannierizationDiagnostic, 1},
                    WannierNLQGSymmetryFoundationExt.var"#84#93",
                },
            },
        )

        _foundation_owner_sequence(
            Tuple{
                Type{WannierNLQGSymmetryFoundationExt.BandRepresentationValidation},
                Bool,
                Float64,
                Float64,
                NTuple{4, Float64},
                Float64,
                Float64,
                Float64,
                Nothing,
                Nothing,
                String,
                Array{String, 1},
            },
        )

        _foundation_owner_sequence(
            Tuple{
                typeof(Base.getproperty),
                WannierNLQGSymmetryFoundationExt.BandRepresentationValidation,
                Symbol,
            },
        )

        _foundation_owner_sequence(
            Tuple{
                WannierNLQGSymmetryFoundationExt.var"##_atomic_band_hdf5_write#76",
                Bool,
                typeof(WannierNLQGSymmetryFoundationExt._atomic_band_hdf5_write),
                WannierNLQGSymmetryFoundationExt.var"#85#94"{
                    Nothing,
                    Array{WannierNLQG.SymmetryFoundation.RepresentationRawDiagnostic, 1},
                    Symbol,
                    Symbol,
                    Symbol,
                    WannierNLQG.SymmetryFoundation.BandRepresentation,
                    WannierNLQGSymmetryFoundationExt.BandRepresentationProductTable,
                    NTuple{4, Base.Dict{String, String}},
                    NTuple{4, Base.Dict{String, String}},
                    Array{Float64, 1},
                    Array{Float64, 1},
                },
                String,
            },
        )

        _foundation_owner_sequence(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{
                    (
                        :inventory,
                        :qualification_outer_mask,
                        :qualification_frozen_mask,
                        :raw_diagnostics,
                        :requested_policy,
                        :effective_policy,
                        :symmetry_tolerance_status,
                    ),
                    Tuple{
                        Nothing,
                        Base.BitArray{2},
                        Base.BitArray{2},
                        Array{WannierNLQG.SymmetryFoundation.RepresentationRawDiagnostic, 1},
                        Symbol,
                        Symbol,
                        Symbol,
                    },
                },
                typeof(WannierNLQGSymmetryFoundationExt._write_band_v14_preparation_metadata),
                HDF5.File,
                WannierNLQG.SymmetryFoundation.BandRepresentation,
            },
        )

        _foundation_owner_sequence(
            Tuple{
                Type{Base.Generator{I, F} where {F} where I},
                WannierNLQGSymmetryFoundationExt.var"#102#105"{
                    Array{UInt8, 1},
                    Array{Float64, 2},
                    Array{Float64, 3},
                    Array{Int64, 3},
                },
                Base.OneTo{Int64},
            },
        )

        _foundation_owner_sequence(
            Tuple{
                typeof(Base.collect),
                Base.Generator{
                    Base.OneTo{Int64},
                    WannierNLQGSymmetryFoundationExt.var"#102#105"{
                        Array{UInt8, 1},
                        Array{Float64, 2},
                        Array{Float64, 3},
                        Array{Int64, 3},
                    },
                },
            },
        )

        _foundation_owner_sequence(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{(:include_time_reversal, :symmetry_tolerance), Tuple{Bool, Float64}},
                typeof(
                    WannierNLQGSymmetryFoundationExt.detect_tb_compatibility_symmetry_operations,
                ),
                WannierNLQG.SymmetryFoundation.CrystalStructure,
            },
        )

        _foundation_owner_sequence(
            Tuple{typeof(WannierNLQGSymmetryFoundationExt.symmetry_detection_backend_provenance)},
        )
    end
end

@compile_workload begin
    if WannierNLQG.FIRST_USE_WORKLOAD_ENABLED
        _foundation_owner_sequence(
            Tuple{
                typeof(Base.Core.kwcall),
                NamedTuple{(:include_time_reversal, :symmetry_tolerance), Tuple{Bool, Float64}},
                typeof(WannierNLQGSymmetryFoundationExt.detect_magnetic_symmetry_inventory),
                WannierNLQG.SymmetryFoundation.CrystalStructure,
            },
        )
    end
end
