"""Compare actual cold evidence using explicit, frozen per-scene contracts.

No tolerance, inferred backend exclusions, best-sample selection, or numerical
normalization. Receipt locations and file hashes are attested separately.
"""
import hashlib
import json
from pathlib import Path

BACKEND_NAMES=frozenset(('WannierNLQGWannierizationPrecompileExt',
    'WannierNLQGWannierizationExt','WannierNLQGOperatorBundleExt',
    'WannierNLQGSymmetryFoundationExt','WannierNLQGSymmetrizationExt'))

def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def attest_native_report(report):
    if report is None:return
    if sha256(report['artifact'])!=report['artifact_sha256']:
        raise ValueError('NATIVE_ARTIFACT_SHA_MISMATCH')
    if Path(report['artifact']).stat().st_size!=report['raw_file_bytes']:
        raise ValueError('NATIVE_ARTIFACT_SIZE_MISMATCH')

def compare_native_report(actual,reference,contract):
    if actual is None or reference is None:return actual is reference
    attest_native_report(actual);attest_native_report(reference)
    if actual['format']!=reference['format'] or actual['numeric_leaves']!=reference['numeric_leaves']:
        return False
    if actual['format']=='json':
        a=json.loads(Path(actual['artifact']).read_text())
        b=json.loads(Path(reference['artifact']).read_text())
        for key in contract['ignored_json_top_level_metadata']:
            if key not in a or key not in b:raise ValueError('DECLARED_METADATA_KEY_MISSING')
            del a[key];del b[key]
        return a==b and actual['top_level_keys']==reference['top_level_keys']
    if actual['format']=='hdf5':
        ignored=frozenset(contract.get('ignored_hdf5_metadata_fields', []))
        permitted=frozenset(('/environment/@generated_at_utc','/@generated_at_utc'))
        if not ignored<=permitted:raise ValueError('HDF5_METADATA_EXCLUSION_NOT_PERMITTED')
        a=dict(actual['semantic_fields']);b=dict(reference['semantic_fields'])
        for key in ignored:
            if key not in a or key not in b:raise ValueError('DECLARED_METADATA_KEY_MISSING')
            if not isinstance(a[key],str) or not isinstance(b[key],str):
                raise ValueError('HDF5_METADATA_TYPE_CHANGED')
            del a[key];del b[key]
        return actual['dataset_paths']==reference['dataset_paths'] and a==b
    raise ValueError('UNKNOWN_NATIVE_FORMAT')

def compare_first_call(actual,reference,contract,*,gc_on):
    required=frozenset(contract['required_absent_backends'])
    if not required or not required<=BACKEND_NAMES:raise ValueError('INVALID_REQUIRED_BACKEND_CONTRACT')
    if frozenset(actual['extension_state_before'])!=BACKEND_NAMES:
        raise ValueError('BACKEND_INVENTORY_CHANGED')
    excluded=frozenset(contract['excluded_return_fields'])
    fields=lambda r:[x for x in r['return_summary']['leaves'] if x['path'] not in excluded]
    if contract['native_kind']=='writer':
        native=compare_native_report(actual['native_readback'],reference['native_readback'],contract)
    else:
        native=True  # Separate exact native-science payload is mandatory below.
    checks=dict(gc_on=gc_on is True,success=actual['success'] is True,
        cold_backend=not any(actual['extension_state_before'][name] for name in required),
        compile_time=0<=actual['compile_time']<=contract['compile_limit_seconds'],
        recompile_subset=0<=actual['recompile_time']<=actual['compile_time'],
        scientific_return_bits=fields(actual)==fields(reference),
        native_readback=native,
        semantic_return=(actual['semantic_return']==reference['semantic_return']
            if contract['compare_semantic_return'] else True))
    return checks

def compare_native_science(actual,reference):
    # This must include every native dataset / semantic field present in the
    # frozen record. Exclusions cannot be invented by the comparator.
    return actual==reference
