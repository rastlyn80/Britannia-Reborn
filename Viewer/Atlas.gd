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
var overview_target := Vector3.ZERO
var overview_distance := 3700.0
var display_name := "Britannia"
var distant_materials: Array=[]
var regional:=preload("res://Presentation/RegionalContext.gd").new()
var loaded_chunks: Dictionary={}
var initial_district := Vector2i(-1,-1)
func _ready() -> void:
 var path := ProjectSettings.globalize_path("res://../outputs/britain/atlas.json")
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--atlas="): path = arg.substr(8)
  if arg.begins_with("--screenshot="): screenshot = arg.substr(13)
  if arg.begins_with("--district="):
   var pair := arg.substr(11).split(",")
   initial_district=Vector2i(int(pair[0]),int(pair[1]))
 if not data.open(path):
  push_error("Prepare Britain first with scripts/prepare-britain.ps1")
  get_tree().quit(1)
  return
 target = Vector3(data.manifest.originX+data.manifest.width/2.0,0,data.manifest.originY+data.manifest.height/2.0)
 display_name=str(data.manifest.get("displayName","Britannia"))
 overview_target=target
 overview_distance=maxf(float(data.manifest.width)*0.9,float(data.manifest.height)*1.2)
 distance=overview_distance
 var terrain := MeshInstance3D.new()
 terrain.mesh = overview_mesh()
 ground_material.shader = preload("res://Presentation/AtlasGround.gdshader")
 terrain.material_override = ground_material
 add_child(terrain)
 if data.manifest.get("scope","")=="city":
  var architecture_path:=data.folder.path_join("architecture.scn")
  var has_architecture:=FileAccess.file_exists(architecture_path)
  var forest:Node3D=preload("res://Presentation/CityOverview.gd").new().build(data,ground_material,has_architecture)
  add_child(forest)
  distant_materials.append_array(forest.get_meta("mask_materials",[]))
  if has_architecture:
   var packed:PackedScene=load(architecture_path)
   var architecture:Node3D=packed.instantiate()
   add_child(architecture)
   for mesh in architecture.get_children():
    if mesh is MeshInstance3D and mesh.material_override is ShaderMaterial:distant_materials.append(mesh.material_override)
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
 home.text = "Whole "+display_name
 home.pressed.connect(func(): distance=overview_distance;target=overview_target)
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
 return preload("res://Presentation/AtlasGeometry.gd").build(data)
func load_detail() -> void:
 if loading:return
 var at:=Vector2i(floori(target.x/64)*64,floori(target.z/64)*64)
 if at==detail_at:return
 loading=true
 status.text="Planning joined city architecture..."
 await get_tree().process_frame
 if not regional.ready:regional.prepare(data)
 var wanted:=[]
 var bounds:=Rect2i(int(data.manifest.originX),int(data.manifest.originY),int(data.manifest.width),int(data.manifest.height))
 for dy in range(-1,2):
  for dx in range(-1,2):
   var key:=at+Vector2i(dx,dy)*64
   if bounds.has_point(key):wanted.append(key)
 # Retain only the neighborhood; shared global plans survive draw eviction.
 for key in loaded_chunks.keys():
  if key not in wanted:
   loaded_chunks[key].free()
   loaded_chunks.erase(key)
 update_detail_masks()
 for key in wanted:
  if loaded_chunks.has(key):continue
  status.text="Rendering joined district %d / %d..." % [loaded_chunks.size()+1,wanted.size()]
  var node:Node3D=await regional.build_chunk(key,get_tree())
  detail.add_child(node)
  loaded_chunks[key]=node
  update_detail_masks()
  await get_tree().process_frame
 detail_at=at
 var unmapped:=0
 for node in loaded_chunks.values():unmapped+=int(node.get_meta("unmapped",0))
 detail.set_meta("unmapped",unmapped)
 loading=false
 print("ATLAS DETAIL: ",at," / ",loaded_chunks.size()," joined chunks / ",unmapped," unmapped")
func update_detail_masks()->void:
 var rectangles:=PackedVector4Array()
 for key in loaded_chunks:rectangles.append(Vector4(key.x,key.y,key.x+64,key.y+64))
 while rectangles.size()<16:rectangles.append(Vector4(-100,-100,-100,-100))
 ground_material.set_shader_parameter("detail_rects",rectangles)
 ground_material.set_shader_parameter("detail_count",loaded_chunks.size())
 for material in distant_materials:
  material.set_shader_parameter("detail_rects",rectangles)
  material.set_shader_parameter("detail_count",loaded_chunks.size())
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
  status.text="BRITANNIA REBORN / %s / TRAMMEL\n%d x %d source tiles / %d chunks\nDistant overview / joined 3D districts load nearby\nWASD pan / Right mouse orbit / Wheel zoom\nCentre %d, %d / district detail loads when close\nSelected detail: %s\nOffline explorer / Launch.cmd opens live Britain" % [display_name.to_upper(),data.manifest.width,data.manifest.height,data.manifest.chunks.size(),target.x,target.z,("not loaded" if detail_at.x<0 else "%d unmapped records" % int(detail.get_meta("unmapped",0)))]
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
