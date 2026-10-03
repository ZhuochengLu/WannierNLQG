"""Compile observed external finalizer entrypoints during lazy extension loading.

Julia 1.11.2 restored inferred HDF5 finalizer CodeInstances without native entry
pointers despite declarations and workload execution. This bounded fallback is
charged to the real first public call. It neither runs finalizers nor changes GC.
"""
function __init__()
    for type in (
        HDF5.Datatype,
        HDF5.AttributeAccessProperties,
        HDF5.LinkAccessProperties,
        HDF5.DatasetTransferProperties,
        HDF5.FileCreateProperties,
        HDF5.StringCreateProperties,
        HDF5.ObjectCreateProperties,
        HDF5.ObjectCopyProperties,
        HDF5.LinkCreateProperties,
        HDF5.GroupCreateProperties,
        HDF5.GroupAccessProperties,
        HDF5.FileMountProperties,
        HDF5.DatatypeCreateProperties,
        HDF5.DatatypeAccessProperties,
        HDF5.DatasetAccessProperties,
        HDF5.AttributeCreateProperties,
    )
        precompile(HDF5.API.try_close_finalizer, (type,))
    end
    return nothing
end
