"""Exercise the public independent hen without source files or game data."""
import hashlib,importlib.util,json,os,re,shutil,subprocess,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 target=(ROOT/'work/creatures/chicken-distribution'/uuid.uuid4().hex).resolve();assert target.is_relative_to((ROOT/'work/creatures/chicken-distribution').resolve());target.mkdir(parents=True)
 pending=['Presentation/ChickenDistributionTests.gd'];copied=set();pattern=re.compile(r'(?:preload\s*\(|extends\s+|#include\s+)["\']res://([^"\']+)')
 while pending:
  relative=pending.pop()
  if relative in copied:continue
  assert not relative.startswith('local-art/');source=ROOT/'Viewer'/relative;assert source.is_file();destination=target/relative;destination.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,destination);copied.add(relative)
  if source.suffix in ['.gd','.gdshader','.gdshaderinc']:pending.extend(pattern.findall(source.read_text(encoding='utf-8-sig')))
 art=target/'Art/Creatures';art.mkdir(parents=True);shutil.copyfile(ROOT/'Viewer/Art/Creatures/index.json',art/'index.json');chicken=art/'Chicken';chicken.mkdir()
 # Start from the published payload only: Godot must extract embedded maps itself.
 payload=['chicken.glb','chicken.glb.import','NOTICE.txt','SOURCE-LICENSE.txt','provenance.json']
 for name in payload:shutil.copyfile(ROOT/'Viewer/Art/Creatures/Chicken'/name,chicken/name)
 assert not list(chicken.glob('*.png')) and not list(chicken.glob('*.png.import'))
 (target/'project.godot').write_text('[application]\nconfig/name="Isolated public hen check"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
 env=os.environ.copy();env['APPDATA']=env['LOCALAPPDATA']=str(ROOT/'.godot-user');godot=next((ROOT/'.tools/godot').glob('*console.exe'))
 def run(label,args):
  result=subprocess.run([str(godot),'--headless','--path',str(target),*args],env=env,capture_output=True,text=True,timeout=240);output=result.stdout+result.stderr;(target/(label+'.log')).write_text(output,encoding='utf-8');assert result.returncode==0 and 'ERROR:' not in output,output[-6000:];return output
 run('import',['--editor','--import','--quit']);spec=importlib.util.spec_from_file_location('chicken_distribution_configuration',ROOT/'scripts/prepare-chicken.py');config=importlib.util.module_from_spec(spec);spec.loader.exec_module(config);config.configure(art/'Chicken/chicken.glb.import');run('precision',['--editor','--import','--quit']);output=run('check',['--script','res://Presentation/ChickenDistributionTests.gd']);match=re.search(r'CHICKEN DISTRIBUTION: (\d+) / (\d+); (\d+) complete skins',output);assert match and match[1]==match[2] and int(match[1])>500 and int(match[3])==171
 receipt={'checks':int(match[1]),'failures':0,'complete_skins':171,'asset_sha256':sha(art/'Chicken/chicken.glb'),'index_sha256':sha(art/'index.json'),'runner_sha256':sha(Path(__file__)),'runtime_sha256':{p:sha(ROOT/'Viewer'/p) for p in sorted(copied)},'scope':'Actual standalone avatar/source clips/authored categories, positive normalized skins/PBR maps, raw native hues, finite bounds/gaits and all static corpse components; no original blend/maps, private art, game data or server.'};path=ROOT/'outputs/creatures/chicken-trial/distribution.json';path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(receipt,indent=2)+'\n');print('CHICKEN DISTRIBUTION:',match[1],'checks/171 skins, no private art, donor, game inputs or server');print(target/'check.log')
if __name__=='__main__':main()
