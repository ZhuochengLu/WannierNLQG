#!/usr/bin/env python3
"""Measure each declared registered path twice in independent guarded processes."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys
sys.dont_write_bytecode=True
import guarded_process
from expert_campaign import environment,quiet,command
from qualify_registered_scene import qualify
from release_inventory import verify_release


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate',type=Path,required=True)
    parser.add_argument('--depot','--candidate-depot',type=Path,required=True)
    parser.add_argument('--readonly-depot',type=Path,action='append',default=[])
    parser.add_argument('--evidence',type=Path,required=True)
    parser.add_argument('--name',required=True)
    parser.add_argument('--ranks',type=int,choices=(1,12),required=True)
    parser.add_argument('--cases')
    parser.add_argument('--julia',default=shutil.which('julia'))
    parser.add_argument('--launcher',default=shutil.which('mpiexec'))
    args=parser.parse_args();candidate=args.candidate.resolve()
    if candidate!=Path(__file__).resolve().parents[2]:raise ValueError('REGISTERED_CONTROLLER_COPY_MISMATCH')
    if not args.julia or (args.ranks>1 and not args.launcher):parser.error('Julia and real MPI launcher are required')
    if Path(args.name).name!=args.name or args.name in ('.','..'):parser.error('one fresh output component required')
    depot=args.depot.resolve()
    if depot==candidate or candidate in depot.parents:raise ValueError('REGISTERED_DEPOT_INSIDE_PACKAGE')
    frozen=verify_release(candidate)
    registry=candidate/'scripts/first_use/path_registry.json';entries=json.loads(registry.read_text())
    if len(entries)!=52 or len({x['id'] for x in entries})!=52:raise ValueError('REGISTERED_REGISTRY_INCOMPLETE')
    selected=set(args.cases.split(',')) if args.cases else {x['id'] for x in entries}
    if not selected<={x['id'] for x in entries}:raise ValueError('REGISTERED_CASE_UNKNOWN')
    root=args.evidence.resolve()/args.name;root.mkdir(parents=True,exist_ok=False)
    (root/'frozen_inputs.json').write_text(json.dumps(dict(frozen,registry_sha256=hashlib.sha256(registry.read_bytes()).hexdigest(),samples_per_path=2,ranks=args.ranks),indent=2)+'\n')
    attempts=[]
    for case in entries:
        if case['id'] not in selected:continue
        for ordinal in (1,2):
            if verify_release(candidate)!=frozen:raise ValueError('REGISTERED_FROZEN_RELEASE_CHANGED')
            quiet(root,case['id']);destination=root/case['id']/str(ordinal);destination.mkdir(parents=True)
            cmd=command(candidate,candidate/'scripts/first_use/run_case.jl',case['example'],destination,args.ranks,args.julia,args.launcher)
            process=guarded_process.run(cmd,environment(depot,args.readonly_depot),destination,180)
            row=dict(id=case['id'],ordinal=ordinal,ranks=args.ranks,process=process,final_pass=False)
            attempts.append(row);(root/'attempts.json').write_text(json.dumps(attempts,indent=2)+'\n');print(case['id'],ordinal,process,flush=True)
            if process['return_code'] or process['stop_reason']:raise RuntimeError('Failed attempt retained; pending entries untouched')
            result=qualify(case,destination,args.ranks,candidate,frozen['release_tree_sha256'])
            (destination/'qualification.json').write_text(json.dumps(result,indent=2)+'\n');row['qualification']=result;(root/'attempts.json').write_text(json.dumps(attempts,indent=2)+'\n')
            if not result['passed']:raise RuntimeError('Cold or scientific failure retained; no replacement sample')
    (root/'completion.json').write_text(json.dumps(dict(attempts=len(attempts),paths=len(selected),ranks=args.ranks,all52=len(selected)==52,all_samples_qualified=True,final_release_gates_pending=True,final_pass=False),indent=2)+'\n')


if __name__=='__main__':
    main()
