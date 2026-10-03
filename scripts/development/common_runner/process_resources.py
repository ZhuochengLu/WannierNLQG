"""Resource observations for owned Julia jobs on Darwin or Linux."""
import os
from pathlib import Path
import sys

if sys.platform == 'darwin':
    from darwin_process_resources import science_processes, tree_rss_kib, swapout_pages
elif sys.platform.startswith('linux'):
    def rows():
        result = []
        for path in Path('/proc').iterdir():
            if not path.name.isdigit():
                continue
            try:
                raw = (path / 'stat').read_text()
                close = raw.rindex(')')
                command = raw[raw.index('(')+1:close]
                fields = raw[close+2:].split()
                result.append(dict(pid=int(path.name), ppid=int(fields[1]),
                                   rss_kib=int(fields[21]) * os.sysconf('SC_PAGE_SIZE') // 1024,
                                   command=command))
            except (OSError, ValueError, IndexError):
                continue
        return result

    def tree_rss_kib(pid):
        snapshot = rows()
        if pid not in {r["pid"] for r in snapshot}:
            raise RuntimeError("owned root resource observation missing")
        owned = {pid}
        while True:
            expanded = owned | {r['pid'] for r in snapshot if r['ppid'] in owned}
            if expanded == owned:
                break
            owned = expanded
        return sum(r['rss_kib'] for r in snapshot if r['pid'] in owned)

    def science_processes():
        return [r for r in rows() if r['command'].startswith('julia') or r['command'] in ('mpiexec', 'mpirun')]

    def swapout_pages():
        values = dict(line.split() for line in Path('/proc/vmstat').read_text().splitlines())
        return int(values['pswpout'])
else:
    raise RuntimeError('First-use resource guard requires Darwin or Linux; no job launched')
