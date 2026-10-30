"""Build a browsable catalogue from actual completed Godot frames."""
import json, html, math
from pathlib import Path
from PIL import Image, ImageOps, ImageDraw
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'outputs/human-wardrobe50'
rows=[r for r in json.loads((ROOT/'scripts/human-coverage-recipes.json').read_text())['assets'] if r['kind']=='expansion50']
groups={'clothing':[],'headwear':[],'weapons':[],'accessories':[]}
for row in rows:
 group='weapons' if row['slot'] in ['weapon','shield'] else 'headwear' if row['slot']=='head' else 'accessories' if row['slot'] in ['waist','talisman','gorget'] or row['design']=='quiver' else 'clothing'
 groups[group].append(row)
links=[];sections=[]
counts=json.loads((ROOT/'outputs/human-catalogue/human-port-catalogue.json').read_text())['counts']
heading=f"{counts['wearable_percent']:.2f}% human wearable category coverage"
summary=f"{counts['category_mapped']:,}/{counts['indexed_wearables']:,} indexed graphics; {counts['equipment_categories']} categories. This batch adds {len(rows)} category models per body and {sum(len(r['graphics']) for r in rows)} graphics."
for group,items in groups.items():
 for gait in ['walking','riding']:
  sheet=Image.new('RGB',(1600,44+math.ceil(len(items)/4)*272),'#20313c');draw=ImageDraw.Draw(sheet)
  draw.text((16,12),'BRITANNIA REBORN / '+group.upper()+' / '+gait.upper()+' / MALE + FEMALE',fill='white')
  for i,row in enumerate(items):
   file=OUT/(row['key']+'_'+gait+'.png');assert file.exists(),file
   with Image.open(file) as picture:
    # Crop only the repetitive frame header/footer; keep both full models.
    tile=ImageOps.contain(picture.crop((0,64,1600,952)).convert('RGB'),(400,246))
    x=i%4*400;y=44+i//4*272;sheet.paste(tile,(x,y));draw.text((x+8,y+246),row['key'].replace('_',' '),fill='white')
  name='sheet-'+group+'-'+gait+'.png';sheet.save(OUT/name);links.append(f'<a href="{name}">{group.title()} · {gait}</a>')
 figures=[]
 for row in items:
  views=[]
  for gait in ['walking','riding']:
   for back in [False,True]:
    file=row['key']+'_'+gait+('_back' if back else '')+'.png';assert (OUT/file).exists()
    views.append(f'<a href="{file}"><img loading="lazy" src="{file}" alt="{html.escape(row["key"])} {gait}">{gait}'+(' · rear' if back else '')+'</a>')
  ids=', '.join(f'0x{i:04X}' for i in row['graphics'])
  figures.append('<article><h3>'+html.escape(row['key'].replace('_',' ').title())+'</h3><p>'+ids+'</p><div class="views">'+''.join(views)+'</div></article>')
 sections.append('<h2>'+group.title()+'</h2>'+''.join(figures))
(OUT/'index.html').write_text('''<!doctype html><meta charset="utf-8"><title>Britannia Reborn — human wearable coverage</title>
<style>body{background:#1c2c36;color:#eee;font:16px system-ui;margin:28px}a{color:#b7d7ed}nav{display:flex;gap:20px;flex-wrap:wrap}.views{display:grid;grid-template-columns:repeat(4,minmax(220px,1fr));gap:10px}.views a{display:block}img{width:100%;display:block}article{margin-bottom:24px}h3{margin-bottom:4px}p{max-width:1000px}@media(max-width:1000px){.views{grid-template-columns:repeat(2,1fr)}}</style>
<input id="filter" placeholder="Filter by name or native graphic" style="font:inherit;padding:12px;width:95%;margin:20px 0">
<h1>Britannia Reborn — Human wardrobe expansion</h1>
<p>__SUMMARY__ Category coverage is separate from final native cuts and ornament. Class-backed IDs and curated client EQUIPMENT variants are recorded separately; client variants do not certify active server classes or racial eligibility. Rejected masks, veil, middle-layer plate fits and inaccurate cuts are excluded. Native dyes and server identity remain authoritative. These are real Godot frames with both bodies walking and riding; category coverage is separate from exact original silhouettes, ornaments and per-weapon combat choreography. Native dyes and server identities remain authoritative. Images and generated art are local, ignored outputs.</p>
<nav>'''+''.join(links)+'''</nav><p><a href="gpu-validation.json">Native/GPU checks</a> · <a href="armour-validation.json">Armour opacity</a> · <a href="hair-validation.json">Hair depth checks</a> · <a href="asset-validation.json">Sources, rigs and backing audit</a></p>'''+''.join(sections)+'<script>document.querySelector("#filter").addEventListener("input",e=>{const q=e.target.value.toLowerCase();document.querySelectorAll("article").forEach(a=>a.hidden=!a.textContent.toLowerCase().includes(q))})</script>',encoding='utf-8')
page=OUT/'index.html';page.write_text(page.read_text(encoding='utf-8').replace('__HEADING__',heading).replace('__SUMMARY__',summary),encoding='utf-8')
print('WARDROBE50 REVIEW: eight sheets,',len(rows)*4,'real frames;',OUT/'index.html')
