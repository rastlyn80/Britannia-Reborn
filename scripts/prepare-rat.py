"""Pinned independent rat inputs and evidence-gated installation."""
import argparse,hashlib,json,re,shutil,subprocess,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
PINS=ROOT/'scripts/rat-inputs.json';WORK=ROOT/'work/creatures/rat-cc0';LOCAL=ROOT/'Viewer/local-art/rat';PUBLIC=ROOT/'Viewer/Art/Creatures/Rat';OUT=ROOT/'outputs/creatures/rat-trial'
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path,value):path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
def resource(path):
    assert path.startswith('res://')
    result=(ROOT/'Viewer'/path[6:]).resolve();assert result.is_relative_to(ROOT);return result
def inputs(verify_only):
    pins=read(PINS);WORK.mkdir(parents=True,exist_ok=True);archive=WORK/'rat_source.7z'
    if not archive.exists():
        assert not verify_only,'Pinned rat source missing'
        with urllib.request.urlopen(pins['download'],timeout=60) as response:raw=response.read(pins['archive_bytes']+1)
        assert len(raw)==pins['archive_bytes'] and hashlib.sha256(raw).hexdigest()==pins['archive_sha256'];archive.write_bytes(raw)
    assert archive.stat().st_size==pins['archive_bytes'] and sha(archive)==pins['archive_sha256']
    folder=WORK/'source';folder.mkdir(exist_ok=True)
    if any(not (folder/pin['member']).exists() for pin in pins['files']):
        assert not verify_only
        subprocess.run(['tar','-xf',str(archive),'-C',str(folder),*[pin['member'] for pin in pins['files']]],check=True)
    for pin in pins['files']:
        assert re.fullmatch(r'rat\.(blend|png)',pin['member'])
        path=folder/pin['member'];assert path.stat().st_size==pin['bytes'] and sha(path)==pin['sha256']
    return pins
def candidate(pins):
    prep=read(LOCAL/'preparation.json');motion=read(OUT/'motion.json');asset=LOCAL/'rat-modern.glb'
    assert prep['recipe_sha256']==sha(ROOT/'scripts/blender-prepare-rat.py')==motion['recipe_sha256']
    assert motion['failures']==0 and motion['checks']>=700 and len(motion['samples'])==260
    assert motion['test_sha256']==sha(ROOT/'Viewer/Presentation/RatMotionTests.gd') and motion['preparation_sha256']==sha(LOCAL/'preparation.json')
    assert motion['assets']['modern']['sha256']==sha(asset)==prep['treatments']['modern']['asset_sha256']
    assert motion['assets']['modern']['import_sha256']==sha(Path(str(asset)+'.import'))
    native='Projects/UOContent/Mobiles/Animals/Town Critters/Rat.cs';path=ROOT/'Server/ModernUO'/native
    assignment=re.search(r'\bBody\s*=\s*(\d+)\s*;',path.read_text(encoding='utf-8-sig'));assert assignment and int(assignment[1])==238
    bounds=motion['envelope'];clips=prep['treatments']['modern']['clips'];stats={'bones':21,'height_m':.15,'bind_diagonal_m':.55,'clips':clips}
    record={'kind':'rat_ordinary','family':'ordinary_rats','status':'candidate','profile':'animal','contact_kind':'rat_legs','surface_kind':'fur_pbr','head_bone':'head',
        'assets':{'modern':'res://local-art/rat/rat-modern.glb','original':'res://local-art/rat/rat-source.glb'},
        'bodies':[{'body':238,'scale':[1,1,1],'name':'Rat','native_profile':'animal','native_sources':[{'path':native,'sha256':sha(path)}]}],
        'source':pins['source'],'license':'CC0-1.0 source mesh/rig/map/five clips; GPL-3.0-or-later authored conversion, refinement and additional actions',
        'source_interpretation':'Independent br-n518 rat, 21-bone evaluated constraint bake; five licensed source categories plus five declared authored categories. Refined silhouette, explicit gait closure and actual-skin floor correction. No recovered UO choreography.',
        'partial_hue_interpretation':'Authored fur-only partial tint; pink ears/nose/tail and dark eyes protected. Not a recovered UO partial mask.',
        'stats':{'original':stats,'modern':stats},'authored_replacements':{name:info['origin'] for name,info in clips.items()},
        'camera_height':.15,'pick_bounds':{'position':[v-.01 for v in bounds['position']],'size':[v+.02 for v in bounds['size']]},
        'recipe_sha256':prep['recipe_sha256'],'source_pin_sha256':sha(PINS)}
    write(LOCAL/'candidate.json',record);print('RAT CANDIDATE: real native238, measured260skins; not installed')
def verified_trial():
    record=read(LOCAL/'candidate.json');prep=read(LOCAL/'preparation.json');asset=resource(record['assets']['modern'])
    assert record['source_pin_sha256']==sha(PINS) and record['recipe_sha256']==prep['recipe_sha256']==sha(ROOT/'scripts/blender-prepare-rat.py')
    motion=read(OUT/'motion.json');presentation=read(OUT/'presentation.json')
    assert motion['failures']==0 and motion['checks']>=700 and len(motion['samples'])==260
    assert motion['assets']['modern']['sha256']==sha(asset)==prep['treatments']['modern']['asset_sha256'] and motion['preparation_sha256']==sha(LOCAL/'preparation.json')
    assert motion['assets']['modern']['import_sha256']==sha(Path(str(asset)+'.import')) and motion['test_sha256']==sha(ROOT/'Viewer/Presentation/RatMotionTests.gd')
    assert presentation['failures']==0 and presentation['checks']>=100 and len(presentation['terrain'])==18 and presentation['renderer']=='forward_plus'
    assert presentation['asset_sha256']==sha(asset) and presentation['import_sha256']==sha(Path(str(asset)+'.import')) and presentation['candidate_sha256']==sha(LOCAL/'candidate.json')
    for path,digest in presentation['runtime_sha256'].items():assert sha(resource(path))==digest,'Stale rat evidence: '+path
    return record,presentation
def stage():
    record,_=verified_trial();record.update(status='validated',native_validation='Pending isolated native Rat constructor checks')
    path=ROOT/'Viewer/local-art/creatures/accepted-index.json';data=read(path);data['entries']=[row for row in data['entries'] if row['kind']!=record['kind']]+[record];write(path,data)
    print('RAT LOCAL STAGE: measured donor accepted for native tests only')
def install():
    record,presentation=verified_trial();path=ROOT/'outputs/creatures/ordinary_rats/live.json';live=read(path)
    assert live['failures']==0 and live['checks']>=70 and len(live['records'])==2
    assert all(row['body']==238 and row['native_class']=='Rat' for row in live['records']) and {row['female'] for row in live['records']}=={False,True}
    assert path.stat().st_mtime>(OUT/'presentation.json').stat().st_mtime
    PUBLIC.mkdir(parents=True,exist_ok=True);shutil.copyfile(resource(record['assets']['modern']),PUBLIC/'rat.glb')
    # Godot's extract mode names this single embedded image rat_rat.png.
    # It is an unchanged byte copy, not a generated or recoloured atlas.
    atlas=WORK/'source/rat.png';atlas_pin=next(row for row in read(PINS)['files'] if row['member']=='rat.png')
    assert sha(atlas)==atlas_pin['sha256']
    companion=PUBLIC/'rat_rat.png'
    if not companion.exists() or sha(companion)!=sha(atlas):shutil.copyfile(atlas,companion)
    record.update(status='validated',assets={'modern':'res://Art/Creatures/Rat/rat.glb'},native_validation='Actual isolated two-client native Rat constructor, movement, hues, actions, hurt and corpse')
    index=PUBLIC.parent/'index.json';data=read(index);data['entries']=[row for row in data['entries'] if row['kind']!=record['kind']]+[record];write(index,data)
    private=ROOT/'Viewer/local-art/creatures/accepted-index.json';data=read(private);data['entries']=[row for row in data['entries'] if row['kind']!=record['kind']];write(private,data)
    write(PUBLIC/'provenance.json',{'sources':read(PINS),'preparation':read(LOCAL/'preparation.json'),'asset_sha256':sha(PUBLIC/'rat.glb'),'embedded_map_sha256':{'rat_rat.png':sha(companion)},'runtime_sha256':presentation['runtime_sha256']})
    (PUBLIC/'NOTICE.txt').write_text('Ordinary rat mesh, rig, atlas and original five clips: br-n518, CC0-1.0.\nSource: https://opengameart.org/content/rat-0\nLicense: https://creativecommons.org/publicdomain/zero/1.0/\nExact input hashes: scripts/rat-inputs.json and provenance.json.\nBritannia Reborn conversion, refinement, additional categories and shaders: GPL-3.0-or-later; root LICENSE.\nFive additional motions and gait/floor corrections are authored. No original UO geometry, map, rig or motion is included.\n',encoding='utf-8')
    print('RAT INSTALLED: independent licensed bundle; final public checks remain required')
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ['verify-only','candidate','stage','install']:parser.add_argument('--'+name,action='store_true')
    args=parser.parse_args();pins=inputs(args.verify_only)
    if args.candidate:candidate(pins)
    if args.stage:stage()
    if args.install:install()
if __name__=='__main__':main()
