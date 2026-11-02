"""Preserve the declared sampling precision when Godot imports local trials."""
import argparse,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('families',nargs='+');args=parser.parse_args()
    changed=0
    for family in args.families:
        report=json.loads((ROOT/f'Viewer/local-art/creatures/{family}/preparation.json').read_text())
        for model in report['models']:
            if model['status']!='prepared':continue
            rate=max(clip.get('floor_sample_rate',30) for clip in model['stats']['original']['clips'].values())
            assert 30<=rate<=240
            for treatment in ['original','rounded','modern']:
                path=ROOT/f"Viewer/local-art/creatures/{model['kind']}-{treatment}.gltf.import"
                if not path.exists():continue # First import creates the sidecar.
                text=path.read_text(encoding='utf-8');match=re.search(r'^animation/fps=(\d+)\s*$',text,re.M)
                assert match,'Cannot identify the local Godot animation sample rate'
                previous=text
                if int(match[1])<rate:text=re.sub(r'^animation/fps=\d+\s*$',f'animation/fps={rate}',text,flags=re.M)
                if model['kind'] in ['serpents_snake_giant','serpents_snake_giant_ice','small_snakes','liche_liche_retro','liche_liche_lord_retro'] or model.get('presentation_script') in ['res://Presentation/SourceElementalVisual.gd','res://Presentation/SourceFrogVisual.gd']:
                    # The fast strike's floor correction must stay coupled to
                    # its joint poses. Default key reduction visibly lifts it.
                    text=re.sub(r'^meshes/force_disable_compression=\w+', 'meshes/force_disable_compression=true',text,flags=re.M)
                    options='_subresources={\n"nodes": {\n"PATH:AnimationPlayer": {\n"compression/enabled": false,\n"optimizer/enabled": false\n}\n}\n}'
                    if '_subresources={}' in text:text=text.replace('_subresources={}',options)
                    else:
                        assert '"optimizer/enabled": false' in text and '"compression/enabled": false' in text,'Unexpected existing serpent import subresources; preserve them for review'
                if text!=previous:path.write_text(text,encoding='utf-8');changed+=1
    print('CREATURE IMPORT SETTINGS:',changed,'local sidecars updated')
    return 3 if changed else 0
if __name__=='__main__':raise SystemExit(main())
