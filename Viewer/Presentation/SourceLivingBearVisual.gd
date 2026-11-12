# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceQuadrupedCollapseVisual.gd"

const PawSupport := preload("res://Presentation/SourceTrollGround.gd")
const Clearance := .003
const FloorProbes := [Vector3(-.40, 0, -.55), Vector3(-.40, 0, .55),
	Vector3(.40, 0, -.55), Vector3(.40, 0, .55), Vector3(-.40, 0, 0), Vector3(.40, 0, 0),
	Vector3(0, 0, -.70), Vector3(0, 0, .70)]
var skin: Array[Dictionary] = []
var trunk: Array[Dictionary] = []
var support_plane := {}
var split_floor := {}
var support_lift := 0.0
var query := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.DOWN, 1)


func _ready() -> void:
	super._ready()
	var mesh: MeshInstance3D = contact.surface
	contact.free()
	contact = PawSupport.new()
	skeleton.add_child(contact)
	contact.include_toe_descendants = true
	contact.configure(mesh, true)
	include_blended_paws(mesh)
	skin.append(Ground.skin_points(mesh, skeleton))
	trunk.append(trunk_points(skin[0]))
	animator.mixer_applied.connect(release_support)
	contact.modification_processed.connect(settle_support)


func include_blended_paws(mesh: MeshInstance3D) -> void:
	var bones: PackedInt32Array = contact.arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = contact.arrays[Mesh.ARRAY_WEIGHTS]
	var vertices: PackedVector3Array = contact.arrays[Mesh.ARRAY_VERTEX]
	var bindings: Array[int] = []
	for index in mesh.skin.get_bind_count():
		var joint := mesh.skin.get_bind_bone(index)
		bindings.append(joint if joint >= 0 else skeleton.find_bone(mesh.skin.get_bind_name(index)))
	for foot: Dictionary in contact.feet:
		var limb_root: int = foot.b if foot.c == foot.end and skeleton.get_bone_name(foot.c).ends_with(" hand") else foot.c
		var paw_joints := {}
		for index in skeleton.get_bone_count():
			var joint := index
			while joint >= 0:
				if joint == limb_root:
					paw_joints[index] = true
					break
				joint = skeleton.get_bone_parent(joint)
		var seen := {}
		for index: int in foot.vertices:
			seen[vertices[index]] = true
		for vertex in vertices.size():
			if seen.has(vertices[vertex]):
				continue
			var paw_weight := 0.0
			for slot in 4:
				var index := vertex * 4 + slot
				if paw_joints.has(bindings[bones[index]]):
					paw_weight += weights[index]
			if paw_weight > .35:
				foot.vertices.append(vertex)
				seen[vertices[vertex]] = true


func trunk_points(source: Dictionary) -> Dictionary:
	var distal := {}
	for leg: Dictionary in contact.feet:
		distal[leg.b] = true
	for index in skeleton.get_bone_count():
		var parent := skeleton.get_bone_parent(index)
		if distal.has(parent):
			distal[index] = true
	var surfaces: Array[Dictionary] = []
	for surface: Dictionary in source.surfaces:
		var points := PackedVector3Array()
		var bindings := PackedInt32Array()
		var weights := PackedFloat32Array()
		var stride: int = surface.stride
		for vertex in surface.points.size():
			var offset: int = vertex * stride
			var leg_weight := 0.0
			for influence in stride:
				var binding: int = surface.bindings[offset + influence]
				if distal.has(source.bones[binding]):
					leg_weight += surface.weights[offset + influence]
			if leg_weight > .45:
				continue
			points.append(surface.points[vertex])
			for influence in stride:
				bindings.append(surface.bindings[offset + influence])
				weights.append(surface.weights[offset + influence])
		surfaces.append({"points": points, "bindings": bindings, "weights": weights, "stride": stride})
	return {"bones": source.bones, "bind_poses": source.bind_poses, "surfaces": surfaces}


func _physics_process(_delta: float) -> void:
	release_support()
	support_plane = {}
	split_floor = {}
	contact.plane = {}
	contact.use_local_planes = false
	if dead or not contact.enabled:
		return
	contact.sample(get_world_3d().direct_space_state, global_position)
	var center := ground_under(global_position)
	if center.is_empty() or center.normal.y < .95:
		return
	var normal: Vector3 = center.normal
	for hit: Dictionary in contact.contacts.values():
		if separate_plane(center, hit):
			split_floor = center
			break
	if split_floor.is_empty():
		for offset: Vector3 in FloorProbes:
			var hit := ground_under(to_global(offset))
			if not hit.is_empty() and hit.normal.y >= .8 and separate_plane(center, hit):
				split_floor = center
				break
	if split_floor.is_empty():
		support_plane = center
		contact.plane = center
	else:
		contact.use_local_planes = true
		normal = step_normal(normal)
	var local_normal := (global_basis.inverse() * normal).normalized()
	model.basis = (Basis(Quaternion(Vector3.UP, local_normal)) * source_model_basis).scaled_local(model.scale)
	if not split_floor.is_empty():
		tilt_away_from_step()
	contact.sample(get_world_3d().direct_space_state, global_position)


func ground_under(point: Vector3) -> Dictionary:
	query.from = point + Vector3.UP * .65
	query.to = point - Vector3.UP * .65
	return get_world_3d().direct_space_state.intersect_ray(query)


func separate_plane(base: Dictionary, sample: Dictionary) -> bool:
	var normal: Vector3 = base.normal
	return normal.dot(sample.normal) < .995 or absf(normal.dot(sample.position - base.position)) > .02


func step_normal(fallback: Vector3) -> Vector3:
	if contact.contacts.size() != 4:
		return fallback
	# Front and rear supports determine pitch. Left and right determine roll.
	var rear_left: Vector3 = contact.contacts[0].position
	var front_left: Vector3 = contact.contacts[1].position
	var rear_right: Vector3 = contact.contacts[2].position
	var front_right: Vector3 = contact.contacts[3].position
	var length := (front_left + front_right) - (rear_left + rear_right)
	var width := (front_right + rear_right) - (front_left + rear_left)
	var normal := length.cross(width).normalized()
	if normal.y < 0.0:
		normal = -normal
	if normal.y < .8:
		return fallback
	var tilt := fallback.angle_to(normal)
	return fallback.slerp(normal, minf(1.0, .20 / tilt)) if tilt > .001 else fallback


func tilt_away_from_step() -> void:
	var floor_height: float = split_floor.position.y
	var hit: Dictionary = contact.step_conflict(floor_height, query, trunk)
	if float(hit.get("lift", 0.0)) < .035:
		return
	var lever: Vector3 = (hit.point - model.global_position).slide(Vector3.UP)
	if lever.length() < .30:
		return
	var original := model.global_basis
	var axis := lever.normalized().cross(Vector3.UP)
	model.global_basis = Basis(Quaternion(axis, minf(.16, float(hit.lift) / lever.length()))) * original
	var revised: Dictionary = contact.step_conflict(floor_height, query, trunk)
	if float(revised.get("lift", 0.0)) >= float(hit.lift):
		model.global_basis = original


func release_support() -> void:
	model.global_position.y -= support_lift
	support_lift = 0.0


func settle_support() -> void:
	if dead:
		return
	release_support()
	skeleton.force_update_all_bone_transforms()
	if not split_floor.is_empty():
		support_lift = float(contact.step_conflict(split_floor.position.y, query, skin).get("lift", 0.0))
	elif not support_plane.is_empty():
		var normal: Vector3 = support_plane.normal
		var gap := Ground.minimum_plane_gap(skin[0], skeleton, skeleton.global_transform,
			support_plane.position, normal)
		support_lift = maxf(0.0, (Clearance - gap) / normal.y)
	model.global_position.y += support_lift


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in ["Fidget", "Fidget2"]:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	release_support()
	return super.receive_action(request)


func begin_death_from(source: Node3D) -> float:
	model.global_position.y -= float(source.support_lift)
	return super.begin_death_from(source)
