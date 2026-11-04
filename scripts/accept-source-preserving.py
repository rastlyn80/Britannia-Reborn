"""Activate checked local source presentations; native gameplay remains separate.

Requires current saved skins/corpses, actual GPU avatar/appearance evidence and
action timing/material checks for every prepared form. Original art stays local.
"""
import argparse
import copy
import hashlib
import importlib.util
import json
import runpy
from pathlib import Path

ALIAS_EVIDENCE = runpy.run_path(str(Path(__file__).with_name('legacy-action-evidence.py')))

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT/'Viewer/local-art/creatures'
PREPARATION = ART/'source_preserving/preparation.json'
RECEIPT = ART/'source_preserving/local-presentation.json'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def resource(path):
    assert path.startswith('res://'), path
    resolved = (ROOT/'Viewer'/path.removeprefix('res://')).resolve()
    assert resolved.is_relative_to((ROOT/'Viewer').resolve()), path
    return resolved


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT/'scripts'/filename)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def checked_rows(presentation_path, appearance_path):
    preparation = module('source_accept_inputs', 'prepare-source-preserving.py').check_prepared()
    skin_path = ROOT/'work/creatures/source-preserving/skin-proof.json'
    action_path = ROOT/'work/creatures/source-preserving/actions.json'
    skin, actions = read(skin_path), read(action_path)
    presentation, appearance = read(presentation_path), read(appearance_path)
    pin = sha(PREPARATION)
    models = {row['kind']:row for row in preparation['models']}
    for proof in [skin, actions, presentation, appearance]:
        assert proof['checks'] > 0 and proof['failures'] == 0, 'A required presentation gate failed'
    for proof in [skin, actions, appearance]:
        assert proof['preparation_sha256'] == pin, 'Evidence belongs to another preparation'
    assert skin['test_sha256'] == sha(ROOT/'Viewer/Presentation/SourcePreservingSkinTests.gd')
    assert skin['helper_sha256'] == sha(ROOT/'Viewer/Presentation/SourcePoseSubdivision.gd')
    assert actions['test_sha256'] == sha(ROOT/'Viewer/Presentation/SourcePreservingActionTests.gd')
    assert appearance['test_sha256'] == sha(ROOT/'Viewer/Presentation/CreatureAppearanceTests.gd')
    assert {row['kind'] for row in skin['models']} == set(models)
    assert {row['kind'] for row in actions['models']} == set(models)
    assert presentation['renderer'] == appearance['renderer'] == 'forward_plus'
    assert presentation['inputs_sha256']['res://local-art/creatures/source_preserving/preparation.json'] == pin
    for name, digest in presentation['inputs_sha256'].items():
        assert sha(resource(name)) == digest, 'Rendered input changed: '+name
    runtime = presentation['runtime_sha256']
    required = {'CandidatePresentationBatchTests.gd','CreatureAppearanceTests.gd',
                'SourcePreservingCreatureVisual.gd','SourceIronGolemVisual.gd','SourceFrostOozeVisual.gd',
                'SourceAmorphousMaterial.gd','SourceAmorphousSurface.gdshader','CreatureCutoutSurface.gdshader',
                'OstardSurface.gdshader','CreatureVisual.gd','CreatureRegistry.gd','HumanAvatar.gd',
                'SourceVariantPoseEntry.gd','CreatureDeaths.gd','CorpseModels.gd','SkinGeometry.gd'}
    assert required <= set(runtime), 'Incomplete runtime/shader evidence'
    for name, digest in runtime.items():
        assert Path(name).name == name and sha(ROOT/'Viewer/Presentation'/name) == digest, 'Rendered runtime changed: '+name
    assert {row['kind'] for row in presentation['samples']} == set(models)
    assert {row['kind'] for row in appearance['samples']} == set(models)
    pipeline = module('source_accept_native_map', 'prepare-creatures.py')
    _, native = pipeline.native_bodies()
    profiles = pipeline.body_profiles()
    rows, excluded = [], []
    for kind, row in models.items():
        expected = set(row['stats']['original']['clips'])
        saved = next(item for item in skin['models'] if item['kind'] == kind)
        assert set(saved['clips']) == expected and saved['poses'] == len(expected)*3
        assert saved['maximum_source_triangle_distance_m'] < .002
        samples = [item for item in presentation['samples'] if item['kind'] == kind]
        assert len(samples) == len(expected)*2
        assert {(item['clip'],item['plane']) for item in samples} == {(clip,plane) for clip in expected for plane in ['flat','cross']}
        deaths = [item for item in presentation['death_entries'] if item['kind'] == kind]
        assert len(deaths) == 2 and {item['plane'] for item in deaths} == {'flat','cross'}
        assert all(item['first_displayed_skin_error_m'] < .001 for item in deaths)
        views = [item for item in appearance['samples'] if item['kind'] == kind]
        assert len(views) == 6 and {item['clip'] for item in views} == {'Walk','Run','Attack'}
        for item in views:
            assert item['asset_path'] == row['assets']['modern']
            assert item['asset_sha256'] == sha(resource(row['assets']['modern']))
            assert item['art_dependency_sha256'] == row['art_dependency_sha256']
        bodies = []
        for identity in row['bodies']:
            body = int(identity['body'])
            # These keys describe source presentation variants, not witnessed
            # loose native bodies. Mount-only registration needs its own path.
            if body in [193,272]:
                excluded.append({'body':body,'kind':kind,'reason':'Mount-only193 or source-table compatibility272; not a loose native route'})
                continue
            signature = lambda records: sorted((item['path'],item['sha256']) for item in records)
            assert native.get(body) and signature(identity['native_sources']) == signature(native[body])
            assert identity['native_profile'] == profiles.get(body) and profiles[body] in ['animal','monster','sea']
            bodies.append(identity)
        if not bodies:
            continue
        result = copy.deepcopy(row)
        result.update(status='validated', bodies=bodies,
                      validation_sha256=sha(skin_path), gpu_sha256=sha(appearance_path),
                      action_validation_sha256=sha(action_path), presentation_validation_sha256=sha(presentation_path),
                      gpu_runtime_sha256=runtime,
                      asset_sha256={key:sha(resource(path)) for key,path in row['assets'].items()},
                      validation_scope='Local presentation: complete saved skins, three off-grid phases per clip, two rendered finite-plane phases, full hue/alpha, repeated cast timing/material contracts and frozen/entry corpses. No native-server certificate.',
                      remaining_fidelity=['Native AI/permissions/combat/loot and all constructors sharing a body',
                                          'Continuous cadence/transitions, mixed ledges, spawn settling and physical no-slip',
                                          'Partial-dye pixels, final art, LOD and crowd cost'])
        if kind == 'four_armed_demon':
            result['remaining_fidelity'].append('Original Idle rejects duplicate bone names; held valid Fidget rest needs breathing/polish')
        rows.append(result)
    return rows, excluded


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--presentation', type=Path, default=ROOT/'work/creatures/next-family/presentation-final/validation.json')
    parser.add_argument('--appearance', type=Path, default=ROOT/'work/creatures/next-family/appearance-final/appearance.json')
    parser.add_argument('--publish', action='store_true', help='Atomically update the private local presentation index after every gate passes')
    parser.add_argument('--check-active', action='store_true', help='Verify current locally activated rows against their exact evidence receipt')
    args = parser.parse_args()
    assert not (args.publish and args.check_active)
    if args.check_active:
        receipt = read(RECEIPT)
        ALIAS_EVIDENCE['check_publisher'](Path(__file__).name, receipt['publisher_sha256'], sha(Path(__file__)))
        args.presentation = ROOT/receipt['presentation']
        args.appearance = ROOT/receipt['appearance']
    for path in [args.presentation,args.appearance]:
        assert path.resolve().is_relative_to(ROOT), 'Evidence must stay in this workspace'
    rows, excluded = checked_rows(args.presentation, args.appearance)
    accepted = ART/'accepted-index.json'
    report = read(accepted)
    incoming = {row['kind'] for row in rows}
    rows = ALIAS_EVIDENCE['expected_rows_with_legacy_aliases'](rows, report['entries'])
    bodies = {identity['body']:row['kind'] for row in report['entries'] for identity in row['bodies']}
    for row in rows:
        for identity in row['bodies']:
            assert identity['body'] not in bodies or bodies[identity['body']] == row['kind'], 'Refusing to replace an unrelated working creature'
    if args.check_active:
        assert receipt['preparation_sha256'] == sha(PREPARATION)
        active = {row['kind']:row for row in report['entries'] if row['kind'] in incoming}
        assert active == {row['kind']:row for row in rows}, 'Activated presentation differs from checked evidence'
    if args.publish:
        backup = ROOT/'work/creatures/next-family/accepted-index-before-source-batch.json'
        if not backup.exists():backup.write_bytes(accepted.read_bytes())
        report['entries'] = [row for row in report['entries'] if row['kind'] not in incoming]+rows
        report['scope'] = 'Passing bounded local presentation/skin/GPU/corpse evidence. Native server witnesses remain a separate ledger; not universal animation/final-art certification or redistributable assets.'
        pending = accepted.with_suffix('.json.pending')
        pending.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
        pending.replace(accepted)
        receipt = {'publisher_sha256':sha(Path(__file__)), 'preparation_sha256':sha(PREPARATION),
                   'presentation':args.presentation.resolve().relative_to(ROOT).as_posix(),
                   'appearance':args.appearance.resolve().relative_to(ROOT).as_posix(),
                   'scope':'Local presentation activation only; native witnesses and remaining fidelity are separate.'}
        pending_receipt = RECEIPT.with_suffix('.json.pending')
        pending_receipt.write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
        pending_receipt.replace(RECEIPT)
    print('SOURCE LOCAL PRESENTATIONS:', 'published' if args.publish else 'active verified' if args.check_active else 'dry run', len(rows),'forms;',sum(len(row['bodies']) for row in rows),'native body routes; excluded',excluded,'; no new native-server witness')


if __name__ == '__main__':
    main()
