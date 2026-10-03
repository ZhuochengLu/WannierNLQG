"""Real native goldens and field-specific transport rejection tests."""
import copy
import hashlib
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
from native_science_contract import compare_sealed_extra, at
ROOT = Path(__file__).resolve().parents[2]
G = ROOT / 'test/fixtures/first_use_science'
references = json.loads((G / 'native_index.json').read_text())['records']
goldens = json.loads((G / 'native_goldens.json').read_text())['records']
cases = []
for reference, golden in zip(references, goldens, strict=True):
    assert reference['id'] == golden['id'] and reference['native_report'] == golden['native_report']
    # Sealed goldens are historical observations, not outputs from the repacked
    # transport. Live scenes use native_index's current physical input binding.
    reference = copy.deepcopy(reference)
    for binding in reference['contract'].get('input_digest_bindings', []):
        if 'historical_portable_sha256' in binding:
            binding['portable_sha256'] = binding['historical_portable_sha256']
    content = (G / golden['actual']).read_bytes()
    assert hashlib.sha256(content).hexdigest() == golden['actual_sha256']
    actual = json.loads(content)
    if isinstance(actual, dict) and 'artifact' in actual:
        actual['artifact'] = str(G / actual['artifact'])
    def compare(a=actual, c=reference['contract'], p=golden['integrity'], digest=reference['reference_sha256'], file=G/reference['reference']):
        return compare_sealed_extra(a, file, digest, c, payload_root='golden-payload', integrity=p)
    assert compare()
    cases.append((actual, reference, golden))
results = []
def reject(label, case, mutate_actual=lambda a: None, mutate_contract=lambda c: None, mutate_proof=lambda p: None, digest=None):
    actual, reference, golden = copy.deepcopy(case)
    contract = reference['contract']; proof = golden['integrity']
    mutate_actual(actual); mutate_contract(contract); mutate_proof(proof)
    try:
        passed = compare_sealed_extra(actual, G/reference['reference'], digest or reference['reference_sha256'], contract, payload_root='golden-payload', integrity=proof)
    except (ValueError, KeyError, OSError, TypeError):
        passed = False
    assert passed is False, label
    results.append(label)
artifact = next(x for x in cases if isinstance(x[0], dict) and 'artifact' in x[0])
reject('artifact_digest_changed', artifact, lambda a: a.__setitem__('artifact_sha256', '0'*64))
reject('artifact_size_changed', artifact, lambda a: a.__setitem__('raw_file_bytes', a['raw_file_bytes']+1))
reject('sealed_reference_digest_changed', artifact, digest='0'*64)
reject('scientific_field_removed', artifact, lambda a: a['numeric_leaves'].pop())
reject('scientific_shape_changed', artifact, lambda a: a.__setitem__('dataset_paths', a['dataset_paths']+['/invented']))
reject('scientific_bits_changed', artifact, lambda a: a['numeric_leaves'][0].__setitem__('payload', 'ffffffffffffffff'))
time_case = next(x for x in cases if x[1]['contract'].get('generated_time_fields'))
time_field = time_case[1]['contract']['generated_time_fields'][0]
def set_field(a, field, value):
    parent, key = at(a, field); parent[key] = value
reject('generated_time_wrong_type', time_case, lambda a: set_field(a, time_field, 1))
reject('arbitrary_generated_time_exclusion', artifact, mutate_contract=lambda c: c.__setitem__('generated_time_fields', [['numeric_leaves']]))
input_case = next(x for x in cases if x[1]['contract'].get('input_digest_bindings'))
input_field = input_case[1]['contract']['input_digest_bindings'][0]['field']
reject('input_digest_unbound', input_case, lambda a: set_field(a, input_field, '0'*64))
locator_case = next(x for x in cases if x[1]['contract'].get('input_locator_bindings'))
locator_field = locator_case[1]['contract']['input_locator_bindings'][0]['field']
reject('input_locator_unbound', locator_case, lambda a: set_field(a, locator_field, 'elsewhere/fixture.save'))
coupled = next(x for x in cases if x[1]['contract'].get('official_path_bound_digest_fields'))
field = coupled[1]['contract']['official_path_bound_digest_fields'][0]
reject('official_verification_missing', coupled, mutate_proof=lambda p: p.__setitem__('official_digest_and_readback', False))
reject('official_artifact_changed', coupled, mutate_proof=lambda p: p.__setitem__('artifact_sha256', '0'*64))
reject('official_readback_missing', coupled, mutate_proof=lambda p: p.__setitem__('verified_digest_fields', []))
reject('coupled_digest_report_tampered', coupled, lambda a: set_field(a, field, '0'*64))
pair = next(x for x in cases if x[1]['contract'].get('temporary_output_pair'))
field = pair[1]['contract']['temporary_output_pair'][0]['field']
reject('output_basename_changed', pair, lambda a: set_field(a, field, 'golden-outputs/wrong.spn'))
reject('output_pair_directory_changed', pair, lambda a: set_field(a, field, 'different/native.spn'))
assert len(cases) == 28 and len(results) == 16
print(json.dumps(dict(real_native_positives=28, native_negatives=results, bitwise_comparison=True, final_pass=False)))
