#!/usr/bin/env python3
"""Generate legitimate portable public-call source supplements without manifest warmup.

The baseline expert probe supplies unchanged timing/inference/science machinery.
Python validates the complete input payload. A literal Julia transport context
avoids compiling JSON3 manifest iteration/pairs or Dict string indexing before
public targets. Native HDF preparation occurs in a separate guarded process.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
sys.dont_write_bytecode = True

SCENES = ('read_projection_representation_search_hdf5',
          'generate_symmetry_completed_qe_paw_matrix_elements',
          'prepare_exact_wannier_operator_bundle')
EXPECTED_PROBE_SHA = '923aafbfd95a337bc286e3f71e309268aaa5d35b798c1e882a2c4020e93d7f1e'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def literal(value):
    # Julia uses $ interpolation even inside double quotes.
    return json.dumps(str(value), ensure_ascii=False).replace('$', '\\$')


def prepare(candidate, destination, tooling):
    from fixture_bundle import rehydrate, checked_path
    from source_identity import source_digest
    candidate, destination = candidate.resolve(), destination.resolve()
    source = candidate/'test/fixtures/first_use_portable'
    destination.mkdir(parents=True, exist_ok=False)
    payload = destination/'payload'
    manifest = rehydrate(source, payload)
    # The actual local absolute locator has 287 UTF-8 bytes, matching HDF5.jl fixed string storage.
    # Fail early for a root that cannot contain this bounded native case.
    prefix = payload/'replay'
    padding = 287-len(os.fsencode(str(prefix/'fixture.save')))-1
    if not 1 <= padding <= 200:
        raise ValueError('REPLAY_ROOT_TOO_LONG_OR_SHORT: choose a local destination whose payload/replay locator allows 1..200 padding bytes')
    replay = prefix/('p'*padding)/'fixture.save'
    assert len(os.fsencode(str(replay))) == 287
    replay.parent.mkdir(parents=True)
    shutil.copytree(payload/'assets/group_5/fixture.save', replay)
    gauge = payload/'assets/group_4/gauge.standard.h5'
    original_probe = candidate/'scripts/first_use/expert_probe.jl'
    if sha(original_probe) != EXPECTED_PROBE_SHA:
        raise ValueError('BASELINE_EXPERT_PROBE_CHANGED: review transport extraction before use')
    text = original_probe.read_text()
    start = text.index('const PORTABLE_ROOT = abspath(ENV["FIRSTUSE_PORTABLE_PAYLOAD_ROOT"])')
    end = text.index('const ROOT = PACKAGE_ROOT', start)
    bootstrap = '''const PORTABLE_ROOT = abspath(ENV["FIRSTUSE_PORTABLE_PAYLOAD_ROOT"])
const TRANSPORT_CONTEXT = abspath(ENV["FIRSTUSE_PREVALIDATED_CONTEXT"])
bytes2hex(sha256(read(TRANSPORT_CONTEXT))) == ENV["FIRSTUSE_PREVALIDATED_CONTEXT_SHA256"] ||
    error("PREVALIDATED_CONTEXT_SHA_MISMATCH")
Base.include(Main, TRANSPORT_CONTEXT)
cd(PORTABLE_ROOT)
'''
    transformed = text[:start]+bootstrap+text[end:]
    transformed = transformed.replace('joinpath(@__DIR__, "NativeInferenceEvidence.jl")',
                                      'joinpath(PACKAGE_ROOT, "scripts", "first_use", "NativeInferenceEvidence.jl")')
    probe = destination/'prevalidated_expert_probe.jl'
    probe.write_text(transformed)
    plan = []
    for name in SCENES:
        entry = next(x for x in manifest['expert_entries'] if x['id'] == name)
        registry = json.loads((candidate/'scripts/first_use/expert_paths.json').read_text())
        declared = next(x for x in registry if x['id'] == name)
        assert declared['kind'] == 'generic' and declared['mpi_size'] == 1 and not declared['supports']
        plan.append(dict(id=name, public_target=declared['public_target'],
                         fixture=str(checked_path(payload,entry['fixture'])),
                         fixture_sha256=sha(checked_path(payload,entry['fixture'])),
                         environment=entry['environment']))
    plan_record = dict(source_src_ext_sha256=source_digest(candidate),candidate=str(candidate),
        original_manifest_sha256=sha(source/'manifest.json'),payload=str(payload),replay=str(replay),
        gauge=str(gauge),gauge_before_sha256=sha(gauge),replay_locator_utf8_bytes=287,
        original_probe=str(original_probe),original_probe_sha256=sha(original_probe),
        generated_probe=str(probe),generated_probe_sha256=sha(probe),scenes=plan,
        speed_samples_per_scene=2,source_only_samples_per_scene=1,
        required_backend_before_target=False,gc_required=True,scientific_knobs_unchanged=True)
    (destination/'predeclaration.json').write_text(json.dumps(plan_record,indent=2)+'\n')
    return plan_record


def context(plan, scene, output):
    payload = Path(plan['payload'])
    manifest = json.loads((payload/'manifest.json').read_text())
    mapping = {}
    for token,item in manifest['paths'].items():
        target = (payload if item['role']=='input' else output/'argument_outputs')/item['relative']
        if item['role']=='output':target.parent.mkdir(parents=True,exist_ok=True)
        mapping[token] = str(target)
    mapping['@FIXTURE_PATH_14@'] = plan['replay']
    # Separate dictionaries preserve standard deserializer reference semantics.
    arguments = {str((payload/item['file']).resolve()): item['id'] for item in manifest['arguments']}
    aliases = {str((payload/'public_band/prepared_representation.jls').resolve()):'fixture_27'}
    arguments.update(aliases)
    text = 'module FirstUsePortableSupport\nusing Serialization\n'
    text += 'include('+literal(payload/'PortableFixturePathIO_v1.jl')+')\n'
    text += 'using .PortableFixturePathIO\n'
    text += 'const ROOT = '+literal(payload)+'\n'
    text += 'const PATHS = Dict{String,String}('+','.join(literal(k)+'=>'+literal(v) for k,v in mapping.items())+')\n'
    text += 'const ARGUMENTS = Dict{String,String}('+','.join(literal(k)+'=>'+literal(v) for k,v in arguments.items())+')\n'
    text += 'input(relative::AbstractString) = joinpath(ROOT, relative)\n'
    text += '''function deserialize_input(path::AbstractString)
    id = get(ARGUMENTS, abspath(path), nothing)
    id === nothing && error("UNDECLARED_ARGUMENT_FILE")
    return open(path, "r") do stream
        Serialization.deserialize(FixturePathIO(stream, PATHS))
    end
end
end
'''
    path=output/'prevalidated_context.jl';path.write_text(text)
    return path


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode',choices=('prepare','seal','trace','cold'))
    parser.add_argument('--candidate',type=Path,required=True)
    parser.add_argument('--destination',type=Path,required=True)
    parser.add_argument('--depot',type=Path)
    parser.add_argument('--readonly-depot',type=Path,action='append',default=[])
    parser.add_argument('--julia',default='julia')
    parser.add_argument('--project',type=Path)
    parser.add_argument('--evidence',type=Path)
    args=parser.parse_args()
    if args.mode=='prepare':
        print(json.dumps(prepare(args.candidate,args.destination,Path(__file__).parent),indent=2));return
    root=args.destination.resolve();plan=json.loads((root/'predeclaration.json').read_text())
    if args.mode=='seal':
        from source_identity import source_digest
        assert source_digest(args.candidate)==plan['source_src_ext_sha256']
        assert (root/'replay_preparation_receipt.txt').read_text().startswith('REPLAY_LOCATOR_BYTES=287')
        payload=Path(plan['payload']);identity=[]
        for file in sorted(payload.rglob('*')):
            if file.is_file():identity.append(dict(file=str(file.relative_to(payload)),sha256=sha(file)))
        manifest=json.loads((payload/'manifest.json').read_text())
        manifest['files']=[dict(file=x['file'],sha256=x['sha256'],bytes=(payload/x['file']).stat().st_size) for x in identity if x['file']!='manifest.json']
        (payload/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
        identity=[dict(file=str(file.relative_to(payload)),sha256=sha(file)) for file in sorted(payload.rglob('*')) if file.is_file()]
        from fixture_bundle import verify
        verify(payload)
        (root/'generated_payload_identity.json').write_text(json.dumps(identity,indent=2)+'\n');print('GENERATED_PAYLOAD_SEALED');return
    from expert_campaign import environment, quiet
    from guarded_process import run
    from source_identity import source_digest
    from qualify_expert_scene import qualify_scene, cold_checks
    from release_inventory import verify_release
    if args.evidence is None or args.depot is None:
        parser.error('trace/cold requires --evidence and --depot')
    candidate=args.candidate.resolve();project=(args.project or candidate).resolve()
    assert source_digest(candidate)==source_digest(project)==plan['source_src_ext_sha256']
    if args.mode=='trace':
        preference=project/'LocalPreferences.toml'
        assert preference.is_file() and 'precompile_workloads = false' in preference.read_text()
    else:
        frozen_release=verify_release(candidate)
    if sha(plan['original_probe']) != plan['original_probe_sha256'] or sha(plan['generated_probe']) != plan['generated_probe_sha256']:
        raise ValueError('PROBE_IDENTITY_CHANGED')
    sealed=json.loads((root/'generated_payload_identity.json').read_text())
    def verify_prepared():
        for x in sealed:
            if sha(Path(plan['payload'])/x['file'])!=x['sha256']:
                raise ValueError('PREPARED_INPUT_CHANGED')
    verify_prepared()
    evidence=args.evidence.resolve();evidence.mkdir(parents=True,exist_ok=False)
    samples=(1,) if args.mode=='trace' else (1,2)
    (evidence/'predeclaration.json').write_text(json.dumps(dict(source_src_ext_sha256=plan['source_src_ext_sha256'],mode=args.mode,scenes=list(SCENES),samples=list(samples),gc_required=True,required_backend_before_target=False,compile_limit_seconds=.5,source_diagnostic_only=args.mode=='trace',final_pass=False),indent=2)+'\n')
    registry=json.loads((candidate/'scripts/first_use/expert_paths.json').read_text())
    index=[];attempts=[]
    for scene in plan['scenes']:
        declaration=next(x for x in registry if x['id']==scene['id'])
        for ordinal in samples:
            verify_prepared()
            if args.mode=='cold':assert verify_release(candidate)==frozen_release
            quiet(evidence,scene['id'])
            d=evidence/scene['id']/str(ordinal);d.mkdir(parents=True)
            ctx=context(plan,scene,d)
            env=environment(args.depot.resolve(),[x.resolve() for x in args.readonly_depot])
            env.update(FIRSTUSE_EXPECTED_PACKAGE_ROOT=str(project),FIRSTUSE_PORTABLE_PAYLOAD_ROOT=plan['payload'],FIRSTUSE_PREVALIDATED_CONTEXT=str(ctx),FIRSTUSE_PREVALIDATED_CONTEXT_SHA256=sha(ctx),FIRSTUSE_FIXTURE_SUPPORTS='',FIRSTUSE_FREEZE_READER_INPUT='0')
            for key,val in scene['environment'].items():
                env[key]=str(Path(plan['payload'])/val['input']) if isinstance(val,dict) else val
            raw=d/'raw_trace.jl'
            cmd=[args.julia,'--startup-file=no','--threads=1','--project='+str(project)]
            if args.mode=='trace':
                env.update(FIRSTUSE_TRACE_PATH=str(raw),FIRSTUSE_COLLECT_INFERENCE='1')
                cmd.append('--trace-compile='+str(raw))
            cmd.extend([plan['generated_probe'],scene['public_target'],scene['fixture'],str(d/'receipt.json')])
            process=d/'process';process.mkdir()
            result=run(cmd,env,process,180)
            record=dict(id=scene['id'],ordinal=ordinal,process=result,final_pass=False)
            attempts.append(record);(evidence/'attempts.json').write_text(json.dumps(attempts,indent=2)+'\n')
            print('PORTABLE_SOURCE_SUPPLEMENT',scene['id'],ordinal,result,flush=True)
            if result['return_code'] or result['stop_reason']:
                raise RuntimeError('Failed public supplement retained; pending untouched')
            receipt=json.loads((d/'receipt.json').read_text());call=receipt['first_calls'][0]
            assert receipt['fixture_passed'] and len(receipt['first_calls'])==1 and call['success'] and call['gc_on_at_target']
            assert not any(call['extension_state_before'].values())
            qualification=qualify_scene(declaration,d,payload_root=Path(plan['payload']),speed=args.mode=='cold')
            (d/'qualification.json').write_text(json.dumps(qualification,indent=2)+'\n')
            record['qualification']=qualification
            (evidence/'attempts.json').write_text(json.dumps(attempts,indent=2)+'\n')
            if not qualification['passed']:raise RuntimeError('Failed science/cold supplement retained')
            if args.mode=='trace':
                before,after=call['trace_bytes_before'],call['trace_bytes_after'];data=raw.read_bytes()
                assert 0<=before<=after<=len(data)
                target=d/'public_target_first_inference.jl';target.write_bytes(data[before:after])
                # The absence of the previously hidden compiler requests from
                # preparation is tested using an independently declared pattern set.
                patterns={'read_projection_representation_search_hdf5':['typeof(Base.iterate), JSON3.Array{JSON3.Object'],
                    'prepare_exact_wannier_operator_bundle':['typeof(Base.pairs), JSON3.Object{','typeof(Base.getindex), Base.Dict{String, String}, String']}.get(scene['id'],[])
                prefix=data[:before].decode()
                preheated=[line for line in prefix.splitlines() if any(x in line for x in patterns)]
                (d/'preparation_warmup_check.json').write_text(json.dumps(dict(patterns=patterns,unexpected_preparation_requests=preheated,passed=not preheated),indent=2)+'\n')
                if preheated:raise RuntimeError('PREPARATION_PREHEATED_REQUIRED_SOURCE_SPECIALIZATION')
                infer=d/'first_inference/inference_timings.json';types=d/'first_inference/actual_all_inference_types.jls'
                index.append(dict(id=scene['id'],base_id=scene['id'],public_target=scene['public_target'],mpi_size=1,source_src_ext_sha256=plan['source_src_ext_sha256'],manifest_sha256=sha(project/'Manifest.toml'),fixture_path=scene['fixture'],fixture_sha256=sha(scene['fixture']),runner_path=plan['generated_probe'],runner_sha256=sha(plan['generated_probe']),trace_scope='first_successful_public_call_byte_interval',trace=str(target.relative_to(evidence)),sha256=sha(target),inference=str(infer.relative_to(evidence)),inference_sha256=sha(infer),actual_types=str(types.relative_to(evidence)),actual_types_sha256=sha(types)))
                (evidence/'index_partial.json').write_text(json.dumps(index,indent=2)+'\n')
    if index:(evidence/'index.json').write_text(json.dumps(index,indent=2)+'\n')
    (evidence/'completion.json').write_text(json.dumps(dict(attempts=len(attempts),source_src_ext_sha256=plan['source_src_ext_sha256'],all_samples_qualified=True,source_diagnostic_only=args.mode=='trace',performance_qualified=args.mode=='cold',final_pass=False),indent=2)+'\n')



if __name__=='__main__':main()
