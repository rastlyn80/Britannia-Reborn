"""Prepare a disposable two-client riding trial for Ridgebacks and Reptalon."""

from pathlib import Path
import hashlib
import json
import runpy
import shutil

root = Path(__file__).resolve().parents[1]
folder = root / 'work/creatures/ridgeback_through_dragons_actions/mounted'
relative = folder.relative_to(root).as_posix()
fixture = folder / 'mounted-fixture'
fixture_path = fixture.relative_to(root).as_posix()
common = runpy.run_path(str(root / 'scripts/prepare-post-solen-actions.py'))
read, sha = common['read'], common['sha']
IDENTITIES = {187: (0x3EBA, 'Ridgeback'), 188: (0x3EB8, 'SavageRidgeback'), 276: (0x3E90, 'Reptalon')}
REPORT = 'ridgeback-reptalon-mounted-preview-live.json'


def edit(source, replacements):
    for before, after in replacements.items():
        assert before in source, before
        source = source.replace(before, after)
    return source


def fixture_source():
    path = root / 'Server/HorseIntegrationFixtures/EquineFixtures.cs'
    return edit(path.read_text(encoding='utf-8'), {
        '        58 => new SavageRidgeback(),': '        58 => new SavageRidgeback(),\n        60 => new Reptalon(),',
        'index < 0 || index > 59': 'index < 0 || index > 60',
        'riderSubject is SwampDragon or ScaledSwampDragon or Ridgeback or SavageRidgeback)':
            'riderSubject is SwampDragon or ScaledSwampDragon or Ridgeback or SavageRidgeback or Reptalon)',
        '        else if (command == "hiryu-flight"':
            '        else if (command == "reptalon-flight" && Animals.TryGetValue(owner, out var reptalon) && reptalon is Reptalon)\n'
            '        {\n'
            '            owner.SendMessage($"UCEQUINE|reptalon-flight|{(reptalon.CanFly ? 1 : 0)}|{(reptalon.Flying ? 1 : 0)}");\n'
            '        }\n'
            '        else if (command == "hiryu-flight"',
    })


def parent_source():
    return edit((root / 'Viewer/Network/OstardLive.gd').read_text(encoding='utf-8'), {
        '[55,56,57,58,59] if source_mounts': '[57,58,60] if source_mounts',
        '[794,0x3ebd,"SwampDragon"]][variant - 55]': '[794,0x3ebd,"SwampDragon"],[276,0x3e90,"Reptalon"]][variant - 55]',
        '                if not check([body,item,fields[5]] == identity'.replace('                ','\t\t\t\t'):
            '\t\t\t\tif variant == 60:\n'
            '\t\t\t\t\tvar capability := await fixture_reply(session,sex,"reptalon-flight","UCEQUINE|reptalon-flight|")\n'
            '\t\t\t\t\tif not check(capability == "UCEQUINE|reptalon-flight|1|0","Native Reptalon can fly and starts grounded"):return\n'
            '\t\t\t\tif not check([body,item,fields[5]] == identity',
        '\t\t\t\tif source_mounts:action_clips.clear()': '\t\t\t\tif source_mounts:action_clips = {11:"LieDown"}',
        'source-mounts-live.json': 'ridgeback-reptalon-mounted-preview-live.json',
        'Swamp Dragons and Ridgebacks on the isolated native server. Normal mounting, rider action packets, hues, walk/run, dismount and corpses. The real barding deed is used with the client target cursor; its placement in the disposable backpack is fixture setup.':
            'Ridgeback, Savage Ridgeback and Reptalon. Actual mounting and dismount, mounted rider actions, dyes, movement, native rest and corpse on both clients. Reptalon flight capability, grounded state only.',
    })


def wrapper_source():
    return f'''extends "res://../{relative}/MountedPreviewParent.gd"

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const CANDIDATE := "res://../{relative}/mounted-preview.json"
const REPORT := "res://../outputs/ostard-riding/{REPORT}"

func run() -> void:
	assert("--source-mounts" in OS.get_cmdline_user_args())
	var accepted := "res://local-art/creatures/accepted-index.json"
	var pin := FileAccess.get_sha256(accepted)
	var candidate_sha := FileAccess.get_sha256(CANDIDATE)
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(CANDIDATE))
	Registry.load_index()
	for row: Dictionary in rows:
		for treatment: String in row.assets:
			assert(FileAccess.get_sha256(row.assets[treatment]) == row.authored_action_scene_sha256[treatment])
		Registry.entries[int(row.bodies[0].body)] = row
	await super.run()
	assert(FileAccess.get_sha256(accepted) == pin and FileAccess.get_sha256(CANDIDATE) == candidate_sha)
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT))
	report.candidate_sha256 = candidate_sha
	report.parent_sha256 = FileAccess.get_sha256("res://../{relative}/MountedPreviewParent.gd")
	report.wrapper_sha256 = FileAccess.get_sha256(get_script().resource_path)
	report.fixture_sha256 = FileAccess.get_sha256("res://../{fixture_path}/EquineFixtures.cs")
	var output := FileAccess.open(REPORT, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
'''

def runner_source():
    return edit((root / 'scripts/test-horses.ps1').read_text(encoding='utf-8'), {
        '$root=Split-Path $PSScriptRoot -Parent': '$root=(Resolve-Path -LiteralPath "$PSScriptRoot/../../../..").Path',
        '"$PSScriptRoot/prepare-horses.ps1"': '"$root/scripts/prepare-horses.ps1"',
        '$root/Server/HorseIntegrationFixtures': '$root/' + fixture_path,
        "'Server/HorseIntegrationFixtures/'": "'" + fixture_path + "/'",
        "elseif ($Ostards -or $EquineCompletion": f"elseif ($SourceMounts) {{'res://../{relative}/MountedPreviewLive.gd'}} elseif ($Ostards -or $EquineCompletion",
        "if ($SourceMounts) {'source-mounts-live.json'}": "if ($SourceMounts) {'ridgeback-reptalon-mounted-preview-live.json'}",
    })


def candidate_rows(entries):
    rows = []
    for row in entries:
        body = int(row['bodies'][0]['body'])
        if body not in IDENTITIES:
            continue
        mount_item, _ = IDENTITIES[body]
        assert row['mount_item'] == mount_item and row['status'] == 'prepared'
        assert row['authored_action_scene_sha256'] == {
            name: sha(root / 'Viewer' / path[6:]) for name, path in row['assets'].items()}
        rows.append(row)
    assert len(rows) == len(IDENTITIES)
    assert {int(row['bodies'][0]['body']) for row in rows} == IDENTITIES.keys()
    return rows


def prepare():
    fixture.mkdir(parents=True, exist_ok=True)
    for path in (root / 'Server/HorseIntegrationFixtures').iterdir():
        if path.name == 'EquineFixtures.cs':
            (fixture / path.name).write_text(fixture_source(), encoding='utf-8', newline='\n')
        elif path.suffix == '.cs' or path.name == 'global.json':
            shutil.copyfile(path, fixture / path.name)
        elif path.suffix == '.csproj':
            source = path.read_text(encoding='utf-8')
            assert '../runtime/' in source
            (fixture / path.name).write_text(source.replace('../runtime/', (root / 'Server/runtime').as_posix() + '/'), encoding='utf-8')
    rows = candidate_rows(read(folder.parent / 'prepared-client.json'))
    (folder / 'mounted-preview.json').write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')
    (folder / 'MountedPreviewParent.gd').write_text(parent_source(), encoding='utf-8', newline='\n')
    (folder / 'MountedPreviewLive.gd').write_text(wrapper_source(), encoding='utf-8', newline='\n')
    (folder / 'test-mounted-preview.ps1').write_text(runner_source(), encoding='utf-8')


def check_report(entries, candidate, report_path):
    report = read(report_path)
    assert read(candidate) == candidate_rows(entries)
    assert not report['failures'] and report['checks'] >= 370 and report['candidate_sha256'] == sha(candidate)
    sources = {'fixture_sha256': fixture_source(), 'parent_sha256': parent_source(),
               'wrapper_sha256': wrapper_source()}
    assert all(report[key] == hashlib.sha256(source.encode('utf-8')).hexdigest()
               for key, source in sources.items())
    assert len(report['records']) == 2 * len(IDENTITIES)
    assert {(row['body'], row['mount_item'], row['native_class'], row['female'], row['ride_permitted'])
            for row in report['records']} == {
        (body, item, name, female, True) for body, (item, name) in IDENTITIES.items()
        for female in (False, True)}


if __name__ == '__main__':
    prepare()
