"""Verify the Ophidian Classic action and staff preparation receipts."""

import hashlib
import json
from pathlib import Path
import runpy
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'Viewer/local-art/creatures'
CLASSES = {85: ['OphidianMage', 'OphidianArchmage'], 87: ['OphidianMatriarch']}
RECIPES = {
    85: ('ophidians_ophidian_mage', '4857404f4ce76caf2467615caabef896626e2d06631959ccd02cbfac75b3ca21', {
        11: ('StaffDip', '3ade2c42457b905211ae8d547435e48387e5ab868c2779b0af195785256cabe7'),
        12: ('StaffCast', '3a567ca5440555cfd2fd775ec7fad2454ed46a8ab770a54082107d90965072bc'),
        14: ('Cast2', '2dbccf3f3ba93cd502009366b03a743e606191509aeb403234f6f3b77f6e697e'),
    }),
    87: ('ophidians_ophidian_queen', '4ba100de6e17d73bbd6e51ff4ab5d2aa4edc5cd744bd17c9c032922131a0478f', {
        11: ('OphidianQueenDip', '38e0ca37f3bee12218a4d98c78f282a77d16966fcb4840a7cf06025daedbbd15'),
    }),
}
DESCRIPTIONS = {
    'StaffDip': 'Authored torso dip with the original staff held upright',
    'StaffCast': 'Authored held cast with the original staff braced across both hands',
    'Cast2': 'Authored forward staff release with local sparks',
    'OphidianQueenDip': 'Authored unarmed torso and tail dip from the Classic frames',
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def prepared(entries):
    extraction = runpy.run_path(str(ROOT / 'scripts/prepare-ophidian-staff.py'))
    extraction['checked_source']()
    private = extraction['OUTPUT']
    source = read(private / 'source.json')
    assert (source['staff'], source['sha256'], source['atlas'], source['atlas_sha256']) == (
        extraction['STAFF'], extraction['STAFF_SHA'], extraction['ATLAS'], extraction['ATLAS_SHA'])
    bake = read(private / 'bake.json')
    for key, script in (('recipe', 'bake-ophidian-staff-gestures.gd'),
                        ('arm', 'bake-skeleton-axe-trial.gd'), ('weapon', 'bake-troll-weapons-trial.gd'),
                        ('clearance', 'ophidian-staff-clearance.gd'), ('skin_solver', 'ophidian-bardiche-clearance.gd')):
        assert bake[key] == sha(ROOT / 'scripts' / script)
    assert bake['corners'] == source['corners_sha256'] == sha(private / 'corners.json')
    assert bake['atlas'] == source['png_sha256'] == sha(private / 'atlas.png')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    rows = []
    with ZipFile(ROOT / 'work/third-dawn/uotdb.zip') as archive:
        for body, (kind, donor_sha, actions) in RECIPES.items():
            base, = (row for row in entries if row['status'] == 'validated' and row['kind'] == kind
                     and [identity['body'] for identity in row['bodies']] == [body])
            assert hashlib.sha256(archive.read(base['clip_sources']['Idle'])).hexdigest() == donor_sha
            references = {str(slot): reference(ledger, body, slot, ('anim.mul', body, 5, digest))
                          for slot, (_, digest) in actions.items()}
            assets, scenes = {}, {}
            for treatment in ('original', 'rounded', 'modern'):
                file = f'ophidian-{body}-staff-classic-{treatment}.scn'
                original = sha(ART / f'{kind}-{treatment}.gltf')
                scenes[treatment] = sha(ART / file)
                assert original == base['asset_sha256'][treatment]
                assert bake['forms'][str(body)][treatment] == {'source': original, 'scene': scenes[treatment]}
                assets[treatment] = f'res://local-art/creatures/{file}'
            categories = {str(slot): clip for slot, (clip, _) in actions.items()}
            row = dict(base, status='prepared', family='ophidian_staff', assets=assets,
                       authored_action_scene_sha256=scenes, authored_action_reference=references['11'],
                       classic_motion_references=references,
                       classic_action_categories=base.get('classic_action_categories', {}) | categories,
                       authored_replacements=base.get('authored_replacements', {}) | {
                           clip: DESCRIPTIONS[clip] for clip in categories.values()})
            if body == 85:
                visual = 'Presentation/SourceOphidianStaffVisual.gd'
                row.update(presentation_script=f'res://{visual}', presentation_script_sha256=sha(ROOT / 'Viewer' / visual),
                           source_body_prop=source)
            rows.append(row)
    return rows, CLASSES
