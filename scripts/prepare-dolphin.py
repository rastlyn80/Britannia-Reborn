"""Pinned independent dolphin input and trial metadata; no game art is copied."""
import argparse, hashlib, json, re, struct, urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
PINS=ROOT/'scripts/dolphin-inputs.json'
WORK=ROOT/'work/creatures/dolphin-free'
LOCAL=ROOT/'Viewer/local-art/dolphin'

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def write(path,data):path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')

def inputs(verify_only):
    pins=read(PINS);path=WORK/pins['file'];WORK.mkdir(parents=True,exist_ok=True)
    if not path.exists():
        assert not verify_only,'Pinned independent mesh missing'
        with urllib.request.urlopen(pins['download'],timeout=60) as response:raw=response.read(pins['bytes']+1)
        assert len(raw)==pins['bytes'] and hashlib.sha256(raw).hexdigest()==pins['sha256'],'Unexpected dolphin download'
        path.write_bytes(raw)
    raw=path.read_bytes();assert len(raw)==pins['bytes'] and sha(path)==pins['sha256'],'Changed source GLB'
    magic,version,length=struct.unpack_from('<4sII',raw);assert magic==b'glTF' and version==2 and length==len(raw)
    size,tag=struct.unpack_from('<II',raw,12);assert tag==0x4e4f534a
    source=json.loads(raw[20:20+size]);assert 'CC0' in source['asset']['copyright'] and not source.get('skins') and not source.get('animations')
    print('DOLPHIN INPUT: pinned CC0 study mesh; no source rig/actions')
    return pins

def candidate(pins):
    report=read(LOCAL/'preparation.json');asset=LOCAL/'dolphin.glb'
    assert report['recipe_sha256']==sha(ROOT/'scripts/blender-prepare-dolphin.py') and report['asset_sha256']==sha(asset),'Stale dolphin export'
    motion=read(ROOT/'outputs/creatures/dolphin-trial/motion.json')
    assert motion['failures']==0 and motion['checks']>=1000 and motion['asset_sha256']==sha(asset)
    assert motion['test_sha256']==sha(ROOT/'Viewer/Presentation/DolphinMotionTests.gd')
    assert motion['recipe_sha256']==report['recipe_sha256'] and motion['import_sha256']==sha(Path(str(asset)+'.import'))
    samples=motion['samples'];assert len(samples)==126
    low=[min(row['bounds']['position'][i] for row in samples) for i in range(3)]
    high=[max(row['bounds']['position'][i]+row['bounds']['size'][i] for row in samples) for i in range(3)]
    native='Projects/UOContent/Mobiles/Animals/Misc/Dolphin.cs'
    source=ROOT/'Server/ModernUO'/native
    assert source.exists(),'Pinned native dolphin source unavailable'
    assignment=re.search(r'\bBody\s*=\s*(0x[0-9a-fA-F]+|[0-9]+)\s*;',source.read_text(encoding='utf-8-sig'))
    assert assignment and int(assignment[1],0)==151,'Native dolphin body changed'
    clips=report['clips'];stats={'bones':report['bones'],'height_m':.83,'bind_diagonal_m':3.3,'clips':clips}
    record={'kind':'dolphin_bottlenose','family':'dolphins','status':'candidate','profile':'sea','movement_mode':'native_waterline','surface_kind':'marine_pbr','head_bone':'head',
      'assets':{'modern':'res://local-art/dolphin/dolphin.glb'},'bodies':[{'body':151,'scale':[1,1,1],'name':'Dolphin','native_profile':'sea','native_sources':[{'path':native,'sha256':sha(source)}]}],
      'license':'GPL-3.0-or-later authored conversion/rig/actions; underlying Innerscene mesh and embedded maps CC0-1.0',
      'source':pins['source'],'source_interpretation':'Independent licensed bottlenose study mesh/maps with authored rig and 14 action categories. No recovered Third Dawn rig or original choreography.',
      'partial_hue_interpretation':'Authored neutral-colour test on the licensed body; dark eyes/nose/mouth protected. Original UO partial dye mask not recovered.',
      'classic_action_categories':{'3':'Jump','4':'Roll'},'new_action_categories':{'11':'Attack'},
      'stats':{'original':stats,'modern':stats},'authored_replacements':{name:info['origin'] for name,info in clips.items()},
      'camera_height':.7,'pick_bounds':{'position':low,'size':[high[i]-low[i] for i in range(3)]},
      'source_pin_sha256':sha(PINS),'recipe_sha256':report['recipe_sha256']}
    write(LOCAL/'candidate.json',record)
    print('DOLPHIN CANDIDATE: measured 126-pose bounds, native body151, explicit breach3/4; not installed')

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--verify-only',action='store_true');parser.add_argument('--candidate',action='store_true');args=parser.parse_args()
    pins=inputs(args.verify_only)
    if args.candidate:candidate(pins)
if __name__=='__main__':main()
