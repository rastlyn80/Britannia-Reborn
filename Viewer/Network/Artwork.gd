extends RefCounted
static var items := {}
static var hues := {}
static var ready := false
static var tinted := {}
static func load_local() -> void:
 if ready: return
 ready = true
 if FileAccess.file_exists("res://hues.local.json"):
  var value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://hues.local.json"))
  if value is Dictionary: hues = value
 if not FileAccess.file_exists("res://item-art.local.json"): return
 var records: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://item-art.local.json"))
 if records is not Array: return
 for record in records:
  var w := int(record.width)
  var h := int(record.height)
  var bytes := Marshalls.base64_to_raw(record.rgba)
  if w<1 or h<1 or w>1024 or h>1024 or bytes.size()!=w*h*4: continue
  items[int(record.id)] = ImageTexture.create_from_image(Image.create_from_data(w,h,false,Image.FORMAT_RGBA8,bytes))
static func color(hue: int, fallback: Color = Color("ece2c6")) -> Color:
 load_local()
 var palette: Array = hues.get(str((hue&0x3fff)-1),[])
 return rgb(int(palette[31])) if palette.size()==32 else fallback
static func rgb(value: int) -> Color:
 return Color(float((value>>10)&31)/31,float((value>>5)&31)/31,float(value&31)/31)
static func item(id: int, hue: int = 0) -> Texture2D:
 load_local()
 if not items.has(id): return null
 var key := Vector2i(id,hue)
 if hue==0 or not hues.has(str((hue&0x3fff)-1)): return items[id]
 if tinted.has(key): return tinted[key]
 var image: Image = items[id].get_image()
 var palette: Array = hues[str((hue&0x3fff)-1)]
 for y in image.get_height():
  for x in image.get_width():
   var pixel := image.get_pixel(x,y)
   if pixel.a==0: continue
   if (hue&0x8000)!=0 and (absf(pixel.r-pixel.g)>0.01 or absf(pixel.r-pixel.b)>0.01): continue
   var tint := rgb(int(palette[clampi(roundi(pixel.r*31),0,31)]))
   tint.a = pixel.a
   image.set_pixel(x,y,tint)
 tinted[key] = ImageTexture.create_from_image(image)
 return tinted[key]
