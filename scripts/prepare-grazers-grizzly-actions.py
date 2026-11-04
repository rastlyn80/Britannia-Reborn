"""Verify the Grey Wolf donor and the Grizzly, Boar and Goat motion scenes."""

from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'grazers_grizzly_actions'
CLASSES = {25: ['GreyWolf'], 27: ['GreyWolf'], 212: ['GrizzlyBear'], 290: ['Boar'], 209: ['Goat']}
VISUAL = 'Presentation/SourceQuadrupedCollapseVisual.gd'
WOLVES = {5: 'Attack', 6: 'Attack2', 8: 'Death', 9: 'Fidget', 10: 'Fidget2', 12: 'Death2'}
OTHER = {4: 'LookSide', **WOLVES}
METHODS = {
    25: {'Attack': 'Recovered Grey Wolf strike with measured floor clearance',
         'Attack2': 'Fitted Timber Wolf forepaw pounce on the matching 32-joint rig',
         'Fidget2': 'Fitted Timber Wolf chin lift on the matching rig',
         'Death': 'Fitted Timber Wolf belly-first fall on the matching rig',
         'Death2': 'Fitted Timber Wolf alternate roll on the matching rig'},
    212: {'Attack': 'Fitted tall rearing swipe', 'Attack2': 'Fitted lower forward strike',
          'LookSide': 'Fitted lateral head turn', 'Fidget2': 'Fitted short head dip',
          'Death': 'Fitted forward fall', 'Death2': 'Fitted side collapse'},
    290: {'Attack': 'Recovered Boar attack with fitted floor offset', 'Attack2': 'Fitted short head drive',
          'LookSide': 'Fitted lateral head turn', 'Fidget2': 'Fitted short head dip',
          'Death': 'Fitted belly-first fall with tucked hooves', 'Death2': 'Fitted side collapse'},
    209: {'Attack': 'Recovered Goat attack with fitted floor offset', 'Attack2': 'Fitted low head drive',
          'LookSide': 'Fitted lateral head turn', 'Fidget2': 'Fitted short head dip',
          'Death': 'Fitted roll', 'Death2': 'Fitted opposite side collapse'},
}


def prepared(entries):
    helpers = runpy.run_path(str(ROOT / 'scripts/prepare-field-fauna.py'))
    read, sha, read_bake = (helpers[name] for name in ('read', 'sha', 'read_bake'))
    common = ('bake-dog-bear-actions.gd', 'bake-quadruped-actions.gd')
    wolves = read_bake('grey-wolf-actions', ('bake-grey-wolf-actions.gd', *common))
    grazers = read_bake('grazers-grizzly-actions', ('bake-grazers-grizzly-actions.gd', *common))
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    pins = read(ROOT / 'scripts/grazers-grizzly-frame-pins.json')
    assert pins['definition_archives'] == {row['name']: row['sha256'] for row in ledger['archives']
                                          if row['name'] in ('Body.def', 'Corpse.def')}
    donor = read(ART / 'quadruped-actions-bake.json')['scenes']['225']
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    rows = []
    for body, classes in CLASSES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and any(identity['body'] == body for identity in row['bodies']))
        identity, = (identity for identity in base['bodies'] if identity['body'] == body)
        assert base['profile'] == identity['native_profile'] == 'animal'
        wolf = body in (25, 27)
        graphic = 225 if wolf else body
        routes = WOLVES if wolf else OTHER
        redirects = [row for row in ledger['original_definition_redirect_candidates'] if row['body'] == body]
        if wolf:
            assert pins['definition_redirects'][str(body)][0] == graphic
            assert len(redirects) == 2 and {row['scope'] for row in redirects} == {'mobile', 'corpse'}
            for row in redirects:
                assert [row['graphic'], row['legacy_hue']] == pins['definition_redirects'][str(body)]
                assert row['target_indexed_frames'] and not row['source_indexed_frames']
        else:
            assert not redirects
        references = {slot: reference(ledger, graphic, int(slot), ('anim.mul', graphic, frames, digest))
                      for slot, (frames, digest) in pins['frames'][str(graphic)].items()}
        assert set(references) == {str(slot) for slot in routes}
        assets, scenes = {}, {}
        for treatment in ('original', 'rounded', 'modern'):
            source = base.get('assets', {}).get(treatment, f"res://local-art/creatures/{base['kind']}-{treatment}.gltf")
            original = sha(VIEWER / source.removeprefix('res://'))
            assert original == base['asset_sha256'][treatment]
            stem = 'grey-wolf-actions' if wolf else f'grazers-grizzly-actions-{body}'
            file = f'{stem}-{treatment}.scn'
            scenes[treatment] = sha(ART / file)
            expected = {'source': original, 'scene': scenes[treatment]}
            if wolf:
                donor_file = ART / f'quadruped-actions-225-{treatment}.scn'
                expected['donor'] = sha(donor_file)
                assert expected['donor'] == donor[treatment]['scene']
                assert wolves[treatment] == expected
            else:
                assert grazers[str(body)][treatment] == expected
            assets[treatment] = f'res://local-art/creatures/{file}'
        clips = dict(base['clip_sources'])
        for clip in ('Attack', 'Death'):
            clips['Recovered' + clip] = clips.pop(clip)
        rows.append(dict(base, status='prepared', family=FAMILY, bodies=[identity], assets=assets,
                         clip_sources=clips, legacy_frame_redirects=redirects,
                         presentation_script='res://' + VISUAL, presentation_script_sha256=sha(VIEWER / VISUAL),
                         native_constructor_hues={classes[0]: 0},
                         classic_motion_references=references, authored_action_reference=dict(references['8'], body=body),
                         authored_action_scene_sha256=scenes,
                         native_extra_classic_actions=[6, 8, 12] if wolf else [4, 6, 8, 12],
                         classic_action_categories={str(slot): clip for slot, clip in routes.items()},
                         authored_replacements=METHODS[25 if wolf else body]))
    return rows, CLASSES
