"""Bound one manually dispatched diagnostic; never run the package's Fast/Full/MPI plan."""
from pathlib import Path
import hashlib,json,os,signal,subprocess,sys,time,shutil
ROOT=Path(os.environ['GITHUB_WORKSPACE']).resolve()
BASE='b4036fd4f04c5b7fd02716c5854531c81117391b'
BRANCH='refs/heads/diagnostics/blas-tail-20261116'
PINS={'src/MatrixElements/ConventionCovariantTransport.jl': '68d7910741bb713ffa62f38d1eaa5fb2359e9798201fde15aad711b27c409e34', 'src/MatrixElements/GeometricLoopMatrixElements.jl': '01a5c7740a290703de986b6a44341070e9967358d0bb71d7a5df0fa256b1d338', 'test/shifted_link_columns_unit.jl': '9c5fdd6b04cd3f2714ab3932c0e5886a1f08963c7291036676e9e8b61543e885', 'test/vertex_column_panels_unit.jl': 'b823f5b86ea05f157a8446a6c128d7a93e0d71433780457cbab41bf5499faf8f', 'test/TestCountCompatibilitySupport.jl': '203b8daf585c840ca5cd4bb49bd07a14cf2aca030d3cc3e7b2d0c5eefb56bed6', 'Project.toml': '9d5efb2fc3ffc38a763ce2ae4fe15d9817737dd9cc39a68debf9b9ef0d04cc40', 'Manifest.toml': '4d3f73cefc386e1a92f81348c2874e899a7a24d5653cd4be5c353b75b766406a'}
assert os.environ['GITHUB_REF']==BRANCH and os.environ['GITHUB_EVENT_NAME']=='workflow_dispatch'
assert subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()==os.environ['GITHUB_SHA']
for rel,digest in PINS.items():assert hashlib.sha256((ROOT/rel).read_bytes()).hexdigest()==digest
info={}
for line in Path('/proc/cpuinfo').read_text().splitlines():
 if ':' in line:
  key,value=(x.strip()for x in line.split(':',1))
  if key in ('model name','vendor_id','flags') and key not in info:info[key]=value
mem={line.split(':')[0]:line.split(':',1)[1].strip()for line in Path('/proc/meminfo').read_text().splitlines()if line.split(':')[0]in ('MemTotal','MemAvailable','SwapTotal','SwapFree')}
print('PANEL_DIAGNOSTIC_HOST',json.dumps(dict(cpu=info,memory=mem,logical_cpus=os.cpu_count(),source_base=BASE,diagnostic_commit=os.environ['GITHUB_SHA'],scope='NO_REQUIRED_MAIN_CI_OR_RELEASE_QUALIFICATION',rss_limit_kib=12*1024**2,wall_limit_seconds=900)),flush=True)
if sys.argv[1:]==['--host-only']:raise SystemExit(0)
assert not sys.argv[1:]
assert not subprocess.check_output(['git','diff',BASE,'HEAD','--','src','ext','test','Project.toml','Manifest.toml'])
assert int(mem['MemAvailable'].split()[0])>=4*1024**2
assert shutil.disk_usage(ROOT).free>=11*1024**3
OUT=Path(os.environ['RUNNER_TEMP'])/'blas-panel-diagnostic';assert not OUT.exists();OUT.mkdir()
started=time.monotonic();reports=[]
def identity(pid):
 s=Path(f'/proc/{pid}/stat').read_text();parts=s[s.rfind(')')+2:].split();return dict(pid=pid,ppid=int(parts[1]),pgid=int(parts[2]),session=int(parts[3]),birth=int(parts[19]))
def rss_group(pgid):
 total=0;count=0
 for path in Path('/proc').iterdir():
  if not path.name.isdecimal():continue
  try:
   x=identity(int(path.name))
   if x['pgid']!=pgid:continue
   stat=(path/'status').read_text();v=next((z for z in stat.splitlines()if z.startswith('VmRSS:')),None)
   if v:total+=int(v.split()[1]);count+=1
  except (OSError,ValueError,StopIteration):pass
 return total,count
# Termination is confined to this newly created session with its original birth.
def stop_owned(p,original):
 try:current=identity(p.pid)
 except FileNotFoundError:return
 assert current['birth']==original['birth'] and current['pgid']==current['session']==p.pid
 os.killpg(p.pid,signal.SIGTERM)
 try:p.wait(timeout=10)
 except subprocess.TimeoutExpired:
  current=identity(p.pid);assert current['birth']==original['birth'] and current['pgid']==p.pid
  os.killpg(p.pid,signal.SIGKILL);p.wait(timeout=10)
def profile(label,core=None):
 dest=OUT/label;dest.mkdir();contract=dest/'contract.json';contract.write_text(json.dumps(dict(phase='remote_panel_observation')))
 env=os.environ.copy()
 for key in ('JULIA_NUM_THREADS','OPENBLAS_NUM_THREADS','OMP_NUM_THREADS','MKL_NUM_THREADS','VECLIB_MAXIMUM_THREADS'):env[key]='1'
 env.update(WANNIERNLQG_USE_MPI='0',JULIA_PKG_PRECOMPILE_AUTO='0',JULIA_PKG_OFFLINE='true',WANNIERNLQG_DIAG_PROFILE=label)
 if core is None:env.pop('OPENBLAS_CORETYPE',None)
 else:env['OPENBLAS_CORETYPE']=core
 argv=['julia','--startup-file=no','--compiled-modules=yes','--threads=1','--gcthreads=1','--project='+os.environ['WANNIERNLQG_CI_PROJECT'],str(ROOT/'.github/scripts/blas_panel_diagnostic.jl'),str(ROOT),str(dest),str(contract)]
 peak=0;peak_count=0;reason=None;begin=time.monotonic()
 with (dest/'stdout.log').open('w')as stdout,(dest/'stderr.log').open('w')as stderr:
  p=subprocess.Popen(argv,stdout=stdout,stderr=stderr,env=env,start_new_session=True)
  original=identity(p.pid);assert original['pgid']==original['session']==p.pid
  while p.poll()is None:
   rss,count=rss_group(p.pid);peak=max(peak,rss);peak_count=max(peak_count,count)
   if rss>12*1024**2-256*1024:reason='RSS_LIMIT'
   if time.monotonic()-started>900 or time.monotonic()-begin>450:reason='WALL_LIMIT'
   if shutil.disk_usage(ROOT).free<10*1024**3:reason='DISK_FLOOR'
   if sum(x.stat().st_size for x in (dest/'stdout.log',dest/'stderr.log'))>8*1024**2:reason='LOG_BOUND'
   if reason:stop_owned(p,original);break
   time.sleep(1)
  code=p.wait()
 print('PANEL_PROFILE_PROCESS',json.dumps(dict(profile=label,exit_code=code,stop_reason=reason,seconds=time.monotonic()-begin,sampled_peak_rss_kib=peak,peak_owned_process_count=peak_count,original=original)),flush=True)
 for name in ('stdout.log','stderr.log'):
  text=(dest/name).read_text(errors='replace');print('PANEL_PROFILE_LOG',label,name,flush=True);print(text,flush=True)
 assert reason is None
 result_path=dest/'selection.json'
 if not result_path.exists():result_path=dest/'observations.partial.json'
 d=json.loads(result_path.read_text());assert len(d['observations'])==22
 d['_process']=dict(exit_code=code,complete_report=(result_path.name=='selection.json'),sampled_peak_rss_kib=peak,seconds=time.monotonic()-begin)
 print('PANEL_DIAGNOSTIC_REPORT',json.dumps(d,separators=(',',':')),flush=True)
 reports.append(d)
 return d
first=profile('default')
cores=[x['values']['core'].lower()for x in first['runtime']['openblas']]
flags=set(info.get('flags','').split())
control=('haswell','Haswell') if 'haswell'not in cores and {'avx2','fma'}<=flags else ('sandybridge','Sandybridge') if 'haswell'in cores and 'avx'in flags else None
if control is not None:
 second=profile(*control)
 assert [(x['n'],x['mode'],x['columns'],x['operand_sha256'])for x in first['observations']]==[(x['n'],x['mode'],x['columns'],x['operand_sha256'])for x in second['observations']]
 print('PANEL_CONTROL_ACTUAL_CORES',json.dumps([x['values']['core']for x in second['runtime']['openblas']]),flush=True)
else:print('PANEL_CONTROL_SKIPPED',json.dumps(dict(reason='No supported distinct control kernel for captured CPU flags',actual_cores=cores)),flush=True)
print('PANEL_DIAGNOSIS_COMPLETE',json.dumps(dict(profiles=len(reports),seconds=time.monotonic()-started,new_full_runs=0,new_mpi_runs=0,new_material_runs=0,meaning='Observation completion only, not scientific or required main CI success')),flush=True)

raise SystemExit(1 if any(x['_process']['exit_code']!=0 for x in reports)else 0)
