"""Prepare the next encounter-ranked Classic motion set on sealed source rigs."""

import hashlib
import json
from pathlib import Path
import runpy


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'scripts'
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'banshee_through_queens_actions'
COMMON = runpy.run_path(str(SCRIPTS / 'prepare-post-solen-actions.py'))
read, sha, new_actions = (COMMON[name] for name in ('read', 'sha', 'new_actions'))
CLASSES = {310: ['WailingBanshee'], 280: ['MinotaurCaptain'], 767: ['Betrayer'], 43: ['IceFiend'],
           279: ['Ferret'], 768: ['Juggernaut'], 307: ['Gibberling'],
           807: ['BlackSolenQueen', 'BlackSolenInfiltratorQueen'],
           783: ['RedSolenQueen', 'RedSolenInfiltratorQueen'], 249: ['Yamandon', 'Serado']}
KINDS = {310: 'wailingbanshee', 280: 'minotaurarmored', 767: 'npc_blackthorn_cohort', 43: 'daemons_daemon_ice_fiend',
         279: 'ferret', 768: 'juggernaut', 307: 'gibberling', 807: 'black_ant_queen', 783: 'fire_ant_queen', 249: 'yamandon'}
MONSTER = COMMON['BASE']
SINGLE_FALL = MONSTER | {3: 'Death'}
QUEEN = SINGLE_FALL | {15: 'QueenShortRecoil', 16: 'QueenShortRecoil', 18: 'Fidget2'}
CLASSIC = {
    310: SINGLE_FALL | {15: 'BansheeShortRecoil', 16: 'BansheeShortRecoil', 18: 'BansheeHandCheck'},
    280: MONSTER | {11: 'Pillage', 15: 'BlockLeft', 16: 'BlockRight', 18: 'CaptainWatch'},
    767: SINGLE_FALL | {6: 'Attack2', 15: 'CohortShortRecoil', 16: 'CohortShortRecoil', 18: 'CohortPoint'},
    43: SINGLE_FALL | {6: 'Attack2', 12: 'DaemonCast', 13: 'FiendWingCanopy', 15: 'FiendShortRecoil',
                       16: 'FiendShortRecoil', 18: 'FiendWingFlare', 19: 'Fly', 20: 'Land', 21: 'AirDeath'},
    279: COMMON['GAMAN'] | {10: 'FerretSniff'},
    768: SINGLE_FALL | {6: 'Attack2', 15: 'JuggernautShortRecoil', 16: 'JuggernautShortRecoil', 18: 'JuggernautArmSweep'},
    307: SINGLE_FALL | {6: 'Attack2', 15: 'GibberlingDuck', 16: 'GibberlingDuck', 18: 'GibberlingReach'},
    807: QUEEN,
    783: QUEEN,
    249: MONSTER | {11: 'YamandonCoil', 15: 'YamandonDuck', 16: 'YamandonDuck', 18: 'YamandonCoil'},
}
FITTED = {310: (15, 18), 280: (18,), 767: (15, 18), 43: (13, 15, 18, 21), 279: (10,),
          768: (15, 18), 307: (15, 18), 807: (15,), 783: (15,), 249: (11, 15)}
GROUND = {280: (15, 16, 18), 43: (13, 15, 18)}
RENDERERS = {43: 'SourceIceFiendActionsVisual', 279: 'SourceFerretActionsVisual', 768: 'SourcePreservingCreatureVisual',
             807: 'SourceSolenQueenActionsVisual', 783: 'SourceSolenQueenActionsVisual', 249: 'ArchiveSourcePreservingGestureVisual'}
BAKE_INPUTS = ('bake-banshee-through-queens-actions.gd', 'bake-quagmire-through-exodus-actions.gd',
               'bake-lattice-through-meer-actions.gd', 'bake-frost-through-gargoyle-actions.gd',
               'bake-swamp-widow-juka-actions.gd', 'bake-zombie-actions.gd', 'bake-troll-actions.gd', 'bake-skeleton-actions.gd')


def checked_source():
    pins = read(SCRIPTS / 'banshee-through-queens-action-pins.json')
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
    return pins['bodies']


def prepared(entries):
    pins = checked_source()
    inputs = {name: sha(SCRIPTS / name) for name in BAKE_INPUTS}
    inputs.update({name: sha(VIEWER / 'Presentation' / name) for name in ('WaterElementalFidgets.gd', 'SourceGroundLookup.gd')})
    rows = []
    for body, classes in CLASSES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [int(identity['body']) for identity in row['bodies']] == [body])
        assert base['kind'] == KINDS[body]
        stem = f'banshee-through-queens-{body}-actions'
        previous = base['assets']
        source = {name: sha(VIEWER / path[6:]) for name, path in previous.items()}
        expected = base.get('asset_sha256') or {name: value['scene_sha256'] for name, value in base['saved_scenes'].items()}
        assert source == expected
        assets = {name: f'res://local-art/creatures/{stem}-{name}.scn' for name in previous}
        scenes = {name: sha(VIEWER / path[6:]) for name, path in assets.items()}
        receipt = read(ART / f'{stem}-bake.json')
        assert receipt['inputs'] == inputs and receipt['scenes'][str(body)] == {
            name: {'source': source[name], 'scene': scenes[name]} for name in assets}
        proof = pins[str(body)]
        references = {slot: dict(body=body, group=int(slot), archive=proof['archive'], graphic=proof['graphic'],
                                 frames=frames[0], directions=list(range(5)), directional_payload_sha256=digest)
                      for slot, (frames, digest) in proof['groups'].items()}
        classic = CLASSIC[body]
        renderer = f"res://Presentation/{RENDERERS.get(body, 'ArchiveOccurrenceGestureVisual')}.gd"
        authored = {classic[slot]: f'Fitted on the retained rig from {proof["archive"]} group {slot}' for slot in FITTED[body]}
        grounded = sorted({classic[slot] for slot in GROUND.get(body, FITTED[body])})
        if body == 279:
            extra = [0, 1, 2, 4, 6, 7, 8, 10, 12]
        else:
            extra = [0, 1, 2, 3, 10, 15, 16] + ([] if body in (807, 783) else [18])
            if body == 43:
                extra += [13, 21]
        rows.append(dict(base, status='prepared', family=FAMILY, assets=assets, classic_gesture_base_assets=previous,
                         authored_action_scene_sha256=scenes, authored_action_reference=references['10' if body == 279 else '15'],
                         classic_motion_references=references, classic_action_categories=base.get('classic_action_categories', {}) |
                         {str(slot): clip for slot, clip in classic.items()}, new_action_categories=base.get('new_action_categories', {}),
                         presentation_script=renderer, presentation_script_sha256=sha(VIEWER / renderer[6:]),
                         authored_replacements=base.get('authored_replacements', {}) | authored,
                         archive_grounded_gestures=grounded, archive_align_gesture_slope=body in (280, 43),
                         native_extra_classic_actions=extra, native_constructor_hues=base.get('native_constructor_hues', dict.fromkeys(classes, 0))))
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
