"""Prepare ranked source actions for Ridgebacks, Fire Beetle, Reptalon and dragons."""

import hashlib
import json
from pathlib import Path
import runpy


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'scripts'
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'ridgeback_through_dragons_actions'
FIRE = 'fire_beetle_rest'
COMMON = runpy.run_path(str(SCRIPTS / 'prepare-post-solen-actions.py'))
read, sha, new_actions = (COMMON[name] for name in ('read', 'sha', 'new_actions'))
CLASSES = {187: ['Ridgeback'], 276: ['Reptalon'], 308: ['BoneDemon'], 188: ['SavageRidgeback'],
           103: ['SerpentineDragon'], 104: ['SkeletalDragon']}
KINDS = {187: 'ridgeback_ridgeback', 276: 'raptalon', 308: 'bonedemon', 169: 'giant_beetle_fire',
         188: 'ridgeback_savage', 103: 'dragons_dragon_asian', 104: 'dragons_dragon_skeletal'}
SINGLE_FALL = COMMON['BASE'] | {3: 'Death'}
ANIMAL = COMMON['GAMAN']
RIDGEBACK = ANIMAL | {4: 'RidgebackNoseDip', 6: 'Attack', 10: 'RidgebackBriefFidget', 12: 'Death'}
CLASSIC = {
    187: RIDGEBACK,
    276: ANIMAL | {3: 'ReptalonGrazing', 10: 'ReptalonSourceFidget2'},
    308: SINGLE_FALL | {6: 'Attack2', 11: 'Pillage', 15: 'BoneDemonShortRecoil', 16: 'BoneDemonShortRecoil',
                        18: 'BoneDemonHandCheck'},
    169: ANIMAL | {3: 'Fidget', 4: 'FireBeetleLowerHead', 10: 'Fidget2', 12: 'Death'},
    188: RIDGEBACK,
    103: SINGLE_FALL | {5: 'Attack', 6: 'Attack', 15: 'SerpentineShortRecoil', 16: 'SerpentineShortRecoil',
                        18: 'SerpentineNeckSweep'},
    104: SINGLE_FALL | {6: 'Attack2', 15: 'SkeletalShortRecoil', 16: 'SkeletalShortRecoil', 18: 'SkeletalWingAdjust',
                        19: 'Fly', 20: 'Land', 21: 'AirDeath'},
}
FITTED = {187: (4, 10, 11), 276: (), 308: (15, 18), 169: (4, 11), 188: (4, 10, 11), 103: (15, 18), 104: (15, 18, 21)}
GROUND = {276: (3, 10, 11), 104: (15, 18)}
RENDERERS = {187: 'SourceRidgebackActionsVisual', 276: 'SourceReptalonActionsVisual', 308: 'ArchiveOccurrenceGestureVisual',
             169: 'SourceFireBeetleActionsVisual', 188: 'SourceRidgebackActionsVisual', 103: 'ArchiveGestureVisual',
             104: 'SourceSkeletalDragonActionsVisual'}
BAKE_INPUTS = ('bake-ridgeback-through-dragons-actions.gd', 'bake-banshee-through-queens-actions.gd',
               'bake-quagmire-through-exodus-actions.gd', 'bake-lattice-through-meer-actions.gd',
               'bake-frost-through-gargoyle-actions.gd', 'bake-swamp-widow-juka-actions.gd', 'bake-zombie-actions.gd',
               'bake-troll-actions.gd', 'bake-skeleton-actions.gd')
TREATMENTS = ('original', 'rounded', 'modern')

def checked_source():
    pins = read(SCRIPTS / 'ridgeback-through-dragons-action-pins.json')
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    assert pins['inputs'] == {name: sha(data / name) for name in ('AnimationSequence.uop', 'Bodyconv.def', 'mobtypes.txt')}
    ledger = runpy.run_path(str(SCRIPTS / 'build-creature-actions.py'))
    raw, _, flags = ledger['original_mul_groups'](data, set(CLASSIC))
    reader = runpy.run_path(str(SCRIPTS / 'uo-human-sequences.py'))
    sequence = {row['animation_ref']: row for row in reader['inspect'](data / 'AnimationSequence.uop', set(CLASSIC))}
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
    return pins['bodies']


def checked_reptalon_donor():
    folder = ROOT / 'work/creatures/reptalon-source-clips'
    receipt = read(folder / 'extra-motion-receipt.json')
    extra = read(SCRIPTS / 'reptalon-extra-inputs.json')
    base = runpy.run_path(str(SCRIPTS / 'prepare-recovered-late.py'))['BASE'] / 'final-late-source'
    assert extra['files'] == receipt['source_sha256'] == {name: sha(base / name) for name in extra['files']}
    assert receipt['rig_joint_count'] == 45
    assert receipt['scenes_sha256'] == {name: sha(folder / f'raptalon-{name}.gltf') for name in TREATMENTS}
    clips = receipt['clips']
    assert set(clips) == {'FittedRest', 'ReptalonGrazing', 'ReptalonSourceFidget2'}
    assert set(clips.values()) == {name.lower() for name in extra['files']}
    return {'LieDown' if clip == 'FittedRest' else clip: member for clip, member in clips.items()}


def prepared(entries, bodies=CLASSES):
    pins = checked_source()
    inputs = {name: sha(SCRIPTS / name) for name in BAKE_INPUTS}
    inputs.update({name: sha(VIEWER / 'Presentation' / name) for name in ('WaterElementalFidgets.gd', 'SourceGroundLookup.gd')})
    rows = []
    for body in bodies:
        base, = (row for row in entries if row['status'] == 'validated' and [int(identity['body']) for identity in row['bodies']] == [body])
        assert base['kind'] == KINDS[body]
        stem = f'ridgeback-through-dragons-{body}-actions'
        before = base.get('assets') or {name: f'res://local-art/creatures/{base["kind"]}-{name}.gltf' for name in TREATMENTS}
        hashes = {name: sha(VIEWER / path[6:]) for name, path in before.items()}
        expected = base.get('asset_sha256') or {name: row['scene_sha256'] for name, row in base.get('saved_scenes', {}).items()}
        assert hashes == (expected or pins[str(body)].get('legacy_base_sha256'))
        assets = {name: f'res://local-art/creatures/{stem}-{name}.scn' for name in before}
        scenes = {name: sha(VIEWER / path[6:]) for name, path in assets.items()}
        receipt = read(ART / f'{stem}-bake.json')
        assert receipt['inputs'] == inputs and receipt['scenes'][str(body)] == {
            name: {'source': hashes[name], 'scene': scenes[name]} for name in before}
        proof = pins[str(body)]
        references = {slot: dict(body=body, group=int(slot), archive=proof['archive'], graphic=proof['graphic'],
                                 frames=frames[0], directions=list(range(5)), directional_payload_sha256=digest)
                      for slot, (frames, digest) in proof['groups'].items()}
        classic = CLASSIC[body]
        artist = {classic[slot]: f'Fitted on the retained rig from {proof["archive"]} group {slot}' for slot in FITTED[body]}
        ground = sorted({classic[slot] for slot in GROUND.get(body, FITTED[body])})
        renderer = f'res://Presentation/{RENDERERS[body]}.gd'
        extra = [0, 1, 2, 4, 6, 7, 8, 10, 12] if body in (187, 188, 276) else [0, 1, 2, 3, 10, 15, 16, 18]
        if body == 104:
            extra.append(21)
        if body == 169:
            extra = []
        classes = CLASSES.get(body, ['FireBeetle'])
        row = dict(base, status='prepared', family=FIRE if body == 169 else FAMILY, assets=assets,
                   authored_action_scene_sha256=scenes, classic_gesture_base_assets=before,
                   authored_action_reference=references['4' if body == 169 else '10' if body in (187, 188, 276) else '15'],
                   classic_motion_references=references, classic_action_categories=base.get('classic_action_categories', {}) |
                   {str(slot): clip for slot, clip in classic.items()}, new_action_categories=base.get('new_action_categories', {}),
                   authored_replacements=base.get('authored_replacements', {}) | artist,
                   presentation_script=renderer, presentation_script_sha256=sha(VIEWER / renderer[6:]),
                   archive_grounded_gestures=ground, archive_align_gesture_slope=body in (103, 104, 276),
                   native_extra_classic_actions=extra, native_constructor_hues=base.get('native_constructor_hues',
                   dict.fromkeys(classes, 0x489 if body == 169 else 0)))
        if body == 276:
            row.update(clip_sources=base['clip_sources'] | checked_reptalon_donor(), original_rest_retained=True, mount_item=0x3E90)
        rows.append(row)
    return rows, CLASSES


def main():
    selector = runpy.run_path(str(SCRIPTS / 'prepare-creature-fixtures.py'))
    for family, bodies in ((FAMILY, CLASSES), (FIRE, {169})):
        work = ROOT / 'work/creatures' / family
        accepted_base = work / 'accepted-native/base-rows.json'
        base = read(accepted_base) if accepted_base.is_file() else selector['gesture_baseline'](family, None, bodies, layered=True)
        rows, _ = prepared(base, bodies)
        work.mkdir(parents=True, exist_ok=True)
        output = work / ('preview.json' if family == FIRE else 'prepared-client.json')
        output.write_text(json.dumps(rows[0] if family == FIRE else rows, indent=2) + '\n', encoding='utf-8')
        print(f'{len(rows)} bodies and {sum(len(CLASSIC[body]) for body in bodies)} directly stored Classic groups for {family}')


if __name__ == '__main__':
    main()
