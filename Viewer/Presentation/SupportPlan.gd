extends RefCounted
# Native elevations identify attachment relationships; visual dimensions determine
# contact height. Source records and authoritative movement are never rewritten.
const Reviews=preload("res://Presentation/ReviewedCatalog.gd")
var cells: Dictionary={}
var land: Dictionary={}
var metadata: Dictionary={}
var scale:=0.2
var cache: Dictionary={}
var issues: Array=[]
var dynamic: Dictionary={}
var dynamic_definitions: Dictionary={}
func index(world: Dictionary, extra: Array=[]) -> void:
 cells.clear();land.clear();cache.clear();issues.clear()
 scale=float(world.get("elevationScale",.2))
 var source_metadata: Variant=world.get("staticData",{})
 metadata=source_metadata if source_metadata is Dictionary else {}
 for tile in world.get("terrain",[]):land[Vector2i(tile.x,tile.y)]=tile
 for tile in world.get("statics",[])+extra:
  var cell:=Vector2i(tile.x,tile.y)
  if not cells.has(cell):cells[cell]=[]
  cells[cell].append(tile)
func placement(item: Dictionary, depth: int=0) -> Dictionary:
 var key:=Vector4i(item.x,item.y,item.z,item.id)
 if cache.has(key):return cache[key]
 var result:={"offset":Vector3.ZERO,"status":"unreviewed","support":null,"confidence":"unresolved"}
 var review:=Reviews.entry(int(item.id))
 if review.is_empty() or review.get("attachment","") not in ["floor","surface"]:return result
 if depth>12:result.status="ambiguous-stack";return result
 var cell:=Vector2i(item.x,item.y)
 var candidates: Array=[]
 if land.has(cell) and absf(float(item.z)-float(land[cell].z))<=1:
  candidates.append({"native":float(land[cell].z),"visual":float(land[cell].z)*scale,"id":-1,"z":land[cell].z,"score":absf(float(item.z)-float(land[cell].z))})
 var nearby: Array=cells.get(cell,[]).duplicate()
 for support in dynamic.values():
  if int(support.x)==cell.x and int(support.y)==cell.y:nearby.append(support)
 for support in nearby:
  var support_review:=Reviews.entry(int(support.id))
  var layered:=int(support.z)==int(item.z) and int(support_review.get("supportRank",0))>0 and int(support_review.get("supportRank",0))<int(review.get("supportRank",0))
  var info: Dictionary=metadata.get(str(int(support.id)),dynamic_definitions.get(str(int(support.id)),support.get("definition",{})))
  var other:=Reviews.entry(int(support.id))
  var native_height:=float(info.get("height",0))*(.5 if int(info.get("flags",0))&0x400 else 1.0)
  var floor:=int(info.get("flags",0))&0x200 and native_height==0
  if int(support.z)>int(item.z) or (int(support.z)==int(item.z) and not layered and not floor):continue
  if not other.get("providesSupport",false) and not floor:continue
  var native_top:=float(support.z)+native_height
  var gap:=absf(float(item.z)-native_top)
  var tolerance:=2.0 if other.get("kind","") in ["table","counter"] else 1.0
  if gap>tolerance:continue
  var visual_top:=native_top*scale
  if other.has("dimensions"):visual_top=float(support.z)*scale+float(other.dimensions[1])+placement(support,depth+1).offset.y
  candidates.append({"native":native_top,"visual":visual_top,"id":support.id,"z":support.z,"score":gap})
 if candidates.is_empty():
  result.status="unsupported-candidate"
 else:
  candidates.sort_custom(func(a: Dictionary,b: Dictionary):return a.score<b.score)
  var chosen: Dictionary=candidates[0]
  result.offset=Vector3(0,chosen.visual-float(item.z)*scale,0)
  result.status="contact-adjusted" if absf(result.offset.y)>.015 else "supported"
  result.support={"id":chosen.id,"z":chosen.z,"nativeContact":chosen.native}
  result.confidence="source-height-match" if chosen.score<.01 else "bounded-native-contact-tolerance"
 cache[key]=result
 return result
