"""Verify the retained Deathwatch rig and its distinct Classic gestures."""

from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'deathwatch_gestures'
CLASSES = {242: ['DeathwatchBeetle', 'DeathwatchBeetleHatchling']}
ROUTES = {'10': 'Hit', '11': 'Fidget', '15': 'LeftRecoil', '16': 'RightRecoil',
          '17': 'RearingFidget', '18': 'Fidget'}
PINS = {
    '10': (4, '41794fc1c469199cbe0aa76a3d989d6cfab14fd3f8d2a4e2782ac673f59a4c56'),
    '11': (5, 'f819a97aab82ad1104604691ef0957c2d3ff662d9f9058597ad9479d38e55d97'),
    '15': (3, 'a9b48eae2c0e094d9ba8806876fc5fc8759c31a06cd73301a3080a9e2488674a'),
    '16': (3, 'dd9c38bc8cfb83589f91937b500b58a90d572cc9a5da15834de2e3eee2d5993a'),
    '17': (5, 'ae86a43e30ba3a9ee5ab3839f3f041ac126e60f6064c472266f0e5f28f4b6fe4'),
    '18': (5, 'f819a97aab82ad1104604691ef0957c2d3ff662d9f9058597ad9479d38e55d97'),
}


def prepared(entries):
    helpers = runpy.run_path(str(ROOT / 'scripts/prepare-field-fauna.py'))
    read, sha, read_bake = (helpers[name] for name in ('read', 'sha', 'read_bake'))
    base, = (row for row in entries if row['kind'] == 'bimbobushi' and row['status'] == 'validated')
    original, = read(ART / 'deathwatch/preparation.json')['models']
    alias = read(VIEWER / 'Presentation/legacy-late-action-aliases.json')['242']
    assert base == dict(original, status='validated', classic_action_categories={'11': 'Fidget'},
                        legacy_slot11_evidence=alias)
    assert alias['sibling'] == 18 and PINS['11'] == PINS['18'] and alias['payload_signature'] == PINS['11'][1]
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-earth-gazer-imp-actions.py'))['reference']
    refs = {slot: reference(ledger, 242, int(slot), ('anim4.mul', 3, frames, list(range(5)), digest))
            for slot, (frames, digest) in PINS.items()}
    recipe = read_bake('deathwatch-actions', ('bake-deathwatch-actions.gd', 'bake-zombie-actions.gd',
                                             'bake-troll-actions.gd', 'bake-skeleton-actions.gd'))['242']
    assets, scenes = {}, {}
    for treatment, path in base['assets'].items():
        source = sha(VIEWER / path.removeprefix('res://'))
        assert source == base['asset_sha256'][treatment]
        name = f'deathwatch-actions-{treatment}.scn'
        scenes[treatment] = sha(ART / name)
        assert recipe[treatment] == {'source': source, 'scene': scenes[treatment]}
        assets[treatment] = 'res://local-art/creatures/' + name
    visual = 'Presentation/DeathwatchActionsVisual.gd'
    candidate = dict(base, status='prepared', family=FAMILY, assets=assets,
                     presentation_script='res://' + visual, presentation_script_sha256=sha(VIEWER / visual),
                     authored_action_scene_sha256=scenes, authored_action_reference=refs['15'],
                     classic_motion_references=refs, classic_action_categories=ROUTES,
                     native_extra_classic_actions=[10, 15, 16, 18],
                     authored_replacements=base.get('authored_replacements', {}) | {
                         ROUTES[slot]: f'Fitted motion on the original rig from Classic group {slot}'
                         for slot in ('15', '16', '17')})
    return [candidate], CLASSES
