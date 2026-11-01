"""Evidence gates for the independently authored Wisp, with no external art input."""
import argparse,hashlib,json,re,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];LOCAL=ROOT/'Viewer/local-art/wisp';OUT=ROOT/'outputs/creatures/wisp-trial';PUBLIC=ROOT/'Viewer/Art/Creatures/Wisp'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,value):
    p.parent.mkdir(parents=True,exist_ok=True);pending=p.with_suffix(p.suffix+'.pending');pending.write_text(json.dumps(value,indent=2)+'\n');pending.replace(p)
def resource(p):
    assert p.startswith('res://');path=(ROOT/'Viewer'/p[6:]).resolve();assert path.is_relative_to(ROOT/'Viewer');return path
def motion():
    prep=read(LOCAL/'preparation.json');proof=read(OUT/'motion.json')
    assert prep['bones']==7 and prep['triangles']==4480 and len(prep['clips'])==16
    assert proof['failures']==0 and proof['checks']>=1586 and proof['complete_skins']==1408
    assert proof['asset_sha256']==sha(LOCAL/'wisp-modern.scn') and proof['recipe_sha256']==sha(ROOT/'Viewer/Presentation/PrepareWisp.gd')
    assert proof['test_sha256']==sha(ROOT/'Viewer/Presentation/WispMotionTests.gd') and proof['preparation_sha256']==sha(LOCAL/'preparation.json')
    return prep,proof
def candidate():
    prep,proof=motion();pin=read(ROOT/'Server/dependencies.json')['modernuo']['revision']
    assert subprocess.check_output(['git','-C',str(ROOT/'Server/ModernUO'),'rev-parse','HEAD'],text=True).strip()==pin
    sources=[]
    for name in ['Projects/UOContent/Mobiles/Monsters/Misc/Magic/Wisp.cs','Projects/UOContent/Mobiles/Monsters/ML/Prism of Light/CrystalWisp.cs']:
        sources.append({'path':name,'sha256':sha(ROOT/'Server/ModernUO'/name)})
    assert re.search(r'\bBody\s*=\s*58\s*;',resource_path_text(sources[0]))
    crystal=resource_path_text(sources[1]);assert 'class CrystalWisp : Wisp' in crystal and 'Hue = 0x482;' in crystal and not re.search(r'\bBody\s*=',crystal)
    lo=[min(s['position'][i] for s in proof['samples'])-.03 for i in range(3)];hi=[max(s['position'][i]+s['size'][i] for s in proof['samples'])+.03 for i in range(3)]
    clips=prep['clips'];stats={'bones':7,'height_m':.9,'clips':clips}
    record={'kind':'wisp','family':'wisps','status':'candidate','profile':'monster','movement_mode':'source_hover','surface_kind':'authored_energy',
        'assets':{'modern':'res://local-art/wisp/wisp-modern.scn'},'bodies':[{'body':58,'name':'Wisp / CrystalWisp','scale':[1,1,1],'native_profile':'monster','native_sources':sources}],
        'source':'https://github.com/rastlyn80/Britannia-Reborn','license':'GPL-3.0-or-later original analytic geometry, seven-bone rig, sixteen authored action categories and shader. No game-derived art or external asset.',
        'source_interpretation':'Authored three-dimensional radiant star-core with six distinct skinned rays. Named Third Dawn Wisp model absent from this inspected archive; no recovered source mesh/rig/choreography claimed.',
        'partial_hue_interpretation':'Authored white-core protection with tinted energy rays, not a recovered native partial mask.',
        'stats':{'original':stats,'modern':stats},'authored_replacements':{k:v['origin'] for k,v in clips.items()},'loop_categories':[k for k,v in clips.items() if v['loop']],
        'camera_height':1.0,'pick_bounds':{'position':lo,'size':[hi[i]-lo[i] for i in range(3)]},'new_action_categories':{'2':'Hit','5':'Fidget','14':'Pillage'},
        'recipe_sha256':proof['recipe_sha256'],'asset_sha256':proof['asset_sha256']}
    write(LOCAL/'candidate.json',record);print('WISP CANDIDATE: complete authored skins; no route installed')
def resource_path_text(source):return (ROOT/'Server/ModernUO'/source['path']).read_text(encoding='utf-8-sig')
def gated():
    motion();record=read(LOCAL/'candidate.json');proof=read(OUT/'presentation.json')
    assert record['recipe_sha256']==sha(ROOT/'Viewer/Presentation/PrepareWisp.gd') and record['asset_sha256']==sha(resource(record['assets']['modern']))
    assert proof['failures']==0 and proof['checks']>=566 and len(proof['terrain'])==72 and proof['renderer']=='forward_plus'
    assert proof['candidate_sha256']==sha(LOCAL/'candidate.json') and proof['asset_sha256']==record['asset_sha256']
    for path,digest in proof['runtime_sha256'].items():assert sha(resource(path))==digest,'Stale Wisp presenter evidence: '+path
    assert len(proof['hues'])==3 and all(row['changed_pixels']>80 for row in proof['hues'])
    for source in record['bodies'][0]['native_sources']:assert sha(ROOT/'Server/ModernUO'/source['path'])==source['sha256']
    return record,proof
def stage():
    record,_=gated();record.update(status='validated',native_validation='Actual candidate avatar/skin/effect/hover/corpse proved; both native constructors pending')
    p=ROOT/'Viewer/local-art/creatures/accepted-index.json';data=read(p)
    assert all(row['kind']=='wisp' or all(int(b['body'])!=58 for b in row['bodies']) for row in data['entries'])
    data['entries']=[row for row in data['entries'] if row['kind']!='wisp']+[record];write(p,data);print('WISP STAGED: candidate visual proof passed; native identity checks pending')
def live():
    p=ROOT/'outputs/creatures/wisps/live.json';proof=read(p)
    assert proof['failures']==0 and proof['checks']>=180
    assert {(r['body'],r['native_class'],r['female']) for r in proof['records']}=={(58,name,sex) for name in ['Wisp','CrystalWisp'] for sex in [False,True]}
    return proof
def install():
    record,proof=gated();native=live();assert (ROOT/'outputs/creatures/wisps/live.json').stat().st_mtime>(OUT/'presentation.json').stat().st_mtime
    PUBLIC.mkdir(parents=True,exist_ok=True);shutil.copyfile(resource(record['assets']['modern']),PUBLIC/'wisp.scn')
    record.update(status='validated',assets={'modern':'res://Art/Creatures/Wisp/wisp.scn'},native_validation='Actual isolated Wisp and CrystalWisp constructors, two clients, native actions/hues/movement/death/corpse; repeat on installed public route')
    p=PUBLIC.parent/'index.json';data=read(p);data['entries']=[r for r in data['entries'] if r['kind']!='wisp']+[record];write(p,data)
    p=ROOT/'Viewer/local-art/creatures/accepted-index.json';data=read(p);data['entries']=[r for r in data['entries'] if r['kind']!='wisp'];write(p,data)
    write(PUBLIC/'provenance.json',{'license':'GPL-3.0-or-later original project art/code; no third-party or game-derived mesh, rig, texture or animation','preparation':read(LOCAL/'preparation.json'),'asset_sha256':sha(PUBLIC/'wisp.scn'),'recipe_sha256':record['recipe_sha256'],'shader_sha256':sha(ROOT/'Viewer/Presentation/WispSurface.gdshader'),'runtime_sha256':proof['runtime_sha256']})
    (PUBLIC/'NOTICE.txt').write_text('Independently authored Britannia Reborn Wisp analytic mesh, seven-bone rig, sixteen action categories and energy shader. GPL-3.0-or-later; see root LICENSE.\nNo Ultima Online mesh, rig, texture or motion and no external donor asset is included.\nReproduce with Viewer/Presentation/PrepareWisp.gd. Exact source/art hashes: provenance.json. Original UO choreography and exact partial masks are not claimed.\n')
    print('WISP PUBLIC BUNDLE INSTALLED: repeat public avatar/native/distribution proof before publishing')
def verify_public():
    _,source=motion();record=next(r for r in read(PUBLIC.parent/'index.json')['entries'] if r['kind']=='wisp');proof=read(OUT/'presentation.json');native=live();provenance=read(PUBLIC/'provenance.json')
    assert record['status']=='validated' and record['assets']['modern']=='res://Art/Creatures/Wisp/wisp.scn'
    assert sha(PUBLIC/'wisp.scn')==record['asset_sha256']==source['asset_sha256']==proof['asset_sha256']==provenance['asset_sha256']
    assert proof['candidate_sha256']==sha(PUBLIC.parent/'index.json') and proof['failures']==0 and proof['checks']>=566 and len(proof['terrain'])==72
    for path,digest in proof['runtime_sha256'].items():assert sha(resource(path))==digest,'Stale public Wisp proof: '+path
    assert (ROOT/'outputs/creatures/wisps/live.json').stat().st_mtime>(OUT/'presentation.json').stat().st_mtime
    assert provenance['recipe_sha256']==sha(ROOT/'Viewer/Presentation/PrepareWisp.gd') and provenance['shader_sha256']==sha(ROOT/'Viewer/Presentation/WispSurface.gdshader')
    print('WISP PUBLIC VERIFIED: exact independent scene/recipe/shader, installed avatar/hover/hues/static corpse and both native classes')
def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ['candidate','stage','install','verify-public']:p.add_argument('--'+name,action='store_true')
    a=p.parse_args()
    if a.candidate:candidate()
    if a.stage:stage()
    if a.install:install()
    if a.verify_public:verify_public()
if __name__=='__main__':main()
