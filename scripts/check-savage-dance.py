"""Validate exact prepared dance evidence; this never accepts a body/action."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def main():
    subprocess.run([sys.executable, '-B', str(ROOT / 'scripts/prepare-savage-dance.py'), '--check-inputs'], check=True)
    reference = ROOT / 'work/creatures/savages/dance-reference'
    output = ROOT / 'Viewer/local-art/human-npcs/savages/dance'
    source = read(reference / 'preparation.json')
    prep = read(output / 'preparation.json')
    proof = read(ROOT / 'work/creatures/savages/dance-tests.json')
    assert source['input_manifest_sha256'] == sha(ROOT / 'scripts/savage-dance-inputs.json')
    for name, digest in source['source_tool_sha256'].items():
        assert sha(ROOT / 'scripts' / name) == digest, name
    for report in [prep, proof]:
        assert report['runtime_sha256']
        for name, digest in report['runtime_sha256'].items():
            assert sha(ROOT / 'Viewer/Presentation' / name) == digest, name
    assert prep['reference_preparation_sha256'] == proof['source_preparation_sha256'] == sha(reference / 'preparation.json')
    assert proof['preparation_sha256'] == sha(output / 'preparation.json')
    assert proof['checks'] >= 63725 and proof['failures'] == 0
    assert proof['rendered_poses'] == len(proof['captures']) == 8
    for capture in proof['captures']:
        path = (ROOT / 'Viewer' / capture['path'].removeprefix('res://')).resolve()
        assert path.is_relative_to((ROOT / 'work/creatures/savages').resolve())
        assert sha(path) == capture['sha256'] and capture['occupied_samples'] > 500
    assert {row['gender'] for row in prep['models']} == {row['gender'] for row in proof['models']} == {'male', 'female'}
    for original in source['models']:
        assert sha(reference / original['output']) == original['sha256']
        assert original['omitted_animation_bones'] == ['bip01 footsteps']
        floor = original['stats']['clips']['TribalDance']
        assert floor['floor_policy'] == 'source_vertical' and floor['floor_offset_range'][0] == floor['floor_offset_range'][1]
        prepared = next(r for r in prep['models'] if r['gender'] == original['gender'])
        tested = next(r for r in proof['models'] if r['gender'] == original['gender'])
        assert prepared['status'] == 'prepared' and prepared['mapped_bones'] == len(prepared['mapping']) == 52
        assert prepared['source_bones'] == 43 and prepared['target_bones'] == 61
        assert prepared['maximum_global_rotation_basis_error'] < .00001
        assert prepared['maximum_nonpelvis_local_position_error_m'] < .000001
        assert prepared['maximum_floor_reference_error_m'] < .00001
        assert prepared['source_reference_sha256'] == original['sha256']
        body=original['floor_reference']
        assert body['stats']['source_points']==(190 if original['gender']=='female' else 183)
        assert sha(reference/body['output'])==body['sha256']==prepared['floor_reference_sha256']
        assert all(abs(s['source_lift_m']-max(0,s['raw_source_body_clearance_m']))<.000001 for s in prepared['samples'])
        asset = (ROOT / 'Viewer' / prepared['asset'].removeprefix('res://')).resolve()
        assert asset.is_relative_to(output.resolve())
        assert sha(asset) == prepared['asset_sha256'] == tested['asset_sha256']
        assert len(tested['complete_skin_holdouts']) == 193
        assert tested['maximum_floor_error_m'] < .004 and tested['maximum_global_basis_error'] < .0001
        assert tested['maximum_local_offset_error_m'] < .000001
        assert prepared['source_lift_m']>.02 and abs(tested['preserved_lift_m']-prepared['source_lift_m'])<.004
    print('SAVAGE PREPARED DANCE: exact source/retarget/386 off-grid skins/eight actual GPU views pass; no native111 or runtime acceptance')


if __name__ == '__main__':
    main()
