extends SceneTree
# The compact streaming cache rule (docs/COMPACT_STREAMING.md): placed models
# are not merged into per-district geometry, detailed solids collide as boxes
# and terrain as a heightmap, and the shared model library stores one copy of
# each model, however many districts or groups use it.
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS ",label)
	else:
		failures += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")

static func detailed_mesh() -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 48
	sphere.rings = 24
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,sphere.get_mesh_arrays())
	return mesh

func run() -> void:
	# Batching: architecture merges, a detailed placed model does not.
	var district := Node3D.new()
	var group := Node3D.new()
	district.add_child(group)
	var wall := MeshInstance3D.new()
	wall.mesh = BoxMesh.new()
	wall.set_meta("kind","wall")
	group.add_child(wall)
	var rock := MeshInstance3D.new()
	rock.mesh = detailed_mesh()
	rock.set_meta("kind","asset")
	rock.position = Vector3(3,0,0)
	group.add_child(rock)
	preload("res://Presentation/DistrictBatch.gd").new().apply(district)
	check(wall.mesh == null and rock.mesh != null,"architecture is merged; a placed model keeps its own mesh for instancing")
	district.free()
	# Collision: a detailed solid is a box, the terrain a heightmap.
	var builder := preload("res://Presentation/CollisionBuilder.gd").new()
	var solid := MeshInstance3D.new()
	solid.mesh = detailed_mesh()
	solid.set_meta("solid",true)
	solid.position = Vector3(10,0,10)
	builder.add_visual(solid)
	var terrain := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(64,64)
	plane.subdivide_width = 63
	plane.subdivide_depth = 63
	plane.center_offset = Vector3(32,0,32)
	var ground := ArrayMesh.new()
	ground.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,plane.get_mesh_arrays())
	terrain.mesh = ground
	var holder := Node3D.new()
	builder.finish(holder,terrain)
	var boxes := 0
	var heightmaps := 0
	var concave := 0
	for shape_node in holder.find_children("*","CollisionShape3D",true,false):
		if shape_node.shape is BoxShape3D: boxes += 1
		elif shape_node.shape is HeightMapShape3D: heightmaps += 1
		elif shape_node.shape is ConcavePolygonShape3D: concave += 1
	check(boxes == 1 and heightmaps == 1 and concave == 0,"a detailed solid collides as one box and the terrain as one heightmap (%d/%d/%d)" % [boxes,heightmaps,concave])
	var map: HeightMapShape3D = holder.find_children("*","CollisionShape3D",true,false).filter(func(n): return n.shape is HeightMapShape3D)[0].shape
	check(map.map_width == 65 and map.map_depth == 65,"the terrain heightmap has one height per tile corner (65 x 65)")
	solid.free()
	terrain.free()
	holder.free()
	# Model library: identical meshes in different groups share one stored copy.
	var bake := preload("res://Presentation/BakeStreaming.gd").new()
	var folder := ProjectSettings.globalize_path("user://compact-test")
	DirAccess.make_dir_recursive_absolute(folder)
	if DirAccess.dir_exists_absolute(folder.path_join("models")):
		for name in DirAccess.get_files_at(folder.path_join("models")): DirAccess.remove_absolute(folder.path_join("models").path_join(name))
	bake.output = folder
	var first := detailed_mesh()
	var second := detailed_mesh()
	var a: Mesh = bake.shared(first)
	var b: Mesh = bake.shared(second)
	check(a == b and not a.resource_path.is_empty() and not "::" in a.resource_path,"two identical meshes become one library model, referenced by path")
	check(DirAccess.get_files_at(folder.path_join("models")).size() == 1,"the library holds that model once")
	var small := ArrayMesh.new()
	small.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,BoxMesh.new().get_mesh_arrays())
	check(bake.shared(small).resource_path.is_empty(),"tiny meshes stay inline")
	bake.free()
	print("COMPACT STREAMING TESTS: %d checks / %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
