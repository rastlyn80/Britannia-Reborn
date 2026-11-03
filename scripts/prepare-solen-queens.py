"""Build both original Solen Queen meshes with a bounded authored normal repair."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import runpy
import shutil
import struct

SCRIPTS = Path(__file__).resolve().parent
tools = runpy.run_path(str(SCRIPTS / 'prepare-giant-beetle.py'))
base = tools['module']('queen_source', 'prepare-source-preserving.py')
ROOT = base.ROOT
WORK = ROOT / 'work/creatures/solen-queen-source/final'
MANIFEST = SCRIPTS / 'solen-queen-inputs.json'
OUTPUT = base.ART / 'solen_queens' / 'preparation.json'
BAKER = tools['BAKER']
base.MANIFEST, base.WORK = MANIFEST, WORK


def repaired(raw, reader, contract):
    assert hashlib.sha256(raw).hexdigest() == contract['original_sha256']
    buffers = [payload for tag, payload, _ in reader.chunks(raw) if tag == 0xca5e0802]
    assert len(buffers) == 1 and raw.count(buffers[0]) == 1
    normals, = buffers
    invalid = [index for index, vector in enumerate(struct.iter_unpack('<3f', normals))
               if not all(math.isfinite(value) for value in vector)]
    assert invalid == [row['index'] for row in contract['replacements']] == [100, 101, 118, 257, 258, 272]
    offset = raw.index(normals)
    output = bytearray(raw)
    for row in contract['replacements']:
        vector = bytes.fromhex(row['normal_f32le'])
        assert 5000 < row['face_coherence_basis_points'] <= 10000
        assert abs(math.hypot(*struct.unpack('<3f', vector)) - 1) < 1e-6
        start = offset + 12 * row['index']
        output[start:start + 12] = vector
    assert hashlib.sha256(output).hexdigest() == contract['repaired_sha256']
    return bytes(output)


def bind_baker():
    code = BAKER.read_text(encoding='utf-8-sig')
    for before, after in {
        'res://../work/creatures/source-preserving/': 'res://../work/creatures/solen-queen-source/final/',
        'res://local-art/creatures/source_preserving/': 'res://local-art/creatures/solen_queens/',
    }.items():
        assert code.count(before) == 1
        code = code.replace(before, after)
    return code


def check(sources):
    sha = base.sha
    report = json.loads(OUTPUT.read_text())
    assert report['manifest_sha256'] == sha(MANIFEST)
    assert report['queen_preparer_sha256'] == sha(Path(__file__))
    assert report['baker_sha256'] == sha(BAKER)
    assert report['subdivision_sha256'] == sha(base.RECIPE)
    assert report['native_metadata_sha256'] == base.native_metadata_stamp()
    assert report['runtime_sha256'] == {name: sha(ROOT / 'Viewer/Presentation' / name) for name in base.RUNTIME}
    assert (WORK / 'BakeSolenQueens.gd').read_text(encoding='utf-8') == bind_baker()
    assert report['bound_baker_sha256'] == sha(WORK / 'BakeSolenQueens.gd')
    for row in report['models']:
        kind = row['kind']
        assert row['family'] == 'solen_queens' and row['source_provenance'] == sources[kind]
        assert row['converter_sha256'] == base.converter_pins(base.pipeline_for(kind))
        body, = row['bodies']
        assert body['body'] == sources[kind]['expected_bodies'][0] and body['native_profile'] == 'monster'
        assert body['animation_body'] == sources[kind]['source_animation_body'] and body['scale'] == [1.3] * 3
        native_classes = {Path(source['path'].replace('\\', '/')).stem for source in body['native_sources']}
        assert row['native_constructor_hues'] == sources[kind]['native_constructor_hues']
        assert native_classes == set(row['native_constructor_hues'])
        assert row['presentation_script_sha256'] == sha(ROOT / 'Viewer/Presentation/SourceSolenWarriorVisual.gd')
        assert row['refinement']['triangles_before'] == 1488 and row['refinement']['triangles_after'] == 5952
        assert row['stats']['original']['bones'] == 44 and len(row['clip_sources']) == 10
        assert not row['rejected_source_clips'] and not row['authored_replacements']
        for treatment, asset in row['assets'].items():
            assert asset == f'res://local-art/creatures/solen_queens/{kind}-{treatment}.scn'
            assert sha(OUTPUT.parent / Path(asset).name) == row['saved_scenes'][treatment]['scene_sha256']
        atlas, = row['art_dependency_sha256']
        assert row['source_atlas_texture'] == atlas
        assert Path(atlas).name == atlas and sha(base.ART / atlas) == row['art_dependency_sha256'][atlas]
    assert {row['kind'] for row in report['models']} == sources.keys()
    print('SOLEN QUEENS PREPARATION: two original 44-joint rigs, ten clips each, six authored normals per mesh')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-prepared', action='store_true')
    args = parser.parse_args()
    sources = {row['kind']: row for row in base.inputs()['models']}
    original = base.pipeline_for

    def pipeline_for(kind):
        pipeline = original(kind)
        parse = pipeline.td.parse
        repair = sources[kind]['authored_normal_repair']

        def parse_queen(raw, **options):
            if hashlib.sha256(raw).hexdigest() == repair['original_sha256']:
                raw = repaired(raw, pipeline.td, repair)
            return parse(raw, **options)

        pipeline.td.parse = parse_queen
        return pipeline

    base.pipeline_for = pipeline_for
    if not args.check_prepared:
        # The shared cache has no independent pin for this parse adapter.
        base.cached_candidate = lambda *args, **kwargs: None
        original_art = base.ART
        base.ART = WORK / 'atlases'
        try:
            base.prepare()
        finally:
            base.ART = original_art
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        intermediate = WORK / 'preparation.json'
        report = json.loads(intermediate.read_text())
        for row in report['models']:
            atlas, = row['art_dependency_sha256']
            staged = WORK / 'atlases' / atlas
            final = base.ART / atlas
            if not final.exists():
                shutil.copyfile(staged, final)
            assert base.sha(final) == base.sha(staged)
            row['assets'] = {name: f"res://local-art/creatures/solen_queens/{row['kind']}-{name}.scn"
                             for name in row['assets']}
            row.update(family='solen_queens', source_atlas_texture=atlas,
                       native_constructor_hues=sources[row['kind']]['native_constructor_hues'])
        intermediate.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        script = WORK / 'BakeSolenQueens.gd'
        script.write_text(bind_baker(), encoding='utf-8')
        tools['godot'](script, WORK / 'bake.log')
        report = json.loads(OUTPUT.read_text())
        report.update(queen_preparer_sha256=base.sha(Path(__file__)), bound_baker_sha256=base.sha(script))
        OUTPUT.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    check(sources)


if __name__ == '__main__':
    main()
