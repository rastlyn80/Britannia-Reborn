"""Prepare the distinct Classic group 3 falls on the checked Meer rigs."""

import json
from pathlib import Path
import runpy


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'scripts'
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'meer_forward_falls'
BASE_FAMILY = 'lattice_through_meer_actions'
CLASSES = {770: ['MeerMage'], 773: ['MeerCaptain']}
LATTICE = runpy.run_path(str(SCRIPTS / 'prepare-lattice-through-meer-actions.py'))
read, sha = LATTICE['read'], LATTICE['sha']
BAKE_INPUTS = ('bake-meer-forward-falls.gd', *LATTICE['BAKE_INPUTS'])


def prepared(entries):
    pins = LATTICE['check_source']()
    inputs = {name: sha(SCRIPTS / name) for name in BAKE_INPUTS}
    inputs.update({name: sha(VIEWER / 'Presentation' / name)
                   for name in ('WaterElementalFidgets.gd', 'SourceGroundLookup.gd')})
    rows = []
    for body in CLASSES:
        base, = (row for row in entries if row['status'] == 'validated' and [item['body'] for item in row['bodies']] == [body])
        assert base['classic_gesture_batch'] == BASE_FAMILY and base['classic_action_categories']['3'] == 'Death'
        stem = f'meer-forward-fall-{body}-actions'
        assets = {name: f'res://local-art/creatures/{stem}-{name}.scn' for name in base['assets']}
        scenes = {name: sha(VIEWER / path[6:]) for name, path in assets.items()}
        old = {name: sha(VIEWER / path[6:]) for name, path in base['assets'].items()}
        assert old == base['asset_sha256']
        receipt = read(ART / f'{stem}-bake.json')
        assert receipt['inputs'] == inputs and receipt['scenes'][str(body)] == {
            name: {'source': old[name], 'scene': scenes[name]} for name in scenes}
        source = base['classic_motion_references']['3']
        assert source['directional_payload_sha256'] == pins[str(body)]['groups']['3'][1]
        assert source['directional_payload_sha256'] != pins[str(body)]['groups']['2'][1]
        renderer = 'MeerMageFallVisual' if body == 770 else 'MeerCaptainFallVisual'
        dependencies = [renderer, 'CreatureFallPlayback', 'SourceSpaceFallPlayback', 'ArchiveGestureGround', 'SourceGroundLookup']
        dependencies.append('ArchiveOccurrenceGestureVisual' if body == 770 else 'SourceMeerCaptainActionsVisual')
        rows.append(dict(base, family=FAMILY, status='prepared', assets=assets, classic_gesture_base_assets=base['assets'],
                         authored_action_scene_sha256=scenes, authored_action_reference=source,
                         classic_action_categories=base['classic_action_categories'] | {'3': 'Death2'},
                         authored_replacements=base['authored_replacements'] | {'Death2': 'Forward collapse fitted to Classic group 3'},
                         presentation_script=f'res://Presentation/{renderer}.gd',
                         presentation_script_sha256=sha(VIEWER / 'Presentation' / f'{renderer}.gd'),
                         collapse_renderer_dependencies={name: sha(VIEWER / 'Presentation' / f'{name}.gd')
                                                         for name in dependencies}))
    return rows, CLASSES


def main():
    selector = runpy.run_path(str(SCRIPTS / 'prepare-creature-fixtures.py'))
    baseline = selector['gesture_baseline'](FAMILY, None, CLASSES, layered=True)
    rows, _ = prepared(baseline)
    work = ROOT / 'work/creatures' / FAMILY
    work.mkdir(parents=True, exist_ok=True)
    (work / 'prepared-client.json').write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')
    print('Two independently stored forward Meer falls on the retained action scenes')


if __name__ == '__main__':
    main()
