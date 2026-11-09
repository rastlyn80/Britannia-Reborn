"""Prepare the next source-backed Classic creature actions in encounter order."""

import hashlib
import json
from pathlib import Path
import runpy


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'scripts'
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'post_solen_actions'
CLASSES = {248: ['Gaman'], 303: ['Devourer'], 251: ['RevenantLion'], 787: ['AntLion'],
           300: ['CrystalElemental'], 263: ['Minotaur'], 253: ['YomotsuPriest'], 305: ['GoreFiend']}
KINDS = {248: 'wild_guar', 303: 'devourer', 251: 'vampyric_beast', 787: 'ant_lion', 300: 'crystal_elemental',
         263: 'minotaur', 253: 'yomotsu_priest', 305: 'gore_fiend'}
BASE = {0: 'Walk', 1: 'Idle', 2: 'Death', 3: 'Death2', 4: 'Attack', 5: 'Attack2',
        6: 'Attack3', 10: 'Hit', 11: 'Fidget', 15: 'Hit', 16: 'Hit', 17: 'Fidget', 18: 'Fidget'}
GAMAN = {0: 'Walk', 1: 'Run', 2: 'Idle', 3: 'Eat', 4: 'Alert', 5: 'Attack',
         6: 'Attack2', 7: 'Hit', 8: 'Death', 9: 'Fidget', 10: 'GamanLowGuard',
         11: 'LieDown', 12: 'Death2'}
OVERRIDES = {
    303: {3: 'Death', 6: 'Attack2', 11: 'DevourerMouthCheck', 15: 'DevourerBrace',
          16: 'DevourerBrace', 18: 'DevourerBellow'},
    251: {11: 'LionScent', 15: 'BlockLeft', 16: 'BlockLeft', 18: 'LionScent'},
    787: {3: 'Death', 15: 'AntLionCrouch', 16: 'AntLionCrouch', 18: 'Fidget2'},
    300: {3: 'Death', 6: 'Attack2', 15: 'CrystalHunch', 16: 'CrystalHunch', 18: 'CrystalRattle'},
    263: {11: 'Pillage', 15: 'BlockLeft', 16: 'BlockRight', 18: 'MinotaurCheck'},
    253: {11: 'YomotsuStaffSweep', 15: 'BlockLeft', 16: 'BlockLeft', 18: 'YomotsuStaffSweep'},
    305: {3: 'Death', 15: 'GoreFiendCurl', 16: 'GoreFiendCurl', 18: 'GoreFiendHeadRaise'},
}
FITTED = {248: (10,), 303: (15, 18), 251: (11,), 787: (15,), 300: (15, 18), 263: (18,), 253: (11,), 305: (15, 18)}
BAKE_INPUTS = ('bake-post-solen-actions.gd', 'bake-swamp-widow-juka-actions.gd',
               'bake-zombie-actions.gd', 'bake-troll-actions.gd', 'bake-skeleton-actions.gd')


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def new_actions(sequence):
    return {str(row['type']): row['groups'] for mode in sequence.get('modes', []) if mode['mode'] == 0
            for row in mode['new_protocol_actions'] if row['subaction'] == -1}


def checked_source():
    pins = read(SCRIPTS / 'post-solen-classic-action-pins.json')
    config = read(ROOT / 'Server/runtime/Configuration/modernuo.json')
    data = Path(config['dataDirectories'][0])
    assert pins['inputs'] == {name: sha(data / name) for name in ('AnimationSequence.uop', 'Bodyconv.def', 'mobtypes.txt')}
    ledger = runpy.run_path(str(SCRIPTS / 'build-creature-actions.py'))
    raw, _, flags = ledger['original_mul_groups'](data, set(CLASSES))
    reader = runpy.run_path(str(SCRIPTS / 'uo-human-sequences.py'))
    sequence = {row['animation_ref']: row for row in reader['inspect'](data / 'AnimationSequence.uop', set(CLASSES))}
    assert set(sequence) == set(CLASSES) - {253}
    for body in CLASSES:
        proof = pins['bodies'][str(body)]
        assert list(flags[body]) == proof['mobtypes']
        assert proof['sequence_present'] == (body in sequence)
        assert proof['new_actions'] == new_actions(sequence.get(body, {}))
        rows = [row for row in raw if row['body'] == body]
        slots = GAMAN if body == 248 else BASE
        assert {row['group'] for row in rows} == set(slots) == set(map(int, proof['groups']))
        for row in rows:
            assert all(row[name] == proof[name] for name in ('archive', 'graphic', 'layout'))
            directions = row['directions']
            assert [item['direction'] for item in directions] == list(range(5))
            digest = hashlib.sha256(''.join(item['payload_sha256'] for item in directions).encode('ascii')).hexdigest()
            assert proof['groups'][str(row['group'])] == [[item['frames'] for item in directions], digest]
    return pins['bodies']


def prepared(entries):
    pins = checked_source()
    inputs = {name: sha(SCRIPTS / name) for name in BAKE_INPUTS}
    inputs.update({name: sha(VIEWER / 'Presentation' / name)
                   for name in ('WaterElementalFidgets.gd', 'SourceGroundLookup.gd')})
    rows = []
    for body, classes in CLASSES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [int(identity['body']) for identity in row['bodies']] == [body])
        assert base['kind'] == KINDS[body]
        before = base['assets']
        assert set(before) == {'original', 'rounded', 'modern'}
        assets = {name: f'res://local-art/creatures/post-solen-{body}-actions-{name}.scn' for name in before}
        source_hash = {name: sha(VIEWER / path[6:]) for name, path in before.items()}
        expected_hash = base.get('asset_sha256') or {
            name: scene['scene_sha256'] for name, scene in base['saved_scenes'].items()}
        assert source_hash == expected_hash
        scenes = {name: sha(VIEWER / path[6:]) for name, path in assets.items()}
        receipt = read(ART / f'post-solen-{body}-actions-bake.json')
        bake_inputs = inputs
        if body == 248:
            bake_inputs = {name: digest for name, digest in inputs.items() if name != BAKE_INPUTS[0]}
            bake_inputs['bake-gaman-low-guard.gd'] = sha(SCRIPTS / 'bake-gaman-low-guard.gd')
        assert receipt['inputs'] == bake_inputs and receipt['scenes'][str(body)] == {
            name: {'source': source_hash[name], 'scene': scenes[name]} for name in scenes}
        proof = pins[str(body)]
        classic = GAMAN if body == 248 else BASE | OVERRIDES[body]
        for a, b in proof['exact_aliases'] + proof['same_silhouette']:
            assert classic[a] == classic[b], (body, a, b)
        references = {}
        for slot in classic:
            frames, digest = proof['groups'][str(slot)]
            references[str(slot)] = dict(body=body, group=slot, archive=proof['archive'], graphic=proof['graphic'],
                                         frames=frames[0], directions=list(range(5)), directional_payload_sha256=digest)
        modern = base.get('new_action_categories', {})
        if body != 248:
            modern = {kind: classic[groups[0]] for kind, groups in proof['new_actions'].items()
                      if kind in {'0', '2', '3', '4', '14'} and groups[0] in classic} | modern
            if proof['new_actions'].get('11') == [4, 4, 4] and '11' not in modern:
                modern['11'] = 'Attack'
        authored = {classic[group]: f'Fitted on the retained rig from {proof["archive"]} group {group}'
                    for group in FITTED[body]}
        renderer = ('SourcePreservingCreatureVisual' if body in (248, 787) else
                    'ArchiveOccurrenceGestureVisual' if body in (303, 251) else 'ArchiveGestureVisual')
        grounded = set(authored) if body not in (248, 787) else set()
        if body in (251, 263, 253):
            grounded.update((classic[15], classic[16]))
        dependencies = [renderer, 'SourceGroundLookup']
        if body not in (248, 787):
            dependencies.append('ArchiveGestureGround')
        extra = [0, 1, 2, 4, 6, 7, 8, 10, 12] if body == 248 else [0, 1, 2, 3, 10, 15, 16]
        if body not in (248, 787):
            extra.append(18)
        row = dict(base, family=FAMILY, status='prepared', assets=assets,
                   classic_gesture_base_assets=before, authored_action_scene_sha256=scenes,
                   authored_action_reference=references['10' if body == 248 else '15'],
                   classic_motion_references=references,
                   classic_action_categories=base.get('classic_action_categories', {}) |
                                             {str(slot): clip for slot, clip in classic.items()},
                   new_action_categories=modern, native_constructor_hues=dict.fromkeys(classes, 0),
                   authored_replacements=base.get('authored_replacements', {}) | authored,
                   native_extra_classic_actions=extra,
                   presentation_script=f'res://Presentation/{renderer}.gd',
                   presentation_script_sha256=sha(VIEWER / f'Presentation/{renderer}.gd'),
                   archive_grounded_gestures=sorted(grounded), archive_align_gesture_slope=body in (251, 300),
                   collapse_renderer_dependencies=base.get('collapse_renderer_dependencies', {}) | {
                       name: sha(VIEWER / f'Presentation/{name}.gd') for name in dependencies})
        rows.append(row)
    return rows, CLASSES


def main():
    selector = runpy.run_path(str(SCRIPTS / 'prepare-creature-fixtures.py'))
    base = selector['gesture_baseline'](FAMILY, None, CLASSES, layered=True)
    rows, _ = prepared(base)
    target = ROOT / 'work/creatures' / FAMILY / 'prepared-client.json'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')
    print('POST-SOLEN ACTIONS: 104 directly stored Classic groups verified for eight bodies')


if __name__ == '__main__':
    main()
