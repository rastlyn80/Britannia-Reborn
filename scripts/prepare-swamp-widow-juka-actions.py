"""Prepare four retained rigs against 52 exact Classic groups."""

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
FAMILY = 'swamp_widow_juka_actions'
CLASSES = {794: ['SwampDragon'], 799: ['ScaledSwampDragon'], 157: ['GiantBlackWidow'], 765: ['JukaMage']}
KINDS = {794: 'swamp_dragon', 799: 'swamp_dragon_armor', 157: 'arachnids_spider_black_widow', 765: 'juka_mage'}
SWAMP = dict(enumerate(('Walk', 'Run', 'Idle', 'Eat', 'RaiseHead', 'Attack', 'Attack2', 'Hit', 'Death',
                       'ForwardNeckCheck', 'TailBalance', 'QuietChuff', 'Death')))
CLASSIC = {
    794: SWAMP,
    799: SWAMP,
    157: {0: 'Walk', 1: 'Idle', 2: 'Death', 3: 'Death', 4: 'Attack', 5: 'Attack', 6: 'Attack',
          10: 'Hit', 11: 'Fidget', 15: 'LowBrace', 16: 'LowBrace', 17: 'Fidget', 18: 'AbdomenSignal'},
    765: {0: 'Walk', 1: 'Idle', 2: 'Death', 3: 'Death2', 4: 'Attack', 5: 'Attack2', 6: 'AdvancingPalm',
          10: 'Hit', 11: 'Pillage', 15: 'HighRecoil', 16: 'LowRecoil', 17: 'Fidget', 18: 'JukaGlance'},
}
FITTED = {794: (4, 9, 10, 11), 799: (4, 9, 10, 11), 157: (15, 18), 765: (6, 15, 16, 18)}
ALIASES = {794: [[8, 12]], 799: [[8, 12]], 157: [[2, 3], [4, 5, 6], [11, 17], [15, 16]]}
EXTRA = {794: [0, 1, 2, 4, 6, 7, 8, 10, 12], 799: [0, 1, 2, 4, 6, 7, 8, 10, 12],
         157: [0, 1, 2, 3, 10, 15, 16, 18], 765: [0, 1, 2, 3, 10, 15, 16, 18]}
MODERN = {794: {}, 799: {}, 157: {2: 'LowBrace', 14: 'Fidget'}, 765: {2: 'HighRecoil'}}
BAKE_INPUTS = ('bake-swamp-widow-juka-actions.gd', 'bake-zombie-actions.gd', 'bake-troll-actions.gd',
               'bake-skeleton-actions.gd', 'WaterElementalFidgets.gd', 'SourceGroundLookup.gd')
RENDERERS = {
    794: ('SourceSwampDragonVisual', 'SourceRigMountVisual', 'SourcePreservingCreatureVisual'),
    799: ('SourceSwampDragonVisual', 'SourceRigMountVisual', 'SourcePreservingCreatureVisual'),
    157: ('BlackWidowActionsVisual', 'DreadSpiderActionsVisual', 'VampireBatFallVisual', 'CreatureFallPlayback'),
    765: ('SourceJukaMageActionsVisual', 'SourceJukaVisual', 'SourceMageVisual', 'SourceJukaSupport', 'CreatureModeZeroVariants'),
}


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def source_groups():
    pins = read(SCRIPTS / 'swamp-widow-juka-action-pins.json')
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    assert pins['definitions'] == {name: sha(data / name) for name in ('AnimationSequence.uop', 'mobtypes.txt', 'Bodyconv.def')}
    reader = runpy.run_path(str(SCRIPTS / 'uo-human-sequences.py'))
    ledger = runpy.run_path(str(SCRIPTS / 'build-creature-actions.py'))
    rows, _, flags = ledger['original_mul_groups'](data, set(CLASSES))
    frames, _ = ledger['original_frame_groups'](data, set(CLASSES), type('SequenceReader', (), reader))
    assert not frames, 'Unexpected directly stored canonical UOP groups'
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
        assets = {name: f'res://local-art/creatures/swamp-widow-juka-{body}-actions-{name}.scn' for name in base['asset_sha256']}
        earlier = base.get('assets') or {name: f'res://local-art/creatures/{base["kind"]}-{name}.gltf' for name in assets}
        scenes = {name: sha(VIEWER / path[6:]) for name, path in assets.items()}
        sources = {name: sha(VIEWER / path[6:]) for name, path in earlier.items()}
        assert sources == base['asset_sha256']
        bake = read(ART / f'swamp-widow-juka-{body}-actions-bake.json')
        assert bake['inputs'] == inputs
        assert bake['scenes'][str(body)] == {name: {'source': sources[name], 'scene': scenes[name]} for name in scenes}

        proof = proofs[str(body)]
        references = {str(slot): dict(body=body, group=slot, archive=proof['archive'], graphic=proof['graphic'],
                                      frames=proof['groups'][str(slot)][0][0], directions=list(range(5)),
                                      directional_payload_sha256=proof['groups'][str(slot)][1])
                      for slot in categories}
        dependencies = RENDERERS[body] + ('SourceGroundLookup',)
        renderer = dependencies[0]
        rows.append(dict(base, status='prepared', family=FAMILY, assets=assets,
                         classic_gesture_base_assets=earlier, authored_action_scene_sha256=scenes,
                         authored_action_reference=references[str(FITTED[body][0])],
                         classic_motion_references=references,
                         classic_action_categories=base.get('classic_action_categories', {}) |
                         {str(slot): clip for slot, clip in categories.items()},
                         new_action_categories=base.get('new_action_categories', {}) |
                         {str(kind): clip for kind, clip in MODERN[body].items()},
                         native_extra_classic_actions=EXTRA[body],
                         native_constructor_hues=dict.fromkeys(CLASSES[body], 0x851 if body == 794 else 0),
                         authored_replacements=base.get('authored_replacements', {}) | {
                             categories[slot]: f'Fitted on the retained rig from Classic group {slot}' for slot in FITTED[body]},
                         reviewed_registered_aliases=ALIASES.get(body, []),
                         swamp_widow_juka_sequence_evidence=proof['sequence'],
                         presentation_script=f'res://Presentation/{renderer}.gd',
                         presentation_script_sha256=sha(VIEWER / f'Presentation/{renderer}.gd'),
                         collapse_renderer_dependencies={name: sha(VIEWER / f'Presentation/{name}.gd')
                                                         for name in dependencies}))
    return rows, CLASSES


def check_mounted(rows, path):
    evidence = read(path)
    candidate = (json.dumps(rows, indent=2) + '\n').replace('\n', os.linesep).encode()
    assert evidence['candidate_sha256'] == hashlib.sha256(candidate).hexdigest()
    assert evidence['scene_sha256'] == {
        str(int(row['bodies'][0]['body'])): row['authored_action_scene_sha256']['modern']
        for row in rows if int(row['bodies'][0]['body']) in (794, 799)
    }
    for key, source in (
        ('check_sha256', 'Viewer/Network/SwampDragonActionsMountedLive.gd'),
        ('mount_test_sha256', 'Viewer/Network/OstardLive.gd'),
        ('mount_fixture_sha256', 'Server/HorseIntegrationFixtures/EquineFixtures.cs'),
    ):
        assert evidence[key] == sha(ROOT / source)
    assert evidence['failures'] == 0 and evidence['checks'] >= 594 and len(evidence['records']) == 10
    mounted = {(row['fixture_variant'], row['female'], row['body'], row['mount_item'], row['native_class'])
               for row in evidence['records'] if row['ride_permitted'] and row['fixture_variant'] in (55, 56, 59)}
    assert mounted == {(variant, female, body, item, native_class)
                       for variant, body, item, native_class in ((55, 794, 0x3EBD, 'SwampDragon'),
                                                               (56, 799, 0x3EBE, 'ScaledSwampDragon'),
                                                               (59, 799, 0x3EBE, 'SwampDragon'))
                       for female in (False, True)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--audit-aliases', action='store_true', help='Re-decode every exact shared frame group')
    args = parser.parse_args()
    selector = runpy.run_path(str(SCRIPTS / 'prepare-creature-fixtures.py'))
    baseline = selector['gesture_baseline'](FAMILY, None, CLASSES, layered=True)
    rows, _ = prepared(baseline)
    if args.audit_aliases:
        python = ROOT / '.tools/pyenv/Scripts/python.exe'
        for body, groups in ALIASES.items():
            for group in groups:
                subprocess.run([str(python), '-B', str(SCRIPTS / 'inspect-creature-mul-frames.py'),
                                str(body), '--compare', '--groups', *map(str, group)], check=True)
    output = ROOT / 'work/creatures' / FAMILY / 'prepared-client.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')
    print(f'SWAMP, WIDOW AND JUKA ACTIONS: {sum(map(len, CLASSIC.values()))} frame groups and twelve candidate scenes verified')


if __name__ == '__main__':
    main()
