"""Pin the retargeted Classic attacks and separate gestures of both Skeleton forms."""

import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
FAMILY = 'skeleton_actions'
CLASSES = {50: ['Skeleton'], 56: ['Skeleton']}
DONOR = 'cbd480a7a45e02c3d4809dae3a8afd58e263f36b14f265d366eed4147705a6c9'
DONOR_INPUTS = {
    'patchskeleton_attack2.grn': 'b869d6bbf1f058cb00294ead79720dc2aede2d928235faebbc1cf535e1a11c14',
    'patchskeleton_attack3.grn': '5ec655d8b7396f1981412b808fef456683d3969282c55a2166e973d41032dded',
}
SLOTS = {4: 'Attack', 5: 'Attack2', 6: 'Attack3', 10: 'Hit', 15: 'BoneInward',
         16: 'BoneWide', 17: 'BoneStretch', 18: 'Fidget2'}
REFERENCES = {
    50: {
        4: (4, '07200c169fb2b669c6f52d737dff427c3150dd506cc55724c591577f4737539f'),
        5: (4, 'd110d17e0166cd11ae898613c0201c2571a4896dd5a3c71e32fc871b20806981'),
        6: (4, '018b5728104fa4e00bd0900ff19c834042b9de39abd48f76584371463c1a7c91'),
        10: (4, '5aad01ea2b032af5c7f42c8a247e4cb0c9bf23e97e9bab524930331c84eb99d2'),
        15: (3, '7152b73b4dee717424f1535228d3751d564d57f8e92e150b884b4ebdb2f41ad4'),
        16: (3, '1f83a9133d76585d9428b240dc4855869833864c5447124fe683c86e897b4f40'),
        17: (5, '040a427b3fbfbdab368d5b19fd38d16762e59856c6561c0b701e267faf9ab84a'),
        18: (5, 'a27c336af2f0478f93a0a9472750c752c1980ef89675f1b5feaeb35632180887'),
    },
    56: {
        4: (4, '56f26127b6debd8280023eda494c4fd48f1ea63e3210096013e5a71f02b15687'),
        5: (4, 'dad999fa64a56bfdcf14d7f6fdc53fb104e6f6653dab90a1346ca8635ec46e64'),
        6: (4, '19280c7aa7f3308febb21501c6651f04883966f7c6c106154a6c548e0f8e3082'),
        10: (4, 'b99d291fb1e6bcc6d4a512ad598feaa90c9fba141d76da60d5040ffaecb7f6a3'),
        15: (3, 'ad339309b62c144a554722046de1db387a3a953365fd8ff6b494fa287c17e619'),
        16: (3, '93bbea913fbab1a115d965006b507e89657edf406ec5e639398432bae0012d96'),
        17: (5, 'b8b42c555053ef5ccb6b90ca01ea6419c038417da26ad5b48b2b121369b32997'),
        18: (5, 'c87b5f78f41200ca1347b0a7fe30d6211449397cc6912717d03aee6be48bf259'),
    },
}
METHODS = {
    'Attack2': 'Patchwork Skeleton second attack retargeted to plain Skeleton proportions',
    'Attack3': 'Patchwork Skeleton third attack retargeted with a shorter guarded arc',
    'BoneInward': 'Fitted inward reaction with a raised near arm',
    'BoneWide': 'Fitted wide alternating-arm reaction',
    'BoneStretch': 'Fitted two-arm fidget',
    'Fidget2': 'Fitted single-arm salute',
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def prepared(entries):
    bake = read(VIEWER / 'local-art/creatures/skeleton-actions-bake.json')
    for key, path in {
        'recipe': ROOT / 'scripts/bake-skeleton-actions.gd',
        'arm_solver': VIEWER / 'Presentation/WaterElementalFidgets.gd',
        'skin_solver': VIEWER / 'Presentation/SourceGroundLookup.gd',
    }.items():
        assert bake[key] == sha(path)
    donor = VIEWER / 'local-art/creatures/occurrence_next/patchskeleton-modern.gltf'
    assert sha(donor) == bake['donor'] == DONOR
    raw = ROOT / 'work/third-dawn/late-source-research/uoaos-source/Models/Monsters'
    assert all(sha(raw / name) == digest for name, digest in DONOR_INPUTS.items())
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    rows = []
    for body in CLASSES:
        base, = (row for row in entries if row['status'] == 'validated'
                 and row['kind'] == f'skeletons_skeleton_slot11_{body}'
                 and [identity['body'] for identity in row['bodies']] == [body])
        assert base['classic_gesture_native_sha256'] and not base.get('classic_gesture_batch')
        assets, scenes = {}, {}
        for treatment, source in base['assets'].items():
            digest = sha(VIEWER / source.removeprefix('res://'))
            assert digest == base['asset_sha256'][treatment]
            target = f'local-art/creatures/skeleton-actions-{body}-{treatment}.scn'
            scenes[treatment] = sha(VIEWER / target)
            assert bake['scenes'][str(body)][treatment] == {'source': digest, 'scene': scenes[treatment]}
            assets[treatment] = 'res://' + target
        references = {str(slot): reference(ledger, body, slot, ('anim.mul', body, frames, digest))
                      for slot, (frames, digest) in REFERENCES[body].items()}
        row = dict(base, family=FAMILY, status='prepared', assets=assets,
                   authored_action_scene_sha256=scenes, authored_action_reference=references['4'],
                   classic_motion_references=base.get('classic_motion_references', {}) | references,
                   native_extra_classic_actions=[10, 15, 16],
                   classic_action_categories=base['classic_action_categories'] |
                   {str(slot): label for slot, label in SLOTS.items()},
                   authored_replacements=base.get('authored_replacements', {}) | METHODS)
        if body == 50:
            source, = (item for item in ledger['original_new_protocol_actions']
                       if item['body'] == body and item['type'] == 14)
            assert source['mode'] == 0 and source['subaction'] == -1 and source['groups'] == [11]
            original, = (item for item in ledger['original_mul_group_candidates']
                         if (item['body'], item['group']) == (body, 11) and 'matching_classic_route' in item)
            assert original['layout'] == 'large' and not original['mobtype_prefers_uop']
            clip = row['classic_action_categories']['11']
            assert original['matching_classic_route']['resolved'] == clip == 'Reach'
            row['new_action_categories'] = base.get('new_action_categories', {}) | {'14': clip}
            row['new_action_reference'] = {key: source[key] for key in ('body', 'type', 'mode', 'subaction', 'groups')}
        rows.append(row)
    return rows, CLASSES
