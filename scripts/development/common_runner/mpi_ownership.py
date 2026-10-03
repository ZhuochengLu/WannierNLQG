"""Explicit local OpenMPI/PRTE process-group admission; never a general setsid allowlist."""
import hashlib, os, time, subprocess, sys
from pathlib import Path
from identity import alive, parent_pid, process_snapshot


def digest(path):
    """Hash a declared executable/runtime input."""
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def validate(stage, cpu_budget):
    """Validate the exact runtime and rank-argv catalogue before any launch."""
    policy=stage['mpi_ownership']
    if set(policy)!={'kind','launcher','runtime','runtime_inputs','applications'} or policy['kind']!='local_openmpi/1':
        raise ValueError('unsupported MPI ownership schema')
    for label in ('launcher','runtime'):
        entry=policy[label]
        if set(entry)!={'path','sha256'}: raise ValueError('MPI executable identity fields')
        path=entry['path']
        if not Path(path).is_absolute() or str(Path(path).resolve())!=path or stage['inputs'].get(path)!=entry['sha256'] or digest(path)!=entry['sha256']:
            raise ValueError('MPI launcher/runtime must be resolved pinned inputs')
    if Path(policy['launcher']['path']).name!='mpirun' or Path(policy['runtime']['path']).name not in ('prterun','prte'):
        raise ValueError('only OpenMPI mpirun with embedded local PRTE prterun is supported')
    libs=policy['runtime_inputs']
    if not isinstance(libs,dict) or not libs or not all(any(name in Path(p).name for p in libs) for name in ('libmpi','libprrte','libpmix')):
        raise ValueError('MPI/libprrte/libpmix runtime closure required')
    for path,sha in libs.items():
        if not Path(path).is_absolute() or str(Path(path).resolve())!=path or stage['inputs'].get(path)!=sha or digest(path)!=sha:
            raise ValueError('MPI runtime closure hash mismatch')
    if sys.platform!='darwin': raise ValueError('local OpenMPI ownership currently qualified on Darwin only')
    closure=runtime_closure([policy['launcher']['path'],policy['runtime']['path'],*libs])
    if any(path not in libs for path in closure): raise ValueError('MPI runtime linked-library closure must be pinned')
    if not isinstance(policy['applications'],list) or not policy['applications']: raise ValueError('MPI rank catalogue required')
    for app in policy['applications']:
        if set(app)!={'argv','ranks'} or not isinstance(app['argv'],list) or not app['argv']: raise ValueError('MPI argv pattern required')
        exe=app['argv'][0]
        if not isinstance(exe,str) or str(Path(exe).resolve())!=exe or exe not in stage['inputs']: raise ValueError('resolved pinned rank executable required')
        if not isinstance(app['ranks'],list) or not app['ranks'] or any(type(n) is not int or n<1 or n>cpu_budget for n in app['ranks']): raise ValueError('MPI rank count exceeds declared CPU budget')
        for arg in app['argv'][1:]:
            if isinstance(arg,str):
                if '\0' in arg: raise ValueError('NUL in MPI argv')
                if (Path(arg) if Path(arg).is_absolute() else Path(stage['cwd'])/arg).is_file() and str((Path(arg) if Path(arg).is_absolute() else Path(stage['cwd'])/arg).resolve()) not in stage['inputs']: raise ValueError('rank argv source/file must be pinned')
            elif not isinstance(arg,dict) or set(arg)!={'path_under'} or not Path(arg['path_under']).is_absolute():
                raise ValueError('MPI variable arguments only allow absolute paths under declared roots')
    # Scheduler allocations / remote and arbitrary runtime command overrides are not this contract.
    if not parameter_defaults_only(policy,stage['env']): raise ValueError('custom MPI parameter files or missing HOME unsupported')
    if not environment_supported(stage['env']): raise ValueError('external MPI allocation/runtime/loader overrides unsupported')


def parameter_defaults_only(policy, env):
    """Reject active user/site MCA parameter overrides; never modify their files."""
    home=Path(env.get('HOME',''))
    if not home.is_absolute(): return False
    launcher=Path(policy['launcher']['path'])
    cellar=next((p for p in launcher.parents if p.name=='Cellar'),None)
    etc=(cellar.parent if cellar else launcher.parent.parent)/'etc'
    paths=[home/('.'+name)/'mca-params.conf' for name in ('openmpi','prte','pmix')]
    paths += [etc/(name+'-mca-params.conf') for name in ('openmpi','prte','pmix')]
    try:
        return all(not p.exists() or not any(line.strip() and not line.lstrip().startswith('#') for line in p.read_text().splitlines()) for p in paths)
    except (OSError,UnicodeError): return False


def runtime_closure(seeds):
    """Resolve the installed Darwin MPI tool/library link closure, excluding Apple cache."""
    pending=list(seeds);seen=set();libraries=set()
    while pending:
        path=str(Path(pending.pop()).resolve())
        if path in seen: continue
        seen.add(path)
        result=subprocess.run(['/usr/bin/otool','-L',path],capture_output=True,text=True)
        if result.returncode: raise ValueError('MPI runtime dependency inspection failed')
        for line in result.stdout.splitlines()[1:]:
            ref=line.strip().split(' (',1)[0]
            if ref==path or ref.startswith(('/usr/lib/','/System/Library/')): continue
            if not Path(ref).is_absolute(): raise ValueError('unresolved MPI runtime install name unsupported: '+ref)
            resolved=str(Path(ref).resolve(strict=True));libraries.add(resolved);pending.append(resolved)
    return libraries


def environment_supported(env, runtime=False):
    """Reject external allocations, runtime selection and loader/prefix overrides."""
    prefixes=('SLURM_','PBS_','LSB_','PMI_','PMIX_MCA_','OMPI_MCA_','PRTE_MCA_','DYLD_','LD_')
    keys={'OPAL_PREFIX','PRTE_PREFIX','PMIX_PREFIX','OMPI_PREFIX','PMIX_SERVER_URI','PMIX_SERVER_URI2','PMIX_SERVER_URI21','PMIX_SERVER_URI3','PMIX_SERVER_URI4','PMIX_NAMESPACE'}
    generated={'PRTE_MCA_schizo_proxy':'ompi','OMPI_MCA_PREFIXES':'mca,opal,ompi,atomic,memheap,scoll,spml,sshmem,bml,coll,fbtl,fcoll,fs,hook,io,mtl,op,osc,part,pml,sharedfp,topo,vprotocol,accelerator,allocator,backtrace,btl,dl,hwloc,if,installdirs,memchecker,memcpy,memory,mpool,patcher,rcache,reachable,shmem,smsc,threads,timer'} if runtime else {}
    return not any((k.startswith(prefixes) or k in keys) and generated.get(k)!=env[k] for k in env)


def argv_matches(pattern, actual):
    """Match exact argv, with only declared absolute path arguments varying."""
    if len(pattern)!=len(actual): return False
    for i,(want,got) in enumerate(zip(pattern,actual)):
        if isinstance(want,str):
            if i==0:
                if not Path(got).is_absolute() or str(Path(got).resolve())!=want: return False
            elif got!=want: return False
        else:
            root=Path(want['path_under']).resolve();path=Path(got)
            if not path.is_absolute(): return False
            path=path.resolve()
            if path!=root and root not in path.parents: return False
    return True


def parse_launch(policy, snapshot):
    """Admit single-program local launch syntax, and bind the entire observed argv."""
    if snapshot is None or not environment_supported(snapshot['env'],runtime=True) or snapshot['executable'] not in (policy['launcher']['path'],policy['runtime']['path']): return None
    args=snapshot['argv'][1:]
    if args[:2]==['--bind-to','none']: args=args[2:]
    if len(args)<3 or args[0] not in ('-n','-np') or not args[1].isdigit(): return None
    count=int(args[1]);rank_argv=args[2:]
    app=next((a for a in policy['applications'] if count in a['ranks'] and argv_matches(a['argv'],rank_argv)),None)
    if app is None: return None
    return dict(ranks=count,rank_argv=rank_argv,launcher_argv=snapshot['argv'],runtime_executable=snapshot['executable'])


def group_supported(stage, root, member, current, states):
    """Prove a same-session direct PRTE rank, or members inside its observed group."""
    policy=stage.get('mpi_ownership')
    if not policy or not alive(member): return (not alive(member)),None
    by_pid={m['pid']:m for m in current if alive(m)}
    leader=by_pid.get(member['pgid'])
    if leader is None or leader['pid']!=leader['pgid'] or member['pid'] not in by_pid: return False,None
    # A previously observed orphan is cleanup evidence, never new admission authority.
    launcher=by_pid.get(parent_pid(leader['pid']))
    if launcher is None: return False,None
    launch_snapshot=process_snapshot(launcher);launch=parse_launch(policy,launch_snapshot)
    if launch is None or launch_snapshot['env'].get('HOME')!=stage['env'].get('HOME') or not parameter_defaults_only(policy,launch_snapshot['env']): return False,None
    snap=process_snapshot(leader)
    if snap is None: return (not alive(leader)),None
    if snap['session']!=root['pid'] or launch_snapshot['session']!=root['pid']: return False,None
    # Prove launcher ancestry all the way to the original still-identical task root.
    ancestry=[];pid=launcher['pid'];seen=set()
    while pid in by_pid and pid not in seen:
        seen.add(pid);ancestry.append(by_pid[pid])
        if pid==root['pid']: break
        pid=parent_pid(pid)
    if not ancestry or ancestry[-1]!=root: return False,None
    key=(leader['pid'],str(leader['start']));state=states.setdefault(key,dict(started=time.monotonic(),bound=None))
    binding=dict(launcher=launcher,rank_argv=launch['rank_argv'],ranks=launch['ranks'])
    if state['bound'] is not None and state['bound']!=binding: return False,None
    state['bound']=binding
    if snap['executable']==launch_snapshot['executable'] and snap['argv']==launch_snapshot['argv']:
        if time.monotonic()-state['started']>.5: return False,None
        kind='openmpi_rank_exec_transition';rank=None
    else:
        if snap['executable']!=str(Path(launch['rank_argv'][0]).resolve()) or snap['argv']!=launch['rank_argv']: return False,None
        env=snap['env'];n=launch['ranks']
        if any(k.startswith(('LD_','DYLD_')) or k in ('OPAL_PREFIX','PRTE_PREFIX','PMIX_PREFIX','OMPI_PREFIX') for k in env): return False,None
        try: rank=int(env['OMPI_COMM_WORLD_RANK'])
        except (KeyError,ValueError): return False,None
        if not 0<=rank<n or any(env.get(k)!=str(n) for k in ('OMPI_COMM_WORLD_SIZE','OMPI_COMM_WORLD_LOCAL_SIZE')) or env.get('OMPI_COMM_WORLD_LOCAL_RANK')!=str(rank): return False,None
        kind='openmpi_local_rank'
    state['leader']=leader;state['rank']=rank;state['kind']=kind
    # Group members must still lead back to this rank; arbitrary new groups reject.
    pid=member['pid'];seen=set()
    while pid!=leader['pid'] and pid in by_pid and pid not in seen:
        seen.add(pid);pid=parent_pid(pid)
    if pid!=leader['pid']: return False,None
    return True,dict(kind=kind,leader=leader,launcher=launcher,rank=rank,ranks=launch['ranks'],rank_argv=launch['rank_argv'],launcher_argv=launch['launcher_argv'],runtime_executable=launch['runtime_executable'],session=snap['session'],ancestry=ancestry)
