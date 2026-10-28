"""Read human/equipment AnimationSequence UOP metadata, never sprite pixels.

Layout reference: pinned ClassicUO AnimationsLoader.cs, LoadUop comment and
reader. Unknown tails are recorded, never silently interpreted as actions.
"""
import struct,zlib
class Reader:
 def __init__(self,raw):self.raw=raw;self.p=0
 def read(self,fmt):
  size=struct.calcsize('<'+fmt)
  if self.p+size>len(self.raw):raise ValueError('Truncated sequence metadata')
  v=struct.unpack_from('<'+fmt,self.raw,self.p);self.p+=size;return v[0] if len(v)==1 else v
 def skip(self,n):
  if n<0 or self.p+n>len(self.raw):raise ValueError('Invalid sequence span')
  self.p+=n
 def count(self,limit=4096):
  n=self.read('I')
  if n>limit:raise ValueError('Unbounded sequence count')
  return n
def payloads(path):
 size=path.stat().st_size
 with path.open('rb') as f:
  header=f.read(28)
  if len(header)!=28:raise ValueError('Truncated UOP header')
  magic,version,signature,nxt,capacity,count=struct.unpack('<IIIQII',header)
  if magic!=0x0050594d:raise ValueError('Not a UOP archive')
  seen=set()
  while nxt:
   if nxt in seen or not 0<nxt<size-12:raise ValueError('Invalid UOP directory')
   seen.add(nxt);f.seek(nxt);entries,nxt=struct.unpack('<IQ',f.read(12))
   if entries>100000:raise ValueError('Unbounded UOP directory')
   rows=[]
   for _ in range(entries):
    raw=f.read(34)
    if len(raw)!=34:raise ValueError('Truncated UOP directory')
    offset,extra,packed,unpacked,digest,checksum,flag=struct.unpack('<QIIIQIH',raw)
    if offset:rows.append((offset+extra,packed,unpacked,flag,digest))
   for offset,packed,unpacked,flag,digest in rows:
    if not 0<=offset<=size-packed or unpacked>64*1024*1024:raise ValueError('Invalid UOP payload')
    f.seek(offset);raw=f.read(packed)
    if flag==1:
     stream=zlib.decompressobj();raw=stream.decompress(raw,unpacked+1)
     if not stream.eof or stream.unused_data:raise ValueError('Invalid UOP zlib stream')
    elif flag!=0:raise ValueError('Unsupported UOP compression')
    if len(raw)!=unpacked:raise ValueError('UOP unpacked length mismatch')
    yield digest,raw
def inspect(path,allowed):
 records=[]
 for digest,raw in payloads(path):
  if len(raw)<56:continue
  body=struct.unpack_from('<I',raw)[0]
  if body not in allowed:continue
  r=Reader(raw);r.skip(52);result={'animation_ref':body,'uop_name_hash':hex(digest),'bytes':len(raw),'replacements':[],'modes':[],'unparsed_bytes':0}
  try:
   count=r.count()
   for _ in range(count):
    old,frames,new,flags=r.read('IIiI');r.skip(48)
    r.skip(r.count()*32);r.skip(r.count()*4)
    result['replacements'].append({'old_group':old,'frame_count':frames,'new_group':new,'flags':flags})
   mode_count=r.count(32)
   for _ in range(mode_count):
    mode,fallback,default=r.read('BbI');transitions=[];movement=[];actions=[]
    for _ in range(r.count(64)):
     target,group=r.read('BI');transitions.append({'target_mode':target,'group':group})
    for _ in range(r.count(64)):
     action,one,two=r.read('BII');movement.append({'action':action,'one_handed_group':one,'two_handed_group':two})
    for _ in range(r.count(256)):
     kind,subaction=r.read('bb');choices=[r.read('I') for _ in range(r.count(256))]
     actions.append({'type':kind,'subaction':subaction,'groups':choices})
    result['modes'].append({'mode':mode,'fallback_mode':fallback,'default_group':default,'transitions':transitions,'movement':movement,'new_protocol_actions':actions})
   result['unparsed_bytes']=len(raw)-r.p
  except (ValueError,struct.error) as e:
   result['parse_blocker']=str(e);result['unparsed_bytes']=len(raw)-r.p
  records.append(result)
 return records
