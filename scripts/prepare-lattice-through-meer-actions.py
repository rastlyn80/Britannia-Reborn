"""Prepare encounter-ranked creature actions and the Giant Beetle rest package."""

import argparse
import hashlib
import json
from pathlib import Path
import runpy


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'scripts'
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'lattice_through_meer_actions'
BEETLE_FAMILY = 'giant_beetle_rest'
COMMON = runpy.run_path(str(SCRIPTS / 'prepare-post-solen-actions.py'))
read, sha, new_actions = (COMMON[name] for name in ('read', 'sha', 'new_actions'))
CLASSES = {123: ['CrystalLatticeSeeker', 'EtherealWarrior'], 785: ['Moloch'], 189: ['OrcBrute'],
           241: ['Oni'], 770: ['MeerMage'], 301: ['Treefellow', 'FeralTreefellow'],
           277: ['CuSidhe'], 773: ['MeerCaptain']}
KINDS = {123: 'ethereal_warriors_male', 785: 'four_armed_demon', 189: 'orcs_orc_brute', 241: 'oni',
         791: 'giant_beetle', 770: 'meer_mage', 301: 'treefellow', 277: 'cushidhe', 773: 'npc_cpt_dasha'}
MONSTER = COMMON['BASE']
ANIMAL = COMMON['GAMAN'] | {10: 'Fidget2'}
CLASSIC = {
    123: MONSTER | {3: 'Death', 6: 'Attack2', 15: 'LatticeWingBrace', 16: 'LatticeWingBrace', 18: 'LatticeWingDisplay'},
    785: MONSTER | {3: 'Death', 15: 'MolochHighGuard', 16: 'MolochHighGuard', 18: 'MolochShoulderCheck'},
    189: MONSTER | {3: 'Death', 11: 'Pillage', 15: 'BruteCrouch', 16: 'BruteCrouch', 18: 'BruteChallenge'},
    241: MONSTER | {11: 'OniOverheadGesture', 15: 'OniLowGuard', 16: 'OniLowGuard', 18: 'OniOverheadGesture'},
    791: ANIMAL | {3: 'Fidget', 4: 'BeetleLowerHead', 9: 'Fidget', 12: 'Death'},
    770: MONSTER | {3: 'Death', 5: 'MeerMageHighSweep', 6: 'MeerMageSideSweep', 15: 'MeerMageGuard',
                    16: 'MeerMageGuard', 18: 'MeerMageLook'},
    301: MONSTER | {3: 'Death', 6: 'Attack2', 11: 'Pillage', 15: 'TreefellowBrace', 16: 'TreefellowBrace', 18: 'TreefellowLook'},
    277: ANIMAL | {10: 'CuSidheScent'},
    773: MONSTER | {3: 'Death', 5: 'MeerCaptainHighCut', 6: 'MeerCaptainSideCut', 15: 'MeerCaptainBrace',
                    16: 'MeerCaptainBrace', 18: 'MeerCaptainLook'},
}
FITTED = {123: (15, 18), 785: (15, 18), 189: (15, 18), 241: (15, 18), 791: (4, 11),
          770: (5, 6, 15, 18), 301: (15, 18), 277: (10,), 773: (5, 6, 15, 18)}
RENDERERS = {241: 'ArchiveOccurrenceGestureVisual', 770: 'ArchiveOccurrenceGestureVisual',
             773: 'SourceMeerCaptainActionsVisual', 791: 'SourceBeetleRestVisual'}
BAKE_INPUTS = ('bake-lattice-through-meer-actions.gd', 'bake-frost-through-gargoyle-actions.gd',
               'bake-swamp-widow-juka-actions.gd', 'bake-zombie-actions.gd',
               'bake-troll-actions.gd', 'bake-skeleton-actions.gd')


def check_source():
    pins = read(SCRIPTS / 'lattice-through-meer-action-pins.json')
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    assert pins['inputs'] == {name: sha(data / name) for name in ('AnimationSequence.uop', 'Bodyconv.def', 'mobtypes.txt')}
    scanner = runpy.run_path(str(SCRIPTS / 'build-creature-actions.py'))
    raw, _, flags = scanner['original_mul_groups'](data, set(CLASSIC))
    reader = runpy.run_path(str(SCRIPTS / 'uo-human-sequences.py'))
    sequence = {row['animation_ref']: row for row in reader['inspect'](data / 'AnimationSequence.uop', set(CLASSIC))}
    for body, actions in CLASSIC.items():
        proof = pins['bodies'][str(body)]
        rows = [row for row in raw if row['body'] == body]
        assert set(actions) == {row['group'] for row in rows} == set(map(int, proof['groups']))
        assert proof['mobtypes'] == list(flags[body]) and proof['sequence_present'] == (body in sequence)
        assert proof['new_actions'] == new_actions(sequence.get(body, {}))
        assert not sequence.get(body, {}).get('parse_blocker')
        for row in rows:
            assert not row['mobtype_prefers_uop'] and all(row[name] == proof[name] for name in ('archive', 'graphic', 'layout'))
            directions = row['directions']
            assert [direction['direction'] for direction in directions] == list(range(5))
            digest = hashlib.sha256(''.join(item['payload_sha256'] for item in directions).encode('ascii')).hexdigest()
            assert proof['groups'][str(row['group'])] == [[item['frames'] for item in directions], digest]
    return pins['bodies']


def make_row(base, body, proof):
    assert base['kind'] == KINDS[body]
    stem = f'lattice-through-meer-{body}-actions'
    existing = base['assets']
    assets = {name: f'res://local-art/creatures/{stem}-{name}.scn' for name in existing}
    scenes = {name: sha(VIEWER / path[6:]) for name, path in assets.items()}
    old_hashes = base.get('asset_sha256') or {name: row['scene_sha256'] for name, row in base['saved_scenes'].items()}
    assert old_hashes == {name: sha(VIEWER / path[6:]) for name, path in existing.items()}
    receipt = read(ART / f'{stem}-bake.json')
    inputs = {name: sha(SCRIPTS / name) for name in BAKE_INPUTS}
    inputs.update({name: sha(VIEWER / 'Presentation' / name)
                   for name in ('WaterElementalFidgets.gd', 'SourceGroundLookup.gd')})
    assert receipt['inputs'] == inputs and receipt['scenes'][str(body)] == {
        name: {'source': old_hashes[name], 'scene': scenes[name]} for name in scenes}
    classic = CLASSIC[body]
    references = {slot: dict(body=body, group=int(slot), archive=proof['archive'], graphic=proof['graphic'],
                             frames=frames[0], directions=list(range(5)), directional_payload_sha256=digest)
                  for slot, (frames, digest) in proof['groups'].items()}
    if proof['layout'] == 'small':
        # Sequence groups and Classic low-layout slots have different numbers.
        newer = {'0': 'Attack', '3': 'Death', '4': 'Hit'}
    else:
        newer = {kind: classic[groups[0]] for kind, groups in proof['new_actions'].items()
                 if kind in {'0', '2', '3', '4', '14'} and groups[0] in classic}
    newer.update(base.get('new_action_categories', {}))
    if body in (241, 770):
        newer['11'] = 'Cast'
    grounded = sorted({classic[slot] for slot in FITTED[body]})
    authored = {clip: 'Fitted on the retained source rig from the registered Classic frames' for clip in grounded}
    if body == 791:
        authored['LieDown'] = 'Upright settle and hold on the retained shell, separate from its collapse'
    renderer = (f'res://Presentation/{RENDERERS[body]}.gd' if body in RENDERERS else base['presentation_script'])
    classes = CLASSES.get(body, ['Beetle'])
    extra = ([0, 1, 2, 4, 6, 7, 8, 10, 12] if body == 277 else [0, 1, 2, 3, 10, 15, 16, 18])
    return dict(base, family=BEETLE_FAMILY if body == 791 else FAMILY, status='prepared', assets=assets,
                authored_action_scene_sha256=scenes, classic_gesture_base_assets=existing,
                authored_action_reference=references[str(FITTED[body][0])], classic_motion_references=references,
                classic_action_categories=base.get('classic_action_categories', {}) | {str(slot): clip for slot, clip in classic.items()},
                new_action_categories=newer, presentation_script=renderer,
                presentation_script_sha256=sha(VIEWER / renderer[6:]),
                authored_replacements=base.get('authored_replacements', {}) | authored,
                archive_grounded_gestures=grounded, native_extra_classic_actions=extra if body != 791 else [],
                native_constructor_hues={name: 0x47E if name == 'CrystalLatticeSeeker' else 0 for name in classes})


def prepared(entries, bodies=CLASSES):
    pins = check_source()
    rows = []
    for body in bodies:
        base, = (row for row in entries if row['status'] == 'validated' and [item['body'] for item in row['bodies']] == [body])
        rows.append(make_row(base, body, pins[str(body)]))
    return rows, CLASSES


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--beetle', action='store_true')
    args = parser.parse_args()
    selector = runpy.run_path(str(SCRIPTS / 'prepare-creature-fixtures.py'))
    family, bodies = (BEETLE_FAMILY, {791}) if args.beetle else (FAMILY, CLASSES)
    work = ROOT / 'work/creatures' / family
    if args.beetle and (work / 'accepted-native/base-rows.json').is_file():
        baseline = read(work / 'accepted-native/base-rows.json')
    else:
        baseline = selector['gesture_baseline'](family, None, bodies, layered=True)
    rows, _ = prepared(baseline, bodies)
    work.mkdir(parents=True, exist_ok=True)
    target = work / ('preview.json' if args.beetle else 'prepared-client.json')
    target.write_text(json.dumps(rows[0] if args.beetle else rows, indent=2) + '\n', encoding='utf-8')
    print(f'{len(rows)} bodies and {sum(len(CLASSIC[body]) for body in bodies)} directly stored Classic groups')


if __name__ == '__main__':
    main()
