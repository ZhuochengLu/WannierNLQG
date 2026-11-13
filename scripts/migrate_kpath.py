#!/usr/bin/env python3
"""Explicit continuous kpath1.0 -> branch-aware2.0 conversion, preserving the source."""
import argparse
import hashlib
import json
from pathlib import Path


def migrate(source, destination):
    source, destination = Path(source).resolve(), Path(destination).resolve()
    if destination == source or destination.exists():
        raise ValueError('migration needs a new destination; the original is preserved')
    raw = source.read_bytes()
    value = json.loads(raw)
    if value.get('schema') != 'wanniernlqg.kpath' or value.get('schema_version') != '1.0':
        raise ValueError('only the explicit continuous1.0 source is supported')
    nodes, segments = value['node_chain'], value['segments']
    if len(nodes) < 2 or len(segments) != len(nodes) - 1:
        raise ValueError('invalid original continuous path')
    count = value['total_kpoints']
    if nodes[0]['point_index_one_based'] != 1 or nodes[-1]['point_index_one_based'] != count:
        raise ValueError('original endpoints do not span the table')
    for index, segment in enumerate(segments):
        start, stop = nodes[index]['point_index_one_based'], nodes[index + 1]['point_index_one_based']
        if not start < stop or segment['start_node_index_one_based'] != index + 1 or segment['end_node_index_one_based'] != index + 2 or segment['start_point_index_one_based'] != start or segment['end_point_index_one_based'] != stop or segment['kpoints_including_endpoints'] != stop - start + 1:
            raise ValueError('original segment contract is inconsistent')
    converted = dict(value, schema_version='2.0',
        connected_branches=[dict(start_point_index_one_based=1, end_point_index_one_based=count)],
        path_provenance=dict(path_origin='EXPLICIT_MIGRATION_OF_CONTINUOUS_MANUAL_PATH',
            original_file=str(source), original_sha256=hashlib.sha256(raw).hexdigest(),
            numerical_arrays_units_order_preserved=True))
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open('x') as stream:
        json.dump(converted, stream, ensure_ascii=False, indent=2)
        stream.write('\n')
    return converted


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    migrate(args.input, args.output)
