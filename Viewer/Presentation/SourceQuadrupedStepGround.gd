# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceTrollGround.gd"

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Fall := preload("res://Presentation/SourceGroundedCreatureFall.gd")
const Gaits := preload("res://Presentation/SourceCreatureGaitLoop.gd")
const Probes := [Vector3(-.63, 0, -.96), Vector3(.63, 0, -.96),
	Vector3(-.63, 0, .96), Vector3(.63, 0, .96), Vector3.FORWARD * 1.42, Vector3.BACK * 1.42]

var visual: Node3D
var surfaces: Dictionary
var ground: Dictionary
var lift := 0.0
var head_points: Array[Dictionary] = []
var head: Array[int] = []
var displayed := preload("res://Presentation/SourceRenderedPose.gd").new()
var displayed_space := Transform3D.IDENTITY
var death := Fall.new()


static func attach(actor: Node3D, footing: SkeletonModifier3D) -> void:
	var mesh: MeshInstance3D = actor.contact.surface
	actor.contact.free()
	actor.contact = footing
	actor.skeleton.add_child(footing)
	footing.bind(actor, mesh)


func bind(actor: Node3D, mesh: MeshInstance3D) -> void:
	visual = actor
	include_toe_descendants = true
	align_skinned_soles = true
	configure(mesh, true)
	assert(feet.size() == 4)
	var rig := get_skeleton()
	for part: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
		if part.skin != null and part.name != &"SourceContactReference":
			surfaces[part] = Ground.skin_points(part, rig)
	for label: String in ["bip01 head", "bip01 neck"]:
		head.append(rig.find_bone(label))
	assert(not head.has(-1))
	for skin: Dictionary in surfaces.values():
		head_points.append(horn_skin(skin))
	Gaits.close_gaits(actor.animator)
	support_appendages = clear_horns
	actor.animator.mixer_applied.connect(release)
	actor.animator.mixer_applied.connect(settle_death)
	modification_processed.connect(settle)
	modification_processed.connect(remember_display)


func horn_skin(skin: Dictionary) -> Dictionary:
	var selected: Array[Dictionary] = []
	for original: Dictionary in skin.surfaces:
		var points := PackedVector3Array()
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		var stride: int = original.stride
		for vertex: int in original.points.size():
			var first := vertex * stride
			var weight := 0.0
			for slot in range(first, first + stride):
				if skin.bones[original.bindings[slot]] in head:
					weight += original.weights[slot]
			if weight < .45:
				continue
			points.append(original.points[vertex])
			for slot in range(first, first + stride):
				bones.append(original.bindings[slot])
				weights.append(original.weights[slot])
		selected.append({"points": points, "bindings": bones, "weights": weights, "stride": stride})
	return {"bones": skin.bones, "bind_poses": skin.bind_poses, "surfaces": selected}


func sample(space: PhysicsDirectSpaceState3D, origin: Vector3) -> void:
	release()
	ground = hit_at(space, origin, origin.y)
	plane = {}
	use_local_planes = false
	if ground.is_empty():
		return
	var up: Vector3 = (visual.global_basis.inverse() * ground.normal).normalized()
	var tilt := Basis(Quaternion(Vector3.UP, up))
	visual.model.basis = (tilt * visual.source_model_basis).scaled_local(visual.model.scale)
	super.sample(space, origin)
	use_local_planes = spans_treads(ground)
	for hit: Dictionary in contacts.values():
		if different(ground, hit):
			use_local_planes = true
			break
	if not use_local_planes:
		plane = ground


func hit_at(space: PhysicsDirectSpaceState3D, point: Vector3, height: float) -> Dictionary:
	floor_query.from = Vector3(point.x, height + .65, point.z)
	floor_query.to = Vector3(point.x, height - .65, point.z)
	var hit := space.intersect_ray(floor_query)
	return hit if not hit.is_empty() and hit.normal.y > .8 else {}


func different(support: Dictionary, hit: Dictionary) -> bool:
	return not hit.is_empty() and (support.normal.dot(hit.normal) < .995
		or absf(support.normal.dot(hit.position - support.position)) > .018)


func spans_treads(support: Dictionary) -> bool:
	var space := get_world_3d().direct_space_state
	var origin: Vector3 = visual.global_position
	for offset: Vector3 in Probes:
		if different(support, hit_at(space, origin + visual.global_basis * offset, origin.y)):
			return true
	return false


func clear_horns() -> void:
	for attempt in 5:
		for joint: int in head:
			var conflict := step_conflict(ground.position.y, floor_query, head_points)
			if float(conflict.get("lift", 0.0)) <= .007:
				return
			rotate_toward_surface(joint, conflict.point, conflict.normal, conflict.lift)


func release() -> void:
	if lift > 0.0:
		visual.model.global_position.y -= lift
		lift = 0.0


func settle() -> void:
	if visual.dead or ground.is_empty():
		return
	release()
	var rig := get_skeleton()
	rig.force_update_all_bone_transforms()
	if use_local_planes:
		var active: Array[Dictionary] = []
		active.assign(surfaces.values())
		lift = float(step_conflict(ground.position.y, floor_query, active).get("lift", 0.0))
	else:
		var gap := INF
		for skin: Dictionary in surfaces.values():
			gap = minf(gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, ground.position, ground.normal))
		lift = maxf(0.0, (SoleClearance - gap) / float(ground.normal.y))
	visual.model.global_position.y += lift


func remember_display() -> void:
	if not visual.dead:
		var rig := get_skeleton()
		displayed.capture(rig)
		displayed_space = visual.global_transform.affine_inverse() * rig.global_transform


func prepare_death() -> void:
	var support := ground if not ground.is_empty() else death.floor_under(visual)
	death.split = use_local_planes or spans_treads(support)
	death.remember_floor(visual, support)
	death.skin = death.supported_skin(visual)


func settle_death() -> void:
	if not death.plane.is_empty():
		death.settle(visual)
