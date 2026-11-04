"""Activate the checked source-family/reused-asset batch; art remains local."""
import argparse
import copy
import importlib.util
import json
import os
import runpy
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT/'Viewer/local-art/creatures'
WORK = ROOT/'work/creatures/shared-batch'
RECEIPT = ART/'source_family_batch/local-presentation.json'
spec = importlib.util.spec_from_file_location('batch_helpers',ROOT/'scripts/accept-source-preserving.py')
helpers = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helpers)
sha, read, resource = helpers.sha, helpers.read, helpers.resource


def checked_rows():
    for name in ['prepare-source-family-batch.py','prepare-source-reused-variants.py']:
        subprocess.run([sys.executable,'-B',str(ROOT/'scripts'/name),'--check-prepared'],check=True)
    presentation = read(WORK/'presentation-final/validation.json')
    assert presentation['checks'] > 0 and presentation['failures'] == 0 and presentation['renderer'] == 'forward_plus'
    assert 'ERROR:' not in (WORK/'presentation-final.log').read_text()
    for name, digest in presentation['runtime_sha256'].items():
        assert sha(ROOT/'Viewer/Presentation'/name) == digest, 'Rendered runtime changed: '+name
    for name, digest in presentation['inputs_sha256'].items():
        assert sha(resource(name)) == digest, 'Rendered input changed: '+name
    skin, actions = read(WORK/'skin-proof.json'), read(WORK/'actions.json')
    for proof, base in [(skin,'SourcePreservingSkinTests.gd'),(actions,'SourcePreservingActionTests.gd')]:
        assert proof['checks'] > 0 and proof['failures'] == 0
        assert proof['test_sha256'] == sha(ROOT/'Viewer/Presentation'/base)
    assert skin['helper_sha256'] == sha(ROOT/'Viewer/Presentation/SourcePoseSubdivision.gd')
    native_map = helpers.module('batch_native','prepare-creatures.py')
    _, native = native_map.native_bodies()
    profiles = native_map.body_profiles()
    rows, pins = [], {}
    for relative in ['source_family_batch/preparation.json','source_reused_variants/preparation.json']:
        path = ART/relative
        preparation = read(path)
        pin = sha(path)
        pins[relative] = pin
        assert presentation['inputs_sha256']['res://local-art/creatures/'+relative] == pin
        if relative.startswith('source_family_batch/'):
            assert skin['preparation_sha256'] == actions['preparation_sha256'] == pin
            expected = {row['kind'] for row in preparation['models']}
            assert {row['kind'] for row in skin['models']} == {row['kind'] for row in actions['models']} == expected
        for row in preparation['models']:
            kind = row['kind']
            clips = set(row['stats']['original']['clips'])
            samples = [item for item in presentation['samples'] if item['kind'] == kind]
            assert len(samples) == 2*len(clips)
            assert {(item['clip'],item['plane']) for item in samples} == {(clip,plane) for clip in clips for plane in ['flat','cross']}
            deaths = [item for item in presentation['death_entries'] if item['kind'] == kind]
            assert len(deaths) == 2 and {item['plane'] for item in deaths} == {'flat','cross'}
            assert all(item['first_displayed_skin_error_m'] < .001 for item in deaths)
            if relative.startswith('source_family_batch/'):
                saved = next(item for item in skin['models'] if item['kind'] == kind)
                assert set(saved['clips']) == clips and saved['poses'] == 3*len(clips)
                assert saved['maximum_source_triangle_distance_m'] < .002
            assert sha(resource(row['presentation_script'])) == row['presentation_script_sha256']
            appearance_path = WORK/'review'/kind/'appearance.json'
            appearance = read(appearance_path)
            assert appearance['checks'] > 0 and appearance['failures'] == 0 and appearance['renderer'] == 'forward_plus'
            assert appearance['preparation_sha256'] == pin
            assert appearance['test_sha256'] == sha(ROOT/'Viewer/Presentation/CreatureAppearanceTests.gd')
            assert 'ERROR:' not in appearance_path.with_name('appearance.log').read_text()
            views = appearance['samples']
            assert len(views) == 6 and {view['clip'] for view in views} == {'Walk','Run','Attack'}
            for view in views:
                assert view['kind'] == kind and view['asset_path'] == row['assets']['modern']
                assert view['asset_sha256'] == sha(resource(row['assets']['modern']))
                assert view['art_dependency_sha256'] == row.get('art_dependency_sha256',{})
            for identity in row['bodies']:
                body = int(identity['body'])
                signature = lambda entries: sorted((item['path'].replace('\\','/'),item['sha256']) for item in entries)
                assert native.get(body) and signature(identity['native_sources']) == signature(native[body])
                assert identity['native_profile'] == profiles[body]
            result = copy.deepcopy(row)
            result.update(status='validated',gpu_sha256=sha(appearance_path),presentation_validation_sha256=sha(WORK/'presentation-final/validation.json'),
                          validation_scope='Bounded local source/asset/skin, visible tint/alpha, finite-plane, decoded death-entry and static corpse support. Native behaviour and final art remain separate.',
                          remaining_fidelity=['Native AI/combat/permissions/loot and all constructors sharing a body','Continuous cadence/transitions, mixed ledges/spawn, physical no-slip','Partial-dye pixel masks, original shader semantics, final art/LOD/crowd cost'])
            rows.append(result)
            pins[kind] = sha(appearance_path)
    kinds = {row['kind'] for row in rows}
    assert rows and len(kinds) == len(rows) and {row['kind'] for row in presentation['samples']} == kinds
    # Activation adds normal-registry assertions to the same action test. Its
    # count can increase without changing these checked action/input contracts.
    pins.update(presentation=sha(WORK/'presentation-final/validation.json'),skin=sha(WORK/'skin-proof.json'),
                actions={key:actions[key] for key in ['test_sha256','preparation_sha256','models','failures']})
    return rows, pins


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--publish',action='store_true')
    mode.add_argument('--activate-gargoyle-pillage',action='store_true')
    mode.add_argument('--check-active',action='store_true')
    args = parser.parse_args()
    rows, pins = checked_rows()
    path = ART/'accepted-index.json'
    previous = path.read_bytes()
    index = read(path)
    gargoyle = runpy.run_path(str(ROOT/'scripts/gargoyle-pillage-evidence.py'))
    base = next(row for row in rows if row['kind'] == gargoyle['KIND'])
    current = next((row for row in index['entries'] if row['kind'] == gargoyle['KIND']), {})
    overlay_active = 'authored_action_native_sha256' in current
    if overlay_active:
        overlay = gargoyle['compose'](base, True)
        assert current == overlay, 'Gargoyle action overlay or base package changed'
        rows = [overlay if row is base else row for row in rows]
    incoming = {row['kind'] for row in rows}
    existing = {int(body['body']):row['kind'] for row in index['entries'] for body in row['bodies']}
    for row in rows:
        for body in row['bodies']:
            assert int(body['body']) not in existing or existing[int(body['body'])] == row['kind'], 'Refusing to replace an unrelated working creature'
    if args.check_active or args.activate_gargoyle_pillage:
        receipt = read(RECEIPT)
        assert receipt['publisher_sha256'] in (
            sha(Path(__file__)), '45ba8a2a4212f2d1728b2a13c5c940f235f2e6b23bef4da99e552bc110b96950')
        assert receipt['evidence_pins'] == pins
        assert {row['kind']:row for row in index['entries'] if row['kind'] in incoming} == {row['kind']:row for row in rows}
    if args.activate_gargoyle_pillage:
        if overlay_active:
            raise ValueError('Gargoyle Pillage is already active')
        if read(gargoyle['LIVE'])['accepted_index_sha256'] != sha(path):
            raise ValueError('Registry changed since the isolated Gargoyle trial')
        overlay = gargoyle['compose'](base, False)
        gargoyle['seal']()
        assert overlay == gargoyle['compose'](base, True)
        index['entries'] = [overlay if row['kind'] == gargoyle['KIND'] else row for row in index['entries']]
        if path.read_bytes() != previous:
            raise RuntimeError('Registry changed during Gargoyle activation')
        temporary = path.with_suffix('.gargoyle.pending')
        updated = (json.dumps(index, indent=2) + '\n').encode()
        temporary.write_bytes(updated)
        temporary.replace(path)
        try:
            godot = next((ROOT/'.tools/godot').glob('*console.exe'))
            profile = str(ROOT/'.godot-user')
            env = dict(os.environ, APPDATA=profile, LOCALAPPDATA=profile)
            command = [str(godot), '--headless', '--path', str(ROOT/'Viewer'), '--script']
            for test in [
                ['res://../scripts/test-gargoyle-pillage-trial.gd', '--', '--active'],
                ['res://Presentation/CreatureBatchRouteTests.gd'],
            ]:
                subprocess.run(command + test, cwd=ROOT, env=env, check=True, timeout=150)
            subprocess.run([sys.executable, '-B', str(ROOT/'scripts/prepare-source-family-batch.py'),
                            '--check-actions'], cwd=ROOT, check=True, timeout=180)
        except (Exception, KeyboardInterrupt):
            if path.read_bytes() == updated:
                temporary.write_bytes(previous)
                temporary.replace(path)
            raise
        print('Gargoyle 753 Pillage: active and verified')
        return
    if args.publish:
        backup = WORK/'accepted-index-before-family-batch.json'
        if not backup.exists():backup.write_bytes(path.read_bytes())
        index['entries'] = [row for row in index['entries'] if row['kind'] not in incoming]+rows
        temporary = path.with_suffix('.json.pending')
        temporary.write_text(json.dumps(index,indent=2)+'\n',encoding='utf-8')
        temporary.replace(path)
        RECEIPT.parent.mkdir(parents=True,exist_ok=True)
        RECEIPT.write_text(json.dumps({'publisher_sha256':sha(Path(__file__)),'evidence_pins':pins,'scope':'Five bounded local presentations; no new live native witness.'},indent=2)+'\n',encoding='utf-8')
    print('SOURCE FAMILY ROUTES:', 'published' if args.publish else 'active verified' if args.check_active else 'dry run',len(rows),'bodies; native-live coverage unchanged')


if __name__ == '__main__':
    main()
