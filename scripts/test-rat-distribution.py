"""Exercise the public rat in a new project containing no private game inputs."""
import argparse,os,re,runpy,shutil,subprocess,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    mode=parser.add_mutually_exclusive_group()
    mode.add_argument('--candidate',action='store_true')
    mode.add_argument('--candidate-deaths',action='store_true')
    args=parser.parse_args()
    target=(ROOT/'work/creatures/rat-distribution'/uuid.uuid4().hex).resolve()
    assert target.is_relative_to((ROOT/'work/creatures/rat-distribution').resolve());target.mkdir(parents=True)
    pending=['Presentation/RatDistributionTests.gd'];copied=set()
    pattern=re.compile(r'(?:preload\s*\(|extends\s+|#include\s+)["\']res://([^"\']+)')
    while pending:
        relative=pending.pop()
        if relative in copied:continue
        assert not relative.startswith('local-art/')
        source=ROOT/'Viewer'/relative;destination=target/relative;destination.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,destination);copied.add(relative)
        if source.suffix in ['.gd','.gdshader','.gdshaderinc']:pending.extend(pattern.findall(source.read_text(encoding='utf-8-sig')))
    shutil.copytree(ROOT/'Viewer/Art/Creatures',target/'Art/Creatures')
    if args.candidate:
        recipe=runpy.run_path(str(ROOT/'scripts/prepare-field-fidgets.py'))
        rows,_=recipe['prepared_rat']()
        recipe['write_rat_bundle'](target/'Art/Creatures',rows[0])
    if args.candidate_deaths:
        recipe=runpy.run_path(str(ROOT/'scripts/prepare-field-deaths.py'))
        baseline=runpy.run_path(str(ROOT/'scripts/prepare-creature-fixtures.py'))['gesture_baseline']
        rows,_=recipe['prepared'](baseline('field_deaths',None,{237},layered=True))
        rat,=(row for row in rows if row['kind']=='rat_ordinary')
        recipe['write_rat_bundle'](target/'Art/Creatures',rat)
    (target/'project.godot').write_text('[application]\nconfig/name="Isolated public rat check"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
    env=os.environ.copy();env['APPDATA']=env['LOCALAPPDATA']=str(ROOT/'.godot-user');godot=next((ROOT/'.tools/godot').glob('*console.exe'))
    for args in [['--editor','--import'],['--script','res://Presentation/RatDistributionTests.gd']]:
        result=subprocess.run([str(godot),'--headless','--path',str(target),*args],env=env,capture_output=True,text=True,timeout=120)
        output=result.stdout+result.stderr;(target/('import.log' if '--editor' in args else 'check.log')).write_text(output,encoding='utf-8')
        assert result.returncode==0 and 'ERROR:' not in output,output
        if '--script' in args:
            minimum=380 if (target/'Art/Creatures/Rat/rat-deaths.scn').exists() else (
                330 if (target/'Art/Creatures/Rat/rat-fidgets.scn').exists() else 280)
            match=re.search(r'RAT DISTRIBUTION: (\d+) / (\d+)',output);assert match and match[1]==match[2] and int(match[1])>=minimum,output
    print('RAT DISTRIBUTION: source-only actual skin, action, four-leg and corpse checks pass; no local-art, original source or server')
    print(target/'check.log')
if __name__=='__main__':main()
