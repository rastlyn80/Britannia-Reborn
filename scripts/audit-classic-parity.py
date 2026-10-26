"""Independent local MUL/UOP parity check; proprietary coordinates stay in outputs/."""
import argparse, collections, hashlib, json, struct, zlib
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
MASK = 0xffffffff
def rotate(v,n): return ((v<<n)|(v>>(32-n))) & MASK
def name_hash(name):
 data = name.encode('ascii'); a=b=c=(0xdeadbeef+len(data))&MASK; i=0
 while len(data)-i>12:
  aa,bb,cc=struct.unpack_from('<III',data,i);a=(a+aa)&MASK;b=(b+bb)&MASK;c=(c+cc)&MASK
  a=((a-c)^rotate(c,4))&MASK;c=(c+b)&MASK
  b=((b-a)^rotate(a,6))&MASK;a=(a+c)&MASK
  c=((c-b)^rotate(b,8))&MASK;b=(b+a)&MASK
  a=((a-c)^rotate(c,16))&MASK;c=(c+b)&MASK
  b=((b-a)^rotate(a,19))&MASK;a=(a+c)&MASK
  c=((c-b)^rotate(b,4))&MASK;b=(b+a)&MASK;i+=12
 tail=data[i:]
 for n,v in enumerate(tail):
  if n<4:a=(a+(v<<((n%4)*8)))&MASK
  elif n<8:b=(b+(v<<((n%4)*8)))&MASK
  else:c=(c+(v<<((n%4)*8)))&MASK
 if tail:
  c=((c^b)-rotate(b,14))&MASK;a=((a^c)-rotate(c,11))&MASK;b=((b^a)-rotate(a,25))&MASK
  c=((c^b)-rotate(b,16))&MASK;a=((a^c)-rotate(c,4))&MASK;b=((b^a)-rotate(a,14))&MASK;c=((c^b)-rotate(b,24))&MASK
 return (b<<32)|c
class MapReader:
 def __init__(self,folder):
  self.folder=folder;self.cache={};self.index={}
  self.path=folder/'map1.mul'
  if self.path.exists():return
  self.path=folder/'map1LegacyMUL.uop'
  with self.path.open('rb') as f:
   if f.read(4)!=b'MYP\0':raise ValueError('UOP signature')
   f.seek(12);n=struct.unpack('<Q',f.read(8))[0];seen=set()
   while n:
    if n in seen:raise ValueError('Cyclic UOP directory')
    seen.add(n);f.seek(n);count,n=struct.unpack('<IQ',f.read(12))
    if count>100000:raise ValueError('UOP count')
    for _ in range(count):
     off,header,packed,raw,key,checksum,flag=struct.unpack('<QIIIQIH',f.read(34))
     if off:self.index[key]=(off+header,packed,raw,flag)
 def block(self,number):
  if not self.index:
   with self.path.open('rb') as f:f.seek(number*196);return f.read(196)
  chunk=number//4096
  if chunk not in self.cache:
   off,packed,raw,flag=self.index[name_hash(f'build/map1legacymul/{chunk:08d}.dat')]
   if flag not in (0,1) or raw>4096*196:raise ValueError('Unsupported map chunk')
   with self.path.open('rb') as f:f.seek(off);data=f.read(packed)
   data=zlib.decompress(data) if flag else data
   if len(data)!=raw:raise ValueError('UOP chunk length')
   self.cache[chunk]=data
  start=(number%4096)*196
  return self.cache[chunk][start:start+196]
def patch(folder,kind):
 name='mapdifl1.mul' if kind=='map' else 'stadifl1.mul'
 if not (folder/name).exists():return {}
 data=(folder/name).read_bytes()
 if len(data)%4:raise ValueError('Patch list size')
 return {n:i for i,n in enumerate(struct.unpack('<'+'I'*(len(data)//4),data))}
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--data-dir',type=Path);parser.add_argument('--world',type=Path,default=ROOT/'Viewer/play-world.json');args=parser.parse_args()
 folder=args.data_dir
 if folder is None:
  config=json.loads((ROOT/'Server/runtime/Configuration/modernuo.json').read_text(encoding='utf-8-sig'))
  folder=next(Path(p) for p in config['dataDirectories'] if (Path(p)/'staidx1.mul').exists())
 world=json.loads(args.world.read_text(encoding='utf-8'));reader=MapReader(folder);map_patches=patch(folder,'map');static_patches=patch(folder,'static')
 ox,oy,w,h=(world[k] for k in ('originX','originY','width','height'))
 terrain=[];statics=[]
 with (folder/'staidx1.mul').open('rb') as index,(folder/'statics1.mul').open('rb') as data:
  for bx in range(ox//8,(ox+w-1)//8+1):
   for by in range(oy//8,(oy+h-1)//8+1):
    number=bx*512+by
    if number in map_patches:
     with (folder/'mapdif1.mul').open('rb') as f:f.seek(map_patches[number]*196);block=f.read(196)
    else:block=reader.block(number)
    if len(block)!=196:raise ValueError('Truncated terrain block')
    for dy in range(8):
     for dx in range(8):
      tile,z=struct.unpack_from('<Hb',block,4+(dy*8+dx)*3);x,y=bx*8+dx,by*8+dy
      if ox<=x<ox+w and oy<=y<oy+h:terrain.append((x,y,z,tile))
    if number in static_patches:
     with (folder/'stadifi1.mul').open('rb') as f:f.seek(static_patches[number]*12);off,length,_=struct.unpack('<iii',f.read(12))
     if off<0 or not length:continue
     with (folder/'stadif1.mul').open('rb') as f:f.seek(off);records=f.read(length)
    else:
     index.seek(number*12);off,length,_=struct.unpack('<iii',index.read(12))
     if off<0 or not length:continue
     data.seek(off);records=data.read(length)
    if len(records)!=length or length%7:raise ValueError('Invalid static block')
    for offset in range(0,length,7):
     tile,dx,dy,z,hue=struct.unpack_from('<HBBbH',records,offset);x,y=bx*8+dx,by*8+dy
     if ox<=x<ox+w and oy<=y<oy+h:statics.append((x,y,z,tile,hue))
 expected_terrain=[tuple(t[k] for k in ('x','y','z','id')) for t in world['terrain']]
 expected_statics=[tuple(t[k] for k in ('x','y','z','id','hue')) for t in world['statics']]
 missing_terrain=list((collections.Counter(expected_terrain)-collections.Counter(terrain)).elements());extra_terrain=list((collections.Counter(terrain)-collections.Counter(expected_terrain)).elements())
 missing_statics=list((collections.Counter(expected_statics)-collections.Counter(statics)).elements());extra_statics=list((collections.Counter(statics)-collections.Counter(expected_statics)).elements())
 rules=json.loads((ROOT/'Viewer/Presentation/static-catalog.json').read_text(encoding='utf-8'))['rules']
 unresolved=sorted({t[3] for t in statics if str(t[3]) not in rules})
 native=json.loads((ROOT/'Server/runtime/Data/UltimaClonePreview/audit.local.json').read_text(encoding='utf-8'))
 doors=[i for i in native['items'] if i['family']=='door'];signs=[i for i in native['items'] if i['family']=='sign']
 report={'facet':'Trammel','bounds':[ox,oy,w,h],'terrain_count':len(terrain),'static_count':len(statics),'terrain_missing':missing_terrain,'terrain_extra':extra_terrain,'statics_missing':missing_statics,'statics_extra':extra_statics,'unmapped_static_ids':unresolved,'mapped_unique_static_ids':len({t[3] for t in statics}),'native_doors':len(doors),'single_doors':sum(i.get('linked') is None for i in doors),'linked_leaves':sum(i.get('linked') is not None for i in doors),'native_signs':len(signs),'native_sign_graphics':sorted({i['id'] for i in signs}),'kinds':dict(collections.Counter(rules[str(t[3])]['kind'] for t in statics if str(t[3]) in rules)),'scope':'Source geography and ID coverage; not a claim of identical 3D silhouettes or complete behavior parity.'}
 report['passed']=not any((missing_terrain,extra_terrain,missing_statics,extra_statics,unresolved))
 out=ROOT/'outputs/validation/classic-parity.local.json';out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(report,indent=2),encoding='utf-8')
 print(f"CLASSIC SOURCE PARITY: {len(terrain)} terrain, {len(statics)} statics, {len(unresolved)} unmapped IDs; {'PASS' if report['passed'] else 'FAIL'}")
 print(f"NATIVE POPULATION: {len(doors)} door leaves ({report['single_doors']} singles/{report['linked_leaves']} paired leaves), {len(signs)} signs")
 if not report['passed']:raise SystemExit(1)
if __name__=='__main__':main()
