"""Prepare Orc Captain and Bog Thing action candidates without activating them."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import runpy
import subprocess


SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'orc_bog_actions'
CLASSES = {7: ['OrcCaptain'], 780: ['BogThing', 'Tangle']}
TANGLE = {'path': 'Projects/UOContent/Mobiles/Monsters/ML/Blighted Grove/Tangle.cs',
          'sha256': '932d2c6b4464301068a52c10dc4b691cca1d8827cdd28ae30b993cc8d0c32201'}
CLASSIC = {
    7: {0: 'Walk', 1: 'Idle', 2: 'Death', 3: 'Death2', 4: 'Attack', 5: 'Attack2', 6: 'Attack3',
        10: 'Hit', 11: 'Pillage', 15: 'CaptainHighGuard', 16: 'CaptainLowGuard',
        17: 'CaptainAxeSignal', 18: 'CaptainAxeCheck'},
    780: {0: 'Walk', 1: 'Idle', 2: 'Death', 3: 'Death', 4: 'Attack', 5: 'Attack2', 6: 'Attack3',
          10: 'Hit', 11: 'BogFloorFidget', 15: 'BogFloorBrace', 16: 'BogFloorBrace',
          17: 'BogFloorFidget', 18: 'BogFloorReach'},
}
FITTED = {7: (3, 15, 16, 17, 18), 780: (11, 15, 18)}
SCRIPTS_BY_BODY = {
    7: ('bake-orc-captain-axe.gd', 'bake-orc-captain-motions.gd', 'fit-orc-captain-axe.gd',
        'orc-captain-axe-clearance.gd', 'route-orc-captain-second-strike.gd', 'prepare-orc-captain-axe.py',
        'bake-troll-weapons-trial.gd', 'bake-zombie-actions.gd', 'bake-skeleton-actions.gd',
        'bone-knight-cyclops-clearance.gd', 'test-quadruped-actions.gd'),
    780: ('bake-bog-thing-gestures.gd', 'bake-bog-thing-clearance.gd', 'test-quadruped-actions.gd'),
}
helpers = runpy.run_path(str(SCRIPTS / 'prepare-field-fauna.py'))
read, sha = helpers['read'], helpers['sha']
ledger = runpy.run_path(str(SCRIPTS / 'build-creature-actions.py'))


def references():
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    rows, _, flags = ledger['original_mul_groups'](data, set(CLASSES))
    result = {}
    for body, categories in CLASSIC.items():
        pins = read(SCRIPTS / f'creature-{body}-classic-frame-pins.json')
        assert pins['mobtypes'] == list(flags[body])
        body_rows = [row for row in rows if row['body'] == body]
        assert set(pins['groups']) == {str(slot) for slot in categories} == {str(row['group']) for row in body_rows}
        result[body] = {}
        for row in body_rows:
            group = str(row['group'])
            assert all(row[key] == pins[key] for key in ('archive', 'graphic', 'layout'))
            directions = row['directions']
            assert [item['direction'] for item in directions] == list(range(5))
            signature = hashlib.sha256(''.join(item['payload_sha256'] for item in directions).encode('ascii')).hexdigest()
            assert pins['groups'][group] == [[item['frames'] for item in directions], signature]
            if row['group'] not in (0, 1):
                result[body][group] = dict(body=body, group=row['group'], archive=row['archive'], graphic=row['graphic'],
                                           frames=directions[0]['frames'], directions=list(range(5)),
                                           directional_payload_sha256=signature)
        duplicates = {(int(first), int(second)) for first, item in pins['groups'].items()
                      for second, other in pins['groups'].items() if int(first) < int(second) and item == other}
        assert duplicates == ({(2, 3), (11, 17), (15, 16)} if body == 780 else set())
    return result


def bake_record(body, base):
    treatments = ('original', 'rounded', 'modern') if body == 7 else ('original', 'modern')
    assets = {name: (f'res://local-art/creatures/orc-captain-actions-{name}.scn' if body == 7 else
                     'res://local-art/creatures/bog-thing-actions.scn') for name in treatments}
    retained = {name: base.get('assets', {}).get(name, f"res://local-art/creatures/{base['kind']}-{name}.gltf")
                for name in treatments}
    inputs = {name: sha(SCRIPTS / name) for name in SCRIPTS_BY_BODY[body]}
    sources = {name: sha(VIEWER / asset[6:]) for name, asset in retained.items()}
    assert sources == base['asset_sha256']
    scenes = {name: sha(VIEWER / asset[6:]) for name, asset in assets.items()}
    return assets, retained, scenes, dict(inputs=inputs, sources=sources, scenes=scenes)


def prepared(entries):
    frame_refs = references()
    result = []
    for body in CLASSES:
        base, = (row for row in entries if row['status'] == 'validated'
                 and [int(identity['body']) for identity in row['bodies']] == [body])
        assets, retained, scenes, record = bake_record(body, base)
        assert read(ART / f'creature-{body}-actions-bake.json') == record
        if body == 780:
            assets['rounded'] = assets['original']
            scenes['rounded'] = scenes['original']
        presentation = 'OrcCaptainActionsVisual' if body == 7 else 'BogThingActionsVisual'
        renderer = f'Presentation/{presentation}.gd'
        dependency = (('TerathanActionsVisual', 'SourceSpaceFallPlayback', 'CreatureFallPlayback', 'SourceGroundLookup')
                      if body == 7 else ('SourceBogThingVisual', 'SourceGazerLarvaVisual'))
        categories = CLASSIC[body]
        result.append(dict(base, status='prepared', family=FAMILY, assets=assets,
                           classic_gesture_base_assets=retained, authored_action_scene_sha256=scenes,
                           authored_action_base_sha256=record['sources'],
                           authored_action_reference=frame_refs[body]['18'], classic_motion_references=frame_refs[body],
                           classic_action_categories={str(slot): clip for slot, clip in categories.items()},
                           native_extra_classic_actions=[2, 3, 10, 15, 16, 18],
                           native_constructor_hues={'OrcCaptain': 0} if body == 7 else {'BogThing': 0, 'Tangle': 0x21},
                           authored_replacements=base.get('authored_replacements', {}) | {
                               categories[slot]: f'Fitted on the original rig using Classic group {slot}'
                               for slot in FITTED[body]},
                           presentation_script=f'res://{renderer}', presentation_script_sha256=sha(VIEWER / renderer),
                           collapse_renderer_dependencies={name: sha(VIEWER / f'Presentation/{name}.gd')
                                                           for name in (presentation, *dependency)}))
        if body == 7:
            result[-1]['grounded_gestures'] = [categories[slot] for slot in (4, 5, 6, 10, 11, 15, 16, 17, 18)]
            result[-1]['orc_captain_axe'] = dict(
                source=runpy.run_path(str(SCRIPTS / 'prepare-orc-captain-axe.py'))['INPUT_HASHES'], triangles=82,
                socket='cp_grasp_rhand', scale=0.86,
                scope='Original related Orc Lord axe art attached to the Orc Captain as a client visual. '
                      'Classic sprites show a double blade. The native constructor does not equip a weapon.')
        else:
            assert sha(ROOT / 'Server/ModernUO' / TANGLE['path']) == TANGLE['sha256']
            identity, = base['bodies']
            result[-1]['bodies'] = [dict(identity, native_sources=[*identity['native_sources'], TANGLE])]
    return result, CLASSES


def bake(body):
    index = read(ART / 'accepted-index.json')
    base, = (row for row in index['entries'] if row['status'] == 'validated'
             and [int(identity['body']) for identity in row['bodies']] == [body])
    if base.get('classic_gesture_batch') == FAMILY:
        raise ValueError('Rebuild this active package in a separate workspace with the retained base registry.')
    stages = (('bake-orc-captain-axe', 'bake-orc-captain-motions', 'fit-orc-captain-axe',
               'route-orc-captain-second-strike') if body == 7 else
              ('bake-bog-thing-gestures', 'bake-bog-thing-clearance'))
    if body == 7:
        runpy.run_path(str(SCRIPTS / 'prepare-orc-captain-axe.py'))['prepare']()
    godot = next((ROOT / '.tools/godot').glob('*console.exe'))
    profile = str(ROOT / '.godot-user')
    env = dict(os.environ, APPDATA=profile, LOCALAPPDATA=profile)
    for stage in stages:
        process = subprocess.run([str(godot), '--headless', '--path', str(VIEWER), '--script',
                                  f'res://../scripts/{stage}.gd'], env=env, text=True, encoding='utf-8',
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=True)
        print(process.stdout, end='')
        assert 'ERROR:' not in process.stdout, stage
    record = bake_record(body, base)[3]
    (ART / f'creature-{body}-actions-bake.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bake', type=int, choices=CLASSES, required=True)
    bake(parser.parse_args().bake)
