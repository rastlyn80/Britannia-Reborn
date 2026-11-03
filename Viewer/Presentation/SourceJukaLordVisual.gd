extends "res://Presentation/SourceJukaVisual.gd"
## The server equipment record controls the original bow's visibility.
const FIT := Basis(Vector3(-.856116, -.156203, -.492611), Vector3(.301679, .622887, -.721805), Vector3(.419589, -.766559, -.486141))
const GRIP := Vector3(-.000910, .032157, -.005850)

var bow_holder: Node3D
var bow_mesh: MeshInstance3D
var rest_mesh: Mesh
var rest_arrays: Array
var string_vertices := PackedInt32Array()
var string_center := Vector3.ZERO
var applied_draw := Vector3.ZERO
var left_grasp := -1
var right_grasp := -1

func set_equipment(worn: Array) -> void:
	server_equipment = worn.duplicate(true)
	var equipped := worn.any(func(item: Dictionary) -> bool:
		return int(item.get("id", 0)) in [0x13b1, 0x13b2] and int(item.get("layer", 2)) == 2)
	if not equipped:
		if is_instance_valid(bow_holder):
			bow_holder.hide()
		return
	if not is_instance_valid(bow_holder):
		load_bow()
	if is_instance_valid(bow_holder):
		bow_holder.show()
		update_bow()

func load_bow() -> void:
	var path := str(entry.get("bow_asset", ""))
	if path.is_empty():
		return
	left_grasp = skeleton.find_bone("cp_grasp_lhand")
	right_grasp = skeleton.find_bone("cp_grasp_rhand")
	if left_grasp < 0 or right_grasp < 0:
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(ProjectSettings.globalize_path(path), state) != OK:
		return
	var bow := document.generate_scene(state) as Node3D
	var meshes := bow.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() != 1:
		bow.free()
		return
	bow_mesh = meshes[0]
	rest_mesh = bow_mesh.mesh
	rest_arrays = rest_mesh.surface_get_arrays(0)
	string_vertices.clear()
	string_center = Vector3.ZERO
	var vertices: PackedVector3Array = rest_arrays[Mesh.ARRAY_VERTEX]
	for index in vertices.size():
		var point := vertices[index]
		if absf(point.y - .0104) < .0002 and point.z > .229 and absf(point.x) < .01:
			string_vertices.append(index)
			string_center += point
	if string_vertices.size() < 3:
		bow.free()
		return
	string_center /= float(string_vertices.size())
	var attachment := BoneAttachment3D.new()
	attachment.bone_idx = left_grasp
	skeleton.add_child(attachment)
	bow_holder = Node3D.new()
	attachment.add_child(bow_holder)
	bow_holder.add_child(bow)
	bow.position = -GRIP
	animator.mixer_applied.connect(update_bow)
	contact.modification_processed.connect(update_bow)

func update_bow() -> void:
	if not is_instance_valid(bow_holder) or not bow_holder.visible:
		return
	skeleton.force_update_all_bone_transforms()
	var socket := skeleton.global_transform * skeleton.get_bone_global_pose(left_grasp)
	bow_holder.global_transform = Transform3D(socket.basis.orthonormalized() * FIT.orthonormalized(), socket.origin)
	var movement := Vector3.ZERO
	if not dead and animator.current_animation == "AttackBow":
		var phase := animator.current_animation_position / animator.current_animation_length
		var engagement := smoothstep(.27, .34, phase) * (1. - smoothstep(.49, .57, phase))
		if engagement > 0.:
			var right := skeleton.to_global(skeleton.get_bone_global_pose(right_grasp).origin)
			movement = (bow_mesh.to_local(right) - string_center) * engagement
	if movement.is_equal_approx(applied_draw):
		return
	applied_draw = movement
	if movement == Vector3.ZERO:
		bow_mesh.mesh = rest_mesh
		return
	var vertices: PackedVector3Array = rest_arrays[Mesh.ARRAY_VERTEX].duplicate()
	for index in string_vertices:
		vertices[index] += movement
	var arrays := rest_arrays.duplicate()
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var drawn := ArrayMesh.new()
	drawn.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	drawn.surface_set_material(0, rest_mesh.surface_get_material(0))
	bow_mesh.mesh = drawn
