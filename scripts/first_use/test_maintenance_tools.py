"""Real comparator goldens and corrupt transport/provenance rejection tests."""
import copy
import json
from pathlib import Path
import shutil
import sys
import tempfile
sys.dont_write_bytecode = True
from comparison_contract import compare_first_call, compare_native_science
from provenance_shards import reconstruct, write_shards
from fixture_bundle import verify, rehydrate
ROOT = Path(__file__).resolve().parents[2]
golden_root = ROOT / 'test/fixtures/first_use_comparison'
goldens = json.loads((golden_root / 'goldens.json').read_text())['rows']
results = []
for record in goldens:
    for side in ('actual', 'reference'):
        native = record[side]['native_readback']
        if native:
            native['artifact'] = str(golden_root / native['artifact'])
    assert all(compare_first_call(record['actual'], record['reference'], record['contract'], gc_on=True).values())
    if 'native_actual' in record:
        assert compare_native_science(record['native_actual'], record['native_reference'])
contracts = [next(x['contract'] for x in goldens if x['id'] == name) for name in ('write_response_symmetry_artifact','prepare_band_representation','generate_qe_paw_spn','generate_wannier_uiu')]
rows = [dict(id=x['id'], first=x['actual']) for x in goldens]
writer = rows[0]['first']; ref = goldens[0]['reference']; c = contracts[0]
def rejected(label,mutate,contract=c,gc=True,base=writer,reference=ref):
 a=copy.deepcopy(base);mutate(a)
 try:checks=compare_first_call(a,reference,contract,gc_on=gc);failed=not all(checks.values())
 except (ValueError,KeyError):failed=True
 assert failed,label
 results.append(dict(negative=label,rejected=True))
rejected('GC_disabled',lambda a:None,gc=False)
rejected('target_backend_already_active',lambda a:a['extension_state_before'].__setitem__('WannierNLQGSymmetrizationExt',True))
rejected('required_foundation_already_active',lambda a:a['extension_state_before'].__setitem__('WannierNLQGSymmetryFoundationExt',True))
rejected('backend_inventory_missing',lambda a:a['extension_state_before'].pop('WannierNLQGOperatorBundleExt'))
rejected('compile_over_limit',lambda a:a.__setitem__('compile_time',.500000001))
rejected('recompile_not_subset',lambda a:a.__setitem__('recompile_time',a['compile_time']+1))
rejected('native_number_bits_changed',lambda a:a['native_readback']['numeric_leaves'][0].__setitem__('payload','ffffffffffffffff'))
rejected('native_field_dropped',lambda a:a['native_readback']['numeric_leaves'].pop())
rejected('artifact_SHA_changed',lambda a:a['native_readback'].__setitem__('artifact_sha256','changed'))
# Signed zero must fail even though Python 0.0 == -0.0.
band=next(r['first'] for r in rows if r['id']=='prepare_band_representation');bref=next(x['reference'] for x in goldens if x['id']=='prepare_band_representation')
zero=next(x for x in band['return_summary']['leaves'] if x.get('payload')=='0000000000000000' and x.get('type')=='Float64')
rejected('positive_zero_to_negative_zero',lambda a:next(x for x in a['return_summary']['leaves'] if x['path']==zero['path']).__setitem__('payload','0000000000000080'),contract=contracts[1],base=band,reference=bref)
rejected('scientific_shape_changed',lambda a:next(x for x in a['return_summary']['leaves'] if 'shape' in x).__setitem__('shape',[999]),contract=contracts[1],base=band,reference=bref)
rejected('semantic_return_changed',lambda a:a.__setitem__('semantic_return','changed'),contract=contracts[1],base=band,reference=bref)
# Only frozen unrelated backend is permitted for band preparation.
assert band['extension_state_before']['WannierNLQGOperatorBundleExt'] is True
assert all(compare_first_call(band,bref,contracts[1],gc_on=True).values())

assert len(results) == 12
with tempfile.TemporaryDirectory(prefix='nlqg-maintenance-tests-') as temporary:
    scratch = Path(temporary)
    source = ROOT / 'docs/first_use_signature_provenance'
    canonical, metadata = reconstruct(source)
    regenerated = scratch / 'regenerated'
    write_shards(canonical, regenerated)
    assert reconstruct(regenerated)[0] == canonical
    shard_negative = 0
    for mode in ('missing', 'corrupt', 'duplicate', 'path_escape', 'row_count', 'source', 'canonical'):
        target = scratch / ('shard_' + mode)
        shutil.copytree(source, target)
        index = json.loads((target / 'index.json').read_text())
        part = target / index['parts'][0]['file']
        if mode == 'missing':
            part.unlink()
        elif mode == 'corrupt':
            value = bytearray(part.read_bytes()); value[-2] ^= 1; part.write_bytes(value)
        elif mode == 'duplicate':
            index['parts'].append(index['parts'][0])
        elif mode == 'path_escape':
            index['parts'][0]['file'] = '../outside.tsv'
        elif mode == 'row_count':
            index['retained_rows'] += 1
        elif mode == 'source':
            index['source_src_ext_sha256'] = 'wrong'
        else:
            index['canonical_sha256'] = 'wrong'
        (target / 'index.json').write_text(json.dumps(index))
        try:
            reconstruct(target)
        except (ValueError, OSError):
            shard_negative += 1
        else:
            raise AssertionError(mode)
    assert shard_negative == 7
    fixture = ROOT / 'test/fixtures/first_use_portable'
    restored = scratch / 'portable'
    assert verify(fixture) == rehydrate(fixture, restored)
    fixture_negative = 0
    for mode in ('corrupt', 'duplicate', 'role', 'extra', 'ancestor_link'):
        target = scratch / ('fixture_' + mode)
        shutil.copytree(fixture, target)
        index = json.loads((target / 'manifest.json').read_text())
        if mode == 'corrupt':
            part = target / index['files'][0]['file']; value = bytearray(part.read_bytes()); value[0] ^= 1; part.write_bytes(value)
        elif mode == 'duplicate':
            index['files'].append(index['files'][0])
        elif mode == 'role':
            index['paths'][next(iter(index['paths']))]['role'] = 'invalid'
        elif mode == 'extra':
            (target / 'undeclared.txt').write_text('extra')
        else:
            shutil.rmtree(target / 'arguments'); (target / 'arguments').symlink_to(fixture / 'arguments', target_is_directory=True)
        (target / 'manifest.json').write_text(json.dumps(index))
        try:
            verify(target)
        except (ValueError, OSError):
            fixture_negative += 1
        else:
            raise AssertionError(mode)
    assert fixture_negative == 5
print(json.dumps(dict(real_comparator_positives=8, comparator_negatives=12, provenance_roundtrip=True, provenance_negatives=7, fixture_rehydration=True, fixture_negatives=5)))
