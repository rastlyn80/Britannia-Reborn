"""Prepare exact source-skin variants of existing creature integrations.

Requires matching normalized geometry, skin, UVs and weighted rest hierarchy.
Only source atlas pixels and an unused scene label may differ. Existing donor
art and routes are never modified; the Godot baker writes private candidates.
"""
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT/'scripts/source-variant-inputs.json'
WORK = ROOT/'work/creatures/source-variants'
ART = ROOT/'Viewer/local-art/creatures'
RUNTIME = ['SourceVariantPoseEntry.gd','SourceRenderedPose.gd','SourcePoseEntry.gd',
           'SourceLavaSerpentVisual.gd','SourceLavaSerpentSurface.gdshader',
           'SourceBloodElementalVisual.gd','SourceFluidElementalVisual.gd',
           'SourceFluidElementalMaterial.gd','SourceFluidElementalSurface.gdshader',
           'SourceSilverSerpentVisual.gd','SourceSilverSerpentMaterial.gd',
           'SourceSilverSerpentSurface.gdshader','SourceElementalVisual.gd',
           'SourcePlaneSoleSupport.gd','MeasuredCreatureSupport.gd',
           'SmallSnakeVisual.gd','MeasuredCreatureVisual.gd','CreatureVisual.gd',
           'SourceMountContact.gd','SourceGroundLookup.gd','HumanAvatar.gd',
           'CreatureDeaths.gd','CorpseModels.gd','CreatureRegistry.gd','SkinGeometry.gd']


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def checked(row):
    path = (ROOT/row['path']).resolve()
    assert path.is_relative_to((ROOT/'work').resolve()) or path.is_relative_to(ART.resolve())
    assert path.stat().st_size == row['bytes'] and sha(path) == row['sha256'], row['path']
    return path


def inputs():
    pins = json.loads(MANIFEST.read_text())
    assert pins['schema'] == 1
    assert pins['server_pin'] == json.loads((ROOT/'Server/dependencies.json').read_text())['modernuo']['revision']
    for row in [pins['model_table'], *pins['cabinets']]:
        checked(row)
    for model in pins['models']:
        for row in [*model['files'], model['donor_preparation'], *model['donor_assets'].values(), *model['donor_imports'].values()]:
            checked(row)
        if 'ground_lookup' in model:
            checked(model['ground_lookup'])
    return pins


def prepare():
    pins = inputs()
    spec = importlib.util.spec_from_file_location('source_variant_pipeline', ROOT/'scripts/prepare-creatures.py')
    pipeline = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(pipeline)
    tools = pipeline.module('variant_pins', 'prepare-source-preserving.py').converter_pins(pipeline)
    table = pipeline.table_rows((ROOT/pins['model_table']['path']).read_bytes())
    server_pin, native = pipeline.native_bodies()
    profiles = pipeline.body_profiles()
    assert server_pin == pins['server_pin']
    source = ROOT/pins['source_root']
    records = []
    WORK.mkdir(parents=True, exist_ok=True)
    for model in pins['models']:
        kind = model['kind']
        source_models, normalizations = [], []
        for relative in [model['source_mesh'], model['donor_mesh']]:
            raw = (source/relative).read_bytes()
            parsed = pipeline.td.parse(raw, scene_root_names=True)
            parsed, normalized = pipeline.normalise_bind(raw, parsed)
            parsed, _ = pipeline.visible_vertices(parsed)
            source_models.append(parsed)
            normalizations.append(normalized)
        aliases = [[a['name'], b['name']] for a, b in zip(source_models[0]['bones'], source_models[1]['bones']) if a['name'] != b['name']]
        contract = pipeline.reuse.assert_motion_contract(*source_models, aliases)
        assert source_models[0]['uv_sets'] == source_models[1]['uv_sets'], 'This baker cannot substitute a different UV layout'
        contract['uv_coordinates_exact'] = True
        # The inactive donor label is retained so saved animation track paths
        # and skin bind names can remain byte-for-byte unchanged.
        contract['inactive_label_policy'] = 'Keep declared unused donor scene label; no weighted joint or ancestor is renamed'
        donor = json.loads(checked(model['donor_preparation']).read_text())
        record = copy.deepcopy(next(row for row in donor['models'] if row['kind'] == model['donor_kind']))
        identities = [dict(row, native_sources=native.get(row['body'], []), native_profile=profiles.get(row['body'], '')) for row in table if row['body'] == model['body']]
        assert len(identities) == 1 and identities[0]['stem'] == kind
        target_identity, donor_identity = identities[0], record['bodies'][0]
        assert target_identity['scale'] == donor_identity['scale'] and target_identity['type'] == donor_identity['type'], 'Compiled reuse must preserve model-table size and action profile'
        target_animation = target_identity['animation_body'] or target_identity['body']
        donor_animation = donor_identity['animation_body'] or donor_identity['body']
        assert target_animation == donor_animation, 'An identical skin does not imply identical original choreography'
        contract['model_table_scale_exact'] = True
        contract['model_table_animation_body'] = target_animation
        atlas = pipeline.td.png_from_tga((source/model['source_atlas']).read_bytes())
        atlas_name = kind+'-original-albedo.png'
        (ART/atlas_name).write_bytes(atlas)
        for key in ['exact_prompt', 'generation_mode', 'atlas_reference', 'modern_atlas_reference']:
            record.pop(key, None)
        record.update(kind=kind, family=model['family'], status='prepared', bodies=identities,
                      inputs=[{'path': row['path'], 'sha256': row['sha256']} for row in model['files']],
                      source_provenance=model, source_motion_contract=contract,
                      bind_scale_normalisation=normalizations[0],
                      source_atlas_texture=atlas_name, atlas_sha256=hashlib.sha256(atlas).hexdigest(), modern_atlas=None,
                      art_dependency_sha256={atlas_name: hashlib.sha256(atlas).hexdigest()},
                      surface='Own original RGB/opacity over exact matching donor source/refined skins; authored procedural surface and explicitly reused donor action/support implementation',
                      source_motion_assignment='Original model-table animation link retained; exact normalized skin/UV/rest contract permits reuse of prepared donor clips and authored aliases',
                      presentation_script=model['presentation_script'],
                      presentation_script_sha256=sha(ROOT/'Viewer'/model['presentation_script'].removeprefix('res://')),
                      preparation_recipe={'path':'scripts/prepare-source-variants.py', 'sha256':sha(Path(__file__))},
                      assets={t:'res://local-art/creatures/'+kind+'-'+t+'.scn' for t in model['donor_assets']},
                      donor_assets=model['donor_assets'], donor_imports=model['donor_imports'])
        if model['body'] == 90:
            record.update(source_alpha_texture=atlas_name, source_alpha_scope='fine_edges')
            record['ground_lookup'] = 'res://'+model['ground_lookup']['path'].removeprefix('Viewer/')
            record['ground_lookup_sha256'] = model['ground_lookup']['sha256']
            record['art_dependency_sha256'][Path(model['ground_lookup']['path']).name] = model['ground_lookup']['sha256']
            record['ground_lookup_status'] = 'Reused donor curves through exact compiled deformation contract; current candidate terrain/death gate remains separate'
        records.append(record)
    report = {'models':records, 'server_pin':server_pin, 'manifest_sha256':sha(MANIFEST),
              'preparer_sha256':sha(Path(__file__)), 'converter_sha256':tools,
              'runtime_sha256':{name:sha(ROOT/'Viewer/Presentation'/name) for name in RUNTIME},
              'pin_helper_sha256':sha(ROOT/'scripts/prepare-source-preserving.py'),
              'scope':'Exact normalized source-skin/UV variants; candidate body identity and own atlas are retained. No accepted routes, native behaviour, raw GRN affine or current candidate avatar/terrain/death certificate.'}
    (WORK/'preparation.json').write_text(json.dumps(report, indent=2)+'\n')
    print('SOURCE VARIANTS:',len(records),'exact normalized skin/UV contracts; next run BakeSourceVariants.gd')


def check_prepared():
    pins = inputs()
    path = ART/'source_variants/preparation.json'
    report = json.loads(path.read_text())
    assert report['manifest_sha256'] == sha(MANIFEST) and report['preparer_sha256'] == sha(Path(__file__))
    assert report['baker_sha256'] == sha(ROOT/'Viewer/Presentation/BakeSourceVariants.gd')
    assert report['pin_helper_sha256'] == sha(ROOT/'scripts/prepare-source-preserving.py')
    assert report['runtime_sha256'] == {name:sha(ROOT/'Viewer/Presentation'/name) for name in RUNTIME}
    for name, digest in report['converter_sha256'].items():
        assert sha(ROOT/'scripts'/name) == digest, name
    assert len(report['models']) == len(pins['models'])
    for model, row in zip(pins['models'], report['models']):
        assert row['source_provenance'] == model and row['kind'] == model['kind']
        assert len(row['bodies']) == 1 and row['bodies'][0]['body'] == model['body']
        assert row['source_motion_contract']['uv_coordinates_exact']
        assert row['presentation_script'] == model['presentation_script']
        assert row['presentation_script_sha256'] == sha(ROOT/'Viewer'/row['presentation_script'].removeprefix('res://'))
        for treatment, asset in row['assets'].items():
            output = (ROOT/'Viewer'/asset.removeprefix('res://')).resolve()
            assert output.parent == ART.resolve() and sha(output) == row['saved_scenes'][treatment]['asset_sha256']
            assert row['saved_scenes'][treatment]['donor_asset_sha256'] == model['donor_assets'][treatment]['sha256']
        for name, digest in row['art_dependency_sha256'].items():
            assert Path(name).name == name and sha(ART/name) == digest
    print('SOURCE VARIANT PREPARATION:',len(report['models']),'current exact-source inputs/donors and saved candidates; no accepted routes')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-inputs', action='store_true')
    parser.add_argument('--check-prepared', action='store_true')
    args = parser.parse_args()
    if args.check_prepared:
        check_prepared()
    elif args.check_inputs:
        print('SOURCE VARIANT INPUTS:',len(inputs()['models']),'exact source/donor records checked')
    else:
        prepare()
