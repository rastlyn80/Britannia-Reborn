"""Prepare the source-backed actions for Grizzle, Changeling and Matriarch."""

import argparse
import hashlib
import json
from pathlib import Path
import runpy

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'ranked_classic_actions'
CLASSES = {259: ['Ilhenir', 'InterredGrizzle'], 264: ['Changeling'], 72: ['TerathanMatriarch']}
KINDS = {259: 'monstrousinterredgrizzle', 264: 'changling', 72: 'terathan_terathan_queen'}
COMMON = {0: 'Walk', 1: 'Idle', 2: 'Death', 3: 'Death2', 4: 'Attack', 5: 'Attack2', 6: 'Attack3', 10: 'Hit'}
CLASSIC = {
    259: COMMON | {11: 'GrizzleAntlerCheck', 15: 'BlockLeft', 16: 'BlockRight', 17: 'GrizzleBreath', 18: 'Fidget'},
    264: COMMON | {11: 'Pillage', 15: 'BlockLeft', 16: 'BlockRight', 17: 'ChangelingWingRoll', 18: 'Fidget'},
    72: COMMON | {5: 'ForelegThrust', 6: 'PincerOverhead', 11: 'MatriarchDip', 12: 'TerathanCast',
                  13: 'MatriarchBurst', 14: 'Cast2', 15: 'PincerBrace', 16: 'PincerRecoil',
                  17: 'Fidget', 18: 'MandibleTwitch'},
}
FITTED = {259: (17,), 264: (17,), 72: (3, 5, 6, 13, 15, 16, 18)}
MODERN = {0: 4, 2: 15, 3: 2, 4: 10, 14: 11}
BAKE_INPUTS = ('bake-ranked-classic-actions.gd', 'bake-zombie-actions.gd', 'bake-troll-actions.gd',
               'bake-skeleton-actions.gd', 'WaterElementalFidgets.gd', 'SourceGroundLookup.gd')


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def source_groups():
    pins = read(SCRIPTS / 'ranked-classic-action-pins.json')
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    assert pins['definitions'] == {name: sha(data / name) for name in ('AnimationSequence.uop', 'mobtypes.txt', 'Bodyconv.def')}
    reader = runpy.run_path(str(SCRIPTS / 'uo-human-sequences.py'))
    ledger = runpy.run_path(str(SCRIPTS / 'build-creature-actions.py'))
    rows, _, flags = ledger['original_mul_groups'](data, set(CLASSES))
    frames, _ = ledger['original_frame_groups'](data, set(CLASSES), type('SequenceReader', (), reader))
    assert not frames, 'Unexpected canonical UOP payloads for the three Classic bodies'
    for body, categories in CLASSIC.items():
        proof = pins['bodies'][str(body)]
        actual = [row for row in rows if row['body'] == body]
        assert proof['mobtypes'] == list(flags[body])
        assert set(categories) == {row['group'] for row in actual} == set(map(int, proof['groups']))
        for row in actual:
            assert all(row[key] == proof[key] for key in ('archive', 'graphic', 'layout'))
            directions = row['directions']
            assert [item['direction'] for item in directions] == list(range(5))
            hashes = ''.join(item['payload_sha256'] for item in directions).encode('ascii')
            assert proof['groups'][str(row['group'])] == [
                [item['frames'] for item in directions], hashlib.sha256(hashes).hexdigest()]
    records = reader['inspect'](data / 'AnimationSequence.uop', set(CLASSES))
    assert {record['animation_ref'] for record in records} == set(CLASSES)
    for record in records:
        assert not record.get('parse_blocker') and record['unparsed_bytes'] == 0
        proof = pins['bodies'][str(record['animation_ref'])]['sequence']
        assert proof == dict(name_hash=record['uop_name_hash'], modes={
            str(mode['mode']): mode['new_protocol_actions'] for mode in record['modes']})
    return pins['bodies']


def prepared(entries):
    proofs = source_groups()
    inputs = {name: sha((VIEWER / 'Presentation' if name in BAKE_INPUTS[-2:] else SCRIPTS) / name)
              for name in BAKE_INPUTS}
    rows = []
    for body, categories in CLASSIC.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [int(identity['body']) for identity in row['bodies']] == [body])
        assert base['kind'] == KINDS[body]
        assert all(categories[int(slot)] == clip for slot, clip in base.get('classic_action_categories', {}).items())
        bake = read(ART / f'ranked-{body}-actions-bake.json')
        assert bake['inputs'] == inputs
        assets = {name: f'res://local-art/creatures/ranked-{body}-actions-{name}.scn' for name in base['assets']}
        scenes = {name: sha(VIEWER / path[6:]) for name, path in assets.items()}
        sources = {name: sha(VIEWER / path[6:]) for name, path in base['assets'].items()}
        assert sources == base['asset_sha256']
        assert bake['scenes'][str(body)] == {name: {'source': sources[name], 'scene': scenes[name]} for name in scenes}

        proof = proofs[str(body)]
        references = {str(slot): dict(body=body, group=slot, archive=proof['archive'], graphic=proof['graphic'],
                                      frames=proof['groups'][str(slot)][0][0], directions=list(range(5)),
                                      directional_payload_sha256=proof['groups'][str(slot)][1])
                      for slot in categories if slot not in (0, 1)}
        modern = MODERN | ({11: 12} if body == 72 else {})
        mode_zero = {row['type']: row['groups'][0] for row in proof['sequence']['modes']['0'] if row['subaction'] == -1}
        assert all(mode_zero[kind] == slot for kind, slot in modern.items())
        renderer = 'MatriarchActionsVisual' if body == 72 else 'SourcePreservingDistinctActionsVisual'
        parent = 'SourceTerathanMatriarchVisual' if body == 72 else 'SourcePreservingCreatureVisual'
        dependencies = (renderer, parent, 'CreatureModeZeroVariants', 'SourceSpaceFallPlayback',
                        'CreatureFallPlayback', 'SourceGroundLookup')
        rows.append(dict(base, status='prepared', family=FAMILY, assets=assets,
                         classic_gesture_base_assets=base['assets'], authored_action_scene_sha256=scenes,
                         authored_action_reference=references['17' if body != 72 else '13'],
                         classic_motion_references=references,
                         classic_action_categories={str(slot): clip for slot, clip in categories.items()},
                         new_action_categories={str(kind): categories[slot] for kind, slot in modern.items()},
                         native_extra_classic_actions=[2, 3, 10, 15, 16, 18] + ([13] if body == 72 else []),
                         native_constructor_hues=dict.fromkeys(CLASSES[body], 0),
                         grounded_gestures=[categories[slot] for slot in FITTED[body] if slot != 3] if body == 72 else [],
                         authored_replacements=base.get('authored_replacements', {}) | {
                             categories[slot]: f'Fitted on the retained rig from Classic group {slot}' for slot in FITTED[body]},
                         ranked_sequence_evidence=proof['sequence'],
                         presentation_script=f'res://Presentation/{renderer}.gd',
                         presentation_script_sha256=sha(VIEWER / f'Presentation/{renderer}.gd'),
                         collapse_renderer_dependencies={name: sha(VIEWER / f'Presentation/{name}.gd')
                                                         for name in dependencies}))
    return rows, CLASSES


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    selector = runpy.run_path(str(SCRIPTS / 'prepare-creature-fixtures.py'))
    baseline = selector['gesture_baseline'](FAMILY, None, CLASSES, layered=True)
    rows, _ = prepared(baseline)
    output = ROOT / 'work/creatures' / FAMILY / 'prepared-client.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')
    groups = sum(len(categories) for categories in CLASSIC.values())
    print(f'RANKED CLASSIC ACTIONS: {groups} frame groups, three rigs and nine candidate scenes verified')


if __name__ == '__main__':
    main()
