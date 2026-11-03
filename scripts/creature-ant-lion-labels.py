"""Scoped Ant Lion label repair; numeric motion and every model joint survive.

Never install on a shared importer. Both ambiguous clips require exact source
hashes, original object/track IDs and right-pincer ancestry before relabelling.
"""
import copy
import hashlib


def install(pipeline, source):
    contract = source['chain_label_contract']
    files = {row['sha256'] for row in source['files'] if row['member'].lower().endswith('.grn')}
    repairs = {row['sha256']:row for row in contract['right_pincer']}
    assert set(repairs) <= files and len(repairs) == 2
    original_parse = pipeline.td.parse
    model_names = []
    active_names = set()
    evidence = []

    def parse(raw, **options):
        digest = hashlib.sha256(raw).hexdigest()
        assert digest in files, 'Ant Lion adapter received an unpinned input'
        repair = repairs.get(digest)
        animation = bool(options.get('animations_only', False))
        if animation:
            assert model_names, 'Parse the pinned model first'
            options['retained_bone_names'] = None if repair else model_names
        elif digest != contract['model_sha256']:
            raise AssertionError('Unexpected Ant Lion mesh')
        require = pipeline.td.require
        duplicate_checks = []

        def bounded_require(ok, message):
            if repair and not ok and message == 'Duplicate bone names':
                duplicate_checks.append(message)
                return
            require(ok, message)

        pipeline.td.require = bounded_require
        try:
            result = original_parse(raw, **options)
        finally:
            pipeline.td.require = require
        before = copy.deepcopy(result)
        if repair:
            assert animation and duplicate_checks == ['Duplicate bone names']
            assert len(result['bones']) == repair['bone_count']
            index, parent = repair['bone_index'], repair['parent_index']
            bone = result['bones'][index]
            assert bone['name'] == repair['original_label'] and bone['parent'] == parent
            assert result['bones'][parent]['name'] == repair['parent_label']
            duplicate = [i for i,b in enumerate(result['bones']) if b['name'] == repair['original_label']]
            assert duplicate == [5,7] and index == 5
            assert result['bones'][7]['parent'] == 6 and result['bones'][6]['name'] == 'large pincher l 01'
            tracks = [t for t in result['tracks'] if t['name'] == repair['original_label']]
            assert len(tracks) == 2 and sum(t['id'] == repair['track_id'] for t in tracks) == 1
            bone['name'] = repair['replacement_label']
            for track in tracks:
                if track['id'] == repair['track_id']:
                    track['name'] = repair['replacement_label']
        for bone in result['bones']:
            bone['name'] = ' '.join(bone['name'].split())
        for track in result['tracks']:
            track['name'] = ' '.join(track['name'].split())
        assert len({bone['name'] for bone in result['bones']}) == len(result['bones'])
        for field in result.keys() - {'bones','tracks'}:
            assert result[field] == before[field], field
        for field in ['bones','tracks']:
            assert len(result[field]) == len(before[field])
            for old, new in zip(before[field],result[field]):
                assert {k:v for k,v in old.items() if k != 'name'} == {k:v for k,v in new.items() if k != 'name'}
        if not animation:
            model_names[:] = [bone['name'] for bone in result['bones']]
            weighted = {result['ties'][slot] for pairs in result['weights'] for slot,weight in pairs if weight > 0}
            for index in weighted:
                seen = set()
                while index not in seen:
                    seen.add(index); active_names.add(result['bones'][index]['name'])
                    index = result['bones'][index]['parent']
        evidence.append({'sha256':digest,'indexed_right_pincer':repair,'numeric_fields_unchanged':True,
                         'model_bones':len(model_names),'weighted_and_ancestor_names':sorted(active_names)})
        return result

    match = pipeline.helper.match_animation

    def checked_match(animation, model):
        result, omitted = match(animation, model)
        names = {bone['name'] for bone in result['bones']}
        assert active_names <= names, 'Cannot discard a weighted Ant Lion joint or ancestor'
        model_map = {bone['name']:bone for bone in model['bones']}
        for bone in result['bones']:
            expected = model['bones'][model_map[bone['name']]['parent']]['name']
            actual = result['bones'][bone['parent']]['name']
            assert actual == expected, (bone['name'],expected,actual)
        return result, omitted

    pipeline.td.parse = parse
    pipeline.helper.match_animation = checked_match
    pipeline.ant_lion_label_evidence = evidence
