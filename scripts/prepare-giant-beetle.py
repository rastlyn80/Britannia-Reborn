"""Prepare the original Giant Beetle with strictly scoped chain-label repairs.

Reuses the existing source-preserving converter/baker/tests without editing
their shared implementation. Original artwork and all outputs remain local.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT/'work/creatures/giant-beetle/final'
ART = ROOT/'Viewer/local-art/creatures'
MANIFEST = ROOT/'scripts/giant-beetle-inputs.json'
OUTPUT = ART/'giant_beetle/preparation.json'
BAKER = ROOT/'Viewer/Presentation/BakeSourcePreserving.gd'


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name,ROOT/'scripts'/filename)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def recipe():
    base = module('ant_preserving','prepare-source-preserving.py')
    labels = module('ant_labels','creature-giant-beetle-labels.py')
    base.MANIFEST, base.WORK = MANIFEST, WORK
    original = base.pipeline_for
    source = json.loads(MANIFEST.read_text())['models'][0]

    def pipeline_for(kind):
        assert kind == 'giant_beetle'
        pipeline = original(kind)
        labels.install(pipeline,source)
        pipeline.giant_beetle_labels = labels
        return pipeline

    base.pipeline_for = pipeline_for
    # Preparation executes the indexed repair guards for every original clip;
    # checking an existing bake below hashes its exact tools and saved scenes.
    base.cached_candidate = lambda *args, **kwargs: None
    return base


def bound_baker():
    source = BAKER.read_text(encoding='utf-8-sig')
    for before, after in {
        'const INPUT="res://../work/creatures/source-preserving/preparation.json"':
            'const INPUT="res://../work/creatures/giant-beetle/final/preparation.json"',
        'const OUTPUT="res://local-art/creatures/source_preserving/preparation.json"':
            'const OUTPUT="res://local-art/creatures/giant_beetle/preparation.json"'}.items():
        assert source.count(before) == 1, 'Review changed shared baker I/O'
        source = source.replace(before,after)
    return source


def godot(script, log):
    executable = next((ROOT/'.tools/godot').glob('*console.exe'))
    env = os.environ.copy()
    env['APPDATA'] = env['LOCALAPPDATA'] = str(ROOT/'.godot-user')
    result = subprocess.run([str(executable),'--headless','--path',str(ROOT/'Viewer'),
                             '--script',str(script)],env=env,cwd=ROOT,capture_output=True,
                            text=True,encoding='utf-8',errors='replace',timeout=240)
    text = result.stdout+result.stderr
    log.write_text(text,encoding='utf-8')
    assert result.returncode == 0 and 'ERROR:' not in text, text[-4000:]


def check(base):
    pins = base.inputs()
    report = json.loads(OUTPUT.read_text())
    assert report['manifest_sha256'] == base.sha(MANIFEST)
    assert report['preparer_sha256'] == base.sha(ROOT/'scripts/prepare-source-preserving.py')
    assert report['chain_preparer_sha256'] == base.sha(Path(__file__))
    assert report['baker_sha256'] == base.sha(BAKER)
    assert report['subdivision_sha256'] == base.sha(base.RECIPE)
    assert report['bound_baker_sha256'] == base.sha(WORK/'BakeGiantBeetle.gd')
    assert (WORK/'BakeGiantBeetle.gd').read_text() == bound_baker()
    assert report['native_metadata_sha256'] == base.native_metadata_stamp()
    assert report['server_pin'] == pins['server_pin'] and len(report['models']) == 1
    row, source = report['models'][0], pins['models'][0]
    assert row['source_provenance'] == source and row['kind'] == 'giant_beetle'
    assert row['converter_sha256'] == base.converter_pins(base.pipeline_for('giant_beetle'))
    assert row['family'] == 'giant_beetle' and row['source_opacity'] == 'opaque'
    assert [identity['body'] for identity in row['bodies']] == [791]
    assert row['stats']['original']['bones'] == source['bones'] == 51
    assert row['stats']['original']['triangles'] == source['triangles'] == 1102
    assert len(row['clip_sources']) == source['source_clips'] == 10
    assert not row['rejected_source_clips'] and not row['authored_replacements']
    assert row['mount_item'] == 0x3EBC
    assert row['refinement']['triangles_after'] == 4408
    for name, digest in report['runtime_sha256'].items():
        assert base.sha(ROOT/'Viewer/Presentation'/name) == digest, name
    for treatment, asset in row['assets'].items():
        path = ROOT/'Viewer'/asset.removeprefix('res://')
        assert path.parent == ART and path.name == f'giant-beetle-{treatment}.scn'
        assert base.sha(path) == row['saved_scenes'][treatment]['scene_sha256']
    for name, digest in row['art_dependency_sha256'].items():
        assert Path(name).name == name and base.sha(ART/name) == digest
    print('GIANT BEETLE PREPARATION: 51 joints, ten original clips, 4408 refined triangles')


def tests(base, actions=False):
    check(base)
    name = 'SourcePreservingActionTests.gd' if actions else 'SourcePreservingSkinTests.gd'
    source = (ROOT/'Viewer/Presentation'/name).read_text(encoding='utf-8-sig')
    replacements = {
        'res://local-art/creatures/source_preserving/':'res://local-art/creatures/giant_beetle/',
        'res://../work/creatures/source-preserving':'res://../work/creatures/giant-beetle/final'}
    if not actions:
        replacements['res://../scripts/source-preserving-inputs.json'] = 'res://../scripts/giant-beetle-inputs.json'
    for before, after in replacements.items():
        assert before in source, 'Review changed shared test I/O'
        source = source.replace(before,after)
    script = WORK/name
    script.write_text(source,encoding='utf-8')
    godot(script,WORK/('actions.log' if actions else 'skin.log'))
    path = WORK/('actions.json' if actions else 'skin-proof.json')
    proof = json.loads(path.read_text())
    assert proof['failures'] == 0 and proof['checks'] > 0
    assert proof['preparation_sha256'] == base.sha(OUTPUT)
    assert proof['test_sha256'] == base.sha(ROOT/'Viewer/Presentation'/name)
    proof['bound_test_sha256'] = base.sha(script)
    path.write_text(json.dumps(proof,indent=2)+'\n',encoding='utf-8')
    print('GIANT BEETLE SHARED TEST:',name,proof['checks'],'checks/0failures')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--check-prepared',action='store_true')
    group.add_argument('--check-skins',action='store_true')
    group.add_argument('--check-actions',action='store_true')
    args = parser.parse_args()
    base = recipe()
    if args.check_prepared:
        check(base)
        return
    if args.check_skins or args.check_actions:
        tests(base,args.check_actions)
        return
    base.prepare()
    path = WORK/'preparation.json'
    report = json.loads(path.read_text())
    row = report['models'][0]
    row['family'] = 'giant_beetle'
    row['assets'] = {name:f'res://local-art/creatures/giant-beetle-{name}.scn'
                     for name in ['original','rounded','modern']}
    row['source_interpretation'] = (
        'Original body 791 rig, opaque atlas and ten clips. The clip hierarchy '
        'restores the model identity parent and reconciles exact bone labels. '
        'The existing rigid bake approximates source affine motion. The mount '
        'uses authored shell proportions and saddle, rein and stirrup fittings.'
    )
    path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    script = WORK/'BakeGiantBeetle.gd'
    script.write_text(bound_baker(),encoding='utf-8')
    godot(script,WORK/'bake.log')
    report = json.loads(OUTPUT.read_text())
    report.update(chain_preparer_sha256=base.sha(Path(__file__)),bound_baker_sha256=base.sha(script))
    OUTPUT.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    check(base)


if __name__ == '__main__':
    main()
