"""Prepare reproducible isolated native trials for the Classic gesture bridge."""

import argparse
import json
from pathlib import Path
import shutil


ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'work/creatures/classic-gesture-bridge/native'
ROUTES = ROOT / 'Viewer/Presentation/creature-classic-gesture-bridge.json'
PINS = ROOT / 'scripts/classic-gesture-bridge-pins.json'
FAMILY_PREFIX = 'classic_gesture_bridge_'
VENDOR = '758'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def edit(source, replacements):
    for before, after in replacements.items():
        assert before in source, before
        source = source.replace(before, after)
    return source


def prepare_fixture(classes, types):
    source = ROOT / 'Server/HorseIntegrationFixtures'
    fixture = WORK / 'fixture'
    fixture.mkdir(parents=True, exist_ok=True)
    for path in source.iterdir():
        if path.name == 'ClassicWireFixtures.cs':
            content = path.read_text(encoding='utf-8')
            first = content.index('    [\n', content.index('private static readonly HashSet<int> Bodies'))
            last = content.index('    ];', first)
            bodies = list(classes)
            lines = ['        ' + ', '.join(bodies[index:index + 15]) + ',' for index in range(0, len(bodies), 15)]
            content = content[:first] + '    [\n' + '\n'.join(lines) + '\n' + content[last:]
            content = edit(content, {'type is not (1 or 2 or 11 or 14)': f"type is not ({' or '.join(types)})"})
            (fixture / path.name).write_text(content, encoding='utf-8')
        elif path.suffix == '.cs' or path.name == 'global.json':
            shutil.copyfile(path, fixture / path.name)
        elif path.suffix == '.csproj':
            text = edit(path.read_text(encoding='utf-8'), {'../runtime/': (ROOT / 'Server/runtime').as_posix() + '/'})
            (fixture / path.name).write_text(text, encoding='utf-8')
    return fixture.relative_to(ROOT).as_posix()


def prepare_client(relative):
    source = (ROOT / 'Viewer/Network/ClassicWireAliasesLive.gd').read_text(encoding='utf-8')
    source = edit(source, {
        'const FAMILY := "classic_wire_aliases"\n': '',
        'const ROUTES := "res://Presentation/creature-wire-routes.json"':
            f'const SHARDS := "res://../{relative}/"\nvar routes_path := ""',
        '\tfamily = FAMILY\n\tassert("--family=" + FAMILY in OS.get_cmdline_user_args())':
            f'\tfor arg: String in OS.get_cmdline_user_args():\n'
            f'\t\tif arg.begins_with("--family={FAMILY_PREFIX}"):\n'
            '\t\t\tfamily = arg.trim_prefix("--family=")\n'
            f'\tassert(family.begins_with("{FAMILY_PREFIX}") and family.is_valid_identifier())\n'
            '\troutes_path = SHARDS + family + "/routes.json"',
        'ROUTES)': 'routes_path)',
        '+ FAMILY': '+ family',
    })
    (WORK / 'ClassicGestureBridgeLive.gd').write_text(source, encoding='utf-8')


def prepare_runner(relative, fixture):
    runner = (ROOT / 'scripts/test-horses.ps1').read_text(encoding='utf-8')
    runner = edit(runner, {
        '$root=Split-Path $PSScriptRoot -Parent': '$root=(Resolve-Path -LiteralPath "$PSScriptRoot/../../../..").Path',
        '"$PSScriptRoot/prepare-horses.ps1"': '"$root/scripts/prepare-horses.ps1"',
        '$root/Server/HorseIntegrationFixtures': '$root/' + fixture,
        "'Server/HorseIntegrationFixtures/'": "'" + fixture + "/'",
        '$preparedCreatureTrial=$PreparedQueen -or ': f'$preparedCreatureTrial=$PreparedQueen -or $CreatureFamily -like \'{FAMILY_PREFIX}*\' -or ',
        "$CreatureFamily -eq 'classic_wire_aliases'": f"$CreatureFamily -like '{FAMILY_PREFIX}*'",
        "'res://Network/ClassicWireAliasesLive.gd'": f"'res://../{relative}/ClassicGestureBridgeLive.gd'",
        '"$root/scripts/prepare-creature-fixtures.py"': '"$PSScriptRoot/prepare-bridge-fixtures.py"',
        '(Get-FileHash "$root/scripts/test-horses.ps1")': '(Get-FileHash -LiteralPath $PSCommandPath)',
    })
    (WORK / 'test-native-bridge.ps1').write_text(runner, encoding='utf-8')
    selector = """from pathlib import Path
import json
import runpy

folder = Path(__file__).resolve().parent
root = folder.parents[3]
selector = runpy.run_path(str(root / 'scripts/prepare-creature-fixtures.py'))


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def prepared_entries(family):
    assert family.startswith('__PREFIX__') and family.isidentifier()
    selected = read(folder / family / 'constructors.json')
    public = read(root / 'Viewer/Art/Creatures/index.json')['entries']
    local = read(root / 'Viewer/local-art/creatures/accepted-index.json')['entries']
    owners = {str(int(identity['body'])): (row, identity)
              for row in public + local if row['status'] == 'validated' for identity in row['bodies']}
    rows = []
    for body in selected:
        base, identity = owners[body]
        row = dict(base, bodies=[identity], family=family, status='prepared')
        row.pop('native_constructor_hues', None)
        row.pop('native_constructor_hue_ranges', None)
        rows.append(row)
    return rows, {int(body): [name] for body, name in selected.items()}


selector['main'].__globals__['prepared_entries'] = prepared_entries
selector['main']()
"""
    (WORK / 'prepare-bridge-fixtures.py').write_text(selector.replace('__PREFIX__', FAMILY_PREFIX), encoding='utf-8')


def prepare(routes, classes, types, batch_size):
    assert routes.keys() == classes.keys()
    bodies = [body for body in classes if body != VENDOR]
    groups = {f'{FAMILY_PREFIX}{offset // batch_size + 1:02}': bodies[offset:offset + batch_size]
              for offset in range(0, len(bodies), batch_size)}
    # The native city morph moves both disposable accounts onto another map.
    if VENDOR in classes:
        groups[FAMILY_PREFIX + 'city'] = [VENDOR]
    for family, selected in groups.items():
        folder = WORK / family
        folder.mkdir(parents=True, exist_ok=True)
        write_json(folder / 'routes.json', {body: routes[body] for body in selected})
        write_json(folder / 'constructors.json', {body: classes[body] for body in selected})
    write_json(WORK / 'shards.json', groups)
    relative = WORK.relative_to(ROOT).as_posix()
    fixture = prepare_fixture(classes, types)
    prepare_client(relative)
    prepare_runner(relative, fixture)
    print(f'Prepared {len(groups)} isolated trial groups for {len(classes)} bodies under {WORK}')


def main():
    global WORK, FAMILY_PREFIX
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--routes', type=Path, default=ROUTES)
    parser.add_argument('--pins', type=Path)
    parser.add_argument('--reactions', action='store_true')
    args = parser.parse_args()
    types, pin_path, batch_size = ('5', '8'), PINS, 26
    if args.reactions:
        WORK = ROOT / 'work/creatures/classic-reaction-bridge/native-installed'
        FAMILY_PREFIX = 'classic_reaction_bridge_installed_'
        types = ('1', '2', '6', '9', '10', '11', '14')
        pin_path = ROOT / 'scripts/classic-reaction-bridge-pins.json'
        batch_size = 22
    routes = {body: selected for body, row in read(args.routes).items()
              if (selected := {kind: rule for kind, rule in row.items() if kind in types})}
    prepare(routes, read(args.pins or pin_path)['native_classes'], types, batch_size)


if __name__ == '__main__':
    main()
