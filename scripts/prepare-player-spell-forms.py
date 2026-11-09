"""Prepare and verify source-backed player transformations with existing creature rigs."""

import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import runpy


ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'work/creatures/native-form-audit'
VIEWER = ROOT / 'Viewer'
INDEX = VIEWER / 'local-art/creatures/accepted-index.json'
RECEIPT = WORK / 'accepted-spell-forms.json'
DONORS = {
    746: (785, 'spell_form_horrific_beast', 'Horrific Beast', 'HorrificBeast', 'exact archive frames'),
    747: (310, 'spell_form_wraith_female', 'Wraith Form / female', 'WraithForm', 'exact archive frames'),
    748: (26, 'spell_form_wraith_male', 'Wraith Form / male', 'WraithForm', 'Classic redirect and Third Dawn spectral rig'),
    749: (24, 'spell_form_lich', 'Lich Form', 'LichForm', 'Classic body redirect'),
}
DONOR_ONLY = {
    'classic_gesture_batch', 'classic_gesture_base_assets', 'classic_gesture_native_sha256',
    'legacy_slot11_evidence', 'native_constructor_hues', 'native_extra_classic_actions',
    'action_validation_sha256', 'presentation_validation_sha256', 'validation_scope',
}


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix('.json.pending')
    temporary.write_text(json.dumps(data, indent=2), encoding='utf-8')
    temporary.replace(path)


def signature(rows, body):
    return sorted((r['archive'], r['graphic'], r['group'],
                   tuple((d['direction'], d['frames'], d['payload_sha256']) for d in r['directions']))
                  for r in rows if r['body'] == body)


def source_rows(base, data):
    ledger = runpy.run_path(str(ROOT / 'scripts/build-creature-actions.py'))
    allowed = set(DONORS) | {value[0] for value in DONORS.values()}
    mul, _, _ = ledger['original_mul_groups'](data, allowed)
    uop, _ = ledger['original_frame_groups'](
        data, {748, 749}, type('Reader', (), {'payloads': staticmethod(
            runpy.run_path(str(ROOT / 'scripts/uo-human-sequences.py'))['payloads'])}))
    by_body = {int(identity['body']): (row, identity) for row in base for identity in row['bodies']}
    rows = []
    for body, (donor, kind, name, spell, proof) in DONORS.items():
        assert body not in by_body, f'Existing route for body {body}'
        source, identity = by_body[donor]
        assert source['status'] == 'validated'
        for treatment, path in source['assets'].items():
            assert sha(VIEWER / path.removeprefix('res://')) == source['asset_sha256'][treatment]
        expected = signature(mul, body)
        if proof == 'exact archive frames':
            assert len(expected) == 13 and all(len(slot[3]) == 5 for slot in expected)
            assert expected == signature(mul, donor)
        else:
            pattern = rf'^\s*{body}\s+\{{{donor}\}}\s+0\s*$'
            assert re.search(pattern, (data / 'Body.def').read_text(encoding='utf-8-sig'), re.M)
            assert not any(row['body'] == body for row in uop)
            if body == 748:
                assert len(expected) == 13 and all(len(slot[3]) == 5 for slot in expected)
                assert source['kind'] == 'spirits_ghost'
            else:
                assert not expected
        filepath = f'Projects/UOContent/Spells/Necromancy/{spell}.cs'
        spell_path = ROOT / 'Server/ModernUO' / filepath
        spell_text = spell_path.read_text(encoding='utf-8-sig')
        expression, = re.findall(r'public override int Body => ([^;]+);', spell_text)
        assert str(body) in re.findall(r'\b\d+\b', expression)
        row = {key: copy.deepcopy(value) for key, value in source.items() if key not in DONOR_ONLY}
        row.update(kind=kind, bodies=[dict(identity, body=body, name=name, native_sources=[{
            'path': filepath, 'sha256': sha(spell_path)}])], spell_form_source={
                'donor': donor, 'proof': proof, 'original_group_count': len(expected)})
        rows.append(row)
    return rows


def gameplay_receipt(prepared):
    live = read(WORK / 'creature-forms.json')
    vampiric = read(WORK / 'candidate.json')
    assert live['index_sha256'] == sha(prepared)
    assert live['test_sha256'] == sha(WORK / 'NativeCreatureFormsLive.gd')
    assert live['checks'] == 101 and [record['body'] for record in live['records']] == list(DONORS)
    for record in live['records']:
        body = record['body']
        assert record['kind'] == DONORS[body][1] and record['spell'] == DONORS[body][3] + 'Spell'
        assert record['movement'][0] != record['movement'][1]
        assert record['corpse'] > 0
    assert vampiric['checks'] == 54 and vampiric['candidate'] is True
    assert [int(record['native'][2]) for record in vampiric['records']] == [744, 745]
    assert vampiric['records'][1]['corpse'][-2:] == ['745', '33918']
    for key, path in [('profiles_sha256', 'HumanNPCProfiles.gd'), ('human_visual_sha256', 'HumanVisual.gd'),
                      ('skin_sha256', 'FreeHumanSkin.gdshader')]:
        assert vampiric[key] == sha(VIEWER / 'Presentation' / path)
    result = {}
    for prefix in ('candidate', 'creature-forms'):
        proof = read(WORK / (prefix + '-runtime.json'))
        assert proof['server_sha256'].lower() == sha(ROOT / 'Server/runtime/Server.dll')
        assert proof['content_sha256'].lower() == sha(ROOT / 'Server/runtime/Assemblies/UOContent.dll')
        assert proof['report_sha256'].lower() == sha(WORK / (prefix + '.json'))
        result[prefix] = proof['report_sha256'].lower()
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--activate', action='store_true')
    mode.add_argument('--check-active', action='store_true')
    parser.add_argument('--data', type=Path)
    args = parser.parse_args()
    data = args.data
    if data is None:
        data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    index = read(INDEX)
    base = [row for row in index['entries'] if not row.get('spell_form_source')]
    active = [row for row in index['entries'] if row.get('spell_form_source')]
    rows = source_rows(base, data)
    if args.check_active:
        assert active == rows
        receipt = read(RECEIPT)
        assert gameplay_receipt(WORK / 'prepared-index.json') == receipt['native_reports']
        print('PLAYER SPELL FORMS: four checked rig routes and both vampiric profiles')
        return
    assert not active, 'Use --check-active for an already installed spell batch'
    prepared = WORK / 'prepared-index.json'
    write(prepared, dict(index, entries=base + rows))
    if args.activate:
        native = gameplay_receipt(prepared)
        backup = WORK / 'accepted-index-before-spell-forms.json'
        if not backup.exists():
            backup.write_bytes(INDEX.read_bytes())
        write(RECEIPT, {'native_reports': native, 'spell_bodies': list(DONORS)})
        write(INDEX, dict(index, entries=base + rows))
    print('PLAYER SPELL FORMS:', 'installed' if args.activate else 'prepared', list(DONORS))


if __name__ == '__main__':
    main()
