"""Project development entrypoints; scientific contracts stay in adapters.

Loaded only by the package launcher after its pinned core identity is verified.
No installation, service, inherited task environment or implicit science rerun.
"""
import argparse
import csv
import json
import math
import sys
from pathlib import Path
import adapters
import runner


def pin(inputs, path):
    path = str(Path(path).resolve())
    inputs[path] = runner.digest(path)
    return path


def package_inputs(package):
    # Validate exact bytes before admitting a command, not just the manifest hash.
    import importlib.util
    script = package / 'scripts/first_use/release_inventory.py'
    spec = importlib.util.spec_from_file_location('development_inventory', script)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.verify_release(package)
    inputs = {}
    with (package / 'SOURCE_MANIFEST.tsv').open() as handle:
        for row in csv.DictReader(handle, delimiter='\t'):
            inputs[str(package / row['path'])] = row['sha256']
    for path in (package/'SOURCE_MANIFEST.tsv', package/'SHA256SUMS'):
        pin(inputs, path)
    return inputs


def prepare(args, package, launcher):
    root = Path(args.runs_root).resolve()
    if root == package or package in root.parents:
        raise ValueError('run evidence must be outside the package payload')
    inputs = package_inputs(package)
    for path in (sys.executable, __file__, launcher, *args.input):
        pin(inputs, path)
    env = runner.read(Path(args.env_json).resolve())
    if not isinstance(env, dict):
        raise ValueError('env-json must contain the complete explicit environment')
    # Prevent Python child imports from polluting the scientific source inventory.
    if env.get('PYTHONDONTWRITEBYTECODE', '1') != '1':
        raise ValueError('PYTHONDONTWRITEBYTECODE must be 1')
    env['PYTHONDONTWRITEBYTECODE'] = '1'
    pin(inputs, args.env_json)
    destination = root / args.run_id / 'execute'
    if args.kind == 'full':
        if not Path(args.julia).is_absolute():
            raise ValueError('julia executable must be absolute')
        julia=pin(inputs, args.julia)
        if args.jobs < 1 or args.cpu_budget < 17:
            raise ValueError('Full requires jobs>=1 and cpu-budget>=17; no cases dropped')
        argv = [str(Path(sys.executable).resolve()), str(package/'scripts/run_tests.py'), 'full',
                '--owned-group', '--jobs', str(args.jobs), '--cpu-budget', str(args.cpu_budget),
                '--julia', julia, '--output-dir', str(destination/'suite')]
        names = ['fast','interfaces-and-symmetry','wannier-core','scientific-contracts',
                 'thread-determinism','star-gauge-thread','mpi-only']
        outputs = ['suite/summary.json', *[f'suite/{n}/test.log' for n in names]]
        qualification = dict(kind='full',summary='suite/summary.json',logs={n:f'suite/{n}/test.log' for n in names},
            source_root=str(package),source_manifest=str(package/'SOURCE_MANIFEST.tsv'),
            source_manifest_sha256=runner.digest(package/'SOURCE_MANIFEST.tsv'),
            jobs_effective=args.jobs,cpu_budget=args.cpu_budget)
        cwd = str(package)
    else:
        argv = runner.read(Path(args.argv_json).resolve())
        if not isinstance(argv,list) or not argv or not isinstance(argv[0],str) or not Path(argv[0]).is_absolute():
            raise ValueError('argv-json requires an absolute executable and explicit arguments')
        argv[0] = str(Path(argv[0]).resolve())
        pin(inputs, argv[0]);pin(inputs,args.argv_json);pin(inputs,args.outputs_json);pin(inputs,args.qualification_json)
        outputs = runner.read(Path(args.outputs_json).resolve())
        qualification = runner.read(Path(args.qualification_json).resolve())
        kind = args.kind.replace('-', '_')
        if qualification.get('kind') != kind:
            raise ValueError('typed contract must match entrypoint kind')
        source = Path(qualification['source_manifest']).resolve()
        if source != package/'SOURCE_MANIFEST.tsv' or qualification['source_manifest_sha256'] != runner.digest(source):
            raise ValueError('contract must bind this package current source manifest')
        source_root = qualification.get('package_root',qualification.get('source_root'))
        if source_root is None or Path(source_root).resolve() != package:
            raise ValueError('contract package/source root must match this launcher package')
        references = [p['reference'] for p in qualification.get('science_pairs',[])]
        if kind == 'cold': references.append(qualification['reference'])
        if kind == 'source_audit': references.append(qualification['certificate_file'])
        for path in references:
            if not Path(path).is_absolute():raise ValueError('reference must be absolute')
            pin(inputs,path)
        cwd = str(Path(args.cwd).resolve())
    gates = runner.read(Path(args.gates_json).resolve()) if args.gates_json else []
    if args.gates_json:pin(inputs,args.gates_json)
    limits = dict(timeout_seconds=args.timeout,rss_kib=int(args.rss_gib*1024**2),
        sample_seconds=1,cpu_budget=args.cpu_budget,reserve_bytes=int(args.reserve_gib*1024**3),
        disk_floor_bytes=10*1024**3,rss_over_samples=3,host_swapouts_guard=True)
    stage = dict(name='execute',argv=argv,cwd=cwd,env=env,inputs=inputs,outputs=outputs)
    if args.kind=='full':
        stage['controlled_groups']=dict(kind='ci_scheduler_selftest',driver=str(package/'test/run_tests_unit.py'))
    if getattr(args,'mpi_ownership_json',None):
        policy=runner.read(Path(args.mpi_ownership_json).resolve());pin(inputs,args.mpi_ownership_json)
        for entry in (policy['launcher'],policy['runtime']): pin(inputs,entry['path'])
        for path in policy['runtime_inputs']: pin(inputs,path)
        for app in policy['applications']:
            for arg in app['argv']:
                if isinstance(arg,str) and Path(arg).is_absolute() and Path(arg).is_file(): pin(inputs,arg)
        stage['mpi_ownership']=policy
    request = adapters.request(args.kind.replace('-','_'),args.run_id,[stage],limits,
        {'execute':gates},{'execute':qualification},process_contract='foreground_owned_mpi' if stage.get('mpi_ownership') else 'foreground_owned_group')
    runner.validate(request)
    path = Path(args.request_out).resolve()
    if path == package or package in path.parents:raise ValueError('request must be outside package payload')
    # An existing identical request may be reused; never overwrite a different request.
    if path.exists() and runner.read(path) != request:raise ValueError('request-out exists with different content')
    if not path.exists():runner.atomic(path,request)
    return request,root,path


def main(package,launcher,argv=None):
    package=Path(package).resolve();launcher=Path(launcher).resolve()
    parser=argparse.ArgumentParser(description=__doc__)
    sub=parser.add_subparsers(dest='action',required=True)
    for kind in ('full','mpi','cold','source-audit'):
        p=sub.add_parser(kind,help=f'prepare and submit typed {kind} development request')
        p.set_defaults(kind=kind)
        p.add_argument('--run-id',required=True);p.add_argument('--runs-root',required=True)
        p.add_argument('--request-out',required=True);p.add_argument('--env-json',required=True)
        p.add_argument('--mpi-ownership-json',help='explicit pinned local OpenMPI rank-argv catalogue');p.add_argument('--input',action='append',default=[]);p.add_argument('--gates-json')
        p.add_argument('--timeout',type=float,required=True);p.add_argument('--rss-gib',type=float,default=42)
        p.add_argument('--cpu-budget',type=int,required=True);p.add_argument('--reserve-gib',type=float,default=0)
        p.add_argument('--plan-only',action='store_true',help='write validated request without launching')
        if kind=='full':p.add_argument('--julia',required=True);p.add_argument('--jobs',type=int,default=1)
        else:
            for name in ('argv-json','outputs-json','qualification-json','cwd'):p.add_argument('--'+name,required=True)
    p=sub.add_parser('submit');p.add_argument('request');p.add_argument('--root',required=True)
    for action in ('status','reconcile','resume','qualify'):
        p=sub.add_parser(action);p.add_argument('run_directory')
    args=parser.parse_args(argv)
    if args.action in ('full','mpi','cold','source-audit'):
        if not all(math.isfinite(v) for v in (args.timeout,args.rss_gib,args.reserve_gib)):raise ValueError('finite resource limits required')
        request,root,path=prepare(args,package,launcher)
        result=dict(state='PLANNED',request=str(path),run_directory=str(root/args.run_id)) if args.plan_only else runner.submit(request,root)
    elif args.action=='submit':
        request=runner.read(Path(args.request).resolve())
        if request.get('adapter') not in adapters.KINDS or not request.get('qualification'):
            raise ValueError('package submit requires a four-kind typed development request')
        if any(q.get('kind')!=request['adapter'] for q in request['qualification'].values()):
            raise ValueError('typed qualification kind must match request adapter')
        root=Path(args.root).resolve()
        if root==package or package in root.parents:raise ValueError('run evidence must be outside package payload')
        # Raw request submission still must declare the package identity in every stage.
        current=package_inputs(package)
        for stage in request['stages']:
            q=request['qualification'].get(stage['name'])
            if q is None:
                if not request.get('acceptance',{}).get(stage['name']):
                    raise ValueError('non-typed prerequisite stage requires explicit completion gates')
            else:
                source=Path(q['source_manifest']).resolve()
                source_root=q.get('package_root',q.get('source_root'))
                if source!=package/'SOURCE_MANIFEST.tsv' or q['source_manifest_sha256']!=runner.digest(source) or source_root is None or Path(source_root).resolve()!=package:
                    raise ValueError('typed contract must bind current launcher package identity')
                if request['adapter']=='full':
                    budget=request['limits'].get('cpu_budget',0)
                    if budget<17 or q['cpu_budget']!=budget or q['jobs_effective']<1:
                        raise ValueError('Full typed submit requires at least 17 CPU slots')
                    argv=stage['argv']
                    if argv.count('--julia')!=1:raise ValueError('Full requires one pinned Julia executable')
                    julia=argv[argv.index('--julia')+1]
                    if not Path(julia).is_absolute() or julia not in stage['inputs']:
                        raise ValueError('Full Julia executable must be absolute and pinned')
                    expected=[str(Path(sys.executable).resolve()),str(package/'scripts/run_tests.py'),'full',
                        '--owned-group','--jobs',str(q['jobs_effective']),'--cpu-budget',str(budget),
                        '--julia',julia,'--output-dir',str(root/request['run_id']/stage['name']/'suite')]
                    if argv!=expected or Path(stage['cwd']).resolve()!=package:
                        raise ValueError('Full submit must preserve canonical owned-group scheduler command')
            if any(stage['inputs'].get(p)!=sha for p,sha in current.items()):raise ValueError('request lacks current package input closure')
        result=runner.submit(request,root)
    else:
        directory=Path(args.run_directory).resolve()
        if args.action=='qualify':result=adapters.qualify(directory)
        elif args.action=='resume':result=runner.resume(directory)
        else:
            result=runner.reconcile(directory)
            if args.action=='reconcile':runner.atomic(directory/'receipt.json',result)
    print(json.dumps(result,indent=2))
    return 0
