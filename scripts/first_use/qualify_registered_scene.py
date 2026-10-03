"""All-rank cold checks and exact native scientific equality for registered paths."""
import hashlib
import json
from pathlib import Path
from comparison_contract import BACKEND_NAMES
from registered_science import outputs, spectral_source_digest, rank_output_inventory
ROOT=Path(__file__).resolve().parents[2]
G=ROOT/'test/fixtures/first_use_registered_science'


def reference(case,ranks):
    rows=json.loads((G/'index.json').read_text())['records']
    row=next(x for x in rows if x['id']==case['id'] and x['ranks']==ranks)
    content=(G/row['file']).read_bytes()
    if hashlib.sha256(content).hexdigest()!=row['sha256']:raise ValueError('REGISTERED_REFERENCE_CHANGED')
    return json.loads(content)


def cold(record,case,rank,candidate):
    if frozenset(record['extension_state_before'])!=BACKEND_NAMES:raise ValueError('REGISTERED_BACKEND_INVENTORY_CHANGED')
    timer=record['first']
    return dict(path=record['path']==case['example'],rank=record['rank']==rank,
                candidate=Path(record['package_root']).samefile(candidate),gc_on=record['gc_on'] is True,
                workload_on=record['workload_enabled'] is True,
                no_required_backend_active=not any(record['extension_state_before'].values()),
                mpi_not_initialized_ahead=record['mpi_initialized_before'] is False,
                threads=record['julia_threads']==record['blas_threads']==record['fftw_threads']==1,
                MPI_library='Open MPI' in record['mpi_library'] and '5.0.9' in record['mpi_library'],
                Julia=record['julia_version']=='1.11.2',
                compile_time=0<=timer['compile_time']<=.5,
                recompile_subset=0<=timer['recompile_time']<=timer['compile_time'])


def qualify(case,directory,ranks,candidate,release_tree):
    directory=Path(directory);ref=reference(case,ranks);records=[json.loads((directory/f'rank_{rank}.json').read_text()) for rank in range(ranks)]
    spectral_source=spectral_source_digest(candidate)
    data=outputs(case,records[0],directory,release_tree=release_tree,spectral_source=spectral_source)
    checks=dict(native_science_exact=data==ref['native_science'],expected_nonzero=any(v['nonzero_scientific_values'] for v in data.values() if 'native_float_bits' in v),
                labels_exact=all(x['task_labels']==ref['task_labels'] for x in records),
                rank_output_inventory=rank_output_inventory(records,directory)==ref['rank_output_inventory'])
    if ranks==1:
        repeat=dict(records[0],first_outputs=records[0]['repeat_outputs'])
        checks['write_read_repeat_exact']=outputs(case,repeat,directory,release_tree=release_tree,spectral_source=spectral_source,stage='repeat')==data
    per_rank=[dict(rank=rank,checks=cold(record,case,rank,candidate),compile_time=record['first']['compile_time'],recompile_time=record['first']['recompile_time']) for rank,record in enumerate(records)]
    return dict(id=case['id'],ranks=ranks,scientific_checks=checks,rank_observations=per_rank,
                max_rank_compile_time=max(x['compile_time'] for x in per_rank),max_rank_recompile_subset=max(x['recompile_time'] for x in per_rank),
                global_first_task_span_seconds=(max(x['first_end_ns'] for x in records)-min(x['first_start_ns'] for x in records))/1e9,
                passed=all(checks.values()) and all(all(x['checks'].values()) for x in per_rank))
