"""Bind the Solen Queen validation tools and register fully checked local art."""
import argparse
import copy
import hashlib
import json
import runpy
from pathlib import Path

ALIAS_EVIDENCE = runpy.run_path(str(Path(__file__).with_name('legacy-action-evidence.py')))
import subprocess
import sys

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent
RUNTIME = ROOT / 'Viewer/Presentation'
WORK = ROOT / 'work/creatures/solen-queen-source/final'
ART = ROOT / 'Viewer/local-art/creatures'
PREP = ART / 'solen_queens/preparation.json'
GROUNDED = PREP.with_name('grounded.json')
RECEIPT = PREP.with_name('local-presentation.json')
BODY_KEYS = {783, 807}


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def write(path, data):
    temporary = path.with_suffix('.json.pending')
    temporary.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
    temporary.replace(path)


def grounded():
    report = read(PREP)
    for row in report['models']:
        row['ground_lookup'] = f"res://local-art/creatures/solen_queens/{row['kind']}-ground.json"
    return report


def bind(name, changes):
    text = (RUNTIME / name).read_text(encoding='utf-8-sig')
    for before, after in changes.items():
        assert before in text, (name, before)
        text = text.replace(before, after)
    return text


def bound_tests():
    prep = 'res://local-art/creatures/solen_queens/grounded.json'
    result = {
        'BakeQueenGround.gd': bind('BakeSolenWarriorGround.gd', {
            'solen_warriors/preparation.json': 'solen_queens/grounded.json',
            'var path:=FOLDER+str(record.kind)+"-"+treatment+".gltf";var asset_pin:=FileAccess.get_sha256(path)\n'
            '\t\t\tvar document:=GLTFDocument.new();var state:=GLTFState.new();assert(document.append_from_file(ProjectSettings.globalize_path(path),state)==OK);var model:=document.generate_scene(state);root.add_child(model)':
                'var path:=str(record.assets[treatment]);var asset_pin:=FileAccess.get_sha256(path)\n'
                '\t\t\tvar model: Node3D=(load(path) as PackedScene).instantiate();root.add_child(model)',
            'FileAccess.open(FOLDER+str(record.kind)+"-ground.json",': 'FileAccess.open(str(record.ground_lookup),',
        }),
        'QueenTerrainTests.gd': bind('SolenWarriorTerrainTests.gd', {
            'solen_warriors/preparation.json': 'solen_queens/grounded.json',
            'work/creatures/solen-warriors/terrain-tests.json': 'work/creatures/solen-queen-source/final/terrain-tests.json',
        }),
    }
    for name in ('SourcePreservingSkinTests.gd', 'SourcePreservingActionTests.gd'):
        replacements = {
            'res://local-art/creatures/source_preserving/preparation.json': prep,
            'res://../work/creatures/source-preserving/': 'res://../work/creatures/solen-queen-source/final/',
        }
        if name == 'SourcePreservingSkinTests.gd':
            replacements['res://../scripts/source-preserving-inputs.json'] = 'res://../scripts/solen-queen-inputs.json'
        else:
            replacements['res://local-art/creatures/source_preserving/local-presentation.json'] = (
                'res://local-art/creatures/solen_queens/local-presentation.json')
        result[name] = bind(name, replacements)
    return result


def verified_rows():
    assert read(GROUNDED) == grounded()
    for name, source in bound_tests().items():
        assert (WORK / name).read_text(encoding='utf-8') == source
    rows = copy.deepcopy(grounded()['models'])
    assert {int(body['body']) for row in rows for body in row['bodies']} == BODY_KEYS
    ground_pins = {}
    for row in rows:
        path = ROOT / 'Viewer' / row['ground_lookup'].removeprefix('res://')
        measurement = read(path)
        assert measurement['sample_rate'] == 960 and measurement['preparation_sha256'] == sha(GROUNDED)
        assert measurement['recipe_sha256'] == sha(RUNTIME / 'BakeSolenWarriorGround.gd')
        assert measurement['geometry_sha256'] == sha(RUNTIME / 'SourceGroundLookup.gd')
        assert set(measurement['treatments']) == set(row['assets'])
        for treatment, item in measurement['treatments'].items():
            assert item['asset_sha256'] == row['saved_scenes'][treatment]['scene_sha256']
            assert set(item['clips']) == set(row['clip_sources'])
        ground_pins[row['ground_lookup']] = sha(path)
        constructor_hues = row['source_provenance']['native_constructor_hues']
        assert row['native_constructor_hues'] == constructor_hues
        assert all(int(hue) == hue and 0 <= hue <= 0xffff for hue in constructor_hues.values())
        row['native_constructor_hues'] = {name: int(hue) for name, hue in constructor_hues.items()}
        row.update(status='validated', validation_scope='Original Queen rig and clips, calibrated six-leg terrain, dyes and static corpse.')
    terrain = read(WORK / 'terrain-tests.json')
    assert terrain['failures'] == 0 and terrain['poses'] == 2880 and len(terrain['cases']) == 96
    assert not terrain['misses'] and terrain['maximum_skin_error_m'] < .008 and terrain['maximum_foot_error_m'] < .008
    assert terrain['preparation_sha256'] == sha(GROUNDED) and terrain['ground_measurement_sha256'] == ground_pins
    skin = read(WORK / 'skin-proof.json')
    actions = read(WORK / 'actions.json')
    appearance = read(WORK / 'appearance/appearance.json')
    render = read(WORK / 'presentation/validation.json')
    for proof in (skin, actions, appearance):
        assert proof['checks'] > 0 and proof['failures'] == 0 and proof['preparation_sha256'] == sha(GROUNDED)
    for proof, name in ((skin, 'SourcePreservingSkinTests.gd'), (actions, 'SourcePreservingActionTests.gd'),
                        (appearance, 'CreatureAppearanceTests.gd')):
        assert proof['test_sha256'] == sha(RUNTIME / name)
    assert skin['helper_sha256'] == sha(RUNTIME / 'SourcePoseSubdivision.gd')
    assert len(skin['models']) == 2 and all(row['poses'] == 30 for row in skin['models'])
    assert len(actions['models']) == 2 and {int(row['body']) for row in actions['models']} == BODY_KEYS
    assert appearance['renderer'] == render['renderer'] == 'forward_plus'
    appearance_log = (WORK / 'appearance.log').read_text(encoding='utf-8-sig')
    assert 'Vulkan' in appearance_log and 'Forward+' in appearance_log and 'ERROR:' not in appearance_log
    assert len(appearance['samples']) == 12
    assert render['failures'] == 0 and len(render['samples']) == 40 and len(render['death_entries']) == 4
    assert render['inputs_sha256']['res://local-art/creatures/solen_queens/grounded.json'] == sha(GROUNDED)
    for proof in (terrain, render):
        for name, digest in proof['runtime_sha256'].items():
            assert Path(name).name == name and sha(RUNTIME / name) == digest
    subprocess.run([sys.executable, str(SCRIPTS / 'test-creature-presentation-batch.py'),
                    '--preparation', 'solen_queens/grounded.json', '--output', str(WORK / 'presentation'),
                    '--merge-only'], check=True)
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    options = parser.add_mutually_exclusive_group()
    options.add_argument('--write-tests', action='store_true')
    options.add_argument('--publish', action='store_true')
    options.add_argument('--check-active', action='store_true')
    args = parser.parse_args()
    subprocess.run([sys.executable, str(SCRIPTS / 'prepare-solen-queens.py'), '--check-prepared'], check=True)
    if args.write_tests:
        write(GROUNDED, grounded())
        for name, text in bound_tests().items():
            (WORK / name).write_text(text, encoding='utf-8')
        return
    rows = verified_rows()
    receipt = {'publisher_sha256': sha(Path(__file__)), 'grounded_sha256': sha(GROUNDED)}
    path = ART / 'accepted-index.json'
    index = read(path)
    existing = [row for row in index['entries'] if BODY_KEYS.intersection(int(body['body']) for body in row['bodies'])]
    assert all(row['family'] == 'solen_queens' for row in existing), 'Refusing to replace an unrelated body route'
    rows = ALIAS_EVIDENCE['expected_rows_with_legacy_aliases'](rows, index['entries'])
    if args.check_active:
        assert existing == rows
        ALIAS_EVIDENCE['check_base_receipt'](Path(__file__).name, read(RECEIPT), receipt)
    if args.publish:
        backup = WORK / 'accepted-index-before-queens.json'
        if not backup.exists():
            backup.write_bytes(path.read_bytes())
        index['entries'] = [row for row in index['entries'] if row not in existing] + rows
        write(path, index)
        write(RECEIPT, receipt)
    print('SOLEN QUEEN ROUTES:', 'published' if args.publish else 'active verified' if args.check_active else 'dry run')


if __name__ == '__main__':
    main()
