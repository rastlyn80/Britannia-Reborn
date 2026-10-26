extends Node3D
const Data = preload("res://Presentation/AtlasData.gd")
const Reconstruction = preload("res://Presentation/Reconstruction.gd")
var data := Data.new()
var camera := Camera3D.new()
var target := Vector3(2560,0,2048)
var distance := 3700.0
var yaw := 0.0
var pitch := -0.90
var looking := false
var status := Label.new()
var detail := Node3D.new()
var detail_at := Vector2i(-64,-64)
var ground_material := ShaderMaterial.new()
var loading := false
var screenshot := ""
var frames := 0
var initial_district := Vector2i(-1,-1)
func _ready() -> void:
 var path := ProjectSettings.globalize_path("res://../outputs/atlas/atlas.json")
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--atlas="): path = arg.substr(8)
  if arg.begins_with("--screenshot="): screenshot = arg.substr(13)
  if arg.begins_with("--district="):
   var pair := arg.substr(11).split(",")
   initial_district=Vector2i(int(pair[0]),int(pair[1]))
 if not data.open(path):
  push_error("Prepare Britannia first with scripts/prepare-britannia.ps1")
  get_tree().quit(1)
  return
 target = Vector3(data.manifest.originX+data.manifest.width/2.0,0,data.manifest.originY+data.manifest.height/2.0)
 var terrain := MeshInstance3D.new()
 terrain.mesh = overview_mesh()
 ground_material.shader = preload("res://Presentation/AtlasGround.gdshader")
 terrain.material_override = ground_material
 add_child(terrain)
 var environment := WorldEnvironment.new()
 environment.environment = Environment.new()
 environment.environment.background_mode = Environment.BG_SKY
 environment.environment.sky = Sky.new()
 var sky := ProceduralSkyMaterial.new()
 sky.sky_top_color = Color("377dc2")
 sky.sky_horizon_color = Color("d1e4df")
 sky.ground_horizon_color = Color("d1e4df")
 sky.ground_bottom_color = Color("7fabbf")
 environment.environment.sky.sky_material = sky
 environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color = Color("b3c9db")
 environment.environment.ambient_light_energy = 0.65
 environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
 add_child(environment)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-50,-30,0)
 sun.light_energy = 1.3
 add_child(sun)
 add_child(camera)
 camera.near = 0.2
 camera.far = 15000
 add_child(detail)
 var canvas := CanvasLayer.new()
 add_child(canvas)
 var panel := PanelContainer.new()
 panel.position = Vector2(18,18)
 canvas.add_child(panel)
 var column := VBoxContainer.new()
 panel.add_child(column)
 column.add_child(status)
 var buttons := HBoxContainer.new()
 column.add_child(buttons)
 var home := Button.new()
 home.text = "Whole Britannia"
 home.pressed.connect(func(): distance=3700;target=Vector3(2560,0,2048))
 buttons.add_child(home)
 var britain := Button.new()
 britain.text = "Britain district"
 britain.pressed.connect(func(): target=Vector3(1602,4,1591);distance=75;load_detail())
 buttons.add_child(britain)
 var inspect := Button.new()
 inspect.text = "Render detail here"
 inspect.pressed.connect(load_detail)
 buttons.add_child(inspect)
 if initial_district.x>=0:
  target=Vector3(initial_district.x+32,8,initial_district.y+32)
  distance=85
  load_detail.call_deferred()
 print("ATLAS VIEW: ",data.manifest.terrainCount," terrain / ",data.manifest.staticCount," statics / ",data.manifest.chunks.size()," chunks")
func overview_mesh() -> ArrayMesh:
 var points := {}
 var vertices := PackedVector3Array()
 var colors := PackedColorArray()
 var indices := PackedInt32Array()
 for tile in data.manifest.overview:
  var cell := Vector2i(tile[0],tile[1])
  points[cell] = vertices.size()
  vertices.append(Vector3(cell.x,float(tile[2])*0.2,cell.y))
  colors.append(Reconstruction.terrain_color(str(data.manifest.landData.get(str(int(tile[3])),{}).get("name",""))).srgb_to_linear())
 for cell in points:
  var next := Vector2i(mini(cell.x+8,int(data.manifest.originX+data.manifest.width)-1),mini(cell.y+8,int(data.manifest.originY+data.manifest.height)-1))
  if next.x==cell.x or next.y==cell.y or not points.has(next): continue
  var a: int=points[cell]
  var b: int=points[Vector2i(next.x,cell.y)]
  var c: int=points[Vector2i(cell.x,next.y)]
  var d: int=points[next]
  indices.append_array(PackedInt32Array([a,c,b,b,c,d]))
 var normals := PackedVector3Array()
 normals.resize(vertices.size())
 for i in range(0,indices.size(),3):
  var a:=indices[i]
  var b:=indices[i+1]
  var c:=indices[i+2]
  var normal := (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).normalized()
  normals[a]+=normal;normals[b]+=normal;normals[c]+=normal
 for i in normals.size(): normals[i]=normals[i].normalized()
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices
 arrays[Mesh.ARRAY_NORMAL]=normals
 arrays[Mesh.ARRAY_COLOR]=colors
 arrays[Mesh.ARRAY_INDEX]=indices
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return mesh
func load_detail() -> void:
 if loading: return
 var at := Vector2i(floori(target.x/64)*64,floori(target.z/64)*64)
 if at==detail_at: return
 var world := data.world(at)
 if world.is_empty(): return
 loading = true
 status.text = "Rendering source district…"
 await get_tree().process_frame
 for child in detail.get_children(): child.free()
 detail.position=Vector3(at.x,0,at.y)
 var reconstruction := Reconstruction.new()
 reconstruction.index(world)
 var shore := preload("res://Presentation/ShorelinePlan.gd").new()
 shore.index(world,reconstruction.catalog)
 var surface := preload("res://Presentation/TerrainSurface.gd").new()
 surface.index(world,shore)
 var terrain := MeshInstance3D.new()
 terrain.mesh=surface.build()
 var surfaces = preload("res://Presentation/SurfaceLibrary.gd")
 surfaces.source_origin=Vector2(at)
 var material := ShaderMaterial.new()
 material.shader=preload("res://Presentation/Ground.gdshader")
 material.set_shader_parameter("stone_detail",load("res://Art/Quaternius/Village/T_Brick_BaseColor.png"))
 material.set_shader_parameter("stone_normal",load("res://Art/Quaternius/Village/T_Brick_Normal.png"))
 surfaces.bind(material,"paving","cobblestone_floor_03")
 surfaces.bind(material,"ground","forest_ground_04")
 surfaces.bind(material,"rock","rock_face_03")
 surfaces.bind(material,"wood","brown_planks_03")
 shore.apply(material)
 terrain.material_override=material
 detail.add_child(terrain)
 for cell in surface.wooden_cells:
  var source: Dictionary=surface.wooden_cells[cell]
  var floor_node := Node3D.new()
  floor_node.position=Vector3(source.x-at.x+0.5,float(source.z)*0.2,source.y-at.y+0.5)
  floor_node.add_child(reconstruction.floors.slab(-int(surface.source_ordinals[cell])-1,reconstruction.floors.material()))
  detail.add_child(floor_node)
 for i in world.statics.size():
  var node := reconstruction.build(world.statics[i],world,i)
  if node: detail.add_child(node)
  else:
   var marker := MeshInstance3D.new()
   var cube := BoxMesh.new()
   cube.size = Vector3(0.16,0.16,0.16)
   marker.mesh=cube
   marker.position=Vector3(world.statics[i].x-at.x+0.5,float(world.statics[i].z)*0.2+0.08,world.statics[i].y-at.y+0.5)
   var missing := StandardMaterial3D.new()
   missing.albedo_color=Color("e7ba70")
   marker.material_override=missing
   detail.add_child(marker)
  if i%128==0: await get_tree().process_frame
 var shell := preload("res://Presentation/InteriorShell.gd").new()
 shell.index(world,reconstruction)
 detail.add_child(shell.build(world,reconstruction))
 for repair in reconstruction.floors.repairs:
  var floor_node := Node3D.new()
  floor_node.position=Vector3(repair.x-at.x+0.5,float(repair.z)*0.2,repair.y-at.y+0.5)
  floor_node.add_child(reconstruction.floors.slab(repair,reconstruction.floors.material()))
  detail.add_child(floor_node)
 ground_material.set_shader_parameter("detail_rect",Vector4(at.x,at.y,at.x+63,at.y+63))
 detail_at=at
 detail.set_meta("unmapped",reconstruction.unresolved)
 detail.set_meta("count",world.statics.size())
 loading=false
 print("ATLAS DETAIL: ",at," / ",world.statics.size()," records / ",reconstruction.unresolved," unmapped")
func _process(delta: float) -> void:
 frames+=1
 var movement := Vector3.ZERO
 if Input.is_physical_key_pressed(KEY_W): movement.z-=1
 if Input.is_physical_key_pressed(KEY_S): movement.z+=1
 if Input.is_physical_key_pressed(KEY_A): movement.x-=1
 if Input.is_physical_key_pressed(KEY_D): movement.x+=1
 target+=movement.rotated(Vector3.UP,yaw)*distance*delta*0.5
 target.x=clampf(target.x,data.manifest.originX,data.manifest.originX+data.manifest.width-8)
 target.z=clampf(target.z,data.manifest.originY,data.manifest.originY+data.manifest.height-8)
 camera.position=target+Vector3(sin(yaw)*cos(pitch),-sin(pitch),cos(yaw)*cos(pitch))*distance
 camera.look_at(target)
 if not loading and distance<180 and Vector2i(floori(target.x/64)*64,floori(target.z/64)*64)!=detail_at: load_detail()
 if not loading:
  status.text="BRITANNIA REBORN Â/ TRAMMEL EXPLORER
5120 Ã— 4096 source tiles Â/ 5,120 local chunks
WASD pan Â/ Right mouse orbit Â/ Wheel zoom
Centre %d, %d Â/ detail uses existing art mappings
Unmapped records shown as gold markers: %d
Exploration preview Â/ gameplay remains in the validated Britain crop" % [target.x,target.z,int(detail.get_meta("unmapped",0))]
 if frames>=20 and not screenshot.is_empty() and not loading and (initial_district.x<0 or detail_at.x>=0):
  var output := screenshot
  screenshot=""
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(output)
  get_tree().quit()
func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_RIGHT: looking=event.pressed
  if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP: distance=maxf(15,distance*0.85)
  if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN: distance=minf(9000,distance/0.85)
 if event is InputEventMouseMotion and looking:
  yaw-=event.relative.x*0.004
  pitch=clampf(pitch-event.relative.y*0.004,-1.55,-0.08)
 if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE: get_tree().quit()
func _notification(what: int) -> void:
 if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT: looking=false
