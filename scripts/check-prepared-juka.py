"""Check exact prepared Juka evidence; this does not accept native routes."""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'Viewer/local-art/creatures'
OUT = ROOT / 'outputs/creatures/juka'
KINDS = {'juka_warrior': (764, 34, 470), 'juka_mage': (765, 39, 559)}
CATEGORIES = {'Idle', 'Walk', 'Run', 'Attack', 'Attack2', 'AttackBow', 'Hit', 'Death', 'Death2', 'Fidget', 'Cast', 'Cast2', 'Pillage'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def runtime(proof):
    assert proof['runtime_sha256']
    for name, digest in proof['runtime_sha256'].items():
        path = ROOT / 'Viewer' / name[6:] if name.startswith('res://') else ROOT / 'Viewer' / name if name.startswith(('Network/', 'Presentation/')) else ROOT / 'Viewer/Presentation' / name
        assert sha(path) == digest, 'Juka runtime/test changed: ' + name


def source():
    subprocess.run([sys.executable, '-B', str(ROOT / 'scripts/prepare-source-juka.py'), '--check-inputs'], check=True)
    prep = read(ART / 'juka/preparation.json')
    for field, name in [('recipe_sha256', 'prepare-source-juka.py'), ('reader_sha256', 'import-third-dawn.py'), ('source_pipeline_sha256', 'prepare-creatures.py'), ('input_manifest_sha256', 'source-juka-inputs.json')]:
        assert prep[field] == sha(ROOT / 'scripts' / name)
    pins = read(ROOT / 'scripts/source-juka-inputs.json')
    assert set(r['source_sha256'] for r in prep['indexed_auxiliary_repairs']) == set(pins['indexed_auxiliary_source_sha256']) and len(pins['indexed_auxiliary_source_sha256']) == 7
    assert all(r['contract'] == pins['indexed_auxiliary_contract'] for r in prep['indexed_auxiliary_repairs'])
    proof = read(OUT / 'source-poses.json')
    assert proof['checks'] >= 8681 and proof['failures'] == 0 and len(proof['samples']) == 2886 and proof['paired_poses'] == 1924
    assert proof['maximum_joint_error_m'] < .00001 and proof['maximum_basis_error'] < .00001 and proof['maximum_floor_error_m'] < .008
    assert proof['preparation_sha256'] == sha(ART / 'juka/preparation.json') and proof['geometry_sha256'] == sha(ROOT / 'Viewer/Presentation/SkinGeometry.gd')
    assert proof['test_sha256'] == sha(ROOT / 'Viewer/Presentation/JukaSourcePoseTests.gd')
    assert {r['kind'] for r in prep['models']} == set(KINDS)
    for row in prep['models']:
        kind = row['kind']
        body, bones, triangles = KINDS[kind]
        assert row['status'] == 'prepared' and row['pending_render_feature'] and row['profile'] == 'monster'
        assert row['stats']['original']['bones'] == bones and row['stats']['original']['triangles'] == triangles and row['stats']['rounded']['triangles'] == triangles * 16
        assert set(row['stats']['original']['clips']) == CATEGORIES and len(row['clip_sources']) == 13 and not row['rejected_source_clips']
        assert {r['body'] for r in row['bodies']} == {body} and row['bodies'][0]['animation_body'] == (400 if body == 764 else 401)
        assert row['presentation_script'] == 'res://Presentation/SourceJukaVisual.gd' and row['presentation_script_sha256'] == sha(ROOT / 'Viewer/Presentation/SourceJukaVisual.gd')
        assert row['classic_action_categories'] == {'14': 'Cast2'} and row['new_action_categories'] == {'2': 'Hit', '5': 'Fidget', '14': 'Pillage'}
        for treatment, pin in proof['assets'][kind].items():
            path = ART / (kind + '-' + treatment + '.gltf')
            assert sha(path) == pin['asset_sha256'] and sha(Path(str(path) + '.import')) == pin['import_sha256']
    print('JUKA PREPARED SOURCE: exact original inputs/rigs, 13 selected source motions each and whole-skin pose evidence pass; this source stage changes no accepted routes')
    return prep, proof


def graphics(prep, source_proof):
    subprocess.run([sys.executable, '-B', str(ROOT / 'scripts/check-creature-evidence.py'), 'juka'], check=True)
    general = read(OUT / 'validation.json')
    standard = read(OUT / 'appearance.json')
    assert general['failures'] == standard['failures'] == 0 and general['checks'] >= 2031 and standard['checks'] >= 25
    flat = read(OUT / 'transitions.json')
    assert flat['failures'] == 0 and flat['samples'] == 5280 and flat['checks'] >= 15840 and flat['maximum_source_clearance_error_m'] < .008
    assert flat['preparation_sha256'] == sha(ART / 'juka/preparation.json') and flat['airborne_cases'] > 0
    runtime(flat)
    mixed = read(OUT / 'mixed-terrain.json')
    assert mixed['failures'] == 0 and mixed['renderer'] == 'forward_plus' and mixed['checks'] >= 23620 and len(mixed['samples']) == 4032
    assert mixed['preparation_sha256'] == sha(ART / 'juka/preparation.json')
    runtime(mixed)
    pairs = {('Walk', 'Run'), ('Run', 'AttackBow'), ('Run', 'Cast'), ('Run', 'Cast2'), ('Run', 'Pillage'), ('Run', 'Death'), ('Run', 'Death2')}
    assert {tuple(r['pair']) for r in mixed['samples']} == pairs and {r['rate'] for r in mixed['samples']} == {.65, 1.65}
    airborne = 0
    for row in mixed['samples']:
        actual, expected = row['sample'], row['expected']
        height = expected['source_airborne_height_m']
        if height:
            airborne += 1
            assert height == expected['raw_source_minimum'] and height >= .015 and all(n >= .015 for n in expected['lifts'])
        assert abs(actual['minimum_gap'] - height) < .008 and actual['picker_contains'] and actual['nameplate_clears']
        if not row['pair'][1].startswith('Death'):
            assert all(abs(gap - (0 if lift < .015 else lift)) < .009 for gap, lift in zip(actual['foot_gaps'], expected['lifts']))
            assert all(abs(a - b) < .001 for limb, original in zip(actual['lengths'], expected['lengths']) for a, b in zip(limb, original))
    assert airborne >= 6
    tested = {row['kind']: row for row in general['models']}
    for row in prep['models']:
        kind = row['kind']
        proof = read(OUT / (kind + '-presentation/validation.json'))
        assert proof['failures'] == 0 and proof['checks'] >= 3250 and proof['renderer'] == 'forward_plus'
        assert len(proof['terrain']) == 246 and len(proof['action_skins']) == 255 and {r['clip'] for r in proof['action_skins']} == CATEGORIES | {'Eat', 'LieDown'}
        assert proof['preparation_sha256'] == sha(ART / 'juka/preparation.json') and proof['body'] == KINDS[kind][0]
        runtime(proof)
        assert 'res://Presentation/SourceJukaSupport.gd' in proof['runtime_sha256']
        pin = source_proof['assets'][kind]['modern']
        assert proof['asset_sha256'] == mixed['assets'][kind]['asset_sha256'] == flat['assets'][kind]['asset_sha256'] == pin['asset_sha256']
        assert proof['import_sha256'] == mixed['assets'][kind]['import_sha256'] == flat['assets'][kind]['import_sha256'] == pin['import_sha256']
        for treatment, pin in source_proof['assets'][kind].items():
            assert tested[kind]['asset_sha256'][treatment] == pin['asset_sha256'] and tested[kind]['import_sha256'][treatment] == pin['import_sha256']
    print('JUKA PREPARED GRAPHICS: current actual avatars, dyes/corpses, source lift/segments and full-skin slope blends pass; native acceptance and final art remain separate')


def native():
    proof = read(OUT / 'live.json')
    assert proof['ai_timer_stop_verified'] and proof['ai_control_sha256'] == sha(ROOT / 'Server/HorseIntegrationFixtures/FixtureAIControls.cs')
    assert proof['failures'] == 0 and proof['checks'] >= 427 and len(proof['records']) == 4
    assert proof['test_sha256'] == sha(ROOT / 'Viewer/Network/SourceJukaLive.gd') and proof['base_test_sha256'] == sha(ROOT / 'Viewer/Network/CreatureLive.gd')
    assert proof['fixture_sha256'] == sha(ROOT / 'Server/HorseIntegrationFixtures/CreatureFixtures.cs') and proof['preparation_sha256'] == sha(ART / 'juka/preparation.json')
    runtime(proof)
    classes = {764: 'JukaWarrior', 765: 'JukaMage'}
    assert {(r['body'], r['native_class'], r['female']) for r in proof['records']} == {(b, c, sex) for b, c in classes.items() for sex in [False, True]}
    expected = {3: 'Death2', 4: 'Attack', 5: 'Attack2', 7: 'AttackBow', 11: 'Pillage', 12: 'Cast', 14: 'Cast2', 17: 'Fidget', -1: 'Hit', -2: 'Cast', -3: 'Hit', -4: 'Fidget', -5: 'Pillage'}
    for row in proof['records']:
        assert row['native_state'] == 'constructor' and not row['corpse_suppressed'] and not row['native_death_refused']
        assert row['movement'] == 'Native Mobile.Move walk/run' and row['native_equipment'] == row['death_equipment']
        assert all(item['layer'] == 21 for item in row['native_equipment'])
        assert {a['requested'] for a in row['actions']} == set(expected)
        assert all(a['owner_clip'] == a['observer_clip'] == expected[a['requested']] for a in row['actions'])
    behaviour = read(OUT / 'behaviour.json')
    assert behaviour['ai_timer_stop_verified'] and 'Server/HorseIntegrationFixtures/FixtureAIControls.cs' in behaviour['inputs_sha256']
    assert behaviour['failures'] == 0 and behaviour['checks'] >= 100 and {(r['client'], r['body']) for r in behaviour['records']} == {(c, b) for c in [0, 1] for b in classes}
    assert behaviour['inputs_sha256']
    for path, digest in behaviour['inputs_sha256'].items():
        assert digest and sha(ROOT / path) == digest, 'Native Juka behaviour input changed: ' + path
    for row in behaviour['records']:
        assert row['support_lord_body'] == 766 and row['native_class'] == classes[row['body']]
        if row['body'] == 764:
            assert row['native_special_observed'] and 1 <= len(row['melee_observations']) <= 96
            last = row['melee_observations'][-1]
            assert last[4] == '0' and (last[5] == '1' or int(last[3]) < int(last[2]))
        else:
            assert row['actual_spell_damage'] > 0
            boosted, restored = row['native_buff'], row['native_buff_expiry']
            assert len(boosted) == len(restored) == 11 and boosted[8] == '0' and restored[8] == '1'
            for before, after, percent in [(2, 3, 75), (4, 5, 50), (6, 7, 50)]:
                assert int(boosted[after]) == int(boosted[before]) + int(boosted[before]) * percent // 100
                assert restored[before] == restored[after] == boosted[before]
            assert 19 <= row['observed_buff_seconds'] < 35
        refused, acquired = row['restricted_refusal'], row['unrestricted_result']
        assert len(refused) == len(acquired) == 8 and refused[2] == refused[5] == refused[7] == '0' and refused[6] == '1' and refused[3] == refused[4]
        assert acquired[2] == acquired[5] == '1' and acquired[6] == '0' and int(acquired[3]) > int(acquired[4]) and int(acquired[7]) > 0
    print('JUKA NATIVE: both constructor bodies/both owners, thirteen actual action requests each, replicated equipment/death/corpses, native random Warrior special, Mage spell/Lord buff/recovery and native loot callbacks pass; Lord graphics and autonomous gameplay remain separate')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--graphics', action='store_true')
    parser.add_argument('--native', action='store_true')
    args = parser.parse_args()
    preparation, poses = source()
    if args.graphics or args.native:
        graphics(preparation, poses)
    if args.native:
        native()
