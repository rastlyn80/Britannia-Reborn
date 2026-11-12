# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceLizardActionsVisual.gd"

const PlaneContact := preload("res://Presentation/SourceArmedLizardContact.gd")
const StepProbes := [Vector2(-.85, -.85), Vector2(-.85, 0), Vector2(-.85, .85),
	Vector2(0, -.85), Vector2(0, .85), Vector2(.85, -.85), Vector2(.85, 0), Vector2(.85, .85)]
var living_skin: Array[Dictionary] = []
var weapon_skin: Array[Dictionary] = []
var tail_skin: Array[Dictionary] = []
var weapon_arm: Array[int] = []
var tail_joints: Array[int] = []
var support_plane: Dictionary
var split_support: Dictionary
var step_query := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.DOWN, 1)
var living_lift := 0.0


func _ready() -> void:
	super._ready()
	var skin_surface: MeshInstance3D = contact.surface
	contact.free()
	contact = PlaneContact.new()
	skeleton.add_child(contact)
	contact.include_toe_descendants = true
	contact.align_skinned_soles = true
	contact.iterations = 5
	contact.configure(skin_surface, false)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			var skin := Ground.skin_points(mesh, skeleton)
			living_skin.append(skin)
			if mesh.name == &"Spear":
				weapon_skin.append(skin)
			elif mesh == skin_surface:
				tail_skin.append(tail_vertices(skin))
	weapon_arm = joints(["bip01 r hand", "bip01 r forearm", "bip01 r upperarm"])
	tail_joints = joints(["bip01 tail2", "bip01 tail1"])
	contact.support_appendages = correct_step_appendages
	animator.mixer_applied.connect(release_living_support)
	contact.modification_processed.connect(support_living_pose)


func joints(names: Array[String]) -> Array[int]:
	var result: Array[int] = []
	for name in names:
		var joint := skeleton.find_bone(name)
		if joint >= 0:
			result.append(joint)
	return result


func tail_vertices(skin: Dictionary) -> Dictionary:
	var surfaces: Array[Dictionary] = []
	for surface: Dictionary in skin.surfaces:
		var points := PackedVector3Array()
		var bindings := PackedInt32Array()
		var weights := PackedFloat32Array()
		var stride: int = surface.stride
		for vertex: int in surface.points.size():
			var offset := vertex * stride
			var weight := 0.0
			for influence in stride:
				var joint: int = skin.bones[surface.bindings[offset + influence]]
				if skeleton.get_bone_name(joint).begins_with("bip01 tail"):
					weight += surface.weights[offset + influence]
			if weight < .5:
				continue
			points.append(surface.points[vertex])
			for influence in stride:
				bindings.append(surface.bindings[offset + influence])
				weights.append(surface.weights[offset + influence])
		surfaces.append({"points": points, "bindings": bindings, "weights": weights, "stride": stride})
	return {"bones": skin.bones, "bind_poses": skin.bind_poses, "surfaces": surfaces}


func release_living_support() -> void:
	if living_lift > 0.0:
		model.global_position.y -= living_lift
		living_lift = 0.0


func _physics_process(delta: float) -> void:
	release_living_support()
	super._physics_process(delta)
	support_plane = {}
	split_support = {}
	contact.plane = {}
	contact.use_local_planes = false
	if dead or not contact.enabled or contact.contacts.size() != 2:
		return
	var left: Dictionary = contact.contacts[0]
	var right: Dictionary = contact.contacts[1]
	var normal: Vector3 = left.normal
	var separation: Vector3 = right.position - left.position
	# Keep the independent supports when the feet straddle a step or a seam.
	if normal.dot(right.normal) < .995 or absf(normal.dot(separation)) > .015 or nearby_step(left):
		var center := ground_under(global_position)
		if not center.is_empty() and center.normal.y >= .8:
			split_support = center
			contact.use_local_planes = true
		return
	if normal.y < .95:
		return
	var local_normal := (global_basis.inverse() * normal).normalized()
	var slope := Basis(Quaternion(Vector3.UP, local_normal))
	model.basis = (slope * source_model_basis).scaled_local(model.scale)
	contact.sample(get_world_3d().direct_space_state, global_position)
	support_plane = left
	contact.plane = left


func nearby_step(plane: Dictionary) -> bool:
	var origin: Vector3 = plane.position
	var normal: Vector3 = plane.normal
	for offset: Vector2 in StepProbes:
		var hit := ground_under(global_position + Vector3(offset.x, 0, offset.y))
		if not hit.is_empty() and hit.normal.y >= .8 and absf(normal.dot(hit.position - origin)) > .025:
			return true
	return false


func ground_under(point: Vector3) -> Dictionary:
	step_query.from = point + Vector3.UP * .65
	step_query.to = point - Vector3.UP * .65
	return get_world_3d().direct_space_state.intersect_ray(step_query)


func support_living_pose() -> void:
	if dead or (support_plane.is_empty() and split_support.is_empty()):
		return
	release_living_support()
	skeleton.force_update_all_bone_transforms()
	if not split_support.is_empty():
		living_lift = step_lift()
		model.global_position.y += living_lift
		return
	var gap := INF
	for skin in living_skin:
		gap = minf(gap, Ground.minimum_plane_gap(skin, skeleton, skeleton.global_transform,
			support_plane.position, support_plane.normal))
	if gap < CLEARANCE:
		living_lift = (CLEARANCE - gap) / float(support_plane.normal.y)
		model.global_position.y += living_lift


func step_lift() -> float:
	var floor_height: float = split_support.position.y
	return float(contact.step_conflict(floor_height, step_query, living_skin).get("lift", 0.0))


func correct_step_appendages() -> void:
	clear_step_appendage(tail_skin, tail_joints)
	if not weapon_skin.is_empty():
		clear_step_appendage(weapon_skin, weapon_arm)


func clear_step_appendage(skins: Array[Dictionary], chain: Array[int]) -> void:
	for attempt in 2:
		for joint in chain:
			skeleton.force_update_all_bone_transforms()
			var hit: Dictionary = contact.step_conflict(float(split_support.position.y), step_query, skins)
			if hit.is_empty():
				return
			contact.rotate_toward_surface(joint, hit.point, hit.normal, hit.lift * hit.normal.y)


func receive_action(request: Dictionary) -> bool:
	release_living_support()
	return super.receive_action(request)


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in ["Fidget", "Fidget2"]:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func begin_death_from(source: Node3D) -> float:
	if "living_lift" in source:
		model.global_position.y -= float(source.living_lift)
	return super.begin_death_from(source)
