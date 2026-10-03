#!/usr/bin/env python3
"""Run the declared 68 expert scenes in fresh guarded processes.

All attempts are retained. This runner reports measurements; qualification also
requires frozen science comparisons and the complete release gates.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import time
sys.dont_write_bytecode = True
import guarded_process
from process_resources import science_processes
from fixture_bundle import verify
from qualify_expert_scene import qualify_scene
from release_inventory import verify_release


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def quiet(directory, label):
    started = time.monotonic()
    observations = []
    while active := science_processes():
        observations.append(dict(elapsed_seconds=time.monotonic()-started, processes=active, next_id=label))
        (directory / 'prelaunch_pauses.json').write_text(json.dumps(observations, indent=2) + '\n')
        if time.monotonic() - started >= 900:
            raise RuntimeError('External Julia/MPI job remained active; no child launched')
        time.sleep(5)


def environment(depot, layers):
    env = os.environ.copy()
    for key in list(env):
        if key.startswith('FIRSTUSE_') or key.startswith('WNLQG_TRACE_'):
            env.pop(key)
    env['PYTHONDONTWRITEBYTECODE']='1'
    env.update(JULIA_DEPOT_PATH=os.pathsep.join(map(str,[depot,*layers,Path.home()/'.julia'])),
               JULIA_PKG_PRECOMPILE_AUTO='0', JULIA_NUM_PRECOMPILE_TASKS='1', JULIA_NUM_THREADS='1',
               OPENBLAS_NUM_THREADS='1', OMP_NUM_THREADS='1', MKL_NUM_THREADS='1', VECLIB_MAXIMUM_THREADS='1')
    return env


def command(project, runner, identifier, output, ranks, julia, launcher):
    cmd = [julia, '--startup-file=no', '--threads=1', '--project='+str(project), str(runner), identifier, str(output)]
    if ranks > 1:
        cmd = [launcher, '-n', str(ranks), *cmd]
    return cmd


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--depot', '--candidate-depot', type=Path, required=True)
    parser.add_argument('--readonly-depot', type=Path, action='append', default=[])
    parser.add_argument('--evidence', type=Path, required=True)
    parser.add_argument('--name', required=True)
    parser.add_argument('--cases', help='comma-separated exact scene IDs; default all 68')
    parser.add_argument('--samples', type=int, default=2)
    parser.add_argument('--julia', default=shutil.which('julia'))
    parser.add_argument('--launcher', default=shutil.which('mpiexec'))
    args = parser.parse_args()
    if not args.julia or args.samples != 2:
        parser.error('Julia and the predeclared two samples per scene are required')
    if Path(args.name).name != args.name or args.name in ('.','..'):
        parser.error('name must be one fresh directory component')
    project = args.candidate.resolve()
    if project != Path(__file__).resolve().parents[2]:
        raise ValueError('EXPERT_CONTROLLER_CANDIDATE_COPY_MISMATCH')
    registry = project / 'scripts/first_use/expert_paths.json'
    entries = json.loads(registry.read_text())
    if len(entries) != 68 or len({e['id'] for e in entries}) != 68:
        raise ValueError('EXPERT_REGISTRY_INCOMPLETE')
    verify(project / 'test/fixtures/first_use_portable')
    selected = set(args.cases.split(',')) if args.cases else {e['id'] for e in entries}
    if not selected <= {e['id'] for e in entries}:
        raise ValueError('EXPERT_CASE_UNKNOWN')
    depot = args.depot.resolve()
    if depot == project or project in depot.parents:
        raise ValueError('EXPERT_DEPOT_MUST_BE_OUTSIDE_PACKAGE')
    root = args.evidence.resolve() / args.name
    root.mkdir(parents=True, exist_ok=False)
    runner = project / 'scripts/first_use/expert_entry.jl'
    frozen_release = verify_release(project)
    frozen = {str(p): sha(p) for p in sorted(project.rglob('*')) if p.is_file()}
    native_contracts = json.loads((project/'test/fixtures/first_use_science/native_index.json').read_text())['records']
    (root / 'frozen_release.json').write_text(json.dumps(frozen_release,indent=2)+'\n')
    (root / 'frozen_inputs.json').write_text(json.dumps(frozen, indent=2)+'\n')
    attempts = []
    for scene in entries:
        if scene['id'] not in selected:
            continue
        for ordinal in (1,2):
            if verify_release(project) != frozen_release or any(sha(p) != value for p,value in frozen.items()):
                raise ValueError('EXPERT_FROZEN_INPUT_CHANGED')
            quiet(root,scene['id'])
            destination = root / scene['id'] / str(ordinal)
            destination.mkdir(parents=True, exist_ok=False)
            if scene['mpi_size'] > 1 and not args.launcher:
                raise ValueError('EXPERT_MPI_LAUNCHER_MISSING')
            cmd = command(project,runner,scene['id'],destination,scene['mpi_size'],args.julia,args.launcher)
            res = guarded_process.run(cmd,environment(depot,args.readonly_depot),destination,180)
            attempts.append(dict(id=scene['id'],ordinal=ordinal,ranks_expected=scene['mpi_size'],command=cmd,
                                 registry_sha256=frozen[str(registry)],process=res,final_pass=False))
            (root / 'attempts.json').write_text(json.dumps(attempts,indent=2)+'\n')
            print(scene['id'],ordinal,res,flush=True)
            if res['return_code'] or res['stop_reason']:
                raise RuntimeError('Failed attempt retained; pending scenes untouched')
            integrity = {}
            required = [x for x in native_contracts if x['id'] == scene['id'] and x['contract'].get('official_path_bound_digest_fields')]
            if required:
                post = destination/'native_integrity'
                post.mkdir()
                plan = []
                for record in required:
                    actual = json.loads((destination/record['native_report']).read_text())
                    fields = record['contract']['official_path_bound_digest_fields']
                    plan.append(dict(kind='vasp_spn' if scene['id']=='generate_vasp_paw_spn' else 'star_gauge',
                                     side='actual', file=actual['artifact'], sha256=actual['artifact_sha256'],
                                     digest_fields=[dict(hdf5_field=f[1], report_field=f) for f in fields]))
                (post/'plan.json').write_text(json.dumps(plan,indent=2)+'\n')
                verifier = project/'scripts/first_use/verify_native_integrity.jl'
                cmd_post = [args.julia,'--startup-file=no','--threads=1','--project='+str(project),str(verifier),str(post/'plan.json'),str(post/'qualification.json')]
                verified = guarded_process.run(cmd_post,environment(depot,args.readonly_depot),post,180)
                attempts[-1]['native_integrity_process'] = verified
                (root/'attempts.json').write_text(json.dumps(attempts,indent=2)+'\n')
                if verified['return_code'] or verified['stop_reason']:
                    raise RuntimeError('Official native integrity failure retained')
                integrity = {x['artifact_sha256']:x for x in json.loads((post/'qualification.json').read_text())['rows']}
            qualification = qualify_scene(scene,destination,payload_root=project/'test/fixtures/first_use_portable',integrity_by_sha=integrity)
            (destination/'qualification.json').write_text(json.dumps(qualification,indent=2)+'\n')
            attempts[-1]['qualification'] = qualification
            (root/'attempts.json').write_text(json.dumps(attempts,indent=2)+'\n')
            if not qualification['passed']:
                raise RuntimeError('Failed cold/scientific attempt retained; pending scenes untouched')

    (root / 'completion.json').write_text(json.dumps(dict(attempts=len(attempts),measured_entries=len(selected),
          all68_measurements_complete=len(selected)==68,all_samples_qualified=all(x['qualification']['passed'] for x in attempts),science_qualification_required=False,final_pass=False),indent=2)+'\n')


if __name__ == '__main__':
    main()
