"""Prepare the Gargoyle flight-death and Tormented Minotaur block routes."""

import hashlib
import json
from pathlib import Path
import runpy


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'scripts'
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'gargoyle_flight_minotaur_actions'
VISUAL = 'res://Presentation/SourceArmoredGargoyleFlightVisual.gd'
COMMON = runpy.run_path(str(SCRIPTS / 'prepare-post-solen-actions.py'))
read, sha = COMMON['read'], COMMON['sha']
CLASSES = {755: ['GargoyleDestroyer'], 754: ['GargoyleEnforcer'], 262: ['TormentedMinotaur']}
SLOTS = {755: {21: 'AirDeath'}, 754: {21: 'AirDeath'}, 262: {15: 'BlockRight', 16: 'BlockLeft'}}
BAKE_INPUTS = ('bake-gargoyle-flight-minotaur-actions.gd', 'bake-frost-through-gargoyle-actions.gd',
               'bake-swamp-widow-juka-actions.gd', 'bake-zombie-actions.gd',
               'bake-troll-actions.gd', 'bake-skeleton-actions.gd')


def source_groups():
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    ledger = runpy.run_path(str(SCRIPTS / 'build-creature-actions.py'))
    source, _, flags = ledger['original_mul_groups'](data, set(CLASSES))
    result = {body: {} for body in CLASSES}
    for row in source:
        body, slot = row['body'], row['group']
        if slot not in SLOTS[body]:
            continue
        assert flags[body][0] == 'MONSTER' and row['layout'] == 'large' and not row['mobtype_prefers_uop']
        directions = row['directions']
        assert [direction['direction'] for direction in directions] == list(range(5))
        digest = hashlib.sha256(''.join(direction['payload_sha256'] for direction in directions).encode()).hexdigest()
        result[body][slot] = dict(body=body, group=slot, archive=row['archive'], graphic=row['graphic'],
                                  frames=[direction['frames'] for direction in directions],
                                  directions=list(range(5)), directional_payload_sha256=digest)
    assert all(result[body].keys() == SLOTS[body].keys() for body in CLASSES)
    return result


def checked_source():
    pins = read(SCRIPTS / 'gargoyle-flight-minotaur-action-pins.json')
    actual = source_groups()
    assert pins == {str(body): {str(slot): proof for slot, proof in groups.items()}
                    for body, groups in actual.items()}
    return pins


def prepared(entries):
    pins = checked_source()
    inputs = {name: sha(SCRIPTS / name) for name in BAKE_INPUTS}
    inputs.update({name: sha(VIEWER / 'Presentation' / name)
                   for name in ('WaterElementalFidgets.gd', 'SourceGroundLookup.gd')})
    rows = []
    for body in CLASSES:
        base, = (row for row in entries if row['status'] == 'validated' and
                 [int(identity['body']) for identity in row['bodies']] == [body])
        if body != 262:
            assert base['classic_gesture_batch'] == 'frost_through_gargoyle_actions'
        before = base['assets']
        assert base['asset_sha256'] == {name: sha(VIEWER / path[6:]) for name, path in before.items()}
        stem = f'gargoyle-flight-minotaur-{body}-actions'
        assets = {name: f'res://local-art/creatures/{stem}-{name}.scn' for name in before}
        scenes = {name: sha(VIEWER / path[6:]) for name, path in assets.items()}
        receipt = read(ART / f'{stem}-bake.json')
        assert receipt['inputs'] == inputs and receipt['scenes'][str(body)] == {
            name: {'source': base['asset_sha256'][name], 'scene': scenes[name]} for name in before}
        groups = SLOTS[body]
        references = pins[str(body)]
        row = dict(base, status='prepared', family=FAMILY, assets=assets,
                   authored_action_scene_sha256=scenes, classic_gesture_base_assets=before,
                   authored_action_reference=references[str(next(iter(groups)))],
                   classic_motion_references=references,
                   classic_action_categories=base.get('classic_action_categories', {}) |
                   {str(slot): clip for slot, clip in groups.items()},
                   new_action_categories=base.get('new_action_categories', {}),
                   native_extra_classic_actions=list(groups),
                   native_constructor_hues=base.get('native_constructor_hues', dict.fromkeys(CLASSES[body], 0)))
        if body != 262:
            row.update(presentation_script=VISUAL, presentation_script_sha256=sha(VIEWER / VISUAL[6:]),
                       authored_replacements=base['authored_replacements'] | {
                           'AirDeath': 'Held folded wings fitted to the seven-frame Classic flight-death group'})
        else:
            retained = read(SCRIPTS / 'tormented-minotaur-inputs.json')['files']
            for clip in ('BlockLeft', 'BlockRight'):
                member = base['clip_sources'][clip]
                assert member in {name.lower() for name in retained}
        rows.append(row)
    return rows, CLASSES


def main():
    selector = runpy.run_path(str(SCRIPTS / 'prepare-creature-fixtures.py'))
    entries = selector['gesture_baseline'](FAMILY, None, CLASSES, layered=True)
    rows, _ = prepared(entries)
    work = ROOT / 'work/creatures' / FAMILY
    work.mkdir(parents=True, exist_ok=True)
    (work / 'prepared-client.json').write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
