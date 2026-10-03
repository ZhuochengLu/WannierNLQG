#!/usr/bin/env python3
"""Recollect all real expert origins, prerequisites and same-source cache hits."""
import argparse
import json
import os
from pathlib import Path
import shutil
import sys
sys.dont_write_bytecode = True
from collect_traces import collect, sha256
from source_identity import source_digest


def interval(directory, raw, before, after, inference_directory, root, rank=None):
    data = raw.read_bytes()
    if not isinstance(before,int) or not isinstance(after,int) or not 0 <= before <= after <= len(data):
        raise ValueError('EXPERT_INVALID_PUBLIC_INTERVAL')
    target = directory / ('public_target_'+inference_directory.name+'.jl' if rank is None else f'public_target_rank_{rank}.jl')
    target.write_bytes(data[before:after])
    inference = inference_directory / 'inference_timings.json'
    actual = inference_directory / 'actual_all_inference_types.jls'
    result = dict(trace=str(target.relative_to(root)),sha256=sha256(target),
                  inference=str(inference.relative_to(root)),inference_sha256=sha256(inference),
                  actual_types=str(actual.relative_to(root)),actual_types_sha256=sha256(actual))
    if rank is not None:
        result['rank'] = rank
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project',type=Path,required=True)
    parser.add_argument('--candidate',type=Path,required=True)
    parser.add_argument('--depot',type=Path,required=True)
    parser.add_argument('--readonly-depot',type=Path,action='append',default=[])
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--cases',help='exact scene IDs for affected local diagnostic checks')
    parser.add_argument('--reuse-main-directory',type=Path,help='explicit original cache seed directory for recovered artifact metadata')
    parser.add_argument('--reuse-main-index',type=Path,help='verified successful partial origins for a new numbered diagnostic controller; requires --cases')
    parser.add_argument('--without-cache-supplements',action='store_true',help='partial diagnostic only; cannot close full source gate')
    args = parser.parse_args()
    project,candidate,root=args.project.resolve(),args.candidate.resolve(),args.output.resolve()
    source=source_digest(project)
    if source != source_digest(candidate):
        raise ValueError('TRACE_COMPUTATION_SOURCE_MISMATCH')
    preference=project/'LocalPreferences.toml'
    if not preference.is_file() or 'precompile_workloads = false' not in preference.read_text():
        raise ValueError('TRACE_WORKLOAD_OFF_PROJECT_REQUIRED')
    entries=json.loads((candidate/'scripts/first_use/expert_paths.json').read_text())
    if len(entries)!=68 or len({x['id'] for x in entries})!=68:
        raise ValueError('EXPERT_REGISTRY_INCOMPLETE')
    chosen=set(args.cases.split(',')) if args.cases else {x['id'] for x in entries}
    if not chosen <= {x['id'] for x in entries}:
        raise ValueError('EXPERT_CASE_UNKNOWN')
    root.mkdir(parents=True,exist_ok=False)
    runner=candidate/'scripts/first_use/expert_entry.jl'
    wrapper=candidate/'scripts/first_use/trace_rank.sh'
    os.environ['FIRSTUSE_READONLY_DEPOTS']=json.dumps([str(p.resolve()) for p in args.readonly_depot])
    index=[];expanded=[]
    main_root=root
    if args.reuse_main_index:
        if not args.cases:
            raise ValueError('REUSE_IS_PARTIAL_DIAGNOSTIC_ONLY')
        original=args.reuse_main_index.resolve()
        main_root=args.reuse_main_directory.resolve() if args.reuse_main_directory else original.parent
        index=json.loads(original.read_text())
        allowed=chosen | ({'validate_band_representation__writer_prerequisite'} if 'write_band_representation_summary' in chosen else set())
        if {x['id'] for x in index}!=allowed or len(index)!=len(allowed):
            raise ValueError('REUSE_MAIN_SCOPE_CHANGED')
        for row in index:
            if row['source_src_ext_sha256']!=source or row['manifest_sha256']!=sha256(project/'Manifest.toml'):
                raise ValueError('REUSE_SOURCE_IDENTITY_CHANGED')
            for key,hkey in [('fixture_path','fixture_sha256'),('runner_path','runner_sha256')]:
                if sha256(row[key])!=row[hkey]:
                    raise ValueError('REUSE_FIXTURE_OR_RUNNER_CHANGED')
            for observation in row.get('rank_traces',[row]):
                for key,hkey in [('trace','sha256'),('inference','inference_sha256'),('actual_types','actual_types_sha256')]:
                    artifact=Path(observation[key]);artifact=artifact if artifact.is_absolute() else main_root/artifact
                    if sha256(artifact)!=observation[hkey]:
                        raise ValueError('REUSE_ORIGINAL_ARTIFACT_CHANGED')
                    observation[key]=str(artifact)
        expanded=[dict(id=x['id'],public_target=x['public_target']) for x in index]
        (root/'reused_main_identity.json').write_text(json.dumps(dict(index_sha256=sha256(original),source=source,original_evidence=str(main_root),samples_recollected=False,partial_diagnostic_only=True),indent=2)+'\n')
    def save():
        (root/'index_partial.json').write_text(json.dumps(index,indent=2)+'\n')
        (root/'expanded_registry.json').write_text(json.dumps(dict(entries=expanded,scope='actual current-source origins only; diagnostic not speed'),indent=2)+'\n')
    for scene in entries:
        if scene['id'] not in chosen or args.reuse_main_index:
            continue
        directory=root/scene['id'];ranks=scene['mpi_size']
        process=collect(project,runner,wrapper,scene['id'],directory,args.depot.resolve(),ranks)
        if process['return_code'] or process['stop_reason'] or len(process['traces'])!=ranks:
            raise RuntimeError('Failed expert origin retained; no replacement')
        observations=[];prerequisite=None
        for rank in range(ranks):
            output=directory/'output'
            if ranks>1:
                output/=f'rank_{rank}'
            receipt=json.loads((output/'receipt.json').read_text());raw=directory/f'trace/rank_{rank}.jl'
            if scene['kind']=='generic':
                if not receipt['fixture_passed'] or len(receipt['first_calls'])!=1:
                    raise ValueError('EXPERT_FIXTURE_FAILED')
                call=receipt['first_calls'][0]
                observations.append(interval(output,raw,call['trace_bytes_before'],call['trace_bytes_after'],output/'first_inference',root,rank if ranks>1 else None))
            elif scene['id']=='authoritative_band_hamiltonian':
                observations.append(interval(output,raw,receipt['trace_bytes_before'],receipt['trace_bytes_after'],output,root))
            elif scene['id']=='read_qe_paw_spn_provenance':
                public=receipt['public_intervals']['first']
                observations.append(interval(output,raw,public['before'],public['after'],output/'first_inference',root))
            else:
                if receipt['validation_before_backend'] or not receipt['writer_before_backend']:
                    raise ValueError('EXPERT_WRITER_PREREQUISITE_CHANGED')
                public=receipt['public_intervals']['writer']
                observations.append(interval(output,raw,public['before'],public['after'],output/'writer_inference',root))
                public=receipt['public_intervals']['validation']
                prerequisite=interval(output,raw,public['before'],public['after'],output/'validation_inference',root)
        fixture=project/'test/fixtures/first_use_portable'/scene['fixture']
        row=dict(id=scene['id'],base_id=scene['id'],public_target=scene['public_target'],source_src_ext_sha256=source,
                 manifest_sha256=sha256(project/'Manifest.toml'),fixture_path=str(fixture),fixture_sha256=sha256(fixture),
                 runner_path=str(runner),runner_sha256=sha256(runner),mpi_size=ranks,trace_scope='first_successful_public_call_byte_interval')
        row.update(observations[0] if ranks==1 else dict(rank_traces=observations))
        index.append(row);expanded.append(dict(scene,fixture_path=str(fixture),fixture_sha256=sha256(fixture)))
        if prerequisite:
            extra=dict(row);extra.update(prerequisite);extra.update(id='validate_band_representation__writer_prerequisite',base_id='validate_band_representation',public_target='validate_band_representation')
            index.append(extra);expanded.append(dict(id=extra['id'],public_target=extra['public_target'],fixture_path=str(fixture),fixture_sha256=sha256(fixture)))
        save();print('expert origins',len(index),scene['id'],flush=True)
    if not args.without_cache_supplements:
        for identifier,base,kind in [('generate_qe_paw_spn__native_cache_hit','generate_qe_paw_spn','spn'),
                                     ('generate_wannier_uiu__native_cache_hit','generate_wannier_uiu','uiu'),
                                     ('generate_qe_paw_spn__native_cache_hit_data_only','generate_qe_paw_spn','spn_data_only')]:
            if base not in chosen:
                raise ValueError('CACHE_MAIN_ORIGIN_REQUIRED; use partial diagnostic flag for a selected scene')
            directory=root/identifier;directory.mkdir()
            seed=main_root/base/'output/native_outputs/.wannier_preparation/qe'
            destination=directory/'output/native_outputs/.wannier_preparation/qe';destination.mkdir(parents=True)
            copied=[]
            for file in sorted(seed.rglob('*')):
                if file.is_file() and (file.name.endswith('.bin') or file.name.endswith('.bin.sha256')):
                    target=destination/file.relative_to(seed);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(file,target)
                    if sha256(file)!=sha256(target):
                        raise ValueError('CACHE_SEED_COPY_CHANGED')
                    copied.append(dict(file=str(target.relative_to(root)),sha256=sha256(target)))
            if not copied:
                raise ValueError('CACHE_SEED_MISSING')
            (directory/'seed_identity.json').write_text(json.dumps(copied,indent=2)+'\n')
            # The small cache wrapper uses the same generic capture protocol.
            os.environ['FIRSTUSE_CACHE_SCENE']=kind
            os.environ['FIRSTUSE_CACHE_BASE_ID']=base
            cache_runner=candidate/'scripts/first_use/expert_cache_entry.jl'
            logs=directory/'process'
            # collect creates its directory and output; cache bytes are already in
            # the declared output. A transport wrapper bridges only that locator.
            os.environ['FIRSTUSE_CACHE_OUTPUT_ROOT']=str(directory/'output')
            process=collect(project,cache_runner,wrapper,identifier,logs,args.depot.resolve(),1)
            if process['return_code'] or process['stop_reason']:
                raise RuntimeError('Failed cache origin retained')
            output=directory/'output';receipt=json.loads((output/'receipt.json').read_text())
            if not receipt['fixture_passed'] or len(receipt['first_calls'])!=1:
                raise ValueError('CACHE_FIXTURE_FAILED')
            call=receipt['first_calls'][0];raw=logs/'trace/rank_0.jl'
            observation=interval(output,raw,call['trace_bytes_before'],call['trace_bytes_after'],output/'first_inference',root)
            actual=json.loads((output/'native_science.json').read_text());reference=json.loads((main_root/base/'output/native_science.json').read_text())
            if actual!=reference:
                raise ValueError('CACHE_SCIENCE_BITS_CHANGED')
            row=dict(id=identifier,base_id=base,public_target=base,source_src_ext_sha256=source,manifest_sha256=sha256(project/'Manifest.toml'),
                     fixture_path=str(candidate/'scripts/first_use/expert_cache_scene.jl'),fixture_sha256=sha256(candidate/'scripts/first_use/expert_cache_scene.jl'),
                     runner_path=str(cache_runner),runner_sha256=sha256(cache_runner),mpi_size=1,trace_scope='first_successful_public_call_byte_interval',**observation)
            index.append(row);expanded.append(dict(id=identifier,public_target=base));save()
            for key in ('FIRSTUSE_CACHE_SCENE','FIRSTUSE_CACHE_BASE_ID','FIRSTUSE_CACHE_OUTPUT_ROOT'):
                os.environ.pop(key,None)
    expected=69 if args.without_cache_supplements else 72
    complete=len(chosen)==68 and len(index)==expected
    (root/'index.json').write_text(json.dumps(index,indent=2)+'\n')
    (root/'completion.json').write_text(json.dumps(dict(launches=len(chosen),observations=len(index),full_main_scope_complete=complete,
          all72_source_scope_complete=complete and not args.without_cache_supplements,performance_qualification=False,final_pass=False),indent=2)+'\n')


if __name__=='__main__':
    main()
