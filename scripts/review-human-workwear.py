"""Sheets from actual completed Godot frames; no generated/modelled screenshots."""
from pathlib import Path
from PIL import Image,ImageOps,ImageDraw
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'outputs/human-workwear'
for armour in [False,True]:
 sheet=Image.new('RGB',(1600,548),'#20313c');draw=ImageDraw.Draw(sheet)
 draw.text((18,12),'BRITANNIA REBORN / MATCHED WORKWEAR / '+('OVER PLATE' if armour else 'CIVILIAN'),fill='white')
 for row,key in enumerate(['body_sash']):
  for col,motion in enumerate(['walking','riding']):
   file=key+('_armour' if armour else '')+'_'+motion+'.png'
   with Image.open(OUT/file) as image:sheet.paste(ImageOps.contain(image.convert('RGB'),(800,500)),(col*800,36+row*500))
 sheet.save(OUT/('sheet-armour.png' if armour else 'sheet-civilian.png'))
tiles=[]
for armour in [False,True]:
 for key in ['body_sash']:
  for mounted in [False,True]:
   for back in [False,True]:
    file=key+('_armour' if armour else '')+('_riding' if mounted else '_walking')+('_back' if back else '')+'.png'
    title=key.replace('_',' ').title()+(' over plate' if armour else ' over shirt')+(' riding' if mounted else ' walking')+(' — rear' if back else '')
    tiles.append(f'<figure><a href="{file}"><img loading="lazy" src="{file}" alt="{title}"></a><figcaption>{title} · male / female</figcaption></figure>')
(OUT/'index.html').write_text('''<!doctype html><meta charset="utf-8"><title>Britannia Reborn — workwear</title>
<style>body{background:#1c2c36;color:#eee;font:16px system-ui;margin:28px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(480px,1fr));gap:16px}figure{margin:0}img{width:100%}figcaption{padding:8px}a{color:#b7d7ed}</style>
<h1>Britannia Reborn — matched workwear</h1><p>Actual Godot frames, both human bodies. Body sash; existing shirt/trousers or plate, walking and riding. Native hues remain independent. Category replacements awaiting owner visual review; exact original designs and universal garment combinations are separate work.</p>
<p><a href="sheet-civilian.png">Civilian sheet</a> · <a href="sheet-armour.png">Plate sheet</a> · <a href="gpu-validation.json">GPU checks</a> · <a href="hair-validation.json">Hair checks</a> · <a href="asset-validation.json">Source/export checks</a></p><main>'''+''.join(tiles)+'</main>',encoding='utf-8')
print('WORKWEAR REVIEW: two sheets and 8-frame gallery',OUT/'index.html')
