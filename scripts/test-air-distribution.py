"""Load the installed independent AirElemental in a clean, source-only project."""
import os,re,shutil,subprocess,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
    target=(ROOT/'work/creatures/air-distribution'/uuid.uuid4().hex).resolve();assert target.is_relative_to((ROOT/'work/creatures/air-distribution').resolve());target.mkdir(parents=True)
    pending=['Presentation/AirElementalDistributionTests.gd'];copied=set();pattern=re.compile(r'(?:preload\s*\(|extends\s+|#include\s+)["\']res://([^"\']+)')
    while pending:
        relative=pending.pop()
        if relative in copied:continue
        assert not relative.startswith('local-art/')
        source=ROOT/'Viewer'/relative;assert source.is_file();destination=target/relative;destination.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,destination);copied.add(relative)
        if source.suffix in ['.gd','.gdshader','.gdshaderinc']:pending.extend(pattern.findall(source.read_text(encoding='utf-8-sig')))
    art=target/'Art/Creatures';art.mkdir(parents=True);shutil.copyfile(ROOT/'Viewer/Art/Creatures/index.json',art/'index.json');shutil.copytree(ROOT/'Viewer/Art/Creatures/Air',art/'Air')
    (target/'project.godot').write_text('[application]\nconfig/name="Isolated public AirElemental check"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    env=os.environ.copy();env['APPDATA']=env['LOCALAPPDATA']=str(ROOT/'.godot-user');godot=next((ROOT/'.tools/godot').glob('*console.exe'))
    for args in [['--editor','--import','--quit'],['--script','res://Presentation/AirElementalDistributionTests.gd']]:
        result=subprocess.run([str(godot),'--headless','--path',str(target),*args],env=env,capture_output=True,text=True,timeout=180);output=result.stdout+result.stderr
        (target/('import.log' if '--editor' in args else 'check.log')).write_text(output,encoding='utf-8');assert result.returncode==0 and 'ERROR:' not in output,output[-7000:]
        if '--script' in args:
            match=re.search(r'AIR DISTRIBUTION: (\d+) / (\d+) checks; (\d+) complete skins',output);assert match and match[1]==match[2] and int(match[1])>=293 and int(match[3])==136,output
    print('AIR DISTRIBUTION: actual standalone avatar, retained rig/actions, complete skins, raw hues and static dry-dust corpse; only independent AirElemental art, no private art/game input/server');print(target/'check.log')
if __name__=='__main__':main()
