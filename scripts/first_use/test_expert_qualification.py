"""Actual cold timer observations, all MPI ranks, and pipeline rejection cases."""
import copy
import hashlib
import json
from pathlib import Path
import sys
sys.dont_write_bytecode=True
from qualify_expert_scene import cold_checks
ROOT=Path(__file__).resolve().parents[2]
G=ROOT/'test/fixtures/first_use_science'
registry=json.loads((ROOT/'scripts/first_use/expert_paths.json').read_text())
index=json.loads((G/'cold_index.json').read_text())
assert hashlib.sha256((ROOT/'scripts/first_use/expert_paths.json').read_bytes()).hexdigest()==index['predeclared_registry_sha256']
cases=[]
for row in index['records']:
    content=(G/row['file']).read_bytes()
    assert hashlib.sha256(content).hexdigest()==row['sha256']
    receipt=json.loads(content);scene=next(x for x in registry if x['id']==row['id'])
    checks,seconds=cold_checks(receipt,scene)
    assert all(checks.values())
    cases.append((receipt,scene,row['rank'],seconds))
mpi=[x for x in cases if x[1]['mpi_size']==12]
assert len(mpi)==12 and {x[2] for x in mpi}==set(range(12))
negatives=[]
def rejected(label,case,mutate):
    receipt,scene,_,_=copy.deepcopy(case);mutate(receipt)
    try:valid=all(cold_checks(receipt,scene)[0].values())
    except (ValueError,KeyError,TypeError,IndexError):valid=False
    assert valid is False,label
    negatives.append(label)
generic=next(x for x in cases if x[1]['id']=='prepare_band_representation')
rejected('GC_disabled_at_actual_target',generic,lambda r:r['first_calls'][0].__setitem__('gc_on_at_target',False))
rejected('target_backend_active',generic,lambda r:r['first_calls'][0]['extension_state_before'].__setitem__('WannierNLQGSymmetryFoundationExt',True))
rejected('compile_above_limit',generic,lambda r:r['first_calls'][0].__setitem__('compile_time',.500000001))
rejected('recompile_added_to_compile',generic,lambda r:r['first_calls'][0].__setitem__('recompile_time',1.0))
rejected('backend_inventory_missing',generic,lambda r:r['first_calls'][0]['extension_state_before'].pop('WannierNLQGOperatorBundleExt'))
rejected('fixture_assertions_failed',generic,lambda r:r.__setitem__('fixture_passed',False))
rejected('duplicate_target_call',generic,lambda r:r['first_calls'].append(r['first_calls'][0]))
custom=next(x for x in cases if x[1]['id']=='authoritative_band_hamiltonian')
rejected('custom_actual_GC_observation_missing',custom,lambda r:r.__setitem__('gc_checked_at_every_timer',False))
rejected('custom_required_backend_active',custom,lambda r:r['backend_state_at_every_timer'][2].__setitem__('WannierNLQGWannierizationExt',True))
writer=next(x for x in cases if x[1]['id']=='write_band_representation_summary')
rejected('writer_prerequisite_already_active',writer,lambda r:r.__setitem__('validation_before_backend',True))
rejected('writer_validation_not_used',writer,lambda r:r.__setitem__('writer_before_backend',False))
rejected('writer_actual_backend_not_observed',writer,lambda r:r['backend_state_at_every_timer'][2].__setitem__('WannierNLQGSymmetryFoundationExt',False))
rejected('writer_validation_compile_over_limit',writer,lambda r:r['validation'].__setitem__('compile_time',.500000001))
rejected('one_MPI_rank_compile_fails',mpi[-1],lambda r:r['first_calls'][0].__setitem__('compile_time',.500000001))
assert len(cases)==16 and len(negatives)==14
print(json.dumps(dict(actual_cold_records=16,real_MPI_ranks=12,max_rank_compile_time=max(x[3] for x in mpi),negative_cases=negatives,final_pass=False)))
