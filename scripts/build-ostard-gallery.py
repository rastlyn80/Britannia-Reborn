"""Package real Godot captures for private review; never edits the skin atlas.

Requires Pillow. Clip timing comes from the imported source animations.
"""
import html
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'outputs/ostard-trial'


def main():
    timings = json.loads((OUTPUT / 'frames/timings.json').read_text())
    for clip, timing in timings.items():
        paths = sorted((OUTPUT / 'frames').glob(clip + '-[0-9][0-9].png'))
        if len(paths) != timing['samples_per_cycle'] * timing['cycles']:
            raise ValueError('Missing actual render frames: ' + clip)
        frames = []
        for path in paths:
            with Image.open(path) as capture:
                capture.thumbnail((1080, 713), Image.Resampling.LANCZOS)
                frames.append(capture.convert('RGB'))
        # GIF stores centiseconds. Distribute rounding across the cycle so the
        # total duration follows the source, rather than slowing every frame.
        step = timing['cycle_seconds'] / timing['samples_per_cycle']
        boundaries = [round(i * step * 100) * 10 for i in range(len(frames) + 1)]
        durations = [max(10, b - a) for a, b in zip(boundaries, boundaries[1:])]
        frames[0].save(OUTPUT / (clip + '-comparison.gif'), save_all=True,
                       append_images=frames[1:], duration=durations, loop=0,
                       optimize=False, disposal=2)
    captures = json.loads((OUTPUT / 'captures.json').read_text())
    rows = []
    for record in captures['frames']:
        name = html.escape(record['file'])
        label = html.escape(record['clip'] + ' / ' + record['angle'] +
                            (' / head' if record.get('head') else ' / ' + str(record['phase'])))
        rows.append(f'<figure><a href="{name}"><img loading="lazy" src="{name}" alt="{label}"></a><figcaption>{label}</figcaption></figure>')
    (OUTPUT / 'index.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Desert ostard trial</title>
<style>body{background:#202d36;color:#e7ecee;font:17px system-ui;margin:24px auto;max-width:1280px;padding:16px}a{color:#e0c98a}img{max-width:100%;height:auto}figure{margin:20px 0}figcaption{padding:8px} .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(420px,1fr));gap:16px}h1{font-size:28px}p{max-width:950px;line-height:1.5}</style>
<h1>Britannia Reborn / Third Dawn desert ostard</h1>
<p>Left: original geometry and atlas. Centre: refined geometry with the original atlas. Right: refined geometry, generated higher-detail atlas and PBR shader. Same 24-bone rig, source clips, camera and lighting. These are actual Godot frames.</p>
<p>185 → 2,960 triangles; 128 → 1,254 px atlas. Local art experiment; native rotations retained, horizontal root motion removed and lowest-vertex flat-floor correction baked. Rider fit, terrain support and live creature routing remain pending.</p>
<h2>Walk / original clip timing</h2><img src="walk-comparison.gif" alt="Actual walk comparison">
<h2>Run / original clip timing</h2><img src="run-comparison.gif" alt="Actual run comparison">
<h2>Head / source beside upgraded</h2><img src="head-side.png" alt="Original and upgraded ostard head">
<p><a href="validation.json">252 sampled skinned poses</a> · <a href="material-forward.json">GPU material checks</a> · <a href="captures.json">Capture manifest</a></p>
<h2>All seven clips / two angles / two phases</h2><div class="grid">''' +
        '\n'.join(rows) + '</div></html>', encoding='utf-8')
    print('OSTARD GALLERY:', OUTPUT / 'index.html')


if __name__ == '__main__':
    main()
