"""Verify saved Bone Knight and Cyclops action candidates against local sources."""

import hashlib
import json
from pathlib import Path
import runpy
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'Viewer/local-art/creatures'
CLASSES = {57: ['BoneKnight'], 75: ['Cyclops']}
RECIPES = {
    57: ('skeletons_skeleton', 'KnightDip', '1f0e60b8a9f177e72b4a090f6771ffdaf7a8b12beebfabc785bb02c8ab5283ba',
         '96641bd0262165a042199779391d97c2a339d6cae609ebf35667b84cee64ac5c',
         ('scimitar', 'wooden_shield'), 'Authored planted guard dip with the recovered scimitar and wooden shield'),
    75: ('cyclops_cyclops', 'MalletDip', 'c2bacbb379a63b526f74c1422a6044a53e8331aa247a72446ddb92561ee0bd5b',
         '013a02bc76784487e750b1e4398868b99084f3a157dafdabc6779ccfc7bb4066',
         ('mallet',), 'Authored mallet dip with a recovered Troll haft and a rebuilt banded head'),
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def prepared(entries):
    extract = runpy.run_path(str(ROOT / 'scripts/prepare-bone-knight-cyclops-props.py'))
    private = extract['OUTPUT']
    inputs = read(private / 'bake-inputs.json')
    bake = read(private / 'bake.json')
    for name, _, _, source in extract['checked_inputs']():
        receipt = inputs[name]
        assert all(receipt[key] == value for key, value in source.items())
        assert receipt['corners_sha256'] == sha(private / f'{name}-corners.json')
        assert receipt['png_sha256'] == sha(private / f'{name}-atlas.png')
    assert bake['inputs'] == sha(private / 'bake-inputs.json')
    for key, script in (('recipe', 'bake-bone-knight-cyclops.gd'),
                        ('arm', 'bake-skeleton-axe-trial.gd'), ('weapon', 'bake-troll-weapons-trial.gd'),
                        ('clearance', 'bone-knight-cyclops-clearance.gd'), ('skin', 'ophidian-bardiche-clearance.gd')):
        assert bake[key] == sha(ROOT / 'scripts' / script)
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    visual = 'Presentation/SourceHeldPropsVisual.gd'
    rows = []
    with ZipFile(extract['ARCHIVE']) as archive:
        for body, (kind, clip, digest, idle_sha, props, description) in RECIPES.items():
            base, = (row for row in entries if row['status'] == 'validated' and row['kind'] == kind
                     and [identity['body'] for identity in row['bodies']] == [body])
            assert hashlib.sha256(archive.read(base['clip_sources']['Idle'])).hexdigest() == idle_sha
            witness = reference(ledger, body, 11, ('anim.mul', body, 5, digest))
            assets, scenes = {}, {}
            for treatment in ('original', 'rounded', 'modern'):
                file = f'bone-cyclops-{body}-{treatment}.scn'
                source = sha(ART / f'{kind}-{treatment}.gltf')
                scenes[treatment] = sha(ART / file)
                assert source == base['asset_sha256'][treatment]
                assert bake['forms'][str(body)][treatment] == {'source': source, 'scene': scenes[treatment]}
                assets[treatment] = f'res://local-art/creatures/{file}'
            rows.append(dict(base, status='prepared', family='bone_cyclops', assets=assets,
                             authored_action_scene_sha256=scenes, authored_action_reference=witness,
                             classic_action_categories=base.get('classic_action_categories', {}) | {'11': clip},
                             authored_replacements=base.get('authored_replacements', {}) | {clip: description},
                             source_body_props={name: inputs[name] for name in props},
                             presentation_script=f'res://{visual}',
                             presentation_script_sha256=sha(ROOT / 'Viewer' / visual)))
    return rows, CLASSES
