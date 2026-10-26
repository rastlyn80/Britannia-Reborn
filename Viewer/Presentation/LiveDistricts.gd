extends Node3D
# Native coordinates remain unchanged; draw/collision nodes share World.point's
# local frame. A district becomes traversable only after its collider is installed.
var regional := preload("res://Presentation/RegionalContext.gd").new()
var loaded: Dictionary = {}
var requested := Vector2i(1602,1591)
var busy := false
var scene: Node3D
var bounds := Rect2i()
var distant_materials: Array = []

func prepare(owner_scene: Node3D) -> bool:
 scene = owner_scene
 var data := preload("res://Presentation/AtlasData.gd").new()
 var path := ProjectSettings.globalize_path("res://../outputs/britain/atlas.json")
 if not FileAccess.file_exists(path) or not data.open(path):
  push_error("Run scripts/prepare-britain.ps1 before launching live Britain.")
  return false
 regional.prepare(data)
 regional.world.provenance = "LOCAL TRAMMEL / streamed live Britain / ModernUO authoritative"
 bounds = Rect2i(regional.world.originX,regional.world.originY,regional.world.width,regional.world.height)
 # RegionalContext normally draws globally for the explorer; the live client
 # uses source-origin-relative positions for avatars, picking and native items.
 regional.reconstruction.source_origin = Vector2(bounds.position)
 preload("res://Presentation/SurfaceLibrary.gd").source_origin = Vector2(bounds.position)
 regional.terrain_material.set_shader_parameter("source_origin",Vector2(bounds.position))
 build_horizon(data)
 await refresh()
 return true

func destination_ready(cell: Vector2i) -> bool:
 return bounds.has_point(cell) and loaded.has(regional.owner({"x":cell.x,"y":cell.y}))

func follow(cell: Vector2i) -> void:
 requested = cell
 if not busy and regional.owner({"x":cell.x,"y":cell.y}) != get_meta("center",Vector2i(-1,-1)):
  refresh()

func refresh() -> void:
 busy = true
 var center := regional.owner({"x":requested.x,"y":requested.y})
 var wanted: Dictionary = {}
 for dy in range(-1,2):
  for dx in range(-1,2):
   var at := center+Vector2i(dx,dy)*64
   if bounds.has_point(at): wanted[at] = true
 # Install new bodies before dropping outgoing ones, including teleports.
 for at in wanted:
  if loaded.has(at): continue
  var district: Node3D = await regional.build_chunk(at,get_tree(),true)
  district.position = Vector3.ZERO
  add_child(district)
  loaded[at] = district
  update_horizon()
  print("LIVE DISTRICT READY: ",at," / collision triangles ",district.get_meta("collision_triangles",0))
 for at in loaded.keys():
  if not wanted.has(at):
   loaded[at].queue_free()
   loaded.erase(at)
 update_horizon()
 set_meta("center",center)
 busy = false
 if is_instance_valid(scene.world_items) and scene.world_items.scene != null:
  scene.world_items.suppress_streamed_posts()

func build_horizon(data: RefCounted) -> void:
 var horizon := Node3D.new()
 horizon.position = Vector3(-bounds.position.x,0,-bounds.position.y)
 add_child(horizon)
 var terrain := MeshInstance3D.new()
 terrain.mesh = preload("res://Presentation/AtlasGeometry.gd").build(data)
 var material := ShaderMaterial.new()
 material.shader = preload("res://Presentation/AtlasGround.gdshader")
 terrain.material_override = material
 horizon.add_child(terrain)
 distant_materials.append(material)
 var architecture_path: String = data.folder.path_join("architecture.scn")
 var has_architecture := FileAccess.file_exists(architecture_path)
 var forest: Node3D = preload("res://Presentation/CityOverview.gd").new().build(data,material,has_architecture)
 horizon.add_child(forest)
 distant_materials.append_array(forest.get_meta("mask_materials",[]))
 if has_architecture:
  var packed: PackedScene = load(architecture_path)
  var architecture := packed.instantiate()
  horizon.add_child(architecture)
  for mesh in architecture.get_children():
   if mesh is MeshInstance3D and mesh.material_override is ShaderMaterial:
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    distant_materials.append(mesh.material_override)
 for shader in distant_materials: shader.set_shader_parameter("source_origin",Vector2(bounds.position))

func update_horizon() -> void:
 var keys := loaded.keys()
 keys.reverse()
 var rectangles := PackedVector4Array()
 for at in keys.slice(0,16): rectangles.append(Vector4(at.x,at.y,at.x+64,at.y+64))
 var count := rectangles.size()
 while rectangles.size()<16: rectangles.append(Vector4(-100,-100,-100,-100))
 for material in distant_materials:
  material.set_shader_parameter("detail_rects",rectangles)
  material.set_shader_parameter("detail_count",count)
