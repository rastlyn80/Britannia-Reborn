"""Prepare original tribal dance references; never enable a runtime body/action."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'work/third-dawn/late-source-research/uoaos-source'
OUTPUT = ROOT / 'work/creatures/savages/dance-reference'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-inputs', action='store_true')
    args = parser.parse_args()
    manifest = ROOT / 'scripts/savage-dance-inputs.json'
    pins = json.loads(manifest.read_text(encoding='utf-8'))
    for row in pins['files']:
        path = (SOURCE / row['path']).resolve()
        assert path.is_relative_to(SOURCE.resolve()) and sha(path) == row['sha256'], row['path']
    for row in pins['source']['cabinets']:
        path = SOURCE.parent / 'uoaos-cabinets' / Path(row['zip_member']).name
        assert path.stat().st_size == row['bytes'] and sha(path) == row['sha256'], path
    for row in pins['native_sources']:
        assert sha(ROOT / 'Server/ModernUO' / row['path']) == row['sha256'], row['path']
    human = pins['human_inputs']
    assert sha(ROOT / human['path']) == human['sha256'], 'Modern human input manifest changed'
    human_pins = json.loads((ROOT / human['path']).read_text(encoding='utf-8'))
    for name, digest in human_pins['prepared_art'].items():
        assert sha(ROOT / name) == digest, name
    print('SAVAGE DANCE INPUTS: original members/cabinets, native Shaman and existing modern human art pass')
    if args.check_inputs:
        return
    spec = importlib.util.spec_from_file_location('savage_dance_pipeline', ROOT / 'scripts/prepare-creatures.py')
    pipeline = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(pipeline)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    rows = []
    allowed = {r['path'] for r in pins['files']}
    for gender, height in [('male', 1.8), ('female', 1.72)]:
        mesh = SOURCE / 'Models/Humans' / ('h_' + gender + '_lod2.grn')
        motion = SOURCE / 'Models/Humans' / ('h_' + gender + '_dance_tribal_01.grn')
        body = pipeline.td.parse(mesh.read_bytes(), scene_root_names=True, skip_unskinned_helpers=True, scale_shear_tracks=True)
        body, bind = pipeline.normalise_bind(mesh.read_bytes(), body)
        clip = pipeline.td.parse(motion.read_bytes(), animations_only=True, scene_root_names=True, scale_shear_tracks=True)
        clip, fold = pipeline.normalise_bind(motion.read_bytes(), clip)
        matched, omitted = pipeline.helper.match_animation(clip, body)
        assert len(body['bones']) == len(clip['bones']) == 43 and omitted == ['bip01 footsteps']
        assert len(matched['bones']) == 42
        assert len(set(body['textures'])) == 1
        atlas = SOURCE / 'Models/Maps' / body['textures'][0]
        assert atlas.relative_to(SOURCE).as_posix() in allowed
        output = OUTPUT / (gender + '-source-dance.gltf')
        stats = pipeline.td.export_gltf(body, {'TribalDance': matched}, pipeline.td.png_from_tga(atlas.read_bytes()),
                                        output, height, floor_sample_rate=240,
                                        preserve_vertical_clips=['TribalDance'], measure_motion_bounds=True)
        floor = stats['clips']['TribalDance']
        assert floor['floor_policy'] == 'source_vertical' and floor['floor_offset_range'][0] == floor['floor_offset_range'][1]
        actual_mesh=SOURCE/'Models/Humans'/('h_savage_'+gender+'_lod2.grn')
        actual=pipeline.td.parse(actual_mesh.read_bytes(),scene_root_names=True,skip_unskinned_helpers=True,scale_shear_tracks=True)
        actual,actual_bind=pipeline.normalise_bind(actual_mesh.read_bytes(),actual)
        assert len(actual['points'])==(183 if gender=='male' else 190)
        actual_motion,actual_omitted=pipeline.helper.match_animation(clip,actual)
        actual_atlas=SOURCE/'Models/Maps'/actual['textures'][0]
        assert actual_mesh.relative_to(SOURCE).as_posix() in allowed and actual_atlas.relative_to(SOURCE).as_posix() in allowed
        actual_output=OUTPUT/(gender+'-source-full-body.gltf')
        actual_stats=pipeline.td.export_gltf(actual,{'TribalDance':actual_motion},pipeline.td.png_from_tga(actual_atlas.read_bytes()),actual_output,height,floor_sample_rate=240,preserve_vertical_clips=['TribalDance'],measure_motion_bounds=True)
        full_body=dict(output=actual_output.name,sha256=sha(actual_output),source_mesh=actual_mesh.relative_to(SOURCE).as_posix(),source_mesh_sha256=sha(actual_mesh),stats=actual_stats,mesh_bind_normalisation=actual_bind,omitted_animation_bones=actual_omitted,scope='Full preserved original Savage skin for clearance; unmatched unweighted exporter leaves are explicitly declared. The43joint hue-chip helper remains a separate choreography rig.')
        rows.append(dict(gender=gender, output=output.name, sha256=sha(output), stats=stats,
                         mesh_bind_normalisation=bind, motion_bind_normalisation=fold,
                         omitted_animation_bones=omitted,floor_reference=full_body))
    scripts = ['prepare-savage-dance.py', 'prepare-creatures.py', 'prepare-distinct-mounts.py',
               'import-third-dawn.py', 'creature-affine.py']
    report = dict(models=rows, input_manifest_sha256=sha(manifest),
                  source_tool_sha256={name: sha(ROOT / 'scripts' / name) for name in scripts},
                  scope='Private original reference conversion only; no accepted body/action or native behaviour claim.')
    (OUTPUT / 'preparation.json').write_bytes((json.dumps(report, indent=2) + '\n').encode())
    print('SAVAGE DANCE REFERENCES: two exact original clips; constant anchors preserve vertical choreography')


if __name__ == '__main__':
    main()
