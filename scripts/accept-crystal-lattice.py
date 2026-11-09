"""Register the checked local Crystal Lattice Seeker without redistributing source artwork."""
import argparse
import copy
import importlib.util
import json
import runpy
from pathlib import Path

ALIAS_EVIDENCE = runpy.run_path(str(Path(__file__).with_name('legacy-action-evidence.py')))

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('crystal_preparer',ROOT/'scripts/prepare-crystal-lattice.py')
preparer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preparer)
ART, WORK = preparer.ART, preparer.WORK
RECEIPT = ART/'crystal_lattice/local-presentation.json'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def atomic(path, value):
    temporary = path.with_suffix('.json.pending')
    temporary.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
    temporary.replace(path)


def checked():
    base = preparer.recipe()
    preparer.check(base)
    sha = base.sha
    prep = preparer.OUTPUT
    pin = sha(prep)
    model = read(prep)['models'][0]
    skin, actions = read(WORK/'skin-proof.json'), read(WORK/'actions.json')
    appearance = read(WORK/'appearance/appearance.json')
    render = read(WORK/'presentation/validation.json')
    for proof in [skin,actions,appearance,render]:
        assert proof['failures'] == 0 and proof['checks'] > 0
    for proof,name in [(skin,'SourcePreservingSkinTests.gd'),(actions,'SourcePreservingActionTests.gd')]:
        assert proof['preparation_sha256'] == pin
        assert proof['test_sha256'] == sha(ROOT/'Viewer/Presentation'/name)
        assert proof['bound_test_sha256'] == sha(WORK/name)
    assert skin['helper_sha256'] == sha(base.RECIPE)
    saved = skin['models'][0]
    clips = set(model['stats']['original']['clips'])
    assert len(clips) == 9 and {'Hit','Cast'} <= clips
    assert saved['kind'] == 'ethereal_warriors_male' and set(saved['clips']) == clips
    assert saved['source_bones'] == 40 and saved['source_triangles'] == 514 and saved['dense_triangles'] == 2056
    assert saved['poses'] == 27 and saved['maximum_source_triangle_distance_m'] < .002
    assert actions['models'] == [{'kind':'ethereal_warriors_male','body':123,'cast_checked':True}]
    for label, proof in [('presentation',render),('appearance',appearance)]:
        assert proof['renderer'] == 'forward_plus'
        log = (WORK/(label+'.log')).read_text(encoding='utf-8-sig')
        assert 'Vulkan' in log and 'Forward+' in log and 'ERROR:' not in log
    assert appearance['preparation_sha256'] == pin
    assert appearance['test_sha256'] == sha(ROOT/'Viewer/Presentation/CreatureAppearanceTests.gd')
    assert render['inputs_sha256']['res://local-art/creatures/crystal_lattice/preparation.json'] == pin
    for name, digest in render['runtime_sha256'].items():
        assert Path(name).name == name and sha(ROOT/'Viewer/Presentation'/name) == digest, name
    for name, digest in render['inputs_sha256'].items():
        assert name.startswith('res://')
        path = (ROOT/'Viewer'/name.removeprefix('res://')).resolve()
        assert path.is_relative_to(ROOT/'Viewer') and sha(path) == digest, name
    assert set(model['assets'].values()) <= set(render['inputs_sha256'])
    assert len(render['samples']) == 18 and {(r['clip'],r['plane']) for r in render['samples']} == {
        (clip,plane) for clip in clips for plane in ['flat','cross']}
    assert all(r['kind']=='ethereal_warriors_male' and r['body']==123 for r in render['samples'])
    assert len(render['death_entries']) == 2 and {r['plane'] for r in render['death_entries']} == {'flat','cross'}
    assert all(r['first_displayed_skin_error_m'] < .001 for r in render['death_entries'])
    assert len(appearance['samples']) == 6 and {r['clip'] for r in appearance['samples']} == {'Walk','Run','Attack'}
    for view in appearance['samples']:
        assert view['kind'] == 'ethereal_warriors_male' and view['asset_path'] == model['assets']['modern']
        assert view['asset_sha256'] == model['saved_scenes']['modern']['scene_sha256']
        assert view['art_dependency_sha256'] == model['art_dependency_sha256']
    pins = {'publisher_sha256':sha(Path(__file__)),'preparation':pin,'skin':sha(WORK/'skin-proof.json'),
            'presentation':sha(WORK/'presentation/validation.json'),'appearance':sha(WORK/'appearance/appearance.json'),
            'actions':{key:actions[key] for key in ['models','failures','test_sha256','bound_test_sha256','preparation_sha256']}}
    row = copy.deepcopy(model)
    row.update(
        status='validated',
        native_constructor_hues={'CrystalLatticeSeeker': 0x47E, 'EtherealWarrior': 0},
        validation_scope='Original local rig, RGBA atlas and seven timed clips with authored Hit and Cast. Dense skins, dye, two rendered finite planes and decoded static corpse.',
        remaining_fidelity=['Native Drain, autonomous combat and loot',
                            'Continuous and mixed terrain, final art, LOD and crowds',
                            'Existing rigid 30 Hz approximation for source affine motion'])
    return row, pins


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--publish',action='store_true')
    group.add_argument('--check-active',action='store_true')
    args = parser.parse_args()
    row, pins = checked()
    path = ART/'accepted-index.json'
    index = read(path)
    existing = [r for r in index['entries'] if any(int(b['body']) == 123 for b in r['bodies'])]
    assert all(r['kind']=='ethereal_warriors_male' and r['family']=='crystal_lattice' for r in existing), 'Refusing unrelated route replacement'
    if existing:
        row = ALIAS_EVIDENCE['expected_with_legacy_alias'](row, existing[0])
    if args.check_active:
        assert existing == ALIAS_EVIDENCE['expected_rows_with_legacy_aliases']([row], index['entries'])
        ALIAS_EVIDENCE['check_base_receipt'](Path(__file__).name, read(RECEIPT), pins)
    if args.publish:
        backup = WORK/'accepted-index-before-crystal-lattice.json'
        if not backup.exists():backup.write_bytes(path.read_bytes())
        index['entries'] = [r for r in index['entries'] if r not in existing]+[row]
        atomic(path,index)
        atomic(RECEIPT,pins)
    print('CRYSTAL LATTICE123:', 'active verified' if args.check_active else 'published' if args.publish else 'dry run',
          'original source skin/clip/GPU/finite terrain/static corpse route; native evidence separate.')


if __name__ == '__main__':
    main()
