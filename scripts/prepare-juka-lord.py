"""Build private Kabur body and original Third Dawn bow previews."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import runpy
from shutil import copyfile
import subprocess

SCRIPTS = Path(__file__).resolve().parent
JUKA = runpy.run_path(str(SCRIPTS / 'prepare-source-juka.py'))
TOOLS = runpy.run_path(str(SCRIPTS / 'prepare-gazer-larva-source.py'))
ROOT, SOURCE = JUKA['ROOT'], JUKA['SOURCE']
WORK = JUKA['WORK'] / 'lord-owned'
MANIFEST = SCRIPTS / 'juka-lord-inputs.json'
SHA = TOOLS['sha']


def inputs():
    shared = JUKA['inputs']()
    pinned = json.loads(MANIFEST.read_text(encoding='utf-8'))
    assert pinned['server_pin'] == shared['server_pin']
    for relative, expected in pinned['files'].items():
        path = SOURCE / relative
        assert path.stat().st_size == expected['bytes'] and SHA(path) == expected['sha256'], path
    for relative, digest in pinned['native'].items():
        assert SHA(ROOT / 'Server/ModernUO' / relative) == digest, relative
    return shared, pinned


def body_preview(shared, pinned, pipeline):
    pipeline.OUTPUT = WORK
    paths = {'uoaos/UOTD/' + path: SOURCE / path
             for path in {*pinned['files'], *(row['path'] for row in shared['files'])}}
    names = {name.casefold(): name for name in paths}
    names.update({key.replace('juka_warrior_', 'npc_kabur_'): value
                  for key, value in shared['source_motion_category_bindings'].items()
                  if 'juka_warrior_' in key})
    parse_source = pipeline.td.parse

    def parse(raw, **options):
        digest = hashlib.sha256(raw).hexdigest()
        if options.get('animations_only') and digest in shared['indexed_auxiliary_source_sha256']:
            options['auxiliary_scene_leaf'] = shared['indexed_auxiliary_contract']
        return parse_source(raw, **options)

    class PrivateInputs:
        def read(self, name):
            return paths[name].read_bytes()

    raw_table = (SOURCE / 'Models/models.txt').read_bytes()
    table = pipeline.table_rows(raw_table)
    assignment, = [row for row in table if row['body'] == pinned['body']]
    assert assignment['stem'] == pinned['model_stem'].lower()
    assert assignment['scale'] == pinned['scale'] and assignment['animation_body'] == pinned['motion_body']
    bow, = [line.split() for line in raw_table.decode('latin-1').splitlines()
            if line.split() and line.split()[0] == str(pinned['bow_body'])]
    assert bow[1] == '4' and bow[-4:] == ['1.3', '1.3', '1.3', 'Weapon_Bow']
    revision, native = pipeline.native_bodies()
    assert revision == pinned['server_pin']
    pipeline.reuse.RECIPES['npc_kabur'] = {'floor_sample_rate': 240, 'measure_motion_bounds': True}
    pipeline.td.parse = parse
    try:
        row, = pipeline.prepare('npc', PrivateInputs(), names, table, native, selected_kinds={'npc_kabur'})
    finally:
        pipeline.td.parse = parse_source
    assert row['status'] == 'prepared' and len(row['clip_sources']) == 13
    assert row['stats']['original']['bones'] == 36 and row['stats']['original']['triangles'] == 666
    return row


def bow_preview(pipeline):
    path = SOURCE / 'Models/Others/weapon_bow_lod2.grn'
    raw = path.read_bytes()
    model = pipeline.td.parse(raw, scene_root_names=True)
    assert not model['weights'] and model['ties'] == [1]
    assert len(model['bones']) == 2 and model['bones'][1]['name'] == 'weapon_bow'
    assert model['textures'] == ['weapons_512.tga']
    model['weights'] = [[(0, 1.0)] for _ in model['points']]
    model, _ = pipeline.normalise_bind(raw, model)
    z = [point[2] for point in model['points']]
    atlas = pipeline.td.png_from_tga((SOURCE / 'Models/Maps/weapons_512.tga').read_bytes())
    output = WORK / 'weapon_bow-original.gltf'
    stats = pipeline.td.export_gltf(model, {}, atlas, output, (max(z) - min(z)) * 1.3)
    assert stats['triangles'] == 92
    return {'asset': output.name, 'sha256': SHA(output), 'stats': stats,
            'binding': 'Full rigid weight to the original weapon_bow joint.'}


def pack(report):
    stage = WORK / 'pack'
    stage.mkdir(exist_ok=True)
    godot = next((ROOT / '.tools/godot').glob('*console.exe'))
    user_dir = str(ROOT / '.godot-user')
    result = subprocess.run(
        [str(godot), '--headless', '--path', str(ROOT / 'Viewer'), '--script',
         'res://Presentation/BakeJukaLord.gd', '--', f'--output={stage.as_posix()}'],
        cwd=ROOT, env=dict(os.environ, APPDATA=user_dir, LOCALAPPDATA=user_dir),
        capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=90)
    output = result.stdout + result.stderr
    if result.returncode or 'ERROR:' in output or 'JUKA LORD BAKE:' not in output:
        raise RuntimeError(output)
    art = ROOT / 'Viewer/local-art/creatures'
    target = art / 'juka_lord'
    res = 'res://local-art/creatures/juka_lord/'
    renderer = 'res://Presentation/SourceJukaLordVisual.gd'
    bow = report['bow']['asset']
    copyfile(WORK / bow, stage / bow)
    row = report['body']
    row['bodies'][0]['native_class'] = 'JukaLord'
    variants = {kind: f'npc_kabur-{kind}.scn' for kind in ('original', 'modern')}
    row.update(family='juka_lord', presentation_script=renderer,
               presentation_script_sha256=SHA(ROOT / 'Viewer' / renderer.removeprefix('res://')),
               bow_asset=res + bow, native_equipment_layers=[2], native_constructor_hues={'JukaLord': 0},
               assets={kind: res + name for kind, name in variants.items()},
               asset_sha256={kind: SHA(stage / name) for kind, name in variants.items()},
               art_dependency_sha256={res + bow: SHA(stage / bow)})
    registry = art / 'accepted-index.json'
    if registry.exists():
        entries = json.loads(registry.read_text(encoding='utf-8-sig'))['entries']
        if any(body['body'] == 766 for item in entries for body in item['bodies']):
            expected = dict(row, status='validated')
            if expected not in entries:
                raise RuntimeError('Rebuilt Juka Lord differs from the active package. Staged files remain in work/.')
            print('Rebuilt Juka Lord matches the active package')
            return
    target.mkdir(parents=True, exist_ok=True)
    for name in [*variants.values(), bow]:
        copyfile(stage / name, target / name)
    pending = target / 'preparation.pending'
    pending.write_text(json.dumps({'models': [row],
                                  'scope': 'Private pinned Juka Lord scene and bow. No active registry or live certification.'},
                                  indent=2) + '\n', encoding='utf-8')
    pending.replace(target / 'preparation.json')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pack', action='store_true', help='Bake the private package for client validation')
    args = parser.parse_args()
    shared, pinned = inputs()
    WORK.mkdir(parents=True, exist_ok=True)
    pipeline = TOOLS['pipeline']()
    report = {'body': body_preview(shared, pinned, pipeline), 'bow': bow_preview(pipeline),
              'manifest_sha256': SHA(MANIFEST), 'shared_juka_manifest_sha256': SHA(SCRIPTS / 'source-juka-inputs.json'),
              'scope': 'Private source conversion. Native and client acceptance are separate.'}
    (WORK / 'preparation.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print('JUKA LORD: original 36-joint body, 13 assigned motions, original 92-triangle bow')
    if args.pack:
        pack(report)


if __name__ == '__main__':
    main()
