#!/usr/bin/env python3
"""Default local Full/MPI/cold/source-audit tooling entrypoint (bundled core)."""
import hashlib
import json
from pathlib import Path
import sys

# The source payload must remain free of generated Python bytecode.
sys.dont_write_bytecode = True
PACKAGE = Path(__file__).resolve().parents[1]


def main(argv=None):
    expected = json.loads((PACKAGE/'scripts/development_runner_identity.json').read_text())
    if expected.get('schema') != 'wanniernlqg.development-runner/1':
        raise ValueError('invalid development runner identity schema')
    # Resolve only the bundled canonical source; never search parents or global tools.
    tool = PACKAGE/'scripts/development/common_runner'
    if not (tool/'integration.py').is_file():
        raise ValueError('bundled development runner missing from this package')
    for name,sha in expected['core_sha256'].items():
        if Path(name).name != name or hashlib.sha256((tool/name).read_bytes()).hexdigest() != sha:
            raise ValueError('development core identity mismatch: '+name)
    # The one implementation is versioned inside this package, separate from Julia Runtime.
    if hashlib.sha256((tool/'integration.py').read_bytes()).hexdigest()!=expected['integration_sha256']:
        raise ValueError('development integration identity mismatch')
    sys.path.insert(0,str(tool))
    import integration
    return integration.main(PACKAGE,Path(__file__).resolve(),argv)


if __name__=='__main__':
    try:raise SystemExit(main())
    except Exception as exc:
        print(json.dumps({'state':'REJECTED','error':str(exc)}),file=sys.stderr)
        raise SystemExit(2)
