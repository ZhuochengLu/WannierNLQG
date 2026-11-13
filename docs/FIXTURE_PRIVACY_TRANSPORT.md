# Fixture privacy transport

A small set of synthetic historical fixtures contained private temporary output
paths. Their published copies replace only the declared path metadata. Every
numeric HDF5 item retains shape, dtype and raw numeric bytes; JSON numeric values
and the independent binary companions remain unchanged. The artifact12 descriptor
retains its numeric leaves and already normalized semantic fields; only its raw
container hash and file-size bookkeeping follow the transported container.

This is fixture transport, not a new producer execution, historical-seal
re-authentication, material qualification or an alteration of current reader
acceptance. Original fixture bytes and identities are retained outside the public
package. [The transport receipt](fixture_privacy_transport.json) names the changed
fields and original/published hashes without carrying the removed private paths.
