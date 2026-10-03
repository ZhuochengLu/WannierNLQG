#!/usr/bin/env python3
"""Qualify the original localization8 serial/MPI/thread and checkpoint contract."""
import argparse
import json
from pathlib import Path
import shutil
import sys
sys.dont_write_bytecode = True
import guarded_process
from expert_campaign import environment, quiet
from fixture_bundle import verify
from qualify_expert_scene import cold_checks
from release_inventory import verify_release

ROOT = Path(__file__).resolve().parents[2]
MATRIX = (('serial',1,1), ('mpi',1,1), ('mpi',2,1), ('mpi',12,1),
          ('threads',1,2), ('threads',1,4))
RETURN_METADATA = frozenset(('result.restart_state.elapsed_seconds','result.peak_memory_bytes'))
CHECKPOINT_METADATA = frozenset((
    '/environment/@attribute/generated_at_utc', '/environment/@attribute/threads',
    '/restart_state/@attribute/elapsed_seconds', '/input_summary/@attribute/parallel',
    '/input_summary/@attribute/u_localization_mpi_size',
    '/input_summary/@attribute/u_localization_parallel_contract',
    '/input_summary/@attribute/restart_config_sha256', '/@attribute/config_sha256',
    '/restart_state/@attribute/config_sha256', '/@attribute/checkpoint_sha256',
))


def scientific_fields(summary, exclusions):
    if len(exclusions)!=len(RETURN_METADATA) or frozenset(exclusions)!=RETURN_METADATA:
        raise ValueError('LOCALIZATION_UNDECLARED_RETURN_EXCLUSION')
    leaves = summary['leaves']
    if len({x['path'] for x in leaves}) != len(leaves):
        raise ValueError('LOCALIZATION_DUPLICATE_RETURN_FIELD')
    return {x['path']:x for x in leaves if x['path'] not in exclusions}


def checkpoint_fields(inventory, contract):
    exclusions = contract['excluded_checkpoint_fields']
    if len(exclusions)!=len(CHECKPOINT_METADATA) or frozenset(exclusions)!=CHECKPOINT_METADATA:
        raise ValueError('LOCALIZATION_UNDECLARED_CHECKPOINT_EXCLUSION')
    fields = inventory['fields']
    if len({x['path'] for x in fields}) != len(fields):
        raise ValueError('LOCALIZATION_DUPLICATE_CHECKPOINT_FIELD')
    if inventory.get('official_integrity_reader_verified') is not True:
        raise ValueError('LOCALIZATION_OFFICIAL_READER_REQUIRED')
    return {x['path']:x for x in fields if x['path'] not in contract['excluded_checkpoint_fields']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate',type=Path,required=True)
    parser.add_argument('--depot',type=Path,required=True)
    parser.add_argument('--readonly-depot',type=Path,action='append',default=[])
    parser.add_argument('--evidence',type=Path,required=True)
    parser.add_argument('--name',required=True)
    parser.add_argument('--julia',default=shutil.which('julia'))
    parser.add_argument('--launcher',default=shutil.which('mpiexec'))
    args = parser.parse_args()
    candidate = args.candidate.resolve()
    if candidate != ROOT or not args.julia or not args.launcher:
        parser.error('the owning candidate, Julia and real MPI launcher are required')
    if Path(args.name).name != args.name or args.name in ('.','..'):
        parser.error('fresh evidence component required')
    frozen = verify_release(candidate)
    payload = candidate/'test/fixtures/first_use_portable'
    verify(payload)
    contract = json.loads((candidate/'test/fixtures/first_use_science/localization_contract.json').read_text())
    if contract['predeclared_samples'] != 2 or contract['compile_limit_seconds'] != .5:
        raise ValueError('LOCALIZATION_PREDECLARED_CONTRACT_CHANGED')
    scene = next(x for x in json.loads((candidate/'scripts/first_use/expert_paths.json').read_text())
                 if x['id']=='construct_symmetry_adapted_wannier_functions__localization8__mpi12')
    root = args.evidence.resolve()/args.name
    root.mkdir(parents=True,exist_ok=False)
    (root/'predeclared_matrix.json').write_text(json.dumps(dict(matrix=MATRIX,samples=2,frozen=frozen),indent=2)+'\n')
    attempts = []
    for execution,ranks,threads in MATRIX:
        for ordinal in (1,2):
            if verify_release(candidate) != frozen:
                raise ValueError('LOCALIZATION_FROZEN_RELEASE_CHANGED')
            label = f'{execution}_r{ranks}_t{threads}_{ordinal}'
            quiet(root,label)
            directory = root/label
            directory.mkdir()
            env = environment(args.depot.resolve(),args.readonly_depot)
            env['JULIA_NUM_THREADS'] = str(threads)
            cmd = [args.julia,'--startup-file=no','--threads='+str(threads),'--project='+str(candidate),
                   str(candidate/'scripts/first_use/localization_parallel_entry.jl'),execution,
                   str(ranks),str(directory),str(payload)]
            if execution == 'mpi':
                cmd = [args.launcher,'-n',str(ranks),*cmd]
            process = guarded_process.run(cmd,env,directory,180)
            attempt = dict(execution=execution,ranks=ranks,threads=threads,ordinal=ordinal,process=process,
                           rank_observations=[],final_pass=False)
            attempts.append(attempt)
            (root/'attempts.json').write_text(json.dumps(attempts,indent=2)+'\n')
            if process['return_code'] or process['stop_reason']:
                raise RuntimeError('Failed localization attempt retained; no replacement')
            for rank in range(ranks):
                d = directory/f'rank_{rank}'
                receipt = json.loads((d/'receipt.json').read_text())
                initialization = json.loads((d/'initialization.json').read_text())
                checks, compile_seconds = cold_checks(receipt,scene)
                checks.update(actual_rank=initialization['rank']==rank,
                              actual_size=initialization['size']==ranks,
                              actual_threads=initialization['threads']==threads,
                              actual_MPI_library='Open MPI' in initialization['mpi_library'] and '5.0.9' in initialization['mpi_library'],
                              candidate=Path(receipt['package_root']).samefile(candidate),
                              expected_candidate=Path(receipt['expected_package_root']).samefile(candidate))
                first = receipt['first_calls'][0]
                expected = contract['scientific_return_fields']
                checks['return_science_exact'] = scientific_fields(first['return_summary'],contract['excluded_return_fields']) == expected
                restored = json.loads((d/'checkpoint_readback_numeric.json').read_text())
                checks['checkpoint_readback_science_exact'] = scientific_fields(restored,contract['excluded_return_fields']) == expected
                update = json.loads((d/'effective_updates.json').read_text())
                checks['original_nonzero_solver_contract'] = (update['status']=='MAX_ITERATIONS' and update['iterations']==8
                    and update['accepted_nonzero_u_updates']==6 and update['v_finite'] is True and update['v_max_abs']==1.0
                    and update['execution']==execution and update['threads']==threads)
                observation = dict(rank=rank,checks=checks,compile_time=compile_seconds,
                                   recompile_subset=first['recompile_time'])
                attempt['rank_observations'].append(observation)
            attempt['max_rank_compile_time'] = max(x['compile_time'] for x in attempt['rank_observations'])
            (root/'attempts.json').write_text(json.dumps(attempts,indent=2)+'\n')
            print(label,attempt['max_rank_compile_time'],flush=True)
            if not all(all(x['checks'].values()) for x in attempt['rank_observations']):
                raise RuntimeError('Localization cold/science failure retained; later attempts untouched')
    paths = [str(root/f"{x['execution']}_r{x['ranks']}_t{x['threads']}_{x['ordinal']}"/'fixture_output/synthetic.wannierization.h5') for x in attempts]
    (root/'checkpoint_inputs.json').write_text(json.dumps(paths,indent=2)+'\n')
    post = root/'official_checkpoint_inventory'
    post.mkdir()
    cmd = [args.julia,'--startup-file=no','--threads=1','--project='+str(candidate),
           str(candidate/'scripts/first_use/inventory_checkpoint_bits.jl'),str(root/'checkpoint_inputs.json'),str(root/'checkpoint_inventory.json')]
    process = guarded_process.run(cmd,environment(args.depot.resolve(),args.readonly_depot),post,180)
    if process['return_code'] or process['stop_reason']:
        raise RuntimeError('Official checkpoint integrity failure retained')
    native = json.loads((root/'checkpoint_inventory.json').read_text())
    if len(native)!=12 or any(checkpoint_fields(x,contract)!=contract['scientific_checkpoint_fields'] for x in native):
        raise ValueError('LOCALIZATION_NATIVE_CHECKPOINT_BITS_CHANGED')
    if verify_release(candidate)!=frozen:
        raise ValueError('LOCALIZATION_FROZEN_RELEASE_CHANGED_AFTER_RUN')
    (root/'completion.json').write_text(json.dumps(dict(attempts=12,rank_observations=36,
        scientific_return_fields=435,scientific_checkpoint_fields=581,all_cold_samples_qualified=True,
        all_science_and_checkpoint_bits_exact=True,solver_quality_qualified=False,
        native_checkpoint_process=process,final_pass=False,final_release_gates_pending=True),indent=2)+'\n')


if __name__=='__main__':
    main()
