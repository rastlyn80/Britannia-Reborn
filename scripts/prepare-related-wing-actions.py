"""Prepare related Gargoyle and Daemon Classic actions from the local source frames."""

import hashlib
import json
from pathlib import Path
import runpy


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'scripts'
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
COMMON = runpy.run_path(str(SCRIPTS / 'prepare-post-solen-actions.py'))
read, sha = COMMON['read'], COMMON['sha']
FAMILIES = {'daemon_kin_wings': {10: ['SummonedDaemon'], 38: ['ServantOfSemidar']},
            'gargoyle_vendor_wings': {758: ['Provisioner']}}
CLASSES = FAMILIES['daemon_kin_wings'] | FAMILIES['gargoyle_vendor_wings']
DAEMON = {6: 'Attack2', 13: 'DaemonWingCanopy', 15: 'DaemonBriefGuard', 16: 'DaemonBriefGuard',
          18: 'DaemonWingFlare', 21: 'AirDeath'}
SLOTS = {10: DAEMON, 38: DAEMON,
         758: {15: 'VendorWingGuard', 16: 'VendorWingGuard', 18: 'VendorHandCheck', 21: 'AirDeath'}}
VISUAL = {10: 'SourceIceFiendActionsVisual.gd', 38: 'SourceIceFiendActionsVisual.gd',
          758: 'SourceGargoyleVendorFlightVisual.gd'}
TREATMENTS = ('original', 'rounded', 'modern')
BAKE_INPUTS = ('bake-related-wing-actions.gd', 'bake-banshee-through-queens-actions.gd',
               'bake-gargoyle-flight-minotaur-actions.gd', 'bake-swamp-widow-juka-actions.gd',
               'bake-zombie-actions.gd', 'bake-troll-actions.gd', 'bake-skeleton-actions.gd')
ALIAS_GROUPS = {10: ((5, 6), (15, 16)), 38: ((5, 6), (15, 16)), 758: ((15, 16),)}


def source_groups():
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    ledger = runpy.run_path(str(SCRIPTS / 'build-creature-actions.py'))
    source, _, flags = ledger['original_mul_groups'](data, set(CLASSES))
    result = {body: {} for body in CLASSES}
    for row in source:
        body, slot = row['body'], row['group']
        required = SLOTS[body].keys() | {group for pair in ALIAS_GROUPS[body] for group in pair}
        if slot not in required:
            continue
        assert flags[body][0] == 'MONSTER' and row['layout'] == 'large' and not row['mobtype_prefers_uop']
        directions = row['directions']
        assert [direction['direction'] for direction in directions] == list(range(5))
        digest = hashlib.sha256(''.join(direction['payload_sha256'] for direction in directions).encode()).hexdigest()
        result[body][slot] = dict(body=body, group=slot, archive=row['archive'], graphic=row['graphic'],
                                  frames=[direction['frames'] for direction in directions],
                                  directions=list(range(5)), directional_payload_sha256=digest)
    for body, aliases in ALIAS_GROUPS.items():
        assert set(SLOTS[body]) <= result[body].keys()
        for a, b in aliases:
            assert result[body][a]['frames'] == result[body][b]['frames']
    return result


def checked_source():
    pins = read(SCRIPTS / 'related-wing-action-pins.json')
    actual = source_groups()
    assert pins == {str(body): {str(slot): proof for slot, proof in groups.items()}
                    for body, groups in actual.items()}
    return pins


def prepared(family, entries):
    pins = checked_source()
    inputs = {name: sha(SCRIPTS / name) for name in BAKE_INPUTS}
    inputs.update({name: sha(VIEWER / 'Presentation' / name)
                   for name in ('WaterElementalFidgets.gd', 'SourceGroundLookup.gd')})
    rows = []
    classes = FAMILIES[family]
    for body in classes:
        base, = (row for row in entries if row['status'] == 'validated' and
                 [int(identity['body']) for identity in row['bodies']] == [body])
        before = base.get('assets') or {name: f'res://local-art/creatures/{base["kind"]}-{name}.gltf'
                                        for name in TREATMENTS}
        base_hashes = {name: sha(VIEWER / path[6:]) for name, path in before.items()}
        expected = base.get('asset_sha256') or {name: row['scene_sha256'] for name, row in base['saved_scenes'].items()}
        assert base_hashes == expected
        stem = f'vendor-daemon-wing-{body}-actions'
        assets = {name: f'res://local-art/creatures/{stem}-{name}.scn' for name in before}
        scenes = {name: sha(VIEWER / path[6:]) for name, path in assets.items()}
        receipt = read(ART / f'{stem}-bake.json')
        assert receipt['inputs'] == inputs and receipt['scenes'][str(body)] == {
            name: {'source': base_hashes[name], 'scene': scenes[name]} for name in before}
        groups = SLOTS[body]
        references = {str(slot): pins[str(body)][str(slot)] for slot in groups}
        replacements = {clip: f'Fitted on the retained rig from Classic group {slot}' for slot, clip in groups.items()
                        if slot not in (6, 16)}
        grounded = sorted(set(replacements) - {'AirDeath'})
        renderer = 'res://Presentation/' + VISUAL[body]
        row = dict(base, status='prepared', family=family, assets=assets,
                   authored_action_scene_sha256=scenes, classic_gesture_base_assets=before,
                   authored_action_reference=references['15'],
                   classic_motion_references=references,
                   classic_action_categories=base.get('classic_action_categories', {}) |
                   {str(slot): clip for slot, clip in groups.items()},
                   new_action_categories=base.get('new_action_categories', {}),
                   authored_replacements=base.get('authored_replacements', {}) | replacements,
                   native_extra_classic_actions=[slot for slot in groups if slot != 6],
                   presentation_script=renderer, presentation_script_sha256=sha(VIEWER / renderer[6:]),
                   archive_grounded_gestures=grounded, archive_align_gesture_slope=True,
                   native_constructor_hues=base.get('native_constructor_hues', dict.fromkeys(classes[body], 0)))
        rows.append(row)
    return rows, classes


def main():
    selector = runpy.run_path(str(SCRIPTS / 'prepare-creature-fixtures.py'))
    for family, classes in FAMILIES.items():
        base = selector['gesture_baseline'](family, None, classes, layered=True)
        rows, _ = prepared(family, base)
        work = ROOT / 'work/creatures' / family
        work.mkdir(parents=True, exist_ok=True)
        (work / 'prepared-client.json').write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
