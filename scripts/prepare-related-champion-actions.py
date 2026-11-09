"""Prepare the five related champion action overlays and check their source inputs."""

import hashlib
import json
from pathlib import Path
import runpy


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'scripts'
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'related_champion_actions'
COMMON = runpy.run_path(str(SCRIPTS / 'prepare-post-solen-actions.py'))
read, sha = COMMON['read'], COMMON['sha']
CLASSES = {172: ['Rikktor'], 173: ['Mephitis'], 174: ['Semidar'], 175: ['LordOaks'], 176: ['Silvani']}
SLOTS = {
    172: {6: 'Attack2', 15: 'RikktorShortRecoil', 16: 'RikktorShortRecoil', 18: 'RikktorWingLift'},
    173: {15: 'LowBrace', 16: 'LowBrace', 18: 'AbdomenSignal'},
    174: {15: 'SuccubusWingRecoil', 16: 'SuccubusWingRecoil', 18: 'SuccubusWingLift'},
    175: {6: 'Attack2', 15: 'OaksShortRecoil', 16: 'OaksShortRecoil', 18: 'LatticeWingDisplay'},
    176: {15: 'PixieFlinch', 16: 'PixieFlinch', 18: 'PixieSpiral'},
}
DONORS = {173: 157, 174: 149, 175: 123, 176: 128}
BAKE_INPUTS = ('bake-related-champion-actions.gd', 'related-champion-action-pins.json',
               'bake-banshee-through-queens-actions.gd', 'bake-swamp-widow-juka-actions.gd',
               'bake-zombie-actions.gd', 'bake-troll-actions.gd', 'bake-skeleton-actions.gd')


def checked_source():
    pins = read(SCRIPTS / 'related-champion-action-pins.json')
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    ledger = runpy.run_path(str(SCRIPTS / 'build-creature-actions.py'))
    source, _, flags = ledger['original_mul_groups'](data, set(CLASSES))
    source_rows = {(row['body'], row['group']): row for row in source}
    for body, groups in SLOTS.items():
        slots = set(groups) | ({5} if body in (172, 175) else set())
        proof = pins['source'][str(body)]
        assert flags[body][0] == 'MONSTER' and set(map(int, proof)) == slots
        for group in slots:
            row = source_rows[body, group]
            assert row['layout'] == 'large' and not row['mobtype_prefers_uop']
            directions = row['directions']
            assert [direction['direction'] for direction in directions] == list(range(5))
            digest = hashlib.sha256(''.join(direction['payload_sha256'] for direction in directions).encode()).hexdigest()
            assert proof[str(group)] == dict(body=body, group=group, archive=row['archive'], graphic=row['graphic'],
                                             directions=list(range(5)), frames=[direction['frames'] for direction in directions],
                                             directional_payload_sha256=digest)
    assert {int(body): pin['body'] for body, pin in pins['donors'].items()} == DONORS
    for pin in pins['donors'].values():
        assert pin['sha256'] == {name: sha(VIEWER / path[6:]) for name, path in pin['assets'].items()}
    return pins['source']


def prepared(entries):
    pins = checked_source()
    inputs = {name: sha(SCRIPTS / name) for name in BAKE_INPUTS}
    inputs.update({name: sha(VIEWER / 'Presentation' / name)
                   for name in ('WaterElementalFidgets.gd', 'SourceGroundLookup.gd')})
    rows = []
    for body in CLASSES:
        base, = (row for row in entries if row['status'] == 'validated' and
                 [int(identity['body']) for identity in row['bodies']] == [body])
        before = base['assets']
        hashes = {name: sha(VIEWER / path[6:]) for name, path in before.items()}
        assert hashes == base['asset_sha256']
        stem = f'related-champion-{body}-actions'
        assets = {name: f'res://local-art/creatures/{stem}-{name}.scn' for name in before}
        scenes = {name: sha(VIEWER / path[6:]) for name, path in assets.items()}
        receipt = read(ART / f'{stem}-bake.json')
        assert receipt['inputs'] == inputs and receipt['scenes'][str(body)] == {
            name: {'source': hashes[name], 'scene': scenes[name]} for name in before}
        groups = SLOTS[body]
        references = {str(slot): pins[str(body)][str(slot)] for slot in groups}
        replacements = {}
        for slot in (15, 18):
            clip = groups[slot]
            if clip == 'OaksShortRecoil':
                description = 'Retimed the retained Hit after comparing the three-frame recoil with the four-frame hit'
            elif body in DONORS:
                description = f'Transferred from fitted body {DONORS[body]} with checked bind and source poses'
            else:
                description = f'Fitted to Classic group {slot} on Rikktor’s original rig'
            replacements[clip] = description
        renderer = ('res://Presentation/SourceMephitisActionsVisual.gd' if body == 173
                    else 'res://Presentation/ArchiveGestureVisual.gd')
        row = dict(base, status='prepared', family=FAMILY, assets=assets,
                   authored_action_scene_sha256=scenes, classic_gesture_base_assets=before,
                   authored_action_reference=references['15'],
                   classic_motion_references=references,
                   classic_action_categories=base.get('classic_action_categories', {}) |
                   {str(slot): clip for slot, clip in groups.items()},
                   new_action_categories=base.get('new_action_categories', {}),
                   authored_replacements=base.get('authored_replacements', {}) | replacements,
                   native_extra_classic_actions=[slot for slot in groups if slot != 6],
                   presentation_script=renderer, presentation_script_sha256=sha(VIEWER / renderer[6:]),
                   archive_grounded_gestures=sorted(replacements), archive_align_gesture_slope=True)
        rows.append(row)
    return rows, CLASSES


def main():
    selector = runpy.run_path(str(SCRIPTS / 'prepare-creature-fixtures.py'))
    base = selector['gesture_baseline'](FAMILY, None, CLASSES, layered=True)
    rows, _ = prepared(base)
    work = ROOT / 'work/creatures' / FAMILY
    work.mkdir(parents=True, exist_ok=True)
    (work / 'prepared-client.json').write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
