"""Start identities independent of ps. Darwin libproc; Linux /proc start ticks."""
import os, sys, ctypes, errno, time

def identity(pid):
    if sys.platform == 'darwin':
        from darwin_process_resources import lib
        b = ctypes.create_string_buffer(136)
        if lib.proc_pidinfo(pid, 3, 0, b, len(b)) != 136:
            return None
        return {'pid': pid, 'start': [ctypes.c_uint64.from_buffer(b, 120).value,
                                     ctypes.c_uint64.from_buffer(b, 128).value],
                'pgid': ctypes.c_uint32.from_buffer(b, 100).value}
    if sys.platform.startswith('linux'):
        try:
            raw = open(f'/proc/{pid}/stat').read(); f = raw[raw.rindex(')')+2:].split()
            return {'pid': pid, 'start': [open('/proc/sys/kernel/random/boot_id').read().strip(), f[19]], 'pgid': int(f[2])}
        except (OSError, IndexError):
            return None
    raise RuntimeError('Only Darwin and Linux are implemented')

def alive(owner):
    return owner is not None and identity(owner['pid']) == owner


def parent_pid(pid):
    if sys.platform=='darwin':
        from darwin_process_resources import lib
        b=ctypes.create_string_buffer(136)
        if lib.proc_pidinfo(pid,3,0,b,len(b))!=136: return None
        return ctypes.c_uint32.from_buffer(b,16).value
    try:
        raw=open(f'/proc/{pid}/stat').read();return int(raw[raw.rindex(')')+2:].split()[1])
    except (OSError,ValueError,IndexError): return None

def signal_owned(owner, sig):
    # Leader remains unreaped while the waiter supervises it; never signal a stale PGID.
    if not alive(owner) or owner['pgid'] != owner['pid']:
        return False
    try:
        os.killpg(owner['pgid'], sig); return True
    except ProcessLookupError:
        return False


def descendants(owner):
    """Capture identities only while they have a verified ancestry to the owned root."""
    if not alive(owner): return []
    if sys.platform == 'darwin':
        from darwin_process_resources import children
    else:
        from process_resources import rows
        snapshot = rows()
        children = lambda pid: [r['pid'] for r in snapshot if r['ppid']==pid]
    found=[];pending=[owner['pid']];seen=set()
    while pending:
        pid=pending.pop()
        if pid in seen: continue
        seen.add(pid)
        ident=identity(pid)
        if ident: found.append(ident);pending.extend(children(pid))
    return found


def signal_process(owner, sig):
    if not alive(owner): return False
    try: os.kill(owner['pid'],sig);return True
    except ProcessLookupError: return False


class _ProcArgsTransition(Exception):
    """Darwin can return EIO while exec replaces the argument memory map."""


def process_snapshot(owner):
    """Bounded read retry, never an ownership grace period or cached admission.

    KERN_PROCARGS2 can report EIO in either syscall during exec. Retry the
    entire read only for that errno, with start identity checked on each attempt.
    Persistent EIO, every other error, and PID reuse still return no evidence.
    """
    for attempt in range(6):
        try:
            return _process_snapshot_once(owner)
        except _ProcArgsTransition:
            if attempt==5 or not alive(owner): return None
            time.sleep(.001)
    return None


def _process_snapshot_once(owner):
    """Read unambiguous executable/argv/environment only between matching identities."""
    if not alive(owner): return None
    try:
        if sys.platform == 'darwin':
            from darwin_process_resources import lib
            path=ctypes.create_string_buffer(4096)
            if lib.proc_pidpath(owner['pid'],path,len(path)) <= 0: return None
            executable=os.path.realpath(os.fsdecode(path.value))
            libc=ctypes.CDLL(None,use_errno=True)
            mib=(ctypes.c_int*3)(1,49,owner['pid'])  # CTL_KERN, KERN_PROCARGS2
            size=ctypes.c_size_t()
            if libc.sysctl(mib,3,None,ctypes.byref(size),None,0):
                if ctypes.get_errno()==errno.EIO: raise _ProcArgsTransition
                return None
            buf=ctypes.create_string_buffer(size.value)
            if libc.sysctl(mib,3,buf,ctypes.byref(size),None,0):
                if ctypes.get_errno()==errno.EIO: raise _ProcArgsTransition
                return None
            raw=buf.raw[:size.value];argc=int.from_bytes(raw[:4],sys.byteorder)
            if not 0 < argc < 65536: return None
            pos=raw.index(b'\0',4)+1
            while pos < len(raw) and raw[pos]==0: pos+=1
            argv=[]
            for _ in range(argc):
                end=raw.index(b'\0',pos);argv.append(os.fsdecode(raw[pos:end]));pos=end+1
            env={}
            for item in raw[pos:].split(b'\0'):
                if b'=' in item:
                    k,v=item.split(b'=',1);env[os.fsdecode(k)]=os.fsdecode(v)
        elif sys.platform.startswith('linux'):
            from pathlib import Path
            root=Path('/proc',str(owner['pid']))
            executable=os.path.realpath(root/'exe')
            argv=[os.fsdecode(x) for x in (root/'cmdline').read_bytes().split(b'\0') if x]
            env=dict(os.fsdecode(x).split('=',1) for x in (root/'environ').read_bytes().split(b'\0') if b'=' in x)
        else: return None
        session=os.getsid(owner['pid'])
    except (OSError,ValueError,IndexError): return None
    if not alive(owner): return None
    return dict(executable=executable,argv=argv,env=env,session=session)


def owned_rss_kib(owners):
    """Sample each still-identical observed process once, including retained orphans."""
    unique={(x['pid'],str(x['start'])):x for x in owners};total=0
    for x in unique.values():
        if not alive(x): continue
        if sys.platform == 'darwin':
            from darwin_process_resources import resident_bytes
            rss=resident_bytes(x['pid'])//1024
        else:
            from pathlib import Path
            raw=Path('/proc',str(x['pid']),'stat').read_text();f=raw[raw.rindex(')')+2:].split()
            rss=int(f[21])*os.sysconf('SC_PAGE_SIZE')//1024
        if alive(x): total+=rss
    return total
