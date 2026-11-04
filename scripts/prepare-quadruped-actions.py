"""Pin separate Classic Timber Wolf and sheep motions to their retained rigs."""

import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
FAMILY = 'quadruped_actions'
CLASSES = {225: ['TimberWolf'], 207: ['Sheep'], 223: ['Sheep']}
KINDS = {225: 'canines_wolf_timber', 207: 'ruminants_sheep', 223: 'ruminants_sheep_shorn'}
VISUAL = 'Presentation/SourceQuadrupedCollapseVisual.gd'
SLOTS = {4: 'LookSide', 5: 'Attack', 6: 'Attack2', 8: 'Death', 9: 'Fidget', 10: 'Fidget2', 12: 'Death2'}
REFERENCES = {
    225: {
        5: (5, '7b8d38da22e1c9617e695ed2f24e8194ae450b969b2a5c3feea1a9ca906633aa'),
        6: (5, '54845bc68ab87086bf3aadbbd520dfcda8f7895d0bc092dae30b0219c8a3eb3c'),
        8: (6, '79c201439c38abccc0c0373de9d4cf0fbf925d67d3c9e16c65382b2e5524e7e2'),
        9: (5, 'cc8b6f9d17ac4729dd8b712f0b330b3633faedf537f998b0333318a576b051c5'),
        10: (3, '7b3327e6826abd301e1164344a10f4ec05c8c30a6a3540f9c8d6bc962639af85'),
        12: (6, 'dfd37922dfffb3630ad6531e67fb9aceb755ab73862a7b051209a92e4f6b0284'),
    },
    207: {
        4: (3, '497a32c19ce644c97e4815cacc2f83a4c9e6b64fe54682daa4ee9829f1d8f4fb'),
        5: (5, '09ca014ccafca71a91072b1b829336156c270aa4bda25f1ed3b6eed5dbe23d4e'),
        6: (5, '3cd128b4ce455159b982dea33f3938372ea6ecb7157f8428afaa6021af89599d'),
        8: (6, '336fe8e29fc0630ea2e2f5260c2c4666c32df214f38881f6fe5f1159c10750e6'),
        9: (5, '30198b7610ca830f8ff3853af501926193d77d442053878318947091c4b6d3f0'),
        10: (3, 'd79b3bc1fdb3c1df5605805e38e628786b0ebb5f762da83ea0adf99da69c4c8f'),
        12: (6, '3e8057cf7464e8809304c2e03b8e37774c262da20062923d68539bbeca507cbb'),
    },
    223: {
        4: (3, '1fcad2da84d7712c956464b1176a362cdb130bf0945f44ca58f68eca51ec84ed'),
        5: (5, '135b59fbef0eb4483fe1a90661cab76bb4d0eab2fb23644aecced88aee08de31'),
        6: (5, 'ac6a8ea144dcc9dd60a9e5f3e83d69c0539f0da75aa2bc072b2502c88986f14e'),
        8: (6, '73d2c8c488c8989b86e7406874d0bd8d1c79b9ae41d756116f0573c7c34a733e'),
        9: (5, '98cd3dcc8c76c0761a84701c16d3cb7d1b7864627e2f6603e4760e548966ec35'),
        10: (3, '76278066c066c7b2abd7efdea0a36edcaddddf53a410660a67e1ea5c08dbee97'),
        12: (6, '64d208d51ed799350d32e99fe7ff465f945bd9767627bd8ef57a82200563a6dd'),
    },
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def prepared(entries):
    bake = read(VIEWER / 'local-art/creatures/quadruped-actions-bake.json')
    assert bake['recipe'] == sha(ROOT / 'scripts/bake-quadruped-actions.gd')
    assert bake['arm_solver'] == sha(VIEWER / 'Presentation/WaterElementalFidgets.gd')
    assert bake['skin_solver'] == sha(VIEWER / 'Presentation/SourceGroundLookup.gd')
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    rows = []
    for native, kind in KINDS.items():
        base, = (row for row in entries if row['status'] == 'validated' and row['kind'] == kind
                 and [identity['body'] for identity in row['bodies']] == [native])
        assert base['profile'] == 'animal' and not base.get('classic_gesture_batch')
        wolf = native == 225
        assets, scenes = {}, {}
        for treatment in ('original', 'rounded', 'modern'):
            source = f'local-art/creatures/{kind}-{treatment}.gltf'
            target = f'local-art/creatures/quadruped-actions-{native}-{treatment}.scn'
            assert sha(VIEWER / source) == base['asset_sha256'][treatment]
            scenes[treatment] = sha(VIEWER / target)
            assert bake['scenes'][str(native)][treatment] == {
                'source': base['asset_sha256'][treatment], 'scene': scenes[treatment]}
            assets[treatment] = 'res://' + target
        references = {str(slot): reference(ledger, native, slot, ('anim.mul', native, frames, digest))
                      for slot, (frames, digest) in REFERENCES[native].items()}
        methods = {
            'Attack2': 'Fitted forepaw lift and pounce' if wolf else 'Fitted low head drive and short step',
            'Death': 'Fitted belly-first fall' if wolf else 'Fitted near-side collapse',
            'Death2': 'Fitted opposite roll with folded limbs',
            'Fidget2': 'Fitted short chin lift',
        }
        if not wolf:
            methods['LookSide'] = 'Fitted lateral head turn for Classic group 4'
        clips = dict(base['clip_sources'])
        clips['RecoveredDeath'] = clips.pop('Death')
        rows.append(dict(base, family=FAMILY, status='prepared', assets=assets, clip_sources=clips,
                         presentation_script='res://' + VISUAL,
                         presentation_script_sha256=sha(VIEWER / VISUAL),
                         authored_action_reference=references['8'], classic_motion_references=references,
                         authored_action_scene_sha256=scenes, native_extra_classic_actions=[6, 8, 12] if wolf else [4, 6, 8, 12],
                         classic_action_categories=base.get('classic_action_categories', {}) |
                         {str(slot): SLOTS[slot] for slot in REFERENCES[native]},
                         authored_replacements=base.get('authored_replacements', {}) | methods))
    return rows, CLASSES
