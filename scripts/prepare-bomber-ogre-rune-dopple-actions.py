"""Prepare Orc Bomber, Ogre Lord, Rune Beetle and Doppleganger actions."""

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
FAMILY = 'bomber_ogre_rune_dopple_actions'
CLASSES = {182: ['OrcBomber'], 83: ['OgreLord'], 244: ['RuneBeetle'], 777: ['Doppleganger']}
KINDS = {182: 'orcs_orc_bomber', 83: 'ogres_ogre_lord', 244: 'rune_beetle', 777: 'doppleganger'}
BASE = {0: 'Walk', 1: 'Idle', 2: 'Death', 3: 'Death2', 4: 'Attack', 5: 'Attack2',
        6: 'Attack3', 10: 'Hit', 11: 'Fidget', 17: 'Fidget'}
CLASSIC = {
    182: BASE | {3: 'Death', 5: 'Attack', 6: 'Attack', 15: 'OrcBomberBrace', 16: 'OrcBomberBrace', 18: 'OrcBomberScan'},
    83: BASE | {4: 'OverheadHammer', 5: 'Attack', 6: 'HighUppercut', 11: 'FaceWipe',
                15: 'ShoulderTurn', 16: 'ChestBrace', 18: 'ShoulderScratch'},
    244: BASE | {11: 'RuneCrestProbe', 15: 'BlockLeft', 16: 'BlockRight', 18: 'RuneCrestProbe'},
    777: BASE | {5: 'Attack', 6: 'Attack', 15: 'DopplegangerRecoil', 16: 'DopplegangerRecoil', 18: 'DopplegangerReach'},
}
FITTED = {182: (15, 18), 83: (3, 4, 6, 11, 15, 16, 18), 244: (11,), 777: (15, 18)}
ALIASES = {182: [[2, 3], [4, 5, 6], [11, 17], [15, 16]], 244: [[11, 18]],
           777: [[4, 5, 6], [11, 17], [15, 16]]}
NEW = {0: 4, 2: 15, 3: 2, 4: 10, 14: 11}
COMMON_INPUTS = ('bake-troll-actions.gd', 'bake-skeleton-actions.gd', 'WaterElementalFidgets.gd', 'SourceGroundLookup.gd')
BAKE = ('bake-bomber-rune-dopple-actions.gd', 'bake-swamp-widow-juka-actions.gd', 'bake-zombie-actions.gd') + COMMON_INPUTS
OGRE_BAKE = ('bake-ogre-lord-actions.gd', 'bake-serpent-ogre-actions.gd') + COMMON_INPUTS
RENDERERS = {
    182: ('OrcBomberActionsVisual', 'SourcePreservingCreatureVisual', 'CreatureEffectPresenter', 'EffectPresenter'),
    83: ('OgreLordActionsVisual', 'SourceQuadrupedCollapseVisual', 'FieldClassicCollapseVisual', 'CreatureGesturePlaneSupport',
         'CreatureModeZeroVariants'),
    244: ('RuneBeetleActionsVisual', 'RuneBeetleVisual', 'OccurrenceCreatureVisual', 'CreatureGesturePlaneSupport',
          'CreatureModeZeroVariants'),
    777: ('SourcePreservingDistinctActionsVisual', 'SourcePreservingCreatureVisual', 'CreatureModeZeroVariants',
          'SourceSpaceFallPlayback', 'CreatureFallPlayback'),
}


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def source_groups():
    pins = read(SCRIPTS / 'bomber-ogre-rune-dopple-action-pins.json')
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    assert pins['definitions'] == {name: sha(data / name) for name in
                                   ('AnimationSequence.uop', 'mobtypes.txt', 'Bodyconv.def', 'Body.def', 'Corpse.def')}
    bodies = set(CLASSES) | {1, 84}
    reader = runpy.run_path(str(SCRIPTS / 'uo-human-sequences.py'))
    ledger = runpy.run_path(str(SCRIPTS / 'build-creature-actions.py'))
    rows, _, flags = ledger['original_mul_groups'](data, bodies)
    frames, _ = ledger['original_frame_groups'](data, bodies, type('SequenceReader', (), reader))
    assert not frames
    redirects, _ = ledger['original_definition_redirects'](data, {83, 84}, rows, set())
    assert {(row['body'], row['scope'], row['graphic'], row['legacy_hue'],
             row['source_indexed_frames'], row['target_indexed_frames']) for row in redirects} == {
        (body, scope, 1, 0, False, True) for body in (83, 84) for scope in ('mobile', 'corpse')}
    for body in bodies:
        proof = pins['bodies'][str(body)]
        actual = [row for row in rows if row['body'] == body]
        assert proof['mobtypes'] == list(flags[body])
        groups = set() if body in (83, 84) else set(CLASSIC[83 if body == 1 else body])
        assert groups == {row['group'] for row in actual} == set(map(int, proof['groups']))
        for row in actual:
            assert all(row[key] == proof[key] for key in ('archive', 'graphic', 'layout'))
            directions = row['directions']
            assert [item['direction'] for item in directions] == list(range(5))
            hashes = ''.join(item['payload_sha256'] for item in directions).encode('ascii')
            assert proof['groups'][str(row['group'])] == [
                [item['frames'] for item in directions], hashlib.sha256(hashes).hexdigest()]
    records = reader['inspect'](data / 'AnimationSequence.uop', bodies)
    assert {record['animation_ref'] for record in records} == bodies
    for record in records:
        assert not record.get('parse_blocker') and record['unparsed_bytes'] == 0
        proof = pins['bodies'][str(record['animation_ref'])]['sequence']
        assert proof == dict(name_hash=record['uop_name_hash'], modes={
            str(mode['mode']): mode['new_protocol_actions'] for mode in record['modes']})
    return pins['bodies']


def prepared(entries):
    proofs = source_groups()
    rows = []
    for body, categories in CLASSIC.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and any(int(identity['body']) == body for identity in row['bodies']))
        assert base['kind'] == KINDS[body]
        identity, = (entry for entry in base['bodies'] if int(entry['body']) == body)
        assert len(base['bodies']) == (2 if body == 83 else 1)
        prefix = 'ogre-lord' if body == 83 else f'bomber-rune-dopple-{body}'
        assets = {name: f'res://local-art/creatures/{prefix}-actions-{name}.scn' for name in base['asset_sha256']}
        earlier = base.get('assets') or {name: f'res://local-art/creatures/{base["kind"]}-{name}.gltf' for name in assets}
        scenes = {name: sha(VIEWER / path[6:]) for name, path in assets.items()}
        sources = {name: sha(VIEWER / path[6:]) for name, path in earlier.items()}
        assert sources == base['asset_sha256']
        inputs = {name: sha((VIEWER / 'Presentation' if name in COMMON_INPUTS[-2:] else SCRIPTS) / name)
                  for name in (OGRE_BAKE if body == 83 else BAKE)}
        bake = read(ART / f'{prefix}-actions-bake.json')
        assert bake['inputs'] == inputs
        assert bake['scenes'][str(body)] == {name: {'source': sources[name], 'scene': scenes[name]} for name in scenes}

        source_body = 1 if body == 83 else body
        proof = proofs[str(source_body)]
        references = {str(slot): dict(body=body, source_body=source_body, group=slot, archive=proof['archive'],
                                      graphic=proof['graphic'], frames=proof['groups'][str(slot)][0][0],
                                      directions=list(range(5)), directional_payload_sha256=proof['groups'][str(slot)][1])
                      for slot in categories}
        modern = NEW if body != 244 else {0: 4, 3: 2, 4: 10}
        sequence = proofs[str(body)]['sequence']
        mode_zero = {row['type']: row['groups'][0] for row in sequence['modes']['0'] if row['subaction'] == -1}
        assert all(mode_zero[kind] == slot for kind, slot in modern.items())
        dependencies = RENDERERS[body] + ('SourceGroundLookup',)
        renderer = dependencies[0]
        replacements = {categories[slot]: f'Fitted on the retained rig from Classic group {slot}' for slot in FITTED[body]}
        if body == 182:
            replacements['BombFollowThrough'] = 'Authored follow-through on the native bomb projectile event'
        rows.append(dict(base, status='prepared', family=FAMILY, bodies=[identity], assets=assets,
                         classic_gesture_base_assets=earlier, authored_action_scene_sha256=scenes,
                         authored_action_reference=references[str(FITTED[body][0])],
                         classic_motion_references=references,
                         classic_action_categories=base.get('classic_action_categories', {}) |
                         {str(slot): clip for slot, clip in categories.items()},
                         new_action_categories=base.get('new_action_categories', {}) |
                         {str(kind): categories[slot] for kind, slot in modern.items()},
                         native_extra_classic_actions=[0, 1, 2, 3, 10, 15, 16, 18],
                         native_constructor_hues=dict.fromkeys(CLASSES[body], 0),
                         authored_replacements=base.get('authored_replacements', {}) | replacements,
                         reviewed_registered_aliases=ALIASES.get(body, []),
                         bomber_ogre_rune_dopple_sequence_evidence=sequence,
                         presentation_script=f'res://Presentation/{renderer}.gd',
                         presentation_script_sha256=sha(VIEWER / f'Presentation/{renderer}.gd'),
                         collapse_renderer_dependencies={name: sha(VIEWER / f'Presentation/{name}.gd')
                                                         for name in dependencies}))
    return rows, CLASSES


def check_bomb(rows, folder, fixture=None):
    report = folder / 'bomb.json'
    evidence = read(report)
    runtime = read(folder / 'bomb-runtime.json')
    candidate = (json.dumps(rows, indent=2) + '\n').replace('\n', os.linesep).encode()
    assert evidence['candidate_sha256'] == hashlib.sha256(candidate).hexdigest()
    bomber, = (row for row in rows if int(row['bodies'][0]['body']) == 182)
    assert evidence['scene_sha256'] == bomber['authored_action_scene_sha256']
    for key, path in (
        ('check_sha256', 'Viewer/Network/OrcBombLive.gd'),
        ('presenter_sha256', 'Viewer/Presentation/CreatureEffectPresenter.gd'),
        ('renderer_sha256', 'Viewer/Presentation/OrcBomberActionsVisual.gd'),
        ('native_sha256', 'Server/ModernUO/Projects/UOContent/Mobiles/Monsters/Humanoid/Melee/OrcBomber.cs'),
    ):
        assert evidence[key] == sha(ROOT / path)
    fixture = fixture or ROOT / 'Server/HorseIntegrationFixtures/OrcBombFixtures.cs'
    assert runtime['report_sha256'] == sha(report) and runtime['fixture_sha256'] == sha(fixture)
    assert len(runtime['fixture_assembly_sha256']) == 64 and len(runtime['server_content_sha256']) == 64
    assert evidence['body'] == 182 and evidence['animation_packets'] == [0, 0]
    assert evidence['hits_before'] > evidence['hits_after'] > 0
    clients = evidence['client_effects']
    assert set(clients) == {'0', '1'} and clients['0'] == clients['1']
    packet = clients['0']
    assert packet['kind'] == 'moving' and packet['graphic'] == 0x1C19 and packet['explodes']
    assert (packet['speed'], packet['duration']) == (1, 0) and packet['source'] != packet['target']
    if 'tile' in packet:
        assert (packet['tile'], packet['explode_effect'], packet['explode_sound']) == (9502, 6014, 0x11D)


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
    print(f'BOMBER, OGRE LORD, RUNE BEETLE AND DOPPLEGANGER: {sum(map(len, CLASSIC.values()))} source groups and twelve candidate scenes')


if __name__ == '__main__':
    main()
