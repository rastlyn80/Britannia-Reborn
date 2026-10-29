"""Decode private primary-MUL horse stand frames for coat matching, not distribution.

Requires Pillow. Does not claim DEF/UOP precedence or change source artwork.
"""
import hashlib,json,struct
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
data=Path(json.loads((ROOT/'Server/runtime/Configuration/modernuo.json').read_text())['dataDirectories'][0])
out=ROOT/'outputs/horse-polish';out.mkdir(parents=True,exist_ok=True)
idx=(data/'anim.idx').read_bytes();sheet=Image.new('RGB',(1000,360),(48,58,64));draw=ImageDraw.Draw(sheet);records=[]
with (data/'anim.mul').open('rb') as source:
 for j,body in enumerate([0xc8,0xe2,0xe4,0xcc]):
  slot=22000+(body-200)*65+2*5+1
  start,size,_=struct.unpack_from('<iii',idx,slot*12);assert start>=0 and size>0
  source.seek(start);raw=source.read(size);palette=struct.unpack_from('<256H',raw)
  frames=struct.unpack_from('<I',raw,512)[0];offset=512+struct.unpack_from('<I',raw,516)[0]
  cx,cy,w,h=struct.unpack_from('<4h',raw,offset);cursor=offset+8
  assert 0<w<1024 and 0<h<1024
  frame=Image.new('RGBA',(w,h));pixels=frame.load()
  while True:
   header=struct.unpack_from('<I',raw,cursor)[0];cursor+=4
   if header==0x7fff7fff:break
   count=header&0xfff;x=(header>>22)&1023;y=(header>>12)&1023
   x=x-1024 if x&512 else x;y=y-1024 if y&512 else y;x+=cx;y+=cy+h
   for k in range(count):
    value=palette[raw[cursor+k]]
    if 0<=x+k<w and 0<=y<h:pixels[x+k,y]=(((value>>10)&31)*255//31,((value>>5)&31)*255//31,(value&31)*255//31,255)
   cursor+=count
  frame.save(out/('native-%x.png'%body))
  large=frame.resize((w*3,h*3),Image.Resampling.NEAREST);sheet.paste(large,(j*250+15,50),large);draw.text((j*250+15,20),hex(body),fill='white')
  records.append({'body':body,'slot':slot,'offset':start,'length':size,'frames':frames,'entry_sha256':hashlib.sha256(raw).hexdigest()})
sheet.save(out/'native-coat-reference.png')
(out/'native-coat-reference.json').write_text(json.dumps({'files':{name:hashlib.file_digest((data/name).open('rb'),'sha256').hexdigest() for name in ['anim.idx','anim.mul']},'scope':'Primary MUL stand group 2, direction 1; private visual reference only; no DEF/UOP precedence claim','records':records},indent=2))
print('Decoded four private original horse reference frames')
