# Generated from exact Type-proved inference within real cold public calls, Julia 1.11.2.
# No target execution, writes, MPI initialization or saved handles. Provenance is external.
@compile_workload begin
    if workload_enabled(parentmodule(BandRepresentation))
        let WannierNLQGSymmetryFoundationExt=@__MODULE__
            _record_foundation(
                Tuple{
                    typeof(Base.Core.kwcall),
                    NamedTuple{
                        (:validation, :overwrite),
                        Tuple{WannierNLQGSymmetryFoundationExt.BandRepresentationValidation, Bool},
                    },
                    typeof(WannierNLQG.SymmetryFoundation.write_band_representation_hdf5),
                    String,
                    WannierNLQG.SymmetryFoundation.BandRepresentation,
                },
            )
            _record_foundation(
                Tuple{
                    WannierNLQGSymmetryFoundationExt.var"##_atomic_band_hdf5_write#76",
                    Bool,
                    typeof(WannierNLQGSymmetryFoundationExt._atomic_band_hdf5_write),
                    WannierNLQGSymmetryFoundationExt.var"#85#94"{
                        Nothing,
                        Nothing,
                        Symbol,
                        Symbol,
                        Symbol,
                        WannierNLQG.SymmetryFoundation.BandRepresentation,
                        WannierNLQGSymmetryFoundationExt.BandRepresentationProductTable,
                        Nothing,
                        Nothing,
                        Nothing,
                        Nothing,
                    },
                    String,
                },
            )
            _record_foundation(
                Tuple{
                    typeof(Base.getproperty),
                    WannierNLQGSymmetryFoundationExt.BandRepresentationProductTable,
                    Symbol,
                },
            )
        end
        @assert !WannierNLQG.MPI.Initialized()
    end
end
