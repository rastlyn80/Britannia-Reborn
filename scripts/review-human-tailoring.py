"""Assemble completed Godot renders; Pillow is needed only for sheets."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'outputs/human-tailoring'
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',27)
small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',20)
groups=[['spellbook','lantern','lantern_lit','chain_coif'],['bonnet','feathered_hat','tricorne_hat','jester_hat']]
for page,items in enumerate(groups,1):
 sheet=Image.new('RGB',(1800,2420),'#182b36');draw=ImageDraw.Draw(sheet)
 draw.text((24,12),'Britannia Reborn / human wearable batch / male and female',font=font,fill='white')
 draw.text((24,48),'Walking                                                    Horse riding',font=small,fill='#c4d4dc')
 for row,key in enumerate(items):
  y=86+row*570;draw.text((24,y),key.replace('_',' ').title(),font=font,fill='white')
  for col,state in enumerate(['walking','riding']):
   im=Image.open(OUT/(key+'_'+state+'.png')).convert('RGB');im.thumbnail((884,525));sheet.paste(im,(col*900+8,y+38))
 draw.text((24,2375),'Actual engine renders / category replacements / sources, evidence and limits: docs/HUMAN_TAILORING_BATCH.md',font=small,fill='white')
 sheet.save(OUT/('sheet-%d.png'%page))
links=[]
for key in groups[0]+groups[1]:
 links.append('<h2>'+key.replace('_',' ').title()+'</h2>'+''.join('<a href="'+key+'_'+state+'.png"><img width="49%" src="'+key+'_'+state+'.png"></a>' for state in ['walking','riding','walking_back','riding_back']))
(OUT/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>Britannia Reborn wearable batch</title><style>body{background:#182b36;color:white;font:18px system-ui;margin:24px}img{max-width:49%;height:auto}a{color:#c4d4dc}</style><h1>Seven human wearable additions</h1><p>Both bodies, actual engine renders. On-foot and riding walking poses; rear views included. Finite GPU tests separately cover running, native hues and long-hair depth. Category art awaits owner review.</p>'+''.join(links),encoding='utf-8')
print('TAILORING REVIEW: 2 sheets and local gallery')
