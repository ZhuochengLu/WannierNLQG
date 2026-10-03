"""Deterministic syscall race replay and unchanged CI admission negative cases."""
import sys,os,json,ctypes,errno,copy
from pathlib import Path
from unittest.mock import patch
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
import argparse
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output-dir',required=True);p.add_argument('--package',default=str(HERE.parents[2]));a=p.parse_args()
if sys.platform!='darwin':print('NOT_RUN: Darwin syscall qualification only');raise SystemExit(78)
PACKAGE=Path(a.package).resolve();sys.path.insert(0,str(HERE))
import identity as ident
import runner
out=Path(a.output_dir).resolve()
if out==PACKAGE or PACKAGE in out.parents:raise ValueError('evidence must be outside package')
out.mkdir();results=[]
def check(name,value,detail=None):
    results.append(dict(test=name,passed=bool(value),detail=detail));(out/'results.json').write_text(json.dumps(results,indent=2));assert value,name
owner=ident.identity(os.getpid());real_libc=ctypes.CDLL(None,use_errno=True)
baseline=ident.process_snapshot(owner);check('actual_self_snapshot',bool(baseline))
class FakeLibc:
    def __init__(self,failures,code=errno.EIO):self.calls=0;self.failures=failures;self.code=code
    def sysctl(self,*args):
        self.calls+=1
        if self.calls in self.failures:
            ctypes.set_errno(self.code);return -1
        return real_libc.sysctl(*args)
for n in range(20):
    f=FakeLibc({1} if n%2==0 else {2})
    with patch.object(ident.ctypes,'CDLL',return_value=f):s=ident.process_snapshot(owner)
    check('exec_EIO_replay_'+str(n),s==baseline and f.calls==(3 if n%2==0 else 4),dict(calls=f.calls))
f=FakeLibc(set(range(1,100)))
with patch.object(ident.ctypes,'CDLL',return_value=f):s=ident.process_snapshot(owner)
check('persistent_EIO_bounded_fail_closed',s is None and f.calls==6)
f=FakeLibc({1},errno.EPERM)
with patch.object(ident.ctypes,'CDLL',return_value=f):s=ident.process_snapshot(owner)
check('permission_error_not_retried',s is None and f.calls==1)
f=FakeLibc({1})
with patch.object(ident.ctypes,'CDLL',return_value=f),patch.object(ident,'alive',side_effect=[True,False]):s=ident.process_snapshot(owner)
check('PID_reuse_during_retry_rejected',s is None and f.calls==1)
# Pure deterministic admission: no invented process authority and no signals.
driver=str(PACKAGE/'test/run_tests_unit.py');stage=dict(inputs={driver:runner.digest(driver)},controlled_groups=dict(kind='ci_scheduler_selftest',driver=driver))
root=dict(pid=1,pgid=1,start=[1]);parent=dict(pid=2,pgid=1,start=[2]);leader=dict(pid=3,pgid=3,start=[3]);current=[root,parent,leader]
fake=out/'private/fake-julia';fake.parent.mkdir(mode=0o700);fake.write_bytes(runner.controlled_fake_bytes(stage))
argv={1:['root'],2:[sys.executable,driver],3:[sys.executable,str(fake)]}
def admit(st=stage,arr=argv,cur=current):
    with patch.object(runner,'alive',return_value=True),patch.object(runner,'parent_pid',side_effect=lambda pid:{3:2,2:1}.get(pid)),patch.object(runner,'owned_argv',side_effect=lambda v:arr.get(v['pid'],[])):
        return runner.controlled_group_supported(st,root,leader,cur,{})
check('exact_fake_admitted',admit()[0])
a=copy.deepcopy(argv);a[2]=[sys.executable,'unowned-driver.py'];check('wrong_driver_rejected',not admit(arr=a)[0])
original=fake.read_bytes();fake.write_bytes(original+b'\n# tamper\n');check('wrong_fake_bytes_rejected',not admit()[0]);fake.write_bytes(original)
check('unowned_parent_rejected',not admit(cur=[root,leader])[0])
a=copy.deepcopy(argv);a[3]=[sys.executable,'arbitrary.py'];check('arbitrary_setsid_rejected',not admit(arr=a)[0])
reused=dict(leader,start=['reused'])
with patch.object(ident,'identity',return_value=reused):check('reused_identity_not_alive',not ident.alive(leader))
# Existing transitional driver argv still has its preexisting .5s limit.
a=copy.deepcopy(argv);a[3]=a[2];logged={(3,str([3])):dict(started=runner.time.monotonic()-1,kinds=[])}
with patch.object(runner,'alive',return_value=True),patch.object(runner,'parent_pid',side_effect=lambda pid:{3:2,2:1}.get(pid)),patch.object(runner,'owned_argv',side_effect=lambda v:a[v['pid']]):
    v=runner.process_groups_supported(stage,root,[leader],current,out,'negative',logged)
check('persistent_transition_rejected',not v)
print(json.dumps(dict(status='PASS',checks=len(results),evidence=str(out))))
