"""Activate bounded local Savage human graphics; native gameplay stays separate."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT/'Viewer/local-art/human-npcs'
WORK = ROOT/'work/creatures/savages'
OUTPUT = ART/'accepted-index.json'
RECEIPT = ART/'savages/local-presentation.json'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def resource(name):
    path = ROOT/'Viewer'/name.removeprefix('res://') if name.startswith('res://') else ROOT/name
    path = path.resolve()
    assert path.is_relative_to(ROOT), 'Evidence must stay in this workspace'
    return path


def proof(path):
    report = read(path)
    assert report['checks'] > 0 and report['failures'] == 0, str(path)
    assert report.get('runtime_sha256'), 'Missing runtime evidence: '+str(path)
    for name, digest in report['runtime_sha256'].items():
        target = resource(name) if name.startswith('res://') else ROOT/'Viewer/Presentation'/name
        assert sha(target) == digest, 'Changed runtime: '+name
    for name, digest in report.get('inputs_sha256',{}).items():
        if name == 'res://local-art/creatures/accepted-index.json':
            # Riding tests inject the exact three prepared source mounts.
            # This index fingerprint checks no mutation DURING that trial;
            # unrelated later registry growth does not change those actors.
            continue
        assert sha(resource(name)) == digest, 'Changed input: '+name
    return report


def checked_profiles():
    for command in [['prepare-savage-profiles.py','--check-inputs'],['check-savage-actions.py']]:
        subprocess.run([sys.executable,'-B',str(ROOT/'scripts'/command[0]),*command[1:]],check=True)
    pins = {}
    foot_path, rider_path = ART/'savages/preparation.json', ART/'savages/riders.json'
    foot, riders = read(foot_path), read(rider_path)
    manifest = ROOT/'scripts/savage-profile-inputs.json'
    assert foot['input_manifest_sha256'] == riders['input_manifest_sha256'] == sha(manifest)
    assert foot['recipe_sha256'] == riders['recipe_sha256'] == sha(ROOT/'scripts/prepare-savage-profiles.py')
    assert riders['source_foot_profiles_sha256'] == sha(foot_path)
    assert riders['server_pin'] == read(ROOT/'Server/dependencies.json')['modernuo']['revision']
    proofs = [WORK/name for name in ['profile-tests.json','human-npc-motion-tests.json','action-integration-tests.json',
                                    'ground-tests.json','death-tests.json','death-floor-tests.json']]
    proofs += [ROOT/'work/creatures/ridgebacks/riding/validation.json',ROOT/'work/creatures/ridgebacks/death-contact/validation.json']
    for path in proofs:
        report = proof(path)
        pins[path.relative_to(ROOT).as_posix()] = sha(path)
    visual = read(WORK/'profile-tests.json')
    assert visual['preparation_sha256'] == sha(foot_path) and visual['input_manifest_sha256'] == sha(manifest)
    assert 'Forward+' in (WORK/'profile-current-gpu.log').read_text()
    assert 'ERROR:' not in (WORK/'profile-current-gpu.log').read_text()
    riding = read(ROOT/'work/creatures/ridgebacks/riding/validation.json')
    assert riding['renderer'] == 'forward_plus' and riding['exact_paint_normals_tangents'] is True
    assert len(riding['samples']) == 336 and len(riding['corpses']) == 6
    assert 'Forward+' in (ROOT/'work/creatures/ridgebacks/riding-current-gpu.log').read_text()
    assert 'ERROR:' not in (ROOT/'work/creatures/ridgebacks/riding-current-gpu.log').read_text()
    source_mounts = read(ROOT/'Viewer/local-art/creatures/source_preserving/preparation.json')['models']
    accepted_mounts = read(ROOT/'Viewer/local-art/creatures/accepted-index.json')['entries']
    for body in [187,188]:
        original = next(row for row in source_mounts if any(int(item['body']) == body for item in row['bodies']))
        current = next(row for row in accepted_mounts if any(int(item['body']) == body for item in row['bodies']))
        assert current['status'] == 'validated' and current['assets'] == original['assets']
        assert current['presentation_script'] == original['presentation_script']
        for treatment,path in original['assets'].items():
            assert sha(resource(path)) == original['saved_scenes'][treatment]['scene_sha256']
    dance_path = ART/'savages/dance/preparation.json'
    dance = read(dance_path)
    pins.update(foot=sha(foot_path),riders=sha(rider_path),dance=sha(dance_path),manifest=sha(manifest))
    profiles = []
    for original in foot['profiles']+riders['profiles']:
        body = int(original['body'])
        assert body in [183,184,185,186] and bool(original['female']) == (body in [184,186])
        gender = 'female' if original['female'] else 'male'
        motion = next(row for row in dance['models'] if row['gender'] == gender)
        assert sha(resource(motion['asset'])) == motion['asset_sha256']
        row = copy.deepcopy(original)
        pending = row.pop('missing',[])
        row.update(status='validated',tribal_dance={'asset':motion['asset'],'sha256':motion['asset_sha256']},
                   original_pending=pending,
                   validation_scope='Local modern human graphics, exact gender/paint/hue/wardrobe, original-retargeted111, finite ground/death and original Ridgeback rider support. Not a native-live or full-family certificate.',
                   remaining_fidelity=['Current native two-client/AI/combat/loot/ownership verification',
                                       'Tribal/deer/orc mask and bone-armour visual fidelity',
                                       'Mixed treads/spawn/continuous terrain, final art/LOD/crowd cost'])
        profiles.append(row)
    assert {row['body'] for row in profiles} == {183,184,185,186}
    return profiles, pins


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--publish',action='store_true')
    group.add_argument('--check-active',action='store_true')
    args = parser.parse_args()
    profiles, pins = checked_profiles()
    index = read(OUTPUT) if OUTPUT.exists() else {'profiles':[]}
    incoming = {row['body'] for row in profiles}
    if args.check_active:
        receipt = read(RECEIPT)
        assert receipt['publisher_sha256'] == sha(Path(__file__)) and receipt['evidence_pins'] == pins
        assert {row['body']:row for row in index['profiles'] if row['body'] in incoming} == {row['body']:row for row in profiles}
    if args.publish:
        backup = WORK/'human-index-before-local-presentation.json'
        if OUTPUT.exists() and not backup.exists():backup.write_bytes(OUTPUT.read_bytes())
        for old in index['profiles']:
            assert old['body'] not in incoming or old.get('skin') == 'savage', 'Refusing to replace an unrelated human profile'
        index['profiles'] = [row for row in index['profiles'] if row['body'] not in incoming]+profiles
        index['scope'] = 'Bounded local human NPC presentation; native behaviour and final art remain separate.'
        temporary = OUTPUT.with_suffix('.json.pending')
        temporary.write_text(json.dumps(index,indent=2)+'\n',encoding='utf-8')
        temporary.replace(OUTPUT)
        RECEIPT.write_text(json.dumps({'publisher_sha256':sha(Path(__file__)),'evidence_pins':pins},indent=2)+'\n',encoding='utf-8')
    print('SAVAGE HUMAN ROUTES:', 'published' if args.publish else 'active verified' if args.check_active else 'dry run',len(profiles),'bodies; no new native-live witness')


if __name__ == '__main__':
    main()
