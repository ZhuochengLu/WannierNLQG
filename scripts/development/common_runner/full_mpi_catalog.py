#!/usr/bin/env python3
"""Build the explicit Full MPI argv catalogue; no scientific job or global preference edit."""
import argparse,json,sys
from pathlib import Path
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE if (HERE/'runner.py').exists() else HERE/'core'))
import runner,mpi_ownership
p=argparse.ArgumentParser();p.add_argument('--package',required=True);p.add_argument('--base-argv-json',required=True,help='exact Base.julia_cmd().exec from the actual MPI-only parent launch flags');p.add_argument('--tmp-root',required=True,help='owned scheduler MPI-only TMPDIR root');p.add_argument('--output',required=True);p.add_argument('--launcher',default='/opt/homebrew/bin/mpiexec');p.add_argument('--runtime',default='/opt/homebrew/opt/prrte/bin/prterun');a=p.parse_args()
package=Path(a.package).resolve();base=runner.read(Path(a.base_argv_json).resolve());base[0]=str(Path(base[0]).resolve());tmp=str(Path(a.tmp_root).resolve());apps=[]
def app(script,flags,tails,ranks):
 path=package/script
 if not path.is_file():raise ValueError('missing literal Full MPI source: '+str(path))
 apps.append(dict(argv=base+flags+[str(path),*tails],ranks=ranks))
flags=['--startup-file=no','--threads=1','--project='+str(package)];compiled=['--compiled-modules=no',*flags];variable={'path_under':tmp}
app('scripts/check_mpi_smoke.jl',flags,[],[2]);app('scripts/check_response_symmetry_mpi.jl',flags,['2'],[2])
for backend in ('Direct','Mixed'):
 app('test/SpectralResponseDeterminismProbe.jl',flags,[variable,variable,backend],[1,2])
 app('test/ThirdOrderDeterminismProbe.jl',flags,[variable,backend],[1,2])
app('test/MDRSRuntimeMpiProbe.jl',compiled,[variable],[2]);app('test/WannierizationRawZMpiProbe.jl',compiled,[],[1,2,4,8,16]);app('test/WannierizationULocalizationMpiProbe.jl',compiled,[],[1,2,4,8,16]);app('test/WannierizationWorkflowMpiProbe.jl',compiled,[variable],[2]);app('test/support/per_task_parallel_runner.jl',compiled,[variable],[1,2]);app('test/support/kpath_band_parallel_runner.jl',compiled,[variable],[1,2])
launcher=str(Path(a.launcher).resolve());runtime=str(Path(a.runtime).resolve());libs={str(next(Path('/opt/homebrew/lib').glob(n+'.dylib')).resolve()) for n in ('libmpi','libprrte','libpmix')};libs|=mpi_ownership.runtime_closure([launcher,runtime,*libs]);pol=dict(kind='local_openmpi/1',launcher=dict(path=launcher,sha256=runner.digest(launcher)),runtime=dict(path=runtime,sha256=runner.digest(runtime)),runtime_inputs={f:runner.digest(f) for f in libs},applications=apps)
out=Path(a.output).resolve()
if out.exists():raise ValueError('use a fresh output path')
runner.atomic(out,pol);print(json.dumps(dict(path=str(out),applications=len(apps),rank_counts=[1,2,4,8,16],scope='strict frozen literal Full closure; rederive after source/parent Julia flags change')))
