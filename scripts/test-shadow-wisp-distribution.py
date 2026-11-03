"""Exercise the owned Shadow Wisp in a clean project with no game/server files."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[1]


def main():
    target = ROOT/'work/creatures/shadow-wisp/distribution'/uuid.uuid4().hex
    target.mkdir(parents=True)
    base = ROOT/'Viewer/Presentation/WispDistributionTests.gd'
    source = base.read_text(encoding='utf-8-sig')
    # Reuse the established complete-skin/action/corpse assertions with only
    # the explicit body/presenter/shader bindings changed for the new variant.
    for before, after in [('body58','body165'),('Registry.entry(58)','Registry.entry(165)'),
                          ('initial_body=58','initial_body=165'),('"body":58','"body":165'),
                          ('native_body==58','native_body==165'),('Corpses.build(58,','Corpses.build(165,'),
                          ('"corpse_body")==58','"corpse_body")==165'),
                          ('Presentation/WispVisual.gd','Presentation/ShadowWispVisual.gd'),
                          ('Presentation/WispSurface.gdshader','Presentation/ShadowWispSurface.gdshader'),
                          ('WISP DISTRIBUTION','SHADOW WISP DISTRIBUTION')]:
        assert before in source, 'Review the shared distribution assertions: '+before
        source = source.replace(before,after)
    script = target/'Presentation/ShadowWispDistributionTests.gd'
    script.parent.mkdir(parents=True)
    script.write_text(source,encoding='utf-8')
    pattern = re.compile(r'(?:preload\s*\(|extends\s+|#include\s+)["\']res://([^"\']+)')
    pending, copied = pattern.findall(source), set()
    while pending:
        relative = pending.pop()
        if relative in copied:
            continue
        assert not relative.startswith('local-art/')
        origin, destination = ROOT/'Viewer'/relative, target/relative
        destination.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(origin,destination)
        copied.add(relative)
        if origin.suffix in ['.gd','.gdshader','.gdshaderinc']:
            pending.extend(pattern.findall(origin.read_text(encoding='utf-8-sig')))
    public = json.loads((ROOT/'Viewer/Art/Creatures/index.json').read_text())
    active = [row for row in public['entries'] if row['kind'] == 'shadow_wisp']
    prepared = ROOT/'Viewer/local-art/creatures/shadow_wisps/preparation.json'
    if not active:
        candidate = json.loads(prepared.read_text())['models'][0]
        candidate.update(status='validated')
        public['entries'].append(candidate)
    else:
        assert len(active) == 1 and active[0]['status'] == 'validated'
    art = target/'Art/Creatures'
    art.mkdir(parents=True)
    (art/'index.json').write_text(json.dumps(public),encoding='utf-8')
    shutil.copytree(ROOT/'Viewer/Art/Creatures/Wisp',art/'Wisp')
    (target/'project.godot').write_text('[application]\nconfig/name="Owned Shadow Wisp distribution check"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    environment = os.environ.copy()
    environment['APPDATA'] = environment['LOCALAPPDATA'] = str(ROOT/'.godot-user')
    godot = next((ROOT/'.tools/godot').glob('*console.exe'))
    for arguments in [['--editor','--import','--quit'],['--script','res://Presentation/ShadowWispDistributionTests.gd']]:
        result = subprocess.run([str(godot),'--headless','--path',str(target),*arguments],env=environment,capture_output=True,text=True,timeout=180)
        output = result.stdout+result.stderr
        (target/('import.log' if '--editor' in arguments else 'check.log')).write_text(output,encoding='utf-8')
        assert result.returncode == 0 and 'ERROR:' not in output, output[-6000:]
        if '--script' in arguments:
            match = re.search(r'SHADOW WISP DISTRIBUTION: (\d+) / (\d+)',output)
            assert match and match[1] == match[2] and int(match[1]) >= 650
    receipt = {'project':str(target.relative_to(ROOT)),'base_test_sha256':hashlib.sha256(base.read_bytes()).hexdigest(),
               'script_sha256':hashlib.sha256(script.read_bytes()).hexdigest(),
               'checks':int(match[1]),'failures':0,'normal_public_route':bool(active),
               'preparation_sha256':hashlib.sha256(prepared.read_bytes()).hexdigest() if prepared.exists() else None,
               'input_sha256':{relative:hashlib.sha256((ROOT/'Viewer'/relative).read_bytes()).hexdigest() for relative in sorted(copied)},
               'scope':'Actual clean body165 avatar, shared owned rig/all actions, raw hue flags and eight-surface static corpse, without local-art/game input/server. This does not prove actual native palette colours without a palette file.'}
    (ROOT/'work/creatures/shadow-wisp/distribution.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print('SHADOW WISP DISTRIBUTION:',match[1],'checks, no private art/game input/server')


if __name__ == '__main__':
    main()
