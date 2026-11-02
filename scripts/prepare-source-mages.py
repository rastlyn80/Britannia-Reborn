"""Prepare preserved Evil Mage forms without accepting their runtime routes."""
import argparse
import hashlib
import importlib.util
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'work/third-dawn/late-source-research/uoaos-source'
CABINETS = SOURCE.parent / 'uoaos-cabinets'
WORK = ROOT / 'work/creatures/evil-mages'
ART = ROOT / 'Viewer/local-art/creatures'
KINDS = ['mages_evil_mage', 'mages_evil_mage_master']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes((json.dumps(data, indent=2) + '\n').encode())


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / filename)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def inputs(extract=False):
    pins = read(ROOT / 'scripts/source-mage-inputs.json')
    for row in pins['cabinets']:
        path = CABINETS / Path(row['zip_member']).name
        assert path.stat().st_size == row['bytes'] and sha(path) == row['sha256']
    if extract:
        program = shutil.which('7z') or shutil.which('7zz') or 'C:/Program Files/7-Zip/7z.exe'
        for cabinet, folder, patterns in [('client7.cab', 'Models', ['models.txt']),
                                          ('client11.cab', 'Models/Monsters', ['mages_evil_mage*.grn']),
                                          ('client10.cab', 'Models/Maps', ['mages_evil_mage*.tga'])]:
            target = SOURCE / folder
            target.mkdir(parents=True, exist_ok=True)
            subprocess.run([program, 'e', '-y', '-o' + str(target), str(CABINETS / cabinet), *patterns], check=True, stdout=subprocess.DEVNULL)
    for row in pins['files']:
        path = (SOURCE / row['path']).resolve()
        assert path.is_relative_to(SOURCE.resolve()) and path.stat().st_size == row['bytes'] and sha(path) == row['sha256'], row['path']
    for row in pins['native_sources']:
        assert sha(ROOT / 'Server/ModernUO' / row['path']) == row['sha256'], 'Changed native identity source'
    return pins


def prepare():
    pins = inputs()
    pipeline = module('mage_pipeline', 'prepare-creatures.py')
    masks = module('mage_masks', 'creature-mage-masks.py')
    staging = WORK / 'source-preparation'
    staging.mkdir(parents=True, exist_ok=True)
    pipeline.OUTPUT = staging

    class OriginalInputs:
        def __init__(self):
            self.paths = {'uoaos/UOTD/' + row['path']: SOURCE / row['path'] for row in pins['files']}

        def read(self, name):
            return self.paths[name].read_bytes()

    original = OriginalInputs()
    names = {n.casefold(): n for n in original.paths}
    table = pipeline.table_rows((SOURCE / 'Models/models.txt').read_bytes())
    server_pin, native = pipeline.native_bodies()
    assert server_pin == pins['server_pin']
    for kind in KINDS:
        pipeline.reuse.RECIPES[kind] = {'floor_sample_rate': 240, 'measure_motion_bounds': True}
    pipeline.reuse.RECIPES[KINDS[1]].update(clip_stem=KINDS[0], motion_contract_stem=KINDS[0], unbound_label_aliases=[[KINDS[1], KINDS[0]]])
    prior_install = pipeline.humanoid_actions.install

    def install_gesture(body, clips, authored, aliases, stem):
        if stem not in KINDS:
            return prior_install(body, clips, authored, aliases, stem)
        assert 'Pillage' not in clips and 'Cast2' in clips
        clips['Pillage'] = pipeline.humanoid_actions.gesture(body, clips['Idle'], 'Pillage')
        authored['Pillage'] = 'Authored measured-arm crouch/reach with source leg stance and wrist/finger pose retained; not recovered original choreography.'
        return True

    pipeline.humanoid_actions.install = install_gesture
    models = pipeline.prepare('mages', original, names, table, native, selected_kinds=set(KINDS))
    assert {r['kind'] for r in models} == set(KINDS) and all(r['status'] == 'prepared' for r in models)
    assert len(models) == 2
    for row in models:
        kind = row['kind']
        assert row['stats']['original']['bones'] == 36 and row['stats']['original']['triangles'] == 442 and row['stats']['rounded']['triangles'] == 7072
        assert len(row['clip_sources']) == 9 and 'Pillage' in row['authored_replacements'] and not row['rejected_source_clips']
        # The literal-only census misses Utility.Random(125,2). Preserve that
        # bounded universe; attach explicit constructor-source provenance here.
        for identity in row['bodies']:
            source = next(r for r in pins['native_sources'] if identity['body'] in r['bodies'])
            identity['native_sources'] = [{'path': source['path'], 'sha256': source['sha256']}]
            identity['native_class'] = source['class']
            identity['native_identity_scope'] = source['identity_scope']
        assert {r['body'] for r in row['bodies']} == ({124} if kind == KINDS[0] else {125, 126})
        for treatment in ['original', 'rounded', 'modern']:
            path = staging / (kind + '-' + treatment + '.gltf')
            doc = read(path)
            if treatment == 'modern':
                doc, proof = masks.apply(read(staging / (kind + '-original.gltf')), doc)
                row['garment_mask'] = dict(proof, recipe_sha256=sha(ROOT / 'scripts/creature-mage-masks.py'))
            (ART / path.name).write_bytes(json.dumps(doc, separators=(',', ':')).encode())
        shutil.copyfile(staging / (kind + '-original-albedo.png'), ART / (kind + '-original-albedo.png'))
        row.update(presentation_script='res://Presentation/SourceMageVisual.gd', presentation_script_sha256=sha(ROOT / 'Viewer/Presentation/SourceMageVisual.gd'),
                   camera_height=1.8, contact_kind='measured_limbs', native_equipment_layers=[22, 6, 3],
                   classic_action_categories={'12': 'Cast2', '14': 'Cast2'}, new_action_categories={'2': 'Hit', '5': 'Fidget', '11': 'Cast2', '14': 'Pillage'},
                   art_dependency_sha256={kind + '-original-albedo.png': sha(ART / (kind + '-original-albedo.png'))},
                   preparation_recipe={'path': 'scripts/prepare-source-mages.py', 'sha256': sha(Path(__file__))},
                   surface='Original 128-square RGB atlas, refined original UV skin, matte procedural relief and independent native body/robe/hat/shoe hues. Integral costume retained after item removal. Authored cap mask, not recovered original clothing geometry/mask or a new bitmap.',
                   source_affine_scope='Proper-rotation rebinding of normalized source transforms; no exact original affine/shear skinning claim.')
    write(ART / 'mages/preparation.json', {'family': 'mages', 'models': models, 'server_pin': server_pin, 'source_url': pins['source_url'], 'source_cabinets': pins['cabinets'],
                                         'recipe_sha256': sha(Path(__file__)), 'input_manifest_sha256': sha(ROOT / 'scripts/source-mage-inputs.json'),
                                         'source_pipeline_sha256': sha(ROOT / 'scripts/prepare-creatures.py'),
                                         'scope': 'Private original-source preparation only. Native random identities are explicit source mappings pending full graphics/native acceptance. Original/derived artwork excluded from Git; no accepted route installed.'})
    print('MAGES PREPARED: two original meshes, three declared native bodies, nine source motions and authored Pillage; no accepted routes')


def refresh_renderer_pin():
    """Update preparation only; existing runtime proofs are not rewritten."""
    inputs()
    path = ART / 'mages/preparation.json'
    report = read(path)
    assert report['input_manifest_sha256'] == sha(ROOT / 'scripts/source-mage-inputs.json')
    assert report['source_pipeline_sha256'] == sha(ROOT / 'scripts/prepare-creatures.py')
    assert {r['kind'] for r in report['models']} == set(KINDS)
    # A code-only renderer revision cannot bless changed geometry/imports.
    # These are the actual saved assets from the independent source pose run.
    source_pose = read(ROOT / 'outputs/creatures/mages/actions.json')
    assert source_pose['failures'] == 0 and set(source_pose['assets']) == set(KINDS)
    for kind, treatments in source_pose['assets'].items():
        assert set(treatments) == {'original', 'rounded', 'modern'}
        for treatment, pin in treatments.items():
            asset = ART / (kind + '-' + treatment + '.gltf')
            assert sha(asset) == pin['asset_sha256'] and sha(Path(str(asset) + '.import')) == pin['import_sha256']
    for row in report['models']:
        assert row['status'] == 'prepared' and row['garment_mask']['recipe_sha256'] == sha(ROOT / 'scripts/creature-mage-masks.py')
        row['presentation_script_sha256'] = sha(ROOT / 'Viewer/Presentation/SourceMageVisual.gd')
        row['preparation_recipe']['sha256'] = sha(Path(__file__))
    report['recipe_sha256'] = sha(Path(__file__))
    write(path, report)
    print('MAGE PREPARATION RENDERER PIN REFRESHED: source assets unchanged; rerun all affected graphics/acceptance gates')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['check-inputs', 'extract', 'prepare', 'refresh-renderer-pin']:
        parser.add_argument('--' + name, action='store_true')
    args = parser.parse_args()
    if args.extract:
        inputs(True)
    if args.check_inputs:
        inputs()
        print('MAGE INPUTS: fourteen original members, three cabinets, two pinned native sources')
    if args.prepare:
        prepare()
    if args.refresh_renderer_pin:
        refresh_renderer_pin()
