"""Seconds-only test producer. Emits frozen-schema fixtures, never executes Julia/MPI."""
import json,sys,time
from pathlib import Path
plan=json.loads(Path(sys.argv[1]).read_text());destination=Path(sys.argv[2])
for name,value in plan['outputs'].items():
 p=destination/name;p.parent.mkdir(parents=True,exist_ok=True)
 if value['format']=='json':p.write_text(json.dumps(value['value'],indent=2)+'\n')
 elif value['format']=='text':p.write_text(value['value'])
 elif value['format']=='hex':p.write_bytes(bytes.fromhex(value['value']))
 else:raise ValueError('bad fixture format')
time.sleep(.15)
print('FIXTURE_DONE',flush=True)
