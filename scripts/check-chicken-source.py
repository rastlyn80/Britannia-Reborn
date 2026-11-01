"""Compare actual imported full skins with independently evaluated CC0 source."""
import hashlib,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];BASE=ROOT/'work/creatures/chicken';OUT=ROOT/'outputs/creatures/chicken-trial';TRIAL=BASE;CELL=.003
source=json.loads((TRIAL/'source-reference.json').read_text());imported=json.loads((OUT/'source-skins.json').read_text())
def key(p):return tuple(math.floor(v/CELL) for v in p)
def directed(a,b):
 grid={}
 for p in b:grid.setdefault(key(p),[]).append(p)
 errors=[]
 for p in a:
  k=key(p);near=[q for dx in [-1,0,1] for dy in [-1,0,1] for dz in [-1,0,1] for q in grid.get((k[0]+dx,k[1]+dy,k[2]+dz),[])]
  if not near:near=b
  errors.append(math.sqrt(min(sum((x-y)**2 for x,y in zip(p,q)) for q in near)))
 return max(errors),sum(e*e for e in errors),len(errors)
rows=[]
assert imported['failures']==0 and imported['bones']==47 and imported['meshes']==2
assert len(source['samples'])==len(imported['samples'])==187
assert source['source_pin_sha256']==hashlib.sha256((ROOT/'scripts/chicken-inputs.json').read_bytes()).hexdigest()
assert source['recipe_sha256']==hashlib.sha256((ROOT/'scripts/blender-reference-chicken.py').read_bytes()).hexdigest()
assert imported['asset_sha256']==hashlib.sha256((ROOT/'Viewer/local-art/chicken/chicken-modern.glb').read_bytes()).hexdigest()
assert imported['test_sha256']==hashlib.sha256((ROOT/'Viewer/Presentation/ChickenSourceTests.gd').read_bytes()).hexdigest()
assert imported['import_sha256']==hashlib.sha256((ROOT/'Viewer/local-art/chicken/chicken-modern.glb.import').read_bytes()).hexdigest()
for target in imported['samples']:
 row=next(s for s in source['samples'] if target['clip'].removeprefix('Armature|')==s['clip'] and abs(s['phase']-target['phase'])<1e-6)
 forward=directed(row['points'],target['points']);reverse=directed(target['points'],row['points']);rms=math.sqrt((forward[1]+reverse[1])/(forward[2]+reverse[2]))
 delta=[x-y for x,y in zip(target['bones']['Main'],row['bones']['Main'])];aligned=[[x-y for x,y in zip(p,delta)] for p in target['points']]
 aligned_forward=directed(row['points'],aligned);aligned_reverse=directed(aligned,row['points'])
 rows.append({'clip':row['clip'],'phase':row['phase'],'source_to_imported_max_m':forward[0],'imported_to_source_max_m':reverse[0],'symmetric_rms_m':rms,'imported_floor_m':target['floor_y'],'root_translation_difference_m':delta,'relative_skin_max_m':max(aligned_forward[0],aligned_reverse[0])})
worst=max(max(r['source_to_imported_max_m'],r['imported_to_source_max_m']) for r in rows)
failures=sum(1 for r in rows if max(r['source_to_imported_max_m'],r['imported_to_source_max_m'],r['relative_skin_max_m'])>=.001)
result={'failures':failures,'checks':len(rows)*3,'reference_recipe_sha256':source['recipe_sha256'],'test_sha256':imported['test_sha256'],'comparison_recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'import_sha256':imported['import_sha256'],'samples':rows,'max_surface_difference_m':worst,'max_relative_skin_difference_m':max(r['relative_skin_max_m'] for r in rows),'max_rms_m':max(r['symmetric_rms_m'] for r in rows),'minimum_floor_m':min(r['imported_floor_m'] for r in rows),'source_reference_sha256':hashlib.sha256((TRIAL/'source-reference.json').read_bytes()).hexdigest(),'imported_samples_sha256':hashlib.sha256((OUT/'source-skins.json').read_bytes()).hexdigest(),'asset_sha256':hashlib.sha256((ROOT/'Viewer/local-art/chicken/chicken-modern.glb').read_bytes()).hexdigest(),'scope':'Private independent source skin comparison; separate whole-root/floor translation and relative-skin deformation; no native acceptance.'}
(OUT/'source.json').write_text(json.dumps(result,indent=2)+'\n')
print('CHICKEN SOURCE SURFACES',len(rows),'max difference',worst,'relative skin',result['max_relative_skin_difference_m'],'RMS',result['max_rms_m'],'min floor',result['minimum_floor_m'])

assert failures==0,"Independent source deformation exceeded1mm"
