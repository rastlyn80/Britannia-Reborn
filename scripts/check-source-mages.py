"""Require exact source, full skins, equipment, slope blends and native cases."""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'Viewer/local-art/creatures'
OUT = ROOT / 'outputs/creatures/mages'
KINDS = {'mages_evil_mage': {124}, 'mages_evil_mage_master': {125, 126}}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def runtime(proof):
    assert proof['runtime_sha256']
    for name, digest in proof['runtime_sha256'].items():
        if name.startswith('res://'):
            path = ROOT / 'Viewer' / name[6:]
        elif name.startswith(('Network/', 'Presentation/')):
            path = ROOT / 'Viewer' / name
        else:
            path = ROOT / 'Viewer/Presentation' / name
        assert sha(path) == digest, 'Mage runtime changed: ' + name


def main():
    subprocess.run([sys.executable, '-B', str(ROOT / 'scripts/prepare-source-mages.py'), '--check-inputs'], check=True)
    prep_path = ART / 'mages/preparation.json'
    prep = read(prep_path)
    for field, filename in [('recipe_sha256', 'prepare-source-mages.py'), ('source_pipeline_sha256', 'prepare-creatures.py'), ('input_manifest_sha256', 'source-mage-inputs.json')]:
        assert prep[field] == sha(ROOT / 'scripts' / filename)
    assert {r['kind'] for r in prep['models']} == set(KINDS) and len(prep['models']) == 2
    general = read(OUT / 'validation.json')
    standard = read(OUT / 'appearance.json')
    assert general['failures'] == standard['failures'] == 0 and general['checks'] >= 1654 and standard['checks'] >= 25
    tested = {r['kind']: r for r in general['models']}
    assert set(tested) == set(KINDS)
    action = read(OUT / 'actions.json')
    assert action['failures'] == 0 and action['checks'] >= 6922 and len(action['samples']) == 2220 and action['paired_poses'] == 1480
    assert action['preparation_sha256'] == sha(prep_path) and action['recipe_sha256'] == sha(ROOT / 'Viewer/Presentation/SourceMageActionTests.gd')
    assert action['maximum_joint_error_m'] < .00001 and action['maximum_basis_error'] < .00001 and action['maximum_floor_error_m'] < .008
    assert len(action['native_timing']) == 63 and {r['body'] for r in action['native_timing']} == {124, 125, 126}
    transition = read(OUT / 'transitions.json')
    assert transition['failures'] == 0 and transition['checks'] >= 11520 and transition['samples'] == 3840 and transition['maximum_floor_error_m'] < .008
    assert transition['test_sha256'] == sha(ROOT / 'Viewer/Presentation/SourceMageTransitionTests.gd')
    assert transition['visual_sha256'] == sha(ROOT / 'Viewer/Presentation/SourceMageVisual.gd') and transition['ground_helper_sha256'] == sha(ROOT / 'Viewer/Presentation/SourceGroundLookup.gd')
    equipment = read(OUT / 'equipment/validation.json')
    mixed = read(OUT / 'mixed-terrain.json')
    for proof in [equipment, mixed]:
        assert proof['failures'] == 0 and proof['renderer'] == 'forward_plus' and proof['preparation_sha256'] == sha(prep_path)
        runtime(proof)
    assert equipment['checks'] >= 97 and {r['body'] for r in equipment['bodies']} == {124, 125, 126}
    assert all(r['robe_changed_pixels'] > 100 and r['vertices'] == 21216 for r in equipment['bodies'])
    assert mixed['checks'] >= 13828 and len(mixed['samples']) == 2304
    assert {tuple(r['pair']) for r in mixed['samples']} == {('Walk', 'Run'), ('Run', 'Cast2'), ('Run', 'Pillage'), ('Run', 'Death')}
    assert {r['rate'] for r in mixed['samples']} == {.65, 1.65} and {r['yaw'] for r in mixed['samples']} >= {0.}
    for row in mixed['samples']:
        sample = row['sample']
        assert abs(sample['minimum_gap']) < .008 and sample['picker_contains'] and sample['nameplate_clears']
        if row['pair'][1] != 'Death':
            for index, gap in enumerate(sample['foot_gaps']):
                source = row['expected']['lifts'][index]
                assert abs(gap - (0 if source < .015 else source)) < .009
                assert all(abs(a - b) < .001 for a, b in zip(sample['lengths'][index], row['expected']['lengths'][index]))
    expected = {'Idle', 'Walk', 'Run', 'Attack', 'Attack2', 'Hit', 'Death', 'Fidget', 'Cast2', 'Pillage'}
    for row in prep['models']:
        kind = row['kind']
        assert {r['body'] for r in row['bodies']} == KINDS[kind]
        assert all(r['native_sources'] and r['native_class'] == ('EvilMage' if kind == 'mages_evil_mage' else 'EvilMageLord') for r in row['bodies'])
        assert row['stats']['original']['bones'] == 36 and row['stats']['original']['triangles'] == 442 and row['stats']['rounded']['triangles'] == 7072
        assert set(row['stats']['original']['clips']) == expected and len(row['clip_sources']) == 9 and not row['rejected_source_clips']
        assert set(row['authored_replacements']) == {'Pillage'} and row['native_equipment_layers'] == [22, 6, 3]
        assert row['classic_action_categories'] == {'12': 'Cast2', '14': 'Cast2'} and row['new_action_categories']['11'] == 'Cast2'
        assert row['presentation_script'] == 'res://Presentation/SourceMageVisual.gd' and row['presentation_script_sha256'] == sha(ROOT / 'Viewer/Presentation/SourceMageVisual.gd')
        assert row['garment_mask']['recipe_sha256'] == sha(ROOT / 'scripts/creature-mage-masks.py')
        assert row['garment_mask']['original_face_roles'] == {'robe': 225, 'skin': 160, 'shoes': 57} and row['garment_mask']['maximum_parent_uv_error'] < .00001
        proof = read(OUT / (kind + '-presentation/validation.json'))
        assert proof['checks'] >= 2737 and proof['failures'] == 0 and proof['renderer'] == 'forward_plus' and proof['preparation_sha256'] == sha(prep_path)
        runtime(proof)
        assert len(proof['terrain']) == 210 and len(proof['action_skins']) == 204 and {r['clip'] for r in proof['action_skins']} == expected | {'Eat', 'LieDown'}
        assert {r['clip'] for r in proof['terrain']} == expected - {'Death'}
        for treatment in ['original', 'rounded', 'modern']:
            path = ART / (kind + '-' + treatment + '.gltf')
            pin = action['assets'][kind][treatment]
            assert sha(path) == pin['asset_sha256'] == tested[kind]['asset_sha256'][treatment]
            assert sha(Path(str(path) + '.import')) == pin['import_sha256'] == tested[kind]['import_sha256'][treatment]
        assert mixed['assets'][kind]['asset_sha256'] == proof['asset_sha256'] == tested[kind]['asset_sha256']['modern']
    print('MAGE GRAPHICS: exact original sources, whole skins, independent gear, frozen corpses, actual finite-plane blends and selection passed')


def native():
    live = read(OUT / 'live.json')
    assert live['ai_timer_stop_verified'] and live['ai_control_sha256'] == sha(ROOT / 'Server/HorseIntegrationFixtures/FixtureAIControls.cs')
    assert live['failures'] == 0 and live['checks'] >= 577 and len(live['records']) == 6
    assert live['test_sha256'] == sha(ROOT / 'Viewer/Network/SourceMageLive.gd') and live['base_test_sha256'] == sha(ROOT / 'Viewer/Network/CreatureLive.gd')
    assert live['fixture_sha256'] == sha(ROOT / 'Server/HorseIntegrationFixtures/CreatureFixtures.cs') and live['preparation_sha256'] == sha(ART / 'mages/preparation.json')
    runtime(live)
    classes = {124: 'EvilMage', 125: 'EvilMageLord', 126: 'EvilMageLord'}
    assert {(r['body'], r['native_class'], r['female']) for r in live['records']} == {(b, c, sex) for b, c in classes.items() for sex in [False, True]}
    for row in live['records']:
        assert row['native_state'] == 'constructor' and not row['corpse_suppressed'] and not row['native_death_refused']
        assert row['movement'] == 'Native Mobile.Move walk/run' and row['native_equipment'] == row['death_equipment']
        slots = {r['layer']: r for r in row['native_equipment']}
        assert slots[22]['id'] == 7939 and slots[22]['hue'] > 0 and slots[3]['id'] == 5901
        if row['body'] != 124:
            assert slots[6]['id'] == 5912 and slots[6]['hue'] == slots[22]['hue']
        assert {a['requested'] for a in row['actions']} == {4, 5, 17, -1, 11, -3, -4, -5, 12, 14, -2}
        for action in row['actions']:
            assert action['owner_clip'] == action['observer_clip']
            if action['requested'] in [12, 14, -2]:
                assert action['owner_clip'] == 'Cast2'
            if action['requested'] in [11, -5]:
                assert action['owner_clip'] == 'Pillage'
    behaviour = read(OUT / 'behaviour.json')
    assert behaviour['ai_timer_stop_verified'] and behaviour['ai_control_sha256'] == sha(ROOT / 'Server/HorseIntegrationFixtures/FixtureAIControls.cs')
    assert behaviour['failures'] == 0 and {(r['client'], r['body']) for r in behaviour['records']} == {(c, b) for c in [0, 1] for b in classes}
    assert all(r['actual_spell_damage'] > 0 and r['native_rummage'] and r['native_backpack_acquired'] and r['corpse_after'] < r['corpse_before'] for r in behaviour['records'])
    assert behaviour['test_sha256'] == sha(ROOT / 'Viewer/Network/MageBehaviourLive.gd') and behaviour['fixture_sha256'] == sha(ROOT / 'Server/HorseIntegrationFixtures/MageBehaviourFixtures.cs')
    assert behaviour['base_test_sha256'] == sha(ROOT / 'Viewer/Network/FluidElementalBehaviourLive.gd')
    for record in behaviour['records']:
        refused = record['restricted_refusal']
        result = record['unrestricted_result']
        assert len(refused) == len(result) == 9
        assert refused[2] == refused[5] == refused[7] == '0' and refused[3] == refused[4] and int(refused[3]) > 0 and refused[6] == '1'
        assert result[2] == result[5] == '1' and result[6] == '0' and int(result[7]) > 0
    for path, digest in behaviour['native_source_sha256'].items():
        assert digest and sha(ROOT / 'Server/ModernUO' / path) == digest
    print('MAGE NATIVE: three constructor bodies/both owners, clothing/action/death replication, native spell damage and corpse rummaging passed; autonomous AI/automatic action packets remain outside this scope')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native', action='store_true')
    args = parser.parse_args()
    main()
    if args.native:
        native()
