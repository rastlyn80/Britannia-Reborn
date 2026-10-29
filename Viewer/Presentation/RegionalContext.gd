extends RefCounted
# One immutable source context and one topology plan for the whole converted
# region. Chunks own draw work, not independent versions of the architecture.
var world: Dictionary
var reconstruction:=preload("res://Presentation/Reconstruction.gd").new()
var shore:=preload("res://Presentation/ShorelinePlan.gd").new()
var surface:=preload("res://Presentation/TerrainSurface.gd").new()
var shell:=preload("res://Presentation/InteriorShell.gd").new()
var chunks: Dictionary={}
var floor_chunks: Dictionary={}
var terrain_material: ShaderMaterial
var ready:=false
var elapsed_ms:=0
# Committed developer edits (ManualOverrides.gd), loaded by the caller before
# prepare(). manual: static ordinal -> "hide" | "m:…"; placed_chunks: chunk ->
# [[N,state]]; terrain_chunks: chunks whose rendered terrain differs.
var overrides:=preload("res://Presentation/ManualOverrides.gd").new()
var manual: Dictionary={}
var placed_chunks: Dictionary={}
var manual_rules_applied:=0
func apply_overrides() -> void:
 if overrides.is_empty():return
 var counts: Dictionary={}
 var bounds:=Rect2i(world.originX,world.originY,world.width,world.height)
 for i in world.statics.size():
  var s:Dictionary=world.statics[i]
  var base:="%d:%d:%d:%d" % [s.x,s.y,s.z,s.id]
  var key:=base+":"+str(int(counts.get(base,0)))
  counts[base]=int(counts.get(base,0))+1
  if overrides.statics.has(key):manual[i]=str(overrides.statics[key][0])
  elif bounds.has_point(Vector2i(s.x,s.y)) and not overrides.rules.is_empty():
   var kind:=str(reconstruction.rule_for(int(s.id)).get("kind",""))
   if kind in preload("res://Presentation/DistrictBatch.gd").LIVE_EDIT_EXCLUDED:continue
   var name:=str(world.staticData.get(str(int(s.id)),{}).get("name",""))
   for rule in overrides.rules:
    if not preload("res://Presentation/ManualOverrides.gd").rule_matches(rule,s,name,kind):continue
    var action:=str(rule.action)
    if action=="hide":manual[i]="hide"
    elif action.begins_with("replace:"):manual[i]="m:%d:%d:%d:0:%s" % [s.x,s.y,s.z,action.substr(8)]
    manual_rules_applied+=1
 for n in overrides.placed:
  var p:=preload("res://Presentation/ManualOverrides.gd").placement(str(overrides.placed[n][0]))
  if p.is_empty():continue
  var key:=Vector2i(floori(p.x/64)*64,floori(p.y/64)*64)
  if not placed_chunks.has(key):placed_chunks[key]=[]
  placed_chunks[key].append([n,p])
 for cell in overrides.terrain:
  var entry: Array=overrides.terrain[cell]
  var at:=preload("res://Presentation/ManualOverrides.gd").cell(cell)
  if int(entry[0])!=0:surface.manual_heights[at]=int(entry[0])
  if str(entry[1]) in preload("res://Presentation/ManualOverrides.gd").SURFACES:surface.manual_paint[at]=str(entry[1])
 surface.heights.clear()
 print("REGIONAL OVERRIDES: %d statics (%d by rules), %d placed, %d terrain samples from %d file(s)" % [manual.size(),manual_rules_applied,overrides.placed.size(),overrides.terrain.size(),overrides.files.size()])

func terrain_overridden(at: Vector2i) -> bool:
 for cell in surface.manual_heights:
  if cell.x>=at.x-1 and cell.x<=at.x+64 and cell.y>=at.y-1 and cell.y<=at.y+64:return true
 return false

# Rendering for a committed static: the original stays only as collision; a
# moved/replaced one gets a render-only model carrying the original identity.
func manual_visual(i: int) -> Node3D:
 var source:Dictionary=world.statics[i]
 var p:=preload("res://Presentation/ManualOverrides.gd").placement(str(manual[i]))
 if p.is_empty():return null
 var moved:Node3D=reconstruction.build({"x":floori(p.x),"y":floori(p.y),"z":p.z,"id":p.id,"hue":source.hue},world,-1)
 moved.position+=Vector3(p.x-floori(p.x),0,p.y-floori(p.y))
 moved.rotation.y-=deg_to_rad(p.yaw)
 moved.set_meta("source_xyz",Vector3i(source.x,source.y,source.z))
 moved.set_meta("source_id",source.id)
 moved.set_meta("solid",false)
 moved.set_meta("manual","moved")
 return moved
func prepare(data: RefCounted) -> void:
 var start:=Time.get_ticks_msec()
 var m:Dictionary=data.manifest
 world={"schema":1,"facet":"Trammel","originX":int(m.originX),"originY":int(m.originY),"width":int(m.width),"height":int(m.height),"elevationScale":0.2,"terrain":[],"statics":[],"terrainHalo":[],"staticHalo":[],"landData":m.landData,"staticData":m.staticData,"render_cells":true}
 var bounds:=Rect2i(world.originX,world.originY,world.width,world.height)
 for entry in m.chunks:
  var source:Dictionary=data.chunk(Vector2i(int(entry.x),int(entry.y)))
  world.terrain.append_array(source.terrain)
  world.statics.append_array(source.statics)
 for entry in m.get("contextChunks",[]):
  var source:Dictionary=data.chunk(Vector2i(int(entry.x),int(entry.y)))
  for t in source.terrain:
   if bounds.grow(4).has_point(Vector2i(t.x,t.y)): world.terrainHalo.append(t)
  for t in source.statics:
   if bounds.grow(4).has_point(Vector2i(t.x,t.y)): world.staticHalo.append(t)
 print("REGIONAL PHASE: source loaded ",Time.get_ticks_msec()-start)
 world.statics.append_array(world.staticHalo)
 world.statics.sort_custom(source_less)
 for i in world.statics.size():
  var s:Dictionary=world.statics[i]
  if not bounds.has_point(Vector2i(s.x,s.y)):continue
  var key:=owner(s)
  if not chunks.has(key):chunks[key]=[]
  chunks[key].append(i)
 preload("res://Presentation/SurfaceLibrary.gd").source_origin=Vector2.ZERO
 print("REGIONAL PHASE: source sorted ",Time.get_ticks_msec()-start)
 reconstruction.index(world)
 print("REGIONAL PHASE: topology ",Time.get_ticks_msec()-start)
 reconstruction.source_origin=Vector2.ZERO
 shore.index(world,reconstruction.catalog)
 reconstruction.shoreline=shore
 print("REGIONAL PHASE: shoreline ",Time.get_ticks_msec()-start)
 surface.index(world,shore)
 reconstruction.terrain_surface=surface
 apply_overrides()
 print("REGIONAL PHASE: surface ",Time.get_ticks_msec()-start)
 shell.index(world,reconstruction)
 for cell in surface.wooden_cells:
  var key:=owner(surface.wooden_cells[cell])
  if not floor_chunks.has(key):floor_chunks[key]=[]
  floor_chunks[key].append(cell)
 terrain_material=ShaderMaterial.new()
 terrain_material.shader=preload("res://Presentation/Ground.gdshader")
 terrain_material.set_shader_parameter("stone_detail",load("res://Art/Quaternius/Village/T_Brick_BaseColor.png"))
 terrain_material.set_shader_parameter("stone_normal",load("res://Art/Quaternius/Village/T_Brick_Normal.png"))
 var surfaces=preload("res://Presentation/SurfaceLibrary.gd")
 surfaces.bind(terrain_material,"paving","cobblestone_floor_03")
 surfaces.bind(terrain_material,"ground","forest_ground_04")
 surfaces.bind(terrain_material,"grass","leafy_grass")
 for family in [["paving","cobbles"],["ground","dirt"],["grass","grass"]]:preload("res://Presentation/SurfaceVariants.gd").bind(terrain_material,family[0],family[1])
 surfaces.bind(terrain_material,"meadow","aerial_grass_rock")
 surfaces.bind(terrain_material,"rock","rock_face_03")
 surfaces.bind(terrain_material,"wood","brown_planks_03")
 shore.apply(terrain_material)
 ready=true
 elapsed_ms=Time.get_ticks_msec()-start
 print("REGIONAL PLAN: ",world.terrain.size()," land / ",world.statics.size()," context statics / ",reconstruction.catalog.size()," rules / ",elapsed_ms," ms")
static func owner(s: Dictionary) -> Vector2i:
 return Vector2i(floori(float(s.x)/64)*64,floori(float(s.y)/64)*64)
func build_chunk(at: Vector2i,tree: SceneTree, physical: bool = false) -> Node3D:
 var rect:=Rect2i(at,Vector2i(64,64))
 var root:=Node3D.new()
 root.name="District_%d_%d" % [at.x,at.y]
 root.position=Vector3(world.originX,0,world.originY)
 var terrain:=MeshInstance3D.new()
 terrain.mesh=surface.build(rect)
 terrain.material_override=terrain_material
 root.add_child(terrain)
 var sea_surface:ArrayMesh=surface.sea_mesh(rect)
 if sea_surface:
  var sea:=MeshInstance3D.new()
  sea.name="SeaSurface"
  sea.mesh=sea_surface
  sea.material_override=reconstruction.water_surface()
  sea.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  root.add_child(sea)
 var collider:=preload("res://Presentation/CollisionBuilder.gd").new()
 var before:=reconstruction.unresolved
 var models:Array=[]
 for i in chunks.get(at,[]):
  var model:Node3D=reconstruction.build(world.statics[i],world,i)
  if model and manual.has(i):
   if physical:collider.add_visual(model)
   model.free()
   model=manual_visual(i)
   if model:
    root.add_child(model)
    models.append(model)
   continue
  if model:
   root.add_child(model)
   models.append(model)
  else:
   var source:Dictionary=world.statics[i]
   var marker:MeshInstance3D=reconstruction.geometry.box(root,Vector3.ONE*0.16,Vector3(source.x-world.originX+0.5,float(source.z)*0.2+0.08,source.y-world.originY+0.5),"e7ba70")
   marker.set_meta("unmapped_source_id",int(source.id))
  if root.get_child_count()%128==0:await tree.process_frame
 for entry in placed_chunks.get(at,[]):
  var p:Dictionary=entry[1]
  var addition:Node3D=reconstruction.build({"x":floori(p.x),"y":floori(p.y),"z":p.z,"id":p.id,"hue":0},world,-1)
  addition.position+=Vector3(p.x-floori(p.x),0,p.y-floori(p.y))
  addition.rotation.y-=deg_to_rad(p.yaw)
  addition.remove_meta("source_xyz")
  addition.set_meta("solid",false)
  addition.set_meta("manual","placed:"+str(entry[0]))
  root.add_child(addition)
 # Loose objects rest on what is really under them before collision is built.
 var settled:=preload("res://Presentation/ContactSettle.gd").settle(models,world.staticData)
 root.set_meta("settled",settled)
 if physical:
  for model in models:collider.add_visual(model)
 for cell in floor_chunks.get(at,[]):
  var tile:Dictionary=surface.wooden_cells[cell]
  var node:=Node3D.new()
  node.position=Vector3(tile.x-world.originX+0.5,float(tile.z)*0.2,tile.y-world.originY+0.5)
  node.add_child(reconstruction.floors.slab(-int(surface.source_ordinals[cell])-1,reconstruction.floors.material()))
  node.set_meta("solid",true)
  root.add_child(node)
  if physical:collider.add_visual(node)
 var interior:Node3D=shell.build(world,reconstruction,rect)
 root.add_child(interior)
 if physical:collider.add_visual(interior)
 for cell in reconstruction.floors.repairs:
  if not rect.has_point(Vector2i(cell.x,cell.y)):continue
  var node:=Node3D.new()
  node.position=Vector3(cell.x-world.originX+0.5,float(cell.z)*0.2,cell.y-world.originY+0.5)
  node.add_child(reconstruction.floors.slab(cell,reconstruction.floors.material()))
  node.set_meta("solid",true)
  root.add_child(node)
  if physical:collider.add_visual(node)
 if physical:
  # Committed terrain heights are visual; collision keeps the source heights.
  var ground:=terrain
  if terrain_overridden(at):
   surface.manual_enabled=false;surface.heights.clear()
   ground=MeshInstance3D.new();ground.mesh=surface.build(rect)
   surface.manual_enabled=true;surface.heights.clear()
  collider.finish(root,ground)
  if ground!=terrain:ground.free()
  root.set_meta("collision_triangles",collider.triangles)
  preload("res://Presentation/DistrictBatch.gd").new().apply(root)
 root.set_meta("unmapped",reconstruction.unresolved-before)
 root.set_meta("count",chunks.get(at,[]).size())
 reconstruction.report.clear()
 # Cache is disposable; all boundary values derive from the shared source plan.
 if surface.heights.size()>160000:surface.heights.clear()
 return root

static func source_less(a:Dictionary,b:Dictionary)->bool:
 for key in ["x","y","z","id","hue"]:
  if int(a[key])!=int(b[key]):return int(a[key])<int(b[key])
 return false
