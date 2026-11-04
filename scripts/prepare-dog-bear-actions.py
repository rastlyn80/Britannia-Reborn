"""Validate fitted actions on the retained Dog and Black Bear rigs."""

import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
FAMILY = 'dog_bear_actions'
CLASSES = {217: ['Dog'], 211: ['BlackBear']}
CONSTRUCTOR_HUES = {217: {'Dog': [[2301, 2318]]}, 211: {'BlackBear': [[0, 0]]}}
VISUAL = 'Presentation/SourceQuadrupedCollapseVisual.gd'
ROUTES = {
    217: {5: 'Attack', 6: 'Attack2', 8: 'Death', 9: 'Fidget', 10: 'Fidget2', 12: 'Death2'},
    211: {4: 'LookSide', 5: 'BearRearStrike', 6: 'Attack', 8: 'Death', 9: 'Fidget', 10: 'Fidget2', 12: 'Death2'},
}
FRAMES = {4: 3, 5: 5, 6: 5, 8: 6, 9: 5, 10: 3, 12: 6}
REFERENCES = {
    217: {
        5: '35f67470b5b4e1779d9d3ca175d76ece195bdc7112b4fbe8c539d0f8cbcc8e83',
        6: '9f121d8ce16f29ad38426907b05adfe2b504956bb342e7556ac2b2c4832975de',
        8: '33e2c5deec29e10a144cfaf83c05471e921cd2fa78271682d8b735f659b3e1e5',
        9: '7f63ab8091c2b93906d4ccfcdc5ff5654fdded59c28e0058dbbf8fc8b2bfcbd8',
        10: '31ccf26bb5082af7375be7d4ab5ba8639e90e0a8fe2cbf3685dc05d6e68ebf69',
        12: 'cde771e03d767a26a2ee094cc79e081f4ef44fe2d784bc57552f901dffcc86a4',
    },
    211: {
        4: '94315c74d714f42bf5ed67d1cba725340b560e90a5d514cc6e0278535a6d1893',
        5: '92da482025424f311913376c6a736e45ccf0b8b38f261721b9efff1af354a211',
        6: '36046396bb749616695d8d5e65a64a645e9f0196c8559f268e55efd90e6e0ca7',
        8: '0f39fce9bfdff8af1719ed53e5db541f2e015051e468462e2582aa54a6b15384',
        9: 'b829805ed43267fcea4bdd999ef6b0a428196729c10b65df1f1f31d0a20caf36',
        10: '1b88321ea59f905eef5c375dbb908cadd69f3fad8e3993b5d05a1b5fb2e3cfab',
        12: '98f486f869702cc37dbfeab8fe1fb06763a29eb25f866bcf609586b2974bcd19',
    },
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def prepared(entries):
    bake = read(VIEWER / 'local-art/creatures/dog-bear-actions-bake.json')
    inputs = (
        ROOT / 'scripts/bake-dog-bear-actions.gd',
        ROOT / 'scripts/bake-quadruped-actions.gd',
        VIEWER / 'Presentation/WaterElementalFidgets.gd',
        VIEWER / 'Presentation/SourceGroundLookup.gd',
    )
    assert bake['inputs'] == {path.name: sha(path) for path in inputs}
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    rows = []
    for body, routes in ROUTES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [identity['body'] for identity in row['bodies']] == [body])
        assert base['profile'] == 'animal' and not base.get('classic_gesture_batch')
        assets, scenes = {}, {}
        for treatment in ('original', 'rounded', 'modern'):
            source = base.get('assets', {}).get(treatment, f"res://local-art/creatures/{base['kind']}-{treatment}.gltf")
            target = f'local-art/creatures/dog-bear-actions-{body}-{treatment}.scn'
            source_digest = sha(VIEWER / source.removeprefix('res://'))
            assert source_digest == base['asset_sha256'][treatment]
            scenes[treatment] = sha(VIEWER / target)
            assert bake['scenes'][str(body)][treatment] == {'source': source_digest, 'scene': scenes[treatment]}
            assets[treatment] = 'res://' + target
        assert routes.keys() == REFERENCES[body].keys()
        references = {str(slot): reference(ledger, body, slot, ('anim.mul', body, FRAMES[slot], digest))
                      for slot, digest in REFERENCES[body].items()}
        clips = dict(base['clip_sources'])
        for clip in ('Attack', 'Death'):
            clips['Recovered' + clip] = clips.pop(clip)
        descriptions = {
            'Attack': 'Recovered strike with a separately sampled pelvis floor correction',
            'Death': 'Fitted belly-first fall on the retained rig',
            'Death2': 'Fitted opposite roll with folded limbs',
            'Fidget2': 'Fitted chin lift' if body == 217 else 'Fitted paw dip',
        }
        if body == 217:
            descriptions['Attack2'] = 'Fitted forepaw lift and pounce using the related canine profile'
        else:
            descriptions.update(BearRearStrike='Fitted upright swipe from the hind legs',
                                LookSide='Fitted alert head turn')
        rows.append(dict(base, family=FAMILY, status='prepared', assets=assets, clip_sources=clips,
                         presentation_script='res://' + VISUAL, presentation_script_sha256=sha(VIEWER / VISUAL),
                         native_constructor_hue_ranges=CONSTRUCTOR_HUES[body],
                         authored_action_reference=references['8'], classic_motion_references=references,
                         authored_action_scene_sha256=scenes,
                         native_extra_classic_actions=[slot for slot in routes if slot in (4, 6, 8, 12)],
                         classic_action_categories=base.get('classic_action_categories', {}) |
                         {str(slot): clip for slot, clip in routes.items()},
                         authored_replacements=base.get('authored_replacements', {}) | descriptions))
    return rows, CLASSES
