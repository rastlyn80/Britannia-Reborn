"""Validate the retained Ratman, Brown Bear and feline scenes and frame references."""

import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
FAMILY = 'field_fauna'
CLASSES = {42: ['Ratman'], 167: ['BrownBear'], 214: ['Panther'], 63: ['Cougar']}
HUES = {42: 0, 167: 0, 214: 0x901, 63: 0}
VISUAL = 'Presentation/SourceQuadrupedCollapseVisual.gd'
RATMAN = {2: 'Death2', 3: 'Death', 4: 'Attack', 5: 'RatmanSwipe', 6: 'RatmanLunge',
          10: 'Hit', 11: 'Hunch', 15: 'RatmanFlinch', 16: 'RatmanBrace', 17: 'Fidget', 18: 'RatmanSniff'}
BEAR = {4: 'LookSide', 5: 'BearRearStrike', 6: 'Attack', 8: 'Death', 9: 'Fidget', 10: 'Fidget2', 12: 'Death2'}
FELINE = {5: 'Attack', 6: 'FelineRearSwipe', 8: 'Death2', 9: 'FelineStretch', 10: 'FelineSniff', 12: 'Death'}
ROUTES = {42: RATMAN, 167: BEAR, 214: FELINE, 63: FELINE}
EXTRAS = {42: [10, 15, 16, 18, 2, 3], 167: [4, 6, 8, 12], 214: [6, 10, 8, 12], 63: [6, 10, 8, 12]}
METHODS = {
    42: {'Death2': 'Fitted backward fall and tail curl', 'RatmanSwipe': 'Fitted right-hand sweep',
         'RatmanLunge': 'Fitted forward reach with the left hand', 'RatmanFlinch': 'Fitted narrow recoil',
         'RatmanBrace': 'Fitted counterguard and crouch', 'RatmanSniff': 'Fitted turn of the head and tail'},
    167: {'LookSide': 'Fitted alert head turn', 'BearRearStrike': 'Fitted upright swipe',
          'Attack': 'Recovered strike with fitted floor offset', 'Death': 'Fitted low fall',
          'Death2': 'Fitted side collapse', 'Fidget2': 'Fitted forepaw dip'},
    214: {'FelineRearSwipe': 'Fitted rear-up forepaw swipe', 'Death2': 'Fitted rear-up side roll',
          'FelineStretch': 'Fitted low foreleg stretch', 'FelineSniff': 'Fitted quick head lift'},
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def read_bake(name, scripts):
    bake = read(VIEWER / f'local-art/creatures/{name}-bake.json')
    inputs = [ROOT / 'scripts' / script for script in scripts]
    inputs.extend(VIEWER / 'Presentation' / script for script in ('WaterElementalFidgets.gd', 'SourceGroundLookup.gd'))
    assert bake['inputs'] == {path.name: sha(path) for path in inputs}
    return bake['scenes']


def prepared(entries):
    scenes_by_body = read_bake(FAMILY.replace('_', '-'),
                              ('bake-field-fauna.gd', 'bake-troll-actions.gd', 'bake-skeleton-actions.gd'))
    scenes_by_body['167'] = read_bake('brown-bear-actions',
                                     ('bake-brown-bear-actions.gd', 'bake-dog-bear-actions.gd', 'bake-quadruped-actions.gd'))
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    pins = read(ROOT / 'scripts/field-fauna-frame-pins.json')
    assert pins['definition_archives'] == {entry['name']: entry['sha256'] for entry in ledger['archives']
                                          if entry['name'] in pins['definition_archives']}
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    rows = []
    for body, routes in ROUTES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [identity['body'] for identity in row['bodies']] == [body])
        assert base['profile'] == ('monster' if body == 42 else 'animal')
        redirects = [entry for entry in ledger['original_definition_redirect_candidates'] if entry['body'] == body]
        reference_body = body
        if str(body) in pins['definition_redirects']:
            reference_body, hue = pins['definition_redirects'][str(body)]
            assert {entry['scope'] for entry in redirects} == {'mobile', 'corpse'} and len(redirects) == 2
            assert all((entry['graphic'], entry['legacy_hue']) == (reference_body, hue)
                       and entry['target_indexed_frames'] and not entry['source_indexed_frames'] for entry in redirects)
        else:
            assert not redirects
        frame_pins = pins['frames'][str(reference_body)]
        assert set(frame_pins) == {str(slot) for slot in routes}
        references = {slot: reference(ledger, reference_body, int(slot),
                                       ('anim.mul', reference_body, frames, digest))
                      for slot, (frames, digest) in frame_pins.items()}
        assets, scenes = {}, {}
        for treatment in ('original', 'rounded', 'modern'):
            source = base.get('assets', {}).get(treatment, f"res://local-art/creatures/{base['kind']}-{treatment}.gltf")
            digest = sha(VIEWER / source.removeprefix('res://'))
            target = f'local-art/creatures/field-fauna-{body}-{treatment}.scn'
            scenes[treatment] = sha(VIEWER / target)
            assert digest == base['asset_sha256'][treatment]
            assert scenes_by_body[str(body)][treatment] == {'source': digest, 'scene': scenes[treatment]}
            assets[treatment] = 'res://' + target
        clips = dict(base['clip_sources'])
        if body == 167:
            for clip in ('Attack', 'Death'):
                clips['Recovered' + clip] = clips.pop(clip)
        anchor = '2' if body == 42 else '8'
        # The candidate loader checks the native identity of the anchor.
        # Preserve the actual graphic separately for redirected frame evidence.
        row = dict(base, family=FAMILY, status='prepared', assets=assets, clip_sources=clips,
                   presentation_script='res://' + VISUAL, presentation_script_sha256=sha(VIEWER / VISUAL),
                   native_constructor_hues={CLASSES[body][0]: HUES[body]},
                   authored_action_reference=dict(references[anchor], body=body),
                   classic_motion_references=references, legacy_frame_redirects=redirects,
                   authored_action_scene_sha256=scenes, native_extra_classic_actions=EXTRAS[body],
                   classic_action_categories=base.get('classic_action_categories', {}) |
                   {str(slot): label for slot, label in routes.items()},
                   authored_replacements=base.get('authored_replacements', {}) | METHODS.get(body, METHODS[214]))
        if body == 42:
            modern, = (entry for entry in ledger['original_new_protocol_actions']
                       if entry['body'] == body and entry['type'] == 14)
            assert (modern['mode'], modern['subaction'], modern['groups']) == (0, -1, [11])
            assert not modern['groups_with_uop_frame_headers'] and base['classic_action_categories']['11'] == 'Hunch'
            row['new_action_categories'] = base.get('new_action_categories', {}) | {'14': 'Hunch'}
            row['new_action_reference'] = {key: modern[key] for key in ('body', 'type', 'mode', 'subaction', 'groups')}
        rows.append(row)
    return rows, CLASSES
