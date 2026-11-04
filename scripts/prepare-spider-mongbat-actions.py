"""Validate the retained Spider and Mongbat action packages."""

import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'spider_mongbat_actions'
CLASSES = {28: ['GiantSpider'], 39: ['GreaterMongbat', 'Mongbat', 'StrongMongbat']}
ROUTES = {
    28: {2: 'Death', 3: 'Death2', 4: 'Attack', 5: 'FrontClasp', 6: 'ForwardStab',
         10: 'Hit', 11: 'AbdomenShift', 15: 'LegFlick', 16: 'SpiderBrace', 17: 'Fidget', 18: 'AbdomenRock'},
    39: {2: 'Death', 3: 'Death2', 4: 'WingBackhand', 5: 'Attack', 6: 'WingJab',
         10: 'Hit', 11: 'WingSettle', 15: 'WingOpenRecoil', 16: 'WingFoldRecoil',
         17: 'MongbatArmLift', 18: 'Fidget2', 19: 'Fly', 20: 'Land', 21: 'AirDeath'},
}
METHODS = {
    28: {'Death2': 'Fitted fold on the recovered collapse with a front-leg flick and shorter drift',
         'FrontClasp': 'Fitted opposing foreleg sweep', 'ForwardStab': 'Fitted single foreleg extension',
         'LegFlick': 'Fitted raised front-leg recoil', 'SpiderBrace': 'Fitted low opposite recoil',
         'AbdomenRock': 'Fitted abdomen turn and small leg lift'},
    39: {'Death2': 'Fitted ground collapse using the latter part of the recovered airborne fall',
         'WingBackhand': 'Fitted outward strike with the near arm',
         'WingJab': 'Fitted forward thrust and asymmetric wing shift',
         'WingOpenRecoil': 'Fitted asymmetric wing opening', 'WingFoldRecoil': 'Fitted folded wing recoil'},
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def prepared(entries):
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    pins = read(ROOT / 'scripts/spider-mongbat-frame-pins.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    donor_recipe = ROOT / 'scripts/prepare-mongbat-air-death.py'
    donor = read(ART / 'mongbat-air-death-donor.json')
    assert donor['source_sha256'] == runpy.run_path(str(donor_recipe))['PINS']
    assert donor['recipe_sha256'] == sha(donor_recipe)
    assert donor['gltf_sha256'] == sha(ART / 'mongbat-air-death-donor.gltf')
    assert donor['stats']['clips']['AirDeath']['matched_tracks'] == 55
    rows = []
    for body, routes in ROUTES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [identity['body'] for identity in row['bodies']] == [body])
        assert base['profile'] == 'monster' and base['classic_action_categories']['11'] == routes[11]
        assert set(pins[str(body)]) == {str(slot) for slot in routes}
        references = {slot: reference(ledger, body, int(slot), ('anim.mul', body, frames, digest))
                      for slot, (frames, digest) in pins[str(body)].items()}
        for slot, previous in base.get('classic_motion_references', {}).items():
            assert references[slot] == previous
        mongbat = body == 39
        stem = 'mongbat-actions' if mongbat else 'giant-spider-actions'
        renderer = 'Presentation/' + ('MongbatActionsVisual.gd' if mongbat else 'GiantSpiderActionsVisual.gd')
        bake = read(ART / f'{stem}-bake.json')
        files = [ROOT / f'scripts/bake-{stem}.gd', VIEWER / 'Presentation/SourceGroundLookup.gd']
        if mongbat:
            files.extend((ART / 'mongbat-air-death-donor.gltf', ROOT / 'scripts/bake-troll-actions.gd',
                          ROOT / 'scripts/bake-skeleton-actions.gd', VIEWER / 'Presentation/WaterElementalFidgets.gd'))
        assert bake['inputs'] == {path.name: sha(path) for path in files}
        assets, scenes = {}, {}
        for treatment, source in base['assets'].items():
            digest = sha(VIEWER / source.removeprefix('res://'))
            target = f'local-art/creatures/{stem}-{treatment}.scn'
            scenes[treatment] = sha(VIEWER / target)
            assert digest == base['asset_sha256'][treatment]
            assert bake['scenes'][treatment] == {'source': digest, 'scene': scenes[treatment]}
            assets[treatment] = 'res://' + target
        row = dict(base, status='prepared', family=FAMILY, assets=assets,
                   authored_action_scene_sha256=scenes, authored_action_reference=references['3'],
                   presentation_script='res://' + renderer, presentation_script_sha256=sha(VIEWER / renderer),
                   classic_motion_references=references,
                   native_extra_classic_actions=[10, 15, 16, 2, 3, 21 if mongbat else 18],
                   classic_action_categories={str(slot): label for slot, label in routes.items()},
                   authored_replacements=base['authored_replacements'] | METHODS[body])
        if mongbat:
            modern, = (entry for entry in ledger['original_new_protocol_actions']
                       if entry['body'] == 39 and entry['type'] == 14)
            assert (modern['mode'], modern['subaction'], modern['groups']) == (0, -1, [11])
            assert not modern['groups_with_uop_frame_headers']
            row['new_action_categories'] = base.get('new_action_categories', {}) | {'14': 'WingSettle'}
            row['new_action_reference'] = {key: modern[key] for key in ('body', 'type', 'mode', 'subaction', 'groups')}
            row['clip_sources'] = base['clip_sources'] | {
                'AirDeath': 'uotdb/uotd/Models/Monsters/mongbats_mongbat_dieinair.grn'}
        rows.append(row)
    return rows, CLASSES
