"""Prepare the independently authored Classic Water Elemental recoils."""

import argparse
import hashlib
import json
from pathlib import Path
import runpy
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ROOT / 'Viewer/Art/Creatures'
LOCAL = ROOT / 'Viewer/local-art/creatures'
FAMILY = 'water_reactions'
SOURCE = 'afcbae91b71e0ae2a03473f2afcce861c590a9f075e54bcee36cc4590e21be63'
SLOTS = {
    10: ('Hit', 4, '2af91406447557de37aa2f8e9aa1a619065bb51427d0479accb7c7c81f70e453',
         'High recoil and sinking recovery based on Classic group 10'),
    15: ('WaterRightRecoil', 3, '6c8e4f1abe7356ea02ec675193930905edb8094bb200b602988bbfbfe7c027f8',
         'Short right-arm recoil based on Classic group 15'),
    16: ('WaterLeftRecoil', 3, '84b79511c4f29aae20a9d136736cc456719f0fb1b67a6d3f473163643c07b3ba',
         'Short left-arm recoil based on Classic group 16'),
}
WORK = ROOT / 'work/creatures' / FAMILY
LIVE = ROOT / 'outputs/creatures' / FAMILY / 'live.json'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def prepared():
    base, = (row for row in read(PUBLIC / 'index.json')['entries'] if row['kind'] == 'water_elemental')
    installed = base['assets'] == {'modern': 'res://Art/Creatures/Water/water-reactions.scn'}
    assert installed or base['assets'] == {'modern': 'res://Art/Creatures/Water/water-elemental.scn'}
    assert sha(PUBLIC / 'Water/water-elemental.scn') == SOURCE
    target = LOCAL / 'water-reactions.scn'
    if installed:
        bake = read(PUBLIC / 'Water/reactions-provenance.json')['build']
        public_asset = PUBLIC / 'Water/water-reactions.scn'
        assert sha(public_asset) == bake['scene']
        if not target.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(public_asset, target)
    else:
        bake = read(LOCAL / 'water-reactions.json')
    scene = sha(target)
    assert bake == {'recipe': sha(ROOT / 'scripts/bake-water-reactions.gd'),
                    'solver': sha(ROOT / 'Viewer/Presentation/WaterElementalFidgets.gd'),
                    'source': SOURCE, 'scene': scene}
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    evidence = {str(slot): reference(ledger, 16, slot, ('anim.mul', 16, frames, digest))
                for slot, (_, frames, digest, _) in SLOTS.items()}
    treatment = ('original', 'rounded', 'modern')
    row = dict(base, status='prepared', family=FAMILY,
               assets=dict.fromkeys(treatment, 'res://local-art/creatures/water-reactions.scn'),
               authored_action_scene_sha256=dict.fromkeys(treatment, scene),
               authored_action_reference=evidence['10'], classic_motion_references=evidence,
               native_extra_classic_actions=list(SLOTS))
    classes = {16: ['WaterElemental']}
    if installed:
        assert base['classic_motion_references'] == evidence
        assert all(base['classic_action_categories'][str(slot)] == data[0] for slot, data in SLOTS.items())
        assert all(base['new_action_categories'][kind] == 'LegacyHit' for kind in ('2', '4'))
        return [row], classes
    replacements = {'LegacyHit': base['authored_replacements']['Hit']}
    stats = base['stats']['modern']
    clips = dict(stats['clips'], LegacyHit=stats['clips']['Hit'])
    for label, frames, _, origin in SLOTS.values():
        replacements[label] = origin
        clips[label] = {'duration': 0.16 * frames, 'loop': False, 'origin': origin, 'support_policy': 'fluid_base'}
    row.update(
               classic_action_categories=base['classic_action_categories'] |
               {str(slot): label for slot, (label, _, _, _) in SLOTS.items()},
               new_action_categories=base['new_action_categories'] | {'2': 'LegacyHit', '4': 'LegacyHit'},
               authored_replacements=base['authored_replacements'] | replacements,
               stats={key: dict(value, clips=clips) for key, value in base['stats'].items()})
    return [row], classes


def native_receipt(row):
    report = read(LIVE)
    candidates = WORK / 'candidates.json'
    runtime = read(WORK / 'native-runtime.json')
    assert report['failures'] == 0 and report['prepared_trial']
    assert runtime['report_sha256'] == sha(LIVE) and runtime['candidate_sha256'] == report['candidate_sha256'] == sha(candidates)
    for key, path in {
            'test_sha256': 'Viewer/Network/CreatureLive.gd',
            'prepared_base_sha256': 'Viewer/Network/PreparedCreatureActionLive.gd',
            'prepared_wrapper_sha256': 'Viewer/Network/PreparedClassicActionsLive.gd',
            'fixture_sha256': 'Server/HorseIntegrationFixtures/CreatureFixtures.cs',
    }.items():
        assert report[key] == sha(ROOT / path)
    candidate, = read(candidates)
    assert candidate['presentation'] == row and candidate['body'] == 16 and candidate['native_class'] == 'WaterElemental'
    records = report['records']
    assert len(records) == 2 and {record['female'] for record in records} == {False, True}
    for record in records:
        assert record['body'] == 16 and record['native_class'] == 'WaterElemental'
        assert not record['native_death_refused'] and not record['corpse_suppressed']
        for slot, clip in [(slot, data[0]) for slot, data in SLOTS.items()] + [(-1, 'LegacyHit')]:
            action, = (action for action in record['actions'] if action['requested'] == slot)
            for client in ('owner', 'observer'):
                assert action[client + '_clip'] == clip
                packet = action[client + '_packet']
                if slot >= 0:
                    assert (packet['protocol'], packet['action']) == ('classic', slot)
                else:
                    assert (packet['protocol'], packet['type']) == ('new', 4)
    return sha(LIVE)


def check():
    row, = prepared()[0]
    digest = native_receipt(row)
    print('Water Elemental: tested Classic recoils, retained new-protocol hit and native corpse')
    return row, digest


def install():
    row, digest = check()
    gate = [sys.executable, '-B', str(ROOT / 'scripts/test-water-distribution.py')]
    subprocess.run([*gate, '--candidate-reactions'], check=True)
    index = PUBLIC / 'index.json'
    previous = index.read_bytes()
    data = read(index)
    old, = (entry for entry in data['entries'] if entry['kind'] == 'water_elemental')
    asset = PUBLIC / 'Water/water-reactions.scn'
    provenance = PUBLIC / 'Water/reactions-provenance.json'
    assert not asset.exists() and not provenance.exists()
    updated = dict(row, status='validated', family=old['family'], assets={'modern': 'res://Art/Creatures/Water/water-reactions.scn'})
    for field in ('native_extra_classic_actions', 'authored_action_scene_sha256', 'authored_action_reference'):
        del updated[field]
    data['entries'][data['entries'].index(old)] = updated
    newline = '\r\n' if b'\r\n' in previous else '\n'
    next_index = (json.dumps(data, indent=2) + '\n').replace('\n', newline).encode()
    pending = index.with_suffix('.water-reactions.pending')
    try:
        shutil.copyfile(LOCAL / 'water-reactions.scn', asset)
        assert sha(asset) == row['authored_action_scene_sha256']['modern']
        provenance.write_text(json.dumps({
            'license': 'GPL-3.0-or-later; underlying Quaternius assets CC0-1.0',
            'predecessor': 'provenance.json',
            'build': read(LOCAL / 'water-reactions.json'),
            'reference_groups': row['classic_motion_references'],
            'native_receipt_sha256': digest,
            'interpretation': 'Three authored poses on the public rig based on visual reference. The original mesh, rig, textures and animation frames are absent.',
        }, indent=2) + '\n', encoding='utf-8')
        assert index.read_bytes() == previous
        pending.write_bytes(next_index)
        pending.replace(index)
        subprocess.run(gate, check=True)
    except (Exception, KeyboardInterrupt):
        if index.read_bytes() == next_index:
            pending.write_bytes(previous)
            pending.replace(index)
        provenance.unlink(missing_ok=True)
        asset.unlink(missing_ok=True)
        raise
    print('Water Elemental: public recoil bundle installed and clean-distribution checked')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('check', 'install'))
    args = parser.parse_args()
    {'check': check, 'install': install}[args.mode]()
