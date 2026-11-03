"""Run bounded GPU chunks and merge only complete, current passing evidence.

Source data and generated frames stay private under work/. No server is used.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
TEST = ROOT/'Viewer/Presentation/CandidatePresentationBatchTests.gd'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def merge(chunks, preparations, output):
    expected = {model['kind']:model for path in preparations for model in read(path)['models']}
    assert len(expected) == sum(len(read(path)['models']) for path in preparations), 'Duplicate kinds'
    merged = dict(checks=0, failures=0, renderer='forward_plus', samples=[], death_entries=[],
                  inputs_sha256={}, runtime_sha256={}, chunks=[])
    seen = set()
    for folder, kinds in chunks:
        proof = read(folder/'validation.json')
        assert proof['failures'] == 0 and proof['checks'] > 0 and proof['renderer'] == 'forward_plus'
        log = (folder/'gpu.log').read_text(encoding='utf-8')
        assert 'ERROR:' not in log and 'Vulkan' in log and 'Forward+' in log
        assert {row['kind'] for row in proof['samples']} == set(kinds)
        assert not seen.intersection(kinds), 'Overlapping chunks'
        seen.update(kinds)
        for name, digest in proof['runtime_sha256'].items():
            assert Path(name).name == name and sha(ROOT/'Viewer/Presentation'/name) == digest, name
            assert name not in merged['runtime_sha256'] or merged['runtime_sha256'][name] == digest
            merged['runtime_sha256'][name] = digest
        assert proof['runtime_sha256']['CandidatePresentationBatchTests.gd'] == sha(TEST)
        for name, digest in proof['inputs_sha256'].items():
            assert name.startswith('res://')
            path = (ROOT/'Viewer'/name.removeprefix('res://')).resolve()
            assert path.is_relative_to(ROOT) and sha(path) == digest, name
            assert name not in merged['inputs_sha256'] or merged['inputs_sha256'][name] == digest
            merged['inputs_sha256'][name] = digest
        for kind in kinds:
            model = expected[kind]
            clips = set(model['stats']['original']['clips'])
            poses = [row for row in proof['samples'] if row['kind'] == kind]
            assert len(poses) == len(clips)*2
            assert {(row['plane'],row['clip']) for row in poses} == {
                (plane,clip) for plane in ['flat','cross'] for clip in clips}
            deaths = [row for row in proof['death_entries'] if row['kind'] == kind]
            assert len(deaths) == 2 and {row['plane'] for row in deaths} == {'flat','cross'}
            assert all(row['first_displayed_skin_error_m'] < .001 for row in deaths)
            images = list((folder/kind).glob('*.png'))
            assert len(images) == len(clips)*2+2 and all(path.stat().st_size > 100 for path in images)
            (output/kind).mkdir(exist_ok=True)
            for path in images:
                shutil.copy2(path,output/kind/path.name)
        merged['checks'] += proof['checks']
        merged['samples'].extend(proof['samples'])
        merged['death_entries'].extend(proof['death_entries'])
        merged['chunks'].append({'path':folder.relative_to(ROOT).as_posix(),
                                 'validation_sha256':sha(folder/'validation.json'),
                                 'log_sha256':sha(folder/'gpu.log'),'kinds':kinds})
    assert seen == set(expected), 'Incomplete batch'
    for path in preparations:
        resource = 'res://'+path.relative_to(ROOT/'Viewer').as_posix()
        assert merged['inputs_sha256'][resource] == sha(path)
    merged['scope'] = ('Complete union of disjoint actual Vulkan Forward+ chunks using the same pose/skin/floor/'
                       'picking/corpse checks. All exact inputs/runtime and every expected kind/clip/plane/death '
                       'are checked before aggregation. No native server or full-gameplay claim.')
    merged['merger_sha256'] = sha(Path(__file__))
    temporary = output/'validation.json.pending'
    temporary.write_text(json.dumps(merged,indent=2)+'\n',encoding='utf-8')
    temporary.replace(output/'validation.json')
    return merged


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preparation',required=True,help='Comma-separated local creature preparation paths')
    parser.add_argument('--output',required=True,type=Path)
    parser.add_argument('--jobs',type=int,choices=[1,2,3],default=3)
    parser.add_argument('--merge-only',action='store_true')
    args = parser.parse_args()
    names = args.preparation.split(',')
    preparations = [(ROOT/'Viewer/local-art/creatures'/name).resolve() for name in names]
    assert all(path.is_relative_to((ROOT/'Viewer/local-art/creatures').resolve()) for path in preparations)
    output = args.output.resolve()
    assert output.is_relative_to(ROOT/'work'), 'Generated evidence stays under work/'
    output.mkdir(parents=True,exist_ok=True)
    kinds = [model['kind'] for path in preparations for model in read(path)['models']]
    assert kinds and len(kinds) == len(set(kinds))
    assert all(kind.replace('_','').isalnum() for kind in kinds)
    chunks = [(output/'chunks'/str(index),kinds[index::args.jobs]) for index in range(min(args.jobs,len(kinds)))]
    godot = next((ROOT/'.tools/godot').glob('*console.exe'))
    env = os.environ.copy()
    env['APPDATA'] = env['LOCALAPPDATA'] = str(ROOT/'.godot-user')

    def run(chunk):
        folder, selected = chunk
        folder.mkdir(parents=True,exist_ok=True)
        command = [str(godot),'--path',str(ROOT/'Viewer'),'--resolution','96x96',
                   '--script','res://Presentation/CandidatePresentationBatchTests.gd','--',
                   '--preparation='+args.preparation,'--kinds='+','.join(selected),
                   '--output=res://../'+folder.relative_to(ROOT).as_posix()]
        with (folder/'gpu.log').open('w',encoding='utf-8') as log:
            result = subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
        assert result.returncode == 0, str(folder/'gpu.log')
        print('GPU CHUNK PASS:',folder.name,','.join(selected),flush=True)

    if not args.merge_only:
        with ThreadPoolExecutor(max_workers=args.jobs) as workers:
            list(workers.map(run,chunks))
    merged = merge(chunks,preparations,output)
    print(f"CREATURE GPU CHUNKS: {len(kinds)} forms / {merged['checks']} checks / "
          f"{len(merged['samples'])} poses / {len(merged['death_entries'])} death entries /0 failures",flush=True)


if __name__ == '__main__':
    main()
