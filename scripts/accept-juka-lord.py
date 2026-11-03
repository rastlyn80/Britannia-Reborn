"""Activate the private Juka Lord package verified with native equipment."""
import json
import os
from pathlib import Path
import runpy
import subprocess

FIXTURES = runpy.run_path(str(Path(__file__).with_name('prepare-creature-fixtures.py')))
ROOT, SHA = FIXTURES['ROOT'], FIXTURES['sha']
ART = ROOT / 'Viewer/local-art/creatures'
INDEX = ART / 'accepted-index.json'


def replace_index(payload):
    pending = INDEX.with_suffix('.juka-lord.pending')
    pending.write_bytes(payload)
    pending.replace(INDEX)


def main():
    (row,), classes = FIXTURES['prepared_entries']('juka_lord')
    preparation = ART / 'juka_lord/preparation.json'
    report = json.loads((ROOT / 'outputs/creatures/juka_lord/live.json').read_text(encoding='utf-8'))
    records = report['records']
    if (classes != {766: ['JukaLord']} or report['failures'] or not report['ai_timer_stop_verified']
            or report['preparation_sha256'] != SHA(preparation)
            or report['runtime_sha256']['Presentation/SourceJukaLordVisual.gd'] != row['presentation_script_sha256']
            or len(records) != 2 or {record['female'] for record in records} != {False, True}):
        raise ValueError('Juka Lord native evidence does not match the package')
    for record in records:
        if (record['body'] != 766 or record['native_class'] != 'JukaLord'
                or not any(item['id'] in (0x13b1, 0x13b2) for item in record['native_equipment'])
                or not any(action['requested'] == 7 and action['owner_clip'] == action['observer_clip'] == 'AttackBow'
                           for action in record['actions'])):
            raise ValueError('Juka Lord native evidence lacks bow equipment or action')
    previous = INDEX.read_bytes()
    index = json.loads(previous.decode('utf-8-sig'))
    if any(body['body'] == 766 for entry in index['entries'] for body in entry['bodies']):
        raise ValueError('Juka Lord already has a registry route')
    index['entries'].append(dict(row, status='validated'))
    published = (json.dumps(index, indent=2) + '\n').encode('utf-8')
    if INDEX.read_bytes() != previous:
        raise RuntimeError('Registry changed before activation')
    replace_index(published)
    try:
        godot = next((ROOT / '.tools/godot').glob('*console.exe'))
        user_dir = str(ROOT / '.godot-user')
        result = subprocess.run(
            [str(godot), '--resolution', '128x128', '--path', str(ROOT / 'Viewer'), '--script',
             'res://Presentation/JukaLordRouteTests.gd'],
            cwd=ROOT, env=dict(os.environ, APPDATA=user_dir, LOCALAPPDATA=user_dir),
            capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=45)
        output = result.stdout + result.stderr
        print(output.strip())
        if result.returncode or 'ERROR:' in output or 'JUKA LORD PACKETS:' not in output:
            raise RuntimeError('Normal Juka Lord bow route failed')
        if INDEX.read_bytes() != published:
            raise RuntimeError('Registry changed during activation')
    except BaseException:
        if INDEX.read_bytes() == published:
            replace_index(previous)
        raise
    print('Activated Juka Lord 766 in the local registry')


if __name__ == '__main__':
    main()
