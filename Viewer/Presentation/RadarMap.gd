extends RefCounted
# Native radar colours, never replacement-asset colours. Local owned data only.
var palette := PackedByteArray()
var hues := PackedByteArray()
var metadata: Dictionary = {}

static func color16(value: int) -> Color:
 return Color(float((value>>10)&31)/31.0,float((value>>5)&31)/31.0,float(value&31)/31.0)

func color(index: int) -> Color:
 if index<0 or index*2+2>palette.size():return Color.MAGENTA
 return color16(palette.decode_u16(index*2))

func drawable(s: Dictionary) -> bool:
 var id:=int(s.id)
 if id in [0,1,0xffff,0x21bc,0xa1fe,0xa1ff,0xa200,0xa201,0x63d3]:return false
 if id>=0x2198 and id<=0x21a4:return false
 var data: Dictionary=metadata.get(str(id),{})
 return not str(data.get("name","")).to_lower().begins_with("nodraw") and (int(data.get("flags",0))&0x02000000)==0

func static_color(s: Dictionary) -> Color:
 var hue:=(int(s.get("hue",0))&0x3fff)-1
 if hue>=0:
  var offset:=(hue/8)*708+4+(hue%8)*88+32
  if offset+2<=hues.size():return color16(hues.decode_u16(offset))
 return color(int(s.id)+0x4000)

func render(source: Dictionary, origin: Vector2i, size: Vector2i) -> Image:
 var image:=Image.create(size.x,size.y,false,Image.FORMAT_RGB8)
 var heights: Dictionary={}
 var highest: Dictionary={}
 for t in source.terrain:
  var at:=Vector2i(t.x,t.y)-origin
  image.set_pixelv(at,color(int(t.id)))
  heights[at]=int(t.z)
 for s in source.statics:
  if not drawable(s):continue
  var at:=Vector2i(s.x,s.y)-origin
  if not highest.has(at) or int(s.z)>int(highest[at].z):highest[at]=s
 for at in highest:
  if heights.has(at) and int(highest[at].z)>=int(heights[at]):image.set_pixelv(at,static_color(highest[at]))
 return image
