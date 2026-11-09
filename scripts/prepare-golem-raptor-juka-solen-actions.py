"""Check and prepare the next encounter-ranked source motions."""

import argparse
import hashlib
import json
import math
from pathlib import Path
import runpy

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'golem_raptor_juka_solen_actions'
CLASSES = {752: ['Golem'], 730: ['Raptor'], 734: ['Slith', 'StoneSlith', 'ToxicSlith'],
           766: ['JukaLord'], 782: ['RedSolenWarrior', 'RedSolenInfiltratorWarrior'],
           806: ['BlackSolenWarrior', 'BlackSolenInfiltratorWarrior']}
KINDS = {752: 'golem_iron', 730: 'raptor', 734: 'lizards_komodo_dragon', 766: 'npc_kabur',
         782: 'fire_ant_warrior', 806: 'black_ant_warrior'}
HUES = {'BlackSolenWarrior': 0x453, 'BlackSolenInfiltratorWarrior': 0x453, 'ToxicSlith': 476}
BASE = {0: 'Walk', 1: 'Idle', 2: 'Death', 3: 'Death2', 4: 'Attack', 5: 'Attack2',
        6: 'Attack3', 10: 'Hit', 11: 'Fidget', 17: 'Fidget', 18: 'Fidget2'}
SOLEN = BASE | {3: 'Death', 15: 'SolenRecoil', 16: 'SolenRecoil'}
MUL = {
    752: BASE | {3: 'Death', 5: 'Attack', 6: 'Attack', 15: 'IronBrace', 16: 'IronBrace', 18: 'IronReset'},
    766: BASE | {6: 'BackhandStep', 11: 'Pillage', 15: 'ArmoredBrace', 16: 'ArmoredBrace', 18: 'ArmorGlance'},
    782: SOLEN, 806: SOLEN,
}
RAPTOR = {0: 'Walk', 1: 'Idle', 2: 'Death', 3: 'Death2', 4: 'Attack', 5: 'Jump',
          10: 'Hit', 15: 'RaptorDuck', 22: 'RaptorPeaceWalk', 23: 'RaptorLookBehind', 24: 'Run',
          25: 'ReadyStance', 26: 'RaptorLookUp', 27: 'RaptorLowerHead', 28: 'RaptorSettle'}
RAPTOR_NEW = {0: 4, 2: 15, 3: 2, 4: 10, 5: 26, 8: 28, 11: 4, 14: 25, 15: 23}
FITTED = {752: [15, 18], 730: [3, 15, 22, 23, 26, 27, 28], 734: [22], 766: [6, 15, 18], 782: [15], 806: [15]}
RENDERERS = {752: 'SourceIronGolemVisual', 730: 'RaptorActionsVisual', 734: 'SlithUopGaitVisual',
             766: 'JukaLordActionsVisual', 782: 'SolenWarriorActionsVisual', 806: 'SolenWarriorActionsVisual'}
DEPENDENCIES = {752: ['SourcePreservingCreatureVisual'],
                730: ['SourcePreservingCreatureVisual', 'UopMonsterGait', 'CreatureModeZeroVariants',
                      'CreatureFallPlayback'],
                734: ['SlithActionsVisual', 'UopMonsterGait'], 766: ['SourceJukaLordVisual', 'SourceJukaVisual'],
                782: ['SourceSolenWarriorVisual'], 806: ['SourceSolenWarriorVisual']}
COMMON = ('bake-swamp-widow-juka-actions.gd', 'bake-zombie-actions.gd', 'bake-troll-actions.gd', 'bake-skeleton-actions.gd',
          'WaterElementalFidgets.gd', 'SourceGroundLookup.gd')
STANCE_SCRIPTS = ['Network/CreatureCombatFlagsLive.gd', 'Presentation/NativeCreatureAppearance.gd',
                  'Presentation/UopMonsterGait.gd', 'Presentation/RaptorActionsVisual.gd',
                  'Presentation/SlithUopGaitVisual.gd']


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def sources():
    pins = read(SCRIPTS / 'golem-raptor-juka-solen-action-pins.json')
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    assert pins['inputs'] == {name: sha(data / name) for name in ('AnimationSequence.uop', 'AnimationFrame3.uop', 'mobtypes.txt', 'Bodyconv.def')}
    reader = runpy.run_path(str(SCRIPTS / 'uo-human-sequences.py'))
    ledger = runpy.run_path(str(SCRIPTS / 'build-creature-actions.py'))
    raw_mul, _, flags = ledger['original_mul_groups'](data, set(CLASSES))
    raw_uop, _ = ledger['original_frame_groups'](data, set(CLASSES), type('SequenceReader', (), reader))
    sequence = {row['animation_ref']: row for row in reader['inspect'](data / 'AnimationSequence.uop', set(CLASSES))}
    assert set(sequence) == set(CLASSES) - {782}
    for body in MUL:
        proof = pins['mul'][str(body)]
        rows = [row for row in raw_mul if row['body'] == body]
        assert proof['mobtypes'] == list(flags[body]) and proof['sequence'] == sequence.get(body)
        assert set(MUL[body]) == {row['group'] for row in rows} == set(map(int, proof['groups']))
        for row in rows:
            assert all(row[name] == proof[name] for name in ('archive', 'graphic', 'layout'))
            directions = row['directions']
            assert [item['direction'] for item in directions] == list(range(5))
            digest = hashlib.sha256(''.join(item['payload_sha256'] for item in directions).encode()).hexdigest()
            assert proof['groups'][str(row['group'])] == [[item['frames'] for item in directions], digest]
    assert {row['body'] for row in raw_uop} == {730, 734}
    for body in (730, 734):
        proof = pins['uop'][str(body)]
        rows = [row for row in raw_uop if row['body'] == body]
        assert proof['mobtypes'] == list(flags[body]) == ['MONSTER', 0x10000]
        assert proof['sequence'] == sequence[body] and not sequence[body].get('parse_blocker')
        assert all(row['archive'] == 'AnimationFrame3.uop' and row['frame_headers'] % 5 == 0 for row in rows)
        assert proof['groups'] == {str(row['group']): [row['frame_headers'], row['payload_sha256']] for row in rows}
        assert set(map(int, proof['groups'])) == set(RAPTOR)
    return pins


def action_rows(body, base, pins):
    proof = pins['mul' if body in MUL else 'uop'][str(body)]
    if body == 734:
        return (base['classic_action_categories'], base['classic_motion_references'], base['new_action_categories'])
    if body == 730:
        redirects = {row['old_group']: row['new_group'] for row in proof['sequence']['replacements'] if not row['frame_count']}
        groups = {slot: redirects.get(slot, slot) for slot in range(22)}
        references = {str(slot): dict(body=body, group=slot, uop_group=group, archive='AnimationFrame3.uop',
                                      frame_headers=proof['groups'][str(group)][0],
                                      payload_sha256=proof['groups'][str(group)][1]) for slot, group in groups.items()}
        categories = {str(slot): RAPTOR[group] for slot, group in groups.items()}
        modern = {str(kind): RAPTOR[group] for kind, group in RAPTOR_NEW.items()}
        return categories, references, modern
    categories = {str(slot): clip for slot, clip in MUL[body].items()}
    references = {str(slot): dict(body=body, group=slot, archive=proof['archive'], graphic=proof['graphic'],
                                  frames=proof['groups'][str(slot)][0][0], directions=list(range(5)),
                                  directional_payload_sha256=proof['groups'][str(slot)][1]) for slot in MUL[body]}
    mode_zero = {row['type']: row['groups'][0] for mode in (proof['sequence'] or {}).get('modes', [])
                 if mode['mode'] == 0 for row in mode['new_protocol_actions'] if row['subaction'] == -1}
    modern = {str(kind): MUL[body][group] for kind, group in mode_zero.items()
              if kind in (0, 2, 3, 4, 14) and group in MUL[body]}
    return categories, references, modern | base.get('new_action_categories', {})


def prepared(entries):
    pins = sources()
    rows = []
    for body, classes in CLASSES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [int(identity['body']) for identity in row['bodies']] == [body])
        assert base['kind'] == KINDS[body]
        prefix = {730: 'raptor-uop', 734: 'slith-uop-gait'}.get(body, f'golem-juka-solen-{body}')
        recipe = {730: 'bake-raptor-uop-actions.gd', 734: 'bake-slith-uop-gait.gd'}.get(body, 'bake-golem-juka-solen-actions.gd')
        inputs = (recipe, 'bake-raptor-uop-actions.gd') + COMMON if body == 734 else (recipe,) + COMMON
        inputs = {name: sha((VIEWER / 'Presentation' if name in COMMON[-2:] else SCRIPTS) / name) for name in inputs}
        earlier = base.get('assets') or {name: f'res://local-art/creatures/{base["kind"]}-{name}.gltf' for name in base['asset_sha256']}
        assets = {name: f'res://local-art/creatures/{prefix}-actions-{name}.scn' for name in earlier}
        old_sha = {name: sha(VIEWER / path[6:]) for name, path in earlier.items()}
        scenes = {name: sha(VIEWER / path[6:]) for name, path in assets.items()}
        assert old_sha == base['asset_sha256']
        bake = read(ART / f'{prefix}-actions-bake.json')
        assert bake['inputs'] == inputs and bake['scenes'][str(body)] == {
            name: {'source': old_sha[name], 'scene': scenes[name]} for name in scenes}
        if body == 766:
            assert set(assets) == {'original', 'modern'}
            assets['rounded'], scenes['rounded'] = assets['modern'], scenes['modern']

        categories, references, modern = action_rows(body, base, pins)
        renderer = RENDERERS[body]
        dependencies = [renderer, *DEPENDENCIES[body], 'SourceGroundLookup']
        group_clips = MUL[body] if body in MUL else RAPTOR if body == 730 else {22: 'SlithPeaceWalk'}
        archive = pins['mul'][str(body)]['archive'] if body in MUL else 'AnimationFrame3.uop'
        authored = {group_clips[group]: f'Fitted on the retained rig from {archive} group {group}'
                    for group in FITTED[body]}
        checked_dependencies = base.get('collapse_renderer_dependencies', {}) | {
            name: sha(VIEWER / f'Presentation/{name}.gd') for name in dependencies}
        row = dict(base, status='prepared', family=FAMILY, assets=assets,
                   classic_gesture_base_assets=earlier, authored_action_scene_sha256=scenes,
                   authored_action_reference=references['15'], classic_motion_references=references,
                   classic_action_categories=base.get('classic_action_categories', {}) | categories,
                   new_action_categories=modern, native_constructor_hues={name: HUES.get(name, 0) for name in classes},
                   presentation_script=f'res://Presentation/{renderer}.gd',
                   presentation_script_sha256=sha(VIEWER / f'Presentation/{renderer}.gd'),
                   authored_replacements=base.get('authored_replacements', {}) | authored,
                   collapse_renderer_dependencies=checked_dependencies)
        if body in (730, 734):
            proof = pins['uop'][str(body)]
            row['native_uop_stance'] = {'archive': 'AnimationFrame3.uop', 'peace_walk_group': 22,
                                        'peace_idle_group': 25, 'war_walk_group': 0, 'war_idle_group': 1,
                                        'run_group': 24, 'warmode_flag': 0x40,
                                        'peace_walk': proof['groups']['22']}
            row['native_uop_group_clips'] = base.get('slith_uop_group_clips', {}) | {
                str(group): clip for group, clip in group_clips.items()}
            if body == 730:
                row['native_extra_classic_actions'] = [0, 1, 2, 3, 9, 10, 13, 14, 15, 16, 18, 21]
        else:
            row['native_extra_classic_actions'] = [0, 1, 2, 3, 10, 15, 16, 18]
            if body in (782, 806):
                row['native_extra_classic_actions'].remove(18)
                ground_name = f'solen-recoil-{body}-ground.json'
                ground = read(ART / ground_name)
                assert ground['sample_rate'] == 960 and set(ground['treatments']) == set(assets)
                for name, treatment in ground['treatments'].items():
                    assert treatment['asset_sha256'] == scenes[name] and set(treatment['clips']) == {'SolenRecoil'}
                    samples = treatment['clips']['SolenRecoil']
                    assert len(samples) == 462 and all(math.isfinite(x) and math.isfinite(y) for x, y in samples)
                row['action_ground_lookup'] = f'res://local-art/creatures/{ground_name}'
                row['action_ground_lookup_sha256'] = sha(ART / ground_name)
        rows.append(row)
    return rows, CLASSES


def check_stance(rows, report_path, receipt):
    report = read(report_path)
    fixture = 'Server/HorseIntegrationFixtures/CreatureCombatFlagFixtures.cs'
    if (report['failures'] or receipt['stance_sha256'] != sha(report_path)
            or receipt['build_inputs_sha256'][fixture] != sha(ROOT / fixture)
            or report['scripts'] != {path: sha(VIEWER / path) for path in STANCE_SCRIPTS}
            or report['scenes'] != {str(row['bodies'][0]['body']): row['authored_action_scene_sha256']
                                    for row in rows if row['bodies'][0]['body'] in (730, 734)}):
        raise ValueError('Native gait evidence differs from the isolated fixture and the saved scenes')
    for body, peace_walk in ((730, 'RaptorPeaceWalk'), (734, 'SlithPeaceWalk')):
        previous = None
        for phase, combat in enumerate((False, True, False)):
            matches = [row for row in report['records'] if (row['body'], row['phase']) == (body, phase)]
            if len(matches) != 2 or {row['client'] for row in matches} != {0, 1}:
                raise ValueError(f'Both clients must witness each gait transition for body {body}')
            first, second = matches
            if (any(first[key] != second[key] for key in ('serial', 'from', 'to'))
                    or first['from'] == first['to']
                    or previous and (first['serial'] != previous['serial'] or first['from'] != previous['to'])
                    or any(row['combat'] != combat or bool(row['flags'] & 0x40) != combat
                           or row['idle'] != ('Idle' if combat else 'ReadyStance')
                           or row['walk'] != ('Walk' if combat else peace_walk) for row in matches)):
                raise ValueError(f'Native movement or stance flags differ for body {body}')
            previous = first
    if len(report['records']) != 12:
        raise ValueError('Unexpected native gait witness records')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    selector = runpy.run_path(str(SCRIPTS / 'prepare-creature-fixtures.py'))
    baseline = selector['gesture_baseline'](FAMILY, None, CLASSES, layered=True)
    rows, _ = prepared(baseline)
    output = ROOT / 'work/creatures' / FAMILY / 'prepared-client.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')
    print('GOLEM, RAPTOR, SLITH, JUKA LORD AND SOLEN: 52 direct MUL and 30 direct UOP groups checked')


if __name__ == '__main__':
    main()
