"""Pinned independent dolphin input and trial metadata; no game art is copied."""
import argparse, hashlib, json, re, shutil, struct, urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
PINS=ROOT/'scripts/dolphin-inputs.json'
WORK=ROOT/'work/creatures/dolphin-free'
LOCAL=ROOT/'Viewer/local-art/dolphin'
PUBLIC=ROOT/'Viewer/Art/Creatures/Dolphin'

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def write(path,data):path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')

def embedded_images(path):
    raw=path.read_bytes();size,tag=struct.unpack_from('<II',raw,12);assert tag==0x4e4f534a
    gltf=json.loads(raw[20:20+size]);length,tag=struct.unpack_from('<II',raw,20+size);assert tag==0x004e4942
    binary=raw[28+size:28+size+length];result={}
    for image in gltf['images']:
        assert image['mimeType']=='image/png' and re.fullmatch(r'[A-Za-z0-9_]+',image['name'])
        view=gltf['bufferViews'][image['bufferView']];assert view['buffer']==0
        start=view.get('byteOffset',0);data=binary[start:start+view['byteLength']]
        assert len(data)==view['byteLength'] and data.startswith(b'\x89PNG\r\n\x1a\n')
        result['dolphin_'+image['name']+'.png']=data
    assert len(result)==5
    return result

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

def verified_trial():
    record=read(LOCAL/'candidate.json');asset=LOCAL/'dolphin.glb';preparation=read(LOCAL/'preparation.json')
    assert record['recipe_sha256']==preparation['recipe_sha256']==sha(ROOT/'scripts/blender-prepare-dolphin.py')
    assert record['source_pin_sha256']==sha(PINS) and preparation['asset_sha256']==sha(asset)
    reports={}
    for name,minimum in [('motion',1000),('materials',90),('aquatic/validation',56)]:
        report=read(ROOT/'outputs/creatures/dolphin-trial'/f'{name}.json')
        assert report['failures']==0 and report['checks']>=minimum,'Missing or failed dolphin '+name
        for relative,digest in report.get('runtime_sha256',{}).items():
            path=ROOT/'Viewer/Presentation'/relative if not relative.startswith('res://') else ROOT/'Viewer'/relative.removeprefix('res://')
            assert sha(path)==digest,'Stale dolphin trial: '+relative
        if name=='aquatic/validation':
            assert report['renderer']=='forward_plus' and report['preparation_sha256']==sha(LOCAL/'candidate.json')
            assert set(report['assets'])=={record['kind']}
            checked=report['assets'][record['kind']]
            assert checked['asset_sha256']==sha(asset) and checked['import_sha256']==sha(Path(str(asset)+'.import'))
        else:assert report['asset_sha256']==sha(asset)
        if name=='motion':
            assert report['test_sha256']==sha(ROOT/'Viewer/Presentation/DolphinMotionTests.gd') and report['recipe_sha256']==record['recipe_sha256']
            assert report['import_sha256']==sha(Path(str(asset)+'.import')) and len(report['samples'])==126
        if name=='materials':assert report['renderer']=='forward_plus'
        reports[name]=report
    return record,reports

def stage():
    record,_=verified_trial();record['status']='validated';record['native_validation']='pending isolated native Dolphin constructor/Jump checks'
    index=ROOT/'Viewer/local-art/creatures/accepted-index.json';data=read(index)
    data['entries']=[row for row in data['entries'] if row['kind']!=record['kind']]+[record];write(index,data)
    print('DOLPHIN LOCAL STAGE: exact presentation passed; native fixture pending; no public install')

def install():
    record,reports=verified_trial();live_path=ROOT/'outputs/creatures/dolphins/live.json';live=read(live_path)
    assert live['failures']==0 and live['checks']>=100 and len(live['records'])==2
    assert all(row['body']==151 and row['native_class']=='Dolphin' and row['native_water'] for row in live['records'])
    assert {row['female'] for row in live['records']}=={False,True}
    assert live_path.stat().st_mtime>(ROOT/'outputs/creatures/dolphin-trial/aquatic/validation.json').stat().st_mtime
    log=ROOT/'work/creatures/dolphin-native-final.log';text=log.read_text(encoding='utf-8-sig')
    assert 'SCRIPT ERROR:' not in text and 'ERROR:' not in text and 'Both random native dolphin breach variants are exercised' in text
    PUBLIC.mkdir(parents=True,exist_ok=True)
    if not (PUBLIC/'dolphin.glb').exists() or sha(PUBLIC/'dolphin.glb')!=sha(LOCAL/'dolphin.glb'):shutil.copyfile(LOCAL/'dolphin.glb',PUBLIC/'dolphin.glb')
    images=embedded_images(PUBLIC/'dolphin.glb')
    for name,data in images.items():
        target=PUBLIC/name
        if not target.exists() or target.read_bytes()!=data:target.write_bytes(data)
    record.update(status='validated',assets={'modern':'res://Art/Creatures/Dolphin/dolphin.glb'},native_validation='Actual isolated two-client Dolphin constructor, native Jump variants, wet movement, hurt, hues and corpse')
    index=PUBLIC.parent/'index.json';data=read(index);data['entries']=[row for row in data['entries'] if row['kind']!=record['kind']]+[record];write(index,data)
    private=ROOT/'Viewer/local-art/creatures/accepted-index.json';data=read(private);data['entries']=[row for row in data['entries'] if row['kind']!=record['kind']];write(private,data)
    write(PUBLIC/'provenance.json',{'sources':read(PINS),'export':read(LOCAL/'preparation.json'),'asset_sha256':sha(PUBLIC/'dolphin.glb'),'embedded_map_sha256':{name:hashlib.sha256(data).hexdigest() for name,data in images.items()},'map_policy':'Lossless byte copies of the five PNG members already embedded in the CC0-derived GLB; matches Godot extract mode.','presentation_runtime':reports['aquatic/validation']['runtime_sha256'],'interpretation':record['source_interpretation']})
    (PUBLIC/'NOTICE.txt').write_text('Bottlenose dolphin study mesh and embedded maps: Innerscene Corp, CC0-1.0.\nSource: '+read(PINS)['source']+'\nLicense: https://creativecommons.org/publicdomain/zero/1.0/\nExact original GLB SHA-256 and source URL are in provenance.json and scripts/dolphin-inputs.json.\nBritannia Reborn authored rig, skin weights, conversion, motions and shaders: GPL-3.0-or-later; see root LICENSE.\nFourteen action categories are authored replacements, not recovered Ultima Online choreography.\nNo original Ultima Online mesh, texture, rig or animation is included.\n',encoding='utf-8')
    print('DOLPHIN INSTALLED: independently licensed mesh/maps, authored rig/actions, measured and native gates passed')

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--verify-only',action='store_true');parser.add_argument('--candidate',action='store_true');parser.add_argument('--stage',action='store_true');parser.add_argument('--install',action='store_true');args=parser.parse_args()
    pins=inputs(args.verify_only)
    if args.candidate:candidate(pins)
    if args.stage:stage()
    if args.install:install()
if __name__=='__main__':main()
