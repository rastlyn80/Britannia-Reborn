"""Run the public water actor in a source-only project, with no private artwork."""
import argparse,json,os,re,runpy,shutil,subprocess,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--candidate-reactions',action='store_true');args=parser.parse_args()
 target=(ROOT/'work/creatures/water-distribution'/uuid.uuid4().hex).resolve()
 assert target.is_relative_to((ROOT/'work/creatures/water-distribution').resolve());target.mkdir(parents=True)
 pending=['Presentation/WaterElementalDistributionTests.gd'];copied=set()
 pattern=re.compile(r'(?:preload\s*\(|extends\s+|#include\s+)["\']res://([^"\']+)')
 while pending:
  relative=pending.pop()
  if relative in copied:continue
  assert not relative.startswith('local-art/')
  source=ROOT/'Viewer'/relative;destination=target/relative;destination.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,destination);copied.add(relative)
  if source.suffix in ['.gd','.gdshader','.gdshaderinc']:pending.extend(pattern.findall(source.read_text(encoding='utf-8-sig')))
 shutil.copytree(ROOT/'Viewer/Art/Creatures',target/'Art/Creatures')
 index=target/'Art/Creatures/index.json'
 data=json.loads(index.read_text(encoding='utf-8'))
 water=next(row for row in data['entries'] if row['kind']=='water_elemental')
 if args.candidate_reactions:
  workflow=runpy.run_path(str(ROOT/'scripts/prepare-water-reactions.py'))
  trial,=workflow['prepared']()[0]
  source=ROOT/'Viewer'/trial['assets']['modern'].removeprefix('res://')
  relative='Art/Creatures/Water/water-reactions.scn'
  shutil.copyfile(source,target/relative)
  water.update(trial,status='validated',assets={'modern':'res://'+relative})
  index.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
 checks=25 if '15' in water['classic_action_categories'] else 17
 (target/'project.godot').write_text('[application]\nconfig/name="Isolated public water check"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
 env=os.environ.copy();env['APPDATA']=env['LOCALAPPDATA']=str(ROOT/'.godot-user');godot=next((ROOT/'.tools/godot').glob('*console.exe'))
 for args in [['--editor','--import'],['--script','res://Presentation/WaterElementalDistributionTests.gd']]:
  result=subprocess.run([str(godot),'--headless','--path',str(target),*args],env=env,capture_output=True,text=True,timeout=120)
  output=result.stdout+result.stderr;(target/('import.log' if '--editor' in args else 'check.log')).write_text(output,encoding='utf-8')
  assert result.returncode==0 and 'ERROR:' not in output,output
  if '--script' in args:assert f'WATER DISTRIBUTION: {checks} / {checks}' in output,output
 print(f'WATER DISTRIBUTION: {checks} clean checks; no local-art, original CC0 source imports, game inputs or server')
 print(target/'check.log')
if __name__=='__main__':main()
