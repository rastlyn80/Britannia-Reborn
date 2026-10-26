extends RefCounted
var manifest: Dictionary
var folder: String
var cache := {}
func open(path: String) -> bool:
 folder = path.get_base_dir()
 if FileAccess.file_exists(folder.path_join("converting.lock")): return false
 var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
 if not value is Dictionary or value.get("format","")!="BRW1" or int(value.get("chunkSize",0))!=64: return false
 manifest = value
 return true
func chunk(at: Vector2i) -> Dictionary:
 if cache.has(at): return cache[at]
 var file := FileAccess.open(folder.path_join("%d_%d.brw" % [at.x,at.y]),FileAccess.READ)
 if not file or file.get_length()<24: return {}
 if file.get_32()!=0x31575242: return {}
 var x := file.get_32()
 var y := file.get_32()
 var w := file.get_32()
 var h := file.get_32()
 var count := file.get_32()
 if x!=at.x or y!=at.y or w!=64 or h!=64 or file.get_length()!=24+w*h*3+count*7: return {}
 var land := []
 var objects := []
 for dy in h:
  for dx in w:
   var id := file.get_16()
   var z := file.get_8()
   land.append({"id":id,"x":x+dx,"y":y+dy,"z":z-256 if z>127 else z})
 for i in count:
  var id := file.get_16()
  var dx := file.get_8()
  var dy := file.get_8()
  var z := file.get_8()
  var hue := file.get_16()
  if dx>=64 or dy>=64: return {}
  objects.append({"id":id,"x":x+dx,"y":y+dy,"z":z-256 if z>127 else z,"hue":hue})
 var result := {"terrain":land,"statics":objects}
 cache[at] = result
 if cache.size()>16: cache.erase(cache.keys()[0])
 return result
func world(at: Vector2i) -> Dictionary:
 var source := chunk(at)
 if source.is_empty(): return {}
 var result := {"schema":1,"facet":"Trammel","provenance":"LOCAL TRAMMEL — full Britannia chunk; native coordinates","originX":at.x,"originY":at.y,"width":64,"height":64,"elevationScale":0.2,"terrain":source.terrain,"statics":source.statics,"landData":manifest.landData,"staticData":manifest.staticData,"terrainHalo":[],"staticHalo":[]}
 for dy in range(-1,2):
  for dx in range(-1,2):
   if dx==0 and dy==0: continue
   var adjacent := chunk(at+Vector2i(dx,dy)*64)
   for t in adjacent.get("terrain",[]):
    if t.x>=at.x-2 and t.x<at.x+66 and t.y>=at.y-2 and t.y<at.y+66: result.terrainHalo.append(t)
   for t in adjacent.get("statics",[]):
    if t.x>=at.x-2 and t.x<at.x+66 and t.y>=at.y-2 and t.y<at.y+66: result.staticHalo.append(t)
 return result
