"""Create repeatable real-engine review jobs; --sheets assembles their PNGs."""
import json,sys,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'outputs/human-coverage-session';OUT.mkdir(exist_ok=True)
rows=json.loads((ROOT/'scripts/human-coverage-recipes.json').read_text())['assets']
if '--sheets' in sys.argv:
 from PIL import Image,ImageDraw
 jobs=json.loads((OUT/'jobs.json').read_text())['jobs']
 for page,start in enumerate(range(0,len(jobs),15),1):
  height=95+math.ceil(min(15,len(jobs)-start)/3)*305
  sheet=Image.new('RGB',(1500,height),'#182b36');draw=ImageDraw.Draw(sheet)
  draw.text((20,12),'Britannia Reborn / human category review / page '+str(page),fill='white')
  for i,job in enumerate(jobs[start:start+15]):
   x=(i%3)*500;y=45+(i//3)*305
   im=Image.open(OUT/(job['key']+'.png')).convert('RGB');im.thumbnail((496,278));sheet.paste(im,(x,y))
   draw.text((x+8,y+280),job['key'].replace('_',' '),fill='white')
  draw.text((20,height-40),'CC0 human/motion foundation; selected props CC BY 4.0. Full credits: docs/HUMAN_COVERAGE_SOURCES.md',fill='white')
  sheet.save(OUT/('contact-sheet-%d.png'%page))
 print('REVIEW SHEETS:',math.ceil(len(jobs)/15));sys.exit(0)
jobs=[]
for row in rows:
 worn=[{'id':0x1539,'layer':4},{'id':0x170f,'layer':3}]
 if row['slot'] not in ['torso','arms']:worn.append({'id':0x1517,'layer':5})
 worn.append({'id':row['graphics'][0],'hue':0})
 clip='Bow_Idle' if row.get('stance')=='bow' else 'Crossbow_Idle' if row.get('stance')=='crossbow' else 'Idle'
 jobs.append({'key':row['key'],'size':[1600,900],'height':2.3 if row['key']=='bow' else 2.1,'center':1.05 if row['key']=='bow' else .95,'attribution':'Britannia Reborn / category fit review / credits: docs/HUMAN_COVERAGE_SOURCES.md','people':[dict(female=f,x=x,angle=angle,skin=1002,worn=worn,clip=clip,phase=.35) for f,x,angle in [(False,-1.1,0),(False,-.38,-65),(True,.38,0),(True,1.1,65)]]})
for clip in ['Bow_Attack','Crossbow_Attack','Bow_Idle','Crossbow_Idle','Salute','Turn','Fidget3','Rider_Idle','Rider_Walk','Rider_Run','Rider_Attack','Rider_Bow','Rider_Crossbow','Rider_Slap']:
 worn=[{'id':0x1539},{'id':0x1517}]
 if 'Bow' in clip:worn.append({'id':0x13b1})
 if 'Crossbow' in clip:worn.append({'id':0xf4f})
 jobs.append({'key':'action_'+clip,'size':[1600,900],'height':2.4,'center':1.1,'people':[dict(female=f,x=x,angle=angle,skin=1002,worn=worn,clip=clip,phase=phase) for f,x,angle,phase in [(False,-1.1,0,.3),(False,-.38,-65,.7),(True,.38,0,.3),(True,1.1,65,.7)]]})
for clip in ['Walk','Sword_A','Cast']:
 jobs.append({'key':'layered_'+clip,'size':[1600,900],'height':2.1,'center':.95,'people':[dict(female=f,x=x,angle=angle,skin=1002,worn=[{'id':0x1415},{'id':0x1410},{'id':0x1411},{'id':0x1412},{'id':0x1b74},{'id':0xf5e},{'id':0x203c,'layer':11}],clip=clip,phase=phase) for f,x,angle,phase in [(False,-1.1,0,.3),(False,-.38,-65,.7),(True,.38,0,.3),(True,1.1,65,.7)]]})
(OUT/'jobs.json').write_text(json.dumps({'output':str(OUT).replace('\\','/'),'jobs':jobs},indent=2))
print('HUMAN REVIEW JOBS:',len(jobs))
