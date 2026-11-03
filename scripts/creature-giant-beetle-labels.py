"""Resolve the original Giant Beetle clip labels and identity parent."""
import copy
import hashlib
import math
from pathlib import Path


def install(pipeline, source):
    normalise = pipeline.normalise_bind
    match_animation = pipeline.helper.match_animation
    members = {entry['sha256']: Path(entry['path']).name for entry in source['files']}
    target = {}

    def reconcile(raw, data):
        model, adjustments = normalise(raw, data)
        filename = members[hashlib.sha256(raw).hexdigest()]
        bones = model['bones']
        for item in bones + model['tracks']:
            item['name'] = ' '.join(item['name'].split())
        if filename == 'giant_beetle_lod2.grn':
            target.update({bone['name']: bone for bone in bones})
            assert len(target) == len(bones)
            return model, adjustments

        identity = target['granny_master']
        assert identity == {
            'parent': 0, 'translation': [0., 0., 0.],
            'rotation': [0., 0., 0., 1.], 'name': 'granny_master',
        }
        assert bones[0]['name'] == '__root' and bones[0]['parent'] == 0
        joint = next(bone for bone in bones if bone['name'] == 'bip 01')
        assert joint['parent'] == 0 and all(bone['name'] != 'granny_master' for bone in bones)
        # An identity parent preserves every descendant transform.
        joint['parent'] = len(bones)
        bones.append(copy.deepcopy(identity))

        aliases = {}
        if filename == 'giant_beetle_attack3.grn':
            aliases = {'head': 'bip01 head', 'spine 03': 'bip01 pelvis'}
            for position, suffix in [('front', ''), ('middle', ' b'), ('rear', ' c')]:
                for side in 'lr':
                    aliases[f'{position} leg {side} 02'] = f'bip01 {side} calf{suffix}'
                    aliases[f'{position} leg {side} 01'] = f'bip01 {side} foot{suffix}'
            assert set(aliases) <= {bone['name'] for bone in bones}
            for bone in bones:
                if bone['name'] in aliases:
                    expected = target[aliases[bone['name']]]
                    assert math.dist(bone['translation'], expected['translation']) < .0001
        elif filename == 'giant_beetle_fidget.grn':
            unnamed = [bone for bone in bones if not bone['name']]
            assert len(unnamed) == 1
            bone = unnamed[0]
            expected = target['bip01 l foot b']
            assert bones[bone['parent']]['name'] == 'bip01 l calf b'
            assert math.dist(bone['translation'], expected['translation']) < .1
            assert abs(sum(a * b for a, b in zip(bone['rotation'], expected['rotation']))) > .999
            aliases[''] = 'bip01 l foot b'
        for item in bones + model['tracks']:
            item['name'] = aliases.get(item['name'], item['name'])
        assert len({bone['name'] for bone in bones}) == len(bones)
        return model, adjustments

    def match(clip, model):
        matched, omitted = match_animation(clip, model)
        source_bones = model['bones']
        clip_bones = matched['bones']
        by_name = {bone['name']: bone for bone in clip_bones}
        weighted = {model['ties'][slot] for pairs in model['weights'] for slot, weight in pairs if weight > 0}
        for index in weighted:
            while True:
                bone = source_bones[index]
                parent = bone['parent']
                actual = by_name[bone['name']]
                assert source_bones[parent]['name'] == clip_bones[actual['parent']]['name'], bone['name']
                if parent == index:
                    break
                index = parent
        return matched, omitted

    pipeline.normalise_bind = reconcile
    pipeline.helper.match_animation = match
