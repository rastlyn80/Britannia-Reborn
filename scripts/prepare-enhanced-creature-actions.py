# SPDX-License-Identifier: GPL-3.0-or-later
"""Build the optional Enhanced animation profile from checked local art."""

import argparse
import hashlib
from pathlib import Path
import json
import runpy
import shutil


HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
WORK = ROOT / 'work/creatures/native-form-audit'
GAPS = WORK / 'enhanced-source-gaps'
PINS = HERE / 'enhanced-creature-action-pins.json'
ACTIVE = ART / 'enhanced-creature-actions.json'
CANDIDATES = {
    267: ('troglodyte-fidgets', ['TroglodyteSettleFidget', 'TroglodyteRaisedFidget']),
    753: ('gargoyle-quiet-fidget', ['UopGargoyleQuietFidget']),
}
DISPATCHER = VIEWER / 'Presentation/EnhancedCreatureActions.gd'
TREATMENTS = {'original', 'rounded', 'modern'}


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def source_modes(pins):
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    reader = runpy.run_path(str(ROOT / 'scripts/uo-human-sequences.py'))
    name_hash = runpy.run_path(str(ROOT / 'scripts/audit-classic-parity.py'))['name_hash']
    targets = {}
    for body, pin in pins.items():
        for group, frame in pin['groups'].items():
            key = name_hash(f'build/animationlegacyframe/{int(body):06d}/{int(group):02d}.bin')
            targets.setdefault(pin['archive'], {})[key] = frame['sha256']
    for archive, expected in targets.items():
        actual = {key: hashlib.sha256(raw).hexdigest() for key, raw in reader['payloads'](data / archive, expected)}
        assert actual == expected
    tables = {}
    for sequence in reader['inspect'](data / 'AnimationSequence.uop', {int(body) for body in pins}):
        body = str(sequence['animation_ref'])
        groups = pins[body]['groups']
        allowed = {5, 8} if body == '267' else {5}
        assert not sequence.get('unparsed_bytes')
        resolved_groups = set()
        modes = {}
        for mode in sequence['modes']:
            if mode['mode'] == 3:
                assert body == '831' and mode['fallback_mode'] == 0
                assert not any(action['type'] in allowed for action in mode['new_protocol_actions'])
                continue
            assert mode['fallback_mode'] == (0 if mode['mode'] == 1 else -1)
            actions = {}
            for action in mode['new_protocol_actions']:
                if action['type'] in allowed:
                    assert action['subaction'] == -1 and str(action['type']) not in actions
                    ordered = [str(group) for group in action['groups']]
                    actions[str(action['type'])] = [groups[group]['clip'] for group in ordered]
                    resolved_groups.update(ordered)
            modes[str(mode['mode'])] = actions
        assert resolved_groups == groups.keys() and modes.keys() == {'0', '1'}
        tables[body] = modes
    assert tables.keys() == pins.keys()
    return tables


def verify_native_proof(assets, tables):
    path = WORK / 'enhanced-actions-native.json'
    native = read(path)
    receipt = read(WORK / 'enhanced-actions-native-runtime.json')
    assert sha(path) == receipt['report_sha256'].lower()
    assert sha(ROOT / 'Server/runtime/Server.dll') == receipt['server_sha256'].lower()
    assert sha(ROOT / 'Server/runtime/Assemblies/UOContent.dll') == receipt['content_sha256'].lower()
    assert native['checks'] == 91 and len(native['records']) == 2
    assert native['asset_sha256'] == assets['267']['assets']
    assert native['dispatcher_sha256'] == sha(DISPATCHER)
    assert native['test_sha256'] == sha(WORK / 'NativeEnhancedActionLive.gd')
    assert {row['class']: row['hue'] for row in native['records']} == {'Troglodyte': 0, 'Lurg': 1109}
    for row in native['records']:
        assert {(v['combat'], v['type'], v['variation']) for v in row['variants']} == {
            (combat, kind, variation) for combat in (False, True) for kind in (5, 8) for variation in (0, 1)
        }
        for case in row['variants']:
            enhanced, classic = case['client_routes']
            assert enhanced['enhanced'] and not classic['enhanced'] and enhanced['packet'] == classic['packet']
            assert bool(enhanced['flags'] & 0x40) == bool(classic['flags'] & 0x40) == case['combat']
            assert enhanced['packet']['serial'] == row['serial'] and enhanced['packet']['body'] == 267
            kind, variant = str(case['type']), case['variation']
            mode = '0' if case['combat'] else '1'
            choices = tables['267'][mode].get(kind, tables['267']['0'][kind])
            assert enhanced['clip'] == choices[variant % len(choices)]
            assert classic['clip'] == ('Pillage' if kind == '8' else ['Fidget', 'TroglodyteSway'][variant])
    return sha(path)


def prepare():
    pins = read(PINS)
    tables = source_modes(pins['bodies'])
    checked = read(GAPS / 'fidget-candidate-routing.json')
    assert checked['mapped_variants'] == 14 and checked['loaded_clips'] == 42
    assert checked['gargoyle_ground_poses'] == 279 and checked['minimum_gap'] > .0019
    troglodyte = read(GAPS / 'troglodyte-fidgets-evidence.json')
    assert troglodyte['terrain_poses'] == 3069 and troglodyte['minimum_gap'] > .0019
    assert troglodyte['candidate_sha256'] == checked['bodies']['267']['assets']
    native = verify_native_proof(checked['bodies'], tables)
    rows = read(ART / 'accepted-index.json')['entries']
    active_rows = {str(int(ident['body'])): row for row in rows for ident in row['bodies'] if row['status'] == 'validated'}
    manifest = {'schema': 1, 'source': pins['enhanced_version'], 'native_proof_sha256': native, 'bodies': {}}
    copies = {}
    for body, modes in tables.items():
        base = active_rows[body]
        base_hashes = {name: sha(VIEWER / uri.removeprefix('res://')) for name, uri in base['assets'].items()}
        assert base_hashes == base['asset_sha256'] and base_hashes.keys() == TREATMENTS
        row = {'kind': base['kind'], 'base_sha256': base_hashes, 'groups': modes}
        if int(body) in CANDIDATES:
            candidate, grounded = CANDIDATES[int(body)]
            row['grounded'] = grounded
            row['assets'] = {}
            for treatment in sorted(TREATMENTS):
                scene = GAPS / f'{candidate}-{treatment}.scn'
                fingerprint = sha(scene)
                assert fingerprint == checked['bodies'][body]['assets'][treatment]
                path = f'local-art/creatures/enhanced-creature-actions/{body}-{treatment}.scn'
                row['assets'][treatment] = {'path': 'res://' + path, 'sha256': fingerprint}
                copies[VIEWER / path] = scene
        else:
            assert checked['bodies'][body]['assets'] == base_hashes
        manifest['bodies'][body] = row
    return manifest, copies


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument('--stage', action='store_true')
    modes.add_argument('--install', action='store_true')
    modes.add_argument('--check-installed', action='store_true')
    parser.add_argument('--ranked-source', type=Path, help='Local folder holding the pinned Enhanced sequence and AMOU files')
    args = parser.parse_args()
    manifest, copies = prepare()
    source = args.ranked_source
    if source is None and ACTIVE.is_file():
        recorded = read(ACTIVE).get('ranked_source')
        if recorded:
            source = Path(recorded)
    if source is not None:
        source = source.resolve(strict=True)
        ranked = runpy.run_path(str(HERE / 'prepare-ranked-enhanced-actions.py'))['prepare_ranked']
        rows, ranked_copies, proof = ranked(ROOT, source)
        manifest['bodies'].update(rows)
        copies.update(ranked_copies)
        manifest['ranked_source'] = str(source)
        manifest['ranked_native_proof_sha256'] = proof
    if args.stage:
        (GAPS / ACTIVE.name).write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    elif args.install:
        for target, source in copies.items():
            target.parent.mkdir(parents=True, exist_ok=True)
            temporary = target.with_suffix('.pending')
            shutil.copyfile(source, temporary)
            temporary.replace(target)
        temporary = ACTIVE.with_suffix('.pending')
        temporary.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
        temporary.replace(ACTIVE)
    else:
        assert read(ACTIVE) == manifest
        assert all(sha(target) == sha(source) for target, source in copies.items())
    print(f'ENHANCED CREATURE ACTIONS: {len(manifest["bodies"])} profile bodies, {len(copies)} fitted local scenes')


if __name__ == '__main__':
    main()
