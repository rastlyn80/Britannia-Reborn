"""Build private candidates with source-preserving skin subdivision.

This opt-in batch uses the existing conditional-bind Godot baker instead of
averaging incompatible source weights. It never edits the accepted index.
"""
import argparse
import base64
import hashlib
import importlib.util
import json
from types import ModuleType
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT/'scripts/source-preserving-inputs.json'
WORK = ROOT/'work/creatures/source-preserving'
ART = ROOT/'Viewer/local-art/creatures'
RECIPE = ROOT/'Viewer/Presentation/SourcePoseSubdivision.gd'
RUNTIME = ['SourcePreservingCreatureVisual.gd','SourceVariantPoseEntry.gd',
           'SourceRenderedPose.gd','SourcePoseEntry.gd','SmallSnakeVisual.gd',
           'SourcePlaneSoleSupport.gd','MeasuredCreatureSupport.gd',
           'SourceMountContact.gd','SourceGroundLookup.gd','CreatureVisual.gd',
           'HumanAvatar.gd','CreatureRegistry.gd','CorpseModels.gd','SkinGeometry.gd']


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def checked(row):
    path = (ROOT/row['path']).resolve()
    assert path.is_relative_to((ROOT/'work').resolve()), 'Inputs must stay in private work'
    assert path.stat().st_size == row['bytes'] and sha(path) == row['sha256'], row['path']
    return path


def inputs():
    pins = json.loads(MANIFEST.read_text(encoding='utf-8'))
    assert pins['schema'] == 1
    assert pins['server_pin'] == json.loads((ROOT/'Server/dependencies.json').read_text())['modernuo']['revision']
    verified = set()
    for row in pins['models']:
        assert row['kind'].replace('_', '').isalnum()
        for record in [*row['containers'], row['model_table'], *row['files']]:
            identity = (record['path'], record['bytes'], record['sha256'])
            if identity not in verified:
                checked(record)
                verified.add(identity)
    return pins


def pipeline_for(kind):
    # Each model gets an isolated importer module. All adapters are private to
    # this run; accepted converters and their default weight limits stay intact.
    spec = importlib.util.spec_from_file_location('preserving_'+kind, ROOT/'scripts/prepare-creatures.py')
    pipeline = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(pipeline)
    parse, refine, export = pipeline.td.parse, pipeline.smooth.refine, pipeline.td.export_gltf

    def source_parse(raw, **options):
        options.setdefault('max_influences', 4)
        return parse(raw, **options)

    def source_mesh(model, **options):
        options.update(levels=0, max_influences=4, weight_smoothing=0.)
        return refine(model, **options)

    def source_export(*args, **options):
        options['max_influences'] = 4
        options['preserve_vertical_clips'] = sorted(set(options.get('preserve_vertical_clips', ())) | {'Walk', 'Run'})
        return export(*args, **options)

    pipeline.td.parse = source_parse
    pipeline.smooth.refine = source_mesh
    pipeline.td.export_gltf = source_export
    pipeline.LABELS.update(fidget1='Fidget', fidget2='Fidget2')
    return pipeline


def converter_pins(pipeline):
    pending, visited, result = [pipeline], set(), {}
    while pending:
        module = pending.pop()
        if id(module) in visited:
            continue
        visited.add(id(module))
        path = Path(module.__file__).resolve()
        if not path.is_relative_to((ROOT/'scripts').resolve()):
            continue
        result[path.name] = sha(path)
        pending.extend(value for value in vars(module).values() if isinstance(value, ModuleType) and getattr(value, '__file__', None))
    return result


def prepare():
    pins = inputs()
    WORK.mkdir(parents=True, exist_ok=True)
    ART.mkdir(parents=True, exist_ok=True)
    models = []
    for source in pins['models']:
        kind = source['kind']
        pipeline = pipeline_for(kind)
        tools = converter_pins(pipeline)
        pipeline.OUTPUT = WORK/kind
        pipeline.OUTPUT.mkdir(exist_ok=True)
        paths = {row['member']: ROOT/row['path'] for row in source['files']}

        class OriginalInputs:
            def read(self, name):
                return paths[name].read_bytes()

        table = pipeline.table_rows((ROOT/source['model_table']['path']).read_bytes())
        for row in table:
            row['source_table_stem'] = row['stem']
            row['stem'] = row['stem'].casefold()
        server_pin, native = pipeline.native_bodies()
        assert server_pin == pins['server_pin']
        pipeline.reuse.RECIPES[kind] = {'floor_sample_rate': 120, 'measure_motion_bounds': True}
        rows = pipeline.prepare(kind.split('_')[0], OriginalInputs(), {name.casefold(): name for name in paths}, table, native, selected_kinds={kind})
        assert len(rows) == 1 and rows[0]['status'] == 'prepared', rows
        row = rows[0]
        assert not row['rejected_source_clips'] and len(row['clip_sources']) == source['source_clips']
        assert {identity['body'] for identity in row['bodies']} == set(source['expected_bodies'])
        stats = row['stats']['original']
        assert stats['bones'] == source['bones'] and stats['triangles'] == source['triangles']
        # Dense geometry is baked once below, never rebuilt for every avatar.
        row['pose_subdivision'] = {'levels': source['levels'], 'normal_offset_source_units': source['normal_offset_m']/stats['scale'], 'normal_offset_m': source['normal_offset_m'], 'recipe_sha256': sha(RECIPE)}
        row['family'] = 'source_preserving'
        row['presentation_script'] = 'res://Presentation/SourcePreservingCreatureVisual.gd'
        row['presentation_script_sha256'] = sha(ROOT/'Viewer/Presentation/SourcePreservingCreatureVisual.gd')
        row['limb_support'] = 'quadruped' if kind == 'wild_guar' else 'biped'
        row['source_provenance'] = source
        row['converter_sha256'] = tools
        row['source_opacity'] = source['opacity']
        row.pop('source_alpha_texture', None)
        if source['opacity'] == 'fine_edges':
            row['source_alpha_texture'] = kind+'-original-albedo.png'
            row['source_alpha_scope'] = 'fine_edges'
        alpha = pipeline.OUTPUT/(kind+'-original-albedo.png')
        (ART/alpha.name).write_bytes(alpha.read_bytes())
        row['art_dependency_sha256'] = {alpha.name: sha(alpha)}
        row['assets'] = {name: 'res://local-art/creatures/'+kind+'-'+name+'.scn' for name in ['original', 'rounded', 'modern']}
        row['bake_inputs'] = {}
        for treatment in row['assets']:
            path = pipeline.OUTPUT/(kind+'-'+treatment+'.gltf')
            gltf = json.loads(path.read_text())
            if treatment == 'modern' and source.get('modern_texture_member'):
                png = pipeline.td.png_from_tga(paths[source['modern_texture_member']].read_bytes())
                gltf['images'][0]['uri'] = 'data:image/png;base64,'+base64.b64encode(png).decode()
                row['modern_texture_scope'] = source['modern_texture_scope']
            for material in gltf['materials']:
                material.update(alphaMode='MASK', alphaCutoff=.12, doubleSided=True)
            path.write_text(json.dumps(gltf, separators=(',', ':')), encoding='utf-8')
            row['bake_inputs'][treatment] = {'path': str(path.relative_to(ROOT)), 'sha256': sha(path)}
        models.append(row)
    # The old generic converter assumes one older archive. Replace that staging
    # receipt, including nested records, with the actual per-model provenance.
    for model in models:
        family = model['kind'].split('_')[0]
        path = WORK/model['kind']/family/'preparation.json'
        data = json.loads(path.read_text())
        data.pop('archive_sha256', None)
        data['source_provenance'] = model['source_provenance']
        path.write_text(json.dumps(data, indent=2)+'\n')
    report = {'models': models, 'server_pin': pins['server_pin'], 'manifest_sha256': sha(MANIFEST), 'preparer_sha256': sha(Path(__file__)), 'runtime_sha256':{name:sha(ROOT/'Viewer/Presentation'/name) for name in RUNTIME}, 'scope': 'Private coarse source inputs for BakeSourcePreserving. Dense triangles are not present until the baker succeeds. No accepted route, source-interpolation, terrain, riding or native-gameplay certificate.'}
    path = WORK/'preparation.json'
    path.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print('SOURCE PRESERVING: prepared', len(models), 'source forms; next run BakeSourcePreserving.gd')


def check_prepared():
    pins = inputs()
    report = json.loads((ART/'source_preserving/preparation.json').read_text())
    assert report['manifest_sha256'] == sha(MANIFEST) and report['preparer_sha256'] == sha(Path(__file__))
    assert report['baker_sha256'] == sha(ROOT/'Viewer/Presentation/BakeSourcePreserving.gd')
    assert report['subdivision_sha256'] == sha(RECIPE) and report['server_pin'] == pins['server_pin']
    assert report['runtime_sha256'] == {name:sha(ROOT/'Viewer/Presentation'/name) for name in RUNTIME}
    assert len(report['models']) == len(pins['models'])
    for row, source in zip(report['models'], pins['models']):
        assert row['source_provenance'] == source and row['kind'] == source['kind']
        assert row['presentation_script_sha256'] == sha(ROOT/'Viewer/Presentation/SourcePreservingCreatureVisual.gd')
        assert row['converter_sha256'] == converter_pins(pipeline_for(row['kind']))
        assert {body['body'] for body in row['bodies']} == set(source['expected_bodies'])
        assert len(row['clip_sources']) == source['source_clips'] and not row['rejected_source_clips']
        assert row['stats']['original']['bones'] == source['bones']
        assert row['refinement']['triangles_after'] == source['triangles']*4**source['levels']
        for treatment, asset in row['assets'].items():
            path = (ROOT/'Viewer'/asset.removeprefix('res://')).resolve()
            assert path.parent == ART.resolve() and sha(path) == row['saved_scenes'][treatment]['scene_sha256']
        for name, digest in row['art_dependency_sha256'].items():
            assert Path(name).name == name and sha(ART/name) == digest
    print('SOURCE PRESERVING PREPARATION:', len(report['models']), 'exact inputs/converters/saved scenes verified; no accepted route')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-inputs', action='store_true')
    parser.add_argument('--check-prepared', action='store_true')
    args = parser.parse_args()
    if args.check_prepared:
        check_prepared()
    elif args.check_inputs:
        print('SOURCE PRESERVING INPUTS:', len(inputs()['models']), 'exact source forms verified')
    else:
        prepare()
