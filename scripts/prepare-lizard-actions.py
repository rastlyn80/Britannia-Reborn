"""Prepare separate Classic motion categories on both retained armed Lizardmen."""

import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
FAMILY = 'lizard_actions'
CLASSES = {35: ['Lizardman'], 36: ['Lizardman']}
VISUAL = 'Presentation/SourceLizardActionsVisual.gd'
SLOTS = {2: 'Death2', 3: 'Death', 4: 'ClassicOverhead', 5: 'Attack2', 6: 'Attack3',
         10: 'Hit', 15: 'RightGuard', 16: 'LeftGuard', 17: 'Fidget', 18: 'Fidget2'}
FRAMES = (4, 4, 4, 4, 4, 4, 3, 3, 5, 5)
REFERENCES = {
    35: (
        'e3d4ce4be340707a30f36fc7c55953c82680b241db06d1bbfb8f28d2d3bb3d75',
        '7699e834e84b5df79116860ddd093953adb0d0158911cb2c0e0cbab053ea0911',
        '065990b53b40060cc4a6a5ab8da05426727a2c8105858f6f22d1c96b4de74284',
        '5188e28e89faa6b2897c78618ffd4a9c0ee63a9e0dc4615551dc5c5e1b7baacb',
        '87eef44a5d89386b12c8b69b7996b9584d1c7c117a21de0992e4d188a2851ff1',
        '0aeb64fca95fc43b364383b6e34458f7b1f3b8a557f6ad1a6e2e38212f13e4c1',
        'ea02b5d7e244aa8601c77e90f1fb0b2c18dd3bff615439554a13de847f68c02c',
        '64ae4e3ad819c34d6cf4146998e34d1655e28bc1d1a79953e2684f09a4e70d79',
        '11919a963107d68e4bd725316c5d3610ccab4356d920af9d1d2d2512431022ae',
        'a95b94228d6ac67b85048d927b9a6944f1761952058dd4a8ed428e86af427038',
    ),
    36: (
        '389a519920d9a314967197ac340ae6aa2bae9a15810032d1130a83195b7ed486',
        'a7e55871eaa6702f3130071b9aa4fabac07b854526529a1e181afcff23383e0e',
        '2eb0f576ab1422ae3a4dfa7fbd02353107e298c994824e44e2f39ccf68f2f73b',
        '91f214b5a5d7e3bccf255153ba53bd0dd0fc3889be071ba1ee10280d9ebf5b6d',
        '15f8f754d7fbfbbfaca112b555d278eb885fc7456c1ed1a68882891212502018',
        '470a43dac1a83d57afff732d30b305a4e4edf34dffafbf5edaa9eb9fd9b8d584',
        '3c5fa96863d899b1604e85be2aa4c97f9e56fef25195b69422a2326109e10c52',
        'e3b727e55dc043a113dbf17146e313fb6079f72f95fc056e3d5de670b31a0cc2',
        '6de0d922b5edc24b5245e8c3b88395088d66495b33a9dfd7c56ad6852cb12dff',
        'f0c28678334fff4660b32a60ec30bdccae4d8532b2bf1e61fde775575888b429',
    ),
}
METHODS = {
    'Death2': 'Fitted rear collapse with curled tail and retained rigid weapon bind',
    'ClassicOverhead': 'Fitted high preparation and overhead weapon strike',
    'Attack2': 'Fitted wide side strike with the rigid weapon held at the original bind',
    'Attack3': 'Fitted short guarded thrust',
    'RightGuard': 'Fitted narrow high guard reaction',
    'LeftGuard': 'Fitted forward shaft and inward guard reaction',
    'Fidget2': 'Fitted tilt of the raised weapon on the retained fidget body',
}


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepared(entries):
    bake = read(VIEWER / 'local-art/creatures/lizard-actions-bake.json')
    assert bake['recipe'] == sha(ROOT / 'scripts/bake-lizard-actions.gd')
    assert bake['arm_solver'] == sha(VIEWER / 'Presentation/WaterElementalFidgets.gd')
    assert bake['skin_solver'] == sha(VIEWER / 'Presentation/SourceGroundLookup.gd')
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    results = []
    for body, form in ((35, 'spear'), (36, 'mace')):
        base, = (row for row in entries if row['kind'] == f'lizardman_{form}' and row['status'] == 'validated'
                 and row['bodies'][0]['body'] == body and row.get('armed_native_receipt_sha256'))
        target = f'local-art/creatures/lizard-actions-{body}.scn'
        source = VIEWER / base['assets']['modern'].removeprefix('res://')
        scene = sha(VIEWER / target)
        assert bake['scenes'][str(body)] == {'source': sha(source), 'scene': scene}
        assert bake['scenes'][str(body)]['source'] == base['asset_sha256']['modern']
        groups = {str(group): reference(ledger, body, group, ('anim.mul', body, count, digest))
                  for group, count, digest in zip(SLOTS, FRAMES, REFERENCES[body], strict=True)}
        treatments = ('original', 'rounded', 'modern')
        results.append(dict(base, status='prepared', family=FAMILY,
                            assets=dict.fromkeys(treatments, 'res://' + target),
                            presentation_script='res://' + VISUAL, presentation_script_sha256=sha(VIEWER / VISUAL),
                            authored_action_scene_sha256=dict.fromkeys(treatments, scene),
                            authored_action_reference=groups['2'], classic_motion_references=groups,
                            native_extra_classic_actions=[10, 15, 16, 2, 3],
                            classic_action_categories=base['classic_action_categories'] | {str(slot): clip for slot, clip in SLOTS.items()},
                            authored_replacements=base['authored_replacements'] | METHODS))
    return results, CLASSES
