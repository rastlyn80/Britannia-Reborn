"""Load the installed independent FireElemental in a clean, source-only project."""
import hashlib,json,os,re,shutil,subprocess,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
    target=(ROOT/'work/creatures/fire-distribution'/uuid.uuid4().hex).resolve();assert target.is_relative_to((ROOT/'work/creatures/fire-distribution').resolve());target.mkdir(parents=True)
    pending=['Presentation/FireElementalDistributionTests.gd'];copied=set();pattern=re.compile(r'(?:preload\s*\(|extends\s+|#include\s+)["\']res://([^"\']+)')
    while pending:
        relative=pending.pop()
        if relative in copied:continue
        assert not relative.startswith('local-art/')
        source=ROOT/'Viewer'/relative;assert source.is_file();destination=target/relative;destination.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,destination);copied.add(relative)
        if source.suffix in ['.gd','.gdshader','.gdshaderinc']:pending.extend(pattern.findall(source.read_text(encoding='utf-8-sig')))
    art=target/'Art/Creatures';art.mkdir(parents=True);shutil.copyfile(ROOT/'Viewer/Art/Creatures/index.json',art/'index.json');shutil.copytree(ROOT/'Viewer/Art/Creatures/Fire',art/'Fire')
    (target/'project.godot').write_text('[application]\nconfig/name="Isolated public FireElemental check"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    env=os.environ.copy();env['APPDATA']=env['LOCALAPPDATA']=str(ROOT/'.godot-user');godot=next((ROOT/'.tools/godot').glob('*console.exe'))
    for args in [['--editor','--import','--quit'],['--script','res://Presentation/FireElementalDistributionTests.gd']]:
        result=subprocess.run([str(godot),'--headless','--path',str(target),*args],env=env,capture_output=True,text=True,timeout=180);output=result.stdout+result.stderr
        (target/('import.log' if '--editor' in args else 'check.log')).write_text(output,encoding='utf-8');assert result.returncode==0 and 'ERROR:' not in output,output[-7000:]
        if '--script' in args:
            match=re.search(r'FIRE DISTRIBUTION: (\d+) / (\d+) checks; (\d+) complete skins',output);assert match and match[1]==match[2] and int(match[1])>=280 and int(match[3])==136,output
    receipt={'checks':int(match[2]),'failures':0,'component_skin_samples':int(match[3]),'transient_death_trials':4,'asset_sha256':hashlib.sha256((art/'Fire/fire-elemental.scn').read_bytes()).hexdigest(),'index_sha256':hashlib.sha256((ROOT/'Viewer/Art/Creatures/index.json').read_bytes()).hexdigest(),'runtime_sha256':{relative:hashlib.sha256((target/relative).read_bytes()).hexdigest() for relative in sorted(copied)},'runner_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'project':str(target.relative_to(ROOT))}
    (ROOT/'outputs/creatures/fire-trial/distribution.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print('FIRE DISTRIBUTION: actual standalone avatar, retained rig/actions, component skins, raw hues, static ash and four transient death cleanups; only independent FireElemental art, no private art/game input/server');print(target/'check.log')
if __name__=='__main__':main()
