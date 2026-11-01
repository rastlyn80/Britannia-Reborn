"""Add declared hen categories without changing the retained source skin/clips.

The input is the separately verified CC0 source export, not a game archive.
Original binary bytes, meshes, UVs, skins, maps and eleven motions are retained.
"""
import argparse,bisect,copy,hashlib,json,math,statistics,struct
from pathlib import Path

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,required=True);p.add_argument('--preparation',type=Path,required=True);p.add_argument('--gait',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 raw=a.source.read_bytes();assert raw[:4]==b'glTF' and struct.unpack_from('<I',raw,4)[0]==2
 length=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+length]);blob=bytearray(raw[28+length:]);original=copy.deepcopy(doc);original_blob=bytes(blob)
 assert len(doc['buffers'])==1 and 'uri' not in doc['buffers'][0]
 sources={v['name']:copy.deepcopy(v) for v in doc['animations']};assert len(sources)==11
 def values(index):
  acc=doc['accessors'][index];view=doc['bufferViews'][acc['bufferView']];assert acc['componentType']==5126
  n={'SCALAR':1,'VEC3':3,'VEC4':4}[acc['type']];start=view.get('byteOffset',0)+acc.get('byteOffset',0)
  return [struct.unpack_from('<'+'f'*n,blob,start+i*view.get('byteStride',4*n)) for i in range(acc['count'])]
 def append(rows):
  count=len(rows[0]);assert count in [1,3,4] and all(len(r)==count and all(math.isfinite(v) for v in r) for r in rows)
  while len(blob)%4:blob.append(0)
  offset=len(blob);payload=struct.pack('<'+'f'*(len(rows)*count),*(v for row in rows for v in row));blob.extend(payload);view=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(payload)})
  index=len(doc['accessors']);doc['accessors'].append({'bufferView':view,'componentType':5126,'count':len(rows),'type':{1:'SCALAR',3:'VEC3',4:'VEC4'}[count],'min':[min(r[i] for r in rows) for i in range(count)],'max':[max(r[i] for r in rows) for i in range(count)]});return index
 def duration(animation):return max(values(s['input'])[-1][0] for s in animation['samplers'])
 preparation=json.loads(a.preparation.read_text());assert preparation['asset_sha256']==sha(a.source)
 floor_node=next(i for i,n in enumerate(doc['nodes']) if n.get('name')=='Grounding')
 for label,clip in sources.items():
  if any(c['target']=={'node':floor_node,'path':'translation'} for c in clip['channels']):continue
  lower,upper=preparation['corrections'][label];assert abs(upper-lower)<1e-7,'Missing animated floor correction: '+label
  index=len(clip['samplers']);clip['samplers'].append({'input':append([(0.,),(duration(clip),)]),'output':append([[0.,lower,0.],[0.,lower,0.]]),'interpolation':'LINEAR'});clip['channels'].append({'sampler':index,'target':{'node':floor_node,'path':'translation'}})
 def retime(label,source,seconds):
  clip=copy.deepcopy(sources[source]);clip['name']=label;ratio=seconds/duration(clip);changed={}
  for sampler in clip['samplers']:
   index=sampler['input']
   if index not in changed:changed[index]=append([(r[0]*ratio,) for r in values(index)])
   sampler['input']=changed[index]
  return clip
 def interpolate(left,right,u,rotation=False):
  if rotation:
   dot=sum(x*y for x,y in zip(left,right))
   if dot<0:right=[-x for x in right];dot=-dot
   if dot<.9995:
    theta=math.acos(max(-1.,min(1.,dot)));s=math.sin(theta);return [(math.sin((1-u)*theta)*x+math.sin(u*theta)*y)/s for x,y in zip(left,right)]
  result=[x*(1-u)+y*u for x,y in zip(left,right)]
  if rotation:
   norm=math.sqrt(sum(v*v for v in result));result=[v/norm for v in result]
  return result
 cache={}
 def sample(source,target,time):
  key=(source,target)
  if key not in cache:
   channel=next((c for c in sources[source]['channels'] if (c['target']['node'],c['target']['path'])==target),None)
   if channel is None:cache[key]=None
   else:
    sampler=sources[source]['samplers'][channel['sampler']];mode=sampler.get('interpolation','LINEAR');assert mode in ['LINEAR','STEP'];cache[key]=([r[0] for r in values(sampler['input'])],values(sampler['output']),mode)
  row=cache[key]
  if row is None:return doc['nodes'][target[0]].get(target[1],{'translation':[0,0,0],'rotation':[0,0,0,1],'scale':[1,1,1]}[target[1]])
  times,data,mode=row
  if len(times)==1:return data[0]
  index=max(0,min(len(times)-2,bisect.bisect_right(times,time)-1));u=max(0.,min(1.,(time-times[index])/max(1e-9,times[index+1]-times[index])))
  if mode=='STEP':return data[index+1] if time>=times[-1] else data[index]
  return interpolate(data[index],data[index+1],u,target[1]=='rotation')
 # One shared parent moves the complete rig and skin; server coordinates stay
 # outside this scene. Every category explicitly resets this new parent.
 motion=len(doc['nodes']);doc['nodes'].append({'name':'AuthoredChickenMotion','children':doc['scenes'][doc.get('scene',0)]['nodes']});doc['scenes'][doc.get('scene',0)]['nodes']=[motion]
 clips=[];metadata={}
 for name,source in sources.items():
  clip=copy.deepcopy(source);clip['name']='Source'+name;clips.append(clip);metadata[clip['name']]={'origin':'Retained CC0 source motion, evaluated curved-bone conversion','duration':duration(clip),'loop':name not in ['BeginPecking','EndPecking','Dying']}
 for name,source,seconds in [('Idle','Idle2',1.5),('Walk','Walk',.4),('Run','Walk',.8),('Death','Dying',1.),('Fidget','Idle1',duration(sources['Idle1'])),('Eat','Eating',duration(sources['Eating'])),('Hit','Idle2',.6)]:
  clips.append(retime(name,source,seconds));metadata[name]={'origin':'Retained '+source+' with declared category/timing adaptation','duration':seconds,'loop':name in ['Idle','Walk','Run','Eat','Fidget']}
 # A chicken strikes with its beak. Connect the original lowering, peck and
 # recovery poses rather than substituting a mammal's claw or bite gesture.
 pieces=[('BeginPecking',.18),('Pecking3',.22),('EndPecking',.24)];seconds=sum(v for _,v in pieces);times=[seconds*i/round(seconds*240) for i in range(round(seconds*240)+1)];input_id=append([(t,) for t in times]);attack={'name':'Attack','samplers':[],'channels':[]};targets=sorted({(c['target']['node'],c['target']['path']) for source,_ in pieces for c in sources[source]['channels']})
 for target in targets:
  rows=[]
  for time in times:
   start=0.
   for source,width in pieces:
    if time<=start+width+1e-7:rows.append(sample(source,target,max(0.,time-start)/width*duration(sources[source])));break
    start+=width
  index=len(attack['samplers']);attack['samplers'].append({'input':input_id,'output':append(rows),'interpolation':'LINEAR'});attack['channels'].append({'sampler':index,'target':{'node':target[0],'path':target[1]}})
 clips.append(attack);metadata['Attack']={'origin':'Authored .64s beak strike assembled from retained BeginPecking/Pecking3/EndPecking; not original UO choreography','duration':seconds,'loop':False}
 gait=json.loads(a.gait.read_text());assert gait['asset_sha256']==sha(a.source) and len(gait['samples'])==129
 def foot(phase):
  at=phase*128;index=min(127,int(at));u=at-index;points={}
  for side in ['L','R']:
   left=gait['samples'][index]['feet'][side];right=gait['samples'][index+1]['feet'][side];p=interpolate([sum(v[j] for v in left)/4 for j in range(3)],[sum(v[j] for v in right)/4 for j in range(3)],u);points[side]=p
  return points
 # Brief alternating ground contacts and airborne resets permit a small
 # bounded presentation offset without stretching any relative joint pose.
 n=192;offsets=[None]*n;target_speed=2.7;contact_half=.03;run_duration=.8
 for centre in [0.,.5]:
  side=min(foot(centre),key=lambda s:foot(centre)[s][1]);anchor=foot(centre)[side][2]
  for i in range(n):
   phase=i/n;delta=(phase-centre+.5)%1.-.5
   if abs(delta)<=contact_half:offsets[i]=anchor-target_speed*delta*run_duration-foot(phase)[side][2]
 planted=[i for i,v in enumerate(offsets) if v is not None];assert planted and len(planted)<n
 for left in planted:
  if offsets[(left+1)%n] is not None:continue
  right=left+1
  while offsets[right%n] is None:right+=1
  width=right-left;va=offsets[left];vb=offsets[right%n];sa=va-offsets[(left-1)%n];sb=offsets[(right+1)%n]-vb
  for i in range(left+1,right):
   u=(i-left)/width;mid=(va+vb)*.5
   if u<.5:v=u*2.;aa,bb,ma,mb=va,mid,width*.5*sa,0.
   else:v=(u-.5)*2.;aa,bb,ma,mb=mid,vb,0.,width*.5*sb
   offsets[i%n]=(2*v**3-3*v*v+1)*aa+(v**3-2*v*v+v)*ma+(-2*v**3+3*v*v)*bb+(v**3-v*v)*mb
 assert max(abs(v) for v in offsets)<.15;offsets.append(offsets[0])
 for clip in clips:
  seconds=duration(clip)
  if clip['name']=='Run':
   rows=[]
   for i,z in enumerate(offsets):
    phase=i/n;distance=min(phase%.5,.5-phase%.5);lift=0. if distance<=contact_half else .025*math.sin(math.pi*.5*(distance-contact_half)/(.25-contact_half))**2;rows.append([0.,lift,z])
   t=append([(seconds*i/n,) for i in range(n+1)]);output=append(rows)
  elif clip['name']=='Hit':
   t=append([(seconds*i/72,) for i in range(73)]);output=append([[0.,.006*math.sin(math.pi*i/72)**2,-.035*math.sin(math.pi*i/72)**2] for i in range(73)])
  else:t=append([(0.,),(seconds,)]);output=append([[0.,0.,0.],[0.,0.,0.]])
  index=len(clip['samplers']);clip['samplers'].append({'input':t,'output':output,'interpolation':'LINEAR'});clip['channels'].append({'sampler':index,'target':{'node':motion,'path':'translation'}})
 metadata['Run']['origin']='Authored common-root running bound using retained Walk poses, 2.5cm positive lift and measured short stance/airborne reset; relative source joints unchanged'
 metadata['Hit']['origin']='Authored 3.5cm backward/6mm upward common-root recoil over retained Idle2; relative source joints unchanged'
 doc['animations']=clips;doc['buffers'][0]['byteLength']=len(blob)
 for field in ['meshes','skins','materials','images','textures']:assert doc.get(field)==original.get(field),field
 assert bytes(blob[:len(original_blob)])==original_blob
 data=json.dumps(doc,separators=(',',':')).encode();data+=b' '*((-len(data))%4);blob+=b'\0'*((-len(blob))%4);result=struct.pack('<4sII',b'glTF',2,12+8+len(data)+8+len(blob))+struct.pack('<I4s',len(data),b'JSON')+data+struct.pack('<I4s',len(blob),b'BIN\0')+blob
 probes={}
 for side in ['L','R']:
  rows=gait['samples'];heights=[min(p[1] for p in row['feet'][side]) for row in rows];floor=min(heights);speeds=[]
  for i in range(1,len(rows)):
   speed=(sum(p[2] for p in rows[i-1]['feet'][side])-sum(p[2] for p in rows[i]['feet'][side]))*.25/(gait['duration']/128)
   if max(heights[i-1],heights[i])<floor+.012 and speed>.001:speeds.append(speed)
  assert len(speeds)>20;probes[side]={'median_backward_mps':statistics.median(speeds),'samples':len(speeds),'landmark_min_y':floor}
 reference=statistics.mean(v['median_backward_mps'] for v in probes.values())*gait['duration']/.4
 a.output.parent.mkdir(parents=True,exist_ok=True)
 if not a.output.exists() or a.output.read_bytes()!=result:a.output.write_bytes(result)
 report={'source_asset_sha256':sha(a.source),'source_preparation_sha256':sha(a.preparation),'gait_sha256':sha(a.gait),'recipe_sha256':sha(Path(__file__)),'asset_sha256':sha(a.output),'clips':metadata,'source_stance_landmarks':probes,'run_root_range_m':[min(offsets),max(offsets)],'run_contact_half_phase':contact_half,'floor_policy':'Restore constant Grounding tracks omitted by export, using measured source floor metadata; every clip explicitly resets new shared motion. Relative original joint curves are unchanged.','locomotion':{'walk_reference_mps':reference,'run_reference_mps':target_speed,'run_threshold_mps':3.6,'rate_min':.15,'rate_max':4.},'status':'Prepared authored category candidate only; actual saved skins/gaits/avatar/native/corpse/distribution pending'}
 a.output.with_suffix('.actions.json').write_text(json.dumps(report,indent=2)+'\n');print('CHICKEN CATEGORIES',len(clips),'retained11source,8active; no native route installed')

if __name__=='__main__':main()
