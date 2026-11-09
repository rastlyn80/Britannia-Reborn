"""Prepare Efreet's own rig using pinned Classic fallback and newer sequence evidence."""

import hashlib
from pathlib import Path
import runpy

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'efreet_actions'
BODY = 131
CLASSES = {BODY: ['Efreet']}
CLASSIC = {
    0: 'Walk', 1: 'Idle', 2: 'Death', 3: 'Death2', 4: 'Attack', 5: 'EfreetPalmSweep',
    6: 'EfreetReverseStrike', 7: 'EfreetOverhead', 8: 'EfreetHeldReach', 10: 'Hit',
    11: 'EfreetGuardBend', 12: 'Cast', 15: 'EfreetSideRecoil', 16: 'EfreetChestBrace',
    17: 'Fidget', 18: 'EfreetOpenArms',
}
FITTED = (3, 5, 6, 7, 8, 11, 12, 15, 16, 18)
MODERN = {0: 'Attack', 2: 'EfreetSideRecoil', 3: 'Death', 4: 'Hit', 11: 'Cast', 14: 'EfreetGuardBend'}
TREATMENTS = ('original', 'rounded', 'modern')
helpers = runpy.run_path(str(SCRIPTS / 'prepare-field-fauna.py'))
read, sha = helpers['read'], helpers['sha']
ledger = runpy.run_path(str(SCRIPTS / 'build-creature-actions.py'))
sequence = runpy.run_path(str(SCRIPTS / 'uo-human-sequences.py'))


def source_groups():
    pins = read(SCRIPTS / 'efreet-frame-pins.json')
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    assert pins['definitions'] == {name: sha(data / name) for name in pins['definitions']}
    source = pins['classic']
    owners = {BODY, source['source_body']}
    rows, _, flags = ledger['original_mul_groups'](data, owners)
    assert pins['mobtypes'] == {str(body): list(value) for body, value in flags.items()}
    assert {row['body'] for row in rows} == {source['source_body']}
    frames, _ = ledger['original_frame_groups'](data, owners, type('SequenceReader', (), sequence))
    assert not frames, 'Unexpected direct canonical UOP frame evidence for the Efreet or its fallback'
    redirects, _ = ledger['original_definition_redirects'](data, {BODY}, rows, set())
    assert pins['redirects'] == {row['scope']: [row['graphic'], row['legacy_hue']] for row in redirects}
    assert set(source['groups']) == {str(row['group']) for row in rows} == {str(slot) for slot in CLASSIC}
    for row in rows:
        assert all(row[key] == source[key] for key in ('archive', 'graphic', 'layout'))
        directions = row['directions']
        assert [item['direction'] for item in directions] == list(range(5))
        hashes = ''.join(item['payload_sha256'] for item in directions).encode('ascii')
        assert source['groups'][str(row['group'])] == [
            [item['frames'] for item in directions], hashlib.sha256(hashes).hexdigest()]
    record, = sequence['inspect'](data / 'AnimationSequence.uop', {BODY})
    assert not record.get('parse_blocker') and record['unparsed_bytes'] == 0
    assert pins['sequence'] == dict(uop_name_hash=record['uop_name_hash'], new_protocol_modes={
        str(mode['mode']): mode['new_protocol_actions'] for mode in record['modes']})
    return pins


def prepared(entries):
    pins = source_groups()
    base, = (row for row in entries if row['status'] == 'validated'
             and [int(identity['body']) for identity in row['bodies']] == [BODY])
    assert base['kind'] == 'genies_efreet' and base['movement_mode'] == 'source_hover'
    bake = read(ART / 'efreet-actions-bake.json')
    assert 'bake-efreet-actions.gd' in bake['inputs']
    for name, digest in bake['inputs'].items():
        assert sha(SCRIPTS / name) == digest, name
    assets, retained, scenes = {}, {}, {}
    for treatment in TREATMENTS:
        original = base.get('assets', {}).get(treatment, f"res://local-art/creatures/{base['kind']}-{treatment}.gltf")
        asset = f'res://local-art/creatures/efreet-actions-{treatment}.scn'
        old, new = sha(VIEWER / original[6:]), sha(VIEWER / asset[6:])
        assert old == base['asset_sha256'][treatment]
        assert bake['scenes'][str(BODY)][treatment] == {'source': old, 'scene': new}
        assets[treatment], retained[treatment], scenes[treatment] = asset, original, new
    source = pins['classic']
    references = {str(slot): dict(body=BODY, source_body=source['source_body'], group=slot,
                                  archive=source['archive'], graphic=source['graphic'],
                                  frames=source['groups'][str(slot)][0][0], directions=list(range(5)),
                                  directional_payload_sha256=source['groups'][str(slot)][1])
                  for slot in CLASSIC if slot not in (0, 1)}
    renderer = 'Presentation/EfreetActionsVisual.gd'
    dependencies = ('EfreetActionsVisual', 'TerathanActionsVisual', 'SourceSpaceFallPlayback',
                    'CreatureFallPlayback', 'SourceGroundLookup')
    return [dict(base, status='prepared', family=FAMILY, assets=assets, grounded_gestures=[],
                 classic_gesture_base_assets=retained, authored_action_scene_sha256=scenes,
                 authored_action_reference=references['12'], classic_motion_references=references,
                 classic_action_categories={str(slot): clip for slot, clip in CLASSIC.items()},
                 new_action_categories={str(kind): clip for kind, clip in MODERN.items()},
                 native_extra_classic_actions=[2, 3, 10, 15, 16, 18], native_constructor_hues={'Efreet': 0},
                 authored_replacements=base.get('authored_replacements', {}) | {
                     CLASSIC[slot]: f'Fitted on the Efreet rig from Classic fallback group {slot}' for slot in FITTED},
                 classic_definition_redirects=pins['redirects'], efreet_sequence_evidence=pins['sequence'],
                 presentation_script=f'res://{renderer}', presentation_script_sha256=sha(VIEWER / renderer),
                 collapse_renderer_dependencies={name: sha(VIEWER / f'Presentation/{name}.gd')
                                                 for name in dependencies})], CLASSES
