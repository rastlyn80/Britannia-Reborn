"""Index actual renderer captures and verification evidence; no art generation."""
import html,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUTPUT=ROOT/'outputs/mount-integration'
FORMS=['desert','forest','frenzied','ethereal-ostard','kirin','ethereal-kirin','llama','ethereal-llama','skeletal']
def main():
    cards=[];manifest=[]
    for form in FORMS:
        frames=sorted((OUTPUT/form).glob('*.png'))
        if len(frames)!=12:raise ValueError('Expected twelve real frames for '+form)
        details=[]
        for path in frames:
            name=form+'/'+path.name;manifest.append(name)
            details.append(f'<a href="{name}"><img loading="lazy" src="{name}" alt="{html.escape(form+" "+path.stem)}"></a>')
        note='<p>Female ki-rin is a fitting preview only: the real server denies female riders.</p>' if form=='kirin' else ''
        cards.append(f'<section><h2>{form.replace("-"," ").title()}</h2>{note}<img src="{form}/walk-three-quarter-20.png" alt="{form} riding"><details><summary>Idle, walk, run / side and three-quarter / two phases</summary><div class="grid">'+''.join(details)+'</div></details></section>')
    pack=OUTPUT/'pack-llama/stand.png'
    if not pack.exists():raise ValueError('Pack llama capture absent')
    (OUTPUT/'captures.json').write_text(json.dumps({'frames':manifest+['pack-llama/stand.png'],'scope':f'{len(manifest)+1} actual Godot Forward+ render frames; local visual review. Real isolated-server evidence is separate.'},indent=2))
    (OUTPUT/'index.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Mount integration</title><style>body{background:#202d36;color:#e9eeee;font:18px system-ui;max-width:1440px;margin:30px auto;padding:18px}a{color:#dfc989}img{max-width:100%;height:auto}section{margin:50px 0}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}summary{cursor:pointer;margin:15px 0}p{line-height:1.5;max-width:1100px}</style><h1>Britannia Reborn / mount integration</h1><p>Male in robe, female in plate. All images are actual Godot renders. These screenshots are local visual fixtures; native permissions, packets and replication were tested separately on disposable ModernUO.</p><p>Accepted evidence is linked below; the equine and llama completion reports extend the earlier 529 live checks. Both sexes can ride the ethereal ki-rin; only males can ride the living ki-rin. Female ki-rin rides are excluded from supported clothing coverage because the upstream server rejects them. Forced female art previews are not universally certified.</p><p>Review shortcuts are under <strong>Reviews</strong>. Source and generated art remain local.</p>'''+''.join(cards)+'''<h2>Pack llama / unrideable</h2><img src="pack-llama/stand.png" alt="Pack llama with authored panniers"><p><a href="../ostard-riding/live-validation.json">Real server evidence</a> · <a href="../ostard-riding/equine-completion-live.json">Equine completion live</a> &#183; <a href="../ostard-riding/llama-completion-live.json">Llama completion live</a> &#183; <a href="../ostard-riding/contact.json">Rider contact</a> · <a href="../ostard-riding/clothing-validation.json">Clothing coverage</a> · <a href="../ostard-riding/terrain.json">Terrain support</a></p></html>''',encoding='utf-8')
    print('MOUNT GALLERY:',OUTPUT/'index.html')
if __name__=='__main__':main()
