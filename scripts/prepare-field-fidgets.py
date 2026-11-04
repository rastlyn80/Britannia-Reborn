"""Pin the Classic reference groups and the independently licensed Rat update."""

import argparse
import hashlib
import json
from pathlib import Path
import runpy
import shutil
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'Viewer/local-art/creatures'
PUBLIC = ROOT / 'Viewer/Art/Creatures'
RAT_SCENE = 'res://Art/Creatures/Rat/rat-fidgets.scn'
RECIPE = ROOT / 'scripts/bake-field-fidgets.gd'
DEER = {
    237: ('deer_doe', ['Hind', 'EnragedHind']),
    234: ('deer_stag', ['GreatHart', 'EnragedHart']),
}
CLASSES = {body: names for body, (_, names) in DEER.items()}
REFERENCES = {
    234: {
        '4': ('DeerGroundCheck', 3, '4f15b77d73876f40353c37a1dfe979a9f50af706f170df6605fd6fb1289b6ad0'),
        '9': ('Fidget', 5, 'a731b8bec78767007dc9367c6b06d72e9c73fc84052ec1b0aa2088e21211fe84'),
        '10': ('Fidget2', 3, '97f2a8c20f8999331cb3ba41e0e35455605c936ac02e49190dca30cb3d69ff00'),
    },
    237: {
        '4': ('DeerGroundCheck', 3, 'a38ea205bf793ce6cb30833078e4a8e6fc6c9eb1b0d8315bb655cb49c0c938e7'),
        '9': ('DeerPaw', 5, '7534125c99ab7a9fa19e137d73273ecd2fd099b1ffb5cbaafa866842c2fc224b'),
        '10': ('Fidget2', 3, '4e44d1350765959558c7b16bdb4f2d3c6d5b852598ac68cca2667861176a6f2f'),
    },
    238: {
        '9': ('RatRear', 5, '239553488251f7ecf08f9d48c3a0d7bfd9a1ab806a44779dd5b494696cd80319'),
        '10': ('Fidget2', 3, 'f6a8fbb48f19333bd1c997004e6c477a40d726a409c9452876b95255669c2794'),
    },
}
DEER_DONORS = {
    237: {'Idle': '628e6ef9de46de92072f946f5db662ef23edcdfff94d52d8f82f244346bf1ba2',
          'Fidget': '884f7487e81e8d4bde6eb1f97dda68ac9708c6d3843ef6594fca322f44d63f12'},
    234: {'Idle': '0c49954719f11a8692de264d648855f213c8fa0b78f5f96de26ae9b746dc24ac',
          'Fidget': 'a5e61a5b1b4dad8d36f27ecd8f8a1ebb33bbb95def1a8b53039cf1fca7cf77dc'},
}
TREATMENTS = ('original', 'rounded', 'modern')
RAT_CLIPS = {
    'RatRear': {'duration': 0.8, 'loop': False, 'origin': 'Authored hind-paw rear following Classic group 9'},
    'Fidget2': {'duration': 0.48, 'loop': False, 'origin': 'Authored low head and tail motion following Classic group 10'},
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def write(path, data):
    temporary = path.with_suffix(path.suffix + '.pending')
    temporary.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
    temporary.replace(path)


def checked_bake():
    bake = read(ART / 'field-fidgets-bake.json')
    assert bake['recipe_sha256'] == sha(RECIPE)
    return bake['scenes']


def checked_scene(bake, body, treatment, source_digest, name):
    digest = sha(ART / name)
    assert bake[str(body)][treatment] == {'source_sha256': source_digest, 'asset_sha256': digest}
    return 'res://local-art/creatures/' + name, digest


def route_metadata(body, base):
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    evidence = {slot: reference(ledger, body, int(slot), ('anim.mul', body, frames, digest))
                for slot, (_, frames, digest) in REFERENCES[body].items()}
    routes = base.get('classic_action_categories', {}) | {slot: clip for slot, (clip, _, _) in REFERENCES[body].items()}
    return {'classic_action_categories': routes, 'classic_motion_references': evidence,
            'authored_action_reference': next(iter(evidence.values()))}


def prepared_deer(entries):
    bake = checked_bake()
    rows = []
    with ZipFile(ROOT / 'work/third-dawn/uotdb.zip') as archive:
        for body, (stem, _) in DEER.items():
            base, = (row for row in entries if row['status'] == 'validated' and row['kind'] == stem
                     and [identity['body'] for identity in row['bodies']] == [body])
            for clip, digest in DEER_DONORS[body].items():
                assert hashlib.sha256(archive.read(base['clip_sources'][clip])).hexdigest() == digest
            assets, digests = {}, {}
            for treatment in TREATMENTS:
                source = sha(ART / f'{stem}-{treatment}.gltf')
                assert source == base['asset_sha256'][treatment]
                assets[treatment], digests[treatment] = checked_scene(
                    bake, body, treatment, source, f'{stem}-fidgets-{treatment}.scn')
            origins = {'DeerGroundCheck': 'Low lateral check on the existing grazing pose, Classic group 4',
                       'Fidget2': 'Short independent head dip, Classic group 10'}
            if body == 237:
                origins['DeerPaw'] = 'Rephased recovered foreleg pose over a neutral stance, Classic group 9'
            rows.append(dict(base, status='prepared', family='deer_fidgets', assets=assets,
                             authored_action_scene_sha256=digests, native_extra_classic_actions=[4],
                             authored_replacements=base['authored_replacements'] | origins,
                             **route_metadata(body, base)))
    return rows, CLASSES


def prepared_rat():
    base, = (row for row in read(PUBLIC / 'index.json')['entries'] if row['kind'] == 'rat_ordinary')
    sources = read(PUBLIC / 'Rat/provenance.json')
    original = PUBLIC / 'Rat/rat.glb'
    assert sha(original) == sources['asset_sha256']
    assert base['source_pin_sha256'] == sha(ROOT / 'scripts/rat-inputs.json')
    path, digest = checked_scene(checked_bake(), 238, 'modern', sha(original), 'rat-fidgets.scn')
    stats = {name: dict(record, clips=record['clips'] | RAT_CLIPS) for name, record in base['stats'].items()}
    origins = {name: info['origin'] for name, info in RAT_CLIPS.items()}
    row = dict(base, status='prepared', family='rat_fidgets', assets=dict.fromkeys(TREATMENTS, path),
               authored_action_scene_sha256=dict.fromkeys(TREATMENTS, digest), stats=stats,
               authored_replacements=base['authored_replacements'] | origins, **route_metadata(238, base))
    return [row], {238: ['Rat']}


def install_rat():
    rows, _ = prepared_rat()
    row, = rows
    evidence = ROOT / 'work/creatures/rat_fidgets'
    report_path = ROOT / 'outputs/creatures/rat_fidgets/live.json'
    live = read(report_path)
    receipt = read(evidence / 'native-runtime.json')
    candidates = evidence / 'candidates.json'
    trial, = read(candidates)
    assert trial['presentation'] == row
    assert live['failures'] == 0 and live['prepared_trial']
    assert receipt['report_sha256'] == sha(report_path)
    assert receipt['candidate_sha256'] == live['candidate_sha256'] == sha(candidates)
    assert live['test_sha256'] == sha(ROOT / 'Viewer/Network/CreatureLive.gd')
    assert live['prepared_wrapper_sha256'] == sha(ROOT / 'Viewer/Network/PreparedCreatureActionLive.gd')
    assert live['fixture_sha256'] == sha(ROOT / 'Server/HorseIntegrationFixtures/CreatureFixtures.cs')
    assert len(live['records']) == 2 and {r['female'] for r in live['records']} == {True, False}
    for witness in live['records']:
        assert (witness['body'], witness['native_class']) == (238, 'Rat') and not witness['corpse_suppressed']
        for slot, (clip, _, _) in REFERENCES[238].items():
            action, = (item for item in witness['actions'] if item['requested'] == int(slot))
            assert action['owner_clip'] == action['observer_clip'] == clip
            for key in ('owner_packet', 'observer_packet'):
                assert action[key]['protocol'] == 'classic' and action[key]['action'] == int(slot)

    write_rat_bundle(PUBLIC, row)
    print('RAT FIDGETS INSTALLED: verified authored motions on the existing CC0 rig')


def write_rat_bundle(creature_art, row):
    target = creature_art / 'Rat/rat-fidgets.scn'
    temporary = target.with_suffix('.scn.pending')
    shutil.copyfile(ART / 'rat-fidgets.scn', temporary)
    temporary.replace(target)
    provenance_path = creature_art / 'Rat/provenance.json'
    provenance = read(provenance_path)
    provenance['classic_fidgets'] = {'scene_sha256': sha(target), 'recipe_sha256': sha(RECIPE),
                                    'reference_groups': row['classic_motion_references']}
    write(provenance_path, provenance)
    notice_path = creature_art / 'Rat/NOTICE.txt'
    notice = notice_path.read_text(encoding='utf-8')
    description = 'The separate fidget scene adds an authored rear and head dip on the same CC0 rig.'
    if description not in notice:
        notice_path.write_text(notice + description + '\n', encoding='utf-8')
    index_path = creature_art / 'index.json'
    index = read(index_path)
    public_row = dict(row, status='validated', family='ordinary_rats', assets={'modern': RAT_SCENE})
    index['entries'] = [public_row if record['kind'] == 'rat_ordinary' else record for record in index['entries']]
    write(index_path, index)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install-rat', required=True, action='store_true')
    parser.parse_args()
    install_rat()
