"""Contributor test-rank profiles; no execution, recovery or resource controller."""
import copy
import json
from pathlib import Path

PROFILE_ENV = 'WANNIERNLQG_TEST_MPI_PROFILE'
DEFINITIONS = json.loads(Path(__file__).with_suffix('.json').read_text())
if DEFINITIONS.get('schema') != 'wanniernlqg.full-mpi-profiles/1':
    raise ValueError('unsupported contributor rank profile schema')
PROFILES = tuple(DEFINITIONS['profiles'])


def contract(name='legacy16'):
    """Return one explicit scientific test profile and its untested boundaries."""
    if name not in PROFILES:
        raise ValueError('unsupported MPI test profile: ' + str(name))
    value = DEFINITIONS['profiles'][name]
    return copy.deepcopy(dict(mpi_profile=name, mpi_rank_plan=value['rank_plan'],
                              mpi_untested_scope=value['untested_scope']))


def mpi_cpu_slots(name='legacy16'):
    """Count the maximum declared ranks plus the serial test driver."""
    plan = contract(name)['mpi_rank_plan']
    ranks = [plan['other_maximum_ranks']]
    for key in ('checkpoint_definition', 'native_definition', 'wannierization', 'adaptive', 'affine'):
        ranks.extend(plan.get(key, []))
    return max(ranks) + 1
