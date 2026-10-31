"""Check the bundled bird in a disposable source-only Godot project without local art."""
import os, re, shutil, subprocess, uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def main():
    target=(ROOT/'work/birds/distribution'/uuid.uuid4().hex).resolve()
    assert target.is_relative_to((ROOT/'work/birds/distribution').resolve())
    target.mkdir(parents=True)
    pending=['Presentation/BirdDistributionTests.gd'];copied=set()
    # Follow only compile-time dependencies. Optional private runtime paths
    # remain absent; nothing is moved out of the shared working project.
    pattern=re.compile(r'(?:preload\s*\(|extends\s+|#include\s+)["\']res://([^"\']+)')
    while pending:
        relative=pending.pop()
        if relative in copied:continue
        assert not relative.startswith('local-art/')
        source=ROOT/'Viewer'/relative;destination=target/relative
        destination.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,destination);copied.add(relative)
        if source.suffix in ['.gd','.gdshader','.gdshaderinc']:
            pending.extend(pattern.findall(source.read_text(encoding='utf-8-sig')))
    shutil.copytree(ROOT/'Viewer/Art/Creatures',target/'Art/Creatures')
    (target/'project.godot').write_text('[application]\nconfig/name="Isolated public bird check"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
    env=os.environ.copy();env['APPDATA']=env['LOCALAPPDATA']=str(ROOT/'.godot-user')
    godot=next((ROOT/'.tools/godot').glob('*console.exe'))
    for args in [['--editor','--import'],['--script','res://Presentation/BirdDistributionTests.gd','--','--require-isolated']]:
        result=subprocess.run([str(godot),'--headless','--path',str(target),*args],env=env,capture_output=True,text=True,timeout=120)
        (target/('import.log' if '--editor' in args else 'check.log')).write_text(result.stdout+result.stderr,encoding='utf-8')
        output=result.stdout+result.stderr
        assert result.returncode==0 and 'ERROR:' not in output,output
        if '--script' in args:assert 'BIRD DISTRIBUTION: 9 / 9' in output,output
    print('ISOLATED BIRD DISTRIBUTION:',len(copied),'source dependencies; no local-art, game inputs or server; actual avatar, clips and corpse pass')
    print(target/'check.log')
if __name__=='__main__':main()
