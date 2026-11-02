"""Prepare exact original Juka trials; no accepted routes or gameplay claims."""
import argparse
import hashlib
import importlib.util
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'work/third-dawn/late-source-research/uoaos-source'
CABS = SOURCE.parent / 'uoaos-cabinets'
WORK = ROOT / 'work/creatures/juka'
ART = ROOT / 'Viewer/local-art/creatures'
KINDS = {'juka_warrior': (764, 34, 7520), 'juka_mage': (765, 39, 8944)}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes((json.dumps(value, indent=2) + '\n').encode())


def inputs(extract=False):
    pins = json.loads((ROOT / 'scripts/source-juka-inputs.json').read_text(encoding='utf-8'))
    for row in pins['cabinets']:
        path = CABS / Path(row['zip_member']).name
        assert path.stat().st_size == row['bytes'] and sha(path) == row['sha256']
    if extract:
        seven = shutil.which('7z') or shutil.which('7zz') or 'C:/Program Files/7-Zip/7z.exe'
        folders = {'Models': 'client7.cab', 'Models/Monsters': 'client11.cab', 'Models/Maps': 'client10.cab', 'Models/Humans': 'client9.cab'}
        for folder, cabinet in folders.items():
            names = [Path(r['path']).name for r in pins['files'] if Path(r['path']).parent.as_posix() == folder]
            target = SOURCE / folder
            target.mkdir(parents=True, exist_ok=True)
            subprocess.run([seven, 'e', '-y', '-o' + str(target), str(CABS / cabinet), *names], check=True, stdout=subprocess.DEVNULL)
    for row in pins['files']:
        path = (SOURCE / row['path']).resolve()
        assert path.is_relative_to(SOURCE.resolve()) and path.stat().st_size == row['bytes'] and sha(path) == row['sha256'], row['path']
    for row in pins['native_sources']:
        assert sha(ROOT / 'Server/ModernUO' / row['path']) == row['sha256'], row['class']
    return pins


def prepare():
    pins = inputs()
    spec = importlib.util.spec_from_file_location('juka_pipeline', ROOT / 'scripts/prepare-creatures.py')
    pipeline = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(pipeline)
    staging = WORK / 'source-preparation'
    staging.mkdir(parents=True, exist_ok=True)
    pipeline.OUTPUT = staging
    strict_parse = pipeline.td.parse
    repairs = []

    def parse(data, **options):
        try:
            return strict_parse(data, **options)
        except ValueError as error:
            digest = hashlib.sha256(data).hexdigest()
            if str(error) != 'Duplicate bone names' or not options.get('animations_only') or digest not in pins['indexed_auxiliary_source_sha256']:
                raise
            parsed = strict_parse(data, auxiliary_scene_leaf=pins['indexed_auxiliary_contract'], **options)
            assert parsed['bones'][1]['name'] == 'granny_master' and parsed['bones'][43]['name'] == 'unretained_auxiliary_scene_43'
            repairs.append({'source_sha256': digest, 'contract': pins['indexed_auxiliary_contract'],
                            'scope': 'Only the indexed auxiliary scene label changes. Every original joint, transform, track and primary rig ancestor is retained.'})
            return parsed

    pipeline.td.parse = parse
    paths = {'uoaos/UOTD/' + r['path']: SOURCE / r['path'] for r in pins['files']}

    class OriginalInputs:
        def read(self, name):
            return paths[name].read_bytes()

    names = {n.casefold(): n for n in paths}
    names.update(pins['source_motion_category_bindings'])
    for kind in KINDS:
        pipeline.reuse.RECIPES[kind] = {'floor_sample_rate': 240, 'measure_motion_bounds': True}
    table = pipeline.table_rows((SOURCE / 'Models/models.txt').read_bytes())
    server_pin, native = pipeline.native_bodies()
    assert server_pin == pins['server_pin']
    models = pipeline.prepare('juka', OriginalInputs(), names, table, native, selected_kinds=set(KINDS))
    assert len(models) == 2 and {r['kind'] for r in models} == set(KINDS)
    assert {r['source_sha256'] for r in repairs} == set(pins['indexed_auxiliary_source_sha256'])
    for row in models:
        kind = row['kind']
        body, bones, triangles = KINDS[kind]
        assert row['status'] == 'prepared' and not row['rejected_source_clips']
        assert len(row['clip_sources']) == 13 and row['stats']['original']['bones'] == bones and row['stats']['rounded']['triangles'] == triangles
        assert {r['body'] for r in row['bodies']} == {body}
        identity = row['bodies'][0]
        source = next(r for r in pins['native_sources'] if r['body'] == body)
        identity['native_class'] = source['class']
        identity['native_sources'] = [{'path': source['path'], 'sha256': source['sha256']}]
        row.update(presentation_script='res://Presentation/SourceJukaVisual.gd', presentation_script_sha256=sha(ROOT / 'Viewer/Presentation/SourceJukaVisual.gd'),
                   camera_height=row['stats']['original']['height_m'] * .85, contact_kind='measured_limbs',
                   classic_action_categories={'14': 'Cast2'}, new_action_categories={'2': 'Hit', '5': 'Fidget', '14': 'Pillage'},
                   pending_render_feature='Original Juka source-pose, actual terrain/material/corpse and native action/behaviour acceptance pending.',
                   preparation_recipe={'path': 'scripts/prepare-source-juka.py', 'sha256': sha(Path(__file__))})
        for treatment in ['original', 'rounded', 'modern']:
            shutil.copyfile(staging / (kind + '-' + treatment + '.gltf'), ART / (kind + '-' + treatment + '.gltf'))
        shutil.copyfile(staging / (kind + '-original-albedo.png'), ART / (kind + '-original-albedo.png'))
    write(ART / 'juka/preparation.json', {'family': 'juka', 'models': models, 'server_pin': server_pin,
        'source_url': pins['source_url'], 'source_cabinets': pins['cabinets'], 'source_motion_category_bindings': pins['source_motion_category_bindings'],
        'indexed_auxiliary_repairs': repairs, 'recipe_sha256': sha(Path(__file__)),
        'reader_sha256': sha(ROOT / 'scripts/import-third-dawn.py'), 'source_pipeline_sha256': sha(ROOT / 'scripts/prepare-creatures.py'),
        'input_manifest_sha256': sha(ROOT / 'scripts/source-juka-inputs.json'), 'scope': pins['scope']})
    print('JUKA PREPARED: two original meshes, 13 selected original human motions each, all tracks retained. Lord766 remains unresolved; no accepted coverage.')


def refresh_renderer():
    inputs()
    path = ART / 'juka/preparation.json'
    report = json.loads(path.read_text(encoding='utf-8'))
    proof = json.loads((ROOT / 'outputs/creatures/juka/source-poses.json').read_text(encoding='utf-8'))
    assert proof['failures'] == 0 and proof['preparation_sha256'] == sha(path)
    assert report['reader_sha256'] == sha(ROOT / 'scripts/import-third-dawn.py')
    assert report['source_pipeline_sha256'] == sha(ROOT / 'scripts/prepare-creatures.py')
    assert report['input_manifest_sha256'] == sha(ROOT / 'scripts/source-juka-inputs.json')
    assert {r['kind'] for r in report['models']} == set(KINDS)
    for kind, treatments in proof['assets'].items():
        for treatment, pin in treatments.items():
            asset = ART / (kind + '-' + treatment + '.gltf')
            assert sha(asset) == pin['asset_sha256'] and sha(Path(str(asset) + '.import')) == pin['import_sha256']
    for row in report['models']:
        assert row['status'] == 'prepared' and row['pending_render_feature']
        row.update(presentation_script='res://Presentation/SourceJukaVisual.gd', presentation_script_sha256=sha(ROOT / 'Viewer/Presentation/SourceJukaVisual.gd'),
                   camera_height=row['stats']['original']['height_m'] * .85, contact_kind='measured_limbs',
                   classic_action_categories={'14': 'Cast2'}, new_action_categories={'2': 'Hit', '5': 'Fidget', '14': 'Pillage'},
                   preparation_recipe={'path': 'scripts/prepare-source-juka.py', 'sha256': sha(Path(__file__))})
    report['recipe_sha256'] = sha(Path(__file__))
    write(path, report)
    print('JUKA PREPARATION RENDERER UPDATED: exact source assets unchanged; rerun affected pose/terrain/render/native gates, no proof rewritten')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['check-inputs', 'extract', 'prepare', 'refresh-renderer']:
        parser.add_argument('--' + name, action='store_true')
    args = parser.parse_args()
    if args.extract:
        inputs(True)
    if args.check_inputs:
        pins = inputs()
        print('JUKA INPUTS:', len(pins['files']), 'exact members, four cabinets and three native source pins')
    if args.prepare:
        prepare()
    if args.refresh_renderer:
        refresh_renderer()
