"""Assemble exact captured-Type and same-source runtime descriptor proofs.

Inputs are explicit artifact paths; this tool does not manufacture observations
or substitute a parsed type for an actual captured MethodInstance Type.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
sys.dont_write_bytecode = True
from source_identity import source_digest


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def artifact(root, value):
    path = Path(value)
    return path if path.is_absolute() else root/path


def assemble_types(candidate, index_path, identifier, projection, failures_path):
    candidate = Path(candidate).resolve(); index_path = Path(index_path).resolve()
    matches = [x for x in json.loads(index_path.read_text()) if x['id'] == identifier]
    if len(matches) != 1:
        raise ValueError('ACTUAL_TYPE_OBSERVATION_NOT_UNIQUE')
    row = matches[0]
    source = source_digest(candidate); manifest = sha(candidate/'Manifest.toml')
    if row['source_src_ext_sha256'] != source or row['manifest_sha256'] != manifest or row['mpi_size'] != 1:
        raise ValueError('ACTUAL_TYPE_SOURCE_OR_SERIAL_SCOPE_CHANGED')
    capture = artifact(index_path.parent,row['actual_types']).resolve()
    inference = artifact(index_path.parent,row['inference']).resolve()
    runner = Path(row['runner_path']).resolve()
    if sha(capture) != row['actual_types_sha256'] or sha(inference) != row['inference_sha256'] or sha(runner) != row['runner_sha256']:
        raise ValueError('ACTUAL_TYPE_ORIGINAL_ARTIFACT_CHANGED')
    identity = json.loads((Path(projection)/'identity.json').read_text())
    file = Path(projection)/'actual_types.jls'
    if identity['original_capture_sha256'] != sha(capture) or identity['original_inference_sha256'] != sha(inference) or identity['reduced_sha256'] != sha(file) or identity['lossless_exact_identity'] is not True:
        raise ValueError('ACTUAL_TYPE_PROJECTION_IDENTITY_CHANGED')
    if identity.get('source_src_ext_sha256') != source or identity.get('manifest_sha256') != manifest or identity.get('reduction_runner_sha256') != sha(candidate/'scripts/first_use/reduce_actual_types.jl'):
        raise ValueError('ACTUAL_TYPE_REDUCTION_RUNNER_OR_SOURCE_CHANGED')
    observation = identifier+'@1:0:inference'
    failures = json.loads(Path(failures_path).read_text())
    required = sorted({x['signature'] for x in failures if x['error'].startswith('TypeError: in Type, in parameter') and 'topology.num_kpts::' in x['signature'] and observation in x['observations']})
    if not required or len(required) != identity['actual_types']:
        raise ValueError('ACTUAL_TYPE_REQUESTED_FAILURE_SCOPE_CHANGED')
    proof = dict(source_src_ext_sha256=source,manifest_sha256=manifest,observation=observation,required_printed_keys=required)
    for key,hash_key,path in [('file','sha256',file),('runner_path','runner_sha256',runner),('trace_index','trace_index_sha256',index_path),
                              ('original_capture_file','original_capture_sha256',capture),('original_inference_file','original_inference_sha256',inference),
                              ('lossless_reduction_runner','lossless_reduction_runner_sha256',candidate/'scripts/first_use/reduce_actual_types.jl'),
                              ('original_parse_failures_file','original_parse_failures_sha256',Path(failures_path).resolve())]:
        proof[key]=str(path.resolve());proof[hash_key]=sha(path)
    return proof


def assemble_threads(candidate, current_path, traced_path):
    current_path,traced_path = Path(current_path).resolve(),Path(traced_path).resolve()
    old=json.loads(current_path.read_text());new=json.loads(traced_path.read_text())
    source=source_digest(candidate)
    if not Path(old['source']).samefile(candidate) or source_digest(new['source']) != source or old['julia'] != new['julia']:
        raise ValueError('RUNTIME_DESCRIPTOR_SOURCE_OR_JULIA_CHANGED')
    by_key={}
    for row in new['rows']:
        by_key.setdefault(row['stable_method_layout_key'],[]).append(row)
    rows=[]
    for row in old['rows']:
        matches=by_key.get(row['stable_method_layout_key'],[])
        rows.append(dict(old_binding=row['binding'],stable_method_layout_key=row['stable_method_layout_key'],new_candidates=[x['binding'] for x in matches],unique=len(matches)==1))
    return dict(old=dict(folder=str(current_path.parent)),new=dict(folder=str(traced_path.parent)),rows=rows,
                source_src_ext_sha256=source,descriptor_sha256=[sha(current_path),sha(traced_path)],julia=old['julia'])


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode',choices=('types','threads'))
    parser.add_argument('--candidate',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--index',type=Path)
    parser.add_argument('--observation')
    parser.add_argument('--projection',type=Path)
    parser.add_argument('--failures',type=Path)
    parser.add_argument('--current-descriptors',type=Path)
    parser.add_argument('--traced-descriptors',type=Path)
    args=parser.parse_args()
    if args.output.exists():
        raise ValueError('PROOF_OUTPUT_MUST_BE_FRESH')
    if args.mode=='types':
        if not all((args.index,args.observation,args.projection,args.failures)):
            parser.error('types requires index, observation ID, projection directory and parse failures')
        result=assemble_types(args.candidate,args.index,args.observation,args.projection,args.failures)
    else:
        if not args.current_descriptors or not args.traced_descriptors:
            parser.error('threads requires both actual descriptor files')
        result=assemble_threads(args.candidate,args.current_descriptors,args.traced_descriptors)
    # Relative metadata survives relocating an entire evidence tree together.
    for key in ('file','runner_path','trace_index','original_capture_file','original_inference_file','lossless_reduction_runner','original_parse_failures_file'):
        if key in result:result[key]=os.path.relpath(result[key],args.output.parent.resolve())
    if args.mode=='threads':
        for side in ('old','new'):result[side]['folder']=os.path.relpath(result[side]['folder'],args.output.parent.resolve())
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print('EXACT_SOURCE_PROOF_ASSEMBLED',args.mode)


if __name__=='__main__':
    main()
