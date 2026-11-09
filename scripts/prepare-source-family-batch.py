"""Prepare a separate source family batch with the established skin/bake recipe.

Original inputs and every generated asset remain local. The existing accepted
source-preserving batch, donor scenes and its evidence are never replaced.
"""
import argparse
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT/'work/creatures/shared-batch/preserving'
ART = ROOT/'Viewer/local-art/creatures'
OUTPUT = ART/'source_family_batch/preparation.json'
MANIFEST = ROOT/'scripts/source-family-batch-inputs.json'
BAKER = ROOT/'Viewer/Presentation/BakeSourcePreserving.gd'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def recipe():
    spec = importlib.util.spec_from_file_location('family_recipe', ROOT/'scripts/prepare-source-preserving.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.MANIFEST, module.WORK = MANIFEST, WORK
    return module


def mineral():
    index = json.loads((ART/'accepted-index.json').read_text())
    donor = next(row for row in index['entries'] if row['kind'] == 'elementals_bronze_elemental')
    material = copy.deepcopy(donor['mineral_surface'])
    material.update(colour='dbb34c', metallic=.9, roughness_range=[.23,.48])
    material['interpretation'] += ' Gold palette on the original Golden Elemental mesh and UVs.'
    return material


def check(module):
    pins = module.inputs()
    report = json.loads(OUTPUT.read_text())
    # The earlier preparer baked the identical pinned base package.
    assert report['batch_preparer_sha256'] in (
        sha(Path(__file__)), '7106ccdf3e7754da0bc212b6bd00591d3e0a3cfb14fac539a7340bd82d48e782',
        'bbb3b8020275c609ea7dc5f8d18c4e5ba523554991975f51c1ee76003b5962d5')
    assert report['manifest_sha256'] == sha(MANIFEST)
    assert report['preparer_sha256'] == sha(ROOT/'scripts/prepare-source-preserving.py')
    assert report['baker_sha256'] == sha(BAKER)
    assert report['subdivision_sha256'] == sha(module.RECIPE)
    assert report['native_metadata_sha256'] == module.native_metadata_stamp()
    assert report['server_pin'] == pins['server_pin']
    assert len(report['models']) == len(pins['models'])
    for row, source in zip(report['models'], pins['models']):
        assert row['source_provenance'] == source
        assert row['converter_sha256'] == module.converter_pins(module.pipeline_for(row['kind']))
        assert [identity['body'] for identity in row['bodies']] == source['expected_bodies']
        assert len(row['clip_sources']) == source['source_clips']
        assert row['stats']['original']['bones'] == source['bones']
        assert row['stats']['original']['triangles'] == source['triangles']
        for treatment, path in row['assets'].items():
            asset = ROOT/'Viewer'/path.removeprefix('res://')
            assert asset.parent == ART and sha(asset) == row['saved_scenes'][treatment]['scene_sha256']
        for name, digest in row['art_dependency_sha256'].items():
            assert Path(name).name == name and sha(ART/name) == digest
        if row['kind'] == 'elementals_gold_elemental':
            assert row['mineral_surface'] == mineral()
    for name, digest in report['runtime_sha256'].items():
        assert sha(ROOT/'Viewer/Presentation'/name) == digest, name
    print('SOURCE FAMILY BATCH:', len(report['models']), 'current original source/skin/scene/material records; no route changed')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-prepared', action='store_true')
    parser.add_argument('--check-skins', action='store_true',help='Reuse the established complete-skin/static-corpse tests on this batch')
    parser.add_argument('--check-actions', action='store_true',help='Reuse native action timing and full/partial hue contracts')
    args = parser.parse_args()
    module = recipe()
    if args.check_actions:
        check(module)
        base = ROOT/'Viewer/Presentation/SourcePreservingActionTests.gd'
        source = base.read_text(encoding='utf-8-sig')
        for before, after in {
            'res://local-art/creatures/source_preserving/':'res://local-art/creatures/source_family_batch/',
            'res://../work/creatures/source-preserving':'res://../work/creatures/shared-batch'}.items():
            assert source.count(before) == 2, 'Review changed shared action-test I/O'
            source = source.replace(before,after)
        # The publisher separately checks the exact new scenes and native receipt.
        old = 'registered.assets==entry.assets'
        new = ('registered.get("classic_gesture_base_assets",'
               'registered.get("authored_action_base_assets",registered.assets))==entry.assets')
        assert source.count(old) == 1
        source = source.replace(old, new)
        old = 'registered.presentation_script==entry.presentation_script'
        new = (f'({old} or (body==155 and registered.get("classic_gesture_batch","")=="avenger_rotting_actions"'
               ' and registered.presentation_script=="res://Presentation/RottingCorpseActionsVisual.gd")'
               ' or (body==753 and registered.has("preferred_uop_native_sha256")'
               ' and registered.presentation_script=="res://Presentation/ArchiveSourcePreservingGestureVisual.gd"))')
        assert source.count(old) == 1
        source = source.replace(old, new)
        script = WORK/'FamilyActionTests.gd'
        script.write_text(source,encoding='utf-8')
        environment = os.environ.copy()
        environment['APPDATA'] = environment['LOCALAPPDATA'] = str(ROOT/'.godot-user')
        godot = next((ROOT/'.tools/godot').glob('*console.exe'))
        result = subprocess.run([str(godot),'--headless','--path',str(ROOT/'Viewer'),'--script',str(script)],
                                env=environment,capture_output=True,text=True,timeout=150)
        output = result.stdout+result.stderr
        (WORK/'actions.log').write_text(output,encoding='utf-8')
        assert result.returncode == 0 and 'ERROR:' not in output, output[-5000:]
        proof_path = ROOT/'work/creatures/shared-batch/actions.json'
        proof = json.loads(proof_path.read_text())
        assert proof['failures'] == 0 and proof['preparation_sha256'] == sha(OUTPUT)
        assert proof['test_sha256'] == sha(base)
        proof['bound_test_sha256'] = sha(script)
        proof_path.write_text(json.dumps(proof,indent=2)+'\n',encoding='utf-8')
        print('SOURCE FAMILY ACTIONS:',proof['checks'],'checks; original cast timing/hue/skin assertions')
        return
    if args.check_skins:
        check(module)
        base = ROOT/'Viewer/Presentation/SourcePreservingSkinTests.gd'
        source = base.read_text(encoding='utf-8-sig')
        for before, after in {
            'res://local-art/creatures/source_preserving/preparation.json':'res://local-art/creatures/source_family_batch/preparation.json',
            'res://../scripts/source-preserving-inputs.json':'res://../scripts/source-family-batch-inputs.json',
            'res://../work/creatures/source-preserving/skin-proof.json':'res://../work/creatures/shared-batch/skin-proof.json'}.items():
            assert source.count(before) == 1, 'Review changed shared skin-test I/O'
            source = source.replace(before,after)
        script = WORK/'FamilySkinTests.gd'
        script.write_text(source,encoding='utf-8')
        environment = os.environ.copy()
        environment['APPDATA'] = environment['LOCALAPPDATA'] = str(ROOT/'.godot-user')
        godot = next((ROOT/'.tools/godot').glob('*console.exe'))
        result = subprocess.run([str(godot),'--headless','--path',str(ROOT/'Viewer'),'--script',str(script)],
                                env=environment,capture_output=True,text=True,timeout=200)
        output = result.stdout+result.stderr
        (WORK/'skin.log').write_text(output,encoding='utf-8')
        assert result.returncode == 0 and 'ERROR:' not in output, output[-5000:]
        proof_path = ROOT/'work/creatures/shared-batch/skin-proof.json'
        proof = json.loads(proof_path.read_text())
        assert proof['failures'] == 0 and proof['preparation_sha256'] == sha(OUTPUT)
        assert proof['test_sha256'] == sha(base)
        proof['bound_test_sha256'] = sha(script)
        proof_path.write_text(json.dumps(proof,indent=2)+'\n',encoding='utf-8')
        print('SOURCE FAMILY SKINS:',proof['checks'],'checks; unchanged shared assertions, batch-specific input/output')
        return
    if args.check_prepared:
        check(module)
        return
    module.prepare()
    # Reuse the unchanged owned baker, binding only its two I/O constants.
    # Keep the old batch and its exact baker receipt unchanged.
    source = BAKER.read_text(encoding='utf-8-sig')
    replacements = {
        'const INPUT="res://../work/creatures/source-preserving/preparation.json"':
            'const INPUT="res://../work/creatures/shared-batch/preserving/preparation.json"',
        'const OUTPUT="res://local-art/creatures/source_preserving/preparation.json"':
            'const OUTPUT="res://local-art/creatures/source_family_batch/preparation.json"'}
    for before, after in replacements.items():
        assert source.count(before) == 1, 'Review changed shared baker I/O'
        source = source.replace(before, after)
    script = WORK/'BakeFamilyBatch.gd'
    script.write_text(source, encoding='utf-8')
    environment = os.environ.copy()
    environment['APPDATA'] = environment['LOCALAPPDATA'] = str(ROOT/'.godot-user')
    godot = next((ROOT/'.tools/godot').glob('*console.exe'))
    result = subprocess.run([str(godot),'--headless','--path',str(ROOT/'Viewer'),'--script',str(script)],
                            env=environment,capture_output=True,text=True,timeout=200)
    output = result.stdout+result.stderr
    (WORK/'bake.log').write_text(output,encoding='utf-8')
    assert result.returncode == 0 and 'ERROR:' not in output, output[-5000:]
    report = json.loads(OUTPUT.read_text())
    report.update(batch_preparer_sha256=sha(Path(__file__)),bound_baker_sha256=sha(script))
    for row in report['models']:
        if row['kind'] == 'elementals_gold_elemental':row['mineral_surface'] = mineral()
    for name in ['CreatureMineralMaterial.gd','CreatureMineralSurface.gdshader']:
        report['runtime_sha256'][name] = sha(ROOT/'Viewer/Presentation'/name)
    OUTPUT.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    check(module)


if __name__ == '__main__':
    main()
