"""Write reproducible actual-engine review jobs; no generated artwork inputs."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'outputs/human-wardrobe-2';OUT.mkdir(parents=True,exist_ok=True)
CREDIT='Sandals: Elvaerwyn / CC BY 4.0 / modified. Full sources: THIRD_PARTY/Human-Wearables.md'
jobs=[]
def add(key,ids,angle=18,clip='Idle',phase=.23,height=2.05,center=.93,hair=None):
 people=[]
 for female in [False,True]:
  worn=[{'id':i,'hue':0,'layer':0} for i in ids]
  worn.append({'id':hair or (0x203c if female else 0x203b),'hue':1118 if female else 1147,'layer':11})
  spacing=.28 if key.startswith('hair-') else (.23 if height<1 else .52)
  people.append({'female':female,'x':spacing if female else -spacing,'angle':angle,'skin':1002,'worn':worn,'clip':clip,'phase':phase})
 jobs.append({'key':key,'people':people,'size':[1400 if height<1 else 1000,1100],'height':height,'center':center,'attribution':CREDIT})
for name,ids in [('doublet',[0x1f7b,0x1539,0x170f]),('layered-doublet',[0x1517,0x1f7b,0x1539,0x170f]),('cloak',[0x1517,0x1f7b,0x1539,0x170f,0x1515]),('cloak-robe',[0x1f03,0x1515,0x170b])]:
 for suffix,angle,clip in [('',18,'Idle'),('-back',180,'Idle'),('-jog',30,'Jog'),('-cast',18,'Cast')]:add(name+suffix,ids,angle,clip)
for name,shoe in [('shoes',0x170f),('sandals',0x170d)]:
 for suffix,angle,clip in [('',18,'Idle'),('-side',90,'Idle'),('-walk',30,'Walk')]:add(name+suffix,[0x1517,0x1539,shoe],angle,clip,height=.70,center=.25)
add('dyes',[0x1517,0x1f7b,0x1539,0x170f,0x1515])
for person in jobs[-1]['people']:
 for item,hue in zip(person['worn'],[33,203,0,1102,1135,1118]):item['hue']=hue
for style,hair in [('long',0x203c),('ponytail',0x203d)]:
 for garment,ids in [('robe',[0x1f03]),('cloak',[0x1517,0x1f7b,0x1515]),('hood',[0x2687]),('hat',[0x1517,0x1715]),('helmet',[0x1fa1,0x1412])]:
  add('hair-'+style+'-'+garment,ids,155,height=1.10,center=1.37,hair=hair)
 for pose in ['Walk','Cast']:add('hair-'+style+'-'+pose.lower(),[0x1517,0x1f7b,0x1515],150,pose,height=1.10,center=1.37,hair=hair)
(OUT/'jobs.json').write_text(json.dumps({'output':str(OUT),'jobs':jobs},indent=2))
print('CIVILIAN REVIEW:',len(jobs),'actual-engine jobs')
