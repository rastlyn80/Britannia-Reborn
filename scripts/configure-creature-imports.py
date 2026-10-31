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
                if int(match[1])>=rate:continue
                text=re.sub(r'^animation/fps=\d+\s*$',f'animation/fps={rate}',text,flags=re.M)
                path.write_text(text,encoding='utf-8');changed+=1
    print('CREATURE IMPORT SETTINGS:',changed,'local sidecars updated')
    return 3 if changed else 0
if __name__=='__main__':raise SystemExit(main())
