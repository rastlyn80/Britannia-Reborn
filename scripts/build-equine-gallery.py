"""Build an ignored local gallery from completed Godot frames, never AI images."""
import html, json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'outputs/equines'

def main():
    captures=json.loads((OUT/'captures.json').read_text())
    assert len(captures['frames'])==52
    cards=[]
    for row in captures['frames']:
        name=row['file'];path=OUT/name
        assert path.is_file() and path.stat().st_size>10000 and path.read_bytes()[:8]==b'\x89PNG\r\n\x1a\n'
        entry=row['entry'];ethereal=entry['item'] in [0x3eaa,0x3e9b]
        identity=f"mount 0x{entry['item']:X}; rig proxy 0x{entry['body']:X}" if ethereal else f"body 0x{entry['body']:X}; mount 0x{entry['item']:X}"
        caption=f"{entry['name']} — {row['mode']} — {identity}"
        cards.append(f'<figure><a href="{name}"><img loading="lazy" src="{name}" alt="{html.escape(caption)}"></a><figcaption>{html.escape(caption)}</figcaption></figure>')
    tests=[]
    for name in ['validation.json','appearance-validation.json','live-validation.json','completion-validation.json','completion-appearance.json','animal-actions.json']:
        path=OUT/name
        if path.exists():
            report=json.loads(path.read_text());tests.append(f'<li><a href="{name}">{name}</a>: {report["checks"]} checks / {report["failures"]} failures</li>')
    (OUT/'index.html').write_text('''<!doctype html><meta charset="utf-8"><title>Britannia Reborn — equines</title>
<style>body{background:#15232c;color:#e3e9ed;font:16px system-ui;margin:24px}h1{font-size:28px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(480px,1fr));gap:20px}figure{margin:0;background:#24343f;padding:10px;border-radius:8px}img{width:100%;height:auto}figcaption{padding:8px}a{color:#a9d9f8}p{max-width:1000px}</style>
<h1>Britannia Reborn — horses and magical equines</h1>
<p>All 26 indexed body presentations are routed: 17 native identities and 9 explicitly separate client-only compatibility categories. This gallery shows the 24 horse-rig bodies plus two item-only ethereals. Distinct living/ethereal ki-rin and skeletal geometry are in <a href="../mount-integration/index.html">the mount gallery</a>. Compatibility bodies have no invented ridden-item mapping or gameplay permission. These are real Godot Forward+ captures of local visual fixtures. The male unicorn view is fitting only; the server refuses that rider.</p>
<p>Reused Warhorse Lite 1.0.0 under its custom free game-use licence; original procedural horn, panniers and magic effects. Feeding is authored and lying reuses existing collapse art. Exact bespoke anatomy/choreography and redistributable asset packaging remain separate work.</p>
<ul>'''+''.join(tests)+'</ul><main>'+''.join(cards)+'</main>',encoding='utf-8')
    print('EQUINE GALLERY: 52 actual frames / 26 identity panels')

if __name__=='__main__':main()
