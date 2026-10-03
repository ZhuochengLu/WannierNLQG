"""Start identities independent of ps. Darwin libproc; Linux /proc start ticks."""
import os, sys, ctypes

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
