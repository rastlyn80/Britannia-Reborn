extends SceneTree
# Stream source chunks for inspection; never construct the whole city scene.
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var directory:=ProjectSettings.globalize_path("res://../outputs/britain")
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--dataset="):directory=arg.substr(10)
 var data:=preload("res://Presentation/AtlasData.gd").new()
 assert(data.open(directory.path_join("atlas.json")))
 var snapshot: Dictionary={"items":[],"definitions":{}}
 var path:="res://../Server/runtime/Data/UltimaClonePreview/audit.local.json"
 if FileAccess.file_exists(path):snapshot=JSON.parse_string(FileAccess.get_file_as_string(path))
 var findings: Array=[]
 var geometry_findings: Array=[]
 var counts: Dictionary={}
 var known:=preload("res://Presentation/ReviewedCatalog.gd").entries()
 var supports:=preload("res://Presentation/SupportPlan.gd").new()
 supports.dynamic_definitions=snapshot.definitions
 var inspected:=0
 var catalogue: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("prepared/index.json"))).catalog
 for entry in data.manifest.chunks:
  var at:=Vector2i(entry.x,entry.y)
  var world:=data.world(at)
  geometry_findings.append_array(source_geometry(world,catalogue))
  supports.index(world)
  supports.dynamic.clear()
  for item in snapshot.items:
   if Rect2i(at,Vector2i(64,64)).has_point(Vector2i(item.x,item.y)):supports.dynamic[int(item.serial)]=item
  var sources: Array=world.statics.duplicate()
  sources.append_array(supports.dynamic.values())
  for source in sources:
   var review: Dictionary=known.get(str(int(source.id)),{})
   if review.get("attachment","") not in ["floor","surface"]:continue
   var placement:=supports.placement(source)
   counts[placement.status]=int(counts.get(placement.status,0))+1
   inspected+=1
   var offset: Vector3=placement.offset
   findings.append({"id":source.id,"xyz":[source.x,source.y,source.z],"origin":"native-decoration-snapshot" if source.has("serial") else "source-static","status":placement.status,"offset":[offset.x,offset.y,offset.z],"support":placement.support,"confidence":placement.confidence,"reviewStatus":review.get("reviewStatus","provisional")})
  await process_frame
 var output:=ProjectSettings.globalize_path("res://../outputs/art-review")
 DirAccess.make_dir_recursive_absolute(output)
 var file:=FileAccess.open(output.path_join("contacts.local.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"schema":1,"scope":"all converted Britain chunks; source facts plus saved native-decoration snapshot; not live multiplayer validation","counts":counts,"inspected":inspected,"findings":findings,"geometryCandidates":geometry_findings,"geometryLimit":"Source-level candidates, not confirmed rendered holes/intersections. Existing reconstruction may already repair/suppress them. No automatic source relocation."}));file.close()
 print("ART CONTACT AUDIT: ",data.manifest.chunks.size()," source chunks / ",inspected," reviewed-policy placements / ",JSON.stringify(counts))
 quit()

static func source_geometry(world: Dictionary, catalogue: Dictionary) -> Array:
 var findings: Array=[]
 var land: Dictionary={}
 var cells: Dictionary={}
 for tile in world.terrain+world.get("terrainHalo",[]):land[Vector2i(tile.x,tile.y)]=tile
 for tile in world.statics+world.get("staticHalo",[]):
  var cell:=Vector2i(tile.x,tile.y)
  if not cells.has(cell):cells[cell]=[]
  cells[cell].append(tile)
 for tile in world.terrain:
  var name_text: String=world.landData.get(str(int(tile.id)),{}).get("name","")
  if name_text.to_lower() not in ["grass","forest","dirt"] or cells.has(Vector2i(tile.x,tile.y)):continue
  var neighbors: Array=[]
  for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   if land.has(Vector2i(tile.x,tile.y)+delta):neighbors.append(float(land[Vector2i(tile.x,tile.y)+delta].z))
  if neighbors.size()==4 and neighbors.max()-neighbors.min()<=4 and (tile.z-neighbors.max()>=20 or neighbors.min()-tile.z>=20):
   findings.append({"category":"isolated-natural-source-height","id":tile.id,"xyz":[tile.x,tile.y,tile.z],"confidence":"candidate; terrain reconstruction may already filter this source sample"})
 for tile in world.statics:
  var kind: String=catalogue.get(str(int(tile.id)),{}).get("kind","")
  var name_text: String=world.staticData.get(str(int(tile.id)),{}).get("name","")
  if kind=="corner":
   var connected:=false
   for dx in range(-1,2):
    for dy in range(-1,2):
     if dx==0 and dy==0:continue
     for other in cells.get(Vector2i(tile.x+dx,tile.y+dy),[]):
      if catalogue.get(str(int(other.id)),{}).get("kind","") in ["wall","window","corner","arch"] and absf(float(other.z)-float(tile.z))<=1:connected=true
   if not connected:findings.append({"category":"isolated-corner-source","id":tile.id,"xyz":[tile.x,tile.y,tile.z],"confidence":"candidate; inspect pier/corner classification and actual repaired geometry"})
  if "bridge" in name_text.to_lower():
   var height: float=float(world.staticData[str(int(tile.id))].get("height",0))
   for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
    var cell: Vector2i=Vector2i(tile.x,tile.y)+delta
    if not land.has(cell):continue
    var bank: Dictionary=land[cell]
    if str(world.landData.get(str(int(bank.id)),{}).get("name","")).to_lower()=="water":continue
    var gap: float=absf(float(bank.z)-float(tile.z)-height)
    var continuation:=false
    for other in cells.get(cell,[]):
     if "bridge" in str(world.staticData.get(str(int(other.id)),{}).get("name","")).to_lower() or catalogue.get(str(int(other.id)),{}).get("kind","") in ["stairs","landing"]:continuation=true
    if gap>5 and not continuation:findings.append({"category":"bridge-bank-height-source","id":tile.id,"xyz":[tile.x,tile.y,tile.z],"neighbor":[cell.x,cell.y],"gapNativeUnits":gap,"confidence":"candidate; inspect bridge axis and neighboring rendered support"})
 return findings
