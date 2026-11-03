"""Build the Fire Beetle from its private source model, atlas and linked motions."""
import argparse
import copy
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KIND = 'giant_beetle_fire'
WORK = ROOT / 'work/creatures/giant-beetle/fire-final'
MANIFEST = ROOT / 'scripts/fire-beetle-inputs.json'

spec = importlib.util.spec_from_file_location('beetle_build', ROOT / 'scripts/prepare-giant-beetle.py')
shared = importlib.util.module_from_spec(spec)
spec.loader.exec_module(shared)
ART = shared.ART
OUTPUT = ART / KIND / 'preparation.json'


def bind(script):
    source = script.read_text(encoding='utf-8-sig')
    for old, new in {
        'res://../work/creatures/source-preserving': 'res://../work/creatures/giant-beetle/fire-final',
        'res://local-art/creatures/source_preserving/': f'res://local-art/creatures/{KIND}/',
        'res://../scripts/source-preserving-inputs.json': 'res://../scripts/fire-beetle-inputs.json',
    }.items():
        source = source.replace(old, new)
    return source


def recipe():
    base = shared.module('fire_source', 'prepare-source-preserving.py')
    labels = shared.module('beetle_labels', 'creature-giant-beetle-labels.py')
    base.MANIFEST, base.WORK = MANIFEST, WORK
    original = base.pipeline_for
    source = base.inputs()['models'][0]
    # The shared repair expects the base rig's filename. Identify this single
    # proven variant by its exact pinned bytes before applying the same rules.
    label_source = copy.deepcopy(source)
    model = next(row for row in label_source['files'] if row['member'].endswith('_lod2.grn'))
    assert Path(model['path']).name == 'Giant_Beetle_Fire_LOD2.grn'
    model['path'] = 'giant_beetle_lod2.grn'

    def pipeline_for(kind):
        assert kind == KIND
        pipeline = original(kind)
        labels.install(pipeline, label_source)
        pipeline.giant_beetle_labels = labels
        return pipeline

    base.pipeline_for = pipeline_for
    base.cached_candidate = lambda *args, **kwargs: None
    return base, source


def check(base, source):
    report = json.loads(OUTPUT.read_text())
    sha = base.sha
    assert report['manifest_sha256'] == sha(MANIFEST)
    assert report['variant_preparer_sha256'] == sha(Path(__file__))
    assert report['preparer_sha256'] == sha(Path(base.__file__))
    assert report['baker_sha256'] == sha(shared.BAKER)
    assert report['subdivision_sha256'] == sha(base.RECIPE)
    assert report['bound_baker_sha256'] == sha(WORK / 'BakeFireBeetle.gd')
    assert (WORK / 'BakeFireBeetle.gd').read_text() == bind(shared.BAKER)
    assert report['native_metadata_sha256'] == base.native_metadata_stamp()
    assert len(report['models']) == 1
    row = report['models'][0]
    assert row['source_provenance'] == source and row['family'] == row['kind'] == KIND
    assert row['converter_sha256'] == base.converter_pins(base.pipeline_for(KIND))
    assert len(row['bodies']) == 1
    identity = row['bodies'][0]
    assert identity['body'] == 169 and identity['native_profile'] == 'animal'
    assert identity['animation_body'] == source['original_animation_body'] == 791
    assert identity['scale'] == source['original_scale'] == [1, 1, 1]
    assert row['mount_item'] == 0x3E95 and row['source_opacity'] == 'opaque'
    assert len(row['clip_sources']) == 10
    assert not row['rejected_source_clips'] and not row['authored_replacements']
    assert row['stats']['original']['bones'] == 51
    assert row['refinement']['triangles_before'] == 1102
    assert row['refinement']['triangles_after'] == 4408
    runtime = ROOT / 'Viewer/Presentation'
    assert report['runtime_sha256'] == {name: sha(runtime / name) for name in base.RUNTIME}
    assert row['presentation_script_sha256'] == sha(runtime / 'SourceFireBeetleVisual.gd')
    for treatment in ('original', 'rounded', 'modern'):
        name = f'{KIND}-{treatment}.scn'
        assert row['assets'][treatment] == f'res://local-art/creatures/{name}'
        assert sha(ART / name) == row['saved_scenes'][treatment]['scene_sha256']
    for name, digest in row['art_dependency_sha256'].items():
        assert Path(name).name == name and sha(ART / name) == digest
    print('FIRE BEETLE PREPARATION: body 169, 51 joints, ten linked clips, 4408 refined triangles')
    return row


def test(base, actions):
    name = 'SourcePreservingActionTests.gd' if actions else 'SourcePreservingSkinTests.gd'
    original = ROOT / 'Viewer/Presentation' / name
    script = WORK / name
    script.write_text(bind(original), encoding='utf-8')
    label = 'actions' if actions else 'skin'
    shared.godot(script, WORK / (label + '.log'))
    proof = WORK / ('actions.json' if actions else 'skin-proof.json')
    data = json.loads(proof.read_text())
    assert data['failures'] == 0 and data['checks'] > 0
    assert data['preparation_sha256'] == base.sha(OUTPUT)
    assert data['test_sha256'] == base.sha(original)
    data['bound_test_sha256'] = base.sha(script)
    proof.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
    print('FIRE BEETLE', label, data['checks'], 'checks, zero failures')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    options = parser.add_mutually_exclusive_group()
    options.add_argument('--check-prepared', action='store_true')
    options.add_argument('--check-skins', action='store_true')
    options.add_argument('--check-actions', action='store_true')
    args = parser.parse_args()
    base, source = recipe()
    if args.check_prepared or args.check_skins or args.check_actions:
        check(base, source)
        if not args.check_prepared:
            test(base, args.check_actions)
        return
    base.prepare()
    input_path = WORK / 'preparation.json'
    report = json.loads(input_path.read_text())
    report['models'][0]['family'] = KIND
    input_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    script = WORK / 'BakeFireBeetle.gd'
    script.write_text(bind(shared.BAKER), encoding='utf-8')
    shared.godot(script, WORK / 'bake.log')
    report = json.loads(OUTPUT.read_text())
    report.update(variant_preparer_sha256=base.sha(Path(__file__)), bound_baker_sha256=base.sha(script))
    OUTPUT.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    check(base, source)


if __name__ == '__main__':
    main()
