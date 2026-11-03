"""Activate the reviewed Lava/Blood/Mummy/Solen/Ice local presentations.

Each existing source/import/terrain/death checker remains authoritative. Actual
GPU evidence is additional; this does not certify native multiplayer behaviour.
"""
import argparse
import copy
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('local_presentation_helpers', ROOT/'scripts/accept-source-preserving.py')
common = importlib.util.module_from_spec(spec)
spec.loader.exec_module(common)
ART, sha, read, resource = common.ART, common.sha, common.read, common.resource
RECEIPT = ART/'reviewed_presentations/local-presentation.json'
FAMILIES = {
    'variants': ('source_variants/preparation.json', 'prepare-source-variants.py', '--check-prepared'),
    'mummies': ('mummies/preparation.json', 'check-prepared-mummy.py', '--runtime'),
    'solen': ('solen_warriors/preparation.json', 'check-solen-warrior-sources.py', '--fidelity'),
    'ice': ('ice_elementals/candidate.json', 'check-source-ice-elemental.py', '--candidate'),
}


def checked_rows(folder):
    presentation_path = folder/'presentation/validation.json'
    presentation = read(presentation_path)
    assert presentation['checks'] > 0 and presentation['failures'] == 0 and presentation['renderer'] == 'forward_plus'
    runtime = presentation['runtime_sha256']
    assert {'CandidatePresentationBatchTests.gd','CreatureAppearanceTests.gd','CreatureRegistry.gd',
            'CreatureVisual.gd','HumanAvatar.gd','CreatureDeaths.gd','CorpseModels.gd','SkinGeometry.gd',
            'SourceRenderedPose.gd','SourceVariantPoseEntry.gd','OstardSurface.gdshader'} <= set(runtime)
    for name, digest in runtime.items():
        assert Path(name).name == name and sha(ROOT/'Viewer/Presentation'/name) == digest, 'Rendered runtime changed: '+name
    for name, digest in presentation['inputs_sha256'].items():
        assert sha(resource(name)) == digest, 'Rendered input changed: '+name
    native_map = common.module('reviewed_native_map', 'prepare-creatures.py')
    _, native = native_map.native_bodies()
    profiles = native_map.body_profiles()
    rows, evidence = [], {'presentation':sha(presentation_path)}
    for label, (relative, checker, flag) in FAMILIES.items():
        subprocess.run([sys.executable,'-B',str(ROOT/'scripts'/checker),flag],check=True)
        preparation_path = ART/relative
        preparation = read(preparation_path)
        preparation_pin = sha(preparation_path)
        assert presentation['inputs_sha256']['res://local-art/creatures/'+relative] == preparation_pin
        appearance_path = folder/label/'appearance.json'
        appearance = read(appearance_path)
        assert appearance['checks'] > 0 and appearance['failures'] == 0 and appearance['renderer'] == 'forward_plus'
        assert appearance['preparation_sha256'] == preparation_pin
        assert appearance['test_sha256'] == sha(ROOT/'Viewer/Presentation/CreatureAppearanceTests.gd')
        evidence[label] = {'preparation':preparation_pin,'appearance':sha(appearance_path),'checker':sha(ROOT/'scripts'/checker)}
        if label == 'variants':
            saved_path = ROOT/'work/creatures/source-variants/skin-proof.json'
            saved = read(saved_path)
            assert saved['checks'] == 2805 and saved['failures'] == 0
            assert saved['preparation_sha256'] == preparation_pin
            assert saved['test_sha256'] == sha(ROOT/'Viewer/Presentation/SourceVariantSkinTests.gd')
            expected = {(row['kind'],treatment) for row in preparation['models'] for treatment in ['original','rounded','modern']}
            assert {(row['kind'],row['treatment']) for row in saved['scenes']} == expected
            for record in saved['scenes']:
                model = next(row for row in preparation['models'] if row['kind'] == record['kind'])
                assert record['asset_sha256'] == sha(resource(model['assets'][record['treatment']]))
            evidence[label]['saved_skin'] = sha(saved_path)
        for original in preparation['models']:
            assert original['status'] == 'prepared'
            kind = original['kind']
            expected_clips = set(original['stats']['original']['clips'])
            samples = [row for row in presentation['samples'] if row['kind'] == kind]
            assert len(samples) == len(expected_clips)*2
            assert {(row['clip'],row['plane']) for row in samples} == {(clip,plane) for clip in expected_clips for plane in ['flat','cross']}
            deaths = [row for row in presentation['death_entries'] if row['kind'] == kind]
            assert len(deaths) == 2 and {row['plane'] for row in deaths} == {'flat','cross'}
            assert all(row['first_displayed_skin_error_m'] < .001 for row in deaths)
            views = [row for row in appearance['samples'] if row['kind'] == kind]
            assert len(views) == 6 and {row['clip'] for row in views} == {'Walk','Run','Attack'}
            assets = original.get('assets') or {t:'res://local-art/creatures/'+kind+'-'+t+'.gltf' for t in ['original','rounded','modern']}
            assert Path(original['presentation_script']).name in runtime
            for path in assets.values():
                assert presentation['inputs_sha256'][path] == sha(resource(path))
            for view in views:
                assert view['asset_path'] == assets['modern'] and view['asset_sha256'] == sha(resource(assets['modern']))
                assert view['art_dependency_sha256'] == original.get('art_dependency_sha256',{})
            for identity in original['bodies']:
                body = int(identity['body'])
                signature = lambda records: sorted((row['path'].replace('\\','/'),row['sha256']) for row in records)
                assert native.get(body) and signature(identity['native_sources']) == signature(native[body])
                assert identity['native_profile'] == profiles.get(body)
            result = copy.deepcopy(original)
            pending = result.pop('pending_render_feature',None)
            result.pop('pending_features',None)
            result.update(status='validated',assets=assets,
                          local_preparation_sha256=preparation_pin,
                          gpu_sha256=sha(appearance_path),presentation_validation_sha256=sha(presentation_path),
                          gpu_runtime_sha256=runtime,
                          asset_sha256={key:sha(resource(path)) for key,path in assets.items()},
                          validation_scope='Exact family source/import/pose/finite-terrain/death contracts plus current GPU avatar/full-hue/alpha views and actual static corpses. Bounded local presentation only; no new native server witness.',
                          remaining_fidelity=['Native AI/permissions/combat/loot and every constructor sharing a body',
                                              'Continuous cadence, mixed ledges/spawn, physical no-slip and untested death slopes',
                                              'Partial-dye pixels, recovered original shader semantics, final art/LOD/crowd cost'])
            if pending:result['original_preparation_pending_marker'] = pending
            rows.append(result)
    expected_kinds = {row['kind'] for row in rows}
    assert len(rows) == 6 and {row['kind'] for row in presentation['samples']} == expected_kinds
    assert {row['kind'] for row in presentation['death_entries']} == expected_kinds
    return rows, evidence


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence',type=Path,default=ROOT/'work/creatures/route-promotion')
    parser.add_argument('--publish',action='store_true')
    parser.add_argument('--check-active',action='store_true')
    args = parser.parse_args()
    assert not (args.publish and args.check_active)
    if args.check_active:
        receipt = read(RECEIPT)
        assert receipt['publisher_sha256'] == sha(Path(__file__))
        args.evidence = ROOT/receipt['evidence']
    assert args.evidence.resolve().is_relative_to(ROOT/'work'), 'Keep local evidence private under work/'
    rows, evidence = checked_rows(args.evidence)
    accepted = ART/'accepted-index.json'
    report = read(accepted)
    incoming = {row['kind'] for row in rows}
    existing = {int(identity['body']):row['kind'] for row in report['entries'] for identity in row['bodies']}
    for row in rows:
        for identity in row['bodies']:
            assert int(identity['body']) not in existing or existing[int(identity['body'])] == row['kind'], 'Refusing to replace an unrelated working creature'
    if args.check_active:
        active = {row['kind']:row for row in report['entries'] if row['kind'] in incoming}
        assert active == {row['kind']:row for row in rows}, 'Active reviewed presentations changed'
        assert receipt['evidence_pins'] == evidence
    if args.publish:
        backup = args.evidence/'accepted-index-before-reviewed.json'
        if not backup.exists():backup.write_bytes(accepted.read_bytes())
        report['entries'] = [row for row in report['entries'] if row['kind'] not in incoming]+rows
        pending = accepted.with_suffix('.json.pending')
        pending.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
        pending.replace(accepted)
        RECEIPT.parent.mkdir(parents=True,exist_ok=True)
        receipt = {'publisher_sha256':sha(Path(__file__)),'evidence':args.evidence.resolve().relative_to(ROOT).as_posix(),'evidence_pins':evidence,
                   'scope':'Six local presentations; native server witnesses remain separate.'}
        pending = RECEIPT.with_suffix('.json.pending')
        pending.write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
        pending.replace(RECEIPT)
    print('REVIEWED LOCAL PRESENTATIONS:', 'published' if args.publish else 'active verified' if args.check_active else 'dry run',len(rows),'forms /',sum(len(row['bodies']) for row in rows),'body routes; no new live-server witness')


if __name__ == '__main__':
    main()
