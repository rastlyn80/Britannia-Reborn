"""Exercise the shipped cat in a new project without original/private inputs."""
import json,os,re,shutil,subprocess,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
    target=(ROOT/'work/creatures/cat-distribution'/uuid.uuid4().hex).resolve()
    assert target.is_relative_to((ROOT/'work/creatures/cat-distribution').resolve());target.mkdir(parents=True)
    pending=['Presentation/CatDistributionTests.gd'];copied=set();pattern=re.compile(r'(?:preload\s*\(|extends\s+|#include\s+)["\']res://([^"\']+)')
    if (ROOT/'Viewer/Art/Creatures/Cat/cat-actions.scn').is_file():
        entries=json.loads((ROOT/'Viewer/Art/Creatures/index.json').read_text(encoding='utf-8-sig'))['entries']
        cat=next(row for row in entries if row['kind']=='cat_domestic')
        pending.append(cat['presentation_script'].removeprefix('res://'))
    while pending:
        relative=pending.pop()
        if relative in copied:continue
        assert not relative.startswith('local-art/')
        source=ROOT/'Viewer'/relative;destination=target/relative;destination.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,destination);copied.add(relative)
        if source.suffix in ['.gd','.gdshader','.gdshaderinc']:pending.extend(pattern.findall(source.read_text(encoding='utf-8-sig')))
    shutil.copytree(ROOT/'Viewer/Art/Creatures',target/'Art/Creatures')
    (target/'project.godot').write_text('[application]\nconfig/name="Isolated public cat check"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
    env=os.environ.copy();env['APPDATA']=env['LOCALAPPDATA']=str(ROOT/'.godot-user');godot=next((ROOT/'.tools/godot').glob('*console.exe'))
    for args in [['--editor','--import'],['--script','res://Presentation/CatDistributionTests.gd']]:
        result=subprocess.run([str(godot),'--headless','--path',str(target),*args],env=env,capture_output=True,text=True,timeout=180)
        output=result.stdout+result.stderr;(target/('import.log' if '--editor' in args else 'check.log')).write_text(output,encoding='utf-8')
        assert result.returncode==0 and 'ERROR:' not in output,output
        if '--script' in args:
            match=re.search(r'CAT DISTRIBUTION: (\d+) / (\d+)',output);assert match and match[1]==match[2] and int(match[1])>=470,output
    print('CAT DISTRIBUTION: clean actual avatar, eight-influence skins, speed-adapted gaits and static corpse; no local-art, source imports or server');print(target/'check.log')
if __name__=='__main__':main()
