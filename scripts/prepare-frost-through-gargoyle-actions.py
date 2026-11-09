"""Prepare encounter-ranked Classic actions and the Fire Gargoyle's UOP actions."""

import hashlib
import json
from pathlib import Path
import runpy


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'scripts'
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'frost_through_gargoyle_actions'
COMMON = runpy.run_path(str(SCRIPTS / 'prepare-post-solen-actions.py'))
read, sha, new_actions = (COMMON[name] for name in ('read', 'sha', 'new_actions'))
CLASSES = {20: ['FrostSpider'], 792: ['ChaosDaemon'], 771: ['MeerWarrior'], 265: ['Hydra', 'Abscess'],
           281: ['MinotaurScout'], 130: ['FireGargoyle'], 755: ['GargoyleDestroyer'], 754: ['GargoyleEnforcer']}
KINDS = {20: 'arachnids_spider_frost', 792: 'chaos_demon', 771: 'meer_warrior', 265: 'hydra',
         281: 'leatherminotaur', 130: 'gargoyles_gargoyle_blistering',
         755: 'gargoyles_gargoyle_guard', 754: 'gargoyles_gargoyle_enforcer'}
BASE = COMMON['BASE']
GARGOYLE = {3: 'Death', 5: 'Attack', 6: 'Attack', 15: 'GargoyleWingGuard', 16: 'GargoyleWingGuard',
            18: 'GargoyleGuardLook', 19: 'Fly', 20: 'Land', 21: 'Death'}
CLASSIC = {
    20: BASE | {3: 'Death', 5: 'Attack', 6: 'Attack', 15: 'LowBrace', 16: 'LowBrace', 18: 'AbdomenSignal'},
    792: BASE | {3: 'Death', 15: 'ChaosDemonGuard', 16: 'ChaosDemonGuard', 18: 'ChaosDemonScan'},
    771: BASE | {6: 'MeerBackhand', 15: 'MeerGuard', 16: 'MeerGuard', 18: 'MeerLook'},
    265: BASE | {11: 'Pillage', 15: 'BlockLeft', 16: 'BlockLeft', 18: 'Fidget2'},
    281: BASE | {11: 'Pillage', 15: 'BlockLeft', 16: 'BlockRight', 18: 'ScoutShieldCheck'},
    755: BASE | GARGOYLE,
    754: BASE | GARGOYLE,
}
FIRE = {0: 'Walk', 1: 'Idle', 2: 'Death', 3: 'Death2', 4: 'Attack', 5: 'FireGargoyleLunge',
        10: 'Hit', 11: 'Pillage', 15: 'FireGargoyleGuard', 22: 'FireGargoylePeaceWalk',
        23: 'FireGargoyleRise', 24: 'Run', 25: 'ReadyStance', 26: 'FireGargoyleRest',
        27: 'FireGargoyleFlare', 28: 'FireGargoyleRecoil'}
FIRE_NEW = {0: 4, 2: 15, 3: 2, 4: 10, 5: 26, 8: 28, 11: 4, 14: 11, 15: 23}
FITTED = {20: (15, 18), 792: (15, 18), 771: (6, 15, 18), 265: (), 281: (18,),
          130: (3, 5, 15, 22, 23, 25, 26, 27, 28), 755: (15, 18), 754: (15, 18)}
RENDERER = {20: 'BlackWidowActionsVisual', 771: 'ArchiveOccurrenceGestureVisual',
            265: 'ArchiveGestureVisual', 281: 'ArchiveGestureVisual', 130: 'FireGargoyleUopVisual'}
BAKE_INPUTS = ('bake-swamp-widow-juka-actions.gd', 'bake-zombie-actions.gd',
               'bake-troll-actions.gd', 'bake-skeleton-actions.gd')
HUES = {'Abscess': 0x8FD}


def check_source():
    pins = read(SCRIPTS / 'frost-through-gargoyle-action-pins.json')
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    assert pins['inputs'] == {name: sha(data / name) for name in pins['inputs']}
    catalogue = runpy.run_path(str(SCRIPTS / 'build-creature-actions.py'))
    raw, _, flags = catalogue['original_mul_groups'](data, set(CLASSES))
    reader = runpy.run_path(str(SCRIPTS / 'uo-human-sequences.py'))
    sequence = {row['animation_ref']: row for row in reader['inspect'](data / 'AnimationSequence.uop', set(CLASSES))}
    for body, actions in CLASSIC.items():
        proof = pins['classic'][str(body)]
        rows = [row for row in raw if row['body'] == body]
        assert set(actions) == {row['group'] for row in rows} == set(map(int, proof['groups']))
        assert list(flags[body]) == proof['mobtypes']
        assert (body in sequence) == proof['sequence_present']
        assert proof['new_actions'] == new_actions(sequence.get(body, {}))
        for row in rows:
            assert all(row[name] == proof[name] for name in ('archive', 'graphic', 'layout'))
            directions = row['directions']
            assert [item['direction'] for item in directions] == list(range(5))
            digest = hashlib.sha256(''.join(item['payload_sha256'] for item in directions).encode('ascii')).hexdigest()
            assert proof['groups'][str(row['group'])] == [[item['frames'] for item in directions], digest]
        for a, b in proof['exact_aliases'] + proof['same_silhouette']:
            # Chaos has two distinct recovered 3D clips for the identical
            # original strike and hit pixels. Retain both existing actions.
            if (body, a, b) != (792, 4, 10):
                assert actions[a] == actions[b], (body, a, b)
    body = 130
    proof = pins['uop'][str(body)]
    uop, _ = catalogue['original_frame_groups'](data, {body}, type('Reader', (), reader))
    assert list(flags[body]) == proof['mobtypes'] == ['MONSTER', 0x10000]
    assert sequence[body] == proof['sequence'] and not sequence[body].get('parse_blocker')
    assert all(row['archive'] == 'AnimationFrame1.uop' and row['frame_headers'] % 5 == 0 for row in uop)
    assert proof['groups'] == {str(row['group']): [row['frame_headers'], row['payload_sha256']] for row in uop}
    assert set(map(int, proof['groups'])) == set(FIRE)
    return pins


def routes(body, base, pins):
    if body == 130:
        proof = pins['uop'][str(body)]
        redirects = {item['old_group']: item['new_group'] for item in proof['sequence']['replacements']
                     if not item['frame_count']}
        wire_groups = {slot: redirects.get(slot, slot) for slot in range(22)}
        references = {}
        for slot, group in wire_groups.items():
            count, digest = proof['groups'][str(group)]
            references[str(slot)] = dict(body=body, group=slot, uop_group=group, archive='AnimationFrame1.uop',
                                         frame_headers=count, payload_sha256=digest)
        return ({str(slot): FIRE[group] for slot, group in wire_groups.items()}, references,
                {str(kind): FIRE[group] for kind, group in FIRE_NEW.items()})
    proof = pins['classic'][str(body)]
    clips = CLASSIC[body]
    references = {}
    for slot in clips:
        frames, digest = proof['groups'][str(slot)]
        references[str(slot)] = dict(body=body, group=slot, archive=proof['archive'], graphic=proof['graphic'],
                                     frames=frames[0], directions=list(range(5)), directional_payload_sha256=digest)
    modern = {kind: clips[groups[0]] for kind, groups in proof['new_actions'].items()
              if kind in {'0', '2', '3', '4', '14'} and groups[0] in clips}
    return {str(slot): clip for slot, clip in clips.items()}, references, modern | base.get('new_action_categories', {})


def baked(body, base):
    earlier = base.get('assets') or {name: f'res://local-art/creatures/{base["kind"]}-{name}.gltf'
                                     for name in base['asset_sha256']}
    original_hashes = {name: sha(VIEWER / path[6:]) for name, path in earlier.items()}
    assert original_hashes == base['asset_sha256']
    prefix = 'fire-gargoyle-uop' if body == 130 else f'frost-through-gargoyle-{body}'
    recipe = 'bake-fire-gargoyle-uop-actions.gd' if body == 130 else 'bake-frost-through-gargoyle-actions.gd'
    inputs = (recipe,) + BAKE_INPUTS
    if body == 130:
        inputs += ('bake-raptor-uop-actions.gd',)
    inputs = {name: sha(SCRIPTS / name) for name in inputs}
    inputs.update({name: sha(VIEWER / 'Presentation' / name)
                   for name in ('WaterElementalFidgets.gd', 'SourceGroundLookup.gd')})
    assets = {name: f'res://local-art/creatures/{prefix}-actions-{name}.scn' for name in earlier}
    scenes = {name: sha(VIEWER / path[6:]) for name, path in assets.items()}
    receipt = read(ART / f'{prefix}-actions-bake.json')
    assert receipt['inputs'] == inputs and receipt['scenes'][str(body)] == {
        name: {'source': original_hashes[name], 'scene': scenes[name]} for name in scenes}
    return earlier, assets, scenes


def prepared(entries):
    pins = check_source()
    rows = []
    for body, classes in CLASSES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [int(identity['body']) for identity in row['bodies']] == [body])
        assert base['kind'] == KINDS[body]
        earlier, assets, scenes = baked(body, base)
        classic, references, modern = routes(body, base, pins)
        clips = FIRE if body == 130 else CLASSIC[body]
        renderer = RENDERER.get(body, 'SourcePreservingCreatureVisual')
        authored = {clips[group]: f'Fitted on the retained rig from original group {group}' for group in FITTED[body]}
        grounded = sorted(set(authored) - {'Death2'})
        if body == 265:
            grounded = ['BlockLeft']
        elif body == 281:
            grounded.extend(('BlockLeft', 'BlockRight'))
        dependencies = [renderer, 'SourceGroundLookup']
        if body in (771, 265, 281, 130):
            dependencies.append('ArchiveGestureGround')
        if body == 130:
            dependencies.extend(('ArchiveGestureVisual', 'UopMonsterGait', 'CreatureModeZeroVariants',
                                 'CreatureFallPlayback', 'SourceSpaceFallPlayback'))
        extra = [0, 1, 2, 3, 10, 15, 16]
        if body != 265:
            extra.append(18)
        if body in (754, 755):
            extra.append(21)
        if body == 130:
            extra.extend((9, 13, 14, 21))
        row = dict(base, family=FAMILY, status='prepared', assets=assets, classic_gesture_base_assets=earlier,
                   authored_action_scene_sha256=scenes, authored_action_reference=references['15'],
                   classic_motion_references=references,
                   classic_action_categories=base.get('classic_action_categories', {}) | classic,
                   new_action_categories=modern, native_extra_classic_actions=extra,
                   native_constructor_hues={name: HUES.get(name, 0) for name in classes},
                   archive_grounded_gestures=grounded, archive_align_gesture_slope=body in (130, 265),
                   authored_replacements=base.get('authored_replacements', {}) | authored,
                   presentation_script=f'res://Presentation/{renderer}.gd',
                   presentation_script_sha256=sha(VIEWER / f'Presentation/{renderer}.gd'),
                   collapse_renderer_dependencies=base.get('collapse_renderer_dependencies', {}) | {
                       name: sha(VIEWER / f'Presentation/{name}.gd') for name in dependencies})
        if body == 130:
            row['native_uop_group_clips'] = {str(group): clip for group, clip in FIRE.items()}
            row['native_uop_stance'] = {'archive': 'AnimationFrame1.uop', 'peace_walk_group': 22,
                                        'peace_idle_group': 25, 'war_walk_group': 0, 'war_idle_group': 1,
                                        'run_group': 24, 'warmode_flag': 0x40,
                                        'peace_walk': pins['uop']['130']['groups']['22']}
        rows.append(row)
    return rows, CLASSES


def check_fire_stances(report, receipt):
    fixture = 'Server/HorseIntegrationFixtures/FireGargoyleStanceFixtures.cs'
    if receipt['build_inputs_sha256'][fixture] != sha(ROOT / fixture):
        raise ValueError('Fire Gargoyle stance fixture differs from the tested build input')
    stances = report['fire_stances']
    if len(stances) != 12:
        raise ValueError('Expected six Fire Gargoyle steps on both clients')
    for sex in (0, 1):
        witness, = (row for row in report['records']
                    if int(row['body']) == 130 and bool(row['female']) == bool(sex))
        serials = {action['owner_packet']['serial'] for action in witness['actions']}
        if len(serials) != 1:
            raise ValueError('Fire Gargoyle actions did not belong to one native actor')
        serial, = serials
        previous = None
        for phase, combat in enumerate((False, True, False)):
            matches = [row for row in stances if (int(row['owner']), int(row['phase'])) == (sex, phase)]
            if len(matches) != 2 or {int(row['client']) for row in matches} != {0, 1}:
                raise ValueError('Both clients must witness each Fire Gargoyle stance')
            first, second = matches
            if (any(first[field] != second[field] for field in ('from', 'to'))
                    or first['from'] == first['to'] or (previous is not None and first['from'] != previous)
                    or any(int(row['body']) != 130 or row['serial'] != serial
                           or bool(int(row['flags']) & 0x40) != combat
                           or row['idle'] != ('Idle' if combat else 'ReadyStance')
                           or row['walk'] != ('Walk' if combat else 'FireGargoylePeaceWalk')
                           for row in matches)):
                raise ValueError('Fire Gargoyle stance or actual native step did not match on both clients')
            previous = first['to']


def main():
    selector = runpy.run_path(str(SCRIPTS / 'prepare-creature-fixtures.py'))
    baseline = selector['gesture_baseline'](FAMILY, None, CLASSES, layered=True)
    rows, _ = prepared(baseline)
    target = ROOT / 'work/creatures' / FAMILY / 'prepared-client.json'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')
    print('FROST THROUGH GARGOYLE: 97 directly stored MUL groups and 16 UOP groups verified')


if __name__ == '__main__':
    main()
