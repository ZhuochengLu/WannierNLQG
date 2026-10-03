"""Exact native science equality with explicit attested transport bindings.

No numeric, shape, status, tolerance or scientific metadata field is normalized.
Path-bound digests may differ only after the official per-artifact verification.
"""
import copy
import hashlib
import json
from pathlib import Path
from comparison_contract import attest_native_report


def at(mapping, path):
    current = mapping
    for key in path[:-1]:
        current = current[key]
    return current, path[-1]


def _compare(actual, reference, contract, *, payload_root, integrity=None, sealed=False):
    a,b=copy.deepcopy(actual),copy.deepcopy(reference)
    if isinstance(a,dict) and 'artifact' in a:
        attest_native_report(a)
        if not sealed:
            attest_native_report(b)
        # Each report is attested to its own retained raw artifact. HDF5
        # layout, string lengths, generated times and path-bound digests can
        # affect raw bytes without changing any scientific dataset bit.
        for key in ('artifact','artifact_sha256','raw_file_bytes'):
            a.pop(key,None);b.pop(key,None)
    allowed_times = {('generated_at_utc',), ('semantic_fields', '/environment/@generated_at_utc'),
                     ('semantic_fields', '/@generated_at_utc')}
    for path in contract.get('generated_time_fields',[]):
        if tuple(path) not in allowed_times:
            raise ValueError('GENERATED_TIME_EXCLUSION_NOT_PERMITTED')
        aa,key=at(a,path);bb,_=at(b,path)
        if not isinstance(aa[key],str) or not isinstance(bb[key],str):
            raise ValueError('GENERATED_TIME_METADATA_TYPE_CHANGED')
        del aa[key];del bb[key]
    for binding in contract.get('input_digest_bindings',[]):
        aa,key=at(a,binding['field']);bb,_=at(b,binding['field'])
        if aa[key]!=binding['portable_sha256'] or bb[key]!=binding['original_sha256']:
            raise ValueError('PREDECLARED_INPUT_DIGEST_BINDING_CHANGED')
        bb[key]=aa[key]
    for binding in contract.get('input_locator_bindings',[]):
        aa,key=at(a,binding['field']);bb,_=at(b,binding['field'])
        expected=str(Path(payload_root)/binding['relative'])
        if aa[key]!=expected or bb[key]!=binding['original']:
            raise ValueError('PREDECLARED_INPUT_LOCATOR_CHANGED')
        bb[key]=aa[key]
    outputs=contract.get('temporary_output_pair',[])
    if outputs:
        parents=[]
        for binding in outputs:
            aa,key=at(a,binding['field']);bb,_=at(b,binding['field'])
            if Path(aa[key]).name!=binding['basename'] or Path(bb[key]).name!=binding['basename']:
                raise ValueError('DECLARED_NATIVE_OUTPUT_BASENAME_CHANGED')
            parents.append((str(Path(aa[key]).parent),str(Path(bb[key]).parent)))
            bb[key]=aa[key]
        if len(set(parents))!=1:
            raise ValueError('DECLARED_NATIVE_OUTPUT_PAIR_DIRECTORY_CHANGED')
    for path in contract.get('official_path_bound_digest_fields',[]):
        if not integrity or integrity.get('official_digest_and_readback') is not True:
            raise ValueError('OFFICIAL_COUPLED_DIGEST_VERIFICATION_REQUIRED')
        if integrity.get('artifact_sha256')!=actual.get('artifact_sha256'):
            raise ValueError('OFFICIAL_VERIFICATION_ARTIFACT_CHANGED')
        aa,key=at(a,path);bb,_=at(b,path)
        if not isinstance(aa[key],str) or not isinstance(bb[key],str):
            raise ValueError('COUPLED_DIGEST_METADATA_TYPE_CHANGED')
        verified = [x for x in integrity.get('verified_digest_fields', []) if x.get('field') == path]
        if len(verified) != 1 or verified[0].get('value') != aa[key]:
            raise ValueError('OFFICIAL_DIGEST_FIELD_READBACK_CHANGED')
        bb[key]=aa[key]
    return a==b


def compare_extra(actual, reference, contract, *, payload_root, integrity=None):
    return _compare(actual, reference, contract, payload_root=payload_root, integrity=integrity)


def compare_sealed_extra(actual, reference_file, reference_sha256, contract, *, payload_root, integrity=None):
    """Compare with a shipped reference whose original artifact was attested at sealing.

    The reference file's exact digest is bound by the frozen scientific index.
    It retains the original raw artifact digest and size as provenance, while
    current actual artifacts must still pass a fresh byte digest/size check.
    """
    content = Path(reference_file).read_bytes()
    if hashlib.sha256(content).hexdigest() != reference_sha256:
        raise ValueError('SEALED_NATIVE_REFERENCE_SHA_MISMATCH')
    envelope = json.loads(content)
    reference = envelope['report']
    if 'artifact' in reference:
        raise ValueError('SEALED_REFERENCE_HAS_RUNTIME_ARTIFACT_PATH')
    if 'artifact' in actual:
        attestation = envelope.get('original_artifact_attestation', {})
        if attestation.get('verified') is not True or attestation.get('sha256') != reference.get('artifact_sha256') or attestation.get('bytes') != reference.get('raw_file_bytes'):
            raise ValueError('SEALED_ORIGINAL_ATTESTATION_MISSING')
        reference = dict(reference, artifact='<sealed-original-artifact>')
    return _compare(actual, reference, contract, payload_root=payload_root, integrity=integrity, sealed=True)
