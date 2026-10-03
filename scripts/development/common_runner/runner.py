#!/usr/bin/env python3
"""Local durable argv runner. No science qualification in the execution core."""
import sys
sys.dont_write_bytecode = True  # Detached helpers must not write into the source payload.
import argparse, contextlib, fcntl, hashlib, json, os, re, shutil, signal
import subprocess, sys, time
from pathlib import Path
from identity import identity, alive, signal_owned, descendants, signal_process, parent_pid
import process_resources
import ctypes
import uuid
import math
from resource_policy import Policy
SCHEMA = 'nlqg.local-run/1'
HERE = Path(__file__).resolve().parent


def exited_unreaped(pid):
    """waitid through libc: Python on macOS omits this POSIX API."""
    lib = ctypes.CDLL(None, use_errno=True)
    buf = ctypes.create_string_buffer(128)
    if lib.waitid(1, pid, buf, os.WEXITED | os.WNOHANG | os.WNOWAIT) != 0:
        raise OSError(ctypes.get_errno(), 'waitid')
    return ctypes.c_int.from_buffer(buf, 0).value != 0


def digest(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for b in iter(lambda: f.read(1024*1024), b''): h.update(b)
    return h.hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':')).encode()


def relative_output(name):
    return isinstance(name,str) and not Path(name).is_absolute() and bool(name) and all(p not in ('..','.','') for p in name.split('/'))


def atomic(path, value):
    path = Path(path); tmp = path.with_name(path.name + f'.tmp.{os.getpid()}.{uuid.uuid4().hex}')
    with tmp.open('xb') as f:
        f.write(canonical(value)+b'\n'); f.flush(); os.fsync(f.fileno())
    os.replace(tmp, path)
    fd = os.open(path.parent, os.O_RDONLY)
    try: os.fsync(fd)
    finally: os.close(fd)


def read(path):
    return json.loads(Path(path).read_text())


def append(path, value):
    with Path(path).open('ab', buffering=0) as f:
        data=canonical(dict(time=time.time(), **value))+b'\n'
        if f.write(data)!=len(data): raise OSError('short evidence write')
        os.fsync(f.fileno())


@contextlib.contextmanager
def lock(path):
    with Path(path).open('a') as f:
        fcntl.flock(f, fcntl.LOCK_EX); yield


def tools_identity():
    names=('runner.py','identity.py','process_resources.py','darwin_process_resources.py','adapters.py','resource_policy.py','comparison_contract.py')
    return {**{n:digest(HERE/n) for n in names},'python_executable':digest(sys.executable)}


def validate(spec):
    allowed={'schema','run_id','adapter','limits','stages','acceptance','process_contract','qualification'}
    if set(spec)-allowed: raise ValueError('unsupported request fields: '+str(sorted(set(spec)-allowed)))
    if spec.get('process_contract')!='foreground_owned_group':
        raise ValueError('explicit foreground_owned_group contract required; daemonization/PGID escape unsupported')
    if spec.get('schema') != SCHEMA or not re.fullmatch(r'[A-Za-z0-9_-]{1,80}', spec.get('run_id', '')):
        raise ValueError('invalid schema/run_id')
    if spec.get('adapter') not in ('full', 'mpi', 'cold', 'source_audit', 'generic'):
        raise ValueError('unknown adapter')
    limits = spec['limits']
    allowed_limits={'disk_floor_bytes','rss_kib','timeout_seconds','sample_seconds','cpu_budget','reserve_bytes','rss_over_samples','host_swapouts_guard'}
    if set(limits)-allowed_limits:
        raise ValueError('unsupported resource policy (including host Swapouts / complete containment): '+str(sorted(set(limits)-allowed_limits)))
    if type(limits.get('rss_over_samples',1)) is not int or limits.get('rss_over_samples',1)<1: raise ValueError('rss_over_samples must be positive integer')
    if type(limits.get('host_swapouts_guard',False)) is not bool: raise ValueError('host_swapouts_guard must be boolean')
    for name in ('disk_floor_bytes','rss_kib','timeout_seconds','sample_seconds','cpu_budget','reserve_bytes'):
        if name in limits and (type(limits[name]) not in (int,float) or not math.isfinite(limits[name])):
            raise ValueError('resource limits must be finite numbers')
    if limits.get('cpu_budget',1)<1 or limits.get('reserve_bytes',0)<0: raise ValueError('invalid CPU/reserve budget')
    if limits['disk_floor_bytes'] < 10*1024**3 or limits['timeout_seconds'] <= 0 or limits['rss_kib'] <= 0:
        raise ValueError('invalid limits; disk floor must be >=10 GiB')
    if not .05 <= limits['sample_seconds'] <= 5: raise ValueError('invalid sample interval')
    names = []
    for s in spec['stages']:
        if set(s)-{'name','argv','cwd','env','inputs','outputs'}: raise ValueError('unsupported stage fields')
        names.append(s['name'])
        if not re.fullmatch(r'[A-Za-z0-9_-]{1,80}', s['name']): raise ValueError('bad stage name')
        if not s['argv'] or any(not isinstance(a, str) or '\0' in a for a in s['argv']): raise ValueError('argv must be strings')
        if not Path(s['argv'][0]).is_absolute(): raise ValueError('executable must be absolute')
        if not Path(s['cwd']).is_absolute() or not Path(s['cwd']).is_dir(): raise ValueError('cwd must exist and be absolute')
        if not isinstance(s['env'], dict) or any(not isinstance(k, str) or not isinstance(v, str) for k,v in s['env'].items()): raise ValueError('explicit env required')
        if not s['inputs']: raise ValueError('declare at least executable/source input')
        for p, sha in s['inputs'].items():
            if not Path(p).is_absolute() or digest(p) != sha: raise ValueError('input hash mismatch: '+p)
        if s['argv'][0] not in s['inputs']: raise ValueError('executable must be included in input hashes')
        if any(not relative_output(n) for n in s.get('outputs',[])): raise ValueError('outputs must be safe stage-relative paths')
    for stage_name,gates in spec.get('acceptance',{}).items():
        stage=next((s for s in spec['stages'] if s['name']==stage_name),None)
        if stage is None: raise ValueError('unknown acceptance stage')
        for gate in gates:
            if gate['file'] not in ['stdout.log','stderr.log',*stage.get('outputs',[])]: raise ValueError('acceptance file must be captured output')
    if spec.get('qualification'):
        from adapters import validate_qualification
        validate_qualification(spec)
    if not names or len(set(names)) != len(names): raise ValueError('empty/duplicate stages')


def verify(run):
    m = read(run/'manifest.json')
    if hashlib.sha256(canonical(m['spec'])).hexdigest() != m['spec_sha256']: raise ValueError('manifest identity mismatch')
    if m['tool_sha256'] != tools_identity(): raise ValueError('tool identity changed')
    validate(m['spec']); return m['spec']


def spawn(mode, directory):
    with (directory/(mode+'.log')).open('ab') as log:
        p = subprocess.Popen([sys.executable, str(HERE/'runner.py'), mode, str(directory)],
                             stdin=subprocess.DEVNULL, stdout=log, stderr=log,
                             start_new_session=True, close_fds=True)
    return p


def submit(spec, root):
    validate(spec)
    if spec['limits'].get('host_swapouts_guard'):
        try:
            observation=process_resources.swapout_pages()
            if type(observation) is not int or observation<0: raise ValueError('invalid counter')
        except Exception as exc: raise ValueError('required host Swapouts sensor unavailable; no task admitted: '+str(exc))
    root = Path(root).resolve(); root.mkdir(parents=True, exist_ok=True)
    if shutil.disk_usage(root).free < spec['limits']['disk_floor_bytes']+spec['limits'].get('reserve_bytes',0): raise RuntimeError('disk floor/reserve HOLD')
    run = root/spec['run_id']
    with lock(root/'.submit.lock'):
        if run.exists():
            if verify(run) != spec: raise ValueError('run_id already binds another spec')
            return reconcile(run)
        run.mkdir()
        atomic(run/'manifest.json', {'schema': SCHEMA, 'spec':spec,
               'spec_sha256':hashlib.sha256(canonical(spec)).hexdigest(), 'tool_sha256':tools_identity()})
        append(run/'events.jsonl', {'event':'submitted'})
        # If client dies here, resume launches pending stages under the same lock.
        p = spawn('_controller', run)
        atomic(run/'controller.json', identity(p.pid))
    return {'run_id':spec['run_id'], 'state':'SUBMITTED', 'directory':str(run)}


def terminal(stage, spec):
    exit_path = stage/'exit.json'
    if not exit_path.exists():
        if (stage/'owner.json').exists() and alive(read(stage/'owner.json')['waiter']): return {'state':'RUNNING'}
        if not (stage/'owner.json').exists() and (stage.parent/'controller.json').exists() and alive(read(stage.parent/'controller.json')):
            return {'state':'STARTING'}
        return {'state':'UNKNOWN', 'missing':['actual waiter exit'], 'rerun':'explicit new run_id required'}
    e = read(exit_path)
    if e['run_id'] != read(stage.parent/'manifest.json')['spec']['run_id']: raise ValueError('exit run identity mismatch')
    if e['stage_sha256'] != hashlib.sha256(canonical(spec)).hexdigest(): raise ValueError('stage identity mismatch')
    if e['owner'] != read(stage/'owner.json'): raise ValueError('process identity mismatch')
    if read(stage/'stage.json')['spec'] != spec: raise ValueError('stage config mismatch')
    if read(stage/'stage.json')['limits'] != read(stage.parent/'manifest.json')['spec']['limits']:
        raise ValueError('resource limit identity mismatch')
    seal = stage/'evidence.json'
    if seal.exists():
        sealed=read(seal)
        required={'stage.json','owner.json','exit.json','stdout.log','stderr.log'}
        required|={n for n in ('monitor.json','monitor_terminal.json','resources.jsonl','stop.json','members.json') if (stage/n).exists()}
        if set(sealed)!=required: raise ValueError('evidence seal coverage mismatch')
        for name,sha in sealed.items():
            if digest(stage/name) != sha: raise ValueError('evidence tampered: '+name)
    elif alive(e['owner']['waiter']):
        return {'state':'RUNNING', 'actual_return_code':e['return_code']}
    for name, sha in e['output_sha256'].items():
        if digest(stage/name) != sha: raise ValueError('output hash mismatch: '+name)
    state = 'EXECUTED' if e['return_code'] == 0 else 'RUN_FAILED'
    if e.get('missing_outputs'): state='INFRASTRUCTURE_FAILED'
    if e['stop_reason']:
        state = 'RESOURCE_LIMIT' if e['stop_reason'] in ('timeout','rss','disk_floor','host_swapouts_increased') else 'INFRASTRUCTURE_FAILED'
    if not (stage/'monitor_terminal.json').exists() or not seal.exists():
        state = 'INFRASTRUCTURE_FAILED'
    else:
        m=read(stage/'monitor_terminal.json')
        if m['reason'] and m['reason'] not in ('timeout','rss','disk_floor','host_swapouts_increased'):
            state='INFRASTRUCTURE_FAILED'
        if m['samples']==0: state='INFRASTRUCTURE_FAILED'
        try:
            observations=[json.loads(line) for line in (stage/'resources.jsonl').read_text().splitlines()]
            if len(observations)!=m['samples'] or max((r['rss_kib'] for r in observations),default=0)!=m['sampled_peak_tree_rss_kib']:
                state='INFRASTRUCTURE_FAILED'
            policy=Policy(read(stage/'stage.json')['limits'],m['swapouts_baseline_pages'])
            recorded_reason=None
            for r in observations:
                detected=policy.observe(r['rss_kib'],r['elapsed_seconds'],r['free_disk_bytes'],r['host_swapouts_pages'])
                recorded_reason=recorded_reason or detected
            if recorded_reason and e['stop_reason']!=recorded_reason: state='INFRASTRUCTURE_FAILED'
        except (OSError,ValueError,KeyError): state='INFRASTRUCTURE_FAILED'
    return dict(e, state=state, scientific_status='NOT_EVALUATED',
                missing=['complete resource/recording terminal; rerun only affected stage under a new run_id'] if state=='INFRASTRUCTURE_FAILED' else [])


def reconcile(run):
    run = Path(run).resolve(); spec = verify(run); stages = []
    for s in spec['stages']:
        d = run/s['name']
        stages.append({'name':s['name'], **(terminal(d,s) if d.exists() else {'state':'PENDING'})})
    states = [s['state'] for s in stages]
    state = 'EXECUTED' if all(x=='EXECUTED' for x in states) else next((x for x in states if x not in ('EXECUTED','PENDING')), 'PENDING')
    result = {'schema':SCHEMA, 'run_id':spec['run_id'], 'state':state, 'stages':stages, 'scientific_status':'NOT_EVALUATED'}
    result['resource_scope']='sampled observed descendants only; root wait exit is authoritative'
    result['containment_status']='UNKNOWN'
    result['containment_reason']='no kernel containment; unobserved daemon/reparent escape cannot be excluded'
    result['process_contract']=spec['process_contract']
    result['execution_status']='PASS' if state=='EXECUTED' else state
    result['resource_status']='PASS' if state=='EXECUTED' else state
    result['qualification_scope']='foreground_owned_group contract; no daemonization or PGID escape permitted'
    return result


def resume(run):
    run = Path(run).resolve()
    with lock(run/'.resume.lock'):
        result = reconcile(run)
        if any(s['state'] not in ('PENDING','EXECUTED') for s in result['stages']): return result
        from adapters import stage_gate
        spec=verify(run)
        if any(stage_gate(run,spec,s['name'])['status']=='FAIL' for s in result['stages'] if s['state']=='EXECUTED'):
            return dict(result,adapter_status='FAIL',resume_blocked='completed stage adapter gate failed')
        if all(s['state']=='EXECUTED' for s in result['stages']):
            atomic(run/'receipt.json',result); return result
        spawn('_controller', run)
        return result


def controller(run):
    with lock(run/'.controller.lock'):
        atomic(run/'controller.json',identity(os.getpid()))
        spec = verify(run)
        for s in spec['stages']:
            d = run/s['name']
            if d.exists():
                r = terminal(d,s)
                if r['state']=='EXECUTED':
                    from adapters import stage_gate
                    if stage_gate(run,spec,s['name'])['status']=='FAIL':break
                    continue
                # Never start another waiter for a stage with launch intent, even after crash.
                while r['state'] in ('RUNNING','STARTING'): time.sleep(.1); r=terminal(d,s)
                if r['state']!='EXECUTED': break
                from adapters import stage_gate
                if stage_gate(run,spec,s['name'])['status']=='FAIL':break
                continue
            verify(run)
            d.mkdir(); atomic(d/'stage.json', {'run_id':spec['run_id'],'spec':s, 'limits':spec['limits']})
            append(run/'events.jsonl', {'event':'stage_intent','stage':s['name']})
            p=spawn('_waiter',d); p.wait()
            t=terminal(d,s)
            append(run/'events.jsonl',{'event':'stage_terminal','stage':s['name'],'state':t['state']})
            if t['state']!='EXECUTED': break
            from adapters import stage_gate
            gate=stage_gate(run,spec,s['name'])
            append(run/'events.jsonl',{'event':'adapter_terminal','stage':s['name'],'status':gate['status']})
            if gate['status']=='FAIL': break
        result=reconcile(run)
        if not (run/'fault_receipt').exists(): atomic(run/'receipt.json',result)


def terminate(owner, observed=()):
    # Files are evidence, never authority to signal an arbitrary current process.
    members=descendants(owner)+list(observed)
    for m in reversed(members): signal_process(m,signal.SIGTERM)
    signal_owned(owner, signal.SIGTERM)
    time.sleep(.15)
    for m in reversed(members): signal_process(m,signal.SIGKILL)
    signal_owned(owner, signal.SIGKILL)


def waiter(d):
    record=read(d/'stage.json'); s=record['spec']; limits=record['limits']
    if shutil.disk_usage(d).free < limits['disk_floor_bytes']+limits.get('reserve_bytes',0):
        append(d/'infra.jsonl',{'error':'disk floor/reserve before stage; task NOT_RUN'})
        return
    for name in ('stdout.log','stderr.log'):
        with (d/name).open('xb'): pass
    # fork + pipe launch barrier prevents a fast task escaping identity persistence.
    r,w=os.pipe(); pid=os.fork()
    if pid==0:
        os.close(w); os.setsid()
        if os.read(r,1)!=b'G': os._exit(125)
        os.close(r)
        try:
            os.chdir(s['cwd'])
            out=os.open(d/'stdout.log',os.O_WRONLY|os.O_APPEND)
            err=os.open(d/'stderr.log',os.O_WRONLY|os.O_APPEND)
            os.dup2(out,1);os.dup2(err,2);os.close(out);os.close(err)
            os.execve(s['argv'][0],s['argv'],s['env'])
        except BaseException: os._exit(126)
    os.close(r); monitor=None; released=False; rc=None; reason=None; observed={}
    try:
        task=None
        for _ in range(100):
            task=identity(pid)
            if task and task['pgid']==pid: break
            time.sleep(.005)
        if not task or task['pgid']!=pid: raise RuntimeError('task start identity unavailable')
        owner_record={'task':task,'waiter':identity(os.getpid())}
        atomic(d/'owner.json', owner_record)
        monitor=spawn('_monitor',d)
        atomic(d/'monitor.json',identity(monitor.pid))
        for _ in range(100):
            if (d/'monitor_ready.json').exists(): break
            if monitor.poll() is not None: raise RuntimeError('monitor failed before launch')
            time.sleep(.01)
        else: raise RuntimeError('monitor not ready')
        os.write(w,b'G');os.close(w);released=True
        while True:
            for member in descendants(task): observed[(member['pid'],str(member['start']))]=member
            if any(m['pgid']!=task['pgid'] for m in observed.values() if alive(m)):
                reason='unsupported_process_escape';terminate(task,observed.values())
            # waitid WNOWAIT retains leader identity until owned group cleanup.
            if exited_unreaped(pid): break
            if monitor.poll() is not None:
                reason='monitor_lost'; terminate(task,observed.values())
            if (d/'stop.json').exists(): reason=read(d/'stop.json')['reason']; terminate(task,observed.values())
            time.sleep(.025)
        # Reject leftover background descendants: kill owned group while leader is unreaped.
        if any(m['pid']!=task['pid'] and alive(m) for m in observed.values()):
            reason=reason or 'unsupported_background_descendant'
        signal_owned(task,signal.SIGKILL)
        for member in observed.values(): signal_process(member,signal.SIGKILL)
        _,status=os.waitpid(pid,0)
        rc=os.waitstatus_to_exitcode(status)
        if (d/'stop.json').exists(): reason=read(d/'stop.json')['reason']
        e={'schema':SCHEMA,'run_id':record['run_id'],'stage_sha256':hashlib.sha256(canonical(s)).hexdigest(),
           'owner':owner_record,'return_code':rc,'stop_reason':reason,
           'output_sha256':{n:digest(d/n) for n in ['stdout.log','stderr.log',*s.get('outputs',[])] if (d/n).is_file()},
           'missing_outputs':[n for n in s.get('outputs',[]) if not (d/n).is_file()], 'waited_at':time.time()}
        if (d/'fault_exit_write').exists(): raise OSError(28,'injected exit write failure')
        atomic(d/'exit.json',e)  # actual waiter persists exit before receipt or qualification
    except BaseException as exc:
        if not released:
            os.close(w)
        if 'task' in locals() and task: terminate(task,observed.values())
        try:
            _,status=os.waitpid(pid,0);rc=os.waitstatus_to_exitcode(status)
        except ChildProcessError: pass
        if rc is not None and (d/'owner.json').exists():
            try:
                if (d/'fault_exit_write').exists(): raise OSError(28,'injected exit write failure')
                if (d/'stop.json').exists(): reason=read(d/'stop.json')['reason']
                atomic(d/'exit.json',{'schema':SCHEMA,'run_id':record['run_id'],'stage_sha256':hashlib.sha256(canonical(s)).hexdigest(),
                    'owner':owner_record,'return_code':rc,'stop_reason':reason or 'waiter_recording_failed',
                    'output_sha256':{n:digest(d/n) for n in ('stdout.log','stderr.log')},'waited_at':time.time()})
            except OSError: pass
        try: append(d/'infra.jsonl',{'error':repr(exc),'actual_exit_observed':rc})
        except OSError: pass
        raise
    finally:
        if monitor:
            try: monitor.wait(timeout=3)
            except subprocess.TimeoutExpired:
                terminate(identity(monitor.pid)); monitor.wait()
        if (d/'exit.json').exists():
            names=['stage.json','owner.json','exit.json','stdout.log','stderr.log']
            names += [n for n in ('monitor.json','monitor_terminal.json','resources.jsonl','stop.json','members.json') if (d/n).exists()]
            atomic(d/'evidence.json',{n:digest(d/n) for n in names})


def monitor(d):
    x=read(d/'stage.json'); limits=x['limits']; owner=read(d/'owner.json')
    if owner['waiter']!=identity(os.getppid()) or parent_pid(owner['task']['pid'])!=os.getppid() or not alive(owner['task']):
        raise RuntimeError('monitor launch ownership mismatch; no signals authorized')
    start=time.monotonic(); peak=0; count=0; reason=None; members={}; baseline=None; cleanup_error=None
    try:
        baseline=process_resources.swapout_pages() if limits.get('host_swapouts_guard') else None
        policy=Policy(limits,baseline)
        atomic(d/'monitor_ready.json',{'identity':identity(os.getpid())})
        while True:
            if (d/'exit.json').exists(): break
            if not alive(owner['waiter']): reason='waiter_lost'; break
            if not alive(owner['task']): break
            for m in descendants(owner['task']): members[(m['pid'],str(m['start']))]=m
            atomic(d/'members.json',list(members.values()))
            if any(m['pgid']!=owner['task']['pgid'] for m in members.values() if alive(m)):
                reason='unsupported_process_escape';break
            if (d/'fault_sample').exists(): raise RuntimeError('injected sampler failure')
            if (d/'fault_write').exists(): raise OSError(28,'injected ENOSPC; no real disk fill')
            rss=process_resources.tree_rss_kib(owner['task']['pid'])
            swap=process_resources.swapout_pages() if limits.get('host_swapouts_guard') else None
            if (d/'fault_swapout_sensor').exists(): raise RuntimeError('injected Swapouts sensor unavailable')
            if (d/'fault_swapout_increase').exists() and swap is not None: swap=max(swap,baseline+1)
            elapsed=time.monotonic()-start;free=shutil.disk_usage(d).free
            count+=1;peak=max(peak,rss)
            append(d/'resources.jsonl',{'rss_kib':rss,'elapsed_seconds':elapsed,'free_disk_bytes':free,'host_swapouts_pages':swap,
                   'negative_fault_injected':(d/'fault_swapout_increase').exists()})
            reason=policy.observe(rss,elapsed,free,swap)
            if reason: break
            time.sleep(limits['sample_seconds'])
    except BaseException as exc:
        reason='resource_recording_failed'
        try: append(d/'infra.jsonl',{'error':repr(exc)})
        except OSError: pass
    finally:
        if reason:
            try: atomic(d/'stop.json',{'reason':reason})
            except OSError: pass
            try:terminate(owner['task'],members.values())
            except OSError as exc:
                # The actual parent waiter also consumes stop.json and owns wait/cleanup.
                # Record a rejected/racing monitor signal; never lose the policy terminal.
                cleanup_error=repr(exc)
                try:append(d/'infra.jsonl',{'monitor_cleanup_error':cleanup_error})
                except OSError:pass
        atomic(d/'monitor_terminal.json',{'reason':reason,'samples':count,'sampled_peak_tree_rss_kib':peak,
                                         'swapouts_baseline_pages':baseline,'rss_over_samples':limits.get('rss_over_samples',1),
                                         'cleanup_error':cleanup_error,
                                         'rss_semantics':'sampled tree peak, not OS high-water mark'})


def main():
    p=argparse.ArgumentParser();p.add_argument('action',choices=['submit','status','reconcile','resume','_controller','_waiter','_monitor']);p.add_argument('path');p.add_argument('--root')
    a=p.parse_args();d=Path(a.path).resolve()
    if a.action.startswith('_'): globals()[a.action[1:]](d); return
    if a.action=='submit': result=submit(read(d),a.root or str(HERE/'runs'))
    elif a.action=='resume': result=resume(d)
    else:
        result=reconcile(d)
        if a.action=='reconcile': atomic(d/'receipt.json',result)
    print(json.dumps(result,indent=2))

if __name__=='__main__':
    try: main()
    except Exception as exc: print(json.dumps({'state':'REJECTED','error':str(exc)}),file=sys.stderr);sys.exit(2)
