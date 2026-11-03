"""Prepare a local body165 trial using the original project-owned Wisp asset.

Geometry/rig/actions remain the GPL authored donor. No original game artwork is
read, converted or redistributed; native source fingerprints are metadata only.
"""
import argparse
import copy
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT/'Viewer/local-art/creatures'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare():
    index = ROOT/'Viewer/Art/Creatures/index.json'
    donor = next(row for row in json.loads(index.read_text())['entries'] if row['kind'] == 'wisp')
    assert donor['status'] == 'validated' and donor['license'].startswith('GPL-3.0-or-later')
    scene = ROOT/'Viewer/Art/Creatures/Wisp/wisp.scn'
    sources = ['Projects/UOContent/Mobiles/Monsters/Misc/Magic/ShadowWisp.cs',
               'Projects/UOContent/Mobiles/Familiars/ShadowWisp.cs']
    native = [{'path':name,'sha256':sha(ROOT/'Server/ModernUO'/name)} for name in sources]
    row = copy.deepcopy(donor)
    row.update(kind='shadow_wisp',family='shadow_wisps',status='prepared',
               presentation_script='res://Presentation/ShadowWispVisual.gd',
               bodies=[{'body':165,'name':'ShadowWisp / ShadowWispFamiliar','scale':[1,1,1],
                        'native_profile':'monster','native_sources':native}],
               native_constructor_hues={'ShadowWisp':0,'ShadowWispFamiliar':0x901},
               source_interpretation='Original project-owned Wisp geometry/rig/actions with authored dark core/rim surface and0.85proportions; original Third Dawn wisp is unskinned, not recovered skeletal source art.',
               partial_hue_interpretation='Authored dark-core protection with tinted rays; full hue remains distinct. No recovered native partial mask.',
               material_scope='Body165 default hue0 remains intrinsically dark. Familiar0x901 and all other raw native hues pass through the shared palette.',
               native_validation='Constructor-only wild/familiar body165 and raw hues checked in an isolated non-listening probe. No native-live, AI, ownership or mana-restoration certification.',
               remaining_fidelity=['Native wild/familiar AI/ownership/mana restoration','Continuous terrain/no-slip/spawn and final art/LOD/crowds'])
    row['donor_recipe_sha256'] = row.pop('recipe_sha256')
    files = ['ShadowWispVisual.gd','ShadowWispSurface.gdshader','WispVisual.gd','WispMaterial.gd',
             'WispSurface.gdshader','CreatureVisual.gd','OstardVisual.gd','HumanHue.gd','CreatureRegistry.gd','CorpseModels.gd']
    pin = json.loads((ROOT/'Server/dependencies.json').read_text())['modernuo']['revision']
    revision = subprocess.check_output(['git','-C',str(ROOT/'Server/ModernUO'),'rev-parse','HEAD'],text=True).strip()
    assert revision == pin, 'Native checkout differs from pinned revision'
    report = {'family':'shadow_wisps','models':[row],
              'server_pin':json.loads((ROOT/'Server/dependencies.json').read_text())['modernuo']['revision'],
              'donor_scene_sha256':sha(scene),'donor_record_sha256':hashlib.sha256(json.dumps(donor,sort_keys=True).encode()).hexdigest(),
              'preparer_sha256':sha(Path(__file__)),
              'runtime_sha256':{name:sha(ROOT/'Viewer/Presentation'/name) for name in files},
              'scope':'Prepared owned-asset trial only; no accepted route or native witness. Source scene/rig/actions are reused, not edited.'}
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-prepared',action='store_true')
    parser.add_argument('--publish',action='store_true',help='Register the checked owned body165 presentation')
    args = parser.parse_args()
    report = prepare()
    folder = ART/'shadow_wisps'
    folder.mkdir(parents=True,exist_ok=True)
    prepared = folder/'preparation.json'
    if args.check_prepared or args.publish:
        assert json.loads(prepared.read_text()) == report, 'Preparation is stale; regenerate and check changed inputs'
        if args.publish:
            gpu = json.loads((ROOT/'work/creatures/shadow-wisp/validation/presentation.json').read_text())
            assert gpu['failures'] == 0 and gpu['checks'] >= 322 and gpu['renderer'] == 'forward_plus'
            assert gpu['preparation_sha256'] == sha(prepared) and gpu['asset_sha256'] == report['donor_scene_sha256']
            for name, digest in gpu['runtime_sha256'].items():
                assert sha(ROOT/'Viewer/Presentation'/name) == digest, 'Stale GPU evidence: '+name
            distribution = json.loads((ROOT/'work/creatures/shadow-wisp/distribution.json').read_text())
            assert distribution['failures'] == 0 and distribution['checks'] >= 676
            assert distribution['base_test_sha256'] == sha(ROOT/'Viewer/Presentation/WispDistributionTests.gd')
            assert distribution['preparation_sha256'] == sha(prepared)
            for relative, digest in distribution['input_sha256'].items():
                assert sha(ROOT/'Viewer'/relative) == digest, 'Stale clean-package evidence: '+relative
            index_path = ROOT/'Viewer/Art/Creatures/index.json'
            public = json.loads(index_path.read_text())
            row = copy.deepcopy(report['models'][0]);row['status'] = 'validated'
            old = [item for item in public['entries'] if item['kind'] == 'shadow_wisp']
            assert not old or old == [row], 'Existing Shadow Wisp differs; review before replacing'
            if not old:
                assert all(int(body['body']) != 165 for item in public['entries'] for body in item['bodies'])
                public['entries'].append(row)
                index_path.write_text(json.dumps(public,indent=2)+'\n',encoding='utf-8')
            print('SHADOW WISP REGISTERED: owned public body165; original Wisp58 unchanged; no native gameplay claim')
        else:
            print('SHADOW WISP: current pinned native metadata, donor, renderer and preparation')
        return
    prepared.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('SHADOW WISP PREPARED: owned donor scene/rig/actions, native165 identities, raw0/0x901; no route changed')


if __name__ == '__main__':
    main()
