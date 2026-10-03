#!/usr/bin/env python3
"""Read-only macOS libproc resource queries; no privileged ps or process mutation."""
import ctypes,os,errno,re,subprocess
lib=ctypes.CDLL("/usr/lib/libproc.dylib",use_errno=True)
for name,signature in {
 "proc_pidinfo":[ctypes.c_int,ctypes.c_int,ctypes.c_uint64,ctypes.c_void_p,ctypes.c_int],
 "proc_listchildpids":[ctypes.c_int,ctypes.c_void_p,ctypes.c_int],
 "proc_listallpids":[ctypes.c_void_p,ctypes.c_int],
 "proc_pidpath":[ctypes.c_int,ctypes.c_void_p,ctypes.c_uint32],
}.items():
 fn=getattr(lib,name);fn.argtypes=signature;fn.restype=ctypes.c_int

def children(pid):
 buffer=(ctypes.c_int*8192)();n=lib.proc_listchildpids(pid,buffer,ctypes.sizeof(buffer))
 if n<0:
  error=ctypes.get_errno()
  if error==errno.ESRCH:return []
  raise OSError(error,"proc_listchildpids")
 return [x for x in buffer[:min(n,len(buffer))] if x>0]

def resident_bytes(pid):
 buffer=ctypes.create_string_buffer(4096)
 n=lib.proc_pidinfo(pid,4,0,buffer,len(buffer))
 if n<16:
  error=ctypes.get_errno()
  if error==errno.ESRCH:return 0
  # A disappearing child or exited zombie has no live task RSS.
  try:os.kill(pid,0)
  except ProcessLookupError:return 0
  raise OSError(error,f"cannot query live child task RSS pid={pid}")
 return ctypes.c_uint64.from_buffer(buffer,8).value

def tree_rss_kib(pid):
 pending=[pid];members=set()
 while pending:
  current=pending.pop()
  if current in members:continue
  members.add(current);pending.extend(children(current))
 return sum(resident_bytes(x) for x in members)//1024

def science_processes():
 buffer=(ctypes.c_int*16384)();n=lib.proc_listallpids(buffer,ctypes.sizeof(buffer))
 if n<=0:raise RuntimeError("process inventory unavailable")
 found=[]
 for pid in buffer[:min(n,len(buffer))]:
  path=ctypes.create_string_buffer(4096)
  length=lib.proc_pidpath(pid,path,len(path))
  if length<=0:continue
  executable=path.value.decode(errors="replace")
  if any(x in executable.lower() for x in ("julia","mpiexec","prte","orted","postw90","wannier90","/pw.x")):
   found.append({"pid":pid,"executable":executable})
 return found


def swapout_pages():
 output=subprocess.check_output(["/usr/bin/vm_stat"],text=True)
 match=re.search(r"Swapouts:\s*(\d+)\.",output)
 if not match:raise RuntimeError("vm_stat Swapouts unavailable")
 return int(match.group(1))
