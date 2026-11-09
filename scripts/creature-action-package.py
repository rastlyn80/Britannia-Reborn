"""Verify pinned Classic frames and the scenes baked from a retained local rig."""

import hashlib
from pathlib import Path
import runpy


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'scripts'
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
COMMON = runpy.run_path(str(SCRIPTS / 'prepare-post-solen-actions.py'))
read, sha = COMMON['read'], COMMON['sha']


def checked_mul_sources(pin_name, groups_by_body):
    pins = read(SCRIPTS / pin_name)
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    ledger = runpy.run_path(str(SCRIPTS / 'build-creature-actions.py'))
    source, _, flags = ledger['original_mul_groups'](data, set(groups_by_body))
    rows = {(row['body'], row['group']): row for row in source}
    assert set(map(int, pins)) == groups_by_body.keys()
    for body, groups in groups_by_body.items():
        proof = pins[str(body)]
        assert flags[body][0] == 'MONSTER' and set(map(int, proof)) == groups
        for group in groups:
            row = rows[body, group]
            assert row['layout'] == 'large' and not row['mobtype_prefers_uop']
            directions = row['directions']
            assert [entry['direction'] for entry in directions] == list(range(5))
            digest = hashlib.sha256(''.join(entry['payload_sha256'] for entry in directions).encode()).hexdigest()
            assert proof[str(group)] == dict(body=body, group=group, archive=row['archive'], graphic=row['graphic'],
                                             directions=list(range(5)), frames=[entry['frames'] for entry in directions],
                                             directional_payload_sha256=digest)
    return pins


def bake_input_hashes(filenames):
    return {name: sha(SCRIPTS / name) for name in filenames} | {
        name: sha(VIEWER / 'Presentation' / name) for name in ('WaterElementalFidgets.gd', 'SourceGroundLookup.gd')}


def checked_scenes(base, body, stem, inputs):
    treatments = {'original', 'rounded', 'modern'}
    before = base.get('assets') or {
        name: f"res://local-art/creatures/{base['kind']}-{name}.gltf" for name in sorted(treatments)}
    assert before.keys() == treatments
    expected = base.get('asset_sha256') or {
        name: pin['scene_sha256'] for name, pin in base['saved_scenes'].items()}
    hashes = {name: sha(VIEWER / path[6:]) for name, path in before.items()}
    assert hashes == expected
    assets = {name: f'res://local-art/creatures/{stem}-{name}.scn' for name in before}
    scenes = {name: sha(VIEWER / path[6:]) for name, path in assets.items()}
    receipt = read(ART / f'{stem}-bake.json')
    assert receipt['inputs'] == inputs and receipt['scenes'][str(body)] == {
        name: {'source': hashes[name], 'scene': scenes[name]} for name in before}
    return before, assets, scenes
