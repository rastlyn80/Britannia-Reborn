extends RefCounted
# Bridges reuse wall/window art for parapets and pier towers. Recognize them from
# source relationships (plank deck over water or riverbed, bridge-flagged pier
# stacks) so shared facade rules do not dress a stone parapet as a house wall.
# Source records stay immutable; only the presentation family/opening changes.
const BRIDGE:=0x400
const SURFACE:=0x200
var decks: Dictionary={}
var piers: Dictionary={}
var parapets: Dictionary={}
func index(world: Dictionary, catalog: Dictionary) -> void:
 decks.clear();piers.clear();parapets.clear()
 var data: Variant=world.get("staticData",{})
 var metadata: Dictionary=data if data is Dictionary else {}
 var land_data: Variant=world.get("landData",{})
 var land: Dictionary={}
 for tile in world.get("terrain",[]):land[Vector2i(tile.x,tile.y)]=tile
 var cells: Dictionary={}
 for i in world.statics.size():
  var cell:=Vector2i(world.statics[i].x,world.statics[i].y)
  if not cells.has(cell):cells[cell]=[]
  cells[cell].append(i)
 var water:=func(cell: Vector2i) -> bool:
  if land.has(cell) and land_data is Dictionary and str(land_data.get(str(int(land[cell].id)),{}).get("name","")).to_lower()=="water":return true
  for i in cells.get(cell,[]):
   if str(metadata.get(str(int(world.statics[i].id)),{}).get("name",""))=="water":return true
  return false
 # Decks: walkable plank/bridge surfaces over water or a lower riverbed, then
 # bounded continuation along the same deck onto its banks.
 var candidates: Dictionary={}
 var pending: Array=[]
 for i in world.statics.size():
  var s: Dictionary=world.statics[i]
  var info: Dictionary=metadata.get(str(int(s.id)),{})
  var name_text:=str(info.get("name","")).to_lower()
  if catalog.get(str(int(s.id)),{}).get("kind","")!="floor" or not int(info.get("flags",0))&SURFACE:continue
  if not ("bridge" in name_text or "plank" in name_text):continue
  var cell:=Vector2i(s.x,s.y)
  candidates[cell]=int(s.z)
  if water.call(cell) or (land.has(cell) and int(land[cell].z)<int(s.z)-2):pending.append([cell,0])
 while not pending.is_empty():
  var next: Array=pending.pop_back()
  var cell: Vector2i=next[0]
  if decks.has(cell):continue
  decks[cell]=candidates[cell]
  if next[1]>=4:continue
  for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var other: Vector2i=cell+offset
   if candidates.has(other) and not decks.has(other) and absi(int(candidates[other])-int(candidates[cell]))<=1:pending.append([other,next[1]+1])
 # Piers: bridge-flagged stone supports beside or beneath a deck.
 var pier_tops: Dictionary={}
 for i in world.statics.size():
  var s: Dictionary=world.statics[i]
  var info: Dictionary=metadata.get(str(int(s.id)),{})
  if catalog.get(str(int(s.id)),{}).get("kind","")!="landing" or not int(info.get("flags",0))&BRIDGE:continue
  var cell:=Vector2i(s.x,s.y)
  var near_deck:=false
  for dx in range(-1,2):
   for dy in range(-1,2):
    if decks.has(cell+Vector2i(dx,dy)):near_deck=true
  if not near_deck:continue
  piers[i]=true
  if not pier_tops.has(cell):pier_tops[cell]=[]
  pier_tops[cell].append(float(s.z)+float(info.get("height",0))*.5)
 for i in world.statics.size():
  var s: Dictionary=world.statics[i]
  var kind:=str(catalog.get(str(int(s.id)),{}).get("kind",""))
  if kind not in ["wall","window","corner","trim"]:continue
  var name_text:=str(metadata.get(str(int(s.id)),{}).get("name","")).to_lower()
  # Explicit timber/plaster construction beside a bridge is a building.
  if "wooden" in name_text or "plaster" in name_text:continue
  var cell:=Vector2i(s.x,s.y)
  var reason:=""
  for top in pier_tops.get(cell,[]):
   if absf(float(top)-float(s.z))<=1:reason="stands on bridge pier"
  if reason.is_empty() and decks.has(cell) and int(s.z)>=int(decks[cell])-1 and int(s.z)<=int(decks[cell])+2:reason="stands on bridge deck"
  if reason.is_empty():
   for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
    if decks.has(cell+offset) and absi(int(s.z)-int(decks[cell+offset]))<=2:reason="parapet along bridge deck edge"
  if reason.is_empty():continue
  parapets[i]={"family":"brick" if "brick" in name_text else "stone","opening":"slit" if kind=="window" else "","reason":reason}
func audit() -> Dictionary:
 var reasons: Dictionary={}
 for entry in parapets.values():reasons[entry.reason]=int(reasons.get(entry.reason,0))+1
 return {"deck_cells":decks.size(),"pier_records":piers.size(),"parapet_records":parapets.size(),"parapet_reasons":reasons}
