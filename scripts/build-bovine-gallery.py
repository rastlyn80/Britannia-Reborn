"""Index real Godot comparison frames and locally saved texture provenance."""
import hashlib,html,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUTPUT=ROOT/'outputs/bovines'
def main():
    cards=[];frames=[]
    for body,label in [(0xd8,'Cow / black and white'),(0xe7,'Cow / brown and white'),(0xe8,'Bull / brown'),(0xe9,'Bull / spotted')]:
        images=sorted((OUTPUT/str(body)).glob('*.png'));assert len(images)==32
        frames += [str(p.relative_to(OUTPUT)) for p in images]
        detail=''.join(f'<a href="{body}/{p.name}"><img loading="lazy" src="{body}/{p.name}" alt="{html.escape(p.stem)}"></a>' for p in images)
        cards.append(f'<section><h2>{label} / 0x{body:X}</h2><img src="{body}/walk-three-quarter-25.png" alt="{label} original, refined and modern comparison"><details><summary>Eight actions / two views / two phases</summary><div class="grid">{detail}</div></details></section>')
    (OUTPUT/'captures.json').write_text(json.dumps({'frames':frames,'scope':'128 actual Godot comparison frames. Offline review, not multiplayer screenshots.'},indent=2),encoding='utf-8')
    (OUTPUT/'index.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><title>Britannia Reborn / bovines</title><style>body{background:#20303a;color:#e9edef;font:18px system-ui;max-width:1440px;margin:25px auto;padding:15px}img{max-width:100%;height:auto}.grid{display:grid;grid-template-columns:1fr 1fr;gap:10px}section{margin:45px 0}a{color:#dfce95}summary{cursor:pointer}p{line-height:1.5}</style><h1>Britannia Reborn / cows and bulls</h1><p>Left: original source. Middle: bounded geometry refinement. Right: authored coat and modern rough surface. Original rigs, source clips and native identities are retained. These are real local Godot renders; native permissions, movement and interactions have separate disposable-server evidence.</p><p>Four native bodies, no invented mount items. Cow tipping uses a death animation on a living animal; the client recovers instead of marking it dead. Bull fidget shares the compatible cow source clip. Fine relief is an albedo-derived approximation. Coarse source anatomy and exact UV/coat polish remain review work.</p>'''+''.join(cards)+'''<p><a href="validation.json">Source/skin/contact checks</a> | <a href="appearance.json">GPU visibility and dyes</a> | <a href="native-identities.json">Native source audit</a> | <a href="../ostard-riding/bovine-live.json">Actual server interaction checks</a></p></html>''',encoding='utf-8')
    art=ROOT/'Viewer/local-art/animals';atlases=[]
    for coat in ['brown','spotted']:
        path=art/f'bovine-{coat}-albedo-v1.png';prompt=path.with_suffix('.prompt.txt')
        atlases.append({'image':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'exact_prompt_file':str(prompt),'prompt':prompt.read_text(encoding='utf-8'),'mode':'built-in imagegen edit of extracted source atlas; no CLI fallback'})
    (OUTPUT/'atlas-provenance.json').write_text(json.dumps({'atlases':atlases,'scope':'Local proprietary-derived source edits; no redistribution grant. AI registration is visually checked on the actual meshes, not promised pixel-exact.'},indent=2),encoding='utf-8')
    print('BOVINE GALLERY: 128 actual frames; atlas paths/prompts recorded')
if __name__=='__main__':main()
