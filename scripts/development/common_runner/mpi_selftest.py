#!/usr/bin/env python3
"""Owned, seconds-scale actual OpenMPI tests. Never scientific acceptance."""
import sys,os,json,time,subprocess,copy,signal
from pathlib import Path
sys.dont_write_bytecode=True
BASE=Path(__file__).resolve().parent
import argparse
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--core',default=str(BASE if (BASE/'runner.py').exists() else BASE/'core'));parser.add_argument('--output-dir',required=True);parser.add_argument('--legacy',action='store_true',help='1.1.1 request schema has no development mode')
ARGS=parser.parse_args();CORE=Path(ARGS.core).resolve();LEGACY=ARGS.legacy;ROOT=Path(ARGS.output_dir).resolve()
if sys.platform!='darwin': print('NOT_RUN: local OpenMPI contract is qualified only on Darwin');raise SystemExit(78)
package=next((p for p in CORE.parents if (p/'Project.toml').exists() and (p/'AGENTS.md').exists()),CORE)
if ROOT==package or package in ROOT.parents:raise ValueError('test evidence must be outside package')
sys.path.insert(0,str(CORE))
import runner,mpi_ownership
from identity import identity,alive,signal_process
ROOT.mkdir();RESULTS=[]
EXE=str(Path(sys.executable).resolve());LAUNCHER=str(Path('/opt/homebrew/bin/mpiexec').resolve())
RUNTIME=str(Path('/opt/homebrew/opt/prrte/bin/prterun').resolve())
LIBS={str(next(Path('/opt/homebrew/lib').glob(n+'.dylib')).resolve()) for n in ('libmpi','libprrte','libpmix')};LIBS|=mpi_ownership.runtime_closure([LAUNCHER,RUNTIME,*LIBS])
ENV={'HOME':str(Path.home()),'PATH':'/opt/homebrew/bin:/usr/bin:/bin','TMPDIR':str(ROOT),'OMP_NUM_THREADS':'1','OPENBLAS_NUM_THREADS':'1','PYTHONDONTWRITEBYTECODE':'1'}
LIMITS=dict(cpu_budget=2,rss_kib=3*1024**2,timeout_seconds=10,sample_seconds=.05,rss_over_samples=3,host_swapouts_guard=True,disk_floor_bytes=10*1024**3,reserve_bytes=0)

def check(name,value,detail=None):
 RESULTS.append(dict(name=name,passed=bool(value),detail=detail));runner.atomic(ROOT/'results.json',RESULTS);assert value,(name,detail)

def make(name,body,*,nested=False,timeout=10):
 app=ROOT/(name+'-rank.py');app.write_text('import os,time,sys,json,signal\n'+body+'\n');args=[EXE,'-B',str(app)]
 pins={p:runner.digest(p) for p in [EXE,LAUNCHER,RUNTIME,str(app),*LIBS]}
 policy=dict(kind='local_openmpi/1',launcher=dict(path=LAUNCHER,sha256=pins[LAUNCHER]),runtime=dict(path=RUNTIME,sha256=pins[RUNTIME]),runtime_inputs={p:pins[p] for p in LIBS},applications=[dict(argv=args,ranks=[2])])
 argv=[LAUNCHER,'--bind-to','none','-n','2',*args]
 if nested:
  driver=ROOT/(name+'-driver.py');driver.write_text('import subprocess,sys\nsys.exit(subprocess.run('+repr(argv)+',check=False).returncode)\n');pins[str(driver)]=runner.digest(driver);argv=[EXE,'-B',str(driver)]
 s=dict(schema=runner.SCHEMA,mode='development',process_contract='foreground_owned_mpi',adapter='generic',run_id=name,limits=dict(LIMITS,timeout_seconds=timeout),stages=[dict(name='one',argv=argv,cwd=str(ROOT),env=ENV,inputs=pins,outputs=[],mpi_ownership=policy)])
 if LEGACY: s.pop('mode',None)
 return s

def start(s):
 runner.atomic(ROOT/(s['run_id']+'.request.json'),s);runner.submit(s,ROOT/'runs');return ROOT/'runs'/s['run_id']

def wait(d):
 until=time.monotonic()+15
 while time.monotonic()<until:
  if (d/'receipt.json').exists():break
  time.sleep(.05)
 else:raise RuntimeError('receipt timeout '+str(d))
 r=runner.reconcile(d);runner.atomic(d/'observed.json',r);return r

def proofs(d):
 f=d/'one/controlled_groups_waiter.jsonl';return [json.loads(x) for x in f.read_text().splitlines()] if f.exists() else []

try:
 for nested in (False,True):
  name='nested' if nested else 'direct';s=make(name,'print("RANK="+os.environ["OMPI_COMM_WORLD_RANK"],flush=True);time.sleep(.6)',nested=nested);d=start(s);r=wait(d)
  check(name+'_real_exit_0',r['state']=='EXECUTED' and r['stages'][0]['return_code']==0,r['state']);p=proofs(d);check(name+'_two_rank_groups',{x['rank'] for x in p if x['kind']=='openmpi_local_rank'}=={0,1})
  m=runner.read(d/'one/mpi_terminal.json');check(name+'_cleanup_complete',m['cleanup_status']=='PASS' and not m['remaining_owned'] and all(not x['leader_alive'] and not x['launcher_alive'] for x in m['records']))
  check(name+'_resources_complete',runner.read(d/'one/monitor_terminal.json')['samples']>1)
  before={f.relative_to(d/'one').as_posix():runner.digest(f) for f in (d/'one').rglob('*') if f.is_file()};(d/'receipt.json').rename(d/'retained-original-receipt.json');runner.resume(d);after={f.relative_to(d/'one').as_posix():runner.digest(f) for f in (d/'one').rglob('*') if f.is_file()};check(name+'_receipt_rebuild_no_rerun',before==after and (d/'receipt.json').exists())
 s=make('nonzero','time.sleep(.3);sys.exit(7)',nested=True);r=wait(start(s));check('nested_nonzero_real',r['state']=='RUN_FAILED' and r['stages'][0]['return_code']==7,r['stages'][0].get('return_code'))
 s=make('timeout','time.sleep(3)',nested=True,timeout=.6);d=start(s);r=wait(d);check('timeout_real_and_cleanup',r['state']=='RESOURCE_LIMIT' and r['stages'][0]['return_code']!=0 and runner.read(d/'one/mpi_terminal.json')['cleanup_status']=='PASS',r['state'])
 s=make('signal','time.sleep(.3);os.kill(os.getpid(),signal.SIGTERM)');r=wait(start(s));check('rank_signal_not_pass',r['state']=='RUN_FAILED' and r['stages'][0]['return_code']!=0,r['state'])
 # The rank's arbitrary setsid grandchild retains OMPI env: still must reject.
 s=make('unknown_setsid','pid=os.fork()\nif pid==0:\n os.setsid();time.sleep(2);os._exit(0)\ntime.sleep(2)',nested=True);d=start(s);r=wait(d);check('unknown_setsid_rejected',r['state']=='INFRASTRUCTURE_FAILED' and r['stages'][0]['stop_reason']=='unsupported_process_escape',r['state'])
 s=make('launcher_early_exit','time.sleep(.5)\nif os.environ["OMPI_COMM_WORLD_RANK"]=="0": os.kill(os.getppid(),signal.SIGKILL)\ntime.sleep(2)');d=start(s);r=wait(d);check('launcher_early_exit_not_pass',r['state'] in ('RUN_FAILED','INFRASTRUCTURE_FAILED') and r['stages'][0]['return_code']==-9,r['state']);check('launcher_early_exit_no_residual',runner.read(d/'one/mpi_terminal.json')['cleanup_status']=='PASS')
 # Reject injected loader/runtime selection in initial stage and observed nested launcher.
 s=make('env_stage','time.sleep(.5)');s['stages'][0]['env']=dict(ENV,DYLD_LIBRARY_PATH='/tmp')
 try:runner.validate(s);bad=False
 except ValueError:bad=True
 check('initial_loader_override_rejected',bad)
 s=make('env_nested','time.sleep(.5)',nested=True);driver=Path(s['stages'][0]['argv'][-1]);driver.write_text(driver.read_text().replace('import subprocess,sys','import subprocess,sys,os\nos.environ["PRTE_MCA_rmaps_default_mapping_policy"]="slot"'));s['stages'][0]['inputs'][str(driver)]=runner.digest(driver);r=wait(start(s));check('observed_launcher_override_rejected',r['state']=='INFRASTRUCTURE_FAILED',r['state'])
 s=make('runtime_tamper','time.sleep(.2)');s['stages'][0]['mpi_ownership']['runtime']['sha256']='0'*64
 try:runner.validate(s);bad=False
 except ValueError:bad=True
 check('runtime_pin_tamper_rejected',bad)
 victim=identity(os.getpid());check('pid_reuse_signal_refused',not signal_process(dict(victim,start=['REUSED']),signal.SIGTERM) and alive(victim))
 s=make('foreign_pid','time.sleep(.2)');check('foreign_pid_admission_refused',not mpi_ownership.group_supported(s['stages'][0],victim,victim,[victim],{})[0])
 # Existing relative input cannot evade pinning.
 s=make('relative_script','time.sleep(.2)');app=s['stages'][0]['mpi_ownership']['applications'][0]['argv'][-1];s['stages'][0]['mpi_ownership']['applications'][0]['argv'][-1]=Path(app).name;s['stages'][0]['inputs'].pop(app)
 try:runner.validate(s);bad=False
 except ValueError:bad=True
 check('relative_script_unpinned_rejected',bad)
 # Missing final receipt is rebuilt from original sealed MPI evidence.
 s=make('receipt_crash','time.sleep(.5)',nested=True);d=start(s);(d/'fault_receipt').touch()
 until=time.monotonic()+10
 while not (d/'one/evidence.json').exists() and time.monotonic()<until:time.sleep(.05)
 before={f.relative_to(d/'one').as_posix():runner.digest(f) for f in (d/'one').rglob('*') if f.is_file()};v=runner.resume(d);after={f.relative_to(d/'one').as_posix():runner.digest(f) for f in (d/'one').rglob('*') if f.is_file()};check('mpi_receipt_crash_rebuilt',v['state']=='EXECUTED' and before==after and (d/'receipt.json').exists())
 s=make('controller_resume','time.sleep(.8)',nested=True);two=copy.deepcopy(s['stages'][0]);two['name']='two';s['stages'].append(two);d=start(s)
 until=time.monotonic()+10
 while not (d/'one/owner.json').exists() and time.monotonic()<until:time.sleep(.02)
 signal_process(runner.read(d/'controller.json'),signal.SIGKILL)
 until=time.monotonic()+10
 while not (d/'one/evidence.json').exists() and time.monotonic()<until:time.sleep(.05)
 check('controller_loss_keeps_mpi_waiter',runner.reconcile(d)['stages'][0]['state']=='EXECUTED' and not (d/'two').exists())
 before={f.relative_to(d/'one').as_posix():runner.digest(f) for f in (d/'one').rglob('*') if f.is_file()};runner.resume(d);v=wait(d);after={f.relative_to(d/'one').as_posix():runner.digest(f) for f in (d/'one').rglob('*') if f.is_file()};check('pending_resume_no_success_rerun',v['state']=='EXECUTED' and before==after)
 s=make('monitor_lost','time.sleep(2)',nested=True);d=start(s)
 until=time.monotonic()+5
 while not proofs(d) and time.monotonic()<until:time.sleep(.05)
 signal_process(runner.read(d/'one/monitor.json'),signal.SIGKILL);v=wait(d);check('mpi_monitor_lost_fails_closed',v['state']=='INFRASTRUCTURE_FAILED' and v['stages'][0]['return_code']!=0 and runner.read(d/'one/mpi_terminal.json')['cleanup_status']=='PASS')
 s=make('waiter_lost','time.sleep(2)',nested=True);d=start(s)
 until=time.monotonic()+5
 while not proofs(d) and time.monotonic()<until:time.sleep(.05)
 signal_process(runner.read(d/'one/owner.json')['waiter'],signal.SIGKILL);v=wait(d)
 until=time.monotonic()+5
 while not (d/'one/monitor_terminal.json').exists() and time.monotonic()<until:time.sleep(.05)
 check('mpi_waiter_lost_real_exit_unknown',v['state']=='UNKNOWN' and not (d/'one/exit.json').exists())
 check('mpi_waiter_lost_not_resumed',runner.resume(d)['state']=='UNKNOWN')
 s=make('disk_write_failure','time.sleep(2)',nested=True);d=start(s)
 until=time.monotonic()+5
 while not proofs(d) and time.monotonic()<until:time.sleep(.05)
 (d/'one/fault_write').touch();v=wait(d);check('mpi_simulated_enospc_fails_closed',v['state']=='INFRASTRUCTURE_FAILED' and runner.read(d/'one/mpi_terminal.json')['cleanup_status']=='PASS')
 # Every start identity owned by these runs has departed; never signal a foreign PID.
 live=[]
 for f in (ROOT/'runs').rglob('owner.json'):
  for v in runner.read(f).values():
   if alive(v):live.append(v)
 for f in (ROOT/'runs').rglob('members.json'):
  for v in runner.read(f):
   if alive(v):live.append(v)
 check('all_observed_owned_processes_exited',not live,live)
 print(json.dumps(dict(status='PASS',checks=len(RESULTS),evidence=str(ROOT))))
finally:
 print(str(ROOT))
