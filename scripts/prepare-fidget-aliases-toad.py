"""Validate local Classic frame receipts and the unchanged source scene variants."""

import hashlib
import json
from pathlib import Path
import runpy
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'Viewer/local-art/creatures'
CLASSES = {67: ['StoneGargoyle'], 80: ['GiantToad'], 149: ['Succubus', 'Szavetra']}
SZAVETRA = {
    'path': 'Projects/UOContent/Mobiles/Monsters/ML/Sanctuary/Szavetra.cs',
    'sha256': '2dd525968594b026ce97d0d64e4fec01158c33badf8c446333253d356202044d',
}
RECIPES = {
    67: ('gargoyles_gargoyle_stone', 'Fidget', 'anim2.mul', 70,
         'e5aa544b3215f388013dec8f088e66a3f6b30c9ec63caac586f6004c4863d548',
         'ac7a408a9fde0498de764f22dd9c57d9114922630fef37644238cd08b5d268d7',
         '5baf6c84b365ccef458c51fa7466954effa175340f5b1d51de9c9f3fb8a28960'),
    80: ('frogs_frog_giant', 'ToadGulp', 'anim.mul', 80,
         '24baa1333734f39a9cbe25b900459eda879e1b5234eaee3fe1aca625f03c12e3',
         None, '83c516f0b1695953fb701615f536336d855012a5aa0154d687a814353b702993'),
    149: ('succubi_succubus', 'Fidget', 'anim2.mul', 25,
          '35a71ab85e6ca74b3546aab642c833072323b170794c117e73645f1761fc4719',
          '5b58523e4d7cd0e56ee994df06a7a225119a234c166fe077090be90caad8abde',
          'a96fc2f28d1ebcc3fd84d4f2d7e97c7b9182b50d1e67deaa68cfdb99df21c352'),
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def prepared(entries):
    receipt = read(ROOT / 'work/creatures/mul-motion-review/fidget-aliases-toad-bake.json')
    assert receipt['recipe'] == sha(ROOT / 'scripts/bake-fidget-aliases-toad.gd')
    assert receipt['arm'] == sha(ROOT / 'scripts/bake-skeleton-axe-trial.gd')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    rows = []
    with ZipFile(ROOT / 'work/third-dawn/uotdb.zip') as archive:
        for body, (kind, clip, frames, graphic, digest, duplicate, donor_sha) in RECIPES.items():
            base, = (row for row in entries if row['status'] == 'validated' and row['kind'] == kind
                     and [identity['body'] for identity in row['bodies']] == [body])
            if duplicate:
                assert hashlib.sha256(archive.read(base['clip_sources']['Fidget'])).hexdigest() == donor_sha
            else:
                source = base['clip_sources']['Idle'].removeprefix('uoaos/UOTD/')
                assert sha(ROOT / 'work/third-dawn/late-source-research/uoaos-source' / source) == donor_sha
            witnesses = {'11': reference(ledger, body, 11, (frames, graphic, 5, digest))}
            categories = {'11': clip}
            if duplicate:
                # The two pinned encoded groups have identical registered
                # pixels and placement in all five directions.
                witnesses['17'] = reference(ledger, body, 17, (frames, graphic, 5, duplicate))
                categories['17'] = 'Fidget'
            assets, scenes = {}, {}
            for treatment in ('original', 'rounded', 'modern'):
                file = f'fidget-toad-{body}-{treatment}.scn'
                original = sha(ART / f'{kind}-{treatment}.gltf')
                scenes[treatment] = sha(ART / file)
                assert original == base['asset_sha256'][treatment]
                assert receipt['forms'][str(body)][treatment] == {'source': original, 'scene': scenes[treatment]}
                assets[treatment] = f'res://local-art/creatures/{file}'
            row = dict(base, status='prepared', family='fidget_aliases_toad', assets=assets,
                       authored_action_scene_sha256=scenes, authored_action_reference=witnesses['11'],
                       classic_motion_references=witnesses,
                       classic_action_categories=base.get('classic_action_categories', {}) | categories)
            if body == 149:
                assert sha(ROOT / 'Server/ModernUO' / SZAVETRA['path']) == SZAVETRA['sha256']
                identity, = base['bodies']
                row['bodies'] = [dict(identity, native_sources=[*identity['native_sources'], SZAVETRA])]
            if not duplicate:
                row['authored_replacements'] = base.get('authored_replacements', {}) | {
                    clip: 'Authored short throat and tongue movement over the recovered planted idle'}
            rows.append(row)
    return rows, CLASSES
