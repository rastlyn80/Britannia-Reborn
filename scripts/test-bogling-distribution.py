"""Run the shipped Bogling in an isolated source-only project."""
import hashlib,json,os,re,shutil,subprocess,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
 target=ROOT/'work/creatures/bogling-distribution'/uuid.uuid4().hex;target.mkdir(parents=True)
 data=json.loads((ROOT/'Viewer/Art/Creatures/index.json').read_text())
 data['entries']=[r for r in data['entries'] if r['kind']=='bogling'];assert len(data['entries'])==1
 row,=data['entries'];extra='additional_animation_library' in row
 pending=['Presentation/BoglingDistributionTests.gd'];copied=set();pattern=re.compile(r'(?:preload\s*\(|extends\s+|#include\s+)["\']res://([^"\']+)')
 if extra:
  pending.append(row['presentation_script'].removeprefix('res://'))
 while pending:
  relative=pending.pop()
  if relative in copied:continue
  assert not relative.startswith('local-art/')
  source=ROOT/'Viewer'/relative;destination=target/relative;destination.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,destination);copied.add(relative)
  if source.suffix in ['.gd','.gdshader','.gdshaderinc']:pending.extend(pattern.findall(source.read_text(encoding='utf-8-sig')))
 art=target/'Art/Creatures';art.mkdir(parents=True)
 (art/'index.json').write_text(json.dumps(data));(art/'Bogling').mkdir()
 files=['bogling.glb','bogling.glb.import','NOTICE.txt','provenance.json']
 if extra:files+=['distinct-actions.res','distinct-actions-provenance.json']
 for name in files:shutil.copyfile(ROOT/'Viewer/Art/Creatures/Bogling'/name,art/'Bogling'/name)
 (target/'project.godot').write_text('[application]\nconfig/name="Independent public Bogling check"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
 env=os.environ.copy();env['APPDATA']=env['LOCALAPPDATA']=str(ROOT/'.godot-user');godot=next((ROOT/'.tools/godot').glob('*console.exe'))
 for args in [['--editor','--import','--quit'],['--script','res://Presentation/BoglingDistributionTests.gd']]:
  result=subprocess.run([str(godot),'--headless','--path',str(target),*args],env=env,capture_output=True,text=True,timeout=180);output=result.stdout+result.stderr
  (target/('import.log' if '--editor' in args else 'check.log')).write_text(output,encoding='utf-8');assert result.returncode==0 and 'ERROR:' not in output,output[-6000:]
  if '--script' in args:
   match=re.search(r'BOGLING DISTRIBUTION: (\d+) / (\d+) checks; (\d+) complete skins',output);assert match and match[1]==match[2] and int(match[1])>=470 and int(match[3])==(171 if extra else 153),output
 receipt={'checks':int(match[2]),'failures':0,'complete_skins':int(match[3]),'asset_sha256':hashlib.sha256((art/'Bogling/bogling.glb').read_bytes()).hexdigest(),'index_sha256':hashlib.sha256((ROOT/'Viewer/Art/Creatures/index.json').read_bytes()).hexdigest(),'runtime_sha256':{relative:hashlib.sha256((target/relative).read_bytes()).hexdigest() for relative in sorted(copied)},'runner_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'project':str(target.relative_to(ROOT))}
 (ROOT/'outputs/creatures/bogling-trial/distribution.json').write_text(json.dumps(receipt,indent=2)+'\n')
 print('BOGLING DISTRIBUTION: actual independent avatar/maps/actions/skins/raw hue/static corpse; no original donor, private art, game palette or server');print(target/'check.log')
if __name__=='__main__':main()
