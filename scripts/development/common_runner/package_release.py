#!/usr/bin/env python3
"""Create a deterministic local complete source archive; never publish."""
import sys
sys.dont_write_bytecode=True
import argparse
import csv
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import zipfile

PACKAGE=Path(__file__).resolve().parents[3]


def build(output):
    output=Path(output).resolve()
    if PACKAGE==output or PACKAGE in output.parents:raise ValueError('archive output must be outside package')
    if output.exists():raise ValueError('archive output already exists; retain earlier attempt')
    s=importlib.util.spec_from_file_location('inventory',PACKAGE/'scripts/first_use/release_inventory.py')
    m=importlib.util.module_from_spec(s);s.loader.exec_module(m);identity=m.verify_release(PACKAGE)
    version=re.search(r'^version\s*=\s*"([^"]+)"', (PACKAGE/'Project.toml').read_text(),re.M).group(1)
    prefix=f'WannierNLQG-v{version}/'
    with (PACKAGE/'SOURCE_MANIFEST.tsv').open() as handle:rows=list(csv.DictReader(handle,delimiter='\t'))
    manifest_bytes=(PACKAGE/'SOURCE_MANIFEST.tsv').read_bytes()
    sums_bytes=(PACKAGE/'SHA256SUMS').read_bytes()
    contents={}
    for row in rows:
        data=(PACKAGE/row['path']).read_bytes()
        if len(data)!=int(row['bytes']) or hashlib.sha256(data).hexdigest()!=row['sha256']:raise ValueError('source changed during assembly')
        contents[row['path']]=data
    contents.update({'SOURCE_MANIFEST.tsv':manifest_bytes,'SHA256SUMS':sums_bytes})
    output.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(output,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
        for name in sorted(contents):
            info=zipfile.ZipInfo(prefix+name,date_time=(1980,1,1,0,0,0));info.create_system=3
            info.external_attr=(0o100755 if Path(name).suffix=='.sh' else 0o100644)<<16;info.compress_type=zipfile.ZIP_DEFLATED
            archive.writestr(info,contents[name],compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
    # The delivered byte stream and exact inventory are independently inspectable.
    return dict(schema='wanniernlqg.source-archive/1',artifact=str(output),sha256=hashlib.sha256(output.read_bytes()).hexdigest(),
                bytes=output.stat().st_size,archive_members=len(contents),prefix=prefix,payload=identity)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True);a=p.parse_args()
    try:print(json.dumps(build(a.output),indent=2))
    except Exception as exc:print(json.dumps({'state':'REJECTED','error':str(exc)}),file=sys.stderr);raise SystemExit(2)
