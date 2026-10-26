extends RefCounted
# Native elevations identify attachment relationships; visual dimensions determine
# contact height. Source records and authoritative movement are never rewritten.
const Reviews=preload("res://Presentation/ReviewedCatalog.gd")
const Geometry=preload("res://Presentation/GeometryLibrary.gd")
var cells: Dictionary={}
var land: Dictionary={}
var metadata: Dictionary={}
var scale:=0.2
var cache: Dictionary={}
var issues: Array=[]
var dynamic: Dictionary={}
var dynamic_definitions: Dictionary={}
# Reconstruction rules identify procedural supports whose visual top is known.
var catalog: Dictionary={}
# Streamed districts register their worker-built cell indices instead of a
# whole-window rebuild on every install/retirement.
var chunk_cells: Dictionary={}
var chunk_land: Dictionary={}
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
func add_chunk(origin: Vector2i, terrain_index: Dictionary, static_index: Dictionary) -> void:
 chunk_land[origin]=terrain_index;chunk_cells[origin]=static_index;cache.clear()
func remove_chunk(origin: Vector2i) -> void:
 chunk_land.erase(origin);chunk_cells.erase(origin);cache.clear()
static func chunk_of(cell: Vector2i) -> Vector2i:
 return Vector2i(floori(cell.x/64.0)*64,floori(cell.y/64.0)*64)
func tiles_at(cell: Vector2i) -> Array:
 if cells.has(cell):return cells[cell]
 return chunk_cells.get(chunk_of(cell),{}).get(cell,[])
func land_at(cell: Vector2i) -> Dictionary:
 if land.has(cell):return land[cell]
 return chunk_land.get(chunk_of(cell),{}).get(cell,{})
func has_record(item: Dictionary) -> bool:
 for tile in tiles_at(Vector2i(item.x,item.y)):
  if int(tile.z)==int(item.z) and int(tile.id)==int(item.id):return true
 return false
func placement(item: Dictionary, depth: int=0) -> Dictionary:
 var key:=Vector4i(item.x,item.y,item.z,item.id)
 if cache.has(key):return cache[key]
 var result:={"offset":Vector3.ZERO,"status":"unreviewed","support":null,"confidence":"unresolved"}
 var review:=Reviews.entry(int(item.id))
 if review.is_empty() or review.get("attachment","") not in ["floor","surface"]:return result
 if depth>12:result.status="ambiguous-stack";return result
 var cell:=Vector2i(item.x,item.y)
 var candidates: Array=[]
 var ground:=land_at(cell)
 if not ground.is_empty() and absf(float(item.z)-float(ground.z))<=1:
  candidates.append({"native":float(ground.z),"visual":float(ground.z)*scale,"id":-1,"z":ground.z,"score":absf(float(item.z)-float(ground.z))})
 var nearby: Array=tiles_at(cell).duplicate()
 for support in dynamic.values():
  if int(support.x)==cell.x and int(support.y)==cell.y:nearby.append(support)
 for support in nearby:
  var support_review:=Reviews.entry(int(support.id))
  var layered:=int(support.z)==int(item.z) and int(support_review.get("supportRank",0))>0 and int(support_review.get("supportRank",0))<int(review.get("supportRank",0))
  var info: Dictionary=metadata.get(str(int(support.id)),dynamic_definitions.get(str(int(support.id)),support.get("definition",{})))
  var other:=Reviews.entry(int(support.id))
  var kind:=str(other.get("kind",catalog.get(str(int(support.id)),{}).get("kind","")))
  var native_height:=float(info.get("height",0))*(.5 if int(info.get("flags",0))&0x400 else 1.0)
  var surface: bool=int(info.get("flags",0))&0x200!=0
  var floor: bool=surface and native_height==0
  # Legacy rugs carry height 1 without the surface flag; items rest on them.
  var carpet: bool=kind=="carpet" and native_height<=1
  if int(support.z)>int(item.z) or (int(support.z)==int(item.z) and not layered and not floor and not carpet):continue
  var native_top:=float(support.z)+native_height
  var gap:=absf(float(item.z)-native_top)
  # Same reviewed graphic stacked within the lower model's visual height
  # (barrels on barrels): legacy tiledata heights understate the art.
  var stacked: bool=int(support.id)==int(item.id) and other.has("dimensions") and other.get("providesSupport",false) and int(support.z)<int(item.z) and float(item.z)<=float(support.z)+float(other.dimensions[1])/scale+2.0
  var exact: bool=gap<.01 and native_height>0
  if not other.get("providesSupport",false) and not floor and not carpet and not surface and not exact and not stacked:continue
  var tolerance:=2.0 if kind in ["table","counter"] or floor else 1.0
  if gap>tolerance and not stacked:continue
  var visual_top:=native_top*scale
  var basis:="native"
  if other.has("dimensions"):visual_top=float(support.z)*scale+float(other.dimensions[1])+placement(support,depth+1).offset.y;basis="reviewed"
  elif kind in ["table","counter","bench"]:visual_top=float(support.z)*scale+Geometry.furniture_height(kind);basis="procedural"
  elif carpet:visual_top=float(support.z)*scale+Geometry.CARPET_LIFT;basis="carpet"
  candidates.append({"native":native_top,"visual":visual_top,"id":support.id,"z":support.z,"score":0.0 if stacked else gap,"basis":basis,"stacked":stacked})
 if candidates.is_empty():
  result.status="unsupported-candidate"
 else:
  candidates.sort_custom(func(a: Dictionary,b: Dictionary):return a.score<b.score)
  var chosen: Dictionary=candidates[0]
  result.offset=Vector3(0,chosen.visual-float(item.z)*scale,0)
  result.status="contact-adjusted" if absf(result.offset.y)>.015 else "supported"
  result.support={"id":chosen.id,"z":chosen.z,"nativeContact":chosen.native,"visualBasis":chosen.get("basis","terrain")}
  result.confidence="same-graphic stack within reviewed model height" if chosen.get("stacked",false) else ("source-height-match" if chosen.score<.01 else "bounded-native-contact-tolerance")
  if chosen.get("basis","")=="native" and chosen.id!=-1 and not Reviews.entry(int(chosen.id)).has("dimensions"):result.confidence+="; unreviewed support visual height"
 cache[key]=result
 return result
