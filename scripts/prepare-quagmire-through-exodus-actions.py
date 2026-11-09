"""Prepare source-fitted Classic gestures on the next twelve encounter-ranked bodies."""

import hashlib
import json
from pathlib import Path
import runpy


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'scripts'
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'quagmire_through_exodus_actions'
COMMON = runpy.run_path(str(SCRIPTS / 'prepare-post-solen-actions.py'))
read, sha, new_actions = (COMMON[name] for name in ('read', 'sha', 'new_actions'))
CLASSES = {789: ['Quagmire'], 784: ['ArcaneDaemon', 'CrystalDaemon'], 266: ['MLDryad', 'InsaneDryad'], 772: ['MeerEternal'],
           267: ['Troglodyte', 'Lurg'], 304: ['FleshGolem'], 46: ['AncientWyrm'], 757: ['ExodusMinion'],
           756: ['ExodusOverseer'], 252: ['LadyOfTheSnow'], 199: ['RaiJu'], 271: ['Satyr']}
KINDS = {789: 'quagmire', 784: 'arcane_demon', 266: 'dryad', 772: 'npc_adranath', 267: 'troglodyte',
         304: 'flesh_golem', 46: 'dragons_wyrm_ancient', 757: 'clockwork_minion', 756: 'clockwork_overseer',
         252: 'lady_of_the_snow', 199: 'gouzen_ha', 271: 'satyr'}
MONSTER = COMMON['BASE']
SINGLE_FALL = MONSTER | {3: 'Death'}
RECOVERED_BLOCKS = MONSTER | {11: 'Pillage', 15: 'BlockLeft', 16: 'BlockRight'}
CLASSIC = {
    789: SINGLE_FALL | {15: 'QuagmireDrawIn', 16: 'QuagmireDrawIn', 18: 'QuagmireFan'},
    784: SINGLE_FALL | {15: 'ArcaneDaemonBrace', 16: 'ArcaneDaemonBrace'},
    266: RECOVERED_BLOCKS | {18: 'Fidget2'},
    772: SINGLE_FALL | {6: 'Attack2', 15: 'MeerEternalGuard', 16: 'MeerEternalGuard', 18: 'MeerEternalReach'},
    267: RECOVERED_BLOCKS | {18: 'TroglodyteSway'},
    304: SINGLE_FALL | {6: 'Attack2', 15: 'FleshGolemHighGuard', 16: 'FleshGolemHighGuard', 18: 'FleshGolemCheck'},
    46: SINGLE_FALL | {6: 'Attack2', 15: 'AncientWyrmWingBrace', 16: 'AncientWyrmWingBrace', 18: 'AncientWyrmHeadSweep'},
    757: SINGLE_FALL | {6: 'Attack2', 15: 'MinionSpringGuard', 16: 'MinionSpringGuard', 18: 'MinionLeverTest'},
    756: SINGLE_FALL | {15: 'OverseerRetract', 16: 'OverseerRetract', 18: 'OverseerTailCurl'},
    252: MONSTER | {11: 'SnowLadyGather', 15: 'BlockLeft', 16: 'BlockLeft', 18: 'SnowLadyGather'},
    199: RECOVERED_BLOCKS | {18: 'RaiJuCheck'},
    271: RECOVERED_BLOCKS | {18: 'SatyrLean'},
}
FITTED = {789: (15, 18), 784: (15,), 266: (), 772: (15, 18), 267: (18,), 304: (15, 18),
          46: (15, 18), 757: (15, 18), 756: (15, 18), 252: (18,), 199: (18,), 271: (18,)}
GROUND = {266: (15, 16, 18), 267: (15, 16, 18), 252: (15, 18), 199: (15, 16, 18), 271: (15, 16, 18)}
BAKE_INPUTS = ('bake-quagmire-through-exodus-actions.gd', 'bake-lattice-through-meer-actions.gd',
               'bake-frost-through-gargoyle-actions.gd', 'bake-swamp-widow-juka-actions.gd',
               'bake-zombie-actions.gd', 'bake-troll-actions.gd', 'bake-skeleton-actions.gd')
TREATMENTS = ('original', 'rounded', 'modern')


def checked_source():
    pins = read(SCRIPTS / 'quagmire-through-exodus-action-pins.json')
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    assert pins['inputs'] == {name: sha(data / name) for name in ('AnimationSequence.uop', 'Bodyconv.def', 'mobtypes.txt')}
    ledger = runpy.run_path(str(SCRIPTS / 'build-creature-actions.py'))
    raw, _, flags = ledger['original_mul_groups'](data, set(CLASSES))
    reader = runpy.run_path(str(SCRIPTS / 'uo-human-sequences.py'))
    sequence = {row['animation_ref']: row for row in reader['inspect'](data / 'AnimationSequence.uop', set(CLASSES))}
    for body, classic in CLASSIC.items():
        proof = pins['bodies'][str(body)]
        rows = {row['group']: row for row in raw if row['body'] == body}
        assert set(classic) == set(rows) == set(map(int, proof['groups']))
        assert proof['mobtypes'] == list(flags[body]) and proof['sequence_present'] == (body in sequence)
        assert proof['new_actions'] == new_actions(sequence.get(body, {}))
        assert not sequence.get(body, {}).get('parse_blocker')
        for group, row in rows.items():
            assert not row['mobtype_prefers_uop'] and all(row[name] == proof[name] for name in ('archive', 'graphic', 'layout'))
            directions = row['directions']
            assert [direction['direction'] for direction in directions] == list(range(5))
            digest = hashlib.sha256(''.join(item['payload_sha256'] for item in directions).encode('ascii')).hexdigest()
            assert proof['groups'][str(group)] == [[item['frames'] for item in directions], digest]
        for first, second in proof['exact_aliases']:
            assert classic[first] == classic[second], (body, first, second)
    return pins


def prepared(entries):
    pins = checked_source()
    inputs = {name: sha(SCRIPTS / name) for name in BAKE_INPUTS}
    inputs.update({name: sha(VIEWER / 'Presentation' / name) for name in ('WaterElementalFidgets.gd', 'SourceGroundLookup.gd')})
    rows = []
    for body, classes in CLASSES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [int(identity['body']) for identity in row['bodies']] == [body])
        assert base['kind'] == KINDS[body]
        stem = f'quagmire-through-exodus-{body}-actions'
        previous = base.get('assets') or {name: f'res://local-art/creatures/{base["kind"]}-{name}.gltf' for name in TREATMENTS}
        assert set(previous) == set(TREATMENTS)
        source = {name: sha(VIEWER / path[6:]) for name, path in previous.items()}
        expected = base.get('asset_sha256') or {name: value['scene_sha256'] for name, value in base.get('saved_scenes', {}).items()}
        assert source == (expected or pins['ancient_wyrm_base_sha256'] if body == 46 else expected)
        assets = {name: f'res://local-art/creatures/{stem}-{name}.scn' for name in previous}
        scenes = {name: sha(VIEWER / path[6:]) for name, path in assets.items()}
        receipt = read(ART / f'{stem}-bake.json')
        assert receipt['inputs'] == inputs and receipt['scenes'][str(body)] == {
            name: {'source': source[name], 'scene': scenes[name]} for name in assets}
        proof = pins['bodies'][str(body)]
        references = {slot: dict(body=body, group=int(slot), archive=proof['archive'], graphic=proof['graphic'],
                                 frames=frames[0], directions=list(range(5)), directional_payload_sha256=digest)
                      for slot, (frames, digest) in proof['groups'].items()}
        classic = CLASSIC[body]
        renderer = base.get('presentation_script', 'res://Presentation/CreatureVisual.gd')
        renderer = {'OccurrenceCreatureVisual.gd': 'res://Presentation/ArchiveOccurrenceGestureVisual.gd',
                    'CreatureVisual.gd': 'res://Presentation/ArchiveGestureVisual.gd'}.get(Path(renderer).name, renderer)
        authored = {classic[slot]: f'Fitted on the retained rig from {proof["archive"]} group {slot}' for slot in FITTED[body]}
        grounded = sorted({classic[slot] for slot in GROUND.get(body, FITTED[body])})
        extra = [0, 1, 2, 3, 10, 15, 16] + ([] if body == 266 else [18])
        constructor_hues = {name: base.get('native_constructor_hues', {}).get(name, 0) for name in classes}
        if body == 784:
            constructor_hues['CrystalDaemon'] = 0x3E8
        rows.append(dict(base, status='prepared', family=FAMILY, assets=assets, classic_gesture_base_assets=previous,
                         authored_action_scene_sha256=scenes, authored_action_reference=references['15'],
                         classic_motion_references=references, classic_action_categories=base.get('classic_action_categories', {}) |
                         {str(slot): clip for slot, clip in classic.items()}, new_action_categories=base.get('new_action_categories', {}),
                         presentation_script=renderer, presentation_script_sha256=sha(VIEWER / renderer[6:]),
                         authored_replacements=base.get('authored_replacements', {}) | authored,
                         archive_grounded_gestures=grounded, archive_align_gesture_slope=body in (266, 267, 46),
                         native_extra_classic_actions=extra, native_constructor_hues=constructor_hues))
    return rows, CLASSES


def main():
    selector = runpy.run_path(str(SCRIPTS / 'prepare-creature-fixtures.py'))
    rows, _ = prepared(selector['gesture_baseline'](FAMILY, None, CLASSES, layered=True))
    folder = ROOT / 'work/creatures' / FAMILY
    folder.mkdir(parents=True, exist_ok=True)
    (folder / 'prepared-client.json').write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')
    print(f'{len(rows)} bodies and {sum(map(len, CLASSIC.values()))} directly stored Classic groups')


if __name__ == '__main__':
    main()
