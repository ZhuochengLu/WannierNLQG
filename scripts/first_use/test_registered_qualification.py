#!/usr/bin/env python3
"""Exercise sealed native comparators without running or warming scientific code."""
import copy
import hashlib
import json
from pathlib import Path
import struct
import sys
import tempfile
sys.dont_write_bytecode = True
from registered_science import TASK_KEYS, outputs, rank_output_inventory
from qualify_registered_scene import ROOT, cold, reference
from release_inventory import verify_release

PRODUCER = 'a' * 64
SOURCE = 'b' * 64


def restore_json(value):
    if isinstance(value, dict):
        if set(value) == {'float64_bits'}:
            return struct.unpack('>d', bytes.fromhex(value['float64_bits']))[0]
        return {k: restore_json(v) for k, v in value.items()}
    if isinstance(value, list):
        return [restore_json(v) for v in value]
    return value


def materialize(case, ranks, directory):
    gold = reference(case, ranks)['native_science']
    tasks = {}
    for relative, record in gold.items():
        if 'metadata_lines' not in record:
            continue
        lines = [v.replace('<attested-source>', SOURCE).replace('<attested-producer>', PRODUCER)
                 for v in record['metadata_lines']]
        fields = dict(line.split(' = ', 1) for line in lines)
        task = None
        if fields['task_sha256'] != '"NOT_APPLICABLE"':
            task = hashlib.sha256(''.join(k+'='+json.loads(fields[k])+'\0'
                                         for k in TASK_KEYS).encode()).hexdigest()
            lines = [v.replace('<attested-task>', task) for v in lines]
        tasks[Path(relative).parent] = task
        path = directory/'first'/relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('\n'.join(lines)+'\n')
    paths = []
    for relative, record in gold.items():
        path = directory/'first'/relative
        path.parent.mkdir(parents=True, exist_ok=True)
        paths.append(str(path))
        if 'native_float_bits' in record:
            task = tasks.get(Path(relative).parent)
            headers = [v.replace('<attested-producer>', PRODUCER).replace('<attested-task>', task or '')
                       for v in record['headers']]
            width = record['shape'][1]
            values = [repr(struct.unpack('>d', bytes.fromhex(v))[0]) for v in record['native_float_bits']]
            lines = [' '.join(values[i:i+width]) for i in range(0, len(values), width)]
            path.write_text('\n'.join(headers+lines)+'\n')
        elif 'json_science' in record:
            path.write_text(json.dumps(restore_json(record['json_science']))+'\n')
    receipt = {'first_outputs': paths}
    assert outputs(case, receipt, directory, release_tree=PRODUCER, spectral_source=SOURCE) == gold
    return receipt, gold


def main():
    cases = json.loads((ROOT/'scripts/first_use/path_registry.json').read_text())
    rejected = []
    with tempfile.TemporaryDirectory(prefix='registered-comparator-') as temporary:
        root = Path(temporary)
        for ranks in (1, 12):
            for case in cases:
                directory=root/f'r{ranks}'/case['id']
                materialize(case, ranks, directory)
                expected=reference(case,ranks)['rank_output_inventory']
                records=[{'first_outputs':[str(directory/'first'/name) for name in names]} for names in expected]
                assert rank_output_inventory(records,directory)==expected
        case = next(c for c in cases if c['id'] == 'integral__linear_transport__conventional')
        directory = root/'r1'/case['id']
        receipt, gold = materialize(case, 1, directory)
        metadata = next(Path(p) for p in receipt['first_outputs'] if p.endswith('.txt'))
        table = next(Path(p) for p in receipt['first_outputs'] if p.endswith('.dat'))
        def reject(label, path, replace):
            original = path.read_text()
            changed = replace(original)
            assert changed != original, label
            path.write_text(changed)
            try:
                try:
                    observed = outputs(case, receipt, directory, release_tree=PRODUCER, spectral_source=SOURCE)
                except (ValueError, KeyError, json.JSONDecodeError):
                    rejected.append(label)
                else:
                    assert observed != gold, label
                    rejected.append(label)
            finally:
                path.write_text(original)
        reject('source digest', metadata, lambda s:s.replace(SOURCE, 'c'*64))
        reject('producer digest', metadata, lambda s:s.replace(PRODUCER, 'c'*64))
        reject('task digest', metadata, lambda s:s.replace('task_sha256 = "', 'task_sha256 = "0', 1))
        reject('task input', metadata, lambda s:s.replace('temperature_K = "300.0"', 'temperature_K = "301.0"'))
        reject('table task binding', table, lambda s:s.replace('# task_sha256=', '# task_sha256=0', 1))
        reject('table metadata binding', table, lambda s:s.replace('# temperature_K=300.0', '# temperature_K=301.0'))
        reject('metadata scientific field', metadata, lambda s:s.replace('cell_volume_m3 = ', 'cell_volume_m3 = 2', 1))
        reject('metadata duplicate', metadata, lambda s:s+'source_sha256 = "'+SOURCE+'"\n')
        reject('numeric nonfinite', table, lambda s:s+'NaN '*gold[next(k for k in gold if k.endswith('.dat'))]['shape'][1]+'\n')
        reject('numeric shape', table, lambda s:s+'1.0\n')
        # A single zero bit changes the result even when max_abs is still zero.
        original = copy.deepcopy(gold)
        entry = next(v for v in original.values() if 'native_float_bits' in v)
        position = next(i for i,v in enumerate(entry['native_float_bits']) if v in ('0000000000000000','8000000000000000'))
        entry['native_float_bits'][position] = ('8000000000000000' if entry['native_float_bits'][position]=='0000000000000000' else '0000000000000000')
        assert original != gold
        rejected.append('signed zero equality')
        mpi_reference=reference(case,12)['rank_output_inventory']
        assert mpi_reference[0] and mpi_reference[1]==[]
        mpi_records=[{'first_outputs':[str(directory/'first'/name) for name in names]} for names in mpi_reference]
        incorrect=copy.deepcopy(mpi_records)
        incorrect[1]=copy.deepcopy(incorrect[0])
        assert rank_output_inventory(incorrect,directory)!=mpi_reference
        rejected.append('root-only writer rank contract')
        incorrect=copy.deepcopy(mpi_records)
        incorrect[0]['first_outputs'].append(incorrect[0]['first_outputs'][0])
        try:
            rank_output_inventory(incorrect,directory)
        except ValueError:
            rejected.append('duplicate rank output')
        else:
            raise AssertionError('duplicate rank output')
        duplicate = dict(receipt, first_outputs=receipt['first_outputs']+[receipt['first_outputs'][0]])
        try:
            outputs(case, duplicate, directory, release_tree=PRODUCER, spectral_source=SOURCE)
        except ValueError:
            rejected.append('duplicate inventory')
        else:
            raise AssertionError('duplicate inventory')
        record = dict(path=case['example'], rank=0, package_root=str(ROOT), gc_on=True,
                      workload_enabled=True, extension_state_before={k:False for k in ('WannierNLQGMPIExt','WannierNLQGResponseSymmetryExt','WannierNLQGSymmetrizationExt','WannierNLQGSymmetryFoundationExt','WannierNLQGWannierizationExt')},
                      mpi_initialized_before=False, julia_threads=1, blas_threads=1, fftw_threads=1,
                      mpi_library='Open MPI 5.0.9', julia_version='1.11.2', first={'compile_time':.4,'recompile_time':.1})
        from comparison_contract import BACKEND_NAMES
        record['extension_state_before'] = {k:False for k in BACKEND_NAMES}
        assert all(cold(record, case, 0, ROOT).values())
        mutations = {
            'GC': lambda x:x.update(gc_on=False),
            'workload': lambda x:x.update(workload_enabled=False),
            'MPI ahead': lambda x:x.update(mpi_initialized_before=True),
            'threads': lambda x:x.update(julia_threads=2),
            'MPI version': lambda x:x.update(mpi_library='Open MPI 5.0.8'),
            'Julia version': lambda x:x.update(julia_version='1.11.1'),
            'rank': lambda x:x.update(rank=1),
            'one rank over limit': lambda x:x['first'].update(compile_time=.500001),
            'negative compile': lambda x:x['first'].update(compile_time=-.1),
            'recompile double count': lambda x:x['first'].update(recompile_time=.41),
            'required backend active': lambda x:x['extension_state_before'].update({next(iter(BACKEND_NAMES)):True}),
        }
        for label, mutate in mutations.items():
            bad = copy.deepcopy(record)
            mutate(bad)
            assert not all(cold(bad, case, 0, ROOT).values()), label
            rejected.append(label)
        release = root/'release-inventory'
        release.mkdir()
        content = b'owned synthetic inventory\n'
        digest = hashlib.sha256(content).hexdigest()
        (release/'owned.txt').write_bytes(content)
        manifest = 'type\tbytes\tsha256\tpath\nfile\t'+str(len(content))+'\t'+digest+'\towned.txt\n'
        sums = digest+'  owned.txt\n'
        def reset_release():
            for path in release.iterdir():
                path.unlink()
            (release/'owned.txt').write_bytes(content)
            (release/'SOURCE_MANIFEST.tsv').write_text(manifest)
            (release/'SHA256SUMS').write_text(sums)
        reset_release()
        frozen = verify_release(release)
        assert frozen['release_tree_sha256'] == hashlib.sha256(b'owned.txt\0'+content).hexdigest()
        inventory_mutations = {
            'inventory content hash': lambda:(release/'owned.txt').write_bytes(b'changed'),
            'inventory added file': lambda:(release/'added.txt').write_bytes(b'added'),
            'inventory missing file': lambda:(release/'owned.txt').unlink(),
            'inventory sums': lambda:(release/'SHA256SUMS').write_text('changed\n'),
            'inventory duplicate row': lambda:(release/'SOURCE_MANIFEST.tsv').write_text(manifest+manifest.splitlines(True)[1]),
            'inventory symbolic link': lambda:(release/'linked.txt').symlink_to(release/'owned.txt'),
            'inventory bytecode': lambda:(release/'generated.pyc').write_bytes(b'bytecode'),
        }
        for label, mutate in inventory_mutations.items():
            reset_release()
            mutate()
            try:
                verify_release(release)
            except (ValueError, FileNotFoundError):
                rejected.append(label)
            else:
                raise AssertionError(label)
    print(json.dumps(dict(sealed_native_roundtrips=104, cold_comparator_positive=1,
                          negative_cases=len(rejected), rejected=rejected,
                          actual_speed_samples=False, final_pass=False), sort_keys=True))


if __name__ == '__main__':
    main()
