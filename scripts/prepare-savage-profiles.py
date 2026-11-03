"""Prepare human-type Savage candidates without changing accepted body routes."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'work/third-dawn/late-source-research/uoaos-source'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-inputs', action='store_true')
    args = parser.parse_args()
    manifest = ROOT / 'scripts/savage-profile-inputs.json'
    pins = json.loads(manifest.read_text(encoding='utf-8'))
    for row in pins['reference_source']['files']:
        path = (SOURCE / row['path']).resolve()
        assert path.is_relative_to(SOURCE.resolve())
        assert path.stat().st_size == row['bytes'] and sha(path) == row['sha256'], row['path']
    for row in pins['reference_source']['cabinets']:
        path = SOURCE.parent / 'uoaos-cabinets' / Path(row['zip_member']).name
        assert path.stat().st_size == row['bytes'] and sha(path) == row['sha256'], path
    for row in pins['native_sources']:
        assert sha(ROOT / 'Server/ModernUO' / row['path']) == row['sha256'], row['path']
    for name, digest in pins['prepared_art'].items():
        assert sha(ROOT / name) == digest, name
    print('SAVAGE INPUTS: exact original references, native identities and existing modern human art pass')
    if args.check_inputs:
        return
    profiles = [dict(body=body, female=body == 184, skin='savage', name='Savage / ' + gender,
                     status='prepared', native_classes=['Savage', 'SavageShaman'],
                     missing=['native two-client evidence', 'tribal/deer/orc masks', 'bone armour visual fidelity',
                              'Shaman action 111 dance',
                              'terrain and death transition evidence'])
                for body, gender in [(183, 'male'), (184, 'female')]]
    result = dict(profiles=profiles, input_manifest_sha256=sha(manifest), recipe_sha256=sha(Path(__file__)),
                  prepared_rider_bodies=[185, 186],
                  rider_requirement='Real native SavageRidgeback source, mount packet and riding integration; no horse substitute',
                  scope='Prepared shared modern human profiles only. No accepted-index update, native behaviour or added coverage.')
    output = ROOT / 'Viewer/local-art/human-npcs/savages/preparation.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes((json.dumps(result, indent=2) + '\n').encode())
    riders = [dict(body=body, female=body == 186, skin='savage', name='Savage Rider / '+gender,
                   status='prepared', native_classes=['SavageRider'],
                   required_mount=dict(body=188, item=0x3EB8),
                   scope='Modern human profile and native source contract; runtime/riding/native evidence tracked separately.')
              for body, gender in [(185, 'male'), (186, 'female')]]
    rider_result = dict(profiles=riders, input_manifest_sha256=sha(manifest), recipe_sha256=sha(Path(__file__)),
                        source_foot_profiles_sha256=sha(output), server_pin=pins['server_pin'],
                        scope='Prepared male/female Savage Rider profiles. Real Ridgeback artwork is required; no horse fallback, accepted route or native-behaviour certificate.')
    (output.parent/'riders.json').write_text(json.dumps(rider_result, indent=2)+'\n', encoding='utf-8')
    print('SAVAGE PREPARED: two foot and two rider profiles; accepted routes unchanged')


if __name__ == '__main__':
    main()
