"""Bake the original Ethereal Beetle as private art for its mounted item."""
import argparse
import copy
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KIND = 'giant_beetle_ethereal'
WORK = ROOT / 'work/creatures/giant-beetle/ethereal-final'
MANIFEST = ROOT / 'scripts/ethereal-beetle-inputs.json'
spec = importlib.util.spec_from_file_location('beetle_tools', ROOT / 'scripts/prepare-giant-beetle.py')
tools = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tools)
OUTPUT = tools.ART / KIND / 'preparation.json'


def baker_text():
    return (tools.BAKER.read_text(encoding='utf-8-sig')
            .replace('res://../work/creatures/source-preserving/',
                     'res://../work/creatures/giant-beetle/ethereal-final/')
            .replace('res://local-art/creatures/source_preserving/',
                     'res://local-art/creatures/giant_beetle_ethereal/'))


def recipe():
    base = tools.module('ethereal_beetle_source', 'prepare-source-preserving.py')
    labels = tools.module('beetle_labels', 'creature-giant-beetle-labels.py')
    base.MANIFEST, base.WORK = MANIFEST, WORK
    source, = base.inputs()['models']
    model = next(record for record in source['files'] if record['member'].endswith('_lod2.grn'))
    atlas = next(record for record in source['files'] if record['member'].endswith('_256.tga'))
    assert Path(model['path']).name == 'giant_beetle_ethereal_lod2.grn'
    raw = (ROOT / atlas['path']).read_bytes()
    assert raw[:18].hex() == '000002000000000000000000800080002008'
    alpha = raw[21:18 + 128 * 128 * 4:4]
    assert [min(alpha), max(alpha)] == source['source_atlas_alpha_range'] == [180, 212]
    label_source = copy.deepcopy(source)
    next(record for record in label_source['files'] if record['member'] == model['member'])['path'] = 'giant_beetle_lod2.grn'
    original = base.pipeline_for

    def pipeline_for(kind):
        assert kind == KIND
        pipeline = original(kind)
        labels.install(pipeline, label_source)
        pipeline.giant_beetle_labels = labels
        return pipeline

    base.pipeline_for = pipeline_for
    return base, source


def check(base, source):
    sha = base.sha
    report = json.loads(OUTPUT.read_text())
    assert report['manifest_sha256'] == sha(MANIFEST)
    assert report['ethereal_preparer_sha256'] == sha(Path(__file__))
    assert report['preparer_sha256'] == sha(Path(base.__file__))
    assert report['baker_sha256'] == sha(tools.BAKER)
    assert report['subdivision_sha256'] == sha(base.RECIPE)
    assert report['native_metadata_sha256'] == base.native_metadata_stamp()
    bound = WORK / 'BakeEtherealBeetle.gd'
    assert bound.read_text(encoding='utf-8') == baker_text()
    assert report['bound_baker_sha256'] == sha(bound)
    row, = report['models']
    assert row['source_provenance'] == source and row['kind'] == row['family'] == KIND
    assert row['mount_only'] is True and row['mount_item'] == 0x3E97
    body, = row['bodies']
    assert body['body'] == 195 and body['animation_body'] == 791 and not body['native_sources']
    assert row['converter_sha256'] == base.converter_pins(base.pipeline_for(KIND))
    assert row['stats']['original']['bones'] == 51
    assert row['refinement']['triangles_before'] == 1102 and row['refinement']['triangles_after'] == 4408
    assert len(row['clip_sources']) == 10 and not row['rejected_source_clips'] and not row['authored_replacements']
    assert row['presentation_script_sha256'] == sha(ROOT / 'Viewer/Presentation/SourceEtherealBeetleVisual.gd')
    assert row['spectral_shader_sha256'] == sha(ROOT / 'Viewer/Presentation/SourceEtherealBeetleSurface.gdshader')
    assert report['runtime_sha256'] == {name: sha(ROOT / 'Viewer/Presentation' / name) for name in base.RUNTIME}
    for treatment, asset in row['assets'].items():
        name = f'{KIND}-{treatment}.scn'
        assert asset == f'res://local-art/creatures/{name}'
        assert sha(tools.ART / name) == row['saved_scenes'][treatment]['scene_sha256']
    for name, digest in row['art_dependency_sha256'].items():
        assert Path(name).name == name and sha(tools.ART / name) == digest
    print('ETHEREAL BEETLE PREPARATION: 51 joints, ten linked clips, 4408 triangles, original 128px RGBA atlas')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-prepared', action='store_true')
    args = parser.parse_args()
    base, source = recipe()
    if not args.check_prepared:
        base.prepare()
        intermediate = WORK / 'preparation.json'
        report = json.loads(intermediate.read_text())
        report['models'][0].update(
            family=KIND, mount_only=True,
            spectral_shader_sha256=base.sha(ROOT / 'Viewer/Presentation/SourceEtherealBeetleSurface.gdshader'))
        intermediate.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        script = WORK / 'BakeEtherealBeetle.gd'
        script.write_text(baker_text(), encoding='utf-8')
        tools.godot(script, WORK / 'bake.log')
        report = json.loads(OUTPUT.read_text())
        report.update(ethereal_preparer_sha256=base.sha(Path(__file__)), bound_baker_sha256=base.sha(script))
        OUTPUT.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    check(base, source)


if __name__ == '__main__':
    main()
