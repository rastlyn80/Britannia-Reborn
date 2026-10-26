"""Read-only, independent full-atlas comparison with owned Trammel inputs."""
import collections,json,struct,argparse
from pathlib import Path
import importlib.util
_spec=importlib.util.spec_from_file_location('parity',Path(__file__).with_name('audit-classic-parity.py'))
_parity=importlib.util.module_from_spec(_spec);_spec.loader.exec_module(_parity)
MapReader,patch=_parity.MapReader,_parity.patch


def main():
 p=argparse.ArgumentParser();p.add_argument('--data-dir',type=Path,required=True);p.add_argument('--atlas',type=Path,default=Path(__file__).resolve().parents[1]/'outputs/atlas');a=p.parse_args()
 manifest=json.loads((a.atlas/'atlas.json').read_text());reader=MapReader(a.data_dir)
 mp,sp=patch(a.data_dir,'map'),patch(a.data_dir,'static')
 land_count=static_count=0;context_land=context_statics=0;seen=set()
 entries=manifest['chunks']+manifest.get('contextChunks',[])
 with (a.data_dir/'staidx1.mul').open('rb') as index,(a.data_dir/'statics1.mul').open('rb') as statics:
  for number,entry in enumerate(entries):
   blob=(a.atlas/entry['file']).read_bytes();magic,x,y,w,h,n=struct.unpack_from('<6I',blob)
   assert magic==0x31575242 and (x,y)==(entry['x'],entry['y']) and (w,h)==(64,64)
   assert len(blob)==24+w*h*3+n*7 and (x,y) not in seen
   seen.add((x,y));expected=[]
   for bx in range(x//8,(x+64)//8):
    for by in range(y//8,(y+64)//8):
     block_id=bx*512+by
     if block_id in mp:
      with (a.data_dir/'mapdif1.mul').open('rb') as f:f.seek(mp[block_id]*196);block=f.read(196)
     else:block=reader.block(block_id)
     for dy in range(8):
      for dx in range(8):
       source=block[4+(dy*8+dx)*3:7+(dy*8+dx)*3]
       offset=24+((by*8+dy-y)*64+(bx*8+dx-x))*3
       assert blob[offset:offset+3]==source,('terrain mismatch',x,y,bx,by,dx,dy)
     if block_id in sp:
      with (a.data_dir/'stadifi1.mul').open('rb') as f:f.seek(sp[block_id]*12);off,size,_=struct.unpack('<iii',f.read(12))
      if off<0 or size==0:continue
      with (a.data_dir/'stadif1.mul').open('rb') as f:f.seek(off);records=f.read(size)
     else:
      index.seek(block_id*12);off,size,_=struct.unpack('<iii',index.read(12))
      if off<0 or size==0:continue
      statics.seek(off);records=statics.read(size)
     assert len(records)==size and size%7==0
     for tile,dx,dy,z,hue in struct.iter_unpack('<HBBbH',records):expected.append((tile,bx*8+dx-x,by*8+dy-y,z,hue))
   actual=list(struct.iter_unpack('<HBBbH',blob[24+64*64*3:]))
   assert collections.Counter(actual)==collections.Counter(expected),('statics mismatch',x,y)
   if number<len(manifest['chunks']):land_count+=4096;static_count+=n
   else:context_land+=4096;context_statics+=n
   if number%512==0:print('AUDIT',number,'/',len(manifest['chunks']),flush=True)
 assert land_count==manifest['terrainCount'] and static_count==manifest['staticCount']
 assert len(manifest['chunks'])==manifest['width']//64*(manifest['height']//64) and len(seen)==len(entries)
 result={'passed':True,'terrain':land_count,'statics':static_count,'chunks':len(manifest['chunks']),'context_chunks':len(manifest.get('contextChunks',[])),'context_terrain':context_land,'context_statics':context_statics,'bounds':[manifest[k] for k in ('originX','originY','width','height')],'method':'Every terrain ID/elevation byte and static XYZ/ID/hue compared independently to owned base+diff inputs.'}
 out=a.atlas.parent/'validation'/f'{a.atlas.name}-parity.local.json';out.parent.mkdir(exist_ok=True);out.write_text(json.dumps(result,indent=2))
 print('FULL ATLAS PARITY PASS',result,flush=True)
if __name__=='__main__':main()
