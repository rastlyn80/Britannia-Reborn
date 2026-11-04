"""Bake a local Corpser emergence from the accepted Third Dawn rig."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import runpy
import subprocess

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
FOLDER = 'local-art/creatures'
INDEX = VIEWER / FOLDER / 'accepted-index.json'
SOURCE = VIEWER / FOLDER / 'flails_corpser-modern.gltf'
ASSET = VIEWER / FOLDER / 'corpser-emergence.scn'
CANDIDATE = ROOT / 'work/creatures/corpser-emergence/candidate.json'
SOURCE_SHA = '45840e2904c57080f11bf3aa3136a135b9f3777404e8509a9de55eb85bc1ab44'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(godot, env, script, marker, active=False):
    cmd = [str(godot), '--headless', '--path', str(VIEWER), '--script', f'res://Presentation/{script}']
    if active:
        cmd.extend(['--', '--active'])
    result = subprocess.run(cmd, env=env, capture_output=True, text=True, encoding='utf-8',
                            errors='replace', check=True, timeout=45)
    print(result.stdout.strip())
    if marker not in result.stdout or 'ERROR:' in result.stderr:
        raise RuntimeError(result.stdout + result.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--activate', action='store_true')
    args = parser.parse_args()
    if sha(SOURCE) != SOURCE_SHA:
        raise ValueError('The verified Corpser rig input changed')
    previous = INDEX.read_bytes()
    index = json.loads(previous.decode('utf-8-sig'))
    row, = [row for row in index['entries'] if row['kind'] == 'flails_corpser' and row['status'] == 'validated']
    identity, = row['bodies']
    if int(identity['body']) != 8 or identity['native_profile'] != 'monster':
        raise ValueError('The active Corpser identity changed')
    godot = next((ROOT / '.tools/godot').glob('*console.exe'))
    user_dir = str(ROOT / '.godot-user')
    env = dict(os.environ, APPDATA=user_dir, LOCALAPPDATA=user_dir)
    if row.get('classic_gesture_batch') == 'zombie_corpser_gargoyle_actions':
        checked = runpy.run_path(str(ROOT / 'scripts/accept-classic-gestures.py'))['checked']
        checked(index, True, row['classic_gesture_batch'])
        run(godot, env, 'CorpserEmergenceTests.gd', 'CORPSER EMERGENCE:', active=True)
        return
    baker_sha = sha(VIEWER / 'Presentation/BakeCorpserEmergence.gd')
    if row.get('assets', {}).get('modern') == f'res://{FOLDER}/{ASSET.name}':
        if (row.get('corpser_emergence', {}).get('baker_sha256') != baker_sha
                or row['asset_sha256']['modern'] != sha(ASSET)):
            raise ValueError('Active Corpser emergence recipe or scene changed')
    else:
        run(godot, env, 'BakeCorpserEmergence.gd', 'CORPSER BAKE:')
    variants = ('original', 'rounded', 'modern')
    row.setdefault('assets', {name: f'res://{FOLDER}/flails_corpser-{name}.gltf' for name in variants})
    row['assets']['modern'] = f'res://{FOLDER}/{ASSET.name}'
    row['asset_sha256']['modern'] = sha(ASSET)
    row['classic_action_categories'] = row.get('classic_action_categories', {}) | {'12': 'Emerge'}
    row['authored_replacements'] = row.get('authored_replacements', {}) | {
        'Emerge': 'Authored vertical entry on the original Idle rig after visual inspection of body 8 classic slot 12.'
    }
    row['corpser_emergence'] = {
        'source_scene_sha256': SOURCE_SHA,
        'baker_sha256': baker_sha,
        'archive_reference': 'anim.mul body 8 group 12 direction 1, 15 frames',
        'reference_payload_sha256': '8f02014f078dee7c7dfbe274860f9959a83f18e9581b0a25abf8df72f320273f',
    }
    CANDIDATE.parent.mkdir(parents=True, exist_ok=True)
    CANDIDATE.write_text(json.dumps(row, indent=2) + '\n', encoding='utf-8')
    run(godot, env, 'CorpserEmergenceTests.gd', 'CORPSER EMERGENCE:')
    if args.activate:
        if INDEX.read_bytes() != previous:
            raise RuntimeError('Registry changed during Corpser trial')
        pending = INDEX.with_suffix('.corpser.pending')
        updated = (json.dumps(index, indent=2) + '\n').encode('utf-8')
        pending.write_bytes(updated)
        pending.replace(INDEX)
        try:
            run(godot, env, 'CorpserEmergenceTests.gd', 'CORPSER EMERGENCE:', active=True)
        except (RuntimeError, subprocess.SubprocessError, OSError):
            if INDEX.read_bytes() == updated:
                pending.write_bytes(previous)
                pending.replace(INDEX)
            raise


if __name__ == '__main__':
    main()
