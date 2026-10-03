"""Qualify every actual rank against sealed original scientific evidence."""
import copy
import hashlib
import json
from pathlib import Path
import re
from comparison_contract import BACKEND_NAMES, attest_native_report
from native_science_contract import compare_sealed_extra
ROOT = Path(__file__).resolve().parents[2]
REFERENCES = ROOT / 'test/fixtures/first_use_science'
HDF5_TIME_WRITERS = frozenset(('write_band_representation_hdf5', 'write_wannierization_checkpoint_hdf5', 'write_wannierization_u_convergence_diagnostics_hdf5'))


def read_reference(scene):
    rows = json.loads((REFERENCES/'expert_index.json').read_text())['records']
    row = next(x for x in rows if x['id'] == scene['id'])
    content = (REFERENCES/row['reference']).read_bytes()
    if hashlib.sha256(content).hexdigest() != row['reference_sha256']:
        raise ValueError('EXPERT_SCIENTIFIC_REFERENCE_CHANGED')
    value = json.loads(content)
    if value['id'] != scene['id'] or len(value['ranks']) != scene['mpi_size']:
        raise ValueError('EXPERT_SCIENTIFIC_RANK_REFERENCE_CHANGED')
    return value


def return_bits(summary, scene):
    return dict(type=summary['type'], all_finite=summary['all_finite'],
                leaves=[x for x in summary['leaves'] if x['path'] not in scene['excluded_return_fields']])


def semantic(value, identifier):
    if identifier == 'diagnose_wannier_gauge_chain':
        for filename in ('actual.gauge-chain.json', 'actual.gauge-chain.h5'):
            paths = re.findall(r'"([^"\n]*/'+re.escape(filename)+r')"', value)
            if len(paths) != 1:
                raise ValueError('GAUGE_RESULT_OUTPUT_LOCATOR_CHANGED')
            value = value.replace('"'+paths[0]+'"', '"output/'+filename+'"')
    return value


def primary_native_equal(actual, reference, identifier):
    if actual is None or reference is None:
        return actual is reference
    attest_native_report(actual)
    original = reference['original_artifact_attestation']
    baseline = copy.deepcopy(reference['report'])
    if original != dict(verified=True, sha256=baseline['artifact_sha256'], bytes=baseline['raw_file_bytes']):
        raise ValueError('ORIGINAL_WRITER_ATTESTATION_CHANGED')
    value = copy.deepcopy(actual)
    for key in ('artifact', 'artifact_sha256', 'raw_file_bytes'):
        value.pop(key, None); baseline.pop(key, None)
    if identifier in HDF5_TIME_WRITERS:
        key = '/environment/@generated_at_utc'
        for report in (value, baseline):
            if not isinstance(report['semantic_fields'][key], str):
                raise ValueError('GENERATED_TIME_METADATA_TYPE_CHANGED')
            del report['semantic_fields'][key]
    if value != baseline:
        return False
    if actual['format'] == 'json':
        payload = json.loads(Path(actual['artifact']).read_text())
        expected = copy.deepcopy(reference['json_payload'])
        if identifier == 'write_response_symmetry_artifact':
            for report in (payload, expected):
                if not isinstance(report['generated_at_utc'], str):
                    raise ValueError('GENERATED_TIME_METADATA_TYPE_CHANGED')
                del report['generated_at_utc']
        return payload == expected
    return actual['format'] == 'hdf5'


def cold_checks(receipt, scene):
    if scene['kind'] == 'generic':
        calls = receipt['first_calls']
        if len(calls) != 1 or calls[0]['target'] != scene['public_target']:
            raise ValueError('EXPERT_ACTUAL_TARGET_CALL_CHANGED')
        first = calls[0]
        checks = dict(fixture_passed=receipt['fixture_passed'] is True,
                      success=first['success'] is True, gc_on=first['gc_on_at_target'] is True)
        states = [first['extension_state_before']]
        timers = [first]
    else:
        checks = dict(gc_on=receipt['gc_on'] is True and receipt['gc_checked_at_every_timer'] is True)
        inventories = receipt['backend_state_at_every_timer']
        if scene['id'] == 'write_band_representation_summary':
            if len(inventories) != 3:
                raise ValueError('WRITER_PIPELINE_TIMER_COUNT_CHANGED')
            # Actual validation is the required backend owner activation; the
            # subsequent writer receives that concrete validation value.
            states = [inventories[1]]
            timers = [receipt['validation'], receipt['writer']]
            checks['actual_prerequisite'] = receipt['validation_before_backend'] is False and receipt['writer_before_backend'] is True
            checks['writer_backend_lifecycle'] = inventories[1]['WannierNLQGSymmetryFoundationExt'] is False and inventories[2]['WannierNLQGSymmetryFoundationExt'] is True
        else:
            index = 2 if scene['id'] == 'authoritative_band_hamiltonian' else 1
            states = [inventories[index]]
            timers = [receipt]
    if any(frozenset(state) != BACKEND_NAMES for state in states):
        raise ValueError('EXPERT_BACKEND_INVENTORY_CHANGED')
    required = scene['required_absent_backends']
    if not required and scene['id'] != 'write_band_representation_summary':
        raise ValueError('EXPERT_BACKEND_REQUIREMENTS_EMPTY')
    if scene['id'] == 'write_band_representation_summary':
        required = ['WannierNLQGSymmetryFoundationExt']
    checks['cold_required_backends'] = all(not state[name] for state in states for name in required)
    checks['compile_time'] = all(0 <= t['compile_time'] <= scene['compile_limit_seconds'] for t in timers)
    checks['recompile_subset'] = all(0 <= t['recompile_time'] <= t['compile_time'] for t in timers)
    return checks, max(t['compile_time'] for t in timers)


def qualify_scene(scene, directory, *, payload_root, integrity_by_sha=None, speed=True):
    directory = Path(directory)
    references = read_reference(scene)
    rows = []
    for original in references['ranks']:
        rank = original['rank']
        rank_directory = directory/f'rank_{rank}' if scene['mpi_size'] > 1 else directory
        receipt = json.loads((rank_directory/'receipt.json').read_text())
        science = original['science']
        if scene['kind'] == 'generic':
            first = receipt['first_calls'][0]
            exact = return_bits(first['return_summary'], scene) == science['return_bits']
            exact &= semantic(first['semantic_return'], scene['id']) == science['semantic_return']
            exact &= primary_native_equal(first['native_readback'], science['native_readback'], scene['id'])
        elif scene['id'] == 'write_band_representation_summary':
            exact = all(receipt[k] == v for k,v in science.items())
            exact &= hashlib.sha256((rank_directory/'band_summary.json').read_bytes()).hexdigest() == receipt['native_output_sha256']
        else:
            exact = return_bits(receipt['return_summary'], scene) == science['return_bits']
        if 'solver_native_result' in original:
            # Generic fixture outputs differ only in their explicitly chosen
            # output directory. Scientific result fields are never normalized.
            result_file = rank_directory/'result.json'
            if not result_file.exists():
                result_file = rank_directory/'fixture_output/result.json'
            native_result = json.loads(result_file.read_text())
            exact &= {k:native_result[k] for k in original['solver_native_result']} == original['solver_native_result']
        if 'effective_updates' in original:
            exact &= json.loads((rank_directory/'effective_updates.json').read_text()) == original['effective_updates']
            restored = json.loads((rank_directory/'checkpoint_readback_numeric.json').read_text())
            exact &= return_bits(restored, scene) == original['checkpoint_readback_return_bits']
        extras = [x for x in json.loads((REFERENCES/'native_index.json').read_text())['records'] if x['id'] == scene['id']]
        for extra in extras:
            actual = json.loads((rank_directory/extra['native_report']).read_text())
            proof = (integrity_by_sha or {}).get(actual.get('artifact_sha256')) if isinstance(actual, dict) else None
            exact &= compare_sealed_extra(actual, REFERENCES/extra['reference'], extra['reference_sha256'], extra['contract'], payload_root=payload_root, integrity=proof)
        if speed:
            checks, compile_seconds = cold_checks(receipt, scene)
        else:
            checks, compile_seconds = {}, None
        rows.append(dict(rank=rank, scientific_bits_and_semantics_exact=bool(exact), cold_checks=checks, compile_time=compile_seconds))
    return dict(id=scene['id'], ranks=rows,
                max_rank_compile_time=max(x['compile_time'] for x in rows) if speed else None,
                passed=all(x['scientific_bits_and_semantics_exact'] and all(x['cold_checks'].values()) for x in rows),
                speed_qualified=speed, solver_quality_qualified=False)
