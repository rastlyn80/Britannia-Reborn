"""Prepare the original Ant Lion with strictly scoped chain-label repairs.

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
WORK = ROOT/'work/creatures/ant-lion/final'
ART = ROOT/'Viewer/local-art/creatures'
MANIFEST = ROOT/'scripts/ant-lion-chain-inputs.json'
OUTPUT = ART/'ant_lion_chain/preparation.json'
BAKER = ROOT/'Viewer/Presentation/BakeSourcePreserving.gd'
BASE_PREPARER_SHA = 'dd559047dc3aece5fcc71f573021b5f967b5c3a6cf09a3d86f98673ed9e3d303'


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name,ROOT/'scripts'/filename)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def recipe():
    base = module('ant_preserving','prepare-source-preserving.py')
    labels = module('ant_labels','creature-ant-lion-labels.py')
    base.MANIFEST, base.WORK = MANIFEST, WORK
    original = base.pipeline_for
    source = json.loads(MANIFEST.read_text())['models'][0]

    def pipeline_for(kind):
        assert kind == 'ant_lion'
        pipeline = original(kind)
        labels.install(pipeline,source)
        pipeline.ant_lion_labels = labels
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
            'const INPUT="res://../work/creatures/ant-lion/final/preparation.json"',
        'const OUTPUT="res://local-art/creatures/source_preserving/preparation.json"':
            'const OUTPUT="res://local-art/creatures/ant_lion_chain/preparation.json"'}.items():
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
    assert report['chain_preparer_sha256'] in {BASE_PREPARER_SHA, base.sha(Path(__file__))}
    assert report['baker_sha256'] == base.sha(BAKER)
    assert report['subdivision_sha256'] == base.sha(base.RECIPE)
    assert report['bound_baker_sha256'] == base.sha(WORK/'BakeAntLion.gd')
    assert (WORK/'BakeAntLion.gd').read_text() == bound_baker()
    assert report['native_metadata_sha256'] == base.native_metadata_stamp()
    assert report['server_pin'] == pins['server_pin'] and len(report['models']) == 1
    row, source = report['models'][0], pins['models'][0]
    assert row['source_provenance'] == source and row['kind'] == 'ant_lion'
    assert row['converter_sha256'] == base.converter_pins(base.pipeline_for('ant_lion'))
    assert row['family'] == 'ant_lion_chain' and row['source_opacity'] == 'opaque'
    assert [identity['body'] for identity in row['bodies']] == [787]
    assert row['stats']['original']['bones'] == source['bones'] == 53
    assert row['stats']['original']['triangles'] == source['triangles'] == 1086
    assert len(row['clip_sources']) == source['source_clips'] == 10
    assert not row['rejected_source_clips'] and not row['authored_replacements']
    assert row['category_aliases'] == {'Run':'Walk'}
    assert row['refinement']['triangles_after'] == 4344
    for name, digest in report['runtime_sha256'].items():
        assert base.sha(ROOT/'Viewer/Presentation'/name) == digest, name
    for treatment, asset in row['assets'].items():
        path = ROOT/'Viewer'/asset.removeprefix('res://')
        assert path.parent == ART and path.name == f'ant_lion-chain-{treatment}.scn'
        assert base.sha(path) == row['saved_scenes'][treatment]['scene_sha256']
    for name, digest in row['art_dependency_sha256'].items():
        assert Path(name).name == name and base.sha(ART/name) == digest
    print('ANT LION PREPARATION: exact13source members,53model joints,10original clips, '
          'indexed right-pincer/whitespace labels and4344-triangle saved skins. No acceptance/native claim.')


def tests(base, actions=False):
    check(base)
    name = 'SourcePreservingActionTests.gd' if actions else 'SourcePreservingSkinTests.gd'
    source = (ROOT/'Viewer/Presentation'/name).read_text(encoding='utf-8-sig')
    replacements = {
        'res://local-art/creatures/source_preserving/':'res://local-art/creatures/ant_lion_chain/',
        'res://../work/creatures/source-preserving':'res://../work/creatures/ant-lion/final'}
    if not actions:
        replacements['res://../scripts/source-preserving-inputs.json'] = 'res://../scripts/ant-lion-chain-inputs.json'
    for before, after in replacements.items():
        assert before in source, 'Review changed shared test I/O'
        source = source.replace(before,after)
    script = WORK/name
    script.write_text(source,encoding='utf-8')
    runner = script
    if actions:
        # Keep the original bound test and its receipt intact. The active
        # successor has a separate gate for its saved scenes and native actions.
        runner = WORK/'RetainedAntLionActions.gd'
        runner.write_text('''extends "res://../work/creatures/ant-lion/final/SourcePreservingActionTests.gd"

const SealedBase := preload("res://Presentation/SealedCreatureActionBase.gd")

func run() -> void:
	var active := Registry.entry(787)
	if active.get("classic_gesture_batch") == "post_solen_actions":
		Registry.entries[787] = SealedBase.retained(active, 787)
	super.run()
''', encoding='utf-8')
    godot(runner,WORK/('actions.log' if actions else 'skin.log'))
    path = WORK/('actions.json' if actions else 'skin-proof.json')
    proof = json.loads(path.read_text())
    assert proof['failures'] == 0 and proof['checks'] > 0
    assert proof['preparation_sha256'] == base.sha(OUTPUT)
    assert proof['test_sha256'] == base.sha(ROOT/'Viewer/Presentation'/name)
    proof['bound_test_sha256'] = base.sha(script)
    path.write_text(json.dumps(proof,indent=2)+'\n',encoding='utf-8')
    print('ANT LION SHARED TEST:',name,proof['checks'],'checks/0failures')


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
    row['family'] = 'ant_lion_chain'
    row['assets'] = {name:f'res://local-art/creatures/ant_lion-chain-{name}.scn'
                     for name in ['original','rounded','modern']}
    row['source_interpretation'] = ('Own original table787 mesh/atlas/rig/ten clips; two exact right-pincer labels '
                                    'and unique whitespace aliases corrected without numeric edits. All53model '
                                    'joints remain; all38weighted/ancestor names must match. Existing30Hz '
                                    'affine-to-rigid normalization remains an approximation. Source-only '
                                    'mound/rock effect subtrees are not part of this body mesh. Run explicitly reuses Walk.')
    path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    script = WORK/'BakeAntLion.gd'
    script.write_text(bound_baker(),encoding='utf-8')
    godot(script,WORK/'bake.log')
    report = json.loads(OUTPUT.read_text())
    report.update(chain_preparer_sha256=base.sha(Path(__file__)),bound_baker_sha256=base.sha(script))
    OUTPUT.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    check(base)


if __name__ == '__main__':
    main()
